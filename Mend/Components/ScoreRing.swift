import SwiftUI

struct ScoreRing: View {
    let score: Int
    let size: CGFloat
    let lineWidth: CGFloat
    let showText: Bool
    
    init(score: Int, size: CGFloat = 120, lineWidth: CGFloat = 10, showText: Bool = true) {
        self.score = score
        self.size = size
        self.lineWidth = lineWidth
        self.showText = showText
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            // Foreground ring
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .scoreRingStyle(score: score)
                .rotationEffect(.degrees(-90))
                .animation(.mendSpring, value: score)
            
            // Score text
            if showText {
                Text("\(score)")
                    .font(MendFont.title)
                    .fontWeight(.bold)
                    .scoreRingStyle(score: score)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        ScoreRing(score: 35)
        ScoreRing(score: 65)
        ScoreRing(score: 85)
    }
    .padding()
} 