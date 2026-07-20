import SwiftUI

@Observable
final class MathItLevelNineViewModel {
    var lensSizes: [UUID: CGSize] = [:]
    var lensPositions: [UUID: CGPoint] = [:]
    var activeLensOffsets: [UUID: CGSize] = [:]
    var isFiringBeam = false
    var cageCharge = 0.0
    var ballReleased = false
    var ballInGoal = false
    var completed = false

    let lenses: [LevelNineLens] = [
        LevelNineLens(id: UUID(), tint: Color(red: 0.66, green: 0.9, blue: 1.0), startingSize: CGSize(width: 52, height: 126)),
        LevelNineLens(id: UUID(), tint: Color(red: 0.94, green: 0.83, blue: 0.42), startingSize: CGSize(width: 102, height: 72))
    ]

    var intensity: Double {
        isFiringBeam || completed ? 1 : 0
    }

    func prepareLenses(in size: CGSize) {
        for (index, lens) in lenses.enumerated() {
            if lensSizes[lens.id] == nil {
                lensSizes[lens.id] = lens.startingSize
            }
            if lensPositions[lens.id] == nil {
                lensPositions[lens.id] = lensStartPosition(index: index, in: size)
            }
        }
    }

    func moveLens(id: UUID, to location: CGPoint, targetSlots: [LevelNineLensSlot]) {
        guard !isFiringBeam, !completed else { return }

        let current = lensPositions[id] ?? location
        let grabOffset = activeLensOffsets[id] ?? CGSize(width: current.x - location.x, height: current.y - location.y)
        activeLensOffsets[id] = grabOffset
        lensPositions[id] = CGPoint(x: location.x + grabOffset.width, y: location.y + grabOffset.height)
        _ = snapLensIfClose(id: id, targetSlots: targetSlots)
        checkCompletion(targetSlots: targetSlots)
    }

    func finishMovingLens(id: UUID, targetSlots: [LevelNineLensSlot]) {
        activeLensOffsets[id] = nil
        snapLensIfSolved(id: id, targetSlots: targetSlots)
    }

    func resizeLens(id: UUID, dragLocation: CGPoint, targetSlots: [LevelNineLensSlot]) {
        guard !isFiringBeam, !completed else { return }
        let center = lensPositions[id] ?? targetSlots.first?.center ?? dragLocation

        let dx = abs(dragLocation.x - center.x)
        let dy = abs(dragLocation.y - center.y)
        let nextSize = CGSize(
            width: min(max(dx * 2, 38), 126),
            height: min(max(dy * 2, 64), 158)
        )

        lensSizes[id] = nextSize
        if snapLensIfClose(id: id, targetSlots: targetSlots) {
            HapticPlayer.playLightTap()
        }
        checkCompletion(targetSlots: targetSlots)
    }

    func snapLensIfSolved(id: UUID, targetSlots: [LevelNineLensSlot]) {
        guard !isFiringBeam, !completed else { return }

        _ = snapLensIfClose(id: id, targetSlots: targetSlots)
        checkCompletion(targetSlots: targetSlots)
    }

    func lensSolved(_ lensID: UUID, targetSlots: [LevelNineLensSlot]) -> Bool {
        matchingSlot(for: lensID, targetSlots: targetSlots) != nil
    }

    func slotSolved(_ slot: LevelNineLensSlot) -> Bool {
        lenses.contains { lensFits($0.id, in: slot) }
    }

    func focusAmount(targetSlots: [LevelNineLensSlot]) -> Double {
        guard !targetSlots.isEmpty else { return 0 }
        guard !isFiringBeam, !completed else { return 1 }

        let total = targetSlots.reduce(0.0) { partial, slot in
            let bestLensContribution = lenses.compactMap { lens -> Double? in
                guard let size = lensSizes[lens.id], let position = lensPositions[lens.id] else { return nil }
                let widthError = abs(size.width - slot.targetSize.width) / slot.targetSize.width
                let heightError = abs(size.height - slot.targetSize.height) / slot.targetSize.height
                let sizeScore = max(0, 1 - Double((widthError + heightError) * 1.5))
                let beamScore = lensBeamPresenceScore(position: position, target: slot.center)
                let slotScore = lensSlotPresenceScore(position: position, target: slot.center)
                return beamScore * (0.28 + sizeScore * 0.48 + slotScore * 0.24)
            }
            .max() ?? 0

            return partial + bestLensContribution
        }
        return min(max(total / Double(targetSlots.count), 0), 1)
    }

    private func lensMatches(_ size: CGSize, target: CGSize) -> Bool {
        let widthTolerance = max(target.width * 0.08, 4)
        let heightTolerance = max(target.height * 0.08, 7)
        return abs(size.width - target.width) <= widthTolerance && abs(size.height - target.height) <= heightTolerance
    }

    private func lensPositionMatches(_ lensID: UUID, slot: LevelNineLensSlot) -> Bool {
        guard let position = lensPositions[lensID] else { return false }
        let xTolerance = max(slot.targetSize.width * 0.12, 5)
        let yTolerance = max(slot.targetSize.height * 0.08, 7)
        return abs(position.x - slot.center.x) <= xTolerance && abs(position.y - slot.center.y) <= yTolerance
    }

    private func matchingSlot(for lensID: UUID, targetSlots: [LevelNineLensSlot]) -> LevelNineLensSlot? {
        targetSlots.first { lensFits(lensID, in: $0) }
    }

    private func lensFits(_ lensID: UUID, in slot: LevelNineLensSlot) -> Bool {
        guard let size = lensSizes[lensID] else { return false }
        return lensMatches(size, target: slot.targetSize) && lensPositionMatches(lensID, slot: slot)
    }

    private func snapLensIfClose(id: UUID, targetSlots: [LevelNineLensSlot]) -> Bool {
        guard let slot = targetSlots.first(where: { lensCanSnap(id, to: $0) }) else { return false }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            lensSizes[id] = slot.targetSize
            lensPositions[id] = slot.center
        }
        return true
    }

    private func lensCanSnap(_ lensID: UUID, to slot: LevelNineLensSlot) -> Bool {
        guard let size = lensSizes[lensID], let position = lensPositions[lensID] else { return false }

        let widthTolerance = max(slot.targetSize.width * 0.16, 8)
        let heightTolerance = max(slot.targetSize.height * 0.14, 12)
        let xTolerance = max(slot.targetSize.width * 0.18, 10)
        let yTolerance = max(slot.targetSize.height * 0.14, 12)

        return abs(size.width - slot.targetSize.width) <= widthTolerance
            && abs(size.height - slot.targetSize.height) <= heightTolerance
            && abs(position.x - slot.center.x) <= xTolerance
            && abs(position.y - slot.center.y) <= yTolerance
    }

    private func lensBeamPresenceScore(position: CGPoint, target: CGPoint) -> Double {
        let verticalScore = max(0, 1 - Double(abs(position.y - target.y) / 82))
        let horizontalScore = max(0, 1 - Double(abs(position.x - target.x) / 150))
        return verticalScore * max(horizontalScore, 0.45)
    }

    private func lensSlotPresenceScore(position: CGPoint, target: CGPoint) -> Double {
        max(0, 1 - Double(hypot(position.x - target.x, position.y - target.y) / 86))
    }

    private func lensStartPosition(index: Int, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (index == 0 ? 0.36 : 0.64), y: size.height * 0.76)
    }

    private func checkCompletion(targetSlots: [LevelNineLensSlot]) {
        guard !isFiringBeam, !completed, targetSlots.allSatisfy({ slotSolved($0) }) else { return }

        HapticPlayer.playCompletionTap()
        withAnimation(.easeOut(duration: 0.42)) {
            isFiringBeam = true
        }
        withAnimation(.easeInOut(duration: 1.85)) {
            cageCharge = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.74)) {
                self.ballReleased = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.18) {
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 13)) {
                self.ballInGoal = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.05) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                self.completed = true
            }
        }
    }
}

struct LevelNineLens: Identifiable {
    let id: UUID
    let tint: Color
    let startingSize: CGSize
}

struct LevelNineLensSlot: Identifiable {
    let index: Int
    let center: CGPoint
    let targetSize: CGSize

    var id: Int { index }
}

struct MathItLevelNineView: View {
    var viewModel: MathItLevelNineViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let source = CGPoint(x: size.width * 0.16, y: size.height * 0.43)
            let cageCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.43)
            let ballGoal = CGPoint(x: cageCenter.x, y: (cageCenter.y + size.height) / 2)
            let targetSlots = lensSlots(in: size)
            let focus = viewModel.focusAmount(targetSlots: targetSlots)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    Text("lens focus")
                        .font(.trajan(38))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.36))
                }
                .position(x: size.width / 2, y: 86)

                lightSource(at: source, intensity: focus)

                lightBeam(from: source, to: cageCenter, focus: focus)

                ForEach(targetSlots) { slot in
                    lensOutline(slot: slot, active: viewModel.slotSolved(slot))
                }

                ballGoalOutline(center: ballGoal, active: viewModel.ballReleased || viewModel.ballInGoal)

                cage(center: cageCenter, ballGoal: ballGoal, charge: viewModel.cageCharge, ballReleased: viewModel.ballReleased, ballInGoal: viewModel.ballInGoal, intensity: focus)

                ForEach(viewModel.lenses) { lens in
                    adjustableLens(lens, targetSlots: targetSlots)
                }

                CompletionOverlay(
                    title: "Level 9 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
            }
            .coordinateSpace(name: "levelNineStage")
            .onAppear {
                viewModel.prepareLenses(in: size)
            }
            .onChange(of: size) { _, _ in
                viewModel.prepareLenses(in: size)
            }
        }
    }

    private func lensSlots(in size: CGSize) -> [LevelNineLensSlot] {
        let beamY = size.height * 0.43
        return [
            LevelNineLensSlot(index: 0, center: CGPoint(x: size.width * 0.39, y: beamY), targetSize: CGSize(width: 74, height: 128)),
            LevelNineLensSlot(index: 1, center: CGPoint(x: size.width * 0.61, y: beamY), targetSize: CGSize(width: 48, height: 112))
        ]
    }

    private func lightSource(at point: CGPoint, intensity: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.mathGold.opacity(0.16 + intensity * 0.22))
                .frame(width: 78, height: 78)
                .blur(radius: 4)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color.mathGold.opacity(0.9), Color.mathGold.opacity(0.18)],
                        center: .center,
                        startRadius: 3,
                        endRadius: 30
                    )
                )
                .frame(width: 46, height: 46)
                .shadow(color: Color.mathGold.opacity(0.5 + intensity * 0.35), radius: 16)
        }
        .position(point)
    }

    private func lightBeam(from source: CGPoint, to cageCenter: CGPoint, focus: Double) -> some View {
        let wideWidth = 56 - focus * 48
        let glowWidth = 92 - focus * 70
        let coreWidth = 3 + focus * 3

        return ZStack {
            Path { path in
                path.move(to: source)
                path.addLine(to: cageCenter)
            }
            .stroke(
                Color.mathGold.opacity(0.16 + focus * 0.54),
                style: StrokeStyle(lineWidth: glowWidth, lineCap: .round, lineJoin: .round)
            )
            .blur(radius: 9 - focus * 6)

            Path { path in
                path.move(to: source)
                path.addLine(to: cageCenter)
            }
            .stroke(Color.mathGold.opacity(0.24 + focus * 0.62), style: StrokeStyle(lineWidth: wideWidth, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: source)
                path.addLine(to: cageCenter)
            }
            .stroke(.white.opacity(0.22 + focus * 0.78), style: StrokeStyle(lineWidth: coreWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: .white.opacity(focus * 0.72), radius: 10 + focus * 8)
        }
    }

    private func lensOutline(slot: LevelNineLensSlot, active: Bool) -> some View {
        Ellipse()
            .stroke(
                active ? Color.mathGold.opacity(0.92) : .gray.opacity(0.72),
                style: StrokeStyle(lineWidth: active ? 2.4 : 2, dash: active ? [] : [6, 6])
            )
            .frame(width: slot.targetSize.width, height: slot.targetSize.height)
            .position(slot.center)
            .shadow(color: active ? Color.mathGold.opacity(0.4) : .clear, radius: 12)
    }

    private func ballGoalOutline(center: CGPoint, active: Bool) -> some View {
        Circle()
            .stroke(
                active ? Color.mathGold.opacity(0.92) : .white.opacity(0.58),
                style: StrokeStyle(lineWidth: active ? 2.6 : 2, dash: active ? [] : [5, 5])
            )
            .frame(width: 26, height: 26)
            .position(center)
            .shadow(color: active ? Color.mathGold.opacity(0.4) : .white.opacity(0.12), radius: active ? 14 : 6)
    }

    private func adjustableLens(_ lens: LevelNineLens, targetSlots: [LevelNineLensSlot]) -> some View {
        let lensSize = viewModel.lensSizes[lens.id] ?? lens.startingSize
        let lensPosition = viewModel.lensPositions[lens.id] ?? targetSlots.first?.center ?? .zero
        let solved = viewModel.lensSolved(lens.id, targetSlots: targetSlots)

        return ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            lens.tint.opacity(0.22),
                            .white.opacity(0.74),
                            lens.tint.opacity(0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Ellipse()
                        .stroke(.white.opacity(solved ? 0.9 : 0.62), lineWidth: solved ? 2.1 : 1.4)
                }
                .frame(width: lensSize.width, height: lensSize.height)
                .shadow(color: lens.tint.opacity(solved ? 0.55 : 0.28), radius: solved ? 18 : 10)
                .gesture(
                    DragGesture(coordinateSpace: .named("levelNineStage"))
                        .onChanged { value in
                            viewModel.moveLens(id: lens.id, to: value.location, targetSlots: targetSlots)
                        }
                        .onEnded { _ in
                            viewModel.finishMovingLens(id: lens.id, targetSlots: targetSlots)
                        }
                )

            Circle()
                .fill(solved ? Color.mathGold : .white)
                .frame(width: 18, height: 18)
                .shadow(color: .white.opacity(0.4), radius: 8)
                .offset(x: lensSize.width / 2, y: lensSize.height / 2)
                .gesture(
                    DragGesture(coordinateSpace: .named("levelNineStage"))
                        .onChanged { value in
                            viewModel.resizeLens(id: lens.id, dragLocation: value.location, targetSlots: targetSlots)
                        }
                        .onEnded { _ in
                            viewModel.snapLensIfSolved(id: lens.id, targetSlots: targetSlots)
                        }
                )
        }
        .frame(width: 140, height: 174)
        .position(lensPosition)
        .accessibilityLabel("Resizable light lens")
    }

    private func cage(center: CGPoint, ballGoal: CGPoint, charge: Double, ballReleased: Bool, ballInGoal: Bool, intensity: Double) -> some View {
        let goalOffset = CGSize(width: ballGoal.x - center.x, height: ballGoal.y - center.y)
        let ballOffset = ballInGoal ? goalOffset : CGSize(width: 0, height: ballReleased ? min(goalOffset.height * 0.36, 54) : 0)

        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.gray.opacity(0.08))
                .frame(width: 92, height: 108)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.mathGold.opacity(0.84),
                                    Color.mathGold.opacity(0.36),
                                    .white.opacity(0.18)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: 108 * charge)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            charge >= 1 ? Color.mathGold.opacity(0.95) : .gray.opacity(0.78),
                            lineWidth: 2
                        )
                }

            ForEach(0..<4, id: \.self) { index in
                let x = -30 + CGFloat(index) * 20
                Capsule()
                    .fill(.gray.opacity(0.76))
                    .frame(width: 4, height: 100)
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(Color.mathGold.opacity(0.9))
                            .frame(height: 100 * charge)
                    }
                    .offset(x: x)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill((charge >= 1 ? Color.mathGold : .gray).opacity(0.88))
                    .frame(width: 24, height: 20)

                RoundedRectangle(cornerRadius: 8)
                    .stroke((charge >= 1 ? Color.mathGold : .gray).opacity(0.9), lineWidth: 3)
                    .frame(width: 18, height: 18)
                    .offset(y: -10)
                    .mask {
                        Rectangle()
                            .frame(width: 26, height: 18)
                            .offset(y: -8)
                    }
            }
            .shadow(color: Color.mathGold.opacity(charge * 0.45), radius: 10)
            .offset(y: -4)

            Circle()
                .fill(.white.opacity(0.62 + charge * 0.33))
                .frame(width: 26, height: 26)
                .shadow(color: .white.opacity(0.45 + intensity * 0.35), radius: 14 + charge * 10)
                .scaleEffect(ballInGoal ? 0.92 : (ballReleased ? 1.12 : 1))
                .offset(x: ballOffset.width, y: ballOffset.height)

            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.mathGold.opacity(max(intensity, charge)), lineWidth: 2)
                .frame(width: 112, height: 128)
                .blur(radius: 4 - min(charge * 2, 2))
        }
        .position(center)
    }
}
