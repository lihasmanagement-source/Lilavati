import SwiftUI

// MARK: - Level 91 · Dijkstra Path (interactive)
//
// You have 13 credits. Drag from the white ball along the edges — the line
// snaps node to node, and each edge spends its weight in credits. Steer the
// ball from A to the dotted goal F. The only route reachable on exactly 13
// credits is the optimal one (A→C→B→D→E→F), so the budget enforces efficiency.

struct MathItLevelNinetyOneView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        DijkstraPathView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, DJ.accent)
    }
}

// MARK: - Palette

private enum DJ {
    static let bg     = Color(red: 0.04, green: 0.06, blue: 0.09)
    static let edge   = Color(red: 0.62, green: 0.66, blue: 0.70)
    static let node   = Color(red: 0.07, green: 0.20, blue: 0.18)
    static let ring   = Color(red: 0.80, green: 0.66, blue: 0.40)
    static let accent = Color(red: 0.93, green: 0.80, blue: 0.46)
    static let start  = Color(red: 0.34, green: 0.86, blue: 0.84)
    static let path   = Color(red: 0.40, green: 0.90, blue: 0.74)
    static let draft  = Color(red: 0.95, green: 0.78, blue: 0.40)
    static let label  = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let spent  = Color(red: 0.30, green: 0.33, blue: 0.38)
}

// MARK: - Graph data

private struct GNode { let id: String; let x: Double; let y: Double }   // normalized 0…1
private struct GEdge { let a: String; let b: String; let w: Int }

private enum Graph {
    static let nodes: [GNode] = [
        GNode(id: "A", x: 0.10, y: 0.50),
        GNode(id: "B", x: 0.34, y: 0.18),
        GNode(id: "D", x: 0.70, y: 0.24),
        GNode(id: "F", x: 0.92, y: 0.44),
        GNode(id: "C", x: 0.36, y: 0.82),
        GNode(id: "E", x: 0.68, y: 0.82),
    ]

    static let edges: [GEdge] = [
        GEdge(a: "A", b: "B", w: 4),
        GEdge(a: "B", b: "D", w: 5),
        GEdge(a: "D", b: "F", w: 6),
        GEdge(a: "A", b: "C", w: 2),
        GEdge(a: "B", b: "C", w: 1),
        GEdge(a: "C", b: "D", w: 8),
        GEdge(a: "D", b: "E", w: 2),
        GEdge(a: "C", b: "E", w: 10),
        GEdge(a: "E", b: "F", w: 3),
    ]

    static func node(_ id: String) -> GNode { nodes.first { $0.id == id }! }

    static func weight(_ a: String, _ b: String) -> Int? {
        edges.first { ($0.a == a && $0.b == b) || ($0.a == b && $0.b == a) }?.w
    }
}

// MARK: - View

private struct DijkstraPathView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let credits = 13
    private let nodeR: CGFloat = 24
    private let snapR: CGFloat = 42

    @State private var path: [String] = ["A"]   // committed route the ball travels
    @State private var draft: [String] = []      // tentative extension while dragging
    @State private var ballIndex = 0             // ball's position along `path`
    @State private var dragging = false
    @State private var dragPoint: CGPoint? = nil
    @State private var completed = false

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height

            ZStack(alignment: .top) {
                DJ.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        .padding(.bottom, 12)

                    creditBar
                        .padding(.horizontal, 28)
                        .padding(.bottom, 10)

                    graphArea
                        .frame(maxWidth: .infinity)
                        .frame(height: h * 0.52)

                    Button(action: reset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 48, height: 48)
                            .background(.white.opacity(0.06), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)

                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Optimal Route",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 7) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))
            EmptyView()
                .font(.trajan(34))
                .tracking(7)
                .foregroundStyle(Color.mathGold.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Credit bar

    private var creditBar: some View {
        let used = spentCost
        let tentative = draftCost
        let remaining = credits - used - tentative
        return VStack(spacing: 6) {
            HStack {
                Text("CREDITS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(max(0, remaining)) / \(credits)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(remaining == 0 ? DJ.accent : DJ.path)
                    .contentTransition(.numericText())
            }
            HStack(spacing: 3) {
                ForEach(0..<credits, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(segmentColor(i, remaining: remaining, tentative: tentative))
                        .frame(height: 9)
                }
            }
            .animation(.easeOut(duration: 0.2), value: used)
            .animation(.easeOut(duration: 0.15), value: tentative)
        }
    }

    private func segmentColor(_ i: Int, remaining: Int, tentative: Int) -> Color {
        if i < remaining { return DJ.path }                     // still available
        if i < remaining + tentative { return DJ.draft }        // about to spend
        return DJ.spent                                         // already spent
    }

    // MARK: Graph + interaction

    private var graphArea: some View {
        GeometryReader { geo in
            let pos = layout(geo.size)
            ZStack {
                Canvas { ctx, _ in draw(&ctx, pos) }

                // White traveling ball
                if let p = pos[path[ballIndex]] {
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .white.opacity(0.85), radius: 9)
                        .position(p)
                        .animation(.easeInOut(duration: 0.45), value: ballIndex)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in onDragChanged(v, pos: pos) }
                    .onEnded { _ in onDragEnded() }
            )
        }
    }

    private func layout(_ size: CGSize) -> [String: CGPoint] {
        let pad: CGFloat = 46
        var d: [String: CGPoint] = [:]
        for n in Graph.nodes {
            d[n.id] = CGPoint(x: pad + CGFloat(n.x) * (size.width - 2 * pad),
                              y: pad + CGFloat(n.y) * (size.height - 2 * pad))
        }
        return d
    }

    private func draw(_ ctx: inout GraphicsContext, _ pos: [String: CGPoint]) {
        // Base edges
        for e in Graph.edges {
            guard let a = pos[e.a], let b = pos[e.b] else { continue }
            var line = Path(); line.move(to: a); line.addLine(to: b)
            ctx.stroke(line, with: .color(DJ.edge.opacity(0.40)), lineWidth: 2)
        }

        // Committed travelled route
        strokeChain(&ctx, ids: path, pos: pos, color: DJ.path, width: 4, glow: true)
        // Tentative draft (dashed)
        if !draft.isEmpty, let tail = path.last {
            strokeChain(&ctx, ids: [tail] + draft, pos: pos, color: DJ.draft, width: 3,
                        glow: false, dash: [7, 5])
        }
        // Trailing rubber-band line to the finger
        if dragging, let dp = dragPoint, let tail = pos[(path + draft).last ?? "A"] {
            var line = Path(); line.move(to: tail); line.addLine(to: dp)
            ctx.stroke(line, with: .color(DJ.draft.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
        }

        // Edge weights
        for e in Graph.edges {
            guard let a = pos[e.a], let b = pos[e.b] else { continue }
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(1, hypot(dx, dy))
            let off = CGPoint(x: -dy / len * 14, y: dx / len * 14)
            ctx.draw(Text("\(e.w)").font(.garamond(16))
                        .foregroundColor(DJ.label),
                     at: CGPoint(x: mid.x + off.x, y: mid.y + off.y))
        }

        // Nodes
        let filled = Set(path.prefix(ballIndex + 1))
        for n in Graph.nodes {
            guard let p = pos[n.id] else { continue }
            let isStart = n.id == "A", isGoal = n.id == "F"
            let isFilled = filled.contains(n.id)
            let ringColor = isStart ? DJ.start : (isGoal ? DJ.accent : DJ.ring)
            let rect = CGRect(x: p.x - nodeR, y: p.y - nodeR, width: nodeR * 2, height: nodeR * 2)
            let circle = Path(ellipseIn: rect)

            if (isStart || isGoal) && !isFilled {
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: -7, dy: -7)),
                         with: .color(ringColor.opacity(0.18)))
            }
            ctx.fill(circle, with: .color(isFilled ? .white : DJ.node))

            if isGoal && !completed {
                ctx.stroke(circle, with: .color(ringColor),
                           style: StrokeStyle(lineWidth: 3, dash: [5, 5]))   // dotted goal
            } else {
                ctx.stroke(circle, with: .color(ringColor), lineWidth: isStart || isGoal ? 3 : 2)
            }
            ctx.draw(Text(n.id).font(.garamond(22))
                        .foregroundColor(isFilled ? Color.black.opacity(0.8) : DJ.label),
                     at: p)
        }
    }

    private func strokeChain(_ ctx: inout GraphicsContext, ids: [String], pos: [String: CGPoint],
                             color: Color, width: CGFloat, glow: Bool, dash: [CGFloat] = []) {
        guard ids.count > 1 else { return }
        var p = Path()
        guard let first = pos[ids[0]] else { return }
        p.move(to: first)
        for id in ids.dropFirst() { if let q = pos[id] { p.addLine(to: q) } }
        if glow {
            ctx.stroke(p, with: .color(color.opacity(0.28)),
                       style: StrokeStyle(lineWidth: width + 7, lineCap: .round, lineJoin: .round))
        }
        ctx.stroke(p, with: .color(color),
                   style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
    }

    // MARK: Interaction

    private func onDragChanged(_ v: DragGesture.Value, pos: [String: CGPoint]) {
        guard !completed else { return }
        if !dragging {
            guard let ballP = pos[path.last ?? "A"] else { return }
            // The drag must begin on the ball's current node.
            if hypot(v.startLocation.x - ballP.x, v.startLocation.y - ballP.y) <= snapR {
                dragging = true
            } else { return }
        }
        dragPoint = v.location
        if let near = nearestNode(to: v.location, pos: pos) { handleSnap(near) }
    }

    private func onDragEnded() {
        dragging = false
        dragPoint = nil
        guard !draft.isEmpty else { return }
        path += draft
        draft = []
        stepBall()
    }

    private func handleSnap(_ x: String) {
        let chain = path + draft
        guard let tail = chain.last, x != tail else { return }

        // Drag back onto the previous node → undo last draft step.
        if chain.count >= 2, x == chain[chain.count - 2], !draft.isEmpty {
            draft.removeLast()
            return
        }
        // Forward: must be a new, adjacent node we can still afford.
        guard !chain.contains(x), Graph.weight(tail, x) != nil else { return }
        let prospective = spentCost + cost(of: [path.last!] + draft + [x])
        if prospective <= credits { draft.append(x) }
    }

    private func nearestNode(to p: CGPoint, pos: [String: CGPoint]) -> String? {
        var best: String? = nil
        var bestD = snapR
        for n in Graph.nodes {
            guard let q = pos[n.id] else { continue }
            let d = hypot(p.x - q.x, p.y - q.y)
            if d <= bestD { bestD = d; best = n.id }
        }
        return best
    }

    private func stepBall() {
        guard ballIndex < path.count - 1 else {
            if path.last == "F" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.5)) { completed = true }
                }
            }
            return
        }
        withAnimation(.easeInOut(duration: 0.45)) { ballIndex += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { stepBall() }
    }

    private func reset() {
        completed = false
        dragging = false
        dragPoint = nil
        draft = []
        path = ["A"]
        ballIndex = 0
    }

    // MARK: Cost helpers

    private var spentCost: Int { cost(of: path) }
    private var draftCost: Int { draft.isEmpty ? 0 : cost(of: [path.last!] + draft) }

    private func cost(of nodes: [String]) -> Int {
        guard nodes.count > 1 else { return 0 }
        var c = 0
        for i in 1..<nodes.count { c += Graph.weight(nodes[i - 1], nodes[i]) ?? 0 }
        return c
    }
}

#Preview {
    MathItLevelNinetyOneView(onContinue: {}, onLevelSelect: {})
}
