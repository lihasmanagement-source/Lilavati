import SwiftUI

struct MathItLevelOneHundredThirtyTwoView: View {
    private let stages = InstantSpeedStage.all
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var time = 1.0
    @State private var feedback: SpeedCheckFeedback?
    @State private var solved = false
    @State private var completed = false
    @State private var animationToken = UUID()

    private var stage: InstantSpeedStage { stages[stageIndex] }
    private var speed: Double { stage.profile.speed(at: time) }
    private var distance: Double { stage.profile.distance(at: time) }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.017, green: 0.027, blue: 0.043).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    motionGraph
                        .frame(maxWidth: 920)
                        .frame(height: max(405, min(530, proxy.size.height * 0.61)))

                    controls(compact: compact)
                        .frame(maxWidth: 820)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Instantaneous Speed Calibrated",
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

            Text(stage.name.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(gold)

            EmptyView()
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(solved ? cyan : .white)
        }
    }

    private var motionGraph: some View {
        GeometryReader { geo in
            let plot = CGRect(x: 66, y: 64, width: geo.size.width - 132, height: geo.size.height - 116)

            ZStack {
                Canvas { context, _ in
                    drawGrid(context: &context, plot: plot)
                    drawDistanceCurve(context: &context, plot: plot)
                    drawCurrentInstant(context: &context, plot: plot)
                }

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .frame(width: plot.width, height: plot.height)
                    .position(x: plot.midX, y: plot.midY)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !solved else { return }
                                let raw = Double((value.location.x - plot.minX) / plot.width) * 6
                                time = min(6, max(0, (raw * 10).rounded() / 10))
                                feedback = nil
                            }
                    )

                vehicle(plot: plot)

                VStack {
                    HStack {
                        metric("TIME", "\(format(time)) s")
                        metric("DISTANCE", "\(format(distance)) m")
                        Spacer()
                        speedLimitSign
                        speedometer
                    }
                    Spacer()
                }
                .padding(12)

                if let feedback {
                    Text(feedback.message)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(feedback.isMatch ? cyan : coral)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.76))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .position(x: plot.midX, y: plot.maxY - 12)
                }
            }
            .background(Color(red: 0.035, green: 0.047, blue: 0.075))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func vehicle(plot: CGRect) -> some View {
        let point = graphPoint(t: time, value: distance, plot: plot)
        let xScale = plot.width / 6
        let yScale = plot.height / CGFloat(stage.yMax)
        let screenAngle = atan2(-CGFloat(speed) * yScale, xScale)

        return ZStack {
            Circle().fill(cyan.opacity(0.16)).frame(width: 38, height: 38)
            Image(systemName: "car.side.fill")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.radians(Double(screenAngle)))
        }
        .shadow(color: cyan, radius: 7)
        .position(point)
    }

    private var speedLimitSign: some View {
        VStack(spacing: 0) {
            Text("LIMIT")
                .font(.system(size: 7, weight: .black, design: .monospaced))
            Text(format(stage.targetSpeed))
                .font(.system(size: 20, weight: .black, design: .monospaced))
            Text("m/s")
                .font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .foregroundStyle(.black.opacity(0.78))
        .frame(width: 58, height: 58)
        .background(.white)
        .clipShape(Circle())
        .overlay(Circle().stroke(coral, lineWidth: 5))
    }

    private var speedometer: some View {
        let fraction = min(1, max(0, speed / stage.maxSpeed))
        let needleAngle = -120 + fraction * 240

        return ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(cyan, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Capsule()
                .fill(gold)
                .frame(width: 3, height: 26)
                .offset(y: -11)
                .rotationEffect(.degrees(needleAngle))
            Circle().fill(gold).frame(width: 8, height: 8)
            Text(format(speed))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .offset(y: 19)
        }
        .frame(width: 66, height: 66)
        .accessibilityLabel("Speedometer reading \(format(speed)) meters per second")
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 11) {
            HStack(spacing: 12) {
                Text("t = \(format(time))")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)
                    .frame(width: 62, alignment: .leading)
                Slider(value: $time, in: 0...6, step: 0.1)
                    .tint(cyan)
                    .disabled(solved)
                    .onChange(of: time) { _, _ in feedback = nil }
                Text("s′(t) = \(format(speed)) m/s")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(gold)
                    .frame(minWidth: 145, alignment: .trailing)
            }

            if solved {
                Text("TANGENT SLOPE = INSTANTANEOUS RATE = \(format(stage.targetSpeed)) m/s")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)
            }

            Button {
                checkSpeed()
            } label: {
                Label("CHECK SPEEDOMETER", systemImage: "speedometer")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.76))
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 38 : 44)
                    .background(solved ? .white.opacity(0.16) : gold)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(solved)
        }
    }

    private func checkSpeed() {
        let difference = speed - stage.targetSpeed
        guard abs(difference) < 0.06 else {
            feedback = difference > 0 ? .tooFast : .tooSlow
            let token = animationToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                guard token == animationToken else { return }
                withAnimation { feedback = nil }
            }
            return
        }

        solved = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { feedback = .matched }
        let token = animationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard token == animationToken else { return }
            if stageIndex == stages.count - 1 {
                withAnimation { completed = true }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    stageIndex += 1
                    time = 1
                    feedback = nil
                    solved = false
                }
            }
        }
    }

    private func resetLevel() {
        animationToken = UUID()
        stageIndex = 0
        time = 1
        feedback = nil
        solved = false
        completed = false
    }

    private func drawGrid(context: inout GraphicsContext, plot: CGRect) {
        for tick in 0...6 {
            let x = plot.minX + CGFloat(tick) / 6 * plot.width
            var vertical = Path()
            vertical.move(to: CGPoint(x: x, y: plot.minY))
            vertical.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(vertical, with: .color(.white.opacity(tick == 0 ? 0.22 : 0.06)), lineWidth: tick == 0 ? 2 : 1)
            context.draw(Text("\(tick)").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.45)), at: CGPoint(x: x, y: plot.maxY + 13))
        }
        for tick in 0...5 {
            let value = Double(tick) / 5 * stage.yMax
            let y = graphPoint(t: 0, value: value, plot: plot).y
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: plot.minX, y: y))
            horizontal.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(horizontal, with: .color(.white.opacity(tick == 0 ? 0.22 : 0.06)), lineWidth: tick == 0 ? 2 : 1)
            context.draw(Text(format(value)).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.42)), at: CGPoint(x: plot.minX - 20, y: y))
        }
        context.draw(Text("time t").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.52)), at: CGPoint(x: plot.maxX - 20, y: plot.maxY + 28))
        context.draw(Text("distance s(t)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.52)), at: CGPoint(x: plot.minX + 20, y: plot.minY - 18))
    }

    private func drawDistanceCurve(context: inout GraphicsContext, plot: CGRect) {
        var curve = Path()
        for sample in 0...180 {
            let t = Double(sample) / 30
            let point = graphPoint(t: t, value: stage.profile.distance(at: t), plot: plot)
            sample == 0 ? curve.move(to: point) : curve.addLine(to: point)
        }
        context.stroke(curve, with: .color(gold.opacity(0.78)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }

    private func drawCurrentInstant(context: inout GraphicsContext, plot: CGRect) {
        let current = graphPoint(t: time, value: distance, plot: plot)
        var guide = Path()
        guide.move(to: CGPoint(x: current.x, y: plot.maxY))
        guide.addLine(to: current)
        context.stroke(guide, with: .color(.white.opacity(0.23)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))

        let leftT = max(0, time - 1.2)
        let rightT = min(6, time + 1.2)
        let leftY = distance + speed * (leftT - time)
        let rightY = distance + speed * (rightT - time)
        var tangent = Path()
        tangent.move(to: graphPoint(t: leftT, value: leftY, plot: plot))
        tangent.addLine(to: graphPoint(t: rightT, value: rightY, plot: plot))
        context.stroke(tangent, with: .color(cyan), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let direction = time <= 5 ? 1.0 : -1.0
        let endT = time + direction
        let baseline = graphPoint(t: endT, value: distance, plot: plot)
        let risePoint = graphPoint(t: endT, value: distance + speed * direction, plot: plot)
        var triangle = Path()
        triangle.move(to: current)
        triangle.addLine(to: baseline)
        triangle.addLine(to: risePoint)
        context.stroke(triangle, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        context.draw(Text("Δt = 1").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.6)), at: midpoint(current, baseline))
        context.draw(Text("Δs = \(format(abs(speed)))").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(cyan), at: midpoint(baseline, risePoint))
    }

    private func graphPoint(t: Double, value: Double, plot: CGRect) -> CGPoint {
        CGPoint(
            x: plot.minX + CGFloat(t / 6) * plot.width,
            y: plot.maxY - CGFloat(value / stage.yMax) * plot.height
        )
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func format(_ value: Double) -> String {
        let cleaned = abs(value) < 0.005 ? 0 : value
        return cleaned.rounded() == cleaned ? String(Int(cleaned)) : String(format: "%.2f", cleaned)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

private enum DistanceProfile {
    case accelerating
    case braking
    case rolling

    func distance(at t: Double) -> Double {
        switch self {
        case .accelerating: 0.5 * t * t
        case .braking: -0.25 * t * t + 3 * t
        case .rolling: t + (0.9 / .pi) * sin(.pi * t / 3)
        }
    }

    func speed(at t: Double) -> Double {
        switch self {
        case .accelerating: t
        case .braking: 3 - 0.5 * t
        case .rolling: 1 + 0.3 * cos(.pi * t / 3)
        }
    }
}

private struct InstantSpeedStage {
    let name: String
    let profile: DistanceProfile
    let targetSpeed: Double
    let yMax: Double
    let maxSpeed: Double

    static let all = [
        InstantSpeedStage(name: "Acceleration lane", profile: .accelerating, targetSpeed: 4, yMax: 19, maxSpeed: 6),
        InstantSpeedStage(name: "Braking zone", profile: .braking, targetSpeed: 1, yMax: 10, maxSpeed: 3),
        InstantSpeedStage(name: "Rolling parkway", profile: .rolling, targetSpeed: 0.7, yMax: 7, maxSpeed: 1.3)
    ]
}

private enum SpeedCheckFeedback {
    case tooFast
    case tooSlow
    case matched

    var message: String {
        switch self {
        case .tooFast: "TANGENT TOO STEEP · SCRUB TOWARD A LOWER SPEED"
        case .tooSlow: "TANGENT TOO SHALLOW · SCRUB TOWARD A HIGHER SPEED"
        case .matched: "TANGENT SLOPE MATCHES THE INSTANTANEOUS SPEED"
        }
    }

    var isMatch: Bool { self == .matched }
}

#Preview {
    MathItLevelOneHundredThirtyTwoView(onContinue: {}, onLevelSelect: {})
}
