import SwiftUI
import Foundation

enum LevelFiftySixNetKind {
    case cube
    case triangularPrism
    case pyramid
}

struct LevelFiftySixFoldLine: Hashable {
    let a: Int
    let b: Int
}

struct LevelFiftySixFace: Identifiable {
    let id: Int
    let grid: CGPoint
    let kind: LevelFiftySixNetKind
    let isTriangle: Bool
}

struct LevelFiftySixStage {
    let kind: LevelFiftySixNetKind
    let faces: [LevelFiftySixFace]
    let foldLines: [LevelFiftySixFoldLine]
}

struct LevelFiftySixStroke: Identifiable {
    let id = UUID()
    let start: CGPoint
    let end: CGPoint
}

@Observable
final class MathItLevelFiftySixViewModel {
    let stages = [
        LevelFiftySixStage(
            kind: .cube,
            faces: [
                LevelFiftySixFace(id: 0, grid: CGPoint(x: 1, y: 1), kind: .cube, isTriangle: false),
                LevelFiftySixFace(id: 1, grid: CGPoint(x: 0, y: 1), kind: .cube, isTriangle: false),
                LevelFiftySixFace(id: 2, grid: CGPoint(x: 2, y: 1), kind: .cube, isTriangle: false),
                LevelFiftySixFace(id: 3, grid: CGPoint(x: 1, y: 0), kind: .cube, isTriangle: false),
                LevelFiftySixFace(id: 4, grid: CGPoint(x: 1, y: 2), kind: .cube, isTriangle: false),
                LevelFiftySixFace(id: 5, grid: CGPoint(x: 3, y: 1), kind: .cube, isTriangle: false)
            ],
            foldLines: [
                LevelFiftySixFoldLine(a: 0, b: 1),
                LevelFiftySixFoldLine(a: 0, b: 2),
                LevelFiftySixFoldLine(a: 0, b: 3),
                LevelFiftySixFoldLine(a: 0, b: 4),
                LevelFiftySixFoldLine(a: 2, b: 5)
            ]
        ),
        LevelFiftySixStage(
            kind: .triangularPrism,
            faces: [
                LevelFiftySixFace(id: 0, grid: CGPoint(x: 1, y: 1), kind: .triangularPrism, isTriangle: false),
                LevelFiftySixFace(id: 1, grid: CGPoint(x: 0, y: 1), kind: .triangularPrism, isTriangle: true),
                LevelFiftySixFace(id: 2, grid: CGPoint(x: 2, y: 1), kind: .triangularPrism, isTriangle: false),
                LevelFiftySixFace(id: 3, grid: CGPoint(x: 3, y: 1), kind: .triangularPrism, isTriangle: true),
                LevelFiftySixFace(id: 4, grid: CGPoint(x: 1, y: 0), kind: .triangularPrism, isTriangle: false)
            ],
            foldLines: [
                LevelFiftySixFoldLine(a: 0, b: 1),
                LevelFiftySixFoldLine(a: 0, b: 2),
                LevelFiftySixFoldLine(a: 2, b: 3),
                LevelFiftySixFoldLine(a: 0, b: 4)
            ]
        ),
        LevelFiftySixStage(
            kind: .pyramid,
            faces: [
                LevelFiftySixFace(id: 0, grid: CGPoint(x: 1, y: 1), kind: .pyramid, isTriangle: false),
                LevelFiftySixFace(id: 1, grid: CGPoint(x: 1, y: 0), kind: .pyramid, isTriangle: true),
                LevelFiftySixFace(id: 2, grid: CGPoint(x: 2, y: 1), kind: .pyramid, isTriangle: true),
                LevelFiftySixFace(id: 3, grid: CGPoint(x: 1, y: 2), kind: .pyramid, isTriangle: true),
                LevelFiftySixFace(id: 4, grid: CGPoint(x: 0, y: 1), kind: .pyramid, isTriangle: true)
            ],
            foldLines: [
                LevelFiftySixFoldLine(a: 0, b: 1),
                LevelFiftySixFoldLine(a: 0, b: 2),
                LevelFiftySixFoldLine(a: 0, b: 3),
                LevelFiftySixFoldLine(a: 0, b: 4)
            ]
        )
    ]

    var stageIndex = 0
    var strokes: [LevelFiftySixStroke] = []
    var activeStart: CGPoint?
    var activeEnd: CGPoint?
    var matchedLines: Set<LevelFiftySixFoldLine> = []
    var wrongPulse = false
    var folding = false
    var completed = false

    var currentStage: LevelFiftySixStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        let local = Double(matchedLines.count) / Double(max(1, currentStage.foldLines.count))
        return (Double(stageIndex) + local) / Double(stages.count)
    }

    func beginLine(at point: CGPoint) {
        guard !completed, !folding else { return }
        activeStart = point
        activeEnd = point
    }

    func updateLine(to point: CGPoint) {
        guard !completed, !folding else { return }
        activeEnd = point
    }

    func finishLine(in rect: CGRect) {
        guard let activeStart, let activeEnd, !completed, !folding else {
            clearActive()
            return
        }

        if let line = closestFoldLine(to: LevelFiftySixStroke(start: activeStart, end: activeEnd), in: rect),
           !matchedLines.contains(line) {
            let snappedStroke = foldStroke(for: line, in: rect)
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                matchedLines.insert(line)
                strokes.append(snappedStroke)
                wrongPulse = false
            }
            clearActive()

            if matchedLines.count == currentStage.foldLines.count {
                foldAndAdvance()
            }
        } else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.44)) {
                wrongPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    self.wrongPulse = false
                    self.clearActive()
                }
            }
        }
    }

    func resetStage() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            strokes.removeAll()
            matchedLines.removeAll()
            wrongPulse = false
            folding = false
            clearActive()
        }
    }

    func faceCenter(for face: LevelFiftySixFace, in rect: CGRect) -> CGPoint {
        let columns = max(1, (currentStage.faces.map { Int($0.grid.x) }.max() ?? 0) + 1)
        let rows = max(1, (currentStage.faces.map { Int($0.grid.y) }.max() ?? 0) + 1)
        let cell = min(rect.width / CGFloat(columns), rect.height / CGFloat(rows)) * 0.82
        let originX = rect.midX - CGFloat(columns - 1) * cell / 2
        let originY = rect.midY - CGFloat(rows - 1) * cell / 2
        return CGPoint(x: originX + face.grid.x * cell, y: originY + face.grid.y * cell)
    }

    func faceSize(in rect: CGRect) -> CGFloat {
        let columns = max(1, (currentStage.faces.map { Int($0.grid.x) }.max() ?? 0) + 1)
        let rows = max(1, (currentStage.faces.map { Int($0.grid.y) }.max() ?? 0) + 1)
        return min(rect.width / CGFloat(columns), rect.height / CGFloat(rows)) * 0.82
    }

    func foldStroke(for fold: LevelFiftySixFoldLine, in rect: CGRect) -> LevelFiftySixStroke {
        guard let first = currentStage.faces.first(where: { $0.id == fold.a }),
              let second = currentStage.faces.first(where: { $0.id == fold.b }) else {
            return LevelFiftySixStroke(start: rect.origin, end: rect.origin)
        }
        let firstCenter = faceCenter(for: first, in: rect)
        let secondCenter = faceCenter(for: second, in: rect)
        let size = faceSize(in: rect)
        let mid = CGPoint(x: (firstCenter.x + secondCenter.x) / 2, y: (firstCenter.y + secondCenter.y) / 2)
        let horizontalNeighbors = abs(firstCenter.x - secondCenter.x) > abs(firstCenter.y - secondCenter.y)
        let start = horizontalNeighbors ? CGPoint(x: mid.x, y: mid.y - size / 2) : CGPoint(x: mid.x - size / 2, y: mid.y)
        let end = horizontalNeighbors ? CGPoint(x: mid.x, y: mid.y + size / 2) : CGPoint(x: mid.x + size / 2, y: mid.y)
        return LevelFiftySixStroke(start: start, end: end)
    }

    private func foldAndAdvance() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            folding = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.86) {
            if self.stageIndex == self.stages.count - 1 {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                    self.completed = true
                }
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    self.stageIndex += 1
                    self.strokes.removeAll()
                    self.matchedLines.removeAll()
                    self.folding = false
                    self.clearActive()
                }
            }
        }
    }

    private func closestFoldLine(to stroke: LevelFiftySixStroke, in rect: CGRect) -> LevelFiftySixFoldLine? {
        let strokeMid = CGPoint(x: (stroke.start.x + stroke.end.x) / 2, y: (stroke.start.y + stroke.end.y) / 2)
        let strokeAngle = angle(from: stroke.start, to: stroke.end)

        let candidates = currentStage.foldLines.compactMap { fold -> (fold: LevelFiftySixFoldLine, distance: CGFloat, angleDelta: Double)? in
            guard let first = currentStage.faces.first(where: { $0.id == fold.a }),
                  let second = currentStage.faces.first(where: { $0.id == fold.b }) else { return nil }
            let firstCenter = faceCenter(for: first, in: rect)
            let secondCenter = faceCenter(for: second, in: rect)
            let seamMid = CGPoint(x: (firstCenter.x + secondCenter.x) / 2, y: (firstCenter.y + secondCenter.y) / 2)
            let seamAngle = abs(firstCenter.x - secondCenter.x) > abs(firstCenter.y - secondCenter.y) ? 90.0 : 0.0
            let delta = min(abs(strokeAngle - seamAngle), abs(strokeAngle - seamAngle + 180), abs(strokeAngle - seamAngle - 180))
            return (fold, distance(strokeMid, seamMid), delta)
        }

        guard let match = candidates.min(by: { $0.distance + CGFloat($0.angleDelta) < $1.distance + CGFloat($1.angleDelta) }) else { return nil }
        let tolerance = faceSize(in: rect) * 0.42
        return match.distance < tolerance && match.angleDelta < 24 ? match.fold : nil
    }

    private func angle(from first: CGPoint, to second: CGPoint) -> Double {
        let radians = atan2(second.y - first.y, second.x - first.x)
        let degrees = abs(radians * 180 / .pi)
        return degrees > 180 ? degrees - 180 : degrees
    }

    private func clearActive() {
        activeStart = nil
        activeEnd = nil
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt(dx * dx + dy * dy)
    }
}

struct MathItLevelFiftySixView: View {
    var viewModel: MathItLevelFiftySixViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSize = min(size.width - 42, min(size.height * 0.52, 420))
            let boardRect = CGRect(
                x: (size.width - boardSize) / 2,
                y: size.height * 0.24,
                width: boardSize,
                height: boardSize
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                netBoard(rect: boardRect)

                Button(action: viewModel.resetStage) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.45), radius: 12)
                }
                .buttonStyle(.plain)
                .position(x: boardRect.maxX - 12, y: boardRect.maxY + 36)

                CompletionOverlay(
                    title: "Level 56 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
            .coordinateSpace(name: "levelFiftySix")
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.garamond(min(33, size.width * 0.08)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func netBoard(rect: CGRect) -> some View {
        let localRect = CGRect(origin: .zero, size: rect.size)

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.wrongPulse ? Color.red.opacity(0.8) : .white.opacity(0.18), lineWidth: viewModel.wrongPulse ? 2 : 1.2)
                .background(.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 8))

            connectedPaper(rect: localRect)

            if !viewModel.folding {
                ForEach(viewModel.strokes) { stroke in
                    drawnLine(start: stroke.start, end: stroke.end, color: accent, width: 3.8, dash: [7, 7])
                }
            }

            if !viewModel.folding, let start = viewModel.activeStart, let end = viewModel.activeEnd {
                drawnLine(start: start, end: end, color: .white, width: 3.4, dash: [7, 7])
            }

            if viewModel.folding {
                foldedPreview(rect: localRect)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("levelFiftySix"))
                .onChanged { value in
                    let point = boardPoint(from: value.location, boardRect: rect)
                    if viewModel.activeStart == nil {
                        viewModel.beginLine(at: point)
                    } else {
                        viewModel.updateLine(to: point)
                    }
                }
                .onEnded { _ in
                    viewModel.finishLine(in: localRect)
                }
        )
    }

    private func connectedPaper(rect: CGRect) -> some View {
        LevelFiftySixNetSilhouette(stage: viewModel.currentStage)
            .fill(accent.opacity(viewModel.folding ? 0 : 0.16))
            .overlay(
                LevelFiftySixNetSilhouette(stage: viewModel.currentStage)
                    .stroke(.white.opacity(viewModel.folding ? 0 : 0.68), lineWidth: 2.2)
            )
            .frame(width: rect.width, height: rect.height)
            .shadow(color: accent.opacity(0.18), radius: 10)
    }

    @ViewBuilder
    private func foldedPreview(rect: CGRect) -> some View {
        let faceSize = viewModel.faceSize(in: rect)

        ZStack {
            switch viewModel.currentStage.kind {
            case .cube:
                LevelFiftySixCubeSolid(accent: accent)
                    .frame(width: faceSize * 2.1, height: faceSize * 2.1)
            case .triangularPrism:
                LevelFiftySixTriangularPrismSolid(accent: accent)
                    .frame(width: faceSize * 2.55, height: faceSize * 1.55)
            case .pyramid:
                LevelFiftySixPyramidSolid(accent: accent)
                    .frame(width: faceSize * 2.15, height: faceSize * 2.15)
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .transition(.scale.combined(with: .opacity))
        .shadow(color: accent.opacity(0.36), radius: 18)
    }

    private func drawnLine(start: CGPoint, end: CGPoint, color: Color, width: CGFloat, dash: [CGFloat] = []) -> some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
        .shadow(color: color.opacity(0.56), radius: width * 1.8)
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func boardPoint(from screenPoint: CGPoint, boardRect: CGRect) -> CGPoint {
        clamp(
            CGPoint(x: screenPoint.x - boardRect.minX, y: screenPoint.y - boardRect.minY),
            to: CGRect(origin: .zero, size: boardRect.size)
        )
    }
}

struct LevelFiftySixTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct LevelFiftySixCubeSolid: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let p = LevelFiftySixSolidGeometry.cubePoints(in: rect)

            ZStack {
                LevelFiftySixPolygon(points: [p.top, p.rightTop, p.right, p.center])
                    .fill(accent.opacity(0.28))
                LevelFiftySixPolygon(points: [p.center, p.right, p.bottom, p.leftBottom])
                    .fill(accent.opacity(0.2))
                LevelFiftySixPolygon(points: [p.leftTop, p.top, p.center, p.leftBottom])
                    .fill(accent.opacity(0.16))

                LevelFiftySixPolygon(points: [p.top, p.rightTop, p.right, p.bottom, p.leftBottom, p.leftTop])
                    .stroke(.white.opacity(0.76), lineWidth: 2.2)
                LevelFiftySixEdge(start: p.top, end: p.center)
                LevelFiftySixEdge(start: p.center, end: p.leftBottom)
                LevelFiftySixEdge(start: p.center, end: p.right)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct LevelFiftySixTriangularPrismSolid: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let a = CGPoint(x: w * 0.12, y: h * 0.72)
            let b = CGPoint(x: w * 0.3, y: h * 0.24)
            let c = CGPoint(x: w * 0.48, y: h * 0.72)
            let shift = CGSize(width: w * 0.38, height: -h * 0.12)
            let d = CGPoint(x: a.x + shift.width, y: a.y + shift.height)
            let e = CGPoint(x: b.x + shift.width, y: b.y + shift.height)
            let f = CGPoint(x: c.x + shift.width, y: c.y + shift.height)

            ZStack {
                LevelFiftySixPolygon(points: [a, b, e, d])
                    .fill(accent.opacity(0.16))
                LevelFiftySixPolygon(points: [b, c, f, e])
                    .fill(accent.opacity(0.28))
                LevelFiftySixPolygon(points: [a, c, f, d])
                    .fill(accent.opacity(0.2))
                LevelFiftySixPolygon(points: [d, e, f])
                    .fill(accent.opacity(0.34))

                LevelFiftySixPolygon(points: [a, b, c])
                    .stroke(.white.opacity(0.72), lineWidth: 2)
                LevelFiftySixPolygon(points: [d, e, f])
                    .stroke(Color.mathGold.opacity(0.95), lineWidth: 2)
                LevelFiftySixEdge(start: a, end: d)
                LevelFiftySixEdge(start: b, end: e)
                LevelFiftySixEdge(start: c, end: f)
                LevelFiftySixEdge(start: a, end: c)
            }
        }
    }
}

struct LevelFiftySixPyramidSolid: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let apex = CGPoint(x: w * 0.5, y: h * 0.12)
            let left = CGPoint(x: w * 0.16, y: h * 0.66)
            let front = CGPoint(x: w * 0.5, y: h * 0.88)
            let right = CGPoint(x: w * 0.84, y: h * 0.66)
            let back = CGPoint(x: w * 0.5, y: h * 0.46)

            ZStack {
                LevelFiftySixPolygon(points: [apex, left, front])
                    .fill(accent.opacity(0.18))
                LevelFiftySixPolygon(points: [apex, front, right])
                    .fill(accent.opacity(0.3))
                LevelFiftySixPolygon(points: [apex, right, back])
                    .fill(accent.opacity(0.23))
                LevelFiftySixPolygon(points: [left, back, right, front])
                    .fill(accent.opacity(0.12))

                LevelFiftySixPolygon(points: [left, back, right, front])
                    .stroke(Color.mathGold.opacity(0.85), lineWidth: 1.8)
                LevelFiftySixEdge(start: apex, end: left)
                LevelFiftySixEdge(start: apex, end: front)
                LevelFiftySixEdge(start: apex, end: right)
                LevelFiftySixEdge(start: apex, end: back, opacity: 0.34)
                LevelFiftySixEdge(start: left, end: front)
                LevelFiftySixEdge(start: front, end: right)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct LevelFiftySixPolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

struct LevelFiftySixEdge: View {
    let start: CGPoint
    let end: CGPoint
    var opacity: Double = 0.7

    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(.white.opacity(opacity), lineWidth: 1.8)
    }
}

enum LevelFiftySixSolidGeometry {
    static func cubePoints(in rect: CGRect) -> (top: CGPoint, rightTop: CGPoint, right: CGPoint, bottom: CGPoint, leftBottom: CGPoint, leftTop: CGPoint, center: CGPoint) {
        let w = rect.width
        let h = rect.height
        return (
            top: CGPoint(x: w * 0.5, y: h * 0.08),
            rightTop: CGPoint(x: w * 0.82, y: h * 0.26),
            right: CGPoint(x: w * 0.82, y: h * 0.64),
            bottom: CGPoint(x: w * 0.5, y: h * 0.86),
            leftBottom: CGPoint(x: w * 0.18, y: h * 0.64),
            leftTop: CGPoint(x: w * 0.18, y: h * 0.26),
            center: CGPoint(x: w * 0.5, y: h * 0.46)
        )
    }
}

struct LevelFiftySixNetSilhouette: Shape {
    let stage: LevelFiftySixStage

    func path(in rect: CGRect) -> Path {
        let columns = max(1, (stage.faces.map { Int($0.grid.x) }.max() ?? 0) + 1)
        let rows = max(1, (stage.faces.map { Int($0.grid.y) }.max() ?? 0) + 1)
        let cell = min(rect.width / CGFloat(columns), rect.height / CGFloat(rows)) * 0.82
        let originX = rect.midX - CGFloat(columns - 1) * cell / 2 - cell / 2
        let originY = rect.midY - CGFloat(rows - 1) * cell / 2 - cell / 2

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + x * cell, y: originY + y * cell)
        }

        var path = Path()
        let points: [CGPoint]

        switch stage.kind {
        case .cube:
            points = [
                point(1, 0), point(2, 0), point(2, 1), point(4, 1),
                point(4, 2), point(2, 2), point(2, 3), point(1, 3),
                point(1, 2), point(0, 2), point(0, 1), point(1, 1)
            ]
        case .triangularPrism:
            points = [
                point(1, 0), point(2, 0), point(2, 1), point(3, 1),
                point(4, 1.5), point(3, 2), point(1, 2), point(0, 1.5),
                point(1, 1)
            ]
        case .pyramid:
            points = [
                point(1, 0), point(2, 1), point(3, 1), point(2, 2),
                point(2, 3), point(1, 2), point(0, 2), point(1, 1)
            ]
        }

        guard let first = points.first else { return path }
        path.move(to: first)
        for next in points.dropFirst() {
            path.addLine(to: next)
        }
        path.closeSubpath()
        return path
    }
}
