import AVFAudio
import Combine
import SwiftUI

struct MathItLevelOneHundredTwentyFourView: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let ink = Color(red: 0.022, green: 0.03, blue: 0.04)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var recorder = VoiceRecorderModel()

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                ink.ignoresSafeArea()

                VStack(spacing: compact ? 18 : 26) {
                    header
                        .padding(.top, compact ? 22 : 42)

                    ScrollView(.vertical, showsIndicators: false) {
                        recordingSurface(compact: compact)
                            .frame(maxWidth: 720)
                            .padding(.bottom, compact ? 72 : 92)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .padding(.horizontal, compact ? 18 : 28)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear { recorder.prepareReferenceTone() }
        .onChange(of: recorder.gameComplete) { _, complete in
            if complete { onContinue() }
        }
        .onDisappear { recorder.stopAll() }
    }

    private var header: some View {
        VStack(spacing: 7) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(gold)

            EmptyView()
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func recordingSurface(compact: Bool) -> some View {
        VStack(spacing: compact ? 18 : 24) {
            waveform
                .frame(height: compact ? 132 : 180)

            Text(recorder.timeText)
                .font(.system(size: compact ? 34 : 42, weight: .light, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            statusSymbol

            HStack(spacing: compact ? 16 : 22) {
                middleCButton
                recordButton
                playButton
                deleteButton
            }
            .frame(height: 88)

            if let message = recorder.message {
                Text(message)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(recorder.permissionDenied ? Color.red.opacity(0.9) : .white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 30)
            } else {
                Color.clear.frame(height: 30)
            }

            if recorder.hasRecording {
                Divider().overlay(.white.opacity(0.12))

                VoicePianoKeyboard(recorder: recorder, cyan: cyan, gold: gold)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, compact ? 18 : 28)
        .padding(.vertical, compact ? 22 : 30)
        .background(Color(red: 0.04, green: 0.052, blue: 0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(gold.opacity(0.28), lineWidth: 1))
    }

    private var middleCButton: some View {
        Button {
            recorder.toggleReferenceTone()
        } label: {
            VStack(spacing: 11) {
                Image(systemName: recorder.isPlayingReference ? "stop.fill" : "play.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(ink)
                    .frame(width: 54, height: 54)
                    .background(gold, in: Circle())
                Text("MIDDLE C")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(gold.opacity(0.72))
            }
        }
        .buttonStyle(.plain)
        .disabled(recorder.isRecording || recorder.isPlaying)
        .accessibilityLabel(recorder.isPlayingReference ? "Stop middle C" : "Play middle C")
    }

    private var waveform: some View {
        GeometryReader { geo in
            let bars = recorder.waveformSamples
            HStack(alignment: .center, spacing: 3) {
                ForEach(bars.indices, id: \.self) { index in
                    Capsule()
                        .fill(waveformColor(for: index, count: bars.count))
                        .frame(
                            width: max(2, (geo.size.width - CGFloat(bars.count - 1) * 3) / CGFloat(bars.count)),
                            height: max(3, geo.size.height * CGFloat(bars[index]))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .accessibilityHidden(true)
    }

    private func waveformColor(for index: Int, count: Int) -> Color {
        if recorder.isRecording { return index >= count - 5 ? gold : cyan.opacity(0.82) }
        if recorder.isPlaying { return cyan }
        return recorder.hasRecording ? cyan.opacity(0.62) : .white.opacity(0.12)
    }

    private var statusSymbol: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(recorder.isRecording ? Color.red : recorder.isPlaying ? cyan : recorder.isPlayingReference ? gold : .white.opacity(0.22))
                .frame(width: 8, height: 8)
            Image(systemName: recorder.isRecording ? "mic.fill" : (recorder.isPlaying || recorder.isPlayingReference) ? "speaker.wave.2.fill" : "mic")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(height: 18)
        .accessibilityLabel(recorder.statusText)
    }

    private var recordButton: some View {
        Button {
            recorder.toggleRecording()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.7), lineWidth: 2)
                        .frame(width: 62, height: 62)
                    RoundedRectangle(cornerRadius: recorder.isRecording ? 5 : 28)
                        .fill(Color.red)
                        .frame(width: recorder.isRecording ? 24 : 44, height: recorder.isRecording ? 24 : 44)
                }
                Text(recorder.isRecording ? "STOP" : "RECORD")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Record")
    }

    private var playButton: some View {
        Button {
            recorder.togglePlayback()
        } label: {
            VStack(spacing: 11) {
                Image(systemName: recorder.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(recorder.hasRecording ? ink : .white.opacity(0.2))
                    .frame(width: 54, height: 54)
                    .background(recorder.hasRecording ? cyan : .white.opacity(0.07), in: Circle())
                Text(recorder.isPlaying ? "STOP" : "PLAYBACK")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(recorder.hasRecording ? cyan : .white.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
        .disabled(!recorder.hasRecording || recorder.isRecording)
        .accessibilityLabel(recorder.isPlaying ? "Stop playback" : "Play recording")
    }

    private var deleteButton: some View {
        Button {
            recorder.deleteRecording()
        } label: {
            VStack(spacing: 11) {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(recorder.hasRecording ? .white.opacity(0.78) : .white.opacity(0.16))
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(recorder.hasRecording ? 0.08 : 0.035), in: Circle())
                Text("DELETE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(recorder.hasRecording ? .white.opacity(0.5) : .white.opacity(0.16))
            }
        }
        .buttonStyle(.plain)
        .disabled(!recorder.hasRecording || recorder.isRecording)
        .accessibilityLabel("Delete recording")
    }
}

private struct VoicePianoKeyboard: View {
    @ObservedObject var recorder: VoiceRecorderModel
    let cyan: Color
    let gold: Color

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "pianokeys")
                    .foregroundStyle(gold)
                Text(recorder.chordProgressText)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index <= recorder.chordIndex ? gold : .white.opacity(0.12))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            VStack(spacing: 2) {
                Text(recorder.currentChordSymbol)
                    .font(.system(size: 46, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                Text(recorder.currentChordName)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(gold.opacity(0.7))
            }
            .frame(height: 72)

            HStack(alignment: .top, spacing: 2) {
                ForEach(Array(VoiceRecorderModel.noteNames.enumerated()), id: \.offset) { index, note in
                    Button {
                        recorder.playNote(at: index)
                    } label: {
                        VStack {
                            Spacer()
                            Circle()
                                .fill(recorder.selectedKeys.contains(index) ? .white : .clear)
                                .frame(width: 5, height: 5)
                            Text(note)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(recorder.selectedKeys.contains(index) ? Color.white : Color.black.opacity(0.62))
                                .padding(.bottom, 10)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 118)
                        .background(recorder.selectedKeys.contains(index) ? Color.blue : Color.white.opacity(0.84))
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(recorder.selectedKeys.contains(index) ? cyan : .black.opacity(0.12))
                                .frame(height: recorder.selectedKeys.contains(index) ? 4 : 1)
                        }
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play \(noteName(at: index))")
                }
            }

            HStack(spacing: 12) {
                Button {
                    recorder.playSelectedChord()
                } label: {
                    Label("PLAY CHORD", systemImage: "play.fill")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(recorder.selectedKeys.isEmpty ? cyan.opacity(0.25) : cyan)
                }
                .buttonStyle(.plain)
                .disabled(recorder.selectedKeys.isEmpty || recorder.chordSucceeded)

                Button {
                    recorder.resetChordSelection()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(recorder.selectedKeys.isEmpty || recorder.chordSucceeded)
                .accessibilityLabel("Reset selected notes")
            }

            if let feedback = recorder.chordFeedback {
                HStack(spacing: 7) {
                    Image(systemName: recorder.chordSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(feedback)
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(recorder.chordSucceeded ? cyan : Color.red.opacity(0.88))
                .frame(height: 18)
            } else {
                Color.clear.frame(height: 18)
            }
        }
    }

    private func noteName(at index: Int) -> String {
        index == 7 ? "C five" : "\(VoiceRecorderModel.noteNames[index]) four"
    }
}

private struct FourierLayerStack: View {
    @ObservedObject var recorder: VoiceRecorderModel
    let cyan: Color
    let gold: Color

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sum")
                    .foregroundStyle(gold)
                Text("FOURIER COMPONENTS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text("f(t) = Σ[aₙcos + bₙsin]")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.34))
            }

            ForEach(recorder.components.indices, id: \.self) { index in
                componentRow(index: index)
                if index < recorder.components.count - 1 {
                    Divider().overlay(.white.opacity(0.07))
                }
            }
        }
    }

    private func componentRow(index: Int) -> some View {
        let component = recorder.components[index]
        return VStack(spacing: 9) {
            HStack(spacing: 9) {
                Button {
                    recorder.toggleMute(at: index)
                } label: {
                    Image(systemName: component.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(component.isMuted ? .white.opacity(0.25) : cyan)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(component.isMuted ? "Unmute harmonic \(index + 1)" : "Mute harmonic \(index + 1)")

                VStack(alignment: .leading, spacing: 2) {
                    Text("H\(index + 1)  ·  \(Int(component.frequency)) Hz")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(component.isMuted ? .white.opacity(0.25) : .white.opacity(0.78))
                    Text(String(format: "aₙ = %+.2f    bₙ = %+.2f", component.aCoefficient, component.bCoefficient))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(gold.opacity(component.isMuted ? 0.25 : 0.72))
                }

                Spacer()

                FourierMiniWave(component: component, color: component.isMuted ? .white.opacity(0.14) : cyan)
                    .frame(width: 78, height: 30)
            }

            FourierSlider(
                symbol: "A",
                value: recorder.binding(for: index, keyPath: \.amplitude),
                range: 0...2,
                valueText: String(format: "%.2f", component.amplitude),
                color: cyan
            )
            FourierSlider(
                symbol: "f",
                value: recorder.binding(for: index, keyPath: \.frequency),
                range: component.frequencyRange,
                valueText: "\(Int(component.frequency)) Hz",
                color: gold
            )
            FourierSlider(
                symbol: "φ",
                value: recorder.binding(for: index, keyPath: \.phase),
                range: -Double.pi...Double.pi,
                valueText: "\(Int(component.phase * 180 / .pi))°",
                color: Color(red: 0.96, green: 0.31, blue: 0.25)
            )
        }
        .opacity(component.isMuted ? 0.72 : 1)
    }
}

private struct FourierSlider: View {
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 16)
            Slider(value: $value, in: range)
                .tint(color)
            Text(valueText)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: 58, alignment: .trailing)
        }
    }
}

private struct FourierMiniWave: View {
    let component: FourierComponent
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let cycles = 1.4 + Double(component.frequency / 900)
            for step in 0...48 {
                let progress = Double(step) / 48
                let x = size.width * CGFloat(progress)
                let y = size.height / 2 + CGFloat(sin(progress * cycles * 2 * .pi + component.phase)) * size.height * 0.36 * CGFloat(min(1, component.amplitude))
                if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color), lineWidth: 1.4)
        }
        .accessibilityHidden(true)
    }
}

private struct FourierComponent: Identifiable {
    let id = UUID()
    let baseFrequency: Double
    var amplitude = 1.0
    var frequency: Double
    var phase = 0.0
    var isMuted = false

    init(frequency: Double) {
        baseFrequency = frequency
        self.frequency = frequency
    }

    var frequencyRange: ClosedRange<Double> {
        max(55, baseFrequency * 0.55)...min(7_500, baseFrequency * 1.8)
    }

    var aCoefficient: Double { isMuted ? 0 : amplitude * cos(phase) }
    var bCoefficient: Double { isMuted ? 0 : amplitude * sin(phase) }
}

private struct VoicePianoPlaybackVoice {
    let player: AVAudioPlayerNode
    let pitch: AVAudioUnitTimePitch
}

private struct VoiceChordChallenge {
    let symbol: String
    let name: String
    let notes: Set<Int>
}

@MainActor
private final class VoiceRecorderModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let noteNames = ["C", "D", "E", "F", "G", "A", "B", "C"]
    private static let noteSemitones = [0.0, 2.0, 4.0, 5.0, 7.0, 9.0, 11.0, 12.0]
    private static let chordChallenges = [
        VoiceChordChallenge(symbol: "C", name: "C MAJOR", notes: [0, 2, 4]),
        VoiceChordChallenge(symbol: "F", name: "F MAJOR", notes: [3, 5, 7]),
        VoiceChordChallenge(symbol: "G", name: "G MAJOR", notes: [1, 4, 6])
    ]

    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isPlayingReference = false
    @Published private(set) var hasRecording = false
    @Published private(set) var elapsed = 0.0
    @Published private(set) var waveformSamples = Array(repeating: 0.035, count: 54)
    @Published private(set) var message: String?
    @Published private(set) var permissionDenied = false
    @Published private(set) var components = [120, 240, 480, 960, 1_920, 3_840].map { FourierComponent(frequency: Double($0)) }
    @Published private(set) var noteIndex = 0.0
    @Published private(set) var selectedKeys: Set<Int> = []
    @Published private(set) var chordIndex = 0
    @Published private(set) var chordFeedback: String?
    @Published private(set) var chordSucceeded = false
    @Published private(set) var gameComplete = false

    private let maximumDuration = 4.0
    private var audioRecorder: AVAudioRecorder?
    private var playbackEngine: AVAudioEngine?
    private var playerNodes: [AVAudioPlayerNode] = []
    private var equalizers: [AVAudioUnitEQ] = []
    private var phaseDelays: [AVAudioUnitDelay] = []
    private var pitchUnit: AVAudioUnitTimePitch?
    private var preparedPlaybackBuffer: AVAudioPCMBuffer?
    private var tuningCorrectionCents: Float = 0
    private var pianoEngine: AVAudioEngine?
    private var pianoVoices: [VoicePianoPlaybackVoice] = []
    private var nextPianoVoice = 0
    private var referenceEngine: AVAudioEngine?
    private var referencePlayer: AVAudioPlayerNode?
    private var referenceBuffer: AVAudioPCMBuffer?
    private var referenceTimer: Timer?
    private var playbackDuration = 0.0
    private var meterTimer: Timer?
    private var chordAdvanceTimer: Timer?

    var currentChordSymbol: String { Self.chordChallenges[chordIndex].symbol }
    var currentChordName: String { Self.chordChallenges[chordIndex].name }
    var chordProgressText: String { "CHORD \(chordIndex + 1) OF \(Self.chordChallenges.count)" }

    var timeText: String {
        let time = elapsed
        return String(format: "%02d:%02d.%01d", Int(time) / 60, Int(time) % 60, Int((time * 10).truncatingRemainder(dividingBy: 10)))
    }

    var statusText: String {
        if isRecording { return "Recording" }
        if isPlaying { return "Playing" }
        if isPlayingReference { return "Playing middle C" }
        if hasRecording { return "Recording ready" }
        return "Ready to record"
    }

    var pitchText: String {
        let octave = selectedNoteIndex == 7 ? 5 : 4
        return String(format: "%@%d  ·  %.2f Hz", Self.noteNames[selectedNoteIndex], octave, selectedFrequency)
    }

    var selectedNoteIndex: Int {
        min(Self.noteNames.count - 1, max(0, Int(noteIndex.rounded())))
    }

    private var pitchSemitones: Double {
        Self.noteSemitones[selectedNoteIndex]
    }

    private var selectedFrequency: Double {
        261.6256 * pow(2, pitchSemitones / 12)
    }

    var pitchBinding: Binding<Double> {
        Binding(
            get: { self.noteIndex },
            set: { value in
                self.noteIndex = value.rounded()
                self.pitchUnit?.pitch = self.tuningCorrectionCents + Float(self.pitchSemitones * 100)
            }
        )
    }

    func toggleReferenceTone() {
        if isPlayingReference {
            stopReferencePlayback()
        } else {
            playReferenceTone()
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            requestPermissionAndRecord()
        }
    }

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    func playNote(at index: Int) {
        guard hasRecording, Self.noteNames.indices.contains(index) else { return }
        guard !chordSucceeded else { return }
        if isPlaying { stopPlayback() }
        selectedKeys.insert(index)
        noteIndex = Double(index)
        playPianoVoice(at: index)
    }

    func resetChordSelection() {
        guard !chordSucceeded else { return }
        selectedKeys.removeAll()
        chordFeedback = nil
        noteIndex = 0
    }

    func playSelectedChord() {
        guard !selectedKeys.isEmpty, !chordSucceeded else { return }
        if isPlaying { stopPlayback() }
        for index in selectedKeys.sorted() {
            playPianoVoice(at: index)
        }

        if selectedKeys == Self.chordChallenges[chordIndex].notes {
            chordSucceeded = true
            chordFeedback = "CHORD MATCHED"
            chordAdvanceTimer?.invalidate()
            chordAdvanceTimer = Timer.scheduledTimer(
                timeInterval: 1.2,
                target: self,
                selector: #selector(advanceChord),
                userInfo: nil,
                repeats: false
            )
        } else {
            chordFeedback = "TRY AGAIN"
        }
    }

    func toggleMute(at index: Int) {
        guard components.indices.contains(index) else { return }
        components[index].isMuted.toggle()
        updateAudioComponent(at: index)
    }

    func binding(for index: Int, keyPath: WritableKeyPath<FourierComponent, Double>) -> Binding<Double> {
        Binding(
            get: { self.components[index][keyPath: keyPath] },
            set: { value in
                self.components[index][keyPath: keyPath] = value
                self.updateAudioComponent(at: index)
            }
        )
    }

    func deleteRecording() {
        stopAll()
        try? FileManager.default.removeItem(at: recordingURL)
        hasRecording = false
        preparedPlaybackBuffer = nil
        tuningCorrectionCents = 0
        noteIndex = 0
        resetChordGame()
        elapsed = 0
        waveformSamples = Array(repeating: 0.035, count: waveformSamples.count)
        message = nil
    }

    func stopAll() {
        if isRecording { stopRecording() }
        if isPlaying { stopPlayback() }
        stopPianoEngine()
        stopReferenceTone()
        chordAdvanceTimer?.invalidate()
        chordAdvanceTimer = nil
        invalidateTimer()
    }

    private func playPianoVoice(at index: Int) {
        do {
            if preparedPlaybackBuffer == nil {
                try prepareRecordedVoice()
            }
            guard let buffer = preparedPlaybackBuffer else {
                throw VoiceRecorderError.playbackCouldNotStart
            }

            try ensurePianoEngineRunning(format: buffer.format)
            guard !pianoVoices.isEmpty else {
                throw VoiceRecorderError.playbackCouldNotStart
            }

            let voice = pianoVoices[nextPianoVoice]
            nextPianoVoice = (nextPianoVoice + 1) % pianoVoices.count
            voice.player.stop()
            voice.pitch.pitch = tuningCorrectionCents + Float(Self.noteSemitones[index] * 100)
            voice.player.scheduleBuffer(buffer, at: nil, options: [])
            voice.player.play()
        } catch {
            message = "The note could not be played."
        }
    }

    @objc private func advanceChord() {
        chordAdvanceTimer = nil
        if chordIndex + 1 < Self.chordChallenges.count {
            chordIndex += 1
            selectedKeys.removeAll()
            chordFeedback = nil
            chordSucceeded = false
            noteIndex = 0
        } else {
            gameComplete = true
        }
    }

    private func resetChordGame() {
        chordAdvanceTimer?.invalidate()
        chordAdvanceTimer = nil
        selectedKeys.removeAll()
        chordIndex = 0
        chordFeedback = nil
        chordSucceeded = false
        gameComplete = false
    }

    private func ensurePianoEngineRunning(format: AVAudioFormat) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        try session.overrideOutputAudioPort(.speaker)

        if pianoEngine == nil {
            let engine = AVAudioEngine()
            pianoVoices = (0..<12).map { _ in
                let player = AVAudioPlayerNode()
                let pitch = AVAudioUnitTimePitch()
                pitch.rate = 1
                engine.attach(player)
                engine.attach(pitch)
                engine.connect(player, to: pitch, format: format)
                engine.connect(pitch, to: engine.mainMixerNode, format: format)
                return VoicePianoPlaybackVoice(player: player, pitch: pitch)
            }
            engine.mainMixerNode.outputVolume = 0.78
            engine.prepare()
            pianoEngine = engine
            nextPianoVoice = 0
        }

        if pianoEngine?.isRunning == false {
            try pianoEngine?.start()
        }
    }

    private func stopPianoEngine() {
        guard pianoEngine != nil else { return }
        pianoVoices.forEach { $0.player.stop() }
        pianoEngine?.stop()
        pianoEngine = nil
        pianoVoices = []
        nextPianoVoice = 0
        deactivateSession()
    }

    func prepareReferenceTone() {
        do {
            try ensureReferenceToneReady()
        } catch {
            message = "Middle C could not be prepared."
        }
    }

    private func playReferenceTone() {
        if isPlaying { stopPlayback() }
        stopPianoEngine()

        do {
            try ensureReferenceToneReady()
            guard let player = referencePlayer, let buffer = referenceBuffer else {
                throw VoiceRecorderError.playbackCouldNotStart
            }

            player.stop()
            player.scheduleBuffer(buffer)
            player.play()
            isPlayingReference = true
            message = "Match this note with your voice"
            referenceTimer?.invalidate()
            referenceTimer = Timer.scheduledTimer(
                timeInterval: 1.5,
                target: self,
                selector: #selector(referenceTimerFired),
                userInfo: nil,
                repeats: false
            )
        } catch {
            message = "Middle C could not be played."
        }
    }

    private func ensureReferenceToneReady() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        try session.overrideOutputAudioPort(.speaker)

        if referenceEngine == nil {
            let sampleRate = 44_100.0
            let duration = 1.5
            let frameCount = AVAudioFrameCount(sampleRate * duration)
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
                  let samples = buffer.floatChannelData?[0] else {
                throw VoiceRecorderError.playbackCouldNotStart
            }

            buffer.frameLength = frameCount
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / sampleRate
                let attack = min(1, time / 0.025)
                let release = min(1, (duration - time) / 0.14)
                let envelope = max(0, min(attack, release))
                samples[frame] = Float(sin(2 * Double.pi * 261.6256 * time) * envelope * 0.32)
            }

            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            referenceEngine = engine
            referencePlayer = player
            referenceBuffer = buffer
        }

        if referenceEngine?.isRunning == false {
            try referenceEngine?.start()
        }
    }

    private func stopReferenceTone() {
        stopReferencePlayback()
        referenceEngine?.stop()
        referencePlayer = nil
        referenceBuffer = nil
        referenceEngine = nil
    }

    private func stopReferencePlayback() {
        referenceTimer?.invalidate()
        referenceTimer = nil
        referencePlayer?.stop()
        isPlayingReference = false
    }

    @objc private func referenceTimerFired() {
        stopReferencePlayback()
    }

    private func requestPermissionAndRecord() {
        permissionDenied = false
        Task {
            let granted: Bool = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if granted {
                startRecording()
            } else {
                permissionDenied = true
                message = "Microphone access is off. Enable it in Settings to record."
            }
        }
    }

    private func startRecording() {
        stopPlayback()
        stopPianoEngine()
        stopReferenceTone()
        noteIndex = 0
        resetChordGame()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            recorder.record(forDuration: maximumDuration)
            audioRecorder = recorder
            isRecording = true
            hasRecording = false
            elapsed = 0
            message = nil
            waveformSamples = Array(repeating: 0.035, count: waveformSamples.count)
            startMeterTimer()
        } catch {
            message = "The microphone could not start."
            isRecording = false
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        invalidateTimer()
        hasRecording = recordingFileIsReady
        if hasRecording {
            try? prepareRecordedVoice()
            message = "Silence trimmed · voice tuned to C"
        } else {
            message = nil
        }
        deactivateSession()
    }

    private func startPlayback() {
        guard hasRecording else { return }
        stopPianoEngine()
        stopReferenceTone()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)

            if preparedPlaybackBuffer == nil {
                try prepareRecordedVoice()
            }
            guard let buffer = preparedPlaybackBuffer else {
                throw VoiceRecorderError.playbackCouldNotStart
            }
            playbackDuration = Double(buffer.frameLength) / buffer.format.sampleRate

            let engine = AVAudioEngine()
            playerNodes = []
            equalizers = []
            phaseDelays = []

            let player = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            pitch.pitch = tuningCorrectionCents + Float(pitchSemitones * 100)
            pitch.rate = 1

            engine.attach(player)
            engine.attach(pitch)
            engine.connect(player, to: pitch, format: buffer.format)
            engine.connect(pitch, to: engine.mainMixerNode, format: buffer.format)

            player.scheduleBuffer(buffer, at: nil, options: [])
            playerNodes = [player]
            pitchUnit = pitch

            engine.mainMixerNode.outputVolume = 0.82
            engine.prepare()
            try engine.start()
            playerNodes.forEach { $0.play() }
            playbackEngine = engine
            isPlaying = true
            elapsed = 0
            message = "Playing through speaker"
            startMeterTimer()
        } catch {
            message = "The recording could not be played."
            isPlaying = false
        }
    }

    private func stopPlayback() {
        playerNodes.forEach { $0.stop() }
        playbackEngine?.stop()
        playbackEngine = nil
        playerNodes = []
        equalizers = []
        phaseDelays = []
        pitchUnit = nil
        isPlaying = false
        invalidateTimer()
        deactivateSession()
    }

    private func startMeterTimer() {
        invalidateTimer()
        meterTimer = Timer.scheduledTimer(
            timeInterval: 0.06,
            target: self,
            selector: #selector(meterTimerFired),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func meterTimerFired() {
        updateMeter()
    }

    private func updateMeter() {
        if isRecording, let recorder = audioRecorder {
            recorder.updateMeters()
            elapsed = recorder.currentTime
            let normalized = max(0.035, min(1, pow(10, Double(recorder.averagePower(forChannel: 0)) / 34)))
            waveformSamples.removeFirst()
            waveformSamples.append(normalized)

            if !recorder.isRecording || elapsed >= maximumDuration {
                stopRecording()
            }
        } else if isPlaying {
            elapsed += 0.06
            if elapsed >= playbackDuration || playerNodes.first?.isPlaying == false {
                finishPlayback()
            }
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
            invalidateTimer()
            hasRecording = flag && recordingFileIsReady
            elapsed = recorder.currentTime
            if hasRecording {
                try? prepareRecordedVoice()
                message = "Silence trimmed · voice tuned to C"
            } else {
                message = nil
            }
            deactivateSession()
        }
    }

    private func invalidateTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finishPlayback() {
        let duration = playbackDuration
        stopPlayback()
        elapsed = duration
        message = "Playback complete"
    }

    private func updateAudioComponent(at index: Int) {
        guard components.indices.contains(index),
              playerNodes.indices.contains(index),
              equalizers.indices.contains(index),
              phaseDelays.indices.contains(index) else { return }
        let component = components[index]
        playerNodes[index].volume = component.isMuted ? 0 : Float(component.amplitude)
        equalizers[index].bands[0].frequency = Float(component.frequency)
        phaseDelays[index].delayTime = phaseDelay(for: component)
    }

    private func phaseDelay(for component: FourierComponent) -> TimeInterval {
        let normalizedPhase = component.phase >= 0 ? component.phase : component.phase + 2 * .pi
        return normalizedPhase / (2 * .pi * max(1, component.frequency))
    }

    private func prepareRecordedVoice() throws {
        let file = try AVAudioFile(forReading: recordingURL)
        guard let rawBuffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw VoiceRecorderError.playbackCouldNotStart
        }
        try file.read(into: rawBuffer)

        let trimmed = trimLeadingSilence(from: rawBuffer)
        preparedPlaybackBuffer = trimmed
        tuningCorrectionCents = gentleCorrectionTowardC(for: estimatedPitch(in: trimmed))
    }

    private func trimLeadingSilence(from buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let channels = buffer.floatChannelData,
              buffer.frameLength > 512 else { return buffer }

        let samples = channels[0]
        let count = Int(buffer.frameLength)
        var peak: Float = 0
        for index in 0..<count {
            peak = max(peak, abs(samples[index]))
        }

        let threshold = max(0.008, peak * 0.06)
        let windowSize = 256
        let step = 128
        var detectedStart = 0

        if peak > threshold {
            for start in stride(from: 0, to: max(1, count - windowSize), by: step) {
                var energy: Float = 0
                for offset in 0..<windowSize {
                    let sample = samples[start + offset]
                    energy += sample * sample
                }
                let rms = sqrt(energy / Float(windowSize))
                if rms >= threshold {
                    let leadIn = Int(buffer.format.sampleRate * 0.035)
                    detectedStart = max(0, start - leadIn)
                    break
                }
            }
        }

        guard detectedStart > 0 else { return buffer }
        let trimmedLength = count - detectedStart
        guard let trimmed = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: AVAudioFrameCount(trimmedLength)
        ), let trimmedChannels = trimmed.floatChannelData else { return buffer }

        trimmed.frameLength = AVAudioFrameCount(trimmedLength)
        let byteCount = trimmedLength * MemoryLayout<Float>.size
        for channel in 0..<Int(buffer.format.channelCount) {
            memcpy(trimmedChannels[channel], channels[channel].advanced(by: detectedStart), byteCount)
        }
        return trimmed
    }

    private func estimatedPitch(in buffer: AVAudioPCMBuffer) -> Double? {
        guard let source = buffer.floatChannelData?[0],
              buffer.frameLength > 2_048 else { return nil }

        let sampleRate = buffer.format.sampleRate
        let strideSize = max(1, Int(sampleRate / 11_025))
        let analysisStart = min(Int(buffer.frameLength) - 1, Int(sampleRate * 0.04))
        let available = Int(buffer.frameLength) - analysisStart
        let sampleCount = min(8_192, available / strideSize)
        guard sampleCount > 1_024 else { return nil }

        var samples = [Double]()
        samples.reserveCapacity(sampleCount)
        for index in 0..<sampleCount {
            samples.append(Double(source[analysisStart + index * strideSize]))
        }
        let mean = samples.reduce(0, +) / Double(samples.count)
        for index in samples.indices { samples[index] -= mean }

        let reducedRate = sampleRate / Double(strideSize)
        let minimumLag = max(2, Int(reducedRate / 420))
        let maximumLag = min(samples.count / 2, Int(reducedRate / 65))
        var bestLag = 0
        var bestCorrelation = 0.0

        for lag in minimumLag...maximumLag {
            var cross = 0.0
            var energyA = 0.0
            var energyB = 0.0
            for index in 0..<(samples.count - lag) {
                let a = samples[index]
                let b = samples[index + lag]
                cross += a * b
                energyA += a * a
                energyB += b * b
            }
            let correlation = cross / sqrt(max(0.000_001, energyA * energyB))
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestLag > 0, bestCorrelation > 0.3 else { return nil }
        return reducedRate / Double(bestLag)
    }

    private func gentleCorrectionTowardC(for detectedPitch: Double?) -> Float {
        guard let detectedPitch, detectedPitch > 0 else { return 0 }
        let middleC = 261.6256
        let nearestCOctave = middleC * pow(2, round(log2(detectedPitch / middleC)))
        let rawCorrection = 1_200 * log2(nearestCOctave / detectedPitch)
        return Float(max(-80, min(80, rawCorrection * 0.65)))
    }

    private var recordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("lilavati-voice-capture.m4a")
    }

    private var recordingFileIsReady: Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: recordingURL.path),
              let fileSize = attributes[.size] as? NSNumber else { return false }
        return fileSize.intValue > 256
    }
}

private enum VoiceRecorderError: Error {
    case playbackCouldNotStart
}

struct FourierSeriesConceptVisual: View {
    private let colors: [Color] = [
        Color(red: 0.18, green: 0.84, blue: 0.88),
        Color(red: 1.0, green: 0.73, blue: 0.18),
        Color(red: 0.96, green: 0.31, blue: 0.25)
    ]

    var body: some View {
        Canvas { context, size in
            for layer in 0..<3 {
                let baseline = size.height * (0.2 + CGFloat(layer) * 0.22)
                var component = Path()
                for step in 0...100 {
                    let p = Double(step) / 100
                    let point = CGPoint(
                        x: size.width * CGFloat(p),
                        y: baseline + CGFloat(sin(p * Double(layer + 1) * 4 * .pi + Double(layer) * 0.7)) * 12
                    )
                    if step == 0 { component.move(to: point) } else { component.addLine(to: point) }
                }
                context.stroke(component, with: .color(colors[layer].opacity(0.82)), lineWidth: 1.6)
            }

            var sum = Path()
            for step in 0...120 {
                let p = Double(step) / 120
                let combined = sin(p * 4 * .pi) + 0.55 * sin(p * 8 * .pi + 0.7) + 0.28 * sin(p * 12 * .pi + 1.4)
                let point = CGPoint(x: size.width * CGFloat(p), y: size.height * 0.84 + CGFloat(combined) * 13)
                if step == 0 { sum.move(to: point) } else { sum.addLine(to: point) }
            }
            context.stroke(sum, with: .color(.white.opacity(0.9)), lineWidth: 2.2)
        }
    }
}

#Preview {
    MathItLevelOneHundredTwentyFourView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 124) ?? 124)
}
