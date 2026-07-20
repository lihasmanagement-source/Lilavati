import SwiftUI
import Combine
import AVFoundation

private struct InterferencePoolStage {
    let start: CGPoint
    let goal: CGPoint
    let barriers: [CGRect]
}

struct MathItRipplePondGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var ballPosition = CGPoint(x: 0.14, y: 0.58)
    @State private var ballVelocity = CGVector.zero
    @State private var ripples: [PondRipple] = []
    @State private var completed = false
    @State private var transitioning = false
    @State private var warningText: String?

    private let stages = [
        InterferencePoolStage(
            start: CGPoint(x: 0.14, y: 0.58),
            goal: CGPoint(x: 0.84, y: 0.42),
            barriers: [CGRect(x: 0.46, y: 0.18, width: 0.055, height: 0.46)]
        ),
        InterferencePoolStage(
            start: CGPoint(x: 0.15, y: 0.78),
            goal: CGPoint(x: 0.83, y: 0.20),
            barriers: [
                CGRect(x: 0.34, y: 0.12, width: 0.055, height: 0.48),
                CGRect(x: 0.61, y: 0.42, width: 0.055, height: 0.46),
                CGRect(x: 0.39, y: 0.57, width: 0.27, height: 0.05)
            ]
        ),
        InterferencePoolStage(
            start: CGPoint(x: 0.12, y: 0.22),
            goal: CGPoint(x: 0.86, y: 0.76),
            barriers: [
                CGRect(x: 0.27, y: 0.10, width: 0.05, height: 0.47),
                CGRect(x: 0.48, y: 0.38, width: 0.05, height: 0.52),
                CGRect(x: 0.70, y: 0.10, width: 0.05, height: 0.48),
                CGRect(x: 0.31, y: 0.34, width: 0.18, height: 0.05),
                CGRect(x: 0.53, y: 0.62, width: 0.18, height: 0.05)
            ]
        )
    ]
    private let goalLockDistance: CGFloat = 0.034
    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private var stage: InterferencePoolStage { stages[stageIndex] }
    private var goalPosition: CGPoint { stage.goal }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    Color.clear
                        .frame(height: 48)

                    ProgressView(value: completionProgress)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    HStack(spacing: 8) {
                        ForEach(stages.indices, id: \.self) { index in
                            Circle()
                                .fill(index <= stageIndex ? accent : .white.opacity(0.18))
                                .frame(width: 7, height: 7)
                        }
                    }

                    pondField
                        .frame(height: min(390, proxy.size.height * 0.5))
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        Button(action: reset) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 54, height: 48)
                                .background(accent, in: Circle())
                        }
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)

                    if let warningText {
                        Text(warningText)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 38)
                .padding(.bottom, 78)

                CompletionOverlay(
                    title: "Interference Pool Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .onReceive(tick) { _ in
                stepPhysics()
            }
        }
    }

    private var completionProgress: Double {
        let dx = ballPosition.x - goalPosition.x
        let dy = ballPosition.y - goalPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        let local = max(0, min(1, 1 - Double(distance / 0.68)))
        return (Double(stageIndex) + local) / Double(stages.count)
    }

    private var pondField: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.08), Color(red: 0.01, green: 0.05, blue: 0.08), .black.opacity(0.94)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.38), lineWidth: 1.2))

                Canvas { canvas, size in
                    drawWaterGrid(canvas: &canvas, size: size)
                    drawRipples(canvas: &canvas, size: size)
                }

                ForEach(Array(stage.barriers.enumerated()), id: \.offset) { _, barrier in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.black.opacity(0.86))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(accent.opacity(0.58), lineWidth: 1.3)
                        }
                        .frame(width: proxy.size.width * barrier.width, height: proxy.size.height * barrier.height)
                        .position(
                            x: proxy.size.width * barrier.midX,
                            y: proxy.size.height * barrier.midY
                        )
                }

                goalView
                    .position(point(goalPosition, in: proxy.size))

                ballView
                    .position(point(ballPosition, in: proxy.size))

                VStack {
                    HStack {
                        Text("RIPPLE FIELD")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(accent, in: Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(14)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        addRipple(at: value.location, in: proxy.size)
                    }
            )
        }
    }

    private var ballView: some View {
        Circle()
            .fill(.white)
            .frame(width: 34, height: 34)
            .shadow(color: .white.opacity(0.72), radius: 12)
            .overlay {
                Circle()
                    .stroke(accent.opacity(0.25), lineWidth: 2)
                    .scaleEffect(1.26)
            }
    }

    private var goalView: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 34, height: 34)
            Circle()
                .stroke(accent.opacity(0.82), style: StrokeStyle(lineWidth: 2.2, dash: [5, 4]))
                .frame(width: 34, height: 34)
                .shadow(color: accent.opacity(0.46), radius: 12)
        }
    }

    private func addRipple(at location: CGPoint, in size: CGSize) {
        guard !completed, !transitioning else { return }
        let normalized = CGPoint(
            x: min(max(location.x / max(size.width, 1), 0.06), 0.94),
            y: min(max(location.y / max(size.height, 1), 0.08), 0.92)
        )
        ripples.append(PondRipple(origin: normalized, age: 0, strength: 1))
        warningText = nil
        HapticPlayer.playLightTap()
    }

    private func stepPhysics() {
        guard !completed, !transitioning else { return }

        let dt: CGFloat = 1.0 / 60.0
        ripples = ripples
            .map { ripple in
                PondRipple(origin: ripple.origin, age: ripple.age + dt, strength: ripple.strength)
            }
            .filter { $0.age < 2.4 }

        var acceleration = CGVector.zero
        for ripple in ripples {
            let dx = ballPosition.x - ripple.origin.x
            let dy = ballPosition.y - ripple.origin.y
            let distance = max(0.001, sqrt(dx * dx + dy * dy))
            let radius = ripple.age * 0.42
            let waveBand = max(0, 1 - abs(distance - radius) / 0.052)
            let fade = max(0, 1 - ripple.age / 2.4)
            let force = waveBand * fade * ripple.strength * 0.018
            acceleration.dx += dx / distance * force
            acceleration.dy += dy / distance * force
        }

        ballVelocity.dx = (ballVelocity.dx + acceleration.dx) * 0.985
        ballVelocity.dy = (ballVelocity.dy + acceleration.dy + 0.0007) * 0.985

        ballPosition.x += ballVelocity.dx
        ballPosition.y += ballVelocity.dy

        resolveBarrierCollisions()

        if ballPosition.x < 0.07 || ballPosition.x > 0.93 {
            ballVelocity.dx *= -0.58
            ballPosition.x = min(max(ballPosition.x, 0.07), 0.93)
        }
        if ballPosition.y < 0.10 || ballPosition.y > 0.90 {
            ballVelocity.dy *= -0.58
            ballPosition.y = min(max(ballPosition.y, 0.10), 0.90)
        }

        let goalDX = ballPosition.x - goalPosition.x
        let goalDY = ballPosition.y - goalPosition.y
        if sqrt(goalDX * goalDX + goalDY * goalDY) < goalLockDistance {
            transitioning = true
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                ballPosition = goalPosition
                ballVelocity = .zero
                warningText = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                if self.stageIndex == self.stages.count - 1 {
                    withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                        self.completed = true
                    }
                } else {
                    self.stageIndex += 1
                    self.resetCurrentStage()
                }
            }
        }
    }

    private func resolveBarrierCollisions() {
        let radius: CGFloat = 0.026
        for barrier in stage.barriers {
            let expanded = barrier.insetBy(dx: -radius, dy: -radius)
            guard expanded.contains(ballPosition) else { continue }

            let left = abs(ballPosition.x - expanded.minX)
            let right = abs(expanded.maxX - ballPosition.x)
            let top = abs(ballPosition.y - expanded.minY)
            let bottom = abs(expanded.maxY - ballPosition.y)
            let nearest = min(left, right, top, bottom)

            if nearest == left {
                ballPosition.x = expanded.minX
                ballVelocity.dx = -abs(ballVelocity.dx) * 0.72
            } else if nearest == right {
                ballPosition.x = expanded.maxX
                ballVelocity.dx = abs(ballVelocity.dx) * 0.72
            } else if nearest == top {
                ballPosition.y = expanded.minY
                ballVelocity.dy = -abs(ballVelocity.dy) * 0.72
            } else {
                ballPosition.y = expanded.maxY
                ballVelocity.dy = abs(ballVelocity.dy) * 0.72
            }
        }
    }

    private func reset() {
        stageIndex = 0
        resetCurrentStage()
    }

    private func resetCurrentStage() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            ballPosition = stage.start
            ballVelocity = .zero
            ripples = []
            completed = false
            transitioning = false
            warningText = nil
        }
    }

    private func drawWaterGrid(canvas: inout GraphicsContext, size: CGSize) {
        for row in stride(from: 0.16, through: 0.88, by: 0.18) {
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.08, y: size.height * row))
            path.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * row))
            canvas.stroke(path, with: .color(accent.opacity(0.06)), lineWidth: 1)
        }

        for col in stride(from: 0.15, through: 0.90, by: 0.15) {
            var path = Path()
            path.move(to: CGPoint(x: size.width * col, y: size.height * 0.08))
            path.addLine(to: CGPoint(x: size.width * col, y: size.height * 0.92))
            canvas.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 1)
        }
    }

    private func drawRipples(canvas: inout GraphicsContext, size: CGSize) {
        let base = min(size.width, size.height)
        for ripple in ripples {
            let center = point(ripple.origin, in: size)
            let radius = ripple.age * 0.42 * base
            let opacity = max(0, 1 - ripple.age / 2.4)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            canvas.stroke(
                Path(ellipseIn: rect),
                with: .color(accent.opacity(0.72 * opacity)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            canvas.stroke(
                Path(ellipseIn: rect.insetBy(dx: -8, dy: -8)),
                with: .color(.white.opacity(0.16 * opacity)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
        }
    }

    private func pondBadge(_ text: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(width: 96, height: 48)
        .background(.black.opacity(0.84), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.44), lineWidth: 1.1))
    }

    private func point(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * point.x, y: size.height * point.y)
    }
}

struct PondRipple: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let age: CGFloat
    let strength: CGFloat
}
