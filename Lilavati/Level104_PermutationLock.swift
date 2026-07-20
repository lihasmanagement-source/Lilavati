import SwiftUI

enum LevelThirtySevenToken: Int, CaseIterable, Identifiable {
    case circle
    case triangle
    case square

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .circle: "circle.fill"
        case .triangle: "triangle.fill"
        case .square: "square.fill"
        }
    }
}

@Observable
final class MathItLevelThirtySevenViewModel {
    var slots: [LevelThirtySevenToken?] = [nil, nil, nil]
    var offsets: [LevelThirtySevenToken: CGSize] = [:]
    var foundOrders: [[LevelThirtySevenToken]] = []
    var duplicateFlash = false
    var ballProgress: CGFloat = 0
    var completed = false

    var progress: Double {
        completed ? 1 : Double(foundOrders.count) / 6
    }

    func move(_ token: LevelThirtySevenToken, translation: CGSize) {
        guard !slots.contains(token), !completed else { return }
        offsets[token] = translation
    }

    func finish(_ token: LevelThirtySevenToken, endPoint: CGPoint, slotFrames: [CGRect]) {
        guard !slots.contains(token), !completed else { return }
        guard let target = slotFrames.indices.first(where: {
            slots[$0] == nil && slotFrames[$0].insetBy(dx: -14, dy: -14).contains(endPoint)
        }) else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                offsets[token] = .zero
            }
            return
        }

        HapticPlayer.playLightTap()
        slots[target] = token
        offsets[token] = .zero
        guard slots.allSatisfy({ $0 != nil }) else { return }
        evaluateOrder()
    }

    func remove(_ token: LevelThirtySevenToken) {
        guard let index = slots.firstIndex(where: { $0 == token }), !completed else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
            slots[index] = nil
        }
    }

    private func evaluateOrder() {
        let order = slots.compactMap { $0 }
        if foundOrders.contains(order) {
            duplicateFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.74)) {
                    self.duplicateFlash = false
                    self.slots = [nil, nil, nil]
                }
            }
            return
        }

        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.56, dampingFraction: 0.7)) {
            foundOrders.append(order)
        }

        guard foundOrders.count == 6 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
                    self.slots = [nil, nil, nil]
                }
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 2.35)) {
                self.ballProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.15) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }
}

struct MathItLevelThirtySevenView: View {
    var viewModel: MathItLevelThirtySevenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let green = Color.mathItLogic

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let slotFrames = slots(in: size)
            let sources = tokenSources(in: size)
            let center = CGPoint(x: size.width / 2, y: size.height * 0.48)

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
                        .font(.trajan(36))
                        .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.34))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(green)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                combinationRing(center: center, radius: min(118, size.width * 0.29))
                arrangementSlots(slotFrames)
                tokenBank(sources: sources, slotFrames: slotFrames)
                escapingBall(center: center, width: size.width)

                CompletionOverlay(
                    title: "Level 37 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelThirtySevenStage")
        }
    }

    private func slots(in size: CGSize) -> [CGRect] {
        let width: CGFloat = 62
        let gap: CGFloat = 18
        let total = width * 3 + gap * 2
        return (0..<3).map { index in
            CGRect(
                x: size.width / 2 - total / 2 + CGFloat(index) * (width + gap),
                y: size.height * 0.72,
                width: width,
                height: 62
            )
        }
    }

    private func tokenSources(in size: CGSize) -> [LevelThirtySevenToken: CGPoint] {
        Dictionary(uniqueKeysWithValues: LevelThirtySevenToken.allCases.map { token in
            (token, CGPoint(x: size.width * (0.25 + CGFloat(token.rawValue) * 0.25), y: size.height * 0.88))
        })
    }

    private func combinationRing(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1.2, dash: [4, 7]))
                .frame(width: radius * 2, height: radius * 2)
                .position(center)

            ForEach(0..<6, id: \.self) { index in
                let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 3
                let unlocked = index < viewModel.foundOrders.count
                Circle()
                    .fill(unlocked ? green : .black)
                    .overlay {
                        Circle().stroke(unlocked ? green : Color.mathGold.opacity(0.5), lineWidth: 1.4)
                    }
                    .frame(width: unlocked ? 20 : 16, height: unlocked ? 20 : 16)
                    .shadow(color: unlocked ? green.opacity(0.72) : .clear, radius: 9)
                    .position(
                        x: center.x + CGFloat(cos(angle)) * radius,
                        y: center.y + CGFloat(sin(angle)) * radius
                    )
            }
        }
    }

    private func arrangementSlots(_ frames: [CGRect]) -> some View {
        ZStack {
            ForEach(frames.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7)
                    .fill(viewModel.duplicateFlash ? Color.mathItLogic.opacity(0.08) : .white.opacity(0.025))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(viewModel.duplicateFlash ? Color.mathItLogic.opacity(0.75) : green.opacity(0.42), lineWidth: 1.2)
                    }
                    .frame(width: frames[index].width, height: frames[index].height)
                    .position(x: frames[index].midX, y: frames[index].midY)

                if let token = viewModel.slots[index] {
                    tokenView(token, active: true)
                        .position(x: frames[index].midX, y: frames[index].midY)
                        .onTapGesture { viewModel.remove(token) }
                }
            }
        }
    }

    private func tokenBank(
        sources: [LevelThirtySevenToken: CGPoint],
        slotFrames: [CGRect]
    ) -> some View {
        ZStack {
            ForEach(LevelThirtySevenToken.allCases) { token in
                if !viewModel.slots.contains(token), let source = sources[token] {
                    let offset = viewModel.offsets[token, default: .zero]
                    tokenView(token, active: false)
                        .position(x: source.x + offset.width, y: source.y + offset.height)
                        .gesture(
                            DragGesture(coordinateSpace: .named("levelThirtySevenStage"))
                                .onChanged { value in viewModel.move(token, translation: value.translation) }
                                .onEnded { value in
                                    viewModel.finish(
                                        token,
                                        endPoint: CGPoint(
                                            x: source.x + value.translation.width,
                                            y: source.y + value.translation.height
                                        ),
                                        slotFrames: slotFrames
                                    )
                                }
                        )
                }
            }
        }
        .zIndex(8)
    }

    private func tokenView(_ token: LevelThirtySevenToken, active: Bool) -> some View {
        Image(systemName: token.symbol)
            .font(.system(size: 27, weight: .regular))
            .foregroundStyle(active ? green : .white)
            .frame(width: 52, height: 52)
            .shadow(color: active ? green.opacity(0.72) : .white.opacity(0.36), radius: active ? 10 : 6)
    }

    private func escapingBall(center: CGPoint, width: CGFloat) -> some View {
        let hop = abs(sin(viewModel.ballProgress * .pi * 5)) * 15
        return Circle()
            .fill(.white)
            .frame(width: 25, height: 25)
            .shadow(color: .white.opacity(0.82), radius: 12)
            .position(
                x: center.x + viewModel.ballProgress * width * 0.65,
                y: center.y - hop
            )
            .zIndex(7)
    }
}
