import AVFoundation
import SwiftUI

// MARK: - Level 107 - Radicals (Spiral of Theodorus → Memory Melody)
//
// Phase 1 — construction: an increment/decrement control on √x adds or removes
// the right triangles of the Spiral of Theodorus (legs √n and 1 → hypotenuse
// √(n+1)). Phase 2 — melody: each finished triangle becomes a note, highest
// pitch on the smallest radical (√2) down to the lowest on the largest. Three
// stages play a growing sequence (5 → 6 → 7 notes); each note's triangle
// glows as it plays, and the player must repeat it from memory.

struct MathItLevelOneHundredSevenView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private enum Phase { case building, preview, input, done }

    /// Spoke endpoints √1 … √17 in unit maths coordinates — the full shell
    /// (16 triangles = 16 notes).
    private static let spokes: [CGPoint] = {
        var out: [CGPoint] = []
        var phi = 0.0
        for k in 1...17 {
            let r = Double(k).squareRoot()
            out.append(CGPoint(x: cos(phi) * r, y: sin(phi) * r))
            phi += atan(1.0 / Double(k).squareRoot())
        }
        return out
    }()

    /// 16 notes descending: highest pitch on √2, lowest on √17 (two octaves).
    private let noteFreqs: [Double] = [
        1046.50, 987.77, 880.00, 783.99, 698.46, 659.25, 587.33, 523.25,
        493.88, 440.00, 392.00, 349.23, 329.63, 293.66, 261.63, 246.94
    ]
    private var triangleCount: Int { 16 }
    private let stageLengths = [5, 6, 7]

    @State private var x = 1                    // current √x during construction
    @State private var phase: Phase = .building
    @State private var highlighted: Int?        // triangle glowing right now
    @State private var flashGen = 0

    @State private var stageIndex = 0
    @State private var sequence: [Int] = []
    @State private var inputIndex = 0
    @State private var previewGen = 0
    @State private var wrongFlash = false
    @State private var completed = false

    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let player = SpiralNotePlayer()

    private var built: Int { x - 1 }            // triangles currently drawn

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let lay = layout(size)

            ZStack {
                Color.black.ignoresSafeArea()

                // Faint radial spokes under the triangles.
                Canvas { ctx, _ in
                    for j in 0...min(built, Self.spokes.count - 1) {
                        var line = Path()
                        line.move(to: lay.origin)
                        line.addLine(to: lay.pts[j])
                        ctx.stroke(line, with: .color(.white.opacity(0.22)), lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)

                // Triangles (also the playable notes).
                ForEach(0..<triangleCount, id: \.self) { i in
                    if i < built {
                        triangleView(i, lay: lay, size: size)
                    }
                }

                // Labels on top of the triangles: √k along each spoke (one side
                // of the triangle), and a unit "1" on each triangle's base.
                Canvas { ctx, _ in
                    // Radicals on the spokes — includes √1 at the base.
                    for j in 0..<min(built + 1, Self.spokes.count) {
                        let p = lay.pts[j]
                        var dx = p.x - lay.origin.x, dy = p.y - lay.origin.y
                        let len = max(hypot(dx, dy), 0.001)
                        dx /= len; dy /= len
                        let along = CGPoint(x: lay.origin.x + dx * len * 0.6,
                                            y: lay.origin.y + dy * len * 0.6)
                        // Nudge perpendicular so the number sits beside the spoke.
                        let pos = CGPoint(x: along.x - dy * 9, y: along.y + dx * 9)
                        ctx.draw(
                            Text("√\(j + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white),
                            at: pos
                        )
                    }
                    // Unit "1" just outside each triangle's base edge.
                    for i in 0..<min(built, triangleCount) {
                        let a = lay.pts[i], b = lay.pts[i + 1]
                        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                        var ox = mid.x - lay.origin.x, oy = mid.y - lay.origin.y
                        let olen = max(hypot(ox, oy), 0.001)
                        ox /= olen; oy /= olen
                        let pos = CGPoint(x: mid.x + ox * 10, y: mid.y + oy * 10)
                        ctx.draw(
                            Text("1")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85)),
                            at: pos
                        )
                    }
                }
                .allowsHitTesting(false)

                // Ghost preview of the next triangle to add.
                if phase == .building, built < triangleCount {
                    SpiralTriangle(a: lay.origin, b: lay.pts[built], c: lay.pts[built + 1])
                        .stroke(gold.opacity(0.5), style: StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
                        .allowsHitTesting(false)
                }

                // Origin pip.
                Circle().fill(.white.opacity(0.85)).frame(width: 6, height: 6)
                    .position(lay.origin)
                    .allowsHitTesting(false)

                controls(size: size)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Melody Mastered",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
        }
        .environment(\.mathItAccent, gold)
    }

    // MARK: - Triangle view

    private func triangleView(_ i: Int, lay: (origin: CGPoint, pts: [CGPoint]), size: CGSize) -> some View {
        let color = Color(hue: Double(i) / Double(triangleCount), saturation: 0.82, brightness: 0.98)
        let hot = highlighted == i
        let shape = SpiralTriangle(a: lay.origin, b: lay.pts[i], c: lay.pts[i + 1])
        return shape
            .fill(color.opacity(hot ? 1.0 : 0.8))
            .overlay(shape.stroke(.white.opacity(hot ? 0.95 : 0.28), lineWidth: hot ? 2.6 : 1))
            .shadow(color: hot ? color.opacity(0.85) : .clear, radius: hot ? 16 : 0)
            .contentShape(shape)
            .onTapGesture { if phase == .input { handleTap(i) } }
            .allowsHitTesting(phase == .input)
            .frame(width: size.width, height: size.height)
            .animation(.easeOut(duration: 0.12), value: hot)
    }

    // MARK: - Controls / status

    @ViewBuilder
    private func controls(size: CGSize) -> some View {
        VStack(spacing: 12) {
            Spacer()
            switch phase {
            case .building:
                Text("Grow the spiral to √17")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                HStack(spacing: 22) {
                    stepButton("minus") { decrement() }.disabled(x <= 1)
                    Text("√\(x)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(gold)
                        .frame(minWidth: 70)
                        .contentTransition(.numericText())
                    stepButton("plus") { increment() }.disabled(x >= triangleCount + 1)
                }
            case .preview, .input:
                stageDots
                Text(phase == .preview ? "Listen…" : "Your turn — repeat the melody")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(phase == .preview ? gold : .white.opacity(0.65))
                    .opacity(wrongFlash ? 0.4 : 1)
            case .done:
                EmptyView()
            }
        }
        .padding(.bottom, size.height * 0.06)
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .allowsHitTesting(phase == .building)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.black)
                .frame(width: 52, height: 52)
                .background(Circle().fill(gold))
        }
        .buttonStyle(.plain)
    }

    private var stageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<stageLengths.count, id: \.self) { i in
                Circle().fill(i <= stageIndex ? gold : Color.white.opacity(0.2))
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: - Construction

    private func increment() {
        guard x <= triangleCount else { return }
        x += 1
        let tri = x - 2                       // the triangle just added
        HapticPlayer.playLightTap()
        if tri >= 0, tri < noteFreqs.count {
            player.play(noteFreqs[tri])
            flash(tri)
        }
        if x == triangleCount + 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { beginStage(0) }
        }
    }

    private func decrement() {
        guard x > 1 else { return }
        x -= 1
        HapticPlayer.playLightTap()
    }

    private func flash(_ i: Int) {
        highlighted = i
        flashGen += 1
        let gen = flashGen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if flashGen == gen, phase != .preview { highlighted = nil }
        }
    }

    // MARK: - Memory game

    private func beginStage(_ index: Int) {
        stageIndex = index
        inputIndex = 0
        sequence = (0..<stageLengths[index]).map { _ in Int.random(in: 0..<triangleCount) }
        playPreview()
    }

    private func playPreview() {
        phase = .preview
        highlighted = nil
        previewGen += 1
        let gen = previewGen
        var delay = 0.6
        let onDur = 0.4, gap = 0.24
        for note in sequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard gen == previewGen else { return }
                highlighted = note
                player.play(noteFreqs[note])
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + onDur) {
                guard gen == previewGen, highlighted == note else { return }
                highlighted = nil
            }
            delay += onDur + gap
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) {
            guard gen == previewGen else { return }
            highlighted = nil
            inputIndex = 0
            phase = .input
        }
    }

    private func handleTap(_ i: Int) {
        guard phase == .input else { return }
        player.play(noteFreqs[i])
        flash(i)

        if i == sequence[inputIndex] {
            inputIndex += 1
            if inputIndex >= sequence.count {
                phase = .preview                     // brief lock while transitioning
                HapticPlayer.playCompletionTap()
                if stageIndex < stageLengths.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { beginStage(stageIndex + 1) }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        phase = .done
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { completed = true }
                    }
                }
            }
        } else {
            // Wrong: flash the prompt and replay the same sequence.
            HapticPlayer.playLightTap()
            wrongFlash = true
            phase = .preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                wrongFlash = false
                playPreview()
            }
        }
    }

    private func reset() {
        completed = false
        x = 1
        stageIndex = 0
        inputIndex = 0
        sequence = []
        highlighted = nil
        phase = .building
    }

    // MARK: - Geometry

    private func layout(_ size: CGSize) -> (origin: CGPoint, pts: [CGPoint]) {
        let su = Self.spokes.map { CGPoint(x: $0.x, y: -$0.y) }   // flip y → spiral winds up
        let minX = su.map(\.x).min() ?? 0, maxX = su.map(\.x).max() ?? 1
        let minY = su.map(\.y).min() ?? 0, maxY = su.map(\.y).max() ?? 1
        let bw = max(maxX - minX, 0.001), bh = max(maxY - minY, 0.001)
        let scale = min((size.width - 60) / bw, (size.height * 0.48) / bh)
        let areaCenter = CGPoint(x: size.width / 2, y: size.height * 0.40)
        let bcx = (minX + maxX) / 2, bcy = (minY + maxY) / 2
        func screen(_ u: CGPoint) -> CGPoint {
            CGPoint(x: areaCenter.x + (u.x - bcx) * scale, y: areaCenter.y + (u.y - bcy) * scale)
        }
        return (screen(.zero), su.map(screen))
    }
}

// MARK: - Triangle shape

private struct SpiralTriangle: Shape {
    let a: CGPoint
    let b: CGPoint
    let c: CGPoint

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath()
        }
    }
}

// MARK: - Note synth

/// A soft plucked sine tone with a short decay envelope.
private final class SpiralNotePlayer {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let lock = NSLock()
    private var frequency: Double = 440
    private var amplitude: Double = 0
    private var phase: Double = 0

    private lazy var sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self else { return noErr }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let decay = pow(0.001, 1.0 / (0.42 * self.sampleRate))   // ~0.42 s tail

        for frame in 0..<Int(frameCount) {
            self.lock.lock()
            let freq = self.frequency
            self.amplitude *= decay
            if self.amplitude < 0.0004 { self.amplitude = 0 }
            let amp = self.amplitude
            self.lock.unlock()

            // Two partials for a warmer, bell-like note.
            let sample = Float((sin(self.phase) * 0.7 + sin(self.phase * 2) * 0.2) * amp)
            self.phase += 2 * .pi * freq / self.sampleRate
            if self.phase > 2 * .pi { self.phase -= 2 * .pi }

            for buffer in buffers {
                buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
            }
        }
        return noErr
    }

    init() {
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        try? engine.start()
    }

    func play(_ freq: Double) {
        lock.lock()
        frequency = freq
        amplitude = 0.18
        phase = 0
        lock.unlock()
        if !engine.isRunning { try? engine.start() }
    }
}

#Preview {
    MathItLevelOneHundredSevenView(onContinue: {}, onLevelSelect: {})
}
