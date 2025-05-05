import SwiftUI
import UniformTypeIdentifiers
import PassKit
import UIKit

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
    @State private var showTipJar = false
    @State private var devModeClickCount = 0  // Track clicks to enable dev mode
    @ObservedObject private var developerSettings = DeveloperSettings.shared
    
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
            Spacer()
            VStack(spacing: 10) {
                // ACCOUNT section
                mendSectionHeader(title: "ACCOUNT", colorScheme: colorScheme)
                    .onTapGesture(count: 5) {
                        developerSettings.isDeveloperMode.toggle()
                        devModeClickCount = 0
                    }
                
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
                
                // Only show Simulated Data Settings if developer mode is enabled
                if developerSettings.isDeveloperMode {
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
                }
                
                // IMPROVE MEND section
                mendSectionHeader(title: "IMPROVE MEND", colorScheme: colorScheme)
                
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
                mendSectionHeader(title: "ABOUT", colorScheme: colorScheme)
                
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
                Text("Mend for iOS - 1.0.8")
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
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .toolbarBackground(backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: colorScheme) { oldValue, newValue in
            // Force UI to update when color scheme changes
            let needsToRefreshUI = true
            if needsToRefreshUI {
                Task {
                    // Short delay to let system complete theme change
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
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
    @State private var showingThankYou = false
    @State private var processingPayment = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedTipIndex: Int = 0
    
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkBackground : MendColors.background
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private let tipService = StripePaymentService.shared
    private let tipAmounts = ["£0.99", "£2.99", "£4.99", "£9.99"]
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Support Mend")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(textColor)
                    .padding(.top, 40)
                
                Text("Your support helps us continue to build and improve Mend. Thank you for your generosity!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(textColor)
                    .padding(.horizontal)
                
                // Tip amount selector
                VStack(spacing: 12) {
                    ForEach(0..<tipAmounts.count, id: \.self) { index in
                        Button(action: {
                            selectedTipIndex = index
                        }) {
                            HStack {
                                Text(tipAmounts[index])
                                    .font(.title3)
                                    .bold()
                                
                                Spacer()
                                
                                if selectedTipIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(cardBackgroundColor)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                // Apple Pay button
                if StripePaymentService.shared.isApplePayAvailable() {
                    ApplePayButton {
                        processPayment()
                    }
                    .frame(height: 45)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .opacity(processingPayment ? 0.5 : 1.0)
                    .disabled(processingPayment)
                } else {
                    Text("Apple Pay is not available on this device")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Payment Error"),
                    message: Text(errorMessage ?? "There was a problem processing your payment."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(
                Group {
                    if processingPayment {
                        ZStack {
                            Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text("Processing payment...")
                                    .foregroundColor(.white)
                                    .padding(.top)
                            }
                            .padding(30)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(15)
                        }
                    }
                    
                    if showingThankYou {
                        ZStack {
                            Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)
                            VStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.pink)
                                
                                Text("Thank You!")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(textColor)
                                    .padding(.top)
                                
                                Text("Your support means a lot to us.")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(textColor)
                                
                                Button(action: {
                                    showingThankYou = false
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Text("Done")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .padding(.top, 20)
                            }
                            .padding(30)
                            .background(cardBackgroundColor)
                            .cornerRadius(15)
                            .shadow(radius: 10)
                            .padding(30)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3))
                    }
                }
            )
        }
        .onAppear {
            // Set up payment callbacks
            tipService.onPaymentSuccess = {
                DispatchQueue.main.async {
                    processingPayment = false
                    showingThankYou = true
                }
            }
            
            tipService.onPaymentFailure = { error in
                DispatchQueue.main.async {
                    processingPayment = false
                    errorMessage = error?.localizedDescription ?? "Payment was cancelled"
                    showingError = true
                }
            }
        }
    }
    
    private func processPayment() {
        processingPayment = true
        let amount = tipService.tipAmounts[selectedTipIndex]
        
        tipService.presentApplePay(amount: amount) { success, error in
            // Since the payment is now handled via callbacks, we don't need to handle it here
            if !success {
                DispatchQueue.main.async {
                    self.processingPayment = false
                    self.errorMessage = error?.localizedDescription ?? "Payment could not be processed"
                    self.showingError = true
                }
            }
        }
    }
}

// Apple Pay Button using UIKit representable
struct ApplePayButton: UIViewRepresentable {
    var onPaymentMethodCreation: () -> Void
    
    func makeUIView(context: Context) -> some UIView {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: colorScheme(for: context))
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // No updates needed - button style is set when created
        // If we need to recreate with different style, SwiftUI will call makeUIView again
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        var parent: ApplePayButton
        
        init(parent: ApplePayButton) {
            self.parent = parent
        }
        
        @objc func buttonTapped() {
            parent.onPaymentMethodCreation()
        }
    }
    
    private func colorScheme(for context: Context) -> PKPaymentButtonStyle {
        return context.environment.colorScheme == .dark ? .white : .black
    }
}

struct TipOption {
    let name: String
    let price: String
    let amount: Double
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
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @StateObject private var activityManager = ActivityManager.shared
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var developerSettings = DeveloperSettings.shared
    
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkBackground : MendColors.cardBackground
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
                        
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
                        // Add toggle for showing all activity recommendations
                        Toggle("Show All Activity Recommendations", isOn: $developerSettings.showAllActivityRecommendations)
                            .toggleStyle(SwitchToggleStyle(tint: MendColors.primary))
                            .padding(.horizontal, MendSpacing.medium)
                            .padding(.vertical, MendSpacing.medium)
                            .onChange(of: developerSettings.showAllActivityRecommendations) { oldValue, newValue in
                                Task {
                                    // Force refresh to update recommendations
                                    await recoveryMetrics.refreshWithReset()
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
                            
                            Text("• Show All Recommendations: Displays all possible activity recommendation cards for testing")
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
                        // Developer mode status
                        HStack {
                            Text("Developer Mode")
                                .font(MendFont.body)
                                .foregroundColor(textColor)
                            
                            Spacer()
                            
                            Text(developerSettings.isDeveloperMode ? "Enabled" : "Disabled")
                                .font(MendFont.body)
                                .foregroundColor(developerSettings.isDeveloperMode ? MendColors.positive : secondaryTextColor)
                        }
                        .padding(.horizontal, MendSpacing.medium)
                        
                        if developerSettings.isDeveloperMode {
                            Divider()
                                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                .padding(.horizontal, MendSpacing.small)
                            
                            // Toggle for random variations
                            Toggle("Use Random Variations", isOn: Binding(
                                get: { developerSettings.useRandomVariation },
                                set: { developerSettings.useRandomVariation = $0 }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: MendColors.primary))
                            .padding(.horizontal, MendSpacing.medium)
                            
                            Text("When enabled, adds natural daily variations to recovery scores. Disable for consistent scores based only on real data.")
                                .font(MendFont.footnote)
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, MendSpacing.medium)
                                .padding(.bottom, MendSpacing.small)
                            
                            // Button to regenerate history with current settings
                            Button(action: {
                                Task {
                                    // Force regeneration of historical data
                                    await recoveryMetrics.generateHistoricalRecoveryScores(forceGeneration: true)
                                }
                            }) {
                                Text("Regenerate Historical Data")
                                    .font(MendFont.body)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(MendColors.primary)
                                    .cornerRadius(MendCornerRadius.medium)
                            }
                        } else {
                            // Update instruction text - developer mode is now controlled from Settings
                            Text("Developer Mode can be enabled from the main Settings screen")
                                .font(MendFont.footnote)
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, MendSpacing.medium)
                        }
                        
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
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
