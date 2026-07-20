import SwiftUI

struct AlgebraChoiceDefinition {
    let number: Int
    let title: String
    let prompt: String
    let options: [String]
    let correct: String
    let explanation: String
}

extension AlgebraChoiceDefinition {
    static let levels: [Int: AlgebraChoiceDefinition] = [
        46: .init(
            number: 46,
            title: "power tower",
            prompt: "The tower shows 2^6. What value reaches the top?",
            options: ["12", "32", "64", "128"],
            correct: "64",
            explanation: "2^6 means 2 multiplied by itself 6 times."
        ),
        47: .init(
            number: 47,
            title: "equation crossroads",
            prompt: "Which expression matches 2(x + 4) - 3?",
            options: ["2x + 1", "2x + 5", "x + 5", "2x + 8"],
            correct: "2x + 5",
            explanation: "Distribute first: 2x + 8 - 3 = 2x + 5."
        ),
        48: .init(
            number: 48,
            title: "sequence greenhouse",
            prompt: "Plant the missing term: 2, 5, 8, ?, 14",
            options: ["9", "10", "11", "12"],
            correct: "11",
            explanation: "The pattern grows by 3 each step."
        ),
        
        49: .init(
            number: 49,
            title: "probability lab",
            prompt: "A chamber has 3 glowing tokens out of 8 total. What is the probability?",
            options: ["3/5", "3/8", "5/8", "8/3"],
            correct: "3/8",
            explanation: "Probability is favorable outcomes over total outcomes."
        ),
        50: .init(
            number: 50,
            title: "inequality gates",
            prompt: "Which symbol opens the gate for 4 ? 6?",
            options: ["<", ">", "=", "≠"],
            correct: "<",
            explanation: "4 is less than 6."
        ),
        
        51: .init(
            number: 51,
            title: "decimal orbit",
            prompt: "Which value belongs farthest from zero?",
            options: ["0.25", "0.5", "3/4", "0.6"],
            correct: "3/4",
            explanation: "3/4 equals 0.75, the largest distance listed."
        ),
        
        52: .init(
            number: 52,
            title: "polynomial foundry",
            prompt: "Combine the blocks: x^2 + 3x + 4 + 2x",
            options: ["x^2 + 5x + 4", "3x^2 + 4", "x^2 + x + 4", "5x + 4"],
            correct: "x^2 + 5x + 4",
            explanation: "Combine like terms: 3x + 2x = 5x."
        ),
        
        53: .init(
            number: 53,
            title: "rate relay",
            prompt: "A runner goes 15 miles in 3 hours. What is the rate?",
            options: ["3 mph", "5 mph", "12 mph", "45 mph"],
            correct: "5 mph",
            explanation: "Rate equals distance divided by time: 15 ÷ 3 = 5."
        )
    ]
}

struct MathItAlgebraChoiceLevelView: View {
    let definition: AlgebraChoiceDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var selected: String?
    @State private var completed = false
    @State private var wrongPulse = false

    private let accent = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 16) {
                    header
                    ProgressView(value: completed ? 1 : selected == definition.correct ? 0.82 : 0.18)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    visual
                        .frame(height: min(260, proxy.size.height * 0.32))
                        .padding(.horizontal, 20)

                    promptCard
                    optionGrid

                    if let selected, selected != definition.correct {
                        Text("Try again. \(definition.explanation)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 38)
                .padding(.bottom, 24)

                CompletionOverlay(
                    title: "Level \(definition.number) Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: replay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.58))

            Text(definition.title)
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(completed ? 1 : 0.35))
        }
    }

    private var promptCard: some View {
        VStack(spacing: 8) {
            Text(definition.prompt)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Text("Choose the answer that completes the design.")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(accent.opacity(0.72))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.28), lineWidth: 1))
        .padding(.horizontal, 22)
    }

    private var optionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(definition.options, id: \.self) { option in
                Button {
                    choose(option)
                } label: {
                    Text(option)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(optionForeground(option))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(optionBackground(option), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(optionStroke(option), lineWidth: 1.4))
                        .shadow(color: option == selected && option == definition.correct ? accent.opacity(0.45) : .clear, radius: 10)
                }
                .buttonStyle(.plain)
                .disabled(completed)
            }
        }
        .padding(.horizontal, 22)
        .scaleEffect(wrongPulse ? 0.985 : 1)
    }

    @ViewBuilder
    private var visual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(accent.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.36), lineWidth: 1.2))

            switch definition.number {
            case 46:
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach([(2, "2^2"), (4, "2^4"), (6, "2^6"), (8, "?")], id: \.0) { height, text in
                        VStack {
                            Text(text).font(.system(.headline, design: .monospaced)).foregroundStyle(accent)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(accent.opacity(0.18 + Double(height) * 0.04))
                                .frame(width: 48, height: CGFloat(height * 22))
                        }
                    }
                }
            case 47:
                VStack(spacing: 18) {
                    Text("2(x + 4) - 3").font(.system(size: 28, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                    Image(systemName: "arrow.down").foregroundStyle(accent)
                    Text("?").font(.system(size: 42, weight: .medium, design: .serif)).foregroundStyle(.white)
                }
            case 48:
                HStack(alignment: .bottom, spacing: 18) {
                    ForEach(Array(["2", "5", "8", "?", "14"].enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 5) {
                            Image(systemName: index == 3 ? "questionmark.circle" : "leaf.fill")
                                .font(.system(size: 20 + CGFloat(index * 7)))
                                .foregroundStyle(accent.opacity(0.55 + Double(index) * 0.09))
                            Capsule().fill(accent.opacity(0.55)).frame(width: 3, height: 24 + CGFloat(index * 12))
                            Text(value).font(.system(.headline, design: .monospaced)).foregroundStyle(.white)
                        }
                    }
                }
            case 49:
                HStack(spacing: 32) {
                    ForEach(0..<8) { index in
                        Circle().fill(index < 3 ? accent : .white.opacity(0.2)).frame(width: 24, height: 24)
                    }
                }
            case 50:
                HStack(spacing: 26) {
                    Text("4").font(.system(size: 54, design: .serif)).foregroundStyle(.white)
                    Text("?").font(.system(size: 60, weight: .thin, design: .serif)).foregroundStyle(accent)
                    Text("6").font(.system(size: 54, design: .serif)).foregroundStyle(.white)
                }
            case 51:
                ZStack {
                    ForEach([70.0, 120.0, 170.0], id: \.self) { diameter in
                        Circle().stroke(accent.opacity(0.22), lineWidth: 1).frame(width: diameter, height: diameter)
                    }
                    orbitToken("0").offset(x: 0)
                    orbitToken("0.5").offset(x: 84)
                    orbitToken("?").offset(x: -54, y: -66)
                }
            case 52:
                HStack(alignment: .bottom, spacing: 12) {
                    RoundedRectangle(cornerRadius: 6).fill(accent.opacity(0.65)).frame(width: 104, height: 104).overlay(Text("x^2"))
                    ForEach(0..<5) { _ in RoundedRectangle(cornerRadius: 4).fill(accent.opacity(0.38)).frame(width: 24, height: 76) }
                    ForEach(0..<4) { _ in RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.55)).frame(width: 24, height: 24) }
                }
            default:
                VStack(spacing: 18) {
                    HStack(spacing: 20) {
                        Text("15 miles").conceptGate(accent)
                        Text("3 hours").conceptGate(accent)
                    }
                    Image(systemName: "arrow.down").foregroundStyle(accent)
                    Text("rate = ?").font(.system(size: 26, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
            }
        }
    }

    private func orbitToken(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(8)
            .background(.black, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.7), lineWidth: 1))
    }

    private func choose(_ option: String) {
        selected = option
        if option == definition.correct {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                wrongPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
                    wrongPulse = false
                }
            }
        }
    }

    private func replay() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            selected = nil
            completed = false
            wrongPulse = false
        }
    }

    private func optionForeground(_ option: String) -> Color {
        guard let selected else { return .white }
        if option == selected && option == definition.correct { return .black }
        if option == selected { return .red.opacity(0.9) }
        return .white.opacity(0.58)
    }

    private func optionBackground(_ option: String) -> Color {
        option == selected && option == definition.correct ? accent : .black.opacity(0.86)
    }

    private func optionStroke(_ option: String) -> Color {
        if option == selected && option == definition.correct { return accent }
        if option == selected { return .red.opacity(0.7) }
        return accent.opacity(0.36)
    }
}

private extension View {
    func conceptGate(_ accent: Color) -> some View {
        self
            .font(.system(.headline, design: .monospaced))
            .foregroundStyle(accent)
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(accent.opacity(0.7), lineWidth: 1.2))
    }
}
