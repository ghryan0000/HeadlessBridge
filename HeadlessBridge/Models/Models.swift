import Foundation

// MARK: - Mac Configuration
struct MacConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var hostname: String        // My-Mac.local
    var sshUser: String         // ryanchang
    var sshPort: Int            // 22
    var betterDisplayPort: Int  // 55777
    var iPadUUID: String        // 7EDAF4D0-AE2E-42A0-A5E4-24832539A009
    var tailscaleIP: String     // 100.x.x.x
    
    /// 固定 UUID，確保 Keychain key 不會因重置而改變
    private static let defaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static let `default` = MacConfig(
        id: defaultID,
        name: "我的 Mac",
        hostname: "My-Mac.local",
        sshUser: "",
        sshPort: 22,
        betterDisplayPort: 55777,
        iPadUUID: "",
        tailscaleIP: ""
    )
}

// MARK: - Connection Mode
enum ConnectionMode: String, CaseIterable {
    case wired = "有線 Sidecar"
    case wireless = "無線 Sidecar"
    case remote = "遠距 VNC"
    case auto = "自動選擇"
    
    var icon: String {
        switch self {
        case .wired:    return "cable.connector"
        case .wireless: return "wifi"
        case .remote:   return "globe"
        case .auto:     return "wand.and.stars"
        }
    }
    

}

// MARK: - Connection Status
enum ConnectionStatus: Equatable {
    case disconnected
    case detecting
    case connecting(String)
    case connected(ConnectionMode)
    case failed(String)
    case retrying(Int)
    
    var displayText: String {
        switch self {
        case .disconnected:         return "未連線"
        case .detecting:            return "偵測環境中..."
        case .connecting(let msg):  return msg
        case .connected(let mode):  return "已連線：\(mode.rawValue)"
        case .failed(let error):    return "失敗：\(error)"
        case .retrying(let count):  return "重試中... (\(count)/3)"
        }
    }
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    var isLoading: Bool {
        switch self {
        case .detecting, .connecting, .retrying: return true
        default: return false
        }
    }
    

}

// MARK: - Network Environment
struct NetworkEnvironment {
    var isUSBConnected: Bool = false
    var isOnSameNetwork: Bool = false
    var isTailscaleActive: Bool = false
    var tailscaleMode: TailscaleMode = .unknown
    var latencyMs: Double? = nil
    var wifiSSID: String? = nil
    
    enum TailscaleMode {
        case direct, relay, inactive, unknown
        
        var displayText: String {
            switch self {
            case .direct:   return "直連"
            case .relay:    return "中繼"
            case .inactive: return "未啟用"
            case .unknown:  return "偵測中"
            }
        }
    }
    
    var recommendedMode: ConnectionMode {
        if isUSBConnected { return .wired }
        if isOnSameNetwork { return .wireless }
        if isTailscaleActive { return .remote }
        return .wired
    }
}

// MARK: - Connection History
struct ConnectionHistory: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var mode: String
    var duration: TimeInterval
    var success: Bool
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        if hours > 0 {
            return "\(hours)小時 \(minutes)分"
        }
        return "\(minutes)分鐘"
    }
}

// MARK: - Diagnostic Result
struct DiagnosticResult: Identifiable {
    var id: UUID = UUID()
    var item: String
    var status: DiagnosticStatus
    var message: String
    
    enum DiagnosticStatus {
        case pass, fail, warning, checking
        
        var icon: String {
            switch self {
            case .pass:     return "checkmark.circle.fill"
            case .fail:     return "xmark.circle.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .checking: return "arrow.clockwise.circle.fill"
            }
        }
        

    }
}
