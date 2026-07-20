import SwiftUI

struct MathItExponentialGrowthLegacyView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stage       = 1
    @State private var bacteria: [GCell: CGFloat] = [GCell(0, 4): 1]
    @State private var invalidCell: GCell? = nil
    @State private var completed   = false
    @State private var busy        = false
    @State private var gridOpacity: CGFloat = 1
    @State private var stageBannerVisible = false

    // Hearts
    @State private var hearts      = 3
    @State private var shakeHearts = false
    @State private var dyingOut    = false   // true while fading after 0 hearts

    private var n: Int           { stage == 1 ? 5 : 6 }
    private var startCell: GCell { stage == 1 ? GCell(0, 4) : GCell(0, 5) }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 0) {
                    header
                        .padding(.top, 48)

                    Spacer()

                    let side = min(proxy.size.width - 36, proxy.size.height * 0.58)
                    latticeGrid(side: side)
                        .frame(width: side, height: side)
                        .opacity(gridOpacity)

                    Spacer()

                    bottomBar
                        .padding(.bottom, 40)
                }

                if stageBannerVisible {
                    stageBanner.transition(.opacity).zIndex(10)
                }

                CompletionOverlay(
                    title: "Level 84 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetToStageOne,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.45))

            EmptyView()
                .font(.trajan(28))
                .tracking(5)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Stage pips + hearts on the same row
            HStack(spacing: 0) {
                // Stage pips (left-aligned)
                HStack(spacing: 7) {
                    ForEach(1...2, id: \.self) { s in
                        Capsule()
                            .fill(s == stage
                                  ? Color.mathItLogic
                                  : Color.mathItLogic.opacity(0.22))
                            .frame(width: s == stage ? 22 : 8, height: 4)
                            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: stage)
                    }
                }

                Spacer()

                // Hearts (right-aligned)
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < hearts ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(
                                i < hearts
                                    ? Color(red: 1, green: 0.28, blue: 0.32)
                                    : .white.opacity(0.18)
                            )
                            .shadow(
                                color: i < hearts
                                    ? Color(red: 1, green: 0.28, blue: 0.32).opacity(0.55)
                                    : .clear,
                                radius: 6
                            )
                            .scaleEffect(i < hearts ? 1 : 0.85)
                            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: hearts)
                    }
                }
                .offset(x: shakeHearts ? -6 : 0)
                .animation(
                    shakeHearts
                        ? .spring(response: 0.12, dampingFraction: 0.3)
                        : .spring(response: 0.22, dampingFraction: 0.8),
                    value: shakeHearts
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 6)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Grid

    private func latticeGrid(side: CGFloat) -> some View {
        let cellSize = side / CGFloat(n)

        return ZStack {
            ForEach(0...n, id: \.self) { i in
                let offset = CGFloat(i) * cellSize
                Path { p in
                    p.move(to: CGPoint(x: offset, y: 0))
                    p.addLine(to: CGPoint(x: offset, y: side))
                }
                .stroke(.white.opacity(0.11), lineWidth: 1)

                Path { p in
                    p.move(to: CGPoint(x: 0, y: offset))
                    p.addLine(to: CGPoint(x: side, y: offset))
                }
                .stroke(.white.opacity(0.11), lineWidth: 1)
            }

            ForEach(sortedCells, id: \.self) { cell in
                BacteriumDot(isInvalid: invalidCell == cell)
                    .frame(width: cellSize * 0.54, height: cellSize * 0.54)
                    .scaleEffect(bacteria[cell] ?? 0)
                    .position(cellCenter(cell, cellSize: cellSize))
                    .animation(.spring(response: 0.30, dampingFraction: 0.60), value: bacteria[cell])
                    .onTapGesture { handleTap(cell) }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.012, green: 0.016, blue: 0.022))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.10), lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Stage banner

    private var stageBanner: some View {
        ZStack {
            Color.black.opacity(0.76).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("STAGE 1 COMPLETE")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color.mathItLogic.opacity(0.8))
                Text("6 × 6")
                    .font(.trajan(52))
                    .tracking(8)
                    .foregroundStyle(.white.opacity(0.9))
                Text("GRID UNLOCKED")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.mathItLogic)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.mathItLogic.opacity(0.7), radius: 5)
                Text("\(liveCellCount)")
                    .font(.system(size: 22, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: liveCellCount)
                Text("bacteria")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.leading, 3)
            }

            Spacer()

            Button(action: resetCurrentStage) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 40)
                    .background(.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(accent.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Helpers

    private var sortedCells: [GCell] {
        bacteria.keys.sorted { a, b in a.row == b.row ? a.col < b.col : a.row < b.row }
    }

    private var liveCellCount: Int {
        bacteria.values.filter { $0 > 0.5 }.count
    }

    private func cellCenter(_ cell: GCell, cellSize: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(cell.col) + 0.5) * cellSize,
                y: (CGFloat(cell.row) + 0.5) * cellSize)
    }

    // MARK: - Split logic

    private func canSplit(_ cell: GCell) -> Bool {
        guard cell.row > 0, cell.col < n - 1 else { return false }
        return bacteria[GCell(cell.col, cell.row - 1)] == nil
            && bacteria[GCell(cell.col + 1, cell.row)] == nil
    }

    private func handleTap(_ cell: GCell) {
        guard !busy, !completed, !stageBannerVisible, !dyingOut else { return }
        guard (bacteria[cell] ?? 0) > 0.5 else { return }

        guard canSplit(cell) else {
            penaliseInvalidTap(cell)
            return
        }

        busy = true

        let above = GCell(cell.col,     cell.row - 1)
        let right = GCell(cell.col + 1, cell.row)

        withAnimation(.spring(response: 0.20, dampingFraction: 0.72)) {
            bacteria[cell] = 0
        }
        bacteria[above] = 0
        bacteria[right] = 0
        withAnimation(.spring(response: 0.36, dampingFraction: 0.56).delay(0.10)) {
            bacteria[above] = 1
            bacteria[right] = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            bacteria.removeValue(forKey: cell)
            busy = false
            checkStageCompletion()
        }
    }

    // MARK: - Hearts

    private func penaliseInvalidTap(_ cell: GCell) {
        // Flash the cell red
        invalidCell = cell
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { invalidCell = nil }

        // Shake the hearts row
        shakeHearts = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { shakeHearts = false }

        // Decrement
        withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) {
            hearts = max(0, hearts - 1)
        }

        if hearts - 1 <= 0 {
            // Small extra delay so the last heart empties visibly before reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                triggerDeathReset()
            }
        }
    }

    private func triggerDeathReset() {
        dyingOut = true
        // Fade out the whole grid
        withAnimation(.easeInOut(duration: 0.4)) { gridOpacity = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Hard-reset state
            stage       = 1
            bacteria    = [:]
            invalidCell = nil
            completed   = false
            hearts      = 3

            // Re-plant starting bacterium off-screen (scale 0), then pop in
            bacteria[GCell(0, 4)] = 0
            withAnimation(.easeInOut(duration: 0.38)) { gridOpacity = 1 }
            withAnimation(.spring(response: 0.40, dampingFraction: 0.60).delay(0.20)) {
                bacteria[GCell(0, 4)] = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { dyingOut = false }
        }
    }

    // MARK: - Stage completion

    private func checkStageCompletion() {
        let anyMove = bacteria.keys.contains {
            (bacteria[$0] ?? 0) > 0.5 && canSplit($0)
        }
        guard !anyMove else { return }

        if stage == 1 {
            advanceToStageTwo()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.4)) { completed = true }
            }
        }
    }

    private func advanceToStageTwo() {
        busy = true
        withAnimation(.easeInOut(duration: 0.35)) { gridOpacity = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeInOut(duration: 0.28)) { stageBannerVisible = true }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.28)) { stageBannerVisible = false }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    stage = 2
                    bacteria = [GCell(0, 5): 0]
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.62)) {
                        bacteria[GCell(0, 5)] = 1
                    }
                    withAnimation(.easeInOut(duration: 0.38)) { gridOpacity = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { busy = false }
                }
            }
        }
    }

    // MARK: - Reset

    private func resetCurrentStage() {
        guard !stageBannerVisible, !dyingOut else { return }
        busy = false
        invalidCell = nil
        withAnimation(.easeInOut(duration: 0.22)) {
            for k in bacteria.keys { bacteria[k] = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            bacteria = [:]
            bacteria[startCell] = 0
            withAnimation(.spring(response: 0.38, dampingFraction: 0.60)) {
                bacteria[startCell] = 1
            }
        }
    }

    private func resetToStageOne() {
        busy        = false
        invalidCell = nil
        completed   = false
        stage       = 1
        hearts      = 3
        bacteria    = [:]
        bacteria[GCell(0, 4)] = 0
        withAnimation(.spring(response: 0.38, dampingFraction: 0.60)) {
            bacteria[GCell(0, 4)] = 1
        }
    }
}

// MARK: - Bacterium dot

private struct BacteriumDot: View {
    let isInvalid: Bool
    private var col: Color { isInvalid ? Color(red: 1, green: 0.26, blue: 0.26) : .mathItLogic }

    var body: some View {
        ZStack {
            Circle().fill(col.opacity(0.18)).scaleEffect(1.6)
            Circle()
                .fill(RadialGradient(
                    colors: [col.opacity(0.95), col.opacity(0.70)],
                    center: .topLeading, startRadius: 0, endRadius: 18))
                .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1))
        }
        .shadow(color: col.opacity(0.70), radius: 8)
        .animation(.easeInOut(duration: 0.14), value: isInvalid)
    }
}

// MARK: - Grid coordinate

private struct GCell: Hashable {
    let col: Int, row: Int
    init(_ col: Int, _ row: Int) { self.col = col; self.row = row }
}
