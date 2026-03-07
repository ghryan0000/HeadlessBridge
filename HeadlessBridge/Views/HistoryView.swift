import SwiftUI

// MARK: - History View
struct HistoryView: View {
    @EnvironmentObject var manager: ConnectionManager
    
    var body: some View {
        Group {
            if manager.history.isEmpty {
                EmptyHistoryView()
            } else {
                List {
                    // Stats Summary
                    Section {
                        StatsRow()
                    }
                    
                    // History List
                    Section("連線記錄") {
                        ForEach(manager.history) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                }
            }
        }
        .navigationTitle("連線記錄")
        .toolbar {
            if !manager.history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            manager.history = []
                        }
                    } label: {
                        Text("清除")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Stats Row
struct StatsRow: View {
    @EnvironmentObject var manager: ConnectionManager
    
    var wiredCount: Int {
        manager.history.filter { $0.mode == ConnectionMode.wired.rawValue }.count
    }
    var wirelessCount: Int {
        manager.history.filter { $0.mode == ConnectionMode.wireless.rawValue }.count
    }
    var remoteCount: Int {
        manager.history.filter { $0.mode == ConnectionMode.remote.rawValue }.count
    }
    var successRate: Int {
        guard !manager.history.isEmpty else { return 0 }
        let successful = manager.history.filter { $0.success }.count
        return Int(Double(successful) / Double(manager.history.count) * 100)
    }
    
    var body: some View {
        HStack {
            StatItem(value: "\(wiredCount)", label: "有線", icon: "cable.connector", color: .blue)
            Divider()
            StatItem(value: "\(wirelessCount)", label: "無線", icon: "wifi", color: .green)
            Divider()
            StatItem(value: "\(remoteCount)", label: "遠距", icon: "globe", color: .orange)
            Divider()
            StatItem(value: "\(successRate)%", label: "成功率", icon: "chart.line.uptrend.xyaxis", color: .purple)
        }
        .padding(.vertical, 8)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let entry: ConnectionHistory
    
    var modeIcon: String {
        switch entry.mode {
        case ConnectionMode.wired.rawValue:    return "cable.connector"
        case ConnectionMode.wireless.rawValue: return "wifi"
        case ConnectionMode.remote.rawValue:   return "globe"
        default: return "display"
        }
    }
    
    var modeColor: Color {
        switch entry.mode {
        case ConnectionMode.wired.rawValue:    return .blue
        case ConnectionMode.wireless.rawValue: return .green
        case ConnectionMode.remote.rawValue:   return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: modeIcon)
                .foregroundStyle(modeColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.mode)
                    .font(.subheadline.bold())
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(entry.success ? .green : .red)
                if entry.success && entry.duration > 0 {
                    Text(entry.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Empty State
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("尚無連線記錄")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("連線後記錄會顯示在這裡")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}
