import SwiftUI
import Combine
import AVFoundation

struct MathItEQEnvelopeGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var audio = LevelSixtySevenEQAudio()
    @State private var stageIndex = 0
    @State private var bands = [3, 5, 7]
    @State private var completed = false
    @State private var wrongPulse = false
    @State private var advancing = false

    private let targets = [
        [7, 4, 3],
        [2, 8, 5],
        [5, 3, 8]
    ]
    private let labels = ["LOW", "MID", "HIGH"]
    private var target: [Int] { targets[stageIndex] }
    private var matchCount: Int {
        zip(bands, target).filter { $0 == $1 }.count
    }
    private var progress: Double {
        (Double(stageIndex) + Double(matchCount) / 3.0) / Double(targets.count)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(36))
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.46))
                    }
                    .padding(.horizontal, 58)

                    ProgressView(value: progress)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    eqField
                        .frame(height: min(390, proxy.size.height * 0.5))
                        .padding(.horizontal, 20)
                        .scaleEffect(wrongPulse ? 0.985 : 1)

                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            eqDial(index)
                        }

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
            .onAppear {
                audio.start()
                updateAudio()
            }
            .onDisappear {
                audio.stop()
            }
        }
    }

    private var eqField: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.1), Color(red: 0.035, green: 0.012, blue: 0.04), .black.opacity(0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.36), lineWidth: 1.2))

                Canvas { canvas, size in
                    drawEQWave(canvas: &canvas, size: size, source: target, color: .white.opacity(0.2), dashed: true)
                    if advancing {
                        drawEQWave(canvas: &canvas, size: size, source: bands, color: accent.opacity(0.26), dashed: false, lineWidth: 15)
                        drawEQWave(canvas: &canvas, size: size, source: bands, color: accent.opacity(0.48), dashed: false, lineWidth: 9)
                    }
                    drawEQWave(canvas: &canvas, size: size, source: bands, color: accent.opacity(matchCount == 3 ? 0.96 : 0.68), dashed: false)
                }

                HStack(spacing: 26) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(bands[index] == target[index] ? accent : Color.mathGold.opacity(0.5))
                    }
                }
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.82)
            }
        }
    }

    private func eqDial(_ index: Int) -> some View {
        let matched = bands[index] == target[index]
        return VStack(spacing: 5) {
            eqStepButton(systemImage: "plus", index: index, amount: 1)

            HStack(spacing: 5) {
                eqStepButton(systemImage: "minus", index: index, amount: -1)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(bands[index]) / 9.0)
                        .stroke(matched ? accent : accent.opacity(0.62), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Capsule()
                        .fill(matched ? accent : .white.opacity(0.7))
                        .frame(width: 5, height: 24)
                        .offset(y: -18)
                        .rotationEffect(.degrees(Double(bands[index]) / 9.0 * 270 - 135))
                    Text("\(bands[index])")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(matched ? accent : .white)
                }
                .frame(width: 52, height: 52)
            }

            Text(labels[index])
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Color.mathGold.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private func eqStepButton(systemImage: String, index: Int, amount: Int) -> some View {
        Button {
            adjustBand(index, by: amount)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 25, height: 20)
                .background(accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(completed)
    }

    private func adjustBand(_ index: Int, by amount: Int) {
        guard !completed else { return }
        bands[index] = min(max(bands[index] + amount, 1), 9)
        updateAudio()
        HapticPlayer.playLightTap()
        checkAutoAdvance()
    }

    private func drawEQWave(canvas: inout GraphicsContext, size: CGSize, source: [Int], color: Color, dashed: Bool, lineWidth: CGFloat = 5) {
        var path = Path()
        let width = size.width * 0.84
        let startX = size.width * 0.08
        let midY = size.height * 0.42
        for step in 0...120 {
            let x = startX + width * CGFloat(step) / 120.0
            let t = Double(step) / 120.0 * .pi * 2
            let low = sin(t) * Double(source[0]) * 3.2
            let mid = sin(t * 2.1 + 0.7) * Double(source[1]) * 2.1
            let high = sin(t * 5.0 + 1.4) * Double(source[2]) * 1.1
            let y = midY + CGFloat(low + mid + high)
            if step == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        canvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: dashed ? 3 : lineWidth, lineCap: .round, lineJoin: .round, dash: dashed ? [8, 8] : []))
    }

    private func checkAutoAdvance() {
        guard !completed, !advancing, matchCount == 3 else { return }
        advancing = true
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.32) {
            if stageIndex == targets.count - 1 {
                withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                    completed = true
                    advancing = false
                }
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    stageIndex += 1
                    bands = targets[stageIndex].map { max(1, min(9, $0 - 2)) }
                    advancing = false
                    updateAudio()
                }
            }
        }
    }

    private func updateAudio() {
        audio.setBands(
            low: Double(bands[0]) / 9.0,
            mid: Double(bands[1]) / 9.0,
            high: Double(bands[2]) / 9.0
        )
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            stageIndex = 0
            bands = [3, 5, 7]
            completed = false
            wrongPulse = false
            advancing = false
            updateAudio()
        }
    }
}

final class LevelSixtySevenEQAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let sampleRate = 44_100.0
    private let lock = NSLock()
    private var low = 0.35
    private var mid = 0.55
    private var high = 0.75
    private var currentLow = 0.35
    private var currentMid = 0.55
    private var currentHigh = 0.75
    private var lowPhase = 0.0
    private var midPhase = 0.0
    private var highPhase = 0.0
    private var shimmerPhase = 0.0

    private lazy var sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self else { return noErr }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

        for frame in 0..<Int(frameCount) {
            self.lock.lock()
            let low = self.low
            let mid = self.mid
            let high = self.high
            self.lock.unlock()

            self.currentLow += (low - self.currentLow) * 0.0018
            self.currentMid += (mid - self.currentMid) * 0.0018
            self.currentHigh += (high - self.currentHigh) * 0.0018

            let slowBloom = 0.78 + sin(self.shimmerPhase) * 0.08
            let sample =
                sin(self.lowPhase) * self.currentLow * 0.2
                + sin(self.midPhase) * self.currentMid * 0.16
                + sin(self.midPhase * 1.5) * self.currentMid * 0.055
                + sin(self.highPhase) * self.currentHigh * 0.045
            let output = Float(tanh(sample * slowBloom) * 0.46)

            self.lowPhase += 2 * .pi * 130.81 / self.sampleRate
            self.midPhase += 2 * .pi * 196.0 / self.sampleRate
            self.highPhase += 2 * .pi * 329.63 / self.sampleRate
            self.shimmerPhase += 2 * .pi * 0.18 / self.sampleRate
            if self.lowPhase > 2 * .pi { self.lowPhase -= 2 * .pi }
            if self.midPhase > 2 * .pi { self.midPhase -= 2 * .pi }
            if self.highPhase > 2 * .pi { self.highPhase -= 2 * .pi }
            if self.shimmerPhase > 2 * .pi { self.shimmerPhase -= 2 * .pi }

            for buffer in buffers {
                let channel = buffer.mData?.assumingMemoryBound(to: Float.self)
                channel?[frame] = output
            }
        }

        return noErr
    }

    func start() {
        if engine.attachedNodes.isEmpty {
            engine.attach(sourceNode)
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.85
        }
        if !engine.isRunning {
            try? engine.start()
        }
    }

    func stop() {
        engine.stop()
    }

    func setBands(low: Double, mid: Double, high: Double) {
        lock.lock()
        self.low = low
        self.mid = mid
        self.high = high
        lock.unlock()
    }
}
