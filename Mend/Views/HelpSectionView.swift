import SwiftUI

struct HelpSectionView: View {
    let title: String
    let content: String
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
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
        ScrollView {
            VStack(alignment: .leading, spacing: MendSpacing.large) {
                VStack(alignment: .leading, spacing: MendSpacing.medium) {
                    Text(content)
                        .font(MendFont.body)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(cardBackgroundColor)
                .cornerRadius(MendCornerRadius.medium)
            }
            .padding()
        }
        .navigationTitle(title)
        .background(backgroundColor.ignoresSafeArea())
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        HelpSectionView(
            title: "Privacy Policy",
            content: """
            # Privacy Policy
            
            Effective Date: April 24, 2025
            
            ## Introduction
            
            Your privacy is important to us. This Privacy Policy explains how Mend collects, uses, and safeguards your information when you use our mobile application.
            
            ## Information We Collect
            
            **Health and Fitness Data**: We collect health data from Apple Health, including heart rate, HRV, sleep metrics, and activity information. This data is used solely to provide recovery insights and recommendations.
            
            **Device Information**: We collect basic device information to improve app performance and troubleshoot issues.
            
            ## How We Use Your Information
            
            - To provide personalized recovery metrics and training recommendations
            - To improve our app's functionality and user experience
            - To diagnose technical issues and optimize performance
            
            ## Data Storage and Security
            
            All health data is processed locally on your device. We implement appropriate security measures to protect your personal information.
            
            ## Third-Party Services
            
            We do not share your health data with third parties for advertising or marketing purposes.
            
            ## Your Rights
            
            You can control what health data is shared with Mend through your device's privacy settings. You may request deletion of your account data at any time.
            
            ## Changes to This Policy
            
            We may update this policy periodically. We will notify you of any significant changes.
            
            ## Contact Us
            
            If you have questions about this policy, please contact us at privacy@mendapp.com
            """
        )
    }
}

struct CommunityGuidelinesView: View {
    var body: some View {
        HelpSectionView(
            title: "Community Guidelines",
            content: """
            # Community Guidelines
            
            Welcome to the Mend community! These guidelines help ensure our community remains supportive, informative, and respectful.
            
            ## Core Values
            
            **Respect**: Treat everyone with dignity and respect, regardless of background, fitness level, or experience.
            
            **Support**: Encourage others in their recovery and training journeys. We're all here to improve.
            
            **Knowledge**: Share evidence-based information and be open to learning from others.
            
            **Inclusivity**: Make everyone feel welcome and valued in our community spaces.
            
            ## Prohibited Behaviors
            
            - Harassment or bullying of any kind
            - Sharing dangerous or extreme training advice
            - Promoting unhealthy behaviors or attitudes toward recovery
            - Spam, promotional content, or irrelevant discussions
            - Sharing personal information without consent
            
            ## Content Guidelines
            
            When posting in Mend community spaces (forums, social channels, etc.):
            
            - Be constructive and supportive in your feedback
            - Respect intellectual property and give credit where due
            - Keep discussions relevant to recovery, training, and wellness
            - Consider the diversity of our community when sharing
            
            ## Reporting Violations
            
            If you encounter content that violates these guidelines, please report it to community@mendapp.com
            
            Thank you for helping make Mend a positive and supportive community!
            """
        )
    }
} 