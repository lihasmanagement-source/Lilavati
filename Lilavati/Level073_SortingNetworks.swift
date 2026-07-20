import SwiftUI

// MARK: - Level 92 · Bitonic Sort (interactive, two stages)
//
// Drag a vertical line between two track dots to place a comparator, then press
// Play. Tokens flow left→right; at each comparator the two tracks compare and
// swap so the smaller value rides higher. Sort to 1·2·3·…, twice:
//   Stage 1 — 4 tracks, start 3·4·1·2
//   Stage 2 — 5 tracks, start 5·2·4·1·3

struct MathItLevelNinetyTwoView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        BitonicSortView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, BS.accent)
    }
}

// MARK: - Palette

private enum BS {
    static let bg     = Color(red: 0.04, green: 0.05, blue: 0.10)
    static let track  = Color(red: 0.62, green: 0.45, blue: 0.95)
    static let node   = Color(red: 0.70, green: 0.58, blue: 0.98)
    static let accent = Color(red: 0.40, green: 0.85, blue: 0.95)
    static let column = Color(red: 0.35, green: 0.55, blue: 0.70)
    static let label  = Color(red: 0.95, green: 0.96, blue: 0.98)

    static func tile(_ v: Int) -> Color {
        switch v {
        case 1: return Color(red: 0.30, green: 0.78, blue: 0.42)   // green
        case 2: return Color(red: 0.95, green: 0.72, blue: 0.25)   // gold
        case 3: return Color(red: 0.28, green: 0.55, blue: 0.95)   // blue
        case 4: return Color(red: 0.62, green: 0.40, blue: 0.92)   // purple
        default: return Color(red: 0.92, green: 0.35, blue: 0.45)  // red (5)
        }
    }
}

// MARK: - Stage config

private struct SortStage {
    let tracks: Int
    let start: [Int]
    let cols: Int
    var goal: [Int] { Array(1...tracks) }
}

private let kStage1 = SortStage(tracks: 4, start: [3, 4, 1, 2], cols: 5)
private let kStage2 = SortStage(tracks: 5, start: [5, 2, 4, 1, 3], cols: 6)

// MARK: - View

private struct BitonicSortView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private let snapR: CGFloat = 34

    @State private var stage = 1
    @State private var comparators: [Int: (a: Int, b: Int)] = [:]   // keyed by column 1…cols
    @State private var arrangements: [[Int]] = []
    @State private var step = 0
    @State private var playing = false
    @State private var completed = false

    @State private var dragAnchor: (col: Int, track: Int)? = nil
    @State private var dragPoint: CGPoint? = nil

    private var cfg: SortStage { stage == 1 ? kStage1 : kStage2 }

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height

            ZStack(alignment: .top) {
                BS.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        .padding(.bottom, 14)

                    network
                        .frame(maxWidth: .infinity)
                        .frame(height: h * 0.44)

                    orderStrip
                        .padding(.top, 16)

                    controlRow
                        .padding(.top, 18)

                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Sorted",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: restart,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .onAppear { if arrangements.isEmpty { rebuild() } }
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
        }
        .padding(.horizontal, 24)
    }

    // MARK: Network + interaction

    private var network: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let xs = columnXs(w)
            let ys = trackYs(h)
            let tile = min((ys[1] - ys[0]) * 0.72, 50)

            ZStack {
                Canvas { ctx, _ in drawNetwork(&ctx, xs: xs, ys: ys, width: w) }

                ForEach(1...cfg.tracks, id: \.self) { v in
                    let tr = arrangements.isEmpty ? (cfg.start.firstIndex(of: v) ?? 0)
                                                  : (arrangements[step].firstIndex(of: v) ?? 0)
                    tokenTile(v, size: tile)
                        .position(x: xs[step], y: ys[tr])
                        .animation(.easeInOut(duration: 0.55), value: step)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in onChanged(v, xs: xs, ys: ys) }
                    .onEnded { v in onEnded(v, xs: xs, ys: ys) }
            )
        }
    }

    /// Token rest positions / comparator dots. Index 0 is the entry; comparators
    /// live on columns 1…cols, each aligned to a track dot.
    private func columnXs(_ w: CGFloat) -> [CGFloat] {
        let xStart = w * 0.12, xEnd = w * 0.82
        return (0...cfg.cols).map { xStart + (xEnd - xStart) * CGFloat($0) / CGFloat(cfg.cols) }
    }

    private func trackYs(_ h: CGFloat) -> [CGFloat] {
        let top = h * 0.14, bottom = h * 0.86
        return (0..<cfg.tracks).map { top + (bottom - top) * CGFloat($0) / CGFloat(cfg.tracks - 1) }
    }

    private func drawNetwork(_ ctx: inout GraphicsContext, xs: [CGFloat], ys: [CGFloat], width: CGFloat) {
        let xRight = width * 0.92

        // Tracks + arrowheads
        for y in ys {
            var line = Path()
            line.move(to: CGPoint(x: xs[0], y: y)); line.addLine(to: CGPoint(x: xRight, y: y))
            ctx.stroke(line, with: .color(BS.track.opacity(0.5)), lineWidth: 2.5)
            var head = Path()
            head.move(to: CGPoint(x: xRight, y: y)); head.addLine(to: CGPoint(x: xRight - 12, y: y - 7))
            head.move(to: CGPoint(x: xRight, y: y)); head.addLine(to: CGPoint(x: xRight - 12, y: y + 7))
            ctx.stroke(head, with: .color(BS.track.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }

        // Empty comparator columns — dashed verticals aligned on the dot columns
        for col in 1...cfg.cols where comparators[col] == nil {
            let x = xs[col]
            var v = Path()
            v.move(to: CGPoint(x: x, y: ys.first! - 18)); v.addLine(to: CGPoint(x: x, y: ys.last! + 18))
            ctx.stroke(v, with: .color(BS.column.opacity(0.28)),
                       style: StrokeStyle(lineWidth: 1.4, dash: [5, 6]))
        }

        // Track dots at every checkpoint
        for x in xs { for y in ys {
            ctx.fill(Path(ellipseIn: CGRect(x: x - 4.5, y: y - 4.5, width: 9, height: 9)),
                     with: .color(BS.node.opacity(0.85)))
        } }

        // Placed comparators — solid cyan, sitting on the dots
        for (col, pair) in comparators {
            let x = xs[col], ya = ys[pair.a], yb = ys[pair.b]
            var line = Path(); line.move(to: CGPoint(x: x, y: ya)); line.addLine(to: CGPoint(x: x, y: yb))
            ctx.stroke(line, with: .color(BS.accent), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            for y in [ya, yb] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14)),
                         with: .color(BS.accent))
            }
        }

        // Drag preview
        if let anchor = dragAnchor, let dp = dragPoint {
            let x = xs[anchor.col], ya = ys[anchor.track]
            var line = Path(); line.move(to: CGPoint(x: x, y: ya)); line.addLine(to: dp)
            ctx.stroke(line, with: .color(BS.accent.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 5]))
        }
    }

    private func tokenTile(_ v: Int, size: CGFloat) -> some View {
        let color = BS.tile(v)
        return Text("\(v)")
            .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.24)
                .fill(LinearGradient(colors: [color, color.opacity(0.72)],
                                     startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: size * 0.24).stroke(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: color.opacity(0.6), radius: 6)
    }

    // MARK: Order strip

    private var orderStrip: some View {
        let current = arrangements.isEmpty ? cfg.start : arrangements[min(step, arrangements.count - 1)]
        return VStack(spacing: 10) {
            HStack(spacing: 9) {
                ForEach(Array(current.enumerated()), id: \.offset) { _, v in
                    Text("\(v)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 8).fill(BS.tile(v)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
            .animation(.easeInOut(duration: 0.55), value: step)

            HStack(spacing: 6) {
                Text("GOAL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(2)
                    .foregroundStyle(.white.opacity(0.45))
                ForEach(cfg.goal, id: \.self) { v in
                    Text("\(v)").font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(BS.tile(v))
                }
            }
        }
    }

    // MARK: Controls

    private var controlRow: some View {
        HStack(spacing: 16) {
            Button(action: restart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 50, height: 48)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: play) {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 150, height: 48)
                    .background(BS.accent.opacity(playing ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(playing)
        }
    }

    // MARK: Editing

    private func onChanged(_ v: DragGesture.Value, xs: [CGFloat], ys: [CGFloat]) {
        guard !playing, !completed else { return }
        if dragAnchor == nil { dragAnchor = nearestNode(v.startLocation, xs: xs, ys: ys) }
        guard dragAnchor != nil else { return }
        dragPoint = v.location
    }

    private func onEnded(_ v: DragGesture.Value, xs: [CGFloat], ys: [CGFloat]) {
        defer { dragAnchor = nil; dragPoint = nil }
        guard !playing, !completed, let a = dragAnchor else { return }
        let moved = hypot(v.translation.width, v.translation.height)

        if let b = nearestNode(v.location, xs: xs, ys: ys), b.col == a.col, b.track != a.track {
            comparators[a.col] = (min(a.track, b.track), max(a.track, b.track))
            rebuild()
        } else if moved < 12, comparators[a.col] != nil {
            comparators[a.col] = nil   // tap to remove
            rebuild()
        }
    }

    private func nearestNode(_ p: CGPoint, xs: [CGFloat], ys: [CGFloat]) -> (col: Int, track: Int)? {
        var best: (Int, Int)? = nil
        var bestD = snapR
        for col in 1...cfg.cols {
            for t in 0..<cfg.tracks {
                let d = hypot(p.x - xs[col], p.y - ys[t])
                if d <= bestD { bestD = d; best = (col, t) }
            }
        }
        return best.map { (col: $0.0, track: $0.1) }
    }

    // MARK: Simulation

    private func rebuild() {
        var arr = cfg.start
        var out = [arr]
        for col in 1...cfg.cols {
            if let pair = comparators[col], arr[pair.a] > arr[pair.b] { arr.swapAt(pair.a, pair.b) }
            out.append(arr)
        }
        arrangements = out
        step = 0
    }

    private func play() {
        guard !playing else { return }
        rebuild()
        playing = true
        advance()
    }

    private func advance() {
        if step < cfg.cols {
            withAnimation(.easeInOut(duration: 0.55)) { step += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { advance() }
        } else if arrangements.last == cfg.goal {
            if stage == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { advanceStage() }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut(duration: 0.5)) { completed = true }
                }
            }
        } else {
            // Not sorted — rewind so the player can adjust.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.5)) { step = 0 }
                playing = false
            }
        }
    }

    private func advanceStage() {
        withAnimation(.easeInOut(duration: 0.35)) { stage = 2 }
        comparators = [:]
        playing = false
        rebuild()
    }

    private func restart() {
        completed = false
        playing = false
        dragAnchor = nil
        dragPoint = nil
        stage = 1
        comparators = [:]
        rebuild()
    }
}

#Preview {
    MathItLevelNinetyTwoView(onContinue: {}, onLevelSelect: {})
}
