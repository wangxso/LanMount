//
//  MainTabView.swift
//  LanMount
//
//  Main tab view integrating bottom navigation bar and content views
//  Requirements: 1.1 - Tab_Bar fixed at bottom of main window
//  Requirements: 1.3 - Navigation controller shall immediately switch to corresponding content view
//  Requirements: 8.1 - Disk config tab badge for connection errors
//  Requirements: 8.2 - Disk info tab badge for storage warnings (>90%)
//  Requirements: 8.3 - Overview tab badge for mounted disk count
//  Requirements: 8.4 - Badge removal when conditions are cleared
//

import SwiftUI

// MARK: - MainTabView

/// 主选项卡视图
/// The main view of the application integrating the bottom navigation bar and content views
///
/// This view provides:
/// - VStack layout with content area and bottom navigation bar
/// - Integration with TabNavigationController for navigation state management
/// - Badge update logic based on mounted volumes, errors, and storage warnings
/// - Keyboard shortcuts for tab switching (Cmd+1/2/3/4)
///
/// **Validates: Requirements 1.1, 1.3, 8.1, 8.2, 8.3, 8.4**
///
/// Example usage:
/// ```swift
/// MainTabView()
/// ```
@available(macOS 13.0, *)
struct MainTabView: View {
    
    // MARK: - State Objects
    
    /// Navigation controller managing tab selection and persistence
    @StateObject private var navigationController = TabNavigationController()
    
    /// Dashboard view model providing data for all tabs
    @StateObject private var dashboardViewModel = DashboardViewModel()
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 内容区域
            // Content area displaying the selected tab's view
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部导航栏
            // Bottom navigation bar with tab items and badges
            // Requirements: 1.1 - Tab_Bar fixed at bottom of main window
            BottomTabBar(
                selectedTab: $navigationController.selectedTab,
                badges: navigationController.badges,
                onTabSelected: { tab in
                    // Optional: Add analytics or other side effects here
                }
            )
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            // Load initial data and start monitoring
            await dashboardViewModel.loadInitialData()
            dashboardViewModel.startMonitoring()
            updateBadges()
        }
        .onChange(of: dashboardViewModel.mountedVolumeCount) { _ in
            // Update badges when mounted volume count changes
            // Requirements: 8.3 - Overview tab badge for mounted disk count
            updateBadges()
        }
        .onChange(of: dashboardViewModel.errorCount) { _ in
            // Update badges when error count changes
            // Requirements: 8.1 - Disk config tab badge for connection errors
            updateBadges()
        }
        .onChange(of: dashboardViewModel.storageWarningCount) { _ in
            // Update badges when storage warning count changes
            // Requirements: 8.2 - Disk info tab badge for storage warnings
            updateBadges()
        }
        .onDisappear {
            // Stop monitoring when view disappears
            dashboardViewModel.stopMonitoring()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("Main Application View", comment: "Main view accessibility label"))
    }
    
    // MARK: - Content View
    
    /// Content view displaying the selected tab's content
    /// Requirements: 1.3 - Navigation controller shall immediately switch to corresponding content view
    @ViewBuilder
    private var contentView: some View {
        switch navigationController.selectedTab {
        case .overview:
            OverviewTabView(
                viewModel: dashboardViewModel,
                onNavigateToTab: { tab in
                    navigationController.switchTo(tab)
                }
            )
            .accessibilityLabel(NSLocalizedString("Overview Tab Content", comment: "Overview content accessibility"))
            
        case .diskConfig:
            DiskConfigTabView(viewModel: dashboardViewModel.connectionManagerViewModel)
                .accessibilityLabel(NSLocalizedString("Disk Configuration Tab Content", comment: "Disk config content accessibility"))
            
        case .diskInfo:
            DiskInfoTabView(
                storageViewModel: dashboardViewModel.storageViewModel,
                ioViewModel: dashboardViewModel.ioMonitorViewModel
            )
            .accessibilityLabel(NSLocalizedString("Disk Information Tab Content", comment: "Disk info content accessibility"))
            
        case .systemConfig:
            SystemConfigTabView()
                .accessibilityLabel(NSLocalizedString("System Configuration Tab Content", comment: "System config content accessibility"))
        }
    }
    
    // MARK: - Badge Update Logic
    
    /// Updates badges for all tabs based on current state
    /// Requirements: 8.1, 8.2, 8.3, 8.4 - Badge display and removal
    private func updateBadges() {
        // 更新概览选项卡徽章（已挂载数量）
        // Update overview tab badge (mounted count)
        // Requirements: 8.3 - Overview tab badge for mounted disk count
        if dashboardViewModel.mountedVolumeCount > 0 {
            navigationController.updateBadge(
                for: .overview,
                badge: TabBadgeData(type: .count(dashboardViewModel.mountedVolumeCount), color: .blue)
            )
        } else {
            // Requirements: 8.4 - Badge removal when conditions are cleared
            navigationController.updateBadge(for: .overview, badge: nil)
        }
        
        // 更新磁盘配置选项卡徽章（错误数量）
        // Update disk config tab badge (error count)
        // Requirements: 8.1 - Disk config tab badge for connection errors
        if dashboardViewModel.errorCount > 0 {
            navigationController.updateBadge(
                for: .diskConfig,
                badge: TabBadgeData(type: .count(dashboardViewModel.errorCount), color: .red)
            )
        } else {
            // Requirements: 8.4 - Badge removal when conditions are cleared
            navigationController.updateBadge(for: .diskConfig, badge: nil)
        }
        
        // 更新磁盘信息选项卡徽章（存储警告）
        // Update disk info tab badge (storage warnings)
        // Requirements: 8.2 - Disk info tab badge for storage warnings (>90%)
        if dashboardViewModel.storageWarningCount > 0 {
            navigationController.updateBadge(
                for: .diskInfo,
                badge: TabBadgeData(type: .count(dashboardViewModel.storageWarningCount), color: .orange)
            )
        } else {
            // Requirements: 8.4 - Badge removal when conditions are cleared
            navigationController.updateBadge(for: .diskInfo, badge: nil)
        }
    }
}

// MARK: - MainTabView for macOS 12 Fallback

/// Fallback view for macOS 12 that doesn't support Swift Charts
/// Uses the existing DashboardView instead
struct MainTabViewLegacy: View {
    
    @StateObject private var navigationController = TabNavigationController()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Content area - use a simple placeholder for legacy support
            // DashboardView requires macOS 13.0+, so we show a basic view
            legacyContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom navigation bar
            BottomTabBar(
                selectedTab: $navigationController.selectedTab,
                badges: navigationController.badges
            )
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            await dashboardViewModel.loadInitialData()
            dashboardViewModel.startMonitoring()
            updateBadges()
        }
        .onChange(of: dashboardViewModel.mountedVolumeCount) { _ in
            updateBadges()
        }
        .onDisappear {
            dashboardViewModel.stopMonitoring()
        }
    }
    
    @ViewBuilder
    private var legacyContentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text(NSLocalizedString("LanMount", comment: "App name"))
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(NSLocalizedString(
                "Please upgrade to macOS 13.0 or later for the full experience.",
                comment: "Legacy mode message"
            ))
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            
            Text(String(
                format: NSLocalizedString(
                    "%d volumes mounted",
                    comment: "Mounted volume count"
                ),
                dashboardViewModel.mountedVolumeCount
            ))
            .font(.headline)
            .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func updateBadges() {
        // Update overview tab badge (mounted count)
        if dashboardViewModel.mountedVolumeCount > 0 {
            navigationController.updateBadge(
                for: .overview,
                badge: TabBadgeData(type: .count(dashboardViewModel.mountedVolumeCount), color: .blue)
            )
        } else {
            navigationController.updateBadge(for: .overview, badge: nil)
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 13.0, *)
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            MainTabView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            // Dark mode preview
            MainTabView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
