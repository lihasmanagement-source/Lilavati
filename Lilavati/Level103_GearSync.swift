import SwiftUI

@Observable
final class MathItLevelThirtySixViewModel {
    var step = 0
    var guess = 1
    var simulating = false
    var gateOpen = false
    var ballProgress: CGFloat = 0
    var completed = false
    private var runID = UUID()

    var progress: Double {
        completed ? 1 : min(0.96, Double(step) / 12)
    }

    func incrementGuess() {
        guard !simulating, !gateOpen else { return }
        guess = min(24, guess + 1)
        HapticPlayer.playLightTap()
    }

    func decrementGuess() {
        guard !simulating, !gateOpen else { return }
        guess = max(1, guess - 1)
        HapticPlayer.playLightTap()
    }

    func testGuess() {
        guard !simulating, !gateOpen else { return }
        let id = UUID()
        runID = id
        simulating = true
        step = 0
        runStep(1, run: id)
    }

    private func runStep(_ next: Int, run: UUID) {
        guard simulating, run == runID else { return }
        guard next <= guess else {
            finishSimulation()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            guard self.simulating, run == self.runID else { return }
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                self.step = next
            }
            self.runStep(next + 1, run: run)
        }
    }

    private func finishSimulation() {
        runID = UUID()
        simulating = false
        let aligned = guess == 12
        if aligned {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.62, dampingFraction: 0.68)) {
                gateOpen = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeInOut(duration: 2.25)) {
                    self.ballProgress = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.05) {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                    self.completed = true
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                self.resetRun()
            }
        }
    }

    private func resetRun() {
        runID = UUID()
        simulating = false
        withAnimation(.spring(response: 0.54, dampingFraction: 0.76)) {
            step = 0
        }
    }
}

struct MathItLevelThirtySixView: View {
    var viewModel: MathItLevelThirtySixViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let sync = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gearY = size.height * 0.47
            let smallRadius = min(62, size.width * 0.15)
            let largeRadius = smallRadius * 1.5
            let gearSpacing = smallRadius + largeRadius + 0.5
            let leftGear = CGPoint(x: size.width / 2 - gearSpacing / 2, y: gearY)
            let rightGear = CGPoint(x: size.width / 2 + gearSpacing / 2, y: gearY)
            let trackY = size.height * 0.71
            let ballStart = CGPoint(x: 42, y: trackY)
            let goal = CGPoint(x: size.width - 42, y: trackY)

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
                        .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.34))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(sync)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                gear(
                    number: 4,
                    center: leftGear,
                    radius: smallRadius,
                    rotation: Double(viewModel.step) * 90
                )

                gear(
                    number: 6,
                    center: rightGear,
                    radius: largeRadius,
                    rotation: -Double(viewModel.step) * 60
                )

                syncTrack(ballStart: ballStart, goal: goal)
                movementControl(at: CGPoint(x: size.width / 2, y: size.height * 0.84))

                CompletionOverlay(
                    title: "Level 36 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private func movementControl(at point: CGPoint) -> some View {
        HStack(spacing: 17) {
            Button(action: viewModel.decrementGuess) {
                Image(systemName: "minus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(sync)
                    .frame(width: 42, height: 42)
                    .overlay { Circle().stroke(sync.opacity(0.55), lineWidth: 1.2) }
            }
            .buttonStyle(.plain)

            Text("\(viewModel.guess)")
                .font(.trajan(34))
                .foregroundStyle(.white)
                .frame(width: 56)

            Button(action: viewModel.incrementGuess) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(sync)
                    .frame(width: 42, height: 42)
                    .overlay { Circle().stroke(sync.opacity(0.55), lineWidth: 1.2) }
            }
            .buttonStyle(.plain)

            Button(action: viewModel.testGuess) {
                Image(systemName: "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(sync, in: Circle())
                    .shadow(color: sync.opacity(0.52), radius: 9)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.simulating || viewModel.gateOpen)
            .opacity(viewModel.simulating ? 0.42 : 1)
        }
        .position(point)
    }

    private func gear(number: Int, center: CGPoint, radius: CGFloat, rotation: Double) -> some View {
        ZStack {
            LevelThirtySixGearShape(teeth: number)
                .stroke(
                    viewModel.gateOpen ? sync : .white.opacity(0.82),
                    style: StrokeStyle(lineWidth: viewModel.gateOpen ? 2.8 : 2, lineJoin: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(rotation))
                .shadow(color: viewModel.gateOpen ? sync.opacity(0.78) : .white.opacity(0.12), radius: viewModel.gateOpen ? 18 : 5)

            Circle()
                .stroke(.white.opacity(0.24), lineWidth: 1)
                .frame(width: radius * 1.18, height: radius * 1.18)

            Circle()
                .fill(.black)
                .overlay { Circle().stroke(.white.opacity(0.56), lineWidth: 1.6) }
                .frame(width: radius * 0.52, height: radius * 0.52)

            Text("\(number)")
                .font(.garamond(radius * 0.35))
                .foregroundStyle(.white)

            Circle()
                .stroke(sync.opacity(0.58), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                .frame(width: 18, height: 18)
                .shadow(color: sync.opacity(0.36), radius: 5)
                .offset(y: -radius * 1.13)

            Circle()
                .fill(viewModel.gateOpen ? sync : .white)
                .frame(width: 12, height: 12)
                .shadow(color: viewModel.gateOpen ? sync : .white.opacity(0.8), radius: 9)
                .offset(y: -radius * 1.13)
                .rotationEffect(.degrees(rotation))
        }
        .position(center)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: viewModel.step)
    }

    private func syncTrack(ballStart: CGPoint, goal: CGPoint) -> some View {
        let ballX = ballStart.x + (goal.x - ballStart.x) * viewModel.ballProgress
        let hop = abs(sin(viewModel.ballProgress * .pi * 4)) * 8

        return ZStack {
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: goal.x - ballStart.x, height: 2)
                .position(x: (goal.x + ballStart.x) / 2, y: goal.y)

            Circle()
                .stroke(.white.opacity(viewModel.gateOpen ? 0.9 : 0.36), lineWidth: 2.2)
                .frame(width: 42, height: 42)
                .shadow(color: viewModel.gateOpen ? sync.opacity(0.46) : .clear, radius: 10)
                .position(goal)

            Circle()
                .fill(.white)
                .frame(width: 25, height: 25)
                .shadow(color: .white.opacity(0.76), radius: 12)
                .position(x: ballX, y: ballStart.y - hop)
                .zIndex(4)
        }
    }
}

private struct LevelThirtySixGearShape: Shape {
    let teeth: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.49
        let rootRadius = outerRadius * 0.72
        let count = teeth * 4
        let startAngle = teeth == 4 ? -CGFloat.pi / 8 : -CGFloat.pi / 2
        var path = Path()

        for index in 0..<count {
            let toothPhase = index % 4
            let radius = toothPhase == 1 || toothPhase == 2 ? outerRadius : rootRadius
            let angle = startAngle + CGFloat(index) * 2 * .pi / CGFloat(count)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
