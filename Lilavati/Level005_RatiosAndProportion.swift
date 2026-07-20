import SwiftUI
import Combine
import AVFoundation

enum ScaleCityObjectType: CaseIterable, Identifiable {
    case buildings
    case cars
    case trees
    case streetlights
    case people

    var id: Self { self }

    var title: String {
        switch self {
        case .buildings: "Buildings"
        case .cars: "Cars"
        case .trees: "Trees"
        case .streetlights: "Lights"
        case .people: "People"
        }
    }

    var icon: String {
        switch self {
        case .buildings: "building.2.fill"
        case .cars: "car.fill"
        case .trees: "tree.fill"
        case .streetlights: "lightbulb.fill"
        case .people: "figure.walk"
        }
    }
}

struct MathItScaleCityGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var scales: [ScaleCityObjectType: CGFloat] = ScaleCityStage.stages[0].startScales
    @State private var completed = false

    private let tolerance: CGFloat = 0.035

    private var stage: ScaleCityStage {
        ScaleCityStage.stages[stageIndex]
    }

    private var progress: Double {
        if completed { return 1 }
        let stageProgress = stage.objectTypes.reduce(CGFloat(0)) { partial, type in
            let distance = abs(scale(for: type) - target(for: type))
            return partial + max(0, 1 - distance / 1.25)
        } / CGFloat(stage.objectTypes.count)
        return (Double(stageIndex) + Double(stageProgress)) / Double(ScaleCityStage.stages.count)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 13) {
                    VStack(spacing: 8) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(34))
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.46))
                    }
                    .padding(.horizontal, 58)

                    ProgressView(value: progress)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    cityField
                        .frame(height: min(440, proxy.size.height * 0.52))
                        .padding(.horizontal, 22)

                    controlPanel
                        .padding(.horizontal, 22)
                }
                .padding(.top, 38)
                .padding(.bottom, 60)

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

    private var cityField: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.018, green: 0.02, blue: 0.025))

                cityGuideLines(in: proxy.size)
                roadLayer(in: proxy.size)

                cityObjects(in: proxy.size, isTarget: false)
                cityObjects(in: proxy.size, isTarget: true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.42), lineWidth: 1.2))
            .contentShape(Rectangle())
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: stageIndex)
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 9) {
            ForEach(stage.objectTypes) { type in
                HStack(spacing: 12) {
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(accent, in: Circle())

                    Text(type.title)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 86, alignment: .leading)

                    scaleButton(systemImage: "minus") {
                        adjust(type, by: -0.05)
                    }

                    Text(String(format: "%.2fx", Double(scale(for: type))))
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(.black.opacity(0.84), in: Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.34), lineWidth: 1))

                    scaleButton(systemImage: "plus") {
                        adjust(type, by: 0.05)
                    }
                }
            }
        }
    }

    private func scaleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 38, height: 34)
                .background(accent.opacity(0.92), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(completed)
    }

    private func cityObjects(in size: CGSize, isTarget: Bool) -> some View {
        ZStack {
            buildingLayer(in: size, scale: scaleValue(for: .buildings, isTarget: isTarget), isTarget: isTarget)
            treeLayer(in: size, scale: scaleValue(for: .trees, isTarget: isTarget), isTarget: isTarget)
            carLayer(in: size, scale: scaleValue(for: .cars, isTarget: isTarget), isTarget: isTarget)

            if stage.objectTypes.contains(.streetlights) {
                streetlightLayer(in: size, scale: scaleValue(for: .streetlights, isTarget: isTarget), isTarget: isTarget)
            }

            if stage.objectTypes.contains(.people) {
                peopleLayer(in: size, scale: scaleValue(for: .people, isTarget: isTarget), isTarget: isTarget)
            }
        }
    }

    private func roadLayer(in size: CGSize) -> some View {
        let baseline = size.height * stage.baseline
        let roadHeight = size.height * stage.roadHeight
        let mainRoad = CGRect(x: 18, y: baseline - roadHeight, width: size.width - 36, height: roadHeight)

        return ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(red: 0.035, green: 0.04, blue: 0.055).opacity(0.96))
                .frame(width: mainRoad.width, height: mainRoad.height)
                .position(x: mainRoad.midX, y: mainRoad.midY)
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.white.opacity(0.24), lineWidth: 1.1)
                        .frame(width: mainRoad.width, height: mainRoad.height)
                        .position(x: mainRoad.midX, y: mainRoad.midY)
                }

            Path { path in
                path.move(to: CGPoint(x: mainRoad.minX + 18, y: mainRoad.midY))
                path.addLine(to: CGPoint(x: mainRoad.maxX - 18, y: mainRoad.midY))
                path.move(to: CGPoint(x: mainRoad.minX + 18, y: mainRoad.minY + roadHeight * 0.26))
                path.addLine(to: CGPoint(x: mainRoad.maxX - 18, y: mainRoad.minY + roadHeight * 0.26))
            }
            .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
        }
    }

    private func buildingLayer(in size: CGSize, scale: CGFloat, isTarget: Bool) -> some View {
        ZStack {
            ForEach(stage.buildings) { building in
                cityBuilding(building, scale: scale, isTarget: isTarget)
                    .position(
                        x: size.width * building.x,
                        y: size.height * building.bottom - building.height * scale / 2
                    )
            }
        }
    }

    private func carLayer(in size: CGSize, scale: CGFloat, isTarget: Bool) -> some View {
        ZStack {
            ForEach(stage.cars) { item in
                car(scale: scale, isTarget: isTarget)
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: size.width * item.x, y: size.height * item.y)
            }
        }
    }

    private func treeLayer(in size: CGSize, scale: CGFloat, isTarget: Bool) -> some View {
        ZStack {
            ForEach(stage.trees) { item in
                tree(scale: scale, isTarget: isTarget)
                    .position(x: size.width * item.x, y: size.height * item.y)
            }
        }
    }

    private func streetlightLayer(in size: CGSize, scale: CGFloat, isTarget: Bool) -> some View {
        ZStack {
            ForEach(stage.streetlights) { item in
                streetlight(scale: scale, isTarget: isTarget)
                    .position(x: size.width * item.x, y: size.height * item.y)
            }
        }
    }

    private func peopleLayer(in size: CGSize, scale: CGFloat, isTarget: Bool) -> some View {
        ZStack {
            ForEach(stage.people) { item in
                person(scale: scale, isTarget: isTarget)
                    .position(x: size.width * item.x, y: size.height * item.y)
            }
        }
    }

    private func cityBuilding(_ building: ScaleCityBuilding, scale: CGFloat, isTarget: Bool) -> some View {
        let width = building.width * scale
        let height = building.height * scale

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: isTarget ? 3 : 5)
                .fill(isTarget ? .clear : accent.opacity(0.82))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: isTarget ? 3 : 5)
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.78) : accent,
                            style: StrokeStyle(lineWidth: isTarget ? 1.5 : 1.1, dash: isTarget ? [6, 5] : [])
                        )
                )

            if !isTarget {
                VStack(spacing: max(3, 5 * scale)) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: max(3, 4 * scale)) {
                            ForEach(0..<2, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(.black.opacity(0.48))
                                    .frame(width: max(3, 6 * scale), height: max(4, 7 * scale))
                            }
                        }
                    }
                }
                .padding(.bottom, max(6, 9 * scale))
            }
        }
    }

    private func car(scale: CGFloat, isTarget: Bool) -> some View {
        let width = 38 * scale
        let height = 17 * scale
        let roofWidth = 18 * scale
        let roofHeight = 9 * scale

        return ZStack {
            RoundedRectangle(cornerRadius: isTarget ? 3 : 5)
                .fill(isTarget ? .clear : Color.mathGold.opacity(0.86))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: isTarget ? 3 : 5)
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.74) : Color.mathGold,
                            style: StrokeStyle(lineWidth: isTarget ? 1.8 : 1, dash: isTarget ? [5, 4] : [])
                        )
                )
                .offset(y: roofHeight * 0.28)

            RoundedRectangle(cornerRadius: isTarget ? 2 : 3)
                .fill(isTarget ? .clear : Color.mathGold.opacity(0.72))
                .frame(width: roofWidth, height: roofHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: isTarget ? 2 : 3)
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.74) : Color.mathGold,
                            style: StrokeStyle(lineWidth: isTarget ? 1.8 : 1, dash: isTarget ? [5, 4] : [])
                        )
                )
                .offset(y: -height * 0.42)

            if !isTarget {
                HStack(spacing: max(1, 2 * scale)) {
                    RoundedRectangle(cornerRadius: max(0.8, 1.5 * scale))
                        .fill(Color(red: 0.10, green: 0.16, blue: 0.19).opacity(0.9))
                    RoundedRectangle(cornerRadius: max(0.8, 1.5 * scale))
                        .fill(Color(red: 0.10, green: 0.16, blue: 0.19).opacity(0.9))
                }
                .frame(width: roofWidth * 0.78, height: roofHeight * 0.56)
                .offset(y: -height * 0.42)

                Rectangle()
                    .fill(.black.opacity(0.34))
                    .frame(width: max(0.8, scale), height: height * 0.48)
                    .offset(y: height * 0.18)

                HStack(spacing: width * 0.78) {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.92, blue: 0.48))
                        .frame(width: max(2, 3 * scale), height: max(2, 3 * scale))
                    Circle()
                        .fill(Color(red: 0.95, green: 0.22, blue: 0.18))
                        .frame(width: max(2, 3 * scale), height: max(2, 3 * scale))
                }
                .offset(y: height * 0.16)

                HStack(spacing: width * 0.86) {
                    Capsule()
                        .fill(.white.opacity(0.72))
                        .frame(width: max(3, 4 * scale), height: max(1.5, 2 * scale))
                    Capsule()
                        .fill(.white.opacity(0.72))
                        .frame(width: max(3, 4 * scale), height: max(1.5, 2 * scale))
                }
                .offset(y: height * 0.39)

                HStack(spacing: width * 0.42) {
                    ZStack {
                        Circle().fill(.black.opacity(0.92))
                        Circle().fill(.white.opacity(0.42)).padding(max(1, 1.5 * scale))
                    }
                    .frame(width: max(4, 6 * scale), height: max(4, 6 * scale))
                    ZStack {
                        Circle().fill(.black.opacity(0.92))
                        Circle().fill(.white.opacity(0.42)).padding(max(1, 1.5 * scale))
                    }
                    .frame(width: max(4, 6 * scale), height: max(4, 6 * scale))
                }
                .offset(y: height * 0.48)
            }
        }
    }

    private func tree(scale: CGFloat, isTarget: Bool) -> some View {
        let trunkHeight = 22 * scale
        let crown = 28 * scale

        return ZStack {
            Rectangle()
                .fill(isTarget ? .clear : Color(red: 0.46, green: 0.28, blue: 0.12).opacity(0.9))
                .frame(width: max(3, 5 * scale), height: trunkHeight)
                .overlay(
                    Rectangle()
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.74) : .clear,
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                        )
                )
                .offset(y: crown * 0.46)

            Circle()
                .fill(isTarget ? .clear : Color.green.opacity(0.72))
                .frame(width: crown, height: crown)
                .overlay(
                    Circle()
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.74) : Color.green.opacity(0.9),
                            style: StrokeStyle(lineWidth: isTarget ? 1.3 : 1, dash: isTarget ? [5, 4] : [])
                        )
                )
        }
    }

    private func streetlight(scale: CGFloat, isTarget: Bool) -> some View {
        let height = 42 * scale
        let head = 11 * scale

        return ZStack {
            Rectangle()
                .fill(isTarget ? .clear : .white.opacity(0.72))
                .frame(width: max(2, 4 * scale), height: height)
                .overlay(
                    Rectangle()
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.74) : .clear,
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                        )
                )

            Circle()
                .fill(isTarget ? .clear : Color.mathGold.opacity(0.78))
                .frame(width: head, height: head)
                .overlay(
                    Circle()
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.74) : Color.mathGold,
                            style: StrokeStyle(lineWidth: isTarget ? 1.4 : 1, dash: isTarget ? [5, 4] : [])
                        )
                )
                .offset(y: -height * 0.5)
        }
    }

    private func person(scale: CGFloat, isTarget: Bool) -> some View {
        let head = 8 * scale
        let body = 18 * scale

        return ZStack {
            Circle()
                .fill(isTarget ? .clear : .white.opacity(0.82))
                .frame(width: head, height: head)
                .overlay(
                    Circle()
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.74) : .white.opacity(0.9),
                            style: StrokeStyle(lineWidth: isTarget ? 1.3 : 1, dash: isTarget ? [4, 4] : [])
                        )
                )
                .offset(y: -body * 0.55)

            RoundedRectangle(cornerRadius: 2)
                .fill(isTarget ? .clear : .white.opacity(0.72))
                .frame(width: max(3, 5 * scale), height: body)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(
                            isTarget ? Color.mathGold.opacity(0.74) : .white.opacity(0.9),
                            style: StrokeStyle(lineWidth: isTarget ? 1.3 : 1, dash: isTarget ? [4, 4] : [])
                        )
                )

            Path { path in
                path.move(to: CGPoint(x: -6 * scale, y: body * 0.66))
                path.addLine(to: CGPoint(x: 0, y: body * 0.2))
                path.addLine(to: CGPoint(x: 6 * scale, y: body * 0.66))
            }
            .stroke(isTarget ? Color.mathGold.opacity(0.74) : .white.opacity(0.85), style: StrokeStyle(lineWidth: isTarget ? 1.3 : 1.1, dash: isTarget ? [4, 4] : []))
        }
    }

    private func cityGuideLines(in size: CGSize) -> some View {
        Canvas { canvas, canvasSize in
            for y in [CGFloat(0.28), CGFloat(0.50), CGFloat(0.72)] {
                var path = Path()
                path.move(to: CGPoint(x: 24, y: canvasSize.height * y))
                path.addLine(to: CGPoint(x: canvasSize.width - 24, y: canvasSize.height * y))
                canvas.stroke(path, with: .color(accent.opacity(0.07)), lineWidth: 1)
            }
        }
    }

    private func scaleValue(for type: ScaleCityObjectType, isTarget: Bool) -> CGFloat {
        isTarget ? target(for: type) : scale(for: type)
    }

    private func scale(for type: ScaleCityObjectType) -> CGFloat {
        scales[type] ?? target(for: type)
    }

    private func target(for type: ScaleCityObjectType) -> CGFloat {
        stage.targetScales[type] ?? 1
    }

    private func adjust(_ type: ScaleCityObjectType, by amount: CGFloat) {
        guard !completed else { return }
        scales[type] = min(max(scale(for: type) + amount, 0.35), 2.65)
        HapticPlayer.playLightTap()
        checkCompletion()
    }

    private func checkCompletion() {
        let solved = stage.objectTypes.allSatisfy { type in
            abs(scale(for: type) - target(for: type)) <= tolerance
        }

        guard solved else { return }

        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
            scales = stage.targetScales
        }

        if stageIndex == ScaleCityStage.stages.count - 1 {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    stageIndex += 1
                    scales = ScaleCityStage.stages[stageIndex].startScales
                }
            }
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            stageIndex = 0
            scales = ScaleCityStage.stages[0].startScales
            completed = false
        }
    }
}

private enum ScaleCityRoadKind: Equatable {
    case avenue
    case crossing
    case plaza
}

private struct ScaleCityStage {
    let objectTypes: [ScaleCityObjectType]
    let startScales: [ScaleCityObjectType: CGFloat]
    let targetScales: [ScaleCityObjectType: CGFloat]
    let baseline: CGFloat
    let roadHeight: CGFloat
    let roadKind: ScaleCityRoadKind
    let buildings: [ScaleCityBuilding]
    let cars: [ScaleCityPlacedObject]
    let trees: [ScaleCityPlacedObject]
    let streetlights: [ScaleCityPlacedObject]
    let people: [ScaleCityPlacedObject]

    static let stages: [ScaleCityStage] = [
        ScaleCityStage(
            objectTypes: [.buildings, .cars, .trees],
            startScales: [.buildings: 0.55, .cars: 2.25, .trees: 0.48],
            targetScales: [.buildings: 1.15, .cars: 0.82, .trees: 1.0],
            baseline: 0.86,
            roadHeight: 0.18,
            roadKind: .avenue,
            buildings: [
                ScaleCityBuilding(x: 0.16, bottom: 0.68, width: 32, height: 58),
                ScaleCityBuilding(x: 0.38, bottom: 0.68, width: 38, height: 88),
                ScaleCityBuilding(x: 0.63, bottom: 0.68, width: 44, height: 118),
                ScaleCityBuilding(x: 0.86, bottom: 0.68, width: 30, height: 72)
            ],
            cars: [
                ScaleCityPlacedObject(x: 0.24, y: 0.77),
                ScaleCityPlacedObject(x: 0.52, y: 0.78),
                ScaleCityPlacedObject(x: 0.80, y: 0.76)
            ],
            trees: [
                ScaleCityPlacedObject(x: 0.08, y: 0.66),
                ScaleCityPlacedObject(x: 0.48, y: 0.65),
                ScaleCityPlacedObject(x: 0.93, y: 0.67)
            ],
            streetlights: [],
            people: []
        ),
        ScaleCityStage(
            objectTypes: [.buildings, .cars, .trees, .streetlights],
            startScales: [.buildings: 1.82, .cars: 0.46, .trees: 1.72, .streetlights: 0.48],
            targetScales: [.buildings: 0.95, .cars: 0.88, .trees: 0.92, .streetlights: 1.08],
            baseline: 0.84,
            roadHeight: 0.2,
            roadKind: .crossing,
            buildings: [
                ScaleCityBuilding(x: 0.12, bottom: 0.64, width: 34, height: 92),
                ScaleCityBuilding(x: 0.30, bottom: 0.64, width: 30, height: 68),
                ScaleCityBuilding(x: 0.69, bottom: 0.64, width: 40, height: 104),
                ScaleCityBuilding(x: 0.88, bottom: 0.64, width: 34, height: 78)
            ],
            cars: [
                ScaleCityPlacedObject(x: 0.35, y: 0.76, rotation: -4),
                ScaleCityPlacedObject(x: 0.75, y: 0.78, rotation: 3)
            ],
            trees: [
                ScaleCityPlacedObject(x: 0.20, y: 0.63),
                ScaleCityPlacedObject(x: 0.44, y: 0.63),
                ScaleCityPlacedObject(x: 0.82, y: 0.62)
            ],
            streetlights: [
                ScaleCityPlacedObject(x: 0.08, y: 0.66),
                ScaleCityPlacedObject(x: 0.51, y: 0.66),
                ScaleCityPlacedObject(x: 0.92, y: 0.66)
            ],
            people: []
        ),
        ScaleCityStage(
            objectTypes: [.buildings, .cars, .trees, .streetlights, .people],
            startScales: [.buildings: 0.72, .cars: 1.7, .trees: 0.55, .streetlights: 1.95, .people: 2.25],
            targetScales: [.buildings: 1.05, .cars: 0.76, .trees: 0.9, .streetlights: 1.0, .people: 0.66],
            baseline: 0.88,
            roadHeight: 0.22,
            roadKind: .plaza,
            buildings: [
                ScaleCityBuilding(x: 0.09, bottom: 0.58, width: 26, height: 64),
                ScaleCityBuilding(x: 0.24, bottom: 0.58, width: 34, height: 120),
                ScaleCityBuilding(x: 0.42, bottom: 0.58, width: 30, height: 86),
                ScaleCityBuilding(x: 0.60, bottom: 0.58, width: 42, height: 132),
                ScaleCityBuilding(x: 0.79, bottom: 0.58, width: 32, height: 96),
                ScaleCityBuilding(x: 0.93, bottom: 0.58, width: 24, height: 70)
            ],
            cars: [
                ScaleCityPlacedObject(x: 0.22, y: 0.79, rotation: -2),
                ScaleCityPlacedObject(x: 0.48, y: 0.71),
                ScaleCityPlacedObject(x: 0.67, y: 0.82, rotation: 4),
                ScaleCityPlacedObject(x: 0.84, y: 0.76, rotation: -3)
            ],
            trees: [
                ScaleCityPlacedObject(x: 0.12, y: 0.62),
                ScaleCityPlacedObject(x: 0.33, y: 0.61),
                ScaleCityPlacedObject(x: 0.70, y: 0.61),
                ScaleCityPlacedObject(x: 0.91, y: 0.62)
            ],
            streetlights: [
                ScaleCityPlacedObject(x: 0.17, y: 0.66),
                ScaleCityPlacedObject(x: 0.39, y: 0.66),
                ScaleCityPlacedObject(x: 0.62, y: 0.66),
                ScaleCityPlacedObject(x: 0.86, y: 0.66)
            ],
            people: [
                ScaleCityPlacedObject(x: 0.30, y: 0.70),
                ScaleCityPlacedObject(x: 0.43, y: 0.69),
                ScaleCityPlacedObject(x: 0.57, y: 0.70),
                ScaleCityPlacedObject(x: 0.76, y: 0.69)
            ]
        )
    ]
}

private struct ScaleCityBuilding: Identifiable {
    let id = UUID()
    let x: CGFloat
    let bottom: CGFloat
    let width: CGFloat
    let height: CGFloat
}

private struct ScaleCityPlacedObject: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    var rotation: Double = 0
}
