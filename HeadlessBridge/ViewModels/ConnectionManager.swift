import Foundation
import SwiftUI

// MARK: - Connection Manager
@MainActor
class ConnectionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var status: ConnectionStatus = .disconnected
    @Published var environment: NetworkEnvironment = NetworkEnvironment()
    @Published var config: MacConfig = MacConfig.default
    @Published var history: [ConnectionHistory] = []
    @Published var diagnosticResults: [DiagnosticResult] = []
    @Published var selectedMode: ConnectionMode = .auto
    @Published var isRunningDiagnostic: Bool = false
    @Published var connectedAt: Date? = nil
    
    // MARK: - Private
    private let sshService = SSHService.shared
    private let networkService = NetworkService.shared
    private let keychain = KeychainService.shared
    private var connectionTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 3
    
    // MARK: - Init
    init() {
        loadConfig()
        loadHistory()
    }
    
    // MARK: - Smart Connect
    func smartConnect() async {
        guard !status.isLoading else { return }
        retryCount = 0
        await performConnection()
    }
    
    private func performConnection() async {
        // Step 1: 偵測環境
        status = .detecting
        environment = await networkService.detectEnvironment(config: config)
        
        // Step 2: 決定連線模式（解析 .auto 為具體模式）
        let mode: ConnectionMode
        if selectedMode == .auto {
            mode = environment.recommendedMode
        } else {
            mode = selectedMode
        }
        
        // Step 3: 執行連線
        await connect(mode: mode)
    }
    
    private func connect(mode: ConnectionMode) async {
        // .auto 在此解析為具體模式，避免遞迴
        let resolvedMode: ConnectionMode
        if mode == .auto {
            resolvedMode = environment.recommendedMode
        } else {
            resolvedMode = mode
        }
        
        let password = keychain.load(for: "ssh_password_\(config.id)") ?? ""
        
        switch resolvedMode {
        case .wired:
            await connectWiredSidecar(password: password)
        case .wireless:
            await connectWirelessSidecar(password: password)
        case .remote:
            await connectRemoteVNC(password: password)
        case .auto:
            // 不可能到這裡，但安全起見回報錯誤
            status = .failed("無法決定連線模式")
        }
    }
    
    // MARK: - Wired Sidecar
    private func connectWiredSidecar(password: String) async {
        status = .connecting("連接有線 Sidecar 中...")
        
        do {
            try await sshService.triggerSidecar(config: config, password: password)
            handleSuccess(mode: .wired)
        } catch {
            await handleFailure(error: error, currentMode: .wired, fallbackMode: .wireless, password: password)
        }
    }
    
    // MARK: - Wireless Sidecar
    private func connectWirelessSidecar(password: String) async {
        status = .connecting("連接無線 Sidecar 中...")
        
        guard environment.isOnSameNetwork else {
            await handleFailure(
                error: ConnectionError.notSameNetwork,
                currentMode: .wireless,
                fallbackMode: .remote,
                password: password
            )
            return
        }
        
        do {
            try await sshService.triggerSidecar(config: config, password: password)
            handleSuccess(mode: .wireless)
        } catch {
            await handleFailure(error: error, currentMode: .wireless, fallbackMode: .remote, password: password)
        }
    }
    
    // MARK: - Remote VNC
    private func connectRemoteVNC(password: String) async {
        status = .connecting("建立遠距連線中...")
        
        guard environment.isTailscaleActive else {
            status = .failed("Tailscale 未啟用，請確認 Tailscale App 已開啟")
            return
        }
        
        // 使用 Tailscale IP 觸發連線
        let remoteConfig = MacConfig(
            name: config.name,
            hostname: config.tailscaleIP,
            sshUser: config.sshUser,
            sshPort: config.sshPort,
            betterDisplayPort: config.betterDisplayPort,
            iPadUUID: config.iPadUUID,
            tailscaleIP: config.tailscaleIP
        )
        
        do {
            try await sshService.triggerSidecar(config: remoteConfig, password: password)
            handleSuccess(mode: .remote)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Handle Success
    /// 連線成功時只啟動計時器，不記錄歷史。
    /// 歷史在 `disconnect()` 時記錄一次，帶實際使用時間。
    private func handleSuccess(mode: ConnectionMode) {
        status = .connected(mode)
        connectedAt = Date()
        startConnectionTimer()
    }
    
    // MARK: - Handle Failure with Retry
    /// 先重試同一模式 maxRetries 次，用盡後才切換到 fallbackMode（只切換一次）
    private func handleFailure(
        error: Error,
        currentMode: ConnectionMode,
        fallbackMode: ConnectionMode,
        password: String
    ) async {
        retryCount += 1
        
        if retryCount <= maxRetries {
            // 重試同一模式
            status = .retrying(retryCount)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await connect(mode: currentMode)
        } else if retryCount == maxRetries + 1 {
            // 重試用盡，嘗試 fallback（只做一次）
            status = .connecting("切換到 \(fallbackMode.rawValue)...")
            await connect(mode: fallbackMode)
        } else {
            // fallback 也失敗
            status = .failed(error.localizedDescription)
            addHistory(mode: selectedMode, success: false)
        }
    }
    
    // MARK: - Disconnect
    func disconnect() {
        let password = keychain.load(for: "ssh_password_\(config.id)") ?? ""
        
        // 記錄歷史（帶實際使用時間）
        if case .connected(let mode) = status {
            addHistory(mode: mode, success: true)
        }
        
        // 非同步發送中斷指令（不等待結果）
        Task {
            do {
                _ = try await sshService.executeCommand(
                    host: config.hostname,
                    port: config.sshPort,
                    user: config.sshUser,
                    password: password,
                    command: "curl 'http://localhost:\(config.betterDisplayPort)/set?sidecarConnected=off&specifier=\(config.iPadUUID)'"
                )
            } catch {}
        }
        
        stopConnectionTimer()
        status = .disconnected
        connectedAt = nil
    }
    
    // MARK: - Run Diagnostics
    func runDiagnostics() async {
        isRunningDiagnostic = true
        diagnosticResults = []
        
        let password = keychain.load(for: "ssh_password_\(config.id)") ?? ""
        
        // 1. 檢查 Mac mini 設定
        await addDiagnostic(item: "Mac mini 設定", status: .checking, message: "檢查中...")
        let configValid = !config.hostname.isEmpty && !config.sshUser.isEmpty && !config.iPadUUID.isEmpty
        updateDiagnostic(item: "Mac mini 設定",
                         status: configValid ? .pass : .fail,
                         message: configValid ? "設定完整" : "請完成 Mac mini 設定")
        
        // 2. 檢查網路連線
        await addDiagnostic(item: "網路連線", status: .checking, message: "偵測中...")
        let networkOk = await networkService.detectSameNetwork(hostname: config.hostname)
        updateDiagnostic(item: "網路連線",
                         status: networkOk ? .pass : .warning,
                         message: networkOk ? "Mac mini 可連達" : "無法連達 Mac mini（可能需要 VPN）")
        
        // 3. 檢查 SSH
        await addDiagnostic(item: "SSH 服務", status: .checking, message: "測試中...")
        let sshOk = await sshService.testConnection(
            host: config.hostname,
            port: config.sshPort,
            user: config.sshUser,
            password: password
        )
        updateDiagnostic(item: "SSH 服務",
                         status: sshOk ? .pass : .fail,
                         message: sshOk ? "SSH 連線正常" : "SSH 連線失敗，請確認密碼和設定")
        
        // 4. 檢查 BetterDisplay
        await addDiagnostic(item: "BetterDisplay", status: .checking, message: "確認中...")
        let bdOk = await sshService.checkBetterDisplay(config: config, password: password)
        updateDiagnostic(item: "BetterDisplay",
                         status: bdOk ? .pass : .fail,
                         message: bdOk ? "HTTP server 運作正常" : "BetterDisplay 未啟動，請確認 App 已開啟")
        
        // 5. 檢查 iPad UUID
        await addDiagnostic(item: "iPad UUID", status: .checking, message: "確認中...")
        let uuidValid = config.iPadUUID.count == 36
        updateDiagnostic(item: "iPad UUID",
                         status: uuidValid ? .pass : .fail,
                         message: uuidValid ? "UUID 格式正確" : "UUID 格式錯誤，請重新設定")
        
        // 6. 檢查 Tailscale（若有設定）
        if !config.tailscaleIP.isEmpty {
            await addDiagnostic(item: "Tailscale", status: .checking, message: "確認中...")
            let tsOk = environment.isTailscaleActive
            updateDiagnostic(item: "Tailscale",
                             status: tsOk ? .pass : .warning,
                             message: tsOk ? "Tailscale 連線正常" : "Tailscale 未連線")
        }
        
        isRunningDiagnostic = false
    }
    
    // MARK: - Diagnostic Helpers
    private func addDiagnostic(item: String, status: DiagnosticResult.DiagnosticStatus, message: String) async {
        let result = DiagnosticResult(item: item, status: status, message: message)
        diagnosticResults.append(result)
    }
    
    private func updateDiagnostic(item: String, status: DiagnosticResult.DiagnosticStatus, message: String) {
        if let index = diagnosticResults.firstIndex(where: { $0.item == item }) {
            diagnosticResults[index] = DiagnosticResult(item: item, status: status, message: message)
        }
    }
    
    // MARK: - Connection Timer
    private func startConnectionTimer() {
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkConnectionHealth()
            }
        }
    }
    
    private func stopConnectionTimer() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
    private func checkConnectionHealth() async {
        guard status.isConnected else { return }
        let password = keychain.load(for: "ssh_password_\(config.id)") ?? ""
        let healthy = await sshService.testConnection(
            host: config.hostname,
            port: config.sshPort,
            user: config.sshUser,
            password: password
        )
        if !healthy {
            status = .disconnected
            connectedAt = nil
            stopConnectionTimer()
        }
    }
    
    // MARK: - Connection Duration
    var connectionDuration: String {
        guard let connectedAt else { return "" }
        let duration = Date().timeIntervalSince(connectedAt)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        if hours > 0 { return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))" }
        return "\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
    }
    
    // MARK: - History Management
    private func addHistory(mode: ConnectionMode, success: Bool) {
        let duration = connectedAt.map { Date().timeIntervalSince($0) } ?? 0
        let entry = ConnectionHistory(
            date: Date(),
            mode: mode.rawValue,
            duration: duration,
            success: success
        )
        history.insert(entry, at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
        saveHistory()
    }
    
    // MARK: - Persistence
    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "mac_config")
        }
    }
    
    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "mac_config"),
           let config = try? JSONDecoder().decode(MacConfig.self, from: data) {
            self.config = config
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "connection_history")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "connection_history"),
           let history = try? JSONDecoder().decode([ConnectionHistory].self, from: data) {
            self.history = history
        }
    }
    
    // MARK: - Clear Config (with proper Keychain cleanup)
    /// 清除設定並正確刪除舊的 Keychain 密碼
    func clearAllSettings() {
        let oldConfigID = config.id
        keychain.delete(for: "ssh_password_\(oldConfigID)")
        config = MacConfig.default
        // 默認 config 的 id 可能相同，但多刪一次無害
        keychain.delete(for: "ssh_password_\(config.id)")
        saveConfig()
    }
}

// MARK: - Connection Errors
enum ConnectionError: LocalizedError {
    case notSameNetwork
    case tailscaleNotActive
    case betterDisplayNotRunning
    case configIncomplete
    
    var errorDescription: String? {
        switch self {
        case .notSameNetwork:
            return "iPad 和 Mac mini 不在同一網路"
        case .tailscaleNotActive:
            return "Tailscale 未啟用"
        case .betterDisplayNotRunning:
            return "BetterDisplay 未執行"
        case .configIncomplete:
            return "設定不完整，請先完成設定"
        }
    }
}
