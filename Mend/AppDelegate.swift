//
//  AppDelegate.swift
//  Mend
//
//  Created by Zac Heggie on 4/14/25.
//

import UIKit
import HealthKit
import PassKit
import BackgroundTasks
import UserNotifications
import StoreKit

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize the health store
        requestHealthKitAuthorization()
        
        // Register for background refresh
        setupBackgroundRefresh()
        
        // Initialize the StoreKit for in-app purchases
        Task {
            await StoreKitService.shared.loadProducts()
        }
        
        // Set this class as the UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Request authorization for HealthKit
    private func requestHealthKitAuthorization() {
        Task {
            do {
                try await HealthKitManager.shared.requestAuthorization()
            } catch {
                print("Error requesting HealthKit authorization: \(error)")
            }
        }
    }
    
    // Setup background refresh for health data updates
    private func setupBackgroundRefresh() {
        // Setup background processing
        let taskIdentifier = "com.mend.dataRefresh"
        
        // Register for background refresh
        if #available(iOS 13.0, *) {
            // Register for background refresh tasks with a specific queue
            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: DispatchQueue.global()) { task in
                self.handleBackgroundRefresh(task: task as! BGProcessingTask)
            }
            
            // Schedule the initial background task
            self.scheduleBackgroundRefresh()
        } else {
            // Fallback for older iOS versions
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        }
    }
    
    // Handle background refresh task
    @available(iOS 13.0, *)
    private func handleBackgroundRefresh(task: BGProcessingTask) {
        // Schedule the next background refresh
        scheduleBackgroundRefresh()
        
        // Create a task to refresh health data
        let refreshTask = Task {
            do {
                // Perform the actual refresh operation
                await RecoveryMetrics.shared.refreshData()
                
                // Mark the task as completed
                task.setTaskCompleted(success: true)
            } catch {
                print("Error refreshing data in background: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
        
        // If the system needs to cancel the task, cancel our operation
        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    // Schedule background refresh
    @available(iOS 13.0, *)
    private func scheduleBackgroundRefresh() {
        let request = BGProcessingTaskRequest(identifier: "com.mend.dataRefresh")
        
        // Set to true to require device to be charging
        request.requiresExternalPower = false
        
        // Set to true to require Wi-Fi
        request.requiresNetworkConnectivity = false
        
        // Set earliest begin date to 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled successfully")
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // If this is a refresh notification, refresh data but don't show it to the user
        if notification.request.identifier.starts(with: "mend_refresh_before_") {
            // Refresh the recovery data before the actual notification appears
            Task {
                await RecoveryMetrics.shared.refreshWithReset()
                
                // After data is refreshed, update the corresponding notification with fresh data
                await updatePendingNotificationWithCurrentData(center: center, refreshIdentifier: notification.request.identifier)
                
                // Don't show the silent refresh notification
                completionHandler([])
            }
        } else {
            // For normal notifications, show alert and sound
            completionHandler([.banner, .sound, .badge])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        
        // If this is a refresh notification, just complete the handler
        if response.notification.request.identifier.starts(with: "mend_refresh_before_") {
            completionHandler()
            return
        }
        
        // For other notifications, process any needed actions here
        // (e.g., navigate to specific views if needed)
        
        completionHandler()
    }
    
    // Helper method to update the pending notification with fresh data
    private func updatePendingNotificationWithCurrentData(center: UNUserNotificationCenter, refreshIdentifier: String) async {
        // Extract hour from identifier (format is "mend_refresh_before_XX")
        let hour = refreshIdentifier.replacingOccurrences(of: "mend_refresh_before_", with: "")
        
        // Get the corresponding notification identifier
        let notificationIdentifier = "mend_recovery_\(hour)"
        
        // Get pending notification requests
        let pendingRequests = await center.pendingNotificationRequests()
        
        // Find the notification request to update
        guard let pendingNotification = pendingRequests.first(where: { $0.identifier == notificationIdentifier }) else {
            return
        }
        
        // Create a new notification with updated content
        let content = pendingNotification.content.mutableCopy() as! UNMutableNotificationContent
        
        // Update content with current recovery score
        if let recoveryMetrics = RecoveryMetrics.shared.currentRecoveryScore {
            content.title = pendingNotification.content.title
            content.body = "Your recovery score is \(recoveryMetrics.overallScore). \(RecoveryMetrics.scoreDescription(for: recoveryMetrics))"
        }
        
        // Create a new request with the updated content but same trigger
        let updatedRequest = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: pendingNotification.trigger
        )
        
        // Remove the old notification and add the updated one
        await center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        try? await center.add(updatedRequest)
    }
    
    // MARK: UISceneSession Lifecycle
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        let sceneConfig = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - State Preservation and Restoration
    
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        // Allow state preservation
        return true
    }
    
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        // Allow state restoration
        return true
    }
    
    // MARK: - Background Fetch
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Refresh data in the background
        Task {
            do {
                await RecoveryMetrics.shared.refreshData()
                completionHandler(.newData)
            } catch {
                print("Error refreshing data in background: \(error.localizedDescription)")
                completionHandler(.failed)
            }
        }
    }
} 