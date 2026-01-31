//
//  QuickActionsPanel.swift
//  LanMount
//
//  Quick actions panel for batch operations on the dashboard
//  Requirements: 6.1 - Provide "Mount All" button to mount all configured disk sources with one click
//  Requirements: 6.2 - Provide "Unmount All" button to unmount all mounted disks with one click
//  Requirements: 6.3 - Provide "Refresh Status" button to manually refresh all connection status information
//  Requirements: 6.4 - Display progress indicator during batch operations
//

import SwiftUI

// MARK: - QuickActionsPanel

/// A panel containing quick action buttons for batch operations
///
/// QuickActionsPanel provides a convenient interface for performing
/// common batch operations like mounting all drives, unmounting all drives,
/// and refreshing connection status.
///
/// Example usage:
/// ```swift
/// @StateObject private var dashboardViewModel = DashboardViewModel()
///
/// QuickActionsPanel(viewModel: dashboardViewModel)
/// ```
struct QuickActionsPanel: View {
    /// The view model that provides data and handles operations
    @ObservedObject var viewModel: DashboardViewModel

    /// Creates a new quick actions panel
    ///
    /// - Parameter viewModel: The dashboard view model to use for operations
    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack {
                Label {
                    Text(NSLocalizedString("Quick Actions", comment: "Quick actions panel title"))
                        .font(.headline)
                } icon: {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            // Action buttons
            HStack(spacing: 12) {
                // Mount All button
                Button(
                    action: performMountAll,
                    label: {
                        Label(
                            NSLocalizedString("Mount All", comment: "Mount all button title"),
                            systemImage: "arrow.up.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(viewModel.isPerformingBatchOperation || !viewModel.hasConfigurations)
                .accessibilityLabel(NSLocalizedString("Mount all configured drives", comment: "Mount all button accessibility label"))
                .accessibilityHint(NSLocalizedString("Double tap to mount all configured drives", comment: "Mount all button accessibility hint"))

                // Unmount All button
                Button(
                    action: performUnmountAll,
                    label: {
                        Label(
                            NSLocalizedString("Unmount All", comment: "Unmount all button title"),
                            systemImage: "arrow.down.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(viewModel.isPerformingBatchOperation || !viewModel.hasMountedVolumes)
                .accessibilityLabel(NSLocalizedString("Unmount all mounted drives", comment: "Unmount all button accessibility label"))
                .accessibilityHint(NSLocalizedString("Double tap to unmount all mounted drives", comment: "Unmount all button accessibility hint"))

                // Refresh Status button
                Button(
                    action: performRefreshStatus,
                    label: {
                        Label(
                            NSLocalizedString("Refresh", comment: "Refresh button title"),
                            systemImage: "arrow.clockwise.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.isPerformingBatchOperation)
                .accessibilityLabel(NSLocalizedString("Refresh all connection statuses", comment: "Refresh button accessibility label"))
                .accessibilityHint(NSLocalizedString("Double tap to refresh all connection statuses", comment: "Refresh button accessibility hint"))
            }

            // Progress indicator
            if viewModel.isPerformingBatchOperation {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.batchOperationProgress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity)

                    Text(NSLocalizedString("Processing...", comment: "Batch operation in progress"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Operation result summary
            if let lastResult = viewModel.lastBatchResult, !lastResult.failedItems.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Some operations failed", comment: "Batch operation partial failure"))
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(String(format: NSLocalizedString("%d of %d operations succeeded", comment: "Batch operation success count"), lastResult.successCount, lastResult.totalCount))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Private Methods

    /// Performs the "Mount All" operation
    private func performMountAll() {
        Task {
            await viewModel.mountAll()
        }
    }

    /// Performs the "Unmount All" operation
    private func performUnmountAll() {
        Task {
            await viewModel.unmountAll()
        }
    }

    /// Performs the "Refresh Status" operation
    private func performRefreshStatus() {
        Task {
            await viewModel.refreshStatus()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct QuickActionsPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()

                QuickActionsPanel(viewModel: DashboardViewModel())
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

            // Dark mode preview
            ZStack {
                Color.black
                    .ignoresSafeArea()

                QuickActionsPanel(viewModel: DashboardViewModel())
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .frame(width: 400, height: 200)
    }
}
#endif