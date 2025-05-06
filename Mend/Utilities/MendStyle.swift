import SwiftUI

// MARK: - Colors
struct MendColors {
    // Main colors
    static let primary: Color = Color(red: 0x61/255, green: 0x7E/255, blue: 0xFF/255) // Blue primary accent
    static let secondary: Color = Color(red: 0x4D/255, green: 0xF7/255, blue: 0xA1/255) // Mint green for highlights
    
    // Background colors
    static let background: Color = Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF4/255) // Light gray background (more like Polycam)
    static let darkBackground: Color = Color(red: 0x06/255, green: 0x06/255, blue: 0x0A/255) // Darker background for better contrast
    static let cardBackground: Color = .white
    static let darkCardBackground: Color = Color(red: 0x15/255, green: 0x15/255, blue: 0x1A/255) // Slightly darker card background
    
    // Text colors
    static let text: Color = Color(red: 0x11/255, green: 0x11/255, blue: 0x11/255)
    static let darkText: Color = .white // Pure white for maximum contrast
    static let secondaryText: Color = Color(red: 0x66/255, green: 0x66/255, blue: 0x66/255) // Darker for better contrast
    static let darkSecondaryText: Color = Color(red: 0xE2/255, green: 0xE2/255, blue: 0xE2/255) // Lighter for better contrast in dark mode
    
    // Status colors
    static let positive: Color = Color(red: 0x4D/255, green: 0xF7/255, blue: 0xA1/255) // Mint green
    static let negative: Color = Color(red: 0xFF/255, green: 0x56/255, blue: 0x56/255) // Red
    static let neutral: Color = Color(red: 0xFF/255, green: 0xDA/255, blue: 0x55/255) // Yellow
    
    // Button colors
    static let accentButton: Color = Color(red: 0x61/255, green: 0x7E/255, blue: 0xFF/255)
    static let highlightButton: Color = Color(red: 0x4D/255, green: 0xF7/255, blue: 0xA1/255)
}

// MARK: - UI Constants
enum MendSpacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
    static let notificationMenu: CGFloat = 10
}

enum MendCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let pill: CGFloat = 24
}

// MARK: - Font styles more like Polycam
enum MendFont {
    // Polycam uses SF Pro with more consistent weights
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title = Font.system(.title, design: .default).weight(.bold)
    static let title2 = Font.system(.title2, design: .default).weight(.semibold)
    static let title3 = Font.system(.title3, design: .default).weight(.semibold)
    static let headline = Font.system(.headline, design: .default).weight(.medium)
    static let body = Font.system(.body, design: .default).weight(.regular)
    static let callout = Font.system(.callout, design: .default).weight(.regular)
    static let subheadline = Font.system(.subheadline, design: .default).weight(.regular)
    static let footnote = Font.system(.footnote, design: .default).weight(.regular)
    static let caption = Font.system(.caption, design: .default).weight(.medium)
    static let caption2 = Font.system(.caption2, design: .default).weight(.medium)
    
    // Polycam-style text styles
    static let sectionHeader = Font.system(.subheadline, design: .default).weight(.semibold)
    static let tabLabel = Font.system(.caption, design: .default).weight(.medium)
}

// MARK: - View Extensions
extension View {
    // Light-themed card (white background)
    func mendCard() -> some View {
        self
            .padding(MendSpacing.medium)
            .background(MendColors.cardBackground)
            .cornerRadius(MendCornerRadius.medium)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
    
    // Dark-themed card (dark background)
    func mendDarkCard() -> some View {
        self
            .padding(MendSpacing.medium)
            .background(MendColors.darkCardBackground)
            .cornerRadius(MendCornerRadius.medium)
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2) // Added shadow for better visibility
    }
    
    // Button style similar to Polycam
    func mendButtonStyle(color: Color = MendColors.primary) -> some View {
        self
            .padding(.vertical, MendSpacing.medium)
            .padding(.horizontal, MendSpacing.large)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(MendCornerRadius.pill)
    }
    
    // Tab item style
    func mendTabStyle(isSelected: Bool) -> some View {
        self
            .padding(.vertical, MendSpacing.small)
            .padding(.horizontal, MendSpacing.medium)
            .background(isSelected ? MendColors.primary.opacity(0.1) : Color.clear)
            .cornerRadius(MendCornerRadius.pill)
            .foregroundColor(isSelected ? MendColors.primary : MendColors.secondaryText)
    }
    
    func scoreRingStyle(score: Int) -> some View {
        let color: Color = switch score {
        case 0..<40: MendColors.negative
        case 40..<70: MendColors.neutral
        default: MendColors.positive
        }
        
        return self.foregroundColor(color)
    }
    
    // Helper function to get appropriate secondary text color based on color scheme
    func adaptiveSecondaryTextColor(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText
    }
    
    // Standard section header styling to ensure consistency across the app
    func mendSectionHeader(title: String, colorScheme: ColorScheme) -> some View {
        Text(title)
            .font(MendFont.headline)
            .foregroundColor(colorScheme == .dark ? MendColors.darkSecondaryText : MendColors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .background(colorScheme == .dark ? MendColors.darkBackground : MendColors.background)
    }
}

// MARK: - Animation Extensions
extension Animation {
    static var mendSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.7)
    }
    
    static var mendEaseInOut: Animation {
        .easeInOut(duration: 0.3)
    }
} 