//
//  SceneDelegate.swift
//  Mend
//
//  Created by Zac Heggie on 4/14/25.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()
            .environmentObject(RecoveryMetrics.shared)
        
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
            
            // Perform full refresh when scene connects
            refreshData()
        }
        
        // Handle userActivity for state restoration
        if let userActivity = connectionOptions.userActivities.first {
            self.scene(scene, continue: userActivity)
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        refreshData()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Called when using Handoff or continuing state restoration
        if userActivity.activityType == "com.mend.restorationActivity" {
            // Restore app state if needed
            refreshData()
        }
    }
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        // Provide an activity for state restoration
        let activity = NSUserActivity(activityType: "com.mend.restorationActivity")
        activity.title = "Mend App State"
        return activity
    }
    
    // Helper function to refresh data using Task
    private func refreshData() {
        Task {
            await RecoveryMetrics.shared.refreshWithReset()
        }
    }
} 