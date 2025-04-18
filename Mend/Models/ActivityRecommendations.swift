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
    // Synchronous property that returns basic recommendations based on score
    var recommendedActivities: [ActivityRecommendation] {
        if overallScore < 40 {
            return [
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
                )
            ]
        } else if overallScore < 60 {
            return [
                ActivityRecommendation(
                    id: UUID(),
                    title: "Moderate Walk",
                    intensity: .low,
                    duration: 30,
                    description: "A brisk walk to get your body moving without strain.",
                    icon: "figure.walk"
                ),
                ActivityRecommendation(
                    id: UUID(),
                    title: "Recovery Ride",
                    intensity: .low,
                    duration: 25,
                    description: "Easy cycling to promote blood flow and recovery.",
                    icon: "figure.outdoor.cycle"
                )
            ]
        } else if overallScore < 80 {
            return [
                ActivityRecommendation(
                    id: UUID(),
                    title: "Easy Run",
                    intensity: .moderate,
                    duration: 30,
                    description: "A relaxed run at conversation pace.",
                    icon: "figure.run"
                ),
                ActivityRecommendation(
                    id: UUID(),
                    title: "Moderate Ride",
                    intensity: .moderate,
                    duration: 45,
                    description: "A ride with mixed intensity for fitness maintenance.",
                    icon: "figure.outdoor.cycle"
                )
            ]
        } else {
            return [
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
                )
            ]
        }
    }
    
    // Gets personalized activity recommendations based on user history and recovery score
    func getPersonalizedRecommendations() async -> [ActivityRecommendation] {
        // Since ActivityManager is marked with @MainActor, we need to properly access it asynchronously
        @MainActor func getRecentUserActivities() async -> [Activity] {
            return ActivityManager.shared.getRecentActivities(days: 14)
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
            
            if let mostFrequentType = activityCounts.first?.key {
                // Add a recommendation based on the user's most frequent activity
                switch mostFrequentType {
                case .run:
                    if overallScore > 70 {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Personalized Run",
                                intensity: overallScore > 80 ? .high : .moderate,
                                duration: overallScore > 80 ? 50 : 35,
                                description: "A running session tailored to your recovery level and preferences.",
                                icon: "figure.run"
                            )
                        )
                    }
                case .ride:
                    if overallScore > 65 {
                        recommendations.append(
                            ActivityRecommendation(
                                id: UUID(),
                                title: "Personalized Ride",
                                intensity: overallScore > 80 ? .high : .moderate,
                                duration: overallScore > 80 ? 60 : 40,
                                description: "A cycling session based on your recent history and current recovery.",
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
                    if overallScore > 70 {
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
        
        // Limit to at most 3 recommendations
        if recommendations.count > 3 {
            recommendations = Array(recommendations.prefix(3))
        }
        
        return recommendations
    }
} 
