import SwiftUI

struct MathItLevelOneHundredFourteenView: View {
    private let coral = Color(red: 0.97, green: 0.28, blue: 0.18)
    private let navy = Color(red: 0.035, green: 0.24, blue: 0.39)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var rideProgress = 0.0
    @State private var isRiding = false
    @State private var isAssembled = false
    @State private var completed = false
    @State private var rideToken = UUID()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CoasterAssemblyScene(
                    progress: rideProgress,
                    isRiding: isRiding,
                    isAssembled: $isAssembled,
                    coral: coral,
                    navy: navy
                )
                .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                if isAssembled && !isRiding && !completed {
                    Button(action: launchRide) {
                        Image(systemName: rideProgress == 0 ? "play.fill" : "arrow.counterclockwise")
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(coral, in: Circle())
                            .shadow(color: coral.opacity(0.24), radius: 12, y: 5)
                    }
                    .buttonStyle(.plain)
                    .position(x: proxy.size.width - 48, y: proxy.size.height - 46)
                    .accessibilityLabel(rideProgress == 0 ? "Launch roller coaster" : "Ride again")
                    .transition(.scale.combined(with: .opacity))
                }

                CompletionOverlay(
                    title: "Ride Complete",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetRide,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, coral)
    }

    private func launchRide() {
        guard isAssembled, !isRiding else { return }
        let token = UUID()
        rideToken = token
        rideProgress = 0
        isRiding = true
        HapticPlayer.playLightTap()

        withAnimation(.linear(duration: 9.5)) {
            rideProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 9.55) {
            guard rideToken == token else { return }
            isRiding = false
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                completed = true
            }
        }
    }

    private func resetRide() {
        rideToken = UUID()
        completed = false
        isRiding = false
        rideProgress = 0
    }
}

private struct CoasterAssemblyScene: View {
    let progress: Double
    let isRiding: Bool
    @Binding var isAssembled: Bool
    let coral: Color
    let navy: Color

    @State private var pieceCenters: [Int: CGPoint] = [:]
    @State private var lockedPieces: Set<Int> = []
    @State private var previousSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let layout = CoasterLayout(size: size)
            let sections = CoasterCourse.sections(in: layout)
            let allPoints = CoasterCourse.joinedPoints(in: layout)
            let sectionEnds = CoasterCourse.sectionEndProgresses(in: layout)

            ZStack {
                Canvas { context, canvasSize in
                    drawBackground(context: &context, size: canvasSize)
                    drawSupports(context: &context, layout: layout)
                    drawGuide(context: &context, points: allPoints)
                    drawLandscape(context: &context, layout: layout, size: canvasSize)
                    drawStations(context: &context, points: allPoints)
                }

                ForEach(sections.indices, id: \.self) { index in
                    if let center = pieceCenters[index] {
                        DraggableTrackPiece(
                            points: sections[index],
                            equation: CoasterCourse.equations[index],
                            center: center,
                            isLocked: lockedPieces.contains(index),
                            isEnabled: !isRiding,
                            coral: coral,
                            navy: navy
                        ) { translation in
                            finishDrag(index: index, translation: translation, sections: sections, size: size)
                        }
                        .zIndex(lockedPieces.contains(index) ? 2 : 4)
                    }
                }

                if isAssembled {
                    ForEach(0..<4, id: \.self) { car in
                        CoasterCar(color: car == 0 ? coral : navy)
                            .modifier(CoasterRideModifier(
                                timeProgress: progress,
                                distanceOffset: Double(car) * 0.012,
                                points: allPoints,
                                sectionEnds: sectionEnds
                            ))
                            .opacity(progress == 0 && car > 0 ? 0 : 1)
                            .zIndex(8)
                    }
                }
            }
            .onAppear { configurePieces(for: size, sections: sections) }
            .onChange(of: size) { _, newSize in
                guard newSize != previousSize else { return }
                configurePieces(for: newSize, sections: CoasterCourse.sections(in: CoasterLayout(size: newSize)), force: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Connect six roller coaster sections, then launch the train")
    }

    private func configurePieces(for size: CGSize, sections: [[CGPoint]], force: Bool = false) {
        guard force || pieceCenters.isEmpty else { return }
        previousSize = size
        lockedPieces.removeAll()
        isAssembled = false

        let scale = max(0.72, min(size.width / 950, size.height / 700))
        let offsets = [
            CGSize(width: -74, height: 76),
            CGSize(width: 68, height: -62),
            CGSize(width: -82, height: 68),
            CGSize(width: 74, height: 70),
            CGSize(width: 86, height: -54),
            CGSize(width: -78, height: 64)
        ]

        pieceCenters = Dictionary(uniqueKeysWithValues: sections.indices.map { index in
            let target = sections[index].boundingRect.center
            let offset = offsets[index]
            return (index, CGPoint(x: target.x + offset.width * scale, y: target.y + offset.height * scale))
        })
    }

    private func finishDrag(index: Int, translation: CGSize, sections: [[CGPoint]], size: CGSize) {
        guard !lockedPieces.contains(index), let current = pieceCenters[index] else { return }
        let candidate = CGPoint(x: current.x + translation.width, y: current.y + translation.height)
        let target = sections[index].boundingRect.center
        let snapDistance = max(34, min(size.width, size.height) * 0.055)

        if candidate.distance(to: target) <= snapDistance {
            // GestureState clears its temporary translation as soon as the drag
            // ends. Commit the release point first so the piece cannot flash back
            // to its original center before the snap animation begins.
            var placementTransaction = Transaction()
            placementTransaction.disablesAnimations = true
            withTransaction(placementTransaction) {
                pieceCenters[index] = candidate
            }

            DispatchQueue.main.async {
                guard !lockedPieces.contains(index) else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    pieceCenters[index] = target
                    lockedPieces.insert(index)
                }
                HapticPlayer.playLightTap()

                if lockedPieces.count == sections.count {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        isAssembled = true
                    }
                    HapticPlayer.playCompletionTap()
                }
            }
        } else {
            let margin: CGFloat = 24
            pieceCenters[index] = CGPoint(
                x: min(max(margin, candidate.x), size.width - margin),
                y: min(max(margin, candidate.y), size.height - margin)
            )
        }
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.72, green: 0.88, blue: 0.96)))

        for cloud in [(0.21, 0.16, 0.07), (0.52, 0.20, 0.055), (0.82, 0.14, 0.075)] {
            let x = size.width * CGFloat(cloud.0)
            let y = size.height * CGFloat(cloud.1)
            let width = size.width * CGFloat(cloud.2)
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: width, height: width * 0.24)), with: .color(.white.opacity(0.86)))
            context.fill(Path(ellipseIn: CGRect(x: x + width * 0.28, y: y - width * 0.11, width: width * 0.42, height: width * 0.32)), with: .color(.white.opacity(0.86)))
        }
    }

    private func drawSupports(context: inout GraphicsContext, layout: CoasterLayout) {
        let ground = layout.point(x: 0, y: 0.90).y
        let supports: [(CGFloat, CGFloat, CGFloat)] = [
            (0.04, 0.56, 0.018), (0.10, 0.28, 0.022), (0.16, 0.20, 0.026),
            (0.24, 0.45, 0.022), (0.33, 0.76, 0.019), (0.44, 0.72, 0.020),
            (0.53, 0.65, 0.022), (0.63, 0.76, 0.021), (0.68, 0.49, 0.023),
            (0.74, 0.18, 0.028), (0.82, 0.49, 0.023), (0.92, 0.80, 0.018)
        ]

        for support in supports {
            let top = layout.point(x: support.0, y: support.1)
            let spread = layout.rect.width * support.2
            var frame = Path()
            frame.move(to: top)
            frame.addLine(to: CGPoint(x: top.x - spread, y: ground))
            frame.move(to: top)
            frame.addLine(to: CGPoint(x: top.x + spread, y: ground))
            context.stroke(frame, with: .color(Color.gray.opacity(0.42)), lineWidth: 1.7)
        }
    }

    private func drawGuide(context: inout GraphicsContext, points: [CGPoint]) {
        var guide = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { guide.move(to: point) } else { guide.addLine(to: point) }
        }
        context.stroke(guide, with: .color(.white.opacity(0.42)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [3, 7]))
    }

    private func drawLandscape(context: inout GraphicsContext, layout: CoasterLayout, size: CGSize) {
        let groundY = layout.point(x: 0, y: 0.90).y
        context.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)), with: .color(Color(red: 0.46, green: 0.75, blue: 0.16)))
        context.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: 5)), with: .color(Color(red: 0.67, green: 0.87, blue: 0.11)))

        for index in 0..<9 {
            let x = size.width * (0.13 + CGFloat(index) * 0.09)
            let height = size.height * (0.025 + CGFloat((index * 5) % 3) * 0.006)
            var tree = Path()
            tree.move(to: CGPoint(x: x, y: groundY - height))
            tree.addLine(to: CGPoint(x: x - height * 0.22, y: groundY - 2))
            tree.addLine(to: CGPoint(x: x + height * 0.22, y: groundY - 2))
            tree.closeSubpath()
            context.fill(tree, with: .color(Color(red: 0.04, green: 0.34, blue: 0.17)))
        }
    }

    private func drawStations(context: inout GraphicsContext, points: [CGPoint]) {
        guard let start = points.first, let finish = points.last else { return }
        for station in [(start, true), (finish, false)] {
            let width: CGFloat = 34
            let platform = CGRect(x: station.0.x + (station.1 ? -5 : -width + 5), y: station.0.y + 8, width: width, height: 4)
            context.fill(Path(platform), with: .color(coral))
            context.fill(Path(CGRect(x: platform.minX + 3, y: platform.minY - 20, width: width - 6, height: 4)), with: .color(navy))
        }
    }
}

private struct DraggableTrackPiece: View {
    let points: [CGPoint]
    let equation: String
    let center: CGPoint
    let isLocked: Bool
    let isEnabled: Bool
    let coral: Color
    let navy: Color
    let onDragEnded: (CGSize) -> Void

    @GestureState private var dragTranslation: CGSize = .zero

    var body: some View {
        let bounds = points.boundingRect.insetBy(dx: -12, dy: -12)
        let localPoints = points.map { CGPoint(x: $0.x - bounds.minX, y: $0.y - bounds.minY) }

        Canvas { context, _ in
            var rail = Path()
            for (index, point) in localPoints.enumerated() {
                if index == 0 { rail.move(to: point) } else { rail.addLine(to: point) }
            }
            context.stroke(rail, with: .color(.white.opacity(0.98)), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            context.stroke(rail, with: .color(navy), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            context.stroke(rail, with: .color(coral), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            if !isLocked, let first = localPoints.first, let last = localPoints.last {
                for endpoint in [first, last] {
                    context.fill(Path(ellipseIn: CGRect(x: endpoint.x - 6, y: endpoint.y - 6, width: 12, height: 12)), with: .color(.white))
                    context.stroke(Path(ellipseIn: CGRect(x: endpoint.x - 6, y: endpoint.y - 6, width: 12, height: 12)), with: .color(coral), lineWidth: 2)
                }
            }
        }
        .frame(width: max(24, bounds.width), height: max(24, bounds.height))
        .overlay(alignment: .bottom) {
            Text(equation)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(navy)
                .lineLimit(3)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 5))
                .offset(y: 22)
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        }
        .contentShape(Rectangle())
        .position(center)
        .offset(dragTranslation)
        .shadow(color: .black.opacity(isLocked ? 0.05 : 0.14), radius: isLocked ? 2 : 7, y: 3)
        .gesture(
            DragGesture(minimumDistance: 1)
                .updating($dragTranslation) { value, state, _ in
                    guard isEnabled, !isLocked else { return }
                    state = value.translation
                }
                .onEnded { value in
                    guard isEnabled, !isLocked else { return }
                    onDragEnded(value.translation)
                }
        )
        .accessibilityLabel(isLocked ? "Connected track section" : "Disconnected track section")
        .accessibilityAddTraits(isLocked ? .isSelected : [])
    }
}

private struct CoasterCar: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5).fill(color).frame(width: 18, height: 11)
            Circle().fill(.white).frame(width: 3, height: 3).offset(x: -4, y: -2)
            HStack(spacing: 7) {
                Circle().fill(.black.opacity(0.78)).frame(width: 4, height: 4)
                Circle().fill(.black.opacity(0.78)).frame(width: 4, height: 4)
            }
            .offset(y: 6)
        }
    }
}

private struct CoasterRideModifier: AnimatableModifier {
    var timeProgress: Double
    let distanceOffset: Double
    let points: [CGPoint]
    let sectionEnds: [Double]

    var animatableData: Double {
        get { timeProgress }
        set { timeProgress = newValue }
    }

    func body(content: Content) -> some View {
        let distanceProgress = max(0, CoasterCourse.realisticDistanceProgress(
            for: timeProgress,
            sectionEnds: sectionEnds
        ) - distanceOffset)
        let sample = CoasterCourse.sample(progress: distanceProgress, points: points)
        content
            .rotationEffect(.radians(sample.angle))
            .position(sample.point)
    }
}

private struct CoasterLayout {
    let rect: CGRect

    init(size: CGSize) {
        rect = CGRect(
            x: size.width * 0.09,
            y: size.height * 0.11,
            width: size.width * 0.82,
            height: size.height * 0.62
        )
    }

    func point(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
}

private enum CoasterCourse {
    static let equations = [
        "P1(t)  x=-.02+.15t+.03t^2\ny=.73-.99t+.27t^2+.18t^3",
        "P2(t)  x=.16+.21t-.15t^2+.15t^3\ny=.19+.03t+1.86t^2-1.27t^3",
        "P3(t)  x=.37+.18t-.06t^2+.04t^3\ny=.81-.03t-.45t^2+.32t^3",
        "P4(t)  x=.53+.21t-.15t^2+.15t^3\ny=.65+.03t+.42t^2-.30t^3",
        "P5,k(t)=(1-t)^3P0+3(1-t)^2tP1\n+3(1-t)t^2P2+t^3P3,  k=1...4",
        "P6(t)  x=.74+.24t+.03t^2+.01t^3\ny=.80+.06t^2-.08t^3"
    ]

    static func sections(in layout: CoasterLayout) -> [[CGPoint]] {
        normalizedSections.map { section in
            section.map { layout.point(x: $0.x, y: $0.y) }
        }
    }

    static func joinedPoints(in layout: CoasterLayout) -> [CGPoint] {
        sections(in: layout).enumerated().flatMap { index, section in
            index == 0 ? section : Array(section.dropFirst())
        }
    }

    static func sectionEndProgresses(in layout: CoasterLayout) -> [Double] {
        let sectionLengths = sections(in: layout).map { points in
            cumulativeLengths(points).last ?? 0
        }
        let total = max(0.0001, sectionLengths.reduce(0, +))
        var running = 0.0
        return sectionLengths.map { length in
            running += length
            return running / total
        }
    }

    static func realisticDistanceProgress(for time: Double, sectionEnds: [Double]) -> Double {
        guard sectionEnds.count == 6 else { return min(1, max(0, time)) }
        let times = [0.0, 0.31, 0.48, 0.60, 0.70, 0.90, 1.0]
        let distances = [0.0] + sectionEnds
        let clamped = min(1, max(0, time))
        let rawSegment = times.partitioningIndex { $0 >= clamped } - 1
        let segment = Swift.min(5, Swift.max(0, rawSegment))
        let span = max(0.0001, times[segment + 1] - times[segment])
        let local = (clamped - times[segment]) / span

        let eased: Double
        switch segment {
        case 0: eased = pow(local, 1.18)                         // Chain lift.
        case 1: eased = local * local                           // Gravity accelerates the drop.
        case 2: eased = 1 - pow(1 - local, 1.65)               // Bleed speed over the hill.
        case 3: eased = local * local * (3 - 2 * local)         // Smooth loop entry.
        case 4: eased = local + 0.08 * sin(2 * .pi * local)     // Faster low, slower high.
        default: eased = 1 - pow(1 - local, 1.45)               // Coast into the station.
        }
        return distances[segment] + (distances[segment + 1] - distances[segment]) * eased
    }

    static func sample(progress: Double, points: [CGPoint]) -> (point: CGPoint, angle: Double) {
        guard points.count > 1 else { return (.zero, 0) }
        let lengths = cumulativeLengths(points)
        let target = min(1, max(0, progress)) * (lengths.last ?? 0)
        var index = lengths.partitioningIndex { $0 >= target }
        index = min(max(1, index), points.count - 1)
        let previousLength = lengths[index - 1]
        let segmentLength = max(0.0001, lengths[index] - previousLength)
        let fraction = CGFloat((target - previousLength) / segmentLength)
        let a = points[index - 1]
        let b = points[index]
        let point = CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
        return (point, Double(atan2(b.y - a.y, b.x - a.x)))
    }

    private static var normalizedSections: [[CGPoint]] {
        var sections: [[CGPoint]] = []
        sections.append(bezier(from: CGPoint(x: -0.02, y: 0.73), c1: CGPoint(x: 0.03, y: 0.40), c2: CGPoint(x: 0.09, y: 0.16), to: CGPoint(x: 0.16, y: 0.19), steps: 48))
        sections.append(bezier(from: CGPoint(x: 0.16, y: 0.19), c1: CGPoint(x: 0.23, y: 0.20), c2: CGPoint(x: 0.25, y: 0.83), to: CGPoint(x: 0.37, y: 0.81), steps: 55))
        sections.append(bezier(from: CGPoint(x: 0.37, y: 0.81), c1: CGPoint(x: 0.43, y: 0.80), c2: CGPoint(x: 0.47, y: 0.64), to: CGPoint(x: 0.53, y: 0.65), steps: 38))
        sections.append(bezier(from: CGPoint(x: 0.53, y: 0.65), c1: CGPoint(x: 0.60, y: 0.66), c2: CGPoint(x: 0.62, y: 0.81), to: CGPoint(x: 0.74, y: 0.80), steps: 42))

        let loop = joined([
            bezier(from: CGPoint(x: 0.74, y: 0.80), c1: CGPoint(x: 0.812, y: 0.80), c2: CGPoint(x: 0.87, y: 0.661), to: CGPoint(x: 0.87, y: 0.49), steps: 30),
            bezier(from: CGPoint(x: 0.87, y: 0.49), c1: CGPoint(x: 0.87, y: 0.319), c2: CGPoint(x: 0.812, y: 0.18), to: CGPoint(x: 0.74, y: 0.18), steps: 30),
            bezier(from: CGPoint(x: 0.74, y: 0.18), c1: CGPoint(x: 0.668, y: 0.18), c2: CGPoint(x: 0.61, y: 0.319), to: CGPoint(x: 0.61, y: 0.49), steps: 30),
            bezier(from: CGPoint(x: 0.61, y: 0.49), c1: CGPoint(x: 0.61, y: 0.661), c2: CGPoint(x: 0.668, y: 0.80), to: CGPoint(x: 0.74, y: 0.80), steps: 30)
        ])
        sections.append(loop)
        sections.append(bezier(from: CGPoint(x: 0.74, y: 0.80), c1: CGPoint(x: 0.82, y: 0.80), c2: CGPoint(x: 0.91, y: 0.82), to: CGPoint(x: 1.02, y: 0.78), steps: 48))
        return sections
    }

    private static func bezier(from p0: CGPoint, c1: CGPoint, c2: CGPoint, to p3: CGPoint, steps: Int) -> [CGPoint] {
        (0...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            let u = 1 - t
            return CGPoint(
                x: u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p3.x,
                y: u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p3.y
            )
        }
    }

    private static func joined(_ sections: [[CGPoint]]) -> [CGPoint] {
        sections.enumerated().flatMap { index, section in
            index == 0 ? section : Array(section.dropFirst())
        }
    }

    private static func cumulativeLengths(_ points: [CGPoint]) -> [Double] {
        var result = [0.0]
        for index in 1..<points.count {
            let distance = hypot(points[index].x - points[index - 1].x, points[index].y - points[index - 1].y)
            result.append(result[index - 1] + Double(distance))
        }
        return result
    }
}

private extension Array where Element == CGPoint {
    var boundingRect: CGRect {
        guard let first else { return .zero }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in dropFirst() {
            minX = Swift.min(minX, point.x)
            maxX = Swift.max(maxX, point.x)
            minY = Swift.min(minY, point.y)
            maxY = Swift.max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private extension Array where Element == Double {
    func partitioningIndex(where predicate: (Double) -> Bool) -> Int {
        var low = 0
        var high = count
        while low < high {
            let middle = (low + high) / 2
            if predicate(self[middle]) { high = middle } else { low = middle + 1 }
        }
        return low
    }
}

#Preview {
    MathItLevelOneHundredFourteenView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 114) ?? 114)
}
