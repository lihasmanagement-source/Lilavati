import SwiftUI

@Observable
final class MathItLevelTwentyEightViewModel {
    var magneticAngle: Double = 48
    var completed = false
    var stabilizedAt: Date?

    var progress: Double {
        if completed { return 1 }
        return min(0.96, max(0.08, 1 - alignmentError / 90))
    }

    var isAligned: Bool {
        alignmentError <= 4
    }

    var displayAngle: Double {
        normalizedAxisAngle(magneticAngle)
    }

    var alignmentError: Double {
        abs(displayAngle)
    }

    func rotateAxis(touch: CGPoint, center: CGPoint) {
        guard !completed else { return }
        let radians = atan2(touch.y - center.y, touch.x - center.x)
        let rawAngle = Double(radians * 180 / .pi) + 90
        let nearestTurn = ((magneticAngle - rawAngle) / 180).rounded()
        magneticAngle = rawAngle + nearestTurn * 180
    }

    func finishRotation() {
        guard isAligned, !completed, stabilizedAt == nil else { return }
        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            magneticAngle = (magneticAngle / 180).rounded() * 180
            stabilizedAt = Date()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    private func normalizedAxisAngle(_ angle: Double) -> Double {
        var result = angle.truncatingRemainder(dividingBy: 180)
        if result > 90 {
            result -= 180
        } else if result < -90 {
            result += 180
        }
        return result
    }
}

struct MathItLevelTwentyEightView: View {
    var viewModel: MathItLevelTwentyEightViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let cyan = Color.mathItMusic

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 18, y: size.height * 0.18, width: size.width - 36, height: min(570, size.height * 0.67))
            let center = CGPoint(x: board.midX, y: board.midY - 14)

            ZStack {
                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    Text("pulsar")
                        .font(.trajan(36))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(cyan)
                    .opacity(0.78)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.012))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(cyan.opacity(0.22), lineWidth: 1.1)
                    }
                    .frame(width: board.width, height: board.height)
                    .position(x: board.midX, y: board.midY)

                stars(in: board)

                Path { path in
                    path.move(to: CGPoint(x: center.x, y: board.minY + 34))
                    path.addLine(to: CGPoint(x: center.x, y: board.maxY - 42))
                }
                .stroke(Color.mathGold.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [5, 6]))

                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let wobble = viewModel.stabilizedAt == nil
                        ? sin(time * 3.1) * viewModel.alignmentError * 0.055
                        : 0
                    let displayAngle = viewModel.magneticAngle + wobble

                    ZStack {
                        magneticField(center: center, angle: displayAngle)
                        beamPair(center: center, angle: displayAngle, board: board)
                        pulsar(center: center, time: time)
                        axisHandles(center: center, angle: displayAngle)
                    }
                }

                angleArc(center: center)

                Text("\(Int(viewModel.alignmentError.rounded()))°")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(viewModel.isAligned ? cyan : .white.opacity(0.62))
                    .position(x: center.x + 54, y: center.y - 52)

                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: board.width, height: board.height)
                    .position(x: board.midX, y: board.midY)
                    .gesture(
                        DragGesture(coordinateSpace: .named("levelTwentyEightStage"))
                            .onChanged { value in
                                viewModel.rotateAxis(touch: value.location, center: center)
                            }
                            .onEnded { _ in
                                viewModel.finishRotation()
                            }
                    )

                CompletionOverlay(
                    title: "Level 28 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelTwentyEightStage")
        }
    }

    private func pulsar(center: CGPoint, time: Double) -> some View {
        let pulse = 1 + sin(time * 5) * 0.08
        return ZStack {
            Circle()
                .fill(cyan.opacity(0.12))
                .frame(width: 76, height: 76)
                .scaleEffect(pulse)
                .blur(radius: 6)

            Circle()
                .fill(.black)
                .overlay {
                    Circle().stroke(cyan, lineWidth: 1.8)
                }
                .frame(width: 48, height: 48)
                .shadow(color: cyan.opacity(0.75), radius: 16)
        }
        .position(center)
    }

    private func magneticField(center: CGPoint, angle: Double) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Ellipse()
                    .stroke(cyan.opacity(0.28 - Double(index) * 0.035), lineWidth: 1)
                    .frame(width: 102 + CGFloat(index) * 42, height: 54 + CGFloat(index) * 18)
                    .rotationEffect(.degrees(angle))
            }
        }
        .position(center)
    }

    private func beamPair(center: CGPoint, angle: Double, board: CGRect) -> some View {
        ZStack {
            LevelTwentyEightBeamShape()
                .fill(cyan.opacity(viewModel.isAligned ? 0.42 : 0.24))
                .overlay {
                    LevelTwentyEightBeamShape()
                        .stroke(cyan.opacity(0.72), lineWidth: 1)
                }
                .frame(width: 50, height: board.height * 0.43)
                .position(x: center.x, y: center.y - board.height * 0.215)

            LevelTwentyEightBeamShape()
                .fill(cyan.opacity(viewModel.isAligned ? 0.42 : 0.24))
                .overlay {
                    LevelTwentyEightBeamShape()
                        .stroke(cyan.opacity(0.72), lineWidth: 1)
                }
                .frame(width: 50, height: board.height * 0.43)
                .rotationEffect(.degrees(180))
                .position(x: center.x, y: center.y + board.height * 0.215)
        }
        .rotationEffect(.degrees(angle), anchor: .center)
        .shadow(color: cyan.opacity(viewModel.isAligned ? 0.7 : 0.2), radius: viewModel.isAligned ? 18 : 6)
    }

    private func axisHandles(center: CGPoint, angle: Double) -> some View {
        let radians = (angle - 90) * .pi / 180
        let direction = CGVector(dx: cos(radians), dy: sin(radians))
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: center.x - direction.dx * 82, y: center.y - direction.dy * 82))
                path.addLine(to: CGPoint(x: center.x + direction.dx * 82, y: center.y + direction.dy * 82))
            }
            .stroke(cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))

            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle()
                    .fill(.black)
                    .overlay { Circle().stroke(cyan, lineWidth: 1.8) }
                    .frame(width: 15, height: 15)
                    .shadow(color: cyan, radius: 8)
                    .position(
                        x: center.x + direction.dx * 82 * side,
                        y: center.y + direction.dy * 82 * side
                    )
            }
        }
    }

    private func angleArc(center: CGPoint) -> some View {
        LevelTwentyEightArcShape(angle: viewModel.displayAngle)
            .stroke(cyan.opacity(0.72), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: 90, height: 90)
            .position(center)
    }

    private func stars(in board: CGRect) -> some View {
        let positions: [(CGFloat, CGFloat)] = [
            (0.12, 0.16), (0.82, 0.12), (0.9, 0.28), (0.18, 0.74),
            (0.74, 0.8), (0.26, 0.32), (0.88, 0.62), (0.1, 0.48)
        ]
        return ZStack {
            ForEach(Array(positions.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(index.isMultiple(of: 3) ? .white : cyan)
                    .frame(width: index.isMultiple(of: 3) ? 3 : 2, height: index.isMultiple(of: 3) ? 3 : 2)
                    .shadow(color: cyan, radius: 4)
                    .position(x: board.minX + board.width * point.0, y: board.minY + board.height * point.1)
            }
        }
    }
}

private struct LevelTwentyEightBeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct LevelTwentyEightArcShape: Shape {
    let angle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = -90.0
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: .degrees(start),
            endAngle: .degrees(start + angle),
            clockwise: angle < 0
        )
        return path
    }
}
