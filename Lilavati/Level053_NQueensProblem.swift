import SwiftUI

struct MathItLevelOneHundredSixteenView: View {
    private let stages = ComplexDroneStage.all
    private let cyan = Color(red: 0.18, green: 0.82, blue: 0.88)
    private let yellow = Color(red: 1.0, green: 0.74, blue: 0.20)
    private let coral = Color(red: 0.96, green: 0.30, blue: 0.27)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var legIndex = 0
    @State private var current = ComplexPoint(1, 0)
    @State private var selectedCommand: ComplexCommand?
    @State private var flightStart = ComplexPoint(1, 0)
    @State private var flightCommand = ComplexPoint(1, 0)
    @State private var flightProgress = 0.0
    @State private var isFlying = false
    @State private var wrongCommand = false
    @State private var routeComplete = false
    @State private var completed = false
    @State private var animationToken = UUID()

    private var stage: ComplexDroneStage { stages[stageIndex] }
    private var leg: ComplexDroneLeg { stage.legs[legIndex] }
    private var target: ComplexPoint { current * leg.correct.value }
    private var displayedVector: ComplexPoint {
        isFlying ? flightStart * flightCommand.fractionalPower(flightProgress) : current
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.025, green: 0.045, blue: 0.075).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 14) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    flightMap
                        .frame(maxWidth: 760)
                        .frame(height: max(330, min(480, proxy.size.height * 0.54)))

                    commandConsole(compact: compact)
                        .frame(maxWidth: 720)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 14 : 22)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 116 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear { current = stages[0].start }
    }

    private var header: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(stages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex ? cyan : index == stageIndex ? yellow : .white.opacity(0.13))
                        .frame(width: index == stageIndex ? 42 : 24, height: 5)
                }
            }

            Text(stage.name.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(yellow)

            Text(routeComplete ? "ROUTE LOCKED" : "z = \(current.formatted)   →   gate \(target.formatted)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(routeComplete ? cyan : .white)
                .minimumScaleFactor(0.68)
                .lineLimit(1)
        }
    }

    private var flightMap: some View {
        GeometryReader { geo in
            let size = geo.size
            let dronePoint = map(displayedVector, in: size)
            let droneAngle = displayedVector.angle * 180 / .pi

            ZStack {
                Canvas { context, canvasSize in
                    drawAirspace(in: &context, size: canvasSize)
                    drawMagnitudeRing(in: &context, size: canvasSize)
                    if let selectedCommand, !isFlying {
                        drawPreview(command: selectedCommand, in: &context, size: canvasSize)
                    }
                    if !routeComplete { drawGate(in: &context, size: canvasSize) }
                    drawVector(in: &context, size: canvasSize)
                }

                ZStack {
                    Circle()
                        .fill(Color(red: 0.08, green: 0.13, blue: 0.18))
                        .frame(width: 35, height: 35)
                        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.3))
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(wrongCommand ? coral : cyan)
                }
                .rotationEffect(.degrees(droneAngle + 90))
                .position(dronePoint)
                .shadow(color: (wrongCommand ? coral : cyan).opacity(0.8), radius: 12)

                VStack {
                    HStack {
                        mapMetric("MAGNITUDE", displayedVector.magnitudeText)
                        mapMetric("ANGLE", displayedVector.angleText)
                        Spacer()
                        mapMetric("GATE", "\(legIndex + 1)/\(stage.legs.count)")
                    }
                    Spacer()
                }
                .padding(13)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func commandConsole(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 11) {
            HStack(spacing: 8) {
                ForEach(leg.options) { command in
                    Button {
                        guard !isFlying else { return }
                        selectedCommand = command
                        wrongCommand = false
                    } label: {
                        VStack(spacing: 3) {
                            Text("× \(command.label)")
                                .font(.system(size: compact ? 17 : 20, weight: .black, design: .serif))
                            Text(command.effect)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: compact ? 52 : 60)
                        .background(selectedCommand?.id == command.id ? cyan.opacity(0.28) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(selectedCommand?.id == command.id ? cyan : .white.opacity(0.1), lineWidth: selectedCommand?.id == command.id ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isFlying || routeComplete)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    EmptyView()
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.38))
                    Text(equationText)
                        .font(.system(size: compact ? 12 : 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(wrongCommand ? coral : .white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Spacer()

                Button(action: applyCommand) {
                    Image(systemName: isFlying ? "antenna.radiowaves.left.and.right" : "paperplane.fill")
                        .font(.system(size: 18, weight: .black))
                        .frame(width: 62, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.025, green: 0.045, blue: 0.075))
                .background(selectedCommand == nil || routeComplete ? .white.opacity(0.18) : yellow, in: RoundedRectangle(cornerRadius: 6))
                .disabled(selectedCommand == nil || isFlying || routeComplete)
                .accessibilityLabel("Apply complex command")

                Button(action: resetStage) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 42, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.68))
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("Restart route")
            }
        }
        .padding(compact ? 11 : 14)
        .background(Color(red: 0.055, green: 0.08, blue: 0.11), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    private var equationText: String {
        guard let selectedCommand else { return "z' = z × ?" }
        return "(\(current.formatted)) × (\(selectedCommand.label)) = \((current * selectedCommand.value).formatted)"
    }

    private func mapMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 5))
    }

    private func drawAirspace(in context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.045, green: 0.085, blue: 0.13)))
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = mapScale(size)

        for value in -3...3 {
            var vertical = Path()
            vertical.move(to: CGPoint(x: center.x + CGFloat(value) * scale, y: 0))
            vertical.addLine(to: CGPoint(x: center.x + CGFloat(value) * scale, y: size.height))
            context.stroke(vertical, with: .color(.white.opacity(value == 0 ? 0.25 : 0.06)), lineWidth: value == 0 ? 1.5 : 1)

            var horizontal = Path()
            horizontal.move(to: CGPoint(x: 0, y: center.y - CGFloat(value) * scale))
            horizontal.addLine(to: CGPoint(x: size.width, y: center.y - CGFloat(value) * scale))
            context.stroke(horizontal, with: .color(.white.opacity(value == 0 ? 0.25 : 0.06)), lineWidth: value == 0 ? 1.5 : 1)
        }

        context.draw(Text("Re").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.45)), at: CGPoint(x: size.width - 22, y: center.y - 12))
        context.draw(Text("Im").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.45)), at: CGPoint(x: center.x + 16, y: 18))

        for ring in 1...3 {
            let radius = CGFloat(ring) * scale
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.035)), lineWidth: 1)
        }
    }

    private func drawMagnitudeRing(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = CGFloat(displayedVector.magnitude) * mapScale(size)
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(cyan.opacity(0.18)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 6]))
    }

    private func drawPreview(command: ComplexCommand, in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let endpoint = map(current * command.value, in: size)
        var preview = Path()
        preview.move(to: center)
        preview.addLine(to: endpoint)
        context.stroke(preview, with: .color(cyan.opacity(0.42)), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
        context.fill(Path(ellipseIn: CGRect(x: endpoint.x - 5, y: endpoint.y - 5, width: 10, height: 10)), with: .color(cyan.opacity(0.7)))
    }

    private func drawGate(in context: inout GraphicsContext, size: CGSize) {
        let point = map(target, in: size)
        for inset in [0.0, 5.0, 10.0] {
            let rect = CGRect(x: point.x - 21 + inset / 2, y: point.y - 27 + inset / 2, width: 42 - inset, height: 54 - inset)
            context.stroke(Path(ellipseIn: rect), with: .color(yellow.opacity(0.9 - inset * 0.04)), lineWidth: inset == 0 ? 4 : 1.5)
        }
        context.draw(Text(target.formatted).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(yellow), at: CGPoint(x: point.x, y: point.y + 38))
    }

    private func drawVector(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let endpoint = map(displayedVector, in: size)
        var vector = Path()
        vector.move(to: center)
        vector.addLine(to: endpoint)
        context.stroke(vector, with: .color((wrongCommand ? coral : cyan).opacity(0.82)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(.white))

        if isFlying {
            var trail = Path()
            for step in 0...32 {
                let p = flightStart * flightCommand.fractionalPower(flightProgress * Double(step) / 32)
                let mapped = map(p, in: size)
                if step == 0 { trail.move(to: mapped) } else { trail.addLine(to: mapped) }
            }
            context.stroke(trail, with: .color((wrongCommand ? coral : yellow).opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))
        }
    }

    private func map(_ point: ComplexPoint, in size: CGSize) -> CGPoint {
        let scale = mapScale(size)
        return CGPoint(x: size.width / 2 + CGFloat(point.real) * scale, y: size.height / 2 - CGFloat(point.imaginary) * scale)
    }

    private func mapScale(_ size: CGSize) -> CGFloat { min(size.width, size.height) * 0.132 }

    private func applyCommand() {
        guard let selectedCommand, !isFlying else { return }
        let correct = selectedCommand.id == leg.correct.id
        let token = UUID()
        animationToken = token
        flightStart = current
        flightCommand = selectedCommand.value
        flightProgress = 0
        isFlying = true
        wrongCommand = !correct

        let frames = correct ? 72 : 108
        for frame in 0...frames {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(frame) * 0.016) {
                guard animationToken == token else { return }
                if correct {
                    flightProgress = Double(frame) / Double(frames)
                } else if frame <= 58 {
                    flightProgress = Double(frame) / 58
                } else {
                    flightProgress = 1 - Double(frame - 58) / Double(frames - 58)
                }

                guard frame == frames else { return }
                isFlying = false
                if correct {
                    current = flightStart * flightCommand
                    wrongCommand = false
                    self.selectedCommand = nil
                    advanceLeg()
                } else {
                    flightProgress = 0
                    self.selectedCommand = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        guard animationToken == token else { return }
                        wrongCommand = false
                    }
                }
            }
        }
    }

    private func advanceLeg() {
        if legIndex < stage.legs.count - 1 {
            legIndex += 1
        } else {
            routeComplete = true
            let token = animationToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard animationToken == token else { return }
                if stageIndex == stages.count - 1 {
                    completed = true
                } else {
                    stageIndex += 1
                    legIndex = 0
                    current = stages[stageIndex].start
                    selectedCommand = nil
                    routeComplete = false
                    animationToken = UUID()
                }
            }
        }
    }

    private func resetStage() {
        animationToken = UUID()
        legIndex = 0
        current = stage.start
        selectedCommand = nil
        isFlying = false
        flightProgress = 0
        wrongCommand = false
        routeComplete = false
    }

    private func resetLevel() {
        completed = false
        stageIndex = 0
        resetStage()
    }
}

private struct ComplexPoint: Equatable {
    let real: Double
    let imaginary: Double

    init(_ real: Double, _ imaginary: Double) {
        self.real = real
        self.imaginary = imaginary
    }

    static func * (lhs: ComplexPoint, rhs: ComplexPoint) -> ComplexPoint {
        ComplexPoint(lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
                     lhs.real * rhs.imaginary + lhs.imaginary * rhs.real)
    }

    var magnitude: Double { hypot(real, imaginary) }
    var angle: Double { atan2(imaginary, real) }

    func fractionalPower(_ progress: Double) -> ComplexPoint {
        let radius = pow(max(0.0001, magnitude), progress)
        let theta = angle * progress
        return ComplexPoint(radius * cos(theta), radius * sin(theta))
    }

    var formatted: String {
        let r = clean(real)
        let i = clean(imaginary)
        if abs(imaginary) < 0.001 { return r }
        if abs(real) < 0.001 { return abs(imaginary - 1) < 0.001 ? "i" : abs(imaginary + 1) < 0.001 ? "−i" : "\(i)i" }
        return "\(r) \(imaginary < 0 ? "−" : "+") \(clean(abs(imaginary)))i"
    }

    var magnitudeText: String { clean(magnitude) }
    var angleText: String { "\(Int((angle * 180 / .pi).rounded()))°" }

    private func clean(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if abs(rounded.rounded() - rounded) < 0.001 { return String(Int(rounded.rounded())) }
        return String(format: "%.2f", rounded).replacingOccurrences(of: "0$", with: "", options: .regularExpression)
    }
}

private struct ComplexCommand: Identifiable {
    let id: String
    let label: String
    let effect: String
    let value: ComplexPoint
}

private struct ComplexDroneLeg {
    let correct: ComplexCommand
    let options: [ComplexCommand]
}

private struct ComplexDroneStage {
    let name: String
    let start: ComplexPoint
    let legs: [ComplexDroneLeg]

    static let i = ComplexCommand(id: "i", label: "i", effect: "+90°", value: ComplexPoint(0, 1))
    static let negativeI = ComplexCommand(id: "-i", label: "−i", effect: "−90°", value: ComplexPoint(0, -1))
    static let negativeOne = ComplexCommand(id: "-1", label: "−1", effect: "+180°", value: ComplexPoint(-1, 0))
    static let two = ComplexCommand(id: "2", label: "2", effect: "scale ×2", value: ComplexPoint(2, 0))
    static let half = ComplexCommand(id: ".5", label: "1/2", effect: "scale ×1/2", value: ComplexPoint(0.5, 0))
    static let twoI = ComplexCommand(id: "2i", label: "2i", effect: "+90° · ×2", value: ComplexPoint(0, 2))
    static let onePlusI = ComplexCommand(id: "1+i", label: "1+i", effect: "+45° · ×√2", value: ComplexPoint(1, 1))
    static let oneMinusI = ComplexCommand(id: "1-i", label: "1−i", effect: "−45° · ×√2", value: ComplexPoint(1, -1))
    static let positiveHalfI = ComplexCommand(id: "i/2", label: "i/2", effect: "+90° · ×1/2", value: ComplexPoint(0, 0.5))
    static let negativeHalfI = ComplexCommand(id: "-i/2", label: "−i/2", effect: "−90° · ×1/2", value: ComplexPoint(0, -0.5))

    static let all: [ComplexDroneStage] = [
        .init(
            name: "Sector 1 · Rotation",
            start: ComplexPoint(1, 0),
            legs: [
                .init(correct: i, options: [i, negativeI, negativeOne]),
                .init(correct: i, options: [negativeI, two, i])
            ]
        ),
        .init(
            name: "Sector 2 · Rotation + Scale",
            start: ComplexPoint(0.75, 0.75),
            legs: [
                .init(correct: twoI, options: [two, i, twoI]),
                .init(correct: half, options: [negativeI, half, two])
            ]
        ),
        .init(
            name: "Sector 3 · Complex Route",
            start: ComplexPoint(1, 1),
            legs: [
                .init(correct: onePlusI, options: [oneMinusI, two, onePlusI]),
                .init(correct: oneMinusI, options: [onePlusI, i, oneMinusI]),
                .init(correct: negativeHalfI, options: [positiveHalfI, half, negativeHalfI])
            ]
        )
    ]
}

#Preview {
    MathItLevelOneHundredSixteenView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 116) ?? 116)
}
