//
//  IOHistoryChart.swift
//  LanMount
//
//  IO history chart component for visualizing read/write speed over time
//  Requirements: 6.2, 6.4, 6.5
//

import SwiftUI
import Charts

// Note: ChartTimeRange is now defined in ChartModels.swift

// MARK: - IOHistoryChart

/// IO 历史图（显示读写速度历史）
/// A chart view that displays IO read/write speed history over time
///
/// This component visualizes IO performance with support for:
/// - Dual-line chart showing read and write speeds
/// - Time range selection (1 minute, 5 minutes, 1 hour)
/// - Hover interaction to show precise values at specific time points
/// - Full VoiceOver accessibility support
///
/// Requirements:
/// - 6.2: Display IO performance history chart (read/write speed)
/// - 6.4: Support chart zoom and time range selection
/// - 6.5: Show precise values when user hovers on the chart
///
/// Example usage:
/// ```swift
/// IOHistoryChart(data: ioDataPoints, timeRange: .hour)
///
/// // With binding for time range selection
/// @State var selectedRange: ChartTimeRange = .hour
/// IOHistoryChart(data: ioDataPoints, timeRange: selectedRange)
/// ```
@available(macOS 13.0, *)
struct IOHistoryChart: View {
    /// IO 数据点数组
    let data: [IODataPoint]
    
    /// 当前选中的时间范围
    @Binding var timeRange: ChartTimeRange
    
    /// 图表高度
    var chartHeight: CGFloat = 200
    
    /// 是否显示图例
    var showLegend: Bool = true
    
    /// 是否显示时间范围选择器
    var showTimeRangePicker: Bool = true
    
    // MARK: - Private State
    
    /// 当前选中/悬停的数据点
    @State private var selectedPoint: IODataPoint?
    
    /// 悬停位置
    @State private var hoverPosition: CGPoint = .zero
    
    /// 当前悬停的时间
    @State private var hoveredDate: Date?
    
    // MARK: - Computed Properties
    
    /// 是否有数据可显示
    private var hasData: Bool {
        !filteredData.isEmpty
    }
    
    /// 根据时间范围过滤后的数据
    private var filteredData: [IODataPoint] {
        let range = timeRange.dateRange
        return data.filter { range.contains($0.timestamp) }
    }
    
    /// 获取Y轴最大值（用于统一刻度）
    private var maxSpeed: Int64 {
        let maxRead = filteredData.map { $0.readSpeed }.max() ?? 0
        let maxWrite = filteredData.map { $0.writeSpeed }.max() ?? 0
        let maxValue = max(maxRead, maxWrite)
        // Add 10% padding for visual clarity
        return max(maxValue + maxValue / 10, 1024) // Minimum 1KB/s
    }
    
    // MARK: - Initialization
    
    /// Creates an IOHistoryChart with a binding for time range
    /// - Parameters:
    ///   - data: Array of IO data points to display
    ///   - timeRange: Binding to the selected time range
    init(data: [IODataPoint], timeRange: Binding<ChartTimeRange>) {
        self.data = data
        self._timeRange = timeRange
    }
    
    /// Creates an IOHistoryChart with a constant time range
    /// - Parameters:
    ///   - data: Array of IO data points to display
    ///   - timeRange: The time range to display (constant)
    init(data: [IODataPoint], timeRange: ChartTimeRange) {
        self.data = data
        self._timeRange = .constant(timeRange)
    }
    
    // MARK: - Body
    
    var body: some View {
        GlassCard(
            accessibility: .summary(
                label: accessibilityLabel,
                hint: NSLocalizedString(
                    "Shows IO read and write speed history. Hover to see precise values.",
                    comment: "IO history chart accessibility hint"
                )
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with time range picker
                headerView
                
                if !hasData {
                    emptyStateView
                } else {
                    // Main chart
                    chartView
                    
                    // Legend
                    if showLegend {
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
                Text(NSLocalizedString("IO 历史", comment: "IO history chart title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.accentColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(NSLocalizedString("IO History Chart", comment: "IO history header accessibility"))
            
            Spacer()
            
            // Time range picker
            if showTimeRangePicker {
                timeRangePickerView
            }
        }
    }
    
    // MARK: - Time Range Picker
    
    private var timeRangePickerView: some View {
        Picker("", selection: $timeRange) {
            ForEach(ChartTimeRange.allCases) { range in
                Text(range.rawValue)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
        .accessibilityLabel(NSLocalizedString("Time range", comment: "Time range picker label"))
        .accessibilityHint(String(
            format: NSLocalizedString(
                "Currently showing %@. Select to change time range.",
                comment: "Time range picker hint"
            ),
            timeRange.displayName
        ))
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        ZStack(alignment: .topLeading) {
            Chart {
                ForEach(filteredData) { point in
                    // Read speed line
                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("读取速度", point.readSpeed),
                        series: .value("类型", "读取")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(.circle)
                    .symbolSize(hoveredDate != nil ? 30 : 20)
                    
                    // Write speed line
                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("写入速度", point.writeSpeed),
                        series: .value("类型", "写入")
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(.square)
                    .symbolSize(hoveredDate != nil ? 30 : 20)
                }
                
                // Hover rule line
                if let hoveredDate = hoveredDate {
                    RuleMark(x: .value("时间", hoveredDate))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartXScale(domain: timeRange.dateRange)
            .chartYScale(domain: 0...maxSpeed)
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
                        if let speed = value.as(Int64.self) {
                            Text(formatSpeed(speed))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                "读取": Color.blue,
                "写入": Color.orange
            ])
            .chartLegend(showLegend ? .visible : .hidden)
            .chartLegend(position: .top, alignment: .trailing)
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
                "Hover over the chart to see precise values at specific times",
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
                
                // Find the closest data point in filtered data
                let closestPoint = filteredData.min(by: { point1, point2 in
                    abs(point1.timestamp.timeIntervalSince(date)) < abs(point2.timestamp.timeIntervalSince(date))
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
    private func hoverTooltip(for point: IODataPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timestamp
            Text(formatTooltipTime(point.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Read speed
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text(NSLocalizedString("读取:", comment: "Read label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(point.formattedReadSpeed)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            // Write speed
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                Text(NSLocalizedString("写入:", comment: "Write label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(point.formattedWriteSpeed)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
        }
        .frame(minWidth: 140)
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
        HStack(spacing: 20) {
            // Read speed legend
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                
                Text(NSLocalizedString("读取速度", comment: "Read speed legend"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(NSLocalizedString("Blue line: Read speed", comment: "Read speed legend accessibility"))
            
            // Write speed legend
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                
                Text(NSLocalizedString("写入速度", comment: "Write speed legend"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(NSLocalizedString("Orange line: Write speed", comment: "Write speed legend accessibility"))
            
            Spacer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString(
            "Chart legend showing read and write speed colors",
            comment: "Legend accessibility label"
        ))
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("暂无 IO 数据", comment: "No IO data title"))
                .font(.headline)
            
            Text(NSLocalizedString(
                "IO 历史数据将在收集后显示",
                comment: "No IO data message"
            ))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString(
            "No IO history data available. Data will appear after collection.",
            comment: "Empty state accessibility label"
        ))
    }
    
    // MARK: - Helper Methods
    
    /// 格式化X轴时间
    private func formatAxisTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch timeRange {
        case .minute:
            formatter.dateFormat = "HH:mm:ss"
        case .fiveMinutes:
            formatter.dateFormat = "HH:mm"
        case .hour:
            formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }
    
    /// 格式化提示框时间
    private func formatTooltipTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// 格式化速度值
    private func formatSpeed(_ speed: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: speed, countStyle: .file) + "/s"
    }
    
    /// 提示框的无障碍标签
    private func tooltipAccessibilityLabel(for point: IODataPoint) -> String {
        String(
            format: NSLocalizedString(
                "At %@: Read speed %@, Write speed %@",
                comment: "Tooltip accessibility label"
            ),
            formatTooltipTime(point.timestamp),
            point.formattedReadSpeed,
            point.formattedWriteSpeed
        )
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        if filteredData.isEmpty {
            return NSLocalizedString("IO history chart: No data available", comment: "Empty chart accessibility")
        }
        
        let dataPointCount = filteredData.count
        return String(
            format: NSLocalizedString(
                "IO history chart showing %d data points over %@",
                comment: "Chart accessibility label"
            ),
            dataPointCount,
            timeRange.displayName
        )
    }
    
    private var chartAccessibilityLabel: String {
        if filteredData.isEmpty {
            return NSLocalizedString("Empty IO history chart", comment: "Empty chart accessibility")
        }
        
        // Calculate summary statistics
        let avgRead = filteredData.isEmpty ? 0 : filteredData.reduce(Int64(0)) { $0 + $1.readSpeed } / Int64(filteredData.count)
        let avgWrite = filteredData.isEmpty ? 0 : filteredData.reduce(Int64(0)) { $0 + $1.writeSpeed } / Int64(filteredData.count)
        let maxRead = filteredData.map { $0.readSpeed }.max() ?? 0
        let maxWrite = filteredData.map { $0.writeSpeed }.max() ?? 0
        
        return String(
            format: NSLocalizedString(
                "IO history chart. Average read: %@, Average write: %@. Peak read: %@, Peak write: %@",
                comment: "Chart data accessibility label"
            ),
            formatSpeed(avgRead),
            formatSpeed(avgWrite),
            formatSpeed(maxRead),
            formatSpeed(maxWrite)
        )
    }
}

// MARK: - IOHistoryChart + Convenience Initializers

@available(macOS 13.0, *)
extension IOHistoryChart {
    /// 创建紧凑型 IO 历史图
    /// Creates a compact IO history chart without legend and time range picker
    static func compact(data: [IODataPoint], timeRange: ChartTimeRange = .fiveMinutes) -> IOHistoryChart {
        var chart = IOHistoryChart(data: data, timeRange: timeRange)
        chart.showLegend = false
        chart.showTimeRangePicker = false
        chart.chartHeight = 150
        return chart
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 13.0, *)
struct IOHistoryChart_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With sample data - 1 hour range
            IOHistoryChartPreviewWrapper(timeRange: .hour)
                .frame(width: 500, height: 350)
                .previewDisplayName("1 Hour Range")
            
            // With sample data - 5 minutes range
            IOHistoryChartPreviewWrapper(timeRange: .fiveMinutes)
                .frame(width: 500, height: 350)
                .previewDisplayName("5 Minutes Range")
            
            // With sample data - 1 minute range
            IOHistoryChartPreviewWrapper(timeRange: .minute)
                .frame(width: 500, height: 350)
                .previewDisplayName("1 Minute Range")
            
            // Empty state
            IOHistoryChart(data: [], timeRange: .hour)
                .frame(width: 500, height: 350)
                .previewDisplayName("Empty State")
            
            // Compact version
            IOHistoryChart.compact(data: sampleData)
                .frame(width: 400, height: 250)
                .previewDisplayName("Compact")
            
            // Dark mode
            IOHistoryChartPreviewWrapper(timeRange: .hour)
                .frame(width: 500, height: 350)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    static var sampleData: [IODataPoint] {
        let now = Date()
        let volumeId = UUID()
        
        var points: [IODataPoint] = []
        
        // Generate sample data for the past hour
        for secondsAgo in stride(from: 3600, through: 0, by: -30) {
            let timestamp = now.addingTimeInterval(-TimeInterval(secondsAgo))
            
            // Simulate varying read/write speeds with some randomness
            let baseRead = Int64(50_000_000) // 50 MB/s base
            let baseWrite = Int64(30_000_000) // 30 MB/s base
            
            let readVariation = Int64.random(in: -20_000_000...40_000_000)
            let writeVariation = Int64.random(in: -15_000_000...25_000_000)
            
            let readSpeed = max(0, baseRead + readVariation)
            let writeSpeed = max(0, baseWrite + writeVariation)
            
            points.append(IODataPoint(
                volumeId: volumeId,
                timestamp: timestamp,
                readSpeed: readSpeed,
                writeSpeed: writeSpeed
            ))
        }
        
        return points.sorted { $0.timestamp < $1.timestamp }
    }
}

/// Preview wrapper to handle @State binding
@available(macOS 13.0, *)
private struct IOHistoryChartPreviewWrapper: View {
    @State var timeRange: ChartTimeRange
    
    var body: some View {
        IOHistoryChart(
            data: IOHistoryChart_Previews.sampleData,
            timeRange: $timeRange
        )
    }
}
#endif
