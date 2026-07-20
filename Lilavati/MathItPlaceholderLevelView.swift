import SwiftUI

// A stand-in screen for curriculum topics that haven't been built yet. Shows the
// topic's place in the curriculum plus a "coming soon" note, and lets the player
// step past it so the sequence stays contiguous.
struct MathItPlaceholderLevelView: View {
    let number: Int
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let gold = Color.mathGold

    var body: some View {
        let placement = MathItCurriculum.placement(forPosition: number)
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.10),
                                    Color(red: 0.02, green: 0.02, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            HomeButton(action: onLevelSelect).position(x: 34, y: 54)

            VStack(spacing: 16) {
                if let p = placement {
                    Text(p.section.title.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(2)
                        .foregroundStyle(p.section.color.opacity(0.9))
                    Text("\(p.topic.number)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(gold.opacity(0.6))
                    Text(p.topic.title)
                        .font(.trajan(30))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Image(systemName: "hammer.fill")
                    .font(.system(size: 28)).foregroundStyle(gold.opacity(0.7))
                    .padding(.vertical, 2)

                Text("This level is being built.\nComing soon.")
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    conceptCapsuleButton("Skip Ahead", filled: true, accent: gold, action: onContinue)
                    conceptCapsuleButton("Levels", filled: false, accent: gold, action: onLevelSelect)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
    }
}
