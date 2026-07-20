import SwiftUI

enum LevelThirtyFourStage: Int {
    case single = 1
    case four = 4
    case sixteen = 16

    var plotCount: Int { rawValue }
}

@Observable
final class MathItLevelThirtyFourViewModel {
    var stage: LevelThirtyFourStage = .single
    var plantedPlots: Set<Int> = []
    var harvestedPlots: Set<Int> = []
    var consumedSeeds: Set<Int> = []
    var seedOffsets: [Int: CGSize] = [:]
    var completed = false

    var availableSeeds: [Int] {
        (0..<stage.plotCount).filter { !consumedSeeds.contains($0) }
    }

    var progress: Double {
        if completed { return 1 }
        switch stage {
        case .single:
            return Double(plantedPlots.count) * 0.18
        case .four:
            return 0.24 + Double(plantedPlots.count) * 0.09 + Double(harvestedPlots.count) * 0.035
        case .sixteen:
            return 0.6 + Double(plantedPlots.count) * 0.025
        }
    }

    func moveSeed(_ id: Int, translation: CGSize) {
        guard !completed, availableSeeds.contains(id) else { return }
        seedOffsets[id] = translation
    }

    func finishSeed(_ id: Int, at point: CGPoint, plotFrames: [CGRect]) {
        guard !completed, availableSeeds.contains(id) else { return }
        guard let plot = plotFrames.indices.first(where: {
            !plantedPlots.contains($0) && plotFrames[$0].insetBy(dx: -12, dy: -12).contains(point)
        }) else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                seedOffsets[id] = .zero
            }
            return
        }

        HapticPlayer.playLightTap()
        seedOffsets[id] = nil
        consumedSeeds.insert(id)
        withAnimation(.spring(response: 0.58, dampingFraction: 0.68)) {
            _ = plantedPlots.insert(plot)
        }

        if stage == .sixteen, plantedPlots.count == stage.plotCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                HapticPlayer.playCompletionTap()
                withAnimation(.spring(response: 0.64, dampingFraction: 0.8)) {
                    self.completed = true
                }
            }
        }
    }

    func pluckFlower(_ plot: Int) {
        guard plantedPlots.contains(plot), !harvestedPlots.contains(plot), stage != .sixteen else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.46, dampingFraction: 0.64)) {
            _ = harvestedPlots.insert(plot)
        }

        guard harvestedPlots.count == stage.plotCount else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.76)) {
                self.stage = self.stage == .single ? .four : .sixteen
                self.plantedPlots = []
                self.harvestedPlots = []
                self.consumedSeeds = []
                self.seedOffsets = [:]
            }
        }
    }
}

struct MathItLevelThirtyFourView: View {
    var viewModel: MathItLevelThirtyFourViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let leaf = Color.mathItAlgebra
    private let petal = Color.mathItAlgebra
    private let soil = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let field = CGRect(x: 30, y: size.height * 0.24, width: size.width - 60, height: size.height * 0.48)
            let plotFrames = plots(in: field)
            let seedSources = seedSources(in: size)

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    EmptyView()
                        .font(.trajan(34))
                        .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.34))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(leaf)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                fieldView(plotFrames: plotFrames)
                seedTray(sources: seedSources, plotFrames: plotFrames)

                CompletionOverlay(
                    title: "Level 34 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelThirtyFourStage")
            .animation(.spring(response: 0.72, dampingFraction: 0.78), value: viewModel.stage)
        }
    }

    private func plots(in field: CGRect) -> [CGRect] {
        let columns = viewModel.stage == .single ? 1 : (viewModel.stage == .four ? 2 : 4)
        let rows = columns
        let gap: CGFloat = viewModel.stage == .sixteen ? 8 : 15
        let maxCell = viewModel.stage == .single ? min(field.width * 0.52, 180) : 100
        let cell = min(
            maxCell,
            (field.width - gap * CGFloat(columns - 1)) / CGFloat(columns),
            (field.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        )
        let gridWidth = cell * CGFloat(columns) + gap * CGFloat(columns - 1)
        let gridHeight = cell * CGFloat(rows) + gap * CGFloat(rows - 1)
        let origin = CGPoint(x: field.midX - gridWidth / 2, y: field.midY - gridHeight / 2)

        return (0..<viewModel.stage.plotCount).map { index in
            let row = index / columns
            let column = index % columns
            return CGRect(
                x: origin.x + CGFloat(column) * (cell + gap),
                y: origin.y + CGFloat(row) * (cell + gap),
                width: cell,
                height: cell
            )
        }
    }

    private func seedSources(in size: CGSize) -> [Int: CGPoint] {
        let seeds = viewModel.availableSeeds
        let columns = min(8, max(1, seeds.count))
        let spacing = min(38, (size.width - 64) / CGFloat(max(columns - 1, 1)))
        let startX = size.width / 2 - spacing * CGFloat(columns - 1) / 2

        return Dictionary(uniqueKeysWithValues: seeds.enumerated().map { position, id in
            let row = position / columns
            let column = position % columns
            return (
                id,
                CGPoint(
                    x: startX + CGFloat(column) * spacing,
                    y: size.height * 0.79 + CGFloat(row) * 46
                )
            )
        })
    }

    private func fieldView(plotFrames: [CGRect]) -> some View {
        ZStack {
            ForEach(plotFrames.indices, id: \.self) { index in
                let frame = plotFrames[index]
                let planted = viewModel.plantedPlots.contains(index)
                let harvested = viewModel.harvestedPlots.contains(index)

                LevelThirtyFourPlotShape()
                    .fill(
                        LinearGradient(
                            colors: [soil.opacity(0.82), soil.opacity(0.36), .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        LevelThirtyFourPlotShape()
                            .stroke(planted ? leaf.opacity(0.54) : .white.opacity(0.18), lineWidth: 1.2)
                    }
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)

                if planted && !harvested {
                    LevelThirtyFourFlower(compact: viewModel.stage == .sixteen, leaf: leaf, petal: petal)
                        .frame(width: frame.width * 0.78, height: frame.height * 0.92)
                        .position(x: frame.midX, y: frame.midY - frame.height * 0.13)
                        .transition(.scale(scale: 0.08, anchor: .bottom).combined(with: .opacity))
                        .onTapGesture { viewModel.pluckFlower(index) }
                }

                if harvested {
                    ForEach(0..<4, id: \.self) { seed in
                        LevelThirtyFourSeed()
                            .fill(.white)
                            .frame(width: 8, height: 13)
                            .rotationEffect(.degrees(Double(seed) * 90 + 25))
                            .position(
                                x: frame.midX + cos(CGFloat(seed) * .pi / 2) * frame.width * 0.2,
                                y: frame.midY + sin(CGFloat(seed) * .pi / 2) * frame.height * 0.14
                            )
                            .shadow(color: leaf.opacity(0.8), radius: 5)
                    }
                }
            }
        }
    }

    private func seedTray(sources: [Int: CGPoint], plotFrames: [CGRect]) -> some View {
        ZStack {
            ForEach(viewModel.availableSeeds, id: \.self) { id in
                if let source = sources[id] {
                    let offset = viewModel.seedOffsets[id, default: .zero]
                    LevelThirtyFourSeed()
                        .fill(.white)
                        .frame(width: 15, height: 23)
                        .shadow(color: leaf.opacity(0.72), radius: 8)
                        .position(x: source.x + offset.width, y: source.y + offset.height)
                        .gesture(
                            DragGesture(coordinateSpace: .named("levelThirtyFourStage"))
                                .onChanged { value in
                                    viewModel.moveSeed(id, translation: value.translation)
                                }
                                .onEnded { value in
                                    viewModel.finishSeed(
                                        id,
                                        at: CGPoint(x: source.x + value.translation.width, y: source.y + value.translation.height),
                                        plotFrames: plotFrames
                                    )
                                }
                        )
                }
            }
        }
        .zIndex(8)
    }
}

private struct LevelThirtyFourPlotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct LevelThirtyFourSeed: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.24),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.74)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.74),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.24)
        )
        path.closeSubpath()
        return path
    }
}

private struct LevelThirtyFourFlower: View {
    let compact: Bool
    let leaf: Color
    let petal: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Capsule()
                    .fill(leaf.opacity(0.82))
                    .frame(width: max(2, size.width * 0.035), height: size.height * 0.62)
                    .position(x: size.width / 2, y: size.height * 0.68)

                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [petal, petal.opacity(0.28)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size.width * 0.24, height: size.height * 0.34)
                        .offset(y: -size.height * 0.16)
                        .rotationEffect(.degrees(Double(index) * 60), anchor: .bottom)
                }

                Circle()
                    .fill(.white)
                    .frame(width: size.width * 0.2, height: size.width * 0.2)
                    .shadow(color: petal.opacity(0.8), radius: compact ? 3 : 7)
                    .position(x: size.width / 2, y: size.height * 0.31)

                Capsule()
                    .fill(leaf.opacity(0.7))
                    .frame(width: size.width * 0.28, height: size.height * 0.1)
                    .rotationEffect(.degrees(-28))
                    .position(x: size.width * 0.38, y: size.height * 0.68)
            }
        }
        .contentShape(Rectangle())
    }
}
