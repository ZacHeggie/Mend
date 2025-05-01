//
//  MendApp.swift
//  Mend
//
//  Created by Zac Heggie on 4/14/25.
//

import SwiftUI
import HealthKit

@main
struct MendApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recoveryMetrics = RecoveryMetrics.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Configure the status bar appearance
        let colorScheme = UITraitCollection.current.userInterfaceStyle
        let statusBarBackgroundColor = colorScheme == .dark ? 
            UIColor(MendColors.darkBackground) : 
            UIColor(MendColors.background)
        
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = statusBarBackgroundColor
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // Set the status bar style
        let statusBarStyle: UIStatusBarStyle = colorScheme == .dark ? .lightContent : .darkContent
        UIApplication.shared.statusBarStyle = statusBarStyle
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recoveryMetrics)
                .onAppear {
                    // Perform a full refresh when app appears
                    refreshData()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        // App has become active (foreground)
                        refreshData()
                    case .background:
                        // App has moved to background
                        // Save state or perform cleanup if needed
                        break
                    case .inactive:
                        // App is inactive (transitioning between states)
                        break
                    @unknown default:
                        break
                    }
                }
        }
        .backgroundTask(.appRefresh("com.mend.dataRefresh")) {
            // This runs during a background app refresh
            refreshData()
        }
        // Handle user activity for state restoration
        .handlesExternalEvents(matching: ["com.mend.restorationActivity"])
    }
    
    // Helper function to refresh data using Task
    private func refreshData() {
        Task {
            await recoveryMetrics.refreshWithReset()
        }
    }
}

// Extension to apply status bar style
extension UIApplication {
    var statusBarStyle: UIStatusBarStyle {
        get { return .default }
        set {
            if #available(iOS 15.0, *) {
                // Use modern scene-based API for iOS 15+
                for scene in UIApplication.shared.connectedScenes {
                    if let windowScene = scene as? UIWindowScene {
                        for window in windowScene.windows {
                            window.overrideUserInterfaceStyle = newValue == .lightContent ? .dark : .light
                        }
                    }
                }
            } else {
                // Fallback for earlier iOS versions
                UIApplication.shared.windows.forEach { window in
                    window.overrideUserInterfaceStyle = newValue == .lightContent ? .dark : .light
                }
            }
        }
    }
}
