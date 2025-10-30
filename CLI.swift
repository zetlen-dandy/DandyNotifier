//
//  DandyNotifyCLI.swift
//  Command-line interface for DandyNotifier
//

import Foundation

@main
struct DandyNotifyCLI {
    static func main() {
        let args = CommandLine.arguments.dropFirst()
        
        var title: String?
        var subtitle: String?
        var message: String?
        var group: String?
        var sound: String?
        var openLocation: String?
        var executeCommand: String?
        
        var i = args.startIndex
        while i < args.endIndex {
            let arg = args[i]
            
            switch arg {
            case "-t", "--title":
                i = args.index(after: i)
                if i < args.endIndex { title = args[i] }
            case "-s", "--subtitle":
                i = args.index(after: i)
                if i < args.endIndex { subtitle = args[i] }
            case "-m", "--message":
                i = args.index(after: i)
                if i < args.endIndex { message = args[i] }
            case "-g", "--group":
                i = args.index(after: i)
                if i < args.endIndex { group = args[i] }
            case "--sound":
                i = args.index(after: i)
                if i < args.endIndex { sound = args[i] }
            case "-o", "--open":
                i = args.index(after: i)
                if i < args.endIndex { openLocation = args[i] }
            case "-e", "--execute":
                i = args.index(after: i)
                if i < args.endIndex { executeCommand = args[i] }
            case "-h", "--help":
                printHelp()
                exit(0)
            default:
                print("Unknown option: \(arg)")
                exit(1)
            }
            
            i = args.index(after: i)
        }
        
        guard let title = title, let message = message else {
            print("Error: --title and --message are required")
            exit(1)
        }
        
        sendNotification(
            title: title,
            subtitle: subtitle,
            message: message,
            group: group,
            sound: sound,
            openLocation: openLocation,
            executeCommand: executeCommand
        )
    }
    
    static func sendNotification(
        title: String,
        subtitle: String?,
        message: String,
        group: String?,
        sound: String?,
        openLocation: String?,
        executeCommand: String?
    ) {
        let tokenPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dandy-notifier-token")
        
        guard let token = try? String(contentsOf: tokenPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("Error: Auth token not found at \(tokenPath.path)")
            print("Make sure DandyNotifier.app is running")
            exit(1)
        }
        
        var notification: [String: Any] = [
            "title": title,
            "message": message
        ]
        
        if let subtitle = subtitle { notification["subtitle"] = subtitle }
        if let group = group { notification["group"] = group }
        if let sound = sound { notification["sound"] = sound }
        
        // Handle actions
        if let openLocation = openLocation {
            notification["action"] = [
                "id": "open_action",
                "label": "Open",
                "type": "open",
                "location": openLocation
            ]
        } else if let executeCommand = executeCommand {
            notification["action"] = [
                "id": "exec_action",
                "label": "Execute",
                "type": "exec",
                "exec": "/bin/bash",
                "args": ["-c", executeCommand]
            ]
        }
        
        let payload = ["notification": notification]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            print("Error: Failed to encode JSON")
            exit(1)
        }
        
        // Debug: print JSON
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            // Uncomment for debugging: print("Sending: \(jsonString)")
        }
        
        let serverURL = ProcessInfo.processInfo.environment["DANDY_SERVER_URL"] ?? "http://localhost:8889"
        guard let url = URL(string: "\(serverURL)/notify") else {
            print("Error: Invalid server URL")
            exit(1)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                success = httpResponse.statusCode == 200
                if !success {
                    print("Error: Server returned HTTP \(httpResponse.statusCode)")
                }
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        exit(success ? 0 : 1)
    }
    
    static func printHelp() {
        print("""
Usage: dandy-notify [options]

Options:
  -t, --title TITLE          Notification title (required)
  -s, --subtitle SUBTITLE    Notification subtitle
  -m, --message MESSAGE      Notification message (required)
  -g, --group GROUP          Group identifier for related notifications
  --sound PATH               Path to custom sound file (.aiff)
  -o, --open LOCATION        URL or file path to open when clicked
  -e, --execute COMMAND      Shell command to execute when clicked
  -h, --help                 Show this help message

Environment Variables:
  DANDY_SERVER_URL           Server URL (default: http://localhost:8889)

Examples:
  # Simple notification
  dandy-notify -t "Build Complete" -m "Your project compiled successfully"

  # With action button
  dandy-notify -t "Test Failed" -m "Click to view logs" -o "file:///tmp/test.log"

  # With shell command
  dandy-notify -t "Deploy Done" -m "Click to view" -e "open https://dashboard.com"

  # Git hook notification
  dandy-notify \\
    -t "Repository" \\
    -s "post-commit hook" \\
    -m "Linting failed" \\
    -e "open /tmp/lint.log" \\
    -g "git-hooks" \\
    --sound "/System/Library/Sounds/Basso.aiff"
""")
    }
}

