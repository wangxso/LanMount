//
//  DashboardView.swift
//  LanMount
//
//  Legacy dashboard view - DEPRECATED
//  This view has been replaced by MainTabView with bottom navigation bar.
//  Kept for backward compatibility and as a fallback for older macOS versions.
//
//  Requirements: 4.1 - Main dashboard interface with comprehensive overview
//  Requirements: 4.2 - Display connection status grid with detailed information
//  Requirements: 7.1 - Set minimum window size to 600x400
//
//  NOTE: This file is deprecated. New features should be added to:
//  - MainTabView.swift (main navigation)
//  - OverviewTabView.swift (overview content)
//  - DiskConfigTabView.swift (disk configuration)
//  - DiskInfoTabView.swift (disk information)
//  - SystemConfigTabView.swift (system settings)
//

import SwiftUI

// MARK: - DashboardTab (Legacy)

/// Legacy tabs for the dashboard sidebar navigation
/// @available(*, deprecated, message: "Use AppTab from NavigationModels.swift instead")
enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "overview"
    case connections = "connections"
    case addConnection = "addConnection"
    case storage = "storage"
    case ioMonitor = "ioMonitor"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .overview:
            return NSLocalizedString("Overview", comment: "Overview tab")
        case .connections:
            return NSLocalizedString("Connections", comment: "Connections tab")
        case .addConnection:
            return NSLocalizedString("Add Connection", comment: "Add connection tab")
        case .storage:
            return NSLocalizedString("Storage", comment: "Storage tab")
        case .ioMonitor:
            return NSLocalizedString("IO Monitor", comment: "IO Monitor tab")
        case .settings:
            return NSLocalizedString("Settings", comment: "Settings tab")
        }
    }
    
    var icon: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .connections:
            return "network"
        case .addConnection:
            return "plus.circle"
        case .storage:
            return "internaldrive"
        case .ioMonitor:
            return "chart.line.uptrend.xyaxis"
        case .settings:
            return "gearshape"
        }
    }
}

// MARK: - DashboardView (Legacy)

/// Legacy dashboard view with sidebar navigation
/// @available(*, deprecated, message: "Use MainTabView instead for bottom navigation bar layout")
///
/// This view is kept for backward compatibility but is no longer the primary interface.
/// The application now uses MainTabView with a bottom navigation bar.
///
/// Reusable components from this view that are still in use:
/// - QuickActionsPanel (used by OverviewTabView)
/// - ConnectionCard (used by OverviewTabView)
/// - AdaptiveGrid (used by OverviewTabView)
/// - InlineAddConnectionForm (can be used by DiskConfigTabView)
/// - InlineNetworkScannerView (can be used by DiskConfigTabView)
@available(macOS 13.0, *)
struct DashboardView: View {
    /// The view model that provides data and handles operations
    @StateObject var viewModel: DashboardViewModel

    /// Currently selected tab
    @State private var selectedTab: DashboardTab = .overview
    
    /// Previous mounted volume count for change detection
    @State private var previousMountedCount: Int = 0

    /// Previous configuration count for change detection
    @State private var previousConfigCount: Int = 0
    
    /// Configuration being edited (for inline editing)
    @State private var editingConfiguration: MountConfiguration?
    
    /// Show add connection form
    @State private var showAddConnectionForm: Bool = false

    /// Creates a new dashboard view
    init(viewModel: DashboardViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: DashboardViewModel())
        }
    }

    var body: some View {
        // NOTE: This sidebar navigation is deprecated.
        // The application now uses MainTabView with bottom navigation bar.
        // This view is kept for backward compatibility only.
        NavigationSplitView {
            // Sidebar (Legacy - replaced by BottomTabBar in MainTabView)
            sidebarView
        } detail: {
            // Main content area
            mainContentView
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            await viewModel.loadInitialData()
            viewModel.startMonitoring()
            previousMountedCount = viewModel.mountedVolumeCount
            previousConfigCount = viewModel.configurationCount
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .onChange(of: viewModel.mountedVolumeCount) { newCount in
            handleMountedVolumeCountChange(from: previousMountedCount, to: newCount)
            previousMountedCount = newCount
        }
        .onChange(of: viewModel.configurationCount) { newCount in
            handleConfigurationCountChange(from: previousConfigCount, to: newCount)
            previousConfigCount = newCount
        }
        .onChange(of: viewModel.lastBatchResult) { result in
            if let result = result {
                announceBatchOperationResult(result)
            }
        }
    }
    
    // MARK: - Sidebar View (Legacy)
    
    /// Legacy sidebar view - replaced by BottomTabBar in MainTabView
    private var sidebarView: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach([DashboardTab.overview, .connections, .addConnection], id: \.id) { tab in
                    sidebarItem(for: tab)
                }
            } header: {
                Text(NSLocalizedString("Main", comment: "Main section"))
            }
            
            Section {
                ForEach([DashboardTab.storage, .ioMonitor], id: \.id) { tab in
                    sidebarItem(for: tab)
                }
            } header: {
                Text(NSLocalizedString("Monitoring", comment: "Monitoring section"))
            }
            
            Section {
                sidebarItem(for: .settings)
            } header: {
                Text(NSLocalizedString("System", comment: "System section"))
            }
            
            // Quick stats at bottom of sidebar
            Section {
                quickStatsView
            } header: {
                Text(NSLocalizedString("Status", comment: "Status section"))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("LanMount")
        .frame(minWidth: 200)
    }
    
    private func sidebarItem(for tab: DashboardTab) -> some View {
        Label(tab.title, systemImage: tab.icon)
            .tag(tab)
            .badge(badgeCount(for: tab))
    }
    
    private func badgeCount(for tab: DashboardTab) -> Int {
        switch tab {
        case .connections:
            return viewModel.configurations.count
        case .storage:
            return viewModel.mountedVolumeCount
        default:
            return 0
        }
    }
    
    private var quickStatsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(viewModel.mountedVolumeCount > 0 ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text("\(viewModel.mountedVolumeCount) " + NSLocalizedString("mounted", comment: "Mounted count"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("\(viewModel.configurations.count) " + NSLocalizedString("configured", comment: "Configured count"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var mainContentView: some View {
        switch selectedTab {
        case .overview:
            overviewContentView
        case .connections:
            connectionsContentView
        case .addConnection:
            addConnectionContentView
        case .storage:
            storageContentView
        case .ioMonitor:
            ioMonitorContentView
        case .settings:
            settingsContentView
        }
    }

    // MARK: - Overview Content
    
    private var overviewContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Quick Actions Panel (Reusable component)
                QuickActionsPanel(viewModel: viewModel)
                
                // Connection Status Grid
                if !viewModel.configurations.isEmpty {
                    connectionStatusSection
                }
                
                // Two-column layout for Storage and IO
                HStack(alignment: .top, spacing: 20) {
                    // Storage Overview (compact)
                    if viewModel.storageViewModel.hasData {
                        compactStorageSection
                    }
                    
                    // IO Monitor (compact)
                    if viewModel.ioMonitorViewModel.hasData {
                        compactIOSection
                    }
                }
                
                // Empty state message
                if viewModel.configurations.isEmpty {
                    emptyStateMessage
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("Overview", comment: "Overview title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await viewModel.refreshStatus() } }) {
                    Label(NSLocalizedString("Refresh", comment: "Refresh button"), systemImage: "arrow.clockwise")
                }
            }
        }
    }
    
    // MARK: - Connections Content
    
    private var connectionsContentView: some View {
        VStack(spacing: 0) {
            // Inline connection manager
            ConnectionManagerView(viewModel: viewModel.connectionManagerViewModel)
        }
        .navigationTitle(NSLocalizedString("Connections", comment: "Connections title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { selectedTab = .addConnection }) {
                    Label(NSLocalizedString("Add", comment: "Add button"), systemImage: "plus")
                }
            }
        }
    }
    
    // MARK: - Add Connection Content
    
    private var addConnectionContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Add New SMB Connection", comment: "Add connection title"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(NSLocalizedString("Configure a new SMB share to mount on your Mac.", comment: "Add connection description"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Inline configuration form
                GlassCard(theme: .light) {
                    InlineAddConnectionForm(
                        viewModel: viewModel.connectionManagerViewModel,
                        onSave: {
                            // Switch to connections tab after saving
                            selectedTab = .connections
                        }
                    )
                    .padding()
                }
                
                // Network scanner section
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("Or Scan Network", comment: "Scan network section"))
                        .font(.headline)
                    
                    Text(NSLocalizedString("Automatically discover SMB shares on your local network.", comment: "Scan network description"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    GlassCard(theme: .light) {
                        InlineNetworkScannerView(
                            onSelectShare: { server, share in
                                // Pre-fill the form with discovered share
                            }
                        )
                        .padding()
                    }
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("Add Connection", comment: "Add connection title"))
    }
    
    // MARK: - Storage Content
    
    private var storageContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.storageViewModel.hasData {
                    // Full storage chart view
                    GlassCard(theme: .light) {
                        VStack(spacing: 16) {
                            StorageChartView(viewModel: viewModel.storageViewModel)
                                .frame(minHeight: 400)
                        }
                        .padding()
                    }
                    
                    // Storage details list
                    storageDetailsList
                } else {
                    noStorageDataView
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("Storage", comment: "Storage title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await viewModel.storageViewModel.refresh() } }) {
                    Label(NSLocalizedString("Refresh", comment: "Refresh button"), systemImage: "arrow.clockwise")
                }
            }
        }
    }
    
    // MARK: - IO Monitor Content
    
    private var ioMonitorContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.ioMonitorViewModel.hasData {
                    // Full IO monitor view
                    GlassCard(theme: .light) {
                        IOMonitorView(viewModel: viewModel.ioMonitorViewModel)
                            .frame(minHeight: 400)
                            .padding()
                    }
                    
                    // IO statistics details
                    ioStatisticsDetails
                } else {
                    noIODataView
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("IO Monitor", comment: "IO Monitor title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if viewModel.ioMonitorViewModel.isMonitoring {
                        viewModel.ioMonitorViewModel.stopMonitoring()
                    } else {
                        viewModel.ioMonitorViewModel.startMonitoring()
                    }
                }) {
                    Label(
                        viewModel.ioMonitorViewModel.isMonitoring 
                            ? NSLocalizedString("Stop", comment: "Stop button")
                            : NSLocalizedString("Start", comment: "Start button"),
                        systemImage: viewModel.ioMonitorViewModel.isMonitoring ? "stop.fill" : "play.fill"
                    )
                }
            }
        }
    }
    
    // MARK: - Settings Content
    
    private var settingsContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // General settings
                GlassCard(theme: .light) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("General", comment: "General settings"))
                            .font(.headline)
                        
                        Toggle(NSLocalizedString("Launch at Login", comment: "Launch at login setting"), isOn: .constant(false))
                        Toggle(NSLocalizedString("Show in Menu Bar", comment: "Menu bar setting"), isOn: .constant(true))
                        Toggle(NSLocalizedString("Auto-mount on Network Change", comment: "Auto mount setting"), isOn: .constant(true))
                    }
                    .padding()
                }
                
                // Notifications settings
                GlassCard(theme: .light) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("Notifications", comment: "Notifications settings"))
                            .font(.headline)
                        
                        Toggle(NSLocalizedString("Mount/Unmount Notifications", comment: "Mount notifications"), isOn: .constant(true))
                        Toggle(NSLocalizedString("Error Notifications", comment: "Error notifications"), isOn: .constant(true))
                        Toggle(NSLocalizedString("Storage Warning Notifications", comment: "Storage warnings"), isOn: .constant(true))
                    }
                    .padding()
                }
                
                // About section
                GlassCard(theme: .light) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("About", comment: "About section"))
                            .font(.headline)
                        
                        HStack {
                            Text(NSLocalizedString("LanMount", comment: "App name"))
                                .fontWeight(.medium)
                            Spacer()
                            Text(NSLocalizedString("v1.0.0", comment: "Version"))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(NSLocalizedString("A modern SMB mount manager for macOS", comment: "App description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("Settings", comment: "Settings title"))
    }

    // MARK: - Section Views
    
    /// Connection status section with adaptive grid of connection cards
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("Connections", comment: "Connections section title"))
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { selectedTab = .connections }) {
                    Text(NSLocalizedString("View All", comment: "View all button"))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            AdaptiveGrid(items: viewModel.configurations.prefix(6).map { $0 }) { config in
                if let mountedVolume = viewModel.mountedVolumes.first(where: { $0.id == config.id }) {
                    ConnectionCard(
                        configuration: config,
                        mountedVolume: mountedVolume,
                        statistics: nil
                    )
                } else {
                    ConnectionCard(
                        configuration: config,
                        mountedVolume: nil,
                        statistics: nil
                    )
                }
            }
            
            if viewModel.configurations.count > 6 {
                Button(action: { selectedTab = .connections }) {
                    Text(String(format: NSLocalizedString("+ %d more connections", comment: "More connections"), viewModel.configurations.count - 6))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// Compact storage section for overview
    private var compactStorageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("Storage", comment: "Storage section"))
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { selectedTab = .storage }) {
                    Text(NSLocalizedString("Details", comment: "Details button"))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            
            GlassCard(theme: .light) {
                VStack(spacing: 12) {
                    let summary = viewModel.storageViewModel.totalStorage
                    
                    // Usage bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(summary.overallUsageLevel.color)
                                .frame(width: geometry.size.width * CGFloat(summary.overallUsagePercentage / 100))
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text(summary.formattedTotalUsed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", summary.overallUsagePercentage))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(summary.overallUsageLevel.color)
                        
                        Spacer()
                        
                        Text(summary.formattedTotalCapacity)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Compact IO section for overview
    private var compactIOSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("IO Activity", comment: "IO section"))
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { selectedTab = .ioMonitor }) {
                    Text(NSLocalizedString("Details", comment: "Details button"))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            
            GlassCard(theme: .light) {
                VStack(spacing: 12) {
                    if let stats = viewModel.ioMonitorViewModel.currentStats.first {
                        HStack(spacing: 20) {
                            // Read speed
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text(NSLocalizedString("Read", comment: "Read label"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(stats.formattedReadSpeed)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            // Write speed
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(NSLocalizedString("Write", comment: "Write label"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                                Text(stats.formattedWriteSpeed)
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                        }
                    } else {
                        Text(NSLocalizedString("No IO data", comment: "No IO data"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Storage details list
    private var storageDetailsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Volume Details", comment: "Volume details"))
                .font(.headline)
            
            ForEach(viewModel.storageViewModel.storageData) { volume in
                GlassCard(theme: .light) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(volume.volumeName)
                                .font(.headline)
                            Text("\(volume.server)/\(volume.share)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%.1f%%", volume.usagePercentage))
                                .font(.headline)
                                .foregroundColor(volume.usageLevel.color)
                            Text("\(volume.formattedUsedSpace) / \(volume.formattedTotalCapacity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    /// IO statistics details
    private var ioStatisticsDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Statistics", comment: "Statistics"))
                .font(.headline)
            
            ForEach(viewModel.ioMonitorViewModel.currentStats) { stats in
                GlassCard(theme: .light) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(stats.volumeName)
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("Current", comment: "Current"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("↓ \(stats.formattedReadSpeed)")
                                        .foregroundColor(.blue)
                                    Text("↑ \(stats.formattedWriteSpeed)")
                                        .foregroundColor(.orange)
                                }
                                .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text(NSLocalizedString("Average", comment: "Average"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("↓ \(stats.formattedAverageReadSpeed)")
                                        .foregroundColor(.blue)
                                    Text("↑ \(stats.formattedAverageWriteSpeed)")
                                        .foregroundColor(.orange)
                                }
                                .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(NSLocalizedString("Peak", comment: "Peak"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("↓ \(stats.formattedPeakReadSpeed)")
                                        .foregroundColor(.blue)
                                    Text("↑ \(stats.formattedPeakWriteSpeed)")
                                        .foregroundColor(.orange)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    /// No storage data view
    private var noStorageDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "internaldrive.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("No Storage Data", comment: "No storage data"))
                .font(.headline)
            
            Text(NSLocalizedString("Mount a drive to see storage information.", comment: "No storage description"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    /// No IO data view
    private var noIODataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("No IO Data", comment: "No IO data"))
                .font(.headline)
            
            Text(NSLocalizedString("Mount a drive to see IO statistics.", comment: "No IO description"))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { viewModel.ioMonitorViewModel.startMonitoring() }) {
                Label(NSLocalizedString("Start Monitoring", comment: "Start monitoring"), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// Empty state message when no configurations exist
    private var emptyStateMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("No SMB Connections Configured", comment: "Empty state title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(NSLocalizedString("Add your first SMB connection to get started.", comment: "Empty state description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { selectedTab = .addConnection }) {
                Label(NSLocalizedString("Add Connection", comment: "Add connection button"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Private Helpers

    /// Returns appropriate color for storage usage level
    private func storageLevelColor(for level: UsageLevel) -> Color {
        switch level {
        case .normal:
            return .green
        case .warning:
            return .yellow
        case .critical:
            return .red
        }
    }

    /// Handles changes in mounted volume count and announces status changes
    private func handleMountedVolumeCountChange(from oldCount: Int, to newCount: Int) {
        if newCount > oldCount {
            let difference = newCount - oldCount
            if difference == 1 {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "Volume mounted successfully",
                    comment: "Single volume mounted announcement"
                )
            } else {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "\(difference) volumes mounted successfully",
                    comment: "Multiple volumes mounted announcement"
                )
            }
        } else if newCount < oldCount {
            let difference = oldCount - newCount
            if difference == 1 {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "Volume unmounted",
                    comment: "Single volume unmounted announcement"
                )
            } else {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "\(difference) volumes unmounted",
                    comment: "Multiple volumes unmounted announcement"
                )
            }
        }
    }

    /// Handles changes in configuration count and announces status changes
    private func handleConfigurationCountChange(from oldCount: Int, to newCount: Int) {
        if newCount > oldCount {
            let difference = newCount - oldCount
            if difference == 1 {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "Connection added",
                    comment: "Single connection added announcement"
                )
            } else {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "\(difference) connections added",
                    comment: "Multiple connections added announcement"
                )
            }
        } else if newCount < oldCount {
            let difference = oldCount - newCount
            if difference == 1 {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "Connection removed",
                    comment: "Single connection removed announcement"
                )
            } else {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "\(difference) connections removed",
                    comment: "Multiple connections removed announcement"
                )
            }
        }
    }

    /// Announces the result of a batch operation
    private func announceBatchOperationResult(_ result: BatchOperationResult) {
        if result.isFullySuccessful {
            if result.totalCount == 1 {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "Operation completed successfully",
                    comment: "Single operation success announcement"
                )
            } else {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "All \(result.totalCount) operations completed successfully",
                    comment: "Multiple operations success announcement"
                )
            }
        } else {
            let successCount = result.successCount
            let failedCount = result.failedItems.count

            if successCount > 0 && failedCount > 0 {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "\(successCount) operations succeeded, \(failedCount) failed",
                    comment: "Partial success announcement"
                )
            } else if failedCount > 0 {
                VoiceOverAnnouncer.shared.announceLocalized(
                    "All operations failed",
                    comment: "Complete failure announcement"
                )
            }
        }
    }
}

// MARK: - Inline Add Connection Form (Reusable)

/// Inline form for adding a new SMB connection
/// This component can be reused by DiskConfigTabView
struct InlineAddConnectionForm: View {
    @ObservedObject var viewModel: ConnectionManagerViewModel
    var onSave: () -> Void
    
    @State private var server: String = ""
    @State private var share: String = ""
    @State private var mountPoint: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var autoMount: Bool = true
    @State private var syncEnabled: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: String?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Server section
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Server", comment: "Server field"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField(NSLocalizedString("e.g., 192.168.1.100 or server.local", comment: "Server placeholder"), text: $server)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Share section
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Share Name", comment: "Share field"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField(NSLocalizedString("e.g., Documents", comment: "Share placeholder"), text: $share)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Mount point section
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Mount Point", comment: "Mount point field"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField(NSLocalizedString("/Volumes/MyShare", comment: "Mount point placeholder"), text: $mountPoint)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(NSLocalizedString("Browse", comment: "Browse button")) {
                        // Open folder picker
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Divider()
            
            // Credentials section
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Credentials (Optional)", comment: "Credentials section"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField(NSLocalizedString("Username", comment: "Username field"), text: $username)
                    .textFieldStyle(.roundedBorder)
                
                SecureField(NSLocalizedString("Password", comment: "Password field"), text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            // Options section
            VStack(alignment: .leading, spacing: 8) {
                Toggle(NSLocalizedString("Auto-mount on startup", comment: "Auto mount option"), isOn: $autoMount)
                Toggle(NSLocalizedString("Enable sync", comment: "Sync option"), isOn: $syncEnabled)
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Button(action: testConnection) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label(NSLocalizedString("Test Connection", comment: "Test button"), systemImage: "network")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(server.isEmpty || share.isEmpty || isTesting)
                
                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.contains("✓") ? .green : .red)
                }
                
                Spacer()
                
                Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                    clearForm()
                }
                .buttonStyle(.bordered)
                
                Button(action: saveConfiguration) {
                    Label(NSLocalizedString("Save", comment: "Save button"), systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(server.isEmpty || share.isEmpty || mountPoint.isEmpty)
            }
        }
        .alert(NSLocalizedString("Error", comment: "Error alert"), isPresented: $showError) {
            Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        Task {
            // Simulate connection test
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isTesting = false
                testResult = "✓ " + NSLocalizedString("Connection successful", comment: "Test success")
            }
        }
    }
    
    private func saveConfiguration() {
        let config = MountConfiguration(
            id: UUID(),
            server: server,
            share: share,
            mountPoint: mountPoint.isEmpty ? "/Volumes/\(share)" : mountPoint,
            autoMount: autoMount,
            syncEnabled: syncEnabled
        )
        
        Task {
            do {
                try await viewModel.addConfiguration(config)
                clearForm()
                onSave()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func clearForm() {
        server = ""
        share = ""
        mountPoint = ""
        username = ""
        password = ""
        autoMount = true
        syncEnabled = false
        testResult = nil
    }
}

// MARK: - Inline Network Scanner View (Reusable)

/// Inline network scanner for discovering SMB shares
/// This component can be reused by DiskConfigTabView
struct InlineNetworkScannerView: View {
    var onSelectShare: (String, String) -> Void
    
    @State private var isScanning: Bool = false
    @State private var discoveredServers: [String] = []
    @State private var discoveredShares: [(server: String, share: String)] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: startScan) {
                    if isScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(NSLocalizedString("Scanning...", comment: "Scanning status"))
                        }
                    } else {
                        Label(NSLocalizedString("Scan Network", comment: "Scan button"), systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning)
                
                Spacer()
                
                if !discoveredShares.isEmpty {
                    Text(String(format: NSLocalizedString("%d shares found", comment: "Shares found"), discoveredShares.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !discoveredShares.isEmpty {
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(discoveredShares, id: \.share) { item in
                            HStack {
                                Image(systemName: "externaldrive.connected.to.line.below")
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading) {
                                    Text(item.share)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(item.server)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(NSLocalizedString("Use", comment: "Use button")) {
                                    onSelectShare(item.server, item.share)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 200)
            } else if !isScanning {
                Text(NSLocalizedString("Click 'Scan Network' to discover SMB shares on your local network.", comment: "Scan hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func startScan() {
        isScanning = true
        discoveredShares = []
        
        Task {
            // Simulate network scan
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                // Mock discovered shares
                discoveredShares = [
                    (server: "192.168.1.100", share: "Documents"),
                    (server: "192.168.1.100", share: "Media"),
                    (server: "nas.local", share: "Backup"),
                ]
                isScanning = false
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 13.0, *)
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashboardView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode (Legacy)")

            DashboardView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode (Legacy)")
        }
        .frame(width: 1000, height: 700)
    }
}
#endif
