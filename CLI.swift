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
        var interruptionLevel: String?
        var debug = false
        
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
            case "-i", "--interruption":
                i = args.index(after: i)
                if i < args.endIndex { interruptionLevel = args[i] }
            case "-o", "--open":
                i = args.index(after: i)
                if i < args.endIndex { openLocation = args[i] }
            case "-e", "--execute":
                i = args.index(after: i)
                if i < args.endIndex { executeCommand = args[i] }
            case "-d", "--debug":
                debug = true
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
            interruptionLevel: interruptionLevel,
            openLocation: openLocation,
            executeCommand: executeCommand,
            debug: debug
        )
    }
    
    static func sendNotification(
        title: String,
        subtitle: String?,
        message: String,
        group: String?,
        sound: String?,
        interruptionLevel: String?,
        openLocation: String?,
        executeCommand: String?,
        debug: Bool
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
        if let interruptionLevel = interruptionLevel { notification["interruptionLevel"] = interruptionLevel }
        
        // Handle actions
        if let openLocation = openLocation {
            notification["action"] = [
                "id": "open_action",
                "label": "Open",
                "type": "open",
                "location": openLocation
            ] as [String: Any]
        } else if let executeCommand = executeCommand {
            notification["action"] = [
                "id": "exec_action",
                "label": "Execute",
                "type": "exec",
                "exec": "/bin/bash",
                "args": ["-c", executeCommand] as [String]
            ] as [String: Any]
        }
        
        let payload = ["notification": notification]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            print("Error: Failed to encode JSON")
            exit(1)
        }
        
        let serverURL = ProcessInfo.processInfo.environment["DANDY_SERVER_URL"] ?? "http://localhost:8889"
        
        // Debug output
        if debug, let jsonString = String(data: jsonData, encoding: .utf8) {
            fputs("Debug: Sending to \(serverURL)/notify\n", stderr)
            fputs("Debug: JSON: \(jsonString)\n", stderr)
        }
        // Use curl for reliable HTTP requests
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "-s",
            "-X", "POST",
            "-H", "Content-Type: application/json",
            "-H", "Authorization: Bearer \(token)",
            "-d", String(data: jsonData, encoding: .utf8) ?? "",
            "\(serverURL)/notify"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let response = String(data: data, encoding: .utf8), !response.isEmpty {
                // Parse JSON response if possible
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if jsonResponse["status"] as? String == "OK" {
                        exit(0)
                    } else {
                        print("Error: \(response)")
                        exit(1)
                    }
                } else {
                    // Plain text response
                    if response.contains("OK") {
                        exit(0)
                    } else {
                        print("Error: \(response)")
                        exit(1)
                    }
                }
            }
            
            exit(process.terminationStatus == 0 ? 0 : 1)
        } catch {
            print("Error: Failed to execute curl - \(error.localizedDescription)")
            exit(1)
        }
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
  -i, --interruption LEVEL   Interruption level (passive|active|timeSensitive|critical)
  -o, --open LOCATION        URL or file path to open when clicked
  -e, --execute COMMAND      Shell command to execute when clicked
  -d, --debug                Print debug output (JSON payload, server URL)
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

