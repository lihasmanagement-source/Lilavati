import SwiftUI

@Observable
final class MathItLevelFortyViewModel {
    let datasets: [[Int]] = [
        [1, 2, 3, 6],
        [2, 4, 4, 6],
        [1, 3, 6, 6]
    ]

    var stage = 0
    var fulcrumValue: CGFloat = 1
    var locked = false
    var completed = false

    var dataset: [Int] {
        datasets[min(stage, datasets.count - 1)]
    }

    var mean: CGFloat {
        CGFloat(dataset.reduce(0, +)) / CGFloat(dataset.count)
    }

    var tilt: CGFloat {
        min(12, max(-12, (mean - fulcrumValue) * 4.5))
    }

    var progress: Double {
        completed ? 1 : (Double(stage) + (locked ? 1 : 0)) / Double(datasets.count)
    }

    func moveFulcrum(to value: CGFloat) {
        guard !locked, !completed else { return }
        fulcrumValue = min(6, max(0, value))
    }

    func finishMove() {
        guard !locked, !completed else { return }
        guard abs(fulcrumValue - mean) < 0.24 else { return }
        locked = true
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) {
            fulcrumValue = mean
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            if self.stage == self.datasets.count - 1 {
                HapticPlayer.playCompletionTap()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                        self.completed = true
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.45)) {
                    self.stage += 1
                    self.fulcrumValue = 1
                    self.locked = false
                }
            }
        }
    }
}

struct MathItLevelFortyView: View {
    var viewModel: MathItLevelFortyViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let orange = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let line = CGRect(
                x: 34,
                y: size.height * 0.46,
                width: size.width - 68,
                height: 4
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
                    .tint(orange)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                datasetStage(line: line)

                CompletionOverlay(
                    title: "Level 40 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelForty")
        }
    }

    private func datasetStage(line: CGRect) -> some View {
        let pivot = point(for: viewModel.fulcrumValue, line: line)
        return ZStack {
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.72))
                    .frame(width: line.width, height: 4)

                ForEach(0...6, id: \.self) { value in
                    VStack(spacing: 7) {
                        Rectangle()
                            .fill(.white.opacity(0.42))
                            .frame(width: 1, height: 10)

                        Text("\(value)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .position(x: CGFloat(value) / 6 * line.width, y: 18)
                }

                ForEach(Array(viewModel.dataset.enumerated()), id: \.offset) { index, value in
                    Circle()
                        .fill(orange)
                        .frame(width: 25, height: 25)
                        .shadow(color: orange.opacity(0.7), radius: 8)
                        .position(
                            x: CGFloat(value) / 6 * line.width,
                            y: -18 - CGFloat(stackIndex(at: index)) * 28
                        )
                }
            }
            .frame(width: line.width, height: 80)
            .rotationEffect(.degrees(viewModel.locked ? 0 : viewModel.tilt), anchor: UnitPoint(
                x: viewModel.fulcrumValue / 6,
                y: 0.5
            ))
            .position(x: line.midX, y: line.midY)
            .animation(.spring(response: 0.42, dampingFraction: 0.72), value: viewModel.fulcrumValue)
            .animation(.spring(response: 0.52, dampingFraction: 0.74), value: viewModel.stage)

            LevelFortyTriangle()
                .fill(viewModel.locked ? orange : .white.opacity(0.28))
                .frame(width: 42, height: 38)
                .shadow(color: viewModel.locked ? orange.opacity(0.65) : .clear, radius: 8)
                .position(x: pivot.x, y: line.midY + 27)
                .contentShape(Rectangle().inset(by: -18))
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("levelForty"))
                        .onChanged { value in
                            viewModel.moveFulcrum(to: (value.location.x - line.minX) / line.width * 6)
                        }
                        .onEnded { _ in viewModel.finishMove() }
                )

        }
    }

    private func point(for value: CGFloat, line: CGRect) -> CGPoint {
        CGPoint(x: line.minX + value / 6 * line.width, y: line.midY)
    }

    private func stackIndex(at index: Int) -> Int {
        let value = viewModel.dataset[index]
        return viewModel.dataset[..<index].filter { $0 == value }.count
    }
}

private struct LevelFortyTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
