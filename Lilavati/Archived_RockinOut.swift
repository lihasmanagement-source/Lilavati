import AVFoundation
import SwiftUI

@Observable
final class MathItLevelSixteenViewModel {
    private static let beatDuration = 60.0 / 130.0

    var currentBeat = -1
    var numberTiles: [LevelSixteenNumberTile] = [
        LevelSixteenNumberTile(value: 1),
        LevelSixteenNumberTile(value: 1)
    ]
    var operators: [LevelSixteenOperatorTile] = [
        LevelSixteenOperatorTile(kind: .plus),
        LevelSixteenOperatorTile(kind: .multiply),
        LevelSixteenOperatorTile(kind: .equals)
    ]
    var placedBeats: [LevelSixteenBeatSlot: UUID] = [:]
    var generatedSignatures: Set<String> = []
    var activeNumberGrabOffsets: [UUID: CGSize] = [:]
    var activeOperatorGrabOffsets: [UUID: CGSize] = [:]
    var didLayout = false
    var rhythmUnlocked = false
    var boxBroken = false
    var completed = false
    var rockPosition = CGPoint.zero
    var rockRotation: Angle = .zero
    var ballPosition = CGPoint.zero

    private let player = LevelSixteenRhythmPlayer()
    private var timer: Timer?

    deinit {
        stop()
    }

    var progress: Double {
        if completed { return 1 }
        return min(0.96, Double(placedBeats.count) / 3.0)
    }

    func prepareLayout(size: CGSize) {
        guard !didLayout else { return }
        didLayout = true

        let workY = size.height * 0.76
        let numberXs = [size.width * 0.17, size.width * 0.31]
        for index in numberTiles.indices {
            numberTiles[index].position = CGPoint(x: numberXs[index], y: workY)
        }

        let operatorXs = [size.width * 0.48, size.width * 0.64, size.width * 0.82]
        for index in operators.indices {
            operators[index].position = CGPoint(x: operatorXs[index], y: workY)
        }
    }

    func moveNumber(id: UUID, to absoluteLocation: CGPoint) {
        guard !completed, let index = numberTiles.firstIndex(where: { $0.id == id }) else { return }
        placedBeats = placedBeats.filter { $0.value != id }
        updateRhythmPattern()

        let current = numberTiles[index].position
        let grabOffset = activeNumberGrabOffsets[id] ?? CGSize(
            width: current.x - absoluteLocation.x,
            height: current.y - absoluteLocation.y
        )
        activeNumberGrabOffsets[id] = grabOffset
        numberTiles[index].position = CGPoint(
            x: absoluteLocation.x + grabOffset.width,
            y: absoluteLocation.y + grabOffset.height
        )
    }

    func finishMovingNumber(id: UUID, beatBoxes: [LevelSixteenBeatSlot: CGRect], bounds: CGSize) {
        activeNumberGrabOffsets[id] = nil
        guard let index = numberTiles.firstIndex(where: { $0.id == id }) else { return }
        let tile = numberTiles[index]

        if let slot = beatBoxes.first(where: { $0.value.insetBy(dx: -14, dy: -16).contains(tile.position) }) {
            if tile.value == expectedValue(for: slot.key) {
                HapticPlayer.playLightTap()
                placedBeats[slot.key] = id
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    numberTiles[index].position = CGPoint(x: slot.value.midX, y: slot.value.midY)
                }
                updateRhythmPattern()
                checkRhythmCompletion(bounds: bounds)
            } else {
                HapticPlayer.playLightTap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    numberTiles[index].position = clampedPoint(
                        CGPoint(x: tile.position.x, y: bounds.height * 0.76),
                        in: bounds
                    )
                }
            }
            return
        }

        snapExpression(draggedID: id, bounds: bounds)
    }

    func moveOperator(id: UUID, to absoluteLocation: CGPoint, bounds: CGSize) {
        guard !completed, let index = operators.firstIndex(where: { $0.id == id }) else { return }

        let current = operators[index].position
        let grabOffset = activeOperatorGrabOffsets[id] ?? CGSize(
            width: current.x - absoluteLocation.x,
            height: current.y - absoluteLocation.y
        )
        activeOperatorGrabOffsets[id] = grabOffset
        operators[index].position = clampedPoint(
            CGPoint(x: absoluteLocation.x + grabOffset.width, y: absoluteLocation.y + grabOffset.height),
            in: bounds
        )
    }

    func finishMovingOperator(id: UUID, bounds: CGSize) {
        activeOperatorGrabOffsets[id] = nil
        snapExpression(draggedID: id, bounds: bounds)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentBeat = -1
        player.stop()
    }

    private func checkRhythmCompletion(bounds: CGSize) {
        guard !rhythmUnlocked, placedBeats.count == 3 else { return }
        guard tileValue(in: LevelSixteenBeatSlot(track: .stomp, beat: 0)) == 1,
              tileValue(in: LevelSixteenBeatSlot(track: .stomp, beat: 1)) == 2,
              tileValue(in: LevelSixteenBeatSlot(track: .clap, beat: 2)) == 3 else { return }
        rhythmUnlocked = true
        animateEscape(bounds: bounds)
    }

    private func updateRhythmPattern() {
        let stompBeats = Set(placedBeats.keys.filter { $0.track == .stomp }.map(\.beat))
        let clapBeats = Set(placedBeats.keys.filter { $0.track == .clap }.map(\.beat))
        player.setPattern(stompBeats: stompBeats, clapBeats: clapBeats)
        if stompBeats.isEmpty && clapBeats.isEmpty {
            stop()
        } else {
            startRhythmIfNeeded()
        }
    }

    private func startRhythmIfNeeded() {
        guard timer == nil else { return }
        currentBeat = 0
        player.start()
        player.playBeat(0)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.beatDuration, repeats: true) { [weak self] _ in
            guard let self else { return }
            let nextBeat = (self.currentBeat + 1) % 4
            withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
                self.currentBeat = nextBeat
            }
            self.player.playBeat(nextBeat)
        }
    }

    private func tileValue(in slot: LevelSixteenBeatSlot) -> Int? {
        guard let id = placedBeats[slot] else { return nil }
        return numberTiles.first(where: { $0.id == id })?.value
    }

    private func expectedValue(for slot: LevelSixteenBeatSlot) -> Int {
        slot.beat + 1
    }

    private func animateEscape(bounds: CGSize) {
        HapticPlayer.playCompletionTap()
        let boxCenter = CGPoint(x: bounds.width - 76, y: bounds.height * 0.21)
        let rockStart = CGPoint(x: boxCenter.x - 82, y: boxCenter.y + 2)
        rockPosition = rockStart
        ballPosition = boxCenter

        withAnimation(.easeInOut(duration: 0.46)) {
            rockPosition = CGPoint(x: boxCenter.x - 18, y: boxCenter.y)
            rockRotation = .degrees(92)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            self.boxBroken = true
            self.hopBallAway(from: boxCenter)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    private func hopBallAway(from start: CGPoint) {
        let hops: [(Double, CGPoint)] = [
            (0.00, CGPoint(x: start.x - 30, y: start.y - 30)),
            (0.34, CGPoint(x: start.x - 62, y: start.y + 10)),
            (0.68, CGPoint(x: start.x - 106, y: start.y - 26)),
            (1.05, CGPoint(x: start.x - 158, y: start.y + 14)),
            (1.46, CGPoint(x: -34, y: start.y - 10))
        ]

        for hop in hops {
            DispatchQueue.main.asyncAfter(deadline: .now() + hop.0) {
                withAnimation(.easeInOut(duration: 0.32)) {
                    self.ballPosition = hop.1
                }
            }
        }
    }

    private func snapExpression(draggedID: UUID, bounds: CGSize) {
        let nodes = expressionNodes
        guard let dragged = nodes.first(where: { $0.id == draggedID }) else { return }
        let cluster = connectedCluster(containing: dragged, in: nodes)
        guard cluster.count > 1 else { return }

        let sortedCluster = cluster.sorted { $0.position.x < $1.position.x }
        let spacing: CGFloat = 58
        let centerX = sortedCluster.map(\.position.x).reduce(0, +) / CGFloat(sortedCluster.count)
        let centerY = sortedCluster.map(\.position.y).reduce(0, +) / CGFloat(sortedCluster.count)
        let leftX = centerX - CGFloat(sortedCluster.count - 1) * spacing / 2
        let targets = boundedLinePositions(count: sortedCluster.count, leftX: leftX, centerY: centerY, spacing: spacing, bounds: bounds)

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            for (index, node) in sortedCluster.enumerated() {
                setPosition(targets[index], for: node)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.createResult(from: sortedCluster, bounds: bounds)
        }
    }

    private var expressionNodes: [LevelSixteenExpressionNode] {
        let numberNodes = numberTiles
            .filter { tile in !placedBeats.values.contains(tile.id) }
            .map { LevelSixteenExpressionNode(id: $0.id, kind: .number($0.value), position: $0.position) }
        let operatorNodes = operators.map { LevelSixteenExpressionNode(id: $0.id, kind: .operation($0.kind), position: $0.position) }
        return numberNodes + operatorNodes
    }

    private func connectedCluster(containing dragged: LevelSixteenExpressionNode, in nodes: [LevelSixteenExpressionNode]) -> [LevelSixteenExpressionNode] {
        var cluster = [dragged]
        var changed = true

        while changed {
            changed = false
            for node in nodes where !cluster.contains(where: { $0.id == node.id }) {
                if cluster.contains(where: { canSnap($0.position, node.position) }) {
                    cluster.append(node)
                    changed = true
                }
            }
        }

        return cluster
    }

    private func createResult(from cluster: [LevelSixteenExpressionNode], bounds: CGSize) {
        let sorted = cluster.sorted { $0.position.x < $1.position.x }
        guard sorted.count == 4 else { return }
        guard case .number(let left) = sorted[0].kind,
              case .operation(let operation) = sorted[1].kind,
              case .number(let right) = sorted[2].kind,
              case .operation(.equals) = sorted[3].kind else { return }

        let result: Int
        switch operation {
        case .plus:
            result = left + right
        case .multiply:
            result = left * right
        case .equals:
            return
        }

        guard (1...4).contains(result) else { return }
        let signature = sorted.map { "\($0.id.uuidString)@\(Int($0.position.x.rounded())),\(Int($0.position.y.rounded()))" }.joined(separator: "|") + "=\(result)"
        guard !generatedSignatures.contains(signature) else { return }
        generatedSignatures.insert(signature)

        let resultPosition = clampedPoint(CGPoint(x: sorted[3].position.x + 66, y: sorted[3].position.y), in: bounds)
        numberTiles.append(LevelSixteenNumberTile(value: result, position: sorted[3].position))
        withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
            if let index = numberTiles.indices.last {
                numberTiles[index].position = resultPosition
            }
        }
    }

    private func setPosition(_ position: CGPoint, for node: LevelSixteenExpressionNode) {
        switch node.kind {
        case .number:
            guard let index = numberTiles.firstIndex(where: { $0.id == node.id }) else { return }
            numberTiles[index].position = position
        case .operation:
            guard let index = operators.firstIndex(where: { $0.id == node.id }) else { return }
            operators[index].position = position
        }
    }

    private func canSnap(_ first: CGPoint, _ second: CGPoint) -> Bool {
        abs(first.y - second.y) <= 78 && abs(first.x - second.x) <= 104
    }

    private func boundedLinePositions(count: Int, leftX: CGFloat, centerY: CGFloat, spacing: CGFloat, bounds: CGSize) -> [CGPoint] {
        let width = CGFloat(count - 1) * spacing
        let minLeft: CGFloat = 40
        let maxLeft = max(minLeft, bounds.width - 40 - width)
        let boundedLeft = min(max(leftX, minLeft), maxLeft)
        let boundedY = min(max(centerY, 140), max(140, bounds.height - 72))
        return (0..<count).map { CGPoint(x: boundedLeft + CGFloat($0) * spacing, y: boundedY) }
    }

    private func clampedPoint(_ point: CGPoint, in bounds: CGSize, margin: CGFloat = 36) -> CGPoint {
        CGPoint(
            x: min(max(point.x, margin), max(margin, bounds.width - margin)),
            y: min(max(point.y, margin), max(margin, bounds.height - margin))
        )
    }
}

struct MathItLevelSixteenView: View {
    var viewModel: MathItLevelSixteenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let laneWidth = min(size.width * 0.72, 330)
            let beatSpacing = laneWidth / 4
            let stompCenter = CGPoint(x: size.width / 2, y: size.height * 0.31)
            let clapCenter = CGPoint(x: size.width / 2, y: size.height * 0.43)
            let boxFrame = CGRect(x: size.width - 112, y: size.height * 0.21 - 40, width: 76, height: 80)
            let rockHome = CGPoint(x: boxFrame.minX - 44, y: boxFrame.midY + 2)
            let beatBoxes = beatBoxFrames(laneWidth: laneWidth, beatSpacing: beatSpacing, stompCenter: stompCenter, clapCenter: clapCenter)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    Text("rockin' out")
                        .font(.trajan(36))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                }
                .position(x: size.width / 2, y: 74)

                ProgressView(value: viewModel.progress)
                    .tint(.white)
                    .opacity(0.72)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 128)

                lockBox(frame: boxFrame, rockHome: rockHome)

                rhythmTracks(laneWidth: laneWidth, beatSpacing: beatSpacing, stompCenter: stompCenter, clapCenter: clapCenter, beatBoxes: beatBoxes)

                mathWorkBand(size: size)

                ForEach(viewModel.numberTiles) { tile in
                    numberTile(tile, beatBoxes: beatBoxes, bounds: size)
                }

                ForEach(viewModel.operators) { tile in
                    operatorTile(tile, bounds: size)
                }

                CompletionOverlay(
                    title: "Level 16 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .onAppear {
                viewModel.prepareLayout(size: size)
                if viewModel.ballPosition == .zero {
                    viewModel.ballPosition = CGPoint(x: boxFrame.midX, y: boxFrame.midY)
                }
                if viewModel.rockPosition == .zero {
                    viewModel.rockPosition = rockHome
                }
            }
            .onDisappear {
                viewModel.stop()
            }
            .coordinateSpace(name: "levelSixteenStage")
        }
    }

    private func beatBoxFrames(laneWidth: CGFloat, beatSpacing: CGFloat, stompCenter: CGPoint, clapCenter: CGPoint) -> [LevelSixteenBeatSlot: CGRect] {
        var boxes: [LevelSixteenBeatSlot: CGRect] = [:]
        for track in [LevelSixteenTrack.stomp, .clap] {
            let center = track == .stomp ? stompCenter : clapCenter
            for beat in 0..<4 {
                boxes[LevelSixteenBeatSlot(track: track, beat: beat)] = CGRect(
                    x: center.x - laneWidth / 2 + CGFloat(beat) * beatSpacing + beatSpacing / 2 - 22,
                    y: center.y + 32,
                    width: 44,
                    height: 38
                )
            }
        }
        return boxes
    }

    private func rhythmTracks(laneWidth: CGFloat, beatSpacing: CGFloat, stompCenter: CGPoint, clapCenter: CGPoint, beatBoxes: [LevelSixteenBeatSlot: CGRect]) -> some View {
        ZStack {
            rhythmTrack(track: .stomp, laneWidth: laneWidth, beatSpacing: beatSpacing, center: stompCenter, beatBoxes: beatBoxes)
            rhythmTrack(track: .clap, laneWidth: laneWidth, beatSpacing: beatSpacing, center: clapCenter, beatBoxes: beatBoxes)
        }
    }

    private func rhythmTrack(track: LevelSixteenTrack, laneWidth: CGFloat, beatSpacing: CGFloat, center: CGPoint, beatBoxes: [LevelSixteenBeatSlot: CGRect]) -> some View {
        ZStack {
            Text(track.label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 56, alignment: .leading)
                .position(x: center.x - laneWidth / 2 - 39, y: center.y)

            Capsule()
                .fill(.white.opacity(0.14))
                .frame(width: laneWidth, height: 4)
                .position(center)

            ForEach(0..<4, id: \.self) { beat in
                let x = center.x - laneWidth / 2 + CGFloat(beat) * beatSpacing + beatSpacing / 2
                let slot = LevelSixteenBeatSlot(track: track, beat: beat)
                let isSoundBeat = viewModel.placedBeats[slot] != nil
                let isPlayingNow = viewModel.currentBeat == beat

                Circle()
                    .fill(isSoundBeat ? .white.opacity(isPlayingNow ? 0.94 : 0.52) : .black)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(isSoundBeat ? 0.82 : 0.28), lineWidth: 1.4)
                    }
                    .frame(width: isPlayingNow && isSoundBeat ? 34 : 27, height: isPlayingNow && isSoundBeat ? 34 : 27)
                    .shadow(color: .white.opacity(isPlayingNow && isSoundBeat ? 0.64 : 0.08), radius: isPlayingNow && isSoundBeat ? 18 : 4)
                    .position(x: x, y: center.y)

                if let beatBox = beatBoxes[slot] {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.42), style: StrokeStyle(lineWidth: 1.4, dash: [7, 5]))
                        .frame(width: beatBox.width, height: beatBox.height)
                        .position(x: beatBox.midX, y: beatBox.midY)
                }
            }
        }
    }

    private func mathWorkBand(size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 34, y: size.height * 0.62))
                path.addLine(to: CGPoint(x: size.width - 34, y: size.height * 0.62))
            }
            .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [7, 10]))
        }
    }

    private func lockBox(frame: CGRect, rockHome: CGPoint) -> some View {
        ZStack {
            if viewModel.boxBroken {
                boxShard(offset: CGSize(width: -24, height: -20), rotation: .degrees(-26))
                    .position(x: frame.midX - 11, y: frame.midY - 7)
                boxShard(offset: CGSize(width: 25, height: -18), rotation: .degrees(28))
                    .position(x: frame.midX + 12, y: frame.midY - 7)
                boxShard(offset: CGSize(width: -20, height: 24), rotation: .degrees(18))
                    .position(x: frame.midX - 9, y: frame.midY + 15)
                boxShard(offset: CGSize(width: 22, height: 24), rotation: .degrees(-20))
                    .position(x: frame.midX + 11, y: frame.midY + 16)
            } else {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.white.opacity(0.66), style: StrokeStyle(lineWidth: 2, dash: [8, 7]))
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }

            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
                .shadow(color: .white.opacity(0.72), radius: 14)
                .position(viewModel.ballPosition == .zero ? CGPoint(x: frame.midX, y: frame.midY) : viewModel.ballPosition)

            rock()
                .rotationEffect(viewModel.rockRotation)
                .position(viewModel.rockPosition == .zero ? rockHome : viewModel.rockPosition)
        }
    }

    private func rock() -> some View {
        UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 12, bottomLeading: 18, bottomTrailing: 10, topTrailing: 16))
            .fill(.gray.opacity(0.72))
            .overlay {
                UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 12, bottomLeading: 18, bottomTrailing: 10, topTrailing: 16))
                    .stroke(.white.opacity(0.42), lineWidth: 1.4)
            }
            .frame(width: 34, height: 30)
            .shadow(color: .white.opacity(0.12), radius: 8)
    }

    private func boxShard(offset: CGSize, rotation: Angle) -> some View {
        Rectangle()
            .stroke(.white.opacity(0.66), lineWidth: 2)
            .frame(width: 32, height: 2)
            .rotationEffect(rotation)
            .offset(offset)
    }

    private func numberTile(_ tile: LevelSixteenNumberTile, beatBoxes: [LevelSixteenBeatSlot: CGRect], bounds: CGSize) -> some View {
        Text("\(tile.value)")
            .font(.trajan(54))
            .foregroundStyle(.white.opacity(0.9))
            .shadow(color: Color.mathGold.opacity(0.5), radius: 12)
            .frame(width: 62, height: 70)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .named("levelSixteenStage"))
                    .onChanged { value in
                        viewModel.moveNumber(id: tile.id, to: value.location)
                    }
                    .onEnded { _ in
                        viewModel.finishMovingNumber(id: tile.id, beatBoxes: beatBoxes, bounds: bounds)
                    }
            )
            .position(tile.position)
            .zIndex(8)
    }

    private func operatorTile(_ tile: LevelSixteenOperatorTile, bounds: CGSize) -> some View {
        Text(tile.kind.display)
            .font(.trajan(50))
            .foregroundStyle(.white.opacity(0.86))
            .shadow(color: .white.opacity(0.28), radius: 10)
            .frame(width: 64, height: 70)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .named("levelSixteenStage"))
                    .onChanged { value in
                        viewModel.moveOperator(id: tile.id, to: value.location, bounds: bounds)
                    }
                    .onEnded { _ in
                        viewModel.finishMovingOperator(id: tile.id, bounds: bounds)
                    }
            )
            .position(tile.position)
            .zIndex(7)
    }
}

struct LevelSixteenNumberTile: Identifiable {
    let id: UUID
    var value: Int
    var position: CGPoint

    init(id: UUID = UUID(), value: Int, position: CGPoint = .zero) {
        self.id = id
        self.value = value
        self.position = position
    }
}

struct LevelSixteenOperatorTile: Identifiable {
    let id = UUID()
    let kind: LevelSixteenOperatorKind
    var position = CGPoint.zero
}

struct LevelSixteenBeatSlot: Hashable {
    let track: LevelSixteenTrack
    let beat: Int
}

enum LevelSixteenTrack: Hashable {
    case stomp
    case clap

    var label: String {
        switch self {
        case .stomp:
            "STOMP"
        case .clap:
            "CLAP"
        }
    }
}

private struct LevelSixteenExpressionNode {
    let id: UUID
    let kind: LevelSixteenExpressionKind
    let position: CGPoint
}

private enum LevelSixteenExpressionKind {
    case number(Int)
    case operation(LevelSixteenOperatorKind)
}

enum LevelSixteenOperatorKind {
    case plus
    case multiply
    case equals

    var display: String {
        switch self {
        case .plus:
            "+"
        case .multiply:
            "×"
        case .equals:
            "="
        }
    }
}

private final class LevelSixteenRhythmPlayer {
    private let engine = AVAudioEngine()
    private let stompNode = AVAudioPlayerNode()
    private let clapNode = AVAudioPlayerNode()
    private let lock = NSLock()
    private var stompBeats: Set<Int> = []
    private var clapBeats: Set<Int> = []
    private var stompFile: AVAudioFile?
    private var clapFile: AVAudioFile?

    init() {
        if let stompURL = Bundle.main.url(forResource: "LevelSixteenStomp", withExtension: "wav") {
            stompFile = try? AVAudioFile(forReading: stompURL)
        }
        if let clapURL = Bundle.main.url(forResource: "LevelSixteenClap", withExtension: "wav") {
            clapFile = try? AVAudioFile(forReading: clapURL)
        }

        engine.attach(stompNode)
        engine.attach(clapNode)
        engine.connect(stompNode, to: engine.mainMixerNode, format: stompFile?.processingFormat)
        engine.connect(clapNode, to: engine.mainMixerNode, format: clapFile?.processingFormat)
    }

    func start() {
        if !engine.isRunning {
            try? engine.start()
        }
    }

    func setPattern(stompBeats: Set<Int>, clapBeats: Set<Int>) {
        lock.lock()
        self.stompBeats = stompBeats
        self.clapBeats = clapBeats
        lock.unlock()
    }

    func stop() {
        stompNode.stop()
        clapNode.stop()
        engine.stop()
    }

    func playBeat(_ beat: Int) {
        lock.lock()
        let shouldStomp = stompBeats.contains(beat)
        let shouldClap = clapBeats.contains(beat)
        lock.unlock()

        if shouldStomp {
            playSample(stompFile, on: stompNode, startSeconds: 0.0, durationSeconds: 0.62)
        }
        if shouldClap {
            playSample(clapFile, on: clapNode, startSeconds: 0.0, durationSeconds: 0.46)
        }
    }

    private func playSample(_ sampleFile: AVAudioFile?, on node: AVAudioPlayerNode, startSeconds: Double, durationSeconds: Double) {
        guard let sampleFile else { return }
        if !engine.isRunning {
            try? engine.start()
        }

        let sampleRate = sampleFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(startSeconds * sampleRate)
        let requestedFrames = AVAudioFrameCount(durationSeconds * sampleRate)
        let availableFrames = max(0, sampleFile.length - startFrame)
        let frameCount = min(requestedFrames, AVAudioFrameCount(availableFrames))
        guard frameCount > 0 else { return }

        node.stop()
        node.scheduleSegment(sampleFile, startingFrame: startFrame, frameCount: frameCount, at: nil)
        node.play()
    }
}
