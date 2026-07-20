import SwiftUI
import Combine

// MARK: - Unit Circle Defense

private struct UnitCircleAngle: Identifiable, Hashable {
    let degrees: Int
    let radians: String

    var id: Int { degrees }

    static let standard: [UnitCircleAngle] = [
        UnitCircleAngle(degrees: 0, radians: "0"),
        UnitCircleAngle(degrees: 30, radians: "π/6"),
        UnitCircleAngle(degrees: 45, radians: "π/4"),
        UnitCircleAngle(degrees: 60, radians: "π/3"),
        UnitCircleAngle(degrees: 90, radians: "π/2"),
        UnitCircleAngle(degrees: 120, radians: "2π/3"),
        UnitCircleAngle(degrees: 135, radians: "3π/4"),
        UnitCircleAngle(degrees: 150, radians: "5π/6"),
        UnitCircleAngle(degrees: 180, radians: "π"),
        UnitCircleAngle(degrees: 210, radians: "7π/6"),
        UnitCircleAngle(degrees: 225, radians: "5π/4"),
        UnitCircleAngle(degrees: 240, radians: "4π/3"),
        UnitCircleAngle(degrees: 270, radians: "3π/2"),
        UnitCircleAngle(degrees: 300, radians: "5π/3"),
        UnitCircleAngle(degrees: 315, radians: "7π/4"),
        UnitCircleAngle(degrees: 330, radians: "11π/6")
    ]

    static func nearest(to degrees: Double) -> UnitCircleAngle {
        standard.min {
            circularDistance(from: Double($0.degrees), to: degrees)
                < circularDistance(from: Double($1.degrees), to: degrees)
        } ?? standard[0]
    }

    private static func circularDistance(from lhs: Double, to rhs: Double) -> Double {
        let difference = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }
}

private struct UnitCircleEnemy: Identifiable {
    let id: Int
    let angle: UnitCircleAngle
    let speed: CGFloat
    var progress: CGFloat
}

@Observable
private final class UnitCircleDefenseViewModel {
    private struct WaveEntry {
        let degrees: Int
        let speed: CGFloat
    }

    private let wave: [WaveEntry] = [
        WaveEntry(degrees: 30, speed: 0.078),
        WaveEntry(degrees: 135, speed: 0.082),
        WaveEntry(degrees: 240, speed: 0.086),
        WaveEntry(degrees: 330, speed: 0.090),
        WaveEntry(degrees: 60, speed: 0.094)
    ]

    let maximumLives = 3
    let maximumActiveTargets = 2
    var lives = 3
    var enemies: [UnitCircleEnemy] = []
    var defeated = 0
    var resolved = 0
    var selectedAngle: UnitCircleAngle?
    var feedback = "ANGLE GRID ONLINE"
    var feedbackPositive = true
    var shotVisible = false
    var shotAngle = UnitCircleAngle.standard[0]
    var shotProgress: CGFloat = 0
    var shotWasCorrect = true
    var triangleVisible = false
    var explosionVisible = false
    var explosionAngle = UnitCircleAngle.standard[0]
    var explosionProgress: CGFloat = 0
    var running = false
    var gameOver = false
    var completed = false

    private var nextWaveIndex = 0
    private var nextEnemyID = 0
    private var nextSpawnDelay: TimeInterval = 0
    private var lastUpdate: Date?
    private var shotLocked = false
    private var sessionID = UUID()

    var targetCount: Int { wave.count }

    var progress: Double {
        completed ? 1 : Double(resolved) / Double(max(1, targetCount))
    }

    func reset() {
        sessionID = UUID()
        lives = maximumLives
        enemies = []
        defeated = 0
        resolved = 0
        selectedAngle = nil
        feedback = "ANGLE GRID ONLINE"
        feedbackPositive = true
        shotVisible = false
        triangleVisible = false
        explosionVisible = false
        running = false
        gameOver = false
        completed = false
        nextWaveIndex = 0
        nextEnemyID = 0
        nextSpawnDelay = 0
        lastUpdate = nil
        shotLocked = false
    }

    func start(at date: Date = Date()) {
        guard !running, !gameOver, !completed else { return }
        running = true
        lastUpdate = date
        if enemies.isEmpty, nextWaveIndex < wave.count, !shotLocked {
            spawnEnemy()
        }
    }

    func pause() {
        running = false
        lastUpdate = nil
    }

    func update(at date: Date) {
        guard running, !gameOver, !completed else {
            lastUpdate = date
            return
        }

        let delta = min(max(date.timeIntervalSince(lastUpdate ?? date), 0), 0.12)
        lastUpdate = date

        guard !shotLocked else { return }

        if nextWaveIndex < wave.count, enemies.count < maximumActiveTargets {
            nextSpawnDelay -= delta
            if nextSpawnDelay <= 0 {
                spawnEnemy()
            }
        }

        var advancingEnemies = enemies
        for index in advancingEnemies.indices {
            advancingEnemies[index].progress += CGFloat(delta) * advancingEnemies[index].speed
        }
        enemies = advancingEnemies

        let breachedIDs = Set(enemies.filter { $0.progress >= 1 }.map(\.id))
        if !breachedIDs.isEmpty {
            enemies.removeAll { breachedIDs.contains($0.id) }
            resolved += breachedIDs.count
            feedback = breachedIDs.count == 1 ? "CENTER BREACHED" : "DOUBLE BREACH"
            feedbackPositive = false
            loseLives(breachedIDs.count)
            nextSpawnDelay = 0.9
        }

        finishWaveIfNeeded()
    }

    func fire(_ angle: UnitCircleAngle) {
        guard running, !shotLocked, !enemies.isEmpty else { return }
        let token = sessionID
        let target = enemies.first { $0.angle.degrees == angle.degrees }
        let isCorrect = target != nil

        shotLocked = true
        selectedAngle = angle
        shotAngle = angle
        shotProgress = target?.progress ?? 0.08
        shotWasCorrect = isCorrect
        triangleVisible = false
        withAnimation(.easeOut(duration: 0.12)) {
            shotVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            guard self.sessionID == token, !self.gameOver else { return }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                self.triangleVisible = true
            }
        }

        if let target {
            feedback = "θ = \(angle.degrees)° = \(angle.radians)"
            feedbackPositive = true
            explosionAngle = angle
            explosionProgress = target.progress

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                guard self.sessionID == token, !self.gameOver else { return }
                self.enemies.removeAll { $0.id == target.id }
                self.defeated += 1
                self.resolved += 1
                withAnimation(.spring(response: 0.24, dampingFraction: 0.55)) {
                    self.explosionVisible = true
                }
                HapticPlayer.playCompletionTap()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
                guard self.sessionID == token, !self.gameOver else { return }
                self.clearShot()
                self.nextSpawnDelay = 0.75
                self.finishWaveIfNeeded()
            }
        } else {
            feedback = "WRONG RAY · θ = \(angle.degrees)°"
            feedbackPositive = false
            HapticPlayer.playLightTap()
            loseLives(1)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                guard self.sessionID == token, !self.gameOver else { return }
                self.clearShot()
            }
        }
    }

    private func spawnEnemy() {
        guard running,
              enemies.count < maximumActiveTargets,
              nextWaveIndex < wave.count else { return }
        let entry = wave[nextWaveIndex]
        guard let angle = UnitCircleAngle.standard.first(where: { $0.degrees == entry.degrees }) else { return }
        guard !enemies.contains(where: { $0.angle.degrees == angle.degrees }) else {
            nextSpawnDelay = 0.5
            return
        }

        enemies.append(
            UnitCircleEnemy(
                id: nextEnemyID,
                angle: angle,
                speed: entry.speed,
                progress: 0
            )
        )
        feedback = enemies.count == maximumActiveTargets
            ? "TWO DIRECTIONS ACTIVE"
            : "TARGET \(nextWaveIndex + 1) INBOUND"
        feedbackPositive = true
        nextEnemyID += 1
        nextWaveIndex += 1
        nextSpawnDelay = 2.6
    }

    private func clearShot() {
        withAnimation(.easeIn(duration: 0.16)) {
            shotVisible = false
            triangleVisible = false
            explosionVisible = false
            selectedAngle = nil
        }
        shotLocked = false
    }

    private func loseLives(_ count: Int) {
        lives = max(0, lives - count)
        guard lives == 0 else { return }

        let token = sessionID
        running = false
        enemies = []
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            gameOver = true
        }

        // A life loss is never level completion. Briefly show the final empty
        // heart, then restart the full defense wave automatically.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            guard self.sessionID == token, self.gameOver, !self.completed else { return }
            self.reset()
            self.start()
        }
    }

    private func finishWaveIfNeeded() {
        guard running,
              nextWaveIndex == wave.count,
              enemies.isEmpty,
              !shotLocked,
              lives > 0 else { return }

        running = false
        let token = sessionID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard self.sessionID == token, !self.gameOver else { return }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }
}

struct MathItLevelOneHundredThirteenView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var viewModel = UnitCircleDefenseViewModel()
    @State private var clock = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private let accent = Color.mathItGeometry
    private let danger = Color(red: 1.00, green: 0.28, blue: 0.34)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSide = min(size.width - 10, min(size.height * 0.62, 440))
            let boardCenterY = size.height * 0.43

            ZStack {
                defenseBackground

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)
                    .zIndex(30)

                header(size: size)

                UnitCircleDefenseBoard(viewModel: viewModel)
                    .frame(width: boardSide, height: boardSide)
                    .position(x: size.width / 2, y: boardCenterY)

                angleReadout
                    .frame(width: min(size.width - 44, 350), height: 54)
                    .position(
                        x: size.width / 2,
                        y: min(size.height - 60, boardCenterY + boardSide * 0.55)
                    )

                if viewModel.gameOver {
                    gameOverOverlay(size: size)
                        .zIndex(50)
                }

                CompletionOverlay(
                    title: "Circle Secured",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: replay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(100)
            }
            .environment(\.mathItAccent, accent)
        }
        .onAppear { viewModel.start() }
        .onReceive(clock) { viewModel.update(at: $0) }
        .onDisappear { viewModel.pause() }
    }

    private var defenseBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.08, blue: 0.12),
                    Color.black,
                    Color(red: 0.10, green: 0.025, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.82)
            .ignoresSafeArea()

            Canvas { context, size in
                let spacing: CGFloat = 28
                var grid = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(grid, with: .color(accent.opacity(0.045)), lineWidth: 0.7)
            }
            .ignoresSafeArea()
        }
    }

    private func header(size: CGSize) -> some View {
        ZStack {
            VStack(spacing: 4) {
                ProgressView(value: viewModel.progress)
                    .tint(accent)
                    .frame(width: min(size.width - 164, 226))
            }
            .position(x: size.width / 2, y: 69)

            HStack(spacing: 5) {
                ForEach(0..<viewModel.maximumLives, id: \.self) { index in
                    ZStack {
                        Image(systemName: "heart")
                            .foregroundStyle(.white.opacity(0.23))

                        if index < viewModel.lives {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(danger)
                                .shadow(color: danger.opacity(0.72), radius: 5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 21, height: 22)
                    .accessibilityLabel(index < viewModel.lives ? "Life remaining" : "Life lost")
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: viewModel.lives)
            .frame(width: 82, alignment: .trailing)
            .position(x: size.width - 53, y: 52)

            Text("\(viewModel.resolved) / \(viewModel.targetCount)")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent.opacity(0.8))
                .position(x: size.width - 53, y: 79)
        }
    }

    private var angleReadout: some View {
        VStack(spacing: 5) {
            if let angle = viewModel.selectedAngle {
                Text("θ = \(angle.degrees)°  =  \(angle.radians)")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(viewModel.feedbackPositive ? accent : danger)
            } else {
                Text(viewModel.feedback)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(viewModel.feedbackPositive ? accent.opacity(0.82) : danger)
            }

            Text("(cos θ, sin θ)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private func gameOverOverlay(size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.76).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(danger)

                Text("CENTER BREACHED")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(viewModel.defeated) targets cleared")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(accent)
                    .symbolEffect(.rotate)

                Text("RESTARTING")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(accent.opacity(0.82))
            }
            .frame(width: min(size.width - 64, 290), height: 220)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.06, green: 0.07, blue: 0.09)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(danger.opacity(0.5), lineWidth: 1))
        }
    }

    private func replay() {
        viewModel.reset()
        viewModel.start()
    }
}

private struct UnitCircleDefenseBoard: View {
    var viewModel: UnitCircleDefenseViewModel

    private let danger = Color(red: 1.00, green: 0.28, blue: 0.34)
    private let rayColor = Color.mathItGeometry
    private let sineColor = Color(red: 0.38, green: 0.90, blue: 0.57)
    private let cosineColor = Color(red: 0.27, green: 0.76, blue: 1.00)
    private let angleColor = Color.mathGold

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let extent = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let unitRadius = extent * 0.335
            let spawnRadius = extent * 0.455

            ZStack {
                circleCanvas(size: size, center: center, radius: unitRadius, spawnRadius: spawnRadius)

                if viewModel.shotVisible {
                    let end = point(
                        center: center,
                        distance: spawnRadius * max(0.2, 1 - viewModel.shotProgress),
                        angle: viewModel.shotAngle
                    )
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: end)
                    }
                    .stroke(
                        viewModel.shotWasCorrect ? angleColor : danger,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .shadow(color: (viewModel.shotWasCorrect ? angleColor : danger).opacity(0.9), radius: 10)
                }

                if viewModel.explosionVisible {
                    let explosionPoint = point(
                        center: center,
                        distance: spawnRadius * max(0.2, 1 - viewModel.explosionProgress),
                        angle: viewModel.explosionAngle
                    )
                    ZStack {
                        Circle().stroke(.white.opacity(0.9), lineWidth: 2).frame(width: 26, height: 26)
                        Circle().stroke(angleColor, lineWidth: 3).frame(width: 48, height: 48)
                    }
                    .shadow(color: angleColor, radius: 12)
                    .position(explosionPoint)
                    .transition(.scale.combined(with: .opacity))
                }

                ForEach(viewModel.enemies) { enemy in
                    let enemyPoint = point(
                        center: center,
                        distance: spawnRadius * max(0, 1 - enemy.progress),
                        angle: enemy.angle
                    )
                    enemyView(enemy)
                        .position(enemyPoint)
                }

                ZStack {
                    Circle().fill(Color.black)
                    Circle().stroke(rayColor, lineWidth: 2)
                    Circle().fill(rayColor).frame(width: 7, height: 7)
                }
                .frame(width: 23, height: 23)
                .shadow(color: rayColor.opacity(0.8), radius: 8)
                .position(center)
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        fireRay(at: value.location, center: center, radius: unitRadius)
                    }
            )
        }
        .accessibilityLabel("Interactive unit circle")
        .accessibilityHint("Tap the angle ray carrying the incoming target")
    }

    private func circleCanvas(
        size: CGSize,
        center: CGPoint,
        radius: CGFloat,
        spawnRadius: CGFloat
    ) -> some View {
        Canvas { context, _ in
            let selected = viewModel.selectedAngle

            if let selected, viewModel.triangleVisible {
                drawTriangle(context: &context, center: center, radius: radius, angle: selected)
            }

            for angle in UnitCircleAngle.standard {
                let end = point(center: center, distance: radius, angle: angle)
                var spoke = Path()
                spoke.move(to: center)
                spoke.addLine(to: end)
                context.stroke(
                    spoke,
                    with: .color(selected == angle ? angleColor.opacity(0.95) : .white.opacity(0.15)),
                    style: StrokeStyle(
                        lineWidth: selected == angle ? 3.2 : 0.8,
                        lineCap: .round
                    )
                )
            }

            var axes = Path()
            axes.move(to: CGPoint(x: center.x - radius - 15, y: center.y))
            axes.addLine(to: CGPoint(x: center.x + radius + 15, y: center.y))
            axes.move(to: CGPoint(x: center.x, y: center.y - radius - 15))
            axes.addLine(to: CGPoint(x: center.x, y: center.y + radius + 15))
            context.stroke(axes, with: .color(.white.opacity(0.46)), lineWidth: 1.1)

            let unitCircle = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.stroke(unitCircle, with: .color(.white.opacity(0.88)), lineWidth: 2.4)

            for angle in UnitCircleAngle.standard {
                let labelPoint = point(center: center, distance: radius * 0.72, angle: angle)
                let selectedLabel = selected == angle
                context.draw(
                    Text("\(angle.degrees)°")
                        .font(.system(size: selectedLabel ? 9.2 : 7.7, weight: selectedLabel ? .black : .semibold, design: .serif))
                        .foregroundColor(selectedLabel ? angleColor : .white.opacity(0.72)),
                    at: CGPoint(x: labelPoint.x, y: labelPoint.y - 4)
                )
                context.draw(
                    Text(angle.radians)
                        .font(.system(size: selectedLabel ? 8.5 : 7.2, weight: selectedLabel ? .black : .semibold, design: .serif))
                        .foregroundColor(selectedLabel ? angleColor : .white.opacity(0.62)),
                    at: CGPoint(x: labelPoint.x, y: labelPoint.y + 4)
                )
            }

            drawCardinalLabels(context: &context, center: center, radius: radius)

            if let selected {
                let theta = Double(selected.degrees) * .pi / 180
                let labelDistance = radius * 0.24
                let thetaPoint = CGPoint(
                    x: center.x + CGFloat(cos(theta / 2)) * labelDistance,
                    y: center.y - CGFloat(sin(theta / 2)) * labelDistance
                )
                context.draw(
                    Text("θ")
                        .font(.system(size: 11, weight: .black, design: .serif))
                        .foregroundColor(angleColor),
                    at: thetaPoint
                )

                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius * 0.18,
                    startAngle: .degrees(0),
                    endAngle: .degrees(-Double(selected.degrees)),
                    clockwise: true
                )
                context.stroke(arc, with: .color(angleColor.opacity(0.9)), lineWidth: 1.8)
            }

            for enemy in viewModel.enemies {
                let guideEnd = point(center: center, distance: spawnRadius, angle: enemy.angle)
                var guide = Path()
                guide.move(to: point(center: center, distance: radius, angle: enemy.angle))
                guide.addLine(to: guideEnd)
                context.stroke(
                    guide,
                    with: .color(danger.opacity(0.28)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                )
            }
        }
    }

    private func drawTriangle(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        angle: UnitCircleAngle
    ) {
        let circlePoint = point(center: center, distance: radius * 0.90, angle: angle)
        let projection = CGPoint(x: circlePoint.x, y: center.y)

        var fill = Path()
        fill.move(to: center)
        fill.addLine(to: projection)
        fill.addLine(to: circlePoint)
        fill.closeSubpath()
        context.fill(fill, with: .color(angleColor.opacity(0.10)))

        drawLine(context: &context, from: center, to: projection, color: cosineColor, width: 3.2)
        drawLine(context: &context, from: projection, to: circlePoint, color: sineColor, width: 3.2)
        drawLine(context: &context, from: center, to: circlePoint, color: angleColor, width: 3.4)

        context.draw(
            Text("cos θ")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(cosineColor),
            at: CGPoint(x: (center.x + projection.x) / 2, y: center.y + 11)
        )
        context.draw(
            Text("sin θ")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(sineColor),
            at: CGPoint(x: projection.x + (circlePoint.x >= center.x ? 19 : -19), y: (center.y + circlePoint.y) / 2)
        )
    }

    private func drawCardinalLabels(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let labels: [(String, CGPoint)] = [
            ("(1, 0)", CGPoint(x: center.x + radius + 23, y: center.y)),
            ("(0, 1)", CGPoint(x: center.x, y: center.y - radius - 19)),
            ("(-1, 0)", CGPoint(x: center.x - radius - 25, y: center.y)),
            ("(0, -1)", CGPoint(x: center.x, y: center.y + radius + 19))
        ]

        for label in labels {
            context.draw(
                Text(label.0)
                    .font(.system(size: 8.5, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.88)),
                at: label.1
            )
        }
    }

    private func drawLine(
        context: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        color: Color,
        width: CGFloat
    ) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func point(center: CGPoint, distance: CGFloat, angle: UnitCircleAngle) -> CGPoint {
        let radians = Double(angle.degrees) * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * distance,
            y: center.y - CGFloat(sin(radians)) * distance
        )
    }

    private func fireRay(at location: CGPoint, center: CGPoint, radius: CGFloat) {
        let dx = location.x - center.x
        let dy = center.y - location.y
        let distance = hypot(dx, dy)
        guard distance > radius * 0.18 else { return }

        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        viewModel.fire(UnitCircleAngle.nearest(to: degrees))
    }

    private func enemyView(_ enemy: UnitCircleEnemy) -> some View {
        ZStack {
            Circle()
                .stroke(danger.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .frame(width: 48, height: 48)
                .shadow(color: danger.opacity(0.7), radius: 7)

            Circle()
                .fill(Color(red: 0.16, green: 0.025, blue: 0.04))
                .overlay(Circle().stroke(danger, lineWidth: 2.2))

            Image(systemName: "scope")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: 37, height: 37)
        .shadow(color: danger.opacity(0.72), radius: 9)
        .accessibilityLabel("Incoming target on the \(enemy.angle.degrees) degree ray")
    }
}
