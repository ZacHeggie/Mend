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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recoveryMetrics)
        }
    }
}
