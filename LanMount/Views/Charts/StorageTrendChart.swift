//
//  StorageTrendChart.swift
//  LanMount
//
//  Storage trend chart component for visualizing storage changes over time
//  Requirements: 6.1, 6.5
//

import SwiftUI
import Charts

// Note: StorageTrendDataPoint is now defined in ChartModels.swift

// MARK: - StorageTrendChart

/// 存储趋势图（显示过去 7 天的存储变化）
/// A chart view that displays storage usage trends over the past 7 days
///
/// This component visualizes storage changes with support for:
/// - Line chart showing storage usage over time
/// - Area chart with gradient fill for visual emphasis
/// - Multi-volume support with color differentiation
/// - Hover interaction to show precise values at specific time points
/// - Full VoiceOver accessibility support
///
/// Requirements:
/// - 6.1: Display storage usage trend chart (past 7 days)
/// - 6.5: Show precise values when user hovers on the chart
///
/// Example usage:
/// ```swift
/// StorageTrendChart(data: trendDataPoints)
///
/// // With custom chart height
/// StorageTrendChart(data: trendDataPoints, chartHeight: 250)
/// ```
@available(macOS 13.0, *)
struct StorageTrendChart: View {
    /// 趋势数据点数组
    let data: [StorageTrendDataPoint]
    
    /// 图表高度
    var chartHeight: CGFloat = 200
    
    /// 是否显示图例
    var showLegend: Bool = true
    
    // MARK: - Private State
    
    /// 当前选中/悬停的数据点
    @State private var selectedPoint: StorageTrendDataPoint?
    
    /// 悬停位置
    @State private var hoverPosition: CGPoint = .zero
    
    /// 当前悬停的日期
    @State private var hoveredDate: Date?
    
    // MARK: - Computed Properties
    
    /// 是否有数据可显示
    private var hasData: Bool {
        !data.isEmpty
    }
    
    /// 获取所有唯一的卷名称
    private var volumeNames: [String] {
        Array(Set(data.map { $0.volumeName })).sorted()
    }
    
    /// 获取时间范围（过去7天）
    private var timeRange: ClosedRange<Date> {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return sevenDaysAgo...now
    }
    
    /// 获取Y轴最大值
    private var maxUsedBytes: Int64 {
        data.map { $0.usedBytes }.max() ?? 0
    }
    
    /// 为每个卷分配颜色
    private var volumeColors: [String: Color] {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .indigo, .mint]
        var colorMap: [String: Color] = [:]
        for (index, name) in volumeNames.enumerated() {
            colorMap[name] = colors[index % colors.count]
        }
        return colorMap
    }
    
    // MARK: - Body
    
    var body: some View {
        GlassCard(
            accessibility: .summary(
                label: accessibilityLabel,
                hint: NSLocalizedString(
                    "Shows storage usage trends over the past 7 days. Hover to see precise values.",
                    comment: "Storage trend chart accessibility hint"
                )
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerView
                
                if !hasData {
                    emptyStateView
                } else {
                    // Main chart
                    chartView
                    
                    // Legend
                    if showLegend && volumeNames.count > 1 {
                        legendView
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
                Text(NSLocalizedString("存储趋势", comment: "Storage trend chart title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(NSLocalizedString("Storage Trend Chart", comment: "Storage trend header accessibility"))
            
            Spacer()
            
            // Time range indicator
            Text(NSLocalizedString("过去 7 天", comment: "Past 7 days label"))
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel(NSLocalizedString("Showing data from the past 7 days", comment: "Time range accessibility"))
        }
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        ZStack(alignment: .topLeading) {
            Chart {
                ForEach(data) { point in
                    // Line mark for trend visualization
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("使用量", point.usedBytes)
                    )
                    .foregroundStyle(by: .value("卷", point.volumeName))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    // Area mark for visual emphasis
                    AreaMark(
                        x: .value("日期", point.date),
                        y: .value("使用量", point.usedBytes)
                    )
                    .foregroundStyle(by: .value("卷", point.volumeName))
                    .opacity(0.3)
                }
                
                // Hover rule line
                if let hoveredDate = hoveredDate {
                    RuleMark(x: .value("日期", hoveredDate))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartXScale(domain: timeRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatAxisDate(date))
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
                            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartForegroundStyleScale(mapping: { (volumeName: String) -> Color in
                volumeColors[volumeName] ?? .blue
            })
            .chartLegend(showLegend && volumeNames.count > 1 ? .visible : .hidden)
            .frame(height: chartHeight)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            handleHover(phase: phase, proxy: proxy, geometry: geometry)
                        }
                }
            }
            .accessibilityLabel(chartAccessibilityLabel)
            .accessibilityHint(NSLocalizedString(
                "Hover over the chart to see precise values at specific dates",
                comment: "Chart hover hint"
            ))
            
            // Hover tooltip
            if let selectedPoint = selectedPoint {
                hoverTooltip(for: selectedPoint)
                    .offset(x: max(0, min(hoverPosition.x - 80, 200)), y: 10)
            }
        }
    }
    
    // MARK: - Hover Handling
    
    /// 处理悬停事件
    /// Requirements: 6.5 - Show precise values when user hovers on the chart
    private func handleHover(phase: HoverPhase, proxy: ChartProxy, geometry: GeometryProxy) {
        switch phase {
        case .active(let location):
            hoverPosition = location
            
            // Find the closest data point to the hover position
            if let date: Date = proxy.value(atX: location.x) {
                hoveredDate = date
                
                // Find the closest data point
                let closestPoint = data.min(by: { point1, point2 in
                    abs(point1.date.timeIntervalSince(date)) < abs(point2.date.timeIntervalSince(date))
                })
                
                selectedPoint = closestPoint
            }
            
        case .ended:
            hoveredDate = nil
            selectedPoint = nil
        }
    }
    
    // MARK: - Hover Tooltip
    
    /// 创建悬停提示视图
    /// Requirements: 6.5 - Show precise values when user hovers on the chart
    private func hoverTooltip(for point: StorageTrendDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date and time
            Text(point.formattedDate)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Volume name
            HStack(spacing: 4) {
                Circle()
                    .fill(volumeColors[point.volumeName] ?? .blue)
                    .frame(width: 8, height: 8)
                Text(point.volumeName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Divider()
            
            // Used space
            HStack(spacing: 4) {
                Text(NSLocalizedString("已用:", comment: "Used label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(point.formattedUsedBytes)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            // Total space
            HStack(spacing: 4) {
                Text(NSLocalizedString("总计:", comment: "Total label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(point.formattedTotalBytes)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            // Usage percentage
            HStack(spacing: 4) {
                Text(NSLocalizedString("使用率:", comment: "Usage label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%%", point.usagePercentage))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(usageColor(for: point.usagePercentage))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tooltipAccessibilityLabel(for: point))
    }
    
    // MARK: - Legend View
    
    private var legendView: some View {
        HStack(spacing: 16) {
            ForEach(volumeNames, id: \.self) { name in
                HStack(spacing: 6) {
                    Circle()
                        .fill(volumeColors[name] ?? .blue)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(
                    format: NSLocalizedString(
                        "%@ volume",
                        comment: "Legend item accessibility"
                    ),
                    name
                ))
            }
            
            Spacer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString(
            "Chart legend showing volume colors",
            comment: "Legend accessibility label"
        ))
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("暂无趋势数据", comment: "No trend data title"))
                .font(.headline)
            
            Text(NSLocalizedString(
                "存储趋势数据将在收集后显示",
                comment: "No trend data message"
            ))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString(
            "No storage trend data available. Data will appear after collection.",
            comment: "Empty state accessibility label"
        ))
    }
    
    // MARK: - Helper Methods
    
    /// 格式化X轴日期
    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"  // Abbreviated weekday
        return formatter.string(from: date)
    }
    
    /// 根据使用率返回颜色
    private func usageColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<80: return .green
        case 80..<95: return .orange
        default: return .red
        }
    }
    
    /// 提示框的无障碍标签
    private func tooltipAccessibilityLabel(for point: StorageTrendDataPoint) -> String {
        String(
            format: NSLocalizedString(
                "On %@, %@: %@ used of %@ total, %.1f percent usage",
                comment: "Tooltip accessibility label"
            ),
            point.formattedDate,
            point.volumeName,
            point.formattedUsedBytes,
            point.formattedTotalBytes,
            point.usagePercentage
        )
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        if data.isEmpty {
            return NSLocalizedString("Storage trend chart: No data available", comment: "Empty chart accessibility")
        }
        
        let volumeCount = volumeNames.count
        return String(
            format: NSLocalizedString(
                "Storage trend chart showing %d volumes over the past 7 days",
                comment: "Chart accessibility label"
            ),
            volumeCount
        )
    }
    
    private var chartAccessibilityLabel: String {
        if data.isEmpty {
            return NSLocalizedString("Empty storage trend chart", comment: "Empty chart accessibility")
        }
        
        // Summarize the data for accessibility
        let latestPoints = volumeNames.compactMap { name -> StorageTrendDataPoint? in
            data.filter { $0.volumeName == name }.max(by: { $0.date < $1.date })
        }
        
        let descriptions = latestPoints.map { point in
            String(
                format: NSLocalizedString(
                    "%@: %@ used, %.1f percent",
                    comment: "Volume summary accessibility"
                ),
                point.volumeName,
                point.formattedUsedBytes,
                point.usagePercentage
            )
        }.joined(separator: ". ")
        
        return String(
            format: NSLocalizedString(
                "Storage trend chart. Latest values: %@",
                comment: "Chart data accessibility label"
            ),
            descriptions
        )
    }
}

// MARK: - StorageTrendChart + Convenience Initializers

@available(macOS 13.0, *)
extension StorageTrendChart {
    /// 创建紧凑型存储趋势图
    /// Creates a compact storage trend chart without legend
    static func compact(data: [StorageTrendDataPoint]) -> StorageTrendChart {
        var chart = StorageTrendChart(data: data)
        chart.showLegend = false
        chart.chartHeight = 150
        return chart
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 13.0, *)
struct StorageTrendChart_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With sample data
            StorageTrendChart(data: sampleData)
                .frame(width: 500, height: 350)
                .previewDisplayName("With Data")
            
            // Empty state
            StorageTrendChart(data: [])
                .frame(width: 500, height: 350)
                .previewDisplayName("Empty State")
            
            // Compact version
            StorageTrendChart.compact(data: sampleData)
                .frame(width: 400, height: 250)
                .previewDisplayName("Compact")
            
            // Dark mode
            StorageTrendChart(data: sampleData)
                .frame(width: 500, height: 350)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    static var sampleData: [StorageTrendDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        let volumeId1 = UUID()
        let volumeId2 = UUID()
        
        var points: [StorageTrendDataPoint] = []
        
        // Generate sample data for two volumes over 7 days
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // Volume 1: Gradually increasing usage
            let used1 = Int64(500_000_000_000) + Int64(dayOffset * 10_000_000_000)
            points.append(StorageTrendDataPoint(
                volumeId: volumeId1,
                volumeName: "NAS-Main",
                date: date,
                usedBytes: used1,
                totalBytes: 1_000_000_000_000
            ))
            
            // Volume 2: Fluctuating usage
            let used2 = Int64(200_000_000_000) + Int64((dayOffset % 3) * 50_000_000_000)
            points.append(StorageTrendDataPoint(
                volumeId: volumeId2,
                volumeName: "Backup-Drive",
                date: date,
                usedBytes: used2,
                totalBytes: 500_000_000_000
            ))
        }
        
        return points.sorted { $0.date < $1.date }
    }
}
#endif
