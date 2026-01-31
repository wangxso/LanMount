//
//  ContentView.swift
//  LanMount
//
//  Main content view for the application
//  Requirements: 1.1 - Tab_Bar fixed at bottom of main window with bottom navigation layout
//  Requirements: 4.1 - Display all configured SMB disk source connection status on the main interface
//

import SwiftUI

/// Main content view that displays the MainTabView as the primary interface
///
/// ContentView serves as the main entry point for the application's UI,
/// integrating MainTabView to provide a bottom navigation bar layout with
/// tab-based navigation for all SMB connections and system status.
///
/// For macOS 13.0+, uses MainTabView with Swift Charts support.
/// For macOS 12.x, falls back to MainTabViewLegacy with basic functionality.
///
/// Requirements: 1.1 - THE Tab_Bar SHALL be fixed at the bottom of the main window
/// Requirements: 4.1 - THE Dashboard SHALL display all configured SMB disk source
/// connection status on the main interface
struct ContentView: View {
    /// The app coordinator environment object for accessing shared services
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        if #available(macOS 13.0, *) {
            MainTabView()
        } else {
            // Fallback for macOS 12
            MainTabViewLegacy()
        }
    }
}

/// Alternative ContentView that creates its own view model
/// Use this when AppCoordinator is not available in the environment
struct StandaloneContentView: View {
    var body: some View {
        if #available(macOS 13.0, *) {
            MainTabView()
        } else {
            MainTabViewLegacy()
        }
    }
}

// MARK: - Preview

#Preview("With Environment") {
    ContentView()
        .environmentObject(AppCoordinator())
        .frame(width: 1000, height: 700)
}

#Preview("Standalone") {
    StandaloneContentView()
        .frame(width: 1000, height: 700)
}
