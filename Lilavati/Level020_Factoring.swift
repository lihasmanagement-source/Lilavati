import SwiftUI

// MARK: - Level 108 - Factoring (Genetics Punnett Square → (a+b)²)
//
// A genetics lab: two parents each carry genes a and b (shown with a colored
// eye). The player taps the 2×2 Punnett square to hatch every offspring
// (aa, ab, ba, bb) whose two eyes reveal its inherited genes. Then the player
// drags each creature into the dotted slot of the equation it belongs to —
// aa → a², the two heterozygotes → the 2ab slots, bb → b² — physically
// assembling (a + b)² = a² + 2ab + b².

struct MathItLevelOneHundredEightView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private enum Gene {
        case a, b
        var letter: String { self == .a ? "a" : "b" }
        var color: Color {
            self == .a ? Color(red: 0.98, green: 0.74, blue: 0.30)     // amber
                       : Color(red: 0.34, green: 0.62, blue: 0.98)     // blue
        }
    }

    private enum SlotKind { case a2, ab, b2
        var label: String { self == .a2 ? "a²" : (self == .ab ? "ab" : "b²") }
    }

    private enum Phase { case breeding, placing, done }

    // Cell order: 0 = (row a, col a) = aa, 1 = ab, 2 = ba, 3 = bb.
    private let cellGenes: [(row: Gene, col: Gene)] = [(.a, .a), (.a, .b), (.b, .a), (.b, .b)]
    private let slotKinds: [SlotKind] = [.a2, .ab, .ab, .b2]

    @State private var hatched = [false, false, false, false]
    @State private var phase: Phase = .breeding
    @State private var dragOffset: [Int: CGSize] = [:]
    @State private var lockedSlot: [Int: Int] = [:]     // creature → slot
    @State private var activeDrag: Int?
    @State private var hatchPulse: [Int: Bool] = [:]
    @State private var hatchPosition: [Int: CGPoint] = [:]

    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)

    private var bredCount: Int { hatched.filter { $0 }.count }

    private func kind(of i: Int) -> SlotKind {
        let g = cellGenes[i]
        if g.row == g.col { return g.row == .a ? .a2 : .b2 }
        return .ab
    }

    private func creatureBodyColor(for i: Int) -> Color {
        switch kind(of: i) {
        case .a2:
            Color(red: 0.42, green: 0.28, blue: 0.13)
        case .ab:
            Color(red: 0.24, green: 0.25, blue: 0.34)
        case .b2:
            Color(red: 0.14, green: 0.22, blue: 0.42)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cell: CGFloat = 66
            let colGap = cell + 10
            let cx = size.width / 2
            let colX = [cx - colGap / 2, cx + colGap / 2]
            let headerY = size.height * 0.235
            let row0Y = headerY + colGap
            let row1Y = row0Y + colGap
            let leftX = colX[0] - colGap
            let cellCenters: [CGPoint] = (0..<4).map { CGPoint(x: colX[$0 % 2], y: $0 < 2 ? row0Y : row1Y) }

            let slotSize: CGFloat = 56
            let slotGap: CGFloat = 12
            let totalW = slotSize * 4 + slotGap * 3
            let startX = cx - totalW / 2 + slotSize / 2
            let slotY = size.height * 0.70
            let slotCenters: [CGPoint] = (0..<4).map { CGPoint(x: startX + CGFloat($0) * (slotSize + slotGap), y: slotY) }

            ZStack {
                Color.black.ignoresSafeArea()

                // Gene chips (with eyes).
                geneChip(.a).position(x: colX[0], y: headerY)
                geneChip(.b).position(x: colX[1], y: headerY)
                geneChip(.a).position(x: leftX, y: row0Y)
                geneChip(.b).position(x: leftX, y: row1Y)

                // Cell backdrops (+ eggs while unbred). The tap gesture is
                // attached to the sized cell BEFORE .position, so its hit area
                // is exactly this cell — otherwise .position expands the view to
                // fill the screen and every cell would capture the same taps.
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: cell, height: cell)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14), lineWidth: 1))
                        .overlay {
                            if !hatched[i] {
                                EggView().frame(width: cell * 0.5, height: cell * 0.58)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { breed(i, at: cellCenters[i]) }
                        .allowsHitTesting(phase == .breeding && !hatched[i])
                        .position(cellCenters[i])
                }

                // Equation + dotted slots (placing phase).
                if phase != .breeding {
                    equationLine(complete: phase == .done)
                        .position(x: cx, y: slotY - 74)
                    ForEach(0..<4, id: \.self) { k in
                        slotView(k, filled: lockedSlot.values.contains(k))
                            .frame(width: slotSize, height: slotSize + 20)
                            .position(x: slotCenters[k].x, y: slotY + 8)
                    }
                }

                // Creature tokens.
                ForEach(0..<4, id: \.self) { i in
                    if hatched[i] {
                        creatureToken(i, cellCenter: cellCenters[i], slotCenters: slotCenters,
                                      slotSize: slotSize, threshold: 46)
                    }
                }

                if phase == .breeding {
                    Text("Tap each egg to breed the four offspring")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .position(x: cx, y: size.height * 0.64)
                }

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Identity Bred",
                    isVisible: phase == .done,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
            .coordinateSpace(name: "lab")
        }
        .environment(\.mathItAccent, gold)
    }

    // MARK: - Pieces

    private func geneChip(_ gene: Gene) -> some View {
        HStack(spacing: 4) {
            Text(gene.letter)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(gene.color)
            GeneEye(color: gene.color).frame(width: 13, height: 13)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 9).fill(gene.color.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(gene.color.opacity(0.5), lineWidth: 1))
    }

    private func slotView(_ k: Int, filled: Bool) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 11)
                .stroke(filled ? gold.opacity(0) : .white.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.6, dash: [6, 5]))
                .frame(width: 54, height: 54)
            Text(slotKinds[k].label)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(filled ? gold : .white.opacity(0.55))
        }
    }

    private func creatureToken(_ i: Int, cellCenter: CGPoint, slotCenters: [CGPoint],
                               slotSize: CGFloat, threshold: CGFloat) -> some View {
        let locked = lockedSlot[i]
        let offset = dragOffset[i] ?? .zero
        let spawn = hatchPosition[i] ?? cellCenter
        let base = locked != nil ? slotCenters[locked!] : spawn
        let pos = CGPoint(x: base.x + offset.width, y: base.y + offset.height)
        let g = cellGenes[i]
        let draggable = phase == .placing && locked == nil

        return ZStack {
            Hatchling(left: g.row.color, right: g.col.color, bodyColor: creatureBodyColor(for: i), variant: i)
                .frame(width: 40, height: 40)
            if locked == nil && phase != .breeding {
                Text("\(g.row.letter)\(g.col.letter)")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .offset(y: 30)
            }
        }
        .frame(width: 58, height: 68)
        .scaleEffect(activeDrag == i ? 1.12 : (hatchPulse[i] == true ? 1.18 : 1))
        // Gesture attached to the sized token BEFORE .position, so grabbing one
        // creature doesn't hit another's screen-filling frame.
        .contentShape(Rectangle())
        .allowsHitTesting(draggable)
        .highPriorityGesture(
            DragGesture(coordinateSpace: .named("lab"))
                .onChanged { value in
                    guard draggable else { return }
                    activeDrag = i
                    dragOffset[i] = value.translation
                }
                .onEnded { value in
                    activeDrag = nil
                    guard draggable else { return }
                    let dropped = CGPoint(x: spawn.x + value.translation.width,
                                          y: spawn.y + value.translation.height)
                    finishDrag(i, dropped: dropped, slotCenters: slotCenters, threshold: threshold)
                }
        )
        .position(pos)
        .zIndex(activeDrag == i ? 40 : (locked != nil ? 8 : 20))
    }

    private func equationLine(complete: Bool) -> some View {
        HStack(spacing: 4) {
            Text("(a + b)²  =  a²  +  2ab  +  b²")
        }
        .font(.system(size: 19, weight: .heavy, design: .rounded))
        .foregroundStyle(complete ? gold : .white.opacity(0.85))
        .shadow(color: complete ? gold.opacity(0.5) : .clear, radius: 10)
        .scaleEffect(complete ? 1.05 : 1)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: complete)
    }

    // MARK: - Logic

    private func breed(_ i: Int, at point: CGPoint) {
        guard phase == .breeding, !hatched[i] else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            hatchPosition[i] = point
            hatched[i] = true
            hatchPulse[i] = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                hatchPulse[i] = false
            }
        }
        if bredCount == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { phase = .placing }
            }
        }
    }

    private func finishDrag(_ i: Int, dropped: CGPoint, slotCenters: [CGPoint], threshold: CGFloat) {
        // Nearest empty slot whose kind matches this creature.
        let creatureKind = kind(of: i)
        var best: Int?
        var bestDist = threshold
        for k in 0..<4 where !lockedSlot.values.contains(k) && slotKinds[k] == creatureKind {
            let c = slotCenters[k]
            let d = hypot(dropped.x - c.x, dropped.y - c.y)
            if d < bestDist { bestDist = d; best = k }
        }
        if let slot = best {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                dragOffset[i] = .zero
                lockedSlot[i] = slot
            }
            HapticPlayer.playLightTap()
            if lockedSlot.count == 4 {
                HapticPlayer.playCompletionTap()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { phase = .done }
                }
            }
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.7)) { dragOffset[i] = .zero }
        }
    }

    private func reset() {
        hatched = [false, false, false, false]
        dragOffset = [:]
        lockedSlot = [:]
        activeDrag = nil
        hatchPulse = [:]
        hatchPosition = [:]
        withAnimation(.easeInOut(duration: 0.3)) { phase = .breeding }
    }
}

private extension Text {
    func levelLabel() -> some View {
        self.font(.system(size: 9, weight: .heavy, design: .monospaced)).tracking(3)
            .foregroundStyle(.white.opacity(0.35))
    }
}

// MARK: - Art

private struct GeneEye: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(.white)
                Circle().fill(color).frame(width: s * 0.6, height: s * 0.6)
                Circle().fill(.black.opacity(0.85)).frame(width: s * 0.26, height: s * 0.26)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct Hatchling: View {
    let left: Color
    let right: Color
    let bodyColor: Color
    let variant: Int

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [bodyColor.opacity(0.95), bodyColor.opacity(0.55)],
                                         center: .topLeading, startRadius: 1, endRadius: s))
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                creatureEars(size: s)
                HStack(spacing: s * 0.12) {
                    eye(left, s: s)
                    eye(right, s: s)
                }
                .offset(y: -s * 0.04)
                Path { p in
                    p.addArc(center: CGPoint(x: s / 2, y: s * 0.66), radius: s * 0.14,
                             startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                }
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func creatureEars(size s: CGFloat) -> some View {
        switch variant {
        case 0:
            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle().fill(bodyColor.opacity(0.78))
                    .frame(width: s * 0.22, height: s * 0.22)
                    .offset(x: CGFloat(side) * s * 0.28, y: -s * 0.42)
            }
        case 1:
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(bodyColor.opacity(0.82))
                    .frame(width: s * 0.12, height: s * 0.34)
                    .rotationEffect(.degrees(side < 0 ? -28 : 28))
                    .offset(x: CGFloat(side) * s * 0.26, y: -s * 0.43)
            }
        case 2:
            ForEach([-1.0, 1.0], id: \.self) { side in
                TriangleEar()
                    .fill(bodyColor.opacity(0.82))
                    .frame(width: s * 0.22, height: s * 0.24)
                    .rotationEffect(.degrees(side < 0 ? -16 : 16))
                    .offset(x: CGFloat(side) * s * 0.28, y: -s * 0.42)
            }
        default:
            Capsule().fill(bodyColor.opacity(0.82))
                .frame(width: s * 0.5, height: s * 0.13)
                .offset(y: -s * 0.43)
        }
    }

    private func eye(_ color: Color, s: CGFloat) -> some View {
        ZStack {
            Circle().fill(.white).frame(width: s * 0.30, height: s * 0.30)
            Circle().fill(color).frame(width: s * 0.18, height: s * 0.18)
            Circle().fill(.black.opacity(0.85)).frame(width: s * 0.08, height: s * 0.08)
            Circle().fill(.white).frame(width: s * 0.04, height: s * 0.04).offset(x: -s * 0.03, y: -s * 0.03)
        }
        .shadow(color: color.opacity(0.6), radius: 3)
    }
}

private struct TriangleEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct EggView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [Color(white: 0.22), Color(white: 0.12)],
                                         center: .topLeading, startRadius: 1, endRadius: h))
                    .overlay(Ellipse().stroke(.white.opacity(0.2), lineWidth: 1))
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.28))
                    p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.44))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.56))
                    p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.72))
                }
                .stroke(.white.opacity(0.16), lineWidth: 1)
                Image(systemName: "plus")
                    .font(.system(size: w * 0.24, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.3))
                    .offset(y: h * 0.02)
            }
            .frame(width: w, height: h)
        }
    }
}

#Preview {
    MathItLevelOneHundredEightView(onContinue: {}, onLevelSelect: {})
}
