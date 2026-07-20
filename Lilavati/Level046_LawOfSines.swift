import SwiftUI

@Observable
final class MathItLevelNineteenViewModel {
    var pullOffset = CGSize.zero
    var triangleCreated = false
    var triangleOffset = CGSize.zero
    var multiplyOffset = CGSize.zero
    var heightOffset = CGSize.zero
    var equalsOffset = CGSize.zero
    var triangleSnapped = false
    var multiplySnapped = false
    var heightSnapped = false
    var equalsSnapped = false
    var prismCreated = false
    var prismFormation: CGFloat = 0
    var prismOffset = CGSize.zero
    var prismPlaced = false
    var boxCharge: CGFloat = 0
    var boxBroken = false
    var ballEscaped = false
    var ballPosition = CGPoint.zero
    var completed = false

    var progress: Double {
        let build = (triangleCreated ? 0.18 : 0)
        let equation = ([triangleSnapped, multiplySnapped, heightSnapped, equalsSnapped].filter { $0 }.count)
        let prism = prismCreated ? 0.16 : 0
        let placed = prismPlaced ? 0.16 : 0
        return min(1, 0.08 + build + Double(equation) * 0.09 + prism + placed + Double(boxCharge) * 0.14)
    }

    func updatePull(_ translation: CGSize) {
        guard !triangleCreated else { return }
        pullOffset = CGSize(
            width: min(100, max(0, translation.width)),
            height: 0
        )
    }

    func finishPull(triangleSource: CGPoint) {
        guard !triangleCreated else { return }
        if pullOffset.width > 68 {
            HapticPlayer.playLightTap()
            triangleCreated = true
            triangleOffset = CGSize(width: 0, height: -58)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
                triangleOffset = .zero
            }
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            pullOffset = .zero
        }
    }

    func moveTriangle(to point: CGPoint, source: CGPoint) {
        guard triangleCreated, !prismCreated else { return }
        triangleOffset = CGSize(width: point.x - source.x, height: point.y - source.y)
    }

    func finishTriangle(at point: CGPoint, slot: CGRect, source: CGPoint) {
        guard triangleCreated, !prismCreated else { return }
        if slot.insetBy(dx: -22, dy: -22).contains(point) {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                triangleSnapped = true
                triangleOffset = CGSize(width: slot.midX - source.x, height: slot.midY - source.y)
            }
            checkPrism()
        }
    }

    func moveSymbol(_ symbol: LevelNineteenSymbol, to point: CGPoint, source: CGPoint) {
        guard !prismCreated else { return }
        let offset = CGSize(width: point.x - source.x, height: point.y - source.y)
        switch symbol {
        case .multiply: multiplyOffset = offset
        case .height: heightOffset = offset
        case .equals: equalsOffset = offset
        }
    }

    func finishSymbol(_ symbol: LevelNineteenSymbol, at point: CGPoint, slot: CGRect, source: CGPoint) {
        guard !prismCreated else { return }
        if slot.insetBy(dx: -20, dy: -20).contains(point) {
            HapticPlayer.playLightTap()
            let offset = CGSize(width: slot.midX - source.x, height: slot.midY - source.y)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                switch symbol {
                case .multiply:
                    multiplySnapped = true
                    multiplyOffset = offset
                case .height:
                    heightSnapped = true
                    heightOffset = offset
                case .equals:
                    equalsSnapped = true
                    equalsOffset = offset
                }
            }
            checkPrism()
        }
    }

    func movePrism(to point: CGPoint, source: CGPoint) {
        guard prismCreated, !prismPlaced else { return }
        prismOffset = CGSize(width: point.x - source.x, height: point.y - source.y)
    }

    func finishPrism(at point: CGPoint, target: CGRect, source: CGPoint, ballStart: CGPoint, ballEnd: CGPoint) {
        guard prismCreated, !prismPlaced else { return }
        if target.insetBy(dx: -22, dy: -22).contains(point) {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                prismPlaced = true
                prismOffset = CGSize(width: target.midX - source.x, height: target.midY - source.y)
            }
            chargeBox(ballStart: ballStart, ballEnd: ballEnd)
        }
    }

    private func checkPrism() {
        guard triangleSnapped, multiplySnapped, heightSnapped, equalsSnapped, !prismCreated else { return }
        HapticPlayer.playCompletionTap()
        withAnimation(.easeInOut(duration: 0.9)) {
            prismCreated = true
            prismFormation = 1
        }
    }

    private func chargeBox(ballStart: CGPoint, ballEnd: CGPoint) {
        withAnimation(.linear(duration: 1.8)) {
            boxCharge = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.82) {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                self.boxBroken = true
            }
            self.escapeBall(from: ballStart, to: ballEnd)
        }
    }

    private func escapeBall(from start: CGPoint, to end: CGPoint) {
        ballEscaped = true
        ballPosition = start
        let firstLand = CGPoint(x: start.x - 82, y: start.y + 24)
        let firstHop = CGPoint(x: start.x - 42, y: start.y - 30)
        let secondHop = CGPoint(x: start.x - 124, y: start.y - 26)

        withAnimation(.easeInOut(duration: 0.5)) {
            ballPosition = firstHop
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.48)) {
                self.ballPosition = firstLand
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.98) {
            withAnimation(.easeInOut(duration: 0.55)) {
                self.ballPosition = secondHop
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.53) {
            withAnimation(.easeInOut(duration: 0.7)) {
                self.ballPosition = end
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }
}

enum LevelNineteenSymbol {
    case multiply
    case height
    case equals
}

struct MathItLevelNineteenView: View {
    var viewModel: MathItLevelNineteenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 22, y: size.height * 0.18, width: size.width - 44, height: min(360, size.height * 0.45))
            let slots = expressionSlots(size: size)
            let workY = (board.maxY + slots[0].minY) / 2
            let launcherAnchor = CGPoint(x: size.width * 0.18, y: workY)
            let triangleSource = CGPoint(x: size.width * 0.32, y: workY)
            let multiplySource = CGPoint(x: size.width * 0.42, y: workY - 4)
            let heightSource = CGPoint(x: size.width * 0.58, y: workY - 4)
            let equalsSource = CGPoint(x: size.width * 0.77, y: workY - 4)
            let prismSource = CGPoint(x: size.width * 0.5, y: workY - 92)
            let prismTarget = CGRect(x: board.minX + board.width * 0.42 - 48, y: board.midY - 58, width: 96, height: 116)
            let boxFrame = CGRect(x: board.maxX - 82, y: board.midY - 44, width: 82, height: 82)
            let ballStart = CGPoint(x: boxFrame.midX, y: boxFrame.midY)
            let ballEnd = CGPoint(x: -36, y: boxFrame.midY - 76)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    EmptyView()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.mathGold.opacity(0.85))

                    EmptyView()
                        .font(.trajan(36))
                        .foregroundStyle(Color.mathGold.opacity(viewModel.completed ? 1 : 0.32))
                }
                .position(x: size.width / 2, y: 74)

                ProgressView(value: viewModel.progress)
                    .tint(.white)
                    .opacity(0.72)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 128)

                prismBoard(
                    frame: board,
                    prismTarget: prismTarget,
                    boxFrame: boxFrame,
                    ballStart: ballStart
                )

                expressionSlots(slots)

                launcher(anchor: launcherAnchor, triangleSource: triangleSource)

                constructionPieces(
                    triangleSource: triangleSource,
                    multiplySource: multiplySource,
                    heightSource: heightSource,
                    equalsSource: equalsSource,
                    slots: slots
                )

                if viewModel.prismCreated {
                    draggablePrism(source: prismSource, target: prismTarget, ballStart: ballStart, ballEnd: ballEnd)
                }

                CompletionOverlay(
                    title: "Level 19 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private func prismBoard(frame: CGRect, prismTarget: CGRect, boxFrame: CGRect, ballStart: CGPoint) -> some View {
        let source = CGPoint(x: frame.minX + 18, y: boxFrame.midY)
        let targetPoint = CGPoint(x: boxFrame.minX, y: boxFrame.midY)

        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.16), lineWidth: 1.2)
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            PrismGridShape()
                .stroke(.white.opacity(0.055), lineWidth: 1)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            if viewModel.prismPlaced {
                animatedLightBeam(from: source, to: CGPoint(x: prismTarget.midX - 42, y: prismTarget.midY))

                rainbowBeam(
                    from: CGPoint(x: prismTarget.midX + 38, y: prismTarget.midY),
                    to: targetPoint
                )
            } else {
                animatedLightBeam(from: source, to: targetPoint)
            }

            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .shadow(color: .white.opacity(0.8), radius: 12)
                .position(source)

            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.mathItGeometry.opacity(viewModel.prismPlaced ? 0.12 : 0.54), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                .frame(width: prismTarget.width, height: prismTarget.height)
                .position(x: prismTarget.midX, y: prismTarget.midY)

            lockedBox(frame: boxFrame, ballStart: ballStart)
        }
    }

    private func lockedBox(frame: CGRect, ballStart: CGPoint) -> some View {
        ZStack {
            if viewModel.boxBroken {
                boxShard(offset: CGSize(width: -34, height: -24), rotation: .degrees(-24))
                    .position(x: frame.midX, y: frame.midY)
                boxShard(offset: CGSize(width: 34, height: -18), rotation: .degrees(25))
                    .position(x: frame.midX, y: frame.midY)
                boxShard(offset: CGSize(width: -26, height: 31), rotation: .degrees(18))
                    .position(x: frame.midX, y: frame.midY)
                boxShard(offset: CGSize(width: 30, height: 30), rotation: .degrees(-18))
                    .position(x: frame.midX, y: frame.midY)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.56), lineWidth: 2)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)

                Rectangle()
                    .fill(Color.mathItGeometry.opacity(0.42))
                    .frame(width: max(0, (frame.width - 10) * viewModel.boxCharge), height: 6)
                    .position(x: frame.minX + 5 + (frame.width - 10) * viewModel.boxCharge / 2, y: frame.maxY - 9)
            }

            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
                .shadow(color: .white.opacity(0.55), radius: 12)
                .position(viewModel.ballEscaped ? viewModel.ballPosition : ballStart)
        }
    }

    private func launcher(anchor: CGPoint, triangleSource: CGPoint) -> some View {
        let creatorBlue = Color.mathItGeometry
        let ballPoint = CGPoint(x: anchor.x + viewModel.pullOffset.width, y: anchor.y)
        let top = CGPoint(x: anchor.x, y: anchor.y - 58)
        let bottom = CGPoint(x: anchor.x, y: anchor.y + 58)

        return ZStack {
            Path { path in
                path.move(to: top)
                path.addLine(to: bottom)
            }
            .stroke(creatorBlue.opacity(0.76), lineWidth: 3)
            .shadow(color: creatorBlue.opacity(0.28), radius: 8)

            Path { path in
                path.move(to: top)
                path.addLine(to: ballPoint)
                path.addLine(to: bottom)
            }
            .stroke(creatorBlue.opacity(viewModel.pullOffset.width > 4 ? 0.86 : 0.34), lineWidth: 2)
            .shadow(color: creatorBlue.opacity(viewModel.pullOffset.width > 4 ? 0.32 : 0.08), radius: 8)

            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .white.opacity(0.6), radius: 10)
                .position(ballPoint)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewModel.updatePull(value.translation)
                        }
                        .onEnded { _ in
                            viewModel.finishPull(triangleSource: triangleSource)
                        }
                )
        }
    }

    private func constructionPieces(
        triangleSource: CGPoint,
        multiplySource: CGPoint,
        heightSource: CGPoint,
        equalsSource: CGPoint,
        slots: [CGRect]
    ) -> some View {
        ZStack {
            if viewModel.triangleCreated {
                CreatorTriangleShape()
                    .fill(Color.mathItGeometry.opacity(0.05))
                    .overlay {
                        CreatorTriangleShape()
                            .stroke(Color.mathItGeometry.opacity(0.9), lineWidth: 2.2)
                    }
                    .frame(width: 100, height: 116)
                    .position(x: triangleSource.x + viewModel.triangleOffset.width, y: triangleSource.y + viewModel.triangleOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                viewModel.moveTriangle(to: value.location, source: triangleSource)
                            }
                            .onEnded { value in
                                viewModel.finishTriangle(at: value.location, slot: slots[0], source: triangleSource)
                            }
                    )
            }

            symbolView("x")
                .position(x: multiplySource.x + viewModel.multiplyOffset.width, y: multiplySource.y + viewModel.multiplyOffset.height)
                .gesture(symbolDrag(.multiply, source: multiplySource, slot: slots[1]))

            Text("height")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .position(x: heightSource.x + viewModel.heightOffset.width, y: heightSource.y + viewModel.heightOffset.height)
                .gesture(symbolDrag(.height, source: heightSource, slot: slots[2]))

            symbolView("=")
                .position(x: equalsSource.x + viewModel.equalsOffset.width, y: equalsSource.y + viewModel.equalsOffset.height)
                .gesture(symbolDrag(.equals, source: equalsSource, slot: slots[3]))
        }
        .opacity(viewModel.prismCreated ? 0.34 : 1)
    }

    private func draggablePrism(source: CGPoint, target: CGRect, ballStart: CGPoint, ballEnd: CGPoint) -> some View {
        prismShape()
            .frame(width: 92, height: 78)
            .scaleEffect(0.72 + 0.28 * viewModel.prismFormation)
            .position(x: source.x + viewModel.prismOffset.width, y: source.y + viewModel.prismOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.movePrism(to: value.location, source: source)
                    }
                    .onEnded { value in
                        viewModel.finishPrism(at: value.location, target: target, source: source, ballStart: ballStart, ballEnd: ballEnd)
                    }
            )
    }

    private func prismShape() -> some View {
        ZStack {
            TriangleShape()
                .fill(Color.mathItGeometry.opacity(0.07))
                .overlay {
                    TriangleShape()
                        .stroke(Color.mathItGeometry.opacity(0.95), lineWidth: 2.4)
                }

            TriangleShape()
                .stroke(.white.opacity(0.34), lineWidth: 1.5)
                .offset(x: 22 * viewModel.prismFormation, y: -12 * viewModel.prismFormation)

            Path { path in
                path.move(to: CGPoint(x: 46, y: 0))
                path.addLine(to: CGPoint(x: 68, y: -12 * viewModel.prismFormation))
                path.move(to: CGPoint(x: 92, y: 78))
                path.addLine(to: CGPoint(x: 114, y: 66))
                path.move(to: CGPoint(x: 0, y: 78))
                path.addLine(to: CGPoint(x: 22, y: 66))
            }
            .stroke(.white.opacity(0.34), lineWidth: 1.5)
        }
        .shadow(color: Color.mathItGeometry.opacity(0.42), radius: 12)
    }

    private func expressionSlots(_ slots: [CGRect]) -> some View {
        ZStack {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.18), lineWidth: 1.2)
                    .frame(width: slot.width, height: slot.height)
                    .position(x: slot.midX, y: slot.midY)
            }
        }
    }

    private func expressionSlots(size: CGSize) -> [CGRect] {
        let y = size.height * 0.86
        let widths: [CGFloat] = [158, 40, 84, 40]
        let spacing: CGFloat = 5
        let totalWidth = widths.reduce(0, +) + spacing * CGFloat(widths.count - 1)
        var x = size.width / 2 - totalWidth / 2
        return widths.map { width in
            let height: CGFloat = width == 158 ? 122 : 56
            let rect = CGRect(x: x, y: y - height / 2, width: width, height: height)
            x += width + spacing
            return rect
        }
    }

    private func symbolView(_ text: String) -> some View {
        Text(text)
            .font(.trajan(30))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
    }

    private func symbolDrag(_ symbol: LevelNineteenSymbol, source: CGPoint, slot: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                viewModel.moveSymbol(symbol, to: value.location, source: source)
            }
            .onEnded { value in
                viewModel.finishSymbol(symbol, at: value.location, slot: slot, source: source)
            }
    }

    private func rainbowBeam(from start: CGPoint, to target: CGPoint) -> some View {
        let spectrum: [(color: Color, wavelength: CGFloat)] = [
            (Color(red: 1.00, green: 0.23, blue: 0.19), 34),
            (Color(red: 1.00, green: 0.58, blue: 0.00), 32),
            (Color(red: 1.00, green: 0.84, blue: 0.04), 30),
            (Color(red: 0.30, green: 0.85, blue: 0.39), 28),
            (Color(red: 0.00, green: 0.60, blue: 1.00), 26),
            (Color(red: 0.35, green: 0.34, blue: 0.84), 24),
            (Color(red: 0.69, green: 0.32, blue: 0.87), 22)
        ]
        return TimelineView(.animation) { context in
            let phase = CGFloat(context.date.timeIntervalSinceReferenceDate * 7)

            ZStack {
                ForEach(Array(spectrum.enumerated()), id: \.offset) { index, wave in
                    let offset = CGFloat(index - 3) * 4.6
                    sineWave(
                        from: start,
                        to: CGPoint(x: target.x, y: target.y + offset),
                        amplitude: 3.6,
                        wavelength: wave.wavelength,
                        phase: phase + CGFloat(index) * 0.28,
                        anchorsEnds: true
                    )
                    .stroke(wave.color.opacity(0.9), style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                    .shadow(color: wave.color.opacity(0.5), radius: 8)
                }
            }
        }
    }

    private func animatedLightBeam(from start: CGPoint, to end: CGPoint) -> some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9

            ZStack {
                sineWave(from: start, to: end, amplitude: 6, wavelength: 30)
                    .stroke(.white.opacity(0.88), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    .shadow(color: .white.opacity(0.5), radius: 10)

                ForEach(0..<3, id: \.self) { index in
                    let progress = CGFloat((phase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1))
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 7, height: 7)
                        .shadow(color: .white.opacity(0.8), radius: 8)
                        .position(sineWavePoint(
                            from: start,
                            to: end,
                            progress: progress,
                            amplitude: 6,
                            wavelength: 30
                        ))
                }
            }
        }
    }

    private func boxShard(offset: CGSize, rotation: Angle) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.white.opacity(0.64))
            .frame(width: 38, height: 3)
            .rotationEffect(rotation)
            .offset(offset)
    }

    private func sineWave(
        from start: CGPoint,
        to end: CGPoint,
        amplitude: CGFloat,
        wavelength: CGFloat,
        phase: CGFloat = 0,
        anchorsEnds: Bool = false
    ) -> Path {
        let distance = hypot(end.x - start.x, end.y - start.y)
        let steps = max(24, Int(distance / 2))
        var path = Path()
        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let point = sineWavePoint(
                from: start,
                to: end,
                progress: progress,
                amplitude: amplitude,
                wavelength: wavelength,
                phase: phase,
                anchorsEnds: anchorsEnds
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func sineWavePoint(
        from start: CGPoint,
        to end: CGPoint,
        progress: CGFloat,
        amplitude: CGFloat,
        wavelength: CGFloat,
        phase: CGFloat = 0,
        anchorsEnds: Bool = false
    ) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(1, hypot(dx, dy))
        let cycles = max(1, (distance / wavelength).rounded())
        let endEnvelope = anchorsEnds ? sin(.pi * progress) : 1
        let displacement = amplitude * sin(progress * cycles * 2 * .pi - phase) * endEnvelope
        let normal = CGVector(dx: -dy / distance, dy: dx / distance)

        return CGPoint(
            x: start.x + dx * progress + normal.dx * displacement,
            y: start.y + dy * progress + normal.dy * displacement
        )
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CreatorTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PrismGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let columns = 7
        let rows = 5

        for column in 0...columns {
            let x = rect.minX + rect.width * CGFloat(column) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        for row in 0...rows {
            let y = rect.minY + rect.height * CGFloat(row) / CGFloat(rows)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}
