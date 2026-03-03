import SwiftUI

// MARK: - Color Extensions
// 將顏色定義從 Model 層移到 View 層，保持 Models 不依賴 SwiftUI

extension ConnectionMode {
    var color: Color {
        switch self {
        case .wired:    return .blue
        case .wireless: return .green
        case .remote:   return .orange
        case .auto:     return .purple
        }
    }
}

extension ConnectionStatus {
    var statusColor: Color {
        switch self {
        case .disconnected:  return .gray
        case .detecting:     return .blue
        case .connecting:    return .blue
        case .connected:     return .green
        case .failed:        return .red
        case .retrying:      return .orange
        }
    }
}

extension DiagnosticResult.DiagnosticStatus {
    var color: Color {
        switch self {
        case .pass:     return .green
        case .fail:     return .red
        case .warning:  return .orange
        case .checking: return .blue
        }
    }
}
