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
            .padding(.bottom, 50)
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

            ## Your Data Stays on Your Device

            Mend is designed with privacy at its core. All your health and fitness data remains stored locally on your device and is never transmitted to external servers.

            ## Information We Use

            **Health and Fitness Data**: With your permission, Mend accesses health data from Apple Health, including:
            • Heart rate and heart rate variability (HRV)
            • Sleep metrics and patterns
            • Activity and workout information
            • Recovery indicators

            This data remains on your device and is used exclusively to:
            • Calculate your personalized recovery score
            • Generate training recommendations based on your body's readiness
            • Provide insights about your recovery patterns

            **Device Information**: Basic device data is used only for app functionality and troubleshooting, and stays on your device.

            ## Data Security

            Your privacy is protected through:
            • Local processing: All analysis happens directly on your device
            • No external transmission: Your health data never leaves your device
            • Apple's security framework: We utilize iOS security features to protect your information

            ## Your Control

            • You control exactly which health metrics Mend can access through your device's privacy settings
            • You can revoke access to any health category at any time
            • You can request complete deletion of all app data through the Settings menu

            ## No Third-Party Sharing

            We do not:
            • Share your health data with any third parties
            • Use your data for advertising or marketing
            • Sell or transfer your information to other companies

            ## Contact Us

            If you have questions about your privacy, please contact us at:
            mendsupport@icloud.com
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
