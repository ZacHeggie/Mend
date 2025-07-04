import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var recoveryMetrics: RecoveryMetrics
    @StateObject private var activityManager = ActivityManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var recentActivities: [Activity] = []
    @State private var personalizedRecommendations: [ActivityRecommendation] = []
    @State private var recoveryInsights: [RecoveryInsight] = []
    @Environment(\.colorScheme) var colorScheme
    @State private var showingAddActivity = false
    @State private var showingNotificationMenu = false
    @State private var selectedInsight: RecoveryInsight?
    @State private var refreshing = false
    
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
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        VStack(spacing: MendSpacing.large) {
                            if recoveryMetrics.isLoading {
                                // Show loading view while data is being fetched
                                loadingView
                            } else if let score = recoveryMetrics.currentRecoveryScore {
                                // Only show the score when we have valid data
                                recoveryScoreView(score: score)
                                
                                // Recent activities from the last 24 hours
                                if !recentActivities.isEmpty {
                                    recentActivitiesView
                                }
                                
                                // Activity recommendations
                                recommendationsSection
                                
                                // Recovery insights
                                if !recoveryInsights.isEmpty {
                                    insightsSection
                                }
                            } else {
                                // Show no data view when loading is complete but no data is available
                                noDataView
                            }
                        }
                        .padding(.vertical)
                        .padding(.bottom, 100) // Add extra padding at the bottom to prevent content from being obscured by tab bar
                    }
                    
                    // Only show the add activity button when we're not loading
                    if !recoveryMetrics.isLoading {
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
                        .padding(.trailing, 20)
                        .padding(.bottom, 70)
                    }
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarItems(trailing: notificationButton)
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
                        await MainActor.run {
                            // This will trigger a UI refresh
                            loadRecentActivities()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await refreshData()
                }
            }
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showingAddActivity) {
                NavigationView {
                    AddActivityView(isPresented: $showingAddActivity)
                        .navigationTitle("Add Activity")
                        .navigationBarItems(leading: Button("Cancel") {
                            showingAddActivity = false
                        })
                        .environmentObject(activityManager)
                        .onDisappear {
                            // Refresh data when activity sheet is dismissed
                            Task {
                                await recoveryMetrics.refreshWithReset()
                                loadRecentActivities()
                            }
                        }
                }
            }
            
            .sheet(item: $selectedInsight) { insight in
                VStack {
                    Text(insight.title)
                        .font(MendFont.title)
                    Text(insight.detailedDescription)
                        .font(MendFont.body)
                    Spacer()
                }
                .padding()
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
            
            Button("Refresh") {
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
    
    private func recoveryScoreView(score: RecoveryScore) -> some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            HStack {
                mendSectionHeader(title: "Today's Recovery", colorScheme: colorScheme)
                Spacer()
            }
            .padding(.horizontal, MendSpacing.medium)
            
            VStack(spacing: 0) {
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
                
                RecoveryHistoryToggle()
            }
            .background(cardBackgroundColor)
            .cornerRadius(MendCornerRadius.medium)
            .padding(.horizontal, MendSpacing.medium)
        }
    }
    
    @ViewBuilder
    private func RecoveryHistoryToggle() -> some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, MendSpacing.medium)

            DisclosureGroup {
                RecoveryHistoryChart(
                    history: recoveryMetrics.recoveryScoreHistory,
                    colorScheme: colorScheme
                )
                .padding(.horizontal, MendSpacing.medium)
                .padding(.vertical, MendSpacing.small)
            } label: {
                HStack {
                    Text("View 4-Week History")
                        .font(MendFont.subheadline)
                        .foregroundColor(MendColors.primary)
                    
                    Spacer()
                    
                    // The arrow icon will be automatically added by DisclosureGroup
                    // but we need to make sure it doesn't overlap with the edge
                }
                .padding(.horizontal, MendSpacing.medium)
                .padding(.vertical, MendSpacing.small)
            }
            .padding(.trailing, MendSpacing.medium) // Add extra padding on the trailing edge to ensure chevron doesn't overlap
        }
    }
    
    private var recentActivitiesView: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            ZStack {
                HStack {
                    mendSectionHeader(title: "Today's Activities", colorScheme: colorScheme)
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddActivity = true
                    }) {
                        Text("Add")
                            .font(MendFont.subheadline.weight(.medium))
                            .foregroundColor(MendColors.primary)
                    }
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
            mendSectionHeader(title: "Recommended Activities", colorScheme: colorScheme)
            
            // Show personalized recommendations if available, otherwise use basic recommendations
            let recommendationsToShow = !personalizedRecommendations.isEmpty ? 
                                       personalizedRecommendations : 
                                       score.recommendedActivities
                                       
            ForEach(recommendationsToShow) { activity in
                ExpandableActivityCard(activity: activity, colorScheme: colorScheme)
            }
        }
    }
    
    private var recoveryInsightsView: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            mendSectionHeader(title: "Recovery Insights", colorScheme: colorScheme)
            
            ForEach(recoveryInsights) { insight in
                RecoveryInsightCard(insight: insight, colorScheme: colorScheme)
            }
        }
    }
    
    private var notificationButton: some View {
        Button(action: {
            showingNotificationMenu.toggle()
        }) {
            Image(systemName: "bell")
                .font(.system(size: 18))
                .foregroundColor(textColor)
        }
        .popover(isPresented: $showingNotificationMenu, arrowEdge: .top) {
            NotificationMenuView(
                notificationManager: notificationManager,
                isPresented: $showingNotificationMenu,
                colorScheme: colorScheme,
                recoveryScore: recoveryMetrics.currentRecoveryScore
            )
            .presentationCompactAdaptation(.popover)
        }
    }
    
    // MARK: - Helper Functions
    
    private func refreshData() async {
        refreshing = true
        // Start by setting loading state
        if !recoveryMetrics.isInitialLoadComplete {
            // Don't need to do anything here, as the initial load is already in progress
            return
        }
        
        // Refresh recovery metrics - use await to ensure we wait for completion
        await recoveryMetrics.refreshWithReset()
        
        // Update activities
        await activityManager.refreshActivities()
        loadRecentActivities()
        
        // Load personalized recommendations if we have a recovery score
        if let recoveryScore = recoveryMetrics.currentRecoveryScore {
            personalizedRecommendations = await recoveryScore.getPersonalizedRecommendations()
        }
        
        // Refresh recovery insights
        loadRecoveryInsights()
        refreshing = false
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
        // Filter activities from the last 24 hours
        let calendar = Calendar.current
        let now = Date()
        let twentyFourHoursAgo = calendar.date(byAdding: .hour, value: -24, to: now)!
        
        recentActivities = activityManager.getRecentActivities(days: 2) // Get 2 days to ensure we have all data
            .filter { $0.date >= twentyFourHoursAgo && $0.date <= now }
    }
    
    private func loadRecoveryInsights() {
        let allActivities = activityManager.getRecentActivities(days: 30)
        
        // Group activities by type
        let activityTypeGroups = Dictionary(grouping: allActivities) { $0.type }
        
        // Generate insights for each activity type with enough data
        recoveryInsights = []
        
        for (type, activities) in activityTypeGroups {
            if activities.count >= 3 {
                // Find similar activities and calculate average recovery time
                let averageRecoveryDays = calculateAverageRecoveryDays(for: activities)
                
                if averageRecoveryDays > 0 {
                    recoveryInsights.append(
                        RecoveryInsight(
                            id: UUID(),
                            activityType: type,
                            title: "Recovery after \(type.rawValue)s",
                            description: "You typically need \(String(format: "%.1f", averageRecoveryDays)) days to fully recover after \(type.rawValue.lowercased()) activities.",
                            detailedDescription: "Based on \(activities.count) recent \(type.rawValue.lowercased()) activities, your body takes an average of \(String(format: "%.1f", averageRecoveryDays)) days to return to baseline recovery. Consider scheduling your next \(type.rawValue.lowercased()) activity accordingly.",
                            recoveryDays: averageRecoveryDays
                        )
                    )
                }
            }
        }
    }
    
    private func calculateAverageRecoveryDays(for activities: [Activity]) -> Double {
        // This is a simplified model - in a real app, you would analyze actual recovery metrics
        // following each activity and measure time to return to baseline
        
        // For this example, we'll estimate recovery time based on intensity and duration
        let recoveryTimes = activities.map { activity in
            let intensityFactor: Double
            switch activity.intensity {
            case .low: intensityFactor = 1.0
            case .moderate: intensityFactor = 1.5
            case .high: intensityFactor = 2.0
            }
            
            let durationHours = activity.duration / 3600
            let baseRecovery = durationHours * intensityFactor / 3.0 // Rough estimate - 3 hour intense activity needs 2 days
            
            return min(max(baseRecovery, 0.5), 4.0) // Between 0.5 and 4 days
        }
        
        return recoveryTimes.reduce(0, +) / Double(recoveryTimes.count)
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
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            HStack {
                Text("Recommended Activities")
                    .font(MendFont.headline)
                    .foregroundColor(secondaryTextColor)
                Spacer()
            }
            .padding(.horizontal, MendSpacing.medium)
            .padding(.vertical, 10)
            .background(colorScheme == .dark ? MendColors.darkBackground : MendColors.background)
            
            // Show personalized recommendations if available, otherwise use basic recommendations
            let recommendationsToShow = !personalizedRecommendations.isEmpty ? 
                                       personalizedRecommendations : 
                                       recoveryMetrics.currentRecoveryScore?.recommendedActivities ?? []
                                       
            ForEach(recommendationsToShow) { activity in
                ExpandableActivityCard(activity: activity, colorScheme: colorScheme)
                    .padding(.horizontal, MendSpacing.medium)
            }
        }
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            HStack {
                Text("Recovery Insights")
                    .font(MendFont.headline)
                    .foregroundColor(secondaryTextColor)
                Spacer()
            }
            .padding(.horizontal, MendSpacing.medium)
            .padding(.vertical, 10)
            .background(colorScheme == .dark ? MendColors.darkBackground : MendColors.background)
            
            ForEach(recoveryInsights) { insight in
                RecoveryInsightCard(insight: insight, colorScheme: colorScheme)
                    .padding(.horizontal, MendSpacing.medium)
            }
        }
    }
}

// MARK: - New Card Components

struct ExpandableActivityCard: View {
    let activity: ActivityRecommendation
    var colorScheme: ColorScheme
    @State private var isExpanded = false
    
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
        VStack(alignment: .leading, spacing: 0) {
            // Activity header (always visible)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
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
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(secondaryTextColor)
                        .padding(.trailing, MendSpacing.medium)
                        .animation(.spring(), value: isExpanded)
                }
                .padding(.vertical, MendSpacing.medium)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content (visible only when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: MendSpacing.medium) {
                    Divider()
                        .padding(.horizontal, MendSpacing.medium)
                    
                    VStack(alignment: .leading, spacing: MendSpacing.small) {
                        // Duration
                        HStack(spacing: MendSpacing.medium) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(activity.intensity.color)
                                .frame(width: 24)
                            
                            Text("Duration: \(activity.formattedDuration)")
                                .font(MendFont.body)
                                .foregroundColor(textColor)
                        }
                        
                        // Intensity
                        HStack(spacing: MendSpacing.medium) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(activity.intensity.color)
                                .frame(width: 24)
                            
                            Text("Intensity: \(activity.intensity.rawValue)")
                                .font(MendFont.body)
                                .foregroundColor(textColor)
                        }
                        
                        // Benefits
                        HStack(alignment: .top, spacing: MendSpacing.medium) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(activity.intensity.color)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Benefits:")
                                    .font(MendFont.body)
                                    .foregroundColor(textColor)
                                
                                Text(getBenefitsText(for: activity))
                                    .font(MendFont.body)
                                    .foregroundColor(secondaryTextColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Recovery Impact
                        HStack(alignment: .top, spacing: MendSpacing.medium) {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundColor(activity.intensity.color)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recovery Impact:")
                                    .font(MendFont.body)
                                    .foregroundColor(textColor)
                                
                                Text(getRecoveryImpactText(for: activity))
                                    .font(MendFont.body)
                                    .foregroundColor(secondaryTextColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, MendSpacing.medium)
                    .padding(.bottom, MendSpacing.medium)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .animation(.spring(), value: isExpanded)
    }
    
    private func getBenefitsText(for activity: ActivityRecommendation) -> String {
        switch activity.intensity {
        case .low:
            return "Promotes active recovery, increases blood flow, reduces stiffness, and helps clear metabolic waste without adding training stress."
        case .moderate:
            return "Improves aerobic capacity, builds endurance, and maintains fitness levels while allowing for recovery from more intense sessions."
        case .high:
            return "Enhances VO2 max, increases lactate threshold, builds muscular endurance, and provides significant fitness adaptations."
        }
    }
    
    private func getRecoveryImpactText(for activity: ActivityRecommendation) -> String {
        switch activity.intensity {
        case .low:
            return "Minimal impact on recovery. Can typically be performed daily, even when fatigued, and may enhance recovery between harder sessions."
        case .moderate:
            return "Moderate impact on recovery resources. Allow 24-48 hours before another moderate session, or mix with low-intensity activities."
        case .high:
            return "Significant impact on recovery resources. Allow 48-72 hours before another high-intensity session to ensure adequate recovery."
        }
    }
}

struct RecoveryInsight: Identifiable {
    let id: UUID
    let activityType: ActivityType
    let title: String
    let description: String
    let detailedDescription: String
    let recoveryDays: Double
}

struct RecoveryInsightCard: View {
    let insight: RecoveryInsight
    var colorScheme: ColorScheme
    @State private var isExpanded = false
    
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
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: MendSpacing.medium) {
                    // Activity Icon
                    ZStack {
                        Circle()
                            .fill(MendColors.primary.opacity(colorScheme == .dark ? 0.3 : 0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: insight.activityType.icon)
                            .font(.system(size: 20))
                            .foregroundColor(MendColors.primary)
                    }
                    .padding(.leading, MendSpacing.small)
                    
                    // Insight Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(MendFont.headline)
                            .foregroundColor(textColor)
                        
                        Text(insight.description)
                            .font(MendFont.subheadline)
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(isExpanded ? 5 : 2)
                    }
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(secondaryTextColor)
                        .padding(.trailing, MendSpacing.medium)
                }
                .padding(.vertical, MendSpacing.medium)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: MendSpacing.medium) {
                    Divider()
                        .padding(.horizontal, MendSpacing.medium)
                    
                    Text(insight.detailedDescription)
                        .font(MendFont.body)
                        .foregroundColor(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, MendSpacing.medium)
                    
                    // Training implications section
                    VStack(alignment: .leading, spacing: MendSpacing.small) {
                        Text("Implications for Training")
                            .font(MendFont.subheadline.bold())
                            .foregroundColor(textColor)
                            .padding(.top, MendSpacing.small)
                        
                        Text(getTrainingImplications())
                            .font(MendFont.body)
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, MendSpacing.medium)
                    .padding(.bottom, MendSpacing.medium)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func getTrainingImplications() -> String {
        switch insight.activityType {
        case .run:
            return "Consider alternating run days with recovery or cross-training activities. For your next run, schedule it after \(String(format: "%.1f", insight.recoveryDays)) days of recovery for optimal performance."
        case .ride:
            return "Cycling allows for more frequent training. For high-intensity rides, wait \(String(format: "%.1f", insight.recoveryDays)) days, but light recovery rides can be beneficial in between."
        case .swim:
            return "Swimming has lower impact on joints. After intense sessions, wait \(String(format: "%.1f", insight.recoveryDays)) days for full recovery, but light technique work can be done sooner."
        case .workout:
            return "For strength training, allow \(String(format: "%.1f", insight.recoveryDays)) days before targeting the same muscle groups again. Consider a split routine to train different areas while others recover."
        default:
            return "For this activity type, planning about \(String(format: "%.1f", insight.recoveryDays)) days between sessions is optimal for recovery and progression."
        }
    }
}

// MARK: - Existing Activity Cards

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
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
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
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Notification Menu
struct NotificationMenuView: View {
    @ObservedObject var notificationManager: NotificationManager
    @Binding var isPresented: Bool
    var colorScheme: ColorScheme
    var recoveryScore: RecoveryScore?
    
    private var backgroundColor: Color {
        colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground
    }
    
    private var textColor: Color {
        colorScheme == .dark ? MendColors.darkText : MendColors.text
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: MendSpacing.notificationMenu) {
            Text("Recovery Notifications")
                .font(MendFont.headline)
                .foregroundColor(textColor)
                .padding(.top, MendSpacing.medium)
                .padding(.horizontal, MendSpacing.medium)
            
            Divider()
            
            ForEach(NotificationPreference.allCases, id: \.self) { preference in
                Button(action: {
                    notificationManager.currentPreference = preference
                    // No longer closing menu when selecting an option
                }) {
                    HStack(spacing: MendSpacing.medium) {
                        Image(systemName: preference.icon)
                            .foregroundColor(notificationManager.currentPreference == preference ? MendColors.primary : secondaryTextColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preference.rawValue)
                                .font(MendFont.body)
                                .foregroundColor(textColor)
                            
                            Text(preference.description)
                                .font(MendFont.caption)
                                .foregroundColor(secondaryTextColor)
                        }
                        
                        Spacer()
                        
                        if notificationManager.currentPreference == preference {
                            Image(systemName: "checkmark")
                                .foregroundColor(MendColors.primary)
                        }
                    }
                    .padding(.horizontal, MendSpacing.medium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                
                if preference != NotificationPreference.allCases.last {
                    Divider()
                        .padding(.horizontal, MendSpacing.medium)
                }
            }
            
            Divider()
            
            // Test notification button
            Button(action: {
                notificationManager.sendTestNotification()
            }) {
                HStack(spacing: MendSpacing.medium) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(MendColors.primary)
                        .frame(width: 24)
                    
                    Text("Send Test Notification")
                        .font(MendFont.body)
                        .foregroundColor(textColor)
                }
                .padding(.horizontal, MendSpacing.medium)
                .padding(.vertical, MendSpacing.small)
                .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Divider()
            
            if let score = recoveryScore {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Today's Recovery: ")
                            .font(MendFont.caption)
                            .foregroundColor(secondaryTextColor)
                        
                        Text("\(score.overallScore)")
                            .font(MendFont.caption.bold())
                            .foregroundColor(textColor)
                    }
                    
                    Text(RecoveryMetrics.scoreDescription(for: score))
                        .font(MendFont.caption)
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(MendSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundColor.opacity(colorScheme == .dark ? 0.5 : 0.3))
                .cornerRadius(MendCornerRadius.small)
                .padding(.horizontal, MendSpacing.medium)
                .padding(.bottom, MendSpacing.medium)
            }
        }
        .padding(.vertical, MendSpacing.small)
        .frame(width: 300)
        .background(backgroundColor)
        .cornerRadius(MendCornerRadius.medium)
    }
}

#Preview {
    NavigationView {
        TodayView()
            .environmentObject(RecoveryMetrics.shared)
    }
} 
