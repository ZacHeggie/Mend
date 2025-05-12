import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @StateObject private var activityManager = ActivityManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showScoreInTitle = false
    
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkBackground : MendColors.background
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sample data warning - positioned below navigation bar with improved visibility
                if recoveryMetrics.isShowingSampleData() && !recoveryMetrics.isLoading {
                    Text("No data available - showing sample data")
                        .font(MendFont.footnote.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, MendSpacing.medium)
                        .padding(.vertical, MendSpacing.small)
                        .frame(maxWidth: .infinity)
                        .background(MendColors.neutral)
                }
                
                // Main content
                ScrollView {
                    ScrollViewReader { scrollProxy in
                        if recoveryMetrics.isLoading {
                            VStack {
                                ProgressView()
                                    .padding()
                                Text("Loading recovery data...")
                                    .foregroundColor(secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else if let recoveryScore = recoveryMetrics.currentRecoveryScore {
                            VStack(spacing: MendSpacing.large) {
                                // Header with overall score
                                VStack(spacing: MendSpacing.medium) {
                                    Text("Today's Recovery")
                                        .font(MendFont.title)
                                        .foregroundColor(textColor)
                                        .id("titleHeader") // ID for scroll detection
                                    
                                    VStack(spacing: 0) {
                                        ScoreRing(score: recoveryScore.overallScore, size: 160, lineWidth: 15)
                                            .padding(.vertical, MendSpacing.medium)
                                        
                                        Text("Your body is \(recoveryScoreDescription(for: recoveryScore))")
                                            .font(MendFont.headline)
                                            .foregroundColor(textColor)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                            .padding(.bottom, MendSpacing.medium)
                                        
                                        // Add recovery history toggle
                                        Divider()
                                            .padding(.horizontal, MendSpacing.medium)
                                        
                                        // Show recovery history chart by default (no disclosure group)
                                        VStack(alignment: .leading) {
                                            //Text("28-Day History")
                                            //    .font(MendFont.subheadline)
                                            //    .foregroundColor(MendColors.primary)
                                            //    .padding(.horizontal, MendSpacing.small)
                                            //    .padding(.vertical, MendSpacing.small)
                                            
                                            RecoveryHistoryChart(
                                                history: recoveryMetrics.recoveryScoreHistory,
                                                colorScheme: colorScheme
                                            )
                                            .padding(.horizontal, MendSpacing.small)
                                            .padding(.vertical, MendSpacing.small)
                                        }
                                    }
                                    .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
                                    .cornerRadius(MendCornerRadius.medium)
                                    .padding(.horizontal, MendSpacing.medium)
                                }
                                .padding(.top, MendSpacing.large)
                                
                                // Metrics cards
                                VStack(spacing: MendSpacing.medium) {
                                    mendSectionHeader(title: "Your Metrics", colorScheme: colorScheme)
                                    
                                    // Training Load - use the same card as in ActivityView
                                    TrainingLoadCard(activityManager: activityManager, collapsible: true)
                                    
                                    // Heart Rate
                                    MetricCard(metric: recoveryScore.heartRateScore)
                                    
                                    // HRV
                                    if let hrvMetric = recoveryMetrics.hrvMetric {
                                        MetricCard(metric: hrvMetric)
                                    } else {
                                        MetricCard(metric: MetricScore.createHRVMetric(score: recoveryScore.hrvScore))
                                    }
                                    
                                    // Sleep Duration
                                    let sleepMetric = recoveryMetrics.sleepMetric ?? recoveryMetrics.createSleepMetric()
                                    MetricCard(metric: sleepMetric)
                                    
                                    // Sleep Quality
                                    let sleepQualityMetric = recoveryMetrics.sleepQualityMetric ?? recoveryMetrics.createSleepQualityMetric()
                                    MetricCard(metric: sleepQualityMetric)
                                }
                                .padding(.horizontal, MendSpacing.medium)
                            }
                            .padding(.bottom, 50)
                            .padding(.bottom, 50) // Add additional padding to ensure content isn't obscured by tab bar
                            .background(
                                // Use GeometryReader to detect when title is scrolled off screen
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(key: ScrollViewOffsetPreferenceKey.self, 
                                                    value: proxy.frame(in: .global).minY)
                                }
                                .frame(height: 0)
                            )
                            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { offset in
                                // Show score in title when scrolled past a certain point
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showScoreInTitle = offset < 100
                                }
                            }
                        } else {
                            VStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(MendColors.neutral)
                                    .padding()
                                
                                Text("No recovery data available")
                                    .font(.headline)
                                    .foregroundColor(textColor)
                                
                                Text("Try refreshing your data in Settings")
                                    .foregroundColor(secondaryTextColor)
                                
                                Button("Refresh Now") {
                                    Task {
                                        await recoveryMetrics.refreshWithReset()
                                    }
                                }
                                .padding(.vertical, MendSpacing.medium)
                                .padding(.horizontal, MendSpacing.large)
                                .background(MendColors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(MendCornerRadius.pill)
                                .padding(.top, MendSpacing.medium)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        }
                    }
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: colorScheme) { oldValue, newValue in
                // Force navigation title to update when color scheme changes
                let tempShow = showScoreInTitle
                showScoreInTitle = !tempShow
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showScoreInTitle = tempShow
                }
            }
            .onAppear {
                Task {
                    await recoveryMetrics.refreshWithReset()
                }
            }
            .refreshable {
                Task {
                    await recoveryMetrics.refreshData()
                }
            }
        }
    }
    
    private var navigationTitle: String {
        if showScoreInTitle, let score = recoveryMetrics.currentRecoveryScore {
            return "Dashboard • \(score.overallScore)"
        } else {
            return "Dashboard"
        }
    }
    
    func recoveryScoreDescription(for score: RecoveryScore) -> String {
        switch score.overallScore {
        case 0..<40:
            return "highly stressed. Focus on recovery today."
        case 40..<60:
            return "somewhat fatigued. Consider light activity."
        case 60..<80:
            return "reasonably recovered. Moderate training is fine."
        default:
            return "well recovered. You're ready for intense training."
        }
    }
}

// Preference key to track scroll position
struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    DashboardView()
        .environmentObject(RecoveryMetrics.shared)
} 
