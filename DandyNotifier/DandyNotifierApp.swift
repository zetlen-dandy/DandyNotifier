//
//  DandyNotifierApp.swift
//  DandyNotifier
//
//  Created by James Zetlen on 10/29/25.
//

import SwiftUI
import UserNotifications

@main
struct DandyNotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    var server: NotificationServer?
    var notificationManager: NotificationManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - run as menu bar agent
        NSApp.setActivationPolicy(.accessory)
        
        // Setup menu bar
        setupMenuBar()
        
        // Initialize notification manager
        notificationManager = NotificationManager()
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        requestNotificationPermissions()
        
        // Start HTTP server
        server = NotificationServer(notificationManager: notificationManager!)
        server?.start()
        
        // Prevent App Nap (but allow quit to work)
        ProcessInfo.processInfo.disableAutomaticTermination("Running notification server")
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "DandyNotifier")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Server Status: Running", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DandyNotifier", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func quit() {
        // Cleanup: stop server
        server?.stop()
        
        // Re-enable automatic termination
        ProcessInfo.processInfo.enableAutomaticTermination("Server stopped")
        
        NSApplication.shared.terminate(nil)
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✓ Notification permission granted")
            } else if let error = error {
                print("✗ Notification permission error: \(error)")
            } else {
                print("✗ Notification permission denied")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        notificationManager?.handleNotificationResponse(response)
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}
