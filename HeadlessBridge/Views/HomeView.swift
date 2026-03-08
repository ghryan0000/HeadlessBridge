import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var manager: ConnectionManager
    @Namespace private var animation
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: 瀏覽器 Tab 式 —— Tab 列 + 狀態卡片無縮合一
                    VStack(spacing: 0) {

                        // ── Tab 列 ──
                        ModeSelectorHeader(animation: animation)

                        // ── 內容卡片（Tab 下方，背景色與作動 Tab 一致）──
                        StatusHeaderView()
                            .padding(24)
                            .frame(minHeight: 300) // 增加高度以容納下移
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray5))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)
                    .padding(.top, 16) // Restored from 0

                    // MARK: 診斷區塊
                    ConnectionDiagnosticSection()
                        .padding(.vertical, 2.0)       // 再次縮減容器內高度 (由 4.4 降至 2.0)
                        .padding(.horizontal, 5.5)
                        .background(
                            RoundedRectangle(cornerRadius: 36)
                                .fill(Color(.systemGray5))     // 底色與作動 Tab 一致
                                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                        .padding(.top, 18)            // 加寬與上方區塊的間隔 (原 10)
                }
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .refreshable {
                manager.environment = await NetworkService.shared.detectEnvironment(config: manager.config)
            }
        }
    }
}

// MARK: - Mode Selector Header
struct ModeSelectorHeader: View {
    @EnvironmentObject var manager: ConnectionManager
    var animation: Namespace.ID

    private var orderedModes: [ConnectionMode] {
        [.wired, .wireless, .remote, .auto]
    }

    var body: some View {
        // Tab 列：中央 70%，左右各留 15%
        GeometryReader { geo in
            HStack(spacing: 4) { // tab 之間加微小間隔
                ForEach(orderedModes, id: \.self) { mode in
                    ModeItem(mode: mode, isSelected: manager.selectedMode == mode)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                manager.selectedMode = mode
                            }
                            if mode != .auto {
                                manager.connect(mode: mode)
                            } else {
                                manager.smartConnect()
                            }
                        }
                }
            }
            .frame(width: geo.size.width * 0.7)
            .frame(maxWidth: .infinity)   // 讓它在父容器中水平置中
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .frame(height: 80)   // 固定 Tab 列高度
    }
}

// MARK: - Mode Item
struct ModeItem: View {
    let mode: ConnectionMode
    let isSelected: Bool

    // 作動中 tab：變淡 20%（Gray4 -> Gray5）；非作動：底色再變淡 20%
    private var tabBg: Color {
        isSelected ? Color(.systemGray5) : Color(.tertiarySystemFill).opacity(0.8)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mode.icon)
                .font(.system(size: 22, weight: .medium))
                .scaleEffect(mode == .wired ? 0.8 : 1.0) // 縮減 USB 圖示使高度與 Wi-Fi 一致
                .foregroundStyle(isSelected ? Theme.musicRed : .secondary)

            VStack(spacing: 2) {
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.musicRed : .primary)
                    .lineLimit(1)
                
                Text(modeSubtitle)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(tabBg)
        // 已選中：上圆角，下方直角（與内容區無縮連接）
        // 未選中：四角均小圆
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: isSelected ? 0 : 6,
                bottomTrailingRadius: isSelected ? 0 : 6,
                topTrailingRadius: 16
            )
        )
        .overlay(
            // 選中 tab 頂部加一條藍色指示線（6pt 加粗，圓角設計）
            isSelected ?
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.musicRed)
                .frame(height: 6)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
            : nil
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var modeSubtitle: String {
        switch mode {
        case .auto:     return "環境優先"
        case .wired:    return "USB 有線連線"
        case .wireless: return "Wi-Fi 連線"
        case .remote:   return "VPN 延遲優化"
        }
    }
}

// MARK: - Triangle Indicator
struct TriangleIndicator: View {
    let selectedMode: ConnectionMode
    
    private var offset: CGFloat {
        switch selectedMode {
        case .wired:    return -157   // 第 1 個
        case .wireless: return -52.5  // 第 2 個
        case .remote:   return 52.5   // 第 3 個
        case .auto:     return 157.5  // 第 4 個（最右）
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .frame(width: 20, height: 12)
                .foregroundStyle(Color(.secondarySystemBackground))
                .offset(x: offset)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedMode)
        }
        .frame(height: 12)
        .zIndex(1) // Ensure triangle is above the card
    }
}

// MARK: - Status & Connect Section
struct StatusHeaderView: View {
    @EnvironmentObject var manager: ConnectionManager

    var statusColor: Color {
        switch manager.status {
        case .connected:    return Theme.musicRed
        case .failed:       return .red
        case .disconnected: return .gray
        default:            return Theme.musicRed
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Row 1: 狀態 label ──────────────
            HStack(spacing: 6) {
                Text("連線狀態")
                    .font(.system(size: 15, weight: .bold)) // 15pt Bold
                    .foregroundStyle(Color(white: 0.3))
            }

            // ── Row 2: 連線網路架構圖 ────────────────────
            // .id() 讓 SwiftUI 在狀態改變時完整重建 View，
            // onAppear 重新觸發 → 動畫從乾淨初始狀態啟動（等同於從鏡像跳回）
            NetworkTopologyView(
                status: manager.status,
                mode: manager.selectedMode
            )
            .id("\(manager.status.isConnected)-\(manager.status.isLoading)-\(manager.selectedMode.rawValue)")
            .frame(height: 90)
            .padding(.top, 28) // 往下降 1 公分
            .transition(.opacity)

            // ── Row 3: 圓形按鈕 (左) + 狀態文字 (居中) ─────────────
            ZStack {
                // 狀態文字（保持整體居中）
                VStack(alignment: .center, spacing: 4) {
                    Text(manager.status.displayText)
                        .font(.system(size: 20, weight: .bold)) // 20pt Bold
                        .foregroundStyle(statusColor)

                    HStack(spacing: 8) {
                        Text(manager.status.isConnected ? "連線成功" : (manager.status.isLoading ? "連線中..." : "尚未連線"))
                            .font(.system(size: 15, weight: .regular)) // 15pt Regular
                            .foregroundStyle(manager.status.isConnected ? Theme.musicRed : Color(white: 0.3))
                        
                        // 累計時間：標籤 10pt Medium，數字 10pt Semibold Monospaced (移至此處)
                        if !manager.connectionDuration.isEmpty {
                            Text("|")
                                .font(.system(size: 10, weight: .light))
                                .foregroundStyle(Color(white: 0.5).opacity(0.35))
                            Text(manager.connectionDuration)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.musicRed.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // 圓形動作鈕（移至左側）
                HStack {
                    Button {
                        if manager.status.isConnected {
                            manager.disconnect()
                        } else {
                            manager.reconnect()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(manager.status.isConnected ? Color.red : Theme.musicRed)
                                .frame(width: 64, height: 64) // 尺寸縮減 20% (80->64)
                                .shadow(
                                    color: (manager.status.isConnected ? Color.red : Theme.musicRed).opacity(0.3),
                                    radius: 8, x: 0, y: 4
                                )

                            if manager.status.isLoading && !manager.status.isConnected {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                            } else {
                                VStack(spacing: 2) {
                                    Image(systemName: actionButtonIcon)
                                        .font(.system(size: 20, weight: .bold)) // 保持圖示大小
                                    Text(manager.status.isConnected ? "中斷" : "啟動")
                                        .font(.system(size: 11, weight: .bold)) // 改為 11pt
                                }
                                .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.status.isLoading && !manager.status.isConnected)
                    
                    Spacer() // 推向左側
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 8)
        }
    }

    private var actionButtonIcon: String {
        manager.status.isConnected ? "stop.fill" : "play.fill"
    }
}

// MARK: - Network Topology Diagram
struct NetworkTopologyView: View {
    let status: ConnectionStatus
    let mode: ConnectionMode

    // 動畫狀態（流動方向：由右向左，從 1.0 → 0.0）
    @State private var flowPhase: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.3
    @State private var glowRadius: CGFloat = 4

    // 依連線模式選色
    private var modeColor: Color {
        switch mode {
        case .wired:    return Theme.musicRed
        case .wireless: return .green
        case .remote:   return .orange
        case .auto:     return .purple
        }
    }

    // 連線模式中文標示
    private var modeLabel: String {
        switch mode {
        case .wired:    return "USB-C 有線"
        case .wireless: return "Wi-Fi 無線"
        case .remote:   return "VPN 遠端"
        case .auto:     return "自動選擇"
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let iconSize: CGFloat = 36
            // 內縮 120pt，讓設備更靠近中間
            let leftCenter  = CGPoint(x: iconSize / 2 + 120, y: h / 2)
            let rightCenter = CGPoint(x: w - iconSize / 2 - 120, y: h / 2)
            let midX        = w / 2
            let cp1 = CGPoint(x: midX - 20, y: h * 0.15)
            let cp2 = CGPoint(x: midX + 20, y: h * 0.85)

            ZStack {
                // ── 底線（靠背景虛線）──
                Path { p in
                    p.move(to: leftCenter)
                    p.addCurve(to: rightCenter, control1: cp1, control2: cp2)
                }
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: isConnected ? [] : [6, 5]
                    )
                )
                .foregroundStyle(
                    isConnected
                        ? modeColor.opacity(0.25)
                        : Color.secondary.opacity(0.3)
                )

                // ── 連線中：脈衝光暈線 ──
                if isConnecting {
                    Path { p in
                        p.move(to: leftCenter)
                        p.addCurve(to: rightCenter, control1: cp1, control2: cp2)
                    }
                    .stroke(modeColor.opacity(pulseOpacity), lineWidth: 3)
                    .blur(radius: 3)
                }

                // ── 已連線：流動光點（由右向左，flowPhase: 1→0）──
                if isConnected {
                    // 光暈軌跡：tail 在 flowPhase 右邊
                    Path { p in
                        p.move(to: leftCenter)
                        p.addCurve(to: rightCenter, control1: cp1, control2: cp2)
                    }
                    .trim(from: flowPhase, to: min(1.0, flowPhase + 0.18))
                    .stroke(
                        LinearGradient(
                            colors: [modeColor.opacity(0), modeColor, modeColor.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .blur(radius: glowRadius)

                    // 光點本體
                    Path { p in
                        p.move(to: leftCenter)
                        p.addCurve(to: rightCenter, control1: cp1, control2: cp2)
                    }
                    .trim(from: flowPhase, to: min(1.0, flowPhase + 0.04))
                    .stroke(modeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }

                // ── iPad 圖示（左） ──
                DeviceNode(symbol: "ipad", label: "iPad", color: modeColor, isActive: isConnected || isConnecting)
                    .frame(width: 100, height: h)
                    .position(x: leftCenter.x, y: h / 2)

                // ── Mac 三機型圖示（右）──
                MacDeviceNode(color: modeColor, isActive: isConnected)
                    .frame(width: 64, height: h)
                    .position(x: rightCenter.x, y: h / 2)

                // ── 中間線路標籤 ──
                VStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Image(systemName: modeIconName)
                            .font(.caption2)
                            .foregroundStyle(isConnected ? modeColor : .secondary)
                        Text(modeLabel)
                            .font(.system(size: 12, weight: .medium)) // 12pt Medium
                            .foregroundStyle(isConnected ? modeColor : .secondary)
                    }
                    .padding(.horizontal, 10) // 增加內縮以容納 12pt
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isConnected ? modeColor.opacity(0.1) : Color(.tertiarySystemBackground))
                            .overlay(
                                Capsule().stroke(
                                    isConnected ? modeColor.opacity(0.3) : Color.secondary.opacity(0.2),
                                    lineWidth: 1
                                )
                            )
                    )
                    
                    Text("HeadlessBridge")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .offset(y: 4)
                }
                .position(x: midX, y: h / 2)
            }
        }
        // .id() 在父層確保每次狀態改變，此 View 完整重建並重新觸發 onAppear。
        // 因此 onChange 已不必要，onAppear 即是唯一的動畫啟動點。
        .onAppear { startAnimations() }
        .animation(.easeInOut(duration: 0.5), value: isConnected)
    }

    // MARK: - Helpers
    private var isConnected: Bool  { status.isConnected }
    private var isConnecting: Bool { status.isLoading }

    private var modeIconName: String {
        switch mode {
        case .wired:    return "cable.connector"
        case .wireless: return "wifi"
        case .remote:   return "globe"
        case .auto:     return "wand.and.stars"
        }
    }

    private func startAnimations() {
        // 重設初始狀態
        flowPhase    = 1.0
        pulseOpacity = 0.3
        glowRadius   = 4

        // 因為 .id() 保證此函數將在全新的 onAppear 中執行，
        // 可安全使用同步 withAnimation 不會與舊動畫競爭
        if isConnecting {
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.9
            }
        } else if isConnected {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                flowPhase = 0.0
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.7
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowRadius = 12
            }
        }
    }
}

// MARK: - Device Node
private struct DeviceNode: View {
    let symbol: String
    let label: String
    let color: Color
    let isActive: Bool

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(color.opacity(0.15))
                        .scaleEffect(pulse ? 1.35 : 1.0)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                }
                Circle()
                    .fill(isActive ? color.opacity(0.12) : Color(.quaternarySystemFill))
                    .frame(width: 76, height: 76)
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(isActive ? color : .secondary)
            }
            .frame(width: 96, height: 96)

            Text(label)
                .font(.system(size: 16, weight: .semibold)) // 16pt Semibold
                .foregroundStyle(isActive ? color : .secondary)
        }
        .onAppear { if isActive { pulse = true } }
        .onChange(of: isActive, perform: { active in pulse = active })
    }
}

// MARK: - Mac Device Node（三機型：mini / Studio / Pro）
private struct MacDeviceNode: View {
    let color: Color
    let isActive: Bool

    @State private var pulse = false

    // Mac mini、Mac Studio、Mac Pro、MacBook 四種外形
    private let macIcons: [(symbol: String, tip: String)] = [
        ("macmini",            "mini"),
        ("macstudio",          "Studio"),
        ("macpro.gen3.server", "Pro"),
        ("laptopcomputer",     "MacBook")
    ]

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 呼吸光暈
                if isActive {
                    Circle()
                        .fill(color.opacity(0.15))
                        .scaleEffect(pulse ? 1.35 : 1.0)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                }
                Circle()
                    .fill(isActive ? color.opacity(0.12) : Color(.quaternarySystemFill))
                    .frame(width: 80, height: 80)

                // 四機型垂直排列 (mini / Studio / Pro / MacBook)
                VStack(spacing: 4) {
                    ForEach(macIcons, id: \.symbol) { item in
                        Image(systemName: item.symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isActive ? color : .secondary)
                    }
                }
            }
            .frame(width: 96, height: 96)

            Text("Mac")
                .font(.system(size: 16, weight: .semibold)) // 16pt Semibold
                .foregroundStyle(isActive ? color : .secondary)
        }
        .onAppear { if isActive { pulse = true } }
        .onChange(of: isActive, perform: { active in pulse = active })
    }
}

struct EnvironmentRow: View {
    let icon: String
    let label: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(isActive ? .green : .gray)
                .frame(width: 28)
            Text(label)
                .font(.subheadline.bold())
            Spacer()
            Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(isActive ? .green : .red)
        }
    }
}

// MARK: - Merged Diagnostic Section
struct ConnectionDiagnosticSection: View {
    @EnvironmentObject var manager: ConnectionManager
    @State private var isExpanded = false
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded.toggle()
                    // Auto-run diagnostics if expanded and empty
                    if isExpanded && manager.diagnosticResults.isEmpty {
                        Task { await manager.runDiagnostics() }
                    }
                }
            } label: {
                HStack {
                    Text("連線狀態診斷")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(white: 0.3))
                        .padding(.leading, 12) // Indent by about one character width
                    
                    Image(systemName: manager.isRunningDiagnostic ? "arrow.clockwise.circle.fill" : "magnifyingglass.circle.fill")
                        .font(.title) // 加大 1 倍 (由 title2 -> title)
                        .foregroundStyle(Theme.musicRed)
                        .rotationEffect(.degrees(manager.isRunningDiagnostic ? 360 : 0))
                        .animation(manager.isRunningDiagnostic ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: manager.isRunningDiagnostic)
                    
                    if isRefreshing || manager.isRunningDiagnostic {
                        ProgressView()
                            .scaleEffect(0.9)
                            .padding(.leading, 4)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 20) {
                    Divider().padding(.vertical, 4)
                    
                    // A. Environment Results Block
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("環境與網路狀態")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            
                            // 重新整理按鈕緊接在標題後面
                            Button {
                                Task {
                                    isRefreshing = true
                                    manager.environment = await NetworkService.shared.detectEnvironment(config: manager.config)
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    isRefreshing = false
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.title) // 加大 1 倍
                                    .foregroundStyle(Theme.musicRed) // 改為藍色以統一風格
                                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                    .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            EnvironmentRow(
                                icon: "cable.connector",
                                label: "USB-C 連接狀態",
                                isActive: manager.environment.isUSBConnected
                            )
                            Divider()
                            EnvironmentRow(
                                icon: "wifi",
                                label: "區域網路 (LAN)",
                                isActive: manager.environment.isOnSameNetwork
                            )
                            Divider()
                            EnvironmentRow(
                                icon: "lock.shield",
                                label: "Tailscale VPN 狀態",
                                isActive: manager.environment.isTailscaleActive
                            )
                            
                            if let latency = manager.environment.latencyMs {
                                Divider()
                                HStack {
                                    Image(systemName: "speedometer")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                        .frame(width: 28)
                                    Text("往返延遲 (Latency)")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(String(format: "%.0f ms", latency))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.blue)
                                        .monospacedDigit()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(16)
                    }
                    
                    // B. System Diagnostic Results Block
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("深度系統分析")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            
                            // 重新執行診斷按鈕緊接在標題後面
                            Button {
                                Task { await manager.runDiagnostics() }
                            } label: {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.title) // 加大 1 倍
                                    .foregroundStyle(.blue)
                                    .rotationEffect(.degrees(manager.isRunningDiagnostic ? 360 : 0))
                                    .animation(manager.isRunningDiagnostic ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: manager.isRunningDiagnostic)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            if manager.isRunningDiagnostic && manager.diagnosticResults.isEmpty {
                                HStack {
                                    ProgressView().padding(.trailing, 4)
                                    Text("分析中...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 12)
                            } else if !manager.diagnosticResults.isEmpty {
                                ForEach(manager.diagnosticResults, id: \.item) { result in
                                    // 版面配置參照 EnvironmentRow：icon 左、文字中、狀態 icon 靠右
                                    HStack(alignment: .top, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.item)
                                                .font(.subheadline.bold())
                                            Text(result.message)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: result.status.icon)
                                            .font(.title3)
                                            .foregroundStyle(colorForResult(result.status))
                                            .frame(width: 30, alignment: .trailing) // 與上方 EnvironmentRow 的對齊空間一致
                                    }
                                    if result.item != manager.diagnosticResults.last?.item {
                                        Divider().opacity(0.5)
                                    }
                                }
                            } else {
                                Text("尚無診斷結果")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            }
                        }
                        .padding(14)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(16)
                    }
                    
                    // Bottom padding for expanded view
                    Color.clear.frame(height: 4)
                }
                .transition(.opacity.combined(with: .offset(y: -10)))
            }
        }
    }
    
    private func colorForResult(_ status: DiagnosticResult.DiagnosticStatus) -> Color {
        switch status {
        case .pass: return .green
        case .fail: return .red
        case .warning: return .yellow
        case .checking: return .blue
        }
    }
}
