import SwiftUI
import Combine

// MARK: - Level 84 · Derivatives through flocking (interactive, three stages)
//
// 40 mouse cursors fly as a boid flock (separation · alignment · cohesion) and
// follow your finger. Stage 1: lead them to the marked zone. Stage 2: guide
// them through the maze to the exit. Stage 3: survive 7s while a red predator
// cursor hunts the flock. If every cursor dies, the level resets to stage 1.

struct MathItLevelFiftyThreeFlockingView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        FlockView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, FL.accent)
    }
}

// MARK: - Palette

private enum FL {
    static let bg     = Color(red: 0.03, green: 0.04, blue: 0.09)
    static let bgLow  = Color(red: 0.06, green: 0.08, blue: 0.16)
    static let accent = Color(red: 0.52, green: 0.78, blue: 1.0)
    static let cursor = Color(red: 0.92, green: 0.95, blue: 1.0)
    static let zone   = Color(red: 0.40, green: 0.92, blue: 0.55)
    static let wall   = Color(red: 0.28, green: 0.30, blue: 0.42)
    static let pred   = Color(red: 0.96, green: 0.30, blue: 0.32)
}

private struct Boid { var x: Double; var y: Double; var vx: Double; var vy: Double; var alive = true }

private enum Stage { case zone, maze, chase, done }

// Serpentine maze — vertical walls with alternating top/bottom gaps.
private let kWalls: [CGRect] = [
    CGRect(x: 0.22, y: 0.0,  width: 0.04, height: 0.56),
    CGRect(x: 0.40, y: 0.44, width: 0.04, height: 0.56),
    CGRect(x: 0.58, y: 0.0,  width: 0.04, height: 0.56),
    CGRect(x: 0.76, y: 0.44, width: 0.04, height: 0.56),
]
private let kZone1 = CGPoint(x: 0.84, y: 0.22)
private let kExit = CGPoint(x: 0.90, y: 0.20)
private let kZoneR = 0.13

// MARK: - View

private struct FlockView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let count = 40

    @State private var boids: [Boid] = []
    @State private var pred = Boid(x: 0.1, y: 0.1, vx: 0, vy: 0)
    @State private var target: CGPoint? = nil
    @State private var phase: Stage = .zone
    @State private var hold = 0
    @State private var chaseSteps = 0
    @State private var flash = false

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let chaseLen = 7 * 60

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height

            ZStack(alignment: .top) {
                FL.bg.ignoresSafeArea()
                if flash { FL.pred.opacity(0.18).ignoresSafeArea().transition(.opacity) }

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 56).padding(.bottom, 8)
                    hud.padding(.bottom, 6)
                    flockArea.frame(maxWidth: .infinity).frame(height: h * 0.66).padding(.horizontal, 16)
                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                CompletionOverlay(title: "Flock Survived", isVisible: phase == .done,
                                  onContinue: onContinue, onReplay: { setupStage(.zone) }, onLevelSelect: onLevelSelect)
                    .zIndex(500)
            }
            .animation(.easeInOut(duration: 0.25), value: flash)
            .onAppear { if boids.isEmpty { setupStage(.zone) } }
            .onReceive(tick) { _ in step() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4).foregroundStyle(Color.mathGold.opacity(0.85))
            EmptyView()
                .font(.trajan(34))
                .tracking(7).foregroundStyle(Color.mathGold.opacity(0.95))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 24)
    }

    private var hud: some View {
        HStack(spacing: 14) {
            if phase == .chase {
                HStack(spacing: 12) {
                    HStack(spacing: 7) {
                        Image(systemName: "timer")
                            .font(.system(size: 16, weight: .bold))
                        Text("\(max(0, Int(ceil(Double(chaseLen - chaseSteps) / 60.0))))s")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(FL.accent, in: RoundedRectangle(cornerRadius: 7))
                    .shadow(color: FL.accent.opacity(0.38), radius: 8)

                    Label("\(aliveCount)", systemImage: "cursorarrow")
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(FL.cursor)
                }
            }
        }
    }
    private var stageIndex: Int { switch phase { case .zone: return 0; case .maze: return 1; default: return 2 } }
    private var aliveCount: Int { boids.filter { $0.alive }.count }

    // MARK: Field + drag

    private var flockArea: some View {
        GeometryReader { geo in
            Canvas { ctx, size in draw(&ctx, size) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in target = CGPoint(x: v.location.x / geo.size.width, y: v.location.y / geo.size.height) }
                        .onEnded { _ in target = nil }
                )
        }
    }

    // MARK: Setup

    private func setupStage(_ s: Stage) {
        phase = s; target = nil; hold = 0
        switch s {
        case .zone:
            boids = (0..<count).map { _ in spawn(0.12...0.32, 0.55...0.85) }
        case .maze:
            boids = (0..<count).map { _ in spawn(0.04...0.16, 0.30...0.70) }
        case .chase:
            chaseSteps = 0
            boids = (0..<count).map { _ in spawn(0.4...0.6, 0.4...0.6) }
            pred = Boid(x: 0.08, y: 0.08, vx: 0, vy: 0)
        case .done:
            break
        }
    }
    private func spawn(_ rx: ClosedRange<Double>, _ ry: ClosedRange<Double>) -> Boid {
        let a = Double.random(in: 0..<(2 * .pi))
        return Boid(x: .random(in: rx), y: .random(in: ry), vx: cos(a) * 0.004, vy: sin(a) * 0.004)
    }

    // MARK: Step

    private func step() {
        guard !boids.isEmpty, phase != .done else { return }
        var next = boids
        for i in boids.indices where boids[i].alive { stepBoid(i, &next) }
        boids = next
        if phase == .chase { stepPredator() }
        evaluate()
    }

    private func stepBoid(_ i: Int, _ next: inout [Boid]) {
        let b = boids[i]
        let perception = 0.11, sepR = 0.035
        var cx = 0.0, cy = 0.0, avx = 0.0, avy = 0.0, sx = 0.0, sy = 0.0, n = 0
        for j in boids.indices where j != i && boids[j].alive {
            let dx = boids[j].x - b.x, dy = boids[j].y - b.y
            let d2 = dx * dx + dy * dy
            if d2 < perception * perception {
                cx += boids[j].x; cy += boids[j].y; avx += boids[j].vx; avy += boids[j].vy; n += 1
                if d2 < sepR * sepR { let d = max(0.0001, d2.squareRoot()); sx -= dx / d; sy -= dy / d }
            }
        }
        var ax = 0.0, ay = 0.0
        if n > 0 {
            ax += (cx / Double(n) - b.x) * 0.0009 + (avx / Double(n) - b.vx) * 0.05 + sx * 0.0016
            ay += (cy / Double(n) - b.y) * 0.0009 + (avy / Double(n) - b.vy) * 0.05 + sy * 0.0016
        }
        if let t = target { ax += (Double(t.x) - b.x) * 0.0038; ay += (Double(t.y) - b.y) * 0.0038 }
        if phase == .maze { let wa = wallAvoid(b.x, b.y); ax += wa.0; ay += wa.1 }
        if phase == .chase {
            let dx = b.x - pred.x, dy = b.y - pred.y, d2 = dx * dx + dy * dy
            if d2 < 0.11 * 0.11 { let d = max(0.0001, d2.squareRoot()); ax += dx / d * 0.0015; ay += dy / d * 0.0015 }
        }
        let m = 0.05, e = 0.00028
        if b.x < m { ax += e }; if b.x > 1 - m { ax -= e }
        if b.y < m { ay += e }; if b.y > 1 - m { ay -= e }

        var vx = b.vx + ax, vy = b.vy + ay
        let sp = (vx * vx + vy * vy).squareRoot()
        let maxS = 0.0067, minS = 0.003
        if sp > maxS { vx = vx / sp * maxS; vy = vy / sp * maxS }
        else if sp < minS, sp > 0 { vx = vx / sp * minS; vy = vy / sp * minS }

        var nx = b.x + vx, ny = b.y + vy
        if phase == .maze {
            if blocked(nx, b.y) { nx = b.x; vx = -vx * 0.3 }
            if blocked(nx, ny) { ny = b.y; vy = -vy * 0.3 }
        }
        next[i].vx = vx; next[i].vy = vy; next[i].x = nx; next[i].y = ny
    }

    private func stepPredator() {
        // Seek the nearest living boid; faster than the flock and sharper-turning,
        // so the player must actively steer the flock clear to keep them alive.
        var tx = 0.5, ty = 0.5, bestD = Double.infinity
        for b in boids where b.alive {
            let dx = b.x - pred.x, dy = b.y - pred.y, d = dx * dx + dy * dy
            if d < bestD { bestD = d; tx = b.x; ty = b.y }
        }
        var vx = pred.vx + (tx - pred.x) * 0.012
        var vy = pred.vy + (ty - pred.y) * 0.012
        let sp = (vx * vx + vy * vy).squareRoot()
        let maxS = 0.0082          // outruns the flock (flock max 0.0067) → it can run cursors down
        if sp > maxS { vx = vx / sp * maxS; vy = vy / sp * maxS }
        pred.vx = vx; pred.vy = vy; pred.x += vx; pred.y += vy
        // On contact, the touched cursor is removed from the flock (wider strike radius).
        for i in boids.indices where boids[i].alive {
            let dx = boids[i].x - pred.x, dy = boids[i].y - pred.y
            if dx * dx + dy * dy < 0.042 * 0.042 { boids[i].alive = false }
        }
    }

    // MARK: Walls

    private func blocked(_ x: Double, _ y: Double) -> Bool {
        let pad = 0.012
        for r in kWalls {
            if x > Double(r.minX) - pad, x < Double(r.maxX) + pad, y > Double(r.minY) - pad, y < Double(r.maxY) + pad { return true }
        }
        return false
    }
    private func wallAvoid(_ x: Double, _ y: Double) -> (Double, Double) {
        var ax = 0.0, ay = 0.0
        for r in kWalls {
            let nx = min(max(x, Double(r.minX)), Double(r.maxX))
            let ny = min(max(y, Double(r.minY)), Double(r.maxY))
            let dx = x - nx, dy = y - ny, d2 = dx * dx + dy * dy
            if d2 < 0.05 * 0.05, d2 > 0 { let d = d2.squareRoot(); ax += dx / d * 0.00018 / d; ay += dy / d * 0.00018 / d }
        }
        return (ax, ay)
    }

    // MARK: Stage evaluation

    private func evaluate() {
        switch phase {
        case .zone:
            // Solved once a majority of the cursors are touching the green ring.
            let inZone = boids.filter { inside($0, kZone1) }.count
            hold = inZone > count / 2 ? hold + 1 : 0
            if hold > 12 { setupStage(.maze) }
        case .maze:
            // Same rule — a majority of cursors reaching the exit ring solves it.
            let atExit = boids.filter { inside($0, kExit) }.count
            hold = atExit > count / 2 ? hold + 1 : 0
            if hold > 12 { setupStage(.chase) }
        case .chase:
            chaseSteps += 1
            if aliveCount == 0 {
                withAnimation { flash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation { flash = false }; setupStage(.zone) }
            } else if chaseSteps >= chaseLen {
                withAnimation(.easeInOut(duration: 0.5)) { phase = .done }
            }
        case .done:
            break
        }
    }
    private func inside(_ b: Boid, _ c: CGPoint) -> Bool {
        let dx = b.x - Double(c.x), dy = b.y - Double(c.y)
        return dx * dx + dy * dy < kZoneR * kZoneR
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: [FL.bgLow, FL.bg]),
                                       center: CGPoint(x: w * 0.5, y: h * 0.45), startRadius: 1, endRadius: max(w, h) * 0.85))
        ctx.stroke(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16),
                   with: .color(FL.accent.opacity(0.14)), lineWidth: 1.5)
        func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: CGFloat(x) * w, y: CGFloat(y) * h) }

        if phase == .zone { drawZone(&ctx, P(Double(kZone1.x), Double(kZone1.y)), CGFloat(kZoneR) * w) }
        if phase == .maze {
            for r in kWalls {
                let rect = CGRect(x: r.minX * w, y: r.minY * h, width: r.width * w, height: r.height * h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(FL.wall))
                ctx.stroke(Path(roundedRect: rect, cornerRadius: 5), with: .color(.white.opacity(0.18)), lineWidth: 1)
            }
            drawZone(&ctx, P(Double(kExit.x), Double(kExit.y)), CGFloat(kZoneR) * w)
        }
        if let t = target {
            let p = P(Double(t.x), Double(t.y))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32)), with: .color(FL.accent.opacity(0.16)))
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)),
                       with: .color(FL.accent.opacity(0.6)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
        }

        for b in boids where b.alive { drawCursor(&ctx, P(b.x, b.y), atan2(b.vy, b.vx), FL.cursor, 1) }
        if phase == .chase {
            let pp = P(pred.x, pred.y)
            ctx.fill(Path(ellipseIn: CGRect(x: pp.x - 16, y: pp.y - 16, width: 32, height: 32)), with: .color(FL.pred.opacity(0.22)))
            drawCursor(&ctx, pp, atan2(pred.vy, pred.vx), FL.pred, 1.5)
        }
    }

    private func drawZone(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(FL.zone.opacity(0.10)))
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .color(FL.zone.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
        ctx.draw(Text(Image(systemName: "flag.fill")).font(.system(size: 18)).foregroundColor(FL.zone), at: c)
    }

    private func drawCursor(_ ctx: inout GraphicsContext, _ p: CGPoint, _ heading: Double, _ color: Color, _ scale: CGFloat) {
        ctx.drawLayer { layer in
            layer.translateBy(x: p.x, y: p.y)
            layer.rotate(by: .radians(heading + .pi / 2))
            layer.scaleBy(x: scale, y: scale)
            layer.fill(Self.cursorPath, with: .color(color))
            layer.stroke(Self.cursorPath, with: .color(.black.opacity(0.5)), lineWidth: 0.8)
        }
    }

    private static let cursorPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -8))
        p.addLine(to: CGPoint(x: 5.5, y: 5))
        p.addLine(to: CGPoint(x: 1.8, y: 4))
        p.addLine(to: CGPoint(x: 3.4, y: 9))
        p.addLine(to: CGPoint(x: 1.2, y: 10))
        p.addLine(to: CGPoint(x: -0.2, y: 5))
        p.addLine(to: CGPoint(x: -3.5, y: 5))
        p.closeSubpath()
        return p
    }()
}

#Preview {
    MathItLevelFiftyThreeFlockingView(onContinue: {}, onLevelSelect: {})
}
