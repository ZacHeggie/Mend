import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum HealthDataImportError: Error {
    case invalidFile
    case parsingError
    case unsupportedFormat
    case emptyData
    
    var description: String {
        switch self {
        case .invalidFile: return "The selected file is not a valid Apple Health export"
        case .parsingError: return "Unable to parse the health data"
        case .unsupportedFormat: return "Unsupported file format"
        case .emptyData: return "No health data found in the file"
        }
    }
}

class HealthDataImporter: ObservableObject {
    @Published var isImporting = false
    @Published var error: HealthDataImportError?
    
    private let supportedTypes = [UTType.xml]
    
    func validateFile(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "xml" else {
            error = .unsupportedFormat
            return false
        }
        
        // Verify file size is reasonable (e.g., not over 50MB)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            if fileSize > 50_000_000 { // 50MB limit
                error = .invalidFile
                return false
            }
        } catch {
            self.error = .invalidFile
            return false
        }
        
        return true
    }
    
    func importHealthData(from url: URL) async throws -> [Activity] {
        guard validateFile(url) else {
            throw error ?? .invalidFile
        }
        
        // Create a secure temporary directory for processing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: tempDir, 
                                                 withIntermediateDirectories: true)
            
            // Copy file to secure temporary location
            let secureFilePath = tempDir.appendingPathComponent("health_import.xml")
            try FileManager.default.copyItem(at: url, to: secureFilePath)
            
            // Parse the XML file
            let activities = try await parseHealthData(from: secureFilePath)
            
            // Clean up
            try FileManager.default.removeItem(at: tempDir)
            
            return activities
        } catch {
            // Clean up on error
            try? FileManager.default.removeItem(at: tempDir)
            throw HealthDataImportError.parsingError
        }
    }
    
    private func parseHealthData(from url: URL) async throws -> [Activity] {
        guard let xmlData = try? Data(contentsOf: url) else {
            throw HealthDataImportError.invalidFile
        }
        
        let parser = XMLParser(data: xmlData)
        let delegate = HealthDataParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse() else {
            throw HealthDataImportError.parsingError
        }
        
        return delegate.activities
    }
}

class HealthDataParserDelegate: NSObject, XMLParserDelegate {
    var activities: [Activity] = []
    private var currentElement = ""
    private var workoutData: [String: Any] = [:]
    
    func parser(_ parser: XMLParser, 
               didStartElement elementName: String,
               namespaceURI: String?,
               qualifiedName qName: String?,
               attributes attributeDict: [String: String] = [:]) {
        
        currentElement = elementName
        
        if elementName == "Workout" {
            workoutData = [:]
            
            if let workoutType = attributeDict["workoutActivityType"],
               let startDate = attributeDict["startDate"],
               let duration = attributeDict["duration"] {
                
                workoutData["type"] = mapWorkoutType(workoutType)
                workoutData["startDate"] = startDate
                workoutData["duration"] = Double(duration)
                
                if let distance = attributeDict["totalDistance"] {
                    workoutData["distance"] = Double(distance)
                }
            }
        }
    }
    
    func parser(_ parser: XMLParser,
               didEndElement elementName: String,
               namespaceURI: String?,
               qualifiedName qName: String?) {
        
        if elementName == "Workout" {
            createActivity()
        }
    }
    
    private func createActivity() {
        guard let type = workoutData["type"] as? ActivityType,
              let startDateString = workoutData["startDate"] as? String,
              let duration = workoutData["duration"] as? Double else {
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: startDateString) else {
            return
        }
        
        let distance = workoutData["distance"] as? Double
        
        let activity = Activity(
            id: UUID(),
            title: "\(type.rawValue) Activity",
            type: type,
            date: date,
            duration: duration,
            distance: distance.map { $0 / 1000 }, // Convert to kilometers
            intensity: determineIntensity(duration: duration, distance: distance),
            source: .healthKit
        )
        
        activities.append(activity)
    }
    
    private func mapWorkoutType(_ healthKitType: String) -> ActivityType {
        switch healthKitType {
        case "HKWorkoutActivityTypeRunning": return .run
        case "HKWorkoutActivityTypeCycling": return .ride
        case "HKWorkoutActivityTypeSwimming": return .swim
        case "HKWorkoutActivityTypeWalking": return .walk
        case "HKWorkoutActivityTypeTraditionalStrengthTraining": return .workout
        default: return .other
        }
    }
    
    private func determineIntensity(duration: Double, distance: Double?) -> ActivityIntensity {
        // Simple intensity determination based on duration
        if duration > 3600 { // More than 1 hour
            return .high
        } else if duration > 1800 { // More than 30 minutes
            return .moderate
        } else {
            return .low
        }
    }
} 