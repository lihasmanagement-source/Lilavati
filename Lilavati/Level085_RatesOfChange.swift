import Darwin
import Combine
import SwiftUI

private enum SnowboardRunPhase {
    case waiting
    case riding
    case climb
    case crest
    case descent
    case done
}

struct MathItLevelEightyFourView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var time = 0.0
    @State private var speed = 0.0
    @State private var phase: SnowboardRunPhase = .waiting
    @State private var lastTick = Date()
    @State private var runToken = UUID()
    @State private var pushPulse = 0
    @State private var resetGuard = false
    @State private var completed = false

    private let physicsTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private let coral = Color(red: 1.0, green: 0.31, blue: 0.27)
    private let cyan = Color(red: 0.24, green: 0.82, blue: 0.93)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    private var height: Double { SnowboardRateMath.height(at: time, stage: stageIndex) }
    private var slope: Double { SnowboardRateMath.slope(at: time, stage: stageIndex) }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760
            let graphHeight = min(proxy.size.width - 24, proxy.size.height * (compact ? 0.60 : 0.64), 590)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header
                        .padding(.top, compact ? 92 : 110)

                    SnowboardRateGraph(
                        stage: stageIndex,
                        time: time,
                        coral: coral,
                        cyan: cyan,
                        gold: gold,
                        phase: phase,
                        speed: speed
                    )
                    .frame(maxWidth: 680)
                    .frame(height: graphHeight)

                    readout
                        .frame(maxWidth: 680)

                    tapIndicator
                        .frame(maxWidth: 680)
                        .padding(.bottom, compact ? 4 : 12)
                }
                .padding(.horizontal, 12)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Rates Traced",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded(handleTap))
        .onAppear { lastTick = Date() }
        .onReceive(physicsTimer) { stepPhysics(at: $0) }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("STAGE \(stageIndex + 1) / 3")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(gold)
                .tracking(3)

            Text(SnowboardRateMath.equation(for: stageIndex))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(cyan.opacity(0.82))
        }
    }

    private var readout: some View {
        HStack(spacing: 10) {
            rateMetric(symbol: "t", value: String(format: "%.2f s", time), color: cyan)
            rateMetric(symbol: "h", value: String(format: "%.1f m", height), color: .white)
            rateMetric(symbol: "h′", value: slopeText, color: slopeColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func rateMetric(symbol: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(symbol)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var tapIndicator: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: tapSymbol)
                    .font(.system(size: 18, weight: .black))

                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < pushStrength ? slopeColor : .white.opacity(0.1))
                        .frame(width: 20, height: 5)
                }
            }
            .foregroundStyle(slopeColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            .scaleEffect(pushPulse.isMultiple(of: 2) ? 1 : 1.025)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: pushPulse)

            Button(action: resetLevel) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(gold)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.055), in: Circle())
                    .overlay(Circle().stroke(gold.opacity(0.38), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset snowboard run")
        }
        .padding(.horizontal, 10)
    }

    private var pushStrength: Int {
        if stageIndex != 1 {
            return phase == .waiting ? 0 : min(5, max(1, Int((time / 6 * 5).rounded(.up))))
        }
        return min(5, max(0, Int(((speed / 2.2) * 5).rounded(.up))))
    }

    private var tapSymbol: String {
        if phase == .waiting || phase == .climb { return "hand.tap.fill" }
        if phase == .crest { return "minus" }
        return "wind"
    }

    private var slopeText: String {
        if abs(slope) < 0.05 { return "0 m/s" }
        return String(format: "%+.1f m/s", slope)
    }

    private var slopeColor: Color {
        if abs(slope) < 0.7 { return gold }
        return slope > 0 ? coral : cyan
    }

    private func handleTap() {
        guard !completed, !resetGuard else { return }

        if stageIndex == 1 {
            guard phase == .climb else { return }
            speed = min(2.35, speed + 0.62)
            pushPulse += 1
            HapticPlayer.playLightTap()
            return
        }

        guard phase == .waiting else { return }
        phase = .riding
        speed = stageIndex == 0 ? 1.25 : 0.92
        pushPulse += 1
        HapticPlayer.playLightTap()
    }

    private func stepPhysics(at now: Date) {
        let delta = min(0.04, max(0, now.timeIntervalSince(lastTick)))
        lastTick = now
        guard delta > 0, !completed else { return }

        switch phase {
        case .waiting:
            break

        case .riding:
            time += speed * delta
            if time >= 6 {
                finishRun()
            }

        case .climb:
            let steepness = min(1, max(0, SnowboardRateMath.slope(at: time, stage: stageIndex) / 40))
            let downhillResistance = 0.10 + 0.58 * steepness
            speed -= (downhillResistance + max(0, speed) * 0.16) * delta
            speed = max(-0.30, speed)
            time += speed * delta

            if time <= 0 {
                time = 0
                speed = 0
            } else if time >= 3 {
                reachCrest()
            }

        case .crest:
            time = 3
            speed = 0

        case .descent:
            let descent = min(1, max(0, (time - 3) / 3))
            let gravity = 0.12 + 1.45 * descent
            speed += (gravity - speed * 0.035) * delta
            time += speed * delta
            if time >= 6 {
                finishRun()
            }

        case .done:
            break
        }
    }

    private func reachCrest() {
        time = 3
        speed = 0
        phase = .crest
        let token = runToken
        HapticPlayer.playLightTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            guard runToken == token, phase == .crest else { return }
            phase = .descent
            speed = 0.12
        }
    }

    private func finishRun() {
        time = 6
        speed = 0
        phase = .done
        let token = runToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard runToken == token, phase == .done else { return }
            if stageIndex < 2 {
                HapticPlayer.playLightTap()
                advanceStage()
            } else {
                HapticPlayer.playCompletionTap()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    completed = true
                }
            }
        }
    }

    private func advanceStage() {
        runToken = UUID()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            stageIndex += 1
            time = 0
            speed = 0
            phase = stageIndex == 1 ? .climb : .waiting
            pushPulse = 0
            lastTick = Date()
        }
    }

    private func resetLevel() {
        resetGuard = true
        runToken = UUID()
        completed = false
        stageIndex = 0
        phase = .waiting
        time = 0
        speed = 0
        pushPulse = 0
        lastTick = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            resetGuard = false
        }
    }
}

private struct SnowboardRateGraph: View {
    let stage: Int
    let time: Double
    let coral: Color
    let cyan: Color
    let gold: Color
    let phase: SnowboardRunPhase
    let speed: Double

    var body: some View {
        GeometryReader { geo in
            let plot = CGRect(x: 48, y: 42, width: geo.size.width - 76, height: geo.size.height - 82)
            let riderPoint = graphPoint(
                time: time,
                height: SnowboardRateMath.height(at: time, stage: stage),
                plot: plot
            )
            let angle = screenTangentAngle(time: time, plot: plot)
            let boardAnchorOffset = 25.5
            let riderCenter = CGPoint(
                x: riderPoint.x + CGFloat(sin(angle) * boardAnchorOffset),
                y: riderPoint.y - CGFloat(cos(angle) * boardAnchorOffset)
            )

            ZStack {
                Canvas { context, _ in
                    drawTerrain(context: &context, plot: plot)
                    drawAxes(context: &context, plot: plot)
                    drawCurve(context: &context, plot: plot)
                    drawSlopeRegions(context: &context, plot: plot)
                    drawTangent(context: &context, plot: plot)
                }

                if phase == .descent {
                    SnowboardSnowSpray(speed: speed)
                        .frame(width: 54, height: 34)
                        .rotationEffect(.radians(angle))
                        .position(
                            x: riderPoint.x - cos(angle) * 21,
                            y: riderPoint.y - 8 - sin(angle) * 21
                        )
                        .allowsHitTesting(false)
                }

                SnowboarderRateSprite(coral: coral, cyan: cyan, gold: gold)
                    .frame(width: 55, height: 62)
                    .rotationEffect(.radians(angle))
                    .position(riderCenter)
                    .shadow(color: .black.opacity(0.5), radius: 5, y: 4)
                    .scaleEffect(phase == .crest ? 1.08 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.68), value: phase)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.025, green: 0.055, blue: 0.075), Color(red: 0.01, green: 0.018, blue: 0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(gold.opacity(0.34), lineWidth: 1))
        }
    }

    private func drawTerrain(context: inout GraphicsContext, plot: CGRect) {
        var snow = Path()
        snow.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        for sample in 0...180 {
            let t = Double(sample) / 180 * 6
            snow.addLine(to: graphPoint(time: t, height: SnowboardRateMath.height(at: t, stage: stage), plot: plot))
        }
        snow.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        snow.closeSubpath()
        context.fill(
            snow,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.22), cyan.opacity(0.10), cyan.opacity(0.025)]),
                startPoint: CGPoint(x: plot.midX, y: plot.minY),
                endPoint: CGPoint(x: plot.midX, y: plot.maxY)
            )
        )
    }

    private func drawAxes(context: inout GraphicsContext, plot: CGRect) {
        var axes = Path()
        axes.move(to: CGPoint(x: plot.minX, y: plot.minY))
        axes.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        axes.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(axes, with: .color(.white.opacity(0.48)), lineWidth: 1.3)

        for second in 0...6 {
            let point = graphPoint(time: Double(second), height: 0, plot: plot)
            var tick = Path()
            tick.move(to: CGPoint(x: point.x, y: plot.maxY - 4))
            tick.addLine(to: CGPoint(x: point.x, y: plot.maxY + 4))
            context.stroke(tick, with: .color(.white.opacity(0.34)), lineWidth: 1)
            context.draw(
                Text("\(second)").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.48)),
                at: CGPoint(x: point.x, y: plot.maxY + 13)
            )
        }

        for meters in stride(from: 0, through: 60, by: 10) {
            let point = graphPoint(time: 0, height: Double(meters), plot: plot)
            var grid = Path()
            grid.move(to: CGPoint(x: plot.minX, y: point.y))
            grid.addLine(to: CGPoint(x: plot.maxX, y: point.y))
            context.stroke(grid, with: .color(.white.opacity(meters == 0 ? 0.2 : 0.065)), lineWidth: 0.8)
            context.draw(
                Text("\(meters)").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.46)),
                at: CGPoint(x: plot.minX - 15, y: point.y)
            )
        }

        context.draw(Text("h (m)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(cyan), at: CGPoint(x: plot.minX + 14, y: plot.minY - 14))
        context.draw(Text("t (s)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(coral), at: CGPoint(x: plot.maxX + 12, y: plot.maxY))
    }

    private func drawCurve(context: inout GraphicsContext, plot: CGRect) {
        var curve = Path()
        for sample in 0...240 {
            let t = Double(sample) / 240 * 6
            let point = graphPoint(time: t, height: SnowboardRateMath.height(at: t, stage: stage), plot: plot)
            sample == 0 ? curve.move(to: point) : curve.addLine(to: point)
        }
        context.stroke(curve, with: .color(.white.opacity(0.94)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))

        if stage == 1 {
            let vertex = graphPoint(time: 3, height: 60, plot: plot)
            context.fill(Path(ellipseIn: CGRect(x: vertex.x - 5, y: vertex.y - 5, width: 10, height: 10)), with: .color(gold))
            context.stroke(Path(ellipseIn: CGRect(x: vertex.x - 11, y: vertex.y - 11, width: 22, height: 22)), with: .color(gold.opacity(0.42)), lineWidth: 1.5)
        } else if stage == 2 {
            let inflection = graphPoint(time: 3, height: SnowboardRateMath.height(at: 3, stage: stage), plot: plot)
            context.fill(Path(ellipseIn: CGRect(x: inflection.x - 4, y: inflection.y - 4, width: 8, height: 8)), with: .color(gold))
            context.stroke(Path(ellipseIn: CGRect(x: inflection.x - 10, y: inflection.y - 10, width: 20, height: 20)), with: .color(gold.opacity(0.42)), lineWidth: 1.5)
        }
    }

    private func drawSlopeRegions(context: inout GraphicsContext, plot: CGRect) {
        switch stage {
        case 0:
            context.draw(
                Text("CONSTANT RATE  h′ = −10").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(cyan.opacity(0.88)),
                at: graphPoint(time: 3, height: 36, plot: plot)
            )
        case 1:
            context.draw(
                Text("POSITIVE\nSLOPE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(coral.opacity(0.8)),
                at: graphPoint(time: 1.2, height: 31, plot: plot)
            )
            context.draw(
                Text("SLOPE = 0").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(gold),
                at: CGPoint(x: graphPoint(time: 3, height: 60, plot: plot).x, y: plot.minY + 5)
            )
            context.draw(
                Text("NEGATIVE\nSLOPE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(cyan.opacity(0.82)),
                at: graphPoint(time: 4.8, height: 31, plot: plot)
            )
        default:
            context.draw(
                Text("h′ CHANGES").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(coral.opacity(0.82)),
                at: graphPoint(time: 1.15, height: 53, plot: plot)
            )
            context.draw(
                Text("INFLECTION").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(gold),
                at: graphPoint(time: 3, height: 24, plot: plot)
            )
            context.draw(
                Text("h′ CHANGES").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(cyan.opacity(0.82)),
                at: graphPoint(time: 4.85, height: 8, plot: plot)
            )
        }
    }

    private func drawTangent(context: inout GraphicsContext, plot: CGRect) {
        let slope = SnowboardRateMath.slope(at: time, stage: stage)
        let span = 0.55
        let startT = max(0, time - span)
        let endT = min(6, time + span)
        let h = SnowboardRateMath.height(at: time, stage: stage)
        let start = graphPoint(time: startT, height: h + slope * (startT - time), plot: plot)
        let end = graphPoint(time: endT, height: h + slope * (endT - time), plot: plot)
        var tangent = Path()
        tangent.move(to: start)
        tangent.addLine(to: end)
        context.stroke(tangent, with: .color(gold), style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
    }

    private func graphPoint(time: Double, height: Double, plot: CGRect) -> CGPoint {
        CGPoint(
            x: plot.minX + CGFloat(time / 6) * plot.width,
            y: plot.maxY - CGFloat(height / 66) * plot.height
        )
    }

    private func screenTangentAngle(time: Double, plot: CGRect) -> Double {
        let screenSlope = -SnowboardRateMath.slope(at: time, stage: stage) * 6 / 66 * Double(plot.height / plot.width)
        return atan(screenSlope)
    }
}

private struct SnowboardSnowSpray: View {
    let speed: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for index in 0..<9 {
                    let cycle = (time * (1.8 + speed * 0.7) + Double(index) * 0.31)
                        .truncatingRemainder(dividingBy: 1)
                    let x = size.width * (1 - cycle)
                    let arc = sin(cycle * .pi)
                    let y = size.height * 0.68 - arc * size.height * (0.24 + Double(index % 3) * 0.05)
                    let diameter = 2.2 + Double(index % 3)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                        with: .color(.white.opacity(0.28 + arc * 0.5))
                    )
                }
            }
        }
    }
}

private struct SnowboarderRateSprite: View {
    let coral: Color
    let cyan: Color
    let gold: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            var board = Path()
            board.move(to: CGPoint(x: center.x - 22, y: center.y + 20))
            board.addQuadCurve(to: CGPoint(x: center.x + 22, y: center.y + 20), control: CGPoint(x: center.x, y: center.y + 25))
            context.stroke(board, with: .color(gold), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            var backLeg = Path()
            backLeg.move(to: CGPoint(x: center.x - 4, y: center.y + 5))
            backLeg.addLine(to: CGPoint(x: center.x - 12, y: center.y + 18))
            context.stroke(backLeg, with: .color(cyan), style: StrokeStyle(lineWidth: 5, lineCap: .round))

            var frontLeg = Path()
            frontLeg.move(to: CGPoint(x: center.x + 3, y: center.y + 5))
            frontLeg.addLine(to: CGPoint(x: center.x + 12, y: center.y + 18))
            context.stroke(frontLeg, with: .color(cyan), style: StrokeStyle(lineWidth: 5, lineCap: .round))

            var body = Path()
            body.move(to: CGPoint(x: center.x, y: center.y + 6))
            body.addLine(to: CGPoint(x: center.x - 1, y: center.y - 13))
            context.stroke(body, with: .color(coral), style: StrokeStyle(lineWidth: 9, lineCap: .round))

            var arms = Path()
            arms.move(to: CGPoint(x: center.x - 1, y: center.y - 8))
            arms.addLine(to: CGPoint(x: center.x - 15, y: center.y - 1))
            arms.move(to: CGPoint(x: center.x, y: center.y - 8))
            arms.addLine(to: CGPoint(x: center.x + 15, y: center.y - 13))
            context.stroke(arms, with: .color(coral), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

            context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 28, width: 14, height: 14)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 29, width: 16, height: 7)), with: .color(cyan))
        }
    }
}

private enum SnowboardRateMath {
    static func height(at time: Double, stage: Int) -> Double {
        switch stage {
        case 0:
            return max(0, 60 - 10 * time)
        case 1:
            return max(0, 60 - (20.0 / 3.0) * pow(time - 3, 2))
        default:
            return 1.5 * pow(time, 3) - 13.5 * pow(time, 2) + 27 * time + 30
        }
    }

    static func slope(at time: Double, stage: Int) -> Double {
        switch stage {
        case 0:
            return -10
        case 1:
            return -(40.0 / 3.0) * (time - 3)
        default:
            return 4.5 * pow(time, 2) - 27 * time + 27
        }
    }

    static func equation(for stage: Int) -> String {
        switch stage {
        case 0:
            return "h(t) = 60 − 10t"
        case 1:
            return "h(t) = 60 − (20/3)(t − 3)²"
        default:
            return "h(t) = 1.5t³ − 13.5t² + 27t + 30"
        }
    }
}

#Preview {
    MathItLevelEightyFourView(onContinue: {}, onLevelSelect: {})
}
