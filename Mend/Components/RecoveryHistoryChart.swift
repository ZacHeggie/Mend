import SwiftUI
import Charts

struct RecoveryHistoryChart: View {
    let history: [RecoveryScore]
    let colorScheme: ColorScheme
    
    @State private var selectedScore: RecoveryScore?
    // Add scroll position state to control initial position
    @State private var scrollPosition: Date?
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground
    }
    
    private var recentHistory: [RecoveryScore] {
        // Get last 28 days data (4 weeks)
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -27, to: endDate) else {
            return history
        }
        
        return history.filter { score in
            score.date >= startDate && score.date <= endDate
        }.sorted { $0.date < $1.date }
    }
    
    private var sortedHistory: [RecoveryScore] {
        recentHistory.sorted { $0.date < $1.date }
    }
    
    private var mostRecentDate: Date? {
        sortedHistory.last?.date
    }
    
    // Calculate the appropriate chart width based on data points
    private var chartWidth: CGFloat {
        // Set the minimum width per day point
        let minWidthPerDay: CGFloat = 100
        // Set the visible width for the display
        let visibleWidth: CGFloat = UIScreen.main.bounds.width - 40 // Subtract padding
        
        // Calculate the desired width based on the number of days with data
        let dataPointCount = CGFloat(sortedHistory.count)
        // Ensure we have at least 1 day of data width
        let dataPoints = max(1, dataPointCount)
        
        // Calculate width based on minimum width per day and data points
        var calculatedWidth = dataPoints * minWidthPerDay
        
        // If we have very few data points, make sure the chart isn't too narrow
        if dataPoints <= 7 {
            // For 7 or fewer days, we want the chart to fill the visible area
            calculatedWidth = max(calculatedWidth, visibleWidth)
        } else {
            // For more than 7 days, ensure we maintain the minimum width per day
            // which means the chart will scroll horizontally
            calculatedWidth = dataPoints * minWidthPerDay
        }
        
        // Cap the chart at 28 days maximum (from our filteredHistory)
        let maxWidth = 28 * minWidthPerDay
        return min(calculatedWidth, maxWidth)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            Text("Recovery Trend (4 Weeks)")
                .font(MendFont.headline)
                .foregroundColor(textColor)
                .padding(.horizontal, MendSpacing.small)
            
            if sortedHistory.isEmpty {
                Text("No historical data available yet.")
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: MendSpacing.small) {
                    // Score details
                    if let score = selectedScore {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(formatDate(score.date))
                                    .font(MendFont.footnote)
                                    .foregroundColor(secondaryTextColor)
                                
                                HStack(spacing: MendSpacing.small) {
                                    Text(score.timeOfDay.displayName)
                                        .font(MendFont.footnote)
                                        .foregroundColor(secondaryTextColor)
                                    
                                    Text("Score: \(score.overallScore)")
                                        .font(MendFont.headline)
                                        .foregroundColor(textColor)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, MendSpacing.small)
                    } else {
                        Text("Tap the chart to see details")
                            .font(MendFont.footnote)
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, MendSpacing.small)
                    }
                    
                    // Chart view with scroll position set to the most recent date
                    ScrollView(.horizontal, showsIndicators: true) {
                        ScrollViewReader { scrollReader in
                            ZStack(alignment: .trailing) {
                                ChartView(
                                    history: sortedHistory,
                                    selectedScore: $selectedScore,
                                    colorScheme: colorScheme
                                )
                                .frame(width: chartWidth, height: 200)
                                .id("chartView")
                                
                                // Place anchor at the very end to ensure we scroll to the rightmost point
                                Color.clear.frame(width: 1, height: 1).id("chartEnd")
                            }
                            .onAppear {
                                // Set scroll position to the end (most recent date) when first appearing
                                DispatchQueue.main.async {
                                    // Use a slight delay to ensure the view is fully laid out
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation {
                                            // Scroll to the right end
                                            scrollReader.scrollTo("chartEnd", anchor: .trailing)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .defaultScrollAnchor(.trailing)
                    .frame(height: 200)
                    
                    // Instructions - Only show if we have enough data that requires scrolling
                    if sortedHistory.count > 7 {
                        Text("Scroll horizontally to see more history")
                            .font(MendFont.caption)
                            .foregroundColor(secondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(height: 280)
                .padding(MendSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                )
            }
        }
    }
    
    // Helper methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Chart component with added weekly grid lines and padding for axis labels
struct ChartView: View {
    let history: [RecoveryScore]
    @Binding var selectedScore: RecoveryScore?
    let colorScheme: ColorScheme
    
    // Calculate week boundaries for grid lines
    private var weekBoundaries: [Date] {
        let calendar = Calendar.current
        guard let firstDate = history.first?.date,
              let lastDate = history.last?.date else {
            return []
        }
        
        // Get start of first week
        guard let startOfFirstWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstDate)) else {
            return []
        }
        
        var boundaries: [Date] = []
        var currentDate = startOfFirstWeek
        
        // Add week boundaries until we reach past the last date
        while currentDate <= lastDate {
            boundaries.append(currentDate)
            if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) {
                currentDate = nextWeek
            } else {
                break
            }
        }
        
        return boundaries
    }
    
    var body: some View {
        Chart {
            // Add weekly grid lines
            ForEach(weekBoundaries, id: \.timeIntervalSince1970) { date in
                RuleMark(x: .value("Week", date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: []))
                    .foregroundStyle(Color.gray.opacity(0.5))
            }
            
            // Line connecting the points
            ForEach(history) { score in
                LineMark(
                    x: .value("Date", score.date),
                    y: .value("Score", score.overallScore)
                )
                .foregroundStyle(scoreColor(score.overallScore))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            
            // Data points
            ForEach(history) { score in
                PointMark(
                    x: .value("Date", score.date),
                    y: .value("Score", score.overallScore)
                )
                .foregroundStyle(scoreColor(score.overallScore))
                .symbolSize(score.id == selectedScore?.id ? 60 : 35)
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 1)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(formatShortDate(date))
                    }
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisValueLabel {
                    Text("\(value.index * 25)")
                }
                AxisGridLine()
            }
        }
        // Add padding to prevent axis labels from being cut off
        .padding(.top, 10)
        .padding(.bottom, 5)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, in: geometry, proxy: proxy)
                    }
            }
        }
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return MendColors.positive
        } else if score >= 60 {
            return MendColors.positive.opacity(0.7)
        } else if score >= 40 {
            return MendColors.neutral
        } else {
            return MendColors.negative
        }
    }
    
    private func handleTap(at location: CGPoint, in geometry: GeometryProxy, proxy: ChartProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        
        let xPosition = location.x - geometry[plotFrame].origin.x
        
        if let date: Date = proxy.value(atX: xPosition) {
            var closestScore: RecoveryScore?
            var minDistance: TimeInterval = .infinity
            
            for score in history {
                let distance = abs(score.date.timeIntervalSince(date))
                if distance < minDistance {
                    minDistance = distance
                    closestScore = score
                }
            }
            
            // Only update if tap is close to a point (within 12 hours)
            if minDistance < 43200 { // 12 hours in seconds
                selectedScore = closestScore
            }
        }
    }
}

#Preview {
    RecoveryHistoryChart(
        history: [
            RecoveryScore(
                date: Date().addingTimeInterval(-86400 * 1), // 1 day ago
                overallScore: 85,
                heartRateScore: MetricScore.sampleHeartRate,
                hrvScore: 75,
                sleepScore: 80,
                trainingLoadScore: MetricScore.sampleTrainingLoad,
                stressScore: 85,
                timeOfDay: .morning
            ),
            RecoveryScore(
                date: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                overallScore: 65,
                heartRateScore: MetricScore.sampleHeartRate,
                hrvScore: 60,
                sleepScore: 70,
                trainingLoadScore: MetricScore.sampleTrainingLoad,
                stressScore: 70,
                timeOfDay: .morning
            ),
            RecoveryScore(
                date: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                overallScore: 75,
                heartRateScore: MetricScore.sampleHeartRate,
                hrvScore: 65,
                sleepScore: 75,
                trainingLoadScore: MetricScore.sampleTrainingLoad,
                stressScore: 80,
                timeOfDay: .morning
            ),
        ],
        colorScheme: .light
    )
} 

