import SwiftUI
import UniformTypeIdentifiers

// Add a minimal UserViewModel implementation
class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    
    func signOut() {
        // For demo purposes, just set the user to nil
        currentUser = nil
    }
}

struct User {
    let displayName: String
    let email: String
}

struct SettingsView: View {
    @StateObject private var healthImporter = HealthDataImporter()
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @State private var showingFilePicker = false
    @State private var showingError = false
    @State private var isImporting = false
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var userViewModel = UserViewModel()
    @State private var showingTipJar = false
    
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkBackground : MendColors.background
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    @State private var showingLogoutAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ACCOUNT section
                sectionHeader(title: "ACCOUNT")
                
                SectionCard {
                    Button(action: {
                        // Refresh health data with full reset to ensure proper recalculation
                        Task {
                            await recoveryMetrics.refreshWithReset()
                        }
                    }) {
                        menuRow(icon: "arrow.clockwise", title: "Refresh Health Data", showArrow: false)
                    }
                }
                
                SectionCard {
                    NavigationLink(destination: SimulatedDataSettings()) {
                        HStack {
                            menuRow(icon: "chart.line.uptrend.xyaxis", title: "Simulated Data Settings", showArrow: true)
                            Spacer()
                            Text(recoveryMetrics.useSimulatedData ? "On" : "Off")
                                .foregroundColor(secondaryTextColor)
                                .font(MendFont.body)
                        }
                    }
                }
                
                // IMPROVE MEND section
                sectionHeader(title: "IMPROVE MEND")
                
                SectionCard {
                    NavigationLink(destination: ReportBugView()) {
                        menuRow(icon: "ant.fill", title: "Report a bug", showArrow: true)
                    }
                    Divider()
                    NavigationLink(destination: FeatureRequestView()) {
                        menuRow(icon: "lightbulb.fill", title: "Request a feature", showArrow: true)
                    }
                    Divider()
                    Button(action: {
                        showingTipJar = true
                    }) {
                        menuRow(icon: "cup.and.saucer.fill", title: "Tip jar", showArrow: true)
                    }
                    .sheet(isPresented: $showingTipJar) {
                        TipJarView()
                    }
                }
                
                // ABOUT section
                sectionHeader(title: "ABOUT")
                
                SectionCard {
                    NavigationLink(destination: HelpCenterView()) {
                        menuRow(icon: "questionmark.circle.fill", title: "Help center", showArrow: true)
                    }
                    Divider()
                    NavigationLink(destination: PrivacyPolicyView()) {
                        menuRow(icon: "lock.fill", title: "Privacy policy", showArrow: true)
                    }
                }
                
                // DEVELOPER TESTING section - Only in debug mode
                #if DEBUG
                // Removed the developer testing section from the main settings menu
                #endif
                
                // Version at the bottom
                Text("Mend for iOS - 1.0.5")
                    .font(MendFont.footnote)
                    .foregroundColor(secondaryTextColor)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Add extra padding at the bottom to ensure content isn't obscured by tab bar
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(MendFont.caption)
                .foregroundColor(secondaryTextColor)
                .padding(.vertical, 10)
                .padding(.leading, 10)
            Spacer()
        }
    }
    
    private func menuRow(icon: String, title: String, showArrow: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MendColors.primary)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(MendFont.body)
                .foregroundColor(textColor)
                .padding(.leading, 4)
            
            Spacer()
            
            if showArrow {
                Image(systemName: "chevron.right")
                    .foregroundColor(secondaryTextColor)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 12)
    }
}

struct TipJarView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkBackground : MendColors.background
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    let tipOptions = [
        TipOption(name: "Small Tip", price: "$0.99", icon: "cup.and.saucer.fill"),
        TipOption(name: "Medium Tip", price: "$2.99", icon: "mug.fill"),
        TipOption(name: "Large Tip", price: "$4.99", icon: "wineglass.fill"),
        TipOption(name: "Generous Tip", price: "$9.99", icon: "gift.fill")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50))
                            .foregroundColor(MendColors.primary)
                            .padding()
                        
                        Text("Support Mend")
                            .font(MendFont.title)
                            .fontWeight(.bold)
                            .foregroundColor(textColor)
                        
                        Text("Your support helps us continue to develop and improve Mend with new features and regular updates. Thank you for your generosity!")
                            .font(MendFont.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Tip options
                    VStack(spacing: 16) {
                        ForEach(tipOptions, id: \.name) { option in
                            Button(action: {
                                // In a real app, this would trigger the in-app purchase
                                print("Processing purchase: \(option.name)")
                            }) {
                                HStack {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(MendColors.primary)
                                        .frame(width: 40, height: 40)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.name)
                                            .font(MendFont.headline)
                                            .foregroundColor(textColor)
                                        
                                        Text("One-time purchase")
                                            .font(MendFont.caption)
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(option.price)
                                        .font(MendFont.headline)
                                        .foregroundColor(MendColors.primary)
                                }
                                .padding()
                                .background(cardBackgroundColor)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Note
                    Text("All tips are one-time purchases and do not include any subscriptions or recurring charges.")
                        .font(MendFont.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }
                .padding(.bottom, 30)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Tip Jar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct TipOption {
    let name: String
    let price: String
    let icon: String
}

struct SectionCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : .white
    }
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 16)
        }
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .padding(.vertical, 6)
    }
}

// MARK: - Simulated Data Settings
struct SimulatedDataSettings: View {
    @EnvironmentObject var recoveryMetrics: RecoveryMetrics
    @StateObject private var activityManager = ActivityManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkBackground : MendColors.background
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: MendSpacing.large) {
                // Main simulated data toggle
                VStack(spacing: 0) {
                    Toggle("Use Simulated Data", isOn: $recoveryMetrics.useSimulatedData)
                        .toggleStyle(SwitchToggleStyle(tint: MendColors.primary))
                        .padding(.horizontal, MendSpacing.medium)
                        .padding(.vertical, MendSpacing.medium)
                        .onChange(of: recoveryMetrics.useSimulatedData) { oldValue, newValue in
                            Task {
                                await recoveryMetrics.loadMetrics()
                            }
                        }
                    
                    if recoveryMetrics.useSimulatedData {
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
                        // Recovery state toggle
                        Toggle("Show Low Recovery State", isOn: $recoveryMetrics.usePoorRecoveryData)
                            .toggleStyle(SwitchToggleStyle(tint: MendColors.primary))
                            .padding(.horizontal, MendSpacing.medium)
                            .padding(.vertical, MendSpacing.medium)
                            .onChange(of: recoveryMetrics.usePoorRecoveryData) { oldValue, newValue in
                                Task {
                                    await recoveryMetrics.loadMetrics()
                                }
                            }
                        
                        // Info about the simulated data
                        VStack(alignment: .leading, spacing: MendSpacing.small) {
                            Text("Simulated Data Information:")
                                .font(MendFont.subheadline.bold())
                                .foregroundColor(textColor)
                                .padding(.top, MendSpacing.small)
                                
                            Text("• Standard: Simulates a normal recovery state with typical metrics")
                                .font(MendFont.footnote)
                                .foregroundColor(secondaryTextColor)
                                
                            Text("• Low Recovery: Simulates a stressed or fatigued state with elevated heart rate, lower HRV, and reduced sleep quality")
                                .font(MendFont.footnote)
                                .foregroundColor(secondaryTextColor)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, MendSpacing.medium)
                        .padding(.bottom, MendSpacing.medium)
                    }
                }
                .background(cardBackgroundColor)
                .cornerRadius(MendCornerRadius.medium)
                
                // Developer tools section
                VStack(alignment: .leading, spacing: MendSpacing.small) {
                    Text("Developer Tools")
                        .font(MendFont.headline)
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal)
                    
                    VStack(spacing: MendSpacing.medium) {
                        // Toggle simulated data
                        Button(action: {
                            recoveryMetrics.toggleSimulatedData()
                        }) {
                            Text(recoveryMetrics.useSimulatedData ? "Using Simulated Data" : "Use Simulated Data")
                                .font(MendFont.body)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(recoveryMetrics.useSimulatedData ? MendColors.primary : MendColors.primary)
                                .cornerRadius(MendCornerRadius.medium)
                        }
                        
                        // Toggle poor recovery simulation
                        Button(action: {
                            recoveryMetrics.togglePoorRecoveryData()
                        }) {
                            Text(recoveryMetrics.usePoorRecoveryData ? "Using Poor Recovery Data" : "Simulate Poor Recovery")
                                .font(MendFont.body)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(recoveryMetrics.usePoorRecoveryData ? MendColors.negative : MendColors.primary)
                                .cornerRadius(MendCornerRadius.medium)
                        }
                        
                        // Add Test Activity
                        Button(action: {
                            // Add a test activity
                            let _ = activityManager.addTestActivity()
                            // Refresh data to trigger recovery score update
                            Task {
                                await recoveryMetrics.refreshWithReset()
                            }
                        }) {
                            Text("Add Test Activity")
                                .font(MendFont.body)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(MendColors.primary)
                                .cornerRadius(MendCornerRadius.medium)
                        }
                        
                        // Add High Intensity Activity
                        Button(action: {
                            // Add a high intensity test activity
                            let _ = activityManager.addTestActivity(intensity: .high)
                            // Refresh data to trigger recovery score update
                            Task {
                                await recoveryMetrics.refreshWithReset()
                            }
                        }) {
                            Text("Add High Intensity Activity")
                                .font(MendFont.body)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(MendColors.primary)
                                .cornerRadius(MendCornerRadius.medium)
                        }
                        
                        // Simulate a new recent activity to test cool-down
                        Button(action: {
                            simulateRecentActivity()
                        }) {
                            Text("Simulate Recent Activity")
                                .font(MendFont.body)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(MendColors.primary)
                                .cornerRadius(MendCornerRadius.medium)
                        }
                        
                        // Reset Processed Activities
                        Button(action: {
                            // No more cooldown processing needed
                            // Just refresh data
                            Task {
                                await recoveryMetrics.refreshWithReset()
                            }
                        }) {
                            Text("Reset Data Processing")
                                .font(MendFont.body)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(MendColors.primary)
                                .cornerRadius(MendCornerRadius.medium)
                        }
                    }
                    .padding()
                    .background(cardBackgroundColor)
                    .cornerRadius(MendCornerRadius.medium)
                }
                
                // Refresh button
                Button {
                    Task {
                        await recoveryMetrics.refreshWithReset()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MendSpacing.medium)
                    .background(MendColors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(MendCornerRadius.medium)
                }
                .padding(.top, MendSpacing.small)
            }
            .padding()
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Simulated Data")
    }
    
    private func simulateRecentActivity() {
        // Create a recent high-intensity activity
        let activity = Activity(
            id: UUID(),
            title: "Test Activity",
            type: .run,
            date: Date().addingTimeInterval(-10 * 60), // 10 minutes ago
            duration: 3600, // 1 hour
            distance: 10.0,
            intensity: .high,
            source: .manual
        )
        
        // Add to activity manager
        activityManager.addActivity(activity)
        
        // Refresh data
        Task {
            await recoveryMetrics.refreshWithReset()
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(RecoveryMetrics.shared)
    }
} 
