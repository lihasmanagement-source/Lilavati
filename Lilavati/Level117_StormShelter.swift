import SwiftUI

struct MathItLevelEightyFiveView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void
    var body: some View {
        StormShelterView(onContinue: onContinue, onLevelSelect: onLevelSelect)
    }
}

private enum HouseState: Equatable { case unlit, lit, destroyed }

private enum GamePhase: Equatable { case intro, playing, resolving }

private struct RodPlacement: Equatable {
    var inZone: Int?   // nil = resting at scattered home
}

// MARK: - Main view

private struct StormShelterView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    // 7-item logical row [S H S H S H S]; houses at item indices 1,3,5
    private let totalItems = 7
    private func houseXFrac(_ i: Int) -> CGFloat {
        (CGFloat([1, 3, 5][i]) + 0.5) / CGFloat(totalItems)
    }

    // Timing
    private let introFill: Double = 1.5    // demo countdown
    private let playFill:  Double = 8.0    // player's time to place rods

    // Scattered rod resting spots (fractions of width / height) — deliberately
    // not in a horizontal line.
    private let rodHomeFracs: [CGPoint] = [
        CGPoint(x: 0.18, y: 0.82),
        CGPoint(x: 0.52, y: 0.90),
        CGPoint(x: 0.82, y: 0.76),
    ]

    @State private var phase: GamePhase = .intro
    @State private var houseStates   = [HouseState](repeating: .unlit, count: 3)
    @State private var shakeHouse: Int? = nil
    @State private var rods          = [RodPlacement(inZone: nil),
                                        RodPlacement(inZone: nil),
                                        RodPlacement(inZone: nil)]
    @State private var draggingIndex: Int?   = nil
    @State private var dragPos               = CGPoint.zero
    @State private var boltProgress          = [CGFloat](repeating: 0, count: 3)
    @State private var flashOpacity          = [CGFloat](repeating: 0, count: 3)
    @State private var flashScale            = [CGFloat](repeating: 0.2, count: 3)
    @State private var barProgress: CGFloat  = 0
    @State private var completed             = false
    @State private var runID                 = 0   // invalidates stale scheduled work

    // Zone: to the LEFT of each house, at ground level
    private func zoneCenter(i: Int, w: CGFloat, skyH: CGFloat) -> CGPoint {
        let cellW = w / CGFloat(totalItems)
        return CGPoint(x: w * houseXFrac(i) - cellW * 0.50, y: skyH + 46)
    }

    private func rodHome(_ ri: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        CGPoint(x: rodHomeFracs[ri].x * w, y: rodHomeFracs[ri].y * h)
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    var body: some View {
        GeometryReader { proxy in
            let w     = proxy.size.width
            let h     = proxy.size.height
            let skyH  = h * 0.50
            let rowH  = CGFloat(72)
            let zones = (0..<3).map { zoneCenter(i: $0, w: w, skyH: skyH) }

            ZStack {
                Color.black.ignoresSafeArea()

                // ── Sky ──
                SkyScene(houseXFracs: (0..<3).map { houseXFrac($0) }, width: w, height: skyH)
                    .frame(width: w, height: skyH)
                    .frame(maxHeight: .infinity, alignment: .top)

                // ── Strike bolts + flashes ──
                ForEach(0..<3, id: \.self) { i in
                    let hasRod  = rods.contains { $0.inZone == i }
                    let rodTip  = CGPoint(x: zones[i].x, y: zones[i].y - 32)
                    let endX    = hasRod ? rodTip.x : w * houseXFrac(i)
                    let endY    = hasRod ? rodTip.y : skyH

                    StrikeBolt(boltIndex: i,
                               startX: w * houseXFrac(i),
                               endX: endX,
                               endY: endY,
                               progress: boltProgress[i])
                        .frame(width: w, height: h)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)

                    Circle()
                        .fill(RadialGradient(
                            colors: [.white, Color(red: 0.6, green: 0.85, blue: 1).opacity(0)],
                            center: .center, startRadius: 0, endRadius: 40))
                        .frame(width: 80, height: 80)
                        .scaleEffect(flashScale[i])
                        .opacity(flashOpacity[i])
                        .position(x: endX, y: endY)
                        .allowsHitTesting(false)
                }

                // ── Ground strip ──
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.08, green: 0.10, blue: 0.14),
                                 Color(red: 0.03, green: 0.04, blue: 0.06)],
                        startPoint: .top, endPoint: .bottom))
                    .overlay(Rectangle()
                        .fill(Color(red: 0.28, green: 0.38, blue: 0.55).opacity(0.18))
                        .frame(height: 1), alignment: .top)
                    .frame(width: w, height: h - skyH)
                    .position(x: w / 2, y: skyH + (h - skyH) / 2)

                // ── Houses ──
                HousesRow(width: w, totalItems: totalItems,
                          houseStates: houseStates, shakeHouse: shakeHouse,
                          houseItemIndices: [1, 3, 5])
                    .frame(width: w, height: rowH)
                    .position(x: w / 2, y: skyH + rowH / 2)

                // ── Drop zones ──
                ForEach(0..<3, id: \.self) { i in
                    let occupied = rods.contains { $0.inZone == i }
                    ZoneCircle(occupied: occupied)
                        .frame(width: 32, height: 32)
                        .position(zones[i])
                }

                // ── Persistent draggable rods (scattered homes) ──
                ForEach(rods.indices, id: \.self) { ri in
                    let isDragging = draggingIndex == ri
                    let pos = rodPosition(ri: ri, zones: zones, w: w, h: h)
                    LightningRodIcon()
                        .frame(width: 26, height: 52)
                        .scaleEffect(isDragging ? 1.18 : 1)
                        .shadow(color: isDragging
                                ? Color(red: 0.36, green: 0.72, blue: 1).opacity(0.7) : .clear,
                                radius: 10)
                        .position(pos)
                        .zIndex(isDragging ? 100 : 1)
                        .animation(.spring(response: 0.30, dampingFraction: 0.74),
                                   value: rods[ri].inZone)
                        .gesture(dragGesture(ri: ri, zones: zones))
                }

                // ── Top loading bar + header ──
                VStack(spacing: 14) {
                    header
                    loadingBar(width: w - 36)
                }
                .padding(.top, 54)
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity, alignment: .top)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 85 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: { startIntro(w: w, h: h) },
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .coordinateSpace(name: "scene")
            .onAppear {
                if phase == .intro && barProgress == 0 { startIntro(w: w, h: h) }
            }
        }
    }

    // MARK: - Loading bar

    private func loadingBar(width: CGFloat) -> some View {
        let blue = Color(red: 0.30, green: 0.66, blue: 1)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.08))
                .frame(width: width, height: 10)
            Capsule()
                .fill(LinearGradient(
                    colors: [blue, Color(red: 0.55, green: 0.86, blue: 1)],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: max(0, width * barProgress), height: 10)
                .shadow(color: blue.opacity(0.85), radius: 8)
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .white.opacity(0.9), radius: 6)
                        .opacity(barProgress > 0.02 && barProgress < 0.999 ? 1 : 0)
                }
        }
        .frame(width: width, height: 12)
    }

    // MARK: - Rod position

    private func rodPosition(ri: Int, zones: [CGPoint], w: CGFloat, h: CGFloat) -> CGPoint {
        if draggingIndex == ri { return dragPos }
        if let z = rods[ri].inZone { return CGPoint(x: zones[z].x, y: zones[z].y - 12) }
        return rodHome(ri, w: w, h: h)
    }

    // MARK: - Drag gesture

    private func dragGesture(ri: Int, zones: [CGPoint]) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("scene"))
            .onChanged { val in
                guard phase == .playing else { return }
                if draggingIndex != ri {
                    draggingIndex = ri
                    rods[ri].inZone = nil  // lift out of any zone
                }
                dragPos = val.location
            }
            .onEnded { val in
                guard draggingIndex == ri else { return }
                let threshold: CGFloat = 52
                let best = zones.enumerated()
                    .filter { idx, _ in !rods.contains { $0.inZone == idx } }
                    .min { dist($0.element, val.location) < dist($1.element, val.location) }
                if let (zIdx, zPt) = best, dist(zPt, val.location) < threshold {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        rods[ri].inZone = zIdx
                    }
                }
                draggingIndex = nil
            }
    }

    // MARK: - Game flow

    /// Opening demo: the storm strikes unprotected, the houses break, then the
    /// level resets into a playable round.
    private func startIntro(w: CGFloat, h: CGFloat) {
        runID += 1
        let token = runID
        completed     = false
        phase         = .intro
        houseStates   = [.unlit, .unlit, .unlit]
        shakeHouse    = nil
        boltProgress  = [0, 0, 0]
        flashOpacity  = [0, 0, 0]
        flashScale    = [0.2, 0.2, 0.2]
        draggingIndex = nil
        for i in rods.indices { rods[i].inZone = nil }   // all rods scattered, none placed
        barProgress = 0
        withAnimation(.linear(duration: introFill)) { barProgress = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + introFill) {
            guard token == runID else { return }
            triggerStrike(token: token, isIntro: true, w: w, h: h)
        }
    }

    /// Playable round: 8-second window for the player to place rods.
    private func startPlaying(w: CGFloat, h: CGFloat) {
        runID += 1
        let token = runID
        phase        = .playing
        houseStates  = [.unlit, .unlit, .unlit]
        shakeHouse   = nil
        boltProgress = [0, 0, 0]
        flashOpacity = [0, 0, 0]
        flashScale   = [0.2, 0.2, 0.2]
        for i in rods.indices { rods[i].inZone = nil }
        barProgress = 0
        withAnimation(.linear(duration: playFill)) { barProgress = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + playFill) {
            guard token == runID else { return }
            triggerStrike(token: token, isIntro: false, w: w, h: h)
        }
    }

    private func triggerStrike(token: Int, isIntro: Bool, w: CGFloat, h: CGFloat) {
        phase = .resolving

        for i in 0..<3 {
            let delay  = Double(i) * 0.55
            let hasRod = !isIntro && rods.contains { $0.inZone == i }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard token == runID else { return }
                withAnimation(.linear(duration: 0.34)) { boltProgress[i] = 1 }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.34) {
                guard token == runID else { return }
                flashOpacity[i] = 1; flashScale[i] = 0.2
                withAnimation(.easeOut(duration: 0.5)) {
                    flashOpacity[i] = 0; flashScale[i] = 2.8
                }
                if hasRod {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                        houseStates[i] = .lit
                    }
                } else {
                    withAnimation(.spring(response: 0.10, dampingFraction: 0.25)) { shakeHouse = i }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        guard token == runID else { return }
                        shakeHouse = nil
                        withAnimation(.easeIn(duration: 0.22)) { houseStates[i] = .destroyed }
                    }
                }
            }
        }

        // Resolve the outcome after all three bolts have landed.
        let total = Double(2) * 0.55 + 0.34 + 0.5 + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            guard token == runID else { return }
            if isIntro {
                startPlaying(w: w, h: h)
            } else if houseStates.allSatisfy({ $0 == .lit }) {
                withAnimation(.easeInOut(duration: 0.4)) { completed = true }
            } else {
                // A house broke — reset and let the player try again.
                startPlaying(w: w, h: h)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            EmptyView()
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(3).foregroundStyle(.white.opacity(0.52))
            EmptyView()
                .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Houses row (only the 3 strike houses, no spots)

private struct HousesRow: View {
    let width: CGFloat
    let totalItems: Int
    let houseStates: [HouseState]
    let shakeHouse: Int?
    let houseItemIndices: [Int]

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let cellW = width / CGFloat(totalItems)
                let xFrac = (CGFloat(houseItemIndices[i]) + 0.5) / CGFloat(totalItems)
                HouseIcon(state: houseStates[i], shake: shakeHouse == i)
                    .frame(width: cellW * 0.88, height: 60)
                    .position(x: width * xFrac, y: 30)
            }
        }
    }
}

// MARK: - Drop zone circle

private struct ZoneCircle: View {
    let occupied: Bool
    var body: some View {
        Circle()
            .stroke(Color(red: 1, green: 0.82, blue: 0.20)
                        .opacity(occupied ? 0.25 : 0.80),
                    style: StrokeStyle(lineWidth: 1.8, dash: occupied ? [] : [5, 4]))
    }
}

// MARK: - Sky scene

private struct SkyScene: View {
    let houseXFracs: [CGFloat]
    let width: CGFloat
    let height: CGFloat

    private let boltDx: [[CGFloat]] = [
        [-5, 8, -10, 6, -4, 9, -6, 2],
        [ 7,-9,  12,-5,  8,-11, 6,-8],
        [-8, 6, -12, 9, -4, 11,-5, 3],
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.10, blue: 0.20).opacity(0.9), .black],
                startPoint: .top, endPoint: .bottom)
            ForEach(houseXFracs.indices, id: \.self) { i in
                decorBolt(xFrac: houseXFracs[i], dxArr: boltDx[i])
            }
        }
    }

    private func decorBolt(xFrac: CGFloat, dxArr: [CGFloat]) -> some View {
        let segH = height / CGFloat(dxArr.count)
        let path = Path { p in
            var pt = CGPoint(x: xFrac * width, y: 0)
            p.move(to: pt)
            for dx in dxArr {
                pt = CGPoint(x: pt.x + dx, y: pt.y + segH)
                p.addLine(to: pt)
            }
        }
        return ZStack {
            path.stroke(Color(red: 0.55, green: 0.78, blue: 1).opacity(0.18),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
            path.stroke(Color(red: 0.72, green: 0.90, blue: 1).opacity(0.40),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            path.stroke(.white.opacity(0.92),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Animated strike bolt

private struct StrikeBolt: View {
    let boltIndex: Int
    let startX: CGFloat   // top of bolt (sky)
    let endX: CGFloat     // strike point x (rod tip or house roof)
    let endY: CGFloat     // strike point y
    let progress: CGFloat

    // Per-bolt sideways jitter (in points) applied along the descent.
    private var jitter: [CGFloat] {
        switch boltIndex {
        case 0: return [-5, 8,-10,  6, -4,  9, -6,  0]
        case 1: return [ 7,-9, 12, -5,  8,-11,  6,  0]
        default:return [-8, 6,-12,  9, -4, 11, -5,  0]
        }
    }

    var body: some View {
        let n = jitter.count
        // Base x interpolates startX → endX; jitter[k] adds the jagged look and
        // resolves to 0 at the last vertex so the bolt lands exactly on target.
        let path = Path { p in
            p.move(to: CGPoint(x: startX, y: 0))
            for k in 0..<n {
                let t  = CGFloat(k + 1) / CGFloat(n)
                let bx = startX + (endX - startX) * t
                let y  = endY * t
                p.addLine(to: CGPoint(x: bx + jitter[k], y: y))
            }
        }
        return ZStack {
            path.trim(from: 0, to: progress)
                .stroke(Color(red: 0.5, green: 0.75, blue: 1).opacity(0.25),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
            path.trim(from: 0, to: progress)
                .stroke(Color(red: 0.68, green: 0.88, blue: 1).opacity(0.55),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            path.trim(from: 0, to: progress)
                .stroke(.white.opacity(0.96),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .animation(.linear(duration: 0.38), value: progress)
    }
}

// MARK: - House icon (3 states)

private struct HouseIcon: View {
    let state: HouseState
    let shake: Bool

    private var wallColor: Color {
        switch state {
        case .unlit:     return Color(red: 0.38, green: 0.38, blue: 0.42)
        case .lit:       return Color(red: 1.00, green: 0.72, blue: 0.10)
        case .destroyed: return Color(red: 0.22, green: 0.22, blue: 0.25)
        }
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                // Roof
                Path { p in
                    p.move(to: CGPoint(x: w*0.50, y: 0))
                    p.addLine(to: CGPoint(x: w, y: h*0.40))
                    p.addLine(to: CGPoint(x: 0, y: h*0.40))
                    p.closeSubpath()
                }
                .fill(wallColor.opacity(0.92))

                // Body
                Rectangle()
                    .fill(wallColor.opacity(0.75))
                    .frame(width: w*0.74, height: h*0.54)
                    .position(x: w/2, y: h*0.73)

                // Windows — only when lit
                if state == .lit {
                    HStack(spacing: w*0.10) {
                        windowRect(w: w*0.18, h: h*0.14)
                        windowRect(w: w*0.18, h: h*0.14)
                    }
                    .position(x: w/2, y: h*0.70)
                }

                // Crack — only when destroyed
                if state == .destroyed {
                    Path { p in
                        p.move(to: CGPoint(x: w*0.30, y: h*0.42))
                        p.addLine(to: CGPoint(x: w*0.48, y: h*0.60))
                        p.addLine(to: CGPoint(x: w*0.36, y: h*0.72))
                        p.addLine(to: CGPoint(x: w*0.54, y: h*0.95))
                    }
                    .stroke(.black.opacity(0.55), lineWidth: 1.6)
                }
            }
            .offset(x: shake ? 5 : 0)
            .animation(shake
                ? .spring(response: 0.08, dampingFraction: 0.2)
                : .spring(response: 0.18, dampingFraction: 0.6),
                value: shake)
            .shadow(color: state == .lit
                    ? Color(red: 1, green: 0.82, blue: 0.20).opacity(0.65)
                    : .clear,
                    radius: 10)
        }
    }

    private func windowRect(w: CGFloat, h: CGFloat) -> some View {
        Rectangle()
            .fill(Color(red: 1, green: 0.95, blue: 0.60).opacity(0.9))
            .frame(width: w, height: h)
            .shadow(color: Color(red: 1, green: 0.92, blue: 0.40).opacity(0.8), radius: 4)
    }
}

// MARK: - Lightning rod icon

private struct LightningRodIcon: View {
    var body: some View {
        GeometryReader { g in
            let cx = g.size.width / 2, h = g.size.height
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.36, green: 0.72, blue: 1).opacity(0.30))
                    .frame(width: g.size.width*0.88, height: h*0.20)
                    .blur(radius: 4)
                    .position(x: cx, y: h*0.90)
                Rectangle()
                    .fill(Color(red: 0.52, green: 0.76, blue: 1).opacity(0.85))
                    .frame(width: 1.8, height: h*0.58)
                    .position(x: cx, y: h*0.62)
                Circle()
                    .fill(RadialGradient(
                        colors: [.white, Color(red: 0.52, green: 0.82, blue: 1)],
                        center: .topLeading, startRadius: 0, endRadius: 8))
                    .frame(width: g.size.width*0.44, height: g.size.width*0.44)
                    .shadow(color: Color(red: 0.36, green: 0.72, blue: 1).opacity(0.9), radius: 7)
                    .position(x: cx, y: h*0.22)
            }
        }
    }
}
