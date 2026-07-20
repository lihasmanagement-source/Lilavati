import AVFoundation
import SwiftUI

@Observable
final class MathItLevelTwelveViewModel {
    var completed = false
    var activeNodeID: Int?
    var dragPoint: CGPoint?
    var traversedEdgeIDs: Set<String> = []
    var playedEdgeIDs: [String] = []
    var recentEdgeID: String?
    var isTracing = false

    let nodes = [
        LevelTwelveNode(id: 0, position: CGPoint(x: 0.2, y: 0.28)),
        LevelTwelveNode(id: 1, position: CGPoint(x: 0.5, y: 0.12)),
        LevelTwelveNode(id: 2, position: CGPoint(x: 0.8, y: 0.28)),
        LevelTwelveNode(id: 3, position: CGPoint(x: 0.68, y: 0.74)),
        LevelTwelveNode(id: 4, position: CGPoint(x: 0.32, y: 0.74))
    ]

    let edges = [
        LevelTwelveEdge(from: 0, to: 1, frequency: 261.63),
        LevelTwelveEdge(from: 1, to: 2, frequency: 293.66),
        LevelTwelveEdge(from: 2, to: 3, frequency: 329.63),
        LevelTwelveEdge(from: 3, to: 4, frequency: 392.0),
        LevelTwelveEdge(from: 4, to: 0, frequency: 440.0),
        LevelTwelveEdge(from: 1, to: 3, frequency: 349.23),
        LevelTwelveEdge(from: 1, to: 4, frequency: 523.25)
    ]

    private let tonePlayer = LevelTwelveTonePlayer()
    private let nodeHitRadius: CGFloat = 34

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
            isTracing = false
        }
    }

    func begin(at point: CGPoint, nodePositions: [Int: CGPoint]) {
        guard !completed, let nodeID = nearestNode(to: point, nodePositions: nodePositions) else { return }
        resetAttempt(playHaptic: false)
        isTracing = true
        activeNodeID = nodeID
        dragPoint = nodePositions[nodeID]
    }

    func drag(to point: CGPoint, nodePositions: [Int: CGPoint]) {
        guard !completed, isTracing, let activeNodeID else { return }
        dragPoint = point

        guard let nextNodeID = nearestNode(to: point, nodePositions: nodePositions), nextNodeID != activeNodeID else { return }
        guard let edge = edgeBetween(activeNodeID, nextNodeID) else { return }
        guard !traversedEdgeIDs.contains(edge.id) else {
            resetAttempt()
            return
        }

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
        resetAttempt()
    }

    private func resetAttempt(playHaptic: Bool = true) {
        if playHaptic, isTracing || !traversedEdgeIDs.isEmpty {
            HapticPlayer.playLightTap()
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            activeNodeID = nil
            dragPoint = nil
            traversedEdgeIDs = []
            playedEdgeIDs = []
            recentEdgeID = nil
            isTracing = false
        }
    }

    private func checkCompletion() {
        guard traversedEdgeIDs.count == edges.count, !completed else { return }

        HapticPlayer.playCompletionTap()
        isTracing = false
        tonePlayer.playMelody(edges: playedEdgeIDs.compactMap { id in edges.first { $0.id == id } })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
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

    private func edgeBetween(_ first: Int, _ second: Int) -> LevelTwelveEdge? {
        edges.first { edge in
            (edge.from == first && edge.to == second) || (edge.from == second && edge.to == first)
        }
    }
}

struct LevelTwelveNode: Identifiable {
    let id: Int
    let position: CGPoint
}

struct LevelTwelveEdge: Identifiable, Hashable {
    let from: Int
    let to: Int
    let frequency: Double

    var id: String {
        "\(min(from, to))-\(max(from, to))"
    }
}

struct MathItLevelTwelveView: View {
    var viewModel: MathItLevelTwelveViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let graphFrame = CGRect(x: 16, y: size.height * 0.18, width: size.width - 32, height: size.height * 0.62)
            let nodePositions = Dictionary(uniqueKeysWithValues: viewModel.nodes.map { node in
                (node.id, CGPoint(x: graphFrame.minX + graphFrame.width * node.position.x, y: graphFrame.minY + graphFrame.height * node.position.y))
            })

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
                    .position(x: size.width / 2, y: 154)

                graph(nodePositions: nodePositions)

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
                    title: "Level 12 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if viewModel.activeNodeID == nil {
                            viewModel.begin(at: value.location, nodePositions: nodePositions)
                        } else {
                            viewModel.drag(to: value.location, nodePositions: nodePositions)
                        }
                    }
                    .onEnded { _ in
                        viewModel.endDrag()
                    }
            )
        }
    }

    private func graph(nodePositions: [Int: CGPoint]) -> some View {
        ZStack {
            ForEach(viewModel.edges) { edge in
                if let start = nodePositions[edge.from], let end = nodePositions[edge.to] {
                    edgeView(edge, from: start, to: end)
                }
            }

            ForEach(viewModel.nodes) { node in
                if let point = nodePositions[node.id] {
                    nodeView(nodeID: node.id)
                        .position(point)
                }
            }
        }
    }

    private func edgeView(_ edge: LevelTwelveEdge, from start: CGPoint, to end: CGPoint) -> some View {
        let isPlayed = viewModel.traversedEdgeIDs.contains(edge.id)
        let isRecent = viewModel.recentEdgeID == edge.id

        return ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(.white.opacity(isPlayed ? 0.82 : 0.24), style: StrokeStyle(lineWidth: isRecent ? 5 : 3, lineCap: .round))
            .shadow(color: .white.opacity(isRecent ? 0.62 : 0.12), radius: isRecent ? 16 : 6)
        }
    }

    private func nodeView(nodeID: Int) -> some View {
        let isActive = viewModel.activeNodeID == nodeID

        return Circle()
            .fill(.black)
            .frame(width: 34, height: 34)
            .overlay {
                Circle()
                    .stroke(.white.opacity(isActive ? 0.92 : 0.58), lineWidth: isActive ? 2.6 : 1.7)
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

private final class LevelTwelveTonePlayer {
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

    func playMelody(edges: [LevelTwelveEdge]) {
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
