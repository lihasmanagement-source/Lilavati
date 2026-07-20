import SwiftUI

struct LevelFortyEightStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
}

enum LevelFortyEightSymbol: Hashable {
    case polygon(Int)
    case dots(Int)
    case combo(edges: Int, dots: Int)
}

struct LevelFortyEightStage {
    let sequence: [LevelFortyEightSymbol]
    let answer: LevelFortyEightSymbol
}

@Observable
final class MathItLevelFortyEightViewModel {
    let stages = [
        LevelFortyEightStage(
            sequence: [.polygon(3), .polygon(4), .polygon(5)],
            answer: .polygon(6)
        ),
        LevelFortyEightStage(
            sequence: [.dots(1), .dots(3), .dots(6)],
            answer: .dots(10)
        ),
        LevelFortyEightStage(
            sequence: [.combo(edges: 3, dots: 5), .combo(edges: 5, dots: 7), .combo(edges: 4, dots: 6)],
            answer: .combo(edges: 6, dots: 8)
        )
    ]

    var stage = 0
    var strokes: [LevelFortyEightStroke] = []
    var activeStroke: [CGPoint] = []
    var formalized = false
    var wrongPulse = false
    var completed = false

    var currentStage: LevelFortyEightStage {
        stages[min(stage, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        let stageProgress = Double(stage) / Double(stages.count)
        let localProgress: Double
        if formalized {
            localProgress = 1
        } else {
            localProgress = strokes.isEmpty && activeStroke.isEmpty ? 0.2 : 0.48
        }
        return stageProgress + localProgress / Double(stages.count)
    }

    func beginDrawing(at point: CGPoint) {
        guard !formalized, !completed else { return }
        activeStroke = [point]
    }

    func continueDrawing(to point: CGPoint) {
        guard !formalized, !completed else { return }
        guard let last = activeStroke.last else {
            activeStroke = [point]
            return
        }
        if distance(last, point) > 2.5 {
            activeStroke.append(point)
        }
    }

    func finishDrawing(in rect: CGRect) {
        guard !formalized, !completed else { return }
        if !activeStroke.isEmpty {
            strokes.append(LevelFortyEightStroke(points: activeStroke))
        }
        activeStroke.removeAll()
        validate(in: rect)
    }

    func clearDrawing() {
        guard !formalized, !completed else { return }
        strokes.removeAll()
        activeStroke.removeAll()
        wrongPulse = false
        HapticPlayer.playLightTap()
    }

    private func validate(in rect: CGRect) {
        switch currentStage.answer {
        case .polygon(let edges):
            validatePolygon(edges: edges, in: rect)
        case .dots(let count):
            validateDots(count: count)
        case .combo(let edges, let dots):
            validateCombo(edges: edges, dots: dots, in: rect)
        }
    }

    private func validatePolygon(edges: Int, in rect: CGRect) {
        let points = strokes.flatMap(\.points)
        guard points.count > 12 else { return }
        let bounds = boundingRect(for: points)
        guard bounds.width > rect.width * 0.28, bounds.height > rect.height * 0.28 else {
            markWrong()
            return
        }

        let closedEnough = distance(points.first ?? .zero, points.last ?? .zero) < max(bounds.width, bounds.height) * 0.36
        let corners = cornerEstimate(for: points)

        if closedEnough && acceptedCornerRange(for: edges).contains(corners) {
            acceptDrawing()
        } else {
            markWrong()
        }
    }

    private func validateDots(count: Int) {
        let dots = dotCount
        if dots == count {
            acceptDrawing()
        } else if dots > count {
            markWrong()
        }
    }

    private func validateCombo(edges: Int, dots: Int, in rect: CGRect) {
        let largePoints = strokes
            .filter { !isDotLike($0) }
            .flatMap(\.points)
        let drawnDots = dotCount

        guard largePoints.count > 12 else {
            if drawnDots > dots + 1 {
                markWrong()
            }
            return
        }

        let bounds = boundingRect(for: largePoints)
        guard bounds.width > rect.width * 0.24, bounds.height > rect.height * 0.24 else { return }
        let closedEnough = distance(largePoints.first ?? .zero, largePoints.last ?? .zero) < max(bounds.width, bounds.height) * 0.4
        let corners = cornerEstimate(for: largePoints)

        if closedEnough && acceptedCornerRange(for: edges).contains(corners) && drawnDots == dots {
            acceptDrawing()
        } else if drawnDots > dots {
            markWrong()
        }
    }

    private func acceptedCornerRange(for answer: Int) -> ClosedRange<Int> {
        if answer <= 6 {
            return (answer - 1)...(answer + 1)
        }
        return (answer - 2)...(answer + 2)
    }

    var dotCount: Int {
        strokes.filter(isDotLike).count
    }

    private func isDotLike(_ stroke: LevelFortyEightStroke) -> Bool {
        guard !stroke.points.isEmpty else { return false }
        guard stroke.points.count > 1 else { return true }
        let bounds = boundingRect(for: stroke.points)
        return max(bounds.width, bounds.height) < 28 && pathLength(stroke.points) < 70
    }

    private func acceptDrawing() {
        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            formalized = true
            wrongPulse = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            if self.stage == self.stages.count - 1 {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                    self.completed = true
                }
                return
            }

            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                self.stage += 1
                self.strokes.removeAll()
                self.activeStroke.removeAll()
                self.formalized = false
                self.wrongPulse = false
            }
        }
    }

    private func markWrong() {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.46)) {
            wrongPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                self.wrongPulse = false
            }
        }
    }

    private func boundingRect(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func cornerEstimate(for points: [CGPoint]) -> Int {
        let bounds = boundingRect(for: points)
        let epsilon = max(bounds.width, bounds.height) * 0.07
        var simplified = simplify(points, epsilon: epsilon)
        if simplified.count > 2, distance(simplified.first ?? .zero, simplified.last ?? .zero) < max(bounds.width, bounds.height) * 0.24 {
            simplified.removeLast()
        }
        return simplified.count
    }

    private func simplify(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var maxDistance: CGFloat = 0
        var maxIndex = 0
        let start = points[0]
        let end = points[points.count - 1]

        for index in 1..<(points.count - 1) {
            let distance = perpendicularDistance(points[index], lineStart: start, lineEnd: end)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = index
            }
        }

        guard maxDistance > epsilon else {
            return [start, end]
        }

        let left = simplify(Array(points[0...maxIndex]), epsilon: epsilon)
        let right = simplify(Array(points[maxIndex...(points.count - 1)]), epsilon: epsilon)
        return Array(left.dropLast()) + right
    }

    private func perpendicularDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let denominator = max(0.001, sqrt(dx * dx + dy * dy))
        return abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x) / denominator
    }

    private func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(CGFloat(0)) { total, pair in
            total + distance(pair.0, pair.1)
        }
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt(dx * dx + dy * dy)
    }
}

struct MathItLevelFortyEightView: View {
    var viewModel: MathItLevelFortyEightViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let drawingRect = CGRect(
                x: max(28, (size.width - min(310, size.width - 54)) / 2),
                y: size.height * 0.52,
                width: min(310, size.width - 54),
                height: min(210, size.height * 0.28)
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)
                patternRow(size: size)
                sketchPad(rect: drawingRect)
                clearButton(rect: drawingRect)

                CompletionOverlay(
                    title: "Level 48 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
            .coordinateSpace(name: "levelFortyEightStage")
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 10) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.garamond(min(34, size.width * 0.085)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.36))

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: max(180, size.width - 68))
                .opacity(0.74)
                .padding(.top, 4)
        }
        .position(x: size.width / 2, y: 94)
    }

    private func patternRow(size: CGSize) -> some View {
        HStack(spacing: min(22, size.width * 0.045)) {
            ForEach(viewModel.currentStage.sequence, id: \.self) { symbol in
                patternSymbol(symbol, filled: false)
            }
            answerSlot
        }
        .position(x: size.width / 2, y: size.height * 0.34)
        .animation(.spring(response: 0.5, dampingFraction: 0.84), value: viewModel.stage)
    }

    @ViewBuilder
    private func patternSymbol(_ symbol: LevelFortyEightSymbol, filled: Bool) -> some View {
        switch symbol {
        case .polygon(let edges):
            patternShape(edges: edges, filled: filled)
        case .dots(let count):
            dotCluster(count: count, filled: filled)
        case .combo(let edges, let dots):
            comboSymbol(edges: edges, dots: dots, filled: filled)
        }
    }

    private func patternShape(edges: Int, filled: Bool) -> some View {
        LevelFortyEightPolygon(edges: edges)
            .stroke(filled ? accent : .white.opacity(0.72), lineWidth: filled ? 2.5 : 1.7)
            .background {
                LevelFortyEightPolygon(edges: edges)
                    .fill(filled ? accent.opacity(0.1) : .white.opacity(0.025))
            }
            .frame(width: 58, height: 58)
            .shadow(color: filled ? accent.opacity(0.58) : .white.opacity(0.12), radius: filled ? 12 : 5)
    }

    private func dotCluster(count: Int, filled: Bool) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(filled ? accent : .white.opacity(0.76))
                    .frame(width: filled ? 8 : 7, height: filled ? 8 : 7)
                    .position(dotPosition(index: index, count: count, size: 58))
            }
        }
        .frame(width: 58, height: 58)
        .background(.white.opacity(filled ? 0.05 : 0.018), in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: filled ? accent.opacity(0.56) : .white.opacity(0.1), radius: filled ? 12 : 4)
    }

    private func comboSymbol(edges: Int, dots: Int, filled: Bool) -> some View {
        ZStack {
            patternShape(edges: edges, filled: filled)
                .frame(width: 58, height: 58)

            dotCluster(count: dots, filled: filled)
                .frame(width: 34, height: 34)
                .scaleEffect(0.7)
        }
        .frame(width: 58, height: 58)
    }

    private func dotPosition(index: Int, count: Int, size: CGFloat) -> CGPoint {
        if let position = triangularDotPosition(index: index, count: count, size: size) {
            return position
        }
        if let position = compactDotPosition(index: index, count: count, size: size) {
            return position
        }
        if let position = squareDotPosition(index: index, count: count, size: size) {
            return position
        }

        let columns = min(4, max(1, Int(ceil(sqrt(Double(count))))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let column = index % columns
        let row = index / columns
        let spacing: CGFloat = count <= 4 ? 16 : 13
        let x = size / 2 + (CGFloat(column) - CGFloat(columns - 1) / 2) * spacing
        let y = size / 2 + (CGFloat(row) - CGFloat(rows - 1) / 2) * spacing
        return CGPoint(x: x, y: y)
    }

    private func compactDotPosition(index: Int, count: Int, size: CGFloat) -> CGPoint? {
        let layouts: [Int: [(CGFloat, CGFloat)]] = [
            5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
            6: [(-1, -1), (0, -1), (1, -1), (-1, 1), (0, 1), (1, 1)],
            7: [(-1, -1), (0, -1), (1, -1), (-1.5, 0.6), (-0.5, 0.6), (0.5, 0.6), (1.5, 0.6)],
            8: [(-1.5, -1), (-0.5, -1), (0.5, -1), (1.5, -1), (-1.5, 1), (-0.5, 1), (0.5, 1), (1.5, 1)]
        ]
        guard let layout = layouts[count], layout.indices.contains(index) else { return nil }
        let spacing: CGFloat = count >= 7 ? 8.5 : 9.5
        return CGPoint(
            x: size / 2 + layout[index].0 * spacing,
            y: size / 2 + layout[index].1 * spacing
        )
    }

    private func squareDotPosition(index: Int, count: Int, size: CGFloat) -> CGPoint? {
        guard [4, 9, 16].contains(count) else { return nil }
        let columns = Int(sqrt(Double(count)))
        let column = index % columns
        let row = index / columns
        let spacing: CGFloat = count <= 4 ? 15 : count == 9 ? 12 : 9
        let x = size / 2 + (CGFloat(column) - CGFloat(columns - 1) / 2) * spacing
        let y = size / 2 + (CGFloat(row) - CGFloat(columns - 1) / 2) * spacing
        return CGPoint(x: x, y: y)
    }

    private func triangularDotPosition(index: Int, count: Int, size: CGFloat) -> CGPoint? {
        guard [1, 3, 6, 10].contains(count) else { return nil }

        var remaining = index
        var row = 0
        while remaining >= row + 1 {
            remaining -= row + 1
            row += 1
        }

        let rows = count == 1 ? 1 : count == 3 ? 2 : count == 6 ? 3 : 4
        let spacing: CGFloat = count <= 3 ? 15 : 12
        let rowCount = row + 1
        let x = size / 2 + (CGFloat(remaining) - CGFloat(rowCount - 1) / 2) * spacing
        let y = size / 2 + (CGFloat(row) - CGFloat(rows - 1) / 2) * spacing
        return CGPoint(x: x, y: y)
    }

    private var answerSlot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.formalized ? accent.opacity(0.75) : .white.opacity(0.22), style: StrokeStyle(lineWidth: 1.3, dash: viewModel.formalized ? [] : [4, 5]))
                .frame(width: 66, height: 66)

            if viewModel.formalized {
                patternSymbol(viewModel.currentStage.answer, filled: true)
                    .transition(.scale(scale: 0.78).combined(with: .opacity))
            }
        }
        .frame(width: 66, height: 66)
    }

    private func sketchPad(rect: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.wrongPulse ? Color.red.opacity(0.8) : .white.opacity(0.22), lineWidth: viewModel.wrongPulse ? 2 : 1.2)
                .background(.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: viewModel.formalized ? accent.opacity(0.28) : .clear, radius: 18)

            if viewModel.formalized {
                patternSymbol(viewModel.currentStage.answer, filled: true)
                    .scaleEffect(1.45)
                    .frame(width: 112, height: 112)
            } else {
                sketchLines
                    .frame(width: rect.width, height: rect.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .position(x: rect.midX, y: rect.midY)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("levelFortyEightStage"))
                .onChanged { value in
                    let localPoint = CGPoint(x: value.location.x - rect.minX, y: value.location.y - rect.minY)
                    if viewModel.activeStroke.isEmpty {
                        viewModel.beginDrawing(at: localPoint)
                    } else {
                        viewModel.continueDrawing(to: localPoint)
                    }
                }
                .onEnded { _ in
                    viewModel.finishDrawing(in: CGRect(origin: .zero, size: rect.size))
                }
        )
    }

    private var sketchLines: some View {
        ZStack {
            ForEach(viewModel.strokes) { stroke in
                sketchPath(points: stroke.points)
            }

            sketchPath(points: viewModel.activeStroke)
        }
    }

    @ViewBuilder
    private func sketchPath(points: [CGPoint]) -> some View {
        if points.count == 1, let point = points.first {
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .position(point)
                .shadow(color: accent.opacity(0.9), radius: 9)
                .shadow(color: .white.opacity(0.34), radius: 2)
        } else {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.white, accent, .white.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: accent.opacity(0.82), radius: 8)
            .shadow(color: .white.opacity(0.34), radius: 2)
        }
    }

    private func clearButton(rect: CGRect) -> some View {
        Button(action: viewModel.clearDrawing) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(viewModel.formalized ? .white.opacity(0.22) : .black)
                .frame(width: 40, height: 40)
                .background(viewModel.formalized ? .white.opacity(0.08) : accent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.formalized)
        .position(x: rect.maxX - 24, y: rect.maxY + 34)
    }
}

struct LevelFortyEightPolygon: Shape {
    let edges: Int

    func path(in rect: CGRect) -> Path {
        let sides = max(3, edges)
        let radius = min(rect.width, rect.height) * 0.42
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        for index in 0..<sides {
            let angle = (-Double.pi / 2) + (Double(index) * 2 * Double.pi / Double(sides))
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
