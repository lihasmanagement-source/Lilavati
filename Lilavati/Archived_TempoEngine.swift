import SwiftUI
import Combine
import AVFoundation

struct MathItTempoEngineGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var metronomeAudio = TempoMetronomeAudio()
    @State private var stageIndex = 0
    @State private var completed = false
    @State private var phase = 0.0
    @State private var running = false
    @State private var beatFlash = false
    @State private var shotFlash = false
    @State private var hitStreak = 0
    @State private var lastCadenceIndex = -1
    @State private var lastTapDate: Date?
    @State private var tapIntervals: [Double] = []
    @State private var playerBPM: Int?
    @State private var wrongPulse = false

    private let stages = [
        RhythmShooterStage(bpm: 94, beats: [0.0, 0.1875, 0.5, 0.6875], icon: "drumstick.fill"),
        RhythmShooterStage(bpm: 118, beats: [0.0, 0.25, 0.375, 0.625, 0.75], icon: "metronome.fill"),
        RhythmShooterStage(bpm: 142, beats: [0.0, 0.125, 0.3125, 0.5, 0.5625, 0.8125], icon: "bolt.fill")
    ]
    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private var stage: RhythmShooterStage { stages[stageIndex] }
    private var progress: Double {
        (Double(stageIndex) + Double(hitStreak) / 4.0) / Double(stages.count)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        Text("LEVEL \(concept.number)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        Text(concept.title)
                            .font(.trajan(36))
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.46))
                    }
                    .padding(.horizontal, 58)

                    ProgressView(value: progress)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    tempoField
                        .frame(height: min(390, proxy.size.height * 0.5))
                        .padding(.horizontal, 20)
                        .scaleEffect(wrongPulse ? 0.985 : 1)

                    HStack(spacing: 12) {
                        playButton
                        rhythmBadge("\(playerBPM ?? 0)", systemImage: "speedometer")
                        rhythmBadge("\(hitStreak)/4", systemImage: "scope")
                        Button(action: reset) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 48, height: 46)
                                .background(accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.top, 38)
                .padding(.bottom, 78)

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
                stepBeat()
            }
        }
    }

    private var tempoField: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.08), Color(red: 0.01, green: 0.035, blue: 0.05), .black.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.36), lineWidth: 1.2))

                VStack(spacing: 24) {
                    rhythmShooterField
                        .frame(height: min(210, proxy.size.height * 0.52))

                    cadenceStrip
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 18)
            }
        }
    }

    private var rhythmShooterField: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let targetX = width * (0.08 + 0.84 * CGFloat(phase))
            let targetY = height * (0.35 + 0.18 * sin(CGFloat(phase) * .pi * 2))

            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    let x = width * (0.08 + 0.84 * CGFloat(index) / 3.0)
                    Capsule()
                        .fill(.white.opacity(0.11))
                        .frame(width: 4, height: height * 0.66)
                        .position(x: x, y: height * 0.46)
                }

                ForEach(stage.beats, id: \.self) { beat in
                    let x = width * (0.08 + 0.84 * CGFloat(beat))
                    Circle()
                        .fill(isNearBeat(beat) ? accent.opacity(0.95) : accent.opacity(0.22))
                        .frame(width: isNearBeat(beat) ? 18 : 12, height: isNearBeat(beat) ? 18 : 12)
                        .position(x: x, y: height * 0.78)
                }

                Path { path in
                    path.move(to: CGPoint(x: width * 0.5, y: height * 0.92))
                    path.addLine(to: CGPoint(x: targetX, y: targetY))
                }
                .stroke(accent.opacity(shotFlash ? 0.95 : 0), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 6]))

                Circle()
                    .fill(beatFlash ? accent.opacity(0.92) : accent.opacity(0.16))
                    .frame(width: beatFlash ? 86 : 62, height: beatFlash ? 86 : 62)
                    .position(x: width * 0.5, y: height * 0.92)

                Image(systemName: "target")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.52), radius: 10)
                    .position(x: targetX, y: targetY)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                shoot()
            }
        }
    }

    private var cadenceStrip: some View {
        HStack(spacing: 6) {
            ForEach(0..<16, id: \.self) { index in
                let step = Double(index) / 16.0
                let active = stage.beats.contains(step)
                RoundedRectangle(cornerRadius: 4)
                    .fill(active ? accent.opacity(currentStep == index ? 0.95 : 0.5) : .white.opacity(currentStep == index ? 0.28 : 0.09))
                    .frame(height: active ? 18 : 10)
            }
        }
        .frame(height: 24)
    }

    private var playButton: some View {
        Button {
            startStage()
        } label: {
            Image(systemName: running ? stage.icon : "play.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 46, height: 46)
                .background(running ? accent.opacity(0.7) : accent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(completed)
    }

    private func rhythmBadge(_ value: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.mathGold.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(.black.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.36), lineWidth: 1.1))
    }

    private var currentStep: Int {
        Int(floor(phase * 16.0)) % 16
    }

    private func startStage() {
        guard !completed else { return }
        running = true
        phase = 0
        lastCadenceIndex = -1
        hitStreak = 0
        lastTapDate = nil
        tapIntervals = []
        playerBPM = nil
        HapticPlayer.playLightTap()
    }

    private func shoot() {
        guard running, !completed else { return }
        registerTap()
        shotFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shotFlash = false
        }

        if isOnCadenceBeat {
            hitStreak += 1
            HapticPlayer.playCompletionTap()
            if hitStreak >= 4 {
                completeStage()
            }
        } else {
            hitStreak = 0
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                wrongPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
                    wrongPulse = false
                }
            }
        }
    }

    private func completeStage() {
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                running = false
                completed = true
            }
        } else {
            let nextIndex = stageIndex + 1
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                stageIndex = nextIndex
                phase = 0
                running = false
                hitStreak = 0
                lastCadenceIndex = -1
                lastTapDate = nil
                tapIntervals = []
                playerBPM = nil
            }
        }
    }

    private func stepBeat() {
        guard running else { return }
        phase = (phase + Double(stage.bpm) / 60.0 / 60.0 / 4.0).truncatingRemainder(dividingBy: 1)

        if let cadenceIndex = activeCadenceIndex, cadenceIndex != lastCadenceIndex {
            lastCadenceIndex = cadenceIndex
            beatFlash = true
            playMetronomeTick()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                beatFlash = false
            }
        }
    }

    private var activeCadenceIndex: Int? {
        stage.beats.firstIndex { isNearBeat($0) }
    }

    private var isOnCadenceBeat: Bool {
        activeCadenceIndex != nil
    }

    private func isNearBeat(_ beat: Double) -> Bool {
        let distance = min(abs(phase - beat), 1 - abs(phase - beat))
        return distance < 0.045
    }

    private func registerTap() {
        let now = Date()
        if let lastTapDate {
            let interval = now.timeIntervalSince(lastTapDate)
            if interval > 0.18 && interval < 1.6 {
                tapIntervals.append(interval)
                tapIntervals = Array(tapIntervals.suffix(4))
                let average = tapIntervals.reduce(0, +) / Double(tapIntervals.count)
                playerBPM = Int((60.0 / average).rounded())
            }
        }
        lastTapDate = now
    }

    private func playMetronomeTick() {
        metronomeAudio.playTick()
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            stageIndex = 0
            completed = false
            wrongPulse = false
            phase = 0
            running = false
            beatFlash = false
            shotFlash = false
            hitStreak = 0
            lastCadenceIndex = -1
            lastTapDate = nil
            tapIntervals = []
            playerBPM = nil
        }
    }
}

struct RhythmShooterStage {
    let bpm: Int
    let beats: [Double]
    let icon: String
}

final class TempoMetronomeAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
        try? engine.start()
        player.play()
    }

    func playTick() {
        if !engine.isRunning {
            try? engine.start()
            player.play()
        }

        guard let buffer = makeTickBuffer() else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    private func makeTickBuffer() -> AVAudioPCMBuffer? {
        let duration = 0.045
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = exp(-t * 88)
            let snap = sin(2 * .pi * 2_250 * t)
            let body = sin(2 * .pi * 1_100 * t) * 0.35
            channel[frame] = Float((snap + body) * envelope * 0.95)
        }

        return buffer
    }
}
