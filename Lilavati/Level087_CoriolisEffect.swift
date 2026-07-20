import SwiftUI
import Combine

// MARK: - Level 6 · The Rotating World (Coriolis effect, 3 stages)
//
// You stand on a spinning platform in space with a cannon fixed to the rim.
// The ball ALWAYS flies in a perfectly straight line through world space — but
// the whole scene is drawn in the platform's rotating frame, so the platform,
// cannon and targets stay put while the starfield wheels around you and the
// ball appears to curve. To hit a target you must aim ahead of it.
//   Stage 1: no spin — the ball goes straight.
//   Stage 2: slow spin — lead the target.
//   Stage 3: fast spin, several targets.
// Finishing plays a short lesson: the same effect steers winds, hurricanes and
// long-range trajectories because the Earth turns beneath them.

enum RWBallPhase { case waiting, flying, done }

@Observable
final class MathItLevelSixViewModel {
    var stageIndex = 0
    let stageCount = 3

    var theta: CGFloat = 0          // platform rotation; render everything at -theta
    var omega: CGFloat = 0          // spin rate (rad/s) for the current stage

    var targets: [CGPoint] = []     // platform-frame target positions
    var hit: Set<Int> = []

    var ballPhase: RWBallPhase = .waiting
    var ballWorld = CGPoint.zero
    var ballVel = CGSize.zero

    var aiming = false
    var aimVec = CGSize.zero        // platform-frame vector from cannon to finger

    var completed = false

    // Geometry (set on configure).
    private(set) var configured = false
    var center = CGPoint.zero
    var radius: CGFloat = 120
    var cannon = CGPoint.zero       // platform-frame cannon position (on the rim)
    var stars: [CGPoint] = []       // world-fixed background points

    private let omegas: [CGFloat] = [0, 0.55, 0.95]
    private let hitFrac: CGFloat = 0.12

    var spinning: Bool { omega != 0 }

    func configure(size: CGSize) {
        guard !configured else { return }
        configured = true
        center = CGPoint(x: size.width / 2, y: size.height * 0.44)
        radius = min(size.width * 0.40, size.height * 0.30)
        cannon = CGPoint(x: center.x, y: center.y + radius)   // bottom of the rim

        // World-fixed stars scattered around the platform.
        var pts: [CGPoint] = []
        let reach = max(size.width, size.height)
        for _ in 0..<70 {
            let a = CGFloat.random(in: 0..<(2 * .pi))
            let d = CGFloat.random(in: radius * 0.2...reach * 0.75)
            pts.append(CGPoint(x: center.x + cos(a) * d, y: center.y + sin(a) * d))
        }
        stars = pts
        loadStage(0)
    }

    func loadStage(_ i: Int) {
        stageIndex = i
        omega = omegas[min(i, omegas.count - 1)]
        theta = 0
        hit = []
        ballPhase = .waiting
        aiming = false
        aimVec = .zero
        targets = stageTargets(i)
    }

    private func stageTargets(_ i: Int) -> [CGPoint] {
        func at(_ angle: CGFloat, _ frac: CGFloat) -> CGPoint {
            CGPoint(x: center.x + cos(angle) * radius * frac,
                    y: center.y + sin(angle) * radius * frac)
        }
        let up = -CGFloat.pi / 2
        switch i {
        case 0:  return [at(up, 0.68)]
        case 1:  return [at(up - 0.55, 0.72)]
        default: return [at(up, 0.74), at(up - 1.15, 0.6), at(up + 1.15, 0.6)]
        }
    }

    var hitRadius: CGFloat { radius * hitFrac }

    // MARK: Aiming + firing

    func aim(to finger: CGPoint) {
        guard ballPhase == .waiting, !completed else { return }
        aiming = true
        aimVec = CGSize(width: finger.x - cannon.x, height: finger.y - cannon.y)
    }

    func release() {
        guard aiming, ballPhase == .waiting, !completed else { aiming = false; return }
        aiming = false
        let len = max(hypot(aimVec.width, aimVec.height), 1)
        let power = min(max(len / radius, 0.2), 1)
        let speed = (0.9 + power * 1.9) * radius          // px/s
        let dir = CGVector(dx: aimVec.width / len, dy: aimVec.height / len)

        // Convert the platform-frame aim into a world-space velocity, and place
        // the ball at the cannon's CURRENT world position.
        let worldDir = rotVec(dir, theta)
        ballVel = CGSize(width: worldDir.dx * speed, height: worldDir.dy * speed)
        ballWorld = rotPoint(cannon, around: center, by: theta)
        ballPhase = .flying
        HapticPlayer.playLightTap()
    }

    /// Ball position as it appears on screen (rotating frame).
    var ballScreen: CGPoint {
        ballPhase == .flying ? rotPoint(ballWorld, around: center, by: -theta) : cannon
    }

    // MARK: Simulation

    func tick(dt: CGFloat) {
        guard configured, !completed, ballPhase != .done else { return }
        theta += omega * dt

        guard ballPhase == .flying else { return }
        ballWorld.x += ballVel.width * dt
        ballWorld.y += ballVel.height * dt
        let screen = rotPoint(ballWorld, around: center, by: -theta)

        for idx in targets.indices where !hit.contains(idx) {
            if hypot(screen.x - targets[idx].x, screen.y - targets[idx].y) < hitRadius {
                hitTarget(idx)
                return
            }
        }
        if hypot(screen.x - center.x, screen.y - center.y) > radius * 1.15 {
            ballPhase = .waiting          // flew off the platform → try again
            HapticPlayer.playLightTap()
        }
    }

    private func hitTarget(_ idx: Int) {
        hit.insert(idx)
        HapticPlayer.playCompletionTap()
        if hit.count == targets.count {
            stageCleared()
        } else {
            ballPhase = .waiting          // reload for the remaining targets
        }
    }

    private func stageCleared() {
        ballPhase = .done
        if stageIndex == stageCount - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { self.completed = true }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.4)) { self.loadStage(self.stageIndex + 1) }
            }
        }
    }

}

// MARK: - Rotation helpers

private func rotPoint(_ p: CGPoint, around c: CGPoint, by a: CGFloat) -> CGPoint {
    let dx = p.x - c.x, dy = p.y - c.y
    return CGPoint(x: c.x + dx * cos(a) - dy * sin(a),
                   y: c.y + dx * sin(a) + dy * cos(a))
}

private func rotVec(_ v: CGVector, _ a: CGFloat) -> CGVector {
    CGVector(dx: v.dx * cos(a) - v.dy * sin(a), dy: v.dx * sin(a) + v.dy * cos(a))
}

// MARK: - View

struct MathItLevelSixView: View {
    var viewModel: MathItLevelSixViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let gold = Color.mathGold
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let vm = viewModel

            ZStack {
                Color.black.ignoresSafeArea()

                // Starfield (world-fixed → wheels around in the rotating frame).
                Canvas { ctx, _ in
                    guard vm.configured else { return }
                    for s in vm.stars {
                        let p = rotPoint(s, around: vm.center, by: -vm.theta)
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.1, y: p.y - 1.1, width: 2.2, height: 2.2)),
                                 with: .color(.white.opacity(0.5)))
                    }
                }
                .allowsHitTesting(false)

                platform(size: size)

                ForEach(vm.targets.indices, id: \.self) { i in
                    targetView(at: vm.targets[i], hit: vm.hit.contains(i))
                }

                if vm.ballPhase == .waiting && vm.aiming {
                    aimLine()
                }

                cannonView()
                if vm.ballPhase != .done {
                    Circle()
                        .fill(.white)
                        .frame(width: 15, height: 15)
                        .shadow(color: .white.opacity(0.7), radius: 8)
                        .position(vm.ballScreen)
                }

                // Aim gesture surface.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { vm.aim(to: $0.location) }
                            .onEnded { _ in vm.release() }
                    )
                    .allowsHitTesting(vm.ballPhase == .waiting && !vm.completed)

                HomeButton(action: onLevelSelect).position(x: 34, y: 54).zIndex(20)

                CompletionOverlay(
                    title: "Coriolis Effect",
                    isVisible: vm.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(40)
            }
            .onAppear { vm.configure(size: size) }
            .onReceive(timer) { _ in vm.tick(dt: 1.0 / 60.0) }
        }
    }

    // MARK: Pieces

    private func platform(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                                     center: .center, startRadius: 0, endRadius: viewModel.radius))
                .frame(width: viewModel.radius * 2, height: viewModel.radius * 2)
            Circle()
                .stroke(gold.opacity(0.5), lineWidth: 2)
                .frame(width: viewModel.radius * 2, height: viewModel.radius * 2)
            Circle().fill(gold.opacity(0.5)).frame(width: 6, height: 6)
            if viewModel.spinning {
                spinArrow()
            }
        }
        .position(viewModel.center)
    }

    // Curved arrow near the rim showing the platform's spin direction.
    private func spinArrow() -> some View {
        let r = viewModel.radius * 0.9
        return Path { p in
            p.addArc(center: .init(x: viewModel.radius, y: viewModel.radius), radius: r,
                     startAngle: .degrees(-60), endAngle: .degrees(30), clockwise: false)
        }
        .stroke(gold.opacity(0.45), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: viewModel.radius * 2, height: viewModel.radius * 2)
    }

    private func targetView(at p: CGPoint, hit: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(hit ? gold : .white.opacity(0.7),
                        style: StrokeStyle(lineWidth: 2, dash: hit ? [] : [3, 3]))
                .frame(width: viewModel.hitRadius * 2, height: viewModel.hitRadius * 2)
            Circle()
                .fill(hit ? gold : .white.opacity(0.35))
                .frame(width: 7, height: 7)
        }
        .shadow(color: hit ? gold.opacity(0.6) : .clear, radius: 10)
        .position(p)
    }

    private func aimLine() -> some View {
        let c = viewModel.cannon
        let v = viewModel.aimVec
        let len = max(hypot(v.width, v.height), 1)
        let show = min(len, viewModel.radius)
        let end = CGPoint(x: c.x + v.width / len * show, y: c.y + v.height / len * show)
        return Path { p in p.move(to: c); p.addLine(to: end) }
            .stroke(gold.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
    }

    private func cannonView() -> some View {
        Circle()
            .fill(gold)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
            .shadow(color: gold.opacity(0.6), radius: 8)
            .position(viewModel.cannon)
    }

}
