import SwiftUI

struct MathItLevelOneHundredThirtyEightView: View {
    private let stages = PerfectSliceStage.all
    private let cyan = Color(red: 0.20, green: 0.86, blue: 0.94)
    private let gold = Color(red: 1.0, green: 0.72, blue: 0.17)
    private let coral = Color(red: 0.98, green: 0.34, blue: 0.28)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var guideDegrees = 65.0
    @State private var submitted = false
    @State private var correct = false
    @State private var cutProgress: CGFloat = 0
    @State private var distributionProgress: CGFloat = 0
    @State private var completed = false
    @State private var transitionScheduled = false

    private var stage: PerfectSliceStage { stages[stageIndex] }
    private var selectedArc: Double { stage.circumference * guideDegrees / 360 }
    private var isExact: Bool { abs(guideDegrees - stage.targetDegrees) < 0.1 }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.010, green: 0.018, blue: 0.028).ignoresSafeArea()

                bakeryBackdrop

                VStack(spacing: compact ? 8 : 12) {
                    Spacer().frame(height: compact ? 84 : 98)

                    stageProgress
                    givenReadout

                    pieBoard
                        .frame(maxWidth: 430)
                        .frame(height: min(390, max(310, proxy.size.height * 0.46)))

                    guideControls
                        .frame(maxWidth: 430)

                    Spacer(minLength: compact ? 68 : 78)
                }
                .padding(.horizontal, 16)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Arc Length",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear { loadStage(0) }
    }

    private var bakeryBackdrop: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let counterY = size.height * 0.73
                context.fill(
                    Path(CGRect(x: 0, y: counterY, width: size.width, height: size.height - counterY)),
                    with: .linearGradient(
                        Gradient(colors: [Color(red: 0.10, green: 0.07, blue: 0.08), .black]),
                        startPoint: CGPoint(x: 0, y: counterY),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                for row in 0..<7 {
                    let y = CGFloat(row) * 62 + 86
                    let offset = row.isMultiple(of: 2) ? CGFloat.zero : 34
                    for column in -1...8 {
                        let rect = CGRect(x: CGFloat(column) * 68 + offset, y: y, width: 66, height: 60)
                        context.stroke(Path(rect), with: .color(gold.opacity(0.035)), lineWidth: 1)
                    }
                }

                var counter = Path()
                counter.move(to: CGPoint(x: 0, y: counterY))
                counter.addLine(to: CGPoint(x: size.width, y: counterY))
                context.stroke(counter, with: .color(gold.opacity(0.20)), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }

    private var stageProgress: some View {
        HStack(spacing: 7) {
            ForEach(stages.indices, id: \.self) { index in
                Capsule()
                    .fill(index < stageIndex || (index == stageIndex && correct) ? cyan : index == stageIndex ? gold : .white.opacity(0.16))
                    .frame(width: index == stageIndex ? 34 : 18, height: 4)
            }
        }
    }

    private var givenReadout: some View {
        HStack(spacing: 10) {
            Label(stage.given, systemImage: stage.givenIcon)
            Divider().overlay(.white.opacity(0.16)).frame(height: 22)
            Label("n = \(stage.customers)", systemImage: "person.2.fill")
        }
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(.black.opacity(0.46), in: Capsule())
        .overlay(Capsule().stroke(gold.opacity(0.24), lineWidth: 1))
    }

    private var pieBoard: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let pieRadius = size * 0.245
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.70)
            let personSize = customerSize(for: stage.customers)

            ZStack {
                Canvas { context, _ in
                    drawPlate(context: &context, center: center, radius: pieRadius * 1.18)
                }

                Canvas { context, _ in
                    drawPie(context: &context, center: center, radius: pieRadius)
                    drawGuide(context: &context, center: center, radius: pieRadius)
                    if submitted {
                        drawCuts(context: &context, center: center, radius: pieRadius)
                    }
                }
                .opacity(1 - distributionProgress)

                ForEach(0..<stage.customers, id: \.self) { index in
                    DetailedPieCustomer(
                        index: index,
                        served: distributionProgress > 0.82,
                        accent: customerColor(index)
                    )
                    .frame(width: personSize.width, height: personSize.height)
                    .position(customerPosition(index: index, count: stage.customers, in: geo.size))
                    .zIndex(3)
                }

                if correct, cutProgress > 0.96 {
                    ForEach(0..<stage.customers, id: \.self) { index in
                        let destination = servingDestination(index: index, count: stage.customers, in: geo.size)
                        let position = interpolatedPoint(from: center, to: destination, progress: distributionProgress)
                        let finalScale = servingScale(for: stage.customers)
                        PieServingSlice(angleDegrees: stage.targetDegrees, color: customerColor(index))
                            .frame(width: pieRadius * 2, height: pieRadius * 2)
                            .rotationEffect(.degrees(Double(index) * stage.targetDegrees * Double(1 - distributionProgress)))
                            .scaleEffect(0.94 + (finalScale - 0.94) * distributionProgress)
                            .position(position)
                            .shadow(color: .black.opacity(0.28), radius: 4, y: 3)
                            .zIndex(6)
                    }
                }

                Circle()
                    .fill(correct ? cyan : submitted ? coral : gold)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().fill(.black).frame(width: 8, height: 8))
                    .shadow(color: (correct ? cyan : submitted ? coral : gold).opacity(0.65), radius: 8)
                    .position(point(on: center, radius: pieRadius + 3, degrees: guideDegrees))
                    .opacity(correct ? 0 : 1)
                    .zIndex(7)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateGuide(from: value.location, center: center)
                            }
                    )
                    .allowsHitTesting(!correct)
                    .accessibilityLabel("Arc-length cutting guide")
                    .zIndex(8)
            }
        }
    }

    private var guideControls: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                guideButton(systemName: "minus", delta: -5)

                VStack(spacing: 3) {
                    Text("s = \(decimal(selectedArc)) cm")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(correct ? cyan : submitted ? coral : .white)
                        .contentTransition(.numericText())

                    Text("θ = \(Int(guideDegrees))°  =  \(radianLabel(guideDegrees))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.52))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke((submitted ? (correct ? cyan : coral) : gold).opacity(0.42), lineWidth: 1))

                guideButton(systemName: "plus", delta: 5)
            }

            Button(action: cutPie) {
                Image(systemName: correct ? "checkmark" : "fork.knife")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 58, height: 58)
                    .background(correct ? cyan : submitted ? coral : gold, in: Circle())
                    .shadow(color: (correct ? cyan : submitted ? coral : gold).opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(correct)
            .accessibilityLabel("Cut the pie")
        }
    }

    private func guideButton(systemName: String, delta: Double) -> some View {
        Button {
            setGuide(guideDegrees + delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background(gold, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(correct)
    }

    private func drawPlate(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let plate = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.addFilter(.shadow(color: .black.opacity(0.65), radius: 14, x: 0, y: 10))
        context.fill(Path(ellipseIn: plate), with: .radialGradient(
            Gradient(colors: [.white.opacity(0.14), Color(red: 0.10, green: 0.13, blue: 0.16), .black.opacity(0.82)]),
            center: CGPoint(x: center.x - radius * 0.28, y: center.y - radius * 0.30),
            startRadius: 2,
            endRadius: radius
        ))
        context.stroke(Path(ellipseIn: plate), with: .color(.white.opacity(0.18)), lineWidth: 1)
    }

    private func drawPie(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let pieRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: pieRect), with: .radialGradient(
            Gradient(colors: [Color(red: 0.95, green: 0.36, blue: 0.20), Color(red: 0.65, green: 0.11, blue: 0.08)]),
            center: CGPoint(x: center.x - radius * 0.26, y: center.y - radius * 0.32),
            startRadius: 2,
            endRadius: radius
        ))

        for index in 0..<12 {
            let angle = Double(index) * 137.5
            let distance = radius * CGFloat(0.22 + Double(index % 4) * 0.17)
            let toppingCenter = point(on: center, radius: distance, degrees: angle)
            let toppingRadius = max(3, radius * 0.045)
            context.fill(
                Path(ellipseIn: CGRect(x: toppingCenter.x - toppingRadius, y: toppingCenter.y - toppingRadius, width: toppingRadius * 2, height: toppingRadius * 2)),
                with: .color(index.isMultiple(of: 3) ? gold.opacity(0.82) : Color(red: 0.38, green: 0.06, blue: 0.05))
            )
        }

        context.stroke(Path(ellipseIn: pieRect), with: .color(Color(red: 0.96, green: 0.62, blue: 0.22)), lineWidth: max(9, radius * 0.10))
        context.stroke(Path(ellipseIn: pieRect.insetBy(dx: 5, dy: 5)), with: .color(.white.opacity(0.18)), lineWidth: 1.2)
    }

    private func drawGuide(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let guideColor = correct ? cyan : submitted ? coral : gold
        let arc = sampledArc(center: center, radius: radius + 5, startDegrees: 0, endDegrees: guideDegrees)
        context.stroke(arc, with: .color(guideColor.opacity(0.35)), lineWidth: 11)
        context.stroke(arc, with: .color(guideColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        for degrees in stride(from: 0.0, through: guideDegrees, by: 5) {
            let outer = point(on: center, radius: radius + 11, degrees: degrees)
            let inner = point(on: center, radius: radius + (Int(degrees).isMultiple(of: 15) ? 3 : 6), degrees: degrees)
            var tick = Path()
            tick.move(to: inner)
            tick.addLine(to: outer)
            context.stroke(tick, with: .color(guideColor.opacity(0.76)), lineWidth: Int(degrees).isMultiple(of: 15) ? 1.4 : 0.7)
        }

        var startRadius = Path()
        startRadius.move(to: center)
        startRadius.addLine(to: point(on: center, radius: radius, degrees: 0))
        context.stroke(startRadius, with: .color(.white.opacity(0.56)), lineWidth: 1.3)

        let angleArc = sampledArc(
            center: center,
            radius: max(18, radius * 0.25),
            startDegrees: 0,
            endDegrees: guideDegrees
        )
        context.stroke(angleArc, with: .color(guideColor.opacity(0.92)), lineWidth: 2)

        let labelPoint = point(
            on: center,
            radius: radius * 0.48,
            degrees: max(10, guideDegrees / 2)
        )
        let labelRect = CGRect(x: labelPoint.x - 28, y: labelPoint.y - 18, width: 56, height: 36)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 5), with: .color(.black.opacity(0.64)))
        context.stroke(Path(roundedRect: labelRect, cornerRadius: 5), with: .color(guideColor.opacity(0.42)), lineWidth: 0.8)
        var degreeText = context.resolve(
            Text("\(Int(guideDegrees))°")
                .font(.system(size: 10, weight: .black, design: .monospaced))
        )
        degreeText.shading = .color(.white)
        context.draw(degreeText, at: CGPoint(x: labelPoint.x, y: labelPoint.y - 7), anchor: .center)

        var radianText = context.resolve(
            Text(radianLabel(guideDegrees))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
        )
        radianText.shading = .color(guideColor)
        context.draw(radianText, at: CGPoint(x: labelPoint.x, y: labelPoint.y + 7), anchor: .center)

        if !submitted {
            var endRadius = Path()
            endRadius.move(to: center)
            endRadius.addLine(to: point(on: center, radius: radius, degrees: guideDegrees))
            context.stroke(endRadius, with: .color(guideColor.opacity(0.75)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
        }
    }

    private func drawCuts(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let count = correct ? stage.customers : max(2, Int(ceil(360 / guideDegrees)))
        let visibleCuts = max(1, Int(ceil(CGFloat(count) * cutProgress)))

        for index in 0..<min(count, visibleCuts) {
            let angle = Double(index) * guideDegrees
            var cut = Path()
            cut.move(to: center)
            cut.addLine(to: point(on: center, radius: radius - 4, degrees: angle))
            context.stroke(cut, with: .color(.black.opacity(0.72)), lineWidth: 3.8)
            context.stroke(cut, with: .color(.white.opacity(0.62)), lineWidth: 1)
        }

        if !correct, cutProgress > 0.95 {
            let lastAngle = floor(360 / guideDegrees) * guideDegrees
            let remainder = 360 - lastAngle
            let remainderArc = sampledArc(center: center, radius: radius - 7, startDegrees: lastAngle, endDegrees: 360)
            context.stroke(remainderArc, with: .color(coral), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            let labelPoint = point(on: center, radius: radius * 0.72, degrees: lastAngle + remainder / 2)
            context.fill(Path(ellipseIn: CGRect(x: labelPoint.x - 5, y: labelPoint.y - 5, width: 10, height: 10)), with: .color(coral))
        }
    }

    private func updateGuide(from location: CGPoint, center: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        var degrees = Double(atan2(dx, -dy) * 180 / .pi)
        if degrees < 0 { degrees += 360 }
        guard degrees <= 185 else { return }
        setGuide((degrees / 5).rounded() * 5)
    }

    private func setGuide(_ degrees: Double) {
        guard !correct else { return }
        if submitted {
            submitted = false
            cutProgress = 0
            distributionProgress = 0
        }
        guideDegrees = min(180, max(10, degrees))
    }

    private func cutPie() {
        guard !submitted, !correct else { return }
        submitted = true
        correct = isExact
        cutProgress = 0
        distributionProgress = 0
        HapticPlayer.playLightTap()

        withAnimation(.easeInOut(duration: correct ? 1.05 : 0.52)) {
            cutProgress = 1
        }

        guard correct else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { HapticPlayer.playLightTap() }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.02) {
            HapticPlayer.playCompletionTap()
            withAnimation(.easeInOut(duration: 1.25)) {
                distributionProgress = 1
            }
        }
        scheduleNextStage()
    }

    private func scheduleNextStage() {
        guard !transitionScheduled else { return }
        transitionScheduled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if stageIndex == stages.count - 1 {
                withAnimation(.easeInOut(duration: 0.45)) { completed = true }
            } else {
                loadStage(stageIndex + 1)
            }
        }
    }

    private func loadStage(_ index: Int) {
        stageIndex = min(index, stages.count - 1)
        guideDegrees = stages[stageIndex].startingDegrees
        submitted = false
        correct = false
        cutProgress = 0
        distributionProgress = 0
        transitionScheduled = false
    }

    private func resetLevel() {
        completed = false
        loadStage(0)
    }

    private func customerSize(for count: Int) -> CGSize {
        if count <= 4 { return CGSize(width: 46, height: 68) }
        if count <= 8 { return CGSize(width: 36, height: 56) }
        return CGSize(width: 30, height: 48)
    }

    private func customerPosition(index: Int, count: Int, in size: CGSize) -> CGPoint {
        let columns = count <= 4 ? count : count / 2
        let row = count <= 4 ? 0 : index / columns
        let column = count <= 4 ? index : index % columns
        let inset: CGFloat = count <= 4 ? 42 : 24
        let usableWidth = max(1, size.width - inset * 2)
        let x = columns == 1
            ? size.width / 2
            : inset + CGFloat(column) / CGFloat(columns - 1) * usableWidth
        let y: CGFloat = count <= 4 ? 53 : 34 + CGFloat(row) * (count <= 8 ? 66 : 57)
        return CGPoint(x: x, y: y)
    }

    private func servingDestination(index: Int, count: Int, in size: CGSize) -> CGPoint {
        let person = customerPosition(index: index, count: count, in: size)
        let personHeight = customerSize(for: count).height
        return CGPoint(x: person.x, y: person.y + personHeight * 0.16)
    }

    private func interpolatedPoint(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        let eased = progress * progress * (3 - 2 * progress)
        return CGPoint(
            x: start.x + (end.x - start.x) * eased,
            y: start.y + (end.y - start.y) * eased
        )
    }

    private func servingScale(for count: Int) -> CGFloat {
        if count <= 4 { return 0.25 }
        if count <= 8 { return 0.20 }
        return 0.16
    }

    private func point(on center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + sin(radians) * radius,
            y: center.y - cos(radians) * radius
        )
    }

    private func sampledArc(center: CGPoint, radius: CGFloat, startDegrees: Double, endDegrees: Double) -> Path {
        var path = Path()
        let span = max(0, endDegrees - startDegrees)
        let samples = max(2, Int(span / 2))
        for sample in 0...samples {
            let fraction = Double(sample) / Double(samples)
            let degrees = startDegrees + span * fraction
            let arcPoint = point(on: center, radius: radius, degrees: degrees)
            sample == 0 ? path.move(to: arcPoint) : path.addLine(to: arcPoint)
        }
        return path
    }

    private func decimal(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func radianLabel(_ degrees: Double) -> String {
        switch Int(degrees.rounded()) {
        case 30: "π/6"
        case 45: "π/4"
        case 60: "π/3"
        case 90: "π/2"
        case 120: "2π/3"
        case 135: "3π/4"
        case 180: "π"
        default: "\(String(format: "%.2f", degrees * .pi / 180)) rad"
        }
    }

    private func customerColor(_ index: Int) -> Color {
        [cyan, gold, coral, Color.green, Color.pink][index % 5]
    }
}

private struct DetailedPieCustomer: View {
    let index: Int
    let served: Bool
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let skin = skinColor(index)
                let hair = hairColor(index)
                let torso = CGRect(x: width * 0.23, y: height * 0.43, width: width * 0.54, height: height * 0.34)

                for side in [-1.0, 1.0] {
                    let legX = width * (side < 0 ? 0.38 : 0.57)
                    let leg = CGRect(x: legX - width * 0.07, y: height * 0.72, width: width * 0.14, height: height * 0.24)
                    context.fill(Path(roundedRect: leg, cornerRadius: width * 0.07), with: .color(Color(red: 0.12, green: 0.17, blue: 0.24)))
                    let shoe = CGRect(x: leg.midX - width * 0.09, y: height * 0.91, width: width * 0.20, height: height * 0.07)
                    context.fill(Path(roundedRect: shoe, cornerRadius: width * 0.035), with: .color(.black.opacity(0.88)))
                }

                context.fill(Path(roundedRect: torso, cornerRadius: width * 0.10), with: .linearGradient(
                    Gradient(colors: [accent.opacity(0.98), accent.opacity(0.58)]),
                    startPoint: CGPoint(x: torso.midX, y: torso.minY),
                    endPoint: CGPoint(x: torso.midX, y: torso.maxY)
                ))
                context.stroke(Path(roundedRect: torso, cornerRadius: width * 0.10), with: .color(.white.opacity(0.20)), lineWidth: 0.8)

                for side in [-1.0, 1.0] {
                    let shoulder = CGPoint(x: width * (side < 0 ? 0.25 : 0.75), y: height * 0.50)
                    let hand = CGPoint(
                        x: width * (side < 0 ? 0.35 : 0.65),
                        y: height * (served ? 0.64 : 0.70)
                    )
                    var arm = Path()
                    arm.move(to: shoulder)
                    arm.addLine(to: hand)
                    context.stroke(arm, with: .color(accent.opacity(0.92)), style: StrokeStyle(lineWidth: max(2.5, width * 0.12), lineCap: .round))
                    context.fill(Path(ellipseIn: CGRect(x: hand.x - width * 0.055, y: hand.y - width * 0.055, width: width * 0.11, height: width * 0.11)), with: .color(skin))
                }

                let neck = CGRect(x: width * 0.43, y: height * 0.34, width: width * 0.14, height: height * 0.13)
                context.fill(Path(roundedRect: neck, cornerRadius: width * 0.04), with: .color(skin))

                let head = CGRect(x: width * 0.27, y: height * 0.08, width: width * 0.46, height: height * 0.34)
                context.fill(Path(ellipseIn: head), with: .color(skin))
                for earX in [head.minX - width * 0.025, head.maxX - width * 0.025] {
                    context.fill(Path(ellipseIn: CGRect(x: earX, y: head.midY - width * 0.045, width: width * 0.09, height: width * 0.11)), with: .color(skin.opacity(0.94)))
                }

                let hairCap = CGRect(x: head.minX - width * 0.015, y: head.minY - height * 0.015, width: head.width + width * 0.03, height: head.height * 0.62)
                context.fill(Path(ellipseIn: hairCap), with: .color(hair))
                let face = CGRect(x: head.minX + width * 0.035, y: head.minY + height * 0.07, width: head.width - width * 0.07, height: head.height * 0.78)
                context.fill(Path(ellipseIn: face), with: .color(skin))

                let eyeY = head.minY + head.height * 0.55
                for eyeX in [head.minX + head.width * 0.36, head.minX + head.width * 0.68] {
                    context.fill(Path(ellipseIn: CGRect(x: eyeX - width * 0.018, y: eyeY - width * 0.018, width: width * 0.036, height: width * 0.036)), with: .color(.black.opacity(0.82)))
                }

                var mouth = Path()
                mouth.move(to: CGPoint(x: head.midX - width * 0.06, y: head.minY + head.height * 0.72))
                mouth.addQuadCurve(
                    to: CGPoint(x: head.midX + width * 0.06, y: head.minY + head.height * 0.72),
                    control: CGPoint(x: head.midX, y: head.minY + head.height * (served ? 0.82 : 0.76))
                )
                context.stroke(mouth, with: .color(.black.opacity(0.55)), style: StrokeStyle(lineWidth: max(0.7, width * 0.025), lineCap: .round))

                if served {
                    let plate = CGRect(x: width * 0.28, y: height * 0.61, width: width * 0.44, height: height * 0.08)
                    context.fill(Path(ellipseIn: plate), with: .color(.white.opacity(0.82)))
                    context.stroke(Path(ellipseIn: plate), with: .color(accent.opacity(0.85)), lineWidth: 0.8)
                }
            }
        }
        .scaleEffect(served ? 1.04 : 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.68), value: served)
    }

    private func skinColor(_ index: Int) -> Color {
        [
            Color(red: 0.98, green: 0.78, blue: 0.62),
            Color(red: 0.72, green: 0.48, blue: 0.33),
            Color(red: 0.91, green: 0.66, blue: 0.47),
            Color(red: 0.52, green: 0.32, blue: 0.23)
        ][index % 4]
    }

    private func hairColor(_ index: Int) -> Color {
        [
            Color(red: 0.10, green: 0.06, blue: 0.04),
            Color(red: 0.36, green: 0.18, blue: 0.08),
            Color(red: 0.92, green: 0.70, blue: 0.24),
            Color(red: 0.18, green: 0.12, blue: 0.10)
        ][index % 4]
    }
}

private struct PieServingSlice: View {
    let angleDegrees: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.46
            let wedge = wedgePath(center: center, radius: radius)

            context.fill(wedge, with: .radialGradient(
                Gradient(colors: [Color(red: 0.98, green: 0.39, blue: 0.20), Color(red: 0.62, green: 0.09, blue: 0.07)]),
                center: CGPoint(x: center.x, y: center.y - radius * 0.25),
                startRadius: 1,
                endRadius: radius
            ))
            context.stroke(wedge, with: .color(.white.opacity(0.64)), lineWidth: 1)

            let crust = arcPath(center: center, radius: radius, startDegrees: -90, endDegrees: -90 + angleDegrees)
            context.stroke(crust, with: .color(Color(red: 0.98, green: 0.67, blue: 0.23)), style: StrokeStyle(lineWidth: max(3, radius * 0.10), lineCap: .round))

            let toppingAngle = (-90 + angleDegrees / 2) * .pi / 180
            let topping = CGPoint(
                x: center.x + CGFloat(cos(toppingAngle)) * radius * 0.58,
                y: center.y + CGFloat(sin(toppingAngle)) * radius * 0.58
            )
            let toppingRadius = max(2, radius * 0.055)
            context.fill(Path(ellipseIn: CGRect(x: topping.x - toppingRadius, y: topping.y - toppingRadius, width: toppingRadius * 2, height: toppingRadius * 2)), with: .color(color.opacity(0.92)))
        }
    }

    private func wedgePath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: center)
        let samples = max(4, Int(angleDegrees / 3))
        for sample in 0...samples {
            let fraction = Double(sample) / Double(samples)
            let degrees = -90 + angleDegrees * fraction
            let radians = degrees * .pi / 180
            path.addLine(to: CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            ))
        }
        path.closeSubpath()
        return path
    }

    private func arcPath(center: CGPoint, radius: CGFloat, startDegrees: Double, endDegrees: Double) -> Path {
        var path = Path()
        let samples = max(4, Int(abs(endDegrees - startDegrees) / 3))
        for sample in 0...samples {
            let fraction = Double(sample) / Double(samples)
            let degrees = startDegrees + (endDegrees - startDegrees) * fraction
            let radians = degrees * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )
            sample == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

private struct PerfectSliceStage {
    let radius: Double
    let customers: Int
    let given: String
    let givenIcon: String
    let startingDegrees: Double

    var circumference: Double { 2 * .pi * radius }
    var targetDegrees: Double { 360 / Double(customers) }

    static let all: [PerfectSliceStage] = [
        PerfectSliceStage(radius: 6, customers: 4, given: "r = 6 cm", givenIcon: "ruler", startingDegrees: 65),
        PerfectSliceStage(radius: 8, customers: 8, given: "d = 16 cm", givenIcon: "arrow.left.and.right", startingDegrees: 70),
        PerfectSliceStage(radius: 9, customers: 12, given: "C = 18π cm", givenIcon: "circle.dashed", startingDegrees: 20)
    ]
}

#Preview {
    MathItLevelOneHundredThirtyEightView(onContinue: {}, onLevelSelect: {})
}
