//
//  SyncEngine.swift
//  LanMount
//
//  Monitors file changes and executes synchronization operations for SMB mounts
//  Requirements: 7.1, 7.2, 7.3, 7.5
//

import Foundation

// MARK: - SyncEngineProtocol

/// Protocol defining the interface for file synchronization operations
/// Monitors local and remote file changes and synchronizes them
protocol SyncEngineProtocol {
    /// Enables synchronization for a mount point
    /// - Parameters:
    ///   - mountPoint: The local filesystem path of the mounted share
    ///   - bidirectional: Whether to sync changes in both directions (local to remote and remote to local)
    /// - Throws: `SMBMounterError` if sync cannot be enabled
    func enableSync(for mountPoint: String, bidirectional: Bool) throws
    
    /// Disables synchronization for a mount point
    /// - Parameter mountPoint: The local filesystem path of the mounted share
    func disableSync(for mountPoint: String)
    
    /// Manually triggers a synchronization for a mount point
    /// - Parameter mountPoint: The local filesystem path to sync
    /// - Throws: `SMBMounterError` if sync fails
    func syncNow(mountPoint: String) async throws
    
    /// Stream of synchronization events, updated in real-time as sync operations occur
    var syncEvents: AsyncStream<SyncEvent> { get }
    
    /// Indicates whether sync is enabled for a specific mount point
    /// - Parameter mountPoint: The mount point to check
    /// - Returns: true if sync is enabled, false otherwise
    func isSyncEnabled(for mountPoint: String) -> Bool
    
    /// Gets all mount points with sync enabled
    var syncEnabledMountPoints: [String] { get }
    
    // MARK: - Conflict Detection and Resolution (Requirement 7.4)
    
    /// Detects conflicts between local and remote file states
    /// - Parameters:
    ///   - localPath: Path to the local file
    ///   - remotePath: Path to the remote file
    /// - Returns: ConflictInfo if a conflict is detected, nil otherwise
    func detectConflict(localPath: String, remotePath: String) -> ConflictInfo?
    
    /// Resolves a file conflict using the specified resolution strategy
    /// - Parameters:
    ///   - conflict: The conflict information
    ///   - resolution: The resolution strategy to apply
    ///   - mountPoint: The mount point where the conflict occurred
    /// - Throws: `SMBMounterError` if resolution fails
    func resolveConflict(_ conflict: ConflictInfo, resolution: ConflictResolution, mountPoint: String) async throws
    
    /// Gets all pending conflicts for a mount point
    /// - Parameter mountPoint: The mount point to check
    /// - Returns: Array of pending conflicts
    func getPendingConflicts(for mountPoint: String) -> [ConflictInfo]
}

// MARK: - SyncConfiguration

/// Configuration for a sync-enabled mount point
struct SyncConfiguration {
    /// The mount point path
    let mountPoint: String
    /// Whether bidirectional sync is enabled
    let bidirectional: Bool
    /// Timestamp when sync was enabled
    let enabledAt: Date
    /// Last sync timestamp
    var lastSyncAt: Date?
}

// MARK: - FileChangeEvent

/// Represents a detected file change
struct FileChangeEvent {
    /// Type of change
    enum ChangeType {
        case created
        case modified
        case deleted
        case renamed
    }
    
    /// The path of the changed file
    let path: String
    /// The type of change
    let changeType: ChangeType
    /// Timestamp of the change
    let timestamp: Date
    /// Whether this is a local or remote change
    let isLocal: Bool
}

// MARK: - FileSnapshot

/// Snapshot of a file's state for change detection
struct FileSnapshot: Equatable {
    /// File path relative to mount point
    let relativePath: String
    /// File modification date
    let modificationDate: Date
    /// File size in bytes
    let size: Int64
    /// Whether the file exists
    let exists: Bool
    
    /// Creates a snapshot from file attributes
    static func from(path: String, relativeTo basePath: String, attributes: [FileAttributeKey: Any]) -> FileSnapshot? {
        guard let modDate = attributes[.modificationDate] as? Date,
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        
        let relativePath = String(path.dropFirst(basePath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        return FileSnapshot(
            relativePath: relativePath,
            modificationDate: modDate,
            size: size,
            exists: true
        )
    }
    
    /// Creates a non-existent file snapshot
    static func nonExistent(relativePath: String) -> FileSnapshot {
        return FileSnapshot(
            relativePath: relativePath,
            modificationDate: Date.distantPast,
            size: 0,
            exists: false
        )
    }
}

// MARK: - FileState

/// Represents the tracked state of a file for conflict detection
struct FileState: Equatable {
    /// The file snapshot at last sync
    let lastSyncSnapshot: FileSnapshot?
    /// The current local snapshot
    var localSnapshot: FileSnapshot?
    /// The current remote snapshot
    var remoteSnapshot: FileSnapshot?
    /// Timestamp of last sync for this file
    var lastSyncTime: Date?
    
    /// Determines if the file has been modified locally since last sync
    var isLocallyModified: Bool {
        guard let lastSync = lastSyncSnapshot, let local = localSnapshot else {
            // If no last sync, consider it modified if local exists
            return localSnapshot?.exists ?? false
        }
        return local.modificationDate > lastSync.modificationDate ||
               local.size != lastSync.size
    }
    
    /// Determines if the file has been modified remotely since last sync
    var isRemotelyModified: Bool {
        guard let lastSync = lastSyncSnapshot, let remote = remoteSnapshot else {
            // If no last sync, consider it modified if remote exists
            return remoteSnapshot?.exists ?? false
        }
        return remote.modificationDate > lastSync.modificationDate ||
               remote.size != lastSync.size
    }
    
    /// Determines if there is a conflict (both local and remote modified)
    var hasConflict: Bool {
        return isLocallyModified && isRemotelyModified
    }
}

// MARK: - SyncEngine

/// Implementation of SyncEngineProtocol using FSEvents for local monitoring
/// and periodic polling for remote monitoring
final class SyncEngine: SyncEngineProtocol {
    
    // MARK: - Constants
    
    /// Default interval for remote polling (5 seconds as per requirements)
    private static let defaultRemotePollInterval: TimeInterval = 5.0
    
    /// Default debounce interval to avoid frequent syncs
    private static let defaultDebounceInterval: TimeInterval = 1.0
    
    /// System files to exclude from synchronization
    private static let excludedFiles: Set<String> = [
        ".DS_Store",
        ".Spotlight-V100",
        ".Trashes",
        ".fseventsd",
        ".TemporaryItems",
        ".VolumeIcon.icns",
        ".localized",
        "._*",  // Apple double files
        ".AppleDouble",
        ".AppleDB",
        ".AppleDesktop",
        "Network Trash Folder",
        "Temporary Items"
    ]
    
    /// File patterns to exclude (prefix patterns)
    private static let excludedPrefixes: [String] = [
        "._",  // Apple double files
        ".~"   // Temporary files
    ]
    
    // MARK: - Properties
    
    /// Remote poll interval
    private let remotePollInterval: TimeInterval
    
    /// Debounce interval
    private let debounceInterval: TimeInterval
    
    /// File manager for filesystem operations
    private let fileManager: FileManager
    
    /// Continuation for the AsyncStream
    private var streamContinuation: AsyncStream<SyncEvent>.Continuation?
    
    /// The AsyncStream for sync events
    private var _syncEvents: AsyncStream<SyncEvent>?
    
    /// Active sync configurations by mount point
    private var syncConfigurations: [String: SyncConfiguration] = [:]
    
    /// Lock for thread-safe access to syncConfigurations
    private let configLock = NSLock()
    
    /// FSEvents stream references by mount point
    private var fsEventStreams: [String: FSEventStreamRef] = [:]
    
    /// Lock for thread-safe access to fsEventStreams
    private let streamLock = NSLock()
    
    /// Remote polling tasks by mount point
    private var remotePollTasks: [String: Task<Void, Never>] = [:]
    
    /// Lock for thread-safe access to remotePollTasks
    private let pollTaskLock = NSLock()
    
    /// File snapshots for change detection (mount point -> relative path -> snapshot)
    private var fileSnapshots: [String: [String: FileSnapshot]] = [:]
    
    /// Lock for thread-safe access to fileSnapshots
    private let snapshotLock = NSLock()
    
    /// Pending changes for debouncing (mount point -> set of paths)
    private var pendingChanges: [String: Set<String>] = [:]
    
    /// Lock for thread-safe access to pendingChanges
    private let pendingLock = NSLock()
    
    /// Debounce tasks by mount point
    private var debounceTasks: [String: Task<Void, Never>] = [:]
    
    /// Lock for thread-safe access to debounceTasks
    private let debounceTaskLock = NSLock()
    
    /// Dispatch queue for FSEvents callbacks
    private let fsEventsQueue = DispatchQueue(label: "com.lanmount.syncengine.fsevents", qos: .utility)
    
    /// Callback context for FSEvents
    private var callbackContexts: [String: UnsafeMutablePointer<SyncEngineContext>] = [:]
    
    // MARK: - Conflict Detection Properties (Requirement 7.4)
    
    /// Pending conflicts by mount point (mount point -> [relative path -> ConflictInfo])
    private var pendingConflicts: [String: [String: ConflictInfo]] = [:]
    
    /// Lock for thread-safe access to pendingConflicts
    private let conflictLock = NSLock()
    
    /// File states for conflict detection (mount point -> relative path -> FileState)
    private var fileStates: [String: [String: FileState]] = [:]
    
    /// Lock for thread-safe access to fileStates
    private let fileStateLock = NSLock()
    
    /// Last sync snapshots (mount point -> relative path -> FileSnapshot)
    private var lastSyncSnapshots: [String: [String: FileSnapshot]] = [:]
    
    /// Lock for thread-safe access to lastSyncSnapshots
    private let lastSyncSnapshotLock = NSLock()
    
    // MARK: - SyncEngineProtocol Properties
    
    var syncEvents: AsyncStream<SyncEvent> {
        if let existing = _syncEvents {
            return existing
        }
        
        let stream = AsyncStream<SyncEvent> { [weak self] continuation in
            self?.streamContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                // Stream terminated
            }
        }
        
        _syncEvents = stream
        return stream
    }
    
    var syncEnabledMountPoints: [String] {
        configLock.lock()
        defer { configLock.unlock() }
        return Array(syncConfigurations.keys)
    }
    
    // MARK: - Initialization
    
    /// Creates a new SyncEngine instance
    /// - Parameters:
    ///   - remotePollInterval: Interval for remote polling (defaults to 5 seconds)
    ///   - debounceInterval: Interval for debouncing changes (defaults to 1 second)
    ///   - fileManager: File manager to use (defaults to FileManager.default)
    init(
        remotePollInterval: TimeInterval = SyncEngine.defaultRemotePollInterval,
        debounceInterval: TimeInterval = SyncEngine.defaultDebounceInterval,
        fileManager: FileManager = .default
    ) {
        self.remotePollInterval = remotePollInterval
        self.debounceInterval = debounceInterval
        self.fileManager = fileManager
    }
    
    deinit {
        // Clean up all sync configurations
        let mountPoints = syncEnabledMountPoints
        for mountPoint in mountPoints {
            disableSync(for: mountPoint)
        }
        
        // Finish the stream
        streamContinuation?.finish()
    }
    
    // MARK: - SyncEngineProtocol Implementation
    
    func enableSync(for mountPoint: String, bidirectional: Bool) throws {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        // Verify the mount point exists and is accessible
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: normalizedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw SMBMounterError.syncFailed(reason: "Mount point does not exist or is not a directory: \(normalizedPath)")
        }
        
        // Check if sync is already enabled
        if isSyncEnabled(for: normalizedPath) {
            // Update configuration if bidirectional setting changed
            configLock.lock()
            if var config = syncConfigurations[normalizedPath], config.bidirectional != bidirectional {
                syncConfigurations[normalizedPath] = SyncConfiguration(
                    mountPoint: normalizedPath,
                    bidirectional: bidirectional,
                    enabledAt: config.enabledAt,
                    lastSyncAt: config.lastSyncAt
                )
            }
            configLock.unlock()
            return
        }
        
        // Create sync configuration
        let config = SyncConfiguration(
            mountPoint: normalizedPath,
            bidirectional: bidirectional,
            enabledAt: Date(),
            lastSyncAt: nil
        )
        
        configLock.lock()
        syncConfigurations[normalizedPath] = config
        configLock.unlock()
        
        // Create initial file snapshot
        createInitialSnapshot(for: normalizedPath)
        
        // Start FSEvents monitoring for local changes
        try startFSEventsMonitoring(for: normalizedPath)
        
        // Start remote polling
        startRemotePolling(for: normalizedPath)
        
        // Emit sync started event
        streamContinuation?.yield(.started(normalizedPath))
    }
    
    func disableSync(for mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        // Stop FSEvents monitoring
        stopFSEventsMonitoring(for: normalizedPath)
        
        // Stop remote polling
        stopRemotePolling(for: normalizedPath)
        
        // Cancel any pending debounce tasks
        cancelDebounceTask(for: normalizedPath)
        
        // Remove configuration
        configLock.lock()
        syncConfigurations.removeValue(forKey: normalizedPath)
        configLock.unlock()
        
        // Clear snapshots
        snapshotLock.lock()
        fileSnapshots.removeValue(forKey: normalizedPath)
        snapshotLock.unlock()
        
        // Clear pending changes
        pendingLock.lock()
        pendingChanges.removeValue(forKey: normalizedPath)
        pendingLock.unlock()
    }
    
    func syncNow(mountPoint: String) async throws {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        // Check for cancellation at the start
        try Task.checkCancellation()
        
        // Verify sync is enabled
        guard isSyncEnabled(for: normalizedPath) else {
            throw SMBMounterError.syncFailed(reason: "Sync is not enabled for mount point: \(normalizedPath)")
        }
        
        // Emit sync started event
        streamContinuation?.yield(.started(normalizedPath))
        
        do {
            // Check for cancellation before performing sync
            try Task.checkCancellation()
            
            // Perform the sync operation
            try await performSync(for: normalizedPath)
            
            // Check for cancellation after sync
            try Task.checkCancellation()
            
            // Update last sync timestamp
            updateLastSyncTime(for: normalizedPath)
            
            // Emit sync completed event
            streamContinuation?.yield(.completed(normalizedPath))
        } catch is CancellationError {
            // Emit sync failed event for cancellation
            streamContinuation?.yield(.failed(normalizedPath, "Sync operation was cancelled"))
            throw CancellationError()
        } catch {
            // Emit sync failed event
            streamContinuation?.yield(.failed(normalizedPath, error.localizedDescription))
            throw error
        }
    }
    
    func isSyncEnabled(for mountPoint: String) -> Bool {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        configLock.lock()
        defer { configLock.unlock() }
        
        return syncConfigurations[normalizedPath] != nil
    }
    
    // MARK: - FSEvents Monitoring
    
    /// Starts FSEvents monitoring for a mount point
    /// - Parameter mountPoint: The mount point to monitor
    private func startFSEventsMonitoring(for mountPoint: String) throws {
        // Create callback context
        let context = UnsafeMutablePointer<SyncEngineContext>.allocate(capacity: 1)
        context.initialize(to: SyncEngineContext(engine: self, mountPoint: mountPoint))
        
        // Store context for cleanup
        streamLock.lock()
        callbackContexts[mountPoint] = context
        streamLock.unlock()
        
        // Create FSEvents stream context
        var streamContext = FSEventStreamContext(
            version: 0,
            info: context,
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        // Create the FSEvents stream
        let pathsToWatch = [mountPoint] as CFArray
        
        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &streamContext,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latency in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            context.deallocate()
            throw SMBMounterError.syncFailed(reason: "Failed to create FSEvents stream for: \(mountPoint)")
        }
        
        // Store the stream reference
        streamLock.lock()
        fsEventStreams[mountPoint] = stream
        streamLock.unlock()
        
        // Schedule the stream on the dispatch queue
        FSEventStreamSetDispatchQueue(stream, fsEventsQueue)
        
        // Start the stream
        if !FSEventStreamStart(stream) {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            
            streamLock.lock()
            fsEventStreams.removeValue(forKey: mountPoint)
            callbackContexts.removeValue(forKey: mountPoint)
            streamLock.unlock()
            
            context.deallocate()
            throw SMBMounterError.syncFailed(reason: "Failed to start FSEvents stream for: \(mountPoint)")
        }
    }
    
    /// Stops FSEvents monitoring for a mount point
    /// - Parameter mountPoint: The mount point to stop monitoring
    private func stopFSEventsMonitoring(for mountPoint: String) {
        streamLock.lock()
        
        if let stream = fsEventStreams.removeValue(forKey: mountPoint) {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        
        if let context = callbackContexts.removeValue(forKey: mountPoint) {
            context.deallocate()
        }
        
        streamLock.unlock()
    }
    
    // MARK: - Remote Polling
    
    /// Starts remote polling for a mount point with cancellation support
    /// - Parameter mountPoint: The mount point to poll
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    private func startRemotePolling(for mountPoint: String) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    // Check for cancellation before sleeping
                    try Task.checkCancellation()
                    
                    try await Task.sleep(nanoseconds: UInt64(self.remotePollInterval * 1_000_000_000))
                    
                    // Check for cancellation after sleeping
                    try Task.checkCancellation()
                    
                    // Check for remote changes
                    await self.checkForRemoteChanges(mountPoint: mountPoint)
                } catch is CancellationError {
                    // Task was cancelled, exit the loop
                    break
                } catch {
                    // Other errors, continue polling
                    continue
                }
            }
        }
        
        pollTaskLock.lock()
        remotePollTasks[mountPoint] = task
        pollTaskLock.unlock()
    }
    
    /// Stops remote polling for a mount point
    /// - Parameter mountPoint: The mount point to stop polling
    private func stopRemotePolling(for mountPoint: String) {
        pollTaskLock.lock()
        if let task = remotePollTasks.removeValue(forKey: mountPoint) {
            task.cancel()
        }
        pollTaskLock.unlock()
    }
    
    // MARK: - Change Detection
    
    /// Creates an initial snapshot of files at a mount point
    /// - Parameter mountPoint: The mount point to snapshot
    private func createInitialSnapshot(for mountPoint: String) {
        var snapshots: [String: FileSnapshot] = [:]
        
        // Enumerate all files in the mount point
        if let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: mountPoint),
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            while let url = enumerator.nextObject() as? URL {
                let path = url.path
                
                // Skip excluded files
                if shouldExcludeFile(path) {
                    continue
                }
                
                // Skip directories
                if let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                   isDirectory {
                    continue
                }
                
                // Create snapshot
                if let attributes = try? fileManager.attributesOfItem(atPath: path),
                   let snapshot = FileSnapshot.from(path: path, relativeTo: mountPoint, attributes: attributes) {
                    snapshots[snapshot.relativePath] = snapshot
                }
            }
        }
        
        snapshotLock.lock()
        fileSnapshots[mountPoint] = snapshots
        snapshotLock.unlock()
    }
    
    /// Checks for remote changes at a mount point
    /// - Parameter mountPoint: The mount point to check
    @MainActor
    private func checkForRemoteChanges(mountPoint: String) async {
        // Get current file state
        var currentSnapshots: [String: FileSnapshot] = [:]
        
        if let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: mountPoint),
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            while let url = enumerator.nextObject() as? URL {
                let path = url.path
                
                // Skip excluded files
                if shouldExcludeFile(path) {
                    continue
                }
                
                // Skip directories
                if let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                   isDirectory {
                    continue
                }
                
                // Create snapshot
                if let attributes = try? fileManager.attributesOfItem(atPath: path),
                   let snapshot = FileSnapshot.from(path: path, relativeTo: mountPoint, attributes: attributes) {
                    currentSnapshots[snapshot.relativePath] = snapshot
                }
            }
        }
        
        // Compare with previous snapshots
        snapshotLock.lock()
        let previousSnapshots = fileSnapshots[mountPoint] ?? [:]
        snapshotLock.unlock()
        
        var changedFiles: [String] = []
        
        // Check for new or modified files
        for (relativePath, currentSnapshot) in currentSnapshots {
            if let previousSnapshot = previousSnapshots[relativePath] {
                // File existed before - check if modified
                if currentSnapshot.modificationDate != previousSnapshot.modificationDate ||
                   currentSnapshot.size != previousSnapshot.size {
                    changedFiles.append(relativePath)
                }
            } else {
                // New file
                changedFiles.append(relativePath)
            }
        }
        
        // Check for deleted files
        for relativePath in previousSnapshots.keys {
            if currentSnapshots[relativePath] == nil {
                changedFiles.append(relativePath)
            }
        }
        
        // Update snapshots
        snapshotLock.lock()
        fileSnapshots[mountPoint] = currentSnapshots
        snapshotLock.unlock()
        
        // Process changes if any
        if !changedFiles.isEmpty {
            handleRemoteChanges(changedFiles, for: mountPoint)
        }
    }
    
    /// Handles detected remote changes
    /// - Parameters:
    ///   - changedFiles: List of changed file paths
    ///   - mountPoint: The mount point where changes occurred
    private func handleRemoteChanges(_ changedFiles: [String], for mountPoint: String) {
        // Add to pending changes for debouncing
        pendingLock.lock()
        var pending = pendingChanges[mountPoint] ?? Set<String>()
        for file in changedFiles {
            pending.insert(file)
        }
        pendingChanges[mountPoint] = pending
        pendingLock.unlock()
        
        // Schedule debounced sync
        scheduleDebounceSync(for: mountPoint)
    }
    
    // MARK: - FSEvents Callback Handling
    
    /// Handles FSEvents callback
    /// - Parameters:
    ///   - paths: Array of changed paths
    ///   - mountPoint: The mount point being monitored
    func handleFSEventsCallback(paths: [String], mountPoint: String) {
        // Filter out excluded files
        let filteredPaths = paths.filter { !shouldExcludeFile($0) }
        
        guard !filteredPaths.isEmpty else { return }
        
        // Add to pending changes for debouncing
        pendingLock.lock()
        var pending = pendingChanges[mountPoint] ?? Set<String>()
        for path in filteredPaths {
            // Convert to relative path
            let relativePath = String(path.dropFirst(mountPoint.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            pending.insert(relativePath)
        }
        pendingChanges[mountPoint] = pending
        pendingLock.unlock()
        
        // Schedule debounced sync
        scheduleDebounceSync(for: mountPoint)
    }
    
    // MARK: - Debouncing
    
    /// Schedules a debounced sync for a mount point with cancellation support
    /// - Parameter mountPoint: The mount point to sync
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    private func scheduleDebounceSync(for mountPoint: String) {
        // Cancel existing debounce task
        cancelDebounceTask(for: mountPoint)
        
        // Create new debounce task
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check for cancellation before sleeping
                try Task.checkCancellation()
                
                try await Task.sleep(nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))
                
                // Check for cancellation after sleeping
                try Task.checkCancellation()
                
                // Get pending changes
                self.pendingLock.lock()
                let pending = self.pendingChanges[mountPoint] ?? Set<String>()
                self.pendingChanges[mountPoint] = Set<String>()
                self.pendingLock.unlock()
                
                guard !pending.isEmpty else { return }
                
                // Check for cancellation before emitting progress
                try Task.checkCancellation()
                
                // Emit progress event
                self.streamContinuation?.yield(.progress(mountPoint, 0, pending.count))
                
                // Perform sync with cancellation support
                try await self.performSync(for: mountPoint)
                
                // Check for cancellation after sync
                try Task.checkCancellation()
                
                // Update last sync time
                self.updateLastSyncTime(for: mountPoint)
                
                // Emit completed event
                self.streamContinuation?.yield(.completed(mountPoint))
            } catch is CancellationError {
                // Task was cancelled, emit failed event
                self.streamContinuation?.yield(.failed(mountPoint, "Sync operation was cancelled"))
            } catch {
                // Emit failed event
                self.streamContinuation?.yield(.failed(mountPoint, error.localizedDescription))
            }
        }
        
        debounceTaskLock.lock()
        debounceTasks[mountPoint] = task
        debounceTaskLock.unlock()
    }
    
    /// Cancels a debounce task for a mount point
    /// - Parameter mountPoint: The mount point
    private func cancelDebounceTask(for mountPoint: String) {
        debounceTaskLock.lock()
        if let task = debounceTasks.removeValue(forKey: mountPoint) {
            task.cancel()
        }
        debounceTaskLock.unlock()
    }
    
    // MARK: - Sync Operations
    
    /// Performs the actual sync operation for a mount point with cancellation support
    /// - Parameter mountPoint: The mount point to sync
    /// - Throws: `CancellationError` if the task is cancelled
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    private func performSync(for mountPoint: String) async throws {
        // Check for cancellation at the start
        try Task.checkCancellation()
        
        // Get configuration
        configLock.lock()
        guard let config = syncConfigurations[mountPoint] else {
            configLock.unlock()
            throw SMBMounterError.syncFailed(reason: "Sync configuration not found for: \(mountPoint)")
        }
        configLock.unlock()
        
        // Check for cancellation before snapshot creation
        try Task.checkCancellation()
        
        // Update snapshots to reflect current state
        createInitialSnapshot(for: mountPoint)
        
        // Check for cancellation before conflict detection
        try Task.checkCancellation()
        
        // Detect conflicts before syncing (Requirement 7.4)
        let conflicts = detectAllConflicts(for: mountPoint)
        
        // If there are conflicts, emit events and wait for resolution
        if !conflicts.isEmpty {
            // Conflicts have already been emitted via detectAllConflicts
            // The sync will continue but conflicting files won't be synced
            // until the user resolves them
        }
        
        // Check for cancellation before bidirectional sync
        try Task.checkCancellation()
        
        // If bidirectional sync is enabled, we would also upload local changes
        if config.bidirectional {
            // In a full implementation, this would:
            // 1. Get list of locally modified files (excluding conflicts)
            // 2. Upload them to remote
            // 3. Update last sync snapshots
        }
        
        // Check for cancellation before recording state
        try Task.checkCancellation()
        
        // Record the current state as the last sync state (for non-conflicting files)
        recordNonConflictingSyncState(for: mountPoint)
    }
    
    /// Records sync state for files that don't have conflicts
    /// - Parameter mountPoint: The mount point
    private func recordNonConflictingSyncState(for mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        // Get current snapshots
        snapshotLock.lock()
        let currentSnapshots = fileSnapshots[normalizedPath] ?? [:]
        snapshotLock.unlock()
        
        // Get pending conflicts
        conflictLock.lock()
        let conflictPaths = Set(pendingConflicts[normalizedPath]?.keys ?? [:].keys)
        conflictLock.unlock()
        
        // Update last sync snapshots for non-conflicting files only
        lastSyncSnapshotLock.lock()
        if lastSyncSnapshots[normalizedPath] == nil {
            lastSyncSnapshots[normalizedPath] = [:]
        }
        
        for (relativePath, snapshot) in currentSnapshots {
            if !conflictPaths.contains(relativePath) {
                lastSyncSnapshots[normalizedPath]?[relativePath] = snapshot
            }
        }
        lastSyncSnapshotLock.unlock()
    }
    
    // MARK: - Helper Methods
    
    /// Checks if a file should be excluded from synchronization
    /// - Parameter path: The file path to check
    /// - Returns: true if the file should be excluded, false otherwise
    private func shouldExcludeFile(_ path: String) -> Bool {
        let fileName = (path as NSString).lastPathComponent
        
        // Check exact matches
        if SyncEngine.excludedFiles.contains(fileName) {
            return true
        }
        
        // Check prefix patterns
        for prefix in SyncEngine.excludedPrefixes {
            if fileName.hasPrefix(prefix) {
                return true
            }
        }
        
        // Check if it's a hidden file (starts with .)
        if fileName.hasPrefix(".") {
            return true
        }
        
        return false
    }
    
    /// Updates the last sync timestamp for a mount point
    /// - Parameter mountPoint: The mount point
    private func updateLastSyncTime(for mountPoint: String) {
        configLock.lock()
        if var config = syncConfigurations[mountPoint] {
            syncConfigurations[mountPoint] = SyncConfiguration(
                mountPoint: config.mountPoint,
                bidirectional: config.bidirectional,
                enabledAt: config.enabledAt,
                lastSyncAt: Date()
            )
        }
        configLock.unlock()
    }
    
    // MARK: - Conflict Detection and Resolution (Requirement 7.4)
    
    func detectConflict(localPath: String, remotePath: String) -> ConflictInfo? {
        // Get file attributes for local file
        guard let localAttributes = try? fileManager.attributesOfItem(atPath: localPath),
              let localModDate = localAttributes[.modificationDate] as? Date,
              let localSize = localAttributes[.size] as? Int64 else {
            return nil
        }
        
        // Get file attributes for remote file
        guard let remoteAttributes = try? fileManager.attributesOfItem(atPath: remotePath),
              let remoteModDate = remoteAttributes[.modificationDate] as? Date,
              let remoteSize = remoteAttributes[.size] as? Int64 else {
            return nil
        }
        
        // Check if there's a conflict (different modification times and/or sizes)
        // A conflict exists when both files have been modified (different from each other)
        let hasTimeDifference = abs(localModDate.timeIntervalSince(remoteModDate)) > 1.0 // 1 second tolerance
        let hasSizeDifference = localSize != remoteSize
        
        if hasTimeDifference || hasSizeDifference {
            return ConflictInfo(
                filePath: localPath,
                localModifiedAt: localModDate,
                remoteModifiedAt: remoteModDate,
                localSize: localSize,
                remoteSize: remoteSize
            )
        }
        
        return nil
    }
    
    func resolveConflict(_ conflict: ConflictInfo, resolution: ConflictResolution, mountPoint: String) async throws {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        let relativePath = String(conflict.filePath.dropFirst(normalizedPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        switch resolution {
        case .keepLocal:
            try await resolveKeepLocal(conflict: conflict, mountPoint: normalizedPath)
            
        case .keepRemote:
            try await resolveKeepRemote(conflict: conflict, mountPoint: normalizedPath)
            
        case .keepBoth:
            try await resolveKeepBoth(conflict: conflict, mountPoint: normalizedPath)
            
        case .skip:
            // Just remove from pending conflicts without any file operations
            break
        }
        
        // Remove from pending conflicts
        conflictLock.lock()
        pendingConflicts[normalizedPath]?.removeValue(forKey: relativePath)
        conflictLock.unlock()
        
        // Update file state after resolution
        updateFileStateAfterResolution(relativePath: relativePath, mountPoint: normalizedPath)
    }
    
    func getPendingConflicts(for mountPoint: String) -> [ConflictInfo] {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        conflictLock.lock()
        defer { conflictLock.unlock() }
        
        return Array(pendingConflicts[normalizedPath]?.values ?? [:].values)
    }
    
    // MARK: - Conflict Resolution Helpers
    
    /// Resolves conflict by keeping the local version
    /// - Parameters:
    ///   - conflict: The conflict to resolve
    ///   - mountPoint: The mount point
    private func resolveKeepLocal(conflict: ConflictInfo, mountPoint: String) async throws {
        // In a real implementation, this would:
        // 1. Copy the local file to overwrite the remote file
        // 2. Update the remote file's metadata
        
        // For now, we just update the last sync snapshot to match local
        let relativePath = String(conflict.filePath.dropFirst(mountPoint.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if let attributes = try? fileManager.attributesOfItem(atPath: conflict.filePath),
           let snapshot = FileSnapshot.from(path: conflict.filePath, relativeTo: mountPoint, attributes: attributes) {
            lastSyncSnapshotLock.lock()
            if lastSyncSnapshots[mountPoint] == nil {
                lastSyncSnapshots[mountPoint] = [:]
            }
            lastSyncSnapshots[mountPoint]?[relativePath] = snapshot
            lastSyncSnapshotLock.unlock()
        }
    }
    
    /// Resolves conflict by keeping the remote version
    /// - Parameters:
    ///   - conflict: The conflict to resolve
    ///   - mountPoint: The mount point
    private func resolveKeepRemote(conflict: ConflictInfo, mountPoint: String) async throws {
        // In a real implementation, this would:
        // 1. Copy the remote file to overwrite the local file
        // 2. Update the local file's metadata
        
        // For now, we just update the last sync snapshot to match remote
        let relativePath = String(conflict.filePath.dropFirst(mountPoint.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Create a snapshot representing the remote state
        let remoteSnapshot = FileSnapshot(
            relativePath: relativePath,
            modificationDate: conflict.remoteModifiedAt,
            size: conflict.remoteSize,
            exists: true
        )
        
        lastSyncSnapshotLock.lock()
        if lastSyncSnapshots[mountPoint] == nil {
            lastSyncSnapshots[mountPoint] = [:]
        }
        lastSyncSnapshots[mountPoint]?[relativePath] = remoteSnapshot
        lastSyncSnapshotLock.unlock()
    }
    
    /// Resolves conflict by keeping both versions (creates a conflict copy)
    /// - Parameters:
    ///   - conflict: The conflict to resolve
    ///   - mountPoint: The mount point
    private func resolveKeepBoth(conflict: ConflictInfo, mountPoint: String) async throws {
        let originalPath = conflict.filePath
        let conflictPath = generateConflictFilePath(for: originalPath)
        
        // Copy the local file to a conflict copy
        do {
            try fileManager.copyItem(atPath: originalPath, toPath: conflictPath)
        } catch {
            throw SMBMounterError.syncFailed(reason: "Failed to create conflict copy: \(error.localizedDescription)")
        }
        
        // Update the last sync snapshot for both files
        let relativePath = String(originalPath.dropFirst(mountPoint.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let conflictRelativePath = String(conflictPath.dropFirst(mountPoint.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        lastSyncSnapshotLock.lock()
        if lastSyncSnapshots[mountPoint] == nil {
            lastSyncSnapshots[mountPoint] = [:]
        }
        
        // Original file will be overwritten with remote version
        let remoteSnapshot = FileSnapshot(
            relativePath: relativePath,
            modificationDate: conflict.remoteModifiedAt,
            size: conflict.remoteSize,
            exists: true
        )
        lastSyncSnapshots[mountPoint]?[relativePath] = remoteSnapshot
        
        // Conflict copy represents the local version
        if let attributes = try? fileManager.attributesOfItem(atPath: conflictPath),
           let conflictSnapshot = FileSnapshot.from(path: conflictPath, relativeTo: mountPoint, attributes: attributes) {
            lastSyncSnapshots[mountPoint]?[conflictRelativePath] = conflictSnapshot
        }
        
        lastSyncSnapshotLock.unlock()
    }
    
    /// Generates a conflict file path by appending a timestamp
    /// - Parameter originalPath: The original file path
    /// - Returns: A new path with conflict suffix
    private func generateConflictFilePath(for originalPath: String) -> String {
        let pathExtension = (originalPath as NSString).pathExtension
        let pathWithoutExtension = (originalPath as NSString).deletingPathExtension
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        if pathExtension.isEmpty {
            return "\(pathWithoutExtension) (conflict \(timestamp))"
        } else {
            return "\(pathWithoutExtension) (conflict \(timestamp)).\(pathExtension)"
        }
    }
    
    /// Updates file state after conflict resolution
    /// - Parameters:
    ///   - relativePath: The relative path of the resolved file
    ///   - mountPoint: The mount point
    private func updateFileStateAfterResolution(relativePath: String, mountPoint: String) {
        fileStateLock.lock()
        defer { fileStateLock.unlock() }
        
        // Reset the file state to indicate no pending changes
        if var states = fileStates[mountPoint] {
            states.removeValue(forKey: relativePath)
            fileStates[mountPoint] = states
        }
    }
    
    // MARK: - Enhanced Conflict Detection
    
    /// Detects conflicts for all files in a mount point during sync
    /// - Parameter mountPoint: The mount point to check
    /// - Returns: Array of detected conflicts
    func detectAllConflicts(for mountPoint: String) -> [ConflictInfo] {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        var conflicts: [ConflictInfo] = []
        
        // Get current snapshots
        snapshotLock.lock()
        let currentSnapshots = fileSnapshots[normalizedPath] ?? [:]
        snapshotLock.unlock()
        
        // Get last sync snapshots
        lastSyncSnapshotLock.lock()
        let lastSnapshots = lastSyncSnapshots[normalizedPath] ?? [:]
        lastSyncSnapshotLock.unlock()
        
        // Check each file for conflicts
        for (relativePath, currentSnapshot) in currentSnapshots {
            guard let lastSnapshot = lastSnapshots[relativePath] else {
                // New file, no conflict possible
                continue
            }
            
            // Check if file has been modified since last sync
            let localModified = currentSnapshot.modificationDate > lastSnapshot.modificationDate ||
                               currentSnapshot.size != lastSnapshot.size
            
            // For remote changes, we compare against what we expect
            // In a real implementation, we would fetch remote file attributes
            // For now, we simulate by checking if the current state differs from last sync
            // and the modification time is different from what we recorded
            
            if localModified {
                // Check if remote was also modified (simulated)
                // In production, this would involve checking the actual remote file
                let fullPath = (normalizedPath as NSString).appendingPathComponent(relativePath)
                
                // Create conflict info if both local and remote appear modified
                let conflict = ConflictInfo(
                    filePath: fullPath,
                    localModifiedAt: currentSnapshot.modificationDate,
                    remoteModifiedAt: lastSnapshot.modificationDate, // Would be actual remote mod time
                    localSize: currentSnapshot.size,
                    remoteSize: lastSnapshot.size // Would be actual remote size
                )
                
                conflicts.append(conflict)
                
                // Store in pending conflicts
                conflictLock.lock()
                if pendingConflicts[normalizedPath] == nil {
                    pendingConflicts[normalizedPath] = [:]
                }
                pendingConflicts[normalizedPath]?[relativePath] = conflict
                conflictLock.unlock()
                
                // Emit conflict event
                streamContinuation?.yield(.conflict(normalizedPath, conflict))
            }
        }
        
        return conflicts
    }
    
    /// Checks if a specific file has a conflict
    /// - Parameters:
    ///   - relativePath: The relative path of the file
    ///   - mountPoint: The mount point
    /// - Returns: ConflictInfo if conflict exists, nil otherwise
    func checkFileForConflict(relativePath: String, mountPoint: String) -> ConflictInfo? {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        let fullPath = (normalizedPath as NSString).appendingPathComponent(relativePath)
        
        // Get current file attributes
        guard let currentAttributes = try? fileManager.attributesOfItem(atPath: fullPath),
              let currentModDate = currentAttributes[.modificationDate] as? Date,
              let currentSize = currentAttributes[.size] as? Int64 else {
            return nil
        }
        
        // Get last sync snapshot
        lastSyncSnapshotLock.lock()
        let lastSnapshot = lastSyncSnapshots[normalizedPath]?[relativePath]
        lastSyncSnapshotLock.unlock()
        
        guard let lastSync = lastSnapshot else {
            // No previous sync, no conflict
            return nil
        }
        
        // Check if modified since last sync
        let localModified = currentModDate > lastSync.modificationDate ||
                           currentSize != lastSync.size
        
        if localModified {
            // In a real implementation, we would also check remote state
            // For now, we create a conflict if local is modified
            return ConflictInfo(
                filePath: fullPath,
                localModifiedAt: currentModDate,
                remoteModifiedAt: lastSync.modificationDate,
                localSize: currentSize,
                remoteSize: lastSync.size
            )
        }
        
        return nil
    }
    
    /// Records the current state as the last sync state for a mount point
    /// - Parameter mountPoint: The mount point
    func recordSyncState(for mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        snapshotLock.lock()
        let currentSnapshots = fileSnapshots[normalizedPath] ?? [:]
        snapshotLock.unlock()
        
        lastSyncSnapshotLock.lock()
        lastSyncSnapshots[normalizedPath] = currentSnapshots
        lastSyncSnapshotLock.unlock()
    }
}

// MARK: - FSEvents Callback Context

/// Context passed to FSEvents callback
private struct SyncEngineContext {
    weak var engine: SyncEngine?
    let mountPoint: String
}

// MARK: - FSEvents Callback Function

/// FSEvents callback function
private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    
    let context = info.assumingMemoryBound(to: SyncEngineContext.self).pointee
    
    guard let engine = context.engine else { return }
    
    // Get the paths from the callback
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
    
    // Handle the callback on the engine
    engine.handleFSEventsCallback(paths: paths, mountPoint: context.mountPoint)
}


// MARK: - Mock SyncEngine for Testing

/// Mock implementation of SyncEngineProtocol for unit testing
final class MockSyncEngine: SyncEngineProtocol {
    
    // MARK: - Test Configuration
    
    /// Events to emit during sync operations
    var eventsToEmit: [SyncEvent] = []
    
    /// Delay between emitting events (in seconds)
    var emitDelay: TimeInterval = 0.1
    
    /// Whether to simulate sync failure
    var simulateFailure: Bool = false
    
    /// Error to throw when simulating failure
    var failureError: SMBMounterError = .syncFailed(reason: "Simulated failure")
    
    // MARK: - State
    
    private var streamContinuation: AsyncStream<SyncEvent>.Continuation?
    private var _syncEvents: AsyncStream<SyncEvent>?
    private var _syncConfigurations: [String: SyncConfiguration] = [:]
    private let configLock = NSLock()
    
    /// Records of enableSync calls
    var enableSyncCalls: [(mountPoint: String, bidirectional: Bool)] = []
    
    /// Records of disableSync calls
    var disableSyncCalls: [String] = []
    
    /// Records of syncNow calls
    var syncNowCalls: [String] = []
    
    // MARK: - SyncEngineProtocol Properties
    
    var syncEvents: AsyncStream<SyncEvent> {
        if let existing = _syncEvents {
            return existing
        }
        
        let stream = AsyncStream<SyncEvent> { [weak self] continuation in
            self?.streamContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                // Stream terminated
            }
        }
        
        _syncEvents = stream
        return stream
    }
    
    var syncEnabledMountPoints: [String] {
        configLock.lock()
        defer { configLock.unlock() }
        return Array(_syncConfigurations.keys)
    }
    
    // MARK: - SyncEngineProtocol Implementation
    
    func enableSync(for mountPoint: String, bidirectional: Bool) throws {
        enableSyncCalls.append((mountPoint: mountPoint, bidirectional: bidirectional))
        
        if simulateFailure {
            throw failureError
        }
        
        let config = SyncConfiguration(
            mountPoint: mountPoint,
            bidirectional: bidirectional,
            enabledAt: Date(),
            lastSyncAt: nil
        )
        
        configLock.lock()
        _syncConfigurations[mountPoint] = config
        configLock.unlock()
        
        // Create stream if needed
        if _syncEvents == nil {
            _ = syncEvents
        }
        
        streamContinuation?.yield(.started(mountPoint))
    }
    
    func disableSync(for mountPoint: String) {
        disableSyncCalls.append(mountPoint)
        
        configLock.lock()
        _syncConfigurations.removeValue(forKey: mountPoint)
        configLock.unlock()
    }
    
    func syncNow(mountPoint: String) async throws {
        syncNowCalls.append(mountPoint)
        
        if simulateFailure {
            streamContinuation?.yield(.failed(mountPoint, failureError.localizedDescription))
            throw failureError
        }
        
        // Emit events
        streamContinuation?.yield(.started(mountPoint))
        
        for event in eventsToEmit {
            try? await Task.sleep(nanoseconds: UInt64(emitDelay * 1_000_000_000))
            streamContinuation?.yield(event)
        }
        
        streamContinuation?.yield(.completed(mountPoint))
    }
    
    func isSyncEnabled(for mountPoint: String) -> Bool {
        configLock.lock()
        defer { configLock.unlock() }
        return _syncConfigurations[mountPoint] != nil
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and configuration
    func reset() {
        streamContinuation?.finish()
        streamContinuation = nil
        _syncEvents = nil
        
        configLock.lock()
        _syncConfigurations.removeAll()
        configLock.unlock()
        
        eventsToEmit = []
        emitDelay = 0.1
        simulateFailure = false
        failureError = .syncFailed(reason: "Simulated failure")
        enableSyncCalls = []
        disableSyncCalls = []
        syncNowCalls = []
    }
    
    /// Manually emits an event (for testing real-time updates)
    func emitEvent(_ event: SyncEvent) {
        // Create stream if needed
        if _syncEvents == nil {
            _ = syncEvents
        }
        streamContinuation?.yield(event)
    }
    
    /// Simulates a sync started event
    func simulateSyncStarted(mountPoint: String) {
        emitEvent(.started(mountPoint))
    }
    
    /// Simulates a sync progress event
    func simulateSyncProgress(mountPoint: String, current: Int, total: Int) {
        emitEvent(.progress(mountPoint, current, total))
    }
    
    /// Simulates a sync completed event
    func simulateSyncCompleted(mountPoint: String) {
        emitEvent(.completed(mountPoint))
    }
    
    /// Simulates a sync failed event
    func simulateSyncFailed(mountPoint: String, error: String) {
        emitEvent(.failed(mountPoint, error))
    }
    
    /// Simulates a sync conflict event
    func simulateSyncConflict(mountPoint: String, conflict: ConflictInfo) {
        emitEvent(.conflict(mountPoint, conflict))
    }
    
    // MARK: - Conflict Detection and Resolution (Requirement 7.4)
    
    /// Mock pending conflicts storage
    private var _pendingConflicts: [String: [String: ConflictInfo]] = [:]
    private let conflictLock = NSLock()
    
    /// Mock conflict to return from detectConflict
    var mockConflict: ConflictInfo?
    
    /// Records of resolveConflict calls
    var resolveConflictCalls: [(conflict: ConflictInfo, resolution: ConflictResolution, mountPoint: String)] = []
    
    func detectConflict(localPath: String, remotePath: String) -> ConflictInfo? {
        return mockConflict
    }
    
    func resolveConflict(_ conflict: ConflictInfo, resolution: ConflictResolution, mountPoint: String) async throws {
        resolveConflictCalls.append((conflict: conflict, resolution: resolution, mountPoint: mountPoint))
        
        if simulateFailure {
            throw failureError
        }
        
        // Remove from pending conflicts
        let relativePath = conflict.fileName
        conflictLock.lock()
        _pendingConflicts[mountPoint]?.removeValue(forKey: relativePath)
        conflictLock.unlock()
    }
    
    func getPendingConflicts(for mountPoint: String) -> [ConflictInfo] {
        conflictLock.lock()
        defer { conflictLock.unlock() }
        return Array(_pendingConflicts[mountPoint]?.values ?? [:].values)
    }
    
    /// Adds a pending conflict for testing
    func addPendingConflict(_ conflict: ConflictInfo, for mountPoint: String) {
        conflictLock.lock()
        if _pendingConflicts[mountPoint] == nil {
            _pendingConflicts[mountPoint] = [:]
        }
        _pendingConflicts[mountPoint]?[conflict.fileName] = conflict
        conflictLock.unlock()
    }
    
    /// Clears all pending conflicts
    func clearPendingConflicts() {
        conflictLock.lock()
        _pendingConflicts.removeAll()
        conflictLock.unlock()
    }
}
