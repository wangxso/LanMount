//
//  DiskInfoTabView.swift
//  LanMount
//
//  Disk information tab view displaying detailed storage info, charts, and health metrics
//  Requirements: 4.1 - Display detailed storage information for all mounted disks
//  Requirements: 4.2 - Display storage usage ring chart for each disk
//  Requirements: 4.3 - Display real-time IO performance line chart (read/write speed)
//  Requirements: 4.4 - Display connection latency and health status indicators
//  Requirements: 4.5 - When user selects a disk, expand to show complete statistics
//  Requirements: 4.6 - Support exporting disk statistics report
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

// Note: ChartTimeRange and HealthMetrics are now defined in ChartModels.swift

// MARK: - DiskStatisticsReport

/// 磁盘统计报告
/// Data structure for exporting disk statistics
struct DiskStatisticsReport: Codable {
    let generatedAt: Date
    let volumes: [VolumeReport]
    
    struct VolumeReport: Codable {
        let volumeName: String
        let server: String
        let share: String
        let totalBytes: Int64
        let usedBytes: Int64
        let availableBytes: Int64
        let usagePercentage: Double
        let currentReadSpeed: Int64
        let currentWriteSpeed: Int64
        let averageReadSpeed: Int64
        let averageWriteSpeed: Int64
        let peakReadSpeed: Int64
        let peakWriteSpeed: Int64
        let healthScore: Double
        let latencyMs: Double
        let successRate: Double
    }
}

// MARK: - DiskInfoTabView

/// 磁盘信息选项卡视图
/// Displays detailed storage information, charts, and health metrics for mounted disks
///
/// This view provides:
/// - Storage overview with ring charts for each volume
/// - Real-time IO performance line charts
/// - Health dashboard with latency and success rate gauges
/// - Expandable volume details with complete statistics
/// - Export functionality for disk statistics reports
///
/// Example usage:
/// ```swift
/// DiskInfoTabView(
///     storageViewModel: storageViewModel,
///     ioViewModel: ioMonitorViewModel
/// )
/// ```
@available(macOS 13.0, *)
struct DiskInfoTabView: View {
    
    // MARK: - Properties
    
    /// ViewModel for storage data
    @ObservedObject var storageViewModel: StorageViewModel
    
    /// ViewModel for IO monitoring data
    @ObservedObject var ioViewModel: IOMonitorViewModel
    
    // MARK: - Private State
    
    /// Currently selected volume for expanded details
    /// Requirements: 4.5 - When user selects a disk, expand to show complete statistics
    @State private var selectedVolume: UUID? = nil
    
    /// Current time range for IO charts
    @State private var chartTimeRange: ChartTimeRange = .hour
    
    /// Whether the export sheet is showing
    @State private var showingExportSheet: Bool = false
    
    /// Export file URL for sharing
    @State private var exportFileURL: URL? = nil
    
    /// Health metrics for each volume (simulated for now)
    @State private var healthMetrics: [UUID: HealthMetrics] = [:]
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 工具栏
                toolbarSection
                
                if storageViewModel.storageData.isEmpty && !storageViewModel.isLoading {
                    emptyStateView
                } else {
                    // 存储概览图表
                    // Requirements: 4.1, 4.2 - Display storage info and ring charts
                    storageOverviewSection
                    
                    // IO 性能图表
                    // Requirements: 4.3 - Display real-time IO performance line chart
                    ioPerformanceSection
                    
                    // 健康度仪表盘
                    // Requirements: 4.4 - Display connection latency and health status
                    healthDashboardSection
                    
                    // 磁盘详情列表
                    // Requirements: 4.5 - Expandable volume details
                    volumeDetailsSection
                }
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("Disk Info Tab", comment: "Disk info tab accessibility label"))
        .onAppear {
            initializeHealthMetrics()
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: exportFileURL.map { StatisticsDocument(url: $0) },
            contentType: .json,
            defaultFilename: "disk_statistics_\(formattedDate()).json"
        ) { result in
            handleExportResult(result)
        }
    }

    // MARK: - Toolbar Section
    
    /// Toolbar with time range picker and export button
    private var toolbarSection: some View {
        HStack {
            // Section title
            Label {
                Text(NSLocalizedString("Disk Information", comment: "Disk info section title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.accentColor)
            }
            .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            // Time range picker for IO charts
            Picker(NSLocalizedString("Time Range", comment: "Time range picker label"), selection: $chartTimeRange) {
                ForEach(ChartTimeRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityLabel(NSLocalizedString("IO chart time range", comment: "Time range picker accessibility"))
            
            // Export button
            // Requirements: 4.6 - Support exporting disk statistics report
            Button {
                exportStatistics()
            } label: {
                Label(
                    NSLocalizedString("Export", comment: "Export button"),
                    systemImage: "square.and.arrow.up"
                )
            }
            .buttonStyle(.bordered)
            .disabled(storageViewModel.storageData.isEmpty)
            .accessibilityHint(NSLocalizedString(
                "Export disk statistics as JSON file",
                comment: "Export button hint"
            ))
        }
    }
    
    // MARK: - Storage Overview Section
    
    /// Storage overview with ring charts for each volume
    /// Requirements: 4.1, 4.2 - Display storage info and ring charts
    private var storageOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            sectionHeader(
                title: NSLocalizedString("Storage Overview", comment: "Storage overview section"),
                icon: "internaldrive.fill",
                color: .blue
            )
            
            // Storage cards grid
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 300, maximum: 450), spacing: 16)],
                spacing: 16
            ) {
                ForEach(storageViewModel.storageData) { volume in
                    storageCard(for: volume)
                }
            }
        }
    }
    
    /// Creates a storage card with ring chart for a volume
    private func storageCard(for volume: VolumeStorageData) -> some View {
        GlassCard(
            accessibility: .summary(
                label: volume.accessibilityDescription,
                hint: NSLocalizedString("Tap to view details", comment: "Storage card hint")
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(volume.volumeName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(volume.smbURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Usage level badge
                    usageLevelBadge(for: volume)
                }
                
                Divider()
                
                // Ring chart and details
                HStack(spacing: 16) {
                    // Ring chart
                    ringChart(for: volume)
                        .frame(width: 80, height: 80)
                    
                    // Storage details
                    VStack(alignment: .leading, spacing: 6) {
                        storageDetailRow(
                            label: NSLocalizedString("Used", comment: "Used storage"),
                            value: volume.formattedUsedSpace,
                            color: volume.usageLevel.color
                        )
                        storageDetailRow(
                            label: NSLocalizedString("Available", comment: "Available storage"),
                            value: volume.formattedAvailableSpace,
                            color: .secondary
                        )
                        storageDetailRow(
                            label: NSLocalizedString("Total", comment: "Total storage"),
                            value: volume.formattedTotalCapacity,
                            color: .primary
                        )
                    }
                }
            }
            .padding()
        }
    }

    /// Ring chart for a volume
    @ViewBuilder
    private func ringChart(for volume: VolumeStorageData) -> some View {
        if #available(macOS 14.0, *) {
            Chart {
                SectorMark(
                    angle: .value("Used", volume.usedBytes),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(volume.usageLevel.color)
                .cornerRadius(4)
                
                SectorMark(
                    angle: .value("Available", volume.availableBytes),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(Color.gray.opacity(0.3))
                .cornerRadius(4)
            }
            .chartLegend(.hidden)
        } else {
            // Fallback for macOS 13.0
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(volume.usagePercentage / 100))
                    .stroke(volume.usageLevel.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", volume.usagePercentage))
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    /// Usage level badge
    private func usageLevelBadge(for volume: VolumeStorageData) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(volume.usageLevel.color)
                .frame(width: 8, height: 8)
            Text(String(format: "%.1f%%", volume.usagePercentage))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(volume.usageLevel.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(volume.usageLevel.color.opacity(0.1))
        )
    }
    
    /// Storage detail row helper
    private func storageDetailRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(minWidth: 120)
    }
    
    // MARK: - IO Performance Section
    
    /// IO performance section with line charts
    /// Requirements: 4.3 - Display real-time IO performance line chart
    private var ioPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            sectionHeader(
                title: NSLocalizedString("IO Performance", comment: "IO performance section"),
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
            
            GlassCard(
                accessibility: .summary(
                    label: ioPerformanceAccessibilityLabel,
                    hint: NSLocalizedString("Shows read and write speeds over time", comment: "IO chart hint")
                )
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // Current speeds summary
                    HStack(spacing: 24) {
                        speedIndicator(
                            label: NSLocalizedString("Read", comment: "Read speed"),
                            value: ioViewModel.formattedTotalReadSpeed,
                            icon: "arrow.down.circle.fill",
                            color: .blue,
                            isActive: ioViewModel.totalReadSpeed > 0
                        )
                        
                        speedIndicator(
                            label: NSLocalizedString("Write", comment: "Write speed"),
                            value: ioViewModel.formattedTotalWriteSpeed,
                            icon: "arrow.up.circle.fill",
                            color: .orange,
                            isActive: ioViewModel.totalWriteSpeed > 0
                        )
                        
                        Spacer()
                        
                        // Monitoring status
                        if ioViewModel.isMonitoring {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text(NSLocalizedString("Live", comment: "Live monitoring"))
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // IO line chart
                    ioLineChart
                        .frame(height: 200)
                    
                    // Legend
                    ioChartLegend
                }
                .padding()
            }
        }
    }

    /// IO line chart
    private var ioLineChart: some View {
        let historyData = ioViewModel.getHistory(duration: chartTimeRange.seconds)
        
        return Chart {
            ForEach(historyData) { point in
                // Read speed line
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Read", point.readSpeed),
                    series: .value("Type", "Read")
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.monotone)
                
                // Write speed line
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Write", point.writeSpeed),
                    series: .value("Type", "Write")
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: chartTimeRange.dateRange)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatAxisTime(date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let bytes = value.as(Int64.self) {
                        Text(formatAxisSpeed(bytes))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }
    
    /// IO chart legend
    private var ioChartLegend: some View {
        HStack(spacing: 20) {
            legendItem(color: .blue, label: NSLocalizedString("Read Speed", comment: "Read speed legend"))
            legendItem(color: .orange, label: NSLocalizedString("Write Speed", comment: "Write speed legend"))
            
            Spacer()
            
            Text(String(
                format: NSLocalizedString("Last %@", comment: "Time range label"),
                chartTimeRange.displayName
            ))
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
    
    /// Speed indicator view
    private func speedIndicator(label: String, value: String, icon: String, color: Color, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isActive ? color : .secondary)
        }
    }
    
    // MARK: - Health Dashboard Section
    
    /// Health dashboard with gauges
    /// Requirements: 4.4 - Display connection latency and health status indicators
    private var healthDashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            sectionHeader(
                title: NSLocalizedString("Health Dashboard", comment: "Health dashboard section"),
                icon: "heart.fill",
                color: .red
            )
            
            GlassCard(
                accessibility: .summary(
                    label: healthDashboardAccessibilityLabel,
                    hint: NSLocalizedString("Shows overall health metrics", comment: "Health dashboard hint")
                )
            ) {
                if storageViewModel.storageData.isEmpty {
                    Text(NSLocalizedString("No volumes to display", comment: "No volumes message"))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(storageViewModel.storageData) { volume in
                            healthGaugeCard(for: volume)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    /// Health gauge card for a volume
    private func healthGaugeCard(for volume: VolumeStorageData) -> some View {
        let metrics = healthMetrics[volume.id] ?? HealthMetrics.defaultMetrics(for: volume.id)
        
        return VStack(alignment: .leading, spacing: 12) {
            // Volume name
            Text(volume.volumeName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            // Gauges
            HStack(spacing: 16) {
                gaugeView(
                    value: metrics.healthScore,
                    maxValue: 100,
                    title: NSLocalizedString("Health", comment: "Health gauge"),
                    color: healthColor(for: metrics.healthScore)
                )
                
                gaugeView(
                    value: min(metrics.latencyMs, 500),
                    maxValue: 500,
                    title: NSLocalizedString("Latency", comment: "Latency gauge"),
                    unit: "ms",
                    color: latencyColor(for: metrics.latencyMs)
                )
                
                gaugeView(
                    value: metrics.successRate,
                    maxValue: 100,
                    title: NSLocalizedString("Success", comment: "Success rate gauge"),
                    unit: "%",
                    color: successRateColor(for: metrics.successRate)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    /// Gauge view component
    private func gaugeView(
        value: Double,
        maxValue: Double,
        title: String,
        unit: String = "",
        color: Color
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(min(value / maxValue, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                // Value
                VStack(spacing: 1) {
                    Text(String(format: "%.0f", value))
                        .font(.caption)
                        .fontWeight(.bold)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 60, height: 60)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(String(format: "%.0f", value))\(unit)")
    }
    
    // MARK: - Volume Details Section
    
    /// Volume details section with expandable cards
    /// Requirements: 4.5 - When user selects a disk, expand to show complete statistics
    private var volumeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            sectionHeader(
                title: NSLocalizedString("Volume Details", comment: "Volume details section"),
                icon: "list.bullet.rectangle",
                color: .purple
            )
            
            // Volume cards
            ForEach(storageViewModel.storageData) { volume in
                volumeDetailCard(for: volume)
                    .id("\(volume.id)-\(selectedVolume == volume.id ? "expanded" : "collapsed")")
            }
        }
    }
    
    /// Expandable volume detail card
    /// Requirements: 4.5 - When user selects a disk, expand to show complete statistics
    private func volumeDetailCard(for volume: VolumeStorageData) -> some View {
        let isExpanded = selectedVolume == volume.id
        let ioStats = ioViewModel.getStats(for: volume.id)
        let metrics = healthMetrics[volume.id] ?? HealthMetrics.defaultMetrics(for: volume.id)
        
        return GlassCard(
            accessibility: .button(
                label: volumeDetailAccessibilityLabel(for: volume, isExpanded: isExpanded),
                hint: isExpanded
                    ? NSLocalizedString("Tap to collapse", comment: "Collapse hint")
                    : NSLocalizedString("Tap to expand", comment: "Expand hint")
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header (always visible)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedVolume == volume.id {
                            selectedVolume = nil
                        } else {
                            selectedVolume = volume.id
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(volume.volumeName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(volume.smbURL)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Usage badge
                        usageLevelBadge(for: volume)
                        
                        // Expand/collapse indicator
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                
                // Expanded content
                if isExpanded {
                    Divider()
                    
                    // Storage details
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Storage", comment: "Storage section"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 20) {
                            detailItem(
                                label: NSLocalizedString("Total", comment: "Total"),
                                value: volume.formattedTotalCapacity
                            )
                            detailItem(
                                label: NSLocalizedString("Used", comment: "Used"),
                                value: volume.formattedUsedSpace,
                                color: volume.usageLevel.color
                            )
                            detailItem(
                                label: NSLocalizedString("Available", comment: "Available"),
                                value: volume.formattedAvailableSpace
                            )
                        }
                    }
                    
                    Divider()
                    
                    // IO statistics
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("IO Statistics", comment: "IO statistics section"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let stats = ioStats {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("Current", comment: "Current"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 8) {
                                        ioStatItem(icon: "arrow.down", value: stats.formattedReadSpeed, color: .blue)
                                        ioStatItem(icon: "arrow.up", value: stats.formattedWriteSpeed, color: .orange)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("Average", comment: "Average"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 8) {
                                        ioStatItem(icon: "arrow.down", value: stats.formattedAverageReadSpeed, color: .blue)
                                        ioStatItem(icon: "arrow.up", value: stats.formattedAverageWriteSpeed, color: .orange)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("Peak", comment: "Peak"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 8) {
                                        ioStatItem(icon: "arrow.down", value: stats.formattedPeakReadSpeed, color: .blue)
                                        ioStatItem(icon: "arrow.up", value: stats.formattedPeakWriteSpeed, color: .orange)
                                    }
                                }
                            }
                        } else {
                            Text(NSLocalizedString("No IO data available", comment: "No IO data"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Health metrics
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Health Metrics", comment: "Health metrics section"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 20) {
                            detailItem(
                                label: NSLocalizedString("Health Score", comment: "Health score"),
                                value: String(format: "%.0f%%", metrics.healthScore),
                                color: healthColor(for: metrics.healthScore)
                            )
                            detailItem(
                                label: NSLocalizedString("Latency", comment: "Latency"),
                                value: String(format: "%.0f ms", metrics.latencyMs),
                                color: latencyColor(for: metrics.latencyMs)
                            )
                            detailItem(
                                label: NSLocalizedString("Success Rate", comment: "Success rate"),
                                value: String(format: "%.0f%%", metrics.successRate),
                                color: successRateColor(for: metrics.successRate)
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }

    /// Detail item view
    private func detailItem(label: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
    
    /// IO stat item view
    private func ioStatItem(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .foregroundColor(color)
        }
    }
    
    // MARK: - Empty State View
    
    /// Empty state view when no volumes are mounted
    private var emptyStateView: some View {
        GlassCard(
            accessibility: .summary(
                label: NSLocalizedString(
                    "No mounted disks. Mount a disk to see storage information.",
                    comment: "Empty state accessibility"
                )
            )
        ) {
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text(NSLocalizedString("No Mounted Disks", comment: "Empty state title"))
                    .font(.headline)
                
                Text(NSLocalizedString(
                    "Mount a disk to view storage information, IO performance, and health metrics.",
                    comment: "Empty state message"
                ))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Helper Views
    
    /// Section header view
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
    
    /// Legend item view
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Color Helpers
    
    /// Returns color based on health score
    private func healthColor(for score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    /// Returns color based on latency
    private func latencyColor(for latency: Double) -> Color {
        switch latency {
        case 0..<100: return .green
        case 100..<200: return .yellow
        case 200..<300: return .orange
        default: return .red
        }
    }
    
    /// Returns color based on success rate
    private func successRateColor(for rate: Double) -> Color {
        switch rate {
        case 95...100: return .green
        case 80..<95: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    // MARK: - Formatting Helpers
    
    /// Formats time for chart axis
    private func formatAxisTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// Formats speed for chart axis
    private func formatAxisSpeed(_ bytes: Int64) -> String {
        if bytes == 0 { return "0" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + "/s"
    }
    
    /// Formats date for export filename
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    // MARK: - Accessibility Labels
    
    /// Accessibility label for IO performance section
    private var ioPerformanceAccessibilityLabel: String {
        String(
            format: NSLocalizedString(
                "IO Performance: Read %@, Write %@",
                comment: "IO performance accessibility"
            ),
            ioViewModel.formattedTotalReadSpeed,
            ioViewModel.formattedTotalWriteSpeed
        )
    }
    
    /// Accessibility label for health dashboard
    private var healthDashboardAccessibilityLabel: String {
        let volumeCount = storageViewModel.storageData.count
        return String(
            format: NSLocalizedString(
                "Health dashboard showing metrics for %d volumes",
                comment: "Health dashboard accessibility"
            ),
            volumeCount
        )
    }
    
    /// Accessibility label for volume detail card
    private func volumeDetailAccessibilityLabel(for volume: VolumeStorageData, isExpanded: Bool) -> String {
        let expandedState = isExpanded
            ? NSLocalizedString("expanded", comment: "Expanded state")
            : NSLocalizedString("collapsed", comment: "Collapsed state")
        
        return String(
            format: NSLocalizedString(
                "%@ volume details, %@, %.1f percent used",
                comment: "Volume detail accessibility"
            ),
            volume.volumeName,
            expandedState,
            volume.usagePercentage
        )
    }
    
    // MARK: - Export Functionality
    
    /// Exports disk statistics as JSON
    /// Requirements: 4.6 - Support exporting disk statistics report
    private func exportStatistics() {
        let report = generateStatisticsReport()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            
            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "disk_statistics_\(formattedDate()).json"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            exportFileURL = fileURL
            showingExportSheet = true
        } catch {
            print("Failed to export statistics: \(error)")
        }
    }
    
    /// Generates statistics report from current data
    private func generateStatisticsReport() -> DiskStatisticsReport {
        let volumeReports = storageViewModel.storageData.map { volume -> DiskStatisticsReport.VolumeReport in
            let ioStats = ioViewModel.getStats(for: volume.id)
            let metrics = healthMetrics[volume.id] ?? HealthMetrics.defaultMetrics(for: volume.id)
            
            return DiskStatisticsReport.VolumeReport(
                volumeName: volume.volumeName,
                server: volume.server,
                share: volume.share,
                totalBytes: volume.totalBytes,
                usedBytes: volume.usedBytes,
                availableBytes: volume.availableBytes,
                usagePercentage: volume.usagePercentage,
                currentReadSpeed: ioStats?.readBytesPerSecond ?? 0,
                currentWriteSpeed: ioStats?.writeBytesPerSecond ?? 0,
                averageReadSpeed: ioStats?.averageReadSpeed ?? 0,
                averageWriteSpeed: ioStats?.averageWriteSpeed ?? 0,
                peakReadSpeed: ioStats?.peakReadSpeed ?? 0,
                peakWriteSpeed: ioStats?.peakWriteSpeed ?? 0,
                healthScore: metrics.healthScore,
                latencyMs: metrics.latencyMs,
                successRate: metrics.successRate
            )
        }
        
        return DiskStatisticsReport(
            generatedAt: Date(),
            volumes: volumeReports
        )
    }
    
    /// Handles export result
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Statistics exported to: \(url)")
        case .failure(let error):
            print("Export failed: \(error)")
        }
        
        // Clean up temporary file
        if let tempURL = exportFileURL {
            try? FileManager.default.removeItem(at: tempURL)
            exportFileURL = nil
        }
    }
    
    /// Initializes health metrics for all volumes
    private func initializeHealthMetrics() {
        for volume in storageViewModel.storageData {
            if healthMetrics[volume.id] == nil {
                healthMetrics[volume.id] = HealthMetrics.defaultMetrics(for: volume.id)
            }
        }
    }
}

// MARK: - StatisticsDocument

/// Document wrapper for file export
struct StatisticsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        // Not used for export-only document
        self.url = URL(fileURLWithPath: "")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 13.0, *)
struct DiskInfoTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            DiskInfoTabView(
                storageViewModel: StorageViewModel(),
                ioViewModel: IOMonitorViewModel()
            )
            .frame(width: 900, height: 800)
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
            
            // Dark mode preview
            DiskInfoTabView(
                storageViewModel: StorageViewModel(),
                ioViewModel: IOMonitorViewModel()
            )
            .frame(width: 900, height: 800)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
