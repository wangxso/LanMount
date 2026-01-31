//
//  IOMonitorViewModel.swift
//  LanMount
//
//  ViewModel for managing IO monitoring data and providing real-time statistics
//  Requirements: 3.1 - Display read/write speed as real-time line chart for each connected disk
//  Requirements: 3.3 - Display current speed, average speed, and peak speed
//

import Foundation
import Combine
import SwiftUI

// MARK: - IOMonitorViewModel

/// ViewModel for managing IO monitoring data visualization
/// Subscribes to IOStatsCollector data stream and manages monitoring state
/// - Note: This class is MainActor-isolated for safe UI updates
@MainActor
final class IOMonitorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of current IO statistics for all monitored volumes
    /// Requirements: 3.3 - Includes current, average, and peak speeds
    @Published private(set) var currentStats: [VolumeIOStats] = []
    
    /// Historical IO data points for chart display
    /// Requirements: 3.1 - Used for real-time line chart visualization
    @Published private(set) var historyData: [IODataPoint] = []
    
    /// Indicates whether IO monitoring is currently active
    @Published private(set) var isMonitoring: Bool = false
    
    /// The most recent error encountered during IO monitoring operations
    @Published private(set) var error: Error?
    
    // MARK: - Private Properties
    
    /// The IO stats collector service for fetching IO data
    private let ioStatsCollector: IOStatsCollectorProtocol
    
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Default history duration for chart display (60 seconds)
    private let defaultHistoryDuration: TimeInterval = 60.0
    
    // MARK: - Initialization
    
    /// Creates a new IOMonitorViewModel
    /// - Parameter ioStatsCollector: The IO stats collector service to subscribe to
    init(ioStatsCollector: IOStatsCollectorProtocol) {
        self.ioStatsCollector = ioStatsCollector
        setupSubscriptions()
    }
    
    /// Convenience initializer using the default IOStatsCollector
    convenience init() {
        self.init(ioStatsCollector: IOStatsCollector())
    }
    
    // MARK: - Public Methods
    
    /// Starts IO monitoring
    /// Begins collecting IO statistics and publishing updates
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        error = nil
        ioStatsCollector.startCollecting()
        isMonitoring = ioStatsCollector.isCollecting
    }
    
    /// Stops IO monitoring
    /// Stops collecting IO statistics
    func stopMonitoring() {
        ioStatsCollector.stopCollecting()
        isMonitoring = false
    }
    
    /// Gets IO statistics for a specific volume by ID
    /// - Parameter volumeId: The UUID of the volume to look up
    /// - Returns: The VolumeIOStats for the volume, or nil if not found
    func getStats(for volumeId: UUID) -> VolumeIOStats? {
        return currentStats.first { $0.id == volumeId }
    }
    
    /// Gets IO statistics for a specific volume by name
    /// - Parameter volumeName: The name of the volume to look up
    /// - Returns: The VolumeIOStats for the volume, or nil if not found
    func getStats(byName volumeName: String) -> VolumeIOStats? {
        return currentStats.first { $0.volumeName == volumeName }
    }
    
    /// Gets historical IO data points for a specific volume
    /// - Parameter volumeId: The UUID of the volume to get history for
    /// - Returns: Array of IODataPoint for the specified volume
    func getHistory(for volumeId: UUID) -> [IODataPoint] {
        return historyData.filter { $0.volumeId == volumeId }
    }
    
    /// Gets historical IO data points within a specific duration
    /// - Parameter duration: The duration to look back (in seconds)
    /// - Returns: Array of IODataPoint within the specified duration
    func getHistory(duration: TimeInterval) -> [IODataPoint] {
        return ioStatsCollector.getHistory(duration: duration)
    }
    
    /// Adds a mount point to be monitored for IO statistics
    /// - Parameters:
    ///   - mountPoint: The mount point path to monitor
    ///   - volumeId: The unique identifier for the volume
    ///   - volumeName: The display name of the volume
    func addMountPoint(_ mountPoint: String, volumeId: UUID, volumeName: String) {
        ioStatsCollector.addMountPoint(mountPoint, volumeId: volumeId, volumeName: volumeName)
    }
    
    /// Removes a mount point from IO monitoring
    /// - Parameter mountPoint: The mount point path to stop monitoring
    func removeMountPoint(_ mountPoint: String) {
        ioStatsCollector.removeMountPoint(mountPoint)
    }
    
    /// Returns the list of currently monitored mount points
    var monitoredMountPoints: [String] {
        return ioStatsCollector.monitoredMountPoints
    }
    
    // MARK: - Computed Properties
    
    /// Returns the total current read speed across all volumes (bytes per second)
    var totalReadSpeed: Int64 {
        return currentStats.reduce(0) { $0 + $1.readBytesPerSecond }
    }
    
    /// Returns the total current write speed across all volumes (bytes per second)
    var totalWriteSpeed: Int64 {
        return currentStats.reduce(0) { $0 + $1.writeBytesPerSecond }
    }
    
    /// Returns a formatted string for the total read speed
    var formattedTotalReadSpeed: String {
        ByteCountFormatter.string(fromByteCount: totalReadSpeed, countStyle: .file) + "/s"
    }
    
    /// Returns a formatted string for the total write speed
    var formattedTotalWriteSpeed: String {
        ByteCountFormatter.string(fromByteCount: totalWriteSpeed, countStyle: .file) + "/s"
    }
    
    /// Returns the number of volumes being monitored
    var volumeCount: Int {
        return currentStats.count
    }
    
    /// Returns true if there are any active IO operations
    var hasActiveIO: Bool {
        return totalReadSpeed > 0 || totalWriteSpeed > 0
    }
    
    /// Returns the volume with the highest current read speed
    var highestReadSpeedVolume: VolumeIOStats? {
        return currentStats.max(by: { $0.readBytesPerSecond < $1.readBytesPerSecond })
    }
    
    /// Returns the volume with the highest current write speed
    var highestWriteSpeedVolume: VolumeIOStats? {
        return currentStats.max(by: { $0.writeBytesPerSecond < $1.writeBytesPerSecond })
    }
    
    /// Returns the overall peak read speed across all volumes
    var overallPeakReadSpeed: Int64 {
        return currentStats.map { $0.peakReadSpeed }.max() ?? 0
    }
    
    /// Returns the overall peak write speed across all volumes
    var overallPeakWriteSpeed: Int64 {
        return currentStats.map { $0.peakWriteSpeed }.max() ?? 0
    }
    
    /// Returns a formatted string for the overall peak read speed
    var formattedOverallPeakReadSpeed: String {
        ByteCountFormatter.string(fromByteCount: overallPeakReadSpeed, countStyle: .file) + "/s"
    }
    
    /// Returns a formatted string for the overall peak write speed
    var formattedOverallPeakWriteSpeed: String {
        ByteCountFormatter.string(fromByteCount: overallPeakWriteSpeed, countStyle: .file) + "/s"
    }
    
    /// Returns true if there is IO data available to display
    var hasData: Bool {
        return !currentStats.isEmpty || !historyData.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// Sets up Combine subscriptions to the IO stats collector
    private func setupSubscriptions() {
        // Subscribe to current IO statistics updates
        ioStatsCollector.statsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.updateCurrentStats(stats)
            }
            .store(in: &cancellables)
        
        // Subscribe to historical IO data updates
        ioStatsCollector.historyPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.updateHistoryData(history)
            }
            .store(in: &cancellables)
    }
    
    /// Updates current IO statistics
    /// - Parameter stats: The new array of volume IO statistics
    private func updateCurrentStats(_ stats: [VolumeIOStats]) {
        currentStats = stats
        
        // Update monitoring state based on collector state
        isMonitoring = ioStatsCollector.isCollecting
        
        // Clear any previous error on successful update
        if !stats.isEmpty {
            error = nil
        }
    }
    
    /// Updates historical IO data
    /// - Parameter history: The new array of IO data points
    private func updateHistoryData(_ history: [IODataPoint]) {
        historyData = history
    }
}

// MARK: - IOMonitorViewModelError

/// Errors that can occur during IO monitor view model operations
enum IOMonitorViewModelError: LocalizedError {
    /// Failed to start IO monitoring
    case monitoringStartFailed(underlying: Error?)
    /// No volumes are being monitored
    case noVolumesMonitored
    /// Volume not found
    case volumeNotFound(id: UUID)
    /// IO data unavailable for volume
    case dataUnavailable(volumeName: String)
    
    var errorDescription: String? {
        switch self {
        case .monitoringStartFailed(let underlying):
            if let underlyingError = underlying {
                return String(
                    format: NSLocalizedString(
                        "Failed to start IO monitoring: %@",
                        comment: "IO monitoring start error"
                    ),
                    underlyingError.localizedDescription
                )
            }
            return NSLocalizedString(
                "Failed to start IO monitoring",
                comment: "IO monitoring start error without details"
            )
        case .noVolumesMonitored:
            return NSLocalizedString(
                "No volumes are being monitored for IO statistics",
                comment: "No volumes monitored error"
            )
        case .volumeNotFound(let id):
            return String(
                format: NSLocalizedString(
                    "Volume with ID %@ not found",
                    comment: "Volume not found error"
                ),
                id.uuidString
            )
        case .dataUnavailable(let volumeName):
            return String(
                format: NSLocalizedString(
                    "IO data unavailable for volume: %@",
                    comment: "IO data unavailable error"
                ),
                volumeName
            )
        }
    }
}
