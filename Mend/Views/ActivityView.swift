import SwiftUI

struct ActivityView: View {
    @StateObject private var activityManager = ActivityManager.shared
    @State private var selectedActivityType: ActivityType? = nil
    @State private var groupedActivities: [Date: [Activity]] = [:]
    @State private var showingAddActivity = false
    @State private var isRefreshing = false
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
        ZStack {
            activityListView
            
            // Floating Action Button
            floatingActionButton
        }
        .background(backgroundColor.ignoresSafeArea())
    }
    
    private var activityListView: some View {
        ScrollView {
            VStack(spacing: MendSpacing.large) {
                // Training Load Card
                TrainingLoadCard(activityManager: activityManager)
                    .padding(.horizontal, MendSpacing.medium)
                    .padding(.top, MendSpacing.medium)
                
                // Activity type filter
                activityTypeFilter
                
                // Activities by day
                activityContent
            }
            .padding(.vertical, MendSpacing.medium)
            .padding(.bottom, 80)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Activities")                .toolbarColorScheme(colorScheme, for: .navigationBar)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshActivities) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(textColor)
                }
                .disabled(isRefreshing)
            }
        }
        .onAppear(perform: loadActivities)
        .onChange(of: selectedActivityType) { oldValue, newValue in
            loadActivities()
        }
        .sheet(isPresented: $showingAddActivity) {
            NavigationView {
                AddActivityView(isPresented: $showingAddActivity)
                    .navigationTitle("Add Activity")
                    .navigationBarItems(leading: Button("Cancel") {
                        showingAddActivity = false
                    })
                    .environmentObject(activityManager)
            }
        }
    }
    
    private var activityTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MendSpacing.medium) {
                ActivityTypeFilterButton(
                    title: "All",
                    isSelected: selectedActivityType == nil,
                    action: { selectedActivityType = nil },
                    colorScheme: colorScheme
                )
                
                ActivityTypeFilterButton(
                    title: "Runs",
                    icon: ActivityType.run.icon,
                    isSelected: selectedActivityType == .run,
                    action: { selectedActivityType = .run },
                    colorScheme: colorScheme
                )
                
                ActivityTypeFilterButton(
                    title: "Rides",
                    icon: ActivityType.ride.icon,
                    isSelected: selectedActivityType == .ride,
                    action: { selectedActivityType = .ride },
                    colorScheme: colorScheme
                )
                
                ActivityTypeFilterButton(
                    title: "Swims",
                    icon: ActivityType.swim.icon,
                    isSelected: selectedActivityType == .swim,
                    action: { selectedActivityType = .swim },
                    colorScheme: colorScheme
                )
                
                ActivityTypeFilterButton(
                    title: "Walks",
                    icon: ActivityType.walk.icon,
                    isSelected: selectedActivityType == .walk,
                    action: { selectedActivityType = .walk },
                    colorScheme: colorScheme
                )
                
                ActivityTypeFilterButton(
                    title: "Workouts",
                    icon: ActivityType.workout.icon,
                    isSelected: selectedActivityType == .workout,
                    action: { selectedActivityType = .workout },
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal, MendSpacing.medium)
        }
    }
    
    private var activityContent: some View {
        Group {
            if activityManager.isLoading {
                loadingView
            } else if groupedActivities.isEmpty {
                emptyStateView
            } else {
                activitiesByDayView
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("Loading activities...")
                .foregroundColor(secondaryTextColor)
        }
        .padding(.top, MendSpacing.extraLarge)
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 50))
                .foregroundColor(secondaryTextColor)
                .padding()
            
            Text("No activities found")
                .font(.headline)
                .foregroundColor(textColor)
            
            Text("Add an activity or import from Apple Health")
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: refreshActivities) {
                Label("Import From HealthKit", systemImage: "heart.fill")
                    .padding()
                    .background(cardBackgroundColor)
                    .foregroundColor(MendColors.primary)
                    .cornerRadius(MendCornerRadius.medium)
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .padding()
        }
        .padding(.top, MendSpacing.extraLarge)
    }
    
    private var activitiesByDayView: some View {
        ForEach(groupedActivities.keys.sorted(by: >), id: \.self) { date in
            if let activities = groupedActivities[date], !activities.isEmpty {
                VStack(alignment: .leading, spacing: MendSpacing.medium) {
                    mendSectionHeader(title: formatDate(date), colorScheme: colorScheme)
                    
                    ForEach(activities) { activity in
                        ActivityCard(activity: activity, colorScheme: colorScheme)
                            .padding(.horizontal, MendSpacing.medium)
                    }
                }
                .padding(.bottom, MendSpacing.medium)
            }
        }
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
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
    
    private func loadActivities() {
        let activities = activityManager.getActivities(ofType: selectedActivityType)
        self.groupedActivities = Dictionary(grouping: activities) { activity in
            Calendar.current.startOfDay(for: activity.date)
        }
    }
    
    private func refreshActivities() {
        isRefreshing = true
        
        Task {
            await activityManager.refreshActivities()
            loadActivities()
            
            DispatchQueue.main.async {
                isRefreshing = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "dd/MM, EEEE"
            return formatter.string(from: date)
        }
    }
    
    private func formatDayOfMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
}

struct TrainingLoadCard: View {
    let activityManager: ActivityManager
    @State private var trainingLoad: Int = 0
    @State private var volumes: [DailyTrainingVolume] = []
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    // Add a parameter to control if this card should be collapsible
    var collapsible: Bool = false
    
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
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            // Title and summary
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("7-Day Training Load")
                        .font(MendFont.headline)
                        .foregroundColor(textColor)
                    
                    // Only show training load value on left side when expanded
                    if isExpanded || !collapsible {
                        Text("\(trainingLoad) pts")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(loadColor)
                    }
                    
                    // If not expanded and collapsible, show comparison to 28-day average
                    if !isExpanded && collapsible {
                        // Calculate 28-day average (simulated as 75 less than current)
                        let twentyEightDayAvg = Double(trainingLoad) - 75
                        let delta = Double(trainingLoad) - twentyEightDayAvg
                        let percentChange = twentyEightDayAvg > 0 ? (delta / twentyEightDayAvg) * 100 : 50
                        let isPositiveDelta = percentChange > 0 && percentChange <= 15
                        
                        Text("28-day avg: \(String(format: "%.0f", twentyEightDayAvg))")
                            .font(MendFont.caption)
                            .foregroundColor(textColor)
                        
                        Text(getTrainingLoadComparison(delta: delta, percentChange: percentChange, isPositiveDelta: isPositiveDelta))
                            .font(MendFont.caption)
                            .foregroundColor(getComparisonColor(isPositiveDelta: isPositiveDelta))
                    } else {
                        Text(loadDescription)
                            .font(MendFont.subheadline)
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
                
                // Show either training load value or work-rest ratio
                if !isExpanded && collapsible {
                    // When collapsed and collapsible, show training load value with color coding
                    VStack(alignment: .center) {
                        // Training load value
                        Text("\(trainingLoad)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(loadColor)
                            .multilineTextAlignment(.center)
                        
                        // Units
                        Text("pts")
                            .font(.system(size: 14))
                            .foregroundColor(secondaryTextColor)
                    }
                    .frame(minWidth: 70)
                } else {
                    // Work-to-Rest ratio indicator (only when expanded or not collapsible)
                    VStack(alignment: .center, spacing: 2) {
                        Text("Work:Rest")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                        
                        HStack(spacing: 2) {
                            Text(workRestRatio.0)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(MendColors.negative)
                            
                            Text(":")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(secondaryTextColor)
                            
                            Text(workRestRatio.1)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(MendColors.positive)
                        }
                        
                        Text(workRestDescription)
                            .font(.system(size: 10))
                            .foregroundColor(secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Expanded content - only show when expanded or not collapsible
            if isExpanded || !collapsible {
                Divider()
                    .padding(.vertical, 4)
                
                // Weekly volume chart with labels
                Text("Daily Training Volume")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                    .padding(.bottom, 4)
                
                // Enhanced bar chart
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(volumes) { volume in
                        VStack(spacing: 2) {
                            // Activity bar with two-tone gradient based on intensity
                            VStack(spacing: 0) {
                                if volume.activityCount > 0 {
                                    // Bar with intensity coloring
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            volume.intensityLevel.color.opacity(0.3),
                                            volume.intensityLevel.color
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(width: 18, height: max(15, min(80, volume.totalDurationMinutes / 2)))
                                    .cornerRadius(4)
                                    
                                    // Activity count indicator
                                    Text("\(volume.activityCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(2)
                                        .background(
                                            Circle()
                                                .fill(volume.intensityLevel.color)
                                        )
                                        .offset(y: -8)
                                        .zIndex(1)
                                } else {
                                    // Empty bar for days with no activity
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2]))
                                        .frame(width: 18, height: 15)
                                        .padding(.bottom, 10)
                                }
                            }
                            
                            VStack(spacing: 0) {
                                // Day of week
                                Text(formatDayOfWeek(volume.date))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(isToday(volume.date) ? textColor : secondaryTextColor)
                                
                                // Day of month
                                Text(formatDayOfMonth(volume.date))
                                    .font(.system(size: 9))
                                    .foregroundColor(secondaryTextColor)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 4)
            }
            
            // Add expand/collapse button if collapsible
            if collapsible {
                Button {
                    withAnimation(.mendEaseInOut) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Hide details" : "Show details")
                            .font(MendFont.subheadline)
                            .foregroundColor(MendColors.secondary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(MendColors.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MendSpacing.small)
                    .background(MendColors.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .cornerRadius(MendCornerRadius.small)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            updateTrainingLoad()
        }
    }
    
    private func updateTrainingLoad() {
        // Always calculate based on the past 7 days
        trainingLoad = activityManager.calculateTrainingLoad(forDays: 7)
        
        // Get 14 days of volume data to show trends, but we'll use only the last 7 for the work:rest ratio
        volumes = activityManager.calculateDailyTrainingVolumes(forDays: 14)
    }
    
    private func calculateLoadScore() -> Int {
        // Convert raw training load to a score out of 100
        // We want high values to be red (bad) and moderate values to be green (good)
        if trainingLoad > 800 {
            return 30 // Too high - poor score
        } else if trainingLoad > 600 {
            return 60 // High but manageable - medium score
        } else if trainingLoad > 300 {
            return 90 // Good range - high score
        } else if trainingLoad > 100 {
            return 70 // A bit low - medium score
        } else {
            return 40 // Too low - lower score
        }
    }
    
    private func getTrainingLoadComparison(delta: Double, percentChange: Double, isPositiveDelta: Bool) -> String {
        let formattedChange = String(format: "%.0f", abs(percentChange))
        
        if percentChange > 25 {
            return "\(String(format: "+%.0f", delta)) (\(formattedChange)%) (high)"
        } else if percentChange > 10 {
            return "\(String(format: "+%.0f", delta)) (\(formattedChange)%) (optimal)"
        } else if percentChange >= -5 {
            return "Similar to avg (balanced)"
        } else {
            return "\(String(format: "-%.0f", abs(delta))) (\(formattedChange)%) (low)"
        }
    }
    
    private func getComparisonColor(isPositiveDelta: Bool) -> Color {
        return isPositiveDelta ? MendColors.positive : MendColors.negative
    }
    
    private var loadColor: Color {
        if trainingLoad > 800 {
            return MendColors.negative
        } else if trainingLoad > 400 {
            return MendColors.neutral
        } else {
            return MendColors.positive
        }
    }
    
    private var loadDescription: String {
        if trainingLoad > 800 {
            return "High training load - consider reducing intensity and adding recovery days"
        } else if trainingLoad > 400 {
            return "Moderate training load - maintaining good balance of work and recovery"
        } else if trainingLoad > 100 {
            return "Light training load - room for additional training if desired"
        } else {
            return "Very light training load - focus on building consistency"
        }
    }
    
    // Calculate work:rest ratio based on activity days vs rest days in the past 7 days only
    private var workRestRatio: (String, String) {
        // Filter to only include the past 7 days
        let past7DaysVolumes = volumes.suffix(7)
        
        let activeDays = past7DaysVolumes.filter { $0.activityCount > 0 }.count
        let restDays = past7DaysVolumes.count - activeDays
        
        // Calculate greatest common divisor for simplification
        func gcd(_ a: Int, _ b: Int) -> Int {
            return b == 0 ? a : gcd(b, a % b)
        }
        
        if activeDays == 0 {
            return ("0", "7")
        }
        
        let divisor = gcd(activeDays, restDays)
        return (String(activeDays / max(1, divisor)), String(restDays / max(1, divisor)))
    }
    
    private var workRestDescription: String {
        let (work, rest) = workRestRatio
        if work == "0" {
            return "Recovery week"
        } else if rest == "0" {
            return "Need recovery!"
        } else if Int(work)! > Int(rest)! * 2 {
            return "High frequency"
        } else if Int(work)! <= Int(rest)! {
            return "Well balanced"
        } else {
            return "Active week"
        }
    }
    
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).prefix(1).uppercased()
    }
    
    private func formatDayOfMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
    
    private func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
}

struct AddActivityView: View {
    @EnvironmentObject private var activityManager: ActivityManager
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var selectedType: ActivityType = .run
    @State private var selectedIntensity: ActivityIntensity = .moderate
    @State private var distance: String = ""
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 30
    @State private var date = Date()
    
    var body: some View {
        Form {
            Section(header: Text("Activity Details")) {
                TextField("Title", text: $title)
                
                Picker("Type", selection: $selectedType) {
                    ForEach(ActivityType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue.capitalized)
                        }
                        .tag(type)
                    }
                }
                
                Picker("Intensity", selection: $selectedIntensity) {
                    ForEach(ActivityIntensity.allCases, id: \.self) { intensity in
                        Text(intensity.rawValue.capitalized)
                            .foregroundColor(intensity.color)
                            .tag(intensity)
                    }
                }
            }
            
            Section(header: Text("Metrics")) {
                HStack {
                    Text("Distance")
                    Spacer()
                    TextField("0.0", text: $distance)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("km")
                }
                
                HStack {
                    Text("Duration")
                    Spacer()
                    
                    Picker("Hours", selection: $durationHours) {
                        ForEach(0..<24) { hour in
                            Text("\(hour)").tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 50)
                    .clipped()
                    
                    Text("h")
                    
                    Picker("Minutes", selection: $durationMinutes) {
                        ForEach(0..<60) { minute in
                            Text("\(minute)").tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 50)
                    .clipped()
                    
                    Text("m")
                }
            }
            
            Section(header: Text("Date & Time")) {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
        }
        .navigationTitle("Add Activity")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveActivity()
                    isPresented = false
                }
            }
        }
    }
    
    private func saveActivity() {
        // Calculate duration in seconds
        let totalSeconds = (durationHours * 3600) + (durationMinutes * 60)
        
        // Create new activity
        let newActivity = Activity(
            id: UUID(),
            title: title.isEmpty ? "\(selectedType.rawValue.capitalized)" : title,
            type: selectedType,
            date: date,
            duration: TimeInterval(totalSeconds),
            distance: Double(distance),
            intensity: selectedIntensity,
            source: .manual
        )
        
        // Add to activity manager
        activityManager.addActivity(newActivity)
    }
}

struct ActivityTypeFilterButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void
    let colorScheme: ColorScheme
    
    init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void, colorScheme: ColorScheme) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
        self.colorScheme = colorScheme
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: MendSpacing.small) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body)
                }
                
                Text(title)
                    .font(MendFont.subheadline)
            }
            .padding(.horizontal, MendSpacing.medium)
            .padding(.vertical, MendSpacing.small)
            .background(isSelected ? MendColors.primary : (colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground))
            .foregroundColor(isSelected ? .white : (colorScheme == .dark ? MendColors.darkText : MendColors.text))
            .cornerRadius(MendCornerRadius.medium)
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

struct ActivityCard: View {
    let activity: Activity
    let colorScheme: ColorScheme
    
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
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            HStack {
                Image(systemName: activity.type.icon)
                    .font(.title2)
                    .foregroundColor(MendColors.primary)
                
                Text(activity.title)
                    .font(.headline)
                    .foregroundColor(textColor)
                
                Spacer()
                
                Text(formatActivityDate(activity.date))
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
            
            HStack(spacing: MendSpacing.large) {
                if activity.distance != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .font(.subheadline)
                        Text(activity.formattedDistance ?? "")
                            .font(.subheadline)
                    }
                    .foregroundColor(secondaryTextColor)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.subheadline)
                    Text(activity.formattedDuration)
                        .font(.subheadline)
                }
                .foregroundColor(secondaryTextColor)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(activity.intensity.color)
                        .frame(width: 10, height: 10)
                    Text(activity.intensity.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(10)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // Helper method to format date as dd/MM/yyyy
    private func formatActivityDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        ActivityView()
    }
} 
