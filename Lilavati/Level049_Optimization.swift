import SwiftUI
import Combine

struct MathItLevelEightySevenView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        AntColonyGame(onContinue: onContinue, onLevelSelect: onLevelSelect)
    }
}

// MARK: - Colours

private enum Colony {
    static let green = Color(red: 0.40, green: 0.95, blue: 0.50)
    static let red   = Color(red: 1.0,  green: 0.28, blue: 0.26)
    static let gold  = Color(red: 1.0,  green: 0.74, blue: 0.30)
    static let blue  = Color(red: 0.38, green: 0.72, blue: 1.0)
}

private enum NodeKind { case nest, food, hazard }
private enum AntKind  { case digger, carrier }

// MARK: - Static graph (hidden tree). Reds are leaves; endpoints are green.

private struct NodeDef {
    let id: Int
    let parent: Int        // -1 for nest
    let kind: NodeKind
    let unit: CGPoint      // position in 0..1 field space
}

// Every junction (nest + each green) spawns two paths: one green continuation
// and one red dead-end. The greens form a winding spine the player must follow;
// the deepest green (9) is the terminal endpoint.
private let colonyNodes: [NodeDef] = [
    NodeDef(id: 0,  parent: -1, kind: .nest,   unit: CGPoint(x: 0.50, y: 0.19)),
    NodeDef(id: 1,  parent: 0,  kind: .food,   unit: CGPoint(x: 0.30, y: 0.34)),
    NodeDef(id: 2,  parent: 0,  kind: .hazard, unit: CGPoint(x: 0.70, y: 0.32)),
    NodeDef(id: 3,  parent: 1,  kind: .food,   unit: CGPoint(x: 0.48, y: 0.46)),
    NodeDef(id: 4,  parent: 1,  kind: .hazard, unit: CGPoint(x: 0.15, y: 0.45)),
    NodeDef(id: 5,  parent: 3,  kind: .food,   unit: CGPoint(x: 0.68, y: 0.57)),
    NodeDef(id: 6,  parent: 3,  kind: .hazard, unit: CGPoint(x: 0.34, y: 0.61)),
    NodeDef(id: 7,  parent: 5,  kind: .food,   unit: CGPoint(x: 0.52, y: 0.71)),
    NodeDef(id: 8,  parent: 5,  kind: .hazard, unit: CGPoint(x: 0.85, y: 0.50)),
    NodeDef(id: 9,  parent: 7,  kind: .food,   unit: CGPoint(x: 0.36, y: 0.83)),
    NodeDef(id: 10, parent: 7,  kind: .hazard, unit: CGPoint(x: 0.72, y: 0.84)),
]

private struct FlightAnt: Identifiable {
    let id = UUID()
    let kind: AntKind
    let nodesPath: [Int]   // nest ... target
    var seg: Int           // current segment index
    var t: CGFloat         // 0..1 within segment
    var returning: Bool
    var target: Int { nodesPath.last ?? 0 }
}

// MARK: - Game

private struct AntColonyGame: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let maxDiggers = 6
    private var greenIds: [Int] { colonyNodes.filter { $0.kind == .food }.map(\.id) }
    private var children: [Int: [Int]] {
        Dictionary(grouping: colonyNodes.filter { $0.parent >= 0 }, by: { $0.parent })
            .mapValues { $0.map(\.id) }
    }

    @State private var discovered: Set<Int> = [0]
    @State private var harvested:  Set<Int> = []
    @State private var activeRoute: Set<Int> = []        // illuminated supply lines (node ids)

    @State private var diggersIdle  = 6
    @State private var diggersTotal = 6
    @State private var carriersIdle = 6
    @State private var carriersTotal = 6

    @State private var flights: [FlightAnt] = []          // diggers & carriers in flight
    @State private var openedSplits: Set<Int> = [0]       // nodes whose two paths have popped out

    @State private var fieldSize = CGSize.zero
    @State private var completed = false
    @State private var collapsing = false

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                SoilField().ignoresSafeArea()

                // Chambers behind discovered nodes
                ForEach(colonyNodes.filter { discovered.contains($0.id) }, id: \.id) { n in
                    Chamber(radius: n.kind == .nest ? 52 : 32)
                        .frame(width: n.kind == .nest ? 170 : 110,
                               height: n.kind == .nest ? 170 : 110)
                        .position(abs(n.unit, w, h))
                }

                // Revealed tunnels (parent → child)
                ForEach(colonyNodes.filter { $0.parent >= 0 && discovered.contains($0.id) }, id: \.id) { n in
                    let a = abs(nodeUnit(n.parent), w, h)
                    let b = abs(n.unit, w, h)
                    TunnelView(from: a, to: b,
                               lit: activeRoute.contains(n.id),
                               food: n.kind == .food)
                }

                // Unexplored directions — tapping a stub immediately sends a digger.
                ForEach(unexploredChildren(), id: \.self) { c in
                    let a = abs(nodeUnit(colonyNodes[c].parent), w, h)
                    let b = abs(nodeUnit(c), w, h)
                    let isDigging = flights.contains { $0.kind == .digger && $0.target == c }
                    Path { p in p.move(to: a); p.addLine(to: b) }
                        .stroke(.white.opacity(0.16),
                                style: StrokeStyle(lineWidth: 2, dash: [3, 6]))
                    StubGlyph(selected: isDigging)
                        .frame(width: 30, height: 30)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                        .onTapGesture { handleTap(c) }
                        .accessibilityLabel("Unexplored tunnel")
                        .accessibilityHint("Sends a digger ant")
                        .position(b)
                }

                // In-flight ants — gold diggers, blue carriers (with their load)
                ForEach(flights) { f in
                    ZStack {
                        AntGlyph(color: f.kind == .digger ? Colony.gold : Colony.blue)
                            .frame(width: 21, height: 21)
                        if f.kind == .carrier && f.returning && colonyNodes[f.target].kind == .food {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Colony.green)
                                .offset(y: -13)
                        }
                    }
                    .position(flightPos(f, w, h))
                }

                // Nodes
                ForEach(colonyNodes.filter { discovered.contains($0.id) }, id: \.id) { n in
                    nodeView(n, w: w, h: h)
                }

                // HUD (icons + counts, no instructional text)
                hud
                    .position(x: w / 2 + 20, y: 64)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                // Collapse flash
                if collapsing {
                    Colony.red.opacity(0.35).ignoresSafeArea()
                        .transition(.opacity)
                }

                CompletionOverlay(
                    title: "Level 87 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetColony,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .coordinateSpace(name: "scene")
            .onAppear { fieldSize = proxy.size }
            .onReceive(tick) { _ in step(w: w, h: h) }
        }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack(spacing: 10) {
            antStatus(
                icon: "ant.fill",
                tint: Colony.gold,
                value: "\(diggersIdle)/\(diggersTotal)",
                active: diggersIdle < diggersTotal
            )
            antStatus(
                icon: "ant",
                tint: Colony.blue,
                value: "\(carriersIdle)/\(carriersTotal)",
                active: carriersIdle < carriersTotal
            )
            // Food counter (display only)
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill").font(.system(size: 16)).foregroundStyle(Colony.green)
                Text("\(harvested.count)/\(greenIds.count)")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Capsule().fill(.black.opacity(0.5))
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1)))
        }
    }

    private func antStatus(icon: String, tint: Color, value: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(Capsule()
            .fill(active ? tint.opacity(0.18) : .black.opacity(0.5))
            .overlay(Capsule().stroke(active ? tint : .white.opacity(0.12),
                                      lineWidth: active ? 1.8 : 1)))
        .shadow(color: active ? tint.opacity(0.5) : .clear, radius: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
    }

    // MARK: - Node view

    @ViewBuilder
    private func nodeView(_ n: NodeDef, w: CGFloat, h: CGFloat) -> some View {
        Group {
            if n.kind == .nest {
                NestGlyph().frame(width: 64, height: 64)
            } else {
                NodeGlyph(color: n.kind == .food ? Colony.green : Colony.red,
                          pulsing: n.kind == .hazard,
                          harvested: harvested.contains(n.id))
                    .frame(width: 34, height: 34)
            }
        }
        .frame(width: n.kind == .nest ? 72 : 48, height: n.kind == .nest ? 72 : 48)
        .contentShape(Circle())
        .onTapGesture { handleTap(n.id) }
        .accessibilityLabel(n.kind == .nest ? "Ant nest" : n.kind == .food ? "Food chamber" : "Hazard chamber")
        .accessibilityHint(n.kind == .food && !harvested.contains(n.id) ? "Sends a carrier ant" : "")
        .position(abs(n.unit, w, h))
    }

    // MARK: - Deploy

    /// Stubs currently popped out: children of an opened split that aren't dug yet.
    private func unexploredChildren() -> [Int] {
        colonyNodes
            .filter { $0.parent >= 0 && openedSplits.contains($0.parent) && !discovered.contains($0.id) }
            .map(\.id)
    }

    /// A tap directly performs the action appropriate for that location.
    private func handleTap(_ id: Int) {
        guard !completed, !collapsing else { return }
        if id == 0 {
            if !openedSplits.contains(0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { _ = openedSplits.insert(0) }
            }
            return
        }

        if !discovered.contains(id) {
            deployDigger(to: id)
            return
        }

        guard colonyNodes[id].kind == .food, !harvested.contains(id) else {
            HapticPlayer.playLightTap()
            return
        }
        deployCarrier(to: id)
    }

    /// Send a digger to a tapped stub. It digs the tunnel and reveals the node:
    /// green is safe and it returns; red kills the digger.
    private func deployDigger(to target: Int) {
        guard !discovered.contains(target), diggersIdle > 0,
              !flights.contains(where: { $0.kind == .digger && $0.target == target }) else { return }
        HapticPlayer.playLightTap()
        diggersIdle -= 1
        flights.append(FlightAnt(kind: .digger, nodesPath: pathTo(target), seg: 0, t: 0, returning: false))
    }

    /// Send a carrier along a dug tunnel to a tapped green chamber.
    private func deployCarrier(to target: Int) {
        guard discovered.contains(target), colonyNodes[target].kind == .food,
              !harvested.contains(target), carriersIdle > 0,
              !flights.contains(where: { $0.kind == .carrier && $0.target == target }) else { return }
        HapticPlayer.playLightTap()
        carriersIdle -= 1
        flights.append(FlightAnt(kind: .carrier, nodesPath: pathTo(target), seg: 0, t: 0, returning: false))
    }

    // MARK: - Simulation step

    private func step(w: CGFloat, h: CGFloat) {
        guard !completed, !collapsing, !flights.isEmpty else { return }
        var next: [FlightAnt] = []
        for var f in flights {
            let lastSeg = f.nodesPath.count - 2
            let rate: CGFloat = f.kind == .digger ? 0.045 : 0.038
            if !f.returning {
                f.t += rate
                if f.t >= 1 {
                    f.t = 1
                    if f.seg >= lastSeg {
                        if !arrive(f) { continue }   // ant died on red
                        f.returning = true
                    } else { f.seg += 1; f.t = 0 }
                }
            } else {
                f.t -= rate
                if f.t <= 0 {
                    f.t = 0
                    if f.seg <= 0 { homeReturn(f); continue }
                    else { f.seg -= 1; f.t = 1 }
                }
            }
            next.append(f)
        }
        flights = next
    }

    /// Ant arrival at its target. Returns false if it should be removed (died on red).
    private func arrive(_ f: FlightAnt) -> Bool {
        let node = colonyNodes[f.target]
        if f.kind == .digger {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                _ = discovered.insert(node.id)
            }
            if node.kind == .hazard {
                diggersTotal -= 1
                checkFail()
                return false
            }
            return true
        } else {
            if node.kind == .hazard {
                carriersTotal -= 1
                checkFail()
                return false
            }
            withAnimation(.easeInOut(duration: 0.4)) { markRouteActive(node.id) }  // light supply line
            return true
        }
    }

    /// An ant made it home.
    private func homeReturn(_ f: FlightAnt) {
        if f.kind == .digger {
            diggersIdle = min(diggersTotal, diggersIdle + 1)
        } else {
            carriersIdle = min(carriersTotal, carriersIdle + 1)
            let g = f.target
            guard colonyNodes[g].kind == .food, !harvested.contains(g) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                harvested.insert(g)
                openedSplits.insert(g)          // the next split branches off this green
            }
            if harvested.count == greenIds.count {
                withAnimation(.easeInOut(duration: 0.5)) {
                    activeRoute = Set(greenIds)
                    completed = true
                }
            }
        }
    }

    /// Fail when a whole ant type is wiped out before the food is collected.
    private func checkFail() {
        if (diggersTotal <= 0 || carriersTotal <= 0) && harvested.count < greenIds.count {
            triggerCollapse()
        }
    }

    /// Illuminate every edge along the path to `id`.
    private func markRouteActive(_ id: Int) {
        var cur = id
        while cur > 0 {
            activeRoute.insert(cur)
            cur = colonyNodes[cur].parent
        }
    }

    private func triggerCollapse() {
        withAnimation(.easeInOut(duration: 0.3)) { collapsing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { resetColony() }
    }

    private func resetColony() {
        flights = []
        discovered = [0]
        harvested = []
        activeRoute = []
        openedSplits = [0]
        diggersIdle = maxDiggers
        diggersTotal = maxDiggers
        carriersIdle = 6
        carriersTotal = 6
        completed = false
        withAnimation(.easeInOut(duration: 0.3)) { collapsing = false }
    }

    // MARK: - Geometry helpers

    private func nodeUnit(_ id: Int) -> CGPoint { colonyNodes[id].unit }
    private func abs(_ u: CGPoint, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        CGPoint(x: u.x * w, y: u.y * h)
    }

    private func pathTo(_ id: Int) -> [Int] {
        var chain: [Int] = []
        var cur = id
        while cur >= 0 { chain.append(cur); cur = colonyNodes[cur].parent }
        return chain.reversed()
    }

    private func flightPos(_ f: FlightAnt, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        let a = abs(nodeUnit(f.nodesPath[f.seg]), w, h)
        let b = abs(nodeUnit(f.nodesPath[f.seg + 1]), w, h)
        return bezier(a, b, f.t)
    }

    private func bezier(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let c1 = CGPoint(x: a.x + (b.x - a.x) * 0.15, y: (a.y + b.y) / 2)
        let c2 = CGPoint(x: b.x - (b.x - a.x) * 0.15, y: (a.y + b.y) / 2)
        let mt = 1 - t
        let x = mt*mt*mt*a.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*b.x
        let y = mt*mt*mt*a.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*b.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Procedural soil

private struct SoilField: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let base = Path(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.fill(base, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.20, green: 0.12, blue: 0.07),
                    Color(red: 0.10, green: 0.06, blue: 0.035),
                    Color(red: 0.04, green: 0.025, blue: 0.015),
                    .black
                ]),
                startPoint: CGPoint(x: w / 2, y: 0),
                endPoint: CGPoint(x: w / 2, y: h)))

            var rng = SeededRNG(seed: 8723)
            let count = Int(w * h / 900)
            for _ in 0..<count {
                let x = CGFloat(rng.next()) * w
                let y = CGFloat(rng.next()) * h
                let depth = y / h
                let r = 2 + CGFloat(rng.next()) * 11
                let tone = CGFloat(rng.next())
                let light = tone > 0.86 && depth < 0.6
                let br = (light ? 0.34 : 0.16) * (1 - depth * 0.6) * (0.6 + tone * 0.6)
                let col = Color(red: br * 1.5, green: br * 0.95, blue: br * 0.55)
                let rect = CGRect(x: x - r, y: y - r * 0.8, width: r * 2, height: r * 1.6)
                ctx.fill(Ellipse().path(in: rect), with: .color(col.opacity(0.55)))
                if light {
                    let s = CGRect(x: x - r, y: y - r * 0.4, width: r * 2, height: r * 1.2)
                    ctx.fill(Ellipse().path(in: s), with: .color(.black.opacity(0.22)))
                }
            }

            ctx.fill(base, with: .radialGradient(
                Gradient(colors: [.clear, .black.opacity(0.55)]),
                center: CGPoint(x: w / 2, y: h * 0.42),
                startRadius: min(w, h) * 0.30, endRadius: max(w, h) * 0.75))
        }
    }
}

// MARK: - Carved chamber

private struct Chamber: View {
    let radius: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 0.05, green: 0.03, blue: 0.02),
                             Color(red: 0.12, green: 0.07, blue: 0.04).opacity(0.5),
                             .clear],
                    center: .center, startRadius: 0, endRadius: radius * 1.6))
            Circle()
                .stroke(Colony.gold.opacity(0.22), lineWidth: 3)
                .frame(width: radius * 1.6, height: radius * 1.6)
                .blur(radius: 5)
        }
    }
}

// MARK: - Tunnel

private struct TunnelView: View {
    let from: CGPoint
    let to: CGPoint
    let lit: Bool
    let food: Bool

    private var path: Path {
        Path { p in
            p.move(to: from)
            let c1 = CGPoint(x: from.x + (to.x - from.x) * 0.15, y: (from.y + to.y) / 2)
            let c2 = CGPoint(x: to.x - (to.x - from.x) * 0.15,   y: (from.y + to.y) / 2)
            p.addCurve(to: to, control1: c1, control2: c2)
        }
    }

    var body: some View {
        ZStack {
            path.stroke(Colony.gold.opacity(lit ? 0.55 : 0.22),
                        style: StrokeStyle(lineWidth: lit ? 16 : 12, lineCap: .round))
                .blur(radius: 6)
            path.stroke(Color(red: 0.06, green: 0.035, blue: 0.02),
                        style: StrokeStyle(lineWidth: lit ? 9 : 7, lineCap: .round))
            path.stroke(.black.opacity(0.4),
                        style: StrokeStyle(lineWidth: lit ? 4 : 3, lineCap: .round))
            path.stroke((food ? (lit ? Colony.gold : Colony.blue) : Colony.gold).opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [5, 6]))
        }
    }
}

// MARK: - Glyphs

private struct NestGlyph: View {
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(RadialGradient(
                    colors: [Colony.gold.opacity(0.55), Colony.gold.opacity(0.12), .clear],
                    center: .center, startRadius: 0, endRadius: s * 0.62))
                Image(systemName: "triangle.fill")
                    .font(.system(size: s * 0.40))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 1, green: 0.88, blue: 0.55), Colony.gold],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: Colony.gold.opacity(0.9), radius: 8)
            }
        }
    }
}

private struct NodeGlyph: View {
    let color: Color
    var pulsing: Bool = false
    var harvested: Bool = false
    @State private var pulse = false

    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(RadialGradient(
                    colors: [color.opacity(harvested ? 0.7 : 0.5), .clear],
                    center: .center, startRadius: 0, endRadius: s * 0.78))
                    .scaleEffect(pulsing && pulse ? 1.4 : 1.0)
                    .opacity(pulsing && pulse ? 0.65 : 1.0)
                Circle().stroke(color, lineWidth: harvested ? 3 : 2)
                    .frame(width: s * 0.6, height: s * 0.6)
                if harvested {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: s * 0.30))
                        .foregroundStyle(color)
                } else {
                    Circle().fill(color).frame(width: s * 0.26, height: s * 0.26)
                }
            }
            .shadow(color: color.opacity(0.8), radius: 6)
            .onAppear {
                if pulsing {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
        }
    }
}

private struct StubGlyph: View {
    let selected: Bool
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle()
                    .fill(.black.opacity(0.45))
                    .overlay(Circle().stroke(
                        selected ? Colony.gold : .white.opacity(0.4),
                        style: StrokeStyle(lineWidth: selected ? 2.4 : 1.4, dash: [3, 3])))
                    .frame(width: s * 0.62, height: s * 0.62)
                Text("?")
                    .font(.system(size: s * 0.34, weight: .bold, design: .monospaced))
                    .foregroundStyle(selected ? Colony.gold : .white.opacity(0.55))
            }
            .shadow(color: selected ? Colony.gold.opacity(0.7) : .clear, radius: 6)
        }
    }
}

private struct AntGlyph: View {
    let color: Color
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(color.opacity(0.18)).scaleEffect(1.5)
                Image(systemName: "ant.fill")
                    .font(.system(size: s * 0.85))
                    .foregroundStyle(color)
            }
            .shadow(color: color.opacity(0.6), radius: 3)
        }
    }
}

// MARK: - Seeded RNG

private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        let v = state &* 0x2545F4914F6CDD1D
        return Double(v >> 11) / Double(1 << 53)
    }
}
