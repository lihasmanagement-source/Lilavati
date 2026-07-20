import Combine
import SwiftUI

final class MathItLevelTwentyOneViewModel: ObservableObject {
    struct Stage {
        let expression: String
        let answer: Int
    }

    let stages: [Stage] = [
        Stage(expression: "7 + 8", answer: 15),
        Stage(expression: "54 + 39", answer: 93),
        Stage(expression: "10,346 + 743", answer: 11_089)
    ]

    @Published var stageIndex = 0
    @Published var rowCounts = Array(repeating: 0, count: 10)
    @Published var completed = false
    @Published var stageSolved = false
    @Published var pulseRows: Set<Int> = []
    @Published var carryingRows: Set<Int> = []

    private var isAdvancing = false
    private var isRegrouping = false

    var stage: Stage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var currentValue: Int {
        rowCounts.enumerated().reduce(0) { total, item in
            total + item.element * Self.placeValue(for: item.offset)
        }
    }

    var progress: Double {
        if completed { return 1 }
        return (Double(stageIndex) + (stageSolved ? 1 : 0)) / Double(stages.count)
    }

    func reset() {
        completed = false
        loadStage(0)
    }

    func setRow(_ row: Int, count: Int) {
        guard (0..<rowCounts.count).contains(row), !completed, !isAdvancing, !isRegrouping else { return }
        let clamped = min(max(count, 0), 10)
        guard rowCounts[row] != clamped else { return }
        rowCounts[row] = clamped
        pulse(row)
        HapticPlayer.playLightTap()

        if clamped == 10, row < rowCounts.count - 1 {
            triggerCarry(from: row)
            return
        }

        checkForMatch()
    }

    func slideBead(row: Int, bead: Int, direction: CGFloat) {
        guard (0..<rowCounts.count).contains(row), (0..<10).contains(bead) else { return }
        let count = rowCounts[row]
        let selected = Self.isBeadOnRight(bead: bead, count: count)
        let nextRightBead = 9 - count
        let nextLeftBead = 10 - count

        if direction > 8, !selected, bead == nextRightBead {
            setRow(row, count: rowCounts[row] + 1)
        } else if direction < -8, selected, bead == nextLeftBead {
            setRow(row, count: rowCounts[row] - 1)
        }
    }

    func clearAll() {
        guard !completed, !isAdvancing else { return }
        rowCounts = Array(repeating: 0, count: 10)
        pulseRows = Set(0..<10)
        HapticPlayer.playLightTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            self.pulseRows = []
        }
    }

    private func loadStage(_ index: Int) {
        let next = min(max(index, 0), stages.count - 1)
        stageIndex = next
        rowCounts = Array(repeating: 0, count: 10)
        pulseRows = []
        carryingRows = []
        completed = false
        stageSolved = false
        isAdvancing = false
        isRegrouping = false
    }

    private func checkForMatch() {
        guard currentValue == stage.answer, !isAdvancing else { return }
        isAdvancing = true
        stageSolved = true
        HapticPlayer.playCompletionTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            if self.stageIndex == self.stages.count - 1 {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    self.completed = true
                }
            } else {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    self.loadStage(self.stageIndex + 1)
                }
            }
        }
    }

    private func pulse(_ row: Int) {
        pulseRows.insert(row)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.pulseRows.remove(row)
        }
    }

    private func triggerCarry(from row: Int) {
        guard row < rowCounts.count - 1 else {
            checkForMatch()
            return
        }
        isRegrouping = true
        carryingRows.insert(row)
        pulseRows.insert(row)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                self.rowCounts[row] = 0
                self.rowCounts[row + 1] = min(10, self.rowCounts[row + 1] + 1)
                self.pulseRows.insert(row + 1)
                self.carryingRows.remove(row)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                self.pulseRows.remove(row)
                self.pulseRows.remove(row + 1)
                self.isRegrouping = false

                if self.rowCounts[row + 1] == 10, row + 1 < self.rowCounts.count - 1 {
                    self.triggerCarry(from: row + 1)
                } else {
                    self.checkForMatch()
                }
            }
        }
    }

    static func placeValue(for row: Int) -> Int {
        var value = 1
        if row > 0 {
            for _ in 0..<row { value *= 10 }
        }
        return value
    }

    static func isBeadOnRight(bead: Int, count: Int) -> Bool {
        bead >= 10 - count
    }
}

struct MathItLevelTwentyOneView: View {
    @ObservedObject var viewModel: MathItLevelTwentyOneViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let gold = Color(red: 0.93, green: 0.78, blue: 0.40)
    private let woodLight = Color(red: 0.83, green: 0.60, blue: 0.34)
    private let woodDark = Color(red: 0.45, green: 0.24, blue: 0.10)
    private let beadColors: [Color] = [
        Color(red: 0.05, green: 0.58, blue: 0.78),
        Color(red: 0.86, green: 0.02, blue: 0.08),
        Color(red: 0.84, green: 0.70, blue: 0.48),
        Color(red: 0.00, green: 0.62, blue: 0.24),
        Color(red: 0.96, green: 0.82, blue: 0.03)
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(
                x: 26,
                y: max(190, size.height * 0.25),
                width: size.width - 52,
                height: min(430, size.height * 0.48)
            )

            ZStack {
                marketplaceBackground

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)
                    .zIndex(20)

                expressionPanel
                    .frame(width: min(size.width - 42, 430))
                    .position(x: size.width / 2, y: board.minY - 58)

                abacus(board: board)

                bottomControls(size: size, board: board)

                ProgressView(value: viewModel.progress)
                    .tint(gold)
                    .frame(width: min(size.width - 58, 380))
                    .position(x: size.width / 2, y: size.height - 34)

                CompletionOverlay(
                    title: "Market Counted",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .environment(\.mathItAccent, gold)
        }
    }

    private var marketplaceBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.03, blue: 0.02),
                    Color(red: 0.18, green: 0.09, blue: 0.04),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom, spacing: 18) {
                    ForEach(0..<5, id: \.self) { index in
                        VStack(spacing: 0) {
                            Triangle()
                                .fill(gold.opacity(index.isMultiple(of: 2) ? 0.16 : 0.10))
                                .frame(width: 70, height: 36)
                            Rectangle()
                                .fill(.black.opacity(0.30))
                                .frame(width: 58, height: 54 + CGFloat(index % 3) * 13)
                        }
                    }
                }
                .padding(.bottom, 18)
            }
            .ignoresSafeArea()
        }
    }

    private var expressionPanel: some View {
        HStack(spacing: 14) {
            Image(systemName: "scroll.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(gold)

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.stage.expression)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(viewModel.currentValue)")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(viewModel.stageSolved ? gold : .white.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(minWidth: 58, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.62)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.24), lineWidth: 1))
    }

    private func abacus(board: CGRect) -> some View {
        let inner = board.insetBy(dx: 28, dy: 34)
        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [woodLight, woodDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.20), lineWidth: 1.2))
                .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            Rectangle()
                .fill(.black.opacity(0.18))
                .frame(width: inner.width, height: inner.height)
                .position(x: inner.midX, y: inner.midY)

            sidePost(x: board.minX + 20, board: board)
            sidePost(x: board.maxX - 20, board: board)

            ForEach(0..<10, id: \.self) { row in
                let y = rowY(row, inner: inner)
                abacusRow(row: row, y: y, inner: inner)
            }

            Capsule()
                .fill(LinearGradient(colors: [woodLight.opacity(1.1), woodDark], startPoint: .top, endPoint: .bottom))
                .frame(width: board.width + 18, height: 34)
                .position(x: board.midX, y: board.maxY + 8)

            Capsule()
                .fill(LinearGradient(colors: [woodLight.opacity(1.05), woodDark], startPoint: .top, endPoint: .bottom))
                .frame(width: board.width - 18, height: 22)
                .position(x: board.midX, y: board.minY + 10)
        }
    }

    private func sidePost(x: CGFloat, board: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(LinearGradient(colors: [woodLight.opacity(1.08), woodDark], startPoint: .leading, endPoint: .trailing))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.18), lineWidth: 1))
            .frame(width: 28, height: board.height + 16)
            .position(x: x, y: board.midY)
    }

    private func abacusRow(row: Int, y: CGFloat, inner: CGRect) -> some View {
        let count = viewModel.rowCounts[row]
        let activeColor = beadColors[row % beadColors.count]
        let pulse = viewModel.pulseRows.contains(row)
        let carrying = viewModel.carryingRows.contains(row)

        return ZStack {
            Capsule()
                .fill(activeColor.opacity(0.76))
                .frame(width: inner.width - 20, height: 4)
                .position(x: inner.midX, y: y)
                .shadow(color: pulse ? activeColor.opacity(0.9) : .clear, radius: 8)

            ForEach(0..<10, id: \.self) { bead in
                let selected = MathItLevelTwentyOneViewModel.isBeadOnRight(bead: bead, count: count)
                let x = beadX(bead: bead, selected: selected, inner: inner)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.55), activeColor, activeColor.opacity(0.58)],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 18
                        )
                    )
                    .frame(width: beadSize(inner: inner), height: beadSize(inner: inner))
                    .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.34), radius: 3, y: 2)
                    .scaleEffect(pulse && selected ? 1.12 : 1)
                    .opacity(carrying ? 0.78 : 1)
                    .position(x: x, y: y)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onEnded { value in
                                viewModel.slideBead(row: row, bead: bead, direction: value.translation.width)
                            }
                    )
            }

            Text(placeLabel(row))
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(row < 5 ? 0.56 : 0.36))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(width: 38, alignment: .trailing)
                .position(x: inner.minX - 5, y: y)
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.76), value: count)
        .animation(.easeInOut(duration: 0.16), value: pulse)
        .animation(.easeInOut(duration: 0.18), value: carrying)
    }

    private func bottomControls(size: CGSize, board: CGRect) -> some View {
        let y = min(size.height - 90, board.maxY + 74)
        return HStack(spacing: 12) {
            Button(action: viewModel.clearAll) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 52, height: 44)
                    .background(RoundedRectangle(cornerRadius: 13).fill(gold))
            }
            .buttonStyle(.plain)

            Text("total: \(viewModel.currentValue)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.76))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 13).fill(.black.opacity(0.58)))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .position(x: size.width / 2, y: y)
    }

    private func rowY(_ row: Int, inner: CGRect) -> CGFloat {
        inner.maxY - inner.height * (CGFloat(row) + 0.5) / 10
    }

    private func beadSize(inner: CGRect) -> CGFloat {
        min(22, max(14, inner.height / 16))
    }

    private func beadX(bead: Int, selected: Bool, inner: CGRect) -> CGFloat {
        let beadSize = beadSize(inner: inner)
        let spacing = beadSize * 0.86
        let leftStart = inner.minX + 18
        let rightStart = inner.maxX - 18 - spacing * 9
        let start = selected ? rightStart : leftStart
        return start + CGFloat(bead) * spacing
    }

    private func placeLabel(_ row: Int) -> String {
        let value = MathItLevelTwentyOneViewModel.placeValue(for: row)
        if value >= 1_000_000 {
            return "\(value / 1_000_000)M"
        }
        if value >= 1_000 {
            return "\(value / 1_000)K"
        }
        return "\(value)"
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

#Preview {
    MathItLevelTwentyOneView(
        viewModel: MathItLevelTwentyOneViewModel(),
        onContinue: {},
        onReplay: {},
        onLevelSelect: {}
    )
}
