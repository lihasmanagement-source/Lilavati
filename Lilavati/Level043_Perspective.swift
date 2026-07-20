import SwiftUI
import Foundation

enum LevelSixtyOnePerspectiveKind {
    case onePoint
    case twoPoint
    case threePoint
}

struct LevelSixtyOneStage {
    let title: String
    let kind: LevelSixtyOnePerspectiveKind
    let targets: [CGPoint]
    let starts: [CGPoint]
}

struct LevelSixtyOneBuilding: Identifiable {
    let id = UUID()
    let outerX: CGFloat
    let streetX: CGFloat
    let topY: CGFloat
    let bottomY: CGFloat
    let depth: CGFloat
    let floors: Int
    let bays: Int
}

@Observable
final class MathItLevelSixtyOneViewModel {
    let stages = [
        LevelSixtyOneStage(
            title: "one-point perspective",
            kind: .onePoint,
            targets: [CGPoint(x: 0.5, y: 0.62)],
            starts: [CGPoint(x: 0.34, y: 0.47)]
        ),
        LevelSixtyOneStage(
            title: "two-point perspective",
            kind: .twoPoint,
            targets: [CGPoint(x: 0.1, y: 0.58), CGPoint(x: 0.9, y: 0.58)],
            starts: [CGPoint(x: 0.22, y: 0.44), CGPoint(x: 0.78, y: 0.72)]
        ),
        LevelSixtyOneStage(
            title: "three-point perspective",
            kind: .threePoint,
            targets: [CGPoint(x: 0.5, y: 0.12), CGPoint(x: 0.08, y: 0.74), CGPoint(x: 0.92, y: 0.74)],
            starts: [CGPoint(x: 0.58, y: 0.24), CGPoint(x: 0.18, y: 0.62), CGPoint(x: 0.8, y: 0.66)]
        )
    ]

    var stageIndex = 0
    var vanishingPoints: [CGPoint] = []
    var completed = false
    var advancing = false

    init() {
        vanishingPoints = stages[0].starts
    }

    var currentStage: LevelSixtyOneStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        return (Double(stageIndex) + Double(alignmentStrength)) / Double(stages.count)
    }

    var alignmentStrength: CGFloat {
        guard !currentStage.targets.isEmpty else { return 0 }
        let strengths = currentStage.targets.indices.map { index in
            guard vanishingPoints.indices.contains(index) else { return CGFloat(0) }
            let point = vanishingPoints[index]
            let target = currentStage.targets[index]
            let distance = hypot(point.x - target.x, point.y - target.y)
            return 1 - min(1, distance / 0.26)
        }
        return strengths.reduce(0, +) / CGFloat(strengths.count)
    }

    func setVanishingPoint(index: Int, value: CGPoint) {
        guard !completed, !advancing, vanishingPoints.indices.contains(index) else { return }
        vanishingPoints[index] = CGPoint(
            x: min(max(value.x, 0.04), 0.96),
            y: min(max(value.y, 0.08), 0.92)
        )
    }

    func finishIfAligned() {
        guard !completed, !advancing else { return }
        let solved = currentStage.targets.indices.allSatisfy { index in
            guard vanishingPoints.indices.contains(index) else { return false }
            let point = vanishingPoints[index]
            let target = currentStage.targets[index]
            return hypot(point.x - target.x, point.y - target.y) <= 0.055
        }

        if solved {
            advancing = true
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                self.advance()
            }
        }
    }

    func resetStage() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            vanishingPoints = currentStage.starts
            advancing = false
        }
    }

    private func advance() {
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                stageIndex += 1
                vanishingPoints = stages[stageIndex].starts
                advancing = false
            }
        }
    }
}

struct MathItLevelSixtyOneView: View {
    var viewModel: MathItLevelSixtyOneViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry
    private let buildings = [
        LevelSixtyOneBuilding(outerX: 0.02, streetX: 0.26, topY: 0.17, bottomY: 0.86, depth: 0.9, floors: 4, bays: 3),
        LevelSixtyOneBuilding(outerX: 0.18, streetX: 0.39, topY: 0.32, bottomY: 0.78, depth: 0.65, floors: 3, bays: 2),
        LevelSixtyOneBuilding(outerX: 0.34, streetX: 0.44, topY: 0.49, bottomY: 0.7, depth: 0.4, floors: 2, bays: 1),
        LevelSixtyOneBuilding(outerX: 0.98, streetX: 0.74, topY: 0.13, bottomY: 0.86, depth: 0.9, floors: 4, bays: 3),
        LevelSixtyOneBuilding(outerX: 0.84, streetX: 0.62, topY: 0.28, bottomY: 0.79, depth: 0.62, floors: 3, bays: 2),
        LevelSixtyOneBuilding(outerX: 0.68, streetX: 0.57, topY: 0.5, bottomY: 0.7, depth: 0.38, floors: 2, bays: 1)
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardWidth = min(size.width - 40, 440)
            let boardHeight = min(size.height * 0.56, 440)
            let boardRect = CGRect(
                x: (size.width - boardWidth) / 2,
                y: size.height * 0.22,
                width: boardWidth,
                height: boardHeight
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                perspectiveBoard(rect: boardRect)

                CompletionOverlay(
                    title: "Level 61 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func perspectiveBoard(rect: CGRect) -> some View {
        let localRect = CGRect(origin: .zero, size: rect.size)

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.18), lineWidth: 1.2)
                .background(.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 8))

            starField(rect: localRect)

            stageHorizon(rect: localRect)

            stageScene(rect: localRect)

            targetRings(rect: localRect)

            ForEach(Array(viewModel.vanishingPoints.indices), id: \.self) { index in
                vanishingHandle(index: index, rect: localRect)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .coordinateSpace(name: "levelSixtyOneBoard")
        .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    private func stageScene(rect: CGRect) -> some View {
        switch viewModel.currentStage.kind {
        case .onePoint:
            onePointScene(rect: rect)
        case .twoPoint:
            twoPointScene(rect: rect)
        case .threePoint:
            threePointScene(rect: rect)
        }
    }

    private func starField(rect: CGRect) -> some View {
        ZStack {
            ForEach(0..<22, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index.isMultiple(of: 3) ? 0.16 : 0.08))
                    .frame(width: index.isMultiple(of: 4) ? 3 : 2, height: index.isMultiple(of: 4) ? 3 : 2)
                    .position(
                        x: rect.width * CGFloat((index * 37) % 100) / 100,
                        y: rect.height * CGFloat((index * 19) % 42) / 100 + 16
                    )
            }
        }
    }

    private func stageHorizon(rect: CGRect) -> some View {
        let y: CGFloat
        switch viewModel.currentStage.kind {
        case .onePoint:
            y = targetPoint(index: 0, in: rect).y
        case .twoPoint:
            y = (targetPoint(index: 0, in: rect).y + targetPoint(index: 1, in: rect).y) / 2
        case .threePoint:
            y = rect.height * 0.74
        }

        return Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        .stroke(.white.opacity(0.36), style: StrokeStyle(lineWidth: 1.4, dash: [8, 8]))
    }

    private func targetRings(rect: CGRect) -> some View {
        ZStack {
            ForEach(Array(viewModel.currentStage.targets.indices), id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [3, 5]))
                    .frame(width: 32, height: 32)
                    .position(targetPoint(index: index, in: rect))
            }
        }
    }

    private func onePointScene(rect: CGRect) -> some View {
        let vanishingPoint = point(index: 0, in: rect)
        let alignment = viewModel.alignmentStrength

        return ZStack {
            clouds(rect: rect)

            road(rect: rect, vanishingPoint: vanishingPoint, alignment: alignment)

            ForEach(sortedBuildings(for: vanishingPoint, in: rect)) { building in
                streetBuilding(building, rect: rect, vanishingPoint: vanishingPoint, alignment: alignment)
            }
        }
        .animation(.easeOut(duration: 0.12), value: viewModel.alignmentStrength)
    }

    private func twoPointScene(rect: CGRect) -> some View {
        let left = point(index: 0, in: rect)
        let right = point(index: 1, in: rect)
        let alignment = viewModel.alignmentStrength

        return ZStack {
            clouds(rect: rect)

            twoPointBlock(rect: rect, corner: unitPoint(x: 0.5, y: 0.76, in: rect), height: rect.height * 0.34, left: left, right: right, leftDepth: 0.28, rightDepth: 0.28, floors: 3, alignment: alignment)
            twoPointBlock(rect: rect, corner: unitPoint(x: 0.35, y: 0.7, in: rect), height: rect.height * 0.27, left: left, right: right, leftDepth: 0.22, rightDepth: 0.18, floors: 3, alignment: alignment)
            twoPointBlock(rect: rect, corner: unitPoint(x: 0.66, y: 0.68, in: rect), height: rect.height * 0.29, left: left, right: right, leftDepth: 0.18, rightDepth: 0.22, floors: 3, alignment: alignment)
            twoPointBlock(rect: rect, corner: unitPoint(x: 0.48, y: 0.48, in: rect), height: rect.height * 0.22, left: left, right: right, leftDepth: 0.12, rightDepth: 0.12, floors: 4, alignment: alignment)
        }
        .animation(.easeOut(duration: 0.12), value: viewModel.alignmentStrength)
    }

    private func threePointScene(rect: CGRect) -> some View {
        let top = point(index: 0, in: rect)
        let left = point(index: 1, in: rect)
        let right = point(index: 2, in: rect)
        let alignment = viewModel.alignmentStrength

        return ZStack {
            threePointBuilding(rect: rect, base: unitPoint(x: 0.2, y: 0.82, in: rect), scale: 0.58, top: top, left: left, right: right, alignment: alignment, bands: 4)
            threePointBuilding(rect: rect, base: unitPoint(x: 0.78, y: 0.8, in: rect), scale: 0.62, top: top, left: left, right: right, alignment: alignment, bands: 5)
            threePointBuilding(rect: rect, base: unitPoint(x: 0.34, y: 0.9, in: rect), scale: 0.46, top: top, left: left, right: right, alignment: alignment, bands: 3)
            threePointBuilding(rect: rect, base: unitPoint(x: 0.66, y: 0.9, in: rect), scale: 0.46, top: top, left: left, right: right, alignment: alignment, bands: 3)
            threePointBuilding(rect: rect, base: unitPoint(x: 0.5, y: 0.86, in: rect), scale: 1, top: top, left: left, right: right, alignment: alignment, bands: 6)
        }
        .animation(.easeOut(duration: 0.12), value: viewModel.alignmentStrength)
    }

    private func clouds(rect: CGRect) -> some View {
        Path { path in
            addCloud(to: &path, rect: rect, x: 0.5, y: 0.18, scale: 0.86)
            addCloud(to: &path, rect: rect, x: 0.72, y: 0.34, scale: 0.48)
            addCloud(to: &path, rect: rect, x: 0.38, y: 0.4, scale: 0.42)
        }
        .stroke(.white.opacity(0.2), lineWidth: 1.2)
    }

    private func road(rect: CGRect, vanishingPoint: CGPoint, alignment: CGFloat) -> some View {
        ZStack {
            polygon([
                CGPoint(x: rect.width * 0.28, y: rect.height * 0.98),
                projectedPoint(from: CGPoint(x: rect.width * 0.46, y: rect.height * 0.98), toward: vanishingPoint, amount: 0.84),
                projectedPoint(from: CGPoint(x: rect.width * 0.54, y: rect.height * 0.98), toward: vanishingPoint, amount: 0.84),
                CGPoint(x: rect.width * 0.72, y: rect.height * 0.98)
            ])
            .fill(accent.opacity(Double(0.025 + alignment * 0.06)))

        }
    }

    private func streetBuilding(_ building: LevelSixtyOneBuilding, rect: CGRect, vanishingPoint: CGPoint, alignment: CGFloat) -> some View {
        let outerBottom = unitPoint(x: building.outerX, y: building.bottomY, in: rect)
        let streetBottom = unitPoint(x: building.streetX, y: building.bottomY, in: rect)
        let streetTop = unitPoint(x: building.streetX, y: building.topY, in: rect)
        let outerTop = unitPoint(x: building.outerX, y: building.topY, in: rect)
        let topDepth = projectedPoint(from: streetTop, toward: vanishingPoint, amount: building.depth * 0.55)
        let bottomDepth = projectedPoint(from: streetBottom, toward: vanishingPoint, amount: building.depth * 0.55)

        return ZStack {
            polygon([outerBottom, streetBottom, streetTop, outerTop])
                .fill(Color.black.opacity(0.96))

            polygon([streetTop, topDepth, bottomDepth, streetBottom])
                .fill(Color(red: 0.02, green: 0.07 + Double(alignment) * 0.03, blue: 0.08 + Double(alignment) * 0.04).opacity(0.98))

            buildingOutlinePath(front: [outerBottom, streetBottom, streetTop, outerTop], depthTop: topDepth, depthBottom: bottomDepth)
                .stroke(.white.opacity(Double(0.48 + alignment * 0.34)), style: StrokeStyle(lineWidth: 1.6 + alignment * 0.7, lineCap: .round, lineJoin: .round))

            facadeDetails(building, rect: rect, vanishingPoint: vanishingPoint)
                .stroke(.white.opacity(Double(0.3 + alignment * 0.28)), lineWidth: 1.1)

            recedingWindowBands(building, fromTop: streetTop, fromBottom: streetBottom, toward: vanishingPoint)
                .stroke(.white.opacity(Double(0.3 + alignment * 0.3)), lineWidth: 1.05)
        }
    }

    private func sortedBuildings(for vanishingPoint: CGPoint, in rect: CGRect) -> [LevelSixtyOneBuilding] {
        buildings.sorted {
            buildingDepthScore($0, vanishingPoint: vanishingPoint, rect: rect) < buildingDepthScore($1, vanishingPoint: vanishingPoint, rect: rect)
        }
    }

    private func buildingDepthScore(_ building: LevelSixtyOneBuilding, vanishingPoint: CGPoint, rect: CGRect) -> CGFloat {
        let streetBottom = unitPoint(x: building.streetX, y: building.bottomY, in: rect)
        let outerBottom = unitPoint(x: building.outerX, y: building.bottomY, in: rect)
        return abs(streetBottom.x - vanishingPoint.x) + abs(outerBottom.x - vanishingPoint.x) * 0.45 + building.bottomY * rect.height * 0.18 + building.depth * 20
    }

    private func twoPointBlock(rect: CGRect, corner: CGPoint, height: CGFloat, left: CGPoint, right: CGPoint, leftDepth: CGFloat, rightDepth: CGFloat, floors: Int, alignment: CGFloat) -> some View {
        let topCorner = CGPoint(x: corner.x, y: corner.y - height)
        let leftBottom = projectedPoint(from: corner, toward: left, amount: leftDepth)
        let leftTop = projectedPoint(from: topCorner, toward: left, amount: leftDepth)
        let rightBottom = projectedPoint(from: corner, toward: right, amount: rightDepth)
        let rightTop = projectedPoint(from: topCorner, toward: right, amount: rightDepth)

        return ZStack {
            polygon([corner, leftBottom, leftTop, topCorner])
                .fill(Color.black.opacity(0.96))
            polygon([corner, rightBottom, rightTop, topCorner])
                .fill(Color(red: 0.02, green: 0.07 + Double(alignment) * 0.03, blue: 0.08 + Double(alignment) * 0.04).opacity(0.98))

            Path { path in
                path.move(to: topCorner)
                path.addLine(to: leftTop)
                path.addLine(to: leftBottom)
                path.addLine(to: corner)
                path.addLine(to: rightBottom)
                path.addLine(to: rightTop)
                path.addLine(to: topCorner)
                path.move(to: corner)
                path.addLine(to: topCorner)
            }
            .stroke(.white.opacity(Double(0.54 + alignment * 0.26)), style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))

            twoPointFacadeLines(corner: corner, topCorner: topCorner, leftBottom: leftBottom, leftTop: leftTop, rightBottom: rightBottom, rightTop: rightTop, floors: floors)
                .stroke(.white.opacity(Double(0.3 + alignment * 0.25)), lineWidth: 1)
        }
    }

    private func twoPointFacadeLines(corner: CGPoint, topCorner: CGPoint, leftBottom: CGPoint, leftTop: CGPoint, rightBottom: CGPoint, rightTop: CGPoint, floors: Int) -> Path {
        Path { path in
            for floor in 1..<floors {
                let amount = CGFloat(floor) / CGFloat(floors)
                path.move(to: interpolate(corner, topCorner, amount))
                path.addLine(to: interpolate(leftBottom, leftTop, amount))
                path.move(to: interpolate(corner, topCorner, amount))
                path.addLine(to: interpolate(rightBottom, rightTop, amount))
            }

            for amount in [CGFloat(0.35), CGFloat(0.68)] {
                path.move(to: interpolate(leftBottom, corner, amount))
                path.addLine(to: interpolate(leftTop, topCorner, amount))
                path.move(to: interpolate(corner, rightBottom, amount))
                path.addLine(to: interpolate(topCorner, rightTop, amount))
            }
        }
    }

    private func threePointBuilding(rect: CGRect, base: CGPoint, scale: CGFloat, top: CGPoint, left: CGPoint, right: CGPoint, alignment: CGFloat, bands: Int) -> some View {
        let ridge = projectedPoint(from: base, toward: top, amount: 0.58 + scale * 0.18)
        let leftBase = projectedPoint(from: base, toward: left, amount: 0.2 + scale * 0.16)
        let rightBase = projectedPoint(from: base, toward: right, amount: 0.2 + scale * 0.16)
        let leftTop = projectedPoint(from: leftBase, toward: top, amount: 0.58 + scale * 0.2)
        let rightTop = projectedPoint(from: rightBase, toward: top, amount: 0.58 + scale * 0.2)
        let cap = projectedPoint(from: ridge, toward: top, amount: 0.08 + scale * 0.04)

        return ZStack {
            polygon([base, leftBase, leftTop, ridge])
                .fill(Color.black.opacity(0.96))
            polygon([base, rightBase, rightTop, ridge])
                .fill(Color(red: 0.02, green: 0.08 + Double(alignment) * 0.03, blue: 0.09 + Double(alignment) * 0.04).opacity(0.98))
            polygon([leftTop, ridge, rightTop, cap])
                .fill(accent.opacity(Double(0.12 + alignment * 0.08)))

            Path { path in
                path.move(to: leftBase)
                path.addLine(to: base)
                path.addLine(to: rightBase)
                path.move(to: leftBase)
                path.addLine(to: leftTop)
                path.addLine(to: ridge)
                path.addLine(to: rightTop)
                path.addLine(to: rightBase)
                path.move(to: base)
                path.addLine(to: ridge)
            }
            .stroke(.white.opacity(Double(0.5 + alignment * 0.28)), style: StrokeStyle(lineWidth: 1.2 + scale * 0.6, lineJoin: .round))

            threePointBands(baseCenter: base, ridge: ridge, leftBase: leftBase, leftTop: leftTop, rightBase: rightBase, rightTop: rightTop, bands: bands)
                .stroke(.white.opacity(Double(0.3 + alignment * 0.26)), lineWidth: 1.05)
        }
    }

    private func threePointBands(baseCenter: CGPoint, ridge: CGPoint, leftBase: CGPoint, leftTop: CGPoint, rightBase: CGPoint, rightTop: CGPoint, bands: Int) -> Path {
        Path { path in
            for index in 1...bands {
                let amount = CGFloat(index) / CGFloat(bands + 1)
                path.move(to: interpolate(leftBase, leftTop, amount))
                path.addLine(to: interpolate(baseCenter, ridge, amount))
                path.addLine(to: interpolate(rightBase, rightTop, amount))
            }

            for amount in [CGFloat(0.32), CGFloat(0.62)] {
                path.move(to: interpolate(leftBase, baseCenter, amount))
                path.addLine(to: interpolate(leftTop, ridge, amount))
                path.move(to: interpolate(baseCenter, rightBase, amount))
                path.addLine(to: interpolate(ridge, rightTop, amount))
            }
        }
    }

    private func buildingOutlinePath(front: [CGPoint], depthTop: CGPoint, depthBottom: CGPoint) -> Path {
        Path { path in
            guard front.count >= 4 else { return }
            path.move(to: front[0])
            path.addLine(to: front[1])
            path.addLine(to: front[2])
            path.addLine(to: front[3])
            path.closeSubpath()

            path.move(to: front[2])
            path.addLine(to: depthTop)
            path.addLine(to: depthBottom)
            path.addLine(to: front[1])

            path.move(to: front[1])
            path.addLine(to: depthBottom)
        }
    }

    private func facadeDetails(_ building: LevelSixtyOneBuilding, rect: CGRect, vanishingPoint: CGPoint) -> Path {
        Path { path in
            let left = min(building.outerX, building.streetX)
            let right = max(building.outerX, building.streetX)
            let width = right - left
            let height = building.bottomY - building.topY

            for bay in 0..<building.bays {
                for floor in 0..<building.floors {
                    let insetX = width * 0.12
                    let insetY = height * 0.08
                    let bayWidth = width / CGFloat(building.bays)
                    let floorHeight = height / CGFloat(building.floors)
                    let x0 = left + CGFloat(bay) * bayWidth + insetX
                    let x1 = left + CGFloat(bay + 1) * bayWidth - insetX
                    let y0 = building.topY + CGFloat(floor) * floorHeight + insetY
                    let y1 = building.topY + CGFloat(floor + 1) * floorHeight - insetY

                    addRect(to: &path, rect: rect, x0: x0, y0: y0, x1: x1, y1: y1)
                }
            }

            for floor in 1..<building.floors {
                let y = building.topY + (building.bottomY - building.topY) * CGFloat(floor) / CGFloat(building.floors)
                path.move(to: unitPoint(x: left, y: y, in: rect))
                path.addLine(to: unitPoint(x: right, y: y, in: rect))
                path.addLine(to: projectedPoint(from: unitPoint(x: building.streetX, y: y, in: rect), toward: vanishingPoint, amount: building.depth * 0.42))
            }
        }
    }

    private func recedingWindowBands(_ building: LevelSixtyOneBuilding, fromTop: CGPoint, fromBottom: CGPoint, toward vanishingPoint: CGPoint) -> Path {
        Path { path in
            for index in 1...max(2, building.bays + 1) {
                let amount = CGFloat(index) / CGFloat(max(3, building.bays + 2)) * building.depth * 0.52
                let top = projectedPoint(from: fromTop, toward: vanishingPoint, amount: amount)
                let bottom = projectedPoint(from: fromBottom, toward: vanishingPoint, amount: amount)
                path.move(to: top)
                path.addLine(to: bottom)
            }
        }
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private func projectedPoint(from point: CGPoint, toward vanishingPoint: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x + (vanishingPoint.x - point.x) * amount,
            y: point.y + (vanishingPoint.y - point.y) * amount
        )
    }

    private func interpolate(_ start: CGPoint, _ end: CGPoint, _ amount: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * amount,
            y: start.y + (end.y - start.y) * amount
        )
    }

    private func addRect(to path: inout Path, rect: CGRect, x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat) {
        let topLeft = unitPoint(x: x0, y: y0, in: rect)
        let topRight = unitPoint(x: x1, y: y0, in: rect)
        let bottomRight = unitPoint(x: x1, y: y1, in: rect)
        let bottomLeft = unitPoint(x: x0, y: y1, in: rect)
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.closeSubpath()
    }

    private func addCloud(to path: inout Path, rect: CGRect, x: CGFloat, y: CGFloat, scale: CGFloat) {
        let center = unitPoint(x: x, y: y, in: rect)
        let width = rect.width * 0.16 * scale
        let height = rect.height * 0.08 * scale
        path.move(to: CGPoint(x: center.x - width * 0.5, y: center.y + height * 0.18))
        path.addQuadCurve(to: CGPoint(x: center.x - width * 0.24, y: center.y - height * 0.05), control: CGPoint(x: center.x - width * 0.38, y: center.y - height * 0.28))
        path.addQuadCurve(to: CGPoint(x: center.x + width * 0.02, y: center.y - height * 0.24), control: CGPoint(x: center.x - width * 0.1, y: center.y - height * 0.55))
        path.addQuadCurve(to: CGPoint(x: center.x + width * 0.28, y: center.y - height * 0.08), control: CGPoint(x: center.x + width * 0.2, y: center.y - height * 0.46))
        path.addQuadCurve(to: CGPoint(x: center.x + width * 0.5, y: center.y + height * 0.16), control: CGPoint(x: center.x + width * 0.42, y: center.y - height * 0.08))
    }

    private func unitPoint(x: CGFloat, y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.width * x, y: rect.height * y)
    }

    private func targetPoint(index: Int, in rect: CGRect) -> CGPoint {
        guard viewModel.currentStage.targets.indices.contains(index) else { return .zero }
        let point = viewModel.currentStage.targets[index]
        return unitPoint(x: point.x, y: point.y, in: rect)
    }

    private func point(index: Int, in rect: CGRect) -> CGPoint {
        guard viewModel.vanishingPoints.indices.contains(index) else { return .zero }
        let point = viewModel.vanishingPoints[index]
        return unitPoint(x: point.x, y: point.y, in: rect)
    }

    private func vanishingHandle(index: Int, rect: CGRect) -> some View {
        let point = point(index: index, in: rect)
        return ZStack {
            Circle()
                .fill(.white.opacity(0.001))
                .frame(width: 72, height: 72)
            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: 18, height: 18)
            Circle()
                .stroke(accent, lineWidth: 3)
                .frame(width: 32, height: 32)
                .shadow(color: accent.opacity(0.75), radius: 12)
        }
        .contentShape(Circle())
        .position(point)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("levelSixtyOneBoard"))
                .onChanged { value in
                    viewModel.setVanishingPoint(index: index, value: CGPoint(x: value.location.x / rect.width, y: value.location.y / rect.height))
                }
                .onEnded { value in
                    viewModel.setVanishingPoint(index: index, value: CGPoint(x: value.location.x / rect.width, y: value.location.y / rect.height))
                    viewModel.finishIfAligned()
                }
        )
        .disabled(viewModel.advancing || viewModel.completed)
    }
}
