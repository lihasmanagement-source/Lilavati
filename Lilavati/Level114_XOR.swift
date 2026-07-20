import SwiftUI

enum NimDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }
}

enum NimTurn {
    case player
    case cpu
}

@Observable
final class MathItLevelSevenViewModel {
    var rows = [1, 3, 5, 7]
    var aliveIds: [[Int]] = [Array(0..<1), Array(0..<3), Array(0..<5), Array(0..<7)]
    var selectedRow: Int?
    var selectedIds: Set<Int> = []              // multiple matches, all within selectedRow
    var dragStartIndex: Int?                     // anchor position for swipe-to-select a range
    var removingRow: Int?                        // row currently animating out on commit
    var removingIds: Set<Int> = []
    var difficulty: NimDifficulty = .medium
    var gameStarted = false                      // locks difficulty once the first match is picked
    var turn: NimTurn = .player
    var message = "Choose one row."
    var resultTitle: String?
    var stageResolved = false
    var levelComplete = false
    var cpuThinking = false
    var lastMove: (row: Int, count: Int, wasCPU: Bool)?
    var resultPulse = false
    var cpuRemoval: (row: Int, count: Int)?
    var cpuTrashFlash = false

    var canPlayerMove: Bool {
        turn == .player && !stageResolved && !cpuThinking && cpuRemoval == nil && removingRow == nil
    }

    /// Rebuild the stable-id lists to match the current row counts.
    func setupIfNeeded() {
        if aliveIds.count != rows.count || zip(aliveIds, rows).contains(where: { $0.count != $1 }) {
            aliveIds = rows.map { Array(0..<$0) }
        }
    }

    func reset() {
        rows = [1, 3, 5, 7]
        aliveIds = rows.map { Array(0..<$0) }
        selectedRow = nil
        selectedIds = []
        dragStartIndex = nil
        removingRow = nil
        removingIds = []
        gameStarted = false
        turn = .player
        message = "Choose matches from one row."
        resultTitle = nil
        stageResolved = false
        levelComplete = false
        cpuThinking = false
        lastMove = nil
        resultPulse = false
        cpuRemoval = nil
        cpuTrashFlash = false
    }

    /// Tap a match to toggle it. Tapping in a different row clears the old selection
    /// (you can only ever have matches from ONE row selected at a time).
    func choose(row: Int, id: Int) {
        guard canPlayerMove, aliveIds.indices.contains(row), aliveIds[row].contains(id) else { return }
        gameStarted = true
        if selectedRow != row {
            selectedRow = row
            selectedIds = [id]
        } else if selectedIds.contains(id) {
            selectedIds.remove(id)
            if selectedIds.isEmpty { selectedRow = nil }
        } else {
            selectedIds.insert(id)
        }
        updateSelectionMessage()
        HapticPlayer.playLightTap()
    }

    /// Swipe across a row to select a contiguous range of matches within that row.
    func dragSelect(row: Int, toPosition position: Int) {
        guard canPlayerMove, aliveIds.indices.contains(row), !aliveIds[row].isEmpty else { return }
        gameStarted = true
        let clamped = min(max(position, 0), aliveIds[row].count - 1)
        if selectedRow != row || dragStartIndex == nil {
            selectedRow = row
            dragStartIndex = clamped
        }
        let lo = min(dragStartIndex!, clamped)
        let hi = max(dragStartIndex!, clamped)
        selectedIds = Set(aliveIds[row][lo...hi])
        updateSelectionMessage()
    }

    func endDragSelection() {
        dragStartIndex = nil
    }

    private func updateSelectionMessage() {
        if let row = selectedRow, !selectedIds.isEmpty {
            let n = selectedIds.count
            message = "Remove \(n) match\(n == 1 ? "" : "es") from row \(row + 1)."
        } else {
            message = "Choose matches from one row."
        }
    }

    func commitPlayerMove() {
        guard canPlayerMove, let row = selectedRow, !selectedIds.isEmpty,
              aliveIds.indices.contains(row) else { return }
        let ids = selectedIds
        let count = ids.count
        guard count > 0 else { return }

        // Animate exactly the selected matches out, then apply the removal.
        removingRow = row
        removingIds = ids
        dragStartIndex = nil
        HapticPlayer.playLightTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            self.removingRow = nil
            self.removingIds = []
            self.applyMove(row: row, count: count, wasCPU: false, removedIds: ids)
        }
    }

    func performCPUMove() {
        guard turn == .cpu, !stageResolved, !cpuThinking else { return }
        cpuThinking = true
        message = "CPU is thinking..."

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            let move = self.cpuMove()
            self.animateCPUMove(row: move.row, count: move.count)
        }
    }

    func advanceAfterWin() {
        guard resultTitle == "You Win" else { return }
        levelComplete = true
    }

    private func applyMove(row: Int, count: Int, wasCPU: Bool, removedIds: Set<Int>? = nil) {
        guard aliveIds.indices.contains(row) else { return }
        if let ids = removedIds {
            aliveIds[row].removeAll { ids.contains($0) }          // player: exact matches
        } else {
            aliveIds[row].removeLast(min(count, aliveIds[row].count))   // CPU: from the end
        }
        rows[row] = aliveIds[row].count
        selectedRow = nil
        selectedIds = []
        dragStartIndex = nil
        cpuRemoval = nil
        cpuTrashFlash = false
        lastMove = (row, count, wasCPU)
        HapticPlayer.playLightTap()

        if rows.allSatisfy({ $0 == 0 }) {
            stageResolved = true
            resultTitle = wasCPU ? "You Lose" : "You Win"
            message = wasCPU ? "CPU took the last match." : "You took the last match."
            resultPulse = true
            HapticPlayer.playCompletionTap()
            return
        }

        turn = wasCPU ? .player : .cpu
        message = wasCPU ? "Your turn. Choose one row." : "CPU turn."
    }

    private func animateCPUMove(row: Int, count: Int) {
        guard rows.indices.contains(row), count > 0, count <= rows[row] else {
            cpuThinking = false
            return
        }

        cpuRemoval = (row, count)
        cpuTrashFlash = false
        HapticPlayer.playLightTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard self.cpuRemoval?.row == row, self.cpuRemoval?.count == count else { return }
            self.cpuTrashFlash = true
            HapticPlayer.playLightTap()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            guard self.cpuRemoval?.row == row, self.cpuRemoval?.count == count else { return }
            self.cpuThinking = false
            self.applyMove(row: row, count: count, wasCPU: true)
        }
    }

    private func cpuMove() -> (row: Int, count: Int) {
        switch difficulty {
        case .easy:
            return randomMove()
        case .medium:
            if Double.random(in: 0...1) < 0.28 {
                return randomMove()
            }
            return mediumMove()
        case .hard:
            return optimalNimMove()
        }
    }

    private func randomMove() -> (row: Int, count: Int) {
        let validRows = rows.indices.filter { rows[$0] > 0 }
        guard let row = validRows.randomElement() else { return (0, 0) }
        return (row, Int.random(in: 1...rows[row]))
    }

    private func mediumMove() -> (row: Int, count: Int) {
        let nonZeroRows = rows.indices.filter { rows[$0] > 0 }
        if nonZeroRows.count == 1, let row = nonZeroRows.first {
            return (row, max(rows[row] - 1, 1))
        }

        if let safeMove = immediateSafeMove() {
            return safeMove
        }

        let row = rows.indices.max { rows[$0] < rows[$1] } ?? 0
        let target = rows[row] > 3 ? 3 : 1
        return (row, max(rows[row] - target, 1))
    }

    private func immediateSafeMove() -> (row: Int, count: Int)? {
        for row in rows.indices where rows[row] > 0 {
            for count in 1...rows[row] {
                var next = rows
                next[row] -= count
                if next.allSatisfy({ $0 == 0 }) {
                    continue
                }
                if next.filter({ $0 > 0 }).count == 1, next.reduce(0, +) == 1 {
                    continue
                }
                return (row, count)
            }
        }
        return nil
    }

    private func optimalNimMove() -> (row: Int, count: Int) {
        let xorValue = rows.reduce(0, ^)
        if xorValue == 0 {
            return randomMove()
        }

        for row in rows.indices where rows[row] > 0 {
            let target = rows[row] ^ xorValue
            if target < rows[row] {
                return (row, rows[row] - target)
            }
        }

        return randomMove()
    }
}

struct MathItLevelSevenView: View {
    var viewModel: MathItLevelSevenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    @State private var lossShakeTrigger = 0
    @State private var lossFlash = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 20) {
                    EmptyView()
                        .font(.trajan(34))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.levelComplete ? 1 : 0.55))

                    difficultyPicker
                    movePanel
                    board
                }
                .padding(.horizontal, 22)
                .padding(.top, 64)
                .padding(.bottom, 96)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .modifier(MathItLevelSevenShakeEffect(trigger: CGFloat(lossShakeTrigger)))

                Color.red
                    .opacity(lossFlash ? 0.28 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                CompletionOverlay(
                    title: "XOR Mastered",
                    isVisible: viewModel.levelComplete,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
            }
            .onAppear { viewModel.setupIfNeeded() }
            .onChange(of: viewModel.turn) { _, turn in
                if turn == .cpu {
                    viewModel.performCPUMove()
                }
            }
            .onChange(of: viewModel.resultTitle) { _, result in
                guard let result else { return }
                if result == "You Win" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                        viewModel.advanceAfterWin()
                    }
                } else {
                    lossFlash = true
                    withAnimation(.linear(duration: 0.48)) {
                        lossShakeTrigger += 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                        withAnimation(.easeOut(duration: 0.22)) {
                            lossFlash = false
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                        viewModel.reset()
                    }
                }
            }
        }
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(NimDifficulty.allCases) { difficulty in
                Button {
                    guard !viewModel.gameStarted, viewModel.turn == .player, !viewModel.stageResolved else { return }
                    viewModel.difficulty = difficulty
                    HapticPlayer.playLightTap()
                } label: {
                    Text(difficulty.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(viewModel.difficulty == difficulty ? .black : Color.mathGold)
                        .frame(width: 82, height: 34)
                        .background(viewModel.difficulty == difficulty ? Color.mathGold : .clear, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.mathGold.opacity(0.7), lineWidth: 1.2)
                        }
                }
                .disabled(viewModel.gameStarted)
            }
        }
        .opacity(viewModel.gameStarted ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.25), value: viewModel.gameStarted)
    }

    private var board: some View {
        VStack(spacing: 42) {
            ForEach(viewModel.rows.indices, id: \.self) { row in
                matchRow(row)
            }
        }
        .padding(.top, 18)
        .frame(maxHeight: .infinity, alignment: .center)
        .scaleEffect(viewModel.resultPulse ? 1.03 : 1)
        .opacity(viewModel.stageResolved ? 0.48 : 1)
    }

    private func matchRow(_ row: Int) -> some View {
        GeometryReader { proxy in
            let ids = viewModel.aliveIds.indices.contains(row) ? viewModel.aliveIds[row] : []
            let count = ids.count
            let spacing = matchSpacing(for: count, availableWidth: proxy.size.width)
            let clusterWidth = matchClusterWidth(for: count, spacing: spacing)

            HStack {
                Spacer(minLength: 0)

                HStack(spacing: spacing) {
                    ForEach(Array(ids.enumerated()), id: \.element) { position, mid in
                        matchstick(row: row, position: position, id: mid)
                    }
                }
                .frame(width: clusterWidth, height: 68, alignment: .leading)
                .animation(.spring(response: 0.34, dampingFraction: 0.82), value: count)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            updateSelection(row: row, xLocation: value.location.x, spacing: spacing)
                        }
                        .onEnded { _ in
                            viewModel.endDragSelection()
                        }
                )

                Spacer(minLength: 0)
            }
        }
        .frame(height: 82)
    }

    private func matchstick(row: Int, position: Int, id: Int) -> some View {
        let playerSelected = viewModel.selectedRow == row && viewModel.selectedIds.contains(id)
        let cpuRemovalCount = viewModel.cpuRemoval?.row == row ? (viewModel.cpuRemoval?.count ?? 0) : 0
        let aliveCount = viewModel.aliveIds.indices.contains(row) ? viewModel.aliveIds[row].count : 0
        let cpuSelected = cpuRemovalCount > 0 && position >= aliveCount - cpuRemovalCount
        let selected = playerSelected || cpuSelected
        let removing = viewModel.removingRow == row && viewModel.removingIds.contains(id)
        let tilt = Double(((row * 7 + id * 5) % 9) - 4)
        let yDrift = CGFloat(((row * 3 + id * 2) % 7) - 3)

        return VStack(spacing: 0) {
            Circle()
                .fill(selected ? Color.mathGold : Color(red: 1.0, green: 0.36, blue: 0.24))
                .frame(width: 12, height: 12)

            Capsule()
                .fill(selected ? Color.mathGold.opacity(0.82) : .white.opacity(0.82))
                .frame(width: 8, height: 48)
        }
        .frame(width: 12, height: 60)
        .opacity(removing ? 0.0 : 1)
        .scaleEffect(removing ? 0.5 : (selected ? 1.08 : 1))
        .rotationEffect(.degrees(selected ? 0 : tilt))
        .offset(y: removing ? -22 : (selected ? -3 : yDrift))
        .shadow(color: (cpuSelected || playerSelected) ? Color.mathGold.opacity(0.72) : .clear, radius: 14)
        .animation(.easeInOut(duration: 0.18), value: selected)
        .animation(.easeIn(duration: 0.3), value: removing)
        .onTapGesture {
            viewModel.choose(row: row, id: id)
        }
    }

    private var movePanel: some View {
        ZStack {
            Button {
                viewModel.commitPlayerMove()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(trashLit ? .black : .white.opacity(0.34))
                    .frame(width: 62, height: 62)
                    .background(trashLit ? Color.mathGold : .white.opacity(0.08), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(viewModel.cpuTrashFlash ? Color.mathGold.opacity(0.72) : .white.opacity(0.16), lineWidth: 1.2)
                    }
                    .shadow(color: viewModel.cpuTrashFlash ? Color.mathGold.opacity(0.78) : .clear, radius: 16)
            }
            .disabled(!canCommit)
        }
        .animation(.easeInOut(duration: 0.18), value: trashLit)
    }

    private var canCommit: Bool {
        viewModel.canPlayerMove && viewModel.selectedRow != nil && !viewModel.selectedIds.isEmpty
    }

    private var trashLit: Bool {
        canCommit || viewModel.cpuTrashFlash
    }

    private func matchSpacing(for count: Int, availableWidth: CGFloat) -> CGFloat {
        guard count > 1 else { return 0 }

        let targetWidth = availableWidth * (count <= 3 ? 0.72 : 0.9)
        let naturalSpacing = (targetWidth - CGFloat(count) * 12) / CGFloat(count - 1)
        return min(max(naturalSpacing, 30), 58)
    }

    private func matchClusterWidth(for count: Int, spacing: CGFloat) -> CGFloat {
        guard count > 0 else { return 12 }
        return CGFloat(count) * 12 + CGFloat(max(count - 1, 0)) * spacing
    }

    private func updateSelection(row: Int, xLocation: CGFloat, spacing: CGFloat) {
        guard viewModel.canPlayerMove, viewModel.rows[row] > 0 else { return }

        let matchPitch = 12 + spacing
        let position = Int((xLocation + matchPitch / 2) / matchPitch)
        viewModel.dragSelect(row: row, toPosition: position)
    }

}

private struct MathItLevelSevenShakeEffect: GeometryEffect {
    var trigger: CGFloat

    var animatableData: CGFloat {
        get { trigger }
        set { trigger = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = sin(trigger * .pi * 10) * 10
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
