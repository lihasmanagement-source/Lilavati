import SwiftUI

struct MathItLevelOneHundredThirtyView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var matched: Set<Int> = []
    @State private var wrongTarget: Int?
    @State private var draggingID: Int?
    @State private var dragTranslation = CGSize.zero
    @State private var hoverTarget: Int?
    @State private var dropFrames: [Int: CGRect] = [:]
    @State private var rideStart: Date?
    @State private var completed = false
    @State private var actionToken = UUID()

    private let stages = LimitStage.all
    private let rideDuration = 10.2

    private var stage: LimitStage { stages[min(stageIndex, stages.count - 1)] }
    private var curves: [LimitCurve] { stage.curves }
    private var allMatched: Bool { matched.count == curves.count }
    private var trayCurves: [LimitCurve] { [curves[2], curves[0], curves[1]] }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: compact ? 8 : 12) {
                    stageProgress
                        .padding(.top, compact ? 12 : 20)

                    graph
                        .frame(maxWidth: 920)
                        .frame(height: max(430, min(575, proxy.size.height * 0.66)))

                    equationTray
                        .frame(maxWidth: 700)
                        .padding(.bottom, compact ? 8 : 15)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Every Limit Landed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
            .coordinateSpace(name: "limitsLevel")
            .onPreferenceChange(LimitDropFramePreferenceKey.self) { frames in
                dropFrames = frames
            }
        }
        .environment(\.mathItAccent, Color(red: 0.22, green: 0.82, blue: 0.94))
    }

    private var stageProgress: some View {
        HStack(spacing: 8) {
            ForEach(stages.indices, id: \.self) { index in
                Capsule()
                    .fill(index < stageIndex ? Color.mathGold : index == stageIndex ? stage.accent : .white.opacity(0.14))
                    .frame(width: index == stageIndex ? 38 : 22, height: 5)
            }

            Text("\(stageIndex + 1) / 3")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
                .padding(.leading, 3)
        }
        .frame(height: 12)
    }

    private var graph: some View {
        GeometryReader { geo in
            let plot = CGRect(
                x: 48,
                y: 24,
                width: max(140, geo.size.width - 70),
                height: max(200, geo.size.height - 58)
            )

            ZStack {
                Canvas { context, _ in
                    drawGrid(context: &context, plot: plot)
                    drawGuides(context: &context, plot: plot)
                    for curve in curves {
                        drawCurve(curve, context: &context, plot: plot)
                    }
                    drawLimitMarkers(context: &context, plot: plot)
                }

                ForEach(curves) { curve in
                    equationDropZone(for: curve)
                        .position(dropZonePosition(for: curve, plot: plot))
                }

                if let rideStart {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        let elapsed = timeline.date.timeIntervalSince(rideStart)
                        if elapsed <= rideDuration,
                           let state = skaterState(progress: elapsed / rideDuration, plot: plot) {
                            LimitSkater(accent: state.color)
                                .frame(width: 43, height: 38)
                                .scaleEffect(x: state.facing, y: 1)
                                .rotationEffect(.radians(state.angle))
                                .opacity(state.opacity)
                                .position(skaterCenter(for: state))
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .background(Color(red: 0.024, green: 0.030, blue: 0.041))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.mathGold.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var equationTray: some View {
        VStack(spacing: 6) {
            ForEach(trayCurves) { curve in
                if matched.contains(curve.id) {
                    Color.clear.frame(height: 35)
                } else {
                    equationToken(curve)
                        .offset(draggingID == curve.id ? dragTranslation : .zero)
                        .scaleEffect(draggingID == curve.id ? 1.04 : 1)
                        .shadow(color: Color.mathGold.opacity(draggingID == curve.id ? 0.45 : 0), radius: 10)
                        .zIndex(draggingID == curve.id ? 20 : 0)
                        .contentShape(Rectangle())
                        .gesture(equationDragGesture(for: curve.id))
                }
            }
        }
        .overlay {
            if allMatched && rideStart == nil {
                ProgressView().tint(stage.accent)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: matched)
    }

    private func equationToken(_ curve: LimitCurve) -> some View {
        Text(curve.equation)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.mathGold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: 340)
            .frame(height: 35)
            .background(Color(red: 0.045, green: 0.048, blue: 0.060))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.mathGold.opacity(0.45), lineWidth: 1)
            }
    }

    private func equationDropZone(for curve: LimitCurve) -> some View {
        let isMatched = matched.contains(curve.id)
        let isWrong = wrongTarget == curve.id
        let isHovered = hoverTarget == curve.id

        return Group {
            if isMatched {
                Text(curve.compactEquation)
                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                    .foregroundStyle(curve.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(isWrong ? .red : .white.opacity(0.28))
            }
        }
        .frame(width: 116, height: 34)
        .background(Color.black.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    isMatched ? curve.color : isWrong ? .red : isHovered ? Color.mathGold : .white.opacity(0.28),
                    style: StrokeStyle(lineWidth: isMatched || isHovered ? 1.8 : 1, dash: isMatched ? [] : [4, 3])
                )
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: LimitDropFramePreferenceKey.self,
                    value: [curve.id: proxy.frame(in: .named("limitsLevel"))]
                )
            }
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isMatched)
        .animation(.easeInOut(duration: 0.16), value: isWrong)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private func equationDragGesture(for sourceID: Int) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("limitsLevel"))
            .onChanged { value in
                if draggingID == nil {
                    draggingID = sourceID
                    HapticPlayer.playLightTap()
                }
                guard draggingID == sourceID else { return }
                dragTranslation = value.translation
                hoverTarget = target(at: value.location)
            }
            .onEnded { value in
                guard draggingID == sourceID else { return }
                if let targetID = target(at: value.location) {
                    _ = placeEquation(sourceID, on: targetID)
                }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    draggingID = nil
                    dragTranslation = .zero
                    hoverTarget = nil
                }
            }
    }

    private func target(at point: CGPoint) -> Int? {
        dropFrames.first { _, frame in
            frame.insetBy(dx: -24, dy: -22).contains(point)
        }?.key
    }

    private func placeEquation(_ sourceID: Int, on targetID: Int) -> Bool {
        guard rideStart == nil, !matched.contains(sourceID) else { return false }
        guard sourceID == targetID else {
            wrongTarget = targetID
            HapticPlayer.playLightTap()
            let token = actionToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard token == actionToken else { return }
                withAnimation { wrongTarget = nil }
            }
            return false
        }

        let finishesStage = matched.count == curves.count - 1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
            matched.insert(sourceID)
            wrongTarget = nil
        }
        HapticPlayer.playCompletionTap()
        if finishesStage { startRide() }
        return true
    }

    private func startRide() {
        let token = actionToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard token == actionToken else { return }
            rideStart = Date()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + rideDuration) {
            guard token == actionToken else { return }
            HapticPlayer.playCompletionTap()
            rideStart = nil
            if stageIndex == stages.count - 1 {
                withAnimation(.easeInOut(duration: 0.35)) {
                    completed = true
                }
            } else {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                    stageIndex += 1
                    matched.removeAll()
                    wrongTarget = nil
                    dropFrames.removeAll()
                }
            }
        }
    }

    private func resetLevel() {
        actionToken = UUID()
        stageIndex = 0
        matched.removeAll()
        wrongTarget = nil
        draggingID = nil
        dragTranslation = .zero
        hoverTarget = nil
        dropFrames.removeAll()
        rideStart = nil
        completed = false
    }

    private func dropZonePosition(for curve: LimitCurve, plot: CGRect) -> CGPoint {
        CGPoint(
            x: screenX(curve.slot.x, plot: plot),
            y: screenY(curve.slot.y, plot: plot) + curve.slot.verticalOffset
        )
    }

    private func drawGrid(context: inout GraphicsContext, plot: CGRect) {
        for index in 0...5 {
            let fraction = Double(index) / 5
            let xValue = stage.xRange.lowerBound + fraction * (stage.xRange.upperBound - stage.xRange.lowerBound)
            let x = screenX(xValue, plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: x, y: plot.minY))
            line.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(line, with: .color(.white.opacity(abs(xValue) < 0.001 ? 0.30 : 0.06)), lineWidth: abs(xValue) < 0.001 ? 1.6 : 1)
            context.draw(tickText(format(xValue)), at: CGPoint(x: x, y: plot.maxY + 13))
        }

        for index in 0...6 {
            let fraction = Double(index) / 6
            let yValue = stage.yRange.lowerBound + fraction * (stage.yRange.upperBound - stage.yRange.lowerBound)
            let y = screenY(yValue, plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(line, with: .color(.white.opacity(abs(yValue) < 0.001 ? 0.30 : 0.06)), lineWidth: abs(yValue) < 0.001 ? 1.6 : 1)
            context.draw(tickText(format(yValue)), at: CGPoint(x: plot.minX - 20, y: y))
        }
    }

    private func drawGuides(context: inout GraphicsContext, plot: CGRect) {
        for curve in curves {
            let active = matched.contains(curve.id)
            for marker in curve.markers {
                switch marker {
                case .vertical(let x, _):
                    var line = Path()
                    line.move(to: CGPoint(x: screenX(x, plot: plot), y: plot.minY))
                    line.addLine(to: CGPoint(x: screenX(x, plot: plot), y: plot.maxY))
                    context.stroke(line, with: .color(active ? curve.color.opacity(0.72) : .white.opacity(0.16)), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                case .horizontal(let y, _):
                    var line = Path()
                    line.move(to: CGPoint(x: plot.minX, y: screenY(y, plot: plot)))
                    line.addLine(to: CGPoint(x: plot.maxX, y: screenY(y, plot: plot)))
                    context.stroke(line, with: .color(active ? curve.color.opacity(0.72) : .white.opacity(0.16)), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                default:
                    break
                }
            }
        }
    }

    private func drawCurve(_ curve: LimitCurve, context: inout GraphicsContext, plot: CGRect) {
        let samples = 1_000
        var path = Path()
        var drawing = false

        for index in 0...samples {
            let fraction = Double(index) / Double(samples)
            let x = stage.xRange.lowerBound + fraction * (stage.xRange.upperBound - stage.xRange.lowerBound)
            if curve.exclusions.contains(where: { abs(x - $0) < 0.025 }) {
                drawing = false
                continue
            }
            guard let y = curve.value(x), stage.yRange.contains(y) else {
                drawing = false
                continue
            }
            let point = graphPoint(x: x, y: y, plot: plot)
            if drawing { path.addLine(to: point) } else { path.move(to: point); drawing = true }
        }

        let active = matched.contains(curve.id)
        context.stroke(
            path,
            with: .color(active ? curve.color.opacity(0.94) : .white.opacity(0.20)),
            style: StrokeStyle(lineWidth: active ? 4 : 2.2, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawLimitMarkers(context: inout GraphicsContext, plot: CGRect) {
        for curve in curves {
            let active = matched.contains(curve.id)
            let markerColor = active ? curve.color : .white.opacity(0.25)
            for marker in curve.markers {
                switch marker {
                case .hole(let x, let y, let label):
                    drawOpenPoint(x: x, y: y, color: markerColor, context: &context, plot: plot)
                    if active { drawMarkerLabel(label, x: x, y: y, color: curve.color, context: &context, plot: plot) }
                case .endpoint(let x, let y, let label):
                    let point = graphPoint(x: x, y: y, plot: plot)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)), with: .color(markerColor))
                    if active { drawMarkerLabel(label, x: x, y: y, color: curve.color, context: &context, plot: plot) }
                case .jump(let x, let leftY, let rightY, let label):
                    drawOpenPoint(x: x, y: leftY, color: markerColor, context: &context, plot: plot)
                    drawOpenPoint(x: x, y: rightY, color: markerColor, context: &context, plot: plot)
                    if active { drawMarkerLabel(label, x: x, y: (leftY + rightY) / 2, color: curve.color, context: &context, plot: plot) }
                case .vertical(let x, let label):
                    if active, let label {
                        drawMarkerLabel(label, x: x - 0.12, y: stage.yRange.upperBound * 0.78, color: curve.color, context: &context, plot: plot)
                    }
                case .horizontal(let y, let label):
                    if active, let label {
                        drawMarkerLabel(label, x: stage.xRange.upperBound * 0.82, y: y, color: curve.color, context: &context, plot: plot)
                    }
                }
            }
        }
    }

    private func drawOpenPoint(x: Double, y: Double, color: Color, context: inout GraphicsContext, plot: CGRect) {
        let point = graphPoint(x: x, y: y, plot: plot)
        let hole = Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
        context.fill(hole, with: .color(Color(red: 0.024, green: 0.030, blue: 0.041)))
        context.stroke(hole, with: .color(color), lineWidth: 2.4)
    }

    private func drawMarkerLabel(_ label: String, x: Double, y: Double, color: Color, context: inout GraphicsContext, plot: CGRect) {
        context.draw(
            Text(label).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(color),
            at: CGPoint(x: screenX(x, plot: plot) + 18, y: screenY(y, plot: plot) - 15)
        )
    }

    private func skaterState(progress rawProgress: Double, plot: CGRect) -> LimitSkaterState? {
        let progress = min(max(rawProgress, 0), 1)
        let scaled = progress * 3
        let curveIndex = min(2, Int(scaled))
        let local = min(1, scaled - Double(curveIndex))

        switch stageIndex {
        case 0:
            return stageOneSkater(curve: curveIndex, progress: local, plot: plot)
        case 1:
            return stageTwoSkater(curve: curveIndex, progress: local, plot: plot)
        default:
            return stageThreeSkater(curve: curveIndex, progress: local, plot: plot)
        }
    }

    private func stageOneSkater(curve: Int, progress: Double, plot: CGRect) -> LimitSkaterState {
        if curve == 0 {
            let x = mix(3.95, 0, progress)
            let y = sqrt(max(0, 4 - x))
            let slope = -1 / max(0.35, 2 * sqrt(max(0.001, 4 - x)))
            return rideState(x: x, y: y, slope: slope, direction: -1, color: curves[1].color, plot: plot)
        }
        if curve == 1 {
            if progress < 0.43 {
                let t = progress / 0.43
                let x = mix(0, 1.65, t)
                return rideState(x: x, y: x + 2, slope: 1, color: curves[0].color, plot: plot)
            }
            if progress < 0.62 {
                let t = (progress - 0.43) / 0.19
                return jumpState(
                    from: graphPoint(x: 1.65, y: 3.65, plot: plot),
                    to: graphPoint(x: 2.35, y: 4.35, plot: plot),
                    progress: t,
                    lift: 42,
                    color: curves[0].color
                )
            }
            if progress < 0.79 {
                let t = (progress - 0.62) / 0.17
                let x = mix(2.35, 3.2, t)
                return rideState(x: x, y: x + 2, slope: 1, color: curves[0].color, plot: plot)
            }
            let t = (progress - 0.79) / 0.21
            return jumpState(
                from: graphPoint(x: 3.2, y: 5.2, plot: plot),
                to: graphPoint(x: 4.5, y: 1 / 1.5, plot: plot),
                progress: t,
                lift: 36,
                color: curves[0].color
            )
        }
        if progress < 0.62 {
            let t = progress / 0.62
            let x = mix(4.5, 5.9, t)
            let distance = 6 - x
            return rideState(
                x: x,
                y: 1 / distance,
                slope: 1 / (distance * distance),
                color: curves[2].color,
                plot: plot
            )
        }
        if progress < 0.72 {
            return LimitSkaterState(
                point: CGPoint(x: screenX(6.25, plot: plot), y: plot.maxY + 45),
                angle: 0,
                color: curves[2].color,
                opacity: 0,
                facing: 1
            )
        }
        let t = (progress - 0.72) / 0.28
        let x = mix(6.5, 8, t)
        let distance = 6 - x
        return rideState(
            x: x,
            y: 1 / distance,
            slope: 1 / (distance * distance),
            color: curves[2].color,
            plot: plot
        )
    }

    private func stageTwoSkater(curve: Int, progress: Double, plot: CGRect) -> LimitSkaterState {
        if curve == 0 {
            if progress < 0.76 {
                let t = progress / 0.76
                let x = mix(8, -1, t)
                let y = sqrt(max(0, x + 1))
                let slope = 1 / max(0.35, 2 * sqrt(max(0.001, x + 1)))
                return rideState(
                    x: x,
                    y: y,
                    slope: slope,
                    direction: -1,
                    color: curves[1].color,
                    plot: plot
                )
            }
            let t = (progress - 0.76) / 0.24
            return jumpState(
                from: graphPoint(x: -1, y: 0, plot: plot),
                to: graphPoint(x: -3.4, y: 1 / -1.4, plot: plot),
                progress: t,
                lift: 52,
                color: curves[1].color
            )
        }
        if curve == 1 {
            if progress < 0.30 {
                let t = progress / 0.30
                let x = mix(-3.4, -2.5, t)
                let distance = x + 2
                return rideState(
                    x: x,
                    y: 1 / distance,
                    slope: -1 / (distance * distance),
                    color: curves[2].color,
                    plot: plot
                )
            }
            if progress < 0.40 {
                return LimitSkaterState(
                    point: CGPoint(x: screenX(-2, plot: plot), y: plot.minY - 45),
                    angle: 0,
                    color: curves[2].color,
                    opacity: 0,
                    facing: 1
                )
            }
            let t = (progress - 0.40) / 0.60
            let intersectionX = (-3 + sqrt(5)) / 2
            let x = mix(-1.9, intersectionX, t)
            let distance = x + 2
            return rideState(
                x: x,
                y: 1 / distance,
                slope: -1 / (distance * distance),
                color: curves[2].color,
                plot: plot
            )
        }
        let intersectionX = (-3 + sqrt(5)) / 2
        let x = mix(intersectionX, 5, progress)
        let holeProgress = (1 - intersectionX) / (5 - intersectionX)
        let lift = localizedJump(progress: progress, center: holeProgress, width: 0.15, height: 1.2)
        return rideState(
            x: x,
            y: x + 1 + lift,
            slope: 1,
            color: curves[0].color,
            plot: plot
        )
    }

    private func stageThreeSkater(curve: Int, progress: Double, plot: CGRect) -> LimitSkaterState {
        if curve == 0 {
            if progress < 0.42 {
                let t = progress / 0.42
                let x = mix(-5.0 / 6.0, -0.25, t)
                let y = (3 * x - 1) / (x + 2)
                return rideState(
                    x: x,
                    y: y,
                    slope: 7 / ((x + 2) * (x + 2)),
                    color: curves[2].color,
                    plot: plot
                )
            }
            let t = (progress - 0.42) / 0.58
            let x = mix(-0.25, -5.2, t)
            return rideState(
                x: x,
                y: -1,
                slope: 0,
                direction: -1,
                color: curves[1].color,
                plot: plot
            )
        }
        if curve == 1 {
            if progress < 0.16 {
                let t = progress / 0.16
                let landingX = -4.8
                return jumpState(
                    from: graphPoint(x: -5.2, y: -1, plot: plot),
                    to: graphPoint(x: landingX, y: sin(landingX) / landingX, plot: plot),
                    progress: t,
                    lift: 48,
                    color: curves[1].color
                )
            }
            if progress < 0.78 {
                let t = (progress - 0.16) / 0.62
                let x = mix(-4.8, -0.35, t)
                return rideState(
                    x: x,
                    y: sin(x) / x,
                    slope: numericalSlope(curves[0], at: x),
                    color: curves[0].color,
                    plot: plot
                )
            }
            let t = (progress - 0.78) / 0.22
            let startX = -0.35
            return jumpState(
                from: graphPoint(x: startX, y: sin(startX) / startX, plot: plot),
                to: graphPoint(x: 0.35, y: 1, plot: plot),
                progress: t,
                lift: 42,
                color: curves[0].color
            )
        }
        let x = mix(0.35, 12, progress)
        return rideState(x: x, y: 1, slope: 0, color: curves[1].color, plot: plot)
    }

    private func verticalRide(progress: Double, startX: Double, endX: Double, asymptoteX: Double, fromRight: Bool, color: Color, plot: CGRect) -> LimitSkaterState {
        if progress < 0.84 {
            let t = progress / 0.84
            let x = mix(startX, endX, t)
            let distance = abs(asymptoteX - x)
            let y = 1 / distance
            let slope = 1 / (distance * distance)
            return rideState(x: x, y: y, slope: fromRight ? -slope : slope, direction: fromRight ? -1 : 1, color: color, plot: plot)
        }
        let t = (progress - 0.84) / 0.16
        let start = graphPoint(x: endX, y: 1 / abs(asymptoteX - endX), plot: plot)
        let end = CGPoint(x: screenX(asymptoteX + (fromRight ? -0.2 : 0.2), plot: plot), y: plot.minY - 80)
        var state = jumpState(from: start, to: end, progress: t, lift: 36, color: color)
        state.opacity = 1 - max(0, (t - 0.65) / 0.35)
        return state
    }

    private func endpointJump(progress: Double, start: (Double, Double), end: (Double, Double), color: Color, plot: CGRect) -> LimitSkaterState {
        var state = jumpState(
            from: graphPoint(x: start.0, y: start.1, plot: plot),
            to: graphPoint(x: end.0, y: end.1, plot: plot),
            progress: progress,
            lift: 48,
            color: color
        )
        state.opacity = 1 - max(0, (progress - 0.82) / 0.18)
        return state
    }

    private func numericalSlope(_ curve: LimitCurve, at x: Double) -> Double {
        let h = 0.01
        guard let left = curve.value(x - h), let right = curve.value(x + h) else { return 0 }
        return (right - left) / (2 * h)
    }

    private func rideState(x: Double, y: Double, slope: Double, direction: Double = 1, color: Color, plot: CGRect) -> LimitSkaterState {
        let xScale = plot.width / CGFloat(stage.xRange.upperBound - stage.xRange.lowerBound)
        let yScale = plot.height / CGFloat(stage.yRange.upperBound - stage.yRange.lowerBound)
        let rawAngle = atan2(-slope * Double(yScale), Double(xScale))
        return LimitSkaterState(
            point: graphPoint(x: x, y: y, plot: plot),
            angle: normalizedBoardAngle(rawAngle),
            color: color,
            opacity: 1,
            facing: direction < 0 ? -1 : 1
        )
    }

    private func jumpState(from start: CGPoint, to end: CGPoint, progress: Double, lift: CGFloat, color: Color) -> LimitSkaterState {
        let t = CGFloat(min(max(progress, 0), 1))
        let base = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
        let point = CGPoint(x: base.x, y: base.y - sin(t * .pi) * lift)
        let rawAngle = atan2(Double(end.y - start.y), Double(end.x - start.x)) - sin(progress * .pi) * 0.22
        return LimitSkaterState(
            point: point,
            angle: normalizedBoardAngle(rawAngle),
            color: color,
            opacity: 1,
            facing: end.x < start.x ? -1 : 1
        )
    }

    private func normalizedBoardAngle(_ angle: Double) -> Double {
        var result = angle
        while result > .pi / 2 { result -= .pi }
        while result < -.pi / 2 { result += .pi }
        return result
    }

    private func skaterCenter(for state: LimitSkaterState) -> CGPoint {
        let boardOffset: CGFloat = 9
        return CGPoint(
            x: state.point.x + sin(state.angle) * boardOffset,
            y: state.point.y - cos(state.angle) * boardOffset
        )
    }

    private func localizedJump(progress: Double, center: Double, width: Double, height: Double) -> Double {
        let start = center - width / 2
        let end = center + width / 2
        guard progress >= start, progress <= end else { return 0 }
        return sin((progress - start) / width * .pi) * height
    }

    private func mix(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        start + (end - start) * progress
    }

    private func graphPoint(x: Double, y: Double, plot: CGRect) -> CGPoint {
        CGPoint(x: screenX(x, plot: plot), y: screenY(y, plot: plot))
    }

    private func screenX(_ x: Double, plot: CGRect) -> CGFloat {
        plot.minX + CGFloat((x - stage.xRange.lowerBound) / (stage.xRange.upperBound - stage.xRange.lowerBound)) * plot.width
    }

    private func screenY(_ y: Double, plot: CGRect) -> CGFloat {
        plot.maxY - CGFloat((y - stage.yRange.lowerBound) / (stage.yRange.upperBound - stage.yRange.lowerBound)) * plot.height
    }

    private func tickText(_ value: String) -> Text {
        Text(value).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.38))
    }

    private func format(_ value: Double) -> String {
        if abs(value) < 0.001 { return "0" }
        return value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

private struct LimitDropFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct LimitSkaterState {
    let point: CGPoint
    let angle: Double
    let color: Color
    var opacity: Double
    let facing: CGFloat
}

private struct LimitSkater: View {
    let accent: Color

    var body: some View {
        Canvas { context, _ in
            let white = Color.white.opacity(0.96)
            var board = Path()
            board.move(to: CGPoint(x: 5, y: 27))
            board.addQuadCurve(to: CGPoint(x: 9, y: 29), control: CGPoint(x: 5, y: 30))
            board.addLine(to: CGPoint(x: 34, y: 29))
            board.addQuadCurve(to: CGPoint(x: 39, y: 26), control: CGPoint(x: 39, y: 30))
            context.stroke(board, with: .color(accent), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            context.fill(Path(ellipseIn: CGRect(x: 11, y: 30, width: 5, height: 5)), with: .color(white))
            context.fill(Path(ellipseIn: CGRect(x: 31, y: 30, width: 5, height: 5)), with: .color(white))
            var rider = Path()
            rider.move(to: CGPoint(x: 22, y: 17)); rider.addLine(to: CGPoint(x: 18, y: 9))
            rider.move(to: CGPoint(x: 22, y: 17)); rider.addLine(to: CGPoint(x: 14, y: 27))
            rider.move(to: CGPoint(x: 22, y: 17)); rider.addLine(to: CGPoint(x: 32, y: 27))
            rider.move(to: CGPoint(x: 19, y: 11)); rider.addLine(to: CGPoint(x: 10, y: 15))
            rider.move(to: CGPoint(x: 19, y: 11)); rider.addLine(to: CGPoint(x: 30, y: 12))
            context.stroke(rider, with: .color(white), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            context.fill(Path(ellipseIn: CGRect(x: 14, y: 2, width: 9, height: 9)), with: .color(white))
            context.fill(Path(ellipseIn: CGRect(x: 15, y: 3, width: 7, height: 3)), with: .color(accent))
        }
        .accessibilityHidden(true)
    }
}

private struct LimitSlot {
    let x: Double
    let y: Double
    let verticalOffset: CGFloat
}

private enum LimitMarker {
    case hole(x: Double, y: Double, label: String)
    case endpoint(x: Double, y: Double, label: String)
    case jump(x: Double, leftY: Double, rightY: Double, label: String)
    case vertical(x: Double, label: String?)
    case horizontal(y: Double, label: String?)
}

private struct LimitCurve: Identifiable {
    let id: Int
    let equation: String
    let compactEquation: String
    let color: Color
    let slot: LimitSlot
    let exclusions: [Double]
    let markers: [LimitMarker]
    let value: (Double) -> Double?
}

private struct LimitStage {
    let accent: Color
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    let curves: [LimitCurve]

    static let all: [LimitStage] = [
        LimitStage(
            accent: Color(red: 0.22, green: 0.82, blue: 0.94),
            xRange: -2...8,
            yRange: -2...10,
            curves: [
                LimitCurve(id: 0, equation: "lim x→2  (x² − 4)/(x − 2) = 4", compactEquation: "x→2  (x²−4)/(x−2)", color: Color(red: 0.97, green: 0.30, blue: 0.27), slot: LimitSlot(x: -0.55, y: 1.45, verticalOffset: -44), exclusions: [2], markers: [.hole(x: 2, y: 4, label: "4")], value: { x in abs(x - 2) < 0.0001 ? nil : x + 2 }),
                LimitCurve(id: 1, equation: "lim x→4⁻  √(4 − x) = 0", compactEquation: "x→4⁻  √(4−x)", color: Color(red: 0.18, green: 0.79, blue: 1.0), slot: LimitSlot(x: 2.45, y: 1.25, verticalOffset: 49), exclusions: [], markers: [.endpoint(x: 4, y: 0, label: "0")], value: { x in x <= 4 ? sqrt(4 - x) : nil }),
                LimitCurve(id: 2, equation: "lim x→6⁻  1/(6 − x) = +∞", compactEquation: "x→6⁻  1/(6−x)", color: Color(red: 0.25, green: 0.90, blue: 0.44), slot: LimitSlot(x: 5.25, y: 1.35, verticalOffset: -50), exclusions: [6], markers: [.vertical(x: 6, label: "+∞")], value: { x in abs(x - 6) < 0.0001 ? nil : 1 / (6 - x) })
            ]
        ),
        LimitStage(
            accent: Color(red: 0.97, green: 0.58, blue: 0.22),
            xRange: -4...8,
            yRange: -2...10,
            curves: [
                LimitCurve(id: 0, equation: "lim x→1  (x² − 1)/(x − 1) = 2", compactEquation: "x→1  (x²−1)/(x−1)", color: Color(red: 1.0, green: 0.43, blue: 0.25), slot: LimitSlot(x: 1.6, y: 2.6, verticalOffset: -48), exclusions: [1], markers: [.hole(x: 1, y: 2, label: "2")], value: { x in abs(x - 1) < 0.0001 ? nil : x + 1 }),
                LimitCurve(id: 1, equation: "lim x→−1⁺  √(x + 1) = 0", compactEquation: "x→−1⁺  √(x+1)", color: Color(red: 0.20, green: 0.76, blue: 1.0), slot: LimitSlot(x: 3.2, y: 2.1, verticalOffset: 54), exclusions: [], markers: [.endpoint(x: -1, y: 0, label: "0")], value: { x in x >= -1 ? sqrt(x + 1) : nil }),
                LimitCurve(id: 2, equation: "lim x→−2⁺  1/(x + 2) = +∞", compactEquation: "x→−2⁺  1/(x+2)", color: Color(red: 0.40, green: 0.92, blue: 0.46), slot: LimitSlot(x: -1.25, y: 1.35, verticalOffset: -48), exclusions: [-2], markers: [.vertical(x: -2, label: "+∞")], value: { x in abs(x + 2) < 0.0001 ? nil : 1 / (x + 2) })
            ]
        ),
        LimitStage(
            accent: Color(red: 0.74, green: 0.48, blue: 1.0),
            xRange: -6...12,
            yRange: -3...5,
            curves: [
                LimitCurve(id: 0, equation: "lim x→0  sin(x)/x = 1", compactEquation: "x→0  sin(x)/x", color: Color(red: 0.97, green: 0.31, blue: 0.30), slot: LimitSlot(x: -3.4, y: 0.1, verticalOffset: -52), exclusions: [0], markers: [.hole(x: 0, y: 1, label: "1")], value: { x in abs(x) < 0.0001 ? nil : sin(x) / x }),
                LimitCurve(id: 1, equation: "lim x→0  |x|/x = DNE", compactEquation: "x→0  |x|/x", color: Color(red: 1.0, green: 0.72, blue: 0.18), slot: LimitSlot(x: 2.4, y: -1, verticalOffset: 48), exclusions: [0], markers: [.jump(x: 0, leftY: -1, rightY: 1, label: "DNE")], value: { x in abs(x) < 0.0001 ? nil : abs(x) / x }),
                LimitCurve(id: 2, equation: "lim x→∞  (3x − 1)/(x + 2) = 3", compactEquation: "x→∞  (3x−1)/(x+2)", color: Color(red: 0.37, green: 0.88, blue: 0.53), slot: LimitSlot(x: 7.8, y: 2.3, verticalOffset: -48), exclusions: [-2], markers: [.vertical(x: -2, label: nil), .horizontal(y: 3, label: "3")], value: { x in abs(x + 2) < 0.0001 ? nil : (3 * x - 1) / (x + 2) })
            ]
        )
    ]
}

#Preview {
    MathItLevelOneHundredThirtyView(onContinue: {}, onLevelSelect: {})
}
