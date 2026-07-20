import SwiftUI

enum LevelFortySevenPanSide {
    case left
    case right
}

struct LevelFortySevenStage {
    let leftCoins: Int
    let rightCoins: Int
}

@Observable
final class MathItLevelFortySevenViewModel {
    let stages = [
        LevelFortySevenStage(leftCoins: 5, rightCoins: 10),
        LevelFortySevenStage(leftCoins: 6, rightCoins: 14),
        LevelFortySevenStage(leftCoins: 9, rightCoins: 21)
    ]

    var stage = 0
    var bagValue = 1
    var bagSide: LevelFortySevenPanSide?
    var bagDragPosition: CGPoint?
    var completed = false
    var stageSolved = false

    var currentStage: LevelFortySevenStage {
        stages[min(stage, stages.count - 1)]
    }

    var leftWeight: Int {
        currentStage.leftCoins + (bagSide == .left ? bagValue : 0)
    }

    var rightWeight: Int {
        currentStage.rightCoins + (bagSide == .right ? bagValue : 0)
    }

    var progress: Double {
        if completed { return 1 }
        let stageProgress = Double(stage) / Double(stages.count)
        let localProgress: Double
        if stageSolved {
            localProgress = 1
        } else if bagSide != nil {
            localProgress = leftWeight == rightWeight ? 0.86 : 0.42
        } else {
            localProgress = 0.18
        }
        return stageProgress + localProgress / Double(stages.count)
    }

    var canAdjustBag: Bool {
        bagSide == nil && bagDragPosition == nil && !completed && !stageSolved
    }

    func incrementBag() {
        guard canAdjustBag else { return }
        bagValue = min(20, bagValue + 1)
        HapticPlayer.playLightTap()
    }

    func decrementBag() {
        guard canAdjustBag else { return }
        bagValue = max(0, bagValue - 1)
        HapticPlayer.playLightTap()
    }

    func moveBag(to location: CGPoint) {
        guard !completed, !stageSolved else { return }
        if bagDragPosition == nil {
            HapticPlayer.playLightTap()
        }
        bagDragPosition = location
        bagSide = nil
    }

    func finishMovingBag(leftPan: CGRect, rightPan: CGRect, home: CGPoint) {
        guard !completed, !stageSolved else { return }
        guard let position = bagDragPosition else { return }

        if leftPan.insetBy(dx: -20, dy: -20).contains(position) {
            placeBag(on: .left)
        } else if rightPan.insetBy(dx: -20, dy: -20).contains(position) {
            placeBag(on: .right)
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                bagDragPosition = home
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                self.bagDragPosition = nil
            }
        }
    }

    private func placeBag(on side: LevelFortySevenPanSide) {
        bagSide = side
        bagDragPosition = nil
        HapticPlayer.playLightTap()
        checkCompletion()
    }

    private func checkCompletion() {
        guard !completed, bagSide != nil, leftWeight == rightWeight else { return }
        HapticPlayer.playCompletionTap()
        stageSolved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            guard self.stageSolved else { return }
            if self.stage == self.stages.count - 1 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                    self.completed = true
                }
                return
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                self.stage += 1
                self.bagValue = 1
                self.bagSide = nil
                self.bagDragPosition = nil
                self.stageSolved = false
            }
        }
    }
}

struct MathItLevelFortySevenView: View {
    var viewModel: MathItLevelFortySevenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItAlgebra
    private let coinSize: CGFloat = 20
    private let bagSize: CGFloat = 58

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = layout(in: size)

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)
                scale(layout: layout)
                bagCounter(at: layout.counterCenter)
                bagSymbol(layout: layout)

                CompletionOverlay(
                    title: "Level 47 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
            .coordinateSpace(name: "levelFortySevenStage")
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 10) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.garamond(min(34, size.width * 0.085)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.36))

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: max(180, size.width - 68))
                .opacity(0.74)
                .padding(.top, 4)
        }
        .position(x: size.width / 2, y: 94)
    }

    private func scale(layout: LevelFortySevenLayout) -> some View {
        let tilt = tiltAngle
        let leftDrop = panDrop(for: .left)
        let rightDrop = panDrop(for: .right)

        return ZStack {
            Capsule()
                .fill(.white.opacity(0.2))
                .frame(width: 5, height: 142)
                .position(layout.standCenter)

            LevelFortySevenTriangle()
                .fill(.white.opacity(0.13))
                .frame(width: 78, height: 54)
                .position(x: layout.standCenter.x, y: layout.standCenter.y + 78)

            Capsule()
                .fill(viewModel.leftWeight == viewModel.rightWeight ? accent : .white.opacity(0.62))
                .frame(width: layout.beamWidth, height: 5)
                .rotationEffect(.degrees(tilt), anchor: .center)
                .shadow(color: viewModel.leftWeight == viewModel.rightWeight ? accent.opacity(0.48) : .clear, radius: 10)
                .position(layout.beamCenter)

            pan(
                at: CGPoint(x: layout.leftPanCenter.x, y: layout.leftPanCenter.y + leftDrop),
                count: viewModel.currentStage.leftCoins,
                total: viewModel.leftWeight,
                side: .left
            )

            pan(
                at: CGPoint(x: layout.rightPanCenter.x, y: layout.rightPanCenter.y + rightDrop),
                count: viewModel.currentStage.rightCoins,
                total: viewModel.rightWeight,
                side: .right
            )
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: viewModel.leftWeight)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: viewModel.rightWeight)
        .animation(.spring(response: 0.5, dampingFraction: 0.84), value: viewModel.stage)
    }

    private func pan(at center: CGPoint, count: Int, total: Int, side: LevelFortySevenPanSide) -> some View {
        let revealedCoins = viewModel.stageSolved && viewModel.bagSide == side ? viewModel.bagValue : 0

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 75, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 56))
                path.move(to: CGPoint(x: 75, y: 0))
                path.addLine(to: CGPoint(x: 130, y: 56))
            }
            .stroke(.white.opacity(0.22), lineWidth: 1.2)

            Capsule()
                .fill(.white.opacity(0.1))
                .frame(width: 132, height: 8)
                .overlay {
                    Capsule()
                        .stroke(total > oppositeWeight(for: side) ? accent.opacity(0.74) : .white.opacity(0.24), lineWidth: 1.2)
                }
                .position(x: 75, y: 72)

            coinStack(count: count, revealedCount: revealedCoins)
                .position(x: 75, y: 42)

            Text("\(total)")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(total > oppositeWeight(for: side) ? accent : .white.opacity(0.42))
                .position(x: 75, y: 104)
        }
        .frame(width: 150, height: 116)
        .position(center)
    }

    private func coinStack(count: Int, revealedCount: Int) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                coin
                    .offset(coinOffset(index: index, totalCount: count + revealedCount))
            }

            ForEach(0..<revealedCount, id: \.self) { index in
                coin
                    .offset(coinOffset(index: count + index, totalCount: count + revealedCount))
                    .transition(.scale(scale: 0.55).combined(with: .opacity))
            }
        }
        .frame(width: 142, height: 76)
        .animation(.spring(response: 0.42, dampingFraction: 0.72), value: revealedCount)
    }

    private var coin: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(red: 1, green: 0.82, blue: 0.24), Color(red: 0.9, green: 0.48, blue: 0.08)],
                    center: .topLeading,
                    startRadius: 1,
                    endRadius: 22
                )
            )
            .frame(width: coinSize, height: coinSize)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.42), lineWidth: 0.9)
                    .padding(4)
            }
    }

    private func coinOffset(index: Int, totalCount: Int) -> CGSize {
        let columns = totalCount > 14 ? 7 : totalCount > 5 ? 7 : totalCount
        let column = index % columns
        let row = index / columns
        let centered = CGFloat(column) - CGFloat(columns - 1) / 2
        return CGSize(width: centered * 21, height: CGFloat(row) * -22)
    }

    private func oppositeWeight(for side: LevelFortySevenPanSide) -> Int {
        side == .left ? viewModel.rightWeight : viewModel.leftWeight
    }

    private func bagCounter(at center: CGPoint) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                counterButton(systemName: "minus", action: viewModel.decrementBag)

                Text("\(viewModel.bagValue)")
                    .font(.trajan(34))
                    .foregroundStyle(viewModel.canAdjustBag ? accent : .white.opacity(0.34))
                    .frame(width: 62, height: 48)

                counterButton(systemName: "plus", action: viewModel.incrementBag)
            }
        }
        .opacity(viewModel.completed ? 0.28 : 1)
        .position(center)
    }

    private func counterButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(viewModel.canAdjustBag ? .black : .white.opacity(0.22))
                .frame(width: 40, height: 40)
                .background(viewModel.canAdjustBag ? accent : .white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canAdjustBag)
    }

    private func bagSymbol(layout: LevelFortySevenLayout) -> some View {
        let position = viewModel.bagDragPosition ?? bagSettledPosition(layout: layout)
        let isPlaced = viewModel.bagSide != nil && viewModel.bagDragPosition == nil
        let symbolSize: CGFloat = isPlaced ? 36 : bagSize
        let frameSize: CGFloat = isPlaced ? 48 : 74

        return ZStack {
            Image(systemName: "bag.fill")
                .font(.system(size: symbolSize, weight: .regular))
                .foregroundStyle(.white.opacity(0.82))
                .shadow(color: accent.opacity(viewModel.bagSide == nil ? 0.52 : 0.2), radius: viewModel.bagSide == nil ? 12 : 6)

            Text("?")
                .font(.garamond(isPlaced ? 15 : 24))
                .foregroundStyle(accent)
                .offset(y: isPlaced ? 4 : 6)
        }
        .frame(width: frameSize, height: frameSize)
        .opacity(viewModel.stageSolved ? 0 : 1)
        .contentShape(Rectangle())
        .position(position)
        .zIndex(viewModel.bagDragPosition == nil ? 8 : 22)
        .gesture(
            DragGesture(coordinateSpace: .named("levelFortySevenStage"))
                .onChanged { value in
                    viewModel.moveBag(to: value.location)
                }
                .onEnded { _ in
                    viewModel.finishMovingBag(
                        leftPan: layout.leftPanRect,
                        rightPan: layout.rightPanRect,
                        home: layout.bagHomeCenter
                    )
                }
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: viewModel.bagSide)
    }

    private func bagSettledPosition(layout: LevelFortySevenLayout) -> CGPoint {
        switch viewModel.bagSide {
        case .left:
            CGPoint(x: layout.leftPanCenter.x, y: layout.leftPanCenter.y + panDrop(for: .left) - 66)
        case .right:
            CGPoint(x: layout.rightPanCenter.x, y: layout.rightPanCenter.y + panDrop(for: .right) - 66)
        case nil:
            layout.bagHomeCenter
        }
    }

    private var tiltAngle: Double {
        Double(max(-5, min(5, viewModel.rightWeight - viewModel.leftWeight))) * 4.0
    }

    private func panDrop(for side: LevelFortySevenPanSide) -> CGFloat {
        let difference = CGFloat(max(-5, min(5, viewModel.rightWeight - viewModel.leftWeight)))
        return side == .left ? -difference * 4.0 : difference * 4.0
    }

    private func layout(in size: CGSize) -> LevelFortySevenLayout {
        let safeWidth = min(size.width - 34, 520)
        let centerX = size.width / 2
        let panGap = min(168, safeWidth * 0.34)
        let beamY = size.height * 0.41
        let panY = beamY + 88

        return LevelFortySevenLayout(
            beamCenter: CGPoint(x: centerX, y: beamY),
            beamWidth: min(safeWidth, 382),
            standCenter: CGPoint(x: centerX, y: beamY + 62),
            leftPanCenter: CGPoint(x: centerX - panGap, y: panY),
            rightPanCenter: CGPoint(x: centerX + panGap, y: panY),
            counterCenter: CGPoint(x: centerX, y: min(size.height - 92, panY + 170)),
            bagHomeCenter: CGPoint(x: centerX, y: min(size.height - 176, panY + 92))
        )
    }
}

struct LevelFortySevenLayout {
    let beamCenter: CGPoint
    let beamWidth: CGFloat
    let standCenter: CGPoint
    let leftPanCenter: CGPoint
    let rightPanCenter: CGPoint
    let counterCenter: CGPoint
    let bagHomeCenter: CGPoint

    var leftPanRect: CGRect {
        CGRect(x: leftPanCenter.x - 75, y: leftPanCenter.y - 58, width: 150, height: 116)
    }

    var rightPanRect: CGRect {
        CGRect(x: rightPanCenter.x - 75, y: rightPanCenter.y - 58, width: 150, height: 116)
    }
}

struct LevelFortySevenTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
