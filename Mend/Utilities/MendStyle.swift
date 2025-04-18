import SwiftUI

// MARK: - Colors
struct MendColors {
    static let primary: Color = Color(red: 0x45/255, green: 0x67/255, blue: 0xDF/255)
    static let secondary: Color = Color(red: 0xF5/255, green: 0x58/255, blue: 0x9F/255)
    static let background: Color = Color(red: 0xF4/255, green: 0xF6/255, blue: 0xF8/255)
    static let cardBackground: Color = .white
    static let text: Color = Color(red: 0x11/255, green: 0x22/255, blue: 0x33/255)
    static let positive: Color = Color(red: 0x4C/255, green: 0xC2/255, blue: 0x7A/255)
    static let negative: Color = Color(red: 0xF5/255, green: 0x55/255, blue: 0x55/255)
    static let neutral: Color = Color(red: 0xF5/255, green: 0xC2/255, blue: 0x55/255)
}

// MARK: - UI Constants
enum MendSpacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
}

enum MendCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

enum MendFont {
    static let title = Font.system(.title, design: .rounded).weight(.bold)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let subheadline = Font.system(.subheadline, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
}

// MARK: - View Extensions
extension View {
    func mendCard() -> some View {
        self
            .padding(MendSpacing.medium)
            .background(MendColors.cardBackground)
            .cornerRadius(MendCornerRadius.medium)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
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