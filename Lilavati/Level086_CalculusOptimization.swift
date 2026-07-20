import SwiftUI
import Combine

struct MathItLevelOneHundredThirtyThreeView: View {
    private let cyan = Color(red: 0.20, green: 0.86, blue: 0.94)
    private let magenta = Color(red: 0.96, green: 0.31, blue: 0.68)
    private let gold = Color(red: 1.0, green: 0.72, blue: 0.17)
    private let coral = Color(red: 0.98, green: 0.34, blue: 0.28)
    private let surfaceTension = 0.025 // N/m, representative soapy water at room temperature
    private let minimumBubbleVolume = 12.0
    private let maximumBubbleVolume = 220.0
    private let targetBubbleCount = 3
    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var bubbles: [FilmBubble] = []
    @State private var ripples: [BubbleMergeRipple] = []
    @State private var connections: [BubbleConnection] = []
    @State private var labSize: CGSize = .zero
    @State private var lastTick = Date()
    @State private var charging = false
    @State private var charge: CGFloat = 0
    @State private var releasedCount = 0
    @State private var lastAreaDrop = 0.0
    @State private var solved = false
    @State private var completed = false
    @State private var completionScheduled = false

    private var flightBounds: CGRect {
        CGRect(x: 24, y: 82, width: max(0, labSize.width - 48), height: max(0, labSize.height - 182))
    }
    private var nozzlePoint: CGPoint {
        CGPoint(x: labSize.width / 2, y: max(110, labSize.height - 80))
    }
    private var chargedVolume: Double {
        minimumBubbleVolume + Double(charge) * (maximumBubbleVolume - minimumBubbleVolume)
    }
    private var previewRadius: CGFloat { visualRadius(volume: chargedVolume) }
    private var maximumPossibleAirVolume: Double { Double(targetBubbleCount) * maximumBubbleVolume }
    private var totalVolume: Double { bubbles.reduce(0) { $0 + $1.volume } }
    private var displayedVolume: Double { totalVolume + (charging ? chargedVolume : 0) }
    private var minimumSurfaceArea: Double {
        let separateArea = bubbles.reduce(0) { $0 + sphereArea(volume: $1.volume) }
        let sharedSavings = connections.reduce(0) { $0 + $1.savedArea }
        return max(0, separateArea - sharedSavings)
    }
    private var displayedMinimumArea: Double {
        minimumSurfaceArea + (charging ? sphereArea(volume: chargedVolume) : 0)
    }
    private var minimumSurfaceEnergy: Double {
        // cm² → m², joules → millijoules, and ×2 for the two sides of the film.
        2 * surfaceTension * displayedMinimumArea * 1e-4 * 1_000
    }
    private var activeRadius: Double {
        physicalRadius(volume: charging ? chargedVolume : (bubbles.last?.volume ?? 0))
    }
    private var allBubblesConnected: Bool {
        guard bubbles.count >= 3, let first = bubbles.first?.id else { return false }
        var visited: Set<UUID> = [first]
        var changed = true
        while changed {
            changed = false
            for connection in connections {
                if visited.contains(connection.firstID), !visited.contains(connection.secondID) {
                    visited.insert(connection.secondID)
                    changed = true
                } else if visited.contains(connection.secondID), !visited.contains(connection.firstID) {
                    visited.insert(connection.firstID)
                    changed = true
                }
            }
        }
        return visited.count == bubbles.count
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.006, green: 0.014, blue: 0.027).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header.padding(.top, compact ? 12 : 22)
                    bubbleChamber
                        .frame(maxWidth: 940)
                        .frame(height: max(500, min(650, proxy.size.height * 0.76)))
                    resetControl
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Minimum Film Cluster",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onReceive(tick) { now in advancePhysics(to: now) }
    }

    private var header: some View {
        VStack(spacing: 7) {
            Capsule()
                .fill(solved ? cyan : gold)
                .frame(width: solved ? 92 : 46, height: 5)
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: solved)

            EmptyView()
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(gold)

            EmptyView()
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(solved ? cyan : .white)
        }
    }

    private var bubbleChamber: some View {
        GeometryReader { geo in
            let bounds = CGRect(x: 24, y: 82, width: geo.size.width - 48, height: geo.size.height - 182)
            let nozzle = CGPoint(x: geo.size.width / 2, y: geo.size.height - 80)

            TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate * 1.7)

                ZStack {
                    Canvas { context, size in
                        drawBackground(context: &context, size: size, bounds: bounds, phase: phase)
                        drawBubbles(context: &context, phase: phase, now: timeline.date)
                        drawConnections(context: &context, now: timeline.date)
                        drawRipples(context: &context, now: timeline.date)
                        if charging {
                            drawBubbleSphere(
                                context: &context,
                                center: CGPoint(x: nozzle.x, y: nozzle.y - previewRadius - 8),
                                radius: previewRadius,
                                phase: phase,
                                hueOffset: 0.12,
                                inflation: charge
                            )
                        }
                    }

                    metrics
                    mergeGoal.position(x: geo.size.width / 2, y: 58)
                    dispenser(at: nozzle)

                    if lastAreaDrop > 0 {
                        Text("−\(number(lastAreaDrop)) cm²")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(cyan)
                            .shadow(color: cyan.opacity(0.75), radius: 8)
                            .position(x: geo.size.width / 2, y: bounds.minY + 28)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .background(Color(red: 0.012, green: 0.032, blue: 0.054))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(gold.opacity(0.25), lineWidth: 1))
            .onAppear {
                labSize = geo.size
                lastTick = Date()
            }
            .onChange(of: geo.size) { _, newSize in labSize = newSize }
        }
    }

    private var metrics: some View {
        VStack {
            HStack(spacing: 5) {
                metric(icon: "cube.transparent", label: "V / VMAX", value: "\(number(displayedVolume))/\(number(maximumPossibleAirVolume))", color: gold)
                metric(icon: "circle", label: "R", value: "\(number(activeRadius)) cm", color: coral)
                metric(icon: "circle.dotted", label: "A MIN", value: "\(number(displayedMinimumArea)) cm²", color: cyan)
                metric(icon: "bolt.fill", label: "E MIN", value: "\(energyNumber(minimumSurfaceEnergy)) mJ", color: magenta)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(10)
        .allowsHitTesting(false)
    }

    private var mergeGoal: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < min(releasedCount, 3) ? cyan.opacity(0.18) : .clear)
                    .overlay(Circle().stroke(index < min(releasedCount, 3) ? cyan : .white.opacity(0.28), lineWidth: 1.5))
                    .frame(width: 13 + CGFloat(index) * 2, height: 13 + CGFloat(index) * 2)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white.opacity(0.45))
            ZStack {
                Circle().frame(width: 18, height: 18).offset(x: -6, y: 4)
                Circle().frame(width: 18, height: 18).offset(x: 6, y: 4)
                Circle().frame(width: 18, height: 18).offset(y: -6)
            }
            .foregroundStyle(allBubblesConnected ? cyan.opacity(0.22) : .clear)
            .overlay {
                ZStack {
                    Circle().stroke(allBubblesConnected ? cyan : gold, lineWidth: 1.5).frame(width: 18, height: 18).offset(x: -6, y: 4)
                    Circle().stroke(allBubblesConnected ? cyan : gold, lineWidth: 1.5).frame(width: 18, height: 18).offset(x: 6, y: 4)
                    Circle().stroke(allBubblesConnected ? cyan : gold, lineWidth: 1.5).frame(width: 18, height: 18).offset(y: -6)
                }
            }
            .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.38), in: Capsule())
        .allowsHitTesting(false)
    }

    private func dispenser(at point: CGPoint) -> some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color.white.opacity(0.3), Color(red: 0.12, green: 0.17, blue: 0.22), .black], startPoint: .top, endPoint: .bottom))
                .frame(width: 32, height: 55)
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                .offset(y: 27)

            Capsule()
                .fill(Color(red: 0.18, green: 0.25, blue: 0.30))
                .frame(width: 58, height: 18)
                .overlay(Capsule().stroke(cyan.opacity(0.55), lineWidth: 2))
                .offset(y: 2)

            ZStack {
                Circle()
                    .fill(.black.opacity(0.84))
                Circle()
                    .trim(from: 0, to: max(0.02, charge))
                    .stroke(charging ? cyan : gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: charging ? "hand.tap.fill" : "hand.tap")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(charging ? cyan : .white)
                Text("HOLD")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .offset(y: 26)
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
            .offset(y: 58)
            .gesture(dispenserGesture)
            .accessibilityLabel("Hold to inflate a bubble and release to launch it")
        }
        .position(point)
    }

    private var dispenserGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !solved, releasedCount < targetBubbleCount else { return }
                if !charging {
                    charging = true
                    charge = 0
                }
            }
            .onEnded { _ in releaseChargedBubble() }
    }

    private var resetControl: some View {
        Button(action: resetLevel) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 58, height: 42)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.11), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func releaseChargedBubble() {
        guard charging, !solved, labSize.width > 0 else {
            charging = false
            return
        }

        let volume = chargedVolume
        let radius = visualRadius(volume: volume)
        let directions: [CGFloat] = [-1, 1, -0.55, 0.65, -0.25, 0.3]
        let direction = directions[releasedCount % directions.count]
        let speed = 38 + (1 - charge) * 34
        let start = CGPoint(x: nozzlePoint.x, y: flightBounds.maxY - radius - 4)
        let bubble = FilmBubble(
            position: start,
            velocity: CGVector(dx: direction * (18 + charge * 9), dy: -speed),
            volume: volume,
            age: 0,
            hueOffset: CGFloat(releasedCount % 5) * 0.14
        )

        bubbles.append(bubble)
        releasedCount += 1
        charging = false
        charge = 0
    }

    private func advancePhysics(to now: Date) {
        let dt = min(1.0 / 30.0, max(0, now.timeIntervalSince(lastTick)))
        lastTick = now
        guard labSize.width > 0 else { return }

        if charging {
            charge = min(1, charge + CGFloat(dt / 1.65))
        }

        guard !bubbles.isEmpty, !solved else { return }
        let bounds = flightBounds
        let centerX = bounds.midX

        for index in bubbles.indices {
            var bubble = bubbles[index]
            let radius = visualRadius(volume: bubble.volume)
            bubble.age += dt
            bubble.velocity.dy -= 5.5 * dt
            bubble.velocity.dx += (centerX - bubble.position.x) * 0.055 * dt
            bubble.velocity.dx *= 0.998
            bubble.velocity.dy *= 0.999
            bubble.position.x += bubble.velocity.dx * dt
            bubble.position.y += bubble.velocity.dy * dt

            if bubble.position.x - radius < bounds.minX {
                bubble.position.x = bounds.minX + radius
                bubble.velocity.dx = abs(bubble.velocity.dx) * 0.72
            } else if bubble.position.x + radius > bounds.maxX {
                bubble.position.x = bounds.maxX - radius
                bubble.velocity.dx = -abs(bubble.velocity.dx) * 0.72
            }

            if bubble.position.y - radius < bounds.minY {
                bubble.position.y = bounds.minY + radius
                bubble.velocity.dy = abs(bubble.velocity.dy) * 0.22
                bubble.velocity.dx += (centerX - bubble.position.x) * 0.035
            }

            bubbles[index] = bubble
        }

        applyConnectionForces(dt: dt)
        connectFirstCollision(now: now)
        ripples.removeAll { now.timeIntervalSince($0.createdAt) > 0.9 }
        checkForCompletion()
    }

    private func applyConnectionForces(dt: TimeInterval) {
        for connection in connections {
            guard
                let firstIndex = bubbles.firstIndex(where: { $0.id == connection.firstID }),
                let secondIndex = bubbles.firstIndex(where: { $0.id == connection.secondID })
            else { continue }

            var first = bubbles[firstIndex]
            var second = bubbles[secondIndex]
            let dx = second.position.x - first.position.x
            let dy = second.position.y - first.position.y
            let distance = max(0.001, hypot(dx, dy))
            let nx = dx / distance
            let ny = dy / distance
            let target = (visualRadius(volume: first.volume) + visualRadius(volume: second.volume)) * 0.78
            let error = distance - target
            let relativeSpeed = (second.velocity.dx - first.velocity.dx) * nx + (second.velocity.dy - first.velocity.dy) * ny
            let impulse = (error * 5.2 + relativeSpeed * 0.55) * dt

            first.velocity.dx += nx * impulse
            first.velocity.dy += ny * impulse
            second.velocity.dx -= nx * impulse
            second.velocity.dy -= ny * impulse

            let correction = error * 0.055
            first.position.x += nx * correction
            first.position.y += ny * correction
            second.position.x -= nx * correction
            second.position.y -= ny * correction

            bubbles[firstIndex] = first
            bubbles[secondIndex] = second
        }
    }

    private func connectFirstCollision(now: Date) {
        guard bubbles.count > 1 else { return }

        for first in 0..<(bubbles.count - 1) {
            for second in (first + 1)..<bubbles.count {
                guard bubbles[first].age > 0.22, bubbles[second].age > 0.22 else { continue }
                let firstID = bubbles[first].id
                let secondID = bubbles[second].id
                guard !connections.contains(where: {
                    ($0.firstID == firstID && $0.secondID == secondID) ||
                    ($0.firstID == secondID && $0.secondID == firstID)
                }) else { continue }
                let dx = bubbles[second].position.x - bubbles[first].position.x
                let dy = bubbles[second].position.y - bubbles[first].position.y
                let distance = hypot(dx, dy)
                let r1 = visualRadius(volume: bubbles[first].volume)
                let r2 = visualRadius(volume: bubbles[second].volume)
                guard distance < (r1 + r2) * 0.88 else { continue }

                let midpoint = CGPoint(
                    x: (bubbles[first].position.x + bubbles[second].position.x) / 2,
                    y: (bubbles[first].position.y + bubbles[second].position.y) / 2
                )
                let geometry = optimizedDoubleBubble(
                    volume1: bubbles[first].volume,
                    volume2: bubbles[second].volume
                )
                let saved = geometry.savedArea
                connections.append(BubbleConnection(
                    firstID: firstID,
                    secondID: secondID,
                    createdAt: now,
                    savedArea: saved,
                    sharedRadius: geometry.sharedRadius
                ))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) { lastAreaDrop = saved }
                ripples.append(BubbleMergeRipple(center: midpoint, createdAt: now, baseRadius: min(r1, r2)))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.25)) { lastAreaDrop = 0 }
                }
                return
            }
        }
    }

    private func checkForCompletion() {
        guard releasedCount >= 3, allBubblesConnected, !charging, !completionScheduled else { return }
        completionScheduled = true
        solved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.45)) { completed = true }
        }
    }

    private func resetLevel() {
        bubbles = []
        ripples = []
        connections = []
        charging = false
        charge = 0
        releasedCount = 0
        lastAreaDrop = 0
        solved = false
        completed = false
        completionScheduled = false
        lastTick = Date()
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize, bounds: CGRect, phase: CGFloat) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(red: 0.025, green: 0.34, blue: 0.43), Color(red: 0.004, green: 0.10, blue: 0.16)]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: size.height)
        ))

        for index in 0..<7 {
            let fraction = CGFloat(index) / 6
            let x = bounds.minX + fraction * bounds.width
            let y = bounds.minY + 18 + sin(phase * 0.35 + CGFloat(index) * 0.8) * 6
            let radius = CGFloat(5 + index % 3 * 3)
            context.stroke(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(cyan.opacity(0.08)), lineWidth: 1)
        }

        context.stroke(Path(roundedRect: bounds, cornerRadius: 22), with: .color(.white.opacity(0.08)), lineWidth: 1)
        var floor = Path()
        floor.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        floor.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        context.stroke(floor, with: .color(.white.opacity(0.12)), lineWidth: 1)
    }

    private func drawBubbles(context: inout GraphicsContext, phase: CGFloat, now _: Date) {
        for (index, bubble) in bubbles.enumerated() {
            drawBubbleSphere(
                context: &context,
                center: bubble.position,
                radius: visualRadius(volume: bubble.volume),
                phase: phase + CGFloat(index) * 0.8,
                hueOffset: bubble.hueOffset,
                inflation: 1
            )
        }
    }

    private func drawConnections(context: inout GraphicsContext, now: Date) {
        for connection in connections {
            guard
                let first = bubbles.first(where: { $0.id == connection.firstID }),
                let second = bubbles.first(where: { $0.id == connection.secondID })
            else { continue }
            let reveal = min(1, CGFloat(now.timeIntervalSince(connection.createdAt) / 0.42))
            let firstScale = visualRadius(volume: first.volume) / CGFloat(max(0.001, physicalRadius(volume: first.volume)))
            let secondScale = visualRadius(volume: second.volume) / CGFloat(max(0.001, physicalRadius(volume: second.volume)))
            let membraneRadius = CGFloat(connection.sharedRadius) * min(firstScale, secondScale)
            drawSharedMembrane(
                context: &context,
                firstCenter: first.position,
                secondCenter: second.position,
                radius: membraneRadius,
                opacity: 0.35 + reveal * 0.65
            )
        }
    }

    private func drawSharedMembrane(
        context: inout GraphicsContext,
        firstCenter: CGPoint,
        secondCenter: CGPoint,
        radius: CGFloat,
        opacity: CGFloat
    ) {
        guard opacity > 0.01 else { return }
        let midpoint = CGPoint(x: (firstCenter.x + secondCenter.x) / 2, y: (firstCenter.y + secondCenter.y) / 2)
        let angle = atan2(secondCenter.y - firstCenter.y, secondCenter.x - firstCenter.x) - .pi / 2
        let width = max(14, radius * 2)
        let height = max(5, radius * 0.20)
        var membrane = Path()
        membrane.move(to: CGPoint(x: -width / 2, y: 0))
        membrane.addCurve(
            to: CGPoint(x: width / 2, y: 0),
            control1: CGPoint(x: -width * 0.22, y: -height),
            control2: CGPoint(x: width * 0.22, y: -height)
        )
        membrane.addCurve(
            to: CGPoint(x: -width / 2, y: 0),
            control1: CGPoint(x: width * 0.22, y: height),
            control2: CGPoint(x: -width * 0.22, y: height)
        )
        membrane.closeSubpath()
        membrane = membrane.applying(CGAffineTransform(translationX: midpoint.x, y: midpoint.y).rotated(by: angle))

        context.stroke(membrane, with: .color(cyan.opacity(Double(opacity) * 0.20)), lineWidth: max(4, height * 0.9))
        context.fill(membrane, with: .linearGradient(
            Gradient(colors: [
                cyan.opacity(Double(opacity) * 0.20),
                magenta.opacity(Double(opacity) * 0.52),
                .white.opacity(Double(opacity) * 0.30),
                gold.opacity(Double(opacity) * 0.46),
                cyan.opacity(Double(opacity) * 0.18)
            ]),
            startPoint: CGPoint(x: midpoint.x - width / 2, y: midpoint.y),
            endPoint: CGPoint(x: midpoint.x + width / 2, y: midpoint.y)
        ))
        context.stroke(membrane, with: .color(.white.opacity(Double(opacity) * 0.68)), lineWidth: 1)

        var highlight = Path()
        highlight.move(to: CGPoint(x: -width * 0.36, y: -height * 0.22))
        highlight.addCurve(
            to: CGPoint(x: width * 0.30, y: -height * 0.18),
            control1: CGPoint(x: -width * 0.12, y: -height * 0.72),
            control2: CGPoint(x: width * 0.12, y: -height * 0.64)
        )
        highlight = highlight.applying(CGAffineTransform(translationX: midpoint.x, y: midpoint.y).rotated(by: angle))
        context.stroke(highlight, with: .color(.white.opacity(Double(opacity) * 0.70)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    }

    private func drawBubbleSphere(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        phase: CGFloat,
        hueOffset: CGFloat,
        inflation: CGFloat
    ) {
        let wobble = max(0.004, (1 - inflation) * 0.035 + 0.008)
        let path = bubblePath(center: center, radius: radius, wobble: wobble, phase: phase)

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.55), radius: radius * 0.18, x: radius * 0.08, y: radius * 0.16))
            layer.fill(path, with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.17),
                    Color(red: 0.06, green: 0.54, blue: 0.64).opacity(0.30 + hueOffset * 0.04),
                    Color(red: 0.015, green: 0.20, blue: 0.29).opacity(0.45),
                    magenta.opacity(0.12)
                ]),
                center: CGPoint(x: center.x - radius * 0.32, y: center.y - radius * 0.35),
                startRadius: 1,
                endRadius: radius * 1.06
            ))
        }

        drawWindowReflections(context: &context, clip: path, center: center, radius: radius)

        context.stroke(path, with: .color(cyan.opacity(0.18)), lineWidth: max(6, radius * 0.15))
        context.stroke(path, with: .color(magenta.opacity(0.28)), lineWidth: max(3, radius * 0.075))
        context.stroke(path, with: .linearGradient(
            Gradient(colors: [gold, cyan, .white.opacity(0.95), magenta, Color.green.opacity(0.8), gold]),
            startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
            endPoint: CGPoint(x: center.x + radius, y: center.y + radius)
        ), style: StrokeStyle(lineWidth: max(1.5, radius * 0.045), lineCap: .round, lineJoin: .round))

        let specular = CGRect(
            x: center.x - radius * 0.48,
            y: center.y - radius * 0.50,
            width: radius * 0.42,
            height: max(5, radius * 0.15)
        )
        context.stroke(Path(ellipseIn: specular), with: .color(.white.opacity(0.78)), style: StrokeStyle(lineWidth: max(1.2, radius * 0.035), lineCap: .round))

        let lowerBand = CGRect(x: center.x - radius * 0.56, y: center.y + radius * 0.23, width: radius * 1.12, height: radius * 0.30)
        context.stroke(Path(ellipseIn: lowerBand), with: .color(magenta.opacity(0.42)), lineWidth: max(0.8, radius * 0.02))

        let glint = CGRect(x: center.x + radius * 0.30, y: center.y - radius * 0.16, width: radius * 0.12, height: radius * 0.07)
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.7)))
    }

    private func drawWindowReflections(context: inout GraphicsContext, clip: Path, center: CGPoint, radius: CGFloat) {
        context.drawLayer { reflections in
            reflections.clip(to: clip)
            let paneWidth = max(3, radius * 0.105)
            let paneHeight = max(4, radius * 0.145)
            let colors = [cyan, Color.green, magenta, gold]
            let groupOffsets: [(CGFloat, CGFloat, CGFloat)] = [
                (-0.49, -0.20, -0.10),
                (0.29, -0.12, 0.08),
                (-0.10, 0.18, 0.02)
            ]

            for (groupIndex, group) in groupOffsets.enumerated() {
                for row in 0..<3 {
                    for column in 0..<2 {
                        let x = center.x + radius * group.0 + CGFloat(column) * paneWidth * 1.18
                        let y = center.y + radius * group.1 + CGFloat(row) * paneHeight * 1.10
                        let rect = CGRect(x: x, y: y, width: paneWidth, height: paneHeight)
                        let color = colors[(groupIndex + row + column) % colors.count]
                        reflections.fill(Path(roundedRect: rect, cornerRadius: paneWidth * 0.12), with: .color(color.opacity(0.13)))
                        reflections.stroke(Path(roundedRect: rect, cornerRadius: paneWidth * 0.12), with: .color(.white.opacity(0.08)), lineWidth: 0.6)
                    }
                }
            }

            for index in 0..<3 {
                let ovalRadius = radius * (0.08 + CGFloat(index) * 0.018)
                let oval = CGRect(
                    x: center.x - ovalRadius,
                    y: center.y - radius * 0.54 + CGFloat(index) * radius * 0.16,
                    width: ovalRadius * 2,
                    height: ovalRadius * 0.72
                )
                reflections.fill(Path(ellipseIn: oval), with: .color(cyan.opacity(0.12)))
            }
        }
    }

    private func drawRipples(context: inout GraphicsContext, now: Date) {
        for ripple in ripples {
            let progress = CGFloat(now.timeIntervalSince(ripple.createdAt) / 0.9)
            guard progress >= 0, progress <= 1 else { continue }
            let radius = ripple.baseRadius * (0.7 + progress * 1.65)
            let rect = CGRect(x: ripple.center.x - radius, y: ripple.center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(cyan.opacity(Double(1 - progress) * 0.65)), lineWidth: 2)
        }
    }

    private func bubblePath(center: CGPoint, radius: CGFloat, wobble: CGFloat, phase: CGFloat) -> Path {
        var path = Path()
        for sample in 0...100 {
            let angle = CGFloat(sample) / 100 * 2 * .pi
            let ripple = 1 + wobble * sin(angle * 3 + phase) + wobble * 0.45 * cos(angle * 5 - phase * 0.6)
            let point = CGPoint(x: center.x + cos(angle) * radius * ripple, y: center.y + sin(angle) * radius * ripple)
            sample == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func visualRadius(volume: Double) -> CGFloat {
        CGFloat(pow(max(1, volume), 1.0 / 3.0)) * 8.8
    }

    private func physicalRadius(volume: Double) -> Double {
        pow(3 * max(0, volume) / (4 * .pi), 1.0 / 3.0)
    }

    private func sphereArea(volume: Double) -> Double {
        let radius = physicalRadius(volume: volume)
        return 4 * .pi * radius * radius
    }

    private func sphericalCapVolume(baseRadius: Double, height: Double) -> Double {
        .pi * height * (3 * baseRadius * baseRadius + height * height) / 6
    }

    private func capHeight(volume: Double, baseRadius: Double) -> Double {
        var low = 0.0
        var high = max(0.1, physicalRadius(volume: volume) * 2)

        while sphericalCapVolume(baseRadius: baseRadius, height: high) < volume {
            high *= 2
        }

        for _ in 0..<48 {
            let middle = (low + high) / 2
            if sphericalCapVolume(baseRadius: baseRadius, height: middle) < volume {
                low = middle
            } else {
                high = middle
            }
        }
        return (low + high) / 2
    }

    private func optimizedDoubleBubble(volume1: Double, volume2: Double) -> DoubleBubbleGeometry {
        let separateArea = sphereArea(volume: volume1) + sphereArea(volume: volume2)
        let searchRadius = max(physicalRadius(volume: volume1), physicalRadius(volume: volume2))
        var bestArea = separateArea
        var bestSharedRadius = 0.0

        // Search the common membrane radius while each spherical cap preserves its exact air volume.
        for sample in 1...180 {
            let fraction = Double(sample) / 180
            let sharedRadius = searchRadius * (0.05 + 1.45 * fraction)
            let firstHeight = capHeight(volume: volume1, baseRadius: sharedRadius)
            let secondHeight = capHeight(volume: volume2, baseRadius: sharedRadius)
            let connectedArea = .pi * (
                firstHeight * firstHeight
                    + secondHeight * secondHeight
                    + 3 * sharedRadius * sharedRadius
            )

            if connectedArea < bestArea {
                bestArea = connectedArea
                bestSharedRadius = sharedRadius
            }
        }

        return DoubleBubbleGeometry(
            savedArea: max(0, separateArea - bestArea),
            sharedRadius: bestSharedRadius
        )
    }

    private func number(_ value: Double) -> String {
        let cleaned = abs(value) < 0.005 ? 0 : value
        if cleaned >= 100 { return String(Int(cleaned.rounded())) }
        return cleaned.rounded() == cleaned ? String(Int(cleaned)) : String(format: "%.1f", cleaned)
    }

    private func energyNumber(_ value: Double) -> String {
        String(format: "%.2f", abs(value) < 0.005 ? 0 : value)
    }

    private func metric(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                Text(value)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct FilmBubble: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var volume: Double
    var age: TimeInterval
    var hueOffset: CGFloat
}

private struct BubbleMergeRipple: Identifiable {
    let id = UUID()
    let center: CGPoint
    let createdAt: Date
    let baseRadius: CGFloat
}

private struct BubbleConnection: Identifiable {
    let id = UUID()
    let firstID: UUID
    let secondID: UUID
    let createdAt: Date
    let savedArea: Double
    let sharedRadius: Double
}

private struct DoubleBubbleGeometry {
    let savedArea: Double
    let sharedRadius: Double
}

#Preview {
    MathItLevelOneHundredThirtyThreeView(onContinue: {}, onLevelSelect: {})
}
