import SwiftUI

// MARK: - Level 94 · Pinball Memory (interactive)
//
// MEMORIZE: only the angled deflectors are shown. They vanish, then a random
// entry node lights up. PREDICT: with the deflectors hidden, tap where you
// think the ball will exit. Only then does the ball animate along its true
// path so you can see if you were right. Eight rounds; score and streak build.

struct MathItLevelNinetyFourView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        PinballMemoryView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, PB.accent)
    }
}

// MARK: - Palette

private enum PB {
    static let bg     = Color(red: 0.05, green: 0.04, blue: 0.03)
    static let wood   = Color(red: 0.20, green: 0.13, blue: 0.07)
    static let woodHi = Color(red: 0.30, green: 0.20, blue: 0.11)
    static let grid   = Color(red: 0.55, green: 0.40, blue: 0.22)
    static let node   = Color(red: 0.62, green: 0.46, blue: 0.26)
    static let accent = Color(red: 0.96, green: 0.74, blue: 0.30)
    static let entry  = Color(red: 0.36, green: 0.74, blue: 1.0)
    static let bar    = Color(red: 0.98, green: 0.97, blue: 0.92)
    static let good   = Color(red: 0.40, green: 0.92, blue: 0.55)
    static let bad    = Color(red: 0.95, green: 0.36, blue: 0.34)
}

private enum Edge { case top, bottom, left, right }
private struct PNode: Equatable { let edge: Edge; let idx: Int }
private struct DCell: Equatable { let c: Int; let r: Int; let back: Bool }   // back == "\"

private struct Puzzle {
    let deflectors: [DCell]
    let path: [(c: Int, r: Int)]
    let entry: PNode
    let exit: PNode
}

private enum Phase { case watch, choose, reveal }

// MARK: - Puzzle generation

private enum PinGen {
    static func reflect(_ d: (Int, Int), _ back: Bool) -> (Int, Int) {
        back ? (d.1, d.0) : (-d.1, -d.0)
    }

    static func startInfo(_ e: PNode, L: Int) -> (cell: (Int, Int), dir: (Int, Int)) {
        switch e.edge {
        case .top:    return ((e.idx, 0), (0, 1))
        case .bottom: return ((e.idx, L - 1), (0, -1))
        case .left:   return ((0, e.idx), (1, 0))
        case .right:  return ((L - 1, e.idx), (-1, 0))
        }
    }

    /// Simulate one entry/deflector set; returns (path, exit, turns) or nil on a loop.
    private static func simulate(_ deflectors: [DCell], entry: PNode, L: Int)
        -> (path: [(c: Int, r: Int)], exit: PNode, turns: Int)? {
        let lookup = Dictionary(uniqueKeysWithValues: deflectors.map { ([$0.c, $0.r], $0.back) })
        let (start, dir0) = startInfo(entry, L: L)
        var c = start.0, r = start.1, dx = dir0.0, dy = dir0.1
        var path: [(c: Int, r: Int)] = [(c, r)]
        var turns = 0
        for _ in 0..<400 {
            if let back = lookup[[c, r]] {
                let nd = reflect((dx, dy), back)
                if nd != (dx, dy) { turns += 1 }
                (dx, dy) = nd
            }
            let nc = c + dx, nr = r + dy
            if nc < 0 || nc >= L || nr < 0 || nr >= L {
                let exit: PNode
                if dx == 1 { exit = PNode(edge: .right, idx: r) }
                else if dx == -1 { exit = PNode(edge: .left, idx: r) }
                else if dy == 1 { exit = PNode(edge: .bottom, idx: c) }
                else { exit = PNode(edge: .top, idx: c) }
                return (path, exit, turns)
            }
            c = nc; r = nr; path.append((c, r))
        }
        return nil
    }

    static func make(L: Int) -> Puzzle {
        let edges: [Edge] = [.top, .bottom, .left, .right]
        let minTurns = L <= 3 ? 1 : 2
        let kRange = L <= 3 ? 2...3 : 3...5
        for _ in 0..<400 {
            let entry = PNode(edge: edges.randomElement()!, idx: Int.random(in: 0..<L))
            let start = startInfo(entry, L: L).cell

            let k = Int.random(in: kRange)
            var cells: [DCell] = []
            var used = Set<[Int]>([[start.0, start.1]])
            while cells.count < k {
                let c = Int.random(in: 0..<L), r = Int.random(in: 0..<L)
                if used.contains([c, r]) { continue }
                used.insert([c, r])
                cells.append(DCell(c: c, r: r, back: Bool.random()))
            }
            if let firstPass = simulate(cells, entry: entry, L: L) {
                let visited = Set(firstPass.path.map { [$0.c, $0.r] })
                let activeCells = cells.filter { visited.contains([$0.c, $0.r]) }
                if let sim = simulate(activeCells, entry: entry, L: L),
                   sim.exit != entry, sim.turns >= minTurns, sim.path.count >= 3 {
                    return Puzzle(deflectors: activeCells, path: sim.path, entry: entry, exit: sim.exit)
                }
            }
        }
        // Fallback: straight shot across the top row.
        let entry = PNode(edge: .left, idx: 0)
        let sim = simulate([], entry: entry, L: L)!
        return Puzzle(deflectors: [], path: sim.path, entry: entry, exit: sim.exit)
    }
}

// MARK: - View

private struct PinballMemoryView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let roundsPerStage = 3
    private let watchDuration = 2.8
    private let ballAnim = 1.6
    private let revealHold = 1.1

    @State private var stage = 1                 // 1 = 3×3, 2 = 5×5
    @State private var puzzle = PinGen.make(L: 3)
    @State private var phase: Phase = .watch
    @State private var revealEpoch = Date.timeIntervalSinceReferenceDate
    @State private var solves = 0                // correct solves in current stage
    @State private var prevEntry: PNode? = nil
    @State private var selected: PNode? = nil
    @State private var completed = false

    private var gridL: Int { stage == 1 ? 3 : 5 }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack(alignment: .top) {
                PB.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 60).padding(.bottom, 14)

                    board
                        .frame(maxWidth: .infinity)
                        .frame(height: h * 0.60)
                        .padding(.horizontal, 18)

                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                Button(action: restart) {
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
                    title: "Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: restart,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .onAppear { startRound() }
        }
    }

    // MARK: Header / status / prompt

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

    // MARK: Board

    private var board: some View {
        GeometryReader { geo in
            let lay = Layout(size: geo.size, L: gridL)
            TimelineView(.animation) { timeline in
                Canvas { ctx, _ in
                    draw(&ctx, lay, sweep: sweep(timeline.date.timeIntervalSinceReferenceDate))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { v in
                    if hypot(v.translation.width, v.translation.height) < 14 { tap(v.location, lay) }
                }
            )
        }
    }

    private func sweep(_ now: Double) -> Double {
        phase == .reveal ? max(0, min(1, (now - revealEpoch) / ballAnim)) : 0
    }

    // MARK: Layout

    private struct Layout {
        let board: CGRect, inner: CGRect
        let L: Int
        init(size: CGSize, L: Int) {
            self.L = L
            board = CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12)
            inner = board.insetBy(dx: 40, dy: 40)
        }
        func xOf(_ c: Int) -> CGFloat { inner.minX + inner.width * CGFloat(c) / CGFloat(L - 1) }
        func yOf(_ r: Int) -> CGFloat { inner.minY + inner.height * CGFloat(r) / CGFloat(L - 1) }
        func cell(_ c: Int, _ r: Int) -> CGPoint { CGPoint(x: xOf(c), y: yOf(r)) }
        func pos(_ n: PNode) -> CGPoint {
            switch n.edge {
            case .top:    return CGPoint(x: xOf(n.idx), y: board.minY + 18)
            case .bottom: return CGPoint(x: xOf(n.idx), y: board.maxY - 18)
            case .left:   return CGPoint(x: board.minX + 18, y: yOf(n.idx))
            case .right:  return CGPoint(x: board.maxX - 18, y: yOf(n.idx))
            }
        }
        var allNodes: [PNode] {
            var out: [PNode] = []
            for i in 0..<L { out += [PNode(edge: .top, idx: i), PNode(edge: .bottom, idx: i),
                                     PNode(edge: .left, idx: i), PNode(edge: .right, idx: i)] }
            return out
        }
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ lay: Layout, sweep: Double) {
        let board = lay.board, inner = lay.inner

        ctx.fill(Path(roundedRect: board, cornerRadius: 22),
                 with: .linearGradient(Gradient(colors: [PB.woodHi, PB.wood]),
                                       startPoint: board.origin,
                                       endPoint: CGPoint(x: board.maxX, y: board.maxY)))
        ctx.stroke(Path(roundedRect: board, cornerRadius: 22), with: .color(PB.accent.opacity(0.35)), lineWidth: 2)
        ctx.stroke(Path(roundedRect: inner.insetBy(dx: -10, dy: -10), cornerRadius: 16),
                   with: .color(PB.grid.opacity(0.5)), lineWidth: 1.5)

        for c in 0..<lay.L { for r in 0..<lay.L {
            let p = lay.cell(c, r)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 1.6, width: 3.2, height: 3.2)),
                     with: .color(PB.grid.opacity(0.4)))
        } }

        func nodeRing(_ p: CGPoint, _ color: Color, glow: Bool, lw: CGFloat = 2) {
            if glow {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 17, y: p.y - 17, width: 34, height: 34)),
                         with: .color(color.opacity(0.25)))
            }
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                       with: .color(color), lineWidth: lw)
        }

        let entryShown = (phase != .watch)
        for n in lay.allNodes {
            if entryShown && n == puzzle.entry { continue }   // drawn specially below
            var color = PB.node, glow = false, lw: CGFloat = 2
            if phase == .reveal {
                if n == puzzle.exit { color = PB.good; glow = true; lw = 3 }
                if let s = selected, n == s, s != puzzle.exit { color = PB.bad; glow = true; lw = 3 }
            } else if phase == .choose, let s = selected, n == s {
                color = PB.accent; glow = true
            }
            nodeRing(lay.pos(n), color, glow: glow, lw: lw)
        }

        // Entry node + direction arrow (revealed only once deflectors hide)
        if entryShown {
            let ep = lay.pos(puzzle.entry)
            nodeRing(ep, PB.entry, glow: true, lw: 3)
            let dir = PinGen.startInfo(puzzle.entry, L: lay.L).dir
            let d = CGVector(dx: CGFloat(dir.0), dy: CGFloat(dir.1))
            let a0 = CGPoint(x: ep.x + d.dx * 16, y: ep.y + d.dy * 16)
            let a1 = CGPoint(x: ep.x + d.dx * 40, y: ep.y + d.dy * 40)
            var arrow = Path(); arrow.move(to: a0); arrow.addLine(to: a1)
            // arrowhead
            let perp = CGVector(dx: -d.dy, dy: d.dx)
            arrow.move(to: CGPoint(x: a1.x - d.dx * 8 + perp.dx * 6, y: a1.y - d.dy * 8 + perp.dy * 6))
            arrow.addLine(to: a1)
            arrow.addLine(to: CGPoint(x: a1.x - d.dx * 8 - perp.dx * 6, y: a1.y - d.dy * 8 - perp.dy * 6))
            ctx.stroke(arrow, with: .color(PB.accent), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
        }

        // Deflectors: shown while memorizing and during the reveal; hidden while choosing.
        if phase != .choose {
            let Lh = inner.width * 0.055
            for dfl in puzzle.deflectors {
                let c = lay.cell(dfl.c, dfl.r)
                var bar = Path()
                if dfl.back { bar.move(to: CGPoint(x: c.x - Lh, y: c.y - Lh)); bar.addLine(to: CGPoint(x: c.x + Lh, y: c.y + Lh)) }
                else { bar.move(to: CGPoint(x: c.x - Lh, y: c.y + Lh)); bar.addLine(to: CGPoint(x: c.x + Lh, y: c.y - Lh)) }
                ctx.stroke(bar, with: .color(PB.bar.opacity(0.22)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
                ctx.stroke(bar, with: .color(PB.bar), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            }
        }

        // Ball + trail: only during the reveal animation.
        if phase == .reveal {
            let poly = [lay.pos(puzzle.entry)] + puzzle.path.map { lay.cell($0.c, $0.r) } + [lay.pos(puzzle.exit)]
            var segLen: [CGFloat] = []; var total: CGFloat = 0
            for i in 1..<poly.count { let d = hypot(poly[i].x - poly[i-1].x, poly[i].y - poly[i-1].y); segLen.append(d); total += d }
            func at(_ u: CGFloat) -> CGPoint {
                var d = max(0, min(1, u)) * total
                for i in 1..<poly.count {
                    if d <= segLen[i-1] {
                        let f = segLen[i-1] == 0 ? 0 : d / segLen[i-1]
                        return CGPoint(x: poly[i-1].x + (poly[i].x - poly[i-1].x) * f,
                                       y: poly[i-1].y + (poly[i].y - poly[i-1].y) * f)
                    }
                    d -= segLen[i-1]
                }
                return poly.last!
            }
            let beads = 64
            for k in 0...beads {
                let u = CGFloat(k) / CGFloat(beads)
                if Double(u) > sweep { continue }
                let p = at(u)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.4, y: p.y - 2.4, width: 4.8, height: 4.8)),
                         with: .color(.white.opacity(0.9)))
            }

            // Every deflector hit turns an axis-aligned path through a right angle.
            let deflectorCells = Set(puzzle.deflectors.map { [$0.c, $0.r] })
            var traveled: CGFloat = 0
            for pathIndex in puzzle.path.indices {
                let polyIndex = pathIndex + 1
                traveled += segLen[polyIndex - 1]
                let cell = puzzle.path[pathIndex]
                guard deflectorCells.contains([cell.c, cell.r]),
                      polyIndex + 1 < poly.count else { continue }

                let bounceSweep = total == 0 ? 0 : Double(traveled / total)
                guard sweep >= bounceSweep else { continue }
                drawRightAngleMarker(
                    &ctx,
                    vertex: poly[polyIndex],
                    previous: poly[polyIndex - 1],
                    next: poly[polyIndex + 1],
                    flashing: sweep - bounceSweep < 0.08
                )
            }

            let bp = at(CGFloat(sweep))
            ctx.fill(Path(ellipseIn: CGRect(x: bp.x - 13, y: bp.y - 13, width: 26, height: 26)),
                     with: .color(PB.accent.opacity(0.25)))
            ctx.fill(Path(ellipseIn: CGRect(x: bp.x - 7, y: bp.y - 7, width: 14, height: 14)),
                     with: .color(.white))
        }
    }

    private func drawRightAngleMarker(
        _ ctx: inout GraphicsContext,
        vertex: CGPoint,
        previous: CGPoint,
        next: CGPoint,
        flashing: Bool
    ) {
        func unitVector(from origin: CGPoint, to point: CGPoint) -> CGVector {
            let dx = point.x - origin.x
            let dy = point.y - origin.y
            let length = max(0.001, hypot(dx, dy))
            return CGVector(dx: dx / length, dy: dy / length)
        }

        let incoming = unitVector(from: vertex, to: previous)
        let outgoing = unitVector(from: vertex, to: next)
        let arm: CGFloat = 10
        let first = CGPoint(x: vertex.x + incoming.dx * arm, y: vertex.y + incoming.dy * arm)
        let corner = CGPoint(x: first.x + outgoing.dx * arm, y: first.y + outgoing.dy * arm)
        let second = CGPoint(x: vertex.x + outgoing.dx * arm, y: vertex.y + outgoing.dy * arm)

        if flashing {
            ctx.fill(
                Path(ellipseIn: CGRect(x: vertex.x - 24, y: vertex.y - 24, width: 48, height: 48)),
                with: .color(PB.accent.opacity(0.20))
            )
        }

        var bracket = Path()
        bracket.move(to: first)
        bracket.addLine(to: corner)
        bracket.addLine(to: second)
        ctx.stroke(
            bracket,
            with: .color(PB.accent),
            style: StrokeStyle(lineWidth: flashing ? 3 : 2.2, lineCap: .round, lineJoin: .round)
        )

        let label = CGPoint(
            x: vertex.x + (incoming.dx + outgoing.dx) * 20,
            y: vertex.y + (incoming.dy + outgoing.dy) * 20
        )
        ctx.draw(
            Text("90°")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(PB.accent),
            at: label
        )
    }

    // MARK: Interaction

    private func tap(_ loc: CGPoint, _ lay: Layout) {
        guard phase == .choose else { return }
        var best: PNode? = nil
        var bestD: CGFloat = 28
        for n in lay.allNodes where n != puzzle.entry {
            let p = lay.pos(n)
            let d = hypot(loc.x - p.x, loc.y - p.y)
            if d < bestD { bestD = d; best = n }
        }
        guard let pick = best else { return }
        selected = pick
        let correct = pick == puzzle.exit
        revealEpoch = Date.timeIntervalSinceReferenceDate
        withAnimation(.easeInOut(duration: 0.3)) { phase = .reveal }
        DispatchQueue.main.asyncAfter(deadline: .now() + ballAnim + revealHold) { resolve(correct) }
    }

    // MARK: Flow

    private func resolve(_ correct: Bool) {
        guard correct else { startRound(); return }     // miss → redo with a new entry
        solves += 1
        if solves < roundsPerStage {
            startRound()
        } else if stage == 1 {
            withAnimation(.easeInOut(duration: 0.3)) { stage = 2 }
            solves = 0
            startRound()
        } else {
            withAnimation(.easeInOut(duration: 0.5)) { completed = true }
        }
    }

    private func startRound() {
        // Always present a different entry node from the previous round.
        var p = PinGen.make(L: gridL)
        var tries = 0
        while p.entry == prevEntry, tries < 30 { p = PinGen.make(L: gridL); tries += 1 }
        prevEntry = p.entry
        puzzle = p
        selected = nil
        phase = .watch
        DispatchQueue.main.asyncAfter(deadline: .now() + watchDuration) {
            if phase == .watch { withAnimation(.easeInOut(duration: 0.3)) { phase = .choose } }
        }
    }

    private func restart() {
        completed = false
        stage = 1; solves = 0; prevEntry = nil
        startRound()
    }
}

#Preview {
    MathItLevelNinetyFourView(onContinue: {}, onLevelSelect: {})
}
