import SwiftUI

// MARK: - Level 104 - One-Step Equations
//
// Two identical graduated cylinders of the same capacity. The left one is
// completely full (e.g. 5L, no empty space). The right one already holds a
// known amount (e.g. 2L); the empty space above it is the unknown x. A PUMP
// button transfers 1L per press from the full cylinder into the right one. When
// the right cylinder fills to the top, the number of litres pumped IS x — so
// x + 2 = 5 is solved by pumping until the columns match.

struct MathItLevelOneHundredFourView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    private struct Puzzle {
        let base: Int        // water already in the right cylinder
        let capacity: Int    // cylinder size = how full the left one starts
        var x: Int { capacity - base }
    }

    private let puzzles: [Puzzle] = [
        Puzzle(base: 2, capacity: 5),
        Puzzle(base: 4, capacity: 9),
        Puzzle(base: 3, capacity: 10)
    ]

    @State private var index = 0
    @State private var pumped = 0
    @State private var solvedRound = false
    @State private var completed = false
    @State private var pumpFlash = false

    private let water = Color(red: 0.30, green: 0.72, blue: 0.98)
    private let xWater = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let accent = Color(red: 0.30, green: 0.72, blue: 0.98)

    private var puzzle: Puzzle { puzzles[index] }
    private var leftAmount: Int { puzzle.capacity - pumped }
    private var canPump: Bool { !solvedRound && !completed && pumped < puzzle.x }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cylW = min(size.width * 0.26, 118)
            let cylH = min(size.height * 0.40, 300)
            let gap = cylW * 0.72
            let cy = size.height * 0.42
            let bottom = cy + cylH / 2
            let leftX = size.width / 2 - (cylW + gap) / 2
            let rightX = size.width / 2 + (cylW + gap) / 2

            ZStack {
                Color.black.ignoresSafeArea()

                header
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, size.height * 0.13)
                    .allowsHitTesting(false)

                // Left cylinder — completely full of gold, drains as it is pumped out.
                cylinderStack(
                    centerX: leftX, cy: cy, w: cylW, h: cylH, bottom: bottom,
                    divisions: puzzle.capacity,
                    base: Double(leftAmount), extra: 0, baseColor: xWater,
                    volumeLabel: "\(leftAmount)L", showX: false, extraCount: 0
                )

                // Right cylinder — known base + the pumped-in unknown x (gold).
                cylinderStack(
                    centerX: rightX, cy: cy, w: cylW, h: cylH, bottom: bottom,
                    divisions: puzzle.capacity,
                    base: Double(puzzle.base), extra: Double(pumped), baseColor: water,
                    volumeLabel: "\(puzzle.base)L", showX: true, extraCount: pumped
                )

                // Flow arrow between the cylinders.
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(pumpFlash ? xWater : .white.opacity(0.28))
                    .scaleEffect(pumpFlash ? 1.3 : 1.0)
                    .position(x: size.width / 2, y: cy - cylH * 0.26)
                    .allowsHitTesting(false)

                pumpButton
                    .position(x: size.width / 2, y: bottom + 48)

                equationStrip
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, size.height * 0.06)
                    .allowsHitTesting(false)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Solved for x",
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

    private var header: some View {
        EmptyView()
    }

    private var pumpButton: some View {
        Button(action: pump) {
            HStack(spacing: 9) {
                Image(systemName: "drop.fill")
                Text("PUMP")
            }
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(canPump ? .black : .white.opacity(0.4))
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
            .background(
                Capsule().fill(canPump ? accent : Color.white.opacity(0.12))
            )
            .shadow(color: canPump ? accent.opacity(0.4) : .clear, radius: pumpFlash ? 18 : 8)
            .scaleEffect(pumpFlash ? 0.94 : 1.0)
        }
        .disabled(!canPump)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pumpFlash)
    }

    private var equationStrip: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("x")
                    .foregroundStyle(xWater)
                Text("+ \(puzzle.base)  =  \(puzzle.capacity)")
                    .foregroundStyle(.white)
            }
            .font(.system(size: 30, weight: .heavy, design: .rounded))

            HStack(spacing: 6) {
                Text("x =")
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(pumped)")
                    .foregroundStyle(solvedRound ? xWater : .white.opacity(0.85))
                if solvedRound {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(xWater)
                }
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: solvedRound)
        }
    }

    @ViewBuilder
    private func cylinderStack(
        centerX: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, bottom: CGFloat,
        divisions: Int, base: Double, extra: Double, baseColor: Color,
        volumeLabel: String, showX: Bool, extraCount: Int
    ) -> some View {
        EquationCylinder(
            width: w, height: h, divisions: divisions,
            baseValue: base, extraValue: extra,
            baseColor: baseColor, extraColor: xWater
        )
        .position(x: centerX, y: cy)

        Text(volumeLabel)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(baseColor.opacity(0.9))
            .position(x: centerX, y: bottom + 24)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: volumeLabel)

        if showX {
            let baseSurface = bottom - CGFloat(base) / CGFloat(divisions) * h
            let totalSurface = bottom - (base + extra) / Double(divisions) * Double(h)
            let labelY = extraCount > 0 ? (baseSurface + CGFloat(totalSurface)) / 2 : baseSurface - 18
            Text(solvedRound ? "\(pumped)L" : "x")
                .font(.system(size: extraCount > 0 ? 28 : 22, weight: .heavy, design: .rounded))
                .foregroundStyle(extraCount > 0 ? .black.opacity(0.78) : xWater)
                .position(x: centerX, y: labelY)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: extraCount)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: solvedRound)
        }
    }

    private func pump() {
        guard canPump else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            pumped += 1
        }
        HapticPlayer.playLightTap()
        pumpFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pumpFlash = false }
        checkSolved()
    }

    private func checkSolved() {
        guard !solvedRound, pumped == puzzle.x else { return }
        solvedRound = true
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if index < puzzles.count - 1 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    index += 1
                    pumped = 0
                    solvedRound = false
                }
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    completed = true
                }
            }
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            index = 0
            pumped = 0
            solvedRound = false
            completed = false
        }
    }
}

// MARK: - Graduated cylinder

struct EquationCylinder: View {
    var width: CGFloat
    var height: CGFloat
    var divisions: Int
    var baseValue: Double      // solid water, from the bottom
    var extraValue: Double     // tinted water stacked above the base
    var baseColor: Color
    var extraColor: Color

    var body: some View {
        let corner = width * 0.32
        let baseH = height * CGFloat(baseValue) / CGFloat(divisions)
        let extraH = height * CGFloat(extraValue) / CGFloat(divisions)
        let surfaceH = baseH + extraH

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color.white.opacity(0.03))
                .frame(width: width, height: height)

            // Water column.
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(LinearGradient(colors: [extraColor.opacity(0.82), extraColor],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: extraH)
                    Rectangle()
                        .fill(LinearGradient(colors: [baseColor.opacity(0.85), baseColor],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: baseH)
                }
                if surfaceH > 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(height: 2)
                        .padding(.bottom, min(height - 1, surfaceH - 1))
                }
            }
            .frame(width: width, height: height, alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: corner))

            // Tick marks.
            ForEach(1..<max(2, divisions), id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: width * 0.16, height: 1)
                    .position(x: width * 0.90, y: height - height * CGFloat(i) / CGFloat(divisions))
            }

            RoundedRectangle(cornerRadius: corner)
                .stroke(Color.white.opacity(0.28), lineWidth: 1.6)
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    MathItLevelOneHundredFourView(onContinue: {}, onLevelSelect: {})
}
