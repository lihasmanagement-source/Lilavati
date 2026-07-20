import SwiftUI
import Combine
import AVFoundation

struct MathItFifthsMemoryGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var audio = FifthsMemoryAudio()
    @State private var stageIndex = 0
    @State private var input: [Int] = []
    @State private var litNote: Int?
    @State private var matchedNotes: Set<Int> = []
    @State private var playing = false
    @State private var completed = false
    @State private var wrongPulse = false

    private let notes = ["C", "G", "D", "A", "E", "B", "F#/Gb", "C#/Db", "Ab", "Eb", "Bb", "F"]
    private let stages = [
        [0, 5, 10],
        [0, 5, 10, 3],
        [0, 5, 10, 3, 8],
        [0, 5, 10, 3, 8, 1],
        [0, 5, 10, 3, 8, 1, 6, 11, 4, 9, 2, 7]
    ]
    private var sequence: [Int] { stages[stageIndex] }

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

                    fifthsWheel
                        .frame(height: min(560, proxy.size.height * 0.68))
                        .padding(.horizontal, 18)

                    HStack(spacing: 12) {
                        Button(action: playSequence) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(playing)

                        Button(action: resetStage) {
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    playSequence()
                }
            }
        }
    }

    private var fifthsWheel: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.51)
            let radius = min(size.width, size.height) * 0.36

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.11), Color(red: 0.01, green: 0.012, blue: 0.018), .black],
                            center: .center,
                            startRadius: 30,
                            endRadius: max(size.width, size.height) * 0.72
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(wrongPulse ? .red.opacity(0.8) : .white.opacity(0.12), lineWidth: 1.2))

                Canvas { canvas, _ in
                    var circle = Path()
                    circle.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    canvas.stroke(circle, with: .color(accent.opacity(0.58)), lineWidth: 2)

                    for pair in matchedPairs() {
                        let a = notePoint(pair.0, center: center, radius: radius)
                        let b = notePoint(pair.1, center: center, radius: radius)
                        var line = Path()
                        line.move(to: a)
                        line.addLine(to: b)
                        canvas.stroke(line, with: .color(accent.opacity(0.5)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }

                    for index in 0..<12 {
                        let p = notePoint(index, center: center, radius: radius)
                        var tick = Path()
                        let angle = noteAngle(index)
                        tick.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * (radius - 13), y: center.y + CGFloat(sin(angle)) * (radius - 13)))
                        tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * (radius + 13), y: center.y + CGFloat(sin(angle)) * (radius + 13)))
                        canvas.stroke(tick, with: .color(.white.opacity(0.24)), lineWidth: 1)
                        canvas.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(.white.opacity(0.25)))
                    }
                }

                ForEach(0..<12, id: \.self) { index in
                    let p = notePoint(index, center: center, radius: radius)
                    Button(action: { tapNote(index) }) {
                        ZStack {
                            Circle()
                                .fill(noteColor(index).opacity(matchedNotes.contains(index) || litNote == index || input.contains(index) ? 0.95 : 0.2))
                                .frame(width: 58, height: 58)
                                .overlay(Circle().stroke(.white.opacity(litNote == index ? 1 : 0.58), lineWidth: litNote == index ? 3 : 1.5))
                                .shadow(color: noteColor(index).opacity(litNote == index ? 0.95 : 0.35), radius: litNote == index ? 22 : 8)
                            Text(notes[index])
                                .font(.system(size: notes[index].count > 2 ? 11 : 18, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.85), radius: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(playing || completed)
                    .position(p)
                }
            }
        }
    }

    private func playSequence() {
        guard !playing && !completed else { return }
        playing = true
        input.removeAll()
        for (offset, note) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(offset) * 0.52) {
                litNote = note
                audio.play(note: note)
                HapticPlayer.playLightTap()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(offset) * 0.52 + 0.32) {
                if litNote == note { litNote = nil }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(sequence.count) * 0.52 + 0.12) {
            playing = false
        }
    }

    private func tapNote(_ index: Int) {
        guard !playing && !completed else { return }
        audio.play(note: index)
        HapticPlayer.playLightTap()
        litNote = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if litNote == index { litNote = nil }
        }

        let expected = sequence[input.count]
        guard index == expected else {
            pulseWrong()
            return
        }
        input.append(index)
        matchedNotes.insert(index)

        if input.count == sequence.count {
            completeStage()
        }
    }

    private func completeStage() {
        HapticPlayer.playCompletionTap()
        if stageIndex == stages.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
                completed = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                stageIndex += 1
                input.removeAll()
                playSequence()
            }
        }
    }

    private func pulseWrong() {
        wrongPulse = true
        input.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            wrongPulse = false
        }
    }

    private func resetStage() {
        input.removeAll()
        litNote = nil
        wrongPulse = false
        playSequence()
    }

    private func reset() {
        stageIndex = 0
        input.removeAll()
        litNote = nil
        matchedNotes.removeAll()
        playing = false
        completed = false
        wrongPulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            playSequence()
        }
    }

    private func matchedPairs() -> [(Int, Int)] {
        zip(sequence.dropLast(), sequence.dropFirst()).compactMap { a, b in
            matchedNotes.contains(a) && matchedNotes.contains(b) ? (a, b) : nil
        }
    }

    private func notePoint(_ index: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = noteAngle(index)
        return CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
    }

    private func noteAngle(_ index: Int) -> Double {
        -.pi / 2 + Double(index) / 12.0 * .pi * 2
    }

    private func noteColor(_ index: Int) -> Color {
        Color(hue: Double(index) / 12.0, saturation: 0.82, brightness: 0.96)
    }
}

final class FifthsMemoryAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private let frequencies: [Double] = [261.63, 392.0, 293.66, 440.0, 329.63, 493.88, 369.99, 277.18, 415.3, 311.13, 466.16, 349.23]

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func play(note: Int) {
        if !engine.isRunning {
            try? engine.start()
        }
        guard let buffer = makeBuffer(frequency: frequencies[note % frequencies.count]) else { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    private func makeBuffer(frequency: Double) -> AVAudioPCMBuffer? {
        let duration = 0.34
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let attack = min(1, t / 0.03)
            let release = min(1, (duration - t) / 0.12)
            let envelope = max(0, min(attack, release))
            let tone = sin(.pi * 2 * frequency * t) + 0.18 * sin(.pi * 4 * frequency * t)
            channel[frame] = Float(tone * envelope * 0.18)
        }
        return buffer
    }
}
