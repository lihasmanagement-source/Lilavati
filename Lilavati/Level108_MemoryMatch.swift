import SwiftUI
import Foundation

struct LevelSixtyCell: Hashable {
    let x: Int
    let y: Int
}

struct LevelSixtyStage {
    let sequence: [LevelSixtyCell]

    var target: Set<LevelSixtyCell> {
        Set(sequence)
    }
}

@Observable
final class MathItLevelSixtyViewModel {
    let stages = [
        LevelSixtyStage(sequence: [
            LevelSixtyCell(x: 2, y: 1),
            LevelSixtyCell(x: 2, y: 2), LevelSixtyCell(x: 1, y: 2), LevelSixtyCell(x: 3, y: 2),
            LevelSixtyCell(x: 4, y: 2), LevelSixtyCell(x: 2, y: 3), LevelSixtyCell(x: 2, y: 2)
        ]),
        LevelSixtyStage(sequence: [
            LevelSixtyCell(x: 1, y: 1),
            LevelSixtyCell(x: 1, y: 2), LevelSixtyCell(x: 2, y: 2),
            LevelSixtyCell(x: 3, y: 2),
            LevelSixtyCell(x: 3, y: 3), LevelSixtyCell(x: 3, y: 4),
            LevelSixtyCell(x: 3, y: 2), LevelSixtyCell(x: 1, y: 2)
        ]),
        LevelSixtyStage(sequence: [
            LevelSixtyCell(x: 2, y: 0),
            LevelSixtyCell(x: 2, y: 1),
            LevelSixtyCell(x: 2, y: 2),
            LevelSixtyCell(x: 1, y: 2), LevelSixtyCell(x: 3, y: 2),
            LevelSixtyCell(x: 1, y: 3),
            LevelSixtyCell(x: 2, y: 2), LevelSixtyCell(x: 2, y: 1), LevelSixtyCell(x: 3, y: 2)
        ])
    ]

    var stageIndex = 0
    var placed: Set<LevelSixtyCell> = []
    var matchedSequence: [LevelSixtyCell] = []
    var inputIndex = 0
    var previewCell: LevelSixtyCell?
    var tapFlashCell: LevelSixtyCell?
    var previewing = true
    var wrongPulse = false
    var completed = false
    var advancing = false

    var currentStage: LevelSixtyStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        let local = Double(inputIndex) / Double(max(1, currentStage.sequence.count))
        return (Double(stageIndex) + local) / Double(stages.count)
    }

    func tap(_ cell: LevelSixtyCell) {
        guard !completed, !advancing, !previewing else { return }
        guard currentStage.sequence.indices.contains(inputIndex), cell == currentStage.sequence[inputIndex] else {
            reject()
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            matchedSequence.append(cell)
            placed.insert(cell)
            tapFlashCell = cell
            inputIndex += 1
            wrongPulse = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if self.tapFlashCell == cell {
                withAnimation(.easeOut(duration: 0.12)) {
                    self.tapFlashCell = nil
                }
            }
        }

        if inputIndex == currentStage.sequence.count {
            advancing = true
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                self.advance()
            }
        }
    }

    func resetStage() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            placed.removeAll()
            matchedSequence.removeAll()
            inputIndex = 0
            previewCell = nil
            tapFlashCell = nil
            previewing = false
            wrongPulse = false
            advancing = false
        }
        playPreview()
    }

    func playPreview() {
        guard !completed else { return }
        placed.removeAll()
        matchedSequence.removeAll()
        inputIndex = 0
        previewCell = nil
        tapFlashCell = nil
        previewing = true

        let stepDelay = 0.34
        for (index, cell) in currentStage.sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * stepDelay) {
                guard self.previewing, self.stageIndex < self.stages.count else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    self.previewCell = cell
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(currentStage.sequence.count) * stepDelay + 0.24) {
            guard self.previewing else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                self.previewCell = nil
                self.tapFlashCell = nil
                self.previewing = false
            }
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
                placed.removeAll()
                matchedSequence.removeAll()
                inputIndex = 0
                previewCell = nil
                tapFlashCell = nil
                previewing = false
                wrongPulse = false
                advancing = false
            }
            playPreview()
        }
    }

    private func reject() {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.44)) {
            wrongPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                self.placed.removeAll()
                self.matchedSequence.removeAll()
                self.inputIndex = 0
                self.tapFlashCell = nil
                self.wrongPulse = false
            }
            self.playPreview()
        }
    }
}

struct MathItLevelSixtyView: View {
    var viewModel: MathItLevelSixtyViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry
    private let gridCount = 5

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSize = min(size.width - 40, min(size.height * 0.52, 420))
            let boardRect = CGRect(
                x: (size.width - boardSize) / 2,
                y: size.height * 0.22,
                width: boardSize,
                height: boardSize
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                netBoard(rect: boardRect)

                Button(action: viewModel.resetStage) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.45), radius: 12)
                }
                .buttonStyle(.plain)
                .position(x: boardRect.maxX - 14, y: boardRect.maxY + 38)

                CompletionOverlay(
                    title: "Level 60 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
        .onAppear {
            viewModel.playPreview()
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

                EmptyView()
                .font(.garamond(min(32, size.width * 0.073)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            Text(viewModel.previewing ? "watch" : "match")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(viewModel.wrongPulse ? .red.opacity(0.9) : accent)
                .shadow(color: viewModel.wrongPulse ? .red.opacity(0.45) : accent.opacity(0.34), radius: 8)

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func netBoard(rect: CGRect) -> some View {
        let localRect = CGRect(origin: .zero, size: rect.size)
        let cellSize = localRect.width / CGFloat(gridCount)

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.wrongPulse ? Color.red.opacity(0.82) : .white.opacity(0.18), lineWidth: viewModel.wrongPulse ? 2 : 1.2)
                .background(.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 8))

            gridLines(rect: localRect)

            ForEach(0..<gridCount, id: \.self) { y in
                ForEach(0..<gridCount, id: \.self) { x in
                    let cell = LevelSixtyCell(x: x, y: y)
                    let frame = CGRect(
                        x: CGFloat(x) * cellSize,
                        y: CGFloat(y) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    cellView(cell, frame: frame)
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    let column = Int(value.location.x / cellSize)
                    let row = Int(value.location.y / cellSize)
                    guard (0..<gridCount).contains(column), (0..<gridCount).contains(row) else { return }
                    viewModel.tap(LevelSixtyCell(x: column, y: row))
                }
        )
        .position(x: rect.midX, y: rect.midY)
        .offset(x: viewModel.wrongPulse ? -7 : 0)
        .animation(.linear(duration: 0.06).repeatCount(5, autoreverses: true), value: viewModel.wrongPulse)
    }

    private func gridLines(rect: CGRect) -> some View {
        let cellSize = rect.width / CGFloat(gridCount)

        return Path { path in
            for index in 0...gridCount {
                let position = CGFloat(index) * cellSize
                path.move(to: CGPoint(x: position, y: 0))
                path.addLine(to: CGPoint(x: position, y: rect.height))
                path.move(to: CGPoint(x: 0, y: position))
                path.addLine(to: CGPoint(x: rect.width, y: position))
            }
        }
        .stroke(.white.opacity(0.1), lineWidth: 1)
    }

    private func cellView(_ cell: LevelSixtyCell, frame: CGRect) -> some View {
        let isPlaced = viewModel.placed.contains(cell)
        let isPreview = viewModel.previewCell == cell
        let isTapFlash = viewModel.tapFlashCell == cell

        return ZStack {
            if isPlaced || isPreview || isTapFlash {
                RoundedRectangle(cornerRadius: 6)
                    .fill(accent.opacity((isPreview || isTapFlash) ? 0.62 : 0.32))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.95), lineWidth: (isPreview || isTapFlash) ? 3 : 2.2))
                    .frame(width: frame.width * 0.86, height: frame.height * 0.86)
                    .shadow(color: accent.opacity((isPreview || isTapFlash) ? 0.78 : 0.45), radius: (isPreview || isTapFlash) ? 18 : 11)

                faceMark(in: CGSize(width: frame.width * 0.86, height: frame.height * 0.86))
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .allowsHitTesting(false)
    }

    private func faceMark(in size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.32))
            path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.32))
            path.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.68))
            path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.68))
        }
        .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        .frame(width: size.width, height: size.height)
    }
}
