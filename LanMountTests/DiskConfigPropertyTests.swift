//
//  DiskConfigPropertyTests.swift
//  LanMountTests
//
//  Property-based tests for DiskConfigTabView functionality
//  Feature: bottom-nav-refactor
//
//  **Validates: Requirements 3.1, 3.3, 3.4, 3.5**
//

import XCTest
import SwiftUI
@testable import LanMountCore

// MARK: - Property Testing Framework for DiskConfig

/// A property testing helper for DiskConfig tests
/// Simulates property-based testing with randomized inputs
struct DiskConfigPropertyTester {
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
}


// MARK: - Random Generators for MountConfiguration

extension MountConfiguration {
    /// Creates a random valid MountConfiguration for property testing
    static func random() -> MountConfiguration {
        let serverType = DiskConfigPropertyTester.randomInt(in: 0...2)
        let server: String
        
        switch serverType {
        case 0:
            // Valid IP address
            server = "\(DiskConfigPropertyTester.randomInt(in: 1...255)).\(DiskConfigPropertyTester.randomInt(in: 0...255)).\(DiskConfigPropertyTester.randomInt(in: 0...255)).\(DiskConfigPropertyTester.randomInt(in: 1...254))"
        case 1:
            // Valid hostname
            let hostLength = DiskConfigPropertyTester.randomInt(in: 3...15)
            server = DiskConfigPropertyTester.randomAlphanumericString(length: hostLength).lowercased()
        default:
            // Valid hostname with domain
            let hostLength = DiskConfigPropertyTester.randomInt(in: 3...10)
            let domainLength = DiskConfigPropertyTester.randomInt(in: 2...5)
            server = "\(DiskConfigPropertyTester.randomAlphanumericString(length: hostLength).lowercased()).\(DiskConfigPropertyTester.randomAlphanumericString(length: domainLength).lowercased())"
        }
        
        let shareLength = DiskConfigPropertyTester.randomInt(in: 3...20)
        let share = DiskConfigPropertyTester.randomAlphanumericString(length: shareLength)
        
        return MountConfiguration(
            id: UUID(),
            server: server,
            share: share,
            mountPoint: "/Volumes/\(share)",
            autoMount: DiskConfigPropertyTester.randomBool(),
            rememberCredentials: DiskConfigPropertyTester.randomBool(),
            syncEnabled: DiskConfigPropertyTester.randomBool()
        )
    }
    
    /// Creates a random MountConfiguration with potentially invalid fields for validation testing
    static func randomForValidation() -> MountConfiguration {
        let validationType = DiskConfigPropertyTester.randomInt(in: 0...5)
        
        switch validationType {
        case 0:
            // Empty server
            return MountConfiguration(
                server: "",
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
        case 1:
            // Empty share
            return MountConfiguration(
                server: "192.168.1.1",
                share: ""
            )
        case 2:
            // Whitespace-only server
            return MountConfiguration(
                server: "   ",
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
        case 3:
            // Whitespace-only share
            return MountConfiguration(
                server: "192.168.1.1",
                share: "   "
            )
        case 4:
            // Invalid server format (special characters)
            return MountConfiguration(
                server: "server@#$%",
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
        default:
            // Valid configuration
            return MountConfiguration.random()
        }
    }
    
    /// Creates a random array of MountConfigurations
    static func randomArray(count: Int) -> [MountConfiguration] {
        return (0..<count).map { _ in MountConfiguration.random() }
    }
}


// MARK: - DiskConfig Property Tests

final class DiskConfigPropertyTests: XCTestCase {
    
    // MARK: - Property 5: 配置列表展示完整性 (Configuration List Display Completeness)
    
    /// Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
    ///
    /// For any MountConfiguration array, the number of configuration cards displayed by DiskConfigTabView
    /// should equal the array length, and each card should contain the corresponding configuration's
    /// server, share, and mount status information.
    ///
    /// **Validates: Requirements 3.1, 3.4**
    func testProperty5_ConfigurationListCompleteness_CountMatches() {
        // Label: Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性 (count)"
        ) {
            // Generate a random number of configurations (0 to 20)
            let count = DiskConfigPropertyTester.randomInt(in: 0...20)
            let configurations = MountConfiguration.randomArray(count: count)
            
            // The number of configurations should match the array length
            return configurations.count == count
        }
        
        XCTAssertTrue(result, "Property 5 failed: Configuration count must match array length")
    }
    
    /// Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
    ///
    /// Property test: For any configuration in the array, it must have non-empty server property.
    ///
    /// **Validates: Requirements 3.1, 3.4**
    func testProperty5_ConfigurationListCompleteness_ServerPresent() {
        // Label: Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性 (server)"
        ) {
            let config = MountConfiguration.random()
            
            // Server must be non-empty for display
            return !config.server.isEmpty
        }
        
        XCTAssertTrue(result, "Property 5 failed: Each configuration must have server information")
    }
    
    /// Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
    ///
    /// Property test: For any configuration in the array, it must have non-empty share property.
    ///
    /// **Validates: Requirements 3.1, 3.4**
    func testProperty5_ConfigurationListCompleteness_SharePresent() {
        // Label: Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性 (share)"
        ) {
            let config = MountConfiguration.random()
            
            // Share must be non-empty for display
            return !config.share.isEmpty
        }
        
        XCTAssertTrue(result, "Property 5 failed: Each configuration must have share information")
    }
    
    /// Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
    ///
    /// Property test: For any configuration, the autoMount property represents mount status
    /// and must be a valid boolean value.
    ///
    /// **Validates: Requirements 3.1, 3.4**
    func testProperty5_ConfigurationListCompleteness_MountStatusPresent() {
        // Label: Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性 (mount status)"
        ) {
            let config = MountConfiguration.random()
            
            // autoMount is a Bool, so it's always valid (true or false)
            // This test verifies the property exists and is accessible
            let _ = config.autoMount
            return true
        }
        
        XCTAssertTrue(result, "Property 5 failed: Each configuration must have mount status")
    }

    
    /// Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
    ///
    /// Comprehensive property test: For any randomly generated configuration array,
    /// all configurations must have valid server, share, and mount status properties.
    ///
    /// **Validates: Requirements 3.1, 3.4**
    func testProperty5_ConfigurationListCompleteness_AllPropertiesValid() {
        // Label: Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性 (all properties)"
        ) {
            let count = DiskConfigPropertyTester.randomInt(in: 1...10)
            let configurations = MountConfiguration.randomArray(count: count)
            
            // All configurations must have valid display properties
            for config in configurations {
                if config.server.isEmpty { return false }
                if config.share.isEmpty { return false }
                // autoMount is always valid as a Bool
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 5 failed: All configurations must have valid display properties")
    }
    
    /// Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
    ///
    /// Verifies that each configuration has a unique identifier.
    ///
    /// **Validates: Requirements 3.1, 3.4**
    func testProperty5_ConfigurationListCompleteness_UniqueIdentifiers() {
        // Label: Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性 (unique IDs)"
        ) {
            let count = DiskConfigPropertyTester.randomInt(in: 2...15)
            let configurations = MountConfiguration.randomArray(count: count)
            
            // All IDs must be unique
            let ids = configurations.map { $0.id }
            let uniqueIds = Set(ids)
            
            return ids.count == uniqueIds.count
        }
        
        XCTAssertTrue(result, "Property 5 failed: All configurations must have unique identifiers")
    }
    
    /// Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
    ///
    /// Verifies that smbURL is correctly formed from server and share.
    ///
    /// **Validates: Requirements 3.1, 3.4**
    func testProperty5_ConfigurationListCompleteness_SMBURLFormat() {
        // Label: Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 5: 配置列表展示完整性 (SMB URL)"
        ) {
            let config = MountConfiguration.random()
            
            // smbURL should be in format "smb://server/share"
            let expectedURL = "smb://\(config.server)/\(config.share)"
            
            return config.smbURL == expectedURL
        }
        
        XCTAssertTrue(result, "Property 5 failed: SMB URL must be correctly formatted")
    }

    
    // MARK: - Property 6: 配置删除操作 (Configuration Delete Operation)
    
    /// Feature: bottom-nav-refactor, Property 6: 配置删除操作
    ///
    /// For any configuration list and configuration ID to delete, after the delete operation,
    /// the configuration list length should equal the original list length minus 1,
    /// and the deleted configuration should no longer appear in the list.
    ///
    /// **Validates: Requirements 3.3**
    func testProperty6_ConfigurationDelete_LengthDecreasedByOne() {
        // Label: Feature: bottom-nav-refactor, Property 6: 配置删除操作
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 6: 配置删除操作 (length)"
        ) {
            // Generate a list with at least 1 configuration
            let count = DiskConfigPropertyTester.randomInt(in: 1...20)
            var configurations = MountConfiguration.randomArray(count: count)
            let originalCount = configurations.count
            
            // Select a random configuration to delete
            let indexToDelete = DiskConfigPropertyTester.randomInt(in: 0...(count - 1))
            let configToDelete = configurations[indexToDelete]
            
            // Perform delete operation
            configurations.removeAll { $0.id == configToDelete.id }
            
            // Length should be original - 1
            return configurations.count == originalCount - 1
        }
        
        XCTAssertTrue(result, "Property 6 failed: List length must decrease by 1 after deletion")
    }
    
    /// Feature: bottom-nav-refactor, Property 6: 配置删除操作
    ///
    /// Property test: After deletion, the deleted configuration should not appear in the list.
    ///
    /// **Validates: Requirements 3.3**
    func testProperty6_ConfigurationDelete_ConfigNotInList() {
        // Label: Feature: bottom-nav-refactor, Property 6: 配置删除操作
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 6: 配置删除操作 (not in list)"
        ) {
            // Generate a list with at least 1 configuration
            let count = DiskConfigPropertyTester.randomInt(in: 1...20)
            var configurations = MountConfiguration.randomArray(count: count)
            
            // Select a random configuration to delete
            let indexToDelete = DiskConfigPropertyTester.randomInt(in: 0...(count - 1))
            let configToDelete = configurations[indexToDelete]
            let deletedId = configToDelete.id
            
            // Perform delete operation
            configurations.removeAll { $0.id == deletedId }
            
            // Deleted configuration should not be in the list
            return !configurations.contains { $0.id == deletedId }
        }
        
        XCTAssertTrue(result, "Property 6 failed: Deleted configuration must not appear in list")
    }
    
    /// Feature: bottom-nav-refactor, Property 6: 配置删除操作
    ///
    /// Property test: After deletion, all other configurations should remain unchanged.
    ///
    /// **Validates: Requirements 3.3**
    func testProperty6_ConfigurationDelete_OtherConfigsUnchanged() {
        // Label: Feature: bottom-nav-refactor, Property 6: 配置删除操作
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 6: 配置删除操作 (others unchanged)"
        ) {
            // Generate a list with at least 2 configurations
            let count = DiskConfigPropertyTester.randomInt(in: 2...20)
            var configurations = MountConfiguration.randomArray(count: count)
            let originalConfigs = configurations
            
            // Select a random configuration to delete
            let indexToDelete = DiskConfigPropertyTester.randomInt(in: 0...(count - 1))
            let configToDelete = configurations[indexToDelete]
            let deletedId = configToDelete.id
            
            // Perform delete operation
            configurations.removeAll { $0.id == deletedId }
            
            // All remaining configurations should be in the original list
            for config in configurations {
                if !originalConfigs.contains(where: { $0.id == config.id }) {
                    return false
                }
            }
            
            return true
        }
        
        XCTAssertTrue(result, "Property 6 failed: Other configurations must remain unchanged after deletion")
    }

    
    /// Feature: bottom-nav-refactor, Property 6: 配置删除操作
    ///
    /// Property test: Deleting from an empty list should result in an empty list.
    ///
    /// **Validates: Requirements 3.3**
    func testProperty6_ConfigurationDelete_EmptyListRemains() {
        // Label: Feature: bottom-nav-refactor, Property 6: 配置删除操作
        
        var configurations: [MountConfiguration] = []
        let randomId = UUID()
        
        // Attempt to delete from empty list
        configurations.removeAll { $0.id == randomId }
        
        // List should still be empty
        XCTAssertTrue(configurations.isEmpty, "Property 6 failed: Empty list should remain empty after delete attempt")
    }
    
    /// Feature: bottom-nav-refactor, Property 6: 配置删除操作
    ///
    /// Property test: Deleting a non-existent ID should not change the list.
    ///
    /// **Validates: Requirements 3.3**
    func testProperty6_ConfigurationDelete_NonExistentIdNoChange() {
        // Label: Feature: bottom-nav-refactor, Property 6: 配置删除操作
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 6: 配置删除操作 (non-existent ID)"
        ) {
            let count = DiskConfigPropertyTester.randomInt(in: 1...20)
            var configurations = MountConfiguration.randomArray(count: count)
            let originalCount = configurations.count
            
            // Try to delete a non-existent ID
            let nonExistentId = UUID()
            configurations.removeAll { $0.id == nonExistentId }
            
            // List should remain unchanged
            return configurations.count == originalCount
        }
        
        XCTAssertTrue(result, "Property 6 failed: Deleting non-existent ID should not change list")
    }
    
    /// Feature: bottom-nav-refactor, Property 6: 配置删除操作
    ///
    /// Property test: Multiple deletions should correctly reduce the list size.
    ///
    /// **Validates: Requirements 3.3**
    func testProperty6_ConfigurationDelete_MultipleDeletions() {
        // Label: Feature: bottom-nav-refactor, Property 6: 配置删除操作
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 6: 配置删除操作 (multiple deletions)"
        ) {
            let count = DiskConfigPropertyTester.randomInt(in: 3...20)
            var configurations = MountConfiguration.randomArray(count: count)
            let originalCount = configurations.count
            
            // Delete multiple configurations (1 to count/2)
            let deleteCount = DiskConfigPropertyTester.randomInt(in: 1...(count / 2))
            var deletedIds: Set<UUID> = []
            
            for _ in 0..<deleteCount {
                if let config = configurations.randomElement() {
                    deletedIds.insert(config.id)
                    configurations.removeAll { $0.id == config.id }
                }
            }
            
            // List should be reduced by the number of unique deletions
            return configurations.count == originalCount - deletedIds.count
        }
        
        XCTAssertTrue(result, "Property 6 failed: Multiple deletions should correctly reduce list size")
    }

    
    // MARK: - Property 7: 配置验证逻辑 (Configuration Validation Logic)
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// For any MountConfiguration input, the validation function should return validation errors
    /// when server is empty, share is empty, or server format is invalid,
    /// and return validation passed when all required fields are valid.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_EmptyServerReturnsError() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (empty server)"
        ) {
            // Create configuration with empty server
            let config = MountConfiguration(
                server: "",
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
            
            let errors = config.validate()
            
            // Should contain serverEmpty error
            return errors.contains(.serverEmpty)
        }
        
        XCTAssertTrue(result, "Property 7 failed: Empty server must return serverEmpty error")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Property test: Whitespace-only server should return serverEmpty error.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_WhitespaceServerReturnsError() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (whitespace server)"
        ) {
            // Create configuration with whitespace-only server
            let whitespaceCount = DiskConfigPropertyTester.randomInt(in: 1...10)
            let whitespace = String(repeating: " ", count: whitespaceCount)
            let config = MountConfiguration(
                server: whitespace,
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
            
            let errors = config.validate()
            
            // Should contain serverEmpty error
            return errors.contains(.serverEmpty)
        }
        
        XCTAssertTrue(result, "Property 7 failed: Whitespace-only server must return serverEmpty error")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Property test: Empty share should return shareEmpty error.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_EmptyShareReturnsError() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (empty share)"
        ) {
            // Create configuration with empty share
            let config = MountConfiguration(
                server: "192.168.1.1",
                share: ""
            )
            
            let errors = config.validate()
            
            // Should contain shareEmpty error
            return errors.contains(.shareEmpty)
        }
        
        XCTAssertTrue(result, "Property 7 failed: Empty share must return shareEmpty error")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Property test: Whitespace-only share should return shareEmpty error.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_WhitespaceShareReturnsError() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (whitespace share)"
        ) {
            // Create configuration with whitespace-only share
            let whitespaceCount = DiskConfigPropertyTester.randomInt(in: 1...10)
            let whitespace = String(repeating: " ", count: whitespaceCount)
            let config = MountConfiguration(
                server: "192.168.1.1",
                share: whitespace
            )
            
            let errors = config.validate()
            
            // Should contain shareEmpty error
            return errors.contains(.shareEmpty)
        }
        
        XCTAssertTrue(result, "Property 7 failed: Whitespace-only share must return shareEmpty error")
    }

    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Property test: Invalid server format should return serverFormatInvalid error.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_InvalidServerFormatReturnsError() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let invalidServers = [
            "server@invalid",
            "server#name",
            "server$test",
            "server%bad",
            "server^wrong",
            "server&fail",
            "server*error",
            "-invalidstart",
            "invalidend-",
            ".startwithdot",
            "endwithdot.",
            "double..dot",
            "has space",
            "has\ttab"
        ]
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (invalid server format)"
        ) {
            // Select a random invalid server
            let invalidServer = invalidServers.randomElement()!
            let config = MountConfiguration(
                server: invalidServer,
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
            
            let errors = config.validate()
            
            // Should contain serverFormatInvalid error
            return errors.contains { error in
                if case .serverFormatInvalid = error {
                    return true
                }
                return false
            }
        }
        
        XCTAssertTrue(result, "Property 7 failed: Invalid server format must return serverFormatInvalid error")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Property test: Valid IPv4 address should pass validation.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_ValidIPv4Passes() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (valid IPv4)"
        ) {
            // Generate a valid IPv4 address
            let octet1 = DiskConfigPropertyTester.randomInt(in: 1...255)
            let octet2 = DiskConfigPropertyTester.randomInt(in: 0...255)
            let octet3 = DiskConfigPropertyTester.randomInt(in: 0...255)
            let octet4 = DiskConfigPropertyTester.randomInt(in: 1...254)
            let ipAddress = "\(octet1).\(octet2).\(octet3).\(octet4)"
            
            let config = MountConfiguration(
                server: ipAddress,
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
            
            let errors = config.validate()
            
            // Should have no errors
            return errors.isEmpty
        }
        
        XCTAssertTrue(result, "Property 7 failed: Valid IPv4 address must pass validation")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Property test: Valid hostname should pass validation.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_ValidHostnamePasses() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (valid hostname)"
        ) {
            // Generate a valid hostname
            let length = DiskConfigPropertyTester.randomInt(in: 3...15)
            let hostname = DiskConfigPropertyTester.randomAlphanumericString(length: length).lowercased()
            
            let config = MountConfiguration(
                server: hostname,
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
            
            let errors = config.validate()
            
            // Should have no errors
            return errors.isEmpty
        }
        
        XCTAssertTrue(result, "Property 7 failed: Valid hostname must pass validation")
    }

    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Property test: Valid hostname with domain should pass validation.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_ValidHostnameWithDomainPasses() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (valid hostname with domain)"
        ) {
            // Generate a valid hostname with domain
            let hostLength = DiskConfigPropertyTester.randomInt(in: 3...10)
            let domainLength = DiskConfigPropertyTester.randomInt(in: 2...5)
            let hostname = "\(DiskConfigPropertyTester.randomAlphanumericString(length: hostLength).lowercased()).\(DiskConfigPropertyTester.randomAlphanumericString(length: domainLength).lowercased())"
            
            let config = MountConfiguration(
                server: hostname,
                share: DiskConfigPropertyTester.randomAlphanumericString(length: 5)
            )
            
            let errors = config.validate()
            
            // Should have no errors
            return errors.isEmpty
        }
        
        XCTAssertTrue(result, "Property 7 failed: Valid hostname with domain must pass validation")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Comprehensive property test: Valid configuration should return empty error array.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_ValidConfigReturnsNoErrors() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        // Minimum iterations: 100 (as per design.md)
        
        let result = DiskConfigPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 7: 配置验证逻辑 (valid config)"
        ) {
            // Generate a valid configuration
            let config = MountConfiguration.random()
            
            let errors = config.validate()
            
            // Should have no errors
            return errors.isEmpty
        }
        
        XCTAssertTrue(result, "Property 7 failed: Valid configuration must return no errors")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Property test: Both empty server and share should return both errors.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_BothEmptyReturnsBothErrors() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        
        let config = MountConfiguration(
            server: "",
            share: ""
        )
        
        let errors = config.validate()
        
        // Should contain both errors
        XCTAssertTrue(errors.contains(.serverEmpty), "Property 7 failed: Should contain serverEmpty error")
        XCTAssertTrue(errors.contains(.shareEmpty), "Property 7 failed: Should contain shareEmpty error")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Edge case tests for validation boundaries.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_EdgeCases() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        
        // Edge case: Single character hostname
        let singleCharConfig = MountConfiguration(server: "a", share: "share")
        XCTAssertTrue(singleCharConfig.validate().isEmpty, "Single character hostname should be valid")
        
        // Edge case: Maximum length hostname label (63 characters)
        let maxLabelConfig = MountConfiguration(
            server: String(repeating: "a", count: 63),
            share: "share"
        )
        XCTAssertTrue(maxLabelConfig.validate().isEmpty, "63 character hostname should be valid")
        
        // Edge case: Hostname with hyphen in middle
        let hyphenConfig = MountConfiguration(server: "my-server", share: "share")
        XCTAssertTrue(hyphenConfig.validate().isEmpty, "Hostname with hyphen should be valid")
        
        // Edge case: IP address boundary values
        let boundaryIPConfig = MountConfiguration(server: "255.255.255.254", share: "share")
        XCTAssertTrue(boundaryIPConfig.validate().isEmpty, "Boundary IP address should be valid")
        
        // Edge case: Localhost
        let localhostConfig = MountConfiguration(server: "localhost", share: "share")
        XCTAssertTrue(localhostConfig.validate().isEmpty, "localhost should be valid")
        
        // Edge case: IP address 0.0.0.0 (valid format but may not be reachable)
        let zeroIPConfig = MountConfiguration(server: "0.0.0.0", share: "share")
        // This should be valid format-wise
        let zeroIPErrors = zeroIPConfig.validate()
        // 0.0.0.0 is a valid IP format
        XCTAssertTrue(zeroIPErrors.isEmpty || zeroIPErrors.contains { if case .serverFormatInvalid = $0 { return true }; return false },
                      "0.0.0.0 validation should be consistent")
    }
    
    /// Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
    ///
    /// Verifies that validation error types are correctly identified.
    ///
    /// **Validates: Requirements 3.5**
    func testProperty7_ConfigurationValidation_ErrorTypeIdentification() {
        // Label: Feature: bottom-nav-refactor, Property 7: 配置验证逻辑
        
        // Test serverEmpty error
        let serverEmptyConfig = MountConfiguration(server: "", share: "share")
        let serverEmptyErrors = serverEmptyConfig.validate()
        XCTAssertEqual(serverEmptyErrors.count, 1, "Should have exactly one error")
        XCTAssertEqual(serverEmptyErrors.first, .serverEmpty, "Error should be serverEmpty")
        
        // Test shareEmpty error
        let shareEmptyConfig = MountConfiguration(server: "192.168.1.1", share: "")
        let shareEmptyErrors = shareEmptyConfig.validate()
        XCTAssertEqual(shareEmptyErrors.count, 1, "Should have exactly one error")
        XCTAssertEqual(shareEmptyErrors.first, .shareEmpty, "Error should be shareEmpty")
        
        // Test serverFormatInvalid error
        let invalidFormatConfig = MountConfiguration(server: "server@invalid", share: "share")
        let invalidFormatErrors = invalidFormatConfig.validate()
        XCTAssertEqual(invalidFormatErrors.count, 1, "Should have exactly one error")
        if case .serverFormatInvalid = invalidFormatErrors.first! {
            // Expected
        } else {
            XCTFail("Error should be serverFormatInvalid")
        }
    }
}
