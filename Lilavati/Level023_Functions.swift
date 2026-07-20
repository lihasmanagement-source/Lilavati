import SwiftUI
import Foundation
import Combine

// MARK: - Level 35 · Coordinate Affection (wave-equation shapes, 3 stages)
//
// Each stage plots an animated travelling wave of the form
//     y = baseline(x) + A·sin(k·x − phase)·envelope(x)
// on an axes-only plane. Raising k packs the oscillation tighter until its
// envelope fills a shape. Reach k = 100 to clear a stage:
//   Stage 1 — heart   y = x^(2/3) + 0.9 sin(kx) √(3 − x²)
//   Stage 2 — circle  y = sin(kx) √(4 − x²)
//   Stage 3 — star    y = sin(kx) (∛4 − ∛x²)^(3/2)   (astroid)

struct HeartShapeStage {
    let name: String
    let equation: String
    let xMax: Double
    let yMin: Double
    let yMax: Double
    let amplitude: Double
    let baseline: (Double) -> Double
    let envelope: (Double) -> Double
}

@Observable
final class MathItLevelThirtyFiveViewModel {
    let stages: [HeartShapeStage] = MathItLevelThirtyFiveViewModel.makeStages()
    var stageIndex = 0
    var k: Double = 1
    var completed = false
    private var advancing = false
    private var armed = true        // must dip back down before the next stage can clear

    var stage: HeartShapeStage { stages[min(stageIndex, stages.count - 1)] }

    func updateK(_ value: Double) {
        guard !completed, !advancing else { return }
        // After a stage clears, ignore the still-held high values until the slider
        // comes back down — otherwise a finger parked at 100 skips the next stage.
        if !armed {
            if value <= 50 { armed = true } else { return }
        }
        k = value
        if k >= 100 { reachedTop() }
    }

    private func reachedTop() {
        advancing = true
        armed = false
        HapticPlayer.playCompletionTap()
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { completed = true }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.stageIndex += 1
                    self.k = 1
                }
                self.advancing = false
            }
        }
    }

    static func makeStages() -> [HeartShapeStage] {
        [
            HeartShapeStage(
                name: "heart",
                equation: "y = x^(2/3) + 0.9 sin(kx) √(3 − x²)",
                xMax: 1.7320508, yMin: -1.6, yMax: 2.3, amplitude: 0.9,
                baseline: { pow(abs($0), 2.0 / 3.0) },
                envelope: { let v = 3 - $0 * $0; return v > 0 ? v.squareRoot() : 0 }
            ),
            HeartShapeStage(
                name: "circle",
                equation: "y = sin(kx) √(4 − x²)",
                xMax: 2.0, yMin: -2.0, yMax: 2.0, amplitude: 1.0,
                baseline: { _ in 0 },
                envelope: { let v = 4 - $0 * $0; return v > 0 ? v.squareRoot() : 0 }
            ),
            HeartShapeStage(
                name: "star",
                equation: "y = sin(kx) (∛4 − ∛x²)^(3/2)",
                xMax: 2.0, yMin: -2.0, yMax: 2.0, amplitude: 1.0,
                baseline: { _ in 0 },
                envelope: {
                    let r = pow(2.0, 2.0 / 3.0)               // 2^(2/3) = ∛4
                    let t = r - pow(abs($0), 2.0 / 3.0)
                    return t > 0 ? pow(t, 1.5) : 0
                }
            ),
        ]
    }
}

struct MathItLevelThirtyFiveView: View {
    var viewModel: MathItLevelThirtyFiveViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    @State private var phase: Double = 0     // travelling-wave phase (drives the motion)
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private let heartPink = Color(red: 1.0, green: 0.52, blue: 0.66)
    private let heartRed = Color(red: 0.92, green: 0.21, blue: 0.34)
    private var titleGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 1.0, green: 0.56, blue: 0.30),
                                Color(red: 1.0, green: 0.42, blue: 0.62)],
                       startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let W = size.width, H = size.height

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect).position(x: 34, y: 54).zIndex(20)

                Canvas { context, csize in
                    drawGraph(&context, csize, stage: viewModel.stage, k: viewModel.k, phase: phase)
                }
                .frame(width: W, height: H * 0.55)
                .position(x: W / 2, y: H * 0.30)

                VStack(spacing: 14) {
                    EmptyView()
                        .font(.trajan(28))
                        .foregroundStyle(titleGradient)

                    Text(viewModel.stage.equation)
                        .font(.system(size: 17, design: .serif)).italic()
                        .foregroundStyle(.white.opacity(0.9))
                        .minimumScaleFactor(0.7).lineLimit(1)

                    Text("k = \(String(format: "%.1f", viewModel.k))")
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(heartRed)

                    HStack(spacing: 12) {
                        Text("k")
                            .font(.system(size: 17, weight: .bold, design: .serif)).italic()
                            .foregroundStyle(.white.opacity(0.85))
                        Slider(
                            value: Binding(get: { viewModel.k },
                                           set: { viewModel.updateK($0) }),
                            in: 1...100
                        )
                        .tint(heartRed)
                    }
                    .frame(width: W - 56)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .position(x: W / 2, y: H * 0.80)

                CompletionOverlay(
                    title: "Level 35 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
            }
            .onReceive(timer) { _ in
                // Always moving; faster as k grows.
                phase += (0.8 + viewModel.k * 0.05) / 60.0
                if phase > 2 * .pi { phase -= 2 * .pi }
            }
        }
    }

    private func drawGraph(_ context: inout GraphicsContext, _ size: CGSize,
                           stage: HeartShapeStage, k: Double, phase: Double) {
        let W = size.width, H = size.height
        let halfH = (stage.yMax - stage.yMin) / 2
        let yc = (stage.yMax + stage.yMin) / 2
        let scale = min((W * 0.42) / CGFloat(stage.xMax), (H * 0.44) / CGFloat(halfH))
        let originX = W / 2
        let originY = H * 0.5 + CGFloat(yc) * scale       // centre the shape vertically
        let axis = GraphicsContext.Shading.color(.white.opacity(0.85))

        // x-axis + right arrowhead
        var xAxis = Path()
        xAxis.move(to: CGPoint(x: 16, y: originY))
        xAxis.addLine(to: CGPoint(x: W - 14, y: originY))
        context.stroke(xAxis, with: axis, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        var xArrow = Path()
        xArrow.move(to: CGPoint(x: W - 14, y: originY)); xArrow.addLine(to: CGPoint(x: W - 26, y: originY - 7))
        xArrow.move(to: CGPoint(x: W - 14, y: originY)); xArrow.addLine(to: CGPoint(x: W - 26, y: originY + 7))
        context.stroke(xArrow, with: axis, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

        // y-axis + top arrowhead
        var yAxis = Path()
        yAxis.move(to: CGPoint(x: originX, y: H - 12))
        yAxis.addLine(to: CGPoint(x: originX, y: 12))
        context.stroke(yAxis, with: axis, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        var yArrow = Path()
        yArrow.move(to: CGPoint(x: originX, y: 12)); yArrow.addLine(to: CGPoint(x: originX - 7, y: 24))
        yArrow.move(to: CGPoint(x: originX, y: 12)); yArrow.addLine(to: CGPoint(x: originX + 7, y: 24))
        context.stroke(yArrow, with: axis, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

        // The wave
        let n = 1800
        var curve = Path()
        for i in 0...n {
            let x = -stage.xMax + 2 * stage.xMax * Double(i) / Double(n)
            let y = stage.baseline(x) + stage.amplitude * sin(k * x - phase) * stage.envelope(x)
            let px = originX + CGFloat(x) * scale
            let py = originY - CGFloat(y) * scale
            if i == 0 { curve.move(to: CGPoint(x: px, y: py)) } else { curve.addLine(to: CGPoint(x: px, y: py)) }
        }
        context.stroke(
            curve,
            with: .linearGradient(
                Gradient(colors: [heartPink, heartRed]),
                startPoint: CGPoint(x: originX, y: originY - CGFloat(stage.yMax) * scale),
                endPoint: CGPoint(x: originX, y: originY - CGFloat(stage.yMin) * scale)
            ),
            style: StrokeStyle(lineWidth: 2, lineJoin: .round)
        )
    }
}
