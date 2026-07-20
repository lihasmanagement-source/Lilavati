import SwiftUI

enum LevelFortyFourOperation: String, CaseIterable, Identifiable {
    case double = "×2"
    case triple = "×3"
    case addThree = "+3"
    case addFour = "+4"
    case subtractTwo = "−2"
    case subtractThree = "−3"

    var id: String { rawValue }

    func apply(to value: Int) -> Int {
        switch self {
        case .double: value * 2
        case .triple: value * 3
        case .addThree: value + 3
        case .addFour: value + 4
        case .subtractTwo: value - 2
        case .subtractThree: value - 3
        }
    }
}

struct LevelFortyFourStage {
    let input: Int
    let target: Int
    let operations: [LevelFortyFourOperation]
    let bankOrder: [LevelFortyFourOperation]
}

@Observable
final class MathItLevelFortyFourViewModel {
    let stages = [
        LevelFortyFourStage(
            input: 2,
            target: 21,
            operations: [.double, .addThree, .triple],
            bankOrder: [.triple, .double, .addThree]
        ),
        LevelFortyFourStage(
            input: 1,
            target: 7,
            operations: [.addFour, .double, .subtractThree],
            bankOrder: [.subtractThree, .addFour, .double]
        ),
        LevelFortyFourStage(
            input: 3,
            target: 14,
            operations: [.triple, .subtractTwo, .double],
            bankOrder: [.double, .triple, .subtractTwo]
        )
    ]

    var stage = 0
    var arranged: [LevelFortyFourOperation] = []
    var running = false
    var activeGear = -1
    var displayedValue = 0
    var gearTurn = 0.0
    var outputPulse = false
    var failed = false
    var completed = false
    private var runID = UUID()

    init() {
        displayedValue = stages[0].input
    }

    var currentStage: LevelFortyFourStage {
        stages[min(stage, stages.count - 1)]
    }

    var availableOperations: [LevelFortyFourOperation] {
        currentStage.operations.filter { !arranged.contains($0) }
    }

    var progress: Double {
        completed ? 1 : Double(stage) / Double(stages.count)
    }

    func place(_ operation: LevelFortyFourOperation) {
        guard !running, arranged.count < currentStage.operations.count, !arranged.contains(operation) else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            arranged.append(operation)
        }
    }

    func remove(at index: Int) {
        guard !running, arranged.indices.contains(index) else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            let _ = arranged.remove(at: index)
        }
    }

    func crank() {
        guard !running, arranged.count == currentStage.operations.count else { return }
        let id = UUID()
        runID = id
        running = true
        displayedValue = currentStage.input
        activeGear = -1
        runGear(at: 0, value: currentStage.input, id: id)
    }

    private func runGear(at index: Int, value: Int, id: UUID) {
        guard id == runID else { return }
        guard arranged.indices.contains(index) else {
            finish(value: value, id: id)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            guard id == self.runID else { return }
            let next = self.arranged[index].apply(to: value)
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.68)) {
                self.activeGear = index
                self.displayedValue = next
                self.gearTurn += 90
            }
            self.runGear(at: index + 1, value: next, id: id)
        }
    }

    private func finish(value: Int, id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard id == self.runID else { return }
            if value == self.currentStage.target {
                self.succeed()
            } else {
                self.fail()
            }
        }
    }

    private func fail() {
        failed = true
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
            activeGear = -1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
                self.arranged.removeAll()
                self.displayedValue = self.currentStage.input
                self.failed = false
                self.running = false
            }
        }
    }

    private func succeed() {
        HapticPlayer.playCompletionTap()
        withAnimation(.easeInOut(duration: 0.42)) {
            outputPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            if self.stage == self.stages.count - 1 {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                    self.completed = true
                }
                return
            }

            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                self.stage += 1
                self.arranged.removeAll()
                self.displayedValue = self.currentStage.input
                self.activeGear = -1
                self.outputPulse = false
                self.running = false
            }
        }
    }
}

struct MathItLevelFortyFourView: View {
    var viewModel: MathItLevelFortyFourViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let orange = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)
                dials(size: size)
                machine(size: size)
                operationBank(size: size)

                CompletionOverlay(
                    title: "Level 44 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 10) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.trajan(34))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.34))

            ProgressView(value: viewModel.progress)
                .tint(orange)
                .frame(width: max(180, size.width - 68))
                .opacity(0.76)
                .padding(.top, 4)
        }
        .position(x: size.width / 2, y: 94)
    }

    private func dials(size: CGSize) -> some View {
        HStack(spacing: max(65, size.width * 0.23)) {
            numberDial(value: viewModel.currentStage.input, target: false)

            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.28))

            numberDial(value: viewModel.currentStage.target, target: true)
        }
        .position(x: size.width / 2, y: size.height * 0.24)
    }

    private func numberDial(value: Int, target: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(target && viewModel.outputPulse ? orange : .white.opacity(0.24), lineWidth: target && viewModel.outputPulse ? 2.5 : 1.2)
                .frame(width: 76, height: 76)
                .shadow(color: target && viewModel.outputPulse ? orange.opacity(0.8) : .clear, radius: 16)

            Text("\(value)")
                .font(.trajan(30))
                .foregroundStyle(target ? orange : .white)
        }
    }

    private func machine(size: CGSize) -> some View {
        let count = viewModel.currentStage.operations.count
        let radius: CGFloat = 45
        let spacing = min(112, (size.width - 70) / CGFloat(count - 1))
        let startX = size.width / 2 - spacing * CGFloat(count - 1) / 2
        let y = size.height * 0.48

        return ZStack {
            Capsule()
                .fill(.white.opacity(0.12))
                .frame(width: spacing * CGFloat(count - 1), height: 3)
                .position(x: size.width / 2, y: y)

            ForEach(0..<count, id: \.self) { index in
                let operation = viewModel.arranged.indices.contains(index) ? viewModel.arranged[index] : nil
                operationSlot(operation, index: index, radius: radius)
                    .position(x: startX + CGFloat(index) * spacing, y: y)
            }

            HStack(spacing: 13) {
                Text("\(viewModel.displayedValue)")
                    .font(.system(size: 27, weight: .medium, design: .monospaced))
                    .foregroundStyle(viewModel.failed ? orange.opacity(0.45) : .white)
                    .contentTransition(.numericText())

                Button(action: viewModel.crank) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(viewModel.arranged.count == count ? .black : .white.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .background(viewModel.arranged.count == count ? orange : .white.opacity(0.04), in: Circle())
                        .shadow(color: viewModel.arranged.count == count ? orange.opacity(0.6) : .clear, radius: 10)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.arranged.count != count || viewModel.running)
            }
            .position(x: size.width / 2, y: size.height * 0.64)
        }
    }

    private func operationSlot(_ operation: LevelFortyFourOperation?, index: Int, radius: CGFloat) -> some View {
        Button {
            viewModel.remove(at: index)
        } label: {
            ZStack {
                LevelFortyFourGearShape(teeth: 10)
                    .stroke(
                        viewModel.activeGear == index ? orange : .white.opacity(operation == nil ? 0.18 : 0.68),
                        lineWidth: viewModel.activeGear == index ? 2.8 : 1.5
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees((index.isMultiple(of: 2) ? 1 : -1) * viewModel.gearTurn))
                    .shadow(color: viewModel.activeGear == index ? orange.opacity(0.8) : .clear, radius: 14)

                Circle()
                    .fill(.black)
                    .overlay { Circle().stroke(.white.opacity(0.24), lineWidth: 1) }
                    .frame(width: 48, height: 48)

                Text(operation?.rawValue ?? "?")
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(operation == nil ? .white.opacity(0.22) : .white)
            }
        }
        .buttonStyle(.plain)
        .disabled(operation == nil || viewModel.running)
    }

    private func operationBank(size: CGSize) -> some View {
        HStack(spacing: 18) {
            ForEach(viewModel.currentStage.bankOrder) { operation in
                let available = viewModel.availableOperations.contains(operation)

                Button {
                    viewModel.place(operation)
                } label: {
                    ZStack {
                        LevelFortyFourGearShape(teeth: 8)
                            .stroke(available ? orange.opacity(0.76) : .white.opacity(0.1), lineWidth: 1.5)
                            .frame(width: 64, height: 64)

                        Text(operation.rawValue)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(available ? orange : .white.opacity(0.14))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!available || viewModel.running)
            }
        }
        .position(x: size.width / 2, y: size.height * 0.76)
    }

}

private struct LevelFortyFourGearShape: Shape {
    let teeth: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.49
        let rootRadius = outerRadius * 0.78
        let count = teeth * 4
        var path = Path()

        for index in 0..<count {
            let radius = index % 4 == 1 || index % 4 == 2 ? outerRadius : rootRadius
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(count)
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
