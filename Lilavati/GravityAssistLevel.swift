import SwiftUI
import UIKit

@Observable
final class MathItLevelTwentyViewModel {
    var tokens: [LevelTwentyMathToken] = [
        LevelTwentyMathToken(kind: .number(1), position: .zero),
        LevelTwentyMathToken(kind: .plus, position: .zero),
        LevelTwentyMathToken(kind: .multiply, position: .zero),
        LevelTwentyMathToken(kind: .equals, position: .zero)
    ]
    var initialized = false
    var plusCreated = false
    var multiplyCreated = false
    var equalsCreated = false
    var launchProgress: CGFloat = 0
    var escapeStartTime: TimeInterval = 0
    var orbiting = true
    var completed = false
    var escapeDuration: TimeInterval { 3.4 }

    var progress: Double {
        if completed { return 1 }
        let bestNumber = tokens.compactMap(\.kind.numberValue).max() ?? 1
        return min(0.96, 0.16 + Double(min(bestNumber, 4)) * 0.16)
    }

    func initialize(size: CGSize) {
        guard !initialized else { return }
        initialized = true
        let y = size.height * 0.88
        setToken(.number(1), at: CGPoint(x: size.width * 0.18, y: y), occurrence: 0)
        setToken(.plus, at: CGPoint(x: size.width * 0.40, y: y), occurrence: 0)
        setToken(.multiply, at: CGPoint(x: size.width * 0.60, y: y), occurrence: 0)
        setToken(.equals, at: CGPoint(x: size.width * 0.82, y: y), occurrence: 0)
    }

    func splitOne(id: UUID) {
        guard let token = tokens.first(where: { $0.id == id }),
              token.kind == .number(1),
              tokens.filter({ $0.kind == .number(1) }).count == 1 else { return }

        HapticPlayer.playLightTap()
        tokens.append(LevelTwentyMathToken(kind: .number(1), position: token.position))
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            if let index = tokens.indices.last {
                tokens[index].position.x += 72
            }
        }
    }

    func makePlus() {
        guard !plusCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            plusCreated = true
        }
    }

    func makeMultiply() {
        guard !multiplyCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            multiplyCreated = true
        }
    }

    func makeEquals() {
        guard !equalsCreated else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            equalsCreated = true
        }
    }

    func moveToken(id: UUID, to point: CGPoint, bounds: CGSize) {
        guard !completed, let index = tokens.firstIndex(where: { $0.id == id }) else { return }
        guard canUse(tokens[index].kind) else { return }
        tokens[index].position = clamped(point, in: bounds)
    }

    func finishToken(id: UUID, speedBox: CGRect, bounds: CGSize) {
        guard !completed, let token = tokens.first(where: { $0.id == id }) else { return }
        guard canUse(token.kind) else { return }

        if let value = token.kind.numberValue, value >= 4, speedBox.insetBy(dx: -18, dy: -18).contains(token.position) {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                setTokenPosition(id: id, point: CGPoint(x: speedBox.midX, y: speedBox.midY))
            }
            triggerEscape()
            return
        }

        snapNearby(to: id, bounds: bounds)
        evaluateExpressions(bounds: bounds)
    }

    private func snapNearby(to id: UUID, bounds: CGSize) {
        guard let dragged = tokens.first(where: { $0.id == id }) else { return }
        guard isUsable(dragged) else { return }
        let close = tokens.filter { other in
            other.id != id
                && isUsable(other)
                && abs(other.position.x - dragged.position.x) < 58
                && abs(other.position.y - dragged.position.y) < 40
        }
        guard !close.isEmpty else { return }

        let cluster = ([dragged] + close).sorted { $0.position.x < $1.position.x }
        let spacing: CGFloat = 54
        let centerX = cluster.map(\.position.x).reduce(0, +) / CGFloat(cluster.count)
        let centerY = cluster.map(\.position.y).reduce(0, +) / CGFloat(cluster.count)
        let left = centerX - CGFloat(cluster.count - 1) * spacing / 2

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
            for (index, token) in cluster.enumerated() {
                setTokenPosition(
                    id: token.id,
                    point: clamped(CGPoint(x: left + CGFloat(index) * spacing, y: centerY), in: bounds)
                )
            }
        }
    }

    private func evaluateExpressions(bounds: CGSize) {
        let rows = clusteredRows()
        for row in rows {
            let sorted = row.sorted { $0.position.x < $1.position.x }
            guard let equalsIndex = sorted.firstIndex(where: { $0.kind == .equals }),
                  equalsIndex >= 3 else { continue }

            let leftSide = Array(sorted[..<equalsIndex])
            guard leftSide.count >= 3,
                  let left = leftSide[leftSide.count - 3].kind.numberValue,
                  let right = leftSide[leftSide.count - 1].kind.numberValue else { continue }

            let op = leftSide[leftSide.count - 2].kind
            let result: Int?
            switch op {
            case .plus:
                result = left + right
            case .multiply:
                result = left * right
            default:
                result = nil
            }

            guard let result else { continue }
            let resultPoint = clamped(
                CGPoint(x: sorted[equalsIndex].position.x + 70, y: sorted[equalsIndex].position.y),
                in: bounds
            )

            let alreadyExists = tokens.contains { token in
                token.kind == .number(result) && hypot(token.position.x - resultPoint.x, token.position.y - resultPoint.y) < 42
            }
            guard !alreadyExists else { continue }

            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                tokens.append(LevelTwentyMathToken(kind: .number(result), position: resultPoint))
            }
        }
    }

    private func clusteredRows() -> [[LevelTwentyMathToken]] {
        var remaining = tokens.filter(isUsable)
        var rows: [[LevelTwentyMathToken]] = []

        while let seed = remaining.first {
            var row = [seed]
            remaining.removeAll { $0.id == seed.id }
            var changed = true
            while changed {
                changed = false
                for token in remaining {
                    if row.contains(where: { abs($0.position.y - token.position.y) < 42 && abs($0.position.x - token.position.x) < 82 }) {
                        row.append(token)
                        remaining.removeAll { $0.id == token.id }
                        changed = true
                        break
                    }
                }
            }
            rows.append(row)
        }

        return rows
    }

    private func isUsable(_ token: LevelTwentyMathToken) -> Bool {
        canUse(token.kind)
    }

    private func canUse(_ kind: LevelTwentyTokenKind) -> Bool {
        switch kind {
        case .number:
            true
        case .plus:
            plusCreated
        case .multiply:
            multiplyCreated
        case .equals:
            equalsCreated
        }
    }

    private func triggerEscape() {
        guard !completed else { return }
        escapeStartTime = Date().timeIntervalSinceReferenceDate
        orbiting = false
        launchProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + escapeDuration) {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    private func setToken(_ kind: LevelTwentyTokenKind, at point: CGPoint, occurrence: Int) {
        var seen = 0
        for index in tokens.indices where tokens[index].kind == kind {
            if seen == occurrence {
                tokens[index].position = point
                return
            }
            seen += 1
        }
    }

    private func setTokenPosition(id: UUID, point: CGPoint) {
        guard let index = tokens.firstIndex(where: { $0.id == id }) else { return }
        tokens[index].position = point
    }

    private func clamped(_ point: CGPoint, in bounds: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 26), max(26, bounds.width - 26)),
            y: min(max(point.y, 146), max(146, bounds.height - 26))
        )
    }
}

struct LevelTwentyMathToken: Identifiable, Equatable {
    let id: UUID
    let kind: LevelTwentyTokenKind
    var position: CGPoint

    init(id: UUID = UUID(), kind: LevelTwentyTokenKind, position: CGPoint) {
        self.id = id
        self.kind = kind
        self.position = position
    }
}

enum LevelTwentyTokenKind: Equatable {
    case number(Int)
    case plus
    case multiply
    case equals

    var text: String {
        switch self {
        case .number(let value): "\(value)"
        case .plus: "+"
        case .multiply: "x"
        case .equals: "="
        }
    }

    var numberValue: Int? {
        if case .number(let value) = self { value } else { nil }
    }
}

struct MathItLevelTwentyView: View {
    var viewModel: MathItLevelTwentyViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 22, y: size.height * 0.18, width: size.width - 44, height: min(400, size.height * 0.52))
            let gravity = CGPoint(x: board.midX, y: board.midY)
            let speedBox = CGRect(x: size.width / 2 - 32, y: size.height * 0.75 - 24, width: 64, height: 48)

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

                    EmptyView()
                        .font(.trajan(36))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                }
                .position(x: size.width / 2, y: 74)

                ProgressView(value: viewModel.progress)
                    .tint(.white)
                    .opacity(0.72)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 128)

                gravityBoard(board: board, gravity: gravity)

                speedRequirement(speedBox: speedBox)

                mathTokens(size: size, speedBox: speedBox)

                CompletionOverlay(
                    title: "Level 20 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .task(id: CGSize(width: size.width, height: size.height)) {
                viewModel.initialize(size: size)
            }
        }
    }

    private func gravityBoard(board: CGRect, gravity: CGPoint) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.16), lineWidth: 1.2)
                }
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            GravityGridShape()
                .stroke(.white.opacity(0.055), lineWidth: 1)
                .frame(width: board.width, height: board.height)
                .position(x: board.midX, y: board.midY)

            orbitPath(center: gravity, radius: board.width * 0.21)
                .stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 7]))

            orbitPath(center: gravity, radius: board.width * 0.31)
                .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, dash: [7, 7]))

            orbitPath(center: gravity, radius: board.width * 0.43)
                .stroke(Color.mathItAlgebra.opacity(0.42), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, dash: [8, 8]))

            Circle()
                .fill(Color.mathItAlgebra)
                .frame(width: 36, height: 36)
                .shadow(color: Color.mathItAlgebra.opacity(0.82), radius: 18)
                .position(gravity)

            if viewModel.orbiting {
                TimelineView(.animation) { _ in
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .white.opacity(0.7), radius: 12)
                        .position(orbitingPoint(center: gravity, radius: board.width * 0.21))
                }
            } else {
                TimelineView(.animation) { context in
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .white.opacity(0.7), radius: 12)
                        .position(escapePoint(
                            board: board,
                            gravity: gravity,
                            progress: escapeProgress(at: context.date)
                        ))
                }
            }
        }
    }

    private func mathTokens(size: CGSize, speedBox: CGRect) -> some View {
        ZStack {
            ForEach(viewModel.tokens) { token in
                mathToken(token, size: size, speedBox: speedBox)
            }
        }
        .coordinateSpace(name: "levelTwentyStage")
    }

    @ViewBuilder
    private func mathToken(_ token: LevelTwentyMathToken, size: CGSize, speedBox: CGRect) -> some View {
        switch token.kind {
        case .number(let value):
            numberToken(token, value: value, size: size, speedBox: speedBox)
        case .plus:
            plusToken(token, size: size, speedBox: speedBox)
        case .multiply:
            multiplyToken(token, size: size, speedBox: speedBox)
        case .equals:
            equalsToken(token, size: size, speedBox: speedBox)
        }
    }

    private func numberToken(_ token: LevelTwentyMathToken, value: Int, size: CGSize, speedBox: CGRect) -> some View {
        Text(String(value))
            .font(.trajan(64))
            .foregroundStyle(.white.opacity(value == 1 ? 0.82 : 0.9))
            .shadow(color: .white.opacity(value == 1 ? 0.28 : 0.34), radius: value == 1 ? 10 : 12)
            .frame(width: value == 1 ? 64 : 74, height: 82)
            .contentShape(Rectangle())
            .overlay {
                if value == 1 {
                    LevelTwentyPinchLayer {
                        viewModel.splitOne(id: token.id)
                    }
                }
            }
            .gesture(tokenDragGesture(token.id, size: size, speedBox: speedBox))
            .position(token.position)
            .accessibilityLabel(value == 1 ? "Splittable one" : "Created number \(value)")
    }

    private func plusToken(_ token: LevelTwentyMathToken, size: CGSize, speedBox: CGRect) -> some View {
        Group {
            if viewModel.plusCreated {
                Text("+")
                    .font(.trajan(52))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.34), radius: 10)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.86))
                    .frame(width: 4, height: 58)
                    .shadow(color: .white.opacity(0.24), radius: 8)
            }
        }
        .frame(width: 76, height: 84)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.makePlus()
        }
        .gesture(tokenDragGesture(token.id, size: size, speedBox: speedBox), isEnabled: viewModel.plusCreated)
        .position(token.position)
        .accessibilityLabel("Double tap to make plus")
    }

    private func multiplyToken(_ token: LevelTwentyMathToken, size: CGSize, speedBox: CGRect) -> some View {
        Group {
            if viewModel.multiplyCreated {
                Text("×")
                    .font(.trajan(52))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.34), radius: 10)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.86))
                    .frame(width: 4, height: 58)
                    .rotationEffect(.degrees(42))
                    .shadow(color: .white.opacity(0.24), radius: 8)
            }
        }
        .frame(width: 76, height: 84)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.45) {
            viewModel.makeMultiply()
        }
        .gesture(tokenDragGesture(token.id, size: size, speedBox: speedBox), isEnabled: viewModel.multiplyCreated)
        .position(token.position)
        .accessibilityLabel("Long press to make multiply")
    }

    private func equalsToken(_ token: LevelTwentyMathToken, size: CGSize, speedBox: CGRect) -> some View {
        Group {
            if viewModel.equalsCreated {
                Text("=")
                    .font(.trajan(52))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.34), radius: 10)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.86))
                    .frame(width: 58, height: 4)
                    .shadow(color: .white.opacity(0.24), radius: 8)
            }
        }
        .frame(width: 76, height: 84)
        .contentShape(Rectangle())
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    if scale > 1.12 {
                        viewModel.makeEquals()
                    }
                }
        )
        .gesture(tokenDragGesture(token.id, size: size, speedBox: speedBox), isEnabled: viewModel.equalsCreated)
        .position(token.position)
        .accessibilityLabel("Pinch apart to make equals")
    }

    private func tokenDragGesture(_ id: UUID, size: CGSize, speedBox: CGRect) -> some Gesture {
        DragGesture(coordinateSpace: .named("levelTwentyStage"))
            .onChanged { value in
                viewModel.moveToken(id: id, to: value.location, bounds: size)
            }
            .onEnded { _ in
                viewModel.finishToken(id: id, speedBox: speedBox, bounds: size)
            }
    }

    private func speedRequirement(speedBox: CGRect) -> some View {
        HStack(spacing: 8) {
            Text("(")
                .foregroundStyle(.white.opacity(0.72))

            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.48), lineWidth: 1.8)
                .frame(width: speedBox.width, height: speedBox.height)

            Text(") > 3")
                .foregroundStyle(.white.opacity(0.36))
        }
        .font(.system(size: 24, weight: .semibold, design: .monospaced))
        .position(x: speedBox.midX + 36, y: speedBox.midY)
    }

    private func escapeProgress(at date: Date) -> CGFloat {
        guard viewModel.escapeStartTime > 0 else { return 0 }
        let elapsed = date.timeIntervalSinceReferenceDate - viewModel.escapeStartTime
        return CGFloat(min(1, max(0, elapsed / viewModel.escapeDuration)))
    }

    private func orbitingPoint(center: CGPoint, radius: CGFloat) -> CGPoint {
        orbitingPoint(center: center, radius: radius, time: Date().timeIntervalSinceReferenceDate)
    }

    private func orbitingPoint(center: CGPoint, radius: CGFloat, time: TimeInterval) -> CGPoint {
        let angle = orbitAngle(time: time)
        return CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
    }

    private func orbitPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for step in 0...140 {
            let angle = CGFloat(step) / 140 * .pi * 2
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func escapePoint(board: CGRect, gravity: CGPoint, progress: CGFloat) -> CGPoint {
        let t = min(1, max(0, progress))
        let angle = orbitAngle(time: viewModel.escapeStartTime)
        let start = orbitingPoint(
            center: gravity,
            radius: board.width * 0.21,
            time: viewModel.escapeStartTime
        )
        let unit = CGVector(dx: -sin(angle), dy: cos(angle))
        let travel = max(board.width, board.height) * 1.35

        return CGPoint(
            x: start.x + unit.dx * travel * t,
            y: start.y + unit.dy * travel * t
        )
    }

    private func orbitAngle(time: TimeInterval) -> CGFloat {
        CGFloat(time.truncatingRemainder(dividingBy: 2.7) / 2.7) * .pi * 2
    }
}

private struct GravityGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let columns = 8
        let rows = 7

        for column in 0...columns {
            let x = rect.minX + rect.width * CGFloat(column) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        for row in 0...rows {
            let y = rect.minY + rect.height * CGFloat(row) / CGFloat(rows)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private struct LevelTwentyPinchLayer: UIViewRepresentable {
    let onSplit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSplit: onSplit)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let recognizer = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let onSplit: () -> Void
        private var hasTriggered = false
        private var startHorizontalDistance: CGFloat?
        private var startVerticalDistance: CGFloat?

        init(onSplit: @escaping () -> Void) {
            self.onSplit = onSplit
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                hasTriggered = false
                captureStartDistances(from: recognizer)
            case .changed:
                guard !hasTriggered else { return }

                if startHorizontalDistance == nil || startVerticalDistance == nil {
                    captureStartDistances(from: recognizer)
                }

                let hasScaleGrowth = recognizer.scale > 1.14
                let hasHorizontalGrowth = distanceGrowth(from: recognizer, axis: .horizontal)
                let hasVerticalGrowth = distanceGrowth(from: recognizer, axis: .vertical)

                if hasScaleGrowth || hasHorizontalGrowth || hasVerticalGrowth {
                    hasTriggered = true
                    onSplit()
                }
            case .ended, .cancelled, .failed:
                hasTriggered = false
                startHorizontalDistance = nil
                startVerticalDistance = nil
            default:
                break
            }
        }

        private func captureStartDistances(from recognizer: UIPinchGestureRecognizer) {
            guard recognizer.numberOfTouches >= 2, let view = recognizer.view else { return }

            let first = recognizer.location(ofTouch: 0, in: view)
            let second = recognizer.location(ofTouch: 1, in: view)
            startHorizontalDistance = abs(first.x - second.x)
            startVerticalDistance = abs(first.y - second.y)
        }

        private enum Axis {
            case horizontal
            case vertical
        }

        private func distanceGrowth(from recognizer: UIPinchGestureRecognizer, axis: Axis) -> Bool {
            guard recognizer.numberOfTouches >= 2, let view = recognizer.view else { return false }

            let first = recognizer.location(ofTouch: 0, in: view)
            let second = recognizer.location(ofTouch: 1, in: view)
            let currentDistance: CGFloat
            let startDistance: CGFloat?

            switch axis {
            case .horizontal:
                currentDistance = abs(first.x - second.x)
                startDistance = startHorizontalDistance
            case .vertical:
                currentDistance = abs(first.y - second.y)
                startDistance = startVerticalDistance
            }

            guard let startDistance, startDistance > 2 else { return false }

            return currentDistance - startDistance > 18 && currentDistance / startDistance > 1.12
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}
