import SwiftUI

// MARK: - Level 105 - Glacier Time Machine

struct MathItLevelOneHundredFiveView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private enum OperationKind {
        case snow
        case sun
    }

    private struct GlacierOperation: Identifiable {
        let id = UUID()
        let kind: OperationKind
        let symbol: String
        let value: Double

        var icon: String {
            kind == .snow ? "snowflake" : "sun.max.fill"
        }

        var label: String {
            kind == .snow ? "+\(Int(value))" : "÷\(Int(value))"
        }

        func apply(to height: Double) -> Double {
            kind == .snow ? height + value : height / value
        }
    }

    private struct GlacierStage {
        let equation: String
        let target: Double
        let solution: Int
        let initialGuess: Int
        let operations: [GlacierOperation]
    }

    private let stages: [GlacierStage] = [
        GlacierStage(
            equation: "(x + 3) ÷ 2 + 4 = 12",
            target: 12,
            solution: 13,
            initialGuess: 10,
            operations: [
                GlacierOperation(kind: .snow, symbol: "+", value: 3),
                GlacierOperation(kind: .sun, symbol: "÷", value: 2),
                GlacierOperation(kind: .snow, symbol: "+", value: 4)
            ]
        ),
        GlacierStage(
            equation: "(x + 5) ÷ 3 + 6 = 13",
            target: 13,
            solution: 16,
            initialGuess: 11,
            operations: [
                GlacierOperation(kind: .snow, symbol: "+", value: 5),
                GlacierOperation(kind: .sun, symbol: "÷", value: 3),
                GlacierOperation(kind: .snow, symbol: "+", value: 6)
            ]
        ),
        GlacierStage(
            equation: "((x + 6) ÷ 2 + 5) ÷ 2 = 8",
            target: 8,
            solution: 16,
            initialGuess: 12,
            operations: [
                GlacierOperation(kind: .snow, symbol: "+", value: 6),
                GlacierOperation(kind: .sun, symbol: "÷", value: 2),
                GlacierOperation(kind: .snow, symbol: "+", value: 5),
                GlacierOperation(kind: .sun, symbol: "÷", value: 2)
            ]
        )
    ]

    @State private var stageIndex = 0
    @State private var xHeight = 10
    @State private var currentHeight: Double = 10
    @State private var activeOperationIndex: Int?
    @State private var checked = false
    @State private var isPlaying = false
    @State private var wrongPulse = false
    @State private var completed = false

    private let accent = Color(red: 0.42, green: 0.82, blue: 1.0)
    private let ice = Color(red: 0.64, green: 0.90, blue: 1.0)
    private let gold = Color(red: 0.93, green: 0.78, blue: 0.40)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.black.ignoresSafeArea()
                if wrongPulse {
                    Color.red.opacity(0.13).ignoresSafeArea()
                }

                progressBar
                    .frame(width: min(size.width - 92, 280), height: 5)
                    .position(x: size.width / 2, y: 94)

                glacierScene(size: size)
                    .position(x: size.width / 2, y: size.height * 0.40)

                equationStrip
                    .frame(width: min(size.width - 34, 370))
                    .position(x: size.width / 2, y: size.height * 0.70)

                controlPanel
                    .frame(width: min(size.width - 34, 370))
                    .position(x: size.width / 2, y: size.height * 0.86)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "✓ \(targetLabel)",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
        }
        .environment(\.mathItAccent, accent)
    }

    private func glacierScene(size: CGSize) -> some View {
        let stageW = min(size.width - 28, 390)
        let stageH = min(size.height * 0.47, 370)
        let maxHeight = stageH * 0.58
        let width = min(stageW * 0.56, 220)
        let scaleMax = max(24.0, stage.target + 10)
        let glacierHeight = max(24, maxHeight * CGFloat(currentHeight / scaleMax))
        let targetHeightPx = max(24, maxHeight * CGFloat(stage.target / scaleMax))
        let glacierX = stageW * 0.58
        let glacierBottomY = stageH - 30
        let labelY = glacierBottomY - maxHeight - 24

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.055))
                .frame(width: stageW, height: stageH)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
                .overlay(
                    LinearGradient(
                        colors: [accent.opacity(0.12), .clear, Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                )

            GlacierBody()
                .stroke(gold.opacity(0.82), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round, dash: [7, 7]))
                .frame(width: width, height: targetHeightPx)
                .position(x: glacierX, y: glacierBottomY - targetHeightPx / 2)

            if showsSun {
                sunEffect(stageWidth: stageW, stageHeight: stageH)
            }

            if showsSnowfall {
                snowfall(stageWidth: stageW, stageHeight: stageH, glacierBottomY: glacierBottomY)
            }

            GlacierBody()
                .fill(
                    LinearGradient(
                        colors: [ice.opacity(0.96), accent.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(GlacierBody().stroke(.white.opacity(0.58), lineWidth: 1.5))
                .frame(width: width, height: glacierHeight)
                .position(x: glacierX, y: glacierBottomY - glacierHeight / 2)
                .shadow(color: finalMatchesTarget ? gold.opacity(0.48) : accent.opacity(0.24), radius: finalMatchesTarget ? 26 : 14)

            VStack(spacing: 2) {
                Text(heightLabel)
                    .font(.system(size: 29, weight: .heavy, design: .rounded))
                    .foregroundStyle(labelColor)
                Text(stepLabel)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.46))
            }
            .frame(width: stageW)
            .position(x: stageW / 2, y: labelY)
        }
        .frame(width: stageW, height: stageH)
        .animation(.spring(response: 0.58, dampingFraction: 0.8), value: currentHeight)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: activeOperationIndex)
    }

    private func snowfall(stageWidth: CGFloat, stageHeight: CGFloat, glacierBottomY: CGFloat) -> some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<54, id: \.self) { index in
                    let seed = Double(index)
                    let x = 18 + CGFloat((seed * 37).truncatingRemainder(dividingBy: 100) / 100) * (stageWidth - 36)
                    let loop = (t * (0.14 + seed.truncatingRemainder(dividingBy: 6) * 0.014) + seed * 0.09)
                        .truncatingRemainder(dividingBy: 1)
                    let y = 20 + CGFloat(loop) * (glacierBottomY - 10)
                    let drift = CGFloat(sin(t * 1.1 + seed)) * 12
                    Circle()
                        .fill(.white.opacity(0.84))
                        .frame(width: 5.5 + CGFloat(index % 4), height: 5.5 + CGFloat(index % 4))
                        .position(x: x + drift, y: y)
                }
            }
            .frame(width: stageWidth, height: stageHeight)
            .allowsHitTesting(false)
        }
        .transition(.opacity)
    }

    private func sunEffect(stageWidth: CGFloat, stageHeight: CGFloat) -> some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 3.2)
            let sweep = CGFloat((t * 0.18).truncatingRemainder(dividingBy: 1.0))
            let sunX = -70 + sweep * (stageWidth + 140)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [gold.opacity(0.95), gold.opacity(0.30), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 92
                        )
                    )
                    .frame(width: 184, height: 184)
                    .scaleEffect(0.94 + pulse * 0.08)

                ForEach(0..<14, id: \.self) { index in
                    Capsule()
                        .fill(gold.opacity(0.56))
                        .frame(width: 5, height: 38)
                        .offset(y: -104)
                        .rotationEffect(.degrees(Double(index) * 36 + t * 18))
                }

                Circle()
                    .fill(gold)
                    .frame(width: 68, height: 68)
                    .shadow(color: gold.opacity(0.82), radius: 24)
            }
            .position(x: sunX, y: stageHeight * 0.24)
            .allowsHitTesting(false)
        }
        .transition(.opacity.combined(with: .scale))
    }

    private var equationStrip: some View {
        VStack(spacing: 11) {
            Text(stage.equation)
                .font(.system(size: equationFontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.68)
                .lineLimit(1)

            HStack(spacing: 8) {
                ForEach(stage.operations) { operation in
                    symbolPill(systemName: operation.icon, text: operation.label)
                }
            }
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))
        .scaleEffect(wrongPulse ? 1.025 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.42), value: wrongPulse)
    }

    private func symbolPill(systemName: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .heavy))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
            .foregroundStyle(.white.opacity(0.68))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.08)))
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                stepButton(systemName: "minus", isEnabled: canEdit && xHeight > 1) {
                    xHeight -= 1
                    currentHeight = Double(xHeight)
                    checked = false
                    HapticPlayer.playLightTap()
                }

                VStack(spacing: 1) {
                    Text("x")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                    Text("\(xHeight)m")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(accent)
                }
                .frame(width: 110, height: 66)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.26), lineWidth: 1))

                stepButton(systemName: "plus", isEnabled: canEdit && xHeight < 22) {
                    xHeight += 1
                    currentHeight = Double(xHeight)
                    checked = false
                    HapticPlayer.playLightTap()
                }
            }

            Button(action: playSimulation) {
                Image(systemName: canEdit ? "play.fill" : "hourglass")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(canEdit ? .black : .white.opacity(0.36))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(canEdit ? gold : Color.white.opacity(0.09)))
            }
            .disabled(!canEdit)
            .buttonStyle(.plain)
        }
    }

    private func stepButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(isEnabled ? .black : .white.opacity(0.3))
                .frame(width: 56, height: 56)
                .background(Circle().fill(isEnabled ? accent : Color.white.opacity(0.09)))
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }

    private var canEdit: Bool {
        !isPlaying && !completed
    }

    private var showsSnowfall: Bool {
        guard let activeOperationIndex else { return false }
        return stage.operations[activeOperationIndex].kind == .snow
    }

    private var showsSun: Bool {
        guard let activeOperationIndex else { return false }
        return stage.operations[activeOperationIndex].kind == .sun
    }

    private var finalMatchesTarget: Bool {
        checked && abs(currentHeight - stage.target) < 0.01
    }

    private var labelColor: Color {
        finalMatchesTarget ? gold : (checked ? .red.opacity(0.88) : accent)
    }

    private var heightLabel: String {
        if abs(currentHeight.rounded() - currentHeight) < 0.01 {
            return "\(Int(currentHeight.rounded()))m"
        }
        return String(format: "%.1fm", currentHeight)
    }

    private var stepLabel: String {
        if checked {
            return finalMatchesTarget ? "= \(targetLabel)" : "≠ \(targetLabel)"
        }
        if let activeOperationIndex {
            return stage.operations.prefix(activeOperationIndex + 1).reduce("x") { expression, operation in
                "\(expression) \(operation.symbol) \(Int(operation.value))"
            }
        }
        return "x"
    }

    private var stage: GlacierStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [gold, accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width * progress)
            }
        }
        .allowsHitTesting(false)
    }

    private var progress: Double {
        if completed { return 1 }
        let operationProgress = Double((activeOperationIndex ?? -1) + 1) / Double(max(1, stage.operations.count + 1))
        let checkedProgress = finalMatchesTarget ? 1.0 : min(0.9, operationProgress)
        return (Double(stageIndex) + checkedProgress) / Double(stages.count)
    }

    private var equationFontSize: CGFloat {
        stage.equation.count > 23 ? 20 : 26
    }

    private var targetLabel: String {
        heightText(stage.target)
    }

    private func playSimulation() {
        guard canEdit else { return }
        isPlaying = true
        wrongPulse = false
        currentHeight = Double(xHeight)
        activeOperationIndex = nil
        checked = false
        HapticPlayer.playLightTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            runOperation(0)
        }
    }

    private func runOperation(_ index: Int) {
        guard index < stage.operations.count else {
            finishSimulation()
            return
        }

        let operation = stage.operations[index]
        withAnimation(.easeInOut(duration: 0.35)) {
            activeOperationIndex = index
        }
        HapticPlayer.playLightTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) {
                currentHeight = operation.apply(to: currentHeight)
            }
            HapticPlayer.playLightTap()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                runOperation(index + 1)
            }
        }
    }

    private func finishSimulation() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            checked = true
            activeOperationIndex = nil
            isPlaying = false
        }

        if abs(currentHeight - stage.target) < 0.01 {
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                if stageIndex == stages.count - 1 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                        completed = true
                    }
                } else {
                    loadStage(stageIndex + 1)
                }
            }
        } else {
            HapticPlayer.playLightTap()
            wrongPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                wrongPulse = false
            }
        }
    }

    private func reset() {
        loadStage(0, animated: false)
        completed = false
    }

    private func loadStage(_ index: Int, animated: Bool = true) {
        let nextIndex = min(max(index, 0), stages.count - 1)
        let next = stages[nextIndex]
        let changes = {
            stageIndex = nextIndex
            xHeight = next.initialGuess
            currentHeight = Double(next.initialGuess)
            activeOperationIndex = nil
            checked = false
            wrongPulse = false
        }

        if animated {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                changes()
            }
        } else {
            changes()
        }
        isPlaying = false
    }

    private func heightText(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return "\(Int(value.rounded()))m"
        }
        return String(format: "%.1fm", value)
    }
}

private struct GlacierBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.03))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MathItLevelOneHundredFiveView(onContinue: {}, onLevelSelect: {})
}
