import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @StateObject private var activityManager = ActivityManager.shared
    @State private var recentActivities: [Activity] = []
    @State private var personalizedRecommendations: [ActivityRecommendation] = []
    
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
                    // Recovery Summary
                    VStack(spacing: MendSpacing.medium) {
                        HStack(spacing: MendSpacing.medium) {
                            ScoreRing(score: recoveryScore.overallScore, size: 80, lineWidth: 8)
                            
                            VStack(alignment: .leading, spacing: MendSpacing.small) {
                                Text("Recovery Score")
                                    .font(MendFont.headline)
                                    .foregroundColor(MendColors.text)
                                
                                Text("Your body is \(recoveryScoreDescription(for: recoveryScore))")
                                    .font(MendFont.body)
                                    .foregroundColor(MendColors.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding()
                        .background(MendColors.cardBackground)
                        .cornerRadius(MendCornerRadius.medium)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                    }
                    
                    // Recent Activities
                    if !recentActivities.isEmpty {
                        VStack(alignment: .leading, spacing: MendSpacing.medium) {
                            Text("Today's Activities")
                                .font(MendFont.headline)
                                .foregroundColor(MendColors.text)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: MendSpacing.medium) {
                                    ForEach(recentActivities) { activity in
                                        RecentActivityCard(activity: activity)
                                            .frame(width: 200)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Activity Recommendations
                    VStack(alignment: .leading, spacing: MendSpacing.medium) {
                        Text("Recommended Activities")
                            .font(MendFont.headline)
                            .foregroundColor(MendColors.text)
                        
                        // Show personalized recommendations if available, otherwise use basic recommendations
                        let recommendationsToShow = !personalizedRecommendations.isEmpty ? 
                                                   personalizedRecommendations : 
                                                   recoveryScore.recommendedActivities
                                                   
                        ForEach(recommendationsToShow) { activity in
                            RecommendedActivityCard(activity: activity)
                        }
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
        .navigationTitle("Today")
        .onAppear {
            loadRecentActivities()
            
            Task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        // Load recovery metrics
        await recoveryMetrics.refreshData()
        
        // Load personalized recommendations if we have a recovery score
        if let recoveryScore = recoveryMetrics.currentRecoveryScore {
            personalizedRecommendations = await recoveryScore.getPersonalizedRecommendations()
        }
    }
    
    private func loadRecentActivities() {
        // Filter only today's activities
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        recentActivities = activityManager.getRecentActivities(days: 1)
            .filter { calendar.isDateInToday($0.date) }
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

struct RecentActivityCard: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            // Header with icon and date
            HStack {
                Image(systemName: activity.type.icon)
                    .font(.title3)
                    .foregroundColor(activity.intensity.color)
                    .frame(width: 36, height: 36)
                    .background(activity.intensity.color.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
                
                Text(formatRelativeDate(activity.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Title
            Text(activity.title)
                .font(MendFont.headline)
                .foregroundColor(MendColors.text)
                .lineLimit(1)
            
            Spacer()
            
            // Stats at bottom
            HStack {
                if activity.distance != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "ruler")
                            .font(.caption)
                        Text(activity.formattedDistance ?? "")
                            .font(.caption)
                    }
                    .foregroundColor(MendColors.text.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(activity.formattedDuration)
                        .font(.caption)
                }
                .foregroundColor(MendColors.text.opacity(0.7))
            }
        }
        .padding()
        .frame(height: 120)
        .background(MendColors.cardBackground)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        }
    }
}

struct RecommendedActivityCard: View {
    let activity: ActivityRecommendation
    
    var body: some View {
        HStack(spacing: MendSpacing.medium) {
            // Icon
            Image(systemName: activity.icon)
                .font(.title)
                .foregroundColor(activity.intensity.color)
                .frame(width: 44, height: 44)
                .background(activity.intensity.color.opacity(0.1))
                .cornerRadius(MendCornerRadius.small)
            
            // Content
            VStack(alignment: .leading, spacing: MendSpacing.small) {
                HStack {
                    Text(activity.title)
                        .font(MendFont.headline)
                        .foregroundColor(MendColors.text)
                    
                    Text(activity.intensity.rawValue)
                        .font(MendFont.caption)
                        .foregroundColor(activity.intensity.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(activity.intensity.color.opacity(0.1))
                        .cornerRadius(MendCornerRadius.small)
                }
                
                Text(activity.description)
                    .font(MendFont.body)
                    .foregroundColor(MendColors.text.opacity(0.8))
                
                Text(activity.formattedDuration)
                    .font(MendFont.subheadline)
                    .foregroundColor(MendColors.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(MendColors.cardBackground)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

#Preview {
    NavigationView {
        TodayView()
            .environmentObject(RecoveryMetrics.shared)
    }
} 