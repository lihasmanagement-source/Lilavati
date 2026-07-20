import SwiftUI

// MARK: - Level 43 · Binary Relay (logic gates per row, 3 stages)
//
// Two binary grids A and B are given. Place a logic gate — AND, OR, or XOR — on
// each row; the row's result is A[row] · gate · B[row]. Choose the right gate for
// every row so the combined result matches the target image. Each row is
// generated so at least one gate works, so the puzzle is always solvable.

enum Gate: CaseIterable, Equatable {
    case none, and, or, xor

    var glyph: String {
        switch self {
        case .none: return "–"
        case .and: return "&"
        case .or: return "|"
        case .xor: return "^"
        }
    }
    var next: Gate {
        switch self {
        case .none: return .and
        case .and: return .or
        case .or: return .xor
        case .xor: return .none
        }
    }
}

@Observable
final class MathItLevelFortyThreeViewModel {
    let stageCount = 3
    var size: Int { target.count }

    // Stage 1: 2×2, stage 2: 4×4, stage 3: 6×6.
    private let stageTargets: [[[Int]]] = [
        [[1, 0], [0, 1]],
        [[1, 1, 1, 1], [1, 0, 0, 0], [1, 1, 1, 0], [1, 0, 0, 0]],
        [[0, 1, 0, 0, 1, 0], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1],
         [0, 1, 1, 1, 1, 0], [0, 0, 1, 1, 0, 0], [0, 0, 0, 0, 0, 0]]
    ]

    var stage = 0
    var target: [[Int]] = []
    var a: [[Int]] = []
    var b: [[Int]] = []
    var gates: [Gate] = []
    var solved = false
    var completed = false

    init() { loadStage(0) }

    func loadStage(_ i: Int) {
        stage = i
        solved = false
        target = stageTargets[min(i, stageTargets.count - 1)]
        gates = Array(repeating: .none, count: target.count)
        generateOperands()
    }

    func resultRow(_ r: Int) -> [Int] {
        guard a.indices.contains(r), b.indices.contains(r), gates.indices.contains(r) else {
            return Array(repeating: 0, count: size)
        }
        return combine(a[r], b[r], gates[r])
    }

    var result: [[Int]] { (0..<size).map { resultRow($0) } }

    func cycleGate(_ r: Int) {
        guard !solved, !completed, gates.indices.contains(r) else { return }
        gates[r] = gates[r].next
        HapticPlayer.playLightTap()
        if result == target { reveal() }
    }

    private func reveal() {
        solved = true
        HapticPlayer.playCompletionTap()
        if stage == stageCount - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { self.completed = true }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.loadStage(self.stage + 1)   // structural resize — no animation
            }
        }
    }

    private func combine(_ x: [Int], _ y: [Int], _ g: Gate) -> [Int] {
        switch g {
        case .none: return Array(repeating: 0, count: x.count)
        case .and: return zip(x, y).map { $0 & $1 }
        case .or: return zip(x, y).map { $0 | $1 }
        case .xor: return zip(x, y).map { $0 ^ $1 }
        }
    }

    // Build A and B so a chosen gate reproduces each target row exactly.
    private func generateOperands() {
        let pool: [Gate] = [.and, .or, .xor]
        var newA: [[Int]] = []
        var newB: [[Int]] = []
        for r in 0..<size {
            let t = target[r]
            let g = pool[r % 3]
            var ar = Array(repeating: 0, count: size)
            var br = Array(repeating: 0, count: size)
            for c in 0..<size {
                switch g {
                case .xor:
                    br[c] = Int.random(in: 0...1)
                    ar[c] = t[c] ^ br[c]
                case .and:
                    if t[c] == 1 { ar[c] = 1; br[c] = 1 }
                    else {
                        switch Int.random(in: 0...2) { case 1: ar[c] = 1; case 2: br[c] = 1; default: break }
                    }
                case .or:
                    if t[c] == 1 {
                        switch Int.random(in: 0...2) { case 0: ar[c] = 1; case 1: br[c] = 1; default: ar[c] = 1; br[c] = 1 }
                    }
                default: break
                }
            }
            newA.append(ar)
            newB.append(br)
        }
        a = newA
        b = newB
    }
}

struct MathItLevelFortyThreeView: View {
    var viewModel: MathItLevelFortyThreeViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let green = Color.mathItLogic

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let resultCell: CGFloat = viewModel.size <= 2 ? 50 : (viewModel.size <= 4 ? 40 : 32)

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect).position(x: 34, y: 54).zIndex(20)

                VStack(spacing: 8) {
                    EmptyView()
                        .font(.trajan(32))
                        .foregroundStyle(green.opacity(viewModel.completed ? 1 : 0.85))
                }
                .position(x: size.width / 2, y: 74)

                // Operand + target references.
                HStack(spacing: 16) {
                    miniGrid(viewModel.a, label: "A")
                    miniGrid(viewModel.b, label: "B")
                    miniGrid(viewModel.target, label: "TARGET")
                }
                .position(x: size.width / 2, y: 156)

                // Gate column + result grid.
                HStack(spacing: 10) {
                    VStack(spacing: 3) {
                        ForEach(Array(0..<viewModel.size), id: \.self) { r in
                            gateButton(r, height: resultCell)
                        }
                    }
                    resultGrid(cell: resultCell)
                        .animation(.easeInOut(duration: 0.22), value: viewModel.gates)
                }
                .id(viewModel.stage)
                .position(x: size.width / 2, y: size.height * 0.53)

                Text("&  A and B      |  A or B      ^  A xor B")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: size.width / 2, y: size.height * 0.78)

                CompletionOverlay(
                    title: "Level 43 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
    }

    // MARK: Pieces

    private func gateButton(_ r: Int, height: CGFloat) -> some View {
        let g = viewModel.gates[safeRow: r]
        let active = g != Gate.none
        return Button {
            viewModel.cycleGate(r)
        } label: {
            Text(g.glyph)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(active ? .black : green.opacity(0.7))
                .frame(width: 34, height: height)
                .background(RoundedRectangle(cornerRadius: 6).fill(active ? green : green.opacity(0.08)))
                .overlay { RoundedRectangle(cornerRadius: 6).stroke(green.opacity(0.5), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.solved || viewModel.completed)
    }

    private func resultGrid(cell: CGFloat) -> some View {
        VStack(spacing: 3) {
            ForEach(Array(0..<viewModel.size), id: \.self) { r in
                let row = viewModel.resultRow(r)
                HStack(spacing: 3) {
                    ForEach(Array(0..<viewModel.size), id: \.self) { c in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(row[c] == 1 ? green : .white.opacity(0.05))
                            .frame(width: cell, height: cell)
                            .overlay { RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.06), lineWidth: 1) }
                            .shadow(color: row[c] == 1 ? green.opacity(0.5) : .clear, radius: 3)
                    }
                }
            }
        }
    }

    private func miniGrid(_ g: [[Int]], label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(green.opacity(0.7))
            VStack(spacing: 1) {
                ForEach(g.indices, id: \.self) { r in
                    HStack(spacing: 1) {
                        ForEach(g[r].indices, id: \.self) { c in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(g[r][c] == 1 ? green.opacity(0.9) : .white.opacity(0.06))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
    }
}

private extension Array where Element == Gate {
    subscript(safeRow index: Int) -> Gate {
        indices.contains(index) ? self[index] : .none
    }
}
