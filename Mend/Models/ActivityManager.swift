import Foundation
import SwiftUI

@MainActor
class ActivityManager: ObservableObject, Sendable {
    static let shared = ActivityManager()
    
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var isLoading: Bool = false
    @Published var error: Error?
    
    private let healthKitManager = HealthKitManager.shared
    
    init() {
        loadInitialData()
    }
    
    /// Load initial activity data
    private func loadInitialData() {
        isLoading = true
        
        // Fetch data from HealthKit
        Task {
            await importActivitiesFromHealthKit()
            
            if self.activities.isEmpty {
                // If no HealthKit data, load sample data
                DispatchQueue.main.async {
                    self.activities = self.generateSampleActivities()
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Import activities from HealthKit
    @MainActor
    func importActivitiesFromHealthKit() async {
        do {
            // Request HealthKit authorization
            try await healthKitManager.requestAuthorization()
            
            // Fetch workouts
            let workouts = await healthKitManager.fetchWorkouts(limit: 50)
            
            if !workouts.isEmpty {
                // Merge new workouts with existing activities, avoiding duplicates
                let existingIDs = Set(activities.map { $0.title + $0.date.description })
                let newWorkouts = workouts.filter { !existingIDs.contains($0.title + $0.date.description) }
                
                // Add new workouts to the activities array
                activities.append(contentsOf: newWorkouts)
                
                // Sort by date (newest first)
                activities.sort { $0.date > $1.date }
            }
        } catch {
            self.error = error
            print("Error importing from HealthKit: \(error)")
        }
    }
    
    /// Refresh activities from HealthKit
    func refreshActivities() async {
        isLoading = true
        await importActivitiesFromHealthKit()
        isLoading = false
    }
    
    /// Calculate training load
    func calculateTrainingLoad(forDays days: Int = 7) -> Int {
        let recentActivities = getRecentActivities(days: days)
        
        // Use a more complex model to calculate training load that accounts for:
        // 1. Intensity (with more granular scaling)
        // 2. Duration (with exponential scaling for longer activities)
        // 3. Activity type weight (some activities are inherently more stressful)
        // 4. Recency (more recent activities contribute more to current load)
        
        var totalLoad = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for activity in recentActivities {
            // Base factors
            let durationInMinutes = activity.duration / 60
            
            // 1. Calculate intensity factor with more granular scaling
            let intensityFactor: Double
            switch activity.intensity {
            case .low:
                intensityFactor = 1.0
            case .moderate:
                intensityFactor = 2.5
            case .high:
                intensityFactor = 4.0
            }
            
            // 2. Apply exponential scaling for longer activities (fatigue accumulates non-linearly)
            let durationFactor: Double
            if durationInMinutes <= 30 {
                durationFactor = durationInMinutes / 30.0
            } else if durationInMinutes <= 60 {
                durationFactor = 1.0 + (durationInMinutes - 30) / 60.0
            } else {
                durationFactor = 1.5 + (durationInMinutes - 60) / 40.0
            }
            
            // 3. Apply activity type weight
            let activityTypeFactor: Double
            switch activity.type {
            case .run:
                activityTypeFactor = 1.2  // Higher impact
            case .ride:
                activityTypeFactor = 1.0  // Moderate impact
            case .swim:
                activityTypeFactor = 0.8  // Low impact
            case .walk:
                activityTypeFactor = 0.5  // Very low impact
            case .workout:
                activityTypeFactor = 1.1  // Depends on the workout, but generally moderate-high impact
            case .other:
                activityTypeFactor = 1.0  // Default
            }
            
            // 4. Apply recency factor (more recent activities have higher impact)
            let daysSinceActivity = calendar.dateComponents([.day], from: calendar.startOfDay(for: activity.date), to: today).day ?? 0
            let recencyFactor = max(0.7, 1.0 - (Double(daysSinceActivity) * 0.05))  // Decay of 5% per day, minimum 70%
            
            // Calculate load points for this activity
            let activityLoad = Int(durationInMinutes * intensityFactor * durationFactor * activityTypeFactor * recencyFactor)
            
            // Add to total
            totalLoad += activityLoad
        }
        
        return totalLoad
    }
    
    /// Calculate daily training volumes for the past week
    func calculateDailyTrainingVolumes(forDays days: Int = 7) -> [DailyTrainingVolume] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var volumes: [DailyTrainingVolume] = []
        
        // Create a dictionary of activities grouped by day
        let dailyActivities = activitiesByDay(days: days)
        
        // Generate data for each day
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let activitiesForDay = dailyActivities[date] ?? []
            
            // Calculate total duration in minutes
            let totalDuration = activitiesForDay.reduce(0) { $0 + $1.duration } / 60
            
            // Calculate weighted intensity (higher intensity activities contribute more)
            var weightedIntensity = 0.0
            var totalWeight = 0.0
            
            for activity in activitiesForDay {
                let weight = activity.duration / 60 // Weight by duration in minutes
                let intensityValue: Double
                
                switch activity.intensity {
                case .low: intensityValue = 1.0
                case .moderate: intensityValue = 2.0
                case .high: intensityValue = 3.0
                }
                
                weightedIntensity += intensityValue * weight
                totalWeight += weight
            }
            
            let avgIntensity = totalWeight > 0 ? weightedIntensity / totalWeight : 0
            
            // Create volume object
            let volume = DailyTrainingVolume(
                date: date,
                totalDurationMinutes: totalDuration,
                averageIntensity: avgIntensity,
                activityCount: activitiesForDay.count
            )
            
            volumes.append(volume)
        }
        
        return volumes.sorted { $0.date < $1.date }
    }
    
    // Get activities from the past week
    func getRecentActivities(days: Int = 7) -> [Activity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pastDate = calendar.date(byAdding: .day, value: -days, to: today)!
        
        return activities.filter { activity in
            return activity.date >= pastDate
        }.sorted { $0.date > $1.date } // Sort by most recent first
    }
    
    // Get activities grouped by day
    func activitiesByDay(days: Int = 7) -> [Date: [Activity]] {
        let recentActivities = getRecentActivities(days: days)
        
        return Dictionary(grouping: recentActivities) { activity in
            Calendar.current.startOfDay(for: activity.date)
        }
    }
    
    // Filter activities by type
    func getActivities(ofType type: ActivityType? = nil) -> [Activity] {
        if let type = type {
            return activities.filter { $0.type == type }
        } else {
            return activities
        }
    }
    
    // Add new activity
    func addActivity(_ activity: Activity) {
        activities.append(activity)
        // Sort activities by date - newest first
        activities.sort { $0.date > $1.date }
    }
    
    // Generate sample data if needed (fallback when no HealthKit data)
    private func generateSampleActivities() -> [Activity] {
        let calendar = Calendar.current
        let today = Date()
        
        let todayRun = Activity(
            id: UUID(),
            title: "Morning Run",
            type: .run,
            date: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today)!,
            duration: 1800, // 30 minutes
            distance: 5.2,
            intensity: .moderate,
            source: .healthKit
        )
        
        let yesterdayRide = Activity(
            id: UUID(),
            title: "Evening Ride",
            type: .ride,
            date: calendar.date(byAdding: .day, value: -1, to: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today)!)!,
            duration: 3600, // 60 minutes
            distance: 15.7,
            intensity: .high,
            source: .manual
        )
        
        let twoDaysAgoSwim = Activity(
            id: UUID(),
            title: "Pool Swim",
            type: .swim,
            date: calendar.date(byAdding: .day, value: -2, to: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)!)!,
            duration: 2700, // 45 minutes
            distance: 1.5,
            intensity: .high,
            source: .healthKit
        )
        
        let threeDaysAgoWorkout = Activity(
            id: UUID(),
            title: "Strength Training",
            type: .workout,
            date: calendar.date(byAdding: .day, value: -3, to: calendar.date(bySettingHour: 16, minute: 30, second: 0, of: today)!)!,
            duration: 3600, // 60 minutes
            distance: nil,
            intensity: .high,
            source: .manual
        )
        
        let fourDaysAgoWalk = Activity(
            id: UUID(),
            title: "Afternoon Walk",
            type: .walk,
            date: calendar.date(byAdding: .day, value: -4, to: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!)!,
            duration: 1800, // 30 minutes
            distance: 2.3,
            intensity: .low,
            source: .healthKit
        )
        
        let lastWeekRun = Activity(
            id: UUID(),
            title: "Trail Run",
            type: .run,
            date: calendar.date(byAdding: .day, value: -7, to: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!)!,
            duration: 5400, // 90 minutes
            distance: 12.5,
            intensity: .high,
            source: .manual
        )
        
        return [todayRun, yesterdayRide, twoDaysAgoSwim, threeDaysAgoWorkout, fourDaysAgoWalk, lastWeekRun].sorted(by: { $0.date > $1.date })
    }
} 