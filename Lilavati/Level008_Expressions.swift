import SwiftUI

// MARK: - Level 103 - Expressions

struct MathItLevelOneHundredThreeView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private struct PieToken: Identifiable {
        let id: Int
        var sign: Int
        var position: CGPoint
        var lockedSlot: Int?

        var isGhost: Bool { sign < 0 }
    }

    private enum ExpressionMachine: String, CaseIterable, Identifiable {
        case timesTwo = "x2"
        case plusTwo = "+2"

        var id: String { rawValue }
        var color: Color {
            switch self {
            case .timesTwo: Color(red: 0.62, green: 0.45, blue: 0.98)
            case .plusTwo: Color(red: 0.28, green: 0.82, blue: 0.70)
            }
        }
    }

    @State private var tokens: [PieToken] = []
    @State private var dragOffsets: [Int: CGSize] = [:]
    @State private var nextTokenID = 1
    @State private var canvasSize: CGSize = .zero
    @State private var outputGlow = false
    @State private var isRunning = false
    @State private var completed = false
    @State private var selectedMachine: ExpressionMachine?
    @State private var activeDragID: Int?
    @State private var stageIndex = 0
    @State private var pacManActive = false
    @State private var pacManPos: CGPoint = .zero

    private let accent = Color(red: 0.62, green: 0.45, blue: 0.98)
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let stageGoals = [3, 5, 7]
    private var goalCount: Int { stageGoals[min(stageIndex, stageGoals.count - 1)] }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let machines: [(ExpressionMachine, CGPoint)] = [
                (.timesTwo, CGPoint(x: size.width * 0.38, y: size.height * 0.50)),
                (.plusTwo, CGPoint(x: size.width * 0.62, y: size.height * 0.50))
            ]
            let slots = goalSlots(in: size)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 8) {
                    Spacer().frame(height: size.height * 0.08)
                    HStack(spacing: 6) {
                        ForEach(0..<stageGoals.count, id: \.self) { i in
                            Circle()
                                .fill(i <= stageIndex ? gold : Color.white.opacity(0.2))
                                .frame(width: 7, height: 7)
                        }
                    }
                    Spacer()
                }
                .allowsHitTesting(false)

                goalSlotsView(slots)
                machineRow(machines)

                ForEach(tokens) { token in
                    movablePie(token, slots: slots, machines: machines)
                }

                if pacManActive {
                    PacManView()
                        .frame(width: 56, height: 56)
                        .position(pacManPos)
                        .zIndex(400)
                }

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Expression Built",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .onAppear { initializeIfNeeded(size: size) }
            .onChange(of: size) { _, newSize in
                canvasSize = newSize
            }
        }
        .environment(\.mathItAccent, accent)
    }

    private func goalSlotsView(_ slots: [CGPoint]) -> some View {
        ZStack {
            ForEach(slots.indices, id: \.self) { index in
                Circle()
                    .stroke(gold.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                    .frame(width: 66, height: 66)
                    .position(slots[index])
            }
        }
    }

    private func machineRow(_ machines: [(ExpressionMachine, CGPoint)]) -> some View {
        ZStack {
            ForEach(machines, id: \.0.id) { machine, point in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.12))
                    .frame(width: 94, height: 86)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(machine.color.opacity(activeStroke(for: machine)), lineWidth: selectedMachine == machine && isRunning ? 3 : 1.5)
                    )
                    .shadow(color: machine.color.opacity(selectedMachine == machine && isRunning ? 0.42 : 0.12), radius: selectedMachine == machine && isRunning ? 24 : 10)
                    .position(point)

                Text(machine.rawValue)
                    .font(.system(size: 31, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .position(point)
            }
        }
    }

    private func movablePie(
        _ token: PieToken,
        slots: [CGPoint],
        machines: [(ExpressionMachine, CGPoint)]
    ) -> some View {
        let offset = dragOffsets[token.id] ?? .zero
        return outputPie(isGhost: token.isGhost)
            .frame(width: 68, height: 68)
            .contentShape(Circle())
            .position(x: token.position.x + offset.width, y: token.position.y + offset.height)
            .shadow(color: token.isGhost ? .blue.opacity(0.34) : gold.opacity(0.35), radius: 13)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !isRunning, !completed else { return }
                        unlockIfNeeded(tokenID: token.id)
                        activeDragID = token.id
                        dragOffsets[token.id] = value.translation
                    }
                    .onEnded { value in
                        guard !isRunning, !completed else {
                            activeDragID = nil
                            dragOffsets[token.id] = .zero
                            return
                        }
                        let dropped = CGPoint(
                            x: token.position.x + value.translation.width,
                            y: token.position.y + value.translation.height
                        )
                        finishDrag(tokenID: token.id, dropped: dropped, slots: slots, machines: machines)
                        activeDragID = nil
                    }
            )
            .zIndex(zIndex(for: token))
    }

    private func initializeIfNeeded(size: CGSize) {
        canvasSize = size
        guard tokens.isEmpty else { return }
        resetTokens(size: size)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func nearestMachine(
        to point: CGPoint,
        machines: [(ExpressionMachine, CGPoint)]
    ) -> (ExpressionMachine, CGPoint)? {
        machines.min { distance(point, $0.1) < distance(point, $1.1) }
    }

    private func nearestSlot(to point: CGPoint, slots: [CGPoint]) -> Int? {
        slots.indices.min { distance(point, slots[$0]) < distance(point, slots[$1]) }
    }

    private func unlockIfNeeded(tokenID: Int) {
        guard let index = tokens.firstIndex(where: { $0.id == tokenID }),
              tokens[index].lockedSlot != nil else { return }
        tokens[index].lockedSlot = nil
    }

    private func finishDrag(
        tokenID: Int,
        dropped: CGPoint,
        slots: [CGPoint],
        machines: [(ExpressionMachine, CGPoint)]
    ) {
        guard let index = tokens.firstIndex(where: { $0.id == tokenID }) else { return }
        let token = tokens[index]
        tokens[index].position = bounded(dropped)
        dragOffsets[tokenID] = .zero

        if let slot = nearestSlot(to: dropped, slots: slots),
           token.sign > 0,
           !tokens.contains(where: { $0.lockedSlot == slot }),
           distance(dropped, slots[slot]) < 48 {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                tokens[index].position = slots[slot]
                tokens[index].lockedSlot = slot
            }
            HapticPlayer.playLightTap()
            checkCompletion(slots: slots)
            return
        }

        if let nearest = nearestMachine(to: dropped, machines: machines),
           distance(dropped, nearest.1) < 82 {
            runMachine(nearest.0, tokenID: tokenID, at: nearest.1)
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            tokens[index].position = bounded(dropped)
        }
    }

    private func runMachine(_ machine: ExpressionMachine, tokenID: Int, at point: CGPoint) {
        guard !isRunning, let index = tokens.firstIndex(where: { $0.id == tokenID }) else { return }
        selectedMachine = machine
        isRunning = true
        outputGlow = false
        activeDragID = tokenID
        let inputSign = tokens[index].sign
        HapticPlayer.playLightTap()
        withAnimation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.08)) {
            tokens[index].position = point
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            let result = resultValue(for: machine, inputSign: inputSign)
            tokens.removeAll { $0.id == tokenID }
            spawnTokens(value: result, near: outputOrigin(for: point))
            withAnimation(.easeInOut(duration: 0.35)) { outputGlow = true }
            HapticPlayer.playCompletionTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                outputGlow = false
                isRunning = false
                selectedMachine = nil
                activeDragID = nil
            }
        }
    }

    private func resultValue(for machine: ExpressionMachine, inputSign: Int) -> Int {
        switch machine {
        case .timesTwo: inputSign * 2
        case .plusTwo: inputSign + 2
        }
    }

    private func spawnTokens(value: Int, near origin: CGPoint) {
        let count = abs(value)
        guard count > 0 else { return }
        let sign = value >= 0 ? 1 : -1
        var occupied = tokens.map(\.position)
        let positions = openSpawnPositions(count: count, near: origin, occupied: occupied)
        let newTokens = positions.map { position in
            let token = PieToken(
                id: nextTokenID,
                sign: sign,
                position: position,
                lockedSlot: nil
            )
            nextTokenID += 1
            occupied.append(position)
            return token
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.66)) {
            tokens.append(contentsOf: newTokens)
        }
    }

    private func checkCompletion(slots: [CGPoint]) {
        let filled = tokens.filter { $0.lockedSlot != nil && $0.sign > 0 }.count
        guard filled >= goalCount, !completed, !pacManActive else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startPacMan(slots: slots)
        }
    }

    // Every stage ends with a little Pac-Man crossing the goal row, chomping
    // each pie in reading order — then it either advances to the next stage or,
    // on the final stage, completes the level.
    private func startPacMan(slots: [CGPoint]) {
        guard !slots.isEmpty else { return }
        isRunning = true
        // Sweep away any leftover spare pies first.
        withAnimation(.easeOut(duration: 0.25)) {
            tokens.removeAll { $0.lockedSlot == nil }
        }
        pacManActive = true
        pacManPos = CGPoint(x: slots[0].x - 110, y: slots[0].y)

        let step = 0.32
        for i in slots.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * step) {
                withAnimation(.easeInOut(duration: step)) { pacManPos = slots[i] }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * step + step * 0.62) {
                HapticPlayer.playLightTap()
                withAnimation(.easeIn(duration: 0.14)) {
                    tokens.removeAll { $0.lockedSlot == i }
                }
            }
        }

        let total = 0.3 + Double(slots.count) * step
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            withAnimation(.linear(duration: 0.5)) {
                pacManPos = CGPoint(x: (slots.last?.x ?? canvasSize.width) + 120, y: slots.last?.y ?? pacManPos.y)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.6) {
            finishPacMan()
        }
    }

    private func finishPacMan() {
        pacManActive = false
        selectedMachine = nil
        activeDragID = nil
        outputGlow = false
        dragOffsets = [:]

        if stageIndex < stageGoals.count - 1 {
            HapticPlayer.playCompletionTap()
            stageIndex += 1
            resetTokens(size: canvasSize)
            isRunning = false
        } else {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                completed = true
            }
        }
    }

    private func reset() {
        completed = false
        isRunning = false
        outputGlow = false
        selectedMachine = nil
        activeDragID = nil
        dragOffsets = [:]
        stageIndex = 0
        pacManActive = false
        resetTokens(size: canvasSize)
    }

    private func resetTokens(size: CGSize) {
        nextTokenID = 2
        tokens = [
            PieToken(id: 1, sign: 1, position: CGPoint(x: size.width * 0.50, y: size.height * 0.76), lockedSlot: nil)
        ]
    }

    private func goalSlots(in size: CGSize) -> [CGPoint] {
        let count = goalCount
        let perRow = min(count, 5)
        let spacing = min((size.width - 80) / CGFloat(max(perRow, 1)), 64)
        let rows = Int(ceil(Double(count) / Double(perRow)))
        let topY = size.height * 0.23
        let rowHeight: CGFloat = 72

        return (0..<count).map { i in
            let row = i / perRow
            let col = i % perRow
            let itemsInRow = (row == rows - 1) ? (count - perRow * row) : perRow
            let startX = size.width / 2 - spacing * CGFloat(itemsInRow - 1) / 2
            return CGPoint(x: startX + CGFloat(col) * spacing, y: topY + CGFloat(row) * rowHeight)
        }
    }

    private func outputOrigin(for machinePoint: CGPoint) -> CGPoint {
        CGPoint(x: machinePoint.x, y: canvasSize.height * 0.70)
    }

    private func openSpawnPositions(count: Int, near origin: CGPoint, occupied: [CGPoint]) -> [CGPoint] {
        var placed: [CGPoint] = []
        let offsets = outputOffsets(count: count)
        let rowSteps: [CGFloat] = [0, 86, -86, 172, -172, 258, -258]
        let sideSteps: [CGFloat] = [0, -44, 44, -88, 88, -132, 132, -176, 176]

        for offset in offsets {
            var chosen = bounded(CGPoint(x: origin.x + offset, y: origin.y))
            search: for row in rowSteps {
                for side in sideSteps {
                    let candidate = bounded(CGPoint(x: origin.x + offset + side, y: origin.y + row))
                    if isOpen(candidate, occupied: occupied + placed) {
                        chosen = candidate
                        break search
                    }
                }
            }
            placed.append(chosen)
        }

        return placed
    }

    private func isOpen(_ point: CGPoint, occupied: [CGPoint]) -> Bool {
        occupied.allSatisfy { distance(point, $0) >= 76 }
    }

    private func bounded(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 36), max(36, canvasSize.width - 36)),
            y: min(max(point.y, canvasSize.height * 0.31), max(canvasSize.height * 0.31, canvasSize.height - 72))
        )
    }

    private func outputOffsets(count: Int) -> [CGFloat] {
        switch count {
        case 0:
            return []
        case 1:
            return [0]
        case 2:
            return [-48, 48]
        case 3:
            return [-82, 0, 82]
        default:
            let spacing: CGFloat = 72
            let start = -CGFloat(count - 1) * spacing / 2
            return (0..<count).map { start + CGFloat($0) * spacing }
        }
    }

    private func activeStroke(for machine: ExpressionMachine) -> Double {
        selectedMachine == machine && isRunning ? 0.95 : 0.55
    }

    private func zIndex(for token: PieToken) -> Double {
        if activeDragID == token.id { return 20 }
        if token.lockedSlot == nil { return 8 + Double(token.id) * 0.001 }
        return 3 + Double(token.id) * 0.001
    }

    @ViewBuilder
    private func outputPie(isGhost: Bool) -> some View {
        if isGhost {
            GhostPieBody()
        } else {
            PieBody()
        }
    }
}

// MARK: - Pac-Man

private struct PacManView: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let mouth = 6 + 30 * abs(sin(t * 8))
            ZStack {
                PacManShape(mouthAngle: mouth)
                    .fill(.white)
                    .shadow(color: .white.opacity(0.6), radius: 12)
                Circle()
                    .fill(.black)
                    .frame(width: 6, height: 6)
                    .offset(x: 4, y: -13)
            }
        }
    }
}

private struct PacManShape: Shape {
    var mouthAngle: Double   // half-angle of the mouth opening, in degrees

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(mouthAngle),
            endAngle: .degrees(360 - mouthAngle),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Pie drawing

private struct PieBody: View {
    private let crust = Color(red: 0.72, green: 0.47, blue: 0.24)
    private let crustHi = Color(red: 0.86, green: 0.62, blue: 0.34)
    private let filling = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let cherry = Color(red: 0.86, green: 0.24, blue: 0.26)

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2

            ctx.fill(circle(c, r), with: .color(crust))
            for k in 0..<20 {
                let a = CGFloat(k) / 20 * 2 * .pi
                let p = CGPoint(x: c.x + cos(a) * r * 0.96, y: c.y + sin(a) * r * 0.96)
                ctx.fill(circle(p, r * 0.09), with: .color(crustHi))
            }
            ctx.fill(circle(c, r * 0.84), with: .color(crust))
            ctx.fill(
                circle(c, r * 0.77),
                with: .radialGradient(
                    Gradient(colors: [filling, filling.opacity(0.74)]),
                    center: CGPoint(x: c.x - r * 0.2, y: c.y - r * 0.2),
                    startRadius: 1,
                    endRadius: r * 0.88
                )
            )

            var clipped = ctx
            clipped.clip(to: circle(c, r * 0.77))
            let step = r * 0.32
            for d in stride(from: -r, through: r, by: step) {
                clipped.stroke(diagonal(c, r, offset: d, up: true), with: .color(crustHi.opacity(0.9)),
                               style: StrokeStyle(lineWidth: r * 0.1, lineCap: .round))
                clipped.stroke(diagonal(c, r, offset: d, up: false), with: .color(crust.opacity(0.95)),
                               style: StrokeStyle(lineWidth: r * 0.1, lineCap: .round))
            }

            ctx.fill(circle(c, r * 0.15), with: .color(cherry))
            ctx.fill(circle(CGPoint(x: c.x - r * 0.05, y: c.y - r * 0.06), r * 0.05),
                     with: .color(.white.opacity(0.75)))
        }
    }

    private func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private func diagonal(_ c: CGPoint, _ r: CGFloat, offset: CGFloat, up: Bool) -> Path {
        var path = Path()
        let s: CGFloat = up ? 1 : -1
        path.move(to: CGPoint(x: c.x - r, y: c.y + offset - s * r))
        path.addLine(to: CGPoint(x: c.x + r, y: c.y + offset + s * r))
        return path
    }
}

private struct GhostPieBody: View {
    private let ghost = Color(red: 0.38, green: 0.70, blue: 1.0)

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            let outer = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            let inner = Path(ellipseIn: CGRect(x: c.x - r * 0.74, y: c.y - r * 0.74, width: r * 1.48, height: r * 1.48))

            ctx.fill(outer, with: .color(ghost.opacity(0.13)))
            ctx.stroke(outer, with: .color(ghost.opacity(0.78)),
                       style: StrokeStyle(lineWidth: r * 0.08, lineCap: .round, dash: [r * 0.18, r * 0.13]))
            ctx.stroke(inner, with: .color(.white.opacity(0.38)),
                       style: StrokeStyle(lineWidth: r * 0.045, lineCap: .round))

            for k in 0..<3 {
                let y = c.y + CGFloat(k - 1) * r * 0.32
                var path = Path()
                path.move(to: CGPoint(x: c.x - r * 0.42, y: y))
                path.addCurve(
                    to: CGPoint(x: c.x + r * 0.42, y: y),
                    control1: CGPoint(x: c.x - r * 0.18, y: y - r * 0.16),
                    control2: CGPoint(x: c.x + r * 0.18, y: y + r * 0.16)
                )
                ctx.stroke(path, with: .color(ghost.opacity(0.55)),
                           style: StrokeStyle(lineWidth: r * 0.045, lineCap: .round))
            }

            ctx.draw(
                Text("-")
                    .font(.system(size: r * 0.9, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.82)),
                at: c
            )
        }
    }
}

#Preview {
    MathItLevelOneHundredThreeView(onContinue: {}, onLevelSelect: {})
}
