import Foundation
import UserNotifications

// Keys for UserDefaults
private let kNotificationPreference = "notificationPreference"
private let kRecoveryScore = "recoveryScore"

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var currentPreference: NotificationPreference {
        didSet {
            savePreference()
        }
    }
    
    private init() {
        // Load saved preference or use default
        if let savedValue = UserDefaults.standard.string(forKey: kNotificationPreference),
           let savedPreference = NotificationPreference(rawValue: savedValue) {
            currentPreference = savedPreference
        } else {
            currentPreference = .none
        }
    }
    
    private func savePreference() {
        UserDefaults.standard.set(currentPreference.rawValue, forKey: kNotificationPreference)
        updateScheduledNotifications()
    }
    
    func updateScheduledNotifications() {
        // First, remove all existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Then schedule based on current preference
        switch currentPreference {
        case .none:
            // No notifications to schedule
            break
            
        case .morning:
            scheduleNotification(at: 8, title: "Morning Recovery Update")
            
        case .morningAndEvening:
            scheduleNotification(at: 8, title: "Morning Recovery Update")
            scheduleNotification(at: 20, title: "Evening Recovery Update")
        }
    }
    
    private func scheduleNotification(at hour: Int, title: String) {
        let center = UNUserNotificationCenter.current()
        
        // Request permission if we haven't already
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                // First, ensure data is refreshed before getting recovery score
                Task {
                    // Force refresh of health data
                    await RecoveryMetrics.shared.refreshWithReset()
                    
                    // Now create notification content with updated data
                    await MainActor.run {
                        // Create the notification content
                        let content = UNMutableNotificationContent()
                        content.title = title
                        
                        // Get the current recovery data
                        if let recoveryMetrics = RecoveryMetrics.shared.currentRecoveryScore {
                            content.body = "Your recovery score is \(recoveryMetrics.overallScore). \(RecoveryMetrics.scoreDescription(for: recoveryMetrics))"
                        } else {
                            content.body = "Check your latest recovery metrics"
                        }
                        
                        // Configure trigger for daily at the specified hour
                        var dateComponents = DateComponents()
                        dateComponents.hour = hour
                        dateComponents.minute = 0
                        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                        
                        // Create the request
                        let request = UNNotificationRequest(identifier: "mend_recovery_\(hour)", content: content, trigger: trigger)
                        
                        // Add the request
                        center.add(request)
                    }
                }
            }
        }
    }
    
    func sendTestNotification() {
        let center = UNUserNotificationCenter.current()
        
        // Request permission if we haven't already
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                // First, ensure data is refreshed before getting recovery score
                Task {
                    // Force refresh of health data
                    await RecoveryMetrics.shared.refreshWithReset()
                    
                    // Now create notification content with updated data
                    await MainActor.run {
                        // Create the notification content
                        let content = UNMutableNotificationContent()
                        content.title = "Test Recovery Notification"
                        
                        // Get the current recovery data
                        if let recoveryMetrics = RecoveryMetrics.shared.currentRecoveryScore {
                            content.body = "Your recovery score is \(recoveryMetrics.overallScore). \(RecoveryMetrics.scoreDescription(for: recoveryMetrics))"
                        } else {
                            content.body = "Test notification - check your latest recovery metrics"
                        }
                        
                        // Configure trigger for immediate delivery (5 seconds from now)
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                        
                        // Create the request
                        let request = UNNotificationRequest(identifier: "mend_recovery_test", content: content, trigger: trigger)
                        
                        // Add the request
                        center.add(request)
                    }
                }
            }
        }
    }
} 
