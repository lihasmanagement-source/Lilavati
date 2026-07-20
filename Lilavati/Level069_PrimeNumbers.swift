import SwiftUI

struct MathItLevelOneHundredTwentySevenView: View {
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let cyan = Color(red: 0.18, green: 0.78, blue: 1.0)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var brokenComposites: Set<Int> = []
    @State private var placedPrimes: Set<Int> = []
    @State private var hammerOffset: CGSize = .zero
    @State private var hammerSwing = 0.0
    @State private var primeOffsets: [Int: CGSize] = [:]
    @State private var completed = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: compact ? 8 : 12) {
                    progressHeader
                        .padding(.top, compact ? 8 : 18)

                    factorMine
                        .frame(maxWidth: 760)
                        .frame(height: max(520, min(650, proxy.size.height * 0.73)))
                        .padding(.bottom, compact ? 6 : 14)
                }
                .padding(.horizontal, compact ? 10 : 18)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 70 Completed",
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

    private var progressHeader: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach([2, 3, 5, 7], id: \.self) { prime in
                    Circle()
                        .fill(placedPrimes.contains(prime) ? cyan : .white.opacity(0.12))
                        .frame(width: placedPrimes.contains(prime) ? 10 : 7, height: placedPrimes.contains(prime) ? 10 : 7)
                        .shadow(color: placedPrimes.contains(prime) ? cyan : .clear, radius: 5)
                }
            }

            EmptyView()
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var factorMine: some View {
        GeometryReader { geo in
            let layout = CrystalMineLayout(size: geo.size)

            ZStack {
                MineStrataBackground()

                ForEach([6, 35], id: \.self) { composite in
                    CompositeCrystalView(
                        number: composite,
                        broken: brokenComposites.contains(composite),
                        gold: gold
                    )
                    .frame(width: layout.compositeSize.width, height: layout.compositeSize.height)
                    .position(layout.compositeCenter(composite))
                }

                ForEach([2, 3, 5, 7], id: \.self) { number in
                    CrystalSlotView(
                        number: number,
                        filled: placedPrimes.contains(number),
                        color: cyan
                    )
                    .frame(width: layout.slotSize.width, height: layout.slotSize.height)
                    .position(layout.slotCenter(number))
                }

                if brokenComposites.contains(6) {
                    draggablePrime(2, sourceComposite: 6, layout: layout)
                    draggablePrime(3, sourceComposite: 6, layout: layout)
                }

                if brokenComposites.contains(35) {
                    draggablePrime(5, sourceComposite: 35, layout: layout)
                    draggablePrime(7, sourceComposite: 35, layout: layout)
                }

                hammer(layout: layout)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(gold.opacity(0.34), lineWidth: 1)
            )
            .coordinateSpace(name: "crystalMine")
        }
    }

    private func hammer(layout: CrystalMineLayout) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(gold)
                .rotationEffect(.degrees(-32 + hammerSwing), anchor: .bottomLeading)
                .shadow(color: gold.opacity(0.35), radius: 6)

            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.38))
        }
        .frame(width: 64, height: 70)
        .contentShape(Rectangle())
        .position(layout.hammerHome)
        .offset(hammerOffset)
        .gesture(
            DragGesture(coordinateSpace: .named("crystalMine"))
                .onChanged { value in
                    hammerOffset = value.translation
                    hammerSwing = 18
                }
                .onEnded { value in
                    let impact = CGPoint(
                        x: layout.hammerHome.x + value.translation.width,
                        y: layout.hammerHome.y + value.translation.height
                    )
                    breakCrystal(at: impact, layout: layout)
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                        hammerOffset = .zero
                        hammerSwing = 0
                    }
                }
        )
        .accessibilityLabel("Draggable geology hammer")
        .zIndex(20)
    }

    @ViewBuilder
    private func draggablePrime(
        _ prime: Int,
        sourceComposite: Int,
        layout: CrystalMineLayout
    ) -> some View {
        if !placedPrimes.contains(prime) {
            ShiningPrimeCrystal(number: prime, color: cyan)
                .frame(width: layout.primeSize.width, height: layout.primeSize.height)
                .position(layout.primeOrigin(prime, sourceComposite: sourceComposite))
                .offset(primeOffsets[prime] ?? .zero)
                .gesture(
                    DragGesture(coordinateSpace: .named("crystalMine"))
                        .onChanged { value in
                            primeOffsets[prime] = value.translation
                        }
                        .onEnded { value in
                            let origin = layout.primeOrigin(prime, sourceComposite: sourceComposite)
                            let dropPoint = CGPoint(
                                x: origin.x + value.translation.width,
                                y: origin.y + value.translation.height
                            )
                            placePrime(prime, at: dropPoint, layout: layout)
                        }
                )
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .accessibilityLabel("Prime crystal \(prime), drag to its outline")
                .zIndex(12)
        }
    }

    private func breakCrystal(at point: CGPoint, layout: CrystalMineLayout) {
        guard let composite = [6, 35].first(where: {
            distance(point, layout.compositeCenter($0)) < layout.compositeHitRadius
        }), !brokenComposites.contains(composite) else { return }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.58)) {
            brokenComposites.insert(composite)
        }
    }

    private func placePrime(_ prime: Int, at point: CGPoint, layout: CrystalMineLayout) {
        let destination = layout.slotCenter(prime)
        guard distance(point, destination) < layout.slotHitRadius else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
                primeOffsets[prime] = .zero
            }
            return
        }

        withAnimation(.spring(response: 0.46, dampingFraction: 0.65)) {
            placedPrimes.insert(prime)
            primeOffsets[prime] = .zero
        }

        if placedPrimes.union([prime]) == Set([2, 3, 5, 7]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { completed = true }
            }
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func resetLevel() {
        brokenComposites = []
        placedPrimes = []
        hammerOffset = .zero
        hammerSwing = 0
        primeOffsets = [:]
        completed = false
    }
}

private struct CrystalMineLayout {
    let size: CGSize

    var compositeSize: CGSize { CGSize(width: min(104, size.width * 0.25), height: 125) }
    var slotSize: CGSize { CGSize(width: min(64, size.width * 0.16), height: 78) }
    var primeSize: CGSize { CGSize(width: min(58, size.width * 0.15), height: 68) }
    var compositeHitRadius: CGFloat { max(50, compositeSize.width * 0.62) }
    var slotHitRadius: CGFloat { max(35, slotSize.width * 0.7) }
    var hammerHome: CGPoint { CGPoint(x: size.width / 2, y: size.height - 42) }

    func compositeCenter(_ number: Int) -> CGPoint {
        CGPoint(x: size.width * (number == 6 ? 0.31 : 0.69), y: size.height * 0.20)
    }

    func primeOrigin(_ prime: Int, sourceComposite: Int) -> CGPoint {
        let source = compositeCenter(sourceComposite)
        let leftFactor = prime == 2 || prime == 5
        return CGPoint(
            x: source.x + (leftFactor ? -42 : 42),
            y: source.y + compositeSize.height * 0.73
        )
    }

    func slotCenter(_ number: Int) -> CGPoint {
        let order = [2, 3, 5, 7]
        let index = order.firstIndex(of: number) ?? 0
        let column = index % 2
        let row = index / 2
        return CGPoint(
            x: size.width * (0.34 + CGFloat(column) * 0.32),
            y: size.height * (0.53 + CGFloat(row) * 0.19)
        )
    }
}

private struct CompositeCrystalView: View {
    let number: Int
    let broken: Bool
    let gold: Color

    var body: some View {
        ZStack {
            if broken {
                ForEach(0..<4, id: \.self) { index in
                    CrystalShape()
                        .fill(Color(red: 0.30, green: 0.20, blue: 0.12))
                        .overlay(CrystalShape().stroke(gold.opacity(0.35), lineWidth: 1))
                        .frame(width: 35, height: 58)
                        .rotationEffect(.degrees(Double(index - 2) * 17))
                        .offset(
                            x: CGFloat(index - 2) * 17,
                            y: 36 + CGFloat(index % 2) * 7
                        )
                }
            } else {
                CrystalShape()
                    .fill(
                        LinearGradient(
                            colors: [gold.opacity(0.88), Color(red: 0.44, green: 0.29, blue: 0.14), Color(red: 0.13, green: 0.09, blue: 0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(CrystalFacetLines().stroke(.white.opacity(0.33), lineWidth: 1))
                    .overlay(CrystalShape().stroke(gold.opacity(0.72), lineWidth: 1.3))
                    .shadow(color: gold.opacity(0.24), radius: 8)

                Text("\(number)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.58), value: broken)
        .accessibilityLabel(broken ? "Composite crystal \(number), broken" : "Composite crystal \(number)")
    }
}

private struct CrystalSlotView: View {
    let number: Int
    let filled: Bool
    let color: Color

    var body: some View {
        ZStack {
            CrystalShape()
                .fill(filled ? color.opacity(0.72) : .clear)
                .overlay(
                    CrystalShape()
                        .stroke(
                            filled ? color : .white.opacity(0.42),
                            style: StrokeStyle(lineWidth: filled ? 2 : 1.3, dash: filled ? [] : [5, 4])
                        )
                )
                .shadow(color: filled ? color.opacity(0.8) : .clear, radius: 11)

            Text("\(number)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(filled ? .black.opacity(0.72) : .white.opacity(0.58))
        }
        .accessibilityLabel("Crystal outline \(number)")
    }
}

private struct ShiningPrimeCrystal: View {
    let number: Int
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let pulse = CGFloat((sin(timeline.date.timeIntervalSinceReferenceDate * 4) + 1) / 2)

            ZStack {
                CrystalShape()
                    .fill(
                        LinearGradient(
                            colors: [.white, color, color.opacity(0.38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(CrystalFacetLines().stroke(.white.opacity(0.65), lineWidth: 0.9))
                    .overlay(CrystalShape().stroke(.white.opacity(0.9), lineWidth: 1.2))
                    .shadow(color: color.opacity(0.55 + 0.35 * pulse), radius: 8 + 7 * pulse)

                Text("\(number)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.74))
            }
            .scaleEffect(0.96 + pulse * 0.04)
        }
    }
}

private struct CrystalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.88, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.24))
        path.closeSubpath()
        return path
    }
}

private struct CrystalFacetLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.maxX * 0.88, y: rect.minY + rect.height * 0.24))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.68))
        return path
    }
}

private struct MineStrataBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.052, green: 0.041, blue: 0.035)))

            for index in 0..<8 {
                let baseY = size.height * (0.08 + CGFloat(index) * 0.125)
                var seam = Path()
                seam.move(to: CGPoint(x: 0, y: baseY))
                for step in 1...9 {
                    let x = size.width * CGFloat(step) / 9
                    let y = baseY + CGFloat((step * 17 + index * 11) % 17) - 8
                    seam.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(seam, with: .color(.white.opacity(0.05)), lineWidth: 1)
            }
        }
    }
}

#Preview {
    MathItLevelOneHundredTwentySevenView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 127) ?? 127)
}
