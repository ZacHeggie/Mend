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
                // Create notification with placeholder content first
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = "Check your latest recovery metrics"
                
                // Configure trigger for daily at the specified hour
                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                
                // Create the request with placeholder content
                let request = UNNotificationRequest(identifier: "mend_recovery_\(hour)", content: content, trigger: trigger)
                
                // Schedule the notification 
                center.add(request)
                
                // Setup a time-based trigger that will refresh data just before notification time
                // Schedule a refresh 5 minutes before the notification
                dateComponents.minute = 55  // 5 minutes before the hour
                if hour == 0 {
                    // If hour is midnight, set to 11:55 PM the previous day
                    dateComponents.hour = 23
                } else {
                    dateComponents.hour = hour - 1
                }
                
                // Create the background refresh call that will be triggered before notification
                let refreshTrigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let refreshContent = UNMutableNotificationContent()
                refreshContent.sound = nil
                refreshContent.badge = nil
                
                // This is a silent notification that will update data
                let refreshRequest = UNNotificationRequest(
                    identifier: "mend_refresh_before_\(hour)",
                    content: refreshContent,
                    trigger: refreshTrigger
                )
                
                center.add(refreshRequest)
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
