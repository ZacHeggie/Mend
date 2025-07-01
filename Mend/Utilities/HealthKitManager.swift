import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    
    // The types of data we want to read from HealthKit
    let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.workoutType()
    ]
    
    private init() {}
    
    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
    
    // MARK: - Workout Methods
    
    func fetchWorkouts(limit: Int = 20) async -> [Activity] {
        // Define the predicate for the last 30 days
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        // Create the descriptor
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: limit
        )
        
        do {
            let workouts = try await descriptor.result(for: healthStore)
            return workouts.compactMap { workout in
                return createActivityFromWorkout(workout)
            }
        } catch {
            print("Error fetching workouts: \(error)")
            return []
        }
    }
    
    private func createActivityFromWorkout(_ workout: HKWorkout) -> Activity {
        // Map workout type to ActivityType
        let activityType = mapWorkoutTypeToActivityType(workout.workoutActivityType)
        
        // Create title based on workout type
        let title = getTitleForWorkoutType(workout.workoutActivityType)
        
        // Extract duration
        let duration = workout.duration
        
        // Extract distance
        var distance: Double? = nil
        if let distanceStats = workout.statistics(for: HKQuantityType(.distanceWalkingRunning)) {
            distance = distanceStats.sumQuantity()?.doubleValue(for: .meter())
            distance = distance != nil ? distance! / 1000 : nil // Convert to km
        } else if let distanceStats = workout.statistics(for: HKQuantityType(.distanceCycling)) {
            distance = distanceStats.sumQuantity()?.doubleValue(for: .meter())
            distance = distance != nil ? distance! / 1000 : nil // Convert to km
        } else if let distanceStats = workout.statistics(for: HKQuantityType(.distanceSwimming)) {
            distance = distanceStats.sumQuantity()?.doubleValue(for: .meter())
            distance = distance != nil ? distance! / 1000 : nil // Convert to km
        } else if let totalDistance = workout.totalDistance {
            distance = totalDistance.doubleValue(for: .meter()) / 1000 // Convert to km
        }
        
        // Extract elevation
        var elevation: Double? = nil
        // Note: HealthKit doesn't have a direct elevation identifier in older versions
        // We'll set elevation to nil for now and can add this in future updates
        // if let elevationStats = workout.statistics(for: HKQuantityType(.distanceElevationAscended)) {
        //     elevation = elevationStats.sumQuantity()?.doubleValue(for: HKUnit.meter())
        // }
        
        // Extract heart rate data
        var averageHeartRate: Double? = nil
        if let heartRateStats = workout.statistics(for: HKQuantityType(.heartRate)) {
            if let averageHR = heartRateStats.averageQuantity() {
                averageHeartRate = averageHR.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
        }
        
        // Determine intensity based on heart rate and duration
        let intensity = determineIntensityFromWorkout(workout)
        
        // Calculate training load score (simplified formula: duration in minutes * intensity factor)
        let durationMinutes = duration / 60
        let intensityFactor: Double
        switch intensity {
        case .low: intensityFactor = 1.0
        case .moderate: intensityFactor = 2.0
        case .high: intensityFactor = 3.0
        }
        // If we have heart rate data, use it to refine training load calculation
        let trainingLoadScore: Double
        if let hr = averageHeartRate {
            // Enhanced formula that considers heart rate: duration * intensity * (hr factor)
            let hrFactor = (hr / 100.0) // normalize around 100bpm
            trainingLoadScore = durationMinutes * intensityFactor * hrFactor
        } else {
            // Basic formula without heart rate
            trainingLoadScore = durationMinutes * intensityFactor
        }
        
        return Activity(
            id: UUID(),
            title: title,
            type: activityType,
            date: workout.startDate,
            duration: duration,
            distance: distance,
            intensity: intensity,
            source: .healthKit,
            averageHeartRate: averageHeartRate,
            trainingLoadScore: trainingLoadScore,
            elevation: elevation,
            lengths: nil // HealthKit doesn't typically provide lap/length data directly
        )
    }
    
    private func mapWorkoutTypeToActivityType(_ workoutType: HKWorkoutActivityType) -> ActivityType {
        switch workoutType {
        case .running:
            return .run
        case .cycling:
            return .ride
        case .swimming:
            return .swim
        case .walking:
            return .walk
        case .rowing:
            return .rowOutdoor
        case .traditionalStrengthTraining, .functionalStrengthTraining, .crossTraining:
            return .workout
        default:
            return .other
        }
    }
    
    private func getTitleForWorkoutType(_ workoutType: HKWorkoutActivityType) -> String {
        switch workoutType {
        case .running:
            return "Run"
        case .cycling:
            return "Bike Ride"
        case .swimming:
            return "Swim"
        case .walking:
            return "Walk"
        case .rowing:
            return "Outdoor Row"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .functionalStrengthTraining:
            return "Functional Training"
        case .crossTraining:
            return "Cross Training"
        case .yoga:
            return "Yoga"
        case .hiking:
            return "Hike"
        default:
            return "Workout"
        }
    }
    
    private func determineIntensityFromWorkout(_ workout: HKWorkout) -> ActivityIntensity {
        // Determine intensity based on:
        // 1. Heart rate if available
        // 2. Duration and calories as fallback
        
        // Get energy burned using statistics
        if let caloriesStats = workout.statistics(for: HKQuantityType(.activeEnergyBurned)),
           let energyBurned = caloriesStats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
            // Intensity based on calories per minute
            let caloriesPerMinute = energyBurned / (workout.duration / 60)
            
            if caloriesPerMinute > 10 {
                return .high
            } else if caloriesPerMinute > 5 {
                return .moderate
            } else {
                return .low
            }
        } else {
            // Fallback to duration-based intensity
            if workout.duration > 3600 { // More than 1 hour
                return .high
            } else if workout.duration > 1800 { // More than 30 minutes
                return .moderate
            } else {
                return .low
            }
        }
    }
    
    func fetchLatestHeartRateData() async -> Double? {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictEndDate
        )
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heartRateType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        
        do {
            let results = try await descriptor.result(for: healthStore)
            guard let latestSample = results.first else { return nil }
            return latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        } catch {
            print("Error fetching heart rate: \(error)")
            return nil
        }
    }
    
    func fetchLatestHRVData() async -> Double? {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictEndDate
        )
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrvType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        
        do {
            let results = try await descriptor.result(for: healthStore)
            guard let latestSample = results.first else { return nil }
            return latestSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
        } catch {
            print("Error fetching HRV: \(error)")
            return nil
        }
    }
    
    func fetchSleepData(forDate date: Date) async -> (hours: Double, quality: Double, stages: SleepStages)? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        
        do {
            let samples = try await descriptor.result(for: healthStore)
            
            // Check if we have any actual sleep samples
            guard !samples.isEmpty else {
                print("No sleep samples found for date \(date)")
                return nil
            }
            
            var totalSleepTime: TimeInterval = 0
            var deepSleepTime: TimeInterval = 0
            var remSleepTime: TimeInterval = 0
            var coreSleepTime: TimeInterval = 0
            var unspecifiedSleepTime: TimeInterval = 0
            var awakeTime: TimeInterval = 0
            var hasSleepData = false
            
            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                
                // Skip invalid samples with zero or negative duration
                guard duration > 0 else { continue }
                
                // Skip extremely short samples (less than 2 minutes)
                guard duration >= 120 else { continue }
                
                // Track actual sleep categories (not just "inBed")
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    totalSleepTime += duration
                    unspecifiedSleepTime += duration
                    hasSleepData = true
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    totalSleepTime += duration
                    coreSleepTime += duration
                    hasSleepData = true
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    totalSleepTime += duration
                    deepSleepTime += duration
                    hasSleepData = true
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    totalSleepTime += duration
                    remSleepTime += duration
                    hasSleepData = true
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeTime += duration
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    // We don't count "in bed" as sleep time, but we track it
                    break
                default:
                    break
                }
            }
            
            // Now validate if we have actual sleep data (not just "in bed" time)
            guard hasSleepData else {
                print("No actual sleep data found for date \(date) - only inBed time")
                return nil
            }
            
            // Check if total sleep time is realistic - at least 30 minutes
            guard totalSleepTime >= 1800 else {
                print("Sleep time too short (\(totalSleepTime/60) min) for date \(date)")
                return nil
            }
            
            // Check if the sleep duration seems realistic (less than 14 hours)
            guard totalSleepTime <= 50400 else {
                print("Sleep time too long (\(totalSleepTime/3600) hours) for date \(date)")
                return nil
            }
            
            let sleepHours = totalSleepTime / 3600 // Convert to hours
            
            // Calculate sleep stages percentages (avoid division by zero)
            let deepPercentage = totalSleepTime > 0 ? (deepSleepTime / totalSleepTime) * 100 : 0
            let remPercentage = totalSleepTime > 0 ? (remSleepTime / totalSleepTime) * 100 : 0
            let corePercentage = totalSleepTime > 0 ? (coreSleepTime / totalSleepTime) * 100 : 0
            let unspecifiedPercentage = totalSleepTime > 0 ? (unspecifiedSleepTime / totalSleepTime) * 100 : 0
            
            let sleepStages = SleepStages(
                deep: deepPercentage,
                rem: remPercentage,
                core: corePercentage,
                unspecified: unspecifiedPercentage
            )
            
            // Calculate sleep quality based on:
            // 1. Total sleep duration (weight: 60%)
            // 2. Percentage of deep/REM sleep (weight: 30%)
            // 3. Minimal disruptions (weight: 10%)
            
            // 1. Duration score (0-100): 8 hours is optimal (100%), less is proportionally lower
            let durationScore = min(100, (sleepHours / 8) * 100)
            
            // 2. Deep sleep score: Ideally 25% of sleep should be deep/REM
            let deepSleepPercentage = (deepSleepTime + remSleepTime) / max(totalSleepTime, 1)
            let deepSleepScore = min(100, (deepSleepPercentage / 0.25) * 100)
            
            // 3. Continuity score: Fewer awakenings is better
            let awakeningRatio = awakeTime / max(totalSleepTime + awakeTime, 1)
            let continuityScore = 100 - min(100, awakeningRatio * 200) // Penalize awakenings
            
            // Weighted quality score (0-100)
            let qualityScore = (durationScore * 0.6) + (deepSleepScore * 0.3) + (continuityScore * 0.1)
            
            return (sleepHours, qualityScore, sleepStages)
        } catch {
            print("Error fetching sleep data: \(error)")
            return nil
        }
    }
    
    func fetchLatestRestingHeartRateData() async -> Double? {
        guard let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictEndDate
        )
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: restingHeartRateType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        
        do {
            let results = try await descriptor.result(for: healthStore)
            guard let latestSample = results.first else { return nil }
            return latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        } catch {
            print("Error fetching resting heart rate: \(error)")
            return nil
        }
    }
    
    // MARK: - Metric Methods
    
    func fetchDailyRestingHeartRateData(forDays days: Int) async -> [RecoveryMetricData] {
        guard let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return []
        }
        
        var metrics: [RecoveryMetricData] = []
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -(days + 1), to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictEndDate
        )
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: restingHeartRateType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        
        do {
            let results = try await descriptor.result(for: healthStore)
            
            // Group samples by day
            let calendar = Calendar.current
            var samplesByDay: [Date: [HKQuantitySample]] = [:]
            
            for sample in results {
                let day = calendar.startOfDay(for: sample.startDate)
                if samplesByDay[day] == nil {
                    samplesByDay[day] = []
                }
                samplesByDay[day]?.append(sample)
            }
            
            // Get the average for each day
            for dayOffset in 0..<days {
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now))!
                if let samplesForDay = samplesByDay[date], !samplesForDay.isEmpty {
                    let totalValue = samplesForDay.reduce(0.0) { total, sample in
                        return total + sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    }
                    let avgValue = totalValue / Double(samplesForDay.count)
                    metrics.append(RecoveryMetricData(date: date, value: avgValue, explicitType: .heartRate))
                }
            }
            
            return metrics.sorted { $0.date < $1.date }
        } catch {
            print("Error fetching daily resting heart rate: \(error)")
            return []
        }
    }
    
    func fetchDailyHRVData(forDays days: Int) async -> [RecoveryMetricData] {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return []
        }
        
        var metrics: [RecoveryMetricData] = []
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -(days + 1), to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictEndDate
        )
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrvType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        
        do {
            let results = try await descriptor.result(for: healthStore)
            
            // Group samples by day
            let calendar = Calendar.current
            var samplesByDay: [Date: [HKQuantitySample]] = [:]
            
            for sample in results {
                let day = calendar.startOfDay(for: sample.startDate)
                if samplesByDay[day] == nil {
                    samplesByDay[day] = []
                }
                samplesByDay[day]?.append(sample)
            }
            
            // Get the average for each day
            for dayOffset in 0..<days {
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now))!
                if let samplesForDay = samplesByDay[date], !samplesForDay.isEmpty {
                    let totalValue = samplesForDay.reduce(0.0) { total, sample in
                        return total + sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    }
                    let avgValue = totalValue / Double(samplesForDay.count)
                    metrics.append(RecoveryMetricData(date: date, value: avgValue, explicitType: .hrv))
                }
            }
            
            return metrics.sorted { $0.date < $1.date }
        } catch {
            print("Error fetching daily HRV data: \(error)")
            return []
        }
    }
    
    func fetchDailySleepData(forDays days: Int) async -> [RecoveryMetricData] {
        var metrics: [RecoveryMetricData] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            if let sleepData = await fetchSleepData(forDate: date) {
                // Only add sleep data if it's available and seems valid (more than 1 hour)
                if sleepData.hours > 1.0 {
                    metrics.append(RecoveryMetricData(date: date, value: sleepData.hours, explicitType: .sleep))
                }
            }
            // Don't add placeholder entries for missing data
        }
        
        return metrics.sorted { $0.date < $1.date }
    }
    
    func fetchDailySleepQualityData(forDays days: Int) async -> [RecoveryMetricData] {
        var qualityMetrics: [RecoveryMetricData] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            if let sleepData = await fetchSleepData(forDate: date) {
                // Only add sleep quality data if sleep duration is valid (more than 1 hour)
                if sleepData.hours > 1.0 {
                    qualityMetrics.append(RecoveryMetricData(date: date, value: sleepData.quality, explicitType: .sleepQuality))
                }
            }
            // Don't add placeholder entries for missing data
        }
        
        return qualityMetrics.sorted { $0.date < $1.date }
    }
    
    // New method for fetching daily sleep stages data
    func fetchDailySleepStagesData(forDays days: Int) async -> [SleepStagesData] {
        var stagesData: [SleepStagesData] = []
        
        for dayOffset in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            if let sleepData = await fetchSleepData(forDate: date) {
                // Only add sleep stages data if sleep duration is valid (more than 1 hour)
                if sleepData.hours > 1.0 {
                    stagesData.append(SleepStagesData(date: date, stages: sleepData.stages))
                }
            }
        }
        
        return stagesData.sorted { $0.date < $1.date }
    }
}

struct SleepStages {
    let deep: Double  // Percentage of deep sleep
    let rem: Double   // Percentage of REM sleep
    let core: Double  // Percentage of core/light sleep
    let unspecified: Double // Percentage of unspecified sleep
    
    static var sample: SleepStages {
        return SleepStages(deep: 20, rem: 25, core: 45, unspecified: 10)
    }
}

struct SleepStagesData: Identifiable {
    let id = UUID()
    let date: Date
    let stages: SleepStages
} 
