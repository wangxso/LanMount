//
//  ConnectionManagerView.swift
//  LanMount
//
//  Connection manager view for managing SMB mount configurations
//  Requirements: 5.1 - Display all saved SMB disk source configurations as card list
//  Requirements: 5.2 - Support drag-and-drop reordering of configurations
//  Requirements: 5.4 - Support batch selection and batch deletion
//  Requirements: 5.5 - Support export and import configurations (JSON format)
//

import SwiftUI
import AppKit

// MARK: - ConnectionManagerView

/// Connection manager view for managing SMB mount configurations
///
/// This view displays all saved SMB disk source configurations as a card list,
/// supports drag-and-drop reordering, and provides batch selection and deletion.
///
/// Example usage:
/// ```swift
/// ConnectionManagerView(viewModel: connectionManagerViewModel)
/// ```
///
/// Requirements: 5.1 - Display all saved SMB disk source configurations as card list
/// Requirements: 5.2 - Support drag-and-drop reordering of configurations
/// Requirements: 5.4 - Support batch selection and batch deletion
/// Requirements: 5.5 - Support export and import configurations (JSON format)
struct ConnectionManagerView: View {
    
    // MARK: - Properties
    
    /// The view model managing configurations
    @ObservedObject var viewModel: ConnectionManagerViewModel
    
    /// Set of selected configuration IDs for batch operations
    @State private var selectedConfigs: Set<UUID> = []
    
    /// Whether the view is in editing/selection mode
    @State private var isEditing: Bool = false
    
    /// Whether to show the delete confirmation alert
    @State private var showDeleteConfirmation: Bool = false
    
    /// Error message to display
    @State private var errorMessage: String?
    
    /// Whether to show the error alert
    @State private var showError: Bool = false
    
    /// Success message to display
    @State private var successMessage: String?
    
    /// Whether to show the success alert
    @State private var showSuccess: Bool = false
    
    /// Whether an export/import operation is in progress
    @State private var isExportImportInProgress: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and action buttons
            headerView
            
            Divider()
                .padding(.horizontal)
            
            // Configuration list
            if viewModel.configurations.isEmpty {
                emptyStateView
            } else {
                configurationListView
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .alert(NSLocalizedString("Delete Configurations", comment: "Delete confirmation title"), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) { }
            Button(NSLocalizedString("Delete", comment: "Delete button"), role: .destructive) {
                deleteSelectedConfigurations()
            }
        } message: {
            Text(String(format: NSLocalizedString("Are you sure you want to delete %d configuration(s)? This action cannot be undone.", comment: "Delete confirmation message"), selectedConfigs.count))
        }
        .alert(NSLocalizedString("Error", comment: "Error title"), isPresented: $showError) {
            Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(errorMessage ?? NSLocalizedString("An unknown error occurred.", comment: "Unknown error"))
        }
        .alert(NSLocalizedString("Success", comment: "Success title"), isPresented: $showSuccess) {
            Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(successMessage ?? NSLocalizedString("Operation completed successfully.", comment: "Success message"))
        }
        .task {
            await viewModel.loadConfigurations()
        }
    }
    
    // MARK: - Header View
    
    /// Header view with title and action buttons
    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("Connection Manager", comment: "Connection manager title"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Export/Import buttons (always visible)
            HStack(spacing: 8) {
                // Import button
                Button(action: importConfigurations) {
                    Label(NSLocalizedString("Import", comment: "Import button"), systemImage: "square.and.arrow.down")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(isExportImportInProgress)
                .help(NSLocalizedString("Import configurations from a JSON file", comment: "Import help"))
                .accessibilityLabel(NSLocalizedString("Import configurations", comment: "Import accessibility"))
                .accessibilityHint(NSLocalizedString("Opens a file picker to select a JSON file containing configurations to import", comment: "Import hint"))
                
                // Export button
                Button(action: exportConfigurations) {
                    Label(NSLocalizedString("Export", comment: "Export button"), systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(viewModel.configurations.isEmpty ? .secondary : .accentColor)
                .disabled(viewModel.configurations.isEmpty || isExportImportInProgress)
                .help(exportButtonHelpText)
                .accessibilityLabel("Export configurations")
                .accessibilityHint(exportButtonAccessibilityHint)
                
                Divider()
                    .frame(height: 16)
            }
            
            // Batch action buttons (visible in editing mode)
            if isEditing {
                HStack(spacing: 12) {
                    // Select All / Deselect All button
                    Button(action: toggleSelectAll) {
                        Text(selectedConfigs.count == viewModel.configurations.count ? "Deselect All" : "Select All")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    
                    // Delete button (enabled when items are selected)
                    Button(action: { showDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedConfigs.isEmpty ? .secondary : .red)
                    .disabled(selectedConfigs.isEmpty)
                }
            }
            
            // Edit/Done button
            Button(action: toggleEditMode) {
                Text(isEditing ? "Done" : "Edit")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Connection Manager Header")
    }
    
    /// Help text for the export button
    private var exportButtonHelpText: String {
        if viewModel.configurations.isEmpty {
            return "No configurations to export"
        } else if isEditing && !selectedConfigs.isEmpty {
            return "Export \(selectedConfigs.count) selected configuration(s)"
        } else {
            return "Export all configurations to a JSON file"
        }
    }
    
    /// Accessibility hint for the export button
    private var exportButtonAccessibilityHint: String {
        if viewModel.configurations.isEmpty {
            return "Button is disabled because there are no configurations to export"
        } else if isEditing && !selectedConfigs.isEmpty {
            return "Opens a save dialog to export \(selectedConfigs.count) selected configuration(s) to a JSON file"
        } else {
            return "Opens a save dialog to export all \(viewModel.configurations.count) configuration(s) to a JSON file"
        }
    }
    
    // MARK: - Empty State View
    
    /// View displayed when there are no configurations
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("No Configurations", comment: "Empty state title"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(NSLocalizedString("Add SMB mount configurations to get started.", comment: "Empty state message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("No configurations. Add SMB mount configurations to get started.", comment: "Empty state accessibility"))
    }
    
    // MARK: - Configuration List View
    
    /// List view displaying all configurations
    private var configurationListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.configurations) { config in
                    ConfigurationCardView(
                        configuration: config,
                        statistics: viewModel.getConnectionStats(for: config.id),
                        isSelected: selectedConfigs.contains(config.id),
                        isEditing: isEditing,
                        onSelect: { toggleSelection(for: config.id) },
                        onTap: { handleConfigurationTap(config) }
                    )
                }
                .onMove(perform: moveConfigurations)
            }
            .padding()
        }
        .accessibilityLabel("Configuration list with \(viewModel.configurations.count) items")
    }
    
    // MARK: - Actions
    
    /// Toggles the editing mode
    private func toggleEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing.toggle()
            if !isEditing {
                // Clear selection when exiting edit mode
                selectedConfigs.removeAll()
            }
        }
    }
    
    /// Toggles selection for a specific configuration
    private func toggleSelection(for id: UUID) {
        if selectedConfigs.contains(id) {
            selectedConfigs.remove(id)
        } else {
            selectedConfigs.insert(id)
        }
    }
    
    /// Toggles select all / deselect all
    private func toggleSelectAll() {
        if selectedConfigs.count == viewModel.configurations.count {
            selectedConfigs.removeAll()
        } else {
            selectedConfigs = Set(viewModel.configurations.map { $0.id })
        }
    }
    
    /// Handles moving configurations for drag-and-drop reordering
    /// Requirements: 5.2 - Support drag-and-drop reordering
    private func moveConfigurations(from source: IndexSet, to destination: Int) {
        viewModel.reorderConfigurations(from: source, to: destination)
    }
    
    /// Deletes the selected configurations
    /// Requirements: 5.4 - Support batch deletion
    private func deleteSelectedConfigurations() {
        Task {
            do {
                try await viewModel.deleteConfigurations(selectedConfigs)
                selectedConfigs.removeAll()
                
                // Exit edit mode if no configurations remain
                if viewModel.configurations.isEmpty {
                    isEditing = false
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    /// Handles tapping on a configuration card
    private func handleConfigurationTap(_ config: MountConfiguration) {
        if isEditing {
            toggleSelection(for: config.id)
        } else {
            // In non-editing mode, could open detail view or perform other action
            // This can be extended in future tasks
        }
    }
    
    // MARK: - Export/Import Actions
    
    /// Exports configurations to a JSON file using NSSavePanel
    /// Requirements: 5.5 - Support export configurations (JSON format)
    private func exportConfigurations() {
        isExportImportInProgress = true
        
        // Determine which configurations to export
        let idsToExport: Set<UUID>
        if isEditing && !selectedConfigs.isEmpty {
            // Export only selected configurations
            idsToExport = selectedConfigs
        } else {
            // Export all configurations
            idsToExport = Set(viewModel.configurations.map { $0.id })
        }
        
        // Get the JSON data
        let jsonData = viewModel.exportConfigurations(idsToExport)
        
        guard !jsonData.isEmpty else {
            isExportImportInProgress = false
            errorMessage = "Failed to generate export data."
            showError = true
            return
        }
        
        // Create and configure the save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Configurations"
        savePanel.message = "Choose a location to save the configuration file"
        savePanel.nameFieldLabel = "File Name:"
        savePanel.nameFieldStringValue = "LanMount-Configurations.json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false
        
        // Show the save panel
        savePanel.begin { response in
            DispatchQueue.main.async {
                self.isExportImportInProgress = false
                
                if response == .OK, let url = savePanel.url {
                    do {
                        try jsonData.write(to: url)
                        self.successMessage = "Successfully exported \(idsToExport.count) configuration(s) to \(url.lastPathComponent)"
                        self.showSuccess = true
                    } catch {
                        self.errorMessage = "Failed to save file: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            }
        }
    }
    
    /// Imports configurations from a JSON file using NSOpenPanel
    /// Requirements: 5.5 - Support import configurations (JSON format)
    private func importConfigurations() {
        isExportImportInProgress = true
        
        // Create and configure the open panel
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Configurations"
        openPanel.message = "Select a JSON file containing LanMount configurations"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        // Show the open panel
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                Task { @MainActor in
                    do {
                        let data = try Data(contentsOf: url)
                        let importedConfigs = try await self.viewModel.importConfigurations(from: data)
                        
                        self.isExportImportInProgress = false
                        
                        if importedConfigs.isEmpty {
                            self.errorMessage = "No configurations were imported. The file may be empty or contain invalid data."
                            self.showError = true
                        } else {
                            self.successMessage = "Successfully imported \(importedConfigs.count) configuration(s) from \(url.lastPathComponent)"
                            self.showSuccess = true
                        }
                    } catch {
                        self.isExportImportInProgress = false
                        self.errorMessage = "Failed to import configurations: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isExportImportInProgress = false
                }
            }
        }
    }
}

// MARK: - ConfigurationCardView

/// A card view displaying a single configuration
///
/// Uses GlassCard for the glassmorphism design style.
/// Requirements: 5.1 - Display configurations as card list
private struct ConfigurationCardView: View {
    
    /// The configuration to display
    let configuration: MountConfiguration
    
    /// Connection statistics for this configuration
    let statistics: ConnectionStatistics?
    
    /// Whether this card is selected
    let isSelected: Bool
    
    /// Whether the parent view is in editing mode
    let isEditing: Bool
    
    /// Action to perform when selection checkbox is tapped
    let onSelect: () -> Void
    
    /// Action to perform when the card is tapped
    let onTap: () -> Void
    
    var body: some View {
        GlassCard(
            opacity: isSelected ? 0.5 : 0.3,
            cornerRadius: 12,
            isHoverable: !isEditing,
            accessibility: .button(
                label: accessibilityLabel,
                hint: isEditing ? "Double tap to toggle selection" : "Double tap to view details"
            )
        ) {
            HStack(spacing: 12) {
                // Selection checkbox (visible in editing mode)
                if isEditing {
                    selectionCheckbox
                }
                
                // Server icon
                serverIcon
                
                // Configuration details
                VStack(alignment: .leading, spacing: 4) {
                    // Server and share name
                    Text(configuration.smbURL)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Mount point
                    Text(configuration.mountPoint)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Statistics row
                    if let stats = statistics {
                        statisticsRow(stats)
                    }
                }
                
                Spacer()
                
                // Status indicators
                statusIndicators
                
                // Drag handle (visible in editing mode)
                if isEditing {
                    dragHandle
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .onTapGesture {
            onTap()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    // MARK: - Subviews
    
    /// Selection checkbox for batch operations
    private var selectionCheckbox: some View {
        Button(action: onSelect) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to toggle selection")
    }
    
    /// Server icon with status color
    private var serverIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 44, height: 44)
            
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.title3)
                .foregroundColor(.accentColor)
        }
    }
    
    /// Statistics row showing last connection and success rate
    private func statisticsRow(_ stats: ConnectionStatistics) -> some View {
        HStack(spacing: 8) {
            // Last connected time
            if let lastConnected = stats.lastConnectedAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(lastConnected, style: .relative)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Success rate
            if stats.totalConnections > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar")
                        .font(.caption2)
                    Text(String(format: "%.0f%%", stats.successRate))
                        .font(.caption)
                }
                .foregroundColor(successRateColor(stats.successRate))
            }
        }
    }
    
    /// Status indicators (auto-mount, sync)
    private var statusIndicators: some View {
        HStack(spacing: 8) {
            if configuration.autoMount {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help("Auto-mount enabled")
                    .accessibilityLabel("Auto-mount enabled")
            }
            
            if configuration.syncEnabled {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .help("Sync enabled")
                    .accessibilityLabel("Sync enabled")
            }
        }
    }
    
    /// Drag handle for reordering
    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.title3)
            .foregroundColor(.secondary)
            .accessibilityLabel("Drag to reorder")
    }
    
    // MARK: - Helpers
    
    /// Accessibility label for the card
    private var accessibilityLabel: String {
        var label = "Configuration for \(configuration.server), share \(configuration.share)"
        
        if configuration.autoMount {
            label += ", auto-mount enabled"
        }
        
        if configuration.syncEnabled {
            label += ", sync enabled"
        }
        
        if let stats = statistics, stats.totalConnections > 0 {
            label += ", success rate \(String(format: "%.0f", stats.successRate)) percent"
        }
        
        if isSelected {
            label += ", selected"
        }
        
        return label
    }
    
    /// Returns the color for the success rate based on the value
    private func successRateColor(_ rate: Double) -> Color {
        switch rate {
        case 80...:
            return .green
        case 50..<80:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ConnectionManagerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock view model for preview
        let viewModel = ConnectionManagerViewModel()
        
        Group {
            // Light mode
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ConnectionManagerView(viewModel: viewModel)
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
            
            // Dark mode
            ZStack {
                LinearGradient(
                    colors: [.indigo.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ConnectionManagerView(viewModel: viewModel)
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .frame(width: 500, height: 600)
    }
}
#endif
