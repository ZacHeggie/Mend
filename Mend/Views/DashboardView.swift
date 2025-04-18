import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    
    var body: some View {
        ScrollView {
            if recoveryMetrics.isLoading {
                VStack {
                    ProgressView()
                        .padding()
                    Text("Loading recovery data...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else if let recoveryScore = recoveryMetrics.currentRecoveryScore {
                VStack(spacing: MendSpacing.large) {
                    // Header with overall score
                    VStack(spacing: MendSpacing.medium) {
                        Text("Today's Recovery")
                            .font(MendFont.title)
                            .foregroundColor(MendColors.text)
                        
                        ScoreRing(score: recoveryScore.overallScore, size: 160, lineWidth: 15)
                        
                        Text("Your body is \(recoveryScoreDescription(for: recoveryScore))")
                            .font(MendFont.headline)
                            .foregroundColor(MendColors.text)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, MendSpacing.large)
                    
                    // Metrics cards
                    VStack(spacing: MendSpacing.medium) {
                        Text("Your Metrics")
                            .font(MendFont.headline)
                            .foregroundColor(MendColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        MetricCard(metric: recoveryScore.heartRateScore)
                        
                        // Get HRV metric directly from the model
                        if let hrvMetric = recoveryMetrics.hrvMetric {
                            MetricCard(metric: hrvMetric)
                        } else {
                            MetricCard(metric: MetricScore.createHRVMetric(score: recoveryScore.hrvScore))
                        }
                        
                        // Get sleep metric directly from the model
                        if let sleepMetric = recoveryMetrics.sleepMetric {
                            MetricCard(metric: sleepMetric)
                        } else {
                            MetricCard(metric: MetricScore.createSleepMetric(score: recoveryScore.sleepScore))
                        }
                        
                        // Get sleep quality metric
                        if let sleepQualityMetric = recoveryMetrics.sleepQualityMetric {
                            MetricCard(metric: sleepQualityMetric)
                        }
                        
                        MetricCard(metric: recoveryScore.trainingLoadScore)
                    }
                }
                .padding()
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text("No recovery data available")
                        .font(.headline)
                    
                    Text("Try refreshing your data in Settings")
                        .foregroundColor(.secondary)
                    
                    Button("Refresh Now") {
                        Task {
                            await recoveryMetrics.refreshData()
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            }
        }
        .background(MendColors.background.ignoresSafeArea())
        .onAppear {
            Task {
                await recoveryMetrics.refreshData()
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