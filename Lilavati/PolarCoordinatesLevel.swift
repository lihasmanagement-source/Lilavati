import SwiftUI

struct MathItLevelOneHundredTwentyEightView: View {
    private let stages = PolarRadarStage.all
    private let cyan = Color(red: 0.20, green: 0.86, blue: 0.72)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)
    private let maxRange = 5.0

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var range = 1.0
    @State private var angle = 0.0
    @State private var placedTargets: Set<Int> = []
    @State private var missedPoint: PolarPoint?
    @State private var feedback: RadarFeedback?
    @State private var completed = false
    @State private var animationToken = UUID()

    private var stage: PolarRadarStage { stages[stageIndex] }
    private var activeTargetIndex: Int { stage.targets.indices.first { !placedTargets.contains($0) } ?? 0 }
    private var activeTarget: PolarPoint { stage.targets[activeTargetIndex] }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.014, green: 0.032, blue: 0.038).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    radarScope
                        .frame(maxWidth: 900)
                        .frame(height: max(410, min(535, proxy.size.height * 0.62)))

                    controls(compact: compact)
                        .frame(maxWidth: 780)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Storm Radar Calibrated",
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
                .foregroundStyle(feedback == .locked ? cyan : .white)
        }
    }

    private var radarScope: some View {
        GeometryReader { geo in
            let geometry = scopeGeometry(size: geo.size)

            TimelineView(.animation) { timeline in
                let pulse = CGFloat((sin(timeline.date.timeIntervalSinceReferenceDate * 3.2) + 1) / 2)

                ZStack {
                    Canvas { context, _ in
                        drawWeatherMap(context: &context, geometry: geometry)
                        drawPolarGrid(context: &context, geometry: geometry)
                        drawSweepArm(context: &context, geometry: geometry)
                        drawForecastTargets(context: &context, geometry: geometry, pulse: pulse)
                        drawPlacedCells(context: &context, geometry: geometry)
                        drawAttempt(context: &context, geometry: geometry)
                    }

                    Circle()
                        .fill(.clear)
                        .frame(width: geometry.radius * 2, height: geometry.radius * 2)
                        .contentShape(Circle())
                        .position(geometry.center)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { updateFromRadar(location: $0.location, geometry: geometry) }
                        )

                    VStack {
                        HStack {
                            metric("FORECAST CELL", "(\(format(activeTarget.r)), \(Int(activeTarget.theta))°)")
                            metric("LOCKED", "\(placedTargets.count) / \(stage.targets.count)")
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(12)

                    stationMarker(at: geometry.center)
                }
            }
            .background(Color(red: 0.025, green: 0.070, blue: 0.075))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func stationMarker(at point: CGPoint) -> some View {
        ZStack {
            Circle().fill(Color(red: 0.02, green: 0.04, blue: 0.05)).frame(width: 34, height: 34)
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(cyan)
        }
        .position(point)
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            HStack(spacing: 16) {
                controlReadout(label: "RANGE r", value: "\(format(range)) units", color: cyan)
                Slider(value: $range, in: 0.5...maxRange, step: 0.5)
                    .tint(cyan)
                    .disabled(feedback == .locked)

                controlReadout(label: "BEARING θ", value: "\(Int(angle))°", color: gold)
                Slider(value: $angle, in: 0...345, step: 15)
                    .tint(gold)
                    .disabled(feedback == .locked)
            }

            HStack(spacing: 12) {
                Text("x = \(format(cartesian.x))")
                Text("y = \(format(cartesian.y))")
                Text("x = r cos θ")
                Text("y = r sin θ")
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.58))

            Button {
                lockStormCell()
            } label: {
                Label(feedback == .missed ? "RECALIBRATE" : "LOCK STORM CELL", systemImage: feedback == .missed ? "arrow.counterclockwise" : "scope")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.76))
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 38 : 44)
                    .background(feedback == .missed ? coral : gold)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(feedback == .locked)
        }
    }

    private func controlReadout(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .frame(minWidth: 74, alignment: .leading)
        }
    }

    private var cartesian: (x: Double, y: Double) {
        let radians = angle * .pi / 180
        return (clean(range * cos(radians)), clean(range * sin(radians)))
    }

    private func lockStormCell() {
        if feedback == .missed {
            withAnimation { feedback = nil; missedPoint = nil }
            return
        }

        let angularError = min(abs(angle - activeTarget.theta), 360 - abs(angle - activeTarget.theta))
        guard abs(range - activeTarget.r) < 0.26, angularError < 7.6 else {
            missedPoint = PolarPoint(r: range, theta: angle)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { feedback = .missed }
            return
        }

        let targetIndex = activeTargetIndex
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
            placedTargets.insert(targetIndex)
            feedback = .locked
            missedPoint = nil
        }

        let token = animationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard token == animationToken else { return }
            if placedTargets.count == stage.targets.count {
                finishStage()
            } else {
                withAnimation {
                    feedback = nil
                    range = 1
                    angle = 0
                }
            }
        }
    }

    private func finishStage() {
        let token = animationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard token == animationToken else { return }
            if stageIndex == stages.count - 1 {
                withAnimation { completed = true }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    stageIndex += 1
                    placedTargets = []
                    feedback = nil
                    missedPoint = nil
                    range = 1
                    angle = 0
                }
            }
        }
    }

    private func resetLevel() {
        animationToken = UUID()
        stageIndex = 0
        range = 1
        angle = 0
        placedTargets = []
        missedPoint = nil
        feedback = nil
        completed = false
    }

    private func updateFromRadar(location: CGPoint, geometry: RadarScopeGeometry) {
        guard feedback != .locked else { return }
        let dx = location.x - geometry.center.x
        let dy = geometry.center.y - location.y
        let normalizedRange = Double(hypot(dx, dy) / geometry.radius)
        let rawRange = min(maxRange, normalizedRange * maxRange)
        let rawAngle = Double(atan2(dy, dx)) * 180 / .pi
        range = max(0.5, (rawRange * 2).rounded() / 2)
        angle = (rawAngle < 0 ? rawAngle + 360 : rawAngle) / 15
        angle = angle.rounded() * 15
        if angle >= 360 { angle = 0 }
        feedback = nil
        missedPoint = nil
    }

    private func scopeGeometry(size: CGSize) -> RadarScopeGeometry {
        let radius = min(size.width * 0.37, size.height * 0.39)
        return RadarScopeGeometry(center: CGPoint(x: size.width / 2, y: size.height / 2 + 18), radius: radius)
    }

    private func radarPoint(_ point: PolarPoint, geometry: RadarScopeGeometry) -> CGPoint {
        let radians = CGFloat(point.theta * .pi / 180)
        let scaledRadius = CGFloat(point.r / maxRange) * geometry.radius
        return CGPoint(
            x: geometry.center.x + cos(radians) * scaledRadius,
            y: geometry.center.y - sin(radians) * scaledRadius
        )
    }

    private func drawPolarGrid(context: inout GraphicsContext, geometry: RadarScopeGeometry) {
        for ring in 1...5 {
            let radius = geometry.radius * CGFloat(ring) / 5
            let rect = CGRect(x: geometry.center.x - radius, y: geometry.center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(ring == 5 ? 0.35 : 0.14)), lineWidth: ring == 5 ? 2 : 1)
            context.draw(Text("\(ring)").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.42)), at: CGPoint(x: geometry.center.x + radius - 7, y: geometry.center.y + 10))
        }

        for degrees in stride(from: 0, to: 360, by: 30) {
            let radians = Double(degrees) * .pi / 180
            let end = CGPoint(x: geometry.center.x + cos(radians) * geometry.radius, y: geometry.center.y - sin(radians) * geometry.radius)
            var spoke = Path()
            spoke.move(to: geometry.center)
            spoke.addLine(to: end)
            context.stroke(spoke, with: .color(.white.opacity(degrees.isMultiple(of: 90) ? 0.22 : 0.09)), lineWidth: 1)
            let label = CGPoint(x: geometry.center.x + cos(radians) * (geometry.radius + 17), y: geometry.center.y - sin(radians) * (geometry.radius + 17))
            context.draw(Text("\(degrees)°").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.5)), at: label)
        }
    }

    private func drawSweepArm(context: inout GraphicsContext, geometry: RadarScopeGeometry) {
        let point = radarPoint(PolarPoint(r: maxRange, theta: angle), geometry: geometry)
        let lower = radarPoint(PolarPoint(r: maxRange, theta: angle - 7), geometry: geometry)
        let upper = radarPoint(PolarPoint(r: maxRange, theta: angle + 7), geometry: geometry)
        var sector = Path()
        sector.move(to: geometry.center)
        sector.addLine(to: lower)
        sector.addLine(to: upper)
        sector.closeSubpath()
        context.fill(sector, with: .color(cyan.opacity(0.10)))

        var arm = Path()
        arm.move(to: geometry.center)
        arm.addLine(to: point)
        context.stroke(arm, with: .color(cyan), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let cursor = radarPoint(PolarPoint(r: range, theta: angle), geometry: geometry)
        context.fill(Path(ellipseIn: CGRect(x: cursor.x - 7, y: cursor.y - 7, width: 14, height: 14)), with: .color(.white))
        context.stroke(Path(ellipseIn: CGRect(x: cursor.x - 11, y: cursor.y - 11, width: 22, height: 22)), with: .color(cyan), lineWidth: 2)
    }

    private func drawForecastTargets(context: inout GraphicsContext, geometry: RadarScopeGeometry, pulse: CGFloat) {
        for index in stage.targets.indices where !placedTargets.contains(index) {
            let target = stage.targets[index]
            let point = radarPoint(target, geometry: geometry)
            let isActive = index == activeTargetIndex
            let radius: CGFloat = isActive ? 15 + pulse * 5 : 11
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(isActive ? gold : .white.opacity(0.35)), style: StrokeStyle(lineWidth: isActive ? 3 : 1.5, dash: [4, 3]))
            context.draw(Text("(\(format(target.r)), \(Int(target.theta))°)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(isActive ? gold : .white.opacity(0.55)), at: CGPoint(x: point.x, y: point.y - radius - 10))
        }
    }

    private func drawPlacedCells(context: inout GraphicsContext, geometry: RadarScopeGeometry) {
        for index in placedTargets {
            drawStormSymbol(context: &context, at: radarPoint(stage.targets[index], geometry: geometry), color: cyan)
        }
    }

    private func drawAttempt(context: inout GraphicsContext, geometry: RadarScopeGeometry) {
        guard let missedPoint else { return }
        let point = radarPoint(missedPoint, geometry: geometry)
        drawStormSymbol(context: &context, at: point, color: coral)
        var correction = Path()
        correction.move(to: point)
        correction.addLine(to: radarPoint(activeTarget, geometry: geometry))
        context.stroke(correction, with: .color(coral.opacity(0.65)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
    }

    private func drawStormSymbol(context: inout GraphicsContext, at point: CGPoint, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: point.x - 13, y: point.y - 5, width: 26, height: 14)), with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: point.x - 8, y: point.y - 12, width: 14, height: 14)), with: .color(color))
        for offset in [-7.0, 0.0, 7.0] {
            var rain = Path()
            rain.move(to: CGPoint(x: point.x + offset, y: point.y + 10))
            rain.addLine(to: CGPoint(x: point.x + offset - 3, y: point.y + 16))
            context.stroke(rain, with: .color(color.opacity(0.8)), lineWidth: 2)
        }
    }

    private func drawWeatherMap(context: inout GraphicsContext, geometry: RadarScopeGeometry) {
        var river = Path()
        river.move(to: CGPoint(x: geometry.center.x - geometry.radius * 0.9, y: geometry.center.y - geometry.radius * 0.25))
        river.addCurve(to: CGPoint(x: geometry.center.x + geometry.radius * 0.85, y: geometry.center.y + geometry.radius * 0.35), control1: CGPoint(x: geometry.center.x - geometry.radius * 0.25, y: geometry.center.y - geometry.radius * 0.85), control2: CGPoint(x: geometry.center.x + geometry.radius * 0.15, y: geometry.center.y + geometry.radius * 0.85))
        context.stroke(river, with: .color(Color.blue.opacity(0.15)), lineWidth: 8)

        var county = Path()
        county.move(to: CGPoint(x: geometry.center.x - geometry.radius * 0.65, y: geometry.center.y + geometry.radius * 0.55))
        county.addLine(to: CGPoint(x: geometry.center.x - geometry.radius * 0.2, y: geometry.center.y + geometry.radius * 0.2))
        county.addLine(to: CGPoint(x: geometry.center.x + geometry.radius * 0.55, y: geometry.center.y + geometry.radius * 0.65))
        context.stroke(county, with: .color(gold.opacity(0.10)), lineWidth: 2)
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

    private func clean(_ value: Double) -> Double {
        abs(value) < 0.005 ? 0 : value
    }

    private func format(_ value: Double) -> String {
        let cleaned = clean(value)
        return cleaned.rounded() == cleaned ? String(Int(cleaned)) : String(format: "%.2f", cleaned)
    }
}

private struct PolarPoint {
    let r: Double
    let theta: Double
}

private struct PolarRadarStage {
    let name: String
    let targets: [PolarPoint]

    static let all = [
        PolarRadarStage(name: "Local bearing", targets: [PolarPoint(r: 3, theta: 30)]),
        PolarRadarStage(name: "Regional cells", targets: [PolarPoint(r: 2, theta: 120), PolarPoint(r: 4, theta: 225)]),
        PolarRadarStage(name: "Storm front", targets: [PolarPoint(r: 1.5, theta: 330), PolarPoint(r: 3.5, theta: 150), PolarPoint(r: 4.5, theta: 60)])
    ]
}

private struct RadarScopeGeometry {
    let center: CGPoint
    let radius: CGFloat
}

private enum RadarFeedback {
    case missed
    case locked
}

#Preview {
    MathItLevelOneHundredTwentyEightView(onContinue: {}, onLevelSelect: {})
}
