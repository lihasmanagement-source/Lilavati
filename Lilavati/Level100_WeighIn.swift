import SwiftUI

@Observable
final class MathItLevelElevenViewModel {
    var completed = false
    var boxBroken = false
    var boxHitCount = 0
    var ballEscaped = false
    var ballEscapePosition = CGPoint.zero
    var acceptedMarble: Int?
    var placements: [Int: LevelElevenScaleSide] = [:]
    var dragOffsets: [Int: CGSize] = [:]
    var weighings: [LevelElevenWeighing] = []

    private let oddMarble: Int

    init() {
        oddMarble = Int.random(in: 1...6)
    }

    var progress: Double {
        if completed { return 1 }
        let weighProgress = Double(weighings.count) / 2 * 0.62
        let shotProgress = acceptedMarble != nil ? 0.2 : 0
        let brokenProgress = boxBroken ? 0.14 : 0
        return min(0.96, weighProgress + shotProgress + brokenProgress)
    }

    var weighingsRemaining: Int {
        max(0, 2 - weighings.count)
    }

    var canWeigh: Bool {
        weighings.count < 2 && leftMarbles.count > 0 && rightMarbles.count > 0
    }

    var leftMarbles: [Int] {
        marbles(on: .left)
    }

    var rightMarbles: [Int] {
        marbles(on: .right)
    }

    func placement(for marble: Int) -> LevelElevenScaleSide {
        placements[marble, default: .shelf]
    }

    func offset(for marble: Int) -> CGSize {
        dragOffsets[marble, default: .zero]
    }

    func move(_ marble: Int, by translation: CGSize) {
        guard !completed, acceptedMarble != marble else { return }
        dragOffsets[marble] = translation
    }

    func finishMoving(
        _ marble: Int,
        at point: CGPoint,
        leftPan: CGRect,
        rightPan: CGRect,
        targetCircle: CGRect,
        ballStart: CGPoint,
        ballEnd: CGPoint
    ) {
        guard !completed, acceptedMarble != marble else { return }

        if weighingsRemaining == 0 {
            if targetCircle.insetBy(dx: -16, dy: -16).contains(point), marble == oddMarble {
                acceptMarble(marble, at: targetCircle.center, from: point, ballStart: ballStart, ballEnd: ballEnd)
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                    dragOffsets[marble] = .zero
                }
            }
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            if leftPan.insetBy(dx: -18, dy: -22).contains(point) {
                placements[marble] = .left
            } else if rightPan.insetBy(dx: -18, dy: -22).contains(point) {
                placements[marble] = .right
            } else {
                placements[marble] = .shelf
            }
            dragOffsets[marble] = .zero
        }
    }

    func clearScale() {
        guard !completed, weighingsRemaining > 0 else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            placements = [:]
            dragOffsets = [:]
        }
    }

    func weigh() {
        guard canWeigh else { return }

        let left = leftMarbles
        let right = rightMarbles
        let result = compare(left: left, right: right)

        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
            weighings.append(LevelElevenWeighing(left: left, right: right, result: result))
            placements = [:]
            dragOffsets = [:]
        }
    }

    private func marbles(on side: LevelElevenScaleSide) -> [Int] {
        (1...6).filter { placements[$0, default: .shelf] == side }
    }

    private func acceptMarble(_ marble: Int, at targetCenter: CGPoint, from point: CGPoint, ballStart: CGPoint, ballEnd: CGPoint) {
        guard !boxBroken else { return }

        HapticPlayer.playCompletionTap()
        acceptedMarble = marble
        placements = [:]

        let currentOffset = dragOffsets[marble, default: .zero]
        let basePoint = CGPoint(x: point.x - currentOffset.width, y: point.y - currentOffset.height)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            dragOffsets[marble] = CGSize(width: targetCenter.x - basePoint.x, height: targetCenter.y - basePoint.y)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            self.smashBox(ballStart: ballStart, ballEnd: ballEnd)
        }
    }

    private func smashBox(ballStart: CGPoint, ballEnd: CGPoint) {
        guard !boxBroken else { return }

        HapticPlayer.playCompletionTap()
        boxHitCount = 3
        boxBroken = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            self.ballEscaped = true
            self.ballEscapePosition = ballStart
            let firstLand = CGPoint(x: ballStart.x - 92, y: ballEnd.y + 12)
            let firstHop = CGPoint(x: (ballStart.x + firstLand.x) / 2, y: firstLand.y - 34)
            let secondHop = CGPoint(x: (firstLand.x + ballEnd.x) / 2, y: ballEnd.y - 30)

            withAnimation(.easeInOut(duration: 0.55)) {
                self.ballEscapePosition = firstHop
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeInOut(duration: 0.48)) {
                    self.ballEscapePosition = firstLand
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.03) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    self.ballEscapePosition = secondHop
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.58) {
                withAnimation(.easeInOut(duration: 0.62)) {
                    self.ballEscapePosition = ballEnd
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.78) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    private func compare(left: [Int], right: [Int]) -> LevelElevenScaleResult {
        let leftWeight = left.reduce(0) { $0 + weight(for: $1) }
        let rightWeight = right.reduce(0) { $0 + weight(for: $1) }

        if leftWeight > rightWeight { return .leftHeavy }
        if rightWeight > leftWeight { return .rightHeavy }
        return .balanced
    }

    private func weight(for marble: Int) -> Int {
        guard marble == oddMarble else { return 10 }
        return 11
    }
}

enum LevelElevenScaleSide {
    case shelf
    case left
    case right
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

enum LevelElevenScaleResult: String {
    case leftHeavy
    case rightHeavy
    case balanced

    var tilt: Angle {
        switch self {
        case .leftHeavy:
            .degrees(-7)
        case .rightHeavy:
            .degrees(7)
        case .balanced:
            .degrees(0)
        }
    }
}

struct LevelElevenWeighing: Identifiable {
    let id = UUID()
    let left: [Int]
    let right: [Int]
    let result: LevelElevenScaleResult
}

struct MathItLevelElevenView: View {
    var viewModel: MathItLevelElevenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let marbleSize: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height * 0.39)
            let beamWidth = min(286, size.width * 0.7)
            let beamY = center.y + 34
            let snapSize = CGSize(width: min(116, size.width * 0.28), height: 56)
            let snapOffset = beamWidth * 0.27
            let leftPan = CGRect(
                x: center.x - snapOffset - snapSize.width / 2,
                y: beamY - snapSize.height - 2,
                width: snapSize.width,
                height: snapSize.height
            )
            let rightPan = CGRect(
                x: center.x + snapOffset - snapSize.width / 2,
                y: beamY - snapSize.height - 2,
                width: snapSize.width,
                height: snapSize.height
            )
            let shelfY = size.height * 0.72
            let shelfSpacing = min(56, max(44, (size.width - 72) / 5))
            let shelfStartX = size.width / 2 - shelfSpacing * 2.5
            let shelfPoints = Dictionary(uniqueKeysWithValues: (1...6).map { marble in
                (marble, CGPoint(x: shelfStartX + CGFloat(marble - 1) * shelfSpacing, y: shelfY))
            })
            let topY = size.height * 0.18
            let boxFrame = CGRect(x: size.width * 0.78 - 43, y: topY - 43, width: 86, height: 86)
            let ballStart = CGPoint(x: boxFrame.midX, y: boxFrame.midY)
            let ballEnd = CGPoint(x: -34, y: max(34, topY - 58))
            let targetCircle = CGRect(
                x: boxFrame.minX - marbleSize - 20,
                y: boxFrame.midY - marbleSize / 2,
                width: marbleSize,
                height: marbleSize
            )
            let panPoints = scalePanPoints(leftPan: leftPan, rightPan: rightPan)

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
                .position(x: size.width / 2, y: 86)

                ProgressView(value: viewModel.progress)
                    .tint(.white)
                    .opacity(0.72)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 224)

                Text("find the heaviest marble")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.mathGold.opacity(0.9))
                    .position(x: size.width / 2, y: 190)

                scaleView(center: center, beamWidth: beamWidth)

                historyMarks
                    .position(x: size.width / 2, y: size.height * 0.58)

                escapeBox(frame: boxFrame, ballStart: ballStart, ballEnd: ballEnd)

                marbleTargetCircle(frame: targetCircle)
                    .opacity(viewModel.weighingsRemaining == 0 && !viewModel.boxBroken ? 1 : 0)

                ForEach(1...6, id: \.self) { marble in
                    let point = position(for: marble, shelfPoints: shelfPoints, panPoints: panPoints)
                    marbleView(marble)
                        .position(x: point.x + viewModel.offset(for: marble).width, y: point.y + viewModel.offset(for: marble).height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    viewModel.move(marble, by: value.translation)
                                }
                                .onEnded { value in
                                    let endPoint = CGPoint(x: point.x + value.translation.width, y: point.y + value.translation.height)
                                    viewModel.finishMoving(
                                        marble,
                                        at: endPoint,
                                        leftPan: leftPan,
                                        rightPan: rightPan,
                                        targetCircle: targetCircle,
                                        ballStart: ballStart,
                                        ballEnd: ballEnd
                                    )
                                }
                        )
                        .accessibilityLabel("Marble \(marble)")
                }

                controls(size: size)
                    .opacity(viewModel.weighingsRemaining == 0 ? 0 : 1)
                    .position(x: size.width / 2, y: size.height * 0.88)

                CompletionOverlay(
                    title: "Level 11 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
            }
        }
    }

    private func scalePanPoints(leftPan: CGRect, rightPan: CGRect) -> [Int: CGPoint] {
        var points: [Int: CGPoint] = [:]
        let left = viewModel.leftMarbles
        let right = viewModel.rightMarbles

        for (index, marble) in left.enumerated() {
            points[marble] = panPoint(in: leftPan, index: index, count: left.count)
        }
        for (index, marble) in right.enumerated() {
            points[marble] = panPoint(in: rightPan, index: index, count: right.count)
        }
        return points
    }

    private func panPoint(in pan: CGRect, index: Int, count: Int) -> CGPoint {
        let columns = min(3, max(1, count))
        let row = index / columns
        let column = index % columns
        let xSpacing = min(38, pan.width / CGFloat(columns + 1))
        let ySpacing: CGFloat = 28
        let x = pan.midX + (CGFloat(column) - CGFloat(columns - 1) / 2) * xSpacing
        let y = pan.maxY - marbleSize * 0.52 + CGFloat(row) * ySpacing - CGFloat(max(0, count - 1) / columns) * ySpacing / 2
        return CGPoint(x: x, y: y)
    }

    private func position(for marble: Int, shelfPoints: [Int: CGPoint], panPoints: [Int: CGPoint]) -> CGPoint {
        switch viewModel.placement(for: marble) {
        case .left, .right:
            panPoints[marble] ?? shelfPoints[marble, default: .zero]
        case .shelf:
            shelfPoints[marble, default: .zero]
        }
    }

    private func scaleView(center: CGPoint, beamWidth: CGFloat) -> some View {
        let tilt = viewModel.weighings.last?.result.tilt ?? .degrees(0)

        return ZStack {
            Capsule()
                .fill(.white.opacity(0.62))
                .frame(width: 4, height: 150)
                .position(x: center.x, y: center.y + 92)

            Capsule()
                .fill(.white.opacity(0.82))
                .frame(width: beamWidth, height: 5)
                .rotationEffect(tilt)
                .position(x: center.x, y: center.y + 34)
        }
    }

    private func marbleTargetCircle(frame: CGRect) -> some View {
        Circle()
            .stroke(.gray.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            .background(Circle().fill(.gray.opacity(0.12)))
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }

    private func escapeBox(frame: CGRect, ballStart: CGPoint, ballEnd: CGPoint) -> some View {
        let isSolid = viewModel.weighingsRemaining == 0

        return ZStack {
            if viewModel.boxBroken {
                boxShard(offset: CGSize(width: -34, height: -24), rotation: .degrees(-24))
                    .position(x: frame.midX - 18, y: frame.midY - 12)
                boxShard(offset: CGSize(width: 36, height: -20), rotation: .degrees(29))
                    .position(x: frame.midX + 20, y: frame.midY - 10)
                boxShard(offset: CGSize(width: -24, height: 34), rotation: .degrees(18))
                    .position(x: frame.midX - 15, y: frame.midY + 18)
                boxShard(offset: CGSize(width: 28, height: 32), rotation: .degrees(-18))
                    .position(x: frame.midX + 18, y: frame.midY + 20)
            } else {
                crackingBox(frame: frame, isSolid: isSolid)
            }

            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
                .shadow(color: .white.opacity(0.72), radius: 14)
                .position(viewModel.ballEscaped ? viewModel.ballEscapePosition : ballStart)
        }
    }

    private func crackingBox(frame: CGRect, isSolid: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    .white.opacity(isSolid ? 0.78 : 0.5),
                    style: StrokeStyle(lineWidth: 2, dash: isSolid ? [] : [8, 7])
                )
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            if viewModel.boxHitCount >= 1 {
                crackPath(points: [
                    CGPoint(x: frame.midX - 18, y: frame.midY - 22),
                    CGPoint(x: frame.midX - 4, y: frame.midY - 8),
                    CGPoint(x: frame.midX - 12, y: frame.midY + 8)
                ])
            }

            if viewModel.boxHitCount >= 2 {
                crackPath(points: [
                    CGPoint(x: frame.midX + 18, y: frame.midY - 18),
                    CGPoint(x: frame.midX + 4, y: frame.midY - 2),
                    CGPoint(x: frame.midX + 20, y: frame.midY + 20)
                ])
            }
        }
    }

    private func crackPath(points: [CGPoint]) -> some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .shadow(color: .white.opacity(0.24), radius: 8)
    }

    private func boxShard(offset: CGSize, rotation: Angle) -> some View {
        Rectangle()
            .stroke(.white.opacity(0.64), lineWidth: 2)
            .frame(width: 38, height: 2)
            .rotationEffect(rotation)
            .offset(offset)
            .transition(.opacity.combined(with: .scale(scale: 0.84)))
    }

    private var historyMarks: some View {
        HStack(spacing: 18) {
            ForEach(viewModel.weighings) { weighing in
                resultMark(weighing.result)
            }
        }
        .frame(height: 24)
    }

    private func resultMark(_ result: LevelElevenScaleResult) -> some View {
        Capsule()
            .fill(.white.opacity(0.74))
            .frame(width: 26, height: 3)
            .rotationEffect(result.tilt)
        .frame(width: 24, height: 24)
    }

    private func controls(size: CGSize) -> some View {
        HStack(spacing: 16) {
            Button(action: viewModel.weigh) {
                ZStack {
                    Circle()
                        .fill(viewModel.canWeigh ? .white : .clear)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(viewModel.canWeigh ? 0 : 0.28), lineWidth: 1.2)
                        }

                    Image(systemName: "arrow.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(viewModel.canWeigh ? .black : .white.opacity(0.42))
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canWeigh)

            Button(action: viewModel.clearScale) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.42), lineWidth: 1.2)

                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
        }
    }

    private func marbleView(_ number: Int) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(viewModel.acceptedMarble == number ? 0.94 : 0.78))
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.98), lineWidth: 1.3)
                }
                .shadow(color: .white.opacity(viewModel.acceptedMarble == number ? 0.42 : 0.2), radius: 11)

            Text("\(number)")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.78))
        }
        .frame(width: marbleSize, height: marbleSize)
        .contentShape(Circle())
    }
}
