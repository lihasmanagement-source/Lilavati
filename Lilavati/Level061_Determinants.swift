import SwiftUI

struct MathItLevelOneHundredTwentyTwoView: View {
    private let stages = PixelDeterminantStage.all
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.31, blue: 0.25)
    private let ink = Color(red: 0.025, green: 0.034, blue: 0.044)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var matrix = PixelDeterminantStage.all[0].start
    @State private var redistributing = false
    @State private var redistributionProgress = 0.0
    @State private var showMismatch = false
    @State private var completed = false
    @State private var animationToken = UUID()

    private var stage: PixelDeterminantStage { stages[stageIndex] }
    private var determinant: Double { matrix.determinant }
    private var magnitude: Double { abs(determinant) }
    private var isMatched: Bool {
        matrix.distance(to: stage.target) < 0.18 &&
        abs(determinant - stage.target.determinant) < 0.14 &&
        (0.45...2.4).contains(magnitude)
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                ink.ignoresSafeArea()

                VStack(spacing: compact ? 8 : 12) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    transformationBoard
                        .frame(maxWidth: 820)
                        .frame(height: max(390, min(525, proxy.size.height * 0.62)))

                    determinantControls(compact: compact)
                        .frame(maxWidth: 720)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Pixel Matrix Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear { loadStage() }
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

            Text(stage.name.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(gold)

            HStack(spacing: 8) {
                Image(systemName: "viewfinder")
                Text("MATCH TARGET")
                Text("det = \(formatted(stage.target.determinant))")
            }
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundStyle(isMatched ? cyan : .white)
        }
    }

    private var transformationBoard: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 28, geo.size.height - 28)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + 8)
            let scale = side * 0.265

            ZStack {
                Canvas { context, size in
                    drawBoardBackground(context: &context, size: size, center: center, scale: scale)
                    drawPixelImage(context: &context, matrix: stage.target, center: center, scale: scale, target: true)
                    drawFrame(context: &context, matrix: stage.target, center: center, scale: scale, color: .white.opacity(0.42), dashed: true)
                    drawPixelImage(context: &context, matrix: matrix, center: center, scale: scale, target: false)
                    drawFrame(context: &context, matrix: matrix, center: center, scale: scale, color: qualityColor.opacity(0.88), dashed: false)
                    drawBasis(context: &context, center: center, scale: scale)
                }

                matrixHandle(
                    label: "u",
                    color: cyan,
                    position: transformedPoint(x: 1, y: 0, matrix: matrix, center: center, scale: scale)
                ) { location in
                    updateFirstColumn(at: location, center: center, scale: scale)
                }

                matrixHandle(
                    label: "v",
                    color: gold,
                    position: transformedPoint(x: 0, y: 1, matrix: matrix, center: center, scale: scale)
                ) { location in
                    updateSecondColumn(at: location, center: center, scale: scale)
                }

                VStack {
                    HStack {
                        Image(systemName: stage.symbol)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(stage.primary)
                        Spacer()
                        Text("TARGET")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                }
                .padding(13)
            }
            .coordinateSpace(name: "pixelMatrixBoard")
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12)))
        }
    }

    private func matrixHandle(
        label: String,
        color: Color,
        position: CGPoint,
        update: @escaping (CGPoint) -> Void
    ) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 34, height: 34)
            Text(label)
                .font(.system(size: 15, weight: .black, design: .serif))
                .foregroundStyle(ink)
        }
        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
        .shadow(color: color.opacity(0.7), radius: 10)
        .contentShape(Circle().inset(by: -18))
        .position(position)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("pixelMatrixBoard"))
                .onChanged { value in
                    guard !redistributing else { return }
                    update(value.location)
                    showMismatch = false
                }
        )
        .accessibilityLabel("Matrix handle \(label)")
    }

    private func determinantControls(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 11) {
            HStack(alignment: .center, spacing: 12) {
                matrixReadout
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DETERMINANT")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(formatted(determinant))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(qualityColor)
                }
            }

            determinantMeter
                .frame(height: 36)

            Button(action: redistributePixels) {
                HStack(spacing: 9) {
                    Image(systemName: redistributing ? "square.grid.3x3.fill" : isMatched ? "wand.and.stars" : "viewfinder")
                    Text(redistributing ? "REDISTRIBUTING PIXELS" : isMatched ? "REDISTRIBUTE PIXELS" : "ALIGN WITH TARGET")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                }
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isMatched ? cyan : showMismatch ? coral : .white.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(redistributing)
        }
        .padding(compact ? 10 : 13)
        .background(Color(red: 0.05, green: 0.06, blue: 0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1)))
    }

    private var matrixReadout: some View {
        HStack(spacing: 5) {
            Text("[")
            VStack(spacing: 2) {
                HStack(spacing: 10) {
                    Text(formatted(matrix.a))
                    Text(formatted(matrix.b))
                }
                HStack(spacing: 10) {
                    Text(formatted(matrix.c))
                    Text(formatted(matrix.d))
                }
            }
            Text("]")
        }
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .foregroundStyle(.white.opacity(0.84))
        .frame(minWidth: 132, alignment: .leading)
    }

    private var determinantMeter: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let position = min(1, magnitude / 3.0) * width
            let targetPosition = min(1, abs(stage.target.determinant) / 3.0) * width

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    coral.opacity(0.82).frame(width: width * 0.15)
                    cyan.opacity(0.72).frame(width: width * 0.65)
                    coral.opacity(0.82).frame(width: width * 0.20)
                }
                .frame(height: 8)
                .clipShape(Capsule())

                Rectangle()
                    .fill(.white.opacity(0.72))
                    .frame(width: 2, height: 18)
                    .position(x: targetPosition, y: geo.size.height / 2)

                VStack(spacing: 1) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 9, weight: .black))
                    Circle().frame(width: 7, height: 7)
                }
                .foregroundStyle(qualityColor)
                .position(x: position, y: geo.size.height / 2 - 1)
            }
        }
        .accessibilityLabel("Determinant magnitude \(formatted(magnitude))")
    }

    private var qualityColor: Color {
        magnitude < 0.45 || magnitude > 2.4 ? coral : cyan
    }

    private func drawBoardBackground(context: inout GraphicsContext, size: CGSize, center: CGPoint, scale: CGFloat) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.055, green: 0.075, blue: 0.095)))

        let spacing = scale / 4
        for index in -8...8 {
            var vertical = Path()
            vertical.move(to: CGPoint(x: center.x + CGFloat(index) * spacing, y: 0))
            vertical.addLine(to: CGPoint(x: center.x + CGFloat(index) * spacing, y: size.height))
            context.stroke(vertical, with: .color(.white.opacity(index == 0 ? 0.12 : 0.035)), lineWidth: 1)

            var horizontal = Path()
            horizontal.move(to: CGPoint(x: 0, y: center.y + CGFloat(index) * spacing))
            horizontal.addLine(to: CGPoint(x: size.width, y: center.y + CGFloat(index) * spacing))
            context.stroke(horizontal, with: .color(.white.opacity(index == 0 ? 0.12 : 0.035)), lineWidth: 1)
        }
    }

    private func drawBasis(context: inout GraphicsContext, center: CGPoint, scale: CGFloat) {
        let u = transformedPoint(x: 1, y: 0, matrix: matrix, center: center, scale: scale)
        let v = transformedPoint(x: 0, y: 1, matrix: matrix, center: center, scale: scale)
        drawArrow(context: &context, from: center, to: u, color: cyan)
        drawArrow(context: &context, from: center, to: v, color: gold)
        context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(.white))
    }

    private func drawArrow(context: inout GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color.opacity(0.82)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    private func drawFrame(
        context: inout GraphicsContext,
        matrix: PixelMatrix,
        center: CGPoint,
        scale: CGFloat,
        color: Color,
        dashed: Bool
    ) {
        var frame = Path()
        let corners = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]
        for (index, corner) in corners.enumerated() {
            let point = transformedPoint(x: corner.0, y: corner.1, matrix: matrix, center: center, scale: scale)
            if index == 0 { frame.move(to: point) } else { frame.addLine(to: point) }
        }
        frame.closeSubpath()
        context.stroke(
            frame,
            with: .color(color),
            style: StrokeStyle(lineWidth: dashed ? 2 : 2.5, lineCap: .round, lineJoin: .round, dash: dashed ? [6, 5] : [])
        )
    }

    private func drawPixelImage(
        context: inout GraphicsContext,
        matrix: PixelMatrix,
        center: CGPoint,
        scale: CGFloat,
        target: Bool
    ) {
        let pixels = stage.pixels
        let danger = magnitude < 0.45 || magnitude > 2.4
        let gap = target ? 0.16 : max(0.035, 0.13 * (1 - redistributionProgress))

        for (index, pixel) in pixels.enumerated() {
            if !target && magnitude < 0.22 && index.isMultiple(of: 3) { continue }

            let inset = pixel.size * gap
            let left = pixel.x + inset
            let right = pixel.x + pixel.size - inset
            let bottom = pixel.y + inset
            let top = pixel.y + pixel.size - inset
            var path = Path()
            path.move(to: transformedPoint(x: left, y: bottom, matrix: matrix, center: center, scale: scale))
            path.addLine(to: transformedPoint(x: right, y: bottom, matrix: matrix, center: center, scale: scale))
            path.addLine(to: transformedPoint(x: right, y: top, matrix: matrix, center: center, scale: scale))
            path.addLine(to: transformedPoint(x: left, y: top, matrix: matrix, center: center, scale: scale))
            path.closeSubpath()

            let color = pixel.accent ? stage.accent : stage.primary
            let distortionOpacity = danger && !target && index.isMultiple(of: 4) ? 0.35 : 1.0
            context.fill(path, with: .color(color.opacity(target ? 0.10 : distortionOpacity)))
        }
    }

    private func transformedPoint(
        x: Double,
        y: Double,
        matrix: PixelMatrix,
        center: CGPoint,
        scale: CGFloat
    ) -> CGPoint {
        let transformedX = matrix.a * x + matrix.b * y
        let transformedY = matrix.c * x + matrix.d * y
        return CGPoint(
            x: center.x + CGFloat(transformedX) * scale,
            y: center.y - CGFloat(transformedY) * scale
        )
    }

    private func vector(at point: CGPoint, center: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: min(1.55, max(-1.55, (point.x - center.x) / scale)),
            y: min(1.55, max(-1.55, (center.y - point.y) / scale))
        )
    }

    private func updateFirstColumn(at point: CGPoint, center: CGPoint, scale: CGFloat) {
        let value = vector(at: point, center: center, scale: scale)
        matrix.a = Double(value.x)
        matrix.c = Double(value.y)
    }

    private func updateSecondColumn(at point: CGPoint, center: CGPoint, scale: CGFloat) {
        let value = vector(at: point, center: center, scale: scale)
        matrix.b = Double(value.x)
        matrix.d = Double(value.y)
    }

    private func redistributePixels() {
        guard !redistributing else { return }
        guard isMatched else {
            showMismatch = true
            HapticPlayer.playLightTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { showMismatch = false }
            return
        }

        let token = UUID()
        animationToken = token
        redistributing = true
        HapticPlayer.playCompletionTap()
        withAnimation(.easeInOut(duration: 0.75)) {
            matrix = stage.target
            redistributionProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            guard animationToken == token else { return }
            advanceStage()
        }
    }

    private func advanceStage() {
        if stageIndex == stages.count - 1 {
            completed = true
            redistributing = false
        } else {
            stageIndex += 1
            loadStage()
        }
    }

    private func loadStage() {
        animationToken = UUID()
        matrix = stage.start
        redistributing = false
        redistributionProgress = 0
        showMismatch = false
    }

    private func resetLevel() {
        completed = false
        stageIndex = 0
        loadStage()
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct PixelMatrix: Equatable {
    var a: Double
    var b: Double
    var c: Double
    var d: Double

    var determinant: Double { a * d - b * c }

    func distance(to other: PixelMatrix) -> Double {
        max(abs(a - other.a), abs(b - other.b), abs(c - other.c), abs(d - other.d))
    }
}

private struct PixelCell {
    let x: Double
    let y: Double
    let size: Double
    let accent: Bool
}

private struct PixelDeterminantStage {
    let name: String
    let symbol: String
    let rows: [String]
    let primary: Color
    let accent: Color
    let target: PixelMatrix
    let start: PixelMatrix

    var pixels: [PixelCell] {
        let size = 2.0 / Double(rows.count)
        return rows.enumerated().flatMap { row, line in
            Array(line).enumerated().compactMap { column, character in
                guard character != "." else { return nil }
                return PixelCell(
                    x: -1 + Double(column) * size,
                    y: 1 - Double(row + 1) * size,
                    size: size,
                    accent: character == "+"
                )
            }
        }
    }

    static let all: [PixelDeterminantStage] = [
        .init(
            name: "Image 1 · Smiley Rotation",
            symbol: "face.smiling.fill",
            rows: [
                "..#####..", ".#.....#.", "#.......#", "#.#...#.#", "#.......#",
                "#..###..#", "#...#...#", ".#.....#.", "..#####.."
            ],
            primary: Color(red: 1.0, green: 0.77, blue: 0.18),
            accent: .white,
            target: .init(a: 0.91, b: -0.42, c: 0.42, d: 0.91),
            start: .init(a: 1.0, b: 0.0, c: 0.0, d: 1.0)
        ),
        .init(
            name: "Image 2 · Tree Skew",
            symbol: "tree.fill",
            rows: [
                "....#....", "...###...", "..#####..", ".#######.", "...###...",
                "..#####..", ".#######.", "....+....", "...+++..."
            ],
            primary: Color(red: 0.22, green: 0.82, blue: 0.47),
            accent: Color(red: 0.78, green: 0.47, blue: 0.20),
            target: .init(a: 1.15, b: 0.28, c: 0.10, d: 0.78),
            start: .init(a: 0.78, b: -0.18, c: 0.08, d: 1.08)
        ),
        .init(
            name: "Image 3 · Cat Stretch",
            symbol: "cat.fill",
            rows: [
                ".##...##.", "#########", "#..#.#..#", "#.......#", "#.#...#.#",
                "#..###..#", ".#.....#.", "..#####..", "........."
            ],
            primary: Color(red: 0.66, green: 0.55, blue: 1.0),
            accent: .white,
            target: .init(a: 0.72, b: -0.35, c: 0.22, d: 1.18),
            start: .init(a: 1.12, b: 0.16, c: -0.12, d: 0.70)
        )
    ]
}

#Preview {
    MathItLevelOneHundredTwentyTwoView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 122) ?? 122)
}
