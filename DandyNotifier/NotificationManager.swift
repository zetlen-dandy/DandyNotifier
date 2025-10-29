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
    let action: NotificationAction?
}

struct NotificationAction: Codable {
    let id: String
    let label: String
    let type: String  // "open"
    let location: String  // URL or file path
}

class NotificationManager {
    private var pendingActions: [String: NotificationAction] = [:]
    
    init() {
        // Register notification categories at initialization
        setupCategories()
    }
    
    private func setupCategories() {
        // We'll register categories dynamically per notification
        // This is called once at init to ensure the system is ready
    }
    
    func showNotification(_ payload: NotificationPayload) throws {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.message
        
        // Make notification more prominent and persistent
        content.interruptionLevel = .timeSensitive
        
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
        
        // Handle action button
        if let action = payload.action {
            // Create action without authentication requirement for better UX
            let actionButton = UNNotificationAction(
                identifier: action.id,
                title: action.label,
                options: []
            )
            
            // Create category with custom dismiss for Alert-style notifications
            let category = UNNotificationCategory(
                identifier: "ACTIONABLE_\(action.id)",
                actions: [actionButton],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
            
            // Register category
            UNUserNotificationCenter.current().setNotificationCategories([category])
            content.categoryIdentifier = "ACTIONABLE_\(action.id)"
            
            // Store action for later handling
            pendingActions[action.id] = action
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
            if action.type == "open" {
                openLocation(action.location)
            }
            pendingActions.removeValue(forKey: actionId)
        }
    }
    
    private func openLocation(_ location: String) {
        // Handle file:// URLs and regular paths
        let url: URL
        if location.hasPrefix("file://") {
            url = URL(string: location)!
        } else {
            url = URL(fileURLWithPath: location)
        }
        
        // Open with default application
        NSWorkspace.shared.open(url)
    }
}


