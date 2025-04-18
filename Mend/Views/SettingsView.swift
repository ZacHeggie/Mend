import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var healthImporter = HealthDataImporter()
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @State private var showingFilePicker = false
    @State private var showingError = false
    @State private var isImporting = false
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
        colorScheme == .dark ? MendColors.darkText.opacity(0.7) : MendColors.secondaryText
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: MendSpacing.large) {
                // Data Section
                sectionCard(title: "Data Import") {
                    VStack(spacing: 0) {
                        settingsButton(
                            icon: "square.and.arrow.down",
                            text: "Import Apple Health Data",
                            action: { showingFilePicker = true }
                        )
                        .disabled(isImporting)
                        
                        if isImporting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Importing data...")
                                    .font(MendFont.subheadline)
                                    .foregroundColor(secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, MendSpacing.medium)
                            .padding(.horizontal, MendSpacing.medium)
                        }
                        
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
                        settingsButton(
                            icon: "arrow.clockwise",
                            text: "Refresh Health Data",
                            action: {
                                Task {
                                    await recoveryMetrics.refreshData()
                                }
                            }
                        )
                    }
                }
                
                #if DEBUG
                // Developer Options
                sectionCard(title: "Developer Options") {
                    Toggle("Use Simulated Data", isOn: $recoveryMetrics.useSimulatedData)
                        .toggleStyle(SwitchToggleStyle(tint: MendColors.primary))
                        .padding(.horizontal, MendSpacing.medium)
                        .padding(.vertical, MendSpacing.medium)
                        .onChange(of: recoveryMetrics.useSimulatedData) {
                            Task {
                                await recoveryMetrics.loadMetrics()
                            }
                        }
                }
                #endif
                
                // About Section
                sectionCard(title: "About") {
                    VStack(spacing: MendSpacing.small) {
                        HStack {
                            Text("Version")
                                .foregroundColor(textColor)
                            
                            Spacer()
                            
                            Text("1.0.0")
                                .foregroundColor(secondaryTextColor)
                        }
                        .padding(.horizontal, MendSpacing.medium)
                        .padding(.vertical, MendSpacing.medium)
                        
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
                        Text("Imported health data is processed locally on your device.")
                            .font(MendFont.footnote)
                            .foregroundColor(secondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, MendSpacing.medium)
                            .padding(.vertical, MendSpacing.medium)
                    }
                }
                
                // App Rating
                sectionCard(title: "Improve Mend") {
                    VStack(spacing: 0) {
                        settingsButton(
                            icon: "star.fill",
                            text: "Rate Mend on the App Store",
                            action: { /* Rating action */ }
                        )
                        
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
                        settingsButton(
                            icon: "megaphone.fill",
                            text: "Join affiliates program",
                            action: { /* Affiliates action */ }
                        )
                    }
                }
                
                // Support Section
                sectionCard(title: "Help") {
                    VStack(spacing: 0) {
                        settingsButton(
                            icon: "questionmark.circle.fill",
                            text: "Help center",
                            action: { /* Open help center */ }
                        )
                        
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
                        settingsButton(
                            icon: "ladybug.fill",
                            text: "Report a bug",
                            action: { /* Bug report */ }
                        )
                        
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
                        settingsButton(
                            icon: "lightbulb.fill",
                            text: "Request a feature",
                            action: { /* Feature request */ }
                        )
                    }
                }
                
                // Info Section
                sectionCard(title: "About") {
                    VStack(spacing: 0) {
                        settingsButton(
                            icon: "lock.fill",
                            text: "Privacy policy",
                            action: { /* Privacy policy */ }
                        )
                        
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .padding(.horizontal, MendSpacing.small)
                        
                        settingsButton(
                            icon: "heart.fill",
                            text: "Community guidelines",
                            action: { /* Community guidelines */ }
                        )
                    }
                }
                
                // App Version
                HStack {
                    Spacer()
                    Text("Mend for iOS - 1.0.0")
                        .font(MendFont.caption)
                        .foregroundColor(secondaryTextColor)
                    Spacer()
                }
                .padding(.vertical, MendSpacing.large)
                
                // Logout Button
                Button(action: {
                    // Logout action
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                        Text("LOGOUT")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MendSpacing.medium)
                    .background(Color.clear)
                    .foregroundColor(MendColors.negative)
                    .overlay(
                        RoundedRectangle(cornerRadius: MendCornerRadius.medium)
                            .stroke(MendColors.negative.opacity(0.5), lineWidth: 1)
                    )
                }
                .padding(.horizontal, MendSpacing.medium)
            }
            .padding()
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Account")
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                
                // Start import process
                isImporting = true
                
                Task {
                    do {
                        let activities = try await healthImporter.importHealthData(from: url)
                        await MainActor.run {
                            // Here you would update your app's data store with the new activities
                            print("Successfully imported \(activities.count) activities")
                            isImporting = false
                        }
                    } catch {
                        await MainActor.run {
                            isImporting = false
                            showingError = true
                        }
                    }
                }
                
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
                showingError = true
            }
        }
        .alert("Import Error",
               isPresented: $showingError,
               actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(healthImporter.error?.description ?? "Failed to import health data")
        })
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            Text(title)
                .font(MendFont.headline)
                .foregroundColor(secondaryTextColor)
                .padding(.horizontal, MendSpacing.medium)
            
            content()
                .background(cardBackgroundColor)
                .cornerRadius(MendCornerRadius.medium)
        }
    }
    
    private func settingsButton(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: MendSpacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(MendColors.primary)
                    .frame(width: 24, height: 24)
                
                Text(text)
                    .font(MendFont.body)
                    .foregroundColor(textColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.horizontal, MendSpacing.medium)
            .padding(.vertical, MendSpacing.medium)
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(RecoveryMetrics.shared)
    }
} 