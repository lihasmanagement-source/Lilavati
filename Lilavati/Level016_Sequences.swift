import SwiftUI

@Observable
final class MirrorCascadeViewModel {
    var tokens: [OneToken] = [
        OneToken(position: .zero, isOriginal: true)
    ]
    var activeDragOffsets: [UUID: CGSize] = [:]
    var draggingTokenID: UUID?
    var rampBuilt = false
    var ballReleased = false
    var ballProgress: CGFloat = 0
    var completed = false

    func duplicateOneFromMirror(tokenID: UUID, mirrorGlass: CGRect, source: CGPoint) {
        guard tokens.count < 7, let token = tokens.first(where: { $0.id == tokenID }) else { return }

        let absolutePoint = CGPoint(x: source.x + token.position.x, y: source.y + token.position.y)
        guard mirrorGlass.contains(absolutePoint) else { return }

        let reflectedAbsolutePoint = CGPoint(
            x: mirrorGlass.midX + (mirrorGlass.midX - absolutePoint.x),
            y: absolutePoint.y
        )
        let spawnPoint = CGPoint(
            x: reflectedAbsolutePoint.x - source.x,
            y: reflectedAbsolutePoint.y - source.y
        )
        let hasNearbyCopy = tokens.contains { other in
            other.id != tokenID && hypot(other.position.x - spawnPoint.x, other.position.y - spawnPoint.y) < 18
        }
        guard !hasNearbyCopy else { return }

        HapticPlayer.playLightTap()
        // Pop the new "1" into existence at the reflection point (no slide from the original).
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            tokens.append(OneToken(id: UUID(), position: spawnPoint, isOriginal: false))
        }
    }

    func moveToken(id: UUID, to absoluteLocation: CGPoint, source: CGPoint) {
        guard let index = tokens.firstIndex(where: { $0.id == id }) else { return }
        draggingTokenID = id

        let currentAbsolutePosition = CGPoint(
            x: source.x + tokens[index].position.x,
            y: source.y + tokens[index].position.y
        )
        let grabOffset = activeDragOffsets[id] ?? CGSize(
            width: currentAbsolutePosition.x - absoluteLocation.x,
            height: currentAbsolutePosition.y - absoluteLocation.y
        )
        activeDragOffsets[id] = grabOffset

        tokens[index].position = CGPoint(
            x: absoluteLocation.x + grabOffset.width - source.x,
            y: absoluteLocation.y + grabOffset.height - source.y
        )
    }

    func finishMovingToken(id: UUID, rampSlots: [CGPoint], mirrorGlass: CGRect, source: CGPoint) {
        guard let index = tokens.firstIndex(where: { $0.id == id }) else { return }

        duplicateOneFromMirror(tokenID: id, mirrorGlass: mirrorGlass, source: source)
        snapTokenIfNeeded(at: index, rampSlots: rampSlots)
        checkForRamp(rampSlots: rampSlots)

        tokens[index].dragStart = tokens[index].position
        activeDragOffsets[id] = nil
        draggingTokenID = nil
    }

    private func snapTokenIfNeeded(at index: Int, rampSlots: [CGPoint]) {
        let snapThreshold: CGFloat = 42
        let token = tokens[index]

        // Snap only onto the ramp slots (the gray guides) so placed 1s line up exactly.
        let candidates = rampSlots.filter { candidate in
            !tokens.contains { other in
                other.id != token.id && hypot(other.position.x - candidate.x, other.position.y - candidate.y) < 8
            }
        }

        guard let nearest = candidates.min(by: {
            hypot(token.position.x - $0.x, token.position.y - $0.y) < hypot(token.position.x - $1.x, token.position.y - $1.y)
        }) else { return }

        let distance = hypot(token.position.x - nearest.x, token.position.y - nearest.y)
        guard distance < snapThreshold else { return }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.76)) {
            tokens[index].position = nearest
        }
    }

    private func checkForRamp(rampSlots: [CGPoint]) {
        guard !rampBuilt, containsStairRamp(rampSlots: rampSlots) else { return }

        HapticPlayer.playCompletionTap()
        rampBuilt = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.releaseBall()
        }
    }

    private func containsStairRamp(rampSlots: [CGPoint]) -> Bool {
        let tolerance: CGFloat = 10
        var matchedTokenIDs = Set<UUID>()

        for slot in rampSlots {
            let matchingTokens = tokens.filter { token in
                hypot(token.position.x - slot.x, token.position.y - slot.y) <= tolerance
            }
            guard matchingTokens.count == 1, let tokenID = matchingTokens.first?.id else { return false }
            matchedTokenIDs.insert(tokenID)
        }

        guard matchedTokenIDs.count == rampSlots.count else { return false }

        let xValues = rampSlots.map(\.x)
        let yValues = rampSlots.map(\.y)
        let rampBounds = CGRect(
            x: (xValues.min() ?? 0) - 46,
            y: (yValues.min() ?? 0) - 46,
            width: ((xValues.max() ?? 0) - (xValues.min() ?? 0)) + 92,
            height: ((yValues.max() ?? 0) - (yValues.min() ?? 0)) + 92
        )

        return tokens.allSatisfy { token in
            matchedTokenIDs.contains(token.id) || !rampBounds.contains(token.position)
        }
    }

    private func releaseBall() {
        guard !ballReleased else { return }

        ballReleased = true
        withAnimation(.linear(duration: 2.2)) {
            ballProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                self.completed = true
            }
        }
    }
}

struct OneToken: Identifiable {
    let id: UUID
    var position: CGPoint
    var dragStart: CGPoint
    let isOriginal: Bool

    init(id: UUID = UUID(), position: CGPoint, isOriginal: Bool) {
        self.id = id
        self.position = position
        self.dragStart = position
        self.isOriginal = isOriginal
    }
}

// Translates the ball along a multi-segment hop path. `progress` is the animatable
// data, so `withAnimation` samples the curve every frame (a real hop, not a slide).
private struct BallHopEffect: GeometryEffect {
    var progress: CGFloat
    let waypoints: [CGPoint]

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard waypoints.count >= 2 else { return ProjectionTransform() }
        let segments = waypoints.count - 1
        let scaled = min(max(progress, 0), 1) * CGFloat(segments)
        let seg = min(Int(scaled), segments - 1)
        let t = scaled - CGFloat(seg)
        let a = waypoints[seg], b = waypoints[seg + 1]
        let x = a.x + (b.x - a.x) * t
        let lineY = a.y + (b.y - a.y) * t
        let arc = -84 * 4 * t * (1 - t)                       // taller parabolic hop
        // Translate relative to the ball's base position (waypoints[0]).
        return ProjectionTransform(CGAffineTransform(translationX: x - waypoints[0].x, y: lineY + arc - waypoints[0].y))
    }
}

struct MirrorCascadeView: View {
    var viewModel: MirrorCascadeViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void
    var embedded: Bool = false   // true when hosted as stage 2 of level 1

    private let oneFontSize: CGFloat = 78

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardFrame = levelThreeBoardFrame(in: size)
            let mirrorCenter = levelThreeMirrorCenter(in: boardFrame)
            let mirrorSize = CGSize(width: 118, height: 146)
            let mirrorGlass = CGRect(
                x: mirrorCenter.x - mirrorSize.width / 2,
                y: mirrorCenter.y - mirrorSize.height / 2,
                width: mirrorSize.width,
                height: mirrorSize.height
            )
            let source = sourcePoint(mirrorCenter: mirrorCenter, mirrorSize: mirrorSize)
            // Ascending staircase — columns of heights 1, 2, 3 — centered, near the bottom.
            let hSpacing: CGFloat = 64
            let vSpacing: CGFloat = 62
            let glyphHalf = oneFontSize * 0.36
            let col0X = boardFrame.midX - hSpacing          // 3 columns centered on the board
            let baseY = size.height * 0.82                  // ground line near the bottom
            // Landing points that sit just on top of each column's tallest "1".
            let hopTops = (0..<3).map { c in
                CGPoint(x: col0X + CGFloat(c) * hSpacing, y: baseY - CGFloat(c) * vSpacing - glyphHalf - 6)
            }
            let ballStart = CGPoint(x: col0X - hSpacing * 0.85, y: baseY + glyphHalf)   // level with the base of the first "1"
            let goal = CGPoint(x: hopTops[2].x, y: hopTops[2].y - vSpacing)  // aligned above the tallest column
            let catchFrame = CGRect(x: goal.x - 13, y: goal.y - 13, width: 26, height: 26)
            let hopWaypoints = [ballStart] + hopTops + [goal]
            let rampSlots = levelThreeRampSlots(source: source, col0X: col0X, baseY: baseY, hSpacing: hSpacing, vSpacing: vSpacing)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                cascadeMirror(center: mirrorCenter, size: mirrorSize)

                mirrorGhost(mirrorCenter: mirrorCenter, mirrorSize: mirrorSize, source: source)

                Circle()
                    .stroke(.white.opacity(0.85), lineWidth: 2)
                    .frame(width: catchFrame.width, height: catchFrame.height)
                    .position(x: catchFrame.midX, y: catchFrame.midY)
                    .shadow(color: .white.opacity(viewModel.completed ? 0.34 : 0.08), radius: viewModel.completed ? 14 : 5)

                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: .white.opacity(0.8), radius: 14)
                    .position(ballStart)
                    .modifier(BallHopEffect(progress: viewModel.ballProgress, waypoints: hopWaypoints))

                // Gray "1" guides marking the precise staircase locations to build.
                ForEach(Array(rampSlots.enumerated()), id: \.offset) { _, slot in
                    Text("1")
                        .font(.system(size: oneFontSize, weight: .regular, design: .serif))
                        .foregroundStyle(Color(white: 0.4))
                        .position(x: source.x + slot.x, y: source.y + slot.y)
                        .allowsHitTesting(false)
                }

                ForEach(viewModel.tokens) { token in
                    oneTokenView(token, source: source, rampSlots: rampSlots, mirrorGlass: mirrorGlass)
                }

                // When embedded as stage 2, the host (level 1) shows the final overlay.
                if !embedded, let concept = ConceptLibrary.concept(for: 3) {
                    ConceptCompletionOverlay(
                        levelTitle: "Mirror Cascade",
                        concept: concept,
                        isVisible: viewModel.completed,
                        onContinue: onContinue,
                        onReplay: onReplay,
                        onLevelSelect: onLevelSelect
                    )
                }
            }
            .coordinateSpace(name: "levelThreeStage")
        }
    }

    private func oneTokenView(_ token: OneToken, source: CGPoint, rampSlots: [CGPoint], mirrorGlass: CGRect) -> some View {
        let point = CGPoint(x: source.x + token.position.x, y: source.y + token.position.y)

        let dragGesture = DragGesture(coordinateSpace: .named("levelThreeStage"))
            .onChanged { value in
                viewModel.moveToken(id: token.id, to: value.location, source: source)
            }
            .onEnded { _ in
                viewModel.finishMovingToken(id: token.id, rampSlots: rampSlots, mirrorGlass: mirrorGlass, source: source)
            }

        return SymbolOneView(fontSize: oneFontSize, glow: true)
            .transition(.scale(scale: 0.35).combined(with: .opacity))
            .position(point)
            .gesture(dragGesture)
    }

    private func sourcePoint(mirrorCenter: CGPoint, mirrorSize: CGSize) -> CGPoint {
        CGPoint(x: mirrorCenter.x, y: mirrorCenter.y - mirrorSize.height * 0.95)
    }

    private func levelThreeMirrorCenter(in boardFrame: CGRect) -> CGPoint {
        CGPoint(x: boardFrame.midX, y: boardFrame.minY + 140)
    }

    private func levelThreeBoardFrame(in size: CGSize) -> CGRect {
        let width = min(size.width * 0.84, 430)
        let height = min(size.height * 0.62, 560)
        return CGRect(
            x: (size.width - width) / 2,
            y: size.height * 0.19,
            width: width,
            height: height
        )
    }

    private func levelThreeCatchFrame(in boardFrame: CGRect) -> CGRect {
        CGRect(
            x: boardFrame.minX + 86,
            y: boardFrame.maxY - 96,
            width: 24,
            height: 24
        )
    }

    private func levelThreeRampSlots(source: CGPoint, col0X: CGFloat, baseY: CGFloat, hSpacing: CGFloat, vSpacing: CGFloat) -> [CGPoint] {
        var slots: [CGPoint] = []
        for column in 0..<3 {                              // columns of heights 1, 2, 3
            let columnX = col0X + CGFloat(column) * hSpacing
            for row in 0...column {
                let absolute = CGPoint(x: columnX, y: baseY - CGFloat(row) * vSpacing)
                slots.append(CGPoint(x: absolute.x - source.x, y: absolute.y - source.y))
            }
        }
        return slots
    }


    private func rampBallPoint(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let control = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x
        let y = oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }

    // Ghosted reflection preview while a "1" is dragged toward the mirror (as in Level 1).
    @ViewBuilder
    private func mirrorGhost(mirrorCenter: CGPoint, mirrorSize: CGSize, source: CGPoint) -> some View {
        if let dragID = viewModel.draggingTokenID,
           let token = viewModel.tokens.first(where: { $0.id == dragID }) {
            let absPos = CGPoint(x: source.x + token.position.x, y: source.y + token.position.y)
            let dist = hypot(absPos.x - mirrorCenter.x, absPos.y - mirrorCenter.y)
            let revealDistance = mirrorSize.height * 0.82
            if dist < revealDistance {
                let approach = max(0, min(1, 1 - dist / revealDistance))
                // Exactly where the duplicated "1" will spawn (mirror across the glass centre).
                let reflection = CGPoint(x: 2 * mirrorCenter.x - absPos.x, y: absPos.y)
                SymbolOneView(fontSize: oneFontSize, glow: false)
                    .scaleEffect(x: -1, y: 1)
                    .opacity(0.12 + Double(approach) * 0.55)
                    .blur(radius: (1 - approach) * 1.2)
                    .position(reflection)
                    .allowsHitTesting(false)
            }
        }
    }

    // Same mirror as Level 1 (copied for identical look).
    private func cascadeMirror(center mirrorCenter: CGPoint, size mirrorSize: CGSize) -> some View {
        ZStack {
            ForEach(0..<28, id: \.self) { index in
                let angle = Double(index) / 28 * Double.pi * 2
                let radiusX = mirrorSize.width * 0.55
                let radiusY = mirrorSize.height * 0.52
                Circle()
                    .stroke(Color.mathGold.opacity(0.7), lineWidth: 1.2)
                    .frame(width: 7, height: 7)
                    .position(
                        x: mirrorCenter.x + CGFloat(cos(angle)) * radiusX,
                        y: mirrorCenter.y + CGFloat(sin(angle)) * radiusY
                    )
            }

            Path { path in
                path.move(to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y - mirrorSize.height * 0.66))
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y - mirrorSize.height * 0.55),
                    control: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.16, y: mirrorCenter.y - mirrorSize.height * 0.61)
                )
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y - mirrorSize.height * 0.66),
                    control: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.16, y: mirrorCenter.y - mirrorSize.height * 0.61)
                )

                path.move(to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y + mirrorSize.height * 0.66))
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y + mirrorSize.height * 0.55),
                    control: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.16, y: mirrorCenter.y + mirrorSize.height * 0.61)
                )
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y + mirrorSize.height * 0.66),
                    control: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.16, y: mirrorCenter.y + mirrorSize.height * 0.61)
                )

                path.move(to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.62, y: mirrorCenter.y))
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.78, y: mirrorCenter.y),
                    control: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.69, y: mirrorCenter.y - mirrorSize.height * 0.11)
                )
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.62, y: mirrorCenter.y),
                    control: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.69, y: mirrorCenter.y + mirrorSize.height * 0.11)
                )

                path.move(to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.62, y: mirrorCenter.y))
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.78, y: mirrorCenter.y),
                    control: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.69, y: mirrorCenter.y - mirrorSize.height * 0.11)
                )
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.62, y: mirrorCenter.y),
                    control: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.69, y: mirrorCenter.y + mirrorSize.height * 0.11)
                )
            }
            .stroke(Color.mathGold.opacity(0.78), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))

            Ellipse()
                .stroke(Color.mathGold.opacity(0.95), lineWidth: 8)
                .frame(width: mirrorSize.width + 18, height: mirrorSize.height + 18)
                .position(mirrorCenter)
                .shadow(color: Color.mathGold.opacity(0.18), radius: 10)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.73, green: 0.95, blue: 1.0).opacity(0.92),
                            Color(red: 0.45, green: 0.82, blue: 0.94).opacity(0.78),
                            Color(red: 0.18, green: 0.32, blue: 0.42).opacity(0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: mirrorSize.width, height: mirrorSize.height)
                .overlay(
                    Ellipse()
                        .stroke(.white.opacity(0.78), lineWidth: 1.3)
                )
                .position(mirrorCenter)

            Path { path in
                path.move(to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.22, y: mirrorCenter.y - mirrorSize.height * 0.38))
                path.addLine(to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.2, y: mirrorCenter.y + mirrorSize.height * 0.06))
                path.move(to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.1, y: mirrorCenter.y - mirrorSize.height * 0.46))
                path.addLine(to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.32, y: mirrorCenter.y - mirrorSize.height * 0.02))
            }
            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
    }
}

// MARK: - Level 3 · Lunar Phases (Fractions)

struct LunarPhaseStage {
    let numerator: Int
    let denominator: Int
    let startingAngle: CGFloat
    let hidePhaseNameUntilSolved: Bool

    var target: CGFloat { CGFloat(numerator) / CGFloat(denominator) }
    var label: String { denominator == 1 ? "\(numerator)" : "\(numerator)/\(denominator)" }
}

@Observable
final class MathItLevelThreeViewModel {
    let stages: [LunarPhaseStage] = [
        LunarPhaseStage(numerator: 0, denominator: 1, startingAngle: -0.18 * .pi, hidePhaseNameUntilSolved: false),
        LunarPhaseStage(numerator: 1, denominator: 2, startingAngle: 0.72 * .pi, hidePhaseNameUntilSolved: false),
        LunarPhaseStage(numerator: 1, denominator: 1, startingAngle: -0.64 * .pi, hidePhaseNameUntilSolved: false),
        LunarPhaseStage(numerator: 1, denominator: 4, startingAngle: 0.08 * .pi, hidePhaseNameUntilSolved: false),
        LunarPhaseStage(numerator: 3, denominator: 4, startingAngle: -0.92 * .pi, hidePhaseNameUntilSolved: false),
        LunarPhaseStage(numerator: 1, denominator: 4, startingAngle: -0.34 * .pi, hidePhaseNameUntilSolved: false),
        LunarPhaseStage(numerator: 1, denominator: 8, startingAngle: 0.46 * .pi, hidePhaseNameUntilSolved: true),
        LunarPhaseStage(numerator: 5, denominator: 8, startingAngle: -0.28 * .pi, hidePhaseNameUntilSolved: true),
        LunarPhaseStage(numerator: 7, denominator: 8, startingAngle: 0.82 * .pi, hidePhaseNameUntilSolved: true)
    ]

    var stageIndex = 0
    var moonAngle: CGFloat = -0.18 * .pi
    var completed = false
    var glowPulse = false
    var advancing = false
    var revealedPhaseName: String?

    var currentStage: LunarPhaseStage { stages[min(stageIndex, stages.count - 1)] }

    var progress: Double {
        if completed { return 1 }
        let local = max(0, 1 - abs(visibleFraction - currentStage.target) / 0.45) * 0.5
        return (Double(stageIndex) + 0.12 + Double(local)) / Double(stages.count)
    }

    var stageBand: Int { min(3, stageIndex / 3 + 1) }

    var visibleFraction: CGFloat {
        min(1, max(0, (1 + cos(moonAngle)) / 2))
    }

    var isWaxing: Bool {
        moonAngle > 0
    }

    var currentPhaseName: String {
        Self.phaseName(for: visibleFraction, waxing: isWaxing)
    }

    var displayedPhaseName: String? {
        if let revealedPhaseName { return revealedPhaseName }
        return currentStage.hidePhaseNameUntilSolved ? nil : currentPhaseName
    }

    var targetWaxing: Bool {
        sin(targetAngle(for: currentStage)) > 0
    }

    func beginIfNeeded() {
        if stageIndex == 0, abs(moonAngle - stages[0].startingAngle) < 0.0001 { return }
    }

    func dragMoon(to location: CGPoint, earth: CGPoint, orbitRadius: CGFloat) {
        guard !completed, !advancing else { return }
        let dx = location.x - earth.x
        let dy = location.y - earth.y
        guard hypot(dx, dy) > orbitRadius * 0.24 else { return }
        moonAngle = atan2(dy, dx)
        checkForMatch()
    }

    func endDrag() {
        checkForMatch()
    }

    func reset() {
        stageIndex = 0
        moonAngle = stages[0].startingAngle
        completed = false
        glowPulse = false
        advancing = false
        revealedPhaseName = nil
    }

    private func checkForMatch() {
        guard !advancing, !completed else { return }
        guard abs(visibleFraction - currentStage.target) <= tolerance(for: currentStage) else { return }

        advancing = true
        glowPulse = true
        let snapAngle = nearestAngle(for: currentStage.target)
        revealedPhaseName = Self.phaseName(for: currentStage.target, waxing: sin(snapAngle) > 0)
        HapticPlayer.playCompletionTap()

        withAnimation(.spring(response: 0.48, dampingFraction: 0.74)) {
            moonAngle = snapAngle
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            self.completeStage()
        }
    }

    private func completeStage() {
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.66, dampingFraction: 0.82)) {
                completed = true
                glowPulse = false
                advancing = false
            }
        } else {
            let next = stageIndex + 1
            withAnimation(.spring(response: 0.56, dampingFraction: 0.82)) {
                stageIndex = next
                moonAngle = stages[next].startingAngle
                glowPulse = false
                advancing = false
                revealedPhaseName = nil
            }
        }
    }

    private func tolerance(for stage: LunarPhaseStage) -> CGFloat {
        stage.denominator >= 8 ? 0.015 : 0.02
    }

    private func nearestAngle(for target: CGFloat) -> CGFloat {
        nearestAngle(for: target, reference: moonAngle)
    }

    private func targetAngle(for stage: LunarPhaseStage) -> CGFloat {
        nearestAngle(for: stage.target, reference: stage.startingAngle)
    }

    private func nearestAngle(for target: CGFloat, reference: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, target))
        let base = acos(2 * clamped - 1)
        let candidates = [base, -base, 2 * .pi - base, base - 2 * .pi]
        return candidates.min { angularDistance($0, reference) < angularDistance($1, reference) } ?? base
    }

    private func angularDistance(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let raw = abs(a - b).truncatingRemainder(dividingBy: 2 * .pi)
        return min(raw, 2 * .pi - raw)
    }

    static func phaseName(for fraction: CGFloat, waxing: Bool) -> String {
        if fraction <= 0.04 { return "New Moon" }
        if fraction >= 0.96 { return "Full Moon" }
        if abs(fraction - 0.5) <= 0.04 { return waxing ? "First Quarter" : "Last Quarter" }
        if fraction < 0.5 { return waxing ? "Waxing Crescent" : "Waning Crescent" }
        return waxing ? "Waxing Gibbous" : "Waning Gibbous"
    }
}

struct MathItLevelThreeView: View {
    var viewModel: MathItLevelThreeViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathGold

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let size = proxy.size
                let earth = CGPoint(x: size.width * 0.52, y: size.height * 0.50)
                let orbitRadius = min(size.width * 0.34, size.height * 0.26, 150)
                let moonRadius = min(size.width * 0.075, 31)
                let sunCenter = CGPoint(x: max(52, size.width * 0.12), y: earth.y - orbitRadius * 0.18)
                let moonCenter = moonPoint(earth: earth, orbitRadius: orbitRadius, time: timeline.date.timeIntervalSinceReferenceDate)
                let fraction = viewModel.visibleFraction
                let closeness = max(0, 1 - abs(fraction - viewModel.currentStage.target) / 0.22)

                ZStack {
                    LunarSpaceBackground()

                    HomeButton(action: onLevelSelect)
                        .position(x: 34, y: 54)
                        .zIndex(20)

                    sunView(center: sunCenter, radius: min(size.width * 0.09, 44))

                    orbitView(center: earth, radius: orbitRadius, closeness: closeness)

                    earthView(center: earth, radius: min(size.width * 0.105, 46), pulse: viewModel.glowPulse)

                    targetPanel(fraction: fraction)
                        .position(x: size.width / 2, y: size.height * 0.21)

                    moonView(center: moonCenter, radius: moonRadius, fraction: fraction, waxing: viewModel.isWaxing, closeness: closeness)
                        .contentShape(Circle().inset(by: -28))
                        .gesture(
                            DragGesture(coordinateSpace: .named("levelThreeLunar"))
                                .onChanged { value in
                                    viewModel.dragMoon(to: value.location, earth: earth, orbitRadius: orbitRadius)
                                }
                                .onEnded { _ in viewModel.endDrag() }
                        )
                        .accessibilityLabel("Moon")

                    phaseReadout(size: size, fraction: fraction)

                    if let concept = ConceptLibrary.concept(for: 3) {
                        ConceptCompletionOverlay(
                            levelTitle: "Lunar Phases",
                            concept: concept,
                            isVisible: viewModel.completed,
                            onContinue: onContinue,
                            onReplay: {
                                viewModel.reset()
                                onReplay()
                            },
                            onLevelSelect: onLevelSelect
                        )
                        .zIndex(30)
                    }
                }
                .coordinateSpace(name: "levelThreeLunar")
                .onAppear { viewModel.reset() }
                .animation(.easeInOut(duration: 0.22), value: viewModel.stageIndex)
                .animation(.easeOut(duration: 0.18), value: fraction)
            }
        }
    }

    private func moonPoint(earth: CGPoint, orbitRadius: CGFloat, time: TimeInterval) -> CGPoint {
        let gravityWobble = CGFloat(sin(time * 1.9)) * (viewModel.advancing ? 1.4 : 4.0)
        let radius = orbitRadius + gravityWobble
        return CGPoint(
            x: earth.x + cos(viewModel.moonAngle) * radius,
            y: earth.y + sin(viewModel.moonAngle) * radius * 0.76
        )
    }

    private func targetPanel(fraction: CGFloat) -> some View {
        let target = viewModel.currentStage
        return HStack(spacing: 16) {
            Text(target.label)
                .font(.system(size: 48, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.92))
                .contentTransition(.numericText())

            lunarPhaseSymbol(
                fraction: target.target,
                waxing: viewModel.targetWaxing,
                size: 42,
                glow: max(0.2, 1 - abs(fraction - target.target) / 0.25)
            )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func sunView(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.12))
                .frame(width: radius * 4.2, height: radius * 4.2)
                .blur(radius: 12)
            Circle()
                .fill(RadialGradient(colors: [.white, accent, Color(red: 1, green: 0.42, blue: 0.08)], center: .center, startRadius: 2, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: accent.opacity(0.7), radius: 20)
        }
        .position(center)
    }

    private func orbitView(center: CGPoint, radius: CGFloat, closeness: CGFloat) -> some View {
        Ellipse()
            .stroke(accent.opacity(0.22 + Double(closeness) * 0.25), style: StrokeStyle(lineWidth: 1.8, dash: [6, 8]))
            .frame(width: radius * 2, height: radius * 1.52)
            .position(center)
            .shadow(color: accent.opacity(Double(closeness) * 0.35), radius: 10)
    }

    private func earthView(center: CGPoint, radius: CGFloat, pulse: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.28, green: 0.78, blue: 1).opacity(pulse ? 0.56 : 0.16), lineWidth: pulse ? 12 : 6)
                .frame(width: radius * 2.65, height: radius * 2.65)
                .blur(radius: pulse ? 5 : 8)
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.28, green: 0.78, blue: 1), Color(red: 0.05, green: 0.14, blue: 0.42), Color(red: 0.015, green: 0.04, blue: 0.09)], center: .topLeading, startRadius: 2, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .overlay(
                    ZStack {
                        EarthContinentShape(points: [
                            CGPoint(x: 0.16, y: 0.28), CGPoint(x: 0.31, y: 0.18), CGPoint(x: 0.46, y: 0.25),
                            CGPoint(x: 0.42, y: 0.39), CGPoint(x: 0.28, y: 0.46), CGPoint(x: 0.14, y: 0.40)
                        ])
                        .fill(Color(red: 0.24, green: 0.62, blue: 0.28).opacity(0.66))

                        EarthContinentShape(points: [
                            CGPoint(x: 0.54, y: 0.24), CGPoint(x: 0.76, y: 0.21), CGPoint(x: 0.88, y: 0.34),
                            CGPoint(x: 0.78, y: 0.49), CGPoint(x: 0.59, y: 0.45), CGPoint(x: 0.49, y: 0.34)
                        ])
                        .fill(Color(red: 0.30, green: 0.70, blue: 0.32).opacity(0.58))

                        EarthContinentShape(points: [
                            CGPoint(x: 0.30, y: 0.55), CGPoint(x: 0.45, y: 0.53), CGPoint(x: 0.53, y: 0.66),
                            CGPoint(x: 0.43, y: 0.84), CGPoint(x: 0.31, y: 0.76), CGPoint(x: 0.23, y: 0.64)
                        ])
                        .fill(Color(red: 0.20, green: 0.55, blue: 0.25).opacity(0.62))

                        EarthContinentShape(points: [
                            CGPoint(x: 0.67, y: 0.60), CGPoint(x: 0.84, y: 0.57), CGPoint(x: 0.91, y: 0.72),
                            CGPoint(x: 0.78, y: 0.83), CGPoint(x: 0.63, y: 0.77)
                        ])
                        .fill(Color(red: 0.27, green: 0.66, blue: 0.30).opacity(0.46))

                        Capsule()
                            .fill(.white.opacity(0.16))
                            .frame(width: radius * 0.86, height: radius * 0.12)
                            .offset(x: -radius * 0.18, y: -radius * 0.06)
                            .rotationEffect(.degrees(-12))

                        Capsule()
                            .fill(.white.opacity(0.11))
                            .frame(width: radius * 0.72, height: radius * 0.10)
                            .offset(x: radius * 0.22, y: radius * 0.28)
                            .rotationEffect(.degrees(18))
                    }
                    .clipShape(Circle())
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1.2)
                )
                .shadow(color: Color.blue.opacity(0.42), radius: 16)
        }
        .position(center)
        .scaleEffect(pulse ? 1.035 : 1)
    }

    private func moonView(center: CGPoint, radius: CGFloat, fraction: CGFloat, waxing: Bool, closeness: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.06, green: 0.065, blue: 0.08))
            LunarIlluminationShape(fraction: fraction, waxing: waxing)
                .fill(LinearGradient(colors: [.white, Color(red: 0.72, green: 0.74, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle())
            Circle()
                .stroke(.white.opacity(0.12 + Double(closeness) * 0.24), lineWidth: 1.4)
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(.black.opacity(0.10))
                    .frame(width: radius * CGFloat([0.24, 0.15, 0.18, 0.11, 0.13][index]), height: radius * CGFloat([0.24, 0.15, 0.18, 0.11, 0.13][index]))
                    .offset(x: radius * CGFloat([-0.28, 0.20, 0.02, -0.08, 0.34][index]), y: radius * CGFloat([-0.18, -0.28, 0.26, 0.03, 0.18][index]))
                    .opacity(0.55)
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .shadow(color: .black.opacity(0.8), radius: 12)
        .shadow(color: accent.opacity(Double(closeness) * 0.45), radius: 16)
        .position(center)
        .scaleEffect(viewModel.glowPulse ? 1.06 : 1)
    }

    private func lunarPhaseSymbol(fraction: CGFloat, waxing: Bool, size: CGFloat, glow: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.055, green: 0.06, blue: 0.075))
            LunarIlluminationShape(fraction: fraction, waxing: waxing)
                .fill(LinearGradient(colors: [.white, Color(red: 0.72, green: 0.74, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle())
            Circle()
                .stroke(accent.opacity(0.35 + Double(glow) * 0.34), lineWidth: 1.4)
        }
        .frame(width: size, height: size)
        .shadow(color: accent.opacity(Double(glow) * 0.42), radius: 8)
    }

    private func phaseReadout(size: CGSize, fraction: CGFloat) -> some View {
        let railWidth = min(size.width - 74, 330)
        return VStack(spacing: 10) {
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1)).frame(width: railWidth, height: 7)
                Capsule().fill(accent.opacity(0.88)).frame(width: railWidth * fraction, height: 7)
                Capsule()
                    .fill(.white.opacity(0.95))
                    .frame(width: 4, height: 18)
                    .offset(x: railWidth * viewModel.currentStage.target - 2)
                    .shadow(color: .white.opacity(0.65), radius: 6)
            }
        }
        .position(x: size.width / 2, y: size.height * 0.82)
    }
}

private struct LunarIlluminationShape: Shape {
    var fraction: CGFloat
    var waxing: Bool

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let f = min(1, max(0, fraction))
        guard f > 0.01 else { return Path() }
        if f >= 0.99 { return Circle().path(in: rect) }

        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let top = CGPoint(x: c.x, y: c.y - r)
        let litRight = waxing
        let bulge = (f - 0.5) * 2
        let innerX = c.x - (litRight ? 1 : -1) * bulge * r

        var path = Path()
        path.move(to: top)
        path.addArc(
            center: c,
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: !litRight
        )
        path.addQuadCurve(to: top, control: CGPoint(x: innerX, y: c.y))
        path.closeSubpath()
        return path
    }
}

private struct EarthContinentShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
        }

        path.move(to: point(first))
        for index in points.indices.dropFirst() {
            let previous = point(points[index - 1])
            let current = point(points[index])
            let control = CGPoint(
                x: (previous.x + current.x) / 2 + (index.isMultiple(of: 2) ? 6 : -5),
                y: (previous.y + current.y) / 2 + (index.isMultiple(of: 3) ? -4 : 5)
            )
            path.addQuadCurve(to: current, control: control)
        }
        path.addQuadCurve(to: point(first), control: point(points[points.count / 2]))
        path.closeSubpath()
        return path
    }
}

private struct LunarSpaceBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.008, green: 0.01, blue: 0.025),
                    Color(red: 0.012, green: 0.018, blue: 0.052),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Canvas { context, size in
                for index in 0..<86 {
                    let x = CGFloat((index * 47) % 997) / 997 * size.width
                    let y = CGFloat((index * 83) % 991) / 991 * size.height
                    let opacity = 0.12 + Double((index * 17) % 9) / 68
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(.white.opacity(opacity)))
                }
            }
            .ignoresSafeArea()
        }
    }
}
