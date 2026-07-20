import SwiftUI
import Combine
import AVFoundation

// MARK: - Level 89 · Chladni Plate (two-phase pattern match)
//
// Sand grains random-walk with a step size proportional to the plate's
// vibration amplitude, draining off the antinodes and settling along the
// nodal lines of
//
//     cos(nπx)·cos(mπy) − cos(mπx)·cos(nπy) = 0
//
// The frequency knob f selects the vibration mode (n, m); the settling knob ζ
// sets how crisp the lines become. Match the goal figure for each of two
// phases to clear the level.

struct MathItLevelEightyNineView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        ChladniPlateView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, Chl.accent)
    }
}

// MARK: - Palette

private enum Chl {
    static let bg     = Color(red: 0.03, green: 0.05, blue: 0.10)
    static let panel  = Color(red: 0.06, green: 0.09, blue: 0.16)
    static let grid   = Color(red: 0.30, green: 0.55, blue: 1.0)
    static let accent = Color(red: 0.52, green: 0.72, blue: 1.0)
    static let sand   = Color(red: 0.96, green: 0.97, blue: 1.0)
    static let go     = Color(red: 0.42, green: 0.92, blue: 0.55)
}

// MARK: - Chladni math (shared by sim + goal preview)

private enum Chladni {
    /// Curated modes, ordered by rising spatial frequency, indexed by the f knob.
    static let modes: [(n: Int, m: Int)] =
        [(1, 2), (2, 1), (1, 3), (2, 3), (3, 2), (1, 4),
         (3, 4), (2, 5), (3, 5), (4, 5), (3, 6), (5, 6)]

    static let fMin = 1.0
    static let fMax = 8.0

    static func index(for f: Double) -> Int {
        let t = (f - fMin) / (fMax - fMin)
        return max(0, min(modes.count - 1, Int(t * Double(modes.count))))
    }

    static func mode(for f: Double) -> (n: Int, m: Int) { modes[index(for: f)] }

    /// Plate displacement at (x, y) ∈ [0,1]² — zero on the nodal lines.
    static func displacement(_ x: Double, _ y: Double, _ n: Int, _ m: Int) -> Double {
        let p = Double.pi, fn = Double(n), fm = Double(m)
        return cos(fn * p * x) * cos(fm * p * y)
             - cos(fm * p * x) * cos(fn * p * y)
    }
}

// MARK: - Simulation model (square plate only; stepped inside the Canvas draw)

private final class ChladniField {
    struct Grain { var x: Double; var y: Double }

    var grains: [Grain] = []
    private var lastDate: Date?

    func step(date: Date, frequency: Double, settling: Double, count: Int) {
        if let last = lastDate, date <= last { return }   // once per frame
        lastDate = date

        if grains.count < count {
            grains.append(contentsOf: (0..<(count - grains.count)).map { _ in
                Grain(x: .random(in: 0...1), y: .random(in: 0...1))
            })
        } else if grains.count > count {
            grains.removeLast(grains.count - count)
        }

        let (n, m) = Chladni.mode(for: frequency)
        let floor = (1.0 - settling) * 0.010 + 0.0004   // higher ζ → crisper lines
        let scale = 0.022

        for i in grains.indices {
            let v = abs(Chladni.displacement(grains[i].x, grains[i].y, n, m))   // ~0 on nodes
            let amp = floor + v * scale
            let nx = grains[i].x + Double.random(in: -1...1) * amp
            let ny = grains[i].y + Double.random(in: -1...1) * amp
            if nx >= 0, nx <= 1, ny >= 0, ny <= 1 {
                grains[i].x = nx
                grains[i].y = ny
            }   // otherwise reflect: keep position
        }
    }

    func reseed() { grains.removeAll(); lastDate = nil }
}

// MARK: - View

private struct ChladniPlateView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var frequency: Double = 1.0
    @State private var phase = 1
    @State private var hold = 0
    @State private var completed = false

    @StateObject private var tone = ToneGenerator()

    private let settling = 0.85            // fixed: always render crisp lines
    private let sandCount = 1800
    private let holdNeeded = 150           // ~5 s at 30 Hz — let the figure settle

    // Exact goal frequencies (slider snaps in 0.1 steps, so these are reachable):
    //   Phase 1 → f = 3.0 → mode (2,3) sweeping diagonals, like the reference image
    //   Phase 2 → f = 6.5 → mode (4,5) dense symmetric mandala
    private let phase1Freq = 3.0
    private let phase2Freq = 6.5

    private let field = ChladniField()
    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var targetFreq: Double { phase == 1 ? phase1Freq : phase2Freq }
    private var targetMode: (n: Int, m: Int) { Chladni.mode(for: targetFreq) }
    private var onTarget: Bool {
        abs(frequency - targetFreq) < 0.001            // must land exactly on the goal
    }

    /// Slider frequency → audible pitch (C3…C5, a smooth two-octave glide).
    private func audibleHz(_ f: Double) -> Double {
        130.81 * pow(2.0, (f - Chladni.fMin) / (Chladni.fMax - Chladni.fMin) * 2.0)
    }

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height

            ZStack(alignment: .top) {
                Chl.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 12)

                    plate
                        .frame(maxWidth: .infinity)
                        .frame(height: max(220, h * 0.52))
                        .clipped()

                    controls
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    Spacer(minLength: 8)
                }

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Plate Tuned",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: replay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .onReceive(tick) { _ in detect() }
            .onAppear {
                tone.setFrequency(audibleHz(frequency))
                tone.start()
            }
            .onDisappear { tone.stop() }
            .onChange(of: frequency) { tone.setFrequency(audibleHz(frequency)) }
            .onChange(of: completed) { tone.setPlaying(!completed) }
        }
    }

    // MARK: Win detection (depends only on the knob values)

    private func detect() {
        guard !completed else { return }
        hold = onTarget ? hold + 1 : 0
        if hold >= holdNeeded {
            hold = 0
            if phase == 1 {
                withAnimation(.easeInOut(duration: 0.4)) { phase = 2 }
                field.reseed()
            } else {
                withAnimation(.easeInOut(duration: 0.5)) { completed = true }
            }
        }
    }

    private func replay() {
        completed = false
        phase = 1
        hold = 0
        frequency = 1.0
        tone.setFrequency(audibleHz(1.0))
        tone.setPlaying(true)
        field.reseed()
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 7) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))
            EmptyView()
                .font(.trajan(34))
                .tracking(7)
                .foregroundStyle(Color.mathGold.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("cos(nπx)cos(mπy) − cos(mπx)cos(nπy) = 0")
                .font(.garamond(15))
                .foregroundStyle(.white.opacity(0.7))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Plate canvas

    private var plate: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                field.step(date: timeline.date,
                           frequency: frequency,
                           settling: settling,
                           count: sandCount)
                drawPlate(&ctx, size)
            }
        }
    }

    private func drawPlate(_ ctx: inout GraphicsContext, _ size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.16),
                                      Color(red: 0.02, green: 0.03, blue: 0.07)]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))

        let cells = 14
        let sx = size.width / CGFloat(cells), sy = size.height / CGFloat(cells)
        var grid = Path()
        for i in 0...cells {
            let x = CGFloat(i) * sx
            grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
            let y = CGFloat(i) * sy
            grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(grid, with: .color(Chl.grid.opacity(0.08)), lineWidth: 0.6)

        var grains = Path()
        for g in field.grains {
            let px = CGFloat(g.x) * size.width
            let py = CGFloat(g.y) * size.height
            grains.addEllipse(in: CGRect(x: px - 0.7, y: py - 0.7, width: 1.4, height: 1.4))
        }
        ctx.fill(grains, with: .color(Chl.sand.opacity(0.9)))
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                NodalPreview(mode: targetMode)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.4)))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke((onTarget ? Chl.go : Chl.accent).opacity(0.6), lineWidth: 1.4))

                VStack(alignment: .leading, spacing: 6) {
                    Text("PHASE \(phase)/2")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Chl.accent)
                    ProgressView(value: Double(hold), total: Double(holdNeeded))
                        .tint(Chl.go)
                        .frame(width: 150)
                        .opacity(onTarget ? 1 : 0.15)
                }
                Spacer(minLength: 0)
                Button(action: { field.reseed() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }

            slider("f", value: $frequency, range: 1...8, format: "%.1f")
        }
    }

    private func slider(_ symbol: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(symbol)
                    .font(.garamond(16))
                    .italic()
                    .foregroundStyle(Chl.accent)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range, step: 0.1).tint(Chl.accent)
        }
    }
}

// MARK: - Goal nodal-line thumbnail

private struct NodalPreview: View {
    let mode: (n: Int, m: Int)

    var body: some View {
        Canvas { ctx, size in
            let res = 56
            var dots = Path()
            for i in 0..<res {
                for j in 0..<res {
                    let x = Double(i) / Double(res - 1)
                    let y = Double(j) / Double(res - 1)
                    if abs(Chladni.displacement(x, y, mode.n, mode.m)) < 0.07 {
                        let px = CGFloat(x) * size.width
                        let py = CGFloat(y) * size.height
                        dots.addEllipse(in: CGRect(x: px - 0.8, y: py - 0.8, width: 1.6, height: 1.6))
                    }
                }
            }
            ctx.fill(dots, with: .color(Chl.sand.opacity(0.9)))
        }
        .padding(4)
    }
}

// MARK: - Tone generator
//
// A single sine voice. Frequency and amplitude are smoothed per-sample on the
// audio thread, so sliding the knob glides between pitches with no clicks or
// zipper noise. Kept at a soft level and mixed with other audio.

private final class ToneGenerator: ObservableObject {
    private let engine = AVAudioEngine()
    private var srcNode: AVAudioSourceNode?
    private var running = false

    private var sampleRate: Double = 44_100
    private var phase: Double = 0
    private var currentFreq: Double = 130.81
    private var targetFreq: Double = 130.81
    private var currentAmp: Double = 0
    private var targetAmp: Double = 0

    private let level = 0.10                // soft, comfortable volume

    init() {
        let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        sampleRate = mixerFormat.sampleRate > 0 ? mixerFormat.sampleRate : 44_100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, ablPointer -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(ablPointer)
            let twoPi = 2.0 * Double.pi
            for frame in 0..<Int(frameCount) {
                // One-pole smoothing toward the targets (~25–40 ms time constants).
                self.currentFreq += (self.targetFreq - self.currentFreq) * 0.0009
                self.currentAmp  += (self.targetAmp  - self.currentAmp)  * 0.0006
                let sample = Float(sin(self.phase) * self.currentAmp)
                self.phase += twoPi * self.currentFreq / self.sampleRate
                if self.phase > twoPi { self.phase -= twoPi }
                for buffer in abl {
                    let buf = buffer.mData!.assumingMemoryBound(to: Float.self)
                    buf[frame] = sample
                }
            }
            return noErr
        }
        srcNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    func start() {
        configureSession()
        targetAmp = level
        guard !running else { return }
        do { try engine.start(); running = true } catch { running = false }
    }

    func stop() {
        targetAmp = 0
        // Let the amplitude fade before tearing the engine down (avoids a click).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.engine.stop()
            self?.running = false
        }
    }

    func setFrequency(_ hz: Double) { targetFreq = hz }

    func setPlaying(_ on: Bool) { targetAmp = on ? level : 0 }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}

#Preview {
    MathItLevelEightyNineView(onContinue: {}, onLevelSelect: {})
}
