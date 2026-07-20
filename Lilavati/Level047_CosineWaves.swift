import SwiftUI
import Combine
import AVFoundation

struct MathItUpdraftGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var ballPosition = CGPoint(x: 0.28, y: 0.48)
    @State private var ballVelocity = CGVector(dx: 0, dy: 0)
    @State private var worldOffset: Double = 0
    @State private var speed: Double = 0.0017
    @State private var survivalTime: Double = 0
    @State private var airborne = false
    @State private var completed = false
    @State private var hitPulse = false
    @State private var contactGlow = false
    @State private var failedPulse = false
    @State private var ballSpin: Double = 0
    @State private var jumpCount = 0

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let ballRadius: CGFloat = 16
    private let survivalGoal: Double = 15
    private let waveFrequency: Double = 2.15
    private let wavePhase: Double = 0.08

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
                            .font(.trajan(39))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(completed ? 1 : 0.72))

                        Text("tap jump survival")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accent.opacity(0.9))
                    }
                    .padding(.horizontal, 58)

                    updraftField
                        .frame(height: min(500, proxy.size.height * 0.62))
                        .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        tinyBadge("\(max(0, Int(ceil(survivalGoal - survivalTime))))s", systemImage: "timer")
                        tinyBadge(airborne ? "\(max(0, 3 - jumpCount))" : "3", systemImage: airborne ? "arrow.up" : "circle.fill")
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
                }
                .padding(.top, 38)
                .padding(.bottom, 74)

                CompletionOverlay(
                    title: "Level \(concept.number) Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .onReceive(tick) { _ in
                stepUpdraft()
            }
        }
    }

    private var updraftField: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let ballPoint = point(ballPosition, in: size)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.black, Color(red: 0.012, green: 0.015, blue: 0.02), accent.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))

                Canvas { canvas, size in
                    drawStars(canvas: &canvas, size: size)
                    drawTinyTerrain(canvas: &canvas, size: size)
                    drawHazards(canvas: &canvas, size: size)
                }

                ZStack {
                    Circle()
                        .fill(.white)
                    Capsule()
                        .fill(accent.opacity(0.62))
                        .frame(width: 4, height: ballRadius * 1.55)
                }
                    .frame(width: ballRadius * 2, height: ballRadius * 2)
                    .rotationEffect(.degrees(ballSpin))
                    .shadow(color: .white.opacity(contactGlow ? 1 : 0.85), radius: contactGlow ? 22 : 14)
                    .overlay(Circle().stroke(failedPulse ? .red.opacity(0.88) : accent.opacity(0.32), lineWidth: failedPulse ? 3 : 1.6))
                    .position(ballPoint)
                    .scaleEffect(contactGlow ? CGSize(width: 1.16, height: 0.84) : CGSize(width: 1, height: 1))

                VStack {
                    ProgressView(value: survivalTime / survivalGoal)
                        .tint(accent)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                    Spacer()
                    Text(failedPulse ? "target hit" : "tap to jump over red targets")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(failedPulse ? .red.opacity(0.9) : accent.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(.bottom, 14)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                jump()
            }
        }
    }

    private func tinyBadge(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 3) {
            Text(text)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.mathGold.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(.black.opacity(0.74), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.36), lineWidth: 1.1))
    }

    private func stepUpdraft() {
        guard !completed else { return }
        if failedPulse { return }

        survivalTime += 1.0 / 60.0
        if survivalTime >= survivalGoal {
            complete()
            return
        }

        speed = currentRunnerSpeed()
        ballSpin += speed * 3600
        worldOffset += speed
        let targetX = runnerAnchorX()
        ballPosition.x += (targetX - ballPosition.x) * 0.09

        if airborne {
            let progress = min(1, survivalTime / survivalGoal)
            ballVelocity.dy += 0.0011 + progress * 0.0014
            ballPosition.y += ballVelocity.dy

            let ground = terrainY(screenX: ballPosition.x)
            if ballPosition.y > ground - 0.02 && ballVelocity.dy > 0 {
                ballPosition.y = ground - 0.025
                ballVelocity = .zero
                airborne = false
                jumpCount = 0
                contactGlow = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    contactGlow = false
                }
            }
        } else {
            ballPosition.y = terrainY(screenX: ballPosition.x) - 0.025
        }

        checkHazardCollision()
    }

    private func jump() {
        guard !completed && jumpCount < 3 else { return }
        let progress = min(1, survivalTime / survivalGoal)
        ballVelocity = CGVector(dx: 0, dy: -(0.023 + progress * 0.014))
        airborne = true
        jumpCount += 1
        contactGlow = false
        HapticPlayer.playLightTap()
    }

    private func complete() {
        ballVelocity = .zero
        hitPulse = true
        completed = true
        HapticPlayer.playCompletionTap()
    }

    private func checkHazardCollision() {
        for hazard in visibleHazards() {
            let hazardPoint = CGPoint(x: hazard, y: terrainY(screenX: hazard) - 0.045)
            let dx = ballPosition.x - hazardPoint.x
            let dy = ballPosition.y - hazardPoint.y
            if sqrt(dx * dx + dy * dy) < 0.045 {
                failAndReset()
                return
            }
        }
    }

    private func failAndReset() {
        failedPulse = true
        HapticPlayer.playLightTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            reset()
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            ballPosition = CGPoint(x: 0.28, y: terrainY(screenX: 0.28) - 0.025)
            ballVelocity = .zero
            worldOffset = 0
            speed = 0.0017
            survivalTime = 0
            airborne = false
            completed = false
            hitPulse = false
            contactGlow = false
            failedPulse = false
            ballSpin = 0
            jumpCount = 0
        }
    }

    private func terrainY(screenX: Double) -> Double {
        let x = screenX + worldOffset
        return 0.64 - 0.12 * sin((x * waveFrequency + wavePhase) * .pi * 2)
    }

    private func visibleHazards() -> [Double] {
        hazardWorldPositions().compactMap { worldX in
            let screenX = worldX - worldOffset
            return (-0.1...1.1).contains(screenX) ? screenX : nil
        }
    }

    private func hazardWorldPositions() -> [Double] {
        (0..<16).compactMap { index in
            guard index != 2 else { return nil }
            let cycle = Double(index + 1)
            let placement = index.isMultiple(of: 2) ? 0.25 : 0.37
            return (cycle + placement - wavePhase) / waveFrequency
        }
    }

    private func currentRunnerSpeed() -> Double {
        let progress = min(1, survivalTime / survivalGoal)
        return 0.0012 + pow(progress, 1.25) * 0.012
    }

    private func runnerAnchorX() -> Double {
        let progress = min(1, survivalTime / survivalGoal)
        return 0.24 + progress * 0.18
    }

    private func drawTinyTerrain(canvas: inout GraphicsContext, size: CGSize) {
        var crest = Path()
        var fill = Path()
        for index in 0...96 {
            let x = Double(index) / 96.0
            let y = terrainY(screenX: x)
            let point = CGPoint(x: x * size.width, y: y * size.height)
            if index == 0 {
                crest.move(to: point)
                fill.move(to: point)
            } else {
                crest.addLine(to: point)
                fill.addLine(to: point)
            }
        }
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()

        canvas.fill(fill, with: .linearGradient(
            Gradient(colors: [
                accent.opacity(0.62),
                accent.opacity(0.24),
                .black.opacity(0.15)
            ]),
            startPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.42),
            endPoint: CGPoint(x: size.width * 0.5, y: size.height)
        ))
        canvas.stroke(crest, with: .color(.white.opacity(0.88)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private func drawHazards(canvas: inout GraphicsContext, size: CGSize) {
        for screenX in visibleHazards() {
            let center = point(CGPoint(x: screenX, y: terrainY(screenX: screenX) - 0.052), in: size)
            let radius: CGFloat = 16
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            canvas.fill(Path(ellipseIn: rect), with: .color(.red.opacity(0.84)))
            canvas.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.48)), style: StrokeStyle(lineWidth: 1.4))
        }
    }

    private func drawStars(canvas: inout GraphicsContext, size: CGSize) {
        for index in 0..<18 {
            let x = CGFloat((index * 37) % 100) / 100.0 * size.width
            let y = CGFloat((index * 53) % 45) / 100.0 * size.height
            let radius = CGFloat(index % 3 + 1)
            canvas.fill(
                Path(ellipseIn: CGRect(x: x, y: y + 12, width: radius, height: radius)),
                with: .color(.white.opacity(index.isMultiple(of: 4) ? 0.7 : 0.35))
            )
        }
    }

    private func point(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }
}
