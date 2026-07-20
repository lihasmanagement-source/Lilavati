import AVFoundation
import Darwin
import SwiftUI

struct MathItLevelSixtyEightView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var resetToken = UUID()
    @State private var completed = false
    @State private var soundPlayer = PeriodicWaveSoundPlayer()
    @State private var stage = 0
    @State private var completedWaves: Set<PeriodicTraceWave> = []
    @State private var sequence: [PeriodicTraceWave] = []
    @State private var performanceID = UUID()

    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: compact ? 8 : 12) {
                    header
                        .padding(.top, compact ? 8 : 18)

                    Group {
                        if stage == 0 {
                            traceStage
                        } else if stage == 1 {
                            PeriodicWaveSequencerStage(resetToken: resetToken) { arrangedWaves in
                                beginPerformance(arrangedWaves)
                            }
                        } else {
                            PeriodicWavePerformanceStage(
                                sequence: sequence,
                                elapsedProvider: soundPlayer.playbackElapsed,
                                onReplay: replayPerformance
                            )
                        }
                    }
                    .frame(maxWidth: 760)
                    .frame(height: min(520, proxy.size.height * 0.64))

                    Button(action: resetLevel) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(gold)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.055), in: Circle())
                            .overlay(Circle().stroke(gold.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset level")
                    .padding(.bottom, compact ? 5 : 12)
                }
                .padding(.horizontal, compact ? 10 : 18)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 79 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, gold)
        .onAppear { soundPlayer.prepare() }
        .onDisappear { soundPlayer.stop() }
    }

    private var header: some View {
        let stageIndex = min(stage, 1)

        return VStack(spacing: 7) {
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    Capsule()
                        .fill(index <= stageIndex ? gold : .white.opacity(0.13))
                        .frame(width: index == stageIndex ? 38 : 25, height: 5)
                        .shadow(color: index <= stageIndex ? gold.opacity(0.48) : .clear, radius: 4)
                }
            }

            Text(stageTitle)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var stageTitle: String {
        switch stage {
        case 0: "DRAW THE WAVES"
        case 1: "BUILD THE TRACK"
        default: "TWO-BAR PLAYBACK"
        }
    }

    private var traceStage: some View {
        VStack(spacing: 9) {
            ForEach(PeriodicTraceWave.allCases) { wave in
                PeriodicWaveTracePanel(wave: wave, resetToken: resetToken) {
                    completeTrace(wave)
                }
            }
        }
    }

    private func completeTrace(_ wave: PeriodicTraceWave) {
        guard completedWaves.insert(wave).inserted else { return }
        soundPlayer.play(wave)
        HapticPlayer.playLightTap()

        guard completedWaves.count == PeriodicTraceWave.allCases.count else { return }
        let token = resetToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) {
            guard resetToken == token, stage == 0 else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                stage = 1
            }
        }
    }

    private func beginPerformance(_ arrangedWaves: [PeriodicTraceWave]) {
        guard arrangedWaves.count == 4 else { return }
        sequence = arrangedWaves
        stage = 2
        replayPerformance()
    }

    private func replayPerformance() {
        guard sequence.count == 4 else { return }
        let run = UUID()
        performanceID = run
        completed = false
        soundPlayer.playSequence(sequence)

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.3) {
            guard performanceID == run, stage == 2 else { return }
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                completed = true
            }
        }
    }

    private func resetLevel() {
        soundPlayer.stop()
        performanceID = UUID()
        resetToken = UUID()
        completedWaves = []
        sequence = []
        stage = 0
        completed = false
    }
}

private enum PeriodicTraceWave: String, CaseIterable, Identifiable, Hashable {
    case sine
    case square
    case triangle
    case sawtooth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sine: "SINE"
        case .square: "SQUARE"
        case .triangle: "TRIANGLE"
        case .sawtooth: "SAWTOOTH"
        }
    }

    var formula: String {
        switch self {
        case .sine: "sin(x)"
        case .square: "sgn(sin x)"
        case .triangle: "(2/π)asin(sin x)"
        case .sawtooth: "x mod T"
        }
    }

    var color: Color {
        switch self {
        case .sine: Color(red: 0.18, green: 0.78, blue: 1.0)
        case .square: Color(red: 1.0, green: 0.68, blue: 0.16)
        case .triangle: Color(red: 0.24, green: 0.84, blue: 0.48)
        case .sawtooth: Color(red: 1.0, green: 0.34, blue: 0.28)
        }
    }
}

private struct PeriodicWaveSequencerStage: View {
    let resetToken: UUID
    let onReady: ([PeriodicTraceWave]) -> Void

    @State private var placements: [Int: PeriodicTraceWave] = [:]
    @State private var dragOffsets: [PeriodicTraceWave: CGSize] = [:]
    @State private var draggingWave: PeriodicTraceWave?
    @State private var submitted = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let timeline = timelineRect(in: size)
            let rowHeight = trackRowHeight(in: size)
            let chipWidth = min(78, max(58, (size.width - 34) / 4 - 7))

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.025, green: 0.03, blue: 0.035))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mathGold.opacity(0.34), lineWidth: 1))

                ForEach(0..<8, id: \.self) { beat in
                    Text("\(beat % 4 + 1)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(beat == 0 || beat == 4 ? Color.mathGold : .white.opacity(0.46))
                        .position(
                            x: timeline.minX + timeline.width * (CGFloat(beat) + 0.5) / 8,
                            y: 18
                        )
                }

                ForEach(0..<4, id: \.self) { track in
                    let rowY = trackCenter(track, rowHeight: rowHeight)
                    let slot = slotRect(track, in: size, rowHeight: rowHeight)

                    Text("\(track + 1)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                        .position(x: 18, y: rowY)

                    Capsule()
                        .fill(.white.opacity(0.055))
                        .frame(width: timeline.width, height: 2)
                        .position(x: timeline.midX, y: rowY)

                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            placements[track]?.color.opacity(0.76) ?? .white.opacity(0.34),
                            style: StrokeStyle(lineWidth: 1.5, dash: placements[track] == nil ? [5, 5] : [])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(placements[track]?.color.opacity(0.1) ?? .black.opacity(0.72))
                        )
                        .frame(width: slot.width, height: slot.height)
                        .position(x: slot.midX, y: slot.midY)

                    if placements[track] == nil {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.18))
                            .position(x: slot.midX, y: slot.midY)
                    }
                }

                ForEach(PeriodicTraceWave.allCases) { wave in
                    let placedTrack = placements.first(where: { $0.value == wave })?.key
                    let base = placedTrack.map { slotRect($0, in: size, rowHeight: rowHeight).center }
                        ?? palettePoint(for: wave, in: size)

                    PeriodicWaveChip(wave: wave, compact: placedTrack != nil)
                        .frame(width: chipWidth, height: 50)
                        .contentShape(Rectangle())
                        .position(base)
                        .offset(dragOffsets[wave] ?? .zero)
                        .scaleEffect(draggingWave == wave ? 1.08 : 1)
                        .shadow(color: draggingWave == wave ? wave.color.opacity(0.65) : .clear, radius: 14)
                        .zIndex(draggingWave == wave ? 20 : 5)
                        .gesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .named("periodicSequencer"))
                                .onChanged { value in
                                    guard !submitted else { return }
                                    draggingWave = wave
                                    dragOffsets[wave] = value.translation
                                }
                                .onEnded { value in
                                    finishDrag(wave, at: value.location, in: size, rowHeight: rowHeight)
                                }
                        )
                }

                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { track in
                        Image(systemName: placements[track] == nil ? "circle.dashed" : "checkmark.circle.fill")
                            .foregroundStyle(placements[track]?.color ?? .white.opacity(0.25))
                    }
                }
                .font(.system(size: 17, weight: .bold))
                .position(x: size.width / 2, y: size.height - 20)
            }
            .coordinateSpace(name: "periodicSequencer")
            .clipped()
            .onChange(of: resetToken) { _, _ in
                placements = [:]
                dragOffsets = [:]
                draggingWave = nil
                submitted = false
            }
        }
    }

    private func timelineRect(in size: CGSize) -> CGRect {
        CGRect(x: 34, y: 0, width: max(180, size.width - 48), height: size.height)
    }

    private func trackRowHeight(in size: CGSize) -> CGFloat {
        min(67, max(52, (size.height - 138) / 4))
    }

    private func trackCenter(_ track: Int, rowHeight: CGFloat) -> CGFloat {
        112 + rowHeight * (CGFloat(track) + 0.5)
    }

    private func slotRect(_ track: Int, in size: CGSize, rowHeight: CGFloat) -> CGRect {
        let timeline = timelineRect(in: size)
        let columnWidth = timeline.width / 4
        return CGRect(
            x: timeline.minX + columnWidth * CGFloat(track) + 4,
            y: trackCenter(track, rowHeight: rowHeight) - min(25, rowHeight * 0.42),
            width: max(48, columnWidth - 8),
            height: min(50, rowHeight * 0.84)
        )
    }

    private func palettePoint(for wave: PeriodicTraceWave, in size: CGSize) -> CGPoint {
        let index = PeriodicTraceWave.allCases.firstIndex(of: wave) ?? 0
        return CGPoint(
            x: 17 + (size.width - 34) * (CGFloat(index) + 0.5) / 4,
            y: 65
        )
    }

    private func finishDrag(_ wave: PeriodicTraceWave, at point: CGPoint, in size: CGSize, rowHeight: CGFloat) {
        draggingWave = nil
        let target = (0..<4).first { track in
            slotRect(track, in: size, rowHeight: rowHeight)
                .insetBy(dx: -10, dy: -8)
                .contains(point)
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            dragOffsets[wave] = .zero
        }

        guard let target else {
            HapticPlayer.playLightTap()
            return
        }
        place(wave, on: target)
    }

    private func place(_ wave: PeriodicTraceWave, on track: Int) {
        guard !submitted else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            if let oldTrack = placements.first(where: { $0.value == wave })?.key {
                placements.removeValue(forKey: oldTrack)
            }
            placements[track] = wave
        }
        HapticPlayer.playLightTap()

        guard placements.count == 4 else { return }
        let arrangement = (0..<4).compactMap { placements[$0] }
        guard arrangement.count == 4 else { return }
        submitted = true
        onReady(arrangement)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private struct PeriodicWavePerformanceStage: View {
    let sequence: [PeriodicTraceWave]
    let elapsedProvider: () -> Double
    let onReplay: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            let elapsed = min(8, max(0, elapsedProvider()))
            let progress = min(1, elapsed / 8)
            let activeClip = min(3, Int(elapsed / 2))
            let activeKick = min(15, Int(elapsed / 0.5))
            let beatPosition = elapsed / 0.5
            let beatPhase = beatPosition - floor(beatPosition)

            VStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(Color.mathGold)
                    ForEach(0..<16, id: \.self) { kick in
                        Circle()
                            .fill(kick == activeKick ? Color.mathGold : .white.opacity(0.12))
                            .frame(width: 6, height: 6)
                            .scaleEffect(kick == activeKick ? 1 + 0.42 * max(0, 1 - beatPhase * 5) : 1)
                    }
                    Spacer()
                    Text("60")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.64))
                    Image(systemName: "metronome.fill")
                        .foregroundStyle(.white.opacity(0.42))
                }

                performanceGrid(progress: progress, activeClip: activeClip)

                HStack(spacing: 12) {
                    Button(action: onReplay) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.black)
                            .frame(width: 48, height: 48)
                            .background(Color.mathGold, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Replay two-bar track")

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12)).frame(height: 5)
                            Capsule().fill(Color.mathGold).frame(width: geo.size.width * progress, height: 5)
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .offset(x: max(0, geo.size.width * progress - 6))
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 20)
                }
            }
            .padding(16)
            .background(Color(red: 0.025, green: 0.03, blue: 0.035))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mathGold.opacity(0.34), lineWidth: 1))
        }
    }

    private func performanceGrid(progress: Double, activeClip: Int) -> some View {
        GeometryReader { geo in
            let labelWidth: CGFloat = 28
            let timelineWidth = max(1, geo.size.width - labelWidth)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 9) {
                    ForEach(0..<4, id: \.self) { track in
                        HStack(spacing: 6) {
                            Text("\(track + 1)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.42))
                                .frame(width: 22)

                            ForEach(0..<4, id: \.self) { column in
                                if column == track, sequence.indices.contains(track) {
                                    PeriodicWaveChip(wave: sequence[track], compact: true)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(sequence[track].color.opacity(track == activeClip ? 0.22 : 0.06), in: RoundedRectangle(cornerRadius: 5))
                                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(sequence[track].color.opacity(track == activeClip ? 0.9 : 0.3), lineWidth: track == activeClip ? 2 : 1))
                                        .shadow(color: track == activeClip ? sequence[track].color.opacity(0.55) : .clear, radius: 10)
                                } else {
                                    Capsule()
                                        .fill(.white.opacity(0.05))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 2)
                                }
                            }
                        }
                        .frame(height: 54)
                    }
                }

                Rectangle()
                    .fill(Color.mathGold)
                    .frame(width: 2, height: 243)
                    .offset(x: labelWidth + timelineWidth * progress)
                    .shadow(color: Color.mathGold.opacity(0.65), radius: 5)
            }
        }
        .frame(height: 243)
    }
}

private struct PeriodicWaveChip: View {
    let wave: PeriodicTraceWave
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 2 : 5) {
            PeriodicWaveGlyph(wave: wave)
                .frame(height: compact ? 22 : 28)
            if !compact {
                Text(wave.title)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.76))
            }
        }
        .padding(.horizontal, compact ? 5 : 9)
        .padding(.vertical, compact ? 4 : 7)
        .background(wave.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(wave.color.opacity(0.62), lineWidth: 1))
    }
}

private struct PeriodicWaveGlyph: View {
    let wave: PeriodicTraceWave

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: 2, y: 2, width: max(1, size.width - 4), height: max(1, size.height - 4))
            let samples = PeriodicWaveGeometry.samples(for: wave, in: rect)
            var path = Path()
            if let first = samples.first {
                path.move(to: first)
                for point in samples.dropFirst() {
                    path.addLine(to: point)
                }
            }
            context.stroke(path, with: .color(wave.color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct PeriodicWaveTracePanel: View {
    let wave: PeriodicTraceWave
    let resetToken: UUID
    let onCompleted: () -> Void

    @State private var sampleIndex = 0
    @State private var tracing = false
    @State private var finished = false
    @State private var errorPulse = false

    var body: some View {
        GeometryReader { geo in
            let plot = CGRect(x: 12, y: 24, width: max(80, geo.size.width - 24), height: max(45, geo.size.height - 32))
            let samples = PeriodicWaveGeometry.samples(for: wave, in: plot)

            ZStack(alignment: .top) {
                Canvas { context, size in
                    drawGrid(context: &context, plot: plot)

                    let guide = path(from: samples, through: samples.count - 1)
                    context.stroke(
                        guide,
                        with: .color(.white.opacity(0.34)),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round, dash: [3, 5])
                    )

                    if sampleIndex > 0 {
                        context.stroke(
                            path(from: samples, through: sampleIndex),
                            with: .color(wave.color),
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                        )
                    }

                    if let start = samples.first, !finished {
                        context.fill(
                            Path(ellipseIn: CGRect(x: start.x - 3.5, y: start.y - 3.5, width: 7, height: 7)),
                            with: .color(sampleIndex == 0 ? .white.opacity(0.55) : wave.color.opacity(0.25))
                        )
                    }

                    if sampleIndex < samples.count, sampleIndex > 0 {
                        let current = samples[min(sampleIndex, samples.count - 1)]
                        context.fill(
                            Path(ellipseIn: CGRect(x: current.x - 4, y: current.y - 4, width: 8, height: 8)),
                            with: .color(wave.color)
                        )
                    }
                }

                HStack {
                    Text(wave.title)
                        .foregroundStyle(finished ? wave.color : .white.opacity(0.68))
                    Spacer()
                    Text(wave.formula)
                        .foregroundStyle(.white.opacity(0.38))
                }
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.top, 7)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        trace(value.location, samples: samples)
                    }
                    .onEnded { _ in
                        tracing = false
                    }
            )
            .background(Color(red: 0.045, green: 0.055, blue: 0.062))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(errorPulse ? Color.red : finished ? wave.color.opacity(0.7) : .white.opacity(0.11), lineWidth: errorPulse ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .accessibilityLabel("Trace the \(wave.title.lowercased()) periodic function")
            .onChange(of: resetToken) { _, _ in
                sampleIndex = 0
                tracing = false
                finished = false
                errorPulse = false
            }
        }
    }

    private func trace(_ point: CGPoint, samples: [CGPoint]) {
        guard !finished, !samples.isEmpty else { return }
        let current = min(sampleIndex, samples.count - 1)

        if !tracing {
            guard distance(point, samples[current]) <= 28 else { return }
            tracing = true
        }

        let lower = max(0, current - 7)
        let upper = min(samples.count - 1, current + 34)
        var nearestIndex = current
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for index in lower...upper {
            let candidateDistance = distance(point, samples[index])
            if candidateDistance < nearestDistance {
                nearestDistance = candidateDistance
                nearestIndex = index
            }
        }

        if nearestDistance <= 24 {
            sampleIndex = max(sampleIndex, nearestIndex)
            if sampleIndex >= samples.count - 4 {
                sampleIndex = samples.count - 1
                tracing = false
                finished = true
                onCompleted()
            }
        } else if distance(point, samples[current]) > 44 {
            tracing = false
            errorPulse = true
            HapticPlayer.playLightTap()
            withAnimation(.easeOut(duration: 0.22)) {
                sampleIndex = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                errorPulse = false
            }
        }
    }

    private func drawGrid(context: inout GraphicsContext, plot: CGRect) {
        var grid = Path()
        for fraction in [0.25, 0.5, 0.75] as [CGFloat] {
            let x = plot.minX + plot.width * fraction
            grid.move(to: CGPoint(x: x, y: plot.minY))
            grid.addLine(to: CGPoint(x: x, y: plot.maxY))
        }
        for fraction in [0.25, 0.5, 0.75] as [CGFloat] {
            let y = plot.minY + plot.height * fraction
            grid.move(to: CGPoint(x: plot.minX, y: y))
            grid.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
        context.stroke(grid, with: .color(.white.opacity(0.07)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
    }

    private func path(from samples: [CGPoint], through index: Int) -> Path {
        Path { path in
            guard !samples.isEmpty else { return }
            path.move(to: samples[0])
            if index > 0 {
                for point in samples[1...min(index, samples.count - 1)] {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

private enum PeriodicWaveGeometry {
    static func samples(for wave: PeriodicTraceWave, in rect: CGRect) -> [CGPoint] {
        switch wave {
        case .sine:
            return smoothSamples(in: rect) { phase in sin(phase * .pi * 6) }
        case .triangle:
            return smoothSamples(in: rect) { phase in
                2 / .pi * asin(sin(phase * .pi * 6))
            }
        case .square:
            return squareSamples(in: rect)
        case .sawtooth:
            return sawtoothSamples(in: rect)
        }
    }

    private static func smoothSamples(
        in rect: CGRect,
        function: (Double) -> Double
    ) -> [CGPoint] {
        let amplitude = rect.height * 0.36
        return (0...360).map { index in
            let t = Double(index) / 360
            return CGPoint(
                x: rect.minX + rect.width * CGFloat(t),
                y: rect.midY - amplitude * CGFloat(function(t))
            )
        }
    }

    private static func squareSamples(in rect: CGRect) -> [CGPoint] {
        let high = rect.midY - rect.height * 0.34
        let low = rect.midY + rect.height * 0.34
        var points: [CGPoint] = []

        for segment in 0..<6 {
            let x0 = rect.minX + rect.width * CGFloat(segment) / 6
            let x1 = rect.minX + rect.width * CGFloat(segment + 1) / 6
            let y = segment.isMultiple(of: 2) ? high : low

            for step in 0...34 {
                let t = CGFloat(step) / 34
                points.append(CGPoint(x: x0 + (x1 - x0) * t, y: y))
            }

            if segment < 5 {
                let nextY = segment.isMultiple(of: 2) ? low : high
                for step in 1...18 {
                    let t = CGFloat(step) / 18
                    points.append(CGPoint(x: x1, y: y + (nextY - y) * t))
                }
            }
        }
        return points
    }

    private static func sawtoothSamples(in rect: CGRect) -> [CGPoint] {
        let high = rect.midY - rect.height * 0.34
        let low = rect.midY + rect.height * 0.34
        var points: [CGPoint] = []

        for cycle in 0..<3 {
            let x0 = rect.minX + rect.width * CGFloat(cycle) / 3
            let x1 = rect.minX + rect.width * CGFloat(cycle + 1) / 3

            for step in 0...64 {
                let t = CGFloat(step) / 64
                points.append(CGPoint(x: x0 + (x1 - x0) * t, y: low + (high - low) * t))
            }

            if cycle < 2 {
                for step in 1...18 {
                    let t = CGFloat(step) / 18
                    points.append(CGPoint(x: x1, y: high + (low - high) * t))
                }
            }
        }
        return points
    }
}

private final class PeriodicWaveSoundPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private let playbackLead = 0.12
    private var kickPlayers: [AVAudioPlayer] = []
    private var audioSessionReady = false
    private var lastPlaybackElapsed = 0.0

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func prepare() {
        guard prepareAudioSystem() else { return }
        _ = prepareKickPlayers()
    }

    func play(_ wave: PeriodicTraceWave) {
        let duration = 1.9
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            let samples = buffer.floatChannelData?[0]
        else { return }

        buffer.frameLength = frameCount
        let frequency = 196.0

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let phase = 2 * Double.pi * frequency * time
            let attack = min(1, time / 0.035)
            let release = min(1, (duration - time) / 0.16)
            let envelope = max(0, min(attack, release))
            samples[frame] = Float(sample(wave, phase: phase) * envelope * gain(for: wave))
        }

        player.volume = 1
        start(buffer)
    }

    func playSequence(_ sequence: [PeriodicTraceWave]) {
        guard sequence.count == 4 else { return }
        let duration = 8.0
        let clipDuration = 1.9
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            let samples = buffer.floatChannelData?[0]
        else { return }

        buffer.frameLength = frameCount
        let frequencies = [130.81, 155.56, 196.0, 116.54]

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let clipIndex = min(3, Int(time / 2))
            let clipTime = time - Double(clipIndex) * 2
            var waveSample = 0.0

            if clipTime < clipDuration {
                let phase = 2 * Double.pi * frequencies[clipIndex] * clipTime
                let attack = min(1, clipTime / 0.035)
                let release = min(1, (clipDuration - clipTime) / 0.16)
                let envelope = max(0, min(attack, release))
                let kickPhase = time.truncatingRemainder(dividingBy: 0.5)
                let sidechain = 0.42 + 0.58 * min(1, kickPhase / 0.22)
                let wave = sequence[clipIndex]
                waveSample = sample(wave, phase: phase) * envelope * sidechain * gain(for: wave)
            }

            samples[frame] = Float(waveSample)
        }

        player.volume = 0.68
        startSynchronizedLoop(buffer)
    }

    private func start(_ buffer: AVAudioPCMBuffer) {
        cancelKickPattern()
        guard prepareAudioSystem() else {
            player.stop()
            return
        }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func startSynchronizedLoop(_ buffer: AVAudioPCMBuffer) {
        guard prepareAudioSystem(), prepareKickPlayers(), let firstKick = kickPlayers.first else {
            start(buffer)
            return
        }

        cancelKickPattern()
        player.stop()
        lastPlaybackElapsed = 0

        let hostStart = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: playbackLead)
        let kickStart = firstKick.deviceCurrentTime + playbackLead

        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play(at: AVAudioTime(hostTime: hostStart))
        scheduleKickPattern(at: kickStart)
    }

    private func prepareAudioSystem() -> Bool {
        do {
            if !audioSessionReady {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                engine.prepare()
                audioSessionReady = true
            }
            if !engine.isRunning {
                try engine.start()
            }
            return true
        } catch {
            return false
        }
    }

    func stop() {
        player.stop()
        cancelKickPattern()
        lastPlaybackElapsed = 0
    }

    func playbackElapsed() -> Double {
        guard
            let nodeTime = player.lastRenderTime,
            let playerTime = player.playerTime(forNodeTime: nodeTime),
            playerTime.sampleRate > 0
        else { return lastPlaybackElapsed }

        let elapsed = min(8, max(0, Double(playerTime.sampleTime) / playerTime.sampleRate))
        lastPlaybackElapsed = max(lastPlaybackElapsed, elapsed)
        return lastPlaybackElapsed
    }

    private func sample(_ wave: PeriodicTraceWave, phase: Double) -> Double {
        switch wave {
        case .sine:
            return sin(phase)
        case .square:
            return sin(phase) >= 0 ? 1 : -1
        case .triangle:
            return 2 / .pi * asin(sin(phase))
        case .sawtooth:
            let cycle = (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1)
            return 2 * cycle - 1
        }
    }

    private func gain(for wave: PeriodicTraceWave) -> Double {
        switch wave {
        case .sine: 0.24
        case .square: 0.15
        case .triangle: 0.25
        case .sawtooth: 0.16
        }
    }

    private func scheduleKickPattern(at startTime: TimeInterval) {
        for kick in 0..<16 {
            for layer in 0..<2 {
                let kickPlayer = kickPlayers[kick * 2 + layer]
                let layerVolume: Float = layer == 0 ? 1 : 0.78
                kickPlayer.volume = layerVolume
                kickPlayer.currentTime = 0
                kickPlayer.play(atTime: startTime + Double(kick) * 0.5)
            }
        }
    }

    private func prepareKickPlayers() -> Bool {
        if kickPlayers.count == 32 { return true }
        guard let url = Bundle.main.url(forResource: "PeriodicKick", withExtension: "m4a") else { return false }

        kickPlayers = (0..<32).compactMap { _ in
            guard let kickPlayer = try? AVAudioPlayer(contentsOf: url) else { return nil }
            kickPlayer.prepareToPlay()
            return kickPlayer
        }
        return kickPlayers.count == 32
    }

    private func cancelKickPattern() {
        kickPlayers.forEach {
            $0.pause()
            $0.currentTime = 0
        }
    }
}

#Preview {
    MathItLevelSixtyEightView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 68) ?? 68)
}
