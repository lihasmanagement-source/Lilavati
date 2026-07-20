import Combine
import SwiftUI

// MARK: - Level 14 - Linear Functions
//
// A mountain range drawn on a coordinate plane. The ridge is a chain of
// straight-line segments — sharp peaks and valleys, like a line graph. Each
// face of the mountain is a linear function over its stretch of x. Equation
// tiles lie scattered in the snow at the bottom; drag each one onto the dotted
// slot on its matching face. Match them all and the blue climber snowboards
// down the ridge to the pink climber.

final class MathItLevelFourteenViewModel: ObservableObject {
    struct Face: Identifiable {
        let id: Int
        let a: CGPoint
        let b: CGPoint

        var slope: Double { (b.y - a.y) / (b.x - a.x) }
        var intercept: Double { a.y - slope * a.x }
        var midpoint: CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }

        var equation: String {
            let m = Int(slope.rounded())
            let bVal = Int(intercept.rounded())
            var text = "y = "
            switch m {
            case 1: text += "x"
            case -1: text += "−x"
            default: text += m < 0 ? "−\(abs(m))x" : "\(m)x"
            }
            if bVal != 0 {
                text += bVal < 0 ? " − \(abs(bVal))" : " + \(bVal)"
            }
            return text
        }

        var interval: String {
            "(\(intText(a.x)) ≤ x ≤ \(intText(b.x)))"
        }

        private func intText(_ v: Double) -> String {
            let i = Int(v.rounded())
            return i < 0 ? "−\(abs(i))" : "\(i)"
        }
    }

    /// Ridge vertices in graph coordinates, left to right — chosen so every
    /// face has an integer slope and intercept.
    let ridge: [CGPoint] = [
        CGPoint(x: -8, y: -4),
        CGPoint(x: -5, y: 2),    // y = 2x + 12
        CGPoint(x: -3, y: -2),   // y = −2x − 8
        CGPoint(x: 0, y: 4),     // y = 2x + 4
        CGPoint(x: 2, y: 0),     // y = −2x + 4
        CGPoint(x: 4, y: 6),     // y = 3x − 6
        CGPoint(x: 8, y: -2)     // y = −2x + 14
    ]

    var faces: [Face] {
        (0..<(ridge.count - 1)).map { Face(id: $0, a: ridge[$0], b: ridge[$0 + 1]) }
    }

    /// Order the tiles appear in the snow (shuffled once, stable).
    let tileOrder: [Int] = [3, 0, 5, 1, 4, 2]

    @Published var locked: Set<Int> = []
    @Published var riding = false
    @Published var riderPosition: CGPoint = CGPoint(x: -8, y: -4)
    @Published var riderAngle: Double = 0
    @Published var hopOffset: CGFloat = 0
    @Published var completed = false

    var allMatched: Bool { locked.count == faces.count }

    func lock(_ faceID: Int) {
        guard !locked.contains(faceID) else { return }
        locked.insert(faceID)
        HapticPlayer.playLightTap()
        if allMatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                self.startRide()
            }
        }
    }

    func startRide() {
        guard !riding, !completed else { return }
        riding = true
        riderPosition = ridge[0]
        HapticPlayer.playCompletionTap()

        var delay = 0.15
        for index in 1..<ridge.count {
            let a = ridge[index - 1]
            let b = ridge[index]
            let length = hypot(b.x - a.x, b.y - a.y)
            let duration = 0.16 + length * 0.055
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.riderAngle = -atan2(Double(b.y - a.y), Double(b.x - a.x)) * 180 / .pi
                withAnimation(.linear(duration: duration)) {
                    self.riderPosition = b
                }
            }
            delay += duration
        }
        // Land flat next to the pink climber, then both hop three times.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15) {
            withAnimation(.easeOut(duration: 0.2)) { self.riderAngle = 0 }
            var hopDelay = 0.2
            for _ in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + hopDelay) {
                    withAnimation(.easeOut(duration: 0.16)) { self.hopOffset = 9 }
                    HapticPlayer.playLightTap()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + hopDelay + 0.16) {
                    withAnimation(.easeIn(duration: 0.15)) { self.hopOffset = 0 }
                }
                hopDelay += 0.34
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + hopDelay + 0.35) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    self.completed = true
                }
            }
        }
    }

    func reset() {
        locked = []
        riding = false
        riderPosition = ridge[0]
        riderAngle = 0
        hopOffset = 0
        completed = false
    }
}

struct MathItLevelFourteenView: View {
    @ObservedObject var viewModel: MathItLevelFourteenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    @State private var dragOffsets: [Int: CGSize] = [:]
    @State private var activeDragID: Int?
    @State private var climbersSwapped = false

    private let accent = Color(red: 0.28, green: 0.76, blue: 1.0)
    private let gold = Color(red: 0.93, green: 0.78, blue: 0.40)
    private let pink = Color(red: 1.0, green: 0.45, blue: 0.75)

    private let tileSize = CGSize(width: 70, height: 24)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.black.ignoresSafeArea()

                mountainGraph(size: size)
                    .position(x: size.width / 2, y: size.height * 0.52)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Range Charted",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .environment(\.mathItAccent, accent)
        }
    }

    // MARK: - Scene

    private func mountainGraph(size: CGSize) -> some View {
        let width = min(size.width - 24, 430)
        let height = min(size.height * 0.72, 560)
        let scale = min(width, height * 0.78) / 22
        let origin = CGPoint(x: width / 2, y: height * 0.40)
        let slots = slotPlacements(origin: origin, scale: scale)
        let homes = tileHomes(width: width, height: height)

        return ZStack {
            GraphGrid(origin: origin, scale: scale)
                .stroke(.white.opacity(0.07), lineWidth: 1)

            GraphAxes(origin: origin, scale: scale)
                .stroke(.white.opacity(0.38), lineWidth: 1.3)

            axisTicks(origin: origin, scale: scale)

            mountainFill(origin: origin, scale: scale, height: height)

            ridgePath(origin: origin, scale: scale)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.85), .white, accent.opacity(0.85)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .miter)
                )
                .shadow(color: accent.opacity(0.5), radius: 9)

            snowCaps(origin: origin, scale: scale)
            vertexDots(origin: origin, scale: scale)
            vertexCoordinates(origin: origin, scale: scale)

            // Dotted slots on the underside of each face.
            ForEach(viewModel.faces) { face in
                slotView(face, placement: slots[face.id])
            }

            Snowfall(width: width, height: height)
                .allowsHitTesting(false)

            // Climbers. Pink waits a step past the end of the ridge so the
            // snowboarder lands beside her, not on top of her. Tapping either
            // one swaps their colors.
            if !viewModel.riding && !viewModel.completed {
                climber(at: viewModel.ridge[0], symbol: "figure.walk", color: climbersSwapped ? pink : accent, origin: origin, scale: scale, tappable: true)
            }
            climber(at: viewModel.ridge[viewModel.ridge.count - 1], symbol: "figure.walk", color: climbersSwapped ? accent : pink, origin: origin, scale: scale, xNudge: 26, hop: viewModel.hopOffset, tappable: true)

            if viewModel.riding || viewModel.completed {
                snowboarder(origin: origin, scale: scale)
            }

            // Equation tiles scattered in the snow.
            ForEach(Array(viewModel.tileOrder.enumerated()), id: \.element) { orderIndex, faceID in
                tileView(
                    faceID: faceID,
                    home: homes[orderIndex],
                    rotation: tileRotations[orderIndex],
                    slots: slots
                )
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Slots & tiles

    /// Slot centre + screen-angle + width for each face: hugging the underside
    /// of the slope (almost touching it). Every equation anchors toward the
    /// RIGHT end of its face — the peak for inclines, the valley for declines —
    /// so the two texts meeting at any vertex are always one near, one far,
    /// and can never crowd the same point.
    private func slotPlacements(origin: CGPoint, scale: CGFloat) -> [(point: CGPoint, angle: Double, width: CGFloat)] {
        viewModel.faces.map { face in
            let a = screenPoint(face.a, origin: origin, scale: scale)
            let b = screenPoint(face.b, origin: origin, scale: scale)
            let angle = atan2(b.y - a.y, b.x - a.x)
            let length = hypot(b.x - a.x, b.y - a.y)

            // Shrink the text on short faces so it always fits with margin.
            let width = min(tileSize.width, length - 26)

            // Clearance from the right vertex, measured along the slope,
            // clamped so short faces fall back to their midpoint. The two
            // inclines ending at the first two peaks (faces 0 and 2) slide
            // further down their slopes to stay clear of the equations on the
            // short declines just past those peaks.
            let extraClearance: CGFloat = (face.id == 0 || face.id == 2) ? 26 : 0
            let clearance: CGFloat = 16 + extraClearance
            let along = min(clearance + width / 2, length - width / 2 - 8)
            let dirX = (a.x - b.x) / length
            let dirY = (a.y - b.y) / length

            // Unit normal pointing downward on screen (below the line).
            var nx = -sin(angle)
            var ny = cos(angle)
            if ny < 0 { nx = -nx; ny = -ny }
            // Text frame is 24 tall → half is 12; 14 keeps the top edge a
            // hair's breadth under the line.
            let inset: CGFloat = 14

            return (
                CGPoint(
                    x: b.x + dirX * along + nx * inset,
                    y: b.y + dirY * along + ny * inset
                ),
                Double(angle * 180 / CGFloat.pi),
                width
            )
        }
    }

    private var tileRotations: [Double] { [-4, 3, -2, 4, -3, 2] }

    private func tileHomes(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let xs: [CGFloat] = [0.17, 0.50, 0.83]
        let jitter: [CGFloat] = [3, -4, 2, -2, 4, -3]
        return (0..<6).map { i in
            CGPoint(
                x: width * xs[i % 3] + jitter[i],
                y: height * (i < 3 ? 0.855 : 0.955) + jitter[(i + 2) % 6] * 0.4
            )
        }
    }

    private func slotView(_ face: MathItLevelFourteenViewModel.Face, placement: (point: CGPoint, angle: Double, width: CGFloat)) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .stroke(
                viewModel.locked.contains(face.id) ? gold.opacity(0.0) : .white.opacity(0.42),
                style: StrokeStyle(lineWidth: 1.3, dash: [5, 4])
            )
            .frame(width: placement.width, height: tileSize.height)
            .rotationEffect(.degrees(placement.angle))
            .position(placement.point)
            .allowsHitTesting(false)
    }

    private func tileView(faceID: Int, home: CGPoint, rotation: Double, slots: [(point: CGPoint, angle: Double, width: CGFloat)]) -> some View {
        let face = viewModel.faces[faceID]
        let isLocked = viewModel.locked.contains(faceID)
        let offset = dragOffsets[faceID] ?? .zero
        let position = isLocked
            ? slots[faceID].point
            : CGPoint(x: home.x + offset.width, y: home.y + offset.height)

        return VStack(spacing: 0) {
            Text(face.equation)
                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(isLocked ? gold : .white)
            Text(face.interval)
                .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                .foregroundStyle(isLocked ? gold.opacity(0.65) : .white.opacity(0.55))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: slots[faceID].width, height: tileSize.height)
        .contentShape(Rectangle().inset(by: -8))
        .shadow(color: .black.opacity(0.8), radius: 3)
        .rotationEffect(.degrees(isLocked ? slots[faceID].angle : rotation))
        .position(position)
        .zIndex(activeDragID == faceID ? 60 : (isLocked ? 10 : 30))
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isLocked)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !isLocked, !viewModel.riding, !viewModel.completed else { return }
                    activeDragID = faceID
                    dragOffsets[faceID] = value.translation
                }
                .onEnded { value in
                    activeDragID = nil
                    guard !isLocked, !viewModel.riding, !viewModel.completed else { return }
                    let dropped = CGPoint(x: home.x + value.translation.width, y: home.y + value.translation.height)
                    if hypot(dropped.x - slots[faceID].point.x, dropped.y - slots[faceID].point.y) < 40 {
                        dragOffsets[faceID] = .zero
                        viewModel.lock(faceID)
                    } else {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                            dragOffsets[faceID] = .zero
                        }
                        HapticPlayer.playLightTap()
                    }
                }
        )
    }

    // MARK: - Ridge drawing

    private func ridgePath(origin: CGPoint, scale: CGFloat) -> Path {
        Path { path in
            let points = viewModel.ridge.map { screenPoint($0, origin: origin, scale: scale) }
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func mountainFill(origin: CGPoint, scale: CGFloat, height: CGFloat) -> some View {
        Path { path in
            let points = viewModel.ridge.map { screenPoint($0, origin: origin, scale: scale) }
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            path.addLine(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [accent.opacity(0.20), accent.opacity(0.02)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // Short white strokes along the two faces meeting at each peak.
    private func snowCaps(origin: CGPoint, scale: CGFloat) -> some View {
        Path { path in
            let ridge = viewModel.ridge
            for index in ridge.indices where isLocalPeak(index) {
                let peak = screenPoint(ridge[index], origin: origin, scale: scale)
                let left = screenPoint(ridge[index - 1], origin: origin, scale: scale)
                let right = screenPoint(ridge[index + 1], origin: origin, scale: scale)
                path.move(to: lerp(peak, left, 0.30))
                path.addLine(to: peak)
                path.addLine(to: lerp(peak, right, 0.30))
            }
        }
        .stroke(
            Color.white.opacity(0.95),
            style: StrokeStyle(lineWidth: 4.6, lineCap: .round, lineJoin: .miter)
        )
        .shadow(color: .white.opacity(0.35), radius: 5)
    }

    private func vertexDots(origin: CGPoint, scale: CGFloat) -> some View {
        ZStack {
            ForEach(viewModel.ridge.indices, id: \.self) { index in
                let isPeak = isLocalPeak(index)
                Circle()
                    .fill(isPeak ? gold : Color.white.opacity(0.85))
                    .frame(width: isPeak ? 7 : 5, height: isPeak ? 7 : 5)
                    .shadow(color: (isPeak ? gold : .white).opacity(0.6), radius: 4)
                    .position(screenPoint(viewModel.ridge[index], origin: origin, scale: scale))
            }
        }
    }

    // Coordinate labels at every ridge vertex — above peaks, below valleys,
    // beside the start and end points.
    private func vertexCoordinates(origin: CGPoint, scale: CGFloat) -> some View {
        ZStack {
            ForEach(viewModel.ridge.indices, id: \.self) { index in
                let point = viewModel.ridge[index]
                let isPeak = isLocalPeak(index)
                let isEndpoint = index == 0 || index == viewModel.ridge.count - 1
                let screen = screenPoint(point, origin: origin, scale: scale)
                Text("(\(coordText(point.x)), \(coordText(point.y)))")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isPeak ? gold.opacity(0.9) : .white.opacity(0.6))
                    .position(
                        x: screen.x + (index == 0 ? -6 : (index == viewModel.ridge.count - 1 ? 6 : 0)),
                        y: screen.y + (isPeak ? -17 : (isEndpoint ? 16 : 15))
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func coordText(_ v: CGFloat) -> String {
        let i = Int(v.rounded())
        return i < 0 ? "−\(abs(i))" : "\(i)"
    }

    private func axisTicks(origin: CGPoint, scale: CGFloat) -> some View {
        ZStack {
            ForEach([-8, -4, 4, 8], id: \.self) { i in
                Text("\(i)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .position(x: origin.x + CGFloat(i) * scale, y: origin.y + 11)
                Text("\(i)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .position(x: origin.x - 11, y: origin.y - CGFloat(i) * scale)
            }
        }
    }

    // MARK: - Climbers & snowboarder

    private func climber(at point: CGPoint, symbol: String, color: Color, origin: CGPoint, scale: CGFloat, xNudge: CGFloat = 0, hop: CGFloat = 0, tappable: Bool = false) -> some View {
        let screen = screenPoint(point, origin: origin, scale: scale)
        return Image(systemName: symbol)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.65), radius: 7)
            .contentShape(Circle().inset(by: -12))
            .onTapGesture {
                guard tappable else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    climbersSwapped.toggle()
                }
                HapticPlayer.playLightTap()
            }
            .position(x: screen.x + xNudge, y: screen.y - 15 - hop)
    }

    private func snowboarder(origin: CGPoint, scale: CGFloat) -> some View {
        let screen = screenPoint(viewModel.riderPosition, origin: origin, scale: scale)
        return ZStack {
            Capsule()
                .fill(gold)
                .frame(width: 26, height: 4)
                .offset(y: 11)
            Image(systemName: "figure.snowboarding")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(climbersSwapped ? pink : accent)
                .shadow(color: (climbersSwapped ? pink : accent).opacity(0.7), radius: 8)
        }
        .rotationEffect(.degrees(viewModel.riderAngle * 0.5))
        .position(x: screen.x, y: screen.y - 13 - viewModel.hopOffset)
    }

    // MARK: - Helpers

    private func isLocalPeak(_ index: Int) -> Bool {
        let ridge = viewModel.ridge
        guard index > 0, index < ridge.count - 1 else { return false }
        return ridge[index].y > ridge[index - 1].y && ridge[index].y > ridge[index + 1].y
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ f: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    private func screenPoint(_ point: CGPoint, origin: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + point.x * scale, y: origin.y - point.y * scale)
    }
}

// MARK: - Snowfall

private struct Snowfall: View {
    let width: CGFloat
    let height: CGFloat

    private let flakeCount = 60

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for i in 0..<flakeCount {
                    let seed = Double(i)
                    let speed = 14.0 + fract(seed * 0.731) * 22.0
                    let baseX = fract(seed * 0.377) * size.width
                    let phase = fract(seed * 0.911) * size.height
                    let sway = 6.0 + fract(seed * 0.547) * 8.0
                    let r = 1.0 + fract(seed * 0.269) * 1.6

                    let y = (phase + t * speed).truncatingRemainder(dividingBy: size.height + 12) - 6
                    let x = baseX + sin(t * 0.8 + seed) * sway
                    let fade = min(1, y / 30) * min(1, (size.height - y) / 40)
                    guard fade > 0 else { continue }

                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.22 + 0.5 * fract(seed * 0.173) * Double(fade)))
                    )
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func fract(_ v: Double) -> Double {
        v - v.rounded(.down)
    }
}

// MARK: - Grid & axes

private struct GraphGrid: Shape {
    let origin: CGPoint
    let scale: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for i in -10...10 {
            let x = origin.x + CGFloat(i) * scale
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = origin.y + CGFloat(i) * scale
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

private struct GraphAxes: Shape {
    let origin: CGPoint
    let scale: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: origin.y))
        path.addLine(to: CGPoint(x: rect.maxX, y: origin.y))
        path.move(to: CGPoint(x: origin.x, y: rect.minY))
        path.addLine(to: CGPoint(x: origin.x, y: rect.maxY))
        return path
    }
}

#Preview {
    MathItLevelFourteenView(
        viewModel: MathItLevelFourteenViewModel(),
        onContinue: {},
        onReplay: {},
        onLevelSelect: {}
    )
}
