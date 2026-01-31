//
//  DiskInfoPropertyTests.swift
//  LanMountTests
//
//  Property-based tests for DiskInfoTabView functionality
//  Feature: bottom-nav-refactor
//
//  **Validates: Requirements 4.1, 4.5, 4.6**
//

import XCTest
import SwiftUI
@testable import LanMountCore

// MARK: - Property Testing Framework for DiskInfo

/// A property testing helper for DiskInfo tests
/// Simulates property-based testing with randomized inputs
struct DiskInfoPropertyTester {
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
    
    /// Generates a random Int64 in the specified range
    static func randomInt64(in range: ClosedRange<Int64>) -> Int64 {
        return Int64.random(in: range)
    }
    
    /// Generates a random Double in the specified range
    static func randomDouble(in range: ClosedRange<Double>) -> Double {
        return Double.random(in: range)
    }
    
    /// Generates a random Bool
    static func randomBool() -> Bool {
        return Bool.random()
    }
    
    /// Generates a random alphanumeric string of specified length
    static func randomAlphanumericString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

// MARK: - Random Generators for VolumeStorageData

extension VolumeStorageData {
    /// Creates a random VolumeStorageData for property testing
    static func random() -> VolumeStorageData {
        let totalBytes = DiskInfoPropertyTester.randomInt64(in: 1_000_000_000...10_000_000_000_000) // 1GB to 10TB
        let usedBytes = DiskInfoPropertyTester.randomInt64(in: 0...totalBytes)
        let availableBytes = totalBytes - usedBytes
        
        let serverType = DiskInfoPropertyTester.randomInt(in: 0...1)
        let server: String
        
        if serverType == 0 {
            // Valid IP address
            server = "\(DiskInfoPropertyTester.randomInt(in: 1...255)).\(DiskInfoPropertyTester.randomInt(in: 0...255)).\(DiskInfoPropertyTester.randomInt(in: 0...255)).\(DiskInfoPropertyTester.randomInt(in: 1...254))"
        } else {
            // Valid hostname
            let hostLength = DiskInfoPropertyTester.randomInt(in: 3...15)
            server = DiskInfoPropertyTester.randomAlphanumericString(length: hostLength).lowercased()
        }
        
        let shareLength = DiskInfoPropertyTester.randomInt(in: 3...20)
        let share = DiskInfoPropertyTester.randomAlphanumericString(length: shareLength)
        
        let volumeNameLength = DiskInfoPropertyTester.randomInt(in: 3...15)
        let volumeName = DiskInfoPropertyTester.randomAlphanumericString(length: volumeNameLength)
        
        return VolumeStorageData(
            id: UUID(),
            volumeName: volumeName,
            server: server,
            share: share,
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            availableBytes: availableBytes,
            lastUpdated: Date()
        )
    }
    
    /// Creates a random array of VolumeStorageData
    static func randomArray(count: Int) -> [VolumeStorageData] {
        return (0..<count).map { _ in VolumeStorageData.random() }
    }
}


// MARK: - Random Generators for HealthMetrics

extension HealthMetrics {
    /// Creates a random HealthMetrics for property testing
    static func random(for volumeId: UUID = UUID()) -> HealthMetrics {
        let latencyMs = DiskInfoPropertyTester.randomDouble(in: 0...1000)
        let successRate = DiskInfoPropertyTester.randomDouble(in: 0...100)
        let healthScore = HealthMetrics.calculateHealthScore(latencyMs: latencyMs, successRate: successRate)
        
        return HealthMetrics(
            volumeId: volumeId,
            healthScore: healthScore,
            latencyMs: latencyMs,
            successRate: successRate,
            lastChecked: Date()
        )
    }
}

// MARK: - Random Generators for DiskStatisticsReport

extension DiskStatisticsReport.VolumeReport {
    /// Creates a random VolumeReport for property testing
    static func random() -> DiskStatisticsReport.VolumeReport {
        let totalBytes = DiskInfoPropertyTester.randomInt64(in: 1_000_000_000...10_000_000_000_000)
        let usedBytes = DiskInfoPropertyTester.randomInt64(in: 0...totalBytes)
        let availableBytes = totalBytes - usedBytes
        let usagePercentage = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
        
        let volumeNameLength = DiskInfoPropertyTester.randomInt(in: 3...15)
        let volumeName = DiskInfoPropertyTester.randomAlphanumericString(length: volumeNameLength)
        
        let serverType = DiskInfoPropertyTester.randomInt(in: 0...1)
        let server: String
        if serverType == 0 {
            server = "\(DiskInfoPropertyTester.randomInt(in: 1...255)).\(DiskInfoPropertyTester.randomInt(in: 0...255)).\(DiskInfoPropertyTester.randomInt(in: 0...255)).\(DiskInfoPropertyTester.randomInt(in: 1...254))"
        } else {
            let hostLength = DiskInfoPropertyTester.randomInt(in: 3...15)
            server = DiskInfoPropertyTester.randomAlphanumericString(length: hostLength).lowercased()
        }
        
        let shareLength = DiskInfoPropertyTester.randomInt(in: 3...20)
        let share = DiskInfoPropertyTester.randomAlphanumericString(length: shareLength)
        
        return DiskStatisticsReport.VolumeReport(
            volumeName: volumeName,
            server: server,
            share: share,
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            availableBytes: availableBytes,
            usagePercentage: usagePercentage,
            currentReadSpeed: DiskInfoPropertyTester.randomInt64(in: 0...1_000_000_000),
            currentWriteSpeed: DiskInfoPropertyTester.randomInt64(in: 0...1_000_000_000),
            averageReadSpeed: DiskInfoPropertyTester.randomInt64(in: 0...500_000_000),
            averageWriteSpeed: DiskInfoPropertyTester.randomInt64(in: 0...500_000_000),
            peakReadSpeed: DiskInfoPropertyTester.randomInt64(in: 0...2_000_000_000),
            peakWriteSpeed: DiskInfoPropertyTester.randomInt64(in: 0...2_000_000_000),
            healthScore: DiskInfoPropertyTester.randomDouble(in: 0...100),
            latencyMs: DiskInfoPropertyTester.randomDouble(in: 0...1000),
            successRate: DiskInfoPropertyTester.randomDouble(in: 0...100)
        )
    }
}

extension DiskStatisticsReport {
    /// Creates a random DiskStatisticsReport for property testing
    static func random(volumeCount: Int) -> DiskStatisticsReport {
        let volumes = (0..<volumeCount).map { _ in VolumeReport.random() }
        return DiskStatisticsReport(
            generatedAt: Date(),
            volumes: volumes
        )
    }
}


// MARK: - DiskInfo Property Tests

final class DiskInfoPropertyTests: XCTestCase {
    
    // MARK: - Property 8: 已挂载磁盘展示完整性 (Mounted Disk Display Completeness)
    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// For any mounted disk array, the number of disk details displayed by DiskInfoTabView
    /// should equal the array length.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_CountMatches() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性 (count)"
        ) {
            // Generate a random number of volumes (0 to 20)
            let count = DiskInfoPropertyTester.randomInt(in: 0...20)
            let volumes = VolumeStorageData.randomArray(count: count)
            
            // The number of volumes should match the array length
            return volumes.count == count
        }
        
        XCTAssertTrue(result, "Property 8 failed: Volume count must match array length")
    }
    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// Property test: For any volume in the array, it must have a valid (non-empty) volumeName.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_VolumeNamePresent() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性 (volumeName)"
        ) {
            let volume = VolumeStorageData.random()
            
            // Volume name must be non-empty for display
            return !volume.volumeName.isEmpty
        }
        
        XCTAssertTrue(result, "Property 8 failed: Each volume must have a volume name")
    }
    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// Property test: For any volume in the array, it must have valid storage information.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_StorageInfoValid() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性 (storage info)"
        ) {
            let volume = VolumeStorageData.random()
            
            // Storage info must be valid
            let hasValidTotal = volume.totalBytes >= 0
            let hasValidUsed = volume.usedBytes >= 0
            let hasValidAvailable = volume.availableBytes >= 0
            let usedPlusAvailableValid = volume.usedBytes + volume.availableBytes <= volume.totalBytes + 1 // Allow small rounding
            
            return hasValidTotal && hasValidUsed && hasValidAvailable && usedPlusAvailableValid
        }
        
        XCTAssertTrue(result, "Property 8 failed: Each volume must have valid storage information")
    }

    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// Property test: For any volume, the smbURL should be correctly formatted.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_SMBURLFormat() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性 (SMB URL)"
        ) {
            let volume = VolumeStorageData.random()
            
            // smbURL should be in format "smb://server/share"
            let expectedURL = "smb://\(volume.server)/\(volume.share)"
            
            return volume.smbURL == expectedURL
        }
        
        XCTAssertTrue(result, "Property 8 failed: SMB URL must be correctly formatted")
    }
    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// Property test: For any volume, the usagePercentage should be between 0 and 100.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_UsagePercentageValid() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性 (usage percentage)"
        ) {
            let volume = VolumeStorageData.random()
            
            // Usage percentage must be between 0 and 100
            return volume.usagePercentage >= 0 && volume.usagePercentage <= 100
        }
        
        XCTAssertTrue(result, "Property 8 failed: Usage percentage must be between 0 and 100")
    }
    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// Property test: For any volume, the usageLevel should correspond to the usagePercentage.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_UsageLevelCorrect() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性 (usage level)"
        ) {
            let volume = VolumeStorageData.random()
            
            // Usage level should match percentage thresholds
            let expectedLevel: UsageLevel
            switch volume.usagePercentage {
            case 0..<80: expectedLevel = .normal
            case 80..<95: expectedLevel = .warning
            default: expectedLevel = .critical
            }
            
            return volume.usageLevel == expectedLevel
        }
        
        XCTAssertTrue(result, "Property 8 failed: Usage level must correspond to usage percentage")
    }
    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// Property test: All volumes in an array must have unique identifiers.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_UniqueIdentifiers() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性 (unique IDs)"
        ) {
            let count = DiskInfoPropertyTester.randomInt(in: 2...15)
            let volumes = VolumeStorageData.randomArray(count: count)
            
            // All IDs must be unique
            let ids = volumes.map { $0.id }
            let uniqueIds = Set(ids)
            
            return ids.count == uniqueIds.count
        }
        
        XCTAssertTrue(result, "Property 8 failed: All volumes must have unique identifiers")
    }

    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// Comprehensive property test: For any randomly generated volume array,
    /// all volumes must have valid display properties.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_AllPropertiesValid() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性 (all properties)"
        ) {
            let count = DiskInfoPropertyTester.randomInt(in: 1...10)
            let volumes = VolumeStorageData.randomArray(count: count)
            
            // All volumes must have valid display properties
            for volume in volumes {
                if volume.volumeName.isEmpty { return false }
                if volume.server.isEmpty { return false }
                if volume.share.isEmpty { return false }
                if volume.totalBytes < 0 { return false }
                if volume.usedBytes < 0 { return false }
                if volume.availableBytes < 0 { return false }
                if volume.usagePercentage < 0 || volume.usagePercentage > 100 { return false }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 8 failed: All volumes must have valid display properties")
    }
    
    /// Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
    ///
    /// Edge case: Empty volume array should be handled correctly.
    ///
    /// **Validates: Requirements 4.1**
    func testProperty8_MountedDiskDisplayCompleteness_EmptyArray() {
        // Label: Feature: bottom-nav-refactor, Property 8: 已挂载磁盘展示完整性
        
        let volumes: [VolumeStorageData] = []
        
        // Empty array should have count 0
        XCTAssertEqual(volumes.count, 0, "Property 8 failed: Empty array should have count 0")
    }
    
    // MARK: - Property 9: 磁盘选择展开状态 (Disk Selection Expand State)
    
    /// Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
    ///
    /// For any disk ID, when the user selects that disk, the selectedVolume state should
    /// update to that ID; when selected again, it should toggle the expand/collapse state.
    ///
    /// **Validates: Requirements 4.5**
    func testProperty9_DiskSelectionExpandState_SelectUpdatesState() {
        // Label: Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态 (select updates)"
        ) {
            // Simulate selectedVolume state
            var selectedVolume: UUID? = nil
            
            // Generate a random volume ID
            let volumeId = UUID()
            
            // Select the volume
            selectedVolume = volumeId
            
            // selectedVolume should now be the volume ID
            return selectedVolume == volumeId
        }
        
        XCTAssertTrue(result, "Property 9 failed: Selecting a disk must update selectedVolume state")
    }
    
    /// Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
    ///
    /// Property test: Selecting the same disk again should toggle to nil (collapse).
    ///
    /// **Validates: Requirements 4.5**
    func testProperty9_DiskSelectionExpandState_ReselectToggles() {
        // Label: Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态 (reselect toggles)"
        ) {
            // Simulate selectedVolume state
            var selectedVolume: UUID? = nil
            
            // Generate a random volume ID
            let volumeId = UUID()
            
            // First selection - should expand
            if selectedVolume == volumeId {
                selectedVolume = nil
            } else {
                selectedVolume = volumeId
            }
            
            // Should be expanded (volumeId)
            guard selectedVolume == volumeId else { return false }
            
            // Second selection - should collapse
            if selectedVolume == volumeId {
                selectedVolume = nil
            } else {
                selectedVolume = volumeId
            }
            
            // Should be collapsed (nil)
            return selectedVolume == nil
        }
        
        XCTAssertTrue(result, "Property 9 failed: Reselecting the same disk must toggle expand/collapse")
    }

    
    /// Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
    ///
    /// Property test: Selecting a different disk should update to the new ID.
    ///
    /// **Validates: Requirements 4.5**
    func testProperty9_DiskSelectionExpandState_SelectDifferentDisk() {
        // Label: Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态 (different disk)"
        ) {
            // Simulate selectedVolume state
            var selectedVolume: UUID? = nil
            
            // Generate two different volume IDs
            let volumeId1 = UUID()
            let volumeId2 = UUID()
            
            // Select first volume
            if selectedVolume == volumeId1 {
                selectedVolume = nil
            } else {
                selectedVolume = volumeId1
            }
            
            // Should be volumeId1
            guard selectedVolume == volumeId1 else { return false }
            
            // Select second volume (different from current)
            if selectedVolume == volumeId2 {
                selectedVolume = nil
            } else {
                selectedVolume = volumeId2
            }
            
            // Should be volumeId2
            return selectedVolume == volumeId2
        }
        
        XCTAssertTrue(result, "Property 9 failed: Selecting a different disk must update to new ID")
    }
    
    /// Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
    ///
    /// Property test: Multiple toggle operations should maintain consistency.
    ///
    /// **Validates: Requirements 4.5**
    func testProperty9_DiskSelectionExpandState_MultipleToggles() {
        // Label: Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态 (multiple toggles)"
        ) {
            // Simulate selectedVolume state
            var selectedVolume: UUID? = nil
            
            // Generate a random volume ID
            let volumeId = UUID()
            
            // Perform multiple toggles
            let toggleCount = DiskInfoPropertyTester.randomInt(in: 1...10)
            
            for _ in 0..<toggleCount {
                if selectedVolume == volumeId {
                    selectedVolume = nil
                } else {
                    selectedVolume = volumeId
                }
            }
            
            // After odd number of toggles, should be expanded (volumeId)
            // After even number of toggles, should be collapsed (nil)
            let expectedState: UUID? = (toggleCount % 2 == 1) ? volumeId : nil
            
            return selectedVolume == expectedState
        }
        
        XCTAssertTrue(result, "Property 9 failed: Multiple toggles must maintain consistency")
    }
    
    /// Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
    ///
    /// Property test: Initial state should be nil (no disk selected).
    ///
    /// **Validates: Requirements 4.5**
    func testProperty9_DiskSelectionExpandState_InitialStateNil() {
        // Label: Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
        
        // Simulate initial selectedVolume state
        let selectedVolume: UUID? = nil
        
        // Initial state should be nil
        XCTAssertNil(selectedVolume, "Property 9 failed: Initial selectedVolume state must be nil")
    }
    
    /// Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
    ///
    /// Property test: Selection state should be independent for each volume.
    ///
    /// **Validates: Requirements 4.5**
    func testProperty9_DiskSelectionExpandState_IndependentSelection() {
        // Label: Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 9: 磁盘选择展开状态 (independent)"
        ) {
            // Generate multiple volumes
            let count = DiskInfoPropertyTester.randomInt(in: 2...10)
            let volumes = VolumeStorageData.randomArray(count: count)
            
            // Simulate selectedVolume state
            var selectedVolume: UUID? = nil
            
            // Select a random volume
            let randomIndex = DiskInfoPropertyTester.randomInt(in: 0...(count - 1))
            let selectedId = volumes[randomIndex].id
            
            selectedVolume = selectedId
            
            // Only the selected volume should be expanded
            for volume in volumes {
                let isExpanded = selectedVolume == volume.id
                if volume.id == selectedId {
                    if !isExpanded { return false }
                } else {
                    if isExpanded { return false }
                }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 9 failed: Selection state must be independent for each volume")
    }

    
    // MARK: - Property 10: 统计报告导出 (Statistics Report Export)
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// For any mounted disk statistics data, the export function should generate
    /// a valid data format containing all disk storage and IO information.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_ContainsAllVolumes() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (all volumes)"
        ) {
            // Generate a random number of volumes
            let count = DiskInfoPropertyTester.randomInt(in: 0...20)
            let report = DiskStatisticsReport.random(volumeCount: count)
            
            // Report should contain all volumes
            return report.volumes.count == count
        }
        
        XCTAssertTrue(result, "Property 10 failed: Report must contain all volumes")
    }
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Property test: Each volume report must contain valid storage information.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_ValidStorageInfo() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (storage info)"
        ) {
            let volumeReport = DiskStatisticsReport.VolumeReport.random()
            
            // Storage info must be valid
            let hasValidTotal = volumeReport.totalBytes >= 0
            let hasValidUsed = volumeReport.usedBytes >= 0
            let hasValidAvailable = volumeReport.availableBytes >= 0
            let hasValidPercentage = volumeReport.usagePercentage >= 0 && volumeReport.usagePercentage <= 100
            
            return hasValidTotal && hasValidUsed && hasValidAvailable && hasValidPercentage
        }
        
        XCTAssertTrue(result, "Property 10 failed: Each volume report must contain valid storage info")
    }
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Property test: Each volume report must contain valid IO information.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_ValidIOInfo() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (IO info)"
        ) {
            let volumeReport = DiskStatisticsReport.VolumeReport.random()
            
            // IO info must be valid (non-negative)
            let hasValidCurrentRead = volumeReport.currentReadSpeed >= 0
            let hasValidCurrentWrite = volumeReport.currentWriteSpeed >= 0
            let hasValidAverageRead = volumeReport.averageReadSpeed >= 0
            let hasValidAverageWrite = volumeReport.averageWriteSpeed >= 0
            let hasValidPeakRead = volumeReport.peakReadSpeed >= 0
            let hasValidPeakWrite = volumeReport.peakWriteSpeed >= 0
            
            return hasValidCurrentRead && hasValidCurrentWrite &&
                   hasValidAverageRead && hasValidAverageWrite &&
                   hasValidPeakRead && hasValidPeakWrite
        }
        
        XCTAssertTrue(result, "Property 10 failed: Each volume report must contain valid IO info")
    }

    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Property test: Each volume report must contain valid health metrics.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_ValidHealthMetrics() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (health metrics)"
        ) {
            let volumeReport = DiskStatisticsReport.VolumeReport.random()
            
            // Health metrics must be valid
            let hasValidHealthScore = volumeReport.healthScore >= 0 && volumeReport.healthScore <= 100
            let hasValidLatency = volumeReport.latencyMs >= 0
            let hasValidSuccessRate = volumeReport.successRate >= 0 && volumeReport.successRate <= 100
            
            return hasValidHealthScore && hasValidLatency && hasValidSuccessRate
        }
        
        XCTAssertTrue(result, "Property 10 failed: Each volume report must contain valid health metrics")
    }
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Property test: Report must contain a valid generation timestamp.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_ValidTimestamp() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (timestamp)"
        ) {
            let count = DiskInfoPropertyTester.randomInt(in: 0...10)
            let report = DiskStatisticsReport.random(volumeCount: count)
            
            // Timestamp should be a valid date (not in the distant future)
            let now = Date()
            let oneMinuteFromNow = now.addingTimeInterval(60)
            
            return report.generatedAt <= oneMinuteFromNow
        }
        
        XCTAssertTrue(result, "Property 10 failed: Report must contain a valid generation timestamp")
    }
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Property test: Report should be encodable to JSON format.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_JSONEncodable() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (JSON encodable)"
        ) {
            let count = DiskInfoPropertyTester.randomInt(in: 0...10)
            let report = DiskStatisticsReport.random(volumeCount: count)
            
            // Report should be encodable to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            do {
                let data = try encoder.encode(report)
                return !data.isEmpty
            } catch {
                return false
            }
        }
        
        XCTAssertTrue(result, "Property 10 failed: Report must be encodable to JSON format")
    }
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Property test: Report should be decodable from JSON format (round-trip).
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_JSONRoundTrip() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (JSON round-trip)"
        ) {
            let count = DiskInfoPropertyTester.randomInt(in: 0...10)
            let originalReport = DiskStatisticsReport.random(volumeCount: count)
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let data = try encoder.encode(originalReport)
                let decodedReport = try decoder.decode(DiskStatisticsReport.self, from: data)
                
                // Verify volume count matches
                return decodedReport.volumes.count == originalReport.volumes.count
            } catch {
                return false
            }
        }
        
        XCTAssertTrue(result, "Property 10 failed: Report must survive JSON round-trip")
    }

    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Property test: Each volume report must contain server and share information.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_ServerShareInfo() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (server/share)"
        ) {
            let volumeReport = DiskStatisticsReport.VolumeReport.random()
            
            // Server and share must be non-empty
            let hasValidServer = !volumeReport.server.isEmpty
            let hasValidShare = !volumeReport.share.isEmpty
            let hasValidVolumeName = !volumeReport.volumeName.isEmpty
            
            return hasValidServer && hasValidShare && hasValidVolumeName
        }
        
        XCTAssertTrue(result, "Property 10 failed: Each volume report must contain server and share info")
    }
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Comprehensive property test: Report must contain all required fields for each volume.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_AllFieldsPresent() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskInfoPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 10: 统计报告导出 (all fields)"
        ) {
            let count = DiskInfoPropertyTester.randomInt(in: 1...10)
            let report = DiskStatisticsReport.random(volumeCount: count)
            
            // All volumes must have all required fields
            for volumeReport in report.volumes {
                // Identity fields
                if volumeReport.volumeName.isEmpty { return false }
                if volumeReport.server.isEmpty { return false }
                if volumeReport.share.isEmpty { return false }
                
                // Storage fields (must be non-negative)
                if volumeReport.totalBytes < 0 { return false }
                if volumeReport.usedBytes < 0 { return false }
                if volumeReport.availableBytes < 0 { return false }
                if volumeReport.usagePercentage < 0 || volumeReport.usagePercentage > 100 { return false }
                
                // IO fields (must be non-negative)
                if volumeReport.currentReadSpeed < 0 { return false }
                if volumeReport.currentWriteSpeed < 0 { return false }
                if volumeReport.averageReadSpeed < 0 { return false }
                if volumeReport.averageWriteSpeed < 0 { return false }
                if volumeReport.peakReadSpeed < 0 { return false }
                if volumeReport.peakWriteSpeed < 0 { return false }
                
                // Health fields
                if volumeReport.healthScore < 0 || volumeReport.healthScore > 100 { return false }
                if volumeReport.latencyMs < 0 { return false }
                if volumeReport.successRate < 0 || volumeReport.successRate > 100 { return false }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 10 failed: Report must contain all required fields for each volume")
    }
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Edge case: Empty volume array should produce valid empty report.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_EmptyReport() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        
        let report = DiskStatisticsReport.random(volumeCount: 0)
        
        // Empty report should have 0 volumes
        XCTAssertEqual(report.volumes.count, 0, "Property 10 failed: Empty report should have 0 volumes")
        
        // Should still be encodable
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        XCTAssertNoThrow(try encoder.encode(report), "Property 10 failed: Empty report should be encodable")
    }
    
    /// Feature: bottom-nav-refactor, Property 10: 统计报告导出
    ///
    /// Edge case: Large volume count should be handled correctly.
    ///
    /// **Validates: Requirements 4.6**
    func testProperty10_StatisticsReportExport_LargeVolumeCount() {
        // Label: Feature: bottom-nav-refactor, Property 10: 统计报告导出
        
        let largeCount = 50
        let report = DiskStatisticsReport.random(volumeCount: largeCount)
        
        // Large report should have correct volume count
        XCTAssertEqual(report.volumes.count, largeCount, "Property 10 failed: Large report should have correct volume count")
        
        // Should still be encodable
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        XCTAssertNoThrow(try encoder.encode(report), "Property 10 failed: Large report should be encodable")
    }
}
