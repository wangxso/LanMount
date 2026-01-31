//
//  SystemConfigPropertyTests.swift
//  LanMountTests
//
//  Property-based tests for SystemConfigTabView (Configuration Export/Import)
//  Feature: bottom-nav-refactor
//
//  **Validates: Requirements 5.6**
//

import XCTest
@testable import LanMountCore

// MARK: - Property Testing Framework for SystemConfig

/// A property testing helper for SystemConfig tests
/// Generates random MountConfiguration instances for property-based testing
struct SystemConfigPropertyTester {
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
    
    /// Generates a random Bool
    static func randomBool() -> Bool {
        return Bool.random()
    }
    
    /// Generates a random alphanumeric string of specified length
    static func randomAlphanumericString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    /// Generates a random valid server address (hostname or IP)
    static func randomServer() -> String {
        if randomBool() {
            // Generate IP address
            let octet1 = randomInt(in: 1...254)
            let octet2 = randomInt(in: 0...255)
            let octet3 = randomInt(in: 0...255)
            let octet4 = randomInt(in: 1...254)
            return "\(octet1).\(octet2).\(octet3).\(octet4)"
        } else {
            // Generate hostname
            let prefix = randomAlphanumericString(length: randomInt(in: 3...10))
            let domain = ["local", "lan", "home", "network"].randomElement()!
            return "\(prefix.lowercased()).\(domain)"
        }
    }
    
    /// Generates a random valid share name
    static func randomShare() -> String {
        let prefixes = ["share", "data", "files", "backup", "media", "documents", "photos"]
        let prefix = prefixes.randomElement()!
        let suffix = randomInt(in: 1...99)
        return "\(prefix)\(suffix)"
    }
    
    /// Generates a random mount point path
    static func randomMountPoint(share: String) -> String {
        return "/Volumes/\(share)"
    }
}

// MARK: - Random Generators for MountConfiguration (SystemConfig)

/// Helper struct for generating random MountConfigurations for SystemConfig tests
/// Uses a separate namespace to avoid conflicts with other test files
struct SystemConfigMountConfigGenerator {
    /// Creates a random valid MountConfiguration for property testing
    static func random() -> MountConfiguration {
        let server = SystemConfigPropertyTester.randomServer()
        let share = SystemConfigPropertyTester.randomShare()
        let mountPoint = SystemConfigPropertyTester.randomMountPoint(share: share)
        
        return MountConfiguration(
            id: UUID(),
            server: server,
            share: share,
            mountPoint: mountPoint,
            autoMount: SystemConfigPropertyTester.randomBool(),
            rememberCredentials: SystemConfigPropertyTester.randomBool(),
            syncEnabled: SystemConfigPropertyTester.randomBool(),
            createdAt: Date(),
            lastModified: Date()
        )
    }
    
    /// Creates an array of random MountConfigurations
    static func randomArray(count: Int) -> [MountConfiguration] {
        return (0..<count).map { _ in random() }
    }
    
    /// Creates an array of random MountConfigurations with random count
    static func randomArray(countRange: ClosedRange<Int>) -> [MountConfiguration] {
        let count = SystemConfigPropertyTester.randomInt(in: countRange)
        return randomArray(count: count)
    }
}

// MARK: - SystemConfig Property Tests

final class SystemConfigPropertyTests: XCTestCase {
    
    // MARK: - Property 11: 配置导出导入往返 (Configuration Export/Import Round-Trip)
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// For any valid MountConfiguration array, exporting to JSON and then importing
    /// should produce an equivalent configuration array (excluding credential information).
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_SingleConfiguration() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = SystemConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 11: 配置导出导入往返 (single config)"
        ) {
            // Generate a random configuration
            let originalConfig = SystemConfigMountConfigGenerator.random()
            let originalConfigs = [originalConfig]
            
            // Export to JSON
            let export = ConfigurationExport(configurations: originalConfigs)
            guard let jsonData = try? export.toJSON() else {
                print("Failed to export configuration to JSON")
                return false
            }
            
            // Import from JSON
            guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
                print("Failed to import configuration from JSON")
                return false
            }
            
            // Convert back to MountConfigurations
            let importedConfigs = importedExport.toMountConfigurations()
            
            // Verify count matches
            guard importedConfigs.count == originalConfigs.count else {
                print("Configuration count mismatch: expected \(originalConfigs.count), got \(importedConfigs.count)")
                return false
            }
            
            // Verify exported fields match (excluding credentials and IDs)
            let original = originalConfigs[0]
            let imported = importedConfigs[0]
            
            let serverMatches = imported.server == original.server
            let shareMatches = imported.share == original.share
            let mountPointMatches = imported.mountPoint == original.mountPoint
            let autoMountMatches = imported.autoMount == original.autoMount
            let syncEnabledMatches = imported.syncEnabled == original.syncEnabled
            
            // rememberCredentials should be false after import (credentials not exported)
            let credentialsReset = imported.rememberCredentials == false
            
            return serverMatches && shareMatches && mountPointMatches && 
                   autoMountMatches && syncEnabledMatches && credentialsReset
        }
        
        XCTAssertTrue(result, "Property 11 failed: Export/import round-trip should preserve configuration data (excluding credentials)")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// For any valid MountConfiguration array with multiple configurations,
    /// exporting to JSON and then importing should preserve all configurations.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_MultipleConfigurations() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = SystemConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 11: 配置导出导入往返 (multiple configs)"
        ) {
            // Generate random number of configurations (1-10)
            let configCount = SystemConfigPropertyTester.randomInt(in: 1...10)
            let originalConfigs = SystemConfigMountConfigGenerator.randomArray(count: configCount)
            
            // Export to JSON
            let export = ConfigurationExport(configurations: originalConfigs)
            guard let jsonData = try? export.toJSON() else {
                print("Failed to export configurations to JSON")
                return false
            }
            
            // Import from JSON
            guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
                print("Failed to import configurations from JSON")
                return false
            }
            
            // Convert back to MountConfigurations
            let importedConfigs = importedExport.toMountConfigurations()
            
            // Verify count matches
            guard importedConfigs.count == originalConfigs.count else {
                print("Configuration count mismatch: expected \(originalConfigs.count), got \(importedConfigs.count)")
                return false
            }
            
            // Verify each configuration's exported fields match
            for i in 0..<originalConfigs.count {
                let original = originalConfigs[i]
                let imported = importedConfigs[i]
                
                if imported.server != original.server ||
                   imported.share != original.share ||
                   imported.mountPoint != original.mountPoint ||
                   imported.autoMount != original.autoMount ||
                   imported.syncEnabled != original.syncEnabled {
                    print("Configuration \(i) data mismatch")
                    return false
                }
                
                // rememberCredentials should be false after import
                if imported.rememberCredentials != false {
                    print("Configuration \(i) rememberCredentials should be false after import")
                    return false
                }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 11 failed: Export/import round-trip should preserve all configuration data for multiple configs")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// For an empty MountConfiguration array, exporting to JSON and then importing
    /// should produce an empty array.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_EmptyArray() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        
        let originalConfigs: [MountConfiguration] = []
        
        // Export to JSON
        let export = ConfigurationExport(configurations: originalConfigs)
        guard let jsonData = try? export.toJSON() else {
            XCTFail("Failed to export empty configuration array to JSON")
            return
        }
        
        // Import from JSON
        guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
            XCTFail("Failed to import empty configuration array from JSON")
            return
        }
        
        // Convert back to MountConfigurations
        let importedConfigs = importedExport.toMountConfigurations()
        
        // Verify empty array
        XCTAssertEqual(importedConfigs.count, 0, "Property 11 failed: Empty array should remain empty after round-trip")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// Verifies that credentials (rememberCredentials) are NOT exported for security.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_CredentialsNotExported() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = SystemConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 11: 配置导出导入往返 (credentials not exported)"
        ) {
            // Create a configuration with rememberCredentials = true
            let server = SystemConfigPropertyTester.randomServer()
            let share = SystemConfigPropertyTester.randomShare()
            
            let originalConfig = MountConfiguration(
                id: UUID(),
                server: server,
                share: share,
                mountPoint: "/Volumes/\(share)",
                autoMount: SystemConfigPropertyTester.randomBool(),
                rememberCredentials: true, // Explicitly set to true
                syncEnabled: SystemConfigPropertyTester.randomBool(),
                createdAt: Date(),
                lastModified: Date()
            )
            
            // Export to JSON
            let export = ConfigurationExport(configurations: [originalConfig])
            guard let jsonData = try? export.toJSON() else {
                print("Failed to export configuration to JSON")
                return false
            }
            
            // Verify JSON does not contain rememberCredentials field
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("Failed to convert JSON data to string")
                return false
            }
            
            // The exported JSON should not contain rememberCredentials
            if jsonString.contains("rememberCredentials") {
                print("JSON should not contain rememberCredentials field")
                return false
            }
            
            // Import from JSON
            guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
                print("Failed to import configuration from JSON")
                return false
            }
            
            // Convert back to MountConfigurations
            let importedConfigs = importedExport.toMountConfigurations()
            
            // Verify rememberCredentials is false after import
            guard importedConfigs.count == 1 else {
                print("Expected 1 configuration, got \(importedConfigs.count)")
                return false
            }
            
            return importedConfigs[0].rememberCredentials == false
        }
        
        XCTAssertTrue(result, "Property 11 failed: Credentials should not be exported and should be reset to false on import")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// Verifies that the export version is correctly set and preserved.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_VersionPreserved() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = SystemConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 11: 配置导出导入往返 (version preserved)"
        ) {
            // Generate random configurations
            let configs = SystemConfigMountConfigGenerator.randomArray(countRange: 0...5)
            
            // Export to JSON
            let export = ConfigurationExport(configurations: configs)
            
            // Verify version is set correctly
            guard export.version == ConfigurationExport.currentVersion else {
                print("Export version mismatch: expected \(ConfigurationExport.currentVersion), got \(export.version)")
                return false
            }
            
            guard let jsonData = try? export.toJSON() else {
                print("Failed to export configuration to JSON")
                return false
            }
            
            // Import from JSON
            guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
                print("Failed to import configuration from JSON")
                return false
            }
            
            // Verify version is preserved
            return importedExport.version == ConfigurationExport.currentVersion
        }
        
        XCTAssertTrue(result, "Property 11 failed: Export version should be preserved during round-trip")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// Verifies that the export timestamp is set and is a valid date.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_TimestampSet() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = SystemConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 11: 配置导出导入往返 (timestamp set)"
        ) {
            let beforeExport = Date()
            
            // Generate random configurations
            let configs = SystemConfigMountConfigGenerator.randomArray(countRange: 0...5)
            
            // Export to JSON
            let export = ConfigurationExport(configurations: configs)
            
            let afterExport = Date()
            
            // Verify exportedAt is within the expected time range
            guard export.exportedAt >= beforeExport && export.exportedAt <= afterExport else {
                print("Export timestamp out of expected range")
                return false
            }
            
            guard let jsonData = try? export.toJSON() else {
                print("Failed to export configuration to JSON")
                return false
            }
            
            // Import from JSON
            guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
                print("Failed to import configuration from JSON")
                return false
            }
            
            // Verify timestamp is preserved (within 1 second tolerance for encoding/decoding)
            let timeDifference = abs(importedExport.exportedAt.timeIntervalSince(export.exportedAt))
            return timeDifference < 1.0
        }
        
        XCTAssertTrue(result, "Property 11 failed: Export timestamp should be set and preserved during round-trip")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// Verifies that imported configurations get new UUIDs (not the original ones).
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_NewUUIDsGenerated() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = SystemConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 11: 配置导出导入往返 (new UUIDs)"
        ) {
            // Generate random configurations
            let originalConfigs = SystemConfigMountConfigGenerator.randomArray(countRange: 1...5)
            let originalIds = Set(originalConfigs.map { $0.id })
            
            // Export to JSON
            let export = ConfigurationExport(configurations: originalConfigs)
            guard let jsonData = try? export.toJSON() else {
                print("Failed to export configuration to JSON")
                return false
            }
            
            // Import from JSON
            guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
                print("Failed to import configuration from JSON")
                return false
            }
            
            // Convert back to MountConfigurations
            let importedConfigs = importedExport.toMountConfigurations()
            let importedIds = Set(importedConfigs.map { $0.id })
            
            // Verify that imported IDs are different from original IDs
            // (new UUIDs should be generated on import)
            let intersection = originalIds.intersection(importedIds)
            
            // It's extremely unlikely (practically impossible) for randomly generated UUIDs to collide
            return intersection.isEmpty
        }
        
        XCTAssertTrue(result, "Property 11 failed: Imported configurations should have new UUIDs")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// Verifies that the order of configurations is preserved during export/import.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_OrderPreserved() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = SystemConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 11: 配置导出导入往返 (order preserved)"
        ) {
            // Generate multiple configurations with distinct servers
            let configCount = SystemConfigPropertyTester.randomInt(in: 2...10)
            var originalConfigs: [MountConfiguration] = []
            
            for i in 0..<configCount {
                let config = MountConfiguration(
                    id: UUID(),
                    server: "server\(i).local",
                    share: "share\(i)",
                    mountPoint: "/Volumes/share\(i)",
                    autoMount: SystemConfigPropertyTester.randomBool(),
                    rememberCredentials: SystemConfigPropertyTester.randomBool(),
                    syncEnabled: SystemConfigPropertyTester.randomBool(),
                    createdAt: Date(),
                    lastModified: Date()
                )
                originalConfigs.append(config)
            }
            
            // Export to JSON
            let export = ConfigurationExport(configurations: originalConfigs)
            guard let jsonData = try? export.toJSON() else {
                print("Failed to export configuration to JSON")
                return false
            }
            
            // Import from JSON
            guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
                print("Failed to import configuration from JSON")
                return false
            }
            
            // Convert back to MountConfigurations
            let importedConfigs = importedExport.toMountConfigurations()
            
            // Verify order is preserved by checking server names
            guard importedConfigs.count == originalConfigs.count else {
                print("Configuration count mismatch")
                return false
            }
            
            for i in 0..<originalConfigs.count {
                if importedConfigs[i].server != originalConfigs[i].server {
                    print("Order not preserved at index \(i)")
                    return false
                }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 11 failed: Configuration order should be preserved during round-trip")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// Verifies that special characters in server/share names are handled correctly.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_SpecialCharacters() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        
        // Test with various special characters that might appear in server/share names
        let testCases: [(server: String, share: String)] = [
            ("192.168.1.100", "share-with-dash"),
            ("server.local", "share_with_underscore"),
            ("my-server.home.lan", "Share123"),
            ("10.0.0.1", "data"),
        ]
        
        for testCase in testCases {
            let originalConfig = MountConfiguration(
                id: UUID(),
                server: testCase.server,
                share: testCase.share,
                mountPoint: "/Volumes/\(testCase.share)",
                autoMount: true,
                rememberCredentials: true,
                syncEnabled: false,
                createdAt: Date(),
                lastModified: Date()
            )
            
            // Export to JSON
            let export = ConfigurationExport(configurations: [originalConfig])
            guard let jsonData = try? export.toJSON() else {
                XCTFail("Failed to export configuration with server=\(testCase.server), share=\(testCase.share)")
                continue
            }
            
            // Import from JSON
            guard let importedExport = try? ConfigurationExport.fromJSON(jsonData) else {
                XCTFail("Failed to import configuration with server=\(testCase.server), share=\(testCase.share)")
                continue
            }
            
            // Convert back to MountConfigurations
            let importedConfigs = importedExport.toMountConfigurations()
            
            XCTAssertEqual(importedConfigs.count, 1, "Should have exactly 1 imported configuration")
            XCTAssertEqual(importedConfigs[0].server, testCase.server, "Server should match for \(testCase.server)")
            XCTAssertEqual(importedConfigs[0].share, testCase.share, "Share should match for \(testCase.share)")
        }
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// Verifies that ConfigurationExport and ExportedConfiguration are Equatable.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_Equatable() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        
        let config1 = MountConfiguration(
            id: UUID(),
            server: "server1.local",
            share: "share1",
            mountPoint: "/Volumes/share1",
            autoMount: true,
            rememberCredentials: false,
            syncEnabled: true,
            createdAt: Date(),
            lastModified: Date()
        )
        
        let config2 = MountConfiguration(
            id: UUID(),
            server: "server1.local",
            share: "share1",
            mountPoint: "/Volumes/share1",
            autoMount: true,
            rememberCredentials: false,
            syncEnabled: true,
            createdAt: Date(),
            lastModified: Date()
        )
        
        // ExportedConfiguration should be equal if all exported fields match
        let exported1 = ExportedConfiguration(from: config1)
        let exported2 = ExportedConfiguration(from: config2)
        
        XCTAssertEqual(exported1, exported2, "ExportedConfigurations with same data should be equal")
        
        // Different data should not be equal
        let config3 = MountConfiguration(
            id: UUID(),
            server: "server2.local",
            share: "share2",
            mountPoint: "/Volumes/share2",
            autoMount: false,
            rememberCredentials: true,
            syncEnabled: false,
            createdAt: Date(),
            lastModified: Date()
        )
        
        let exported3 = ExportedConfiguration(from: config3)
        XCTAssertNotEqual(exported1, exported3, "ExportedConfigurations with different data should not be equal")
    }
    
    /// Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
    ///
    /// Verifies that JSON encoding produces valid, parseable JSON.
    ///
    /// **Validates: Requirements 5.6**
    func testProperty11_ConfigExportImportRoundTrip_ValidJSON() {
        // Label: Feature: bottom-nav-refactor, Property 11: 配置导出导入往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = SystemConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 11: 配置导出导入往返 (valid JSON)"
        ) {
            // Generate random configurations
            let configs = SystemConfigMountConfigGenerator.randomArray(countRange: 0...10)
            
            // Export to JSON
            let export = ConfigurationExport(configurations: configs)
            guard let jsonData = try? export.toJSON() else {
                print("Failed to export configuration to JSON")
                return false
            }
            
            // Verify JSON is valid by parsing with JSONSerialization
            guard let _ = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
                print("Exported JSON is not valid")
                return false
            }
            
            // Verify JSON string is not empty
            guard let jsonString = String(data: jsonData, encoding: .utf8), !jsonString.isEmpty else {
                print("JSON string is empty")
                return false
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 11 failed: Exported JSON should be valid and parseable")
    }
}
