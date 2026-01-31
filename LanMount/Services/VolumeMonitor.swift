//
//  VolumeMonitor.swift
//  LanMount
//
//  Monitors mounted volumes for state changes, disconnections, and network status
//  Requirements: 8.1, 8.2, 8.3, 8.4, 8.5
//

import Foundation
import AppKit
import Network

// MARK: - VolumeMonitorProtocol

/// Protocol defining the interface for volume monitoring operations
/// Monitors mounted SMB volumes for state changes and disconnections
protocol VolumeMonitorProtocol {
    /// Starts monitoring mounted volumes
    /// Begins listening for mount/unmount notifications and periodic status checks
    func startMonitoring()
    
    /// Stops monitoring mounted volumes
    /// Removes all notification observers and stops periodic checks
    func stopMonitoring()
    
    /// Stream of volume events, updated in real-time as volume states change
    var volumeEvents: AsyncStream<VolumeEvent> { get }
    
    /// Indicates whether monitoring is currently active
    var isMonitoring: Bool { get }
    
    /// Gets the current list of monitored mount points
    var monitoredMountPoints: [String] { get }
    
    /// Adds a mount point to be monitored
    /// - Parameter mountPoint: The mount point path to monitor
    func addMountPoint(_ mountPoint: String)
    
    /// Removes a mount point from monitoring
    /// - Parameter mountPoint: The mount point path to stop monitoring
    func removeMountPoint(_ mountPoint: String)
}

// MARK: - VolumeMonitor

/// Implementation of VolumeMonitorProtocol using NSWorkspace notifications and periodic status checks
/// Monitors SMB volumes for mount/unmount events and unexpected disconnections
final class VolumeMonitor: VolumeMonitorProtocol {
    
    // MARK: - Constants
    
    /// Default interval for periodic status checks (30 seconds as per requirements)
    private static let defaultCheckInterval: TimeInterval = 30.0
    
    // MARK: - Properties
    
    /// The notification center for workspace notifications
    private let notificationCenter: NotificationCenter
    
    /// Interval for periodic status checks
    private let checkInterval: TimeInterval
    
    /// Continuation for the AsyncStream
    private var streamContinuation: AsyncStream<VolumeEvent>.Continuation?
    
    /// The AsyncStream for volume events
    private var _volumeEvents: AsyncStream<VolumeEvent>?
    
    /// Set of mount points being monitored
    private var _monitoredMountPoints: Set<String> = []
    
    /// Lock for thread-safe access to monitored mount points
    private let mountPointsLock = NSLock()
    
    /// Current monitoring state
    private var _isMonitoring: Bool = false
    
    /// Lock for thread-safe access to _isMonitoring
    private let monitoringLock = NSLock()
    
    /// Task for periodic status checks
    private var periodicCheckTask: Task<Void, Never>?
    
    /// Network path monitor for detecting network changes
    private var networkMonitor: NWPathMonitor?
    
    /// Queue for network monitor
    private let networkQueue = DispatchQueue(label: "com.lanmount.volumemonitor.network", qos: .utility)
    
    /// Last known network status
    private var lastNetworkStatus: NWPath.Status = .satisfied
    
    /// Notification observers
    private var didMountObserver: NSObjectProtocol?
    private var didUnmountObserver: NSObjectProtocol?
    private var willUnmountObserver: NSObjectProtocol?
    
    /// Cache of last known mount states for detecting disconnections
    private var lastKnownStates: [String: Bool] = [:]
    
    /// Lock for thread-safe access to lastKnownStates
    private let statesLock = NSLock()
    
    /// Cache manager for caching mount status to reduce statfs calls
    /// Requirements: 11.1, 11.2 - Performance optimization
    private let cacheManager: CacheManagerProtocol?
    
    // MARK: - VolumeMonitorProtocol Properties
    
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
    
    var volumeEvents: AsyncStream<VolumeEvent> {
        if let existing = _volumeEvents {
            return existing
        }
        
        let stream = AsyncStream<VolumeEvent> { [weak self] continuation in
            self?.streamContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                // Don't stop monitoring on stream termination
                // as we may want to create a new stream
            }
        }
        
        _volumeEvents = stream
        return stream
    }
    
    // MARK: - Initialization
    
    /// Creates a new VolumeMonitor instance
    /// - Parameters:
    ///   - checkInterval: The interval for periodic status checks (defaults to 30 seconds)
    ///   - notificationCenter: The notification center to use (defaults to NSWorkspace.shared.notificationCenter)
    ///   - cacheManager: Optional cache manager for caching mount status
    init(
        checkInterval: TimeInterval = VolumeMonitor.defaultCheckInterval,
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        cacheManager: CacheManagerProtocol? = nil
    ) {
        self.checkInterval = checkInterval
        self.notificationCenter = notificationCenter
        self.cacheManager = cacheManager
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - VolumeMonitorProtocol Implementation
    
    func startMonitoring() {
        guard !isMonitoring else {
            return
        }
        
        setMonitoringState(true)
        
        // Create a new stream if needed
        if _volumeEvents == nil {
            _ = volumeEvents
        }
        
        // Register for workspace notifications
        registerNotificationObservers()
        
        // Start network monitoring
        startNetworkMonitoring()
        
        // Start periodic status checks
        startPeriodicChecks()
        
        // Initialize last known states for all monitored mount points
        initializeLastKnownStates()
    }
    
    func stopMonitoring() {
        // Stop periodic checks
        periodicCheckTask?.cancel()
        periodicCheckTask = nil
        
        // Stop network monitoring
        networkMonitor?.cancel()
        networkMonitor = nil
        
        // Remove notification observers
        removeNotificationObservers()
        
        // Finish the stream
        streamContinuation?.finish()
        streamContinuation = nil
        _volumeEvents = nil
        
        // Update monitoring state
        setMonitoringState(false)
        
        // Clear last known states
        statesLock.lock()
        lastKnownStates.removeAll()
        statesLock.unlock()
    }
    
    func addMountPoint(_ mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        mountPointsLock.lock()
        _monitoredMountPoints.insert(normalizedPath)
        mountPointsLock.unlock()
        
        // Initialize the last known state for this mount point
        statesLock.lock()
        lastKnownStates[normalizedPath] = isMountPointAccessible(normalizedPath)
        statesLock.unlock()
    }
    
    func removeMountPoint(_ mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        mountPointsLock.lock()
        _monitoredMountPoints.remove(normalizedPath)
        mountPointsLock.unlock()
        
        statesLock.lock()
        lastKnownStates.removeValue(forKey: normalizedPath)
        statesLock.unlock()
    }
    
    // MARK: - Private Methods
    
    /// Sets the monitoring state in a thread-safe manner
    /// - Parameter monitoring: The new monitoring state
    private func setMonitoringState(_ monitoring: Bool) {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        _isMonitoring = monitoring
    }
    
    /// Registers notification observers for volume events
    private func registerNotificationObservers() {
        // Observer for volume mount events
        didMountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleDidMountNotification(notification)
        }
        
        // Observer for volume unmount events
        didUnmountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleDidUnmountNotification(notification)
        }
        
        // Observer for volume will unmount events
        willUnmountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.willUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWillUnmountNotification(notification)
        }
    }
    
    /// Removes all notification observers
    private func removeNotificationObservers() {
        if let observer = didMountObserver {
            notificationCenter.removeObserver(observer)
            didMountObserver = nil
        }
        
        if let observer = didUnmountObserver {
            notificationCenter.removeObserver(observer)
            didUnmountObserver = nil
        }
        
        if let observer = willUnmountObserver {
            notificationCenter.removeObserver(observer)
            willUnmountObserver = nil
        }
    }
    
    /// Starts network path monitoring
    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handleNetworkPathUpdate(path)
        }
        
        monitor.start(queue: networkQueue)
    }
    
    /// Starts periodic status checks
    private func startPeriodicChecks() {
        periodicCheckTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(self.checkInterval * 1_000_000_000))
                    
                    guard !Task.isCancelled else { break }
                    
                    await self.performPeriodicCheck()
                } catch {
                    // Task was cancelled
                    break
                }
            }
        }
    }
    
    /// Initializes last known states for all monitored mount points
    private func initializeLastKnownStates() {
        let mountPoints = monitoredMountPoints
        
        statesLock.lock()
        for mountPoint in mountPoints {
            lastKnownStates[mountPoint] = isMountPointAccessible(mountPoint)
        }
        statesLock.unlock()
    }
    
    /// Handles the didMount notification
    /// - Parameter notification: The notification object
    private func handleDidMountNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            return
        }
        
        let mountPoint = volumeURL.path
        
        // Invalidate cache for this mount point since state changed
        cacheManager?.invalidateMountStatus(for: mountPoint)
        
        // Check if this is an SMB mount
        guard isSMBMount(at: mountPoint) else {
            return
        }
        
        // Create a MountedVolume from the mount point
        if let volume = createMountedVolume(from: mountPoint) {
            // Update last known state
            statesLock.lock()
            lastKnownStates[mountPoint] = true
            statesLock.unlock()
            
            // Emit the mounted event
            streamContinuation?.yield(.mounted(volume))
        }
    }
    
    /// Handles the didUnmount notification
    /// - Parameter notification: The notification object
    private func handleDidUnmountNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            return
        }
        
        let mountPoint = volumeURL.path
        
        // Invalidate cache for this mount point since state changed
        cacheManager?.invalidateMountStatus(for: mountPoint)
        
        // Update last known state
        statesLock.lock()
        lastKnownStates[mountPoint] = false
        statesLock.unlock()
        
        // Emit the unmounted event
        streamContinuation?.yield(.unmounted(mountPoint))
        
        // Remove from monitored mount points if it was being monitored
        removeMountPoint(mountPoint)
    }
    
    /// Handles the willUnmount notification
    /// - Parameter notification: The notification object
    private func handleWillUnmountNotification(_ notification: Notification) {
        // This notification is informational - we don't emit an event for it
        // but we could use it for cleanup or preparation if needed
    }
    
    /// Handles network path updates
    /// - Parameter path: The updated network path
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let newStatus = path.status
        let previousStatus = lastNetworkStatus
        lastNetworkStatus = newStatus
        
        // If network became unavailable, check all monitored mount points
        if previousStatus == .satisfied && newStatus != .satisfied {
            Task {
                await checkAllMountPointsForDisconnection()
            }
        }
        
        // If network became available again, we might want to trigger reconnection
        // This is handled by the auto-reconnect feature in MountManager
    }
    
    /// Performs a periodic check of all monitored mount points
    @MainActor
    private func performPeriodicCheck() async {
        let mountPoints = monitoredMountPoints
        
        for mountPoint in mountPoints {
            let isAccessible = isMountPointAccessible(mountPoint)
            
            statesLock.lock()
            let wasAccessible = lastKnownStates[mountPoint] ?? true
            lastKnownStates[mountPoint] = isAccessible
            statesLock.unlock()
            
            // If the mount point was accessible but is no longer, it's disconnected
            if wasAccessible && !isAccessible {
                streamContinuation?.yield(.disconnected(mountPoint))
            }
        }
    }
    
    /// Checks all mount points for disconnection after network change
    @MainActor
    private func checkAllMountPointsForDisconnection() async {
        let mountPoints = monitoredMountPoints
        
        for mountPoint in mountPoints {
            let isAccessible = isMountPointAccessible(mountPoint)
            
            statesLock.lock()
            let wasAccessible = lastKnownStates[mountPoint] ?? true
            lastKnownStates[mountPoint] = isAccessible
            statesLock.unlock()
            
            if wasAccessible && !isAccessible {
                streamContinuation?.yield(.disconnected(mountPoint))
            }
        }
    }
    
    /// Checks if a mount point is accessible using statfs
    /// Uses cache to reduce frequent statfs calls
    /// - Parameter mountPoint: The mount point path to check
    /// - Returns: true if the mount point is accessible, false otherwise
    /// Requirements: 11.1, 11.2 - Performance optimization
    private func isMountPointAccessible(_ mountPoint: String) -> Bool {
        // Check cache first to avoid frequent statfs calls
        if let cacheManager = cacheManager,
           let cachedStatus = cacheManager.getCachedMountStatus(for: mountPoint) {
            return cachedStatus.isAccessible
        }
        
        // Perform actual statfs check
        var statInfo = statfs()
        
        // statfs returns 0 on success
        guard statfs(mountPoint, &statInfo) == 0 else {
            // Cache the negative result
            cacheMountStatus(mountPoint: mountPoint, isAccessible: false, isSMBMount: false, filesystemType: nil, mountSource: nil)
            return false
        }
        
        // Verify the mount point is actually mounted (not just a directory)
        let mountSource = withUnsafePointer(to: &statInfo.f_mntfromname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        
        // Get filesystem type
        let fsType = withUnsafePointer(to: &statInfo.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                String(cString: $0)
            }
        }
        
        // If the mount source is empty or just the path itself, it's not a real mount
        let isAccessible = !mountSource.isEmpty && mountSource != mountPoint
        let isSMBMount = fsType.lowercased() == "smbfs"
        
        // Cache the result
        cacheMountStatus(mountPoint: mountPoint, isAccessible: isAccessible, isSMBMount: isSMBMount, filesystemType: fsType, mountSource: mountSource)
        
        return isAccessible
    }
    
    /// Caches mount status for a mount point
    /// - Parameters:
    ///   - mountPoint: The mount point path
    ///   - isAccessible: Whether the mount point is accessible
    ///   - isSMBMount: Whether it's an SMB mount
    ///   - filesystemType: The filesystem type
    ///   - mountSource: The mount source
    private func cacheMountStatus(mountPoint: String, isAccessible: Bool, isSMBMount: Bool, filesystemType: String?, mountSource: String?) {
        guard let cacheManager = cacheManager else { return }
        
        let entry = MountStatusCacheEntry(
            isAccessible: isAccessible,
            isSMBMount: isSMBMount,
            filesystemType: filesystemType,
            mountSource: mountSource,
            ttl: CacheManager.defaultMountStatusTTL
        )
        
        cacheManager.cacheMountStatus(entry, for: mountPoint)
    }
    
    /// Checks if a mount point is an SMB mount
    /// Uses cache to reduce frequent statfs calls
    /// - Parameter path: The mount point path
    /// - Returns: true if it's an SMB mount, false otherwise
    /// Requirements: 11.1, 11.2 - Performance optimization
    private func isSMBMount(at path: String) -> Bool {
        // Check cache first
        if let cacheManager = cacheManager,
           let cachedStatus = cacheManager.getCachedMountStatus(for: path) {
            return cachedStatus.isSMBMount
        }
        
        var statInfo = statfs()
        
        guard statfs(path, &statInfo) == 0 else {
            return false
        }
        
        // Get the filesystem type
        let fsType = withUnsafePointer(to: &statInfo.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                String(cString: $0)
            }
        }
        
        // Get mount source for caching
        let mountSource = withUnsafePointer(to: &statInfo.f_mntfromname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        
        let isSMB = fsType.lowercased() == "smbfs"
        let isAccessible = !mountSource.isEmpty && mountSource != path
        
        // Cache the result
        cacheMountStatus(mountPoint: path, isAccessible: isAccessible, isSMBMount: isSMB, filesystemType: fsType, mountSource: mountSource)
        
        // SMB mounts typically show as "smbfs"
        return isSMB
    }
    
    /// Creates a MountedVolume from a mount point path
    /// - Parameter path: The mount point path
    /// - Returns: A MountedVolume, or nil if creation fails
    private func createMountedVolume(from path: String) -> MountedVolume? {
        var statInfo = statfs()
        
        guard statfs(path, &statInfo) == 0 else {
            return nil
        }
        
        // Get the mount source (e.g., //server/share)
        let mountSource = withUnsafePointer(to: &statInfo.f_mntfromname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        
        // Parse server and share from mount source
        let (server, share) = parseMountSource(mountSource)
        
        guard !server.isEmpty, !share.isEmpty else {
            return nil
        }
        
        // Get volume name
        let volumeName = getVolumeName(at: path) ?? share
        
        // Get space information
        let blockSize = Int64(statInfo.f_bsize)
        let totalBlocks = Int64(statInfo.f_blocks)
        let freeBlocks = Int64(statInfo.f_bfree)
        
        let bytesTotal = totalBlocks * blockSize
        let bytesUsed = (totalBlocks - freeBlocks) * blockSize
        
        return MountedVolume(
            server: server,
            share: share,
            mountPoint: path,
            volumeName: volumeName,
            status: .connected,
            mountedAt: Date(),
            bytesUsed: bytesUsed,
            bytesTotal: bytesTotal
        )
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
            return ("", "")
        }
        
        return (String(components[0]), String(components[1]))
    }
    
    /// Gets the volume name for a mount point
    /// - Parameter path: The mount point path
    /// - Returns: The volume name, or nil if unavailable
    private func getVolumeName(at path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeNameKey])
            return resourceValues.volumeName
        } catch {
            return (path as NSString).lastPathComponent
        }
    }
}


// MARK: - Mock VolumeMonitor for Testing

/// Mock implementation of VolumeMonitorProtocol for unit testing
final class MockVolumeMonitor: VolumeMonitorProtocol {
    
    // MARK: - Test Configuration
    
    /// Events to emit during monitoring
    var eventsToEmit: [VolumeEvent] = []
    
    /// Delay between emitting events (in seconds)
    var emitDelay: TimeInterval = 0.1
    
    /// Whether to simulate monitoring failure
    var simulateFailure: Bool = false
    
    // MARK: - State
    
    private var _isMonitoring: Bool = false
    private var streamContinuation: AsyncStream<VolumeEvent>.Continuation?
    private var _volumeEvents: AsyncStream<VolumeEvent>?
    private var monitorTask: Task<Void, Never>?
    private var _monitoredMountPoints: Set<String> = []
    private let mountPointsLock = NSLock()
    
    /// Records of startMonitoring calls
    var startMonitoringCalls: Int = 0
    
    /// Records of stopMonitoring calls
    var stopMonitoringCalls: Int = 0
    
    /// Records of addMountPoint calls
    var addMountPointCalls: [String] = []
    
    /// Records of removeMountPoint calls
    var removeMountPointCalls: [String] = []
    
    // MARK: - VolumeMonitorProtocol Properties
    
    var isMonitoring: Bool {
        return _isMonitoring
    }
    
    var monitoredMountPoints: [String] {
        mountPointsLock.lock()
        defer { mountPointsLock.unlock() }
        return Array(_monitoredMountPoints)
    }
    
    var volumeEvents: AsyncStream<VolumeEvent> {
        if let existing = _volumeEvents {
            return existing
        }
        
        let stream = AsyncStream<VolumeEvent> { [weak self] continuation in
            self?.streamContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                // Don't stop monitoring on stream termination
            }
        }
        
        _volumeEvents = stream
        return stream
    }
    
    // MARK: - VolumeMonitorProtocol Implementation
    
    func startMonitoring() {
        startMonitoringCalls += 1
        
        guard !_isMonitoring else { return }
        _isMonitoring = true
        
        // Create stream if needed
        if _volumeEvents == nil {
            _ = volumeEvents
        }
        
        if simulateFailure {
            stopMonitoring()
            return
        }
        
        // Start emitting events
        monitorTask = Task { [weak self] in
            guard let self = self else { return }
            
            for event in self.eventsToEmit {
                guard !Task.isCancelled else { break }
                
                try? await Task.sleep(nanoseconds: UInt64(self.emitDelay * 1_000_000_000))
                
                guard !Task.isCancelled else { break }
                
                self.streamContinuation?.yield(event)
            }
        }
    }
    
    func stopMonitoring() {
        stopMonitoringCalls += 1
        
        monitorTask?.cancel()
        monitorTask = nil
        
        streamContinuation?.finish()
        streamContinuation = nil
        _volumeEvents = nil
        
        _isMonitoring = false
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
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and configuration
    func reset() {
        stopMonitoring()
        eventsToEmit = []
        emitDelay = 0.1
        simulateFailure = false
        startMonitoringCalls = 0
        stopMonitoringCalls = 0
        addMountPointCalls = []
        removeMountPointCalls = []
        
        mountPointsLock.lock()
        _monitoredMountPoints.removeAll()
        mountPointsLock.unlock()
    }
    
    /// Manually emits an event (for testing real-time updates)
    func emitEvent(_ event: VolumeEvent) {
        streamContinuation?.yield(event)
    }
    
    /// Simulates a volume mount
    func simulateMount(_ volume: MountedVolume) {
        addMountPoint(volume.mountPoint)
        streamContinuation?.yield(.mounted(volume))
    }
    
    /// Simulates a volume unmount
    func simulateUnmount(mountPoint: String) {
        removeMountPoint(mountPoint)
        streamContinuation?.yield(.unmounted(mountPoint))
    }
    
    /// Simulates a volume disconnection
    func simulateDisconnect(mountPoint: String) {
        streamContinuation?.yield(.disconnected(mountPoint))
    }
    
    /// Simulates a reconnection attempt
    func simulateReconnecting(mountPoint: String) {
        streamContinuation?.yield(.reconnecting(mountPoint))
    }
}
