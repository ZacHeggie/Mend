import SwiftUI

struct CooldownStatusView: View {
    let isInCooldown: Bool
    let percentage: Int
    let description: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: MendSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Status")
                        .font(MendFont.headline)
                        .foregroundColor(colorScheme == .dark ? MendColors.darkText : MendColors.text)
                    
                    Text(description)
                        .font(MendFont.subheadline)
                        .foregroundColor(colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Recovery progress ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(
                            colorScheme == .dark ? MendColors.darkCardBackground : MendColors.background,
                            lineWidth: 8
                        )
                        .frame(width: 60, height: 60)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(percentage) / 100)
                        .stroke(
                            progressColor,
                            style: StrokeStyle(
                                lineWidth: 8,
                                lineCap: .round
                            )
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    // Percentage text
                    Text("\(percentage)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(progressColor)
                }
            }
            
            if isInCooldown {
                // Recovery tips when in cool-down
                recoveryTipsSection
            }
        }
        .padding(MendSpacing.medium)
        .background(colorScheme == .dark ? MendColors.darkCardBackground : MendColors.cardBackground)
        .cornerRadius(MendSpacing.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var progressColor: Color {
        if percentage < 40 {
            return MendColors.negative
        } else if percentage < 70 {
            return MendColors.neutral
        } else {
            return MendColors.positive
        }
    }
    
    private var recoveryTipsSection: some View {
        VStack(alignment: .leading, spacing: MendSpacing.small) {
            Text("Recovery Tips")
                .font(MendFont.subheadline)
                .foregroundColor(colorScheme == .dark ? MendColors.darkText : MendColors.text)
                .padding(.top, MendSpacing.small)
            
            // Recovery tips based on recovery percentage
            ForEach(recoveryTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: MendSpacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MendColors.primary)
                        .font(.system(size: 14))
                    
                    Text(tip)
                        .font(MendFont.footnote)
                        .foregroundColor(colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // Dynamic recovery tips based on recovery percentage
    private var recoveryTips: [String] {
        if percentage < 30 {
            return [
                "Focus on passive recovery activities like gentle stretching and mobility work",
                "Ensure you get adequate sleep for optimal recovery",
                "Stay hydrated and focus on nutrient-rich foods to aid recovery",
                "Consider compression garments to improve circulation"
            ]
        } else if percentage < 70 {
            return [
                "Light activity like walking or gentle yoga can promote active recovery",
                "Consider contrast therapy (alternating hot and cold) to reduce inflammation",
                "Focus on proper nutrition with emphasis on protein intake for tissue repair",
                "Monitor your sleep quality and aim for 7-9 hours"
            ]
        } else {
            return [
                "You're almost fully recovered - listen to your body if resuming training",
                "Start with lower intensity before returning to your regular training load",
                "Continue proper nutrition and hydration practices",
                "Pay attention to any lingering soreness or fatigue"
            ]
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CooldownStatusView(
            isInCooldown: true,
            percentage: 25,
            description: "Recovery in progress: 36 hr remaining"
        )
        
        CooldownStatusView(
            isInCooldown: true,
            percentage: 65,
            description: "Recovery in progress: 12 hr remaining"
        )
        
        CooldownStatusView(
            isInCooldown: false,
            percentage: 100,
            description: "Fully recovered"
        )
    }
    .padding()
    .background(MendColors.background.opacity(0.5))
} 