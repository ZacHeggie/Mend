import Foundation
import SwiftUI

/// Manages the cool-down period after activities, adjusting recovery scores based on workout intensity,
/// duration, and elapsed time since the workout.
class PostActivityCooldown {
    
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = PostActivityCooldown()
    
    /// Last processed activity to avoid duplicate processing
    public var lastProcessedActivityID: UUID?
    
    /// Last time when recovery score was affected by post-activity cool-down
    public var lastCooldownAdjustmentTime: Date?
    
    /// Recovery score adjustment due to recent activity (0-100 scale, where 0 means maximum reduction)
    private var currentCooldownAdjustment: Int = 100
    
    /// Stores the expected full recovery time for the most recent workout
    public var expectedRecoveryTime: TimeInterval = 0
    
    /// Cached data of historical recovery times by activity type and intensity
    private var historicalRecoveryData: [String: [ActivityIntensity: TimeInterval]] = [:]
    
    /// Cached similar activities for analysis
    private var similarActivitiesByType: [ActivityType: [Activity]] = [:]
    
    /// Set of activities that have already been processed
    /// This is used to ensure each activity only affects the recovery score once
    private var processedActivityIDs: Set<UUID> = []
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton
        Task {
            await analyzeHistoricalRecoveryData()
            
            // Load processed activities from UserDefaults if available
            loadProcessedActivities()
        }
    }
    
    // MARK: - Public Methods
    
    /// Processes a new activity and calculates its impact on recovery
    /// - Parameter activity: The activity to process
    /// - Returns: The recovery score adjustment (0-100, where 100 means no reduction)
    func processActivity(_ activity: Activity) -> Int {
        // Skip if we've already processed this activity
        if processedActivityIDs.contains(activity.id) {
            return currentCooldownAdjustment
        }
        
        // Calculate expected recovery time based on activity intensity and duration
        expectedRecoveryTime = calculateExpectedRecoveryTime(for: activity)
        
        // Calculate initial recovery score reduction
        let initialReduction = calculateInitialScoreReduction(for: activity)
        
        // Update state
        lastProcessedActivityID = activity.id
        lastCooldownAdjustmentTime = Date()
        currentCooldownAdjustment = 100 - initialReduction
        
        // Add to processed activities set and save
        processedActivityIDs.insert(activity.id)
        saveProcessedActivities()
        
        return currentCooldownAdjustment
    }
    
    /// Updates the recovery score adjustment based on elapsed time since activity
    /// - Returns: The current recovery score adjustment (0-100, where 100 means no reduction)
    func updateCooldownAdjustment() -> Int {
        guard let lastAdjustment = lastCooldownAdjustmentTime else {
            // No recent activity to recover from
            return 100
        }
        
        let elapsedTimeSinceActivity = Date().timeIntervalSince(lastAdjustment)
        
        // If we've fully recovered, reset and return 100 (no adjustment)
        if elapsedTimeSinceActivity >= expectedRecoveryTime {
            resetCooldown()
            return 100
        }
        
        // Calculate recovery progress (0.0 to 1.0)
        let recoveryProgress = elapsedTimeSinceActivity / expectedRecoveryTime
        
        // Recovery follows a curve that starts slow, accelerates in the middle, and tapers at the end
        // Using a modified sigmoid function for a more natural recovery progression
        let adjustedProgress = recoveryFunction(progress: recoveryProgress)
        
        // Calculate the new adjustment (starts at currentCooldownAdjustment and moves toward 100)
        let initialReduction = 100 - currentCooldownAdjustment
        let currentReduction = Int(Double(initialReduction) * (1.0 - adjustedProgress))
        
        // Calculate new adjustment - this will always be >= to currentCooldownAdjustment 
        // as time passes (guaranteeing monotonic recovery)
        let newAdjustment = 100 - currentReduction
        
        // Store the highest adjustment value to ensure recovery never decreases
        currentCooldownAdjustment = max(currentCooldownAdjustment, newAdjustment)
        
        return currentCooldownAdjustment
    }
    
    /// Gets the current cool-down state as a user-friendly description
    /// - Returns: A description of the current cool-down state
    func getCooldownDescription() -> String {
        guard currentCooldownAdjustment < 100, let lastAdjustment = lastCooldownAdjustmentTime else {
            return "Fully recovered"
        }
        
        let elapsedTime = Date().timeIntervalSince(lastAdjustment)
        let remainingTime = max(0, expectedRecoveryTime - elapsedTime)
        
        // Format remaining time
        if remainingTime < 3600 {
            // Less than 1 hour
            let minutes = Int(remainingTime / 60)
            return "Recovery in progress: \(minutes) min remaining"
        } else if remainingTime < 86400 {
            // Less than 1 day
            let hours = Int(remainingTime / 3600)
            return "Recovery in progress: \(hours) hr remaining"
        } else {
            // Days
            let days = Int(remainingTime / 86400)
            let hours = Int((remainingTime.truncatingRemainder(dividingBy: 86400)) / 3600)
            return "Recovery in progress: \(days)d \(hours)h remaining"
        }
    }
    
    /// Returns the percentage of recovery completed
    /// - Returns: Recovery percentage (0-100)
    func getRecoveryPercentage() -> Int {
        guard currentCooldownAdjustment < 100, let lastAdjustment = lastCooldownAdjustmentTime else {
            return 100
        }
        
        let elapsedTime = Date().timeIntervalSince(lastAdjustment)
        let progress = min(1.0, elapsedTime / expectedRecoveryTime)
        
        return Int(progress * 100)
    }
    
    /// Returns the remaining recovery time in days
    /// - Returns: Remaining recovery time in days
    func getRemainingRecoveryDays() -> Double {
        guard currentCooldownAdjustment < 100, let lastAdjustment = lastCooldownAdjustmentTime else {
            return 0
        }
        
        let elapsedTime = Date().timeIntervalSince(lastAdjustment)
        let remainingTime = max(0, expectedRecoveryTime - elapsedTime)
        
        // Convert seconds to days
        return remainingTime / 86400
    }
    
    // MARK: - Private Methods
    
    /// Analyzes historical activity data to determine typical recovery times
    /// This examines the past month of activities and how they affected recovery
    @MainActor
    private func analyzeHistoricalRecoveryData() async {
        let activityManager = ActivityManager.shared
        
        // Get activities from the past month
        let activities = await activityManager.getRecentActivities(days: 30)
        
        // Group activities by type
        let typeGroups = Dictionary(grouping: activities) { $0.type.rawValue }
        
        // For each activity type, analyze recovery time by intensity
        for (typeKey, typeActivities) in typeGroups {
            var intensityRecoveryTimes: [ActivityIntensity: [TimeInterval]] = [:]
            
            // Group by intensity
            let intensityGroups = Dictionary(grouping: typeActivities) { $0.intensity }
            
            // For each intensity, gather recovery times
            for (intensity, intensityActivities) in intensityGroups {
                // Analysis based on activity spacing and duration
                let recoveryTimes = calculateRecoveryTimesFromActivitySpacing(intensityActivities)
                intensityRecoveryTimes[intensity] = recoveryTimes
            }
            
            // Calculate average recovery time for each intensity
            var averageRecoveryByIntensity: [ActivityIntensity: TimeInterval] = [:]
            
            for (intensity, times) in intensityRecoveryTimes {
                if !times.isEmpty {
                    let averageTime = times.reduce(0, +) / Double(times.count)
                    averageRecoveryByIntensity[intensity] = averageTime
                }
            }
            
            historicalRecoveryData[typeKey] = averageRecoveryByIntensity
        }
        
        // Also cache similar activities by type for reuse
        for activity in activities {
            if similarActivitiesByType[activity.type] == nil {
                similarActivitiesByType[activity.type] = []
            }
            similarActivitiesByType[activity.type]?.append(activity)
        }
    }
    
    /// Calculate estimated recovery times based on spacing between similar activities
    private func calculateRecoveryTimesFromActivitySpacing(_ activities: [Activity]) -> [TimeInterval] {
        guard activities.count >= 2 else { return [] }
        
        // Sort activities by date (oldest first)
        let sortedActivities = activities.sorted { $0.date < $1.date }
        var recoveryTimes: [TimeInterval] = []
        
        // Look at gaps between activities of the same type
        for i in 0..<(sortedActivities.count - 1) {
            let current = sortedActivities[i]
            let next = sortedActivities[i + 1]
            
            // Calculate time between activities
            let timeBetween = next.date.timeIntervalSince(current.date)
            
            // Only consider reasonable recovery periods (between 8 hours and 7 days)
            // Less than 8 hours likely means activities in same day (not full recovery)
            // More than 7 days likely means gap in training, not actual recovery need
            if timeBetween >= 8 * 3600 && timeBetween <= 7 * 24 * 3600 {
                // Adjust for activity duration - longer activities need more recovery
                let durationFactor = sqrt(current.duration / 3600) // Square root scaling
                
                // Estimate actual recovery time needed
                let estimatedRecoveryTime = min(timeBetween, timeBetween * durationFactor)
                recoveryTimes.append(estimatedRecoveryTime)
            }
        }
        
        return recoveryTimes
    }
    
    /// Calculates the expected recovery time for an activity
    /// - Parameter activity: The activity to calculate recovery time for
    /// - Returns: Expected recovery time in seconds
    private func calculateExpectedRecoveryTime(for activity: Activity) -> TimeInterval {
        // Try to get historical data for this activity type and intensity
        if let typeData = historicalRecoveryData[activity.type.rawValue],
           let historicalRecoveryTime = typeData[activity.intensity] {
            // We have historical data - scale by duration
            let durationHours = activity.duration / 3600
            let durationScale = sqrt(durationHours / 1.0) // Square root scaling
            
            // Return the personalized recovery time based on user's history
            return historicalRecoveryTime * durationScale
        }
        
        // Fallback to default calculation if no historical data
        let durationHours = activity.duration / 3600
        
        // Base recovery factors by intensity (in hours)
        let intensityFactor: Double
        switch activity.intensity {
        case .low:
            intensityFactor = 8  // ~8 hours for low intensity
        case .moderate:
            intensityFactor = 24  // ~24 hours for moderate intensity
        case .high:
            intensityFactor = 36  // ~36 hours for high intensity
        }
        
        // Scale by duration - longer workouts need more recovery
        // Use a non-linear scaling to prevent extremely long recovery times
        let durationScale = sqrt(durationHours / 1.0)  // Square root scaling
        
        // Calculate recovery time in hours, then convert to seconds
        let recoveryTimeHours = intensityFactor * durationScale
        return recoveryTimeHours * 3600
    }
    
    /// Calculates the initial score reduction based on activity intensity and duration
    /// - Parameter activity: The activity to calculate for
    /// - Returns: Initial score reduction (0-100)
    private func calculateInitialScoreReduction(for activity: Activity) -> Int {
        // Try to analyze past activities of similar type/intensity from our cached data
        if let similarActivities = similarActivitiesByType[activity.type]?.filter({ $0.intensity == activity.intensity }),
           !similarActivities.isEmpty {
            
            // Calculate average duration for similar activities
            let averageDuration = similarActivities.reduce(0.0) { $0 + $1.duration } / Double(similarActivities.count)
            
            // Base reduction by intensity (personalized based on historical patterns)
            let baseReduction: Int
            switch activity.intensity {
            case .low:
                baseReduction = 5  // 5% reduction for low intensity
            case .moderate:
                baseReduction = 20  // 20% reduction for moderate intensity
            case .high:
                baseReduction = 35  // 35% reduction for high intensity
            }
            
            // Scale by relation to average duration
            // If this activity is longer than average, increase reduction
            let durationRatio = activity.duration / averageDuration
            let durationFactor = min(2.5, max(0.8, durationRatio)) // Between 0.8x and 2.5x
            
            // Calculate final reduction
            return min(80, Int(Double(baseReduction) * durationFactor))
        }
        
        // Fallback to default calculation if no similar activities
        let baseReduction: Int
        switch activity.intensity {
        case .low:
            baseReduction = 2  // 2% reduction for low intensity
        case .moderate:
            baseReduction = 15  // 15% reduction for moderate intensity
        case .high:
            baseReduction = 25  // 25% reduction for high intensity
        }
        
        // Scale by duration - longer workouts cause more initial fatigue
        let durationHours = activity.duration / 3600
        let durationFactor = min(2.5, 1.0 + (durationHours / 2.0))  // Cap at 2.5x for very long workouts
        
        // Calculate final reduction
        return min(80, Int(Double(baseReduction) * durationFactor))  // Cap at 80% to avoid extreme reductions
    }
    
    /// Recovery function that models how recovery progresses over time
    /// - Parameter progress: Raw linear progress (0.0 to 1.0)
    /// - Returns: Adjusted progress value following a recovery curve
    private func recoveryFunction(progress: Double) -> Double {
        // Modified sigmoid function that ensures recovery steadily increases over time
        // This gives a more natural recovery progression:
        // - Starts slower (initial recovery phase)
        // - Accelerates in the middle (primary recovery phase)
        // - Tapers at the end (final adaptation phase)
        
        // Make sure progress is constrained between 0 and 1
        let constrainedProgress = min(1.0, max(0.0, progress))
        
        // Apply sigmoid transformation for a natural recovery curve
        // This function guarantees monotonic increase (recovery always improves, never declines)
        return 1.0 / (1.0 + exp(-12 * (constrainedProgress - 0.5)))
    }
    
    /// Resets the cooldown state
    private func resetCooldown() {
        currentCooldownAdjustment = 100
        lastCooldownAdjustmentTime = nil
        expectedRecoveryTime = 0
    }
    
    /// Saves the list of processed activity IDs to UserDefaults
    private func saveProcessedActivities() {
        let processedIDs = processedActivityIDs.map { $0.uuidString }
        UserDefaults.standard.set(processedIDs, forKey: "processedActivityIDs")
    }
    
    /// Loads the list of processed activity IDs from UserDefaults
    private func loadProcessedActivities() {
        guard let savedIDs = UserDefaults.standard.array(forKey: "processedActivityIDs") as? [String] else {
            return
        }
        
        // Convert strings back to UUIDs
        processedActivityIDs = Set(savedIDs.compactMap { UUID(uuidString: $0) })
    }
    
    /// Cleans up old processed activities that are no longer relevant
    /// This should be called periodically to prevent the set from growing too large
    func cleanupOldProcessedActivities(olderThan days: Int = 60) {
        // This would typically remove activities older than the specified period
        // But since we don't store dates with the IDs, we'll just keep this as a placeholder
        // In a real implementation, you might want to store activity IDs with dates
        
        // For now, we'll just cap the size of the set to prevent unbounded growth
        if processedActivityIDs.count > 1000 {
            // Just reset if we get too many
            processedActivityIDs = []
            saveProcessedActivities()
        }
    }
    
    /// Resets all processed activities - used for testing
    func resetAllProcessedActivities() {
        processedActivityIDs = []
        saveProcessedActivities()
        
        // Also reset cooldown state
        resetCooldown()
    }
} 
