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
    @StateObject private var recoveryMetrics = RecoveryMetrics.shared
    @Environment(\.colorScheme) var colorScheme
    
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
