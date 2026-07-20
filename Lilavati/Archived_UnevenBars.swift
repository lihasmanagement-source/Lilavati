import SwiftUI
import Combine

// MARK: - Level 95 · Uneven Bars (interactive · gymnastics)
//
// Inspired by Hasbro's "Fantastic Gymnastics" + uneven-bars gymnastics: pump a
// giant swing on the HIGH bar, RELEASE to fly across and catch the LOW bar, swing
// again, then dismount and land on your feet. On a bar the gymnast is a body
// pivoting at the hands (a pendulum, kept inside the screen); in the air it is a
// free body whose spin you trim by TUCKing — pulling in shrinks the moment of
// inertia so it rotates faster (L = Iω conserved).

struct MathItLevelNinetyFiveView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        HighBarView(onContinue: onContinue, onLevelSelect: onLevelSelect)
            .environment(\.mathItAccent, GB.accent)
    }
}

// MARK: - Palette

private enum GB {
    static let bg     = Color(red: 0.03, green: 0.04, blue: 0.09)
    static let bgLow  = Color(red: 0.07, green: 0.06, blue: 0.13)
    static let accent = Color(red: 0.98, green: 0.78, blue: 0.32)
    static let body   = Color(red: 0.62, green: 0.82, blue: 1.0)
    static let bar    = Color(red: 0.85, green: 0.88, blue: 0.95)
    static let bar2   = Color(red: 0.70, green: 0.80, blue: 0.55)
    static let mat    = Color(red: 0.30, green: 0.55, blue: 0.85)
    static let good   = Color(red: 0.40, green: 0.92, blue: 0.55)
    static let bad    = Color(red: 0.96, green: 0.38, blue: 0.36)
}

private enum GBPhase { case highSwing, flight1, lowSwing, flight2, result }

// MARK: - View

private struct HighBarView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var size: CGSize = .zero
    @State private var phase: GBPhase = .highSwing

    // Swing (pendulum about the current bar).
    @State private var theta = 0.35
    @State private var omega = 0.9
    @State private var lowSwingRadius: CGFloat = 0

    // Flight (free body).
    @State private var com = CGPoint.zero
    @State private var vel = CGVector.zero
    @State private var phi = 0.0
    @State private var spinBase = 0.0
    @State private var tuck = false
    @State private var catchProgress = 0.0
    @State private var catchStartCom = CGPoint.zero
    @State private var catchStartPhi = 0.0
    @State private var catchTargetTheta = 0.0
    @State private var catchTargetOmega = 0.0
    @State private var catchTargetRadius: CGFloat = 0

    @State private var success = false
    @State private var resultMsg = ""
    @State private var completed = false

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let dt = 1.0 / 60.0
    private let swingG = 10.0
    private let omegaMax = 7.5
    private let catchDuration = 0.34

    // Geometry (kept so both swing circles fit fully on screen).
    private var barHigh: CGPoint { CGPoint(x: size.width * 0.36, y: size.height * 0.22) }
    private var barLow: CGPoint { CGPoint(x: size.width * 0.66, y: size.height * 0.46) }
    private var rCom: CGFloat { min(size.width, size.height) * 0.19 }
    private var activeRadius: CGFloat { phase == .lowSwing ? max(1, lowSwingRadius) : rCom }
    private var landY: CGFloat { size.height * 0.86 }
    private var gPx: Double { Double(size.height) * 2.0 }
    private var pivot: CGPoint { phase == .lowSwing ? barLow : barHigh }
    private var isSwing: Bool { phase == .highSwing || phase == .lowSwing }
    private var isCatchingLowBar: Bool { catchProgress > 0 && catchProgress < 1 }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height

            ZStack(alignment: .top) {
                LinearGradient(colors: [GB.bgLow, GB.bg], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

                VStack(spacing: 0) {
                    header.padding(.horizontal, 24).padding(.top, 56).padding(.bottom, 2)
                    Text(hint)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24).frame(height: 30)
                    stage.frame(maxWidth: .infinity).frame(height: h * 0.66)
                    Spacer(minLength: 0)
                }

                if isSwing {
                    Button(action: release) {
                        Text("RELEASE")
                            .font(.system(size: 18, weight: .heavy, design: .rounded)).tracking(2)
                            .foregroundStyle(.black)
                            .frame(width: 200, height: 54)
                            .background(Capsule().fill(GB.accent))
                            .shadow(color: GB.accent.opacity(0.5), radius: 10)
                    }
                    .buttonStyle(.plain)
                    .position(x: w / 2, y: h - 66)
                    .zIndex(10)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                CompletionOverlay(title: "Stuck the Dismount", isVisible: completed,
                                  onContinue: onContinue, onReplay: fullReset, onLevelSelect: onLevelSelect)
                    .zIndex(500)
            }
            .onReceive(tick) { _ in step() }
        }
    }

    private var header: some View {
        Text("UNEVEN BARS")
            .font(.trajan(30)).tracking(5)
            .foregroundStyle(GB.accent.opacity(0.95))
            .lineLimit(1).minimumScaleFactor(0.6)
            .padding(.horizontal, 24)
    }

    private var hint: String {
        switch phase {
        case .highSwing: return "Pump the swing, then RELEASE to fly to the low bar."
        case .flight1:   return "Hold to tuck — reach and catch the low bar!"
        case .lowSwing:  return "Pump again, then RELEASE to dismount."
        case .flight2:   return "Hold to tuck — land on your feet!"
        case .result:    return success ? "Sticks it!" : resultMsg
        }
    }

    // MARK: Stage

    private var stage: some View {
        GeometryReader { geo in
            Canvas { ctx, _ in draw(&ctx, geo.size) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if phase == .flight1 || phase == .flight2 { tuck = true } }
                        .onEnded { _ in
                            if phase == .flight1 || phase == .flight2 { tuck = false }
                            else if isSwing { pump() }
                        }
                )
                .onAppear { size = geo.size }
                .onChange(of: geo.size) { _, s in size = s }
        }
    }

    // MARK: Simulation

    private func step() {
        guard size != .zero else { return }
        if isCatchingLowBar {
            advanceCatchTransition()
            return
        }

        switch phase {
        case .highSwing, .lowSwing:
            omega += -swingG * sin(theta) * dt
            omega *= 0.9995
            theta += omega * dt
        case .flight1, .flight2:
            vel.dy += CGFloat(gPx) * CGFloat(dt)
            com.x += vel.dx * CGFloat(dt)
            com.y += vel.dy * CGFloat(dt)
            phi += spinBase * (tuck ? 1.9 : 1.0) * dt
            clampToScreen()
            if phase == .flight1 {
                if tryCatchLowBar() { return }
                if com.y >= landY { miss("Missed the bar — try again.") }
            } else {
                if com.y >= landY {
                    if landingPlatformContains(com.x) {
                        land()
                    } else {
                        miss("Missed the mat — try again.")
                    }
                }
            }
        case .result:
            break
        }
    }

    private func clampToScreen() {
        let m: CGFloat = 10
        if com.x < m { com.x = m; vel.dx = abs(vel.dx) }
        if com.x > size.width - m { com.x = size.width - m; vel.dx = -abs(vel.dx) }
        if com.y < 6 { com.y = 6; vel.dy = abs(vel.dy) }
    }

    private func pump() {
        guard isSwing else { return }
        let dir: Double = abs(omega) < 0.4 ? 1 : (omega > 0 ? 1 : -1)
        omega = max(-omegaMax, min(omegaMax, omega + dir * 1.2))
        HapticPlayer.playLightTap()
    }

    private func release() {
        guard isSwing else { return }
        let p = pivot
        let radius = activeRadius
        com = CGPoint(x: p.x + radius * CGFloat(sin(theta)), y: p.y + radius * CGFloat(cos(theta)))
        vel = CGVector(dx: radius * CGFloat(omega) * CGFloat(cos(theta)),
                       dy: -radius * CGFloat(omega) * CGFloat(sin(theta)))
        phi = theta
        spinBase = omega
        tuck = false
        phase = (phase == .highSwing) ? .flight1 : .flight2
        HapticPlayer.playLightTap()
    }

    // Grab the low bar if the body swings within reach of it.
    private func tryCatchLowBar() -> Bool {
        let dx = com.x - barLow.x, dy = com.y - barLow.y
        let dist = hypot(dx, dy)
        guard dist <= rCom * 1.72, dist > rCom * 0.46 else { return false }
        let incomingTheta = atan2(Double(dx), Double(dy))                  // (sinθ, cosθ) = direction to body
        let tang = CGVector(dx: cos(incomingTheta), dy: -sin(incomingTheta))
        catchTargetRadius = dist
        catchTargetTheta = incomingTheta
        catchTargetOmega = max(-omegaMax, min(omegaMax, Double((vel.dx * tang.dx + vel.dy * tang.dy) / max(dist, 1))))
        catchStartCom = com
        catchStartPhi = phi
        catchProgress = 0.001
        tuck = false
        HapticPlayer.playCompletionTap()
        return true
    }

    private func advanceCatchTransition() {
        catchProgress = min(1, catchProgress + dt / catchDuration)
        let smooth = catchProgress * catchProgress * (3 - 2 * catchProgress)
        let carriedTheta = catchTargetTheta + catchTargetOmega * catchDuration * smooth * 0.72
        let orbitPoint = CGPoint(
            x: barLow.x + catchTargetRadius * CGFloat(sin(carriedTheta)),
            y: barLow.y + catchTargetRadius * CGFloat(cos(carriedTheta))
        )
        com = CGPoint(
            x: catchStartCom.x + (orbitPoint.x - catchStartCom.x) * CGFloat(smooth),
            y: catchStartCom.y + (orbitPoint.y - catchStartCom.y) * CGFloat(smooth)
        )
        phi = catchStartPhi + (carriedTheta - catchStartPhi) * smooth

        guard catchProgress >= 1 else { return }
        lowSwingRadius = catchTargetRadius
        theta = carriedTheta
        omega = catchTargetOmega
        spinBase = catchTargetOmega
        phase = .lowSwing
        catchProgress = 0
    }

    private func land() {
        com.y = landY
        vel = .zero
        let twoPi = 2 * Double.pi
        var fm = phi.truncatingRemainder(dividingBy: twoPi)
        if fm > Double.pi { fm -= twoPi }
        if fm < -Double.pi { fm += twoPi }
        success = abs(fm) < 0.95
        resultMsg = "Rotate to land feet-first — try again."
        phase = .result
        if success {
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { completed = true }
            }
        } else {
            HapticPlayer.playLightTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { fullReset() }
        }
    }

    private func miss(_ msg: String) {
        success = false
        resultMsg = msg
        phase = .result
        HapticPlayer.playLightTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { fullReset() }
    }

    private func landingPlatformContains(_ x: CGFloat) -> Bool {
        let pad: CGFloat = size.width * 0.04
        return (size.width * 0.10 - pad)...(size.width * 0.90 + pad) ~= x
    }

    private func fullReset() {
        completed = false; success = false
        theta = 0.35; omega = 0.9
        lowSwingRadius = 0
        catchProgress = 0
        catchTargetRadius = 0
        tuck = false
        phase = .highSwing
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ sz: CGSize) {
        let w = sz.width, h = sz.height

        // Mat.
        let matH = h * 0.05
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.10, y: landY, width: w * 0.80, height: matH), cornerRadius: 6),
                 with: .color(GB.mat.opacity(0.85)))
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.10, y: landY, width: w * 0.80, height: matH * 0.4), cornerRadius: 6),
                 with: .color(GB.mat))

        drawBar(&ctx, barLow, color: GB.bar2, half: w * 0.20)
        drawBar(&ctx, barHigh, color: GB.bar, half: w * 0.20)

        // Low-bar catch ring while flying toward it.
        if phase == .flight1 {
            let r = rCom * 1.72
            ctx.stroke(Path(ellipseIn: CGRect(x: barLow.x - r, y: barLow.y - r, width: r * 2, height: r * 2)),
                       with: .color(GB.good.opacity(0.35)), style: StrokeStyle(lineWidth: 2, dash: [5, 6]))
        }

        // Swing circle guide.
        if isSwing {
            let p = pivot
            let radius = activeRadius
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                       with: .color(.white.opacity(0.07)), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            drawReleaseHints(&ctx, sz)
            let comPt = CGPoint(x: p.x + radius * CGFloat(sin(theta)), y: p.y + radius * CGFloat(cos(theta)))
            drawGymnast(&ctx, sz, com: comPt, phi: theta, tuck: 0, grip: p)

            let frac = min(1, abs(omega) / omegaMax)
            let mw = w * 0.4
            ctx.fill(Path(roundedRect: CGRect(x: w / 2 - mw / 2, y: h * 0.02, width: mw, height: 6), cornerRadius: 3),
                     with: .color(.white.opacity(0.12)))
            ctx.fill(Path(roundedRect: CGRect(x: w / 2 - mw / 2, y: h * 0.02, width: mw * CGFloat(frac), height: 6), cornerRadius: 3),
                     with: .color(GB.accent))
        } else {
            drawGymnast(&ctx, sz, com: com, phi: phi, tuck: tuck ? 1 : 0, grip: isCatchingLowBar ? barLow : nil)
            if !isCatchingLowBar {
                drawOrientationGauge(&ctx, sz)
            }
        }

        if phase == .result {
            let label = success ? "STICK!" : "FALL"
            let col = success ? GB.good : GB.bad
            ctx.draw(Text(label).font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundColor(col),
                     at: CGPoint(x: w / 2, y: h * 0.14))
        }
    }

    private func drawBar(_ ctx: inout GraphicsContext, _ bp: CGPoint, color: Color, half: CGFloat) {
        for sx in [-1.0, 1.0] {
            var post = Path()
            post.move(to: CGPoint(x: bp.x + CGFloat(sx) * half, y: bp.y))
            post.addLine(to: CGPoint(x: bp.x + CGFloat(sx) * half, y: landY))
            ctx.stroke(post, with: .color(color.opacity(0.3)), lineWidth: 4)
        }
        var barPath = Path()
        barPath.move(to: CGPoint(x: bp.x - half, y: bp.y))
        barPath.addLine(to: CGPoint(x: bp.x + half, y: bp.y))
        ctx.stroke(barPath, with: .color(color), lineWidth: 5)
    }

    private func drawOrientationGauge(_ ctx: inout GraphicsContext, _ sz: CGSize) {
        let c = CGPoint(x: sz.width - 44, y: 40), r: CGFloat = 22
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .color(.white.opacity(0.18)), lineWidth: 2)
        var zone = Path()
        zone.addArc(center: c, radius: r, startAngle: .radians(.pi / 2 - 0.6), endAngle: .radians(.pi / 2 + 0.6), clockwise: false)
        ctx.stroke(zone, with: .color(GB.good.opacity(0.7)), lineWidth: 3)
        let m = CGPoint(x: c.x + CGFloat(sin(phi)) * r, y: c.y + CGFloat(cos(phi)) * r)
        ctx.fill(Path(ellipseIn: CGRect(x: m.x - 4, y: m.y - 4, width: 8, height: 8)), with: .color(GB.body))
    }

    private func drawReleaseHints(_ ctx: inout GraphicsContext, _ sz: CGSize) {
        switch phase {
        case .highSwing:
            drawReleaseHint(&ctx, pivot: barHigh, radius: rCom, angle: 1.12, labelDot: barLow, color: GB.good)
        case .lowSwing:
            drawReleaseHint(&ctx, pivot: barLow, radius: activeRadius, angle: -0.78, labelDot: CGPoint(x: size.width * 0.73, y: landY), color: GB.accent)
        default:
            break
        }
    }

    private func drawReleaseHint(
        _ ctx: inout GraphicsContext,
        pivot: CGPoint,
        radius: CGFloat,
        angle: Double,
        labelDot: CGPoint,
        color: Color
    ) {
        let ghost = CGPoint(
            x: pivot.x + radius * CGFloat(sin(angle)),
            y: pivot.y + radius * CGFloat(cos(angle))
        )
        let hintRadius: CGFloat = 16
        var path = Path()
        path.addEllipse(in: CGRect(x: ghost.x - hintRadius, y: ghost.y - hintRadius, width: hintRadius * 2, height: hintRadius * 2))
        ctx.stroke(path, with: .color(color.opacity(0.42)), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

        var target = Path()
        target.addEllipse(in: CGRect(x: labelDot.x - hintRadius, y: labelDot.y - hintRadius, width: hintRadius * 2, height: hintRadius * 2))
        ctx.stroke(target, with: .color(color.opacity(0.36)), style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
    }

    private func drawGymnast(_ ctx: inout GraphicsContext, _ sz: CGSize, com: CGPoint, phi: Double, tuck: Double, grip: CGPoint?) {
        let h = sz.height
        let u = CGVector(dx: sin(phi), dy: cos(phi))
        let p = CGVector(dx: cos(phi), dy: -sin(phi))
        let sideSign: CGFloat = cos(phi) >= 0 ? 1 : -1
        func pt(_ along: CGFloat, _ side: CGFloat) -> CGPoint {
            CGPoint(x: com.x + u.dx * along + p.dx * side, y: com.y + u.dy * along + p.dy * side)
        }
        func line(_ a: CGPoint, _ b: CGPoint, _ lw: CGFloat, _ col: Color) {
            var pth = Path(); pth.move(to: a); pth.addLine(to: b)
            ctx.stroke(pth, with: .color(col), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }

        let headR = h * 0.022
        let head = pt(-h * 0.085, 0)
        let shoulder = pt(-h * 0.05, 0)
        let hip = pt(h * 0.02, 0)
        let legLen = h * 0.11 * (1 - 0.55 * tuck)

        line(shoulder, hip, 6, GB.body)

        let rearKnee = CGPoint(x: hip.x + u.dx * legLen * 0.46 - p.dx * h * 0.018 * sideSign,
                               y: hip.y + u.dy * legLen * 0.46 - p.dy * h * 0.018 * sideSign)
        let rearFoot = CGPoint(x: hip.x + u.dx * legLen * 0.86 - p.dx * h * 0.028 * sideSign,
                               y: hip.y + u.dy * legLen * 0.86 - p.dy * h * 0.028 * sideSign)
        line(hip, rearKnee, 4, GB.body.opacity(0.55))
        line(rearKnee, rearFoot, 4, GB.body.opacity(0.55))

        let knee = CGPoint(x: hip.x + u.dx * legLen * 0.5 + p.dx * h * 0.018 * sideSign,
                           y: hip.y + u.dy * legLen * 0.5 + p.dy * h * 0.018 * sideSign)
        let foot = CGPoint(x: hip.x + u.dx * legLen + p.dx * h * 0.018 * sideSign,
                           y: hip.y + u.dy * legLen + p.dy * h * 0.018 * sideSign)
        line(hip, knee, 5, GB.body)
        line(knee, foot, 5, GB.body)

        if let g = grip {
            let handGap = h * 0.025
            let shoulderGap = h * 0.016
            for s in [-1.0, 1.0] {
                let shoulderSide = CGPoint(x: shoulder.x + handGap * 0.32 * CGFloat(s), y: shoulder.y + shoulderGap * CGFloat(s))
                let hand = CGPoint(x: g.x + handGap * CGFloat(s), y: g.y)
                let reach = CGVector(dx: hand.x - shoulderSide.x, dy: hand.y - shoulderSide.y)
                let reachLen = max(1, hypot(reach.dx, reach.dy))
                let perp = CGVector(dx: -reach.dy / reachLen, dy: reach.dx / reachLen)
                let elbow = CGPoint(
                    x: (shoulderSide.x + hand.x) / 2 + perp.dx * h * 0.012 * CGFloat(s),
                    y: (shoulderSide.y + hand.y) / 2 + perp.dy * h * 0.012 * CGFloat(s)
                )
                line(shoulderSide, elbow, 4, GB.accent)
                line(elbow, hand, 4, GB.accent)
                ctx.fill(Path(ellipseIn: CGRect(x: hand.x - 3.2, y: hand.y - 3.2, width: 6.4, height: 6.4)), with: .color(.white.opacity(0.9)))
            }
        } else {
            let reachForward = CGVector(dx: -u.dx * h * 0.078 + p.dx * h * 0.036 * sideSign,
                                        dy: -u.dy * h * 0.078 + p.dy * h * 0.036 * sideSign)
            let frontHand = CGPoint(x: shoulder.x + reachForward.dx, y: shoulder.y + reachForward.dy)
            let rearHand = CGPoint(x: shoulder.x + reachForward.dx * 0.82 - p.dx * h * 0.026 * sideSign,
                                   y: shoulder.y + reachForward.dy * 0.82 - p.dy * h * 0.026 * sideSign)
            line(shoulder, rearHand, 3.4, GB.accent.opacity(0.55))
            line(shoulder, frontHand, 4, GB.accent)
        }
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - headR, y: head.y - headR, width: headR * 2, height: headR * 2)),
                 with: .color(GB.body))
    }
}

#Preview {
    MathItLevelNinetyFiveView(onContinue: {}, onLevelSelect: {})
}
