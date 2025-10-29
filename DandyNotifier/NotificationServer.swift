//
//  NotificationServer.swift
//  DandyNotifier
//
//  Created by James Zetlen on 10/29/25.
//

import Foundation
import Network

class NotificationServer {
    private var listener: NWListener?
    private let port: UInt16 = 8889
    private let notificationManager: NotificationManager
    private let authToken: String
    
    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
        self.authToken = Self.getOrCreateAuthToken()
    }
    
    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.acceptLocalOnly = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✓ Server listening on port \(self.port)")
                    print("  Auth token: \(self.authToken)")
                case .failed(let error):
                    print("✗ Server failed: \(error)")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
        } catch {
            print("✗ Failed to start server: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        var buffer = Data()
        
        func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                if let data = data {
                    buffer.append(data)
                }
                
                // Check for complete HTTP request (ends with \r\n\r\n)
                if let str = String(data: buffer, encoding: .utf8), str.contains("\r\n\r\n") {
                    self?.processRequest(buffer, connection: connection)
                } else if isComplete || error != nil {
                    self?.processRequest(buffer, connection: connection)
                } else {
                    receive()
                }
            }
        }
        receive()
    }
    
    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            send(connection, 400, "Bad Request")
            return
        }
        
        let lines = request.components(separatedBy: "\r\n")
        guard let first = lines.first else {
            send(connection, 400, "Bad Request")
            return
        }
        
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else {
            send(connection, 400, "Bad Request")
            return
        }
        
        let method = String(parts[0])
        let path = String(parts[1])
        
        // Parse headers
        var headers: [String: String] = [:]
        var bodyStart = 0
        for (i, line) in lines.enumerated() {
            if line.isEmpty {
                bodyStart = i + 1
                break
            }
            if i > 0, let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        
        let bodyData = lines[bodyStart...].joined(separator: "\r\n").data(using: .utf8) ?? Data()
        
        // Route
        if path == "/health" && method == "GET" {
            send(connection, 200, "OK")
        } else if path == "/notify" && method == "POST" {
            handleNotify(connection, headers, bodyData)
        } else {
            send(connection, 404, "Not Found")
        }
    }
    
    private func handleNotify(_ connection: NWConnection, _ headers: [String: String], _ body: Data) {
        guard headers["authorization"] == "Bearer \(authToken)" else {
            send(connection, 401, "Unauthorized")
            return
        }
        
        guard let req = try? JSONDecoder().decode(NotificationRequest.self, from: body) else {
            send(connection, 400, "Invalid JSON")
            return
        }
        
        do {
            try notificationManager.showNotification(req.notification)
            send(connection, 200, "OK")
        } catch {
            send(connection, 500, "Error: \(error)")
        }
    }
    
    private func send(_ connection: NWConnection, _ code: Int, _ body: String) {
        let status = ["200": "OK", "400": "Bad Request", "401": "Unauthorized", 
                      "404": "Not Found", "500": "Internal Server Error"]["\(code)"] ?? "Unknown"
        let response = "HTTP/1.1 \(code) \(status)\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    // MARK: - Auth Token Management
    
    private static func getOrCreateAuthToken() -> String {
        let tokenPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dandy-notifier-token")
        
        // Try to read existing token
        if let token = try? String(contentsOf: tokenPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }
        
        // Generate new token
        let token = UUID().uuidString
        try? token.write(to: tokenPath, atomically: true, encoding: .utf8)
        
        // Set restrictive permissions (readable only by user)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenPath.path)
        
        return token
    }
}
