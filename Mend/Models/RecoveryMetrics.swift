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
    private let activityManager = ActivityManager.shared
    
    @Published var currentRecoveryScore: RecoveryScore?
    @Published var isLoading = true // Start with loading state as true
    @Published var error: Error?
    @Published var useSimulatedData = false
    @Published var usePoorRecoveryData = false
    
    // Keep cool-down related UI properties even though we're removing the actual functionality
    // This ensures the UI remains consistent
    @Published var isInCooldown: Bool = false
    @Published var cooldownPercentage: Int = 100
    @Published var cooldownDescription: String = "Fully recovered"
    
    // Track if initial data load is complete
    @Published var isInitialLoadComplete = false
    
    /// Returns the remaining recovery time in days
    func getRemainingRecoveryDays() -> Double {
        // Always return 0 as we're removing cool-down functionality
        return 0
    }
    
    private init() {
        // Reset currentRecoveryScore to ensure we don't show stale data
        currentRecoveryScore = nil
        isLoading = true
        isInitialLoadComplete = false
        
        // Setup initial data load
        Task { 
            do {
                try await healthKit.requestAuthorization()
                
                // Perform initial data load without cool-down calculation
                await performInitialDataLoad()
                
                // Mark initial load as complete
                isInitialLoadComplete = true
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    // MARK: - Initial Data Loading
    
    /// Performs the initial data load when the app first launches
    private func performInitialDataLoad() async {
        isLoading = true
        
        // Load health data (either from HealthKit or simulated)
        await loadHealthKitData()
        
        // Set default values for UI properties
        isInCooldown = false
        cooldownPercentage = 100
        cooldownDescription = "Fully recovered"
        
        // Finish loading
        isLoading = false
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
        async let restingHeartRateDailyData = healthKit.fetchDailyRestingHeartRateData(forDays: 28)
        async let hrvDailyData = healthKit.fetchDailyHRVData(forDays: 28)
        async let sleepDailyData = healthKit.fetchDailySleepData(forDays: 28)
        async let sleepQualityDailyData = healthKit.fetchDailySleepQualityData(forDays: 28)
        
        let (heartRateValue, hrvValue, sleepData, heartRateMetrics, hrvMetrics, sleepMetrics, sleepQualityMetrics) = 
            await (restingHeartRate, hrv, sleep, restingHeartRateDailyData, hrvDailyData, sleepDailyData, sleepQualityDailyData)
        
        // Extract sleep values
        let sleepValue = sleepData?.hours
        let sleepQualityValue = sleepData?.quality
        let sleepStages = sleepData?.stages
        
        // Mark each metrics collection with appropriate type
        // Since our new detection system has overlap between heart rate and HRV values,
        // we'll tag them explicitly by creating new arrays with the correct type
        let taggedHRVMetrics = hrvMetrics.map { metric in
            // Create a new RecoveryMetricData with explicit HRV type
            return RecoveryMetricData(date: metric.date, value: metric.value, explicitType: .hrv)
        }
        
        // Calculate deltas from average if we have enough data points
        let heartRateDelta = calculateDelta(from: heartRateMetrics, currentValue: heartRateValue)
        let hrvDelta = calculateDelta(from: taggedHRVMetrics, currentValue: hrvValue)
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
            let avgHRV = taggedHRVMetrics.filter { !Calendar.current.isDateInToday($0.date) }
                .map { $0.value }
                .reduce(0, +) / Double(max(1, taggedHRVMetrics.filter { !Calendar.current.isDateInToday($0.date) }.count))
            
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
            
            // For HRV, higher is always better, so a positive delta is positive
            let isPositiveDelta = hrvDelta.delta > 0
            
            self._hrvMetric = MetricScore(
                score: calculatedScore,
                title: "Heart Rate Variability",
                description: getHRVDescription(currentHRV: hrvValue, delta: hrvDelta.delta),
                dailyData: taggedHRVMetrics,
                deltaFromAverage: hrvDelta.delta,
                isPositiveDelta: isPositiveDelta
            )
        }
        
        // Sleep Duration Metric - either use real data or create a fallback
        if let sleepValue = sleepValue, !sleepMetrics.isEmpty {
            // Create description with sleep stages if available
            let description: String
            if let sleepStages = sleepStages {
                let stagesInfo = getSleepStagesDescription(sleepStages: sleepStages)
                description = getSleepDescription(currentSleep: sleepValue, delta: sleepDelta.delta) + "\n\n" + stagesInfo
            } else {
                description = getSleepDescription(currentSleep: sleepValue, delta: sleepDelta.delta)
            }
            
            self._sleepMetric = MetricScore(
                score: Int(sleepValue * 100 / 8), // Convert to score out of 100 (8 hours = 100)
                title: "Sleep Duration",
                description: description,
                dailyData: sleepMetrics,
                deltaFromAverage: sleepDelta.delta,
                isPositiveDelta: sleepDelta.isPositive
            )
        } else if !sleepMetrics.isEmpty {
            // If we have daily data but no current value, use the most recent value as current
            let mostRecentValue = sleepMetrics.sorted(by: { $0.date > $1.date }).first?.value ?? 7.0
            let avgValue = sleepMetrics.map { $0.value }.reduce(0, +) / Double(sleepMetrics.count)
            let delta = mostRecentValue - avgValue
            
            self._sleepMetric = MetricScore(
                score: Int(mostRecentValue * 100 / 8), // Convert to score out of 100 (8 hours = 100)
                title: "Sleep Duration",
                description: getSleepDescription(currentSleep: mostRecentValue, delta: delta),
                dailyData: sleepMetrics,
                deltaFromAverage: delta,
                isPositiveDelta: delta > 0
            )
        } else {
            // Create fallback sleep metric if we have no data at all
            self._sleepMetric = MetricScore.sampleSleep
        }
        
        // Sleep Quality Metric - either use real data or create a fallback
        if let sleepQualityValue = sleepQualityValue, !sleepQualityMetrics.isEmpty {
            self._sleepQualityMetric = MetricScore(
                score: Int(sleepQualityValue),
                title: "Sleep Quality",
                description: getSleepQualityDescription(currentSleepQuality: sleepQualityValue, delta: sleepQualityDelta.delta),
                dailyData: sleepQualityMetrics,
                deltaFromAverage: sleepQualityDelta.delta,
                isPositiveDelta: sleepQualityDelta.isPositive
            )
        } else if !sleepQualityMetrics.isEmpty {
            // If we have daily data but no current value, use the most recent value as current
            let mostRecentValue = sleepQualityMetrics.sorted(by: { $0.date > $1.date }).first?.value ?? 75.0
            let avgValue = sleepQualityMetrics.map { $0.value }.reduce(0, +) / Double(sleepQualityMetrics.count)
            let delta = mostRecentValue - avgValue
            
            self._sleepQualityMetric = MetricScore(
                score: Int(mostRecentValue),
                title: "Sleep Quality",
                description: getSleepQualityDescription(currentSleepQuality: mostRecentValue, delta: delta),
                dailyData: sleepQualityMetrics,
                deltaFromAverage: delta,
                isPositiveDelta: delta > 0
            )
        } else {
            // Create fallback sleep quality metric if we have no data at all
            self._sleepQualityMetric = MetricScore.sampleSleepQuality
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
        
        // Only use valid data points for the average calculation
        let validMetrics: [RecoveryMetricData]
        
        // For sleep metrics, ensure we only include realistic sleep durations (at least 2 hours)
        if let firstMetric = metrics.first, firstMetric.metricType == .sleep {
            validMetrics = previousMetrics.filter { $0.value >= 2.0 }
        } else if let firstMetric = metrics.first, firstMetric.metricType == .sleepQuality {
            validMetrics = previousMetrics.filter { $0.value > 0 }
        } else if let firstMetric = metrics.first, firstMetric.metricType == .heartRate {
            validMetrics = previousMetrics.filter { $0.value >= 30 && $0.value <= 120 }
        } else if let firstMetric = metrics.first, firstMetric.metricType == .hrv {
            validMetrics = previousMetrics.filter { $0.value > 0 && $0.value <= 200 }
        } else {
            validMetrics = previousMetrics.filter { $0.value > 0 }
        }
        
        // If there are no valid metrics after filtering, return no delta
        guard validMetrics.count > 0 else {
            return (0, true)
        }
        
        let average = validMetrics.map { $0.value }.reduce(0, +) / Double(validMetrics.count)
        let delta = currentValue - average
        
        // For heart rate, lower is better (negative delta is positive)
        // For HRV and sleep, higher is better (positive delta is positive)
        let isPositive: Bool
        
        // Determine metric type from the context, not just the value range
        if let firstMetric = metrics.first {
            switch firstMetric.metricType {
            case .heartRate:
                // For heart rate, lower is better, so negative delta is positive
                isPositive = delta < 0
            case .hrv:
                // For HRV, higher is better, so positive delta is positive
                isPositive = delta > 0
            default:
                // For sleep, quality scores, etc., higher is generally better
                isPositive = delta > 0
            }
        } else {
            // Default behavior if metric type can't be determined
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
    
    private func getSleepStagesDescription(sleepStages: SleepStages) -> String {
        let formattedDeep = String(format: "%.0f", sleepStages.deep)
        let formattedREM = String(format: "%.0f", sleepStages.rem)
        let formattedCore = String(format: "%.0f", sleepStages.core)
        let _ = String(format: "%.0f", sleepStages.unspecified)
        
        let baseDescription = "Sleep stages breakdown: \(formattedDeep)% deep sleep, \(formattedREM)% REM sleep, \(formattedCore)% light sleep"
        
        // Assess sleep stage quality
        let deepRemPercentage = sleepStages.deep + sleepStages.rem
        
        if deepRemPercentage >= 40 {
            return baseDescription + ". Your deep and REM sleep percentages are excellent, which is optimal for physical recovery and cognitive function."
        } else if deepRemPercentage >= 30 {
            return baseDescription + ". Your deep and REM sleep percentages are very good, supporting efficient recovery and mental performance."
        } else if deepRemPercentage >= 20 {
            return baseDescription + ". Your deep and REM sleep percentages are adequate for basic recovery functions."
        } else {
            return baseDescription + ". Your deep and REM sleep percentages are lower than optimal, which may affect recovery and cognitive performance."
        }
    }
    
    // Public methods for creating metrics
    func createHRVMetric() -> MetricScore {
        return _hrvMetric ?? MetricScore.sampleHRV
    }
    
    func createSleepMetric() -> MetricScore {
        return _sleepMetric ?? MetricScore(
            score: 0,
            title: "Sleep Duration",
            description: "No sleep data available",
            dailyData: [],
            deltaFromAverage: 0,
            isPositiveDelta: true
        )
    }
    
    func createSleepQualityMetric() -> MetricScore {
        return _sleepQualityMetric ?? MetricScore(
            score: 0,
            title: "Sleep Quality",
            description: "No sleep quality data available",
            dailyData: [],
            deltaFromAverage: 0,
            isPositiveDelta: true
        )
    }
    
    @MainActor
    private func updateRecoveryScore() {
        // Calculate overall score based on available metrics with weighted importance
        var weightedTotal = 0
        var totalWeight = 0
        
        // Constants for weighting different metrics based on order of importance
        let hrvWeight = 5        // HRV is most important
        let heartRateWeight = 4  // Resting heart rate is second most important
        let sleepWeight = 2      // Sleep duration is fourth most important
        let sleepQualityWeight = 3 // Sleep quality is third most important
        let trainingLoadWeight = 2 // Training load is fifth most important
        
        // Get training load data for past week compared to 28-day average
        let trainingLoadScore = calculateTrainingLoadScore()
        
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
        
        // Add training load score
        weightedTotal += trainingLoadScore * trainingLoadWeight
        totalWeight += trainingLoadWeight
        
        let overallScore = totalWeight > 0 ? weightedTotal / totalWeight : 0
        
        // Create recovery score object
        currentRecoveryScore = RecoveryScore(
            date: Date(),
            overallScore: overallScore,
            heartRateScore: _heartRateMetric ?? MetricScore.sampleHeartRate,
            hrvScore: _hrvMetric?.score ?? 0,
            sleepScore: _sleepMetric?.score ?? 0,
            trainingLoadScore: MetricScore(
                score: trainingLoadScore,
                title: "Training Load",
                description: getTrainingLoadDescription(score: trainingLoadScore),
                dailyData: [],
                deltaFromAverage: 0,
                isPositiveDelta: true
            ),
            stressScore: 75
        )
    }
    
    /// Calculates training load score by comparing past week to 28-day average
    private func calculateTrainingLoadScore() -> Int {
        let activityManager = ActivityManager.shared
        
        // Get 7-day training load
        let weekLoad = activityManager.calculateTrainingLoad(forDays: 7)
        
        // Get 28-day training load and calculate the average weekly load
        let monthLoad = activityManager.calculateTrainingLoad(forDays: 28)
        
        // Use actual available weeks for a more accurate average
        let availableWeeks = min(4, max(1, 28 / 7))
        let avgWeeklyLoad = monthLoad / availableWeeks
        
        // If there's no historical training load, return a default score
        if avgWeeklyLoad == 0 {
            return 75 // Default neutral score
        }
        
        // Calculate ratio of current week to average (1.0 means equal)
        let loadRatio = Double(weekLoad) / Double(max(1, avgWeeklyLoad))
        
        // Optimal range is 0.8-1.2 of average weekly load
        // Too little training (< 0.5) or too much (> 1.5) both reduce score
        let score: Int
        
        if loadRatio < 0.5 {
            // Too little training
            score = 60 + Int(min(30, loadRatio * 60)) // 60-90 range for very low training
        } else if loadRatio <= 0.8 {
            // Slightly below optimal but still good
            score = 90 + Int(min(5, (loadRatio - 0.5) * 50)) // 90-95 range
        } else if loadRatio <= 1.2 {
            // Optimal training load
            score = 95 + Int(min(5, (1.0 - abs(loadRatio - 1.0)) * 10)) // 95-100 range, 100 at perfect 1.0
        } else if loadRatio <= 1.5 {
            // Slightly above optimal
            score = 80 + Int(min(15, (1.5 - loadRatio) * 50)) // 80-95 range
        } else {
            // Too much training (overtraining)
            score = 60 + Int(min(20, (2.0 - loadRatio) * 50)) // 60-80 range for high load
        }
        
        return score
    }
    
    /// Gets description for training load based on score
    private func getTrainingLoadDescription(score: Int) -> String {
        if score >= 95 {
            return "Your training load is optimal relative to your 28-day average. This balanced approach promotes recovery and adaptation."
        } else if score >= 80 {
            return "Your training load is slightly off your optimal range compared to your 28-day average, but still supporting good recovery."
        } else if score >= 60 {
            return "Your training load is considerably different from your 28-day average. This may impact recovery and adaptation."
        } else {
            return "Your training load shows a significant imbalance compared to your normal patterns. Consider adjusting your training schedule."
        }
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
    
    /// Refreshes data with a complete reset
    @MainActor
    func refreshWithReset() async {
        isLoading = true
        
        // Load metrics data from HealthKit or simulated data
        await loadHealthKitData()
        
        // Set default values for UI properties
        isInCooldown = false
        cooldownPercentage = 100
        cooldownDescription = "Fully recovered"
        
        // Finish loading
        isLoading = false
    }
    
    private func loadNormalSimulatedData() {
        // Generate daily data for the last 28 days
        let calendar = Calendar.current
        let now = Date()
        
        // Create simulated heart rate data
        let heartRateValue = 58.0
        var heartRateData: [RecoveryMetricData] = []
        for day in 0..<28 {
            let date = calendar.date(byAdding: .day, value: -day, to: now)!
            // Simulate slight daily variations
            let variation = Double.random(in: -5...5)
            let value = max(55, min(75, heartRateValue + variation)) // keep within realistic range
            heartRateData.append(RecoveryMetricData(date: date, value: value))
        }
        
        // Create simulated HRV data
        let hrvValue = 65.0
        var hrvData: [RecoveryMetricData] = []
        for day in 0..<28 {
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
        for day in 0..<28 {
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
        
        // Initialize simulated sleep data
        let sleepStages = SleepStages.sample
        
        // Create sleep metric with stages information included
        let sleepStagesInfo = getSleepStagesDescription(sleepStages: sleepStages)
        let sleepDesc = self._sleepMetric?.description ?? "No sleep data available"
        self._sleepMetric = MetricScore(
            score: self._sleepMetric?.score ?? 75,
            title: "Sleep Duration",
            description: sleepDesc + "\n\n" + sleepStagesInfo,
            dailyData: self._sleepMetric?.dailyData ?? [],
            deltaFromAverage: self._sleepMetric?.deltaFromAverage ?? 0,
            isPositiveDelta: self._sleepMetric?.isPositiveDelta ?? true
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
        
        // Simulate poor sleep quality and stages
        let sleepStages = SleepStages(deep: 12, rem: 18, core: 60, unspecified: 10)
        
        // Update sleep metric with stages information included
        let sleepStagesInfo = getSleepStagesDescription(sleepStages: sleepStages)
        let sleepDesc = self._sleepMetric?.description ?? "No sleep data available"
        self._sleepMetric = MetricScore(
            score: self._sleepMetric?.score ?? 65,
            title: "Sleep Duration",
            description: sleepDesc + "\n\n" + sleepStagesInfo,
            dailyData: self._sleepMetric?.dailyData ?? [],
            deltaFromAverage: self._sleepMetric?.deltaFromAverage ?? 0,
            isPositiveDelta: self._sleepMetric?.isPositiveDelta ?? false
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
            description = "Your training load is \(String(format: "%.0f", trainingLoadDelta)) points (\(String(format: "%.0f", percentChange))%) higher than your 28-day average, suggesting a significant increase in workload. Consider implementing a recovery week soon."
        } else if percentChange > 10 {
            description = "Your training load is \(String(format: "%.0f", trainingLoadDelta)) points (\(String(format: "%.0f", percentChange))%) higher than your 28-day average, indicating a moderate progression in training volume."
        } else if percentChange >= -5 {
            description = "Your training load is similar to your 28-day average, showing consistent training patterns."
        } else {
            description = "Your training load is \(String(format: "%.0f", abs(trainingLoadDelta))) points (\(String(format: "%.0f", abs(percentChange)))%) lower than your 28-day average, showing a reduction in training volume."
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
            description: "Your resting heart rate is 3 BPM lower than your 28-day average, which is a positive sign of recovery.",
            dailyData: [
                RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 62, explicitType: .heartRate),
                RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 65, explicitType: .heartRate),
                RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 64, explicitType: .heartRate),
                RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 67, explicitType: .heartRate),
                RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 66, explicitType: .heartRate),
                RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 65, explicitType: .heartRate),
                RecoveryMetricData(date: Date(), value: 59, explicitType: .heartRate)
            ],
            deltaFromAverage: 3.0,
            isPositiveDelta: true
        )
    }
    
    static var sampleHRV: MetricScore {
        MetricScore(
            score: 76,
            title: "Heart Rate Variability",
            description: "Your HRV is 5 ms higher than your 28-day average, indicating better recovery and less stress.",
            dailyData: [
                RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 58, explicitType: .hrv),
                RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 55, explicitType: .hrv),
                RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 54, explicitType: .hrv),
                RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 59, explicitType: .hrv),
                RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 62, explicitType: .hrv),
                RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 63, explicitType: .hrv),
                RecoveryMetricData(date: Date(), value: 67, explicitType: .hrv)
            ],
            deltaFromAverage: 5.0,
            isPositiveDelta: true
        )
    }
    
    static var sampleSleep: MetricScore {
        MetricScore(
            score: 82,
            title: "Sleep Duration",
            description: "Sleep duration of 6.5 hours. Adequate sleep (7-9 hours) is essential for physical recovery, cognitive function, and overall health. Try to increase your sleep duration for better recovery.",
            dailyData: [
                RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 7.2, explicitType: .sleep),
                RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 6.8, explicitType: .sleep),
                RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 7.0, explicitType: .sleep),
                RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 6.5, explicitType: .sleep),
                RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 7.5, explicitType: .sleep),
                RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 6.9, explicitType: .sleep),
                RecoveryMetricData(date: Date(), value: 6.5, explicitType: .sleep)
            ],
            deltaFromAverage: -0.5,
            isPositiveDelta: false
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
            description = "Your training load is \(String(format: "%.0f", delta)) units (\(String(format: "%.0f", percentChange))%) higher than your 28-day average, suggesting a significant increase in workload. Consider implementing a recovery week soon."
        } else if percentChange > 10 {
            description = "Your training load is \(String(format: "%.0f", delta)) units (\(String(format: "%.0f", percentChange))%) higher than your 28-day average, indicating a moderate progression in training volume."
        } else if percentChange >= -5 {
            description = "Your training load is similar to your 28-day average, showing consistent training patterns."
        } else {
            description = "Your training load is \(String(format: "%.0f", abs(delta))) units (\(String(format: "%.0f", abs(percentChange)))%) lower than your 28-day average, showing a reduction in training volume."
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
                RecoveryMetricData(date: Date().addingTimeInterval(-6 * 86400), value: 78, explicitType: .sleepQuality),
                RecoveryMetricData(date: Date().addingTimeInterval(-5 * 86400), value: 75, explicitType: .sleepQuality),
                RecoveryMetricData(date: Date().addingTimeInterval(-4 * 86400), value: 70, explicitType: .sleepQuality),
                RecoveryMetricData(date: Date().addingTimeInterval(-3 * 86400), value: 75, explicitType: .sleepQuality),
                RecoveryMetricData(date: Date().addingTimeInterval(-2 * 86400), value: 80, explicitType: .sleepQuality),
                RecoveryMetricData(date: Date().addingTimeInterval(-1 * 86400), value: 79, explicitType: .sleepQuality),
                RecoveryMetricData(date: Date(), value: 83, explicitType: .sleepQuality)
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
    let explicitType: MetricType
    
    init(date: Date, value: Double, explicitType: MetricType = .other) {
        self.date = date
        self.value = value
        self.explicitType = explicitType
    }
    
    static func == (lhs: RecoveryMetricData, rhs: RecoveryMetricData) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.value == rhs.value && lhs.explicitType == rhs.explicitType
    }
    
    enum MetricType {
        case heartRate
        case hrv
        case sleep
        case sleepQuality
        case other
    }
    
    var metricType: MetricType {
        // Use explicit type if provided, otherwise infer from value
        if explicitType != .other {
            return explicitType
        }
        
        // Try to infer the metric type based on values and context
        if self.value >= 40 && self.value <= 100 {
            return .heartRate // Most likely heart rate
        } else if self.value >= 20 && self.value <= 200 {
            return .hrv // Likely HRV (though there's overlap with HR ranges)
        } else if self.value > 0 && self.value < 24 {
            return .sleep // Likely sleep hours
        } else if self.value > 0 && self.value <= 100 {
            return .sleepQuality // Likely sleep quality score (0-100)
        } else {
            return .other
        }
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
