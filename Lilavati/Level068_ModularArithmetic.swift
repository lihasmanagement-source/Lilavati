import SwiftUI
import Combine

// MARK: - Level 98 · Josephus (interactive)

struct MathItLevelNinetyEightView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        JosephusView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, JP.accent)
    }
}

// MARK: - Palette

private enum JP {
    static let bg     = Color(red: 0.03, green: 0.04, blue: 0.08)
    static let accent = Color(red: 0.40, green: 0.92, blue: 0.55)
    static let alive  = Color(red: 0.55, green: 0.78, blue: 1.0)
    static let dead   = Color(red: 0.38, green: 0.40, blue: 0.48)
    static let kill   = Color(red: 0.95, green: 0.40, blue: 0.40)
    static let pick   = Color(red: 0.96, green: 0.78, blue: 0.32)
    static let gold   = Color(red: 1.0,  green: 0.82, blue: 0.30)
    static let stone  = Color(red: 0.16, green: 0.16, blue: 0.21)
}

private enum Josephus {
    static let n = 40
    static let killOrder: [Int] = {
        var q = Array(1...n); var order: [Int] = []
        while q.count > 1 { let s = q.removeFirst(); q.append(s); order.append(q.removeFirst()) }
        return order
    }()
    static let survivor: Int = {
        var q = Array(1...n)
        while q.count > 1 { let s = q.removeFirst(); q.append(s); q.removeFirst() }
        return q[0]
    }()
    static func killIndex(_ s: Int) -> Int { killOrder.firstIndex(of: s) ?? (n - 1) }
}

private enum Phase { case demo, march, pick, running, result, victory }

private struct Geom { let c: CGPoint; let R: CGFloat; let icon: CGFloat; let wallY: CGFloat }

// MARK: - View

private struct JosephusView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let demoDur = 3.6
    private let marchDur = 1.7
    private let runDur = 6.0
    private let walkDur = 1.6, shootDur = 0.5, breakDur = 1.2

    @State private var phase: Phase = .demo
    @State private var phaseStart = Date.timeIntervalSinceReferenceDate
    @State private var runStart = Date.timeIntervalSinceReferenceDate
    @State private var victoryStart = Date.timeIntervalSinceReferenceDate
    @State private var guess: Int? = nil
    @State private var resultKilled: Int? = nil
    @State private var won = false
    @State private var victoryDone = false
    @State private var gen = 0
    @State private var clock = Date.timeIntervalSinceReferenceDate

    private let n = Josephus.n
    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            ZStack(alignment: .top) {
                JP.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 56).padding(.bottom, 10)
                    ringArea.frame(maxWidth: .infinity).frame(height: h * 0.66)
                    controls.padding(.top, 12)
                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)
                if phase == .result && !won { failOverlay }
                CompletionOverlay(title: "You Survived", isVisible: victoryDone,
                                  onContinue: onContinue, onReplay: setup, onLevelSelect: onLevelSelect)
                    .zIndex(500)
            }
            .onAppear { setup() }
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
            HStack(spacing: 8) {
                Image(systemName: "person.fill").font(.system(size: 15))
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                Text("2").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(JP.kill.opacity(0.9))
        }
        .padding(.horizontal, 24)
    }

    // MARK: Ring + interaction

    private var ringArea: some View {
        GeometryReader { geo in
            Canvas { ctx, size in draw(&ctx, size, now: clock) }
                .contentShape(Rectangle())
                .onReceive(tick) { _ in clock = Date.timeIntervalSinceReferenceDate }
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { v in
                        if hypot(v.translation.width, v.translation.height) < 12 { tap(v.location, geo.size) }
                    }
                )
        }
    }

    // MARK: Geometry helpers

    private func geom(_ size: CGSize) -> Geom {
        let c = CGPoint(x: size.width / 2, y: size.height * 0.40)
        let R = min(size.width * 0.42, size.height * 0.33)
        let spacing = 2 * .pi * R / CGFloat(n)
        return Geom(c: c, R: R, icon: min(spacing * 0.8, 28), wallY: size.height * 0.82)
    }
    private func ang(_ s: Int) -> Double { (-90.0 + Double(s - 1) * 360.0 / Double(n)) * .pi / 180 }
    private func ringPos(_ s: Int, _ g: Geom) -> CGPoint {
        let a = ang(s)
        return CGPoint(x: g.c.x + g.R * CGFloat(cos(a)), y: g.c.y + g.R * CGFloat(sin(a)))
    }
    private func wallPos(_ s: Int, _ g: Geom, _ w: CGFloat) -> CGPoint {
        let col = CGFloat((s - 1) % 20), row = CGFloat((s - 1) / 20)
        return CGPoint(x: w * 0.08 + col * (w * 0.84 / 19), y: g.wallY + 16 + row * 17)
    }
    private func lerpP(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
    private func walkTarget(_ g: Geom) -> CGPoint {
        let rp = ringPos(Josephus.survivor, g)
        let dx = rp.x - g.c.x, dy = rp.y - g.c.y
        let l = max(1, hypot(dx, dy))
        return CGPoint(x: g.c.x + dx / l * g.icon * 2.0, y: g.c.y + dy / l * g.icon * 2.0)
    }

    private func soldierPosition(_ s: Int, _ g: Geom, _ size: CGSize, now: Double, walkP: Double, dir17: CGPoint) -> CGPoint {
        switch phase {
        case .demo:
            return wallPos(s, g, size.width)
        case .march:
            let p = max(0, min(1, (now - phaseStart) / marchDur))
            let e = CGFloat(p * p * (3 - 2 * p))
            return lerpP(wallPos(s, g, size.width), ringPos(s, g), e)
        case .victory where s == Josephus.survivor:
            let e = CGFloat(walkP * walkP * (3 - 2 * walkP))
            return lerpP(ringPos(s, g), dir17, e)
        default:
            return ringPos(s, g)
        }
    }

    private func tap(_ loc: CGPoint, _ size: CGSize) {
        guard phase == .pick else { return }
        let g = geom(size)
        var best = -1
        var bestD: CGFloat = g.icon
        for s in 1...n {
            let p = ringPos(s, g)
            let d = hypot(loc.x - p.x, loc.y - p.y)
            if d < bestD { bestD = d; best = s }
        }
        if best >= 0 { withAnimation(.easeOut(duration: 0.15)) { guess = (guess == best) ? nil : best } }
    }

    // MARK: Per-phase computed state

    private func killedCount(_ now: Double) -> Int {
        switch phase {
        case .running: return min(n - 1, Int(max(0, (now - runStart) / runDur) * Double(n - 1)))
        case .result: return resultKilled ?? (n - 1)
        case .victory: return n - 1
        default: return 0
        }
    }

    /// Returns (barrelAngle, fireGlow, fireTarget).
    private func aim(_ now: Double, _ killed: Int) -> (Double, Double, Int?) {
        if phase == .demo {
            let p = max(0, min(1, (now - phaseStart) / demoDur))
            let barrel = -Double.pi / 2 + p * 2 * .pi
            var glow = 0.0
            var target: Int? = nil
            for e in stride(from: 2, through: n, by: 2) {
                let d = atan2(sin(barrel - ang(e)), cos(barrel - ang(e)))
                let close = exp(-(d * d) / (2 * 0.14 * 0.14))
                if close > glow { glow = close; target = e }
            }
            return (barrel, glow, target)
        }
        if phase == .running {
            let kf = max(0, (now - runStart) / runDur) * Double(n - 1)
            let frac = kf - Double(killed)
            let prev = killed > 0 ? Josephus.killOrder[killed - 1] : n
            let next = killed < n - 1 ? Josephus.killOrder[killed] : prev
            let a0: Double = killed > 0 ? ang(prev) : -Double.pi / 2
            let a1: Double = ang(next)
            let t: Double = frac * frac * (3 - 2 * frac)
            let barrel = a0 + atan2(sin(a1 - a0), cos(a1 - a0)) * t
            let glow: Double = killed > 0 ? max(0, 1 - frac * 2.4) : 0
            return (barrel, glow, killed > 0 ? prev : nil)
        }
        if phase == .result, !won, let gk = guess {
            return (ang(gk), 0.9, gk)
        }
        if phase == .victory {
            return (ang(Josephus.survivor), 0, nil)
        }
        return (-Double.pi / 2, 0, nil)
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, now: Double) {
        let g = geom(size)
        let pulse = CGFloat(0.5 + 0.5 * sin(now * 4))
        let vt = now - victoryStart
        let walkP = phase == .victory ? max(0, min(1, vt / walkDur)) : 0
        let shootP = phase == .victory ? max(0, min(1, (vt - walkDur) / shootDur)) : 0
        let breakP = phase == .victory ? max(0, min(1, (vt - walkDur - shootDur) / breakDur)) : 0
        let dir17 = walkTarget(g)

        let killed = killedCount(now)
        var dead = Set<Int>()
        for i in 0..<killed { dead.insert(Josephus.killOrder[i]) }
        let solved = killed >= n - 1
        let (barrelAngle, fireGlow, fireTarget) = aim(now, killed)

        drawRange(&ctx, g, now)
        drawTracer(&ctx, g, size, fireTarget: fireTarget, glow: fireGlow, now: now, walkP: walkP, dir17: dir17)
        drawSoldiers(&ctx, g, size, now: now, pulse: pulse, killed: killed, dead: dead, solved: solved, walkP: walkP, dir17: dir17)
        drawVictoryShot(&ctx, g, size, now: now, shootP: shootP, breakP: breakP, walkP: walkP, dir17: dir17)
        drawTurret(&ctx, g.c, base: g.icon * 1.15, angle: barrelAngle, fire: fireGlow, breakP: breakP)
        drawWall(&ctx, size, g)
    }

    private func drawRange(_ ctx: inout GraphicsContext, _ g: Geom, _ now: Double) {
        guard phase == .demo || phase == .march else { return }
        let fade: CGFloat = phase == .march ? CGFloat(max(0, 1 - (now - phaseStart) / marchDur)) : 1
        for s in 1...n {
            let p = ringPos(s, g)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)),
                     with: .color(JP.alive.opacity(0.25 * fade)))
        }
    }

    private func drawTracer(_ ctx: inout GraphicsContext, _ g: Geom, _ size: CGSize,
                            fireTarget: Int?, glow: Double, now: Double, walkP: Double, dir17: CGPoint) {
        guard let tg = fireTarget, glow > 0.02 else { return }
        let tp = phase == .demo ? ringPos(tg, g) : soldierPosition(tg, g, size, now: now, walkP: walkP, dir17: dir17)
        var tr = Path(); tr.move(to: g.c); tr.addLine(to: tp)
        ctx.stroke(tr, with: .color(JP.kill.opacity(glow * 0.8)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    private func drawSoldiers(_ ctx: inout GraphicsContext, _ g: Geom, _ size: CGSize,
                              now: Double, pulse: CGFloat, killed: Int, dead: Set<Int>, solved: Bool,
                              walkP: Double, dir17: CGPoint) {
        var justKilled = -1
        if phase == .running && killed > 0 { justKilled = Josephus.killOrder[killed - 1] }
        else if phase == .result && !won { justKilled = guess ?? -1 }

        for s in 1...n {
            let p = soldierPosition(s, g, size, now: now, walkP: walkP, dir17: dir17)
            let isDead = dead.contains(s)
            let isSurvivor = solved && s == Josephus.survivor
            let isStruck = s == justKilled
            let isGuess = guess == s
            drawOneSoldier(&ctx, s, at: p, g: g, pulse: pulse,
                           isDead: isDead, isSurvivor: isSurvivor, isStruck: isStruck, isGuess: isGuess)
        }
    }

    private func soldierColor(_ isDead: Bool, _ isSurvivor: Bool, _ isStruck: Bool, _ isGuess: Bool) -> Color {
        if isSurvivor { return JP.accent }
        if isStruck { return JP.kill }
        if isGuess && phase == .pick { return JP.pick }
        if isDead { return JP.dead }
        return JP.alive
    }

    private func drawOneSoldier(_ ctx: inout GraphicsContext, _ s: Int, at p: CGPoint, g: Geom, pulse: CGFloat,
                                isDead: Bool, isSurvivor: Bool, isStruck: Bool, isGuess: Bool) {
        let color = soldierColor(isDead, isSurvivor, isStruck, isGuess)

        if isSurvivor {
            let r: CGFloat = g.icon * 0.7 + pulse * 6
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                     with: .color(JP.accent.opacity(0.30)))
        } else if isGuess && phase == .pick {
            let r: CGFloat = g.icon * 0.65 + pulse * 4
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                     with: .color(JP.pick.opacity(0.30)))
        }

        let faded: Bool = isDead && !isSurvivor
        let iconText = Text(Image(systemName: "person.fill")).font(.system(size: g.icon))
            .foregroundColor(color.opacity(faded ? 0.5 : 1))
        ctx.draw(iconText, at: p)

        let armedPlay: Bool = isGuess && (phase == .pick || phase == .running)
        let armedVictory: Bool = s == Josephus.survivor && phase == .victory
        if armedPlay || armedVictory { drawGun(&ctx, at: p, icon: g.icon) }

        let showNumber: Bool = phase == .pick || phase == .running || phase == .result
        if showNumber { drawNumber(&ctx, s, at: p, g: g, isDead: isDead, isSurvivor: isSurvivor) }
    }

    private func drawNumber(_ ctx: inout GraphicsContext, _ s: Int, at p: CGPoint, g: Geom, isDead: Bool, isSurvivor: Bool) {
        let dx: CGFloat = p.x - g.c.x
        let dy: CGFloat = p.y - g.c.y
        let len: CGFloat = max(1, hypot(dx, dy))
        let off: CGFloat = g.icon * 0.85
        let np = CGPoint(x: p.x + dx / len * off, y: p.y + dy / len * off)
        let numColor: Color = isSurvivor ? JP.accent : (isDead ? JP.dead : .white.opacity(0.85))
        let numSize: CGFloat = max(8.5, g.icon * 0.40)
        let numText = Text("\(s)")
            .font(.system(size: numSize, weight: .semibold, design: .monospaced))
            .foregroundColor(numColor)
        ctx.draw(numText, at: np)
    }

    private func drawVictoryShot(_ ctx: inout GraphicsContext, _ g: Geom, _ size: CGSize,
                                 now: Double, shootP: Double, breakP: Double, walkP: Double, dir17: CGPoint) {
        guard phase == .victory, shootP > 0, breakP <= 0 else { return }
        let from = soldierPosition(Josephus.survivor, g, size, now: now, walkP: walkP, dir17: dir17)
        var tr = Path(); tr.move(to: from); tr.addLine(to: g.c)
        let glow = 1 - abs(shootP - 0.5) * 2
        ctx.stroke(tr, with: .color(JP.gold.opacity(0.9 * glow)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private func drawWall(_ ctx: inout GraphicsContext, _ size: CGSize, _ g: Geom) {
        guard phase == .demo || phase == .march else { return }
        ctx.fill(Path(CGRect(x: 0, y: g.wallY, width: size.width, height: size.height - g.wallY)), with: .color(JP.stone))
        let bw = size.width / 14
        for i in 0..<14 where i % 2 == 0 {
            ctx.fill(Path(CGRect(x: CGFloat(i) * bw, y: g.wallY - 9, width: bw, height: 10)), with: .color(JP.stone))
        }
        ctx.stroke(Path(CGRect(x: 0, y: g.wallY, width: size.width, height: 1)), with: .color(.white.opacity(0.18)), lineWidth: 1)
    }

    private func drawGun(_ ctx: inout GraphicsContext, at p: CGPoint, icon: CGFloat) {
        let gw = icon * 0.62, gh = icon * 0.20
        let rect = CGRect(x: p.x + icon * 0.22, y: p.y - gh / 2, width: gw, height: gh)
        let body = Path(roundedRect: rect, cornerRadius: gh * 0.4)
        ctx.fill(body, with: .color(JP.gold))
        ctx.stroke(body, with: .color(.white.opacity(0.6)), lineWidth: 0.8)
        ctx.fill(Path(ellipseIn: CGRect(x: rect.maxX - 2, y: rect.midY - 2, width: 4, height: 4)), with: .color(JP.gold.opacity(0.7)))
    }

    private func drawTurret(_ ctx: inout GraphicsContext, _ c: CGPoint, base: CGFloat, angle: Double, fire: Double, breakP: Double) {
        if breakP <= 0.001 { turretBody(&ctx, c, base: base, angle: angle, fire: fire); return }
        let gap = base * 0.9 * CGFloat(breakP)
        let fall = base * 1.4 * CGFloat(breakP)
        let tilt = 0.7 * breakP
        ctx.drawLayer { l in
            l.translateBy(x: -gap, y: fall)
            l.translateBy(x: c.x, y: c.y); l.rotate(by: .radians(-tilt)); l.translateBy(x: -c.x, y: -c.y)
            l.clip(to: Path(CGRect(x: c.x - base * 4, y: c.y - base * 4, width: base * 4, height: base * 8)))
            turretBody(&l, c, base: base, angle: angle, fire: 0)
        }
        ctx.drawLayer { l in
            l.translateBy(x: gap, y: fall)
            l.translateBy(x: c.x, y: c.y); l.rotate(by: .radians(tilt)); l.translateBy(x: -c.x, y: -c.y)
            l.clip(to: Path(CGRect(x: c.x, y: c.y - base * 4, width: base * 4, height: base * 8)))
            turretBody(&l, c, base: base, angle: angle, fire: 0)
        }
        let sr = base * (0.5 + CGFloat(breakP))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - sr, y: c.y - sr, width: sr * 2, height: sr * 2)),
                 with: .color(.gray.opacity(0.18 * (1 - breakP))))
    }

    private func turretBody(_ ctx: inout GraphicsContext, _ c: CGPoint, base: CGFloat, angle: Double, fire: Double) {
        let baseRect = CGRect(x: c.x - base, y: c.y - base, width: base * 2, height: base * 2)
        ctx.fill(Path(ellipseIn: baseRect), with: .color(Color(red: 0.14, green: 0.15, blue: 0.20)))
        ctx.stroke(Path(ellipseIn: baseRect), with: .color(.white.opacity(0.25)), lineWidth: 2)
        ctx.stroke(Path(ellipseIn: baseRect.insetBy(dx: base * 0.32, dy: base * 0.32)), with: .color(.white.opacity(0.15)), lineWidth: 1.5)

        let bl = base * 1.7, bw = base * 0.30
        let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
        let px = -dy, py = dx
        let muzzle = CGPoint(x: c.x + dx * bl, y: c.y + dy * bl)
        var barrel = Path()
        barrel.move(to: CGPoint(x: c.x + px * bw, y: c.y + py * bw))
        barrel.addLine(to: CGPoint(x: muzzle.x + px * bw, y: muzzle.y + py * bw))
        barrel.addLine(to: CGPoint(x: muzzle.x - px * bw, y: muzzle.y - py * bw))
        barrel.addLine(to: CGPoint(x: c.x - px * bw, y: c.y - py * bw))
        barrel.closeSubpath()
        ctx.fill(barrel, with: .color(Color(red: 0.30, green: 0.32, blue: 0.40)))
        ctx.stroke(barrel, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

        let hub = base * 0.5
        let hubRect = CGRect(x: c.x - hub, y: c.y - hub, width: hub * 2, height: hub * 2)
        ctx.fill(Path(ellipseIn: hubRect), with: .color(Color(red: 0.22, green: 0.24, blue: 0.32)))
        ctx.stroke(Path(ellipseIn: hubRect), with: .color(.white.opacity(0.3)), lineWidth: 1)

        if fire > 0.02 {
            let fr = base * (0.4 + 0.5 * CGFloat(fire))
            ctx.fill(Path(ellipseIn: CGRect(x: muzzle.x - fr, y: muzzle.y - fr, width: fr * 2, height: fr * 2)), with: .color(JP.kill.opacity(0.6 * fire)))
            ctx.fill(Path(ellipseIn: CGRect(x: muzzle.x - fr * 0.4, y: muzzle.y - fr * 0.4, width: fr * 0.8, height: fr * 0.8)), with: .color(.white.opacity(fire)))
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 14) {
            iconButton("arrow.counterclockwise", action: setup)
            if phase == .pick && guess != nil {
                Button(action: run) {
                    Image(systemName: "play.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 130, height: 48).background(JP.accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain).transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: guess)
        .animation(.easeInOut(duration: 0.2), value: phase)
    }
    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                .frame(width: 50, height: 48).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Flow

    private func setup() {
        gen += 1; let myGen = gen
        phase = .demo; phaseStart = Date.timeIntervalSinceReferenceDate
        guess = nil; won = false; victoryDone = false; resultKilled = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + demoDur) {
            guard gen == myGen, phase == .demo else { return }
            phase = .march; phaseStart = Date.timeIntervalSinceReferenceDate
            DispatchQueue.main.asyncAfter(deadline: .now() + marchDur) {
                guard gen == myGen, phase == .march else { return }
                phase = .pick
            }
        }
    }

    private func run() {
        guard let gpick = guess, phase == .pick else { return }
        let myGen = gen
        withAnimation(.easeInOut(duration: 0.2)) { phase = .running }
        runStart = Date.timeIntervalSinceReferenceDate
        if gpick == Josephus.survivor {
            let runDelay: Double = runDur + 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + runDelay) {
                guard gen == myGen, phase == .running else { return }
                won = true
                phase = .victory; victoryStart = Date.timeIntervalSinceReferenceDate
                let vicDelay: Double = walkDur + shootDur + breakDur + 0.4
                DispatchQueue.main.asyncAfter(deadline: .now() + vicDelay) {
                    guard gen == myGen, phase == .victory else { return }
                    withAnimation(.easeInOut(duration: 0.4)) { victoryDone = true }
                }
            }
        } else {
            let ki = Josephus.killIndex(gpick)
            let tDeath: Double = Double(ki + 1) / Double(n - 1) * runDur
            DispatchQueue.main.asyncAfter(deadline: .now() + tDeath) {
                guard gen == myGen, phase == .running else { return }
                won = false; resultKilled = ki + 1
                withAnimation(.easeInOut(duration: 0.3)) { phase = .result }
            }
        }
    }

    private var failOverlay: some View {
        ZStack {
            JP.kill.opacity(0.16).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "xmark.circle").font(.system(size: 46, weight: .light)).foregroundStyle(JP.kill)
                HStack(spacing: 14) {
                    overlayButton("Try Again", filled: true, action: setup)
                    overlayButton("Levels", filled: false, action: onLevelSelect)
                }
            }
        }
        .transition(.opacity).zIndex(400)
    }
    private func overlayButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 16, weight: .semibold, design: .monospaced)).tracking(1.2)
                .foregroundStyle(filled ? .black : JP.kill)
                .frame(width: 150, height: 50)
                .background(filled ? JP.kill : .clear, in: Capsule())
                .overlay(Capsule().stroke(JP.kill.opacity(filled ? 0 : 0.7), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MathItLevelNinetyEightView(onContinue: {}, onLevelSelect: {})
}
