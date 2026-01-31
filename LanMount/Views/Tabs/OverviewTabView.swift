//
//  OverviewTabView.swift
//  LanMount
//
//  Overview tab view displaying connection status, quick actions, and summaries
//  Requirements: 2.1 - Display status card grid for all configured SMB connections
//  Requirements: 2.2 - Include quick actions panel (mount all, unmount all, refresh status)
//  Requirements: 2.3 - Display storage usage summary chart (ring or bar chart)
//  Requirements: 2.4 - Display IO activity real-time summary (current read/write speed)
//  Requirements: 2.6 - Support clicking connection card to navigate to disk info tab
//

import SwiftUI

// MARK: - OverviewTabView

/// 概览选项卡视图
/// Displays an overview of all SMB connections with quick actions and summaries
///
/// This view provides:
/// - Quick actions panel for batch operations (mount all, unmount all, refresh)
/// - Connection status card grid showing all configured SMB connections
/// - Storage usage summary showing total used/available space
/// - IO activity summary showing current read/write speeds
/// - Navigation to disk info tab when clicking on a connection card
///
/// Example usage:
/// ```swift
/// OverviewTabView(viewModel: dashboardViewModel)
///
/// // With tab navigation callback
/// OverviewTabView(viewModel: dashboardViewModel) { tab in
///     navigationController.switchTo(tab)
/// }
/// ```
struct OverviewTabView: View {
    
    // MARK: - Properties
    
    /// The view model providing dashboard data and operations
    @ObservedObject var viewModel: DashboardViewModel
    
    /// Callback for navigating to another tab
    /// Requirements: 2.6 - Support clicking connection card to navigate to disk info tab
    var onNavigateToTab: ((AppTab) -> Void)?
    
    // MARK: - Private State
    
    /// Currently hovered configuration ID for hover effects
    @State private var hoveredConfigId: UUID? = nil
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 快速操作面板
                // Requirements: 2.2 - Include quick actions panel
                QuickActionsPanel(viewModel: viewModel)
                
                // 连接状态网格
                // Requirements: 2.1 - Display status card grid for all configured SMB connections
                if !viewModel.configurations.isEmpty {
                    connectionStatusSection
                }
                
                // 存储和 IO 摘要
                // Requirements: 2.3, 2.4 - Display storage and IO summaries
                if viewModel.hasMountedVolumes {
                    summarySection
                }
                
                // 空状态
                if viewModel.configurations.isEmpty {
                    emptyStateView
                }
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("Overview Tab", comment: "Overview tab accessibility label"))
    }
    
    // MARK: - Connection Status Section
    
    /// Section header and grid for connection status cards
    /// Requirements: 2.1 - Display status card grid for all configured SMB connections
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Label {
                    Text(NSLocalizedString("Connections", comment: "Connections section title"))
                        .font(.headline)
                } icon: {
                    Image(systemName: "network")
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                // Connection count badge
                Text(String(format: NSLocalizedString("%d configured", comment: "Configuration count"), viewModel.configurations.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            
            // Connection status grid
            connectionStatusGrid
        }
    }
    
    /// Grid of connection status cards
    /// Requirements: 2.1, 2.6 - Display status cards with navigation support
    private var connectionStatusGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(viewModel.configurations) { config in
                connectionCard(for: config)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "Connection status grid with %d connections",
                comment: "Connection grid accessibility"
            ),
            viewModel.configurations.count
        ))
    }
    
    /// Creates a connection card for a configuration
    /// Requirements: 2.6 - Support clicking connection card to navigate to disk info tab
    private func connectionCard(for config: MountConfiguration) -> some View {
        let mountedVolume = viewModel.mountedVolumes.first { 
            $0.server == config.server && $0.share == config.share 
        }
        let isConnected = mountedVolume?.status == .connected
        
        return GlassCard(
            accessibility: .button(
                label: connectionCardAccessibilityLabel(for: config, isConnected: isConnected),
                hint: NSLocalizedString("Double tap to view disk details", comment: "Connection card hint")
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with server/share and status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(config.server)")
                            .font(.headline)
                            .lineLimit(1)
                        Text("/\(config.share)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    statusIndicator(isConnected: isConnected, status: mountedVolume?.status)
                }
                
                Divider()
                
                // Mount point
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(config.mountPoint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                // Storage info if mounted
                if let volume = mountedVolume, volume.bytesTotal > 0 {
                    storageProgressBar(for: volume)
                }
                
                // Auto-mount indicator
                if config.autoMount {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                        Text(NSLocalizedString("Auto-mount enabled", comment: "Auto-mount indicator"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .scaleEffect(hoveredConfigId == config.id ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: hoveredConfigId)
        .onHover { isHovered in
            hoveredConfigId = isHovered ? config.id : nil
        }
        .onTapGesture {
            // Navigate to disk info tab when card is tapped
            // Requirements: 2.6 - Support clicking connection card to navigate to disk info tab
            onNavigateToTab?(.diskInfo)
        }
    }
    
    /// Status indicator view
    private func statusIndicator(isConnected: Bool, status: MountStatus?) -> some View {
        let displayStatus = status ?? .disconnected
        let statusText: String
        let statusColor: Color
        let statusIcon: String
        
        switch displayStatus {
        case .connected:
            statusText = NSLocalizedString("Connected", comment: "Connected status")
            statusColor = .green
            statusIcon = "checkmark.circle.fill"
        case .connecting:
            statusText = NSLocalizedString("Connecting", comment: "Connecting status")
            statusColor = .yellow
            statusIcon = "arrow.triangle.2.circlepath"
        case .disconnected:
            statusText = NSLocalizedString("Disconnected", comment: "Disconnected status")
            statusColor = .secondary
            statusIcon = "circle"
        case .error(let message):
            statusText = NSLocalizedString("Error", comment: "Error status")
            statusColor = .red
            statusIcon = "exclamationmark.circle.fill"
            _ = message // Suppress unused warning
        }
        
        return HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.caption)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
    }
    
    /// Storage progress bar for mounted volumes
    private func storageProgressBar(for volume: MountedVolume) -> some View {
        let usagePercentage = volume.usagePercentage ?? 0
        let usageColor: Color = usagePercentage > 95 ? .red : (usagePercentage > 80 ? .orange : .green)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(NSLocalizedString("Storage", comment: "Storage label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f%%", usagePercentage))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(usageColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(usageColor)
                        .frame(width: geometry.size.width * CGFloat(usagePercentage / 100))
                }
            }
            .frame(height: 4)
            
            HStack {
                Text(formatBytes(volume.bytesUsed))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatBytes(volume.bytesTotal))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "Storage: %.1f percent used, %@ of %@",
                comment: "Storage accessibility"
            ),
            usagePercentage,
            formatBytes(volume.bytesUsed),
            formatBytes(volume.bytesTotal)
        ))
    }
    
    // MARK: - Summary Section
    
    /// Storage and IO summary section
    /// Requirements: 2.3, 2.4 - Display storage and IO summaries
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Label {
                    Text(NSLocalizedString("Summary", comment: "Summary section title"))
                        .font(.headline)
                } icon: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            
            // Summary cards
            HStack(alignment: .top, spacing: 16) {
                storageSummaryCard
                    .frame(maxWidth: .infinity)
                ioSummaryCard
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    /// Storage usage summary card
    /// Requirements: 2.3 - Display storage usage summary chart
    private var storageSummaryCard: some View {
        let totalStorage = viewModel.storageViewModel.totalStorage
        
        return GlassCard(
            accessibility: .summary(
                label: String(
                    format: NSLocalizedString(
                        "Storage summary: %@ used of %@, %.1f percent",
                        comment: "Storage summary accessibility"
                    ),
                    totalStorage.formattedTotalUsed,
                    totalStorage.formattedTotalCapacity,
                    totalStorage.overallUsagePercentage
                )
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(.blue)
                    Text(NSLocalizedString("Storage", comment: "Storage card title"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                // Ring chart representation
                HStack(spacing: 16) {
                    // Simple ring chart
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: CGFloat(totalStorage.overallUsagePercentage / 100))
                            .stroke(
                                totalStorage.overallUsageLevel.color,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f%%", totalStorage.overallUsagePercentage))
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(NSLocalizedString("Used", comment: "Used label"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 80, height: 80)
                    
                    // Details
                    VStack(alignment: .leading, spacing: 8) {
                        storageDetailRow(
                            label: NSLocalizedString("Used", comment: "Used storage"),
                            value: totalStorage.formattedTotalUsed,
                            color: totalStorage.overallUsageLevel.color
                        )
                        storageDetailRow(
                            label: NSLocalizedString("Available", comment: "Available storage"),
                            value: totalStorage.formattedTotalAvailable,
                            color: .secondary
                        )
                        storageDetailRow(
                            label: NSLocalizedString("Total", comment: "Total storage"),
                            value: totalStorage.formattedTotalCapacity,
                            color: .primary
                        )
                    }
                }
                
                // Volume count
                Text(String(
                    format: NSLocalizedString("%d volumes", comment: "Volume count"),
                    totalStorage.volumeCount
                ))
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Storage detail row helper
    private func storageDetailRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
    
    /// IO activity summary card
    /// Requirements: 2.4 - Display IO activity real-time summary
    private var ioSummaryCard: some View {
        let currentStats = viewModel.ioMonitorViewModel.currentStats
        
        // Calculate total read/write speeds across all volumes
        let totalReadSpeed = currentStats.reduce(Int64(0)) { $0 + $1.readBytesPerSecond }
        let totalWriteSpeed = currentStats.reduce(Int64(0)) { $0 + $1.writeBytesPerSecond }
        
        return GlassCard(
            accessibility: .summary(
                label: String(
                    format: NSLocalizedString(
                        "IO activity: Read %@, Write %@",
                        comment: "IO summary accessibility"
                    ),
                    formatSpeed(totalReadSpeed),
                    formatSpeed(totalWriteSpeed)
                )
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("IO Activity", comment: "IO card title"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    
                    // Monitoring status indicator
                    if viewModel.ioMonitorViewModel.isMonitoring {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(NSLocalizedString("Live", comment: "Live monitoring indicator"))
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Read/Write speeds
                HStack(spacing: 20) {
                    // Read speed
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(NSLocalizedString("Read", comment: "Read label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(formatSpeed(totalReadSpeed))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(totalReadSpeed > 0 ? .blue : .secondary)
                    }
                    
                    Spacer()
                    
                    // Write speed
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("Write", comment: "Write label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        Text(formatSpeed(totalWriteSpeed))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(totalWriteSpeed > 0 ? .orange : .secondary)
                    }
                }
                
                // Active volumes count
                let activeVolumes = currentStats.filter { $0.readBytesPerSecond > 0 || $0.writeBytesPerSecond > 0 }.count
                if activeVolumes > 0 {
                    Text(String(
                        format: NSLocalizedString("%d active volumes", comment: "Active volume count"),
                        activeVolumes
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    Text(NSLocalizedString("No active IO", comment: "No IO activity"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Empty State View
    
    /// Empty state view when no configurations exist
    private var emptyStateView: some View {
        GlassCard(
            accessibility: .summary(
                label: NSLocalizedString(
                    "No SMB connections configured. Add a connection to get started.",
                    comment: "Empty state accessibility"
                )
            )
        ) {
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text(NSLocalizedString("No Connections", comment: "Empty state title"))
                    .font(.headline)
                
                Text(NSLocalizedString(
                    "Add an SMB connection to start mounting network drives.",
                    comment: "Empty state message"
                ))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
                Button {
                    onNavigateToTab?(.diskConfig)
                } label: {
                    Label(
                        NSLocalizedString("Add Connection", comment: "Add connection button"),
                        systemImage: "plus.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Formats bytes to human-readable string
    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "--" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    /// Formats speed (bytes per second) to human-readable string
    private func formatSpeed(_ bytesPerSecond: Int64) -> String {
        guard bytesPerSecond >= 0 else { return "--" }
        return ByteCountFormatter.string(fromByteCount: bytesPerSecond, countStyle: .file) + "/s"
    }
    
    /// Creates accessibility label for connection card
    private func connectionCardAccessibilityLabel(for config: MountConfiguration, isConnected: Bool) -> String {
        let status = isConnected 
            ? NSLocalizedString("connected", comment: "Connected status for accessibility")
            : NSLocalizedString("disconnected", comment: "Disconnected status for accessibility")
        
        return String(
            format: NSLocalizedString(
                "%@ share %@ on server %@, %@",
                comment: "Connection card accessibility label"
            ),
            config.share,
            config.mountPoint,
            config.server,
            status
        )
    }
}

// MARK: - Preview

#if DEBUG
struct OverviewTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            OverviewTabView(viewModel: DashboardViewModel())
                .frame(width: 800, height: 600)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            // Dark mode preview
            OverviewTabView(viewModel: DashboardViewModel())
                .frame(width: 800, height: 600)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
