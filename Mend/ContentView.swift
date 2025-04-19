//
//  ContentView.swift
//  Mend
//
//  Created by Zac Heggie on 4/14/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @Environment(\.colorScheme) var systemColorScheme
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabView(selection: $selectedTab) {
                NavigationView {
                    TodayView()
                        .navigationBarTitleDisplayMode(.large)
                }
                .tag(0)
                
                NavigationView {
                    ActivityView()
                        .navigationBarTitleDisplayMode(.large)
                }
                .tag(1)
                
                NavigationView {
                    DashboardView()
                        .navigationBarTitleDisplayMode(.large)
                }
                .tag(2)
                
                NavigationView {
                    SettingsView()
                        .navigationBarTitleDisplayMode(.large)
                }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom tab bar - reduced height
            HStack(spacing: 0) {
                Spacer()
                
                // Today Tab
                tabButton(
                    icon: "calendar",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
                
                Spacer()
                
                // Activities Tab
                tabButton(
                    icon: "figure.run",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
                
                Spacer()
                
                // Recovery Tab
                tabButton(
                    icon: "heart.circle",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
                
                Spacer()
                
                // Settings Tab
                tabButton(
                    icon: "gear",
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 }
                )
                
                Spacer()
            }
            .padding(.vertical, 8) // Reduced padding for smaller height
            .background(
                systemColorScheme == .dark 
                    ? MendColors.darkCardBackground 
                    : MendColors.cardBackground
            )
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(systemColorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)),
                alignment: .top
            )
            .edgesIgnoringSafeArea(.bottom)
        }
        .tint(MendColors.primary)
    }
    
    private func tabButton(icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) { // Reduced spacing
                Image(systemName: icon)
                    .font(.system(size: 18)) // Smaller icon
                    .foregroundColor(isSelected ? 
                                     MendColors.primary : 
                                     (systemColorScheme == .dark ? .white.opacity(0.6) : .gray))
                
                // Indicator dot for selected tab
                Circle()
                    .fill(isSelected ? MendColors.primary : Color.clear)
                    .frame(width: 3, height: 3) // Smaller dot
            }
            .frame(height: 32) // Reduced height
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(RecoveryMetrics.shared)
}
