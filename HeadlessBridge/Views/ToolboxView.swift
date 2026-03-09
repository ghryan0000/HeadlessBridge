import SwiftUI

struct ToolboxView: View {
    @Binding var columnVisibility: NavigationSplitViewVisibility
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("通用工具")) {
                    NavigationLink {
                        UserManualView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("使用者操作手冊")
                                    .font(.headline)
                                Text("詳細的操作步驟及技術名詞說明")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "book.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        TroubleshootingDetailsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("故障排除指南")
                                    .font(.headline)
                                Text("常見連線問題與排解步驟")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(.orange)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("連線記錄")
                                    .font(.headline)
                                Text("查看過去的連線紀錄與統計數據")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.blue)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("即將推出")) {
                    HStack(spacing: 12) {
                        Image(systemName: "speedometer")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("網絡測速")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("預留給未來的連線品質測試工具")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

#Preview {
    ToolboxView(columnVisibility: .constant(.all))
}

// MARK: - Troubleshooting Details View
struct TroubleshootingDetailsView: View {
    let guides: [(String, String, String)] = [
        ("SSH 連線失敗", "key.fill", "確認 Mac 系統設定 > 共享 > 遠端登入已開啟，並確認帳號密碼正確"),
        ("BetterDisplay 未回應", "display", "確認 BetterDisplay App 在 Mac 上已啟動並出現在選單列"),
        ("找不到 Mac", "magnifyingglass", "確認 iPad 和 Mac 在同一網路，或用 USB-C 線直連"),
        ("Sidecar 沒有啟動", "rectangle.on.rectangle", "確認 iPad UUID 正確，可在設定頁點「自動取得 UUID」"),
        ("Tailscale 延遲高", "tortoise.fill", "確認兩台設備顯示 direct 直連，避免走 DERP 中繼伺服器")
    ]
    
    var body: some View {
        List(guides, id: \.0) { guide in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: guide.1)
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(guide.0)
                        .font(.subheadline.bold())
                    Text(guide.2)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("故障排除指南")
    }
}

// MARK: - User Manual View
struct UserManualView: View {
    var body: some View {
        List {
            Section("📖 核心概念 (Core Concepts)") {
                ManualRow(title: "什麼是 HeadlessBridge？",
                          icon: "bridge",
                          content: "這是一款讓 iPad 變成 Mac 完美第二螢幕的工具。它透過 SSH 技術自動化控制 Mac 的 Sidecar 功能，讓你可以「無頭 (Headless)」啟動鏡像，不需要在 Mac 上手動操作。")
                
                ManualRow(title: "專有名詞白話文",
                          icon: "character.book.closed.fill",
                          content: """
                          • Hostname: Mac 在區域網路的小名 (例如: My-Mac.local)。
                          • SSH: 一種加密的「遙控通道」，App 透過它對 Mac 下完指令。
                          • UUID: 每台 iPad 獨一無二的身分證字號，用來告訴 Mac 要投影到哪台。
                          • Sidecar: Apple 內建的無線/有線螢幕鏡像技術。
                          """)
            }
            
            Section("🚀 第一次設定 (First-time Setup)") {
                ManualRow(title: "第一步：USB 配對信任",
                          icon: "cable.connector",
                          content: "第一次使用時，請務必先用 USB 線連接 iPad 與 Mac。在兩端點選「信任」並輸入密碼。這是為了確保 Mac 擁有喚醒這台 iPad 的權限。")
                
                ManualRow(title: "第二步：啟動遠端登入 (SSH)",
                          icon: "lock.fill",
                          content: "在 Mac 前往「系統設定 > 一般 > 共享」，開啟「遠端登入」。並在 iPad App 的設定頁填入正確的帳號與密碼。")
                
                ManualRow(title: "第三步：取得 UUID",
                          icon: "ipad.badge.play",
                          content: "在 iPad 連接 Mac 的狀態下，點選設定頁的「從 SSH 自動取得 UUID」。若成功出現一長串代碼，即代表設定完成！")
            }
            
            Section("💡 日常操作與技巧 (Tips)") {
                ManualRow(title: "有線 vs 無線",
                          icon: "wifi",
                          content: "有線連線 (USB) 延遲最低、畫質最穩；無線連線則需要兩台設備在同一個 Wi-Fi 網域內。")
                
                ManualRow(title: "關閉 VPN 是關鍵",
                          icon: "v_square.fill",
                          content: "VPN 會隱藏你的區域網路。如果你發現「診斷失敗」或「找不到 Mac」，請先暫時關閉 iPad 上的 VPN 再試一次。")
            }

            Section("📺 全螢幕優化 (Full-Screen Optimization)") {
                ManualRow(title: "第一步：隱藏 Sidecar 工具列",
                          icon: "menubar.rectangle",
                          content: "在 Mac 前往「系統設定 > 顯示器 > Sidecar 設置 (點選 iPad)」，關閉『顯示側邊欄 (Show Sidebar)』與『顯示觸控列 (Show Touch Bar)』。這能移除 iPad 兩側與底部的黑邊。")
                
                ManualRow(title: "第二步：解決比例不合黑邊",
                          icon: "arrow.up.left.and.arrow.down.right",
                          content: "由於 iPad 螢幕比例 (4:3) 與 Mac (16:10) 不同，可能會有上下黑邊。本 App 已整合 BetterDisplay，建議透過其 API 建立一個與 iPad 解析度一致的「虛擬顯示器」，並將其鏡像至 iPad 即可達成完美全螢幕。")
            }

            Section("🖋️ Apple Pencil 進階操作 (Advanced Interaction)") {
                ManualRow(title: "精準操作映射",
                          icon: "pencil.and.outline",
                          content: "• 筆尖點擊：等同於滑鼠左鍵。\n• 筆尖拖曳：等同於按住滑鼠左鍵（可用於拖視窗或選取文字）。\n• 懸浮感應：若 iPad 支援，靠近螢幕可連動 Mac 鼠標移位。")
                
                ManualRow(title: "如何捲動視窗？",
                          icon: "scroll.fill",
                          content: "Apple Pencil 本身不支援手勢捲動。請直接使用筆尖「拖曳視窗右側的捲動軸」，或使用極力推薦的「指筆並用」法。")
                
                ManualRow(title: "指筆並用：效率最高",
                          icon: "hand.tap.fill",
                          content: "💡 這是 Sidecar 的隱藏技巧：左手手指直接滑動螢幕來「捲動畫面」，右手持 Apple Pencil 負責「精準點擊與操作」。這比單用任何一種工具都快。")
            }
        }
        .navigationTitle("使用者操作手冊")
    }
}

struct ManualRow: View {
    let title: String
    let icon: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(.vertical, 8)
    }
}
