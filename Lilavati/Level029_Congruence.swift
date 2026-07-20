import SwiftUI

// MARK: - Level 17 - Congruence (Fossil Footprints)
//
// A dust-covered dig site. The player brushes a finger across the sand to
// uncover footprints scattered naturally around the pit — four congruent
// pairs (same variety, same size), partners buried far apart, some mirrored.
// At the bottom, the museum shows dashed pair-outlines for each species. Drag
// each uncovered print into its matching outline; complete a pair and the
// prints transform into a full dinosaur model. Two theropod species differ
// only in size — similar, never congruent. The blocky print is built from
// right angles and wears the ∟ marker.

@Observable
final class MathItLevelSeventeenViewModel {
    enum Variety {
        case theropod, sauropod, blocky
    }

    struct PrintSpec: Identifiable {
        let id: Int
        let pair: Int
        let variety: Variety
        let scale: CGFloat
        let pos: CGPoint          // relative (0…1) within the dig area
        let rotation: Double
        let flipped: Bool
    }

    // Natural scatter — no grid, partners far apart, some mirrored.
    let prints: [PrintSpec] = [
        PrintSpec(id: 0, pair: 0, variety: .theropod, scale: 1.0,  pos: CGPoint(x: 0.16, y: 0.14), rotation: 23,  flipped: false),
        PrintSpec(id: 1, pair: 0, variety: .theropod, scale: 1.0,  pos: CGPoint(x: 0.86, y: 0.76), rotation: 208, flipped: true),
        PrintSpec(id: 2, pair: 1, variety: .theropod, scale: 1.42, pos: CGPoint(x: 0.77, y: 0.11), rotation: -12, flipped: false),
        PrintSpec(id: 3, pair: 1, variety: .theropod, scale: 1.42, pos: CGPoint(x: 0.11, y: 0.80), rotation: 97,  flipped: false),
        PrintSpec(id: 4, pair: 2, variety: .sauropod, scale: 1.12, pos: CGPoint(x: 0.43, y: 0.24), rotation: 51,  flipped: false),
        PrintSpec(id: 5, pair: 2, variety: .sauropod, scale: 1.12, pos: CGPoint(x: 0.62, y: 0.87), rotation: 139, flipped: false),
        PrintSpec(id: 6, pair: 3, variety: .blocky,   scale: 1.0,  pos: CGPoint(x: 0.27, y: 0.52), rotation: 66,  flipped: false),
        PrintSpec(id: 7, pair: 3, variety: .blocky,   scale: 1.0,  pos: CGPoint(x: 0.89, y: 0.44), rotation: -78, flipped: true)
    ]

    var reveal: [Int: CGFloat] = [:]        // 0 = buried … 1 = uncovered
    var placed: [Int: Int] = [:]            // printID → slot berth (0 = left, 1 = right)
    var matchedPairs: Set<Int> = []
    var wrongSlot: Int?
    var justHatched: Int?
    var completed = false

    var pairCount: Int { Set(prints.map(\.pair)).count }
    var progress: Double { completed ? 1 : Double(matchedPairs.count) / Double(pairCount) }

    func revealAmount(_ id: Int) -> CGFloat { reveal[id] ?? 0 }
    func isRevealed(_ id: Int) -> Bool { revealAmount(id) >= 1 }
    func isPlaced(_ id: Int) -> Bool { placed[id] != nil }

    func reset() {
        reveal = [:]
        placed = [:]
        matchedPairs = []
        wrongSlot = nil
        justHatched = nil
        completed = false
    }

    /// Brushing the sand near buried prints uncovers them.
    func scrub(at point: CGPoint, printPoints: [Int: CGPoint]) {
        guard !completed else { return }
        for spec in prints where !isRevealed(spec.id) && !isPlaced(spec.id) {
            guard let p = printPoints[spec.id] else { continue }
            let reach = 40 * spec.scale
            if hypot(point.x - p.x, point.y - p.y) < reach {
                let before = revealAmount(spec.id)
                let after = min(1, before + 0.05)
                reveal[spec.id] = after
                if before < 1, after >= 1 {
                    HapticPlayer.playLightTap()
                }
            }
        }
    }

    /// Drop a print onto a museum slot. Only its own species/size outline
    /// accepts it.
    func place(printID: Int, onSlot slot: Int) -> Bool {
        guard let spec = prints.first(where: { $0.id == printID }), !isPlaced(printID) else { return false }
        guard slot == spec.pair else {
            wrongSlot = slot
            HapticPlayer.playLightTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if self.wrongSlot == slot { self.wrongSlot = nil }
            }
            return false
        }

        let berth = placed.contains { key, _ in
            prints.first(where: { $0.id == key })?.pair == spec.pair
        } ? 1 : 0
        placed[printID] = berth
        HapticPlayer.playLightTap()

        // Pair complete → the museum rebuilds the dinosaur.
        let pairPrintIDs = prints.filter { $0.pair == spec.pair }.map(\.id)
        if pairPrintIDs.allSatisfy({ placed[$0] != nil }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                HapticPlayer.playCompletionTap()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                    self.matchedPairs.insert(spec.pair)
                    self.justHatched = spec.pair
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    if self.justHatched == spec.pair { self.justHatched = nil }
                }
                if self.matchedPairs.count == self.pairCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        withAnimation(.spring(response: 0.54, dampingFraction: 0.84)) {
                            self.completed = true
                        }
                    }
                }
            }
        }
        return true
    }
}

struct MathItLevelSeventeenView: View {
    var viewModel: MathItLevelSeventeenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    @State private var dragOffsets: [Int: CGSize] = [:]
    @State private var activeDrag: Int?

    private let bone = Color(red: 0.85, green: 0.76, blue: 0.58)
    private let sand = Color(red: 0.35, green: 0.28, blue: 0.18)
    private let dust = Color(red: 0.48, green: 0.40, blue: 0.27)
    private let gold = Color.mathGold

    private let pairColors: [Color] = [
        Color(red: 0.36, green: 0.86, blue: 1.0),    // triraptor
        Color(red: 0.98, green: 0.62, blue: 0.42),   // scaleosaurus
        Color(red: 0.42, green: 0.85, blue: 0.60),   // ellipsodocus
        Color(red: 0.72, green: 0.60, blue: 0.98)    // blockysaur
    ]
    // Every species is a geometry pun: three-toed → tri, the enlarged copy →
    // scale factor, oval pads → ellipse, right angles → blocks.
    private let dinoNames = ["triraptor", "scaleosaurus", "ellipsodocus", "blockysaur"]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let dig = CGRect(x: 18, y: size.height * 0.195,
                             width: size.width - 36, height: size.height * 0.475)
            let printPoints = Dictionary(uniqueKeysWithValues: viewModel.prints.map {
                ($0.id, CGPoint(x: dig.minX + dig.width * $0.pos.x, y: dig.minY + dig.height * $0.pos.y))
            })
            let slotW = min((size.width - 76) / 4, 88)
            let slotCenters = (0..<4).map { slotCenter(index: $0, slotW: slotW, size: size) }

            ZStack {
                Color.black.ignoresSafeArea()

                digSite(dig)

                // Sand-brushing surface (under the prints, over the site).
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: dig.width, height: dig.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let global = CGPoint(x: dig.minX + value.location.x,
                                                     y: dig.minY + value.location.y)
                                viewModel.scrub(at: global, printPoints: printPoints)
                            }
                    )
                    .position(x: dig.midX, y: dig.midY)

                // Buried / revealed prints on the site.
                ForEach(viewModel.prints) { spec in
                    if !viewModel.isPlaced(spec.id) {
                        printOnSite(spec, at: printPoints[spec.id] ?? .zero, slotCenters: slotCenters)
                    }
                }

                museumBox(size: size, slotW: slotW)
                    .position(x: size.width / 2, y: size.height * 0.80)

                Text(statusText)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .position(x: size.width / 2, y: size.height * 0.70)

                ProgressView(value: viewModel.progress)
                    .tint(gold)
                    .frame(width: min(size.width - 58, 380))
                    .position(x: size.width / 2, y: size.height * 0.165)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)
                    .zIndex(20)

                CompletionOverlay(
                    title: "Herd Rebuilt",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(100)
            }
            .environment(\.mathItAccent, gold)
        }
    }

    private var statusText: String {
        if viewModel.reveal.values.filter({ $0 >= 1 }).isEmpty {
            return "Brush the sand to uncover the tracks"
        }
        return "Drag each print into its matching outline below"
    }

    // MARK: - Prints on the dig site

    private func printOnSite(_ spec: MathItLevelSeventeenViewModel.PrintSpec,
                             at p: CGPoint, slotCenters: [CGPoint]) -> some View {
        let revealAmt = viewModel.revealAmount(spec.id)
        let revealed = viewModel.isRevealed(spec.id)
        let color = pairColors[spec.pair % pairColors.count]
        let offset = dragOffsets[spec.id] ?? .zero
        let isDragging = activeDrag == spec.id

        return ZStack {
            footprintBody(variety: spec.variety,
                          fill: bone.opacity(0.85),
                          stroke: revealed ? color : .white,
                          strokeOpacity: revealed ? 0.8 : 0.15)
                .frame(width: 46, height: 54)
                .scaleEffect(x: (spec.flipped ? -1 : 1) * spec.scale, y: spec.scale)
                .rotationEffect(.degrees(spec.rotation))
                .opacity(Double(min(1, revealAmt * 1.2)))
                .shadow(color: revealed ? color.opacity(isDragging ? 0.7 : 0.3) : .clear, radius: 9)

            // Dust cover — an irregular sandy patch that thins as you brush.
            if revealAmt < 1 {
                DustPatch(seed: spec.id)
                    .frame(width: 86 * spec.scale, height: 86 * spec.scale)
                    .opacity(Double(1 - revealAmt))
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(isDragging ? 1.12 : 1)
        .contentShape(Circle().inset(by: -14))
        .highPriorityGesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    guard revealed, !viewModel.completed else { return }
                    activeDrag = spec.id
                    dragOffsets[spec.id] = value.translation
                }
                .onEnded { value in
                    activeDrag = nil
                    guard revealed, !viewModel.completed else { return }
                    let dropped = CGPoint(x: p.x + value.translation.width,
                                          y: p.y + value.translation.height)
                    resolveDrop(spec: spec, dropped: dropped, slotCenters: slotCenters)
                }
        )
        .allowsHitTesting(revealed)
        .position(x: p.x + offset.width, y: p.y + offset.height)
        .zIndex(isDragging ? 40 : 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }

    private func resolveDrop(spec: MathItLevelSeventeenViewModel.PrintSpec,
                             dropped: CGPoint, slotCenters: [CGPoint]) {
        let nearest = slotCenters.enumerated()
            .map { (index: $0.offset, d: hypot(dropped.x - $0.element.x, dropped.y - $0.element.y)) }
            .min { $0.d < $1.d }

        if let nearest, nearest.d < 62, viewModel.place(printID: spec.id, onSlot: nearest.index) {
            dragOffsets[spec.id] = .zero
            return
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
            dragOffsets[spec.id] = .zero
        }
    }

    // MARK: - Museum box

    private func slotCenter(index: Int, slotW: CGFloat, size: CGSize) -> CGPoint {
        let spacing: CGFloat = 10
        let total = slotW * 4 + spacing * 3
        let startX = size.width / 2 - total / 2 + slotW / 2
        return CGPoint(x: startX + CGFloat(index) * (slotW + spacing), y: size.height * 0.80)
    }

    private func museumBox(size: CGSize, slotW: CGFloat) -> some View {
        VStack(spacing: 7) {
            Text("MUSEUM")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(bone.opacity(0.5))
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { pair in
                    museumSlot(pair: pair, width: slotW)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(bone.opacity(0.3), lineWidth: 1.2))
        }
    }

    private func museumSlot(pair: Int, width: CGFloat) -> some View {
        let matched = viewModel.matchedPairs.contains(pair)
        let hatching = viewModel.justHatched == pair
        let isWrong = viewModel.wrongSlot == pair
        let color = pairColors[pair % pairColors.count]
        let pairSpecs = viewModel.prints.filter { $0.pair == pair }
        let placedCount = pairSpecs.filter { viewModel.isPlaced($0.id) }.count
        let outlineScale: CGFloat = pairSpecs.first?.scale ?? 1

        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isWrong ? Color.red.opacity(0.8) : (matched ? .clear : .white.opacity(0.22)),
                            style: StrokeStyle(lineWidth: 1.3, dash: matched ? [] : [5, 4]))

                if matched {
                    dinoModel(pair: pair)
                        .fill(color)
                        .overlay(dinoModel(pair: pair).stroke(.white.opacity(0.35), lineWidth: 0.8))
                        .padding(6)
                        .scaleEffect(hatching ? 1.15 : 1)
                        .shadow(color: color.opacity(hatching ? 0.8 : 0.35), radius: hatching ? 14 : 6)
                        .transition(.scale(scale: 0.15).combined(with: .opacity))
                } else {
                    // The pair outlines: left + mirrored right berths.
                    HStack(spacing: 6) {
                        ForEach(0..<2, id: \.self) { berth in
                            slotOutline(pair: pair, berth: berth, filled: berth < placedCount,
                                        color: color, scale: outlineScale)
                        }
                    }
                }

                if hatching {
                    Circle()
                        .stroke(color.opacity(0.7), lineWidth: 2)
                        .scaleEffect(1.35)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: width, height: 54)

            Text(matched ? dinoNames[pair] : "?")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(matched ? color : .white.opacity(0.25))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: matched)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: hatching)
        .animation(.easeInOut(duration: 0.2), value: isWrong)
    }

    @ViewBuilder
    private func slotOutline(pair: Int, berth: Int, filled: Bool, color: Color, scale: CGFloat) -> some View {
        let variety: MathItLevelSeventeenViewModel.Variety =
            pair <= 1 ? .theropod : (pair == 2 ? .sauropod : .blocky)
        let base: CGFloat = 20 * scale

        ZStack {
            if filled {
                footprintBody(variety: variety, fill: bone, stroke: color, strokeOpacity: 0.9)
            } else {
                footprintShapeOnly(variety: variety)
                    .stroke(color.opacity(0.55), style: StrokeStyle(lineWidth: 1.1, dash: [3, 3]))
            }
        }
        .frame(width: base, height: base * 1.17)
        .scaleEffect(x: berth == 1 ? -1 : 1, y: 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: filled)
    }

    private func dinoModel(pair: Int) -> AnyShape {
        switch pair {
        case 0, 1: AnyShape(TheropodDinoShape())
        case 2: AnyShape(SauropodDinoShape())
        default: AnyShape(BlockyDinoShape())
        }
    }

    // MARK: - Footprint rendering

    @ViewBuilder
    private func footprintBody(variety: MathItLevelSeventeenViewModel.Variety,
                               fill: Color, stroke: Color, strokeOpacity: Double) -> some View {
        switch variety {
        case .theropod:
            TheropodPrintShape()
                .fill(fill)
                .overlay(TheropodPrintShape().stroke(stroke.opacity(strokeOpacity), lineWidth: 1.5))
        case .sauropod:
            SauropodPrintShape()
                .fill(fill)
                .overlay(SauropodPrintShape().stroke(stroke.opacity(strokeOpacity), lineWidth: 1.5))
        case .blocky:
            BlockyPrintShape()
                .fill(fill)
                .overlay(BlockyPrintShape().stroke(stroke.opacity(strokeOpacity), lineWidth: 1.5))
                .overlay(alignment: .topLeading) {
                    RightAngleGlyph()
                        .stroke(stroke.opacity(max(strokeOpacity, 0.6)), lineWidth: 1.2)
                        .frame(width: 9, height: 9)
                        .offset(x: 11, y: 21)
                }
        }
    }

    private func footprintShapeOnly(variety: MathItLevelSeventeenViewModel.Variety) -> AnyShape {
        switch variety {
        case .theropod: AnyShape(TheropodPrintShape())
        case .sauropod: AnyShape(SauropodPrintShape())
        case .blocky: AnyShape(BlockyPrintShape())
        }
    }

    // MARK: - Dig site

    private func digSite(_ dig: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [sand.opacity(0.5), sand.opacity(0.24)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 18)
                .stroke(bone.opacity(0.25), lineWidth: 1.2)

            // Scattered pebbles, bone chips and drift lines — no grid.
            Canvas { ctx, canvasSize in
                for i in 0..<26 {
                    let seed = Double(i)
                    let x = CGFloat((seed * 0.617).truncatingRemainder(dividingBy: 1)) * canvasSize.width
                    let y = CGFloat((seed * 0.383).truncatingRemainder(dividingBy: 1)) * canvasSize.height
                    let r = 1.4 + CGFloat(i % 4)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r * 0.8)),
                             with: .color(bone.opacity(0.10 + Double(i % 3) * 0.03)))
                }
                for i in 0..<6 {
                    let seed = Double(i)
                    let y = CGFloat((seed * 0.531).truncatingRemainder(dividingBy: 1)) * canvasSize.height
                    let x = CGFloat((seed * 0.713).truncatingRemainder(dividingBy: 1)) * canvasSize.width * 0.6
                    var drift = Path()
                    drift.move(to: CGPoint(x: x, y: y))
                    drift.addQuadCurve(to: CGPoint(x: x + 70, y: y + 6),
                                       control: CGPoint(x: x + 35, y: y - 5))
                    ctx.stroke(drift, with: .color(bone.opacity(0.07)), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .frame(width: dig.width, height: dig.height)
        .position(x: dig.midX, y: dig.midY)
        .allowsHitTesting(false)
    }
}

// MARK: - Dust

/// An irregular sandy mound covering a buried print.
private struct DustPatch: View {
    let seed: Int

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            func fract(_ v: Double) -> Double { v - v.rounded(.down) }

            // Overlapping soft blobs make the mound irregular.
            for i in 0..<7 {
                let s = Double(seed * 7 + i)
                let a = fract(s * 0.618) * 2 * .pi
                let r = 6 + fract(s * 0.377) * 16
                let bw = 34 + fract(s * 0.531) * 26
                let bh = bw * (0.7 + fract(s * 0.269) * 0.3)
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - bw / 2, y: p.y - bh / 2, width: bw, height: bh)),
                         with: .color(Color(red: 0.48, green: 0.40, blue: 0.27).opacity(0.55)))
            }
            // Speckles.
            for i in 0..<12 {
                let s = Double(seed * 13 + i)
                let a = fract(s * 0.719) * 2 * .pi
                let r = fract(s * 0.437) * 26
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: 2, height: 1.6)),
                         with: .color(Color(red: 0.85, green: 0.76, blue: 0.58).opacity(0.18)))
            }
        }
    }
}

// MARK: - Footprint shapes

/// Three-toed theropod footprint: heel pad + three fanned toes.
private struct TheropodPrintShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        func blob(_ cx: CGFloat, _ cy: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ tilt: CGFloat) {
            var p = Path(ellipseIn: CGRect(x: -rw / 2, y: -rh / 2, width: rw, height: rh))
            p = p.applying(CGAffineTransform(rotationAngle: tilt))
            p = p.applying(CGAffineTransform(translationX: rect.minX + cx, y: rect.minY + cy))
            path.addPath(p)
        }
        blob(w * 0.5, h * 0.74, w * 0.52, h * 0.38, 0)
        blob(w * 0.5, h * 0.26, w * 0.20, h * 0.48, 0)
        blob(w * 0.16, h * 0.38, w * 0.18, h * 0.40, -0.5)
        blob(w * 0.84, h * 0.38, w * 0.18, h * 0.40, 0.5)
        return path
    }
}

/// Round sauropod pad with four toe nubs along the front edge.
private struct SauropodPrintShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addEllipse(in: CGRect(x: w * 0.12, y: h * 0.22, width: w * 0.76, height: h * 0.72))
        for i in 0..<4 {
            let cx = w * (0.22 + 0.19 * CGFloat(i))
            path.addEllipse(in: CGRect(x: cx - w * 0.07, y: h * 0.06, width: w * 0.14, height: h * 0.20))
        }
        return path
    }
}

/// A footprint built entirely from right angles: square heel, two rectangular
/// toes. Its 90° corner carries the ∟ marker.
private struct BlockyPrintShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addRect(CGRect(x: w * 0.20, y: h * 0.42, width: w * 0.60, height: h * 0.52))
        path.addRect(CGRect(x: w * 0.20, y: h * 0.06, width: w * 0.20, height: h * 0.36))
        path.addRect(CGRect(x: w * 0.60, y: h * 0.06, width: w * 0.20, height: h * 0.36))
        return path
    }
}

/// The small ∟ right-angle marker.
private struct RightAngleGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - Dinosaur silhouettes

private struct TheropodDinoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var path = Path()
        path.move(to: pt(0.02, 0.52))
        path.addQuadCurve(to: pt(0.38, 0.30), control: pt(0.18, 0.32))
        path.addQuadCurve(to: pt(0.62, 0.20), control: pt(0.52, 0.24))
        path.addLine(to: pt(0.70, 0.08))
        path.addLine(to: pt(0.96, 0.14))
        path.addLine(to: pt(0.80, 0.28))
        path.addQuadCurve(to: pt(0.62, 0.44), control: pt(0.68, 0.36))
        path.addLine(to: pt(0.66, 0.52))
        path.addLine(to: pt(0.58, 0.50))
        path.addQuadCurve(to: pt(0.56, 0.62), control: pt(0.55, 0.56))
        path.addLine(to: pt(0.58, 0.88))
        path.addLine(to: pt(0.50, 0.88))
        path.addLine(to: pt(0.48, 0.64))
        path.addLine(to: pt(0.40, 0.64))
        path.addLine(to: pt(0.38, 0.88))
        path.addLine(to: pt(0.30, 0.88))
        path.addLine(to: pt(0.30, 0.60))
        path.addQuadCurve(to: pt(0.02, 0.62), control: pt(0.14, 0.62))
        path.closeSubpath()
        return path
    }
}

private struct SauropodDinoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var path = Path()
        path.move(to: pt(0.02, 0.58))
        path.addQuadCurve(to: pt(0.34, 0.44), control: pt(0.16, 0.44))
        path.addLine(to: pt(0.56, 0.44))
        path.addQuadCurve(to: pt(0.66, 0.10), control: pt(0.60, 0.20))
        path.addLine(to: pt(0.78, 0.06))
        path.addLine(to: pt(0.80, 0.16))
        path.addQuadCurve(to: pt(0.72, 0.48), control: pt(0.72, 0.28))
        path.addQuadCurve(to: pt(0.80, 0.58), control: pt(0.78, 0.52))
        path.addLine(to: pt(0.78, 0.88))
        path.addLine(to: pt(0.70, 0.88))
        path.addLine(to: pt(0.68, 0.64))
        path.addLine(to: pt(0.52, 0.64))
        path.addLine(to: pt(0.50, 0.88))
        path.addLine(to: pt(0.42, 0.88))
        path.addLine(to: pt(0.40, 0.62))
        path.addQuadCurve(to: pt(0.22, 0.62), control: pt(0.30, 0.64))
        path.addLine(to: pt(0.20, 0.88))
        path.addLine(to: pt(0.12, 0.88))
        path.addLine(to: pt(0.12, 0.62))
        path.addQuadCurve(to: pt(0.02, 0.66), control: pt(0.06, 0.66))
        path.closeSubpath()
        return path
    }
}

/// The blocky dinosaur — every joint a right angle, to match its footprint.
private struct BlockyDinoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.addRect(CGRect(x: w * 0.22, y: h * 0.34, width: w * 0.52, height: h * 0.32))
        path.addRect(CGRect(x: w * 0.66, y: h * 0.10, width: w * 0.28, height: h * 0.26))
        path.addRect(CGRect(x: w * 0.02, y: h * 0.40, width: w * 0.20, height: h * 0.14))
        path.addRect(CGRect(x: w * 0.28, y: h * 0.66, width: w * 0.12, height: h * 0.26))
        path.addRect(CGRect(x: w * 0.56, y: h * 0.66, width: w * 0.12, height: h * 0.26))
        return path
    }
}

#Preview {
    MathItLevelSeventeenView(
        viewModel: MathItLevelSeventeenViewModel(),
        onContinue: {},
        onReplay: {},
        onLevelSelect: {}
    )
}
