import SwiftUI
import Foundation

// MARK: - Level 58 · Area and Perimeter
//
// The player is given a target AREA (soil) and PERIMETER (fence) and must set a
// width and height that satisfy BOTH — w·h = area AND 2(w+h) = perimeter — with
// no live area/perimeter counter to lean on. A dotted outline previews the plot.
// "Build" validates the dimensions, then a farmer constructs every unit of
// perimeter, plants every unit square, and waters the full area before growth.

enum GardenBuildPhase: Equatable {
    case planning
    case fencing
    case planting
    case watering
    case growing
}

struct LevelFiftyEightStage {
    let targetArea: Int
    let targetPerimeter: Int
    let maxWidth: Int
    let maxHeight: Int
    let startWidth: Int
    let startHeight: Int
}

@Observable
final class MathItLevelFiftyEightViewModel {
    let stages = [
        LevelFiftyEightStage(targetArea: 36, targetPerimeter: 24, maxWidth: 9, maxHeight: 9, startWidth: 1, startHeight: 1), // 6×6
        LevelFiftyEightStage(targetArea: 12, targetPerimeter: 14, maxWidth: 9, maxHeight: 9, startWidth: 1, startHeight: 1), // 3×4
        LevelFiftyEightStage(targetArea: 24, targetPerimeter: 22, maxWidth: 9, maxHeight: 9, startWidth: 1, startHeight: 1)  // 3×8
    ]

    var stageIndex = 0
    var width = 1
    var height = 1
    var wrongPulse = false        // drives the red flash
    var shakeCount = 0            // drives the screen shake
    var building = false          // build animation in progress
    var buildPhase: GardenBuildPhase = .planning
    var fencePiecesBuilt = 0
    var plantsPlaced = 0
    var plantsWatered = 0
    var plantGrowth: Double = 0
    var completed = false

    init() {
        width = stages[0].startWidth
        height = stages[0].startHeight
    }

    var currentStage: LevelFiftyEightStage { stages[min(stageIndex, stages.count - 1)] }

    // Stage-based only — never leaks the live area/perimeter.
    var progress: Double { completed ? 1 : Double(stageIndex) / Double(stages.count) }

    func adjustWidth(_ delta: Int) {
        adjust { width = clamp(width + delta, 1, currentStage.maxWidth) }
    }

    func adjustHeight(_ delta: Int) {
        adjust { height = clamp(height + delta, 1, currentStage.maxHeight) }
    }

    func build() {
        guard !completed, !building else { return }
        let correct = width * height == currentStage.targetArea
            && 2 * (width + height) == currentStage.targetPerimeter
        if correct { startBuild() } else { reject() }
    }

    func resetStage() {
        guard !completed, !building else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            width = currentStage.startWidth
            height = currentStage.startHeight
            wrongPulse = false
        }
    }

    private func startBuild() {
        HapticPlayer.playCompletionTap()
        building = true
        buildPhase = .fencing
        fencePiecesBuilt = 0
        plantsPlaced = 0
        plantsWatered = 0
        plantGrowth = 0
        addNextFencePiece()
    }

    private func addNextFencePiece() {
        guard building, buildPhase == .fencing else { return }
        let total = currentStage.targetPerimeter
        guard fencePiecesBuilt < total else {
            buildPhase = .planting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { self.addNextPlant() }
            return
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.76)) {
            fencePiecesBuilt += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.085) { self.addNextFencePiece() }
    }

    private func addNextPlant() {
        guard building, buildPhase == .planting else { return }
        let total = currentStage.targetArea
        guard plantsPlaced < total else {
            buildPhase = .watering
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.waterNextPlant() }
            return
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.6)) {
            plantsPlaced += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { self.addNextPlant() }
    }

    private func waterNextPlant() {
        guard building, buildPhase == .watering else { return }
        let total = currentStage.targetArea
        guard plantsWatered < total else {
            buildPhase = .growing
            withAnimation(.spring(response: 0.85, dampingFraction: 0.62)) {
                plantGrowth = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { self.finishBuild() }
            return
        }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
            plantsWatered += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.065) { self.waterNextPlant() }
    }

    private func finishBuild() {
        guard building else { return }
        HapticPlayer.playCompletionTap()
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                stageIndex += 1
                width = currentStage.startWidth
                height = currentStage.startHeight
                buildPhase = .planning
                fencePiecesBuilt = 0
                plantsPlaced = 0
                plantsWatered = 0
                plantGrowth = 0
                building = false
                wrongPulse = false
            }
        }
    }

    private func reject() {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            wrongPulse = true
            shakeCount += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) { self.wrongPulse = false }
        }
    }

    private func adjust(_ update: () -> Void) {
        guard !completed, !building else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            update()
            wrongPulse = false
        }
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        Swift.min(Swift.max(value, lower), upper)
    }
}

// MARK: - Shapes / effects

private struct RectOutline: Shape {
    let rect: CGRect
    func path(in _: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        return p
    }
}

private struct UnitGrid: Shape {
    let rect: CGRect
    let cols: Int
    let rows: Int
    func path(in _: CGRect) -> Path {
        var p = Path()
        let cw = rect.width / CGFloat(max(cols, 1))
        let ch = rect.height / CGFloat(max(rows, 1))
        for c in 0...cols {
            let x = rect.minX + CGFloat(c) * cw
            p.move(to: CGPoint(x: x, y: rect.minY)); p.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for r in 0...rows {
            let y = rect.minY + CGFloat(r) * ch
            p.move(to: CGPoint(x: rect.minX, y: y)); p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

private struct Shake: GeometryEffect {
    var amount: CGFloat = 9
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakesPerUnit), y: 0))
    }
}

// MARK: - View

struct MathItLevelFiftyEightView: View {
    var viewModel: MathItLevelFiftyEightViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry
    private let soil = Color(red: 0.36, green: 0.22, blue: 0.11)
    private let grass = Color(red: 0.16, green: 0.5, blue: 0.26)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardW = min(size.width - 36, 420)
            let boardH = min(size.height * 0.40, 330)
            let boardRect = CGRect(x: (size.width - boardW) / 2,
                                   y: size.height * 0.25,
                                   width: boardW, height: boardH)

            ZStack {
                Color.black.ignoresSafeArea()

                ZStack {
                    header(size: size)
                    board(rect: boardRect)
                    controls(size: size, board: boardRect)
                }
                .modifier(Shake(animatableData: CGFloat(viewModel.shakeCount)))

                // Whole level flashes red on a wrong build.
                Color.red.opacity(viewModel.wrongPulse ? 0.22 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Area and Perimeter Complete",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
    }

    // MARK: Header + targets

    private func header(size: CGSize) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                targetBadge(label: "SOIL", value: viewModel.currentStage.targetArea, soilStyle: true)
                targetBadge(label: "FENCE", value: viewModel.currentStage.targetPerimeter, soilStyle: false)
            }
        }
        .position(x: size.width / 2, y: 112)
    }

    private func targetBadge(label: String, value: Int, soilStyle: Bool) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(soilStyle ? grass.opacity(0.95) : accent.opacity(0.95))

            HStack(spacing: 10) {
                Group {
                    if soilStyle {
                        RoundedRectangle(cornerRadius: 3).fill(soil)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(grass.opacity(0.7), lineWidth: 1))
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(accent, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                }
                .frame(width: 24, height: 24)

                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(minWidth: 34, alignment: .leading)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: Board

    private func board(rect: CGRect) -> some View {
        let s = viewModel.currentStage
        let w = rect.width, h = rect.height
        let pad: CGFloat = 24
        let cell = min((w - pad * 2) / CGFloat(s.maxWidth), (h - pad * 2) / CGFloat(s.maxHeight))
        let uw = CGFloat(viewModel.width) * cell
        let uh = CGFloat(viewModel.height) * cell
        let r = CGRect(x: (w - uw) / 2, y: (h - uh) / 2, width: uw, height: uh)
        let building = viewModel.building

        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(viewModel.wrongPulse ? Color.red.opacity(0.85) : .white.opacity(0.14),
                        lineWidth: viewModel.wrongPulse ? 2.5 : 1.2)
                .background(.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))

            // Soil becomes rich and ready once the dimensions are validated.
            Rectangle()
                .fill(LinearGradient(colors: [grass.opacity(0.85), soil],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: uw, height: uh)
                .position(x: r.midX, y: r.midY)
                .opacity(building ? 1 : 0.4)

            // Unit cells (the area squares).
            UnitGrid(rect: r, cols: viewModel.width, rows: viewModel.height)
                .stroke(.white.opacity(0.18), lineWidth: 1)

            // Perimeter: dotted preview, then one literal fence section per unit.
            if building {
                Canvas { context, _ in
                    for index in 0..<viewModel.fencePiecesBuilt {
                        let segment = fenceSegment(index, width: viewModel.width, height: viewModel.height, rect: r)
                        var rail = Path()
                        rail.move(to: segment.start)
                        rail.addLine(to: segment.end)
                        context.stroke(
                            rail,
                            with: .color(accent),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        let post = CGRect(x: segment.start.x - 2.4, y: segment.start.y - 5.5, width: 4.8, height: 11)
                        context.fill(Path(roundedRect: post, cornerRadius: 1.2), with: .color(accent))
                    }
                }
                .shadow(color: accent.opacity(0.35), radius: 5)
            } else {
                RectOutline(rect: r)
                    .stroke(accent.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
            }

            // One plant occupies every square unit of area.
            ForEach(0..<viewModel.plantsPlaced, id: \.self) { index in
                let position = cellCenter(index, width: viewModel.width, rect: r)
                let watered = index < viewModel.plantsWatered
                let growth = watered ? 0.62 + viewModel.plantGrowth * 0.38 : 0.34
                GardenUnitPlant(growth: growth, watered: watered)
                    .frame(width: min(cell * 0.72, 30), height: min(cell * 0.8, 34))
                    .position(position)
                    .transition(.scale(scale: 0.1).combined(with: .opacity))
            }

            if building {
                GardenFarmer(action: viewModel.buildPhase)
                    .frame(width: 38, height: 48)
                    .position(farmerPosition(rect: r))
                    .animation(.easeInOut(duration: 0.085), value: viewModel.fencePiecesBuilt)
                    .animation(.easeInOut(duration: 0.06), value: viewModel.plantsPlaced)
                    .animation(.easeInOut(duration: 0.065), value: viewModel.plantsWatered)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func fenceSegment(_ index: Int, width: Int, height: Int, rect: CGRect) -> (start: CGPoint, end: CGPoint) {
        let cw = rect.width / CGFloat(width)
        let ch = rect.height / CGFloat(height)
        if index < width {
            let x = rect.minX + CGFloat(index) * cw
            return (CGPoint(x: x, y: rect.minY), CGPoint(x: x + cw, y: rect.minY))
        }
        if index < width + height {
            let offset = index - width
            let y = rect.minY + CGFloat(offset) * ch
            return (CGPoint(x: rect.maxX, y: y), CGPoint(x: rect.maxX, y: y + ch))
        }
        if index < width * 2 + height {
            let offset = index - width - height
            let x = rect.maxX - CGFloat(offset) * cw
            return (CGPoint(x: x, y: rect.maxY), CGPoint(x: x - cw, y: rect.maxY))
        }
        let offset = index - width * 2 - height
        let y = rect.maxY - CGFloat(offset) * ch
        return (CGPoint(x: rect.minX, y: y), CGPoint(x: rect.minX, y: y - ch))
    }

    private func cellCenter(_ index: Int, width: Int, rect: CGRect) -> CGPoint {
        let column = index % width
        let row = index / width
        let cellWidth = rect.width / CGFloat(width)
        let cellHeight = rect.height / CGFloat(viewModel.height)
        return CGPoint(
            x: rect.minX + (CGFloat(column) + 0.5) * cellWidth,
            y: rect.minY + (CGFloat(row) + 0.5) * cellHeight
        )
    }

    private func farmerPosition(rect: CGRect) -> CGPoint {
        switch viewModel.buildPhase {
        case .fencing:
            let index = max(0, min(viewModel.fencePiecesBuilt - 1, viewModel.currentStage.targetPerimeter - 1))
            let segment = fenceSegment(index, width: viewModel.width, height: viewModel.height, rect: rect)
            return CGPoint(x: segment.end.x, y: segment.end.y - 18)
        case .planting:
            let index = max(0, min(viewModel.plantsPlaced - 1, viewModel.currentStage.targetArea - 1))
            let cell = cellCenter(index, width: viewModel.width, rect: rect)
            return CGPoint(x: cell.x + 13, y: cell.y - 18)
        case .watering:
            let index = max(0, min(viewModel.plantsWatered - 1, viewModel.currentStage.targetArea - 1))
            let cell = cellCenter(index, width: viewModel.width, rect: rect)
            return CGPoint(x: cell.x + 15, y: cell.y - 20)
        case .growing:
            return CGPoint(x: rect.maxX + 10, y: rect.maxY - 22)
        case .planning:
            return CGPoint(x: rect.minX, y: rect.maxY)
        }
    }

    // MARK: Controls

    private func controls(size: CGSize, board: CGRect) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                // Width — left / right
                VStack(spacing: 7) {
                    Text("WIDTH")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.45))
                    HStack(spacing: 12) {
                        arrowButton("chevron.left") { viewModel.adjustWidth(-1) }
                        Text("\(viewModel.width)")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white).frame(width: 30)
                        arrowButton("chevron.right") { viewModel.adjustWidth(1) }
                    }
                }
                // Height — up / down
                VStack(spacing: 7) {
                    Text("HEIGHT")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.45))
                    arrowButton("chevron.up") { viewModel.adjustHeight(1) }
                    Text("\(viewModel.height)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white).frame(height: 26)
                    arrowButton("chevron.down") { viewModel.adjustHeight(-1) }
                }
            }

            HStack(spacing: 16) {
                roundButton(systemName: "arrow.counterclockwise", action: viewModel.resetStage)
                Button(action: viewModel.build) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 84, height: 48)
                        .background(accent, in: Capsule())
                        .shadow(color: accent.opacity(0.42), radius: 12)
                        .opacity(viewModel.building ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.building)
            }
        }
        .position(x: size.width / 2, y: min(size.height - 120, board.maxY + 108))
    }

    private func arrowButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(accent, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func roundButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.84), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct GardenUnitPlant: View {
    let growth: Double
    let watered: Bool

    private let leaf = Color(red: 0.24, green: 0.82, blue: 0.36)

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let scale = CGFloat(max(0.18, min(growth, 1)))

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color(red: 0.18, green: 0.62, blue: 0.25))
                    .frame(width: max(2, w * 0.11), height: h * 0.56)

                Ellipse()
                    .fill(leaf)
                    .frame(width: w * 0.48, height: h * 0.24)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -w * 0.16, y: -h * 0.28)

                Ellipse()
                    .fill(leaf.opacity(0.9))
                    .frame(width: w * 0.46, height: h * 0.22)
                    .rotationEffect(.degrees(26))
                    .offset(x: w * 0.16, y: -h * 0.39)

                if growth > 0.82 {
                    ZStack {
                        ForEach(0..<5, id: \.self) { petal in
                            Ellipse()
                                .fill(Color(red: 1.0, green: 0.76, blue: 0.28))
                                .frame(width: w * 0.24, height: h * 0.18)
                                .offset(y: -h * 0.10)
                                .rotationEffect(.degrees(Double(petal) * 72))
                        }
                        Circle()
                            .fill(Color(red: 0.48, green: 0.25, blue: 0.08))
                            .frame(width: w * 0.15, height: w * 0.15)
                    }
                    .offset(y: -h * 0.55)
                    .transition(.scale.combined(with: .opacity))
                }

                if watered && growth < 0.82 {
                    Circle()
                        .fill(Color.cyan.opacity(0.85))
                        .frame(width: 3.5, height: 3.5)
                        .offset(x: w * 0.26, y: -h * 0.38)
                }
            }
            .frame(width: w, height: h)
            .scaleEffect(scale, anchor: .bottom)
        }
        .allowsHitTesting(false)
    }
}

private struct GardenFarmer: View {
    let action: GardenBuildPhase

    private let overalls = Color(red: 0.22, green: 0.48, blue: 0.78)
    private let skin = Color(red: 0.84, green: 0.58, blue: 0.38)
    private let straw = Color(red: 0.94, green: 0.70, blue: 0.25)

    var body: some View {
        ZStack {
            // Legs and boots.
            Capsule().fill(overalls).frame(width: 7, height: 17).offset(x: -5, y: 14).rotationEffect(.degrees(8))
            Capsule().fill(overalls).frame(width: 7, height: 17).offset(x: 5, y: 14).rotationEffect(.degrees(-8))
            Capsule().fill(Color.black.opacity(0.85)).frame(width: 11, height: 5).offset(x: -6, y: 22)
            Capsule().fill(Color.black.opacity(0.85)).frame(width: 11, height: 5).offset(x: 7, y: 22)

            // Body and head.
            RoundedRectangle(cornerRadius: 6).fill(overalls).frame(width: 22, height: 22).offset(y: 3)
            Circle().fill(skin).frame(width: 17, height: 17).offset(y: -13)
            Circle().fill(Color.black.opacity(0.8)).frame(width: 2, height: 2).offset(x: 4, y: -14)
            Capsule().fill(straw).frame(width: 27, height: 5).offset(y: -22)
            RoundedRectangle(cornerRadius: 3).fill(straw).frame(width: 18, height: 8).offset(y: -25)

            tool
        }
        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var tool: some View {
        switch action {
        case .fencing:
            ZStack {
                Capsule().fill(Color(red: 0.47, green: 0.29, blue: 0.14)).frame(width: 4, height: 24)
                RoundedRectangle(cornerRadius: 2).fill(.gray).frame(width: 15, height: 6).offset(y: -10)
            }
            .rotationEffect(.degrees(-36), anchor: .bottom)
            .offset(x: 13, y: 2)

        case .planting:
            ZStack {
                Capsule().fill(Color(red: 0.47, green: 0.29, blue: 0.14)).frame(width: 3, height: 20)
                Path { path in
                    path.move(to: CGPoint(x: 4, y: 13))
                    path.addLine(to: CGPoint(x: 12, y: 13))
                    path.addLine(to: CGPoint(x: 8, y: 20))
                    path.closeSubpath()
                }
                .fill(.gray)
            }
            .rotationEffect(.degrees(24), anchor: .top)
            .offset(x: 12, y: 7)

        case .watering:
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.36, green: 0.72, blue: 0.92)).frame(width: 16, height: 12)
                Capsule().fill(Color(red: 0.36, green: 0.72, blue: 0.92)).frame(width: 17, height: 4).rotationEffect(.degrees(18)).offset(x: 12, y: 2)
                ForEach(0..<3, id: \.self) { drop in
                    Circle().fill(Color.cyan).frame(width: 3, height: 3)
                        .offset(x: 20 + CGFloat(drop) * 3, y: 8 + CGFloat(drop) * 4)
                }
            }
            .offset(x: 13, y: 4)

        case .growing:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.green)
                .offset(x: 14, y: -4)

        case .planning:
            EmptyView()
        }
    }
}
