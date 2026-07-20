import SwiftUI

// MARK: - Level 97 · Convex Hull (interactive · QuickHull)
//
// QuickHull, divide & conquer. The leftmost/rightmost points start as corners.
// The first triangle plays automatically as a demo; after that the player taps
// the point FARTHEST from the current dashed edge, which snaps a new triangle
// and adds a corner. Edges with no points beyond them lock into the hull.
// Repeat until the hull is closed.

struct MathItLevelNinetySevenView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        QuickHullView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, CH.accent)
    }
}

// MARK: - Palette

private enum CH {
    static let bg     = Color(red: 0.03, green: 0.04, blue: 0.07)
    static let accent = Color(red: 0.46, green: 0.92, blue: 0.50)
    static let point  = Color(red: 0.82, green: 0.88, blue: 1.0)
    static let dash   = Color(red: 0.42, green: 0.66, blue: 1.0)
    static let bad    = Color(red: 0.95, green: 0.40, blue: 0.42)
}

private enum HD {
    static let points: [CGPoint] = [
        CGPoint(x: 0.46, y: 0.07), CGPoint(x: 0.13, y: 0.22), CGPoint(x: 0.07, y: 0.46),
        CGPoint(x: 0.20, y: 0.80), CGPoint(x: 0.45, y: 0.82), CGPoint(x: 0.69, y: 0.62),
        CGPoint(x: 0.72, y: 0.34),
        CGPoint(x: 0.33, y: 0.30), CGPoint(x: 0.46, y: 0.26), CGPoint(x: 0.20, y: 0.37),
        CGPoint(x: 0.29, y: 0.45), CGPoint(x: 0.41, y: 0.46), CGPoint(x: 0.53, y: 0.40),
        CGPoint(x: 0.25, y: 0.55), CGPoint(x: 0.37, y: 0.58), CGPoint(x: 0.49, y: 0.55),
        CGPoint(x: 0.16, y: 0.56), CGPoint(x: 0.31, y: 0.66), CGPoint(x: 0.43, y: 0.68),
        CGPoint(x: 0.55, y: 0.50), CGPoint(x: 0.50, y: 0.63), CGPoint(x: 0.24, y: 0.67),
        CGPoint(x: 0.39, y: 0.38), CGPoint(x: 0.47, y: 0.35), CGPoint(x: 0.58, y: 0.47),
        CGPoint(x: 0.34, y: 0.51), CGPoint(x: 0.28, y: 0.40), CGPoint(x: 0.43, y: 0.59),
    ]
}

private struct Edge: Equatable { var a: Int; var b: Int }

// MARK: - View

private struct QuickHullView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private enum Phase { case pickEndpoints, play, done }

    @State private var pending: [Edge] = []
    @State private var locked: [Edge] = []
    @State private var active: Edge? = nil
    @State private var corners: Set<Int> = []
    @State private var tri: (a: Int, c: Int, b: Int)? = nil
    @State private var triStart = Date.timeIntervalSinceReferenceDate
    @State private var phase: Phase = .pickEndpoints
    @State private var badFlash = false
    @State private var lastLocked: Edge? = nil
    @State private var lockTime = Date.timeIntervalSinceReferenceDate
    // Guided intro state. Endpoints are computed (never default 0) so the two
    // correct dots flash from the very first frame.
    private var lr: Int { HD.points.indices.min { HD.points[$0].x < HD.points[$1].x }! }
    private var rr: Int { HD.points.indices.max { HD.points[$0].x < HD.points[$1].x }! }
    @State private var tappedEnds: Set<Int> = []
    private let animDur = 0.7

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack(alignment: .top) {
                CH.bg.ignoresSafeArea()
                if badFlash { CH.bad.opacity(0.14).ignoresSafeArea().transition(.opacity) }

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 60).padding(.bottom, 14)
                    field
                        .frame(maxWidth: .infinity)
                        .frame(height: h * 0.68)
                        .padding(.horizontal, 18)
                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                Button(action: setup) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .position(x: w - 34, y: 54)

                CompletionOverlay(
                    title: "Convex Hull",
                    isVisible: phase == .done,
                    onContinue: onContinue,
                    onReplay: setup,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .animation(.easeInOut(duration: 0.25), value: badFlash)
            .onAppear { if pending.isEmpty && locked.isEmpty { setup() } }
        }
    }

    private var header: some View {
        VStack(spacing: 7) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4).foregroundStyle(Color.mathGold.opacity(0.85))
            EmptyView()
                .font(.trajan(32))
                .tracking(5).foregroundStyle(Color.mathGold.opacity(0.95))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Field

    private var field: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    draw(&ctx, size, now: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { v in
                    if hypot(v.translation.width, v.translation.height) < 12 { tap(v.location, geo.size) }
                }
            )
        }
    }

    private func inset(_ s: CGSize) -> CGRect { CGRect(x: 26, y: 26, width: s.width - 52, height: s.height - 52) }
    private func S(_ i: Int, _ s: CGSize) -> CGPoint {
        let r = inset(s); let p = HD.points[i]
        return CGPoint(x: r.minX + p.x * r.width, y: r.minY + p.y * r.height)
    }

    // MARK: Geometry

    private func cross(_ a: Int, _ b: Int, _ p: Int) -> CGFloat {
        let A = HD.points[a], B = HD.points[b], P = HD.points[p]
        return (B.x - A.x) * (P.y - A.y) - (B.y - A.y) * (P.x - A.x)
    }
    private func outside(_ e: Edge) -> [Int] {
        HD.points.indices.filter { $0 != e.a && $0 != e.b && cross(e.a, e.b, $0) > 1e-4 }
    }
    private func farthest(_ e: Edge) -> Int? {
        let A = HD.points[e.a], B = HD.points[e.b]
        let len = max(1e-6, hypot(B.x - A.x, B.y - A.y))
        return outside(e).max { abs(cross(e.a, e.b, $0)) / len < abs(cross(e.a, e.b, $1)) / len }
    }

    // MARK: Driver

    private func setup() {
        corners = []
        locked = []
        active = nil
        tri = nil
        lastLocked = nil
        badFlash = false
        tappedEnds = []
        pending = []
        phase = .pickEndpoints      // the two endpoints flash; tap both
    }

    /// Pop the next edge: if no point lies beyond it, lock it into the hull
    /// (with its own beat); otherwise present it for a pick.
    private func processNext() {
        guard let e = pending.last else {
            active = nil
            withAnimation(.easeInOut(duration: 0.5)) { phase = .done }
            return
        }
        pending.removeLast()
        if outside(e).isEmpty {
            active = nil
            lastLocked = e
            lockTime = Date.timeIntervalSinceReferenceDate
            locked.append(e)                                 // seals smoothly in draw
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { processNext() }
        } else {
            active = e
        }
    }

    private func commit(_ e: Edge, _ c: Int) {
        active = nil
        corners.insert(c)
        tri = (e.a, c, e.b)
        triStart = Date.timeIntervalSinceReferenceDate
        pending.append(Edge(a: c, b: e.b))
        pending.append(Edge(a: e.a, b: c))
        DispatchQueue.main.asyncAfter(deadline: .now() + animDur) {
            tri = nil
            processNext()
        }
    }

    private func nearest(_ loc: CGPoint, _ size: CGSize) -> Int? {
        var best = -1; var bestD: CGFloat = 26
        for i in HD.points.indices {
            let d = hypot(loc.x - S(i, size).x, loc.y - S(i, size).y)
            if d < bestD { bestD = d; best = i }
        }
        return best >= 0 ? best : nil
    }

    private func wrong() {
        withAnimation { badFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { badFlash = false } }
    }

    private func tap(_ loc: CGPoint, _ size: CGSize) {
        guard tri == nil, let hit = nearest(loc, size) else { return }
        switch phase {
        case .pickEndpoints:
            guard hit == lr || hit == rr, !tappedEnds.contains(hit) else { return }
            tappedEnds.insert(hit)
            withAnimation(.easeOut(duration: 0.2)) { _ = corners.insert(hit) }
            if tappedEnds.count == 2 {
                // Both endpoints chosen → the dotted baseline appears; from here
                // the player finds the farthest point themselves (no hint).
                withAnimation(.easeInOut(duration: 0.3)) {
                    active = Edge(a: lr, b: rr)
                    pending = [Edge(a: rr, b: lr)]      // lower side, processed later
                    phase = .play
                }
            }
        case .play:
            guard let e = active else { return }
            if hit == farthest(e) { commit(e, hit) } else { wrong() }
        case .done:
            break
        }
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, now: Double) {
        ctx.stroke(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 18),
                   with: .color(CH.accent.opacity(0.18)), lineWidth: 1.5)
        for i in 0..<70 {
            let fx = abs((sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1))
            let fy = abs((sin(Double(i) * 78.2330) * 43758.5453).truncatingRemainder(dividingBy: 1))
            ctx.fill(Path(ellipseIn: CGRect(x: fx * size.width, y: fy * size.height, width: 1.4, height: 1.4)),
                     with: .color(.white.opacity(0.15)))
        }

        // Locked hull edges (solid green). The freshly-locked edge "seals" by
        // drawing across smoothly rather than popping in.
        for e in locked {
            let A = S(e.a, size), B = S(e.b, size)
            let prog: CGFloat = (e == lastLocked) ? CGFloat(min(1, max(0, (now - lockTime) / 0.45))) : 1
            let end = CGPoint(x: A.x + (B.x - A.x) * prog, y: A.y + (B.y - A.y) * prog)
            var p = Path(); p.move(to: A); p.addLine(to: end)
            ctx.stroke(p, with: .color(CH.accent.opacity(0.30)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            ctx.stroke(p, with: .color(CH.accent), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Pending (dim dashed) + active (bright marching dashes)
        let phaseOff = CGFloat(-now * 18).truncatingRemainder(dividingBy: 14)
        for e in pending where e != active {
            var p = Path(); p.move(to: S(e.a, size)); p.addLine(to: S(e.b, size))
            ctx.stroke(p, with: .color(CH.dash.opacity(0.3)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
        }
        if let e = active, tri == nil {
            var p = Path(); p.move(to: S(e.a, size)); p.addLine(to: S(e.b, size))
            ctx.stroke(p, with: .color(CH.dash), style: StrokeStyle(lineWidth: 2.5, dash: [8, 6], dashPhase: phaseOff))
        }

        // Triangle animation
        if let t = tri {
            let prog = min(1, (now - triStart) / animDur)
            let A = S(t.a, size), B = S(t.b, size), C = S(t.c, size)
            // baseline (fading)
            var base = Path(); base.move(to: A); base.addLine(to: B)
            ctx.stroke(base, with: .color(CH.dash.opacity(0.5 * (1 - prog))), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            // translucent fill growing
            var fill = Path(); fill.move(to: A)
            fill.addLine(to: CGPoint(x: A.x + (C.x - A.x) * prog, y: A.y + (C.y - A.y) * prog))
            fill.addLine(to: CGPoint(x: B.x + (C.x - B.x) * prog, y: B.y + (C.y - B.y) * prog))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(CH.accent.opacity(0.12)))
            // two new edges grow toward C as DASHED frontier (matches the active
            // edge style, so there's no flicker when they become baselines).
            for from in [A, B] {
                var e = Path(); e.move(to: from)
                e.addLine(to: CGPoint(x: from.x + (C.x - from.x) * prog, y: from.y + (C.y - from.y) * prog))
                ctx.stroke(e, with: .color(CH.dash), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [8, 6]))
            }
        }

        // The two intro endpoints flash green; during play, the correct farthest
        // point glows in its own colour instead.
        var flashing = Set<Int>()
        var hint: Int? = nil
        if phase == .pickEndpoints {
            flashing = Set([lr, rr]).subtracting(tappedEnds)
        } else if phase == .play, tri == nil, let e = active, let f = farthest(e) {
            hint = f
        }
        let pulse = 0.5 + 0.5 * sin(now * 4.5)

        // Points
        for i in HD.points.indices {
            let q = S(i, size)
            let corner = corners.contains(i)
            if flashing.contains(i) {
                let r = 14 + CGFloat(pulse) * 8
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)),
                         with: .color(CH.accent.opacity(0.20 + 0.30 * pulse)))
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - 6, y: q.y - 6, width: 12, height: 12)),
                         with: .color(CH.accent))
            } else if hint == i {
                // Same dot colour as normal, but glowing to hint it's the one to tap.
                let base = corner ? CH.accent : CH.point
                let r = 14 + CGFloat(pulse) * 8
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)),
                         with: .color(base.opacity(0.18 + 0.30 * pulse)))
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - 5, y: q.y - 5, width: 10, height: 10)),
                         with: .color(base))
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - 11, y: q.y - 11, width: 22, height: 22)),
                         with: .color((corner ? CH.accent : CH.point).opacity(corner ? 0.28 : 0.10)))
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - 5, y: q.y - 5, width: 10, height: 10)),
                         with: .color(corner ? CH.accent : CH.point))
            }
        }
    }
}

#Preview {
    MathItLevelNinetySevenView(onContinue: {}, onLevelSelect: {})
}
