//
//  TabNavigationController.swift
//  LanMount
//
//  Navigation controller for managing tab selection and state persistence
//  Requirements: 1.3 - WHEN 用户点击某个 Tab_Item 时，THE Navigation_Controller SHALL 立即切换到对应的内容视图
//  Requirements: 7.1 - WHEN 应用关闭时，THE Navigation_Controller SHALL 保存当前选中的选项卡索引
//  Requirements: 7.2 - WHEN 应用启动时，THE Navigation_Controller SHALL 恢复上次选中的选项卡
//  Requirements: 7.4 - WHEN 选项卡内容需要刷新时，THE Navigation_Controller SHALL 保持当前选项卡不变
//

import Foundation
import Combine
import SwiftUI

// MARK: - TabNavigationController

/// 选项卡导航控制器
/// Manages tab selection state and persistence via UserDefaults
/// - Note: This class is MainActor-isolated for safe UI updates
@MainActor
final class TabNavigationController: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前选中的选项卡
    /// The currently selected tab, automatically persisted to UserDefaults on change
    /// Requirements: 1.3 - Navigation controller shall immediately switch to corresponding content view
    @Published var selectedTab: AppTab {
        didSet {
            saveSelectedTab()
        }
    }
    
    /// 选项卡徽章数据
    /// Dictionary mapping tabs to their badge data
    /// Requirements: 8.1, 8.2, 8.3 - Badge display for various conditions
    @Published var badges: [AppTab: TabBadgeData] = [:]
    
    // MARK: - Private Properties
    
    /// UserDefaults key for storing the selected tab index
    private let userDefaultsKey = "selectedTabIndex"
    
    /// UserDefaults instance for persistence (injectable for testing)
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    
    /// Creates a new TabNavigationController
    /// - Parameter userDefaults: The UserDefaults instance to use for persistence (defaults to .standard)
    /// Requirements: 7.2 - Restore last selected tab on app launch
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // 从 UserDefaults 恢复上次选中的选项卡
        // Restore the last selected tab from UserDefaults
        let savedIndex = userDefaults.integer(forKey: userDefaultsKey)
        self.selectedTab = AppTab(rawValue: savedIndex) ?? .overview
    }
    
    // MARK: - Public Methods
    
    /// 切换到指定选项卡
    /// Switches to the specified tab
    /// - Parameter tab: The tab to switch to
    /// Requirements: 1.3 - Navigation controller shall immediately switch to corresponding content view
    func switchTo(_ tab: AppTab) {
        selectedTab = tab
    }
    
    /// 更新选项卡徽章
    /// Updates the badge for a specific tab
    /// - Parameters:
    ///   - tab: The tab to update the badge for
    ///   - badge: The badge data to set, or nil to remove the badge
    /// Requirements: 8.1, 8.2, 8.3, 8.4 - Badge display and removal
    func updateBadge(for tab: AppTab, badge: TabBadgeData?) {
        if let badge = badge {
            badges[tab] = badge
        } else {
            badges.removeValue(forKey: tab)
        }
    }
    
    /// 清除所有徽章
    /// Removes all badges from all tabs
    func clearAllBadges() {
        badges.removeAll()
    }
    
    /// 获取指定选项卡的徽章
    /// Returns the badge data for a specific tab
    /// - Parameter tab: The tab to get the badge for
    /// - Returns: The badge data, or nil if no badge is set
    func getBadge(for tab: AppTab) -> TabBadgeData? {
        return badges[tab]
    }
    
    /// 检查指定选项卡是否有徽章
    /// Checks if a specific tab has a badge
    /// - Parameter tab: The tab to check
    /// - Returns: True if the tab has a badge that should be shown
    func hasBadge(for tab: AppTab) -> Bool {
        guard let badge = badges[tab] else { return false }
        return badge.shouldShow
    }
    
    // MARK: - Private Methods
    
    /// 保存当前选项卡到 UserDefaults
    /// Persists the current tab selection to UserDefaults
    /// Requirements: 7.1 - Save current tab index when app closes
    private func saveSelectedTab() {
        userDefaults.set(selectedTab.rawValue, forKey: userDefaultsKey)
    }
}

// MARK: - TabNavigationController Extension for Testing

extension TabNavigationController {
    /// Resets the navigation controller to default state
    /// Useful for testing purposes
    func reset() {
        selectedTab = .overview
        badges.removeAll()
        userDefaults.removeObject(forKey: userDefaultsKey)
    }
}
