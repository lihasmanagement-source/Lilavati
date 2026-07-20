import SwiftUI

struct MathItReservedLevelView: View {
    @Environment(\.mathItAccent) private var accent

    let level: Int
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(0.16), Color(red: 0.01, green: 0.014, blue: 0.012), .black],
                center: .center,
                startRadius: 40,
                endRadius: 540
            )
            .ignoresSafeArea()

            HomeButton(action: onLevelSelect)
                .position(x: 34, y: 54)

            VStack(spacing: 18) {
                Text("LEVEL \(level)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.58))

                Text("RESERVED")
                    .font(.system(size: 38, weight: .light, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.82))

                Text("This slot is ready for a new puzzle.")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.56))

                HStack(spacing: 12) {
                    Button(action: onLevelSelect) {
                        Text("LEVELS")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.86))
                            .frame(width: 124, height: 48)
                            .background(.black.opacity(0.72), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: onContinue) {
                        Text(level == 100 ? "DONE" : "NEXT")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.black.opacity(0.78))
                            .frame(width: 124, height: 48)
                            .background(accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
