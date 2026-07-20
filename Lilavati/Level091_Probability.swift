import SwiftUI
import Combine

// MARK: - Level 90 · Probability (interactive)
//
// Tune two dials — Workers and Pheromone. More of either pulls the colony
// toward fewer, bigger piles (→ one cemetery); less makes more, smaller piles.
// Find the balance that produces EXACTLY 5 piles, one in each dotted ring.

struct MathItLevelOneHundredView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        AntCemeteryView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, AC.accent)
    }
}

// MARK: - Palette

private enum AC {
    static let bg     = Color(red: 0.03, green: 0.03, blue: 0.06)
    static let bgLow  = Color(red: 0.07, green: 0.04, blue: 0.10)
    static let accent = Color(red: 0.95, green: 0.20, blue: 0.50)
    static let blue   = Color(red: 0.30, green: 0.70, blue: 1.0)
    static let ant    = Color(red: 0.86, green: 0.90, blue: 1.0)
    static let nest   = Color(red: 0.98, green: 0.62, blue: 0.22)
    static let good   = Color(red: 0.40, green: 0.92, blue: 0.55)
    static let bad    = Color(red: 0.95, green: 0.36, blue: 0.34)
}

private struct Corpse { var x: Double; var y: Double; var carriedBy: Int? = nil }
private struct Ant { var x: Double; var y: Double; var dir: Double; var carrying: Int? = nil }

private let kCorpses = 55
private let kGoalPiles = 5
private let kPileR = 0.075
private let kNest = CGPoint(x: 0.5, y: 0.07)

// 5 goal centers (shown with dotted rings) + 2 "extra" spots for over-merging.
private let kCenters: [CGPoint] = [
    CGPoint(x: 0.24, y: 0.38), CGPoint(x: 0.74, y: 0.36), CGPoint(x: 0.22, y: 0.74),
    CGPoint(x: 0.52, y: 0.60), CGPoint(x: 0.78, y: 0.74),
    CGPoint(x: 0.50, y: 0.86), CGPoint(x: 0.40, y: 0.50),
]

// MARK: - View

private struct AntCemeteryView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var workers = 100.0
    @State private var pheromone = 0.85

    @State private var corpses: [Corpse] = []
    @State private var ants: [Ant] = []
    @State private var running = false
    @State private var steps = 0
    @State private var placed = 0
    @State private var completed = false

    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    /// Deterministic pile count from the two dials (1…7). More workers/pheromone → fewer.
    private var numPiles: Int {
        let workersN = (workers - 20) / 90
        let combined = 0.5 * (workersN + pheromone)
        return max(1, min(kCenters.count, Int((7.0 - combined * 6.0).rounded())))
    }
    private var activeCenters: [CGPoint] { Array(kCenters.prefix(numPiles)) }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack(alignment: .top) {
                AC.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 58).padding(.bottom, 8)
                    field.frame(maxWidth: .infinity).frame(height: h * 0.46).padding(.horizontal, 16)
                    metrics.padding(.horizontal, 22).padding(.top, 12)
                    controls.padding(.horizontal, 20).padding(.top, 16)
                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                CompletionOverlay(title: "Five Cemeteries", isVisible: completed,
                                  onContinue: onContinue, onReplay: reset, onLevelSelect: onLevelSelect)
                    .zIndex(500)
            }
            .onAppear { if corpses.isEmpty { scatter() } }
            .onReceive(tick) { _ in step() }
        }
    }

    private var header: some View {
        VStack(spacing: 7) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4).foregroundStyle(Color.mathGold.opacity(0.85))
        }
        .padding(.horizontal, 24)
    }

    private var metrics: some View {
        HStack(spacing: 20) {
            metric("circle.dotted", "\(numPiles)/\(kGoalPiles)", numPiles == kGoalPiles ? AC.good : AC.bad)
            metric("ant.fill", "\(placed)/\(kCorpses)", AC.blue)
            metric("clock", timeStr, .white.opacity(0.85))
        }
    }
    private func metric(_ icon: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            Text(value).font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(color).contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
    private var timeStr: String { let t = steps / 30; return String(format: "%02d:%02d", t / 60, t % 60) }

    private var controls: some View {
        VStack(spacing: 14) {
            paramSlider("ant.fill", $workers, 20...110, 5, "%.0f")
            paramSlider("waveform", $pheromone, 0...1, 0.05, "%.2f")
            HStack(spacing: 12) {
                Button(action: reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85)).frame(width: 64, height: 48)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button(action: toggleRun) {
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 48)
                        .background(AC.good, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
    private func paramSlider(_ icon: String, _ v: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double, _ fmt: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7)).frame(width: 30, alignment: .leading)
            Slider(value: v, in: range, step: step).tint(AC.accent)
            Text(String(format: fmt, v.wrappedValue))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white).frame(width: 42, alignment: .trailing)
        }
        // Any slider change restarts the whole animation and plays it through.
        .onChange(of: v.wrappedValue) { restartSim() }
    }

    // MARK: Simulation

    private func scatter() {
        steps = 0; placed = 0; completed = false
        corpses = (0..<kCorpses).map { _ in Corpse(x: .random(in: 0.08...0.92), y: .random(in: 0.22...0.92)) }
        rescatterAnts()
    }
    private func rescatterAnts() {
        ants = (0..<Int(workers)).map { _ in Ant(x: .random(in: 0.1...0.9), y: .random(in: 0.24...0.9), dir: .random(in: 0..<(2 * .pi))) }
    }
    /// Re-scatter everything and play through with the current dial values.
    private func restartSim() { running = false; scatter(); running = true }
    private func reset() { running = false; scatter() }
    private func toggleRun() { if completed { return }; running.toggle() }

    private func nearestCenter(_ x: Double, _ y: Double) -> CGPoint {
        var best = activeCenters[0]; var bestD = Double.infinity
        for c in activeCenters {
            let dx = Double(c.x) - x, dy = Double(c.y) - y
            let d = dx * dx + dy * dy
            if d < bestD { bestD = d; best = c }
        }
        return best
    }
    private func isPlaced(_ cp: Corpse) -> Bool {
        let c = nearestCenter(cp.x, cp.y)
        let dx = Double(c.x) - cp.x, dy = Double(c.y) - cp.y
        return dx * dx + dy * dy < kPileR * kPileR
    }

    private func step() {
        guard running, !ants.isEmpty else { return }
        steps += 1
        for i in ants.indices { stepAnt(i) }
        if steps % 15 == 0 { checkPlaced() }
    }

    private func stepAnt(_ i: Int) {
        ants[i].dir += Double.random(in: -0.4...0.4)
        if let held = ants[i].carrying {
            // Carry toward the nearest active cemetery; pheromone sharpens the homing.
            let c = nearestCenter(ants[i].x, ants[i].y)
            let target = atan2(Double(c.y) - ants[i].y, Double(c.x) - ants[i].x)
            let d = atan2(sin(target - ants[i].dir), cos(target - ants[i].dir))
            ants[i].dir += d * (0.35 + pheromone * 0.5)
            move(i)
            corpses[held].x = ants[i].x; corpses[held].y = ants[i].y
            let dx = Double(c.x) - ants[i].x, dy = Double(c.y) - ants[i].y
            if dx * dx + dy * dy < (kPileR * 0.8) * (kPileR * 0.8) {
                corpses[held].carriedBy = nil; ants[i].carrying = nil
            }
        } else {
            move(i)
            var best = -1; var bestD = 0.024 * 0.024
            for (j, cp) in corpses.enumerated() where cp.carriedBy == nil {
                let dx = cp.x - ants[i].x, dy = cp.y - ants[i].y
                let d = dx * dx + dy * dy
                if d < bestD, !isPlaced(cp) { bestD = d; best = j }   // ignore corpses already at a pile
            }
            if best >= 0, Double.random(in: 0...1) < 0.7 {
                ants[i].carrying = best; corpses[best].carriedBy = i
            }
        }
    }
    private func move(_ i: Int) {
        let speed = 0.006
        ants[i].x += cos(ants[i].dir) * speed
        ants[i].y += sin(ants[i].dir) * speed
        if ants[i].x < 0.04 { ants[i].x = 0.04; ants[i].dir = .pi - ants[i].dir }
        if ants[i].x > 0.96 { ants[i].x = 0.96; ants[i].dir = .pi - ants[i].dir }
        if ants[i].y < 0.16 { ants[i].y = 0.16; ants[i].dir = -ants[i].dir }
        if ants[i].y > 0.96 { ants[i].y = 0.96; ants[i].dir = -ants[i].dir }
    }

    private func checkPlaced() {
        var count = 0
        for cp in corpses where cp.carriedBy == nil && isPlaced(cp) { count += 1 }
        placed = count
        // Complete only once EVERY corpse is gathered and all 5 rings are filled.
        let allRingsFilled = (0..<kGoalPiles).allSatisfy { corpseCount(near: kCenters[$0]) >= 4 }
        if running, numPiles == kGoalPiles, placed >= kCorpses, allRingsFilled {
            running = false
            withAnimation(.easeInOut(duration: 0.5)) { completed = true }
        }
    }

    // MARK: Field

    private var field: some View {
        Canvas { ctx, size in draw(&ctx, size) }
    }
    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: [AC.bgLow, AC.bg]),
                                       center: CGPoint(x: w * 0.5, y: h * 0.45), startRadius: 1, endRadius: max(w, h) * 0.8))
        ctx.stroke(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14),
                   with: .color(AC.accent.opacity(0.14)), lineWidth: 1.5)
        func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: CGFloat(x) * w, y: CGFloat(y) * h) }
        let rr = kPileR * Double(min(w, h)) / Double(max(w, 1)) // pile ring radius in px (approx via width)
        let ringR = CGFloat(kPileR) * w

        // Goal rings (the 5 dotted cemeteries)
        for idx in 0..<kGoalPiles {
            let c = P(Double(kCenters[idx].x), Double(kCenters[idx].y))
            let filled = corpseCount(near: kCenters[idx]) >= 4
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - ringR, y: c.y - ringR, width: ringR * 2, height: ringR * 2)),
                       with: .color((filled ? AC.good : .white.opacity(0.30))),
                       style: StrokeStyle(lineWidth: 1.6, dash: [5, 5]))
        }
        // Extra (unwanted) piles when over-merged are at indices ≥5 → red rings
        if numPiles > kGoalPiles {
            for idx in kGoalPiles..<numPiles {
                let c = P(Double(kCenters[idx].x), Double(kCenters[idx].y))
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - ringR, y: c.y - ringR, width: ringR * 2, height: ringR * 2)),
                           with: .color(AC.bad.opacity(0.6)), style: StrokeStyle(lineWidth: 1.6, dash: [5, 5]))
            }
        }
        _ = rr

        // Nest
        let nest = P(Double(kNest.x), Double(kNest.y))
        ctx.fill(Path(ellipseIn: CGRect(x: nest.x - 20, y: nest.y - 20, width: 40, height: 40)),
                 with: .radialGradient(Gradient(colors: [AC.nest.opacity(0.5), .clear]), center: nest, startRadius: 1, endRadius: 24))
        ctx.draw(Text(Image(systemName: "ant.fill")).font(.system(size: 17)).foregroundColor(AC.nest), at: nest)

        for cp in corpses where cp.carriedBy == nil {
            let p = P(cp.x, cp.y)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(AC.accent.opacity(0.18)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(AC.accent))
        }
        for a in ants {
            let p = P(a.x, a.y)
            ctx.draw(Text(Image(systemName: "ant.fill")).font(.system(size: 10)).foregroundColor(AC.ant), at: p)
            if a.carrying != nil {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 8, width: 5, height: 5)), with: .color(AC.accent))
            }
        }
    }

    private func corpseCount(near c: CGPoint) -> Int {
        var n = 0
        for cp in corpses where cp.carriedBy == nil {
            let dx = Double(c.x) - cp.x, dy = Double(c.y) - cp.y
            if dx * dx + dy * dy < kPileR * kPileR { n += 1 }
        }
        return n
    }
}

#Preview {
    MathItLevelOneHundredView(onContinue: {}, onLevelSelect: {})
}
