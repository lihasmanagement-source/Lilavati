import SwiftUI

struct MathItLevelOneHundredElevenView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var angle = 42.0
    @State private var power = 36.0
    @State private var enemyHealth = 3
    @State private var playerHealth = 3
    @State private var stageIndex = 0
    @State private var shots: [TankShot] = []
    @State private var livePath: [CGPoint] = []
    @State private var liveProgress: Double?
    @State private var liveShotOwner = TankShotOwner.player
    @State private var enemyTurn = false
    @State private var restartingAfterDefeat = false
    @State private var solved = false
    @State private var battlefield = TankBattlefield.initial
    @State private var battleID = UUID()

    private let gold = Color(red: 0.93, green: 0.78, blue: 0.40)
    private let gravity = 9.8

    private var playerBase: CGPoint { battlefield.playerBase }
    private var enemyBase: CGPoint { battlefield.enemyBase }
    private var playerMuzzle: CGPoint { CGPoint(x: playerBase.x, y: playerBase.y + 4) }
    private var enemyMuzzle: CGPoint { CGPoint(x: enemyBase.x, y: enemyBase.y + 4) }
    private var enemyRect: CGRect { CGRect(x: enemyBase.x - 4.2, y: enemyBase.y, width: 8.4, height: 5.8) }

    private var equation: String {
        let radians = angle * .pi / 180
        let cosValue = max(0.08, cos(radians))
        let a = -gravity / (2 * power * power * cosValue * cosValue)
        let b = tan(radians)
        return String(format: "y = %.3f(x - %.0f)² + %.3f(x - %.0f) + %.0f", a, playerMuzzle.x, b, playerMuzzle.x, playerMuzzle.y)
    }

    private var predictedPath: [CGPoint] {
        trajectory(angle: angle, power: power)
    }

    private var liveProjectile: CGPoint? {
        guard let liveProgress, !livePath.isEmpty else { return nil }
        let index = min(Int(liveProgress * Double(livePath.count - 1)), livePath.count - 1)
        return livePath[index]
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let field = CGRect(x: 16, y: max(98, size.height * 0.15), width: size.width - 32, height: min(520, size.height * 0.58))
            let scale = TankScale(field: field, xMax: battlefield.xMax, yMax: battlefield.yMax)

            ZStack {
                LinearGradient(colors: [.black, Color(red: 0.02, green: 0.03, blue: 0.12)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)
                    .zIndex(20)

                battlefieldView(field: field, scale: scale)

                controls
                    .frame(width: min(size.width - 30, 420))
                    .position(x: size.width / 2, y: min(size.height - 96, field.maxY + 106))

                CompletionOverlay(
                    title: "Parabola Locked",
                    isVisible: solved,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .environment(\.mathItAccent, gold)
        }
    }

    private func battlefieldView(field: CGRect, scale: TankScale) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.15), .black], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.12), lineWidth: 1.2))
                .frame(width: field.width, height: field.height)
                .position(x: field.midX, y: field.midY)

            coordinatePlane(scale: scale)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            tower(scale: scale)

            ForEach(shots) { shot in
                path(for: shot.points, scale: scale)
                    .stroke(
                        shot.owner == .player
                            ? (shot.hit ? gold.opacity(0.95) : .white.opacity(0.28))
                            : Color.red.opacity(0.72),
                        style: StrokeStyle(lineWidth: shot.hit ? 3 : 2, lineCap: .round, dash: shot.hit ? [] : [5, 6])
                    )
            }

            path(for: predictedPath, scale: scale)
                .stroke(gold.opacity(liveProgress == nil ? 0.62 : 0.25), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [7, 7]))

            tank(at: playerBase, color: .white, barrelAngle: -angle, scale: scale)
            tank(at: enemyBase, color: gold, barrelAngle: 222, scale: scale)

            if let liveProjectile {
                Circle()
                    .fill(liveShotOwner == .player ? Color.white : Color.red)
                    .frame(width: 13, height: 13)
                    .shadow(color: (liveShotOwner == .player ? gold : .red).opacity(0.95), radius: 12)
                    .position(scale.point(liveProjectile))
            }

            HStack {
                healthHearts(remaining: playerHealth, color: .white)
                Spacer()
                healthHearts(remaining: enemyHealth, color: gold)
            }
            .frame(width: field.width - 42)
            .position(x: field.midX, y: field.minY + 50)

            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= stageIndex ? gold : .white.opacity(0.18))
                        .frame(width: index == stageIndex ? 22 : 8, height: 4)
                }
            }
            .position(x: field.midX, y: field.minY + 51)
        }
    }

    private func healthHearts(remaining: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < remaining ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(index < remaining ? color : .white.opacity(0.18))
                    .shadow(color: index < remaining ? color.opacity(0.55) : .clear, radius: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.52), in: Capsule())
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Text(equation)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(gold)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity, minHeight: 36)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))

            HStack(spacing: 10) {
                stepper(icon: "angle", value: "\(Int(angle))°", minus: { angle = max(12, angle - 1) }, plus: { angle = min(78, angle + 1) })
                stepper(icon: "speedometer", value: "\(Int(power))", minus: { power = max(18, power - 1) }, plus: { power = min(58, power + 1) })
            }

            Button(action: fire) {
                Image(systemName: liveProgress == nil && !enemyTurn ? "scope" : "hourglass")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(liveProgress == nil && !enemyTurn ? .black : .white.opacity(0.42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 49)
                    .background(RoundedRectangle(cornerRadius: 14).fill(liveProgress == nil && !enemyTurn ? gold : Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(liveProgress != nil || enemyTurn || restartingAfterDefeat || solved)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.80)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func stepper(icon: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(gold).frame(width: 23)
            Button(action: minus) { Image(systemName: "minus").frame(width: 30, height: 30) }
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 50)
            Button(action: plus) { Image(systemName: "plus").frame(width: 30, height: 30) }
        }
        .font(.system(size: 13, weight: .black))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 13).fill(.white.opacity(0.075)))
    }

    private func fire() {
        guard liveProgress == nil, !enemyTurn, !restartingAfterDefeat, !solved else { return }
        let points = predictedPath
        let hit = points.contains { enemyRect.insetBy(dx: -1.6, dy: -1.4).contains($0) }
        HapticPlayer.playLightTap()

        animateShot(points: points, owner: .player, hit: hit) {
            if hit {
                enemyHealth = max(0, enemyHealth - 1)
                HapticPlayer.playCompletionTap()
                if enemyHealth == 0 {
                    solved = true
                } else {
                    stageIndex += 1
                    advanceBattlefield()
                }
            } else {
                enemyReturnFire()
            }
        }
    }

    private func animateShot(
        points: [CGPoint],
        owner: TankShotOwner,
        hit: Bool,
        completion: @escaping () -> Void
    ) {
        let token = battleID
        liveShotOwner = owner
        livePath = points
        liveProgress = 0
        let frames = 72
        let duration = 1.45
        for frame in 1...frames {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(frame) / Double(frames)) {
                guard battleID == token else { return }
                liveProgress = Double(frame) / Double(frames)
                if frame == frames {
                    shots.append(TankShot(points: points, hit: hit, owner: owner))
                    liveProgress = nil
                    livePath = []
                    completion()
                }
            }
        }
    }

    private func enemyReturnFire() {
        guard playerHealth > 0, !restartingAfterDefeat, !solved else { return }
        enemyTurn = true
        let token = battleID

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            guard battleID == token, enemyTurn, !solved else { return }
            animateShot(points: enemyTrajectory(), owner: .enemy, hit: true) {
                playerHealth = max(0, playerHealth - 1)
                HapticPlayer.playLightTap()

                if playerHealth == 0 {
                    restartAfterDefeat()
                } else {
                    enemyTurn = false
                }
            }
        }
    }

    private func restartAfterDefeat() {
        guard !restartingAfterDefeat else { return }
        restartingAfterDefeat = true
        enemyTurn = false
        let token = battleID

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard battleID == token, restartingAfterDefeat else { return }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                reset()
            }
        }
    }

    private func reset() {
        battleID = UUID()
        angle = 42
        power = 36
        enemyHealth = 3
        playerHealth = 3
        stageIndex = 0
        shots = []
        livePath = []
        liveProgress = nil
        liveShotOwner = .player
        enemyTurn = false
        restartingAfterDefeat = false
        solved = false
        battlefield = .initial
    }

    private func advanceBattlefield() {
        shots = []
        battlefield = .random()
    }

    private func enemyTrajectory() -> [CGPoint] {
        let distance = max(1, enemyMuzzle.x - playerMuzzle.x)
        let towerDistance = min(distance - 0.1, max(0.1, enemyMuzzle.x - battlefield.tower.midX))
        let clearanceDenominator = max(0.1, towerDistance * (1 - towerDistance / distance))
        let requiredTangent = max(0, battlefield.tower.maxY + 4 - enemyMuzzle.y) / clearanceDenominator
        let launchAngle = min(78.0 * .pi / 180, max(48.0 * .pi / 180, atan(requiredTangent)))
        let speed = sqrt(gravity * distance / max(0.1, sin(2 * launchAngle)))
        let horizontalSpeed = speed * cos(launchAngle)
        let verticalSpeed = speed * sin(launchAngle)
        let flightTime = distance / horizontalSpeed

        return (0...90).map { index in
            let time = flightTime * Double(index) / 90
            return CGPoint(
                x: enemyMuzzle.x - horizontalSpeed * time,
                y: max(0, enemyMuzzle.y + verticalSpeed * time - 0.5 * gravity * time * time)
            )
        }
    }

    private func trajectory(angle: Double, power: Double) -> [CGPoint] {
        let radians = angle * .pi / 180
        var vx = max(0.1, power * cos(radians))
        var vy = power * sin(radians)
        var position = playerMuzzle
        var points: [CGPoint] = [position]
        var bounces = 0
        let dt = 0.055

        for step in 1...170 {
            vy -= gravity * dt
            var next = CGPoint(x: position.x + vx * dt, y: position.y + vy * dt)

            if bounces < 2, battlefield.tower.insetBy(dx: 0.25, dy: 0.25).contains(next) {
                bounces += 1
                if position.y >= battlefield.tower.maxY - 0.25 && vy < 0 {
                    next.y = battlefield.tower.maxY + 0.35
                    vy = abs(vy) * 0.66
                } else {
                    next.x = battlefield.tower.minX - 0.35
                    vx = -abs(vx) * 0.74
                    vy *= 0.88
                }
            }

            if next.x < -2 || next.x > battlefield.xMax + 2 { break }
            if next.y < 0 && step > 4 {
                points.append(CGPoint(x: next.x, y: 0))
                break
            }
            position = CGPoint(x: next.x, y: max(0, next.y))
            points.append(position)
        }
        return points
    }

    private func coordinatePlane(scale: TankScale) -> some View {
        ZStack {
            Path { path in
                for x in stride(from: 0.0, through: battlefield.xMax, by: 10) {
                    path.move(to: scale.point(CGPoint(x: x, y: 0)))
                    path.addLine(to: scale.point(CGPoint(x: x, y: battlefield.yMax)))
                }
                for y in stride(from: 0.0, through: battlefield.yMax, by: 10) {
                    path.move(to: scale.point(CGPoint(x: 0, y: y)))
                    path.addLine(to: scale.point(CGPoint(x: battlefield.xMax, y: y)))
                }
            }
            .stroke(.white.opacity(0.10), lineWidth: 1)

            Path { path in
                path.move(to: scale.point(CGPoint(x: 0, y: 0)))
                path.addLine(to: scale.point(CGPoint(x: battlefield.xMax, y: 0)))
                path.move(to: scale.point(CGPoint(x: 0, y: 0)))
                path.addLine(to: scale.point(CGPoint(x: 0, y: battlefield.yMax)))
            }
            .stroke(.white.opacity(0.46), lineWidth: 2)

            ForEach(axisMarks(max: battlefield.xMax, step: 20), id: \.self) { x in
                let point = scale.point(CGPoint(x: x, y: 0))
                Text("\(Int(x))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.54))
                    .position(x: point.x, y: point.y + 13)
            }

            ForEach(axisMarks(max: battlefield.yMax, step: 10).filter { $0 > 0 }, id: \.self) { y in
                let point = scale.point(CGPoint(x: 0, y: y))
                Text("\(Int(y))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.54))
                    .position(x: point.x - 14, y: point.y)
            }
        }
    }

    private func tower(scale: TankScale) -> some View {
        let rect = scale.rect(battlefield.tower)
        return RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(colors: [Color(red: 0.38, green: 0.47, blue: 0.48), Color(red: 0.17, green: 0.24, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.16), lineWidth: 1))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func tank(at world: CGPoint, color: Color, barrelAngle: Double, scale: TankScale) -> some View {
        let base = scale.point(world)
        return ZStack {
            Capsule().fill(color).frame(width: 34, height: 10).position(x: base.x, y: base.y - 7)
            RoundedRectangle(cornerRadius: 5).fill(color.opacity(0.82)).frame(width: 21, height: 10).position(x: base.x, y: base.y - 15)
            Capsule().fill(color).frame(width: 29, height: 4).rotationEffect(.degrees(barrelAngle)).position(x: base.x + (barrelAngle < 0 ? 17 : -17), y: base.y - 23)
        }
        .shadow(color: color.opacity(0.55), radius: 7)
    }

    private func path(for points: [CGPoint], scale: TankScale) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let screen = scale.point(point)
            if index == 0 { path.move(to: screen) } else { path.addLine(to: screen) }
        }
        return path
    }

    private func axisMarks(max: Double, step: Double) -> [Double] {
        var marks = Array(stride(from: 0.0, through: max, by: step))
        if let last = marks.last, abs(last - max) > 0.1 { marks.append(max) }
        return marks
    }
}

private struct TankShot: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let hit: Bool
    let owner: TankShotOwner
}

private enum TankShotOwner {
    case player
    case enemy
}

private struct TankBattlefield {
    let xMax: Double
    let yMax: Double
    let playerBase: CGPoint
    let enemyBase: CGPoint
    let tower: CGRect

    static let initial = TankBattlefield(
        xMax: 100,
        yMax: 60,
        playerBase: CGPoint(x: 10, y: 0),
        enemyBase: CGPoint(x: 90, y: 0),
        tower: CGRect(x: 45.2, y: 0, width: 9.6, height: 33)
    )

    static func random() -> TankBattlefield {
        let xMax = Double.random(in: 92...142).rounded()
        let yMax = Double.random(in: 56...82).rounded()
        let playerX = Double.random(in: 8...18).rounded()
        let enemyX = (xMax - Double.random(in: 12...24)).rounded()
        let towerWidth = Double.random(in: 8...14)
        let towerHeight = Double.random(in: 22...min(56, yMax - 8)).rounded()
        let center = Double.random(in: (xMax * 0.42)...(xMax * 0.58))
        let towerX = min(max(center - towerWidth / 2, playerX + 18), enemyX - 24)
        return TankBattlefield(
            xMax: xMax,
            yMax: yMax,
            playerBase: CGPoint(x: playerX, y: 0),
            enemyBase: CGPoint(x: enemyX, y: 0),
            tower: CGRect(x: towerX, y: 0, width: towerWidth, height: towerHeight)
        )
    }
}

private struct TankScale {
    let field: CGRect
    let xMax: Double
    let yMax: Double

    private var unit: CGFloat {
        min((field.width - 56) / CGFloat(xMax), (field.height - 112) / CGFloat(yMax))
    }

    private var origin: CGPoint {
        CGPoint(
            x: field.midX - unit * CGFloat(xMax) / 2,
            y: field.midY + unit * CGFloat(yMax) / 2 + 18
        )
    }

    func point(_ point: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + point.x * unit, y: origin.y - point.y * unit)
    }

    func rect(_ rect: CGRect) -> CGRect {
        let topLeft = point(CGPoint(x: rect.minX, y: rect.maxY))
        let bottomRight = point(CGPoint(x: rect.maxX, y: rect.minY))
        return CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
    }
}

#Preview {
    MathItLevelOneHundredElevenView(onContinue: {}, onLevelSelect: {})
}
