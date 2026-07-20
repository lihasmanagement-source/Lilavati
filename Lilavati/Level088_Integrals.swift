import SwiftUI

struct MathItLevelOneHundredThirtyFourView: View {
    private let stages = IntegralPaintStage.all
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var paintedFractions = Array(repeating: 0.0, count: IntegralPaintStage.all[0].sliceCount)
    @State private var brushPoint: CGPoint?
    @State private var solved = false
    @State private var completed = false
    @State private var animationToken = UUID()

    private var stage: IntegralPaintStage { stages[stageIndex] }

    private var coverage: Double {
        let dx = (stage.b - stage.a) / Double(stage.sliceCount)
        var painted = 0.0
        var target = 0.0
        for index in 0..<stage.sliceCount {
            let x = stage.a + (Double(index) + 0.5) * dx
            let weight = abs(stage.value(at: x)) * dx
            target += weight
            painted += weight * paintedFractions[index]
        }
        return target > 0 ? min(1, painted / target) : 0
    }

    private var paintedArea: Double {
        let dx = (stage.b - stage.a) / Double(stage.sliceCount)
        return (0..<stage.sliceCount).reduce(0) { total, index in
            let x0 = stage.a + Double(index) * dx
            let x1 = x0 + dx
            return total + stage.integral(from: x0, to: x1) * paintedFractions[index]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.012, green: 0.021, blue: 0.029).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    paintCanvas
                        .frame(maxWidth: 900)
                        .frame(height: max(430, min(575, proxy.size.height * 0.67)))

                    statusPanel(compact: compact)
                        .frame(maxWidth: 820)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Integral Painted",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
    }

    private var header: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(stages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex ? cyan : index == stageIndex ? gold : .white.opacity(0.13))
                        .frame(width: index == stageIndex ? 42 : 24, height: 5)
                }
            }

            HStack(spacing: 9) {
                Image(systemName: "paintbrush.fill")
                Image(systemName: "chart.bar.fill")
                Text("\(stageIndex + 1)/\(stages.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(gold)

        }
    }

    private var paintCanvas: some View {
        GeometryReader { geo in
            let plot = CGRect(x: 48, y: 54, width: geo.size.width - 96, height: geo.size.height - 102)

            ZStack {
                Canvas { context, size in
                    drawCanvasBackground(context: &context, size: size, plot: plot)
                    drawPaintedSlices(context: &context, plot: plot)
                    drawCurveAndBounds(context: &context, plot: plot)
                }

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .frame(width: plot.width, height: plot.height)
                    .position(x: plot.midX, y: plot.midY)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("integralCanvas"))
                            .onChanged { value in
                                guard !solved else { return }
                                let point = value.location
                                brushPoint = point
                                applyPaint(at: point, plot: plot)
                            }
                            .onEnded { _ in
                                brushPoint = nil
                                DispatchQueue.main.async { evaluateCanvas() }
                            }
                    )

                if let brushPoint, !solved {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(gold)
                        .shadow(color: .black.opacity(0.7), radius: 3, y: 2)
                        .rotationEffect(.degrees(-38))
                        .position(brushPoint)
                        .allowsHitTesting(false)
                }

                VStack {
                    HStack(spacing: 8) {
                        metric(symbol: "sum", value: number(paintedArea), tint: paintedArea < -0.005 ? coral : cyan)
                        Spacer()
                        Button(action: resetStage) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .black))
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.48), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(gold)
                        .disabled(solved)
                    }
                    Spacer()
                }
                .padding(10)

                if solved {
                    Text("∫₍\(number(stage.a))₎⁽\(number(stage.b))⁾ \(stage.equation) dx = \(number(stage.trueIntegral))")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(cyan.opacity(0.20))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(cyan.opacity(0.8), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .position(x: plot.midX, y: plot.minY + 27)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .background(Color(red: 0.025, green: 0.039, blue: 0.047))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(gold.opacity(0.30), lineWidth: 1))
            .coordinateSpace(name: "integralCanvas")
        }
    }

    private func statusPanel(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 9) {
            HStack(spacing: 10) {
                Image(systemName: "paintbrush.fill")
                    .foregroundStyle(gold)
                Text("Δx ≈ \(number((stage.b - stage.a) / Double(stage.sliceCount)))")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
                Text(stage.equation)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(gold)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.09))
                    Capsule()
                        .fill(cyan)
                        .frame(width: geo.size.width * coverage)
                }
            }
            .frame(height: 7)

            HStack(spacing: 8) {
                Image(systemName: coverage >= 0.94 ? "checkmark.circle.fill" : "square.grid.3x3.fill")
                Text("\(Int((coverage * 100).rounded()))%")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .foregroundStyle(coverage >= 0.94 ? cyan : .white.opacity(0.48))
        }
    }

    private func applyPaint(at point: CGPoint, plot: CGRect) {
        let x = worldX(for: point.x, plot: plot)
        guard x >= stage.a, x <= stage.b else { return }

        let normalizedX = (x - stage.a) / (stage.b - stage.a)
        let index = min(stage.sliceCount - 1, max(0, Int(normalizedX * Double(stage.sliceCount))))
        let dx = (stage.b - stage.a) / Double(stage.sliceCount)
        let centerX = stage.a + (Double(index) + 0.5) * dx
        let curveValue = stage.value(at: centerX)

        if abs(curveValue) < 0.035 {
            paintedFractions[index] = 1
            return
        }

        let axisY = screenY(0, plot: plot)
        let curveY = screenY(curveValue, plot: plot)
        let fraction = Double((point.y - axisY) / (curveY - axisY))

        guard fraction >= -0.04, fraction <= 1.08 else { return }
        paintedFractions[index] = max(paintedFractions[index], min(1, max(0, fraction)))
        DispatchQueue.main.async { evaluateCanvas() }
    }

    private func evaluateCanvas() {
        guard !solved, coverage >= 0.94 else { return }
        solved = true
        paintedFractions = Array(repeating: 1, count: stage.sliceCount)
        let token = animationToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard token == animationToken else { return }
            if stageIndex == stages.count - 1 {
                withAnimation { completed = true }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    stageIndex += 1
                    paintedFractions = Array(repeating: 0, count: stages[stageIndex].sliceCount)
                    brushPoint = nil
                    solved = false
                }
            }
        }
    }

    private func resetStage() {
        animationToken = UUID()
        paintedFractions = Array(repeating: 0, count: stage.sliceCount)
        brushPoint = nil
        solved = false
    }

    private func resetLevel() {
        animationToken = UUID()
        stageIndex = 0
        paintedFractions = Array(repeating: 0, count: stages[0].sliceCount)
        brushPoint = nil
        solved = false
        completed = false
    }

    private func drawCanvasBackground(context: inout GraphicsContext, size: CGSize, plot: CGRect) {
        context.fill(Path(roundedRect: plot, cornerRadius: 5), with: .color(Color(red: 0.012, green: 0.022, blue: 0.028)))

        for tick in -2...5 {
            let y = screenY(Double(tick), plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(line, with: .color(.white.opacity(tick == 0 ? 0.30 : 0.055)), lineWidth: tick == 0 ? 1.6 : 1)
            context.draw(
                Text("\(tick)").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.28)),
                at: CGPoint(x: plot.minX - 13, y: y)
            )
        }

        for tick in -2...2 {
            let x = screenX(Double(tick), plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: x, y: plot.minY))
            line.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(line, with: .color(.white.opacity(tick == 0 ? 0.24 : 0.05)), lineWidth: tick == 0 ? 1.4 : 1)
            context.draw(
                Text("\(tick)").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.28)),
                at: CGPoint(x: x, y: screenY(0, plot: plot) + 12)
            )
        }

        let dx = (stage.b - stage.a) / Double(stage.sliceCount)
        for index in 0...stage.sliceCount {
            let x = screenX(stage.a + Double(index) * dx, plot: plot)
            var guide = Path()
            guide.move(to: CGPoint(x: x, y: screenY(0, plot: plot)))
            let sampleX = min(stage.b, stage.a + (Double(index) + 0.5) * dx)
            guide.addLine(to: CGPoint(x: x, y: screenY(stage.value(at: sampleX), plot: plot)))
            context.stroke(guide, with: .color(.white.opacity(0.025)), lineWidth: 0.6)
        }
    }

    private func drawPaintedSlices(context: inout GraphicsContext, plot: CGRect) {
        let dx = (stage.b - stage.a) / Double(stage.sliceCount)
        let screenWidth = plot.width * CGFloat(dx / 5) * (solved ? 1.02 : 0.90)
        let axisY = screenY(0, plot: plot)

        for index in 0..<stage.sliceCount where paintedFractions[index] > 0 {
            let x = stage.a + (Double(index) + 0.5) * dx
            let value = stage.value(at: x)
            let curveY = screenY(value, plot: plot)
            let paintedY = axisY + (curveY - axisY) * CGFloat(paintedFractions[index])
            let rect = CGRect(
                x: screenX(x, plot: plot) - screenWidth / 2,
                y: min(axisY, paintedY),
                width: screenWidth,
                height: max(1, abs(axisY - paintedY))
            )
            let color = value >= 0 ? cyan : coral
            if solved {
                context.fill(Path(rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(color.opacity(0.16)))
            }
            context.fill(Path(rect), with: .color(color.opacity(solved ? 0.68 : 0.48)))
            context.stroke(Path(rect), with: .color(color.opacity(0.72)), lineWidth: 0.6)
        }
    }

    private func drawCurveAndBounds(context: inout GraphicsContext, plot: CGRect) {
        var curve = Path()
        for sample in 0...240 {
            let x = -2.5 + 5 * Double(sample) / 240
            let point = CGPoint(x: screenX(x, plot: plot), y: screenY(stage.value(at: x), plot: plot))
            sample == 0 ? curve.move(to: point) : curve.addLine(to: point)
        }
        context.stroke(curve, with: .color(gold), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

        for (xValue, label) in [(stage.a, "a"), (stage.b, "b")] {
            let x = screenX(xValue, plot: plot)
            var boundary = Path()
            boundary.move(to: CGPoint(x: x, y: plot.minY))
            boundary.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(boundary, with: .color(.white.opacity(0.72)), style: StrokeStyle(lineWidth: 1.3, dash: [5, 5]))
            context.draw(
                Text("\(label)=\(number(xValue))").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.72)),
                at: CGPoint(x: x, y: plot.maxY + 13)
            )
        }
    }

    private func metric(symbol: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func screenX(_ x: Double, plot: CGRect) -> CGFloat {
        plot.minX + CGFloat((x + 2.5) / 5) * plot.width
    }

    private func worldX(for screenX: CGFloat, plot: CGRect) -> Double {
        Double((screenX - plot.minX) / plot.width) * 5 - 2.5
    }

    private func screenY(_ y: Double, plot: CGRect) -> CGFloat {
        plot.maxY - CGFloat((y + 2.5) / 8) * plot.height
    }

    private func number(_ value: Double) -> String {
        let clean = abs(value) < 0.005 ? 0 : value
        if abs(clean.rounded() - clean) < 0.005 { return String(Int(clean.rounded())) }
        return String(format: "%.2f", clean)
    }
}

private struct IntegralPaintStage {
    enum Curve {
        case constant
        case downwardParabola
        case signedParabola
    }

    let equation: String
    let curve: Curve
    let a: Double
    let b: Double
    let sliceCount: Int

    func value(at x: Double) -> Double {
        switch curve {
        case .constant: 2
        case .downwardParabola: 4 - x * x
        case .signedParabola: x * x - 1
        }
    }

    func antiderivative(at x: Double) -> Double {
        switch curve {
        case .constant: 2 * x
        case .downwardParabola: 4 * x - x * x * x / 3
        case .signedParabola: x * x * x / 3 - x
        }
    }

    func integral(from lower: Double, to upper: Double) -> Double {
        antiderivative(at: upper) - antiderivative(at: lower)
    }

    var trueIntegral: Double { integral(from: a, to: b) }

    static let all = [
        IntegralPaintStage(equation: "f(x) = 2", curve: .constant, a: -2, b: 2, sliceCount: 14),
        IntegralPaintStage(equation: "f(x) = 4 − x²", curve: .downwardParabola, a: -2, b: 2, sliceCount: 24),
        IntegralPaintStage(equation: "f(x) = x² − 1", curve: .signedParabola, a: -2, b: 2, sliceCount: 42)
    ]
}

#Preview {
    MathItLevelOneHundredThirtyFourView(onContinue: {}, onLevelSelect: {})
}
