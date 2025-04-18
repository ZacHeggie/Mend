import Foundation
import SwiftUI

struct Activity: Identifiable, Codable {
    let id: UUID
    let title: String
    let type: ActivityType
    let date: Date
    let duration: TimeInterval
    let distance: Double? // in kilometers
    let intensity: ActivityIntensity
    let source: ActivitySource
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var formattedDistance: String? {
        guard let distance = distance else { return nil }
        return String(format: "%.1f km", distance)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Sample data
extension Activity {
    static let sampleData: [Activity] = [
        Activity(
            id: UUID(),
            title: "Morning Run",
            type: .run,
            date: Date().addingTimeInterval(-86400), // Yesterday
            duration: 1800, // 30 minutes
            distance: 5.0,
            intensity: .moderate,
            source: .manual
        ),
        Activity(
            id: UUID(),
            title: "Evening Ride",
            type: .ride,
            date: Date().addingTimeInterval(-43200), // 12 hours ago
            duration: 3600, // 1 hour
            distance: 20.0,
            intensity: .high,
            source: .healthKit
        ),
        Activity(
            id: UUID(),
            title: "Strength Training",
            type: .workout,
            date: Date(),
            duration: 2700, // 45 minutes
            distance: nil,
            intensity: .moderate,
            source: .manual
        )
    ]
} 