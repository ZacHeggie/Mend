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
                    Text("\(getDeltaDisplayText())")
                        .font(MendFont.caption)
                        .foregroundColor(textColor)
                    
                    // Color the delta text directly instead of using arrows
                    Text(getDeltaMeaningText())
                        .font(MendFont.caption)
                        .foregroundColor(getTextColor())
                }
                
                Spacer()
                
                // Display large color-coded metric value with units instead of ring
                getColorCodedValueDisplay()
            }
            
            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: MendSpacing.medium) {
                    // Chart
                    MetricChart(data: metric.dailyData, title: metric.title, colorScheme: colorScheme)
                        .frame(height: 180)
                        .padding(.top, MendSpacing.small)
                        .padding(.bottom, MendSpacing.medium)
                    
                    // Description
                    Text(metric.description)
                        .font(MendFont.body)
                        .foregroundColor(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
            }
            
            // Expand/collapse button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
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
    
    @ViewBuilder
    private func getColorCodedValueDisplay() -> some View {
        // Get value with units and background color
        let (valueText, units) = getFormattedValueWithUnits()
        
        VStack(alignment: .center) {
            // Value with units
            Text(valueText)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(getMetricColor())
                .multilineTextAlignment(.center)
            
            // Units if available
            if !units.isEmpty {
                Text(units)
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor)
            }
        }
        .frame(minWidth: 70)
    }
    
    private func getFormattedValueWithUnits() -> (String, String) {
        if metric.title.contains("Heart Rate") && !metric.title.contains("Variability") {
            return ("\(metric.score)", "BPM")
        } else if metric.title.contains("HRV") || metric.title.contains("Variability") {
            return ("\(metric.score)", "ms")
        } else if metric.title.contains("Sleep Duration") {
            let hours = Double(metric.score) * 8.0 / 100.0
            return (String(format: "%.1f", hours), "hours")
        } else if metric.title.contains("Sleep Quality") {
            return ("\(metric.score)", "/100")
        } else if metric.title.contains("Training") {
            return ("\(metric.score)", "pts")
        } else {
            return ("\(metric.score)", "")
        }
    }
    
    private func getMetricColor() -> Color {
        // Determine if change is significant for color coding
        let absChange = abs(metric.deltaFromAverage)
        let avgValue = getCurrentValueFromScore() - metric.deltaFromAverage
        let percentChange = avgValue != 0 ? (absChange / avgValue) * 100 : 0
        
        // For significant changes (more than 3%), color code based on good/bad
        if percentChange >= 3 {
            // For heart rate, lower is better (negative delta is positive)
            if metric.title.contains("Heart Rate") && !metric.title.contains("Variability") {
                return metric.deltaFromAverage < 0 ? MendColors.positive : MendColors.negative
            }
            
            // For all other metrics, rely on isPositiveDelta flag
            return metric.isPositiveDelta ? MendColors.positive : MendColors.negative
        } else {
            // For small changes, use neutral color
            return textColor
        }
    }
    
    private func getDeltaDisplayText() -> String {
        let avgValue = getCurrentValueFromScore() - metric.deltaFromAverage
        
        if metric.title.contains("Heart Rate") && !metric.title.contains("Variability") {
            return "28-day avg: \(String(format: "%.0f", avgValue)) BPM"
        } else if metric.title.contains("HRV") || metric.title.contains("Variability") {
            return "28-day avg: \(String(format: "%.0f", avgValue)) ms"
        } else if metric.title.contains("Sleep Duration") {
            let hours = avgValue * 8.0 / 100.0
            return "28-day avg: \(String(format: "%.1f", hours)) hours"
        } else if metric.title.contains("Sleep Quality") {
            return "28-day avg: \(String(format: "%.0f", avgValue))/100"
        } else if metric.title.contains("Sleep Stages") {
            return "Deep+REM: \(String(format: "%.0f", metric.score/4))%"
        } else if metric.title.contains("Training") {
            // Display the 28-day average for training load
            return "28-day avg: \(String(format: "%.0f", avgValue))"
        } else {
            return "28-day avg: \(String(format: "%.1f", avgValue))"
        }
    }
    
    private func getDeltaMeaningText() -> String {
        let currentValue = getCurrentValueFromScore()
        let _ = currentValue - metric.deltaFromAverage
        
        // Different metrics have different interpretations of what a "positive" change means
        let displayValue: Double = abs(metric.deltaFromAverage)
        
        // Format the text without the +/- sign
        let changeText = abs(displayValue) < 0.1 ? "No change" : 
                         "\(String(format: "%.1f", displayValue)) from avg"
        
        // Simplify this to use a consistent format
        if metric.title.contains("Sleep Stages") {
            return getStageQualityText(score: metric.score)
        } else if abs(displayValue) < 0.1 {
            return "No change (stable)"
        } else if metric.isPositiveDelta {
            return changeText + " (better)"
        } else {
            return changeText + " (monitor)"
        }
    }
    
    private func getStageQualityText(score: Int) -> String {
        let deepRemPercentage = score / 4 // Convert back to percentage
        
        if deepRemPercentage >= 40 {
            return "Excellent (optimal)"
        } else if deepRemPercentage >= 30 {
            return "Very good (better)"
        } else if deepRemPercentage >= 20 {
            return "Adequate (neutral)"
        } else {
            return "Low (monitor)"
        }
    }
    
    private func getCurrentValueFromScore() -> Double {
        if metric.title.contains("Sleep Duration") {
            return Double(metric.score)
        } else {
            return Double(metric.score)
        }
    }
    
    private func getTextColor() -> Color {
        if metric.isPositiveDelta {
            return MendColors.positive
        } else {
            // Special case for sleep stages
            if metric.title.contains("Sleep Stages") {
                let score = metric.score
                if score >= 30 * 4 { // 30% deep+REM is very good
                    return MendColors.positive
                } else if score >= 20 * 4 { // 20% is adequate
                    return MendColors.neutral
                } else {
                    return MendColors.negative
                }
            }
            
            return MendColors.negative
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
    
    // Get the dates that mark the start of each week in the dataset
    private var weekStartDates: [Date] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let sortedDates = data.map(\.date).sorted()
        
        guard let firstDate = sortedDates.first, let lastDate = sortedDates.last else {
            return []
        }
        
        // Find the first day of the week containing the first date
        let firstWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstDate))!
        
        // Calculate how many weeks we need to cover
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: firstWeekStart, to: lastDate).weekOfYear ?? 0
        
        // Generate a date for the start of each week
        var weekStarts: [Date] = []
        for weekOffset in 0...weeksBetween {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: firstWeekStart) {
                weekStarts.append(weekStart)
            }
        }
        
        return weekStarts
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
                        // Only include valid sleep data points (for sleep, filter out low values)
                        if isValidDataPoint(item) {
                            LineMark(
                                x: .value("Day", item.date, unit: .day),
                                y: .value("Value", item.value)
                            )
                            .foregroundStyle(MendColors.primary)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            PointMark(
                                x: .value("Day", item.date, unit: .day),
                                y: .value("Value", item.value)
                            )
                            .foregroundStyle(MendColors.primary)
                            .symbolSize(selectedPoint?.id == item.id ? 100 : 40)
                        }
                    }
                    
                    // Add average line for reference
                    if let avgValue = calculateAverage() {
                        RuleMark(
                            y: .value("Average", avgValue)
                        )
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .trailing) {
                            Text("Avg")
                                .font(MendFont.caption2)
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(colorScheme == .dark ? Color.black.opacity(0.4) : Color.white.opacity(0.7))
                                )
                        }
                    }
                    
                    if let selected = selectedPoint, isValidDataPoint(selected) {
                        PointMark(
                            x: .value("Day", selected.date, unit: .day),
                            y: .value("Value", selected.value)
                        )
                        .foregroundStyle(MendColors.secondary)
                        .symbolSize(160)
                    }
                }
                .chartForegroundStyleScale([
                    "Value": MendColors.primary
                ])
                .chartXAxis {
                    // Use only week start marks to keep axis clean and readable
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        if let date = value.as(Date.self) {
                            // Clear, prominent week dividers
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1.5))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.2))
                            
                            // Improved date labels that are always visible
                            AxisValueLabel {
                                Text(date, format: .dateTime.day().month())
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(textColor)
                                    .fixedSize()
                                    .frame(width: 40, alignment: .center)
                                    .rotationEffect(.degrees(-10)) // Slight angle to prevent overlap
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
                if let selectedPoint = selectedPoint, isValidDataPoint(selectedPoint) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPoint.date, format: .dateTime.day().month())
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
    
    // Helper function to determine if a data point is valid and should be displayed
    private func isValidDataPoint(_ dataPoint: RecoveryMetricData) -> Bool {
        // For sleep data, filter out very low values that are likely incorrect
        if dataPoint.metricType == .sleep {
            // Minimum threshold of 2 hours for sleep to be considered valid
            // This helps filter out partial recordings or tracking errors
            return dataPoint.value >= 2.0
        }
        
        // For sleep quality, filter out zero values
        if dataPoint.metricType == .sleepQuality {
            return dataPoint.value > 0
        }
        
        // For heart rate and HRV, ensure values are within a reasonable range
        if dataPoint.metricType == .heartRate {
            return dataPoint.value >= 30 && dataPoint.value <= 120
        }
        
        if dataPoint.metricType == .hrv {
            return dataPoint.value > 0 && dataPoint.value <= 200
        }
        
        // For other metrics, accept non-zero values
        return dataPoint.value > 0
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
            // Only consider valid data points
            if isValidDataPoint(point) {
                let distance = abs(point.date.timeIntervalSince(date))
                if distance < minDistance {
                    minDistance = distance
                    closestPoint = point
                }
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
            // For Training Load, just show the raw value without /100
            return "\(String(format: "%.0f", value))"
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
            // Get dynamic range for training load based on actual data
            let values = data.map { $0.value }
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 100
            
            // Calculate appropriate range with padding
            let padding = (maxValue - minValue) * 0.15
            let lowerBound = max(0, minValue - padding)
            let upperBound = maxValue + padding
            
            // Ensure we show at least 0-100 range if values are small
            if maxValue < 100 {
                return 0...max(100, upperBound)
            } else {
                return lowerBound...upperBound
            }
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
        } else if title.contains("Training") {
            // For Training Load, just show the raw value without /100
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }
    
    private func calculateAverage() -> Double? {
        guard !data.isEmpty else { return nil }
        
        let values = data.map { $0.value }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }
}

#Preview {
    VStack {
        MetricCard(metric: MetricScore.sampleHeartRate)
        MetricCard(metric: MetricScore.sampleHRV)
    }
    .padding()
} 
