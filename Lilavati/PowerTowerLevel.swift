import SwiftUI

@Observable
final class MathItLevelFortySixViewModel {
    var exponent: Int? = 1
    var exponentTilePosition: CGPoint?
    var exponentTileValue = 1
    var exponentTileIsDragging = false

    var ones: [MathItOneSymbol] = [MathItOneSymbol(position: .zero)]
    var numbers: [MathItNumberSymbol] = []
    var plusCreated = false
    var multiplyCreated = false
    var equalsCreated = false
    var plusPosition = CGPoint.zero
    var multiplyPosition = CGPoint.zero
    var equalsPosition = CGPoint.zero
    var activeOneDragOffsets: [UUID: CGSize] = [:]
    var activeNumberDragOffsets: [UUID: CGSize] = [:]
    var activeSymbolDragOffsets: [MathItLevelSevenOperatorSymbol: CGSize] = [:]

    var completed = false
    var towerEscaped = false

    private var activeExponentGrabOffset: CGSize?

    var powerValue: Int {
        guard let exponent else { return 1 }
        guard exponent >= 0 else { return 0 }
        return Int(pow(2.0, Double(exponent)))
    }

    func moveExponent(to location: CGPoint, source: CGPoint) {
        guard !completed else { return }
        if !exponentTileIsDragging {
            exponentTileValue = exponent ?? exponentTileValue
            exponent = nil
            exponentTilePosition = location
            exponentTileIsDragging = true
            activeExponentGrabOffset = .zero
            HapticPlayer.playLightTap()
        }
        let grabOffset = activeExponentGrabOffset ?? CGSize(
            width: (exponentTilePosition ?? source).x - location.x,
            height: (exponentTilePosition ?? source).y - location.y
        )
        activeExponentGrabOffset = grabOffset
        exponentTilePosition = CGPoint(x: location.x + grabOffset.width, y: location.y + grabOffset.height)
    }

    func finishMovingExponent(socket: CGPoint) {
        activeExponentGrabOffset = nil
        guard exponentTileIsDragging, let position = exponentTilePosition else { return }
        if distance(position, socket) < 46 {
            setExponent(exponentTileValue)
            return
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            exponentTilePosition = position
            exponentTileIsDragging = false
        }
    }

    func splitOne(from id: UUID) {
        guard !completed, let source = ones.first(where: { $0.id == id }) else { return }

        HapticPlayer.playLightTap()
        let newID = UUID()
        ones.append(MathItOneSymbol(id: newID, position: source.position))

        withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
            if let index = ones.firstIndex(where: { $0.id == newID }) {
                ones[index].position.x += 76
            }
        }
    }

    func moveOne(id: UUID, to absoluteLocation: CGPoint, source: CGPoint) {
        guard !completed, let index = ones.firstIndex(where: { $0.id == id }) else { return }

        let currentAbsolutePosition = CGPoint(
            x: source.x + ones[index].position.x,
            y: source.y + ones[index].position.y
        )
        let grabOffset = activeOneDragOffsets[id] ?? CGSize(
            width: currentAbsolutePosition.x - absoluteLocation.x,
            height: currentAbsolutePosition.y - absoluteLocation.y
        )
        activeOneDragOffsets[id] = grabOffset

        ones[index].position = CGPoint(
            x: absoluteLocation.x + grabOffset.width - source.x,
            y: absoluteLocation.y + grabOffset.height - source.y
        )
    }

    func finishMovingOne(
        id: UUID,
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) {
        activeOneDragOffsets[id] = nil
        snapExpression(
            dragged: .one(id),
            oneSource: oneSource,
            plusSource: plusSource,
            multiplySource: multiplySource,
            equalsSource: equalsSource,
            bounds: bounds
        )
    }

    func moveNumber(id: UUID, to absoluteLocation: CGPoint) {
        guard !completed, let index = numbers.firstIndex(where: { $0.id == id }) else { return }

        let grabOffset = activeNumberDragOffsets[id] ?? CGSize(
            width: numbers[index].position.x - absoluteLocation.x,
            height: numbers[index].position.y - absoluteLocation.y
        )
        activeNumberDragOffsets[id] = grabOffset

        numbers[index].position = CGPoint(
            x: absoluteLocation.x + grabOffset.width,
            y: absoluteLocation.y + grabOffset.height
        )
    }

    func finishMovingNumber(
        id: UUID,
        exponentBox: CGRect,
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) {
        activeNumberDragOffsets[id] = nil

        guard let index = numbers.firstIndex(where: { $0.id == id }) else { return }
        guard exponentBox.insetBy(dx: -18, dy: -18).contains(numbers[index].position) else {
            snapExpression(
                dragged: .number(id),
                oneSource: oneSource,
                plusSource: plusSource,
                multiplySource: multiplySource,
                equalsSource: equalsSource,
                bounds: bounds
            )
            return
        }

        let value = numbers[index].value
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            numbers[index].position = CGPoint(x: exponentBox.midX, y: exponentBox.midY)
        }
        setExponent(value)
        numbers.removeAll { $0.id == id }
    }

    func moveSymbol(_ symbol: MathItLevelSevenOperatorSymbol, to absoluteLocation: CGPoint, source: CGPoint, bounds: CGSize) {
        guard !completed else { return }

        let currentPosition = position(for: symbol)
        let currentAbsolutePosition = CGPoint(
            x: source.x + currentPosition.x,
            y: source.y + currentPosition.y
        )
        let grabOffset = activeSymbolDragOffsets[symbol] ?? CGSize(
            width: currentAbsolutePosition.x - absoluteLocation.x,
            height: currentAbsolutePosition.y - absoluteLocation.y
        )
        activeSymbolDragOffsets[symbol] = grabOffset

        let nextPosition = clampedPoint(
            CGPoint(
                x: absoluteLocation.x + grabOffset.width,
                y: absoluteLocation.y + grabOffset.height
            ),
            in: bounds
        )
        setPosition(
            CGPoint(
                x: nextPosition.x - source.x,
                y: nextPosition.y - source.y
            ),
            for: symbol
        )
    }

    func finishMovingSymbol(
        _ symbol: MathItLevelSevenOperatorSymbol,
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) {
        activeSymbolDragOffsets[symbol] = nil
        snapExpression(
            dragged: symbol.placedSymbol,
            oneSource: oneSource,
            plusSource: plusSource,
            multiplySource: multiplySource,
            equalsSource: equalsSource,
            bounds: bounds
        )
    }

    func makePlus() {
        guard !completed, !plusCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            plusCreated = true
        }
    }

    func makeMultiply() {
        guard !completed, !multiplyCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            multiplyCreated = true
        }
    }

    func makeEquals() {
        guard !completed, !equalsCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            equalsCreated = true
        }
    }

    private func setExponent(_ value: Int) {
        HapticPlayer.playLightTap()
        exponentTileIsDragging = false
        exponentTilePosition = nil
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            exponent = value
            towerEscaped = powerValue > 16
        }
        if powerValue == 16 {
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                    self.completed = true
                }
            }
        }
    }

    private func snapExpression(
        dragged: MathItLevelSevenPlacedSymbol,
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) {
        let nodes = snapNodes(
            oneSource: oneSource,
            plusSource: plusSource,
            multiplySource: multiplySource,
            equalsSource: equalsSource
        )

        guard let draggedNode = nodes.first(where: { $0.symbol == dragged }) else { return }

        let cluster = expressionCluster(containing: draggedNode, in: nodes)
        guard cluster.count > 1 else { return }

        let sortedCluster = cluster.sorted { $0.position.x < $1.position.x }
        let spacing: CGFloat = adjustedSpacing(count: sortedCluster.count, preferred: 60, bounds: bounds)
        let centerX = sortedCluster.map(\.position.x).reduce(0, +) / CGFloat(sortedCluster.count)
        let centerY = sortedCluster.map(\.position.y).reduce(0, +) / CGFloat(sortedCluster.count)
        let leftX = centerX - CGFloat(sortedCluster.count - 1) * spacing / 2
        let targetPositions = boundedLinePositions(
            count: sortedCluster.count,
            leftX: leftX,
            centerY: centerY,
            spacing: spacing,
            bounds: bounds
        )

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            for (index, node) in sortedCluster.enumerated() {
                setAbsolutePosition(
                    targetPositions[index],
                    for: node.symbol,
                    oneSource: oneSource,
                    plusSource: plusSource,
                    multiplySource: multiplySource,
                    equalsSource: equalsSource
                )
            }
        }

        createOrUpdateResultNumber(
            from: sortedCluster,
            oneSource: oneSource,
            plusSource: plusSource,
            multiplySource: multiplySource,
            equalsSource: equalsSource,
            bounds: bounds
        )
    }

    private func snapNodes(
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint
    ) -> [MathItLevelSevenSnapNode] {
        var nodes = ones.map { one in
            MathItLevelSevenSnapNode(
                symbol: .one(one.id),
                position: CGPoint(x: oneSource.x + one.position.x, y: oneSource.y + one.position.y)
            )
        }

        nodes.append(contentsOf: numbers.map { number in
            MathItLevelSevenSnapNode(symbol: .number(number.id), position: number.position)
        })

        if plusCreated {
            nodes.append(MathItLevelSevenSnapNode(
                symbol: .plus,
                position: CGPoint(x: plusSource.x + plusPosition.x, y: plusSource.y + plusPosition.y)
            ))
        }

        if multiplyCreated {
            nodes.append(MathItLevelSevenSnapNode(
                symbol: .multiply,
                position: CGPoint(x: multiplySource.x + multiplyPosition.x, y: multiplySource.y + multiplyPosition.y)
            ))
        }

        if equalsCreated {
            nodes.append(MathItLevelSevenSnapNode(
                symbol: .equals,
                position: CGPoint(x: equalsSource.x + equalsPosition.x, y: equalsSource.y + equalsPosition.y)
            ))
        }

        return nodes
    }

    private func expressionCluster(
        containing draggedNode: MathItLevelSevenSnapNode,
        in nodes: [MathItLevelSevenSnapNode]
    ) -> [MathItLevelSevenSnapNode] {
        var cluster = [draggedNode]
        var changed = true

        while changed {
            changed = false

            for node in nodes where !cluster.contains(where: { $0.symbol == node.symbol }) {
                if cluster.contains(where: { Self.canSnap($0.position, node.position) }) {
                    cluster.append(node)
                    changed = true
                }
            }
        }

        return cluster
    }

    private static func canSnap(_ first: CGPoint, _ second: CGPoint) -> Bool {
        abs(first.y - second.y) <= 84 && abs(first.x - second.x) <= 112
    }

    private func setAbsolutePosition(
        _ position: CGPoint,
        for symbol: MathItLevelSevenPlacedSymbol,
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint
    ) {
        switch symbol {
        case .one(let id):
            guard let index = ones.firstIndex(where: { $0.id == id }) else { return }
            ones[index].position = CGPoint(x: position.x - oneSource.x, y: position.y - oneSource.y)
        case .number(let id):
            guard let index = numbers.firstIndex(where: { $0.id == id }) else { return }
            numbers[index].position = position
        case .plus:
            plusPosition = CGPoint(x: position.x - plusSource.x, y: position.y - plusSource.y)
        case .multiply:
            multiplyPosition = CGPoint(x: position.x - multiplySource.x, y: position.y - multiplySource.y)
        case .equals:
            equalsPosition = CGPoint(x: position.x - equalsSource.x, y: position.y - equalsSource.y)
        }
    }

    private func createOrUpdateResultNumber(
        from cluster: [MathItLevelSevenSnapNode],
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) {
        guard cluster.contains(where: { $0.symbol == .equals }) else { return }

        let tokens = cluster.map { node in
            MathItLevelSevenToken(kind: tokenKind(for: node.symbol), position: node.position)
        }
        let state = MathItLevelSevenExpressionState(tokens: tokens)
        guard let result = state.result else { return }

        let equalsAbsolutePosition = CGPoint(
            x: equalsSource.x + equalsPosition.x,
            y: equalsSource.y + equalsPosition.y
        )
        let resultPosition = clampedPoint(CGPoint(x: equalsAbsolutePosition.x + 68, y: equalsAbsolutePosition.y), in: bounds)

        if let index = numbers.firstIndex(where: { abs($0.position.x - resultPosition.x) < 86 && abs($0.position.y - resultPosition.y) < 70 }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                numbers[index].value = result
                numbers[index].position = resultPosition
            }
        } else {
            HapticPlayer.playLightTap()
            numbers.append(MathItNumberSymbol(value: result, position: equalsAbsolutePosition))
            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                if let index = numbers.indices.last {
                    numbers[index].position = resultPosition
                }
            }
        }
    }

    private func tokenKind(for symbol: MathItLevelSevenPlacedSymbol) -> MathItLevelSevenTokenKind {
        switch symbol {
        case .one:
            .one
        case .number(let id):
            if let number = numbers.first(where: { $0.id == id }) {
                .number(number.value)
            } else {
                .number(0)
            }
        case .plus:
            .plus
        case .multiply:
            .multiply
        case .equals:
            .equals
        }
    }

    private func position(for symbol: MathItLevelSevenOperatorSymbol) -> CGPoint {
        switch symbol {
        case .plus:
            plusPosition
        case .multiply:
            multiplyPosition
        case .equals:
            equalsPosition
        }
    }

    private func setPosition(_ position: CGPoint, for symbol: MathItLevelSevenOperatorSymbol) {
        switch symbol {
        case .plus:
            plusPosition = position
        case .multiply:
            multiplyPosition = position
        case .equals:
            equalsPosition = position
        }
    }

    private func adjustedSpacing(count: Int, preferred: CGFloat, bounds: CGSize) -> CGFloat {
        guard count > 1 else { return preferred }
        let availableWidth = max(44, bounds.width - 88)
        return min(preferred, max(44, availableWidth / CGFloat(count - 1)))
    }

    private func boundedLinePositions(count: Int, leftX: CGFloat, centerY: CGFloat, spacing: CGFloat, bounds: CGSize) -> [CGPoint] {
        guard count > 0 else { return [] }

        let margin: CGFloat = 44
        let width = CGFloat(count - 1) * spacing
        let minLeft = margin
        let maxLeft = max(minLeft, bounds.width - margin - width)
        let boundedLeftX = min(max(leftX, minLeft), maxLeft)
        let boundedY = min(max(centerY, margin), max(margin, bounds.height - margin))

        return (0..<count).map { index in
            CGPoint(x: boundedLeftX + CGFloat(index) * spacing, y: boundedY)
        }
    }

    private func clampedPoint(_ point: CGPoint, in bounds: CGSize, margin: CGFloat = 44) -> CGPoint {
        CGPoint(
            x: min(max(point.x, margin), max(margin, bounds.width - margin)),
            y: min(max(point.y, margin), max(margin, bounds.height - margin))
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

struct MathItLevelFortySixView: View {
    var viewModel: MathItLevelFortySixViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let orange = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let axisBottom = size.height * 0.56
            let axisTop = max(132, size.height * 0.2)
            let axisHeight = axisBottom - axisTop
            let towerWidth = min(102, size.width * 0.2)
            let towerX = size.width * 0.30
            let axisX = towerX + towerWidth * 0.78
            let expressionCenter = CGPoint(x: size.width * 0.72, y: (axisTop + axisBottom) / 2)
            let exponentBox = CGRect(x: expressionCenter.x + 48, y: expressionCenter.y - 58, width: 58, height: 48)
            let symbolY = size.height * 0.77
            let oneSource = CGPoint(x: size.width * 0.18, y: symbolY)
            let plusSource = CGPoint(x: size.width * 0.46, y: symbolY)
            let multiplySource = CGPoint(x: size.width * 0.64, y: symbolY)
            let equalsSource = CGPoint(x: size.width * 0.82, y: symbolY)

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header
                    .position(x: size.width / 2, y: 86)

                stage(
                    towerX: towerX,
                    towerWidth: towerWidth,
                    axisX: axisX,
                    axisTop: axisTop,
                    axisBottom: axisBottom,
                    axisHeight: axisHeight
                )

                exponentExpression(expressionCenter: expressionCenter, exponentBox: exponentBox)

                builderTray(size: size, symbolY: symbolY)

                ForEach(viewModel.ones) { one in
                    oneSymbol(
                        one,
                        source: oneSource,
                        plusSource: plusSource,
                        multiplySource: multiplySource,
                        equalsSource: equalsSource,
                        bounds: size
                    )
                }

                ForEach(viewModel.numbers) { number in
                    numberSymbol(
                        number,
                        exponentBox: exponentBox,
                        oneSource: oneSource,
                        plusSource: plusSource,
                        multiplySource: multiplySource,
                        equalsSource: equalsSource,
                        bounds: size
                    )
                }

                plusSymbol(source: plusSource, oneSource: oneSource, multiplySource: multiplySource, equalsSource: equalsSource, bounds: size)

                multiplySymbol(source: multiplySource, oneSource: oneSource, plusSource: plusSource, equalsSource: equalsSource, bounds: size)

                equalsSymbol(source: equalsSource, oneSource: oneSource, plusSource: plusSource, multiplySource: multiplySource, bounds: size)

                CompletionOverlay(
                    title: "Level 46 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelFortySixStage")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("46")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.trajan(34))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.34))
        }
    }

    private func stage(towerX: CGFloat, towerWidth: CGFloat, axisX: CGFloat, axisTop: CGFloat, axisBottom: CGFloat, axisHeight: CGFloat) -> some View {
        let ballSize: CGFloat = 28
        let ballRadius = ballSize / 2
        let rawHeight = CGFloat(viewModel.powerValue) / 16 * axisHeight
        let displayHeight = viewModel.powerValue > 16 ? axisHeight * 1.42 : min(axisHeight, rawHeight)
        let towerTop = axisBottom - displayHeight
        let ballY = max(axisTop - ballRadius - (viewModel.powerValue > 16 ? 116 : 0), towerTop - ballRadius)

        return ZStack {
            yAxis(axisX: axisX, axisTop: axisTop, axisBottom: axisBottom)

            Circle()
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .frame(width: ballSize, height: ballSize)
                .position(x: towerX, y: axisTop - ballRadius)

            Rectangle()
                .fill(orange.opacity(0.7))
                .overlay(Rectangle().stroke(Color.mathGold.opacity(0.95), lineWidth: 1.4))
                .frame(width: towerWidth, height: max(2, displayHeight))
                .position(x: towerX, y: axisBottom - displayHeight / 2)
                .shadow(color: viewModel.powerValue == 16 ? orange.opacity(0.72) : orange.opacity(0.24), radius: viewModel.powerValue == 16 ? 18 : 8)
                .animation(.interpolatingSpring(stiffness: viewModel.powerValue > 16 ? 90 : 160, damping: viewModel.powerValue > 16 ? 8 : 20), value: viewModel.powerValue)

            Circle()
                .fill(.white)
                .frame(width: ballSize, height: ballSize)
                .shadow(color: .white.opacity(0.64), radius: 12)
                .position(x: towerX, y: ballY)
                .animation(.interpolatingSpring(stiffness: viewModel.powerValue > 16 ? 85 : 170, damping: viewModel.powerValue > 16 ? 7 : 18), value: viewModel.powerValue)

            Text("\(viewModel.powerValue)")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(viewModel.powerValue > 16 ? .red : .white.opacity(0.76))
                .contentTransition(.numericText())
                .position(x: towerX, y: axisBottom + 28)
        }
    }

    private func yAxis(axisX: CGFloat, axisTop: CGFloat, axisBottom: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: axisX, y: axisTop))
                path.addLine(to: CGPoint(x: axisX, y: axisBottom))
            }
            .stroke(.white.opacity(0.42), lineWidth: 1.4)

            ForEach([0, 4, 8, 12, 16], id: \.self) { mark in
                let y = axisBottom - (axisBottom - axisTop) * CGFloat(mark) / 16
                Path { path in
                    path.move(to: CGPoint(x: axisX - 8, y: y))
                    path.addLine(to: CGPoint(x: axisX + 8, y: y))
                }
                .stroke(mark == 16 ? .white.opacity(0.9) : .white.opacity(0.34), lineWidth: mark == 16 ? 2 : 1)

                Text("\(mark)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(mark == 16 ? .white : .white.opacity(0.42))
                    .position(x: axisX + 28, y: y)
            }
        }
    }

    private func exponentExpression(expressionCenter: CGPoint, exponentBox: CGRect) -> some View {
        ZStack {
            Text("2")
                .font(.trajan(72))
                .foregroundStyle(orange)
                .position(x: expressionCenter.x, y: expressionCenter.y)

            RoundedRectangle(cornerRadius: 8)
                .stroke(orange.opacity(0.42), lineWidth: 1.4)
                .frame(width: exponentBox.width, height: exponentBox.height)
                .position(x: exponentBox.midX, y: exponentBox.midY)

            if viewModel.exponent == nil {
                Text("0")
                    .font(.garamond(exponentFontSize(for: "0")))
                    .foregroundStyle(orange.opacity(0.52))
                    .frame(width: exponentBox.width - 8, height: exponentBox.height - 6)
                    .position(x: exponentBox.midX, y: exponentBox.midY)
            }

            if viewModel.exponent != nil || viewModel.exponentTileIsDragging {
                let source = CGPoint(x: exponentBox.midX, y: exponentBox.midY)
                let position = viewModel.exponentTilePosition ?? source
                let exponentText = "\(viewModel.exponent ?? viewModel.exponentTileValue)"
                Text(exponentText)
                    .font(.garamond(exponentFontSize(for: exponentText)))
                    .foregroundStyle(orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(width: exponentBox.width - 8, height: exponentBox.height - 6)
                    .contentShape(Rectangle())
                    .position(position)
                    .gesture(
                        DragGesture(coordinateSpace: .named("levelFortySixStage"))
                            .onChanged { viewModel.moveExponent(to: $0.location, source: source) }
                            .onEnded { _ in viewModel.finishMovingExponent(socket: source) }
                    )
            }
        }
    }

    private func builderTray(size: CGSize, symbolY: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.035))
            .frame(width: size.width - 24, height: 150)
            .position(x: size.width / 2, y: symbolY)
    }

    private func oneSymbol(
        _ one: MathItOneSymbol,
        source: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) -> some View {
        let point = CGPoint(x: source.x + one.position.x, y: source.y + one.position.y)

        return Text("1")
            .font(.trajan(74))
            .foregroundStyle(.white.opacity(0.82))
            .shadow(color: .white.opacity(0.28), radius: 10)
            .frame(width: 74, height: 92)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onEnded { scale in
                        if scale > 1.14 {
                            viewModel.splitOne(from: one.id)
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(coordinateSpace: .named("levelFortySixStage"))
                    .onChanged { value in
                        viewModel.moveOne(id: one.id, to: value.location, source: source)
                    }
                    .onEnded { _ in
                        viewModel.finishMovingOne(
                            id: one.id,
                            oneSource: source,
                            plusSource: plusSource,
                            multiplySource: multiplySource,
                            equalsSource: equalsSource,
                            bounds: bounds
                        )
                    }
            )
            .position(point)
    }

    private func numberSymbol(
        _ number: MathItNumberSymbol,
        exponentBox: CGRect,
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) -> some View {
        let isInExponentBox = exponentBox.insetBy(dx: -18, dy: -18).contains(number.position)
        let text = String(number.value)

        return Text(String(number.value))
            .font(.garamond(isInExponentBox ? exponentFontSize(for: text) : 74))
            .foregroundStyle(isInExponentBox ? orange : .white.opacity(0.9))
            .shadow(color: .white.opacity(0.34), radius: 12)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: isInExponentBox ? exponentBox.width - 8 : 84, height: isInExponentBox ? exponentBox.height - 6 : 96)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .named("levelFortySixStage"))
                    .onChanged { value in
                        viewModel.moveNumber(id: number.id, to: value.location)
                    }
                    .onEnded { _ in
                        viewModel.finishMovingNumber(
                            id: number.id,
                            exponentBox: exponentBox,
                            oneSource: oneSource,
                            plusSource: plusSource,
                            multiplySource: multiplySource,
                            equalsSource: equalsSource,
                            bounds: bounds
                        )
                    }
            )
            .position(number.position)
    }

    private func exponentFontSize(for text: String) -> CGFloat {
        switch text.count {
        case 0...1:
            34
        case 2:
            28
        case 3:
            22
        default:
            18
        }
    }

    private func plusSymbol(
        source: CGPoint,
        oneSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) -> some View {
        let point = CGPoint(
            x: source.x + viewModel.plusPosition.x,
            y: source.y + viewModel.plusPosition.y
        )

        return Group {
            if viewModel.plusCreated {
                Text("+")
                    .font(.trajan(62))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.34), radius: 10)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.86))
                    .frame(width: 4, height: 72)
                    .shadow(color: .white.opacity(0.24), radius: 8)
            }
        }
        .frame(width: 86, height: 96)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.makePlus()
        }
        .gesture(
            operatorDragGesture(
                .plus,
                source: source,
                oneSource: oneSource,
                plusSource: source,
                multiplySource: multiplySource,
                equalsSource: equalsSource,
                bounds: bounds
            ),
            isEnabled: viewModel.plusCreated
        )
        .position(point)
    }

    private func multiplySymbol(
        source: CGPoint,
        oneSource: CGPoint,
        plusSource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) -> some View {
        let point = CGPoint(
            x: source.x + viewModel.multiplyPosition.x,
            y: source.y + viewModel.multiplyPosition.y
        )

        return Group {
            if viewModel.multiplyCreated {
                Text("×")
                    .font(.trajan(62))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.34), radius: 10)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.86))
                    .frame(width: 4, height: 72)
                    .rotationEffect(.degrees(42))
                    .shadow(color: .white.opacity(0.24), radius: 8)
            }
        }
        .frame(width: 86, height: 96)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.45) {
            viewModel.makeMultiply()
        }
        .gesture(
            operatorDragGesture(
                .multiply,
                source: source,
                oneSource: oneSource,
                plusSource: plusSource,
                multiplySource: source,
                equalsSource: equalsSource,
                bounds: bounds
            ),
            isEnabled: viewModel.multiplyCreated
        )
        .position(point)
    }

    private func equalsSymbol(
        source: CGPoint,
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        bounds: CGSize
    ) -> some View {
        let point = CGPoint(
            x: source.x + viewModel.equalsPosition.x,
            y: source.y + viewModel.equalsPosition.y
        )

        return Group {
            if viewModel.equalsCreated {
                Text("=")
                    .font(.trajan(62))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.34), radius: 10)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.86))
                    .frame(width: 72, height: 4)
                    .shadow(color: .white.opacity(0.24), radius: 8)
            }
        }
        .frame(width: 86, height: 96)
        .contentShape(Rectangle())
        .gesture(
            MagnificationGesture()
                .onEnded { scale in
                    if scale > 1.12 {
                        viewModel.makeEquals()
                    }
                }
        )
        .gesture(
            operatorDragGesture(
                .equals,
                source: source,
                oneSource: oneSource,
                plusSource: plusSource,
                multiplySource: multiplySource,
                equalsSource: source,
                bounds: bounds
            ),
            isEnabled: viewModel.equalsCreated
        )
        .position(point)
    }

    private func operatorDragGesture(
        _ symbol: MathItLevelSevenOperatorSymbol,
        source: CGPoint,
        oneSource: CGPoint,
        plusSource: CGPoint,
        multiplySource: CGPoint,
        equalsSource: CGPoint,
        bounds: CGSize
    ) -> some Gesture {
        DragGesture(coordinateSpace: .named("levelFortySixStage"))
            .onChanged { value in
                viewModel.moveSymbol(symbol, to: value.location, source: source, bounds: bounds)
            }
            .onEnded { _ in
                viewModel.finishMovingSymbol(
                    symbol,
                    oneSource: oneSource,
                    plusSource: plusSource,
                    multiplySource: multiplySource,
                    equalsSource: equalsSource,
                    bounds: bounds
                )
            }
    }
}
