//
//  StorageModels.swift
//  LanMount
//
//  Data models for storage visualization and monitoring
//  Requirements: 2.1, 2.4, 2.5
//

import Foundation
import SwiftUI

// MARK: - UsageLevel

/// Represents the usage level of a storage volume based on percentage thresholds
/// - normal: Usage below 80%
/// - warning: Usage between 80% and 95%
/// - critical: Usage above 95%
enum UsageLevel: Equatable {
    /// Usage is below 80% - normal operation
    case normal
    /// Usage is between 80% and 95% - warning state
    case warning
    /// Usage is above 95% - critical state
    case critical
    
    /// Returns the color associated with this usage level
    /// - normal: green
    /// - warning: orange
    /// - critical: red
    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    /// Returns a localized description of the usage level
    var localizedDescription: String {
        switch self {
        case .normal: return NSLocalizedString("Normal", comment: "Normal usage level")
        case .warning: return NSLocalizedString("Warning", comment: "Warning usage level")
        case .critical: return NSLocalizedString("Critical", comment: "Critical usage level")
        }
    }
}

// MARK: - VolumeStorageData

/// Represents storage data for a mounted SMB volume
/// Used for displaying storage charts and monitoring disk usage
struct VolumeStorageData: Identifiable, Equatable {
    /// Unique identifier for the volume storage data
    let id: UUID
    /// Display name of the volume
    let volumeName: String
    /// SMB server address (hostname or IP)
    let server: String
    /// Name of the shared folder on the server
    let share: String
    /// Total storage capacity in bytes
    let totalBytes: Int64
    /// Used storage space in bytes
    let usedBytes: Int64
    /// Available storage space in bytes
    let availableBytes: Int64
    /// Timestamp when the storage data was last updated
    let lastUpdated: Date
    
    /// Creates a new VolumeStorageData instance
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - volumeName: Display name of the volume
    ///   - server: SMB server address
    ///   - share: Name of the shared folder
    ///   - totalBytes: Total storage capacity in bytes
    ///   - usedBytes: Used storage space in bytes
    ///   - availableBytes: Available storage space in bytes
    ///   - lastUpdated: Timestamp of last update (defaults to current date)
    init(
        id: UUID = UUID(),
        volumeName: String,
        server: String,
        share: String,
        totalBytes: Int64,
        usedBytes: Int64,
        availableBytes: Int64,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.volumeName = volumeName
        self.server = server
        self.share = share
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.availableBytes = availableBytes
        self.lastUpdated = lastUpdated
    }
    
    /// Calculates the usage percentage of the volume
    /// Returns 0 if totalBytes is 0 or negative to avoid division by zero
    /// - Returns: Usage percentage (0-100)
    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
    
    /// Determines the usage level based on the usage percentage
    /// - normal: < 80%
    /// - warning: 80% - 95%
    /// - critical: > 95%
    /// - Returns: The appropriate UsageLevel for the current usage
    var usageLevel: UsageLevel {
        switch usagePercentage {
        case 0..<80: return .normal
        case 80..<95: return .warning
        default: return .critical
        }
    }
    
    /// Returns the SMB URL for this volume
    var smbURL: String {
        return "smb://\(server)/\(share)"
    }
    
    /// Returns a formatted string for the total capacity
    var formattedTotalCapacity: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    /// Returns a formatted string for the used space
    var formattedUsedSpace: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    /// Returns a formatted string for the available space
    var formattedAvailableSpace: String {
        ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
    }
    
    /// Generates an accessibility description for VoiceOver
    /// Includes volume name, used space, available space, and usage percentage
    var accessibilityDescription: String {
        let percentageString = String(format: "%.1f", usagePercentage)
        return String(
            format: NSLocalizedString(
                "%@ volume: %@ used of %@ total, %@%% full, %@ available",
                comment: "Accessibility description for volume storage"
            ),
            volumeName,
            formattedUsedSpace,
            formattedTotalCapacity,
            percentageString,
            formattedAvailableSpace
        )
    }
}

// MARK: - StorageSummary

/// Aggregated storage data across all mounted volumes
/// Used for displaying total storage overview in the dashboard
struct StorageSummary: Equatable {
    /// Total storage capacity across all volumes in bytes
    let totalCapacity: Int64
    /// Total used storage across all volumes in bytes
    let totalUsed: Int64
    /// Total available storage across all volumes in bytes
    let totalAvailable: Int64
    /// Number of volumes included in this summary
    let volumeCount: Int
    
    /// Creates a new StorageSummary instance
    /// - Parameters:
    ///   - totalCapacity: Total storage capacity in bytes
    ///   - totalUsed: Total used storage in bytes
    ///   - totalAvailable: Total available storage in bytes
    ///   - volumeCount: Number of volumes
    init(
        totalCapacity: Int64,
        totalUsed: Int64,
        totalAvailable: Int64,
        volumeCount: Int
    ) {
        self.totalCapacity = totalCapacity
        self.totalUsed = totalUsed
        self.totalAvailable = totalAvailable
        self.volumeCount = volumeCount
    }
    
    /// Creates a StorageSummary from an array of VolumeStorageData
    /// - Parameter volumes: Array of volume storage data to aggregate
    /// - Returns: A new StorageSummary with aggregated values
    static func from(volumes: [VolumeStorageData]) -> StorageSummary {
        let totalCapacity = volumes.reduce(Int64(0)) { $0 + $1.totalBytes }
        let totalUsed = volumes.reduce(Int64(0)) { $0 + $1.usedBytes }
        let totalAvailable = volumes.reduce(Int64(0)) { $0 + $1.availableBytes }
        
        return StorageSummary(
            totalCapacity: totalCapacity,
            totalUsed: totalUsed,
            totalAvailable: totalAvailable,
            volumeCount: volumes.count
        )
    }
    
    /// Calculates the overall usage percentage across all volumes
    /// Returns 0 if totalCapacity is 0 or negative to avoid division by zero
    /// - Returns: Overall usage percentage (0-100)
    var overallUsagePercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(totalUsed) / Double(totalCapacity) * 100
    }
    
    /// Determines the overall usage level based on the usage percentage
    var overallUsageLevel: UsageLevel {
        switch overallUsagePercentage {
        case 0..<80: return .normal
        case 80..<95: return .warning
        default: return .critical
        }
    }
    
    /// Returns a formatted string for the total capacity
    var formattedTotalCapacity: String {
        ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
    }
    
    /// Returns a formatted string for the total used space
    var formattedTotalUsed: String {
        ByteCountFormatter.string(fromByteCount: totalUsed, countStyle: .file)
    }

//    /// Returns a formatted string for the total capacity
//    var formattedTotalCapacity: String {
//        ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
//    }

    /// Returns a formatted string for the total available space
    var formattedTotalAvailable: String {
        ByteCountFormatter.string(fromByteCount: totalAvailable, countStyle: .file)
    }
    
    /// An empty storage summary with zero values
    static let empty = StorageSummary(
        totalCapacity: 0,
        totalUsed: 0,
        totalAvailable: 0,
        volumeCount: 0
    )
}
