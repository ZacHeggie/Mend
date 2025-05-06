import SwiftUI
import MessageUI

struct FeatureRequestView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var themeVersion = 0
    
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
    @State private var selectedCategory = FeatureCategory.workout
    @State private var selectedPriority = PriorityLevel.medium
    @State private var showSubmissionSuccess = false
    @State private var showSubmissionError = false
    @State private var keepMeUpdated = false
    
    // Email view state
    @State private var showMailView = false
    @State private var mailViewResult: MailViewResult?
    @State private var showMailNotAvailableAlert = false
    
    enum FeatureCategory: String, CaseIterable, Identifiable {
        case workout = "Workout"
        case recovery = "Recovery"
        case tracking = "Tracking"
        case social = "Social"
        case ui = "User Interface"
        case other = "Other"
        
        var id: String { self.rawValue }
    }
    
    enum PriorityLevel: String, CaseIterable, Identifiable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MendSpacing.large) {
                // Intro content and form fields
                introSection
                    .id("intro-section-\(themeVersion)")
                featureTitleSection
                    .id("title-section-\(themeVersion)")
                categorySection
                    .id("category-section-\(themeVersion)")
                prioritySection
                    .id("priority-section-\(themeVersion)")
                descriptionSection
                    .id("description-section-\(themeVersion)")
                contactEmailSection
                    .id("contact-section-\(themeVersion)")
                
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
                .id("submit-button-\(themeVersion)")
                
                // Popular requests section
                popularRequestsSection
                    .id("popular-requests-\(themeVersion)")
            }
            .padding()
            .padding(.bottom, 50)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Request a Feature")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showSubmissionSuccess) {
            Alert(
                title: Text("Feature Request Submitted"),
                message: Text("Thank you for your suggestion. We'll review it soon to improve Mend."),
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
        .mailSheet(mailData: Binding<MailData?>.constant(requestService.mailData), 
                   isShowing: $showMailView, 
                   result: $mailViewResult)
        .onChange(of: requestService.mailData) { oldValue, newValue in
            if newValue != nil {
                if MFMailComposeViewController.canSendMail() {
                    showMailView = true
                } else {
                    showMailNotAvailableAlert = true
                }
            }
        }
        .onChange(of: mailViewResult) { oldValue, newValue in
            if let result = newValue {
                switch result {
                case .sent:
                    showSubmissionSuccess = true
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                case .saved:
                    showSubmissionSuccess = true
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                case .cancelled:
                    // Do nothing
                    break
                case .failed:
                    showSubmissionError = true
                }
            }
        }
        .alert("Mail Unavailable", isPresented: $showMailNotAvailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Mail functionality is not available on this device. Please make sure the Mail app is configured or contact mendsupport@icloud.com directly.")
        }
        .onChange(of: colorScheme) { _, _ in
            // Update themeVersion to force UI refresh on theme change
            themeVersion += 1
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
            
            Picker("Priority", selection: $selectedPriority) {
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
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $featureDescription)
                    .frame(minHeight: 150)
                    .foregroundColor(textColor)
                    .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                    .background(cardBackgroundColor)
                    .cornerRadius(MendCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: MendCornerRadius.medium)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                if featureDescription.isEmpty {
                    Text("Describe the feature in detail. What problem does it solve? How would it work?")
                        .foregroundColor(secondaryTextColor.opacity(0.5))
                        .padding(EdgeInsets(top: 16, leading: 10, bottom: 8, trailing: 8))
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private var contactEmailSection: some View {
        Toggle(isOn: $keepMeUpdated) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keep Me Updated")
                    .font(MendFont.headline)
                    .foregroundColor(textColor)
                
                Text("We'll let you know when this feature is implemented")
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
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
        !featureDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitFeatureRequest() {
        let featureRequest = FeatureRequestModel(
            title: featureTitle,
            category: selectedCategory.rawValue,
            priorityLevel: selectedPriority.rawValue,
            description: featureDescription,
            keepMeUpdated: keepMeUpdated
        )
        
        Task {
            let result = await requestService.submitFeatureRequest(featureRequest)
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // This will trigger the mail view or save locally if mail isn't available
                    break
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
