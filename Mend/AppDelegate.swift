//
//  AppDelegate.swift
//  Mend
//
//  Created by Zac Heggie on 4/14/25.
//

import UIKit
import BackgroundTasks

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register for background refresh tasks
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.mend.dataRefresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session
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
    
    // MARK: - Background Tasks
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.mend.dataRefresh")
        // Request a refresh no earlier than 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch let error {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule a new refresh task
        scheduleAppRefresh()
        
        // Set up a task expiration handler
        let refreshTask = Task { 
            await RecoveryMetrics.shared.refreshWithReset() 
        }
        
        task.expirationHandler = {
            refreshTask.cancel()
        }
        
        // Inform the system when the refresh task is complete
        Task {
            // Complete the background task after the refresh is done
            let _ = await refreshTask.result
            task.setTaskCompleted(success: true)
        }
    }
} 