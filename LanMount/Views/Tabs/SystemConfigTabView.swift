//
//  SystemConfigTabView.swift
//  LanMount
//
//  System configuration tab view for managing application settings
//  Requirements: 5.1 - Provide launch at login setting toggle
//  Requirements: 5.2 - Provide menu bar icon display setting toggle
//  Requirements: 5.3 - Provide auto-mount on network change setting toggle
//  Requirements: 5.4 - Provide notification settings (mount/unmount, error, storage warning notifications)
//  Requirements: 5.5 - Display app version and about information
//  Requirements: 5.6 - Provide data export and import functionality
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Language Management (Inline Implementation)

/// Supported languages in the application
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    
    var id: String { rawValue }
    
    var nativeDisplayName: String {
        switch self {
        case .system:
            return NSLocalizedString("System Default", comment: "System language option")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

/// Manages application language settings
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguagePreference()
            applyLanguage()
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let languageKey = "AppLanguage"
    
    private init() {
        if let savedLanguage = userDefaults.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
        applyLanguage()
    }
    
    private func saveLanguagePreference() {
        userDefaults.set(currentLanguage.rawValue, forKey: languageKey)
    }
    
    private func applyLanguage() {
        let languageCode: String?
        
        switch currentLanguage {
        case .system:
            languageCode = nil
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            languageCode = "en"
        case .simplifiedChinese:
            languageCode = "zh-Hans"
        }
        
        if let code = languageCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
        
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("LanguageDidChange")
}

// MARK: - SystemConfigTabView

/// 系统配置选项卡视图
/// Provides system-wide settings management including:
/// - General settings (launch at login, menu bar icon, auto-mount)
/// - Notification settings (mount/unmount, error, storage warning)
/// - Data management (export/import configurations)
/// - About information (app version, credits)
///
/// Example usage:
/// ```swift
/// SystemConfigTabView()
/// ```
struct SystemConfigTabView: View {
    
    // MARK: - AppStorage Properties
    
    /// Whether to launch the app at login
    /// Requirements: 5.1 - Provide launch at login setting toggle
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    /// Whether to show the app icon in the menu bar
    /// Requirements: 5.2 - Provide menu bar icon display setting toggle
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    
    /// Whether to auto-mount when network changes
    /// Requirements: 5.3 - Provide auto-mount on network change setting toggle
    @AppStorage("autoMountOnNetworkChange") private var autoMountOnNetworkChange = true
    
    /// Whether to show mount/unmount notifications
    /// Requirements: 5.4 - Provide notification settings
    @AppStorage("mountNotifications") private var mountNotifications = true
    
    /// Whether to show error notifications
    /// Requirements: 5.4 - Provide notification settings
    @AppStorage("errorNotifications") private var errorNotifications = true
    
    /// Whether to show storage warning notifications
    /// Requirements: 5.4 - Provide notification settings
    @AppStorage("storageWarningNotifications") private var storageWarningNotifications = true
    
    // MARK: - State Properties
    
    /// Whether the export file dialog is showing
    @State private var showingExportDialog = false
    
    /// Whether the import file dialog is showing
    @State private var showingImportDialog = false
    
    /// Whether an alert is showing
    @State private var showingAlert = false
    
    /// Alert title
    @State private var alertTitle = ""
    
    /// Alert message
    @State private var alertMessage = ""
    
    /// Whether the launch at login toggle is being updated
    @State private var isUpdatingLaunchAtLogin = false
    
    /// Whether launch at login requires approval
    @State private var launchAtLoginRequiresApproval = false
    
    // MARK: - Environment Objects
    
    /// Language manager for handling language changes
    @StateObject private var languageManager = LanguageManager.shared
    
    // MARK: - Dependencies
    
    /// Configuration store for data export/import
    private let configurationStore: ConfigurationStoreProtocol
    
    /// Launch agent manager for managing login items
    private let launchAgentManager: LaunchAgentManagerProtocol
    
    // MARK: - Initialization
    
    /// Creates a new SystemConfigTabView
    /// - Parameters:
    ///   - configurationStore: The configuration store to use (defaults to ConfigurationStore)
    ///   - launchAgentManager: The launch agent manager to use (defaults to system manager)
    init(
        configurationStore: ConfigurationStoreProtocol = ConfigurationStore(),
        launchAgentManager: LaunchAgentManagerProtocol = createLaunchAgentManager()
    ) {
        self.configurationStore = configurationStore
        self.launchAgentManager = launchAgentManager
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 通用设置
                // Requirements: 5.1, 5.2, 5.3
                generalSettingsSection
                
                Divider()
                
                // 通知设置
                // Requirements: 5.4
                notificationSettingsSection
                
                Divider()
                
                // 数据管理
                // Requirements: 5.6
                dataManagementSection
                
                Divider()
                
                // 关于
                // Requirements: 5.5
                aboutSection
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("System Configuration Tab", comment: "Tab accessibility label"))
        .onAppear {
            checkLaunchAtLoginStatus()
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: createExportDocument(),
            contentType: .json,
            defaultFilename: "lanmount_config_\(formattedDate()).json"
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }
    
    // MARK: - General Settings Section
    
    /// General settings section with launch at login, menu bar, and auto-mount toggles
    /// Requirements: 5.1, 5.2, 5.3
    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            sectionHeader(
                title: NSLocalizedString("General", comment: "General settings section"),
                icon: "gearshape.fill",
                color: .gray
            )
            
            GlassCard(
                accessibility: .summary(
                    label: NSLocalizedString("General settings", comment: "General settings accessibility"),
                    hint: nil
                )
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Launch at login toggle
                    // Requirements: 5.1
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle(isOn: $launchAtLogin) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NSLocalizedString("Launch at Login", comment: "Toggle label"))
                                        .font(.body)
                                    Text(NSLocalizedString("Automatically start LanMount when you log in", comment: "Toggle description"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .disabled(isUpdatingLaunchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                handleLaunchAtLoginChange(newValue)
                            }
                            
                            if isUpdatingLaunchAtLogin {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            }
                        }
                        
                        // Show approval required message if needed
                        if launchAtLoginRequiresApproval {
                            approvalRequiredView
                        }
                    }
                    
                    Divider()
                    
                    // Menu bar icon toggle
                    // Requirements: 5.2
                    Toggle(isOn: $showInMenuBar) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Show in Menu Bar", comment: "Toggle label"))
                                .font(.body)
                            Text(NSLocalizedString("Display LanMount icon in the menu bar for quick access", comment: "Toggle description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    // Auto-mount on network change toggle
                    // Requirements: 5.3
                    Toggle(isOn: $autoMountOnNetworkChange) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Auto-Mount on Network Change", comment: "Toggle label"))
                                .font(.body)
                            Text(NSLocalizedString("Automatically mount configured shares when network becomes available", comment: "Toggle description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    // Language selection
                    languageSelectionView
                }
                .padding()
            }
        }
    }
    
    /// View shown when launch at login requires approval
    private var approvalRequiredView: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text(NSLocalizedString("Requires approval in System Settings", comment: "Approval message"))
                .font(.caption)
                .foregroundColor(.orange)
            
            Button(NSLocalizedString("Open Settings", comment: "Button title")) {
                openLoginItemsSettings()
            }
            .font(.caption)
            .buttonStyle(.link)
        }
    }
    
    // MARK: - Notification Settings Section
    
    /// Notification settings section with mount, error, and storage warning toggles
    /// Requirements: 5.4
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            sectionHeader(
                title: NSLocalizedString("Notifications", comment: "Notifications section"),
                icon: "bell.fill",
                color: .orange
            )
            
            GlassCard(
                accessibility: .summary(
                    label: NSLocalizedString("Notification settings", comment: "Notification settings accessibility"),
                    hint: nil
                )
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Mount/unmount notifications
                    Toggle(isOn: $mountNotifications) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Mount/Unmount Notifications", comment: "Toggle label"))
                                .font(.body)
                            Text(NSLocalizedString("Show notifications when drives are mounted or unmounted", comment: "Toggle description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    // Error notifications
                    Toggle(isOn: $errorNotifications) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Error Notifications", comment: "Toggle label"))
                                .font(.body)
                            Text(NSLocalizedString("Show notifications when connection errors occur", comment: "Toggle description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    // Storage warning notifications
                    Toggle(isOn: $storageWarningNotifications) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Storage Warning Notifications", comment: "Toggle label"))
                                .font(.body)
                            Text(NSLocalizedString("Show notifications when storage usage exceeds 90%", comment: "Toggle description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Data Management Section
    
    /// Data management section with export and import functionality
    /// Requirements: 5.6
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            sectionHeader(
                title: NSLocalizedString("Data Management", comment: "Data management section"),
                icon: "externaldrive.fill",
                color: .blue
            )
            
            GlassCard(
                accessibility: .summary(
                    label: NSLocalizedString("Data management options", comment: "Data management accessibility"),
                    hint: nil
                )
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // Export section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Export Configurations", comment: "Export section title"))
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(NSLocalizedString("Export all mount configurations to a JSON file. Credentials are not exported for security.", comment: "Export description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            showingExportDialog = true
                        } label: {
                            Label(
                                NSLocalizedString("Export", comment: "Export button"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Divider()
                    
                    // Import section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Import Configurations", comment: "Import section title"))
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(NSLocalizedString("Import mount configurations from a JSON file. You will need to re-enter credentials.", comment: "Import description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            showingImportDialog = true
                        } label: {
                            Label(
                                NSLocalizedString("Import", comment: "Import button"),
                                systemImage: "square.and.arrow.down"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - About Section
    
    /// About section with app version and information
    /// Requirements: 5.5
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            sectionHeader(
                title: NSLocalizedString("About", comment: "About section"),
                icon: "info.circle.fill",
                color: .purple
            )
            
            GlassCard(
                accessibility: .summary(
                    label: aboutAccessibilityLabel,
                    hint: nil
                )
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // App icon and name
                    HStack(spacing: 16) {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LanMount")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(NSLocalizedString("SMB Network Drive Manager", comment: "App subtitle"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Version info
                    VStack(alignment: .leading, spacing: 8) {
                        aboutInfoRow(
                            label: NSLocalizedString("Version", comment: "Version label"),
                            value: appVersion
                        )
                        
                        aboutInfoRow(
                            label: NSLocalizedString("Build", comment: "Build label"),
                            value: appBuild
                        )
                        
                        aboutInfoRow(
                            label: NSLocalizedString("macOS", comment: "macOS label"),
                            value: macOSVersion
                        )
                    }
                    
                    Divider()
                    
                    // Copyright and links
                    VStack(alignment: .leading, spacing: 8) {
                        Text(copyrightText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            Button(NSLocalizedString("GitHub", comment: "GitHub link")) {
                                openURL("https://github.com/lanmount/lanmount")
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                            
                            Button(NSLocalizedString("Report Issue", comment: "Report issue link")) {
                                openURL("https://github.com/lanmount/lanmount/issues")
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Helper Views
    
    /// Section header with icon and title
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        Label {
            Text(title)
                .font(.headline)
        } icon: {
            Image(systemName: icon)
                .foregroundColor(color)
        }
        .accessibilityAddTraits(.isHeader)
    }
    
    /// About info row with label and value
    private func aboutInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Computed Properties
    
    /// App version string
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// App build number
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// macOS version string
    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    /// Copyright text
    private var copyrightText: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) LanMount. All rights reserved."
    }
    
    /// Accessibility label for about section
    private var aboutAccessibilityLabel: String {
        String(
            format: NSLocalizedString(
                "LanMount version %@, build %@",
                comment: "About accessibility label"
            ),
            appVersion,
            appBuild
        )
    }
    
    // MARK: - Helper Methods
    
    /// Formats the current date for export filename
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    /// Creates the export document
    private func createExportDocument() -> ConfigurationExportDocument? {
        do {
            let configurations = try configurationStore.getAllMountConfigs()
            let export = ConfigurationExport(configurations: configurations)
            return ConfigurationExportDocument(export: export)
        } catch {
            alertTitle = NSLocalizedString("Export Error", comment: "Export error title")
            alertMessage = error.localizedDescription
            showingAlert = true
            return nil
        }
    }
    
    /// Handles the export result
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertTitle = NSLocalizedString("Export Successful", comment: "Export success title")
            alertMessage = String(
                format: NSLocalizedString(
                    "Configurations exported to %@",
                    comment: "Export success message"
                ),
                url.lastPathComponent
            )
            showingAlert = true
        case .failure(let error):
            alertTitle = NSLocalizedString("Export Error", comment: "Export error title")
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    /// Handles the import result
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importConfigurations(from: url)
        case .failure(let error):
            alertTitle = NSLocalizedString("Import Error", comment: "Import error title")
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    /// Imports configurations from a file URL
    private func importConfigurations(from url: URL) {
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(
                    domain: "SystemConfigTabView",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot access file"]
                )
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: url)
            let export = try ConfigurationExport.fromJSON(data)
            let configurations = export.toMountConfigurations()
            
            // Save imported configurations
            var importedCount = 0
            for config in configurations {
                try configurationStore.saveMountConfig(config)
                importedCount += 1
            }
            
            alertTitle = NSLocalizedString("Import Successful", comment: "Import success title")
            alertMessage = String(
                format: NSLocalizedString(
                    "Successfully imported %d configuration(s). Please re-enter credentials for each mount.",
                    comment: "Import success message"
                ),
                importedCount
            )
            showingAlert = true
            
        } catch {
            alertTitle = NSLocalizedString("Import Error", comment: "Import error title")
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    /// Checks the launch at login status
    private func checkLaunchAtLoginStatus() {
        launchAtLogin = launchAgentManager.isLaunchAtLoginEnabled()
        
        if #available(macOS 13.0, *) {
            if let manager = launchAgentManager as? LaunchAgentManager {
                launchAtLoginRequiresApproval = manager.requiresApproval
            }
        }
    }
    
    /// Handles changes to the launch at login toggle
    private func handleLaunchAtLoginChange(_ enabled: Bool) {
        isUpdatingLaunchAtLogin = true
        
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
                    alertTitle = NSLocalizedString("Error", comment: "Error title")
                    alertMessage = error.localizedDescription
                    showingAlert = true
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
    
    /// Language selection view
    private var languageSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Language", comment: "Language setting label"))
                .font(.body)
            
            Picker("", selection: $languageManager.currentLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.nativeDisplayName)
                        .tag(language)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 200, alignment: .leading)
            
            Text(NSLocalizedString("Restart required for language change to take full effect", comment: "Language change note"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// Opens a URL in the default browser
    private func openURL(_ urlString: String) {
        #if canImport(AppKit)
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

// MARK: - ConfigurationExportDocument

/// Document type for exporting configurations
struct ConfigurationExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let export: ConfigurationExport
    
    init(export: ConfigurationExport) {
        self.export = export
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.export = try ConfigurationExport.fromJSON(data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try export.toJSON()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#if DEBUG
struct SystemConfigTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode
            SystemConfigTabView()
                .frame(width: 800, height: 700)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            // Dark mode
            SystemConfigTabView()
                .frame(width: 800, height: 700)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
