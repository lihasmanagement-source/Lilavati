import SwiftUI

// MARK: - Level 118 - Inverse Functions (The Melt Machine)
//
// A water droplet arrives stamped with a function — f(x) = 2x − 4 — and the
// machine wears the symbol f⁻¹(x) with a dotted slot on its face. Pick the
// equation that truly inverts f from the tray and drag it into the slot: the
// machine accepts it, swallows the droplet through the hopper, runs its show
// (wobble, glow, churning porthole, steam) and a frozen ice cube slides out of
// the output chute. Wrong equations bounce off. Three droplets, three inverses.

struct MathItLevelOneHundredEighteenView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    // MARK: Rounds

    private struct Round {
        let fx: String
        let choices: [String]
        let correct: Int
    }

    private let rounds: [Round] = [
        Round(fx: "f(x) = x + 5",
              choices: ["x − 5", "x + 5", "5 − x"], correct: 0),
        Round(fx: "f(x) = 3x",
              choices: ["3x", "x − 3", "x ⁄ 3"], correct: 2),
        Round(fx: "f(x) = 2x − 4",
              choices: ["(x − 4) ⁄ 2", "(x + 4) ⁄ 2", "2x + 4"], correct: 1)
    ]

    private enum Phase {
        case pick          // drag an equation tile into the slot
        case feeding       // cube dives into the hopper
        case processing
        case output        // water slides out of the chute
    }

    // MARK: State

    @State private var roundIndex = 0
    @State private var phase: Phase = .pick
    @State private var lockedTile: Int?
    @State private var tileOffsets: [Int: CGSize] = [:]
    @State private var activeTile: Int?
    @State private var wrongTile: Int?
    @State private var slotShake: CGFloat = 0
    @State private var cubeDive = false
    @State private var waterProgress: CGFloat = 0      // 0 = in chute, 1 = on tray
    @State private var showCheck = false
    @State private var completed = false
    @State private var token = UUID()

    private let gold = Color.mathGold
    private let accent = Color(red: 0.45, green: 0.78, blue: 1.0)

    private var round: Round { rounds[min(roundIndex, rounds.count - 1)] }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let machine = machineFrame(size: size)
            let slot = slotRect(machine: machine)
            let chuteMouth = CGPoint(x: machine.maxX + 12, y: machine.maxY - 24)
            let tray = CGPoint(x: min(machine.maxX + 64, size.width - 42), y: machine.maxY + 26)

            ZStack {
                Color.black.ignoresSafeArea()

                header(size: size)

                // The machine.
                MeltMachineView(accent: accent,
                                processing: phase == .processing,
                                slotRect: slot,
                                slotEquation: lockedTile.map { round.choices[$0] },
                                slotFlash: wrongTile != nil,
                                frame: machine)
                    .modifier(ShakeEffect(shakes: slotShake))

                // The water droplet on its platform, stamped with f.
                if phase == .pick || phase == .feeding {
                    waterStation(machine: machine, size: size)
                }

                // The product sliding out of the chute onto the tray.
                if phase == .output {
                    IceCubeView()
                        .scaleEffect(0.6 + waterProgress * 0.4)
                        .position(
                            x: chuteMouth.x + (tray.x - chuteMouth.x) * waterProgress,
                            y: chuteMouth.y + (tray.y - chuteMouth.y) * waterProgress
                                - sin(Double(waterProgress) * .pi) * 18
                        )
                        .zIndex(25)
                    if showCheck {
                        Text("f⁻¹(f(x)) = x ✓")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundStyle(gold)
                            .shadow(color: gold.opacity(0.5), radius: 6)
                            .position(x: size.width / 2, y: machine.maxY + 64)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Tray.
                Capsule()
                    .fill(Color(white: 0.14))
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                    .frame(width: 56, height: 8)
                    .position(x: tray.x, y: tray.y + 24)

                // Equation tiles.
                if phase == .pick {
                    equationTiles(size: size, slot: slot)
                }

                // Round dots.
                HStack(spacing: 6) {
                    ForEach(rounds.indices, id: \.self) { i in
                        Circle()
                            .fill(i < roundIndex || completed ? gold : Color.white.opacity(0.2))
                            .frame(width: 7, height: 7)
                    }
                }
                .position(x: size.width / 2, y: size.height * 0.87)

                ProgressView(value: completed ? 1 : Double(roundIndex) / Double(rounds.count))
                    .tint(gold)
                    .frame(width: min(size.width - 58, 380))
                    .position(x: size.width / 2, y: size.height * 0.08)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)
                    .zIndex(50)

                CompletionOverlay(
                    title: "Inverses Installed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(100)
            }
            .environment(\.mathItAccent, gold)
        }
    }

    // MARK: - Layout

    private func machineFrame(size: CGSize) -> CGRect {
        let w = min(size.width * 0.46, 184.0)
        let h = w * 0.95
        return CGRect(x: size.width * 0.54 - w / 2, y: size.height * 0.43 - h / 2, width: w, height: h)
    }

    private func slotRect(machine: CGRect) -> CGRect {
        CGRect(x: machine.midX - machine.width * 0.36,
               y: machine.maxY - 48,
               width: machine.width * 0.72, height: 34)
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 4) {
            Text("INSTALL THE INVERSE")
                .font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(3)
                .foregroundStyle(gold.opacity(0.85))
            Text(phase == .pick
                 ? "drag the equation that undoes f into the machine's slot"
                 : (phase == .output ? "product delivered" : "processing…"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .position(x: size.width / 2, y: size.height * 0.145)
    }

    // MARK: - Water station

    private func waterStation(machine: CGRect, size: CGSize) -> some View {
        let platform = CGPoint(x: size.width * 0.17, y: machine.midY + 22)
        let hopper = CGPoint(x: machine.midX, y: machine.minY - 24)

        return ZStack {
            // Platform.
            Capsule()
                .fill(Color(white: 0.14))
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                .frame(width: 66, height: 8)
                .position(x: platform.x, y: platform.y + 36)

            // The droplet (dives into the hopper when the inverse locks in).
            WaterDropView()
                .scaleEffect(cubeDive ? 0.25 : 1)
                .opacity(cubeDive ? 0 : 1)
                .position(cubeDive ? hopper : platform)

            // The function stamped above the droplet.
            if !cubeDive {
                Text(round.fx)
                    .font(.system(size: 12.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 7).fill(accent.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(accent.opacity(0.5), lineWidth: 1))
                    .position(x: platform.x, y: platform.y - 48)
            }
        }
        .animation(.easeIn(duration: 0.5), value: cubeDive)
    }

    // MARK: - Equation tiles

    private func equationTiles(size: CGSize, slot: CGRect) -> some View {
        let homes = tileHomes(size: size)
        return ForEach(round.choices.indices, id: \.self) { i in
            if lockedTile != i {
                equationTile(i, home: homes[i], slot: slot)
            }
        }
    }

    private func tileHomes(size: CGSize) -> [CGPoint] {
        let xs: [CGFloat] = [0.20, 0.50, 0.80]
        return xs.map { CGPoint(x: size.width * $0, y: size.height * 0.77) }
    }

    private func equationTile(_ i: Int, home: CGPoint, slot: CGRect) -> some View {
        let offset = tileOffsets[i] ?? .zero
        let isWrong = wrongTile == i
        let isActive = activeTile == i

        return Text("f⁻¹(x) = \(round.choices[i])")
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(isWrong ? Color.red : .white)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isWrong ? Color.red.opacity(0.18) : Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isWrong ? Color.red.opacity(0.7) : accent.opacity(0.45), lineWidth: 1.3))
            .scaleEffect(isActive ? 1.1 : 1)
            .contentShape(Rectangle().inset(by: -10))
            .highPriorityGesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        guard phase == .pick else { return }
                        activeTile = i
                        tileOffsets[i] = value.translation
                    }
                    .onEnded { value in
                        activeTile = nil
                        guard phase == .pick else { return }
                        let dropped = CGPoint(x: home.x + value.translation.width,
                                              y: home.y + value.translation.height)
                        resolveTileDrop(i, dropped: dropped, slot: slot)
                    }
            )
            .position(x: home.x + offset.width, y: home.y + offset.height)
            .zIndex(isActive ? 40 : 20)
    }

    private func resolveTileDrop(_ i: Int, dropped: CGPoint, slot: CGRect) {
        guard slot.insetBy(dx: -26, dy: -26).contains(dropped) else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                tileOffsets[i] = .zero
            }
            return
        }

        if i == round.correct {
            HapticPlayer.playLightTap()
            tileOffsets[i] = .zero
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                lockedTile = i
            }
            startRun()
        } else {
            HapticPlayer.playLightTap()
            wrongTile = i
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                slotShake += 1
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                tileOffsets[i] = .zero
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if wrongTile == i { wrongTile = nil }
            }
        }
    }

    // MARK: - The run

    private func startRun() {
        let run = UUID()
        token = run

        // Cube dives into the hopper.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard token == run else { return }
            phase = .feeding
            cubeDive = true
            HapticPlayer.playLightTap()
        }
        // The show.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard token == run else { return }
            phase = .processing
        }
        // Product out of the chute.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.9) {
            guard token == run else { return }
            HapticPlayer.playCompletionTap()
            phase = .output
            waterProgress = 0
            withAnimation(.easeOut(duration: 0.55)) { waterProgress = 1 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.4)) { showCheck = true }
        }
        // Next round / done.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            guard token == run else { return }
            if roundIndex < rounds.count - 1 {
                withAnimation(.easeInOut(duration: 0.35)) {
                    roundIndex += 1
                    resetRound()
                }
            } else {
                withAnimation(.spring(response: 0.54, dampingFraction: 0.84)) {
                    completed = true
                }
            }
        }
    }

    private func resetRound() {
        phase = .pick
        lockedTile = nil
        tileOffsets = [:]
        activeTile = nil
        wrongTile = nil
        cubeDive = false
        waterProgress = 0
        showCheck = false
    }

    private func reset() {
        roundIndex = 0
        completed = false
        token = UUID()
        resetRound()
    }
}

// MARK: - Shake

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(shakes * .pi * 6) * 7, y: 0))
    }
}

// MARK: - The machine

/// The melt machine: hopper on top, churning porthole, a big f⁻¹(x) badge, a
/// dotted equation slot on its face, an output chute on the right — and the
/// full show (wobble, hop, glow, swirl, gear, steam) while processing.
private struct MeltMachineView: View {
    let accent: Color
    let processing: Bool
    let slotRect: CGRect
    let slotEquation: String?
    let slotFlash: Bool
    let frame: CGRect

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let wobble = processing ? sin(t * 26) * 2.2 : 0
            let bounce = processing ? abs(sin(t * 13)) * 3 : 0

            ZStack {
                // Body.
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.09)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .stroke(processing ? accent.opacity(0.9) : .white.opacity(0.25),
                                lineWidth: processing ? 2.2 : 1.3))
                    .shadow(color: processing ? accent.opacity(0.55) : .black.opacity(0.4),
                            radius: processing ? 22 : 10)

                // Hopper (intake) on top.
                Trapezoid()
                    .fill(Color(white: 0.13))
                    .overlay(Trapezoid().stroke(.white.opacity(0.25), lineWidth: 1.2))
                    .frame(width: frame.width * 0.42, height: 20)
                    .offset(y: -frame.height / 2 - 9)

                // Output chute on the right.
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(white: 0.13))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.25), lineWidth: 1.1))
                    Rectangle()
                        .fill(.black.opacity(0.8))
                        .frame(width: 6, height: 12)
                        .offset(x: 8)
                }
                .frame(width: 30, height: 20)
                .offset(x: frame.width / 2 + 9, y: frame.height / 2 - 26)

                // Porthole with the churn.
                ZStack {
                    Circle().fill(Color.black.opacity(0.75))
                    if processing {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .trim(from: 0.1, to: 0.55)
                                .stroke(accent.opacity(0.8 - Double(i) * 0.22),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 15 + CGFloat(i) * 11, height: 15 + CGFloat(i) * 11)
                                .rotationEffect(.radians(t * (3.4 - Double(i) * 0.8) + Double(i)))
                        }
                    } else {
                        Image(systemName: "snowflake")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(accent.opacity(0.6))
                    }
                    Circle().stroke(.white.opacity(0.3), lineWidth: 1.4)
                }
                .frame(width: frame.width * 0.34, height: frame.width * 0.34)
                .offset(x: -frame.width * 0.20, y: -frame.height * 0.16)

                // The f⁻¹(x) badge.
                Text("f⁻¹(x)")
                    .font(.system(size: 19, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .shadow(color: Color.mathGold.opacity(processing ? 0.6 : 0.25), radius: 7)
                    .offset(x: frame.width * 0.18, y: -frame.height * 0.16)

                // Spinning gear.
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(processing ? 0.7 : 0.25))
                    .rotationEffect(.radians(processing ? t * 6 : 0))
                    .offset(x: frame.width * 0.32, y: frame.height * 0.04)

                // The equation slot — dotted until an inverse is installed.
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(slotEquation != nil ? Color.mathGold.opacity(0.14) : Color.black.opacity(0.4))
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(slotFlash ? Color.red.opacity(0.85)
                                : (slotEquation != nil ? Color.mathGold.opacity(0.85) : .white.opacity(0.45)),
                                style: StrokeStyle(lineWidth: 1.5,
                                                   dash: slotEquation != nil ? [] : [6, 5]))
                    if let equation = slotEquation {
                        Text("f⁻¹(x) = \(equation)")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.mathGold)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                    } else {
                        Text("drop inverse here")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(width: slotRect.width, height: slotRect.height)
                .offset(y: frame.height / 2 - (frame.maxY - slotRect.midY))

                // Particles while processing.
                if processing {
                    MachineParticles(accent: accent, t: t)
                        .frame(width: frame.width * 1.6, height: frame.height * 1.5)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: frame.width, height: frame.height)
            .rotationEffect(.degrees(wobble))
            .offset(y: -bounce)
            .position(x: frame.midX, y: frame.midY)
        }
    }
}

private struct Trapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Steam puffs rising from the hopper and droplets shaking loose.
private struct MachineParticles: View {
    let accent: Color
    let t: Double

    var body: some View {
        Canvas { ctx, size in
            func fract(_ v: Double) -> Double { v - v.rounded(.down) }
            let c = CGPoint(x: size.width / 2, y: size.height / 2)

            for i in 0..<10 {
                let seed = Double(i)
                let cycle = fract(t * (0.5 + fract(seed * 0.37) * 0.5) + fract(seed * 0.61))
                let sway = sin(t * 3 + seed) * 8

                if i.isMultiple(of: 2) {
                    // Puffs rising from the hopper.
                    let y = c.y - size.height * 0.30 - cycle * size.height * 0.34
                    let x = c.x + (fract(seed * 0.73) - 0.5) * 26 + sway * 0.5
                    let r = 4 + cycle * 8
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 1.6)),
                             with: .color(.white.opacity((1 - cycle) * 0.4)))
                } else {
                    // Droplets shaking loose down the sides.
                    let x = c.x + (fract(seed * 0.53) - 0.5) * size.width * 0.55
                    let y = c.y + cycle * size.height * 0.42
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 2.2, y: y - 3.2, width: 4.4, height: 6.4)),
                             with: .color(accent.opacity((1 - cycle) * 0.7)))
                }
            }
        }
    }
}

// MARK: - Matter art

private struct IceCubeView: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(red: 0.80, green: 0.93, blue: 1.0),
                                                  Color(red: 0.52, green: 0.76, blue: 0.95)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.7), lineWidth: 1.4))
                Path { p in
                    p.move(to: CGPoint(x: 14, y: 40)); p.addLine(to: CGPoint(x: 36, y: 14))
                    p.move(to: CGPoint(x: 26, y: 48)); p.addLine(to: CGPoint(x: 48, y: 24))
                }
                .stroke(.white.opacity(0.55), lineWidth: 1.4)
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6 + 0.4 * sin(t * 3)))
                    .offset(x: -15, y: -15)
            }
            .frame(width: 58, height: 58)
            .shadow(color: Color(red: 0.5, green: 0.8, blue: 1.0).opacity(0.5), radius: 9)
        }
    }
}

private struct WaterDropView: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let wobbleX = 1 + 0.06 * sin(t * 5)
            let wobbleY = 1 - 0.06 * sin(t * 5)
            ZStack {
                DropletShape()
                    .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.75, blue: 1.0),
                                                  Color(red: 0.16, green: 0.45, blue: 0.85)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(DropletShape().stroke(.white.opacity(0.5), lineWidth: 1.2))
                Circle()
                    .fill(.white.opacity(0.65))
                    .frame(width: 7, height: 7)
                    .offset(x: -7, y: 4)
                Text("f")
                    .font(.system(size: 17, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.85))
                    .offset(y: 8)
            }
            .frame(width: 42, height: 52)
            .scaleEffect(x: wobbleX, y: wobbleY)
            .shadow(color: Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.5), radius: 9)
        }
    }
}

private struct DropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.62),
                   control1: CGPoint(x: rect.midX + w * 0.10, y: rect.minY + h * 0.22),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.36))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + h * 0.62),
                 radius: w / 2,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.36),
                   control2: CGPoint(x: rect.midX - w * 0.10, y: rect.minY + h * 0.22))
        p.closeSubpath()
        return p
    }
}

#Preview {
    MathItLevelOneHundredEighteenView(onContinue: {}, onLevelSelect: {})
}
