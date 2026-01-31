//
//  LanMountApp.swift
//  LanMount
//
//  macOS SMB Mounter Application
//  Minimum deployment target: macOS 12.0 (Monterey)
//  Supports: Apple Silicon (M1/M2/M3) and Intel processors
//
//  Requirements: 2.2, 2.3, 2.5 - Application startup flow
//

import SwiftUI
import AppKit

/// Main application entry point for LanMount
/// A menu bar application for managing SMB network shares
/// Requirements: 2.2, 2.3, 2.5 - Initialize AppCoordinator, load config, auto-mount, start monitoring
@main
struct LanMountApp: App {
    // Use AppDelegate for menu bar functionality and lifecycle management
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // AppCoordinator as StateObject for SwiftUI state management
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        // Settings window for preferences - accessible via menu bar or Cmd+,
        Settings {
            PreferencesView()
                .environmentObject(appCoordinator)
        }
    }
    
    init() {
        // Configure app to run in background (no dock icon)
        // This is handled by LSUIElement = YES in Info.plist
    }
}

/// AppDelegate for managing the menu bar application lifecycle
/// Coordinates with AppCoordinator for startup sequence
/// Requirements: 2.2, 2.3, 2.5
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    
    /// The main application coordinator
    /// Manages all services and coordinates event flow
    @Published var appCoordinator: AppCoordinator?
    
    /// Logger for application logging
    private let logger = Logger.shared
    
    /// Window controllers for managing windows
    private var mountConfigWindowController: NSWindowController?
    private var networkScannerWindowController: NSWindowController?
    private var dashboardWindowController: NSWindowController?
    
    // MARK: - NSApplicationDelegate
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("LanMount application launching", component: Logger.Component.app)
        
        // Initialize the AppCoordinator
        initializeAppCoordinator()
        
        // Register for window notifications
        registerNotificationObservers()
        
        // Start the application startup sequence
        performStartupSequence()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logger.info("LanMount application terminating", component: Logger.Component.app)
        
        // Stop the coordinator
        appCoordinator?.stop()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps should not terminate when windows are closed
        return false
    }
    
    // MARK: - Initialization
    
    /// Initializes the AppCoordinator
    /// Requirements: 2.2 - Initialize AppCoordinator at @main entry
    private func initializeAppCoordinator() {
        logger.info("Initializing AppCoordinator", component: Logger.Component.app)
        
        // Create the coordinator
        let coordinator = AppCoordinator()
        self.appCoordinator = coordinator
        
        logger.info("AppCoordinator initialized successfully", component: Logger.Component.app)
    }
    
    /// Registers notification observers for window management
    private func registerNotificationObservers() {
        // Observer for showing mount configuration window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showMountConfigWindow),
            name: .showMountConfigWindow,
            object: nil
        )

        // Observer for showing network scanner window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showNetworkScannerWindow),
            name: .showNetworkScannerWindow,
            object: nil
        )

        // Observer for showing dashboard window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDashboardWindow),
            name: .showDashboardWindow,
            object: nil
        )
    }
    
    // MARK: - Startup Sequence
    
    /// Performs the complete application startup sequence
    /// Requirements: 2.2, 2.3, 2.5
    /// Sequence: Load config → Auto-mount → Start monitoring → Show menu bar → Open Dashboard
    private func performStartupSequence() {
        logger.info("Starting application startup sequence", component: Logger.Component.app)
        
        Task { @MainActor in
            guard let coordinator = appCoordinator else {
                logger.error("AppCoordinator not initialized", component: Logger.Component.app)
                return
            }
            
            // Step 1: Start the coordinator (sets up menu bar and starts monitoring)
            // This loads configuration and settings, starts volume monitoring, and shows menu bar icon
            logger.info("Step 1: Starting AppCoordinator services", component: Logger.Component.app)
            await coordinator.start()
            
            // Step 2: Execute auto-mount for configured shares
            // Requirements: 2.3 - Auto-mount all configured shares on startup
            logger.info("Step 2: Executing auto-mount", component: Logger.Component.app)
            await coordinator.performAutoMount()
            
            // Step 3: Open Dashboard window automatically on startup
            logger.info("Step 3: Opening Dashboard window", component: Logger.Component.app)
            openDashboardWindow()
            
            // Step 4: Log startup completion
            logger.info("Application startup sequence completed", component: Logger.Component.app)
            
            // Log startup summary
            let mountedVolumes = coordinator.getMountedVolumes()
            logger.info("Startup complete: \(mountedVolumes.count) volume(s) mounted", component: Logger.Component.app)
        }
    }
    
    // MARK: - Window Management
    
    /// Shows the mount configuration window
    @objc private func showMountConfigWindow() {
        logger.info("Opening mount configuration window", component: Logger.Component.app)
        
        // Use SwiftUI window management
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "mount-config" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Open the window using SwiftUI's openWindow
            openMountConfigWindow()
        }
    }
    
    /// Shows the network scanner window
    @objc private func showNetworkScannerWindow() {
        logger.info("Opening network scanner window", component: Logger.Component.app)

        // Use SwiftUI window management
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "network-scanner" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Open the window using SwiftUI's openWindow
            openNetworkScannerWindow()
        }
    }

    /// Shows the dashboard window
    @objc private func showDashboardWindow() {
        logger.info("Opening dashboard window", component: Logger.Component.app)

        // Use SwiftUI window management
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "dashboard" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Open the window using SwiftUI's openWindow
            openDashboardWindow()
        }
    }
    
    /// Opens the mount configuration window using SwiftUI
    private func openMountConfigWindow() {
        guard let coordinator = appCoordinator else { return }
        
        // Create a hosting window for the MountConfigView
        let contentView = MountConfigView()
            .environmentObject(coordinator)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("Add New Mount", comment: "Mount config window title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 450, height: 400))
        window.center()
        window.identifier = NSUserInterfaceItemIdentifier("mount-config")
        
        let windowController = NSWindowController(window: window)
        mountConfigWindowController = windowController
        
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Opens the network scanner window using SwiftUI
    private func openNetworkScannerWindow() {
        guard let coordinator = appCoordinator else { return }
        
        // Create a hosting window for the NetworkScannerView
        let contentView = NetworkScannerView()
            .environmentObject(coordinator)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("Scan Network", comment: "Network scanner window title")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 500, height: 450))
        window.center()
        window.identifier = NSUserInterfaceItemIdentifier("network-scanner")
        
        let windowController = NSWindowController(window: window)
        networkScannerWindowController = windowController
        
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens the dashboard window using SwiftUI
    /// Requirements: 1.1 - Tab_Bar fixed at bottom of main window with bottom navigation layout
    /// Requirements: 4.1 - Display all configured SMB disk source connection status on the main interface
    /// Requirements: 7.1 - Set minimum window size to 600x400
    private func openDashboardWindow() {
        guard let coordinator = appCoordinator else { return }

        // Create a hosting window for the MainTabView (or legacy fallback)
        let contentView: AnyView
        if #available(macOS 13.0, *) {
            contentView = AnyView(
                MainTabView()
                    .environmentObject(coordinator)
            )
        } else {
            contentView = AnyView(
                MainTabViewLegacy()
                    .environmentObject(coordinator)
            )
        }

        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("LanMount Dashboard", comment: "Dashboard window title")
        window.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable, .resizable])
        window.setContentSize(NSSize(width: 1000, height: 700))
        // Requirements: 7.1 - Set minimum window size to 600x400
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        window.identifier = NSUserInterfaceItemIdentifier("dashboard")

        let windowController = NSWindowController(window: window)
        dashboardWindowController = windowController

        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Environment Key for AppCoordinator

/// Environment key for accessing AppCoordinator in SwiftUI views
private struct AppCoordinatorKey: EnvironmentKey {
    static let defaultValue: AppCoordinator? = nil
}

extension EnvironmentValues {
    var appCoordinator: AppCoordinator? {
        get { self[AppCoordinatorKey.self] }
        set { self[AppCoordinatorKey.self] = newValue }
    }
}
