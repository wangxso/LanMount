//
//  ChartModels.swift
//  LanMount
//
//  Centralized chart data models for storage trends, time ranges, and health metrics
//  Requirements: 6.1, 6.2, 6.3
//

import SwiftUI

// MARK: - StorageTrendDataPoint

/// 存储趋势数据点
/// Represents a single data point in the storage trend chart
///
/// This model captures storage usage at a specific point in time for a volume,
/// enabling visualization of storage trends over time.
///
/// **Validates: Requirements 6.1**
struct StorageTrendDataPoint: Identifiable, Equatable {
    let id: UUID
    let volumeId: UUID
    let volumeName: String
    let date: Date
    let usedBytes: Int64
    let totalBytes: Int64
    
    /// 使用率百分比
    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
    
    /// 格式化的已用空间
    var formattedUsedBytes: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    /// 格式化的总空间
    var formattedTotalBytes: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    /// 格式化的日期
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    /// 格式化的时间
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    init(
        id: UUID = UUID(),
        volumeId: UUID,
        volumeName: String,
        date: Date,
        usedBytes: Int64,
        totalBytes: Int64
    ) {
        self.id = id
        self.volumeId = volumeId
        self.volumeName = volumeName
        self.date = date
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }
}

// MARK: - ChartTimeRange

/// 图表时间范围枚举
/// Defines time ranges for IO performance charts
///
/// This enum provides predefined time ranges for chart display,
/// supporting 1 minute, 5 minutes, and 1 hour views.
///
/// **Validates: Requirements 6.2, 6.4**
enum ChartTimeRange: String, CaseIterable, Identifiable {
    case minute = "1分钟"
    case fiveMinutes = "5分钟"
    case hour = "1小时"
    
    var id: String { rawValue }
    
    /// Duration in seconds
    var seconds: TimeInterval {
        switch self {
        case .minute: return 60
        case .fiveMinutes: return 300
        case .hour: return 3600
        }
    }
    
    /// Date range for chart display
    var dateRange: ClosedRange<Date> {
        let now = Date()
        return now.addingTimeInterval(-seconds)...now
    }
    
    /// Localized display name
    var displayName: String {
        switch self {
        case .minute: return NSLocalizedString("1 Min", comment: "1 minute time range")
        case .fiveMinutes: return NSLocalizedString("5 Min", comment: "5 minutes time range")
        case .hour: return NSLocalizedString("1 Hour", comment: "1 hour time range")
        }
    }
}

// MARK: - HealthMetrics

/// 健康指标数据
/// Represents health metrics for a mounted volume
///
/// This model captures connection health information including
/// overall health score, latency, and success rate.
///
/// **Validates: Requirements 6.3**
struct HealthMetrics: Equatable, Identifiable {
    let id: UUID
    let volumeId: UUID
    let healthScore: Double      // 0-100
    let latencyMs: Double        // 延迟毫秒
    let successRate: Double      // 成功率百分比
    let lastChecked: Date
    
    /// 计算综合健康分数
    /// Calculates overall health score from latency and success rate
    /// - Parameters:
    ///   - latencyMs: Connection latency in milliseconds
    ///   - successRate: Success rate percentage (0-100)
    /// - Returns: Health score (0-100)
    ///
    /// The calculation uses:
    /// - Latency score: 100 for 0-100ms, linearly decreasing to 0 at 500ms
    /// - Combined score: 70% success rate weight + 30% latency weight
    ///
    /// **Validates: Requirements 6.3**
    static func calculateHealthScore(latencyMs: Double, successRate: Double) -> Double {
        // 延迟分数：0-100ms = 100分，100-500ms 线性递减
        let latencyScore: Double
        if latencyMs <= 100 {
            latencyScore = 100
        } else if latencyMs >= 500 {
            latencyScore = 0
        } else {
            latencyScore = max(0, 100 - (latencyMs - 100) / 4)
        }
        
        // 综合分数：成功率权重 70%，延迟权重 30%
        let combinedScore = successRate * 0.7 + latencyScore * 0.3
        
        // Clamp to 0-100 range
        return min(100, max(0, combinedScore))
    }
    
    /// Standard initializer with explicit health score
    init(
        id: UUID = UUID(),
        volumeId: UUID,
        healthScore: Double,
        latencyMs: Double,
        successRate: Double,
        lastChecked: Date = Date()
    ) {
        self.id = id
        self.volumeId = volumeId
        self.healthScore = min(100, max(0, healthScore))
        self.latencyMs = max(0, latencyMs)
        self.successRate = min(100, max(0, successRate))
        self.lastChecked = lastChecked
    }
    
    /// Creates HealthMetrics with auto-calculated health score
    init(
        id: UUID = UUID(),
        volumeId: UUID,
        latencyMs: Double,
        successRate: Double,
        lastChecked: Date = Date()
    ) {
        self.id = id
        self.volumeId = volumeId
        self.latencyMs = max(0, latencyMs)
        self.successRate = min(100, max(0, successRate))
        self.healthScore = Self.calculateHealthScore(latencyMs: latencyMs, successRate: successRate)
        self.lastChecked = lastChecked
    }
    
    /// Creates default health metrics for a volume
    static func defaultMetrics(for volumeId: UUID) -> HealthMetrics {
        HealthMetrics(
            id: UUID(),
            volumeId: volumeId,
            healthScore: 100,
            latencyMs: 50,
            successRate: 100,
            lastChecked: Date()
        )
    }
}
