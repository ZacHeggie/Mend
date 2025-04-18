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
        
        // Determine intensity based on heart rate and duration
        let intensity = determineIntensityFromWorkout(workout)
        
        return Activity(
            id: UUID(),
            title: title,
            type: activityType,
            date: workout.startDate,
            duration: duration,
            distance: distance,
            intensity: intensity,
            source: .healthKit
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
    
    func fetchSleepData(forDate date: Date) async -> (hours: Double, quality: Double)? {
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
            
            var totalSleepTime: TimeInterval = 0
            var deepSleepTime: TimeInterval = 0
            var awakeTime: TimeInterval = 0
            
            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                     HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    totalSleepTime += duration
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    totalSleepTime += duration
                    deepSleepTime += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    totalSleepTime += duration
                    // REM sleep is good for quality
                    deepSleepTime += duration * 0.8
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeTime += duration
                default:
                    break
                }
            }
            
            if totalSleepTime > 0 {
                let sleepHours = totalSleepTime / 3600 // Convert to hours
                
                // Calculate sleep quality based on:
                // 1. Total sleep duration (weight: 60%)
                // 2. Percentage of deep/REM sleep (weight: 30%)
                // 3. Minimal disruptions (weight: 10%)
                
                // 1. Duration score (0-100): 8 hours is optimal (100%), less is proportionally lower
                let durationScore = min(100, (sleepHours / 8) * 100)
                
                // 2. Deep sleep score: Ideally 25% of sleep should be deep/REM
                let deepSleepPercentage = deepSleepTime / max(totalSleepTime, 1)
                let deepSleepScore = min(100, (deepSleepPercentage / 0.25) * 100)
                
                // 3. Continuity score: Fewer awakenings is better
                let awakeningRatio = awakeTime / max(totalSleepTime + awakeTime, 1)
                let continuityScore = 100 - min(100, awakeningRatio * 200) // Penalize awakenings
                
                // Weighted quality score (0-100)
                let qualityScore = (durationScore * 0.6) + (deepSleepScore * 0.3) + (continuityScore * 0.1)
                
                return (sleepHours, qualityScore)
            } else {
                return nil
            }
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
                    metrics.append(RecoveryMetricData(date: date, value: avgValue))
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
                    metrics.append(RecoveryMetricData(date: date, value: avgValue))
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
        
        for dayOffset in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            if let sleepData = await fetchSleepData(forDate: date) {
                metrics.append(RecoveryMetricData(date: date, value: sleepData.hours))
            }
        }
        
        return metrics.sorted { $0.date < $1.date }
    }
    
    func fetchDailySleepQualityData(forDays days: Int) async -> [RecoveryMetricData] {
        var qualityMetrics: [RecoveryMetricData] = []
        
        for dayOffset in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            if let sleepData = await fetchSleepData(forDate: date) {
                qualityMetrics.append(RecoveryMetricData(date: date, value: sleepData.quality))
            }
        }
        
        return qualityMetrics.sorted { $0.date < $1.date }
    }
} 