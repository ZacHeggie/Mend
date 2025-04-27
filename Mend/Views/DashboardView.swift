import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @Environment(\.colorScheme) var colorScheme
    
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
        ScrollView {
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
                        
                        ScoreRing(score: recoveryScore.overallScore, size: 160, lineWidth: 15)
                        
                        Text("Your body is \(recoveryScoreDescription(for: recoveryScore))")
                            .font(MendFont.headline)
                            .foregroundColor(textColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, MendSpacing.large)
                    
                    // Metrics cards
                    VStack(spacing: MendSpacing.medium) {
                        Text("Your Metrics")
                            .font(MendFont.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        MetricCard(metric: recoveryScore.heartRateScore)
                        
                        // Get HRV metric directly from the model
                        if let hrvMetric = recoveryMetrics.hrvMetric {
                            MetricCard(metric: hrvMetric)
                        } else {
                            MetricCard(metric: MetricScore.createHRVMetric(score: recoveryScore.hrvScore))
                        }
                        
                        // Always show Sleep Duration - use actual data or create a placeholder
                        let sleepMetric = recoveryMetrics.sleepMetric ?? recoveryMetrics.createSleepMetric()
                        MetricCard(metric: sleepMetric)
                        
                        // Always show Sleep Quality - use actual data or create a placeholder
                        let sleepQualityMetric = recoveryMetrics.sleepQualityMetric ?? recoveryMetrics.createSleepQualityMetric()
                        MetricCard(metric: sleepQualityMetric)
                        
                        MetricCard(metric: recoveryScore.trainingLoadScore)
                    }
                }
                .padding()
                .padding(.bottom, 50)
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
                            recoveryMetrics.refreshData()
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
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .onAppear {
            Task {
                recoveryMetrics.refreshData()
            }
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

#Preview {
    DashboardView()
        .environmentObject(RecoveryMetrics.shared)
} 
