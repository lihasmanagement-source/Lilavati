import SwiftUI
import Foundation

enum LevelFiftySymbol: String, CaseIterable {
    case less = "<"
    case equal = "="
    case greater = ">"

    func isTrue(lhs: Double, rhs: Double) -> Bool {
        switch self {
        case .less:
            lhs < rhs
        case .equal:
            abs(lhs - rhs) < 0.0001
        case .greater:
            lhs > rhs
        }
    }
}

struct LevelFiftyExpression {
    let text: String
    let value: Double
}

@Observable
final class MathItLevelFiftyViewModel {
    let roundSeconds = 60

    var selectedIndex: Int?
    var leftExpression = LevelFiftyExpression(text: "0", value: 0)
    var rightExpression = LevelFiftyExpression(text: "0", value: 0)
    var score = 0
    var solvedCount = 0
    var streak = 0
    var timeRemaining = 60
    var completed = false
    var wrongPulse = false

    private var timer: Timer?
    private var relationshipBag: [LevelFiftySymbol] = [.less, .greater, .equal]

    var selectedSymbol: LevelFiftySymbol? {
        guard let selectedIndex else { return nil }
        return LevelFiftySymbol.allCases[selectedIndex]
    }

    var progress: Double {
        Double(roundSeconds - timeRemaining) / Double(roundSeconds)
    }

    var timeText: String {
        "0:\(String(format: "%02d", timeRemaining))"
    }

    func start() {
        cancelTimer()
        selectedIndex = nil
        score = 0
        solvedCount = 0
        streak = 0
        timeRemaining = roundSeconds
        completed = false
        wrongPulse = false
        relationshipBag = [.less, .greater, .equal]
        nextProblem()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    func select(index: Int) {
        guard !completed else { return }
        let nextIndex = min(max(0, index), LevelFiftySymbol.allCases.count - 1)
        guard nextIndex != selectedIndex else { return }
        selectedIndex = nextIndex
        HapticPlayer.playLightTap()
    }

    func submit() {
        guard !completed, let selectedSymbol else {
            markWrong()
            return
        }
        if selectedSymbol.isTrue(lhs: leftExpression.value, rhs: rightExpression.value) {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.74)) {
                score += 1 + min(2, streak / 5)
                solvedCount += 1
                streak += 1
            }
            nextProblem()
        } else {
            streak = 0
            markWrong()
        }
    }

    private func nextProblem() {
        let relationship = nextRelationship()
        let pair = expressionPair(for: relationship)
        leftExpression = pair.left
        rightExpression = pair.right
        selectedIndex = nil
    }

    private func nextRelationship() -> LevelFiftySymbol {
        if relationshipBag.isEmpty {
            relationshipBag = LevelFiftySymbol.allCases.shuffled()
        }
        return relationshipBag.removeFirst()
    }

    private func expressionPair(for relationship: LevelFiftySymbol) -> (left: LevelFiftyExpression, right: LevelFiftyExpression) {
        let left = randomExpression()

        switch relationship {
        case .less:
            return orderedPair(from: left, makeRightGreater: true)
        case .greater:
            return orderedPair(from: left, makeRightGreater: false)
        case .equal:
            return (left, matchingExpression(for: left))
        }
    }

    private func orderedPair(from left: LevelFiftyExpression, makeRightGreater: Bool) -> (left: LevelFiftyExpression, right: LevelFiftyExpression) {
        for _ in 0..<16 {
            let right = randomExpression()
            if makeRightGreater, right.value > left.value {
                return (left, right)
            }
            if !makeRightGreater, right.value < left.value {
                return (left, right)
            }
        }

        let offset = Double(Int.random(in: 1...5))
        let rightValue = left.value + (makeRightGreater ? offset : -offset)
        return (left, LevelFiftyExpression(text: decimalText(rightValue), value: rightValue))
    }

    private func randomExpression() -> LevelFiftyExpression {
        if solvedCount < 5 {
            return integerExpression(range: -8...12)
        }

        if solvedCount < 10 {
            return [integerExpression(range: -12...18), decimalExpression(), fractionExpression()].randomElement()!
        }

        if solvedCount < 16 {
            return [
                integerExpression(range: -16...24),
                decimalExpression(),
                fractionExpression(),
                powerExpression()
            ].randomElement()!
        }

        return [
            integerExpression(range: -18...28),
            decimalExpression(),
            fractionExpression(),
            powerExpression(),
            radicalExpression()
        ].randomElement()!
    }

    private func randomDifferentExpression(from expression: LevelFiftyExpression) -> LevelFiftyExpression {
        for _ in 0..<12 {
            let candidate = randomExpression()
            if abs(candidate.value - expression.value) >= 0.0001 {
                return candidate
            }
        }
        return LevelFiftyExpression(text: "\(Int(expression.value) + 1)", value: expression.value + 1)
    }

    private func matchingExpression(for expression: LevelFiftyExpression) -> LevelFiftyExpression {
        let whole = Int(expression.value.rounded())
        if abs(expression.value - Double(whole)) < 0.0001 {
            switch whole {
            case 4:
                return Bool.random() ? LevelFiftyExpression(text: "2^2", value: 4) : LevelFiftyExpression(text: "√16", value: 4)
            case 8:
                return LevelFiftyExpression(text: "2^3", value: 8)
            case 9:
                return LevelFiftyExpression(text: "3^2", value: 9)
            case 16:
                return Bool.random() ? LevelFiftyExpression(text: "4^2", value: 16) : LevelFiftyExpression(text: "√256", value: 16)
            default:
                return LevelFiftyExpression(text: "\(whole).0", value: Double(whole))
            }
        }

        return LevelFiftyExpression(text: decimalText(expression.value), value: expression.value)
    }

    private func integerExpression(range: ClosedRange<Int>) -> LevelFiftyExpression {
        let value = Int.random(in: range)
        return LevelFiftyExpression(text: "\(value)", value: Double(value))
    }

    private func decimalExpression() -> LevelFiftyExpression {
        let tenths = Int.random(in: -80...160)
        let value = Double(tenths) / 10
        return LevelFiftyExpression(text: decimalText(value), value: value)
    }

    private func fractionExpression() -> LevelFiftyExpression {
        let options: [(Int, Int)] = [
            (1, 2), (3, 2), (5, 2), (1, 4), (3, 4),
            (5, 4), (7, 4), (1, 3), (2, 3), (4, 3)
        ]
        let fraction = options.randomElement()!
        return LevelFiftyExpression(
            text: "\(fraction.0)/\(fraction.1)",
            value: Double(fraction.0) / Double(fraction.1)
        )
    }

    private func powerExpression() -> LevelFiftyExpression {
        let options = [(2, 2), (3, 2), (4, 2), (5, 2), (2, 3), (3, 3)]
        let power = options.randomElement()!
        return LevelFiftyExpression(
            text: "\(power.0)^\(power.1)",
            value: pow(Double(power.0), Double(power.1))
        )
    }

    private func radicalExpression() -> LevelFiftyExpression {
        let roots = [2, 3, 4, 5, 6, 7, 8, 9]
        let root = roots.randomElement()!
        return LevelFiftyExpression(text: "√\(root * root)", value: Double(root))
    }

    private func decimalText(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.0001 {
            return "\(Int(rounded)).0"
        }
        return String(format: "%.1f", rounded)
    }

    private func tick() {
        guard !completed else {
            cancelTimer()
            return
        }

        if timeRemaining <= 1 {
            timeRemaining = 0
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                completed = true
            }
            cancelTimer()
        } else {
            timeRemaining -= 1
        }
    }

    private func markWrong() {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.2, dampingFraction: 0.46)) {
            wrongPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.76)) {
                self.wrongPulse = false
            }
        }
    }
}

struct MathItLevelFiftyView: View {
    var viewModel: MathItLevelFiftyViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)
                comparisonBox(size: size)
                    .position(x: size.width / 2, y: size.height * 0.37)

                gearSlider(size: size)
                    .position(x: size.width / 2, y: size.height * 0.63)

                actionRow(size: size)
                    .position(x: size.width / 2, y: min(size.height - 96, size.height * 0.82))

                CompletionOverlay(
                    title: "Score \(viewModel.score)",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancelTimer() }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            Text("inequality gates")
                .font(.garamond(min(33, size.width * 0.08)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: max(180, size.width - 68))
                .opacity(0.74)
                .padding(.top, 2)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func comparisonBox(size: CGSize) -> some View {
        HStack(spacing: min(22, size.width * 0.05)) {
            numberTile(viewModel.leftExpression.text, size: size)
            symbolTile(size: size)
            numberTile(viewModel.rightExpression.text, size: size)
        }
        .scaleEffect(viewModel.wrongPulse ? 1.035 : 1)
    }

    private func numberTile(_ value: String, size: CGSize) -> some View {
        Text(value)
            .font(.garamond(expressionFontSize(value, size: size)))
            .minimumScaleFactor(0.68)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(width: min(112, size.width * 0.25), height: 96)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.white.opacity(0.16), lineWidth: 1.2)
            }
    }

    private func expressionFontSize(_ value: String, size: CGSize) -> CGFloat {
        let base = min(56, size.width * 0.13)
        return value.count > 3 ? base * 0.78 : base
    }

    private func symbolTile(size: CGSize) -> some View {
        let hasSelection = viewModel.selectedSymbol != nil

        return Text(viewModel.selectedSymbol?.rawValue ?? "")
            .font(.system(size: min(44, size.width * 0.105), weight: .semibold, design: .monospaced))
            .foregroundStyle(viewModel.wrongPulse ? .red.opacity(0.9) : accent)
            .frame(width: min(96, size.width * 0.22), height: 96)
            .background(accent.opacity(viewModel.wrongPulse ? 0.04 : hasSelection ? 0.12 : 0.035), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke((viewModel.wrongPulse ? Color.red : accent).opacity(hasSelection || viewModel.wrongPulse ? 0.72 : 0.28), lineWidth: 1.4)
            }
            .shadow(color: accent.opacity(viewModel.wrongPulse || !hasSelection ? 0 : 0.28), radius: 12)
    }

    private func gearSlider(size: CGSize) -> some View {
        let trackWidth = min(size.width - 62, 430)
        let stepWidth = trackWidth / CGFloat(LevelFiftySymbol.allCases.count - 1)

        return ZStack {
            Capsule()
                .fill(.white.opacity(0.035))
                .frame(width: trackWidth, height: 16)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }

            ForEach(Array(LevelFiftySymbol.allCases.enumerated()), id: \.offset) { index, symbol in
                Button {
                    viewModel.select(index: index)
                } label: {
                    gearOption(index: index, symbol: symbol)
                }
                .buttonStyle(.plain)
                .position(x: trackWidth / 2 + (-trackWidth / 2 + stepWidth * CGFloat(index)), y: 48)
            }
        }
        .frame(width: trackWidth, height: 86)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let rawIndex = Int(round(value.location.x / stepWidth))
                    viewModel.select(index: rawIndex)
            }
        )
    }

    private func gearOption(index: Int, symbol: LevelFiftySymbol) -> some View {
        let isSelected = index == viewModel.selectedIndex

        return Text(symbol.rawValue)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(isSelected ? accent : .white.opacity(0.72))
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.001), in: Circle())
            .overlay {
                Circle()
                    .stroke(isSelected ? accent : accent.opacity(0.46), lineWidth: isSelected ? 2.5 : 1.1)
            }
            .shadow(color: accent.opacity(isSelected ? 0.78 : 0), radius: isSelected ? 13 : 0)
    }

    private func actionRow(size: CGSize) -> some View {
        HStack(spacing: min(22, size.width * 0.055)) {
            VStack(spacing: 6) {
                Text(viewModel.timeText)
                    .font(.system(size: 27, weight: .semibold, design: .monospaced))
                    .foregroundStyle(viewModel.timeRemaining <= 10 ? .red.opacity(0.92) : .white.opacity(0.86))
                    .frame(width: 88, height: 36)

                Text("\(viewModel.score)")
                    .font(.trajan(29))
                    .foregroundStyle(accent)
                    .frame(width: 88, height: 36)
            }

            Button(action: viewModel.submit) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 68, height: 68)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.42), radius: 12)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.completed)
        }
    }
}
