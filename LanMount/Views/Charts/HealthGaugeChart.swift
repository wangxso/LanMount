//
//  HealthGaugeChart.swift
//  LanMount
//
//  Health gauge dashboard component for visualizing health score, latency, and success rate
//  Requirements: 6.3
//

import SwiftUI

// Note: HealthMetrics is now defined in ChartModels.swift

// MARK: - GaugeView

/// 仪表盘视图
/// A circular gauge view that displays a value with a progress ring
///
/// This component provides:
/// - Circular progress ring with customizable color
/// - Value display in the center
/// - Optional unit label
/// - Title label below the gauge
/// - Full VoiceOver accessibility support
///
/// Requirements: 6.3 - Display health gauge dashboard
struct GaugeView: View {
    /// The current value to display
    let value: Double
    
    /// The maximum value for the gauge
    let maxValue: Double
    
    /// The title displayed below the gauge
    let title: String
    
    /// Optional unit label (e.g., "ms", "%")
    var unit: String = ""
    
    /// The color of the progress ring
    let color: Color
    
    /// The size of the gauge (width and height)
    var size: CGFloat = 80
    
    /// The line width of the progress ring
    var lineWidth: CGFloat = 10
    
    // MARK: - Computed Properties
    
    /// The progress value (0-1) for the ring
    private var progress: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(min(max(value / maxValue, 0), 1))
    }
    
    /// Formatted value string
    private var formattedValue: String {
        String(format: "%.0f", value)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // 背景圆环 - Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                
                // 进度圆环 - Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // 数值 - Value display
                VStack(spacing: 2) {
                    Text(formattedValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .accessibilityHidden(true)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(width: size, height: size)
            
            // 标题 - Title
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        title
    }
    
    private var accessibilityValue: String {
        if unit.isEmpty {
            return String(format: "%.0f of %.0f", value, maxValue)
        } else {
            return String(format: "%.0f %@", value, unit)
        }
    }
}

// MARK: - HealthGaugeChart

/// 健康度仪表盘
/// A dashboard view that displays health score, latency, and success rate gauges
///
/// This component visualizes connection health with support for:
/// - Overall health score gauge (0-100)
/// - Latency gauge (0-500ms)
/// - Success rate gauge (0-100%)
/// - Color-coded indicators based on values
/// - Full VoiceOver accessibility support
///
/// Requirements:
/// - 6.3: Display connection health gauge dashboard (latency, success rate indicators)
///
/// Example usage:
/// ```swift
/// HealthGaugeChart(healthScore: 85, latencyMs: 50, successRate: 99)
///
/// // With HealthMetrics
/// let metrics = HealthMetrics(volumeId: UUID(), latencyMs: 50, successRate: 99)
/// HealthGaugeChart(metrics: metrics)
/// ```
struct HealthGaugeChart: View {
    /// 整体健康度 (0-100)
    let healthScore: Double
    
    /// 延迟毫秒
    let latencyMs: Double
    
    /// 成功率百分比 (0-100)
    let successRate: Double
    
    /// 图表高度
    var chartHeight: CGFloat = 150
    
    /// 是否显示标题
    var showTitle: Bool = true
    
    // MARK: - Computed Properties
    
    /// 健康度颜色
    /// Returns color based on health score value
    private var healthColor: Color {
        switch healthScore {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    /// 延迟颜色
    /// Returns color based on latency value
    private var latencyColor: Color {
        switch latencyMs {
        case 0..<100: return .green
        case 100..<200: return .yellow
        case 200..<300: return .orange
        default: return .red
        }
    }
    
    /// 成功率颜色
    /// Returns color based on success rate value
    private var successRateColor: Color {
        switch successRate {
        case 95...100: return .green
        case 80..<95: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a HealthGaugeChart with individual values
    /// - Parameters:
    ///   - healthScore: Overall health score (0-100)
    ///   - latencyMs: Latency in milliseconds
    ///   - successRate: Success rate percentage (0-100)
    init(healthScore: Double, latencyMs: Double, successRate: Double) {
        self.healthScore = min(100, max(0, healthScore))
        self.latencyMs = max(0, latencyMs)
        self.successRate = min(100, max(0, successRate))
    }
    
    /// Creates a HealthGaugeChart from HealthMetrics
    /// - Parameter metrics: The health metrics to display
    init(metrics: HealthMetrics) {
        self.healthScore = metrics.healthScore
        self.latencyMs = metrics.latencyMs
        self.successRate = metrics.successRate
    }
    
    // MARK: - Body
    
    var body: some View {
        GlassCard(
            accessibility: .summary(
                label: accessibilityLabel,
                hint: NSLocalizedString(
                    "Shows connection health metrics including overall health, latency, and success rate.",
                    comment: "Health gauge chart accessibility hint"
                )
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                if showTitle {
                    headerView
                }
                
                // Gauges
                gaugesView
                
                // Status summary
                statusSummaryView
            }
            .padding()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Label {
                Text(NSLocalizedString("健康状态", comment: "Health status chart title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "heart.circle")
                    .foregroundColor(healthColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(NSLocalizedString("Health Status Dashboard", comment: "Health status header accessibility"))
            
            Spacer()
            
            // Overall status indicator
            statusBadge
        }
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(healthColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString(
                "Overall status: %@",
                comment: "Status badge accessibility"
            ),
            statusText
        ))
    }
    
    /// Status text based on health score
    private var statusText: String {
        switch healthScore {
        case 80...100:
            return NSLocalizedString("优秀", comment: "Excellent status")
        case 60..<80:
            return NSLocalizedString("良好", comment: "Good status")
        case 40..<60:
            return NSLocalizedString("一般", comment: "Fair status")
        default:
            return NSLocalizedString("较差", comment: "Poor status")
        }
    }
    
    // MARK: - Gauges View
    
    private var gaugesView: some View {
        HStack(spacing: 20) {
            Spacer()
            
            // 整体健康度 - Overall health
            GaugeView(
                value: healthScore,
                maxValue: 100,
                title: NSLocalizedString("健康度", comment: "Health score gauge title"),
                color: healthColor
            )
            
            // 延迟 - Latency
            GaugeView(
                value: min(latencyMs, 500),
                maxValue: 500,
                title: NSLocalizedString("延迟", comment: "Latency gauge title"),
                unit: "ms",
                color: latencyColor
            )
            
            // 成功率 - Success rate
            GaugeView(
                value: successRate,
                maxValue: 100,
                title: NSLocalizedString("成功率", comment: "Success rate gauge title"),
                unit: "%",
                color: successRateColor
            )
            
            Spacer()
        }
        .frame(height: chartHeight)
    }
    
    // MARK: - Status Summary View
    
    private var statusSummaryView: some View {
        HStack(spacing: 16) {
            // Health score detail
            statusItem(
                icon: "heart.fill",
                label: NSLocalizedString("健康度", comment: "Health label"),
                value: String(format: "%.0f", healthScore),
                unit: "/100",
                color: healthColor
            )
            
            Divider()
                .frame(height: 20)
            
            // Latency detail
            statusItem(
                icon: "clock.fill",
                label: NSLocalizedString("延迟", comment: "Latency label"),
                value: String(format: "%.0f", latencyMs),
                unit: "ms",
                color: latencyColor
            )
            
            Divider()
                .frame(height: 20)
            
            // Success rate detail
            statusItem(
                icon: "checkmark.circle.fill",
                label: NSLocalizedString("成功率", comment: "Success rate label"),
                value: String(format: "%.1f", successRate),
                unit: "%",
                color: successRateColor
            )
            
            Spacer()
        }
        .font(.caption)
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Status Item
    
    private func statusItem(
        icon: String,
        label: String,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .accessibilityHidden(true)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Text(value)
                .fontWeight(.medium)
            
            Text(unit)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        String(
            format: NSLocalizedString(
                "Health dashboard: Health score %.0f out of 100, Latency %.0f milliseconds, Success rate %.1f percent. Status: %@",
                comment: "Health gauge chart accessibility label"
            ),
            healthScore,
            latencyMs,
            successRate,
            statusText
        )
    }
}

// MARK: - HealthGaugeChart + Convenience Initializers

extension HealthGaugeChart {
    /// 创建紧凑型健康度仪表盘
    /// Creates a compact health gauge chart without title
    static func compact(healthScore: Double, latencyMs: Double, successRate: Double) -> HealthGaugeChart {
        var chart = HealthGaugeChart(
            healthScore: healthScore,
            latencyMs: latencyMs,
            successRate: successRate
        )
        chart.showTitle = false
        chart.chartHeight = 120
        return chart
    }
    
    /// 创建紧凑型健康度仪表盘（从 HealthMetrics）
    /// Creates a compact health gauge chart from HealthMetrics
    static func compact(metrics: HealthMetrics) -> HealthGaugeChart {
        compact(
            healthScore: metrics.healthScore,
            latencyMs: metrics.latencyMs,
            successRate: metrics.successRate
        )
    }
}

// MARK: - Preview

#if DEBUG
struct HealthGaugeChart_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Excellent health
            HealthGaugeChart(
                healthScore: 95,
                latencyMs: 45,
                successRate: 99.5
            )
            .frame(width: 400, height: 280)
            .previewDisplayName("Excellent Health")
            
            // Good health
            HealthGaugeChart(
                healthScore: 75,
                latencyMs: 150,
                successRate: 92
            )
            .frame(width: 400, height: 280)
            .previewDisplayName("Good Health")
            
            // Fair health
            HealthGaugeChart(
                healthScore: 55,
                latencyMs: 250,
                successRate: 75
            )
            .frame(width: 400, height: 280)
            .previewDisplayName("Fair Health")
            
            // Poor health
            HealthGaugeChart(
                healthScore: 25,
                latencyMs: 450,
                successRate: 45
            )
            .frame(width: 400, height: 280)
            .previewDisplayName("Poor Health")
            
            // Compact version
            HealthGaugeChart.compact(
                healthScore: 85,
                latencyMs: 80,
                successRate: 97
            )
            .frame(width: 350, height: 200)
            .previewDisplayName("Compact")
            
            // With HealthMetrics
            HealthGaugeChart(
                metrics: HealthMetrics(
                    volumeId: UUID(),
                    latencyMs: 120,
                    successRate: 95
                )
            )
            .frame(width: 400, height: 280)
            .previewDisplayName("From HealthMetrics")
            
            // Dark mode
            HealthGaugeChart(
                healthScore: 88,
                latencyMs: 65,
                successRate: 98
            )
            .frame(width: 400, height: 280)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif
