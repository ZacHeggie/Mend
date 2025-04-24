import Foundation
import SwiftUI

// MARK: - Shared Enums
enum ActivityIntensity: String, Codable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return MendColors.positive
        case .moderate: return MendColors.neutral
        case .high: return MendColors.negative
        }
    }
    
    var description: String {
        return self.rawValue + " Intensity"
    }
}

enum ActivityType: String, Codable, CaseIterable {
    case run = "Run"
    case ride = "Ride"
    case swim = "Swim"
    case walk = "Walk"
    case workout = "Workout"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .ride: return "figure.outdoor.cycle"
        case .swim: return "figure.pool.swim"
        case .walk: return "figure.walk"
        case .workout: return "figure.strengthtraining.traditional"
        case .other: return "figure.mixed.cardio"
        }
    }
}

enum ActivitySource: String, Codable, CaseIterable {
    case strava = "Strava"
    case manual = "Manual"
    case healthKit = "HealthKit"
}

// MARK: - Training Metrics
struct DailyMetricData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct DailyTrainingVolume: Identifiable {
    let id = UUID()
    let date: Date
    let totalDurationMinutes: Double
    let averageIntensity: Double
    let activityCount: Int
    let trainingLoad: Double
    
    var formattedDuration: String {
        let hours = Int(totalDurationMinutes / 60)
        let minutes = Int(totalDurationMinutes.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var intensityLevel: ActivityIntensity {
        if averageIntensity >= 2.5 {
            return .high
        } else if averageIntensity >= 1.5 {
            return .moderate
        } else {
            return .low
        }
    }
    
    var formattedTrainingLoad: String {
        return String(format: "%.0f", trainingLoad)
    }
} 
