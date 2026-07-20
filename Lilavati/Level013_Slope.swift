import SwiftUI

enum LevelFortyNineDirection: CaseIterable {
    case up
    case down
    case left
    case right

    var iconName: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }

    var step: SIMD2<Int> {
        switch self {
        case .up: SIMD2(0, 1)
        case .down: SIMD2(0, -1)
        case .left: SIMD2(-1, 0)
        case .right: SIMD2(1, 0)
        }
    }
}

struct LevelFortyNineTrianglePiece: Identifiable {
    let id: Int
    let rise: Int
    let run: Int
    let start: SIMD2<Int>
    let end: SIMD2<Int>
    var placedSlot: Int?
    var dragOffset: CGSize = .zero
}

struct LevelFortyNineStage {
    let goalCoordinate: SIMD2<Int>

    var requiredPieces: Int {
        Self.greatestCommonDivisor(abs(goalCoordinate.x), abs(goalCoordinate.y))
    }

    var targetVector: SIMD2<Int> {
        let divisor = max(1, requiredPieces)
        return SIMD2(goalCoordinate.x / divisor, goalCoordinate.y / divisor)
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(1, a)
    }
}

@Observable
final class MathItLevelFortyNineViewModel {
    let minX = -6
    let maxX = 6
    let minY = -4
    let maxY = 4
    let maxLoadedMoves = 12
    let stages = [
        LevelFortyNineStage(goalCoordinate: SIMD2(6, 4)),
        LevelFortyNineStage(goalCoordinate: SIMD2(-6, 3)),
        LevelFortyNineStage(goalCoordinate: SIMD2(-2, 4)),
        LevelFortyNineStage(goalCoordinate: SIMD2(5, -2))
    ]

    var stageIndex = 0
    var moves: [LevelFortyNineDirection] = []
    var ballProgress = 0.0
    var completed = false
    var isAnimatingBall = false
    var isCharged = false
    var wrongPulse = false
    var trianglePieces: [LevelFortyNineTrianglePiece] = []

    var rise: Int {
        loadedEndpoint.y
    }

    var run: Int {
        loadedEndpoint.x
    }

    var slopeVector: SIMD2<Int> {
        loadedEndpoint
    }

    var targetVector: SIMD2<Int> {
        currentStage.targetVector
    }

    var goalCoordinate: SIMD2<Int> {
        currentStage.goalCoordinate
    }

    var targetRise: Int {
        abs(currentStage.targetVector.y)
    }

    var targetRun: Int {
        abs(currentStage.targetVector.x)
    }

    var requiredPieces: Int {
        currentStage.requiredPieces
    }

    var canRelease: Bool {
        !moves.isEmpty
            && loadedEndpoint != SIMD2(0, 0)
            && !completed
            && !isAnimatingBall
            && !isCharged
    }

    var progress: Double {
        if completed { return 1 }
        let stageSpan = 1 / Double(stages.count)
        let stageBase = Double(stageIndex) * stageSpan
        let placed = Double(trianglePieces.filter { $0.placedSlot != nil }.count)
        if !trianglePieces.isEmpty {
            return stageBase + min(0.96, 0.72 + placed / Double(requiredPieces) * 0.24) * stageSpan
        }
        if isAnimatingBall {
            let localProgress = 0.52 + (ballProgress / Double(max(1, releaseTrajectoryCoordinates.count - 1))) * 0.2
            return stageBase + localProgress * stageSpan
        }
        return stageBase + min(0.5, Double(moves.count) / Double(maxLoadedMoves) * 0.5) * stageSpan
    }

    var loadedEndpoint: SIMD2<Int> {
        pathCoordinates.last ?? SIMD2(0, 0)
    }

    var pathCoordinates: [SIMD2<Int>] {
        var current = SIMD2(0, 0)
        var coordinates = [current]

        for move in moves {
            current &+= move.step
            coordinates.append(current)
        }

        return coordinates
    }

    var releaseCoordinates: [SIMD2<Int>] {
        guard slopeVector != SIMD2(0, 0) else { return [SIMD2(0, 0)] }

        var current = SIMD2(0, 0)
        var coordinates = [current]

        while coordinates.count < 12 {
            let next = current &+ slopeVector
            guard contains(next) else { return coordinates }

            current = next
            coordinates.append(current)

            if current == goalCoordinate {
                return coordinates
            }
        }

        return coordinates
    }

    var releaseTrajectoryCoordinates: [SIMD2<Int>] {
        guard releaseCoordinates.count > 1 else { return [SIMD2(0, 0)] }

        var coordinates = [releaseCoordinates[0]]
        for index in 0..<(releaseCoordinates.count - 1) {
            let start = releaseCoordinates[index]
            let end = releaseCoordinates[index + 1]
            let riseCorner = SIMD2(start.x, end.y)

            appendUnitSteps(from: start, to: riseCorner, into: &coordinates)
            appendUnitSteps(from: riseCorner, to: end, into: &coordinates)
        }

        return coordinates
    }

    var landedOnGoal: Bool {
        releaseCoordinates.last == goalCoordinate
    }

    private var currentStage: LevelFortyNineStage {
        stages[stageIndex]
    }

    func press(_ direction: LevelFortyNineDirection) {
        guard !completed, !isAnimatingBall, !isCharged else { return }
        guard moves.count < maxLoadedMoves else {
            markWrong(clearMoves: false, clearPieces: false)
            return
        }

        let current = pathCoordinates.last ?? SIMD2(0, 0)
        let next = current &+ direction.step
        guard contains(next) else {
            markWrong(clearMoves: false, clearPieces: false)
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            isCharged = false
            ballProgress = 0
            trianglePieces.removeAll()
            moves.append(direction)
        }
    }

    func releaseBall() {
        guard canRelease else {
            markWrong(clearMoves: false, clearPieces: false)
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.48)) {
            isCharged = true
            ballProgress = 0
            trianglePieces.removeAll()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            guard self.isCharged else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
                self.isAnimatingBall = true
            }
        }

        let stepDelay = 0.2
        let pathCount = releaseTrajectoryCoordinates.count
        for step in 1..<pathCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36 + Double(step) * stepDelay) {
                guard self.isAnimatingBall else { return }
                withAnimation(.easeInOut(duration: 0.14)) {
                    self.ballProgress = Double(step)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36 + Double(pathCount - 1) * stepDelay + 0.22) {
            guard self.isAnimatingBall else { return }
            self.ballProgress = Double(max(0, pathCount - 1))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                self.isAnimatingBall = false
                self.createTrianglePieces()
            }
            if !self.landedOnGoal {
                self.markWrong(clearMoves: false, clearPieces: false)
            }
        }
    }

    func reset() {
        guard !isAnimatingBall else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            moves.removeAll()
            ballProgress = 0
            isCharged = false
            wrongPulse = false
            trianglePieces.removeAll()
        }
    }

    func placePiece(_ id: Int, at slot: Int) {
        guard let pieceIndex = trianglePieces.firstIndex(where: { $0.id == id }) else { return }
        guard slot < requiredPieces else { return }
        guard !trianglePieces.contains(where: { $0.placedSlot == slot && $0.id != id }) else { return }
        let pieceVector = trianglePieces[pieceIndex].end &- trianglePieces[pieceIndex].start
        guard trianglePieces[pieceIndex].run == targetRun,
              trianglePieces[pieceIndex].rise == targetRise,
              pieceVector == targetVector else {
            markWrong(clearMoves: false, clearPieces: false)
            cancelDrag(for: id)
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            trianglePieces[pieceIndex].placedSlot = slot
            trianglePieces[pieceIndex].dragOffset = .zero
        }
        checkCompletion()
    }

    func firstOpenSlot() -> Int? {
        (0..<requiredPieces).first { slot in
            !trianglePieces.contains { $0.placedSlot == slot }
        }
    }

    func setDragOffset(for id: Int, offset: CGSize) {
        guard let index = trianglePieces.firstIndex(where: { $0.id == id }) else { return }
        trianglePieces[index].dragOffset = offset
    }

    func cancelDrag(for id: Int) {
        guard let index = trianglePieces.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            trianglePieces[index].dragOffset = .zero
        }
    }

    private func createTrianglePieces() {
        let count = max(0, releaseCoordinates.count - 1)
        trianglePieces = (0..<count).map { index in
            LevelFortyNineTrianglePiece(
                id: index,
                rise: abs(rise),
                run: abs(run),
                start: releaseCoordinates[index],
                end: releaseCoordinates[index + 1]
            )
        }
    }

    private func checkCompletion() {
        let placedCount = trianglePieces.filter { $0.placedSlot != nil }.count
        guard landedOnGoal, trianglePieces.count == requiredPieces, placedCount == requiredPieces else { return }
        HapticPlayer.playCompletionTap()
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            advanceStage()
        }
    }

    private func contains(_ coordinate: SIMD2<Int>) -> Bool {
        (minX...maxX).contains(coordinate.x) && (minY...maxY).contains(coordinate.y)
    }

    private func appendUnitSteps(from start: SIMD2<Int>, to end: SIMD2<Int>, into coordinates: inout [SIMD2<Int>]) {
        var current = coordinates.last ?? start
        while current != end {
            if current.y != end.y {
                current.y += (end.y - current.y).signum()
            } else if current.x != end.x {
                current.x += (end.x - current.x).signum()
            }
            coordinates.append(current)
        }
    }

    private func advanceStage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard !self.completed, !self.isAnimatingBall else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                self.stageIndex += 1
                self.moves.removeAll()
                self.ballProgress = 0
                self.isCharged = false
                self.wrongPulse = false
                self.trianglePieces.removeAll()
            }
        }
    }

    private func markWrong(clearMoves: Bool, clearPieces: Bool) {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            wrongPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.76)) {
                self.wrongPulse = false
                self.isAnimatingBall = false
                if clearMoves {
                    self.moves.removeAll()
                    self.ballProgress = 0
                    self.isCharged = false
                }
                if clearPieces {
                    self.trianglePieces.removeAll()
                }
            }
        }
    }
}

struct MathItLevelFortyNineView: View {
    var viewModel: MathItLevelFortyNineViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gridWidth = min(size.width - 42, size.height * 0.56, 420)
            let gridHeight = gridWidth * 2 / 3
            let gridCenterY = size.height * 0.48
            let slotCenters = triangleSlotCenters(size: size)

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                LevelFortyNineGridView(
                    pathCoordinates: viewModel.pathCoordinates,
                    releaseCoordinates: viewModel.releaseCoordinates,
                    releaseTrajectoryCoordinates: viewModel.releaseTrajectoryCoordinates,
                    ballProgress: viewModel.ballProgress,
                    goalCoordinate: viewModel.goalCoordinate,
                    slopeVector: viewModel.slopeVector,
                    isAnimatingBall: viewModel.isAnimatingBall,
                    isCharged: viewModel.isCharged,
                    wrongPulse: viewModel.wrongPulse
                )
                .frame(width: gridWidth, height: gridHeight)
                .position(x: size.width / 2, y: gridCenterY)

                trianglePieces(
                    size: size,
                    gridFrame: CGRect(
                        x: (size.width - gridWidth) / 2,
                        y: gridCenterY - gridHeight / 2,
                        width: gridWidth,
                        height: gridHeight
                    ),
                    slotCenters: slotCenters
                )
                triangleSlots(size: size, centers: slotCenters)

                controlPanel(size: size)
                    .position(x: size.width / 2, y: min(size.height - 118, size.height * 0.83))

                CompletionOverlay(
                    title: "Level 49 Completed",
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

            Text("slope triangles")
                .font(.garamond(min(33, size.width * 0.08)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.38))

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: max(180, size.width - 68))
                .opacity(0.74)
                .padding(.top, 2)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func triangleSlotCenters(size: CGSize) -> [CGPoint] {
        let slotSize = targetTrianglePixelSize(size: size)
        let count = viewModel.requiredPieces
        let spacing = min(slotSize.width + 10, max(44, (size.width - 54) / CGFloat(max(1, count))))
        let startX = size.width / 2 - spacing * CGFloat(count - 1) / 2
        let y = size.height * 0.235
        return (0..<count).map { index in
            CGPoint(x: startX + spacing * CGFloat(index), y: y)
        }
    }

    private func triangleSlots(size: CGSize, centers: [CGPoint]) -> some View {
        let slotSize = targetTrianglePixelSize(size: size)

        return ZStack {
            ForEach(0..<viewModel.requiredPieces, id: \.self) { index in
                LevelFortyNineTriangleShape(orientation: triangleOrientation(forSlot: index))
                    .stroke(.white.opacity(viewModel.trianglePieces.contains(where: { $0.placedSlot == index }) ? 0.84 : 0.42), lineWidth: 2)
                    .frame(width: slotSize.width, height: slotSize.height)
                    .position(centers[index])
            }
        }
    }

    private func trianglePieces(size: CGSize, gridFrame: CGRect, slotCenters: [CGPoint]) -> some View {
        ZStack {
            ForEach(viewModel.trianglePieces) { piece in
                let base = pieceBasePosition(piece, gridFrame: gridFrame, slotCenters: slotCenters)
                let position = CGPoint(x: base.x + piece.dragOffset.width, y: base.y + piece.dragOffset.height)
                let pieceSize = trianglePixelSize(piece, gridFrame: gridFrame)

                LevelFortyNineTrianglePieceView(
                    piece: piece,
                    accent: accent,
                    orientation: triangleOrientation(piece),
                    size: pieceSize
                )
                    .position(position)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard piece.placedSlot == nil else { return }
                                viewModel.setDragOffset(for: piece.id, offset: value.translation)
                            }
                            .onEnded { value in
                                guard piece.placedSlot == nil else { return }
                                let end = CGPoint(
                                    x: base.x + value.translation.width,
                                    y: base.y + value.translation.height
                                )
                                if isNearSlot(end, centers: slotCenters),
                                   let slot = viewModel.firstOpenSlot() {
                                    viewModel.placePiece(piece.id, at: slot)
                                } else {
                                    viewModel.cancelDrag(for: piece.id)
                                }
                            }
                    )
            }
        }
    }

    private func pieceBasePosition(_ piece: LevelFortyNineTrianglePiece, gridFrame: CGRect, slotCenters: [CGPoint]) -> CGPoint {
        if let slot = piece.placedSlot {
            return slotCenters[slot]
        }

        return triangleCenter(piece, gridFrame: gridFrame)
    }

    private func isNearSlot(_ point: CGPoint, centers: [CGPoint]) -> Bool {
        centers.contains { center in
            hypot(point.x - center.x, point.y - center.y) < 48
        }
    }

    private func targetTrianglePixelSize(size: CGSize) -> CGSize {
        let gridWidth = min(size.width - 42, size.height * 0.56, 420)
        let gridHeight = gridWidth * 2 / 3
        return CGSize(
            width: gridWidth / 12 * CGFloat(viewModel.targetRun),
            height: gridHeight / 8 * CGFloat(viewModel.targetRise)
        )
    }

    private func trianglePixelSize(_ piece: LevelFortyNineTrianglePiece, gridFrame: CGRect) -> CGSize {
        CGSize(
            width: gridFrame.width / 12 * CGFloat(max(1, piece.run)),
            height: gridFrame.height / 8 * CGFloat(max(1, piece.rise))
        )
    }

    private func triangleCenter(_ piece: LevelFortyNineTrianglePiece, gridFrame: CGRect) -> CGPoint {
        let start = point(for: piece.start, in: gridFrame)
        let corner = point(for: SIMD2(piece.start.x, piece.end.y), in: gridFrame)
        let end = point(for: piece.end, in: gridFrame)
        return CGPoint(
            x: (start.x + corner.x + end.x) / 3,
            y: (start.y + corner.y + end.y) / 3
        )
    }

    private func triangleOrientation(_ piece: LevelFortyNineTrianglePiece) -> LevelFortyNineTriangleOrientation {
        if let slot = piece.placedSlot {
            return triangleOrientation(forSlot: slot)
        }
        return LevelFortyNineTriangleOrientation(
            runDirection: piece.end.x - piece.start.x,
            riseDirection: piece.end.y - piece.start.y,
            isComplement: false
        )
    }

    private func triangleOrientation(forSlot slot: Int) -> LevelFortyNineTriangleOrientation {
        LevelFortyNineTriangleOrientation(
            runDirection: viewModel.targetVector.x,
            riseDirection: viewModel.targetVector.y,
            isComplement: false
        )
    }

    private func point(for coordinate: SIMD2<Int>, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width / 12 * CGFloat(coordinate.x + 6),
            y: rect.maxY - rect.height / 8 * CGFloat(coordinate.y + 4)
        )
    }

    private func controlPanel(size: CGSize) -> some View {
        HStack(spacing: min(24, size.width * 0.06)) {
            VStack(spacing: 14) {
                Text("\(viewModel.rise)")
                    .font(.trajan(34))
                    .foregroundStyle(accent)
                    .frame(width: 62, height: 42)

                Text("\(viewModel.run)")
                    .font(.trajan(34))
                    .foregroundStyle(accent)
                    .frame(width: 62, height: 42)
            }

            arrowPad

            VStack(spacing: 9) {
                Button(action: viewModel.releaseBall) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(viewModel.canRelease ? .black : .white.opacity(0.24))
                        .frame(width: 52, height: 52)
                        .background(viewModel.canRelease ? accent : .white.opacity(0.055), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(accent.opacity(viewModel.canRelease ? 0 : 0.26), lineWidth: 1.1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canRelease)
                .accessibilityLabel("Release ball")

                Button(action: viewModel.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.isAnimatingBall ? .white.opacity(0.2) : accent)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.055), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(accent.opacity(viewModel.isAnimatingBall ? 0.12 : 0.48), lineWidth: 1.1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isAnimatingBall)
                .accessibilityLabel("Reset slope")
            }
        }
        .padding(.horizontal, 18)
    }

    private var arrowPad: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(width: 54, height: 54)
                arrowButton(.up)
                Color.clear.frame(width: 54, height: 54)
            }
            GridRow {
                arrowButton(.left)
                arrowButton(.down)
                arrowButton(.right)
            }
        }
    }

    private func arrowButton(_ direction: LevelFortyNineDirection) -> some View {
        Button {
            viewModel.press(direction)
        } label: {
            Image(systemName: direction.iconName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(viewModel.isAnimatingBall ? .white.opacity(0.2) : accent)
                .frame(width: 54, height: 54)
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(accent.opacity(viewModel.isAnimatingBall ? 0.12 : 0.52), lineWidth: 1.1)
                }
                .shadow(color: accent.opacity(viewModel.isAnimatingBall ? 0 : 0.18), radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isAnimatingBall)
        .accessibilityLabel("\(String(describing: direction).capitalized)")
    }
}

struct LevelFortyNineTrianglePieceView: View {
    let piece: LevelFortyNineTrianglePiece
    let accent: Color
    let orientation: LevelFortyNineTriangleOrientation
    let size: CGSize

    var body: some View {
        ZStack {
            LevelFortyNineTriangleShape(orientation: orientation)
                .fill(accent.opacity(piece.placedSlot == nil ? 0.78 : 0.54))
            if piece.placedSlot == nil {
                LevelFortyNineTriangleShape(orientation: orientation)
                    .stroke(.white.opacity(0.74), lineWidth: 1.5)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: accent.opacity(piece.placedSlot == nil ? 0.4 : 0.16), radius: 9)
    }
}

struct LevelFortyNineTriangleOrientation {
    let runDirection: Int
    let riseDirection: Int
    let isComplement: Bool
}

struct LevelFortyNineTriangleShape: Shape {
    let orientation: LevelFortyNineTriangleOrientation

    func path(in rect: CGRect) -> Path {
        let runSign = orientation.runDirection < 0 ? -1 : 1
        let riseSign = orientation.riseDirection < 0 ? -1 : 1
        let start = CGPoint(
            x: runSign > 0 ? rect.minX : rect.maxX,
            y: riseSign > 0 ? rect.maxY : rect.minY
        )
        let riseCorner = CGPoint(
            x: start.x,
            y: riseSign > 0 ? rect.minY : rect.maxY
        )
        let end = CGPoint(
            x: runSign > 0 ? rect.maxX : rect.minX,
            y: riseCorner.y
        )
        let runCorner = CGPoint(x: end.x, y: start.y)

        var path = Path()
        if orientation.isComplement {
            path.move(to: start)
            path.addLine(to: end)
            path.addLine(to: runCorner)
        } else {
            path.move(to: start)
            path.addLine(to: riseCorner)
            path.addLine(to: end)
        }
        path.closeSubpath()
        return path
    }
}

struct LevelFortyNineGridView: View {
    let pathCoordinates: [SIMD2<Int>]
    let releaseCoordinates: [SIMD2<Int>]
    let releaseTrajectoryCoordinates: [SIMD2<Int>]
    let ballProgress: Double
    let goalCoordinate: SIMD2<Int>
    let slopeVector: SIMD2<Int>
    let isAnimatingBall: Bool
    let isCharged: Bool
    let wrongPulse: Bool

    private let accent = Color.mathItAlgebra
    private let minX = -6
    private let maxX = 6
    private let minY = -4
    private let maxY = 4

    private var xIntervals: Int { maxX - minX }
    private var yIntervals: Int { maxY - minY }

    var body: some View {
        GeometryReader { proxy in
            let baseRect = plotRect(in: proxy.size)
            let rect = CGRect(
                x: (proxy.size.width - baseRect.width) / 2,
                y: (proxy.size.height - baseRect.height) / 2,
                width: baseRect.width,
                height: baseRect.height
            )

            ZStack {
                grid(in: rect)
                axes(in: rect)
                triangleFill(in: rect)
                slopeLine(in: rect)
                loadedEndpointMarker(in: rect)
                markers(in: rect)

                Circle()
                    .fill(.white)
                    .frame(width: rect.width * 0.038, height: rect.width * 0.038)
                    .shadow(color: .white.opacity(0.72), radius: 12)
                    .position(ballPoint(in: rect))
                    .scaleEffect(isCharged && !isAnimatingBall ? 1.18 : 1)
            }
            .scaleEffect(wrongPulse ? 1.02 : isCharged && !isAnimatingBall ? 0.985 : 1)
        }
    }

    private func plotRect(in size: CGSize) -> CGRect {
        let aspect = CGFloat(xIntervals) / CGFloat(yIntervals)
        let widthFromHeight = size.height * aspect
        if widthFromHeight <= size.width {
            return CGRect(x: 0, y: 0, width: widthFromHeight, height: size.height)
        }
        return CGRect(x: 0, y: 0, width: size.width, height: size.width / aspect)
    }

    private func grid(in rect: CGRect) -> some View {
        Path { path in
            for x in minX...maxX {
                let pointX = point(for: SIMD2(x, 0), in: rect).x
                path.move(to: CGPoint(x: pointX, y: rect.minY))
                path.addLine(to: CGPoint(x: pointX, y: rect.maxY))
            }

            for y in minY...maxY {
                let pointY = point(for: SIMD2(0, y), in: rect).y
                path.move(to: CGPoint(x: rect.minX, y: pointY))
                path.addLine(to: CGPoint(x: rect.maxX, y: pointY))
            }
        }
        .stroke(.white.opacity(0.18), lineWidth: 1)
    }

    private func axes(in rect: CGRect) -> some View {
        Path { path in
            let origin = point(for: SIMD2(0, 0), in: rect)
            path.move(to: CGPoint(x: rect.minX, y: origin.y))
            path.addLine(to: CGPoint(x: rect.maxX, y: origin.y))
            path.move(to: CGPoint(x: origin.x, y: rect.minY))
            path.addLine(to: CGPoint(x: origin.x, y: rect.maxY))
        }
        .stroke(.white.opacity(0.48), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func triangleFill(in rect: CGRect) -> some View {
        Path { path in
            guard releaseCoordinates.count > 1 else { return }
            for index in 0..<(releaseCoordinates.count - 1) {
                let start = releaseCoordinates[index]
                let end = releaseCoordinates[index + 1]
                path.move(to: point(for: start, in: rect))
                path.addLine(to: point(for: SIMD2(start.x, end.y), in: rect))
                path.addLine(to: point(for: end, in: rect))
                path.closeSubpath()
            }
        }
        .fill(accent.opacity(isCharged ? 0.22 : 0.1))
    }

    private func slopeLine(in rect: CGRect) -> some View {
        Path { path in
            guard let first = releaseTrajectoryCoordinates.first else { return }
            path.move(to: point(for: first, in: rect))
            for coordinate in releaseTrajectoryCoordinates.dropFirst() {
                path.addLine(to: point(for: coordinate, in: rect))
            }
        }
        .stroke(
            accent.opacity(isCharged ? 0.76 : 0.28),
            style: StrokeStyle(lineWidth: isCharged ? 5 : 3, lineCap: .round, lineJoin: .round, dash: isCharged ? [] : [7, 7])
        )
        .shadow(color: accent.opacity(isCharged ? 0.38 : 0), radius: 12)
    }

    private func loadedEndpointMarker(in rect: CGRect) -> some View {
        Path { path in
            guard let first = pathCoordinates.first,
                  let last = pathCoordinates.last,
                  first != last else { return }
            path.move(to: point(for: first, in: rect))
            path.addLine(to: point(for: last, in: rect))
        }
        .stroke(Color.mathGold.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
    }

    private func markers(in rect: CGRect) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: rect.width * 0.026, height: rect.width * 0.026)
                .shadow(color: .white.opacity(isCharged ? 0.82 : 0.45), radius: isCharged ? 14 : 8)
                .position(point(for: SIMD2(0, 0), in: rect))

            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: rect.width * 0.054, height: rect.width * 0.054)
                .shadow(color: .white.opacity(0.65), radius: 10)
                .position(point(for: goalCoordinate, in: rect))

            ForEach(Array(releaseCoordinates.enumerated()), id: \.offset) { index, coordinate in
                Circle()
                    .fill(index == 0 ? .clear : .white.opacity(index == releaseCoordinates.count - 1 ? 0.18 : 0.34))
                    .frame(width: index == releaseCoordinates.count - 1 ? 8 : 5, height: index == releaseCoordinates.count - 1 ? 8 : 5)
                    .position(point(for: coordinate, in: rect))
            }
        }
    }

    private func point(for coordinate: SIMD2<Int>, in rect: CGRect) -> CGPoint {
        let cellWidth = rect.width / CGFloat(xIntervals)
        let cellHeight = rect.height / CGFloat(yIntervals)
        return CGPoint(
            x: rect.minX + cellWidth * CGFloat(coordinate.x - minX),
            y: rect.maxY - cellHeight * CGFloat(coordinate.y - minY)
        )
    }

    private func ballPoint(in rect: CGRect) -> CGPoint {
        guard releaseTrajectoryCoordinates.count > 1 else {
            return point(for: SIMD2(0, 0), in: rect)
        }

        let finalProgress = Double(releaseTrajectoryCoordinates.count - 1)
        if ballProgress <= 0 {
            return point(for: releaseTrajectoryCoordinates[0], in: rect)
        }
        if ballProgress >= finalProgress - 0.001,
           let last = releaseTrajectoryCoordinates.last {
            return point(for: last, in: rect)
        }

        let segment = min(Int(floor(ballProgress)), releaseTrajectoryCoordinates.count - 2)
        let localProgress = min(1, max(0, ballProgress - Double(segment)))
        let start = point(for: releaseTrajectoryCoordinates[segment], in: rect)
        let end = point(for: releaseTrajectoryCoordinates[segment + 1], in: rect)
        return CGPoint(
            x: start.x + (end.x - start.x) * localProgress,
            y: start.y + (end.y - start.y) * localProgress
        )
    }

}
