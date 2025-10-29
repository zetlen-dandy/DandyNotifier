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
            parameters.acceptLocalOnly = true  // Only accept connections from localhost
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✓ Server listening on port \(self.port)")
                    print("  Auth token: \(self.authToken)")
                case .failed(let error):
                    print("✗ Server failed: \(error)")
                case .cancelled:
                    print("Server cancelled")
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
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        
        var buffer = Data()
        
        func receiveData() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                if let data = data {
                    buffer.append(data)
                }
                
                // Check if we have a complete HTTP request (ends with \r\n\r\n)
                if let bufferString = String(data: buffer, encoding: .utf8),
                   bufferString.contains("\r\n\r\n") {
                    // We have a complete HTTP request
                    self?.processRequest(buffer, connection: connection)
                } else if isComplete || error != nil {
                    // Connection closed or error - process what we have
                    self?.processRequest(buffer, connection: connection)
                } else {
                    // Keep receiving
                    receiveData()
                }
            }
        }
        
        receiveData()
    }
    
    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        let components = requestLine.split(separator: " ")
        guard components.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid request")
            return
        }
        
        let method = String(components[0])
        let path = String(components[1])
        
        // Find headers and body
        var headers: [String: String] = [:]
        var bodyStartIndex = 0
        
        for (index, line) in lines.enumerated() {
            if line.isEmpty {
                bodyStartIndex = index + 1
                break
            }
            if index > 0 {
                if let colonIndex = line.firstIndex(of: ":") {
                    let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    headers[key.lowercased()] = value
                }
            }
        }
        
        let bodyLines = lines[bodyStartIndex...]
        let bodyString = bodyLines.joined(separator: "\r\n")
        let bodyData = bodyString.data(using: .utf8) ?? Data()
        
        // Route request
        if path == "/health" && method == "GET" {
            handleHealth(connection: connection)
        } else if path == "/notify" && method == "POST" {
            handleNotify(connection: connection, headers: headers, body: bodyData)
        } else {
            sendResponse(connection: connection, statusCode: 404, body: "Not found")
        }
    }
    
    private func handleHealth(connection: NWConnection) {
        sendResponse(connection: connection, statusCode: 200, body: "OK")
    }
    
    private func handleNotify(connection: NWConnection, headers: [String: String], body: Data) {
        // Check authentication
        guard let authHeader = headers["authorization"],
              authHeader == "Bearer \(authToken)" else {
            sendResponse(connection: connection, statusCode: 401, body: "Unauthorized")
            return
        }
        
        // Parse JSON body
        guard let request = try? JSONDecoder().decode(NotificationRequest.self, from: body) else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid JSON")
            return
        }
        
        // Show notification
        do {
            try notificationManager.showNotification(request.notification)
            sendResponse(connection: connection, statusCode: 200, body: "OK")
        } catch {
            sendResponse(connection: connection, statusCode: 500, body: "Error: \(error)")
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let response = """
        HTTP/1.1 \(statusCode) \(httpStatusText(statusCode))
        Content-Type: text/plain
        Content-Length: \(body.utf8.count)
        Connection: close
        
        \(body)
        """
        
        let data = response.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { _ in
            // Close connection after send completes
            connection.cancel()
        })
    }
    
    private func httpStatusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
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


