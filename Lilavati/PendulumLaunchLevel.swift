import Combine
import SwiftUI

struct MathItPendulumLaunchGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var phase: LaunchPhase = .aiming
    @State private var selectedAngle = 54.0
    @State private var pendulumAngle = -54.0 * .pi / 180
    @State private var angularVelocity = 0.0
    @State private var projectilePosition = CGPoint.zero
    @State private var projectileVelocity = CGVector.zero
    @State private var completed = false
    @State private var goalPulse = false

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let releaseAngle = 20.0 * Double.pi / 180
    private let projectileGravity = 430.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 12) {
                    VStack(spacing: 6) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(38))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(completed ? 1 : 0.72))
                    }
                    .padding(.horizontal, 56)

                    launchField
                        .frame(height: min(510, proxy.size.height * 0.65))
                        .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        valueBadge("\(Int(selectedAngle.rounded()))°", icon: "angle")

                        Button(action: reset) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 54, height: 48)
                                .background(accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Reset pendulum")
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 38)
                .padding(.bottom, 70)

                CompletionOverlay(
                    title: "Level \(concept.number) Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var launchField: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let pivot = pivotPoint(in: size)
            let bob = bobPoint(angle: pendulumAngle, in: size)
            let target = targetPoint(in: size)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.015, green: 0.02, blue: 0.03))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mathGold.opacity(0.24), lineWidth: 1))

                Canvas { context, canvasSize in
                    drawField(context: &context, size: canvasSize)
                    drawReleaseGuide(context: &context, size: canvasSize)
                }

                targetView
                    .position(target)

                if phase == .aiming || phase == .swinging {
                    Path { path in
                        path.move(to: pivot)
                        path.addLine(to: bob)
                    }
                    .stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                    pendulumBall
                        .position(bob)
                } else {
                    Path { path in
                        path.move(to: pivot)
                        path.addLine(to: bob)
                    }
                    .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [5, 6]))

                    projectileBall
                        .position(projectilePosition)
                }

                Circle()
                    .fill(Color.mathGold)
                    .frame(width: 12, height: 12)
                    .position(pivot)
                    .shadow(color: Color.mathGold.opacity(0.75), radius: 8)

                VStack {
                    Spacer()
                    Image(systemName: phase == .aiming ? "hand.draw.fill" : phase == .missed ? "arrow.counterclockwise" : "scope")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(phase == .missed ? .red.opacity(0.9) : accent.opacity(0.92))
                        .padding(.bottom, 15)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        aim(at: value.location, in: size)
                    }
                    .onEnded { _ in
                        beginSwing()
                    }
            )
            .onReceive(tick) { _ in
                step(in: size)
            }
        }
    }

    private var pendulumBall: some View {
        Circle()
            .fill(RadialGradient(colors: [.white, accent, accent.opacity(0.54)], center: .topLeading, startRadius: 1, endRadius: 24))
            .frame(width: 38, height: 38)
            .overlay(Circle().stroke(.white.opacity(0.68), lineWidth: 1.5))
            .shadow(color: accent.opacity(0.74), radius: 14)
    }

    private var projectileBall: some View {
        Circle()
            .fill(phase == .missed ? Color.red : accent)
            .frame(width: 30, height: 30)
            .overlay(Circle().stroke(.white.opacity(0.78), lineWidth: 1.4))
            .shadow(color: phase == .missed ? .red.opacity(0.7) : accent.opacity(0.85), radius: 13)
    }

    private var targetView: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.24), lineWidth: 2)
                .frame(width: 66, height: 66)
            Circle()
                .stroke(accent.opacity(0.86), lineWidth: 3)
                .frame(width: 48, height: 48)
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 26, height: 26)
            Image(systemName: "scope")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .scaleEffect(goalPulse ? 1.18 : 1)
        .shadow(color: accent.opacity(goalPulse ? 0.9 : 0.35), radius: goalPulse ? 20 : 9)
    }

    private func valueBadge(_ value: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
        }
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(.black.opacity(0.76), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.38), lineWidth: 1))
    }

    private func aim(at point: CGPoint, in size: CGSize) {
        guard phase == .aiming, !completed else { return }
        let pivot = pivotPoint(in: size)
        let rawAngle = atan2(point.x - pivot.x, point.y - pivot.y) * 180 / .pi
        selectedAngle = min(78, max(24, -Double(rawAngle)))
        pendulumAngle = -selectedAngle * .pi / 180
    }

    private func beginSwing() {
        guard phase == .aiming, !completed else { return }
        phase = .swinging
        angularVelocity = 0
        HapticPlayer.playLightTap()
    }

    private func step(in size: CGSize) {
        guard !completed else { return }
        let dt = 1.0 / 60.0

        switch phase {
        case .aiming, .missed:
            return
        case .swinging:
            angularVelocity += -7.6 * sin(pendulumAngle) * dt
            angularVelocity *= 0.999
            pendulumAngle += angularVelocity * dt

            if pendulumAngle >= releaseAngle, angularVelocity > 0 {
                let length = ropeLength(in: size)
                projectilePosition = bobPoint(angle: pendulumAngle, in: size)
                projectileVelocity = CGVector(
                    dx: length * cos(pendulumAngle) * angularVelocity * 0.98,
                    dy: -length * sin(pendulumAngle) * angularVelocity * 0.98
                )
                phase = .flying
                HapticPlayer.playLightTap()
            }
        case .flying:
            projectileVelocity.dy += projectileGravity * dt
            projectilePosition.x += projectileVelocity.dx * dt
            projectilePosition.y += projectileVelocity.dy * dt

            let target = targetPoint(in: size)
            if hypot(projectilePosition.x - target.x, projectilePosition.y - target.y) <= 34 {
                complete()
            } else if projectilePosition.x > size.width + 30 || projectilePosition.y > size.height + 30 || projectilePosition.x < -30 {
                miss()
            }
        }
    }

    private func complete() {
        phase = .flying
        goalPulse = true
        completed = true
        HapticPlayer.playCompletionTap()
    }

    private func miss() {
        guard phase == .flying else { return }
        phase = .missed
        HapticPlayer.playLightTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            if phase == .missed {
                reset()
            }
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            phase = .aiming
            selectedAngle = 54
            pendulumAngle = -54 * .pi / 180
            angularVelocity = 0
            projectilePosition = .zero
            projectileVelocity = .zero
            completed = false
            goalPulse = false
        }
    }

    private func pivotPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.28, y: size.height * 0.2)
    }

    private func ropeLength(in size: CGSize) -> CGFloat {
        min(size.width * 0.33, size.height * 0.29)
    }

    private func bobPoint(angle: Double, in size: CGSize) -> CGPoint {
        let pivot = pivotPoint(in: size)
        let length = ropeLength(in: size)
        return CGPoint(
            x: pivot.x + length * CGFloat(sin(angle)),
            y: pivot.y + length * CGFloat(cos(angle))
        )
    }

    private func targetPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.79, y: size.height * 0.47)
    }

    private func drawField(context: inout GraphicsContext, size: CGSize) {
        let floorY = size.height * 0.78
        var floor = Path()
        floor.move(to: CGPoint(x: 16, y: floorY))
        floor.addLine(to: CGPoint(x: size.width - 16, y: floorY))
        context.stroke(floor, with: .color(.white.opacity(0.14)), lineWidth: 1)

        for index in 0..<12 {
            let x = size.width * CGFloat((index * 37) % 101) / 101
            let y = size.height * CGFloat((index * 23 + 11) % 67) / 100
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)), with: .color(.white.opacity(0.28)))
        }
    }

    private func drawReleaseGuide(context: inout GraphicsContext, size: CGSize) {
        let pivot = pivotPoint(in: size)
        let length = ropeLength(in: size)
        var arc = Path()
        arc.addArc(center: pivot, radius: length, startAngle: .degrees(112), endAngle: .degrees(70), clockwise: false)
        context.stroke(arc, with: .color(Color.mathGold.opacity(0.24)), style: StrokeStyle(lineWidth: 1.2, dash: [4, 6]))

        let release = bobPoint(angle: releaseAngle, in: size)
        context.stroke(Path(ellipseIn: CGRect(x: release.x - 7, y: release.y - 7, width: 14, height: 14)), with: .color(accent.opacity(0.65)), lineWidth: 1.5)
    }
}

private enum LaunchPhase {
    case aiming
    case swinging
    case flying
    case missed
}
