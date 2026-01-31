//
//  TabNavigationControllerPropertyTests.swift
//  LanMountTests
//
//  Property-based tests for TabNavigationController
//  Feature: bottom-nav-refactor
//
//  **Validates: Requirements 1.3, 7.1, 7.2, 7.3, 7.4**
//

import XCTest
import SwiftUI
@testable import LanMountCore

// MARK: - TabNavigationController Property Tests

@MainActor
final class TabNavigationControllerPropertyTests: XCTestCase {
    
    // MARK: - Test Setup
    
    /// Creates a fresh UserDefaults instance for testing
    /// Uses a unique suite name to avoid conflicts with other tests
    private func createTestUserDefaults() -> UserDefaults {
        let suiteName = "com.lanmount.tests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        return userDefaults
    }
    
    /// Cleans up a test UserDefaults instance
    private func cleanupTestUserDefaults(_ userDefaults: UserDefaults) {
        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }
    
    // MARK: - Property 2: 导航切换一致性 (Navigation Switching Consistency)
    
    /// Feature: bottom-nav-refactor, Property 2: 导航切换一致性
    ///
    /// For any AppTab value, when TabNavigationController's selectedTab is set to that value,
    /// the selectedTab property should immediately reflect that value and not automatically
    /// change to another value.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty2_NavigationSwitchingConsistency_SelectedTabReflectsSetValue() {
        // Label: Feature: bottom-nav-refactor, Property 2: 导航切换一致性
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 2: 导航切换一致性 (set value)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            let randomTab = AppTab.random()
            
            // Set the selected tab
            controller.selectedTab = randomTab
            
            // The selectedTab should immediately reflect the set value
            return controller.selectedTab == randomTab
        }
        
        XCTAssertTrue(result, "Property 2 failed: selectedTab should immediately reflect the set value")
    }
    
    /// Feature: bottom-nav-refactor, Property 2: 导航切换一致性
    ///
    /// Verifies that selectedTab does not automatically change after being set.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty2_NavigationSwitchingConsistency_SelectedTabDoesNotAutoChange() {
        // Label: Feature: bottom-nav-refactor, Property 2: 导航切换一致性
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 2: 导航切换一致性 (no auto change)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            let randomTab = AppTab.random()
            
            // Set the selected tab
            controller.selectedTab = randomTab
            
            // Read the value multiple times to ensure it doesn't change
            let firstRead = controller.selectedTab
            let secondRead = controller.selectedTab
            let thirdRead = controller.selectedTab
            
            // All reads should return the same value
            return firstRead == randomTab && secondRead == randomTab && thirdRead == randomTab
        }
        
        XCTAssertTrue(result, "Property 2 failed: selectedTab should not automatically change after being set")
    }
    
    /// Feature: bottom-nav-refactor, Property 2: 导航切换一致性
    ///
    /// Verifies that switchTo method correctly updates selectedTab.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty2_NavigationSwitchingConsistency_SwitchToMethod() {
        // Label: Feature: bottom-nav-refactor, Property 2: 导航切换一致性
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 2: 导航切换一致性 (switchTo method)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            let randomTab = AppTab.random()
            
            // Use switchTo method
            controller.switchTo(randomTab)
            
            // The selectedTab should reflect the switched value
            return controller.selectedTab == randomTab
        }
        
        XCTAssertTrue(result, "Property 2 failed: switchTo method should correctly update selectedTab")
    }
    
    /// Feature: bottom-nav-refactor, Property 2: 导航切换一致性
    ///
    /// Verifies that multiple consecutive tab switches work correctly.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty2_NavigationSwitchingConsistency_ConsecutiveSwitches() {
        // Label: Feature: bottom-nav-refactor, Property 2: 导航切换一致性
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 2: 导航切换一致性 (consecutive switches)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            
            // Perform multiple random switches
            var lastTab: AppTab = .overview
            for _ in 0..<5 {
                let randomTab = AppTab.random()
                controller.switchTo(randomTab)
                lastTab = randomTab
            }
            
            // The final selectedTab should be the last switched tab
            return controller.selectedTab == lastTab
        }
        
        XCTAssertTrue(result, "Property 2 failed: consecutive switches should work correctly")
    }
    
    // MARK: - Property 3: 导航状态持久化往返 (Navigation State Persistence Round-Trip)
    
    /// Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
    ///
    /// For any AppTab value, after setting it as selectedTab, creating a new
    /// TabNavigationController instance should restore the same tab value
    /// (via UserDefaults persistence).
    ///
    /// **Validates: Requirements 7.1, 7.2**
    func testProperty3_NavigationStatePersistence_RoundTrip() {
        // Label: Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返 (round-trip)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let randomTab = AppTab.random()
            
            // Create first controller and set tab
            let controller1 = TabNavigationController(userDefaults: userDefaults)
            controller1.selectedTab = randomTab
            
            // Create second controller with same UserDefaults
            let controller2 = TabNavigationController(userDefaults: userDefaults)
            
            // The second controller should restore the same tab
            return controller2.selectedTab == randomTab
        }
        
        XCTAssertTrue(result, "Property 3 failed: new controller instance should restore the same tab value")
    }
    
    /// Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
    ///
    /// Verifies that persistence works correctly for all tab values.
    ///
    /// **Validates: Requirements 7.1, 7.2**
    func testProperty3_NavigationStatePersistence_AllTabs() {
        // Label: Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
        
        // Test each tab explicitly
        for tab in AppTab.allCases {
            let userDefaults = createTestUserDefaults()
            defer { cleanupTestUserDefaults(userDefaults) }
            
            // Create first controller and set tab
            let controller1 = TabNavigationController(userDefaults: userDefaults)
            controller1.selectedTab = tab
            
            // Create second controller with same UserDefaults
            let controller2 = TabNavigationController(userDefaults: userDefaults)
            
            XCTAssertEqual(
                controller2.selectedTab, tab,
                "Property 3 failed: Tab \(tab) should be restored after persistence"
            )
        }
    }
    
    /// Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
    ///
    /// Verifies that invalid saved index defaults to overview tab.
    ///
    /// **Validates: Requirements 7.1, 7.2**
    func testProperty3_NavigationStatePersistence_InvalidIndexDefaultsToOverview() {
        // Label: Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
        
        let userDefaults = createTestUserDefaults()
        defer { cleanupTestUserDefaults(userDefaults) }
        
        // Set an invalid tab index directly in UserDefaults
        userDefaults.set(999, forKey: "selectedTabIndex")
        
        // Create controller - should default to overview
        let controller = TabNavigationController(userDefaults: userDefaults)
        
        XCTAssertEqual(
            controller.selectedTab, .overview,
            "Property 3 failed: Invalid saved index should default to overview tab"
        )
    }
    
    /// Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
    ///
    /// Verifies that negative saved index defaults to overview tab.
    ///
    /// **Validates: Requirements 7.1, 7.2**
    func testProperty3_NavigationStatePersistence_NegativeIndexDefaultsToOverview() {
        // Label: Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
        
        let userDefaults = createTestUserDefaults()
        defer { cleanupTestUserDefaults(userDefaults) }
        
        // Set a negative tab index directly in UserDefaults
        userDefaults.set(-1, forKey: "selectedTabIndex")
        
        // Create controller - should default to overview
        let controller = TabNavigationController(userDefaults: userDefaults)
        
        XCTAssertEqual(
            controller.selectedTab, .overview,
            "Property 3 failed: Negative saved index should default to overview tab"
        )
    }
    
    /// Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
    ///
    /// Property test: Multiple persistence cycles should maintain consistency.
    ///
    /// **Validates: Requirements 7.1, 7.2**
    func testProperty3_NavigationStatePersistence_MultipleCycles() {
        // Label: Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 3: 导航状态持久化往返 (multiple cycles)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            var lastTab: AppTab = .overview
            
            // Perform multiple save/restore cycles
            for _ in 0..<3 {
                let randomTab = AppTab.random()
                
                // Create controller and set tab
                let controller = TabNavigationController(userDefaults: userDefaults)
                controller.selectedTab = randomTab
                lastTab = randomTab
            }
            
            // Final restore should match last saved tab
            let finalController = TabNavigationController(userDefaults: userDefaults)
            return finalController.selectedTab == lastTab
        }
        
        XCTAssertTrue(result, "Property 3 failed: Multiple persistence cycles should maintain consistency")
    }
    
    // MARK: - Property 4: 键盘快捷键映射 (Keyboard Shortcut Mapping)
    
    /// Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
    ///
    /// For any AppTab value, its keyboardShortcut property should return the
    /// corresponding number key (overview="1", diskConfig="2", diskInfo="3", systemConfig="4").
    ///
    /// **Validates: Requirements 7.3**
    func testProperty4_KeyboardShortcutMapping_CorrectMapping() {
        // Label: Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
        // Minimum iterations: 100 (as per design.md)
        
        let expectedMappings: [AppTab: KeyEquivalent] = [
            .overview: "1",
            .diskConfig: "2",
            .diskInfo: "3",
            .systemConfig: "4"
        ]
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射 (correct mapping)"
        ) {
            let randomTab = AppTab.random()
            
            // Get the expected shortcut for this tab
            guard let expectedShortcut = expectedMappings[randomTab] else {
                return false
            }
            
            // Verify the mapping is correct
            return randomTab.keyboardShortcut == expectedShortcut
        }
        
        XCTAssertTrue(result, "Property 4 failed: keyboardShortcut should return correct number key")
    }
    
    /// Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
    ///
    /// Verifies that each tab has a unique keyboard shortcut.
    ///
    /// **Validates: Requirements 7.3**
    func testProperty4_KeyboardShortcutMapping_UniqueShortcuts() {
        // Label: Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
        
        let allTabs = AppTab.allCases
        var shortcuts: [KeyEquivalent] = []
        
        for tab in allTabs {
            let shortcut = tab.keyboardShortcut
            
            // Check that this shortcut hasn't been seen before
            XCTAssertFalse(
                shortcuts.contains(shortcut),
                "Property 4 failed: Tab \(tab) has duplicate keyboard shortcut"
            )
            
            shortcuts.append(shortcut)
        }
    }
    
    /// Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
    ///
    /// Verifies specific keyboard shortcut mappings for each tab.
    ///
    /// **Validates: Requirements 7.3**
    func testProperty4_KeyboardShortcutMapping_SpecificMappings() {
        // Label: Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
        
        // Test each specific mapping
        XCTAssertEqual(
            AppTab.overview.keyboardShortcut, "1",
            "Property 4 failed: overview tab should have shortcut '1'"
        )
        XCTAssertEqual(
            AppTab.diskConfig.keyboardShortcut, "2",
            "Property 4 failed: diskConfig tab should have shortcut '2'"
        )
        XCTAssertEqual(
            AppTab.diskInfo.keyboardShortcut, "3",
            "Property 4 failed: diskInfo tab should have shortcut '3'"
        )
        XCTAssertEqual(
            AppTab.systemConfig.keyboardShortcut, "4",
            "Property 4 failed: systemConfig tab should have shortcut '4'"
        )
    }
    
    /// Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
    ///
    /// Property test: Keyboard shortcuts should be consistent across multiple accesses.
    ///
    /// **Validates: Requirements 7.3**
    func testProperty4_KeyboardShortcutMapping_ConsistentAccess() {
        // Label: Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射 (consistent access)"
        ) {
            let randomTab = AppTab.random()
            
            // Access the shortcut multiple times
            let firstAccess = randomTab.keyboardShortcut
            let secondAccess = randomTab.keyboardShortcut
            let thirdAccess = randomTab.keyboardShortcut
            
            // All accesses should return the same value
            return firstAccess == secondAccess && secondAccess == thirdAccess
        }
        
        XCTAssertTrue(result, "Property 4 failed: Keyboard shortcuts should be consistent across multiple accesses")
    }
    
    /// Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
    ///
    /// Property test: Shortcut should match tab's rawValue + 1.
    ///
    /// **Validates: Requirements 7.3**
    func testProperty4_KeyboardShortcutMapping_MatchesRawValuePlusOne() {
        // Label: Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 4: 键盘快捷键映射 (rawValue + 1)"
        ) {
            let randomTab = AppTab.random()
            
            // Expected shortcut is rawValue + 1 (since rawValue starts at 0)
            let expectedShortcutString = String(randomTab.rawValue + 1)
            let expectedShortcut = KeyEquivalent(Character(expectedShortcutString))
            
            return randomTab.keyboardShortcut == expectedShortcut
        }
        
        XCTAssertTrue(result, "Property 4 failed: Keyboard shortcut should match rawValue + 1")
    }
    
    // MARK: - Property 17: 刷新时选项卡保持 (Tab Retention During Refresh)
    
    /// Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
    ///
    /// For any currently selected tab, when a data refresh operation is triggered,
    /// the selectedTab value should remain unchanged.
    ///
    /// **Validates: Requirements 7.4**
    func testProperty17_TabRetentionDuringRefresh_BadgeUpdateDoesNotChangeTab() {
        // Label: Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持 (badge update)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            let randomTab = AppTab.random()
            
            // Set the selected tab
            controller.selectedTab = randomTab
            
            // Simulate data refresh by updating badges (common refresh operation)
            let randomBadge = TabBadgeData.random()
            controller.updateBadge(for: .overview, badge: randomBadge)
            controller.updateBadge(for: .diskConfig, badge: TabBadgeData(type: .count(5), color: .red))
            controller.updateBadge(for: .diskInfo, badge: TabBadgeData(type: .dot, color: .orange))
            
            // The selected tab should remain unchanged
            return controller.selectedTab == randomTab
        }
        
        XCTAssertTrue(result, "Property 17 failed: Badge updates should not change the selected tab")
    }
    
    /// Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
    ///
    /// Verifies that clearing all badges does not change the selected tab.
    ///
    /// **Validates: Requirements 7.4**
    func testProperty17_TabRetentionDuringRefresh_ClearBadgesDoesNotChangeTab() {
        // Label: Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持 (clear badges)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            let randomTab = AppTab.random()
            
            // Set the selected tab
            controller.selectedTab = randomTab
            
            // Add some badges
            controller.updateBadge(for: .overview, badge: TabBadgeData(type: .count(3), color: .blue))
            controller.updateBadge(for: .diskConfig, badge: TabBadgeData(type: .dot, color: .red))
            
            // Clear all badges (simulating refresh that clears notifications)
            controller.clearAllBadges()
            
            // The selected tab should remain unchanged
            return controller.selectedTab == randomTab
        }
        
        XCTAssertTrue(result, "Property 17 failed: Clearing badges should not change the selected tab")
    }
    
    /// Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
    ///
    /// Verifies that removing a badge from the current tab does not change selection.
    ///
    /// **Validates: Requirements 7.4**
    func testProperty17_TabRetentionDuringRefresh_RemoveBadgeFromCurrentTab() {
        // Label: Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持 (remove badge from current)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            let randomTab = AppTab.random()
            
            // Set the selected tab
            controller.selectedTab = randomTab
            
            // Add a badge to the current tab
            controller.updateBadge(for: randomTab, badge: TabBadgeData(type: .count(5), color: .red))
            
            // Remove the badge from the current tab
            controller.updateBadge(for: randomTab, badge: nil)
            
            // The selected tab should remain unchanged
            return controller.selectedTab == randomTab
        }
        
        XCTAssertTrue(result, "Property 17 failed: Removing badge from current tab should not change selection")
    }
    
    /// Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
    ///
    /// Verifies that multiple badge operations do not affect tab selection.
    ///
    /// **Validates: Requirements 7.4**
    func testProperty17_TabRetentionDuringRefresh_MultipleBadgeOperations() {
        // Label: Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持 (multiple operations)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            let randomTab = AppTab.random()
            
            // Set the selected tab
            controller.selectedTab = randomTab
            
            // Perform multiple badge operations (simulating multiple refresh cycles)
            for _ in 0..<5 {
                let targetTab = AppTab.random()
                let badge = TabBadgeData.random()
                controller.updateBadge(for: targetTab, badge: badge)
            }
            
            // Clear and re-add badges
            controller.clearAllBadges()
            controller.updateBadge(for: .overview, badge: TabBadgeData(type: .count(1), color: .blue))
            
            // The selected tab should remain unchanged throughout
            return controller.selectedTab == randomTab
        }
        
        XCTAssertTrue(result, "Property 17 failed: Multiple badge operations should not affect tab selection")
    }
    
    /// Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
    ///
    /// Verifies that reset operation preserves the expected behavior.
    ///
    /// **Validates: Requirements 7.4**
    func testProperty17_TabRetentionDuringRefresh_ResetBehavior() {
        // Label: Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
        
        let userDefaults = createTestUserDefaults()
        defer { cleanupTestUserDefaults(userDefaults) }
        
        let controller = TabNavigationController(userDefaults: userDefaults)
        
        // Set a non-default tab
        controller.selectedTab = .diskInfo
        
        // Add some badges
        controller.updateBadge(for: .diskInfo, badge: TabBadgeData(type: .count(3), color: .orange))
        
        // Reset the controller
        controller.reset()
        
        // After reset, should be back to overview
        XCTAssertEqual(
            controller.selectedTab, .overview,
            "Property 17: After reset, selectedTab should be overview"
        )
        
        // Badges should be cleared
        XCTAssertTrue(
            controller.badges.isEmpty,
            "Property 17: After reset, badges should be empty"
        )
    }
    
    /// Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
    ///
    /// Comprehensive test: Tab selection is independent of badge state.
    ///
    /// **Validates: Requirements 7.4**
    func testProperty17_TabRetentionDuringRefresh_TabSelectionIndependentOfBadges() {
        // Label: Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持
        // Minimum iterations: 100 (as per design.md)
        
        let result = NavigationPropertyTester.check(
            iterations: 100,
            label: "Feature: bottom-nav-refactor, Property 17: 刷新时选项卡保持 (independence)"
        ) {
            let userDefaults = self.createTestUserDefaults()
            defer { self.cleanupTestUserDefaults(userDefaults) }
            
            let controller = TabNavigationController(userDefaults: userDefaults)
            
            // Set random tab
            let selectedTab = AppTab.random()
            controller.selectedTab = selectedTab
            
            // Perform various badge operations
            for tab in AppTab.allCases {
                let shouldHaveBadge = Bool.random()
                if shouldHaveBadge {
                    controller.updateBadge(for: tab, badge: TabBadgeData.random())
                } else {
                    controller.updateBadge(for: tab, badge: nil)
                }
            }
            
            // Verify tab selection is unchanged
            let tabUnchanged = controller.selectedTab == selectedTab
            
            // Verify badge operations worked correctly
            var badgesCorrect = true
            for tab in AppTab.allCases {
                let hasBadge = controller.hasBadge(for: tab)
                let getBadge = controller.getBadge(for: tab)
                
                // hasBadge should be consistent with getBadge
                if hasBadge {
                    badgesCorrect = badgesCorrect && (getBadge != nil) && getBadge!.shouldShow
                }
            }
            
            return tabUnchanged && badgesCorrect
        }
        
        XCTAssertTrue(result, "Property 17 failed: Tab selection should be independent of badge state")
    }
}
