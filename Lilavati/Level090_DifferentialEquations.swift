import SwiftUI
import Combine

// Level 89 · Differential Equations — coupled Lotka-Volterra rates.

struct MathItLevelEightyEightView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        EcosystemSim(onContinue: onContinue, onLevelSelect: onLevelSelect)
    }
}

// MARK: - Palette

private enum Eco {
    static let sheep  = Color(red: 0.95, green: 0.96, blue: 0.94)
    static let fox    = Color(red: 1.0,  green: 0.50, blue: 0.18)
    static let green  = Color(red: 0.46, green: 0.85, blue: 0.32)
    static let yellow = Color(red: 1.0,  green: 0.80, blue: 0.25)
    static let red    = Color(red: 1.0,  green: 0.34, blue: 0.30)
}

private struct AnimalDot { var x: Double; var y: Double; var dir: Double }

// MARK: - Lotka–Volterra ecosystem

private struct EcosystemSim: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    // Fixed system parameters; the player controls α (sheep birth) and δ (fox birth).
    private let beta  = 0.02     // predation rate
    private let gamma = 0.5      // fox death rate
    private let simPerSecond = 3.2          // faster cycles → more visible waves
    private let sheepShownMax = 150
    private let foxShownMax    = 80

    // The winning combination (0.1-step knob values).
    private let solSheep = 0.5
    private let solFox   = 0.7

    // Sliders are normalized 0..1 "degree of rate" in 0.1 steps; they scale to params.
    private let alphaMax = 1.0
    private let deltaMax = 0.014
    private let startR = 80.0
    private let startF = 18.0
    @State private var sheepKnob = 0.4    // SHEEP BIRTH (default shifted right)
    @State private var foxKnob   = 0.6    // FOX BIRTH

    private var alpha: Double { alphaMax * sheepKnob }   // F* = α/β
    private var delta: Double { deltaMax * foxKnob }     // R* = γ/δ

    @State private var R = 80.0        // sheep
    @State private var F = 18.0        // foxes
    @State private var sheepDots: [AnimalDot] = []
    @State private var foxDots: [AnimalDot] = []
    @State private var history: [(r: Double, f: Double)] = []
    @State private var started = false
    @State private var completed = false
    @State private var failed = false
    @State private var correctTicks = 0

    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let fieldH = h * 0.72

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Field (top ~3/4) ──
                    ZStack {
                        Canvas { ctx, size in drawField(&ctx, size) }
                        fieldOverlays(w: w, fieldH: fieldH)
                    }
                    .frame(width: w, height: fieldH)
                    .clipped()

                    // ── Graph + controls (bottom ~1/4) ──
                    controls
                        .frame(width: w, height: h - fieldH)
                        .background(Color.black)
                }

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                Button(action: reset) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .position(x: w - 34, y: 54)

                // Extinction — a species died.
                if failed {
                    ZStack {
                        Color.red.opacity(0.22).ignoresSafeArea()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Eco.red)
                            .position(x: w / 2, y: h * 0.30)
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }

                CompletionOverlay(
                    title: "Ecosystem in Harmony",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .onAppear { if !started { reset(); started = true } }
            .onReceive(tick) { _ in step() }
        }
    }

    // MARK: - Field overlays (counts + health)

    private func fieldOverlays(w: CGFloat, fieldH: CGFloat) -> some View {
        let health = ecosystemHealth
        return ZStack {
            // counts chip
            VStack(alignment: .leading, spacing: 6) {
                countRow(Eco.sheep, "SHEEP", Int(R.rounded()))
                countRow(Eco.fox, "FOXES", Int(F.rounded()))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.55)))
            .position(x: 76, y: fieldH - 48)

            // health ring
            VStack(spacing: 3) {
                HealthRing(fraction: health)
                    .frame(width: 64, height: 64)
            }
            .position(x: w - 50, y: fieldH - 52)
        }
    }

    private func countRow(_ color: Color, _ name: String, _ value: Int) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(name).font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 10)
            Text("\(value)").font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(width: 110)
        .animation(.easeOut(duration: 0.2), value: value)
    }

    // MARK: - Controls (graph + sliders)

    private var controls: some View {
        VStack(spacing: 8) {
            PopulationGraph(history: history, rStar: gamma / delta, fStar: alpha / beta)
                .frame(maxWidth: .infinity)
                .frame(height: 86)
                .padding(.horizontal, 14)
                .padding(.top, 8)

            HStack(spacing: 16) {
                slider("SHEEP BIRTH", Eco.green, value: knob($sheepKnob))
                slider("FOX BIRTH", Eco.fox, value: knob($foxKnob))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    /// Binding that restarts the deterministic simulation whenever the value moves,
    /// so each (sheep, fox) combination yields exactly one repeatable wave.
    private func knob(_ value: Binding<Double>) -> Binding<Double> {
        Binding(get: { value.wrappedValue },
                set: { v in
                    if v != value.wrappedValue { value.wrappedValue = v; restart() }
                })
    }

    private func restart() {
        R = startR; F = startF
        sheepDots = []; foxDots = []
        history = []
        correctTicks = 0
        failed = false
    }

    private func slider(_ label: String, _ color: Color, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: 0...1, step: 0.1).tint(color)
        }
    }

    // MARK: - Health

    private var ecosystemHealth: Double {
        guard history.count > 30 else { return 0.7 }
        let window = history.suffix(220)
        let minR = window.map(\.r).min() ?? 0
        let minF = window.map(\.f).min() ?? 0
        // Healthy when neither trough nears extinction.
        let hR = min(1, minR / 18)
        let hF = min(1, minF / 10)
        return max(0, min(hR, hF))
    }

    // MARK: - Field rendering

    private func drawField(_ ctx: inout GraphicsContext, _ size: CGSize) {
        // grass backdrop with checker tiles
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [Color(red: 0.34, green: 0.52, blue: 0.22),
                                      Color(red: 0.22, green: 0.38, blue: 0.15)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let tile: CGFloat = 38
        var r = 0
        var y: CGFloat = 0
        while y < size.height {
            var c = 0; var x: CGFloat = 0
            while x < size.width {
                if (r + c) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: x, y: y, width: tile, height: tile)),
                             with: .color(.white.opacity(0.025)))
                }
                x += tile; c += 1
            }
            y += tile; r += 1
        }

        for s in sheepDots {
            let p = CGPoint(x: s.x * size.width, y: s.y * size.height)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 3, width: 8, height: 6)),
                     with: .color(Eco.sheep))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x + 2, y: p.y - 4.5, width: 3, height: 3)),
                     with: .color(Color(red: 0.3, green: 0.3, blue: 0.32)))
        }
        for fx in foxDots {
            let p = CGPoint(x: fx.x * size.width, y: fx.y * size.height)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5.5, y: p.y - 3.5, width: 11, height: 7)),
                     with: .color(Eco.fox))
            var tailP = Path()
            tailP.move(to: CGPoint(x: p.x - cos(fx.dir) * 5, y: p.y - sin(fx.dir) * 3.5))
            tailP.addLine(to: CGPoint(x: p.x - cos(fx.dir) * 10, y: p.y - sin(fx.dir) * 7))
            ctx.stroke(tailP, with: .color(.white.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }

    // MARK: - Simulation

    private func step() {
        // Advance the Lotka–Volterra ODE with RK4 for a stable, uniform orbit.
        let total = simPerSecond / 30.0
        let dt = 0.012
        var steps = Int(total / dt); if steps < 1 { steps = 1 }
        var r = R, f = F
        for _ in 0..<steps {
            rk4(&r, &f, dt)
        }
        R = max(0.001, min(r, 1e5))
        F = max(0.001, min(f, 1e5))

        // Only the exact solution is stable. Any error from (0.5, 0.7) injects energy
        // each frame, so the orbit grows until a species dies — closer = slower death.
        let error = abs(sheepKnob - solSheep) + abs(foxKnob - solFox)
        if error > 0.001 && !failed && !completed {
            let rStar = gamma / delta, fStar = alpha / beta
            let g = 1 + 1.3 * error / 30.0
            R = max(0.001, rStar + (R - rStar) * g)
            F = max(0.001, fStar + (F - fStar) * g)
        }

        matchAgents(&sheepDots, to: min(Int(R.rounded()), sheepShownMax), speed: 0.010)
        matchAgents(&foxDots, to: min(Int(F.rounded()), foxShownMax), speed: 0.014)

        history.append((R, F))
        if history.count > 260 { history.removeFirst(history.count - 260) }

        checkOutcome()
    }

    private func checkOutcome() {
        guard !completed else { return }
        // A species died → the level fails (cleared when the player adjusts a slider).
        if R < 2 || F < 1.5 {
            if !failed { withAnimation(.easeInOut(duration: 0.4)) { failed = true } }
            correctTicks = 0
            return
        }
        // The right combination — let a few stable cycles of the wave play out
        // (period ≈ 4 s) before declaring harmony.
        let correct = abs(sheepKnob - solSheep) < 0.001 && abs(foxKnob - solFox) < 0.001
        correctTicks = correct ? correctTicks + 1 : 0
        if correctTicks > 420 {                   // ~14 s ≈ 3+ stable cycles
            withAnimation(.easeInOut(duration: 0.6)) { completed = true }
        }
    }

    private func rk4(_ r: inout Double, _ f: inout Double, _ dt: Double) {
        func dR(_ r: Double, _ f: Double) -> Double { alpha * r - beta * r * f }
        func dF(_ r: Double, _ f: Double) -> Double { delta * r * f - gamma * f }
        let k1r = dR(r, f),                 k1f = dF(r, f)
        let k2r = dR(r + dt/2*k1r, f + dt/2*k1f), k2f = dF(r + dt/2*k1r, f + dt/2*k1f)
        let k3r = dR(r + dt/2*k2r, f + dt/2*k2f), k3f = dF(r + dt/2*k2r, f + dt/2*k2f)
        let k4r = dR(r + dt*k3r, f + dt*k3f), k4f = dF(r + dt*k3r, f + dt*k3f)
        r += dt/6 * (k1r + 2*k2r + 2*k3r + k4r)
        f += dt/6 * (k1f + 2*k2f + 2*k3f + k4f)
    }

    private func matchAgents(_ dots: inout [AnimalDot], to target: Int, speed: Double) {
        while dots.count < target {
            dots.append(AnimalDot(x: .random(in: 0.04...0.96),
                                  y: .random(in: 0.04...0.96),
                                  dir: .random(in: 0..<(2 * .pi))))
        }
        if dots.count > target { dots.removeLast(dots.count - target) }
        for i in dots.indices {
            dots[i].dir += Double.random(in: -0.5...0.5)
            dots[i].x = wrap(dots[i].x + cos(dots[i].dir) * speed)
            dots[i].y = wrap(dots[i].y + sin(dots[i].dir) * speed)
        }
    }

    private func wrap(_ v: Double) -> Double { v < 0 ? v + 1 : (v >= 1 ? v - 1 : v) }

    private func reset() {
        sheepKnob = 0.4
        foxKnob = 0.6
        completed = false
        restart()
    }
}

// MARK: - Population graph

private struct PopulationGraph: View {
    let history: [(r: Double, f: Double)]
    let rStar: Double   // sheep equilibrium γ/δ
    let fStar: Double   // fox equilibrium  α/β

    var body: some View {
        Canvas { ctx, size in
            guard history.count > 1 else { return }
            let w = size.width, h = size.height
            let dataMax = history.map { max($0.r, $0.f) }.max() ?? 1
            let maxV = max(dataMax, rStar, fStar, 10) * 1.05
            let n = history.count

            for gl in [0.0, 0.5, 1.0] {
                var p = Path(); p.move(to: CGPoint(x: 0, y: h * gl)); p.addLine(to: CGPoint(x: w, y: h * gl))
                ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 1)
            }

            // Equilibrium "balance level" lines — the wave should ride evenly on these.
            func eqLine(_ value: Double, _ color: Color) {
                let y = h * (1 - CGFloat(min(value, maxV) / maxV))
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                ctx.stroke(p, with: .color(color.opacity(0.45)),
                           style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            eqLine(rStar, Eco.green)
            eqLine(fStar, Eco.fox)

            func line(_ value: @escaping ((r: Double, f: Double)) -> Double, _ color: Color) {
                var p = Path()
                for (i, rec) in history.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(n - 1)
                    let y = h * (1 - CGFloat(value(rec) / maxV))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            }
            line({ $0.r }, Eco.sheep)
            line({ $0.f }, Eco.fox)
        }
    }
}

// MARK: - Health ring

private struct HealthRing: View {
    let fraction: Double

    private var color: Color {
        fraction > 0.55 ? Eco.green : (fraction > 0.3 ? Eco.yellow : Eco.red)
    }

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 6)
            Circle().trim(from: 0, to: CGFloat(max(0.02, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.7), radius: 5)
            Text("\(Int(fraction * 100))")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .animation(.easeOut(duration: 0.3), value: fraction)
    }
}
