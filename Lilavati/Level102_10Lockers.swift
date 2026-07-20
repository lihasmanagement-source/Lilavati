import SwiftUI

@Observable
final class MathItLevelTwentyNineViewModel {
    var selectedNumbers: Set<Int> = []
    var openPlatforms: Set<Int> = []
    var ballOffsets: [Int: CGSize] = [:]
    var rejectedNumbers: Set<Int> = []
    var introRunning = false
    var predictionLocked = false
    var simulationRunning = false
    var simulationFinished = false
    var currentStudent = 1
    var currentLocker: Int?
    var completed = false
    var landingOffsets: [Int: CGSize] = [:]
    var closedPlatformDrop: CGFloat = 58
    var keyAssemblyProgress: CGFloat = 0
    var keyUnlockProgress: CGFloat = 0
    var keyTwistProgress: CGFloat = 0
    var whiteBallEscapeProgress: CGFloat = 0

    let solution: Set<Int> = [1, 4, 9]
    private var runID = UUID()

    var canPlay: Bool {
        !introRunning && !predictionLocked && !completed &&
            (selectedNumbers.isEmpty || selectedNumbers.count == 3)
    }

    var progress: Double {
        if completed { return 1 }
        if keyAssemblyProgress > 0 { return 0.94 + Double(keyUnlockProgress) * 0.05 }
        if simulationRunning { return min(0.92, Double(currentStudent) / 10) }
        if simulationFinished { return 0.98 }
        return min(0.26, Double(selectedNumbers.count) * 0.08)
    }

    func playIntro() {
        guard !introRunning, !predictionLocked, selectedNumbers.isEmpty else { return }
        introRunning = true
        currentStudent = 1
        currentLocker = nil
        openPlatforms.removeAll()
        let introID = UUID()
        runID = introID
        preview(student: 1, run: introID)
    }

    func togglePrediction(_ number: Int) {
        guard !introRunning, !predictionLocked, !completed else { return }
        HapticPlayer.playLightTap()
        if selectedNumbers.contains(number) {
            selectedNumbers.remove(number)
        } else if selectedNumbers.count < 3 {     // at most three picks
            selectedNumbers.insert(number)
        }
    }

    func lockPredictionAndSimulate() {
        guard !introRunning, !predictionLocked, !selectedNumbers.isEmpty else { return }
        predictionLocked = true
        simulationRunning = true
        currentStudent = 1
        HapticPlayer.playCompletionTap()
        let simulationID = UUID()
        runID = simulationID
        simulate(student: 1, run: simulationID)
    }

    func pressPlay() {
        if selectedNumbers.isEmpty {
            playIntro()
        } else {
            lockPredictionAndSimulate()
        }
    }

    func stop() {
        runID = UUID()
        simulationRunning = false
    }

    func configureLandingOffsets(
        firstX: CGFloat,
        step: CGFloat,
        targetCenterX: CGFloat,
        ballY: CGFloat,
        platformY: CGFloat,
        targetY: CGFloat
    ) {
        closedPlatformDrop = platformY - ballY - 14
        for (index, number) in [1, 4, 9].enumerated() {
            let sourceX = firstX + CGFloat(number - 1) * step
            let destinationX = targetCenterX + CGFloat(index - 1) * 98
            landingOffsets[number] = CGSize(
                width: destinationX - sourceX,
                height: targetY - ballY
            )
        }
    }

    private func simulate(student: Int, run: UUID) {
        guard run == runID, student <= 10 else {
            if run == runID { finishSimulation() }
            return
        }

        currentStudent = student
        let numbers = stride(from: student, through: 10, by: student).map { $0 }
        animateStudent(student, lockers: numbers, index: 0, run: run)
    }

    private func preview(student: Int, run: UUID) {
        guard run == runID else { return }
        guard student <= 10 else {
            currentLocker = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                guard self.runID == run else { return }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                    self.openPlatforms.removeAll()
                    self.currentStudent = 1
                    self.introRunning = false
                }
            }
            return
        }

        currentStudent = student
        let lockers = stride(from: student, through: 10, by: student).map { $0 }
        previewStudent(student, lockers: lockers, index: 0, run: run)
    }

    private func previewStudent(_ student: Int, lockers: [Int], index: Int, run: UUID) {
        guard run == runID else { return }
        guard index < lockers.count else {
            currentLocker = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                self.preview(student: student + 1, run: run)
            }
            return
        }

        let locker = lockers[index]
        withAnimation(.easeInOut(duration: 0.2)) {
            currentLocker = locker
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            guard self.runID == run else { return }
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.66)) {
                self.togglePlatforms([locker])
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                self.previewStudent(student, lockers: lockers, index: index + 1, run: run)
            }
        }
    }

    private func animateStudent(_ student: Int, lockers: [Int], index: Int, run: UUID) {
        guard run == runID else { return }
        guard index < lockers.count else {
            currentLocker = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                self.simulate(student: student + 1, run: run)
            }
            return
        }

        let locker = lockers[index]
        withAnimation(.easeInOut(duration: 0.24)) {
            currentLocker = locker
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard self.runID == run else { return }
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                self.togglePlatforms([locker])
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.animateStudent(student, lockers: lockers, index: index + 1, run: run)
            }
        }
    }

    private func finishSimulation() {
        simulationRunning = false
        simulationFinished = true
        currentStudent = 10
        currentLocker = nil
        let correctPredictions = selectedNumbers.intersection(solution)
        let wrongPredictions = selectedNumbers.subtracting(solution)

        for number in correctPredictions {
            let targetIndex = [1, 4, 9].firstIndex(of: number) ?? 0
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(targetIndex) * 0.22) {
                HapticPlayer.playLightTap()
                withAnimation(.easeIn(duration: 1.05)) {
                    self.ballOffsets[number] = self.landingOffsets[number, default: CGSize(
                        width: CGFloat(targetIndex - 1) * 98,
                        height: 350
                    )]
                }
            }
        }

        for (index, number) in wrongPredictions.sorted().enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(index) * 0.12) {
                withAnimation(.easeIn(duration: 0.46)) {
                    self.ballOffsets[number] = CGSize(width: 0, height: self.closedPlatformDrop)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                    HapticPlayer.playLightTap()
                    self.rejectedNumbers.insert(number)
                }
            }
        }

        let resultDelay = max(2.2, 0.5 + Double(wrongPredictions.count) * 0.12)
        DispatchQueue.main.asyncAfter(deadline: .now() + resultDelay) {
            guard self.selectedNumbers == self.solution else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    self.predictionLocked = false
                    self.simulationFinished = false
                    self.openPlatforms.removeAll()
                    self.ballOffsets.removeAll()
                    self.rejectedNumbers.removeAll()
                    self.selectedNumbers.removeAll()
                }
                return
            }

            self.assembleKey()
        }
    }

    private func assembleKey() {
        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
            keyAssemblyProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.easeInOut(duration: 1.1)) {
                self.keyUnlockProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.35) {
            HapticPlayer.playCompletionTap()
            withAnimation(.easeInOut(duration: 0.72)) {
                self.keyTwistProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            HapticPlayer.playCompletionTap()
            withAnimation(.easeInOut(duration: 2.2)) {
                self.whiteBallEscapeProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.55) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    private func togglePlatforms(_ numbers: [Int]) {
        for number in numbers {
            if openPlatforms.contains(number) {
                openPlatforms.remove(number)
            } else {
                openPlatforms.insert(number)
            }
        }
    }
}

struct MathItLevelTwentyNineView: View {
    var viewModel: MathItLevelTwentyNineViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let pink = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 18, y: size.height * 0.18, width: size.width - 36, height: min(610, size.height * 0.71))
            let spacing: CGFloat = 5
            let columnWidth = (board.width - 28 - spacing * 9) / 10
            let firstX = board.minX + 14 + columnWidth / 2
            let ballY = board.minY + 86
            let platformY = board.minY + 145
            let targetY = board.maxY - 170
            let socketY = targetY - 31
            let jailCenter = CGPoint(x: board.midX, y: board.maxY - 62)

            ZStack {
                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    EmptyView()
                        .font(.trajan(36))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(pink)
                    .opacity(0.78)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.012))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(pink.opacity(0.26), lineWidth: 1.1)
                    }
                    .frame(width: board.width, height: board.height)
                    .position(x: board.midX, y: board.midY)

                ForEach(1...10, id: \.self) { number in
                    let x = firstX + CGFloat(number - 1) * (columnWidth + spacing)
                    ballBox(number: number, width: columnWidth)
                        .position(x: x, y: ballY)

                    platform(number: number, width: columnWidth)
                        .position(x: x, y: platformY)

                    numberedBall(number)
                        .position(x: x, y: ballY)
                        .offset(viewModel.ballOffsets[number, default: .zero])
                        .onTapGesture {
                            viewModel.togglePrediction(number)
                        }
                        .zIndex(6)
                }

                if viewModel.simulationRunning || viewModel.introRunning {
                    if let locker = viewModel.currentLocker {
                        studentBall(viewModel.currentStudent)
                            .position(
                                x: firstX + CGFloat(locker - 1) * (columnWidth + spacing),
                                y: platformY + 46
                            )
                            .zIndex(8)
                    } else {
                        studentBall(viewModel.currentStudent)
                            .position(x: board.minX + 20, y: platformY + 46)
                            .zIndex(8)
                    }
                }

                resultTargets(y: targetY, centerX: board.midX, jailCenter: jailCenter)
                jail(center: jailCenter)

                Button(action: viewModel.pressPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(viewModel.canPlay ? .black : pink.opacity(0.34))
                        .frame(width: 58, height: 58)
                        .background(viewModel.canPlay ? pink : .black, in: Circle())
                        .overlay { Circle().stroke(pink.opacity(0.72), lineWidth: 1.3) }
                        .shadow(color: pink.opacity(viewModel.canPlay ? 0.62 : 0.12), radius: 14)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canPlay)
                .position(x: board.maxX - 42, y: board.minY + 40)
                .opacity(viewModel.predictionLocked ? 0 : 1)

                CompletionOverlay(
                    title: "Level 29 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .task {
                viewModel.configureLandingOffsets(
                    firstX: firstX,
                    step: columnWidth + spacing,
                    targetCenterX: board.midX,
                    ballY: ballY,
                    platformY: platformY,
                    targetY: socketY
                )
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }

    private func ballBox(number: Int, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(.black.opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        viewModel.selectedNumbers.contains(number) ? pink : pink.opacity(0.3),
                        lineWidth: viewModel.selectedNumbers.contains(number) ? 1.6 : 1
                    )
            }
            .frame(width: width, height: 52)
            .shadow(color: pink.opacity(viewModel.selectedNumbers.contains(number) ? 0.48 : 0), radius: 8)
    }

    private func numberedBall(_ number: Int) -> some View {
        Circle()
            .fill(viewModel.rejectedNumbers.contains(number) ? .white : pink)
            .overlay {
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 25, height: 25)
            .shadow(color: pink.opacity(0.72), radius: 8)
    }

    private func platform(number: Int, width: CGFloat) -> some View {
        let isOpen = viewModel.openPlatforms.contains(number)
        let doorWidth = max(14, width - 7)

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(pink)
                .frame(width: doorWidth, height: 3)
                .rotationEffect(.degrees(isOpen ? 86 : 0), anchor: .leading)
                .shadow(color: pink.opacity(0.72), radius: 7)

            Circle()
                .fill(.black)
                .overlay {
                    Circle().stroke(pink, lineWidth: 1.5)
                }
                .frame(width: 7, height: 7)
                .offset(x: -2)
                .shadow(color: pink.opacity(0.72), radius: 6)
        }
        .frame(width: width, height: width, alignment: .leading)
        .animation(.spring(response: 0.34, dampingFraction: 0.66), value: isOpen)
    }

    private func resultTargets(y: CGFloat, centerX: CGFloat, jailCenter: CGPoint) -> some View {
        let spacing: CGFloat = 98

        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let sourceX = centerX + CGFloat(index - 1) * spacing
                let assembledOffset: CGFloat = index == 0 ? -26 : (index == 1 ? 3 : 29)
                let angle = viewModel.keyTwistProgress * .pi / 2
                let rotatedOffset = CGPoint(
                    x: assembledOffset * cos(angle),
                    y: assembledOffset * sin(angle)
                )
                let assembledX = sourceX + (centerX + assembledOffset - sourceX) * viewModel.keyAssemblyProgress
                let lockY = jailCenter.y + 48
                resultBox()
                    .position(x: sourceX, y: y)

                keyFragment(index)
                    .position(
                        x: assembledX + (centerX + rotatedOffset.x - assembledX) * viewModel.keyUnlockProgress,
                        y: y + 8 + (lockY - (y + 8)) * viewModel.keyUnlockProgress + rotatedOffset.y
                    )
                    .rotationEffect(.radians(angle))
                    .zIndex(10)
            }
        }
    }

    private func resultBox() -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(.black)
                .overlay {
                    Circle()
                        .stroke(pink.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                .frame(width: 30, height: 30)
                .shadow(color: pink.opacity(0.38), radius: 7)

            RoundedRectangle(cornerRadius: 5)
                .fill(.black)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(pink.opacity(0.62), lineWidth: 1.2)
                }
                .frame(width: 70, height: 54)
        }
    }

    @ViewBuilder
    private func keyFragment(_ index: Int) -> some View {
        if index == 0 {
            Circle()
                .stroke(pink, lineWidth: 4)
                .frame(width: 23, height: 23)
                .overlay(alignment: .trailing) {
                    Capsule()
                        .fill(pink)
                        .frame(width: 19, height: 4)
                        .offset(x: 15)
                }
                .shadow(color: pink.opacity(0.7), radius: 6)
        } else if index == 1 {
            Capsule()
                .fill(pink)
                .frame(width: 35, height: 5)
                .shadow(color: pink.opacity(0.7), radius: 6)
        } else {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 3))
                path.addLine(to: CGPoint(x: 27, y: 3))
                path.addLine(to: CGPoint(x: 27, y: 15))
                path.addLine(to: CGPoint(x: 20, y: 15))
                path.addLine(to: CGPoint(x: 20, y: 9))
                path.addLine(to: CGPoint(x: 13, y: 9))
                path.addLine(to: CGPoint(x: 13, y: 15))
                path.addLine(to: CGPoint(x: 7, y: 15))
                path.addLine(to: CGPoint(x: 7, y: 3))
            }
            .stroke(pink, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .frame(width: 27, height: 18)
            .shadow(color: pink.opacity(0.7), radius: 6)
        }
    }

    private func jail(center: CGPoint) -> some View {
        let unlocked = viewModel.keyTwistProgress > 0.92
        let escape = viewModel.whiteBallEscapeProgress
        let hop = abs(sin(escape * .pi * 5)) * 20

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(pink.opacity(unlocked ? 0.05 : 0.13))
                .frame(width: 112, height: 80)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(pink.opacity(0.82), lineWidth: 1.7)
                }
                .shadow(color: pink.opacity(0.45), radius: 10)

            ForEach([-32, -11, 11, 32], id: \.self) { offset in
                Capsule()
                    .fill(pink.opacity(unlocked ? 0.2 : 0.72))
                    .frame(width: 3, height: 72)
                    .offset(x: CGFloat(offset), y: unlocked ? -68 : 0)
            }

            padlock(unlocked: unlocked)
                .offset(y: 48)

            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .shadow(color: .white.opacity(0.85), radius: 9)
                .offset(
                    x: escape * 210,
                    y: -hop
                )
                .opacity(escape < 0.99 ? 1 : 0)
        }
        .position(center)
    }

    private func padlock(unlocked: Bool) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 11, y: 22))
                path.addLine(to: CGPoint(x: 11, y: 13))
                path.addCurve(
                    to: CGPoint(x: 29, y: 13),
                    control1: CGPoint(x: 11, y: 0),
                    control2: CGPoint(x: 29, y: 0)
                )
                path.addLine(to: CGPoint(x: 29, y: 22))
            }
            .stroke(pink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(unlocked ? -32 : 0), anchor: .bottomLeading)

            RoundedRectangle(cornerRadius: 5)
                .fill(.black)
                .frame(width: 40, height: 30)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(pink, lineWidth: 2)
                }
                .offset(y: 14)

            Circle()
                .fill(pink)
                .frame(width: 7, height: 7)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(pink)
                        .frame(width: 3, height: 9)
                        .offset(y: 6)
                }
                .offset(y: 11)
        }
        .frame(width: 40, height: 52)
        .shadow(color: pink.opacity(0.75), radius: 7)
    }

    private func studentBall(_ student: Int) -> some View {
        ZStack {
            Circle()
                .fill(pink)
                .frame(width: 29, height: 29)
                .shadow(color: pink.opacity(0.86), radius: 10)

            Text("\(student)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .minimumScaleFactor(0.7)
        }
    }
}
