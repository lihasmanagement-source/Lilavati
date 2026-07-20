import SwiftUI
import Foundation

// MARK: - Level 4 · Paper Toss (three stages, increasing difficulty)
//
// Pull the bow to set launch power; a crumpled paper ball arcs toward a trash can.
//   Stage 1 — direct shot into the can
//   Stage 2 — bounce off a wall to reach a can you can't hit directly
//   Stage 3 — kick off an angled platform back across the launcher, off a vertical
//             platform, and into the can

struct Barrier {
    let a: CGPoint      // fractional endpoint
    let b: CGPoint
}

struct ProjectileStage {
    let can: CGPoint            // trash-can mouth centre (fractional)
    let barriers: [Barrier]
}

struct BounceInfo {
    let point: CGPoint
    let normal: CGVector        // unit surface normal (wall → ball)
    let incident: CGVector      // unit incoming direction
    let reflected: CGVector     // unit outgoing direction
}

struct PredictedFlight {
    let points: [CGPoint]
    let bounces: [BounceInfo]
}

@Observable
final class MathItLevelFourViewModel {
    let stages: [ProjectileStage] = [
        ProjectileStage(can: CGPoint(x: 0.20, y: 0.66), barriers: []),
        ProjectileStage(can: CGPoint(x: 0.70, y: 0.66),
                        barriers: [Barrier(a: CGPoint(x: 0.07, y: 0.26), b: CGPoint(x: 0.07, y: 0.72))]),
        // Solver-verified: must bounce off BOTH side walls (min 2 bounces; the
        // platform blocks any direct/short launch). Solving pull ≈ 120–135.
        ProjectileStage(can: CGPoint(x: 0.62, y: 0.70),
                        barriers: [
                            Barrier(a: CGPoint(x: 0.17, y: 0.30), b: CGPoint(x: 0.17, y: 0.66)), // left wall
                            Barrier(a: CGPoint(x: 0.85, y: 0.30), b: CGPoint(x: 0.85, y: 0.66)), // right wall
                            Barrier(a: CGPoint(x: 0.40, y: 0.60), b: CGPoint(x: 0.64, y: 0.60)), // horizontal blocker
                        ]),
    ]
    var stageIndex = 0

    var pullOffset: CGFloat = 0
    var isDragging = false
    var isFlying = false
    var completed = false
    var ballPosition = CGPoint.zero
    var spin: Double = 0
    var velocity = CGVector.zero
    var lastUpdateDate: Date?
    private var advancing = false

    private let gravity: CGFloat = 760
    private let launchPower: CGFloat = 5.1
    private let maximumPull: CGFloat = 150
    private let ballR: CGFloat = 13

    var currentStage: ProjectileStage { stages[min(stageIndex, stages.count - 1)] }
    var normalizedPull: CGFloat { min(max(pullOffset / maximumPull, 0), 1) }
    var isAdvancing: Bool { advancing }

    func dragBall(to location: CGPoint, anchor: CGPoint, rightBoundaryX: CGFloat?) {
        guard !isFlying, !completed, !advancing else { return }
        isDragging = true
        let boundaryLimitedPull = rightBoundaryX.map {
            max(0, $0 - anchor.x - ballR - 4)
        } ?? maximumPull
        let allowedPull = min(maximumPull, boundaryLimitedPull)
        pullOffset = min(max(location.x - anchor.x, 0), allowedPull)
        ballPosition = CGPoint(x: anchor.x + pullOffset, y: anchor.y)
    }

    func releaseBall(anchor: CGPoint) {
        guard isDragging, !isFlying, !completed, !advancing else { return }
        HapticPlayer.playLightTap()
        isDragging = false
        isFlying = true
        lastUpdateDate = nil
        accumulator = 0
        ballPosition = CGPoint(x: anchor.x + pullOffset, y: anchor.y)
        velocity = CGVector(dx: -pullOffset * launchPower, dy: -pullOffset * 1.35)
    }

    private var accumulator: Double = 0

    func updateProjectile(at date: Date, canMouth: CGRect, barriers: [(CGPoint, CGPoint)], bounds: CGSize) {
        guard isFlying, !completed, !advancing else {
            lastUpdateDate = date
            accumulator = 0
            return
        }
        guard let previousDate = lastUpdateDate else {
            lastUpdateDate = date
            return
        }
        let frame = min(max(date.timeIntervalSince(previousDate), 0), 1.0 / 30.0)
        lastUpdateDate = date

        // Fixed-timestep integration: identical behaviour on 60Hz and 120Hz screens.
        let fixed = 1.0 / 120.0
        accumulator += frame
        var iterations = 0
        while accumulator >= fixed && iterations < 24 {
            accumulator -= fixed
            iterations += 1
            if step(dt: fixed, canMouth: canMouth, barriers: barriers, bounds: bounds) {
                accumulator = 0
                return
            }
        }
    }

    /// One fixed physics step. Returns true if the shot ended (scored or reset).
    private func step(dt: Double, canMouth: CGRect, barriers: [(CGPoint, CGPoint)], bounds: CGSize) -> Bool {
        velocity.dy += gravity * CGFloat(dt)
        ballPosition.x += velocity.dx * CGFloat(dt)
        ballPosition.y += velocity.dy * CGFloat(dt)
        spin += Double(velocity.dx) * dt * 0.6

        let restitution: CGFloat = 0.82
        for (a, b) in barriers {
            let cp = closestPoint(ballPosition, a, b)
            let offx = ballPosition.x - cp.x, offy = ballPosition.y - cp.y
            let dist = hypot(offx, offy)
            guard dist <= ballR, dist > 0.001 else { continue }
            let nx = offx / dist, ny = offy / dist
            let vn = velocity.dx * nx + velocity.dy * ny
            guard vn < 0 else { continue }
            velocity.dx = (velocity.dx - 2 * vn * nx) * restitution
            velocity.dy = (velocity.dy - 2 * vn * ny) * restitution
            ballPosition = CGPoint(x: cp.x + nx * ballR, y: cp.y + ny * ballR)
            HapticPlayer.playLightTap()
        }

        if canMouth.contains(ballPosition) && velocity.dy > -10 {
            registerHit(at: CGPoint(x: canMouth.midX, y: canMouth.midY))
            return true
        }
        if ballPosition.x < -60 || ballPosition.x > bounds.width + 60
            || ballPosition.y > bounds.height + 80 || ballPosition.y < -110 {
            resetToAnchor()
            return true
        }
        return false
    }

    // Forward-simulates the same physics so the player can see the path and bounce angles.
    func predictedPath(anchor: CGPoint, barriers: [(CGPoint, CGPoint)], canMouth: CGRect, bounds: CGSize) -> PredictedFlight {
        guard isDragging, !isFlying, pullOffset > 4 else { return PredictedFlight(points: [], bounces: []) }
        var pos = CGPoint(x: anchor.x + pullOffset, y: anchor.y)
        var vel = CGVector(dx: -pullOffset * launchPower, dy: -pullOffset * 1.35)
        var pts: [CGPoint] = [pos]
        var bounces: [BounceInfo] = []
        let stepDt: CGFloat = 1.0 / 120.0
        let restitution: CGFloat = 0.82
        for step in 0..<900 {
            vel.dy += gravity * stepDt
            pos.x += vel.dx * stepDt
            pos.y += vel.dy * stepDt
            for (a, b) in barriers {
                let cp = closestPoint(pos, a, b)
                let ox = pos.x - cp.x, oy = pos.y - cp.y
                let d = hypot(ox, oy)
                guard d <= ballR, d > 0.001 else { continue }
                let nx = ox / d, ny = oy / d
                let vn = vel.dx * nx + vel.dy * ny
                guard vn < 0 else { continue }
                let inLen = max(hypot(vel.dx, vel.dy), 0.0001)
                let incident = CGVector(dx: vel.dx / inLen, dy: vel.dy / inLen)
                vel.dx = (vel.dx - 2 * vn * nx) * restitution
                vel.dy = (vel.dy - 2 * vn * ny) * restitution
                let outLen = max(hypot(vel.dx, vel.dy), 0.0001)
                let reflected = CGVector(dx: vel.dx / outLen, dy: vel.dy / outLen)
                let bp = CGPoint(x: cp.x + nx * ballR, y: cp.y + ny * ballR)
                bounces.append(BounceInfo(point: bp, normal: CGVector(dx: nx, dy: ny), incident: incident, reflected: reflected))
                pos = bp
            }
            if step % 3 == 0 { pts.append(pos) }
            if canMouth.contains(pos) && vel.dy > -10 { pts.append(pos); break }
            if pos.x < -60 || pos.x > bounds.width + 60 || pos.y > bounds.height + 80 || pos.y < -110 { break }
        }
        return PredictedFlight(points: pts, bounces: bounces)
    }

    private func closestPoint(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let abx = b.x - a.x, aby = b.y - a.y
        let len2 = abx * abx + aby * aby
        if len2 < 0.0001 { return a }
        var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2
        t = Swift.min(1, Swift.max(0, t))
        return CGPoint(x: a.x + abx * t, y: a.y + aby * t)
    }

    func resetToAnchor() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            pullOffset = 0
            isDragging = false
            isFlying = false
            ballPosition = .zero
            velocity = .zero
            spin = 0
            lastUpdateDate = nil
            accumulator = 0
        }
    }

    func resetCurrentStage() {
        guard !advancing else { return }
        HapticPlayer.playLightTap()
        completed = false
        resetToAnchor()
    }

    private func registerHit(at point: CGPoint) {
        if stageIndex == stages.count - 1 { complete(at: point) } else { advanceStage(at: point) }
    }

    private func advanceStage(at point: CGPoint) {
        advancing = true
        HapticPlayer.playCompletionTap()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            ballPosition = point
            isFlying = false
            isDragging = false
            velocity = .zero
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                self.stageIndex += 1
                self.pullOffset = 0
                self.ballPosition = .zero
                self.spin = 0
                self.lastUpdateDate = nil
            }
            self.advancing = false
        }
    }

    private func complete(at point: CGPoint) {
        HapticPlayer.playCompletionTap()
        velocity = .zero
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            ballPosition = point
            isFlying = false
            isDragging = false
            completed = true
        }
    }
}

struct MathItLevelFourView: View {
    var viewModel: MathItLevelFourViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let paperColor = Color(red: 0.93, green: 0.91, blue: 0.84)
    private let mouthW: CGFloat = 50
    private let mouthDepth: CGFloat = 26

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let size = proxy.size
                let W = size.width, H = size.height
                let anchor = CGPoint(x: W * 0.52, y: H * 0.48)
                let stage = viewModel.currentStage
                let canCenter = CGPoint(x: stage.can.x * W, y: stage.can.y * H)
                let canMouth = CGRect(x: canCenter.x - mouthW / 2, y: canCenter.y,
                                      width: mouthW, height: mouthDepth)
                let barriers: [(CGPoint, CGPoint)] = stage.barriers.map {
                    (CGPoint(x: $0.a.x * W, y: $0.a.y * H), CGPoint(x: $0.b.x * W, y: $0.b.y * H))
                }
                let rightBoundaryX = nearestRightWall(anchor: anchor, barriers: barriers)
                let ballPoint = currentBallPoint(anchor: anchor)

                ZStack {
                    Color.black.ignoresSafeArea()

                    HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                    // Launcher
                    Rectangle()
                        .fill(.white.opacity(0.72))
                        .frame(width: 2, height: H * 0.58)
                        .position(anchor)
                        .shadow(color: .white.opacity(0.35), radius: 12)

                    // Barriers (line-art platforms)
                    ForEach(Array(barriers.enumerated()), id: \.offset) { _, seg in
                        Path { p in p.move(to: seg.0); p.addLine(to: seg.1) }
                            .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .shadow(color: .white.opacity(0.25), radius: 6)
                    }

                    trashCan(center: canCenter)

                    if viewModel.isDragging {
                        aimingOverlay(anchor: anchor, barriers: barriers, canMouth: canMouth, size: size, ballPoint: ballPoint)
                    }

                    paperBall()
                        .position(ballPoint)
                        .gesture(
                            DragGesture(coordinateSpace: .named("levelFourStage"))
                                .onChanged { value in
                                    viewModel.dragBall(
                                        to: value.location,
                                        anchor: anchor,
                                        rightBoundaryX: rightBoundaryX
                                    )
                                }
                                .onEnded { _ in viewModel.releaseBall(anchor: anchor) }
                        )
                        .accessibilityLabel("Paper ball")

                    Button(action: viewModel.resetCurrentStage) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color.mathGold)
                            .frame(width: 46, height: 46)
                            .background(.black.opacity(0.76), in: Circle())
                            .overlay(Circle().stroke(Color.mathGold.opacity(0.58), lineWidth: 1.2))
                            .shadow(color: Color.mathGold.opacity(0.28), radius: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isAdvancing)
                    .opacity(viewModel.isAdvancing ? 0.36 : 1)
                    .position(x: W - 36, y: H - 100)
                    .accessibilityLabel("Reset current stage")
                    .zIndex(20)

                    if let concept = ConceptLibrary.concept(for: 4) {
                        ConceptCompletionOverlay(
                            levelTitle: "Projectile",
                            concept: concept,
                            isVisible: viewModel.completed,
                            onContinue: onContinue,
                            onReplay: onReplay,
                            onLevelSelect: onLevelSelect
                        )
                    }
                }
                .coordinateSpace(name: "levelFourStage")
                .onChange(of: timeline.date) { _, date in
                    viewModel.updateProjectile(at: date, canMouth: canMouth, barriers: barriers, bounds: size)
                }
            }
        }
    }

    @ViewBuilder
    private func aimingOverlay(anchor: CGPoint, barriers: [(CGPoint, CGPoint)], canMouth: CGRect, size: CGSize, ballPoint: CGPoint) -> some View {
        let flight = viewModel.predictedPath(anchor: anchor, barriers: barriers, canMouth: canMouth, bounds: size)
        TrajectoryPath(points: flight.points)
            .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
        ForEach(Array(flight.bounces.enumerated()), id: \.offset) { _, bounce in
            reflectionAngle(bounce)
        }
        BowStringView(anchor: anchor, ballPoint: ballPoint)
            .opacity(0.45 + viewModel.normalizedPull * 0.45)
        ProtractorView(anchor: anchor, degrees: pullAngleDegrees(), intensity: viewModel.normalizedPull)
    }

    // Angle of reflection off a platform (incidence = reflection, measured off the surface normal).
    private func reflectionAngle(_ b: BounceInfo) -> some View {
        let len: CGFloat = 32
        let p = b.point
        let inStart = CGPoint(x: p.x - b.incident.dx * len, y: p.y - b.incident.dy * len)
        let refEnd = CGPoint(x: p.x + b.reflected.dx * len, y: p.y + b.reflected.dy * len)
        let normEnd = CGPoint(x: p.x + b.normal.dx * len, y: p.y + b.normal.dy * len)
        let dot = max(-1, min(1, b.reflected.dx * b.normal.dx + b.reflected.dy * b.normal.dy))
        let angle = acos(dot) * 180 / .pi
        let labelDir = CGVector(dx: b.normal.dx + b.reflected.dx, dy: b.normal.dy + b.reflected.dy)
        let labelLen = max(hypot(labelDir.dx, labelDir.dy), 0.0001)
        let labelPos = CGPoint(x: p.x + labelDir.dx / labelLen * (len + 16),
                               y: p.y + labelDir.dy / labelLen * (len + 16))
        return ZStack {
            Path { path in path.move(to: p); path.addLine(to: normEnd) }
                .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            Path { path in path.move(to: inStart); path.addLine(to: p); path.addLine(to: refEnd) }
                .stroke(Color.cyan.opacity(0.85), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            Circle().fill(Color.cyan).frame(width: 5, height: 5).position(p)
            Text("\(Int(angle.rounded()))°")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .position(labelPos)
        }
        .allowsHitTesting(false)
    }

    private func paperBall() -> some View {
        ZStack {
            CrumpledPaperShape().fill(paperColor)
            CrumpledPaperShape().stroke(Color(white: 0.55), lineWidth: 0.8)
            PaperCreases().stroke(Color(white: 0.6).opacity(0.7), lineWidth: 0.8)
        }
        .frame(width: 28, height: 28)
        .rotationEffect(.degrees(viewModel.spin))
        .shadow(color: .black.opacity(0.5), radius: 4)
    }

    // Sleek, minimal line-art bin matching the level's white-on-black aesthetic.
    private func trashCan(center: CGPoint) -> some View {
        let h: CGFloat = 54
        let topW = mouthW
        let baseW = mouthW * 0.74
        let bodyPath = Path { p in
            p.move(to: CGPoint(x: center.x - topW / 2, y: center.y))
            p.addLine(to: CGPoint(x: center.x - baseW / 2, y: center.y + h))
            p.addLine(to: CGPoint(x: center.x + baseW / 2, y: center.y + h))
            p.addLine(to: CGPoint(x: center.x + topW / 2, y: center.y))
        }
        return ZStack {
            bodyPath.fill(.white.opacity(0.04))
            bodyPath.stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            // rim
            Capsule()
                .stroke(.white.opacity(0.85), lineWidth: 2.5)
                .frame(width: topW + 8, height: 9)
                .position(x: center.x, y: center.y)
                .shadow(color: .white.opacity(0.3), radius: 6)
        }
    }

    private func currentBallPoint(anchor: CGPoint) -> CGPoint {
        if viewModel.isFlying || viewModel.completed || viewModel.isAdvancing {
            return viewModel.ballPosition
        }
        return CGPoint(x: anchor.x + viewModel.pullOffset, y: anchor.y)
    }

    private func nearestRightWall(
        anchor: CGPoint,
        barriers: [(CGPoint, CGPoint)]
    ) -> CGFloat? {
        barriers.compactMap { start, end -> CGFloat? in
            guard abs(start.x - end.x) < 1,
                  start.x > anchor.x,
                  anchor.y >= min(start.y, end.y),
                  anchor.y <= max(start.y, end.y) else {
                return nil
            }
            return start.x
        }
        .min()
    }

    private func pullAngleDegrees() -> Double {
        180 - Double(viewModel.normalizedPull * 120)
    }
}

// MARK: - Shapes

private struct TrajectoryPath: Shape {
    let points: [CGPoint]
    func path(in _: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for pt in points.dropFirst() { p.addLine(to: pt) }
        return p
    }
}

private struct CrumpledPaperShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let radii: [CGFloat] = [1.0, 0.72, 0.96, 0.66, 1.0, 0.74, 0.9, 0.68, 1.0, 0.71, 0.94, 0.67]
        var path = Path()
        for (i, rf) in radii.enumerated() {
            let a = Double(i) / Double(radii.count) * 2 * .pi
            let p = CGPoint(x: c.x + CGFloat(cos(a)) * r * rf, y: c.y + CGFloat(sin(a)) * r * rf)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

private struct PaperCreases: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: c.y - 3)); path.addLine(to: c); path.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.minY + 6))
        path.move(to: c); path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.maxY - 6))
        path.move(to: c); path.addLine(to: CGPoint(x: rect.minX + 6, y: rect.maxY - 4))
        return path
    }
}

private struct BowStringView: View {
    let anchor: CGPoint
    let ballPoint: CGPoint

    var body: some View {
        Path { path in
            let upperPoint = CGPoint(x: anchor.x, y: anchor.y - 92)
            let lowerPoint = CGPoint(x: anchor.x, y: anchor.y + 92)
            path.move(to: upperPoint)
            path.addLine(to: ballPoint)
            path.addLine(to: lowerPoint)
        }
        .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .shadow(color: .white.opacity(0.35), radius: 10)
    }
}

private struct ProtractorView: View {
    let anchor: CGPoint
    let degrees: Double
    let intensity: CGFloat

    var body: some View {
        let arcDegrees = 180 - degrees

        ZStack {
            Path { path in
                path.addArc(center: anchor, radius: 58, startAngle: .degrees(0),
                            endAngle: .degrees(-arcDegrees), clockwise: true)
            }
            .stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            Path { path in
                for tick in stride(from: 0.0, through: min(arcDegrees, 120), by: 10) {
                    let angle = CGFloat(-tick * .pi / 180)
                    let innerRadius: CGFloat = tick.truncatingRemainder(dividingBy: 20) == 0 ? 48 : 52
                    let outerRadius: CGFloat = 58
                    let inner = CGPoint(x: anchor.x + CGFloat(cos(angle)) * innerRadius,
                                        y: anchor.y + CGFloat(sin(angle)) * innerRadius)
                    let outer = CGPoint(x: anchor.x + CGFloat(cos(angle)) * outerRadius,
                                        y: anchor.y + CGFloat(sin(angle)) * outerRadius)
                    path.move(to: inner)
                    path.addLine(to: outer)
                }
            }
            .stroke(.white.opacity(0.42), style: StrokeStyle(lineWidth: 1, lineCap: .round))

            Text("\(Int(degrees.rounded()))°")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58 + Double(intensity) * 0.34))
                .position(x: anchor.x + 76, y: anchor.y - 42)
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: degrees)
    }
}
