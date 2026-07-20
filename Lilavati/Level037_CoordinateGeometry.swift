import SwiftUI
import Foundation

struct LevelFiftyNinePoint: Equatable {
    var x: Int
    var y: Int
}

struct LevelFiftyNineStage {
    let name: String
    let route: [LevelFiftyNinePoint]

    var target: LevelFiftyNinePoint {
        route.last ?? LevelFiftyNinePoint(x: 0, y: 0)
    }
}

@Observable
final class MathItLevelFiftyNineViewModel {
    let stages = [
        LevelFiftyNineStage(name: "square", route: [
            LevelFiftyNinePoint(x: 0, y: 0), LevelFiftyNinePoint(x: 4, y: 0),
            LevelFiftyNinePoint(x: 4, y: 4), LevelFiftyNinePoint(x: 0, y: 4),
            LevelFiftyNinePoint(x: 0, y: 0)
        ]),
        LevelFiftyNineStage(name: "triangle", route: [
            LevelFiftyNinePoint(x: 0, y: 0), LevelFiftyNinePoint(x: -3, y: 0),
            LevelFiftyNinePoint(x: 0, y: 5), LevelFiftyNinePoint(x: 3, y: 0),
            LevelFiftyNinePoint(x: 0, y: 0)
        ]),
        LevelFiftyNineStage(name: "pentagon", route: [
            LevelFiftyNinePoint(x: 0, y: 0), LevelFiftyNinePoint(x: -2, y: 0),
            LevelFiftyNinePoint(x: -3, y: 3), LevelFiftyNinePoint(x: 0, y: 5),
            LevelFiftyNinePoint(x: 3, y: 3), LevelFiftyNinePoint(x: 2, y: 0),
            LevelFiftyNinePoint(x: 0, y: 0)
        ])
    ]

    var stageIndex = 0
    var position = LevelFiftyNinePoint(x: 0, y: 0)
    var visited: [LevelFiftyNinePoint] = [LevelFiftyNinePoint(x: 0, y: 0)]
    var routeIndex = 0
    var slopeRise = 1
    var slopeRun = 1
    var wrongPulse = false
    var completed = false
    var advancing = false

    var currentStage: LevelFiftyNineStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var activeTarget: LevelFiftyNinePoint {
        guard routeIndex + 1 < currentStage.route.count else { return currentStage.target }
        return currentStage.route[routeIndex + 1]
    }

    var progress: Double {
        if completed { return 1 }
        let local = Double(routeIndex) / Double(max(1, currentStage.route.count - 1))
        return (Double(stageIndex) + max(0, local)) / Double(stages.count)
    }

    func move(dx: Int, dy: Int) {
        guard !completed, !advancing else { return }
        attemptMove(dx: dx, dy: dy)
    }

    func adjustRise(_ delta: Int) {
        adjustSlope { slopeRise = clamp(slopeRise + delta, min: -6, max: 6) }
    }

    func adjustRun(_ delta: Int) {
        adjustSlope { slopeRun = clamp(slopeRun + delta, min: -6, max: 6) }
    }

    func launchSlope() {
        guard !completed, !advancing else { return }
        guard slopeRise != 0 || slopeRun != 0 else {
            reject(reset: false)
            return
        }
        attemptMove(dx: slopeRun, dy: slopeRise)
    }

    private func attemptMove(dx: Int, dy: Int) {
        let next = LevelFiftyNinePoint(x: position.x + dx, y: position.y + dy)
        guard (-6...6).contains(next.x), (-6...6).contains(next.y) else {
            reject(reset: true)
            return
        }
        guard accepts(next) else {
            reject(reset: true)
            return
        }

        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            position = next
            visited.append(next)
            if routeIndex + 1 < currentStage.route.count, next == currentStage.route[routeIndex + 1] {
                routeIndex += 1
            }
            wrongPulse = false
        }

        if next == currentStage.target {
            advancing = true
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                self.advance()
            }
        }
    }

    func resetStage() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            position = LevelFiftyNinePoint(x: 0, y: 0)
            visited = [position]
            routeIndex = 0
            wrongPulse = false
            advancing = false
        }
    }

    private func accepts(_ next: LevelFiftyNinePoint) -> Bool {
        guard routeIndex + 1 < currentStage.route.count else { return false }
        let start = currentStage.route[routeIndex]
        let end = currentStage.route[routeIndex + 1]
        return point(next, isBetween: start, and: end) && isCloser(next, to: end, than: position)
    }

    private func point(_ point: LevelFiftyNinePoint, isBetween start: LevelFiftyNinePoint, and end: LevelFiftyNinePoint) -> Bool {
        let segmentX = end.x - start.x
        let segmentY = end.y - start.y
        let pointX = point.x - start.x
        let pointY = point.y - start.y

        guard segmentX * pointY == segmentY * pointX else { return false }
        return min(start.x, end.x) <= point.x && point.x <= max(start.x, end.x)
            && min(start.y, end.y) <= point.y && point.y <= max(start.y, end.y)
    }

    private func isCloser(_ next: LevelFiftyNinePoint, to end: LevelFiftyNinePoint, than current: LevelFiftyNinePoint) -> Bool {
        squaredDistance(next, end) < squaredDistance(current, end)
    }

    private func squaredDistance(_ first: LevelFiftyNinePoint, _ second: LevelFiftyNinePoint) -> Int {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return dx * dx + dy * dy
    }

    private func adjustSlope(_ update: () -> Void) {
        guard !completed, !advancing else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            update()
            wrongPulse = false
        }
    }

    private func advance() {
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                completed = true
            }
        } else {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                stageIndex += 1
                position = LevelFiftyNinePoint(x: 0, y: 0)
                visited = [position]
                routeIndex = 0
                wrongPulse = false
                advancing = false
            }
        }
    }

    private func reject(reset: Bool = false) {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.44)) {
            wrongPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                if reset {
                    self.position = LevelFiftyNinePoint(x: 0, y: 0)
                    self.visited = [self.position]
                    self.routeIndex = 0
                }
                self.wrongPulse = false
            }
        }
    }

    private func clamp(_ value: Int, min lower: Int, max upper: Int) -> Int {
        Swift.min(Swift.max(value, lower), upper)
    }
}

struct MathItLevelFiftyNineView: View {
    var viewModel: MathItLevelFiftyNineViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSize = min(size.width - 40, min(size.height * 0.52, 420))
            let boardRect = CGRect(
                x: (size.width - boardSize) / 2,
                y: size.height * 0.22,
                width: boardSize,
                height: boardSize
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                navigatorBoard(rect: boardRect)

                controls(size: size, board: boardRect)

                Button(action: viewModel.resetStage) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.45), radius: 12)
                }
                .buttonStyle(.plain)
                .position(x: boardRect.maxX - 14, y: boardRect.maxY + 36)

                CompletionOverlay(
                    title: "Level 59 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.garamond(min(31, size.width * 0.068)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            Text(targetText)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(viewModel.wrongPulse ? .red.opacity(0.92) : accent)
                .shadow(color: viewModel.wrongPulse ? .red.opacity(0.44) : accent.opacity(0.34), radius: 8)

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 100)
    }

    private var targetText: String {
        "trace \(viewModel.currentStage.name)"
    }

    private func navigatorBoard(rect: CGRect) -> some View {
        let localRect = CGRect(origin: .zero, size: rect.size)

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.wrongPulse ? Color.red.opacity(0.8) : .white.opacity(0.18), lineWidth: viewModel.wrongPulse ? 2 : 1.2)
                .background(.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 8))

            coordinateGrid(rect: localRect)

            dottedRoute(in: localRect)

            travelPath(in: localRect)

            targetBeacon(in: localRect)

            currentMarker(in: localRect)

            coordinateReadout(rect: localRect)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .offset(x: viewModel.wrongPulse ? -7 : 0)
        .animation(.linear(duration: 0.06).repeatCount(5, autoreverses: true), value: viewModel.wrongPulse)
    }

    private func coordinateGrid(rect: CGRect) -> some View {
        let unit = rect.width / 12

        return ZStack {
            ForEach(0...12, id: \.self) { index in
                let position = CGFloat(index) * unit

                Path { path in
                    path.move(to: CGPoint(x: position, y: 0))
                    path.addLine(to: CGPoint(x: position, y: rect.height))
                }
                .stroke(.white.opacity(index == 6 ? 0.58 : 0.12), lineWidth: index == 6 ? 1.7 : 0.8)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: position))
                    path.addLine(to: CGPoint(x: rect.width, y: position))
                }
                .stroke(.white.opacity(index == 6 ? 0.58 : 0.12), lineWidth: index == 6 ? 1.7 : 0.8)
            }
        }
    }

    private func travelPath(in rect: CGRect) -> some View {
        Path { path in
            guard let first = viewModel.visited.first else { return }
            path.move(to: screenPoint(for: first, in: rect))
            for point in viewModel.visited.dropFirst() {
                path.addLine(to: screenPoint(for: point, in: rect))
            }
        }
        .stroke(accent.opacity(0.76), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        .shadow(color: accent.opacity(0.44), radius: 9)
    }

    private func dottedRoute(in rect: CGRect) -> some View {
        designPath(in: rect)
        .stroke(.white.opacity(0.48), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [2, 8]))
        .shadow(color: .white.opacity(0.22), radius: 6)
    }

    private func designPath(in rect: CGRect) -> Path {
        switch viewModel.currentStage.name {
        case "triangle":
            return path(points: [
                LevelFiftyNinePoint(x: -3, y: 0),
                LevelFiftyNinePoint(x: 0, y: 5),
                LevelFiftyNinePoint(x: 3, y: 0),
                LevelFiftyNinePoint(x: -3, y: 0)
            ], in: rect)
        case "pentagon":
            return path(points: [
                LevelFiftyNinePoint(x: -2, y: 0),
                LevelFiftyNinePoint(x: -3, y: 3),
                LevelFiftyNinePoint(x: 0, y: 5),
                LevelFiftyNinePoint(x: 3, y: 3),
                LevelFiftyNinePoint(x: 2, y: 0),
                LevelFiftyNinePoint(x: -2, y: 0)
            ], in: rect)
        default:
            return path(points: viewModel.currentStage.route, in: rect)
        }
    }

    private func path(points: [LevelFiftyNinePoint], in rect: CGRect) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: screenPoint(for: first, in: rect))
            for point in points.dropFirst() {
                path.addLine(to: screenPoint(for: point, in: rect))
            }
        }
    }

    private func targetBeacon(in rect: CGRect) -> some View {
        let point = screenPoint(for: viewModel.activeTarget, in: rect)

        return ZStack {
            Circle()
                .stroke(.white.opacity(0.86), lineWidth: 2.2)
                .frame(width: 32, height: 32)
            Circle()
                .stroke(accent.opacity(0.58), lineWidth: 6)
                .frame(width: 42, height: 42)
                .blur(radius: 3)
        }
        .position(point)
    }

    private func currentMarker(in rect: CGRect) -> some View {
        let point = screenPoint(for: viewModel.position, in: rect)

        return Circle()
            .fill(.white)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(accent, lineWidth: 2))
            .shadow(color: .white.opacity(0.6), radius: 12)
            .position(point)
    }

    private func coordinateReadout(rect: CGRect) -> some View {
        Text("(\(viewModel.position.x), \(viewModel.position.y))")
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.66), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.5), lineWidth: 1.2))
            .shadow(color: accent.opacity(0.24), radius: 8)
            .position(x: rect.midX, y: rect.maxY - 28)
    }

    private func controls(size: CGSize, board: CGRect) -> some View {
        HStack(spacing: 20) {
            arrowPad
            slopePanel
        }
            .position(x: size.width / 2, y: min(size.height - 92, board.maxY + 120))
    }

    private var arrowPad: some View {
        VStack(spacing: 8) {
            padButton(systemName: "chevron.up") {
                viewModel.move(dx: 0, dy: 1)
            }

            HStack(spacing: 8) {
                padButton(systemName: "chevron.left") {
                    viewModel.move(dx: -1, dy: 0)
                }

                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 1.3)
                    .frame(width: 46, height: 46)

                padButton(systemName: "chevron.right") {
                    viewModel.move(dx: 1, dy: 0)
                }
            }

            padButton(systemName: "chevron.down") {
                viewModel.move(dx: 0, dy: -1)
            }
        }
    }

    private func padButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 46, height: 46)
                .background(accent, in: Circle())
                .shadow(color: accent.opacity(0.38), radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.advancing || viewModel.completed)
    }

    private var slopePanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                slopeStepper(title: "rise", value: viewModel.slopeRise, action: viewModel.adjustRise)
                slopeStepper(title: "run", value: viewModel.slopeRun, action: viewModel.adjustRun)
            }

            Button(action: viewModel.launchSlope) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 92, height: 34)
                    .background(accent, in: Capsule())
                    .shadow(color: accent.opacity(0.36), radius: 10)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.advancing || viewModel.completed)
        }
    }

    private func slopeStepper(title: String, value: Int, action: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))

            HStack(spacing: 5) {
                miniButton(systemName: "minus") { action(-1) }
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 28)
                miniButton(systemName: "plus") { action(1) }
            }
        }
        .frame(width: 92, height: 50)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func miniButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(accent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.advancing || viewModel.completed)
    }

    private func screenPoint(for point: LevelFiftyNinePoint, in rect: CGRect) -> CGPoint {
        let unit = rect.width / 12
        return CGPoint(
            x: rect.midX + CGFloat(point.x) * unit,
            y: rect.midY - CGFloat(point.y) * unit
        )
    }
}
