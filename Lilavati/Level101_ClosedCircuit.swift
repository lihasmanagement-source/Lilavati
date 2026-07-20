import SwiftUI

@Observable
final class MathItLevelTwentyFourViewModel {
    var stageIndex = 0
    var components = MathItLevelTwentyFourViewModel.makeComponents(for: 0)
    var didLayout = false
    var layoutSize = CGSize.zero
    var switchClosed = false
    var poweredAt: Date?
    var completed = false

    var progress: Double {
        if completed { return 1 }
        let placed = components.filter(\.isPlaced).count
        let local = min(0.98, Double(placed) / Double(max(components.count, 1)) * 0.78 + (switchClosed ? 0.2 : 0))
        return (Double(stageIndex) + local) / 3
    }

    var circuitComplete: Bool {
        components.allSatisfy(\.isPlaced)
    }

    var powered: Bool {
        circuitComplete && switchClosed
    }

    func prepareLayout(size: CGSize) {
        guard !didLayout else { return }
        didLayout = true
        layoutSize = size
        let y = size.height * 0.79
        let step = size.width / CGFloat(components.count + 1)
        for index in components.indices {
            components[index].position = CGPoint(x: step * CGFloat(index + 1), y: y)
        }
    }

    func moveComponent(id: UUID, to point: CGPoint) {
        guard !completed, let index = components.firstIndex(where: { $0.id == id }), !components[index].isPlaced else { return }
        components[index].position = point
    }

    func finishComponent(id: UUID, slots: [LevelTwentyFourComponentKind: CGRect]) {
        guard !completed, let index = components.firstIndex(where: { $0.id == id }), !components[index].isPlaced else { return }
        let component = components[index]
        guard let slot = slots[component.kind], slot.insetBy(dx: -22, dy: -22).contains(component.position) else { return }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            components[index].isPlaced = true
            components[index].position = CGPoint(x: slot.midX, y: slot.midY)
        }
    }

    func toggleSwitch() {
        guard circuitComplete, !completed else { return }
        switchClosed.toggle()
        HapticPlayer.playLightTap()
        guard powered else {
            poweredAt = nil
            return
        }

        poweredAt = Date()
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            if self.stageIndex == 2 {
                withAnimation(.spring(response: 0.54, dampingFraction: 0.84)) {
                    self.completed = true
                }
            } else {
                self.stageIndex += 1
                self.switchClosed = false
                self.poweredAt = nil
                self.components = Self.makeComponents(for: self.stageIndex)
                self.didLayout = false
                self.prepareLayout(size: self.layoutSize)
            }
        }
    }

    private static func makeComponents(for stage: Int) -> [LevelTwentyFourComponent] {
        let kinds: [LevelTwentyFourComponentKind]
        switch stage {
        case 0: kinds = [.switch, .wire]
        case 1: kinds = [.switch, .resistor, .wire]
        default: kinds = [.switch, .resistor, .capacitor, .wire]
        }
        return kinds.map { LevelTwentyFourComponent(kind: $0) }
    }
}

enum LevelTwentyFourComponentKind: Hashable {
    case `switch`
    case resistor
    case capacitor
    case wire
}

struct LevelTwentyFourComponent: Identifiable {
    let id = UUID()
    let kind: LevelTwentyFourComponentKind
    var position = CGPoint.zero
    var isPlaced = false
}

struct MathItLevelTwentyFourView: View {
    var viewModel: MathItLevelTwentyFourViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 24, y: size.height * 0.19, width: size.width - 48, height: min(390, size.height * 0.5))
            let slots = componentSlots(in: board)

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
                    .tint(Color.mathItLogic)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index <= viewModel.stageIndex ? Color.mathItLogic : .white.opacity(0.18))
                            .frame(width: 7, height: 7)
                    }
                }
                .position(x: size.width / 2, y: 157)

                circuitBoard(board: board, slots: slots)

                ForEach(viewModel.components) { component in
                    componentView(component)
                        .position(component.position)
                        .onTapGesture {
                            if component.kind == .switch, component.isPlaced {
                                viewModel.toggleSwitch()
                            }
                        }
                        .gesture(
                            DragGesture(coordinateSpace: .named("levelTwentyFourStage"))
                                .onChanged { value in
                                    viewModel.moveComponent(id: component.id, to: value.location)
                                }
                                .onEnded { _ in
                                    viewModel.finishComponent(id: component.id, slots: slots)
                                }
                        )
                }

                CompletionOverlay(
                    title: "Level 24 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .task(id: CGSize(width: size.width, height: size.height)) {
                viewModel.prepareLayout(size: size)
            }
            .coordinateSpace(name: "levelTwentyFourStage")
        }
    }

    private func componentSlots(in board: CGRect) -> [LevelTwentyFourComponentKind: CGRect] {
        [
            .switch: CGRect(x: board.minX + board.width * 0.28, y: board.minY + 54, width: 74, height: 44),
            .resistor: CGRect(x: board.midX - 26, y: board.midY - 24, width: 52, height: 76),
            .capacitor: CGRect(x: board.minX + board.width * 0.67, y: board.midY - 24, width: 52, height: 76),
            .wire: CGRect(x: board.minX + board.width * 0.55, y: board.maxY - 86, width: 78, height: 44)
        ]
    }

    private func circuitBoard(board: CGRect, slots: [LevelTwentyFourComponentKind: CGRect]) -> some View {
        let color = viewModel.powered ? Color.mathItLogic : Color.white.opacity(0.62)
        let leftX = board.minX + 48
        let rightX = board.maxX - 70
        let topY = board.minY + 76
        let bottomY = board.maxY - 64
        let bulb = CGPoint(x: board.maxX - 34, y: board.midY)

        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.025))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.mathItLogic.opacity(0.28), lineWidth: 1.2)
                }
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            circuitPath(points: [
                CGPoint(x: leftX, y: topY),
                CGPoint(x: slots[.switch]!.minX, y: topY)
            ]).stroke(color, style: circuitStroke)

            circuitPath(points: [
                CGPoint(x: slots[.switch]!.maxX, y: topY),
                CGPoint(x: rightX, y: topY),
                CGPoint(x: rightX, y: bottomY),
                CGPoint(x: slots[.wire]!.maxX, y: bottomY)
            ]).stroke(color, style: circuitStroke)

            circuitPath(points: [
                CGPoint(x: slots[.wire]!.minX, y: bottomY),
                CGPoint(x: leftX, y: bottomY)
            ]).stroke(color, style: circuitStroke)

            circuitPath(points: [
                CGPoint(x: leftX, y: topY),
                CGPoint(x: leftX, y: board.midY - 9),
                CGPoint(x: leftX - 16, y: board.midY - 9)
            ]).stroke(color, style: circuitStroke)

            circuitPath(points: [
                CGPoint(x: leftX - 10, y: board.midY + 9),
                CGPoint(x: leftX, y: board.midY + 9),
                CGPoint(x: leftX, y: bottomY)
            ]).stroke(color, style: circuitStroke)

            circuitPath(points: [
                CGPoint(x: rightX, y: bulb.y),
                CGPoint(x: bulb.x - 23, y: bulb.y)
            ])
            .stroke(color, style: circuitStroke)
            .shadow(color: Color.mathItLogic.opacity(viewModel.powered ? 0.52 : 0), radius: 10)

            if viewModel.components.contains(where: { $0.kind == .resistor }) {
                circuitPath(points: [
                    CGPoint(x: board.midX, y: topY),
                    CGPoint(x: board.midX, y: slots[.resistor]!.minY)
                ]).stroke(color, style: circuitStroke)

                circuitPath(points: [
                    CGPoint(x: board.midX, y: slots[.resistor]!.maxY),
                    CGPoint(x: board.midX, y: bottomY)
                ]).stroke(color, style: circuitStroke)
            }

            if viewModel.components.contains(where: { $0.kind == .capacitor }) {
                let capacitorX = slots[.capacitor]!.midX
                circuitPath(points: [
                    CGPoint(x: capacitorX, y: topY),
                    CGPoint(x: capacitorX, y: slots[.capacitor]!.minY)
                ]).stroke(color, style: circuitStroke)
                circuitPath(points: [
                    CGPoint(x: capacitorX, y: slots[.capacitor]!.maxY),
                    CGPoint(x: capacitorX, y: bottomY)
                ]).stroke(color, style: circuitStroke)
            }

            battery(at: CGPoint(x: leftX, y: board.midY), color: color)
            bulbView(at: bulb)

            ForEach(viewModel.components.map(\.kind), id: \.self) { kind in
                if let slot = slots[kind], !isPlaced(kind) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.3, dash: [6, 5]))
                        .frame(width: slot.width, height: slot.height)
                        .position(x: slot.midX, y: slot.midY)
                }
            }

            if viewModel.circuitComplete {
                Button(action: viewModel.toggleSwitch) {
                    Color.clear
                        .frame(width: slots[.switch]!.width + 24, height: slots[.switch]!.height + 24)
                }
                .buttonStyle(.plain)
                .position(x: slots[.switch]!.midX, y: slots[.switch]!.midY)
                .zIndex(8)
            }

            electronLayer(board: board, leftX: leftX, rightX: rightX, topY: topY, bottomY: bottomY)
        }
    }

    private func isPlaced(_ kind: LevelTwentyFourComponentKind) -> Bool {
        viewModel.components.first(where: { $0.kind == kind })?.isPlaced == true
    }

    private func componentView(_ component: LevelTwentyFourComponent) -> some View {
        let color = viewModel.powered ? Color.mathItLogic : Color.white.opacity(component.isPlaced ? 0.82 : 0.9)
        return Group {
            switch component.kind {
            case .switch:
                ZStack {
                    Circle().fill(color).frame(width: 8, height: 8).offset(x: -27)
                    Circle().fill(color).frame(width: 8, height: 8).offset(x: 27)
                    Capsule()
                        .fill(color)
                        .frame(width: 48, height: 3)
                        .rotationEffect(.degrees(viewModel.switchClosed ? 0 : -24), anchor: .trailing)
                }
                .frame(width: 74, height: 44)
            case .resistor:
                LevelTwentyFourResistorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 30, height: 68)
            case .capacitor:
                ZStack {
                    Capsule().fill(color).frame(width: 34, height: 3).offset(y: -7)
                    Capsule().fill(color).frame(width: 34, height: 3).offset(y: 7)
                    Capsule().fill(color).frame(width: 3, height: 22).offset(y: -20)
                    Capsule().fill(color).frame(width: 3, height: 22).offset(y: 20)
                }
                .frame(width: 52, height: 76)
            case .wire:
                Capsule()
                    .fill(color)
                    .frame(width: 70, height: 3)
            }
        }
        .shadow(color: Color.mathItLogic.opacity(viewModel.powered ? 0.62 : 0.08), radius: viewModel.powered ? 12 : 5)
    }

    private func battery(at point: CGPoint, color: Color) -> some View {
        ZStack {
            Capsule().fill(color).frame(width: 32, height: 3).offset(y: -9)
            Capsule().fill(color).frame(width: 20, height: 3).offset(y: 9)
            Text("+").font(.system(size: 11, weight: .semibold)).foregroundStyle(color).offset(x: -25, y: -9)
            Text("-").font(.system(size: 11, weight: .semibold)).foregroundStyle(color).offset(x: -25, y: 9)
        }
        .position(point)
    }

    private func bulbView(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(viewModel.powered ? Color.mathItLogic.opacity(0.34) : .black)
                .overlay {
                    Circle().stroke(viewModel.powered ? Color.mathItLogic : Color.mathGold.opacity(0.85), lineWidth: 2)
                }
                .frame(width: 46, height: 46)

            Image(systemName: "lightbulb")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(viewModel.powered ? Color.mathItLogic : .white.opacity(0.64))
        }
        .shadow(color: Color.mathItLogic.opacity(viewModel.powered ? 0.8 : 0), radius: 22)
        .position(point)
    }

    private func electronLayer(board: CGRect, leftX: CGFloat, rightX: CGFloat, topY: CGFloat, bottomY: CGFloat) -> some View {
        Group {
            if let poweredAt = viewModel.poweredAt, viewModel.powered {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(poweredAt)
                    let progress = CGFloat(elapsed.truncatingRemainder(dividingBy: 1.8) / 1.8)
                    Circle()
                        .fill(Color.mathItLogic)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.mathItLogic.opacity(0.9), radius: 12)
                        .position(circuitPoint(progress: progress, leftX: leftX, rightX: rightX, topY: topY, bottomY: bottomY))
                }
            }
        }
    }

    private func circuitPoint(progress: CGFloat, leftX: CGFloat, rightX: CGFloat, topY: CGFloat, bottomY: CGFloat) -> CGPoint {
        let width = rightX - leftX
        let height = bottomY - topY
        let perimeter = width * 2 + height * 2
        let distance = progress * perimeter

        if distance < width { return CGPoint(x: leftX + distance, y: topY) }
        if distance < width + height { return CGPoint(x: rightX, y: topY + distance - width) }
        if distance < width * 2 + height { return CGPoint(x: rightX - (distance - width - height), y: bottomY) }
        return CGPoint(x: leftX, y: bottomY - (distance - width * 2 - height))
    }

    private func circuitPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private var circuitStroke: StrokeStyle {
        StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
    }
}

private struct LevelTwentyFourResistorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let step = rect.height / 8
        path.move(to: CGPoint(x: centerX, y: rect.minY))
        for index in 1..<8 {
            let x = index.isMultiple(of: 2) ? rect.minX + 3 : rect.maxX - 3
            path.addLine(to: CGPoint(x: x, y: rect.minY + CGFloat(index) * step))
        }
        path.addLine(to: CGPoint(x: centerX, y: rect.maxY))
        return path
    }
}
