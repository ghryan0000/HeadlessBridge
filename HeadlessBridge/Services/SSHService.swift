import Foundation
import Network
import Citadel

// MARK: - SSH Service
// NOTE: 此 Service 使用 Citadel 套件 (純 Swift SSH 客戶端)
// Citadel 基於 SwiftNIO SSH，是純 Swift 實作，完全支援 SPM 且無須處理 C 函式庫連結問題

class SSHService: ObservableObject {
    static let shared = SSHService()
    
    // MARK: - Execute SSH Command
    func executeCommand(
        host: String,
        port: Int,
        user: String,
        password: String,
        command: String
    ) async throws -> String {
        
        // 使用 Citadel 執行 SSH 指令 (純 Swift 異步連線)
        let client = try await SSHClient.connect(
            host: host,
            port: port,
            authenticationMethod: .passwordBased(username: user, password: password),
            hostKeyValidator: .acceptAnything(), // 注意：MVP 階段暫時接受所有金鑰
            reconnect: .never
        )
        
        // 確保結束後關閉連線
        defer {
            Task {
                try? await client.close()
            }
        }
        
        // 執行指令並取得結果 (Citadel 0.12.x 回傳的是 ByteBuffer，需要轉為 String)
        let outputBuffer = try await client.executeCommand(command)
        return String(buffer: outputBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Test SSH Connection
    func testConnection(
        host: String,
        port: Int,
        user: String,
        password: String
    ) async -> Bool {
        do {
            let result = try await executeCommand(
                host: host,
                port: port,
                user: user,
                password: password,
                command: "echo 'test'"
            )
            return result.contains("test") || result == "command executed"
        } catch {
            return false
        }
    }
    
    // MARK: - Trigger Sidecar
    func triggerSidecar(config: MacConfig, password: String) async throws {
        // 使用 (指令 &) 讓 Mac 在背景執行等待，讓 SSH 任務能立刻回傳成功並結束。
        // 加入 > /dev/null 2>&1 以及 exit 0 確保 Citadel 不會因為後台任務而報 TTY 錯誤。
        let command = """
        open -a 'BetterDisplay' && (sleep 2; curl 'http://localhost:\(config.betterDisplayPort)/set?sidecarConnected=on&specifier=\(config.iPadUUID)') > /dev/null 2>&1 & exit 0
        """
        
        let result = try await executeCommand(
            host: config.hostname,
            port: config.sshPort,
            user: config.sshUser,
            password: password,
            command: command
        )
        
        print("Sidecar trigger result: \(result)")
    }
    
    // MARK: - Check BetterDisplay Reachability
    /// 僅檢查 BetterDisplay HTTP Server 是否在運行
    func isBetterDisplayReachable(config: MacConfig, password: String) async -> Bool {
        do {
            let result = try await executeCommand(
                host: config.hostname,
                port: config.sshPort,
                user: config.sshUser,
                password: password,
                command: "curl -s http://localhost:\(config.betterDisplayPort)/get?displays 2>/dev/null && echo 'BD_OK' || echo 'BD_FAIL'"
            )
            print("DEBUG isBetterDisplayReachable raw: [\(result)]")
            return result.contains("BD_OK")
        } catch {
            print("DEBUG isBetterDisplayReachable error: \(error)")
            return false
        }
    }
    
    // MARK: - Check Sidecar Connection Status
    /// 檢查 Mac 的 BetterDisplay 是否正在 Sidecar 鏡像
    /// - Returns: true = 確定在鏡像, false = 確定沒在鏡像, nil = 無法判斷
    func isSidecarConnected(config: MacConfig, password: String) async -> Bool? {
        do {
            // 同時查詢 specifier 和全局狀態
            let rawResult = try await executeCommand(
                host: config.hostname,
                port: config.sshPort,
                user: config.sshUser,
                password: password,
                command: "curl -s 'http://localhost:\(config.betterDisplayPort)/get?sidecarConnected&specifier=\(config.iPadUUID)' 2>/dev/null; echo '---SEPARATOR---'; curl -s 'http://localhost:\(config.betterDisplayPort)/get?sidecarConnected' 2>/dev/null"
            )
            
            print("DEBUG isSidecarConnected RAW RESPONSE: [\(rawResult)]")
            
            if rawResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               rawResult == "---SEPARATOR---" {
                print("DEBUG: Empty response from BetterDisplay API")
                return nil
            }
            
            let parts = rawResult.components(separatedBy: "---SEPARATOR---")
            var hasConnected = false
            var hasDisconnected = false
            
            // 掃描所有段落，收集結果
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmed.isEmpty { continue }
                
                let isOn = trimmed == "on" || trimmed == "1" || trimmed == "true" || trimmed == "yes"
                    || trimmed.contains(": 1") || trimmed.contains(":1")
                    || trimmed.contains("\"on\"") || trimmed.contains(": true") || trimmed.contains(":true")
                
                let isOff = trimmed == "off" || trimmed == "0" || trimmed == "false" || trimmed == "no"
                    || trimmed.contains(": 0") || trimmed.contains(":0")
                    || trimmed.contains("\"off\"") || trimmed.contains(": false") || trimmed.contains(":false")
                
                if isOn { hasConnected = true }
                if isOff { hasDisconnected = true }
                
                print("DEBUG: Part [\(trimmed)] → isOn=\(isOn), isOff=\(isOff)")
            }
            
            // 優先判斷：任何一段說 on 就是 on（全局查詢比 specifier 更可靠）
            if hasConnected {
                print("DEBUG: Sidecar is CONNECTED (at least one query returned on)")
                return true
            }
            if hasDisconnected {
                print("DEBUG: Sidecar is DISCONNECTED (all queries returned off)")
                return false
            }
            
            print("DEBUG: Could not parse BetterDisplay response, returning nil")
            return nil
            
        } catch {
            print("DEBUG isSidecarConnected SSH error: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - SSH Errors
enum SSHError: LocalizedError {
    case connectionFailed
    case authenticationFailed
    case executionFailed(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "無法連線到 Mac mini，請確認設備已開機"
        case .authenticationFailed:
            return "SSH 認證失敗，請確認帳號密碼"
        case .executionFailed(let msg):
            return "指令執行失敗：\(msg)"
        case .timeout:
            return "連線逾時"
        }
    }
}
