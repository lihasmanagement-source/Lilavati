import SwiftUI

// MARK: - Level 96 · Fill the Grid (interactive · Shikaku, 3 stages)
//
// Each numbered cell anchors a rectangle whose area equals the number. Start a
// drag ON a number and drag out to draw its rectangle. Rectangles can't overlap,
// can't contain another number, and must match the number's area. Fill the grid
// — three stages, same size, different number configurations.

struct MathItLevelNinetySixView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    // Stage 1: flat area Shikaku · Stage 2: small 3D prism · Stage 3: grid-lined sphere.
    private enum Phase { case flat, small, sphere }
    @State private var phase: Phase = .flat
    @State private var levelDone = false

    var body: some View {
        ZStack {
            Group {
                switch phase {
                case .flat:
                    FillTheGridView(onContinue: {}, onLevelSelect: onLevelSelect,
                                    stageOffset: 0, totalStages: 3,
                                    stages: [Grid96.stages[0]],
                                    onFinished: { withAnimation(.easeInOut(duration: 0.4)) { phase = .small } })
                case .small:
                    Shikaku3DView(spec: Prisms.small, stageLabel: "STAGE 2/3",
                                  onComplete: { withAnimation(.easeInOut(duration: 0.4)) { phase = .sphere } },
                                  onLevelSelect: onLevelSelect)
                        .id("small")
                case .sphere:
                    SphereFillView(stageLabel: "STAGE 3/3",
                                   onComplete: { withAnimation(.easeInOut(duration: 0.5)) { levelDone = true } },
                                   onLevelSelect: onLevelSelect)
                        .id("sphere")
                }
            }

            CompletionOverlay(title: "Volume Filled", isVisible: levelDone,
                              onContinue: onContinue, onReplay: restart, onLevelSelect: onLevelSelect)
                .zIndex(500)
        }
        .environment(\.mathItAccent, FG.accent)
    }

    private func restart() { levelDone = false; phase = .flat }
}

// MARK: - Palette

private enum FG {
    static let bg     = Color(red: 0.03, green: 0.03, blue: 0.06)
    static let accent = Color(red: 0.62, green: 0.40, blue: 0.95)
    static let grid   = Color(red: 0.30, green: 0.32, blue: 0.42)
    static let label  = Color(red: 0.70, green: 0.74, blue: 0.85)
    static let good   = Color(red: 0.40, green: 0.92, blue: 0.55)
    static let bad    = Color(red: 0.95, green: 0.36, blue: 0.34)

    static let tints: [Color] = [
        Color(red: 0.20, green: 0.60, blue: 0.70), Color(red: 0.42, green: 0.66, blue: 0.26),
        Color(red: 0.66, green: 0.28, blue: 0.42), Color(red: 0.26, green: 0.45, blue: 0.80),
        Color(red: 0.72, green: 0.64, blue: 0.20), Color(red: 0.80, green: 0.50, blue: 0.18),
        Color(red: 0.52, green: 0.30, blue: 0.70), Color(red: 0.22, green: 0.62, blue: 0.55),
        Color(red: 0.74, green: 0.26, blue: 0.26), Color(red: 0.20, green: 0.34, blue: 0.62),
        Color(red: 0.24, green: 0.64, blue: 0.46), Color(red: 0.55, green: 0.45, blue: 0.30),
    ]
    static func tint(_ i: Int) -> Color { tints[i % tints.count] }
}

private struct GRect: Equatable { var c0, c1, r0, r1: Int
    var area: Int { (c1 - c0 + 1) * (r1 - r0 + 1) }
    func contains(_ c: Int, _ r: Int) -> Bool { c >= c0 && c <= c1 && r >= r0 && r <= r1 }
}

// Clue cell sits at the TOP-LEFT of its solution rectangle (area = n).
private struct Clue { let c, r, n: Int }

private enum Grid96 {
    static let stages: [[Clue]] = [
        // Stage 1
        [Clue(c: 1, r: 1, n: 4),  Clue(c: 3, r: 1, n: 12), Clue(c: 1, r: 3, n: 6),
         Clue(c: 4, r: 3, n: 4),  Clue(c: 6, r: 3, n: 6),  Clue(c: 1, r: 5, n: 8),
         Clue(c: 5, r: 5, n: 6),  Clue(c: 8, r: 5, n: 2),  Clue(c: 1, r: 7, n: 8),
         Clue(c: 5, r: 7, n: 6),  Clue(c: 8, r: 7, n: 2)],
        // Stage 2 — band partition with 3×3 squares
        [Clue(c: 1, r: 1, n: 8),  Clue(c: 5, r: 1, n: 8),
         Clue(c: 1, r: 3, n: 6),  Clue(c: 3, r: 3, n: 9),  Clue(c: 6, r: 3, n: 9),
         Clue(c: 1, r: 6, n: 9),  Clue(c: 4, r: 6, n: 6),  Clue(c: 6, r: 6, n: 9)],
        // Stage 3 — mixed strips and a big block
        [Clue(c: 1, r: 1, n: 6),  Clue(c: 3, r: 1, n: 6),
         Clue(c: 3, r: 2, n: 6),  Clue(c: 6, r: 2, n: 6),
         Clue(c: 1, r: 4, n: 8),  Clue(c: 5, r: 4, n: 8),
         Clue(c: 1, r: 6, n: 9),  Clue(c: 4, r: 6, n: 15)],
    ]
}

// MARK: - Layout

private struct Layout96 {
    let cs: CGFloat, gx0: CGFloat, gy0: CGFloat
    init(_ size: CGSize) {
        let mTop: CGFloat = 28, mLeft: CGFloat = 26
        let avail = min(size.width - mLeft - 16, size.height - mTop - 34)
        cs = avail / 8
        gx0 = (size.width - cs * 8) / 2 + mLeft / 2
        gy0 = mTop
    }
    func x(_ c: Int) -> CGFloat { gx0 + CGFloat(c - 1) * cs }
    func y(_ r: Int) -> CGFloat { gy0 + CGFloat(r - 1) * cs }
    func rect(_ g: GRect) -> CGRect {
        CGRect(x: x(g.c0), y: y(g.r0),
               width: CGFloat(g.c1 - g.c0 + 1) * cs, height: CGFloat(g.r1 - g.r0 + 1) * cs)
    }
    func cellAt(_ p: CGPoint) -> (Int, Int)? {
        let c = Int((p.x - gx0) / cs) + 1, r = Int((p.y - gy0) / cs) + 1
        guard (1...8).contains(c), (1...8).contains(r) else { return nil }
        return (c, r)
    }
}

// MARK: - View

private struct FillTheGridView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void
    var stageOffset = 0
    var totalStages = 3
    var stages: [[Clue]] = Grid96.stages
    var onFinished: (() -> Void)? = nil    // when set, called instead of showing the final overlay

    @State private var stage = 0
    @State private var placed: [Int: GRect] = [:]
    @State private var dragIndex: Int? = nil
    @State private var anchor: (Int, Int)? = nil
    @State private var dragCell: (Int, Int)? = nil
    @State private var badFlash = false
    @State private var completed = false

    private var clues: [Clue] { stages[stage] }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack(alignment: .top) {
                FG.bg.ignoresSafeArea()
                if badFlash { FG.bad.opacity(0.16).ignoresSafeArea().transition(.opacity) }

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 60).padding(.bottom, 12)
                    coverageBar.padding(.horizontal, 30).padding(.bottom, 8)
                    boardArea
                        .frame(maxWidth: .infinity)
                        .frame(height: h * 0.66)
                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                Button(action: reset) {
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
                    title: "Grid Filled",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .animation(.easeInOut(duration: 0.25), value: badFlash)
        }
    }

    private var header: some View {
        VStack(spacing: 7) {
            Text("STAGE \(stage + 1 + stageOffset)/\(totalStages)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4).foregroundStyle(Color.mathGold.opacity(0.85))
            EmptyView()
                .font(.trajan(32))
                .tracking(5).foregroundStyle(Color.mathGold.opacity(0.95))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 24)
    }

    private var coverageBar: some View {
        let covered = placed.values.reduce(0) { $0 + $1.area }
        let pct = Int(round(Double(covered) / 64.0 * 100))
        return VStack(spacing: 5) {
            HStack {
                Spacer()
                Text("\(pct)%").font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(FG.accent)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule().fill(FG.accent).frame(width: g.size.width * CGFloat(covered) / 64)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: Board + interaction

    private var boardArea: some View {
        GeometryReader { geo in
            let lay = Layout96(geo.size)
            Canvas { ctx, _ in draw(&ctx, lay) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in onChanged(v, lay) }
                        .onEnded { _ in onEnded() }
                )
        }
    }

    private func clueIndex(at c: Int, _ r: Int) -> Int? {
        clues.firstIndex { $0.c == c && $0.r == r }
    }

    private func onChanged(_ v: DragGesture.Value, _ lay: Layout96) {
        guard !completed else { return }
        if dragIndex == nil {
            guard let (c, r) = lay.cellAt(v.startLocation), let idx = clueIndex(at: c, r),
                  placed[idx] == nil else { return }
            dragIndex = idx; anchor = (c, r)
        }
        if let cell = lay.cellAt(v.location) { dragCell = cell }
    }

    private func onEnded() {
        defer { dragIndex = nil; anchor = nil; dragCell = nil }
        guard let idx = dragIndex, let a = anchor, let d = dragCell else { return }
        let rect = bbox(a, d)
        if isValid(rect, idx) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { placed[idx] = rect }
            if placed.count == clues.count { advance() }
        } else {
            withAnimation { badFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { badFlash = false } }
        }
    }

    private func advance() {
        if stage < stages.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeInOut(duration: 0.3)) { stage += 1; placed = [:] }
            }
        } else if let onFinished {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onFinished() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.5)) { completed = true }
            }
        }
    }

    private func bbox(_ a: (Int, Int), _ b: (Int, Int)) -> GRect {
        GRect(c0: min(a.0, b.0), c1: max(a.0, b.0), r0: min(a.1, b.1), r1: max(a.1, b.1))
    }

    private func isValid(_ rect: GRect, _ idx: Int) -> Bool {
        let clue = clues[idx]
        guard rect.area == clue.n, rect.contains(clue.c, clue.r) else { return false }
        for (j, other) in clues.enumerated() where j != idx {
            if rect.contains(other.c, other.r) { return false }
        }
        for (j, p) in placed where j != idx {
            if rect.c0 <= p.c1 && rect.c1 >= p.c0 && rect.r0 <= p.r1 && rect.r1 >= p.r0 { return false }
        }
        return true
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ lay: Layout96) {
        let cs = lay.cs

        for c in 1...8 {
            ctx.draw(Text("\(c)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(FG.label), at: CGPoint(x: lay.x(c) + cs / 2, y: lay.gy0 - 12))
        }
        let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
        for r in 1...8 {
            ctx.draw(Text(letters[r - 1]).font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(FG.label), at: CGPoint(x: lay.gx0 - 13, y: lay.y(r) + cs / 2))
        }

        var lines = Path()
        for c in 0...8 { lines.move(to: CGPoint(x: lay.gx0 + CGFloat(c) * cs, y: lay.gy0)); lines.addLine(to: CGPoint(x: lay.gx0 + CGFloat(c) * cs, y: lay.gy0 + cs * 8)) }
        for r in 0...8 { lines.move(to: CGPoint(x: lay.gx0, y: lay.gy0 + CGFloat(r) * cs)); lines.addLine(to: CGPoint(x: lay.gx0 + cs * 8, y: lay.gy0 + CGFloat(r) * cs)) }
        ctx.stroke(lines, with: .color(FG.grid.opacity(0.35)), lineWidth: 1)
        ctx.stroke(Path(CGRect(x: lay.gx0, y: lay.gy0, width: cs * 8, height: cs * 8)),
                   with: .color(FG.grid.opacity(0.7)), lineWidth: 1.5)

        for (idx, g) in placed {
            let col = FG.tint(idx)
            let rect = lay.rect(g).insetBy(dx: 2.5, dy: 2.5)
            let rr = Path(roundedRect: rect, cornerRadius: 9)
            ctx.fill(rr, with: .color(col.opacity(0.85)))
            ctx.stroke(rr, with: .color(col), lineWidth: 2)
            ctx.draw(Text("\(clues[idx].n)").font(.system(size: cs * 0.42, weight: .bold, design: .rounded))
                        .foregroundColor(.white), at: CGPoint(x: rect.midX, y: rect.midY))
        }

        if let a = anchor, let d = dragCell, let idx = dragIndex {
            let g = bbox(a, d)
            let ok = isValid(g, idx)
            let rect = lay.rect(g).insetBy(dx: 2.5, dy: 2.5)
            let rr = Path(roundedRect: rect, cornerRadius: 9)
            let col = ok ? FG.good : FG.bad
            ctx.fill(rr, with: .color(col.opacity(0.18)))
            ctx.stroke(rr, with: .color(col), style: StrokeStyle(lineWidth: 2.5, dash: ok ? [] : [6, 5]))
            ctx.draw(Text("\(g.area)/\(clues[idx].n)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(col), at: CGPoint(x: rect.midX, y: rect.minY - 12))
        }

        for (idx, clue) in clues.enumerated() where placed[idx] == nil {
            let inset = cs * 0.13
            let rect = CGRect(x: lay.x(clue.c) + inset, y: lay.y(clue.r) + inset,
                              width: cs - inset * 2, height: cs - inset * 2)
            let token = Path(roundedRect: rect, cornerRadius: cs * 0.18)
            ctx.fill(token, with: .color(FG.tint(idx).opacity(0.22)))
            ctx.stroke(token, with: .color(FG.tint(idx).opacity(0.9)), lineWidth: 1.6)
            ctx.draw(Text("\(clue.n)").font(.system(size: cs * 0.42, weight: .bold, design: .rounded))
                        .foregroundColor(.white), at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }

    private func reset() {
        completed = false
        stage = 0
        placed = [:]
        dragIndex = nil; anchor = nil; dragCell = nil
        badFlash = false
    }
}

// MARK: - Stage 1 · 3D volume Shikaku

private struct V3 { var x: Double; var y: Double; var z: Double }

private struct Box3: Equatable {
    var x0, x1, y0, y1, z0, z1: Int
    var volume: Int { (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1) }
    func contains(_ x: Int, _ y: Int, _ z: Int) -> Bool {
        x >= x0 && x <= x1 && y >= y0 && y <= y1 && z >= z0 && z <= z1
    }
    func overlaps(_ o: Box3) -> Bool {
        x0 <= o.x1 && x1 >= o.x0 && y0 <= o.y1 && y1 >= o.y0 && z0 <= o.z1 && z1 >= o.z0
    }
}

private struct Clue3 { let x, y, z, n: Int }

// A 3×3×2 = 18-cell prism partitioned into four rectangular boxes.
private struct PrismSpec {
    let nx: Int, ny: Int, nz: Int
    let clues: [Clue3]                     // each carries an anchor cell (x,y,z) + volume n
    let title: String
    let mask: (Int, Int, Int) -> Bool      // which cells actually exist (for non-cuboid solids)

    init(nx: Int, ny: Int, nz: Int, clues: [Clue3], title: String = "FILL THE VOLUME",
         mask: @escaping (Int, Int, Int) -> Bool = { _, _, _ in true }) {
        self.nx = nx; self.ny = ny; self.nz = nz; self.clues = clues; self.title = title; self.mask = mask
    }

    var total: Int {
        var t = 0
        for z in 0..<nz { for y in 0..<ny { for x in 0..<nx where mask(x, y, z) { t += 1 } } }
        return t
    }
}

private enum Prisms {
    // Numbers are pre-placed on spaced-out cubes so each has room for its fill.
    static let small = PrismSpec(nx: 3, ny: 3, nz: 2, clues: [
        Clue3(x: 1, y: 0, z: 0, n: 6),
        Clue3(x: 0, y: 2, z: 0, n: 4),
        Clue3(x: 2, y: 2, z: 0, n: 4),
        Clue3(x: 1, y: 1, z: 1, n: 4),
    ])
    static let big = PrismSpec(nx: 4, ny: 3, nz: 2, clues: [
        Clue3(x: 0, y: 0, z: 0, n: 4),
        Clue3(x: 3, y: 0, z: 0, n: 4),
        Clue3(x: 0, y: 2, z: 0, n: 4),
        Clue3(x: 3, y: 2, z: 0, n: 4),
        Clue3(x: 1, y: 1, z: 1, n: 4),
        Clue3(x: 2, y: 1, z: 1, n: 4),
    ])
}

private struct Shikaku3DView: View {
    let spec: PrismSpec
    let stageLabel: String
    let onComplete: () -> Void
    let onLevelSelect: () -> Void

    @State private var owner: [Int: Int] = [:]      // cell key → clue (colour) index
    @State private var activeClue = 0
    @State private var rejectCell: (Int, Int, Int)? = nil
    @State private var angleX = 0.52
    @State private var angleY = 0.68
    @State private var baseX = 0.52
    @State private var baseY = 0.68
    @State private var dragging = false
    @State private var solved = false
    @State private var started = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack(alignment: .top) {
                FG.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 60).padding(.bottom, 6)
                    Text("Tap a number to select it, then tap cubes to fill its volume. Drag to rotate.")
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20).padding(.bottom, 4)
                    boardArea.frame(maxWidth: .infinity).frame(height: h * 0.56)
                    palette.padding(.top, 8)
                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                Button(action: reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .position(x: w - 34, y: 54)
            }
            .onAppear { if !started { started = true; seedAnchors() } }
        }
    }

    private var header: some View {
        VStack(spacing: 7) {
            Text(stageLabel)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4).foregroundStyle(Color.mathGold.opacity(0.85))
            Text(spec.title)
                .font(.trajan(30))
                .tracking(4).foregroundStyle(Color.mathGold.opacity(0.95))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 24)
    }

    private var palette: some View {
        HStack(spacing: 9) {
            ForEach(spec.clues.indices, id: \.self) { idx in
                let n = spec.clues[idx].n
                let cnt = count(idx)
                let sel = activeClue == idx
                let done = cnt == n
                Button { activeClue = idx } label: {
                    VStack(spacing: 1) {
                        Text("\(n)").font(.system(size: 17, weight: .bold, design: .rounded))
                        Text("\(cnt)/\(n)").font(.system(size: 9, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(sel ? .black : .white.opacity(0.92))
                    .frame(width: 48, height: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(FG.tint(idx).opacity(sel ? 1 : 0.26)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(done ? FG.good : FG.tint(idx), lineWidth: sel ? 0 : 1.6))
                    .overlay(alignment: .topTrailing) {
                        if done { Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(FG.good).padding(2) }
                    }
                    .scaleEffect(sel ? 1.05 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: activeClue)
    }

    private var boardArea: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in draw(&ctx, size) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            if !dragging { dragging = true; baseX = angleX; baseY = angleY }
                            angleY = baseY + Double(v.translation.width) * 0.011
                            angleX = max(-1.3, min(1.3, baseX + Double(v.translation.height) * 0.011))
                        }
                        .onEnded { v in
                            dragging = false
                            if hypot(v.translation.width, v.translation.height) < 10 { handleTap(v.location, size) }
                        }
                )
        }
    }

    // MARK: 3D math

    private func rotated(_ p: V3) -> V3 {
        let a = angleX, b = angleY
        let y1 = p.y * cos(a) - p.z * sin(a)
        let z1 = p.y * sin(a) + p.z * cos(a)
        let x2 = p.x * cos(b) + z1 * sin(b)
        let z2 = -p.x * sin(b) + z1 * cos(b)
        return V3(x: x2, y: y1, z: z2)
    }
    private func project(_ p: V3, _ size: CGSize) -> CGPoint {
        let s = Double(min(size.width, size.height)) * 0.24
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        let camera = 6.0
        let r = rotated(p)
        let f = camera / (camera - r.z)
        return CGPoint(x: cx + r.x * f * s, y: cy - r.y * f * s)
    }
    private func depth(_ p: V3) -> Double { rotated(p).z }
    private func cellCenter(_ x: Int, _ y: Int, _ z: Int) -> V3 {
        V3(x: Double(x) - Double(spec.nx - 1) / 2,
           y: Double(y) - Double(spec.ny - 1) / 2,
           z: Double(z) - Double(spec.nz - 1) / 2)
    }
    private func wb(_ i: Int, _ n: Int) -> Double { Double(i) - Double(n) / 2 }

    // MARK: Cells

    private func cellKey(_ x: Int, _ y: Int, _ z: Int) -> Int { x + spec.nx * (y + spec.ny * z) }
    private func decode(_ k: Int) -> (Int, Int, Int) {
        (k % spec.nx, (k / spec.nx) % spec.ny, k / (spec.nx * spec.ny))
    }
    private func count(_ idx: Int) -> Int { owner.values.reduce(0) { $1 == idx ? $0 + 1 : $0 } }
    private func anchorAt(_ c: (Int, Int, Int)) -> Int? {
        spec.clues.firstIndex { $0.x == c.0 && $0.y == c.1 && $0.z == c.2 }
    }

    private func seedAnchors() {
        for (idx, c) in spec.clues.enumerated() { owner[cellKey(c.x, c.y, c.z)] = idx }
    }

    private func pickCell(_ loc: CGPoint, _ size: CGSize) -> (Int, Int, Int)? {
        var best: (Int, Int, Int)? = nil
        var bestDepth = -Double.infinity
        let radius = Double(min(size.width, size.height)) * 0.11
        for z in 0..<spec.nz { for y in 0..<spec.ny { for x in 0..<spec.nx where spec.mask(x, y, z) {
            let p = project(cellCenter(x, y, z), size)
            if hypot(Double(loc.x - p.x), Double(loc.y - p.y)) <= radius {
                let d = depth(cellCenter(x, y, z))
                if d > bestDepth { bestDepth = d; best = (x, y, z) }
            }
        } } }
        return best
    }

    // MARK: Interaction

    private func handleTap(_ loc: CGPoint, _ size: CGSize) {
        guard !solved, let cell = pickCell(loc, size) else { return }
        if let a = anchorAt(cell) { activeClue = a; return }   // tapping a numbered cube selects it

        let key = cellKey(cell.0, cell.1, cell.2)
        if let o = owner[key] {
            if o == activeClue { owner[key] = nil }            // clear your own (non-anchor) cube
            return
        }
        if count(activeClue) < spec.clues[activeClue].n {
            owner[key] = activeClue
            if owner.count == spec.total { finish() }
        } else {
            reject(cell)
        }
    }

    private func reject(_ cell: (Int, Int, Int)) {
        HapticPlayer.playLightTap()
        rejectCell = cell
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if rejectCell.map({ $0 == cell }) ?? false { rejectCell = nil }
        }
    }

    private func finish() {
        solved = true
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { onComplete() }
    }

    private func reset() { owner = [:]; seedAnchors(); activeClue = 0; rejectCell = nil; solved = false }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        // Every voxel of the solid, back-to-front. Empty cells are faint outlines
        // so the shape (a prism or a sphere) stays visible; filled cells are solid.
        var cells: [(Int, Int, Int)] = []
        for z in 0..<spec.nz { for y in 0..<spec.ny { for x in 0..<spec.nx where spec.mask(x, y, z) { cells.append((x, y, z)) } } }
        cells.sort { depth(cellCenter($0.0, $0.1, $0.2)) < depth(cellCenter($1.0, $1.1, $1.2)) }
        for cell in cells {
            let key = cellKey(cell.0, cell.1, cell.2)
            if let idx = owner[key] {
                drawBox(&ctx, single(cell), size, FG.tint(idx), opacity: 0.82, fill: true, dashed: false)
            } else {
                drawBox(&ctx, single(cell), size, FG.grid, opacity: 0.16, fill: false, dashed: false)
            }
        }
        if let rc = rejectCell {
            drawBox(&ctx, single(rc), size, FG.bad, opacity: 1, fill: false, dashed: true)
        }

        // Number labels on their anchor cubes, back-to-front so nearer ones sit on top.
        let clueOrder = spec.clues.indices.sorted {
            depth(cellCenter(spec.clues[$0].x, spec.clues[$0].y, spec.clues[$0].z))
                < depth(cellCenter(spec.clues[$1].x, spec.clues[$1].y, spec.clues[$1].z))
        }
        for idx in clueOrder {
            let c = spec.clues[idx]
            let p = project(cellCenter(c.x, c.y, c.z), size)
            let r: CGFloat = 13
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                     with: .color(.black.opacity(0.5)))
            if activeClue == idx {
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                           with: .color(.white), lineWidth: 2)
            }
            ctx.draw(Text("\(c.n)").font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white), at: p)
        }
    }

    private func single(_ c: (Int, Int, Int)) -> Box3 {
        Box3(x0: c.0, x1: c.0, y0: c.1, y1: c.1, z0: c.2, z1: c.2)
    }

    private func drawBox(_ ctx: inout GraphicsContext, _ b: Box3, _ size: CGSize,
                         _ tint: Color, opacity: Double, fill: Bool, dashed: Bool) {
        let xr = [wb(b.x0, spec.nx), wb(b.x1 + 1, spec.nx)]
        let yr = [wb(b.y0, spec.ny), wb(b.y1 + 1, spec.ny)]
        let zr = [wb(b.z0, spec.nz), wb(b.z1 + 1, spec.nz)]
        func corner(_ i: Int, _ j: Int, _ k: Int) -> V3 { V3(x: xr[i], y: yr[j], z: zr[k]) }
        let faces: [[(Int, Int, Int)]] = [
            [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)],
            [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)],
            [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
            [(0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1)],
            [(0, 0, 0), (0, 1, 0), (0, 1, 1), (0, 0, 1)],
            [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)],
        ]
        let sorted = faces.sorted { f1, f2 in
            let d1 = f1.reduce(0.0) { $0 + depth(corner($1.0, $1.1, $1.2)) }
            let d2 = f2.reduce(0.0) { $0 + depth(corner($1.0, $1.1, $1.2)) }
            return d1 < d2
        }
        for f in sorted {
            let pts = f.map { project(corner($0.0, $0.1, $0.2), size) }
            var poly = Path(); poly.move(to: pts[0]); for k in 1..<4 { poly.addLine(to: pts[k]) }; poly.closeSubpath()
            if fill { ctx.fill(poly, with: .color(tint.opacity(opacity))) }
            let strokeOpacity = fill ? min(1, opacity + 0.4) : opacity
            ctx.stroke(poly, with: .color(tint.opacity(strokeOpacity)),
                       style: StrokeStyle(lineWidth: fill ? 1.2 : (dashed ? 2.0 : 1.0), dash: dashed ? [4, 4] : []))
        }
    }
}

// MARK: - Grid-lined sphere stage

private struct SphereFillView: View {
    let stageLabel: String
    let onComplete: () -> Void
    let onLevelSelect: () -> Void

    private let nLat = 4
    private let nLon = 6
    // Anchored numbers (lat band i, lon sector j, volume n) — spread over the globe.
    private let clues: [(i: Int, j: Int, n: Int)] = [
        (0, 0, 4), (0, 3, 4), (1, 1, 4), (2, 4, 4), (3, 2, 4), (3, 5, 4),
    ]
    private var totalCells: Int { nLat * nLon }

    @State private var owner: [Int: Int] = [:]
    @State private var activeClue = 0
    @State private var rejectCell: Int? = nil
    @State private var angleX = 0.5
    @State private var angleY = 0.7
    @State private var baseX = 0.5
    @State private var baseY = 0.7
    @State private var dragging = false
    @State private var solved = false
    @State private var started = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack(alignment: .top) {
                FG.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 60).padding(.bottom, 6)
                    Text("Tap a number to select it, then tap sectors to fill its volume. Drag to spin the sphere.")
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20).padding(.bottom, 4)
                    boardArea.frame(maxWidth: .infinity).frame(height: h * 0.56)
                    palette.padding(.top, 8)
                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                Button(action: reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .position(x: w - 34, y: 54)
            }
            .onAppear { if !started { started = true; seedAnchors() } }
        }
    }

    private var header: some View {
        VStack(spacing: 7) {
            Text(stageLabel)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4).foregroundStyle(Color.mathGold.opacity(0.85))
            Text("FILL THE SPHERE")
                .font(.trajan(30))
                .tracking(4).foregroundStyle(Color.mathGold.opacity(0.95))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 24)
    }

    private var palette: some View {
        HStack(spacing: 9) {
            ForEach(clues.indices, id: \.self) { idx in
                let n = clues[idx].n
                let cnt = count(idx)
                let sel = activeClue == idx
                let done = cnt == n
                Button { activeClue = idx } label: {
                    VStack(spacing: 1) {
                        Text("\(n)").font(.system(size: 17, weight: .bold, design: .rounded))
                        Text("\(cnt)/\(n)").font(.system(size: 9, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(sel ? .black : .white.opacity(0.92))
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(FG.tint(idx).opacity(sel ? 1 : 0.26)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(done ? FG.good : FG.tint(idx), lineWidth: sel ? 0 : 1.6))
                    .overlay(alignment: .topTrailing) {
                        if done { Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(FG.good).padding(2) }
                    }
                    .scaleEffect(sel ? 1.05 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: activeClue)
    }

    private var boardArea: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in draw(&ctx, size) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            if !dragging { dragging = true; baseX = angleX; baseY = angleY }
                            angleY = baseY + Double(v.translation.width) * 0.011
                            angleX = max(-1.3, min(1.3, baseX + Double(v.translation.height) * 0.011))
                        }
                        .onEnded { v in
                            dragging = false
                            if hypot(v.translation.width, v.translation.height) < 10 { handleTap(v.location, size) }
                        }
                )
        }
    }

    // MARK: Sphere math

    private func sphere(_ lat: Double, _ lon: Double) -> V3 {
        V3(x: cos(lat) * cos(lon), y: sin(lat), z: cos(lat) * sin(lon))
    }
    private func latEdge(_ i: Int) -> Double { -Double.pi / 2 + Double.pi * Double(i) / Double(nLat) }
    private func lonEdge(_ j: Int) -> Double { 2 * Double.pi * Double(j) / Double(nLon) }
    private func cellCorners(_ i: Int, _ j: Int) -> [V3] {
        [sphere(latEdge(i), lonEdge(j)), sphere(latEdge(i), lonEdge(j + 1)),
         sphere(latEdge(i + 1), lonEdge(j + 1)), sphere(latEdge(i + 1), lonEdge(j))]
    }
    private func cellCenter(_ i: Int, _ j: Int) -> V3 {
        sphere((latEdge(i) + latEdge(i + 1)) / 2, (lonEdge(j) + lonEdge(j + 1)) / 2)
    }
    private func cellIndex(_ i: Int, _ j: Int) -> Int { i * nLon + j }
    private func decode(_ k: Int) -> (Int, Int) { (k / nLon, k % nLon) }
    private func centerOf(_ idx: Int) -> V3 { let d = decode(idx); return cellCenter(d.0, d.1) }

    private func rotated(_ p: V3) -> V3 {
        let a = angleX, b = angleY
        let y1 = p.y * cos(a) - p.z * sin(a)
        let z1 = p.y * sin(a) + p.z * cos(a)
        let x2 = p.x * cos(b) + z1 * sin(b)
        let z2 = -p.x * sin(b) + z1 * cos(b)
        return V3(x: x2, y: y1, z: z2)
    }
    private func project(_ p: V3, _ size: CGSize) -> CGPoint {
        let s = Double(min(size.width, size.height)) * 0.34
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        let camera = 6.0
        let r = rotated(p)
        let f = camera / (camera - r.z)
        return CGPoint(x: cx + r.x * f * s, y: cy - r.y * f * s)
    }
    private func depth(_ p: V3) -> Double { rotated(p).z }   // >0 = front (facing viewer)

    private func silhouette(_ size: CGSize) -> (CGPoint, CGFloat) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        var maxR: CGFloat = 0
        for k in 0..<36 {
            let p = project(sphere(0, 2 * Double.pi * Double(k) / 36), size)
            maxR = max(maxR, hypot(p.x - c.x, p.y - c.y))
        }
        for s in [-1.0, 1.0] {
            let p = project(sphere(s * Double.pi / 2, 0), size)
            maxR = max(maxR, hypot(p.x - c.x, p.y - c.y))
        }
        return (c, maxR)
    }

    // MARK: Cells

    private func count(_ idx: Int) -> Int { owner.values.reduce(0) { $1 == idx ? $0 + 1 : $0 } }
    private func anchorAt(_ i: Int, _ j: Int) -> Int? { clues.firstIndex { $0.i == i && $0.j == j } }
    private func seedAnchors() { for (idx, c) in clues.enumerated() { owner[cellIndex(c.i, c.j)] = idx } }

    private func pickCell(_ loc: CGPoint, _ size: CGSize) -> Int? {
        let (c, maxR) = silhouette(size)
        guard hypot(loc.x - c.x, loc.y - c.y) <= maxR * 1.05 else { return nil }
        var best: Int? = nil
        var bestD = Double.infinity
        for i in 0..<nLat { for j in 0..<nLon where depth(cellCenter(i, j)) > 0 {
            let p = project(cellCenter(i, j), size)
            let d = Double(hypot(loc.x - p.x, loc.y - p.y))
            if d < bestD { bestD = d; best = cellIndex(i, j) }
        } }
        return best
    }

    // MARK: Interaction

    private func handleTap(_ loc: CGPoint, _ size: CGSize) {
        guard !solved, let idx = pickCell(loc, size) else { return }
        let (i, j) = decode(idx)
        if let a = anchorAt(i, j) { activeClue = a; return }
        if let o = owner[idx] {
            if o == activeClue { owner[idx] = nil }
            return
        }
        if count(activeClue) < clues[activeClue].n {
            owner[idx] = activeClue
            if owner.count == totalCells { finish() }
        } else {
            reject(idx)
        }
    }

    private func reject(_ idx: Int) {
        HapticPlayer.playLightTap()
        rejectCell = idx
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if rejectCell == idx { rejectCell = nil } }
    }

    private func finish() {
        solved = true
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { onComplete() }
    }

    private func reset() { owner = [:]; seedAnchors(); activeClue = 0; rejectCell = nil; solved = false }

    // MARK: Drawing

    // A filled cell is a solid wedge from the centre to the surface (6 triangles:
    // the outer curved patch + four radial cut faces). This makes fills read as
    // orange-slice volumes rather than flat surface patches.
    private func wedgeTris(_ i: Int, _ j: Int) -> [[V3]] {
        let o = cellCorners(i, j)
        let a = V3(x: 0, y: 0, z: 0)
        return [
            [o[0], o[1], o[2]], [o[0], o[2], o[3]],                 // outer patch
            [a, o[0], o[1]], [a, o[1], o[2]], [a, o[2], o[3]], [a, o[3], o[0]],   // cut faces
        ]
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let (c, maxR) = silhouette(size)

        // Empty-cell grid on the whole (glassy) sphere — back lines dimmer.
        for i in 0..<nLat { for j in 0..<nLon where owner[cellIndex(i, j)] == nil {
            let front = depth(cellCenter(i, j)) > 0
            let pts = cellCorners(i, j).map { project($0, size) }
            var poly = Path(); poly.move(to: pts[0]); for k in 1..<pts.count { poly.addLine(to: pts[k]) }; poly.closeSubpath()
            ctx.stroke(poly, with: .color(.white.opacity(front ? 0.26 : 0.07)), lineWidth: 1)
        } }

        // Filled wedges as translucent volumes, all triangles sorted back-to-front.
        var tris: [(d: Double, pts: [CGPoint], col: Color)] = []
        for i in 0..<nLat { for j in 0..<nLon {
            guard let o = owner[cellIndex(i, j)] else { continue }
            let col = FG.tint(o)
            for t in wedgeTris(i, j) {
                let d = (depth(t[0]) + depth(t[1]) + depth(t[2])) / 3
                tris.append((d, t.map { project($0, size) }, col))
            }
        } }
        tris.sort { $0.d < $1.d }
        for t in tris {
            var poly = Path(); poly.move(to: t.pts[0]); for k in 1..<t.pts.count { poly.addLine(to: t.pts[k]) }; poly.closeSubpath()
            ctx.fill(poly, with: .color(t.col))                              // solid, occludes what's behind
            let lit = max(0.0, min(1.0, t.d + 0.5))                          // front faces bright, sides/back darker
            let dark = (1 - lit) * 0.45
            if dark > 0.01 { ctx.fill(poly, with: .color(.black.opacity(dark))) }
            ctx.stroke(poly, with: .color(.black.opacity(0.22)), lineWidth: 0.6)
        }

        // Refused sector (outer patch, red dashed).
        if let rc = rejectCell, depth(centerOf(rc)) > 0 {
            let (i, j) = decode(rc)
            let pts = cellCorners(i, j).map { project($0, size) }
            var poly = Path(); poly.move(to: pts[0]); for k in 1..<pts.count { poly.addLine(to: pts[k]) }; poly.closeSubpath()
            ctx.stroke(poly, with: .color(FG.bad), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
        }

        // Crisp limb.
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - maxR, y: c.y - maxR, width: maxR * 2, height: maxR * 2)),
                   with: .color(.white.opacity(0.22)), lineWidth: 1.5)

        // Numbers on their (near-side) anchor sectors.
        for (idx, cl) in clues.enumerated() where depth(cellCenter(cl.i, cl.j)) > 0 {
            let p = project(cellCenter(cl.i, cl.j), size)
            let r: CGFloat = 12
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                     with: .color(.black.opacity(0.55)))
            if activeClue == idx {
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                           with: .color(.white), lineWidth: 2)
            }
            ctx.draw(Text("\(cl.n)").font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white), at: p)
        }
    }
}

#Preview {
    MathItLevelNinetySixView(onContinue: {}, onLevelSelect: {})
}
