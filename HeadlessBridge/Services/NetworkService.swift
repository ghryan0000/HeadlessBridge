import Foundation
import Network
import NetworkExtension

// MARK: - Network Service
class NetworkService: ObservableObject {
    static let shared = NetworkService()
    private var monitor: NWPathMonitor?
    
    // MARK: - Detect Network Environment
    func detectEnvironment(config: MacConfig) async -> NetworkEnvironment {
        var env = NetworkEnvironment()
        
        // 1. 偵測 USB 連接（透過 link-local IP）
        env.isUSBConnected = await detectUSBConnection()
        
        // 2. 偵測同網路
        env.isOnSameNetwork = await detectSameNetwork(hostname: config.hostname)
        
        // 3. 偵測 Tailscale
        if !config.tailscaleIP.isEmpty {
            env.isTailscaleActive = await detectTailscale(ip: config.tailscaleIP)
        }
        
        // 4. 取得 Wi-Fi SSID
        env.wifiSSID = await getWiFiSSID()
        
        // 5. 量測延遲
        if env.isOnSameNetwork || env.isUSBConnected {
            env.latencyMs = await measureLatency(hostname: config.hostname)
        }
        
        return env
    }
    
    // MARK: - Detect USB Connection
    private func detectUSBConnection() async -> Bool {
        // 偵測 link-local IP 範圍（169.254.x.x）
        let interfaces = getNetworkInterfaces()
        return interfaces.contains { ip in
            ip.hasPrefix("169.254.")
        }
    }
    
    // MARK: - Shared TCP Reachability Check
    /// 通用 TCP 連線檢查（共用邏輯）
    /// - Parameters:
    ///   - host: 目標主機名稱或 IP
    ///   - port: 目標 port（預設 22 = SSH）
    ///   - timeout: 逾時秒數
    /// - Returns: 是否可連達
    private func checkReachability(
        host: String,
        port: UInt16 = 22,
        timeout: TimeInterval = 3
    ) async -> Bool {
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.Host(host)
            let nwPort = NWEndpoint.Port(integerLiteral: port)
            let connection = NWConnection(host: endpoint, port: nwPort, using: .tcp)
            
            var resolved = false
            
            connection.stateUpdateHandler = { state in
                guard !resolved else { return }
                switch state {
                case .ready:
                    resolved = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    if !resolved {
                        resolved = true
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if !resolved {
                    resolved = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - Detect Same Network
    func detectSameNetwork(hostname: String) async -> Bool {
        await checkReachability(host: hostname, timeout: 3)
    }
    
    // MARK: - Detect Tailscale
    private func detectTailscale(ip: String) async -> Bool {
        await checkReachability(host: ip, timeout: 5)
    }
    
    // MARK: - Measure Latency
    func measureLatency(hostname: String) async -> Double? {
        let start = Date()
        let reachable = await detectSameNetwork(hostname: hostname)
        guard reachable else { return nil }
        let elapsed = Date().timeIntervalSince(start) * 1000
        return elapsed
    }
    
    // MARK: - Get WiFi SSID (iOS 17+)
    /// 使用 NEHotspotNetwork（取代已棄用的 CNCopySupportedInterfaces）
    func getWiFiSSID() async -> String? {
        return await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                continuation.resume(returning: network?.ssid)
            }
        }
    }
    
    // MARK: - Get Network Interfaces
    private func getNetworkInterfaces() -> [String] {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                addresses.append(String(cString: hostname))
            }
            ptr = interface.ifa_next
        }
        return addresses
    }
}
