import SwiftUI

@Observable
final class MathItLevelThirtyNineViewModel {
    let majorSegments = 36
    let minorSegments = 16

    var yaw: CGFloat = 0
    var pitch: CGFloat = -0.42
    var lastDragTranslation = CGSize.zero
    var yawVelocity: CGFloat = 0
    var pitchVelocity: CGFloat = 0
    var ballU: CGFloat = 0
    var ballV: CGFloat = .pi / 2
    var ballUVelocity: CGFloat = 0
    var ballVVelocity: CGFloat = 0
    var paintedCells: Set<Int> = []
    var completed = false
    private var lastFrameDate: Date?

    var totalCells: Int {
        majorSegments * minorSegments
    }

    var progress: Double {
        completed ? 1 : Double(paintedCells.count) / Double(totalCells)
    }

    func updateRotation(_ translation: CGSize) {
        let delta = CGSize(
            width: translation.width - lastDragTranslation.width,
            height: translation.height - lastDragTranslation.height
        )
        lastDragTranslation = translation
        yaw += delta.width * 0.012
        pitch = wrappedSigned(pitch - delta.height * 0.009)
        yawVelocity = delta.width * 0.46
        pitchVelocity = -delta.height * 0.34
    }

    func finishRotation() {
        lastDragTranslation = .zero
    }

    func step(at date: Date) {
        guard !completed else { return }
        guard let lastFrameDate else {
            self.lastFrameDate = date
            paintAroundBall()
            return
        }
        let dt = min(CGFloat(date.timeIntervalSince(lastFrameDate)), 1 / 30)
        self.lastFrameDate = date
        guard dt > 0 else { return }

        yaw += yawVelocity * dt
        pitch = wrappedSigned(pitch + pitchVelocity * dt)

        let majorRadius: CGFloat = 1.34
        let minorRadius: CGFloat = 0.52
        let tangentU = normalize(rotate(
            LevelThirtyNineVector3(
                x: -(majorRadius + minorRadius * cos(ballV)) * sin(ballU),
                y: 0,
                z: (majorRadius + minorRadius * cos(ballV)) * cos(ballU)
            ),
            yaw: yaw,
            pitch: pitch
        ))
        let tangentV = normalize(rotate(
            LevelThirtyNineVector3(
                x: -minorRadius * sin(ballV) * cos(ballU),
                y: minorRadius * cos(ballV),
                z: -minorRadius * sin(ballV) * sin(ballU)
            ),
            yaw: yaw,
            pitch: pitch
        ))
        let gravity = LevelThirtyNineVector3(x: 0, y: -1, z: 0)
        let uMetric = max(0.28, majorRadius + minorRadius * cos(ballV))
        let vMetric = minorRadius
        let rollingForce: CGFloat = 5.1

        ballUVelocity += dot(gravity, tangentU) / uMetric * rollingForce * dt
        ballVVelocity += dot(gravity, tangentV) / vMetric * rollingForce * dt

        // Surface friction carries the ball during a flip before gravity settles it downhill.
        let surfaceCoupling = min(1, dt * 8.5)
        ballUVelocity += (-yawVelocity * 0.3 - ballUVelocity) * surfaceCoupling * 0.16
        ballVVelocity += (-pitchVelocity * 0.44 - ballVVelocity) * surfaceCoupling * 0.24

        let ballDamping = pow(0.955, dt * 60)
        ballUVelocity *= ballDamping
        ballVVelocity *= ballDamping
        ballUVelocity = min(4.8, max(-4.8, ballUVelocity))
        ballVVelocity = min(5.4, max(-5.4, ballVVelocity))
        yawVelocity *= pow(0.91, dt * 60)
        pitchVelocity *= pow(0.88, dt * 60)

        let previousU = ballU
        let previousV = ballV
        ballU = wrapped(ballU + ballUVelocity * dt)
        ballV = wrapped(ballV + ballVVelocity * dt)
        paintSegment(fromU: previousU, fromV: previousV, toU: ballU, toV: ballV)
    }

    func isPainted(major: Int, minor: Int) -> Bool {
        paintedCells.contains(cellID(major: major, minor: minor))
    }

    private func paintAroundBall() {
        paint(atU: ballU, v: ballV)
    }

    private func paintSegment(fromU: CGFloat, fromV: CGFloat, toU: CGFloat, toV: CGFloat) {
        let deltaU = shortestAngularDelta(from: fromU, to: toU)
        let deltaV = shortestAngularDelta(from: fromV, to: toV)
        let steps = max(1, Int(max(abs(deltaU) * CGFloat(majorSegments), abs(deltaV) * CGFloat(minorSegments)) / 2))

        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            paint(atU: fromU + deltaU * progress, v: fromV + deltaV * progress)
        }
    }

    private func paint(atU u: CGFloat, v: CGFloat) {
        let major = Int((wrapped(u) / (.pi * 2)) * CGFloat(majorSegments)) % majorSegments
        let minor = Int((wrapped(v) / (.pi * 2)) * CGFloat(minorSegments)) % minorSegments

        for majorOffset in -1...1 {
            for minorOffset in -1...1 {
                let paintedMajor = positiveModulo(major + majorOffset, majorSegments)
                let paintedMinor = positiveModulo(minor + minorOffset, minorSegments)
                paintedCells.insert(cellID(major: paintedMajor, minor: paintedMinor))
            }
        }

        if paintedCells.count >= totalCells, !completed {
            HapticPlayer.playCompletionTap()
            completed = true
        }
    }

    private func shortestAngularDelta(from start: CGFloat, to end: CGFloat) -> CGFloat {
        let fullTurn = CGFloat.pi * 2
        var delta = (end - start).truncatingRemainder(dividingBy: fullTurn)
        if delta > .pi { delta -= fullTurn }
        if delta < -.pi { delta += fullTurn }
        return delta
    }

    private func cellID(major: Int, minor: Int) -> Int {
        major * minorSegments + minor
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let result = value % divisor
        return result >= 0 ? result : result + divisor
    }

    private func wrapped(_ value: CGFloat) -> CGFloat {
        let fullTurn = CGFloat.pi * 2
        let result = value.truncatingRemainder(dividingBy: fullTurn)
        return result >= 0 ? result : result + fullTurn
    }

    private func wrappedSigned(_ value: CGFloat) -> CGFloat {
        let fullTurn = CGFloat.pi * 2
        var result = value.truncatingRemainder(dividingBy: fullTurn)
        if result > .pi { result -= fullTurn }
        if result < -.pi { result += fullTurn }
        return result
    }

    private func rotate(_ point: LevelThirtyNineVector3, yaw: CGFloat, pitch: CGFloat) -> LevelThirtyNineVector3 {
        let yawed = LevelThirtyNineVector3(
            x: point.x * cos(yaw) - point.z * sin(yaw),
            y: point.y,
            z: point.x * sin(yaw) + point.z * cos(yaw)
        )
        return LevelThirtyNineVector3(
            x: yawed.x,
            y: yawed.y * cos(pitch) - yawed.z * sin(pitch),
            z: yawed.y * sin(pitch) + yawed.z * cos(pitch)
        )
    }

    private func normalize(_ vector: LevelThirtyNineVector3) -> LevelThirtyNineVector3 {
        let length = max(0.001, sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z))
        return LevelThirtyNineVector3(x: vector.x / length, y: vector.y / length, z: vector.z / length)
    }

    private func dot(_ lhs: LevelThirtyNineVector3, _ rhs: LevelThirtyNineVector3) -> CGFloat {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }
}

struct MathItLevelThirtyNineView: View {
    var viewModel: MathItLevelThirtyNineViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let blue = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    EmptyView()
                        .font(.trajan(36))
                        .foregroundStyle(.white.opacity(0.34))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(blue)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                TimelineView(.animation) { timeline in
                    Canvas { context, canvasSize in
                        drawTorus(
                            in: &context,
                            size: canvasSize,
                            yaw: viewModel.yaw,
                            pitch: viewModel.pitch
                        )
                    }
                    .onChange(of: timeline.date) { _, date in
                        viewModel.step(at: date)
                    }
                }
                .frame(width: size.width, height: min(size.height * 0.62, size.width * 1.18))
                .position(x: size.width / 2, y: size.height * 0.48)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewModel.updateRotation(value.translation)
                        }
                        .onEnded { _ in
                            viewModel.finishRotation()
                        }
                )

                CompletionOverlay(
                    title: "Level 39 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private func drawTorus(
        in context: inout GraphicsContext,
        size: CGSize,
        yaw: CGFloat,
        pitch: CGFloat
    ) {
        let majorSegments = viewModel.majorSegments
        let minorSegments = viewModel.minorSegments
        let majorRadius: CGFloat = 1.34
        let minorRadius: CGFloat = 0.52
        let scale = min(size.width, size.height) * 0.25
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let light = normalize(LevelThirtyNineVector3(x: -0.45, y: -0.72, z: 0.78))
        var faces: [LevelThirtyNineFace] = []
        let ballSurface = torusPoint(
            u: viewModel.ballU,
            v: viewModel.ballV,
            majorRadius: majorRadius,
            minorRadius: minorRadius + 0.09
        )
        let ball = rotate(ballSurface, yaw: yaw, pitch: pitch)
        var ballDrawn = false

        for majorIndex in 0..<majorSegments {
            for minorIndex in 0..<minorSegments {
                let u0 = CGFloat(majorIndex) / CGFloat(majorSegments) * .pi * 2
                let u1 = CGFloat(majorIndex + 1) / CGFloat(majorSegments) * .pi * 2
                let v0 = CGFloat(minorIndex) / CGFloat(minorSegments) * .pi * 2
                let v1 = CGFloat(minorIndex + 1) / CGFloat(minorSegments) * .pi * 2

                let vertices = [
                    torusPoint(u: u0, v: v0, majorRadius: majorRadius, minorRadius: minorRadius),
                    torusPoint(u: u1, v: v0, majorRadius: majorRadius, minorRadius: minorRadius),
                    torusPoint(u: u1, v: v1, majorRadius: majorRadius, minorRadius: minorRadius),
                    torusPoint(u: u0, v: v1, majorRadius: majorRadius, minorRadius: minorRadius)
                ].map { rotate($0, yaw: yaw, pitch: pitch) }

                let normal = normalize(rotate(
                    LevelThirtyNineVector3(
                        x: cos((u0 + u1) / 2) * cos((v0 + v1) / 2),
                        y: sin((v0 + v1) / 2),
                        z: sin((u0 + u1) / 2) * cos((v0 + v1) / 2)
                    ),
                    yaw: yaw,
                    pitch: pitch
                ))
                let brightness = max(0, dot(normal, light))
                let rim = pow(max(0, 1 - abs(normal.z)), 2.2)
                let depth = vertices.reduce(0) { $0 + $1.z } / CGFloat(vertices.count)
                let points = vertices.map {
                    CGPoint(x: center.x + $0.x * scale, y: center.y - $0.y * scale)
                }

                faces.append(LevelThirtyNineFace(
                    points: points,
                    depth: depth,
                    brightness: brightness,
                    rim: rim,
                    painted: viewModel.isPainted(major: majorIndex, minor: minorIndex)
                ))
            }
        }

        faces.sort { $0.depth < $1.depth }

        for face in faces {
            if !ballDrawn, ball.z < face.depth {
                drawBall(ball, in: &context, center: center, scale: scale)
                ballDrawn = true
            }

            var path = Path()
            path.move(to: face.points[0])
            for point in face.points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()

            let intensity = 0.12 + face.brightness * 0.72 + face.rim * 0.18
            let faceColor = face.painted
                ? Color.mathItGeometry.opacity(0.5 + intensity * 0.5)
                : Color.mathItGeometry.opacity(0.08 + intensity * 0.42)
            context.fill(
                path,
                with: .color(faceColor)
            )
            context.stroke(
                path,
                with: .color(face.painted ? .white.opacity(0.18) : blue.opacity(0.055 + face.rim * 0.13)),
                lineWidth: 0.45
            )
        }

        if !ballDrawn {
            drawBall(ball, in: &context, center: center, scale: scale)
        }
    }

    private func drawBall(
        _ ball: LevelThirtyNineVector3,
        in context: inout GraphicsContext,
        center: CGPoint,
        scale: CGFloat
    ) {
        let ballPoint = CGPoint(x: center.x + ball.x * scale, y: center.y - ball.y * scale)
        let depthScale = min(1.12, max(0.86, 1 + ball.z * 0.045))
        let radius = 18 * depthScale
        let ballRect = CGRect(
            x: ballPoint.x - radius,
            y: ballPoint.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let shadowRect = CGRect(
            x: ballPoint.x - radius * 0.82 + 3,
            y: ballPoint.y - radius * 0.38 + radius * 0.78,
            width: radius * 1.64,
            height: radius * 0.76
        )

        context.fill(
            Path(ellipseIn: shadowRect),
            with: .color(.black.opacity(0.42))
        )
        context.fill(
            Path(ellipseIn: ballRect),
            with: .radialGradient(
                Gradient(colors: [
                    .white,
                    Color(white: 0.88),
                    Color.mathItGeometry
                ]),
                center: CGPoint(x: ballPoint.x - radius * 0.34, y: ballPoint.y - radius * 0.38),
                startRadius: 1,
                endRadius: radius * 1.25
            )
        )
        context.stroke(Path(ellipseIn: ballRect), with: .color(blue.opacity(0.56)), lineWidth: 1)

        let highlightRadius = radius * 0.18
        let highlight = CGRect(
            x: ballPoint.x - radius * 0.42,
            y: ballPoint.y - radius * 0.46,
            width: highlightRadius * 2,
            height: highlightRadius * 2
        )
        context.fill(Path(ellipseIn: highlight), with: .color(.white.opacity(0.72)))
    }

    private func torusPoint(
        u: CGFloat,
        v: CGFloat,
        majorRadius: CGFloat,
        minorRadius: CGFloat
    ) -> LevelThirtyNineVector3 {
        LevelThirtyNineVector3(
            x: (majorRadius + minorRadius * cos(v)) * cos(u),
            y: minorRadius * sin(v),
            z: (majorRadius + minorRadius * cos(v)) * sin(u)
        )
    }

    private func rotate(_ point: LevelThirtyNineVector3, yaw: CGFloat, pitch: CGFloat) -> LevelThirtyNineVector3 {
        let yawed = LevelThirtyNineVector3(
            x: point.x * cos(yaw) - point.z * sin(yaw),
            y: point.y,
            z: point.x * sin(yaw) + point.z * cos(yaw)
        )
        return LevelThirtyNineVector3(
            x: yawed.x,
            y: yawed.y * cos(pitch) - yawed.z * sin(pitch),
            z: yawed.y * sin(pitch) + yawed.z * cos(pitch)
        )
    }

    private func normalize(_ vector: LevelThirtyNineVector3) -> LevelThirtyNineVector3 {
        let length = max(0.001, sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z))
        return LevelThirtyNineVector3(x: vector.x / length, y: vector.y / length, z: vector.z / length)
    }

    private func dot(_ lhs: LevelThirtyNineVector3, _ rhs: LevelThirtyNineVector3) -> CGFloat {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }
}

private struct LevelThirtyNineVector3 {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

private struct LevelThirtyNineFace {
    let points: [CGPoint]
    let depth: CGFloat
    let brightness: CGFloat
    let rim: CGFloat
    let painted: Bool
}
