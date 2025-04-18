import SwiftUI

// MARK: - Colors
struct MendColors {
    // Main colors
    static let primary: Color = Color(red: 0x61/255, green: 0x7E/255, blue: 0xFF/255) // Blue primary accent
    static let secondary: Color = Color(red: 0x4D/255, green: 0xF7/255, blue: 0xA1/255) // Mint green for highlights
    
    // Background colors
    static let background: Color = Color(red: 0xF5/255, green: 0xF5/255, blue: 0xF5/255) // Light gray background
    static let darkBackground: Color = Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0F/255) // Very dark background
    static let cardBackground: Color = .white
    static let darkCardBackground: Color = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1F/255) // Dark card background
    
    // Text colors
    static let text: Color = Color(red: 0x11/255, green: 0x11/255, blue: 0x11/255)
    static let darkText: Color = .white
    static let secondaryText: Color = Color(red: 0x88/255, green: 0x88/255, blue: 0x88/255)
    
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
}

enum MendCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let pill: CGFloat = 24
}

enum MendFont {
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title = Font.system(.title, design: .default).weight(.bold)
    static let title2 = Font.system(.title2, design: .default).weight(.bold)
    static let title3 = Font.system(.title3, design: .default).weight(.bold)
    static let headline = Font.system(.headline, design: .default).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let callout = Font.system(.callout, design: .default)
    static let subheadline = Font.system(.subheadline, design: .default)
    static let footnote = Font.system(.footnote, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let caption2 = Font.system(.caption2, design: .default)
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