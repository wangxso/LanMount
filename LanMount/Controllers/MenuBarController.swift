//
//  MenuBarController.swift
//  LanMount
//
//  Manages the menu bar UI including status item, icon states, and animations
//  Requirements: 9.1 - Menu bar application icon showing current mount status
//  Requirements: 9.2, 9.3, 9.4, 9.5 - Menu bar menu with mounted volumes and actions
//

import Foundation
import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarIconState

/// Represents the different states of the menu bar icon
/// Requirements: 9.1 - Display current mount status via menu bar icon
enum MenuBarIconState: Equatable {
    /// Normal state - no active operations, system is idle
    case normal
    /// Connecting state - one or more mount operations in progress
    case connecting
    /// Error state - one or more mounts have errors
    case error
    
    /// The SF Symbol name for this state
    var symbolName: String {
        switch self {
        case .normal:
            return "externaldrive.connected.to.line.below"
        case .connecting:
            return "externaldrive.badge.timemachine"
        case .error:
            return "externaldrive.badge.xmark"
        }
    }
    
    /// Accessibility description for the icon state
    var accessibilityDescription: String {
        switch self {
        case .normal:
            return NSLocalizedString("LanMount - Connected", comment: "Menu bar icon accessibility: normal state")
        case .connecting:
            return NSLocalizedString("LanMount - Connecting", comment: "Menu bar icon accessibility: connecting state")
        case .error:
            return NSLocalizedString("LanMount - Error", comment: "Menu bar icon accessibility: error state")
        }
    }
}

// MARK: - MenuBarControllerProtocol

/// Protocol defining the interface for menu bar management
protocol MenuBarControllerProtocol: AnyObject {
    /// The current icon state
    var iconState: MenuBarIconState { get }
    
    /// Publisher for icon state changes
    var iconStatePublisher: AnyPublisher<MenuBarIconState, Never> { get }
    
    /// Sets up the menu bar status item
    func setup()
    
    /// Updates the icon state
    /// - Parameter state: The new icon state
    func setIconState(_ state: MenuBarIconState)
    
    /// Updates the menu bar icon based on mount statuses
    /// - Parameter statuses: Array of mount statuses to evaluate
    func updateIconForMountStatuses(_ statuses: [MountStatus])
    
    /// Shows the menu bar item
    func show()
    
    /// Hides the menu bar item
    func hide()
    
    /// Whether the menu bar item is currently visible
    var isVisible: Bool { get }
}

// MARK: - MenuBarController

/// Controller class for managing the menu bar UI
/// Handles icon states, animations, and status item management
/// Requirements: 9.1 - Menu bar application icon showing current mount status
final class MenuBarController: NSObject, MenuBarControllerProtocol, ObservableObject {
    
    // MARK: - Constants
    
    /// Animation frame interval for connecting state (in seconds)
    private static let animationFrameInterval: TimeInterval = 0.5
    
    /// Number of animation frames for connecting state
    private static let animationFrameCount: Int = 3
    
    // MARK: - Published Properties
    
    /// The current icon state - published for SwiftUI observation
    @Published private(set) var iconState: MenuBarIconState = .normal
    
    // MARK: - Properties
    
    /// The status bar item
    private var statusItem: NSStatusItem?
    
    /// Timer for animation
    private var animationTimer: Timer?
    
    /// Current animation frame index
    private var animationFrameIndex: Int = 0
    
    /// Animation symbols for connecting state
    private let connectingAnimationSymbols: [String] = [
        "externaldrive.badge.timemachine",
        "externaldrive.connected.to.line.below.fill",
        "externaldrive.badge.timemachine"
    ]
    
    /// Subject for icon state changes
    private let iconStateSubject = CurrentValueSubject<MenuBarIconState, Never>(.normal)
    
    /// Publisher for icon state changes
    var iconStatePublisher: AnyPublisher<MenuBarIconState, Never> {
        iconStateSubject.eraseToAnyPublisher()
    }
    
    /// Whether the menu bar item is currently visible
    var isVisible: Bool {
        return statusItem != nil
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    deinit {
        stopAnimation()
        hide()
    }
    
    // MARK: - MenuBarControllerProtocol Implementation
    
    /// Sets up the menu bar status item
    /// Creates the status item and configures the initial icon
    func setup() {
        guard statusItem == nil else {
            return
        }
        
        // Create status item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Configure the button
        if let button = statusItem?.button {
            updateButtonIcon(button, for: iconState)
            button.target = self
        }
    }
    
    /// Updates the icon state
    /// - Parameter state: The new icon state
    func setIconState(_ state: MenuBarIconState) {
        guard state != iconState else {
            return
        }
        
        // Stop any existing animation
        stopAnimation()
        
        // Update the state
        iconState = state
        iconStateSubject.send(state)
        
        // Update the icon
        if let button = statusItem?.button {
            updateButtonIcon(button, for: state)
        }
        
        // Start animation if connecting
        if state == .connecting {
            startConnectingAnimation()
        }
    }
    
    /// Updates the menu bar icon based on mount statuses
    /// - Parameter statuses: Array of mount statuses to evaluate
    func updateIconForMountStatuses(_ statuses: [MountStatus]) {
        let newState = determineIconState(from: statuses)
        setIconState(newState)
    }
    
    /// Shows the menu bar item
    func show() {
        if statusItem == nil {
            setup()
        }
    }
    
    /// Hides the menu bar item
    func hide() {
        stopAnimation()
        
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
    
    // MARK: - Menu Management
    
    /// Sets the menu for the status item
    /// - Parameter menu: The menu to display when clicked
    func setMenu(_ menu: NSMenu) {
        statusItem?.menu = menu
    }
    
    /// Gets the current menu
    /// - Returns: The current menu, or nil if not set
    func getMenu() -> NSMenu? {
        return statusItem?.menu
    }
    
    /// Gets the status item button for custom handling
    /// - Returns: The status item button, or nil if not set up
    func getButton() -> NSStatusBarButton? {
        return statusItem?.button
    }
    
    // MARK: - Private Methods
    
    /// Updates the button icon for a given state
    /// - Parameters:
    ///   - button: The status bar button to update
    ///   - state: The icon state to display
    private func updateButtonIcon(_ button: NSStatusBarButton, for state: MenuBarIconState) {
        let image = NSImage(
            systemSymbolName: state.symbolName,
            accessibilityDescription: state.accessibilityDescription
        )
        
        // Configure image for menu bar
        image?.isTemplate = true
        
        button.image = image
        button.toolTip = state.accessibilityDescription
    }
    
    /// Determines the appropriate icon state from mount statuses
    /// - Parameter statuses: Array of mount statuses
    /// - Returns: The appropriate icon state
    private func determineIconState(from statuses: [MountStatus]) -> MenuBarIconState {
        // Check for any errors first
        for status in statuses {
            if case .error = status {
                return .error
            }
        }
        
        // Check for any connecting states
        for status in statuses {
            if case .connecting = status {
                return .connecting
            }
        }
        
        // Default to normal
        return .normal
    }
    
    // MARK: - Animation
    
    /// Starts the connecting animation
    private func startConnectingAnimation() {
        // Reset animation frame
        animationFrameIndex = 0
        
        // Create timer for animation
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: Self.animationFrameInterval,
            repeats: true
        ) { [weak self] _ in
            self?.advanceAnimationFrame()
        }
        
        // Add to run loop for menu bar responsiveness
        if let timer = animationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Stops the connecting animation
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationFrameIndex = 0
    }
    
    /// Advances to the next animation frame
    private func advanceAnimationFrame() {
        guard iconState == .connecting else {
            stopAnimation()
            return
        }
        
        // Advance frame index
        animationFrameIndex = (animationFrameIndex + 1) % connectingAnimationSymbols.count
        
        // Update icon
        if let button = statusItem?.button {
            let symbolName = connectingAnimationSymbols[animationFrameIndex]
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: MenuBarIconState.connecting.accessibilityDescription
            )
            image?.isTemplate = true
            button.image = image
        }
    }
}

// MARK: - MenuBarController Extension for SwiftUI

extension MenuBarController {
    
    /// Creates a binding to the icon state for SwiftUI views
    /// - Returns: A binding to the current icon state
    func iconStateBinding() -> Binding<MenuBarIconState> {
        Binding(
            get: { self.iconState },
            set: { self.setIconState($0) }
        )
    }
}

// MARK: - MenuBarMenuDelegate

/// Protocol for handling menu bar menu actions
/// Requirements: 9.2, 9.3, 9.4, 9.5
@MainActor
protocol MenuBarMenuDelegate: AnyObject {
    /// Called when user selects "Add New Mount..."
    func menuBarDidSelectAddNewMount()

    /// Called when user selects "Scan Network..."
    func menuBarDidSelectScanNetwork()

    /// Called when user selects "Open Dashboard..."
    /// Requirements: 4.1 - Add "Open Dashboard" menu item
    func menuBarDidSelectOpenDashboard()

    /// Called when user selects "Preferences..."
    func menuBarDidSelectPreferences()

    /// Called when user selects "Quit"
    func menuBarDidSelectQuit()

    /// Called when user clicks on a mounted volume to open in Finder
    func menuBarDidSelectVolume(_ volume: MountedVolume)

    /// Called when user selects to unmount a volume
    func menuBarDidSelectUnmountVolume(_ volume: MountedVolume)
}

// MARK: - MenuBuilder

/// Builds and manages the menu bar dropdown menu
/// Requirements: 9.2 - Display dropdown menu with mounted volumes
/// Requirements: 9.3 - Add "Add New Mount..." menu item
/// Requirements: 9.4 - Add "Scan Network..." menu item
/// Requirements: 9.5 - Status indicator for each mounted volume
final class MenuBuilder: NSObject {
    
    // MARK: - Constants
    
    private enum MenuItemTag: Int {
        case addNewMount = 1000
        case scanNetwork = 1001
        case openDashboard = 1002
        case preferences = 1003
        case quit = 1004
        case volumeBase = 2000
        case unmountBase = 3000
    }
    
    // MARK: - Properties
    
    /// Delegate for handling menu actions
    weak var delegate: MenuBarMenuDelegate?
    
    /// Current list of mounted volumes
    private var mountedVolumes: [MountedVolume] = []
    
    // MARK: - Menu Building
    
    /// Builds the complete menu bar menu
    /// - Parameter volumes: List of currently mounted volumes
    /// - Returns: Configured NSMenu
    func buildMenu(with volumes: [MountedVolume]) -> NSMenu {
        self.mountedVolumes = volumes
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Add mounted volumes section
        if !volumes.isEmpty {
            addMountedVolumesSection(to: menu, volumes: volumes)
            menu.addItem(NSMenuItem.separator())
        } else {
            let noVolumesItem = NSMenuItem(
                title: NSLocalizedString("No Mounted Volumes", comment: "Menu item when no volumes are mounted"),
                action: nil,
                keyEquivalent: ""
            )
            noVolumesItem.isEnabled = false
            menu.addItem(noVolumesItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        // Add action items
        addActionItems(to: menu)
        
        return menu
    }
    
    /// Adds the mounted volumes section to the menu
    /// - Parameters:
    ///   - menu: The menu to add items to
    ///   - volumes: List of mounted volumes
    private func addMountedVolumesSection(to menu: NSMenu, volumes: [MountedVolume]) {
        let headerItem = NSMenuItem(
            title: NSLocalizedString("Mounted Volumes", comment: "Menu section header for mounted volumes"),
            action: nil,
            keyEquivalent: ""
        )
        headerItem.isEnabled = false
        headerItem.toolTip = String(format: NSLocalizedString("%d mounted volumes", comment: "Accessibility: Mounted volumes count"), volumes.count)
        menu.addItem(headerItem)
        
        for (index, volume) in volumes.enumerated() {
            let volumeItem = createVolumeMenuItem(for: volume, index: index)
            menu.addItem(volumeItem)
        }
    }
    
    /// Creates a menu item for a mounted volume with status indicator
    /// - Parameters:
    ///   - volume: The mounted volume
    ///   - index: Index in the volumes array
    /// - Returns: Configured NSMenuItem
    private func createVolumeMenuItem(for volume: MountedVolume, index: Int) -> NSMenuItem {
        let statusIndicator = statusSymbol(for: volume.status)
        let title = "\(statusIndicator) \(volume.volumeName)"
        
        let item = NSMenuItem(
            title: title,
            action: #selector(volumeMenuItemClicked(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.tag = MenuItemTag.volumeBase.rawValue + index
        item.toolTip = createVolumeTooltip(for: volume)
        
        // Create submenu for volume actions
        let submenu = createVolumeSubmenu(for: volume, index: index)
        item.submenu = submenu
        
        // Set enabled based on status
        item.isEnabled = true
        
        // Set accessibility properties
        setAccessibilityProperties(for: item, volume: volume)
        
        return item
    }
    
    /// Sets accessibility properties for a volume menu item
    /// - Parameters:
    ///   - item: The menu item to configure
    ///   - volume: The mounted volume
    private func setAccessibilityProperties(for item: NSMenuItem, volume: MountedVolume) {
        // Create accessible description
        let statusDescription = statusDescription(for: volume.status)
        let accessibleTitle = "\(volume.volumeName), \(statusDescription), smb://\(volume.server)/\(volume.share)"
        
        // Set accessibility attributes via the menu item's view if available
        // Note: NSMenuItem accessibility is primarily handled through title and toolTip
        item.toolTip = accessibleTitle
    }
    
    /// Creates a submenu for volume actions (Open in Finder, Unmount)
    /// - Parameters:
    ///   - volume: The mounted volume
    ///   - index: Index in the volumes array
    /// - Returns: Configured NSMenu submenu
    private func createVolumeSubmenu(for volume: MountedVolume, index: Int) -> NSMenu {
        let submenu = NSMenu()
        
        // Open in Finder
        let openItem = NSMenuItem(
            title: NSLocalizedString("Open in Finder", comment: "Menu item to open volume in Finder"),
            action: #selector(openVolumeInFinder(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        openItem.tag = MenuItemTag.volumeBase.rawValue + index
        openItem.isEnabled = volume.status == .connected
        openItem.toolTip = String(format: NSLocalizedString("Opens %@ in Finder", comment: "Accessibility: Open in Finder tooltip"), volume.volumeName)
        submenu.addItem(openItem)
        
        submenu.addItem(NSMenuItem.separator())
        
        // Unmount
        let unmountItem = NSMenuItem(
            title: NSLocalizedString("Unmount", comment: "Menu item to unmount volume"),
            action: #selector(unmountVolume(_:)),
            keyEquivalent: ""
        )
        unmountItem.target = self
        unmountItem.tag = MenuItemTag.unmountBase.rawValue + index
        unmountItem.isEnabled = volume.status == .connected
        unmountItem.toolTip = String(format: NSLocalizedString("Unmounts %@ from the system", comment: "Accessibility: Unmount tooltip"), volume.volumeName)
        submenu.addItem(unmountItem)
        
        // Show volume info
        submenu.addItem(NSMenuItem.separator())
        
        let infoItem = NSMenuItem(
            title: createVolumeInfoString(for: volume),
            action: nil,
            keyEquivalent: ""
        )
        infoItem.isEnabled = false
        infoItem.toolTip = NSLocalizedString("Volume information", comment: "Accessibility: Volume info tooltip")
        submenu.addItem(infoItem)
        
        return submenu
    }
    
    /// Returns the status symbol for a mount status
    /// - Parameter status: The mount status
    /// - Returns: Unicode symbol representing the status
    private func statusSymbol(for status: MountStatus) -> String {
        switch status {
        case .connected:
            return "●"  // Green dot (will be colored via attributed string if needed)
        case .disconnected:
            return "○"  // Empty circle
        case .connecting:
            return "◐"  // Half-filled circle (connecting animation)
        case .error:
            return "⚠"  // Warning symbol
        }
    }
    
    /// Creates a tooltip string for a volume
    /// - Parameter volume: The mounted volume
    /// - Returns: Tooltip string
    private func createVolumeTooltip(for volume: MountedVolume) -> String {
        var tooltip = "smb://\(volume.server)/\(volume.share)\n"
        tooltip += NSLocalizedString("Mount Point: ", comment: "Tooltip label") + volume.mountPoint + "\n"
        tooltip += NSLocalizedString("Status: ", comment: "Tooltip label") + statusDescription(for: volume.status)
        return tooltip
    }
    
    /// Creates a volume info string for the submenu
    /// - Parameter volume: The mounted volume
    /// - Returns: Info string
    private func createVolumeInfoString(for volume: MountedVolume) -> String {
        var info = "smb://\(volume.server)/\(volume.share)"
        if let percentage = volume.usagePercentage {
            info += String(format: " (%.1f%% used)", percentage)
        }
        return info
    }
    
    /// Returns a human-readable description for a mount status
    /// - Parameter status: The mount status
    /// - Returns: Localized status description
    private func statusDescription(for status: MountStatus) -> String {
        switch status {
        case .connected:
            return NSLocalizedString("Connected", comment: "Mount status: connected")
        case .disconnected:
            return NSLocalizedString("Disconnected", comment: "Mount status: disconnected")
        case .connecting:
            return NSLocalizedString("Connecting...", comment: "Mount status: connecting")
        case .error(let message):
            return NSLocalizedString("Error: ", comment: "Mount status: error prefix") + message
        }
    }
    
    /// Adds the standard action items to the menu
    /// - Parameter menu: The menu to add items to
    private func addActionItems(to menu: NSMenu) {
        // Add New Mount...
        let addMountItem = NSMenuItem(
            title: NSLocalizedString("Add New Mount...", comment: "Menu item to add new mount"),
            action: #selector(addNewMountClicked(_:)),
            keyEquivalent: "n"
        )
        addMountItem.keyEquivalentModifierMask = [.command]
        addMountItem.target = self
        addMountItem.tag = MenuItemTag.addNewMount.rawValue
        addMountItem.toolTip = NSLocalizedString("Opens the mount configuration dialog to add a new SMB share", comment: "Accessibility: Add mount tooltip")
        menu.addItem(addMountItem)

        // Scan Network...
        let scanItem = NSMenuItem(
            title: NSLocalizedString("Scan Network...", comment: "Menu item to scan network"),
            action: #selector(scanNetworkClicked(_:)),
            keyEquivalent: "s"
        )
        scanItem.keyEquivalentModifierMask = [.command, .shift]
        scanItem.target = self
        scanItem.tag = MenuItemTag.scanNetwork.rawValue
        scanItem.toolTip = NSLocalizedString("Scans the local network for available SMB services", comment: "Accessibility: Scan network tooltip")
        menu.addItem(scanItem)

        // Open Dashboard...
        let dashboardItem = NSMenuItem(
            title: NSLocalizedString("Open Dashboard...", comment: "Menu item to open dashboard"),
            action: #selector(openDashboardClicked(_:)),
            keyEquivalent: "d"
        )
        dashboardItem.keyEquivalentModifierMask = [.command]
        dashboardItem.target = self
        dashboardItem.tag = MenuItemTag.openDashboard.rawValue
        dashboardItem.toolTip = NSLocalizedString("Opens the LanMount dashboard with comprehensive overview", comment: "Accessibility: Open dashboard tooltip")
        menu.addItem(dashboardItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences...
        let preferencesItem = NSMenuItem(
            title: NSLocalizedString("Preferences...", comment: "Menu item for preferences"),
            action: #selector(preferencesClicked(_:)),
            keyEquivalent: ","
        )
        preferencesItem.keyEquivalentModifierMask = [.command]
        preferencesItem.target = self
        preferencesItem.tag = MenuItemTag.preferences.rawValue
        preferencesItem.toolTip = NSLocalizedString("Opens the application preferences", comment: "Accessibility: Preferences tooltip")
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: NSLocalizedString("Quit LanMount", comment: "Menu item to quit application"),
            action: #selector(quitClicked(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        quitItem.tag = MenuItemTag.quit.rawValue
        quitItem.toolTip = NSLocalizedString("Quits the LanMount application", comment: "Accessibility: Quit tooltip")
        menu.addItem(quitItem)
    }
    
    // MARK: - Menu Actions
    
    /// Called when a volume menu item is clicked (opens in Finder)
    @objc private func volumeMenuItemClicked(_ sender: NSMenuItem) {
        let index = sender.tag - MenuItemTag.volumeBase.rawValue
        guard index >= 0 && index < mountedVolumes.count else { return }

        let volume = mountedVolumes[index]
        Task { @MainActor in
            delegate?.menuBarDidSelectVolume(volume)
        }
    }
    
    /// Called when "Open in Finder" is clicked
    @objc private func openVolumeInFinder(_ sender: NSMenuItem) {
        let index = sender.tag - MenuItemTag.volumeBase.rawValue
        guard index >= 0 && index < mountedVolumes.count else { return }
        
        let volume = mountedVolumes[index]
        openInFinder(volume: volume)
    }
    
    /// Called when "Unmount" is clicked
    @objc private func unmountVolume(_ sender: NSMenuItem) {
        let index = sender.tag - MenuItemTag.unmountBase.rawValue
        guard index >= 0 && index < mountedVolumes.count else { return }

        let volume = mountedVolumes[index]
        Task { @MainActor in
            delegate?.menuBarDidSelectUnmountVolume(volume)
        }
    }
    
    /// Called when "Add New Mount..." is clicked
    @objc private func addNewMountClicked(_ sender: NSMenuItem) {
        Task { @MainActor in
            delegate?.menuBarDidSelectAddNewMount()
        }
    }

    /// Called when "Open Dashboard..." is clicked
    @objc private func openDashboardClicked(_ sender: NSMenuItem) {
        Task { @MainActor in
            delegate?.menuBarDidSelectOpenDashboard()
        }
    }
    
    /// Called when "Scan Network..." is clicked
    @objc private func scanNetworkClicked(_ sender: NSMenuItem) {
        Task { @MainActor in
            delegate?.menuBarDidSelectScanNetwork()
        }
    }
    
    /// Called when "Preferences..." is clicked
    @objc private func preferencesClicked(_ sender: NSMenuItem) {
        Task { @MainActor in
            delegate?.menuBarDidSelectPreferences()
        }
    }
    
    /// Called when "Quit" is clicked
    @objc private func quitClicked(_ sender: NSMenuItem) {
        Task { @MainActor in
            delegate?.menuBarDidSelectQuit()
        }
    }
    
    // MARK: - Finder Integration
    
    /// Opens a mounted volume in Finder
    /// - Parameter volume: The volume to open
    /// Requirements: 9.2 - Click mounted volume to open in Finder
    func openInFinder(volume: MountedVolume) {
        let url = URL(fileURLWithPath: volume.mountPoint)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - MenuBarController Menu Extension

extension MenuBarController {
    
    /// The menu builder instance
    private static var _menuBuilder: MenuBuilder?
    
    /// Gets or creates the menu builder
    var menuBuilder: MenuBuilder {
        if MenuBarController._menuBuilder == nil {
            MenuBarController._menuBuilder = MenuBuilder()
        }
        return MenuBarController._menuBuilder!
    }
    
    /// Sets the menu delegate
    /// - Parameter delegate: The delegate to handle menu actions
    func setMenuDelegate(_ delegate: MenuBarMenuDelegate) {
        menuBuilder.delegate = delegate
    }
    
    /// Updates the menu with the current mounted volumes
    /// - Parameter volumes: List of currently mounted volumes
    /// Requirements: 9.2 - Display dropdown menu with mounted volumes
    func updateMenuWithVolumes(_ volumes: [MountedVolume]) {
        let menu = menuBuilder.buildMenu(with: volumes)
        setMenu(menu)
    }
    
    /// Rebuilds and refreshes the menu
    /// - Parameter volumes: List of currently mounted volumes
    func refreshMenu(with volumes: [MountedVolume]) {
        updateMenuWithVolumes(volumes)
    }
}

// MARK: - Mock MenuBarController for Testing

/// Mock implementation of MenuBarControllerProtocol for unit testing
final class MockMenuBarController: MenuBarControllerProtocol, ObservableObject {
    
    // MARK: - Test State
    
    /// Records of setIconState calls
    var setIconStateCalls: [MenuBarIconState] = []
    
    /// Records of updateIconForMountStatuses calls
    var updateIconForMountStatusesCalls: [[MountStatus]] = []
    
    /// Records of setup calls
    var setupCallCount: Int = 0
    
    /// Records of show calls
    var showCallCount: Int = 0
    
    /// Records of hide calls
    var hideCallCount: Int = 0
    
    /// Records of menu updates
    var updateMenuCalls: [[MountedVolume]] = []
    
    // MARK: - Properties
    
    @Published private(set) var iconState: MenuBarIconState = .normal
    
    private let iconStateSubject = CurrentValueSubject<MenuBarIconState, Never>(.normal)
    
    var iconStatePublisher: AnyPublisher<MenuBarIconState, Never> {
        iconStateSubject.eraseToAnyPublisher()
    }
    
    private var _isVisible: Bool = false
    
    var isVisible: Bool {
        return _isVisible
    }
    
    /// Mock menu builder for testing
    let mockMenuBuilder = MenuBuilder()
    
    // MARK: - MenuBarControllerProtocol Implementation
    
    func setup() {
        setupCallCount += 1
        _isVisible = true
    }
    
    func setIconState(_ state: MenuBarIconState) {
        setIconStateCalls.append(state)
        iconState = state
        iconStateSubject.send(state)
    }
    
    func updateIconForMountStatuses(_ statuses: [MountStatus]) {
        updateIconForMountStatusesCalls.append(statuses)
        
        // Determine state from statuses
        var newState: MenuBarIconState = .normal
        
        for status in statuses {
            if case .error = status {
                newState = .error
                break
            }
            if case .connecting = status {
                newState = .connecting
            }
        }
        
        setIconState(newState)
    }
    
    func show() {
        showCallCount += 1
        _isVisible = true
    }
    
    func hide() {
        hideCallCount += 1
        _isVisible = false
    }
    
    /// Mock implementation of menu update
    func updateMenuWithVolumes(_ volumes: [MountedVolume]) {
        updateMenuCalls.append(volumes)
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and state
    func reset() {
        setIconStateCalls = []
        updateIconForMountStatusesCalls = []
        setupCallCount = 0
        showCallCount = 0
        hideCallCount = 0
        updateMenuCalls = []
        iconState = .normal
        iconStateSubject.send(.normal)
        _isVisible = false
    }
}

// MARK: - MockMenuBarMenuDelegate for Testing

/// Mock delegate for testing menu actions
final class MockMenuBarMenuDelegate: MenuBarMenuDelegate {

    // MARK: - Test State

    var addNewMountCallCount: Int = 0
    var scanNetworkCallCount: Int = 0
    var openDashboardCallCount: Int = 0
    var preferencesCallCount: Int = 0
    var quitCallCount: Int = 0
    var selectedVolumes: [MountedVolume] = []
    var unmountedVolumes: [MountedVolume] = []

    // MARK: - MenuBarMenuDelegate Implementation

    func menuBarDidSelectAddNewMount() {
        addNewMountCallCount += 1
    }

    func menuBarDidSelectScanNetwork() {
        scanNetworkCallCount += 1
    }

    func menuBarDidSelectOpenDashboard() {
        openDashboardCallCount += 1
    }

    func menuBarDidSelectPreferences() {
        preferencesCallCount += 1
    }

    func menuBarDidSelectQuit() {
        quitCallCount += 1
    }

    func menuBarDidSelectVolume(_ volume: MountedVolume) {
        selectedVolumes.append(volume)
    }

    func menuBarDidSelectUnmountVolume(_ volume: MountedVolume) {
        unmountedVolumes.append(volume)
    }

    // MARK: - Test Helpers

    func reset() {
        addNewMountCallCount = 0
        scanNetworkCallCount = 0
        openDashboardCallCount = 0
        preferencesCallCount = 0
        quitCallCount = 0
        selectedVolumes = []
        unmountedVolumes = []
    }
}

// MARK: - Binding Extension

import SwiftUI

extension Binding where Value == MenuBarIconState {
    /// Creates a binding that maps to a boolean for connecting state
    var isConnecting: Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue == .connecting },
            set: { newValue in
                if newValue {
                    self.wrappedValue = .connecting
                } else if self.wrappedValue == .connecting {
                    self.wrappedValue = .normal
                }
            }
        )
    }
    
    /// Creates a binding that maps to a boolean for error state
    var hasError: Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue == .error },
            set: { newValue in
                if newValue {
                    self.wrappedValue = .error
                } else if self.wrappedValue == .error {
                    self.wrappedValue = .normal
                }
            }
        )
    }
}
