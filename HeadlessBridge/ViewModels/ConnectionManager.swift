import Foundation
import SwiftUI
import AudioToolbox

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
    @Published private var timerTick: Int = 0  // 每秒觸發 UI 重繪（超輕量）
    
    // MARK: - Private
    private let sshService = SSHService.shared
    private let networkService = NetworkService.shared
    private let keychain = KeychainService.shared
    private var connectionTask: Task<Void, Never>?
    private var displayTimer: Timer?          // 1Hz 碼表計時器
    private var retryCount = 0
    private let maxRetries = 3
    private var isSyncing = false  // 防止重複同步

    // MARK: - Cumulative Connection Time
    /// 從 UserDefaults 讀取/寫入跨 session 累計秒數
    private var totalAccumulatedSeconds: Double {
        get { UserDefaults.standard.double(forKey: "total_connection_seconds") }
        set { UserDefaults.standard.set(newValue, forKey: "total_connection_seconds") }
    }
    
    // MARK: - Init
    init() {
        loadConfig()
        loadHistory()
        loadStatus()  // ⚡ 立刻從磁碟還原狀態，在 async sync 執行前 UI 就顯示正確
        print("DEBUG: Init completed. Status after loadStatus: \(status)")
    }
    
    // MARK: - Smart Connect
    func smartConnect() {
        guard !status.isLoading else { return }
        selectedMode = .auto
        reconnect()
    }
    
    // MARK: - Reconnect (Improved)
    func reconnect() {
        connectionTask?.cancel()
        connectionTask = Task {
            // Step 1: Detect Environment
            status = .detecting
            environment = await networkService.detectEnvironment(config: config)
            
            // Step 2: Determine Mode
            let modeForConnection: ConnectionMode
            if selectedMode == .auto {
                modeForConnection = environment.recommendedMode
            } else {
                modeForConnection = selectedMode
            }
            
            // Step 3: Execute Connection
            await performConnect(mode: modeForConnection)
        }
    }
    
    func connect(mode: ConnectionMode) {
        // Force selection update
        selectedMode = mode
        reconnect()
    }
    
    private func performConnect(mode: ConnectionMode) async {
        // Ensure we handle .auto resolution here if needed, 
        // but reconnect() already resolved it.
        let resolvedMode = mode
        
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
        
        // 嚴格檢查 USB 連線狀態：如果未插線，直接報錯，不允許假裝有線連線
        guard environment.isUSBConnected else {
            await handleFailure(
                error: ConnectionError.usbNotConnected,
                currentMode: .wired,
                fallbackMode: .wireless,
                password: password
            )
            return
        }
        
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
    private func handleSuccess(mode: ConnectionMode) {
        status = .connected(mode)
        connectedAt = Date()
        startDurationTimer()         // ▶ 啟動 1Hz 碼表
        saveStatus(mode: mode)
        AudioServicesPlaySystemSound(1016)
    }
    
    // MARK: - Handle Failure with Retry
    /// 先重試同一模式 maxRetries 次，用盡後才切換到 fallbackMode（只切換一次）
    private func handleFailure(
        error: Error,
        currentMode: ConnectionMode,
        fallbackMode: ConnectionMode,
        password: String
    ) async {
        // 如果任務已被取消，不進行任何動作
        if Task.isCancelled { return }
        
        // 嚴格手動模式：失敗後直接顯示錯誤，不進行自動重試或切換模式
        status = .failed(error.localizedDescription)
        addHistory(mode: currentMode, success: false)
    }
    
    // MARK: - Disconnect
    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        retryCount = 0
        
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
        
        // 累積本次 session 時間並停止計時器
        if let start = connectedAt {
            totalAccumulatedSeconds += Date().timeIntervalSince(start)
        }
        stopDurationTimer()
        totalAccumulatedSeconds = 0   // 斷線後清零累計
        clearStatus()
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
        let bdOk = await sshService.isBetterDisplayReachable(config: config, password: password)
        updateDiagnostic(item: "BetterDisplay",
                         status: bdOk ? .pass : .fail,
                         message: bdOk ? "HTTP server 運作正常" : "BetterDisplay 未啟動，請確認 App 已開啟")
        
        // 5. 檢查 Sidecar 狀態（顯示原始 API 回應）
        await addDiagnostic(item: "Sidecar 狀態", status: .checking, message: "查詢中...")
        do {
            let specifierCheck = try await sshService.executeCommand(
                host: config.hostname,
                port: config.sshPort,
                user: config.sshUser,
                password: password,
                command: "curl -s 'http://localhost:\(config.betterDisplayPort)/get?sidecarConnected&specifier=\(config.iPadUUID)' 2>/dev/null"
            )
            let globalCheck = try await sshService.executeCommand(
                host: config.hostname,
                port: config.sshPort,
                user: config.sshUser,
                password: password,
                command: "curl -s 'http://localhost:\(config.betterDisplayPort)/get?sidecarConnected' 2>/dev/null"
            )
            let sidecarOk = await sshService.isSidecarConnected(config: config, password: password)
            let statusText = sidecarOk == true ? "連線中" : (sidecarOk == false ? "未連線 (閒置正常)" : "狀態不明")
            
            // 將 raw API 轉為白話文
            let translate: (String) -> String = { raw in
                let r = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if r == "on" || r == "1" || r == "true" { return "開啟" }
                if r == "off" || r == "0" || r == "false" { return "關閉" }
                // Avoid "查詢失敗" if we are actually connected according to sidecarOk
                if sidecarOk == true { return "已開啟" }
                if r.contains("fail") || r.isEmpty { return "無外部連線" }
                return r
            }
            
            let specText = translate(specifierCheck)
            let globText = translate(globalCheck)
            
            let detailMessage = "這台 iPad: \(specText) | Mac 總體: \(globText)"
            let finalMessage = sidecarOk == false ? "\(statusText)\n尚未啟動連線為預期狀態\n\(detailMessage)" : "\(statusText)\n\(detailMessage)"
            
            updateDiagnostic(item: "Sidecar 狀態",
                             status: sidecarOk == true ? .pass : (sidecarOk == false ? .warning : .fail),
                             message: finalMessage)
        } catch {
            updateDiagnostic(item: "Sidecar 狀態",
                             status: .fail,
                             message: "查詢失敗: \(error.localizedDescription)")
        }
        
        // 6. 檢查 iPad UUID
        await addDiagnostic(item: "iPad UUID", status: .checking, message: "確認中...")
        let uuidValid = config.iPadUUID.count == 36
        updateDiagnostic(item: "iPad UUID",
                         status: uuidValid ? .pass : .fail,
                         message: uuidValid ? "UUID 格式正確" : "UUID 格式錯誤，請重新設定")
        
        // 7. 檢查 Tailscale（若有設定）
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
    
    // MARK: - Connection Monitoring (Passive Sync)
    /// 僅在從背景切換回前景時執行一次，確保 UI 狀態與 Mac 實際狀況同步。
    /// 具備「無狀態恢復」功能：即便 App 重啟，只要 Mac 端還在鏡像，App 就會自動恢復為「已連線」。
    private func syncConnectionStatus() async {
        // 防止重複執行
        guard !isSyncing else {
            print("DEBUG: Sync already in progress, skipping.")
            return
        }
        // 如果正在連線中，不干擾
        guard !status.isLoading else {
            print("DEBUG: Connection in progress, skipping sync.")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("DEBUG: Executing stateless connection sync... Current status: \(status)")
        
        // 等待 2 秒，確保 iPadOS 從背景回到前景後的網路介面已經完全恢復
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let password = keychain.load(for: "ssh_password_\(config.id)") ?? ""
        
        // 檢查 Mac 端的 Sidecar 狀態
        let sidecarStatus = await sshService.isSidecarConnected(config: config, password: password)
        print("DEBUG: Sync result - sidecarStatus: \(String(describing: sidecarStatus))")
        
        switch sidecarStatus {
        case .some(true):
            // Mac 端正在鏡像
            if !status.isConnected {
                print("DEBUG: Mac is mirroring but App shows \(status). Adopting connection...")
                status = .connected(.wireless)
                connectedAt = Date()
                startDurationTimer()  // 同步恢復時也啟動計時
                saveStatus(mode: .wireless)
                AudioServicesPlaySystemSound(1016)
            } else {
                print("DEBUG: Status matches Mac (Connected).")
            }
            
        case .some(false):
            // Mac 端確定沒有鏡像
            if status.isConnected {
                print("DEBUG: Mac is NOT mirroring. Resetting to .disconnected.")
                clearStatus()
                status = .disconnected
                connectedAt = nil
            } else {
                print("DEBUG: Status matches Mac (Disconnected).")
            }
            
        case .none:
            // 網路錯誤或無法連達 Mac
            print("DEBUG: Mac unreachable during sync. Preserving current status: \(status)")
        }
    }
    
    // MARK: - Duration Timer（1Hz，超輕量）
    private func startDurationTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timerTick += 1  // 觸發 @ObservableObject 重繪，本身不做任何運算
            }
        }
    }

    private func stopDurationTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    // MARK: - Connection Duration（累計）
    var connectionDuration: String {
        let _ = timerTick   // 讀取此值讓 SwiftUI 訂閱到每秒更新
        let sessionSeconds = connectedAt.map { Date().timeIntervalSince($0) } ?? 0
        let total = totalAccumulatedSeconds + sessionSeconds
        let hours   = Int(total) / 3600
        let minutes = Int(total) % 3600 / 60
        let seconds = Int(total) % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        }
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
    
    // MARK: - Status Persistence
    /// 連線成功時將模式存入磁碟，確保 App 重啟後能立刻還原 UI 狀態
    private func saveStatus(mode: ConnectionMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "last_connected_mode")
        print("DEBUG: Saved status mode: \(mode.rawValue)")
    }
    
    /// App 啟動時從磁碟還原上次的連線狀態
    private func loadStatus() {
        guard let rawMode = UserDefaults.standard.string(forKey: "last_connected_mode"),
              let mode = ConnectionMode(rawValue: rawMode) else {
            print("DEBUG: No saved status found, starting as disconnected.")
            return
        }
        // 立刻設定為「已連線」，讓 UI 在 async sync 執行前就顯示正確
        status = .connected(mode)
        print("DEBUG: Restored status from disk: .connected(\(mode.rawValue))")
    }
    
    /// 中斷連線時清除磁碟上的狀態
    private func clearStatus() {
        UserDefaults.standard.removeObject(forKey: "last_connected_mode")
        print("DEBUG: Cleared saved status.")
    }
    
    // MARK: - Clear Config (with proper Keychain cleanup)
    func clearAllSettings() {
        let oldConfigID = config.id
        keychain.delete(for: "ssh_password_\(oldConfigID)")
        config = MacConfig.default
        keychain.delete(for: "ssh_password_\(config.id)")
        clearStatus()
        saveConfig()
    }
    
    // MARK: - Scene Phase Handling
    func handleScenePhase(_ phase: ScenePhase) {
        print("DEBUG: ScenePhase changed to: \(phase)")
        switch phase {
        case .background:
            print("DEBUG: App backgrounded, keeping active tasks alive...")
            
        case .active:
            print("DEBUG: App became active. Current status: \(status)")
            
            // ① 立刻執行同步（不等待環境偵測）
            Task {
                await syncConnectionStatus()
            }
            
            // ② 環境偵測獨立執行，不阻塞同步
            Task {
                environment = await networkService.detectEnvironment(config: config)
            }
            
        default:
            break
        }
    }
}

// MARK: - Connection Errors
enum ConnectionError: LocalizedError {
    case notSameNetwork
    case tailscaleNotActive
    case betterDisplayNotRunning
    case configIncomplete
    case usbNotConnected
    
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
        case .usbNotConnected:
            return "USB 連接線未接上，無法使用有線 Sidecar"
        }
    }
}
