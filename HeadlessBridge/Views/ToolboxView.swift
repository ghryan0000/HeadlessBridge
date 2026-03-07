import SwiftUI

struct ToolboxView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("通用工具")) {
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
    ToolboxView()
}

// MARK: - Troubleshooting Details View
struct TroubleshootingDetailsView: View {
    let guides: [(String, String, String)] = [
        ("SSH 連線失敗", "key.fill", "確認 Mac mini 系統設定 > 共享 > 遠端登入已開啟，並確認帳號密碼正確"),
        ("BetterDisplay 未回應", "display", "確認 BetterDisplay App 在 Mac mini 上已啟動並出現在選單列"),
        ("找不到 Mac mini", "magnifyingglass", "確認 iPad 和 Mac mini 在同一網路，或用 USB-C 線直連"),
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
