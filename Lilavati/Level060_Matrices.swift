import SwiftUI

struct MathItLevelSeventySevenView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var phase: MatrixRotationPhase = .transpose
    @State private var transposePlaced: [Int?] = Array(repeating: nil, count: 6)
    @State private var rotationPlaced: [Int?] = Array(repeating: nil, count: 6)
    @State private var dragging: MatrixRotationDrag?
    @State private var wrongCell: Int?
    @State private var completed = false
    @State private var ballTravel = false

    private let stages = MatrixRotationStage.stages
    private var stage: MatrixRotationStage { stages[stageIndex] }
    private var sourceRows: [[Int]] { stage.sourceRows }
    private var transposeRows: [[Int]] { stage.transposeRows }
    private var rotationRows: [[Int]] { stage.rotationRows }
    private var sourceFlat: [Int] { stage.sourceFlat }
    private var transposeFlat: [Int] { stage.transposeFlat }
    private var rotationFlat: [Int] { stage.rotationFlat }
    private var activeSource: [Int] { phase == .transpose ? sourceFlat : transposeFlat }
    private var activeTarget: [Int] { phase == .transpose ? transposeFlat : rotationFlat }
    private var activePlaced: [Int?] { phase == .transpose ? transposePlaced : rotationPlaced }
    private var progressValue: Double {
        let finished = stages.prefix(stageIndex).reduce(0) { $0 + $1.valueCount * 2 }
        let current = transposePlaced.compactMap { $0 }.count + rotationPlaced.compactMap { $0 }.count
        let total = stages.reduce(0) { $0 + $1.valueCount * 2 }
        return Double(finished + current) / Double(total)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 12) {
                    VStack(spacing: 7) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(34))
                            .tracking(2)
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                    }
                    .padding(.horizontal, 58)

                    rotationBoard
                        .frame(height: min(610, proxy.size.height * 0.7))
                        .padding(.horizontal, 18)

                    HStack(spacing: 12) {
                        ProgressView(value: progressValue)
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
                    title: "Level 77 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var rotationBoard: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let sourceRowsCount = phase == .transpose ? stage.rows : stage.columns
            let sourceColumnsCount = phase == .transpose ? stage.columns : stage.rows
            let targetRowsCount = stage.columns
            let targetColumnsCount = stage.rows
            let cell = min(40, size.width * 0.68 / CGFloat(sourceColumnsCount + targetColumnsCount + 2))
            let sourceOrigin = CGPoint(x: size.width * 0.12, y: size.height * 0.51)
            let targetOrigin = CGPoint(x: size.width * 0.62, y: sourceOrigin.y)
            let sourceTileOrigin = CGPoint(x: size.width * 0.15, y: size.height * 0.13)
            let targetTileOrigin = CGPoint(x: size.width * 0.69, y: size.height * 0.10)
            let ballStart = CGPoint(x: size.width * 0.13, y: size.height * 0.88)
            let ballEnd = CGPoint(x: size.width * 0.91, y: size.height * 0.88)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.08), Color(red: 0.012, green: 0.014, blue: 0.018), .black],
                            center: .center,
                            startRadius: 30,
                            endRadius: max(size.width, size.height) * 0.72
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1.2))

                pixelImage(rows: stage.rows, columns: stage.columns, values: sourceFlat, litValues: Set(sourceFlat), solid: true)
                    .frame(width: cell * CGFloat(stage.columns) + 10, height: cell * CGFloat(stage.rows) + 10)
                    .rotationEffect(.degrees(completed ? 90 : 0))
                    .position(x: sourceTileOrigin.x + cell * CGFloat(stage.columns) / 2, y: sourceTileOrigin.y + cell * CGFloat(stage.rows) / 2)

                pixelImage(rows: targetRowsCount, columns: targetColumnsCount, values: activeTarget, litValues: Set(activePlaced.compactMap { $0 }), solid: completed || phase == .reverse)
                    .frame(width: cell * CGFloat(targetColumnsCount) + 10, height: cell * CGFloat(targetRowsCount) + 10)
                    .position(x: targetTileOrigin.x + cell * CGFloat(targetColumnsCount) / 2, y: targetTileOrigin.y + cell * CGFloat(targetRowsCount) / 2)

                arrowBetweenMatrices(size: size)

                matrixBracket(rows: sourceRowsCount, columns: sourceColumnsCount, cell: cell, origin: sourceOrigin, active: true)
                matrixBracket(rows: targetRowsCount, columns: targetColumnsCount, cell: cell, origin: targetOrigin, active: activePlaced.compactMap { $0 }.count == stage.valueCount)

                ForEach(0..<activeSource.count, id: \.self) { index in
                    let row = index / sourceColumnsCount
                    let column = index % sourceColumnsCount
                    let value = activeSource[index]
                    let center = cellCenter(origin: sourceOrigin, row: row, column: column, cell: cell)
                    let alreadyPlaced = activePlaced.contains { $0 == value }

                    matrixValue(value, cell: cell, hidden: dragging?.value == value || alreadyPlaced)
                        .position(center)
                        .gesture(!completed && !alreadyPlaced ? dragGesture(value: value, origin: center, targetOrigin: targetOrigin, targetCell: cell) : nil)
                }

                ForEach(0..<activeTarget.count, id: \.self) { index in
                    let row = index / targetColumnsCount
                    let column = index % targetColumnsCount
                    let center = cellCenter(origin: targetOrigin, row: row, column: column, cell: cell)

                    targetCellView(
                        value: activePlaced[index],
                        expected: activeTarget[index],
                        cell: cell,
                        showGhost: stageIndex == 0,
                        wrong: wrongCell == index
                    )
                    .position(center)
                }

                if let dragging {
                    matrixValue(dragging.value, cell: cell, hidden: false)
                        .position(x: dragging.origin.x + dragging.translation.width, y: dragging.origin.y + dragging.translation.height)
                        .zIndex(10)
                }

                if completed {
                    completedPath(from: ballStart, to: ballEnd, size: size)
                    Circle()
                        .stroke(.white.opacity(0.86), lineWidth: 4)
                        .frame(width: 54, height: 54)
                        .position(ballEnd)
                }

                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .white.opacity(0.82), radius: 10)
                    .opacity(completed ? 1 : 0)
                    .position(ballTravel ? ballEnd : ballStart)
                    .animation(.easeInOut(duration: 1.0), value: ballTravel)
            }
        }
    }

    private func matrixValue(_ value: Int, cell: CGFloat, hidden: Bool) -> some View {
        Text("\(value)")
            .font(.system(size: min(22, cell * 0.48), weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(hidden ? 0.16 : 0.88))
            .frame(width: cell, height: cell)
            .contentShape(Rectangle())
    }

    private func targetCellView(value: Int?, expected: Int, cell: CGFloat, showGhost: Bool, wrong: Bool) -> some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(width: cell, height: cell)
                .overlay(Rectangle().stroke(wrong ? .red.opacity(0.9) : .white.opacity(value == nil ? 0.07 : 0.16), lineWidth: wrong ? 2 : 1))
                .offset(x: wrong ? -5 : 0)
                .animation(.spring(response: 0.12, dampingFraction: 0.3), value: wrong)

            if let value {
                Text("\(value)")
                    .font(.system(size: min(22, cell * 0.48), weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
            } else if showGhost {
                Text("\(expected)")
                    .font(.system(size: min(22, cell * 0.48), weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.16))
            }
        }
    }

    private func pixelImage(rows: Int, columns: Int, values: [Int], litValues: Set<Int>, solid: Bool) -> some View {
        GeometryReader { proxy in
            let gap: CGFloat = 2
            let cell = min((proxy.size.width - CGFloat(columns - 1) * gap) / CGFloat(columns), (proxy.size.height - CGFloat(rows - 1) * gap) / CGFloat(rows))

            ZStack {
                Rectangle()
                    .fill(.black)
                    .frame(width: CGFloat(columns) * cell + CGFloat(columns - 1) * gap + 8, height: CGFloat(rows) * cell + CGFloat(rows - 1) * gap + 8)
                    .overlay(Rectangle().stroke(.white.opacity(solid ? 0.42 : 0.18), lineWidth: 1.4))

                VStack(spacing: gap) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<columns, id: \.self) { column in
                                let value = values[row * columns + column]
                                Rectangle()
                                    .fill(pixelTone(value).opacity(litValues.contains(value) ? (solid ? 1 : 0.78) : 0.1))
                                    .frame(width: cell, height: cell)
                                    .overlay(Rectangle().stroke(.black.opacity(0.85), lineWidth: 1.2))
                            }
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private func matrixBracket(rows: Int, columns: Int, cell: CGFloat, origin: CGPoint, active: Bool) -> some View {
        let width = CGFloat(columns) * cell
        let height = CGFloat(rows) * cell

        return Path { path in
            path.move(to: CGPoint(x: origin.x - 10, y: origin.y))
            path.addLine(to: CGPoint(x: origin.x - 18, y: origin.y))
            path.addLine(to: CGPoint(x: origin.x - 18, y: origin.y + height))
            path.addLine(to: CGPoint(x: origin.x - 10, y: origin.y + height))

            path.move(to: CGPoint(x: origin.x + width + 10, y: origin.y))
            path.addLine(to: CGPoint(x: origin.x + width + 18, y: origin.y))
            path.addLine(to: CGPoint(x: origin.x + width + 18, y: origin.y + height))
            path.addLine(to: CGPoint(x: origin.x + width + 10, y: origin.y + height))
        }
        .stroke(active ? Color.mathGold.opacity(0.95) : .white.opacity(0.28), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private func arrowBetweenMatrices(size: CGSize) -> some View {
        Path { path in
            let start = CGPoint(x: size.width * 0.39, y: size.height * 0.59)
            let end = CGPoint(x: size.width * 0.56, y: size.height * 0.59)
            path.move(to: start)
            path.addLine(to: end)
            path.move(to: CGPoint(x: end.x - 12, y: end.y - 8))
            path.addLine(to: end)
            path.addLine(to: CGPoint(x: end.x - 12, y: end.y + 8))
        }
        .stroke(.white.opacity(0.38), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private func completedPath(from start: CGPoint, to end: CGPoint, size: CGSize) -> some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: CGPoint(x: size.width * 0.44, y: start.y))
            path.addLine(to: CGPoint(x: size.width * 0.58, y: end.y))
            path.addLine(to: end)
        }
        .stroke(accent.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private func dragGesture(value: Int, origin: CGPoint, targetOrigin: CGPoint, targetCell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                if dragging == nil {
                    dragging = MatrixRotationDrag(value: value, origin: origin, translation: gesture.translation)
                } else {
                    dragging?.translation = gesture.translation
                }
            }
            .onEnded { gesture in
                let drop = CGPoint(x: origin.x + gesture.translation.width, y: origin.y + gesture.translation.height)
                dragging = nil
                handleDrop(value: value, at: drop, targetOrigin: targetOrigin, targetCell: targetCell)
            }
    }

    private func handleDrop(value: Int, at point: CGPoint, targetOrigin: CGPoint, targetCell: CGFloat) {
        let column = Int((point.x - targetOrigin.x) / targetCell)
        let row = Int((point.y - targetOrigin.y) / targetCell)
        guard (0..<stage.columns).contains(row), (0..<stage.rows).contains(column) else {
            pulseWrong(nil)
            return
        }

        let index = row * stage.rows + column
        guard activePlaced[index] == nil, activeTarget[index] == value else {
            pulseWrong(index)
            return
        }

        var updatedPlaced = activePlaced
        updatedPlaced[index] = value

        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
            if phase == .transpose {
                transposePlaced = updatedPlaced
            } else {
                rotationPlaced = updatedPlaced
            }
        }

        let solved = phase == .transpose
            ? updatedPlaced == transposeFlat.map(Optional.some)
            : updatedPlaced == rotationFlat.map(Optional.some)

        if solved {
            advancePhase()
        }
    }

    private func advancePhase() {
        if phase == .transpose {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    phase = .reverse
                    wrongCell = nil
                }
            }
        } else if stageIndex < stages.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    let nextIndex = stageIndex + 1
                    stageIndex = nextIndex
                    phase = .transpose
                    transposePlaced = emptyPlaced(for: nextIndex)
                    rotationPlaced = emptyPlaced(for: nextIndex)
                    wrongCell = nil
                }
            }
        } else {
            finishLevel()
        }
    }

    private func finishLevel() {
        withAnimation(.easeInOut(duration: 0.62)) {
            completed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            ballTravel = true
        }
    }

    private func pulseWrong(_ index: Int?) {
        wrongCell = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            wrongCell = nil
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            stageIndex = 0
            phase = .transpose
            transposePlaced = emptyPlaced(for: 0)
            rotationPlaced = emptyPlaced(for: 0)
            dragging = nil
            wrongCell = nil
            completed = false
            ballTravel = false
        }
    }

    private func cellCenter(origin: CGPoint, row: Int, column: Int, cell: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(column) * cell + cell / 2, y: origin.y + CGFloat(row) * cell + cell / 2)
    }

    private func emptyPlaced(for index: Int) -> [Int?] {
        Array(repeating: nil, count: stages[index].valueCount)
    }

    private func pixelTone(_ value: Int) -> Color {
        let tones: [Double] = [0.96, 0.08, 0.58, 0.18, 0.88, 0.68, 0.34, 0.78, 0.48, 0.24]
        return Color(white: tones[(value - 1) % tones.count])
    }
}

private struct MatrixRotationStage {
    let rows: Int
    let columns: Int
    let sourceRows: [[Int]]

    var valueCount: Int { rows * columns }
    var sourceFlat: [Int] { sourceRows.flatMap { $0 } }

    var transposeRows: [[Int]] {
        (0..<columns).map { column in
            (0..<rows).map { row in sourceRows[row][column] }
        }
    }

    var rotationRows: [[Int]] {
        transposeRows.map { Array($0.reversed()) }
    }

    var transposeFlat: [Int] { transposeRows.flatMap { $0 } }
    var rotationFlat: [Int] { rotationRows.flatMap { $0 } }

    static let stages: [MatrixRotationStage] = [
        MatrixRotationStage(rows: 2, columns: 3, sourceRows: [
            [1, 2, 3],
            [4, 5, 6]
        ]),
        MatrixRotationStage(rows: 3, columns: 4, sourceRows: [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12]
        ])
    ]
}

private enum MatrixRotationPhase {
    case transpose
    case reverse
}

private struct MatrixRotationDrag: Equatable {
    let value: Int
    let origin: CGPoint
    var translation: CGSize
}
