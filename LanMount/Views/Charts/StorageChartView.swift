//
//  StorageChartView.swift
//  LanMount
//
//  Storage chart view component for visualizing disk storage usage
//  Requirements: 2.1, 2.4, 2.5, 8.2
//

import SwiftUI
import Charts

// MARK: - StorageChartStyle

/// The style of chart to display for storage visualization
enum StorageChartStyle: String, CaseIterable, Identifiable {
    /// Ring/donut chart showing used vs available space
    case ring
    /// Horizontal bar chart showing storage breakdown
    case bar
    
    var id: String { rawValue }
    
    /// Localized display name for the chart style
    var displayName: String {
        switch self {
        case .ring:
            return NSLocalizedString("Ring Chart", comment: "Ring chart style name")
        case .bar:
            return NSLocalizedString("Bar Chart", comment: "Bar chart style name")
        }
    }
}

// MARK: - StorageChartData

/// Data structure for chart segments
struct StorageChartData: Identifiable {
    let id = UUID()
    let label: String
    let value: Int64
    let color: Color
    let isUsed: Bool
    
    /// Formatted value string
    var formattedValue: String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

// MARK: - StorageChartView

/// A view that displays storage usage data as either a ring chart or bar chart
///
/// This component visualizes disk storage usage with support for:
/// - Ring (donut) chart showing used vs available space
/// - Bar chart showing storage breakdown per volume
/// - Warning color (orange) highlighting when usage exceeds 80%
/// - Danger color (red) highlighting when usage exceeds 95%
/// - Full VoiceOver accessibility support with text alternative descriptions
///
/// Requirements:
/// - 2.1: Display used and available space as ring or bar chart
/// - 2.4: Warning color (orange) when usage > 80%
/// - 2.5: Danger color (red) when usage > 95%
/// - 8.2: Provide text alternative descriptions for screen readers
///
/// Example usage:
/// ```swift
/// StorageChartView(viewModel: storageViewModel)
///
/// // With specific chart style
/// StorageChartView(viewModel: storageViewModel, chartStyle: .bar)
///
/// // For a single volume
/// StorageChartView(viewModel: storageViewModel, volumeId: volume.id)
/// ```
@available(macOS 13.0, *)
struct StorageChartView: View {
    /// The view model providing storage data
    @ObservedObject var viewModel: StorageViewModel
    
    /// The style of chart to display
    var chartStyle: StorageChartStyle = .ring
    
    /// Optional specific volume ID to display (nil shows all volumes)
    var volumeId: UUID? = nil
    
    /// Whether to show the legend
    var showLegend: Bool = true
    
    /// Whether to show the summary statistics
    var showSummary: Bool = true
    
    /// The height of the chart
    var chartHeight: CGFloat = 200
    
    // MARK: - Private State
    
    @State private var selectedSegment: StorageChartData? = nil
    @State private var hoveredVolume: UUID? = nil
    
    // MARK: - Computed Properties
    
    /// The volumes to display based on volumeId filter
    private var displayVolumes: [VolumeStorageData] {
        if let volumeId = volumeId {
            return viewModel.storageData.filter { $0.id == volumeId }
        }
        return viewModel.storageData
    }
    
    /// Whether there is data to display
    private var hasData: Bool {
        !displayVolumes.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        GlassCard(
            accessibility: .summary(
                label: accessibilityLabel,
                hint: NSLocalizedString(
                    "Shows storage usage visualization",
                    comment: "Storage chart accessibility hint"
                )
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerView
                
                if viewModel.isLoading {
                    loadingView
                } else if !hasData {
                    emptyStateView
                } else {
                    // Chart content
                    chartContent
                    
                    // Legend
                    if showLegend {
                        legendView
                    }
                    
                    // Summary
                    if showSummary {
                        summaryView
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Label {
                Text(NSLocalizedString("Storage", comment: "Storage chart title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "internaldrive")
                    .foregroundColor(.accentColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(NSLocalizedString("Storage Chart", comment: "Storage chart header accessibility"))
            
            Spacer()
            
            // Chart style picker
            Picker("", selection: Binding(
                get: { chartStyle },
                set: { _ in } // Read-only in this context
            )) {
                ForEach(StorageChartStyle.allCases) { style in
                    Image(systemName: style == .ring ? "circle.circle" : "chart.bar.fill")
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            .accessibilityLabel(NSLocalizedString("Chart style", comment: "Chart style picker label"))
            .accessibilityHint(String(
                format: NSLocalizedString(
                    "Currently showing %@. Select to change chart display style.",
                    comment: "Chart style picker hint"
                ),
                chartStyle.displayName
            ))
        }
    }
    
    // MARK: - Chart Content
    
    @ViewBuilder
    private var chartContent: some View {
        switch chartStyle {
        case .ring:
            ringChartView
        case .bar:
            barChartView
        }
    }
    
    // MARK: - Ring Chart View
    
    private var ringChartView: some View {
        VStack(spacing: 12) {
            ForEach(displayVolumes) { volume in
                VStack(alignment: .leading, spacing: 8) {
                    // Volume name
                    Text(volume.volumeName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack(spacing: 16) {
                        // Ring chart
                        ringChart(for: volume)
                            .frame(width: 80, height: 80)
                        
                        // Details
                        VStack(alignment: .leading, spacing: 4) {
                            storageDetailRow(
                                label: NSLocalizedString("Used", comment: "Used storage label"),
                                value: volume.formattedUsedSpace,
                                color: volume.usageLevel.color
                            )
                            storageDetailRow(
                                label: NSLocalizedString("Available", comment: "Available storage label"),
                                value: volume.formattedAvailableSpace,
                                color: .secondary
                            )
                            storageDetailRow(
                                label: NSLocalizedString("Total", comment: "Total storage label"),
                                value: volume.formattedTotalCapacity,
                                color: .primary
                            )
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(storageDetailsAccessibilityLabel(for: volume))
                        
                        Spacer()
                        
                        // Usage percentage badge
                        usagePercentageBadge(for: volume)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hoveredVolume == volume.id ? Color.primary.opacity(0.05) : Color.clear)
                )
                .onHover { isHovered in
                    hoveredVolume = isHovered ? volume.id : nil
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(
                    format: NSLocalizedString(
                        "%@ storage information",
                        comment: "Volume section accessibility label"
                    ),
                    volume.volumeName
                ))
                
                if volume.id != displayVolumes.last?.id {
                    Divider()
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ringChartAccessibilityLabel)
    }
    
    /// Accessibility label for storage details
    private func storageDetailsAccessibilityLabel(for volume: VolumeStorageData) -> String {
        return String(
            format: NSLocalizedString(
                "Storage details: %@ used, %@ available, %@ total capacity",
                comment: "Storage details accessibility label"
            ),
            volume.formattedUsedSpace,
            volume.formattedAvailableSpace,
            volume.formattedTotalCapacity
        )
    }
    
    /// Accessibility label for the ring chart section
    private var ringChartAccessibilityLabel: String {
        if displayVolumes.isEmpty {
            return NSLocalizedString("Ring chart: No storage data available", comment: "Empty ring chart accessibility")
        }
        
        return String(
            format: NSLocalizedString(
                "Storage ring charts showing %d volumes",
                comment: "Ring chart section accessibility label"
            ),
            displayVolumes.count
        )
    }
    
    /// Creates a ring chart for a single volume
    @ViewBuilder
    private func ringChart(for volume: VolumeStorageData) -> some View {
        let chartData = [
            StorageChartData(
                label: NSLocalizedString("Used", comment: "Used storage"),
                value: volume.usedBytes,
                color: volume.usageLevel.color,
                isUsed: true
            ),
            StorageChartData(
                label: NSLocalizedString("Available", comment: "Available storage"),
                value: volume.availableBytes,
                color: Color.gray.opacity(0.3),
                isUsed: false
            )
        ]
        
        if #available(macOS 14.0, *) {
            Chart(chartData) { data in
                SectorMark(
                    angle: .value("Storage", data.value),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(data.color)
                .cornerRadius(4)
            }
            .chartLegend(.hidden)
            .accessibilityLabel(volume.accessibilityDescription)
        } else {
            // Fallback for macOS 13.0 - use a simple progress view
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(volume.usagePercentage / 100))
                        .stroke(volume.usageLevel.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(String(format: "%.0f%%", volume.usagePercentage))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .accessibilityLabel(volume.accessibilityDescription)
        }
    }
    
    // MARK: - Bar Chart View
    
    private var barChartView: some View {
        VStack(spacing: 16) {
            Chart {
                ForEach(displayVolumes) { volume in
                    // Used space bar
                    BarMark(
                        x: .value("Storage", volume.usedBytes),
                        y: .value("Volume", volume.volumeName)
                    )
                    .foregroundStyle(volume.usageLevel.color)
                    .annotation(position: .trailing, alignment: .leading) {
                        if hoveredVolume == volume.id {
                            Text(volume.formattedUsedSpace)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Available space bar (stacked)
                    BarMark(
                        x: .value("Storage", volume.availableBytes),
                        y: .value("Volume", volume.volumeName)
                    )
                    .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let bytes = value.as(Int64.self) {
                            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .frame(height: CGFloat(displayVolumes.count) * 50 + 40)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let volumeName: String = proxy.value(atY: location.y) {
                                    hoveredVolume = displayVolumes.first { $0.volumeName == volumeName }?.id
                                }
                            case .ended:
                                hoveredVolume = nil
                            }
                        }
                }
            }
            .accessibilityLabel(barChartAccessibilityLabel)
            .accessibilityHint(NSLocalizedString(
                "Bar chart showing storage usage for each volume",
                comment: "Bar chart accessibility hint"
            ))
            
            // Volume details below chart with accessibility
            ForEach(displayVolumes) { volume in
                HStack {
                    Circle()
                        .fill(volume.usageLevel.color)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    
                    Text(volume.volumeName)
                        .font(.caption)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", volume.usagePercentage))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(volume.usageLevel.color)
                }
                .padding(.horizontal, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(volume.accessibilityDescription)
            }
        }
    }
    
    /// Accessibility label for the bar chart
    private var barChartAccessibilityLabel: String {
        if displayVolumes.isEmpty {
            return NSLocalizedString("Bar chart: No storage data available", comment: "Empty bar chart accessibility")
        }
        
        let volumeDescriptions = displayVolumes.map { volume in
            volume.accessibilityDescription
        }.joined(separator: ". ")
        
        return String(
            format: NSLocalizedString(
                "Storage bar chart with %d volumes. %@",
                comment: "Bar chart accessibility label"
            ),
            displayVolumes.count,
            volumeDescriptions
        )
    }
    
    // MARK: - Helper Views
    
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
        .frame(width: 140)
    }
    
    private func usagePercentageBadge(for volume: VolumeStorageData) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f%%", volume.usagePercentage))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(volume.usageLevel.color)
            
            Text(volume.usageLevel.localizedDescription)
                .font(.caption2)
                .foregroundColor(volume.usageLevel.color.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(volume.usageLevel.color.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "%@ usage: %.1f percent, %@",
                comment: "Usage badge accessibility label"
            ),
            volume.volumeName,
            volume.usagePercentage,
            volume.usageLevel.localizedDescription
        ))
    }
    
    // MARK: - Legend View
    
    private var legendView: some View {
        HStack(spacing: 16) {
            legendItem(color: .green, label: NSLocalizedString("Normal (<80%)", comment: "Normal usage legend"))
            legendItem(color: .orange, label: NSLocalizedString("Warning (80-95%)", comment: "Warning usage legend"))
            legendItem(color: .red, label: NSLocalizedString("Critical (>95%)", comment: "Critical usage legend"))
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString(
            "Legend: Green indicates normal usage below 80 percent, orange indicates warning between 80 and 95 percent, red indicates critical above 95 percent",
            comment: "Storage chart legend accessibility label"
        ))
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(label)
        }
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Summary View
    
    private var summaryView: some View {
        let summary = viewModel.totalStorage
        
        return VStack(spacing: 8) {
            Divider()
                .accessibilityHidden(true)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Total Storage", comment: "Total storage summary label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(summary.formattedTotalCapacity)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(
                    format: NSLocalizedString(
                        "Total storage capacity: %@",
                        comment: "Total capacity accessibility label"
                    ),
                    summary.formattedTotalCapacity
                ))
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text(NSLocalizedString("Used", comment: "Used storage summary label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(summary.formattedTotalUsed)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(summary.overallUsageLevel.color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(
                    format: NSLocalizedString(
                        "Total used storage: %@, %@",
                        comment: "Total used accessibility label"
                    ),
                    summary.formattedTotalUsed,
                    summary.overallUsageLevel.localizedDescription
                ))
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(NSLocalizedString("Available", comment: "Available storage summary label"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(summary.formattedTotalAvailable)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(
                    format: NSLocalizedString(
                        "Total available storage: %@",
                        comment: "Total available accessibility label"
                    ),
                    summary.formattedTotalAvailable
                ))
            }
            
            // Overall usage bar
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                format: NSLocalizedString(
                    "Overall storage usage: %.1f percent, %@",
                    comment: "Overall usage accessibility label with level"
                ),
                summary.overallUsagePercentage,
                summary.overallUsageLevel.localizedDescription
            ))
            .accessibilityValue(String(format: "%.0f%%", summary.overallUsagePercentage))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(summaryAccessibilityLabel)
    }
    
    /// Accessibility label for the summary section
    private var summaryAccessibilityLabel: String {
        let summary = viewModel.totalStorage
        return String(
            format: NSLocalizedString(
                "Storage summary for %d volumes: %@ total capacity, %@ used, %@ available, %.1f percent full",
                comment: "Storage summary accessibility label"
            ),
            summary.volumeCount,
            summary.formattedTotalCapacity,
            summary.formattedTotalUsed,
            summary.formattedTotalAvailable,
            summary.overallUsagePercentage
        )
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .accessibilityHidden(true)
            Text(NSLocalizedString("Loading storage data...", comment: "Loading storage data message"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString(
            "Loading storage data, please wait",
            comment: "Loading state accessibility label"
        ))
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("No Storage Data", comment: "No storage data title"))
                .font(.headline)
            
            Text(NSLocalizedString(
                "Mount a drive to see storage information",
                comment: "No storage data message"
            ))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString(
            "No storage data available. Mount a drive to see storage information.",
            comment: "Empty state accessibility label"
        ))
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        if displayVolumes.isEmpty {
            return NSLocalizedString("Storage chart: No data available", comment: "Empty storage chart accessibility")
        }
        
        let volumeDescriptions = displayVolumes.map { volume in
            String(
                format: NSLocalizedString(
                    "%@: %.1f percent used",
                    comment: "Volume usage accessibility description"
                ),
                volume.volumeName,
                volume.usagePercentage
            )
        }.joined(separator: ", ")
        
        return String(
            format: NSLocalizedString(
                "Storage chart showing %d volumes: %@",
                comment: "Storage chart accessibility label"
            ),
            displayVolumes.count,
            volumeDescriptions
        )
    }
}

// MARK: - StorageChartView + Convenience Initializers

@available(macOS 13.0, *)
extension StorageChartView {
    /// Creates a storage chart view for a single volume
    /// - Parameters:
    ///   - viewModel: The storage view model
    ///   - volume: The specific volume to display
    ///   - chartStyle: The chart style to use
    init(viewModel: StorageViewModel, volume: VolumeStorageData, chartStyle: StorageChartStyle = .ring) {
        self.viewModel = viewModel
        self.volumeId = volume.id
        self.chartStyle = chartStyle
    }
    
    /// Creates a compact storage chart view without legend and summary
    /// - Parameters:
    ///   - viewModel: The storage view model
    ///   - chartStyle: The chart style to use
    static func compact(viewModel: StorageViewModel, chartStyle: StorageChartStyle = .ring) -> StorageChartView {
        var view = StorageChartView(viewModel: viewModel, chartStyle: chartStyle)
        view.showLegend = false
        view.showSummary = false
        view.chartHeight = 120
        return view
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 13.0, *)
struct StorageChartView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Ring chart preview
            StorageChartView(
                viewModel: previewViewModel,
                chartStyle: .ring
            )
            .frame(width: 400, height: 500)
            .previewDisplayName("Ring Chart")
            
            // Bar chart preview
            StorageChartView(
                viewModel: previewViewModel,
                chartStyle: .bar
            )
            .frame(width: 400, height: 400)
            .previewDisplayName("Bar Chart")
            
            // Empty state preview
            StorageChartView(
                viewModel: emptyViewModel,
                chartStyle: .ring
            )
            .frame(width: 400, height: 300)
            .previewDisplayName("Empty State")
            
            // Dark mode preview
            StorageChartView(
                viewModel: previewViewModel,
                chartStyle: .ring
            )
            .frame(width: 400, height: 500)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    static var previewViewModel: StorageViewModel {
        let vm = StorageViewModel()
        // Note: In a real preview, we would inject mock data
        return vm
    }
    
    static var emptyViewModel: StorageViewModel {
        StorageViewModel()
    }
}
#endif
