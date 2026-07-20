import SwiftUI

struct MathItLevelOneHundredTwentyFiveView: View {
    private let rows = 12
    private let beadCount = 240
    private let beadStagger = 0.018
    private let travelDuration = 3.6
    private let gold = Color(red: 1.0, green: 0.68, blue: 0.16)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var startedAt: Date?
    @State private var running = false
    @State private var runToken = UUID()
    @State private var completionTask: Task<Void, Never>?
    @State private var bucketTipped = false
    @State private var runSeed: UInt64 = 0xA17C_93E5_62D4_B801
    @State private var completed = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                TimelineView(.animation(minimumInterval: 1 / 60, paused: !running)) { timeline in
                    Canvas { context, size in
                        let elapsed = startedAt.map { timeline.date.timeIntervalSince($0) } ?? -1
                        drawBoard(context: &context, size: size)
                        drawBeads(context: &context, size: size, elapsed: elapsed)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 230)
                .padding(.bottom, 104)

                GaltonBucket(tipped: bucketTipped, color: gold)
                    .frame(width: 64, height: 52)
                    .position(x: proxy.size.width / 2, y: 180)
                    .accessibilityHidden(true)

                Button(action: play) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color.black)
                        .frame(width: 60, height: 60)
                        .background(running ? gold.opacity(0.28) : gold, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(running)
                .accessibilityLabel("Play Galton board")
                .position(x: proxy.size.width / 2, y: proxy.size.height - 48)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 67 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, gold)
        .onDisappear {
            completionTask?.cancel()
            completionTask = nil
        }
    }

    private func play() {
        guard !running else { return }
        let token = UUID()
        runToken = token
        runSeed = UInt64.random(in: 1...UInt64.max)
        startedAt = Date()
        running = true
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
            bucketTipped = true
        }
        completionTask?.cancel()

        let totalDuration = Double(beadCount - 1) * beadStagger + travelDuration + 2.0
        completionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(totalDuration))
            guard !Task.isCancelled, runToken == token else { return }
            running = false
            completed = true
        }
    }

    private func resetLevel() {
        completionTask?.cancel()
        completionTask = nil
        runToken = UUID()
        startedAt = nil
        running = false
        completed = false
        bucketTipped = false
    }

    private func drawBoard(context: inout GraphicsContext, size: CGSize) {
        let layout = BoardLayout(size: size, rows: rows)

        for row in 0..<rows {
            for index in 0...row {
                let point = layout.pin(row: row, index: index)
                context.stroke(
                    Path(ellipseIn: CGRect(x: point.x - 3.2, y: point.y - 3.2, width: 6.4, height: 6.4)),
                    with: .color(.white.opacity(0.72)),
                    lineWidth: 1.2
                )
            }
        }

        var bins = Path()
        bins.move(to: CGPoint(x: layout.binLeft, y: layout.binTop))
        bins.addLine(to: CGPoint(x: layout.binLeft, y: layout.binBottom))
        bins.addLine(to: CGPoint(x: layout.binRight, y: layout.binBottom))
        bins.addLine(to: CGPoint(x: layout.binRight, y: layout.binTop))
        for index in 1...rows {
            let x = layout.binBoundary(index: index)
            bins.move(to: CGPoint(x: x, y: layout.binTop))
            bins.addLine(to: CGPoint(x: x, y: layout.binBottom))
        }
        context.stroke(bins, with: .color(.white.opacity(0.4)), lineWidth: 1.2)
    }

    private func drawBeads(context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        guard elapsed >= 0 else { return }
        let layout = BoardLayout(size: size, rows: rows)

        for bead in 0..<beadCount {
            let localTime = elapsed - Double(bead) * beadStagger
            guard localTime >= 0 else { continue }
            let bin = destinationBin(for: bead)
            let point: CGPoint

            if localTime < travelDuration {
                point = movingPoint(for: bead, progress: localTime / travelDuration, layout: layout)
            } else {
                let stack = settledStackIndex(for: bead, in: bin, elapsed: elapsed)
                point = layout.settledPoint(bin: bin, stackIndex: stack)
            }

            let color = localTime < travelDuration ? gold : Color(white: 0.66)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - 3.1, y: point.y - 3.1, width: 6.2, height: 6.2)),
                with: .color(color)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: point.x - 3.6, y: point.y - 3.6, width: 7.2, height: 7.2)),
                with: .color(.black.opacity(0.8)),
                lineWidth: 0.8
            )
        }
    }

    private func movingPoint(for bead: Int, progress: Double, layout: BoardLayout) -> CGPoint {
        let scaled = max(0, min(0.999_999, progress)) * Double(rows + 1)
        let segment = min(rows, Int(scaled))
        let local = scaled - Double(segment)

        let start: CGPoint
        let end: CGPoint
        if segment == 0 {
            start = CGPoint(x: layout.centerX, y: layout.releaseY)
            end = layout.pin(row: 0, index: 0)
        } else if segment < rows {
            let collisionRow = segment - 1
            let priorRights = rightCount(for: bead, beforeRow: collisionRow)
            start = layout.pin(row: collisionRow, index: priorRights)
            let nextRights = priorRights + (goesRight(bead: bead, row: collisionRow) ? 1 : 0)
            end = layout.pin(row: segment, index: nextRights)
        } else {
            let priorRights = rightCount(for: bead, beforeRow: rows - 1)
            start = layout.pin(row: rows - 1, index: priorRights)
            end = layout.binCenter(index: destinationBin(for: bead))
        }

        return collisionArc(from: start, to: end, progress: local, isRelease: segment == 0)
    }

    private func rightCount(for bead: Int, beforeRow row: Int) -> Int {
        guard row > 0 else { return 0 }
        return (0..<row).reduce(0) { count, decisionRow in
            count + (goesRight(bead: bead, row: decisionRow) ? 1 : 0)
        }
    }

    private func collisionArc(
        from start: CGPoint,
        to end: CGPoint,
        progress: Double,
        isRelease: Bool
    ) -> CGPoint {
        let t = CGFloat(max(0, min(1, progress)))
        guard !isRelease else {
            let fall = t * t
            return CGPoint(x: start.x, y: start.y + (end.y - start.y) * fall)
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let control1 = CGPoint(x: start.x + dx * 0.14, y: start.y + dy * 0.34)
        let control2 = CGPoint(x: end.x - dx * 0.12, y: end.y - dy * 0.12)
        let inverse = 1 - t

        return CGPoint(
            x: inverse * inverse * inverse * start.x
                + 3 * inverse * inverse * t * control1.x
                + 3 * inverse * t * t * control2.x
                + t * t * t * end.x,
            y: inverse * inverse * inverse * start.y
                + 3 * inverse * inverse * t * control1.y
                + 3 * inverse * t * t * control2.y
                + t * t * t * end.y
        )
    }

    private func destinationBin(for bead: Int) -> Int {
        (0..<rows).reduce(0) { count, row in
            count + (goesRight(bead: bead, row: row) ? 1 : 0)
        }
    }

    private func goesRight(bead: Int, row: Int) -> Bool {
        var value = runSeed &+ UInt64(bead + 1) &* 0x9E3779B97F4A7C15
        value &+= UInt64(row + 1) &* 0xD1B54A32D192ED03
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return (value & 1) == 1
    }

    private func settledStackIndex(for bead: Int, in bin: Int, elapsed: TimeInterval) -> Int {
        var count = 0
        guard bead > 0 else { return 0 }
        for earlier in 0..<bead {
            let settledAt = Double(earlier) * beadStagger + travelDuration
            if settledAt <= elapsed, destinationBin(for: earlier) == bin {
                count += 1
            }
        }
        return count
    }
}

private struct BoardLayout {
    let size: CGSize
    let rows: Int

    var centerX: CGFloat { size.width / 2 }
    var releaseY: CGFloat { 2 }
    var pinTop: CGFloat { 30 }
    var binTop: CGFloat { size.height - 102 }
    var binBottom: CGFloat { size.height - 10 }
    var usableWidth: CGFloat { min(size.width * 0.8, 390) }
    var horizontalStep: CGFloat { usableWidth / CGFloat(rows + 1) }
    var verticalStep: CGFloat { (binTop - pinTop - 10) / CGFloat(rows) }
    var binLeft: CGFloat { centerX - horizontalStep * CGFloat(rows + 1) / 2 }
    var binRight: CGFloat { centerX + horizontalStep * CGFloat(rows + 1) / 2 }

    func pin(row: Int, index: Int) -> CGPoint {
        CGPoint(
            x: centerX + (CGFloat(index) - CGFloat(row) / 2) * horizontalStep,
            y: pinTop + CGFloat(row) * verticalStep
        )
    }

    func binCenter(index: Int) -> CGPoint {
        CGPoint(
            x: centerX + (CGFloat(index) - CGFloat(rows) / 2) * horizontalStep,
            y: binTop + 5
        )
    }

    func binBoundary(index: Int) -> CGFloat {
        binLeft + CGFloat(index) * horizontalStep
    }

    func settledPoint(bin: Int, stackIndex: Int) -> CGPoint {
        let columns = 4
        let column = stackIndex % columns
        let row = stackIndex / columns
        let xOffset = (CGFloat(column) - 1.5) * min(5.6, horizontalStep * 0.21)
        return CGPoint(
            x: binCenter(index: bin).x + xOffset,
            y: binBottom - 4 - CGFloat(row) * 6.1
        )
    }
}

private struct GaltonBucket: View {
    let tipped: Bool
    let color: Color

    var body: some View {
        ZStack {
            Canvas { context, size in
                var bucket = Path()
                bucket.move(to: CGPoint(x: 10, y: 18))
                bucket.addLine(to: CGPoint(x: size.width - 10, y: 18))
                bucket.addLine(to: CGPoint(x: size.width - 18, y: size.height - 8))
                bucket.addQuadCurve(
                    to: CGPoint(x: 18, y: size.height - 8),
                    control: CGPoint(x: size.width / 2, y: size.height)
                )
                bucket.closeSubpath()
                context.fill(bucket, with: .color(Color(white: 0.24)))
                context.stroke(bucket, with: .color(color), lineWidth: 3)

                var handle = Path()
                handle.move(to: CGPoint(x: 17, y: 24))
                handle.addQuadCurve(
                    to: CGPoint(x: size.width - 17, y: 24),
                    control: CGPoint(x: size.width / 2, y: -8)
                )
                context.stroke(handle, with: .color(color.opacity(0.72)), lineWidth: 2)

                var rim = Path()
                rim.move(to: CGPoint(x: 7, y: 18))
                rim.addLine(to: CGPoint(x: size.width - 7, y: 18))
                context.stroke(rim, with: .color(color), lineWidth: 4)
            }

            ForEach(0..<11, id: \.self) { index in
                Circle()
                    .fill(Color(white: 0.68))
                    .overlay(Circle().stroke(.black.opacity(0.8), lineWidth: 0.7))
                    .frame(width: 7, height: 7)
                    .offset(
                        x: CGFloat((index * 17) % 43) - 21,
                        y: CGFloat((index * 11) % 17) - 10
                    )
            }
        }
        .rotationEffect(.degrees(tipped ? -62 : 0), anchor: .bottomTrailing)
        .offset(x: tipped ? 12 : 0, y: tipped ? 7 : 0)
        .contentShape(Rectangle())
    }
}
