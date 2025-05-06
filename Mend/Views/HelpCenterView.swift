import SwiftUI

struct HelpCenterView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var themeVersion = 0
    
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
    
    @State private var expandedQuestions: Set<Int> = []
    
    private let faqs = [
        FAQ(question: "How does Mend calculate my recovery score?", 
            answer: "Mend analyzes various health metrics including heart rate variability, resting heart rate, sleep quality, and exercise intensity to calculate your recovery score. The algorithm considers your baseline metrics and recent trends to provide a personalized recovery assessment."),
        
        FAQ(question: "Is my health data secure?", 
            answer: "Yes, your health data is processed locally on your device and is not shared with any third parties. Mend uses Apple's HealthKit framework which maintains strict privacy controls. You can review our complete privacy policy for more details."),
        
        FAQ(question: "How often should I check my recovery score?", 
            answer: "For optimal results, we recommend checking your recovery score each morning. This provides the most accurate assessment based on your overnight recovery and helps you make informed decisions about your training intensity for the day."),
        
        FAQ(question: "Why does my recovery score fluctuate?", 
            answer: "Recovery scores naturally fluctuate based on numerous factors including sleep quality, stress levels, nutrition, hydration, and training intensity. These variations help you understand how your body is responding to your lifestyle and training load."),
        
        FAQ(question: "How do I import my health data?", 
            answer: "Mend can access your health data directly from Apple Health. Go to Settings > Data Import > Import Apple Health Data and follow the prompts. You'll need to grant Mend permission to access specific health metrics."),
        
        FAQ(question: "Can I use Mend without sharing my health data?", 
            answer: "While Mend's primary function relies on analyzing health metrics to provide recovery insights, you can use basic features without sharing health data. However, personalized recovery scoring requires access to your health metrics."),
        
        FAQ(question: "What should I do if my recovery score is low?", 
            answer: "A low recovery score suggests your body needs more recovery time. Consider reducing training intensity, focusing on active recovery, ensuring adequate nutrition and hydration, and prioritizing quality sleep. Listen to your body and adjust your training accordingly.")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: MendSpacing.medium) {
                Text("Frequently Asked Questions")
                    .font(MendFont.title3)
                    .foregroundColor(textColor)
                    .padding(.top)
                    .id("faq-title-\(themeVersion)")
                
                ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                    faqCard(faq: faq, index: index)
                        .id("faq-card-\(index)-\(themeVersion)")
                }
                
                ContactSupportSection()
                    .padding(.top, MendSpacing.large)
                    .padding(.bottom, MendSpacing.extraLarge)
                    .id("contact-section-\(themeVersion)")
            }
            .padding()
            .padding(.bottom, 50)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: colorScheme) { _, _ in
            // Update themeVersion to force UI refresh on theme change
            themeVersion += 1
        }
    }
    
    private func faqCard(faq: FAQ, index: Int) -> some View {
        let isExpanded = expandedQuestions.contains(index)
        
        return VStack(alignment: .leading, spacing: 0) {
            // Question header
            Button(action: {
                if isExpanded {
                    expandedQuestions.remove(index)
                } else {
                    expandedQuestions.insert(index)
                }
            }) {
                HStack {
                    Text(faq.question)
                        .font(MendFont.headline)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(MendColors.primary)
                        .animation(.easeInOut, value: isExpanded)
                }
                .padding(MendSpacing.medium)
            }
            
            // Answer section
            if isExpanded {
                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    .padding(.horizontal, MendSpacing.small)
                
                Text(faq.answer)
                    .font(MendFont.body)
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(MendSpacing.medium)
                    .transition(.opacity)
            }
        }
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

struct ContactSupportSection: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var themeVersion = 0
    
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
        VStack(alignment: .center, spacing: MendSpacing.medium) {
            Text("Still Need Help?")
                .font(MendFont.title3)
                .foregroundColor(textColor)
                .id("help-title-\(themeVersion)")
            
            Text("Our support team is ready to assist you with any questions or issues you might have.")
                .font(MendFont.body)
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
                .id("help-text-\(themeVersion)")
            
            Button(action: {
                if let url = URL(string: "mailto:mendsupport@icloud.com") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Contact Support")
                }
                .font(MendFont.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(MendColors.primary)
                .cornerRadius(MendCornerRadius.medium)
            }
            .padding(.horizontal, MendSpacing.medium)
            .padding(.top, MendSpacing.small)
        }
        .padding(MendSpacing.large)
        .background(cardBackgroundColor)
        .cornerRadius(MendCornerRadius.medium)
        .onChange(of: colorScheme) { _, _ in
            // Update themeVersion to force UI refresh on theme change
            themeVersion += 1
        }
    }
}

struct FAQ {
    let question: String
    let answer: String
}

struct HelpCenterView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HelpCenterView()
        }
    }
} 
