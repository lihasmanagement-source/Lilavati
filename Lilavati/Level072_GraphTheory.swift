import SwiftUI

// MARK: - Level 90 · Knight's Tour (interactive)
//
// Tap a square a legal L-move away to hop the knight there. Visit every square
// exactly once to complete the tour. The numeral toggle reveals the solution
// order as a hint; an illegal tap flashes red and the knight returns. Each
// legal move is logged as a coordinate below the board.

struct MathItLevelNinetyView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        KnightsTourView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, KT.accent)
    }
}

// MARK: - Palette

private enum KT {
    static let bg     = Color(red: 0.04, green: 0.05, blue: 0.10)
    static let board  = Color(red: 0.09, green: 0.11, blue: 0.19)
    static let cell   = Color(red: 0.13, green: 0.16, blue: 0.26)
    static let line   = Color(red: 0.78, green: 0.66, blue: 0.42)
    static let accent = Color(red: 0.93, green: 0.80, blue: 0.46)
    static let trail  = Color(red: 0.66, green: 0.52, blue: 0.95)
    static let knight = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let bad    = Color(red: 0.92, green: 0.32, blue: 0.30)
}

private struct Cell: Equatable, Hashable { var r: Int; var c: Int }

// MARK: - Tour data (one config per stage)

private struct BoardConfig {
    let n: Int
    let path: [Cell]           // a valid open tour; also defines the hint order
    let order: [Cell: Int]

    var start: Cell { path[0] }

    init(n: Int, path: [Cell]) {
        self.n = n
        self.path = path
        var d: [Cell: Int] = [:]
        for (i, cell) in path.enumerated() { d[cell] = i + 1 }
        self.order = d
    }
}

private enum Tour {
    static func isMove(_ a: Cell, _ b: Cell) -> Bool {
        let dr = abs(a.r - b.r), dc = abs(a.c - b.c)
        return (dr == 1 && dc == 2) || (dr == 2 && dc == 1)
    }

    static let stage1 = BoardConfig(n: 5, path: [
        Cell(r:0,c:0), Cell(r:1,c:2), Cell(r:0,c:4), Cell(r:2,c:3), Cell(r:4,c:4),
        Cell(r:3,c:2), Cell(r:4,c:0), Cell(r:2,c:1), Cell(r:0,c:2), Cell(r:1,c:0),
        Cell(r:3,c:1), Cell(r:4,c:3), Cell(r:2,c:4), Cell(r:0,c:3), Cell(r:1,c:1),
        Cell(r:3,c:0), Cell(r:4,c:2), Cell(r:3,c:4), Cell(r:1,c:3), Cell(r:0,c:1),
        Cell(r:2,c:0), Cell(r:4,c:1), Cell(r:2,c:2), Cell(r:1,c:4), Cell(r:3,c:3)
    ])

    static let stage2 = BoardConfig(n: 8, path: [
        Cell(r:0,c:0), Cell(r:1,c:2), Cell(r:0,c:4), Cell(r:1,c:6), Cell(r:3,c:7), Cell(r:5,c:6), Cell(r:7,c:7), Cell(r:6,c:5),
        Cell(r:5,c:7), Cell(r:7,c:6), Cell(r:6,c:4), Cell(r:7,c:2), Cell(r:6,c:0), Cell(r:4,c:1), Cell(r:2,c:0), Cell(r:0,c:1),
        Cell(r:1,c:3), Cell(r:0,c:5), Cell(r:1,c:7), Cell(r:2,c:5), Cell(r:0,c:6), Cell(r:2,c:7), Cell(r:4,c:6), Cell(r:6,c:7),
        Cell(r:7,c:5), Cell(r:6,c:3), Cell(r:7,c:1), Cell(r:5,c:0), Cell(r:3,c:1), Cell(r:1,c:0), Cell(r:0,c:2), Cell(r:2,c:1),
        Cell(r:4,c:0), Cell(r:5,c:2), Cell(r:7,c:3), Cell(r:6,c:1), Cell(r:4,c:2), Cell(r:3,c:0), Cell(r:1,c:1), Cell(r:0,c:3),
        Cell(r:2,c:2), Cell(r:1,c:4), Cell(r:3,c:3), Cell(r:5,c:4), Cell(r:3,c:5), Cell(r:2,c:3), Cell(r:4,c:4), Cell(r:3,c:2),
        Cell(r:5,c:1), Cell(r:7,c:0), Cell(r:6,c:2), Cell(r:4,c:3), Cell(r:2,c:4), Cell(r:3,c:6), Cell(r:1,c:5), Cell(r:0,c:7),
        Cell(r:2,c:6), Cell(r:3,c:4), Cell(r:5,c:3), Cell(r:4,c:5), Cell(r:6,c:6), Cell(r:4,c:7), Cell(r:5,c:5), Cell(r:7,c:4)
    ])
}

// MARK: - View

private struct KnightsTourView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stage = 1
    @State private var pos: Cell = Cell(r: 0, c: 0)          // logical position
    @State private var knightDisplay: Cell = Cell(r: 0, c: 0) // rendered position
    @State private var visited: [Cell] = [Cell(r: 0, c: 0)]
    @State private var badCell: Cell? = nil
    @State private var showNumbers = false
    @State private var interactive = false
    @State private var completed = false

    private var config: BoardConfig { stage == 1 ? Tour.stage1 : Tour.stage2 }
    private var start: Cell { config.start }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let side = min(w - 48, h * 0.46)

            ZStack(alignment: .top) {
                KT.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        .padding(.bottom, 18)

                    board(side: side)
                        .frame(width: side, height: side)

                    pathLog
                        .padding(.horizontal, 28)
                        .padding(.top, 16)

                    controlRow
                        .padding(.top, 14)

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Tour Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .onAppear { runDemo() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 7) {
            Text("STAGE \(stage)/2")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))
            EmptyView()
                .font(.trajan(34))
                .tracking(7)
                .foregroundStyle(Color.mathGold.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("Visit every square exactly once")
                .font(.garamond(15))
                .foregroundStyle(.white.opacity(0.7))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Board

    private func board(side: CGFloat) -> some View {
        let n = config.n
        let pad: CGFloat = 6
        let cs = (side - pad * 2) / CGFloat(n)
        func center(_ cell: Cell) -> CGPoint {
            CGPoint(x: pad + (CGFloat(cell.c) + 0.5) * cs,
                    y: pad + (CGFloat(cell.r) + 0.5) * cs)
        }

        return ZStack {
            RoundedRectangle(cornerRadius: 14).fill(KT.board)
            RoundedRectangle(cornerRadius: 14).stroke(KT.line.opacity(0.55), lineWidth: 1.5)

            // Cells (tappable)
            ForEach(0..<(n * n), id: \.self) { i in
                let cell = Cell(r: i / n, c: i % n)
                cellView(cell, size: cs)
                    .position(center(cell))
                    .onTapGesture { tap(cell) }
            }

            // Trail — drawn above the tiles so the line is never broken
            Canvas { ctx, _ in
                guard visited.count > 1 else { return }
                var p = Path()
                p.move(to: center(visited[0]))
                for cell in visited.dropFirst() { p.addLine(to: center(cell)) }
                ctx.stroke(p, with: .color(KT.trail.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                ctx.stroke(p, with: .color(KT.trail),
                           style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
            }
            .allowsHitTesting(false)

            // Knight marker
            Text("\u{265E}")
                .font(.system(size: cs * 0.58))
                .foregroundStyle(KT.knight)
                .shadow(color: .black.opacity(0.55), radius: 3)
                .position(center(knightDisplay))
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.34), value: knightDisplay)
        }
    }

    private func cellView(_ cell: Cell, size cs: CGFloat) -> some View {
        let isVisited = visited.contains(cell)
        let isBad = badCell == cell
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isBad ? KT.bad.opacity(0.55)
                            : (isVisited ? KT.trail.opacity(0.16) : KT.cell))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(KT.line.opacity(0.18), lineWidth: 1))

            if showNumbers, let n = config.order[cell] {
                Text("\(n)")
                    .font(.garamond(cs * 0.34))
                    .foregroundStyle(KT.accent.opacity(isVisited ? 0.45 : 0.85))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: cs - 4, height: cs - 4)
        .animation(.easeInOut(duration: 0.2), value: isBad)
    }

    // MARK: Coordinate log

    private var pathLog: some View {
        ScrollViewReader { sp in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Text(pathString)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity)
                    Color.clear.frame(height: 1).id("end")
                }
            }
            .frame(maxHeight: 78)
            .onChange(of: visited) {
                withAnimation { sp.scrollTo("end", anchor: .bottom) }
            }
        }
    }

    private var pathString: AttributedString {
        var s = AttributedString()
        for (i, cell) in visited.enumerated() {
            var token = AttributedString(coordLabel(cell))
            token.foregroundColor = (i == visited.count - 1) ? KT.accent : .white.opacity(0.42)
            s += token
            if i < visited.count - 1 {
                var sep = AttributedString(" · ")
                sep.foregroundColor = .white.opacity(0.22)
                s += sep
            }
        }
        return s
    }

    private func coordLabel(_ cell: Cell) -> String {
        let cols = ["A", "B", "C", "D", "E", "F", "G", "H"]
        return "\(cols[cell.c])\(cell.r + 1)"
    }

    // MARK: Controls

    private var controlRow: some View {
        HStack(spacing: 14) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showNumbers.toggle() } } label: {
                Image(systemName: "list.number")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(showNumbers ? .black : KT.accent)
                    .frame(width: 50, height: 44)
                    .background(showNumbers ? KT.accent : .white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(KT.accent.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: reset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 50, height: 44)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Logic

    private func isLegal(_ cell: Cell) -> Bool {
        Tour.isMove(pos, cell) && !visited.contains(cell)
    }

    private func tap(_ cell: Cell) {
        guard interactive, !completed, cell != pos else { return }

        if isLegal(cell) {
            visited.append(cell)
            pos = cell
            withAnimation(.easeInOut(duration: 0.34)) { knightDisplay = cell }
            if visited.count == config.n * config.n {
                if stage == 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { advanceStage() }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) { completed = true }
                    }
                }
            }
        } else {
            // Illegal: flash the square red and bounce the knight back.
            badCell = cell
            withAnimation(.easeInOut(duration: 0.16)) { knightDisplay = cell }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeInOut(duration: 0.26)) { knightDisplay = pos }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) { badCell = nil }
            }
        }
    }

    private func reset() {
        completed = false
        interactive = false
        showNumbers = false
        badCell = nil
        stage = 1
        visited = [Tour.stage1.start]
        pos = Tour.stage1.start
        knightDisplay = Tour.stage1.start
        runDemo()
    }

    /// Stage 1 cleared → load the 8×8 board and continue.
    private func advanceStage() {
        interactive = false
        showNumbers = false
        badCell = nil
        withAnimation(.easeInOut(duration: 0.35)) { stage = 2 }
        let s = Tour.stage2.start
        visited = [s]
        pos = s
        knightDisplay = s
        runDemo()
    }

    /// Demonstrate one L-move at the start, then return and hand over control.
    private func runDemo() {
        let demo = Cell(r: 1, c: 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.6)) { knightDisplay = demo }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.6)) { knightDisplay = start }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            interactive = true
        }
    }
}

#Preview {
    MathItLevelNinetyView(onContinue: {}, onLevelSelect: {})
}
