import Foundation
import SwiftUI
import HealthKit

// Keys for UserDefaults
private let kRecoveryScore = "recoveryScore"
private let kNotificationPreference = "notificationPreference"

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
        
        await loadHealthKitData()
    }
    
    @MainActor
    private func loadHealthKitData() async {
        // If using simulated data, load that instead
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
            // For HRV, higher values are better, so if current value is lower than average
            // we need to calculate an appropriate score that reflects poor recovery
            let avgHRV = hrvMetrics.filter { !Calendar.current.isDateInToday($0.date) }
                .map { $0.value }
                .reduce(0, +) / Double(max(1, hrvMetrics.filter { !Calendar.current.isDateInToday($0.date) }.count))
            
            // Calculate a score that reflects the HRV quality (0-100 scale)
            // When hrvValue is less than 70% of average, score should be very low
            // When hrvValue is equal to or greater than average, score should be high
            let hrvPercentOfAverage = avgHRV > 0 ? (hrvValue / avgHRV) : 1.0
            let calculatedScore: Int
            
            if hrvPercentOfAverage >= 1.0 {
                // HRV is equal to or better than average
                calculatedScore = min(100, 70 + Int(30 * min(1.0, (hrvPercentOfAverage - 1.0) * 2)))
            } else {
                // HRV is worse than average
                calculatedScore = max(30, 70 - Int(40 * min(1.0, (1.0 - hrvPercentOfAverage) * 1.5)))
            }
            
            self._hrvMetric = MetricScore(
                score: calculatedScore,
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
        
        // Calculate and update the recovery score
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
        let delta = currentValue - average
        
        // For heart rate, lower is better (negative delta is positive)
        // For HRV and sleep, higher is better (positive delta is positive)
        let isPositive: Bool
        if metrics.first?.value.isHeartRate == true {
            // For heart rate, lower is better, so negative delta is positive
            isPositive = delta < 0
        } else {
            // For HRV, sleep, etc., higher is better, so positive delta is positive
            isPositive = delta > 0
        }
        
        return (delta, isPositive)
    }
    
    private func getHeartRateDescription(currentHeartRate: Double, delta: Double) -> String {
        let formattedValue = String(format: "%.0f", currentHeartRate)
        let formattedDelta = String(format: "%.0f", abs(delta))
        let avgValue = currentHeartRate - delta
        let formattedAvg = String(format: "%.0f", avgValue)
        
        // Create a more detailed and informative description
        let baseDescription = "Resting heart rate of \(formattedValue) BPM, measured during periods of inactivity."     // Lower RHR typically indicates better cardiovascular efficiency and recovery state.
        
        // If delta is negligible, report stability
        if abs(delta) < 2 {
            return baseDescription + " Your RHR is stable compared to your weekly average of \(formattedAvg) BPM, indicating a consistent balance between cardiovascular load and recovery."
        }
        
        // For heart rate, lower is typically better (negative delta is positive)
        let isPositive = delta < 0
        let direction = delta < 0 ? "lower" : "higher"
        
        if isPositive {
            return baseDescription + " Your RHR is \(formattedDelta) BPM \(direction) than your 7-day average of \(formattedAvg) BPM, suggesting improved cardiovascular efficiency and recovery."
        } else {
            return baseDescription + " Your RHR is \(formattedDelta) BPM \(direction) than your 7-day average of \(formattedAvg) BPM, which could indicate increased fatigue, stress, or insufficient recovery."
        }
    }
    
    private func getHRVDescription(currentHRV: Double, delta: Double) -> String {
        let formattedValue = String(format: "%.0f", currentHRV)
        let formattedDelta = String(format: "%.0f", abs(delta))
        let avgValue = currentHRV - delta
        let formattedAvg = String(format: "%.0f", avgValue)
        
        // Create a more detailed description
        let baseDescription = "Heart Rate Variability of \(formattedValue) ms, representing the average variation in time intervals between consecutive heartbeats."     //Higher HRV typically indicates better recovery and autonomic nervous system balance.
        
        // If delta is negligible, report stability
        if abs(delta) < 5 {
            return baseDescription + " Your HRV is stable compared to your weekly average of \(formattedAvg) ms, indicating consistent levels of fatigue and recovery."
        }
        
        // For HRV, higher is typically better (positive delta is positive)
        let isPositive = delta > 0
        let direction = delta > 0 ? "higher" : "lower"
        
        // Calculate percentage of change to provide more meaningful context
        let percentChange = abs(delta) / avgValue * 100
        let significantChange = percentChange > 15
        
        if isPositive {
            let addon = significantChange ? 
                ", suggesting significantly better recovery, reduced stress, and improved readiness." :
                ", suggesting better recovery, reduced stress, and improved readiness."
            return baseDescription + " Your HRV is \(formattedDelta) ms \(direction) than your 7-day average of \(formattedAvg) ms" + addon
        } else {
            let severity = percentChange > 30 ? "significantly " : ""
            return baseDescription + " Your HRV is \(formattedDelta) ms \(direction) than your 7-day average of \(formattedAvg) ms, which could indicate \(severity)increased stress, fatigue, or accumulated training load requiring additional recovery."
        }
    }
    
    private func getSleepDescription(currentSleep: Double, delta: Double) -> String {
        let formattedValue = String(format: "%.1f", currentSleep)
        let formattedDelta = String(format: "%.1f", abs(delta))
        let avgValue = currentSleep - delta
        let formattedAvg = String(format: "%.1f", avgValue)
        
        // Create a more detailed description
        let baseDescription = "Sleep duration of \(formattedValue) hours. Adequate sleep (7-9 hours) is essential for physical recovery, cognitive function, and overall health."
        
        // If delta is negligible, report stability
        if abs(delta) < 0.3 {
            return baseDescription + " Your sleep duration is consistent with your weekly average of \(formattedAvg) hours."
        }
        
        // For sleep duration, more is typically better up to a point (positive delta is positive)
        // We don't need to store this value since we're just checking conditions
        // let isPositive = delta > 0 && currentSleep <= 9.0 || delta < 0 && currentSleep > 9.0
        
        if delta > 0 {
            if currentSleep <= 9.0 {
                return baseDescription + " You slept \(formattedDelta) hours more than your 7-day average of \(formattedAvg) hours, which is beneficial for recovery and cognitive function."
            } else {
                return baseDescription + " You slept \(formattedDelta) hours more than your 7-day average of \(formattedAvg) hours. While sleep is important, very long sleep periods (>9 hours) may sometimes indicate fatigue or recovery needs."
            }
        } else {
            if currentSleep < 7.0 {
                return baseDescription + " You slept \(formattedDelta) hours less than your 7-day average of \(formattedAvg) hours, which may impact your cognitive function and physical recovery."
            } else {
                return baseDescription + " You slept \(formattedDelta) hours less than your 7-day average of \(formattedAvg) hours, but still within the recommended range."
            }
        }
    }
    
    private func getSleepQualityDescription(currentSleepQuality: Double, delta: Double) -> String {
        let formattedValue = String(format: "%.0f", currentSleepQuality)
        let formattedDelta = String(format: "%.0f", abs(delta))
        let avgValue = currentSleepQuality - delta
        let formattedAvg = String(format: "%.0f", avgValue)
        
        // Create a more technical and informative description
        let baseDescription = "Sleep quality score of \(formattedValue)/100, calculated from sleep continuity (10%), deep/REM sleep percentage (30%), and total sleep duration (60%)."
        
        if abs(delta) < 5 {
            return baseDescription + " Your sleep quality is consistent with your 7-day average of \(formattedAvg)/100."
        }
        
        let isPositive = delta > 0  // For sleep quality, higher is better (positive delta is positive)
        let direction = isPositive ? "higher" : "lower"
        
        if isPositive {
            return baseDescription + " Your score is \(formattedDelta) points \(direction) than your 7-day average of \(formattedAvg)/100, indicating improved sleep architecture with better continuity and/or more optimal deep sleep cycles."
        } else {
            return baseDescription + " Your score is \(formattedDelta) points \(direction) than your 7-day average of \(formattedAvg)/100, suggesting possible disruptions in sleep cycles or reduced deep sleep phases."
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
        // Calculate overall score based on available metrics with weighted importance
        // Heart rate and HRV will be weighted more heavily
        var weightedTotal = 0
        var totalWeight = 0
        
        // Constants for weighting different metrics
        let heartRateWeight = 3  // Heart rate is 3x more important
        let hrvWeight = 3        // HRV is 3x more important
        let sleepWeight = 2      // Sleep is 2x more important
        let sleepQualityWeight = 1
        let trainingLoadWeight = 2  // Training load is 2x more important
        
        if let heartRateMetric = self._heartRateMetric {
            // For heart rate, we need to invert the score because a higher heart rate 
            // is actually worse for recovery (lower = better)
            let invertedScore = max(40, 100 - heartRateMetric.score)
            weightedTotal += invertedScore * heartRateWeight
            totalWeight += heartRateWeight
        }
        
        if let hrvMetric = self._hrvMetric {
            weightedTotal += hrvMetric.score * hrvWeight
            totalWeight += hrvWeight
        }
        
        if let sleepMetric = self._sleepMetric {
            weightedTotal += sleepMetric.score * sleepWeight
            totalWeight += sleepWeight
        }
        
        if let sleepQualityMetric = self._sleepQualityMetric {
            weightedTotal += sleepQualityMetric.score * sleepQualityWeight
            totalWeight += sleepQualityWeight
        }
        
        // Calculate training load score
        // Use the sample training load for now, but in a real app this would be from actual data
        let trainingLoadMetric = MetricScore.sampleTrainingLoad
        
        // Calculate a training load score based on the relationship to the 4-week average
        // The score is already calculated in the sampleTrainingLoad method, but not used
        // Here we'll generate a score where optimal training load gives a higher score
        let percentChange = trainingLoadMetric.deltaFromAverage / (Double(trainingLoadMetric.score) - trainingLoadMetric.deltaFromAverage) * 100
        let trainingLoadScore: Int
        
        if percentChange >= 5 && percentChange <= 15 {
            // Optimal range: 5-15% increase
            trainingLoadScore = 90 + Int(min(10, percentChange - 5))
        } else if percentChange > 15 && percentChange <= 30 {
            // High but still acceptable: 15-30% increase
            trainingLoadScore = 75 - Int(min(15, percentChange - 15))
        } else if percentChange > 30 {
            // Too much increase: >30%
            trainingLoadScore = 60 - Int(min(30, percentChange - 30))
        } else if percentChange >= 0 && percentChange < 5 {
            // Maintenance: 0-5% increase
            trainingLoadScore = 80 + Int(percentChange)
        } else {
            // Decreasing load: negative percentChange
            trainingLoadScore = 70 + Int(max(-20, percentChange))
        }
        
        // Add training load to weighted total
        weightedTotal += trainingLoadScore * trainingLoadWeight
        totalWeight += trainingLoadWeight
        
        let overallScore = totalWeight > 0 ? weightedTotal / totalWeight : 0
        
        currentRecoveryScore = RecoveryScore(
            date: Date(),
            overallScore: overallScore,
            heartRateScore: _heartRateMetric ?? MetricScore.sampleHeartRate,
            hrvScore: _hrvMetric?.score ?? 0,
            sleepScore: _sleepMetric?.score ?? 0,
            trainingLoadScore: trainingLoadMetric,
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
        // Generate daily data points with slightly worse trends
        var heartRateData: [RecoveryMetricData] = []
        var hrvData: [RecoveryMetricData] = []
        var sleepData: [RecoveryMetricData] = []
        var sleepQualityData: [RecoveryMetricData] = []
        
        // Last 7 days
        for dayOffset in (0...6).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            
            // Heart rate - poor recovery shows increasing heart rate
            let heartRatePoint = Double.random(in: 58...68)
            heartRateData.append(RecoveryMetricData(date: date, value: heartRatePoint + Double(dayOffset) * 1.2))
            
            // HRV - poor recovery shows decreasing HRV
            let hrvPoint = Double.random(in: 55...65)
            hrvData.append(RecoveryMetricData(date: date, value: hrvPoint - Double(dayOffset) * 1.5))
            
            // Sleep - poor recovery shows decreasing sleep
            let sleepPoint = Double.random(in: 7.0...8.0)
            sleepData.append(RecoveryMetricData(date: date, value: sleepPoint - Double(dayOffset) * 0.12))
            
            // Sleep quality - poor recovery shows decreasing sleep quality
            let sleepQualityPoint = Double.random(in: 75...90)
            sleepQualityData.append(RecoveryMetricData(date: date, value: sleepQualityPoint - Double(dayOffset) * 2.0))
        }
        
        // Calculate averages
        let heartRateAvg = heartRateData.dropLast().map { $0.value }.reduce(0, +) / Double(heartRateData.count - 1)
        let hrvAvg = hrvData.dropLast().map { $0.value }.reduce(0, +) / Double(hrvData.count - 1)
        let sleepAvg = sleepData.dropLast().map { $0.value }.reduce(0, +) / Double(sleepData.count - 1)
        let sleepQualityAvg = sleepQualityData.dropLast().map { $0.value }.reduce(0, +) / Double(sleepQualityData.count - 1)
        
        // Get today's values (last in each array)
        let heartRateValue = heartRateData.last!.value
        let hrvValue = hrvData.last!.value
        let sleepValue = sleepData.last!.value
        let sleepQualityValue = sleepQualityData.last!.value
        
        // Calculate deltas
        let heartRateDelta = heartRateValue - heartRateAvg
        let hrvDelta = hrvValue - hrvAvg 
        let sleepDelta = sleepValue - sleepAvg
        let sleepQualityDelta = sleepQualityValue - sleepQualityAvg
        
        // Create metrics with poor recovery indicators
        self._heartRateMetric = MetricScore(
            score: Int(heartRateValue),
            title: "Resting Heart Rate",
            description: "Your resting heart rate is \(String(format: "%.0f", abs(heartRateDelta)))BPM higher than your average, which may indicate incomplete recovery or stress.",
            dailyData: heartRateData.sorted { $0.date < $1.date },
            deltaFromAverage: heartRateDelta,
            isPositiveDelta: heartRateDelta < 0 // For heart rate, lower is better
        )
        
        // Calculate a score that reflects the HRV quality (0-100 scale)
        let hrvPercentOfAverage = hrvAvg > 0 ? (hrvValue / hrvAvg) : 1.0
        let calculatedScore = max(30, 70 - Int(40 * min(1.0, (1.0 - hrvPercentOfAverage) * 1.5)))
        
        self._hrvMetric = MetricScore(
            score: calculatedScore,
            title: "Heart Rate Variability",
            description: "Your HRV is \(String(format: "%.0f", abs(hrvDelta))) ms lower than your average of \(String(format: "%.0f", hrvAvg)) ms, which may indicate increased stress levels and poor recovery.",
            dailyData: hrvData.sorted { $0.date < $1.date },
            deltaFromAverage: hrvDelta,
            isPositiveDelta: hrvDelta > 0 // For HRV, higher is better
        )
        
        self._sleepMetric = MetricScore(
            score: Int(sleepValue * 100 / 8), // Around 65%
            title: "Sleep Duration",
            description: "You slept \(String(format: "%.1f", abs(sleepDelta))) hours less than your average, which may impact your recovery.",
            dailyData: sleepData.sorted { $0.date < $1.date },
            deltaFromAverage: sleepDelta,
            isPositiveDelta: sleepDelta > 0 // For sleep, more is better
        )
        
        self._sleepQualityMetric = MetricScore(
            score: Int(sleepQualityValue), // Around 55
            title: "Sleep Quality",
            description: "Your sleep quality is \(String(format: "%.0f", abs(sleepQualityDelta))) points lower than your average, suggesting disrupted sleep patterns.",
            dailyData: sleepQualityData.sorted { $0.date < $1.date },
            deltaFromAverage: sleepQualityDelta,
            isPositiveDelta: sleepQualityDelta > 0 // For sleep quality, higher is better
        )
        
        // Training load - generate a pattern that shows high load compared to 4-week average
        var trainingLoadData: [RecoveryMetricData] = []
        
        // Training load values based on duration * intensity
        // High durations and intensities represent an overreaching scenario
        let durations = [90.0, 75.0, 120.0, 60.0, 105.0, 45.0, 90.0] // Duration in minutes (high values)
        let intensityFactors = [2.5, 2.0, 3.0, 1.5, 3.0, 2.0, 2.5] // Intensity factors (moderate to high)
        
        // Calculate daily training load values as duration * intensity
        var trainingLoadValues: [Double] = []
        for i in 0..<7 {
            trainingLoadValues.append(durations[i] * intensityFactors[i])
        }
        
        // Generate daily data for the last 7 days
        for day in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -day, to: Date())!
            trainingLoadData.append(RecoveryMetricData(date: date, value: trainingLoadValues[day]))
        }
        
        // Calculate current week's average
        let currentWeekAvg = trainingLoadValues.reduce(0.0, +) / Double(trainingLoadValues.count)
        
        // Simulate a 4-week average (much lower to show excessive increase)
        let fourWeekAvg = currentWeekAvg - 75
        
        // Calculate delta and percent change
        let trainingLoadDelta = currentWeekAvg - fourWeekAvg
        let percentChange = fourWeekAvg > 0 ? (trainingLoadDelta / fourWeekAvg) * 100 : 50
        
        // Calculate a score (0-100) that reflects how optimal the training load is
        // Perfect training load is a moderate increase (5-15% over 4-week average)
        // Too much increase (>20%) is bad, too little or negative is suboptimal
        let _: Int = 0 // This is a dummy value, we're not using it
        
        // Create description based on the comparison
        let description: String
        if percentChange > 25 {
            description = "Your training load is \(String(format: "%.0f", trainingLoadDelta)) points (\(String(format: "%.0f", percentChange))%) higher than your 4-week average, suggesting a significant increase in workload. Consider implementing a recovery week soon."
        } else if percentChange > 10 {
            description = "Your training load is \(String(format: "%.0f", trainingLoadDelta)) points (\(String(format: "%.0f", percentChange))%) higher than your 4-week average, indicating a moderate progression in training volume."
        } else if percentChange >= -5 {
            description = "Your training load is similar to your 4-week average, showing consistent training patterns."
        } else {
            description = "Your training load is \(String(format: "%.0f", abs(trainingLoadDelta))) points (\(String(format: "%.0f", abs(percentChange)))%) lower than your 4-week average, showing a reduction in training volume."
        }
        
        // Calculate recovery score - poor overall score
        let poorRecoveryScore = RecoveryScore(
            date: Date(),
            overallScore: 45, // Poor recovery score
            heartRateScore: _heartRateMetric ?? MetricScore.sampleHeartRate,
            hrvScore: _hrvMetric?.score ?? 0,
            sleepScore: _sleepMetric?.score ?? 0,
            trainingLoadScore: MetricScore(
                score: Int(currentWeekAvg),
                title: "Training Load",
                description: description,
                dailyData: trainingLoadData.sorted { $0.date < $1.date },
                deltaFromAverage: trainingLoadDelta,
                isPositiveDelta: false // Excessive increase is not positive
            ),
            stressScore: 35
        )
        
        self.currentRecoveryScore = poorRecoveryScore
    }
    
    static func scoreDescription(for score: RecoveryScore) -> String {
        switch score.overallScore {
        case 0..<40:
            return "Highly stressed. Focus on recovery today."
        case 40..<60:
            return "Somewhat fatigued. Consider light activity."
        case 60..<80:
            return "Reasonably recovered. Moderate training is fine."
        default:
            return "Well recovered. Ready for intense training."
        }
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
        let description: String
        if score >= 75 {
            description = "Your HRV score indicates good recovery and stress management."
        } else if score >= 60 {
            description = "Your HRV score indicates moderate recovery state."
        } else if score >= 40 {
            description = "Your lower HRV score suggests higher stress and reduced recovery."
        } else {
            description = "Your HRV is significantly reduced, indicating poor recovery and high stress levels."
        }
        
        return MetricScore(
            score: score,
            title: "Heart Rate Variability",
            description: description,
            dailyData: [], // You might want to populate this with actual data
            deltaFromAverage: 0,
            isPositiveDelta: score >= 60
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
            description: "Your HRV is 5 ms higher than your 7-day average, indicating better recovery and less stress.",
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
        // Create a pattern that shows consistent training with reasonable variations
        let now = Date()
        let calendar = Calendar.current
        
        // Create more realistic daily load values - these now represent duration * intensity
        var dailyData: [RecoveryMetricData] = []
        
        // Duration (in minutes) * intensity factors for last 7 days
        // Each value represents: daily workout duration * intensity factor
        let durations = [45.0, 30.0, 60.0, 40.0, 75.0, 30.0, 50.0] // Duration in minutes
        let intensityFactors = [2.0, 1.0, 2.5, 1.5, 3.0, 1.0, 2.0] // Intensity factors
        
        // Calculate daily training load values as duration * intensity
        var dailyValues: [Double] = []
        for i in 0..<7 {
            dailyValues.append(durations[i] * intensityFactors[i])
        }
        
        // Generate daily data for the last 7 days
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            dailyData.append(RecoveryMetricData(date: date, value: dailyValues[day]))
        }
        
        // Calculate current week's average
        let currentWeekAvg = dailyValues.reduce(0.0, +) / Double(dailyValues.count)
        
        // Simulate a 4-week average (slightly lower to show an increasing trend)
        let fourWeekAvg = currentWeekAvg - 10
        
        // Calculate the delta between weekly average and 4-week average
        let delta = currentWeekAvg - fourWeekAvg
        
        // Calculate percentage change from 4-week average
        let percentChange = fourWeekAvg > 0 ? (delta / fourWeekAvg) * 100 : 0
        
        // Determine if the delta is positive (in training context, moderate increase is positive)
        // This is a complex assessment - moderate increases are positive, but excessive increases are not
        let isPositiveDelta = percentChange > 0 && percentChange <= 15 // Moderate increase is good
        
        // Calculate a score (0-100) that reflects how optimal the training load is
        // Perfect training load is a moderate increase (5-15% over 4-week average)
        // Too much increase (>20%) is bad, too little or negative is suboptimal
        let _: Int = 0 // This is a dummy value, we're not using it
        
        // Create description based on the comparison
        let description: String
        if percentChange > 25 {
            description = "Your training load is \(String(format: "%.0f", delta)) units (\(String(format: "%.0f", percentChange))%) higher than your 4-week average, suggesting a significant increase in workload. Consider implementing a recovery week soon."
        } else if percentChange > 10 {
            description = "Your training load is \(String(format: "%.0f", delta)) units (\(String(format: "%.0f", percentChange))%) higher than your 4-week average, indicating a moderate progression in training volume."
        } else if percentChange >= -5 {
            description = "Your training load is similar to your 4-week average, showing consistent training patterns."
        } else {
            description = "Your training load is \(String(format: "%.0f", abs(delta))) units (\(String(format: "%.0f", abs(percentChange)))%) lower than your 4-week average, showing a reduction in training volume."
        }
        
        return MetricScore(
            score: Int(currentWeekAvg),
            title: "Training Load",
            description: description,
            dailyData: dailyData.sorted { $0.date < $1.date },
            deltaFromAverage: delta,
            isPositiveDelta: isPositiveDelta
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

struct RecoveryMetricData: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    
    static func == (lhs: RecoveryMetricData, rhs: RecoveryMetricData) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.value == rhs.value
    }
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

// Add extension to Double to identify heart rate values
extension Double {
    var isHeartRate: Bool {
        // Heart rate values are typically between 40-100
        return self >= 40 && self <= 100
    }
}
