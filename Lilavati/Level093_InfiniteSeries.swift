import SwiftUI

struct MathItLevelOneHundredThirtyNineView: View {
    private let stages = RainbowSeriesStage.all
    private let gold = Color(red: 1.0, green: 0.70, blue: 0.18)
    private let cyan = Color(red: 0.25, green: 0.89, blue: 0.94)
    private let coral = Color(red: 0.97, green: 0.34, blue: 0.29)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var termPairs = 1
    @State private var solved = false
    @State private var completed = false
    @State private var feedback: RainbowSeriesFeedback?
    @State private var animationToken = UUID()
    @State private var snapshot = AirySeriesSnapshot.empty

    private var stage: RainbowSeriesStage { stages[stageIndex] }
    private var termCount: Int { termPairs * 2 }
    private var coefficientCount: Int { AirySeries.coefficientCount(forPairCount: termPairs) }
    private var accuracy: Double { snapshot.accuracy }
    private var meetsAccuracy: Bool { accuracy >= stage.requiredAccuracy }
    private var withinBudget: Bool { termPairs <= stage.maximumPairCount }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.015, green: 0.025, blue: 0.045),
                        Color(red: 0.045, green: 0.085, blue: 0.12),
                        Color(red: 0.09, green: 0.13, blue: 0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: compact ? 8 : 12) {
                    Spacer().frame(height: compact ? 78 : 92)

                    stageHeader

                    rainbowScene
                        .frame(maxWidth: 920)
                        .frame(height: max(370, min(545, proxy.size.height * 0.61)))

                    approximationControls(compact: compact)
                        .frame(maxWidth: 760)

                    Spacer(minLength: compact ? 64 : 76)
                }
                .padding(.horizontal, compact ? 12 : 18)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Rainbow Converged",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(100)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear { loadStage(0) }
    }

    private var stageHeader: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(stages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex || (index == stageIndex && solved) ? cyan : index == stageIndex ? gold : .white.opacity(0.14))
                        .frame(width: index == stageIndex ? 38 : 20, height: 4)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: stage.symbol)
                    .foregroundStyle(gold)
                Text(stage.name)
                Text("·")
                    .foregroundStyle(.white.opacity(0.28))
                Text("≥ \(percent(stage.requiredAccuracy))")
                    .foregroundStyle(cyan)

                if stageIndex > 0 {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.28))
                    Image(systemName: "sum")
                    Text("≤ \(stage.maximumPairCount * 2)")
                }
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.78))
        }
    }

    private var rainbowScene: some View {
        GeometryReader { _ in
            ZStack {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    Canvas { context, size in
                        drawSun(context: &context, size: size)
                        drawAtmosphere(context: &context, size: size, time: time)
                        drawDroplets(context: &context, size: size, time: time)
                    }
                }

                Canvas { context, size in
                    drawOpticalPath(context: &context, size: size)
                    drawRainbow(context: &context, size: size, target: true)
                    drawRainbow(context: &context, size: size, target: false)
                    drawIntensityPlot(context: &context, size: size)
                }
            }
            .overlay(alignment: .topLeading) {
                seriesReadout
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                accuracyMeter
                    .padding(12)
            }
            .overlay(alignment: .bottom) {
                if let feedback {
                    feedbackBanner(feedback)
                        .padding(.bottom, 12)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.08, blue: 0.13),
                        Color(red: 0.09, green: 0.15, blue: 0.19),
                        Color(red: 0.16, green: 0.20, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.mathGold.opacity(0.28), lineWidth: 1))
        }
    }

    private var seriesReadout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sum")
                    .foregroundStyle(gold)
                Text("Sₙ(x)")
                    .foregroundStyle(.white)
                Text("→")
                    .foregroundStyle(.white.opacity(0.42))
                Text("Ai(x)")
                    .foregroundStyle(cyan)
            }
            .font(.system(size: 12, weight: .black, design: .monospaced))

            Text("\(termCount) TERMS · ORDER \(coefficientCount - 1)")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 5))
    }

    private var accuracyMeter: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 7)

            Circle()
                .trim(from: 0, to: accuracy)
                .stroke(
                    meetsAccuracy ? cyan : gold,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(percent(accuracy))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                Image(systemName: meetsAccuracy ? "checkmark" : "scope")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(meetsAccuracy ? cyan : gold)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 72, height: 72)
        .padding(7)
        .background(.black.opacity(0.42), in: Circle())
        .accessibilityLabel("Approximation accuracy \(percent(accuracy))")
    }

    private func approximationControls(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 11) {
            HStack(spacing: 12) {
                Image(systemName: "sum")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(gold)

                Slider(
                    value: Binding(
                        get: { Double(termPairs) },
                        set: { value in
                            let next = Int(value.rounded())
                            guard next != termPairs else { return }
                            termPairs = next
                            snapshot = AirySeries.snapshot(pairCount: next, over: stage.domain)
                            clearFeedback()
                        }
                    ),
                    in: 1...12,
                    step: 1
                )
                .tint(accuracy >= stage.requiredAccuracy ? cyan : gold)
                .disabled(solved)

                Text("\(termCount)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 30, alignment: .trailing)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aiₙ(x) = Σ cₖxᵏ")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(cyan)

                    HStack(spacing: 8) {
                        Label(percent(stage.requiredAccuracy), systemImage: "scope")
                        if stageIndex > 0 {
                            Label("\(stage.maximumPairCount * 2)", systemImage: "sum")
                        }
                        Text("ε = \(decimal(1 - accuracy))")
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.54))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: checkApproximation) {
                    Image(systemName: solved ? "checkmark" : "rainbow")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 56, height: 48)
                        .background(solved ? cyan : gold, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(solved)
                .accessibilityLabel("Check rainbow approximation")
            }
        }
    }

    private func checkApproximation() {
        guard !solved else { return }
        animationToken = UUID()
        let token = animationToken
        HapticPlayer.playLightTap()

        guard meetsAccuracy else {
            feedback = .moreTerms
            return
        }

        guard withinBudget else {
            feedback = .fewerTerms
            return
        }

        solved = true
        feedback = .converged
        HapticPlayer.playCompletionTap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            guard token == animationToken else { return }
            if stageIndex == stages.count - 1 {
                withAnimation(.easeInOut(duration: 0.4)) { completed = true }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    loadStage(stageIndex + 1)
                }
            }
        }
    }

    private func clearFeedback() {
        guard !solved else { return }
        animationToken = UUID()
        feedback = nil
    }

    private func loadStage(_ index: Int) {
        animationToken = UUID()
        let nextIndex = min(index, stages.count - 1)
        stageIndex = nextIndex
        termPairs = 1
        snapshot = AirySeries.snapshot(pairCount: 1, over: stages[nextIndex].domain)
        solved = false
        feedback = nil
    }

    private func resetLevel() {
        completed = false
        loadStage(0)
    }

    private func feedbackBanner(_ value: RainbowSeriesFeedback) -> some View {
        Label(value.message, systemImage: value.symbol)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(value == .converged ? .black : .white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(value == .converged ? cyan : .black.opacity(0.74), in: Capsule())
            .overlay(Capsule().stroke((value == .converged ? cyan : coral).opacity(0.72), lineWidth: 1))
    }

    private func drawAtmosphere(context: inout GraphicsContext, size: CGSize, time: Double) {
        let brightness = CGFloat(accuracy)
        let cloudOpacity = 0.66 - brightness * 0.34
        let rainOpacity = 0.62 - brightness * 0.20
        let elapsed = CGFloat(time.truncatingRemainder(dividingBy: 12))
        let horizon = size.height * 0.88

        for index in 0..<7 {
            let x = size.width * (CGFloat(index) / 6) - 25 + sin(CGFloat(time) * 0.08 + CGFloat(index)) * 12
            let y = 32 + CGFloat(index % 3) * 23
            drawCloud(
                context: &context,
                center: CGPoint(x: x, y: y),
                scale: 0.9 + CGFloat(index % 2) * 0.25,
                opacity: cloudOpacity
            )
        }

        for index in 0..<84 {
            let xSeed = rainUnit(index * 17 + 3)
            let ySeed = rainUnit(index * 29 + 11)
            let speedSeed = rainUnit(index * 43 + 7)
            let speed = 0.34 + speedSeed * 0.42
            let cycle = (ySeed + elapsed * speed).truncatingRemainder(dividingBy: 1)
            let x = -12 + xSeed * (size.width + 24) + sin(elapsed * 0.38 + CGFloat(index)) * 2.5
            let y = -24 + cycle * (horizon + 42)
            let length = 7 + rainUnit(index * 61 + 19) * 12
            let slant = 2.5 + length * 0.24

            var drop = Path()
            drop.move(to: CGPoint(x: x, y: y))
            drop.addLine(to: CGPoint(x: x - slant, y: y + length))
            context.stroke(
                drop,
                with: .color(cyan.opacity(rainOpacity * (0.44 + speedSeed * 0.56))),
                style: StrokeStyle(lineWidth: 0.7 + speedSeed * 0.8, lineCap: .round)
            )

            if index % 11 == 0, cycle > 0.92 {
                let splashProgress = (cycle - 0.92) / 0.08
                let splashRadius = 2 + splashProgress * 7
                var splash = Path()
                splash.addArc(
                    center: CGPoint(x: x - slant, y: horizon),
                    radius: splashRadius,
                    startAngle: .degrees(205),
                    endAngle: .degrees(335),
                    clockwise: false
                )
                context.stroke(
                    splash,
                    with: .color(cyan.opacity((1 - splashProgress) * rainOpacity * 0.55)),
                    lineWidth: 0.8
                )
            }
        }

        var land = Path()
        land.move(to: CGPoint(x: 0, y: horizon))
        land.addCurve(
            to: CGPoint(x: size.width, y: horizon - 8),
            control1: CGPoint(x: size.width * 0.27, y: horizon - 28),
            control2: CGPoint(x: size.width * 0.72, y: horizon + 14)
        )
        land.addLine(to: CGPoint(x: size.width, y: size.height))
        land.addLine(to: CGPoint(x: 0, y: size.height))
        land.closeSubpath()
        context.fill(land, with: .color(Color(red: 0.035, green: 0.09, blue: 0.09)))
    }

    private func drawSun(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.11, y: size.height * 0.15)
        let radius = min(size.width, size.height) * 0.048

        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius * 2.2,
                y: center.y - radius * 2.2,
                width: radius * 4.4,
                height: radius * 4.4
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color.yellow.opacity(0.34),
                    gold.opacity(0.12),
                    Color.clear
                ]),
                center: center,
                startRadius: radius * 0.45,
                endRadius: radius * 2.2
            )
        )

        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 6
            let inner = radius * 1.35
            let outer = radius * (index.isMultiple(of: 2) ? 1.78 : 1.62)
            var ray = Path()
            ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            context.stroke(ray, with: .color(Color.yellow.opacity(0.48)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [Color.white, Color.yellow, gold]),
                center: CGPoint(x: center.x - radius * 0.25, y: center.y - radius * 0.25),
                startRadius: 0,
                endRadius: radius * 1.15
            )
        )
    }

    private func drawCloud(context: inout GraphicsContext, center: CGPoint, scale: CGFloat, opacity: CGFloat) {
        let circles: [(CGFloat, CGFloat, CGFloat)] = [(-24, 4, 17), (-8, -5, 23), (14, 0, 20), (31, 6, 13)]
        for item in circles {
            let radius = item.2 * scale
            let rect = CGRect(
                x: center.x + item.0 * scale - radius,
                y: center.y + item.1 * scale - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.20, green: 0.25, blue: 0.28).opacity(opacity)))
        }
    }

    private func drawOpticalPath(context: inout GraphicsContext, size: CGSize) {
        let sun = CGPoint(x: size.width * 0.11, y: size.height * 0.15)
        let droplet = CGPoint(x: size.width * 0.72, y: size.height * 0.24)
        let radius = min(size.width, size.height) * 0.047
        let beamOpacity = 0.35 + accuracy * 0.34
        let spectrum: [Color] = [
            Color(red: 0.66, green: 0.23, blue: 0.94),
            Color(red: 0.28, green: 0.35, blue: 0.98),
            Color(red: 0.15, green: 0.72, blue: 0.98),
            Color(red: 0.22, green: 0.86, blue: 0.42),
            Color(red: 1.0, green: 0.86, blue: 0.15),
            Color(red: 1.0, green: 0.47, blue: 0.10),
            Color(red: 0.95, green: 0.18, blue: 0.16)
        ]

        // A soft fan of sunlight reads more naturally than one rigid laser-like beam.
        for index in -3...3 {
            let spread = CGFloat(index)
            let start = CGPoint(
                x: sun.x + radius * (0.58 + abs(spread) * 0.025),
                y: sun.y + spread * radius * 0.20
            )
            let end = CGPoint(
                x: droplet.x - radius * 0.91,
                y: droplet.y - radius * 0.36 + spread * 0.42
            )
            var ray = Path()
            ray.move(to: start)
            ray.addLine(to: end)
            context.stroke(
                ray,
                with: .color(Color(red: 1.0, green: 0.91, blue: 0.62).opacity(beamOpacity * 0.10)),
                style: StrokeStyle(lineWidth: 5.5 - abs(spread) * 0.45, lineCap: .round)
            )
            context.stroke(
                ray,
                with: .color(Color.white.opacity(beamOpacity * (index == 0 ? 0.34 : 0.13))),
                style: StrokeStyle(lineWidth: index == 0 ? 1.15 : 0.65, lineCap: .round)
            )
        }

        let dropletRect = CGRect(x: droplet.x - radius, y: droplet.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: dropletRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.46),
                    cyan.opacity(0.18),
                    Color(red: 0.10, green: 0.45, blue: 0.62).opacity(0.38)
                ]),
                center: CGPoint(x: droplet.x - radius * 0.34, y: droplet.y - radius * 0.38),
                startRadius: 0,
                endRadius: radius * 1.12
            )
        )
        context.stroke(Path(ellipseIn: dropletRect), with: .color(.white.opacity(0.74)), lineWidth: 1.5)

        context.drawLayer { dropContext in
            dropContext.clip(to: Path(ellipseIn: dropletRect))
            for index in spectrum.indices {
                let separation = CGFloat(index) - CGFloat(spectrum.count - 1) / 2
                let offset = separation * radius * 0.075
                var colorPath = Path()
                colorPath.move(to: CGPoint(x: droplet.x - radius, y: droplet.y - radius * 0.34 + offset))
                colorPath.addLine(to: CGPoint(x: droplet.x + radius * 0.80, y: droplet.y - radius * 0.03 + offset))
                colorPath.addLine(to: CGPoint(x: droplet.x + radius * 0.08, y: droplet.y + radius + offset))
                dropContext.stroke(
                    colorPath,
                    with: .color(spectrum[index].opacity(0.54 + accuracy * 0.28)),
                    style: StrokeStyle(lineWidth: max(0.9, radius * 0.055), lineCap: .round, lineJoin: .round)
                )
            }
        }

        var highlight = Path()
        highlight.addArc(
            center: droplet,
            radius: radius * 0.72,
            startAngle: .degrees(198),
            endAngle: .degrees(286),
            clockwise: false
        )
        context.stroke(highlight, with: .color(.white.opacity(0.64)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        let entry = CGPoint(x: droplet.x - radius * 0.91, y: droplet.y - radius * 0.36)
        let reflection = CGPoint(x: droplet.x + radius * 0.82, y: droplet.y - radius * 0.05)
        let exit = CGPoint(x: droplet.x + radius * 0.10, y: droplet.y + radius * 0.94)
        var internalRay = Path()
        internalRay.move(to: entry)
        internalRay.addLine(to: reflection)
        internalRay.addLine(to: exit)
        context.stroke(
            internalRay,
            with: .linearGradient(
                Gradient(colors: [Color.yellow, Color.white, gold]),
                startPoint: entry,
                endPoint: exit
            ),
            style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: reflection.x - 2.5, y: reflection.y - 2.5, width: 5, height: 5)),
            with: .color(.white)
        )

        let magnifier = CGPoint(x: size.width * 0.46, y: size.height * 0.36)
        let magnifierRadius = min(size.width, size.height) * 0.145
        let destination = CGPoint(x: size.width * 0.08, y: size.height * 0.80)
        let dx = exit.x - destination.x
        let dy = exit.y - destination.y
        let distance = max(1, hypot(dx, dy))
        let direction = CGPoint(x: dx / distance, y: dy / distance)
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)

        // The real spectrum is narrow; the circular inset makes its separation visible.
        for index in spectrum.indices {
            let separation = CGFloat(index) - CGFloat(spectrum.count - 1) / 2
            let offset = separation * 0.65
            var ray = Path()
            ray.move(to: CGPoint(x: exit.x + perpendicular.x * offset, y: exit.y + perpendicular.y * offset))
            ray.addLine(to: CGPoint(x: destination.x + perpendicular.x * offset, y: destination.y + perpendicular.y * offset))
            context.stroke(
                ray,
                with: .color(spectrum[index].opacity(0.28 + accuracy * 0.52)),
                style: StrokeStyle(lineWidth: 1.25, lineCap: .round)
            )
        }

        let lensRect = CGRect(
            x: magnifier.x - magnifierRadius,
            y: magnifier.y - magnifierRadius,
            width: magnifierRadius * 2,
            height: magnifierRadius * 2
        )
        let lensPath = Path(ellipseIn: lensRect)
        context.fill(
            lensPath,
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.25), cyan.opacity(0.20), Color(red: 0.02, green: 0.12, blue: 0.18).opacity(0.96)]),
                center: CGPoint(x: magnifier.x - magnifierRadius * 0.28, y: magnifier.y - magnifierRadius * 0.32),
                startRadius: 0,
                endRadius: magnifierRadius
            )
        )

        context.drawLayer { lensContext in
            lensContext.clip(to: lensPath)

            for index in spectrum.indices {
                let separation = CGFloat(index) - CGFloat(spectrum.count - 1) / 2
                let offset = separation * 5.2
                let start = CGPoint(
                    x: magnifier.x - direction.x * magnifierRadius * 1.45 + perpendicular.x * offset,
                    y: magnifier.y - direction.y * magnifierRadius * 1.45 + perpendicular.y * offset
                )
                let end = CGPoint(
                    x: magnifier.x + direction.x * magnifierRadius * 1.45 + perpendicular.x * offset,
                    y: magnifier.y + direction.y * magnifierRadius * 1.45 + perpendicular.y * offset
                )
                var enlargedRay = Path()
                enlargedRay.move(to: start)
                enlargedRay.addLine(to: end)
                lensContext.stroke(
                    enlargedRay,
                    with: .color(spectrum[index].opacity(0.78 + accuracy * 0.20)),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
            }

            var enlargedHighlight = Path()
            enlargedHighlight.addArc(
                center: magnifier,
                radius: magnifierRadius * 0.72,
                startAngle: .degrees(194),
                endAngle: .degrees(270),
                clockwise: false
            )
            lensContext.stroke(enlargedHighlight, with: .color(.white.opacity(0.52)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        context.stroke(lensPath, with: .color(cyan.opacity(0.48)), lineWidth: 5)
        context.stroke(lensPath, with: .color(.white.opacity(0.82)), lineWidth: 1.5)
    }

    private func drawDroplets(context: inout GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<12 {
            let xSeed = rainUnit(index * 73 + 5)
            let ySeed = rainUnit(index * 89 + 13)
            let point = CGPoint(
                x: size.width * (0.13 + xSeed * 0.76) + sin(time * 0.42 + Double(index)) * 2.2,
                y: size.height * (0.20 + ySeed * 0.47) + cos(time * 0.56 + Double(index) * 0.7) * 3.0
            )
            let dropRadius = CGFloat(2.4 + rainUnit(index * 101 + 23) * 2.8)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - dropRadius, y: point.y - dropRadius, width: dropRadius * 2, height: dropRadius * 2.3)),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.85), cyan.opacity(0.22)]),
                    center: CGPoint(x: point.x - 1, y: point.y - 1),
                    startRadius: 0,
                    endRadius: dropRadius * 1.3
                )
            )
        }
    }

    private func rainUnit(_ value: Int) -> CGFloat {
        let raw = sin(Double(value) * 12.9898) * 43_758.5453
        return CGFloat(raw - floor(raw))
    }

    private func drawRainbow(context: inout GraphicsContext, size: CGSize, target: Bool) {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 1.08)
        let baseRadius = min(size.width * 0.59, size.height * 0.82)
        let colors: [Color] = [
            Color(red: 0.96, green: 0.22, blue: 0.22),
            Color(red: 1.0, green: 0.52, blue: 0.12),
            Color(red: 1.0, green: 0.87, blue: 0.20),
            Color(red: 0.25, green: 0.82, blue: 0.44),
            Color(red: 0.18, green: 0.78, blue: 0.94),
            Color(red: 0.25, green: 0.40, blue: 0.94),
            Color(red: 0.65, green: 0.30, blue: 0.90)
        ]

        let samples = target ? snapshot.targetSamples : snapshot.approximationSamples
        guard samples.count > 1 else { return }
        let sampleCount = samples.count
        let fullMaximum = snapshot.fullMaximum

        if target {
            for sample in samples.indices {
                let ratio = Double(sample) / Double(sampleCount - 1)
                let normalized = min(1, max(0, samples[sample] / max(0.0001, fullMaximum)))
                let radius = baseRadius + CGFloat(ratio - 0.5) * 62
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(199),
                    endAngle: .degrees(341),
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(.white.opacity(0.018 + normalized * 0.12)),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 6])
                )
            }
            return
        }

        for colorIndex in colors.indices {
            for sample in 0..<sampleCount {
                let ratio = Double(sample) / Double(sampleCount - 1)
                let rawIntensity = samples[sample]
                let normalized = min(1, max(0, rawIntensity / max(0.0001, fullMaximum)))
                let radialOffset = CGFloat(ratio - 0.5) * 62
                let radius = baseRadius + radialOffset + CGFloat(colorIndex - 3) * 2.8
                let start = 198.0 + Double(sample) * 0.03
                let end = 342.0 - Double(sampleCount - sample) * 0.03

                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    clockwise: false
                )

                context.stroke(
                    arc,
                    with: .color(colors[colorIndex].opacity(0.015 + normalized * (0.23 + accuracy * 0.40))),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
            }
        }
    }

    private func drawIntensityPlot(context: inout GraphicsContext, size: CGSize) {
        let plot = CGRect(x: 14, y: size.height - 96, width: min(220, size.width * 0.48), height: 78)
        context.fill(Path(roundedRect: plot, cornerRadius: 5), with: .color(.black.opacity(0.48)))
        context.stroke(Path(roundedRect: plot, cornerRadius: 5), with: .color(.white.opacity(0.14)), lineWidth: 1)

        let fullMaximum = snapshot.fullMaximum
        let targetSamples = snapshot.targetSamples
        let approximationSamples = snapshot.approximationSamples
        guard targetSamples.count > 1, targetSamples.count == approximationSamples.count else { return }

        func point(_ sample: Int, _ intensity: Double) -> CGPoint {
            let ratio = Double(sample) / Double(targetSamples.count - 1)
            return CGPoint(
                x: plot.minX + 8 + CGFloat(ratio) * (plot.width - 16),
                y: plot.maxY - 10 - CGFloat(min(1.15, intensity / max(0.0001, fullMaximum))) * (plot.height - 23)
            )
        }

        var targetPath = Path()
        var approximationPath = Path()

        for sample in targetSamples.indices {
            let targetPoint = point(sample, targetSamples[sample])
            let approximationPoint = point(sample, approximationSamples[sample])
            sample == 0 ? targetPath.move(to: targetPoint) : targetPath.addLine(to: targetPoint)
            sample == 0 ? approximationPath.move(to: approximationPoint) : approximationPath.addLine(to: approximationPoint)
        }

        context.stroke(targetPath, with: .color(.white.opacity(0.70)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        context.stroke(approximationPath, with: .color(gold), lineWidth: 2)

        context.draw(
            Text("I(x) = Ai(x)²")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58)),
            at: CGPoint(x: plot.midX, y: plot.minY + 7)
        )
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func decimal(_ value: Double) -> String {
        String(format: "%.3f", max(0, value))
    }
}

private enum AirySeries {
    static let fullCoefficientCount = 50

    static let coefficients: [Double] = {
        var values = Array(repeating: 0.0, count: fullCoefficientCount)
        values[0] = 0.355_028_053_887_817
        values[1] = -0.258_819_403_792_807
        values[2] = 0

        for index in 3..<values.count {
            values[index] = values[index - 3] / Double(index * (index - 1))
        }
        return values
    }()

    static func coefficientCount(forPairCount pairCount: Int) -> Int {
        min(fullCoefficientCount, 2 + max(0, pairCount - 1) * 3)
    }

    static func value(_ x: Double, coefficientCount: Int) -> Double {
        let count = min(max(1, coefficientCount), coefficients.count)
        var sum = 0.0
        var power = 1.0

        for index in 0..<count {
            sum += coefficients[index] * power
            power *= x
        }
        return sum
    }

    static func intensity(_ x: Double, coefficientCount: Int) -> Double {
        let airy = value(x, coefficientCount: coefficientCount)
        return airy * airy
    }

    static func snapshot(pairCount: Int, over domain: ClosedRange<Double>) -> AirySeriesSnapshot {
        let approximationCount = coefficientCount(forPairCount: pairCount)
        var squaredError = 0.0
        var targetEnergy = 0.0
        var fullMaximum = 0.0001

        for sample in 0...220 {
            let x = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(sample) / 220
            let target = intensity(x, coefficientCount: fullCoefficientCount)
            let approximation = intensity(x, coefficientCount: approximationCount)
            let difference = target - approximation
            squaredError += difference * difference
            targetEnergy += target * target
            fullMaximum = max(fullMaximum, target)
        }

        let accuracy = targetEnergy > 0
            ? max(0, min(1, 1 - sqrt(squaredError / targetEnergy)))
            : 0

        var targetSamples: [Double] = []
        var approximationSamples: [Double] = []
        targetSamples.reserveCapacity(49)
        approximationSamples.reserveCapacity(49)

        for sample in 0...48 {
            let x = domain.lowerBound + (domain.upperBound - domain.lowerBound) * Double(sample) / 48
            targetSamples.append(intensity(x, coefficientCount: fullCoefficientCount))
            approximationSamples.append(intensity(x, coefficientCount: approximationCount))
        }

        return AirySeriesSnapshot(
            accuracy: accuracy,
            fullMaximum: fullMaximum,
            targetSamples: targetSamples,
            approximationSamples: approximationSamples
        )
    }
}

private struct AirySeriesSnapshot {
    let accuracy: Double
    let fullMaximum: Double
    let targetSamples: [Double]
    let approximationSamples: [Double]

    static let empty = AirySeriesSnapshot(
        accuracy: 0,
        fullMaximum: 1,
        targetSamples: [],
        approximationSamples: []
    )
}

private struct RainbowSeriesStage {
    let name: String
    let symbol: String
    let domain: ClosedRange<Double>
    let requiredAccuracy: Double
    let maximumPairCount: Int

    static let all = [
        RainbowSeriesStage(
            name: "PRIMARY BOW",
            symbol: "drop.fill",
            domain: -2.5...1.5,
            requiredAccuracy: 0.97,
            maximumPairCount: 12
        ),
        RainbowSeriesStage(
            name: "FINE BANDS",
            symbol: "wave.3.right",
            domain: -3.5...1.8,
            requiredAccuracy: 0.975,
            maximumPairCount: 6
        ),
        RainbowSeriesStage(
            name: "EFFICIENT MODEL",
            symbol: "gauge.with.dots.needle.50percent",
            domain: -4.5...2.0,
            requiredAccuracy: 0.99,
            maximumPairCount: 9
        )
    ]
}

private enum RainbowSeriesFeedback: Equatable {
    case moreTerms
    case fewerTerms
    case converged

    var message: String {
        switch self {
        case .moreTerms: "ADD TERMS · THE SERIES HAS NOT CONVERGED"
        case .fewerTerms: "ACCURATE, BUT USE FEWER TERMS"
        case .converged: "TARGET PATTERN MATCHED"
        }
    }

    var symbol: String {
        switch self {
        case .moreTerms: "plus"
        case .fewerTerms: "minus"
        case .converged: "checkmark"
        }
    }
}

#Preview {
    MathItLevelOneHundredThirtyNineView(onContinue: {}, onLevelSelect: {})
}
