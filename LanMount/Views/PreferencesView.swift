//
//  PreferencesView.swift
//  LanMount
//
//  SwiftUI view for application preferences and settings
//  Requirements: 9.3 - Preferences view for application settings
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - PreferencesView

/// A SwiftUI view for managing application preferences
/// Provides controls for launch at login, auto-reconnect, notifications, scan interval, and log level
/// Requirements: 9.3 - Preferences view for application settings
struct PreferencesView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    /// Whether to launch the app at login
    @State private var launchAtLogin: Bool = false
    
    /// Whether to automatically reconnect disconnected mounts
    @State private var autoReconnect: Bool = true
    
    /// Whether to show system notifications
    @State private var notificationsEnabled: Bool = true
    
    /// Interval between network scans in seconds
    @State private var scanInterval: Double = 300
    
    /// Current log level
    @State private var logLevel: LogLevel = .info
    
    /// Whether settings are being saved
    @State private var isSaving: Bool = false
    
    /// Error message to display
    @State private var errorMessage: String?
    
    /// Whether the launch at login toggle is being updated
    @State private var isUpdatingLaunchAtLogin: Bool = false
    
    /// Whether launch at login requires approval
    @State private var launchAtLoginRequiresApproval: Bool = false
    
    // MARK: - Dependencies
    
    /// Configuration store for persisting settings
    private let configurationStore: ConfigurationStoreProtocol
    
    /// Launch agent manager for managing login items
    private let launchAgentManager: LaunchAgentManagerProtocol
    
    /// Logger for accessing log files
    private let logger: Logger
    
    // MARK: - Callbacks
    
    /// Called when settings are saved
    var onSave: ((AppSettings) -> Void)?
    
    /// Called when the view is cancelled
    var onCancel: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Creates a new PreferencesView
    /// - Parameters:
    ///   - configurationStore: The configuration store to use
    ///   - launchAgentManager: The launch agent manager to use
    ///   - logger: The logger instance
    ///   - onSave: Callback when settings are saved
    ///   - onCancel: Callback when cancelled
    init(
        configurationStore: ConfigurationStoreProtocol = ConfigurationStore(),
        launchAgentManager: LaunchAgentManagerProtocol = createLaunchAgentManager(),
        logger: Logger = .shared,
        onSave: ((AppSettings) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.configurationStore = configurationStore
        self.launchAgentManager = launchAgentManager
        self.logger = logger
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // General section
                    generalSection
                    
                    Divider()
                    
                    // Network section
                    networkSection
                    
                    Divider()
                    
                    // Logging section
                    loggingSection
                    
                    // Error message
                    if let error = errorMessage {
                        errorView(error)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer with buttons
            footerView
        }
        .frame(width: 480, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadSettings()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape")
                .font(.title2)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("Preferences", comment: "Preferences window title"))
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("Preferences", comment: "Accessibility: Preferences header"))
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - General Section
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("General", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Launch at login toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle(isOn: $launchAtLogin) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Launch at Login", comment: "Toggle label"))
                            Text(NSLocalizedString("Automatically start LanMount when you log in", comment: "Toggle description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(isUpdatingLaunchAtLogin)
                    .accessibilityLabel(NSLocalizedString("Launch at Login", comment: "Accessibility: Launch at login toggle"))
                    .accessibilityHint(NSLocalizedString("When enabled, LanMount will start automatically when you log in", comment: "Accessibility: Launch at login hint"))
                    .accessibilityValue(launchAtLogin ? NSLocalizedString("Enabled", comment: "Accessibility: Toggle on") : NSLocalizedString("Disabled", comment: "Accessibility: Toggle off"))
                    .onChange(of: launchAtLogin) { newValue in
                        handleLaunchAtLoginChange(newValue)
                    }
                    
                    if isUpdatingLaunchAtLogin {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                            .accessibilityLabel(NSLocalizedString("Updating launch at login setting", comment: "Accessibility: Updating"))
                    }
                }
                
                // Show approval required message if needed
                if launchAtLoginRequiresApproval {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .accessibilityHidden(true)
                        
                        Text(NSLocalizedString("Requires approval in System Settings", comment: "Approval message"))
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Button(NSLocalizedString("Open Settings", comment: "Button title")) {
                            openLoginItemsSettings()
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                        .accessibilityLabel(NSLocalizedString("Open Login Items Settings", comment: "Accessibility: Open settings button"))
                        .accessibilityHint(NSLocalizedString("Opens System Settings to approve login item", comment: "Accessibility: Open settings hint"))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(NSLocalizedString("Launch at login requires approval in System Settings", comment: "Accessibility: Approval required"))
                }
            }
            
            // Auto-reconnect toggle
            Toggle(isOn: $autoReconnect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Auto-Reconnect", comment: "Toggle label"))
                    Text(NSLocalizedString("Automatically reconnect when a mount is disconnected", comment: "Toggle description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel(NSLocalizedString("Auto-Reconnect", comment: "Accessibility: Auto-reconnect toggle"))
            .accessibilityHint(NSLocalizedString("When enabled, disconnected mounts will be automatically reconnected", comment: "Accessibility: Auto-reconnect hint"))
            .accessibilityValue(autoReconnect ? NSLocalizedString("Enabled", comment: "Accessibility: Toggle on") : NSLocalizedString("Disabled", comment: "Accessibility: Toggle off"))
            
            // Notifications toggle
            Toggle(isOn: $notificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Show Notifications", comment: "Toggle label"))
                    Text(NSLocalizedString("Display notifications for mount events and errors", comment: "Toggle description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel(NSLocalizedString("Show Notifications", comment: "Accessibility: Notifications toggle"))
            .accessibilityHint(NSLocalizedString("When enabled, notifications will be shown for mount events and errors", comment: "Accessibility: Notifications hint"))
            .accessibilityValue(notificationsEnabled ? NSLocalizedString("Enabled", comment: "Accessibility: Toggle on") : NSLocalizedString("Disabled", comment: "Accessibility: Toggle off"))
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Network Section
    
    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Network", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Scan interval setting
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Network Scan Interval", comment: "Setting label"))
                    .accessibilityHidden(true)
                
                HStack(spacing: 12) {
                    Slider(
                        value: $scanInterval,
                        in: 60...900,
                        step: 60
                    )
                    .frame(maxWidth: 250)
                    .accessibilityLabel(NSLocalizedString("Network Scan Interval", comment: "Accessibility: Scan interval slider"))
                    .accessibilityValue(formatScanInterval(scanInterval))
                    .accessibilityHint(NSLocalizedString("Adjust how often to scan for network changes", comment: "Accessibility: Scan interval hint"))
                    
                    Text(formatScanInterval(scanInterval))
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                
                Text(NSLocalizedString("How often to scan for network changes when monitoring mounts", comment: "Setting description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            
            // Preset buttons for common intervals
            HStack(spacing: 8) {
                ForEach(scanIntervalPresets, id: \.value) { preset in
                    Button(preset.label) {
                        scanInterval = preset.value
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(scanInterval == preset.value ? .accentColor : nil)
                    .accessibilityLabel(String(format: NSLocalizedString("Set scan interval to %@", comment: "Accessibility: Preset button"), preset.label))
                    .accessibilityAddTraits(scanInterval == preset.value ? [.isSelected] : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(NSLocalizedString("Scan interval presets", comment: "Accessibility: Presets group"))
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Logging Section
    
    private var loggingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Logging", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Log level picker
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Log Level", comment: "Setting label"))
                    .accessibilityHidden(true)
                
                Picker("", selection: $logLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.displayName)
                            .tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                .accessibilityLabel(NSLocalizedString("Log Level", comment: "Accessibility: Log level picker"))
                .accessibilityValue(logLevel.displayName)
                .accessibilityHint(NSLocalizedString("Select the level of detail for log messages", comment: "Accessibility: Log level hint"))
                
                Text(logLevelDescription(logLevel))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(NSLocalizedString("Log level description", comment: "Accessibility: Log level description") + ": " + logLevelDescription(logLevel))
            }
            
            // View logs button
            HStack(spacing: 12) {
                Button(action: openLogsFolder) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("View Logs", comment: "Button title"))
                    }
                }
                .accessibilityLabel(NSLocalizedString("View Logs", comment: "Accessibility: View logs button"))
                .accessibilityHint(NSLocalizedString("Opens the logs folder in Finder", comment: "Accessibility: View logs hint"))
                
                // Log file info
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Log files location:", comment: "Info label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(logger.logsDirectoryPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(NSLocalizedString("Log files location", comment: "Accessibility: Log location") + ": " + logger.logsDirectoryPath)
            }
            
            // Log size info
            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .accessibilityHidden(true)
                
                Text(String(format: NSLocalizedString("Total log size: %@", comment: "Log size info"), formatLogSize()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: NSLocalizedString("Total log size: %@", comment: "Accessibility: Log size"), formatLogSize()))
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .accessibilityHidden(true)
            
            Text(message)
                .font(.callout)
                .foregroundColor(.red)
            
            Spacer()
            
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("Dismiss error", comment: "Accessibility: Dismiss error button"))
            .accessibilityHint(NSLocalizedString("Dismisses this error message", comment: "Accessibility: Dismiss error hint"))
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("Error", comment: "Accessibility: Error prefix") + ": " + message)
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        HStack(spacing: 12) {
            // Reset to defaults button
            Button(NSLocalizedString("Reset to Defaults", comment: "Button title")) {
                resetToDefaults()
            }
            .accessibilityLabel(NSLocalizedString("Reset to Defaults", comment: "Accessibility: Reset button"))
            .accessibilityHint(NSLocalizedString("Resets all settings to their default values", comment: "Accessibility: Reset hint"))
            
            Spacer()
            
            // Cancel button
            Button(NSLocalizedString("Cancel", comment: "Button title")) {
                handleCancel()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(NSLocalizedString("Cancel", comment: "Accessibility: Cancel button"))
            .accessibilityHint(NSLocalizedString("Closes this window without saving changes", comment: "Accessibility: Cancel hint"))
            
            // Save button
            Button(action: handleSave) {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                    }
                    Text(NSLocalizedString("Save", comment: "Button title"))
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(NSLocalizedString("Save", comment: "Accessibility: Save button"))
            .accessibilityHint(NSLocalizedString("Saves all preference changes", comment: "Accessibility: Save hint"))
            .accessibilityValue(isSaving ? NSLocalizedString("Saving in progress", comment: "Accessibility: Saving") : "")
        }
        .padding()
    }
    
    // MARK: - Helper Properties
    
    /// Preset scan interval options
    private var scanIntervalPresets: [(label: String, value: Double)] {
        return [
            (NSLocalizedString("1 min", comment: "Interval preset"), 60),
            (NSLocalizedString("5 min", comment: "Interval preset"), 300),
            (NSLocalizedString("10 min", comment: "Interval preset"), 600),
            (NSLocalizedString("15 min", comment: "Interval preset"), 900)
        ]
    }
    
    // MARK: - Helper Methods
    
    /// Formats the scan interval for display
    private func formatScanInterval(_ interval: Double) -> String {
        let minutes = Int(interval / 60)
        if minutes == 1 {
            return NSLocalizedString("1 minute", comment: "Interval display")
        } else {
            return String(format: NSLocalizedString("%d minutes", comment: "Interval display"), minutes)
        }
    }
    
    /// Returns a description for the selected log level
    private func logLevelDescription(_ level: LogLevel) -> String {
        switch level {
        case .debug:
            return NSLocalizedString("Detailed information for debugging. May impact performance.", comment: "Log level description")
        case .info:
            return NSLocalizedString("General information about operations. Recommended for normal use.", comment: "Log level description")
        case .warning:
            return NSLocalizedString("Warnings and potential issues. Less verbose.", comment: "Log level description")
        case .error:
            return NSLocalizedString("Only errors. Minimal logging.", comment: "Log level description")
        }
    }
    
    /// Formats the total log size for display
    private func formatLogSize() -> String {
        let totalSize = logger.getTotalLogSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
    
    /// Loads settings from the configuration store
    private func loadSettings() {
        let settings = configurationStore.getAppSettings()
        launchAtLogin = launchAgentManager.isLaunchAtLoginEnabled()
        autoReconnect = settings.autoReconnect
        notificationsEnabled = settings.notificationsEnabled
        scanInterval = settings.scanInterval
        logLevel = settings.logLevel
        
        // Check if launch at login requires approval
        checkLaunchAtLoginStatus()
    }
    
    /// Checks the launch at login status
    private func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            if let manager = launchAgentManager as? LaunchAgentManager {
                launchAtLoginRequiresApproval = manager.requiresApproval
            }
        }
    }
    
    /// Handles changes to the launch at login toggle
    private func handleLaunchAtLoginChange(_ enabled: Bool) {
        isUpdatingLaunchAtLogin = true
        errorMessage = nil
        
        Task {
            do {
                if enabled {
                    try launchAgentManager.enableLaunchAtLogin()
                } else {
                    try launchAgentManager.disableLaunchAtLogin()
                }
                
                await MainActor.run {
                    isUpdatingLaunchAtLogin = false
                    checkLaunchAtLoginStatus()
                }
            } catch {
                await MainActor.run {
                    // Revert the toggle
                    launchAtLogin = !enabled
                    isUpdatingLaunchAtLogin = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Opens the Login Items settings in System Settings
    private func openLoginItemsSettings() {
        #if canImport(AppKit)
        if #available(macOS 13.0, *) {
            if let manager = launchAgentManager as? LaunchAgentManager {
                manager.openLoginItemsSettings()
            }
        }
        #endif
    }
    
    /// Opens the logs folder in Finder
    private func openLogsFolder() {
        #if canImport(AppKit)
        let logsPath = logger.logsDirectoryPath
        let url = URL(fileURLWithPath: logsPath)
        
        // Create the directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: logsPath) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logsPath)
        #endif
    }
    
    /// Resets all settings to defaults
    private func resetToDefaults() {
        let defaults = AppSettings.default
        autoReconnect = defaults.autoReconnect
        notificationsEnabled = defaults.notificationsEnabled
        scanInterval = defaults.scanInterval
        logLevel = defaults.logLevel
        
        // Note: We don't reset launch at login as it requires system interaction
    }
    
    /// Handles the save action
    private func handleSave() {
        isSaving = true
        errorMessage = nil
        
        let settings = AppSettings(
            launchAtLogin: launchAtLogin,
            autoReconnect: autoReconnect,
            notificationsEnabled: notificationsEnabled,
            scanInterval: scanInterval,
            logLevel: logLevel
        )
        
        do {
            try configurationStore.saveAppSettings(settings)
            
            // Update the logger's log level
            logger.logLevel = logLevel
            
            onSave?(settings)
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            errorMessage = String(format: NSLocalizedString("Failed to save settings: %@", comment: "Error message"), error.localizedDescription)
        }
    }
    
    /// Handles the cancel action
    private func handleCancel() {
        onCancel?()
        dismiss()
    }
}

// MARK: - LogLevel Extension

extension LogLevel {
    /// Display name for the log level
    var displayName: String {
        switch self {
        case .debug:
            return NSLocalizedString("Debug", comment: "Log level name")
        case .info:
            return NSLocalizedString("Info", comment: "Log level name")
        case .warning:
            return NSLocalizedString("Warning", comment: "Log level name")
        case .error:
            return NSLocalizedString("Error", comment: "Log level name")
        }
    }
}

// MARK: - Preview

#Preview("Default Settings") {
    PreferencesView()
}

#Preview("With Error") {
    PreferencesView()
}
