//
//  MountManager.swift
//  LanMount
//
//  Manages SMB mount and unmount operations, coordinating between NetFS adapter and credential manager
//  Requirements: 1.1, 1.2, 1.3, 1.4, 1.5
//

import Foundation

// MARK: - MountManagerProtocol

/// Protocol defining the interface for SMB mount management operations
/// Coordinates between NetFS adapter and credential manager to provide a high-level mounting API
protocol MountManagerProtocol {
    /// Mounts an SMB share at the specified mount point
    /// - Parameters:
    ///   - server: The SMB server address (hostname or IP)
    ///   - share: The name of the shared folder
    ///   - mountPoint: The local filesystem path where the share should be mounted
    ///   - credentials: Optional credentials for authentication
    /// - Returns: A MountResult indicating success or failure
    /// - Throws: `SMBMounterError` if the mount operation fails
    func mount(
        server: String,
        share: String,
        mountPoint: String,
        credentials: Credentials?
    ) async throws -> MountResult
    
    /// Unmounts an SMB share at the specified mount point
    /// - Parameter mountPoint: The local filesystem path of the mounted share
    /// - Throws: `SMBMounterError` if the unmount operation fails
    func unmount(mountPoint: String) async throws
    
    /// Gets all currently mounted SMB volumes
    /// - Returns: An array of MountedVolume objects representing mounted shares
    func getMountedVolumes() -> [MountedVolume]
    
    /// Checks if a mount point is currently mounted
    /// - Parameter mountPoint: The local filesystem path to check
    /// - Returns: true if the mount point is mounted, false otherwise
    func isMounted(mountPoint: String) -> Bool
    
    /// Gets the current mount status for a specific mount point
    /// - Parameter mountPoint: The local filesystem path to check
    /// - Returns: The current MountStatus
    func getStatus(for mountPoint: String) -> MountStatus
    
    /// Refreshes the status of all tracked mounts asynchronously with cancellation support
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    func refreshMountStatusesAsync() async
}

// MARK: - MountManager

/// Implementation of MountManagerProtocol that coordinates NetFS adapter and credential manager
/// Provides mount status tracking and volume management
final class MountManager: MountManagerProtocol {
    
    // MARK: - Properties
    
    /// NetFS adapter for low-level mount operations
    private let netfsAdapter: NetFSAdapterProtocol
    
    /// Credential manager for retrieving stored credentials
    private let credentialManager: CredentialManagerProtocol
    
    /// Finder integration for volume display optimization
    private let finderIntegration: FinderIntegrationProtocol
    
    /// File manager for filesystem operations
    private let fileManager: FileManager
    
    /// Dictionary tracking mount status for each mount point
    private var mountStatuses: [String: MountStatus] = [:]
    
    /// Lock for thread-safe access to mountStatuses
    private let statusLock = NSLock()
    
    /// Dictionary tracking active mount operations
    private var activeMounts: [String: MountedVolume] = [:]
    
    /// Lock for thread-safe access to activeMounts
    private let mountsLock = NSLock()
    
    // MARK: - Initialization
    
    /// Creates a new MountManager instance
    /// - Parameters:
    ///   - netfsAdapter: The NetFS adapter to use for mount operations (defaults to NetFSAdapter)
    ///   - credentialManager: The credential manager to use (defaults to CredentialManager)
    ///   - finderIntegration: The Finder integration to use (defaults to FinderIntegration)
    ///   - fileManager: The file manager to use (defaults to FileManager.default)
    init(
        netfsAdapter: NetFSAdapterProtocol = NetFSAdapter(),
        credentialManager: CredentialManagerProtocol = CredentialManager(),
        finderIntegration: FinderIntegrationProtocol = FinderIntegration(),
        fileManager: FileManager = .default
    ) {
        self.netfsAdapter = netfsAdapter
        self.credentialManager = credentialManager
        self.finderIntegration = finderIntegration
        self.fileManager = fileManager
    }
    
    // MARK: - MountManagerProtocol Implementation
    
    func mount(
        server: String,
        share: String,
        mountPoint: String,
        credentials: Credentials?
    ) async throws -> MountResult {
        // Validate inputs
        guard !server.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "server", reason: "Server address cannot be empty")
        }
        guard !share.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "share", reason: "Share name cannot be empty")
        }
        guard !mountPoint.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "mountPoint", reason: "Mount point cannot be empty")
        }
        
        // Normalize the mount point path
        let normalizedMountPoint = (mountPoint as NSString).standardizingPath
        
        // Update status to connecting
        updateStatus(.connecting, for: normalizedMountPoint)
        
        do {
            // Build the SMB URL
            let smbURL = try NetFSAdapter.buildSMBURL(server: server, share: share)
            
            // Get credentials - use provided credentials or try to retrieve from credential manager
            let effectiveCredentials = try resolveCredentials(
                provided: credentials,
                server: server,
                share: share
            )
            
            // Perform the mount operation
            let actualMountPoint = try await netfsAdapter.mount(
                url: smbURL,
                at: normalizedMountPoint,
                username: effectiveCredentials?.username,
                password: effectiveCredentials?.password
            )
            
            // Get volume information
            let volumeName = getVolumeName(at: actualMountPoint) ?? share
            let (bytesUsed, bytesTotal) = getVolumeSpace(at: actualMountPoint)
            
            // Create the mounted volume record
            let mountedVolume = MountedVolume(
                server: server,
                share: share,
                mountPoint: actualMountPoint,
                volumeName: volumeName,
                status: .connected,
                mountedAt: Date(),
                bytesUsed: bytesUsed,
                bytesTotal: bytesTotal
            )
            
            // Track the mounted volume
            trackMount(mountedVolume)
            
            // Update status to connected
            updateStatus(.connected, for: actualMountPoint)
            
            // Configure Finder integration for optimal volume display
            // Requirements: 5.1, 5.5 - Set custom icon and ensure sidebar visibility
            Task {
                do {
                    try await finderIntegration.configureVolume(at: actualMountPoint, volumeName: volumeName)
                } catch {
                    // Log but don't fail the mount - Finder integration is optional
                    print("[MountManager] Warning: Finder integration failed: \(error.localizedDescription)")
                }
            }
            
            return MountResult.success(mountPoint: actualMountPoint, volumeName: volumeName)
            
        } catch let error as SMBMounterError {
            // Update status to error
            updateStatus(.error(error.localizedDescription), for: normalizedMountPoint)
            throw error
            
        } catch {
            // Convert unknown errors to SMBMounterError
            let mountError = SMBMounterError.mountOperationFailed(reason: error.localizedDescription)
            updateStatus(.error(mountError.localizedDescription), for: normalizedMountPoint)
            throw mountError
        }
    }
    
    func unmount(mountPoint: String) async throws {
        // Normalize the mount point path
        let normalizedMountPoint = (mountPoint as NSString).standardizingPath
        
        // Check if the mount point is actually mounted
        guard isMounted(mountPoint: normalizedMountPoint) else {
            throw SMBMounterError.notMounted(mountPoint: normalizedMountPoint)
        }
        
        // Perform the unmount operation
        try await netfsAdapter.unmount(mountPoint: normalizedMountPoint)
        
        // Remove from tracked mounts
        untrackMount(normalizedMountPoint)
        
        // Update status to disconnected
        updateStatus(.disconnected, for: normalizedMountPoint)
        
        // Clean up the mount point directory if it's empty and in /Volumes
        cleanupMountPointIfNeeded(normalizedMountPoint)
    }
    
    func getMountedVolumes() -> [MountedVolume] {
        // Get all mounted volumes from /Volumes
        var volumes: [MountedVolume] = []
        
        let volumesPath = "/Volumes"
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: volumesPath) else {
            return volumes
        }
        
        for item in contents {
            let fullPath = (volumesPath as NSString).appendingPathComponent(item)
            
            // Check if it's a mount point
            guard netfsAdapter.isMountPoint(fullPath) else {
                continue
            }
            
            // Check if it's an SMB mount
            guard isSMBMount(at: fullPath) else {
                continue
            }
            
            // Check if we have a tracked mount for this path
            if let trackedVolume = getTrackedMount(fullPath) {
                // Update the tracked volume with current status
                var updatedVolume = trackedVolume
                updatedVolume.status = .connected
                let (bytesUsed, bytesTotal) = getVolumeSpace(at: fullPath)
                updatedVolume.bytesUsed = bytesUsed
                updatedVolume.bytesTotal = bytesTotal
                volumes.append(updatedVolume)
            } else {
                // Create a new volume entry from filesystem info
                if let volume = createVolumeFromPath(fullPath) {
                    volumes.append(volume)
                }
            }
        }
        
        return volumes
    }
    
    func isMounted(mountPoint: String) -> Bool {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        return netfsAdapter.isMountPoint(normalizedPath)
    }
    
    func getStatus(for mountPoint: String) -> MountStatus {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        statusLock.lock()
        defer { statusLock.unlock() }
        
        if let status = mountStatuses[normalizedPath] {
            return status
        }
        
        // If no tracked status, determine from filesystem
        if isMounted(mountPoint: normalizedPath) {
            return .connected
        }
        
        return .disconnected
    }
    
    // MARK: - Private Methods
    
    /// Resolves credentials for a mount operation
    /// - Parameters:
    ///   - provided: Credentials provided by the caller
    ///   - server: The server address
    ///   - share: The share name
    /// - Returns: The credentials to use, or nil for anonymous access
    private func resolveCredentials(
        provided: Credentials?,
        server: String,
        share: String
    ) throws -> Credentials? {
        // If credentials were provided, use them
        if let provided = provided {
            return provided
        }
        
        // Try to retrieve stored credentials
        do {
            return try credentialManager.getCredentials(server: server, share: share)
        } catch {
            // If retrieval fails (other than not found), log but continue with anonymous
            // The mount may still succeed with guest access
            return nil
        }
    }
    
    /// Updates the mount status for a mount point
    /// - Parameters:
    ///   - status: The new status
    ///   - mountPoint: The mount point path
    private func updateStatus(_ status: MountStatus, for mountPoint: String) {
        statusLock.lock()
        defer { statusLock.unlock() }
        
        mountStatuses[mountPoint] = status
    }
    
    /// Tracks a mounted volume
    /// - Parameter volume: The volume to track
    private func trackMount(_ volume: MountedVolume) {
        mountsLock.lock()
        defer { mountsLock.unlock() }
        
        activeMounts[volume.mountPoint] = volume
    }
    
    /// Removes a mount from tracking
    /// - Parameter mountPoint: The mount point to untrack
    private func untrackMount(_ mountPoint: String) {
        mountsLock.lock()
        defer { mountsLock.unlock() }
        
        activeMounts.removeValue(forKey: mountPoint)
    }
    
    /// Gets a tracked mount by path
    /// - Parameter mountPoint: The mount point path
    /// - Returns: The tracked MountedVolume, or nil if not tracked
    private func getTrackedMount(_ mountPoint: String) -> MountedVolume? {
        mountsLock.lock()
        defer { mountsLock.unlock() }
        
        return activeMounts[mountPoint]
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
            // Fall back to the last path component
            return (path as NSString).lastPathComponent
        }
    }
    
    /// Gets the space usage for a volume
    /// - Parameter path: The mount point path
    /// - Returns: A tuple of (bytesUsed, bytesTotal), or (-1, -1) if unavailable
    private func getVolumeSpace(at path: String) -> (Int64, Int64) {
        var statInfo = statfs()
        
        guard statfs(path, &statInfo) == 0 else {
            return (-1, -1)
        }
        
        let blockSize = Int64(statInfo.f_bsize)
        let totalBlocks = Int64(statInfo.f_blocks)
        let freeBlocks = Int64(statInfo.f_bfree)
        
        let bytesTotal = totalBlocks * blockSize
        let bytesUsed = (totalBlocks - freeBlocks) * blockSize
        
        return (bytesUsed, bytesTotal)
    }
    
    /// Checks if a mount point is an SMB mount
    /// - Parameter path: The mount point path
    /// - Returns: true if it's an SMB mount, false otherwise
    private func isSMBMount(at path: String) -> Bool {
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
        
        // SMB mounts typically show as "smbfs"
        return fsType.lowercased() == "smbfs"
    }
    
    /// Creates a MountedVolume from a filesystem path
    /// - Parameter path: The mount point path
    /// - Returns: A MountedVolume, or nil if creation fails
    private func createVolumeFromPath(_ path: String) -> MountedVolume? {
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
        // Format is typically: //server/share or //user@server/share
        let (server, share) = parseMountSource(mountSource)
        
        guard !server.isEmpty, !share.isEmpty else {
            return nil
        }
        
        let volumeName = getVolumeName(at: path) ?? share
        let (bytesUsed, bytesTotal) = getVolumeSpace(at: path)
        
        return MountedVolume(
            server: server,
            share: share,
            mountPoint: path,
            volumeName: volumeName,
            status: .connected,
            mountedAt: Date(), // We don't know the actual mount time
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
    
    /// Cleans up an empty mount point directory if appropriate
    /// - Parameter mountPoint: The mount point path
    private func cleanupMountPointIfNeeded(_ mountPoint: String) {
        // Only clean up directories in /Volumes
        guard mountPoint.hasPrefix("/Volumes/") else {
            return
        }
        
        // Check if directory is empty
        guard let contents = try? fileManager.contentsOfDirectory(atPath: mountPoint),
              contents.isEmpty else {
            return
        }
        
        // Remove the empty directory
        try? fileManager.removeItem(atPath: mountPoint)
    }
}

// MARK: - Auto-Mount Result

/// Result of an individual auto-mount operation
struct AutoMountResult: Equatable {
    /// The configuration that was attempted
    let configuration: MountConfiguration
    /// Whether the mount succeeded
    let success: Bool
    /// The mount point if successful
    let mountPoint: String?
    /// Error message if failed
    let errorMessage: String?
    
    /// Creates a successful auto-mount result
    static func success(config: MountConfiguration, mountPoint: String) -> AutoMountResult {
        return AutoMountResult(
            configuration: config,
            success: true,
            mountPoint: mountPoint,
            errorMessage: nil
        )
    }
    
    /// Creates a failed auto-mount result
    static func failure(config: MountConfiguration, error: String) -> AutoMountResult {
        return AutoMountResult(
            configuration: config,
            success: false,
            mountPoint: nil,
            errorMessage: error
        )
    }
}

/// Summary of all auto-mount operations
struct AutoMountSummary {
    /// Total number of configurations attempted
    let totalConfigurations: Int
    /// Number of successful mounts
    let successCount: Int
    /// Number of failed mounts
    let failureCount: Int
    /// Individual results for each configuration
    let results: [AutoMountResult]
    /// Timestamp when auto-mount was performed
    let timestamp: Date
    
    /// Whether all mounts succeeded
    var allSucceeded: Bool {
        return failureCount == 0 && totalConfigurations > 0
    }
    
    /// Whether any mounts succeeded
    var anySucceeded: Bool {
        return successCount > 0
    }
    
    /// Returns only the failed results
    var failedResults: [AutoMountResult] {
        return results.filter { !$0.success }
    }
    
    /// Returns only the successful results
    var successfulResults: [AutoMountResult] {
        return results.filter { $0.success }
    }
}

// MARK: - Concurrent Mount Configuration

/// Configuration for concurrent mount operations
/// Requirements: 11.1, 11.2 - Performance and resource management
enum ConcurrentMountConfig {
    /// Maximum number of concurrent mount operations to prevent resource exhaustion
    /// Requirements: 11.5 - Support at least 10 simultaneous mounts
    static let maxConcurrentMounts = 4
    
    /// Timeout for individual mount operations (in seconds)
    static let mountTimeout: TimeInterval = 30.0
}

// MARK: - MountManager Extension for Additional Operations

extension MountManager {
    /// Mounts an SMB share using a configuration with cancellation support
    /// - Parameters:
    ///   - config: The mount configuration
    ///   - credentials: Optional credentials (will use stored credentials if not provided)
    /// - Returns: A MountResult indicating success or failure
    /// - Throws: `CancellationError` if the task is cancelled
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    func mount(config: MountConfiguration, credentials: Credentials? = nil) async throws -> MountResult {
        // Check for cancellation before starting
        try Task.checkCancellation()
        
        return try await mount(
            server: config.server,
            share: config.share,
            mountPoint: config.mountPoint,
            credentials: credentials
        )
    }
    
    /// Remounts a previously mounted volume with cancellation support
    /// - Parameters:
    ///   - volume: The volume to remount
    ///   - credentials: Optional credentials
    /// - Returns: A MountResult indicating success or failure
    /// - Throws: `CancellationError` if the task is cancelled
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    func remount(_ volume: MountedVolume, credentials: Credentials? = nil) async throws -> MountResult {
        // Check for cancellation before starting
        try Task.checkCancellation()
        
        return try await mount(
            server: volume.server,
            share: volume.share,
            mountPoint: volume.mountPoint,
            credentials: credentials
        )
    }
    
    /// Unmounts all currently mounted SMB volumes concurrently
    /// - Returns: An array of mount points that failed to unmount
    /// Requirements: 11.1, 11.2 - Use TaskGroup for concurrent operations
    func unmountAll() async -> [String] {
        let volumes = getMountedVolumes()
        
        guard !volumes.isEmpty else {
            return []
        }
        
        // Use TaskGroup for concurrent unmount operations
        return await withTaskGroup(of: (String, Bool).self) { group in
            for volume in volumes {
                group.addTask {
                    do {
                        try await self.unmount(mountPoint: volume.mountPoint)
                        return (volume.mountPoint, true)
                    } catch {
                        return (volume.mountPoint, false)
                    }
                }
            }
            
            var failedUnmounts: [String] = []
            for await (mountPoint, success) in group {
                if !success {
                    failedUnmounts.append(mountPoint)
                }
            }
            
            return failedUnmounts
        }
    }
    
    /// Refreshes the status of all tracked mounts asynchronously
    /// Requirements: 11.1, 11.2 - Avoid blocking main thread
    func refreshMountStatuses() {
        mountsLock.lock()
        let mounts = Array(activeMounts.values)
        mountsLock.unlock()
        
        for mount in mounts {
            let isCurrentlyMounted = isMounted(mountPoint: mount.mountPoint)
            
            if isCurrentlyMounted {
                updateStatus(.connected, for: mount.mountPoint)
            } else {
                updateStatus(.disconnected, for: mount.mountPoint)
                untrackMount(mount.mountPoint)
            }
        }
    }
    
    /// Refreshes the status of all tracked mounts asynchronously with cancellation support
    /// Requirements: 11.1, 11.2 - Async operations with cancellation support
    func refreshMountStatusesAsync() async {
        // Check for cancellation
        guard !Task.isCancelled else { return }
        
        mountsLock.lock()
        let mounts = Array(activeMounts.values)
        mountsLock.unlock()
        
        for mount in mounts {
            // Check for cancellation in the loop
            guard !Task.isCancelled else { return }
            
            let isCurrentlyMounted = isMounted(mountPoint: mount.mountPoint)
            
            if isCurrentlyMounted {
                updateStatus(.connected, for: mount.mountPoint)
            } else {
                updateStatus(.disconnected, for: mount.mountPoint)
                untrackMount(mount.mountPoint)
            }
        }
    }
    
    /// Performs auto-mount for all configurations marked for auto-mount using concurrent operations
    /// - Parameter configurationStore: The configuration store to read auto-mount configurations from
    /// - Returns: A summary of all auto-mount operations
    /// - Note: This method uses TaskGroup for concurrent mounts with a limit to prevent resource exhaustion
    /// Requirements: 2.2, 2.3, 2.4, 2.5, 11.1, 11.2
    func performAutoMount(using configurationStore: ConfigurationStoreProtocol) async -> AutoMountSummary {
        let timestamp = Date()
        
        // Read auto-mount configurations
        let autoMountConfigs: [MountConfiguration]
        do {
            let allConfigs = try configurationStore.getAllMountConfigs()
            autoMountConfigs = allConfigs.filter { $0.autoMount }
            
            logAutoMountStart(configCount: autoMountConfigs.count)
        } catch {
            // Log the error and return empty summary
            logAutoMountError(message: "Failed to read auto-mount configurations: \(error.localizedDescription)")
            return AutoMountSummary(
                totalConfigurations: 0,
                successCount: 0,
                failureCount: 0,
                results: [],
                timestamp: timestamp
            )
        }
        
        // If no auto-mount configurations, return early
        guard !autoMountConfigs.isEmpty else {
            logAutoMountInfo(message: "No auto-mount configurations found")
            return AutoMountSummary(
                totalConfigurations: 0,
                successCount: 0,
                failureCount: 0,
                results: [],
                timestamp: timestamp
            )
        }
        
        // Separate already mounted configs from those that need mounting
        var alreadyMountedResults: [AutoMountResult] = []
        var configsToMount: [MountConfiguration] = []
        
        for config in autoMountConfigs {
            if isMounted(mountPoint: config.mountPoint) {
                logAutoMountInfo(message: "Skipping \(config.server)/\(config.share) - already mounted at \(config.mountPoint)")
                alreadyMountedResults.append(AutoMountResult.success(config: config, mountPoint: config.mountPoint))
            } else {
                configsToMount.append(config)
            }
        }
        
        // Use TaskGroup for concurrent mount operations with a limit
        // Requirements: 11.1, 11.2 - Use TaskGroup for concurrent operations
        // Requirements: 2.3, 2.4 - Process all configs, continue on failure
        let mountResults = await performConcurrentMounts(configs: configsToMount)
        
        // Combine results
        let allResults = alreadyMountedResults + mountResults
        
        // Calculate summary
        let successCount = allResults.filter { $0.success }.count
        let failureCount = allResults.filter { !$0.success }.count
        
        let summary = AutoMountSummary(
            totalConfigurations: autoMountConfigs.count,
            successCount: successCount,
            failureCount: failureCount,
            results: allResults,
            timestamp: timestamp
        )
        
        // Log final summary
        logAutoMountSummary(summary: summary)
        
        return summary
    }
    
    /// Performs concurrent mount operations with a limit on concurrency
    /// - Parameter configs: The configurations to mount
    /// - Returns: Array of mount results
    /// Requirements: 11.1, 11.2, 11.5 - Concurrent operations with resource management
    private func performConcurrentMounts(configs: [MountConfiguration]) async -> [AutoMountResult] {
        guard !configs.isEmpty else { return [] }
        
        // Use TaskGroup with limited concurrency
        return await withTaskGroup(of: AutoMountResult.self) { group in
            var results: [AutoMountResult] = []
            var activeTaskCount = 0
            var configIndex = 0
            
            // Add initial batch of tasks up to the concurrency limit
            while configIndex < configs.count && activeTaskCount < ConcurrentMountConfig.maxConcurrentMounts {
                let config = configs[configIndex]
                configIndex += 1
                activeTaskCount += 1
                
                group.addTask {
                    await self.mountConfigWithTimeout(config)
                }
            }
            
            // Process results and add new tasks as slots become available
            for await result in group {
                results.append(result)
                activeTaskCount -= 1
                
                // Add next task if there are more configs to process
                if configIndex < configs.count {
                    let config = configs[configIndex]
                    configIndex += 1
                    activeTaskCount += 1
                    
                    group.addTask {
                        await self.mountConfigWithTimeout(config)
                    }
                }
            }
            
            return results
        }
    }
    
    /// Mounts a configuration with timeout and cancellation support
    /// - Parameter config: The configuration to mount
    /// - Returns: The mount result
    /// Requirements: 11.1, 11.2 - Async operations with timeout and cancellation
    private func mountConfigWithTimeout(_ config: MountConfiguration) async -> AutoMountResult {
        logAutoMountInfo(message: "Auto-mounting \(config.server)/\(config.share) to \(config.mountPoint)")
        
        // Retrieve credentials from Keychain if rememberCredentials is enabled
        var credentials: Credentials? = nil
        if config.rememberCredentials {
            do {
                credentials = try credentialManager.getCredentials(server: config.server, share: config.share)
                if let creds = credentials {
                    // Log username prefix and password prefix for debugging (first 3 chars only for security)
                    let usernamePrefix = String(creds.username.prefix(3))
                    let passwordPrefix = String(creds.password.prefix(3))
                    logAutoMountInfo(message: "Retrieved stored credentials for \(config.server)/\(config.share) - user: \(usernamePrefix)*** pass: \(passwordPrefix)***")
                } else {
                    logAutoMountInfo(message: "No credentials found in Keychain for \(config.server)/\(config.share)")
                }
            } catch {
                logAutoMountInfo(message: "Failed to retrieve credentials for \(config.server)/\(config.share): \(error.localizedDescription)")
            }
        } else {
            logAutoMountInfo(message: "rememberCredentials is false for \(config.server)/\(config.share), skipping credential retrieval")
        }
        
        // Create a task with timeout
        let mountTask = Task {
            try await mount(config: config, credentials: credentials)
        }
        
        // Create a timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(ConcurrentMountConfig.mountTimeout * 1_000_000_000))
            mountTask.cancel()
        }
        
        do {
            // Check for cancellation
            try Task.checkCancellation()
            
            let mountResult = try await mountTask.value
            timeoutTask.cancel()
            
            if mountResult.success, let mountPoint = mountResult.mountPoint {
                logAutoMountSuccess(config: config, mountPoint: mountPoint)
                return AutoMountResult.success(config: config, mountPoint: mountPoint)
            } else {
                let errorMessage = mountResult.error?.localizedDescription ?? "Unknown error"
                logAutoMountFailure(config: config, error: errorMessage)
                return AutoMountResult.failure(config: config, error: errorMessage)
            }
        } catch is CancellationError {
            timeoutTask.cancel()
            let errorMessage = "Mount operation cancelled or timed out"
            logAutoMountFailure(config: config, error: errorMessage)
            return AutoMountResult.failure(config: config, error: errorMessage)
        } catch {
            timeoutTask.cancel()
            let errorMessage = error.localizedDescription
            logAutoMountFailure(config: config, error: errorMessage)
            return AutoMountResult.failure(config: config, error: errorMessage)
        }
    }
    
    // MARK: - Auto-Mount Logging Helpers
    
    /// Logs the start of auto-mount process
    private func logAutoMountStart(configCount: Int) {
        let message = "[AutoMount] Starting auto-mount process with \(configCount) configuration(s)"
        print(message) // TODO: Replace with proper Logger when implemented
    }
    
    /// Logs an auto-mount info message
    private func logAutoMountInfo(message: String) {
        let logMessage = "[AutoMount] [INFO] \(message)"
        print(logMessage) // TODO: Replace with proper Logger when implemented
    }
    
    /// Logs an auto-mount error
    private func logAutoMountError(message: String) {
        let logMessage = "[AutoMount] [ERROR] \(message)"
        print(logMessage) // TODO: Replace with proper Logger when implemented
    }
    
    /// Logs a successful auto-mount
    private func logAutoMountSuccess(config: MountConfiguration, mountPoint: String) {
        let message = "[AutoMount] [SUCCESS] Mounted \(config.server)/\(config.share) at \(mountPoint)"
        print(message) // TODO: Replace with proper Logger when implemented
    }
    
    /// Logs a failed auto-mount
    private func logAutoMountFailure(config: MountConfiguration, error: String) {
        let message = "[AutoMount] [FAILURE] Failed to mount \(config.server)/\(config.share): \(error)"
        print(message) // TODO: Replace with proper Logger when implemented
    }
    
    /// Logs the auto-mount summary
    private func logAutoMountSummary(summary: AutoMountSummary) {
        let message = "[AutoMount] [SUMMARY] Completed: \(summary.successCount)/\(summary.totalConfigurations) succeeded, \(summary.failureCount) failed"
        print(message) // TODO: Replace with proper Logger when implemented
        
        // Log details of failures
        for failedResult in summary.failedResults {
            let failMessage = "[AutoMount] [SUMMARY] Failed: \(failedResult.configuration.server)/\(failedResult.configuration.share) - \(failedResult.errorMessage ?? "Unknown error")"
            print(failMessage)
        }
    }
}

// MARK: - Mock MountManager for Testing

/// Mock implementation of MountManagerProtocol for unit testing
final class MockMountManager: MountManagerProtocol {
    
    // MARK: - Test Configuration
    
    /// Result to return from mount operations
    var mountResult: Result<MountResult, SMBMounterError> = .success(
        MountResult.success(mountPoint: "/Volumes/test", volumeName: "test")
    )
    
    /// Result to return from unmount operations
    var unmountResult: Result<Void, SMBMounterError> = .success(())
    
    /// Volumes to return from getMountedVolumes
    var mountedVolumes: [MountedVolume] = []
    
    /// Mount points that should be reported as mounted
    var mountedPaths: Set<String> = []
    
    /// Status to return for each mount point
    var statuses: [String: MountStatus] = [:]
    
    /// Records of mount calls for verification
    var mountCalls: [(server: String, share: String, mountPoint: String, credentials: Credentials?)] = []
    
    /// Records of unmount calls for verification
    var unmountCalls: [String] = []
    
    // MARK: - MountManagerProtocol Implementation
    
    func mount(
        server: String,
        share: String,
        mountPoint: String,
        credentials: Credentials?
    ) async throws -> MountResult {
        mountCalls.append((server: server, share: share, mountPoint: mountPoint, credentials: credentials))
        
        switch mountResult {
        case .success(let result):
            if let mp = result.mountPoint {
                mountedPaths.insert(mp)
                statuses[mp] = .connected
            }
            return result
        case .failure(let error):
            statuses[mountPoint] = .error(error.localizedDescription)
            throw error
        }
    }
    
    func unmount(mountPoint: String) async throws {
        unmountCalls.append(mountPoint)
        
        switch unmountResult {
        case .success:
            mountedPaths.remove(mountPoint)
            statuses[mountPoint] = .disconnected
        case .failure(let error):
            throw error
        }
    }
    
    func getMountedVolumes() -> [MountedVolume] {
        return mountedVolumes
    }
    
    func isMounted(mountPoint: String) -> Bool {
        return mountedPaths.contains(mountPoint)
    }
    
    func getStatus(for mountPoint: String) -> MountStatus {
        return statuses[mountPoint] ?? .disconnected
    }
    
    func refreshMountStatusesAsync() async {
        // Mock implementation - no-op for testing
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and configuration
    func reset() {
        mountResult = .success(MountResult.success(mountPoint: "/Volumes/test", volumeName: "test"))
        unmountResult = .success(())
        mountedVolumes = []
        mountedPaths = []
        statuses = [:]
        mountCalls = []
        unmountCalls = []
    }
    
    /// Simulates a mount becoming disconnected
    func simulateDisconnect(mountPoint: String) {
        mountedPaths.remove(mountPoint)
        statuses[mountPoint] = .disconnected
    }
    
    /// Simulates a mount error
    func simulateError(mountPoint: String, error: String) {
        statuses[mountPoint] = .error(error)
    }
    
    /// Performs auto-mount for all configurations marked for auto-mount
    /// - Parameter configurationStore: The configuration store to read auto-mount configurations from
    /// - Returns: A summary of all auto-mount operations
    func performAutoMount(using configurationStore: ConfigurationStoreProtocol) async -> AutoMountSummary {
        let timestamp = Date()
        var results: [AutoMountResult] = []
        
        // Read auto-mount configurations
        let autoMountConfigs: [MountConfiguration]
        do {
            let allConfigs = try configurationStore.getAllMountConfigs()
            autoMountConfigs = allConfigs.filter { $0.autoMount }
        } catch {
            return AutoMountSummary(
                totalConfigurations: 0,
                successCount: 0,
                failureCount: 0,
                results: [],
                timestamp: timestamp
            )
        }
        
        // Process each auto-mount configuration
        for config in autoMountConfigs {
            // Skip if already mounted
            if isMounted(mountPoint: config.mountPoint) {
                results.append(AutoMountResult.success(config: config, mountPoint: config.mountPoint))
                continue
            }
            
            // Attempt to mount
            do {
                let mountResult = try await mount(
                    server: config.server,
                    share: config.share,
                    mountPoint: config.mountPoint,
                    credentials: nil
                )
                
                if mountResult.success, let mountPoint = mountResult.mountPoint {
                    results.append(AutoMountResult.success(config: config, mountPoint: mountPoint))
                } else {
                    let errorMessage = mountResult.error?.localizedDescription ?? "Unknown error"
                    results.append(AutoMountResult.failure(config: config, error: errorMessage))
                }
            } catch {
                results.append(AutoMountResult.failure(config: config, error: error.localizedDescription))
            }
        }
        
        let successCount = results.filter { $0.success }.count
        let failureCount = results.filter { !$0.success }.count
        
        return AutoMountSummary(
            totalConfigurations: autoMountConfigs.count,
            successCount: successCount,
            failureCount: failureCount,
            results: results,
            timestamp: timestamp
        )
    }
}
