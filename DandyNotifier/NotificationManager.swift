//
//  NotificationManager.swift
//  DandyNotifier
//
//  Created by James Zetlen on 10/29/25.
//

import Foundation
import UserNotifications
import AppKit

struct NotificationRequest: Codable {
    let notification: NotificationPayload
}

struct NotificationPayload: Codable {
    let message: String
    let title: String
    let subtitle: String?
    let group: String?
    let sound: String?
    let interruptionLevel: String?  // "passive", "active", "timeSensitive", "critical"
    let action: NotificationAction?
    let actions: [NotificationAction]?
}

struct NotificationAction: Codable {
    let id: String
    let label: String
    let type: String  // "open" or "exec"
    let location: String?  // For "open" type
    let exec: String?  // For "exec" type - command to run
    let args: [String]?  // For "exec" type - command arguments
}

class NotificationManager {
    private var pendingActions: [String: NotificationAction] = [:]
    
    func showNotification(_ payload: NotificationPayload) throws {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.message
        
        // Set interruption level
        switch payload.interruptionLevel?.lowercased() {
        case "passive":
            content.interruptionLevel = .passive
        case "active":
            content.interruptionLevel = .active
        case "timesensitive", "time-sensitive":
            content.interruptionLevel = .timeSensitive
        case "critical":
            content.interruptionLevel = .critical
        default:
            content.interruptionLevel = .active  // Default
        }
        
        if let subtitle = payload.subtitle {
            content.subtitle = subtitle
        }
        
        // Handle sound
        if let soundPath = payload.sound, !soundPath.isEmpty {
            let soundURL = URL(fileURLWithPath: soundPath)
            let soundName = soundURL.lastPathComponent
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        } else {
            content.sound = .default
        }
        
        // Handle action buttons (single or multiple)
        let actionsToAdd = payload.actions ?? (payload.action.map { [$0] } ?? [])
        
        if !actionsToAdd.isEmpty {
            let buttons = actionsToAdd.prefix(4).map { action in
                UNNotificationAction(
                    identifier: action.id,
                    title: action.label,
                    options: [.foreground]
                )
            }
            
            let categoryId = "ACTIONS_\(actionsToAdd.map { $0.id }.joined(separator: "_"))"
            let category = UNNotificationCategory(
                identifier: categoryId,
                actions: Array(buttons),
                intentIdentifiers: [],
                options: []
            )
            
            UNUserNotificationCenter.current().setNotificationCategories([category])
            content.categoryIdentifier = categoryId
            
            // Store all actions for later handling
            for action in actionsToAdd {
                pendingActions[action.id] = action
            }
        }
        
        // Set thread identifier for grouping
        if let group = payload.group {
            content.threadIdentifier = group
        }
        
        // Create request with unique identifier
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        // Add notification
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let actionId = response.actionIdentifier
        
        // Handle default action (tap on notification)
        if actionId == UNNotificationDefaultActionIdentifier {
            return
        }
        
        // Handle custom action
        if let action = pendingActions[actionId] {
            switch action.type {
            case "open":
                if let location = action.location {
                    openLocation(location)
                }
            case "exec":
                if let exec = action.exec {
                    executeCommand(exec, args: action.args ?? [])
                }
            default:
                break
            }
            pendingActions.removeValue(forKey: actionId)
        }
    }
    
    private func openLocation(_ location: String) {
        // Handle file:// URLs and regular paths
        let url: URL
        if location.hasPrefix("file://") {
            guard let parsedURL = URL(string: location) else {
                return
            }
            url = parsedURL
        } else {
            url = URL(fileURLWithPath: location)
        }
        
        // Open with default application
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func executeCommand(_ command: String, args: [String]) {
        // Execute command with arguments
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = command
            task.arguments = args
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
        }
    }
}


