//
//  IOMonitorView.swift
//  LanMount
//
//  IO monitoring view component for real-time read/write speed visualization
//  Requirements: 3.1 - Display read/write speed as real-time line chart
//  Requirements: 3.3 - Display current speed, average speed, and peak speed
//  Requirements: 3.4 - Show precise values on hover
//

import SwiftUI
import Charts

// MARK: - IOChartDataType

/// Represents the type of IO data being displayed
enum IOChartDataType: String, CaseIterable, Identifiable {
    case read
    case write
    
    var id: String { rawValue }
    
    /// Localized display name
    var displayName: String {
        switch self {
        case .read:
            return NSLocalizedString("Read", comment: "Read speed label")
        case .write:
            return NSLocalizedString("Write", comment: "Write speed label")
        }
    }
    
    /// Color for the chart line
    var color: Color {
        switch self {
        case .read:
            return .blue
        case .write:
            return .orange
        }
    }
    
    /// System image name for the icon
    var iconName: String {
        switch self {
        case .read:
            return "arrow.down.circle.fill"
        case .write:
            return "arrow.up.circle.fill"
        }
    }
}

// MARK: - IOChartPoint

/// A data point for the IO chart
struct IOChartPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let speed: Int64
    let type: IOChartDataType
    let volumeId: UUID
    
    /// Formatted speed string
    var formattedSpeed: String {
        ByteCountFormatter.string(fromByteCount: speed, countStyle: .file) + "/s"
    }
}

// MARK: - HoveredIOData

/// Data structure for hover tooltip display
struct HoveredIOData: Equatable {
    let timestamp: Date
    let readSpeed: Int64
    let writeSpeed: Int64
    let volumeName: String
    
    /// Formatted read speed string
    var formattedReadSpeed: String {
        ByteCountFormatter.string(fromByteCount: readSpeed, countStyle: .file) + "/s"
    }
    
    /// Formatted write speed string
    var formattedWriteSpeed: String {
        ByteCountFormatter.string(fromByteCount: writeSpeed, countStyle: .file) + "/s"
    }
    
    /// Formatted timestamp string
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - IOMonitorView

// MARK: - IOMonitorFocusField

/// Enum representing focusable fields in the IO Monitor view
/// Requirements: 8.3 - Support keyboard navigation and focus management
enum IOMonitorFocusField: Hashable, CaseIterable {
    case monitoringToggle
    case volumeSelector
    case chart
    case statisticsSection
    
    /// The next field in tab order
    var next: IOMonitorFocusField {
        let allCases = IOMonitorFocusField.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return self }
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
    
    /// The previous field in tab order
    var previous: IOMonitorFocusField {
        let allCases = IOMonitorFocusField.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return self }
        let previousIndex = (currentIndex - 1 + allCases.count) % allCases.count
        return allCases[previousIndex]
    }
    
    /// Accessibility label for the focus field
    var accessibilityLabel: String {
        switch self {
        case .monitoringToggle:
            return NSLocalizedString("Monitoring toggle button", comment: "Focus field accessibility")
        case .volumeSelector:
            return NSLocalizedString("Volume selector", comment: "Focus field accessibility")
        case .chart:
            return NSLocalizedString("IO performance chart", comment: "Focus field accessibility")
        case .statisticsSection:
            return NSLocalizedString("Statistics section", comment: "Focus field accessibility")
        }
    }
}

/// A view that displays real-time IO performance data as a line chart
///
/// This component visualizes disk read/write speeds with support for:
/// - Real-time line chart showing read and write speeds over time
/// - Display of current, average, and peak speeds
/// - Hover interaction to show precise values at specific time points
/// - Support for multiple volumes with individual statistics
/// - Keyboard navigation and focus management (Requirements: 8.3)
///
/// Requirements:
/// - 3.1: Display read/write speed as real-time line chart for each connected disk
/// - 3.3: Display current speed, average speed, and peak speed
/// - 3.4: Show precise values when user hovers on the chart
/// - 8.3: Support keyboard navigation and focus management
///
/// Example usage:
/// ```swift
/// IOMonitorView(viewModel: ioMonitorViewModel)
///
/// // Without legend
/// IOMonitorView(viewModel: ioMonitorViewModel, showLegend: false)
///
/// // With custom history duration
/// IOMonitorView(viewModel: ioMonitorViewModel, historyDuration: 30)
/// ```
@available(macOS 13.0, *)
struct IOMonitorView: View {
    /// The view model providing IO monitoring data
    @ObservedObject var viewModel: IOMonitorViewModel
    
    /// Whether to show the chart legend
    var showLegend: Bool = true
    
    /// Duration of history to display in seconds
    var historyDuration: TimeInterval = 60
    
    // MARK: - Private State
    
    /// Currently hovered data point for tooltip display
    @State private var hoveredData: HoveredIOData? = nil
    
    /// Currently selected volume for detailed view
    @State private var selectedVolumeId: UUID? = nil
    
    /// Hover position for tooltip placement
    @State private var hoverPosition: CGPoint = .zero
    
    // MARK: - Focus State (Requirements: 8.3)
    
    /// Current focused field for keyboard navigation
    @FocusState private var focusedField: IOMonitorFocusField?
    
    // MARK: - Computed Properties
    
    /// Chart data points converted from history data
    private var chartDataPoints: [IOChartPoint] {
        let cutoffDate = Date().addingTimeInterval(-historyDuration)
        let filteredHistory = viewModel.historyData.filter { $0.timestamp >= cutoffDate }
        
        var points: [IOChartPoint] = []
        
        for dataPoint in filteredHistory {
            // Add read speed point
            points.append(IOChartPoint(
                timestamp: dataPoint.timestamp,
                speed: dataPoint.readSpeed,
                type: .read,
                volumeId: dataPoint.volumeId
            ))
            
            // Add write speed point
            points.append(IOChartPoint(
                timestamp: dataPoint.timestamp,
                speed: dataPoint.writeSpeed,
                type: .write,
                volumeId: dataPoint.volumeId
            ))
        }
        
        return points
    }
    
    /// Whether there is data to display
    private var hasData: Bool {
        !viewModel.currentStats.isEmpty || !viewModel.historyData.isEmpty
    }
    
    /// The volumes to display
    private var displayVolumes: [VolumeIOStats] {
        if let selectedId = selectedVolumeId {
            return viewModel.currentStats.filter { $0.id == selectedId }
        }
        return viewModel.currentStats
    }
    
    /// Time range for the chart X-axis
    private var timeRange: ClosedRange<Date> {
        let now = Date()
        let start = now.addingTimeInterval(-historyDuration)
        return start...now
    }
    
    // MARK: - Body
    
    var body: some View {
        GlassCard(
            accessibility: .summary(
                label: accessibilityLabel,
                hint: NSLocalizedString(
                    "Shows real-time IO performance visualization. Use Tab to navigate between elements, Space to toggle monitoring.",
                    comment: "IO monitor accessibility hint with keyboard navigation"
                )
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerView
                
                if !viewModel.isMonitoring && !hasData {
                    notMonitoringView
                } else if !hasData {
                    emptyStateView
                } else {
                    // Main chart
                    chartView
                    
                    // Legend
                    if showLegend {
                        legendView
                    }
                    
                    // Statistics cards
                    statisticsView
                }
            }
            .padding()
        }
        // MARK: - Keyboard Navigation (Requirements: 8.3)
        .modifier(KeyboardNavigationModifier(
            onTab: { handleTabNavigation(shiftPressed: false) },
            onSpace: { handleSpaceKey() },
            onEscape: { focusedField = nil }
        ))
        .focusable()
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Label {
                Text(NSLocalizedString("IO Monitor", comment: "IO monitor title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(NSLocalizedString("IO Monitor Chart", comment: "IO monitor header accessibility"))
            
            Spacer()
            
            // Monitoring toggle button (Requirements: 8.3 - Keyboard accessible)
            monitoringToggleButton
            
            // Volume selector if multiple volumes
            if viewModel.currentStats.count > 1 {
                volumeSelector
            }
        }
    }
    
    // MARK: - Monitoring Toggle Button (Requirements: 8.3)
    
    /// Keyboard-accessible monitoring toggle button
    private var monitoringToggleButton: some View {
        Button {
            toggleMonitoring()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                
                Text(viewModel.isMonitoring 
                    ? NSLocalizedString("Monitoring", comment: "Monitoring status")
                    : NSLocalizedString("Stopped", comment: "Stopped status"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: viewModel.isMonitoring ? "pause.fill" : "play.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(focusedField == .monitoringToggle ? 0.2 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(focusedField == .monitoringToggle ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .focused($focusedField, equals: .monitoringToggle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isMonitoring
            ? NSLocalizedString("IO monitoring is active. Press to stop.", comment: "Monitoring active accessibility")
            : NSLocalizedString("IO monitoring is stopped. Press to start.", comment: "Monitoring stopped accessibility"))
        .accessibilityHint(NSLocalizedString(
            "Use Space or Enter to toggle monitoring. Keyboard shortcut: Command+M",
            comment: "Monitoring toggle keyboard hint"
        ))
        .accessibilityAddTraits(.isButton)
        .keyboardShortcut("m", modifiers: .command)
    }
    
    // MARK: - Volume Selector (Requirements: 8.3 - Keyboard accessible)
    
    private var volumeSelector: some View {
        Menu {
            Button {
                selectedVolumeId = nil
            } label: {
                HStack {
                    Text(NSLocalizedString("All Volumes", comment: "All volumes option"))
                    if selectedVolumeId == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach(viewModel.currentStats) { stats in
                Button {
                    selectedVolumeId = stats.id
                } label: {
                    HStack {
                        Text(stats.volumeName)
                        if selectedVolumeId == stats.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "externaldrive")
                Text(selectedVolumeId == nil 
                    ? NSLocalizedString("All", comment: "All volumes short")
                    : viewModel.currentStats.first { $0.id == selectedVolumeId }?.volumeName ?? "")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(focusedField == .volumeSelector ? 0.2 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(focusedField == .volumeSelector ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .focused($focusedField, equals: .volumeSelector)
        .accessibilityLabel(NSLocalizedString("Select volume to display", comment: "Volume selector accessibility"))
        .accessibilityHint(NSLocalizedString(
            "Press Space or Enter to open volume selection menu. Use arrow keys to navigate options.",
            comment: "Volume selector keyboard hint"
        ))
    }
    
    // MARK: - Chart View (Requirements: 8.3 - Keyboard accessible)
    
    private var chartView: some View {
        ZStack(alignment: .topLeading) {
            Chart {
                ForEach(chartDataPoints) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Speed", point.speed)
                    )
                    .foregroundStyle(by: .value("Type", point.type.displayName))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Speed", point.speed)
                    )
                    .foregroundStyle(by: .value("Type", point.type.displayName))
                    .opacity(0.1)
                }
                
                // Hover rule line
                if let hovered = hoveredData {
                    RuleMark(x: .value("Time", hovered.timestamp))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartXScale(domain: timeRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .second, count: 15)) { value in
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
            .chartForegroundStyleScale([
                IOChartDataType.read.displayName: IOChartDataType.read.color,
                IOChartDataType.write.displayName: IOChartDataType.write.color
            ])
            .chartLegend(.hidden)
            .frame(height: 200)
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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focusedField == .chart ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .focused($focusedField, equals: .chart)
            .accessibilityLabel(chartAccessibilityLabel)
            .accessibilityHint(NSLocalizedString(
                "Hover over the chart to see precise values at specific time points. Use Tab to navigate to other elements.",
                comment: "Chart hover hint with keyboard navigation"
            ))
            
            // Hover tooltip
            if let hovered = hoveredData {
                hoverTooltip(for: hovered)
                    .offset(x: max(0, min(hoverPosition.x - 60, 200)), y: 10)
            }
        }
    }
    
    // MARK: - Hover Handling
    
    /// Handles hover events on the chart
    /// Requirements: 3.4 - Show precise values when user hovers on the chart
    private func handleHover(phase: HoverPhase, proxy: ChartProxy, geometry: GeometryProxy) {
        switch phase {
        case .active(let location):
            hoverPosition = location
            
            // Find the closest data point to the hover position
            if let timestamp: Date = proxy.value(atX: location.x) {
                // Find the closest history data point
                let closestPoint = viewModel.historyData.min(by: { point1, point2 in
                    abs(point1.timestamp.timeIntervalSince(timestamp)) < abs(point2.timestamp.timeIntervalSince(timestamp))
                })
                
                if let point = closestPoint {
                    let volumeName = viewModel.currentStats.first { $0.id == point.volumeId }?.volumeName ?? "Unknown"
                    hoveredData = HoveredIOData(
                        timestamp: point.timestamp,
                        readSpeed: point.readSpeed,
                        writeSpeed: point.writeSpeed,
                        volumeName: volumeName
                    )
                }
            }
            
        case .ended:
            hoveredData = nil
        }
    }
    
    // MARK: - Hover Tooltip
    
    /// Creates a tooltip view for the hovered data point
    /// Requirements: 3.4 - Show precise values when user hovers on the chart
    private func hoverTooltip(for data: HoveredIOData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Time
            Text(data.formattedTime)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Volume name
            Text(data.volumeName)
                .font(.caption)
                .fontWeight(.medium)
            
            Divider()
            
            // Read speed
            HStack(spacing: 4) {
                Image(systemName: IOChartDataType.read.iconName)
                    .foregroundColor(IOChartDataType.read.color)
                    .font(.caption2)
                Text(NSLocalizedString("Read:", comment: "Read label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(data.formattedReadSpeed)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(IOChartDataType.read.color)
            }
            
            // Write speed
            HStack(spacing: 4) {
                Image(systemName: IOChartDataType.write.iconName)
                    .foregroundColor(IOChartDataType.write.color)
                    .font(.caption2)
                Text(NSLocalizedString("Write:", comment: "Write label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(data.formattedWriteSpeed)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(IOChartDataType.write.color)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "At %@, %@: Read %@, Write %@",
                comment: "Hover tooltip accessibility"
            ),
            data.formattedTime,
            data.volumeName,
            data.formattedReadSpeed,
            data.formattedWriteSpeed
        ))
    }
    
    // MARK: - Legend View
    
    private var legendView: some View {
        HStack(spacing: 20) {
            ForEach(IOChartDataType.allCases) { type in
                HStack(spacing: 6) {
                    Circle()
                        .fill(type.color)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    
                    Image(systemName: type.iconName)
                        .foregroundColor(type.color)
                        .font(.caption)
                        .accessibilityHidden(true)
                    
                    Text(type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(
                    format: NSLocalizedString(
                        "%@ speed shown in %@",
                        comment: "Legend item accessibility"
                    ),
                    type.displayName,
                    type == .read ? NSLocalizedString("blue", comment: "Blue color") : NSLocalizedString("orange", comment: "Orange color")
                ))
            }
            
            Spacer()
            
            // History duration indicator
            Text(String(
                format: NSLocalizedString(
                    "Last %d seconds",
                    comment: "History duration label"
                ),
                Int(historyDuration)
            ))
            .font(.caption2)
            .foregroundColor(.secondary)
            .accessibilityLabel(String(
                format: NSLocalizedString(
                    "Showing data from the last %d seconds",
                    comment: "History duration accessibility"
                ),
                Int(historyDuration)
            ))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString(
            "Chart legend: Blue line shows read speed, orange line shows write speed",
            comment: "Legend accessibility label"
        ))
    }
    
    // MARK: - Statistics View (Requirements: 8.3 - Keyboard accessible)
    
    /// Displays current, average, and peak speeds
    /// Requirements: 3.3 - Display current speed, average speed, and peak speed
    /// Requirements: 8.3 - Support keyboard navigation and focus management
    private var statisticsView: some View {
        VStack(spacing: 12) {
            ForEach(displayVolumes) { stats in
                VStack(alignment: .leading, spacing: 8) {
                    // Volume name header
                    if displayVolumes.count > 1 || selectedVolumeId != nil {
                        Text(stats.volumeName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .accessibilityAddTraits(.isHeader)
                    }
                    
                    // Statistics grid
                    HStack(spacing: 16) {
                        // Current speeds
                        statisticCard(
                            title: NSLocalizedString("Current", comment: "Current speed label"),
                            readValue: stats.formattedReadSpeed,
                            writeValue: stats.formattedWriteSpeed,
                            readRaw: stats.readBytesPerSecond,
                            writeRaw: stats.writeBytesPerSecond
                        )
                        
                        // Average speeds
                        statisticCard(
                            title: NSLocalizedString("Average", comment: "Average speed label"),
                            readValue: stats.formattedAverageReadSpeed,
                            writeValue: stats.formattedAverageWriteSpeed,
                            readRaw: stats.averageReadSpeed,
                            writeRaw: stats.averageWriteSpeed
                        )
                        
                        // Peak speeds
                        statisticCard(
                            title: NSLocalizedString("Peak", comment: "Peak speed label"),
                            readValue: stats.formattedPeakReadSpeed,
                            writeValue: stats.formattedPeakWriteSpeed,
                            readRaw: stats.peakReadSpeed,
                            writeRaw: stats.peakWriteSpeed
                        )
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(stats.accessibilityDescription)
                
                if stats.id != displayVolumes.last?.id {
                    Divider()
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(focusedField == .statisticsSection ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .focused($focusedField, equals: .statisticsSection)
        .accessibilityHint(NSLocalizedString(
            "Statistics section showing current, average, and peak IO speeds. Use Tab to navigate to other elements.",
            comment: "Statistics section keyboard hint"
        ))
    }
    
    /// Creates a statistic card showing read and write values
    private func statisticCard(
        title: String,
        readValue: String,
        writeValue: String,
        readRaw: Int64,
        writeRaw: Int64
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)
            
            // Read speed
            HStack(spacing: 4) {
                Image(systemName: IOChartDataType.read.iconName)
                    .foregroundColor(IOChartDataType.read.color)
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text(readValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(readRaw > 0 ? IOChartDataType.read.color : .secondary)
            }
            
            // Write speed
            HStack(spacing: 4) {
                Image(systemName: IOChartDataType.write.iconName)
                    .foregroundColor(IOChartDataType.write.color)
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text(writeValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(writeRaw > 0 ? IOChartDataType.write.color : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "%@: Read %@, Write %@",
                comment: "Statistic card accessibility"
            ),
            title,
            readValue,
            writeValue
        ))
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("No IO Data", comment: "No IO data title"))
                .font(.headline)
            
            Text(NSLocalizedString(
                "IO statistics will appear here when data is available",
                comment: "No IO data message"
            ))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString(
            "No IO data available. IO statistics will appear when data is available.",
            comment: "Empty state accessibility label"
        ))
    }
    
    // MARK: - Not Monitoring View
    
    private var notMonitoringView: some View {
        VStack(spacing: 12) {
            Image(systemName: "pause.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("Monitoring Stopped", comment: "Monitoring stopped title"))
                .font(.headline)
            
            Text(NSLocalizedString(
                "Start monitoring to see IO performance data",
                comment: "Monitoring stopped message"
            ))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            
            Button {
                viewModel.startMonitoring()
            } label: {
                Label(
                    NSLocalizedString("Start Monitoring", comment: "Start monitoring button"),
                    systemImage: "play.fill"
                )
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString(
            "IO monitoring is stopped. Activate the Start Monitoring button to begin.",
            comment: "Not monitoring accessibility label"
        ))
    }
    
    // MARK: - Keyboard Navigation Methods (Requirements: 8.3)
    
    /// Handles Tab key navigation between focusable elements
    /// - Parameter shiftPressed: Whether Shift is held (for reverse navigation)
    private func handleTabNavigation(shiftPressed: Bool) {
        if let current = focusedField {
            focusedField = shiftPressed ? current.previous : current.next
        } else {
            // Start with first focusable element
            focusedField = shiftPressed ? IOMonitorFocusField.allCases.last : IOMonitorFocusField.allCases.first
        }
    }
    
    /// Handles Space key press for activating focused element
    private func handleSpaceKey() {
        guard let focused = focusedField else { return }
        
        switch focused {
        case .monitoringToggle:
            toggleMonitoring()
        case .volumeSelector:
            // Menu will handle its own activation
            break
        case .chart, .statisticsSection:
            // These are informational, no action needed
            break
        }
    }
    
    /// Toggles monitoring state
    private func toggleMonitoring() {
        if viewModel.isMonitoring {
            viewModel.stopMonitoring()
        } else {
            viewModel.startMonitoring()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Formats a date for the X-axis label
    private func formatAxisTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        return formatter.string(from: date)
    }
    
    /// Formats a byte count for the Y-axis label
    private func formatAxisSpeed(_ bytes: Int64) -> String {
        if bytes == 0 {
            return "0"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        if !viewModel.isMonitoring && !hasData {
            return NSLocalizedString("IO Monitor: Monitoring stopped", comment: "IO monitor stopped accessibility")
        }
        
        if !hasData {
            return NSLocalizedString("IO Monitor: No data available", comment: "IO monitor no data accessibility")
        }
        
        let volumeCount = viewModel.currentStats.count
        return String(
            format: NSLocalizedString(
                "IO Monitor showing %d volumes. Total read: %@, Total write: %@",
                comment: "IO monitor accessibility label"
            ),
            volumeCount,
            viewModel.formattedTotalReadSpeed,
            viewModel.formattedTotalWriteSpeed
        )
    }
    
    private var chartAccessibilityLabel: String {
        if chartDataPoints.isEmpty {
            return NSLocalizedString("IO chart: No data points available", comment: "Empty chart accessibility")
        }
        
        return String(
            format: NSLocalizedString(
                "Real-time IO line chart showing read and write speeds over the last %d seconds",
                comment: "Chart accessibility label"
            ),
            Int(historyDuration)
        )
    }
}

// MARK: - IOMonitorView + Convenience Initializers

@available(macOS 13.0, *)
extension IOMonitorView {
    /// Creates an IO monitor view for a specific volume
    /// - Parameters:
    ///   - viewModel: The IO monitor view model
    ///   - volumeId: The specific volume ID to display
    init(viewModel: IOMonitorViewModel, volumeId: UUID) {
        self.viewModel = viewModel
        self._selectedVolumeId = State(initialValue: volumeId)
    }
    
    /// Creates a compact IO monitor view without legend
    /// - Parameters:
    ///   - viewModel: The IO monitor view model
    ///   - historyDuration: Duration of history to display
    static func compact(viewModel: IOMonitorViewModel, historyDuration: TimeInterval = 30) -> IOMonitorView {
        var view = IOMonitorView(viewModel: viewModel)
        view.showLegend = false
        view.historyDuration = historyDuration
        return view
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 13.0, *)
struct IOMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default view
            IOMonitorView(viewModel: IOMonitorViewModel())
                .frame(width: 500, height: 450)
                .previewDisplayName("Default")
            
            // Without legend
            IOMonitorView(viewModel: IOMonitorViewModel(), showLegend: false)
                .frame(width: 500, height: 400)
                .previewDisplayName("Without Legend")
            
            // Compact view
            IOMonitorView.compact(viewModel: IOMonitorViewModel())
                .frame(width: 400, height: 350)
                .previewDisplayName("Compact")
            
            // Dark mode
            IOMonitorView(viewModel: IOMonitorViewModel())
                .frame(width: 500, height: 450)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif

// MARK: - KeyboardNavigationModifier

/// A view modifier that adds keyboard navigation support with availability checks
/// This modifier wraps onKeyPress calls which are only available in macOS 14.0+
private struct KeyboardNavigationModifier: ViewModifier {
    let onTab: () -> Void
    let onSpace: () -> Void
    let onEscape: () -> Void
    
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .onKeyPress(.tab) {
                    onTab()
                    return .handled
                }
                .onKeyPress(.space) {
                    onSpace()
                    return .handled
                }
                .onKeyPress(.escape) {
                    onEscape()
                    return .handled
                }
                .focusEffectDisabled()
        } else {
            // Fallback for macOS 13.0 - keyboard navigation not available
            content
        }
    }
}
