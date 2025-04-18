//
//  ContentView.swift
//  Mend
//
//  Created by Zac Heggie on 4/14/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationView {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "calendar")
            }
            
            NavigationView {
                ActivityView()
            }
            .tabItem {
                Label("Activities", systemImage: "figure.run")
            }
            
            NavigationView {
                DashboardView()
            }
            .tabItem {
                Label("Recovery", systemImage: "heart.circle")
            }
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .tint(MendColors.primary)
    }
}

#Preview {
    ContentView()
}
