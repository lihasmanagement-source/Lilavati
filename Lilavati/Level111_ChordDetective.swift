import SwiftUI
import Combine
import AVFoundation

struct MathItChordDetectiveGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var audio = ChordDetectiveAudio()
    @State private var stageIndex = 0
    @State private var selectedNotes: [Int] = []
    @State private var completed = false
    @State private var wrongPulse = false
    @State private var glowPulse = false

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let stages = [
        [0, 7],
        [2, 9],
        [4, 11],
        [1, 6],
        [3, 10]
    ]
    private var targetNotes: [Int] { stages[stageIndex] }
    private var solved: Bool { selectedNotes.sorted() == targetNotes.sorted() }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 12) {
                    chordHeader
                        .padding(.horizontal, 58)

                    HStack(spacing: 16) {
                        listenPanel
                        chordColorHint
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 16) {
                        noteWheel
                            .frame(maxWidth: .infinity)
                        selectionPanel
                            .frame(width: min(250, proxy.size.width * 0.26))
                    }
                    .padding(.horizontal, 28)

                    launchLane
                        .frame(height: 88)
                        .padding(.horizontal, 28)
                }
                .padding(.top, 34)
                .padding(.bottom, 72)

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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    playChord()
                }
            }
        }
    }

    private var chordHeader: some View {
        VStack(spacing: 7) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.trajan(35))
                .tracking(2)
                .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))

        }
    }

    private var listenPanel: some View {
        ZStack {
            Canvas { canvas, size in
                var waveform = Path()
                for index in 0...120 {
                    let x = CGFloat(index) / 120 * size.width
                    let pulse = sin(Double(index) * 0.31) * sin(Double(index) * 0.09)
                    let burst = index < 38 || index > 82 ? 0.35 : 0.12
                    let y = size.height * 0.5 + CGFloat(pulse) * size.height * burst
                    if index == 0 { waveform.move(to: CGPoint(x: x, y: y)) } else { waveform.addLine(to: CGPoint(x: x, y: y)) }
                }
                canvas.stroke(waveform, with: .color(accent.opacity(0.82)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }

            Button(action: playChord) {
                Image(systemName: "play.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 76, height: 76)
                    .background(.black, in: Circle())
                    .overlay(Circle().stroke(accent.opacity(0.9), lineWidth: 2.2))
                    .shadow(color: accent.opacity(0.55), radius: 18)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 98)
        .padding(18)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.22), lineWidth: 1.1))
    }

    private var chordColorHint: some View {
        ZStack {
            Circle()
                .fill(chordColor(notes: targetNotes))
                .frame(width: 86, height: 86)
                .shadow(color: chordColor(notes: targetNotes).opacity(0.72), radius: 22)
            Circle()
                .stroke(.white.opacity(0.74), lineWidth: 2)
                .frame(width: 104, height: 104)
        }
        .frame(width: 150, height: 112)
        .padding(16)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.22), lineWidth: 1.1))
    }

    private var noteWheel: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
            let radius = min(size.width, size.height) * 0.34

            ZStack {
                Canvas { canvas, _ in
                    var ring = Path()
                    ring.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    canvas.stroke(ring, with: .color(.white.opacity(0.34)), lineWidth: 1.2)

                    for index in 0..<12 {
                        let a = noteAngle(index)
                        let p1 = CGPoint(x: center.x + CGFloat(cos(a)) * radius * 0.24, y: center.y + CGFloat(sin(a)) * radius * 0.24)
                        let p2 = CGPoint(x: center.x + CGFloat(cos(a + .pi * 0.84)) * radius * 0.74, y: center.y + CGFloat(sin(a + .pi * 0.84)) * radius * 0.74)
                        var line = Path()
                        line.move(to: p1)
                        line.addLine(to: p2)
                        canvas.stroke(line, with: .color(.white.opacity(0.15)), lineWidth: 0.9)
                    }
                }

                ForEach(0..<12, id: \.self) { index in
                    let angle = noteAngle(index)
                    let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
                    Button(action: { selectNote(index) }) {
                        ZStack {
                            Circle()
                                .fill(noteColor(index))
                                .frame(width: 42, height: 42)
                                .overlay(Circle().fill(.black.opacity(0.18)))
                                .overlay(Circle().stroke(.white.opacity(selectedNotes.contains(index) ? 1 : 0.54), lineWidth: selectedNotes.contains(index) ? 3 : 1.5))
                                .shadow(color: noteColor(index).opacity(selectedNotes.contains(index) ? 0.9 : 0.46), radius: selectedNotes.contains(index) ? 18 : 8)
                            Text(noteNames[index])
                                .font(.system(size: noteNames[index].count > 1 ? 13 : 16, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.8), radius: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(point)
                }
            }
            .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(wrongPulse ? .red.opacity(0.82) : accent.opacity(0.18), lineWidth: 1.2))
        }
    }

    private var selectionPanel: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 11) {
                ForEach(0..<12, id: \.self) { index in
                    Button(action: { selectNote(index) }) {
                        VStack(spacing: 4) {
                            Text(noteNames[index])
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.72))
                            Circle()
                                .fill(selectedNotes.contains(index) ? noteColor(index) : .black)
                                .frame(width: 34, height: 34)
                                .overlay(Circle().stroke(selectedNotes.contains(index) ? .white.opacity(0.9) : .white.opacity(0.28), lineWidth: 1.4))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button(action: playSelectedChord) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(selectedNotes.count == 2 ? accent : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(.black.opacity(0.58), in: Capsule())
                        .overlay(Capsule().stroke(accent.opacity(selectedNotes.count == 2 ? 0.42 : 0.18), lineWidth: 1.1))
                }
                .buttonStyle(.plain)

                Button(action: submit) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(solved ? .black : .white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(solved ? accent : .white.opacity(0.06), in: Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.25), lineWidth: 1.1))
                }
                .buttonStyle(.plain)
            }

            Button(action: clearSelection) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(.black.opacity(0.58), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.22), lineWidth: 1.1))
    }

    private var launchLane: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let start = CGPoint(x: size.width * 0.25, y: size.height * 0.72)
            let end = CGPoint(x: size.width * 0.7, y: size.height * 0.34)

            ZStack {
                Canvas { canvas, _ in
                    var ground = Path()
                    ground.move(to: CGPoint(x: 0, y: start.y + 18))
                    ground.addLine(to: CGPoint(x: size.width, y: start.y + 18))
                    canvas.stroke(ground, with: .color(.white.opacity(0.22)), lineWidth: 1.2)
                }

                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 54, height: 54)
                    .shadow(color: .white.opacity(glowPulse ? 0.9 : 0.42), radius: glowPulse ? 18 : 10)
                    .position(end)
            }
        }
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.2), lineWidth: 1))
    }

    private func noteAngle(_ index: Int) -> Double {
        -.pi / 2 + Double(index) / 12.0 * .pi * 2
    }

    private func noteColor(_ index: Int) -> Color {
        let component = noteColorComponent(index)
        return Color(red: component.red, green: component.green, blue: component.blue)
    }

    private func chordColor(notes: [Int]) -> Color {
        let components = notes.map(noteColorComponent)
        let count = Double(max(1, components.count))
        let red = gammaEncode(components.reduce(0) { $0 + gammaDecode($1.red) } / count)
        let green = gammaEncode(components.reduce(0) { $0 + gammaDecode($1.green) } / count)
        let blue = gammaEncode(components.reduce(0) { $0 + gammaDecode($1.blue) } / count)
        return Color(red: red, green: green, blue: blue)
    }

    private func gammaDecode(_ value: Double) -> Double {
        pow(max(0, min(1, value)), 2.2)
    }

    private func gammaEncode(_ value: Double) -> Double {
        pow(max(0, min(1, value)), 1 / 2.2)
    }

    private func noteColorComponent(_ index: Int) -> (red: Double, green: Double, blue: Double) {
        switch index % 12 {
        case 0: return (0.98, 0.14, 0.18)
        case 1: return (1.0, 0.34, 0.13)
        case 2: return (1.0, 0.54, 0.0)
        case 3: return (0.95, 0.82, 0.0)
        case 4: return (0.42, 0.88, 0.12)
        case 5: return (0.0, 0.78, 0.48)
        case 6: return (0.0, 0.78, 0.78)
        case 7: return (0.28, 0.72, 0.96)
        case 8: return (0.18, 0.38, 0.9)
        case 9: return (0.62, 0.22, 0.9)
        case 10: return (0.86, 0.18, 0.62)
        default: return (0.92, 0.12, 0.36)
        }
    }

    private func selectNote(_ index: Int) {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        if selectedNotes.contains(index) {
            selectedNotes.removeAll { $0 == index }
        } else {
            if selectedNotes.count == 2 {
                selectedNotes.removeFirst()
            }
            selectedNotes.append(index)
        }
    }

    private func clearSelection() {
        selectedNotes.removeAll()
        wrongPulse = false
        HapticPlayer.playLightTap()
    }

    private func playChord() {
        audio.play(notes: targetNotes)
        HapticPlayer.playLightTap()
    }

    private func playSelectedChord() {
        guard selectedNotes.count == 2 else {
            pulseWrong()
            return
        }
        audio.play(notes: selectedNotes)
        HapticPlayer.playLightTap()
    }

    private func submit() {
        guard selectedNotes.count == 2 else {
            pulseWrong()
            return
        }
        if solved {
            glowPulse = true
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                if stageIndex == stages.count - 1 {
                    completed = true
                } else {
                    stageIndex += 1
                    selectedNotes.removeAll()
                    glowPulse = false
                    playChord()
                }
            }
        } else {
            pulseWrong()
        }
    }

    private func pulseWrong() {
        wrongPulse = true
        HapticPlayer.playLightTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            wrongPulse = false
        }
    }

    private func reset() {
        stageIndex = 0
        selectedNotes.removeAll()
        completed = false
        wrongPulse = false
        glowPulse = false
    }
}

final class ChordDetectiveAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private let frequencies: [Double] = [261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.0, 415.3, 440.0, 466.16, 493.88]

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func play(notes: [Int]) {
        if !engine.isRunning {
            try? engine.start()
        }
        guard let buffer = makeBuffer(notes: notes) else { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    private func makeBuffer(notes: [Int]) -> AVAudioPCMBuffer? {
        let duration = 0.9
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let attack = min(1, t / 0.04)
            let release = min(1, (duration - t) / 0.22)
            let envelope = max(0, min(attack, release))
            var value: Double = 0
            for note in notes {
                let frequency = frequencies[note % frequencies.count]
                value += sin(.pi * 2 * frequency * t) + 0.24 * sin(.pi * 4 * frequency * t)
            }
            channel[frame] = Float(value / Double(max(1, notes.count)) * envelope * 0.22)
        }
        return buffer
    }
}
