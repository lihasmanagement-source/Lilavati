import SwiftUI

// MARK: - Level 110 - Piecewise Functions (Skatepark Transitions)
//
// A skatepark on a Cartesian plane. Each ramp/rail/platform is one piece of a
// piecewise function with its own equation and domain, drawn with open/closed
// endpoint circles. The pieces spawn at the wrong heights: drag each one
// vertically until it sits where its equation says. When every piece is
// placed, the skater rides the whole course left to right — rolling smoothly
// through continuous joins and LAUNCHING across discontinuities, so open
// circles literally become gaps you must jump.

struct MathItLevelOneHundredTenView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private struct Piece {
        let slope: Double
        let intercept: Double
        let x0: Double
        let x1: Double
        let leftClosed: Bool
        let rightClosed: Bool
        let label: String

        func value(_ x: Double) -> Double { slope * x + intercept }
        var domainText: String {
            "\(leftClosed ? "[" : "(")\(Self.num(x0)), \(Self.num(x1))\(rightClosed ? "]" : ")")"
        }
        static func num(_ v: Double) -> String {
            v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
        }
    }

    private static let stages: [[Piece]] = [
        [
            Piece(slope: 1, intercept: 4, x0: -7, x1: -3, leftClosed: true, rightClosed: true, label: "y = x + 4"),
            Piece(slope: 0, intercept: 1, x0: -3, x1: 0, leftClosed: true, rightClosed: false, label: "y = 1"),
            Piece(slope: 0, intercept: -1, x0: 0, x1: 3, leftClosed: true, rightClosed: true, label: "y = −1"),
            Piece(slope: 1, intercept: -4, x0: 3, x1: 6, leftClosed: true, rightClosed: true, label: "y = x − 4")
        ],
        [
            Piece(slope: -1, intercept: -4, x0: -7, x1: -4, leftClosed: true, rightClosed: true, label: "y = −x − 4"),
            Piece(slope: 0, intercept: 0, x0: -4, x1: -1, leftClosed: true, rightClosed: false, label: "y = 0"),
            Piece(slope: 0, intercept: 2, x0: -1, x1: 1, leftClosed: true, rightClosed: true, label: "y = 2"),
            Piece(slope: 0, intercept: 0, x0: 1, x1: 3, leftClosed: false, rightClosed: true, label: "y = 0"),
            Piece(slope: 1, intercept: -3, x0: 3, x1: 6, leftClosed: true, rightClosed: true, label: "y = x − 3")
        ],
        [
            Piece(slope: 1, intercept: 5, x0: -7, x1: -4, leftClosed: true, rightClosed: true, label: "y = x + 5"),
            Piece(slope: 0, intercept: 1, x0: -4, x1: -2, leftClosed: true, rightClosed: false, label: "y = 1"),
            Piece(slope: 0, intercept: 3, x0: -2, x1: 0, leftClosed: true, rightClosed: true, label: "y = 3"),
            Piece(slope: 0, intercept: 1, x0: 0, x1: 2, leftClosed: false, rightClosed: true, label: "y = 1"),
            Piece(slope: 0, intercept: -1, x0: 2, x1: 4, leftClosed: false, rightClosed: true, label: "y = −1"),
            Piece(slope: 1, intercept: -5, x0: 4, x1: 6, leftClosed: true, rightClosed: true, label: "y = x − 5")
        ]
    ]

    private static let startOffsets: [[Double]] = [
        [-2, 2, 3, -3],
        [2, -2, -3, 3, -2],
        [-2, 3, -3, 2, 3, -2]
    ]

    @State private var stageIndex = 0
    @State private var offsets: [Double] = []
    @State private var placed: [Bool] = []
    @State private var dragBase: (index: Int, offset: Double)?
    @State private var rideStart: Date?
    @State private var sodaStart: Date?
    @State private var completed = false

    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let accent = Color(red: 0.28, green: 0.76, blue: 1.0)
    private let pieceColors: [Color] = [
        Color(red: 0.28, green: 0.76, blue: 1.0),
        Color(red: 0.42, green: 0.85, blue: 0.60),
        Color(red: 0.98, green: 0.62, blue: 0.42),
        Color(red: 0.72, green: 0.60, blue: 0.98),
        Color(red: 0.95, green: 0.52, blue: 0.72)
    ]

    private let rideSpeed = 3.0        // graph units per second
    private var jumpDuration: Double { stageIndex == 0 ? 0.55 : 0.82 }

    private var pieces: [Piece] { Self.stages[stageIndex] }
    private var allPlaced: Bool { !placed.isEmpty && placed.allSatisfy { $0 } }

    // Graph window.
    private let xMin = -8.0, xMax = 7.0, yMin = -6.5, yMax = 6.5

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let graph = CGRect(x: 14, y: size.height * 0.20,
                               width: size.width - 28, height: size.height * 0.56)

            ZStack {
                Color.black.ignoresSafeArea()

                gridAndAxes(graph)

                TimelineView(.animation) { ctx in
                    Canvas { canvas, _ in
                        drawCourse(canvas, graph: graph)
                        drawSkater(canvas, graph: graph, now: ctx.date)
                    }
                }
                .allowsHitTesting(false)

                dragStrips(graph)

                statusLine
                    .position(x: size.width / 2, y: size.height * 0.82)

                stageDots
                    .position(x: size.width / 2, y: size.height * 0.87)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Course Landed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .onAppear { if offsets.isEmpty { loadStage(0) } }
        }
        .environment(\.mathItAccent, accent)
    }

    // MARK: - Coordinate mapping

    private func sx(_ x: Double, _ g: CGRect) -> CGFloat {
        g.minX + CGFloat((x - xMin) / (xMax - xMin)) * g.width
    }
    private func sy(_ y: Double, _ g: CGRect) -> CGFloat {
        g.maxY - CGFloat((y - yMin) / (yMax - yMin)) * g.height
    }
    private func yScale(_ g: CGRect) -> CGFloat {
        g.height / CGFloat(yMax - yMin)
    }

    // MARK: - Static drawing

    private func gridAndAxes(_ g: CGRect) -> some View {
        Canvas { ctx, _ in
            var grid = Path()
            for x in stride(from: xMin.rounded(.up), through: xMax, by: 1) {
                grid.move(to: CGPoint(x: sx(x, g), y: g.minY))
                grid.addLine(to: CGPoint(x: sx(x, g), y: g.maxY))
            }
            for y in stride(from: yMin.rounded(.up), through: yMax, by: 1) {
                grid.move(to: CGPoint(x: g.minX, y: sy(y, g)))
                grid.addLine(to: CGPoint(x: g.maxX, y: sy(y, g)))
            }
            ctx.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 1)

            var axes = Path()
            axes.move(to: CGPoint(x: g.minX, y: sy(0, g)))
            axes.addLine(to: CGPoint(x: g.maxX, y: sy(0, g)))
            axes.move(to: CGPoint(x: sx(0, g), y: g.minY))
            axes.addLine(to: CGPoint(x: sx(0, g), y: g.maxY))
            ctx.stroke(axes, with: .color(.white.opacity(0.3)), lineWidth: 1.2)

            for x in [-6.0, -3.0, 3.0, 6.0] {
                ctx.draw(Text("\(Int(x))").font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3)),
                         at: CGPoint(x: sx(x, g), y: sy(0, g) + 9))
            }
            for y in [-4.0, -2.0, 2.0, 4.0] {
                ctx.draw(Text("\(Int(y))").font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3)),
                         at: CGPoint(x: sx(0, g) - 9, y: sy(y, g)))
            }
        }
        .allowsHitTesting(false)
    }

    private func drawCourse(_ ctx: GraphicsContext, graph g: CGRect) {
        for (i, p) in pieces.enumerated() {
            let off = i < offsets.count ? offsets[i] : 0
            let isPlaced = i < placed.count && placed[i]
            let color = isPlaced ? gold : pieceColors[i % pieceColors.count]
            let a = CGPoint(x: sx(p.x0, g), y: sy(p.value(p.x0) + off, g))
            let b = CGPoint(x: sx(p.x1, g), y: sy(p.value(p.x1) + off, g))

            var line = Path()
            line.move(to: a)
            line.addLine(to: b)
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            if !isPlaced {
                ctx.stroke(line, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }

            // Endpoint circles: closed = filled, open = hollow.
            endpointCircle(ctx, at: a, closed: p.leftClosed, color: color)
            endpointCircle(ctx, at: b, closed: p.rightClosed, color: color)

            // Opaque label plate keeps the graph segment from crossing its equation.
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let placeBelow = mid.y - 34 < g.minY
            let labelY = min(max(mid.y + (placeBelow ? 32 : -32), g.minY + 19), g.maxY - 19)
            let labelWidth = min(
                max(CGFloat(max(p.label.count, p.domainText.count)) * 6.4 + 14, 58),
                max(58, g.width * 0.3)
            )
            let labelRect = CGRect(x: mid.x - labelWidth / 2, y: labelY - 17, width: labelWidth, height: 34)
            ctx.fill(Path(roundedRect: labelRect, cornerRadius: 5), with: .color(.black.opacity(0.9)))
            ctx.stroke(Path(roundedRect: labelRect, cornerRadius: 5), with: .color(color.opacity(0.42)), lineWidth: 0.8)
            ctx.draw(Text(p.label).font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(color),
                     at: CGPoint(x: mid.x, y: labelY - 6))
            ctx.draw(Text(p.domainText).font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(color.opacity(0.7)),
                     at: CGPoint(x: mid.x, y: labelY + 7))
        }
    }

    private func endpointCircle(_ ctx: GraphicsContext, at p: CGPoint, closed: Bool, color: Color) {
        let rect = CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)
        if closed {
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        } else {
            ctx.fill(Path(ellipseIn: rect), with: .color(.black))
            ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.8)
        }
    }

    // MARK: - Skater

    private enum SkateTrick: Equatable {
        case none
        case horizontal180
        case horizontal360
        case vertical360
    }

    private struct SkateState {
        let point: CGPoint
        let angle: Double
        var horizontalScale: CGFloat = 1
        var sodaProgress: Double = 0
    }

    private func drawSkater(_ ctx: GraphicsContext, graph g: CGRect, now: Date) {
        let state: SkateState
        if let start = sodaStart {
            let finalPiece = pieces[pieces.count - 1]
            state = SkateState(
                point: CGPoint(x: sx(finalPiece.x1, g), y: sy(finalPiece.value(finalPiece.x1), g)),
                angle: -atan(finalPiece.slope * Double(yScale(g)) / (sx(1, g) - sx(0, g))),
                horizontalScale: horizontalFacing(afterJumpCount: jumpCount),
                sodaProgress: min(max(now.timeIntervalSince(start) / 1.8, 0), 1)
            )
        } else if let start = rideStart {
            let elapsed = now.timeIntervalSince(start)
            guard let s = ridePosition(elapsed: elapsed, graph: g) else { return }
            state = s
        } else {
            // Waiting at the start of the course.
            let p = pieces[0]
            let off = offsets.first ?? 0
            state = SkateState(point: CGPoint(x: sx(p.x0, g), y: sy(p.value(p.x0) + off, g)), angle: 0)
        }

        var body = ctx
        body.translateBy(x: state.point.x, y: state.point.y - 14)
        body.rotate(by: .radians(state.angle))
        body.scaleBy(x: state.horizontalScale, y: 1)

        // Board with wheels.
        var board = Path()
        board.move(to: CGPoint(x: -12, y: 10))
        board.addLine(to: CGPoint(x: 12, y: 10))
        body.stroke(board, with: .color(gold), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        body.fill(Path(ellipseIn: CGRect(x: -9, y: 11.5, width: 4, height: 4)), with: .color(.white.opacity(0.8)))
        body.fill(Path(ellipseIn: CGRect(x: 5, y: 11.5, width: 4, height: 4)), with: .color(.white.opacity(0.8)))

        // Human rider in skate stance — head, leaning torso, both arms out,
        // front and back legs bent onto the board.
        let white = Color.white
        // Head.
        body.fill(Path(ellipseIn: CGRect(x: -1.5, y: -22, width: 9, height: 9)), with: .color(white))
        // Torso — leaning forward (riding right).
        var torso = Path()
        torso.move(to: CGPoint(x: 2, y: -14))
        torso.addQuadCurve(to: CGPoint(x: -2, y: -2), control: CGPoint(x: -1, y: -9))
        body.stroke(torso, with: .color(white), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        // Back arm trailing, front arm out for balance.
        var arms = Path()
        arms.move(to: CGPoint(x: 1, y: -12))
        arms.addQuadCurve(to: CGPoint(x: -10, y: -8), control: CGPoint(x: -5, y: -12))
        arms.move(to: CGPoint(x: 1, y: -12))
        arms.addQuadCurve(to: CGPoint(x: 11, y: -14), control: CGPoint(x: 6, y: -12))
        body.stroke(arms, with: .color(white.opacity(0.92)), style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
        // Legs — back leg bent, front leg extended to the nose.
        var legs = Path()
        legs.move(to: CGPoint(x: -2, y: -2))
        legs.addQuadCurve(to: CGPoint(x: -7, y: 9), control: CGPoint(x: -7, y: 2))
        legs.move(to: CGPoint(x: -2, y: -2))
        legs.addQuadCurve(to: CGPoint(x: 7, y: 9), control: CGPoint(x: 5, y: 3))
        body.stroke(legs, with: .color(white), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))

        if state.sodaProgress > 0 {
            drawSoda(in: body, progress: state.sodaProgress)
        }
    }

    private func drawSoda(in context: GraphicsContext, progress: Double) {
        var canContext = context
        let raise: Double
        if progress < 0.24 {
            raise = progress / 0.24
        } else if progress < 0.76 {
            raise = 1
        } else {
            raise = max(0, 1 - (progress - 0.76) / 0.24)
        }
        let eased = raise * raise * (3 - 2 * raise)
        let canX = 15 - CGFloat(eased) * 8
        let canY = -8 - CGFloat(eased) * 10
        canContext.translateBy(x: canX, y: canY)
        canContext.rotate(by: .radians(-0.18 - eased * 0.88))

        let canRect = CGRect(x: -3.3, y: -6.2, width: 6.6, height: 12.4)
        canContext.fill(Path(roundedRect: canRect, cornerRadius: 1.8), with: .color(Color(red: 0.92, green: 0.18, blue: 0.22)))
        canContext.fill(Path(CGRect(x: -3.3, y: -1, width: 6.6, height: 2.2)), with: .color(.white.opacity(0.9)))
        canContext.stroke(Path(ellipseIn: CGRect(x: -3.1, y: -6.7, width: 6.2, height: 1.7)), with: .color(.white.opacity(0.85)), lineWidth: 0.8)

        if progress > 0.28 && progress < 0.72 {
            let sip = sin((progress - 0.28) / 0.44 * .pi)
            for index in 0..<3 {
                let bubble = CGFloat(index) * 3.2 + CGFloat(sip) * 2
                let rect = CGRect(x: 2 + bubble * 0.2, y: -10 - bubble, width: 1.5, height: 1.5)
                canContext.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.55 - Double(index) * 0.12)))
            }
        }
    }

    /// Where the skater is `elapsed` seconds into the ride — riding pieces at
    /// constant horizontal speed, with a fixed-length parabolic arc across
    /// every discontinuity. Returns nil once the ride is over.
    private func ridePosition(elapsed: Double, graph g: CGRect) -> SkateState? {
        var t = 0.0
        var completedJumps = 0
        for i in pieces.indices {
            let p = pieces[i]
            let dur = (p.x1 - p.x0) / rideSpeed
            if elapsed < t + dur {
                let x = p.x0 + (elapsed - t) * rideSpeed
                let angle = -atan(p.slope * Double(yScale(g)) / ((sx(1, g) - sx(0, g))))
                return SkateState(
                    point: CGPoint(x: sx(x, g), y: sy(p.value(x), g)),
                    angle: angle,
                    horizontalScale: horizontalFacing(afterJumpCount: completedJumps)
                )
            }
            t += dur

            if i < pieces.count - 1 {
                let next = pieces[i + 1]
                let a = CGPoint(x: sx(p.x1, g), y: sy(p.value(p.x1), g))
                let b = CGPoint(x: sx(next.x0, g), y: sy(next.value(next.x0), g))
                let gapHere = abs(p.value(p.x1) - next.value(next.x0)) > 0.01
                if gapHere {
                    if elapsed < t + jumpDuration {
                        let s = (elapsed - t) / jumpDuration
                        let x = a.x + (b.x - a.x) * s
                        let base = a.y + (b.y - a.y) * CGFloat(s)
                        let arc = CGFloat(4 * s * (1 - s)) * yScale(g) * 1.6
                        let trick = trickForJump(completedJumps)
                        let facing = horizontalFacing(afterJumpCount: completedJumps)
                        let trickAngle: Double
                        let horizontalScale: CGFloat
                        switch trick {
                        case .horizontal180:
                            trickAngle = -sin(s * .pi) * 0.12
                            horizontalScale = facing * CGFloat(cos(s * .pi))
                        case .horizontal360:
                            trickAngle = -sin(s * .pi) * 0.12
                            horizontalScale = facing * CGFloat(cos(s * .pi * 2))
                        case .vertical360:
                            trickAngle = s * .pi * 2
                            horizontalScale = facing
                        case .none:
                            trickAngle = -sin(s * .pi) * 0.35
                            horizontalScale = facing
                        }
                        return SkateState(
                            point: CGPoint(x: x, y: base - arc),
                            angle: trickAngle,
                            horizontalScale: horizontalScale
                        )
                    }
                    t += jumpDuration
                    completedJumps += 1
                }
            }
        }
        return nil
    }

    private var jumpCount: Int {
        pieces.indices.dropLast().reduce(into: 0) { count, index in
            let current = pieces[index]
            let next = pieces[index + 1]
            if abs(current.value(current.x1) - next.value(next.x0)) > 0.01 {
                count += 1
            }
        }
    }

    private func trickForJump(_ jumpIndex: Int) -> SkateTrick {
        switch stageIndex {
        case 1:
            return jumpIndex == 0 ? .horizontal180 : .vertical360
        case 2:
            switch jumpIndex {
            case 0: return .horizontal360
            case 1: return .vertical360
            default: return .horizontal180
            }
        default:
            return .none
        }
    }

    private func horizontalFacing(afterJumpCount count: Int) -> CGFloat {
        var facing: CGFloat = 1
        guard count > 0 else { return facing }
        for jump in 0..<count {
            if trickForJump(jump) == .horizontal180 {
                facing *= -1
            }
        }
        return facing
    }

    private var totalRideTime: Double {
        var t = 0.0
        for i in pieces.indices {
            t += (pieces[i].x1 - pieces[i].x0) / rideSpeed
            if i < pieces.count - 1,
               abs(pieces[i].value(pieces[i].x1) - pieces[i + 1].value(pieces[i + 1].x0)) > 0.01 {
                t += jumpDuration
            }
        }
        return t
    }

    // MARK: - Interaction

    private func dragStrips(_ g: CGRect) -> some View {
        ForEach(pieces.indices, id: \.self) { i in
            let p = pieces[i]
            let x0 = sx(p.x0, g), x1 = sx(p.x1, g)
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: max(x1 - x0, 30), height: g.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            guard rideStart == nil, sodaStart == nil, !completed,
                                  i < placed.count, !placed[i] else { return }
                            if dragBase?.index != i {
                                dragBase = (i, offsets[i])
                            }
                            guard let base = dragBase else { return }
                            offsets[i] = base.offset - Double(value.translation.height / yScale(g))
                        }
                        .onEnded { _ in
                            dragBase = nil
                            guard rideStart == nil, i < placed.count, !placed[i] else { return }
                            snapPiece(i)
                        }
                )
                .allowsHitTesting(rideStart == nil && sodaStart == nil && !completed)
                .position(x: (x0 + x1) / 2, y: g.midY)
        }
    }

    private func snapPiece(_ i: Int) {
        let snapped = (offsets[i] * 2).rounded() / 2
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offsets[i] = snapped
        }
        if abs(snapped) < 0.01 {
            offsets[i] = 0
            placed[i] = true
            HapticPlayer.playLightTap()
            if allPlaced { beginRide() }
        } else {
            HapticPlayer.playLightTap()
        }
    }

    private func beginRide() {
        HapticPlayer.playCompletionTap()
        let total = totalRideTime
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            rideStart = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.2) {
                if stageIndex == Self.stages.count - 1 {
                    rideStart = nil
                    sodaStart = Date()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                        finishRide()
                    }
                } else {
                    finishRide()
                }
            }
        }
    }

    private func finishRide() {
        rideStart = nil
        sodaStart = nil
        if stageIndex < Self.stages.count - 1 {
            HapticPlayer.playCompletionTap()
            withAnimation(.easeInOut(duration: 0.35)) {
                loadStage(stageIndex + 1)
            }
        } else {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                completed = true
            }
        }
    }

    private func loadStage(_ index: Int) {
        stageIndex = index
        sodaStart = nil
        offsets = Self.startOffsets[index]
        placed = Array(repeating: false, count: Self.stages[index].count)
    }

    private func reset() {
        completed = false
        rideStart = nil
        sodaStart = nil
        loadStage(0)
    }

    // MARK: - Status

    private var statusLine: some View {
        Text(sodaStart != nil
             ? "Refresh!"
             : (rideStart != nil
                ? "Ride!"
                : (allPlaced ? "Course complete" : "Drag each piece to the height its equation demands")))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(rideStart != nil ? gold : .white.opacity(0.42))
    }

    private var stageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.stages.count, id: \.self) { i in
                Circle()
                    .fill(i <= stageIndex ? gold : Color.white.opacity(0.2))
                    .frame(width: 7, height: 7)
            }
        }
    }
}

#Preview {
    MathItLevelOneHundredTenView(onContinue: {}, onLevelSelect: {})
}
