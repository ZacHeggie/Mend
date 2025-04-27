import Foundation
import UIKit

// MARK: - Feature Request Models
struct FeatureRequestModel: Codable {
    let title: String
    let category: String
    let priorityLevel: String
    let description: String
    let keepMeUpdated: Bool
    let deviceInfo: RequestDeviceInfo
    let timestamp: Date
    
    init(title: String, category: String, priorityLevel: String, description: String, keepMeUpdated: Bool = false) {
        self.title = title
        self.category = category
        self.priorityLevel = priorityLevel
        self.description = description
        self.keepMeUpdated = keepMeUpdated
        self.deviceInfo = RequestDeviceInfo.current
        self.timestamp = Date()
    }
}

// MARK: - Bug Report Models
struct BugReportModel: Codable {
    let category: String
    let description: String
    let reproductionSteps: String?
    let deviceInfo: RequestDeviceInfo
    let systemLogs: String?
    let screenshot: Data?
    let timestamp: Date
    let keepMeUpdated: Bool
    
    init(category: String, description: String, reproductionSteps: String? = nil, systemLogs: String? = nil, screenshot: Data? = nil, keepMeUpdated: Bool = false) {
        self.category = category
        self.description = description
        self.reproductionSteps = reproductionSteps
        self.deviceInfo = RequestDeviceInfo.current
        self.systemLogs = systemLogs
        self.screenshot = screenshot
        self.timestamp = Date()
        self.keepMeUpdated = keepMeUpdated
    }
}

// MARK: - Shared Model Types
struct RequestDeviceInfo: Codable {
    let deviceModel: String
    let systemVersion: String
    let appVersion: String
    let appBuild: String
    
    static var current: RequestDeviceInfo {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        return RequestDeviceInfo(
            deviceModel: device.model,
            systemVersion: device.systemVersion,
            appVersion: appVersion,
            appBuild: appBuild
        )
    }
} 