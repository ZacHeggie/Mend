import SwiftUI
import UIKit
import OSLog
import MessageUI

struct ReportBugView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var themeVersion = 0
    
    // Add ObservedObject for the request service
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
    @State private var bugDescription: String = ""
    @State private var reproducibleSteps: String = ""
    @State private var selectedCategory = BugCategory.general
    @State private var includeDeviceInfo = true
    @State private var includeSystemLogs = false
    @State private var includeScreenshot = false
    @State private var showingImagePicker = false
    @State private var screenshot: UIImage?
    @State private var showSubmissionSuccess = false
    @State private var showSubmissionError = false
    @State private var keepMeUpdated = false
    
    // Email view state
    @State private var showMailView = false
    @State private var mailViewResult: MailViewResult?
    @State private var showMailNotAvailableAlert = false
    
    enum BugCategory: String, CaseIterable, Identifiable {
        case general = "General Issue"
        case crash = "App Crash"
        case performance = "Performance Issue"
        case ui = "UI Problem"
        case data = "Data Issue"
        case feature = "Missing Feature"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ScrollView {
            mainContent
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Report a Bug")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $screenshot)
        }
        .alert(isPresented: $showSubmissionSuccess) {
            Alert(
                title: Text("Bug Report Submitted"),
                message: Text("Thank you for reporting this issue. We'll review it soon to improve Mend."),
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
    
    // Breaking up the complex body into smaller components
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: MendSpacing.large) {
            introSection
                .id("intro-section-\(themeVersion)")
            categorySection
                .id("category-section-\(themeVersion)")
            descriptionSection
                .id("description-section-\(themeVersion)")
            stepsToReproduceSection
                .id("steps-section-\(themeVersion)")
            screenshotSection
                .id("screenshot-section-\(themeVersion)")
            deviceInfoSection
                .id("device-info-section-\(themeVersion)")
            systemLogsSection
                .id("logs-section-\(themeVersion)")
            contactEmailSection
                .id("contact-section-\(themeVersion)")
            submitButton
                .id("submit-button-\(themeVersion)")
        }
        .padding()
        .padding(.bottom, 50)
    }
    
    private var introSection: some View {
        Text("Help us improve Mend by reporting any issues you encounter. Please provide as much detail as possible to help us address the problem quickly.")
            .font(MendFont.body)
            .foregroundColor(secondaryTextColor)
            .padding(.bottom, MendSpacing.small)
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Text("Issue Category")
                .font(MendFont.headline)
                .foregroundColor(textColor)
            
            Picker("Category", selection: $selectedCategory) {
                ForEach(BugCategory.allCases) { category in
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
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Text("What's happening?")
                .font(MendFont.headline)
                .foregroundColor(textColor)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $bugDescription)
                    .frame(minHeight: 120)
                    .foregroundColor(textColor)
                    .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                    .background(cardBackgroundColor)
                    .cornerRadius(MendCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: MendCornerRadius.medium)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                if bugDescription.isEmpty {
                    Text("Describe the issue you're experiencing...")
                        .foregroundColor(secondaryTextColor.opacity(0.5))
                        .padding(EdgeInsets(top: 16, leading: 10, bottom: 8, trailing: 8))
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private var stepsToReproduceSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Text("Steps to Reproduce")
                .font(MendFont.headline)
                .foregroundColor(textColor)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $reproducibleSteps)
                    .frame(minHeight: 100)
                    .foregroundColor(textColor)
                    .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                    .background(cardBackgroundColor)
                    .cornerRadius(MendCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: MendCornerRadius.medium)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                if reproducibleSteps.isEmpty {
                    Text("List the steps needed to reproduce this issue...")
                        .foregroundColor(secondaryTextColor.opacity(0.5))
                        .padding(EdgeInsets(top: 16, leading: 10, bottom: 8, trailing: 8))
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Toggle(isOn: $includeScreenshot) {
                Text("Include a Screenshot")
                    .font(MendFont.headline)
                    .foregroundColor(textColor)
            }
            .padding()
            .background(cardBackgroundColor)
            .cornerRadius(MendCornerRadius.medium)
            
            if includeScreenshot {
                Button(action: {
                    showingImagePicker = true
                }) {
                    HStack {
                        Image(systemName: screenshot == nil ? "camera.fill" : "photo.fill")
                        Text(screenshot == nil ? "Take Screenshot" : "Change Screenshot")
                    }
                    .font(MendFont.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(MendColors.primary)
                    .cornerRadius(MendCornerRadius.medium)
                }
                
                if let screenshot = screenshot {
                    Image(uiImage: screenshot)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 150)
                        .cornerRadius(MendCornerRadius.medium)
                        .padding(.top, MendSpacing.small)
                }
            }
        }
    }
    
    private var deviceInfoSection: some View {
        Toggle(isOn: $includeDeviceInfo) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Include Device Information")
                    .font(MendFont.headline)
                    .foregroundColor(textColor)
                
                Text("This helps us diagnose issues specific to certain devices or iOS versions")
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
    }
    
    private var systemLogsSection: some View {
        Toggle(isOn: $includeSystemLogs) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Include System Logs")
                    .font(MendFont.headline)
                    .foregroundColor(textColor)
                
                Text("Attaching logs can help our developers identify the root cause of the issue")
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
    }
    
    private var contactEmailSection: some View {
        Toggle(isOn: $keepMeUpdated) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keep Me Updated")
                    .font(MendFont.headline)
                    .foregroundColor(textColor)
                
                Text("We'll let you know when this issue is resolved")
                    .font(MendFont.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
    }
    
    private var submitButton: some View {
        Button(action: {
            submitBugReport()
        }) {
            HStack {
                if requestService.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 5)
                } else {
                    Image(systemName: "ladybug.fill")
                        .padding(.trailing, 5)
                }
                Text("Submit Bug Report")
            }
            .font(MendFont.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? MendColors.accentButton : MendColors.accentButton.opacity(0.5))
            .cornerRadius(MendCornerRadius.medium)
        }
        .disabled(!isFormValid || requestService.isSubmitting)
        .padding(.top, MendSpacing.medium)
    }
    
    private var isFormValid: Bool {
        !bugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (includeScreenshot ? screenshot != nil : true)
    }
    
    private var screenshotData: Data? {
        screenshot?.jpegData(compressionQuality: 0.8)
    }
    
    private func submitBugReport() {
        let bugReport = BugReportModel(
            category: selectedCategory.rawValue,
            description: bugDescription,
            reproductionSteps: reproducibleSteps,
            systemLogs: includeSystemLogs ? gatherSystemLogs() : nil,
            screenshot: includeScreenshot ? screenshotData : nil,
            keepMeUpdated: keepMeUpdated
        )
        
        Task {
            let result = await requestService.submitBugReport(bugReport)
            
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
    
    private func gatherSystemLogs() -> String? {
        // This is a simplified representation of log gathering
        // In a real app, you would use OSLog to collect relevant logs
        let logs = OSLog.collect(subsystem: "com.mend.app", category: "bugs", level: .error)
        return logs
    }
}

// MARK: - Models
struct BugReport: Codable {
    let category: String
    let description: String
    let reproductionSteps: String?
    let deviceInfo: DeviceInfo?
    let systemLogs: String?
    let screenshot: String?
    let keepMeUpdated: Bool
    var timestamp: Date = Date()
}

struct DeviceInfo: Codable {
    let deviceModel: String
    let systemName: String
    let systemVersion: String
    let appVersion: String
    let buildNumber: String
}

// MARK: - OSLog Extension for demo purposes
extension OSLog {
    static func collect(subsystem: String, category: String, level: OSLogType) -> String {
        // This is a placeholder. In a real app, you would use the OSLogStore API
        // to collect logs from the system, which requires entitlements.
        return "System logs for subsystem: \(subsystem), category: \(category), level: \(level)"
    }
}

// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ReportBugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ReportBugView()
        }
    }
}

// Helper model for submitting bug reports
struct ReportBugViewModel {
    let category: String
    let description: String
    let reproductionSteps: String?
    let includeDeviceInfo: Bool
    let includeSystemLogs: Bool
    let screenshot: Data?
} 
