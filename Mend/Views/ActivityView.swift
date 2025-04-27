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
        .navigationTitle("Activities")
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
                    Text(formatDate(date))
                        .font(MendFont.headline)
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, MendSpacing.medium)
                    
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
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
    }
}

struct TrainingLoadCard: View {
    let activityManager: ActivityManager
    @State private var trainingLoad: Int = 0
    @State private var volumes: [DailyTrainingVolume] = []
    @Environment(\.colorScheme) var colorScheme
    
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
                    
                    Text("\(trainingLoad) pts")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(loadColor)
                    
                    Text(loadDescription)
                        .font(MendFont.subheadline)
                        .foregroundColor(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Work-to-Rest ratio indicator
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
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            updateTrainingLoad()
        }
    }
    
    private func updateTrainingLoad() {
        trainingLoad = activityManager.calculateTrainingLoad()
        volumes = activityManager.calculateDailyTrainingVolumes()
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
    
    // Calculate work:rest ratio based on activity days vs rest days
    private var workRestRatio: (String, String) {
        let activeDays = volumes.filter { $0.activityCount > 0 }.count
        let restDays = volumes.count - activeDays
        
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
        formatter.dateFormat = "d"
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
                
                Text(activity.formattedDate)
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
}

#Preview {
    NavigationView {
        ActivityView()
    }
} 
