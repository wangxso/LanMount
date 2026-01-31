//
//  NetFSAdapter.swift
//  LanMount
//
//  Adapter for NetFS framework to handle SMB mounting operations
//  Requirements: 1.1, 1.2, 1.3
//

import Foundation

// NetFS framework is only available when building with Xcode
// Use conditional compilation to allow SPM builds for testing
#if canImport(NetFS)
import NetFS
#endif

// MARK: - NetFSAdapterProtocol

/// Protocol defining the interface for NetFS mounting operations
/// This protocol allows for dependency injection and testing with mock implementations
protocol NetFSAdapterProtocol {
    /// Mounts an SMB share at the specified mount point
    /// - Parameters:
    ///   - url: The SMB URL to mount (format: smb://[username:password@]server/share)
    ///   - mountPoint: The local filesystem path where the share should be mounted
    ///   - username: Optional username for authentication
    ///   - password: Optional password for authentication
    /// - Returns: The actual mount point path where the share was mounted
    /// - Throws: `SMBMounterError` if the mount operation fails
    func mount(
        url: URL,
        at mountPoint: String,
        username: String?,
        password: String?
    ) async throws -> String
    
    /// Unmounts a volume at the specified mount point
    /// - Parameter mountPoint: The local filesystem path of the mounted volume
    /// - Throws: `SMBMounterError` if the unmount operation fails
    func unmount(mountPoint: String) async throws
    
    /// Checks if a path is currently a mount point
    /// - Parameter path: The filesystem path to check
    /// - Returns: true if the path is a mount point, false otherwise
    func isMountPoint(_ path: String) -> Bool
}

// MARK: - NetFSAdapter

/// Implementation of NetFSAdapterProtocol using macOS NetFS framework
/// Provides SMB mounting and unmounting capabilities using native macOS APIs
final class NetFSAdapter: NetFSAdapterProtocol {
    
    // MARK: - Constants
    
    /// Default timeout for mount operations in seconds
    private static let defaultMountTimeout: TimeInterval = 30.0
    
    /// Default SMB port
    private static let defaultSMBPort = 445
    
    // MARK: - Properties
    
    /// File manager for filesystem operations
    private let fileManager: FileManager
    
    // MARK: - Initialization
    
    /// Creates a new NetFSAdapter instance
    /// - Parameter fileManager: The file manager to use (defaults to FileManager.default)
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // MARK: - NetFSAdapterProtocol Implementation
    
    func mount(
        url: URL,
        at mountPoint: String,
        username: String?,
        password: String?
    ) async throws -> String {
        // Validate the URL scheme
        guard url.scheme?.lowercased() == "smb" else {
            throw SMBMounterError.invalidURL(url: url.absoluteString)
        }
        
        // Validate the URL has a host
        guard let host = url.host, !host.isEmpty else {
            throw SMBMounterError.invalidURL(url: url.absoluteString)
        }
        
        // Validate the URL has a path (share name)
        let sharePath = url.path
        guard !sharePath.isEmpty && sharePath != "/" else {
            throw SMBMounterError.invalidURL(url: url.absoluteString)
        }
        
        // Prepare the mount point
        let actualMountPoint = try prepareMountPoint(mountPoint)
        
        // Perform the mount operation with credentials
        return try await performMount(url: url, mountPoint: actualMountPoint, username: username, password: password)
    }
    
    func unmount(mountPoint: String) async throws {
        // Verify the mount point exists
        guard fileManager.fileExists(atPath: mountPoint) else {
            throw SMBMounterError.notMounted(mountPoint: mountPoint)
        }
        
        // Verify it's actually a mount point
        guard isMountPoint(mountPoint) else {
            throw SMBMounterError.notMounted(mountPoint: mountPoint)
        }
        
        // Try to unmount using the system call
        let result = Darwin.unmount(mountPoint, MNT_FORCE)
        
        if result != 0 {
            let errorCode = errno
            
            // If system unmount fails, try using diskutil as fallback
            let diskutilResult = try await unmountWithDiskutil(mountPoint: mountPoint)
            
            if !diskutilResult {
                throw SMBMounterError.unmountFailed(
                    mountPoint: mountPoint,
                    reason: "System error code: \(errorCode)"
                )
            }
        }
        
        // Clean up the mount point directory if it's empty
        try? cleanupMountPoint(mountPoint)
    }
    
    func isMountPoint(_ path: String) -> Bool {
        var statInfo = statfs()
        
        guard statfs(path, &statInfo) == 0 else {
            return false
        }
        
        // Get the mount point from statfs
        let mountPointFromStat = withUnsafePointer(to: &statInfo.f_mntonname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        
        // Normalize paths for comparison
        let normalizedPath = (path as NSString).standardizingPath
        let normalizedMountPoint = (mountPointFromStat as NSString).standardizingPath
        
        // The path is a mount point if it matches the mount point from statfs
        return normalizedPath == normalizedMountPoint
    }
    
    // MARK: - Private Methods
    
    /// Prepares the mount point directory
    /// - Parameter mountPoint: The desired mount point path
    /// - Returns: The actual mount point path to use
    /// - Throws: `SMBMounterError` if preparation fails
    private func prepareMountPoint(_ mountPoint: String) throws -> String {
        let path = (mountPoint as NSString).standardizingPath
        
        // Check if the path already exists
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            // If it's a directory and it's a mount point, it's already mounted
            if isDirectory.boolValue && isMountPoint(path) {
                throw SMBMounterError.mountPointExists(path: path)
            }
            
            // If it's a directory and empty, we can use it
            if isDirectory.boolValue {
                let contents = try? fileManager.contentsOfDirectory(atPath: path)
                if contents?.isEmpty == true {
                    return path
                }
                // Directory exists and is not empty
                throw SMBMounterError.mountPointExists(path: path)
            }
            
            // It's a file, not a directory
            throw SMBMounterError.mountPointCreationFailed(path: path)
        }
        
        // For /Volumes paths, let NetFS handle the mount point creation
        // NetFS will automatically create the mount point directory
        if path.hasPrefix("/Volumes/") {
            return path
        }
        
        // For custom paths outside /Volumes, try to create the directory
        do {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw SMBMounterError.mountPointCreationFailed(path: path)
        }
        
        return path
    }
    
    /// Builds the mount URL with optional credentials
    /// - Parameters:
    ///   - baseURL: The base SMB URL
    ///   - username: Optional username
    ///   - password: Optional password
    /// - Returns: The complete URL for mounting
    /// - Throws: `SMBMounterError` if URL construction fails
    private func buildMountURL(baseURL: URL, username: String?, password: String?) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw SMBMounterError.invalidURL(url: baseURL.absoluteString)
        }
        
        // Add credentials if provided
        if let username = username, !username.isEmpty {
            components.user = username
            
            if let password = password, !password.isEmpty {
                components.password = password
            }
        }
        
        guard let url = components.url else {
            throw SMBMounterError.invalidURL(url: baseURL.absoluteString)
        }
        
        return url
    }
    
    /// Performs the actual mount operation using NetFS
    /// - Parameters:
    ///   - url: The SMB URL to mount (without credentials)
    ///   - mountPoint: The local mount point path
    ///   - username: Optional username for authentication
    ///   - password: Optional password for authentication
    /// - Returns: The actual mount point path
    /// - Throws: `SMBMounterError` if mounting fails
    private func performMount(url: URL, mountPoint: String, username: String?, password: String?) async throws -> String {
        #if canImport(NetFS)
        // Log for debugging
        let hasUser = username != nil && !(username?.isEmpty ?? true)
        let hasPass = password != nil && !(password?.isEmpty ?? true)
        print("[NetFSAdapter] Mounting URL: \(url.absoluteString), hasUser: \(hasUser), hasPass: \(hasPass)")
        
        // Use synchronous mount wrapped in a Task to avoid blocking
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Open options - add authentication info
                let openOptions = NSMutableDictionary()
                if let username = username, !username.isEmpty {
                    openOptions[kNetFSUseAuthenticationInfoKey] = true
                    print("[NetFSAdapter] Set kNetFSUseAuthenticationInfoKey for user: \(username)")
                }
                
                // Mount options
                let mountOptions = NSMutableDictionary()
                mountOptions[kNetFSSoftMountKey] = true
                mountOptions[kNetFSAllowSubMountsKey] = true
                
                // Prepare mount points array
                var mountedDirs: Unmanaged<CFArray>?
                
                // Try mounting with credentials passed as separate parameters
                print("[NetFSAdapter] Attempting mount with separate credentials...")
                print("[NetFSAdapter] Mount point: \(mountPoint)")
                print("[NetFSAdapter] URL: \(url.absoluteString)")
                
                // Let NetFS choose the mount point by passing nil
                let status = NetFSMountURLSync(
                    url as CFURL,
                    nil,  // Let NetFS choose the mount point
                    username as CFString?,
                    password as CFString?,
                    openOptions as CFMutableDictionary,
                    mountOptions as CFMutableDictionary,
                    &mountedDirs
                )
                
                if status == 0 {
                    print("[NetFSAdapter] Mount succeeded!")
                    // Get the actual mount point
                    if let dirs = mountedDirs?.takeRetainedValue() as? [String],
                       let actualMountPoint = dirs.first {
                        continuation.resume(returning: actualMountPoint)
                    } else {
                        continuation.resume(returning: mountPoint)
                    }
                } else {
                    print("[NetFSAdapter] Mount failed with status: \(status) (errno: \(String(cString: strerror(status))))")
                    let error = self.mapNetFSError(status: status, url: url)
                    continuation.resume(throwing: error)
                }
            }
        }
        #else
        // NetFS framework not available (e.g., when building with SPM)
        // This code path is for testing purposes only
        throw SMBMounterError.mountOperationFailed(reason: "NetFS framework not available. Build with Xcode to enable mounting.")
        #endif
    }
    
    /// Maps NetFS error status to SMBMounterError
    /// - Parameters:
    ///   - status: The NetFS error status code
    ///   - url: The URL that was being mounted
    /// - Returns: An appropriate SMBMounterError
    private func mapNetFSError(status: Int32, url: URL) -> SMBMounterError {
        let server = url.host ?? "unknown"
        let share = url.lastPathComponent
        
        switch status {
        case ENOENT:
            return .shareNotFound(server: server, share: share)
            
        case EAUTH, EPERM:
            return .authenticationFailed(server: server, share: share)
            
        case ETIMEDOUT:
            return .mountTimeout(server: server)
            
        case ENETUNREACH, EHOSTUNREACH, ECONNREFUSED:
            return .networkUnreachable(server: server)
            
        case EACCES:
            return .permissionDenied(operation: "mount")
            
        case EEXIST:
            return .mountPointExists(path: url.path)
            
        default:
            return .mountOperationFailed(reason: "NetFS error code: \(status)")
        }
    }
    
    /// Attempts to unmount using diskutil command
    /// - Parameter mountPoint: The mount point to unmount
    /// - Returns: true if successful, false otherwise
    private func unmountWithDiskutil(mountPoint: String) async throws -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            process.arguments = ["unmount", "force", mountPoint]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Cleans up an empty mount point directory
    /// - Parameter mountPoint: The mount point path to clean up
    private func cleanupMountPoint(_ mountPoint: String) throws {
        // Only clean up if it's in /Volumes and is empty
        guard mountPoint.hasPrefix("/Volumes/") else { return }
        
        let contents = try? fileManager.contentsOfDirectory(atPath: mountPoint)
        if contents?.isEmpty == true {
            try fileManager.removeItem(atPath: mountPoint)
        }
    }
}

// MARK: - NetFSAdapter Extension for URL Building

extension NetFSAdapter {
    /// Builds an SMB URL from components
    /// - Parameters:
    ///   - server: The server address (hostname or IP)
    ///   - share: The share name
    ///   - username: Optional username
    ///   - password: Optional password
    /// - Returns: The constructed SMB URL
    /// - Throws: `SMBMounterError` if URL construction fails
    static func buildSMBURL(
        server: String,
        share: String,
        username: String? = nil,
        password: String? = nil
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = server
        components.path = "/\(share)"
        
        if let username = username, !username.isEmpty {
            components.user = username
            
            if let password = password, !password.isEmpty {
                components.password = password
            }
        }
        
        guard let url = components.url else {
            throw SMBMounterError.invalidURL(url: "smb://\(server)/\(share)")
        }
        
        return url
    }
    
    /// Parses an SMB URL string into components
    /// - Parameter urlString: The SMB URL string to parse
    /// - Returns: A tuple containing server, share, username, and password
    /// - Throws: `SMBMounterError` if parsing fails
    static func parseSMBURL(_ urlString: String) throws -> (server: String, share: String, username: String?, password: String?) {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "smb",
              let host = url.host, !host.isEmpty else {
            throw SMBMounterError.invalidURL(url: urlString)
        }
        
        // Extract share name from path
        let path = url.path
        guard !path.isEmpty && path != "/" else {
            throw SMBMounterError.invalidURL(url: urlString)
        }
        
        // Remove leading slash from path to get share name
        let share = String(path.dropFirst())
        
        return (
            server: host,
            share: share,
            username: url.user,
            password: url.password
        )
    }
}

// MARK: - Mock NetFSAdapter for Testing

/// Mock implementation of NetFSAdapterProtocol for unit testing
final class MockNetFSAdapter: NetFSAdapterProtocol {
    
    // MARK: - Test Configuration
    
    /// Result to return from mount operations
    var mountResult: Result<String, SMBMounterError> = .success("/Volumes/test")
    
    /// Result to return from unmount operations
    var unmountResult: Result<Void, SMBMounterError> = .success(())
    
    /// Paths that should be reported as mount points
    var mountedPaths: Set<String> = []
    
    /// Records of mount calls for verification
    var mountCalls: [(url: URL, mountPoint: String, username: String?, password: String?)] = []
    
    /// Records of unmount calls for verification
    var unmountCalls: [String] = []
    
    // MARK: - NetFSAdapterProtocol Implementation
    
    func mount(
        url: URL,
        at mountPoint: String,
        username: String?,
        password: String?
    ) async throws -> String {
        mountCalls.append((url: url, mountPoint: mountPoint, username: username, password: password))
        
        switch mountResult {
        case .success(let path):
            mountedPaths.insert(path)
            return path
        case .failure(let error):
            throw error
        }
    }
    
    func unmount(mountPoint: String) async throws {
        unmountCalls.append(mountPoint)
        
        switch unmountResult {
        case .success:
            mountedPaths.remove(mountPoint)
        case .failure(let error):
            throw error
        }
    }
    
    func isMountPoint(_ path: String) -> Bool {
        return mountedPaths.contains(path)
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and configuration
    func reset() {
        mountResult = .success("/Volumes/test")
        unmountResult = .success(())
        mountedPaths = []
        mountCalls = []
        unmountCalls = []
    }
}
