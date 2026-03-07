import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var manager: ConnectionManager
    @State private var sshPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showSaved: Bool = false
    @State private var showHelp: HelpType? = nil
    @State private var isFetchingUUID: Bool = false
    @State private var fetchUUIDError: String?
    
    private let keychain = KeychainService.shared
    
    enum HelpType: Identifiable {
        case hostname, username, uuid
        var id: Int { hashValue }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                
                // MARK: Mac mini 基本設定
                Section {
                    LabeledContent("名稱") {
                        TextField("例如: Mac mini", text: $manager.config.name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Hostname")
                        Button { showHelp = .hostname } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        TextField("例如: Mac-mini.local", text: $manager.config.hostname)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("Mac mini 設定")
                } footer: {
                    Text("建議使用 Mac-mini.local，任何網路下都有效")
                }
                
                // MARK: SSH 設定
                Section("SSH 設定") {
                    HStack {
                        Text("使用者名稱")
                        Button { showHelp = .username } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        TextField("例如: ryanchang", text: $manager.config.sshUser)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    LabeledContent("Port") {
                        TextField("例如: 22", value: $manager.config.sshPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Text("SSH 密碼")
                        Spacer()
                        Group {
                            if showPassword {
                                TextField("例如: 123456", text: $sshPassword)
                            } else {
                                SecureField("例如: 123456", text: $sshPassword)
                            }
                        }
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200)
                        
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // MARK: BetterDisplay 設定
                Section("BetterDisplay 設定") {
                    LabeledContent("HTTP Port") {
                        TextField("例如: 55777", value: $manager.config.betterDisplayPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Text("iPad UUID")
                        Button { showHelp = .uuid } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
                                  text: $manager.config.iPadUUID)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.caption.monospaced())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            Task { await fetchUUID() }
                        } label: {
                            HStack {
                                if isFetchingUUID {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                }
                                Text(isFetchingUUID ? "取得中..." : "從 SSH 自動取得 UUID")
                            }
                        }
                        .foregroundStyle(.blue)
                        .disabled(isFetchingUUID)
                        
                        if let error = fetchUUIDError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                // MARK: Tailscale 設定
                Section {
                    LabeledContent("Tailscale IP") {
                        TextField("例如: 100.x.x.x", text: $manager.config.tailscaleIP)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                    }
                } header: {
                    Text("遠距連線設定")
                } footer: {
                    Text("在 Mac mini 終端機執行 tailscale ip 取得")
                }
                
                // MARK: 儲存按鈕
                Section {
                    Button {
                        saveSettings()
                    } label: {
                        HStack {
                            Spacer()
                            Label(showSaved ? "已儲存 ✓" : "儲存設定", 
                                  systemImage: showSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.headline)
                                .foregroundStyle(showSaved ? .green : .white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(showSaved ? Color.green.opacity(0.2) : Color.blue)
                }
                
                // MARK: 危險操作
                Section("重置") {
                    Button(role: .destructive) {
                        manager.clearAllSettings()
                        sshPassword = ""
                    } label: {
                        Label("清除所有設定", systemImage: "trash")
                    }
                }
            }
            .onAppear {
                sshPassword = keychain.load(for: "ssh_password_\(manager.config.id)") ?? ""
            }
            .sheet(item: $showHelp) { type in
                HelpSheet(type: type)
            }
        }
    }
    
    // MARK: - Save Settings
    private func saveSettings() {
        manager.saveConfig()
        if !sshPassword.isEmpty {
            keychain.save(password: sshPassword, for: "ssh_password_\(manager.config.id)")
        }
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
                    host: manager.config.hostname,
                    port: manager.config.sshPort,
                    user: manager.config.sshUser,
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
            print("Failed to fetch UUID: \(error)")
            fetchUUIDError = "連線失敗: \(error.localizedDescription)"
        }
    }
    
    private func updateUUID(_ uuid: String) {
        Task { @MainActor in
            manager.config.iPadUUID = uuid
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
                                    content: "這是你的 Mac mini 在區域網路上的身分證。你可以前往「系統設定 > 一般 > 共享」，在視窗最下方找到「電腦可以透過以下方式存取：Mac-mini.local」。通常建議填入 XXXXX.local。")
                    case .username:
                        HelpContent(title: "如何找到使用者名稱？",
                                    content: "這不是你的全名，而是系統短名稱。請在 Mac 的終端機執行 `whoami`，回傳的小寫文字就是你的使用者名稱。或是前往「系統設定 > 使用者與群組」，點選頭像後的「進階選項」查看「帳號名稱」。")
                    case .uuid:
                        HelpContent(title: "iPad UUID 是什麼？",
                                    content: "這是 Sidecar 用來精準識別這台 iPad 的專屬代碼 (Identifier)。當連線時，系統必須確認是要連到哪一台 iPad。\n\n💡 發生『連線失敗』的常見原因：\n1. 密碼或帳號錯誤 (Error 4: 權限被拒)\n2. Mac 與 iPad 不在同一個 Wi-Fi 網域內\n3. Mac 與 iPad 從未透過 USB 線配對信任過\n\n建議你先確認 SSH 帳號密碼是否正確再試一次。你也可以在 Mac 終端機執行 `system_profiler SPSidecarReporter | grep 'Identifier:'` 來手動獲取 UUID。")
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
