import SwiftUI

struct MathItLevelEightyThreeView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var amounts: [ReservoirJug: Int] = [.five: 0, .three: 0]
    @State private var dragging: ReservoirDrag?
    @State private var completed = false
    @State private var readyToComplete = false
    @State private var shakeJug: ReservoirJug?
    @State private var goalPulse = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    header
                    reservoirBoard
                        .frame(height: min(620, proxy.size.height * 0.74))
                        .padding(.horizontal, 18)
                }
                .padding(.top, 38)
                .padding(.bottom, 72)

                CompletionOverlay(
                    title: "Level 83 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 7) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))
            EmptyView()
                .font(.trajan(34))
                .tracking(7)
                .foregroundStyle(.white.opacity(completed ? 1 : 0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 58)
    }

    // MARK: - Board

    private var reservoirBoard: some View {
        GeometryReader { geo in
            // Sizes chosen so total element width (294) fits comfortably on any phone (~354pt board)
            // giving positive gap (~12pt) with no element pushed off-screen.
            let fiveW: CGFloat  = 96
            let threeW: CGFloat = 68
            let goalW: CGFloat  = 74
            let drainW: CGFloat = 56
            let extra: CGFloat = 22   // extra room between the 4L bottle and the bowl (drain)
            let gap = (geo.size.width - fiveW - threeW - goalW - drainW - extra) / 5
            let midY = geo.size.height * 0.53

            let fiveBase    = CGPoint(x: gap + fiveW / 2,                                                     y: midY)
            let threeBase   = CGPoint(x: gap + fiveW + gap + threeW / 2,                                      y: midY)
            let goalCenter  = CGPoint(x: gap + fiveW + gap + threeW + gap + goalW / 2,                        y: midY)
            let drainCenter = CGPoint(x: gap + fiveW + gap + threeW + gap + goalW + gap + extra + drainW / 2, y: midY)

            let fivePos  = dragPosition(for: .five,  base: fiveBase)
            let threePos = dragPosition(for: .three, base: threeBase)

            ZStack {
                boardBackground(size: geo.size)

                goalBottle(center: goalCenter)
                drainSymbol(center: drainCenter)

                // 5L — tap fills it; drag pours/drains
                jugView(.five, at: fivePos, base: fiveBase,
                        otherJugBase: threeBase, drainCenter: drainCenter, goalCenter: goalCenter,
                        size: CGSize(width: fiveW, height: 170))
                    .zIndex(dragging?.jug == .five  ? 8 : 3)

                // 3L — drag only (no tap-fill)
                jugView(.three, at: threePos, base: threeBase,
                        otherJugBase: fiveBase, drainCenter: drainCenter, goalCenter: goalCenter,
                        size: CGSize(width: threeW, height: 128))
                    .zIndex(dragging?.jug == .three ? 8 : 3)

                if readyToComplete && !completed {
                    pourHereHint(at: goalCenter)
                }

                bottomReadout
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func boardBackground(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(RadialGradient(
                colors: [
                    Color(red: 0.11, green: 0.5, blue: 0.95).opacity(completed ? 0.12 : 0.07),
                    Color(red: 0.012, green: 0.014, blue: 0.018),
                    .black
                ],
                center: .center,
                startRadius: 12,
                endRadius: max(size.width, size.height) * 0.72
            ))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(completed ? 0.24 : 0.12), lineWidth: 1.2)
            )
    }

    // MARK: - Sub-views

    private func pourHereHint(at center: CGPoint) -> some View {
        Text("POUR HERE")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(Color(red: 0.36, green: 0.78, blue: 1).opacity(goalPulse ? 1 : 0.3))
            .position(x: center.x, y: center.y - 96)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    goalPulse = true
                }
            }
            .onDisappear { goalPulse = false }
    }

    private func goalBottle(center: CGPoint) -> some View {
        ZStack {
            if readyToComplete && !completed {
                Circle()
                    .stroke(Color(red: 0.36, green: 0.78, blue: 1).opacity(goalPulse ? 0.5 : 0.1), lineWidth: 1.5)
                    .frame(width: 94, height: 94)
                    .blur(radius: 2)
            }

            ReservoirGoalBottleView(filled: completed)
                .frame(width: 74, height: 128)

            // Show only the litre label, no "GOAL" text
            Text("4L")
                .font(.system(size: 21, weight: .light, design: .monospaced))
                .foregroundStyle(accent.opacity(completed ? 1 : 0.82))
                .offset(y: 16)
        }
        .position(center)
    }

    private func drainSymbol(center: CGPoint) -> some View {
        ZStack {
            // Filled bowl shape
            Path { path in
                path.move(to: CGPoint(x: -26, y: -7))
                path.addQuadCurve(to: CGPoint(x: 26, y: -7),   control: CGPoint(x: 0, y: -19))
                path.addQuadCurve(to: CGPoint(x: 18, y: 17),   control: CGPoint(x: 28, y: 8))
                path.addQuadCurve(to: CGPoint(x: -18, y: 17),  control: CGPoint(x: 0, y: 24))
                path.addQuadCurve(to: CGPoint(x: -26, y: -7),  control: CGPoint(x: -28, y: 8))
                path.closeSubpath()
            }
            .fill(.black.opacity(0.68))

            // Outline + inner ripple lines
            Path { path in
                path.move(to: CGPoint(x: -26, y: -7))
                path.addQuadCurve(to: CGPoint(x: 26, y: -7),   control: CGPoint(x: 0, y: -19))
                path.addQuadCurve(to: CGPoint(x: 18, y: 17),   control: CGPoint(x: 28, y: 8))
                path.addQuadCurve(to: CGPoint(x: -18, y: 17),  control: CGPoint(x: 0, y: 24))
                path.addQuadCurve(to: CGPoint(x: -26, y: -7),  control: CGPoint(x: -28, y: 8))
                path.closeSubpath()
                path.move(to: CGPoint(x: -17, y: -2))
                path.addQuadCurve(to: CGPoint(x: 17, y: -2),   control: CGPoint(x: 0, y: 3))
                path.move(to: CGPoint(x: -12, y: 7))
                path.addQuadCurve(to: CGPoint(x: 12, y: 7),    control: CGPoint(x: 0, y: 11))
            }
            .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 56, height: 46)
        .position(center)
        .shadow(color: Color(red: 0.36, green: 0.78, blue: 1).opacity(0.28), radius: 7)
    }

    private func jugView(_ jug: ReservoirJug,
                         at position: CGPoint,
                         base: CGPoint,
                         otherJugBase: CGPoint,
                         drainCenter: CGPoint,
                         goalCenter: CGPoint,
                         size: CGSize) -> some View {
        ReservoirJugView(
            capacity: jug.capacity,
            amount: amounts[jug, default: 0],
            label: "\(jug.capacity)L",
            completed: completed && jug == .five
        )
        .frame(width: size.width, height: size.height)
        .position(position)
        .offset(x: shakeJug == jug ? -8 : 0)
        .animation(.spring(response: 0.16, dampingFraction: 0.3), value: shakeJug)
        .onTapGesture {
            if jug == .five { fillFiveJug() }   // 3L cannot be filled by tap
        }
        .gesture(
            !completed
                ? dragGesture(for: jug, base: base,
                              otherJugBase: otherJugBase,
                              drainCenter: drainCenter,
                              goalCenter: goalCenter)
                : nil
        )
    }

    private var bottomReadout: some View {
        VStack {
            Spacer()
            HStack(spacing: 26) {
                readout("5L", value: amounts[.five,  default: 0])
                readout("3L", value: amounts[.three, default: 0])
                Button(action: reset) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(accent)
                        .frame(width: 54, height: 44)
                        .background(.black.opacity(0.64), in: Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.34), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 28)
        }
    }

    private func readout(_ title: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(title):")
                .foregroundStyle(Color(red: 0.45, green: 0.82, blue: 1))
            Text("\(value)")
                .foregroundStyle(.white.opacity(0.86))
        }
        .font(.system(size: 17, weight: .medium, design: .monospaced))
    }

    // MARK: - Drag gesture

    private func dragGesture(for jug: ReservoirJug,
                             base: CGPoint,
                             otherJugBase: CGPoint,
                             drainCenter: CGPoint,
                             goalCenter: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { g in
                dragging = ReservoirDrag(jug: jug, origin: base, translation: g.translation)
            }
            .onEnded { g in
                let drop = CGPoint(x: base.x + g.translation.width,
                                   y: base.y + g.translation.height)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                    dragging = nil
                }
                handleDrop(jug, drop: drop,
                           otherJugBase: otherJugBase,
                           drainCenter: drainCenter,
                           goalCenter: goalCenter)
            }
    }

    private func dragPosition(for jug: ReservoirJug, base: CGPoint) -> CGPoint {
        guard dragging?.jug == jug, let d = dragging else { return base }
        return CGPoint(x: d.origin.x + d.translation.width,
                       y: d.origin.y + d.translation.height)
    }

    // MARK: - Drop handling — CLOSEST TARGET WINS
    //
    // Because the goal bottle sits BETWEEN the 3L jug and the drain, any fixed-radius
    // check on the goal would intercept drags meant for the 3L or drain. Instead we
    // compute the distance to every valid target and fire whichever one is nearest,
    // provided that nearest target is within a generous threshold (200pt). This makes
    // short drags go to the near target and long drags go to the far one, with no
    // interception.

    private func handleDrop(_ source: ReservoirJug,
                            drop: CGPoint,
                            otherJugBase: CGPoint,
                            drainCenter: CGPoint,
                            goalCenter: CGPoint) {
        let distOther = distance(drop, otherJugBase)
        let distDrain = distance(drop, drainCenter)
        let distGoal  = source == .five ? distance(drop, goalCenter) : .greatestFiniteMagnitude

        // Find the nearest target and its distance
        let nearest: DropTarget
        let minDist: CGFloat
        if distOther <= distDrain && distOther <= distGoal {
            nearest = .otherJug; minDist = distOther
        } else if distDrain <= distGoal {
            nearest = .drain;    minDist = distDrain
        } else {
            nearest = .goal;     minDist = distGoal
        }

        guard minDist < 200 else { invalid(source); return }

        switch nearest {
        case .otherJug: pour(source, into: source.other)
        case .drain:    empty(source)
        case .goal:     pourIntoGoal()
        }
    }

    private enum DropTarget { case otherJug, drain, goal }

    // MARK: - Game actions

    private func fillFiveJug() {
        guard !completed else { return }
        guard amounts[.five, default: 0] < 5 else { invalid(.five); return }
        withAnimation(.easeIn(duration: 0.55)) {
            amounts[.five] = 5
        }
        evaluate()
    }

    private func pour(_ source: ReservoirJug, into target: ReservoirJug) {
        let src  = amounts[source, default: 0]
        let tgt  = amounts[target, default: 0]
        let move = min(src, target.capacity - tgt)
        guard move > 0 else { invalid(source); return }
        withAnimation(.easeInOut(duration: 0.45)) {
            amounts[source] = src  - move
            amounts[target] = tgt  + move
        }
        evaluate()
    }

    private func pourIntoGoal() {
        guard readyToComplete else { invalid(.five); return }
        withAnimation(.easeOut(duration: 0.45)) {
            amounts[.five] = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.42)) {
                completed      = true
                readyToComplete = false
            }
        }
    }

    private func empty(_ jug: ReservoirJug) {
        guard amounts[jug, default: 0] > 0 else { invalid(jug); return }
        withAnimation(.easeOut(duration: 0.4)) {
            amounts[jug] = 0
        }
        evaluate()
    }

    private func invalid(_ jug: ReservoirJug) {
        withAnimation(.spring(response: 0.12, dampingFraction: 0.24)) { shakeJug = jug }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { shakeJug = nil }
    }

    private func evaluate() {
        readyToComplete = amounts[.five, default: 0] == 4
    }

    private func reset() {
        withAnimation(.easeInOut(duration: 0.3)) {
            amounts         = [.five: 0, .three: 0]
            dragging        = nil
            shakeJug        = nil
            completed       = false
            readyToComplete = false
            goalPulse       = false
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

// MARK: - Jug view

private struct ReservoirJugView: View {
    let capacity: Int
    let amount: Int
    let label: String
    let completed: Bool

    private var fillFraction: CGFloat { CGFloat(amount) / CGFloat(capacity) }

    var body: some View {
        GeometryReader { proxy in
            let h     = proxy.size.height
            let shape = ReservoirJugShape()

            ZStack {
                // Dark jug interior background
                shape.fill(.black.opacity(0.72))

                // Water column — grows from the bottom of the full jug frame.
                // Clipping the entire VStack against the shape ensures the jug
                // outline acts as the mask at full scale, so water always fills
                // right to the walls and up to the neck at 100%.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.10, green: 0.40, blue: 0.90),
                                    Color(red: 0.30, green: 0.70, blue: 1.00).opacity(0.85)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: h * fillFraction)
                }
                .clipShape(shape)
                // easeInOut gives a natural settling feel; no spring overshoot
                .animation(.easeInOut(duration: 0.48), value: amount)

                // Jug outline — on top so it always looks crisp
                shape
                    .stroke(
                        .white.opacity(completed ? 1 : 0.88),
                        style: StrokeStyle(lineWidth: completed ? 2.4 : 1.8,
                                           lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .white.opacity(completed ? 0.52 : 0.28),
                            radius: completed ? 14 : 8)

                // Capacity + current-amount labels
                VStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: capacity == 5 ? 22 : 18,
                                      weight: .light, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))
                    Text("\(amount)L")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(
                            Color(red: 0.46, green: 0.82, blue: 1)
                                .opacity(amount > 0 ? 1 : 0)
                        )
                }
                .shadow(color: .black.opacity(0.6), radius: 3)
            }
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Goal bottle view

private struct ReservoirGoalBottleView: View {
    let filled: Bool

    var body: some View {
        GeometryReader { proxy in
            let h     = proxy.size.height
            let shape = ReservoirJugShape()

            ZStack {
                shape.fill(.black.opacity(0.56))

                // When filled, show water at 4/5 of the jug height
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.14, green: 0.50, blue: 0.95),
                                    Color(red: 0.42, green: 0.84, blue: 1).opacity(0.82)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: filled ? h * 0.80 : 0)
                        .opacity(filled ? 1 : 0)
                }
                .clipShape(shape)
                .animation(.easeInOut(duration: 0.5), value: filled)

                shape
                    .stroke(
                        Color.mathItLogic.opacity(filled ? 1 : 0.82),
                        style: StrokeStyle(lineWidth: filled ? 2.3 : 1.7,
                                           lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.mathItLogic.opacity(filled ? 0.72 : 0.3),
                            radius: filled ? 17 : 9)
            }
        }
    }
}

// MARK: - Shared jug outline shape

private struct ReservoirJugShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let w = rect.width, h = rect.height
            path.move(to:         CGPoint(x: w * 0.34, y: h * 0.05))
            path.addLine(to:      CGPoint(x: w * 0.66, y: h * 0.05))
            path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.18),
                              control: CGPoint(x: w * 0.73, y: h * 0.08))
            path.addLine(to:      CGPoint(x: w * 0.78, y: h * 0.28))
            path.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.38),
                              control: CGPoint(x: w * 0.84, y: h * 0.31))
            path.addLine(to:      CGPoint(x: w * 0.85, y: h * 0.82))
            path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.92),
                              control: CGPoint(x: w * 0.85, y: h * 0.90))
            path.addLine(to:      CGPoint(x: w * 0.28, y: h * 0.92))
            path.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.82),
                              control: CGPoint(x: w * 0.15, y: h * 0.90))
            path.addLine(to:      CGPoint(x: w * 0.15, y: h * 0.38))
            path.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.28),
                              control: CGPoint(x: w * 0.16, y: h * 0.31))
            path.addLine(to:      CGPoint(x: w * 0.34, y: h * 0.18))
            path.closeSubpath()
        }
    }
}

// MARK: - Supporting types

private enum ReservoirJug: CaseIterable, Hashable {
    case five, three
    var capacity: Int    { self == .five ? 5 : 3 }
    var other: ReservoirJug { self == .five ? .three : .five }
}

private struct ReservoirDrag: Equatable {
    let jug: ReservoirJug
    let origin: CGPoint
    let translation: CGSize
}
