import SwiftUI
import Charts

struct MetricCard: View {
    let metric: MetricScore
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    var body: some View {
        VStack(spacing: MendSpacing.medium) {
            // Header section
            HStack {
                VStack(alignment: .leading, spacing: MendSpacing.small) {
                    Text(metric.title)
                        .font(MendFont.headline)
                        .foregroundColor(textColor)
                    
                    // Color the delta text directly instead of using arrows
                    Text("\(metric.deltaFromAverage > 0 ? "+" : metric.deltaFromAverage < 0 ? "-" : "")\(String(format: "%.1f", abs(metric.deltaFromAverage))) from avg")
                        .font(MendFont.caption)
                        .foregroundColor(metric.isPositiveDelta ? MendColors.positive : MendColors.negative)
                }
                
                Spacer()
                
                ScoreRing(score: metric.score, size: 60, lineWidth: 8)
            }
            
            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: MendSpacing.medium) {
                    // Chart
                    MetricChart(data: metric.dailyData, title: metric.title, colorScheme: colorScheme)
                        .frame(height: 150)
                        .padding(.top, MendSpacing.small)
                    
                    // Description
                    Text(metric.description)
                        .font(MendFont.body)
                        .foregroundColor(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Expand/collapse button
            Button {
                withAnimation(.mendEaseInOut) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(isExpanded ? "Hide details" : "Show details")
                        .font(MendFont.subheadline)
                        .foregroundColor(MendColors.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(MendColors.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, MendSpacing.small)
                .background(MendColors.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .cornerRadius(MendCornerRadius.small)
            }
        }
        .padding(MendSpacing.medium)
        .background(backgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct MetricChart: View {
    let data: [RecoveryMetricData]
    let title: String
    var colorScheme: ColorScheme
    
    init(data: [RecoveryMetricData], title: String = "", colorScheme: ColorScheme = .light) {
        self.data = data
        self.title = title
        self.colorScheme = colorScheme
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    var body: some View {
        if data.isEmpty {
            Text("No data available")
                .font(MendFont.caption)
                .foregroundColor(secondaryTextColor)
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(MendColors.secondary.opacity(colorScheme == .dark ? 0.15 : 0.1))
                .cornerRadius(MendCornerRadius.small)
        } else {
            Chart {
                ForEach(data) { item in
                    LineMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(MendColors.primary)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(MendColors.primary)
                }
            }
            .chartForegroundStyleScale([
                "Value": MendColors.primary
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.narrow))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                    AxisTick()
                        .foregroundStyle(secondaryTextColor)
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatYAxisValue(doubleValue))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
            }
            .chartYScale(domain: getYAxisRange())
            .overlay(alignment: .topLeading) {
                Text(getYAxisTitle())
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
                    .padding(8)
            }
        }
    }
    
    private func getYAxisRange() -> ClosedRange<Double> {
        guard !data.isEmpty else { return 0...1 }
        
        // Check for specific metrics to set appropriate ranges
        if title.contains("Heart Rate") {
            // Heart rate typically ranges from 40-100
            return 40...100
        } else if title.contains("HRV") || title.contains("Variability") {
            // HRV ranges depend on the individual but often between 20-100 ms
            return 20...100
        } else if title.contains("Sleep Duration") || title.lowercased().contains("sleep hours") {
            // Sleep hours typically 0-10
            return 0...10
        } else if title.contains("Sleep Quality") {
            // Sleep quality score 0-100
            return 0...100
        } else if title.contains("Training") {
            // Training load
            return 0...100
        } else {
            // Default case for unknown metrics - get from data
            let values = data.map { $0.value }
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let padding = (maxValue - minValue) * 0.1
            let lowerBound = max(0, minValue - padding)
            let upperBound = maxValue + padding
            return lowerBound...upperBound
        }
    }
    
    private func getYAxisTitle() -> String {
        if title.contains("Heart Rate") {
            return "BPM"
        } else if title.contains("HRV") || title.contains("Variability") {
            return "ms"
        } else if title.contains("Sleep Duration") || title.lowercased().contains("sleep hours") {
            return "Hours"
        } else if title.contains("Sleep Quality") {
            return "Score (0-100)"
        } else if title.contains("Training") {
            return "Load"
        } else {
            return "Value"
        }
    }
    
    private func formatYAxisValue(_ value: Double) -> String {
        if title.contains("Sleep Duration") || title.lowercased().contains("sleep hours") {
            return String(format: "%.1f", value)
        } else if title.contains("Heart Rate") || title.contains("HRV") {
            return String(format: "%.0f", value)
        } else if title.contains("Sleep Quality") {
            return String(format: "%.0f", value) 
        } else {
            return String(format: "%.0f", value)
        }
    }
}

#Preview {
    VStack {
        MetricCard(metric: MetricScore.sampleHeartRate)
        MetricCard(metric: MetricScore.sampleHRV)
    }
    .padding()
} 