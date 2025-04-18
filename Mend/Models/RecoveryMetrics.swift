import Foundation
import SwiftUI
import HealthKit

// MARK: - Models

@MainActor
class RecoveryMetrics: ObservableObject {
    static let shared = RecoveryMetrics()
    private let healthKit = HealthKitManager.shared
    
    @Published var currentRecoveryScore: RecoveryScore?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var useSimulatedData = false
    @Published var usePoorRecoveryData = false
    
    private init() {
        Task { 
            do {
                try await healthKit.requestAuthorization()
                await loadMetrics()
            } catch {
                self.error = error
            }
        }
    }
    
    @MainActor
    func loadMetrics() async {
        isLoading = true
        defer { isLoading = false }
        
        if useSimulatedData {
            if usePoorRecoveryData {
                loadPoorRecoverySimulatedData()
            } else {
                loadNormalSimulatedData()
            }
            return
        }
        
        // Load real data from HealthKit
        async let restingHeartRate = healthKit.fetchLatestRestingHeartRateData()
        async let hrv = healthKit.fetchLatestHRVData()
        async let sleep = healthKit.fetchSleepData(forDate: Date())
        
        // Fetch daily metrics for each specific type
        async let restingHeartRateDailyData = healthKit.fetchDailyRestingHeartRateData(forDays: 7)
        async let hrvDailyData = healthKit.fetchDailyHRVData(forDays: 7)
        async let sleepDailyData = healthKit.fetchDailySleepData(forDays: 7)
        async let sleepQualityDailyData = healthKit.fetchDailySleepQualityData(forDays: 7)
        
        let (heartRateValue, hrvValue, sleepData, heartRateMetrics, hrvMetrics, sleepMetrics, sleepQualityMetrics) = 
            await (restingHeartRate, hrv, sleep, restingHeartRateDailyData, hrvDailyData, sleepDailyData, sleepQualityDailyData)
        
        // Extract sleep values
        let sleepValue = sleepData?.hours
        let sleepQualityValue = sleepData?.quality
        
        // Calculate deltas from average if we have enough data points
        let heartRateDelta = calculateDelta(from: heartRateMetrics, currentValue: heartRateValue)
        let hrvDelta = calculateDelta(from: hrvMetrics, currentValue: hrvValue)
        let sleepDelta = calculateDelta(from: sleepMetrics, currentValue: sleepValue)
        let sleepQualityDelta = calculateDelta(from: sleepQualityMetrics, currentValue: sleepQualityValue)
        
        // Update metrics on the main thread
        if let heartRateValue = heartRateValue {
            self._heartRateMetric = MetricScore(
                score: Int(heartRateValue),
                title: "Resting Heart Rate",
                description: getHeartRateDescription(currentHeartRate: heartRateValue, delta: heartRateDelta.delta),
                dailyData: heartRateMetrics,
                deltaFromAverage: heartRateDelta.delta,
                isPositiveDelta: heartRateDelta.isPositive
            )
        }
        
        if let hrvValue = hrvValue {
            self._hrvMetric = MetricScore(
                score: Int(hrvValue),
                title: "Heart Rate Variability",
                description: getHRVDescription(currentHRV: hrvValue, delta: hrvDelta.delta),
                dailyData: hrvMetrics,
                deltaFromAverage: hrvDelta.delta,
                isPositiveDelta: hrvDelta.isPositive
            )
        }
        
        if let sleepValue = sleepValue {
            self._sleepMetric = MetricScore(
                score: Int(sleepValue * 100 / 8), // Convert to score out of 100 (8 hours = 100)
                title: "Sleep Duration",
                description: getSleepDescription(currentSleep: sleepValue, delta: sleepDelta.delta),
                dailyData: sleepMetrics,
                deltaFromAverage: sleepDelta.delta,
                isPositiveDelta: sleepDelta.isPositive
            )
        }
        
        if let sleepQualityValue = sleepQualityValue {
            self._sleepQualityMetric = MetricScore(
                score: Int(sleepQualityValue),
                title: "Sleep Quality",
                description: getSleepQualityDescription(currentSleepQuality: sleepQualityValue, delta: sleepQualityDelta.delta),
                dailyData: sleepQualityMetrics,
                deltaFromAverage: sleepQualityDelta.delta,
                isPositiveDelta: sleepQualityDelta.isPositive
            )
        }
        
        // Calculate overall score based on available metrics
        updateRecoveryScore()
    }
    
    private func calculateDelta(from metrics: [RecoveryMetricData], currentValue: Double?) -> (delta: Double, isPositive: Bool) {
        guard let currentValue = currentValue, metrics.count > 0 else {
            return (0, true)
        }
        
        // Calculate average excluding today
        let previousMetrics = metrics.filter { !Calendar.current.isDateInToday($0.date) }
        guard previousMetrics.count > 0 else {
            return (0, true)
        }
        
        let average = previousMetrics.map { $0.value }.reduce(0, +) / Double(previousMetrics.count)
        let delta = average - currentValue
        
        // For heart rate, lower is better (negative delta is positive)
        // For HRV and sleep, higher is better (positive delta is positive)
        return (delta, delta < 0)
    }
    
    private func getHeartRateDescription(currentHeartRate: Double, delta: Double) -> String {
        let formattedValue = String(format: "%.0f", currentHeartRate)
        
        // More technical description
        let baseDescription = "Resting heart rate of \(formattedValue) BPM, measured during periods of inactivity. Lower RHR typically indicates better cardiovascular efficiency and recovery state."
        
        if abs(delta) < 2 {
            return baseDescription + " Your RHR is stable compared to your weekly average."
        }
        
        let isPositive = delta < 0  // For heart rate, lower is better (negative delta is positive)
        let direction = isPositive ? "higher" : "lower"
        let deltaValue = String(format: "%.0f", abs(delta))
        
        if isPositive {
            return baseDescription + " Currently \(deltaValue) BPM \(direction) than your 7-day average, which may indicate increased physiological stress, incomplete recovery, or normal daily variation."
        } else {
            return baseDescription + " Currently \(deltaValue) BPM \(direction) than your 7-day average, suggesting improved cardiovascular recovery or adaptation to recent training."
        }
    }
    
    private func getHRVDescription(currentHRV: Double, delta: Double) -> String {
        let formattedValue = String(format: "%.0f", currentHRV)
        
        // More technical description
        let baseDescription = "Heart rate variability of \(formattedValue) ms (RMSSD), reflecting autonomic nervous system balance. Higher values typically indicate better recovery capacity and stress resilience."
        
        if abs(delta) < 3 {
            return baseDescription + " Your HRV is consistent with your recent baseline."
        }
        
        let isPositive = delta > 0  // For HRV, higher is better (positive delta is positive)
        let direction = isPositive ? "higher" : "lower"
        let deltaValue = String(format: "%.0f", abs(delta))
        
        if isPositive {
            return baseDescription + " Currently \(deltaValue) ms \(direction) than your 7-day average, suggesting improved parasympathetic tone and potentially better recovery status."
        } else {
            return baseDescription + " Currently \(deltaValue) ms \(direction) than your 7-day average, which may indicate accumulated fatigue, increased stress, or incomplete recovery."
        }
    }
    
    private func getSleepDescription(currentSleep: Double, delta: Double) -> String {
        let formattedHours = String(format: "%.1f hours", currentSleep)
        
        // More technical description
        let baseDescription = "\(formattedHours) of total sleep, including all sleep phases. Optimal adult sleep duration typically ranges from 7-9 hours per night for cognitive and physical recovery."
        
        if abs(delta) < 0.5 {
            return baseDescription + " Your sleep duration is consistent with your recent pattern."
        }
        
        let isPositive = delta > 0  // For sleep, more is better (positive delta is positive)
        let direction = isPositive ? "more" : "less"
        let deltaValue = String(format: "%.1f", abs(delta))
        
        if isPositive {
            return baseDescription + " This is \(deltaValue) hours \(direction) than your weekly average, potentially enhancing recovery processes and cognitive function."
        } else {
            return baseDescription + " This is \(deltaValue) hours \(direction) than your weekly average, which may limit optimal recovery and affect performance."
        }
    }
    
    private func getSleepQualityDescription(currentSleepQuality: Double, delta: Double) -> String {
        let formattedValue = String(format: "%.0f", currentSleepQuality)
        
        // Create a more technical and informative description
        let baseDescription = "Sleep quality score of \(formattedValue)/100, calculated from sleep continuity (10%), deep/REM sleep percentage (30%), and total sleep duration (60%)."
        
        if abs(delta) < 5 {
            return baseDescription + " Your sleep quality is consistent with your recent average."
        }
        
        let isPositive = delta > 0  // For sleep quality, higher is better (positive delta is positive)
        let direction = isPositive ? "higher" : "lower"
        let deltaValue = String(format: "%.0f", abs(delta))
        
        if isPositive {
            return baseDescription + " Your score is \(deltaValue) points \(direction) than your 7-day average, indicating improved sleep architecture with better continuity and/or more optimal deep sleep cycles."
        } else {
            return baseDescription + " Your score is \(deltaValue) points \(direction) than your 7-day average, suggesting possible disruptions in sleep cycles or reduced deep sleep phases."
        }
    }
    
    // Public methods for creating metrics
    func createHRVMetric() -> MetricScore {
        return _hrvMetric ?? MetricScore.sampleHRV
    }
    
    func createSleepMetric() -> MetricScore {
        return _sleepMetric ?? MetricScore(
            score: 0,
            title: "Sleep",
            description: "No sleep data available",
            dailyData: [],
            deltaFromAverage: 0,
            isPositiveDelta: true
        )
    }
    
    @MainActor
    private func updateRecoveryScore() {
        // Calculate overall score based on available metrics
        var totalScore = 0
        var metricCount = 0
        
        if let heartRateMetric = self._heartRateMetric {
            totalScore += heartRateMetric.score
            metricCount += 1
        }
        
        if let hrvMetric = self._hrvMetric {
            totalScore += hrvMetric.score
            metricCount += 1
        }
        
        if let sleepMetric = self._sleepMetric {
            totalScore += sleepMetric.score
            metricCount += 1
        }
        
        if let sleepQualityMetric = self._sleepQualityMetric {
            totalScore += sleepQualityMetric.score
            metricCount += 1
        }
        
        let overallScore = metricCount > 0 ? totalScore / metricCount : 0
        
        currentRecoveryScore = RecoveryScore(
            date: Date(),
            overallScore: overallScore,
            heartRateScore: _heartRateMetric ?? MetricScore.sampleHeartRate,
            hrvScore: _hrvMetric?.score ?? 0,
            sleepScore: _sleepMetric?.score ?? 0,
            trainingLoadScore: MetricScore.sampleTrainingLoad,
            stressScore: 75
        )
    }
    
    // Properties to store current metrics
    private var _heartRateMetric: MetricScore?
    private var _hrvMetric: MetricScore?
    private var _sleepMetric: MetricScore?
    private var _sleepQualityMetric: MetricScore?
    
    // Public getters
    var heartRateMetric: MetricScore? { _heartRateMetric }
    var hrvMetric: MetricScore? { _hrvMetric }
    var sleepMetric: MetricScore? { _sleepMetric }
    var sleepQualityMetric: MetricScore? { _sleepQualityMetric }
    
    /// Toggles between real and simulated data and reloads metrics
    @MainActor
    func toggleSimulatedData() {
        useSimulatedData.toggle()
        // If turning off simulated data, also turn off poor recovery
        if !useSimulatedData {
            usePoorRecoveryData = false
        }
        Task {
            await loadMetrics()
        }
    }
    
    /// Toggles between normal and poor recovery simulated data
    @MainActor
    func togglePoorRecoveryData() {
        usePoorRecoveryData.toggle()
        // Make sure simulated data is enabled when toggling poor recovery
        if usePoorRecoveryData && !useSimulatedData {
            useSimulatedData = true
        }
        Task {
            await loadMetrics()
        }
    }
    
    /// Refreshes data from HealthKit or simulated data
    @MainActor
    func refreshData() {
        Task {
            await loadMetrics()
        }
    }
    
    private func loadNormalSimulatedData() {
        // Generate daily data for the last 7 days
        let calendar = Calendar.current
        let now = Date()
        
        // Create simulated heart rate data
        let heartRateValue = 58.0
        var heartRateData: [RecoveryMetricData] = []
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            // Simulate slight daily variations
            let variation = Double.random(in: -5...5)
            let value = max(55, min(75, heartRateValue + variation)) // keep within realistic range
            heartRateData.append(RecoveryMetricData(date: date, value: value))
        }
        
        // Create simulated HRV data
        let hrvValue = 65.0
        var hrvData: [RecoveryMetricData] = []
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            // Simulate slight daily variations
            let variation = Double.random(in: -10...10)
            let value = max(45, min(85, hrvValue + variation)) // keep within realistic range
            hrvData.append(RecoveryMetricData(date: date, value: value))
        }
        
        // Create simulated sleep data
        let sleepValue = 7.5
        let sleepQualityValue = 85.0 // Sleep quality score 0-100
        var sleepData: [RecoveryMetricData] = []
        var sleepQualityData: [RecoveryMetricData] = []
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            // Simulate slight daily variations
            let variation = Double.random(in: -1.0...1.0)
            let value = max(5.5, min(9.0, sleepValue + variation)) // keep within realistic range
            sleepData.append(RecoveryMetricData(date: date, value: value))
            
            // Also simulate sleep quality values
            let qualityVariation = Double.random(in: -10.0...10.0)
            let qualityValue = max(60, min(95, sleepQualityValue + qualityVariation))
            sleepQualityData.append(RecoveryMetricData(date: date, value: qualityValue))
        }
        
        // Calculate deltas from the simulated data
        let avgHeartRate = heartRateData.dropFirst().map { $0.value }.reduce(0, +) / Double(heartRateData.count - 1)
        let heartRateDelta = avgHeartRate - heartRateValue
        // For heart rate, lower is better (negative delta is positive)
        let isHeartRateDeltaPositive = heartRateDelta > 0
        
        let avgHRV = hrvData.dropFirst().map { $0.value }.reduce(0, +) / Double(hrvData.count - 1)
        let hrvDelta = hrvValue - avgHRV
        // For HRV, higher is better (positive delta is positive)
        let isHRVDeltaPositive = hrvDelta > 0
        
        let avgSleep = sleepData.dropFirst().map { $0.value }.reduce(0, +) / Double(sleepData.count - 1)
        let sleepDelta = sleepValue - avgSleep
        // For sleep, more is better (positive delta is positive)
        let isSleepDeltaPositive = sleepDelta > 0
        
        let avgSleepQuality = sleepQualityData.dropFirst().map { $0.value }.reduce(0, +) / Double(sleepQualityData.count - 1)
        let sleepQualityDelta = sleepQualityValue - avgSleepQuality
        // Higher quality is better (positive delta is positive)
        let isSleepQualityDeltaPositive = sleepQualityDelta > 0
        
        // Use simulated data
        self._heartRateMetric = MetricScore(
            score: Int(heartRateValue),
            title: "Resting Heart Rate",
            description: getHeartRateDescription(currentHeartRate: heartRateValue, delta: heartRateDelta),
            dailyData: heartRateData.sorted { $0.date < $1.date },
            deltaFromAverage: heartRateDelta,
            isPositiveDelta: isHeartRateDeltaPositive
        )
        
        self._hrvMetric = MetricScore(
            score: Int(hrvValue),
            title: "Heart Rate Variability",
            description: getHRVDescription(currentHRV: hrvValue, delta: hrvDelta),
            dailyData: hrvData.sorted { $0.date < $1.date },
            deltaFromAverage: hrvDelta,
            isPositiveDelta: isHRVDeltaPositive
        )
        
        self._sleepMetric = MetricScore(
            score: Int(sleepValue * 100 / 8), // Convert to score out of 100 (8 hours = 100)
            title: "Sleep Duration",
            description: getSleepDescription(currentSleep: sleepValue, delta: sleepDelta),
            dailyData: sleepData.sorted { $0.date < $1.date },
            deltaFromAverage: sleepDelta,
            isPositiveDelta: isSleepDeltaPositive
        )
        
        self._sleepQualityMetric = MetricScore(
            score: Int(sleepQualityValue),
            title: "Sleep Quality",
            description: getSleepQualityDescription(currentSleepQuality: sleepQualityValue, delta: sleepQualityDelta),
            dailyData: sleepQualityData.sorted { $0.date < $1.date },
            deltaFromAverage: sleepQualityDelta,
            isPositiveDelta: isSleepQualityDeltaPositive
        )
        
        // Calculate overall score based on simulated metrics
        updateRecoveryScore()
    }
    
    private func loadPoorRecoverySimulatedData() {
        // Generate daily data for the last 7 days
        let calendar = Calendar.current
        let now = Date()
        
        // Create simulated heart rate data - higher heart rate indicates poor recovery
        let heartRateValue = 75.0
        var heartRateData: [RecoveryMetricData] = []
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            // First few days are normal, today is elevated
            var baseValue = 63.0
            if day < 2 {
                baseValue = 75.0 // Today and yesterday elevated
            }
            let variation = Double.random(in: -3...5)
            let value = max(55, min(85, baseValue + variation))
            heartRateData.append(RecoveryMetricData(date: date, value: value))
        }
        
        // Create simulated HRV data - lower HRV indicates stress/fatigue
        let hrvValue = 35.0
        var hrvData: [RecoveryMetricData] = []
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            // First few days poor, previous days were better
            var baseValue = 63.0
            if day < 2 {
                baseValue = 35.0 // Today and yesterday depressed
            }
            let variation = Double.random(in: -5...8)
            let value = max(30, min(75, baseValue + variation))
            hrvData.append(RecoveryMetricData(date: date, value: value))
        }
        
        // Create simulated sleep data - less sleep hours indicates poor recovery
        let sleepValue = 5.2
        var sleepData: [RecoveryMetricData] = []
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            // First few days poor, previous days were better
            var baseValue = 7.0
            if day < 2 {
                baseValue = 5.2
            }
            let variation = Double.random(in: -0.5...0.8)
            let value = max(4.5, min(8.0, baseValue + variation))
            sleepData.append(RecoveryMetricData(date: date, value: value))
        }
        
        // Create simulated sleep quality data - lower quality
        let sleepQualityValue = 55.0
        var sleepQualityData: [RecoveryMetricData] = []
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            // First few days poor, previous days were better
            var baseValue = 75.0
            if day < 2 {
                baseValue = 55.0
            }
            let variation = Double.random(in: -5...8)
            let value = max(45, min(85, baseValue + variation))
            sleepQualityData.append(RecoveryMetricData(date: date, value: value))
        }
        
        // Calculate deltas - for poor recovery, we want negative deltas for good metrics
        let avgHeartRate = heartRateData.filter { day in
            if let dayIndex = heartRateData.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day.date) }) {
                return dayIndex > 1 // Skip the current and previous day
            }
            return false
        }.map { $0.value }.reduce(0, +) / 5.0 // Average of the 5 previous days
        
        let heartRateDelta = avgHeartRate - heartRateValue
        let isHeartRateDeltaPositive = heartRateDelta > 0 // Negative delta for heart rate is good
        
        // Similar for HRV
        let avgHRV = hrvData.filter { day in
            if let dayIndex = hrvData.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day.date) }) {
                return dayIndex > 1
            }
            return false
        }.map { $0.value }.reduce(0, +) / 5.0
        
        let hrvDelta = hrvValue - avgHRV
        let isHRVDeltaPositive = hrvDelta > 0 // We want this to be negative
        
        // Sleep deltas
        let avgSleep = sleepData.filter { day in
            if let dayIndex = sleepData.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day.date) }) {
                return dayIndex > 1
            }
            return false
        }.map { $0.value }.reduce(0, +) / 5.0
        
        let sleepDelta = sleepValue - avgSleep
        let isSleepDeltaPositive = sleepDelta > 0 // We want this to be negative
        
        // Sleep quality deltas
        let avgSleepQuality = sleepQualityData.filter { day in
            if let dayIndex = sleepQualityData.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day.date) }) {
                return dayIndex > 1
            }
            return false
        }.map { $0.value }.reduce(0, +) / 5.0
        
        let sleepQualityDelta = sleepQualityValue - avgSleepQuality
        let isSleepQualityDeltaPositive = sleepQualityDelta > 0 // We want this to be negative
        
        // Populate metrics with poor recovery data
        self._heartRateMetric = MetricScore(
            score: 45, // Lower score is worse for heart rate
            title: "Resting Heart Rate",
            description: "Your resting heart rate is \(String(format: "%.0f", abs(heartRateDelta))) BPM higher than your average, which may indicate fatigue or stress.",
            dailyData: heartRateData.sorted { $0.date < $1.date },
            deltaFromAverage: heartRateDelta,
            isPositiveDelta: false // It's a negative change
        )
        
        self._hrvMetric = MetricScore(
            score: 40, // Lower score is worse for HRV
            title: "Heart Rate Variability",
            description: "Your HRV is \(String(format: "%.0f", abs(hrvDelta)))ms lower than your average, which may indicate increased stress levels.",
            dailyData: hrvData.sorted { $0.date < $1.date },
            deltaFromAverage: hrvDelta,
            isPositiveDelta: false // It's a negative change
        )
        
        self._sleepMetric = MetricScore(
            score: Int(sleepValue * 100 / 8), // Around 65%
            title: "Sleep Duration",
            description: "You slept \(String(format: "%.1f", abs(sleepDelta))) hours less than your average, which may impact your recovery.",
            dailyData: sleepData.sorted { $0.date < $1.date },
            deltaFromAverage: sleepDelta,
            isPositiveDelta: false // It's a negative change
        )
        
        self._sleepQualityMetric = MetricScore(
            score: Int(sleepQualityValue), // Around 55
            title: "Sleep Quality",
            description: "Your sleep quality is \(String(format: "%.0f", abs(sleepQualityDelta))) points lower than your average, suggesting disrupted sleep patterns.",
            dailyData: sleepQualityData.sorted { $0.date < $1.date },
            deltaFromAverage: sleepQualityDelta,
            isPositiveDelta: false // It's a negative change
        )
        
        // Calculate recovery score - poor overall score
        let poorRecoveryScore = RecoveryScore(
            date: Date(),
            overallScore: 45, // Poor recovery score
            heartRateScore: _heartRateMetric ?? MetricScore.sampleHeartRate,
            hrvScore: _hrvMetric?.score ?? 0,
            sleepScore: _sleepMetric?.score ?? 0,
            trainingLoadScore: MetricScore(
                score: 80, // High training load
                title: "Training Load",
                description: "Your training load is high, which combined with your other metrics suggests you may need additional recovery time.",
                dailyData: [
                    RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 55),
                    RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 60),
                    RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 65),
                    RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 70),
                    RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 75),
                    RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 85),
                    RecoveryMetricData(date: Date(), value: 80)
                ],
                deltaFromAverage: 15.0,
                isPositiveDelta: false
            ),
            stressScore: 35
        )
        
        self.currentRecoveryScore = poorRecoveryScore
    }
}

struct RecoveryScore: Identifiable {
    let id = UUID()
    let date: Date
    let overallScore: Int
    let heartRateScore: MetricScore
    let hrvScore: Int
    let sleepScore: Int
    let trainingLoadScore: MetricScore
    let stressScore: Int
    
    static var sample: RecoveryScore {
        RecoveryScore(
            date: Date(),
            overallScore: 72,
            heartRateScore: MetricScore.sampleHeartRate,
            hrvScore: 76,
            sleepScore: 82,
            trainingLoadScore: MetricScore.sampleTrainingLoad,
            stressScore: 75
        )
    }
}

struct MetricScore {
    let score: Int
    let title: String
    let description: String
    let dailyData: [RecoveryMetricData]
    let deltaFromAverage: Double
    let isPositiveDelta: Bool
}

// MARK: - MetricScore Factory Methods
extension MetricScore {
    static func createHRVMetric(score: Int) -> MetricScore {
        MetricScore(
            score: score,
            title: "Heart Rate Variability",
            description: "Your HRV score indicates your current recovery state.",
            dailyData: [], // You might want to populate this with actual data
            deltaFromAverage: 0,
            isPositiveDelta: true
        )
    }
    
    static func createSleepMetric(score: Int) -> MetricScore {
        MetricScore(
            score: score,
            title: "Sleep Quality",
            description: "Your sleep quality score for the day.",
            dailyData: [], // You might want to populate this with actual data
            deltaFromAverage: 0,
            isPositiveDelta: true
        )
    }
    
    static func heartRateFactory(value: Double, delta: Double, isPositiveDelta: Bool, data: [RecoveryMetricData]) -> MetricScore {
        return MetricScore(
            score: Int(value),
            title: "Resting Heart Rate",
            description: "Your resting heart rate is \(String(format: "%.0f", value)) BPM, which is \(String(format: "%.0f", abs(delta))) BPM \(delta < 0 ? "lower" : "higher") than your average.",
            dailyData: data,
            deltaFromAverage: delta,
            isPositiveDelta: isPositiveDelta
        )
    }
    
    static func hrvFactory(value: Double, delta: Double, isPositiveDelta: Bool, data: [RecoveryMetricData]) -> MetricScore {
        return MetricScore(
            score: Int(value),
            title: "Heart Rate Variability",
            description: "Your HRV is \(String(format: "%.0f", value)) ms, which is \(String(format: "%.0f", abs(delta))) ms \(delta > 0 ? "higher" : "lower") than your average.",
            dailyData: data,
            deltaFromAverage: delta,
            isPositiveDelta: isPositiveDelta
        )
    }
}

// MARK: - MetricScore Sample Data
extension MetricScore {
    static var sampleHeartRate: MetricScore {
        MetricScore(
            score: 68,
            title: "Resting Heart Rate",
            description: "Your resting heart rate is 3 BPM lower than your 7-day average, which is a positive sign of recovery.",
            dailyData: [
                RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 62),
                RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 65),
                RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 64),
                RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 67),
                RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 66),
                RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 65),
                RecoveryMetricData(date: Date(), value: 59)
            ],
            deltaFromAverage: 3.0,
            isPositiveDelta: true
        )
    }
    
    static var sampleHRV: MetricScore {
        MetricScore(
            score: 76,
            title: "Heart Rate Variability",
            description: "Your HRV is 5ms higher than your 7-day average, indicating better recovery and less stress.",
            dailyData: [
                RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 58),
                RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 55),
                RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 54),
                RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 59),
                RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 62),
                RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 63),
                RecoveryMetricData(date: Date(), value: 67)
            ],
            deltaFromAverage: 5.0,
            isPositiveDelta: true
        )
    }
    
    static var sampleTrainingLoad: MetricScore {
        MetricScore(
            score: 62,
            title: "Training Load",
            description: "Your training load is moderate with a slight increase over your 7-day average, suggesting to focus on recovery today.",
            dailyData: [
                RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 85),
                RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 42),
                RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 78),
                RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 50),
                RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 85),
                RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 45),
                RecoveryMetricData(date: Date(), value: 60)
            ],
            deltaFromAverage: 10.0,
            isPositiveDelta: false
        )
    }
    
    static var sampleSleepQuality: MetricScore {
        MetricScore(
            score: 83,
            title: "Sleep Quality",
            description: "Your sleep quality is high with good deep sleep phases and few disruptions.",
            dailyData: [
                RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 78),
                RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 75),
                RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 70),
                RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 75),
                RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 80),
                RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 79),
                RecoveryMetricData(date: Date(), value: 83)
            ],
            deltaFromAverage: 6.5,
            isPositiveDelta: true
        )
    }
}

struct RecoveryMetricData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct RecoveryRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let type: RecommendationType
    let icon: String
}

enum RecommendationType {
    case positive
    case neutral
    case needsAttention
    
    var color: Color {
        switch self {
        case .positive: return MendColors.positive
        case .neutral: return MendColors.neutral
        case .needsAttention: return MendColors.negative
        }
    }
}

extension RecoveryScore {
    func getRecoveryRecommendations(previousScores: [RecoveryScore]) -> [RecoveryRecommendation] {
        var recommendations: [RecoveryRecommendation] = []
        
        // Sleep recommendation based on score
        if sleepScore < 60 {
            recommendations.append(RecoveryRecommendation(
                title: "Prioritize Sleep",
                description: "Your sleep score is lower than usual. Try to get to bed earlier tonight.",
                type: .needsAttention,
                icon: "bed.double.fill"
            ))
        } else if sleepScore > 80 {
            recommendations.append(RecoveryRecommendation(
                title: "Great Sleep!",
                description: "You're maintaining healthy sleep patterns. Keep it up!",
                type: .positive,
                icon: "bed.double.fill"
            ))
        }
        
        // HRV-based recommendation
        if hrvScore < previousScores.map({ $0.hrvScore }).reduce(0, +) / max(previousScores.count, 1) {
            recommendations.append(RecoveryRecommendation(
                title: "HRV Trending Down",
                description: "Consider taking it easier today to help your body recover.",
                type: .needsAttention,
                icon: "waveform.path.ecg"
            ))
        }
        
        // Stress management
        if stressScore < 60 {
            recommendations.append(RecoveryRecommendation(
                title: "Manage Stress",
                description: "High stress detected. Try some breathing exercises or meditation.",
                type: .neutral,
                icon: "brain.head.profile"
            ))
        }
        
        // Overall recovery trend
        let recentScores = previousScores.prefix(7)
        let averageScore = recentScores.map({ $0.overallScore }).reduce(0, +) / max(recentScores.count, 1)
        
        if overallScore > averageScore + 10 {
            recommendations.append(RecoveryRecommendation(
                title: "Recovery Improving",
                description: "Your recovery is trending upward. Great job balancing activity and rest!",
                type: .positive,
                icon: "chart.line.uptrend.xyaxis"
            ))
        }
        
        return recommendations
    }
}

// Sample data
extension RecoveryRecommendation {
    static let samples = [
        RecoveryRecommendation(
            title: "Improve Sleep Quality",
            description: "Try to get to bed 30 minutes earlier tonight than last night",
            type: .neutral,
            icon: "bed.double.fill"
        ),
        RecoveryRecommendation(
            title: "Great Recovery Trend",
            description: "You've maintained consistent recovery scores this week",
            type: .positive,
            icon: "chart.line.uptrend.xyaxis"
        )
    ]
}