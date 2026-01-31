//
//  StorageViewModel.swift
//  LanMount
//
//  ViewModel for managing storage data and providing computed summaries
//  Requirements: 2.3 - Dashboard displays total storage capacity, used capacity, and available capacity summary
//

import Foundation
import Combine
import SwiftUI

// MARK: - StorageViewModel

/// ViewModel for managing storage data visualization
/// Subscribes to StorageMonitor data stream and computes storage summaries
/// - Note: This class is MainActor-isolated for safe UI updates
@MainActor
final class StorageViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of storage data for all monitored volumes
    @Published private(set) var storageData: [VolumeStorageData] = []
    
    /// Aggregated storage summary across all volumes
    @Published private(set) var totalStorage: StorageSummary = .empty
    
    /// Indicates whether storage data is currently being loaded
    @Published private(set) var isLoading: Bool = false
    
    /// The most recent error encountered during storage operations
    @Published private(set) var error: Error?
    
    // MARK: - Private Properties
    
    /// The storage monitor service for fetching volume data
    private let storageMonitor: StorageMonitorProtocol
    
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a new StorageViewModel
    /// - Parameter storageMonitor: The storage monitor service to subscribe to
    init(storageMonitor: StorageMonitorProtocol) {
        self.storageMonitor = storageMonitor
        setupSubscriptions()
    }
    
    /// Convenience initializer using the default StorageMonitor
    convenience init() {
        self.init(storageMonitor: StorageMonitor())
    }
    
    // MARK: - Public Methods
    
    /// Refreshes storage data from all monitored volumes
    /// Updates storageData and totalStorage properties upon completion
    func refresh() async {
        isLoading = true
        error = nil
        
        do {
            let data = await storageMonitor.refreshNow()
            updateStorageData(data)
        } catch let refreshError {
            error = refreshError
        }
        
        isLoading = false
    }
    
    /// Gets storage data for a specific volume by ID
    /// - Parameter volumeId: The UUID of the volume to look up
    /// - Returns: The VolumeStorageData for the volume, or nil if not found
    func getStorageData(for volumeId: UUID) -> VolumeStorageData? {
        return storageData.first { $0.id == volumeId }
    }
    
    /// Gets storage data for a specific volume by name
    /// - Parameter volumeName: The name of the volume to look up
    /// - Returns: The VolumeStorageData for the volume, or nil if not found
    func getStorageData(byName volumeName: String) -> VolumeStorageData? {
        return storageData.first { $0.volumeName == volumeName }
    }
    
    /// Starts monitoring storage data
    /// Call this when the view appears
    func startMonitoring() {
        storageMonitor.startMonitoring()
    }
    
    /// Stops monitoring storage data
    /// Call this when the view disappears
    func stopMonitoring() {
        storageMonitor.stopMonitoring()
    }
    
    /// Adds a mount point to be monitored
    /// - Parameter mountPoint: The mount point path to monitor
    func addMountPoint(_ mountPoint: String) {
        storageMonitor.addMountPoint(mountPoint)
    }
    
    /// Removes a mount point from monitoring
    /// - Parameter mountPoint: The mount point path to stop monitoring
    func removeMountPoint(_ mountPoint: String) {
        storageMonitor.removeMountPoint(mountPoint)
    }
    
    /// Returns whether monitoring is currently active
    var isMonitoring: Bool {
        return storageMonitor.isMonitoring
    }
    
    /// Returns the list of currently monitored mount points
    var monitoredMountPoints: [String] {
        return storageMonitor.monitoredMountPoints
    }
    
    // MARK: - Computed Properties
    
    /// Returns volumes with warning-level usage (80-95%)
    var warningVolumes: [VolumeStorageData] {
        return storageData.filter { $0.usageLevel == .warning }
    }
    
    /// Returns volumes with critical-level usage (>95%)
    var criticalVolumes: [VolumeStorageData] {
        return storageData.filter { $0.usageLevel == .critical }
    }
    
    /// Returns true if any volume has warning or critical usage level
    var hasStorageAlerts: Bool {
        return !warningVolumes.isEmpty || !criticalVolumes.isEmpty
    }
    
    /// Returns the number of volumes being monitored
    var volumeCount: Int {
        return storageData.count
    }
    
    /// Returns true if there is storage data available to display
    var hasData: Bool {
        return !storageData.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// Sets up Combine subscriptions to the storage monitor
    private func setupSubscriptions() {
        storageMonitor.storageDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.updateStorageData(data)
            }
            .store(in: &cancellables)
    }
    
    /// Updates storage data and computes the summary
    /// - Parameter data: The new array of volume storage data
    private func updateStorageData(_ data: [VolumeStorageData]) {
        storageData = data
        totalStorage = StorageSummary.from(volumes: data)
        
        // Clear any previous error on successful update
        if !data.isEmpty {
            error = nil
        }
    }
}

// MARK: - StorageViewModelError

/// Errors that can occur during storage view model operations
enum StorageViewModelError: LocalizedError {
    /// Failed to refresh storage data
    case refreshFailed(underlying: Error?)
    /// No volumes are being monitored
    case noVolumesMonitored
    /// Volume not found
    case volumeNotFound(id: UUID)
    
    var errorDescription: String? {
        switch self {
        case .refreshFailed(let underlying):
            if let underlyingError = underlying {
                return String(
                    format: NSLocalizedString(
                        "Failed to refresh storage data: %@",
                        comment: "Storage refresh error"
                    ),
                    underlyingError.localizedDescription
                )
            }
            return NSLocalizedString(
                "Failed to refresh storage data",
                comment: "Storage refresh error without details"
            )
        case .noVolumesMonitored:
            return NSLocalizedString(
                "No volumes are being monitored",
                comment: "No volumes error"
            )
        case .volumeNotFound(let id):
            return String(
                format: NSLocalizedString(
                    "Volume with ID %@ not found",
                    comment: "Volume not found error"
                ),
                id.uuidString
            )
        }
    }
}
