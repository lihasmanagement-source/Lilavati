import SwiftUI

enum LevelThirtyEightDirection: CaseIterable {
    case north
    case east
    case south
    case west

    var symbol: String {
        switch self {
        case .north: "N"
        case .east: "E"
        case .south: "S"
        case .west: "W"
        }
    }

    var vector: CGVector {
        switch self {
        case .north: CGVector(dx: 0, dy: -1)
        case .east: CGVector(dx: 1, dy: 0)
        case .south: CGVector(dx: 0, dy: 1)
        case .west: CGVector(dx: -1, dy: 0)
        }
    }
}

@Observable
final class MathItLevelThirtyEightViewModel {
    let directions = Array(LevelThirtyEightDirection.allCases.shuffled().prefix(3))

    var stage = 0
    var dragOffset = CGSize.zero
    var fieldTravel: CGFloat = 0
    var fieldPulse: CGFloat = 0
    var completed = false
    var resolving = false

    var direction: LevelThirtyEightDirection {
        directions[min(stage, directions.count - 1)]
    }

    var fieldVector: CGVector {
        let distance = hypot(dragOffset.width, dragOffset.height)
        guard distance > 2 else { return direction.vector }
        return CGVector(
            dx: dragOffset.width / distance,
            dy: dragOffset.height / distance
        )
    }

    var progress: Double {
        completed ? 1 : Double(stage) / Double(directions.count)
    }

    func updateDrag(_ translation: CGSize, limit: CGFloat) {
        guard !resolving, !completed else { return }
        let distance = hypot(translation.width, translation.height)
        let scale = distance > limit ? limit / distance : 1
        dragOffset = CGSize(width: translation.width * scale, height: translation.height * scale)

        fieldTravel = min(1, hypot(dragOffset.width, dragOffset.height) / limit)
    }

    func finishDrag(limit: CGFloat) {
        guard !resolving, !completed else { return }
        let vector = direction.vector
        let forward = dragOffset.width * vector.dx + dragOffset.height * vector.dy
        let sideways = abs(dragOffset.width * vector.dy - dragOffset.height * vector.dx)

        guard forward >= limit * 0.68, sideways <= limit * 0.48 else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                dragOffset = .zero
                fieldTravel = 0
            }
            return
        }

        resolving = true
        HapticPlayer.playLightTap()
        withAnimation(.easeOut(duration: 0.48)) {
            dragOffset = CGSize(width: vector.dx * limit, height: vector.dy * limit)
            fieldTravel = 1
            fieldPulse = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            if self.stage == self.directions.count - 1 {
                HapticPlayer.playCompletionTap()
                withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                    self.completed = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.32)) {
                    self.dragOffset = .zero
                    self.fieldTravel = 0
                    self.fieldPulse = 0
                }
                self.stage += 1
                self.resolving = false
            }
        }
    }
}

struct MathItLevelThirtyEightView: View {
    var viewModel: MathItLevelThirtyEightViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let blue = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSide = min(size.width - 44, size.height * 0.49)
            let board = CGRect(
                x: (size.width - boardSide) / 2,
                y: size.height * 0.205,
                width: boardSide,
                height: boardSide
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    EmptyView()
                        .font(.trajan(36))
                        .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.34))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(blue)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                coordinateBoard(board)

                cardinalIndicator(size: size, board: board)

                CompletionOverlay(
                    title: "Level 38 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private func coordinateBoard(_ board: CGRect) -> some View {
        let center = CGPoint(x: board.midX, y: board.midY)
        let dragLimit = board.width * 0.29

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.018))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.17), lineWidth: 1)
                }
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            LevelThirtyEightGrid()
                .stroke(.white.opacity(0.13), lineWidth: 0.8)
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            LevelThirtyEightAxes()
                .stroke(.white.opacity(0.48), lineWidth: 1.25)
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            LevelThirtyEightVectorField(
                vector: viewModel.fieldVector,
                travel: viewModel.fieldTravel,
                pulse: viewModel.fieldPulse
            )
            .stroke(
                blue.opacity(0.38 + viewModel.fieldTravel * 0.58),
                style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: blue.opacity(viewModel.fieldTravel * 0.72), radius: 5)
            .frame(width: board.width, height: board.height)
            .position(x: board.midX, y: board.midY)
            .animation(.easeOut(duration: 0.22), value: viewModel.fieldTravel)

            Circle()
                .stroke(blue.opacity(0.24), lineWidth: 1)
                .frame(width: 52, height: 52)
                .position(center)

            Circle()
                .fill(.white)
                .frame(width: 27, height: 27)
                .shadow(color: .white.opacity(0.8), radius: 13)
                .position(
                    x: center.x + viewModel.dragOffset.width,
                    y: center.y + viewModel.dragOffset.height
                )
                .contentShape(Circle().inset(by: -26))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.updateDrag(value.translation, limit: dragLimit)
                        }
                        .onEnded { _ in
                            viewModel.finishDrag(limit: dragLimit)
                        }
                )
        }
    }

    private func cardinalIndicator(size: CGSize, board: CGRect) -> some View {
        let direction = viewModel.direction

        return VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<viewModel.directions.count, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.stage ? blue : .white.opacity(index == viewModel.stage ? 0.72 : 0.16))
                        .frame(width: 7, height: 7)
                        .shadow(color: index == viewModel.stage ? blue.opacity(0.8) : .clear, radius: 5)
                }
            }

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 96, height: 96)

                Image(systemName: "arrow.up")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(blue)
                    .shadow(color: blue.opacity(0.72), radius: 8)
                    .rotationEffect(cardinalRotation(direction))

                cardinalLetter("N", selected: direction == .north)
                    .offset(y: -62)
                cardinalLetter("E", selected: direction == .east)
                    .offset(x: 62)
                cardinalLetter("S", selected: direction == .south)
                    .offset(y: 62)
                cardinalLetter("W", selected: direction == .west)
                    .offset(x: -62)
            }
            .id(viewModel.stage)
            .transition(.scale.combined(with: .opacity))
        }
        .position(x: size.width / 2, y: min(size.height - 118, board.maxY + 112))
    }

    private func cardinalLetter(_ text: String, selected: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(selected ? blue : .white.opacity(0.28))
    }

    private func cardinalRotation(_ direction: LevelThirtyEightDirection) -> Angle {
        switch direction {
        case .north: .degrees(0)
        case .east: .degrees(90)
        case .south: .degrees(180)
        case .west: .degrees(270)
        }
    }
}

private struct LevelThirtyEightGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let divisions = 8

        for index in 1..<divisions {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(divisions)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))

            let y = rect.minY + rect.height * CGFloat(index) / CGFloat(divisions)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

private struct LevelThirtyEightAxes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private struct LevelThirtyEightVectorField: Shape {
    let vector: CGVector
    let travel: CGFloat
    let pulse: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing = rect.width / 8
        let shaftLength = spacing * (0.25 + travel * 0.18)
        let headLength = shaftLength * 0.38
        let directionBlend = smoothstep(min(1, travel * 1.8))
        let fieldCenter = CGPoint(x: rect.midX, y: rect.midY)

        for row in 1..<8 {
            for column in 1..<8 {
                let center = CGPoint(
                    x: rect.minX + CGFloat(column) * spacing,
                    y: rect.minY + CGFloat(row) * spacing
                )
                let inward = normalized(
                    CGVector(dx: fieldCenter.x - center.x, dy: fieldCenter.y - center.y),
                    fallback: vector
                )
                let arrowVector = normalized(
                    CGVector(
                        dx: inward.dx * (1 - directionBlend) + vector.dx * directionBlend,
                        dy: inward.dy * (1 - directionBlend) + vector.dy * directionBlend
                    ),
                    fallback: vector
                )

                let start = CGPoint(
                    x: center.x - arrowVector.dx * shaftLength * 0.5,
                    y: center.y - arrowVector.dy * shaftLength * 0.5
                )
                let end = CGPoint(
                    x: center.x + arrowVector.dx * shaftLength * 0.5,
                    y: center.y + arrowVector.dy * shaftLength * 0.5
                )
                let perpendicular = CGVector(dx: -arrowVector.dy, dy: arrowVector.dx)

                path.move(to: start)
                path.addLine(to: end)
                path.move(to: end)
                path.addLine(to: CGPoint(
                    x: end.x - arrowVector.dx * headLength + perpendicular.dx * headLength * 0.55,
                    y: end.y - arrowVector.dy * headLength + perpendicular.dy * headLength * 0.55
                ))
                path.move(to: end)
                path.addLine(to: CGPoint(
                    x: end.x - arrowVector.dx * headLength - perpendicular.dx * headLength * 0.55,
                    y: end.y - arrowVector.dy * headLength - perpendicular.dy * headLength * 0.55
                ))
            }
        }
        return path
    }

    private func normalized(_ vector: CGVector, fallback: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return fallback }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    private func smoothstep(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }
}
