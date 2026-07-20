import SwiftUI

struct MathItLevelOneHundredTwentyNineView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var row: [InsertionSortCard?] = InsertionSortCard.startingRow
    @State private var activeCard: InsertionSortCard? = InsertionSortCard.startingDeck[1]
    @State private var activeIndex = 1
    @State private var gapIndex = 1
    @State private var dragging: InsertionSortDrag?
    @State private var wrongID: Int?
    @State private var completed = false
    @State private var algorithmStage = 0

    private var compareIndex: Int? {
        guard gapIndex > 0, activeCard != nil else { return nil }
        return gapIndex - 1
    }

    private var canInsert: Bool {
        guard let activeCard else { return false }
        guard let compareIndex, let left = row[compareIndex] else { return true }
        return activeCard.value >= left.value
    }

    private var progressValue: Double {
        Double(max(0, activeIndex - 1)) / Double(InsertionSortCard.startingDeck.count - 1)
    }

    var body: some View {
        if algorithmStage == 0 {
            GeometryReader { proxy in
                ZStack {
                    Color.black.ignoresSafeArea()

                    HomeButton(action: onLevelSelect)
                        .position(x: 34, y: 54)

                    VStack(spacing: 14) {
                        VStack(spacing: 7) {
                            Text("STAGE 1")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .tracking(4)
                                .foregroundStyle(Color.mathGold.opacity(0.85))

                            EmptyView()
                                .font(.trajan(34))
                                .tracking(2)
                                .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .padding(.horizontal, 58)

                        insertionBoard
                            .frame(height: min(560, proxy.size.height * 0.66))
                            .padding(.horizontal, 18)

                        HStack(spacing: 14) {
                            ProgressView(value: completed ? 1 : progressValue)
                                .tint(accent)

                            Button(action: reset) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(accent)
                                    .frame(width: 58, height: 48)
                                    .background(.black.opacity(0.72), in: Capsule())
                                    .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.top, 38)
                    .padding(.bottom, 76)

                    CompletionOverlay(
                        title: "Stage 1 Complete",
                        isVisible: completed,
                        onContinue: advanceToMarketFlow,
                        onReplay: reset,
                        onLevelSelect: onLevelSelect
                    )
                    .zIndex(20)
                }
            }
        } else {
            MathItLevelNinetyOneView(
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        }
    }

    private var insertionBoard: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let count = InsertionSortCard.startingDeck.count
            let cardWidth = min(58, (size.width - 58) / CGFloat(count))
            let cardHeight = cardWidth * 1.38
            let spacing = min(11, (size.width - cardWidth * CGFloat(count)) / CGFloat(count + 1))
            let rowWidth = cardWidth * CGFloat(count) + spacing * CGFloat(count - 1)
            let startX = (size.width - rowWidth) / 2 + cardWidth / 2
            let rowY = size.height * 0.55
            let activeY = rowY - cardHeight * 1.32
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(completed ? 0.18 : 0.07), Color(red: 0.012, green: 0.014, blue: 0.018), .black],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(size.width, size.height) * 0.72
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(completed ? 0.26 : 0.12), lineWidth: 1.2))

                sortedSectionLine(startX: startX, rowY: rowY, cardWidth: cardWidth, cardHeight: cardHeight, spacing: spacing)

                ForEach(0..<count, id: \.self) { index in
                    let center = cardCenter(index: index, startX: startX, rowY: rowY, cardWidth: cardWidth, spacing: spacing)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(index == gapIndex && activeCard != nil ? accent.opacity(0.16) : .white.opacity(0.035))
                        .frame(width: cardWidth, height: cardHeight)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(index == gapIndex ? 0.42 : 0.1), style: StrokeStyle(lineWidth: 1.2, dash: index == gapIndex ? [5, 5] : [])))
                        .position(center)

                    if let card = row[index] {
                        cardView(card, width: cardWidth, height: cardHeight, highlighted: index == compareIndex, wrong: wrongID == card.id)
                            .position(dragging?.card.id == card.id ? dragPoint(for: dragging!) : center)
                            .zIndex(dragging?.card.id == card.id ? 10 : 2)
                            .gesture(!completed ? cardDragGesture(card: card, index: index, origin: center, target: cardCenter(index: gapIndex, startX: startX, rowY: rowY, cardWidth: cardWidth, spacing: spacing), cardWidth: cardWidth) : nil)
                    }
                }

                if let activeCard {
                    let activeCenter = CGPoint(x: cardCenter(index: gapIndex, startX: startX, rowY: rowY, cardWidth: cardWidth, spacing: spacing).x, y: activeY)
                    cardView(activeCard, width: cardWidth, height: cardHeight, highlighted: true, wrong: wrongID == activeCard.id)
                        .position(dragging?.card.id == activeCard.id ? dragPoint(for: dragging!) : activeCenter)
                        .zIndex(12)
                        .gesture(!completed ? activeDragGesture(card: activeCard, origin: activeCenter, target: cardCenter(index: gapIndex, startX: startX, rowY: rowY, cardWidth: cardWidth, spacing: spacing), cardWidth: cardWidth) : nil)
                }

            }
        }
    }

    private func sortedSectionLine(startX: CGFloat, rowY: CGFloat, cardWidth: CGFloat, cardHeight: CGFloat, spacing: CGFloat) -> some View {
        let sortedCount = completed ? row.count : activeIndex
        let width = CGFloat(sortedCount) * cardWidth + CGFloat(max(0, sortedCount - 1)) * spacing
        return Capsule()
            .fill(accent.opacity(0.62))
            .frame(width: max(0, width), height: 4)
            .position(x: startX + (width - cardWidth) / 2, y: rowY + cardHeight * 0.66)
            .opacity(sortedCount > 0 ? 1 : 0)
    }

    private func cardView(_ card: InsertionSortCard, width: CGFloat, height: CGFloat, highlighted: Bool, wrong: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(Color(red: 0.94, green: 0.95, blue: 0.92))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(wrong ? .red.opacity(0.9) : (highlighted ? accent.opacity(0.92) : .black.opacity(0.18)), lineWidth: highlighted || wrong ? 3 : 1)
            )
            .overlay(alignment: .topLeading) {
                Text(card.label)
                    .font(.garamond(width * 0.24))
                    .foregroundStyle(card.color)
                    .padding(width * 0.13)
            }
            .overlay {
                Text(card.suit)
                    .font(.garamond(width * 0.48))
                    .foregroundStyle(card.color)
            }
            .shadow(color: highlighted ? accent.opacity(0.52) : .black.opacity(0.34), radius: highlighted ? 14 : 7)
            .offset(x: wrong ? -7 : 0)
            .animation(.spring(response: 0.14, dampingFraction: 0.32), value: wrong)
    }

    private func cardDragGesture(card: InsertionSortCard, index: Int, origin: CGPoint, target: CGPoint, cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                dragging = InsertionSortDrag(card: card, origin: origin, translation: gesture.translation)
            }
            .onEnded { gesture in
                dragging = nil
                let drop = CGPoint(x: origin.x + gesture.translation.width, y: origin.y + gesture.translation.height)
                handleRowCardDrop(card: card, index: index, drop: drop, target: target, tolerance: cardWidth * 0.9)
            }
    }

    private func activeDragGesture(card: InsertionSortCard, origin: CGPoint, target: CGPoint, cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                dragging = InsertionSortDrag(card: card, origin: origin, translation: gesture.translation)
            }
            .onEnded { gesture in
                dragging = nil
                let drop = CGPoint(x: origin.x + gesture.translation.width, y: origin.y + gesture.translation.height)
                handleActiveDrop(card: card, drop: drop, target: target, tolerance: cardWidth * 0.9)
            }
    }

    private func handleRowCardDrop(card: InsertionSortCard, index: Int, drop: CGPoint, target: CGPoint, tolerance: CGFloat) {
        guard !canInsert, index == gapIndex - 1, isNear(drop, target, tolerance: tolerance) else {
            pulseWrong(card.id)
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            row[gapIndex] = card
            row[index] = nil
            gapIndex = index
        }
    }

    private func handleActiveDrop(card: InsertionSortCard, drop: CGPoint, target: CGPoint, tolerance: CGFloat) {
        guard canInsert, isNear(drop, target, tolerance: tolerance) else {
            pulseWrong(card.id)
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            row[gapIndex] = card
            activeCard = nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            advanceActiveCard()
        }
    }

    private func advanceActiveCard() {
        let nextIndex = activeIndex + 1
        guard nextIndex < row.count else {
            finishLevel()
            return
        }

        guard let nextCard = row[nextIndex] else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            activeIndex = nextIndex
            gapIndex = nextIndex
            activeCard = nextCard
            row[nextIndex] = nil
            wrongID = nil
        }
    }

    private func finishLevel() {
        withAnimation(.easeInOut(duration: 0.42)) {
            completed = true
            wrongID = nil
        }
    }

    private func advanceToMarketFlow() {
        withAnimation(.easeInOut(duration: 0.32)) {
            algorithmStage = 1
            completed = false
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            row = InsertionSortCard.startingRow
            activeIndex = 1
            gapIndex = 1
            activeCard = InsertionSortCard.startingDeck[1]
            row[1] = nil
            dragging = nil
            wrongID = nil
            completed = false
        }
    }

    private func pulseWrong(_ id: Int) {
        wrongID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            wrongID = nil
        }
    }

    private func cardCenter(index: Int, startX: CGFloat, rowY: CGFloat, cardWidth: CGFloat, spacing: CGFloat) -> CGPoint {
        CGPoint(x: startX + CGFloat(index) * (cardWidth + spacing), y: rowY)
    }

    private func dragPoint(for drag: InsertionSortDrag) -> CGPoint {
        CGPoint(x: drag.origin.x + drag.translation.width, y: drag.origin.y + drag.translation.height)
    }

    private func isNear(_ point: CGPoint, _ target: CGPoint, tolerance: CGFloat) -> Bool {
        hypot(point.x - target.x, point.y - target.y) < tolerance
    }
}

private struct InsertionSortCard: Equatable, Identifiable {
    let id: Int
    let value: Int
    let suit: String

    var label: String {
        value == 1 ? "A" : "\(value)"
    }

    var color: Color {
        suit == "♥" || suit == "♦" ? Color(red: 0.72, green: 0.05, blue: 0.09) : .black
    }

    static let startingDeck: [InsertionSortCard] = [
        InsertionSortCard(id: 0, value: 5, suit: "♠"),
        InsertionSortCard(id: 1, value: 2, suit: "♥"),
        InsertionSortCard(id: 2, value: 6, suit: "♣"),
        InsertionSortCard(id: 3, value: 1, suit: "♦"),
        InsertionSortCard(id: 4, value: 4, suit: "♠"),
        InsertionSortCard(id: 5, value: 3, suit: "♥")
    ]

    static let startingRow: [InsertionSortCard?] = [
        Optional.some(startingDeck[0]),
        nil,
        Optional.some(startingDeck[2]),
        Optional.some(startingDeck[3]),
        Optional.some(startingDeck[4]),
        Optional.some(startingDeck[5])
    ]
}

private struct InsertionSortDrag: Equatable {
    let card: InsertionSortCard
    let origin: CGPoint
    var translation: CGSize
}
