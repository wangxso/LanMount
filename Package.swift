// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LanMount",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LanMountCore",
            targets: ["LanMountCore"]
        ),
    ],
    dependencies: [
        // SwiftCheck for property-based testing (optional, for tests)
        // .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "LanMountCore",
            dependencies: [],
            path: "LanMount",
            exclude: [
                "Assets.xcassets",
                "LanMount.entitlements",
                "LanMount-Bridging-Header.h",
                "LanMountApp.swift",
                "ContentView.swift"
            ],
            sources: [
                "Models/Models.swift",
                "Models/SMBMounterError.swift",
                "Models/NavigationModels.swift",
                "Services/CredentialManager.swift",
                "Services/ConfigurationStore.swift",
                "Services/NetFSAdapter.swift",
                "Services/MountManager.swift",
                "Services/NetworkScanner.swift",
                "Services/VolumeMonitor.swift",
                "Services/LaunchAgentManager.swift",
                "Services/SyncEngine.swift",
                "Services/Logger.swift",
                "Controllers/MenuBarController.swift",
                "Views/MountConfigView.swift",
                "Views/NetworkScannerView.swift",
                "Views/PreferencesView.swift",
                "Coordinators/AppCoordinator.swift",
                "Services/ErrorHandler.swift",
                "Services/FinderIntegration.swift",
                "Services/NotificationManager.swift",
                "Services/CacheManager.swift",
                "Services/LocalizationHelper.swift",
                "Theme/GlassTheme.swift",
                "Theme/GlassBackgroundModifier.swift",
                "Theme/HoverEffectModifier.swift",
                "Theme/ColorContrast.swift",
                "Views/Components/GlassCard.swift",
                "Views/Components/TabBadgeView.swift",
                "Views/Components/TabBarItem.swift",
                "Views/Components/BottomTabBar.swift",
                "Views/Tabs/OverviewTabView.swift",
                "Views/Tabs/DiskConfigTabView.swift",
                "Views/Tabs/DiskInfoTabView.swift",
                "Views/Tabs/SystemConfigTabView.swift",
                "Models/StorageModels.swift",
                "Services/StorageMonitor.swift",
                "ViewModels/StorageViewModel.swift",
                "ViewModels/TabNavigationController.swift",
                "Models/IOModels.swift",
                "Services/IOStatsCollector.swift",
                "ViewModels/IOMonitorViewModel.swift",
                "ViewModels/ConnectionManagerViewModel.swift",
                "Views/ConnectionManagerView.swift",
                "Views/ConfigurationEditForm.swift",
                "ViewModels/DashboardViewModel.swift",
                "Views/DashboardView.swift",
                "Views/Components/QuickActionsPanel.swift",
                "Views/Components/ConnectionCard.swift",
                "Views/Components/AdaptiveGrid.swift",
                "Theme/LayoutBreakpoint.swift",
                "Services/VoiceOverAnnouncer.swift",
                "Views/Charts/StorageChartView.swift",
                "Views/Charts/IOMonitorView.swift",
                "Views/Charts/IOHistoryChart.swift",
                "Views/Charts/HealthGaugeChart.swift",
                "Views/Charts/StorageTrendChart.swift",
                "Models/ChartModels.swift"
            ]
        ),
        .testTarget(
            name: "LanMountTests",
            dependencies: ["LanMountCore"],
            path: "LanMountTests"
        ),
    ]
)
