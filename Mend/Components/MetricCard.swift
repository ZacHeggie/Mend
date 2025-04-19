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
                    
                    // Summary text showing current value and delta
                    Text("\(getValueDisplayText()) | \(getDeltaDisplayText())")
                        .font(MendFont.caption)
                        .foregroundColor(textColor)
                    
                    // Color the delta text directly instead of using arrows
                    Text(getDeltaMeaningText())
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
    
    private func getValueDisplayText() -> String {
        if metric.title.contains("Heart Rate") && !metric.title.contains("Variability") {
            return "Current: \(metric.score) BPM"
        } else if metric.title.contains("HRV") || metric.title.contains("Variability") {
            return "Current: \(metric.score) ms"
        } else if metric.title.contains("Sleep Duration") {
            let hours = Double(metric.score) * 8.0 / 100.0
            return "Current: \(String(format: "%.1f", hours)) hours"
        } else if metric.title.contains("Sleep Quality") {
            return "Current: \(metric.score)/100"
        } else if metric.title.contains("Training") {
            return "Current: \(metric.score)/100"
        } else {
            return "Current: \(metric.score)"
        }
    }
    
    private func getDeltaDisplayText() -> String {
        let avgValue = getCurrentValueFromScore() - metric.deltaFromAverage
        
        if metric.title.contains("Heart Rate") && !metric.title.contains("Variability") {
            return "7-day avg: \(String(format: "%.0f", avgValue)) BPM"
        } else if metric.title.contains("HRV") || metric.title.contains("Variability") {
            return "7-day avg: \(String(format: "%.0f", avgValue)) ms"
        } else if metric.title.contains("Sleep Duration") {
            let hours = avgValue * 8.0 / 100.0
            return "7-day avg: \(String(format: "%.1f", hours)) hours"
        } else if metric.title.contains("Sleep Quality") {
            return "7-day avg: \(String(format: "%.0f", avgValue))/100"
        } else if metric.title.contains("Training") {
            return "7-day avg: \(String(format: "%.0f", avgValue))/100"
        } else {
            return "7-day avg: \(String(format: "%.1f", avgValue))"
        }
    }
    
    private func getDeltaMeaningText() -> String {
        let currentValue = getCurrentValueFromScore()
        let avgValue = currentValue - metric.deltaFromAverage
        
        // Different metrics have different interpretations of what a "positive" change means
        var displayValue: Double
        
        if metric.title.contains("Heart Rate") && !metric.title.contains("Variability") {
            // For Heart Rate, lower is better, so we want to show the decrease
            displayValue = currentValue - avgValue  // How much lower/higher than average
        } else if metric.title.contains("HRV") || metric.title.contains("Variability") {
            // For HRV, higher is better
            displayValue = currentValue - avgValue
        } else if metric.title.contains("Sleep") {
            // For Sleep metrics, higher is typically better
            displayValue = currentValue - avgValue
        } else {
            // Default case
            displayValue = metric.deltaFromAverage
        }
        
        // Format the text without the +/- sign
        let changeText = abs(displayValue) < 0.1 ? "No change" : 
                         "\(String(format: "%.1f", abs(displayValue))) from avg"
        
        if metric.title.contains("Heart Rate") && !metric.title.contains("Variability") {
            return changeText + (metric.isPositiveDelta ? " (better)" : " (monitor)")
        } else if metric.title.contains("HRV") || metric.title.contains("Variability") {
            return changeText + (metric.isPositiveDelta ? " (better)" : " (monitor)")
        } else if metric.title.contains("Sleep") {
            return changeText + (metric.isPositiveDelta ? " (better)" : " (monitor)")
        } else if metric.title.contains("Training") {
            return changeText + (metric.isPositiveDelta ? " (optimal)" : " (high)")
        } else {
            return changeText
        }
    }
    
    private func getCurrentValueFromScore() -> Double {
        if metric.title.contains("Sleep Duration") {
            return Double(metric.score)
        } else {
            return Double(metric.score)
        }
    }
}

struct MetricChart: View {
    let data: [RecoveryMetricData]
    let title: String
    var colorScheme: ColorScheme
    
    @State private var selectedPoint: RecoveryMetricData?
    @State private var highlightLocation: CGPoint = .zero
    
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
            ZStack(alignment: .topLeading) {
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
                        .symbolSize(selectedPoint?.id == item.id ? 100 : 30)
                    }
                    
                    if let selected = selectedPoint {
                        PointMark(
                            x: .value("Day", selected.date, unit: .day),
                            y: .value("Value", selected.value)
                        )
                        .foregroundStyle(MendColors.secondary)
                        .symbolSize(120)
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
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        highlightLocation = value.location
                                        updateSelectedPoint(at: value.location, in: geometry, proxy: proxy)
                                    }
                                    .onEnded { _ in
                                        // Keep the selected point visible when touch ends
                                    }
                            )
                            .onTapGesture { location in
                                highlightLocation = location
                                updateSelectedPoint(at: location, in: geometry, proxy: proxy)
                            }
                    }
                }
                
                Text(getYAxisTitle())
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
                    .padding(8)
                
                // Selected value overlay
                if let selectedPoint = selectedPoint {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPoint.date, format: .dateTime.month().day())
                            .font(MendFont.caption)
                            .foregroundColor(secondaryTextColor)
                        
                        Text(formatSelectedValue(selectedPoint.value))
                            .font(MendFont.subheadline.bold())
                            .foregroundColor(MendColors.primary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? 
                                Color.black.opacity(0.7) : 
                                Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
                    .position(
                        x: min(max(highlightLocation.x, 70), UIScreen.main.bounds.width - 70),
                        y: max(highlightLocation.y - 45, 50)
                    )
                    .opacity(1)
                    .animation(.easeOut(duration: 0.2), value: selectedPoint)
                }
            }
        }
    }
    
    private func updateSelectedPoint(at location: CGPoint, in geometry: GeometryProxy, proxy: ChartProxy) {
        guard !data.isEmpty else { return }
        
        // Find the closest date for the location
        let xPosition = location.x - geometry[proxy.plotFrame!].origin.x
        guard let date = proxy.value(atX: xPosition, as: Date.self) else { return }
        
        // Find the closest data point
        var minDistance: TimeInterval = .infinity
        var closestPoint: RecoveryMetricData?
        
        for point in data {
            let distance = abs(point.date.timeIntervalSince(date))
            if distance < minDistance {
                minDistance = distance
                closestPoint = point
            }
        }
        
        selectedPoint = closestPoint
    }
    
    private func formatSelectedValue(_ value: Double) -> String {
        if title.contains("Heart Rate") && !title.contains("Variability") {
            return "\(String(format: "%.0f", value)) BPM"
        } else if title.contains("HRV") || title.contains("Variability") {
            return "\(String(format: "%.0f", value)) ms"
        } else if title.contains("Sleep Duration") || title.lowercased().contains("sleep hours") {
            return "\(String(format: "%.1f", value)) hours"
        } else if title.contains("Sleep Quality") {
            return "\(String(format: "%.0f", value))/100"
        } else if title.contains("Training") {
            return "\(String(format: "%.0f", value))/100"
        } else {
            return String(format: "%.1f", value)
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
        if title.contains("Heart Rate") && !title.contains("Variability") {
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