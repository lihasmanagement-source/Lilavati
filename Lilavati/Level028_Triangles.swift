import SwiftUI

struct LevelFortyOneChallenge {
    let name: String
    let targetAngles: [Int]
}

@Observable
final class MathItLevelFortyOneViewModel {
    let challenges = [
        LevelFortyOneChallenge(
            name: "equilateral",
            targetAngles: [60, 60, 60]
        ),
        LevelFortyOneChallenge(
            name: "right isosceles",
            targetAngles: [45, 45, 90]
        ),
        LevelFortyOneChallenge(
            name: "30 - 60 - 90",
            targetAngles: [30, 60, 90]
        )
    ]

    var stage = 0
    var leftAngle = 55
    var rightAngle = 75
    var locked = false
    var completed = false

    var challenge: LevelFortyOneChallenge {
        challenges[min(stage, challenges.count - 1)]
    }

    var progress: Double {
        completed ? 1 : Double(stage) / Double(challenges.count)
    }

    func moveApex(to point: CGPoint, in board: CGRect) {
        guard !locked, !completed else { return }
        let base = basePoints(in: board)
        let proposed = [base.left, base.right, point]
        let measured = measuredAngles(for: proposed)
        let snappedLeft = Int(measured[0].rounded())
        let snappedRight = Int(measured[1].rounded())

        guard point.y < base.left.y,
              snappedLeft >= 5,
              snappedRight >= 5,
              snappedLeft + snappedRight <= 175,
              board.insetBy(dx: 8, dy: 8).contains(
                apexPoint(leftAngle: snappedLeft, rightAngle: snappedRight, in: board)
              ) else { return }

        leftAngle = snappedLeft
        rightAngle = snappedRight
    }

    func finishMove() {
        guard !locked, !completed else { return }
        guard anglesMatchTarget(degreeAngles) else {
            HapticPlayer.playLightTap()
            return
        }

        locked = true
        HapticPlayer.playCompletionTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.stage == self.challenges.count - 1 {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                    self.completed = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.42)) {
                    self.stage += 1
                    self.leftAngle = 55
                    self.rightAngle = 75
                    self.locked = false
                }
            }
        }
    }

    func points(in board: CGRect) -> [CGPoint] {
        let base = basePoints(in: board)
        return [
            base.left,
            base.right,
            apexPoint(leftAngle: leftAngle, rightAngle: rightAngle, in: board)
        ]
    }

    var degreeAngles: [Int] {
        [leftAngle, rightAngle, 180 - leftAngle - rightAngle]
    }

    func anglesMatchTarget(_ measuredAngles: [Int]) -> Bool {
        let measured = measuredAngles.sorted()
        let target = challenge.targetAngles.sorted()
        return measured == target
    }

    func matchingAngles(_ measuredAngles: [Int]) -> Set<Int> {
        var remainingTargets = challenge.targetAngles
        var matches: Set<Int> = []

        for index in measuredAngles.indices {
            guard let targetIndex = remainingTargets.firstIndex(of: measuredAngles[index]) else { continue }
            matches.insert(index)
            remainingTargets.remove(at: targetIndex)
        }
        return matches
    }

    private func basePoints(in board: CGRect) -> (left: CGPoint, right: CGPoint) {
        let baseHalfWidth = min(board.width * 0.32, board.height * 0.34)
        let baseY = board.minY + board.height * 0.78
        return (
            CGPoint(x: board.midX - baseHalfWidth, y: baseY),
            CGPoint(x: board.midX + baseHalfWidth, y: baseY)
        )
    }

    private func apexPoint(leftAngle: Int, rightAngle: Int, in board: CGRect) -> CGPoint {
        let base = basePoints(in: board)
        let leftRadians = CGFloat(leftAngle) * .pi / 180
        let rightRadians = CGFloat(rightAngle) * .pi / 180
        let baseLength = base.right.x - base.left.x
        let leftToApex = baseLength * sin(rightRadians) / sin(leftRadians + rightRadians)
        return CGPoint(
            x: base.left.x + leftToApex * cos(leftRadians),
            y: base.left.y - leftToApex * sin(leftRadians)
        )
    }

    private func measuredAngles(for points: [CGPoint]) -> [CGFloat] {
        [
            measuredAngle(at: points[0], between: points[1], and: points[2]),
            measuredAngle(at: points[1], between: points[0], and: points[2]),
            measuredAngle(at: points[2], between: points[0], and: points[1])
        ]
    }

    private func measuredAngle(at vertex: CGPoint, between first: CGPoint, and second: CGPoint) -> CGFloat {
        let firstVector = CGVector(dx: first.x - vertex.x, dy: first.y - vertex.y)
        let secondVector = CGVector(dx: second.x - vertex.x, dy: second.y - vertex.y)
        let firstLength = hypot(firstVector.dx, firstVector.dy)
        let secondLength = hypot(secondVector.dx, secondVector.dy)
        guard firstLength > 1, secondLength > 1 else { return 0 }
        let cosine = (firstVector.dx * secondVector.dx + firstVector.dy * secondVector.dy) / (firstLength * secondLength)
        return acos(min(1, max(-1, cosine))) * 180 / .pi
    }
}

struct MathItLevelFortyOneView: View {
    var viewModel: MathItLevelFortyOneViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let cyan = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(
                x: 28,
                y: size.height * 0.24,
                width: size.width - 56,
                height: min(size.height * 0.52, 450)
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
                    .tint(cyan)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                challengeLabel(size: size)
                triangleBoard(board)

                CompletionOverlay(
                    title: "Level 41 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelFortyOne")
        }
    }

    private func challengeLabel(size: CGSize) -> some View {
        VStack(spacing: 5) {
            Text("FORGE A \(viewModel.challenge.name.uppercased()) TRIANGLE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(cyan)

            Text(viewModel.challenge.targetAngles.map { "\($0)°" }.joined(separator: "  ·  "))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.mathGold.opacity(0.85))
        }
        .position(x: size.width / 2, y: size.height * 0.19)
    }

    private func triangleBoard(_ board: CGRect) -> some View {
        let points = viewModel.points(in: board)
        let angles = viewModel.degreeAngles
        let matchingAngles = viewModel.matchingAngles(angles)

        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.018))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.11), lineWidth: 1)
                }
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            LevelFortyOneGrid()
                .stroke(.white.opacity(0.055), lineWidth: 0.7)
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            Path { path in
                path.move(to: points[0])
                path.addLine(to: points[1])
                path.addLine(to: points[2])
                path.closeSubpath()
            }
            .fill(cyan.opacity(viewModel.locked ? 0.18 : 0.055))
            .stroke(
                viewModel.locked ? cyan : .white.opacity(0.72),
                style: StrokeStyle(lineWidth: viewModel.locked ? 3 : 2, lineJoin: .round)
            )
            .shadow(color: viewModel.locked ? cyan.opacity(0.72) : .white.opacity(0.12), radius: viewModel.locked ? 16 : 5)

            ForEach(0..<3, id: \.self) { index in
                angleBadge(value: angles[index], matchesTarget: matchingAngles.contains(index))
                    .position(badgePoint(for: index, points: points))
            }

            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(.black)
                    .overlay { Circle().stroke(.white.opacity(0.7), lineWidth: 1.6) }
                    .frame(width: 15, height: 15)
                    .position(points[index])
            }

            Circle()
                .fill(viewModel.locked ? cyan : .white)
                .frame(width: 28, height: 28)
                .overlay { Circle().stroke(cyan.opacity(0.8), lineWidth: 2) }
                .shadow(color: cyan.opacity(0.8), radius: viewModel.locked ? 15 : 8)
                .position(points[2])
                .contentShape(Circle().inset(by: -20))
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("levelFortyOne"))
                        .onChanged { value in
                            viewModel.moveApex(to: value.location, in: board)
                        }
                        .onEnded { _ in
                            viewModel.finishMove()
                        }
                )
        }
    }

    private func angleBadge(value: Int, matchesTarget: Bool) -> some View {
        return Text("\(value)°")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(matchesTarget ? cyan : .white.opacity(0.72))
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(.black.opacity(0.9), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(matchesTarget ? cyan.opacity(0.7) : .white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: matchesTarget ? cyan.opacity(0.55) : .clear, radius: 6)
    }

    private func badgePoint(for index: Int, points: [CGPoint]) -> CGPoint {
        let vertex = points[index]
        let centroid = CGPoint(
            x: (points[0].x + points[1].x + points[2].x) / 3,
            y: (points[0].y + points[1].y + points[2].y) / 3
        )
        let distance: CGFloat = index == 2 ? 46 : 52
        let dx = centroid.x - vertex.x
        let dy = centroid.y - vertex.y
        let length = max(1, sqrt(dx * dx + dy * dy))
        return CGPoint(x: vertex.x + dx / length * distance, y: vertex.y + dy / length * distance)
    }

}

private struct LevelFortyOneGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 28

        stride(from: CGFloat(0), through: rect.width, by: spacing).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        stride(from: CGFloat(0), through: rect.height, by: spacing).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}
