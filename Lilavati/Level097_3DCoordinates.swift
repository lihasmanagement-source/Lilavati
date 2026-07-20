import SwiftUI

// MARK: - 3D Coordinates through Tic-Tac-Toe (vs. computer)
//
// Nine separated mini-cubes float in a 3×3 grid you can orbit by dragging. Tap
// an empty block to claim it — yours turns blue with an ✕ on all six sides, the
// computer's turns red with an ◯ on all six sides. Claim three blocks in a line
// (row, column, or diagonal) to win.

struct MathItLevelNinetyThreeView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        CubeView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, CB.accent)
    }
}

// MARK: - Palette

private enum CB {
    static let bg     = Color(red: 0.04, green: 0.05, blue: 0.10)
    static let accent = Color(red: 0.52, green: 0.72, blue: 1.0)
    static let edge   = Color(red: 0.86, green: 0.90, blue: 1.0)
    static let empty  = Color(red: 0.60, green: 0.66, blue: 0.80)
    static let player = Color(red: 0.24, green: 0.52, blue: 0.96)   // blue (✕)
    static let cpu    = Color(red: 0.94, green: 0.34, blue: 0.34)   // red  (◯)
    static let mark   = Color(red: 0.97, green: 0.98, blue: 1.0)
    static let win    = Color(red: 0.40, green: 0.92, blue: 0.55)
}

// MARK: - Difficulty

private enum Difficulty: String, CaseIterable {
    case easy = "EASY", medium = "MEDIUM", hard = "HARD"

    /// Chance the computer blocks your imminent three-in-a-row.
    var blockChance: Double {
        switch self { case .easy: return 0.30; case .medium: return 0.70; case .hard: return 1.0 }
    }
    /// Whether it favours strong squares (center, corners) over random play.
    var strategic: Bool { self != .easy }
}

private enum CoordinateSelectionMode: String, CaseIterable {
    case cube = "CUBE"
    case coordinates = "COORDINATES"
}

// MARK: - 3D helpers

private struct V3 { var x: Double; var y: Double; var z: Double }

private func vsub(_ a: V3, _ b: V3) -> V3 { V3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
private func vadd(_ a: V3, _ b: V3) -> V3 { V3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
private func vscale(_ a: V3, _ s: Double) -> V3 { V3(x: a.x * s, y: a.y * s, z: a.z * s) }

private func rotated(_ p: V3, ax: Double, ay: Double) -> V3 {
    let cx = cos(ax), sx = sin(ax)
    let y1 = p.y * cx - p.z * sx
    let z1 = p.y * sx + p.z * cx
    let cy = cos(ay), sy = sin(ay)
    let x2 = p.x * cy + z1 * sy
    let z2 = -p.x * sy + z1 * cy
    return V3(x: x2, y: y1, z: z2)
}

// MARK: - 3×3×3 grid of separated mini-cubes

private enum Grid {
    static let n = 3
    static let count = 27
    static let spacing = 0.80
    static let h = 0.26            // mini-cube half-size (leaves a visible gap)

    static func index(_ x: Int, _ y: Int, _ z: Int) -> Int { x + y * 3 + z * 9 }

    static let centers: [V3] = {
        var out: [V3] = []
        for z in 0..<n { for y in 0..<n { for x in 0..<n {
            out.append(V3(x: Double(x - 1) * spacing,
                          y: Double(y - 1) * spacing,
                          z: Double(z - 1) * spacing))
        } } }
        return out
    }()

    static let offsets: [V3] = [
        V3(x: -h, y: -h, z: -h), V3(x: h, y: -h, z: -h),
        V3(x: h, y: h, z: -h),  V3(x: -h, y: h, z: -h),
        V3(x: -h, y: -h, z: h),  V3(x: h, y: -h, z: h),
        V3(x: h, y: h, z: h),   V3(x: -h, y: h, z: h),
    ]
    static let faces: [[Int]] = [
        [4, 5, 6, 7], [1, 0, 3, 2], [1, 2, 6, 5], [0, 4, 7, 3], [3, 7, 6, 2], [0, 1, 5, 4],
    ]

    /// Every straight line of three through the 3×3×3 (axes, face diagonals,
    /// and space diagonals) — 49 lines in all.
    static let winLines: [[Int]] = {
        func inb(_ v: Int) -> Bool { (0..<n).contains(v) }
        var set = Set<[Int]>()
        for x in 0..<n { for y in 0..<n { for z in 0..<n {
            for dx in -1...1 { for dy in -1...1 { for dz in -1...1 {
                if dx == 0 && dy == 0 && dz == 0 { continue }
                let xs = [x, x + dx, x + 2 * dx]
                let ys = [y, y + dy, y + 2 * dy]
                let zs = [z, z + dz, z + 2 * dz]
                if xs.allSatisfy(inb), ys.allSatisfy(inb), zs.allSatisfy(inb) {
                    let line = (0..<3).map { index(xs[$0], ys[$0], zs[$0]) }.sorted()
                    set.insert(line)
                }
            } } }
        } } }
        return Array(set)
    }()
}

private struct CubeCoordinateMove: Equatable {
    let cube: Int
    let owner: Int

    var x: Int { cube % 3 - 1 }
    var y: Int { (cube / 3) % 3 - 1 }
    var z: Int { cube / 9 - 1 }
    var triple: String { "(\(x), \(y), \(z))" }
}

// MARK: - View

private struct CubeView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var angleX = 0.42
    @State private var angleY = 0.30
    @State private var baseX = 0.42
    @State private var baseY = 0.30
    @State private var dragging = false

    @State private var board = Array(repeating: 0, count: Grid.count)   // 0 empty, 1 player, 2 cpu
    @State private var playerTurn = true
    @State private var winner = 0                              // 0 none, 1, 2, 3 draw
    @State private var winLine: [Int]? = nil
    @State private var completed = false
    @State private var difficulty: Difficulty = .medium
    @State private var twoPlayer = false        // pass-and-play: both sides are human
    @State private var moveHistory: [CubeCoordinateMove] = []
    @State private var selectionMode: CoordinateSelectionMode = .cube

    private var gameOver: Bool { winner != 0 }

    private var completionTitle: String {
        if twoPlayer {
            switch winner { case 1: return "Player 1 Wins"; case 2: return "Player 2 Wins"; default: return "Draw" }
        }
        return "3D Coordinates Complete"
    }

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height

            ZStack(alignment: .top) {
                CB.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 60)

                    cubeCanvas
                        .frame(maxWidth: .infinity)
                        .frame(height: h * (selectionMode == .coordinates ? 0.40 : 0.55))

                    statusRow.padding(.top, 6)

                    selectionModePicker.padding(.top, 8)

                    if selectionMode == .coordinates {
                        coordinateChart
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                    }

                    difficultyPicker.padding(.top, selectionMode == .coordinates ? 8 : 12)

                    Spacer(minLength: 0)
                }

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: completionTitle,
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: newGame,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        EmptyView()
    }

    // MARK: Status

    private var statusRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text(statusText)
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).tracking(1)
                    .foregroundStyle(statusColor)
                Button(action: newGame) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.06), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if moveHistory.isEmpty {
                            Text("(x, y, z)")
                                .foregroundStyle(.white.opacity(0.28))
                                .frame(height: 32)
                        } else {
                            ForEach(Array(moveHistory.enumerated()), id: \.offset) { index, move in
                                coordinateChip(move, number: index + 1)
                                    .id(index)
                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .onChange(of: moveHistory.count) { _, count in
                    guard count > 0 else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        scrollProxy.scrollTo(count - 1, anchor: .trailing)
                    }
                }
            }
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
    }

    private func coordinateChip(_ move: CubeCoordinateMove, number: Int) -> some View {
        let ownerColor = move.owner == 1 ? CB.player : CB.cpu
        return HStack(spacing: 6) {
            Text("\(number)")
                .foregroundStyle(.white.opacity(0.38))
            Text(moveOwnerLabel(move))
                .foregroundStyle(ownerColor)
            Text(move.triple)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(ownerColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(ownerColor.opacity(0.45), lineWidth: 1)
        }
    }

    private func moveOwnerLabel(_ move: CubeCoordinateMove) -> String {
        if twoPlayer { return move.owner == 1 ? "P1 ✕" : "P2 ◯" }
        return move.owner == 1 ? "YOU ✕" : "CPU ◯"
    }

    private var statusText: String {
        if twoPlayer {
            switch winner {
            case 1: return "PLAYER 1 WINS"
            case 2: return "PLAYER 2 WINS"
            case 3: return "DRAW"
            default: return playerTurn ? "PLAYER 1 — ✕" : "PLAYER 2 — ◯"
            }
        }
        switch winner {
        case 2: return "COMPUTER WINS"
        case 3: return "DRAW"
        default: return playerTurn ? "YOUR TURN" : "THINKING…"
        }
    }
    private var statusColor: Color {
        if twoPlayer {
            switch winner {
            case 1: return CB.player
            case 2: return CB.cpu
            case 3: return .white.opacity(0.7)
            default: return playerTurn ? CB.player : CB.cpu
            }
        }
        switch winner {
        case 2: return CB.cpu
        case 3: return .white.opacity(0.7)
        default: return playerTurn ? CB.player : .white.opacity(0.5)
        }
    }

    // MARK: Difficulty picker

    private var difficultyPicker: some View {
        HStack(spacing: 7) {
            ForEach(Difficulty.allCases, id: \.self) { d in
                pickerCapsule(d.rawValue, selected: !twoPlayer && difficulty == d) {
                    twoPlayer = false; difficulty = d; newGame()
                }
            }
            pickerCapsule("2P", selected: twoPlayer) { twoPlayer = true; newGame() }
        }
    }

    private func pickerCapsule(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1)
                .foregroundStyle(selected ? .black : .white.opacity(0.7))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(selected ? CB.accent : .white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(CB.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Selection mode + coordinate chart

    private var selectionModePicker: some View {
        HStack(spacing: 0) {
            modeButton(.cube, icon: "cube.transparent")
            modeButton(.coordinates, icon: "tablecells")
        }
        .padding(3)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
    }

    private func modeButton(_ mode: CoordinateSelectionMode, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectionMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(mode.rawValue)
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(selectionMode == mode ? CB.bg : .white.opacity(0.62))
            .padding(.horizontal, 11)
            .frame(height: 29)
            .background(selectionMode == mode ? CB.accent : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private var coordinateChart: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach([-1, 0, 1], id: \.self) { z in
                VStack(spacing: 4) {
                    Text("z = \(z)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(CB.accent)

                    ForEach([1, 0, -1], id: \.self) { y in
                        HStack(spacing: 3) {
                            ForEach([-1, 0, 1], id: \.self) { x in
                                coordinateButton(x: x, y: y, z: z)
                            }
                        }
                    }
                }
                .padding(5)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(CB.accent.opacity(0.22), lineWidth: 1)
                }
            }
        }
    }

    private func coordinateButton(x: Int, y: Int, z: Int) -> some View {
        let cube = Grid.index(x + 1, y + 1, z + 1)
        let owner = board[cube]
        let color = owner == 1 ? CB.player : owner == 2 ? CB.cpu : CB.empty

        return Button {
            claimCube(cube)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(owner == 0 ? color.opacity(0.08) : color.opacity(0.76))
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(owner == 0 ? 0.34 : 0.9), lineWidth: 1)
                Text("(\(x),\(y),\(z))")
                    .font(.system(size: 6.2, weight: .black, design: .monospaced))
                    .foregroundStyle(owner == 0 ? .white.opacity(0.68) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 25)
        }
        .buttonStyle(.plain)
        .disabled(owner != 0 || gameOver || (!twoPlayer && !playerTurn))
        .accessibilityLabel("x \(x), y \(y), z \(z)")
    }

    // MARK: Canvas + interaction

    private var cubeCanvas: some View {
        GeometryReader { geo in
            Canvas { ctx, size in draw(&ctx, size) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            if !dragging { dragging = true; baseX = angleX; baseY = angleY }
                            angleY = baseY + Double(v.translation.width) * 0.011
                            angleX = baseX + Double(v.translation.height) * 0.011
                        }
                        .onEnded { v in
                            dragging = false
                            if selectionMode == .cube,
                               hypot(v.translation.width, v.translation.height) < 10 {
                                handleTap(v.location, geo.size)
                            }
                        }
                )
        }
    }

    // MARK: Projection

    private func project(_ p: V3, _ size: CGSize) -> CGPoint {
        let s = Double(min(size.width, size.height)) * 0.30
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        let camera = 4.0
        let r = rotated(p, ax: angleX, ay: angleY)
        let f = camera / (camera - r.z)
        return CGPoint(x: cx + r.x * f * s, y: cy - r.y * f * s)
    }

    private func worldCorner(_ cube: Int, _ local: Int) -> V3 {
        vadd(Grid.centers[cube], Grid.offsets[local])
    }
    private func depth(_ p: V3) -> Double { rotated(p, ax: angleX, ay: angleY).z }

    // MARK: Drawing

    private struct FaceRef { let cube: Int; let face: Int; let d: Double }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        // Collect every face of every cube and sort globally back-to-front.
        var refs: [FaceRef] = []
        for cube in 0..<Grid.count {
            for face in 0..<6 {
                let idx = Grid.faces[face]
                let d = idx.reduce(0.0) { $0 + depth(worldCorner(cube, $1)) } / 4
                refs.append(FaceRef(cube: cube, face: face, d: d))
            }
        }
        refs.sort { $0.d < $1.d }

        for ref in refs {
            let idx = Grid.faces[ref.face]
            let A = worldCorner(ref.cube, idx[0])
            let u = vsub(worldCorner(ref.cube, idx[1]), A)
            let v = vsub(worldCorner(ref.cube, idx[3]), A)
            let owner = board[ref.cube]
            let near = max(0, min(1, (ref.d + 1.6) / 3.2))

            let quad = idx.map { project(worldCorner(ref.cube, $0), size) }
            var poly = Path()
            poly.move(to: quad[0]); for k in 1..<4 { poly.addLine(to: quad[k]) }; poly.closeSubpath()

            switch owner {
            case 1: ctx.fill(poly, with: .color(CB.player.opacity(0.55 + near * 0.40)))
            case 2: ctx.fill(poly, with: .color(CB.cpu.opacity(0.55 + near * 0.40)))
            default: ctx.fill(poly, with: .color(CB.empty.opacity(0.04 + near * 0.05)))
            }
            ctx.stroke(poly, with: .color(CB.edge.opacity(owner == 0 ? 0.28 : 0.75)),
                       style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))

            if owner != 0 { drawMark(&ctx, size, owner: owner, A: A, u: u, v: v) }
        }

        // Winning line through the three claimed cube centers
        if let line = winLine, let a = line.first, let b = line.last {
            var p = Path()
            p.move(to: project(Grid.centers[a], size))
            p.addLine(to: project(Grid.centers[b], size))
            ctx.stroke(p, with: .color(CB.win), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }

        drawAxisKey(&ctx, size)
    }

    private func drawAxisKey(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let origin = CGPoint(x: 38, y: size.height - 34)
        let axes: [(V3, String, Color)] = [
            (V3(x: 1, y: 0, z: 0), "x", CB.cpu),
            (V3(x: 0, y: 1, z: 0), "y", CB.win),
            (V3(x: 0, y: 0, z: 1), "z", CB.accent)
        ]

        for (axis, label, color) in axes {
            let vector = rotated(axis, ax: angleX, ay: angleY)
            let end = CGPoint(
                x: origin.x + CGFloat(vector.x) * 28,
                y: origin.y - CGFloat(vector.y) * 28
            )
            var line = Path()
            line.move(to: origin)
            line.addLine(to: end)
            ctx.stroke(line, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
            ctx.draw(
                Text(label).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(color),
                at: CGPoint(x: end.x + (end.x >= origin.x ? 7 : -7), y: end.y)
            )
        }
        ctx.fill(Path(ellipseIn: CGRect(x: origin.x - 3, y: origin.y - 3, width: 6, height: 6)), with: .color(.white))
    }

    private func drawMark(_ ctx: inout GraphicsContext, _ size: CGSize, owner: Int,
                          A: V3, u: V3, v: V3) {
        let center = vadd(A, vadd(vscale(u, 0.5), vscale(v, 0.5)))
        let hu = vscale(u, 0.30)   // inset half-extent within the face
        let hv = vscale(v, 0.30)

        if owner == 1 {   // ✕
            var x = Path()
            x.move(to: project(vadd(vadd(center, hu), hv), size))
            x.addLine(to: project(vsub(vsub(center, hu), hv), size))
            x.move(to: project(vadd(vsub(center, hu), hv), size))
            x.addLine(to: project(vsub(vadd(center, hu), hv), size))
            ctx.stroke(x, with: .color(CB.mark), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        } else {          // ◯
            var ring = Path()
            let steps = 18
            for k in 0...steps {
                let a = Double(k) / Double(steps) * 2 * .pi
                let pt = vadd(center, vadd(vscale(hu, cos(a)), vscale(hv, sin(a))))
                let sp = project(pt, size)
                if k == 0 { ring.move(to: sp) } else { ring.addLine(to: sp) }
            }
            ctx.stroke(ring, with: .color(CB.mark), style: StrokeStyle(lineWidth: 3))
        }
    }

    // MARK: Tap → claim

    private func handleTap(_ loc: CGPoint, _ size: CGSize) {
        guard !gameOver, twoPlayer || playerTurn else { return }
        let p0 = project(Grid.centers[0], size), p1 = project(Grid.centers[1], size)
        let radius = hypot(p0.x - p1.x, p0.y - p1.y) * 0.5

        // Among empty cubes near the tap, pick the front-most (nearest the camera).
        var bestI = -1
        var bestDepth = -Double.infinity
        for i in 0..<Grid.count where board[i] == 0 {
            let p = project(Grid.centers[i], size)
            if hypot(loc.x - p.x, loc.y - p.y) <= radius {
                let dz = depth(Grid.centers[i])
                if dz > bestDepth { bestDepth = dz; bestI = i }
            }
        }
        guard bestI >= 0 else { return }

        claimCube(bestI)
    }

    private func claimCube(_ cube: Int) {
        guard board.indices.contains(cube), board[cube] == 0,
              !gameOver, twoPlayer || playerTurn else { return }

        let mark = playerTurn ? 1 : 2
        withAnimation(.easeOut(duration: 0.15)) {
            board[cube] = mark
            let coordinateMove = CubeCoordinateMove(cube: cube, owner: mark)
            moveHistory.append(coordinateMove)
        }
        if resolve() { return }

        if twoPlayer {
            playerTurn.toggle()                       // hand the cube to the other player
        } else {
            playerTurn = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { computerMove() }
        }
    }

    // MARK: Computer

    private func computerMove() {
        guard !gameOver else { return }
        // Always grab an immediate win; how reliably it blocks and whether it
        // plays strong squares depends on the chosen difficulty.
        var move = winningMove(for: 2)
        if move == nil, Double.random(in: 0...1) < difficulty.blockChance { move = winningMove(for: 1) }
        let chosen = move ?? preferredMove(strategic: difficulty.strategic)
        if let m = chosen {
            withAnimation(.easeOut(duration: 0.15)) {
                board[m] = 2
                let coordinateMove = CubeCoordinateMove(cube: m, owner: 2)
                moveHistory.append(coordinateMove)
            }
        }
        _ = resolve()
        playerTurn = true
    }

    private func winningMove(for p: Int) -> Int? {
        for line in Grid.winLines {
            if line.map({ board[$0] }).filter({ $0 == p }).count == 2,
               let empty = line.first(where: { board[$0] == 0 }) { return empty }
        }
        return nil
    }

    private func preferredMove(strategic: Bool) -> Int? {
        let empty = (0..<Grid.count).filter { board[$0] == 0 }
        guard strategic else { return empty.randomElement() }   // easy: pure random

        let center = Grid.index(1, 1, 1)
        if board[center] == 0 { return center }
        // Corners of the 3×3×3 (all coords 0 or 2).
        let corners = empty.filter { i in
            let x = i % 3, y = (i / 3) % 3, z = i / 9
            return [x, y, z].allSatisfy { $0 == 0 || $0 == 2 }
        }
        if let c = corners.randomElement() { return c }
        return empty.randomElement()
    }

    // MARK: Resolution

    @discardableResult
    private func resolve() -> Bool {
        for line in Grid.winLines {
            let v = board[line[0]]
            if v != 0, board[line[1]] == v, board[line[2]] == v {
                winLine = line
                withAnimation(.easeInOut(duration: 0.3)) { winner = v }
                // Vs computer: only your win completes the level. In pass-and-play
                // either player's win ends the match.
                if v == 1 || twoPlayer { finishSoon() }
                return true
            }
        }
        if !board.contains(0) {
            withAnimation { winner = 3 }
            if twoPlayer { finishSoon() }
            return true
        }
        return false
    }

    private func finishSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 0.5)) { completed = true }
        }
    }

    private func newGame() {
        completed = false
        winner = 0
        winLine = nil
        playerTurn = true
        moveHistory = []
        board = Array(repeating: 0, count: Grid.count)
    }
}

#Preview {
    MathItLevelNinetyThreeView(onContinue: {}, onLevelSelect: {})
}
