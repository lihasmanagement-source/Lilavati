import SwiftUI

struct MathItLevelOneHundredTwentyThreeView: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.31, blue: 0.25)
    private let ink = Color(red: 0.022, green: 0.03, blue: 0.04)
    private let milestones = [2.0, 4.0, 6.0]

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var zoomLevel = 0.0
    @State private var reachedMilestones: Set<Int> = []
    @State private var completed = false
    @State private var completionToken = UUID()

    private var magnification: Int {
        Int(pow(2, zoomLevel).rounded())
    }

    private var generation: Int {
        min(6, max(0, Int(zoomLevel.rounded(.down))))
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                ink.ignoresSafeArea()

                VStack(spacing: compact ? 8 : 12) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    fractalViewport
                        .frame(maxWidth: 900)
                        .frame(height: max(410, min(560, proxy.size.height * 0.65)))

                    zoomControls(compact: compact)
                        .frame(maxWidth: 760)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Infinite Scale Revealed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onChange(of: zoomLevel) { _, newValue in
            updateMilestones(for: newValue)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(milestones.indices, id: \.self) { index in
                    Capsule()
                        .fill(reachedMilestones.contains(index) ? cyan : index == nextMilestoneIndex ? gold : .white.opacity(0.13))
                        .frame(width: index == nextMilestoneIndex ? 42 : 24, height: 5)
                }
            }

            Text("SELF-SIMILAR SCALE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(gold)

            Text("FOLLOW THE GOLD TARGET")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var nextMilestoneIndex: Int? {
        milestones.indices.first { !reachedMilestones.contains($0) }
    }

    private var fractalViewport: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    drawBackground(context: &context, size: size)
                    drawFractal(context: &context, size: size)
                    drawFocusReticle(context: &context, size: size)
                }

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MAGNIFICATION")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("\(magnification)×")
                                .font(.system(size: 25, weight: .black, design: .monospaced))
                                .foregroundStyle(gold)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("GENERATION")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("n = \(generation)")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundStyle(cyan)
                        }
                    }
                    Spacer()
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.13), lineWidth: 1))
        }
    }

    private func zoomControls(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 11) {
            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white.opacity(0.55))

                Slider(value: $zoomLevel, in: 0...6)
                    .tint(gold)
                    .accessibilityLabel("Fractal zoom")
                    .accessibilityValue("\(magnification) times magnification")

                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(gold)
            }

            HStack(spacing: 0) {
                ForEach(0...6, id: \.self) { index in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(zoomLevel >= Double(index) ? sequenceColor(index) : .white.opacity(0.12))
                            .frame(width: index == generation ? 9 : 5, height: index == generation ? 9 : 5)
                        Text("\(Int(pow(2, Double(index))))×")
                            .font(.system(size: compact ? 7 : 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(index == generation ? .white : .white.opacity(0.32))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 8) {
                Text("a₀ = 1")
                Image(systemName: "arrow.right")
                Text("aₙ = 2aₙ₋₁")
                Spacer()
                Text("aₙ = 2ⁿ")
            }
            .font(.system(size: compact ? 9 : 10, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(compact ? 10 : 13)
        .background(Color(red: 0.045, green: 0.055, blue: 0.065), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1)))
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.035, green: 0.05, blue: 0.065)))

        for index in 0..<56 {
            let seed = Double(index)
            let x = CGFloat((seed * 0.6180339887).truncatingRemainder(dividingBy: 1)) * size.width
            let y = CGFloat((seed * 0.4142135623).truncatingRemainder(dividingBy: 1)) * size.height
            let radius = 0.6 + CGFloat(index % 3) * 0.35
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(.white.opacity(0.08 + Double(index % 4) * 0.025))
            )
        }
    }

    private func drawFractal(context: inout GraphicsContext, size: CGSize) {
        let viewportCenter = CGPoint(x: size.width / 2, y: size.height / 2 + 8)
        let baseSide = min(size.width, size.height) * 0.72
        let ratio = 0.36
        let fixedPoint = 0.5
        let cameraProgress = 1 - pow(ratio, zoomLevel)
        let cameraX = fixedPoint * cameraProgress
        let cameraY = fixedPoint * cameraProgress
        let cameraScale = pow(1 / ratio, zoomLevel)
        let viewport = CGRect(origin: .zero, size: size).insetBy(dx: -24, dy: -24)
        let visibleGeneration = Int(floor(zoomLevel))
        var nodeCount = 0

        func screenPoint(worldX: Double, worldY: Double) -> CGPoint {
            CGPoint(
                x: viewportCenter.x + CGFloat((worldX - cameraX) * cameraScale) * baseSide,
                y: viewportCenter.y - CGFloat((worldY - cameraY) * cameraScale) * baseSide
            )
        }

        func drawNode(worldX: Double, worldY: Double, worldSide: Double, depth: Int) {
            guard depth <= 12, nodeCount < 18_000 else { return }
            let screenCenter = screenPoint(worldX: worldX, worldY: worldY)
            let screenSide = CGFloat(worldSide * cameraScale) * baseSide
            guard screenSide >= 1.2 else { return }

            let rect = CGRect(
                x: screenCenter.x - screenSide / 2,
                y: screenCenter.y - screenSide / 2,
                width: screenSide,
                height: screenSide
            )
            guard rect.intersects(viewport) else { return }
            nodeCount += 1

            let relativeDepth = max(0, depth - visibleGeneration)
            let color = sequenceColor(relativeDepth)
            if screenSide < max(size.width, size.height) * 2.2 {
                context.fill(Path(rect), with: .color(color.opacity(depth.isMultiple(of: 2) ? 0.16 : 0.09)))
                context.stroke(
                    Path(rect),
                    with: .color(color.opacity(0.72)),
                    lineWidth: screenSide > 34 ? 1.8 : 0.8
                )

                if screenSide > 24 {
                    let inset = rect.insetBy(dx: screenSide * 0.31, dy: screenSide * 0.31)
                    context.stroke(Path(inset), with: .color(.white.opacity(0.24)), lineWidth: 1)
                }
            }

            let childSide = worldSide * ratio
            let offset = worldSide * fixedPoint * (1 - ratio)
            drawNode(worldX: worldX, worldY: worldY, worldSide: childSide, depth: depth + 1)
            drawNode(worldX: worldX - offset, worldY: worldY - offset, worldSide: childSide, depth: depth + 1)
            drawNode(worldX: worldX + offset, worldY: worldY - offset, worldSide: childSide, depth: depth + 1)
            drawNode(worldX: worldX - offset, worldY: worldY + offset, worldSide: childSide, depth: depth + 1)
            drawNode(worldX: worldX + offset, worldY: worldY + offset, worldSide: childSide, depth: depth + 1)
        }

        drawNode(worldX: 0, worldY: 0, worldSide: 1, depth: 0)
    }

    private func drawFocusReticle(context: inout GraphicsContext, size: CGSize) {
        let viewportCenter = CGPoint(x: size.width / 2, y: size.height / 2 + 8)
        let baseSide = min(size.width, size.height) * 0.72
        let ratio = 0.36
        let targetDepth = Int(floor(zoomLevel)) + 1
        let targetCoordinate = 0.5 * (1 - pow(ratio, Double(targetDepth)))
        let cameraCoordinate = 0.5 * (1 - pow(ratio, zoomLevel))
        let cameraScale = pow(1 / ratio, zoomLevel)
        let target = CGPoint(
            x: viewportCenter.x + CGFloat((targetCoordinate - cameraCoordinate) * cameraScale) * baseSide,
            y: viewportCenter.y - CGFloat((targetCoordinate - cameraCoordinate) * cameraScale) * baseSide
        )
        let pulse = 15 + CGFloat(zoomLevel.truncatingRemainder(dividingBy: 1)) * 7
        context.stroke(
            Path(ellipseIn: CGRect(x: target.x - pulse, y: target.y - pulse, width: pulse * 2, height: pulse * 2)),
            with: .color(gold.opacity(0.82)),
            style: StrokeStyle(lineWidth: 2, dash: [4, 4])
        )
        context.fill(Path(ellipseIn: CGRect(x: target.x - 3, y: target.y - 3, width: 6, height: 6)), with: .color(gold))
        context.draw(
            Text("×2")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(gold),
            at: CGPoint(x: target.x, y: target.y - pulse - 10)
        )
    }

    private func sequenceColor(_ index: Int) -> Color {
        switch index % 3 {
        case 0: cyan
        case 1: gold
        default: coral
        }
    }

    private func updateMilestones(for value: Double) {
        for (index, milestone) in milestones.enumerated() where value >= milestone {
            if reachedMilestones.insert(index).inserted {
                HapticPlayer.playLightTap()
            }
        }

        guard value >= 5.98, !completed else { return }
        let token = UUID()
        completionToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard completionToken == token, zoomLevel >= 5.98 else { return }
            HapticPlayer.playCompletionTap()
            completed = true
        }
    }

    private func resetLevel() {
        completionToken = UUID()
        zoomLevel = 0
        reachedMilestones = []
        completed = false
    }
}

#Preview {
    MathItLevelOneHundredTwentyThreeView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 123) ?? 123)
}
