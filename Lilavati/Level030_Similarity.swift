import AVFoundation
import SwiftUI

// MARK: - Level 112 - Similarity (Wildlife Zoom)
//
// A wildlife shoot. Each round opens on the scene itself — the animal standing
// in its habitat (forest, open sky, savanna) with the photographer's camera in
// the foreground. Tap the camera to raise it: the view becomes a circular lens
// with a centre crosshair. The zoom ring scales the animal — bigger or
// smaller, always the SAME proportions — and when it exactly fills the gold
// reference outline the shutter clicks. Zoom never distorts: that's
// similarity, and the zoom factor is the scale factor.

struct MathItLevelOneHundredTwelveView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private enum Phase { case scene, lens }

    private struct Round {
        let name: String
        let baseHeight: CGFloat     // animal height at zoom ×1
        let targetHeight: CGFloat   // reference outline height
        let shape: AnyShape
        let aspect: CGFloat         // width / height

        var requiredZoom: CGFloat { targetHeight / baseHeight }
    }

    private let rounds: [Round] = [
        Round(name: "stag", baseHeight: 92, targetHeight: 150,
              shape: AnyShape(StagShape()), aspect: 1.15),
        Round(name: "eagle", baseHeight: 168, targetHeight: 106,
              shape: AnyShape(EagleShape()), aspect: 1.7),
        Round(name: "elephant", baseHeight: 88, targetHeight: 154,
              shape: AnyShape(ElephantShape()), aspect: 1.35)
    ]

    @State private var phase: Phase = .scene
    @State private var roundIndex = 0
    @State private var zoom: CGFloat = 1.0
    @State private var capturedZooms: [CGFloat] = []
    @State private var captureFlash = false
    @State private var capturing = false
    @State private var dwellGen = 0
    @State private var completed = false

    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let accent = Color(red: 0.36, green: 0.86, blue: 1.0)
    private let zoomRange: ClosedRange<CGFloat> = 0.5...2.5
    private let shutter = CameraShutterPlayer()

    private var round: Round { rounds[min(roundIndex, rounds.count - 1)] }
    private var matched: Bool {
        abs(zoom - round.requiredZoom) / round.requiredZoom < 0.035
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.ignoresSafeArea()

                if phase == .scene {
                    sceneView(size: size)
                        .transition(.opacity)
                } else {
                    lensView(size: size)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                filmStrip
                    .position(x: size.width / 2, y: size.height * 0.665)

                if phase == .lens {
                    zoomControl(width: min(size.width - 72, 330))
                        .position(x: size.width / 2, y: size.height * 0.81)
                }

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                // Shutter flash.
                Color.white
                    .ignoresSafeArea()
                    .opacity(captureFlash ? 0.85 : 0)
                    .allowsHitTesting(false)

                CompletionOverlay(
                    title: "Portfolio Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
        }
        .environment(\.mathItAccent, accent)
    }

    // MARK: - Scene (camera down)

    private func sceneView(size: CGSize) -> some View {
        let frame = CGRect(x: 20, y: size.height * 0.185,
                           width: size.width - 40, height: size.height * 0.42)

        return ZStack {
            habitat(frame: frame)

            // The animal in its habitat.
            round.shape
                .fill(.white.opacity(0.85))
                .frame(width: round.baseHeight * round.aspect * 0.9,
                       height: round.baseHeight * 0.9)
                .position(animalScenePosition(frame: frame))

            // The camera in the foreground, below the film strip — tap to raise it.
            CameraIllustration(accent: accent)
                .frame(width: 128, height: 86)
                .contentShape(Rectangle().inset(by: -18))
                .onTapGesture { raiseCamera() }
                .position(x: size.width / 2, y: size.height * 0.815)

            Text("tap the camera to raise it")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .position(x: size.width / 2, y: size.height * 0.895)
        }
    }

    private func animalScenePosition(frame: CGRect) -> CGPoint {
        switch roundIndex {
        case 1:  CGPoint(x: frame.midX + frame.width * 0.16, y: frame.minY + frame.height * 0.30)  // eagle in the sky
        default: CGPoint(x: frame.midX + frame.width * 0.10, y: frame.maxY - frame.height * 0.30)  // grounded
        }
    }

    @ViewBuilder
    private func habitat(frame: CGRect) -> some View {
        switch roundIndex {
        case 0: ForestScene().frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        case 1: SkyScene().frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        default: SavannaScene().frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    private func raiseCamera() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            phase = .lens
        }
    }

    // MARK: - Lens (camera up) — circular, with a centre crosshair

    private func lensView(size: CGSize) -> some View {
        let d = min(size.width - 52, size.height * 0.44)

        return ZStack {
            // Barrel rings.
            Circle().fill(Color(red: 0.05, green: 0.06, blue: 0.08))
            Circle().stroke(.white.opacity(0.35), lineWidth: 3)
            Circle().stroke(.white.opacity(0.12), lineWidth: 1).padding(7)

            // Focal tick marks around the rim.
            Canvas { ctx, s in
                let c = CGPoint(x: s.width / 2, y: s.height / 2)
                let r = s.width / 2 - 12
                for k in 0..<24 {
                    let a = Double(k) / 24 * 2 * .pi
                    let long = k % 6 == 0
                    var tick = Path()
                    tick.move(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                    tick.addLine(to: CGPoint(x: c.x + cos(a) * (r - (long ? 9 : 5)),
                                             y: c.y + sin(a) * (r - (long ? 9 : 5))))
                    ctx.stroke(tick, with: .color(.white.opacity(long ? 0.4 : 0.18)), lineWidth: long ? 1.4 : 1)
                }
            }

            // Reference outline — the shot the editor wants.
            round.shape
                .stroke(gold.opacity(matched ? 0.95 : 0.6),
                        style: StrokeStyle(lineWidth: 1.6, dash: matched ? [] : [6, 5]))
                .frame(width: round.targetHeight * round.aspect, height: round.targetHeight)
                .shadow(color: matched ? gold.opacity(0.5) : .clear, radius: 10)

            // The animal, scaled by the zoom — same proportions at every size.
            round.shape
                .fill(.white.opacity(0.88))
                .frame(width: round.baseHeight * round.aspect, height: round.baseHeight)
                .scaleEffect(zoom)
                .animation(.easeOut(duration: 0.1), value: zoom)

            // Centre crosshair — the plus.
            CrosshairPlus()
                .stroke(matched ? gold : .white.opacity(0.75), lineWidth: 1.4)
                .frame(width: 26, height: 26)

            // Readouts inside the lens.
            VStack {
                Text(round.name)
                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 26)
                Spacer()
                Text(matched
                     ? String(format: "k = %.2f — same shape", round.requiredZoom)
                     : String(format: "×%.2f", zoom))
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(matched ? gold : accent)
                    .padding(.bottom, 26)
            }
        }
        .frame(width: d, height: d)
        .clipShape(Circle())
        .overlay(Circle().stroke(matched ? gold.opacity(0.8) : .white.opacity(0.3), lineWidth: 2.4))
        .shadow(color: matched ? gold.opacity(0.3) : .black.opacity(0.6), radius: 16)
        .position(x: size.width / 2, y: size.height * 0.40)
        .animation(.easeInOut(duration: 0.2), value: matched)
    }

    // MARK: - Film strip

    private var filmStrip: some View {
        HStack(spacing: 10) {
            ForEach(rounds.indices, id: \.self) { i in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(i < capturedZooms.count ? Color.white.opacity(0.10) : Color.white.opacity(0.03))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(i < capturedZooms.count ? gold.opacity(0.7) : .white.opacity(0.18),
                                style: StrokeStyle(lineWidth: 1.2, dash: i < capturedZooms.count ? [] : [4, 4]))
                    if i < capturedZooms.count {
                        VStack(spacing: 2) {
                            rounds[i].shape
                                .fill(.white.opacity(0.85))
                                .frame(width: 30 * rounds[i].aspect, height: 30)
                            Text(String(format: "k %.2f", capturedZooms[i]))
                                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(gold.opacity(0.85))
                        }
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                    } else {
                        Image(systemName: "camera")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }
                .frame(width: 66, height: 52)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: capturedZooms.count)
    }

    // MARK: - Zoom control

    private func zoomControl(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Slider(value: $zoom, in: zoomRange)
                .tint(matched ? gold : accent)
                .frame(width: width)
                .disabled(capturing || completed)
                .onChange(of: zoom) { _, _ in
                    zoomChanged()
                }
            HStack {
                Label("×0.5", systemImage: "minus.magnifyingglass")
                Spacer()
                Text("ZOOM")
                    .tracking(4)
                Spacer()
                Label("×2.5", systemImage: "plus.magnifyingglass")
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
            .frame(width: width)
        }
    }

    // MARK: - Capture logic

    private func zoomChanged() {
        guard !capturing, !completed, phase == .lens else { return }
        dwellGen += 1
        guard matched else { return }
        let gen = dwellGen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard gen == dwellGen, matched, !capturing else { return }
            capture()
        }
    }

    private func capture() {
        capturing = true
        shutter.click()
        HapticPlayer.playCompletionTap()
        withAnimation(.easeOut(duration: 0.08)) { captureFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.3)) { captureFlash = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                capturedZooms.append(round.requiredZoom)
            }
            if roundIndex < rounds.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    roundIndex += 1
                    zoom = 1.0
                    capturing = false
                    withAnimation(.easeInOut(duration: 0.4)) {
                        phase = .scene       // lower the camera for the next habitat
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                        completed = true
                    }
                }
            }
        }
    }

    private func reset() {
        completed = false
        capturing = false
        roundIndex = 0
        zoom = 1.0
        capturedZooms = []
        phase = .scene
    }
}

// MARK: - Crosshair

private struct CrosshairPlus: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let arm = rect.width / 2
        let gap: CGFloat = 4
        path.move(to: CGPoint(x: c.x - arm, y: c.y)); path.addLine(to: CGPoint(x: c.x - gap, y: c.y))
        path.move(to: CGPoint(x: c.x + gap, y: c.y)); path.addLine(to: CGPoint(x: c.x + arm, y: c.y))
        path.move(to: CGPoint(x: c.x, y: c.y - arm)); path.addLine(to: CGPoint(x: c.x, y: c.y - gap))
        path.move(to: CGPoint(x: c.x, y: c.y + gap)); path.addLine(to: CGPoint(x: c.x, y: c.y + arm))
        return path
    }
}

// MARK: - Camera illustration

private struct CameraIllustration: View {
    let accent: Color

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 2.2)
            ZStack {
                // Body.
                RoundedRectangle(cornerRadius: 13)
                    .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.10)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.25), lineWidth: 1.2))
                // Top plate: viewfinder bump + shutter button.
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.16))
                    .frame(width: 34, height: 12)
                    .offset(x: -30, y: -46)
                Capsule()
                    .fill(accent)
                    .frame(width: 16, height: 6)
                    .offset(x: 34, y: -46)
                    .shadow(color: accent.opacity(0.4 + pulse * 0.4), radius: 5)
                // Lens barrel.
                Circle().fill(Color(white: 0.07))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(.white.opacity(0.4 + pulse * 0.3), lineWidth: 1.6))
                Circle().fill(Color(red: 0.10, green: 0.16, blue: 0.24))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                // Glass glint.
                Circle().fill(.white.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .offset(x: -7, y: -8)
                // Grip line.
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.08))
                    .frame(width: 14, height: 56)
                    .offset(x: 50, y: 0)
            }
        }
    }
}

// MARK: - Habitats

private struct ForestScene: View {
    var body: some View {
        Canvas { ctx, size in
            let green = Color(red: 0.16, green: 0.34, blue: 0.22)
            // Ground.
            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: size.height * 0.78))
            ground.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.80),
                                control: CGPoint(x: size.width / 2, y: size.height * 0.72))
            ground.addLine(to: CGPoint(x: size.width, y: size.height))
            ground.addLine(to: CGPoint(x: 0, y: size.height))
            ground.closeSubpath()
            ctx.fill(ground, with: .color(green.opacity(0.4)))

            // Pines.
            for (fx, s) in [(0.10, 1.0), (0.24, 0.7), (0.86, 0.9), (0.72, 0.55)] {
                let baseX = size.width * fx
                let baseY = size.height * 0.78
                let treeH = size.height * 0.42 * s
                let treeW = treeH * 0.42
                for layer in 0..<3 {
                    let ly = baseY - treeH * (0.28 + 0.26 * CGFloat(layer))
                    let lw = treeW * (1 - 0.24 * CGFloat(layer))
                    var tri = Path()
                    tri.move(to: CGPoint(x: baseX, y: ly - treeH * 0.24))
                    tri.addLine(to: CGPoint(x: baseX + lw / 2, y: ly))
                    tri.addLine(to: CGPoint(x: baseX - lw / 2, y: ly))
                    tri.closeSubpath()
                    ctx.fill(tri, with: .color(green.opacity(0.75)))
                }
                ctx.fill(Path(CGRect(x: baseX - 2, y: baseY - treeH * 0.14, width: 4, height: treeH * 0.14)),
                         with: .color(Color(red: 0.32, green: 0.22, blue: 0.13)))
            }

            // Moon.
            ctx.fill(Path(ellipseIn: CGRect(x: size.width * 0.80, y: size.height * 0.08, width: 26, height: 26)),
                     with: .color(.white.opacity(0.25)))
        }
    }
}

private struct SkyScene: View {
    var body: some View {
        Canvas { ctx, size in
            // Sky wash.
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(
                        Gradient(colors: [Color(red: 0.06, green: 0.12, blue: 0.24), Color(red: 0.02, green: 0.04, blue: 0.10)]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            // Clouds.
            for (fx, fy, s) in [(0.18, 0.24, 1.0), (0.66, 0.14, 0.7), (0.42, 0.52, 0.85), (0.82, 0.62, 0.6)] {
                let cw = size.width * 0.24 * s
                let base = CGPoint(x: size.width * fx, y: size.height * fy)
                for (dx, dy, r) in [(0.0, 0.0, 1.0), (-0.32, 0.10, 0.7), (0.34, 0.12, 0.65)] {
                    let rr = cw * 0.32 * r
                    ctx.fill(Path(ellipseIn: CGRect(x: base.x + cw * dx - rr, y: base.y + cw * dy * 0.4 - rr * 0.7,
                                                    width: rr * 2, height: rr * 1.4)),
                             with: .color(.white.opacity(0.10)))
                }
            }
            // Sun glow.
            ctx.fill(Path(ellipseIn: CGRect(x: size.width * 0.06, y: size.height * 0.06, width: 34, height: 34)),
                     with: .color(Color(red: 0.98, green: 0.85, blue: 0.5).opacity(0.35)))
        }
    }
}

private struct SavannaScene: View {
    var body: some View {
        Canvas { ctx, size in
            let earth = Color(red: 0.45, green: 0.33, blue: 0.18)
            // Ground.
            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: size.height * 0.80))
            ground.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.78),
                                control: CGPoint(x: size.width / 2, y: size.height * 0.84))
            ground.addLine(to: CGPoint(x: size.width, y: size.height))
            ground.addLine(to: CGPoint(x: 0, y: size.height))
            ground.closeSubpath()
            ctx.fill(ground, with: .color(earth.opacity(0.45)))

            // Acacia trees: thin trunk, flat canopy.
            for (fx, s) in [(0.14, 1.0), (0.84, 0.72)] {
                let baseX = size.width * fx
                let baseY = size.height * 0.80
                let treeH = size.height * 0.34 * s
                var trunk = Path()
                trunk.move(to: CGPoint(x: baseX, y: baseY))
                trunk.addQuadCurve(to: CGPoint(x: baseX + treeH * 0.14, y: baseY - treeH * 0.8),
                                   control: CGPoint(x: baseX - treeH * 0.08, y: baseY - treeH * 0.4))
                ctx.stroke(trunk, with: .color(Color(red: 0.35, green: 0.25, blue: 0.14)), lineWidth: 3.4)
                ctx.fill(Path(ellipseIn: CGRect(x: baseX - treeH * 0.42, y: baseY - treeH * 1.02,
                                                width: treeH * 1.1, height: treeH * 0.30)),
                         with: .color(Color(red: 0.28, green: 0.42, blue: 0.20).opacity(0.85)))
            }

            // Low sun.
            ctx.fill(Path(ellipseIn: CGRect(x: size.width * 0.68, y: size.height * 0.12, width: 40, height: 40)),
                     with: .color(Color(red: 0.98, green: 0.62, blue: 0.30).opacity(0.4)))
        }
    }
}

// MARK: - Shutter sound

/// A camera "click-clack": two short filtered noise bursts (shutter open, then
/// mirror return), synthesized live.
private final class CameraShutterPlayer {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let lock = NSLock()
    private var amplitude: Double = 0
    private var filtered: Double = 0

    private lazy var sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self else { return noErr }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        // ~18 ms decay — a snap, not a tone.
        let decay = pow(0.001, 1.0 / (0.018 * self.sampleRate))

        for frame in 0..<Int(frameCount) {
            self.lock.lock()
            self.amplitude *= decay
            if self.amplitude < 0.0004 { self.amplitude = 0 }
            let amp = self.amplitude
            self.lock.unlock()

            // Band-limited noise burst.
            let noise = Double.random(in: -1...1)
            self.filtered += (noise - self.filtered) * 0.45
            let sample = Float(self.filtered * amp)

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

    func click() {
        if !engine.isRunning { try? engine.start() }
        burst(0.5)
        // The mirror-return "clack", a touch softer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            self.burst(0.3)
        }
    }

    private func burst(_ level: Double) {
        lock.lock()
        amplitude = level
        lock.unlock()
    }
}

// MARK: - Animal silhouettes

private struct StagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var path = Path()
        path.move(to: pt(0.12, 0.55))
        path.addQuadCurve(to: pt(0.42, 0.44), control: pt(0.25, 0.42))
        path.addLine(to: pt(0.60, 0.46))
        path.addQuadCurve(to: pt(0.72, 0.30), control: pt(0.68, 0.38))
        path.addLine(to: pt(0.78, 0.26))
        path.addLine(to: pt(0.90, 0.28))
        path.addLine(to: pt(0.80, 0.36))
        path.addQuadCurve(to: pt(0.70, 0.55), control: pt(0.74, 0.46))
        path.addLine(to: pt(0.68, 0.60))
        path.addLine(to: pt(0.66, 0.92))
        path.addLine(to: pt(0.61, 0.92))
        path.addLine(to: pt(0.59, 0.64))
        path.addLine(to: pt(0.50, 0.64))
        path.addLine(to: pt(0.34, 0.62))
        path.addLine(to: pt(0.33, 0.92))
        path.addLine(to: pt(0.28, 0.92))
        path.addLine(to: pt(0.26, 0.62))
        path.addQuadCurve(to: pt(0.12, 0.62), control: pt(0.18, 0.64))
        path.closeSubpath()
        // Antlers.
        path.move(to: pt(0.74, 0.26))
        path.addLine(to: pt(0.70, 0.10))
        path.addLine(to: pt(0.64, 0.16))
        path.addLine(to: pt(0.70, 0.10))
        path.addLine(to: pt(0.74, 0.04))
        path.addLine(to: pt(0.70, 0.10))
        path.move(to: pt(0.78, 0.24))
        path.addLine(to: pt(0.84, 0.08))
        path.addLine(to: pt(0.90, 0.14))
        path.addLine(to: pt(0.84, 0.08))
        path.addLine(to: pt(0.80, 0.02))
        path.move(to: pt(0.12, 0.55))
        path.addLine(to: pt(0.08, 0.52))
        return path
    }
}

private struct EagleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var path = Path()
        path.move(to: pt(0.02, 0.30))
        path.addQuadCurve(to: pt(0.34, 0.44), control: pt(0.16, 0.28))
        path.addQuadCurve(to: pt(0.50, 0.50), control: pt(0.43, 0.48))
        path.addQuadCurve(to: pt(0.66, 0.44), control: pt(0.57, 0.48))
        path.addQuadCurve(to: pt(0.98, 0.30), control: pt(0.84, 0.28))
        path.addLine(to: pt(0.86, 0.42))
        path.addLine(to: pt(0.80, 0.40))
        path.addLine(to: pt(0.72, 0.52))
        path.addLine(to: pt(0.56, 0.60))
        path.addLine(to: pt(0.58, 0.78))
        path.addLine(to: pt(0.50, 0.70))
        path.addLine(to: pt(0.42, 0.78))
        path.addLine(to: pt(0.44, 0.60))
        path.addLine(to: pt(0.34, 0.54))
        path.addLine(to: pt(0.30, 0.44))
        path.addLine(to: pt(0.24, 0.46))
        path.addLine(to: pt(0.28, 0.40))
        path.addLine(to: pt(0.20, 0.40))
        path.addLine(to: pt(0.14, 0.42))
        path.closeSubpath()
        return path
    }
}

private struct ElephantShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var path = Path()
        path.move(to: pt(0.06, 0.42))
        path.addQuadCurve(to: pt(0.50, 0.26), control: pt(0.24, 0.22))
        path.addQuadCurve(to: pt(0.74, 0.30), control: pt(0.64, 0.24))
        path.addQuadCurve(to: pt(0.86, 0.44), control: pt(0.84, 0.34))
        path.addQuadCurve(to: pt(0.90, 0.70), control: pt(0.92, 0.55))
        path.addQuadCurve(to: pt(0.84, 0.82), control: pt(0.88, 0.80))
        path.addQuadCurve(to: pt(0.84, 0.70), control: pt(0.81, 0.76))
        path.addQuadCurve(to: pt(0.78, 0.48), control: pt(0.80, 0.58))
        path.addQuadCurve(to: pt(0.64, 0.56), control: pt(0.72, 0.56))
        path.addLine(to: pt(0.66, 0.92))
        path.addLine(to: pt(0.56, 0.92))
        path.addLine(to: pt(0.54, 0.62))
        path.addLine(to: pt(0.34, 0.62))
        path.addLine(to: pt(0.32, 0.92))
        path.addLine(to: pt(0.22, 0.92))
        path.addLine(to: pt(0.20, 0.58))
        path.addQuadCurve(to: pt(0.06, 0.42), control: pt(0.08, 0.56))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MathItLevelOneHundredTwelveView(onContinue: {}, onLevelSelect: {})
}
