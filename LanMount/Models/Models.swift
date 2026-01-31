//
//  Models.swift
//  LanMount
//
//  Core data models for the SMB Mounter application
//  Requirements: 12.1, 12.2, 12.3, 12.4, 12.5
//

import Foundation
import SwiftUI

// MARK: - MountStatus

/// Represents the current status of a mounted SMB share
enum MountStatus: Equatable, Codable {
    /// The share is successfully connected and accessible
    case connected
    /// The share has been disconnected
    case disconnected
    /// The share is currently being connected
    case connecting
    /// An error occurred with the mount
    case error(String)
    
    // Custom Codable implementation for associated value
    private enum CodingKeys: String, CodingKey {
        case type, errorMessage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "connected":
            self = .connected
        case "disconnected":
            self = .disconnected
        case "connecting":
            self = .connecting
        case "error":
            let message = try container.decode(String.self, forKey: .errorMessage)
            self = .error(message)
        default:
            self = .disconnected
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .connected:
            try container.encode("connected", forKey: .type)
        case .disconnected:
            try container.encode("disconnected", forKey: .type)
        case .connecting:
            try container.encode("connecting", forKey: .type)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .errorMessage)
        }
    }
    
    /// Returns the color associated with this mount status
    /// - connected: green (successful connection)
    /// - connecting: yellow (in progress)
    /// - error: red (failure state)
    /// - disconnected: gray (inactive)
    /// Requirements: 4.4
    var color: Color {
        switch self {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }
}

// MARK: - MountedVolume

/// Represents a mounted SMB volume with its current state and metadata
struct MountedVolume: Identifiable, Equatable, Codable {
    /// Unique identifier for the mounted volume
    let id: UUID
    /// SMB server address (hostname or IP)
    let server: String
    /// Name of the shared folder on the server
    let share: String
    /// Local filesystem path where the share is mounted
    let mountPoint: String
    /// Display name of the volume in Finder
    let volumeName: String
    /// Current connection status
    var status: MountStatus
    /// Timestamp when the volume was mounted
    let mountedAt: Date
    /// Bytes used on the volume (-1 if unknown)
    var bytesUsed: Int64
    /// Total bytes available on the volume (-1 if unknown)
    var bytesTotal: Int64
    
    /// Creates a new MountedVolume instance
    init(
        id: UUID = UUID(),
        server: String,
        share: String,
        mountPoint: String,
        volumeName: String? = nil,
        status: MountStatus = .disconnected,
        mountedAt: Date = Date(),
        bytesUsed: Int64 = -1,
        bytesTotal: Int64 = -1
    ) {
        self.id = id
        self.server = server
        self.share = share
        self.mountPoint = mountPoint
        self.volumeName = volumeName ?? share
        self.status = status
        self.mountedAt = mountedAt
        self.bytesUsed = bytesUsed
        self.bytesTotal = bytesTotal
    }
    
    /// Returns the SMB URL for this volume
    var smbURL: String {
        return "smb://\(server)/\(share)"
    }
    
    /// Returns the percentage of space used (0-100), or nil if unknown
    var usagePercentage: Double? {
        guard bytesTotal > 0, bytesUsed >= 0 else { return nil }
        return Double(bytesUsed) / Double(bytesTotal) * 100.0
    }
}

// MARK: - Credentials

/// Stores authentication credentials for SMB connections
struct Credentials: Equatable {
    /// Username for authentication
    let username: String
    /// Password for authentication (should be stored securely in Keychain)
    let password: String
    /// Optional Windows domain for domain authentication
    let domain: String?
    
    /// Creates new credentials
    init(username: String, password: String, domain: String? = nil) {
        self.username = username
        self.password = password
        self.domain = domain
    }
    
    /// Returns the full username including domain if specified
    var fullUsername: String {
        if let domain = domain, !domain.isEmpty {
            return "\(domain)\\\(username)"
        }
        return username
    }
}

// MARK: - MountConfigurationValidationError

/// Validation errors for MountConfiguration
/// Requirements: 5.3
enum MountConfigurationValidationError: Equatable, LocalizedError {
    /// Server field is empty
    case serverEmpty
    /// Share field is empty
    case shareEmpty
    /// Server format is invalid (contains invalid characters or format)
    case serverFormatInvalid(String)
    
    var errorDescription: String? {
        switch self {
        case .serverEmpty:
            return "Server address cannot be empty"
        case .shareEmpty:
            return "Share name cannot be empty"
        case .serverFormatInvalid(let reason):
            return "Invalid server format: \(reason)"
        }
    }
}

// MARK: - MountConfiguration

/// Persistent configuration for an SMB mount
struct MountConfiguration: Codable, Identifiable, Equatable {
    /// Unique identifier for the configuration
    let id: UUID
    /// SMB server address (hostname or IP)
    let server: String
    /// Name of the shared folder on the server
    let share: String
    /// Local filesystem path where the share should be mounted
    let mountPoint: String
    /// Whether to automatically mount this share on login
    var autoMount: Bool
    /// Whether credentials are stored in Keychain
    var rememberCredentials: Bool
    /// Whether file synchronization is enabled for this mount
    var syncEnabled: Bool
    /// Timestamp when the configuration was created
    let createdAt: Date
    /// Timestamp when the configuration was last modified
    var lastModified: Date
    
    /// Creates a new mount configuration
    init(
        id: UUID = UUID(),
        server: String,
        share: String,
        mountPoint: String? = nil,
        autoMount: Bool = false,
        rememberCredentials: Bool = false,
        syncEnabled: Bool = false,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.server = server
        self.share = share
        self.mountPoint = mountPoint ?? "/Volumes/\(share)"
        self.autoMount = autoMount
        self.rememberCredentials = rememberCredentials
        self.syncEnabled = syncEnabled
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
    
    /// Returns the SMB URL for this configuration
    var smbURL: String {
        return "smb://\(server)/\(share)"
    }
    
    /// Returns a unique identifier string for Keychain storage
    var keychainIdentifier: String {
        return "\(server)/\(share)"
    }
    
    // MARK: - Validation
    
    /// Validates the mount configuration and returns a list of validation errors
    /// Returns an empty array if all required fields are valid
    /// Requirements: 5.3
    func validate() -> [MountConfigurationValidationError] {
        var errors: [MountConfigurationValidationError] = []
        
        // Check if server is empty
        let trimmedServer = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedServer.isEmpty {
            errors.append(.serverEmpty)
        } else {
            // Validate server format
            if let formatError = validateServerFormat(trimmedServer) {
                errors.append(formatError)
            }
        }
        
        // Check if share is empty
        let trimmedShare = share.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedShare.isEmpty {
            errors.append(.shareEmpty)
        }
        
        return errors
    }
    
    /// Validates the server format
    /// Returns a validation error if the format is invalid, nil otherwise
    private func validateServerFormat(_ server: String) -> MountConfigurationValidationError? {
        // Check for invalid characters in server address
        // Server can be a hostname or IP address
        
        // Check if it looks like an IP address
        if isValidIPAddress(server) {
            return nil
        }
        
        // Check if it's a valid hostname
        if isValidHostname(server) {
            return nil
        }
        
        return .serverFormatInvalid("must be a valid hostname or IP address")
    }
    
    /// Checks if the string is a valid IPv4 or IPv6 address
    private func isValidIPAddress(_ string: String) -> Bool {
        // IPv4 validation
        let ipv4Pattern = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        if let regex = try? NSRegularExpression(pattern: ipv4Pattern, options: []),
           regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)) != nil {
            return true
        }
        
        // IPv6 validation (simplified - accepts standard IPv6 format)
        let ipv6Pattern = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::$|^([0-9a-fA-F]{1,4}:){1,7}:$|^:(:([0-9a-fA-F]{1,4})){1,7}$|^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$"
        if let regex = try? NSRegularExpression(pattern: ipv6Pattern, options: []),
           regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)) != nil {
            return true
        }
        
        return false
    }
    
    /// Checks if the string is a valid hostname
    private func isValidHostname(_ string: String) -> Bool {
        // Hostname validation rules:
        // - Can contain alphanumeric characters, hyphens, and dots
        // - Each label (part between dots) must start and end with alphanumeric
        // - Each label must be 1-63 characters
        // - Total length must be <= 253 characters
        
        guard string.count <= 253 else { return false }
        
        // Split by dots and validate each label
        let labels = string.split(separator: ".", omittingEmptySubsequences: false)
        
        // Must have at least one label
        guard !labels.isEmpty else { return false }
        
        // Check for empty labels (consecutive dots or leading/trailing dots)
        for label in labels {
            guard !label.isEmpty else { return false }
            guard label.count <= 63 else { return false }
            
            // Label must start and end with alphanumeric
            guard let first = label.first, first.isLetter || first.isNumber else { return false }
            guard let last = label.last, last.isLetter || last.isNumber else { return false }
            
            // Label can only contain alphanumeric and hyphens
            for char in label {
                if !char.isLetter && !char.isNumber && char != "-" {
                    return false
                }
            }
        }
        
        return true
    }
}

// MARK: - DiscoveredService

/// Represents an SMB service discovered via Bonjour/mDNS
struct DiscoveredService: Identifiable, Equatable, Hashable {
    /// Unique identifier for the discovered service
    let id: UUID
    /// Display name of the service
    let name: String
    /// Hostname of the server
    let hostname: String
    /// IP address of the server
    let ipAddress: String
    /// Port number (typically 445 for SMB)
    let port: Int
    /// List of available shares on this server (may be empty if not yet queried)
    var shares: [String]
    /// Timestamp when the service was discovered
    let discoveredAt: Date
    
    /// Creates a new discovered service
    init(
        id: UUID = UUID(),
        name: String,
        hostname: String,
        ipAddress: String,
        port: Int = 445,
        shares: [String] = [],
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.ipAddress = ipAddress
        self.port = port
        self.shares = shares
        self.discoveredAt = discoveredAt
    }
    
    /// Returns the SMB URL for this service (without share name)
    var smbURL: String {
        return "smb://\(ipAddress)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - MountResult

/// Result of a mount operation
struct MountResult: Equatable {
    /// Whether the mount operation succeeded
    let success: Bool
    /// The mount point path if successful
    let mountPoint: String?
    /// The volume name if successful
    let volumeName: String?
    /// Error that occurred if unsuccessful
    let error: SMBMounterError?
    
    /// Creates a successful mount result
    static func success(mountPoint: String, volumeName: String) -> MountResult {
        return MountResult(
            success: true,
            mountPoint: mountPoint,
            volumeName: volumeName,
            error: nil
        )
    }
    
    /// Creates a failed mount result
    static func failure(_ error: SMBMounterError) -> MountResult {
        return MountResult(
            success: false,
            mountPoint: nil,
            volumeName: nil,
            error: error
        )
    }
}

// MARK: - ConflictInfo

/// Information about a file synchronization conflict
struct ConflictInfo: Identifiable, Equatable {
    /// Unique identifier for the conflict
    let id: UUID
    /// Path to the conflicting file
    let filePath: String
    /// Timestamp when the local file was last modified
    let localModifiedAt: Date
    /// Timestamp when the remote file was last modified
    let remoteModifiedAt: Date
    /// Size of the local file in bytes
    let localSize: Int64
    /// Size of the remote file in bytes
    let remoteSize: Int64
    
    /// Creates a new conflict info
    init(
        id: UUID = UUID(),
        filePath: String,
        localModifiedAt: Date,
        remoteModifiedAt: Date,
        localSize: Int64,
        remoteSize: Int64
    ) {
        self.id = id
        self.filePath = filePath
        self.localModifiedAt = localModifiedAt
        self.remoteModifiedAt = remoteModifiedAt
        self.localSize = localSize
        self.remoteSize = remoteSize
    }
    
    /// Returns the filename from the file path
    var fileName: String {
        return (filePath as NSString).lastPathComponent
    }
    
    /// Returns the time difference between local and remote modifications
    var timeDifference: TimeInterval {
        return abs(localModifiedAt.timeIntervalSince(remoteModifiedAt))
    }
    
    /// Returns the size difference between local and remote files
    var sizeDifference: Int64 {
        return abs(localSize - remoteSize)
    }
}

// MARK: - VolumeEvent

/// Events related to volume state changes
enum VolumeEvent: Equatable {
    /// A volume was mounted
    case mounted(MountedVolume)
    /// A volume was unmounted (includes mount point path)
    case unmounted(String)
    /// A volume was unexpectedly disconnected (includes mount point path)
    case disconnected(String)
    /// A volume is attempting to reconnect (includes mount point path)
    case reconnecting(String)
}

// MARK: - SyncEvent

/// Events related to file synchronization
enum SyncEvent: Equatable {
    /// Synchronization started for a mount point
    case started(String)
    /// Synchronization progress update (mount point, current file index, total files)
    case progress(String, Int, Int)
    /// Synchronization completed successfully
    case completed(String)
    /// Synchronization failed with an error
    case failed(String, String)
    /// A synchronization conflict was detected
    case conflict(String, ConflictInfo)
}

// MARK: - AppSettings

/// Application-wide settings
struct AppSettings: Codable, Equatable {
    /// Whether to launch the app at login
    var launchAtLogin: Bool
    /// Whether to automatically reconnect disconnected mounts
    var autoReconnect: Bool
    /// Whether to show system notifications
    var notificationsEnabled: Bool
    /// Interval between network scans in seconds
    var scanInterval: TimeInterval
    /// Current log level
    var logLevel: LogLevel
    
    /// Default settings
    static let `default` = AppSettings(
        launchAtLogin: false,
        autoReconnect: true,
        notificationsEnabled: true,
        scanInterval: 300, // 5 minutes
        logLevel: .info
    )
}

// MARK: - LogLevel

/// Log levels for the application
enum LogLevel: String, Codable, CaseIterable {
    case debug = "Debug"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    
    /// Numeric value for comparison
    var level: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
}

// MARK: - ConflictResolution

/// Options for resolving synchronization conflicts
enum ConflictResolution {
    /// Keep the local version of the file
    case keepLocal
    /// Keep the remote version of the file
    case keepRemote
    /// Keep both versions (rename one)
    case keepBoth
    /// Skip this file
    case skip
}


// MARK: - ConfigurationExport

/// 配置导出数据结构
/// Used for exporting and importing SMB mount configurations in JSON format
/// Note: Credentials are NOT exported for security reasons
/// Requirements: 5.5
struct ConfigurationExport: Codable, Equatable {
    /// Version of the export format for compatibility checking
    let version: String
    /// Timestamp when the export was created
    let exportedAt: Date
    /// Array of exported configurations (without credentials)
    let configurations: [ExportedConfiguration]
    
    /// Current export format version
    static let currentVersion = "1.0"
    
    /// Creates a new ConfigurationExport from an array of MountConfigurations
    /// - Parameter configurations: The configurations to export
    /// - Returns: A ConfigurationExport containing the exported configurations
    init(configurations: [MountConfiguration]) {
        self.version = Self.currentVersion
        self.exportedAt = Date()
        self.configurations = configurations.map { ExportedConfiguration(from: $0) }
    }
    
    /// Creates a ConfigurationExport with explicit values
    /// - Parameters:
    ///   - version: The export format version
    ///   - exportedAt: The export timestamp
    ///   - configurations: The exported configurations
    init(version: String, exportedAt: Date, configurations: [ExportedConfiguration]) {
        self.version = version
        self.exportedAt = exportedAt
        self.configurations = configurations
    }
    
    /// Encodes the export to JSON data
    /// - Returns: JSON data representation of the export
    /// - Throws: Encoding errors if serialization fails
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    
    /// Creates a ConfigurationExport from JSON data
    /// - Parameter data: JSON data to decode
    /// - Returns: A ConfigurationExport instance
    /// - Throws: Decoding errors if deserialization fails
    static func fromJSON(_ data: Data) throws -> ConfigurationExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ConfigurationExport.self, from: data)
    }
    
    /// Converts the exported configurations back to MountConfigurations
    /// - Returns: Array of MountConfiguration instances (without credentials)
    func toMountConfigurations() -> [MountConfiguration] {
        return configurations.map { $0.toMountConfiguration() }
    }
}

// MARK: - ExportedConfiguration

/// Exported configuration data structure
/// Contains only non-sensitive configuration data (no credentials)
/// Requirements: 5.5
struct ExportedConfiguration: Codable, Equatable {
    /// SMB server address (hostname or IP)
    let server: String
    /// Name of the shared folder on the server
    let share: String
    /// Local filesystem path where the share should be mounted
    let mountPoint: String
    /// Whether to automatically mount this share on login
    let autoMount: Bool
    /// Whether file synchronization is enabled for this mount
    let syncEnabled: Bool
    // Note: Credentials are NOT exported for security reasons
    
    /// Creates an ExportedConfiguration from a MountConfiguration
    /// - Parameter configuration: The source configuration
    /// - Note: Credentials are intentionally excluded from the export
    init(from configuration: MountConfiguration) {
        self.server = configuration.server
        self.share = configuration.share
        self.mountPoint = configuration.mountPoint
        self.autoMount = configuration.autoMount
        self.syncEnabled = configuration.syncEnabled
    }
    
    /// Creates an ExportedConfiguration with explicit values
    /// - Parameters:
    ///   - server: SMB server address
    ///   - share: Share name
    ///   - mountPoint: Local mount point path
    ///   - autoMount: Whether to auto-mount on login
    ///   - syncEnabled: Whether sync is enabled
    init(server: String, share: String, mountPoint: String, autoMount: Bool, syncEnabled: Bool) {
        self.server = server
        self.share = share
        self.mountPoint = mountPoint
        self.autoMount = autoMount
        self.syncEnabled = syncEnabled
    }
    
    /// Converts the exported configuration back to a MountConfiguration
    /// - Returns: A new MountConfiguration instance with default credential settings
    /// - Note: rememberCredentials is set to false since credentials are not exported
    func toMountConfiguration() -> MountConfiguration {
        return MountConfiguration(
            id: UUID(), // Generate new ID for imported configuration
            server: server,
            share: share,
            mountPoint: mountPoint,
            autoMount: autoMount,
            rememberCredentials: false, // Credentials are not exported, so this defaults to false
            syncEnabled: syncEnabled,
            createdAt: Date(),
            lastModified: Date()
        )
    }
}

// MARK: - ConnectionStatistics

/// 连接统计数据
/// Tracks connection statistics for SMB mount configurations
/// Requirements: 5.7
struct ConnectionStatistics: Equatable {
    /// The ID of the configuration this statistics belongs to
    let configurationId: UUID
    /// Timestamp of the last successful connection
    let lastConnectedAt: Date?
    /// Total number of connection attempts
    let totalConnections: Int
    /// Number of successful connections
    let successfulConnections: Int
    /// Average connection latency in milliseconds
    let averageLatencyMs: Double?
    
    /// Calculates the success rate as a percentage (0-100)
    /// Returns 0 when totalConnections is 0 to avoid division by zero
    var successRate: Double {
        guard totalConnections > 0 else { return 0 }
        return Double(successfulConnections) / Double(totalConnections) * 100
    }
    
    /// Creates a new ConnectionStatistics instance
    init(
        configurationId: UUID,
        lastConnectedAt: Date? = nil,
        totalConnections: Int = 0,
        successfulConnections: Int = 0,
        averageLatencyMs: Double? = nil
    ) {
        self.configurationId = configurationId
        self.lastConnectedAt = lastConnectedAt
        self.totalConnections = totalConnections
        self.successfulConnections = successfulConnections
        self.averageLatencyMs = averageLatencyMs
    }
}

// MARK: - FailedOperationItem

/// Represents a failed item in a batch operation
/// Used to track which volumes failed during batch mount/unmount operations
/// Requirements: 6.5
struct FailedOperationItem: Identifiable, Equatable {
    /// Unique identifier for the failed item
    let id: UUID
    /// Name of the volume that failed
    let volumeName: String
    /// Error description explaining why the operation failed
    let error: String
    
    /// Creates a new FailedOperationItem instance
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - volumeName: Name of the volume that failed
    ///   - error: Error description
    init(id: UUID = UUID(), volumeName: String, error: String) {
        self.id = id
        self.volumeName = volumeName
        self.error = error
    }
}

// MARK: - BatchOperationResult

/// 批量操作结果
/// Represents the result of a batch operation (mount all / unmount all)
/// Requirements: 6.5
struct BatchOperationResult: Equatable {
    /// Total number of items in the batch operation
    let totalCount: Int
    /// Number of items that succeeded
    let successCount: Int
    /// List of items that failed with their error details
    let failedItems: [FailedOperationItem]
    
    /// Returns true if all operations succeeded (no failed items)
    /// This computed property checks if failedItems is empty
    var isFullySuccessful: Bool {
        return failedItems.isEmpty
    }
    
    /// Creates a new BatchOperationResult instance
    /// - Parameters:
    ///   - totalCount: Total number of items in the batch
    ///   - successCount: Number of successful operations
    ///   - failedItems: Array of failed operation items
    init(totalCount: Int, successCount: Int, failedItems: [FailedOperationItem]) {
        self.totalCount = totalCount
        self.successCount = successCount
        self.failedItems = failedItems
    }
    
    /// Creates a fully successful batch operation result
    /// - Parameter count: Total number of items that all succeeded
    /// - Returns: A BatchOperationResult with all items successful
    static func allSuccessful(count: Int) -> BatchOperationResult {
        return BatchOperationResult(totalCount: count, successCount: count, failedItems: [])
    }
    
    /// Creates a batch operation result from individual results
    /// - Parameters:
    ///   - total: Total number of items
    ///   - failures: Array of tuples containing volume name and error for each failure
    /// - Returns: A BatchOperationResult with the appropriate counts
    static func fromResults(total: Int, failures: [(volumeName: String, error: String)]) -> BatchOperationResult {
        let failedItems = failures.map { FailedOperationItem(volumeName: $0.volumeName, error: $0.error) }
        return BatchOperationResult(
            totalCount: total,
            successCount: total - failures.count,
            failedItems: failedItems
        )
    }
}
