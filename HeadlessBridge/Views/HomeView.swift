import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var manager: ConnectionManager
    @State private var showModeSelector = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: Status Card
                    StatusCard()
                    
                    // MARK: Connect Button
                    ConnectButton()
                    
                    // MARK: Mode Selector
                    ModeSelectorCard()
                    
                    // MARK: Environment Info
                    EnvironmentCard()
                    
                    // MARK: Quick Actions
                    QuickActionsCard()
                }
                .padding()
            }
            .navigationTitle("HeadlessBridge")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await manager.runDiagnostics() }
                    } label: {
                        Image(systemName: "stethoscope")
                    }
                }
            }
            .refreshable {
                manager.environment = await NetworkService.shared.detectEnvironment(config: manager.config)
            }
        }
    }
}

// MARK: - Status Card
struct StatusCard: View {
    @EnvironmentObject var manager: ConnectionManager
    
    var statusColor: Color {
        switch manager.status {
        case .connected:     return .green
        case .failed:        return .red
        case .disconnected:  return .gray
        default:             return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                if manager.status.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(statusColor)
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: 44))
                        .foregroundStyle(statusColor)
                }
            }
            .animation(.easeInOut, value: manager.status.isConnected)
            
            // Status Text
            VStack(spacing: 4) {
                Text(manager.status.displayText)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                
                if manager.status.isConnected, !manager.connectionDuration.isEmpty {
                    Text("連線時間：\(manager.connectionDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                
                if let ssid = manager.environment.wifiSSID {
                    Text("Wi-Fi：\(ssid)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    var statusIcon: String {
        switch manager.status {
        case .connected(let mode):
            switch mode {
            case .wired:    return "cable.connector.horizontal"
            case .wireless: return "wifi"
            case .remote:   return "globe"
            case .auto:     return "display"
            }
        case .failed:       return "exclamationmark.triangle.fill"
        case .disconnected: return "display.slash"
        default:            return "display"
        }
    }
}

// MARK: - Connect Button
struct ConnectButton: View {
    @EnvironmentObject var manager: ConnectionManager
    
    var body: some View {
        Button {
            if manager.status.isConnected {
                manager.disconnect()
            } else {
                Task { await manager.smartConnect() }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: manager.status.isConnected ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                
                Text(manager.status.isConnected ? "中斷連線" : "智慧連線")
                    .font(.title3.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(manager.status.isConnected ? Color.red : Color.blue)
            )
            .foregroundStyle(.white)
        }
        .disabled(manager.status.isLoading)
        .opacity(manager.status.isLoading ? 0.6 : 1.0)
        .animation(.easeInOut, value: manager.status.isConnected)
    }
}

// MARK: - Mode Selector Card
struct ModeSelectorCard: View {
    @EnvironmentObject var manager: ConnectionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("連線模式")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    ModeButton(mode: mode)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ModeButton: View {
    @EnvironmentObject var manager: ConnectionManager
    let mode: ConnectionMode
    
    var isSelected: Bool {
        manager.selectedMode == mode
    }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                manager.selectedMode = mode
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title3)
                Text(mode.rawValue)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Environment Card
struct EnvironmentCard: View {
    @EnvironmentObject var manager: ConnectionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("環境偵測")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                EnvironmentRow(
                    icon: "cable.connector",
                    label: "USB-C 連接",
                    isActive: manager.environment.isUSBConnected
                )
                Divider()
                EnvironmentRow(
                    icon: "wifi",
                    label: "同一網路",
                    isActive: manager.environment.isOnSameNetwork
                )
                Divider()
                EnvironmentRow(
                    icon: "lock.shield",
                    label: "Tailscale VPN",
                    isActive: manager.environment.isTailscaleActive
                )
                
                if let latency = manager.environment.latencyMs {
                    Divider()
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("延遲")
                        Spacer()
                        Text(String(format: "%.0f ms", latency))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct EnvironmentRow: View {
    let icon: String
    let label: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isActive ? .green : .gray)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isActive ? .green : .red)
        }
    }
}

// MARK: - Quick Actions Card
struct QuickActionsCard: View {
    @EnvironmentObject var manager: ConnectionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速操作")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "arrow.clockwise",
                    label: "重新偵測",
                    color: .blue
                ) {
                    Task {
                        manager.environment = await NetworkService.shared.detectEnvironment(config: manager.config)
                    }
                }
                
                QuickActionButton(
                    icon: "stethoscope",
                    label: "診斷",
                    color: .orange
                ) {
                    Task { await manager.runDiagnostics() }
                }
                
                QuickActionButton(
                    icon: "arrow.counterclockwise",
                    label: "重新連線",
                    color: .green
                ) {
                    manager.disconnect()
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await manager.smartConnect()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
