import SwiftUI
import Foundation

struct LevelFiftyOneStage {
    let slope: Double
    let intercept: Double
    let verticalX: Double?
    let options: [String]
    let correctIndex: Int
    let lasersGreaterSide: Bool
    let solidLine: Bool
    let targetStarts: [SIMD2<Double>]
    let fortress: SIMD2<Double>

    init(
        slope: Double,
        intercept: Double,
        options: [String],
        correctIndex: Int,
        lasersGreaterSide: Bool,
        solidLine: Bool,
        targetStarts: [SIMD2<Double>],
        fortress: SIMD2<Double>
    ) {
        self.slope = slope
        self.intercept = intercept
        self.verticalX = nil
        self.options = options
        self.correctIndex = correctIndex
        self.lasersGreaterSide = lasersGreaterSide
        self.solidLine = solidLine
        self.targetStarts = targetStarts
        self.fortress = fortress
    }

    init(
        verticalX: Double,
        options: [String],
        correctIndex: Int,
        lasersGreaterSide: Bool,
        solidLine: Bool,
        targetStarts: [SIMD2<Double>],
        fortress: SIMD2<Double>
    ) {
        self.slope = 0
        self.intercept = 0
        self.verticalX = verticalX
        self.options = options
        self.correctIndex = correctIndex
        self.lasersGreaterSide = lasersGreaterSide
        self.solidLine = solidLine
        self.targetStarts = targetStarts
        self.fortress = fortress
    }
}

@Observable
final class MathItLevelFiftyOneViewModel {
    let roundSeconds = 10.0
    let stages = [
        LevelFiftyOneStage(
            slope: 1,
            intercept: -1,
            options: ["y > x - 1", "y < x - 1", "y > x + 1"],
            correctIndex: 0,
            lasersGreaterSide: true,
            solidLine: false,
            targetStarts: [SIMD2(-5, 3.8), SIMD2(-3, 3.2), SIMD2(0, 4), SIMD2(3.2, 3.7)],
            fortress: SIMD2(4.8, -3.3)
        ),
        LevelFiftyOneStage(
            slope: -0.5,
            intercept: 2,
            options: ["y > -1/2x + 2", "y < -1/2x + 2", "y < -1/2x - 1"],
            correctIndex: 1,
            lasersGreaterSide: false,
            solidLine: false,
            targetStarts: [SIMD2(-4.6, -3.2), SIMD2(-1.8, -3.6), SIMD2(1.6, -3.4), SIMD2(4.6, -3.7)],
            fortress: SIMD2(4.7, 2.3)
        ),
        LevelFiftyOneStage(
            slope: -1,
            intercept: -1,
            options: ["y > -x - 1", "y < -x - 1", "y < -x + 1"],
            correctIndex: 1,
            lasersGreaterSide: false,
            solidLine: false,
            targetStarts: [SIMD2(-5.2, 2.4), SIMD2(-2.4, -0.8), SIMD2(1.4, -3.4), SIMD2(2.4, -3.8)],
            fortress: SIMD2(4.7, 2.8)
        ),
        LevelFiftyOneStage(
            slope: 0.5,
            intercept: 1,
            options: ["y < 1/2x + 1", "y > 1/2x + 1", "y < 1/2x - 1"],
            correctIndex: 1,
            lasersGreaterSide: true,
            solidLine: false,
            targetStarts: [SIMD2(-5.3, 3.4), SIMD2(-2.2, 3.6), SIMD2(1.4, 3.8), SIMD2(5.1, 3.7)],
            fortress: SIMD2(-4.7, -3.2)
        ),
        LevelFiftyOneStage(
            slope: 0,
            intercept: -1,
            options: ["y > -1", "y < -1", "y > 1"],
            correctIndex: 0,
            lasersGreaterSide: true,
            solidLine: false,
            targetStarts: [SIMD2(-5.0, 3.5), SIMD2(-2.0, 3.2), SIMD2(1.8, 3.6), SIMD2(5.0, 3.3)],
            fortress: SIMD2(0, -3.2)
        ),
        LevelFiftyOneStage(
            verticalX: 2,
            options: ["x > 2", "x < 2", "x > -2"],
            correctIndex: 0,
            lasersGreaterSide: true,
            solidLine: false,
            targetStarts: [SIMD2(5.4, -3.2), SIMD2(5.1, -1.1), SIMD2(5.3, 1.2), SIMD2(5.0, 3.2)],
            fortress: SIMD2(-4.7, 0)
        )
    ]

    var stageIndex = 0
    var selectedIndex: Int?
    var targetProgress = 0.0
    var secondsLeft = 10.0
    var laserActive = false
    var eliminated = false
    var wrongPulse = false
    var homeFlash = false
    var completed = false
    var hearts = 3
    var resettingAfterHeartsLost = false

    private var timer: Timer?
    private var roundStart = Date()

    var currentStage: LevelFiftyOneStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        return (Double(stageIndex) + (laserActive ? 1 : targetProgress)) / Double(stages.count)
    }

    var timeText: String {
        "\(max(0, Int(ceil(secondsLeft))))"
    }

    func start() {
        cancelTimer()
        stageIndex = 0
        hearts = 3
        completed = false
        beginRound()
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }

    func choose(_ index: Int) {
        guard !completed, !laserActive, !resettingAfterHeartsLost else { return }
        selectedIndex = index

        if index == currentStage.correctIndex {
            HapticPlayer.playCompletionTap()
            cancelTimer()
            withAnimation(.easeOut(duration: 0.22)) {
                laserActive = true
                eliminated = true
                targetProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                self.advance()
            }
        } else {
            HapticPlayer.playLightTap()
            hearts = max(0, hearts - 1)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                wrongPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    self.wrongPulse = false
                    self.selectedIndex = nil
                }
            }
            if hearts == 0 {
                resetAfterHeartsLost()
            }
        }
    }

    private func beginRound() {
        cancelTimer()
        selectedIndex = nil
        targetProgress = 0
        secondsLeft = roundSeconds
        laserActive = false
        eliminated = false
        wrongPulse = false
        homeFlash = false
        resettingAfterHeartsLost = false
        roundStart = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard !completed, !laserActive else { return }
        let elapsed = Date().timeIntervalSince(roundStart)
        secondsLeft = max(0, roundSeconds - elapsed)
        targetProgress = min(1, elapsed / roundSeconds)

        if elapsed >= roundSeconds {
            failRound()
        }
    }

    private func failRound() {
        cancelTimer()
        hearts = max(0, hearts - 1)
        HapticPlayer.playLightTap()
        withAnimation(.easeInOut(duration: 0.16)) {
            homeFlash = true
            wrongPulse = true
            targetProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            if self.hearts == 0 {
                self.resetAfterHeartsLost()
            } else {
                self.beginRound()
            }
        }
    }

    private func resetAfterHeartsLost() {
        cancelTimer()
        resettingAfterHeartsLost = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            self.start()
        }
    }

    private func advance() {
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            stageIndex += 1
            beginRound()
        }
    }
}

struct MathItLevelFiftyOneView: View {
    var viewModel: MathItLevelFiftyOneViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                LevelFiftyOneGraphView(
                    stage: viewModel.currentStage,
                    targetProgress: viewModel.targetProgress,
                    laserActive: viewModel.laserActive,
                    eliminated: viewModel.eliminated,
                    wrongPulse: viewModel.wrongPulse,
                    homeFlash: viewModel.homeFlash
                )
                .frame(width: min(size.width - 34, 440), height: min(size.height * 0.46, 330))
                .position(x: size.width / 2, y: size.height * 0.42)

                optionButtons(size: size)
                    .position(x: size.width / 2, y: min(size.height - 94, size.height * 0.79))

                CompletionOverlay(
                    title: "Level 51 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancelTimer() }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()

            HStack(spacing: 14) {
                ProgressView(value: viewModel.progress)
                    .tint(accent)
                    .frame(width: max(116, size.width - 184))
                    .opacity(0.74)

                heartsView()

                Text(viewModel.timeText)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(viewModel.secondsLeft <= 3 ? .red.opacity(0.92) : accent)
                    .frame(width: 34)
            }
            .padding(.top, 2)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func heartsView() -> some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < viewModel.hearts ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(index < viewModel.hearts ? .red.opacity(0.92) : .white.opacity(0.28))
                    .shadow(color: .red.opacity(index < viewModel.hearts ? 0.52 : 0), radius: 7)
                    .scaleEffect(viewModel.wrongPulse && index == viewModel.hearts ? 1.22 : 1)
            }
        }
        .frame(width: 58)
        .animation(.spring(response: 0.22, dampingFraction: 0.58), value: viewModel.hearts)
        .animation(.spring(response: 0.2, dampingFraction: 0.45), value: viewModel.wrongPulse)
    }

    private func optionButtons(size: CGSize) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(viewModel.currentStage.options.enumerated()), id: \.offset) { index, option in
                Button {
                    viewModel.choose(index)
                } label: {
                    Text(option)
                        .font(.system(size: min(18, size.width * 0.043), weight: .semibold, design: .monospaced))
                        .foregroundStyle(buttonTextColor(index))
                        .frame(width: min(size.width - 62, 360), height: 46)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(buttonStrokeColor(index), lineWidth: 1.35)
                        }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.laserActive || viewModel.completed || viewModel.resettingAfterHeartsLost)
            }
        }
        .scaleEffect(viewModel.wrongPulse ? 1.018 : 1)
    }

    private func buttonTextColor(_ index: Int) -> Color {
        if viewModel.laserActive, index == viewModel.currentStage.correctIndex {
            return .black
        }
        return .white.opacity(0.86)
    }

    private func buttonStrokeColor(_ index: Int) -> Color {
        if viewModel.laserActive, index == viewModel.currentStage.correctIndex {
            return accent
        }
        if viewModel.wrongPulse, index == viewModel.selectedIndex {
            return .red.opacity(0.8)
        }
        return accent.opacity(0.45)
    }
}

struct LevelFiftyOneGraphView: View {
    let stage: LevelFiftyOneStage
    let targetProgress: Double
    let laserActive: Bool
    let eliminated: Bool
    let wrongPulse: Bool
    let homeFlash: Bool

    private let accent = Color.mathItAlgebra
    private let minX = -6.0
    private let maxX = 6.0
    private let minY = -4.0
    private let maxY = 4.0

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size).insetBy(dx: 8, dy: 8)

            ZStack {
                quadrantBackdrop(in: rect)
                grid(in: rect)
                axes(in: rect)
                laserRegion(in: rect)
                boundaryLine(in: rect)
                fortress(in: rect)
                targets(in: rect)
                graphBorder(in: rect)
            }
            .scaleEffect(wrongPulse ? 1.018 : 1)
        }
    }

    private func quadrantBackdrop(in rect: CGRect) -> some View {
        let origin = point(for: SIMD2(0, 0), in: rect)

        return ZStack {
            Rectangle()
                .fill(.white.opacity(0.018))
                .frame(width: rect.maxX - origin.x, height: origin.y - rect.minY)
                .position(x: (origin.x + rect.maxX) / 2, y: (rect.minY + origin.y) / 2)

            Rectangle()
                .fill(.white.opacity(0.028))
                .frame(width: origin.x - rect.minX, height: origin.y - rect.minY)
                .position(x: (rect.minX + origin.x) / 2, y: (rect.minY + origin.y) / 2)

            Rectangle()
                .fill(.white.opacity(0.014))
                .frame(width: origin.x - rect.minX, height: rect.maxY - origin.y)
                .position(x: (rect.minX + origin.x) / 2, y: (origin.y + rect.maxY) / 2)

            Rectangle()
                .fill(.white.opacity(0.023))
                .frame(width: rect.maxX - origin.x, height: rect.maxY - origin.y)
                .position(x: (origin.x + rect.maxX) / 2, y: (origin.y + rect.maxY) / 2)
        }
    }

    private func grid(in rect: CGRect) -> some View {
        Path { path in
            for x in Int(minX)...Int(maxX) {
                let px = point(for: SIMD2(Double(x), 0), in: rect).x
                path.move(to: CGPoint(x: px, y: rect.minY))
                path.addLine(to: CGPoint(x: px, y: rect.maxY))
            }
            for y in Int(minY)...Int(maxY) {
                let py = point(for: SIMD2(0, Double(y)), in: rect).y
                path.move(to: CGPoint(x: rect.minX, y: py))
                path.addLine(to: CGPoint(x: rect.maxX, y: py))
            }
        }
        .stroke(.white.opacity(0.14), lineWidth: 1)
    }

    private func axes(in rect: CGRect) -> some View {
        Path { path in
            let origin = point(for: SIMD2(0, 0), in: rect)
            path.move(to: CGPoint(x: rect.minX, y: origin.y))
            path.addLine(to: CGPoint(x: rect.maxX, y: origin.y))
            path.move(to: CGPoint(x: origin.x, y: rect.minY))
            path.addLine(to: CGPoint(x: origin.x, y: rect.maxY))
        }
        .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func graphBorder(in rect: CGRect) -> some View {
        Rectangle()
            .stroke(.white.opacity(0.22), lineWidth: 1.2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func laserRegion(in rect: CGRect) -> some View {
        Path { path in
            let polygon = clippedHalfPlanePolygon(greaterSide: homeFlash ? !stage.lasersGreaterSide : stage.lasersGreaterSide)
            guard let first = polygon.first else { return }
            path.move(to: point(for: first, in: rect))
            for coordinate in polygon.dropFirst() {
                path.addLine(to: point(for: coordinate, in: rect))
            }
            path.closeSubpath()
        }
        .fill((homeFlash ? Color.red : accent).opacity(homeFlash ? 0.26 : laserActive ? 0.24 : 0.045))
        .shadow(color: (homeFlash ? Color.red : accent).opacity(homeFlash ? 0.58 : laserActive ? 0.5 : 0), radius: 18)
    }

    private func boundaryLine(in rect: CGRect) -> some View {
        Path { path in
            guard let segment = boundarySegment() else { return }
            path.move(to: point(for: segment.0, in: rect))
            path.addLine(to: point(for: segment.1, in: rect))
        }
        .stroke(
            accent.opacity(0.78),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: stage.solidLine ? [] : [8, 7])
        )
        .shadow(color: accent.opacity(laserActive ? 0.72 : 0.28), radius: laserActive ? 16 : 8)
    }

    private func fortress(in rect: CGRect) -> some View {
        Image(systemName: "house.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(homeFlash ? .red.opacity(0.96) : .white)
            .shadow(color: (homeFlash ? Color.red : Color.white).opacity(homeFlash ? 0.8 : 0.45), radius: homeFlash ? 16 : 10)
            .scaleEffect(homeFlash ? 1.18 : 1)
            .position(point(for: stage.fortress, in: rect))
    }

    private func targets(in rect: CGRect) -> some View {
        ZStack {
            ForEach(Array(stage.targetStarts.enumerated()), id: \.offset) { index, start in
                let endpoint = lineIntersectionTowardFortress(from: start)
                let coordinate = interpolate(from: start, to: endpoint, progress: targetProgress)
                LevelFiftyOneFrowningEnemy(color: laserActive ? accent : .white)
                    .frame(width: laserActive ? 7 : 18, height: laserActive ? 7 : 18)
                    .shadow(color: laserActive ? accent.opacity(0.75) : .white.opacity(0.45), radius: laserActive ? 14 : 7)
                    .opacity(eliminated ? 0 : 1)
                    .position(point(for: coordinate, in: rect))
                    .animation(.easeOut(duration: 0.24).delay(Double(index) * 0.04), value: eliminated)
            }
        }
    }

    private func point(for coordinate: SIMD2<Double>, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * CGFloat((coordinate.x - minX) / (maxX - minX)),
            y: rect.maxY - rect.height * CGFloat((coordinate.y - minY) / (maxY - minY))
        )
    }

    private func linePointTowardBoundary(from start: SIMD2<Double>) -> SIMD2<Double> {
        if let verticalX = stage.verticalX {
            return SIMD2(verticalX, start.y)
        }

        let lineY = stage.slope * start.x + stage.intercept
        return SIMD2(start.x, lineY)
    }

    private func boundarySegment() -> (SIMD2<Double>, SIMD2<Double>)? {
        if let verticalX = stage.verticalX {
            guard verticalX >= minX, verticalX <= maxX else { return nil }
            return (SIMD2(verticalX, minY), SIMD2(verticalX, maxY))
        }

        var points: [SIMD2<Double>] = []
        appendIfInBounds(SIMD2(minX, stage.slope * minX + stage.intercept), to: &points)
        appendIfInBounds(SIMD2(maxX, stage.slope * maxX + stage.intercept), to: &points)

        if abs(stage.slope) > 0.0001 {
            appendIfInBounds(SIMD2((minY - stage.intercept) / stage.slope, minY), to: &points)
            appendIfInBounds(SIMD2((maxY - stage.intercept) / stage.slope, maxY), to: &points)
        }

        guard points.count >= 2 else { return nil }
        return (points[0], points[1])
    }

    private func appendIfInBounds(_ point: SIMD2<Double>, to points: inout [SIMD2<Double>]) {
        guard point.x >= minX - 0.0001, point.x <= maxX + 0.0001,
              point.y >= minY - 0.0001, point.y <= maxY + 0.0001 else { return }
        guard !points.contains(where: { distance($0, point) < 0.001 }) else { return }
        points.append(SIMD2(min(max(point.x, minX), maxX), min(max(point.y, minY), maxY)))
    }

    private func clippedHalfPlanePolygon(greaterSide: Bool) -> [SIMD2<Double>] {
        let corners = [
            SIMD2(minX, minY),
            SIMD2(maxX, minY),
            SIMD2(maxX, maxY),
            SIMD2(minX, maxY)
        ]

        var output: [SIMD2<Double>] = []
        for index in corners.indices {
            let current = corners[index]
            let next = corners[(index + 1) % corners.count]
            let currentInside = isInsideLaserSide(current, greaterSide: greaterSide)
            let nextInside = isInsideLaserSide(next, greaterSide: greaterSide)

            if currentInside && nextInside {
                output.append(next)
            } else if currentInside && !nextInside {
                if let intersection = segmentBoundaryIntersection(from: current, to: next) {
                    output.append(intersection)
                }
            } else if !currentInside && nextInside {
                if let intersection = segmentBoundaryIntersection(from: current, to: next) {
                    output.append(intersection)
                }
                output.append(next)
            }
        }
        return output
    }

    private func isInsideLaserSide(_ point: SIMD2<Double>, greaterSide: Bool) -> Bool {
        let value = sideValue(point)
        return greaterSide ? value >= -0.0001 : value <= 0.0001
    }

    private func sideValue(_ point: SIMD2<Double>) -> Double {
        if let verticalX = stage.verticalX {
            return point.x - verticalX
        }

        return point.y - (stage.slope * point.x + stage.intercept)
    }

    private func lineIntersectionTowardFortress(from start: SIMD2<Double>) -> SIMD2<Double> {
        segmentBoundaryIntersection(from: start, to: stage.fortress) ?? linePointTowardBoundary(from: start)
    }

    private func segmentBoundaryIntersection(from start: SIMD2<Double>, to end: SIMD2<Double>) -> SIMD2<Double>? {
        let startValue = sideValue(start)
        let endValue = sideValue(end)
        let denominator = startValue - endValue
        guard abs(denominator) > 0.0001 else { return nil }
        let t = min(max(startValue / denominator, 0), 1)
        return interpolate(from: start, to: end, progress: t)
    }

    private func interpolate(from start: SIMD2<Double>, to end: SIMD2<Double>, progress: Double) -> SIMD2<Double> {
        SIMD2(
            start.x + (end.x - start.x) * progress,
            start.y + (end.y - start.y) * progress
        )
    }

    private func distance(_ first: SIMD2<Double>, _ second: SIMD2<Double>) -> Double {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt(dx * dx + dy * dy)
    }
}

private struct LevelFiftyOneFrowningEnemy: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.92))
            HStack(spacing: 4) {
                Circle().fill(.black).frame(width: 2.5, height: 2.5)
                Circle().fill(.black).frame(width: 2.5, height: 2.5)
            }
            .offset(y: -3)
            Path { path in
                path.move(to: CGPoint(x: 5, y: 13))
                path.addQuadCurve(to: CGPoint(x: 13, y: 13), control: CGPoint(x: 9, y: 8))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}
