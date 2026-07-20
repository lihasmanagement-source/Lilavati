import SwiftUI
import Combine
import AVFoundation

struct MathItHarmonicLadderGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var audio = HarmonicLadderAudio()
    @State private var placedDenominators: [Int] = []
    @State private var completed = false
    @State private var wrongPulse = false
    @State private var glowPulse = false
    @State private var wavePhase: Double = 0
    @State private var ballStep = 0
    @State private var ballJumping = false

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let denominators = [1, 2, 3, 4, 5]
    private var nextDenominator: Int? { denominators.first { !placedDenominators.contains($0) } }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 12) {
                    VStack(spacing: 7) {
                        Text("LEVEL \(concept.number)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        Text("HARMONIC LADDER")
                            .font(.trajan(36))
                            .tracking(2)
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))
                    }
                    .padding(.horizontal, 58)

                    HStack(spacing: 14) {
                        fractionRack
                            .frame(width: min(150, proxy.size.width * 0.18))
                        harmonicField
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: min(600, proxy.size.height * 0.68))
                    .padding(.horizontal, 18)

                    HStack(spacing: 12) {
                        ProgressView(value: Double(placedDenominators.count) / Double(denominators.count))
                            .tint(accent)
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
                wavePhase += 0.018
            }
        }
    }

    private var fractionRack: some View {
        VStack(spacing: 12) {
            ForEach(denominators.reversed(), id: \.self) { denominator in
                Button(action: { place(denominator) }) {
                    VStack(spacing: 2) {
                        Text("1")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                        Rectangle()
                            .fill(.white.opacity(0.8))
                            .frame(width: 34, height: 2)
                        Text("\(denominator)")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(placedDenominators.contains(denominator) ? .white.opacity(0.25) : harmonicColor(denominator))
                    .frame(width: 72, height: 76)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(harmonicColor(denominator).opacity(placedDenominators.contains(denominator) ? 0.22 : 0.9), lineWidth: 1.6))
                    .shadow(color: harmonicColor(denominator).opacity(placedDenominators.contains(denominator) ? 0 : 0.36), radius: 10)
                }
                .buttonStyle(.plain)
                .disabled(placedDenominators.contains(denominator) || completed)
            }
        }
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(wrongPulse ? .red.opacity(0.8) : accent.opacity(0.22), lineWidth: 1.1))
    }

    private var harmonicField: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let stringX = size.width * 0.34
            let bottomY = size.height * 0.86
            let topY = size.height * 0.1
            let goal = CGPoint(x: size.width * 0.72, y: topY + 24)
            let ballY = ballY(in: size)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.1), Color(red: 0.01, green: 0.012, blue: 0.018), .black],
                            center: .center,
                            startRadius: 30,
                            endRadius: max(size.width, size.height) * 0.74
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        jumpBall()
                    }

                Canvas { canvas, size in
                    var string = Path()
                    string.move(to: CGPoint(x: stringX, y: topY))
                    string.addLine(to: CGPoint(x: stringX, y: bottomY))
                    canvas.stroke(string, with: .color(.white.opacity(0.86)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                    for denominator in placedDenominators {
                        drawHarmonic(denominator, stringX: stringX, topY: topY, bottomY: bottomY, canvas: &canvas, size: size)
                    }
                }

                ForEach(placedDenominators, id: \.self) { denominator in
                    let y = levelY(denominator, topY: topY, bottomY: bottomY)
                    let width = platformWidth(for: denominator, in: size)
                    Capsule()
                        .fill(harmonicColor(denominator).opacity(0.34))
                        .frame(width: width, height: 13)
                        .overlay(Capsule().stroke(harmonicColor(denominator), lineWidth: 2))
                        .shadow(color: harmonicColor(denominator).opacity(0.6), radius: 12)
                        .position(x: stringX + width / 2, y: y)

                    Text("1/\(denominator)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(harmonicColor(denominator))
                        .position(x: stringX + width + 36, y: y - 20)
                }

                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 66, height: 66)
                    .shadow(color: .white.opacity(glowPulse ? 1 : 0.42), radius: glowPulse ? 24 : 10)
                    .position(goal)

                Circle()
                    .fill(.white)
                    .frame(width: 34, height: 34)
                    .shadow(color: .white.opacity(0.86), radius: 12)
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
                    .onTapGesture {
                        jumpBall()
                    }
                    .accessibilityLabel("Jump ball")
                    .accessibilityAddTraits(.isButton)
                    .position(x: ballX(in: size, stringX: stringX), y: ballY)
            }
        }
    }

    private func place(_ denominator: Int) {
        guard !completed else { return }
        guard denominator == nextDenominator else {
            wrongPulse = true
            HapticPlayer.playLightTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                wrongPulse = false
            }
            return
        }

        placedDenominators.append(denominator)
        audio.play(denominator: denominator)
        HapticPlayer.playLightTap()

        if placedDenominators.count == denominators.count {
            glowPulse = true
            ballJumping = true
        }
    }

    private func reset() {
        placedDenominators.removeAll()
        completed = false
        wrongPulse = false
        glowPulse = false
        wavePhase = 0
        ballStep = 0
        ballJumping = false
    }

    private func ballY(in size: CGSize) -> CGFloat {
        let bottomY = size.height * 0.86
        guard ballStep > 0 else { return bottomY - 20 }
        if ballStep > denominators.count {
            return size.height * 0.1 + 24
        }
        return levelY(ballStep, topY: size.height * 0.1, bottomY: bottomY) - 28
    }

    private func ballX(in size: CGSize, stringX: CGFloat) -> CGFloat {
        guard ballStep > 0 else { return stringX - size.width * 0.17 }
        if ballStep > denominators.count {
            return size.width * 0.72
        }
        return stringX + platformWidth(for: ballStep, in: size)
    }

    private func levelY(_ denominator: Int, topY: CGFloat, bottomY: CGFloat) -> CGFloat {
        let index = CGFloat(denominator - 1)
        return bottomY + (topY - bottomY) * (index / CGFloat(max(1, denominators.count - 1)))
    }

    private func platformWidth(for denominator: Int, in size: CGSize) -> CGFloat {
        size.width * 0.48 / CGFloat(denominator)
    }

    private func jumpBall() {
        guard ballJumping && !completed else { return }
        guard ballStep < denominators.count + 1 else { return }
        let nextStep = ballStep + 1
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            ballStep = nextStep
        }
        HapticPlayer.playLightTap()

        if nextStep <= denominators.count {
            audio.play(denominator: nextStep)
        } else {
            audio.playChord()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                completed = true
            }
        }
    }

    private func drawHarmonic(_ denominator: Int, stringX: CGFloat, topY: CGFloat, bottomY: CGFloat, canvas: inout GraphicsContext, size: CGSize) {
        let color = harmonicColor(denominator)
        let segments = max(1, denominator)
        let height = bottomY - topY
        for segment in 0..<segments {
            let segmentTop = topY + height * CGFloat(segment) / CGFloat(segments)
            let segmentBottom = topY + height * CGFloat(segment + 1) / CGFloat(segments)
            var wave = Path()
            for step in 0...36 {
                let t = CGFloat(step) / 36
                let y = segmentTop + (segmentBottom - segmentTop) * t
                let amplitude = sin(Double(t) * .pi) * 34
                let x = stringX + CGFloat(sin((Double(t) + wavePhase) * .pi * 2)) * CGFloat(amplitude)
                if step == 0 {
                    wave.move(to: CGPoint(x: x, y: y))
                } else {
                    wave.addLine(to: CGPoint(x: x, y: y))
                }
            }
            canvas.stroke(wave, with: .color(color.opacity(0.72)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    private func harmonicColor(_ denominator: Int) -> Color {
        switch denominator {
        case 1: return .white.opacity(0.92)
        case 2: return Color(red: 0.48, green: 1.0, blue: 0.34)
        case 3: return Color(red: 0.12, green: 0.96, blue: 0.92)
        case 4: return Color(red: 0.2, green: 0.55, blue: 1.0)
        default: return Color(red: 0.78, green: 0.28, blue: 1.0)
        }
    }
}

final class HarmonicLadderAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func play(denominator: Int) {
        let frequency = 174.61 * Double(denominator)
        playBuffer(frequencies: [frequency], duration: 0.42)
    }

    func playChord() {
        playBuffer(frequencies: [174.61, 349.23, 523.25, 698.46, 880.0], duration: 0.95)
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    private func playBuffer(frequencies: [Double], duration: Double) {
        if !engine.isRunning {
            try? engine.start()
        }
        guard let buffer = makeBuffer(frequencies: frequencies, duration: duration) else { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private func makeBuffer(frequencies: [Double], duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let attack = min(1, t / 0.04)
            let release = min(1, (duration - t) / 0.2)
            let envelope = max(0, min(attack, release))
            let tone = frequencies.reduce(0.0) { partial, frequency in
                partial + sin(.pi * 2 * frequency * t) * 0.16 + sin(.pi * 4 * frequency * t) * 0.035
            } / Double(max(1, frequencies.count))
            channel[frame] = Float(tone * envelope)
        }
        return buffer
    }
}
