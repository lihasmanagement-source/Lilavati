import AVFoundation
import SwiftUI

@Observable
final class MathItLevelThirteenViewModel {
    var completed = false
    var activeNodeID: Int?
    var dragPoint: CGPoint?
    var traversedEdgeIDs: Set<String> = []
    var playedEdgeIDs: [String] = []
    var recentEdgeID: String?
    var rotationY: CGFloat = -0.48
    var autoRotationStartDate = Date()
    private let autoRotationSpeed: CGFloat = 0.22

    let nodes = [
        LevelThirteenNode(id: 0, point: LevelThirteenPoint3D(x: -0.58, y: -0.42, z: -0.58)),
        LevelThirteenNode(id: 1, point: LevelThirteenPoint3D(x: 0.58, y: -0.42, z: -0.58)),
        LevelThirteenNode(id: 2, point: LevelThirteenPoint3D(x: 0.58, y: -0.42, z: 0.58)),
        LevelThirteenNode(id: 3, point: LevelThirteenPoint3D(x: -0.58, y: -0.42, z: 0.58)),
        LevelThirteenNode(id: 4, point: LevelThirteenPoint3D(x: 0, y: 0.66, z: 0))
    ]

    let edges = [
        LevelThirteenEdge(from: 0, to: 1, frequency: 261.63),
        LevelThirteenEdge(from: 1, to: 2, frequency: 293.66),
        LevelThirteenEdge(from: 2, to: 3, frequency: 329.63),
        LevelThirteenEdge(from: 3, to: 0, frequency: 349.23),
        LevelThirteenEdge(from: 0, to: 4, frequency: 392.0),
        LevelThirteenEdge(from: 1, to: 4, frequency: 440.0),
        LevelThirteenEdge(from: 2, to: 4, frequency: 493.88),
        LevelThirteenEdge(from: 3, to: 4, frequency: 523.25),
        LevelThirteenEdge(from: 0, to: 2, frequency: 587.33),
        LevelThirteenEdge(from: 1, to: 3, frequency: 659.25)
    ]

    private let tonePlayer = LevelThirteenTonePlayer()
    private let nodeHitRadius: CGFloat = 36

    var progress: Double {
        if completed { return 1 }
        return Double(traversedEdgeIDs.count) / Double(edges.count)
    }

    func reset() {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            completed = false
            activeNodeID = nil
            dragPoint = nil
            traversedEdgeIDs = []
            playedEdgeIDs = []
            recentEdgeID = nil
            autoRotationStartDate = Date()
        }
    }

    func rotate(by translation: CGSize) {
        guard activeNodeID == nil, !completed else { return }
        rotationY += translation.width * 0.006
    }

    func rotation(at date: Date) -> CGFloat {
        guard !completed else { return rotationY }
        return rotationY + CGFloat(date.timeIntervalSince(autoRotationStartDate)) * autoRotationSpeed
    }

    func begin(at point: CGPoint, nodePositions: [Int: CGPoint]) -> Bool {
        guard !completed, let nodeID = nearestNode(to: point, nodePositions: nodePositions) else { return false }
        activeNodeID = nodeID
        dragPoint = nodePositions[nodeID]
        return true
    }

    func drag(to point: CGPoint, nodePositions: [Int: CGPoint]) {
        guard !completed, let activeNodeID else { return }
        dragPoint = point

        guard let nextNodeID = nearestNode(to: point, nodePositions: nodePositions), nextNodeID != activeNodeID else { return }
        guard let edge = edgeBetween(activeNodeID, nextNodeID), !traversedEdgeIDs.contains(edge.id) else { return }

        HapticPlayer.playLightTap()
        tonePlayer.play(frequency: edge.frequency)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            traversedEdgeIDs.insert(edge.id)
            playedEdgeIDs.append(edge.id)
            recentEdgeID = edge.id
            self.activeNodeID = nextNodeID
            dragPoint = nodePositions[nextNodeID]
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.recentEdgeID == edge.id {
                self.recentEdgeID = nil
            }
        }

        checkCompletion()
    }

    func endDrag() {
        guard !completed else { return }
        activeNodeID = nil
        dragPoint = nil
    }

    private func checkCompletion() {
        guard traversedEdgeIDs.count == edges.count, !completed else { return }

        HapticPlayer.playCompletionTap()
        tonePlayer.playMelody(edges: playedEdgeIDs.compactMap { id in edges.first { $0.id == id } })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                self.completed = true
                self.activeNodeID = nil
                self.dragPoint = nil
            }
        }
    }

    private func nearestNode(to point: CGPoint, nodePositions: [Int: CGPoint]) -> Int? {
        nodePositions.min {
            hypot(point.x - $0.value.x, point.y - $0.value.y) < hypot(point.x - $1.value.x, point.y - $1.value.y)
        }.flatMap { hypot(point.x - $0.value.x, point.y - $0.value.y) <= nodeHitRadius ? $0.key : nil }
    }

    private func edgeBetween(_ first: Int, _ second: Int) -> LevelThirteenEdge? {
        edges.first { edge in
            (edge.from == first && edge.to == second) || (edge.from == second && edge.to == first)
        }
    }
}

struct LevelThirteenPoint3D {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

struct LevelThirteenNode: Identifiable {
    let id: Int
    let point: LevelThirteenPoint3D
}

struct LevelThirteenEdge: Identifiable, Hashable {
    let from: Int
    let to: Int
    let frequency: Double

    var id: String {
        "\(min(from, to))-\(max(from, to))"
    }
}

struct MathItLevelThirteenView: View {
    var viewModel: MathItLevelThirteenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void
    var showsMusicGraphFollowUp = true
    var completionTitle = "Stage 1 · Graph Traced"
    var stageLabel: String? = nil
    var progressBase = 0.0
    var progressScale = 1.0

    @State private var isConnecting = false
    @State private var previousRotationTranslation = CGSize.zero
    @State private var stage = 1
    @State private var musicGraphViewModel = MathItLevelTwelveViewModel()

    var body: some View {
        ZStack {
            if stage == 1 {
                pyramidStage
                    .transition(.opacity)
            } else {
                // Stage 2 — the music graph, hosted inside the pyramid level.
                MathItLevelTwelveView(
                    viewModel: musicGraphViewModel,
                    onContinue: onContinue,
                    onReplay: { musicGraphViewModel = MathItLevelTwelveViewModel() },
                    onLevelSelect: onLevelSelect
                )
                .id(ObjectIdentifier(musicGraphViewModel))
                .transition(.opacity)
            }
        }
    }

    private var pyramidStage: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation) { timeline in
                let graphCenter = CGPoint(x: size.width / 2, y: size.height * 0.48)
                let graphScale = min(size.width * 0.43, size.height * 0.3)
                let rotationY = viewModel.rotation(at: timeline.date)
                let projections = Dictionary(uniqueKeysWithValues: viewModel.nodes.map { node in
                    (node.id, project(node.point, center: graphCenter, scale: graphScale, rotationY: rotationY))
                })
                let nodePositions = projections.mapValues(\.point)

                ZStack {
                    HomeButton(action: onLevelSelect)
                        .position(x: 34, y: 54)

                    VStack(spacing: 10) {
                        if let stageLabel {
                            Text(stageLabel)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .tracking(4)
                                .foregroundStyle(Color.mathGold.opacity(0.85))
                        }

                        EmptyView()
                            .font(.trajan(36))
                            .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                    }
                    .position(x: size.width / 2, y: 86)

                    ProgressView(value: progressBase + viewModel.progress * progressScale)
                        .tint(.white)
                        .opacity(0.72)
                        .padding(.horizontal, 34)
                        .position(x: size.width / 2, y: 154)

                    pyramid(projections: projections)

                    if let activeNodeID = viewModel.activeNodeID, let dragPoint = viewModel.dragPoint, let start = nodePositions[activeNodeID] {
                        Path { path in
                            path.move(to: start)
                            path.addLine(to: dragPoint)
                        }
                        .stroke(.white.opacity(0.34), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .shadow(color: .white.opacity(0.22), radius: 8)
                    }

                    resetButton
                        .position(x: size.width / 2, y: size.height * 0.84)

                    CompletionOverlay(
                        title: completionTitle,
                        isVisible: viewModel.completed,
                        onContinue: {
                            if showsMusicGraphFollowUp {
                                withAnimation(.easeInOut(duration: 0.4)) { stage = 2 }
                            } else {
                                onContinue()
                            }
                        },
                        onReplay: onReplay,
                        onLevelSelect: onLevelSelect
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if viewModel.activeNodeID != nil {
                                viewModel.drag(to: value.location, nodePositions: nodePositions)
                                return
                            }

                            if !isConnecting {
                                isConnecting = viewModel.begin(at: value.location, nodePositions: nodePositions)
                                if isConnecting {
                                    previousRotationTranslation = value.translation
                                    return
                                }
                            }

                            let delta = CGSize(
                                width: value.translation.width - previousRotationTranslation.width,
                                height: value.translation.height - previousRotationTranslation.height
                            )
                            viewModel.rotate(by: delta)
                            previousRotationTranslation = value.translation
                        }
                        .onEnded { _ in
                            viewModel.endDrag()
                            isConnecting = false
                            previousRotationTranslation = .zero
                        }
                )
            }
        }
    }

    private func project(_ point: LevelThirteenPoint3D, center: CGPoint, scale: CGFloat, rotationY: CGFloat) -> LevelThirteenProjection {
        let cosine = cos(rotationY)
        let sine = sin(rotationY)
        let rotatedX = point.x * cosine - point.z * sine
        let rotatedZ = point.x * sine + point.z * cosine
        let tilt: CGFloat = 0.58
        let tiltedY = point.y * tilt - rotatedZ * 0.34
        let tiltedZ = point.y * 0.28 + rotatedZ * tilt
        let perspective = 1.35 / (1.35 + rotatedZ * 0.36)
        let projected = CGPoint(
            x: center.x + rotatedX * scale * perspective,
            y: center.y - tiltedY * scale * perspective
        )
        return LevelThirteenProjection(point: projected, depth: tiltedZ)
    }

    private func pyramid(projections: [Int: LevelThirteenProjection]) -> some View {
        ZStack {
            ForEach(viewModel.edges.sorted { averageDepth($0, projections: projections) < averageDepth($1, projections: projections) }) { edge in
                if let start = projections[edge.from], let end = projections[edge.to] {
                    edgeView(edge, from: start, to: end)
                }
            }

            ForEach(viewModel.nodes.sorted { (projections[$0.id]?.depth ?? 0) < (projections[$1.id]?.depth ?? 0) }) { node in
                if let projection = projections[node.id] {
                    nodeView(nodeID: node.id, depth: projection.depth)
                        .position(projection.point)
                }
            }
        }
    }

    private func averageDepth(_ edge: LevelThirteenEdge, projections: [Int: LevelThirteenProjection]) -> CGFloat {
        ((projections[edge.from]?.depth ?? 0) + (projections[edge.to]?.depth ?? 0)) / 2
    }

    private func edgeView(_ edge: LevelThirteenEdge, from start: LevelThirteenProjection, to end: LevelThirteenProjection) -> some View {
        let isPlayed = viewModel.traversedEdgeIDs.contains(edge.id)
        let isRecent = viewModel.recentEdgeID == edge.id
        let depthOpacity = 0.24 + Double(max(start.depth, end.depth) + 0.7) * 0.16

        return Path { path in
            path.move(to: start.point)
            path.addLine(to: end.point)
        }
        .stroke(.white.opacity(isPlayed ? 0.84 : min(0.58, max(0.18, depthOpacity))), style: StrokeStyle(lineWidth: isRecent ? 5 : 3, lineCap: .round))
        .shadow(color: .white.opacity(isRecent ? 0.62 : 0.1), radius: isRecent ? 16 : 6)
    }

    private func nodeView(nodeID: Int, depth: CGFloat) -> some View {
        let isActive = viewModel.activeNodeID == nodeID
        let size = 32 + max(0, depth) * 4

        return Circle()
            .fill(.black)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(.white.opacity(isActive ? 0.92 : 0.54 + Double(max(0, depth)) * 0.18), lineWidth: isActive ? 2.6 : 1.7)
            }
            .shadow(color: .white.opacity(isActive ? 0.42 : 0.12), radius: isActive ? 14 : 6)
            .contentShape(Circle())
    }

    private var resetButton: some View {
        Button(action: viewModel.reset) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset")
    }
}

struct LevelThirteenProjection {
    let point: CGPoint
    let depth: CGFloat
}

private final class LevelThirteenTonePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
        player.play()
    }

    func play(frequency: Double) {
        guard let buffer = makeBuffer(frequency: frequency, duration: 0.16) else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(buffer, at: nil)
    }

    func playMelody(edges: [LevelThirteenEdge]) {
        for (index, edge) in edges.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.09) {
                self.play(frequency: edge.frequency)
            }
        }
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    private func makeBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = min(1, Double(frame) / 600) * min(1, Double(Int(frameCount) - frame) / 1200)
            channel[frame] = Float(sin(2 * .pi * frequency * time) * 0.18 * envelope)
        }
        return buffer
    }
}
