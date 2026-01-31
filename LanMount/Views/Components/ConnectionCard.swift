//
//  ConnectionCard.swift
//  LanMount
//
//  Connection status card for displaying individual SMB connection information
//  Requirements: 4.2 - Display server name, share name, mount point, connection status, and latency
//  Requirements: 4.5 - Support tap to expand for detailed information
//

import SwiftUI

// MARK: - ConnectionCard

/// A card component that displays SMB connection status information
///
/// ConnectionCard shows essential information about a mounted or configured SMB volume,
/// including server details, connection status, and performance metrics.
///
/// Example usage:
/// ```swift
/// ConnectionCard(
///     configuration: mountConfig,
///     mountedVolume: mountedVolume,
///     statistics: connectionStats
/// )
/// ```
struct ConnectionCard: View {
    /// The mount configuration for this connection
    let configuration: MountConfiguration

    /// The mounted volume information (nil if not currently mounted)
    let mountedVolume: MountedVolume?

    /// Connection statistics including success rate and latency
    let statistics: ConnectionStatistics?

    /// Whether the card is expanded to show detailed information
    @State private var isExpanded = false

    /// Creates a new connection card
    ///
    /// - Parameters:
    ///   - configuration: The mount configuration
    ///   - mountedVolume: The current mounted volume info (optional)
    ///   - statistics: Connection statistics (optional)
    init(
        configuration: MountConfiguration,
        mountedVolume: MountedVolume? = nil,
        statistics: ConnectionStatistics? = nil
    ) {
        self.configuration = configuration
        self.mountedVolume = mountedVolume
        self.statistics = statistics
    }

    var body: some View {
        GlassCard(
            accessibility: .summary(
                label: accessibilityLabel,
                hint: NSLocalizedString("Double tap to toggle details", comment: "Connection card accessibility hint")
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header section with server and share info
                headerSection

                // Status section
                statusSection

                // Expanded details section
                if isExpanded {
                    Divider()
                    detailsSection
                }

                // Expand/collapse button
                Button(
                    action: { isExpanded.toggle() },
                    label: {
                        HStack {
                            Text(isExpanded ? NSLocalizedString("Show Less", comment: "Show less button") : NSLocalizedString("Show Details", comment: "Show details button"))
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                )
                .buttonStyle(.borderless)
                .accessibilityLabel(isExpanded ? NSLocalizedString("Hide details", comment: "Hide details accessibility label") : NSLocalizedString("Show details", comment: "Show details accessibility label"))
            }
            .padding()
        }
        .onTapGesture {
            isExpanded.toggle()
        }
    }

    // MARK: - Private Views

    /// Header section showing server and share information
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Server and share name
            Text("\(configuration.server)/\(configuration.share)")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            // Mount point
            Text(configuration.mountPoint)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    /// Status section showing connection status and basic metrics
    private var statusSection: some View {
        HStack {
            // Connection status indicator
            statusIndicator

            Spacer()

            // Latency information (if available)
            if let statistics = statistics, let latency = statistics.averageLatencyMs {
                Text(String(format: NSLocalizedString("%.0f ms", comment: "Latency in milliseconds"), latency))
                    .font(.caption)
                    .foregroundColor(latencyColor(for: latency))
            }
        }
    }

    /// Detailed information section (shown when expanded)
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Success rate
            if let successRate = statistics?.successRate {
                HStack {
                    Text(NSLocalizedString("Success Rate:", comment: "Success rate label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", successRate * 100))
                        .font(.caption)
                        .foregroundColor(successRate >= 0.9 ? .green : .yellow)
                }
            }

            // Last connection time
            if let lastConnected = mountedVolume?.mountedAt {
                HStack {
                    Text(NSLocalizedString("Last Connected:", comment: "Last connected label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastConnected, style: .relative)
                        .font(.caption)
                }
            }

            // Total connection attempts
            if let totalAttempts = statistics?.totalConnections {
                HStack {
                    Text(NSLocalizedString("Total Attempts:", comment: "Total attempts label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(totalAttempts)")
                        .font(.caption)
                }
            }

            // Failed attempts
            if let statistics = statistics {
                let failedAttempts = statistics.totalConnections - statistics.successfulConnections
                HStack {
                    Text(NSLocalizedString("Failed Attempts:", comment: "Failed attempts label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(failedAttempts)")
                        .font(.caption)
                        .foregroundColor(failedAttempts > 0 ? .red : .green)
                }
            }
        }
    }

    /// Connection status indicator with appropriate color and icon
    private var statusIndicator: some View {
        let status = mountedVolume?.status ?? .disconnected
        let statusColor = statusColor(for: status)
        let statusText = statusDescription(for: status)
        let statusIcon = statusSymbol(for: status)

        return HStack(spacing: 6) {
            Text(statusIcon)
                .foregroundColor(statusColor)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
    }

    // MARK: - Private Helpers

    /// Generates accessibility label for VoiceOver
    private var accessibilityLabel: String {
        let serverShare = "\(configuration.server)/\(configuration.share)"
        let mountPoint = configuration.mountPoint
        let status = mountedVolume?.status ?? .disconnected
        let statusText = statusDescription(for: status)

        var components = [serverShare, mountPoint, statusText]

        if let statistics = statistics, let latency = statistics.averageLatencyMs {
            components.append(String(format: NSLocalizedString("%.0f ms latency", comment: "Latency description for accessibility"), latency))
        }

        if let statistics = statistics {
            let successRate = statistics.successRate / 100 // Convert from percentage to decimal
            components.append(String(format: NSLocalizedString("%.1f%% success rate", comment: "Success rate description for accessibility"), successRate * 100))
        }

        return components.joined(separator: ", ")
    }

    /// Returns appropriate color for latency value
    private func latencyColor(for latency: Double) -> Color {
        if latency < 50 {
            return .green
        } else if latency < 200 {
            return .yellow
        } else {
            return .red
        }
    }
    /// Returns appropriate color for MountStatus
    private func statusColor(for status: MountStatus) -> Color {
        switch status {
        case .connected:
            return .green
        case .disconnected:
            return .secondary
        case .connecting:
            return .blue
        case .error:
            return .red
        }
    }

    /// Returns the status symbol for a mount status
    private func statusSymbol(for status: MountStatus) -> String {
        switch status {
        case .connected:
            return "●"  // Green dot
        case .disconnected:
            return "○"  // Empty circle
        case .connecting:
            return "◐"  // Half-filled circle (connecting animation)
        case .error:
            return "⚠"  // Warning symbol
        }
    }

    /// Returns a human-readable description for a mount status
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
}

// MARK: - Preview

#if DEBUG
struct ConnectionCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Disconnected card
                    ConnectionCard(
                        configuration: MountConfiguration(
                            id: UUID(),
                            server: "server.example.com",
                            share: "Documents",
                            mountPoint: "/Volumes/Documents",
                            autoMount: true
                        ),
                        mountedVolume: nil,
                        statistics: ConnectionStatistics(
                            configurationId: UUID(),
                            totalConnections: 10,
                            successfulConnections: 7,
                            averageLatencyMs: 150.0
                        )
                    )

                    // Connected card
                    ConnectionCard(
                        configuration: MountConfiguration(
                            id: UUID(),
                            server: "fileserver.local",
                            share: "Projects",
                            mountPoint: "/Volumes/Projects",
                            autoMount: true
                        ),
                        mountedVolume: MountedVolume(
                            id: UUID(),
                            server: "fileserver.local",
                            share: "Projects",
                            mountPoint: "/Volumes/Projects",
                            volumeName: "Projects",
                            status: .connected,
                            mountedAt: Date().addingTimeInterval(-3600)
                        ),
                        statistics: ConnectionStatistics(
                            configurationId: UUID(),
                            totalConnections: 25,
                            successfulConnections: 24,
                            averageLatencyMs: 35.0
                        )
                    )
                }
                .padding()
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

            // Dark mode preview
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ConnectionCard(
                        configuration: MountConfiguration(
                            id: UUID(),
                            server: "server.example.com",
                            share: "Documents",
                            mountPoint: "/Volumes/Documents",
                            autoMount: true
                        ),
                        mountedVolume: nil,
                        statistics: ConnectionStatistics(
                            configurationId: UUID(),
                            totalConnections: 10,
                            successfulConnections: 7,
                            averageLatencyMs: 150.0
                        )
                    )

                    ConnectionCard(
                        configuration: MountConfiguration(
                            id: UUID(),
                            server: "fileserver.local",
                            share: "Projects",
                            mountPoint: "/Volumes/Projects",
                            autoMount: true
                        ),
                        mountedVolume: MountedVolume(
                            id: UUID(),
                            server: "fileserver.local",
                            share: "Projects",
                            mountPoint: "/Volumes/Projects",
                            volumeName: "Projects",
                            status: .connected,
                            mountedAt: Date().addingTimeInterval(-3600)
                        ),
                        statistics: ConnectionStatistics(
                            configurationId: UUID(),
                            totalConnections: 25,
                            successfulConnections: 24,
                            averageLatencyMs: 35.0
                        )
                    )
                }
                .padding()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .frame(width: 400, height: 500)
    }
}
#endif