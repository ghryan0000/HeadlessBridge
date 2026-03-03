import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var manager: ConnectionManager
    @State private var sshPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showSaved: Bool = false
    
    private let keychain = KeychainService.shared
    
    var body: some View {
        NavigationStack {
            Form {
                
                // MARK: Mac mini 基本設定
                Section {
                    LabeledContent("名稱") {
                        TextField("Mac mini", text: $manager.config.name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    LabeledContent("Hostname") {
                        TextField("Mac-mini.local", text: $manager.config.hostname)
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
                    LabeledContent("使用者名稱") {
                        TextField("ryanchang", text: $manager.config.sshUser)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    LabeledContent("Port") {
                        TextField("22", value: $manager.config.sshPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Text("SSH 密碼")
                        Spacer()
                        Group {
                            if showPassword {
                                TextField("密碼", text: $sshPassword)
                            } else {
                                SecureField("密碼", text: $sshPassword)
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
                        TextField("55777", value: $manager.config.betterDisplayPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    
                    LabeledContent("iPad UUID") {
                        TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
                                  text: $manager.config.iPadUUID)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.caption.monospaced())
                    }
                    
                    Button("從 SSH 自動取得 UUID") {
                        Task { await fetchUUID() }
                    }
                    .foregroundStyle(.blue)
                }
                
                // MARK: Tailscale 設定
                Section {
                    LabeledContent("Tailscale IP") {
                        TextField("100.x.x.x", text: $manager.config.tailscaleIP)
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
            .navigationTitle("設定")
            .onAppear {
                sshPassword = keychain.load(for: "ssh_password_\(manager.config.id)") ?? ""
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
        let password = keychain.load(for: "ssh_password_\(manager.config.id)") ?? sshPassword
        guard !password.isEmpty else { return }
        
        do {
            let result = try await SSHService.shared.executeCommand(
                host: manager.config.hostname,
                port: manager.config.sshPort,
                user: manager.config.sshUser,
                password: password,
                command: "betterdisplaycli get -sidecarList 2>/dev/null"
            )
            
            // 解析 UUID（格式：iPad名稱, UUID）
            let lines = result.components(separatedBy: "\n")
            for line in lines {
                let parts = line.components(separatedBy: ", ")
                if parts.count >= 2 {
                    let uuid = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if uuid.count == 36 {
                        await MainActor.run {
                            manager.config.iPadUUID = uuid
                        }
                        break
                    }
                }
            }
        } catch {
            print("Failed to fetch UUID: \(error)")
        }
    }
}
