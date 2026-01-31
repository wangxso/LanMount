//
//  NavigationModelsPropertyTests.swift
//  LanMountTests
//
//  Property-based tests for NavigationModels (AppTab and TabBadgeData)
//  Feature: bottom-nav-refactor
//
//  **Validates: Requirements 1.1, 1.2, 8.5**
//

import XCTest
import SwiftUI
@testable import LanMountCore

// MARK: - Property Testing Framework

/// A simple property testing helper that generates random test cases
/// Simulates property-based testing with randomized inputs
struct NavigationPropertyTester {
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
}

// MARK: - Random Generators for TabBadgeData

extension TabBadgeData.BadgeType {
    /// Creates a random BadgeType for property testing
    static func random() -> TabBadgeData.BadgeType {
        if NavigationPropertyTester.randomBool() {
            // Generate count type with random value (including edge cases)
            let count = NavigationPropertyTester.randomInt(in: -10...200)
            return .count(count)
        } else {
            return .dot
        }
    }
    
    /// Creates a random count BadgeType with a specific range
    static func randomCount(in range: ClosedRange<Int>) -> TabBadgeData.BadgeType {
        return .count(NavigationPropertyTester.randomInt(in: range))
    }
}

extension TabBadgeData.BadgeColor {
    /// Creates a random BadgeColor for property testing
    static func random() -> TabBadgeData.BadgeColor {
        let colors: [TabBadgeData.BadgeColor] = [.red, .orange, .blue, .green]
        return colors.randomElement()!
    }
}

extension TabBadgeData {
    /// Creates a random TabBadgeData for property testing
    static func random() -> TabBadgeData {
        return TabBadgeData(
            type: BadgeType.random(),
            color: BadgeColor.random()
        )
    }
    
    /// Creates a random TabBadgeData with count type
    static func randomWithCount(in range: ClosedRange<Int>) -> TabBadgeData {
        return TabBadgeData(
            type: .count(NavigationPropertyTester.randomInt(in: range)),
            color: BadgeColor.random()
        )
    }
    
    /// Creates a random TabBadgeData with dot type
    static func randomWithDot() -> TabBadgeData {
        return TabBadgeData(
            type: .dot,
            color: BadgeColor.random()
        )
    }
}

extension AppTab {
    /// Creates a random AppTab for property testing
    static func random() -> AppTab {
        return AppTab.allCases.randomElement()!
    }
}

// MARK: - NavigationModels Property Tests

final class NavigationModelsPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Tab_Bar 结构完整性 (Tab Bar Structural Integrity)
    
    /// Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
    ///
    /// For any AppTab enum, it must contain at least 4 tabs (overview, diskConfig, diskInfo, systemConfig),
    /// and each tab must have valid title, icon, and keyboardShortcut properties.
    ///
    /// **Validates: Requirements 1.1, 1.2**
    func testProperty1_TabBarStructuralIntegrity_MinimumTabCount() {
        // Label: Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
        
        // Verify AppTab has at least 4 cases
        let allTabs = AppTab.allCases
        XCTAssertGreaterThanOrEqual(
            allTabs.count, 4,
            "Property 1 failed: AppTab must contain at least 4 tabs"
        )
    }
    
    /// Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
    ///
    /// Verifies that all required tabs (overview, diskConfig, diskInfo, systemConfig) exist.
    ///
    /// **Validates: Requirements 1.1, 1.2**
    func testProperty1_TabBarStructuralIntegrity_RequiredTabsExist() {
        // Label: Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
        
        let allTabs = AppTab.allCases
        
        // Verify all required tabs exist
        XCTAssertTrue(
            allTabs.contains(.overview),
            "Property 1 failed: AppTab must contain overview tab"
        )
        XCTAssertTrue(
            allTabs.contains(.diskConfig),
            "Property 1 failed: AppTab must contain diskConfig tab"
        )
        XCTAssertTrue(
            allTabs.contains(.diskInfo),
            "Property 1 failed: AppTab must contain diskInfo tab"
        )
        XCTAssertTrue(
            allTabs.contains(.systemConfig),
            "Property 1 failed: AppTab must contain systemConfig tab"
        )
    }
    
    /// Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
    ///
    /// Property test: For any randomly selected AppTab, it must have a valid (non-empty) title property.
    ///
    /// **Validates: Requirements 1.1, 1.2**
    func testProperty1_TabBarStructuralIntegrity_ValidTitle() {
        // Label: Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性 (title)"
        ) {
            let tab = AppTab.random()
            
            // Title must be non-empty
            let hasValidTitle = !tab.title.isEmpty
            
            return hasValidTitle
        }
        
        XCTAssertTrue(result, "Property 1 failed: All AppTab instances must have valid (non-empty) title")
    }
    
    /// Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
    ///
    /// Property test: For any randomly selected AppTab, it must have a valid (non-empty) icon property.
    ///
    /// **Validates: Requirements 1.1, 1.2**
    func testProperty1_TabBarStructuralIntegrity_ValidIcon() {
        // Label: Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性 (icon)"
        ) {
            let tab = AppTab.random()
            
            // Icon must be non-empty (SF Symbol name)
            let hasValidIcon = !tab.icon.isEmpty
            
            return hasValidIcon
        }
        
        XCTAssertTrue(result, "Property 1 failed: All AppTab instances must have valid (non-empty) icon")
    }
    
    /// Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
    ///
    /// Property test: For any randomly selected AppTab, it must have a valid keyboardShortcut property
    /// that is one of the expected values ("1", "2", "3", "4").
    ///
    /// **Validates: Requirements 1.1, 1.2**
    func testProperty1_TabBarStructuralIntegrity_ValidKeyboardShortcut() {
        // Label: Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
        // Minimum iterations: 100 (as per design.md)
        
        let validShortcuts: Set<KeyEquivalent> = ["1", "2", "3", "4"]
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性 (keyboardShortcut)"
        ) {
            let tab = AppTab.random()
            
            // KeyboardShortcut must be one of the valid values
            let hasValidShortcut = validShortcuts.contains(tab.keyboardShortcut)
            
            return hasValidShortcut
        }
        
        XCTAssertTrue(result, "Property 1 failed: All AppTab instances must have valid keyboardShortcut")
    }
    
    /// Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
    ///
    /// Comprehensive property test: For any randomly selected AppTab, all three properties
    /// (title, icon, keyboardShortcut) must be valid simultaneously.
    ///
    /// **Validates: Requirements 1.1, 1.2**
    func testProperty1_TabBarStructuralIntegrity_AllPropertiesValid() {
        // Label: Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
        // Minimum iterations: 100 (as per design.md)
        
        let validShortcuts: Set<KeyEquivalent> = ["1", "2", "3", "4"]
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性 (all properties)"
        ) {
            let tab = AppTab.random()
            
            // All properties must be valid
            let hasValidTitle = !tab.title.isEmpty
            let hasValidIcon = !tab.icon.isEmpty
            let hasValidShortcut = validShortcuts.contains(tab.keyboardShortcut)
            
            return hasValidTitle && hasValidIcon && hasValidShortcut
        }
        
        XCTAssertTrue(result, "Property 1 failed: All AppTab instances must have all valid properties")
    }
    
    /// Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
    ///
    /// Verifies that each specific tab has the expected properties.
    ///
    /// **Validates: Requirements 1.1, 1.2**
    func testProperty1_TabBarStructuralIntegrity_SpecificTabProperties() {
        // Label: Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
        
        // Test each tab individually
        for tab in AppTab.allCases {
            XCTAssertFalse(tab.title.isEmpty, "Tab \(tab) must have non-empty title")
            XCTAssertFalse(tab.icon.isEmpty, "Tab \(tab) must have non-empty icon")
            
            // Verify each tab has a unique raw value (0, 1, 2, 3)
            XCTAssertGreaterThanOrEqual(tab.rawValue, 0, "Tab \(tab) rawValue must be >= 0")
            XCTAssertLessThan(tab.rawValue, AppTab.allCases.count, "Tab \(tab) rawValue must be < tab count")
        }
    }
    
    /// Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
    ///
    /// Verifies that tab IDs are unique and match raw values.
    ///
    /// **Validates: Requirements 1.1, 1.2**
    func testProperty1_TabBarStructuralIntegrity_UniqueIdentifiers() {
        // Label: Feature: bottom-nav-refactor, Property 1: Tab_Bar 结构完整性
        
        let allTabs = AppTab.allCases
        let ids = allTabs.map { $0.id }
        let uniqueIds = Set(ids)
        
        // All IDs must be unique
        XCTAssertEqual(
            ids.count, uniqueIds.count,
            "Property 1 failed: All AppTab instances must have unique IDs"
        )
        
        // ID must equal rawValue
        for tab in allTabs {
            XCTAssertEqual(
                tab.id, tab.rawValue,
                "Property 1 failed: Tab \(tab) id must equal rawValue"
            )
        }
    }
    
    // MARK: - Property 15: 徽章类型支持 (Badge Type Support)
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// For any TabBadgeData with count type, shouldShow should return true when count > 0.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_CountPositive_ShouldShowTrue() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 15: 徽章类型支持 (count > 0)"
        ) {
            // Generate a positive count (1 to 200)
            let count = NavigationPropertyTester.randomInt(in: 1...200)
            let badge = TabBadgeData(type: .count(count), color: .random())
            
            // shouldShow must be true when count > 0
            return badge.shouldShow == true
        }
        
        XCTAssertTrue(result, "Property 15 failed: shouldShow must be true when count > 0")
    }
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// For any TabBadgeData with count type, shouldShow should return false when count <= 0.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_CountZeroOrNegative_ShouldShowFalse() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 15: 徽章类型支持 (count <= 0)"
        ) {
            // Generate a zero or negative count (-100 to 0)
            let count = NavigationPropertyTester.randomInt(in: -100...0)
            let badge = TabBadgeData(type: .count(count), color: .random())
            
            // shouldShow must be false when count <= 0
            return badge.shouldShow == false
        }
        
        XCTAssertTrue(result, "Property 15 failed: shouldShow must be false when count <= 0")
    }
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// For any TabBadgeData with dot type, shouldShow should always return true.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_DotType_ShouldShowAlwaysTrue() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 15: 徽章类型支持 (dot type)"
        ) {
            // Create a dot badge with random color
            let badge = TabBadgeData(type: .dot, color: .random())
            
            // shouldShow must always be true for dot type
            return badge.shouldShow == true
        }
        
        XCTAssertTrue(result, "Property 15 failed: shouldShow must always be true for dot type")
    }
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// Comprehensive property test: For any randomly generated TabBadgeData,
    /// shouldShow should follow the rule: true if count > 0 OR type is dot.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_ComprehensiveRule() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 15: 徽章类型支持 (comprehensive)"
        ) {
            let badge = TabBadgeData.random()
            
            // Calculate expected shouldShow value
            let expectedShouldShow: Bool
            switch badge.type {
            case .count(let count):
                expectedShouldShow = count > 0
            case .dot:
                expectedShouldShow = true
            }
            
            // Actual shouldShow must match expected
            return badge.shouldShow == expectedShouldShow
        }
        
        XCTAssertTrue(result, "Property 15 failed: shouldShow must follow the rule (count > 0 OR type is dot)")
    }
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// Verifies that both badge types (count and dot) are supported.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_BothTypesSupported() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        
        // Test count type
        let countBadge = TabBadgeData(type: .count(5), color: .blue)
        XCTAssertEqual(countBadge.shouldShow, true, "Count badge with count=5 should show")
        
        let zeroBadge = TabBadgeData(type: .count(0), color: .red)
        XCTAssertEqual(zeroBadge.shouldShow, false, "Count badge with count=0 should not show")
        
        // Test dot type
        let dotBadge = TabBadgeData(type: .dot, color: .orange)
        XCTAssertEqual(dotBadge.shouldShow, true, "Dot badge should always show")
    }
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// Verifies that all badge colors are supported.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_AllColorsSupported() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        
        let colors: [TabBadgeData.BadgeColor] = [.red, .orange, .blue, .green]
        
        for badgeColor in colors {
            // Test with count type
            let countBadge = TabBadgeData(type: .count(1), color: badgeColor)
            XCTAssertTrue(countBadge.shouldShow, "Badge with color \(badgeColor) and count=1 should show")
            
            // Test with dot type
            let dotBadge = TabBadgeData(type: .dot, color: badgeColor)
            XCTAssertTrue(dotBadge.shouldShow, "Dot badge with color \(badgeColor) should show")
            
            // Verify color property returns a valid Color
            // (Color type is always valid if it compiles)
            _ = badgeColor.color
        }
    }
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// Property test: Badge color should not affect shouldShow behavior.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_ColorDoesNotAffectShouldShow() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 15: 徽章类型支持 (color independence)"
        ) {
            // Generate a random badge type
            let badgeType = TabBadgeData.BadgeType.random()
            
            // Create badges with different colors but same type
            let badge1 = TabBadgeData(type: badgeType, color: .red)
            let badge2 = TabBadgeData(type: badgeType, color: .blue)
            let badge3 = TabBadgeData(type: badgeType, color: .orange)
            let badge4 = TabBadgeData(type: badgeType, color: .green)
            
            // All badges with the same type should have the same shouldShow value
            return badge1.shouldShow == badge2.shouldShow
                && badge2.shouldShow == badge3.shouldShow
                && badge3.shouldShow == badge4.shouldShow
        }
        
        XCTAssertTrue(result, "Property 15 failed: Badge color should not affect shouldShow behavior")
    }
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// Edge case tests for badge count boundaries.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_EdgeCases() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        
        // Edge case: count = 0
        let zeroBadge = TabBadgeData(type: .count(0), color: .red)
        XCTAssertFalse(zeroBadge.shouldShow, "Badge with count=0 should not show")
        
        // Edge case: count = 1 (minimum positive)
        let oneBadge = TabBadgeData(type: .count(1), color: .blue)
        XCTAssertTrue(oneBadge.shouldShow, "Badge with count=1 should show")
        
        // Edge case: count = -1 (negative)
        let negativeBadge = TabBadgeData(type: .count(-1), color: .orange)
        XCTAssertFalse(negativeBadge.shouldShow, "Badge with count=-1 should not show")
        
        // Edge case: count = 99 (typical max display)
        let maxDisplayBadge = TabBadgeData(type: .count(99), color: .green)
        XCTAssertTrue(maxDisplayBadge.shouldShow, "Badge with count=99 should show")
        
        // Edge case: count = 100 (above typical max display)
        let overMaxBadge = TabBadgeData(type: .count(100), color: .red)
        XCTAssertTrue(overMaxBadge.shouldShow, "Badge with count=100 should show")
        
        // Edge case: very large count
        let largeBadge = TabBadgeData(type: .count(Int.max), color: .blue)
        XCTAssertTrue(largeBadge.shouldShow, "Badge with very large count should show")
        
        // Edge case: very negative count
        let veryNegativeBadge = TabBadgeData(type: .count(Int.min), color: .orange)
        XCTAssertFalse(veryNegativeBadge.shouldShow, "Badge with very negative count should not show")
    }
    
    /// Feature: bottom-nav-refactor, Property 15: 徽章类型支持
    ///
    /// Verifies TabBadgeData Equatable conformance.
    ///
    /// **Validates: Requirements 8.5**
    func testProperty15_BadgeTypeSupport_Equatable() {
        // Label: Feature: bottom-nav-refactor, Property 15: 徽章类型支持
        
        // Same type and color should be equal
        let badge1 = TabBadgeData(type: .count(5), color: .red)
        let badge2 = TabBadgeData(type: .count(5), color: .red)
        XCTAssertEqual(badge1, badge2, "Badges with same type and color should be equal")
        
        // Different count should not be equal
        let badge3 = TabBadgeData(type: .count(10), color: .red)
        XCTAssertNotEqual(badge1, badge3, "Badges with different count should not be equal")
        
        // Different color should not be equal
        let badge4 = TabBadgeData(type: .count(5), color: .blue)
        XCTAssertNotEqual(badge1, badge4, "Badges with different color should not be equal")
        
        // Different type should not be equal
        let badge5 = TabBadgeData(type: .dot, color: .red)
        XCTAssertNotEqual(badge1, badge5, "Badges with different type should not be equal")
        
        // Dot badges with same color should be equal
        let dotBadge1 = TabBadgeData(type: .dot, color: .orange)
        let dotBadge2 = TabBadgeData(type: .dot, color: .orange)
        XCTAssertEqual(dotBadge1, dotBadge2, "Dot badges with same color should be equal")
    }
}
