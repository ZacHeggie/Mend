import SwiftUI

struct FeatureRequestView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var requestService = RequestService.shared
    
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
    
    // Form state
    @State private var featureTitle: String = ""
    @State private var featureDescription: String = ""
    @State private var selectedCategory = FeatureCategory.general
    @State private var priorityLevel = PriorityLevel.medium
    @State private var userEmail: String = ""
    @State private var showSubmissionSuccess = false
    @State private var showSubmissionError = false
    
    enum FeatureCategory: String, CaseIterable, Identifiable {
        case general = "General Enhancement"
        case workout = "Workout Related"
        case recovery = "Recovery Features"
        case nutrition = "Nutrition Tracking"
        case sleep = "Sleep Analysis"
        case stats = "Statistics & Reports"
        case social = "Social Integration"
        case other = "Other"
        
        var id: String { self.rawValue }
    }
    
    enum PriorityLevel: String, CaseIterable, Identifiable {
        case low = "Nice to Have"
        case medium = "Important"
        case high = "Critical"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MendSpacing.large) {
                // Intro content and form fields
                introSection
                featureTitleSection
                categorySection
                prioritySection
                descriptionSection
                emailSection
                
                // Submit button
                Button(action: {
                    submitFeatureRequest()
                }) {
                    HStack {
                        if requestService.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 5)
                        } else {
                            Image(systemName: "lightbulb.fill")
                                .padding(.trailing, 5)
                        }
                        Text("Submit Feature Request")
                    }
                    .font(MendFont.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? MendColors.primary : MendColors.primary.opacity(0.5))
                    .cornerRadius(MendCornerRadius.medium)
                }
                .disabled(!isFormValid || requestService.isSubmitting)
                .padding(.top, MendSpacing.medium)
                
                // Popular requests section
                popularRequestsSection
            }
            .padding()
            .padding(.bottom, 50)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Feature Request")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showSubmissionSuccess) {
            Alert(
                title: Text("Feature Request Submitted"),
                message: Text("Thank you for your suggestion! We appreciate your input in making Mend better."),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert("Submission Error", isPresented: $showSubmissionError, presenting: requestService.lastSubmissionError) { _ in
            Button("OK", role: .cancel) { }
        } message: { errorMessage in
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var introSection: some View {
        Text("Have an idea that would make Mend better? We'd love to hear it! Please provide details about your feature request below.")
            .font(MendFont.body)
            .foregroundColor(secondaryTextColor)
            .padding(.bottom, MendSpacing.small)
    }
    
    private var featureTitleSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Text("Feature Title")
                .font(MendFont.headline)
                .foregroundColor(textColor)
            
            TextField("Enter a short, descriptive title", text: $featureTitle)
                .font(MendFont.body)
                .foregroundColor(textColor)
                .padding()
                .background(cardBackgroundColor)
                .cornerRadius(MendCornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: MendCornerRadius.medium)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Text("Category")
                .font(MendFont.headline)
                .foregroundColor(textColor)
            
            Picker("Category", selection: $selectedCategory) {
                ForEach(FeatureCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(cardBackgroundColor)
            .cornerRadius(MendCornerRadius.medium)
        }
    }
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Text("How important is this feature to you?")
                .font(MendFont.headline)
                .foregroundColor(textColor)
            
            Picker("Priority", selection: $priorityLevel) {
                ForEach(PriorityLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .foregroundColor(textColor)
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Text("Feature Description")
                .font(MendFont.headline)
                .foregroundColor(textColor)
            
            TextEditor(text: $featureDescription)
                .frame(minHeight: 150)
                .foregroundColor(textColor)
                .padding()
                .background(cardBackgroundColor)
                .cornerRadius(MendCornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: MendCornerRadius.medium)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if featureDescription.isEmpty {
                            Text("Describe the feature in detail. What problem does it solve? How would it work?")
                                .foregroundColor(secondaryTextColor.opacity(0.5))
                                .padding()
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
        }
    }
    
    private var emailSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            HStack {
                Text("Your Email (Optional)")
                    .font(MendFont.headline)
                    .foregroundColor(textColor)
                
                Text("To follow up on your request")
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
            }
            
            TextField("email@example.com", text: $userEmail)
                .font(MendFont.body)
                .foregroundColor(textColor)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(cardBackgroundColor)
                .cornerRadius(MendCornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: MendCornerRadius.medium)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var popularRequestsSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            Text("Popular Feature Requests")
                .font(MendFont.headline)
                .foregroundColor(textColor)
                .padding(.top, MendSpacing.medium)
            
            ForEach(popularRequests, id: \.title) { request in
                popularRequestCard(request: request)
            }
        }
        .padding(.top, MendSpacing.large)
    }
    
    private var isFormValid: Bool {
        !featureTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !featureDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (userEmail.isEmpty || isValidEmail(userEmail))
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func submitFeatureRequest() {
        // Create the feature request model
        let request = FeatureRequestModel(
            title: featureTitle,
            category: selectedCategory.rawValue,
            priorityLevel: priorityLevel.rawValue,
            description: featureDescription,
            email: userEmail.isEmpty ? nil : userEmail
        )
        
        // Submit using the service
        Task {
            let result = await requestService.submitFeatureRequest(request)
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    showSubmissionSuccess = true
                case .failure:
                    showSubmissionError = true
                }
            }
        }
    }
    
    private func popularRequestCard(request: PopularRequest) -> some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            HStack {
                Text(request.title)
                    .font(MendFont.headline)
                    .foregroundColor(textColor)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Status")
                        .font(MendFont.caption)
                        .foregroundColor(secondaryTextColor)
                    
                    Text(request.status)
                        .font(MendFont.subheadline)
                        .foregroundColor(statusColor(for: request.status))
                }
            }
            
            Text(request.description)
                .font(MendFont.body)
                .foregroundColor(secondaryTextColor)
            
            if let progress = request.progressPercentage {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(Int(progress))% Complete")
                        .font(MendFont.caption)
                        .foregroundColor(secondaryTextColor)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 8)
                                .opacity(0.2)
                                .foregroundColor(MendColors.primary)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .frame(width: min(CGFloat(progress) / 100.0 * geometry.size.width, geometry.size.width), height: 8)
                                .foregroundColor(MendColors.primary)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "In Development":
            return .blue
        case "Planned":
            return .orange
        case "Under Review":
            return .purple
        case "Completed":
            return .green
        default:
            return textColor
        }
    }
    
    // Sample popular requests
    private let popularRequests = [
        PopularRequest(
            title: "Custom Workout Templates",
            description: "Ability to create and save personalized workout templates for quick access.",
            status: "Planned",
            progressPercentage: 25
        ),
        PopularRequest(
            title: "Integration with Apple Health",
            description: "Seamless syncing of workout and recovery data with Apple Health.",
            status: "Completed",
            progressPercentage: 100
        ),
        PopularRequest(
            title: "Dark Mode Support",
            description: "Full app support for system-wide dark mode settings.",
            status: "Completed",
            progressPercentage: 100
        ),
        PopularRequest(
            title: "Weekly Progress Reports",
            description: "Detailed weekly summaries of workout progress and recovery metrics.",
            status: "In Development",
            progressPercentage: 60
        )
    ]
}

struct PopularRequest {
    let title: String
    let description: String
    let status: String
    let progressPercentage: Double?
}

struct FeatureRequestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FeatureRequestView()
        }
    }
} 
