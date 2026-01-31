//
//  AppCoordinator.swift
//  LanMount
//
//  Coordinates all application services and manages event flow between components
//  Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 8.3
//

import Foundation
import Combine
import AppKit
import UserNotifications

// MARK: - AppCoordinatorProtocol

/// Protocol defining the interface for application coordination
@MainActor
protocol AppCoordinatorProtocol: AnyObject {
    /// Starts the coordinator and all managed services
    func start() async

    /// Stops the coordinator and all managed services
    func stop()

    /// Performs auto-mount for all configured shares
    func performAutoMount() async

    /// Cancels the current auto-mount operation if running
    /// Requirements: 11.1, 11.2 - Support operation cancellation
    func cancelAutoMount()

    /// Gets all currently mounted volumes
    func getMountedVolumes() -> [MountedVolume]

    /// Mounts an SMB share
    func mount(server: String, share: String, mountPoint: String, credentials: Credentials?) async throws -> MountResult

    /// Unmounts an SMB share
    func unmount(mountPoint: String) async throws

    /// Starts network scanning
    func startNetworkScan() async

    /// Stops network scanning
    func stopNetworkScan()

    /// Opens the dashboard window
    /// Requirements: 4.1 - Add method to open dashboard window
    func openDashboardWindow()

    /// Cancels a reconnect attempt for a specific mount point
    /// Requirements: 11.1, 11.2 - Support operation cancellation
    func cancelReconnect(for mountPoint: String)

    /// Cancels all pending reconnect attempts
    /// Requirements: 11.1, 11.2 - Support operation cancellation
    func cancelAllReconnects()
}

// MARK: - AppCoordinator

/// Main application coordinator that initializes and coordinates all services
/// Connects event streams between components and handles UI updates
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 8.3
@MainActor
final class AppCoordinator: NSObject, ObservableObject, AppCoordinatorProtocol {
    
    // MARK: - Published Properties
    
    /// Currently mounted volumes
    @Published private(set) var mountedVolumes: [MountedVolume] = []
    
    /// Discovered network services
    @Published private(set) var discoveredServices: [DiscoveredService] = []
    
    /// Current application state
    @Published private(set) var isRunning: Bool = false
    
    /// Whether network scanning is in progress
    @Published private(set) var isScanning: Bool = false
    
    /// Last error that occurred
    @Published private(set) var lastError: SMBMounterError?
    
    // MARK: - Services
    
    /// Mount manager for SMB mount operations
    private let mountManager: MountManagerProtocol
    
    /// Network scanner for discovering SMB services
    private let networkScanner: NetworkScannerProtocol
    
    /// Volume monitor for tracking mount state changes
    private let volumeMonitor: VolumeMonitorProtocol
    
    /// Sync engine for file synchronization
    private let syncEngine: SyncEngineProtocol
    
    /// Configuration store for persistent settings
    private let configurationStore: ConfigurationStoreProtocol
    
    /// Credential manager for secure credential storage
    private let credentialManager: CredentialManagerProtocol
    
    /// Menu bar controller for UI management
    private let menuBarController: MenuBarController
    
    /// Menu builder for creating menus
    private let menuBuilder: MenuBuilder
    
    /// Logger for application logging
    private let logger: Logger
    
    /// Notification manager for user notifications
    private let notificationManager: NotificationManagerProtocol
    
    // MARK: - Event Handling
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Task for volume event monitoring
    private var volumeEventTask: Task<Void, Never>?
    
    /// Task for sync event monitoring
    private var syncEventTask: Task<Void, Never>?
    
    /// Task for network scan monitoring
    private var networkScanTask: Task<Void, Never>?
    
    /// Task for auto-mount operations (supports cancellation)
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    private var autoMountTask: Task<AutoMountSummary, Never>?
    
    /// Task for reconnection attempts
    private var reconnectTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    /// Creates a new AppCoordinator with default services
    override init() {
        // Initialize services
        self.mountManager = MountManager()
        self.networkScanner = NetworkScanner()
        self.volumeMonitor = VolumeMonitor()
        self.syncEngine = SyncEngine()
        self.configurationStore = ConfigurationStore()
        self.credentialManager = CredentialManager()
        self.menuBarController = MenuBarController()
        self.menuBuilder = MenuBuilder()
        self.logger = Logger.shared
        self.notificationManager = NotificationManager.shared
        
        super.init()
        
        // Set up menu delegate
        menuBuilder.delegate = self
        
        // Set up notification manager delegate
        if let manager = notificationManager as? NotificationManager {
            manager.delegate = self
        }
    }
    
    /// Creates a new AppCoordinator with custom services (for testing)
    /// - Parameters:
    ///   - mountManager: Custom mount manager
    ///   - networkScanner: Custom network scanner
    ///   - volumeMonitor: Custom volume monitor
    ///   - syncEngine: Custom sync engine
    ///   - configurationStore: Custom configuration store
    ///   - credentialManager: Custom credential manager
    ///   - menuBarController: Custom menu bar controller
    ///   - logger: Custom logger
    ///   - notificationManager: Custom notification manager
    init(
        mountManager: MountManagerProtocol,
        networkScanner: NetworkScannerProtocol,
        volumeMonitor: VolumeMonitorProtocol,
        syncEngine: SyncEngineProtocol,
        configurationStore: ConfigurationStoreProtocol,
        credentialManager: CredentialManagerProtocol,
        menuBarController: MenuBarController,
        logger: Logger = Logger.shared,
        notificationManager: NotificationManagerProtocol = NotificationManager.shared
    ) {
        self.mountManager = mountManager
        self.networkScanner = networkScanner
        self.volumeMonitor = volumeMonitor
        self.syncEngine = syncEngine
        self.configurationStore = configurationStore
        self.credentialManager = credentialManager
        self.menuBarController = menuBarController
        self.menuBuilder = MenuBuilder()
        self.logger = logger
        self.notificationManager = notificationManager
        
        super.init()
        
        // Set up menu delegate
        menuBuilder.delegate = self
        
        // Set up notification manager delegate
        if let manager = notificationManager as? NotificationManager {
            manager.delegate = self
        }
    }
    
    deinit {
        // Note: Cannot call MainActor-isolated stop() from deinit
        // Cleanup is handled by applicationWillTerminate in AppDelegate
    }
    
    // MARK: - AppCoordinatorProtocol Implementation
    
    /// Starts the coordinator and all managed services
    func start() async {
        guard !isRunning else {
            logger.warning("AppCoordinator already running", component: Logger.Component.app)
            return
        }
        
        logger.info("Starting AppCoordinator", component: Logger.Component.app)
        
        isRunning = true
        
        // Set up menu bar
        setupMenuBar()
        
        // Start volume monitoring
        startVolumeMonitoring()
        
        // Start sync event monitoring
        startSyncEventMonitoring()
        
        // Request notification permissions
        await requestNotificationPermissions()
        
        // Refresh mounted volumes
        refreshMountedVolumes()
        
        // Update menu bar
        updateMenuBar()
        
        logger.info("AppCoordinator started successfully", component: Logger.Component.app)
    }
    
    /// Stops the coordinator and all managed services
    func stop() {
        guard isRunning else { return }
        
        logger.info("Stopping AppCoordinator", component: Logger.Component.app)
        
        isRunning = false
        
        // Cancel all tasks
        volumeEventTask?.cancel()
        volumeEventTask = nil
        
        syncEventTask?.cancel()
        syncEventTask = nil
        
        networkScanTask?.cancel()
        networkScanTask = nil
        
        // Cancel auto-mount task if running
        // Requirements: 11.1, 11.2 - Support operation cancellation
        autoMountTask?.cancel()
        autoMountTask = nil
        
        // Cancel all reconnect tasks
        for (_, task) in reconnectTasks {
            task.cancel()
        }
        reconnectTasks.removeAll()
        
        // Stop services
        volumeMonitor.stopMonitoring()
        networkScanner.stopScan()
        
        // Cancel all subscriptions
        cancellables.removeAll()
        
        // Hide menu bar
        menuBarController.hide()
        
        logger.info("AppCoordinator stopped", component: Logger.Component.app)
    }
    
    /// Performs auto-mount for all configured shares with cancellation support
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    func performAutoMount() async {
        logger.info("Starting auto-mount process", component: Logger.Component.app)
        
        // Cancel any existing auto-mount task
        autoMountTask?.cancel()
        
        // Update menu bar to show connecting state
        menuBarController.setIconState(.connecting)
        
        // Create a new auto-mount task that can be cancelled
        autoMountTask = Task { [weak self] in
            guard let self = self else {
                return AutoMountSummary(
                    totalConfigurations: 0,
                    successCount: 0,
                    failureCount: 0,
                    results: [],
                    timestamp: Date()
                )
            }
            
            // Perform auto-mount using MountManager
            if let mountManager = self.mountManager as? MountManager {
                return await mountManager.performAutoMount(using: self.configurationStore)
            }
            
            return AutoMountSummary(
                totalConfigurations: 0,
                successCount: 0,
                failureCount: 0,
                results: [],
                timestamp: Date()
            )
        }
        
        // Wait for the auto-mount task to complete
        guard let summary = await autoMountTask?.value else {
            logger.warning("Auto-mount task was cancelled or failed", component: Logger.Component.app)
            updateMenuBar()
            return
        }
        
        // Check if task was cancelled
        guard !Task.isCancelled else {
            logger.info("Auto-mount was cancelled", component: Logger.Component.app)
            updateMenuBar()
            return
        }
        
        // Log results
        if summary.totalConfigurations == 0 {
            logger.info("No auto-mount configurations found", component: Logger.Component.app)
        } else if summary.allSucceeded {
            logger.info("Auto-mount completed: \(summary.successCount) share(s) mounted", component: Logger.Component.app)
            showNotification(
                title: NSLocalizedString("Auto-Mount Complete", comment: "Notification title"),
                body: String(format: NSLocalizedString("%d share(s) mounted successfully", comment: "Notification body"), summary.successCount)
            )
        } else {
            logger.warning("Auto-mount completed with issues: \(summary.successCount) succeeded, \(summary.failureCount) failed", component: Logger.Component.app)
            
            // Show notification for failures
            if summary.failureCount > 0 {
                showNotification(
                    title: NSLocalizedString("Auto-Mount Issues", comment: "Notification title"),
                    body: String(format: NSLocalizedString("%d share(s) failed to mount", comment: "Notification body"), summary.failureCount)
                )
            }
        }
        
        // Add successfully mounted volumes to monitoring (run concurrently)
        // Requirements: 11.1, 11.2 - Use TaskGroup for concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for result in summary.successfulResults {
                guard let mountPoint = result.mountPoint else { continue }
                
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    // Check for cancellation
                    guard !Task.isCancelled else { return }
                    
                    self.volumeMonitor.addMountPoint(mountPoint)
                    
                    // Enable sync if configured
                    if result.configuration.syncEnabled {
                        do {
                            try self.syncEngine.enableSync(for: mountPoint, bidirectional: true)
                        } catch {
                            self.logger.error("Failed to enable sync for \(mountPoint)", error: error, component: Logger.Component.syncEngine)
                        }
                    }
                }
            }
        }
        
        // Refresh mounted volumes and update UI
        refreshMountedVolumes()
        updateMenuBar()
    }
    
    /// Cancels the current auto-mount operation if running
    /// Requirements: 11.1, 11.2 - Support operation cancellation
    func cancelAutoMount() {
        guard autoMountTask != nil else { return }
        
        logger.info("Cancelling auto-mount operation", component: Logger.Component.app)
        autoMountTask?.cancel()
        autoMountTask = nil
        updateMenuBar()
    }
    
    /// Gets all currently mounted volumes
    func getMountedVolumes() -> [MountedVolume] {
        return mountedVolumes
    }
    
    /// Mounts an SMB share
    func mount(server: String, share: String, mountPoint: String, credentials: Credentials?) async throws -> MountResult {
        logger.info("Mounting \(server)/\(share) at \(mountPoint)", component: Logger.Component.mountManager)
        
        // Update menu bar to show connecting state
        menuBarController.setIconState(.connecting)
        
        do {
            let result = try await mountManager.mount(
                server: server,
                share: share,
                mountPoint: mountPoint,
                credentials: credentials
            )
            
            if result.success, let actualMountPoint = result.mountPoint {
                logger.info("Successfully mounted \(server)/\(share) at \(actualMountPoint)", component: Logger.Component.mountManager)
                
                // Add to volume monitoring
                volumeMonitor.addMountPoint(actualMountPoint)
                
                // Show success notification using NotificationManager
                notificationManager.showMountSuccess(server: server, share: share, mountPoint: actualMountPoint)
            }
            
            // Refresh UI
            refreshMountedVolumes()
            updateMenuBar()
            
            return result
            
        } catch let error as SMBMounterError {
            logger.error("Failed to mount \(server)/\(share)", error: error, component: Logger.Component.mountManager)
            lastError = error
            
            // Show error notification using NotificationManager
            notificationManager.showMountFailure(server: server, share: share, error: error)
            
            // Update menu bar
            updateMenuBar()
            
            throw error
        }
    }
    
    /// Unmounts an SMB share
    func unmount(mountPoint: String) async throws {
        logger.info("Unmounting \(mountPoint)", component: Logger.Component.mountManager)
        
        do {
            // Disable sync if enabled
            if syncEngine.isSyncEnabled(for: mountPoint) {
                syncEngine.disableSync(for: mountPoint)
            }
            
            // Remove from volume monitoring
            volumeMonitor.removeMountPoint(mountPoint)
            
            // Perform unmount
            try await mountManager.unmount(mountPoint: mountPoint)
            
            logger.info("Successfully unmounted \(mountPoint)", component: Logger.Component.mountManager)
            
            // Refresh UI
            refreshMountedVolumes()
            updateMenuBar()
            
        } catch let error as SMBMounterError {
            logger.error("Failed to unmount \(mountPoint)", error: error, component: Logger.Component.mountManager)
            lastError = error
            showErrorNotification(error: error)
            throw error
        }
    }
    
    /// Starts network scanning
    func startNetworkScan() async {
        guard !isScanning else {
            logger.warning("Network scan already in progress", component: Logger.Component.networkScanner)
            return
        }
        
        logger.info("Starting network scan", component: Logger.Component.networkScanner)
        
        isScanning = true
        discoveredServices = []
        
        // Start monitoring discovered services
        startNetworkScanMonitoring()
        
        // Start the scan
        await networkScanner.startScan()
    }
    
    /// Stops network scanning
    func stopNetworkScan() {
        logger.info("Stopping network scan", component: Logger.Component.networkScanner)

        networkScanner.stopScan()
        networkScanTask?.cancel()
        networkScanTask = nil
        isScanning = false
    }

    /// Opens the dashboard window
    /// Requirements: 4.1 - Add method to open dashboard window
    func openDashboardWindow() {
        logger.info("Opening dashboard window", component: Logger.Component.app)

        // Post notification to show dashboard window
        NotificationCenter.default.post(name: .showDashboardWindow, object: nil)
    }
    
    // MARK: - Private Methods - Setup
    
    /// Sets up the menu bar
    private func setupMenuBar() {
        menuBarController.setup()
        menuBarController.show()
        menuBarController.setMenuDelegate(self)
        
        // Build initial menu
        let menu = menuBuilder.buildMenu(with: mountedVolumes)
        menuBarController.setMenu(menu)
    }
    
    /// Updates the menu bar with current state
    private func updateMenuBar() {
        // Update menu
        let menu = menuBuilder.buildMenu(with: mountedVolumes)
        menuBarController.setMenu(menu)
        
        // Update icon state based on mount statuses
        let statuses = mountedVolumes.map { $0.status }
        menuBarController.updateIconForMountStatuses(statuses)
    }
    
    /// Refreshes the list of mounted volumes
    private func refreshMountedVolumes() {
        mountedVolumes = mountManager.getMountedVolumes()
    }
    
    // MARK: - Private Methods - Event Monitoring
    
    /// Starts volume event monitoring
    private func startVolumeMonitoring() {
        volumeMonitor.startMonitoring()
        
        volumeEventTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await event in self.volumeMonitor.volumeEvents {
                await self.handleVolumeEvent(event)
            }
        }
    }
    
    /// Starts sync event monitoring
    private func startSyncEventMonitoring() {
        syncEventTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await event in self.syncEngine.syncEvents {
                await self.handleSyncEvent(event)
            }
        }
    }
    
    /// Starts network scan monitoring
    private func startNetworkScanMonitoring() {
        networkScanTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await service in self.networkScanner.discoveredServices {
                await self.handleDiscoveredService(service)
            }
            
            // Scan completed
            await MainActor.run {
                self.isScanning = false
                self.logger.info("Network scan completed, found \(self.discoveredServices.count) service(s)", component: Logger.Component.networkScanner)
            }
        }
    }
    
    // MARK: - Private Methods - Event Handlers
    
    /// Handles volume events from VolumeMonitor
    /// Requirements: 8.3 - Handle volume events, trigger UI updates
    private func handleVolumeEvent(_ event: VolumeEvent) async {
        switch event {
        case .mounted(let volume):
            logger.info("Volume mounted: \(volume.volumeName) at \(volume.mountPoint)", component: Logger.Component.volumeMonitor)
            
            // Refresh volumes and update UI
            refreshMountedVolumes()
            updateMenuBar()
            
        case .unmounted(let mountPoint):
            logger.info("Volume unmounted: \(mountPoint)", component: Logger.Component.volumeMonitor)
            
            // Disable sync if enabled
            if syncEngine.isSyncEnabled(for: mountPoint) {
                syncEngine.disableSync(for: mountPoint)
            }
            
            // Refresh volumes and update UI
            refreshMountedVolumes()
            updateMenuBar()
            
        case .disconnected(let mountPoint):
            logger.warning("Volume disconnected unexpectedly: \(mountPoint)", component: Logger.Component.volumeMonitor)
            
            // Get volume name from mount point
            let volumeName = (mountPoint as NSString).lastPathComponent
            
            // Show notification using NotificationManager
            notificationManager.showDisconnection(volumeName: volumeName, mountPoint: mountPoint)
            
            // Check if auto-reconnect is enabled
            let settings = configurationStore.getAppSettings()
            if settings.autoReconnect {
                await attemptReconnect(mountPoint: mountPoint)
            }
            
            // Refresh volumes and update UI
            refreshMountedVolumes()
            updateMenuBar()
            
        case .reconnecting(let mountPoint):
            logger.info("Attempting to reconnect: \(mountPoint)", component: Logger.Component.volumeMonitor)
            menuBarController.setIconState(.connecting)
        }
    }
    
    /// Handles sync events from SyncEngine
    /// Requirements: Handle sync events, show notifications
    private func handleSyncEvent(_ event: SyncEvent) async {
        switch event {
        case .started(let mountPoint):
            logger.info("Sync started for \(mountPoint)", component: Logger.Component.syncEngine)
            
        case .progress(let mountPoint, let current, let total):
            logger.debug("Sync progress for \(mountPoint): \(current)/\(total)", component: Logger.Component.syncEngine)
            
        case .completed(let mountPoint):
            logger.info("Sync completed for \(mountPoint)", component: Logger.Component.syncEngine)
            
            // Show sync complete notification using NotificationManager
            // Note: We don't have the exact file count here, so we use 0 as a placeholder
            notificationManager.showSyncComplete(mountPoint: mountPoint, fileCount: 0)
            
        case .failed(let mountPoint, let errorMessage):
            logger.error("Sync failed for \(mountPoint): \(errorMessage)", component: Logger.Component.syncEngine)
            
            showNotification(
                title: NSLocalizedString("Sync Failed", comment: "Notification title"),
                body: errorMessage
            )
            
        case .conflict(let mountPoint, let conflictInfo):
            logger.warning("Sync conflict detected for \(conflictInfo.filePath) at \(mountPoint)", component: Logger.Component.syncEngine)
            
            // Show sync conflict notification using NotificationManager
            notificationManager.showSyncConflict(conflictInfo: conflictInfo)
        }
    }
    
    /// Handles discovered network services
    private func handleDiscoveredService(_ service: DiscoveredService) async {
        logger.debug("Discovered service: \(service.name) at \(service.ipAddress)", component: Logger.Component.networkScanner)
        
        // Add to discovered services if not already present
        if !discoveredServices.contains(where: { $0.ipAddress == service.ipAddress && $0.name == service.name }) {
            discoveredServices.append(service)
        }
    }
    
    /// Attempts to reconnect a disconnected mount with cancellation support
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    private func attemptReconnect(mountPoint: String) async {
        logger.info("Attempting auto-reconnect for \(mountPoint)", component: Logger.Component.app)
        
        // Cancel any existing reconnect task for this mount point
        reconnectTasks[mountPoint]?.cancel()
        
        // Create a new reconnect task
        let reconnectTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Check for cancellation
            guard !Task.isCancelled else {
                self.logger.info("Reconnect cancelled for \(mountPoint)", component: Logger.Component.app)
                return
            }
            
            // Find the configuration for this mount point
            do {
                let configs = try self.configurationStore.getAllMountConfigs()
                guard let config = configs.first(where: { $0.mountPoint == mountPoint }) else {
                    self.logger.warning("No configuration found for \(mountPoint), cannot auto-reconnect", component: Logger.Component.app)
                    return
                }
                
                // Check for cancellation before attempting mount
                try Task.checkCancellation()
                
                // Get credentials if stored
                var credentials: Credentials? = nil
                if config.rememberCredentials {
                    credentials = try? self.credentialManager.getCredentials(server: config.server, share: config.share)
                }
                
                // Check for cancellation again
                try Task.checkCancellation()
                
                // Attempt to remount
                _ = try await self.mount(
                    server: config.server,
                    share: config.share,
                    mountPoint: config.mountPoint,
                    credentials: credentials
                )
                
                self.logger.info("Auto-reconnect successful for \(mountPoint)", component: Logger.Component.app)
                
            } catch is CancellationError {
                self.logger.info("Reconnect was cancelled for \(mountPoint)", component: Logger.Component.app)
            } catch {
                self.logger.error("Auto-reconnect failed for \(mountPoint)", error: error, component: Logger.Component.app)
            }
            
            // Remove from tracked tasks
            self.reconnectTasks.removeValue(forKey: mountPoint)
        }
        
        // Track the reconnect task
        reconnectTasks[mountPoint] = reconnectTask
        
        // Wait for the task to complete
        await reconnectTask.value
    }
    
    /// Cancels a reconnect attempt for a specific mount point
    /// Requirements: 11.1, 11.2 - Support operation cancellation
    func cancelReconnect(for mountPoint: String) {
        if let task = reconnectTasks.removeValue(forKey: mountPoint) {
            task.cancel()
            logger.info("Cancelled reconnect for \(mountPoint)", component: Logger.Component.app)
        }
    }
    
    /// Cancels all pending reconnect attempts
    /// Requirements: 11.1, 11.2 - Support operation cancellation
    func cancelAllReconnects() {
        for (mountPoint, task) in reconnectTasks {
            task.cancel()
            logger.info("Cancelled reconnect for \(mountPoint)", component: Logger.Component.app)
        }
        reconnectTasks.removeAll()
    }
    
    // MARK: - Private Methods - Notifications
    
    /// Requests notification permissions
    private func requestNotificationPermissions() async {
        _ = await notificationManager.requestPermissions()
    }
    
    /// Shows a notification to the user
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - type: The notification type (optional, defaults to general notification)
    private func showNotification(title: String, body: String) {
        let settings = configurationStore.getAppSettings()
        guard settings.notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to show notification", error: error, component: Logger.Component.app)
            }
        }
    }
    
    /// Shows an error notification
    /// Requirements: Handle errors, show error dialogs
    private func showErrorNotification(error: SMBMounterError) {
        notificationManager.showMountFailure(server: "", share: "", error: error)
    }
    
    /// Shows an error dialog
    func showErrorDialog(error: SMBMounterError) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Error", comment: "Error dialog title")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
        alert.runModal()
    }
}

// MARK: - MenuBarMenuDelegate

extension AppCoordinator: MenuBarMenuDelegate {

    func menuBarDidSelectAddNewMount() {
        logger.info("User selected Add New Mount", component: Logger.Component.menuBar)

        // Open the mount configuration window
        // This will be handled by the SwiftUI views
        NotificationCenter.default.post(name: .showMountConfigWindow, object: nil)
    }

    func menuBarDidSelectScanNetwork() {
        logger.info("User selected Scan Network", component: Logger.Component.menuBar)

        // Open the network scanner window
        NotificationCenter.default.post(name: .showNetworkScannerWindow, object: nil)

        // Start scanning
        Task {
            await startNetworkScan()
        }
    }

    func menuBarDidSelectOpenDashboard() {
        logger.info("User selected Open Dashboard", component: Logger.Component.menuBar)

        // Open the dashboard window
        openDashboardWindow()
    }

    func menuBarDidSelectPreferences() {
        logger.info("User selected Preferences", component: Logger.Component.menuBar)

        // Open the preferences window
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func menuBarDidSelectQuit() {
        logger.info("User selected Quit", component: Logger.Component.menuBar)

        // Stop the coordinator
        stop()

        // Quit the application
        NSApplication.shared.terminate(nil)
    }

    func menuBarDidSelectVolume(_ volume: MountedVolume) {
        logger.info("User selected volume: \(volume.volumeName)", component: Logger.Component.menuBar)

        // Open the volume in Finder
        let url = URL(fileURLWithPath: volume.mountPoint)
        NSWorkspace.shared.open(url)
    }

    func menuBarDidSelectUnmountVolume(_ volume: MountedVolume) {
        logger.info("User selected unmount volume: \(volume.volumeName)", component: Logger.Component.menuBar)

        Task {
            do {
                try await unmount(mountPoint: volume.mountPoint)
            } catch {
                // Error is already handled in unmount method
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the mount configuration window should be shown
    static let showMountConfigWindow = Notification.Name("showMountConfigWindow")

    /// Posted when the network scanner window should be shown
    static let showNetworkScannerWindow = Notification.Name("showNetworkScannerWindow")

    /// Posted when the dashboard window should be shown
    static let showDashboardWindow = Notification.Name("showDashboardWindow")
}

// MARK: - NotificationManagerDelegate

extension AppCoordinator: NotificationManagerDelegate {
    
    func notificationManagerDidRequestOpenInFinder(mountPoint: String) {
        logger.info("Opening mount point in Finder: \(mountPoint)", component: Logger.Component.app)
        
        let url = URL(fileURLWithPath: mountPoint)
        NSWorkspace.shared.open(url)
    }
    
    func notificationManagerDidRequestReconnect(mountPoint: String) {
        logger.info("User requested reconnect from notification: \(mountPoint)", component: Logger.Component.app)
        
        Task {
            await attemptReconnect(mountPoint: mountPoint)
        }
    }
    
    func notificationManagerDidRequestViewConflict(conflictId: UUID) {
        logger.info("User requested to view conflict: \(conflictId)", component: Logger.Component.app)
        
        // Post notification to show conflict resolution UI
        NotificationCenter.default.post(
            name: .showSyncConflictWindow,
            object: nil,
            userInfo: ["conflictId": conflictId]
        )
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    /// Posted when the sync conflict window should be shown
    static let showSyncConflictWindow = Notification.Name("showSyncConflictWindow")
    
    /// Posted when mount status changes (mount/unmount operations)
    static let mountStatusDidChange = Notification.Name("mountStatusDidChange")
}
