import SwiftUI

@Observable
final class MathItLevelTenViewModel {
    var blockOffset = CGSize.zero
    var multiplyOffset = CGSize.zero
    var twoOffset = CGSize.zero
    var equalsOffset = CGSize.zero
    var plusOffset = CGSize.zero

    var multiplyCreated = false
    var equalsCreated = false
    var plusCreated = false
    var completed = false
    var bridgeBlocks: [LevelTenBridgeBlock] = []
    var placedBridgeSlots: Set<Int> = []
    var sourceBlockPlacedSlot: Int?
    var activeBridgeGrabOffsets: [UUID: CGSize] = [:]
    var ballPosition = CGPoint.zero
    var ballAtGoal = false
    var ballIsMoving = false
    var generatedExpressionSignatures: Set<String> = []

    var activeBlockGrabOffset: CGSize?
    var activeMultiplyGrabOffset: CGSize?
    var activeTwoGrabOffset: CGSize?
    var activeEqualsGrabOffset: CGSize?
    var activePlusGrabOffset: CGSize?

    private let snapSpacing: CGFloat = 62
    private let snapRadius: CGFloat = 54

    func makeMultiply() {
        guard !multiplyCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            multiplyCreated = true
        }
    }

    func makeEquals() {
        guard !equalsCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            equalsCreated = true
        }
    }

    func makePlus() {
        guard !plusCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            plusCreated = true
        }
    }

    func moveBlock(to absoluteLocation: CGPoint, source: CGPoint) {
        guard !completed, sourceBlockPlacedSlot == nil else { return }
        blockOffset = moveOffset(currentOffset: blockOffset, grabOffset: &activeBlockGrabOffset, absoluteLocation: absoluteLocation, source: source)
    }

    func finishMovingBlock(source: CGPoint, sources: LevelTenSymbolSources, bridgeSlots: [CGPoint], ballStart: CGPoint, goalCenter: CGPoint, bounds: CGSize) {
        activeBlockGrabOffset = nil
        if snapSourceBlockToBridge(source: source, bridgeSlots: bridgeSlots, ballStart: ballStart, goalCenter: goalCenter) {
            return
        }
        snapToken(.block, source: source, sources: sources, bounds: bounds) { self.blockOffset = $0 }
    }

    func moveMultiply(to absoluteLocation: CGPoint, source: CGPoint, bounds: CGSize) {
        guard multiplyCreated, !completed else { return }
        multiplyOffset = moveOffset(currentOffset: multiplyOffset, grabOffset: &activeMultiplyGrabOffset, absoluteLocation: absoluteLocation, source: source, bounds: bounds)
    }

    func finishMovingMultiply(source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) {
        activeMultiplyGrabOffset = nil
        guard multiplyCreated else { return }
        snapToken(.multiply, source: source, sources: sources, bounds: bounds) { self.multiplyOffset = $0 }
    }

    func moveTwo(to absoluteLocation: CGPoint, source: CGPoint) {
        guard !completed else { return }
        twoOffset = moveOffset(currentOffset: twoOffset, grabOffset: &activeTwoGrabOffset, absoluteLocation: absoluteLocation, source: source)
    }

    func finishMovingTwo(source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) {
        activeTwoGrabOffset = nil
        snapToken(.two, source: source, sources: sources, bounds: bounds) { self.twoOffset = $0 }
    }

    func moveEquals(to absoluteLocation: CGPoint, source: CGPoint, bounds: CGSize) {
        guard equalsCreated, !completed else { return }
        equalsOffset = moveOffset(currentOffset: equalsOffset, grabOffset: &activeEqualsGrabOffset, absoluteLocation: absoluteLocation, source: source, bounds: bounds)
    }

    func finishMovingEquals(source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) {
        activeEqualsGrabOffset = nil
        guard equalsCreated else { return }
        snapToken(.equals, source: source, sources: sources, bounds: bounds) { self.equalsOffset = $0 }
    }

    func movePlus(to absoluteLocation: CGPoint, source: CGPoint, bounds: CGSize) {
        guard plusCreated, !completed else { return }
        plusOffset = moveOffset(currentOffset: plusOffset, grabOffset: &activePlusGrabOffset, absoluteLocation: absoluteLocation, source: source, bounds: bounds)
    }

    func finishMovingPlus(source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) {
        activePlusGrabOffset = nil
        guard plusCreated else { return }
        snapToken(.plus, source: source, sources: sources, bounds: bounds) { self.plusOffset = $0 }
    }

    func moveBridgeBlock(id: UUID, to absoluteLocation: CGPoint) {
        guard let index = bridgeBlocks.firstIndex(where: { $0.id == id }), bridgeBlocks[index].placedSlot == nil, !completed else { return }
        let current = bridgeBlocks[index].position
        let grabOffset = activeBridgeGrabOffsets[id] ?? CGSize(width: current.x - absoluteLocation.x, height: current.y - absoluteLocation.y)
        activeBridgeGrabOffsets[id] = grabOffset
        bridgeBlocks[index].position = CGPoint(x: absoluteLocation.x + grabOffset.width, y: absoluteLocation.y + grabOffset.height)
    }

    private func snapSourceBlockToBridge(source: CGPoint, bridgeSlots: [CGPoint], ballStart: CGPoint, goalCenter: CGPoint) -> Bool {
        guard sourceBlockPlacedSlot == nil, !completed else { return false }
        let current = CGPoint(x: source.x + blockOffset.width, y: source.y + blockOffset.height)
        let availableSlots = bridgeSlots.enumerated().filter { !placedBridgeSlots.contains($0.offset) }
        guard let nearest = availableSlots.min(by: {
            hypot(current.x - $0.element.x, current.y - $0.element.y) < hypot(current.x - $1.element.x, current.y - $1.element.y)
        }), hypot(current.x - nearest.element.x, current.y - nearest.element.y) < 46 else { return false }

        HapticPlayer.playLightTap()
        placedBridgeSlots.insert(nearest.offset)
        sourceBlockPlacedSlot = nearest.offset
        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            blockOffset = CGSize(width: nearest.element.x - source.x, height: nearest.element.y - source.y)
        }

        if placedBridgeSlots.count == bridgeSlots.count {
            animateBallAcrossBridge(from: ballStart, through: bridgeSlots, to: goalCenter)
        }
        return true
    }

    func finishMovingBridgeBlock(id: UUID, bridgeSlots: [CGPoint], ballStart: CGPoint, goalCenter: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) {
        activeBridgeGrabOffsets[id] = nil
        guard let index = bridgeBlocks.firstIndex(where: { $0.id == id }), bridgeBlocks[index].placedSlot == nil, !completed else { return }
        let block = bridgeBlocks[index]
        let availableSlots = bridgeSlots.enumerated().filter { !placedBridgeSlots.contains($0.offset) }
        if let nearest = availableSlots.min(by: {
            hypot(block.position.x - $0.element.x, block.position.y - $0.element.y) < hypot(block.position.x - $1.element.x, block.position.y - $1.element.y)
        }), hypot(block.position.x - nearest.element.x, block.position.y - nearest.element.y) < 46 {
            HapticPlayer.playLightTap()
            placedBridgeSlots.insert(nearest.offset)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                bridgeBlocks[index].position = nearest.element
                bridgeBlocks[index].placedSlot = nearest.offset
            }

            if placedBridgeSlots.count == bridgeSlots.count {
                animateBallAcrossBridge(from: ballStart, through: bridgeSlots, to: goalCenter)
            }
            return
        }

        snapBridgeBlockToExpression(id: id, sources: sources, bounds: bounds)
    }

    func ballDisplayPosition(defaultStart: CGPoint) -> CGPoint {
        if ballPosition == .zero {
            return defaultStart
        }
        return ballPosition
    }

    private func moveOffset(currentOffset: CGSize, grabOffset: inout CGSize?, absoluteLocation: CGPoint, source: CGPoint, bounds: CGSize? = nil) -> CGSize {
        let current = CGPoint(x: source.x + currentOffset.width, y: source.y + currentOffset.height)
        let nextGrabOffset = grabOffset ?? CGSize(width: current.x - absoluteLocation.x, height: current.y - absoluteLocation.y)
        grabOffset = nextGrabOffset
        let nextPoint = CGPoint(x: absoluteLocation.x + nextGrabOffset.width, y: absoluteLocation.y + nextGrabOffset.height)
        let boundedPoint = bounds.map { clampedPoint(nextPoint, in: $0) } ?? nextPoint
        return CGSize(width: boundedPoint.x - source.x, height: boundedPoint.y - source.y)
    }

    private func snapToken(_ kind: LevelTenTokenKind, source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize, assign: (CGSize) -> Void) {
        guard let current = tokenPoint(kind, sources: sources) else { return }
        let movingKey = sourceKey(for: kind)
        let otherTokens = activeTokens(sources: sources).filter { $0.key != movingKey }
        let candidates = otherTokens.flatMap { token in
            [
                clampedPoint(CGPoint(x: token.position.x - snapSpacing, y: token.position.y), in: bounds),
                clampedPoint(CGPoint(x: token.position.x + snapSpacing, y: token.position.y), in: bounds)
            ]
        }
        let filteredCandidates = candidates.filter { candidate in
            !otherTokens.contains { hypot($0.position.x - candidate.x, $0.position.y - candidate.y) < snapSpacing * 0.55 }
        }

        guard let nearest = filteredCandidates.min(by: {
            hypot(current.x - $0.x, current.y - $0.y) < hypot(current.x - $1.x, current.y - $1.y)
        }) else {
            tryGenerateBridgeBlocks(sources: sources, bounds: bounds)
            return
        }
        guard hypot(current.x - nearest.x, current.y - nearest.y) < snapRadius else {
            tryGenerateBridgeBlocks(sources: sources, bounds: bounds)
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            assign(CGSize(width: nearest.x - source.x, height: nearest.y - source.y))
        }
        checkForBridgeBlocksAfterSnap(sources: sources, bounds: bounds)
    }

    private func snapBridgeBlockToExpression(id: UUID, sources: LevelTenSymbolSources, bounds: CGSize) {
        guard let index = bridgeBlocks.firstIndex(where: { $0.id == id }), bridgeBlocks[index].placedSlot == nil else { return }
        let current = bridgeBlocks[index].position
        let otherTokens = activeTokens(sources: sources).filter { $0.key != id.uuidString }
        let candidates = otherTokens.flatMap { token in
            [
                clampedPoint(CGPoint(x: token.position.x - snapSpacing, y: token.position.y), in: bounds),
                clampedPoint(CGPoint(x: token.position.x + snapSpacing, y: token.position.y), in: bounds)
            ]
        }
        let filteredCandidates = candidates.filter { candidate in
            !otherTokens.contains { hypot($0.position.x - candidate.x, $0.position.y - candidate.y) < snapSpacing * 0.55 }
        }
        guard let nearest = filteredCandidates.min(by: {
            hypot(current.x - $0.x, current.y - $0.y) < hypot(current.x - $1.x, current.y - $1.y)
        }), hypot(current.x - nearest.x, current.y - nearest.y) < snapRadius else {
            tryGenerateBridgeBlocks(sources: sources, bounds: bounds)
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            bridgeBlocks[index].position = nearest
        }
        checkForBridgeBlocksAfterSnap(sources: sources, bounds: bounds)
    }

    private func checkForBridgeBlocksAfterSnap(sources: LevelTenSymbolSources, bounds: CGSize) {
        tryGenerateBridgeBlocks(sources: sources, bounds: bounds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.tryGenerateBridgeBlocks(sources: sources, bounds: bounds)
        }
    }

    private func tryGenerateBridgeBlocks(sources: LevelTenSymbolSources, bounds: CGSize) {
        guard let expression = solvedExpressions(sources: sources).first(where: { !generatedExpressionSignatures.contains($0.signature) }) else { return }

        HapticPlayer.playCompletionTap()
        let spacing: CGFloat = 46
        let totalWidth = CGFloat(max(expression.result - 1, 0)) * spacing
        let maxStartX = max(34, bounds.width - totalWidth - 30)
        let start = CGPoint(x: min(expression.equalsPoint.x + 82, maxStartX), y: expression.equalsPoint.y)
        let newBlocks = (0..<expression.result).map { index in
            LevelTenBridgeBlock(position: CGPoint(x: start.x + CGFloat(index) * spacing, y: start.y))
        }
        bridgeBlocks.append(contentsOf: newBlocks)
        generatedExpressionSignatures.insert(expression.signature)
    }

    private func animateBallAcrossBridge(from start: CGPoint, through bridgeSlots: [CGPoint], to goalCenter: CGPoint) {
        guard !ballIsMoving, !completed else { return }
        ballPosition = start
        ballIsMoving = true
        HapticPlayer.playCompletionTap()

        let bouncePoints = bridgeSlots.sorted { $0.x < $1.x }.map { CGPoint(x: $0.x, y: $0.y - 34) } + [goalCenter]
        for (index, point) in bouncePoints.enumerated() {
            let delay = Double(index) * 0.24
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.interpolatingSpring(stiffness: 210, damping: 15)) {
                    self.ballPosition = CGPoint(x: point.x, y: point.y - 18)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.12) {
                withAnimation(.interpolatingSpring(stiffness: 230, damping: 18)) {
                    self.ballPosition = point
                }
            }
        }

        let finishDelay = Double(bouncePoints.count) * 0.24 + 0.16
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            self.ballAtGoal = true
            self.ballIsMoving = false
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    private func isSolved(sources: LevelTenSymbolSources) -> Bool {
        !solvedExpressions(sources: sources).isEmpty
    }

    private func solvedExpressions(sources: LevelTenSymbolSources) -> [LevelTenExpression] {
        guard equalsCreated else { return [] }
        let requiredKinds: Set<LevelTenTokenKind> = [.block, .multiply, .two, .equals]
        let tokens = activeTokens(sources: sources)
            .filter { requiredKinds.contains($0.kind) }
            .sorted { $0.position.x < $1.position.x }
        guard tokens.count >= 4 else { return [] }

        var expressions: [LevelTenExpression] = []
        for equalsIndex in tokens.indices where tokens[equalsIndex].kind == .equals {
            guard equalsIndex >= 3 else { continue }
            for startIndex in 0...(equalsIndex - 3) {
                let row = Array(tokens[startIndex...equalsIndex])
                let candidates = Array(row.dropLast())
                let yValues = row.map(\.position.y)
                let gaps = zip(row, row.dropFirst()).map { $1.position.x - $0.position.x }
                let isHorizontal = (yValues.max() ?? 0) - (yValues.min() ?? 0) < 42
                let isSnapped = gaps.allSatisfy { $0 > 40 && $0 < 92 }
                guard isHorizontal && isSnapped else { continue }

                let operatorIndices = candidates.indices.filter { candidates[$0].kind == .multiply }
                guard operatorIndices.count == 1, let operatorIndex = operatorIndices.first else { continue }
                let leftTokens = Array(candidates[..<operatorIndex])
                let rightTokens = Array(candidates[(operatorIndex + 1)...])
                guard let leftValue = operandValue(leftTokens), let rightValue = operandValue(rightTokens) else { continue }

                let result: Int
                switch candidates[operatorIndex].kind {
                case .multiply:
                    result = leftValue * rightValue
                default:
                    continue
                }
                guard result > 0 && result <= 24 else { continue }
                let signature = row.map { token in
                    let x = Int(token.position.x.rounded())
                    let y = Int(token.position.y.rounded())
                    return "\(token.key)@\(x),\(y)"
                }.joined(separator: "|") + "=\(result)"
                expressions.append(LevelTenExpression(result: result, equalsPoint: tokens[equalsIndex].position, signature: signature))
            }
        }
        return expressions
    }

    private func operandValue(_ tokens: [LevelTenToken]) -> Int? {
        guard !tokens.isEmpty else { return nil }
        if tokens.count == 1, tokens[0].kind == .two {
            return 2
        }
        if tokens.allSatisfy({ $0.kind == .block }) {
            return tokens.count
        }
        return nil
    }

    private func sourceKey(for kind: LevelTenTokenKind) -> String {
        switch kind {
        case .block:
            "source-block"
        case .multiply:
            "source-multiply"
        case .two:
            "source-two"
        case .equals:
            "source-equals"
        case .plus:
            "source-plus"
        }
    }

    private func activeTokens(sources: LevelTenSymbolSources) -> [LevelTenToken] {
        var tokens: [LevelTenToken] = [
            LevelTenToken(kind: .two, position: CGPoint(x: sources.two.x + twoOffset.width, y: sources.two.y + twoOffset.height), key: "source-two")
        ]
        if sourceBlockPlacedSlot == nil {
            tokens.append(LevelTenToken(kind: .block, position: CGPoint(x: sources.block.x + blockOffset.width, y: sources.block.y + blockOffset.height), key: "source-block"))
        }
        for block in bridgeBlocks where block.placedSlot == nil {
            tokens.append(LevelTenToken(kind: .block, position: block.position, key: block.id.uuidString))
        }
        if multiplyCreated {
            tokens.append(LevelTenToken(kind: .multiply, position: CGPoint(x: sources.multiply.x + multiplyOffset.width, y: sources.multiply.y + multiplyOffset.height), key: "source-multiply"))
        }
        if equalsCreated {
            tokens.append(LevelTenToken(kind: .equals, position: CGPoint(x: sources.equals.x + equalsOffset.width, y: sources.equals.y + equalsOffset.height), key: "source-equals"))
        }
        return tokens
    }

    private func tokenPoint(_ kind: LevelTenTokenKind, sources: LevelTenSymbolSources) -> CGPoint? {
        switch kind {
        case .block:
            CGPoint(x: sources.block.x + blockOffset.width, y: sources.block.y + blockOffset.height)
        case .multiply:
            multiplyCreated ? CGPoint(x: sources.multiply.x + multiplyOffset.width, y: sources.multiply.y + multiplyOffset.height) : nil
        case .two:
            CGPoint(x: sources.two.x + twoOffset.width, y: sources.two.y + twoOffset.height)
        case .equals:
            equalsCreated ? CGPoint(x: sources.equals.x + equalsOffset.width, y: sources.equals.y + equalsOffset.height) : nil
        case .plus:
            plusCreated ? CGPoint(x: sources.plus.x + plusOffset.width, y: sources.plus.y + plusOffset.height) : nil
        }
    }

    private func clampedPoint(_ point: CGPoint, in bounds: CGSize, margin: CGFloat = 34) -> CGPoint {
        CGPoint(
            x: min(max(point.x, margin), max(margin, bounds.width - margin)),
            y: min(max(point.y, margin), max(margin, bounds.height - margin))
        )
    }
}

struct LevelTenSymbolSources {
    let block: CGPoint
    let multiply: CGPoint
    let plus: CGPoint
    let two: CGPoint
    let equals: CGPoint
}

struct LevelTenBridgeBlock: Identifiable {
    let id = UUID()
    var position: CGPoint
    var placedSlot: Int?
}

private struct LevelTenToken {
    let kind: LevelTenTokenKind
    let position: CGPoint
    let key: String
}

private struct LevelTenExpression {
    let result: Int
    let equalsPoint: CGPoint
    let signature: String
}

private enum LevelTenTokenKind: Equatable, Hashable {
    case block
    case multiply
    case two
    case equals
    case plus
}

struct MathItLevelTenView: View {
    var viewModel: MathItLevelTenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let platformY = size.height * 0.36
            let bridgeY = platformY + 10
            let ballStart = CGPoint(x: size.width * 0.13, y: platformY - 32)
            let goalCenter = CGPoint(x: size.width * 0.87, y: platformY - 32)
            let bridgeSlotCount = 3
            let bridgeStartX = size.width * 0.32
            let bridgeEndX = size.width * 0.68
            let bridgeSlots = (0..<bridgeSlotCount).map { index in
                let progress = CGFloat(index) / CGFloat(bridgeSlotCount - 1)
                return CGPoint(x: bridgeStartX + (bridgeEndX - bridgeStartX) * progress, y: bridgeY)
            }
            let sourceY = size.height * 0.78
            let sources = LevelTenSymbolSources(
                block: CGPoint(x: size.width * 0.16, y: sourceY),
                multiply: CGPoint(x: size.width * 0.38, y: sourceY),
                plus: CGPoint(x: size.width * 0.5, y: sourceY),
                two: CGPoint(x: size.width * 0.62, y: sourceY),
                equals: CGPoint(x: size.width * 0.84, y: sourceY)
            )
            let blockPoint = CGPoint(x: sources.block.x + viewModel.blockOffset.width, y: sources.block.y + viewModel.blockOffset.height)
            let multiplyPoint = CGPoint(x: sources.multiply.x + viewModel.multiplyOffset.width, y: sources.multiply.y + viewModel.multiplyOffset.height)
            let twoPoint = CGPoint(x: sources.two.x + viewModel.twoOffset.width, y: sources.two.y + viewModel.twoOffset.height)
            let equalsPoint = CGPoint(x: sources.equals.x + viewModel.equalsOffset.width, y: sources.equals.y + viewModel.equalsOffset.height)
            let ballPoint = viewModel.ballDisplayPosition(defaultStart: ballStart)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    Text("LEVEL \(MathItCurriculum.levelNumber(forScreenLevel: 10) ?? 10)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.58))

                    Text("block it out")
                        .font(.system(size: 36, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.32))
                }
                .position(x: size.width / 2, y: 86)

                bridgeStage(bridgeY: bridgeY, ballPoint: ballPoint, ballStart: ballStart, goalCenter: goalCenter)

                draggableBlock(at: blockPoint, source: sources.block, sources: sources, bridgeSlots: bridgeSlots, ballStart: ballStart, goalCenter: goalCenter, bounds: size)
                draggableMultiply(at: multiplyPoint, source: sources.multiply, sources: sources, bounds: size)
                draggableTwo(at: twoPoint, source: sources.two, sources: sources, bounds: size)
                draggableEquals(at: equalsPoint, source: sources.equals, sources: sources, bounds: size)

                ForEach(viewModel.bridgeBlocks) { block in
                    bridgeBlock(block, bridgeSlots: bridgeSlots, ballStart: ballStart, goalCenter: goalCenter, sources: sources, bounds: size)
                }

                CompletionOverlay(
                    title: "Level 10 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
            }
            .coordinateSpace(name: "levelTenStage")
        }
    }

    private func bridgeStage(bridgeY: CGFloat, ballPoint: CGPoint, ballStart: CGPoint, goalCenter: CGPoint) -> some View {
        ZStack {
            Capsule()
                .fill(.white.opacity(0.66))
                .frame(width: 78, height: 8)
                .position(x: ballStart.x, y: bridgeY + 21)

            Capsule()
                .fill(.white.opacity(0.66))
                .frame(width: 78, height: 8)
                .position(x: goalCenter.x, y: bridgeY + 21)

            Circle()
                .stroke(.gray.opacity(0.86), lineWidth: 2)
                .frame(width: 26, height: 26)
                .position(goalCenter)

            Circle()
                .fill(.white)
                .frame(width: 26, height: 26)
                .shadow(color: .white.opacity(0.62), radius: 12)
                .position(ballPoint)
        }
    }

    private func bridgeBlock(_ block: LevelTenBridgeBlock, bridgeSlots: [CGPoint], ballStart: CGPoint, goalCenter: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) -> some View {
        BlockUnitView()
            .frame(width: 40, height: 40)
            .position(block.position)
            .shadow(color: .white.opacity(block.placedSlot == nil ? 0.18 : 0.36), radius: block.placedSlot == nil ? 7 : 12)
            .gesture(
                DragGesture(coordinateSpace: .named("levelTenStage"))
                    .onChanged { value in
                        viewModel.moveBridgeBlock(id: block.id, to: value.location)
                    }
                    .onEnded { _ in
                        viewModel.finishMovingBridgeBlock(id: block.id, bridgeSlots: bridgeSlots, ballStart: ballStart, goalCenter: goalCenter, sources: sources, bounds: bounds)
                    }
            )
            .accessibilityLabel("Bridge block")
    }

    private func draggableBlock(at point: CGPoint, source: CGPoint, sources: LevelTenSymbolSources, bridgeSlots: [CGPoint], ballStart: CGPoint, goalCenter: CGPoint, bounds: CGSize) -> some View {
        BlockUnitView()
            .frame(width: viewModel.sourceBlockPlacedSlot == nil ? 46 : 40, height: viewModel.sourceBlockPlacedSlot == nil ? 46 : 40)
            .position(point)
            .shadow(color: .white.opacity(viewModel.sourceBlockPlacedSlot == nil ? 0.22 : 0.36), radius: viewModel.sourceBlockPlacedSlot == nil ? 9 : 12)
            .gesture(
                DragGesture(coordinateSpace: .named("levelTenStage"))
                    .onChanged { viewModel.moveBlock(to: $0.location, source: source) }
                    .onEnded { _ in
                        viewModel.finishMovingBlock(source: source, sources: sources, bridgeSlots: bridgeSlots, ballStart: ballStart, goalCenter: goalCenter, bounds: bounds)
                    }
            )
            .accessibilityLabel("One block")
    }

    private func draggableMultiply(at point: CGPoint, source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) -> some View {
        Group {
            if viewModel.multiplyCreated {
                Text("×").font(.system(size: 46, weight: .light, design: .serif)).foregroundStyle(.white.opacity(0.78)).shadow(color: .white.opacity(0.26), radius: 10)
            } else {
                SlantedLineSymbolView().stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 42, height: 42).shadow(color: .white.opacity(0.18), radius: 8)
            }
        }
        .frame(width: 58, height: 58)
        .contentShape(Rectangle())
        .position(point)
        .onLongPressGesture(minimumDuration: 0.45) { viewModel.makeMultiply() }
        .gesture(DragGesture(coordinateSpace: .named("levelTenStage")).onChanged { viewModel.moveMultiply(to: $0.location, source: source, bounds: bounds) }.onEnded { _ in viewModel.finishMovingMultiply(source: source, sources: sources, bounds: bounds) })
        .accessibilityLabel("Multiplication symbol")
    }

    private func draggablePlus(at point: CGPoint, source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) -> some View {
        Group {
            if viewModel.plusCreated {
                Text("+").font(.system(size: 46, weight: .light, design: .serif)).foregroundStyle(.white.opacity(0.78)).shadow(color: .white.opacity(0.26), radius: 10)
            } else {
                VerticalLineSymbolView().stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 42, height: 42).shadow(color: .white.opacity(0.18), radius: 8)
            }
        }
        .frame(width: 58, height: 58)
        .contentShape(Rectangle())
        .position(point)
        .onTapGesture { viewModel.makePlus() }
        .gesture(DragGesture(coordinateSpace: .named("levelTenStage")).onChanged { viewModel.movePlus(to: $0.location, source: source, bounds: bounds) }.onEnded { _ in viewModel.finishMovingPlus(source: source, sources: sources, bounds: bounds) })
        .accessibilityLabel("Plus symbol")
    }

    private func draggableTwo(at point: CGPoint, source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) -> some View {
        Text("2")
            .font(.system(size: 50, weight: .medium, design: .serif))
            .foregroundStyle(.white.opacity(0.8))
            .shadow(color: .white.opacity(0.24), radius: 10)
            .frame(width: 58, height: 58)
            .contentShape(Rectangle())
            .position(point)
            .gesture(DragGesture(coordinateSpace: .named("levelTenStage")).onChanged { viewModel.moveTwo(to: $0.location, source: source) }.onEnded { _ in viewModel.finishMovingTwo(source: source, sources: sources, bounds: bounds) })
            .accessibilityLabel("Number two")
    }

    private func draggableEquals(at point: CGPoint, source: CGPoint, sources: LevelTenSymbolSources, bounds: CGSize) -> some View {
        Group {
            if viewModel.equalsCreated {
                Text("=").font(.system(size: 46, weight: .light, design: .serif)).foregroundStyle(.white.opacity(0.78)).shadow(color: .white.opacity(0.26), radius: 10)
            } else {
                HorizontalLineSymbolView().stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 44, height: 42).shadow(color: .white.opacity(0.18), radius: 8)
            }
        }
        .frame(width: 58, height: 58)
        .contentShape(Rectangle())
        .position(point)
        .gesture(MagnifyGesture(minimumScaleDelta: 0.12).onEnded { if $0.magnification > 1.18 { viewModel.makeEquals() } })
        .simultaneousGesture(DragGesture(coordinateSpace: .named("levelTenStage")).onChanged { viewModel.moveEquals(to: $0.location, source: source, bounds: bounds) }.onEnded { _ in viewModel.finishMovingEquals(source: source, sources: sources, bounds: bounds) })
        .accessibilityLabel("Equals symbol")
    }
}

private struct BlockUnitView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.white.opacity(0.82))
            .overlay { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.94), lineWidth: 1.6) }
    }
}

private struct SlantedLineSymbolView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.2))
        return path
    }
}

private struct VerticalLineSymbolView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.14))
        return path
    }
}

private struct HorizontalLineSymbolView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY))
        return path
    }
}
