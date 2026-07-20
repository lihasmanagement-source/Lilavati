import SwiftUI

struct MathItLevelOneHundredTwentyView: View {
    private let stages = EchoStage.all
    private let cyan = Color(red: 0.20, green: 0.86, blue: 0.94)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.30, blue: 0.25)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var center = 0.0
    @State private var pulseSpeed = 2.0
    @State private var pulseStart: Date?
    @State private var result: EchoResult = .idle
    @State private var completed = false
    @State private var animationToken = UUID()

    private var stage: EchoStage { stages[stageIndex] }
    private var slope: Double { 2 / pulseSpeed }
    private var allTargetsDetected: Bool {
        stage.targets.allSatisfy { abs(slope * abs($0.x - center) - $0.time) < 0.08 }
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.018, green: 0.034, blue: 0.052).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    echoField
                        .frame(maxWidth: 920)
                        .frame(height: max(390, min(515, proxy.size.height * 0.61)))

                    controls(compact: compact)
                        .frame(maxWidth: 760)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 120 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear { loadStage() }
        .onChange(of: center) { _, _ in evaluateTargets() }
        .onChange(of: pulseSpeed) { _, _ in evaluateTargets() }
        .task(id: stageIndex) {
            while !Task.isCancelled, !completed {
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
                if allTargetsDetected {
                    evaluateTargets()
                    return
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(stages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex ? cyan : index == stageIndex ? gold : .white.opacity(0.13))
                        .frame(width: index == stageIndex ? 42 : 24, height: 5)
                }
            }

            Image(systemName: result == .success ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(result == .success ? cyan : gold)
        }
        .accessibilityLabel("Stage \(stageIndex + 1) of \(stages.count)")
    }

    private var echoField: some View {
        GeometryReader { geo in
            let plot = CGRect(x: 54, y: 24, width: geo.size.width - 78, height: geo.size.height - 70)

            TimelineView(.animation) { timeline in
                let pulseProgress = currentPulseProgress(at: timeline.date)
                let continuousWaveProgress = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 2.8) / 2.8
                let rayProgress = result == .success
                    ? 0.46 + pulseProgress * 0.54
                    : continuousWaveProgress

                ZStack {
                    Canvas { context, size in
                        drawCave(in: &context, size: size, plot: plot)
                        drawAxes(in: &context, plot: plot)
                        drawEchoGraph(in: &context, plot: plot, pulseProgress: pulseProgress)
                        drawWaveRays(
                            in: &context,
                            plot: plot,
                            pulseProgress: rayProgress,
                            wavePhase: timeline.date.timeIntervalSinceReferenceDate
                        )
                        drawTargets(in: &context, plot: plot, pulseProgress: pulseProgress)
                    }

                    beacon
                        .position(graphPoint(x: center, y: 0, plot: plot))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    guard pulseStart == nil, result != .success else { return }
                                    center = min(5, max(-5, snappedX(value.location.x, plot: plot)))
                                }
                        )

                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var beacon: some View {
        ZStack {
            Circle()
                .fill(result == .failure ? coral.opacity(0.28) : cyan.opacity(0.22))
                .frame(width: 54, height: 54)
            Circle()
                .stroke(result == .failure ? coral : cyan, lineWidth: 2)
                .frame(width: 38, height: 38)
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)
        }
        .shadow(color: (result == .failure ? coral : cyan).opacity(0.65), radius: 12)
        .accessibilityLabel("Echolocation beacon at x equals \(Int(center))")
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 11) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("h = \(Int(center))")
                    }
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)

                    Slider(value: $center, in: -5...5, step: 1)
                    .tint(cyan)
                    .disabled(pulseStart != nil || result == .success)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "speedometer")
                        Text("v = \(speedLabel)")
                    }
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(gold)

                    Slider(value: $pulseSpeed, in: 1...4, step: 1)
                    .tint(gold)
                    .disabled(pulseStart != nil || result == .success)
                }
            }

            HStack {
                Text("y = \(slopeLabel)|x \(centerSign) \(abs(Int(center)))|")
                Spacer()
                Text("t = 2|x − h| / v")
            }
            .font(.system(size: compact ? 10 : 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
            .minimumScaleFactor(0.58)
            .lineLimit(1)
        }
        .padding(compact ? 10 : 13)
        .background(Color(red: 0.04, green: 0.06, blue: 0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1)))
    }

    private var speedLabel: String { String(format: "%.0f", pulseSpeed) }
    private var slopeLabel: String {
        if slope == 1 { return "" }
        return slope == 0.5 ? "0.5" : String(format: "%.0f", slope)
    }
    private var centerSign: String { center >= 0 ? "−" : "+" }

    private func drawCave(in context: inout GraphicsContext, size: CGSize, plot: CGRect) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.025, green: 0.055, blue: 0.078)))

        for index in 0..<11 {
            let x = plot.minX + CGFloat(index) * plot.width / 10
            let height = CGFloat(10 + (index * 17) % 28)
            var stalactite = Path()
            stalactite.move(to: CGPoint(x: x - 13, y: 0))
            stalactite.addLine(to: CGPoint(x: x, y: height))
            stalactite.addLine(to: CGPoint(x: x + 13, y: 0))
            stalactite.closeSubpath()
            context.fill(stalactite, with: .color(.white.opacity(0.035)))
        }
    }

    private func drawAxes(in context: inout GraphicsContext, plot: CGRect) {
        for x in -6...6 {
            let px = mapX(Double(x), plot: plot)
            var vertical = Path()
            vertical.move(to: CGPoint(x: px, y: plot.minY))
            vertical.addLine(to: CGPoint(x: px, y: plot.maxY))
            context.stroke(vertical, with: .color(.white.opacity(x == 0 ? 0.16 : 0.045)), lineWidth: 1)
            context.draw(Text("\(x)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.32)), at: CGPoint(x: px, y: plot.maxY + 17))
        }

        for y in stride(from: 0, through: 8, by: 2) {
            let py = mapY(Double(y), plot: plot)
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: plot.minX, y: py))
            horizontal.addLine(to: CGPoint(x: plot.maxX, y: py))
            context.stroke(horizontal, with: .color(.white.opacity(y == 0 ? 0.18 : 0.045)), lineWidth: 1)
            context.draw(Text("\(y)s").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.32)), at: CGPoint(x: plot.minX - 24, y: py))
        }
    }

    private func drawEchoGraph(in context: inout GraphicsContext, plot: CGRect, pulseProgress: Double) {
        var graph = Path()
        var started = false
        for step in 0...160 {
            let x = -6 + 12 * Double(step) / 160
            let y = slope * abs(x - center)
            guard y <= 8.4 else { started = false; continue }
            let point = graphPoint(x: x, y: y, plot: plot)
            if started { graph.addLine(to: point) } else { graph.move(to: point); started = true }
        }
        context.stroke(graph, with: .color(cyan.opacity(pulseStart == nil ? 0.20 : 0.28)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        if pulseProgress > 0, pulseProgress < 1 {
            let radius = CGFloat(sin(pulseProgress * .pi)) * 62
            let centerPoint = graphPoint(x: center, y: 0, plot: plot)
            context.stroke(Path(ellipseIn: CGRect(x: centerPoint.x - radius, y: centerPoint.y - radius, width: radius * 2, height: radius * 2)), with: .color(gold.opacity(0.55)), lineWidth: 2)
        }
    }

    private func drawWaveRays(
        in context: inout GraphicsContext,
        plot: CGRect,
        pulseProgress: Double,
        wavePhase: TimeInterval
    ) {
        let outboundProgress = min(1, pulseProgress / 0.46)
        let returnProgress = min(1, max(0, (pulseProgress - 0.46) / 0.54))
        let emitter = graphPoint(x: center, y: 0, plot: plot)

        for target in stage.targets {
            let predictedTime = slope * abs(target.x - center)
            let impact = graphPoint(x: target.x, y: predictedTime, plot: plot)
            let matched = abs(predictedTime - target.time) < 0.08

            if returnProgress == 0 {
                drawWaveSegment(
                    in: &context,
                    from: emitter,
                    to: impact,
                    progress: outboundProgress,
                    phase: wavePhase,
                    color: gold
                )
            } else if matched {
                drawWaveSegment(
                    in: &context,
                    from: impact,
                    to: emitter,
                    progress: returnProgress,
                    phase: wavePhase,
                    color: cyan
                )

                let targetPoint = graphPoint(x: target.x, y: target.time, plot: plot)
                let ringRadius = 12 + CGFloat(sin(wavePhase * 8) + 1) * 3
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: targetPoint.x - ringRadius,
                        y: targetPoint.y - ringRadius,
                        width: ringRadius * 2,
                        height: ringRadius * 2
                    )),
                    with: .color(cyan.opacity(0.72)),
                    lineWidth: 2
                )
            } else {
                drawWaveSegment(
                    in: &context,
                    from: emitter,
                    to: impact,
                    progress: 1,
                    phase: wavePhase,
                    color: coral.opacity(0.55)
                )
            }
        }
    }

    private func drawWaveSegment(
        in context: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        progress: Double,
        phase: TimeInterval,
        color: Color
    ) {
        let clampedProgress = min(1, max(0, progress))
        guard clampedProgress > 0 else { return }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(1, hypot(dx, dy))
        let normal = CGVector(dx: -dy / distance, dy: dx / distance)
        let sampleCount = max(8, Int(distance * clampedProgress / 4))
        var wave = Path()

        for sample in 0...sampleCount {
            let local = CGFloat(sample) / CGFloat(sampleCount)
            let travel = local * CGFloat(clampedProgress)
            let carrier = sin((travel * distance / 32) * 2 * .pi - CGFloat(phase) * 7)
            let envelope = sin(local * .pi)
            let amplitude = CGFloat(carrier) * envelope * 10
            let point = CGPoint(
                x: start.x + dx * travel + normal.dx * amplitude,
                y: start.y + dy * travel + normal.dy * amplitude
            )
            if sample == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
        }

        context.stroke(
            wave,
            with: .color(color.opacity(0.24)),
            style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            wave,
            with: .color(color),
            style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawTargets(in context: inout GraphicsContext, plot: CGRect, pulseProgress: Double) {
        for target in stage.targets {
            let point = graphPoint(x: target.x, y: target.time, plot: plot)
            let matched = abs(slope * abs(target.x - center) - target.time) < 0.08
            let color = result == .failure && !matched ? coral : matched ? cyan : gold
            context.fill(Path(ellipseIn: CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)), with: .color(color.opacity(0.16)))
            context.stroke(Path(ellipseIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)), with: .color(color), lineWidth: 2)
            context.draw(Text("\(target.timeLabel)s").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.75)), at: CGPoint(x: point.x, y: point.y - 19))
        }
    }

    private func graphPoint(x: Double, y: Double, plot: CGRect) -> CGPoint {
        CGPoint(x: mapX(x, plot: plot), y: mapY(y, plot: plot))
    }
    private func mapX(_ x: Double, plot: CGRect) -> CGFloat { plot.minX + CGFloat((x + 6) / 12) * plot.width }
    private func mapY(_ y: Double, plot: CGRect) -> CGFloat { plot.maxY - CGFloat(y / 8.5) * plot.height }
    private func snappedX(_ pixel: CGFloat, plot: CGRect) -> Double {
        round(Double((pixel - plot.minX) / plot.width) * 12 - 6)
    }

    private func currentPulseProgress(at date: Date) -> Double {
        guard let pulseStart else { return 0 }
        return min(1, max(0, date.timeIntervalSince(pulseStart) / 1.7))
    }

    private func evaluateTargets() {
        guard result != .success else { return }
        guard allTargetsDetected else {
            animationToken = UUID()
            result = .idle
            return
        }

        let token = UUID()
        animationToken = token
        result = .success
        pulseStart = Date()
        HapticPlayer.playCompletionTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            guard animationToken == token, result == .success else { return }
            pulseStart = nil
            advanceStage()
        }
    }

    private func advanceStage() {
        if stageIndex == stages.count - 1 {
            completed = true
        } else {
            stageIndex += 1
            loadStage()
        }
    }

    private func loadStage() {
        animationToken = UUID()
        center = stage.startCenter
        pulseSpeed = stage.startSpeed
        pulseStart = nil
        result = .idle
    }

    private func resetLevel() {
        completed = false
        stageIndex = 0
        loadStage()
    }
}

private enum EchoResult {
    case idle, failure, success
}

private struct EchoTarget: Identifiable {
    let id = UUID()
    let x: Double
    let time: Double
    var timeLabel: String { time.rounded() == time ? String(Int(time)) : String(format: "%.1f", time) }
}

private struct EchoStage {
    let name: String
    let startCenter: Double
    let startSpeed: Double
    let targets: [EchoTarget]

    static let all: [EchoStage] = [
        .init(name: "Scan 1 · Center the Beacon", startCenter: -2, startSpeed: 2, targets: [
            .init(x: -3, time: 3), .init(x: 3, time: 3)
        ]),
        .init(name: "Scan 2 · Widen the Pulse", startCenter: 1, startSpeed: 2, targets: [
            .init(x: -6, time: 2), .init(x: 2, time: 2), .init(x: 4, time: 3)
        ]),
        .init(name: "Scan 3 · Deep Chamber", startCenter: -1, startSpeed: 4, targets: [
            .init(x: -2, time: 8), .init(x: 0, time: 4), .init(x: 4, time: 4), .init(x: 6, time: 8)
        ])
    ]
}

#Preview {
    MathItLevelOneHundredTwentyView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 120) ?? 120)
}
