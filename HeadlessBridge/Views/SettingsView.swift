import SwiftUI

// MARK: - Inline Hint Row
/// isRequired: true = 紅色「必要」badge，false = 灰色「選填」badge
struct InlineHintRow<Content: View>: View {
    let label: String
    let isRequired: Bool
    let helpAction: () -> Void
    let content: Content

    init(label: String, isRequired: Bool = true,
         helpAction: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.label = label
        self.isRequired = isRequired
        self.helpAction = helpAction
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 4) {
            // 必要 / 選填 badge
            Text(isRequired ? "必要" : "選填")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isRequired ? Theme.musicRed : .secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(isRequired ? Theme.musicRed.opacity(0.15) : Color.secondary.opacity(0.15)))
            
            Text(label)
                .foregroundStyle(Theme.musicRed)
            
            Button(action: helpAction) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            content
        }
        .padding(.vertical, 3) // Ultra-slim internal padding
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var manager: ConnectionManager
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @State private var draftConfig = MacConfig.default
    @State private var sshPassword: String = ""
    @State private var originalPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showSaved: Bool = false
    @State private var showHelp: HelpType? = nil
    @State private var isFetchingUUID: Bool = false
    @State private var fetchUUIDError: String?
    @State private var showResetAlert: Bool = false
    
    private let keychain = KeychainService.shared
    
    enum HelpType: Identifiable {
        case hostname, username, sshPort, sshPassword, betterDisplayPort, uuid, tailscaleIP
        var id: Int { hashValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    // MARK: Floating Action Bar (Relocated to top of Form, left-aligned)
                    Section {
                        HStack(spacing: 12) {
                            // Save Button
                            Button {
                                saveSettings()
                            } label: {
                                HStack {
                                    Image(systemName: showSaved ? "checkmark" : "square.and.arrow.down")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(showSaved ? "已儲存" : "儲存設定")
                                }
                                .font(.system(size: 16, weight: .bold)) // Increased from 13pt (~20%+)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(showSaved ? .green : Theme.musicRed)
                                        .shadow(color: (showSaved ? Color.green : Theme.musicRed).opacity(0.2), radius: 5, x: 0, y: 3)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Reset Button
                            Button {
                                showResetAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("重置")
                                }
                                .font(.system(size: 16, weight: .bold)) // Increased from 13pt
                                .foregroundStyle(.primary.opacity(0.7))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: -25, leading: 20, bottom: -25, trailing: 20)) // Pulled content UP by 0.7cm (bottom: -5 -> -25)
                    
                    // MARK: Mac 連線設定
                    Section("Mac 設定") {
                        // Hostname：必要
                        InlineHintRow(
                            label: "Hostname",
                            isRequired: true,
                            helpAction: { showHelp = .hostname }
                        ) {
                            TextField("例如: My-Mac.local", text: $draftConfig.hostname)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .frame(maxWidth: 200)
                        }
                        .listRowInsets(EdgeInsets(top: -7, leading: 20, bottom: -7, trailing: 20)) // Extreme slim background
                    }
                    
                    // MARK: SSH 設定
                    Section("SSH 設定") {
                        // 使用者名稱：必要
                        InlineHintRow(
                            label: "使用者名稱",
                            isRequired: true,
                            helpAction: { showHelp = .username }
                        ) {
                            TextField("例如: ryanchang", text: $draftConfig.sshUser)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .frame(maxWidth: 200)
                        }
                        .listRowInsets(EdgeInsets(top: -7, leading: 20, bottom: -7, trailing: 20)) // Extreme slim background
                        
                        // Port：必要
                        InlineHintRow(
                            label: "Port",
                            isRequired: true,
                            helpAction: { showHelp = .sshPort }
                        ) {
                            TextField("例如: 22", value: $draftConfig.sshPort, format: .number.grouping(.never))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.asciiCapableNumberPad)
                                .frame(maxWidth: 80)
                        }
                        .listRowInsets(EdgeInsets(top: -7, leading: 20, bottom: -7, trailing: 20)) // Extreme slim background
                        
                        // SSH 密碼：必要
                        InlineHintRow(
                            label: "SSH 密碼",
                            isRequired: true,
                            helpAction: { showHelp = .sshPassword }
                        ) {
                            HStack(spacing: 6) {
                                Group {
                                    if showPassword {
                                        TextField("例如: 123456", text: $sshPassword)
                                    } else {
                                        SecureField("例如: 123456", text: $sshPassword)
                                    }
                                }
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 160)
                                
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: -7, leading: 20, bottom: -7, trailing: 20)) // Extreme slim background
                    }
                    
                    // MARK: BetterDisplay 設定
                    Section("BetterDisplay 設定") {
                        // HTTP Port：必要
                        InlineHintRow(
                            label: "HTTP Port",
                            isRequired: true,
                            helpAction: { showHelp = .betterDisplayPort }
                        ) {
                            TextField("例如: 55777", value: $draftConfig.betterDisplayPort, format: .number.grouping(.never))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.asciiCapableNumberPad)
                                .frame(maxWidth: 80)
                        }
                        .listRowInsets(EdgeInsets(top: -7, leading: 20, bottom: -7, trailing: 20)) // Extreme slim background
                        
                        // iPad UUID：必要，單行整合
                        InlineHintRow(
                            label: "iPad UUID",
                            isRequired: true,
                            helpAction: { showHelp = .uuid }
                        ) {
                            HStack(spacing: 8) {
                                Button {
                                    Task { await fetchUUID() }
                                } label: {
                                    HStack(spacing: 4) {
                                        if isFetchingUUID {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(.blue)
                                        } else {
                                            Image(systemName: "arrow.down.circle.fill")
                                        }
                                        Text(isFetchingUUID ? "取得中..." : "自動取得")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.12))
                                            .shadow(color: Color.blue.opacity(isFetchingUUID ? 0 : 0.1), radius: 2, x: 0, y: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isFetchingUUID)
                                .fixedSize()
                                
                                TextField("UUID", text: $draftConfig.iPadUUID)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(minWidth: 150)
                                    .padding(.vertical, 10) // Increased height
                                    .padding(.horizontal, 12)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                        .listRowInsets(EdgeInsets(top: -7, leading: 20, bottom: -7, trailing: 20))
                        
                        if let error = fetchUUIDError {
                            Text(error)
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                                .padding(.leading, 80) // Align roughly with content
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 20))
                                .listRowBackground(Color.clear)
                        }
                    }
                    
                    // MARK: 遠距連線設定
                    Section("遠距連線設定") {
                        // Tailscale IP：選填
                        InlineHintRow(
                            label: "Tailscale IP",
                            isRequired: false,
                            helpAction: { showHelp = .tailscaleIP }
                        ) {
                            TextField("例如: 100.x.x.x", text: $draftConfig.tailscaleIP)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(maxWidth: 160)
                        }
                        .listRowInsets(EdgeInsets(top: -7, leading: 20, bottom: -7, trailing: 20)) // Extreme slim background
                    }
                    
                    // Add padding to prevent the last content being obscured by potential tab bar or safe area
                    Color.clear.frame(height: 60)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .alert("確定要清除所有設定嗎？", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) { }
                Button("確定清除", role: .destructive) {
                    manager.clearAllSettings()
                    draftConfig = manager.config
                    sshPassword = ""
                    originalPassword = ""
                    manager.hasUnsavedChanges = false
                }
            } message: {
                Text("此動作將清除所有連線參數與金鑰，且無法復原。")
            }
            .onAppear {
                draftConfig = manager.config
                originalPassword = keychain.load(for: "ssh_password_\(manager.config.id)") ?? ""
                sshPassword = originalPassword
                manager.hasUnsavedChanges = false
            }
            .onChange(of: draftConfig) { _, newConfig in
                manager.hasUnsavedChanges = (newConfig != manager.config) || (sshPassword != originalPassword)
            }
            .onChange(of: sshPassword) { _, newPassword in
                manager.hasUnsavedChanges = (draftConfig != manager.config) || (newPassword != originalPassword)
            }
            .sheet(item: $showHelp) { type in
                HelpSheet(type: type)
            }
        }
    }
    
    // MARK: - Save Settings
    private func saveSettings() {
        manager.config = draftConfig
        manager.saveConfig()
        if !sshPassword.isEmpty {
            keychain.save(password: sshPassword, for: "ssh_password_\(manager.config.id)")
        } else {
            keychain.delete(for: "ssh_password_\(manager.config.id)")
        }
        originalPassword = sshPassword
        manager.hasUnsavedChanges = false
        withAnimation {
            showSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSaved = false }
        }
    }
    
    // MARK: - Fetch UUID via SSH
    private func fetchUUID() async {
        isFetchingUUID = true
        fetchUUIDError = nil
        defer { isFetchingUUID = false }
        
        let password = keychain.load(for: "ssh_password_\(manager.config.id)") ?? sshPassword
        guard !password.isEmpty else {
            fetchUUIDError = "請先輸入並儲存 SSH 密碼"
            return
        }
        
        do {
            // 嘗試多個路徑尋找 betterdisplaycli
            let commands = [
                "/opt/homebrew/bin/betterdisplaycli get -sidecarList 2>/dev/null",
                "/usr/local/bin/betterdisplaycli get -sidecarList 2>/dev/null",
                "betterdisplaycli get -sidecarList 2>/dev/null",
                "system_profiler SPSidecarReporter | grep 'Identifier:'" // 備用方案
            ]
            
            var result = ""
            for cmd in commands {
                let output = try await SSHService.shared.executeCommand(
                    host: draftConfig.hostname,
                    port: draftConfig.sshPort,
                    user: draftConfig.sshUser,
                    password: password,
                    command: cmd
                )
                
                if !output.isEmpty {
                    result = output
                    break
                }
            }
            
            guard !result.isEmpty else { return }
            
            // 解析 UUID（格式 1：iPad名稱, UUID / 格式 2：Identifier: UUID）
            let lines = result.components(separatedBy: "\n")
            for line in lines {
                // 處理 BetterDisplay 格式
                if line.contains(", ") {
                    let parts = line.components(separatedBy: ", ")
                    if parts.count >= 2 {
                        let uuid = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if uuid.count == 36 {
                            updateUUID(uuid)
                            return
                        }
                    }
                }
                // 處理 system_profiler 格式
                if line.contains("Identifier:") {
                    let parts = line.components(separatedBy: "Identifier: ")
                    if parts.count >= 2 {
                        let uuid = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if uuid.count == 36 {
                            updateUUID(uuid)
                            return
                        }
                    }
                }
            }
            
            fetchUUIDError = "找不到 UUID，請確認 iPad 是否已準備就緒"
        } catch {
            let errorMsg = error.localizedDescription
            if errorMsg.contains("NIOConnectionError") || errorMsg.contains("Socket") {
                fetchUUIDError = "網路無法連達 Mac。\n請檢查 Hostname (是否拼錯?) 或關閉 VPN。"
            } else if errorMsg.contains("Authentication") {
                fetchUUIDError = "SSH 帳號或密碼錯誤。"
            } else {
                fetchUUIDError = "連線失敗: \(errorMsg)"
            }
        }
    }
    
    private func updateUUID(_ uuid: String) {
        Task { @MainActor in
            draftConfig.iPadUUID = uuid
        }
    }
}

// MARK: - Help Sheet
struct HelpSheet: View {
    let type: SettingsView.HelpType
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch type {
                    case .hostname:
                        HelpContent(title: "Hostname 是什麼？",
                                    content: "這是你的 Mac 在區域網路上的識別位址，格式固定為「電腦名稱.local」。\n\n【查詢步驟】\n1. 前往「系統設定 > 一般 > 共享」\n2. 視窗最上方的「電腦名稱」即是你的設備名稱\n3. 在 Hostname 欄填入「電腦名稱.local」\n\n【常見範例】\n• Mac mini → Mac-mini.local\n• MacBook Pro → MacBook-Pro.local")
                    case .username:
                        HelpContent(title: "如何找到使用者名稱？",
                                    content: "這不是你的全名 (例如: Ryan Chang)，而是系統的「帳號名稱」短名稱 (例如: ryanchang)。\n\n【查詢方法】\n在 Mac 的終端機執行 `whoami`，回傳的小寫文字即是正確的名稱。")
                    case .sshPort:
                        HelpContent(title: "SSH Port 是什麼？",
                                    content: "這是 SSH 連線所使用的通訊埠。\n\n【說明】\n• 預設值為 22。\n• 若你未曾在 Mac 上修改過 SSH 設定，請保持 22 即可。")
                    case .sshPassword:
                        HelpContent(title: "SSH 密碼是什麼？",
                                    content: "這是你的 Mac 登入密碼。\n\n【說明】\n• 即是你平時喚醒 Mac 或安裝軟體時輸入的系統密碼。")
                    case .betterDisplayPort:
                        HelpContent(title: "BetterDisplay HTTP Port",
                                    content: "這是 BetterDisplay 提供 API 控制所需的通訊埠。\n\n【查詢路徑】\n1. 打開 BetterDisplay 選單。\n2. 前往「偏好設定 > API」。\n3. 查看畫面中的 HTTP Port 數值（預設通常為 55777）。")
                    case .uuid:
                        HelpContent(title: "iPad UUID 是什麼？",
                                    content: "這是 Sidecar 辨識這台 iPad 的唯一 ID。\n\n【如何獲取？】\n• 推薦：點擊下方的「從 SSH 自動取得 UUID」按鈕。\n• 手動：請參考 Toolbox 內的詳細手動查詢方式。")
                    case .tailscaleIP:
                        HelpContent(title: "Tailscale IP 是什麼？",
                                    content: "這是用於遠距連線（不在同一個 Wi-Fi 下）的虛擬 IP。\n\n【查詢方法】\n1. 在 Mac 終端機執行 `tailscale ip`。\n2. 或在 Mac 的選單列點擊 Tailscale 圖示查看。")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("幫助說明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct HelpContent: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
// MARK: - View Extension for Keyboard
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
