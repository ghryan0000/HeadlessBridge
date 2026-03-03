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
        return String(buffer: outputBuffer)
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
        let command = """
        open -a 'BetterDisplay' ; sleep 10 ; \
        curl 'http://localhost:\(config.betterDisplayPort)/set?sidecarConnected=on&specifier=\(config.iPadUUID)'
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
    
    // MARK: - Check BetterDisplay
    func checkBetterDisplay(config: MacConfig, password: String) async -> Bool {
        do {
            let result = try await executeCommand(
                host: config.hostname,
                port: config.sshPort,
                user: config.sshUser,
                password: password,
                command: "curl -s http://localhost:\(config.betterDisplayPort)/get?displays 2>/dev/null && echo 'OK' || echo 'FAIL'"
            )
            return result.contains("OK")
        } catch {
            return false
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
