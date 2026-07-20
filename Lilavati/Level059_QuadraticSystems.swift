import SwiftUI

struct MathItLevelOneHundredTwentyOneView: View {
    private let cyan = Color(red: 0.16, green: 0.82, blue: 0.86)
    private let amber = Color(red: 1.0, green: 0.66, blue: 0.16)
    private let coral = Color(red: 0.95, green: 0.28, blue: 0.24)
    private let ink = Color(red: 0.025, green: 0.035, blue: 0.045)

    private let arcHeight = 5.2
    private let cannonX = 4.5
    private let gunPoint = CGPoint(x: -6.05, y: 0.18)
    private let shotDuration = 0.48
    private let breakDuration = 1.25
    private let coordinateReadDuration = 2.0

    private let stages: [QuadraticInterceptStage] = [
        .init(blueOffset: 0, blueSpeed: 0.239, orangeOffset: 0, orangeSpeed: 0.296, aimSlope: 0.42),
        .init(blueOffset: 0, blueSpeed: 0.187, orangeOffset: 0, orangeSpeed: 0.256, aimSlope: 0.58),
        .init(blueOffset: 0, blueSpeed: 0.145, orangeOffset: 0, orangeSpeed: 0.223, aimSlope: 0.72)
    ]

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var animationEpoch = Date()
    @State private var aimSlope = 0.58
    @State private var stageIndex = 0
    @State private var hasLaunched = false
    @State private var frozenElapsed: Double?
    @State private var shotStart: Date?
    @State private var breakStart: Date?
    @State private var shotWasHit = false
    @State private var completed = false
    @State private var shotToken = UUID()

    private var stage: QuadraticInterceptStage { stages[stageIndex] }
    private var isShooting: Bool { shotStart != nil || breakStart != nil }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ink.ignoresSafeArea()

                trajectoryRange
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 18)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                HStack(spacing: 8) {
                    ForEach(stages.indices, id: \.self) { index in
                        Circle()
                            .fill(index < stageIndex ? cyan : index == stageIndex ? amber : .white.opacity(0.18))
                            .frame(width: index == stageIndex ? 11 : 7, height: index == stageIndex ? 11 : 7)
                    }
                }
                .position(x: proxy.size.width / 2, y: 28)

                Button(action: launchPair) {
                    ZStack {
                        HStack(spacing: 0) {
                            Rectangle().fill(cyan)
                            Rectangle().fill(amber)
                        }
                        .clipShape(Circle())

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(ink)
                    }
                    .frame(width: 60, height: 60)
                    .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1.5))
                    .shadow(color: cyan.opacity(0.28), radius: 12, x: -5)
                    .shadow(color: amber.opacity(0.28), radius: 12, x: 5)
                }
                .buttonStyle(.plain)
                .disabled(hasLaunched || isShooting)
                .opacity(hasLaunched ? 0.35 : 1)
                .accessibilityLabel("Launch both projectiles")
                .position(x: proxy.size.width / 2 - 40, y: proxy.size.height - 58)

                Button(action: fireGun) {
                    Image(systemName: isShooting ? "scope" : "flame.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(ink)
                        .frame(width: 60, height: 60)
                        .background(coral, in: Circle())
                        .shadow(color: coral.opacity(0.42), radius: 12)
                }
                .buttonStyle(.plain)
                .disabled(isShooting || !hasLaunched)
                .opacity(hasLaunched ? 1 : 0.35)
                .accessibilityLabel("Fire aiming gun")
                .position(x: proxy.size.width / 2 + 40, y: proxy.size.height - 58)

                CompletionOverlay(
                    title: "Quadratic Intercept Complete",
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

    private var trajectoryRange: some View {
        GeometryReader { geo in
            let plot = CGRect(x: 30, y: 52, width: geo.size.width - 60, height: geo.size.height - 116)

            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let elapsed = frozenElapsed ?? (hasLaunched ? max(0, timeline.date.timeIntervalSince(animationEpoch)) : 0)
                let blue = blueProjectile(at: elapsed)
                let orange = orangeProjectile(at: elapsed)
                let shotProgress = shotStart.map {
                    min(1, max(0, timeline.date.timeIntervalSince($0) / shotDuration))
                }
                let breakProgress = breakStart.map {
                    min(1, max(0, timeline.date.timeIntervalSince($0) / breakDuration))
                }

                    Canvas { context, size in
                    drawRange(context: &context, size: size, plot: plot)
                    drawCoordinatePlane(context: &context, plot: plot)
                    drawCommonParabola(context: &context, plot: plot)
                    drawAimLine(context: &context, plot: plot)
                    drawAimGuide(context: &context, plot: plot)
                    if let breakProgress {
                        drawBrokenProjectile(context: &context, plot: plot, projectile: blue, progress: breakProgress, color: cyan)
                        drawBrokenProjectile(context: &context, plot: plot, projectile: orange, progress: breakProgress, color: amber)
                        drawImpactCoordinates(context: &context, plot: plot, blue: blue, orange: orange)
                    } else {
                        drawProjectile(context: &context, plot: plot, projectile: blue, fromLeft: true, color: cyan)
                        drawProjectile(context: &context, plot: plot, projectile: orange, fromLeft: false, color: amber)
                    }
                    drawCannons(context: &context, plot: plot)
                    drawAimingGun(context: &context, plot: plot)

                    if let shotProgress {
                        drawGunShot(context: &context, plot: plot, progress: shotProgress)
                    }
                    }
                }

                Text("y = 5.2(1 - x² / 20.25)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .position(x: geo.size.width / 2, y: 24)
                    .accessibilityLabel("y equals 5 point 2 times 1 minus x squared divided by 20 point 25")

                VStack(spacing: 7) {
                    angleButton(systemName: "plus", delta: 0.04)
                    angleButton(systemName: "minus", delta: -0.04)
                }
                .position(
                    x: graphPoint(x: gunPoint.x, y: gunPoint.y, plot: plot).x + 9,
                    y: graphPoint(x: gunPoint.x, y: gunPoint.y, plot: plot).y - 88
                )
            }

            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.11)))
        }
    }

    private func drawRange(context: inout GraphicsContext, size: CGSize, plot: CGRect) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.055, green: 0.08, blue: 0.105)))

        let groundY = mapY(0, plot: plot)
        context.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)), with: .color(Color(red: 0.08, green: 0.10, blue: 0.105)))

        var horizon = Path()
        horizon.move(to: CGPoint(x: 0, y: groundY))
        horizon.addLine(to: CGPoint(x: size.width, y: groundY))
        context.stroke(horizon, with: .color(.white.opacity(0.24)), lineWidth: 2)
    }

    private func drawCoordinatePlane(context: inout GraphicsContext, plot: CGRect) {
        for x in -6...5 {
            let px = mapX(Double(x), plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: px, y: plot.minY))
            line.addLine(to: CGPoint(x: px, y: plot.maxY))
            context.stroke(line, with: .color(.white.opacity(x == 0 ? 0.36 : 0.07)), lineWidth: x == 0 ? 1.8 : 1)

            let tickY = mapY(0, plot: plot)
            var tick = Path()
            tick.move(to: CGPoint(x: px, y: tickY - 4))
            tick.addLine(to: CGPoint(x: px, y: tickY + 4))
            context.stroke(tick, with: .color(.white.opacity(0.5)), lineWidth: 1)
            context.draw(
                Text("\(x)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58)),
                at: CGPoint(x: px, y: tickY + 15)
            )
        }

        for y in 1...7 {
            let py = mapY(Double(y), plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: py))
            line.addLine(to: CGPoint(x: plot.maxX, y: py))
            context.stroke(line, with: .color(.white.opacity(0.07)), lineWidth: 1)

            let axisX = mapX(0, plot: plot)
            var tick = Path()
            tick.move(to: CGPoint(x: axisX - 4, y: py))
            tick.addLine(to: CGPoint(x: axisX + 4, y: py))
            context.stroke(tick, with: .color(.white.opacity(0.5)), lineWidth: 1)
            context.draw(
                Text("\(y)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.58)),
                at: CGPoint(x: axisX - 12, y: py)
            )
        }

        let xAxisY = mapY(0, plot: plot)
        let yAxisX = mapX(0, plot: plot)
        var axes = Path()
        axes.move(to: CGPoint(x: plot.minX, y: xAxisY))
        axes.addLine(to: CGPoint(x: plot.maxX + 7, y: xAxisY))
        axes.move(to: CGPoint(x: yAxisX, y: plot.maxY))
        axes.addLine(to: CGPoint(x: yAxisX, y: plot.minY - 7))
        context.stroke(axes, with: .color(.white.opacity(0.48)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

        var arrowheads = Path()
        arrowheads.move(to: CGPoint(x: plot.maxX + 7, y: xAxisY))
        arrowheads.addLine(to: CGPoint(x: plot.maxX, y: xAxisY - 4))
        arrowheads.move(to: CGPoint(x: plot.maxX + 7, y: xAxisY))
        arrowheads.addLine(to: CGPoint(x: plot.maxX, y: xAxisY + 4))
        arrowheads.move(to: CGPoint(x: yAxisX, y: plot.minY - 7))
        arrowheads.addLine(to: CGPoint(x: yAxisX - 4, y: plot.minY))
        arrowheads.move(to: CGPoint(x: yAxisX, y: plot.minY - 7))
        arrowheads.addLine(to: CGPoint(x: yAxisX + 4, y: plot.minY))
        context.stroke(arrowheads, with: .color(.white.opacity(0.62)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }

    private func drawImpactCoordinates(
        context: inout GraphicsContext,
        plot: CGRect,
        blue: ProjectilePoint,
        orange: ProjectilePoint
    ) {
        drawCoordinateReveal(context: &context, plot: plot, projectile: blue, color: cyan, labelAbove: true)
        drawCoordinateReveal(context: &context, plot: plot, projectile: orange, color: amber, labelAbove: false)
    }

    private func drawCoordinateReveal(
        context: inout GraphicsContext,
        plot: CGRect,
        projectile: ProjectilePoint,
        color: Color,
        labelAbove: Bool
    ) {
        let point = graphPoint(x: projectile.x, y: projectile.y, plot: plot)
        let xAxisPoint = graphPoint(x: projectile.x, y: 0, plot: plot)
        let yAxisPoint = graphPoint(x: 0, y: projectile.y, plot: plot)
        var projections = Path()
        projections.move(to: point)
        projections.addLine(to: xAxisPoint)
        projections.move(to: point)
        projections.addLine(to: yAxisPoint)
        context.stroke(
            projections,
            with: .color(color.opacity(0.72)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5])
        )

        let label = "(\(formattedCoordinate(projectile.x)), \(formattedCoordinate(projectile.y)))"
        let labelCenter = CGPoint(x: point.x, y: point.y + (labelAbove ? -34 : 34))
        let labelRect = CGRect(x: labelCenter.x - 44, y: labelCenter.y - 13, width: 88, height: 26)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 6), with: .color(Color.black.opacity(0.78)))
        context.stroke(Path(roundedRect: labelRect, cornerRadius: 6), with: .color(color.opacity(0.85)), lineWidth: 1.5)
        context.draw(
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white),
            at: labelCenter
        )
    }

    private func formattedCoordinate(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.001 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    private func drawCommonParabola(context: inout GraphicsContext, plot: CGRect) {
        var curve = Path()
        for step in 0...180 {
            let x = -cannonX + cannonX * 2 * Double(step) / 180
            let point = graphPoint(x: x, y: trajectoryY(x), plot: plot)
            if step == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
        }
        context.stroke(curve, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func drawAimLine(context: inout GraphicsContext, plot: CGRect) {
        let start = graphPoint(x: gunPoint.x, y: gunPoint.y, plot: plot)
        let endX = 5.15
        let endY = gunPoint.y + aimSlope * (endX - gunPoint.x)
        let end = graphPoint(x: endX, y: endY, plot: plot)
        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        context.stroke(
            line,
            with: .color(Color.red.opacity(0.88)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [2, 7])
        )
    }

    private func drawAimGuide(context: inout GraphicsContext, plot: CGRect) {
        let start = graphPoint(x: gunPoint.x, y: gunPoint.y, plot: plot)
        let endX = 5.15
        let endY = gunPoint.y + stage.aimSlope * (endX - gunPoint.x)
        let end = graphPoint(x: endX, y: endY, plot: plot)
        var guide = Path()
        guide.move(to: start)
        guide.addLine(to: end)
        context.stroke(
            guide,
            with: .color(.white.opacity(0.48)),
            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, dash: [2, 7])
        )
    }

    private func drawProjectile(
        context: inout GraphicsContext,
        plot: CGRect,
        projectile: ProjectilePoint,
        fromLeft: Bool,
        color: Color
    ) {
        var tail = Path()
        let tailLength = 0.085
        for step in 0...28 {
            let phaseOffset = tailLength * Double(step) / 28
            let phase = max(0, projectile.phase - phaseOffset)
            let x = fromLeft ? -cannonX + cannonX * 2 * phase : cannonX - cannonX * 2 * phase
            let point = graphPoint(x: x, y: trajectoryY(x), plot: plot)
            if step == 0 { tail.move(to: point) } else { tail.addLine(to: point) }
        }
        context.stroke(tail, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 8, lineCap: .round))

        let point = graphPoint(x: projectile.x, y: projectile.y, plot: plot)
        context.fill(Path(ellipseIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)), with: .color(.white))
        context.stroke(Path(ellipseIn: CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24)), with: .color(color.opacity(0.8)), lineWidth: 3)
    }

    private func drawBrokenProjectile(
        context: inout GraphicsContext,
        plot: CGRect,
        projectile: ProjectilePoint,
        progress: Double,
        color: Color
    ) {
        let origin = graphPoint(x: projectile.x, y: projectile.y, plot: plot)
        let p = CGFloat(progress)

        for direction in [-1.0, 1.0] {
            let sign = CGFloat(direction)
            let center = CGPoint(
                x: origin.x + sign * (5 + 28 * p),
                y: origin.y + 12 * p + 150 * p * p
            )
            let angle = sign * (0.35 + 4.2 * p)
            let vector = CGVector(dx: cos(angle) * 6, dy: sin(angle) * 6)
            var fragment = Path()
            fragment.move(to: CGPoint(x: center.x - vector.dx, y: center.y - vector.dy))
            fragment.addLine(to: CGPoint(x: center.x + vector.dx, y: center.y + vector.dy))
            context.stroke(fragment, with: .color(color.opacity(0.35)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
            context.stroke(fragment, with: .color(.white), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
    }

    private func drawGunShot(context: inout GraphicsContext, plot: CGRect, progress: Double) {
        let start = graphPoint(x: gunPoint.x, y: gunPoint.y, plot: plot)
        let endX = 5.15
        let endY = gunPoint.y + aimSlope * (endX - gunPoint.x)
        let end = graphPoint(x: endX, y: endY, plot: plot)

        var flash = Path()
        flash.move(to: start)
        flash.addLine(to: end)
        context.stroke(flash, with: .color(shotWasHit ? .white : coral.opacity(0.65)), style: StrokeStyle(lineWidth: shotWasHit ? 4 : 2, lineCap: .round))

        let pulse = CGPoint(
            x: start.x + (end.x - start.x) * CGFloat(progress),
            y: start.y + (end.y - start.y) * CGFloat(progress)
        )
        context.fill(Path(ellipseIn: CGRect(x: pulse.x - 6, y: pulse.y - 6, width: 12, height: 12)), with: .color(.white))
    }

    private func drawCannons(context: inout GraphicsContext, plot: CGRect) {
        drawCannon(context: &context, base: graphPoint(x: -cannonX, y: 0, plot: plot), pointsRight: true, color: cyan)
        drawCannon(context: &context, base: graphPoint(x: cannonX, y: 0, plot: plot), pointsRight: false, color: amber)
    }

    private func drawCannon(context: inout GraphicsContext, base: CGPoint, pointsRight: Bool, color: Color) {
        let direction: CGFloat = pointsRight ? 1 : -1
        context.fill(Path(ellipseIn: CGRect(x: base.x - 18, y: base.y - 12, width: 36, height: 24)), with: .color(Color(red: 0.20, green: 0.23, blue: 0.25)))

        var barrel = Path()
        barrel.move(to: CGPoint(x: base.x, y: base.y - 7))
        barrel.addLine(to: CGPoint(x: base.x + direction * 34, y: base.y - 31))
        context.stroke(barrel, with: .color(color), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: base.x - 8, y: base.y + 1, width: 16, height: 16)), with: .color(.black.opacity(0.85)))
    }

    private func drawAimingGun(context: inout GraphicsContext, plot: CGRect) {
        let base = graphPoint(x: gunPoint.x, y: gunPoint.y, plot: plot)
        let directionPoint = graphPoint(x: gunPoint.x + 1, y: gunPoint.y + aimSlope, plot: plot)
        let dx = directionPoint.x - base.x
        let dy = directionPoint.y - base.y
        let length = max(1, hypot(dx, dy))
        let tip = CGPoint(x: base.x + dx / length * 42, y: base.y + dy / length * 42)

        context.fill(Path(ellipseIn: CGRect(x: base.x - 15, y: base.y - 10, width: 30, height: 20)), with: .color(Color(red: 0.22, green: 0.24, blue: 0.25)))
        var barrel = Path()
        barrel.move(to: base)
        barrel.addLine(to: tip)
        context.stroke(barrel, with: .color(coral), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        context.stroke(barrel, with: .color(.white.opacity(0.38)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func angleButton(systemName: String, delta: Double) -> some View {
        Button {
            guard !isShooting else { return }
            aimSlope = min(1.28, max(0.08, aimSlope + delta))
            HapticPlayer.playLightTap()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(coral.opacity(0.82), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isShooting)
        .opacity(isShooting ? 0.35 : 1)
        .accessibilityLabel(delta > 0 ? "Increase gun angle" : "Decrease gun angle")
    }

    private func launchPair() {
        guard !hasLaunched, !isShooting else { return }
        animationEpoch = Date()
        frozenElapsed = nil
        hasLaunched = true
        HapticPlayer.playLightTap()
    }

    private func fireGun() {
        guard hasLaunched, !isShooting else { return }
        let elapsed = max(0, Date().timeIntervalSince(animationEpoch))
        let blue = blueProjectile(at: elapsed)
        let orange = orangeProjectile(at: elapsed)
        let hit = isOnAimLine(blue) && isOnAimLine(orange)
        let token = UUID()

        shotToken = token
        shotWasHit = hit
        frozenElapsed = elapsed
        shotStart = Date()
        HapticPlayer.playLightTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + shotDuration) {
            guard shotToken == token else { return }
            shotStart = nil
            guard hit else {
                shotWasHit = false
                frozenElapsed = nil
                animationEpoch = Date()
                hasLaunched = false
                return
            }

            HapticPlayer.playCompletionTap()
            breakStart = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + breakDuration + coordinateReadDuration) {
                guard shotToken == token else { return }
                advanceStage()
            }
        }
    }

    private func advanceStage() {
        if stageIndex == stages.count - 1 {
            completed = true
            breakStart = nil
        } else {
            stageIndex += 1
            loadStage()
        }
    }

    private func loadStage() {
        animationEpoch = Date()
        aimSlope = min(1.28, stage.aimSlope + 0.16)
        hasLaunched = false
        frozenElapsed = nil
        shotStart = nil
        breakStart = nil
        shotWasHit = false
    }

    private func isOnAimLine(_ projectile: ProjectilePoint) -> Bool {
        let expectedY = gunPoint.y + aimSlope * (projectile.x - gunPoint.x)
        let distance = abs(projectile.y - expectedY) / sqrt(1 + aimSlope * aimSlope)
        return projectile.x > gunPoint.x && distance <= 0.28
    }

    private func blueProjectile(at elapsed: Double) -> ProjectilePoint {
        let phase = positiveRemainder(stage.blueOffset + stage.blueSpeed * elapsed)
        let x = -cannonX + cannonX * 2 * phase
        return ProjectilePoint(x: x, y: trajectoryY(x), phase: phase)
    }

    private func orangeProjectile(at elapsed: Double) -> ProjectilePoint {
        let phase = positiveRemainder(stage.orangeOffset + stage.orangeSpeed * elapsed)
        let x = cannonX - cannonX * 2 * phase
        return ProjectilePoint(x: x, y: trajectoryY(x), phase: phase)
    }

    private func positiveRemainder(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }

    private func resetLevel() {
        shotToken = UUID()
        stageIndex = 0
        completed = false
        loadStage()
    }

    private func trajectoryY(_ x: Double) -> Double {
        max(0, arcHeight * (1 - x * x / (cannonX * cannonX)))
    }

    private func graphPoint(x: Double, y: Double, plot: CGRect) -> CGPoint {
        CGPoint(x: mapX(x, plot: plot), y: mapY(y, plot: plot))
    }

    private func mapX(_ x: Double, plot: CGRect) -> CGFloat {
        plot.minX + CGFloat((x + 6.3) / 11.5) * plot.width
    }

    private func mapY(_ y: Double, plot: CGRect) -> CGFloat {
        plot.maxY - CGFloat(y / 7.5) * plot.height
    }

}

private struct ProjectilePoint {
    let x: Double
    let y: Double
    let phase: Double
}

private struct QuadraticInterceptStage {
    let blueOffset: Double
    let blueSpeed: Double
    let orangeOffset: Double
    let orangeSpeed: Double
    let aimSlope: Double
}

#Preview {
    MathItLevelOneHundredTwentyOneView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 121) ?? 121)
}
