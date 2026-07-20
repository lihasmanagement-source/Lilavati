import SwiftUI
import Combine
import AVFoundation

struct MathItDopplerDashGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var audio = DopplerDashAudio()
    @State private var sourcePosition = CGPoint(x: 0.32, y: 0.58)
    @State private var receiveLevel: Double = 0
    @State private var completed = false
    @State private var dragging = false
    @State private var wavePhase: Double = 0

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let microphone = CGPoint(x: 0.82, y: 0.5)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 12) {
                    soundStrip
                        .frame(height: 96)
                        .padding(.horizontal, 24)

                    dopplerField
                        .frame(height: min(520, proxy.size.height * 0.62))
                        .padding(.horizontal, 18)

                    HStack(spacing: 12) {
                        ProgressView(value: receiveLevel)
                            .tint(accent)
                            .frame(maxWidth: .infinity)

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
                    title: "Doppler Effect Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .onAppear {
                updateAudio()
            }
            .onDisappear {
                audio.stop()
            }
            .onReceive(tick) { _ in
                stepDoppler()
            }
        }
    }

    private var soundStrip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.76))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.22), lineWidth: 1.1))

            Canvas { canvas, size in
                var path = Path()
                for index in 0...160 {
                    let t = Double(index) / 160
                    let x = t * size.width
                    let frequency = 5 + t * 22
                    let amplitude = 0.12 + t * 0.22
                    let y = size.height * 0.5 + CGFloat(sin((t * frequency + wavePhase) * .pi * 2) * amplitude) * size.height
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                canvas.stroke(path, with: .linearGradient(
                    Gradient(colors: [.purple.opacity(0.75), accent.opacity(0.95), Color.mathGold.opacity(0.95)]),
                    startPoint: CGPoint(x: 0, y: size.height / 2),
                    endPoint: CGPoint(x: size.width, y: size.height / 2)
                ), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    private var dopplerField: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let sourcePoint = point(sourcePosition, in: size)
            let micPoint = point(microphone, in: size)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.1), Color(red: 0.01, green: 0.012, blue: 0.018), .black],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(size.width, size.height) * 0.72
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))

                Canvas { canvas, size in
                    drawDopplerWaves(canvas: &canvas, size: size)
                    var axis = Path()
                    axis.move(to: CGPoint(x: size.width * 0.11, y: micPoint.y))
                    axis.addLine(to: CGPoint(x: size.width * 0.91, y: micPoint.y))
                    canvas.stroke(axis, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.2, dash: [9, 9]))
                }

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.8), lineWidth: 2)
                        .frame(width: 82, height: 82)
                        .shadow(color: accent.opacity(receiveLevel > 0.92 ? 0.9 : 0.35), radius: receiveLevel > 0.92 ? 26 : 12)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .position(micPoint)

                Circle()
                    .fill(.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: .white.opacity(0.86), radius: dragging ? 22 : 12)
                    .position(sourcePoint)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragging = true
                                sourcePosition = CGPoint(
                                    x: max(0.18, min(0.76, Double(value.location.x / size.width))),
                                    y: max(0.2, min(0.78, Double(value.location.y / size.height)))
                                )
                                updateAudio()
                            }
                            .onEnded { _ in
                                dragging = false
                            }
                    )
            }
        }
    }

    private func stepDoppler() {
        guard !completed else { return }
        wavePhase += 0.018 + receiveLevel * 0.035
        let closeness = dopplerCloseness()
        receiveLevel = min(1, receiveLevel + closeness * closeness * 0.006)
        updateAudio()
        if receiveLevel >= 1 {
            completed = true
            audio.stop()
            HapticPlayer.playCompletionTap()
        }
    }

    private func drawDopplerWaves(canvas: inout GraphicsContext, size: CGSize) {
        let source = point(sourcePosition, in: size)
        let mic = point(microphone, in: size)
        for index in 0..<24 {
            let base = CGFloat(index) * 34 + CGFloat((wavePhase.truncatingRemainder(dividingBy: 1)) * 34)
            let distance = max(1, hypot(mic.x - source.x, mic.y - source.y))
            let approach = max(0.28, 1 - CGFloat(dopplerCloseness()) * 0.62)
            let radius = base * approach
            guard radius > 12 else { continue }
            let opacity = max(0.03, 0.42 - Double(index) * 0.014)
            let stretchX = max(0.5, min(1.4, 1 + (mic.x - source.x) / distance * (1 - approach)))
            let stretchY = max(0.5, min(1.4, 1 + (mic.y - source.y) / distance * (1 - approach)))
            let rect = CGRect(x: source.x - radius * stretchX, y: source.y - radius * stretchY, width: radius * 2 * stretchX, height: radius * 2 * stretchY)
            canvas.stroke(Path(ellipseIn: rect), with: .color(accent.opacity(opacity)), lineWidth: 1.2)
        }
    }

    private func updateAudio() {
        let closeness = dopplerCloseness()
        audio.setBlend(closeness)
    }

    private func reset() {
        sourcePosition = CGPoint(x: 0.32, y: 0.58)
        receiveLevel = 0
        completed = false
        dragging = false
        wavePhase = 0
        updateAudio()
    }

    private func point(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    private func dopplerCloseness() -> Double {
        let dx = microphone.x - sourcePosition.x
        let dy = microphone.y - sourcePosition.y
        return max(0, 1 - sqrt(dx * dx + dy * dy) / 0.66)
    }
}

final class DopplerDashAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private var blend: Double = 0
    private var phases = [0.0, 0.0, 0.0]
    private let lock = NSLock()

    private lazy var sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self else { return noErr }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        self.lock.lock()
        let blend = self.blend
        var phases = self.phases
        self.lock.unlock()
        let root = 174.61 + blend * 92.0
        let frequencies = [root, root * 1.2599, root * 1.4983]

        for frame in 0..<Int(frameCount) {
            var value = 0.0
            for index in phases.indices {
                value += sin(phases[index]) * (index == 0 ? 0.052 : 0.034)
                phases[index] += 2 * .pi * frequencies[index] / self.sampleRate
                if phases[index] > 2 * .pi { phases[index] -= 2 * .pi }
            }
            let shimmer = sin(phases[0] * 0.5) * 0.012
            let sample = Float((value + shimmer) * 0.72)
            for buffer in buffers {
                let data = buffer.mData!.assumingMemoryBound(to: Float.self)
                data[frame] = sample
            }
        }

        self.lock.lock()
        self.phases = phases
        self.lock.unlock()
        return noErr
    }

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func setBlend(_ blend: Double) {
        if !engine.isRunning {
            try? engine.start()
        }
        lock.lock()
        self.blend = max(0, min(1, blend))
        lock.unlock()
    }

    func stop() {
        engine.stop()
    }
}
