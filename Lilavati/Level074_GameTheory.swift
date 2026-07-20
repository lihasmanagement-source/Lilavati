import SwiftUI

// MARK: - Level 102 · Mancala (Kalah, player vs. a simple AI)
//
// The classic sowing game. Pits 0–5 are yours (bottom row), 6 is your store;
// pits 7–12 are the opponent's (top row), 13 is theirs. On your turn, pick one
// of your pits and sow its stones one-by-one counter-clockwise, dropping into
// your own store but skipping the opponent's. Land your last stone in your store
// for another turn; land in an empty pit on your own side to capture the stones
// directly across from it. When one side empties, the rest are swept up — most
// stones wins.

enum MancalaDifficulty: String, CaseIterable {
    case easy = "Easy", medium = "Medium", hard = "Hard"
    var subtitle: String {
        switch self {
        case .easy:   return "Plays at random"
        case .medium: return "Plays greedily"
        case .hard:   return "Thinks ahead"
        }
    }
    var searchDepth: Int { self == .hard ? 7 : 0 }
}

@Observable
final class MancalaViewModel {
    var difficulty: MancalaDifficulty = .medium
    var twoPlayer = false          // pass-and-play: both sides are human
    // 0–5 player pits, 6 player store, 7–12 opponent pits, 13 opponent store.
    var pits: [Int] = []
    var currentPlayer = 0          // 0 = you, 1 = opponent
    var animating = false
    var completed = false
    var playerWon = false
    var highlight: Int? = nil
    var lastCapture: Int? = nil
    // The "hand" carrying stones between pockets.
    var handIndex: Int? = nil     // pocket the hand is currently over
    var handRemaining = 0         // stones still in the hand
    var extraTurnFlash = false

    let playerStore = 6
    let aiStore = 13

    init() { reset() }

    func setComputer(_ d: MancalaDifficulty) {
        guard twoPlayer || difficulty != d else { return }
        twoPlayer = false
        difficulty = d
        reset()
    }

    func setTwoPlayer() {
        guard !twoPlayer else { return }
        twoPlayer = true
        reset()
    }

    func reset() {
        pits = Array(repeating: 4, count: 14)
        pits[playerStore] = 0
        pits[aiStore] = 0
        currentPlayer = 0
        animating = false
        completed = false
        playerWon = false
        highlight = nil
        lastCapture = nil
        handIndex = nil
        handRemaining = 0
        extraTurnFlash = false
    }

    func isPlayerPit(_ i: Int) -> Bool { (0...5).contains(i) }
    func isAiPit(_ i: Int) -> Bool { (7...12).contains(i) }

    var playerScore: Int { pits.isEmpty ? 0 : pits[playerStore] }
    var aiScore: Int { pits.isEmpty ? 0 : pits[aiStore] }

    // MARK: Input

    func tapPit(_ i: Int) {
        guard !animating, !completed else { return }
        if currentPlayer == 0, isPlayerPit(i), pits[i] > 0 {
            sow(from: i, player: 0)
        } else if currentPlayer == 1, twoPlayer, isAiPit(i), pits[i] > 0 {
            sow(from: i, player: 1)          // Player 2 (pass-and-play)
        }
    }

    // MARK: Sowing (one stone at a time, animated)

    private func sow(from pit: Int, player: Int) {
        animating = true
        lastCapture = nil
        let hand = pits[pit]
        let oppStore = player == 0 ? aiStore : playerStore

        // Pick up: the hand scoops every stone out of the pocket.
        handIndex = pit
        handRemaining = hand
        pits[pit] = 0
        withAnimation(.easeInOut(duration: 0.22)) { highlight = pit }
        HapticPlayer.playLightTap()

        // A beat to read the pick-up, then start dropping one per pocket.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [self] in
            dropStep(hand: hand, idx: pit, oppStore: oppStore, player: player)
        }
    }

    private func dropStep(hand: Int, idx: Int, oppStore: Int, player: Int) {
        guard hand > 0 else {
            handIndex = nil
            handRemaining = 0
            finishSow(lastIndex: idx, player: player)
            return
        }

        var nextIdx = (idx + 1) % 14
        if nextIdx == oppStore { nextIdx = (nextIdx + 1) % 14 }
        let remaining = hand - 1

        pits[nextIdx] += 1                        // drop one into this pocket
        handIndex = remaining > 0 ? nextIdx : nil // hand moves on (or leaves once empty)
        handRemaining = remaining
        withAnimation(.easeInOut(duration: 0.18)) { highlight = nextIdx }
        HapticPlayer.playLightTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { [self] in
            dropStep(hand: remaining, idx: nextIdx, oppStore: oppStore, player: player)
        }
    }

    private func finishSow(lastIndex: Int, player: Int) {
        let store = player == 0 ? playerStore : aiStore
        let ownPits = player == 0 ? (0...5) : (7...12)

        // Capture: last stone lands in a now-single (was empty) pit on your side.
        if ownPits.contains(lastIndex), pits[lastIndex] == 1 {
            let opposite = 12 - lastIndex
            if pits[opposite] > 0 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    pits[store] += pits[opposite] + 1
                    pits[opposite] = 0
                    pits[lastIndex] = 0
                    lastCapture = lastIndex
                }
                HapticPlayer.playCompletionTap()
            }
        }

        if checkGameOver() { return }

        let extraTurn = lastIndex == store
        highlight = nil

        if extraTurn {
            if player == 1 && !twoPlayer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in aiMove() }
            } else {
                animating = false          // human keeps the turn
                flashExtraTurn()
            }
        } else {
            currentPlayer = 1 - player
            if currentPlayer == 1 && !twoPlayer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in aiMove() }
            } else {
                animating = false          // hand off to the other human
            }
        }
    }

    private func flashExtraTurn() {
        HapticPlayer.playCompletionTap()
        withAnimation(.easeInOut(duration: 0.25)) { extraTurnFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [self] in
            withAnimation(.easeInOut(duration: 0.4)) { extraTurnFlash = false }
        }
    }

    // MARK: Opponent

    private func aiMove() {
        guard !completed else { return }
        currentPlayer = 1
        animating = true
        guard let choice = chooseAiPit() else { _ = checkGameOver(); animating = false; return }
        sow(from: choice, player: 1)
    }

    private func chooseAiPit() -> Int? {
        let moves = (7...12).filter { pits[$0] > 0 }
        guard !moves.isEmpty else { return nil }
        switch difficulty {
        case .easy:   return moves.randomElement()
        case .medium: return greedyChoice(moves)
        case .hard:   return minimaxChoice(moves)
        }
    }

    // Medium — one-ply heuristic: extra turn, then capture, then the fullest pit.
    private func greedyChoice(_ moves: [Int]) -> Int {
        if let m = moves.sorted(by: >).first(where: { landing(from: $0, player: 1) == aiStore }) { return m }
        if let m = moves.first(where: { mv in
            let land = landing(from: mv, player: 1)
            return isAiPit(land) && pits[land] == 0 && land != mv && pits[12 - land] > 0
        }) { return m }
        return moves.max(by: { pits[$0] < pits[$1] }) ?? moves[0]
    }

    // Hard — alpha-beta minimax over the actual game tree.
    private func minimaxChoice(_ moves: [Int]) -> Int {
        var best = moves[0]
        var bestScore = Int.min
        for m in moves {
            let r = Self.applyMove(pits, pit: m, player: 1)
            let score = Self.minimax(r.board, player: r.again ? 1 : 0,
                                     depth: difficulty.searchDepth - 1, alpha: -100_000, beta: 100_000)
            if score > bestScore { bestScore = score; best = m }
        }
        return best
    }

    private func landing(from pit: Int, player: Int) -> Int {
        var hand = pits[pit], idx = pit
        let oppStore = player == 0 ? aiStore : playerStore
        while hand > 0 {
            idx = (idx + 1) % 14
            if idx == oppStore { idx = (idx + 1) % 14 }
            hand -= 1
        }
        return idx
    }

    // MARK: Pure rules (no animation) — used by the search

    static func applyMove(_ board: [Int], pit: Int, player: Int) -> (board: [Int], again: Bool) {
        var b = board
        let store = player == 0 ? 6 : 13
        let oppStore = player == 0 ? 13 : 6
        var hand = b[pit]
        b[pit] = 0
        var idx = pit
        while hand > 0 {
            idx = (idx + 1) % 14
            if idx == oppStore { continue }   // skip the opponent's store
            b[idx] += 1
            hand -= 1
        }
        let lo = player == 0 ? 0 : 7
        if idx >= lo, idx <= lo + 5, b[idx] == 1 {   // capture on own empty pit
            let opp = 12 - idx
            if b[opp] > 0 { b[store] += b[opp] + 1; b[opp] = 0; b[idx] = 0 }
        }
        return (b, idx == store)
    }

    private static func sideEmpty(_ b: [Int], player: Int) -> Bool {
        let lo = player == 0 ? 0 : 7
        return (lo...(lo + 5)).allSatisfy { b[$0] == 0 }
    }

    private static func swept(_ b: [Int]) -> [Int] {
        var x = b
        for i in 0...5 { x[6] += x[i]; x[i] = 0 }
        for i in 7...12 { x[13] += x[i]; x[i] = 0 }
        return x
    }

    private static func evaluate(_ b: [Int]) -> Int { b[13] - b[6] }   // AI store minus player store

    private static func minimax(_ board: [Int], player: Int, depth: Int, alpha: Int, beta: Int) -> Int {
        if sideEmpty(board, player: 0) || sideEmpty(board, player: 1) { return evaluate(swept(board)) }
        if depth == 0 { return evaluate(board) }
        let lo = player == 0 ? 0 : 7
        let moves = (lo...(lo + 5)).filter { board[$0] > 0 }
        if moves.isEmpty { return evaluate(swept(board)) }

        if player == 1 {                       // AI maximises
            var value = Int.min, a = alpha
            for m in moves {
                let r = applyMove(board, pit: m, player: 1)
                value = max(value, minimax(r.board, player: r.again ? 1 : 0, depth: depth - 1, alpha: a, beta: beta))
                a = max(a, value)
                if a >= beta { break }
            }
            return value
        } else {                               // player minimises
            var value = Int.max, b = beta
            for m in moves {
                let r = applyMove(board, pit: m, player: 0)
                value = min(value, minimax(r.board, player: r.again ? 0 : 1, depth: depth - 1, alpha: alpha, beta: b))
                b = min(b, value)
                if alpha >= b { break }
            }
            return value
        }
    }

    // MARK: End of game

    @discardableResult
    private func checkGameOver() -> Bool {
        let youEmpty = (0...5).allSatisfy { pits[$0] == 0 }
        let oppEmpty = (7...12).allSatisfy { pits[$0] == 0 }
        guard youEmpty || oppEmpty else { return false }

        withAnimation(.easeInOut(duration: 0.4)) {
            for i in 0...5 { pits[playerStore] += pits[i]; pits[i] = 0 }
            for i in 7...12 { pits[aiStore] += pits[i]; pits[i] = 0 }
        }
        highlight = nil
        animating = false
        playerWon = pits[playerStore] > pits[aiStore]
        if playerWon { HapticPlayer.playCompletionTap() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { completed = true }
        }
        return true
    }
}

// MARK: - Palette

private enum MC {
    static let bg     = Color(red: 0.03, green: 0.03, blue: 0.06)
    static let board  = Color(red: 0.07, green: 0.07, blue: 0.11)
    static let gold    = Color.mathGold
    static let cool   = Color(red: 0.60, green: 0.66, blue: 0.80)
    static let marble = Color(red: 1.0, green: 0.84, blue: 0.42)    // all stones share this colour
}

struct MathItLevelOneHundredTwoView: View {
    @State private var viewModel = MancalaViewModel()

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let margin: CGFloat = 18
            let boardH = size.height * 0.42
            let boardRect = CGRect(x: margin, y: size.height * 0.30, width: size.width - margin * 2, height: boardH)
            let storeW = boardRect.width * 0.13
            let pitAreaX = boardRect.minX + storeW + 14
            let pitAreaW = boardRect.width - (storeW + 14) * 2
            let colW = pitAreaW / 6
            let pitD = min(colW * 0.86, boardH * 0.34)
            let topY = boardRect.minY + boardH * 0.30
            let botY = boardRect.minY + boardH * 0.70
            let leftStoreX = boardRect.minX + storeW / 2 + 2
            let rightStoreX = boardRect.maxX - storeW / 2 - 2

            let positions: [CGPoint] = (0..<14).map { i -> CGPoint in
                if i <= 5 { return CGPoint(x: pitAreaX + colW * (CGFloat(i) + 0.5), y: botY) }
                if i == 6 { return CGPoint(x: rightStoreX, y: boardRect.midY) }
                if i <= 12 { return CGPoint(x: pitAreaX + colW * (CGFloat(12 - i) + 0.5), y: topY) }
                return CGPoint(x: leftStoreX, y: boardRect.midY)
            }

            ZStack {
                MC.bg.ignoresSafeArea()

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                header(size: size)

                // Board backing.
                RoundedRectangle(cornerRadius: 26)
                    .fill(MC.board)
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(MC.gold.opacity(0.18), lineWidth: 1.2))
                    .frame(width: boardRect.width, height: boardRect.height)
                    .position(x: boardRect.midX, y: boardRect.midY)

                // Stores.
                storeView(index: aiStoreIndex, center: positions[13], w: storeW, h: boardH * 0.78, tint: MC.cool)
                storeView(index: playerStoreIndex, center: positions[6], w: storeW, h: boardH * 0.78, tint: MC.gold)

                // Pits.
                ForEach(7...12, id: \.self) { i in pitView(i, center: positions[i], d: pitD, tint: MC.cool) }
                ForEach(0...5, id: \.self) { i in pitView(i, center: positions[i], d: pitD, tint: MC.gold) }

                // The hand carrying stones between pockets.
                if let hi = viewModel.handIndex, positions.indices.contains(hi) {
                    handCluster(count: viewModel.handRemaining, d: pitD)
                        .position(x: positions[hi].x, y: positions[hi].y - pitD * 0.92)
                        .allowsHitTesting(false)
                        .zIndex(10)
                        .animation(.easeInOut(duration: 0.30), value: viewModel.handIndex)
                }

                if viewModel.extraTurnFlash {
                    Text("EXTRA TURN")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(MC.gold)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(MC.gold.opacity(0.14)))
                        .overlay(Capsule().stroke(MC.gold.opacity(0.7), lineWidth: 1))
                        .position(x: size.width / 2, y: size.height * 0.235)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(20)
                }

                // Overlays.
                if viewModel.completed && !viewModel.twoPlayer && viewModel.playerWon,
                   let concept = ConceptLibrary.concept(for: 102) {
                    ConceptCompletionOverlay(
                        levelTitle: "Mancala",
                        concept: concept,
                        isVisible: true,
                        onContinue: onContinue,
                        onReplay: { viewModel.reset() },
                        onLevelSelect: onLevelSelect
                    )
                    .zIndex(50)
                }

                if viewModel.completed && !viewModel.twoPlayer && !viewModel.playerWon {
                    lossOverlay
                        .zIndex(50)
                }

                if viewModel.completed && viewModel.twoPlayer {
                    twoPlayerResultOverlay
                        .zIndex(50)
                }

                difficultyPicker
                    .position(x: size.width / 2, y: size.height * 0.85)
            }
        }
    }

    // Inline segmented picker (same placement/format as level 93), plus a
    // pass-and-play 2-player option.
    private var difficultyPicker: some View {
        HStack(spacing: 7) {
            ForEach(MancalaDifficulty.allCases, id: \.self) { d in
                capsuleOption(d.rawValue.uppercased(),
                              selected: !viewModel.twoPlayer && viewModel.difficulty == d) {
                    viewModel.setComputer(d)
                }
            }
            capsuleOption("2P", selected: viewModel.twoPlayer) { viewModel.setTwoPlayer() }
        }
    }

    private func capsuleOption(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1)
                .foregroundStyle(selected ? .black : .white.opacity(0.7))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(selected ? MC.gold : .white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(MC.gold.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var playerStoreIndex: Int { 6 }
    private var aiStoreIndex: Int { 13 }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.trajan(34))
                .tracking(6)
                .foregroundStyle(MC.gold.opacity(0.95))

            HStack(spacing: 18) {
                scorePill(viewModel.twoPlayer ? "P1" : "YOU", viewModel.playerScore, tint: MC.gold, active: viewModel.currentPlayer == 0 && !viewModel.completed)
                scorePill(viewModel.twoPlayer ? "P2" : "OPP", viewModel.aiScore, tint: MC.cool, active: viewModel.currentPlayer == 1 && !viewModel.completed)
            }
        }
        .position(x: size.width / 2, y: 96)
    }

    private func scorePill(_ label: String, _ value: Int, tint: Color, active: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(tint.opacity(0.75))
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(active ? 0.16 : 0.04)))
        .overlay(Capsule().stroke(tint.opacity(active ? 0.8 : 0.2), lineWidth: 1))
    }

    private func pitView(_ i: Int, center: CGPoint, d: CGFloat, tint: Color) -> some View {
        let count = viewModel.pits.indices.contains(i) ? viewModel.pits[i] : 0
        let isHighlight = viewModel.highlight == i
        let mine = (i <= 5 && viewModel.currentPlayer == 0)
            || (i >= 7 && viewModel.currentPlayer == 1 && viewModel.twoPlayer)
        let playable = mine && !viewModel.animating && !viewModel.completed && count > 0
        return ZStack {
            Circle()
                .fill(tint.opacity(count > 0 ? 0.10 : 0.04))
                .overlay(Circle().stroke(tint.opacity(isHighlight ? 0.95 : (playable ? 0.6 : 0.28)), lineWidth: isHighlight ? 2.4 : 1.2))
                .shadow(color: isHighlight ? tint.opacity(0.6) : .clear, radius: 8)
            marblePile(count: count, w: d * 0.92, h: d * 0.92, capacity: 18)
            countBadge(count, fontSize: max(9, d * 0.19)).offset(y: d * 0.34)
        }
        .frame(width: d, height: d)
        // Hit shape + tap must be attached to the sized frame BEFORE .position,
        // otherwise .position expands the frame and the tap area covers the screen.
        .contentShape(Circle())
        .onTapGesture { viewModel.tapPit(i) }
        .scaleEffect(isHighlight ? 1.08 : 1)
        .position(center)
    }

    private func storeView(index: Int, center: CGPoint, w: CGFloat, h: CGFloat, tint: Color) -> some View {
        let count = viewModel.pits.indices.contains(index) ? viewModel.pits[index] : 0
        let isHighlight = viewModel.highlight == index
        return ZStack {
            Capsule()
                .fill(tint.opacity(0.10))
                .overlay(Capsule().stroke(tint.opacity(isHighlight ? 0.95 : 0.4), lineWidth: isHighlight ? 2.4 : 1.2))
                .shadow(color: isHighlight ? tint.opacity(0.6) : .clear, radius: 8)
            marblePile(count: count, w: w * 0.82, h: h * 0.92, capacity: 52)
            countBadge(count, fontSize: 15).offset(y: h * 0.40)
        }
        .frame(width: w, height: h)
        .position(center)
    }

    // The stones currently held by the "invisible hand", floating above a pocket.
    private func handCluster(count: Int, d: CGFloat) -> some View {
        let cap = 8
        let shown = min(count, cap)
        let rx = d * 0.28, ry = d * 0.28
        let mSize = min(d * 0.24, max(3.0, (2 * min(rx, ry) / CGFloat(sqrt(Double(cap)))) * 1.05))
        return ZStack {
            Circle().fill(.black.opacity(0.28)).frame(width: d * 0.72, height: d * 0.72).blur(radius: 3)
            ForEach(0..<shown, id: \.self) { k in
                let rf = CGFloat(sqrt(Double(k) / Double(cap)))
                let a = CGFloat(Double(k) * 2.399963229)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.95), MC.marble, MC.marble.opacity(0.5)],
                            center: UnitPoint(x: 0.34, y: 0.30),
                            startRadius: 0.4,
                            endRadius: mSize * 0.75
                        )
                    )
                    .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.5))
                    .frame(width: mSize, height: mSize)
                    .offset(x: cos(a) * rf * rx, y: sin(a) * rf * ry)
            }
        }
        .frame(width: d, height: d)
        .shadow(color: MC.marble.opacity(0.55), radius: 7)
    }

    private func countBadge(_ count: Int, fontSize: CGFloat) -> some View {
        Text("\(count)")
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(.black.opacity(0.6)))
            .opacity(count > 0 ? 1 : 0.4)
    }

    // A glossy pile of marbles in fixed slots (so only the newest one drops in).
    private func marblePile(count: Int, w: CGFloat, h: CGFloat, capacity: Int) -> some View {
        let rx = w * 0.40
        let ry = h * 0.40
        let mSize = min(min(w, h) * 0.34, max(3.0, (2 * min(rx, ry) / CGFloat(sqrt(Double(capacity)))) * 1.05))
        return ZStack {
            ForEach(0..<count, id: \.self) { k in
                let rf = CGFloat(sqrt(Double(k) / Double(capacity)))   // fixed slot, independent of count
                let a = CGFloat(Double(k) * 2.399963229)                // golden angle → even packing
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.95), MC.marble, MC.marble.opacity(0.5)],
                            center: UnitPoint(x: 0.34, y: 0.30),
                            startRadius: 0.4,
                            endRadius: mSize * 0.75
                        )
                    )
                    .overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.5))
                    .frame(width: mSize, height: mSize)
                    .offset(x: cos(a) * rf * rx, y: sin(a) * rf * ry)
                    .transition(.asymmetric(
                        insertion: .offset(y: -h * 0.6).combined(with: .opacity),   // dropped in from above
                        removal: .offset(y: -h * 0.6).combined(with: .opacity)      // scooped up by the hand
                    ))
            }
        }
        .frame(width: w, height: h)
        .animation(.spring(response: 0.42, dampingFraction: 0.72), value: count)
    }

    private var lossOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("OUTSCORED")
                    .font(.trajan(34))
                    .foregroundStyle(MC.cool)
                Text("\(viewModel.playerScore) – \(viewModel.aiScore)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text("The opponent gathered more stones. Try a different opening.")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                VStack(spacing: 10) {
                    conceptCapsuleButton("Try Again", filled: true, accent: MC.gold) { viewModel.reset() }
                    conceptCapsuleButton("Levels", filled: false, accent: MC.gold, action: onLevelSelect)
                }
                .padding(.top, 6)
            }
        }
        .transition(.opacity)
    }

    private var twoPlayerResultOverlay: some View {
        let p1 = viewModel.playerScore
        let p2 = viewModel.aiScore
        let title = p1 > p2 ? "PLAYER 1 WINS" : (p2 > p1 ? "PLAYER 2 WINS" : "DRAW")
        return ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(title)
                    .font(.trajan(32))
                    .foregroundStyle(MC.gold)
                    .multilineTextAlignment(.center)
                Text("\(p1) – \(p2)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                VStack(spacing: 10) {
                    conceptCapsuleButton("Play Again", filled: true, accent: MC.gold) { viewModel.reset() }
                    conceptCapsuleButton("Continue", filled: false, accent: MC.gold, action: onContinue)
                    conceptCapsuleButton("Levels", filled: false, accent: MC.gold, action: onLevelSelect)
                }
                .padding(.top, 6)
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    MathItLevelOneHundredTwoView(onContinue: {}, onLevelSelect: {})
}
