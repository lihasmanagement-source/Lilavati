import SwiftUI
import Foundation

enum LevelFiftyThreeRacer: String {
    case square
    case circle
}

struct LevelFiftyThreeLane {
    var miles: Int
    var hours: Int

    var speed: Double {
        Double(miles) / Double(max(1, hours))
    }
}

struct LevelFiftyThreeStage {
    let squareStart: LevelFiftyThreeLane
    let circleStart: LevelFiftyThreeLane
}

@Observable
final class MathItLevelFiftyThreeViewModel {
    let stages = [
        LevelFiftyThreeStage(
            squareStart: LevelFiftyThreeLane(miles: 8, hours: 2),
            circleStart: LevelFiftyThreeLane(miles: 6, hours: 3)
        )
    ]

    var stageIndex = 0
    var square = LevelFiftyThreeLane(miles: 4, hours: 2)
    var circle = LevelFiftyThreeLane(miles: 6, hours: 3)
    var squareProgress = 0.0
    var circleProgress = 0.0
    var racing = false
    var controlsUnlocked = false
    var squareLooping = false
    var squareLoopStartedAt: Date?
    var squarePhaseAtCircleLaunch = 0.0
    var activeCircleDuration = 0.0
    var wrongPulse = false
    var completed = false

    init() {
        square = stages[0].squareStart
        circle = stages[0].circleStart
    }

    var currentStage: LevelFiftyThreeStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        return circleProgress
    }

    func adjust(_ racer: LevelFiftyThreeRacer, milesDelta: Int = 0, hoursDelta: Int = 0) {
        guard controlsUnlocked, !racing, !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            if racer == .circle {
                circle.miles = clamp(circle.miles + milesDelta, min: 1, max: 12)
                circle.hours = clamp(circle.hours + hoursDelta, min: 1, max: 6)
            }
            circleProgress = 0
            wrongPulse = false
        }
    }

    func startRace() {
        guard !racing, !completed else { return }
        if !controlsUnlocked {
            previewSquarePace()
            return
        }

        racing = true
        wrongPulse = false
        HapticPlayer.playLightTap()

        let circleDuration = raceDuration(for: circle.speed)

        circleProgress = 0
        startSquareLoopIfNeeded()
        squarePhaseAtCircleLaunch = squareLoopPhase()
        activeCircleDuration = circleDuration

        withAnimation(.linear(duration: circleDuration)) {
            circleProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + circleDuration + 0.18) {
            self.finishRace()
        }
    }

    func resetStage() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            square = currentStage.squareStart
            circle = currentStage.circleStart
            squareProgress = 0
            circleProgress = 0
            racing = false
            controlsUnlocked = false
            squareLooping = false
            squareLoopStartedAt = nil
            squarePhaseAtCircleLaunch = 0
            activeCircleDuration = 0
            wrongPulse = false
        }
    }

    private func previewSquarePace() {
        racing = true
        wrongPulse = false
        HapticPlayer.playLightTap()

        let squareDuration = raceDuration(for: square.speed)

        squareProgress = 0
        circleProgress = 0

        withAnimation(.linear(duration: squareDuration)) {
            squareProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + squareDuration) {
            self.squareProgress = 0
            self.squareLooping = false
            self.squareLoopStartedAt = nil
            self.startSquareLoopIfNeeded()
            self.racing = false
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                self.controlsUnlocked = true
            }
        }
    }

    private func startSquareLoopIfNeeded() {
        guard !squareLooping else { return }
        squareLooping = true
        squareLoopStartedAt = Date()
        squareProgress = 0
        withAnimation(.linear(duration: raceDuration(for: square.speed)).repeatForever(autoreverses: false)) {
            squareProgress = 1
        }
    }

    private func finishRace() {
        racing = false
        if didSatisfyOutcome() {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                completed = true
                squareProgress = 0
                squareLooping = false
                squareLoopStartedAt = nil
                activeCircleDuration = 0
            }
        } else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.44)) {
                wrongPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    self.circleProgress = 0
                    self.wrongPulse = false
                }
            }
        }
    }

    private func didSatisfyOutcome() -> Bool {
        let squareDuration = raceDuration(for: square.speed)
        let timeUntilSquareFinish = (1 - squarePhaseAtCircleLaunch) * squareDuration
        return activeCircleDuration < timeUntilSquareFinish - 0.02
    }

    private func squareLoopPhase(at date: Date = Date()) -> Double {
        guard let squareLoopStartedAt else { return squareProgress }
        let duration = raceDuration(for: square.speed)
        let elapsed = date.timeIntervalSince(squareLoopStartedAt)
        return elapsed.truncatingRemainder(dividingBy: duration) / duration
    }

    private func raceDuration(for speed: Double) -> Double {
        let clamped = min(max(speed, 0.5), 8)
        return 3.25 - (clamped - 0.5) / 7.5 * 2.1
    }

    private func clamp(_ value: Int, min lower: Int, max upper: Int) -> Int {
        Swift.min(Swift.max(value, lower), upper)
    }
}

struct MathItLevelFiftyThreeView: View {
    var viewModel: MathItLevelFiftyThreeViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let trackRect = CGRect(
                x: 22,
                y: size.height * 0.3,
                width: size.width - 44,
                height: min(270, size.height * 0.32)
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                raceBoard(rect: trackRect)

                controls(size: size, track: trackRect)

                Button(action: viewModel.resetStage) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.42), radius: 12)
                }
                .buttonStyle(.plain)
                .position(x: trackRect.maxX - 28, y: trackRect.minY - 24)

                CompletionOverlay(
                    title: "Level 53 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            Text("rate relay")
                .font(.garamond(min(32, size.width * 0.075)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            Text(stagePrompt)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(viewModel.wrongPulse ? .red.opacity(0.9) : accent)
                .shadow(color: viewModel.wrongPulse ? .red.opacity(0.45) : accent.opacity(0.35), radius: 9)

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 96)
    }

    private var stagePrompt: String {
        viewModel.controlsUnlocked ? "make circle faster" : "watch square pace"
    }

    private func raceBoard(rect: CGRect) -> some View {
        let localRect = CGRect(origin: .zero, size: rect.size)
        let squareY = localRect.height * 0.34
        let circleY = localRect.height * 0.72
        let startX = min(126, localRect.width * 0.34)
        let finishX = localRect.width - 30
        let squareX = startX + (finishX - startX) * CGFloat(viewModel.squareProgress)
        let circleX = startX + (finishX - startX) * CGFloat(viewModel.circleProgress)

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.wrongPulse ? Color.red.opacity(0.78) : .white.opacity(0.18), lineWidth: viewModel.wrongPulse ? 2 : 1.2)
                .background(.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 8))

            finishLine(x: finishX, rect: localRect)

            lane(y: squareY, startX: startX, finishX: finishX)
            lane(y: circleY, startX: startX, finishX: finishX)

            RoundedRectangle(cornerRadius: 3)
                .fill(accent.opacity(0.92))
                .frame(width: 26, height: 26)
                .position(x: squareX, y: squareY)
                .shadow(color: accent.opacity(0.56), radius: 10)

            Circle()
                .fill(.white)
                .frame(width: 28, height: 28)
                .position(x: circleX, y: circleY)
                .shadow(color: .white.opacity(0.55), radius: 10)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func finishLine(x: CGFloat, rect: CGRect) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x, y: rect.minY + 28))
            path.addLine(to: CGPoint(x: x, y: rect.maxY - 28))
        }
        .stroke(Color.mathGold.opacity(0.95), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .shadow(color: .white.opacity(0.3), radius: 9)
    }

    private func lane(y: CGFloat, startX: CGFloat, finishX: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: startX, y: y))
            path.addLine(to: CGPoint(x: finishX, y: y))
        }
        .stroke(Color.mathGold.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private func controls(size: CGSize, track: CGRect) -> some View {
        VStack(spacing: 14) {
            laneControls(title: "circle", racer: .circle, lane: viewModel.circle)
                .opacity(viewModel.controlsUnlocked ? 1 : 0.34)
                .allowsHitTesting(viewModel.controlsUnlocked)

            Button {
                viewModel.startRace()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 72, height: 48)
                    .background(viewModel.racing ? .white.opacity(0.22) : accent, in: Capsule())
                    .shadow(color: accent.opacity(viewModel.racing ? 0 : 0.42), radius: 12)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.racing)
        }
        .position(x: size.width / 2, y: min(size.height - 106, track.maxY + 132))
    }

    private func laneControls(title: String, racer: LevelFiftyThreeRacer, lane: LevelFiftyThreeLane) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))

            stepperRow(label: "miles", value: lane.miles) { delta in
                viewModel.adjust(racer, milesDelta: delta)
            }
            stepperRow(label: "hrs", value: lane.hours) { delta in
                viewModel.adjust(racer, hoursDelta: delta)
            }
        }
        .frame(width: 154, height: 118)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func stepperRow(label: String, value: Int, action: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            stepButton(systemName: "minus") { action(-1) }

            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.44))
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 54)

            stepButton(systemName: "plus") { action(1) }
        }
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(viewModel.controlsUnlocked && !viewModel.racing ? .black : .white.opacity(0.55))
                    .frame(width: 28, height: 28)
                    .background(viewModel.controlsUnlocked && !viewModel.racing ? accent : .white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.controlsUnlocked || viewModel.racing)
    }
}
