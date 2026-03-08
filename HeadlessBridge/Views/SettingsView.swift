import SwiftUI

// MARK: - Inline Hint Row
/// isRequired: true = 紅色「必要」badge，false = 灰色「選填」badge
struct InlineHintRow<Content: View>: View {
    let label: String
    let hint: String
    let isRequired: Bool
    let helpAction: (() -> Void)?
    let content: Content

    init(label: String, hint: String, isRequired: Bool = true,
         helpAction: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.hint = hint
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
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let action = helpAction {
                Button(action: action) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            content
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var manager: ConnectionManager
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
        case hostname, username, uuid
        var id: Int { hashValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    // MARK: Mac 連線設定
                    Section("Mac 設定") {
                        // Hostname：必要
                        InlineHintRow(
                            label: "Hostname",
                            hint: "💡 格式為「電腦名稱.local」，點 ? 看如何查詢",
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
                    }
                    
                    // MARK: SSH 設定
                    Section("SSH 設定") {
                        // 使用者名稱：必要
                        InlineHintRow(
                            label: "使用者名稱",
                            hint: "💡 在 Mac 終端機執行 whoami 取得",
                            isRequired: true,
                            helpAction: { showHelp = .username }
                        ) {
                            TextField("例如: ryanchang", text: $draftConfig.sshUser)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .frame(maxWidth: 200)
                        }
                        
                        // Port：必要
                        InlineHintRow(
                            label: "Port",
                            hint: "💡 SSH 預設為 22，未修改過可保持不變",
                            isRequired: true
                        ) {
                            TextField("例如: 22", value: $draftConfig.sshPort, format: .number.grouping(.never))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.asciiCapableNumberPad)
                                .frame(maxWidth: 80)
                        }
                        
                        // SSH 密碼：必要
                        InlineHintRow(
                            label: "SSH 密碼",
                            hint: "💡 即 Mac 的系統登入密碼",
                            isRequired: true
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
                    }
                    
                    // MARK: BetterDisplay 設定
                    Section("BetterDisplay 設定") {
                        // HTTP Port：必要
                        InlineHintRow(
                            label: "HTTP Port",
                            hint: "💡 開啟 BetterDisplay > 偏好設定 > API，查看 HTTP Port",
                            isRequired: true
                        ) {
                            TextField("例如: 55777", value: $draftConfig.betterDisplayPort, format: .number.grouping(.never))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.asciiCapableNumberPad)
                                .frame(maxWidth: 80)
                        }
                        
                        // iPad UUID：必要，整合區塊
                        VStack(alignment: .leading, spacing: 8) {
                            // 第一列：必要 badge + 標題 + hint + ? 圖示
                            HStack(spacing: 4) {
                                Text("必要")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Theme.musicRed)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.musicRed.opacity(0.15)))
                                Text("iPad UUID")
                                    .foregroundStyle(Theme.musicRed)
                                Text("💡 點下方按鈕自動取得，或點 ? 查看手動方式")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Button { showHelp = .uuid } label: {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // 第二列：[膠囊按鈕] + [UUID 輸入框] 同一行
                            HStack(spacing: 10) {
                                Button {
                                    Task { await fetchUUID() }
                                } label: {
                                    HStack(spacing: 5) {
                                        if isFetchingUUID {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "arrow.down.circle.fill")
                                        }
                                        Text(isFetchingUUID ? "取得中..." : "從 SSH 自動取得 UUID")
                                            .fontWeight(.medium)
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(isFetchingUUID ? Color.gray : Theme.musicRed)
                                            .shadow(color: Theme.musicRed.opacity(isFetchingUUID ? 0 : 0.3),
                                                    radius: 6, x: 0, y: 3)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isFetchingUUID)
                                .fixedSize() // 按鈕不被壓縮
                                
                                TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
                                          text: $draftConfig.iPadUUID)
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .font(.caption.monospaced())
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )
                            }
                            
                            if let error = fetchUUIDError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    // MARK: Tailscale 遠距連線（選填）
                    Section("遠距連線設定") {
                        // Tailscale IP：選填，僅外部網路遠端連線時需要
                        InlineHintRow(
                            label: "Tailscale IP",
                            hint: "💡 在 Mac 終端機執行 tailscale ip 取得",
                            isRequired: false
                        ) {
                            TextField("例如: 100.x.x.x", text: $draftConfig.tailscaleIP)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(maxWidth: 160)
                        }
                    }
                    
                    // Add padding to prevent the last content being obscured by potential tab bar or safe area
                    Color.clear.frame(height: 60)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .scrollDismissesKeyboard(.immediately)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 70) // Match floating bar container height
                }
                
                // MARK: Floating Action Bar
                HStack(spacing: 20) {
                    // Save Button
                    Button {
                        saveSettings()
                    } label: {
                        HStack {
                            Image(systemName: showSaved ? "checkmark" : "square.and.arrow.down")
                            Text(showSaved ? "已儲存" : "儲存設定")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(showSaved ? .green : Theme.musicRed)
                                .shadow(color: (showSaved ? Color.green : Theme.musicRed).opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Reset Button
                    Button {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("重置")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray5))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                )
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
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
                        HelpContent(title: "Hostname 是什麼？如何查詢？",
                                    content: "這是你的 Mac 在區域網路上的識別位址，格式固定為「電腦名稱.local」。\n\n【查詢步驟】\n1. 前往「系統設定 > 一般 > 共享」\n2. 視窗最上方的「電腦名稱」即是你的設備名稱\n3. 在 Hostname 欄填入「電腦名稱.local」\n\n【常見範例】\n• Mac mini → Mac-mini.local\n• MacBook Pro → MacBook-Pro.local\n• iMac → iMac.local\n\n【為什麼用 .local？】\n.local 是 Apple Bonjour 的自動尋址機制，不需要設定固定 IP，只要兩台設備在同一個 Wi-Fi 或有線網路內，就能自動找到對方。")
                    case .username:
                        HelpContent(title: "如何找到使用者名稱？",
                                    content: "這不是你的全名 (例如: Ryan Chang)，而是系統的「帳號名稱」短名稱 (例如: ryanchang)。\n\n【最推薦方法】\n在 Mac 的終端機執行 `whoami`，回傳的小寫文字即是正確的名稱。\n\n【系統設定查看】\n1. 前往「系統設定 > 使用者與群組」。\n2. 在你的帳號名字上「按右鍵」或「按住 Control 鍵再點擊」。\n3. 選擇「進階選項...」。\n4. 視窗中的『帳號名稱』一欄才是正確的（注意：視窗頂端的『使用者名稱』通常是全名，並非 SSH 所需）。")
                    case .uuid:
                        HelpContent(title: "iPad UUID 是什麼？",
                                    content: "這是 Sidecar 辨識這台 iPad 的身分證字號。第一次設定的使用者，請務必先完成以下步驟：\n\n【第一步：建立信任紀錄】\n1. 使用 **USB 線** 將 iPad 連接至 Mac。\n2. 在 iPad 上點選「信任這部電腦」，並在 Mac 上點選「允許」。\n3. 在 Mac 的「系統設定 > 顯示器」點選『+』並嘗試啟動一次 Sidecar。只要成功啟動一次，系統就會留下紀錄。\n\n【如何手動獲取？】\n若自動取得失敗，請在 Mac 終端機執行：\n`system_profiler SPUSBDataType | grep -A 10 \"iPad\" | grep \"Serial Number\"` \n回傳的一長串代碼即是 UUID。\n\n💡 常見失敗原因：\n• 未曾用線連接過 Mac (無信任紀錄)\n• 兩台設備登入的是不同的 Apple ID\n• iPad 的「接續互通 (Handoff)」功能未開啟")
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
