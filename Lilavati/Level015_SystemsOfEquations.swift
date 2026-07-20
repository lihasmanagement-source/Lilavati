import SwiftUI
import Combine
import AVFoundation

struct MathItBattleshipGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var playerShips: Set<BattleCoordinate> = []
    @State private var playerShots: Set<BattleCoordinate> = []
    @State private var computerShots: Set<BattleCoordinate> = []
    @State private var computerTurnIndex = 0
    @State private var completed = false
    @State private var gameOver = false
    @State private var statusSymbol = "shield.fill"

    private let columns = ["A", "B", "C", "D"]
    private let computerShips: Set<BattleCoordinate> = [
        BattleCoordinate(column: 1, row: 1),
        BattleCoordinate(column: 3, row: 1),
        BattleCoordinate(column: 0, row: 2),
        BattleCoordinate(column: 2, row: 3)
    ]
    private let computerTargets = [
        BattleCoordinate(column: 0, row: 0),
        BattleCoordinate(column: 3, row: 3),
        BattleCoordinate(column: 1, row: 1),
        BattleCoordinate(column: 2, row: 2),
        BattleCoordinate(column: 0, row: 3),
        BattleCoordinate(column: 3, row: 0),
        BattleCoordinate(column: 1, row: 3),
        BattleCoordinate(column: 2, row: 0),
        BattleCoordinate(column: 0, row: 1),
        BattleCoordinate(column: 3, row: 2),
        BattleCoordinate(column: 1, row: 0),
        BattleCoordinate(column: 2, row: 1),
        BattleCoordinate(column: 0, row: 2),
        BattleCoordinate(column: 3, row: 1),
        BattleCoordinate(column: 1, row: 2),
        BattleCoordinate(column: 2, row: 3)
    ]

    private var playerHitCount: Int { playerShots.intersection(computerShips).count }
    private var computerHitCount: Int { computerShots.intersection(playerShips).count }
    private var isPlacing: Bool { playerShips.count < 4 }
    private var boardCoordinates: [BattleCoordinate] {
        (0..<4).flatMap { row in
            (0..<4).map { column in
                BattleCoordinate(column: column, row: row)
            }
        }
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

                    ProgressView(value: Double(playerHitCount), total: 4)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    HStack(spacing: 12) {
                        battleBoard(systemImage: "shield.fill", mode: .fleet)
                        battleBoard(systemImage: "scope", mode: .target)
                    }
                    .frame(height: min(360, proxy.size.height * 0.44))
                    .padding(.horizontal, 14)

                    HStack(spacing: 12) {
                        battleBadge("\(playerShips.count)/4", systemImage: "shield.fill")
                        battleBadge("\(playerHitCount)/4", systemImage: "burst.fill")
                        Button(action: reset) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 54, height: 48)
                                .background(accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)

                    Image(systemName: statusSymbol)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(gameOver ? .red.opacity(0.9) : accent)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.84), in: Circle())
                        .overlay(Circle().stroke((gameOver ? Color.red : accent).opacity(0.44), lineWidth: 1.1))
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

    private func battleBoard(systemImage: String, mode: BattleBoardMode) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 30, height: 24)
                .background(accent, in: Capsule())

            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    axisLabel("")
                    ForEach(0..<4, id: \.self) { column in
                        axisLabel(columns[column])
                    }
                }

                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 5) {
                        axisLabel("\(row + 1)")
                        ForEach(0..<4, id: \.self) { column in
                            let coordinate = BattleCoordinate(column: column, row: row)
                            battleCell(coordinate, mode: mode)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(accent.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.36), lineWidth: 1.2))
    }

    private func axisLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
    }

    private func battleCell(_ coordinate: BattleCoordinate, mode: BattleBoardMode) -> some View {
        let state = cellState(for: coordinate, mode: mode)

        return Button {
            choose(coordinate, mode: mode)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(state.fill)
                RoundedRectangle(cornerRadius: 7)
                    .stroke(state.stroke, lineWidth: 1.1)

                if let icon = state.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(state.iconColor)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled(coordinate, mode: mode))
    }

    private func battleBadge(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(width: 96, height: 48)
        .background(.black.opacity(0.84), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.44), lineWidth: 1.1))
    }

    private func cellState(for coordinate: BattleCoordinate, mode: BattleBoardMode) -> BattleCellState {
        switch mode {
        case .fleet:
            let hasShip = playerShips.contains(coordinate)
            let wasShot = computerShots.contains(coordinate)
            if wasShot && hasShip {
                return BattleCellState(fill: .red.opacity(0.72), stroke: .red.opacity(0.95), icon: "flame.fill", iconColor: .white)
            } else if wasShot {
                return BattleCellState(fill: .white.opacity(0.16), stroke: .white.opacity(0.35), icon: "drop.fill", iconColor: .white.opacity(0.72))
            } else if hasShip {
                return BattleCellState(fill: accent.opacity(0.88), stroke: accent, icon: "shield.fill", iconColor: .black)
            }
        case .target:
            let wasShot = playerShots.contains(coordinate)
            let hit = computerShips.contains(coordinate)
            if wasShot && hit {
                return BattleCellState(fill: accent.opacity(0.9), stroke: accent, icon: "burst.fill", iconColor: .black)
            } else if wasShot {
                return BattleCellState(fill: .white.opacity(0.12), stroke: Color.mathGold.opacity(0.5), icon: "xmark", iconColor: .white.opacity(0.66))
            }
        }

        return BattleCellState(fill: .black.opacity(0.78), stroke: accent.opacity(0.36), icon: nil, iconColor: .white)
    }

    private func isDisabled(_ coordinate: BattleCoordinate, mode: BattleBoardMode) -> Bool {
        if completed || gameOver { return true }
        switch mode {
        case .fleet:
            return !isPlacing || playerShips.contains(coordinate)
        case .target:
            return isPlacing || playerShots.contains(coordinate)
        }
    }

    private func choose(_ coordinate: BattleCoordinate, mode: BattleBoardMode) {
        guard !completed && !gameOver else { return }

        switch mode {
        case .fleet:
            placeShip(at: coordinate)
        case .target:
            firePlayerShot(at: coordinate)
        }
    }

    private func placeShip(at coordinate: BattleCoordinate) {
        guard isPlacing && !playerShips.contains(coordinate) else { return }

        playerShips.insert(coordinate)
        HapticPlayer.playLightTap()
        if playerShips.count == 4 {
            statusSymbol = "scope"
        } else {
            statusSymbol = "shield.fill"
        }
    }

    private func firePlayerShot(at coordinate: BattleCoordinate) {
        guard playerShips.count == 4 && !playerShots.contains(coordinate) else { return }

        playerShots.insert(coordinate)
        let hit = computerShips.contains(coordinate)
        statusSymbol = hit ? "burst.fill" : "xmark"
        HapticPlayer.playLightTap()

        if playerHitCount == 4 {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                completed = true
                statusSymbol = "checkmark.seal.fill"
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                fireComputerShot()
            }
        }
    }

    private func fireComputerShot() {
        guard !completed && !gameOver else { return }

        let target = computerTargets.dropFirst(computerTurnIndex).first { !computerShots.contains($0) }
        computerTurnIndex += 1

        guard let target else { return }
        computerShots.insert(target)

        if playerShips.contains(target) {
            statusSymbol = "flame.fill"
            HapticPlayer.playLightTap()
        } else {
            statusSymbol = "drop.fill"
        }

        if computerHitCount == 4 {
            gameOver = true
            statusSymbol = "exclamationmark.triangle.fill"
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            playerShips = []
            playerShots = []
            computerShots = []
            computerTurnIndex = 0
            completed = false
            gameOver = false
            statusSymbol = "shield.fill"
        }
    }
}

struct BattleCoordinate: Hashable, Identifiable {
    let column: Int
    let row: Int

    var id: String { label }
    var label: String {
        let columnName = ["A", "B", "C", "D"][column]
        return "\(columnName)\(row + 1)"
    }
}

enum BattleBoardMode {
    case fleet
    case target
}

struct BattleCellState {
    let fill: Color
    let stroke: Color
    let icon: String?
    let iconColor: Color
}
