import SwiftUI

@Observable
final class MathItLevelTwoViewModel {
    var currentValue = -3
    var completed = false
    var isAirborne = false
    var ballX: CGFloat = 0
    var ballY: CGFloat = 0
    var velocityY: CGFloat = 0
    var landedPlatformOffsetX: CGFloat = 0
    var lastUpdateDate: Date?

    let minimumValue = -3
    let maximumValue = 3
    let platformWidth: CGFloat = 112
    private let gravity: CGFloat = 1750
    private let jumpVelocity: CGFloat = -660

    var progress: Double {
        completed ? 1 : Double(currentValue - minimumValue) / Double(maximumValue - minimumValue)
    }

    func jump(from launchPoint: CGPoint) {
        guard !completed, !isAirborne, currentValue < maximumValue else { return }

        HapticPlayer.playLightTap()
        ballX = launchPoint.x
        ballY = launchPoint.y
        velocityY = jumpVelocity
        isAirborne = true
        lastUpdateDate = nil
    }

    func updatePhysics(
        at date: Date,
        bottomY: CGFloat,
        restingOffset: CGFloat,
        platformY: (Int) -> CGFloat,
        platformX: (Int, Date) -> CGFloat
    ) {
        guard isAirborne, !completed else {
            lastUpdateDate = date
            return
        }

        let previousY = ballY
        guard let previousDate = lastUpdateDate else {
            lastUpdateDate = date
            return
        }

        let deltaTime = min(max(date.timeIntervalSince(previousDate), 0), 1.0 / 60.0)
        lastUpdateDate = date

        velocityY += gravity * deltaTime
        ballY += velocityY * deltaTime

        if velocityY >= 0 {
            for value in (minimumValue...maximumValue).reversed() {
                let landingY = platformY(value) - restingOffset
                let platformCenterX = platformX(value, date)
                let crossedPlatform = previousY <= landingY && ballY >= landingY
                let isOverPlatform = abs(ballX - platformCenterX) <= platformWidth * 0.5

                if crossedPlatform && isOverPlatform {
                    land(on: value, y: landingY, platformCenterX: platformCenterX)
                    return
                }
            }
        }

        if ballY > bottomY + 90 {
            resetToBottom()
        }
    }

    private func land(on value: Int, y: CGFloat, platformCenterX: CGFloat) {
        currentValue = value
        ballY = y
        landedPlatformOffsetX = ballX - platformCenterX
        velocityY = 0
        isAirborne = false
        lastUpdateDate = nil
        HapticPlayer.playLightTap()

        if currentValue == maximumValue {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.18)) {
                completed = true
            }
        }
    }

    private func resetToBottom() {
        currentValue = minimumValue
        velocityY = 0
        landedPlatformOffsetX = 0
        isAirborne = false
        lastUpdateDate = nil
        HapticPlayer.playLightTap()
    }
}

struct MathItLevelTwoView: View {
    var viewModel: MathItLevelTwoViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let size = proxy.size
                let scaleX = size.width * 0.16
                let bottomY = size.height * 0.9
                let topY = size.height * 0.22
                let zeroY = yPosition(for: 0, topY: topY, bottomY: bottomY)
                let restingOffset: CGFloat = 18
                let currentPlatformX = platformX(for: viewModel.currentValue, width: size.width, date: timeline.date)
                let groundedY = yPosition(for: viewModel.currentValue, topY: topY, bottomY: bottomY) - restingOffset
                let groundedPoint = CGPoint(x: currentPlatformX + viewModel.landedPlatformOffsetX, y: groundedY)

                let ballPoint = viewModel.isAirborne ? CGPoint(x: viewModel.ballX, y: viewModel.ballY) : groundedPoint
                let ballPositiveBlend = positiveBlend(for: ballPoint.y, zeroY: zeroY)

                ZStack {
                    LevelTwoBackground(zeroY: zeroY)

                    HomeButton(action: onLevelSelect)
                        .position(x: 34, y: 54)

                    VStack(spacing: 10) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        Text("+1")
                            .font(.trajan(42))
                            .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                    }
                    .position(x: size.width / 2, y: 96)

                    ProgressView(value: viewModel.progress)
                        .tint(.white)
                        .opacity(0.72)
                        .padding(.horizontal, 34)
                        .position(x: size.width / 2, y: 160)

                    numberScale(scaleX: scaleX, topY: topY, bottomY: bottomY)

                    ForEach(viewModel.minimumValue...viewModel.maximumValue, id: \.self) { value in
                        let y = yPosition(for: value, topY: topY, bottomY: bottomY)

                        PlatformView(isCurrent: value == viewModel.currentValue, isPositiveSide: value > 0)
                            .frame(width: viewModel.platformWidth, height: 12)
                            .position(x: platformX(for: value, width: size.width, date: timeline.date), y: y)
                    }

                    Circle()
                        .fill(Color(white: ballPositiveBlend))
                        .frame(width: 24, height: 24)
                        .shadow(color: Color(white: ballPositiveBlend).opacity(0.35 + 0.43 * ballPositiveBlend), radius: 14)
                        .position(ballPoint)

                    if let concept = ConceptLibrary.concept(for: 2) {
                        ConceptCompletionOverlay(
                            levelTitle: "Level 2",
                            concept: concept,
                            isVisible: viewModel.completed,
                            onContinue: onContinue,
                            onReplay: onReplay,
                            onLevelSelect: onLevelSelect
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.jump(from: groundedPoint)
                }
            }
            .task(id: CGSize(width: proxy.size.width, height: proxy.size.height)) {
                let size = proxy.size
                let bottomY = size.height * 0.9
                let topY = size.height * 0.22
                let restingOffset: CGFloat = 18

                while !Task.isCancelled {
                    let now = Date()
                    viewModel.updatePhysics(
                        at: now,
                        bottomY: bottomY,
                        restingOffset: restingOffset,
                        platformY: { value in yPosition(for: value, topY: topY, bottomY: bottomY) },
                        platformX: { value, date in platformX(for: value, width: size.width, date: date) }
                    )

                    try? await Task.sleep(nanoseconds: 16_666_667)
                }
            }
        }
    }

    private func numberScale(scaleX: CGFloat, topY: CGFloat, bottomY: CGFloat) -> some View {
        ZStack {
            scaleLineSegment(scaleX: scaleX, from: topY, to: yPosition(for: 0, topY: topY, bottomY: bottomY), color: .white)
            scaleLineSegment(scaleX: scaleX, from: yPosition(for: 0, topY: topY, bottomY: bottomY), to: bottomY, color: .black)

            ForEach(viewModel.minimumValue...viewModel.maximumValue, id: \.self) { value in
                let y = yPosition(for: value, topY: topY, bottomY: bottomY)
                let color: Color = value <= 0 ? .black : .white
                let isCurrent = value == viewModel.currentValue

                Rectangle()
                    .fill(color.opacity(isCurrent ? 1 : 0.68))
                    .frame(width: 16, height: 1.4)
                    .position(x: scaleX, y: y)

                Text("\(value)")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.opacity(isCurrent ? 1 : 0.52))
                    .position(x: scaleX - 30, y: y)
            }
        }
    }

    private func scaleLineSegment(scaleX: CGFloat, from startY: CGFloat, to endY: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color.opacity(0.42))
            .frame(width: 1.4, height: abs(endY - startY))
            .position(x: scaleX, y: (startY + endY) / 2)
    }

    private func yPosition(for value: Int, topY: CGFloat, bottomY: CGFloat) -> CGFloat {
        let progress = CGFloat(value - viewModel.minimumValue) / CGFloat(viewModel.maximumValue - viewModel.minimumValue)
        return bottomY - progress * (bottomY - topY)
    }

    private func positiveBlend(for ballY: CGFloat, zeroY: CGFloat) -> Double {
        let fadeDistance: CGFloat = 34
        let progress = (zeroY - ballY + fadeDistance) / (fadeDistance * 2)
        return Double(min(max(progress, 0), 1))
    }

    private func platformX(for value: Int, width: CGFloat, date: Date) -> CGFloat {
        let normalized = value - viewModel.minimumValue
        let platformWidth = viewModel.platformWidth
        let leftEdge = platformWidth / 2 + 12
        let rightEdge = width - platformWidth / 2 - 12
        let phase = date.timeIntervalSinceReferenceDate * (0.72 + Double(normalized) * 0.05) + Double(normalized) * 1.1
        let progress = (sin(phase) + 1) / 2
        return leftEdge + CGFloat(progress) * (rightEdge - leftEdge)
    }
}

private struct LevelTwoBackground: View {
    let zeroY: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.black

                Rectangle()
                    .fill(.white)
                    .frame(height: max(0, proxy.size.height - zeroY))
                    .position(x: proxy.size.width / 2, y: zeroY + max(0, proxy.size.height - zeroY) / 2)

                Rectangle()
                    .fill(.white.opacity(0.38))
                    .frame(height: 1)
                    .position(x: proxy.size.width / 2, y: zeroY)
            }
        }
        .ignoresSafeArea()
    }
}

private struct PlatformView: View {
    let isCurrent: Bool
    let isPositiveSide: Bool

    var body: some View {
        let color: Color = isPositiveSide ? .white : .black

        Capsule()
            .fill(color.opacity(isCurrent ? 0.94 : 0.52))
            .shadow(color: color.opacity(isCurrent ? 0.45 : 0.14), radius: isCurrent ? 12 : 5)
    }
}
