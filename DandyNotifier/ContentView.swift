//
//  ContentView.swift
//  DandyNotifier
//
//  This view is not actually displayed since the app runs as a menu bar agent.
//  Kept for Xcode project structure completeness.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .imageScale(.large)
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            
            Text("DandyNotifier")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Server running on port 8889")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Check the menu bar for controls")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(width: 300, height: 250)
    }
}

#Preview {
    ContentView()
}
