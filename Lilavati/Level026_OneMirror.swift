import SwiftUI

@Observable
final class MathItLevelOneViewModel {
    var originalOffset = CGSize.zero
    var reflectionOffset = CGSize.zero
    var originalDragAnchor: CGSize?
    var reflectionDragAnchor: CGSize?
    var mirrorDropOffset: CGSize?
    var mirrorActivated = false
    var reflectionPulled = false
    var originalPlaced = false
    var reflectionPlaced = false
    var placedLeftOne = false
    var placedRightOne = false
    var completed = false

    var progress: Double {
        if completed { return 1 }
        let mirrorProgress = mirrorActivated ? 0.28 : 0
        let pulledProgress = reflectionPulled ? 0.24 : 0
        let placedProgress = Double([placedLeftOne, placedRightOne].filter { $0 }.count) * 0.2
        return min(0.92, 0.08 + mirrorProgress + pulledProgress + placedProgress)
    }

    func updateOriginalDrag(_ translation: CGSize) {
        guard !originalPlaced, !completed else { return }
        if originalDragAnchor == nil {
            originalDragAnchor = originalOffset
        }
        let anchor = originalDragAnchor ?? .zero
        originalOffset = CGSize(width: anchor.width + translation.width, height: anchor.height + translation.height)
    }

    func endOriginalDrag(base: CGPoint, translation: CGSize, mirrorGlass: CGRect, leftSlot: CGRect, rightSlot: CGRect, symbolSize: CGSize) {
        guard !originalPlaced, !completed else { return }
        updateOriginalDrag(translation)
        originalDragAnchor = nil
        let point = CGPoint(x: base.x + originalOffset.width, y: base.y + originalOffset.height)

        if mirrorActivated, placeOneIfAccepted(at: point, leftSlot: leftSlot, rightSlot: rightSlot, symbolSize: symbolSize) {
            originalPlaced = true
            originalOffset = .zero
            checkCompletion()
            return
        }

        if mirrorGlass.contains(point) {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                mirrorActivated = true
                mirrorDropOffset = originalOffset
            }
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.74)) {
            originalOffset = mirrorActivated
                ? mirrorDropOffset ?? originalOffset
                : .zero
        }
    }

    func updateReflectionDrag(_ translation: CGSize) {
        guard mirrorActivated, !reflectionPlaced, !completed else { return }
        if reflectionDragAnchor == nil {
            reflectionDragAnchor = reflectionOffset
        }
        let anchor = reflectionDragAnchor ?? .zero
        reflectionOffset = CGSize(width: anchor.width + translation.width, height: anchor.height + translation.height)
        if !reflectionPulled, abs(reflectionOffset.width) + abs(reflectionOffset.height) > 18 {
            HapticPlayer.playLightTap()
            reflectionPulled = true
        }
    }

    func endReflectionDrag(base: CGPoint, translation: CGSize, leftSlot: CGRect, rightSlot: CGRect, symbolSize: CGSize) {
        guard mirrorActivated, !reflectionPlaced, !completed else { return }
        updateReflectionDrag(translation)
        reflectionDragAnchor = nil
        let point = CGPoint(x: base.x + reflectionOffset.width, y: base.y + reflectionOffset.height)

        if reflectionPulled, placeOneIfAccepted(at: point, leftSlot: leftSlot, rightSlot: rightSlot, symbolSize: symbolSize) {
            reflectionPlaced = true
            reflectionOffset = .zero
            checkCompletion()
            return
        }
    }

    private func checkCompletion() {
        guard placedLeftOne, placedRightOne, !completed else { return }
        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.64, dampingFraction: 0.84)) {
            completed = true
        }
    }

    private func placeOneIfAccepted(at point: CGPoint, leftSlot: CGRect, rightSlot: CGRect, symbolSize: CGSize) -> Bool {
        let leftAccepted = !placedLeftOne && acceptsOnePlacement(at: point, in: leftSlot, symbolSize: symbolSize)
        let rightAccepted = !placedRightOne && acceptsOnePlacement(at: point, in: rightSlot, symbolSize: symbolSize)

        guard leftAccepted || rightAccepted else { return false }

        if leftAccepted && rightAccepted {
            let leftDistance = hypot(point.x - leftSlot.midX, point.y - leftSlot.midY)
            let rightDistance = hypot(point.x - rightSlot.midX, point.y - rightSlot.midY)
            if leftDistance <= rightDistance {
                placedLeftOne = true
            } else {
                placedRightOne = true
            }
        } else if leftAccepted {
            placedLeftOne = true
        } else {
            placedRightOne = true
        }

        return true
    }

    private func acceptsOnePlacement(at point: CGPoint, in slot: CGRect, symbolSize: CGSize) -> Bool {
        let visibleOneSize = CGSize(
            width: symbolSize.width * 0.46,
            height: symbolSize.height * 0.86
        )
        let visibleOneFrame = CGRect(
            x: point.x - visibleOneSize.width / 2,
            y: point.y - visibleOneSize.height / 2,
            width: visibleOneSize.width,
            height: visibleOneSize.height
        )
        return slot.insetBy(dx: -24, dy: -24).intersects(visibleOneFrame)
            || slot.insetBy(dx: -46, dy: -46).contains(point)
    }
}

struct MathItLevelOneView: View {
    var viewModel: MathItLevelOneViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let symbolSize = CGSize(width: 92, height: 122)
    private let equalsSize = CGSize(width: 92, height: 70)

    // Level 1 now has two stages: the mirror (stage 1) and the former level-3
    // Mirror Cascade (stage 2), hosted here as an embedded view.
    @State private var stage = 1
    @State private var stageTwo = MirrorCascadeViewModel()
    @State private var levelDone = false

    var body: some View {
        ZStack {
            if stage == 1 {
                stageOne
            } else {
                MirrorCascadeView(
                    viewModel: stageTwo,
                    onContinue: {},
                    onReplay: {},
                    onLevelSelect: onLevelSelect,
                    embedded: true
                )
                .transition(.opacity)
            }

            if let concept = ConceptLibrary.concept(for: 1) {
                ConceptCompletionOverlay(
                    levelTitle: "One Mirror",
                    concept: concept,
                    isVisible: levelDone,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
            }
        }
        .onChange(of: viewModel.completed) { _, done in
            // Stage 1 solved → briefly show the 1 = 1 equation, then reveal stage 2.
            if done, stage == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeInOut(duration: 0.5)) { stage = 2 }
                }
            }
        }
        .onChange(of: stageTwo.completed) { _, done in
            if done { withAnimation(.spring(response: 0.64, dampingFraction: 0.84)) { levelDone = true } }
        }
    }

    private var stageOne: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let equationY = size.height * 0.36
            let slotSpacing: CGFloat = 98
            let leftOneSlot = CGRect(x: size.width / 2 - slotSpacing - symbolSize.width / 2, y: equationY - symbolSize.height / 2, width: symbolSize.width, height: symbolSize.height)
            let equalsSlot = CGRect(x: size.width / 2 - equalsSize.width / 2, y: equationY - equalsSize.height / 2, width: equalsSize.width, height: equalsSize.height)
            let rightOneSlot = CGRect(x: size.width / 2 + slotSpacing - symbolSize.width / 2, y: equationY - symbolSize.height / 2, width: symbolSize.width, height: symbolSize.height)
            let mirrorCenter = CGPoint(x: size.width / 2, y: size.height * 0.72)
            let mirrorSize = CGSize(width: min(138, size.width * 0.36), height: 168)
            let mirrorGlass = CGRect(x: mirrorCenter.x - mirrorSize.width / 2, y: mirrorCenter.y - mirrorSize.height / 2, width: mirrorSize.width, height: mirrorSize.height)
            let originalBase = CGPoint(
                x: mirrorCenter.x,
                y: mirrorCenter.y - mirrorSize.height * 0.98
            )
            let originalPoint = CGPoint(x: originalBase.x + viewModel.originalOffset.width, y: originalBase.y + viewModel.originalOffset.height)
            let mirrorSourcePoint = viewModel.mirrorDropOffset.map {
                CGPoint(x: originalBase.x + $0.width, y: originalBase.y + $0.height)
            } ?? originalPoint
            let reflectionBase = mirrorReflectionPoint(
                originalPoint: mirrorSourcePoint,
                mirrorCenter: mirrorCenter,
                mirrorSize: mirrorSize
            )
            let mirrorDistance = distance(mirrorSourcePoint, mirrorCenter)

            ZStack {
                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)
                ProgressView(value: viewModel.progress)
                    .tint(.white)
                    .opacity(0.72)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 150)

                assembledEquation(leftOneSlot: leftOneSlot, equalsSlot: equalsSlot, rightOneSlot: rightOneSlot)

                mirrorStage(
                    mirrorCenter: mirrorCenter,
                    mirrorSize: mirrorSize,
                    originalPoint: mirrorSourcePoint,
                    reflectionPoint: reflectionBase,
                    mirrorDistance: mirrorDistance,
                    revealDistance: mirrorSize.height * 0.82
                )

                if !viewModel.originalPlaced {
                    originalOne(
                        basePoint: originalBase,
                        mirrorGlass: mirrorGlass,
                        leftSlot: leftOneSlot,
                        rightSlot: rightOneSlot
                    )
                }

                if viewModel.mirrorActivated && !viewModel.reflectionPlaced {
                    reflectedOne(basePoint: reflectionBase, leftSlot: leftOneSlot, rightSlot: rightOneSlot)
                }
            }
        }
    }

    private func header(size: CGSize) -> some View {
        EmptyView()
    }

    private func assembledEquation(leftOneSlot: CGRect, equalsSlot: CGRect, rightOneSlot: CGRect) -> some View {
        return ZStack {
            if !viewModel.placedLeftOne {
                SymbolOneView(fontSize: 92, glow: false)
                    .frame(width: leftOneSlot.width, height: leftOneSlot.height)
                    .opacity(0.13)
                    .position(x: leftOneSlot.midX, y: leftOneSlot.midY)
            }

            if viewModel.placedLeftOne {
                SymbolOneView(fontSize: 92, glow: true)
                    .frame(width: leftOneSlot.width, height: leftOneSlot.height)
                    .position(x: leftOneSlot.midX, y: leftOneSlot.midY)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            EqualsSymbolView(color: .white.opacity(0.92), glow: true)
                .frame(width: equalsSlot.width, height: equalsSlot.height)
                .position(x: equalsSlot.midX, y: equalsSlot.midY)

            if !viewModel.placedRightOne {
                SymbolOneView(fontSize: 92, glow: false)
                    .frame(width: rightOneSlot.width, height: rightOneSlot.height)
                    .opacity(0.13)
                    .position(x: rightOneSlot.midX, y: rightOneSlot.midY)
            }

            if viewModel.placedRightOne {
                SymbolOneView(fontSize: 92, glow: true)
                    .frame(width: rightOneSlot.width, height: rightOneSlot.height)
                    .position(x: rightOneSlot.midX, y: rightOneSlot.midY)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    private func mirrorStage(
        mirrorCenter: CGPoint,
        mirrorSize: CGSize,
        originalPoint: CGPoint,
        reflectionPoint: CGPoint,
        mirrorDistance: CGFloat,
        revealDistance: CGFloat
    ) -> some View {
        ZStack {
            ForEach(0..<28, id: \.self) { index in
                let angle = Double(index) / 28 * Double.pi * 2
                let radiusX = mirrorSize.width * 0.55
                let radiusY = mirrorSize.height * 0.52
                Circle()
                    .stroke(Color.mathGold.opacity(0.7), lineWidth: 1.2)
                    .frame(width: 7, height: 7)
                    .position(
                        x: mirrorCenter.x + CGFloat(cos(angle)) * radiusX,
                        y: mirrorCenter.y + CGFloat(sin(angle)) * radiusY
                    )
            }

            Path { path in
                path.move(to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y - mirrorSize.height * 0.66))
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y - mirrorSize.height * 0.55),
                    control: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.16, y: mirrorCenter.y - mirrorSize.height * 0.61)
                )
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y - mirrorSize.height * 0.66),
                    control: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.16, y: mirrorCenter.y - mirrorSize.height * 0.61)
                )

                path.move(to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y + mirrorSize.height * 0.66))
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y + mirrorSize.height * 0.55),
                    control: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.16, y: mirrorCenter.y + mirrorSize.height * 0.61)
                )
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x, y: mirrorCenter.y + mirrorSize.height * 0.66),
                    control: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.16, y: mirrorCenter.y + mirrorSize.height * 0.61)
                )

                path.move(to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.62, y: mirrorCenter.y))
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.78, y: mirrorCenter.y),
                    control: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.69, y: mirrorCenter.y - mirrorSize.height * 0.11)
                )
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.62, y: mirrorCenter.y),
                    control: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.69, y: mirrorCenter.y + mirrorSize.height * 0.11)
                )

                path.move(to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.62, y: mirrorCenter.y))
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.78, y: mirrorCenter.y),
                    control: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.69, y: mirrorCenter.y - mirrorSize.height * 0.11)
                )
                path.addQuadCurve(
                    to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.62, y: mirrorCenter.y),
                    control: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.69, y: mirrorCenter.y + mirrorSize.height * 0.11)
                )
            }
            .stroke(Color.mathGold.opacity(0.78), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))

            Ellipse()
                .stroke(Color.mathGold.opacity(0.95), lineWidth: 8)
                .frame(width: mirrorSize.width + 18, height: mirrorSize.height + 18)
                .position(mirrorCenter)
                .shadow(color: viewModel.mirrorActivated ? Color.mathGold.opacity(0.45) : Color.mathGold.opacity(0.18), radius: 10)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.73, green: 0.95, blue: 1.0).opacity(0.92),
                            Color(red: 0.45, green: 0.82, blue: 0.94).opacity(0.78),
                            Color(red: 0.18, green: 0.32, blue: 0.42).opacity(0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: mirrorSize.width, height: mirrorSize.height)
                .overlay(
                    Ellipse()
                        .stroke(.white.opacity(0.78), lineWidth: 1.3)
                )
                .position(mirrorCenter)

            Path { path in
                path.move(to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.22, y: mirrorCenter.y - mirrorSize.height * 0.38))
                path.addLine(to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.2, y: mirrorCenter.y + mirrorSize.height * 0.06))
                path.move(to: CGPoint(x: mirrorCenter.x - mirrorSize.width * 0.1, y: mirrorCenter.y - mirrorSize.height * 0.46))
                path.addLine(to: CGPoint(x: mirrorCenter.x + mirrorSize.width * 0.32, y: mirrorCenter.y - mirrorSize.height * 0.02))
            }
            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            if !viewModel.mirrorActivated && mirrorDistance < revealDistance {
                let approach = max(0, min(1, 1 - mirrorDistance / revealDistance))
                SymbolOneView(fontSize: 92, glow: viewModel.mirrorActivated)
                    .scaleEffect(x: -1, y: 1)
                    .opacity(viewModel.mirrorActivated ? 0.68 : Double(0.12 + approach * 0.5))
                    .blur(radius: viewModel.mirrorActivated ? 0 : (1 - approach) * 1.2)
                    .frame(width: symbolSize.width, height: symbolSize.height)
                    .position(reflectionPoint)
                    .allowsHitTesting(false)
            }
        }
    }

    private func originalOne(basePoint: CGPoint, mirrorGlass: CGRect, leftSlot: CGRect, rightSlot: CGRect) -> some View {
        let displayedPoint = CGPoint(x: basePoint.x + viewModel.originalOffset.width, y: basePoint.y + viewModel.originalOffset.height)

        return SymbolOneView(fontSize: 92, glow: viewModel.mirrorActivated)
            .frame(width: symbolSize.width, height: symbolSize.height)
            .position(displayedPoint)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.updateOriginalDrag(value.translation)
                    }
                    .onEnded { value in
                        viewModel.endOriginalDrag(
                            base: basePoint,
                            translation: value.translation,
                            mirrorGlass: mirrorGlass,
                            leftSlot: leftSlot,
                            rightSlot: rightSlot,
                            symbolSize: symbolSize
                        )
                    }
            )
            .accessibilityLabel("Number one")
    }

    private func reflectedOne(basePoint: CGPoint, leftSlot: CGRect, rightSlot: CGRect) -> some View {
        SymbolOneView(fontSize: 92, glow: true)
            .scaleEffect(x: viewModel.reflectionPulled ? 1 : -1, y: 1)
            .opacity(viewModel.reflectionPulled ? 1 : 0.78)
            .frame(width: symbolSize.width, height: symbolSize.height)
            .position(x: basePoint.x + viewModel.reflectionOffset.width, y: basePoint.y + viewModel.reflectionOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.updateReflectionDrag(value.translation)
                    }
                    .onEnded { value in
                        viewModel.endReflectionDrag(
                            base: basePoint,
                            translation: value.translation,
                            leftSlot: leftSlot,
                            rightSlot: rightSlot,
                            symbolSize: symbolSize
                        )
                    }
            )
            .accessibilityLabel("Reflected number one")
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    private func mirrorReflectionPoint(originalPoint: CGPoint, mirrorCenter: CGPoint, mirrorSize: CGSize) -> CGPoint {
        let horizontalShift = mirrorCenter.x - originalPoint.x
        let verticalShift = mirrorCenter.y - originalPoint.y
        let sideBias = abs(horizontalShift) < 8 ? mirrorSize.width * 0.18 : 0

        return CGPoint(
            x: mirrorCenter.x + horizontalShift * 0.34 + sideBias,
            y: mirrorCenter.y + min(mirrorSize.height * 0.22, max(-mirrorSize.height * 0.2, verticalShift * 0.2))
        )
    }
}
