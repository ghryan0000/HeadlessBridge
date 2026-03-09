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
            Section("📌 核心設定順序 (The Golden Order)") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("請按此順序操作，保證設定成功：")
                        .font(.subheadline.bold())
                    
                    HStack(alignment: .top, spacing: 10) {
                        Text("1").font(.caption.bold()).padding(6).background(Circle().fill(.blue.opacity(0.1)))
                        Text("在 Mac 安裝 BetterDisplay 並開啟 API")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text("2").font(.caption.bold()).padding(6).background(Circle().fill(.blue.opacity(0.1)))
                        Text("在 Mac/iPad 安裝 Tailscale 並登入同帳號")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text("3").font(.caption.bold()).padding(6).background(Circle().fill(.blue.opacity(0.1)))
                        Text("透過 USB 先連通一次（信任設備）")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text("4").font(.caption.bold()).padding(6).background(Circle().fill(.blue.opacity(0.1)))
                        Text("於本 App 設定頁「自動取得 UUID」")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text("5").font(.caption.bold()).padding(6).background(Circle().fill(.blue.opacity(0.1)))
                        Text("切換至「遠端 VNC」模式並啟動")
                    }
                }
                .padding(.vertical, 8)
            }

            Section("⚡ 有線 Sidecar (最短延遲、最穩定的選擇)") {
                ManualRow(title: "第一步：準備導線",
                          icon: "cable.connector",
                          content: "建議使用高品質的數據線（如 iPad 原廠線）。良好的線材是影像傳輸不中斷的關鍵。")
                
                ManualRow(title: "第二步：物理連接與信任",
                          icon: "lock.shield",
                          content: "插入連線後，若 iPad 詢問「要信任此電腦嗎？」，請點選「信任」並輸入螢幕密碼。這是為了授予 Mac 遙控螢幕的權限。")
                
                ManualRow(title: "第三步：啟動連線",
                          icon: "play.fill",
                          content: "在本 App 首頁上方選擇「有線 Sidecar」模式，接著點擊中央的紅色「啟動」大按鈕。")
            }
            
            Section("📶 無線 Sidecar (擺脫線材、自由移動)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("無線模式對設備環境要求較高，請務必確認以下三點：")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    ManualRow(title: "1. 帳號與通訊",
                              icon: "person.crop.circle.badge.checkmark",
                              content: "iPad 與 Mac 必須登入「同一個 Apple ID」，且兩端皆須開啟「藍牙」與「Wi-Fi」。")
                    
                    ManualRow(title: "2. 接力功能 (Handoff)",
                              icon: "arrow.right.circle.fill",
                              content: "請在兩端系統設定中確認「接力 (Handoff)」功能已開啟。這是無線投影的核心。")
                    
                    ManualRow(title: "3. 距離與頻段",
                              icon: "wifi",
                              content: "設備距離請保持在 10 公尺內，且建議連接至相同的 5GHz Wi-Fi 以獲得最佳流暢度。")
                }
            }

            Section("🌐 Tailscale：您的專屬虛擬隧道") {
                ManualRow(title: "第一步：下載與註冊",
                          icon: "arrow.down.circle.fill",
                          content: "• Mac：至 tailscale.com 下載安裝檔案。\n• iPad：於 App Store 搜尋「Tailscale」下載。\n• 註冊：點擊「Login」，建議選 Google 或 Apple 直接登入。")
                
                ManualRow(title: "第二步：取得 VPN IP",
                          icon: "magnifyingglass.circle.fill",
                          content: "兩台設備皆登入後，點擊 Mac 選單列上的 Tailscale 小圖示。找到以「100.」開頭的一串數字（例如 100.81.2.3），這就是 Mac 的虛擬身分證字號。")
                
                ManualRow(title: "第三步：填入設定",
                          icon: "square.and.pencil",
                          content: "回到本 App 的「設定連線參數」，在「Hostname / IP」處刪除原本的文字，改填入剛才取得的「100.xxx.xxx.xxx」。")
            }

            Section("📺 BetterDisplay：全螢幕與控制橋樑") {
                ManualRow(title: "第一步：安裝與權限",
                          icon: "display",
                          content: "至 betterdisplay.pro 下載並安裝。啟動後若系統詢問權限，請務必點選「允許」。")
                
                ManualRow(title: "第二步：開啟控制開關 (重要！)",
                          icon: "bolt.horizontal.circle.fill",
                          content: "在 Mac BetterDisplay 設定中，點擊「Settings > Advanced」，向下捲動找到「Enable HTTP API」並勾選它。沒有這一步，App 就無法控制 Mac。")
                
                ManualRow(title: "第三步：新增虛擬顯示器 (Dummy)",
                          icon: "plus.square.fill",
                          content: "1. 點擊「Settings > Displays」。\n2. 點擊「Create New Virtual Screen (Dummy)」。\n3. 建議選擇 2048x1536 (iPad 比例)。\n4. 建立後，將此虛擬器「鏡像 (Mirror)」至您的 iPad。這能完美解決上下黑邊問題。")
            }

            Section("❓ 常見問題白話文") {
                ManualRow(title: "為什麼要用這兩個 App？",
                          icon: "questionmark.circle",
                          content: "Tailscale 負責「挖地道」讓連線穿過牆；BetterDisplay 則是「導遊」，負責把 Mac 的畫面正確打包並送上地道。")
                
                ManualRow(title: "Hostname 是什麼？",
                          icon: "character",
                          content: "就是 Mac 的門牌號碼。在家用「Mac的名字.local」，在外遠距請一定要用「Tailscale 的 IP」。")
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
