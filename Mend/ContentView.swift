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
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    
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
            .onAppear {
                configureNavigationBarAppearance()
            }
            
            // Custom tab bar - reduced height
            HStack(spacing: 0) {
                tabButton(icon: "calendar", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                tabButton(icon: "figure.run", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                tabButton(icon: "chart.line.uptrend.xyaxis", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                
                tabButton(icon: "gear", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10) // Less top padding
            .padding(.bottom, 20) // Keep bottom padding for home indicator
            .background(
                // Semi-transparent background with blur for tab bar
                Color.black.opacity(systemColorScheme == .dark ? 0.7 : 0.05)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
    
    // Function to configure navigation bar appearance
    private func configureNavigationBarAppearance() {
        let appearanceStandard = UINavigationBarAppearance()
        let appearanceScrollEdge = UINavigationBarAppearance()
        
        // Configure standard appearance
        appearanceStandard.configureWithOpaqueBackground()
        appearanceStandard.backgroundColor = systemColorScheme == .dark ? 
                                             UIColor(MendColors.darkBackground) : 
                                             UIColor(MendColors.background)
        
        // Ensure title text is always visible
        appearanceStandard.titleTextAttributes = [
            .foregroundColor: systemColorScheme == .dark ? 
                               UIColor.white : 
                               UIColor.black
        ]
        appearanceStandard.largeTitleTextAttributes = [
            .foregroundColor: systemColorScheme == .dark ? 
                               UIColor.white : 
                               UIColor.black
        ]
        
        // Configure scroll edge appearance (large title)
        appearanceScrollEdge.configureWithOpaqueBackground()
        appearanceScrollEdge.backgroundColor = systemColorScheme == .dark ? 
                                              UIColor(MendColors.darkBackground) : 
                                              UIColor(MendColors.background)
        
        // Ensure large title text is always visible
        appearanceScrollEdge.titleTextAttributes = [
            .foregroundColor: systemColorScheme == .dark ? 
                              UIColor.white : 
                              UIColor.black
        ]
        appearanceScrollEdge.largeTitleTextAttributes = [
            .foregroundColor: systemColorScheme == .dark ? 
                              UIColor.white : 
                              UIColor.black
        ]
        
        // Apply the appearance
        UINavigationBar.appearance().standardAppearance = appearanceStandard
        UINavigationBar.appearance().compactAppearance = appearanceStandard
        UINavigationBar.appearance().scrollEdgeAppearance = appearanceScrollEdge
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
