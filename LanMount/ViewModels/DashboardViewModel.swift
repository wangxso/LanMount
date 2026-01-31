//
//  DashboardViewModel.swift
//  LanMount
//
//  ViewModel for the main dashboard, integrating storage, IO monitoring, and connection management
//  Requirements: 6.1 - Provide "Mount All" button to mount all configured disk sources with one click
//  Requirements: 6.2 - Provide "Unmount All" button to unmount all mounted disks with one click
//  Requirements: 6.3 - Provide "Refresh Status" button to manually refresh all connection status information
//

import Foundation
import Combine
import SwiftUI

// MARK: - DashboardViewModel

/// ViewModel for the main dashboard view
/// Integrates StorageViewModel, IOMonitorViewModel, and ConnectionManagerViewModel
/// Provides batch operations for mounting, unmounting, and refreshing status
/// - Note: This class is MainActor-isolated for safe UI updates
@MainActor
final class DashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of currently mounted volumes
    @Published private(set) var mountedVolumes: [MountedVolume] = []
    
    /// Array of all mount configurations
    @Published private(set) var configurations: [MountConfiguration] = []
    
    /// Indicates whether a batch operation is currently in progress
    /// Requirements: 6.4 - Display progress indicator during batch operations
    @Published private(set) var isPerformingBatchOperation: Bool = false
    
    /// Progress of the current batch operation (0.0 to 1.0)
    /// Requirements: 6.4 - Display progress indicator during batch operations
    @Published private(set) var batchOperationProgress: Double = 0.0
    
    /// The most recent error encountered during operations
    @Published private(set) var error: Error?
    
    /// The result of the last batch operation
    @Published private(set) var lastBatchResult: BatchOperationResult?
    
    // MARK: - Child ViewModels
    
    /// ViewModel for storage data visualization
    let storageViewModel: StorageViewModel
    
    /// ViewModel for IO monitoring
    let ioMonitorViewModel: IOMonitorViewModel
    
    /// ViewModel for connection management
    let connectionManagerViewModel: ConnectionManagerViewModel
    
    // MARK: - Private Properties
    
    /// The mount manager service for mount/unmount operations
    private let mountManager: MountManagerProtocol
    
    /// The configuration store for reading configurations
    private let configurationStore: ConfigurationStoreProtocol
    
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a new DashboardViewModel with the specified dependencies
    /// - Parameters:
    ///   - storageViewModel: ViewModel for storage data
    ///   - ioMonitorViewModel: ViewModel for IO monitoring
    ///   - connectionManagerViewModel: ViewModel for connection management
    ///   - mountManager: Service for mount/unmount operations
    ///   - configurationStore: Service for reading configurations
    init(
        storageViewModel: StorageViewModel,
        ioMonitorViewModel: IOMonitorViewModel,
        connectionManagerViewModel: ConnectionManagerViewModel,
        mountManager: MountManagerProtocol,
        configurationStore: ConfigurationStoreProtocol
    ) {
        self.storageViewModel = storageViewModel
        self.ioMonitorViewModel = ioMonitorViewModel
        self.connectionManagerViewModel = connectionManagerViewModel
        self.mountManager = mountManager
        self.configurationStore = configurationStore
        
        setupSubscriptions()
    }
    
    /// Convenience initializer using default services
    convenience init() {
        let configStore = ConfigurationStore()
        let mountMgr = MountManager()
        
        self.init(
            storageViewModel: StorageViewModel(),
            ioMonitorViewModel: IOMonitorViewModel(),
            connectionManagerViewModel: ConnectionManagerViewModel(
                configurationStore: configStore,
                mountManager: mountMgr
            ),
            mountManager: mountMgr,
            configurationStore: configStore
        )
    }
    
    // MARK: - Public Methods
    
    /// Mounts all configured disk sources
    /// Requirements: 6.1 - Provide "Mount All" button to mount all configured disk sources with one click
    /// Requirements: 6.4 - Display progress indicator during batch operations
    /// Requirements: 6.5 - Continue processing other disks if one fails, summarize failures at completion
    /// - Returns: A BatchOperationResult containing the results of all mount operations
    func mountAll() async -> BatchOperationResult {
        isPerformingBatchOperation = true
        batchOperationProgress = 0.0
        error = nil
        
        defer {
            isPerformingBatchOperation = false
            batchOperationProgress = 1.0
        }
        
        // Get all configurations
        let configs: [MountConfiguration]
        do {
            configs = try configurationStore.getAllMountConfigs()
        } catch {
            self.error = error
            let result = BatchOperationResult(totalCount: 0, successCount: 0, failedItems: [])
            lastBatchResult = result
            return result
        }
        
        guard !configs.isEmpty else {
            let result = BatchOperationResult(totalCount: 0, successCount: 0, failedItems: [])
            lastBatchResult = result
            return result
        }
        
        // Filter out already mounted configurations
        let configsToMount = configs.filter { config in
            !mountManager.isMounted(mountPoint: config.mountPoint)
        }
        
        let totalCount = configs.count
        var successCount = configs.count - configsToMount.count // Already mounted count as success
        var failedItems: [FailedOperationItem] = []
        var processedCount = configs.count - configsToMount.count
        
        // Mount each configuration
        for config in configsToMount {
            do {
                let result = try await mountManager.mount(
                    server: config.server,
                    share: config.share,
                    mountPoint: config.mountPoint,
                    credentials: nil
                )
                
                if result.success {
                    successCount += 1
                } else {
                    let errorMessage = result.error?.localizedDescription ?? "Unknown error"
                    failedItems.append(FailedOperationItem(
                        volumeName: "\(config.server)/\(config.share)",
                        error: errorMessage
                    ))
                }
            } catch {
                failedItems.append(FailedOperationItem(
                    volumeName: "\(config.server)/\(config.share)",
                    error: error.localizedDescription
                ))
            }
            
            processedCount += 1
            batchOperationProgress = Double(processedCount) / Double(totalCount)
        }
        
        // Refresh mounted volumes list
        await refreshMountedVolumes()
        
        let result = BatchOperationResult(
            totalCount: totalCount,
            successCount: successCount,
            failedItems: failedItems
        )
        lastBatchResult = result
        return result
    }
    
    /// Unmounts all currently mounted disks
    /// Requirements: 6.2 - Provide "Unmount All" button to unmount all mounted disks with one click
    /// Requirements: 6.4 - Display progress indicator during batch operations
    /// Requirements: 6.5 - Continue processing other disks if one fails, summarize failures at completion
    /// - Returns: A BatchOperationResult containing the results of all unmount operations
    func unmountAll() async -> BatchOperationResult {
        isPerformingBatchOperation = true
        batchOperationProgress = 0.0
        error = nil
        
        defer {
            isPerformingBatchOperation = false
            batchOperationProgress = 1.0
        }
        
        // Get all mounted volumes
        let volumes = mountManager.getMountedVolumes()
        
        guard !volumes.isEmpty else {
            let result = BatchOperationResult(totalCount: 0, successCount: 0, failedItems: [])
            lastBatchResult = result
            return result
        }
        
        let totalCount = volumes.count
        var successCount = 0
        var failedItems: [FailedOperationItem] = []
        var processedCount = 0
        
        // Unmount each volume
        for volume in volumes {
            do {
                try await mountManager.unmount(mountPoint: volume.mountPoint)
                successCount += 1
            } catch {
                failedItems.append(FailedOperationItem(
                    volumeName: volume.volumeName,
                    error: error.localizedDescription
                ))
            }
            
            processedCount += 1
            batchOperationProgress = Double(processedCount) / Double(totalCount)
        }
        
        // Refresh mounted volumes list
        await refreshMountedVolumes()
        
        let result = BatchOperationResult(
            totalCount: totalCount,
            successCount: successCount,
            failedItems: failedItems
        )
        lastBatchResult = result
        return result
    }
    
    /// Refreshes the status of all connections and data
    /// Requirements: 6.3 - Provide "Refresh Status" button to manually refresh all connection status information
    func refreshStatus() async {
        isPerformingBatchOperation = true
        batchOperationProgress = 0.0
        error = nil
        
        defer {
            isPerformingBatchOperation = false
            batchOperationProgress = 1.0
        }
        
        // Refresh mounted volumes
        batchOperationProgress = 0.25
        await refreshMountedVolumes()
        
        // Refresh mount statuses
        batchOperationProgress = 0.5
        await mountManager.refreshMountStatusesAsync()
        
        // Refresh storage data
        batchOperationProgress = 0.75
        await storageViewModel.refresh()
        
        // Reload configurations
        await connectionManagerViewModel.loadConfigurations()
        
        batchOperationProgress = 1.0
    }
    
    /// Starts monitoring for storage and IO data
    /// Call this when the dashboard view appears
    func startMonitoring() {
        storageViewModel.startMonitoring()
        ioMonitorViewModel.startMonitoring()
        
        // Add mount points for monitoring
        for volume in mountedVolumes {
            storageViewModel.addMountPoint(volume.mountPoint)
            ioMonitorViewModel.addMountPoint(
                volume.mountPoint,
                volumeId: volume.id,
                volumeName: volume.volumeName
            )
        }
    }
    
    /// Stops monitoring for storage and IO data
    /// Call this when the dashboard view disappears
    func stopMonitoring() {
        storageViewModel.stopMonitoring()
        ioMonitorViewModel.stopMonitoring()
    }
    
    /// Loads initial data for the dashboard
    func loadInitialData() async {
        await refreshMountedVolumes()
        await connectionManagerViewModel.loadConfigurations()
        await storageViewModel.refresh()
    }
    
    // MARK: - Computed Properties
    
    /// Returns the total number of mounted volumes
    var mountedVolumeCount: Int {
        return mountedVolumes.count
    }
    
    /// Returns the total number of configurations
    var configurationCount: Int {
        return configurations.count
    }
    
    /// Returns true if there are any mounted volumes
    var hasMountedVolumes: Bool {
        return !mountedVolumes.isEmpty
    }
    
    /// Returns true if there are any configurations
    var hasConfigurations: Bool {
        return !configurations.isEmpty
    }
    
    /// Returns configurations that are not currently mounted
    var unmountedConfigurations: [MountConfiguration] {
        return configurations.filter { config in
            !mountManager.isMounted(mountPoint: config.mountPoint)
        }
    }
    
    /// Returns the number of unmounted configurations
    var unmountedCount: Int {
        return unmountedConfigurations.count
    }
    
    /// Returns the number of connection errors
    /// Requirements: 8.1 - Disk config tab badge for connection errors
    /// Counts mounted volumes with error status
    var errorCount: Int {
        return mountedVolumes.filter { volume in
            if case .error = volume.status {
                return true
            }
            return false
        }.count
    }
    
    /// Returns the number of storage warnings (volumes with usage > 90%)
    /// Requirements: 8.2 - Disk info tab badge for storage warnings
    /// Counts volumes where storage usage exceeds 90%
    var storageWarningCount: Int {
        return storageViewModel.storageData.filter { volume in
            volume.usagePercentage > 90
        }.count
    }
    
    // MARK: - Private Methods
    
    /// Sets up Combine subscriptions to child view models
    private func setupSubscriptions() {
        // Subscribe to connection manager configurations
        connectionManagerViewModel.$configurations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configs in
                self?.configurations = configs
            }
            .store(in: &cancellables)
        
        // Subscribe to mount status change notifications
        NotificationCenter.default.publisher(for: .mountStatusDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshMountedVolumes()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Refreshes the list of mounted volumes from the mount manager
    private func refreshMountedVolumes() async {
        mountedVolumes = mountManager.getMountedVolumes()
        
        // Update storage monitoring for mounted volumes
        for volume in mountedVolumes {
            storageViewModel.addMountPoint(volume.mountPoint)
        }
    }
}

// MARK: - DashboardViewModelError

/// Errors that can occur during dashboard view model operations
enum DashboardViewModelError: LocalizedError {
    /// Failed to load configurations
    case configurationLoadFailed(underlying: Error)
    /// Batch mount operation failed
    case batchMountFailed(failedCount: Int)
    /// Batch unmount operation failed
    case batchUnmountFailed(failedCount: Int)
    /// Refresh operation failed
    case refreshFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .configurationLoadFailed(let underlying):
            return String(
                format: NSLocalizedString(
                    "Failed to load configurations: %@",
                    comment: "Configuration load error"
                ),
                underlying.localizedDescription
            )
        case .batchMountFailed(let failedCount):
            return String(
                format: NSLocalizedString(
                    "Failed to mount %d volume(s)",
                    comment: "Batch mount error"
                ),
                failedCount
            )
        case .batchUnmountFailed(let failedCount):
            return String(
                format: NSLocalizedString(
                    "Failed to unmount %d volume(s)",
                    comment: "Batch unmount error"
                ),
                failedCount
            )
        case .refreshFailed(let underlying):
            return String(
                format: NSLocalizedString(
                    "Failed to refresh status: %@",
                    comment: "Refresh error"
                ),
                underlying.localizedDescription
            )
        }
    }
}
