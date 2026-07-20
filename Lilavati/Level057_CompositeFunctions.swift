import SwiftUI

// MARK: - Level 57 - Composite Functions
//
// Composition is nesting. Each round adds one more doll/function. The player
// opens the chain outward, then the values evaluate back inward.

struct MathItCompositeFunctionsLevelView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private struct Round {
        let functionDefinitions: [String]
        let composite: String
        let functionAnswers: [String]
        let functionChoices: [[String]]
        let inputAnswer: String
        let inputChoices: [String]
        let cascade: [String]
        let colors: [Color]
    }

    private enum Phase: Equatable {
        case closed
        case chooseFunction(Int)
        case chooseInput
        case cascade
    }

    private let rounds: [Round] = [
        Round(
            functionDefinitions: ["f(x) = 2x + 1", "g(x) = x²"],
            composite: "f(g(3))",
            functionAnswers: ["g(x)"],
            functionChoices: [["g(x)", "f(x)", "f(g(x))"]],
            inputAnswer: "x = 3",
            inputChoices: ["x = 3", "g(3)", "f(x)"],
            cascade: ["x = 3", "g(3) = 9", "f(9) = 19"],
            colors: [
                Color(red: 0.82, green: 0.22, blue: 0.20),
                Color(red: 0.24, green: 0.62, blue: 0.58),
                Color(red: 0.90, green: 0.76, blue: 0.35)
            ]
        ),
        Round(
            functionDefinitions: ["h(x) = x - 3", "f(x) = x²", "g(x) = x + 3"],
            composite: "h(f(g(2)))",
            functionAnswers: ["f(x)", "g(x)"],
            functionChoices: [
                ["f(x)", "h(x)", "g(f(x))"],
                ["g(x)", "f(x)", "x"]
            ],
            inputAnswer: "x = 2",
            inputChoices: ["g(2)", "x = 2", "h(x)"],
            cascade: ["x = 2", "g(2) = 5", "f(5) = 25", "h(25) = 22"],
            colors: [
                Color(red: 0.34, green: 0.38, blue: 0.86),
                Color(red: 0.82, green: 0.56, blue: 0.20),
                Color(red: 0.22, green: 0.66, blue: 0.48),
                Color(red: 0.90, green: 0.76, blue: 0.35)
            ]
        ),
        Round(
            functionDefinitions: ["p(x) = 2x", "h(x) = x - 1", "f(x) = 3x", "g(x) = x + 2"],
            composite: "p(h(f(g(1))))",
            functionAnswers: ["h(x)", "f(x)", "g(x)"],
            functionChoices: [
                ["h(x)", "p(x)", "f(g(x))"],
                ["f(x)", "h(x)", "p(f(x))"],
                ["x", "g(x)", "f(x)"]
            ],
            inputAnswer: "x = 1",
            inputChoices: ["x = 1", "g(1)", "h(f(x))"],
            cascade: ["x = 1", "g(1) = 3", "f(3) = 9", "h(9) = 8", "p(8) = 16"],
            colors: [
                Color(red: 0.58, green: 0.32, blue: 0.76),
                Color(red: 0.22, green: 0.66, blue: 0.48),
                Color(red: 0.78, green: 0.22, blue: 0.30),
                Color(red: 0.26, green: 0.58, blue: 0.82),
                Color(red: 0.90, green: 0.76, blue: 0.35)
            ]
        )
    ]

    @State private var roundIndex = 0
    @State private var phase: Phase = .closed
    @State private var dollLabels: [String?] = []
    @State private var dollHops: [Bool] = []
    @State private var cascadeStep = -1
    @State private var wrongChoice: String?
    @State private var completed = false

    private let gold = Color.mathGold
    private var round: Round { rounds[min(roundIndex, rounds.count - 1)] }
    private var dollCount: Int { round.functionAnswers.count + 2 }
    private var inputIndex: Int { dollCount - 1 }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.03, blue: 0.08), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 8) {
                    Text(round.functionDefinitions.joined(separator: "     "))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .position(x: size.width / 2, y: size.height * 0.16)

                dollStage(size: size)

                choicePanel(size: size)

                CompletionOverlay(
                    title: "Composite Functions",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetAll,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: phase)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: cascadeStep)
            .animation(.interpolatingSpring(stiffness: 165, damping: 11), value: dollHops)
            .onAppear { resetRoundState() }
        }
    }

    private func dollStage(size: CGSize) -> some View {
        let centerY = size.height * 0.45
        return ZStack {
            ForEach(0..<visibleDollCount, id: \.self) { index in
                let point = dollPosition(index: index, centerY: centerY, size: size)
                CompositeDollView(
                    color: color(for: index),
                    label: label(for: index),
                    scale: scale(for: index),
                    highlighted: highlighted(index),
                    lidOpen: lidOpen(index)
                )
                .rotationEffect(.degrees(hopped(index) ? 0 : (index.isMultiple(of: 2) ? -8 : 7)))
                .position(point)
                .transition(.scale(scale: 0.18).combined(with: .opacity))
                .zIndex(Double(index))
                .onTapGesture {
                    guard index == 0, phase == .closed else { return }
                    HapticPlayer.playLightTap()
                    resetRoundState()
                    phase = .chooseFunction(0)
                    revealDoll(1)
                }
            }
        }
    }

    @ViewBuilder
    private func choicePanel(size: CGSize) -> some View {
        VStack(spacing: 10) {
            switch phase {
            case .closed:
                EmptyView()
            case .chooseFunction(let index):
                chips(round.functionChoices[index]) { chooseFunction($0, at: index) }
            case .chooseInput:
                chips(round.inputChoices) { chooseInput($0) }
            case .cascade:
                if cascadeStep >= round.cascade.count - 1 {
                    Button(roundIndex == rounds.count - 1 ? "FINISH" : "NEXT DOLL") { finishRound() }
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(gold))
                        .buttonStyle(.plain)
                }
            }

            if wrongChoice != nil {
                Circle()
                    .fill(Color(red: 1.0, green: 0.28, blue: 0.34))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(red: 1.0, green: 0.28, blue: 0.34).opacity(0.55), radius: 8)
            }
        }
        .frame(width: min(size.width - 44, 370))
        .position(x: size.width / 2, y: size.height * 0.84)
    }

    private func chips(_ values: [String], action: @escaping (String) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(values, id: \.self) { value in
                Button(value) { action(value) }
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(gold.opacity(0.28), lineWidth: 1))
                    .buttonStyle(.plain)
            }
        }
    }

    private func chooseFunction(_ value: String, at answerIndex: Int) {
        if value == round.functionAnswers[answerIndex] {
            HapticPlayer.playCompletionTap()
            wrongChoice = nil
            setLabel(answerIndex + 1, value)
            let nextAnswer = answerIndex + 1
            if nextAnswer < round.functionAnswers.count {
                phase = .chooseFunction(nextAnswer)
                revealDoll(nextAnswer + 1)
            } else {
                phase = .chooseInput
                revealDoll(inputIndex)
            }
        } else {
            HapticPlayer.playLightTap()
            wrongChoice = value
        }
    }

    private func chooseInput(_ value: String) {
        if value == round.inputAnswer {
            HapticPlayer.playCompletionTap()
            wrongChoice = nil
            setLabel(inputIndex, value)
            phase = .cascade
            cascadeStep = 0
            runReverseCascade()
        } else {
            HapticPlayer.playLightTap()
            wrongChoice = value
        }
    }

    private func runReverseCascade() {
        for index in stride(from: inputIndex, through: 1, by: -1) {
            let step = inputIndex - index
            let base = Double(step) * 0.82
            DispatchQueue.main.asyncAfter(deadline: .now() + base + 0.25) {
                setLabel(index, valuePart(round.cascade[step]))
                HapticPlayer.playLightTap()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + base + 0.54) {
                setHop(index, false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + base + 0.82) {
                setLabel(index - 1, valuePart(round.cascade[step + 1]))
                cascadeStep = step + 1
            }
        }

        let finalDelay = Double(inputIndex) * 0.82 + 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
            HapticPlayer.playCompletionTap()
        }
    }

    private func finishRound() {
        HapticPlayer.playCompletionTap()
        if roundIndex == rounds.count - 1 {
            completed = true
        } else {
            roundIndex += 1
            resetRoundState()
        }
    }

    private func resetAll() {
        roundIndex = 0
        resetRoundState()
        completed = false
    }

    private func resetRoundState() {
        phase = .closed
        dollLabels = Array(repeating: nil, count: dollCount)
        dollLabels[0] = round.composite
        dollHops = Array(repeating: false, count: dollCount)
        dollHops[0] = true
        cascadeStep = -1
        wrongChoice = nil
    }

    private func valuePart(_ expression: String) -> String {
        expression
            .split(separator: "=", maxSplits: 1)
            .last
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? expression
    }

    private var visibleDollCount: Int {
        switch phase {
        case .closed:
            return 1
        case .chooseFunction(let index):
            return min(dollCount, index + 2)
        case .chooseInput, .cascade:
            return dollCount
        }
    }

    private func revealDoll(_ index: Int) {
        setHop(index, false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            setHop(index, true)
        }
    }

    private func setLabel(_ index: Int, _ value: String) {
        guard dollLabels.indices.contains(index) else { return }
        dollLabels[index] = value
    }

    private func setHop(_ index: Int, _ value: Bool) {
        guard dollHops.indices.contains(index) else { return }
        dollHops[index] = value
    }

    private func label(for index: Int) -> String {
        if dollLabels.indices.contains(index), let label = dollLabels[index] { return label }
        if index == 0 { return round.composite }
        return "?"
    }

    private func hopped(_ index: Int) -> Bool {
        if dollHops.indices.contains(index) { return dollHops[index] }
        return index == 0
    }

    private func color(for index: Int) -> Color {
        round.colors[min(index, round.colors.count - 1)]
    }

    private func scale(for index: Int) -> CGFloat {
        let scales: [CGFloat] = [1.0, 0.72, 0.55, 0.42, 0.32]
        return scales[min(index, scales.count - 1)]
    }

    private func finalPoint(index: Int, centerY: CGFloat, size: CGSize) -> CGPoint {
        guard dollCount > 1 else { return CGPoint(x: size.width * 0.33, y: centerY) }
        let usableWidth = min(size.width - 42, CGFloat(96 + (dollCount - 1) * 72))
        let startX = (size.width - usableWidth) / 2 + 48
        let step = (usableWidth - 96) / CGFloat(dollCount - 1)
        return CGPoint(
            x: startX + CGFloat(index) * step,
            y: centerY + CGFloat(index) * 13
        )
    }

    private func dollPosition(index: Int, centerY: CGFloat, size: CGSize) -> CGPoint {
        let final = finalPoint(index: index, centerY: centerY, size: size)
        guard index > 0, !hopped(index) else { return final }
        let parent = finalPoint(index: index - 1, centerY: centerY, size: size)
        return CGPoint(
            x: parent.x,
            y: parent.y + 54 * scale(for: index - 1)
        )
    }

    private func lidOpen(_ index: Int) -> Bool {
        guard phase != .closed, index < inputIndex else { return false }
        switch phase {
        case .cascade:
            return hopped(index + 1) || cascadeStep >= inputIndex - index - 1
        default:
            return index < visibleDollCount - 1
        }
    }

    private func highlighted(_ index: Int) -> Bool {
        phase == .cascade && cascadeStep >= inputIndex - index
    }
}

private struct CompositeDollView: View {
    let color: Color
    let label: String
    let scale: CGFloat
    var highlighted = false
    var lidOpen = false

    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.24))
                .frame(width: 116 * scale, height: 18 * scale)
                .blur(radius: 5 * scale)
                .offset(y: 73 * scale)

            DollBodyShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.78, blue: 0.10),
                            Color(red: 0.94, green: 0.69, blue: 0.09),
                            Color(red: 0.72, green: 0.15, blue: 0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .bottom) {
                    DollBodyShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.96),
                                    color.opacity(0.78)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .mask(
                            Rectangle()
                                .frame(height: 63 * scale)
                                .offset(y: 47 * scale)
                        )
                }
                .overlay(DollBodyShape().stroke(.white.opacity(highlighted ? 0.75 : 0.24), lineWidth: highlighted ? 2.2 : 1.1))
                .frame(width: 110 * scale, height: 150 * scale)
                .shadow(color: Color(red: 0.98, green: 0.74, blue: 0.16).opacity(highlighted ? 0.48 : 0.16), radius: highlighted ? 18 : 8)

            scarfAndFace
                .offset(y: -39 * scale)

            floralPainting
                .offset(y: 26 * scale)

            mathLabel
                .offset(y: 48 * scale)

            GlossShape()
                .fill(.white.opacity(0.24))
                .frame(width: 20 * scale, height: 74 * scale)
                .rotationEffect(.degrees(8))
                .offset(x: -30 * scale, y: -6 * scale)
                .blur(radius: 0.6 * scale)

            if lidOpen {
                DollOpeningShape()
                    .stroke(.black.opacity(0.34), lineWidth: max(1, 1.4 * scale))
                    .frame(width: 72 * scale, height: 24 * scale)
                    .offset(y: -63 * scale)
            }
        }
        .frame(width: 128 * scale, height: 178 * scale)
    }

    private var scarfAndFace: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.98, green: 0.78, blue: 0.10))
                .frame(width: 62 * scale, height: 58 * scale)
                .shadow(color: .black.opacity(0.14), radius: 2 * scale, y: 1 * scale)

            Circle()
                .fill(Color(red: 0.98, green: 0.83, blue: 0.66))
                .frame(width: 43 * scale, height: 39 * scale)
                .offset(y: 3 * scale)

            HairShape()
                .fill(Color(red: 0.06, green: 0.06, blue: 0.09))
                .frame(width: 40 * scale, height: 31 * scale)
                .offset(y: -6 * scale)

            LeafShape()
                .fill(Color(red: 0.12, green: 0.25, blue: 0.16))
                .frame(width: 14 * scale, height: 24 * scale)
                .rotationEffect(.degrees(-26))
                .offset(x: -7 * scale, y: -28 * scale)

            LeafShape()
                .fill(Color(red: 0.12, green: 0.25, blue: 0.16))
                .frame(width: 14 * scale, height: 24 * scale)
                .rotationEffect(.degrees(26))
                .offset(x: 8 * scale, y: -28 * scale)

            faceDetails
        }
    }

    private var faceDetails: some View {
        ZStack {
            Circle().fill(.black).frame(width: 3.5 * scale, height: 3.5 * scale).offset(x: -9 * scale, y: 0)
            Circle().fill(.black).frame(width: 3.5 * scale, height: 3.5 * scale).offset(x: 9 * scale, y: 0)
            Circle().fill(Color(red: 0.86, green: 0.23, blue: 0.28).opacity(0.50)).frame(width: 6 * scale, height: 4 * scale).offset(x: -14 * scale, y: 7 * scale)
            Circle().fill(Color(red: 0.86, green: 0.23, blue: 0.28).opacity(0.50)).frame(width: 6 * scale, height: 4 * scale).offset(x: 14 * scale, y: 7 * scale)
            SmileShape()
                .stroke(Color(red: 0.62, green: 0.06, blue: 0.09), lineWidth: max(0.7, 1.1 * scale))
                .frame(width: 15 * scale, height: 8 * scale)
                .offset(y: 9 * scale)
        }
    }

    private var floralPainting: some View {
        ZStack {
            FlowerView(scale: scale, color: Color(red: 0.72, green: 0.08, blue: 0.13))
                .frame(width: 42 * scale, height: 42 * scale)
                .offset(x: -15 * scale, y: 1 * scale)

            FlowerView(scale: scale * 0.62, color: Color(red: 0.84, green: 0.20, blue: 0.24))
                .frame(width: 30 * scale, height: 30 * scale)
                .offset(x: 24 * scale, y: -17 * scale)

            ForEach(0..<4, id: \.self) { i in
                LeafShape()
                    .fill(Color(red: 0.13, green: 0.35, blue: 0.18))
                    .frame(width: 10 * scale, height: 28 * scale)
                    .rotationEffect(.degrees(Double([-36, -16, 24, 45][i])))
                    .offset(
                        x: CGFloat([-33, -4, 10, 35][i]) * scale,
                        y: CGFloat([-18, -23, 17, 7][i]) * scale
                    )
            }

            Path { path in
                path.move(to: CGPoint(x: 38 * scale, y: 37 * scale))
                path.addCurve(
                    to: CGPoint(x: 82 * scale, y: 18 * scale),
                    control1: CGPoint(x: 46 * scale, y: 10 * scale),
                    control2: CGPoint(x: 70 * scale, y: 42 * scale)
                )
            }
            .stroke(Color(red: 0.16, green: 0.36, blue: 0.20).opacity(0.8), lineWidth: max(0.8, 1.2 * scale))
        }
        .frame(width: 96 * scale, height: 62 * scale)
    }

    private var mathLabel: some View {
        Text(label)
            .font(.system(size: max(8, 13 * scale), weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8 * scale)
            .padding(.vertical, 4 * scale)
            .background(Capsule().fill(.black.opacity(0.34)))
            .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: max(0.6, 1 * scale)))
            .minimumScaleFactor(0.42)
            .lineLimit(1)
            .frame(width: 90 * scale)
    }

}

private struct FlowerView: View {
    let scale: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Ellipse()
                    .fill(color)
                    .frame(width: 9 * scale, height: 20 * scale)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .offset(y: -8 * scale)
            }
            Circle()
                .fill(Color(red: 0.42, green: 0.08, blue: 0.09))
                .frame(width: 12 * scale, height: 12 * scale)
            Circle()
                .stroke(.black.opacity(0.18), lineWidth: max(0.5, 1 * scale))
                .frame(width: 28 * scale, height: 28 * scale)
        }
    }
}

private struct HairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.width * 0.24, y: rect.minY + rect.height * 0.08))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.midY), control: CGPoint(x: rect.width * 0.76, y: rect.minY + rect.height * 0.08))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.43), control: CGPoint(x: rect.width * 0.70, y: rect.minY + rect.height * 0.40))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.midY), control: CGPoint(x: rect.width * 0.30, y: rect.minY + rect.height * 0.40))
        path.closeSubpath()
        return path
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.midY))
        return path
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private struct GlossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: rect)
        return path
    }
}

private struct DollOpeningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY),
            control1: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY),
            control2: CGPoint(x: rect.maxX - rect.width * 0.30, y: rect.maxY)
        )
        return path
    }
}

private struct DollBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.92, y: rect.maxY * 0.72),
            control1: CGPoint(x: rect.maxX * 0.86, y: rect.minY + rect.height * 0.10),
            control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.44)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX * 0.86, y: rect.maxY * 0.94),
            control2: CGPoint(x: rect.maxX * 0.64, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY * 0.72),
            control1: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY),
            control2: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.maxY * 0.94)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.44),
            control2: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.10)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    MathItCompositeFunctionsLevelView(onContinue: {}, onLevelSelect: {})
}
