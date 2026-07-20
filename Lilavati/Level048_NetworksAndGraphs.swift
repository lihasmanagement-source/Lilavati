import SwiftUI

@Observable
final class MathItLevelTwentyThreeViewModel {
    var selectedStarIDs: [Int] = []
    var traversedEdgeIDs: Set<String> = []
    var dragPoint: CGPoint?
    var completed = false
    var recentStarID: Int?
    var constellationIndex = 0

    let constellations = LevelTwentyThreeConstellation.all

    private let hitRadius: CGFloat = 34

    var currentConstellation: LevelTwentyThreeConstellation {
        constellations[min(constellationIndex, constellations.count - 1)]
    }

    var stars: [LevelTwentyThreeStar] {
        currentConstellation.stars
    }

    var edges: [LevelTwentyThreeEdge] {
        currentConstellation.edges
    }

    var progress: Double {
        if completed { return 1 }
        let completedEdges = constellations[..<constellationIndex].reduce(0) { $0 + $1.edges.count }
        let totalEdges = constellations.reduce(0) { $0 + $1.edges.count }
        return Double(completedEdges + traversedEdgeIDs.count) / Double(totalEdges)
    }

    var oddStarIDs: Set<Int> {
        var degrees: [Int: Int] = [:]
        for edge in edges {
            degrees[edge.from, default: 0] += 1
            degrees[edge.to, default: 0] += 1
        }
        return Set(degrees.filter { !$0.value.isMultiple(of: 2) }.map(\.key))
    }

    func reset() {
        HapticPlayer.playLightTap()
        resetAttempt(playHaptic: false)
    }

    func begin(at point: CGPoint, starPositions: [Int: CGPoint]) {
        guard !completed, let starID = nearestStar(to: point, starPositions: starPositions) else { return }
        selectedStarIDs = [starID]
        traversedEdgeIDs = []
        dragPoint = starPositions[starID]
        recentStarID = starID
        HapticPlayer.playLightTap()
        clearRecentStar(after: 0.18, id: starID)
    }

    func drag(to point: CGPoint, starPositions: [Int: CGPoint]) {
        guard !completed, let lastID = selectedStarIDs.last else { return }
        dragPoint = point

        guard let nextID = nearestStar(to: point, starPositions: starPositions), nextID != lastID else { return }

        guard let edge = edgeBetween(lastID, nextID) else {
            resetAttempt()
            return
        }

        guard !traversedEdgeIDs.contains(edge.id) else {
            resetAttempt()
            return
        }

        guard let from = starPositions[lastID], let to = starPositions[nextID] else { return }
        guard !wouldCrossExistingLine(from: from, to: to, edgeID: edge.id, starPositions: starPositions) else {
            resetAttempt()
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            selectedStarIDs.append(nextID)
            traversedEdgeIDs.insert(edge.id)
            dragPoint = to
            recentStarID = nextID
        }
        clearRecentStar(after: 0.18, id: nextID)
        checkCompletion()
    }

    func endDrag() {
        guard !completed else { return }
        dragPoint = nil
    }

    private func checkCompletion() {
        guard traversedEdgeIDs.count == edges.count, !completed else { return }
        HapticPlayer.playCompletionTap()
        dragPoint = nil

        guard constellationIndex < constellations.count - 1 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                    self.completed = true
                }
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                self.constellationIndex += 1
                self.selectedStarIDs = []
                self.traversedEdgeIDs = []
                self.dragPoint = nil
                self.recentStarID = nil
            }
        }
    }

    private func resetAttempt(playHaptic: Bool = true) {
        if playHaptic, !selectedStarIDs.isEmpty {
            HapticPlayer.playLightTap()
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            selectedStarIDs = []
            traversedEdgeIDs = []
            dragPoint = nil
            recentStarID = nil
        }
    }

    private func nearestStar(to point: CGPoint, starPositions: [Int: CGPoint]) -> Int? {
        starPositions.min {
            hypot(point.x - $0.value.x, point.y - $0.value.y) < hypot(point.x - $1.value.x, point.y - $1.value.y)
        }.flatMap { hypot(point.x - $0.value.x, point.y - $0.value.y) <= hitRadius ? $0.key : nil }
    }

    private func edgeBetween(_ first: Int, _ second: Int) -> LevelTwentyThreeEdge? {
        edges.first { edge in
            (edge.from == first && edge.to == second) || (edge.from == second && edge.to == first)
        }
    }

    private func wouldCrossExistingLine(from: CGPoint, to: CGPoint, edgeID: String, starPositions: [Int: CGPoint]) -> Bool {
        guard !traversedEdgeIDs.isEmpty else { return false }

        for edge in edges where traversedEdgeIDs.contains(edge.id) && edge.id != edgeID {
            if edge.id == edgeID || edge.sharesEndpoint(with: edgeID) { continue }
            guard let first = starPositions[edge.from], let second = starPositions[edge.to] else { continue }
            if segmentsIntersect(from, to, first, second) {
                return true
            }
        }

        return false
    }

    private func segmentsIntersect(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        let first = orientation(a, b, c)
        let second = orientation(a, b, d)
        let third = orientation(c, d, a)
        let fourth = orientation(c, d, b)
        return first * second < 0 && third * fourth < 0
    }

    private func orientation(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    private func clearRecentStar(after delay: Double, id: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.recentStarID == id {
                self.recentStarID = nil
            }
        }
    }
}

struct LevelTwentyThreeStar: Identifiable {
    let id: Int
    let position: CGPoint
}

struct LevelTwentyThreeConstellation {
    let stars: [LevelTwentyThreeStar]
    let edges: [LevelTwentyThreeEdge]

    static let all = [
        LevelTwentyThreeConstellation(
            stars: [
                LevelTwentyThreeStar(id: 0, position: CGPoint(x: 0.22, y: 0.44)),
                LevelTwentyThreeStar(id: 1, position: CGPoint(x: 0.34, y: 0.20)),
                LevelTwentyThreeStar(id: 2, position: CGPoint(x: 0.52, y: 0.30)),
                LevelTwentyThreeStar(id: 3, position: CGPoint(x: 0.72, y: 0.28)),
                LevelTwentyThreeStar(id: 4, position: CGPoint(x: 0.50, y: 0.48)),
                LevelTwentyThreeStar(id: 5, position: CGPoint(x: 0.80, y: 0.64)),
                LevelTwentyThreeStar(id: 6, position: CGPoint(x: 0.74, y: 0.78))
            ],
            edges: [
                LevelTwentyThreeEdge(from: 4, to: 0),
                LevelTwentyThreeEdge(from: 0, to: 1),
                LevelTwentyThreeEdge(from: 1, to: 2),
                LevelTwentyThreeEdge(from: 2, to: 3),
                LevelTwentyThreeEdge(from: 3, to: 5),
                LevelTwentyThreeEdge(from: 5, to: 2),
                LevelTwentyThreeEdge(from: 2, to: 4),
                LevelTwentyThreeEdge(from: 4, to: 5),
                LevelTwentyThreeEdge(from: 5, to: 6)
            ]
        ),
        LevelTwentyThreeConstellation(
            stars: [
                LevelTwentyThreeStar(id: 0, position: CGPoint(x: 0.18, y: 0.30)),
                LevelTwentyThreeStar(id: 1, position: CGPoint(x: 0.36, y: 0.20)),
                LevelTwentyThreeStar(id: 2, position: CGPoint(x: 0.58, y: 0.27)),
                LevelTwentyThreeStar(id: 3, position: CGPoint(x: 0.78, y: 0.22)),
                LevelTwentyThreeStar(id: 4, position: CGPoint(x: 0.42, y: 0.48)),
                LevelTwentyThreeStar(id: 5, position: CGPoint(x: 0.66, y: 0.55)),
                LevelTwentyThreeStar(id: 6, position: CGPoint(x: 0.30, y: 0.72)),
                LevelTwentyThreeStar(id: 7, position: CGPoint(x: 0.78, y: 0.78))
            ],
            edges: [
                LevelTwentyThreeEdge(from: 0, to: 1),
                LevelTwentyThreeEdge(from: 1, to: 2),
                LevelTwentyThreeEdge(from: 2, to: 3),
                LevelTwentyThreeEdge(from: 2, to: 4),
                LevelTwentyThreeEdge(from: 4, to: 0),
                LevelTwentyThreeEdge(from: 4, to: 5),
                LevelTwentyThreeEdge(from: 5, to: 2),
                LevelTwentyThreeEdge(from: 4, to: 6),
                LevelTwentyThreeEdge(from: 5, to: 7),
                LevelTwentyThreeEdge(from: 6, to: 7)
            ]
        ),
        LevelTwentyThreeConstellation(
            stars: [
                LevelTwentyThreeStar(id: 0, position: CGPoint(x: 0.18, y: 0.62)),
                LevelTwentyThreeStar(id: 1, position: CGPoint(x: 0.34, y: 0.42)),
                LevelTwentyThreeStar(id: 2, position: CGPoint(x: 0.48, y: 0.22)),
                LevelTwentyThreeStar(id: 3, position: CGPoint(x: 0.66, y: 0.34)),
                LevelTwentyThreeStar(id: 4, position: CGPoint(x: 0.82, y: 0.56)),
                LevelTwentyThreeStar(id: 5, position: CGPoint(x: 0.58, y: 0.66)),
                LevelTwentyThreeStar(id: 6, position: CGPoint(x: 0.38, y: 0.78))
            ],
            edges: [
                LevelTwentyThreeEdge(from: 0, to: 1),
                LevelTwentyThreeEdge(from: 1, to: 2),
                LevelTwentyThreeEdge(from: 2, to: 3),
                LevelTwentyThreeEdge(from: 3, to: 4),
                LevelTwentyThreeEdge(from: 4, to: 5),
                LevelTwentyThreeEdge(from: 5, to: 6),
                LevelTwentyThreeEdge(from: 6, to: 0),
                LevelTwentyThreeEdge(from: 1, to: 5),
                LevelTwentyThreeEdge(from: 5, to: 3)
            ]
        )
    ]
}

struct LevelTwentyThreeEdge: Identifiable, Hashable {
    let from: Int
    let to: Int

    var id: String {
        "\(min(from, to))-\(max(from, to))"
    }

    func sharesEndpoint(with edgeID: String) -> Bool {
        let parts = edgeID.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return false }
        return from == parts[0] || from == parts[1] || to == parts[0] || to == parts[1]
    }
}

struct MathItLevelTwentyThreeView: View {
    var viewModel: MathItLevelTwentyThreeViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    @State private var stage = 1
    @State private var pyramidViewModel = MathItLevelThirteenViewModel()

    var body: some View {
        ZStack {
            if stage == 1 {
                constellationStage
                    .transition(.opacity)
            } else {
                GeometryReader { proxy in
                    ZStack {
                        MathItLevelThirteenView(
                            viewModel: pyramidViewModel,
                            onContinue: onContinue,
                            onReplay: onReplay,
                            onLevelSelect: onLevelSelect,
                            showsMusicGraphFollowUp: false,
                            completionTitle: "Networks & Graphs Complete",
                            stageLabel: "STAGE 4 OF 4",
                            progressBase: 0.75,
                            progressScale: 0.25
                        )
                        .id(ObjectIdentifier(pyramidViewModel))

                        stageIndicator(current: 3)
                            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.785)
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: viewModel.completed) { _, isComplete in
            guard isComplete, stage == 1 else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                stage = 2
            }
        }
    }

    private var constellationStage: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 20, y: size.height * 0.17, width: size.width - 40, height: min(430, size.height * 0.58))
            let starPositions = Dictionary(uniqueKeysWithValues: viewModel.stars.map { star in
                (star.id, normalizedPoint(star.position, in: board))
            })

            ZStack {
                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    Text("STAGE \(viewModel.constellationIndex + 1) OF 4")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    EmptyView()
                        .font(.trajan(36))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress * 0.75)
                    .tint(.white)
                    .opacity(0.72)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                constellationBoard(board: board, starPositions: starPositions)

                stageIndicator(current: viewModel.constellationIndex)
                    .position(x: size.width / 2, y: size.height * 0.785)

                resetButton
                    .position(x: size.width / 2, y: size.height * 0.83)

            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("levelTwentyThreeStage"))
                    .onChanged { value in
                        if viewModel.selectedStarIDs.isEmpty {
                            viewModel.begin(at: value.location, starPositions: starPositions)
                        } else {
                            viewModel.drag(to: value.location, starPositions: starPositions)
                        }
                    }
                    .onEnded { _ in
                        viewModel.endDrag()
                    }
            )
            .coordinateSpace(name: "levelTwentyThreeStage")
        }
    }

    private func constellationBoard(board: CGRect, starPositions: [Int: CGPoint]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(.white.opacity(0.025))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.mathItLogic.opacity(0.34), lineWidth: 1.2)
                }
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            starField(in: board)

            stellarLinks(starPositions: starPositions)

            drawnPath(starPositions: starPositions)

            if let lastID = viewModel.selectedStarIDs.last,
               let start = starPositions[lastID],
               let dragPoint = viewModel.dragPoint,
               !viewModel.completed {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: dragPoint)
                }
                .stroke(Color.mathItLogic.opacity(0.42), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [5, 5]))
                .shadow(color: Color.mathItLogic.opacity(0.24), radius: 10)
            }

            ForEach(viewModel.stars) { star in
                if let point = starPositions[star.id] {
                    starView(starID: star.id)
                        .position(point)
                }
            }
        }
    }

    private func stellarLinks(starPositions: [Int: CGPoint]) -> some View {
        ZStack {
            ForEach(viewModel.edges) { edge in
                if let start = starPositions[edge.from], let end = starPositions[edge.to] {
                    let isTraversed = viewModel.traversedEdgeIDs.contains(edge.id)

                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(
                        isTraversed ? Color.mathItLogic.opacity(0.82) : .white.opacity(0.24),
                        style: StrokeStyle(lineWidth: isTraversed ? 3 : 2, lineCap: .round, dash: isTraversed ? [] : [4, 5])
                    )
                    .shadow(color: Color.mathItLogic.opacity(isTraversed ? 0.48 : 0.1), radius: isTraversed ? 12 : 5)
                }
            }
        }
    }

    private func drawnPath(starPositions: [Int: CGPoint]) -> some View {
        Path { path in
            guard let firstID = viewModel.selectedStarIDs.first, let first = starPositions[firstID] else { return }
            path.move(to: first)
            for id in viewModel.selectedStarIDs.dropFirst() {
                if let point = starPositions[id] {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(Color.mathItLogic.opacity(0.82), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .shadow(color: Color.mathItLogic.opacity(0.54), radius: 12)
    }

    private func starView(starID: Int) -> some View {
        let isSelected = viewModel.selectedStarIDs.contains(starID)
        let isRecent = viewModel.recentStarID == starID

        return Circle()
            .fill(isSelected ? Color.mathItLogic.opacity(0.94) : .white.opacity(0.92))
            .frame(width: isRecent ? 25 : isSelected ? 21 : 18, height: isRecent ? 25 : isSelected ? 21 : 18)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.84), lineWidth: isSelected ? 1.6 : 1.1)
            }
            .shadow(color: Color.mathItLogic.opacity(isRecent ? 0.9 : isSelected ? 0.62 : 0.34), radius: isRecent ? 18 : 10)
            .contentShape(Circle())
    }

    private func starField(in board: CGRect) -> some View {
        ZStack {
            ForEach(0..<42, id: \.self) { index in
                let point = backgroundStar(index: index, in: board)
                let size = CGFloat([2, 2, 3, 4][index % 4])
                Circle()
                    .fill(index.isMultiple(of: 9) ? Color.mathItLogic.opacity(0.72) : .white.opacity(0.56))
                    .frame(width: size, height: size)
                    .shadow(color: Color.mathItLogic.opacity(index.isMultiple(of: 9) ? 0.42 : 0.08), radius: 6)
                    .position(point)
            }
        }
    }

    private func backgroundStar(index: Int, in board: CGRect) -> CGPoint {
        let x = board.minX + board.width * CGFloat((index * 37 + 11) % 100) / 100
        let y = board.minY + board.height * CGFloat((index * 53 + 19) % 100) / 100
        return CGPoint(x: x, y: y)
    }

    private func stageIndicator(current: Int) -> some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index <= current ? Color.mathItLogic.opacity(0.86) : .white.opacity(0.18))
                    .frame(width: index == current ? 10 : 7, height: index == current ? 10 : 7)
                    .shadow(color: Color.mathItLogic.opacity(index == current ? 0.52 : 0), radius: 8)
            }
        }
    }

    private var resetButton: some View {
        Button(action: viewModel.reset) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset")
    }

    private func normalizedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * point.x,
            y: rect.minY + rect.height * point.y
        )
    }
}
