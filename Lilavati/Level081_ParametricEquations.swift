import Darwin
import SwiftUI

struct MathItLevelEightyView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var traceProgress = 0.0
    @State private var flightPending = false
    @State private var butterflyFlying = false
    @State private var flightStartTime: TimeInterval?
    @State private var completed = false
    @State private var animationToken = UUID()

    private let coral = Color(red: 1.0, green: 0.29, blue: 0.27)
    private let cyan = Color(red: 0.20, green: 0.84, blue: 0.92)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760
            let graphHeight = min(proxy.size.width - 24, proxy.size.height * (compact ? 0.58 : 0.62), 590)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header
                        .padding(.top, compact ? 92 : 110)

                    ParametricButterflyGraph(
                        progress: traceProgress,
                        butterflyFlying: butterflyFlying,
                        flightStartTime: flightStartTime,
                        coral: coral,
                        cyan: cyan,
                        gold: gold
                    )
                    .frame(maxWidth: 650)
                    .frame(height: graphHeight)

                    equationReadout
                        .frame(maxWidth: 650)

                    controls
                        .frame(maxWidth: 650)
                        .padding(.bottom, compact ? 4 : 12)
                }
                .padding(.horizontal, 12)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Butterfly Curve Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, coral)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [coral, cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 82, height: 4)
        }
    }

    private var equationReadout: some View {
        VStack(spacing: 4) {
            Text("x(t) = sin(t)[e^(cos t) − 2cos(4t) − sin⁵(t/12)]")
                .foregroundStyle(coral.opacity(0.95))

            Text("y(t) = cos(t)[e^(cos t) − 2cos(4t) − sin⁵(t/12)]")
                .foregroundStyle(cyan.opacity(0.95))

            Text("0 ≤ t ≤ 12π")
                .foregroundStyle(.white.opacity(0.62))
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.68)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.11), lineWidth: 1))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                Slider(value: traceBinding, in: 0...1)
                    .tint(coral)
                    .disabled(flightPending || butterflyFlying || completed)

                HStack {
                    Text("t = 0")
                    Spacer()
                    Text("t = \(formatParameter)π")
                    Spacer()
                    Text("12π")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            }

            Button(action: resetTrace) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(gold)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.055), in: Circle())
                    .overlay(Circle().stroke(gold.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset curve")
        }
        .padding(.horizontal, 10)
    }

    private var formatParameter: String {
        String(format: "%.1f", traceProgress * 12)
    }

    private var traceBinding: Binding<Double> {
        Binding(
            get: { traceProgress },
            set: { newValue in
                guard !flightPending, !butterflyFlying, !completed else { return }
                traceProgress = min(1, max(0, newValue))
                if newValue >= 0.995 {
                    traceProgress = 1
                    beginButterflyFlight()
                }
            }
        )
    }

    private func beginButterflyFlight() {
        guard !flightPending, !butterflyFlying, !completed else { return }
        flightPending = true
        let token = UUID()
        animationToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            guard animationToken == token else { return }
            flightPending = false
            butterflyFlying = true
            flightStartTime = Date.timeIntervalSinceReferenceDate

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.32) {
                guard animationToken == token else { return }
                HapticPlayer.playCompletionTap()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    completed = true
                }
            }
        }
    }

    private func resetTrace() {
        animationToken = UUID()
        flightPending = false
        butterflyFlying = false
        flightStartTime = nil
        completed = false
        withAnimation(.easeOut(duration: 0.25)) {
            traceProgress = 0
        }
    }

    private func resetLevel() {
        resetTrace()
    }
}

private struct ParametricButterflyGraph: View {
    let progress: Double
    let butterflyFlying: Bool
    let flightStartTime: TimeInterval?
    let coral: Color
    let cyan: Color
    let gold: Color

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) - 14
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side / 2 - 24

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let pulse = (sin(time * 4) + 1) / 2
                let flightProgress = butterflyFlying
                    ? min(1, max(0, (time - (flightStartTime ?? time)) / 3.25))
                    : 0

                Canvas { context, _ in
                    drawGrid(context: &context, center: center, radius: radius)
                    drawCurve(
                        context: &context,
                        center: center,
                        radius: radius,
                        pulse: pulse,
                        time: time,
                        flightProgress: flightProgress
                    )
                }
            }
            .background(
                RadialGradient(
                    colors: [coral.opacity(0.055), Color(red: 0.018, green: 0.025, blue: 0.035), .black],
                    center: .center,
                    startRadius: 12,
                    endRadius: side * 0.62
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(gold.opacity(0.32), lineWidth: 1))
        }
    }

    private func drawGrid(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        for ring in 1...5 {
            let ringRadius = radius * CGFloat(ring) / 5
            let rect = CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(ring == 5 ? 0.25 : 0.115)),
                style: StrokeStyle(lineWidth: ring == 5 ? 1.3 : 0.8, dash: [2.5, 3.5])
            )

            context.draw(
                Text("\(ring)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.43)),
                at: CGPoint(x: center.x + ringRadius - 4, y: center.y + 10)
            )
        }

        for spoke in 0..<16 {
            let angle = Double(spoke) * .pi / 8
            let end = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y - sin(angle) * radius
            )
            var line = Path()
            line.move(to: center)
            line.addLine(to: end)
            context.stroke(
                line,
                with: .color(.white.opacity(spoke.isMultiple(of: 4) ? 0.24 : 0.08)),
                style: StrokeStyle(lineWidth: spoke.isMultiple(of: 4) ? 1.2 : 0.75, dash: spoke.isMultiple(of: 4) ? [] : [2, 4])
            )
        }

        context.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(gold))
        context.draw(Text("x").font(.system(size: 10, weight: .black)).foregroundStyle(coral), at: CGPoint(x: center.x + radius + 12, y: center.y))
        context.draw(Text("y").font(.system(size: 10, weight: .black)).foregroundStyle(cyan), at: CGPoint(x: center.x, y: center.y - radius - 12))
    }

    private func drawCurve(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        pulse: Double,
        time: TimeInterval,
        flightProgress: Double
    ) {
        let guide = butterflyPath(center: center, radius: radius, progress: 1)
        context.stroke(
            guide,
            with: .color(.white.opacity(0.26 * (1 - flightProgress))),
            style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round, dash: [3, 4])
        )

        guard progress > 0 else { return }
        if butterflyFlying {
            let lingeringTrace = max(0, 1 - flightProgress * 7)
            if lingeringTrace > 0 {
                context.stroke(
                    butterflyPath(center: center, radius: radius, progress: 1),
                    with: .color(coral.opacity(0.75 * lingeringTrace)),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
            drawFlyingButterfly(
                context: &context,
                center: center,
                radius: radius,
                time: time,
                flightProgress: flightProgress
            )
            return
        }

        let traced = butterflyPath(center: center, radius: radius, progress: progress)
        context.stroke(
            traced,
            with: .color(coral),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )

        let parameter = progress * 12 * .pi
        let marker = screenPoint(ParametricButterflyMath.point(at: parameter), center: center, radius: radius)
        let glowSize = 14 + pulse * 7
        context.fill(
            Path(ellipseIn: CGRect(x: marker.x - glowSize / 2, y: marker.y - glowSize / 2, width: glowSize, height: glowSize)),
            with: .color(coral.opacity(0.12 + pulse * 0.1))
        )
        context.fill(Path(ellipseIn: CGRect(x: marker.x - 4, y: marker.y - 4, width: 8, height: 8)), with: .color(.white))
        context.stroke(Path(ellipseIn: CGRect(x: marker.x - 5.5, y: marker.y - 5.5, width: 11, height: 11)), with: .color(coral), lineWidth: 2)
    }

    private func drawFlyingButterfly(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        flightProgress: Double
    ) {
        let easedProgress = flightProgress * flightProgress * (3 - 2 * flightProgress)
        let rawFlap = 0.67 + ((sin(time * 8.4) + 1) / 2) * 0.33
        let flapBlend = min(1, flightProgress * 4)
        let flap = 1 - (1 - rawFlap) * flapBlend
        let scale = 1 - easedProgress * 0.5
        let rotation = sin(time * 2.3) * 0.04 + easedProgress * 0.08
        let flightOffset = CGPoint(
            x: radius * (0.23 * easedProgress + 0.025 * sin(.pi * easedProgress)),
            y: -radius * 0.60 * easedProgress + sin(time * 4.2) * 1.8 * (1 - easedProgress)
        )
        let flightCenter = CGPoint(x: center.x + flightOffset.x, y: center.y + flightOffset.y)

        let shadowWidth = radius * (0.62 - easedProgress * 0.34)
        let shadowRect = CGRect(
            x: center.x - shadowWidth / 2,
            y: center.y + radius * 0.07,
            width: shadowWidth,
            height: max(5, shadowWidth * 0.12)
        )
        context.fill(
            Path(ellipseIn: shadowRect),
            with: .color(.black.opacity(0.34 * (1 - easedProgress)))
        )

        var flyingCurve = Path()
        for sample in 0...1_440 {
            let t = Double(sample) / 1_440 * 12 * .pi
            let point = ParametricButterflyMath.point(at: t)
            let localX = point.x * radius / 4.75 * scale * flap
            let localY = -point.y * radius / 4.75 * scale
            let rotatedX = localX * cos(rotation) - localY * sin(rotation)
            let rotatedY = localX * sin(rotation) + localY * cos(rotation)
            let screenPoint = CGPoint(
                x: flightCenter.x + rotatedX,
                y: flightCenter.y + rotatedY
            )
            sample == 0 ? flyingCurve.move(to: screenPoint) : flyingCurve.addLine(to: screenPoint)
        }

        context.stroke(
            flyingCurve,
            with: .color(coral.opacity(0.16)),
            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            flyingCurve,
            with: .color(coral),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )
    }

    private func butterflyPath(center: CGPoint, radius: CGFloat, progress: Double) -> Path {
        var path = Path()
        let totalSamples = 1_440
        let finalSample = max(1, Int(Double(totalSamples) * progress))

        for sample in 0...finalSample {
            let t = Double(sample) / Double(totalSamples) * 12 * .pi
            let point = screenPoint(ParametricButterflyMath.point(at: t), center: center, radius: radius)
            sample == 0 ? path.move(to: point) : path.addLine(to: point)
        }

        return path
    }

    private func screenPoint(_ point: CGPoint, center: CGPoint, radius: CGFloat) -> CGPoint {
        let scale = radius / 4.75
        return CGPoint(x: center.x + point.x * scale, y: center.y - point.y * scale)
    }
}

private enum ParametricButterflyMath {
    static func point(at t: Double) -> CGPoint {
        let radial = exp(cos(t)) - 2 * cos(4 * t) - pow(sin(t / 12), 5)
        return CGPoint(x: sin(t) * radial, y: cos(t) * radial)
    }
}

#Preview {
    MathItLevelEightyView(onContinue: {}, onLevelSelect: {})
}
