import SwiftUI

struct AboutView: View {
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
        List {
            NavigationLink(destination: PrivacyPolicyView()) {
                sectionCard(icon: "lock.shield", title: "Privacy Policy")
            }
            .listRowBackground(cardBackgroundColor)
            
            NavigationLink(destination: CommunityGuidelinesView()) {
                sectionCard(icon: "person.3", title: "Community Guidelines")
            }
            .listRowBackground(cardBackgroundColor)
            
            Group {
                HStack {
                    Text("App Version")
                        .font(MendFont.body)
                        .foregroundColor(textColor)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                        .font(MendFont.body)
                        .foregroundColor(secondaryTextColor)
                }
                .padding(MendSpacing.medium)
            }
            .listRowBackground(cardBackgroundColor)
        }
        .listStyle(PlainListStyle())
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("About")
    }
    
    private func sectionCard(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MendColors.primary)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(MendFont.body)
                .foregroundColor(textColor)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(secondaryTextColor)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(MendSpacing.medium)
    }
} 