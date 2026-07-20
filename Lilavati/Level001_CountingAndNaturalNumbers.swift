import SwiftUI
import Combine

// MARK: - Level 101 · Orbital (assemble a solar system of numbers)
//
// The screen begins in darkness with a single pulsing gold singularity. Tapping
// it triggers a "big bang": the sun (0), the number-planets and the asteroids
// scatter and drift haphazardly, and complex-number comets streak across.
//
// The player rebuilds the system. First the 0-sun is dragged into the gold
// dotted centre; it ignites (gold), the gold orbit lines appear, and the
// asteroids of irrationals auto-organise into the outer belt. Then every planet
// must be dragged onto its correct orbit — naturals, negatives and rationals —
// until the whole system is reassembled.

struct MathItLevelOneHundredOneView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        OrbitalView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, OB.accent)
    }
}

// MARK: - Palette

private enum OB {
    static let bg      = Color(red: 0.015, green: 0.015, blue: 0.04)
    static let bgLow   = Color(red: 0.05, green: 0.04, blue: 0.10)
    static let accent  = Color(red: 1.0, green: 0.78, blue: 0.32)   // gold
    static let core    = Color(red: 1.0, green: 0.97, blue: 0.86)
    static let amber   = Color(red: 0.58, green: 0.36, blue: 0.08)
    static let natural = Color(red: 0.52, green: 0.74, blue: 1.0)
    static let negative = Color(red: 0.42, green: 0.86, blue: 0.80)
    static let rational = Color(red: 0.88, green: 0.74, blue: 0.50)
    static let stone   = Color(red: 0.70, green: 0.66, blue: 0.60)
    static let comet   = Color(red: 0.62, green: 0.86, blue: 1.0)
}

private enum Phase { case dormant, assembling, celebrating, done }
private enum Category { case sun, natural, negative, rational }

private struct Piece {
    let id: Int
    let label: String
    let category: Category
    let slot: Int          // angular slot on its ring
    var placed = false
    var pos: CGPoint = .zero
    var vel: CGVector = .zero
}

private struct Asteroid {
    var angle0: CGFloat
    var rFrac: CGFloat
    var size: CGFloat
    var w: CGFloat
    var spin: CGFloat
    var symbol: String
    var shape: [CGFloat]
    var pos: CGPoint = .zero
    var vel: CGVector = .zero
}

private struct Star { var x: CGFloat; var y: CGFloat; var r: CGFloat; var phase: CGFloat }

private struct Comet {
    var theta: CGFloat; var offset: CGFloat; var period: CGFloat; var phase: CGFloat; var label: String
}

private struct PlanetBody {
    var p: CGPoint; var r: CGFloat; var color: Color; var label: String; var ringed: Bool
}
private enum SolarKind { case sun; case planet(PlanetBody); case rock(Asteroid, CGPoint, CGFloat) }
private struct SolarBody { var depth: CGFloat; var kind: SolarKind }

// MARK: - View

private struct OrbitalView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let rationalLabels = ["½", "0.25", "⅔", "1.5", "¾", "0.2", "⅗", "2.5"]
    private let irrationalSymbols = ["π", "e", "φ", "√2", "√3", "√5", "τ", "γ", "√7", "ζ", "√6", "∛2", "ln2", "√8"]

    // Distinct, Keplerian-feeling rates: the closer the ring, the faster it turns.
    private let rNat: CGFloat = 0.185, wNat: CGFloat = 1.00
    private let rNeg: CGFloat = 0.280, wNeg: CGFloat = 0.54
    private let rRat: CGFloat = 0.380, wRat: CGFloat = 0.30
    private let wBelt: CGFloat = 0.17
    private let tilt: CGFloat = 0.46

    @State private var field: CGSize = .zero
    @State private var t: CGFloat = 0
    @State private var phase: Phase = .dormant
    @State private var pieces: [Piece] = []
    @State private var asteroids: [Asteroid] = []
    @State private var stars: [Star] = []
    @State private var comets: [Comet] = []
    @State private var dragIndex: Int? = nil
    @State private var sunPlaced = false
    @State private var asteroidOrg: CGFloat = 0
    @State private var celebrateStart: CGFloat = 0

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let dt: CGFloat = 1.0 / 60.0

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height

            ZStack(alignment: .top) {
                OB.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.frame(height: 44).padding(.top, 56).padding(.bottom, 6)
                    hud.frame(height: 14).padding(.bottom, 6)
                    fieldArea.frame(maxWidth: .infinity).frame(height: h * 0.66).padding(.horizontal, 16)
                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                if let concept = ConceptLibrary.concept(for: 101) {
                    ConceptCompletionOverlay(
                        levelTitle: "Orbital",
                        concept: concept,
                        isVisible: phase == .done,
                        onContinue: onContinue,
                        onReplay: reset,
                        onLevelSelect: onLevelSelect
                    )
                    .zIndex(500)
                }
            }
            .onReceive(tick) { _ in step() }
        }
    }

    private var header: some View {
        Group {
            if phase != .dormant {
                EmptyView()
                    .font(.trajan(34))
                    .tracking(7).foregroundStyle(OB.accent.opacity(0.95))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 24)
    }

    private var hud: some View {
        Group {
            if phase == .dormant {
                Text("tap the singularity")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(2).foregroundStyle(OB.accent.opacity(0.35))
            } else if !pieces.isEmpty {
                Text(sunPlaced ? "\(placedCount) / \(pieces.count) placed"
                               : "place the 0 at the centre")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(1.5).foregroundStyle(OB.accent.opacity(0.7))
            }
        }
    }

    private var placedCount: Int { pieces.filter { $0.placed }.count }

    // MARK: Field + drag

    private var fieldArea: some View {
        GeometryReader { geo in
            Canvas { ctx, size in draw(&ctx, size) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard phase == .assembling else { return }
                            if dragIndex == nil { dragIndex = pickPiece(v.location) }
                            if let i = dragIndex { pieces[i].pos = v.location; pieces[i].vel = .zero }
                        }
                        .onEnded { v in
                            if phase == .dormant {
                                // Only the glowing singularity triggers the big bang.
                                if hypot(v.location.x - center.x, v.location.y - center.y) < sunR * 1.6 { bigBang() }
                                return
                            }
                            if let i = dragIndex { tryPlace(i) }
                            dragIndex = nil
                        }
                )
                .onAppear {
                    field = geo.size
                    if stars.isEmpty { stars = makeStars() }
                    if comets.isEmpty { comets = makeComets() }
                }
                .onChange(of: geo.size) { _, s in field = s }
        }
    }

    // MARK: Geometry (tilted plane)

    private var center: CGPoint { CGPoint(x: field.width / 2, y: field.height / 2) }
    private var minDim: CGFloat { min(field.width, field.height) }
    private var sunR: CGFloat { max(16, minDim * 0.080) }
    private var basePlanetR: CGFloat { max(8, minDim * 0.032) }

    private func angleOf(_ slot: Int, _ count: Int, _ w: CGFloat) -> CGFloat {
        -.pi / 2 + CGFloat(slot) * (2 * .pi / CGFloat(count)) + t * w
    }
    private func ringPos(_ a: CGFloat, _ rFrac: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(a) * rFrac * minDim,
                y: center.y + sin(a) * rFrac * minDim * tilt)
    }
    private func depth(_ a: CGFloat) -> CGFloat { 1 + 0.16 * sin(a) }

    private func ringParams(_ c: Category) -> (r: CGFloat, w: CGFloat, count: Int, color: Color, salt: CGFloat) {
        switch c {
        case .natural:  return (rNat, wNat, 9, OB.natural, 1)
        case .negative: return (rNeg, wNeg, 9, OB.negative, 3)
        case .rational: return (rRat, wRat, rationalLabels.count, OB.rational, 7)
        case .sun:      return (0, 0, 1, OB.accent, 0)
        }
    }

    private func sizeFactor(_ slot: Int, _ salt: CGFloat) -> CGFloat {
        let v = sin(CGFloat(slot) * 12.9898 + salt) * 43758.5453
        return 0.86 + 0.30 * (v - v.rounded(.down))
    }

    // Placed planet's live position on its ring.
    private func placedPos(_ p: Piece) -> (CGPoint, CGFloat, Color) {
        let rp = ringParams(p.category)
        let a = angleOf(p.slot, rp.count, rp.w)
        let pos = ringPos(a, rp.r)
        let r = basePlanetR * depth(a) * sizeFactor(p.slot, rp.salt)
        return (pos, r, rp.color)
    }

    // MARK: Lifecycle

    private func bigBang() {
        HapticPlayer.playCompletionTap()
        pieces = makePieces()
        asteroids = makeBelt()
        sunPlaced = false
        asteroidOrg = 0
        withAnimation(.easeOut(duration: 0.4)) { phase = .assembling }
    }

    private func reset() {
        phase = .dormant
        pieces = []
        asteroids = []
        sunPlaced = false
        asteroidOrg = 0
        dragIndex = nil
    }

    private func makePieces() -> [Piece] {
        var out: [Piece] = []
        var id = 0
        out.append(Piece(id: id, label: "0", category: .sun, slot: 0)); id += 1
        for n in 1...9 { out.append(Piece(id: id, label: "\(n)", category: .natural, slot: n - 1)); id += 1 }
        for n in 1...9 { out.append(Piece(id: id, label: "\u{2212}\(n)", category: .negative, slot: n - 1)); id += 1 }
        for (k, l) in rationalLabels.enumerated() { out.append(Piece(id: id, label: l, category: .rational, slot: k)); id += 1 }
        return out.map { var p = $0; p.pos = scatterPoint(); p.vel = scatterVel(minDim * driftSpeed(p.category)); return p }
    }

    private func scatterPoint() -> CGPoint {
        let m = basePlanetR * 2
        return CGPoint(x: .random(in: m...(max(m + 1, field.width - m))),
                       y: .random(in: m...(max(m + 1, field.height - m))))
    }
    private func scatterVel(_ speed: CGFloat) -> CGVector {
        let a = CGFloat.random(in: 0..<(2 * .pi))
        let s = speed * CGFloat.random(in: 0.8...1.2)
        return CGVector(dx: cos(a) * s, dy: sin(a) * s)
    }
    // Big-bang / drift speed appropriate to each object's ring — inner objects move fastest.
    private func driftSpeed(_ c: Category) -> CGFloat {
        switch c {
        case .natural:  return 0.17
        case .sun:      return 0.10
        case .negative: return 0.115
        case .rational: return 0.075
        }
    }

    private func makeBelt() -> [Asteroid] {
        (0..<irrationalSymbols.count).map { k in
            var shape: [CGFloat] = []
            for _ in 0..<Int.random(in: 6...8) { shape.append(CGFloat.random(in: 0.6...1.0)) }
            var a = Asteroid(angle0: .random(in: 0..<(2 * .pi)),
                             rFrac: .random(in: 0.445...0.495),
                             size: .random(in: 0.016...0.026),
                             w: wBelt * .random(in: 0.8...1.2),
                             spin: .random(in: -0.9...0.9),
                             symbol: irrationalSymbols[k],
                             shape: shape)
            a.pos = scatterPoint(); a.vel = scatterVel(minDim * 0.05)
            return a
        }
    }

    private func makeStars() -> [Star] {
        (0..<70).map { _ in
            Star(x: .random(in: 0...1), y: .random(in: 0...1),
                 r: .random(in: 0.3...1.2), phase: .random(in: 0..<(2 * .pi)))
        }
    }

    private func makeComets() -> [Comet] {
        let labels = ["2+3i", "1\u{2212}i", "3+2i", "\u{2212}1+2i", "i", "4\u{2212}i", "\u{2212}2\u{2212}i", "2+i"]
        return labels.shuffled().prefix(6).enumerated().map { idx, label in
            Comet(theta: .random(in: 0..<(2 * .pi)),
                  offset: .random(in: -0.45...0.45),
                  period: .random(in: 7...12),
                  phase: CGFloat(idx) / 6 + .random(in: 0...0.1),
                  label: label)
        }
    }

    // MARK: Simulation

    private func step() {
        t += dt

        // After everything is placed, admire the finished, brighter system for 5s.
        if phase == .celebrating {
            if t - celebrateStart >= 5 { withAnimation(.easeInOut(duration: 0.5)) { phase = .done } }
            return
        }
        guard phase == .assembling else { return }

        if sunPlaced, asteroidOrg < 1 { asteroidOrg = min(1, asteroidOrg + dt / 1.2) }

        for i in pieces.indices where !pieces[i].placed && i != dragIndex {
            var pos = pieces[i].pos, vel = pieces[i].vel
            drift(&pos, &vel, radius: basePlanetR)
            pieces[i].pos = pos; pieces[i].vel = vel
        }
        if !sunPlaced {
            for i in asteroids.indices {
                var pos = asteroids[i].pos, vel = asteroids[i].vel
                drift(&pos, &vel, radius: minDim * 0.03)
                asteroids[i].pos = pos; asteroids[i].vel = vel
            }
        }

        if pieces.allSatisfy({ $0.placed }) {
            HapticPlayer.playCompletionTap()
            celebrateStart = t
            withAnimation(.easeInOut(duration: 0.6)) { phase = .celebrating }
        }
    }

    private var finished: Bool { phase == .celebrating || phase == .done }

    private func drift(_ pos: inout CGPoint, _ vel: inout CGVector, radius: CGFloat) {
        pos.x += vel.dx * dt; pos.y += vel.dy * dt
        let m = radius * 1.4
        if pos.x < m { pos.x = m; vel.dx = abs(vel.dx) }
        if pos.x > field.width - m { pos.x = field.width - m; vel.dx = -abs(vel.dx) }
        if pos.y < m { pos.y = m; vel.dy = abs(vel.dy) }
        if pos.y > field.height - m { pos.y = field.height - m; vel.dy = -abs(vel.dy) }
    }

    // MARK: Interaction

    private func pickPiece(_ at: CGPoint) -> Int? {
        var best: Int? = nil, bestD = minDim * 0.10
        for i in pieces.indices where !pieces[i].placed {
            let d = hypot(at.x - pieces[i].pos.x, at.y - pieces[i].pos.y)
            if d < bestD { bestD = d; best = i }
        }
        return best
    }

    private func tryPlace(_ i: Int) {
        var p = pieces[i]
        if p.category == .sun {
            if hypot(p.pos.x - center.x, p.pos.y - center.y) < sunR * 1.4 {
                p.placed = true
                pieces[i] = p
                HapticPlayer.playCompletionTap()
                withAnimation(.easeInOut(duration: 0.5)) { sunPlaced = true }
                return
            }
        } else if sunPlaced {
            let rp = ringParams(p.category)
            // Angle of the drop, then the point on that ring at that angle.
            let a = atan2((p.pos.y - center.y) / tilt, p.pos.x - center.x)
            let onRing = ringPos(a, rp.r)
            if hypot(p.pos.x - onRing.x, p.pos.y - onRing.y) < minDim * 0.075 {
                p.placed = true
                pieces[i] = p
                HapticPlayer.playLightTap()
                return
            }
        }
        // Not placed → give it a fresh drift so it doesn't stall under the finger.
        p.vel = scatterVel(minDim * driftSpeed(p.category))
        pieces[i] = p
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let c = CGPoint(x: w / 2, y: h / 2)

        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: [OB.bgLow.opacity(phase == .dormant ? 0.4 : 1), OB.bg]),
                                       center: c, startRadius: 1, endRadius: max(w, h) * 0.9))

        if phase == .dormant {
            drawSeed(&ctx, c)
            return
        }

        // Stars.
        for s in stars {
            let tw = 0.5 + 0.5 * sin(t * 1.6 + s.phase)
            let p = CGPoint(x: s.x * w, y: s.y * h)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - s.r, y: p.y - s.r, width: s.r * 2, height: s.r * 2)),
                     with: .color(.white.opacity(0.12 + 0.4 * tw)))
        }
        ctx.stroke(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16),
                   with: .color(OB.accent.opacity(0.10)), lineWidth: 1.5)

        if sunPlaced {
            goldOrbit(&ctx, rNat, bright: finished)
            goldOrbit(&ctx, rNeg, bright: finished)
            goldOrbit(&ctx, rRat, bright: finished)
            drawSunGlow(&ctx, c, sunR)
        } else {
            drawCenterTarget(&ctx, c)
        }

        // Depth-sorted composite.
        var bodies: [SolarBody] = []
        if sunPlaced { bodies.append(SolarBody(depth: c.y, kind: .sun)) }

        for p in pieces {
            if p.category == .sun {
                if p.placed { continue }                       // becomes the big sun
                bodies.append(SolarBody(depth: p.pos.y, kind: .planet(
                    PlanetBody(p: p.pos, r: basePlanetR * 1.5, color: OB.accent, label: "0", ringed: false))))
            } else if p.placed {
                let (pos, r, color) = placedPos(p)
                bodies.append(SolarBody(depth: pos.y, kind: .planet(
                    PlanetBody(p: pos, r: r, color: color, label: p.label, ringed: p.category == .rational))))
            } else {
                bodies.append(SolarBody(depth: p.pos.y, kind: .planet(
                    PlanetBody(p: p.pos, r: basePlanetR, color: ringParams(p.category).color,
                               label: p.label, ringed: p.category == .rational))))
            }
        }

        for a in asteroids {
            let ang = a.angle0 + t * a.w
            let orbital = ringPos(ang, a.rFrac)
            let pos = sunPlaced ? lerpP(a.pos, orbital, easeOut(asteroidOrg)) : a.pos
            let s = a.size * minDim * (sunPlaced ? depth(ang) : 1)
            bodies.append(SolarBody(depth: pos.y, kind: .rock(a, pos, s)))
        }

        bodies.sort { $0.depth < $1.depth }
        for b in bodies {
            switch b.kind {
            case .sun: drawSunCore(&ctx, c, sunR)
            case .planet(let pl): drawPlanet(&ctx, pl)
            case .rock(let a, let pos, let s): drawAsteroid(&ctx, a, pos, s)
            }
        }

        for cm in comets { drawComet(&ctx, cm, w, h) }
    }

    private func easeOut(_ x: CGFloat) -> CGFloat { 1 - (1 - x) * (1 - x) }
    private func lerpP(_ a: CGPoint, _ b: CGPoint, _ f: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    // The dormant singularity.
    private func drawSeed(_ ctx: inout GraphicsContext, _ c: CGPoint) {
        let pulse = 1 + 0.22 * sin(t * 1.7)
        let gR = sunR * 2.6 * pulse
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - gR, y: c.y - gR, width: gR * 2, height: gR * 2)),
                 with: .radialGradient(Gradient(colors: [OB.accent.opacity(0.32), .clear]),
                                       center: c, startRadius: 1, endRadius: gR))
        let r = sunR * 0.5 * pulse
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(Gradient(colors: [OB.core, OB.accent, OB.amber.opacity(0.0)]),
                                       center: c, startRadius: 1, endRadius: r))
    }

    private func drawCenterTarget(_ ctx: inout GraphicsContext, _ c: CGPoint) {
        let rx = sunR * 1.3, ry = sunR * 1.3 * tilt
        let pulse = 0.5 + 0.5 * sin(t * 2.2)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)),
                   with: .color(OB.accent.opacity(0.4 + 0.4 * pulse)),
                   style: StrokeStyle(lineWidth: 1.6, dash: [4, 5]))
    }

    private func goldOrbit(_ ctx: inout GraphicsContext, _ rFrac: CGFloat, bright: Bool) {
        let rx = rFrac * minDim, ry = rFrac * minDim * tilt
        let rect = CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)
        if bright {
            let pulse = 0.75 + 0.25 * sin(t * 3)
            ctx.stroke(Path(ellipseIn: rect), with: .color(OB.accent.opacity(0.4 * pulse)), lineWidth: 6)
            ctx.stroke(Path(ellipseIn: rect), with: .color(OB.accent.opacity(0.22 * pulse)), lineWidth: 12)
            ctx.stroke(Path(ellipseIn: rect), with: .color(OB.core.opacity(0.95)), lineWidth: 1.6)
        } else {
            ctx.stroke(Path(ellipseIn: rect), with: .color(OB.accent.opacity(0.32)), lineWidth: 1)
        }
    }

    private func drawPlanet(_ ctx: inout GraphicsContext, _ pl: PlanetBody) {
        let p = pl.p, r = pl.r
        if pl.ringed { drawPlanetRing(&ctx, p, r, pl.color) }
        drawSphere(&ctx, p, r, pl.color)
        let fit = min(1.0, 1.9 / CGFloat(max(1, pl.label.count)))
        let f = Font.system(size: r * 0.92 * fit, weight: .bold, design: .rounded)
        ctx.draw(Text(pl.label).font(f).foregroundColor(.black.opacity(0.55)),
                 at: CGPoint(x: p.x + 0.6, y: p.y + 0.7))
        ctx.draw(Text(pl.label).font(f).foregroundColor(.white.opacity(0.96)), at: p)
    }

    private func drawSphere(_ ctx: inout GraphicsContext, _ p: CGPoint, _ r: CGFloat, _ color: Color) {
        let dx = center.x - p.x, dy = center.y - p.y
        let len = max(hypot(dx, dy), 1)
        let lightC = CGPoint(x: p.x + dx / len * r * 0.5, y: p.y + dy / len * r * 0.5)
        let glowR = r * 1.6
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - glowR, y: p.y - glowR, width: glowR * 2, height: glowR * 2)),
                 with: .radialGradient(Gradient(colors: [color.opacity(0.18), .clear]),
                                       center: p, startRadius: 1, endRadius: glowR))
        let disc = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        ctx.fill(disc, with: .radialGradient(Gradient(colors: [.white.opacity(0.9), color, color.opacity(0.6)]),
                                             center: lightC, startRadius: 1, endRadius: r * 1.5))
        ctx.fill(disc, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.55)]),
                                             center: lightC, startRadius: r * 0.2, endRadius: r * 1.95))
        ctx.stroke(disc, with: .color(.white.opacity(0.22)), lineWidth: 0.7)
    }

    private func drawPlanetRing(_ ctx: inout GraphicsContext, _ p: CGPoint, _ r: CGFloat, _ color: Color) {
        let rx = r * 1.9, ry = r * 0.62
        ctx.stroke(Path(ellipseIn: CGRect(x: p.x - rx, y: p.y - ry, width: rx * 2, height: ry * 2)),
                   with: .color(color.opacity(0.55)), lineWidth: max(1, r * 0.14))
    }

    private func drawAsteroid(_ ctx: inout GraphicsContext, _ a: Asteroid, _ p: CGPoint, _ s: CGFloat) {
        let rot = t * a.spin
        var path = Path()
        let n = a.shape.count
        for k in 0..<n {
            let va = rot + CGFloat(k) / CGFloat(n) * 2 * .pi
            let rr = s * a.shape[k]
            let pt = CGPoint(x: p.x + cos(va) * rr, y: p.y + sin(va) * rr)
            if k == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        ctx.fill(path, with: .linearGradient(Gradient(colors: [OB.stone.opacity(0.95), OB.stone.opacity(0.45)]),
                                             startPoint: CGPoint(x: p.x - s, y: p.y - s),
                                             endPoint: CGPoint(x: p.x + s, y: p.y + s)))
        ctx.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: 0.6)

        let symPos = CGPoint(x: p.x, y: p.y - s - 7)
        let sym = Text(a.symbol)
            .font(.system(size: max(8, s * 1.05), weight: .semibold, design: .serif))
            .foregroundColor(OB.accent)
        var glow = ctx
        glow.addFilter(.shadow(color: OB.accent.opacity(0.9), radius: max(2, s * 0.7)))
        glow.draw(sym, at: symPos)
        ctx.draw(sym, at: symPos)
    }

    private func drawComet(_ ctx: inout GraphicsContext, _ cm: Comet, _ w: CGFloat, _ h: CGFloat) {
        let c = CGPoint(x: w / 2, y: h / 2)
        let L = max(w, h)
        let d = CGVector(dx: cos(cm.theta), dy: sin(cm.theta))
        let perp = CGVector(dx: -sin(cm.theta), dy: cos(cm.theta))
        let prog = (t / cm.period + cm.phase).truncatingRemainder(dividingBy: 1)
        let s = (prog * 2 - 1) * L * 1.3
        let pos = CGPoint(x: c.x + d.dx * s + perp.dx * cm.offset * L,
                          y: c.y + d.dy * s + perp.dy * cm.offset * L)
        if pos.x < -L * 0.3 || pos.x > w + L * 0.3 || pos.y < -L * 0.3 || pos.y > h + L * 0.3 { return }

        let tailLen = minDim * 0.22
        let tailEnd = CGPoint(x: pos.x - d.dx * tailLen, y: pos.y - d.dy * tailLen)
        var tp = Path(); tp.move(to: pos); tp.addLine(to: tailEnd)
        ctx.stroke(tp, with: .linearGradient(Gradient(colors: [OB.comet.opacity(0.5), .clear]),
                                             startPoint: pos, endPoint: tailEnd),
                   style: StrokeStyle(lineWidth: minDim * 0.020, lineCap: .round))
        ctx.stroke(tp, with: .linearGradient(Gradient(colors: [.white.opacity(0.9), .clear]),
                                             startPoint: pos, endPoint: tailEnd),
                   style: StrokeStyle(lineWidth: minDim * 0.008, lineCap: .round))
        let hr = minDim * 0.014
        ctx.fill(Path(ellipseIn: CGRect(x: pos.x - hr * 2.4, y: pos.y - hr * 2.4, width: hr * 4.8, height: hr * 4.8)),
                 with: .radialGradient(Gradient(colors: [OB.comet.opacity(0.6), .clear]),
                                       center: pos, startRadius: 1, endRadius: hr * 2.4))
        ctx.fill(Path(ellipseIn: CGRect(x: pos.x - hr, y: pos.y - hr, width: hr * 2, height: hr * 2)),
                 with: .color(.white))
        let lp = CGPoint(x: pos.x, y: pos.y - hr - minDim * 0.032)
        let fit = min(1.0, 3.2 / CGFloat(max(1, cm.label.count)))
        let lbl = Text(cm.label)
            .font(.system(size: minDim * 0.038 * fit, weight: .semibold, design: .rounded))
            .foregroundColor(OB.comet)
        var lg = ctx
        lg.addFilter(.shadow(color: OB.comet.opacity(0.9), radius: minDim * 0.018))
        lg.draw(lbl, at: lp)
        ctx.draw(lbl, at: lp)
    }

    // MARK: The gold burning sun

    private func drawSunGlow(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        let pulse = 1 + 0.05 * sin(t * 2.1)
        let glowR = r * 3.6 * pulse
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - glowR, y: c.y - glowR, width: glowR * 2, height: glowR * 2)),
                 with: .radialGradient(Gradient(colors: [OB.accent.opacity(0.34), OB.amber.opacity(0.12), .clear]),
                                       center: c, startRadius: r * 0.6, endRadius: glowR))
    }

    private func drawSunCore(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        let spikes = 24
        for i in 0..<spikes {
            let base = CGFloat(i) / CGFloat(spikes) * 2 * .pi + t * 0.22
            let flick = 0.55 + 0.45 * sin(t * 3.0 + CGFloat(i) * 1.7) * cos(t * 1.3 + CGFloat(i))
            let len = r * (0.24 + 0.42 * abs(flick))
            let a0 = base - 0.05, a1 = base + 0.05
            var flare = Path()
            flare.move(to: CGPoint(x: c.x + cos(a0) * r * 0.94, y: c.y + sin(a0) * r * 0.94))
            flare.addLine(to: CGPoint(x: c.x + cos(base) * (r + len), y: c.y + sin(base) * (r + len)))
            flare.addLine(to: CGPoint(x: c.x + cos(a1) * r * 0.94, y: c.y + sin(a1) * r * 0.94))
            flare.closeSubpath()
            ctx.fill(flare, with: .linearGradient(Gradient(colors: [OB.accent.opacity(0.85), OB.amber.opacity(0.0)]),
                                                  startPoint: c, endPoint: CGPoint(x: c.x + cos(base) * (r + len), y: c.y + sin(base) * (r + len))))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(Gradient(colors: [OB.core, OB.accent, OB.amber]),
                                       center: CGPoint(x: c.x - r * 0.15, y: c.y - r * 0.15),
                                       startRadius: 1, endRadius: r * 1.15))
        for i in 0..<7 {
            let a = t * (0.4 + CGFloat(i) * 0.1) + CGFloat(i) * 2.0
            let rr = r * (0.18 + 0.13 * CGFloat(i % 3))
            let dd = r * (0.15 + 0.5 * abs(sin(t * 0.7 + CGFloat(i))))
            let p = CGPoint(x: c.x + cos(a) * dd, y: c.y + sin(a) * dd)
            let hot = i % 2 == 0
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                     with: .radialGradient(Gradient(colors: [(hot ? OB.core : OB.accent).opacity(0.5), .clear]),
                                           center: p, startRadius: 1, endRadius: rr))
        }
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .color(OB.core.opacity(0.55)), lineWidth: 1.2)

        // Glowing white 0 — the origin — at the heart of the sun.
        let zero = Text("0").font(.system(size: r * 1.0, weight: .bold, design: .rounded)).foregroundColor(.white)
        var zg = ctx
        zg.addFilter(.shadow(color: .white.opacity(0.95), radius: max(3, r * 0.55)))
        zg.draw(zero, at: c)
        ctx.draw(zero, at: c)
    }
}

#Preview {
    MathItLevelOneHundredOneView(onContinue: {}, onLevelSelect: {})
}
