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
    let averageHeartRate: Double? // in bpm
    let trainingLoadScore: Double?
    let elevation: Double? // in meters
    let lengths: Int? // number of pool lengths for swimming
    
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
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    var formattedHeartRate: String? {
        guard let heartRate = averageHeartRate else { return nil }
        return String(format: "%.0f bpm", heartRate)
    }
    
    var formattedTrainingLoad: String? {
        guard let trainingLoad = trainingLoadScore else { return nil }
        return String(format: "%.0f pts", trainingLoad)
    }
    
    var formattedElevation: String? {
        guard let elevation = elevation else { return nil }
        return String(format: "%.0f m", elevation)
    }
    
    var formattedLengths: String? {
        guard let lengths = lengths else { return nil }
        return "\(lengths) lengths"
    }
    
    // Average speed in km/hr for ride or walk activities
    var averageSpeed: Double? {
        guard let distance = distance, duration > 0,
              type == .ride || type == .walk else { return nil }
        let durationHours = duration / 3600
        return distance / durationHours
    }
    
    var formattedAverageSpeed: String? {
        guard let speed = averageSpeed else { return nil }
        return String(format: "%.1f km/h", speed)
    }
    
    // Average km pace for run activities (minutes per km)
    var averageKmPace: Double? {
        guard let distance = distance, duration > 0, distance > 0,
              type == .run else { return nil }
        let durationMinutes = duration / 60
        return durationMinutes / distance
    }
    
    var formattedAverageKmPace: String? {
        guard let pace = averageKmPace else { return nil }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    // Average 500m pace for row activities (minutes per 500m)
    var average500mPace: Double? {
        guard let distance = distance, duration > 0, distance > 0,
              type == .rowIndoor || type == .rowOutdoor else { return nil }
        let durationMinutes = duration / 60
        let distance500m = distance * 2 // Convert km to 500m segments (1km = 2 x 500m)
        return durationMinutes / distance500m
    }
    
    var formattedAverage500mPace: String? {
        guard let pace = average500mPace else { return nil }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /500m", minutes, seconds)
    }
    
    // Average 100m pace for swim activities (minutes per 100m)
    var average100mPace: Double? {
        guard let distance = distance, duration > 0, distance > 0,
              type == .swim else { return nil }
        let durationMinutes = duration / 60
        let distance100m = distance * 10 // Convert km to 100m segments (1km = 10 x 100m)
        return durationMinutes / distance100m
    }
    
    var formattedAverage100mPace: String? {
        guard let pace = average100mPace else { return nil }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /100m", minutes, seconds)
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
            source: .manual,
            averageHeartRate: 145.0,
            trainingLoadScore: 35.0,
            elevation: 120.0,
            lengths: nil
        ),
        Activity(
            id: UUID(),
            title: "Evening Ride",
            type: .ride,
            date: Date().addingTimeInterval(-43200), // 12 hours ago
            duration: 3600, // 1 hour
            distance: 20.0,
            intensity: .high,
            source: .healthKit,
            averageHeartRate: 160.0,
            trainingLoadScore: 58.0,
            elevation: 350.0,
            lengths: nil
        ),
        Activity(
            id: UUID(),
            title: "Strength Training",
            type: .workout,
            date: Date(),
            duration: 2700, // 45 minutes
            distance: nil,
            intensity: .moderate,
            source: .manual,
            averageHeartRate: 135.0,
            trainingLoadScore: 42.0,
            elevation: nil,
            lengths: nil
        )
    ]
} 
