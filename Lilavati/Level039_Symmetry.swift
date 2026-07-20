
import SwiftUI

@Observable
final class MathItLevelTwentyTwoViewModel {
    var placedPointIDs: Set<Int> = []
    var pointOffsets: [Int: CGSize] = [:]
    var completed = false
    var recentPointID: Int?

    let points = LevelTwentyTwoMirrorPoint.design

    var progress: Double {
        completed ? 1 : Double(placedPointIDs.count) / Double(points.count)
    }

    func offset(for id: Int) -> CGSize {
        pointOffsets[id, default: .zero]
    }

    func movePoint(id: Int, by translation: CGSize) {
        guard !completed, !placedPointIDs.contains(id) else { return }
        pointOffsets[id] = translation
    }

    func finishMovingPoint(id: Int, source: CGPoint, target: CGPoint) {
        guard !completed, !placedPointIDs.contains(id) else { return }
        let offset = pointOffsets[id, default: .zero]
        let current = CGPoint(x: source.x + offset.width, y: source.y + offset.height)

        if hypot(current.x - target.x, current.y - target.y) <= 32 {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                pointOffsets[id] = CGSize(width: target.x - source.x, height: target.y - source.y)
                placedPointIDs.insert(id)
                recentPointID = id
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                if self.recentPointID == id {
                    self.recentPointID = nil
                }
            }

            checkCompletion()
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                pointOffsets[id] = .zero
            }
        }
    }

    private func checkCompletion() {
        guard placedPointIDs.count == points.count, !completed else { return }
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }
}

struct LevelTwentyTwoMirrorPoint: Identifiable {
    let id: Int
    let target: CGPoint

    var source: CGPoint {
        CGPoint(x: 1 - target.x, y: target.y)
    }

    static let design = [
        LevelTwentyTwoMirrorPoint(id: 0, target: CGPoint(x: 0.58, y: 0.18)),
        LevelTwentyTwoMirrorPoint(id: 1, target: CGPoint(x: 0.72, y: 0.22)),
        LevelTwentyTwoMirrorPoint(id: 2, target: CGPoint(x: 0.86, y: 0.34)),
        LevelTwentyTwoMirrorPoint(id: 3, target: CGPoint(x: 0.78, y: 0.48)),
        LevelTwentyTwoMirrorPoint(id: 4, target: CGPoint(x: 0.9, y: 0.62)),
        LevelTwentyTwoMirrorPoint(id: 5, target: CGPoint(x: 0.72, y: 0.74)),
        LevelTwentyTwoMirrorPoint(id: 6, target: CGPoint(x: 0.58, y: 0.82)),
        LevelTwentyTwoMirrorPoint(id: 7, target: CGPoint(x: 0.62, y: 0.36)),
        LevelTwentyTwoMirrorPoint(id: 8, target: CGPoint(x: 0.66, y: 0.62))
    ]
}

struct MathItLevelTwentyTwoView: View {
    var viewModel: MathItLevelTwentyTwoViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 20, y: size.height * 0.17, width: size.width - 40, height: min(430, size.height * 0.58))

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
                    .tint(.white)
                    .opacity(0.72)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                symmetryBoard(board: board)

                CompletionOverlay(
                    title: "Level 22 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelTwentyTwoStage")
        }
    }

    private func symmetryBoard(board: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.white.opacity(0.16), lineWidth: 1.2)
                }
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            LevelTwentyTwoGridShape()
                .stroke(.white.opacity(0.045), lineWidth: 1)
                .frame(width: board.width - 22, height: board.height - 22)
                .position(x: board.midX, y: board.midY)

            flowerHalf(board: board, side: .left, completedOnly: false)
                .stroke(Color.mathItGeometry.opacity(0.88), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .shadow(color: Color.mathItGeometry.opacity(0.42), radius: 10)

            flowerHalf(board: board, side: .right, completedOnly: false)
                .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 6]))

            flowerHalf(board: board, side: .right, completedOnly: true)
                .stroke(Color.mathItGeometry.opacity(0.9), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .shadow(color: Color.mathItGeometry.opacity(0.42), radius: 10)

            axis(in: board)

            ForEach(viewModel.points) { point in
                mirrorTarget(point, board: board)
                draggablePoint(point, board: board)
            }

            Circle()
                .fill(Color.mathItGeometry.opacity(0.88))
                .frame(width: 24, height: 24)
                .shadow(color: Color.mathItGeometry.opacity(0.72), radius: 14)
                .position(normalizedPoint(CGPoint(x: 0.5, y: 0.52), in: board))
        }
    }

    private func mirrorTarget(_ point: LevelTwentyTwoMirrorPoint, board: CGRect) -> some View {
        let target = normalizedPoint(point.target, in: board)
        let isPlaced = viewModel.placedPointIDs.contains(point.id)
        return Circle()
            .stroke(isPlaced ? Color.mathItGeometry.opacity(0.82) : .white.opacity(0.36), style: StrokeStyle(lineWidth: 1.4, dash: isPlaced ? [] : [4, 4]))
            .frame(width: isPlaced ? 18 : 22, height: isPlaced ? 18 : 22)
            .shadow(color: Color.mathItGeometry.opacity(viewModel.recentPointID == point.id ? 0.75 : 0), radius: 12)
            .position(target)
    }

    private func draggablePoint(_ point: LevelTwentyTwoMirrorPoint, board: CGRect) -> some View {
        let source = normalizedPoint(point.source, in: board)
        let target = normalizedPoint(point.target, in: board)
        let offset = viewModel.offset(for: point.id)
        let current = CGPoint(x: source.x + offset.width, y: source.y + offset.height)
        let isPlaced = viewModel.placedPointIDs.contains(point.id)

        return Circle()
            .fill(isPlaced ? Color.mathItGeometry.opacity(0.32) : Color.mathItGeometry.opacity(0.9))
            .frame(width: isPlaced ? 12 : 20, height: isPlaced ? 12 : 20)
            .overlay {
                Circle()
                    .stroke(.white.opacity(isPlaced ? 0.3 : 0.62), lineWidth: 1.1)
            }
            .shadow(color: Color.mathItGeometry.opacity(isPlaced ? 0.18 : 0.62), radius: isPlaced ? 5 : 12)
            .position(current)
            .gesture(
                DragGesture(coordinateSpace: .named("levelTwentyTwoStage"))
                    .onChanged { value in
                        viewModel.movePoint(id: point.id, by: CGSize(width: value.location.x - source.x, height: value.location.y - source.y))
                    }
                    .onEnded { _ in
                        viewModel.finishMovingPoint(id: point.id, source: source, target: target)
                    }
            )
            .zIndex(isPlaced ? 1 : 6)
    }

    private func axis(in board: CGRect) -> some View {
        Path { path in
            path.move(to: CGPoint(x: board.midX, y: board.minY + 12))
            path.addLine(to: CGPoint(x: board.midX, y: board.maxY - 12))
        }
        .stroke(Color.mathItGeometry.opacity(0.86), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [14, 8]))
        .shadow(color: Color.mathItGeometry.opacity(0.45), radius: 12)
    }

    private enum FlowerSide {
        case left
        case right
    }

    private func flowerHalf(board: CGRect, side: FlowerSide, completedOnly: Bool) -> Path {
        var path = Path()
        for point in viewModel.points {
            guard !completedOnly || viewModel.placedPointIDs.contains(point.id) else { continue }
            let normalized = side == .left ? point.source : point.target
            path.addPath(petalPath(to: normalized, in: board, narrow: point.id >= 7))
        }
        return path
    }

    private func petalPath(to normalized: CGPoint, in board: CGRect, narrow: Bool) -> Path {
        let center = normalizedPoint(CGPoint(x: 0.5, y: 0.52), in: board)
        let end = normalizedPoint(normalized, in: board)
        let vector = CGVector(dx: end.x - center.x, dy: end.y - center.y)
        let length = max(1, hypot(vector.dx, vector.dy))
        let perpendicular = CGVector(dx: -vector.dy / length, dy: vector.dx / length)
        let midpoint = CGPoint(x: (center.x + end.x) / 2, y: (center.y + end.y) / 2)
        let width = (narrow ? 24 : 38) * min(1, length / 130)

        var path = Path()
        path.move(to: center)
        path.addQuadCurve(
            to: end,
            control: CGPoint(x: midpoint.x + perpendicular.dx * width, y: midpoint.y + perpendicular.dy * width)
        )
        path.addQuadCurve(
            to: center,
            control: CGPoint(x: midpoint.x - perpendicular.dx * width, y: midpoint.y - perpendicular.dy * width)
        )
        return path
    }

    private func normalizedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * point.x,
            y: rect.minY + rect.height * point.y
        )
    }
}

private struct LevelTwentyTwoGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for column in 0...6 {
            let x = rect.minX + rect.width * CGFloat(column) / 6
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        for row in 0...6 {
            let y = rect.minY + rect.height * CGFloat(row) / 6
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}
