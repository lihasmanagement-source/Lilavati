import SwiftUI

struct MathItLevelOneHundredThirtyOneView: View {
    private let stages = PipelineContinuityStage.all
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)
    private let steel = Color(red: 0.34, green: 0.43, blue: 0.45)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var offsets = PipelineContinuityStage.all[0].initialOffsets
    @State private var dragOrigins: [Int: Double] = [:]
    @State private var waterProgress: CGFloat = 0
    @State private var running = false
    @State private var feedback: PipelineFeedback?
    @State private var solved = false
    @State private var completed = false
    @State private var animationToken = UUID()

    private var stage: PipelineContinuityStage { stages[stageIndex] }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.016, green: 0.030, blue: 0.040).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    pipelineField
                        .frame(maxWidth: 920)
                        .frame(height: max(420, min(555, proxy.size.height * 0.64)))

                    controls(compact: compact)
                        .frame(maxWidth: 840)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Continuous Flow",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
    }

    private var header: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(stages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex ? cyan : index == stageIndex ? gold : .white.opacity(0.13))
                        .frame(width: index == stageIndex ? 42 : 24, height: 5)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "drop.fill")
                Image(systemName: "arrow.right")
                Image(systemName: solved ? "link" : "link.badge.plus")
            }
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(solved ? cyan : gold)

        }
    }

    private var pipelineField: some View {
        GeometryReader { geo in
            let plot = CGRect(x: 48, y: 64, width: geo.size.width - 96, height: geo.size.height - 116)

            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, _ in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        drawPlant(context: &context, plot: plot)
                        drawBoundaries(context: &context, plot: plot)
                        drawPipeSegments(context: &context, plot: plot)
                        drawWater(context: &context, plot: plot, time: time)
                        drawJunctions(context: &context, plot: plot, time: time)
                        drawLeak(context: &context, plot: plot, time: time)
                    }
                }

                ForEach(stage.segments.indices, id: \.self) { index in
                    dragSurface(for: index, plot: plot)
                }

                if let feedback {
                    Image(systemName: feedback.isSuccess ? "checkmark.seal.fill" : "drop.triangle.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(feedback.isSuccess ? cyan : coral)
                        .padding(10)
                        .background(.black.opacity(0.72), in: Circle())
                        .position(x: plot.midX, y: plot.maxY - 4)
                }
            }
            .background(Color(red: 0.035, green: 0.055, blue: 0.058))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(gold.opacity(0.34), lineWidth: 1))
        }
    }

    private func dragSurface(for index: Int, plot: CGRect) -> some View {
        let segment = stage.segments[index]
        let minX = screenX(segment.start.x, plot: plot)
        let maxX = screenX(segment.end.x, plot: plot)

        return Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .frame(width: max(30, maxX - minX), height: plot.height)
            .position(x: (minX + maxX) / 2, y: plot.midY)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        guard !running && !solved else { return }
                        let origin = dragOrigins[index] ?? offsets[index]
                        if dragOrigins[index] == nil { dragOrigins[index] = origin }
                        let units = -Double(value.translation.height / plot.height) * 6
                        setOffset(index, to: origin + units)
                    }
                    .onEnded { _ in
                        dragOrigins[index] = nil
                        evaluateFit()
                    }
            )
            .accessibilityLabel("Pipe section \(sectionName(index))")
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            HStack(spacing: 8) {
                ForEach(stage.segments.indices, id: \.self) { index in
                    sectionControl(index)
                }

                Button {
                    resetStage()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .black))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(gold)
                .disabled(running)
            }

            HStack(spacing: 7) {
                Text("limₓ→ₐ⁻ f(x)")
                Image(systemName: solved ? "equal" : "questionmark")
                Text("f(a)")
                Image(systemName: solved ? "equal" : "questionmark")
                Text("limₓ→ₐ⁺ f(x)")
            }
            .font(.system(size: compact ? 10 : 12, weight: .black, design: .monospaced))
            .foregroundStyle(solved ? cyan : .white.opacity(0.5))

            Text(stage.equationLabel)
                .font(.system(size: compact ? 10 : 12, weight: .black, design: .monospaced))
                .foregroundStyle(gold.opacity(0.84))
        }
    }

    private func sectionControl(_ index: Int) -> some View {
        HStack(spacing: 4) {
            Button { nudge(index, by: -0.5) } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 27, height: 32)
            }
            .buttonStyle(.plain)

            Image(systemName: "\(index + 1).circle.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(isSectionAligned(index) ? cyan : .white.opacity(0.64))
                .frame(width: 24)

            Button { nudge(index, by: 0.5) } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 27, height: 32)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .background(isSectionAligned(index) ? cyan.opacity(0.12) : .white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .disabled(running || solved)
    }

    private func nudge(_ index: Int, by amount: Double) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
            setOffset(index, to: offsets[index] + amount)
        }
        DispatchQueue.main.async { evaluateFit() }
    }

    private func setOffset(_ index: Int, to value: Double) {
        let snapped = min(2, max(-2, (value * 2).rounded() / 2))
        offsets[index] = snapped
        feedback = nil
        waterProgress = 0
    }

    private func evaluateFit() {
        guard !running, !solved, firstBrokenJunction() == nil else { return }
        pressurize()
    }

    private func isSectionAligned(_ index: Int) -> Bool {
        abs(offsets[index] - stage.segments[index].targetOffset) < 0.1
    }

    private func resetStage() {
        animationToken = UUID()
        offsets = stage.initialOffsets
        dragOrigins = [:]
        waterProgress = 0
        running = false
        feedback = nil
        solved = false
    }

    private func pressurize() {
        guard !running, firstBrokenJunction() == nil else { return }
        running = true
        feedback = nil
        waterProgress = 0
        let token = animationToken
        let flowDuration = stageIndex == 0 ? 0.75 : 2.2

        withAnimation(.linear(duration: flowDuration)) { waterProgress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + flowDuration + 0.05) {
            guard token == animationToken else { return }
            running = false
            solved = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { feedback = .flowing }
            finishStage()
        }
    }

    private func firstBrokenJunction() -> Int? {
        for index in 0..<(stage.segments.count - 1) {
            let junction = stage.junctionValue(index)
            let left = stage.segments[index].end.y + offsets[index]
            let right = stage.segments[index + 1].start.y + offsets[index + 1]
            if abs(left - junction) > 0.1 || abs(right - junction) > 0.1 { return index }
        }
        return nil
    }

    private func finishStage() {
        let token = animationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard token == animationToken else { return }
            if stageIndex == stages.count - 1 {
                withAnimation { completed = true }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    stageIndex += 1
                    offsets = stages[stageIndex].initialOffsets
                    dragOrigins = [:]
                    waterProgress = 0
                    feedback = nil
                    solved = false
                }
            }
        }
    }

    private func resetLevel() {
        animationToken = UUID()
        stageIndex = 0
        offsets = stages[0].initialOffsets
        dragOrigins = [:]
        waterProgress = 0
        running = false
        feedback = nil
        solved = false
        completed = false
    }

    private func drawPlant(context: inout GraphicsContext, plot: CGRect) {
        let wall = CGRect(x: plot.minX - 34, y: plot.minY - 42, width: plot.width + 68, height: plot.height + 72)
        context.fill(Path(roundedRect: wall, cornerRadius: 6), with: .color(Color(red: 0.105, green: 0.058, blue: 0.050)))

        let brickHeight: CGFloat = 27
        let brickWidth: CGFloat = 62
        let rows = Int(ceil(wall.height / brickHeight))
        let columns = Int(ceil(wall.width / brickWidth)) + 1
        for row in 0...rows {
            let y = min(wall.maxY, wall.minY + CGFloat(row) * brickHeight)
            var mortar = Path()
            mortar.move(to: CGPoint(x: wall.minX, y: y))
            mortar.addLine(to: CGPoint(x: wall.maxX, y: y))
            context.stroke(mortar, with: .color(Color(red: 0.72, green: 0.40, blue: 0.28).opacity(0.10)), lineWidth: 1.2)

            let stagger = row.isMultiple(of: 2) ? CGFloat(0) : -brickWidth / 2
            for column in 0...columns {
                let x = wall.minX + stagger + CGFloat(column) * brickWidth
                if wall.minX...wall.maxX ~= x {
                    var joint = Path()
                    joint.move(to: CGPoint(x: x, y: y))
                    joint.addLine(to: CGPoint(x: x, y: min(wall.maxY, y + brickHeight)))
                    context.stroke(joint, with: .color(Color(red: 0.72, green: 0.40, blue: 0.28).opacity(0.08)), lineWidth: 1)
                }

                if column.isMultiple(of: 3) {
                    let brick = CGRect(x: x + 3, y: y + 3, width: brickWidth - 6, height: brickHeight - 6)
                        .intersection(wall.insetBy(dx: 1, dy: 1))
                    if !brick.isNull && brick.width > 0 && brick.height > 0 {
                        context.fill(Path(roundedRect: brick, cornerRadius: 2), with: .color(Color(red: 0.34, green: 0.13, blue: 0.09).opacity(0.08)))
                    }
                }
            }
        }

        drawBackdropPipe(
            context: &context,
            points: [
                CGPoint(x: wall.minX + 10, y: wall.maxY - 12),
                CGPoint(x: wall.minX + 10, y: wall.minY + 22),
                CGPoint(x: wall.maxX - 28, y: wall.minY + 22),
                CGPoint(x: wall.maxX - 28, y: plot.midY - 58)
            ],
            width: 13
        )
        drawBackdropPipe(
            context: &context,
            points: [
                CGPoint(x: wall.minX + 24, y: plot.minY + 54),
                CGPoint(x: wall.midX - 74, y: plot.minY + 54),
                CGPoint(x: wall.midX - 74, y: plot.midY - 6)
            ],
            width: 9
        )
        drawBackdropPipe(
            context: &context,
            points: [
                CGPoint(x: wall.midX + 62, y: plot.minY + 38),
                CGPoint(x: wall.midX + 62, y: wall.maxY - 22),
                CGPoint(x: wall.maxX - 14, y: wall.maxY - 22)
            ],
            width: 11
        )

        drawPipeCollar(context: &context, center: CGPoint(x: wall.minX + 10, y: plot.minY + 78), vertical: true, size: 13)
        drawPipeCollar(context: &context, center: CGPoint(x: wall.midX - 74, y: plot.minY + 54), vertical: false, size: 9)
        drawPipeCollar(context: &context, center: CGPoint(x: wall.midX + 62, y: plot.minY + 88), vertical: true, size: 11)
        drawPipeCollar(context: &context, center: CGPoint(x: wall.maxX - 28, y: plot.minY + 24), vertical: true, size: 13)

        let regulator = CGRect(x: wall.midX + 39, y: wall.maxY - 65, width: 46, height: 38)
        context.fill(Path(roundedRect: regulator.offsetBy(dx: 3, dy: 4), cornerRadius: 6), with: .color(.black.opacity(0.22)))
        context.fill(Path(roundedRect: regulator, cornerRadius: 6), with: .color(steel.opacity(0.25)))
        context.stroke(Path(roundedRect: regulator, cornerRadius: 6), with: .color(.white.opacity(0.10)), lineWidth: 1.2)
        for bolt in [CGPoint(x: regulator.minX + 7, y: regulator.minY + 7), CGPoint(x: regulator.maxX - 7, y: regulator.minY + 7), CGPoint(x: regulator.minX + 7, y: regulator.maxY - 7), CGPoint(x: regulator.maxX - 7, y: regulator.maxY - 7)] {
            context.fill(Path(ellipseIn: CGRect(x: bolt.x - 2, y: bolt.y - 2, width: 4, height: 4)), with: .color(.white.opacity(0.18)))
        }

        let valve = CGPoint(x: wall.maxX - 28, y: plot.midY - 58)
        context.stroke(Path(ellipseIn: CGRect(x: valve.x - 14, y: valve.y - 14, width: 28, height: 28)), with: .color(gold.opacity(0.30)), lineWidth: 3)
        var spokes = Path()
        spokes.move(to: CGPoint(x: valve.x - 11, y: valve.y))
        spokes.addLine(to: CGPoint(x: valve.x + 11, y: valve.y))
        spokes.move(to: CGPoint(x: valve.x, y: valve.y - 11))
        spokes.addLine(to: CGPoint(x: valve.x, y: valve.y + 11))
        context.stroke(spokes, with: .color(gold.opacity(0.30)), lineWidth: 2)

        for value in 0...6 {
            let y = screenY(Double(value), plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(line, with: .color(.white.opacity(value == 0 ? 0.24 : 0.075)), lineWidth: value == 0 ? 1.5 : 1)
            context.draw(
                Text("\(value)").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.24)),
                at: CGPoint(x: plot.minX - 13, y: y)
            )
        }
        for column in 0...8 {
            let x = plot.minX + CGFloat(column) / 8 * plot.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: plot.minY))
            line.addLine(to: CGPoint(x: x, y: plot.maxY))
            let value = column - 4
            context.stroke(line, with: .color(.white.opacity(value == 0 ? 0.22 : 0.065)), lineWidth: value == 0 ? 1.5 : 1)
            context.draw(
                Text("\(value)").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.24)),
                at: CGPoint(x: x, y: plot.maxY + 10)
            )
        }
    }

    private func drawBackdropPipe(context: inout GraphicsContext, points: [CGPoint], width: CGFloat) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        context.stroke(path, with: .color(.black.opacity(0.52)), style: StrokeStyle(lineWidth: width + 6, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(steel.opacity(0.34)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func drawPipeCollar(context: inout GraphicsContext, center: CGPoint, vertical: Bool, size: CGFloat) {
        let collar = vertical
            ? CGRect(x: center.x - size / 2 - 4, y: center.y - 4, width: size + 8, height: 8)
            : CGRect(x: center.x - 4, y: center.y - size / 2 - 4, width: 8, height: size + 8)
        context.fill(Path(roundedRect: collar.offsetBy(dx: 1.5, dy: 2), cornerRadius: 2), with: .color(.black.opacity(0.34)))
        context.fill(Path(roundedRect: collar, cornerRadius: 2), with: .color(steel.opacity(0.48)))
        context.stroke(Path(roundedRect: collar, cornerRadius: 2), with: .color(.white.opacity(0.16)), lineWidth: 1)
    }

    private func drawBoundaries(context: inout GraphicsContext, plot: CGRect) {
        for index in 0..<(stage.segments.count - 1) {
            let xValue = stage.segments[index].end.x
            let x = screenX(xValue, plot: plot)
            var boundary = Path()
            boundary.move(to: CGPoint(x: x, y: plot.minY))
            boundary.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(boundary, with: .color(gold.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
            context.draw(Text("a\(index + 1)").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(gold.opacity(0.55)), at: CGPoint(x: x, y: plot.minY + 10))
        }
    }

    private func drawPipeSegments(context: inout GraphicsContext, plot: CGRect) {
        for index in stage.segments.indices {
            let startT = index == stage.segments.startIndex ? 0.0 : 0.035
            let endT = index == stage.segments.index(before: stage.segments.endIndex) ? 1.0 : 0.965
            let path = segmentPath(stage.segments[index], offset: offsets[index], plot: plot, from: startT, to: endT)
            context.stroke(path, with: .color(.black.opacity(0.82)), style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(steel), style: StrokeStyle(lineWidth: 17, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(.white.opacity(0.20)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(.black.opacity(0.52)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

            let midpoint = stage.segments[index].point(at: 0.5, offset: offsets[index])
            let handle = screenPoint(midpoint, plot: plot)
            context.fill(Path(ellipseIn: CGRect(x: handle.x - 13, y: handle.y - 13, width: 26, height: 26)), with: .color(Color(red: 0.025, green: 0.045, blue: 0.048)))
            context.stroke(Path(ellipseIn: CGRect(x: handle.x - 13, y: handle.y - 13, width: 26, height: 26)), with: .color(isSectionAligned(index) ? cyan : gold.opacity(0.72)), lineWidth: 2)
            context.draw(Text("↕").font(.system(size: 13, weight: .black)).foregroundColor(isSectionAligned(index) ? cyan : .white.opacity(0.74)), at: handle)
        }
    }

    private func drawWater(context: inout GraphicsContext, plot: CGRect, time: TimeInterval) {
        if running || solved {
            let visibleProgress = solved ? CGFloat(1) : waterProgress
            let scaled = visibleProgress * CGFloat(stage.segments.count)
            for index in stage.segments.indices {
                let local = min(1, max(0, scaled - CGFloat(index)))
                guard local > 0 else { continue }
                let path = segmentPath(stage.segments[index], offset: offsets[index], plot: plot, progress: local)
                drawWaterBody(context: &context, path: path, time: time, phase: Double(index) * 0.7)
            }
            drawFlowParticles(context: &context, plot: plot, time: time, visibleProgress: visibleProgress)
            if visibleProgress > 0.90 {
                drawOutletSpout(
                    context: &context,
                    plot: plot,
                    time: time,
                    intensity: min(1, (visibleProgress - 0.90) / 0.10)
                )
            }
            return
        }

        guard let broken = firstBrokenJunction() else { return }
        for index in 0...broken {
            let startT = index == 0 ? 0.0 : 0.035
            let endT = index == broken ? 0.965 : 1.0
            let path = segmentPath(stage.segments[index], offset: offsets[index], plot: plot, from: startT, to: endT)
            drawWaterBody(context: &context, path: path, time: time, phase: Double(index) * 0.7)
        }

    }

    private func drawWaterBody(context: inout GraphicsContext, path: Path, time: TimeInterval, phase: Double) {
        let pulse = 0.5 + 0.5 * sin(time * 3.4 + phase)
        context.stroke(path, with: .color(cyan.opacity(0.14 + pulse * 0.08)), style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(Color(red: 0.04, green: 0.55, blue: 0.67).opacity(0.95)), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(cyan.opacity(0.96)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        context.stroke(
            path,
            with: .color(.white.opacity(0.54)),
            style: StrokeStyle(lineWidth: 2.1, lineCap: .round, dash: [16, 25], dashPhase: CGFloat(-time * 52 - phase * 14))
        )
        context.stroke(
            path,
            with: .color(Color(red: 0.55, green: 0.98, blue: 1).opacity(0.30)),
            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [4, 43], dashPhase: CGFloat(-time * 37 - phase * 9))
        )
    }

    private func drawFlowParticles(context: inout GraphicsContext, plot: CGRect, time: TimeInterval, visibleProgress: CGFloat) {
        let count = 28
        let segmentCount = stage.segments.count
        for particle in 0..<count {
            let cycle = (time * 0.22 + Double(particle) / Double(count)).truncatingRemainder(dividingBy: 1)
            guard cycle <= Double(visibleProgress) else { continue }

            let scaled = cycle * Double(segmentCount)
            let index = min(segmentCount - 1, Int(scaled))
            let local = min(1, scaled - Double(index))
            let beforeT = max(0, local - 0.012)
            let afterT = min(1, local + 0.012)
            let point = screenPoint(stage.segments[index].point(at: local, offset: offsets[index]), plot: plot)
            let before = screenPoint(stage.segments[index].point(at: beforeT, offset: offsets[index]), plot: plot)
            let after = screenPoint(stage.segments[index].point(at: afterT, offset: offsets[index]), plot: plot)
            let dx = after.x - before.x
            let dy = after.y - before.y
            let length = max(0.001, hypot(dx, dy))
            let drift = CGFloat(sin(time * 4.1 + Double(particle) * 1.37)) * 2.2
            let center = CGPoint(x: point.x - dy / length * drift, y: point.y + dx / length * drift)
            let size = CGFloat(2.4 + Double(particle % 4))
            let bubble = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
            context.fill(Path(ellipseIn: bubble), with: .color(.white.opacity(0.42 + Double(particle % 3) * 0.12)))
            if particle % 3 == 0 {
                context.stroke(Path(ellipseIn: bubble.insetBy(dx: -1.2, dy: -1.2)), with: .color(cyan.opacity(0.68)), lineWidth: 1)
            }
        }
    }

    private func drawOutletSpout(context: inout GraphicsContext, plot: CGRect, time: TimeInterval, intensity: CGFloat) {
        let finalIndex = stage.segments.index(before: stage.segments.endIndex)
        let segment = stage.segments[finalIndex]
        let outlet = screenPoint(segment.point(at: 1, offset: offsets[finalIndex]), plot: plot)
        let before = screenPoint(segment.point(at: 0.97, offset: offsets[finalIndex]), plot: plot)
        let dx = outlet.x - before.x
        let dy = outlet.y - before.y
        let length = max(0.001, hypot(dx, dy))
        let direction = CGVector(dx: dx / length, dy: dy / length)
        let normal = CGVector(dx: -direction.dy, dy: direction.dx)

        for strand in 0..<4 {
            let spread = CGFloat(strand) - 1.5
            let flutter = CGFloat(sin(time * 6.3 + Double(strand) * 1.4)) * 2.4
            let control = CGPoint(
                x: outlet.x + direction.dx * 15 + normal.dx * (spread * 2 + flutter),
                y: outlet.y + direction.dy * 15 + normal.dy * (spread * 2 + flutter) + 2
            )
            let end = CGPoint(
                x: outlet.x + direction.dx * (31 * intensity) + normal.dx * spread * 3,
                y: outlet.y + direction.dy * (31 * intensity) + normal.dy * spread * 3 + 18 * intensity
            )
            var jet = Path()
            jet.move(to: CGPoint(x: outlet.x + normal.dx * spread, y: outlet.y + normal.dy * spread))
            jet.addQuadCurve(to: end, control: control)
            context.stroke(
                jet,
                with: .color(strand == 1 || strand == 2 ? cyan.opacity(0.90) : cyan.opacity(0.48)),
                style: StrokeStyle(lineWidth: strand == 1 || strand == 2 ? 4.2 : 2.2, lineCap: .round)
            )
        }

        for drop in 0..<9 {
            let cycle = (time * 1.25 + Double(drop) * 0.105).truncatingRemainder(dividingBy: 1)
            let travel = CGFloat(cycle) * intensity
            let x = outlet.x + direction.dx * (12 + travel * 27) + normal.dx * CGFloat(drop % 3 - 1) * 4
            let y = outlet.y + direction.dy * (12 + travel * 27) + 12 * travel + 28 * travel * travel
            let size = CGFloat(2.5 + Double(drop % 3))
            context.fill(
                Path(ellipseIn: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size * 1.45)),
                with: .color(cyan.opacity(0.72))
            )
        }
    }

    private func drawJunctions(context: inout GraphicsContext, plot: CGRect, time: TimeInterval) {
        for index in 0..<(stage.segments.count - 1) {
            let point = PipelinePoint(x: stage.segments[index].end.x, y: stage.junctionValue(index))
            let screen = screenPoint(point, plot: plot)
            let aligned = abs(stage.segments[index].end.y + offsets[index] - stage.junctionValue(index)) < 0.1
                && abs(stage.segments[index + 1].start.y + offsets[index + 1] - stage.junctionValue(index)) < 0.1
            if aligned && (running || solved) {
                let ripple = (time * 1.4 + Double(index) * 0.28).truncatingRemainder(dividingBy: 1)
                let radius = CGFloat(12 + ripple * 12)
                context.stroke(
                    Path(ellipseIn: CGRect(x: screen.x - radius, y: screen.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(cyan.opacity(0.34 * (1 - ripple))),
                    lineWidth: 2
                )
            }
            let fitting = CGRect(x: screen.x - 9, y: screen.y - 18, width: 18, height: 36)
            context.fill(Path(roundedRect: fitting, cornerRadius: 4), with: .color(aligned ? cyan.opacity(0.34) : Color(red: 0.025, green: 0.045, blue: 0.048)))
            context.stroke(
                Path(roundedRect: fitting, cornerRadius: 4),
                with: .color(aligned ? cyan : gold.opacity(0.75)),
                style: StrokeStyle(lineWidth: aligned ? 3 : 2, dash: aligned ? [] : [4, 3])
            )
            for boltY in [-10.0, 10.0] {
                context.fill(Path(ellipseIn: CGRect(x: screen.x - 2, y: screen.y + boltY - 2, width: 4, height: 4)), with: .color(.white.opacity(0.62)))
            }
        }
    }

    private func drawLeak(context: inout GraphicsContext, plot: CGRect, time: TimeInterval) {
        guard !running, !solved, let index = firstBrokenJunction() else { return }
        let outlet = screenPoint(stage.segments[index].point(at: 0.965, offset: offsets[index]), plot: plot)
        for drop in 0..<7 {
            let cycle = (time * 0.95 + Double(drop) * 0.14).truncatingRemainder(dividingBy: 1)
            let x = outlet.x + 5 + CGFloat(cycle * 34) + CGFloat(drop % 2) * 3
            let y = outlet.y + CGFloat(cycle * cycle * 88) - CGFloat(drop % 3) * 2
            let size = CGFloat(5 + drop % 3)
            context.fill(Path(ellipseIn: CGRect(x: x - size / 2, y: y - size, width: size, height: size * 1.5)), with: .color(cyan.opacity(0.82)))
        }
    }

    private func segmentPath(_ segment: PipelineSegment, offset: Double, plot: CGRect, from startT: Double, to endT: Double) -> Path {
        var path = Path()
        let samples = 80
        for sample in 0...samples {
            let progress = Double(sample) / Double(samples)
            let t = startT + (endT - startT) * progress
            let point = screenPoint(segment.point(at: t, offset: offset), plot: plot)
            sample == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }

    private func segmentPath(_ segment: PipelineSegment, offset: Double, plot: CGRect, progress: CGFloat) -> Path {
        var path = Path()
        let samples = max(1, Int(80 * progress))
        for sample in 0...samples {
            let t = Double(sample) / 80
            let point = screenPoint(segment.point(at: t, offset: offset), plot: plot)
            sample == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }

    private func screenPoint(_ point: PipelinePoint, plot: CGRect) -> CGPoint {
        CGPoint(x: screenX(point.x, plot: plot), y: screenY(point.y, plot: plot))
    }

    private func screenX(_ x: Double, plot: CGRect) -> CGFloat {
        plot.minX + CGFloat((x + 4) / 8) * plot.width
    }

    private func screenY(_ y: Double, plot: CGRect) -> CGFloat {
        plot.maxY - CGFloat(y / 6) * plot.height
    }

    private func sectionName(_ index: Int) -> String {
        String(UnicodeScalar(65 + index)!)
    }

}

private struct PipelinePoint {
    let x: Double
    let y: Double
}

private struct PipelineSegment {
    let startX: Double
    let endX: Double
    let equation: PipelineEquation
    let targetOffset: Double

    var start: PipelinePoint {
        PipelinePoint(x: startX, y: equation.value(at: startX))
    }

    var end: PipelinePoint {
        PipelinePoint(x: endX, y: equation.value(at: endX))
    }

    func point(at t: Double, offset: Double) -> PipelinePoint {
        let x = startX + (endX - startX) * t
        return PipelinePoint(x: x, y: equation.value(at: x) + offset)
    }
}

private struct PipelineEquation {
    // Coefficients are stored in ascending powers: c0 + c1x + c2x² ...
    let coefficients: [Double]

    func value(at x: Double) -> Double {
        coefficients.reversed().reduce(0) { partial, coefficient in
            partial * x + coefficient
        }
    }
}

private struct PipelineContinuityStage {
    let equationLabel: String
    let segments: [PipelineSegment]
    let initialOffsets: [Double]

    func junctionValue(_ index: Int) -> Double {
        segments[index].end.y + segments[index].targetOffset
    }

    static let all = [
        PipelineContinuityStage(
            equationLabel: "f(x) = −0.18x² + 3.8",
            segments: [
                PipelineSegment(startX: -4, endX: 0, equation: PipelineEquation(coefficients: [3.8, 0, -0.18]), targetOffset: 0),
                PipelineSegment(startX: 0, endX: 4, equation: PipelineEquation(coefficients: [3.8, 0, -0.18]), targetOffset: 0)
            ],
            initialOffsets: [-1, 1]
        ),
        PipelineContinuityStage(
            equationLabel: "f(x) = 0.035x³ − 0.22x + 2.7",
            segments: [
                PipelineSegment(startX: -4, endX: -1, equation: PipelineEquation(coefficients: [2.7, -0.22, 0, 0.035]), targetOffset: 0),
                PipelineSegment(startX: -1, endX: 2, equation: PipelineEquation(coefficients: [2.7, -0.22, 0, 0.035]), targetOffset: 0),
                PipelineSegment(startX: 2, endX: 4, equation: PipelineEquation(coefficients: [2.7, -0.22, 0, 0.035]), targetOffset: 0)
            ],
            initialOffsets: [-1, 1, -0.5]
        ),
        PipelineContinuityStage(
            equationLabel: "f(x) = 0.015x⁴ − 0.24x² + 3.4",
            segments: [
                PipelineSegment(startX: -4, endX: -2, equation: PipelineEquation(coefficients: [3.4, 0, -0.24, 0, 0.015]), targetOffset: 0),
                PipelineSegment(startX: -2, endX: 0, equation: PipelineEquation(coefficients: [3.4, 0, -0.24, 0, 0.015]), targetOffset: 0),
                PipelineSegment(startX: 0, endX: 2, equation: PipelineEquation(coefficients: [3.4, 0, -0.24, 0, 0.015]), targetOffset: 0),
                PipelineSegment(startX: 2, endX: 4, equation: PipelineEquation(coefficients: [3.4, 0, -0.24, 0, 0.015]), targetOffset: 0)
            ],
            initialOffsets: [-1, 1, -0.5, 1.5]
        )
    ]
}

private enum PipelineFeedback {
    case flowing

    var isSuccess: Bool {
        true
    }
}

#Preview {
    MathItLevelOneHundredThirtyOneView(onContinue: {}, onLevelSelect: {})
}
