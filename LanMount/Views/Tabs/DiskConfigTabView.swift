//
//  DiskConfigTabView.swift
//  LanMount
//
//  Disk configuration tab view for managing SMB mount configurations
//  Requirements: 3.1 - Display all saved SMB disk source configurations in list form
//  Requirements: 3.2 - Provide "Add new configuration" button that shows configuration form
//  Requirements: 3.3 - Support editing and deleting existing configurations
//  Requirements: 3.4 - Display server address, share name, mount status for each configuration
//  Requirements: 3.6 - Support discovering available SMB shares via network scan
//

import SwiftUI

// MARK: - DiskConfigTabView

/// 磁盘配置选项卡视图
/// Displays and manages SMB mount configurations with add, edit, delete, and network scan functionality
///
/// This view provides:
/// - Configuration list showing server, share name, and mount status
/// - Add new configuration button with form sheet
/// - Edit and delete existing configurations
/// - Network scanning to discover available SMB shares
///
/// Example usage:
/// ```swift
/// DiskConfigTabView(viewModel: connectionManagerViewModel)
/// ```
struct DiskConfigTabView: View {
    
    // MARK: - Properties
    
    /// The view model managing configurations
    @ObservedObject var viewModel: ConnectionManagerViewModel
    
    /// Whether to show the add configuration form
    /// Requirements: 3.2 - Provide "Add new configuration" button
    @State private var showAddForm = false
    
    /// The configuration currently being edited
    /// Requirements: 3.3 - Support editing existing configurations
    @State private var editingConfig: MountConfiguration?
    
    /// Whether to show the network scanner
    /// Requirements: 3.6 - Support network scan
    @State private var showNetworkScanner = false
    
    /// Whether to show delete confirmation alert
    @State private var showDeleteConfirmation = false
    
    /// The configuration to be deleted
    @State private var configToDelete: MountConfiguration?
    
    /// Error message to display
    @State private var errorMessage: String?
    
    /// Whether to show error alert
    @State private var showError = false
    
    /// Service discovered from network scan to auto-fill form
    @State private var discoveredService: DiscoveredService?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            // Requirements: 3.2, 3.6 - Add and scan buttons
            configToolbar
            
            Divider()
            
            // 配置列表
            // Requirements: 3.1 - Display all saved configurations in list form
            if viewModel.configurations.isEmpty {
                emptyStateView
            } else {
                configurationListView
            }
        }
        .sheet(isPresented: $showAddForm) {
            AddConfigurationSheet(
                viewModel: viewModel,
                discoveredService: discoveredService,
                onDismiss: {
                    discoveredService = nil
                }
            )
        }
        .sheet(item: $editingConfig) { config in
            EditConfigurationSheet(
                viewModel: viewModel,
                configuration: config
            )
        }
        .sheet(isPresented: $showNetworkScanner) {
            NetworkScannerView(
                onServiceSelected: { service in
                    discoveredService = service
                    showAddForm = true
                },
                onCancel: {
                    // Do nothing on cancel
                }
            )
        }
        .alert(
            NSLocalizedString("Delete Configuration", comment: "Delete confirmation title"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
                configToDelete = nil
            }
            Button(NSLocalizedString("Delete", comment: "Delete button"), role: .destructive) {
                if let config = configToDelete {
                    deleteConfiguration(config)
                }
            }
        } message: {
            if let config = configToDelete {
                Text(String(
                    format: NSLocalizedString(
                        "Are you sure you want to delete the configuration for %@/%@? This action cannot be undone.",
                        comment: "Delete confirmation message"
                    ),
                    config.server,
                    config.share
                ))
            }
        }
        .alert(
            NSLocalizedString("Error", comment: "Error alert title"),
            isPresented: $showError
        ) {
            Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? NSLocalizedString("An unknown error occurred.", comment: "Unknown error"))
        }
        .task {
            await viewModel.loadConfigurations()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("Disk Configuration Tab", comment: "Tab accessibility label"))
    }
    
    // MARK: - Config Toolbar
    
    /// Toolbar with add and scan buttons
    /// Requirements: 3.2 - Provide "Add new configuration" button
    /// Requirements: 3.6 - Support network scan
    private var configToolbar: some View {
        HStack(spacing: 16) {
            // Title
            Label {
                Text(NSLocalizedString("Disk Configurations", comment: "Section title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "externaldrive.badge.plus")
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            // Configuration count
            if !viewModel.configurations.isEmpty {
                Text(String(
                    format: NSLocalizedString("%d configurations", comment: "Configuration count"),
                    viewModel.configurations.count
                ))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            
            // Network scan button
            // Requirements: 3.6 - Support network scan
            Button {
                showNetworkScanner = true
            } label: {
                Label(
                    NSLocalizedString("Scan Network", comment: "Scan button"),
                    systemImage: "network"
                )
                .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .help(NSLocalizedString("Scan network for available SMB shares", comment: "Scan button help"))
            .accessibilityLabel(NSLocalizedString("Scan Network", comment: "Scan button accessibility"))
            .accessibilityHint(NSLocalizedString("Opens network scanner to discover SMB shares", comment: "Scan button hint"))
            
            // Add configuration button
            // Requirements: 3.2 - Provide "Add new configuration" button
            Button {
                discoveredService = nil
                showAddForm = true
            } label: {
                Label(
                    NSLocalizedString("Add", comment: "Add button"),
                    systemImage: "plus.circle.fill"
                )
                .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel(NSLocalizedString("Add Configuration", comment: "Add button accessibility"))
            .accessibilityHint(NSLocalizedString("Opens form to add a new SMB configuration", comment: "Add button hint"))
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Configuration List View
    
    /// List of all configurations
    /// Requirements: 3.1 - Display all saved configurations in list form
    /// Requirements: 3.4 - Display server address, share name, mount status
    private var configurationListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.configurations) { config in
                    ConfigurationCard(
                        configuration: config,
                        statistics: viewModel.getConnectionStats(for: config.id),
                        onEdit: {
                            editingConfig = config
                        },
                        onDelete: {
                            configToDelete = config
                            showDeleteConfirmation = true
                        },
                        onMount: {
                            Task {
                                await mountConfiguration(config)
                            }
                        },
                        onUnmount: {
                            Task {
                                await unmountConfiguration(config)
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "Configuration list with %d items",
                comment: "List accessibility"
            ),
            viewModel.configurations.count
        ))
    }
    
    // MARK: - Empty State View
    
    /// View displayed when there are no configurations
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("No Configurations", comment: "Empty state title"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(NSLocalizedString(
                "Add SMB mount configurations to connect to network drives.",
                comment: "Empty state message"
            ))
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            
            HStack(spacing: 16) {
                // Scan network button
                Button {
                    showNetworkScanner = true
                } label: {
                    Label(
                        NSLocalizedString("Scan Network", comment: "Scan button"),
                        systemImage: "network"
                    )
                }
                .buttonStyle(.bordered)
                
                // Add manually button
                Button {
                    discoveredService = nil
                    showAddForm = true
                } label: {
                    Label(
                        NSLocalizedString("Add Manually", comment: "Add manually button"),
                        systemImage: "plus.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString(
            "No configurations. Add SMB mount configurations to connect to network drives.",
            comment: "Empty state accessibility"
        ))
    }
    
    // MARK: - Actions
    
    /// Deletes a configuration
    /// Requirements: 3.3 - Support deleting existing configurations
    private func deleteConfiguration(_ config: MountConfiguration) {
        Task {
            do {
                try await viewModel.deleteConfigurations(Set([config.id]))
                configToDelete = nil
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    /// Mounts a configuration
    private func mountConfiguration(_ config: MountConfiguration) async {
        // Get credentials from Keychain if rememberCredentials is enabled
        var credentials: Credentials? = nil
        if config.rememberCredentials {
            let credentialManager = CredentialManager()
            credentials = try? credentialManager.getCredentials(server: config.server, share: config.share)
        }
        
        // Use the mount manager from the view model
        let mountManager = MountManager()
        do {
            let result = try await mountManager.mount(
                server: config.server,
                share: config.share,
                mountPoint: config.mountPoint,
                credentials: credentials
            )
            
            if !result.success {
                errorMessage = result.error?.localizedDescription ?? NSLocalizedString("Mount failed", comment: "Mount error")
                showError = true
            } else {
                // Reload configurations to refresh UI
                await viewModel.loadConfigurations()
                
                // Post notification to refresh dashboard
                NotificationCenter.default.post(name: .mountStatusDidChange, object: nil)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    /// Unmounts a configuration
    private func unmountConfiguration(_ config: MountConfiguration) async {
        let mountManager = MountManager()
        do {
            try await mountManager.unmount(mountPoint: config.mountPoint)
            // Reload configurations to refresh UI
            await viewModel.loadConfigurations()
            
            // Post notification to refresh dashboard
            NotificationCenter.default.post(name: .mountStatusDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - ConfigurationCard

/// A card view displaying a single configuration with actions
/// Requirements: 3.4 - Display server address, share name, mount status
private struct ConfigurationCard: View {
    
    /// The configuration to display
    let configuration: MountConfiguration
    
    /// Connection statistics for this configuration
    let statistics: ConnectionStatistics?
    
    /// Action to edit the configuration
    /// Requirements: 3.3 - Support editing
    let onEdit: () -> Void
    
    /// Action to delete the configuration
    /// Requirements: 3.3 - Support deleting
    let onDelete: () -> Void
    
    /// Action to mount the configuration
    let onMount: () -> Void
    
    /// Action to unmount the configuration
    let onUnmount: () -> Void
    
    /// Whether the card is hovered
    @State private var isHovered = false
    
    /// Whether actions menu is shown
    @State private var showActionsMenu = false
    
    var body: some View {
        GlassCard(
            accessibility: .button(
                label: cardAccessibilityLabel,
                hint: NSLocalizedString("Double tap for options", comment: "Card hint")
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with server info and status
                headerSection
                
                Divider()
                
                // Details section
                detailsSection
                
                // Statistics section
                if let stats = statistics, stats.totalConnections > 0 {
                    statisticsSection(stats)
                }
                
                // Action buttons
                actionButtonsSection
            }
            .padding()
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // MARK: - Header Section
    
    /// Header with server/share and mount status
    /// Requirements: 3.4 - Display server address, share name, mount status
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // Server icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            .accessibilityHidden(true)
            
            // Server and share info
            VStack(alignment: .leading, spacing: 4) {
                // Server address
                // Requirements: 3.4 - Display server address
                Text(configuration.server)
                    .font(.headline)
                    .lineLimit(1)
                
                // Share name
                // Requirements: 3.4 - Display share name
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(configuration.share)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Mount status indicator
            // Requirements: 3.4 - Display mount status
            mountStatusBadge
        }
    }
    
    /// Mount status badge
    /// Requirements: 3.4 - Display mount status
    private var mountStatusBadge: some View {
        let mountManager = MountManager()
        let isMounted = mountManager.isMounted(mountPoint: configuration.mountPoint)
        let isAutoMount = configuration.autoMount
        
        if isMounted {
            return AnyView(
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("Mounted", comment: "Mounted status"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
            )
        } else if isAutoMount {
            return AnyView(
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("Auto", comment: "Auto-mount status"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                )
            )
        } else {
            return AnyView(
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("Not Mounted", comment: "Not mounted status"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            )
        }
    }
    
    // MARK: - Details Section
    
    /// Details section with mount point and options
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mount point
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(configuration.mountPoint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            // Options indicators
            HStack(spacing: 12) {
                if configuration.autoMount {
                    optionBadge(
                        icon: "bolt.fill",
                        text: NSLocalizedString("Auto-mount", comment: "Auto-mount option"),
                        color: .orange
                    )
                }
                
                if configuration.syncEnabled {
                    optionBadge(
                        icon: "arrow.triangle.2.circlepath",
                        text: NSLocalizedString("Sync", comment: "Sync option"),
                        color: .blue
                    )
                }
                
                if configuration.rememberCredentials {
                    optionBadge(
                        icon: "key.fill",
                        text: NSLocalizedString("Saved", comment: "Credentials saved"),
                        color: .purple
                    )
                }
            }
        }
    }
    
    /// Option badge helper
    private func optionBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .foregroundColor(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
    
    // MARK: - Statistics Section
    
    /// Statistics section showing connection history
    private func statisticsSection(_ stats: ConnectionStatistics) -> some View {
        HStack(spacing: 16) {
            // Last connected
            if let lastConnected = stats.lastConnectedAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(lastConnected, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Success rate
            HStack(spacing: 4) {
                Image(systemName: "chart.bar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f%%", stats.successRate))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(successRateColor(stats.successRate))
            }
            
            // Average latency
            if let latency = stats.averageLatencyMs {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0fms", latency))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "Success rate %.0f percent",
                comment: "Stats accessibility"
            ),
            stats.successRate
        ))
    }
    
    /// Returns color based on success rate
    private func successRateColor(_ rate: Double) -> Color {
        switch rate {
        case 80...: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
    
    // MARK: - Action Buttons Section
    
    /// Action buttons for edit, delete, mount/unmount
    /// Requirements: 3.3 - Support editing and deleting
    private var actionButtonsSection: some View {
        let mountManager = MountManager()
        let isMounted = mountManager.isMounted(mountPoint: configuration.mountPoint)
        
        return HStack(spacing: 12) {
            // Edit button
            Button {
                onEdit()
            } label: {
                Label(
                    NSLocalizedString("Edit", comment: "Edit button"),
                    systemImage: "pencil"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(NSLocalizedString("Edit Configuration", comment: "Edit accessibility"))
            .accessibilityHint(NSLocalizedString("Opens form to edit this configuration", comment: "Edit hint"))
            
            // Delete button
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(
                    NSLocalizedString("Delete", comment: "Delete button"),
                    systemImage: "trash"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(NSLocalizedString("Delete Configuration", comment: "Delete accessibility"))
            .accessibilityHint(NSLocalizedString("Deletes this configuration", comment: "Delete hint"))
            
            Spacer()
            
            // Mount/Unmount button - changes based on mount status
            if isMounted {
                Button {
                    onUnmount()
                } label: {
                    Label(
                        NSLocalizedString("Unmount", comment: "Unmount button"),
                        systemImage: "externaldrive.badge.xmark"
                    )
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
                .accessibilityLabel(NSLocalizedString("Unmount Drive", comment: "Unmount accessibility"))
                .accessibilityHint(NSLocalizedString("Unmounts this network drive", comment: "Unmount hint"))
            } else {
                Button {
                    onMount()
                } label: {
                    Label(
                        NSLocalizedString("Mount", comment: "Mount button"),
                        systemImage: "externaldrive.badge.checkmark"
                    )
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel(NSLocalizedString("Mount Drive", comment: "Mount accessibility"))
                .accessibilityHint(NSLocalizedString("Mounts this network drive", comment: "Mount hint"))
            }
        }
    }
    
    // MARK: - Accessibility
    
    /// Accessibility label for the card
    private var cardAccessibilityLabel: String {
        var label = String(
            format: NSLocalizedString(
                "Configuration for server %@, share %@",
                comment: "Card accessibility label"
            ),
            configuration.server,
            configuration.share
        )
        
        if configuration.autoMount {
            label += ", " + NSLocalizedString("auto-mount enabled", comment: "Auto-mount accessibility")
        }
        
        if configuration.syncEnabled {
            label += ", " + NSLocalizedString("sync enabled", comment: "Sync accessibility")
        }
        
        return label
    }
}

// MARK: - AddConfigurationSheet

/// Sheet for adding a new configuration
/// Requirements: 3.2 - Provide "Add new configuration" button that shows configuration form
private struct AddConfigurationSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    
    /// The view model for saving configurations
    @ObservedObject var viewModel: ConnectionManagerViewModel
    
    /// Optional discovered service to pre-fill form
    let discoveredService: DiscoveredService?
    
    /// Callback when sheet is dismissed
    let onDismiss: () -> Void
    
    /// Selected share from discovered service
    @State private var selectedShare: String = ""
    
    /// Whether to show share picker
    @State private var showSharePicker: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // If discovered service has multiple shares, show picker first
            if let service = discoveredService, service.shares.count > 1, showSharePicker {
                sharePickerView(service: service)
            } else {
                ConfigurationEditForm(
                    configuration: createInitialConfiguration(),
                    onSave: { config in
                        Task {
                            do {
                                try await viewModel.addConfiguration(config)
                                onDismiss()
                                dismiss()
                            } catch {
                                // Error handling is done in the form
                            }
                        }
                    },
                    onCancel: {
                        onDismiss()
                        dismiss()
                    },
                    onTestConnection: { config in
                        let result = await viewModel.testConnection(config)
                        if result.success {
                            return .success(message: String(
                                format: NSLocalizedString(
                                    "Connected successfully (%.0fms)",
                                    comment: "Connection success"
                                ),
                                result.latencyMs ?? 0
                            ))
                        } else {
                            return .failure(message: result.errorMessage ?? NSLocalizedString(
                                "Connection failed",
                                comment: "Connection failure"
                            ))
                        }
                    }
                )
            }
        }
        .onAppear {
            // If service has multiple shares, show picker
            if let service = discoveredService, service.shares.count > 1 {
                showSharePicker = true
            } else if let service = discoveredService, let firstShare = service.shares.first {
                selectedShare = firstShare
            }
        }
    }
    
    /// Share picker view for services with multiple shares
    private func sharePickerView(service: DiscoveredService) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder.badge.questionmark")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(NSLocalizedString("Select Share", comment: "Share picker title"))
                    .font(.headline)
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Share list
            VStack(alignment: .leading, spacing: 8) {
                Text(String(
                    format: NSLocalizedString(
                        "Server %@ has multiple shares. Select one to configure:",
                        comment: "Share picker message"
                    ),
                    service.name
                ))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(service.shares, id: \.self) { share in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.accentColor)
                                Text(share)
                                    .font(.body)
                                Spacer()
                                if selectedShare == share {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedShare == share ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedShare = share
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                    onDismiss()
                    dismiss()
                }
                
                Spacer()
                
                Button(NSLocalizedString("Continue", comment: "Continue button")) {
                    showSharePicker = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedShare.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
    
    /// Creates initial configuration from discovered service or empty
    private func createInitialConfiguration() -> MountConfiguration? {
        guard let service = discoveredService else { return nil }
        
        // Use selected share or first share if available
        let share = selectedShare.isEmpty ? (service.shares.first ?? "") : selectedShare
        
        // Only create config if we have a share
        guard !share.isEmpty else {
            // Return config with just server filled in
            return MountConfiguration(
                server: service.ipAddress,
                share: "",
                mountPoint: "",
                autoMount: false,
                rememberCredentials: false,
                syncEnabled: false
            )
        }
        
        return MountConfiguration(
            server: service.ipAddress,
            share: share,
            mountPoint: "/Volumes/\(share)",
            autoMount: false,
            rememberCredentials: false,
            syncEnabled: false
        )
    }
}

// MARK: - EditConfigurationSheet

/// Sheet for editing an existing configuration
/// Requirements: 3.3 - Support editing existing configurations
private struct EditConfigurationSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    
    /// The view model for updating configurations
    @ObservedObject var viewModel: ConnectionManagerViewModel
    
    /// The configuration to edit
    let configuration: MountConfiguration
    
    var body: some View {
        ConfigurationEditForm(
            configuration: configuration,
            onSave: { config in
                Task {
                    do {
                        try await viewModel.updateConfiguration(config)
                        dismiss()
                    } catch {
                        // Error handling is done in the form
                    }
                }
            },
            onCancel: {
                dismiss()
            },
            onTestConnection: { config in
                let result = await viewModel.testConnection(config)
                if result.success {
                    return .success(message: String(
                        format: NSLocalizedString(
                            "Connected successfully (%.0fms)",
                            comment: "Connection success"
                        ),
                        result.latencyMs ?? 0
                    ))
                } else {
                    return .failure(message: result.errorMessage ?? NSLocalizedString(
                        "Connection failed",
                        comment: "Connection failure"
                    ))
                }
            }
        )
    }
}

// MARK: - Preview

#if DEBUG
struct DiskConfigTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode with configurations
            DiskConfigTabView(viewModel: ConnectionManagerViewModel())
                .frame(width: 800, height: 600)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            // Dark mode
            DiskConfigTabView(viewModel: ConnectionManagerViewModel())
                .frame(width: 800, height: 600)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
