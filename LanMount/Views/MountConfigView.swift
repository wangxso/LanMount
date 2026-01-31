//
//  MountConfigView.swift
//  LanMount
//
//  SwiftUI view for configuring SMB mount settings
//  Requirements: 9.3 - Configuration dialog for adding new mounts
//

import SwiftUI

// MARK: - MountConfigView

/// A SwiftUI view for configuring SMB mount settings
/// Provides input fields for server, share, credentials, and mount options
/// Requirements: 9.3 - Display configuration dialog when user selects "Add New Mount"
struct MountConfigView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    /// Server address (hostname or IP)
    @State private var server: String = ""
    
    /// Share name on the server
    @State private var shareName: String = ""
    
    /// Username for authentication
    @State private var username: String = ""
    
    /// Password for authentication
    @State private var password: String = ""
    
    /// Whether to remember credentials in Keychain
    @State private var rememberCredentials: Bool = false
    
    /// Whether to auto-mount this share on login
    @State private var autoMount: Bool = false
    
    /// Whether to enable file synchronization
    @State private var enableSync: Bool = false
    
    /// Current validation errors
    @State private var validationErrors: [ValidationError] = []
    
    /// Whether a test connection is in progress
    @State private var isTestingConnection: Bool = false
    
    /// Result of the last connection test
    @State private var connectionTestResult: ConnectionTestResult?
    
    /// Whether the form is being saved
    @State private var isSaving: Bool = false
    
    // MARK: - Callbacks
    
    /// Called when the user saves the configuration
    var onSave: ((MountConfigData) -> Void)?
    
    /// Called when the user cancels
    var onCancel: (() -> Void)?
    
    /// Called when the user tests the connection
    var onTestConnection: ((MountConfigData) async -> ConnectionTestResult)?
    
    // MARK: - Initialization
    
    /// Creates a new MountConfigView
    /// - Parameters:
    ///   - existingConfig: Optional existing configuration to edit
    ///   - onSave: Callback when configuration is saved
    ///   - onCancel: Callback when configuration is cancelled
    ///   - onTestConnection: Callback to test the connection
    init(
        existingConfig: MountConfiguration? = nil,
        onSave: ((MountConfigData) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onTestConnection: ((MountConfigData) async -> ConnectionTestResult)? = nil
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        self.onTestConnection = onTestConnection
        
        // Pre-populate fields if editing existing configuration
        if let config = existingConfig {
            _server = State(initialValue: config.server)
            _shareName = State(initialValue: config.share)
            _rememberCredentials = State(initialValue: config.rememberCredentials)
            _autoMount = State(initialValue: config.autoMount)
            _enableSync = State(initialValue: config.syncEnabled)
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
                VStack(alignment: .leading, spacing: 20) {
                    // Server section
                    serverSection
                    
                    Divider()
                    
                    // Credentials section
                    credentialsSection
                    
                    Divider()
                    
                    // Options section
                    optionsSection
                    
                    // Validation errors
                    if !validationErrors.isEmpty {
                        validationErrorsView
                    }
                    
                    // Connection test result
                    if let result = connectionTestResult {
                        connectionTestResultView(result)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer with buttons
            footerView
        }
        .frame(width: 450, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.title2)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("Mount Configuration", comment: "Mount config window title"))
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("Mount Configuration", comment: "Accessibility: Mount config header"))
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Server Section
    
    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Server Information", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Server address field
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Server Address", comment: "Field label"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                TextField(
                    NSLocalizedString("e.g., 192.168.1.100 or server.local", comment: "Server placeholder"),
                    text: $server
                )
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .accessibilityLabel(NSLocalizedString("Server Address", comment: "Accessibility: Server address field"))
                .accessibilityHint(NSLocalizedString("Enter the server hostname or IP address", comment: "Accessibility: Server address hint"))
                .accessibilityValue(server.isEmpty ? NSLocalizedString("Empty", comment: "Accessibility: Empty field") : server)
                .onChange(of: server) { _ in
                    clearValidationError(for: .server)
                    connectionTestResult = nil
                }
                
                if hasValidationError(for: .server) {
                    errorLabel(for: .server)
                }
            }
            
            // Share name field
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Share Name", comment: "Field label"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                TextField(
                    NSLocalizedString("e.g., Documents or Public", comment: "Share placeholder"),
                    text: $shareName
                )
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .accessibilityLabel(NSLocalizedString("Share Name", comment: "Accessibility: Share name field"))
                .accessibilityHint(NSLocalizedString("Enter the name of the shared folder", comment: "Accessibility: Share name hint"))
                .accessibilityValue(shareName.isEmpty ? NSLocalizedString("Empty", comment: "Accessibility: Empty field") : shareName)
                .onChange(of: shareName) { _ in
                    clearValidationError(for: .shareName)
                    connectionTestResult = nil
                }
                
                if hasValidationError(for: .shareName) {
                    errorLabel(for: .shareName)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Credentials Section
    
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Authentication", comment: "Section header"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Username field
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Username", comment: "Field label"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                TextField(
                    NSLocalizedString("Leave empty for guest access", comment: "Username placeholder"),
                    text: $username
                )
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textContentType(.username)
                .accessibilityLabel(NSLocalizedString("Username", comment: "Accessibility: Username field"))
                .accessibilityHint(NSLocalizedString("Enter your username, or leave empty for guest access", comment: "Accessibility: Username hint"))
                .accessibilityValue(username.isEmpty ? NSLocalizedString("Empty, guest access", comment: "Accessibility: Empty username") : username)
                .onChange(of: username) { _ in
                    connectionTestResult = nil
                }
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Password", comment: "Field label"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                SecureField(
                    NSLocalizedString("Leave empty for guest access", comment: "Password placeholder"),
                    text: $password
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .accessibilityLabel(NSLocalizedString("Password", comment: "Accessibility: Password field"))
                .accessibilityHint(NSLocalizedString("Enter your password, or leave empty for guest access", comment: "Accessibility: Password hint"))
                .accessibilityValue(password.isEmpty ? NSLocalizedString("Empty", comment: "Accessibility: Empty password") : NSLocalizedString("Password entered", comment: "Accessibility: Password has value"))
                .onChange(of: password) { _ in
                    connectionTestResult = nil
                }
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
            .accessibilityLabel(NSLocalizedString("Remember Credentials", comment: "Accessibility: Remember credentials toggle"))
            .accessibilityHint(NSLocalizedString("When enabled, credentials will be stored securely in Keychain", comment: "Accessibility: Remember credentials hint"))
            .accessibilityValue(rememberCredentials ? NSLocalizedString("Enabled", comment: "Accessibility: Toggle on") : NSLocalizedString("Disabled", comment: "Accessibility: Toggle off"))
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            .accessibilityLabel(NSLocalizedString("Auto-Mount on Login", comment: "Accessibility: Auto-mount toggle"))
            .accessibilityHint(NSLocalizedString("When enabled, this share will be automatically mounted when you log in", comment: "Accessibility: Auto-mount hint"))
            .accessibilityValue(autoMount ? NSLocalizedString("Enabled", comment: "Accessibility: Toggle on") : NSLocalizedString("Disabled", comment: "Accessibility: Toggle off"))
            
            // Enable sync toggle
            Toggle(isOn: $enableSync) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Enable Synchronization", comment: "Toggle label"))
                    Text(NSLocalizedString("Keep local and remote files in sync", comment: "Toggle description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel(NSLocalizedString("Enable Synchronization", comment: "Accessibility: Sync toggle"))
            .accessibilityHint(NSLocalizedString("When enabled, local and remote files will be kept in sync", comment: "Accessibility: Sync hint"))
            .accessibilityValue(enableSync ? NSLocalizedString("Enabled", comment: "Accessibility: Toggle on") : NSLocalizedString("Disabled", comment: "Accessibility: Toggle off"))
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Validation Errors View
    
    private var validationErrorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(validationErrors, id: \.field) { error in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                        .accessibilityHidden(true)
                    
                    Text(error.message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(NSLocalizedString("Error", comment: "Accessibility: Error prefix") + ": " + error.message)
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("Validation Errors", comment: "Accessibility: Validation errors section"))
    }
    
    // MARK: - Connection Test Result View
    
    private func connectionTestResultView(_ result: ConnectionTestResult) -> some View {
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
            ? NSLocalizedString("Connection test successful", comment: "Accessibility: Test success") + ": " + result.message
            : NSLocalizedString("Connection test failed", comment: "Accessibility: Test failed") + ": " + result.message)
        .accessibilityAddTraits(.isStaticText)
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
            .accessibilityLabel(NSLocalizedString("Test Connection", comment: "Accessibility: Test connection button"))
            .accessibilityHint(NSLocalizedString("Tests the connection to the SMB server with current settings", comment: "Accessibility: Test connection hint"))
            .accessibilityValue(isTestingConnection ? NSLocalizedString("Testing in progress", comment: "Accessibility: Testing") : "")
            
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
            .disabled(isSaving || !canSave)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(NSLocalizedString("Save", comment: "Accessibility: Save button"))
            .accessibilityHint(NSLocalizedString("Saves the mount configuration", comment: "Accessibility: Save hint"))
            .accessibilityValue(isSaving ? NSLocalizedString("Saving in progress", comment: "Accessibility: Saving") : "")
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    private func errorLabel(for field: ValidationField) -> some View {
        if let error = validationErrors.first(where: { $0.field == field }) {
            return AnyView(
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.red)
            )
        }
        return AnyView(EmptyView())
    }
    
    // MARK: - Computed Properties
    
    /// Whether the form can be saved (basic validation)
    private var canSave: Bool {
        return !server.trimmingCharacters(in: .whitespaces).isEmpty &&
               !shareName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Whether a connection test can be performed
    private var canTestConnection: Bool {
        return canSave
    }
    
    // MARK: - Validation
    
    /// Validates the form and returns true if valid
    private func validateForm() -> Bool {
        validationErrors.removeAll()
        
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)
        let trimmedShare = shareName.trimmingCharacters(in: .whitespaces)
        
        // Validate server address
        if trimmedServer.isEmpty {
            validationErrors.append(ValidationError(
                field: .server,
                message: NSLocalizedString("Server address is required", comment: "Validation error")
            ))
        } else if !isValidServerAddress(trimmedServer) {
            validationErrors.append(ValidationError(
                field: .server,
                message: NSLocalizedString("Invalid server address format", comment: "Validation error")
            ))
        }
        
        // Validate share name
        if trimmedShare.isEmpty {
            validationErrors.append(ValidationError(
                field: .shareName,
                message: NSLocalizedString("Share name is required", comment: "Validation error")
            ))
        } else if !isValidShareName(trimmedShare) {
            validationErrors.append(ValidationError(
                field: .shareName,
                message: NSLocalizedString("Invalid share name format", comment: "Validation error")
            ))
        }
        
        return validationErrors.isEmpty
    }
    
    /// Checks if a server address is valid
    private func isValidServerAddress(_ address: String) -> Bool {
        // Allow hostnames, IP addresses, and .local addresses
        let hostnameRegex = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#
        let ipv4Regex = #"^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$"#
        
        let hostnamePredicate = NSPredicate(format: "SELF MATCHES %@", hostnameRegex)
        let ipv4Predicate = NSPredicate(format: "SELF MATCHES %@", ipv4Regex)
        
        return hostnamePredicate.evaluate(with: address) || ipv4Predicate.evaluate(with: address)
    }
    
    /// Checks if a share name is valid
    private func isValidShareName(_ name: String) -> Bool {
        // Share names should not contain certain special characters
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.rangeOfCharacter(from: invalidCharacters) == nil && !name.isEmpty
    }
    
    /// Checks if there's a validation error for a specific field
    private func hasValidationError(for field: ValidationField) -> Bool {
        return validationErrors.contains { $0.field == field }
    }
    
    /// Clears validation error for a specific field
    private func clearValidationError(for field: ValidationField) {
        validationErrors.removeAll { $0.field == field }
    }
    
    // MARK: - Actions
    
    /// Handles the save action
    private func handleSave() {
        guard validateForm() else { return }
        
        isSaving = true
        
        let configData = MountConfigData(
            server: server.trimmingCharacters(in: .whitespaces),
            shareName: shareName.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password,
            rememberCredentials: rememberCredentials,
            autoMount: autoMount,
            enableSync: enableSync
        )
        
        onSave?(configData)
        isSaving = false
        dismiss()
    }
    
    /// Handles the cancel action
    private func handleCancel() {
        onCancel?()
        dismiss()
    }
    
    /// Tests the connection with current settings
    private func testConnection() {
        guard validateForm() else { return }
        
        isTestingConnection = true
        connectionTestResult = nil
        
        let configData = MountConfigData(
            server: server.trimmingCharacters(in: .whitespaces),
            shareName: shareName.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password,
            rememberCredentials: rememberCredentials,
            autoMount: autoMount,
            enableSync: enableSync
        )
        
        Task {
            if let testHandler = onTestConnection {
                let result = await testHandler(configData)
                await MainActor.run {
                    connectionTestResult = result
                    isTestingConnection = false
                }
            } else {
                // Default test behavior - simulate a brief delay
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    connectionTestResult = ConnectionTestResult(
                        success: false,
                        message: NSLocalizedString("Connection test not available", comment: "Test result message")
                    )
                    isTestingConnection = false
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Validation field identifiers
enum ValidationField: String {
    case server
    case shareName
    case username
    case password
}

/// Validation error information
struct ValidationError: Identifiable {
    let id = UUID()
    let field: ValidationField
    let message: String
}

/// Data structure for mount configuration form data
struct MountConfigData {
    let server: String
    let shareName: String
    let username: String
    let password: String
    let rememberCredentials: Bool
    let autoMount: Bool
    let enableSync: Bool
    
    /// Creates a MountConfiguration from this data
    /// - Parameter mountPoint: Optional custom mount point (defaults to /Volumes/<shareName>)
    /// - Returns: A MountConfiguration instance
    func toMountConfiguration(mountPoint: String? = nil) -> MountConfiguration {
        return MountConfiguration(
            server: server,
            share: shareName,
            mountPoint: mountPoint ?? "/Volumes/\(shareName)",
            autoMount: autoMount,
            rememberCredentials: rememberCredentials,
            syncEnabled: enableSync
        )
    }
    
    /// Creates Credentials from this data if username is provided
    /// - Returns: Credentials instance, or nil if no username
    func toCredentials() -> Credentials? {
        guard !username.isEmpty else { return nil }
        return Credentials(username: username, password: password)
    }
}

/// Result of a connection test
struct ConnectionTestResult {
    let success: Bool
    let message: String
    
    /// Creates a successful connection test result
    static func success(message: String = NSLocalizedString("Connection successful", comment: "Test result")) -> ConnectionTestResult {
        return ConnectionTestResult(success: true, message: message)
    }
    
    /// Creates a failed connection test result
    static func failure(message: String) -> ConnectionTestResult {
        return ConnectionTestResult(success: false, message: message)
    }
}

// MARK: - Preview

#Preview("Empty Form") {
    MountConfigView()
}

#Preview("With Validation Errors") {
    MountConfigView()
}

#Preview("Pre-filled Form") {
    MountConfigView(
        existingConfig: MountConfiguration(
            server: "192.168.1.100",
            share: "Documents",
            mountPoint: "/Volumes/Documents",
            autoMount: true,
            rememberCredentials: true,
            syncEnabled: false
        )
    )
}
