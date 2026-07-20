import SwiftUI

struct MathItNoContactView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void
    let levelTitle: String
    let eyebrow: String?
    let completionTitle: String

    init(
        onContinue: @escaping () -> Void,
        onLevelSelect: @escaping () -> Void,
        levelTitle: String = "NO CONTACT",
        eyebrow: String? = nil,
        completionTitle: String = "Level 80 Completed"
    ) {
        self.onContinue = onContinue
        self.onLevelSelect = onLevelSelect
        self.levelTitle = levelTitle
        self.eyebrow = eyebrow
        self.completionTitle = completionTitle
    }

    @State private var stageIndex = 0
    @State private var rooks: Set<RookCell> = []
    @State private var failingCells: Set<RookCell> = []
    @State private var recentCell: RookCell?
    @State private var advancingStage = false
    @State private var completed = false
    @State private var ballTravel = false

    private let stages = TouchStage.stages
    private var stage: TouchStage { stages[stageIndex] }
    private var boardSize: Int { stage.size }
    private var requiredRooks: Int { stage.requiredDots }

    private var conflicts: Set<RookCell> {
        var result = Set<RookCell>()
        for first in rooks {
            for second in rooks where first != second {
                if cellsConflict(first, second) {
                    result.insert(first)
                    result.insert(second)
                }
            }
        }
        return result
    }

    private var conflictPairs: [(RookCell, RookCell)] {
        let sorted = rooks.sorted()
        var pairs: [(RookCell, RookCell)] = []
        for leftIndex in sorted.indices {
            for rightIndex in sorted.indices where rightIndex > leftIndex {
                let first = sorted[leftIndex]
                let second = sorted[rightIndex]
                if cellsConflict(first, second) {
                    pairs.append((first, second))
                }
            }
        }
        return pairs
    }

    private var progressValue: Double {
        let finished = stages.prefix(stageIndex).reduce(0) { $0 + $1.requiredDots }
        let total = stages.reduce(0) { $0 + $1.requiredDots }
        return Double(finished + min(rooks.count, requiredRooks)) / Double(total)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    VStack(spacing: 7) {
                        if let eyebrow {
                            Text(eyebrow)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .tracking(3)
                                .foregroundStyle(Color.mathGold.opacity(0.85))
                        }

                        EmptyView()
                            .font(.trajan(31))
                            .tracking(1.6)
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)

                    }
                    .padding(.horizontal, 58)

                    rookBoard
                        .frame(height: min(600, proxy.size.height * 0.7))
                        .padding(.horizontal, 18)

                    HStack(spacing: 14) {
                        ProgressView(value: completed ? 1 : progressValue)
                            .tint(accent)

                        Button(action: resetStage) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(accent)
                                .frame(width: 58, height: 48)
                                .background(.black.opacity(0.72), in: Capsule())
                                .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.top, 38)
                .padding(.bottom, 76)

                CompletionOverlay(
                    title: completionTitle,
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var rookBoard: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSide = min(size.width * 0.86, size.height * 0.76)
            let cell = boardSide / CGFloat(boardSize)
            let origin = CGPoint(x: (size.width - boardSide) / 2, y: size.height * 0.12)
            let ballStart = CGPoint(x: origin.x + cell * 0.45, y: origin.y + boardSide + cell * 0.7)
            let ballEnd = CGPoint(x: origin.x + boardSide - cell * 0.45, y: origin.y + boardSide + cell * 0.7)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(completed ? 0.16 : 0.07), Color(red: 0.012, green: 0.014, blue: 0.018), .black],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(size.width, size.height) * 0.72
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(completed ? 0.26 : 0.12), lineWidth: 1.2))

                boardGrid(origin: origin, side: boardSide, cell: cell)

                if let recentCell, !completed {
                    rookSightLines(cell: recentCell, origin: origin, boardSide: boardSide, cellSize: cell)
                }

                ForEach(conflictPairs.indices, id: \.self) { index in
                    let pair = conflictPairs[index]
                    Path { path in
                        path.move(to: center(of: pair.0, origin: origin, cell: cell))
                        path.addLine(to: center(of: pair.1, origin: origin, cell: cell))
                    }
                    .stroke(.red.opacity(0.82), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }

                ForEach(Array(rooks).sorted(), id: \.self) { rook in
                    let conflicting = conflicts.contains(rook) || failingCells.contains(rook)
                    rookMarker(rook, cellSize: cell, conflicting: conflicting)
                        .position(center(of: rook, origin: origin, cell: cell))
                }

                ForEach(0..<boardSize, id: \.self) { row in
                    ForEach(0..<boardSize, id: \.self) { column in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .frame(width: cell, height: cell)
                            .position(x: origin.x + CGFloat(column) * cell + cell / 2, y: origin.y + CGFloat(row) * cell + cell / 2)
                            .onTapGesture {
                                toggle(RookCell(row: row, column: column))
                            }
                    }
                }

                if completed {
                    Path { path in
                        path.move(to: ballStart)
                        path.addLine(to: ballEnd)
                    }
                    .stroke(accent.opacity(0.62), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                    Circle()
                        .stroke(.white.opacity(0.88), lineWidth: 4)
                        .frame(width: 52, height: 52)
                        .position(ballEnd)
                }

                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .white.opacity(0.9), radius: 12)
                    .opacity(completed ? 1 : 0)
                    .position(ballTravel ? ballEnd : ballStart)
                    .animation(.easeInOut(duration: 1.0), value: ballTravel)
            }
        }
    }

    private func boardGrid(origin: CGPoint, side: CGFloat, cell: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.46))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.34), lineWidth: 1.4))
                .frame(width: side, height: side)
                .position(x: origin.x + side / 2, y: origin.y + side / 2)

            Path { path in
                for index in 1..<boardSize {
                    let offset = CGFloat(index) * cell
                    path.move(to: CGPoint(x: origin.x + offset, y: origin.y))
                    path.addLine(to: CGPoint(x: origin.x + offset, y: origin.y + side))
                    path.move(to: CGPoint(x: origin.x, y: origin.y + offset))
                    path.addLine(to: CGPoint(x: origin.x + side, y: origin.y + offset))
                }
            }
            .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func rookMarker(_ rook: RookCell, cellSize: CGFloat, conflicting: Bool) -> some View {
        Image(systemName: "crown.fill")
            .font(.system(size: cellSize * 0.24, weight: .black))
            .foregroundStyle(conflicting ? .white : .black)
            .frame(width: cellSize * 0.42, height: cellSize * 0.42)
            .background(conflicting ? Color.red : Color.white, in: Circle())
            .shadow(color: (conflicting ? Color.red : Color.white).opacity(0.8), radius: conflicting ? 12 : 10)
            .scaleEffect(conflicting ? 1.12 : 1)
            .animation(.easeInOut(duration: 0.2).repeatCount(conflicting ? 2 : 1, autoreverses: true), value: conflicts)
    }

    private func rookSightLines(cell rook: RookCell, origin: CGPoint, boardSide: CGFloat, cellSize: CGFloat) -> some View {
        let c = center(of: rook, origin: origin, cell: cellSize)
        return Path { path in
            path.move(to: CGPoint(x: origin.x, y: c.y))
            path.addLine(to: CGPoint(x: origin.x + boardSide, y: c.y))
            path.move(to: CGPoint(x: c.x, y: origin.y))
            path.addLine(to: CGPoint(x: c.x, y: origin.y + boardSide))
        }
        .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 8]))
    }

    private func toggle(_ cell: RookCell) {
        guard !completed, !advancingStage else { return }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            if rooks.contains(cell) {
                rooks.remove(cell)
                failingCells = []
            } else if rooks.count < requiredRooks {
                rooks.insert(cell)
                recentCell = cell
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if !conflicts.isEmpty {
                failStage()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            if recentCell == cell {
                recentCell = nil
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            checkCompletion()
        }
    }

    private func checkCompletion() {
        guard rooks.count == requiredRooks, conflicts.isEmpty else { return }
        advanceStage()
    }

    private func advanceStage() {
        advancingStage = true
        if stageIndex < stages.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                    stageIndex += 1
                    rooks = []
                    failingCells = []
                    recentCell = nil
                    advancingStage = false
                }
            }
        } else {
            finishLevel()
        }
    }

    private func failStage() {
        let badCells = conflicts
        failingCells = badCells
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                rooks = []
                failingCells = []
                recentCell = nil
            }
        }
    }

    private func finishLevel() {
        withAnimation(.easeInOut(duration: 0.42)) {
            completed = true
            recentCell = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            ballTravel = true
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            rooks = []
            failingCells = []
            recentCell = nil
            stageIndex = 0
            advancingStage = false
            completed = false
            ballTravel = false
        }
    }

    private func resetStage() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            rooks = []
            failingCells = []
            recentCell = nil
            advancingStage = false
        }
    }

    private func cellsConflict(_ first: RookCell, _ second: RookCell) -> Bool {
        first.row == second.row
            || first.column == second.column
            || abs(first.row - second.row) == abs(first.column - second.column)
    }

    private func center(of cellValue: RookCell, origin: CGPoint, cell: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(cellValue.column) * cell + cell / 2, y: origin.y + CGFloat(cellValue.row) * cell + cell / 2)
    }
}

private struct RookCell: Hashable, Comparable {
    let row: Int
    let column: Int

    static func < (lhs: RookCell, rhs: RookCell) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }
}

private struct TouchStage {
    let size: Int
    let requiredDots: Int

    static let stages: [TouchStage] = [
        TouchStage(size: 4, requiredDots: 4),
        TouchStage(size: 5, requiredDots: 5),
        TouchStage(size: 6, requiredDots: 6)
    ]
}
