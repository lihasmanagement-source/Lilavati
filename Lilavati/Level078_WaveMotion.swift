import AVFoundation
import SwiftUI

@Observable
final class MathItLevelTwentySixViewModel {
    var tokens = [
        LevelTwentySixFractionToken(label: "1/3", value: 1.0 / 3.0, harmonic: 3),
        LevelTwentySixFractionToken(label: "1/2", value: 1.0 / 2.0, harmonic: 2),
        LevelTwentySixFractionToken(label: "1/4", value: 1.0 / 4.0, harmonic: 4)
    ]
    var activeRows: Set<Int> = []
    var completed = false

    private let tonePlayer = LevelTwentySixTonePlayer()

    deinit {
        tonePlayer.stop()
    }

    var progress: Double {
        completed ? 1 : min(0.96, Double(activeRows.count) / Double(tokens.count))
    }

    func moveToken(id: UUID, by translation: CGSize) {
        guard !completed, let index = tokens.firstIndex(where: { $0.id == id }), tokens[index].placedRow == nil else { return }
        tokens[index].offset = translation
    }

    func finishToken(id: UUID, at point: CGPoint, source: CGPoint, slots: [Int: CGRect]) {
        guard !completed, let index = tokens.firstIndex(where: { $0.id == id }), tokens[index].placedRow == nil else { return }
        let token = tokens[index]

        guard let row = slots.first(where: { $0.value.insetBy(dx: -24, dy: -28).contains(point) })?.key,
              row == token.harmonic - 2,
              let slot = slots[row] else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                tokens[index].offset = .zero
            }
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            tokens[index].placedRow = row
            tokens[index].offset = CGSize(width: slot.midX - source.x, height: slot.midY - source.y)
            activeRows.insert(row)
        }
        tonePlayer.setHarmonics(activeRows.map { $0 + 2 })

        guard activeRows.count == tokens.count else { return }
        complete()
    }

    private func complete() {
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    func stopSound() {
        tonePlayer.stop()
    }
}

struct LevelTwentySixFractionToken: Identifiable {
    let id = UUID()
    let label: String
    let value: CGFloat
    let harmonic: Int
    var offset = CGSize.zero
    var placedRow: Int?
}

struct MathItLevelTwentySixView: View {
    var viewModel: MathItLevelTwentySixViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let cyan = Color.mathItMusic

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let stringLeft = size.width * 0.13
            let stringRight = size.width * 0.87
            let rowYs = [size.height * 0.29, size.height * 0.43, size.height * 0.57]
            let slots = harmonicSlots(left: stringLeft, right: stringRight, rowYs: rowYs)
            let sources = tokenSources(in: size)

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
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(cyan)
                    .opacity(0.78)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.018))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(cyan.opacity(0.24), lineWidth: 1.2)
                    }
                    .frame(width: size.width - 36, height: size.height * 0.5)
                    .position(x: size.width / 2, y: size.height * 0.42)

                ForEach(0..<3, id: \.self) { row in
                    harmonicString(
                        row: row,
                        left: stringLeft,
                        right: stringRight,
                        y: rowYs[row],
                        slot: slots[row]!
                    )
                }

                ForEach(Array(viewModel.tokens.enumerated()), id: \.element.id) { index, token in
                    fractionToken(token)
                        .position(sources[index])
                        .offset(token.offset)
                        .gesture(
                            DragGesture(coordinateSpace: .named("levelTwentySixStage"))
                                .onChanged { value in
                                    viewModel.moveToken(id: token.id, by: value.translation)
                                }
                                .onEnded { value in
                                    viewModel.finishToken(
                                        id: token.id,
                                        at: value.location,
                                        source: sources[index],
                                        slots: slots
                                    )
                                }
                        )
                        .zIndex(5)
                }

                CompletionOverlay(
                    title: "Level 26 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelTwentySixStage")
            .onDisappear {
                viewModel.stopSound()
            }
        }
    }

    private func harmonicString(row: Int, left: CGFloat, right: CGFloat, y: CGFloat, slot: CGRect) -> some View {
        let active = viewModel.activeRows.contains(row)
        let harmonic = row + 2

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
            }
            .stroke(.white.opacity(active ? 0.16 : 0.5), lineWidth: 1.4)

            if active {
                TimelineView(.animation) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate * 1.65 * Double(harmonic)
                    LevelTwentySixStandingWave(harmonic: harmonic, phase: phase)
                        .stroke(cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .shadow(color: cyan.opacity(0.65), radius: 6)
                        .frame(width: right - left, height: 72)
                        .position(x: (left + right) / 2, y: y)
                }
                .transition(.opacity)
            }

            Circle()
                .fill(.black)
                .overlay { Circle().stroke(.white.opacity(0.82), lineWidth: 1.5) }
                .frame(width: 13, height: 13)
                .position(x: left, y: y)

            Circle()
                .fill(.black)
                .overlay { Circle().stroke(.white.opacity(0.82), lineWidth: 1.5) }
                .frame(width: 13, height: 13)
                .position(x: right, y: y)

            Circle()
                .fill(active ? cyan : .black)
                .overlay {
                    Circle()
                        .stroke(cyan.opacity(active ? 1 : 0.52), style: StrokeStyle(lineWidth: 1.4, dash: active ? [] : [3, 3]))
                }
                .frame(width: 20, height: 20)
                .shadow(color: cyan.opacity(active ? 0.75 : 0), radius: 9)
                .position(x: slot.midX, y: slot.midY)

            Text("\(harmonic)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(cyan.opacity(0.48))
                .position(x: left - 18, y: y)

            if active, let token = viewModel.tokens.first(where: { $0.placedRow == row }) {
                Text(token.label)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(cyan)
                    .position(x: slot.midX, y: y - 35)
            }
        }
    }

    private func fractionToken(_ token: LevelTwentySixFractionToken) -> some View {
        ZStack {
            Circle()
                .fill(.black)
                .overlay {
                    Circle().stroke(cyan.opacity(token.placedRow == nil ? 0.66 : 1), lineWidth: 1.5)
                }
                .frame(width: 58, height: 58)
                .shadow(color: cyan.opacity(token.placedRow == nil ? 0.12 : 0.64), radius: 10)

            Text(token.label)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func harmonicSlots(left: CGFloat, right: CGFloat, rowYs: [CGFloat]) -> [Int: CGRect] {
        Dictionary(uniqueKeysWithValues: viewModel.tokens.map { token in
            let row = token.harmonic - 2
            let x = left + (right - left) * token.value
            return (row, CGRect(x: x - 14, y: rowYs[row] - 14, width: 28, height: 28))
        })
    }

    private func tokenSources(in size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: size.width * 0.22, y: size.height * 0.79),
            CGPoint(x: size.width * 0.5, y: size.height * 0.84),
            CGPoint(x: size.width * 0.78, y: size.height * 0.78)
        ]
    }
}

private struct LevelTwentySixStandingWave: Shape {
    let harmonic: Int
    let phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amplitude = rect.height * 0.43 * CGFloat(sin(phase))

        for step in 0...120 {
            let progress = CGFloat(step) / 120
            let x = rect.minX + rect.width * progress
            let y = rect.midY - sin(progress * .pi * CGFloat(harmonic)) * amplitude
            if step == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

private final class LevelTwentySixTonePlayer {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let lock = NSLock()
    private var activeHarmonics: Set<Int> = []
    private var targetAmplitudes: [Int: Double] = [:]
    private var amplitudes: [Int: Double] = [:]
    private var phases: [Int: Double] = [:]

    private lazy var sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self else { return noErr }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

        for frame in 0..<Int(frameCount) {
            self.lock.lock()
            var sample = 0.0
            for harmonic in 2...4 {
                let target = self.targetAmplitudes[harmonic, default: 0]
                let current = self.amplitudes[harmonic, default: 0] + (target - self.amplitudes[harmonic, default: 0]) * 0.0025
                var phase = self.phases[harmonic, default: 0]
                sample += (sin(phase) + sin(phase * 2) * 0.14) * current
                phase += 2 * Double.pi * (220 * Double(harmonic)) / self.sampleRate
                if phase > 2 * Double.pi { phase -= 2 * Double.pi }
                self.amplitudes[harmonic] = current
                self.phases[harmonic] = phase
            }
            self.lock.unlock()

            let outputSample = Float(tanh(sample))
            for buffer in buffers {
                buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = outputSample
            }
        }
        return noErr
    }

    init() {
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func setHarmonics(_ harmonics: [Int]) {
        lock.lock()
        activeHarmonics = Set(harmonics)
        for harmonic in 2...4 {
            targetAmplitudes[harmonic] = activeHarmonics.contains(harmonic) ? 0.032 : 0
        }
        lock.unlock()

        if !engine.isRunning {
            try? engine.start()
        }
    }

    func stop() {
        lock.lock()
        activeHarmonics.removeAll()
        for harmonic in 2...4 {
            targetAmplitudes[harmonic] = 0
            amplitudes[harmonic] = 0
        }
        lock.unlock()
        engine.stop()
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

}
