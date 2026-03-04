import SwiftUI

// MARK: - Diagnostic View
struct DiagnosticView: View {
    @EnvironmentObject var manager: ConnectionManager
    @Binding var selectedSidebarItem: SidebarItem?
    @Binding var selectedTab: SidebarItem
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Run Button
                    Button {
                        Task { await manager.runDiagnostics() }
                    } label: {
                        HStack(spacing: 12) {
                            if manager.isRunningDiagnostic {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "stethoscope")
                                    .font(.title3)
                            }
                            Text(manager.isRunningDiagnostic ? "診斷中..." : "開始診斷")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(manager.isRunningDiagnostic ? Color.gray : Color.orange)
                        )
                        .foregroundStyle(.white)
                    }
                    .disabled(manager.isRunningDiagnostic)
                    .padding(.horizontal)
                    
                    // Results
                    if !manager.diagnosticResults.isEmpty {
                        DiagnosticResultsCard(selectedSidebarItem: $selectedSidebarItem, selectedTab: $selectedTab)
                    } else {
                        EmptyDiagnosticView()
                    }
                    
                    // Troubleshooting Guide
                    TroubleshootingGuideCard()
                }
                .padding(.vertical)
            }
            .navigationTitle("系統診斷")
        }
    }
}

// MARK: - Diagnostic Results Card
struct DiagnosticResultsCard: View {
    @EnvironmentObject var manager: ConnectionManager
    @Binding var selectedSidebarItem: SidebarItem?
    @Binding var selectedTab: SidebarItem
    
    var allPassed: Bool {
        manager.diagnosticResults.allSatisfy { $0.status == .pass }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("診斷結果")
                    .font(.headline)
                Spacer()
                if allPassed {
                    Label("全部通過", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            ForEach(manager.diagnosticResults) { result in
                DiagnosticRow(result: result, 
                              selectedSidebarItem: $selectedSidebarItem, 
                              selectedTab: $selectedTab)
                if result.id != manager.diagnosticResults.last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

struct DiagnosticRow: View {
    let result: DiagnosticResult
    @Binding var selectedSidebarItem: SidebarItem?
    @Binding var selectedTab: SidebarItem
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var color: Color {
        switch result.status {
        case .pass:     return .green
        case .fail:     return .red
        case .warning:  return .orange
        case .checking: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.status.icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.item)
                    .font(.subheadline.bold())
                Text(result.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if result.status == .checking {
                ProgressView()
                    .scaleEffect(0.8)
            } else if result.status == .fail || result.status == .warning {
                Button {
                    // 導向設定頁面
                    if sizeClass == .regular {
                        selectedSidebarItem = .settings
                    } else {
                        selectedTab = .settings
                    }
                } label: {
                    Text("如何修復？")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.1))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Empty State
struct EmptyDiagnosticView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "stethoscope.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("點擊「開始診斷」")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("自動檢查所有連線元件")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }
}

// MARK: - Troubleshooting Guide
struct TroubleshootingGuideCard: View {
    @State private var isExpanded = false
    
    let guides: [(String, String, String)] = [
        ("SSH 連線失敗", "key.fill", "確認 Mac mini 系統設定 > 共享 > 遠端登入已開啟，並確認帳號密碼正確"),
        ("BetterDisplay 未回應", "display", "確認 BetterDisplay App 在 Mac mini 上已啟動並出現在選單列"),
        ("找不到 Mac mini", "magnifyingglass", "確認 iPad 和 Mac mini 在同一網路，或用 USB-C 線直連"),
        ("Sidecar 沒有啟動", "rectangle.on.rectangle", "確認 iPad UUID 正確，可在設定頁點「自動取得 UUID」"),
        ("Tailscale 延遲高", "tortoise.fill", "確認兩台設備顯示 direct 直連，避免走 DERP 中繼伺服器")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("故障排除指南")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ForEach(guides, id: \.0) { guide in
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
                    if guide.0 != guides.last?.0 {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}
