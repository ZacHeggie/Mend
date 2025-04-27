import Foundation
import SwiftUI
import MessageUI

// MARK: - Mail Data
struct MailData: Equatable {
    let toRecipients: [String]
    let subject: String
    let messageBody: String
    let attachment: Data?
    let attachmentMimeType: String?
    let attachmentFilename: String?
    
    init(toRecipients: [String], subject: String, messageBody: String, 
         attachment: Data? = nil, attachmentMimeType: String? = nil, attachmentFilename: String? = nil) {
        self.toRecipients = toRecipients
        self.subject = subject
        self.messageBody = messageBody
        self.attachment = attachment
        self.attachmentMimeType = attachmentMimeType
        self.attachmentFilename = attachmentFilename
    }
    
    // Custom Equatable implementation because Data isn't Equatable by default
    static func == (lhs: MailData, rhs: MailData) -> Bool {
        lhs.toRecipients == rhs.toRecipients &&
        lhs.subject == rhs.subject &&
        lhs.messageBody == rhs.messageBody &&
        // Compare attachments by checking if both are nil or both are non-nil
        // We don't actually compare Data contents since that's expensive and unnecessary
        (lhs.attachment == nil) == (rhs.attachment == nil) &&
        lhs.attachmentMimeType == rhs.attachmentMimeType &&
        lhs.attachmentFilename == rhs.attachmentFilename
    }
}

class RequestService: ObservableObject {
    // Shared singleton instance
    static let shared = RequestService()
    
    // Published properties for UI updates
    @Published var isSubmitting = false
    @Published var lastSubmissionError: String?
    @Published var mailData: MailData?
    
    // API configuration - would typically come from configuration
    private let apiBaseURL = "https://api.mendapp.com/v1"
    private let timeoutInterval: TimeInterval = 30.0
    
    // Support email
    private let supportEmail = "mendsupport@icloud.com"
    
    private init() {}
    
    // Check if mail is available
    var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }
    
    // Provide a fallback method for when mail is unavailable - creates a URL to open in Mail app
    func getMailtoURL(subject: String, body: String) -> URL? {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoString = "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        return URL(string: mailtoString)
    }
    
    // MARK: - Feature Request Submission
    
    func submitFeatureRequest(_ request: FeatureRequestModel) async -> Result<Bool, RequestError> {
        // Update UI state
        DispatchQueue.main.async {
            self.isSubmitting = true
            self.lastSubmissionError = nil
        }
        
        do {
            // Encode the request as JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let requestData = try encoder.encode(request)
            
            guard let jsonString = String(data: requestData, encoding: .utf8) else {
                throw RequestError.invalidRequest
            }
            
            // Generate email body
            let emailSubject = "Feature Request: \(request.title)"
            let emailBody = """
            Feature Request Details:
            
            Title: \(request.title)
            Category: \(request.category)
            Priority: \(request.priorityLevel)
            Keep Me Updated: \(request.keepMeUpdated ? "Yes" : "No")
            
            Description:
            \(request.description)
            
            Device Info:
            - Device Model: \(request.deviceInfo.deviceModel)
            - iOS Version: \(request.deviceInfo.systemVersion)
            - App Version: \(request.deviceInfo.appVersion) (\(request.deviceInfo.appBuild))
            
            Timestamp: \(ISO8601DateFormatter().string(from: request.timestamp))
            
            Thank you for your feedback!
            """
            
            // For logging
            print("📤 Prepared feature request email: \(emailSubject)")
            
            // Create mail data
            let mailData = MailData(
                toRecipients: [supportEmail],
                subject: emailSubject,
                messageBody: emailBody,
                attachment: requestData,
                attachmentMimeType: "application/json",
                attachmentFilename: "feature_request_\(Int(Date().timeIntervalSince1970)).json"
            )
            
            // Check if mail can be sent from device
            if canSendMail {
                // Update UI to present mail composer
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    self.mailData = mailData
                }
                return .success(true)
            } else {
                // No mail capability - try fallback options
                #if DEBUG
                saveRequestLocally(requestData, type: "feature")
                DispatchQueue.main.async {
                    self.isSubmitting = false
                }
                return .success(true)
                #else
                let mailtoURL = getMailtoURL(
                    subject: emailSubject,
                    body: "Please copy and paste the information below:\n\n\(emailBody)"
                )
                
                // If we can create a mailto URL, update UI to use it
                if let mailtoURL = mailtoURL {
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        UIApplication.shared.open(mailtoURL)
                    }
                    return .success(true)
                } else {
                    throw RequestError.mailUnavailable
                }
                #endif
            }
        } catch let error as RequestError {
            // Handle known request errors
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.lastSubmissionError = error.localizedDescription
            }
            return .failure(error)
        } catch {
            // Handle unknown errors
            let requestError = RequestError.unknown(error.localizedDescription)
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.lastSubmissionError = requestError.localizedDescription
            }
            return .failure(requestError)
        }
    }
    
    // MARK: - Bug Report Submission
    
    func submitBugReport(_ report: BugReportModel) async -> Result<Bool, RequestError> {
        // Update UI state
        DispatchQueue.main.async {
            self.isSubmitting = true
            self.lastSubmissionError = nil
        }
        
        do {
            // Encode the report as JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            // Remove screenshot from JSON to keep it small
            var reportForJson = report
            let screenshot = report.screenshot
            reportForJson = BugReportModel(
                category: report.category,
                description: report.description,
                reproductionSteps: report.reproductionSteps,
                systemLogs: report.systemLogs,
                screenshot: nil,
                keepMeUpdated: report.keepMeUpdated
            )
            
            let reportData = try encoder.encode(reportForJson)
            
            guard let jsonString = String(data: reportData, encoding: .utf8) else {
                throw RequestError.invalidRequest
            }
            
            // Generate email body
            let emailSubject = "Bug Report: \(report.category)"
            let emailBody = """
            Bug Report Details:
            
            Category: \(report.category)
            Keep Me Updated: \(report.keepMeUpdated ? "Yes" : "No")
            
            Description:
            \(report.description)
            
            Steps to Reproduce:
            \(report.reproductionSteps ?? "Not provided")
            
            System Logs:
            \(report.systemLogs ?? "Not included")
            
            Device Info:
            - Device Model: \(report.deviceInfo.deviceModel)
            - iOS Version: \(report.deviceInfo.systemVersion)
            - App Version: \(report.deviceInfo.appVersion) (\(report.deviceInfo.appBuild))
            
            Timestamp: \(ISO8601DateFormatter().string(from: report.timestamp))
            
            Thank you for reporting this issue!
            """
            
            // For logging
            print("📤 Prepared bug report email: \(emailSubject)")
            
            // Create mail data with screenshot if available
            let mailData = MailData(
                toRecipients: [supportEmail],
                subject: emailSubject,
                messageBody: emailBody,
                attachment: screenshot,
                attachmentMimeType: screenshot != nil ? "image/jpeg" : nil,
                attachmentFilename: screenshot != nil ? "screenshot_\(Int(Date().timeIntervalSince1970)).jpg" : nil
            )
            
            // Check if mail can be sent from device
            if canSendMail {
                // Update UI to present mail composer
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    self.mailData = mailData
                }
                return .success(true)
            } else {
                // No mail capability - try fallback options
                #if DEBUG
                saveRequestLocally(reportData, type: "bug")
                DispatchQueue.main.async {
                    self.isSubmitting = false
                }
                return .success(true)
                #else
                let mailtoURL = getMailtoURL(
                    subject: emailSubject,
                    body: "Please copy and paste the information below:\n\n\(emailBody)"
                )
                
                // If we can create a mailto URL, update UI to use it
                if let mailtoURL = mailtoURL {
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        UIApplication.shared.open(mailtoURL)
                    }
                    return .success(true)
                } else {
                    throw RequestError.mailUnavailable
                }
                #endif
            }
        } catch let error as RequestError {
            // Handle known request errors
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.lastSubmissionError = error.localizedDescription
            }
            return .failure(error)
        } catch {
            // Handle unknown errors
            let requestError = RequestError.unknown(error.localizedDescription)
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.lastSubmissionError = requestError.localizedDescription
            }
            return .failure(requestError)
        }
    }
    
    // MARK: - Helper Methods
    
    /// For development, store requests locally for inspection
    private func saveRequestLocally(_ data: Data, type: String) {
        // Get the documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not access documents directory")
            return
        }
        
        // Create a timestamped filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(type)_request_\(timestamp).json"
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // Write the data to file
        do {
            try data.write(to: fileURL)
            print("✅ Saved \(type) request to: \(fileURL.path)")
        } catch {
            print("⚠️ Failed to save \(type) request: \(error.localizedDescription)")
        }
    }
    
    /// For development, store screenshot data
    private func saveImageLocally(_ imageData: Data, name: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(name)
        
        do {
            try imageData.write(to: fileURL)
            print("✅ Saved image to: \(fileURL.path)")
        } catch {
            print("⚠️ Failed to save image: \(error.localizedDescription)")
        }
    }
}

// MARK: - Request Error

enum RequestError: Error, CustomStringConvertible {
    case invalidRequest
    case networkError(String)
    case serverError(Int)
    case mailUnavailable
    case unknown(String)
    
    var description: String {
        switch self {
        case .invalidRequest:
            return "Unable to process your request. Please try again."
        case .networkError(let details):
            return "Network error: \(details)"
        case .serverError(let code):
            return "Server error (code: \(code)). Please try again later."
        case .mailUnavailable:
            return "Mail functionality is not available on this device. Please set up Mail app or contact support directly."
        case .unknown(let details):
            return "An unexpected error occurred: \(details)"
        }
    }
    
    var localizedDescription: String {
        return description
    }
} 