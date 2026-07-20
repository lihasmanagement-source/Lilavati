import SwiftUI
import Combine
import AVFoundation

struct MathItEchoCanyonGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var audio = EchoCanyonAudio()
    @State private var mirrorAngles: [Double] = [30, 30, 0]
    @State private var pulsePath: [CGPoint] = []
    @State private var echoActive = false
    @State private var echoPhase: Double = 0
    @State private var echoCycle = 0
    @State private var completed = false
    @State private var hitPulse = false
    @State private var missPulse = false

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let source = CGPoint(x: 0.17, y: 0.46)
    private let receiver = CGPoint(x: 0.82, y: 0.2)
    private let mirrorCenters = [
        CGPoint(x: 0.44, y: 0.23),
        CGPoint(x: 0.66, y: 0.58),
        CGPoint(x: 0.38, y: 0.78)
    ]
    private let solutionAngles = [0.0, 60.0, -30.0]
    private let angleOptions = [-60.0, -30.0, 0.0, 30.0, 60.0]
    private let mirrorLength: CGFloat = 0.15

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 12) {
                    VStack(spacing: 7) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(36))
                            .tracking(2)
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))
                    }
                    .padding(.horizontal, 58)

                    canyonField
                        .frame(height: min(560, proxy.size.height * 0.7))
                        .padding(.horizontal, 18)

                    HStack(spacing: 12) {
                        Button(action: testPulse) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(accent, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: reset) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(accent)
                                .frame(width: 58, height: 48)
                                .background(.black.opacity(0.72), in: Capsule())
                                .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.top, 38)
                .padding(.bottom, 76)

                CompletionOverlay(
                    title: "Level \(concept.number) Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .onReceive(tick) { _ in
                stepEcho()
            }
        }
    }

    private var canyonField: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.1), Color(red: 0.01, green: 0.012, blue: 0.018), .black],
                            center: .center,
                            startRadius: 40,
                            endRadius: max(size.width, size.height) * 0.7
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))

                Canvas { canvas, size in
                    drawCanyon(canvas: &canvas, size: size)
                    drawPulsePath(canvas: &canvas, size: size)
                }

                ForEach(0..<mirrorCenters.count, id: \.self) { index in
                    Button(action: { rotateMirror(index) }) {
                        Rectangle()
                            .fill(.white.opacity(0.88))
                            .frame(width: mirrorLength * size.width, height: 7)
                            .shadow(color: accent.opacity(0.55), radius: 10)
                            .overlay(Rectangle().stroke(.black.opacity(0.32), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .rotationEffect(.degrees(mirrorAngles[index]))
                    .position(point(mirrorCenters[index], in: size))
                }

                sourceNode
                    .position(point(source, in: size))

                receiverNode
                    .position(point(receiver, in: size))
            }
        }
    }

    private var sourceNode: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.25), lineWidth: 12)
                .frame(width: 66, height: 66)
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 2)
                .frame(width: 48, height: 48)
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
        }
    }

    private var receiverNode: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.72))
                .frame(width: 72, height: 72)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                .shadow(color: completed || hitPulse ? accent.opacity(0.9) : .white.opacity(0.34), radius: completed || hitPulse ? 22 : 10)
            Image(systemName: "mic.fill")
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .scaleEffect(hitPulse ? 1.08 : 1)
    }

    private func drawCanyon(canvas: inout GraphicsContext, size: CGSize) {
        let points = [
            CGPoint(x: 0.08, y: 0.25), CGPoint(x: 0.16, y: 0.08), CGPoint(x: 0.34, y: 0.1),
            CGPoint(x: 0.44, y: 0.22), CGPoint(x: 0.58, y: 0.09), CGPoint(x: 0.77, y: 0.12),
            CGPoint(x: 0.92, y: 0.28), CGPoint(x: 0.9, y: 0.55), CGPoint(x: 0.78, y: 0.72),
            CGPoint(x: 0.62, y: 0.74), CGPoint(x: 0.5, y: 0.9), CGPoint(x: 0.32, y: 0.82),
            CGPoint(x: 0.26, y: 0.64), CGPoint(x: 0.13, y: 0.61), CGPoint(x: 0.07, y: 0.43)
        ].map { point($0, in: size) }

        var cave = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { cave.move(to: point) } else { cave.addLine(to: point) }
        }
        cave.closeSubpath()
        canvas.fill(cave, with: .color(.white.opacity(0.035)))
        canvas.stroke(cave, with: .color(.white.opacity(0.42)), style: StrokeStyle(lineWidth: 1.3, lineJoin: .round))

        for index in points.indices {
            let next = points[(index + 1) % points.count]
            var shard = Path()
            shard.move(to: points[index])
            shard.addLine(to: CGPoint(x: (points[index].x + next.x) * 0.5, y: (points[index].y + next.y) * 0.5 + CGFloat(index.isMultiple(of: 2) ? 18 : -14)))
            shard.addLine(to: next)
            canvas.stroke(shard, with: .color(.white.opacity(0.1)), lineWidth: 1)
        }
    }

    private func drawPulsePath(canvas: inout GraphicsContext, size: CGSize) {
        guard pulsePath.count > 1 else { return }

        for index in 0..<(pulsePath.count - 1) {
            let wave = echoWavePath(from: pulsePath[index], to: pulsePath[index + 1], in: size)
            canvas.stroke(wave, with: .color(accent.opacity(missPulse ? 0.16 : 0.28)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            canvas.stroke(wave, with: .color(accent.opacity(missPulse ? 0.42 : 0.94)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            drawEchoFront(canvas: &canvas, from: pulsePath[index], to: pulsePath[index + 1], segmentIndex: index, in: size)
        }

        for p in pulsePath.dropFirst().dropLast() {
            let center = point(p, in: size)
            canvas.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(accent.opacity(0.9)))
        }
    }

    private func rotateMirror(_ index: Int) {
        guard !completed else { return }
        let current = mirrorAngles[index]
        let nextIndex = (angleOptions.firstIndex(of: current) ?? 0) + 1
        mirrorAngles[index] = angleOptions[nextIndex % angleOptions.count]
        missPulse = false
        if echoActive {
            updateEchoPath(playSound: false)
        } else {
            pulsePath.removeAll()
        }
        HapticPlayer.playLightTap()
    }

    private func testPulse() {
        echoActive = true
        echoPhase = 0
        echoCycle = 0
        updateEchoPath(playSound: true)
    }

    private func updateEchoPath(playSound: Bool) {
        let success = echoSolved
        pulsePath = tracedEchoPath()
        if playSound {
            audio.playPulse(success: success)
        }
        if success {
            HapticPlayer.playCompletionTap()
            hitPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                completed = true
            }
        } else {
            missPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                missPulse = false
            }
        }
    }

    private func stepEcho() {
        guard echoActive && !completed else { return }
        echoPhase += 0.018
        let cycle = Int(echoPhase / 1.0)
        if cycle > echoCycle {
            echoCycle = cycle
            updateEchoPath(playSound: true)
        }
    }

    private var echoSolved: Bool {
        zip(mirrorAngles, solutionAngles).allSatisfy { abs($0 - $1) < 0.1 }
    }

    private func tracedEchoPath() -> [CGPoint] {
        var path = [source, mirrorCenters[0]]

        guard mirrorIsSolved(0) else {
            path.append(edgePoint(from: mirrorCenters[0], index: 0))
            return path
        }

        path.append(mirrorCenters[1])
        guard mirrorIsSolved(1) else {
            path.append(edgePoint(from: mirrorCenters[1], index: 1))
            return path
        }

        path.append(mirrorCenters[2])
        guard mirrorIsSolved(2) else {
            path.append(edgePoint(from: mirrorCenters[2], index: 2))
            return path
        }

        path.append(receiver)
        return path
    }

    private func mirrorIsSolved(_ index: Int) -> Bool {
        abs(mirrorAngles[index] - solutionAngles[index]) < 0.1
    }

    private func edgePoint(from mirror: CGPoint, index: Int) -> CGPoint {
        let baseAngles = [90.0, -15.0, -28.0]
        let angle = baseAngles[index] + (mirrorAngles[index] - solutionAngles[index]) * 1.25
        return edgePoint(from: mirror, angleDegrees: angle)
    }

    private func edgePoint(from origin: CGPoint, angleDegrees: Double) -> CGPoint {
        let radians = angleDegrees * .pi / 180
        let direction = CGPoint(x: cos(radians), y: sin(radians))
        let bounds = CGRect(x: 0.07, y: 0.08, width: 0.86, height: 0.84)
        var candidates: [CGFloat] = []

        if abs(direction.x) > 0.0001 {
            candidates.append((bounds.minX - origin.x) / direction.x)
            candidates.append((bounds.maxX - origin.x) / direction.x)
        }
        if abs(direction.y) > 0.0001 {
            candidates.append((bounds.minY - origin.y) / direction.y)
            candidates.append((bounds.maxY - origin.y) / direction.y)
        }

        var travel: CGPoint?
        var shortestDistance = CGFloat.greatestFiniteMagnitude

        for candidate in candidates where candidate > 0.04 {
            let point = CGPoint(
                x: origin.x + direction.x * candidate,
                y: origin.y + direction.y * candidate
            )
            let onBoundary =
                bounds.contains(point) ||
                abs(point.x - bounds.minX) < 0.002 ||
                abs(point.x - bounds.maxX) < 0.002 ||
                abs(point.y - bounds.minY) < 0.002 ||
                abs(point.y - bounds.maxY) < 0.002

            guard onBoundary else { continue }

            let dx = point.x - origin.x
            let dy = point.y - origin.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < shortestDistance {
                shortestDistance = distance
                travel = point
            }
        }

        return travel ?? CGPoint(x: max(bounds.minX, min(bounds.maxX, origin.x + direction.x * 0.24)), y: max(bounds.minY, min(bounds.maxY, origin.y + direction.y * 0.24)))
    }

    private func reset() {
        mirrorAngles = [30, 30, 0]
        pulsePath.removeAll()
        echoActive = false
        echoPhase = 0
        echoCycle = 0
        completed = false
        hitPulse = false
        missPulse = false
    }

    private func point(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    private func echoWavePath(from: CGPoint, to: CGPoint, in size: CGSize) -> Path {
        let start = point(from, in: size)
        let end = point(to, in: size)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(1, sqrt(dx * dx + dy * dy))
        let normal = CGPoint(x: -dy / distance, y: dx / distance)
        let cycles = max(1.5, distance / 48)
        var path = Path()

        for step in 0...48 {
            let t = CGFloat(step) / 48
            let envelope = sin(Double(t) * .pi)
            let wave = sin((Double(t) * cycles - echoPhase) * .pi * 2) * envelope * 5.5
            let point = CGPoint(
                x: start.x + dx * t + normal.x * CGFloat(wave),
                y: start.y + dy * t + normal.y * CGFloat(wave)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func drawEchoFront(canvas: inout GraphicsContext, from: CGPoint, to: CGPoint, segmentIndex: Int, in size: CGSize) {
        let start = point(from, in: size)
        let end = point(to, in: size)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let travel = (echoPhase * 0.9 - Double(segmentIndex) * 0.18).truncatingRemainder(dividingBy: 1.0)
        let t = CGFloat(travel < 0 ? travel + 1 : travel)
        let center = CGPoint(x: start.x + dx * t, y: start.y + dy * t)

        for index in 0..<3 {
            let radius = CGFloat(4 + index * 4)
            canvas.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(accent.opacity(0.42 / Double(index + 1))),
                lineWidth: 1.4
            )
        }
        canvas.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(.white.opacity(0.9)))
    }
}

final class EchoCanyonAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func playPulse(success: Bool) {
        if !engine.isRunning {
            try? engine.start()
        }
        guard let buffer = makeBuffer(success: success) else { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    private func makeBuffer(success: Bool) -> AVAudioPCMBuffer? {
        let duration = success ? 0.74 : 0.46
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let progress = t / duration
            let base = success ? 520.0 + progress * 260.0 : 420.0 - progress * 90.0
            let echoDelay = 0.075
            let primary = sin(.pi * 2 * base * t)
            let echo1 = t > echoDelay ? sin(.pi * 2 * base * (t - echoDelay)) * 0.45 : 0
            let echo2 = t > echoDelay * 2 ? sin(.pi * 2 * base * (t - echoDelay * 2)) * 0.2 : 0
            let attack = min(1, t / 0.025)
            let release = pow(max(0, 1 - progress), success ? 1.4 : 2.1)
            channel[frame] = Float((primary + echo1 + echo2) * attack * release * 0.18)
        }
        return buffer
    }
}
