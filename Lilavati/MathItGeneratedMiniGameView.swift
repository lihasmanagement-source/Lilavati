import SwiftUI
import Combine
import AVFoundation

struct MathItGeneratedMiniGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var values = [3, 5, 7]
    @State private var completed = false
    @State private var wrongPulse = false

    private var stageCount: Int { 3 }
    private var isLogicLevel: Bool { concept.number >= 82 }
    private var mode: GeneratedMiniGameMode {
        if concept.number >= 82 {
            switch concept.number % 5 {
            case 0: return .logicRoute
            case 1: return .logicCascade
            case 2: return .logicTraffic
            case 3: return .logicBits
            default: return .logicGrid
            }
        }

        switch concept.visual {
        case .phaseRings: return .phase
        case .soundEnvelope: return .envelope
        case .waveformMixer: return concept.number == 74 ? .doppler : .wave
        case .spectrumBars: return .spectrum
        case .chordCircle: return concept.number == 79 ? .stereo : .chord
        case .echoTunnel: return .echo
        case .beatGrid: return concept.number == 77 ? .rhythm : .scale
        default: return .wave
        }
    }
    private var targetValues: [Int] {
        (0..<3).map { index in
            ((concept.number * (index + 3) + stageIndex * 7 + index * 5) % 9) + 1
        }
    }
    private var matchCount: Int {
        zip(values, targetValues).filter { $0 == $1 }.count
    }
    private var progress: Double {
        (Double(stageIndex) + Double(matchCount) / 3.0) / Double(stageCount)
    }
    private var symbols: [String] {
        mode.symbols
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
                            .foregroundStyle(.white.opacity(0.58))

                        EmptyView()
                            .font(.system(size: 36, weight: .medium, design: .serif))
                            .foregroundStyle(.white.opacity(completed ? 1 : 0.46))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 58)

                    ProgressView(value: progress)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    generatedField
                        .frame(height: min(390, proxy.size.height * 0.5))
                        .padding(.horizontal, 20)
                        .scaleEffect(wrongPulse ? 0.985 : 1)

                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            valueControl(index)
                        }

                        Button(action: checkStage) {
                            Image(systemName: matchCount == 3 ? "checkmark.seal.fill" : "scope")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 48, height: 46)
                                .background(accent, in: Circle())
                        }
                        .buttonStyle(.plain)

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
                resetValuesForStage()
            }
        }
    }

    private var generatedField: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.08), Color(red: 0.012, green: 0.018, blue: 0.03), .black.opacity(0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.36), lineWidth: 1.2))

                switch mode {
                case .logicGrid, .logicRoute, .logicCascade, .logicTraffic, .logicBits:
                    logicMiniField(size: proxy.size)
                case .phase:
                    phaseMiniField(size: proxy.size)
                case .envelope:
                    envelopeMiniField(size: proxy.size)
                case .spectrum:
                    spectrumMiniField(size: proxy.size)
                case .chord, .stereo:
                    chordMiniField(size: proxy.size)
                case .echo:
                    echoMiniField(size: proxy.size)
                case .rhythm, .scale:
                    rhythmMiniField(size: proxy.size)
                case .wave, .doppler:
                    musicMiniField(size: proxy.size)
                }

            }
        }
    }

    private func musicMiniField(size: CGSize) -> some View {
        Canvas { canvas, canvasSize in
            let midY = canvasSize.height * 0.54
            let width = canvasSize.width * 0.82
            let startX = canvasSize.width * 0.09

            for index in 0..<3 {
                let target = CGFloat(targetValues[index]) / 10.0
                let actual = CGFloat(values[index]) / 10.0
                let y = midY - CGFloat(index - 1) * 42

                var targetPath = Path()
                var actualPath = Path()
                for step in 0...90 {
                    let x = startX + width * CGFloat(step) / 90.0
                    let phase = CGFloat(step) / 90.0 * .pi * 2 * CGFloat(index + 1)
                    let targetY = y + sin(phase) * (18 + target * 28)
                    let actualY = y + sin(phase + actual * 1.4) * (18 + actual * 28)
                    if step == 0 {
                        targetPath.move(to: CGPoint(x: x, y: targetY))
                        actualPath.move(to: CGPoint(x: x, y: actualY))
                    } else {
                        targetPath.addLine(to: CGPoint(x: x, y: targetY))
                        actualPath.addLine(to: CGPoint(x: x, y: actualY))
                    }
                }
                canvas.stroke(targetPath, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 3, dash: [7, 7]))
                canvas.stroke(actualPath, with: .color(accent.opacity(values[index] == targetValues[index] ? 0.95 : 0.58)), lineWidth: 4)
            }
        }
        .overlay {
            symbolOverlay
        }
    }

    private func logicMiniField(size: CGSize) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

        return VStack(spacing: 18) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    let channel = index % 3
                    let value = index + 1
                    RoundedRectangle(cornerRadius: 8)
                        .fill(value == values[channel] ? accent.opacity(0.78) : value == targetValues[channel] ? .white.opacity(0.2) : .black.opacity(0.74))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(value == targetValues[channel] ? accent.opacity(0.86) : .white.opacity(0.1), lineWidth: value == targetValues[channel] ? 2 : 1)
                        )
                        .frame(height: max(34, size.height * 0.095))
                }
            }
            .padding(.horizontal, 36)

            HStack(spacing: 28) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: generatedStatusSymbol(for: index))
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(values[index] == targetValues[index] ? accent : .white.opacity(0.58))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func phaseMiniField(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let targetAngle = Angle.degrees(Double(targetValues[index]) * 40)
                let actualAngle = Angle.degrees(Double(values[index]) * 40)
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 2)
                    .frame(width: 88 + CGFloat(index * 46), height: 88 + CGFloat(index * 46))
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: 5, height: 44 + CGFloat(index * 23))
                    .offset(y: -(22 + CGFloat(index * 12)))
                    .rotationEffect(targetAngle)
                Capsule()
                    .fill(values[index] == targetValues[index] ? accent : accent.opacity(0.58))
                    .frame(width: 7, height: 44 + CGFloat(index * 23))
                    .offset(y: -(22 + CGFloat(index * 12)))
                    .rotationEffect(actualAngle)
            }
            symbolOverlay.offset(y: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func envelopeMiniField(size: CGSize) -> some View {
        Canvas { canvas, canvasSize in
            let inset: CGFloat = 34
            let width = canvasSize.width - inset * 2
            let baseY = canvasSize.height * 0.74
            let targetPoints = envelopePoints(targetValues, inset: inset, width: width, baseY: baseY)
            let actualPoints = envelopePoints(values, inset: inset, width: width, baseY: baseY)
            canvas.stroke(path(through: targetPoints), with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 4, dash: [8, 8]))
            canvas.stroke(path(through: actualPoints), with: .color(accent.opacity(matchCount == 3 ? 0.96 : 0.68)), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
        }
        .overlay { symbolOverlay }
    }

    private func spectrumMiniField(size: CGSize) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(0..<9, id: \.self) { index in
                let channel = index % 3
                let targetHeight = CGFloat(targetValues[channel]) / 9.0 * size.height * 0.52 + 16
                let actualHeight = CGFloat(values[channel]) / 9.0 * size.height * 0.52 + 16
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        .frame(width: 18, height: targetHeight)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(values[channel] == targetValues[channel] ? accent : accent.opacity(0.48))
                        .frame(width: 18, height: actualHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { symbolOverlay }
    }

    private func chordMiniField(size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 2)
                .frame(width: min(size.width, size.height) * 0.54, height: min(size.width, size.height) * 0.54)
            ForEach(0..<12, id: \.self) { index in
                let channel = index % 3
                let isActual = values[channel] == (index % 9) + 1
                let isTarget = targetValues[channel] == (index % 9) + 1
                Circle()
                    .fill(isActual ? accent : isTarget ? .white.opacity(0.22) : .white.opacity(0.08))
                    .frame(width: isActual || isTarget ? 20 : 10, height: isActual || isTarget ? 20 : 10)
                    .offset(y: -min(size.width, size.height) * 0.27)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            symbolOverlay.offset(y: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func echoMiniField(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let targetWidth = CGFloat(targetValues[index]) / 9.0 * size.width * 0.56 + 42
                let actualWidth = CGFloat(values[index]) / 9.0 * size.width * 0.56 + 42
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                    .frame(width: targetWidth, height: 54 + CGFloat(index * 34))
                RoundedRectangle(cornerRadius: 18)
                    .stroke(values[index] == targetValues[index] ? accent : accent.opacity(0.58), lineWidth: 3)
                    .frame(width: actualWidth, height: 54 + CGFloat(index * 34))
            }
            HStack(spacing: 86) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Image(systemName: "arrow.left")
            }
            .font(.system(size: 30, weight: .black))
            .foregroundStyle(accent)
            symbolOverlay.offset(y: 112)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rhythmMiniField(size: CGSize) -> some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<9, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(index < values[row] ? accent.opacity(values[row] == targetValues[row] ? 0.9 : 0.56) : .white.opacity(index < targetValues[row] ? 0.18 : 0.06))
                            .frame(height: 18)
                    }
                }
                .padding(.horizontal, 34)
            }
            symbolOverlay.offset(y: 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbolOverlay: some View {
        HStack(spacing: 28) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: generatedStatusSymbol(for: index))
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(values[index] == targetValues[index] ? accent : .white.opacity(0.56))
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.54), in: Circle())
                    .overlay(Circle().stroke(accent.opacity(0.28), lineWidth: 1.1))
            }
        }
        .offset(y: 118)
    }

    private func generatedStatusSymbol(for index: Int) -> String {
        if values[index] == targetValues[index] || concept.number == 67 {
            return "checkmark.circle.fill"
        }
        return symbols[index]
    }

    private func valueControl(_ index: Int) -> some View {
        VStack(spacing: 4) {
            Button {
                adjust(index, by: 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 22)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(.plain)

            Text("\(values[index])")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(values[index] == targetValues[index] ? .black : accent)
                .frame(width: 46, height: 34)
                .background(values[index] == targetValues[index] ? accent : .black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.42), lineWidth: 1))

            Button {
                adjust(index, by: -1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 22)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func adjust(_ index: Int, by amount: Int) {
        guard !completed, values.indices.contains(index) else { return }
        values[index] = min(max(values[index] + amount, 1), 9)
        HapticPlayer.playLightTap()
    }

    private func checkStage() {
        guard !completed else { return }
        if matchCount == 3 {
            HapticPlayer.playCompletionTap()
            if stageIndex == stageCount - 1 {
                withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                    completed = true
                }
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    stageIndex += 1
                    resetValuesForStage()
                }
            }
        } else {
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

    private func resetValuesForStage() {
        values = (0..<3).map { index in
            let seed = ((concept.number + stageIndex * 4 + index * 2) % 9) + 1
            return seed == targetValues[index] ? (seed % 9) + 1 : seed
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            stageIndex = 0
            completed = false
            wrongPulse = false
            resetValuesForStage()
        }
    }

    private func envelopePoints(_ source: [Int], inset: CGFloat, width: CGFloat, baseY: CGFloat) -> [CGPoint] {
        [
            CGPoint(x: inset, y: baseY),
            CGPoint(x: inset + width * 0.22, y: baseY - CGFloat(source[0]) * 16),
            CGPoint(x: inset + width * 0.54, y: baseY - CGFloat(source[1]) * 12),
            CGPoint(x: inset + width * 0.78, y: baseY - CGFloat(source[2]) * 12),
            CGPoint(x: inset + width, y: baseY)
        ]
    }

    private func path(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

enum GeneratedMiniGameMode {
    case wave
    case phase
    case envelope
    case spectrum
    case chord
    case echo
    case rhythm
    case scale
    case doppler
    case stereo
    case logicGrid
    case logicRoute
    case logicCascade
    case logicTraffic
    case logicBits

    var symbols: [String] {
        switch self {
        case .phase:
            return ["waveform.path.ecg", "circle.dotted", "arrow.left.and.right"]
        case .envelope:
            return ["waveform.path", "slider.horizontal.3", "speaker.wave.2.fill"]
        case .spectrum:
            return ["chart.bar.fill", "line.3.horizontal.decrease", "speaker.wave.3.fill"]
        case .chord:
            return ["circle.grid.cross", "music.note", "link"]
        case .echo:
            return ["dot.radiowaves.left.and.right", "arrow.left.and.right", "timer"]
        case .rhythm:
            return ["metronome.fill", "circle.grid.2x2.fill", "music.quarternote.3"]
        case .scale:
            return ["pianokeys", "stairs", "music.note.list"]
        case .doppler:
            return ["car.fill", "waveform.path", "ear.fill"]
        case .stereo:
            return ["speaker.wave.2.fill", "circle.lefthalf.filled", "speaker.wave.2.fill"]
        case .logicGrid:
            return ["square.grid.3x3.fill", "switch.2", "checkmark.seal"]
        case .logicRoute:
            return ["point.3.connected.trianglepath.dotted", "arrow.triangle.branch", "location.fill"]
        case .logicCascade:
            return ["list.number", "arrow.down.right", "sparkles"]
        case .logicTraffic:
            return ["trafficlight", "clock.fill", "exclamationmark.triangle.fill"]
        case .logicBits:
            return ["number.square.fill", "plus.forwardslash.minus", "checkmark.shield.fill"]
        case .wave:
            return ["waveform", "dial.low", "dial.high"]
        }
    }
}
