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
    static let version = "27f40d7"  // Updated via build script
    
    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
        self.authToken = Self.getOrCreateAuthToken()
    }
    
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Write to stdout (which LaunchAgent redirects to file)
        if let data = logMessage.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }
    
    private func logError(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Write to stderr (which LaunchAgent redirects to error log)
        if let data = logMessage.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
    
    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.acceptLocalOnly = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.stateUpdateHandler = { _ in }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
        } catch {
            // Server failed to start - silent failure
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
        // Find the end of headers (double CRLF)
        let headerSeparator = Data([13, 10, 13, 10]) // \r\n\r\n
        guard let separatorRange = data.range(of: headerSeparator) else {
            send(connection, 400, "Bad Request")
            return
        }
        
        // Extract headers and body
        let headerData = data.subdata(in: 0..<separatorRange.lowerBound)
        let bodyData = data.subdata(in: separatorRange.upperBound..<data.count)
        
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            send(connection, 400, "Bad Request")
            return
        }
        
        let lines = headerString.components(separatedBy: "\r\n")
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
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        
        // Route
        if path == "/health" && method == "GET" {
            send(connection, 200, "OK")
        } else if path == "/version" && method == "GET" {
            send(connection, 200, Self.version)
        } else if path == "/notify" && method == "POST" {
            log("POST /notify from \(connection)")
            handleNotify(connection, headers, bodyData)
        } else {
            log("404: \(method) \(path)")
            send(connection, 404, "Not Found")
        }
    }
    
    private func handleNotify(_ connection: NWConnection, _ headers: [String: String], _ body: Data) {
        guard headers["authorization"] == "Bearer \(authToken)" else {
            logError("Unauthorized request - missing or invalid auth token")
            sendJSON(connection, 401, ["error": "Unauthorized", "message": "Missing or invalid auth token"])
            return
        }
        
        // Try to decode the request
        let decoder = JSONDecoder()
        let req: NotificationRequest
        do {
            req = try decoder.decode(NotificationRequest.self, from: body)
        } catch {
            let bodyStr = String(data: body, encoding: .utf8) ?? "<binary data>"
            logError("JSON decode error: \(error)")
            logError("  Received body: \(bodyStr)")
            
            var errorDetails: [String: Any] = [
                "error": "Invalid JSON",
                "message": error.localizedDescription,
                "receivedBody": bodyStr
            ]
            
            // Try to decode just to see what fields are present
            if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                logError("  Parsed keys: \(json.keys.joined(separator: ", "))")
                errorDetails["parsedKeys"] = Array(json.keys)
                
                if let notification = json["notification"] as? [String: Any] {
                    logError("  Notification keys: \(notification.keys.joined(separator: ", "))")
                    errorDetails["notificationKeys"] = Array(notification.keys)
                }
            }
            
            sendJSON(connection, 400, errorDetails)
            return
        }
        
        do {
            try notificationManager.showNotification(req.notification)
            log("Notification sent: \(req.notification.title)")
            sendJSON(connection, 200, ["status": "OK", "message": "Notification sent"])
        } catch {
            logError("Error showing notification: \(error)")
            sendJSON(connection, 500, ["error": "Server Error", "message": error.localizedDescription])
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
    
    private func sendJSON(_ connection: NWConnection, _ code: Int, _ json: [String: Any]) {
        let status = ["200": "OK", "400": "Bad Request", "401": "Unauthorized", 
                      "404": "Not Found", "500": "Internal Server Error"]["\(code)"] ?? "Unknown"
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            send(connection, code, "Error serializing JSON response")
            return
        }
        
        let response = "HTTP/1.1 \(code) \(status)\r\nContent-Type: application/json\r\nContent-Length: \(jsonString.utf8.count)\r\n\r\n\(jsonString)"
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
