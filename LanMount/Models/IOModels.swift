//
//  IOModels.swift
//  LanMount
//
//  Data models for IO performance monitoring and visualization
//  Requirements: 3.3 - Display current speed, average speed, and peak speed
//

import Foundation
import SwiftUI

// MARK: - IODataPoint

/// Represents a single IO data point for historical tracking
/// Used for building IO history charts and calculating statistics
struct IODataPoint: Identifiable, Equatable {
    /// Unique identifier for this data point
    let id: UUID
    /// The volume this data point belongs to
    let volumeId: UUID
    /// Timestamp when this data point was recorded
    let timestamp: Date
    /// Read speed in bytes per second at this point in time
    let readSpeed: Int64
    /// Write speed in bytes per second at this point in time
    let writeSpeed: Int64
    
    /// Creates a new IODataPoint instance
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - volumeId: The volume this data point belongs to
    ///   - timestamp: Timestamp of the data point (defaults to current date)
    ///   - readSpeed: Read speed in bytes per second
    ///   - writeSpeed: Write speed in bytes per second
    init(
        id: UUID = UUID(),
        volumeId: UUID,
        timestamp: Date = Date(),
        readSpeed: Int64,
        writeSpeed: Int64
    ) {
        self.id = id
        self.volumeId = volumeId
        self.timestamp = timestamp
        self.readSpeed = readSpeed
        self.writeSpeed = writeSpeed
    }
    
    /// Returns a formatted string for the read speed
    var formattedReadSpeed: String {
        ByteCountFormatter.string(fromByteCount: readSpeed, countStyle: .file) + "/s"
    }
    
    /// Returns a formatted string for the write speed
    var formattedWriteSpeed: String {
        ByteCountFormatter.string(fromByteCount: writeSpeed, countStyle: .file) + "/s"
    }
}

// MARK: - VolumeIOStats

/// Represents IO statistics for a mounted SMB volume
/// Includes current, average, and peak speeds for both read and write operations
/// Requirements: 3.3 - Display current speed, average speed, and peak speed
struct VolumeIOStats: Identifiable, Equatable {
    /// Unique identifier for this stats record
    let id: UUID
    /// Display name of the volume
    let volumeName: String
    /// Current read speed in bytes per second
    let readBytesPerSecond: Int64
    /// Current write speed in bytes per second
    let writeBytesPerSecond: Int64
    /// Average read speed in bytes per second (calculated from history)
    let averageReadSpeed: Int64
    /// Average write speed in bytes per second (calculated from history)
    let averageWriteSpeed: Int64
    /// Peak (maximum) read speed in bytes per second (from history)
    let peakReadSpeed: Int64
    /// Peak (maximum) write speed in bytes per second (from history)
    let peakWriteSpeed: Int64
    /// Timestamp when these statistics were recorded
    let timestamp: Date
    
    /// Creates a new VolumeIOStats instance
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - volumeName: Display name of the volume
    ///   - readBytesPerSecond: Current read speed in bytes per second
    ///   - writeBytesPerSecond: Current write speed in bytes per second
    ///   - averageReadSpeed: Average read speed in bytes per second
    ///   - averageWriteSpeed: Average write speed in bytes per second
    ///   - peakReadSpeed: Peak read speed in bytes per second
    ///   - peakWriteSpeed: Peak write speed in bytes per second
    ///   - timestamp: Timestamp of the statistics (defaults to current date)
    init(
        id: UUID = UUID(),
        volumeName: String,
        readBytesPerSecond: Int64,
        writeBytesPerSecond: Int64,
        averageReadSpeed: Int64,
        averageWriteSpeed: Int64,
        peakReadSpeed: Int64,
        peakWriteSpeed: Int64,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.volumeName = volumeName
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.averageReadSpeed = averageReadSpeed
        self.averageWriteSpeed = averageWriteSpeed
        self.peakReadSpeed = peakReadSpeed
        self.peakWriteSpeed = peakWriteSpeed
        self.timestamp = timestamp
    }
    
    // MARK: - Formatted Speed Strings
    
    /// Returns a formatted string for the current read speed
    var formattedReadSpeed: String {
        ByteCountFormatter.string(fromByteCount: readBytesPerSecond, countStyle: .file) + "/s"
    }
    
    /// Returns a formatted string for the current write speed
    var formattedWriteSpeed: String {
        ByteCountFormatter.string(fromByteCount: writeBytesPerSecond, countStyle: .file) + "/s"
    }
    
    /// Returns a formatted string for the average read speed
    var formattedAverageReadSpeed: String {
        ByteCountFormatter.string(fromByteCount: averageReadSpeed, countStyle: .file) + "/s"
    }
    
    /// Returns a formatted string for the average write speed
    var formattedAverageWriteSpeed: String {
        ByteCountFormatter.string(fromByteCount: averageWriteSpeed, countStyle: .file) + "/s"
    }
    
    /// Returns a formatted string for the peak read speed
    var formattedPeakReadSpeed: String {
        ByteCountFormatter.string(fromByteCount: peakReadSpeed, countStyle: .file) + "/s"
    }
    
    /// Returns a formatted string for the peak write speed
    var formattedPeakWriteSpeed: String {
        ByteCountFormatter.string(fromByteCount: peakWriteSpeed, countStyle: .file) + "/s"
    }
    
    // MARK: - Accessibility
    
    /// Generates an accessibility description for VoiceOver
    /// Includes volume name, current speeds, average speeds, and peak speeds
    var accessibilityDescription: String {
        String(
            format: NSLocalizedString(
                "%@ IO: Read %@, Write %@. Average: Read %@, Write %@. Peak: Read %@, Write %@",
                comment: "Accessibility description for volume IO statistics"
            ),
            volumeName,
            formattedReadSpeed,
            formattedWriteSpeed,
            formattedAverageReadSpeed,
            formattedAverageWriteSpeed,
            formattedPeakReadSpeed,
            formattedPeakWriteSpeed
        )
    }
    
    // MARK: - Static Factory Methods
    
    /// Creates a VolumeIOStats with zero values (for unavailable data)
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - volumeName: Display name of the volume
    /// - Returns: A VolumeIOStats instance with all speeds set to zero
    static func unavailable(id: UUID = UUID(), volumeName: String) -> VolumeIOStats {
        VolumeIOStats(
            id: id,
            volumeName: volumeName,
            readBytesPerSecond: 0,
            writeBytesPerSecond: 0,
            averageReadSpeed: 0,
            averageWriteSpeed: 0,
            peakReadSpeed: 0,
            peakWriteSpeed: 0
        )
    }
}

// MARK: - IOStatsCalculator

/// Utility for calculating IO statistics from a collection of data points
/// Implements Property 7: IO 统计计算 - averageReadSpeed equals arithmetic mean of all readSpeed values,
/// peakReadSpeed equals maximum of all readSpeed values, same for write speeds
struct IOStatsCalculator {
    
    /// Calculates the average read speed from a collection of data points
    /// Returns 0 if the collection is empty
    /// - Parameter dataPoints: Array of IO data points
    /// - Returns: Average read speed in bytes per second
    static func calculateAverageReadSpeed(from dataPoints: [IODataPoint]) -> Int64 {
        guard !dataPoints.isEmpty else { return 0 }
        let sum = dataPoints.reduce(Int64(0)) { $0 + $1.readSpeed }
        return sum / Int64(dataPoints.count)
    }
    
    /// Calculates the average write speed from a collection of data points
    /// Returns 0 if the collection is empty
    /// - Parameter dataPoints: Array of IO data points
    /// - Returns: Average write speed in bytes per second
    static func calculateAverageWriteSpeed(from dataPoints: [IODataPoint]) -> Int64 {
        guard !dataPoints.isEmpty else { return 0 }
        let sum = dataPoints.reduce(Int64(0)) { $0 + $1.writeSpeed }
        return sum / Int64(dataPoints.count)
    }
    
    /// Calculates the peak (maximum) read speed from a collection of data points
    /// Returns 0 if the collection is empty
    /// - Parameter dataPoints: Array of IO data points
    /// - Returns: Peak read speed in bytes per second
    static func calculatePeakReadSpeed(from dataPoints: [IODataPoint]) -> Int64 {
        dataPoints.map { $0.readSpeed }.max() ?? 0
    }
    
    /// Calculates the peak (maximum) write speed from a collection of data points
    /// Returns 0 if the collection is empty
    /// - Parameter dataPoints: Array of IO data points
    /// - Returns: Peak write speed in bytes per second
    static func calculatePeakWriteSpeed(from dataPoints: [IODataPoint]) -> Int64 {
        dataPoints.map { $0.writeSpeed }.max() ?? 0
    }
    
    /// Creates a VolumeIOStats instance from current values and historical data points
    /// - Parameters:
    ///   - id: Unique identifier for the stats
    ///   - volumeName: Display name of the volume
    ///   - currentReadSpeed: Current read speed in bytes per second
    ///   - currentWriteSpeed: Current write speed in bytes per second
    ///   - historyDataPoints: Historical data points for calculating averages and peaks
    /// - Returns: A fully populated VolumeIOStats instance
    static func createStats(
        id: UUID = UUID(),
        volumeName: String,
        currentReadSpeed: Int64,
        currentWriteSpeed: Int64,
        historyDataPoints: [IODataPoint]
    ) -> VolumeIOStats {
        // Include current values in calculations if we have history
        let allDataPoints: [IODataPoint]
        if historyDataPoints.isEmpty {
            // If no history, create a single data point from current values
            allDataPoints = [
                IODataPoint(
                    volumeId: id,
                    readSpeed: currentReadSpeed,
                    writeSpeed: currentWriteSpeed
                )
            ]
        } else {
            allDataPoints = historyDataPoints
        }
        
        return VolumeIOStats(
            id: id,
            volumeName: volumeName,
            readBytesPerSecond: currentReadSpeed,
            writeBytesPerSecond: currentWriteSpeed,
            averageReadSpeed: calculateAverageReadSpeed(from: allDataPoints),
            averageWriteSpeed: calculateAverageWriteSpeed(from: allDataPoints),
            peakReadSpeed: max(currentReadSpeed, calculatePeakReadSpeed(from: allDataPoints)),
            peakWriteSpeed: max(currentWriteSpeed, calculatePeakWriteSpeed(from: allDataPoints))
        )
    }
}

// MARK: - IOHistoryBuffer

/// Manages a buffer of IO data points with automatic expiration
/// Implements Property 8: IO 历史数据缓冲区管理 - buffer only keeps data points within the last 60 seconds
struct IOHistoryBuffer {
    /// Maximum duration to keep data points (default: 60 seconds)
    let maxDuration: TimeInterval
    
    /// Internal storage for data points
    private(set) var dataPoints: [IODataPoint]
    
    /// Creates a new IOHistoryBuffer
    /// - Parameter maxDuration: Maximum duration to keep data points (default: 60 seconds)
    init(maxDuration: TimeInterval = 60.0) {
        self.maxDuration = maxDuration
        self.dataPoints = []
    }
    
    /// Adds a new data point and removes expired ones
    /// - Parameter dataPoint: The data point to add
    mutating func add(_ dataPoint: IODataPoint) {
        dataPoints.append(dataPoint)
        pruneExpired(relativeTo: dataPoint.timestamp)
    }
    
    /// Removes data points older than maxDuration relative to the reference date
    /// - Parameter referenceDate: The date to use as reference for expiration
    mutating func pruneExpired(relativeTo referenceDate: Date = Date()) {
        let cutoffDate = referenceDate.addingTimeInterval(-maxDuration)
        dataPoints.removeAll { $0.timestamp < cutoffDate }
    }
    
    /// Returns data points for a specific volume
    /// - Parameter volumeId: The volume ID to filter by
    /// - Returns: Array of data points for the specified volume
    func dataPoints(for volumeId: UUID) -> [IODataPoint] {
        dataPoints.filter { $0.volumeId == volumeId }
    }
    
    /// Returns all data points within a specific duration from now
    /// - Parameter duration: The duration to look back
    /// - Returns: Array of data points within the specified duration
    func dataPoints(within duration: TimeInterval) -> [IODataPoint] {
        let cutoffDate = Date().addingTimeInterval(-duration)
        return dataPoints.filter { $0.timestamp >= cutoffDate }
    }
    
    /// Clears all data points
    mutating func clear() {
        dataPoints.removeAll()
    }
    
    /// Returns the number of data points in the buffer
    var count: Int {
        dataPoints.count
    }
    
    /// Returns whether the buffer is empty
    var isEmpty: Bool {
        dataPoints.isEmpty
    }
}
