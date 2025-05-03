import SwiftUI
import Charts

struct RecoveryHistoryChart: View {
    let history: [RecoveryScore]
    let colorScheme: ColorScheme
    
    @State private var selectedScore: RecoveryScore?
    @State private var highlightLocation: CGPoint = .zero
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    private var sortedHistory: [RecoveryScore] {
        // Sort by date (oldest to newest) for chart display
        history.sorted { $0.date < $1.date }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
    
    // Calculate weekly boundaries for gridlines
    private var weeklyBoundaries: [Date] {
        guard !sortedHistory.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let startDate = sortedHistory.first?.date ?? Date()
        let endDate = sortedHistory.last?.date ?? Date()
        
        // Find the first day of the week containing the start date
        let weekStartComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)
        guard let firstWeekStart = calendar.date(from: weekStartComponents) else { return [] }
        
        var boundaries: [Date] = []
        var currentWeekStart = firstWeekStart
        
        // Add each week start until we pass the end date
        while currentWeekStart <= endDate {
            boundaries.append(currentWeekStart)
            if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) {
                currentWeekStart = nextWeek
            } else {
                break
            }
        }
        
        return boundaries
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            Text("Recovery Trend (28 Days)")
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
                    if let selectedScore = selectedScore {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(dateFormatter.string(from: selectedScore.date))")
                                    .font(MendFont.footnote)
                                    .foregroundColor(secondaryTextColor)
                                
                                HStack(spacing: MendSpacing.small) {
                                    Text(selectedScore.timeOfDay.displayName)
                                        .font(MendFont.footnote)
                                        .foregroundColor(secondaryTextColor)
                                    
                                    Text("Score: \(selectedScore.overallScore)")
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
                    
                    GeometryReader { geometry in
                        Chart {
                            // Weekly gridlines
                            ForEach(weeklyBoundaries, id: \.self) { date in
                                RuleMark(x: .value("Week", date))
                                    .foregroundStyle(secondaryTextColor.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            }
                            
                            // Connect points with a line for trend visualization
                            // Group by date to create daily segments
                            let calendar = Calendar.current
                            let groupedByDay = Dictionary(grouping: sortedHistory) { score in
                                calendar.startOfDay(for: score.date)
                            }
                            
                            ForEach(groupedByDay.keys.sorted(), id: \.self) { day in
                                if let dayScores = groupedByDay[day]?.sorted(by: { $0.date < $1.date }),
                                   dayScores.count > 1 {
                                    ForEach(0..<dayScores.count-1, id: \.self) { i in
                                        LineMark(
                                            x: .value("Date", dayScores[i].date),
                                            y: .value("Score", dayScores[i].overallScore),
                                            series: .value("Day", day)
                                        )
                                        .foregroundStyle(.gray.opacity(0.7))
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: []))
                                    }
                                }
                            }
                            
                            // Data points
                            ForEach(sortedHistory) { score in
                                PointMark(
                                    x: .value("Date", score.date),
                                    y: .value("Score", score.overallScore)
                                )
                                .foregroundStyle(recoveryScoreColor(score: score.overallScore))
                                .symbolSize(score.id == selectedScore?.id ? 60 : 35) // Smaller data points
                            }
                        }
                        .chartXAxis {
                            AxisMarks(preset: .aligned, values: .stride(by: .day, count: 7)) { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(shortDateFormatter.string(from: date))
                                            .font(MendFont.caption)
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    AxisGridLine()
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                                AxisValueLabel {
                                    Text("\(value.index * 50)")
                                        .font(MendFont.caption)
                                        .foregroundColor(secondaryTextColor)
                                }
                                AxisGridLine()
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartOverlay { proxy in
                            GeometryReader { geometry in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                highlightLocation = value.location
                                                updateSelectedPoint(at: value.location, in: geometry, proxy: proxy)
                                            }
                                            .onEnded { _ in
                                                // Keep the selected point highlighted
                                            }
                                    )
                            }
                        }
                        .frame(height: 200)
                    }
                }
                .frame(height: 250)
                .padding(MendSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground)
                )
            }
        }
    }
    
    private func recoveryScoreColor(score: Int) -> Color {
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
    
    private func updateSelectedPoint(at location: CGPoint, in geometry: GeometryProxy, proxy: ChartProxy) {
        guard !sortedHistory.isEmpty else { return }
        
        // Handle optional plotFrame safely
        guard let plotFrame = proxy.plotFrame else { return }
        let xPosition = location.x - geometry[plotFrame].origin.x
        
        // Find the date at the x position
        if let date: Date = proxy.value(atX: xPosition) {
            // Find the closest score to this date
            var closestScore: RecoveryScore?
            var minDistance: TimeInterval = .infinity
            
            for score in sortedHistory {
                let distance = abs(score.date.timeIntervalSince(date))
                if distance < minDistance {
                    minDistance = distance
                    closestScore = score
                }
            }
            
            selectedScore = closestScore
        }
    }
}

#Preview {
    RecoveryHistoryChart.PreviewContainer()
}

extension RecoveryHistoryChart {
    struct PreviewContainer: View {
        static let sampleScores: [RecoveryScore] = {
            let calendar = Calendar.current
            let today = Date()
            var samples: [RecoveryScore] = []
            
            for dayOffset in 0..<28 {
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
                let score = Int.random(in: 30...90) // Random score for visualization
                
                // Add multiple entries per day to simulate morning/noon/evening
                let timesOfDay: [RecoveryScoreData.TimeOfDay] = [.morning, .noon, .evening]
                for timeOfDay in timesOfDay {
                    var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    switch timeOfDay {
                    case .morning: dateComponents.hour = 8
                    case .noon: dateComponents.hour = 13
                    case .evening: dateComponents.hour = 20
                    }
                    
                    let timePoint = calendar.date(from: dateComponents) ?? date
                    let timeVariation = Int.random(in: -5...5)
                    
                    samples.append(
                        RecoveryScore(
                            date: timePoint,
                            overallScore: max(0, min(100, score + timeVariation)),
                            heartRateScore: MetricScore.sampleHeartRate,
                            hrvScore: Int.random(in: 40...80),
                            sleepScore: Int.random(in: 50...90),
                            trainingLoadScore: MetricScore.sampleTrainingLoad,
                            stressScore: Int.random(in: 40...90),
                            timeOfDay: timeOfDay
                        )
                    )
                }
            }
            
            return samples
        }()
        
        var body: some View {
            VStack {
                RecoveryHistoryChart(history: Self.sampleScores, colorScheme: .light)
                    .padding()
                
                RecoveryHistoryChart(history: Self.sampleScores, colorScheme: .dark)
                    .padding()
                    .background(Color.black)
            }
        }
    }
} 