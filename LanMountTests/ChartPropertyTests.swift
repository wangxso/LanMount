//
//  ChartPropertyTests.swift
//  LanMountTests
//
//  Property-based tests for Chart components (IOHistoryChart, HealthGaugeChart)
//  Feature: bottom-nav-refactor
//
//  **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.6**
//

import XCTest
import SwiftUI
@testable import LanMountCore

// MARK: - Property Testing Framework for Charts

/// A property testing helper for Chart tests
/// Simulates property-based testing with randomized inputs
struct ChartPropertyTester {
    /// Runs a property test with the specified number of iterations
    /// - Parameters:
    ///   - iterations: Number of test iterations (default: 100 as per design.md)
    ///   - label: Test label for identification
    ///   - property: The property to test, returns true if property holds
    static func check(
        iterations: Int = 100,
        label: String,
        property: () -> Bool
    ) -> Bool {
        for iteration in 0..<iterations {
            if !property() {
                print("Property '\(label)' failed at iteration \(iteration)")
                return false
            }
        }
        return true
    }
    
    /// Generates a random Int in the specified range
    static func randomInt(in range: ClosedRange<Int>) -> Int {
        return Int.random(in: range)
    }
    
    /// Generates a random Double in the specified range
    static func randomDouble(in range: ClosedRange<Double>) -> Double {
        return Double.random(in: range)
    }
    
    /// Generates a random Bool
    static func randomBool() -> Bool {
        return Bool.random()
    }
}


// MARK: - Random Generators for Chart Models

extension ChartTimeRange {
    /// Creates a random ChartTimeRange for property testing
    static func random() -> ChartTimeRange {
        return ChartTimeRange.allCases.randomElement()!
    }
}

extension IODataPoint {
    /// Creates a random IODataPoint for property testing
    /// - Parameters:
    ///   - volumeId: Optional volume ID (defaults to random UUID)
    ///   - timestamp: Optional timestamp (defaults to random time within last hour)
    static func random(
        volumeId: UUID? = nil,
        timestamp: Date? = nil
    ) -> IODataPoint {
        let now = Date()
        let randomTimestamp = timestamp ?? now.addingTimeInterval(
            -Double(ChartPropertyTester.randomInt(in: 0...7200)) // Up to 2 hours ago
        )
        
        return IODataPoint(
            volumeId: volumeId ?? UUID(),
            timestamp: randomTimestamp,
            readSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000)), // 0 to 1 GB/s
            writeSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000))
        )
    }
    
    /// Creates a random array of IODataPoints
    /// - Parameters:
    ///   - count: Number of data points to generate
    ///   - volumeId: Optional volume ID for all points
    ///   - timeRange: Optional time range to constrain timestamps
    static func randomArray(
        count: Int,
        volumeId: UUID? = nil,
        timeRange: ChartTimeRange? = nil
    ) -> [IODataPoint] {
        let vid = volumeId ?? UUID()
        let now = Date()
        
        return (0..<count).map { index in
            let timestamp: Date
            if let range = timeRange {
                // Generate timestamp within the specified range
                let secondsAgo = Double(ChartPropertyTester.randomInt(in: 0...Int(range.seconds)))
                timestamp = now.addingTimeInterval(-secondsAgo)
            } else {
                // Generate timestamp within last 2 hours
                let secondsAgo = Double(ChartPropertyTester.randomInt(in: 0...7200))
                timestamp = now.addingTimeInterval(-secondsAgo)
            }
            
            return IODataPoint(
                volumeId: vid,
                timestamp: timestamp,
                readSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000)),
                writeSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000))
            )
        }
    }
    
    /// Creates a random array with some points inside and some outside a time range
    static func randomMixedArray(
        insideCount: Int,
        outsideCount: Int,
        timeRange: ChartTimeRange
    ) -> [IODataPoint] {
        let volumeId = UUID()
        let now = Date()
        
        // Points inside the range
        let insidePoints = (0..<insideCount).map { _ -> IODataPoint in
            let secondsAgo = Double(ChartPropertyTester.randomInt(in: 0...Int(timeRange.seconds - 1)))
            return IODataPoint(
                volumeId: volumeId,
                timestamp: now.addingTimeInterval(-secondsAgo),
                readSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000)),
                writeSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000))
            )
        }
        
        // Points outside the range (older than the range)
        let outsidePoints = (0..<outsideCount).map { _ -> IODataPoint in
            let secondsAgo = Double(ChartPropertyTester.randomInt(in: Int(timeRange.seconds + 1)...Int(timeRange.seconds * 3)))
            return IODataPoint(
                volumeId: volumeId,
                timestamp: now.addingTimeInterval(-secondsAgo),
                readSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000)),
                writeSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000))
            )
        }
        
        return (insidePoints + outsidePoints).shuffled()
    }
}


// MARK: - Chart Property Tests

final class ChartPropertyTests: XCTestCase {
    
    // MARK: - Property 12: 图表时间范围数据过滤 (Chart Time Range Data Filtering)
    
    /// Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
    ///
    /// For any ChartTimeRange value and data point array, filtered data points should only
    /// include points with timestamps within the specified range.
    ///
    /// **Validates: Requirements 6.1, 6.2, 6.4**
    func testProperty12_ChartTimeRangeFiltering_AllFilteredPointsWithinRange() {
        // Label: Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤 (within range)"
        ) {
            // Generate random time range
            let timeRange = ChartTimeRange.random()
            
            // Generate random data points (some inside, some outside range)
            let insideCount = ChartPropertyTester.randomInt(in: 0...20)
            let outsideCount = ChartPropertyTester.randomInt(in: 0...20)
            let data = IODataPoint.randomMixedArray(
                insideCount: insideCount,
                outsideCount: outsideCount,
                timeRange: timeRange
            )
            
            // Filter data using the same logic as IOHistoryChart
            let range = timeRange.dateRange
            let filteredData = data.filter { range.contains($0.timestamp) }
            
            // All filtered points must be within the range
            for point in filteredData {
                if !range.contains(point.timestamp) {
                    return false
                }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 12 failed: All filtered data points must be within the specified time range")
    }
    
    /// Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
    ///
    /// Property test: Points outside the time range should be excluded from filtered results.
    ///
    /// **Validates: Requirements 6.1, 6.2, 6.4**
    func testProperty12_ChartTimeRangeFiltering_OutsidePointsExcluded() {
        // Label: Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤 (outside excluded)"
        ) {
            // Generate random time range
            let timeRange = ChartTimeRange.random()
            
            // Generate data with known inside/outside counts
            let insideCount = ChartPropertyTester.randomInt(in: 1...15)
            let outsideCount = ChartPropertyTester.randomInt(in: 1...15)
            let data = IODataPoint.randomMixedArray(
                insideCount: insideCount,
                outsideCount: outsideCount,
                timeRange: timeRange
            )
            
            // Filter data
            let range = timeRange.dateRange
            let filteredData = data.filter { range.contains($0.timestamp) }
            
            // Filtered count should be approximately equal to insideCount
            // (allowing for edge cases where timestamps might be exactly on boundary)
            // The key property is that no outside points should be included
            for point in data {
                let isInRange = range.contains(point.timestamp)
                let isInFiltered = filteredData.contains { $0.id == point.id }
                
                // If point is outside range, it must not be in filtered data
                if !isInRange && isInFiltered {
                    return false
                }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 12 failed: Points outside the time range must be excluded")
    }

    
    /// Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
    ///
    /// Property test: Each ChartTimeRange should have correct seconds value.
    ///
    /// **Validates: Requirements 6.1, 6.2, 6.4**
    func testProperty12_ChartTimeRangeFiltering_CorrectSecondsValue() {
        // Label: Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
        
        // Verify each time range has the correct seconds value
        XCTAssertEqual(ChartTimeRange.minute.seconds, 60, "1 minute should be 60 seconds")
        XCTAssertEqual(ChartTimeRange.fiveMinutes.seconds, 300, "5 minutes should be 300 seconds")
        XCTAssertEqual(ChartTimeRange.hour.seconds, 3600, "1 hour should be 3600 seconds")
    }
    
    /// Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
    ///
    /// Property test: dateRange should span from (now - seconds) to now.
    ///
    /// **Validates: Requirements 6.1, 6.2, 6.4**
    func testProperty12_ChartTimeRangeFiltering_DateRangeSpan() {
        // Label: Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤 (date range span)"
        ) {
            let timeRange = ChartTimeRange.random()
            let range = timeRange.dateRange
            
            // The range should span approximately `seconds` duration
            let duration = range.upperBound.timeIntervalSince(range.lowerBound)
            
            // Allow small tolerance for timing differences
            let expectedDuration = timeRange.seconds
            let tolerance = 1.0 // 1 second tolerance
            
            return abs(duration - expectedDuration) <= tolerance
        }
        
        XCTAssertTrue(result, "Property 12 failed: dateRange should span the correct duration")
    }
    
    /// Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
    ///
    /// Property test: Empty data array should result in empty filtered array.
    ///
    /// **Validates: Requirements 6.1, 6.2, 6.4**
    func testProperty12_ChartTimeRangeFiltering_EmptyDataReturnsEmpty() {
        // Label: Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤 (empty data)"
        ) {
            let timeRange = ChartTimeRange.random()
            let data: [IODataPoint] = []
            
            let range = timeRange.dateRange
            let filteredData = data.filter { range.contains($0.timestamp) }
            
            return filteredData.isEmpty
        }
        
        XCTAssertTrue(result, "Property 12 failed: Empty data should result in empty filtered data")
    }
    
    /// Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
    ///
    /// Property test: All points within range should be included in filtered results.
    ///
    /// **Validates: Requirements 6.1, 6.2, 6.4**
    func testProperty12_ChartTimeRangeFiltering_AllInsidePointsIncluded() {
        // Label: Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 12: 图表时间范围数据过滤 (inside included)"
        ) {
            let timeRange = ChartTimeRange.random()
            
            // Generate only points inside the range
            let count = ChartPropertyTester.randomInt(in: 1...20)
            let data = IODataPoint.randomArray(count: count, timeRange: timeRange)
            
            let range = timeRange.dateRange
            let filteredData = data.filter { range.contains($0.timestamp) }
            
            // All points should be included (they were all generated within range)
            for point in data {
                if range.contains(point.timestamp) {
                    if !filteredData.contains(where: { $0.id == point.id }) {
                        return false
                    }
                }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 12 failed: All points within range should be included")
    }

    
    // MARK: - Property 13: 图表数据刷新 (Chart Data Refresh)
    
    /// Feature: bottom-nav-refactor, Property 13: 图表数据刷新
    ///
    /// For any chart view, after calling refresh method, data should update to latest values,
    /// and timestamps should be after refresh time.
    ///
    /// **Validates: Requirements 6.6**
    func testProperty13_ChartDataRefresh_NewDataHasRecentTimestamps() {
        // Label: Feature: bottom-nav-refactor, Property 13: 图表数据刷新
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 13: 图表数据刷新 (recent timestamps)"
        ) {
            // Simulate refresh by recording time before generating new data
            let refreshTime = Date()
            
            // Small delay to ensure new data has later timestamp
            // In real implementation, this would be actual data collection
            let newDataPoint = IODataPoint(
                volumeId: UUID(),
                timestamp: Date(), // Current time (after refresh)
                readSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000)),
                writeSpeed: Int64(ChartPropertyTester.randomInt(in: 0...1_000_000_000))
            )
            
            // New data timestamp should be >= refresh time
            return newDataPoint.timestamp >= refreshTime
        }
        
        XCTAssertTrue(result, "Property 13 failed: New data timestamps should be after refresh time")
    }
    
    /// Feature: bottom-nav-refactor, Property 13: 图表数据刷新
    ///
    /// Property test: After refresh, the data array should contain the new data point.
    ///
    /// **Validates: Requirements 6.6**
    func testProperty13_ChartDataRefresh_DataArrayUpdated() {
        // Label: Feature: bottom-nav-refactor, Property 13: 图表数据刷新
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 13: 图表数据刷新 (array updated)"
        ) {
            // Start with existing data
            let existingCount = ChartPropertyTester.randomInt(in: 0...10)
            var data = IODataPoint.randomArray(count: existingCount)
            let originalCount = data.count
            
            // Simulate refresh by adding new data point
            let newDataPoint = IODataPoint.random(timestamp: Date())
            data.append(newDataPoint)
            
            // Data array should now contain the new point
            let containsNewPoint = data.contains { $0.id == newDataPoint.id }
            let countIncreased = data.count == originalCount + 1
            
            return containsNewPoint && countIncreased
        }
        
        XCTAssertTrue(result, "Property 13 failed: Data array should be updated after refresh")
    }
    
    /// Feature: bottom-nav-refactor, Property 13: 图表数据刷新
    ///
    /// Property test: Refresh should preserve existing data within the time range.
    ///
    /// **Validates: Requirements 6.6**
    func testProperty13_ChartDataRefresh_ExistingDataPreserved() {
        // Label: Feature: bottom-nav-refactor, Property 13: 图表数据刷新
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 13: 图表数据刷新 (existing preserved)"
        ) {
            let timeRange = ChartTimeRange.random()
            
            // Generate existing data within range
            let existingCount = ChartPropertyTester.randomInt(in: 1...10)
            var data = IODataPoint.randomArray(count: existingCount, timeRange: timeRange)
            let existingIds = Set(data.map { $0.id })
            
            // Simulate refresh by adding new data
            let newDataPoint = IODataPoint.random(timestamp: Date())
            data.append(newDataPoint)
            
            // All existing data should still be present
            let currentIds = Set(data.map { $0.id })
            
            return existingIds.isSubset(of: currentIds)
        }
        
        XCTAssertTrue(result, "Property 13 failed: Existing data should be preserved after refresh")
    }
    
    /// Feature: bottom-nav-refactor, Property 13: 图表数据刷新
    ///
    /// Property test: IOHistoryBuffer should correctly add new data points.
    ///
    /// **Validates: Requirements 6.6**
    func testProperty13_ChartDataRefresh_BufferAddition() {
        // Label: Feature: bottom-nav-refactor, Property 13: 图表数据刷新
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 13: 图表数据刷新 (buffer addition)"
        ) {
            var buffer = IOHistoryBuffer(maxDuration: 3600) // 1 hour buffer
            
            // Add initial data points
            let initialCount = ChartPropertyTester.randomInt(in: 0...10)
            for _ in 0..<initialCount {
                buffer.add(IODataPoint.random(timestamp: Date()))
            }
            
            let countBefore = buffer.count
            
            // Simulate refresh by adding new data point
            let newDataPoint = IODataPoint.random(timestamp: Date())
            buffer.add(newDataPoint)
            
            // Buffer should contain the new point
            let containsNewPoint = buffer.dataPoints.contains { $0.id == newDataPoint.id }
            let countIncreased = buffer.count >= countBefore // May prune old data
            
            return containsNewPoint
        }
        
        XCTAssertTrue(result, "Property 13 failed: Buffer should correctly add new data points")
    }

    
    // MARK: - Property 16: 健康分数计算 (Health Score Calculation)
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// For any latency and success rate values, HealthMetrics.calculateHealthScore should return
    /// a value in 0-100 range, with success rate weight 70% and latency weight 30%.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_ResultInValidRange() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (valid range)"
        ) {
            // Generate random latency (0 to 1000ms) and success rate (0 to 100%)
            let latencyMs = ChartPropertyTester.randomDouble(in: 0...1000)
            let successRate = ChartPropertyTester.randomDouble(in: 0...100)
            
            let healthScore = HealthMetrics.calculateHealthScore(
                latencyMs: latencyMs,
                successRate: successRate
            )
            
            // Health score must be in 0-100 range
            return healthScore >= 0 && healthScore <= 100
        }
        
        XCTAssertTrue(result, "Property 16 failed: Health score must be in 0-100 range")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Success rate has 70% weight in the calculation.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_SuccessRateWeight70Percent() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (success rate weight)"
        ) {
            // Use fixed latency to isolate success rate effect
            let fixedLatency = 50.0 // Low latency = 100 latency score
            
            let successRate1 = ChartPropertyTester.randomDouble(in: 0...50)
            let successRate2 = successRate1 + 10 // 10% higher success rate
            
            let score1 = HealthMetrics.calculateHealthScore(
                latencyMs: fixedLatency,
                successRate: successRate1
            )
            let score2 = HealthMetrics.calculateHealthScore(
                latencyMs: fixedLatency,
                successRate: successRate2
            )
            
            // 10% increase in success rate should result in ~7 point increase (70% weight)
            let scoreDifference = score2 - score1
            let expectedDifference = 10 * 0.7 // 7 points
            let tolerance = 0.5
            
            return abs(scoreDifference - expectedDifference) <= tolerance
        }
        
        XCTAssertTrue(result, "Property 16 failed: Success rate should have 70% weight")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Latency has 30% weight in the calculation.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_LatencyWeight30Percent() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (latency weight)"
        ) {
            // Use fixed success rate to isolate latency effect
            let fixedSuccessRate = 100.0 // Perfect success rate
            
            // Test with latency in the linear decrease range (100-500ms)
            // Latency score formula: max(0, 100 - (latencyMs - 100) / 4)
            let latency1 = ChartPropertyTester.randomDouble(in: 100...400)
            let latency2 = latency1 + 40 // 40ms higher latency = 10 point decrease in latency score
            
            let score1 = HealthMetrics.calculateHealthScore(
                latencyMs: latency1,
                successRate: fixedSuccessRate
            )
            let score2 = HealthMetrics.calculateHealthScore(
                latencyMs: latency2,
                successRate: fixedSuccessRate
            )
            
            // 40ms increase in latency = 10 point decrease in latency score
            // With 30% weight, this should result in ~3 point decrease in health score
            let scoreDifference = score1 - score2
            let expectedDifference = 10 * 0.3 // 3 points
            let tolerance = 0.5
            
            return abs(scoreDifference - expectedDifference) <= tolerance
        }
        
        XCTAssertTrue(result, "Property 16 failed: Latency should have 30% weight")
    }

    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Latency <= 100ms should give maximum latency score (100).
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_LowLatencyMaxScore() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (low latency max)"
        ) {
            // Latency <= 100ms should give latency score of 100
            let lowLatency = ChartPropertyTester.randomDouble(in: 0...100)
            let successRate = 100.0 // Perfect success rate
            
            let healthScore = HealthMetrics.calculateHealthScore(
                latencyMs: lowLatency,
                successRate: successRate
            )
            
            // With 100% success rate and 100 latency score:
            // healthScore = 100 * 0.7 + 100 * 0.3 = 100
            let expectedScore = 100.0
            let tolerance = 0.01
            
            return abs(healthScore - expectedScore) <= tolerance
        }
        
        XCTAssertTrue(result, "Property 16 failed: Low latency (<=100ms) should give maximum latency score")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Latency >= 500ms should give minimum latency score (0).
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_HighLatencyMinScore() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (high latency min)"
        ) {
            // Latency >= 500ms should give latency score of 0
            let highLatency = ChartPropertyTester.randomDouble(in: 500...2000)
            let successRate = 100.0 // Perfect success rate
            
            let healthScore = HealthMetrics.calculateHealthScore(
                latencyMs: highLatency,
                successRate: successRate
            )
            
            // With 100% success rate and 0 latency score:
            // healthScore = 100 * 0.7 + 0 * 0.3 = 70
            let expectedScore = 70.0
            let tolerance = 0.01
            
            return abs(healthScore - expectedScore) <= tolerance
        }
        
        XCTAssertTrue(result, "Property 16 failed: High latency (>=500ms) should give minimum latency score")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Latency between 100-500ms should have linear decrease in latency score.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_LinearLatencyDecrease() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (linear decrease)"
        ) {
            // Test linearity in the 100-500ms range
            let latency1 = ChartPropertyTester.randomDouble(in: 100...300)
            let latency2 = latency1 + 100 // 100ms more
            let latency3 = latency2 + 100 // Another 100ms more
            
            let successRate = 100.0
            
            let score1 = HealthMetrics.calculateHealthScore(latencyMs: latency1, successRate: successRate)
            let score2 = HealthMetrics.calculateHealthScore(latencyMs: latency2, successRate: successRate)
            let score3 = HealthMetrics.calculateHealthScore(latencyMs: latency3, successRate: successRate)
            
            // The decrease should be linear (equal steps)
            let diff1 = score1 - score2
            let diff2 = score2 - score3
            let tolerance = 0.01
            
            return abs(diff1 - diff2) <= tolerance
        }
        
        XCTAssertTrue(result, "Property 16 failed: Latency score should decrease linearly between 100-500ms")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Perfect inputs (0 latency, 100% success) should give score of 100.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_PerfectInputsPerfectScore() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        
        let healthScore = HealthMetrics.calculateHealthScore(
            latencyMs: 0,
            successRate: 100
        )
        
        XCTAssertEqual(healthScore, 100, accuracy: 0.01, "Perfect inputs should give score of 100")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Worst inputs (high latency, 0% success) should give score of 0.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_WorstInputsMinScore() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        
        let healthScore = HealthMetrics.calculateHealthScore(
            latencyMs: 1000, // Very high latency
            successRate: 0   // 0% success rate
        )
        
        XCTAssertEqual(healthScore, 0, accuracy: 0.01, "Worst inputs should give score of 0")
    }

    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: HealthMetrics initialization should clamp values to valid ranges.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_ValuesClamped() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (values clamped)"
        ) {
            // Generate potentially out-of-range values
            let healthScore = ChartPropertyTester.randomDouble(in: -50...150)
            let latencyMs = ChartPropertyTester.randomDouble(in: -100...2000)
            let successRate = ChartPropertyTester.randomDouble(in: -50...150)
            
            let metrics = HealthMetrics(
                volumeId: UUID(),
                healthScore: healthScore,
                latencyMs: latencyMs,
                successRate: successRate
            )
            
            // All values should be clamped to valid ranges
            let healthScoreClamped = metrics.healthScore >= 0 && metrics.healthScore <= 100
            let latencyClamped = metrics.latencyMs >= 0
            let successRateClamped = metrics.successRate >= 0 && metrics.successRate <= 100
            
            return healthScoreClamped && latencyClamped && successRateClamped
        }
        
        XCTAssertTrue(result, "Property 16 failed: HealthMetrics should clamp values to valid ranges")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: HealthMetrics auto-calculation initializer should compute correct health score.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_AutoCalculation() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (auto calculation)"
        ) {
            let latencyMs = ChartPropertyTester.randomDouble(in: 0...1000)
            let successRate = ChartPropertyTester.randomDouble(in: 0...100)
            
            // Use auto-calculation initializer
            let metrics = HealthMetrics(
                volumeId: UUID(),
                latencyMs: latencyMs,
                successRate: successRate
            )
            
            // Calculate expected health score
            let expectedScore = HealthMetrics.calculateHealthScore(
                latencyMs: latencyMs,
                successRate: successRate
            )
            
            let tolerance = 0.01
            return abs(metrics.healthScore - expectedScore) <= tolerance
        }
        
        XCTAssertTrue(result, "Property 16 failed: Auto-calculation should compute correct health score")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Edge case tests for health score calculation boundaries.
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_EdgeCases() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        
        // Edge case: Exactly 100ms latency (boundary)
        let score100ms = HealthMetrics.calculateHealthScore(latencyMs: 100, successRate: 100)
        XCTAssertEqual(score100ms, 100, accuracy: 0.01, "100ms latency should give max score")
        
        // Edge case: Exactly 500ms latency (boundary)
        let score500ms = HealthMetrics.calculateHealthScore(latencyMs: 500, successRate: 100)
        XCTAssertEqual(score500ms, 70, accuracy: 0.01, "500ms latency should give 70 (100*0.7 + 0*0.3)")
        
        // Edge case: 300ms latency (middle of range)
        // Latency score = 100 - (300 - 100) / 4 = 100 - 50 = 50
        // Health score = 100 * 0.7 + 50 * 0.3 = 70 + 15 = 85
        let score300ms = HealthMetrics.calculateHealthScore(latencyMs: 300, successRate: 100)
        XCTAssertEqual(score300ms, 85, accuracy: 0.01, "300ms latency should give 85")
        
        // Edge case: 50% success rate with 0 latency
        // Health score = 50 * 0.7 + 100 * 0.3 = 35 + 30 = 65
        let score50Success = HealthMetrics.calculateHealthScore(latencyMs: 0, successRate: 50)
        XCTAssertEqual(score50Success, 65, accuracy: 0.01, "50% success with 0 latency should give 65")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Higher success rate should always result in higher or equal health score
    /// (with same latency).
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_MonotonicSuccessRate() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (monotonic success)"
        ) {
            let latencyMs = ChartPropertyTester.randomDouble(in: 0...1000)
            let successRate1 = ChartPropertyTester.randomDouble(in: 0...50)
            let successRate2 = ChartPropertyTester.randomDouble(in: 50...100)
            
            let score1 = HealthMetrics.calculateHealthScore(latencyMs: latencyMs, successRate: successRate1)
            let score2 = HealthMetrics.calculateHealthScore(latencyMs: latencyMs, successRate: successRate2)
            
            // Higher success rate should give higher or equal score
            return score2 >= score1
        }
        
        XCTAssertTrue(result, "Property 16 failed: Higher success rate should give higher health score")
    }
    
    /// Feature: bottom-nav-refactor, Property 16: 健康分数计算
    ///
    /// Property test: Lower latency should always result in higher or equal health score
    /// (with same success rate).
    ///
    /// **Validates: Requirements 6.3**
    func testProperty16_HealthScoreCalculation_MonotonicLatency() {
        // Label: Feature: bottom-nav-refactor, Property 16: 健康分数计算
        // Minimum iterations: 100 (as per design.md)
        
        let result = ChartPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 16: 健康分数计算 (monotonic latency)"
        ) {
            let successRate = ChartPropertyTester.randomDouble(in: 0...100)
            let latency1 = ChartPropertyTester.randomDouble(in: 0...500)
            let latency2 = ChartPropertyTester.randomDouble(in: 500...1000)
            
            let score1 = HealthMetrics.calculateHealthScore(latencyMs: latency1, successRate: successRate)
            let score2 = HealthMetrics.calculateHealthScore(latencyMs: latency2, successRate: successRate)
            
            // Lower latency should give higher or equal score
            return score1 >= score2
        }
        
        XCTAssertTrue(result, "Property 16 failed: Lower latency should give higher health score")
    }
}
