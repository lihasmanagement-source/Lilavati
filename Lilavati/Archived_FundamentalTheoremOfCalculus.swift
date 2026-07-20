import SwiftUI

struct MathItLevelOneHundredFortyOneView: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.91)
    private let gold = Color(red: 1.0, green: 0.72, blue: 0.18)
    private let coral = Color(red: 0.97, green: 0.34, blue: 0.29)
    private let green = Color(red: 0.32, green: 0.86, blue: 0.55)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var currentTime = 0.0
    @State private var editableRates = FTCStage.all[2].rates
    @State private var dragStarts: [Int: Double] = [:]
    @State private var completed = false
    @State private var feedback: FTCFeedback?
    @State private var animationToken = UUID()

    private var stage: FTCStage { FTCStage.all[stageIndex] }
    private var rates: [Double] { stage.editable ? editableRates : stage.rates }
    private var currentRate: Double { rate(at: currentTime, rates: rates) }
    private var currentVolume: Double { max(0, accumulation(at: currentTime, rates: rates)) }
    private var targetReached: Bool { abs(currentVolume - stage.targetVolume) <= stage.tolerance }

    private var capacity: Double {
        let peak = (0...100).map { accumulation(at: Double($0) / 10, rates: rates) }.max() ?? 0
        return max(30, max(stage.targetVolume * 1.22, peak * 1.12))
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.012, green: 0.025, blue: 0.036).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 12) {
                    Spacer().frame(height: compact ? 76 : 90)
                    header

                    theoremLab
                        .frame(maxWidth: 920)
                        .frame(height: max(410, min(555, proxy.size.height * 0.63)))

                    controls(compact: compact)
                        .frame(maxWidth: 820)

                    Spacer(minLength: compact ? 64 : 76)
                }
                .padding(.horizontal, compact ? 12 : 18)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 141 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(100)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear { loadStage(0) }
    }

    private var header: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(FTCStage.all.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex ? green : index == stageIndex ? gold : .white.opacity(0.14))
                        .frame(width: index == stageIndex ? 42 : 23, height: 5)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: stage.symbol)
                Text(stage.name)
                Text("·")
                    .foregroundStyle(.white.opacity(0.28))
                Text("V = \(number(stage.targetVolume)) m³")
                    .foregroundStyle(cyan)
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(gold)
        }
    }

    private var theoremLab: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let rateRect = CGRect(x: 18, y: 18, width: size.width - 36, height: size.height * 0.42)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    Canvas { context, canvasSize in
                        drawLabBackground(context: &context, size: canvasSize)
                        drawRateGraph(context: &context, rect: rateRect)
                        drawReservoir(context: &context, size: canvasSize, time: time)
                        drawAccumulationGraph(context: &context, size: canvasSize)
                    }

                    if stage.editable {
                        ForEach(editableRates.indices, id: \.self) { index in
                            rateHandle(index: index, rect: rateRect)
                        }
                    }

                    if let feedback {
                        Label(feedback.message, systemImage: feedback.symbol)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(feedback.success ? .black : .white)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(feedback.success ? green : .black.opacity(0.82), in: Capsule())
                            .overlay(Capsule().stroke((feedback.success ? green : coral).opacity(0.68), lineWidth: 1))
                            .position(x: size.width / 2, y: size.height - 18)
                    }
                }
            }
            .background(Color(red: 0.02, green: 0.055, blue: 0.075))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.mathGold.opacity(0.28), lineWidth: 1))
        }
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            HStack(spacing: 12) {
                Image(systemName: stage.editable ? "waveform.path.ecg" : "clock")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(gold)

                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { value in
                            currentTime = value
                            feedback = nil
                        }
                    ),
                    in: 0...10,
                    step: 0.05
                )
                .tint(cyan)
                .disabled(stage.editable)

                Text("t = \(number(currentTime))")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 72, alignment: .trailing)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("F(t) = ∫₀ᵗ f(x)dx")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(cyan)

                    Text("F = \(number(currentVolume)) m³   ·   f = \(number(currentRate)) m³/s")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: checkTarget) {
                    Image(systemName: stage.editable ? "checkmark" : "pause.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 58, height: compact ? 42 : 48)
                        .background(targetReached ? green : gold, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(stage.editable ? "Check final volume" : "Stop time")
            }
        }
    }

    private func rateHandle(index: Int, rect: CGRect) -> some View {
        let point = ratePoint(index: index, value: editableRates[index], rect: rect)

        return Circle()
            .fill(index.isMultiple(of: 2) ? gold : cyan)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(.black.opacity(0.72), lineWidth: 2))
            .shadow(color: (index.isMultiple(of: 2) ? gold : cyan).opacity(0.65), radius: 7)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if dragStarts[index] == nil {
                            dragStarts[index] = editableRates[index]
                        }
                        let start = dragStarts[index] ?? editableRates[index]
                        let delta = -Double(gesture.translation.height / rect.height) * 8
                        editableRates[index] = max(-2, min(6, start + delta))
                        feedback = nil
                    }
                    .onEnded { _ in dragStarts[index] = nil }
            )
            .accessibilityLabel("Flow control \(index + 1)")
    }

    private func checkTarget() {
        animationToken = UUID()
        let token = animationToken
        HapticPlayer.playLightTap()

        guard targetReached else {
            feedback = currentVolume < stage.targetVolume ? .low : .high
            return
        }

        feedback = .success
        HapticPlayer.playCompletionTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard token == animationToken else { return }
            if stageIndex == FTCStage.all.count - 1 {
                withAnimation(.easeInOut(duration: 0.4)) { completed = true }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) { loadStage(stageIndex + 1) }
            }
        }
    }

    private func loadStage(_ index: Int) {
        animationToken = UUID()
        stageIndex = min(index, FTCStage.all.count - 1)
        currentTime = FTCStage.all[stageIndex].editable ? 10 : 0
        if FTCStage.all[stageIndex].editable {
            editableRates = FTCStage.all[stageIndex].rates
        }
        dragStarts = [:]
        feedback = nil
    }

    private func resetLevel() {
        completed = false
        editableRates = FTCStage.all[2].rates
        loadStage(0)
    }

    private func rate(at time: Double, rates: [Double]) -> Double {
        let clamped = max(0, min(10, time))
        if clamped >= 10 { return rates.last ?? 0 }
        let spacing = 10.0 / Double(rates.count - 1)
        let index = min(rates.count - 2, Int(clamped / spacing))
        let local = (clamped - Double(index) * spacing) / spacing
        return rates[index] + (rates[index + 1] - rates[index]) * local
    }

    private func accumulation(at time: Double, rates: [Double]) -> Double {
        let clamped = max(0, min(10, time))
        let spacing = 10.0 / Double(rates.count - 1)
        let fullSegments = min(rates.count - 1, Int(clamped / spacing))
        var total = 0.0

        if fullSegments > 0 {
            for index in 0..<fullSegments {
                total += (rates[index] + rates[index + 1]) * 0.5 * spacing
            }
        }

        if fullSegments < rates.count - 1 {
            let used = clamped - Double(fullSegments) * spacing
            let slope = (rates[fullSegments + 1] - rates[fullSegments]) / spacing
            total += rates[fullSegments] * used + 0.5 * slope * used * used
        }
        return total
    }

    private func drawLabBackground(context: inout GraphicsContext, size: CGSize) {
        let horizon = size.height * 0.51
        var sky = Path()
        sky.addRect(CGRect(x: 0, y: 0, width: size.width, height: horizon))
        context.fill(sky, with: .linearGradient(
            Gradient(colors: [Color(red: 0.04, green: 0.11, blue: 0.16), Color(red: 0.09, green: 0.20, blue: 0.23)]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: horizon)
        ))

        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: horizon + 28))
        hills.addCurve(to: CGPoint(x: size.width, y: horizon + 16), control1: CGPoint(x: size.width * 0.28, y: horizon - 24), control2: CGPoint(x: size.width * 0.70, y: horizon + 46))
        hills.addLine(to: CGPoint(x: size.width, y: size.height))
        hills.addLine(to: CGPoint(x: 0, y: size.height))
        hills.closeSubpath()
        context.fill(hills, with: .color(Color(red: 0.035, green: 0.13, blue: 0.12)))
    }

    private func drawRateGraph(context: inout GraphicsContext, rect: CGRect) {
        context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(.black.opacity(0.62)))
        context.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(.white.opacity(0.15)), lineWidth: 1)

        func x(_ time: Double) -> CGFloat { rect.minX + CGFloat(time / 10) * rect.width }
        func y(_ value: Double) -> CGFloat { rect.maxY - CGFloat((value + 2) / 8) * rect.height }
        let axisY = y(0)

        for value in stride(from: -2.0, through: 6.0, by: 2.0) {
            var grid = Path()
            grid.move(to: CGPoint(x: rect.minX, y: y(value)))
            grid.addLine(to: CGPoint(x: rect.maxX, y: y(value)))
            context.stroke(grid, with: .color(.white.opacity(value == 0 ? 0.30 : 0.08)), lineWidth: value == 0 ? 1.2 : 1)
        }

        let slices = max(1, Int(currentTime / 10 * 90))
        for index in 0..<slices {
            let t0 = Double(index) / 90 * 10
            let t1 = min(currentTime, Double(index + 1) / 90 * 10)
            guard t1 > t0 else { continue }
            let value = rate(at: (t0 + t1) / 2, rates: rates)
            let top = y(value)
            let strip = CGRect(x: x(t0), y: min(axisY, top), width: max(1, x(t1) - x(t0) + 0.5), height: abs(axisY - top))
            context.fill(Path(strip), with: .color((value >= 0 ? cyan : coral).opacity(0.24)))
        }

        var curve = Path()
        for sample in 0...120 {
            let time = Double(sample) / 12
            let point = CGPoint(x: x(time), y: y(rate(at: time, rates: rates)))
            sample == 0 ? curve.move(to: point) : curve.addLine(to: point)
        }
        context.stroke(curve, with: .color(cyan), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

        var timeLine = Path()
        timeLine.move(to: CGPoint(x: x(currentTime), y: rect.minY))
        timeLine.addLine(to: CGPoint(x: x(currentTime), y: rect.maxY))
        context.stroke(timeLine, with: .color(gold.opacity(0.88)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        context.fill(Path(ellipseIn: CGRect(x: x(currentTime) - 5, y: y(currentRate) - 5, width: 10, height: 10)), with: .color(gold))

        context.draw(Text("f(t) · FLOW RATE").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.62)), at: CGPoint(x: rect.minX + 58, y: rect.minY + 11))
        context.draw(Text("t").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(gold), at: CGPoint(x: rect.maxX - 9, y: axisY - 9))
    }

    private func drawReservoir(context: inout GraphicsContext, size: CGSize, time: Double) {
        let panel = CGRect(x: 18, y: size.height * 0.48, width: size.width * 0.57, height: size.height * 0.45)
        let tank = panel.insetBy(dx: 18, dy: 24)
        let fraction = CGFloat(max(0, min(1, currentVolume / capacity)))
        let waterY = tank.maxY - fraction * tank.height

        context.fill(Path(roundedRect: panel, cornerRadius: 6), with: .color(.black.opacity(0.44)))
        context.stroke(Path(roundedRect: panel, cornerRadius: 6), with: .color(.white.opacity(0.12)), lineWidth: 1)

        var basin = Path()
        basin.move(to: CGPoint(x: tank.minX, y: tank.minY))
        basin.addLine(to: CGPoint(x: tank.minX + 8, y: tank.maxY))
        basin.addLine(to: CGPoint(x: tank.maxX - 8, y: tank.maxY))
        basin.addLine(to: CGPoint(x: tank.maxX, y: tank.minY))
        context.stroke(basin, with: .color(.white.opacity(0.48)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

        if fraction > 0.003 {
            var water = Path()
            water.move(to: CGPoint(x: tank.minX + 5, y: tank.maxY - 3))
            water.addLine(to: CGPoint(x: tank.minX + 5, y: waterY))
            water.addCurve(
                to: CGPoint(x: tank.maxX - 5, y: waterY),
                control1: CGPoint(x: tank.minX + tank.width * 0.32, y: waterY + CGFloat(sin(time * 2.2)) * 3),
                control2: CGPoint(x: tank.minX + tank.width * 0.68, y: waterY - CGFloat(sin(time * 2.2)) * 3)
            )
            water.addLine(to: CGPoint(x: tank.maxX - 5, y: tank.maxY - 3))
            water.closeSubpath()
            context.fill(water, with: .linearGradient(
                Gradient(colors: [cyan.opacity(0.72), Color(red: 0.05, green: 0.42, blue: 0.62).opacity(0.90)]),
                startPoint: CGPoint(x: 0, y: waterY),
                endPoint: CGPoint(x: 0, y: tank.maxY)
            ))
        }

        let targetY = tank.maxY - CGFloat(min(1, stage.targetVolume / capacity)) * tank.height
        var targetLine = Path()
        targetLine.move(to: CGPoint(x: tank.minX + 8, y: targetY))
        targetLine.addLine(to: CGPoint(x: tank.maxX - 8, y: targetY))
        context.stroke(targetLine, with: .color(gold.opacity(0.82)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

        if currentRate > 0.05 {
            let inlet = CGPoint(x: tank.minX + 26, y: tank.minY - 8)
            var flow = Path()
            flow.move(to: CGPoint(x: inlet.x - 32, y: inlet.y - 18))
            flow.addCurve(to: CGPoint(x: inlet.x, y: max(inlet.y, waterY)), control1: CGPoint(x: inlet.x - 16, y: inlet.y - 14), control2: CGPoint(x: inlet.x + 5, y: inlet.y + 8))
            context.stroke(
                flow,
                with: .color(cyan.opacity(0.88)),
                style: StrokeStyle(lineWidth: 2.5 + CGFloat(currentRate) * 0.72, lineCap: .round, dash: [9, 4], dashPhase: -CGFloat(time * 28))
            )
        } else if currentRate < -0.05 {
            var outflow = Path()
            outflow.move(to: CGPoint(x: tank.maxX - 8, y: tank.maxY - 18))
            outflow.addLine(to: CGPoint(x: panel.maxX + 8, y: tank.maxY - 3))
            context.stroke(outflow, with: .color(coral.opacity(0.86)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [7, 4], dashPhase: -CGFloat(time * 24)))
        }

        context.draw(Text("F(t)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(cyan), at: CGPoint(x: panel.minX + 35, y: panel.minY + 12))
        context.draw(Text("\(number(currentVolume)) m³").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.white), at: CGPoint(x: panel.maxX - 48, y: panel.minY + 12))
    }

    private func drawAccumulationGraph(context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(x: size.width * 0.62, y: size.height * 0.48, width: size.width * 0.34, height: size.height * 0.45)
        context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(.black.opacity(0.52)))
        context.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(.white.opacity(0.13)), lineWidth: 1)

        func x(_ time: Double) -> CGFloat { rect.minX + 10 + CGFloat(time / 10) * (rect.width - 20) }
        func y(_ value: Double) -> CGFloat { rect.maxY - 14 - CGFloat(max(0, value) / capacity) * (rect.height - 30) }

        var graph = Path()
        for sample in 0...100 {
            let time = Double(sample) / 10
            let point = CGPoint(x: x(time), y: y(accumulation(at: time, rates: rates)))
            sample == 0 ? graph.move(to: point) : graph.addLine(to: point)
        }
        context.stroke(graph, with: .color(gold), style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))

        let point = CGPoint(x: x(currentTime), y: y(currentVolume))
        context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(cyan))

        let tangentSpan = 0.55
        let leftTime = max(0, currentTime - tangentSpan)
        let rightTime = min(10, currentTime + tangentSpan)
        let leftValue = currentVolume + currentRate * (leftTime - currentTime)
        let rightValue = currentVolume + currentRate * (rightTime - currentTime)
        var tangent = Path()
        tangent.move(to: CGPoint(x: x(leftTime), y: y(leftValue)))
        tangent.addLine(to: CGPoint(x: x(rightTime), y: y(rightValue)))
        context.stroke(tangent, with: .color(cyan.opacity(0.80)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        context.draw(Text("F(t)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(gold), at: CGPoint(x: rect.minX + 24, y: rect.minY + 12))
        context.draw(Text("F′ = f").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(cyan), at: CGPoint(x: rect.maxX - 30, y: rect.minY + 12))
    }

    private func ratePoint(index: Int, value: Double, rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + CGFloat(index) / CGFloat(max(1, editableRates.count - 1)) * rect.width,
            y: rect.maxY - CGFloat((value + 2) / 8) * rect.height
        )
    }

    private func number(_ value: Double) -> String {
        abs(value.rounded() - value) < 0.01
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value)
    }
}

private struct FTCStage {
    let name: String
    let symbol: String
    let rates: [Double]
    let targetVolume: Double
    let tolerance: Double
    let editable: Bool

    static let all = [
        FTCStage(name: "ACCUMULATE", symbol: "water.waves", rates: [1.6, 3.2, 4.4, 3.5, 2.7, 2.1], targetVolume: 22.0, tolerance: 0.22, editable: false),
        FTCStage(name: "INFLOW + OUTFLOW", symbol: "arrow.left.arrow.right", rates: [3.4, 4.8, 2.0, -0.8, -1.3, 1.8], targetVolume: 14.1, tolerance: 0.24, editable: false),
        FTCStage(name: "SHAPE THE RATE", symbol: "point.3.connected.trianglepath.dotted", rates: [1.4, 1.8, 1.2, 1.7, 1.0, 1.4], targetVolume: 25.0, tolerance: 0.55, editable: true)
    ]
}

private enum FTCFeedback {
    case low
    case high
    case success

    var message: String {
        switch self {
        case .low: "∫ < TARGET"
        case .high: "∫ > TARGET"
        case .success: "AREA = WATER VOLUME"
        }
    }

    var symbol: String {
        switch self {
        case .low: "arrow.up"
        case .high: "arrow.down"
        case .success: "checkmark"
        }
    }

    var success: Bool { self == .success }
}

#Preview {
    MathItLevelOneHundredFortyOneView(onContinue: {}, onLevelSelect: {})
}
