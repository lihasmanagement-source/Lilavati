import SwiftUI

private struct LevelThirtyRescueStage {
    let truckDistance: Double
    let buildingHeight: Double
    let ladderLength: Double
}

@Observable
final class MathItLevelThirtyViewModel {
    private static let stages = [
        LevelThirtyRescueStage(truckDistance: 3, buildingHeight: 4, ladderLength: 5),
        LevelThirtyRescueStage(truckDistance: 6, buildingHeight: 8, ladderLength: 10),
        LevelThirtyRescueStage(truckDistance: 5, buildingHeight: 12, ladderLength: 13)
    ]

    var stageIndex = 0
    var ladderLength = 1.0
    var rescueReady = false
    var personLift: CGFloat = 0
    var personJumpProgress: CGFloat = 0
    var personSlideProgress: CGFloat = 0
    var completed = false
    private var completionID = UUID()

    var stageCount: Int { Self.stages.count }
    var truckDistance: Double { currentStage.truckDistance }
    var buildingHeight: Double { currentStage.buildingHeight }
    var correctLadderLength: Double { currentStage.ladderLength }
    var ladderRange: ClosedRange<Double> {
        1...(correctLadderLength + 3)
    }

    func setLadderLength(_ value: Double) {
        guard !completed else { return }
        ladderLength = value
        checkForRescue()
    }

    func reset() {
        completionID = UUID()
        stageIndex = 0
        ladderLength = 1
        rescueReady = false
        personLift = 0
        personJumpProgress = 0
        personSlideProgress = 0
        completed = false
    }

    private func checkForRescue() {
        let solved = ladderLength == correctLadderLength

        guard solved else {
            completionID = UUID()
            rescueReady = false
            personLift = 0
            personJumpProgress = 0
            personSlideProgress = 0
            return
        }
        guard !rescueReady else { return }

        rescueReady = true
        let id = UUID()
        completionID = id
        HapticPlayer.playCompletionTap()

        withAnimation(.easeOut(duration: 0.18)) {
            personLift = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard self.completionID == id, self.rescueReady else { return }
            withAnimation(.easeIn(duration: 0.24)) {
                self.personLift = 0
                self.personJumpProgress = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            guard self.completionID == id, self.rescueReady else { return }
            HapticPlayer.playLightTap()
            withAnimation(.easeInOut(duration: 1.25)) {
                self.personSlideProgress = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) {
            guard self.completionID == id, self.rescueReady else { return }
            if self.stageIndex < Self.stages.count - 1 {
                self.advanceStage()
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                    self.completed = true
                }
            }
        }
    }

    private var currentStage: LevelThirtyRescueStage {
        Self.stages[stageIndex]
    }

    private func advanceStage() {
        completionID = UUID()
        withAnimation(.easeInOut(duration: 0.38)) {
            stageIndex += 1
            ladderLength = ladderRange.lowerBound
            rescueReady = false
            personLift = 0
            personJumpProgress = 0
            personSlideProgress = 0
        }
        HapticPlayer.playLightTap()
    }
}

struct MathItLevelThirtyView: View {
    var viewModel: MathItLevelThirtyViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 620
            let controlHeight: CGFloat = compact ? 92 : 116
            let sceneHeight = proxy.size.height - controlHeight

            ZStack {
                Color.black.ignoresSafeArea()

                RescueScene(
                    truckDistance: viewModel.truckDistance,
                    buildingHeight: viewModel.buildingHeight,
                    ladderLength: viewModel.ladderLength,
                    rescueReady: viewModel.rescueReady,
                    personLift: viewModel.personLift,
                    personJumpProgress: viewModel.personJumpProgress,
                    personSlideProgress: viewModel.personSlideProgress
                )
                .frame(width: proxy.size.width, height: sceneHeight)
                .position(x: proxy.size.width / 2, y: sceneHeight / 2)
                .id(viewModel.stageIndex)
                .transition(.opacity)

                controls(compact: compact, size: proxy.size)
                    .frame(width: proxy.size.width, height: controlHeight)
                    .position(
                        x: proxy.size.width / 2,
                        y: sceneHeight + controlHeight / 2
                    )

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                StageIndicator(
                    stageIndex: viewModel.stageIndex,
                    stageCount: viewModel.stageCount,
                    accent: accent
                )
                .position(x: proxy.size.width / 2, y: 52)

                CompletionOverlay(
                    title: "Rescue Complete",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .environment(\.mathItAccent, accent)
        }
    }

    @ViewBuilder
    private func controls(compact: Bool, size: CGSize) -> some View {
        let ladder = Binding(
            get: { viewModel.ladderLength },
            set: { newValue in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    viewModel.setLadderLength(newValue)
                }
            }
        )

        MetricControl(
            icon: "arrow.up.right",
            title: "LADDER LENGTH",
            value: ladder,
            range: viewModel.ladderRange,
            accent: .orange
        )
        .padding(.horizontal, compact ? 24 : min(34, size.width * 0.08))
        .padding(.vertical, compact ? 10 : 14)
        .background(Color.black.opacity(0.97))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(height: 1)
        }
        .disabled(viewModel.rescueReady)
    }
}

private struct StageIndicator: View {
    let stageIndex: Int
    let stageCount: Int
    let accent: Color

    var body: some View {
        VStack(spacing: 5) {
            Text("STAGE \(stageIndex + 1) OF \(stageCount)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))

            HStack(spacing: 6) {
                ForEach(0..<stageCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= stageIndex ? accent : Color.white.opacity(0.18))
                        .frame(width: index == stageIndex ? 22 : 8, height: 6)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: stageIndex)
        .accessibilityLabel("Stage \(stageIndex + 1) of \(stageCount)")
    }
}

private struct MetricControl: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let accent: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))

                Spacer(minLength: 8)

                Text("\(Int(value.rounded())) m")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            Slider(value: $value, in: range, step: 1)
                .tint(accent)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.lowercased())
        .accessibilityValue("\(Int(value.rounded())) meters")
    }
}

private struct RescueScene: View {
    let truckDistance: Double
    let buildingHeight: Double
    let ladderLength: Double
    let rescueReady: Bool
    let personLift: CGFloat
    let personJumpProgress: CGFloat
    let personSlideProgress: CGFloat

    private let buildingColor = Color(red: 0.12, green: 0.15, blue: 0.19)
    private let windowColor = Color(red: 0.42, green: 0.72, blue: 0.95)
    private let measurementColor = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let groundY = size.height - 48
            let buildingWidth = min(120, max(84, size.width * 0.22))
            let buildingMinX = size.width - buildingWidth - 52
            let horizontalScale = max(16, (buildingMinX - 72) / CGFloat(truckDistance))
            let verticalScale = max(16, (groundY - 88) / CGFloat(buildingHeight))
            let meterScale = min(50, min(horizontalScale, verticalScale))
            let buildingHeightPoints = meterScale * CGFloat(buildingHeight)
            let building = CGRect(
                x: buildingMinX,
                y: groundY - buildingHeightPoints,
                width: buildingWidth,
                height: buildingHeightPoints
            )
            let ladderBase = CGPoint(
                x: building.minX - CGFloat(truckDistance) * meterScale,
                y: groundY
            )
            let rescuePoint = CGPoint(x: building.minX, y: building.minY)
            let targetVector = CGVector(
                dx: rescuePoint.x - ladderBase.x,
                dy: rescuePoint.y - ladderBase.y
            )
            let targetLength = max(1, sqrt(targetVector.dx * targetVector.dx + targetVector.dy * targetVector.dy))
            let ladderEnd = CGPoint(
                x: ladderBase.x + targetVector.dx / targetLength * CGFloat(ladderLength) * meterScale,
                y: ladderBase.y + targetVector.dy / targetLength * CGFloat(ladderLength) * meterScale
            )

            ZStack {
                groundLine(y: groundY, width: size.width)
                buildingBody(building)
                heightMarker(for: building, meters: buildingHeight)
                distanceMarker(from: ladderBase.x, to: building.minX, y: groundY + 23)

                RescueLadder(
                    start: ladderBase,
                    end: ladderEnd,
                    length: ladderLength,
                    solved: rescueReady
                )

                FireTruck()
                    .frame(width: 82, height: 52)
                    .position(x: ladderBase.x - 28, y: groundY - 25)

                Circle()
                    .fill(measurementColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: measurementColor.opacity(0.7), radius: 8)
                    .position(rescuePoint)

                RescuePerson(
                    rescuePoint: rescuePoint,
                    ladderBase: ladderBase,
                    lift: personLift,
                    jumpProgress: personJumpProgress,
                    slideProgress: personSlideProgress
                )
            }
        }
    }

    private func groundLine(y: CGFloat, width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(.white.opacity(0.28), lineWidth: 2)
    }

    private func buildingBody(_ rect: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(buildingColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.22), lineWidth: 1.4)
                }

            VStack(spacing: rect.height * 0.08) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: rect.width * 0.12) {
                        ForEach(0..<2, id: \.self) { _ in
                            window(
                                width: rect.width * 0.22,
                                height: rect.height * 0.11
                            )
                        }
                    }
                }
            }

            AnimatedBuildingFire()
                .frame(width: rect.width * 1.08, height: rect.height * 0.46)
                .offset(y: rect.height * 0.29)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func window(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(windowColor.opacity(0.68))
        .frame(width: width, height: height)
    }

    private func heightMarker(for rect: CGRect, meters: Double) -> some View {
        let x = rect.maxX + 25

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: x - 8, y: rect.minY))
                path.addLine(to: CGPoint(x: x + 8, y: rect.minY))
                path.move(to: CGPoint(x: x - 8, y: rect.maxY))
                path.addLine(to: CGPoint(x: x + 8, y: rect.maxY))
            }
            .stroke(measurementColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))

            Text("\(Int(meters.rounded())) m")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(measurementColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 4))
                .position(x: x, y: rect.midY)
        }
    }

    private func distanceMarker(from startX: CGFloat, to endX: CGFloat, y: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: endX, y: y))
                path.move(to: CGPoint(x: startX, y: y - 6))
                path.addLine(to: CGPoint(x: startX, y: y + 6))
                path.move(to: CGPoint(x: endX, y: y - 6))
                path.addLine(to: CGPoint(x: endX, y: y + 6))
            }
            .stroke(.white.opacity(0.42), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            Text("\(Int(truckDistance.rounded())) m")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 6)
                .background(.black)
                .position(x: (startX + endX) / 2, y: y)
        }
        .allowsHitTesting(false)
    }
}

private struct RescuePerson: View {
    let rescuePoint: CGPoint
    let ladderBase: CGPoint
    let lift: CGFloat
    let jumpProgress: CGFloat
    let slideProgress: CGFloat

    var body: some View {
        let pathProgress = jumpProgress * 0.08 + slideProgress * 0.84
        let x = rescuePoint.x + (ladderBase.x - rescuePoint.x) * pathProgress
        let y = rescuePoint.y + (ladderBase.y - rescuePoint.y) * pathProgress - lift * 24

        Image(systemName: "person.fill")
            .font(.system(size: 27, weight: .black))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.85), radius: 2, y: 1)
            .shadow(color: Color.mathItGeometry.opacity(0.7), radius: 8)
            .position(x: x, y: y)
            .accessibilityLabel(
                slideProgress > 0
                    ? "Person sliding down the rescue ladder"
                    : "Person waiting at the top-left rescue point"
            )
    }
}

private struct FireTruck: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.82, green: 0.08, blue: 0.06))
                .frame(width: 76, height: 28)
                .offset(y: 5)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.94, green: 0.12, blue: 0.08))
                .frame(width: 31, height: 28)
                .offset(x: 20, y: -9)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.52, green: 0.82, blue: 0.95))
                .frame(width: 18, height: 11)
                .offset(x: 20, y: -11)

            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: 65, height: 4)
                .offset(x: -4, y: 4)

            HStack(spacing: 31) {
                wheel
                wheel
            }
            .offset(y: 20)

            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
                .offset(x: 35, y: 20)

            Image(systemName: "cross.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .offset(x: -19, y: -1)
        }
        .shadow(color: .red.opacity(0.28), radius: 7)
        .accessibilityLabel("Firetruck")
    }

    private var wheel: some View {
        Circle()
            .fill(Color(red: 0.08, green: 0.09, blue: 0.11))
            .frame(width: 18, height: 18)
            .overlay {
                Circle()
                    .fill(.white.opacity(0.48))
                    .frame(width: 7, height: 7)
            }
    }
}

private struct RescueLadder: View {
    let start: CGPoint
    let end: CGPoint
    let length: Double
    let solved: Bool

    var body: some View {
        Canvas { context, _ in
            let dx = end.x - start.x
            let dy = end.y - start.y
            let visualLength = max(1, sqrt(dx * dx + dy * dy))
            let ux = dx / visualLength
            let uy = dy / visualLength
            let px = -uy
            let py = ux
            let railOffset: CGFloat = 4.5
            let color = solved ? Color.green : Color.white.opacity(0.94)

            for side in [-1.0, 1.0] {
                var rail = Path()
                let offset = CGFloat(side) * railOffset
                rail.move(to: CGPoint(x: start.x + px * offset, y: start.y + py * offset))
                rail.addLine(to: CGPoint(x: end.x + px * offset, y: end.y + py * offset))
                context.stroke(rail, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }

            var rungDistance: CGFloat = 10
            while rungDistance < visualLength - 7 {
                let center = CGPoint(
                    x: start.x + ux * rungDistance,
                    y: start.y + uy * rungDistance
                )
                var rung = Path()
                rung.move(to: CGPoint(x: center.x - px * railOffset, y: center.y - py * railOffset))
                rung.addLine(to: CGPoint(x: center.x + px * railOffset, y: center.y + py * railOffset))
                context.stroke(rung, with: .color(color.opacity(0.9)), lineWidth: 1.5)
                rungDistance += 13
            }
        }
        .overlay {
            Text("\(Int(length.rounded())) m")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(solved ? .green : .orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 4))
                .position(
                    x: (start.x + end.x) / 2 - 10,
                    y: (start.y + end.y) / 2 - 13
                )
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.2), value: solved)
        .accessibilityHidden(true)
    }
}

private struct AnimatedBuildingFire: View {
    private let flameCount = 9

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(0..<flameCount, id: \.self) { index in
                        flame(index: index, time: time, size: proxy.size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func flame(index: Int, time: TimeInterval, size: CGSize) -> some View {
        let phase = time * 3.2 + Double(index) * 0.83
        let sway = CGFloat(sin(phase)) * size.width * 0.018
        let pulse = CGFloat(0.88 + sin(phase * 1.37) * 0.12)
        let spacing = size.width / CGFloat(flameCount)
        let x = spacing * (CGFloat(index) + 0.5) + sway
        let height = size.height * (0.48 + CGFloat(index % 3) * 0.13)
        let width = spacing * 1.45

        return ZStack(alignment: .bottom) {
            FlameShape()
                .fill(Color(red: 0.94, green: 0.16, blue: 0.04))
                .frame(width: width, height: height)

            FlameShape()
                .fill(Color(red: 1.0, green: 0.56, blue: 0.04))
                .frame(width: width * 0.64, height: height * 0.72)

            FlameShape()
                .fill(Color(red: 1.0, green: 0.88, blue: 0.16))
                .frame(width: width * 0.3, height: height * 0.42)
        }
        .scaleEffect(x: 1, y: pulse, anchor: .bottom)
        .position(x: x, y: size.height - height / 2)
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY * 0.72),
                control1: CGPoint(x: rect.midX * 0.84, y: rect.height * 0.22),
                control2: CGPoint(x: rect.minX, y: rect.height * 0.42)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY * 0.72),
                control1: CGPoint(x: rect.minX, y: rect.maxY),
                control2: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.minY),
                control1: CGPoint(x: rect.maxX, y: rect.height * 0.42),
                control2: CGPoint(x: rect.midX * 1.16, y: rect.height * 0.22)
            )
            path.closeSubpath()
        }
    }
}
