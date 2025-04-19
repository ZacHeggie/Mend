import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @StateObject private var activityManager = ActivityManager.shared
    @State private var recentActivities: [Activity] = []
    @State private var personalizedRecommendations: [ActivityRecommendation] = []
    @Environment(\.colorScheme) var colorScheme
    @State private var showingAddActivity = false
    
    // Computed properties for dynamic colors
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkBackground : MendColors.background
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                if recoveryMetrics.isLoading {
                    loadingView
                } else if let recoveryScore = recoveryMetrics.currentRecoveryScore {
                    VStack(spacing: MendSpacing.large) {
                        // Recovery Summary
                        recoveryScoreView(score: recoveryScore)
                        
                        // Recent Activities
                        if !recentActivities.isEmpty {
                            recentActivitiesView
                        }
                        
                        // Activity Recommendations
                        recommendationsView(score: recoveryScore)
                    }
                    .padding()
                    .padding(.bottom, 80) // Add extra padding at bottom for the FAB
                } else {
                    noDataView
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarItems(trailing: notificationButton)
            
            // Floating Action Button for adding activity
            Button(action: {
                showingAddActivity = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(MendColors.primary)
                    .clipShape(Circle())
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.bottom, 70) // Position above tab bar
            .padding(.trailing, 20)
        }
        .onAppear {
            loadRecentActivities()
            
            Task {
                await loadData()
            }
        }
        .sheet(isPresented: $showingAddActivity) {
            NavigationView {
                AddActivityView(isPresented: $showingAddActivity)
                    .navigationTitle("Add Activity")
                    .navigationBarItems(trailing: Button("Cancel") {
                        showingAddActivity = false
                    })
                    .environmentObject(activityManager)
            }
        }
    }
    
    // MARK: - Component Views
    
    private var loadingView: some View {
        VStack(spacing: MendSpacing.medium) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading recovery data...")
                .font(MendFont.subheadline)
                .foregroundColor(secondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var noDataView: some View {
        VStack(spacing: MendSpacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(MendColors.neutral)
                .padding()
            
            Text("No recovery data available")
                .font(MendFont.title3)
                .foregroundColor(textColor)
            
            Text("Try refreshing your data in Settings")
                .font(MendFont.subheadline)
                .foregroundColor(secondaryTextColor)
            
            Button("Refresh Now") {
                Task {
                    await recoveryMetrics.refreshData()
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
    
    private func recoveryScoreView(score: RecoveryScore) -> some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            Text("Today's Recovery")
                .font(MendFont.headline)
                .foregroundColor(secondaryTextColor)
                .padding(.horizontal, MendSpacing.medium)
            
            HStack(spacing: MendSpacing.large) {
                ScoreRing(score: score.overallScore, size: 90, lineWidth: 10)
                    .padding(.leading, MendSpacing.medium)
                
                VStack(alignment: .leading, spacing: MendSpacing.small) {
                    Text("\(score.overallScore)")
                        .font(MendFont.title)
                        .foregroundColor(textColor)
                    
                    Text(recoveryScoreDescription(for: score))
                        .font(MendFont.subheadline)
                        .foregroundColor(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.trailing, MendSpacing.medium)
            }
            .padding(.vertical, MendSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackgroundColor)
            .cornerRadius(MendCornerRadius.medium)
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
    
    private var recentActivitiesView: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            HStack {
                Text("Today's Activities")
                    .font(MendFont.headline)
                    .foregroundColor(secondaryTextColor)
                
                Spacer()
                
                Button(action: {
                    showingAddActivity = true
                }) {
                    Text("Add")
                        .font(MendFont.subheadline.weight(.medium))
                        .foregroundColor(MendColors.primary)
                }
            }
            .padding(.horizontal, MendSpacing.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MendSpacing.medium) {
                    ForEach(recentActivities) { activity in
                        RecentActivityCard(activity: activity, colorScheme: colorScheme)
                            .frame(width: 220)
                    }
                }
                .padding(.horizontal, MendSpacing.medium)
            }
        }
    }
    
    private func recommendationsView(score: RecoveryScore) -> some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            Text("Recommended Activities")
                .font(MendFont.headline)
                .foregroundColor(secondaryTextColor)
                .padding(.horizontal, MendSpacing.medium)
            
            // Show personalized recommendations if available, otherwise use basic recommendations
            let recommendationsToShow = !personalizedRecommendations.isEmpty ? 
                                       personalizedRecommendations : 
                                       score.recommendedActivities
                                       
            ForEach(recommendationsToShow) { activity in
                RecommendedActivityCard(activity: activity, colorScheme: colorScheme)
            }
        }
    }
    
    private var notificationButton: some View {
        Button(action: {
            // Notification action
        }) {
            Image(systemName: "bell")
                .font(.system(size: 18))
                .foregroundColor(textColor)
        }
    }
    
    // MARK: - Helper Functions
    
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
            return "Highly stressed. Focus on recovery today."
        case 40..<60:
            return "Somewhat fatigued. Consider light activity."
        case 60..<80:
            return "Reasonably recovered. Moderate training is fine."
        default:
            return "Well recovered. Ready for intense training."
        }
    }
}

// MARK: - Activity Cards

struct RecentActivityCard: View {
    let activity: Activity
    var colorScheme: ColorScheme
    
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
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            // Header with icon and date
            HStack {
                Image(systemName: activity.type.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(activity.intensity.color)
                    .clipShape(Circle())
                
                Spacer()
                
                Text(formatRelativeDate(activity.date))
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
            }
            
            // Title
            Text(activity.title)
                .font(MendFont.headline)
                .foregroundColor(textColor)
                .lineLimit(1)
            
            Spacer()
            
            // Stats at bottom
            HStack {
                if activity.distance != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "ruler")
                            .font(MendFont.caption)
                        Text(activity.formattedDistance ?? "")
                            .font(MendFont.caption)
                    }
                    .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(MendFont.caption)
                    Text(activity.formattedDuration)
                        .font(MendFont.caption)
                }
                .foregroundColor(secondaryTextColor)
            }
        }
        .padding()
        .frame(height: 130)
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
    var colorScheme: ColorScheme
    
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
        HStack(spacing: MendSpacing.medium) {
            // Activity Icon
            ZStack {
                Circle()
                    .fill(activity.intensity.color.opacity(colorScheme == .dark ? 0.3 : 0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: activity.icon)
                    .font(.system(size: 20))
                    .foregroundColor(activity.intensity.color)
            }
            .padding(.leading, MendSpacing.small)
            
            // Activity Details
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(MendFont.headline)
                    .foregroundColor(textColor)
                
                Text(activity.description)
                    .font(MendFont.subheadline)
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(secondaryTextColor)
                .padding(.trailing, MendSpacing.medium)
        }
        .padding(.vertical, MendSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// Helper for date formatting
func formatRelativeDate(_ date: Date) -> String {
    let calendar = Calendar.current
    
    if calendar.isDateInToday(date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        TodayView()
            .environmentObject(RecoveryMetrics.shared)
    }
} 