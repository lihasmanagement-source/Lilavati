import SwiftUI
import Combine

struct MathItLevelEightySixView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        SheepHerdingGame(onContinue: onContinue, onLevelSelect: onLevelSelect)
    }
}

// MARK: - Model

private enum SheepKind: Equatable { case white, red, green, gold }

private struct Sheep: Identifiable {
    let id: Int
    var pos: CGPoint
    var vel: CGPoint = .zero      // points per tick
    var heading: Double = 0       // facing angle (radians)
    var kind: SheepKind = .white
    var speedMul: CGFloat = 1
    var wander: Double = 0        // drifting heading for restless (golden) sheep
    var settled: Bool = false     // resting inside its matching pen
}

private struct PenInfo: Identifiable {
    let id: Int
    let center: CGPoint
    let radius: CGFloat
    let kind: SheepKind
    let color: Color
}

// MARK: - Game

private struct SheepHerdingGame: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let greenC = Color(red: 0.36, green: 0.92, blue: 0.5)
    private let redC   = Color(red: 1.0,  green: 0.40, blue: 0.40)
    private let goldC  = Color(red: 1.0,  green: 0.80, blue: 0.28)

    // Tunable physics (per-tick units; 60 ticks/sec)
    private var dogRadius: CGFloat { stage == 3 ? 150 : 124 }
    private let sepRadius: CGFloat = 30
    private let maxSpeed:  CGFloat = 6

    @State private var stage = 1
    @State private var sheep: [Sheep] = []
    @State private var pens:  [PenInfo] = []
    @State private var dogPos    = CGPoint(x: 0, y: 0)
    @State private var fieldSize = CGSize.zero
    @State private var ready     = false
    @State private var dogActive = false
    @State private var transitioning = false
    @State private var completed = false

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                // ── Pens (goals) ──
                ForEach(pens) { pen in
                    Pen(radius: pen.radius,
                        color: pen.color,
                        progress: penProgress(pen),
                        glowing: completed || penProgress(pen) >= 0.999)
                        .frame(width: pen.radius * 2 + 24, height: pen.radius * 2 + 24)
                        .position(pen.center)
                }

                // ── Sheep ──
                ForEach(sheep) { s in
                    SheepIcon(wool: woolColor(s.kind))
                        .frame(width: 26, height: 20)
                        .rotationEffect(.radians(s.heading))
                        .position(s.pos)
                }

                // ── Sheepdog + pressure field ──
                if ready {
                    ZStack {
                        PressureRings()
                            .frame(width: dogRadius * 2, height: dogRadius * 2)
                            .opacity(dogActive ? 1 : 0.55)
                        SheepdogIcon()
                            .frame(width: 38, height: 28)
                    }
                    .position(dogPos)
                    .allowsHitTesting(false)
                }

                // ── Touch layer: drag the dog ──
                Color.white.opacity(0.001)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                dogActive = true
                                dogPos = v.location
                            }
                            .onEnded { _ in dogActive = false }
                    )

                // ── Stage pips (top-centre) ──
                HStack(spacing: 7) {
                    ForEach(1...3, id: \.self) { s in
                        Capsule()
                            .fill(s == stage ? greenC : greenC.opacity(0.22))
                            .frame(width: s == stage ? 22 : 8, height: 4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: stage)
                    }
                }
                .position(x: w / 2, y: 40)

                // ── Reset ──
                Button(action: { setupStage(1, size: proxy.size) }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.07), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .position(x: w - 38, y: h - 48)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Gradient Descent Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: { setupStage(1, size: proxy.size) },
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .onAppear {
                if !ready { setupStage(1, size: proxy.size) }
            }
            .onReceive(tick) { _ in step() }
        }
    }

    // MARK: - Derived

    private func woolColor(_ kind: SheepKind) -> Color {
        switch kind {
        case .white: return .white
        case .red:   return redC
        case .green: return greenC
        case .gold:  return goldC
        }
    }

    private func matchingPen(_ kind: SheepKind) -> PenInfo? {
        pens.first { $0.kind == kind }
    }

    private func penProgress(_ pen: PenInfo) -> CGFloat {
        let matching = sheep.filter { $0.kind == pen.kind }
        guard !matching.isEmpty else { return 0 }
        let settled = matching.filter { $0.settled }.count
        return CGFloat(settled) / CGFloat(matching.count)
    }

    // MARK: - Stage setup

    private func setupStage(_ st: Int, size: CGSize) {
        fieldSize     = size
        stage         = st
        completed     = false
        dogActive     = false
        transitioning = false
        let w = size.width, h = size.height
        dogPos = CGPoint(x: w * 0.5, y: h * 0.82)

        switch st {
        case 1:
            pens = [PenInfo(id: 0, center: CGPoint(x: w * 0.5, y: h * 0.18),
                            radius: 92, kind: .white, color: greenC)]
            sheep = makeFlock(kinds: Array(repeating: .white, count: 18), w: w, h: h)

        case 2:
            pens = [
                PenInfo(id: 0, center: CGPoint(x: w * 0.28, y: h * 0.18),
                        radius: 74, kind: .red,   color: redC),
                PenInfo(id: 1, center: CGPoint(x: w * 0.72, y: h * 0.18),
                        radius: 74, kind: .green, color: greenC),
            ]
            var kinds: [SheepKind] = []
            for i in 0..<16 { kinds.append(i % 2 == 0 ? .red : .green) }
            sheep = makeFlock(kinds: kinds, w: w, h: h)

        default: // Stage 3 — responsive golden sheep, compact pen
            pens = [PenInfo(id: 0, center: CGPoint(x: w * 0.5, y: h * 0.18),
                            radius: 64, kind: .gold, color: goldC)]
            sheep = makeFlock(kinds: Array(repeating: .gold, count: 3), w: w, h: h)
        }
        ready = true
    }

    private func makeFlock(kinds: [SheepKind], w: CGFloat, h: CGFloat) -> [Sheep] {
        let cx = w * 0.5, cy = h * 0.62
        var out: [Sheep] = []
        for (i, k) in kinds.enumerated() {
            let a = CGFloat(i) / CGFloat(kinds.count) * 2 * .pi * 1.7
            let r = CGFloat(46) + CGFloat((i * 53) % 120)
            let jitter = CGFloat((i * 29) % 40) - 20
            out.append(Sheep(
                id: i,
                pos: CGPoint(x: cx + cos(a) * r + jitter,
                             y: cy + sin(a) * r * 0.7 + jitter),
                kind: k,
                speedMul: k == .gold ? 0.85 : 1,
                wander: Double.random(in: 0 ..< (2 * .pi))
            ))
        }
        return out
    }

    // MARK: - Simulation step

    private func step() {
        guard ready, !completed, !transitioning, !sheep.isEmpty else { return }
        let w = fieldSize.width, h = fieldSize.height
        let margin: CGFloat = 22
        let topMargin: CGFloat = 70
        let sheepRadius: CGFloat = 12
        let settledSep: CGFloat = 24

        var next = sheep
        for i in next.indices {
            var s = next[i]
            var v = s.vel
            guard let pen = matchingPen(s.kind) else { next[i] = s; continue }
            let penInner = pen.radius - sheepRadius

            // Settle the moment it enters its OWN pen — latched so it can't leave.
            if !s.settled && dist(s.pos, pen.center) < penInner {
                s.settled = true
            }

            if s.settled {
                // Inside the pen: ignore the dog, just separate so sheep stand side
                // by side and shuffle aside to make room for new arrivals.
                for j in next.indices where j != i {
                    let off = s.pos - next[j].pos
                    let dd = hypot(off.x, off.y)
                    if dd < settledSep && dd > 0.001 {
                        v += (off / dd) * (settledSep - dd) / settledSep * 1.3
                    }
                }
                v *= 0.78
            } else {
                // Flee the dog's pressure field (stronger for faster sheep).
                let away = s.pos - dogPos
                let d = max(hypot(away.x, away.y), 0.001)
                if d < dogRadius {
                    let strength = (dogRadius - d) / dogRadius
                    let response = stage == 3 ? pow(strength, 1.25) * 7.2 : strength * strength * 5.4
                    v += (away / d) * response * s.speedMul
                }

                // Separation from all close neighbours.
                for j in next.indices where j != i {
                    let off = s.pos - next[j].pos
                    let dd = hypot(off.x, off.y)
                    if dd < sepRadius && dd > 0.001 {
                        let separationForce: CGFloat = stage == 3 ? 0.78 : 1.4
                        v += (off / dd) * (sepRadius - dd) / sepRadius * separationForce
                    }
                }

                // Stage 3 sheep still wander, but the dog's steering force now
                // dominates so they move as a manageable flock instead of scattering.
                if s.kind == .gold {
                    s.wander += Double.random(in: -0.10 ... 0.10)
                    v += CGPoint(x: cos(s.wander), y: sin(s.wander)) * 0.28
                    let toC = s.pos - pen.center
                    let pd = max(hypot(toC.x, toC.y), 0.001)
                    let avoidR = pen.radius * 1.55
                    if pd < avoidR {
                        v += (toC / pd) * (avoidR - pd) / avoidR * 0.42
                    }
                    v *= 0.86
                } else {
                    v *= 0.90
                }

                if s.pos.x < margin     { v.x += (margin - s.pos.x) * 0.06 }
                if s.pos.x > w - margin { v.x -= (s.pos.x - (w - margin)) * 0.06 }
                if s.pos.y < topMargin  { v.y += (topMargin - s.pos.y) * 0.06 }
                if s.pos.y > h - margin { v.y -= (s.pos.y - (h - margin)) * 0.06 }

                // A gentle minimum keeps the flock alive without making it flighty.
                if s.kind == .gold {
                    let cur = hypot(v.x, v.y)
                    let minRun = 0.75 * s.speedMul
                    if cur < minRun {
                        v += CGPoint(x: cos(s.wander), y: sin(s.wander)) * (minRun - cur)
                    }
                }
            }

            // Clamp speed (golden sheep are quicker).
            let sp = hypot(v.x, v.y)
            let movingCap: CGFloat = stage == 3 ? 4.4 : maxSpeed
            let cap = (s.settled ? maxSpeed * 0.5 : movingCap) * s.speedMul
            if sp > cap { v = v / sp * cap }

            s.vel = v
            s.pos = CGPoint(x: s.pos.x + v.x, y: s.pos.y + v.y)

            // Hard containment for settled sheep — jostled but never pushed out.
            if s.settled {
                let toC = s.pos - pen.center
                let dd = hypot(toC.x, toC.y)
                if dd > penInner && dd > 0.001 {
                    let dir = toC / dd
                    s.pos = pen.center + dir * penInner
                    let outward = s.vel.x * dir.x + s.vel.y * dir.y
                    if outward > 0 { s.vel = s.vel - dir * outward }
                }
            }

            if sp > 0.4 { s.heading = atan2(v.y, v.x) }
            next[i] = s
        }
        sheep = next

        if next.allSatisfy({ $0.settled }) { handleWin() }
    }

    private func handleWin() {
        transitioning = true
        if stage < 3 {
            // Brief beat so the filled pen registers, then advance — no text screen.
            let nextStage = stage + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                setupStage(nextStage, size: fieldSize)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.5)) { completed = true }
        }
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

private func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
private func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
private func * (a: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
private func / (a: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: a.x / s, y: a.y / s) }
private extension CGPoint {
    static func += (a: inout CGPoint, b: CGPoint) { a = a + b }
    static func *= (a: inout CGPoint, s: CGFloat) { a = a * s }
}

// MARK: - Pen (goal)

private struct Pen: View {
    let radius: CGFloat
    let color: Color
    let progress: CGFloat
    let glowing: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [color.opacity(glowing ? 0.55 : 0.26),
                             color.opacity(glowing ? 0.22 : 0.08), .clear],
                    center: .center, startRadius: 0, endRadius: radius))
            Circle()
                .stroke(color.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .padding(12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color.opacity(0.95),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(12)
                .shadow(color: color.opacity(glowing ? 0.9 : 0.5), radius: glowing ? 14 : 6)
                .animation(.easeOut(duration: 0.3), value: progress)
        }
    }
}

// MARK: - Pressure rings (sheepdog influence)

private struct PressureRings: View {
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 0.85, green: 0.30, blue: 0.12).opacity(0.32),
                                 Color(red: 0.55, green: 0.16, blue: 0.06).opacity(0.12),
                                 .clear],
                        center: .center, startRadius: 0, endRadius: s * 0.5))
                Circle()
                    .stroke(Color(red: 1, green: 0.5, blue: 0.3).opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
            }
        }
    }
}

// MARK: - Icons

private struct SheepIcon: View {
    var wool: Color = .white

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let c = wool   // wool colour identifies the sheep's target pen
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(c)
                        .frame(width: h * 0.62, height: h * 0.62)
                        .position(x: w * (0.28 + CGFloat(i) * 0.12),
                                  y: h * (i % 2 == 0 ? 0.46 : 0.58))
                }
                Capsule()
                    .fill(c)
                    .frame(width: w * 0.62, height: h * 0.55)
                    .position(x: w * 0.46, y: h * 0.56)
                Ellipse()
                    .fill(Color(red: 0.22, green: 0.24, blue: 0.28))
                    .frame(width: h * 0.34, height: h * 0.40)
                    .position(x: w * 0.84, y: h * 0.52)
            }
        }
    }
}

private struct SheepdogIcon: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let body = Color(red: 0.85, green: 0.55, blue: 0.22)
            ZStack {
                Ellipse()
                    .fill(body)
                    .frame(width: w * 0.74, height: h * 0.56)
                    .position(x: w * 0.46, y: h * 0.54)
                Circle()
                    .fill(body)
                    .frame(width: h * 0.46, height: h * 0.46)
                    .position(x: w * 0.80, y: h * 0.48)
                Ellipse()
                    .fill(Color(red: 0.62, green: 0.38, blue: 0.14))
                    .frame(width: h * 0.18, height: h * 0.30)
                    .position(x: w * 0.84, y: h * 0.34)
                Capsule()
                    .fill(body)
                    .frame(width: w * 0.22, height: h * 0.16)
                    .rotationEffect(.degrees(-25))
                    .position(x: w * 0.12, y: h * 0.42)
            }
            .shadow(color: Color(red: 1, green: 0.6, blue: 0.2).opacity(0.5), radius: 6)
        }
    }
}
