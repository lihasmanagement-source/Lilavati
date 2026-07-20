import SwiftUI
import Foundation

struct LevelFiftySevenPoint: Equatable {
    var x: Int
    var y: Int
}

struct LevelFiftySevenStage {
    let start: [LevelFiftySevenPoint]
    let target: [LevelFiftySevenPoint]
    let minimumMoves: Int
}

private enum LevelFiftySevenMovement {
    case up, down, left, right, rotate
}

@Observable
final class MathItLevelFiftySevenViewModel {
    let stages = [
        LevelFiftySevenStage(
            start: [
                LevelFiftySevenPoint(x: -5, y: -2),
                LevelFiftySevenPoint(x: -3, y: -2),
                LevelFiftySevenPoint(x: -4, y: 0)
            ],
            target: [
                LevelFiftySevenPoint(x: -1, y: 0),
                LevelFiftySevenPoint(x: 1, y: 0),
                LevelFiftySevenPoint(x: 0, y: 2)
            ],
            minimumMoves: 6
        ),
        LevelFiftySevenStage(
            start: [
                LevelFiftySevenPoint(x: -4, y: 2),
                LevelFiftySevenPoint(x: -2, y: 2),
                LevelFiftySevenPoint(x: -4, y: 4)
            ],
            target: [
                LevelFiftySevenPoint(x: 1, y: 2),
                LevelFiftySevenPoint(x: 1, y: 0),
                LevelFiftySevenPoint(x: 3, y: 2)
            ],
            minimumMoves: 6
        ),
        LevelFiftySevenStage(
            start: [
                LevelFiftySevenPoint(x: -2, y: 4),
                LevelFiftySevenPoint(x: 0, y: 4),
                LevelFiftySevenPoint(x: -2, y: 6)
            ],
            target: [
                LevelFiftySevenPoint(x: 0, y: 1),
                LevelFiftySevenPoint(x: 0, y: -1),
                LevelFiftySevenPoint(x: 2, y: 1)
            ],
            minimumMoves: 6
        ),
        LevelFiftySevenStage(
            start: [
                LevelFiftySevenPoint(x: -5, y: 1),
                LevelFiftySevenPoint(x: -3, y: 1),
                LevelFiftySevenPoint(x: -3, y: 2),
                LevelFiftySevenPoint(x: -5, y: 3)
            ],
            target: [
                LevelFiftySevenPoint(x: 2, y: 2),
                LevelFiftySevenPoint(x: 2, y: 0),
                LevelFiftySevenPoint(x: 3, y: 0),
                LevelFiftySevenPoint(x: 4, y: 2)
            ],
            minimumMoves: 9
        )
    ]

    var stageIndex = 0
    var currentShape: [LevelFiftySevenPoint] = []
    var moveCount = 0
    var upUnits = 0
    var downUnits = 0
    var leftUnits = 0
    var rightUnits = 0
    var rotationCount = 0
    var wrongPulse = false
    var budgetExhausted = false
    var completed = false
    var advancing = false
    private var resetToken = UUID()

    init() {
        currentShape = stages[0].start
    }

    var currentStage: LevelFiftySevenStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        let local = normalized(currentShape) == normalized(currentStage.target)
            ? 1
            : min(0.92, Double(moveCount) / Double(currentStage.minimumMoves))
        return (Double(stageIndex) + local) / Double(stages.count)
    }

    var movesRemaining: Int {
        max(0, currentStage.minimumMoves - moveCount)
    }

    func shift(dx: Int, dy: Int) {
        guard !completed, !advancing else { return }
        guard moveCount < currentStage.minimumMoves else {
            rejectBudget()
            return
        }
        let next = currentShape.map { LevelFiftySevenPoint(x: $0.x + dx, y: $0.y + dy) }
        let movement: LevelFiftySevenMovement
        if dx > 0 {
            movement = .right
        } else if dx < 0 {
            movement = .left
        } else if dy > 0 {
            movement = .up
        } else {
            movement = .down
        }
        commit(next, movement: movement)
    }

    func rotateClockwise() {
        guard !completed, !advancing, let pivot = currentShape.first else { return }
        guard moveCount < currentStage.minimumMoves else {
            rejectBudget()
            return
        }
        let next = currentShape.map { point in
            let relativeX = point.x - pivot.x
            let relativeY = point.y - pivot.y
            return LevelFiftySevenPoint(x: pivot.x + relativeY, y: pivot.y - relativeX)
        }
        commit(next, movement: .rotate)
    }

    func resetStage() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            currentShape = currentStage.start
            resetMoveTracking()
            advancing = false
        }
    }

    private func commit(_ next: [LevelFiftySevenPoint], movement: LevelFiftySevenMovement) {
        guard next.allSatisfy({ (-6...6).contains($0.x) && (-6...6).contains($0.y) }) else {
            reject()
            return
        }

        let matchedTarget = normalized(next) == normalized(currentStage.target)
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            currentShape = next
            moveCount += 1
            record(movement)
            wrongPulse = false
            budgetExhausted = false
        }

        if matchedTarget {
            advancing = true
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                self.advance()
            }
        } else if moveCount >= currentStage.minimumMoves {
            rejectBudget()
        }
    }

    private func advance() {
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                stageIndex += 1
                currentShape = stages[stageIndex].start
                resetMoveTracking()
                advancing = false
            }
        }
    }

    private func record(_ movement: LevelFiftySevenMovement) {
        switch movement {
        case .up: upUnits += 1
        case .down: downUnits += 1
        case .left: leftUnits += 1
        case .right: rightUnits += 1
        case .rotate: rotationCount += 1
        }
    }

    private func resetMoveTracking() {
        resetToken = UUID()
        moveCount = 0
        upUnits = 0
        downUnits = 0
        leftUnits = 0
        rightUnits = 0
        rotationCount = 0
        wrongPulse = false
        budgetExhausted = false
    }

    private func rejectBudget() {
        guard !advancing else { return }
        let token = UUID()
        resetToken = token
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.44)) {
            wrongPulse = true
            budgetExhausted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            guard self.resetToken == token, !self.advancing else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                self.currentShape = self.currentStage.start
                self.resetMoveTracking()
            }
        }
    }

    private func reject() {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.44)) {
            wrongPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                self.wrongPulse = false
            }
        }
    }

    private func normalized(_ points: [LevelFiftySevenPoint]) -> [LevelFiftySevenPoint] {
        points.sorted {
            if $0.x == $1.x { return $0.y < $1.y }
            return $0.x < $1.x
        }
    }
}

struct MathItLevelFiftySevenView: View {
    var viewModel: MathItLevelFiftySevenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSize = min(size.width - 40, min(size.height * 0.5, 420))
            let boardRect = CGRect(
                x: (size.width - boardSize) / 2,
                y: size.height * 0.23,
                width: boardSize,
                height: boardSize
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                transformBoard(rect: boardRect)

                controls(size: size, board: boardRect)

                Button(action: viewModel.resetStage) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.45), radius: 12)
                }
                .buttonStyle(.plain)
                .position(x: boardRect.maxX - 12, y: boardRect.maxY + 36)

                CompletionOverlay(
                    title: "Level 57 Completed",
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
        VStack(spacing: 7) {
            EmptyView()
                .font(.garamond(min(31, size.width * 0.068)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            HStack(spacing: 0) {
                moveCounter(
                    label: "MOVES USED",
                    value: "\(viewModel.moveCount) / \(viewModel.currentStage.minimumMoves)",
                    color: viewModel.budgetExhausted ? .red : .white
                )

                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 1, height: 35)

                moveCounter(
                    label: "MAXIMUM MOVES",
                    value: "\(viewModel.currentStage.minimumMoves)",
                    color: Color.mathGold
                )

                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 1, height: 35)

                moveCounter(
                    label: "MOVES LEFT",
                    value: "\(viewModel.movesRemaining)",
                    color: viewModel.budgetExhausted ? .red : accent
                )
            }
            .padding(.vertical, 7)
            .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.mathGold.opacity(0.42), lineWidth: 1)
            }

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 96)
    }

    private func moveCounter(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.52))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(width: 100)
    }

    private func transformBoard(rect: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.wrongPulse ? Color.red.opacity(0.8) : .white.opacity(0.18), lineWidth: viewModel.wrongPulse ? 2 : 1.2)
                .background(.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 8))

            coordinateGrid(rect: CGRect(origin: .zero, size: rect.size))

            polygon(points: viewModel.currentStage.target, in: CGRect(origin: .zero, size: rect.size), color: .white.opacity(0.22), stroke: .white.opacity(0.62), dashed: true)
            polygon(points: viewModel.currentShape, in: CGRect(origin: .zero, size: rect.size), color: accent.opacity(0.3), stroke: accent, dashed: false)

            ForEach(viewModel.currentShape.indices, id: \.self) { index in
                let position = screenPoint(for: viewModel.currentShape[index], in: CGRect(origin: .zero, size: rect.size))
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .position(position)
                    .shadow(color: .white.opacity(0.7), radius: 7)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func coordinateGrid(rect: CGRect) -> some View {
        let unit = rect.width / 12

        return ZStack {
            ForEach(0...12, id: \.self) { index in
                let position = CGFloat(index) * unit
                Path { path in
                    path.move(to: CGPoint(x: position, y: 0))
                    path.addLine(to: CGPoint(x: position, y: rect.height))
                }
                .stroke(.white.opacity(index == 6 ? 0.55 : 0.12), lineWidth: index == 6 ? 1.6 : 0.8)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: position))
                    path.addLine(to: CGPoint(x: rect.width, y: position))
                }
                .stroke(.white.opacity(index == 6 ? 0.55 : 0.12), lineWidth: index == 6 ? 1.6 : 0.8)
            }
        }
    }

    private func polygon(points: [LevelFiftySevenPoint], in rect: CGRect, color: Color, stroke: Color, dashed: Bool) -> some View {
        let mapped = points.map { screenPoint(for: $0, in: rect) }

        return Path { path in
            guard let first = mapped.first else { return }
            path.move(to: first)
            for point in mapped.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        .fill(color)
        .overlay {
            Path { path in
                guard let first = mapped.first else { return }
                path.move(to: first)
                for point in mapped.dropFirst() {
                    path.addLine(to: point)
                }
                path.closeSubpath()
            }
            .stroke(stroke, style: StrokeStyle(lineWidth: 2.4, lineJoin: .round, dash: dashed ? [7, 6] : []))
        }
        .shadow(color: stroke.opacity(dashed ? 0.18 : 0.48), radius: dashed ? 6 : 14)
    }

    private func controls(size: CGSize, board: CGRect) -> some View {
        HStack(spacing: 28) {
            arrowPad
            rotateButton
        }
        .position(x: size.width / 2, y: min(size.height - 90, board.maxY + 116))
    }

    private var arrowPad: some View {
        VStack(spacing: 8) {
            directionPadButton(systemName: "chevron.up", units: viewModel.upUnits, badgeOffset: CGSize(width: 53, height: 0)) {
                viewModel.shift(dx: 0, dy: 1)
            }

            HStack(spacing: 8) {
                directionPadButton(systemName: "chevron.left", units: viewModel.leftUnits, badgeOffset: CGSize(width: -53, height: 0)) {
                    viewModel.shift(dx: -1, dy: 0)
                }

                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 1.3)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text("1u")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                directionPadButton(systemName: "chevron.right", units: viewModel.rightUnits, badgeOffset: CGSize(width: 53, height: 0)) {
                    viewModel.shift(dx: 1, dy: 0)
                }
            }

            directionPadButton(systemName: "chevron.down", units: viewModel.downUnits, badgeOffset: CGSize(width: 53, height: 0)) {
                viewModel.shift(dx: 0, dy: -1)
            }
        }
    }

    private var rotateButton: some View {
        Button {
            viewModel.rotateClockwise()
        } label: {
            Image(systemName: "rotate.right")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 70, height: 70)
                .background(accent, in: Circle())
                .shadow(color: accent.opacity(0.38), radius: 14)
        }
        .buttonStyle(.plain)
    }

    private func directionPadButton(
        systemName: String,
        units: Int,
        badgeOffset: CGSize,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 46, height: 46)
                .background(accent, in: Circle())
                .shadow(color: accent.opacity(0.34), radius: 10)
                .overlay {
                    Text("\(units) UNITS")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(units > 0 ? .white : .white.opacity(0.48))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(accent.opacity(units > 0 ? 0.72 : 0.26), lineWidth: 1)
                        }
                        .offset(badgeOffset)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Move \(systemName), \(units) units traveled")
    }

    private func screenPoint(for point: LevelFiftySevenPoint, in rect: CGRect) -> CGPoint {
        let unit = rect.width / 12
        return CGPoint(
            x: rect.midX + CGFloat(point.x) * unit,
            y: rect.midY - CGFloat(point.y) * unit
        )
    }
}
