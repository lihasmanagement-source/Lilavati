import SwiftUI
import Combine
import AVFoundation

struct MathItPackingSpaceGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var selectedBlockID = 1
    @State private var blockOrigins: [Int: SlideCell] = MathItPackingSpaceGame.stages[0].origins
    @State private var completed = false
    @State private var warningPulse = false

    private static let stages = [
        SlideStage(origins: [
            1: SlideCell(x: 0, y: 2),
            2: SlideCell(x: 4, y: 3),
            3: SlideCell(x: 5, y: 4),
            4: SlideCell(x: 0, y: 3),
            5: SlideCell(x: 1, y: 1),
            6: SlideCell(x: 3, y: 1),
            7: SlideCell(x: 5, y: 2)
        ]),
        SlideStage(origins: [
            1: SlideCell(x: 1, y: 2),
            2: SlideCell(x: 4, y: 0),
            3: SlideCell(x: 0, y: 3),
            4: SlideCell(x: 3, y: 2),
            5: SlideCell(x: 1, y: 0),
            6: SlideCell(x: 2, y: 5),
            7: SlideCell(x: 5, y: 3)
        ]),
        SlideStage(origins: [
            1: SlideCell(x: 0, y: 2),
            2: SlideCell(x: 3, y: 0),
            3: SlideCell(x: 5, y: 0),
            4: SlideCell(x: 4, y: 2),
            5: SlideCell(x: 0, y: 0),
            6: SlideCell(x: 1, y: 5),
            7: SlideCell(x: 2, y: 3)
        ]),
        SlideStage(origins: [
            1: SlideCell(x: 0, y: 2),
            2: SlideCell(x: 2, y: 0),
            3: SlideCell(x: 4, y: 1),
            4: SlideCell(x: 5, y: 3),
            5: SlideCell(x: 0, y: 0),
            6: SlideCell(x: 1, y: 5),
            7: SlideCell(x: 3, y: 3)
        ]),
        SlideStage(origins: [
            1: SlideCell(x: 0, y: 2),
            2: SlideCell(x: 2, y: 0),
            3: SlideCell(x: 3, y: 1),
            4: SlideCell(x: 4, y: 2),
            5: SlideCell(x: 0, y: 0),
            6: SlideCell(x: 1, y: 5),
            7: SlideCell(x: 5, y: 3)
        ])
    ]

    private let blocks = [
        SlideBlock(id: 1, length: 2, orientation: .horizontal, isEscape: true),
        SlideBlock(id: 2, length: 3, orientation: .vertical, isEscape: false),
        SlideBlock(id: 3, length: 2, orientation: .vertical, isEscape: false),
        SlideBlock(id: 4, length: 2, orientation: .vertical, isEscape: false),
        SlideBlock(id: 5, length: 2, orientation: .horizontal, isEscape: false),
        SlideBlock(id: 6, length: 3, orientation: .horizontal, isEscape: false),
        SlideBlock(id: 7, length: 2, orientation: .vertical, isEscape: false)
    ]

    private let exitRow = 2
    private let blockBlue = Color(red: 0.16, green: 0.64, blue: 1.0)
    private var currentStage: SlideStage { Self.stages[stageIndex] }
    private var redOrigin: SlideCell { blockOrigins[1] ?? currentStage.origins[1]! }
    private var progress: Double {
        let stageProgress = min(1, Double(redOrigin.x) / 4.0)
        return (Double(stageIndex) + stageProgress) / Double(Self.stages.count)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(36))
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.46))
                    }
                    .padding(.horizontal, 58)

                    ProgressView(value: progress)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    slideField
                        .frame(height: min(390, proxy.size.height * 0.5))
                        .padding(.horizontal, 24)
                        .scaleEffect(warningPulse ? 0.985 : 1)

                    HStack(spacing: 12) {
                        slideButton(systemImage: "arrow.left", direction: .left)
                        slideButton(systemImage: "arrow.up", direction: .up)
                        slideButton(systemImage: "arrow.down", direction: .down)
                        slideButton(systemImage: "arrow.right", direction: .right)
                        Button(action: reset) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 50, height: 46)
                                .background(accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)
                }
                .padding(.top, 38)
                .padding(.bottom, 78)

                CompletionOverlay(
                    title: "Level \(concept.number) Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var slideField: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cellSize = side / 6

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.28, green: 0.13, blue: 0.06), Color(red: 0.11, green: 0.055, blue: 0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.36), lineWidth: 1.2))

                ZStack {
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<6, id: \.self) { column in
                                    Rectangle()
                                        .fill((row + column).isMultiple(of: 2) ? .white.opacity(0.035) : .black.opacity(0.06))
                                        .frame(width: cellSize, height: cellSize)
                                        .overlay(Rectangle().stroke(.black.opacity(0.2), lineWidth: 1))
                                }
                            }
                        }
                    }

                    HStack(spacing: 0) {
                        Spacer()
                        Capsule()
                            .fill(Color.black.opacity(0.82))
                            .frame(width: 18, height: cellSize * 0.72)
                            .overlay(Capsule().stroke(accent.opacity(0.86), lineWidth: 1.5))
                            .offset(x: 12, y: CGFloat(exitRow) * cellSize - side / 2 + cellSize / 2)
                    }

                    ForEach(blocks) { block in
                        slideBlockView(block, cellSize: cellSize)
                    }
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.58), lineWidth: 2))

            }
        }
    }

    private func slideBlockView(_ block: SlideBlock, cellSize: CGFloat) -> some View {
        let origin = blockOrigins[block.id] ?? currentStage.origins[block.id]!
        let width = CGFloat(block.orientation == .horizontal ? block.length : 1) * cellSize - 8
        let height = CGFloat(block.orientation == .vertical ? block.length : 1) * cellSize - 8
        let x = CGFloat(origin.x) * cellSize + width / 2 + 4
        let y = CGFloat(origin.y) * cellSize + height / 2 + 4
        let isSelected = selectedBlockID == block.id

        return Button {
            selectedBlockID = block.id
            HapticPlayer.playLightTap()
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(block.isEscape ? blockBlue.opacity(0.88) : blockBlue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(blockBlue.opacity(isSelected || block.isEscape ? 0.98 : 0.7), lineWidth: isSelected ? 2.8 : 2)
                )
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(block.isEscape ? 0.34 : 0.14), .clear, blockBlue.opacity(block.isEscape ? 0.12 : 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                )
                .shadow(color: blockBlue.opacity(isSelected || block.isEscape ? 0.42 : 0.18), radius: isSelected ? 12 : 5)
                .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    let direction = dragDirection(value.translation)
                    move(block.id, direction: direction)
                }
        )
    }

    private func slideButton(systemImage: String, direction: SlideDirection) -> some View {
        Button {
            move(selectedBlockID, direction: direction)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 48, height: 46)
                .background(accent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(completed || !canMove(selectedBlockID, direction: direction))
        .opacity(canMove(selectedBlockID, direction: direction) ? 1 : 0.35)
    }

    private func dragDirection(_ translation: CGSize) -> SlideDirection {
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        }
        return translation.height > 0 ? .down : .up
    }

    private func move(_ blockID: Int, direction: SlideDirection) {
        guard !completed else { return }
        selectedBlockID = blockID

        if blockID == 1 && direction == .right && redOrigin.x == 4 {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                blockOrigins[1] = SlideCell(x: 5, y: exitRow)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                advanceStage()
            }
            return
        }

        guard canMove(blockID, direction: direction), let origin = blockOrigins[blockID] else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                warningPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
                    warningPulse = false
                }
            }
            return
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            blockOrigins[blockID] = origin.moved(direction)
        }
        HapticPlayer.playLightTap()
    }

    private func canMove(_ blockID: Int, direction: SlideDirection) -> Bool {
        guard let block = blocks.first(where: { $0.id == blockID }),
              let origin = blockOrigins[blockID] else { return false }

        if block.orientation == .horizontal && !direction.isHorizontal { return false }
        if block.orientation == .vertical && direction.isHorizontal { return false }

        if blockID == 1 && direction == .right && origin.x == 4 {
            return true
        }

        let nextOrigin = origin.moved(direction)
        let nextCells = block.cells(from: nextOrigin)
        let occupied = occupiedCells(excluding: blockID)

        return nextCells.allSatisfy { cell in
            (0..<6).contains(cell.x) && (0..<6).contains(cell.y) && occupied[cell] == nil
        }
    }

    private func occupiedCells(excluding blockID: Int? = nil) -> [SlideCell: Int] {
        blockOrigins.reduce(into: [:]) { result, entry in
            guard entry.key != blockID, let block = blocks.first(where: { $0.id == entry.key }) else { return }
            for cell in block.cells(from: entry.value) {
                if (0..<6).contains(cell.x) && (0..<6).contains(cell.y) {
                    result[cell] = block.id
                }
            }
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            stageIndex = 0
            selectedBlockID = 1
            blockOrigins = Self.stages[0].origins
            completed = false
            warningPulse = false
        }
    }

    private func advanceStage() {
        if stageIndex == Self.stages.count - 1 {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            let nextIndex = stageIndex + 1
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                stageIndex = nextIndex
                selectedBlockID = 1
                blockOrigins = Self.stages[nextIndex].origins
                warningPulse = false
            }
        }
    }
}

struct SlideStage {
    let origins: [Int: SlideCell]
}

struct SlideCell: Hashable {
    let x: Int
    let y: Int

    func moved(_ direction: SlideDirection) -> SlideCell {
        switch direction {
        case .left: return SlideCell(x: x - 1, y: y)
        case .right: return SlideCell(x: x + 1, y: y)
        case .up: return SlideCell(x: x, y: y - 1)
        case .down: return SlideCell(x: x, y: y + 1)
        }
    }
}

enum SlideDirection {
    case left
    case right
    case up
    case down

    var isHorizontal: Bool {
        self == .left || self == .right
    }
}

enum SlideOrientation {
    case horizontal
    case vertical
}

struct SlideBlock: Identifiable {
    let id: Int
    let length: Int
    let orientation: SlideOrientation
    let isEscape: Bool

    func cells(from origin: SlideCell) -> [SlideCell] {
        (0..<length).map { offset in
            switch orientation {
            case .horizontal:
                return SlideCell(x: origin.x + offset, y: origin.y)
            case .vertical:
                return SlideCell(x: origin.x, y: origin.y + offset)
            }
        }
    }
}
