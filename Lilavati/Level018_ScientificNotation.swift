import SwiftUI

// MARK: - Level 106 - Scientific Notation (Powers of Ten)
//
// One continuous zoom. The camera starts at the observable universe; sliding
// the magnifier to the right dives through galaxy → solar system → planet →
// human → bacterium → molecule → atom → quark. Objects are rendered nested and
// concentric, so each thing you reach is visibly inside the bigger thing that
// came before it. The live 10ⁿ m readout ties the journey to scientific
// notation: the exponent IS the zoom.

struct MathItLevelOneHundredSixView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private struct ScaleObject {
        let name: String
        let exponent: Int          // size in metres, as a power of ten
        let color: Color
        /// Where the NEXT object nests inside this one, in this object's own
        /// base coordinates (relative to its centre). The camera pans so the
        /// child grows out of this exact spot, not the parent's centre.
        let childAnchor: CGPoint
    }

    private let journey: [ScaleObject] = [
        ScaleObject(name: "Observable Universe", exponent: 26,  color: Color(red: 0.62, green: 0.55, blue: 0.98), childAnchor: CGPoint(x: -16, y: 12)),
        ScaleObject(name: "Galaxy",              exponent: 21,  color: Color(red: 0.50, green: 0.62, blue: 0.99), childAnchor: CGPoint(x: 10, y: 24)),
        ScaleObject(name: "Solar System",        exponent: 13,  color: Color(red: 0.98, green: 0.78, blue: 0.32), childAnchor: CGPoint(x: 20.3, y: 15.3)),
        ScaleObject(name: "Planet",              exponent: 7,   color: Color(red: 0.34, green: 0.74, blue: 0.98), childAnchor: CGPoint(x: -16, y: -14)),
        ScaleObject(name: "Human",               exponent: 0,   color: Color(red: 0.96, green: 0.62, blue: 0.42), childAnchor: CGPoint(x: 2, y: -12)),
        ScaleObject(name: "Bacterium",           exponent: -6,  color: Color(red: 0.46, green: 0.86, blue: 0.62), childAnchor: .zero),
        ScaleObject(name: "Molecule",            exponent: -9,  color: Color(red: 0.42, green: 0.82, blue: 0.86), childAnchor: .zero),
        ScaleObject(name: "Atom",                exponent: -10, color: Color(red: 0.72, green: 0.66, blue: 0.99), childAnchor: .zero),
        ScaleObject(name: "Quark",               exponent: -18, color: Color(red: 0.98, green: 0.52, blue: 0.66), childAnchor: .zero)
    ]

    @State private var zoom: Double = 0   // 0 = universe … journey.count-1 = quark
    @State private var completed = false
    @State private var reachedEnd = false
    @State private var focusIndex = 0     // stage the camera is nearest to
    @State private var arrivalRipple: CGFloat = 1   // 0→1 on each stage arrival

    private let accent = Color(red: 0.42, green: 0.70, blue: 1.0)
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)

    /// Visual decades between neighbouring objects: each object renders ~16×
    /// bigger than the one nested inside it.
    private let nestFactor = 1.2

    private var maxZoom: Double { Double(journey.count - 1) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.ignoresSafeArea()
                Starfield().allowsHitTesting(false)

                // The nested world, clipped to a circular viewport.
                nestedWorld
                    .frame(width: size.width, height: size.height * 0.52)
                    .clipped()
                    .position(x: size.width / 2, y: size.height * 0.43)
                    .allowsHitTesting(false)

                // Arrival ripple — expands from the focused object each time
                // the camera reaches a new stage of the zoom.
                Circle()
                    .stroke(journey[focusIndex].color.opacity(Double(1 - arrivalRipple) * 0.7), lineWidth: 2)
                    .frame(width: 156, height: 156)
                    .scaleEffect(0.4 + arrivalRipple * 1.5)
                    .position(x: size.width / 2, y: size.height * 0.43)
                    .allowsHitTesting(false)

                readout
                    .position(x: size.width / 2, y: size.height * 0.235)

                focusLabel
                    .position(x: size.width / 2, y: size.height * 0.715)

                zoomSlider(width: min(size.width - 72, 340))
                    .position(x: size.width / 2, y: size.height * 0.80)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Journey Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
        }
        .environment(\.mathItAccent, accent)
    }

    // MARK: - Nested rendering

    /// Every object is drawn concentric; its apparent size is 10^((zoom−i)·k)
    /// of its base size, so sliding right blows the current object up past the
    /// edges while the next one grows at its centre — pure containment.
    private var nestedWorld: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(journey.indices, id: \.self) { i in
                    let scale = pow(10.0, (zoom - Double(i)) * nestFactor)
                    if scale > 0.03, scale < 40 {
                        let p = nestOffset(index: i, scale: scale)
                        objectView(journey[i], index: i, t: t)
                            .scaleEffect(scale)
                            .offset(x: p.x, y: p.y)
                            .opacity(objectOpacity(scale))
                            .zIndex(Double(i))
                    }
                }
            }
        }
    }

    /// Camera pan for object i so its child grows out of `childAnchor` rather
    /// than the centre: when i is focused it sits centred with its anchor
    /// visible off-centre; as the camera dives toward the child, i slides away
    /// so the anchor point (and the child on it) lands at screen centre.
    private func nestOffset(index i: Int, scale: Double) -> CGPoint {
        func blend(_ s: Double) -> Double {
            min(1, max(0, log10(max(s, 0.0001)) / nestFactor))
        }
        var x = -journey[i].childAnchor.x * scale * blend(scale)
        var y = -journey[i].childAnchor.y * scale * blend(scale)
        if i > 0 {
            let ps = pow(10.0, (zoom - Double(i - 1)) * nestFactor)
            let a = journey[i - 1].childAnchor
            x += a.x * ps * (1 - blend(ps))
            y += a.y * ps * (1 - blend(ps))
        }
        return CGPoint(x: x, y: y)
    }

    private func objectView(_ object: ScaleObject, index: Int, t: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [object.color.opacity(0.14), .clear],
                                     center: .center, startRadius: 2, endRadius: 78))
                .frame(width: 156, height: 156)
            Circle()
                .stroke(object.color.opacity(0.4), lineWidth: 1.2)
                .frame(width: 136, height: 136)
            ScaleArt(kind: index, tint: object.color, t: t)
                .frame(width: 128, height: 128)
        }
    }

    /// Fade in while tiny, fade out as the camera passes through it.
    private func objectOpacity(_ scale: Double) -> Double {
        if scale < 0.5 { return min(1, (scale - 0.03) / 0.2) }
        if scale > 3 { return max(0, 1 - (log10(scale) - log10(3.0)) / 0.9) }
        return 1
    }

    // MARK: - Readout

    /// Continuous exponent interpolated between the two neighbouring objects.
    private var currentExponent: Double {
        let z = min(max(zoom, 0), maxZoom)
        let i = min(Int(z), journey.count - 2)
        let f = z - Double(i)
        return Double(journey[i].exponent) + f * Double(journey[i + 1].exponent - journey[i].exponent)
    }

    private var readout: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)
            Text("10\(superscript(Int(currentExponent.rounded()))) m")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.12), value: Int(currentExponent.rounded()))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Capsule().fill(.white.opacity(0.05)))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    /// Name of the object nearest the camera, fading as you travel between two.
    private var focusLabel: some View {
        let nearest = Int(zoom.rounded())
        let fade = max(0, 1 - abs(zoom - Double(nearest)) * 2.4)
        let object = journey[min(max(nearest, 0), journey.count - 1)]
        let parent = nearest > 0 ? journey[nearest - 1] : nil

        return VStack(spacing: 3) {
            Text(object.name)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            if let parent {
                Text("inside \(parent.name.lowercased()) · \(sciLabel(object.exponent))")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(object.color.opacity(0.85))
            } else {
                Text(sciLabel(object.exponent))
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(object.color.opacity(0.85))
            }
        }
        .opacity(fade)
        .scaleEffect(1 + (1 - arrivalRipple) * 0.14)   // pop on arrival
    }

    // MARK: - Slider

    private func zoomSlider(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Slider(value: $zoom, in: 0...maxZoom)
                .tint(accent)
                .frame(width: width)
                .onChange(of: zoom) { _, newValue in
                    let nearest = min(max(Int(newValue.rounded()), 0), journey.count - 1)
                    if nearest != focusIndex {
                        focusIndex = nearest
                        HapticPlayer.playLightTap()
                        arrivalRipple = 0
                        withAnimation(.easeOut(duration: 0.75)) { arrivalRipple = 1 }
                    }
                    checkCompletion(newValue)
                }

            HStack {
                Label("10²⁶", systemImage: "minus.magnifyingglass")
                Spacer()
                Label("10⁻¹⁸", systemImage: "plus.magnifyingglass")
            }
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.42))
            .frame(width: width)
        }
    }

    // MARK: - Logic

    private func checkCompletion(_ value: Double) {
        guard !reachedEnd, value >= maxZoom - 0.02 else { return }
        reachedEnd = true
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                completed = true
            }
        }
    }

    private func reset() {
        completed = false
        reachedEnd = false
        focusIndex = 0
        arrivalRipple = 1
        withAnimation(.easeInOut(duration: 0.4)) {
            zoom = 0
        }
    }

    // MARK: - Formatting

    private func sciLabel(_ exp: Int) -> String {
        "10\(superscript(exp)) m"
    }

    private func superscript(_ n: Int) -> String {
        let map: [Character: Character] = [
            "-": "⁻", "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"
        ]
        return String(String(n).map { map[$0] ?? $0 })
    }
}

// MARK: - Scale art
//
// Hand-drawn, animated vignette for each rung of the journey. All are Canvas
// based, share a 128×128 frame, and take the global time `t` for motion.

private struct ScaleArt: View {
    let kind: Int
    let tint: Color
    let t: Double

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            switch kind {
            case 0: drawUniverse(ctx, c)
            case 1: drawGalaxy(ctx, c)
            case 2: drawSolarSystem(ctx, c)
            case 3: drawPlanet(ctx, c)
            case 4: drawHuman(ctx, c)
            case 5: drawBacteria(ctx, c)
            case 6: drawMolecule(ctx, c)
            case 7: drawAtom(ctx, c)
            default: drawQuarks(ctx, c)
            }
        }
    }

    private func fract(_ v: Double) -> Double { v - v.rounded(.down) }

    private func dot(_ ctx: GraphicsContext, _ p: CGPoint, _ r: CGFloat, _ color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                 with: .color(color))
    }

    // 0 · Observable universe — a deep-field: dozens of distinct galaxies of
    // different shapes, tilts and hues, floating among faint stars.
    private func drawUniverse(_ ctx: GraphicsContext, _ c: CGPoint) {
        let hues: [Color] = [
            Color(red: 0.95, green: 0.82, blue: 0.55),   // golden spiral
            Color(red: 0.55, green: 0.68, blue: 0.98),   // blue disk
            Color(red: 0.80, green: 0.62, blue: 0.95),   // violet
            Color(red: 0.95, green: 0.60, blue: 0.62),   // rose
            Color(red: 0.88, green: 0.90, blue: 0.98)    // white elliptical
        ]
        // Background stars.
        for i in 0..<50 {
            let seed = Double(i)
            let p = CGPoint(x: c.x + (fract(seed * 0.377) - 0.5) * 126,
                            y: c.y + (fract(seed * 0.719) - 0.5) * 126)
            let tw = 0.18 + 0.3 * (0.5 + 0.5 * sin(t * 1.8 + seed * 2.3))
            dot(ctx, p, 0.5 + fract(seed * 0.269), .white.opacity(tw))
        }
        // The galaxy field — each galaxy drifts gently on its own path, so the
        // whole field visibly breathes.
        for i in 0..<16 {
            let seed = Double(i)
            let drift = CGPoint(
                x: sin(t * 0.45 + seed * 1.9) * 3.6,
                y: cos(t * 0.34 + seed * 1.3) * 3.0
            )
            let p = CGPoint(x: c.x + (fract(seed * 0.618) - 0.5) * 112 + drift.x,
                            y: c.y + (fract(seed * 0.831) - 0.5) * 112 + drift.y)
            let hue = hues[i % hues.count]
            let kind = i % 3
            let tilt = fract(seed * 0.451) * .pi + sin(t * 0.2 + seed) * 0.06
            let sz = 4.0 + fract(seed * 0.577) * 7.0
            drawMiniGalaxy(ctx, at: p, size: sz, tilt: tilt, hue: hue, kind: kind, spin: t * 0.25 + seed)
        }
        // The hero spiral — large, tilted, glowing — where the Milky Way nests.
        // Only a whisper of drift so the nest anchor stays honest.
        let hero = CGPoint(x: c.x - 16 + sin(t * 0.4) * 1.4, y: c.y + 12 + cos(t * 0.31) * 1.2)
        drawMiniGalaxy(ctx, at: hero, size: 16, tilt: 0.5, hue: hues[0], kind: 0, spin: t * 0.18)
    }

    // One small galaxy: 0 = spiral (core + arm dots), 1 = tilted disk,
    // 2 = elliptical smudge.
    private func drawMiniGalaxy(_ ctx: GraphicsContext, at p: CGPoint, size: CGFloat, tilt: Double, hue: Color, kind: Int, spin: Double) {
        switch kind {
        case 0:
            // Spiral: bright core + two arms of dots, squashed by tilt.
            let squash = 0.45 + 0.4 * abs(cos(tilt))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - size * 0.4, y: p.y - size * 0.4 * squash,
                                            width: size * 0.8, height: size * 0.8 * squash)),
                     with: .radialGradient(Gradient(colors: [.white, hue.opacity(0)]),
                                           center: p, startRadius: 0.5, endRadius: size * 0.6))
            for arm in 0..<2 {
                for k in 0..<14 {
                    let f = Double(k) / 14
                    let a = Double(arm) * .pi + f * 3.0 + spin
                    let r = size * (0.18 + f * 0.85)
                    let q = CGPoint(x: p.x + cos(a + tilt) * r, y: p.y + sin(a + tilt) * r * squash)
                    dot(ctx, q, 0.55 + (1 - f) * 0.5, hue.opacity((1 - f) * 0.8 + 0.1))
                }
            }
        case 1:
            // Edge-on disk: thin bright streak with a core bulge.
            var streak = Path(ellipseIn: CGRect(x: -size, y: -size * 0.16, width: size * 2, height: size * 0.32))
            streak = streak.applying(CGAffineTransform(rotationAngle: tilt))
            streak = streak.applying(CGAffineTransform(translationX: p.x, y: p.y))
            ctx.fill(streak, with: .color(hue.opacity(0.55)))
            dot(ctx, p, size * 0.22, .white.opacity(0.85))
        default:
            // Elliptical: a soft radial smudge.
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - size * 0.7, y: p.y - size * 0.55,
                                            width: size * 1.4, height: size * 1.1)),
                     with: .radialGradient(Gradient(colors: [hue.opacity(0.75), hue.opacity(0)]),
                                           center: p, startRadius: 0.5, endRadius: size * 0.75))
        }
    }

    // 1 · Galaxy — the Milky Way face-on: a golden central bar, four dusty
    // blue-white spiral arms flecked with pink star-forming regions, and a
    // small gold marker where the Sun sits (the nest anchor).
    private func drawGalaxy(_ ctx: GraphicsContext, _ c: CGPoint) {
        let spin = t * 0.05
        let squash = 0.94

        // Faint disk haze.
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 58, y: c.y - 58 * squash, width: 116, height: 116 * squash)),
                 with: .radialGradient(Gradient(colors: [tint.opacity(0.14), .clear]),
                                       center: c, startRadius: 4, endRadius: 60))

        // Four arms, logarithmic-ish, dense with star dust.
        for arm in 0..<4 {
            let armPhase = Double(arm) * .pi / 2
            for k in 0..<40 {
                let f = Double(k) / 40.0
                let a = armPhase + 0.55 + f * 2.6 + spin
                let r = 11 + f * 47
                let scatterA = (fract(Double(k * 7 + arm * 13) * 0.431) - 0.5) * 0.25
                let scatterR = (fract(Double(k * 3 + arm * 5) * 0.719) - 0.5) * 5
                let p = CGPoint(x: c.x + cos(a + scatterA) * (r + scatterR),
                                y: c.y + sin(a + scatterA) * (r + scatterR) * squash)
                // Bluish-white star dust, denser and brighter inward.
                let bright = (1 - f) * 0.55 + 0.18
                dot(ctx, p, 0.7 + (1 - f) * 0.9, Color(red: 0.78, green: 0.85, blue: 1.0).opacity(bright))
                // Dust lane haze.
                if k % 3 == 0 {
                    dot(ctx, p, 2.6, tint.opacity(0.13))
                }
                // Pink star-forming flecks, sparse, mid-arm outward.
                if k % 9 == 4, f > 0.3 {
                    dot(ctx, p, 1.1, Color(red: 0.95, green: 0.5, blue: 0.6).opacity(0.75))
                }
            }
        }

        // Central bar — elongated golden core, slowly turning with the arms.
        var bar = Path(ellipseIn: CGRect(x: -17, y: -6.5, width: 34, height: 13))
        bar = bar.applying(CGAffineTransform(rotationAngle: 0.55 + spin))
        bar = bar.applying(CGAffineTransform(translationX: c.x, y: c.y))
        ctx.fill(bar, with: .color(Color(red: 0.96, green: 0.83, blue: 0.55).opacity(0.55)))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16)),
                 with: .radialGradient(Gradient(colors: [.white, Color(red: 0.96, green: 0.8, blue: 0.5).opacity(0)]),
                                       center: c, startRadius: 1, endRadius: 11))

        // The Sun — a small gold marker on an outer arm (the nest anchor).
        let sun = CGPoint(x: c.x + 10, y: c.y + 24)
        dot(ctx, sun, 1.6, Color(red: 1.0, green: 0.85, blue: 0.4))
        ctx.stroke(Path(ellipseIn: CGRect(x: sun.x - 3.6, y: sun.y - 3.6, width: 7.2, height: 7.2)),
                   with: .color(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.5)), lineWidth: 0.7)
    }

    // 2 · Solar system — the sun with orbiting planets (rough replica: Mercury
    // → Saturn, with Saturn's ring).
    private func drawSolarSystem(_ ctx: GraphicsContext, _ c: CGPoint) {
        // Sun.
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)),
                 with: .radialGradient(Gradient(colors: [.white, Color(red: 0.98, green: 0.7, blue: 0.2)]),
                                       center: c, startRadius: 1, endRadius: 8))
        let orbits: [(r: CGFloat, speed: Double, size: CGFloat, color: Color)] = [
            (14, 1.9,  1.3, Color(white: 0.75)),                          // mercury
            (20, 1.4,  1.9, Color(red: 0.92, green: 0.78, blue: 0.55)),   // venus
            (27, 1.1,  2.0, Color(red: 0.35, green: 0.62, blue: 0.95)),   // earth
            (34, 0.85, 1.7, Color(red: 0.88, green: 0.42, blue: 0.28)),   // mars
            (45, 0.55, 3.4, Color(red: 0.85, green: 0.68, blue: 0.48)),   // jupiter
            (57, 0.4,  2.9, Color(red: 0.90, green: 0.82, blue: 0.60))    // saturn
        ]
        for (i, o) in orbits.enumerated() {
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - o.r, y: c.y - o.r * 0.86,
                                              width: o.r * 2, height: o.r * 1.72)),
                       with: .color(.white.opacity(0.10)), lineWidth: 0.7)
            // Earth stays pinned at the nest anchor so the Planet grows out of
            // it — everything else orbits.
            let a = i == 2 ? 0.72 : t * o.speed + Double(i) * 1.9
            let p = CGPoint(x: c.x + cos(a) * o.r, y: c.y + sin(a) * o.r * 0.86)
            dot(ctx, p, o.size, o.color)
            if i == 5 {   // saturn's ring
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 5.4, y: p.y - 2.0, width: 10.8, height: 4.0)),
                           with: .color(o.color.opacity(0.75)), lineWidth: 0.8)
            }
            if i == 2 {   // earth's moon
                let ma = t * 4.2
                dot(ctx, CGPoint(x: p.x + cos(ma) * 4.4, y: p.y + sin(ma) * 4.4), 0.7, .white.opacity(0.8))
            }
        }
    }

    // 3 · Planet — Earth with drifting clouds, rotating continents and an
    // orbiting moon.
    private func drawPlanet(_ ctx: GraphicsContext, _ c: CGPoint) {
        let R: CGFloat = 44
        let globe = Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2))
        ctx.fill(globe, with: .radialGradient(
            Gradient(colors: [Color(red: 0.35, green: 0.68, blue: 0.98),
                              Color(red: 0.05, green: 0.20, blue: 0.48)]),
            center: CGPoint(x: c.x - R * 0.4, y: c.y - R * 0.4), startRadius: 4, endRadius: R * 2))

        var land = ctx
        land.clip(to: globe)
        let drift = CGFloat(fract(t * 0.02)) * R * 4 // slow rotation, wraps
        for pass in 0..<2 {
            let baseX = c.x - drift + CGFloat(pass) * R * 4
            let green = Color(red: 0.28, green: 0.62, blue: 0.32)
            land.fill(blob(at: CGPoint(x: baseX - 20, y: c.y - 16), w: 30, h: 20, tilt: -0.3), with: .color(green.opacity(0.85)))
            land.fill(blob(at: CGPoint(x: baseX + 14, y: c.y + 6), w: 24, h: 26, tilt: 0.5), with: .color(green.opacity(0.8)))
            land.fill(blob(at: CGPoint(x: baseX + 44, y: c.y - 20), w: 20, h: 14, tilt: 0.2), with: .color(green.opacity(0.75)))
            land.fill(blob(at: CGPoint(x: baseX - 44, y: c.y + 22), w: 26, h: 14, tilt: -0.1), with: .color(green.opacity(0.7)))
        }
        // Clouds — drifting faster than the land.
        let cloudDrift = CGFloat(fract(t * 0.05)) * R * 4
        for pass in 0..<2 {
            let baseX = c.x - cloudDrift + CGFloat(pass) * R * 4
            land.fill(blob(at: CGPoint(x: baseX, y: c.y - 28), w: 34, h: 7, tilt: 0.06), with: .color(.white.opacity(0.30)))
            land.fill(blob(at: CGPoint(x: baseX + 30, y: c.y + 18), w: 28, h: 6, tilt: -0.08), with: .color(.white.opacity(0.24)))
            land.fill(blob(at: CGPoint(x: baseX - 34, y: c.y + 2), w: 22, h: 5, tilt: 0.1), with: .color(.white.opacity(0.2)))
        }
        // Terminator shading.
        ctx.fill(globe, with: .linearGradient(
            Gradient(colors: [.clear, .black.opacity(0.45)]),
            startPoint: CGPoint(x: c.x - R, y: c.y), endPoint: CGPoint(x: c.x + R, y: c.y)))
        ctx.stroke(globe, with: .color(.white.opacity(0.25)), lineWidth: 1)

        // Moon.
        let ma = t * 0.5
        let mp = CGPoint(x: c.x + cos(ma) * 58, y: c.y + sin(ma) * 58 * 0.6)
        dot(ctx, mp, 4.2, Color(white: 0.78))
        dot(ctx, CGPoint(x: mp.x - 1.1, y: mp.y - 0.8), 1.0, Color(white: 0.6))
    }

    // 4 · Human — a profile figure walking rightward with a natural gait:
    // alternating knee-lift strides, opposite arm swing, a slight bob, and
    // the ground scrolling beneath to sell the direction.
    private func drawHuman(_ ctx: GraphicsContext, _ c: CGPoint) {
        let skin = tint
        let phase = t * 4.2
        let bob = abs(sin(phase)) * 1.6
        let lean: CGFloat = 3.0                       // forward (rightward) lean
        let cx = c.x, groundY = c.y + 34
        let hip = CGPoint(x: cx, y: groundY - 30 - bob)
        let shoulder = CGPoint(x: hip.x + lean, y: hip.y - 18)

        // Legs — each foot traces a stride loop: forward on the ground, then
        // lifted as it swings back.
        for legPhase in [phase, phase + .pi] {
            let s = sin(legPhase)
            // Lift while the foot swings FORWARD; planted while it slides back
            // (matching the leftward-scrolling ground) — a real gait cycle.
            let lift = max(0, cos(legPhase)) * 5
            let foot = CGPoint(x: hip.x + s * 10 + 2, y: groundY - lift)
            let knee = CGPoint(x: (hip.x + foot.x) / 2 + 4 + max(0, s) * 2,
                               y: (hip.y + foot.y) / 2)
            var leg = Path()
            leg.move(to: hip)
            leg.addQuadCurve(to: foot, control: knee)
            ctx.stroke(leg, with: .color(skin), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
        }

        // Torso.
        var torso = Path()
        torso.move(to: hip)
        torso.addQuadCurve(to: shoulder, control: CGPoint(x: hip.x + lean * 0.4, y: hip.y - 9))
        ctx.stroke(torso, with: .color(skin), style: StrokeStyle(lineWidth: 5.4, lineCap: .round))

        // Arms — opposite phase to the legs, swinging from the shoulder.
        for armPhase in [phase + .pi, phase] {
            let s = sin(armPhase)
            let hand = CGPoint(x: shoulder.x + s * 8 + 1, y: shoulder.y + 14 + abs(s))
            let elbow = CGPoint(x: (shoulder.x + hand.x) / 2 + 2.5, y: shoulder.y + 8)
            var arm = Path()
            arm.move(to: shoulder)
            arm.addQuadCurve(to: hand, control: elbow)
            ctx.stroke(arm, with: .color(skin.opacity(0.9)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        }

        // Head — slightly ahead of the shoulders, facing right.
        let head = CGPoint(x: shoulder.x + 2.5, y: shoulder.y - 11)
        dot(ctx, head, 7, skin)

        // Ground scrolling left underneath — sells the rightward walk.
        let dashShift = CGFloat(fract(t * 1.8)) * 18
        for k in -3...3 {
            let x = cx + CGFloat(k) * 18 - dashShift
            guard abs(x - cx) < 42 else { continue }
            var dash = Path()
            dash.move(to: CGPoint(x: x, y: groundY + 3))
            dash.addLine(to: CGPoint(x: x + 8, y: groundY + 3))
            let edgeFade = 1 - abs(x - cx) / 42
            ctx.stroke(dash, with: .color(.white.opacity(0.18 * edgeFade)), lineWidth: 1)
        }
        // Soft shadow under the figure.
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 13, y: groundY + 1, width: 26, height: 4)),
                 with: .color(.white.opacity(0.06)))

        // Beating heart.
        let beat = 1 + 0.25 * max(0, sin(t * 5.6))
        dot(ctx, CGPoint(x: shoulder.x - 1, y: shoulder.y + 5), 2.4 * beat,
            Color(red: 0.95, green: 0.3, blue: 0.35))
    }

    // 5 · Bacterium — squirming rod-shaped microbes with waving flagella.
    private func drawBacteria(_ ctx: GraphicsContext, _ c: CGPoint) {
        let cells: [(orbitR: CGFloat, speed: Double, phase: Double, len: CGFloat)] = [
            (26, 0.35, 0.0, 20), (38, 0.26, 2.2, 16), (18, 0.44, 4.1, 13), (44, 0.2, 5.3, 18)
        ]
        for (i, cell) in cells.enumerated() {
            let a = t * cell.speed + cell.phase
            let p = CGPoint(x: c.x + cos(a) * cell.orbitR, y: c.y + sin(a) * cell.orbitR * 0.8)
            let heading = a + .pi / 2 + sin(t * 1.8 + Double(i)) * 0.4
            drawOneBacterium(ctx, at: p, heading: heading, length: cell.len, seed: Double(i))
        }
        // Nutrient specks.
        for i in 0..<14 {
            let seed = Double(i)
            let a = fract(seed * 0.71) * 2 * .pi + t * 0.05
            let r = 8 + fract(seed * 0.43) * 50
            dot(ctx, CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r * 0.85),
                0.8, tint.opacity(0.3))
        }
    }

    private func drawOneBacterium(_ ctx: GraphicsContext, at p: CGPoint, heading: Double, length: CGFloat, seed: Double) {
        let dir = CGPoint(x: cos(heading), y: sin(heading))
        let half = length / 2
        let a = CGPoint(x: p.x - dir.x * half, y: p.y - dir.y * half)
        let b = CGPoint(x: p.x + dir.x * half, y: p.y + dir.y * half)
        var bodyPath = Path()
        bodyPath.move(to: a)
        bodyPath.addLine(to: b)
        ctx.stroke(bodyPath, with: .color(tint.opacity(0.28)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        ctx.stroke(bodyPath, with: .color(tint.opacity(0.9)), style: StrokeStyle(lineWidth: 6.4, lineCap: .round))
        // Flagellum — animated sine tail off the back end.
        var tail = Path()
        tail.move(to: a)
        let normal = CGPoint(x: -dir.y, y: dir.x)
        for k in 1...8 {
            let f = CGFloat(k) / 8
            let wig = sin(t * 9 + seed * 2 + Double(f) * 9) * 3.2 * Double(f)
            tail.addLine(to: CGPoint(
                x: a.x - dir.x * f * 13 + normal.x * wig,
                y: a.y - dir.y * f * 13 + normal.y * wig
            ))
        }
        ctx.stroke(tail, with: .color(tint.opacity(0.6)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    }

    // 6 · Molecule — a rotating ball-and-stick ring with two side groups.
    private func drawMolecule(_ ctx: GraphicsContext, _ c: CGPoint) {
        let spin = t * 0.4
        var ring: [CGPoint] = []
        for k in 0..<6 {
            let a = Double(k) / 6 * 2 * .pi + spin
            ring.append(CGPoint(x: c.x + cos(a) * 26, y: c.y + sin(a) * 26 * 0.9))
        }
        // Bonds.
        for k in 0..<6 {
            var bond = Path()
            bond.move(to: ring[k])
            bond.addLine(to: ring[(k + 1) % 6])
            ctx.stroke(bond, with: .color(.white.opacity(0.4)), lineWidth: 1.6)
        }
        // Side groups on two opposite vertices.
        for (k, reach) in [(0, 18.0), (3, 18.0)] {
            let a = Double(k) / 6 * 2 * .pi + spin
            let out = CGPoint(x: ring[k].x + cos(a) * reach, y: ring[k].y + sin(a) * reach * 0.9)
            var bond = Path()
            bond.move(to: ring[k])
            bond.addLine(to: out)
            ctx.stroke(bond, with: .color(.white.opacity(0.35)), lineWidth: 1.4)
            dot(ctx, out, 4.4, Color(red: 0.95, green: 0.42, blue: 0.4))
            dot(ctx, CGPoint(x: out.x - 1.2, y: out.y - 1.2), 1.3, .white.opacity(0.6))
        }
        // Ring atoms.
        for (k, p) in ring.enumerated() {
            let big = k % 2 == 0
            dot(ctx, p, big ? 6.2 : 5.0, big ? tint : Color(white: 0.85))
            dot(ctx, CGPoint(x: p.x - 1.6, y: p.y - 1.6), 1.6, .white.opacity(0.7))
        }
    }

    // 7 · Atom — a jittering nucleus with electrons racing on tilted orbits.
    private func drawAtom(_ ctx: GraphicsContext, _ c: CGPoint) {
        // Orbits: three ellipses at different tilts.
        for (i, tilt) in [0.0, 1.05, 2.09].enumerated() {
            var orbit = Path(ellipseIn: CGRect(x: -46, y: -17, width: 92, height: 34))
            orbit = orbit.applying(CGAffineTransform(rotationAngle: tilt))
            orbit = orbit.applying(CGAffineTransform(translationX: c.x, y: c.y))
            ctx.stroke(orbit, with: .color(tint.opacity(0.32)), lineWidth: 0.9)

            // Electron on this orbit.
            let a = t * (2.2 + Double(i) * 0.5) + Double(i) * 2.1
            let ex = cos(a) * 46
            let ey = sin(a) * 17
            let rx = ex * cos(tilt) - ey * sin(tilt)
            let ry = ex * sin(tilt) + ey * cos(tilt)
            let p = CGPoint(x: c.x + rx, y: c.y + ry)
            dot(ctx, p, 2.6, .white)
            dot(ctx, p, 4.6, tint.opacity(0.25))
        }
        // Nucleus: protons and neutrons, breathing slightly.
        let cluster: [(dx: CGFloat, dy: CGFloat, proton: Bool)] = [
            (0, 0, true), (5, -2, false), (-4, -3, true), (-2, 4, false),
            (4, 4, true), (-6, 1, false), (1, -6, true)
        ]
        let breathe = 1 + 0.06 * sin(t * 3.4)
        for n in cluster {
            let p = CGPoint(x: c.x + n.dx * breathe, y: c.y + n.dy * breathe)
            dot(ctx, p, 3.4, n.proton ? Color(red: 0.95, green: 0.45, blue: 0.4) : Color(white: 0.72))
            dot(ctx, CGPoint(x: p.x - 0.9, y: p.y - 0.9), 1.0, .white.opacity(0.55))
        }
    }

    // 8 · Quark — three colour-charged quarks bound by wobbling gluon lines.
    private func drawQuarks(_ ctx: GraphicsContext, _ c: CGPoint) {
        let colors: [Color] = [
            Color(red: 0.98, green: 0.42, blue: 0.45),
            Color(red: 0.45, green: 0.9, blue: 0.55),
            Color(red: 0.45, green: 0.62, blue: 0.98)
        ]
        // Quark positions: triangle with confinement jitter.
        var pts: [CGPoint] = []
        for i in 0..<3 {
            let a = Double(i) / 3 * 2 * .pi - .pi / 2
            let jx = sin(t * 3.1 + Double(i) * 2.4) * 4.5
            let jy = cos(t * 2.7 + Double(i) * 1.8) * 4.5
            pts.append(CGPoint(x: c.x + cos(a) * 24 + jx, y: c.y + sin(a) * 24 + jy))
        }
        // Gluon springs — wavy lines between each pair.
        for i in 0..<3 {
            let a = pts[i], b = pts[(i + 1) % 3]
            let dirX = b.x - a.x, dirY = b.y - a.y
            let len = max(hypot(dirX, dirY), 0.01)
            let nx = -dirY / len, ny = dirX / len
            var wave = Path()
            wave.move(to: a)
            for k in 1...10 {
                let f = CGFloat(k) / 10
                let amp = sin(Double(f) * .pi * 3 + t * 7) * 3.4 * sin(Double(f) * .pi)
                wave.addLine(to: CGPoint(x: a.x + dirX * f + nx * amp, y: a.y + dirY * f + ny * amp))
            }
            ctx.stroke(wave, with: .color(.white.opacity(0.42)), lineWidth: 1.1)
        }
        // The quarks.
        for (i, p) in pts.enumerated() {
            dot(ctx, p, 8.5, colors[i].opacity(0.25))
            dot(ctx, p, 5.4, colors[i])
            dot(ctx, CGPoint(x: p.x - 1.5, y: p.y - 1.5), 1.6, .white.opacity(0.8))
        }
        // Confinement boundary hint.
        let pulse = 1 + 0.04 * sin(t * 2.2)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 40 * pulse, y: c.y - 40 * pulse,
                                          width: 80 * pulse, height: 80 * pulse)),
                   with: .color(tint.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
    }

    private func blob(at p: CGPoint, w: CGFloat, h: CGFloat, tilt: CGFloat) -> Path {
        var path = Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        path = path.applying(CGAffineTransform(rotationAngle: tilt))
        path = path.applying(CGAffineTransform(translationX: p.x, y: p.y))
        return path
    }
}

// MARK: - Starfield

private struct Starfield: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<70 {
                let x = CGFloat((i * 61) % 997) / 997 * size.width
                let y = CGFloat((i * 89) % 991) / 991 * size.height
                let r = CGFloat((i % 3) + 1) * 0.5
                let opacity = 0.1 + Double((i * 13) % 7) / 30
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(opacity)))
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    MathItLevelOneHundredSixView(onContinue: {}, onLevelSelect: {})
}
