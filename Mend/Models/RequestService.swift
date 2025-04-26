import Foundation
import SwiftUI

class RequestService: ObservableObject {
    // Shared singleton instance
    static let shared = RequestService()
    
    // Published properties for UI updates
    @Published var isSubmitting = false
    @Published var lastSubmissionError: String?
    
    // API configuration - would typically come from configuration
    private let apiBaseURL = "https://api.mendapp.com/v1"
    private let timeoutInterval: TimeInterval = 30.0
    
    private init() {}
    
    // MARK: - Feature Request Submission
    
    func submitFeatureRequest(_ request: FeatureRequestModel) async -> Result<Bool, RequestError> {
        // Update UI state
        DispatchQueue.main.async {
            self.isSubmitting = true
            self.lastSubmissionError = nil
        }
        
        do {
            // In production, this would be an actual API call
            // For now, we'll simulate the network request
            
            // Encode the request
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let requestData = try encoder.encode(request)
            
            // Log for debugging (would be removed in production)
            if let jsonString = String(data: requestData, encoding: .utf8) {
                print("📤 Sending feature request: \(jsonString)")
            }
            
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Simulate response with random success (90% success rate for testing)
            let isSuccessful = Double.random(in: 0...1) < 0.9
            
            if isSuccessful {
                // For development we'll store locally (would be removed in production)
                saveRequestLocally(requestData, type: "feature")
                
                // Update UI state
                DispatchQueue.main.async {
                    self.isSubmitting = false
                }
                
                return .success(true)
            } else {
                throw RequestError.serverError("Server is temporarily unavailable")
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
            // Encode the report
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let reportData = try encoder.encode(report)
            
            // Log for debugging (would be removed in production)
            if let jsonString = String(data: reportData, encoding: .utf8) {
                // Truncate screenshot data in log
                let truncatedJson = jsonString.replacingOccurrences(
                    of: "\"screenshot\":\"[^\"]+\"", 
                    with: "\"screenshot\":\"[DATA]\"", 
                    options: [.regularExpression]
                )
                print("📤 Sending bug report: \(truncatedJson)")
            }
            
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Simulate response with random success (90% success rate for testing)
            let isSuccessful = Double.random(in: 0...1) < 0.9
            
            if isSuccessful {
                // For development we'll store locally (would be removed in production)
                saveRequestLocally(reportData, type: "bug")
                
                // Update UI state
                DispatchQueue.main.async {
                    self.isSubmitting = false
                }
                
                return .success(true)
            } else {
                throw RequestError.serverError("Server is temporarily unavailable")
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
}

// MARK: - Error Types

enum RequestError: Error, LocalizedError {
    case invalidRequest
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request data"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
} 