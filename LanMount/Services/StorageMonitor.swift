//
//  StorageMonitor.swift
//  LanMount
//
//  Monitors storage information for mounted SMB volumes
//  Requirements: 2.2 - Storage data refresh within 2 seconds
//  Requirements: 6.1 - Storage trend chart with 7 days of historical data
//

import Foundation
import Combine

// MARK: - StorageMonitorProtocol

/// Protocol defining the interface for storage monitoring operations
/// Monitors mounted SMB volumes for storage capacity and usage information
protocol StorageMonitorProtocol {
    /// Publisher that emits storage data updates for all monitored volumes
    var storageDataPublisher: AnyPublisher<[VolumeStorageData], Never> { get }
    
    /// Publisher that emits storage history data updates
    var storageHistoryPublisher: AnyPublisher<[StorageTrendDataPoint], Never> { get }
    
    /// Starts monitoring storage data with periodic refresh
    func startMonitoring()
    
    /// Stops monitoring storage data
    func stopMonitoring()
    
    /// Immediately refreshes storage data for all monitored volumes
    /// - Returns: Array of current storage data for all volumes
    func refreshNow() async -> [VolumeStorageData]
    
    /// Gets storage information for a specific mount point
    /// - Parameter mountPoint: The mount point path to query
    /// - Returns: Storage data for the mount point, or nil if not found
    func getStorageInfo(for mountPoint: String) -> VolumeStorageData?
    
    /// Indicates whether monitoring is currently active
    var isMonitoring: Bool { get }
    
    /// Adds a mount point to be monitored
    /// - Parameter mountPoint: The mount point path to monitor
    func addMountPoint(_ mountPoint: String)
    
    /// Removes a mount point from monitoring
    /// - Parameter mountPoint: The mount point path to stop monitoring
    func removeMountPoint(_ mountPoint: String)
    
    /// Gets the current list of monitored mount points
    var monitoredMountPoints: [String] { get }
    
    // MARK: - Storage History Methods (Requirements 6.1)
    
    /// Gets historical storage data for all volumes
    /// - Returns: Array of storage trend data points for the past 7 days
    var storageHistory: [StorageTrendDataPoint] { get }
    
    /// Gets historical storage data for a specific volume
    /// - Parameter volumeId: The UUID of the volume to query
    /// - Returns: Array of storage trend data points for the specified volume
    func getStorageHistory(for volumeId: UUID) -> [StorageTrendDataPoint]
    
    /// Adds a storage snapshot to the history
    /// - Parameter dataPoint: The storage trend data point to add
    func addStorageSnapshot(_ dataPoint: StorageTrendDataPoint)
    
    /// Prunes storage history data older than the retention period
    func pruneOldHistoryData()
}

// MARK: - StorageMonitor

/// Implementation of StorageMonitorProtocol using FileManager to collect storage information
/// Refreshes storage data every 2 seconds as per requirements
/// Maintains 7 days of historical storage data for trend charts (Requirements 6.1)
final class StorageMonitor: StorageMonitorProtocol {
    
    // MARK: - Constants
    
    /// Default refresh interval (2 seconds as per requirements 2.2)
    static let defaultRefreshInterval: TimeInterval = 2.0
    
    /// History snapshot interval (1 hour - collect one snapshot per hour for trend data)
    static let historySnapshotInterval: TimeInterval = 3600.0
    
    /// History retention period (7 days as per requirements 6.1)
    static let historyRetentionDays: Int = 7
    
    // MARK: - Properties
    
    /// The refresh interval for storage data updates
    private let refreshInterval: TimeInterval
    
    /// Timer for periodic refresh
    private var timer: Timer?
    
    /// Timer for periodic history snapshots
    private var historyTimer: Timer?
    
    /// Subject for publishing storage data updates
    private let storageSubject = CurrentValueSubject<[VolumeStorageData], Never>([])
    
    /// Subject for publishing storage history updates
    private let historySubject = CurrentValueSubject<[StorageTrendDataPoint], Never>([])
    
    /// Set of mount points being monitored
    private var _monitoredMountPoints: Set<String> = []
    
    /// Lock for thread-safe access to monitored mount points
    private let mountPointsLock = NSLock()
    
    /// Current monitoring state
    private var _isMonitoring: Bool = false
    
    /// Lock for thread-safe access to _isMonitoring
    private let monitoringLock = NSLock()
    
    /// Cache of storage data by mount point
    private var storageCache: [String: VolumeStorageData] = [:]
    
    /// Lock for thread-safe access to storage cache
    private let cacheLock = NSLock()
    
    /// Storage history data buffer (7 days of data)
    private var _storageHistory: [StorageTrendDataPoint] = []
    
    /// Lock for thread-safe access to storage history
    private let historyLock = NSLock()
    
    /// Mapping of mount points to volume UUIDs for consistent tracking
    private var volumeIdMapping: [String: UUID] = [:]
    
    /// Lock for thread-safe access to volume ID mapping
    private let volumeIdLock = NSLock()
    
    /// Last snapshot time for each volume (to avoid duplicate snapshots)
    private var lastSnapshotTime: [UUID: Date] = [:]
    
    /// FileManager instance for querying storage information
    private let fileManager: FileManager
    
    // MARK: - StorageMonitorProtocol Properties
    
    var storageDataPublisher: AnyPublisher<[VolumeStorageData], Never> {
        storageSubject.eraseToAnyPublisher()
    }
    
    var storageHistoryPublisher: AnyPublisher<[StorageTrendDataPoint], Never> {
        historySubject.eraseToAnyPublisher()
    }
    
    var isMonitoring: Bool {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        return _isMonitoring
    }
    
    var monitoredMountPoints: [String] {
        mountPointsLock.lock()
        defer { mountPointsLock.unlock() }
        return Array(_monitoredMountPoints)
    }
    
    var storageHistory: [StorageTrendDataPoint] {
        historyLock.lock()
        defer { historyLock.unlock() }
        return _storageHistory
    }
    
    // MARK: - Initialization
    
    /// Creates a new StorageMonitor instance
    /// - Parameters:
    ///   - refreshInterval: The interval for periodic storage data refresh (defaults to 2 seconds)
    ///   - fileManager: The FileManager instance to use (defaults to .default)
    init(
        refreshInterval: TimeInterval = StorageMonitor.defaultRefreshInterval,
        fileManager: FileManager = .default
    ) {
        self.refreshInterval = refreshInterval
        self.fileManager = fileManager
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - StorageMonitorProtocol Implementation
    
    func startMonitoring() {
        guard !isMonitoring else {
            return
        }
        
        setMonitoringState(true)
        
        // Perform initial refresh
        Task {
            _ = await refreshNow()
            // Take initial history snapshot
            await collectHistorySnapshot()
        }
        
        // Start periodic timer on main run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.timer = Timer.scheduledTimer(
                withTimeInterval: self.refreshInterval,
                repeats: true
            ) { [weak self] _ in
                Task { [weak self] in
                    _ = await self?.refreshNow()
                }
            }
            
            // Add to common run loop mode to ensure timer fires during UI interactions
            if let timer = self.timer {
                RunLoop.main.add(timer, forMode: .common)
            }
            
            // Start history snapshot timer (every hour)
            self.historyTimer = Timer.scheduledTimer(
                withTimeInterval: StorageMonitor.historySnapshotInterval,
                repeats: true
            ) { [weak self] _ in
                Task { [weak self] in
                    await self?.collectHistorySnapshot()
                }
            }
            
            if let historyTimer = self.historyTimer {
                RunLoop.main.add(historyTimer, forMode: .common)
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        
        historyTimer?.invalidate()
        historyTimer = nil
        
        setMonitoringState(false)
        
        // Clear cache
        cacheLock.lock()
        storageCache.removeAll()
        cacheLock.unlock()
        
        // Publish empty data
        storageSubject.send([])
        // Note: We don't clear history on stop - it should persist
    }
    
    func refreshNow() async -> [VolumeStorageData] {
        let mountPoints = monitoredMountPoints
        var storageDataList: [VolumeStorageData] = []
        
        for mountPoint in mountPoints {
            if let storageData = await fetchStorageData(for: mountPoint) {
                storageDataList.append(storageData)
                
                // Update cache
                cacheLock.lock()
                storageCache[mountPoint] = storageData
                cacheLock.unlock()
            }
        }
        
        // Publish updated data
        storageSubject.send(storageDataList)
        
        return storageDataList
    }
    
    func getStorageInfo(for mountPoint: String) -> VolumeStorageData? {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return storageCache[normalizedPath]
    }
    
    func addMountPoint(_ mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        mountPointsLock.lock()
        _monitoredMountPoints.insert(normalizedPath)
        mountPointsLock.unlock()
        
        // Fetch initial storage data for this mount point
        if isMonitoring {
            Task {
                if let storageData = await fetchStorageData(for: normalizedPath) {
                    cacheLock.lock()
                    storageCache[normalizedPath] = storageData
                    cacheLock.unlock()
                    
                    // Publish updated data
                    let allData = Array(storageCache.values)
                    storageSubject.send(allData)
                }
            }
        }
    }
    
    func removeMountPoint(_ mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        mountPointsLock.lock()
        _monitoredMountPoints.remove(normalizedPath)
        mountPointsLock.unlock()
        
        // Remove from cache
        cacheLock.lock()
        storageCache.removeValue(forKey: normalizedPath)
        let allData = Array(storageCache.values)
        cacheLock.unlock()
        
        // Publish updated data
        storageSubject.send(allData)
    }
    
    // MARK: - Storage History Methods (Requirements 6.1)
    
    func getStorageHistory(for volumeId: UUID) -> [StorageTrendDataPoint] {
        historyLock.lock()
        defer { historyLock.unlock() }
        return _storageHistory.filter { $0.volumeId == volumeId }
    }
    
    func addStorageSnapshot(_ dataPoint: StorageTrendDataPoint) {
        historyLock.lock()
        _storageHistory.append(dataPoint)
        let currentHistory = _storageHistory
        historyLock.unlock()
        
        // Prune old data after adding
        pruneOldHistoryData()
        
        // Publish updated history
        historySubject.send(currentHistory)
    }
    
    func pruneOldHistoryData() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -StorageMonitor.historyRetentionDays,
            to: Date()
        ) ?? Date()
        
        historyLock.lock()
        _storageHistory = _storageHistory.filter { $0.date >= cutoffDate }
        let currentHistory = _storageHistory
        historyLock.unlock()
        
        // Publish updated history
        historySubject.send(currentHistory)
    }
    
    // MARK: - Private Methods
    
    /// Collects a history snapshot for all monitored volumes
    /// Called periodically (every hour) to build trend data
    private func collectHistorySnapshot() async {
        let mountPoints = monitoredMountPoints
        let now = Date()
        
        for mountPoint in mountPoints {
            // Get or create volume ID for this mount point
            let volumeId = getOrCreateVolumeId(for: mountPoint)
            
            // Check if we already have a recent snapshot for this volume
            if let lastSnapshot = lastSnapshotTime[volumeId],
               now.timeIntervalSince(lastSnapshot) < StorageMonitor.historySnapshotInterval * 0.9 {
                // Skip if we have a recent snapshot (within 90% of interval)
                continue
            }
            
            // Fetch current storage data
            if let storageData = await fetchStorageData(for: mountPoint) {
                let dataPoint = StorageTrendDataPoint(
                    volumeId: volumeId,
                    volumeName: storageData.volumeName,
                    date: now,
                    usedBytes: storageData.usedBytes,
                    totalBytes: storageData.totalBytes
                )
                
                addStorageSnapshot(dataPoint)
                lastSnapshotTime[volumeId] = now
            }
        }
    }
    
    /// Gets or creates a consistent volume ID for a mount point
    /// - Parameter mountPoint: The mount point path
    /// - Returns: A UUID that consistently identifies this volume
    private func getOrCreateVolumeId(for mountPoint: String) -> UUID {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        volumeIdLock.lock()
        defer { volumeIdLock.unlock() }
        
        if let existingId = volumeIdMapping[normalizedPath] {
            return existingId
        }
        
        let newId = UUID()
        volumeIdMapping[normalizedPath] = newId
        return newId
    }
    
    /// Sets the monitoring state in a thread-safe manner
    /// - Parameter monitoring: The new monitoring state
    private func setMonitoringState(_ monitoring: Bool) {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        _isMonitoring = monitoring
    }
    
    /// Fetches storage data for a specific mount point
    /// - Parameter mountPoint: The mount point path to query
    /// - Returns: Storage data for the mount point, or nil if unavailable
    private func fetchStorageData(for mountPoint: String) async -> VolumeStorageData? {
        let url = URL(fileURLWithPath: mountPoint)
        
        do {
            // Get volume information using FileManager
            let resourceValues = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeNameKey
            ])
            
            guard let totalCapacity = resourceValues.volumeTotalCapacity,
                  let availableCapacity = resourceValues.volumeAvailableCapacity else {
                return nil
            }
            
            let totalBytes = Int64(totalCapacity)
            let availableBytes = Int64(availableCapacity)
            let usedBytes = totalBytes - availableBytes
            
            // Get volume name
            let volumeName = resourceValues.volumeName ?? (mountPoint as NSString).lastPathComponent
            
            // Parse server and share from mount point
            let (server, share) = parseMountPointInfo(mountPoint)
            
            return VolumeStorageData(
                volumeName: volumeName,
                server: server,
                share: share,
                totalBytes: totalBytes,
                usedBytes: usedBytes,
                availableBytes: availableBytes,
                lastUpdated: Date()
            )
        } catch {
            // Log error but don't crash - volume may have been unmounted
            return nil
        }
    }
    
    /// Parses mount point path to extract server and share information
    /// - Parameter mountPoint: The mount point path
    /// - Returns: A tuple of (server, share) extracted from the mount point
    private func parseMountPointInfo(_ mountPoint: String) -> (server: String, share: String) {
        // Try to get mount source using statfs
        var statInfo = statfs()
        
        guard statfs(mountPoint, &statInfo) == 0 else {
            // Fallback: use mount point name as share
            let share = (mountPoint as NSString).lastPathComponent
            return ("unknown", share)
        }
        
        // Get the mount source (e.g., //server/share)
        let mountSource = withUnsafePointer(to: &statInfo.f_mntfromname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        
        // Parse server and share from mount source
        return parseMountSource(mountSource)
    }
    
    /// Parses a mount source string to extract server and share
    /// - Parameter source: The mount source string (e.g., //server/share)
    /// - Returns: A tuple of (server, share)
    private func parseMountSource(_ source: String) -> (server: String, share: String) {
        // Remove leading slashes
        var cleanSource = source
        while cleanSource.hasPrefix("/") {
            cleanSource = String(cleanSource.dropFirst())
        }
        
        // Remove user@ prefix if present
        if let atIndex = cleanSource.firstIndex(of: "@") {
            cleanSource = String(cleanSource[cleanSource.index(after: atIndex)...])
        }
        
        // Split by /
        let components = cleanSource.split(separator: "/", maxSplits: 1)
        
        guard components.count >= 2 else {
            // Fallback
            return ("unknown", cleanSource.isEmpty ? "unknown" : cleanSource)
        }
        
        return (String(components[0]), String(components[1]))
    }
}

// MARK: - MockStorageMonitor

/// Mock implementation of StorageMonitorProtocol for unit testing
final class MockStorageMonitor: StorageMonitorProtocol {
    
    // MARK: - Test Configuration
    
    /// Storage data to return during monitoring
    var mockStorageData: [VolumeStorageData] = []
    
    /// Storage history data for testing
    var mockStorageHistory: [StorageTrendDataPoint] = []
    
    /// Whether to simulate monitoring failure
    var simulateFailure: Bool = false
    
    /// Delay before publishing data (in seconds)
    var publishDelay: TimeInterval = 0
    
    // MARK: - State
    
    private var _isMonitoring: Bool = false
    private var _monitoredMountPoints: Set<String> = []
    private let mountPointsLock = NSLock()
    private let storageSubject = CurrentValueSubject<[VolumeStorageData], Never>([])
    private let historySubject = CurrentValueSubject<[StorageTrendDataPoint], Never>([])
    
    /// Records of startMonitoring calls
    var startMonitoringCalls: Int = 0
    
    /// Records of stopMonitoring calls
    var stopMonitoringCalls: Int = 0
    
    /// Records of refreshNow calls
    var refreshNowCalls: Int = 0
    
    /// Records of addMountPoint calls
    var addMountPointCalls: [String] = []
    
    /// Records of removeMountPoint calls
    var removeMountPointCalls: [String] = []
    
    /// Records of addStorageSnapshot calls
    var addStorageSnapshotCalls: [StorageTrendDataPoint] = []
    
    /// Records of pruneOldHistoryData calls
    var pruneOldHistoryDataCalls: Int = 0
    
    // MARK: - StorageMonitorProtocol Properties
    
    var storageDataPublisher: AnyPublisher<[VolumeStorageData], Never> {
        storageSubject.eraseToAnyPublisher()
    }
    
    var storageHistoryPublisher: AnyPublisher<[StorageTrendDataPoint], Never> {
        historySubject.eraseToAnyPublisher()
    }
    
    var isMonitoring: Bool {
        return _isMonitoring
    }
    
    var monitoredMountPoints: [String] {
        mountPointsLock.lock()
        defer { mountPointsLock.unlock() }
        return Array(_monitoredMountPoints)
    }
    
    var storageHistory: [StorageTrendDataPoint] {
        return mockStorageHistory
    }
    
    // MARK: - StorageMonitorProtocol Implementation
    
    func startMonitoring() {
        startMonitoringCalls += 1
        
        guard !_isMonitoring else { return }
        _isMonitoring = true
        
        if simulateFailure {
            stopMonitoring()
            return
        }
        
        // Publish mock data
        if publishDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + publishDelay) { [weak self] in
                guard let self = self else { return }
                self.storageSubject.send(self.mockStorageData)
                self.historySubject.send(self.mockStorageHistory)
            }
        } else {
            storageSubject.send(mockStorageData)
            historySubject.send(mockStorageHistory)
        }
    }
    
    func stopMonitoring() {
        stopMonitoringCalls += 1
        _isMonitoring = false
        storageSubject.send([])
    }
    
    func refreshNow() async -> [VolumeStorageData] {
        refreshNowCalls += 1
        
        if publishDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(publishDelay * 1_000_000_000))
        }
        
        storageSubject.send(mockStorageData)
        return mockStorageData
    }
    
    func getStorageInfo(for mountPoint: String) -> VolumeStorageData? {
        return mockStorageData.first { $0.volumeName == (mountPoint as NSString).lastPathComponent }
    }
    
    func addMountPoint(_ mountPoint: String) {
        addMountPointCalls.append(mountPoint)
        
        mountPointsLock.lock()
        _monitoredMountPoints.insert(mountPoint)
        mountPointsLock.unlock()
    }
    
    func removeMountPoint(_ mountPoint: String) {
        removeMountPointCalls.append(mountPoint)
        
        mountPointsLock.lock()
        _monitoredMountPoints.remove(mountPoint)
        mountPointsLock.unlock()
    }
    
    // MARK: - Storage History Methods
    
    func getStorageHistory(for volumeId: UUID) -> [StorageTrendDataPoint] {
        return mockStorageHistory.filter { $0.volumeId == volumeId }
    }
    
    func addStorageSnapshot(_ dataPoint: StorageTrendDataPoint) {
        addStorageSnapshotCalls.append(dataPoint)
        mockStorageHistory.append(dataPoint)
        historySubject.send(mockStorageHistory)
    }
    
    func pruneOldHistoryData() {
        pruneOldHistoryDataCalls += 1
        // In mock, we can optionally implement actual pruning for testing
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -7,
            to: Date()
        ) ?? Date()
        mockStorageHistory = mockStorageHistory.filter { $0.date >= cutoffDate }
        historySubject.send(mockStorageHistory)
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and configuration
    func reset() {
        stopMonitoring()
        mockStorageData = []
        mockStorageHistory = []
        simulateFailure = false
        publishDelay = 0
        startMonitoringCalls = 0
        stopMonitoringCalls = 0
        refreshNowCalls = 0
        addMountPointCalls = []
        removeMountPointCalls = []
        addStorageSnapshotCalls = []
        pruneOldHistoryDataCalls = 0
        
        mountPointsLock.lock()
        _monitoredMountPoints.removeAll()
        mountPointsLock.unlock()
    }
    
    /// Manually publishes storage data (for testing real-time updates)
    func publishStorageData(_ data: [VolumeStorageData]) {
        mockStorageData = data
        storageSubject.send(data)
    }
    
    /// Manually publishes storage history data (for testing)
    func publishStorageHistory(_ data: [StorageTrendDataPoint]) {
        mockStorageHistory = data
        historySubject.send(data)
    }
    
    /// Simulates a storage data update for a specific volume
    func simulateStorageUpdate(for volumeName: String, usedBytes: Int64, totalBytes: Int64) {
        let storageData = VolumeStorageData(
            volumeName: volumeName,
            server: "test-server",
            share: volumeName,
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            availableBytes: totalBytes - usedBytes
        )
        
        // Update or add to mock data
        if let index = mockStorageData.firstIndex(where: { $0.volumeName == volumeName }) {
            mockStorageData[index] = storageData
        } else {
            mockStorageData.append(storageData)
        }
        
        storageSubject.send(mockStorageData)
    }
    
    /// Simulates adding historical storage data for testing trend charts
    func simulateStorageHistory(for volumeId: UUID, volumeName: String, days: Int = 7) {
        let now = Date()
        var history: [StorageTrendDataPoint] = []
        
        for dayOffset in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            let usedBytes = Int64.random(in: 50_000_000_000...100_000_000_000)
            let totalBytes: Int64 = 200_000_000_000
            
            let dataPoint = StorageTrendDataPoint(
                volumeId: volumeId,
                volumeName: volumeName,
                date: date,
                usedBytes: usedBytes,
                totalBytes: totalBytes
            )
            history.append(dataPoint)
        }
        
        mockStorageHistory.append(contentsOf: history)
        historySubject.send(mockStorageHistory)
    }
}
