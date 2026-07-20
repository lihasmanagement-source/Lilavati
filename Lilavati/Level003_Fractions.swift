import AVFoundation
import SwiftUI

@Observable
final class MathItLevelFifteenViewModel {
    var strings: [LevelFifteenStringState] = [
        LevelFifteenStringState(fraction: "1", lengthRatio: 1, frequency: 261.63),
        LevelFifteenStringState(fraction: "8/9", lengthRatio: 8.0 / 9.0, frequency: 293.66),
        LevelFifteenStringState(fraction: "4/5", lengthRatio: 4.0 / 5.0, frequency: 329.63),
        LevelFifteenStringState(fraction: "3/4", lengthRatio: 3.0 / 4.0, frequency: 349.23),
        LevelFifteenStringState(fraction: "2/3", lengthRatio: 2.0 / 3.0, frequency: 392.00),
        LevelFifteenStringState(fraction: "3/5", lengthRatio: 3.0 / 5.0, frequency: 440.00)
    ]
    var fractionOrder: [String] = []
    var fractionOffsets: [String: CGSize] = [:]
    var placedFractions: [Int: String] = [:]
    var lastTapDate = Date.distantPast
    var completed = false
    var starUnlocked = false

    // Guided song: once every string has its fraction, the app demonstrates
    // the melody one group at a time — glowing (not waving) the correct string
    // N times, then waiting for the user to pluck that string N times before
    // previewing the next note.
    var guideStarted = false
    var guideString: Int?      // the string the guide is currently pointing at
    var demonstrating = false  // true while auto-glowing or during the hand-off pause
    var guidePulse = 0         // increments on each preview glow (the view flashes)
    private var guideGroupIndex = 0
    private var guideHitsDone = 0
    private var demoGeneration = 0

    private let tonePlayer = LevelFifteenStringPlayer()
    private let melody = [0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0]

    // Consecutive identical notes collapsed into (string, repeatCount) groups.
    private var groups: [(string: Int, count: Int)] {
        var result: [(Int, Int)] = []
        for note in melody {
            if let last = result.last, last.0 == note {
                result[result.count - 1].1 += 1
            } else {
                result.append((note, 1))
            }
        }
        return result
    }

    init() {
        fractionOrder = strings.map(\.fraction).shuffled()
    }

    var progress: Double {
        if completed { return 1 }
        let done = groups.prefix(guideGroupIndex).reduce(0) { $0 + $1.count } + guideHitsDone
        return min(0.96, Double(done) / Double(melody.count))
    }

    func pluck(at point: CGPoint, stringFrames: [CGRect]) {
        guard !completed else { return }
        guard !demonstrating else { return }   // it's the app's turn — ignore taps
        guard let nearest = nearestString(to: point.x, stringFrames: stringFrames) else { return }
        let frame = stringFrames[nearest]
        let distanceFromString = abs(point.x - frame.midX)
        let isAlongString = point.y >= frame.minY - 72 && point.y <= frame.maxY + 72
        guard distanceFromString < 64, isAlongString else { return }
        guard placedFractions[nearest] == strings[nearest].fraction else { return }
        guard Date().timeIntervalSince(lastTapDate) > 0.08 else { return }

        lastTapDate = Date()
        strings[nearest].anchor = min(max((point.y - frame.minY) / max(frame.height, 1), 0.12), 0.88)
        let direction: CGFloat = point.x < frame.midX ? -1 : 1
        let centeredAnchor = abs(strings[nearest].anchor - 0.5)
        let strength = 28 + centeredAnchor * 26

        HapticPlayer.playLightTap()
        tonePlayer.play(frequency: strings[nearest].frequency, intensity: 0.72)
        animateString(at: nearest, direction: direction, strength: strength)
        registerGuideHit(nearest)
    }

    // Hits still required on the current note before the guide moves on.
    var guideHitsRemaining: Int {
        guard guideStarted, guideGroupIndex < groups.count else { return 0 }
        return max(0, groups[guideGroupIndex].count - guideHitsDone)
    }

    func beginGuideIfReady() {
        guard !guideStarted, !completed else { return }
        guard placedFractions.count == strings.count,
              strings.indices.allSatisfy({ placedFractions[$0] == strings[$0].fraction }) else { return }
        guideStarted = true
        guideGroupIndex = 0
        guideHitsDone = 0
        guideString = groups.first?.string
        demonstrating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.demonstrateGroup()
        }
    }

    // Preview the current note by GLOWING (not waving) the string once per
    // repeat, then hand control to the player once the last glow finishes.
    private func demonstrateGroup() {
        guard guideStarted, !completed, guideGroupIndex < groups.count else { return }
        let group = groups[guideGroupIndex]
        guideString = group.string
        guard placedFractions[group.string] == strings[group.string].fraction else { return }

        demoGeneration += 1
        let gen = demoGeneration
        demonstrating = true

        let interval = 0.62
        for k in 0..<group.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + Double(k) * interval) {
                guard gen == self.demoGeneration, !self.completed else { return }
                self.tonePlayer.play(frequency: self.strings[group.string].frequency, intensity: 0.5)
                self.guidePulse += 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + Double(group.count) * interval) {
            guard gen == self.demoGeneration else { return }
            self.demonstrating = false
        }
    }

    // Count the player's plucks; advance to the next note only after the
    // current note has been hit its required number of times.
    private func registerGuideHit(_ stringIndex: Int) {
        guard guideStarted, !completed, !demonstrating else { return }
        guard guideGroupIndex < groups.count else { return }
        let group = groups[guideGroupIndex]

        guard stringIndex == group.string else {
            guideHitsDone = 0          // wrong string — start this note over
            return
        }

        guideHitsDone += 1
        guard guideHitsDone >= group.count else { return }   // more hits still needed

        guideGroupIndex += 1
        guideHitsDone = 0

        if guideGroupIndex < groups.count {
            guideString = groups[guideGroupIndex].string
            demonstrating = true       // block input during the brief hand-off pause
            demoGeneration += 1
            let gen = demoGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard gen == self.demoGeneration else { return }
                self.demonstrateGroup()
            }
        } else {
            guideString = nil
            completeAfterVibration()
        }
    }

    private func nearestString(to x: CGFloat, stringFrames: [CGRect]) -> Int? {
        stringFrames.indices.min {
            abs(stringFrames[$0].midX - x) < abs(stringFrames[$1].midX - x)
        }
    }

    private func animateString(at index: Int, direction: CGFloat, strength: CGFloat) {
        let steps: [(delay: Double, amount: CGFloat)] = [
            (0.00, 1.0),
            (0.08, -0.68),
            (0.16, 0.45),
            (0.24, -0.28),
            (0.33, 0.16),
            (0.43, -0.08),
            (0.55, 0.0)
        ]

        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                guard self.strings.indices.contains(index) else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.strings[index].offset = direction * strength * step.amount
                }
            }
        }
    }

    private func completeAfterVibration() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            self.unlockStar()
        }
    }

    private func unlockStar() {
        guard !starUnlocked, !completed else { return }

        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            starUnlocked = true
        }

        playFinaleMelody()
    }

    private func playFinaleMelody() {
        demonstrating = true
        guideString = nil
        demoGeneration += 1
        let generation = demoGeneration
        let interval = 0.42

        for (position, note) in melody.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24 + Double(position) * interval) {
                guard generation == self.demoGeneration, self.starUnlocked else { return }
                self.guideString = note
                self.guidePulse += 1
                self.tonePlayer.play(frequency: self.strings[note].frequency, intensity: 0.68)
                self.strings[note].anchor = 0.5
                self.animateString(
                    at: note,
                    direction: position.isMultiple(of: 2) ? -1 : 1,
                    strength: 34
                )
            }
        }

        let finishDelay = 0.24 + Double(melody.count) * interval + 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            guard generation == self.demoGeneration else { return }
            self.guideString = nil
            self.demonstrating = false
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    func fractionOffset(_ fraction: String) -> CGSize {
        fractionOffsets[fraction, default: .zero]
    }

    func moveFraction(_ fraction: String, by translation: CGSize) {
        guard !completed else { return }
        fractionOffsets[fraction] = translation
    }

    func finishMovingFraction(_ fraction: String, at point: CGPoint, source: CGPoint, boxFrames: [CGRect]) {
        guard !completed else { return }

        if let target = boxFrames.indices.first(where: { boxFrames[$0].insetBy(dx: -12, dy: -12).contains(point) }),
           strings[target].fraction == fraction {
            HapticPlayer.playLightTap()
            placedFractions[target] = fraction
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                fractionOffsets[fraction] = CGSize(
                    width: boxFrames[target].midX - source.x,
                    height: boxFrames[target].midY - source.y
                )
            }
            beginGuideIfReady()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                if let placedIndex = placedFractions.first(where: { $0.value == fraction })?.key {
                    fractionOffsets[fraction] = CGSize(
                        width: boxFrames[placedIndex].midX - source.x,
                        height: boxFrames[placedIndex].midY - source.y
                    )
                } else {
                    fractionOffsets[fraction] = .zero
                }
            }
        }
    }
}

struct LevelFifteenStringState: Identifiable {
    let id = UUID()
    let fraction: String
    let lengthRatio: CGFloat
    let frequency: Double
    var offset: CGFloat = 0
    var anchor: CGFloat = 0.5
}

struct MathItLevelFifteenView: View {
    var viewModel: MathItLevelFifteenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    @State private var demoFlash: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let stringTop = size.height * 0.22
            let stringBottom = size.height * 0.66
            let stringCenters = stringCenters(in: size)
            let stringFrames = frames(for: stringCenters, top: stringTop, bottom: stringBottom)
            let boxFrames = boxes(for: stringFrames)
            let fractionSources = fractionSources(in: size)

            ZStack {
                LevelFifteenTwinklingStars(active: viewModel.starUnlocked)
                    .opacity(viewModel.starUnlocked ? 1 : 0)
                    .animation(.easeIn(duration: 0.8), value: viewModel.starUnlocked)

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
                    .padding(.horizontal, 72)
                    .position(x: size.width / 2, y: 96)

                stringRig(stringFrames: stringFrames, boxFrames: boxFrames)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("levelFifteenStage"))
                            .onEnded { value in
                                viewModel.pluck(
                                    at: value.location,
                                    stringFrames: stringFrames
                                )
                            }
                    )
                    .zIndex(1)

                fractionChoices(sources: fractionSources, boxFrames: boxFrames)
                    .zIndex(4)

                CompletionOverlay(
                    title: "Level 15 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelFifteenStage")
            .onChange(of: viewModel.guidePulse) { _, _ in
                demoFlash = 1
                withAnimation(.easeOut(duration: 0.55)) { demoFlash = 0 }
            }
        }
    }

    private func frames(for centers: [CGFloat], top: CGFloat, bottom: CGFloat) -> [CGRect] {
        let maxHeight = bottom - top
        let bottomY = bottom
        return viewModel.strings.enumerated().compactMap { index, string in
            guard centers.indices.contains(index) else { return nil }
            let height = maxHeight * string.lengthRatio
            return CGRect(x: centers[index] - 36, y: bottomY - height, width: 72, height: height)
        }
    }

    private func boxes(for stringFrames: [CGRect]) -> [CGRect] {
        stringFrames.map { frame in
            CGRect(x: frame.midX - 21, y: frame.maxY + 29, width: 42, height: 30)
        }
    }

    private func fractionSources(in size: CGSize) -> [String: CGPoint] {
        let xPositions = [
            size.width * 0.16,
            size.width * 0.36,
            size.width * 0.66,
            size.width * 0.84,
            size.width * 0.25,
            size.width * 0.74
        ]
        let yPositions = [
            size.height * 0.77,
            size.height * 0.81,
            size.height * 0.775,
            size.height * 0.815,
            size.height * 0.845,
            size.height * 0.848
        ]

        return Dictionary(uniqueKeysWithValues: viewModel.fractionOrder.enumerated().map { index, fraction in
            let safeIndex = index % xPositions.count
            return (fraction, CGPoint(x: xPositions[safeIndex], y: yPositions[safeIndex]))
        })
    }

    private func stringCenters(in size: CGSize) -> [CGFloat] {
        let width = min(size.width * 0.72, 310)
        let startX = size.width / 2 - width / 2
        return viewModel.strings.indices.map { index in
            startX + width * CGFloat(index) / CGFloat(max(viewModel.strings.count - 1, 1))
        }
    }

    private func stringRig(stringFrames: [CGRect], boxFrames: [CGRect]) -> some View {
        ZStack {
            Capsule()
                .fill(.white.opacity(0.42))
                .frame(width: ((stringFrames.last?.midX ?? 0) - (stringFrames.first?.midX ?? 0)) + 54, height: 8)
                .position(x: ((stringFrames.first?.midX ?? 0) + (stringFrames.last?.midX ?? 0)) / 2, y: (stringFrames.map(\.minY).min() ?? 0) - 16)

            Capsule()
                .fill(.white.opacity(0.42))
                .frame(width: ((stringFrames.last?.midX ?? 0) - (stringFrames.first?.midX ?? 0)) + 54, height: 8)
                .position(x: ((stringFrames.first?.midX ?? 0) + (stringFrames.last?.midX ?? 0)) / 2, y: (stringFrames.map(\.maxY).max() ?? 0) + 16)

            ForEach(Array(viewModel.strings.enumerated()), id: \.element.id) { index, string in
                if stringFrames.indices.contains(index) {
                    let frame = stringFrames[index]
                    let isGuide = viewModel.guideString == index && !viewModel.completed
                    let vibrating = abs(string.offset) > 2
                    let flash = isGuide ? demoFlash : 0
                    let strokeColor: Color = isGuide ? Color.mathGold : .white
                    let glowColor: Color = isGuide ? Color.mathGold : .white
                    let glowRadius: CGFloat = (vibrating ? 16 : (isGuide ? 12 : 7)) + CGFloat(flash) * 13
                    let glowOpacity: Double = min(0.95, (vibrating ? 0.5 : (isGuide ? 0.4 : 0.16)) + flash * 0.5)

                    GuitarStringShape(offset: string.offset, anchor: string.anchor)
                        .stroke(strokeColor.opacity(0.92), style: StrokeStyle(lineWidth: isGuide ? 4 : 3.4, lineCap: .round))
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .shadow(color: glowColor.opacity(glowOpacity), radius: glowRadius)

                    if isGuide {
                        Text("×\(viewModel.guideHitsRemaining)")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.mathGold)
                            .shadow(color: Color.mathGold.opacity(0.5), radius: 5)
                            .position(x: frame.midX, y: frame.minY - 34)
                            .scaleEffect(1 + CGFloat(flash) * 0.15)
                    }

                    GuitarStringShape(
                        offset: string.offset * -0.35,
                        anchor: min(max(string.anchor + 0.07, 0.18), 0.82)
                    )
                    .stroke(.white.opacity(abs(string.offset) > 2 ? 0.22 : 0), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)

                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white.opacity(0.46), lineWidth: 1.4)
                        .frame(width: boxFrames[index].width, height: boxFrames[index].height)
                        .position(x: boxFrames[index].midX, y: boxFrames[index].midY)
                }
            }
        }
    }

    private func fractionChoices(sources: [String: CGPoint], boxFrames: [CGRect]) -> some View {
        return ZStack {
            ForEach(viewModel.fractionOrder, id: \.self) { fraction in
                if let source = sources[fraction] {
                    let offset = viewModel.fractionOffset(fraction)
                    let point = CGPoint(x: source.x + offset.width, y: source.y + offset.height)

                    Text(fraction)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(width: 48, height: 34)
                        .background(.black.opacity(0.001))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.36), lineWidth: 1.1)
                        }
                        .contentShape(Rectangle())
                        .position(point)
                        .gesture(
                            DragGesture(coordinateSpace: .named("levelFifteenStage"))
                                .onChanged { value in
                                    viewModel.moveFraction(fraction, by: value.translation)
                                }
                                .onEnded { value in
                                    let endPoint = CGPoint(
                                        x: source.x + value.translation.width,
                                        y: source.y + value.translation.height
                                    )
                                    viewModel.finishMovingFraction(
                                        fraction,
                                        at: endPoint,
                                        source: source,
                                        boxFrames: boxFrames
                                    )
                                }
                        )
                }
            }
        }
    }

}

private struct LevelFifteenTwinklingStars: View {
    let active: Bool
    @State private var activationDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !active)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let elapsed = timeline.date.timeIntervalSince(activationDate)

                let sky = Gradient(colors: [
                    Color(red: 0.005, green: 0.012, blue: 0.055),
                    Color(red: 0.012, green: 0.035, blue: 0.12),
                    Color(red: 0.025, green: 0.018, blue: 0.09),
                    .black
                ])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
                )

                // A deep layer of tiny stars gives the sky texture without a grid.
                for index in 0..<150 {
                    let x = starUnit(index, salt: 0.17) * size.width
                    let y = starUnit(index, salt: 4.91) * size.height
                    let radius = 0.35 + starUnit(index, salt: 8.13) * 0.75
                    let opacity = 0.12 + Double(starUnit(index, salt: 2.77)) * 0.28
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }

                // Foreground stars use filled, tapered diffraction spikes instead of glowing dots.
                for index in 0..<56 {
                    let x = starUnit(index, salt: 13.27) * size.width
                    let y = starUnit(index, salt: 29.41) * size.height
                    let phase = Double(starUnit(index, salt: 41.03)) * .pi * 2
                    let speed = 1.15 + Double(starUnit(index, salt: 53.71)) * 2.25
                    let wave = sin(time * speed + phase)
                    let normalizedWave = 0.5 + 0.5 * wave
                    let pulse = 0.2 + 0.8 * normalizedWave
                    let isHero = index.isMultiple(of: 7)
                    let baseRadius = isHero
                        ? 7.5 + starUnit(index, salt: 67.19) * 8.5
                        : 2.4 + starUnit(index, salt: 67.19) * 3.6
                    let radius = baseRadius * (0.82 + CGFloat(pulse) * 0.3)
                    let tint: Color = index.isMultiple(of: 11)
                        ? Color(red: 1.0, green: 0.88, blue: 0.72)
                        : Color(red: 0.78, green: 0.86, blue: 1.0)
                    let center = CGPoint(x: x, y: y)

                    let haloRadius = radius * (isHero ? 1.25 : 0.9)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - haloRadius,
                            y: y - haloRadius,
                            width: haloRadius * 2,
                            height: haloRadius * 2
                        )),
                        with: .color(tint.opacity(isHero ? 0.055 + pulse * 0.07 : 0.025))
                    )

                    context.fill(
                        starburstPath(
                            center: center,
                            verticalRadius: radius,
                            horizontalRadius: radius * (isHero ? 0.82 : 0.7),
                            diagonalRadius: isHero ? radius * 0.48 : 0
                        ),
                        with: .color(tint.opacity(0.55 + pulse * 0.4))
                    )

                    let coreRadius = isHero ? 1.75 + CGFloat(pulse) * 0.7 : 0.8 + CGFloat(pulse) * 0.45
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - coreRadius,
                            y: y - coreRadius,
                            width: coreRadius * 2,
                            height: coreRadius * 2
                        )),
                        with: .color(.white.opacity(0.88 + pulse * 0.12))
                    )
                }

                drawComet(context: &context, size: size, elapsed: elapsed)
            }
        }
        .onChange(of: active) { _, isActive in
            if isActive { activationDate = Date() }
        }
        .allowsHitTesting(false)
    }

    private func starUnit(_ index: Int, salt: Double) -> CGFloat {
        let raw = sin(Double(index + 1) * 12.9898 + salt * 78.233) * 43_758.5453
        return CGFloat(raw - floor(raw))
    }

    private func starburstPath(
        center: CGPoint,
        verticalRadius: CGFloat,
        horizontalRadius: CGFloat,
        diagonalRadius: CGFloat
    ) -> Path {
        var path = Path()
        let core = max(min(verticalRadius, horizontalRadius) * 0.12, 0.55)
        let diagonalInset = core * 0.72
        var points = [CGPoint]()

        if diagonalRadius > 0 {
            points = [
                CGPoint(x: center.x, y: center.y - verticalRadius),
                CGPoint(x: center.x + diagonalInset, y: center.y - diagonalInset),
                CGPoint(x: center.x + diagonalRadius, y: center.y - diagonalRadius),
                CGPoint(x: center.x + core, y: center.y - core * 0.28),
                CGPoint(x: center.x + horizontalRadius, y: center.y),
                CGPoint(x: center.x + core, y: center.y + core * 0.28),
                CGPoint(x: center.x + diagonalRadius, y: center.y + diagonalRadius),
                CGPoint(x: center.x + diagonalInset, y: center.y + diagonalInset),
                CGPoint(x: center.x, y: center.y + verticalRadius),
                CGPoint(x: center.x - diagonalInset, y: center.y + diagonalInset),
                CGPoint(x: center.x - diagonalRadius, y: center.y + diagonalRadius),
                CGPoint(x: center.x - core, y: center.y + core * 0.28),
                CGPoint(x: center.x - horizontalRadius, y: center.y),
                CGPoint(x: center.x - core, y: center.y - core * 0.28),
                CGPoint(x: center.x - diagonalRadius, y: center.y - diagonalRadius),
                CGPoint(x: center.x - diagonalInset, y: center.y - diagonalInset)
            ]
        } else {
            points = [
                CGPoint(x: center.x, y: center.y - verticalRadius),
                CGPoint(x: center.x + core, y: center.y - core),
                CGPoint(x: center.x + horizontalRadius, y: center.y),
                CGPoint(x: center.x + core, y: center.y + core),
                CGPoint(x: center.x, y: center.y + verticalRadius),
                CGPoint(x: center.x - core, y: center.y + core),
                CGPoint(x: center.x - horizontalRadius, y: center.y),
                CGPoint(x: center.x - core, y: center.y - core)
            ]
        }
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private func drawComet(context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        guard elapsed >= 0.35, elapsed <= 3.75 else { return }
        let rawProgress = CGFloat((elapsed - 0.35) / 3.4)
        let progress = rawProgress * rawProgress * (3 - 2 * rawProgress)
        let start = CGPoint(x: -70, y: size.height * 0.13)
        let end = CGPoint(x: size.width + 90, y: size.height * 0.48)
        let head = CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
        let length = max(hypot(end.x - start.x, end.y - start.y), 1)
        let direction = CGVector(dx: (end.x - start.x) / length, dy: (end.y - start.y) / length)

        for index in stride(from: 34, through: 1, by: -1) {
            let amount = CGFloat(index) / 34
            let distance = CGFloat(index) * 5.2
            let wobble = sin(CGFloat(index) * 0.72 + progress * 8) * amount * 2.4
            let point = CGPoint(
                x: head.x - direction.dx * distance - direction.dy * wobble,
                y: head.y - direction.dy * distance + direction.dx * wobble
            )
            let radius = 0.8 + (1 - amount) * 3.4
            let opacity = Double((1 - amount) * 0.48 + 0.025)
            let color = Color(red: 0.62 + Double(1 - amount) * 0.34, green: 0.82, blue: 1.0)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(opacity))
            )
        }

        for layer in stride(from: 18.0, through: 5.0, by: -4.0) {
            let radius = CGFloat(layer)
            let opacity = 0.035 + (18 - layer) * 0.012
            context.fill(
                Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color(red: 0.72, green: 0.9, blue: 1).opacity(opacity))
            )
        }
        context.fill(
            Path(ellipseIn: CGRect(x: head.x - 3.4, y: head.y - 3.4, width: 6.8, height: 6.8)),
            with: .color(.white.opacity(0.98))
        )
    }
}

private struct GuitarStringShape: Shape {
    var offset: CGFloat
    var anchor: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset, anchor) }
        set {
            offset = newValue.first
            anchor = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.midX
        let pluckY = rect.minY + rect.height * anchor
        let control = CGPoint(x: x + offset, y: pluckY)

        path.move(to: CGPoint(x: x, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: x, y: rect.midY), control: control)
        path.addQuadCurve(to: CGPoint(x: x, y: rect.maxY), control: control)
        return path
    }
}

private final class LevelFifteenStringPlayer {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let lock = NSLock()
    private var currentFrequency: Double = 220
    private var amplitude: Double = 0
    private var targetAmplitude: Double = 0
    private var phase: Double = 0
    private var vibratoPhase: Double = 0
    private var filteredSample: Double = 0

    private lazy var sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self else { return noErr }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

        for frame in 0..<Int(frameCount) {
            self.lock.lock()
            let frequency = self.currentFrequency
            self.amplitude += (self.targetAmplitude - self.amplitude) * 0.008
            let currentAmplitude = self.amplitude
            self.targetAmplitude *= 0.99972
            if self.targetAmplitude < 0.0008 {
                self.targetAmplitude = 0
            }
            if self.amplitude < 0.0008 && self.targetAmplitude == 0 {
                self.amplitude = 0
            }
            self.lock.unlock()

            let vibrato = 1 + sin(self.vibratoPhase) * 0.0022
            let bowedString =
                sin(self.phase) * 0.46
                + sin(self.phase * 2) * 0.25
                + sin(self.phase * 3) * 0.15
                + sin(self.phase * 4) * 0.08
                + sin(self.phase * 5) * 0.04
                + sin(self.phase * 6) * 0.02
            let bowTexture = sin(self.phase * 13.7) * 0.012
            let shapedSample = tanh((bowedString + bowTexture) * currentAmplitude * 1.7)
            self.filteredSample += (shapedSample - self.filteredSample) * 0.32
            let sample = Float(self.filteredSample)

            self.phase += 2 * Double.pi * frequency * vibrato / self.sampleRate
            if self.phase > 2 * Double.pi {
                self.phase -= 2 * Double.pi
            }
            self.vibratoPhase += 2 * Double.pi * 5.2 / self.sampleRate
            if self.vibratoPhase > 2 * Double.pi {
                self.vibratoPhase -= 2 * Double.pi
            }

            for buffer in buffers {
                let output = buffer.mData?.assumingMemoryBound(to: Float.self)
                output?[frame] = sample
            }
        }

        return noErr
    }

    init() {
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func play(frequency: Double, intensity: Double) {
        lock.lock()
        currentFrequency = frequency
        targetAmplitude = min(max(0.085 * intensity, 0.026), 0.086)
        lock.unlock()

        if !engine.isRunning {
            try? engine.start()
        }
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }
}
