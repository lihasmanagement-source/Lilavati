import AVFoundation
import SwiftUI

@Observable
final class MathItLevelFortyTwoViewModel {
    let steps = 8
    let targetPatterns: [Set<Int>] = [
        [0, 3, 6],
        [0, 2, 4, 6],
        [0, 2, 3, 5, 6]
    ]

    var stage = 0
    var selectedSteps: Set<Int> = []
    var currentStep = -1
    var locked = false
    var completed = false
    var isDemonstrating = false
    var shields = 3
    var score = 0
    var combo = 1
    var overload = false
    var shockwave: CGFloat = 0
    var successGlow: CGFloat = 0
    var successPink = false
    var isPlaying = false
    var wrongBeat = false

    private let player = LevelFortyTwoClickPlayer()
    private var timer: Timer?
    private var demonstrationTicks = 0

    deinit {
        stop()
    }

    var targetPulses: Int {
        targetPattern.count
    }

    var targetPattern: Set<Int> {
        targetPatterns[min(stage, targetPatterns.count - 1)]
    }

    var progress: Double {
        completed ? 1 : (Double(stage) + Double(selectedSteps.count) / Double(targetPulses)) / Double(targetPatterns.count)
    }

    var canFire: Bool {
        selectedSteps.count == targetPulses && !locked && !completed && !isDemonstrating
    }

    var canPlay: Bool {
        !selectedSteps.isEmpty && !locked && !completed && !isDemonstrating
    }

    func startStage() {
        guard timer == nil, selectedSteps.isEmpty, !completed else { return }
        demonstratePattern()
    }

    func replayPattern() {
        guard !locked, !completed, !isDemonstrating else { return }
        score = max(0, score - 50)
        demonstratePattern()
    }

    func toggleStep(_ step: Int) {
        guard !locked, !completed, !isDemonstrating else { return }

        if selectedSteps.contains(step) {
            selectedSteps.remove(step)
        } else {
            guard selectedSteps.count < targetPulses else {
                HapticPlayer.playLightTap()
                return
            }
            selectedSteps.insert(step)
            player.play(accented: step == 0)
        }

        HapticPlayer.playLightTap()
        // Editing the pattern stops the metronome; playback only starts from the play button.
        stop()
    }

    func togglePlayback() {
        guard !isDemonstrating, !locked, !completed, !selectedSteps.isEmpty else { return }
        if isPlaying {
            stop()
        } else {
            startPlayback()
        }
    }

    func clear() {
        guard !locked, !completed else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            selectedSteps.removeAll()
        }
        stop()
    }

    func fire() {
        guard canFire else { return }
        locked = true

        if selectedSteps == targetPattern {
            score += targetPulses * 100 * combo
            combo += 1
            HapticPlayer.playCompletionTap()
            withAnimation(.easeOut(duration: 0.5)) {
                successGlow = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.successPink = true
                    self.shockwave = 1
                }
            }
            replaySolutionThenComplete()
        } else {
            shields -= 1
            combo = 1
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.42)) {
                overload = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.stop()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    self.selectedSteps.removeAll()
                    self.overload = false
                    self.locked = false
                    if self.shields == 0 {
                        self.shields = 3
                        self.score = max(0, self.score - 200)
                    }
                }
                self.demonstratePattern()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentStep = -1
        isPlaying = false
    }

    private func startPlayback() {
        guard !selectedSteps.isEmpty, timer == nil, !isDemonstrating else { return }
        isPlaying = true
        currentStep = 0
        playCurrentStep()
        timer = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: true) { [weak self] _ in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.1)) {
                self.currentStep = (self.currentStep + 1) % self.steps
            }
            self.playCurrentStep()
        }
    }

    private func playCurrentStep() {
        guard selectedSteps.contains(currentStep) else { return }
        player.play(accented: currentStep == 0)
        // A selected beat that isn't in the target is a wrong note — flash red.
        if !targetPattern.contains(currentStep) {
            flashWrongBeat()
        }
    }

    private func flashWrongBeat() {
        HapticPlayer.playLightTap()
        withAnimation(.easeOut(duration: 0.07)) { wrongBeat = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.14)) { self.wrongBeat = false }
        }
    }

    private func demonstratePattern() {
        stop()
        isDemonstrating = true
        locked = true
        demonstrationTicks = 0
        currentStep = 0
        playDemonstrationStep()

        timer = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.demonstrationTicks += 1
            if self.demonstrationTicks >= self.steps * 2 {
                timer.invalidate()
                self.timer = nil
                self.currentStep = -1
                self.isDemonstrating = false
                self.locked = false
                return
            }
            withAnimation(.easeInOut(duration: 0.1)) {
                self.currentStep = self.demonstrationTicks % self.steps
            }
            self.playDemonstrationStep()
        }
    }

    private func playDemonstrationStep() {
        guard targetPattern.contains(currentStep) else { return }
        player.play(accented: currentStep == 0)
    }

    private func replaySolutionThenComplete() {
        stop()
        isDemonstrating = true
        locked = true
        demonstrationTicks = 0
        currentStep = 0
        playCurrentStep()

        timer = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.demonstrationTicks += 1
            if self.demonstrationTicks >= self.steps {
                timer.invalidate()
                self.timer = nil
                self.currentStep = -1
                self.isDemonstrating = false
                self.completeStage(delay: 0.28)
                return
            }
            withAnimation(.easeInOut(duration: 0.1)) {
                self.currentStep = self.demonstrationTicks
            }
            self.playCurrentStep()
        }
    }

    private func completeStage(delay: Double = 2.65) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.stage == self.targetPatterns.count - 1 {
                self.stop()
                withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                    self.completed = true
                }
            } else {
                self.stop()
                withAnimation(.easeInOut(duration: 0.42)) {
                    self.stage += 1
                    self.selectedSteps.removeAll()
                    self.locked = false
                    self.shockwave = 0
                    self.successGlow = 0
                    self.successPink = false
                }
                self.demonstratePattern()
            }
        }
    }
}

struct MathItLevelFortyTwoView: View {
    var viewModel: MathItLevelFortyTwoViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let purple = Color.mathItMusic

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height * 0.48)
            let radius = min(size.width * 0.34, size.height * 0.24)
            let points = stepPoints(center: center, radius: radius)

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    EmptyView()
                        .font(.trajan(34))
                        .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.34))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(purple)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                shieldBar(size: size)
                rhythmWheel(center: center, radius: radius, points: points)

                HStack(spacing: 8) {
                    controlButton("waveform", enabled: !viewModel.isDemonstrating && !viewModel.locked, action: viewModel.replayPattern)
                    controlButton("arrow.counterclockwise", enabled: !viewModel.selectedSteps.isEmpty && !viewModel.locked, action: viewModel.clear)
                    controlButton(viewModel.isPlaying ? "pause.fill" : "play.fill", enabled: viewModel.canPlay, action: viewModel.togglePlayback)
                    controlButton("checkmark", enabled: viewModel.canFire, filled: true, action: viewModel.fire)
                }
                .position(x: size.width / 2, y: size.height * 0.79)

                Color.mathItMusic
                    .opacity(viewModel.wrongBeat ? 0.16 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                CompletionOverlay(
                    title: "Level 42 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .onDisappear {
                viewModel.stop()
            }
            .onAppear {
                viewModel.startStage()
            }
        }
    }

    private func rhythmWheel(center: CGPoint, radius: CGFloat, points: [CGPoint]) -> some View {
        ZStack {
            Circle()
                .stroke(
                    viewModel.successGlow > 0
                        ? (viewModel.successPink ? purple : .white)
                        : (viewModel.overload ? Color.mathItMusic.opacity(0.8) : .white.opacity(0.14)),
                    lineWidth: viewModel.successGlow > 0 || viewModel.overload ? 4 : 1.2
                )
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
                .shadow(
                    color: viewModel.successGlow > 0
                        ? (viewModel.successPink ? purple.opacity(0.9) : .white.opacity(0.72))
                        : (viewModel.overload ? Color.mathItMusic.opacity(0.9) : .clear),
                    radius: viewModel.successGlow > 0 ? 20 : 20
                )

            ForEach(0..<viewModel.steps, id: \.self) { step in
                Path { path in
                    path.move(to: center)
                    path.addLine(to: points[step])
                }
                .stroke(.white.opacity(viewModel.currentStep == step ? 0.25 : 0.06), lineWidth: 1)

                stepButton(step, point: points[step])
            }

            Circle()
                .stroke(purple.opacity(0.75 * (1 - viewModel.shockwave)), lineWidth: 4)
                .frame(width: (radius + 58) * 2 * viewModel.shockwave, height: (radius + 58) * 2 * viewModel.shockwave)
                .position(center)
                .opacity(viewModel.shockwave > 0 ? 1 : 0)
                .shadow(color: purple, radius: 18)

            VStack(spacing: 9) {
                Image(systemName: centerIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(viewModel.overload ? Color.mathItMusic : purple)
                    .symbolEffect(.pulse, isActive: viewModel.isDemonstrating)

                Text("\(viewModel.selectedSteps.count) / \(viewModel.targetPulses)")
                    .font(.trajan(30))
                    .foregroundStyle(viewModel.locked ? purple : Color.mathGold.opacity(0.95))
            }
            .position(center)
        }
        .offset(x: viewModel.overload ? 7 : (viewModel.wrongBeat ? 5 : 0))
        .animation(.easeInOut(duration: 0.07).repeatCount(6, autoreverses: true), value: viewModel.overload)
        .animation(.easeInOut(duration: 0.05).repeatCount(4, autoreverses: true), value: viewModel.wrongBeat)
    }

    private var centerIcon: String {
        if viewModel.overload { return "xmark" }
        if viewModel.canFire { return "checkmark" }
        return "waveform"
    }

    private func stepButton(_ step: Int, point: CGPoint) -> some View {
        let selected = viewModel.selectedSteps.contains(step)
        let playing = viewModel.currentStep == step
        let wrongPlaying = playing && selected && !viewModel.targetPattern.contains(step)

        return Button {
            viewModel.toggleStep(step)
        } label: {
            ZStack {
                Circle()
                    .fill(.black)
                    .overlay {
                        Circle()
                            .stroke(
                                wrongPlaying
                                    ? Color.mathItMusic
                                    : (selected && viewModel.successGlow > 0
                                        ? (viewModel.successPink ? purple : .white)
                                        : (selected ? purple : .white.opacity(0.38))),
                                lineWidth: selected && viewModel.successGlow > 0 ? 3.5 : (playing ? 3 : 1.4)
                            )
                    }
                    .frame(width: playing ? 42 : 34, height: playing ? 42 : 34)
                    .shadow(
                        color: selected
                            ? (viewModel.successGlow > 0
                                ? (viewModel.successPink ? purple.opacity(0.95) : Color.mathGold.opacity(0.95))
                                : purple.opacity(playing ? 0.9 : 0.52))
                            : .clear,
                        radius: selected && viewModel.successGlow > 0 ? 14 : (playing ? 15 : 7)
                    )

                Text("\(step + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(selected ? purple.opacity(0.92) : .white.opacity(0.54))
            }
            .frame(width: 54, height: 54)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.locked)
        .position(point)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: playing)
    }

    private func stepPoints(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<viewModel.steps).map { step in
            let angle = -.pi / 2 + CGFloat(step) * 2 * .pi / CGFloat(viewModel.steps)
            return CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
        }
    }

    private func shieldBar(size: CGSize) -> some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < viewModel.shields ? "shield.fill" : "shield")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(index < viewModel.shields ? purple : .white.opacity(0.18))
            }
        }
        .position(x: size.width / 2, y: size.height * 0.22)
    }

    private func controlButton(_ symbol: String, enabled: Bool, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(filled && enabled ? .black : .white.opacity(enabled ? 0.72 : 0.25))
                .frame(width: 70, height: 42)
                .background(filled && enabled ? purple : .clear, in: Capsule())
                .overlay {
                    Capsule().stroke(filled && enabled ? .clear : .white.opacity(enabled ? 0.28 : 0.12), lineWidth: 1)
                }
                .shadow(color: filled && enabled ? purple.opacity(0.65) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

}

private final class LevelFortyTwoClickPlayer {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100

    func play(accented: Bool) {
        let player = AVAudioPlayerNode()
        let buffer = makeBuffer(frequency: accented ? 880 : 440)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        if !engine.isRunning {
            try? engine.start()
        }
        player.scheduleBuffer(buffer, at: nil, options: []) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                player.stop()
                self.engine.detach(player)
            }
        }
        player.play()
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    private func makeBuffer(frequency: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * 0.07)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = exp(-time * 52)
            channel[frame] = Float(sin(2 * .pi * frequency * time) * envelope * 0.12)
        }
        return buffer
    }
}
