import SwiftUI

struct ScoreRing: View {
    let score: Int
    let size: CGFloat
    let lineWidth: CGFloat
    let showText: Bool
    @Environment(\.colorScheme) var colorScheme
    
    init(score: Int, size: CGFloat = 120, lineWidth: CGFloat = 10, showText: Bool = true) {
        self.score = score
        self.size = size
        self.lineWidth = lineWidth
        self.showText = showText
    }
    
    private var scoreColor: Color {
        switch score {
        case 0..<40: return MendColors.negative
        case 40..<70: return MendColors.neutral
        default: return MendColors.positive
        }
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : MendColors.text
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.15),
                    lineWidth: lineWidth
                )
            
            // Foreground ring
            Circle()
                .trim(from: 0, to: max(0.01, CGFloat(score) / 100)) // Ensure at least a tiny arc is visible
                .stroke(
                    scoreGradient(),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.mendSpring, value: score)
                .shadow(color: scoreColor.opacity(0.3), radius: 3, x: 0, y: 0)
            
            // Score text
            if showText {
                Text("\(score)")
                    .font(.system(size: size * 0.25, weight: .bold, design: .default))
                    .foregroundColor(textColor)
            }
        }
        .frame(width: size, height: size)
    }
    
    private func scoreGradient() -> AngularGradient {
        let baseColor = scoreColor
        
        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: baseColor.opacity(0.8), location: 0),
                .init(color: baseColor, location: 0.5),
                .init(color: baseColor.opacity(0.8), location: 1)
            ]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}

#Preview {
    ZStack {
        Color(red: 0.95, green: 0.95, blue: 0.95)
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            ScoreRing(score: 35)
            ScoreRing(score: 65)
            ScoreRing(score: 85)
        }
        .padding()
    }
} 