//
//  AppDelegate.swift
//  Mend
//
//  Created by Zac Heggie on 4/14/25.
//

import UIKit
import HealthKit
import StripeApplePay
import BackgroundTasks

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize the health store
        HealthKitManager.shared.initializeHealthKit()
        
        // Initialize the stripe SDK
        configureStripe()
        
        // Register for background refresh
        setupBackgroundRefresh()
        
        return true
    }
    
    // Configure Stripe with the publishable key
    private func configureStripe() {
        // Use your actual publishable key here
        let publishableKey = "pk_test_yourPublishableKeyHere"
        StripeAPI.defaultPublishableKey = publishableKey
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
                try await RecoveryMetrics.shared.refreshData()
                
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
                try await RecoveryMetrics.shared.refreshData()
                completionHandler(.newData)
            } catch {
                print("Error refreshing data in background: \(error.localizedDescription)")
                completionHandler(.failed)
            }
        }
    }
} 