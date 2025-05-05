import Foundation
import SwiftUI

struct ActivityRecommendation: Identifiable {
    let id: UUID
    let title: String
    let intensity: ActivityIntensity
    let duration: Int
    let description: String
    let icon: String
    
    // Computed property for formatted duration
    var formattedDuration: String {
        return "\(duration) minutes"
    }
}

// Static helper for testing/development
extension ActivityRecommendation {
    /// Generate a comprehensive set of activity recommendations for testing all card types
    static func getAllRecommendationTypes() -> [ActivityRecommendation] {
        var recommendations: [ActivityRecommendation] = []
        
        // Low intensity recommendations
        recommendations.append(contentsOf: [
            ActivityRecommendation(
                id: UUID(),
                title: "Light Walk",
                intensity: .low,
                duration: 20,
                description: "A gentle stroll to promote recovery without further stress.",
                icon: "figure.walk"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Gentle Yoga",
                intensity: .low,
                duration: 15,
                description: "Easy yoga poses to improve circulation and relaxation.",
                icon: "figure.yoga"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Recovery Ride",
                intensity: .low,
                duration: 25,
                description: "Very easy cycling to promote blood flow and recovery.",
                icon: "figure.outdoor.cycle"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Easy Recovery Run",
                intensity: .low,
                duration: 20,
                description: "A very light jog to maintain fitness without taxing recovery.",
                icon: "figure.run"
            )
        ])
        
        // Moderate intensity recommendations
        recommendations.append(contentsOf: [
            ActivityRecommendation(
                id: UUID(),
                title: "Moderate Run",
                intensity: .moderate,
                duration: 35,
                description: "A controlled pace run at conversational level.",
                icon: "figure.run"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Moderate Ride",
                intensity: .moderate,
                duration: 45,
                description: "A ride with mixed intensity for fitness maintenance.",
                icon: "figure.outdoor.cycle"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Personalized Run",
                intensity: .moderate,
                duration: 40,
                description: "A moderate running session tailored to your current recovery.",
                icon: "figure.run"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Personalized Swim",
                intensity: .moderate,
                duration: 30,
                description: "A swimming workout customized for your recovery status.",
                icon: "figure.pool.swim"
            )
        ])
        
        // High intensity recommendations
        recommendations.append(contentsOf: [
            ActivityRecommendation(
                id: UUID(),
                title: "Interval Session",
                intensity: .high,
                duration: 45,
                description: "High-intensity intervals to challenge your fitness.",
                icon: "figure.run"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Long Run",
                intensity: .high,
                duration: 60,
                description: "Extended running session to build endurance.",
                icon: "figure.run"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Challenging Ride",
                intensity: .high,
                duration: 75,
                description: "A challenging ride with hills and higher intensities.",
                icon: "figure.outdoor.cycle"
            ),
            ActivityRecommendation(
                id: UUID(),
                title: "Personalized Speed Run",
                intensity: .high,
                duration: 50,
                description: "A running session with speed work tailored to your recovery level.",
                icon: "figure.run"
            )
        ])
        
        return recommendations
    }
}

//enum ActivityIntensity: String {
//    case low = "Low"
//    case moderate = "Moderate"
//    case high = "High"
//
//    var color: Color {
//        switch self {
//        case .low: MendColors.positive
//        case .moderate: MendColors.neutral
//        case .high: MendColors.negative
//        }
//    }
//}

extension RecoveryScore {
    // Base recommendations property based on score
    var recommendedActivities: [ActivityRecommendation] {
        // Check if we should show all recommendation types for testing
        if DeveloperSettings.shared.showAllActivityRecommendations {
            return ActivityRecommendation.getAllRecommendationTypes()
        }
        
        var recommendations: [ActivityRecommendation] = []
        
        // Always include an easy walk option no matter the recovery state
        recommendations.append(
            ActivityRecommendation(
                id: UUID(),
                title: "Light Walk",
                intensity: .low,
                duration: 20,
                description: "A gentle stroll to promote recovery without further stress.",
                icon: "figure.walk"
            )
        )
        
        // Add recovery-specific recommendations
        if overallScore < 40 {
            // For very low recovery, only add additional low-intensity options
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Gentle Yoga",
                    intensity: .low,
                    duration: 15,
                    description: "Easy yoga poses to improve circulation and relaxation.",
                    icon: "figure.yoga"
                )
            )
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Recovery Ride",
                    intensity: .low,
                    duration: 25,
                    description: "Very easy cycling to promote blood flow and recovery.",
                    icon: "figure.outdoor.cycle"
                )
            )
        } else if overallScore < 60 {
            // For low recovery (40-60), add low to moderate options
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Recovery Ride",
                    intensity: .low,
                    duration: 30,
                    description: "Easy cycling to promote blood flow and recovery.",
                    icon: "figure.outdoor.cycle"
                )
            )
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Easy Run",
                    intensity: .low,
                    duration: 20,
                    description: "A very light jog to maintain fitness without taxing recovery.",
                    icon: "figure.run"
                )
            )
        } else if overallScore < 80 {
            // For moderate recovery (60-80), add moderate options
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Moderate Run",
                    intensity: .moderate,
                    duration: 35,
                    description: "A controlled pace run at conversation level.",
                    icon: "figure.run"
                )
            )
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Moderate Ride",
                    intensity: .moderate,
                    duration: 45,
                    description: "A ride with mixed intensity for fitness maintenance.",
                    icon: "figure.outdoor.cycle"
                )
            )
        } else {
            // For high recovery (80+), add higher intensity options
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Interval Session",
                    intensity: .high,
                    duration: 45,
                    description: "High-intensity intervals to challenge your fitness.",
                    icon: "figure.run"
                )
            )
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Long Run",
                    intensity: .high,
                    duration: 60,
                    description: "Extended running session to build endurance.",
                    icon: "figure.run"
                )
            )
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Challenging Ride",
                    intensity: .high,
                    duration: 75,
                    description: "A challenging ride with hills and higher intensities.",
                    icon: "figure.outdoor.cycle"
                )
            )
        }
        
        return recommendations
    }
    
    // Gets personalized activity recommendations based on user history and recovery score
    func getPersonalizedRecommendations() async -> [ActivityRecommendation] {
        // Check if we should show all recommendation types for testing
        if DeveloperSettings.shared.showAllActivityRecommendations {
            return ActivityRecommendation.getAllRecommendationTypes()
        }
        
        // Since ActivityManager is marked with @MainActor, we need to properly access it asynchronously
        @MainActor func getRecentUserActivities() async -> [Activity] {
            return ActivityManager.shared.getRecentActivities(days: 14)
        }
        
        @MainActor func getTodayActivities() async -> [Activity] {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            return ActivityManager.shared.activities.filter { calendar.isDate($0.date, inSameDayAs: startOfToday) }
        }
        
        // Check if user has done intense activity today
        let todayActivities = await getTodayActivities()
        let hasIntenseActivityToday = todayActivities.contains { $0.intensity == .high }
        
        // If user has already done an intense activity today, only recommend easy/recovery activities
        if hasIntenseActivityToday {
            return [
                ActivityRecommendation(
                    id: UUID(),
                    title: "Recovery Walk",
                    intensity: .low,
                    duration: 25,
                    description: "A gentle walk to help your body recover from today's intense activity.",
                    icon: "figure.walk"
                ),
                ActivityRecommendation(
                    id: UUID(),
                    title: "Light Stretching",
                    intensity: .low,
                    duration: 15,
                    description: "Gentle stretching to improve flexibility and aid recovery.",
                    icon: "figure.yoga"
                ),
                ActivityRecommendation(
                    id: UUID(),
                    title: "Easy Recovery Ride",
                    intensity: .low,
                    duration: 20,
                    description: "Very easy spinning to increase blood flow without adding stress.",
                    icon: "figure.outdoor.cycle"
                )
            ]
        }
        
        // First get static recommendations based on recovery score
        var recommendations = self.recommendedActivities
        
        // Then try to personalize based on user history
        let recentActivities = await getRecentUserActivities()
        
        if !recentActivities.isEmpty {
            // Find user's preferred activity types
            let activityCounts = Dictionary(grouping: recentActivities, by: { $0.type })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            // Calculate average duration for scaling recommendations
            let avgDuration = recentActivities.compactMap { $0.duration / 60 }.reduce(0, +) / Double(recentActivities.count)
            let durationScalingFactor = max(0.8, min(1.5, avgDuration / 45)) // Using 45 min as base duration
            
            if let mostFrequentType = activityCounts.first?.key {
                // Add recommendations based on the user's most frequent activity
                switch mostFrequentType {
                case .run:
                    // Scale recommendation duration based on user's average activity duration
                    let baseDuration = overallScore > 80 ? 50 : (overallScore > 60 ? 35 : 25)
                    let scaledDuration = Int(Double(baseDuration) * durationScalingFactor)
                    
                    if overallScore > 80 {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Personalized Speed Run",
                                intensity: .high,
                                duration: scaledDuration,
                                description: "A running session with speed work tailored to your recovery level.",
                                icon: "figure.run"
                            )
                        )
                    } else if overallScore > 60 {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Personalized Run",
                                intensity: .moderate,
                                duration: scaledDuration,
                                description: "A moderate running session tailored to your current recovery.",
                                icon: "figure.run"
                            )
                        )
                    } else {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Easy Recovery Run",
                                intensity: .low,
                                duration: scaledDuration,
                                description: "A very easy run to maintain fitness while prioritizing recovery.",
                                icon: "figure.run"
                            )
                        )
                    }
                    
                case .ride:
                    // Scale recommendation duration based on user's average activity duration
                    let baseDuration = overallScore > 80 ? 60 : (overallScore > 60 ? 45 : 30)
                    let scaledDuration = Int(Double(baseDuration) * durationScalingFactor)
                    
                    if overallScore > 80 {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Personalized Power Ride",
                                intensity: .high,
                                duration: scaledDuration,
                                description: "A challenging ride with intervals tailored to your high recovery level.",
                                icon: "figure.outdoor.cycle"
                            )
                        )
                    } else if overallScore > 60 {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Personalized Ride",
                                intensity: .moderate,
                                duration: scaledDuration,
                                description: "A cycling session with mixed terrain based on your current recovery.",
                                icon: "figure.outdoor.cycle"
                            )
                        )
                    } else {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Easy Spin Ride",
                                intensity: .low,
                                duration: scaledDuration,
                                description: "A gentle ride focusing on high cadence and low power to aid recovery.",
                                icon: "figure.outdoor.cycle"
                            )
                        )
                    }
                    
                case .swim:
                    if overallScore > 60 {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Personalized Swim",
                                intensity: overallScore > 80 ? .high : .moderate,
                                duration: overallScore > 80 ? 45 : 30,
                                description: "A swimming workout customized for your recovery status.",
                                icon: "figure.pool.swim"
                            )
                        )
                    }
                    
                default:
                    // Add a generic recommendation for other activity types
                    if overallScore > 60 {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Custom Workout",
                                intensity: overallScore > 80 ? .moderate : .low,
                                duration: 40,
                                description: "A workout based on your fitness preferences and recovery status.",
                                icon: "figure.mixed.cardio"
                            )
                        )
                    }
                }
            }
        }
        
        // Ensure we always have an easy walk option
        if !recommendations.contains(where: { $0.title.contains("Walk") && $0.intensity == .low }) {
            recommendations.append(
                ActivityRecommendation(
                    id: UUID(),
                    title: "Light Walk",
                    intensity: .low,
                    duration: 20,
                    description: "A gentle stroll to promote recovery without further stress.",
                    icon: "figure.walk"
                )
            )
        }
        
        // Limit to at most 4 recommendations
        if recommendations.count > 4 {
            recommendations = Array(recommendations.prefix(4))
        }
        
        return recommendations
    }
} 
