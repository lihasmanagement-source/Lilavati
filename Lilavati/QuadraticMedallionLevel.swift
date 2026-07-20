import SwiftUI

// MARK: - Level 109 - Quadratics Introduction (The Five-Method Medallion)
//
// One equation, x² − 5x + 6 = 0. A medallion at the top is split into five
// dotted wedges — one per solving method. Solve the equation with a method
// (factoring, quadratic formula, completing the square, square-root extraction,
// graphing) and its golden wedge locks into place. Complete all five to forge
// the whole medallion — five methods, one truth: x = 2, 3.

struct MathItLevelOneHundredNineView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private struct SolveMethod {
        let name: String
        let short: String
        let icon: String
        let setup: [String]
        let prompt: String
        let options: [String]
        let correct: Int
        let isGraph: Bool
    }

    private let methods: [SolveMethod] = [
        SolveMethod(name: "Factoring", short: "Factor", icon: "square.on.square",
                    setup: ["x² − 5x + 6 = 0"], prompt: "Factor it:",
                    options: ["(x−2)(x−3)", "(x−1)(x−6)", "(x+2)(x+3)"], correct: 0, isGraph: false),
        SolveMethod(name: "Quadratic Formula", short: "Formula", icon: "function",
                    setup: ["x = (5 ± √(b²−4ac)) ⁄ 2"], prompt: "b² − 4ac =",
                    options: ["1", "49", "−1"], correct: 0, isGraph: false),
        SolveMethod(name: "Completing the Square", short: "Complete", icon: "square.dashed",
                    setup: ["x² − 5x + 6 = 0"], prompt: "Complete the square:",
                    options: ["(x−5⁄2)² = 1⁄4", "(x−5)² = 19", "(x−5⁄2)² = 25⁄4"], correct: 0, isGraph: false),
        SolveMethod(name: "Square-Root Extraction", short: "√ Extract", icon: "x.squareroot",
                    setup: ["(x − 5⁄2)² = 1⁄4"], prompt: "Take the root:",
                    options: ["x − 5⁄2 = ±1⁄2", "x − 5⁄2 = ±1⁄4", "x = ±1⁄2"], correct: 0, isGraph: false),
        SolveMethod(name: "Graphing", short: "Graph", icon: "chart.xyaxis.line",
                    setup: [], prompt: "Tap where the parabola meets the x-axis",
                    options: [], correct: 0, isGraph: true)
    ]

    @State private var solved: Set<Int> = []
    @State private var selected: Int?
    @State private var wrongOption: Int?
    @State private var graphTapped: Set<Int> = []
    @State private var completed = false

    private let accent = Color(red: 0.55, green: 0.78, blue: 0.98)
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    Spacer().frame(height: size.height * 0.12)

                    medallion
                        .frame(width: 138, height: 138)

                    Text("x² − 5x + 6 = 0")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                    solvePanel(size: size)
                        .frame(height: size.height * 0.26)
                        .padding(.horizontal, 22)

                    methodChips
                        .padding(.horizontal, 16)

                    Spacer()
                }
                .frame(width: size.width)

                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Medallion Forged",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(500)
            }
        }
        .environment(\.mathItAccent, accent)
    }

    // MARK: - Medallion

    private var medallion: some View {
        ZStack {
            // Outer ring.
            Circle().stroke(.white.opacity(0.16), lineWidth: 2)
            Circle().stroke(solved.count == 5 ? gold.opacity(0.8) : .clear, lineWidth: 3)
                .shadow(color: solved.count == 5 ? gold.opacity(0.6) : .clear, radius: 12)

            ForEach(methods.indices, id: \.self) { i in
                let start = Angle.degrees(-90 + Double(i) * 72)
                let end = Angle.degrees(-90 + Double(i + 1) * 72)
                let isSolved = solved.contains(i)
                Wedge(start: start, end: end)
                    .fill(isSolved
                          ? AnyShapeStyle(RadialGradient(colors: [gold, gold.opacity(0.55)], center: .center, startRadius: 4, endRadius: 68))
                          : AnyShapeStyle(Color.clear))
                    .overlay(
                        Wedge(start: start, end: end)
                            .stroke(isSolved ? gold.opacity(0.9) : .white.opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1.4, dash: isSolved ? [] : [4, 4]))
                    )
                    .scaleEffect(isSolved ? 1 : 0.98)

                // Method icon in the wedge once solved.
                if isSolved {
                    let mid = Angle.degrees(-90 + Double(i) * 72 + 36)
                    Image(systemName: methods[i].icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                        .offset(x: cos(mid.radians) * 40, y: sin(mid.radians) * 40)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Center hub.
            Circle().fill(Color(red: 0.09, green: 0.10, blue: 0.14))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(solved.count == 5 ? gold : .white.opacity(0.3), lineWidth: 1.4))
                .overlay(
                    Text("\(solved.count)⁄5")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(solved.count == 5 ? gold : .white.opacity(0.7))
                )
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: solved)
    }

    // MARK: - Solve panel

    @ViewBuilder
    private func solvePanel(size: CGSize) -> some View {
        if let idx = selected {
            methodCard(idx)
        } else {
            emptyPanel
        }
    }

    private var emptyPanel: some View {
        VStack(spacing: 6) {
            Image(systemName: "hand.tap.fill").font(.system(size: 22)).foregroundStyle(accent.opacity(0.6))
            Text("Choose a method below to solve the equation")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func methodCard(_ idx: Int) -> some View {
        VStack(spacing: 10) {
            methodHeader(idx)
            methodBody(idx)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func methodHeader(_ idx: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: methods[idx].icon).foregroundStyle(accent)
            Text(methods[idx].name)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            if solved.contains(idx) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 13)).foregroundStyle(gold)
            }
        }
    }

    @ViewBuilder
    private func methodBody(_ idx: Int) -> some View {
        if solved.contains(idx) {
            Text("→  x = 2, 3")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(gold)
        } else if methods[idx].isGraph {
            graphSolve
        } else {
            choiceBody(idx)
        }
    }

    private func choiceBody(_ idx: Int) -> some View {
        let m = methods[idx]
        return VStack(spacing: 10) {
            ForEach(m.setup, id: \.self) { line in
                Text(line)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(m.prompt)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 8) {
                ForEach(m.options.indices, id: \.self) { o in
                    optionChip(method: idx, option: o)
                }
            }
        }
    }

    private func optionChip(method: Int, option: Int) -> some View {
        let isWrong = wrongOption == option && selected == method
        let label = methods[method].options[option]
        let fg: Color = isWrong ? Color.red.opacity(0.9) : Color.white
        let bg: Color = isWrong ? Color.red.opacity(0.18) : Color.white.opacity(0.06)
        let border: Color = isWrong ? Color.red.opacity(0.7) : accent.opacity(0.4)

        return Button {
            answer(method: method, option: option)
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(fg)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 11).fill(bg))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(border, lineWidth: 1.3))
        }
        .buttonStyle(.plain)
    }

    private var graphSolve: some View {
        ZStack {
            MiniParabola(accent: accent)
                .frame(width: 240, height: 116)
            // Tap targets at the two x-intercepts.
            ForEach([2, 3], id: \.self) { root in
                let p = interceptPoint(root, in: CGSize(width: 240, height: 116))
                Circle()
                    .fill(graphTapped.contains(root) ? gold : accent.opacity(0.001))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(graphTapped.contains(root) ? gold : accent.opacity(0.7),
                                             style: StrokeStyle(lineWidth: 1.6, dash: graphTapped.contains(root) ? [] : [3, 3])))
                    .position(p)
                    .onTapGesture { tapIntercept(root) }
            }
        }
        .frame(width: 240, height: 116)
    }

    private func interceptPoint(_ root: Int, in size: CGSize) -> CGPoint {
        let xMin = -0.7, xMax = 5.7, yMin = -1.4, yMax = 6.6
        let x = CGFloat((Double(root) - xMin) / (xMax - xMin)) * size.width
        let y = size.height - CGFloat((0 - yMin) / (yMax - yMin)) * size.height
        return CGPoint(x: x, y: y)
    }

    // MARK: - Method chips

    private var methodChips: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(methods.indices, id: \.self) { i in
                let isSel = selected == i
                let done = solved.contains(i)
                Button {
                    HapticPlayer.playLightTap()
                    withAnimation(.easeInOut(duration: 0.2)) { selected = i; wrongOption = nil }
                } label: {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Image(systemName: methods[i].icon).font(.system(size: 11, weight: .bold))
                            if done { Image(systemName: "checkmark").font(.system(size: 8, weight: .black)).foregroundStyle(isSel ? .black : gold) }
                        }
                        Text(methods[i].short).font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(isSel ? .black : .white.opacity(0.85))
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 11)
                        .fill(isSel ? accent : (done ? gold.opacity(0.14) : Color.white.opacity(0.06))))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(isSel ? .clear : (done ? gold.opacity(0.5) : accent.opacity(0.3)), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Logic

    private func answer(method: Int, option: Int) {
        guard !solved.contains(method) else { return }
        if option == methods[method].correct {
            wrongOption = nil
            unlock(method)
        } else {
            wrongOption = option
            HapticPlayer.playLightTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if wrongOption == option { wrongOption = nil }
            }
        }
    }

    private func tapIntercept(_ root: Int) {
        guard selected == 4, !solved.contains(4) else { return }
        HapticPlayer.playLightTap()
        graphTapped.insert(root)
        if graphTapped.count == 2 { unlock(4) }
    }

    private func unlock(_ method: Int) {
        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            _ = solved.insert(method)
        }
        if solved.count == methods.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { completed = true }
            }
        }
    }

    private func reset() {
        completed = false
        solved.removeAll()
        graphTapped.removeAll()
        selected = nil
        wrongOption = nil
    }
}

// MARK: - Shapes & art

private struct Wedge: Shape {
    let start: Angle
    let end: Angle
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct MiniParabola: View {
    let accent: Color
    var body: some View {
        Canvas { ctx, size in
            let xMin = -0.7, xMax = 5.7, yMin = -1.4, yMax = 6.6
            func sx(_ x: Double) -> CGFloat { CGFloat((x - xMin) / (xMax - xMin)) * size.width }
            func sy(_ y: Double) -> CGFloat { size.height - CGFloat((y - yMin) / (yMax - yMin)) * size.height }
            var ax = Path()
            ax.move(to: CGPoint(x: 0, y: sy(0))); ax.addLine(to: CGPoint(x: size.width, y: sy(0)))
            ax.move(to: CGPoint(x: sx(0), y: 0)); ax.addLine(to: CGPoint(x: sx(0), y: size.height))
            ctx.stroke(ax, with: .color(.white.opacity(0.22)), lineWidth: 0.8)
            var curve = Path()
            var first = true
            for i in 0...80 {
                let x = xMin + (xMax - xMin) * Double(i) / 80
                let p = CGPoint(x: sx(x), y: sy(x * x - 5 * x + 6))
                if first { curve.move(to: p); first = false } else { curve.addLine(to: p) }
            }
            ctx.stroke(curve, with: .color(accent), lineWidth: 2)
        }
    }
}

#Preview {
    MathItLevelOneHundredNineView(onContinue: {}, onLevelSelect: {})
}
