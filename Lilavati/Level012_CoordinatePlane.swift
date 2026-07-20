import SwiftUI
import Foundation

struct LevelFiftyTwoPoint: Equatable {
    let x: Double
    let y: Double
}

struct LevelFiftyTwoStage {
    let ball: LevelFiftyTwoPoint
    let goal: LevelFiftyTwoPoint
    let equations: [String]
    let correctIndex: Int
}

@Observable
final class MathItLevelFiftyTwoViewModel {
    let roundSeconds = 60
    let stages = [
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -4, y: 4),
            goal: LevelFiftyTwoPoint(x: 2, y: -2),
            equations: ["y = -x", "y = x", "y = -x + 2"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -4, y: 2),
            goal: LevelFiftyTwoPoint(x: 4, y: -2),
            equations: ["y = -2x", "y = -1/2x", "y = 1/2x"],
            correctIndex: 1
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -1, y: 4),
            goal: LevelFiftyTwoPoint(x: 2, y: -2),
            equations: ["y = -2x + 2", "y = -x + 3", "y = 2x - 2"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -5, y: 3),
            goal: LevelFiftyTwoPoint(x: 1, y: 0),
            equations: ["y = -1/2x + 1/2", "y = -x - 2", "y = 1/2x + 3"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -3, y: 5),
            goal: LevelFiftyTwoPoint(x: 3, y: -1),
            equations: ["y = -x + 2", "y = x + 8", "y = -2x - 1"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -5, y: 1),
            goal: LevelFiftyTwoPoint(x: 5, y: -4),
            equations: ["y = -1/2x - 3/2", "y = 1/2x - 3/2", "y = -x + 1"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -2, y: 5),
            goal: LevelFiftyTwoPoint(x: 4, y: 2),
            equations: ["y = -1/2x + 4", "y = -x + 3", "y = 1/2x + 6"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -4, y: 5),
            goal: LevelFiftyTwoPoint(x: 0, y: 1),
            equations: ["y = -x + 1", "y = x + 9", "y = -1/2x + 3"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: 0, y: 4),
            goal: LevelFiftyTwoPoint(x: 4, y: 0),
            equations: ["y = -x + 4", "y = x + 4", "y = -2x + 4"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -3, y: 4),
            goal: LevelFiftyTwoPoint(x: 1, y: -4),
            equations: ["y = -2x - 2", "y = -x + 1", "y = 2x + 10"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -5, y: 4),
            goal: LevelFiftyTwoPoint(x: 3, y: 0),
            equations: ["y = -1/2x + 3/2", "y = -x - 1", "y = 1/2x + 13/2"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -2, y: 3),
            goal: LevelFiftyTwoPoint(x: 4, y: -3),
            equations: ["y = -x + 1", "y = x + 5", "y = -1/2x + 2"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: 1, y: 5),
            goal: LevelFiftyTwoPoint(x: 5, y: -3),
            equations: ["y = -2x + 7", "y = -x + 6", "y = 2x + 3"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -4, y: 1),
            goal: LevelFiftyTwoPoint(x: 2, y: -5),
            equations: ["y = -x - 3", "y = x + 5", "y = -2x - 7"],
            correctIndex: 0
        ),
        LevelFiftyTwoStage(
            ball: LevelFiftyTwoPoint(x: -1, y: 5),
            goal: LevelFiftyTwoPoint(x: 5, y: 1),
            equations: ["y = -2/3x + 13/3", "y = -x + 4", "y = 2/3x + 17/3"],
            correctIndex: 0
        )
    ]

    var stageIndex = 0
    var solvedCount = 0
    var hearts = 3
    var timeRemaining = 60
    var selectedIndex: Int?
    var wrongPulse = false
    var rampVisible = false
    var ballProgress = 0.0
    var completed = false
    var restartingAfterFailure = false
    private var timer: Timer?
    private var sessionID = UUID()

    var currentStage: LevelFiftyTwoStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        let local = rampVisible ? ballProgress : 0
        return min(1, (Double(solvedCount) + local) / Double(stages.count))
    }

    var timeText: String {
        "0:\(String(format: "%02d", max(0, timeRemaining)))"
    }

    func start() {
        sessionID = UUID()
        cancelTimer()
        stageIndex = 0
        solvedCount = 0
        hearts = 3
        timeRemaining = roundSeconds
        selectedIndex = nil
        wrongPulse = false
        rampVisible = false
        ballProgress = 0
        completed = false
        restartingAfterFailure = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    func chooseEquation(_ index: Int) {
        guard !completed, !restartingAfterFailure, !rampVisible, timeRemaining > 0 else { return }
        selectedIndex = index

        guard index == currentStage.correctIndex else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.44)) {
                wrongPulse = true
                hearts = max(0, hearts - 1)
            }
            if hearts == 0 {
                restartAfterFailure()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    self.wrongPulse = false
                    self.selectedIndex = nil
                }
            }
            return
        }

        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            rampVisible = true
            wrongPulse = false
        }
        withAnimation(.easeInOut(duration: 1.35).delay(0.16)) {
            ballProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.74) {
            self.advance()
        }
    }

    func resetStage() {
        guard !completed, !restartingAfterFailure else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            selectedIndex = nil
            wrongPulse = false
            rampVisible = false
            ballProgress = 0
        }
    }

    private func advance() {
        guard !completed else { return }
        solvedCount += 1
        if stageIndex == stages.count - 1 {
            cancelTimer()
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                stageIndex += 1
                selectedIndex = nil
                wrongPulse = false
                rampVisible = false
                ballProgress = 0
            }
        }
    }

    private func tick() {
        guard !completed, !restartingAfterFailure else {
            cancelTimer()
            return
        }
        if timeRemaining <= 1 {
            timeRemaining = 0
            restartAfterFailure()
        } else {
            timeRemaining -= 1
        }
    }

    private func restartAfterFailure() {
        guard !completed, !restartingAfterFailure else { return }
        cancelTimer()
        restartingAfterFailure = true
        let token = sessionID

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            guard self.sessionID == token, self.restartingAfterFailure else { return }
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                self.start()
            }
        }
    }
}

struct MathItLevelFiftyTwoView: View {
    var viewModel: MathItLevelFiftyTwoViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let graphSize = min(size.width - 42, min(size.height * 0.52, 420))
            let graphRect = CGRect(
                x: (size.width - graphSize) / 2,
                y: size.height * 0.2,
                width: graphSize,
                height: graphSize
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                graph(rect: graphRect)

                equationChoices(size: size, graph: graphRect)

                Button(action: viewModel.resetStage) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.42), radius: 12)
                }
                .buttonStyle(.plain)
                .position(x: graphRect.maxX - 10, y: graphRect.maxY + 34)

                CompletionOverlay(
                    title: "Level 52 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancelTimer() }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            Text("ramping up")
                .font(.garamond(min(32, size.width * 0.075)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            Text(viewModel.timeText)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(viewModel.timeRemaining <= 10 ? .red.opacity(0.92) : accent)
                .shadow(color: viewModel.timeRemaining <= 10 ? .red.opacity(0.5) : accent.opacity(0.35), radius: 10)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < viewModel.hearts ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(index < viewModel.hearts ? .red.opacity(0.9) : .white.opacity(0.28))
                        .shadow(color: index < viewModel.hearts ? .red.opacity(0.45) : .clear, radius: 7)
                }
            }

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func graph(rect: CGRect) -> some View {
        let localRect = CGRect(origin: .zero, size: rect.size)
        let stage = viewModel.currentStage
        let start = screenPoint(stage.ball, in: localRect)
        let goal = screenPoint(stage.goal, in: localRect)
        let ball = interpolate(from: start, to: goal, progress: viewModel.ballProgress)
        let rampAngle = Angle(radians: Double(atan2(goal.y - start.y, goal.x - start.x)))

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.wrongPulse ? Color.red.opacity(0.78) : .white.opacity(0.18), lineWidth: viewModel.wrongPulse ? 2 : 1.2)
                .background(.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 8))

            coordinateGrid(rect: localRect)

            if viewModel.rampVisible {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: goal)
                }
                .stroke(accent.opacity(0.92), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .shadow(color: accent.opacity(0.7), radius: 14)
            }

            Circle()
                .stroke(.white.opacity(0.86), lineWidth: 2.4)
                .frame(width: 30, height: 30)
                .position(goal)
                .shadow(color: .white.opacity(0.34), radius: 10)

            LevelFiftyTwoSkater(accent: accent)
                .frame(width: 44, height: 44)
                .rotationEffect(rampAngle)
                .position(ball)
                .shadow(color: accent.opacity(0.62), radius: 10)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func coordinateGrid(rect: CGRect) -> some View {
        let unit = rect.width / 10

        return ZStack {
            ForEach(0...10, id: \.self) { index in
                let position = CGFloat(index) * unit
                Path { path in
                    path.move(to: CGPoint(x: position, y: 0))
                    path.addLine(to: CGPoint(x: position, y: rect.height))
                }
                .stroke(.white.opacity(index == 5 ? 0.52 : 0.12), lineWidth: index == 5 ? 1.6 : 0.8)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: position))
                    path.addLine(to: CGPoint(x: rect.width, y: position))
                }
                .stroke(.white.opacity(index == 5 ? 0.52 : 0.12), lineWidth: index == 5 ? 1.6 : 0.8)
            }
        }
    }

    private func equationChoices(size: CGSize, graph: CGRect) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(viewModel.currentStage.equations.enumerated()), id: \.offset) { index, equation in
                Button {
                    viewModel.chooseEquation(index)
                } label: {
                    Text(equation)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(width: min(size.width - 72, 260), height: 46)
                        .background(choiceColor(index), in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: choiceColor(index).opacity(0.36), radius: 10)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.rampVisible)
            }
        }
        .position(x: size.width / 2, y: min(size.height - 108, graph.maxY + 126))
    }

    private func choiceColor(_ index: Int) -> Color {
        if viewModel.selectedIndex == index && viewModel.wrongPulse {
            return .red
        }
        if viewModel.selectedIndex == index && viewModel.rampVisible {
            return accent
        }
        return .white.opacity(0.86)
    }

    private func screenPoint(_ point: LevelFiftyTwoPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.midX + CGFloat(point.x) * rect.width / 10,
            y: rect.midY - CGFloat(point.y) * rect.height / 10
        )
    }

    private func interpolate(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        let t = CGFloat(min(max(progress, 0), 1))
        return CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }
}

private struct LevelFiftyTwoSkater: View {
    let accent: Color

    var body: some View {
        Canvas { context, _ in
            let white = Color.white.opacity(0.96)

            var board = Path()
            board.move(to: CGPoint(x: 7, y: 25))
            board.addQuadCurve(to: CGPoint(x: 11, y: 27), control: CGPoint(x: 7, y: 28))
            board.addLine(to: CGPoint(x: 34, y: 27))
            board.addQuadCurve(to: CGPoint(x: 38, y: 24), control: CGPoint(x: 38, y: 28))
            context.stroke(board, with: .color(accent), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

            context.fill(Path(ellipseIn: CGRect(x: 12, y: 28, width: 5, height: 5)), with: .color(white))
            context.fill(Path(ellipseIn: CGRect(x: 30, y: 28, width: 5, height: 5)), with: .color(white))

            var body = Path()
            body.move(to: CGPoint(x: 22, y: 15))
            body.addLine(to: CGPoint(x: 18, y: 8))
            body.move(to: CGPoint(x: 21, y: 15))
            body.addLine(to: CGPoint(x: 13, y: 24))
            body.move(to: CGPoint(x: 21, y: 15))
            body.addLine(to: CGPoint(x: 31, y: 24))
            body.move(to: CGPoint(x: 19, y: 10))
            body.addLine(to: CGPoint(x: 11, y: 15))
            body.move(to: CGPoint(x: 19, y: 10))
            body.addLine(to: CGPoint(x: 28, y: 12))
            context.stroke(body, with: .color(white), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))

            context.fill(Path(ellipseIn: CGRect(x: 14, y: 2, width: 8, height: 8)), with: .color(white))
            context.fill(Path(ellipseIn: CGRect(x: 14.8, y: 2.8, width: 6.4, height: 3)), with: .color(accent))
        }
        .accessibilityHidden(true)
    }
}
