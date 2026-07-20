import SwiftUI

@Observable
final class MathItLevelThirtyTwoViewModel {
    var selectedAmount = 1
    var releasedBlocks = 0
    var fallingBlock: Int?
    var fallingBlockStartedAt: Date?
    var releasing = false
    var result: LevelThirtyTwoResult?
    var completed = false
    private var runID = UUID()

    var progress: Double {
        if completed { return 1 }
        if releasing { return min(0.92, Double(releasedBlocks) / 30) }
        return min(0.5, Double(selectedAmount) / 60)
    }

    func increment() {
        guard !releasing, result == nil else { return }
        selectedAmount = min(40, selectedAmount + 1)
        HapticPlayer.playLightTap()
    }

    func decrement() {
        guard !releasing, result == nil else { return }
        selectedAmount = max(0, selectedAmount - 1)
        HapticPlayer.playLightTap()
    }

    func release() {
        guard !releasing, result == nil else { return }
        releasing = true
        releasedBlocks = 0
        let id = UUID()
        runID = id
        dropNext(index: 1, run: id)
    }

    func reset() {
        runID = UUID()
        selectedAmount = 1
        releasedBlocks = 0
        fallingBlock = nil
        fallingBlockStartedAt = nil
        releasing = false
        result = nil
        completed = false
    }

    private func dropNext(index: Int, run: UUID) {
        guard run == runID else { return }
        guard index <= selectedAmount else {
            finish(run: run)
            return
        }

        fallingBlock = index
        fallingBlockStartedAt = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard self.runID == run else { return }
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.72)) {
                self.releasedBlocks = index
                self.fallingBlock = nil
                self.fallingBlockStartedAt = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                self.dropNext(index: index + 1, run: run)
            }
        }
    }

    private func finish(run: UUID) {
        guard run == runID else { return }
        releasing = false
        let outcome: LevelThirtyTwoResult = selectedAmount == 30 ? .perfect : (selectedAmount < 30 ? .underfilled : .overflow)
        withAnimation(.spring(response: 0.75, dampingFraction: 0.72)) {
            result = outcome
        }

        if outcome == .perfect {
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) {
                guard self.runID == run else { return }
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                    self.completed = true
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
                guard self.runID == run else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.releasedBlocks = 0
                    self.result = nil
                    self.selectedAmount = 1
                }
            }
        }
    }
}

enum LevelThirtyTwoResult {
    case underfilled
    case overflow
    case perfect
}

struct MathItLevelThirtyTwoView: View {
    var viewModel: MathItLevelThirtyTwoViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let water = Color(red: 0.26, green: 0.60, blue: 1.0)
    private let leaf = Color.mathItAlgebra
    private let bloom = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let pot = CGRect(
                x: size.width / 2 - min(142, size.width * 0.35),
                y: size.height * 0.67,
                width: min(284, size.width * 0.7),
                height: min(245, size.height * 0.28)
            )
            let faucet = CGPoint(x: size.width / 2, y: size.height * 0.24)

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
                    .tint(viewModel.result == .perfect ? leaf : water)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                faucetView(at: faucet)
                fallingBlocks(spout: CGPoint(x: faucet.x + 42, y: faucet.y + 16), pot: pot)
                measuredPot(pot)
                flower(at: CGPoint(x: pot.midX - 12, y: pot.minY + 35))

                CompletionOverlay(
                    title: "Level 32 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private func faucetView(at point: CGPoint) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: point.x - 122, y: point.y - 18))
                path.addLine(to: CGPoint(x: point.x - 62, y: point.y - 18))
                path.addCurve(
                    to: CGPoint(x: point.x + 42, y: point.y - 3),
                    control1: CGPoint(x: point.x - 56, y: point.y - 84),
                    control2: CGPoint(x: point.x + 42, y: point.y - 84)
                )
                path.addLine(to: CGPoint(x: point.x + 42, y: point.y + 16))
            }
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.36), .white.opacity(0.94), .gray.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: water.opacity(0.28), radius: 9)

            Path { path in
                path.move(to: CGPoint(x: point.x - 120, y: point.y - 22))
                path.addLine(to: CGPoint(x: point.x - 65, y: point.y - 22))
                path.addCurve(
                    to: CGPoint(x: point.x + 38, y: point.y - 6),
                    control1: CGPoint(x: point.x - 54, y: point.y - 75),
                    control2: CGPoint(x: point.x + 38, y: point.y - 75)
                )
            }
            .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.88), .gray.opacity(0.44)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 30, height: 18)
                .overlay { Capsule().stroke(.white.opacity(0.5), lineWidth: 1) }
                .position(x: point.x + 42, y: point.y + 16)

            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.82), .gray.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 17, height: 42)
                .overlay { RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.42), lineWidth: 1) }
                .position(x: point.x - 70, y: point.y - 43)

            Capsule()
                .fill(.white.opacity(0.8))
                .frame(width: 62, height: 8)
                .overlay { Capsule().stroke(.gray.opacity(0.72), lineWidth: 1) }
                .position(x: point.x - 70, y: point.y - 67)

            Capsule()
                .fill(.gray.opacity(0.72))
                .frame(width: 15, height: 31)
                .position(x: point.x - 122, y: point.y - 18)

            HStack(spacing: 15) {
                controlButton(systemName: "minus", action: viewModel.decrement)

                Text("\(viewModel.selectedAmount)")
                    .font(.system(size: 25, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(water.opacity(0.65), lineWidth: 1.4)
                    }
                    .shadow(color: water.opacity(0.36), radius: 8)

                controlButton(systemName: "plus", action: viewModel.increment)

                Button(action: viewModel.release) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.releasing ? .black : water)
                        .frame(width: 48, height: 48)
                        .background(viewModel.releasing ? water : .black, in: Circle())
                        .overlay { Circle().stroke(water.opacity(0.8), lineWidth: 1.5) }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.releasing || viewModel.result != nil)
            }
            .position(x: point.x, y: point.y + 82)
        }
    }

    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .overlay { Circle().stroke(.white.opacity(0.42), lineWidth: 1.2) }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.releasing || viewModel.result != nil)
    }

    private func measuredPot(_ pot: CGRect) -> some View {
        let depth = CGSize(width: 34, height: -28)
        let front = CGRect(
            x: pot.minX,
            y: pot.minY - depth.height,
            width: pot.width - depth.width,
            height: pot.height + depth.height
        )
        let blockWidth = front.width / 3
        let blockHeight = front.height / 5
        let visibleCount = min(viewModel.releasedBlocks, 30)

        return ZStack {
            ForEach(0..<visibleCount, id: \.self) { index in
                let layer = index / 15
                let indexInLayer = index % 15
                let row = indexInLayer / 3
                let column = indexInLayer % 3
                let layerOffset = CGSize(
                    width: CGFloat(layer) * depth.width * 0.72,
                    height: CGFloat(layer) * depth.height * 0.72
                )
                let x = front.minX + blockWidth * (CGFloat(column) + 0.5) + layerOffset.width
                let y = front.maxY - blockHeight * (CGFloat(row) + 0.5) + layerOffset.height

                RoundedRectangle(cornerRadius: 3)
                    .fill(water.opacity(layer == 0 ? 0.27 : 0.48))
                    .frame(width: blockWidth - 9, height: blockHeight - 8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(water.opacity(0.72), lineWidth: 1)
                    }
                    .shadow(color: water.opacity(0.35), radius: 5)
                    .position(x: x, y: y)
                    .zIndex(layer == 0 ? 2 : 1)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }

            if viewModel.releasedBlocks > 30 {
                ForEach(30..<viewModel.releasedBlocks, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(water.opacity(0.48))
                        .frame(width: blockWidth - 8, height: blockHeight - 7)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(water.opacity(0.8), lineWidth: 1)
                        }
                        .rotationEffect(.degrees(Double((index * 17) % 36) - 18))
                        .position(
                            x: front.minX + CGFloat((index * 47) % Int(max(1, front.width))),
                            y: front.minY - 18 - CGFloat((index - 30) % 3) * 15
                        )
                }
            }

            potWireframe(front: front, depth: depth)
            measurementTicks(front: front, depth: depth)
        }
    }

    private func potWireframe(front: CGRect, depth: CGSize) -> some View {
        let backTopLeft = CGPoint(x: front.minX + depth.width, y: front.minY + depth.height)
        let backTopRight = CGPoint(x: front.maxX + depth.width, y: front.minY + depth.height)
        let backBottomRight = CGPoint(x: front.maxX + depth.width, y: front.maxY + depth.height)

        return ZStack {
            Path { path in
                path.addRect(front)
                path.move(to: CGPoint(x: front.minX, y: front.minY))
                path.addLine(to: backTopLeft)
                path.addLine(to: backTopRight)
                path.addLine(to: CGPoint(x: front.maxX, y: front.minY))
                path.move(to: backTopRight)
                path.addLine(to: backBottomRight)
                path.addLine(to: CGPoint(x: front.maxX, y: front.maxY))
            }
            .stroke(.white.opacity(0.68), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            .shadow(color: water.opacity(0.32), radius: 7)

            Path { path in
                path.move(to: backTopLeft)
                path.addLine(to: CGPoint(x: backTopLeft.x, y: backTopLeft.y + front.height))
                path.addLine(to: CGPoint(x: front.minX, y: front.maxY))
            }
            .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

            Path { path in
                for index in 1..<3 {
                    let x = front.minX + front.width * CGFloat(index) / 3
                    path.move(to: CGPoint(x: x, y: front.minY))
                    path.addLine(to: CGPoint(x: x, y: front.maxY))
                }
                for index in 1..<5 {
                    let y = front.minY + front.height * CGFloat(index) / 5
                    path.move(to: CGPoint(x: front.minX, y: y))
                    path.addLine(to: CGPoint(x: front.maxX, y: y))
                }
            }
            .stroke(.white.opacity(0.11), lineWidth: 0.8)
        }
    }

    private func measurementTicks(front: CGRect, depth: CGSize) -> some View {
        ZStack {
            ForEach(1..<3, id: \.self) { index in
                Rectangle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 1, height: 10)
                    .position(x: front.minX + front.width * CGFloat(index) / 3, y: front.maxY + 5)
            }

            ForEach(1..<5, id: \.self) { index in
                Rectangle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 10, height: 1)
                    .position(x: front.minX - 5, y: front.maxY - front.height * CGFloat(index) / 5)
            }

            Path { path in
                let start = CGPoint(x: front.maxX, y: front.maxY)
                let end = CGPoint(x: start.x + depth.width, y: start.y + depth.height)
                let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                path.move(to: start)
                path.addLine(to: end)
                path.move(to: CGPoint(x: midpoint.x - 5, y: midpoint.y - 6))
                path.addLine(to: CGPoint(x: midpoint.x + 5, y: midpoint.y + 6))
            }
            .stroke(.white.opacity(0.72), lineWidth: 1.4)
        }
    }

    private func fallingBlocks(spout: CGPoint, pot: CGRect) -> some View {
        TimelineView(.animation) { context in
            if let block = viewModel.fallingBlock, let startedAt = viewModel.fallingBlockStartedAt {
                let elapsed = context.date.timeIntervalSince(startedAt)
                let phase = min(1, max(0, CGFloat(elapsed / 0.2)))
                let fall = phase * phase
                let columnOffset = CGFloat((block - 1) % 3 - 1) * 24
                let destination = CGPoint(x: pot.midX + columnOffset, y: pot.minY + 22)
                let x = spout.x + (destination.x - spout.x) * phase
                let y = spout.y + (destination.y - spout.y) * fall

                ZStack {
                    if phase < 0.34 {
                        Capsule()
                            .fill(water.opacity(0.36))
                            .frame(width: 8, height: 18 + phase * 28)
                            .position(x: spout.x, y: spout.y + 8)
                    }

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.92), water.opacity(0.78), water.opacity(0.42)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.75), lineWidth: 1)
                        }
                        .rotationEffect(.degrees(Double(phase) * 90))
                        .shadow(color: water, radius: 8)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private func flower(at point: CGPoint) -> some View {
        TimelineView(.animation) { context in
            let pulse = CGFloat((sin(context.date.timeIntervalSinceReferenceDate * 3.2) + 1) / 2)
            let perfect = viewModel.result == .perfect
            let dead = viewModel.result == .underfilled || viewModel.result == .overflow
            let blossomY: CGFloat = perfect ? 42 : 92
            let baseY: CGFloat = 205
            let stemColor = dead ? Color.gray.opacity(0.42) : leaf

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 100, y: baseY))
                    path.addCurve(
                        to: CGPoint(x: 100, y: blossomY + 10),
                        control1: CGPoint(x: dead ? 126 : 96, y: 160),
                        control2: CGPoint(x: dead ? 132 : 104, y: 95)
                    )
                    path.move(to: CGPoint(x: 100, y: 150))
                    path.addCurve(
                        to: CGPoint(x: 58, y: 126),
                        control1: CGPoint(x: 86, y: 145),
                        control2: CGPoint(x: 72, y: 132)
                    )
                    path.move(to: CGPoint(x: 101, y: 127))
                    path.addCurve(
                        to: CGPoint(x: 143, y: 102),
                        control1: CGPoint(x: 116, y: 120),
                        control2: CGPoint(x: 132, y: 107)
                    )
                }
                .stroke(stemColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .shadow(color: perfect ? leaf.opacity(0.58) : .clear, radius: 7)

                Ellipse()
                    .fill(stemColor.opacity(0.9))
                    .frame(width: perfect ? 58 : 42, height: perfect ? 23 : 18)
                    .rotationEffect(.degrees(dead ? 35 : -28))
                    .position(x: 57, y: 124)

                Ellipse()
                    .fill(stemColor.opacity(0.9))
                    .frame(width: perfect ? 62 : 44, height: perfect ? 24 : 18)
                    .rotationEffect(.degrees(dead ? 58 : 28))
                    .position(x: 144, y: 100)

                ZStack {
                    ForEach(0..<10, id: \.self) { index in
                        Ellipse()
                            .fill(dead ? .gray.opacity(0.32) : bloom.opacity(0.9))
                            .frame(width: perfect ? 28 : 20, height: perfect ? 62 : 40)
                            .offset(y: perfect ? -29 : -19)
                            .rotationEffect(.degrees(Double(index) * 36))
                            .shadow(color: perfect ? bloom.opacity(0.62) : .clear, radius: 7 + pulse * 5)
                    }

                    ForEach(0..<6, id: \.self) { index in
                        Ellipse()
                            .fill(dead ? .gray.opacity(0.4) : Color.white.opacity(0.82))
                            .frame(width: perfect ? 17 : 12, height: perfect ? 34 : 24)
                            .offset(y: perfect ? -15 : -10)
                            .rotationEffect(.degrees(Double(index) * 60 + 30))
                    }

                    Circle()
                        .fill(dead ? .gray.opacity(0.5) : Color.mathItAlgebra)
                        .frame(width: perfect ? 31 : 21, height: perfect ? 31 : 21)
                        .overlay {
                            Circle().stroke(.white.opacity(dead ? 0.12 : 0.8), lineWidth: 1.2)
                        }
                        .shadow(color: perfect ? .white.opacity(0.9) : .clear, radius: 12 + pulse * 8)
                }
                .position(x: dead ? 124 : 100, y: blossomY)
            }
            .frame(width: 200, height: 220)
            .rotationEffect(.degrees(dead ? 14 : 0), anchor: .bottom)
            .position(x: point.x, y: point.y - 110)
            .animation(.spring(response: 0.9, dampingFraction: 0.65), value: viewModel.result)
        }
        .allowsHitTesting(false)
    }
}
