//
//  ConfigurationEditForm.swift
//  LanMount
//
//  Configuration edit form with real-time validation
//  Requirements: 5.3 - Provide form validation and display real-time error prompts
//  Requirements: 5.6 - Provide "Test Connection" functionality to verify configuration validity
//

import SwiftUI

// MARK: - ConfigurationEditForm

/// A form view for editing SMB mount configurations with real-time validation
///
/// This form displays fields for server, share, mountPoint, autoMount, and syncEnabled,
/// and shows validation errors inline near the relevant fields as the user types.
///
/// Example usage:
/// ```swift
/// ConfigurationEditForm(
///     configuration: existingConfig,
///     onSave: { config in
///         // Handle save
///     },
///     onCancel: {
///         // Handle cancel
///     },
///     onTestConnection: { config in
///         // Test connection and return result
///         return .success(message: "Connected successfully")
///     }
/// )
/// ```
///
/// Requirements: 5.3 - Provide form validation and display real-time error prompts
/// Requirements: 5.6 - Provide "Test Connection" functionality
struct ConfigurationEditForm: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State Properties
    
    /// Server address (hostname or IP)
    @State private var server: String
    
    /// Share name on the server
    @State private var share: String
    
    /// Mount point path
    @State private var mountPoint: String
    
    /// Whether to auto-mount this share on login
    @State private var autoMount: Bool
    
    /// Whether to enable file synchronization
    @State private var syncEnabled: Bool
    
    /// Username for SMB authentication
    @State private var username: String
    
    /// Password for SMB authentication
    @State private var password: String
    
    /// Whether to remember credentials in Keychain
    @State private var rememberCredentials: Bool
    
    /// Current validation errors mapped by field
    @State private var validationErrors: [ValidationFieldType: String] = [:]
    
    /// Whether a test connection is in progress
    @State private var isTestingConnection: Bool = false
    
    /// Result of the last connection test
    @State private var connectionTestResult: ConfigurationTestResult?
    
    /// Whether the form is being saved
    @State private var isSaving: Bool = false
    
    /// Whether to use auto-generated mount point
    @State private var useAutoMountPoint: Bool
    
    // MARK: - Services
    
    /// Credential manager for Keychain operations
    private let credentialManager = CredentialManager()
    
    // MARK: - Properties
    
    /// The existing configuration being edited (nil for new configuration)
    private let existingConfiguration: MountConfiguration?
    
    /// Whether this is editing an existing configuration or creating a new one
    private var isEditing: Bool {
        existingConfiguration != nil
    }
    
    // MARK: - Callbacks
    
    /// Called when the user saves the configuration
    var onSave: ((MountConfiguration) -> Void)?
    
    /// Called when the user cancels
    var onCancel: (() -> Void)?
    
    /// Called when the user tests the connection
    var onTestConnection: ((MountConfiguration) async -> ConfigurationTestResult)?
    
    // MARK: - Initialization
    
    /// Creates a new ConfigurationEditForm
    /// - Parameters:
    ///   - configuration: Optional existing configuration to edit
    ///   - onSave: Callback when configuration is saved
    ///   - onCancel: Callback when configuration is cancelled
    ///   - onTestConnection: Callback to test the connection
    init(
        configuration: MountConfiguration? = nil,
        onSave: ((MountConfiguration) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onTestConnection: ((MountConfiguration) async -> ConfigurationTestResult)? = nil
    ) {
        self.existingConfiguration = configuration
        self.onSave = onSave
        self.onCancel = onCancel
        self.onTestConnection = onTestConnection
        
        // Initialize state from existing configuration or defaults
        if let config = configuration {
            _server = State(initialValue: config.server)
            _share = State(initialValue: config.share)
            _mountPoint = State(initialValue: config.mountPoint)
            _autoMount = State(initialValue: config.autoMount)
            _syncEnabled = State(initialValue: config.syncEnabled)
            _rememberCredentials = State(initialValue: config.rememberCredentials)
            // Check if mount point matches auto-generated pattern
            _useAutoMountPoint = State(initialValue: config.mountPoint == "/Volumes/\(config.share)")
            // Credentials will be loaded in onAppear
            _username = State(initialValue: "")
            _password = State(initialValue: "")
        } else {
            _server = State(initialValue: "")
            _share = State(initialValue: "")
            _mountPoint = State(initialValue: "")
            _autoMount = State(initialValue: false)
            _syncEnabled = State(initialValue: false)
            _rememberCredentials = State(initialValue: false)
            _useAutoMountPoint = State(initialValue: true)
            _username = State(initialValue: "")
            _password = State(initialValue: "")
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Server section
                    serverSection
                    
                    // Credentials section
                    credentialsSection
                    
                    // Mount point section
                    mountPointSection
                    
                    // Options section
                    optionsSection
                    
                    // Connection test result
                    if let result = connectionTestResult {
                        connectionTestResultView(result)
                    }
                }
                .padding(20)
            }
            .onAppear {
                loadExistingCredentials()
            }
            
            Divider()
            
            // Footer with buttons
            footerView
        }
        .frame(width: 480, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.title2)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text(isEditing 
                ? NSLocalizedString("Edit Configuration", comment: "Edit config window title")
                : NSLocalizedString("New Configuration", comment: "New config window title"))
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEditing ? "Edit Configuration" : "New Configuration")
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Server Section
    
    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Server Information", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Server address field
            FormField(
                label: NSLocalizedString("Server Address", comment: "Field label"),
                placeholder: NSLocalizedString("e.g., 192.168.1.100 or server.local", comment: "Server placeholder"),
                text: $server,
                error: validationErrors[.server],
                accessibilityHint: NSLocalizedString("Enter the server hostname or IP address", comment: "Server hint")
            )
            .onChange(of: server) { _ in
                validateFieldRealTime(.server)
                connectionTestResult = nil
            }
            
            // Share name field
            FormField(
                label: NSLocalizedString("Share Name", comment: "Field label"),
                placeholder: NSLocalizedString("e.g., Documents or Public", comment: "Share placeholder"),
                text: $share,
                error: validationErrors[.share],
                accessibilityHint: NSLocalizedString("Enter the name of the shared folder", comment: "Share hint")
            )
            .onChange(of: share) { newValue in
                validateFieldRealTime(.share)
                connectionTestResult = nil
                
                // Update mount point if using auto-generated
                if useAutoMountPoint && !newValue.isEmpty {
                    mountPoint = "/Volumes/\(newValue)"
                }
            }
        }
    }
    
    // MARK: - Credentials Section
    
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Credentials", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Username field
            FormField(
                label: NSLocalizedString("Username", comment: "Field label"),
                placeholder: NSLocalizedString("e.g., admin or DOMAIN\\user", comment: "Username placeholder"),
                text: $username,
                error: nil,
                accessibilityHint: NSLocalizedString("Enter the username for SMB authentication", comment: "Username hint")
            )
            
            // Password field
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Password", comment: "Field label"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                SecureField(NSLocalizedString("Enter password", comment: "Password placeholder"), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Password")
                    .accessibilityHint(NSLocalizedString("Enter the password for SMB authentication", comment: "Password hint"))
            }
            
            // Remember credentials toggle
            Toggle(isOn: $rememberCredentials) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Remember Credentials", comment: "Toggle label"))
                    Text(NSLocalizedString("Store credentials securely in Keychain", comment: "Toggle description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Remember Credentials")
            .accessibilityHint("When enabled, credentials will be stored securely in the macOS Keychain")
        }
    }
    
    // MARK: - Mount Point Section
    
    private var mountPointSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Mount Point", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Auto mount point toggle
            Toggle(isOn: $useAutoMountPoint) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Use Default Mount Point", comment: "Toggle label"))
                    Text(NSLocalizedString("Mount at /Volumes/<share name>", comment: "Toggle description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .onChange(of: useAutoMountPoint) { useAuto in
                if useAuto && !share.isEmpty {
                    mountPoint = "/Volumes/\(share)"
                }
            }
            .accessibilityLabel("Use Default Mount Point")
            .accessibilityHint("When enabled, the share will be mounted at /Volumes/ followed by the share name")
            
            // Custom mount point field (only shown when not using auto)
            if !useAutoMountPoint {
                FormField(
                    label: NSLocalizedString("Custom Mount Point", comment: "Field label"),
                    placeholder: NSLocalizedString("e.g., /Volumes/MyShare", comment: "Mount point placeholder"),
                    text: $mountPoint,
                    error: validationErrors[.mountPoint],
                    accessibilityHint: NSLocalizedString("Enter the local path where the share should be mounted", comment: "Mount point hint")
                )
                .onChange(of: mountPoint) { _ in
                    validateFieldRealTime(.mountPoint)
                    connectionTestResult = nil
                }
            }
        }
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Options", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Auto-mount toggle
            Toggle(isOn: $autoMount) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Auto-Mount on Login", comment: "Toggle label"))
                    Text(NSLocalizedString("Automatically mount this share when you log in", comment: "Toggle description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Auto-Mount on Login")
            .accessibilityHint("When enabled, this share will be automatically mounted when you log in")
            
            // Enable sync toggle
            Toggle(isOn: $syncEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Enable Synchronization", comment: "Toggle label"))
                    Text(NSLocalizedString("Keep local and remote files in sync", comment: "Toggle description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Enable Synchronization")
            .accessibilityHint("When enabled, local and remote files will be kept in sync")
        }
    }
    
    // MARK: - Connection Test Result View
    
    private func connectionTestResultView(_ result: ConfigurationTestResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
                .accessibilityHidden(true)
            
            Text(result.message)
                .font(.callout)
                .foregroundColor(result.success ? .green : .red)
            
            Spacer()
        }
        .padding(12)
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result.success 
            ? "Connection test successful: \(result.message)"
            : "Connection test failed: \(result.message)")
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        HStack(spacing: 12) {
            // Test Connection button
            Button(action: testConnection) {
                HStack(spacing: 6) {
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "network")
                            .accessibilityHidden(true)
                    }
                    Text(NSLocalizedString("Test Connection", comment: "Button title"))
                }
            }
            .disabled(isTestingConnection || !canTestConnection)
            .accessibilityLabel("Test Connection")
            .accessibilityHint("Tests the connection to the SMB server with current settings")
            
            Spacer()
            
            // Cancel button
            Button(NSLocalizedString("Cancel", comment: "Button title")) {
                handleCancel()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Cancel")
            .accessibilityHint("Closes this window without saving changes")
            
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
            .disabled(isSaving || !canSave)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Save")
            .accessibilityHint("Saves the mount configuration")
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    /// Whether the form can be saved (basic validation)
    private var canSave: Bool {
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)
        let trimmedShare = share.trimmingCharacters(in: .whitespaces)
        return !trimmedServer.isEmpty && !trimmedShare.isEmpty && validationErrors.isEmpty
    }
    
    /// Whether a connection test can be performed
    private var canTestConnection: Bool {
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)
        let trimmedShare = share.trimmingCharacters(in: .whitespaces)
        return !trimmedServer.isEmpty && !trimmedShare.isEmpty
    }
    
    // MARK: - Validation
    
    /// Validates a specific field in real-time and updates the error state
    private func validateFieldRealTime(_ field: ValidationFieldType) {
        // Create a temporary configuration to validate
        let tempConfig = createConfiguration()
        let errors = tempConfig.validate()
        
        // Map MountConfigurationValidationError to field-specific errors
        switch field {
        case .server:
            if let serverError = errors.first(where: { isServerError($0) }) {
                validationErrors[.server] = serverError.errorDescription
            } else {
                validationErrors.removeValue(forKey: .server)
            }
        case .share:
            if let shareError = errors.first(where: { isShareError($0) }) {
                validationErrors[.share] = shareError.errorDescription
            } else {
                validationErrors.removeValue(forKey: .share)
            }
        case .mountPoint:
            // Mount point validation (basic check)
            let trimmedMountPoint = mountPoint.trimmingCharacters(in: .whitespaces)
            if !useAutoMountPoint && trimmedMountPoint.isEmpty {
                validationErrors[.mountPoint] = NSLocalizedString("Mount point cannot be empty", comment: "Validation error")
            } else if !useAutoMountPoint && !trimmedMountPoint.hasPrefix("/") {
                validationErrors[.mountPoint] = NSLocalizedString("Mount point must be an absolute path", comment: "Validation error")
            } else {
                validationErrors.removeValue(forKey: .mountPoint)
            }
        }
    }
    
    /// Validates the entire form and returns true if valid
    private func validateForm() -> Bool {
        validationErrors.removeAll()
        
        let config = createConfiguration()
        let errors = config.validate()
        
        // Map all errors to their respective fields
        for error in errors {
            if isServerError(error) {
                validationErrors[.server] = error.errorDescription
            } else if isShareError(error) {
                validationErrors[.share] = error.errorDescription
            }
        }
        
        // Validate mount point
        if !useAutoMountPoint {
            let trimmedMountPoint = mountPoint.trimmingCharacters(in: .whitespaces)
            if trimmedMountPoint.isEmpty {
                validationErrors[.mountPoint] = NSLocalizedString("Mount point cannot be empty", comment: "Validation error")
            } else if !trimmedMountPoint.hasPrefix("/") {
                validationErrors[.mountPoint] = NSLocalizedString("Mount point must be an absolute path", comment: "Validation error")
            }
        }
        
        return validationErrors.isEmpty
    }
    
    /// Checks if the error is related to the server field
    private func isServerError(_ error: MountConfigurationValidationError) -> Bool {
        switch error {
        case .serverEmpty, .serverFormatInvalid:
            return true
        case .shareEmpty:
            return false
        }
    }
    
    /// Checks if the error is related to the share field
    private func isShareError(_ error: MountConfigurationValidationError) -> Bool {
        switch error {
        case .shareEmpty:
            return true
        case .serverEmpty, .serverFormatInvalid:
            return false
        }
    }
    
    /// Creates a MountConfiguration from the current form state
    private func createConfiguration() -> MountConfiguration {
        let effectiveMountPoint = useAutoMountPoint 
            ? "/Volumes/\(share.trimmingCharacters(in: .whitespaces))"
            : mountPoint.trimmingCharacters(in: .whitespaces)
        
        return MountConfiguration(
            id: existingConfiguration?.id ?? UUID(),
            server: server.trimmingCharacters(in: .whitespaces),
            share: share.trimmingCharacters(in: .whitespaces),
            mountPoint: effectiveMountPoint,
            autoMount: autoMount,
            rememberCredentials: rememberCredentials,
            syncEnabled: syncEnabled,
            createdAt: existingConfiguration?.createdAt ?? Date(),
            lastModified: Date()
        )
    }
    
    // MARK: - Actions
    
    /// Handles the save action
    private func handleSave() {
        guard validateForm() else { return }
        
        isSaving = true
        var config = createConfiguration()
        
        // Save or delete credentials based on rememberCredentials toggle
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)
        let trimmedShare = share.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        
        if rememberCredentials && !trimmedUsername.isEmpty {
            // Save credentials to Keychain
            do {
                try credentialManager.saveCredentials(
                    server: trimmedServer,
                    share: trimmedShare,
                    username: trimmedUsername,
                    password: password
                )
            } catch {
                // Log error but don't block save
                print("Failed to save credentials: \(error)")
            }
        } else if !rememberCredentials {
            // Delete credentials from Keychain if user unchecked remember
            do {
                try credentialManager.deleteCredentials(
                    server: trimmedServer,
                    share: trimmedShare
                )
            } catch {
                // Ignore delete errors
            }
        }
        
        onSave?(config)
        isSaving = false
        dismiss()
    }
    
    /// Handles the cancel action
    private func handleCancel() {
        onCancel?()
        dismiss()
    }
    
    /// Loads existing credentials from Keychain when editing a configuration
    private func loadExistingCredentials() {
        guard let config = existingConfiguration else { return }
        
        // Try to load credentials from Keychain
        do {
            if let credentials = try credentialManager.getCredentials(
                server: config.server,
                share: config.share
            ) {
                username = credentials.username
                password = credentials.password
            }
        } catch {
            // Ignore errors - credentials may not exist
            print("Failed to load credentials: \(error)")
        }
    }
    
    /// Tests the connection with current settings
    private func testConnection() {
        guard validateForm() else { return }
        
        isTestingConnection = true
        connectionTestResult = nil
        
        let config = createConfiguration()
        
        Task {
            if let testHandler = onTestConnection {
                let result = await testHandler(config)
                await MainActor.run {
                    connectionTestResult = result
                    isTestingConnection = false
                }
            } else {
                // Default test behavior - simulate a brief delay
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    connectionTestResult = ConfigurationTestResult(
                        success: false,
                        message: NSLocalizedString("Connection test not available", comment: "Test result message")
                    )
                    isTestingConnection = false
                }
            }
        }
    }
}

// MARK: - ValidationFieldType

/// Field types for validation error mapping
enum ValidationFieldType: Hashable {
    case server
    case share
    case mountPoint
}

// MARK: - ConfigurationTestResult

/// Result of a configuration connection test
struct ConfigurationTestResult {
    let success: Bool
    let message: String
    
    /// Creates a successful connection test result
    static func success(message: String = NSLocalizedString("Connection successful", comment: "Test result")) -> ConfigurationTestResult {
        return ConfigurationTestResult(success: true, message: message)
    }
    
    /// Creates a failed connection test result
    static func failure(message: String) -> ConfigurationTestResult {
        return ConfigurationTestResult(success: false, message: message)
    }
}

// MARK: - FormField

/// A reusable form field component with label, text field, and inline error display
private struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let error: String?
    let accessibilityHint: String
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            // Text field
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .focused($isFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(error != nil ? Color.red : Color.clear, lineWidth: 1)
                )
                .accessibilityLabel(label)
                .accessibilityHint(accessibilityHint)
                .accessibilityValue(text.isEmpty ? NSLocalizedString("Empty", comment: "Empty field") : text)
            
            // Inline error message
            if let errorMessage = error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: error)
    }
}

// MARK: - Preview

#if DEBUG
struct ConfigurationEditForm_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // New configuration
            ConfigurationEditForm()
                .previewDisplayName("New Configuration")
            
            // Edit existing configuration
            ConfigurationEditForm(
                configuration: MountConfiguration(
                    server: "192.168.1.100",
                    share: "Documents",
                    mountPoint: "/Volumes/Documents",
                    autoMount: true,
                    syncEnabled: false
                )
            )
            .previewDisplayName("Edit Configuration")
            
            // With validation errors (simulated by empty fields)
            ConfigurationEditForm(
                configuration: MountConfiguration(
                    server: "",
                    share: "",
                    mountPoint: "",
                    autoMount: false,
                    syncEnabled: false
                )
            )
            .previewDisplayName("With Validation Errors")
        }
    }
}
#endif
