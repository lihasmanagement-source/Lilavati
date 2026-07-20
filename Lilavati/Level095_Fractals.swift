import SwiftUI

@Observable
final class MathItLevelTwentySevenViewModel {
    var expandedPaths: Set<String> = []
    var flowStartedAt: Date?
    var completed = false

    let finalDepth = 5

    var progress: Double {
        if completed { return 1 }
        return min(0.96, Double(expandedPaths.count) / Double(totalExpandableBranches))
    }

    func expand(path: String) {
        guard !completed, flowStartedAt == nil, path.count < finalDepth, !expandedPaths.contains(path) else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.46, dampingFraction: 0.8)) {
            _ = expandedPaths.insert(path)
        }

        guard expandedPaths.count == totalExpandableBranches else { return }
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.flowStartedAt = Date()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    private var totalExpandableBranches: Int {
        1 + (1..<finalDepth).reduce(0) { $0 + (1 << $1) }
    }
}

struct LevelTwentySevenBranch: Identifiable {
    let id: String
    let parentPath: String
    let depth: Int
    let start: CGPoint
    let end: CGPoint
}

struct MathItLevelTwentySevenView: View {
    var viewModel: MathItLevelTwentySevenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let green = Color.mathItLogic

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 18, y: size.height * 0.18, width: size.width - 36, height: min(570, size.height * 0.67))
            let branches = fractalBranches(in: board)
            let visible = branches.filter(isVisible)
            let activeTips = branches.filter(isActiveTip)

            ZStack {
                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    EmptyView()
                        .font(.trajan(36))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(green)
                    .opacity(0.78)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.012))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(green.opacity(0.22), lineWidth: 1.1)
                    }
                    .frame(width: board.width, height: board.height)
                    .position(x: board.midX, y: board.midY)

                ForEach(visible) { branch in
                    Path { path in
                        path.move(to: branch.start)
                        path.addLine(to: branch.end)
                    }
                    .stroke(
                        green.opacity(max(0.36, 1 - Double(branch.depth) * 0.1)),
                        style: StrokeStyle(lineWidth: max(1, 3.4 - CGFloat(branch.depth) * 0.45), lineCap: .round)
                    )
                    .shadow(color: green.opacity(0.36), radius: 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.72, anchor: .bottom)))
                }

                ForEach(activeTips) { branch in
                    Circle()
                        .fill(.black)
                        .overlay {
                            Circle().stroke(green, lineWidth: 1.8)
                        }
                        .frame(width: 13, height: 13)
                        .shadow(color: green.opacity(0.95), radius: 12)
                    .position(branch.end)
                }

                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: board.width, height: board.height)
                    .position(x: board.midX, y: board.midY)
                    .gesture(
                        SpatialTapGesture(coordinateSpace: .named("levelTwentySevenStage"))
                            .onEnded { value in
                                tapEndpoint(at: value.location, activeTips: activeTips)
                            }
                    )

                if let flowStartedAt = viewModel.flowStartedAt {
                    TimelineView(.animation) { context in
                        let elapsed = context.date.timeIntervalSince(flowStartedAt)
                        let flowProgress = min(1, max(0, elapsed / 4.4))

                        ZStack {
                            ForEach(leafPaths(), id: \.self) { leafPath in
                                Circle()
                                    .fill(green)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: green, radius: 9)
                                    .position(
                                        flowPoint(
                                            progress: flowProgress,
                                            leafPath: leafPath,
                                            branches: branches
                                        )
                                    )
                            }
                        }
                    }
                }

                ForEach(visible.filter { viewModel.expandedPaths.contains($0.id) }) { branch in
                    Circle()
                        .fill(green.opacity(0.7))
                        .frame(width: 6, height: 6)
                        .position(branch.end)
                }

                if viewModel.flowStartedAt != nil {
                    Circle()
                        .fill(green)
                        .frame(width: 10, height: 10)
                        .shadow(color: green, radius: 12)
                        .position(branches[0].start)
                        .transition(.scale.combined(with: .opacity))
                }

                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 20, weight: .light))
                    HStack(spacing: 12) {
                        ForEach(0..<viewModel.finalDepth, id: \.self) { depth in
                            Circle()
                                .fill(generationComplete(depth: depth) ? green : .white.opacity(0.14))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
                .foregroundStyle(green.opacity(0.62))
                .position(x: board.midX, y: board.maxY - 34)

                CompletionOverlay(
                    title: "Level 27 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelTwentySevenStage")
        }
    }

    private func tapEndpoint(at point: CGPoint, activeTips: [LevelTwentySevenBranch]) {
        guard let nearest = activeTips.min(by: {
            hypot(point.x - $0.end.x, point.y - $0.end.y) <
                hypot(point.x - $1.end.x, point.y - $1.end.y)
        }), hypot(point.x - nearest.end.x, point.y - nearest.end.y) <= 46 else { return }
        viewModel.expand(path: nearest.id)
    }

    private func isActiveTip(_ branch: LevelTwentySevenBranch) -> Bool {
        guard branch.depth < viewModel.finalDepth,
              isVisible(branch),
              !viewModel.expandedPaths.contains(branch.id),
              viewModel.flowStartedAt == nil else { return false }
        return true
    }

    private func isVisible(_ branch: LevelTwentySevenBranch) -> Bool {
        branch.depth == 0 ||
            (branch.depth == 1 && viewModel.expandedPaths.contains("")) ||
            (branch.depth > 1 && viewModel.expandedPaths.contains(branch.parentPath))
    }

    private func generationComplete(depth: Int) -> Bool {
        if depth == 0 {
            return viewModel.expandedPaths.contains("")
        }
        return viewModel.expandedPaths.filter { $0.count == depth }.count == (1 << depth)
    }

    private func leafPaths() -> [String] {
        func paths(prefix: String, depth: Int) -> [String] {
            guard depth < viewModel.finalDepth else { return [prefix] }
            return paths(prefix: prefix + "L", depth: depth + 1) +
                paths(prefix: prefix + "R", depth: depth + 1)
        }
        return paths(prefix: "", depth: 0)
    }

    private func flowPoint(
        progress: Double,
        leafPath: String,
        branches: [LevelTwentySevenBranch]
    ) -> CGPoint {
        guard let trunk = branches.first else { return .zero }
        let branchLookup = Dictionary(uniqueKeysWithValues: branches.map { ($0.id, $0) })
        var points = [trunk.start, trunk.end]
        var prefix = ""

        for character in leafPath {
            prefix.append(character)
            if let branch = branchLookup[prefix] {
                points.append(branch.end)
            }
        }

        let segmentProgress = progress * Double(points.count - 1)
        let segment = min(points.count - 2, Int(segmentProgress))
        let local = CGFloat(segmentProgress - Double(segment))
        let start = points[segment]
        let end = points[segment + 1]
        return CGPoint(
            x: start.x + (end.x - start.x) * local,
            y: start.y + (end.y - start.y) * local
        )
    }

    private func fractalBranches(in board: CGRect) -> [LevelTwentySevenBranch] {
        let root = CGPoint(x: board.midX, y: board.maxY - 72)
        let trunkEnd = CGPoint(x: board.midX, y: root.y - board.height * 0.22)
        var branches = [
            LevelTwentySevenBranch(id: "", parentPath: "", depth: 0, start: root, end: trunkEnd)
        ]
        appendBranches(
            from: trunkEnd,
            angle: -.pi / 2,
            length: board.width * 0.22,
            depth: 1,
            path: "",
            into: &branches
        )
        return branches
    }

    private func appendBranches(
        from start: CGPoint,
        angle: CGFloat,
        length: CGFloat,
        depth: Int,
        path: String,
        into branches: inout [LevelTwentySevenBranch]
    ) {
        guard depth <= viewModel.finalDepth + 1 else { return }

        for (suffix, turn) in [("L", -CGFloat.pi / 5.2), ("R", CGFloat.pi / 5.2)] {
            let childPath = path + suffix
            let childAngle = angle + turn
            let end = CGPoint(
                x: start.x + cos(childAngle) * length,
                y: start.y + sin(childAngle) * length
            )
            branches.append(
                LevelTwentySevenBranch(
                    id: childPath,
                    parentPath: path,
                    depth: depth,
                    start: start,
                    end: end
                )
            )
            appendBranches(
                from: end,
                angle: childAngle,
                length: length * 0.64,
                depth: depth + 1,
                path: childPath,
                into: &branches
            )
        }
    }
}
