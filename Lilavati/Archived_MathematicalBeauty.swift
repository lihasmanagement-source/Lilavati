import SwiftUI

struct MathItLevelEightyOneView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var paths: [FlowColor: [FlowCell]] = [:]
    @State private var activeColor: FlowColor?
    @State private var lastDragCell: FlowCell?
    @State private var wrongCells: Set<FlowCell> = []
    @State private var advancingStage = false
    @State private var completed = false

    private let puzzles = FlowPuzzle.levelEightyOneStages
    private var puzzle: FlowPuzzle { puzzles[stageIndex] }

    private var filledCells: Set<FlowCell> {
        Set(paths.values.flatMap { $0 })
    }

    private var progressValue: Double {
        let finished = puzzles.prefix(stageIndex).reduce(0) { $0 + $1.size * $1.size }
        let total = puzzles.reduce(0) { $0 + $1.size * $1.size }
        return Double(finished + filledCells.count) / Double(total)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    VStack(spacing: 7) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        Text("PAINT WITH NUMBERS")
                            .font(.trajan(34))
                            .tracking(2)
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                    }
                    .padding(.horizontal, 58)

                    flowBoard
                        .frame(height: min(600, proxy.size.height * 0.7))
                        .padding(.horizontal, 18)

                    HStack(spacing: 14) {
                        ProgressView(value: completed ? 1 : progressValue)
                            .tint(accent)

                        Button(action: reset) {
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
                    title: "Level 81 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var flowBoard: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSide = min(size.width * 0.86, size.height * 0.74)
            let cell = boardSide / CGFloat(puzzle.size)
            let origin = CGPoint(x: (size.width - boardSide) / 2, y: size.height * 0.12)

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

                grid(origin: origin, side: boardSide, cell: cell)

                ForEach(puzzle.colors, id: \.self) { color in
                    if let path = paths[color], path.count > 1 {
                        flowPath(path, origin: origin, cell: cell)
                            .stroke(.white.opacity(completed ? 0.95 : 0.76), style: StrokeStyle(lineWidth: cell * 0.34, lineCap: .round, lineJoin: .round))
                            .shadow(color: Color.mathGold.opacity(0.85), radius: completed ? 16 : 9)
                    }
                }

                ForEach(Array(wrongCells), id: \.self) { cellValue in
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.red.opacity(0.9), lineWidth: 3)
                        .frame(width: cell * 0.86, height: cell * 0.86)
                        .position(center(of: cellValue, origin: origin, cell: cell))
                }

                ForEach(puzzle.colors, id: \.self) { color in
                    let pair = puzzle.endpoints[color]!
                    endpoint(color, at: pair.start, origin: origin, cell: cell)
                    endpoint(color, at: pair.end, origin: origin, cell: cell)
                }

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .frame(width: boardSide, height: boardSide)
                    .position(x: origin.x + boardSide / 2, y: origin.y + boardSide / 2)
                    .gesture(flowDrag(origin: origin, cell: cell))

            }
            .coordinateSpace(name: "colorFlowBoard")
        }
    }

    private func grid(origin: CGPoint, side: CGFloat, cell: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.46))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.34), lineWidth: 1.4))
                .frame(width: side, height: side)
                .position(x: origin.x + side / 2, y: origin.y + side / 2)

            Path { path in
                for index in 1..<puzzle.size {
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

    private func endpoint(_ color: FlowColor, at cellValue: FlowCell, origin: CGPoint, cell: CGFloat) -> some View {
        Circle()
            .fill(.black)
            .frame(width: cell * 0.48, height: cell * 0.48)
            .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 2.4))
            .overlay(
                Text(color.label)
                    .font(.system(size: cell * 0.23, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            )
            .shadow(color: Color.mathGold.opacity(0.95), radius: 12)
            .position(center(of: cellValue, origin: origin, cell: cell))
    }

    private func flowDrag(origin: CGPoint, cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("colorFlowBoard"))
            .onChanged { gesture in
                guard !completed, !advancingStage, let cellValue = cellAt(gesture.location, origin: origin, cell: cell) else { return }
                guard cellValue != lastDragCell else { return }
                lastDragCell = cellValue

                if activeColor == nil {
                    guard let color = puzzle.color(at: cellValue) else { return }
                    activeColor = color
                    paths[color] = [cellValue]
                    wrongCells = []
                    return
                }

                guard let color = activeColor else { return }
                extend(color: color, to: cellValue)
            }
            .onEnded { _ in
                activeColor = nil
                lastDragCell = nil
                checkCompletion()
            }
    }

    private func extend(color: FlowColor, to cell: FlowCell) {
        guard var path = paths[color], let last = path.last else { return }
        if cell == last { return }

        let pair = puzzle.endpoints[color]!
        if path.count >= 2, (last == pair.start || last == pair.end), cell != path[path.count - 2] {
            reject(cell)
            return
        }

        if path.count >= 2, cell == path[path.count - 2] {
            path.removeLast()
            paths[color] = path
            return
        }

        guard last.isAdjacent(to: cell) else { return }

        if let occupied = owner(of: cell), occupied != color {
            reject(cell)
            return
        }

        let isEndpoint = cell == pair.start || cell == pair.end
        if let existingIndex = path.firstIndex(of: cell) {
            path = Array(path.prefix(through: existingIndex))
            paths[color] = path
            return
        }

        if puzzle.isEndpoint(cell), !isEndpoint {
            reject(cell)
            return
        }

        path.append(cell)
        paths[color] = path
        wrongCells = []
    }

    private func reject(_ cell: FlowCell) {
        wrongCells = [cell]
        if let activeColor {
            paths[activeColor] = []
        }
        activeColor = nil
        lastDragCell = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            wrongCells = []
        }
    }

    private func owner(of cell: FlowCell) -> FlowColor? {
        for (color, path) in paths where path.contains(cell) {
            return color
        }
        return nil
    }

    private func checkCompletion() {
        guard allColorsConnected else { return }

        if filledCells.count < puzzle.size * puzzle.size {
            resetStage()
            return
        }

        advanceStage()
    }

    private var allColorsConnected: Bool {
        puzzle.colors.allSatisfy { color in
            guard let path = paths[color], let first = path.first, let last = path.last, let pair = puzzle.endpoints[color] else { return false }
            let endpoints = Set([first, last])
            return endpoints == Set([pair.start, pair.end])
        }
    }

    private func advanceStage() {
        advancingStage = true
        if stageIndex < puzzles.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                    stageIndex += 1
                    paths = [:]
                    activeColor = nil
                    lastDragCell = nil
                    wrongCells = []
                    advancingStage = false
                }
            }
        } else {
            finishLevel()
        }
    }

    private func resetStage() {
        advancingStage = true
        wrongCells = Set(paths.values.flatMap { $0 }).subtracting(filledCells)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                paths = [:]
                activeColor = nil
                lastDragCell = nil
                wrongCells = []
                advancingStage = false
            }
        }
    }

    private func resetLevel() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            stageIndex = 0
            paths = [:]
            activeColor = nil
            lastDragCell = nil
            wrongCells = []
            advancingStage = false
            completed = false
        }
    }

    private func finishLevel() {
        advancingStage = false
        withAnimation(.easeInOut(duration: 0.42)) {
            completed = true
            wrongCells = []
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            paths = [:]
            activeColor = nil
            lastDragCell = nil
            wrongCells = []
            advancingStage = false
            completed = false
        }
    }

    private func flowPath(_ path: [FlowCell], origin: CGPoint, cell: CGFloat) -> Path {
        Path { line in
            guard let first = path.first else { return }
            line.move(to: center(of: first, origin: origin, cell: cell))
            for cellValue in path.dropFirst() {
                line.addLine(to: center(of: cellValue, origin: origin, cell: cell))
            }
        }
    }

    private func cellAt(_ point: CGPoint, origin: CGPoint, cell: CGFloat) -> FlowCell? {
        let localX = point.x - origin.x
        let localY = point.y - origin.y
        guard localX >= 0, localY >= 0 else { return nil }

        let column = Int(floor(localX / cell))
        let row = Int(floor(localY / cell))
        guard (0..<puzzle.size).contains(row), (0..<puzzle.size).contains(column) else { return nil }
        return FlowCell(row: row, column: column)
    }

    private func center(of cellValue: FlowCell, origin: CGPoint, cell: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(cellValue.column) * cell + cell / 2, y: origin.y + CGFloat(cellValue.row) * cell + cell / 2)
    }
}

private struct FlowPuzzle {
    let size: Int
    let endpoints: [FlowColor: FlowPair]
    let solution: [FlowColor]

    var colors: [FlowColor] { solution }

    func color(at cell: FlowCell) -> FlowColor? {
        endpoints.first { _, pair in
            pair.start == cell || pair.end == cell
        }?.key
    }

    func isEndpoint(_ cell: FlowCell) -> Bool {
        color(at: cell) != nil
    }

    static let levelEightyOneStages: [FlowPuzzle] = [
        FlowPuzzle(
            size: 5,
            endpoints: [
                .red: FlowPair(start: FlowCell(row: 0, column: 0), end: FlowCell(row: 0, column: 4)),
                .blue: FlowPair(start: FlowCell(row: 1, column: 0), end: FlowCell(row: 4, column: 0)),
                .green: FlowPair(start: FlowCell(row: 1, column: 1), end: FlowCell(row: 4, column: 4)),
                .yellow: FlowPair(start: FlowCell(row: 2, column: 1), end: FlowCell(row: 4, column: 3))
            ],
            solution: [.red, .blue, .green, .yellow]
        ),
        FlowPuzzle(
            size: 6,
            endpoints: [
                .red: FlowPair(start: FlowCell(row: 0, column: 0), end: FlowCell(row: 0, column: 5)),
                .blue: FlowPair(start: FlowCell(row: 1, column: 0), end: FlowCell(row: 5, column: 0)),
                .green: FlowPair(start: FlowCell(row: 1, column: 1), end: FlowCell(row: 1, column: 5)),
                .yellow: FlowPair(start: FlowCell(row: 2, column: 1), end: FlowCell(row: 2, column: 5)),
                .purple: FlowPair(start: FlowCell(row: 3, column: 1), end: FlowCell(row: 5, column: 5))
            ],
            solution: [.red, .blue, .green, .yellow, .purple]
        ),
        FlowPuzzle(
            size: 7,
            endpoints: [
                .red: FlowPair(start: FlowCell(row: 0, column: 0), end: FlowCell(row: 0, column: 6)),
                .blue: FlowPair(start: FlowCell(row: 1, column: 0), end: FlowCell(row: 6, column: 0)),
                .green: FlowPair(start: FlowCell(row: 1, column: 1), end: FlowCell(row: 1, column: 6)),
                .yellow: FlowPair(start: FlowCell(row: 2, column: 1), end: FlowCell(row: 2, column: 6)),
                .purple: FlowPair(start: FlowCell(row: 3, column: 1), end: FlowCell(row: 3, column: 6)),
                .orange: FlowPair(start: FlowCell(row: 4, column: 1), end: FlowCell(row: 6, column: 6))
            ],
            solution: [.red, .blue, .green, .yellow, .purple, .orange]
        )
    ]
}

private struct FlowPair {
    let start: FlowCell
    let end: FlowCell
}

private enum FlowColor: CaseIterable, Hashable {
    case red
    case blue
    case green
    case yellow
    case purple
    case orange

    var label: String {
        switch self {
        case .red:
            "1"
        case .blue:
            "2"
        case .green:
            "3"
        case .yellow:
            "4"
        case .purple:
            "5"
        case .orange:
            "6"
        }
    }
}

private struct FlowCell: Hashable {
    let row: Int
    let column: Int

    func isAdjacent(to other: FlowCell) -> Bool {
        abs(row - other.row) + abs(column - other.column) == 1
    }
}
