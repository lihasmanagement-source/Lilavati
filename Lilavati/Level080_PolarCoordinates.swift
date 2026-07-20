import SwiftUI

struct MathItLevelSeventyNineView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var challengeIndex = 0
    @State private var bearRadius = 0.0
    @State private var bearTheta = 90.0
    @State private var attemptedCoordinate: PolarLakeCoordinate?
    @State private var fishVisible = true
    @State private var fishEscaping = false
    @State private var carryingFish = false
    @State private var splashVisible = false
    @State private var interactionLocked = false
    @State private var completed = false
    @State private var animationToken = UUID()

    private let stages = PolarLakeStage.all
    private let ice = Color(red: 0.36, green: 0.82, blue: 0.91)
    private let deepIce = Color(red: 0.055, green: 0.19, blue: 0.25)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    private var stage: PolarLakeStage { stages[stageIndex] }
    private var challenge: PolarLakeChallenge { stage.challenges[challengeIndex] }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760
            let lakeHeight = min(proxy.size.width - 24, proxy.size.height * (compact ? 0.53 : 0.56), 520)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: compact ? 9 : 13) {
                    stageHeader
                        .padding(.top, compact ? 92 : 112)

                    PolarLakeView(
                        labelStyle: stage.labelStyle,
                        target: challenge.target,
                        attemptedCoordinate: attemptedCoordinate,
                        bearRadius: bearRadius,
                        bearTheta: bearTheta,
                        fishVisible: fishVisible,
                        fishEscaping: fishEscaping,
                        carryingFish: carryingFish,
                        splashVisible: splashVisible,
                        interactionEnabled: challenge.mode == .place && !interactionLocked,
                        ice: ice,
                        deepIce: deepIce,
                        gold: gold,
                        onLakeTap: handleLakeTap
                    )
                    .frame(maxWidth: 620)
                    .frame(height: lakeHeight)

                    controls
                        .frame(maxWidth: 650)
                        .frame(minHeight: compact ? 72 : 90)

                    Button(action: resetLevel) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(gold)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.055), in: Circle())
                            .overlay(Circle().stroke(gold.opacity(0.38), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset polar lake")
                    .padding(.bottom, compact ? 4 : 12)
                }
                .padding(.horizontal, 12)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Polar Lake Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, ice)
    }

    private var stageHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                ForEach(stages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex ? ice : index == stageIndex ? gold : .white.opacity(0.13))
                        .frame(width: index == stageIndex ? 38 : 23, height: 5)
                }
            }

            HStack(spacing: 7) {
                Image(systemName: stage.symbol)
                Text(stage.title)
                Text("\(challengeIndex + 1)/\(stage.challenges.count)")
                    .foregroundStyle(.white.opacity(0.42))
            }
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(gold)
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch challenge.mode {
        case .choose:
            HStack(spacing: 8) {
                ForEach(challenge.options) { option in
                    Button {
                        attempt(option)
                    } label: {
                        Text(option.label)
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(optionTint(option), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(option == attemptedCoordinate ? gold : .white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(interactionLocked)
                }
            }

        case .place:
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(ice)

                Text(challenge.target.label)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(gold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.14), lineWidth: 1))
        }
    }

    private func optionTint(_ option: PolarLakeCoordinate) -> Color {
        guard attemptedCoordinate == option else { return .white.opacity(0.055) }
        return option.isEquivalent(to: challenge.target) ? ice.opacity(0.24) : Color.red.opacity(0.24)
    }

    private func handleLakeTap(_ coordinate: PolarLakeCoordinate) {
        guard challenge.mode == .place else { return }
        attempt(coordinate)
    }

    private func attempt(_ coordinate: PolarLakeCoordinate) {
        guard !interactionLocked, !completed else { return }
        interactionLocked = true
        attemptedCoordinate = coordinate
        let correct = coordinate.isEquivalent(to: challenge.target, tolerance: challenge.mode == .place ? 0.48 : 0.08)
        let token = UUID()
        animationToken = token

        if challenge.mode == .place, correct {
            withAnimation(.easeOut(duration: 0.18)) { fishVisible = true }
        }

        withAnimation(.easeInOut(duration: 0.42)) {
            bearTheta = coordinate.physicalTheta
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard animationToken == token else { return }
            withAnimation(.easeInOut(duration: 0.78)) {
                bearRadius = min(4, coordinate.physicalRadius)
            }
        }

        if !correct, challenge.mode == .place {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                guard animationToken == token else { return }
                withAnimation(.easeOut(duration: 0.16)) { fishVisible = true }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.22) {
            guard animationToken == token else { return }
            if correct {
                HapticPlayer.playCompletionTap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.68)) {
                    fishVisible = false
                    carryingFish = true
                    splashVisible = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                    guard animationToken == token else { return }
                    splashVisible = false
                }
            } else {
                HapticPlayer.playLightTap()
                withAnimation(.easeIn(duration: 0.42)) {
                    fishVisible = true
                    fishEscaping = true
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.68) {
            guard animationToken == token else { return }
            withAnimation(.easeInOut(duration: 0.7)) {
                bearRadius = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
            guard animationToken == token else { return }
            if correct {
                advance()
            } else {
                resetAttempt()
            }
        }
    }

    private func advance() {
        if challengeIndex + 1 < stage.challenges.count {
            challengeIndex += 1
            resetAttempt()
        } else if stageIndex + 1 < stages.count {
            stageIndex += 1
            challengeIndex = 0
            resetAttempt()
        } else {
            carryingFish = false
            completed = true
        }
    }

    private func resetAttempt() {
        attemptedCoordinate = nil
        bearRadius = 0
        bearTheta = 90
        fishVisible = challenge.mode == .choose
        fishEscaping = false
        carryingFish = false
        splashVisible = false
        interactionLocked = false
    }

    private func resetLevel() {
        animationToken = UUID()
        stageIndex = 0
        challengeIndex = 0
        completed = false
        attemptedCoordinate = nil
        bearRadius = 0
        bearTheta = 90
        fishVisible = true
        fishEscaping = false
        carryingFish = false
        splashVisible = false
        interactionLocked = false
    }
}

private struct PolarLakeView: View {
    let labelStyle: PolarLakeLabelStyle
    let target: PolarLakeCoordinate
    let attemptedCoordinate: PolarLakeCoordinate?
    let bearRadius: Double
    let bearTheta: Double
    let fishVisible: Bool
    let fishEscaping: Bool
    let carryingFish: Bool
    let splashVisible: Bool
    let interactionEnabled: Bool
    let ice: Color
    let deepIce: Color
    let gold: Color
    let onLakeTap: (PolarLakeCoordinate) -> Void

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) - 18
            let radius = side / 2
            let travelRadius = radius * 0.79
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let targetPoint = point(for: target, center: center, travelRadius: travelRadius)
            let bearPoint = point(radius: bearRadius, theta: bearTheta, center: center, travelRadius: travelRadius)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.16), ice.opacity(0.22), deepIce.opacity(0.96)],
                                center: .center,
                                startRadius: 8,
                                endRadius: radius
                            )
                        )
                        .frame(width: side, height: side)
                        .position(center)

                    PolarWaterMotion(time: time, ice: ice)
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                        .position(center)

                    PolarIceField(time: time, ice: ice, deepIce: deepIce)
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                        .position(center)

                    PolarLakeGrid(labelStyle: labelStyle, center: center, radius: travelRadius, ice: ice)

                    if let attemptedCoordinate {
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: point(for: attemptedCoordinate, center: center, travelRadius: travelRadius))
                        }
                        .stroke(
                            attemptedCoordinate.isEquivalent(to: target) ? ice.opacity(0.78) : Color.red.opacity(0.65),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
                        )
                    }

                    if fishVisible || fishEscaping {
                        PolarSwimmingFish(escaping: fishEscaping, time: time, ice: ice)
                            .position(targetPoint)
                            .transition(.scale.combined(with: .opacity))
                    }

                    if splashVisible {
                        PolarCatchSplash(ice: ice)
                            .frame(width: 70, height: 70)
                            .position(targetPoint)
                            .allowsHitTesting(false)
                    }

                    if let attemptedCoordinate, !attemptedCoordinate.isEquivalent(to: target) {
                        Circle()
                            .stroke(Color.red.opacity(0.48), style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
                            .frame(width: 31, height: 31)
                            .position(point(for: attemptedCoordinate, center: center, travelRadius: travelRadius))
                    }

                    PolarBearSprite(carryingFish: carryingFish, ice: ice)
                        .frame(width: 52, height: 62)
                        .rotationEffect(.degrees(90 - bearTheta))
                        .position(bearPoint)
                        .shadow(color: .black.opacity(0.35), radius: 7, y: 4)

                    Circle()
                        .fill(.clear)
                        .frame(width: side, height: side)
                        .contentShape(Circle())
                        .position(center)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard interactionEnabled else { return }
                                    onLakeTap(coordinate(at: value.location, center: center, travelRadius: travelRadius))
                                }
                        )
                }
            }
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(gold.opacity(0.34), lineWidth: 1))
        }
    }

    private func point(for coordinate: PolarLakeCoordinate, center: CGPoint, travelRadius: CGFloat) -> CGPoint {
        point(radius: coordinate.physicalRadius, theta: coordinate.physicalTheta, center: center, travelRadius: travelRadius)
    }

    private func point(radius: Double, theta: Double, center: CGPoint, travelRadius: CGFloat) -> CGPoint {
        let radians = theta * .pi / 180
        let distance = travelRadius * CGFloat(min(4, radius) / 4)
        return CGPoint(
            x: center.x + cos(radians) * distance,
            y: center.y - sin(radians) * distance
        )
    }

    private func coordinate(at point: CGPoint, center: CGPoint, travelRadius: CGFloat) -> PolarLakeCoordinate {
        let dx = point.x - center.x
        let dy = center.y - point.y
        let radius = min(4, Double(hypot(dx, dy) / travelRadius) * 4)
        var theta = atan2(Double(dy), Double(dx)) * 180 / .pi
        if theta < 0 { theta += 360 }
        return PolarLakeCoordinate(r: radius, theta: theta, label: "")
    }
}

private struct PolarWaterMotion: View {
    let time: TimeInterval
    let ice: Color

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            for band in 0..<6 {
                let baseline = height * (0.16 + Double(band) * 0.145)
                var current = Path()
                current.move(to: CGPoint(x: -100, y: baseline))

                for x in stride(from: -100.0, through: width + 100, by: 7.0) {
                    let broadSwell = sin(x * 0.021 + time * 0.36 + Double(band) * 1.18) * 4.8
                    let softRipple = sin(x * 0.052 - time * 0.23 + Double(band)) * 1.7
                    current.addLine(to: CGPoint(x: x, y: baseline + broadSwell + softRipple))
                }

                context.stroke(
                    current,
                    with: .color(ice.opacity(band.isMultiple(of: 2) ? 0.16 : 0.095)),
                    style: StrokeStyle(lineWidth: band.isMultiple(of: 2) ? 2.4 : 1.4, lineCap: .round)
                )
            }

            for index in 0..<7 {
                let phase = time * (0.12 + Double(index) * 0.011) + Double(index) * 1.73
                let x = width * (0.5 + 0.36 * cos(phase))
                let y = height * (0.5 + 0.34 * sin(phase * 1.31))
                let shimmerWidth = 18.0 + Double(index % 3) * 7
                var shimmer = Path()
                shimmer.move(to: CGPoint(x: x - shimmerWidth / 2, y: y))
                shimmer.addCurve(
                    to: CGPoint(x: x + shimmerWidth / 2, y: y),
                    control1: CGPoint(x: x - shimmerWidth * 0.18, y: y - 3.2),
                    control2: CGPoint(x: x + shimmerWidth * 0.18, y: y + 3.2)
                )
                context.stroke(
                    shimmer,
                    with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.19 : 0.11)),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
            }
        }
        .background(
            LinearGradient(
                colors: [ice.opacity(0.1), Color.clear, ice.opacity(0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .allowsHitTesting(false)
    }
}

private struct PolarIceField: View {
    let time: TimeInterval
    let ice: Color
    let deepIce: Color

    private let floes: [(angle: Double, distance: Double, width: Double, height: Double, phase: Double)] = [
        (18, 0.77, 38, 21, 0.2),
        (73, 0.84, 31, 18, 1.4),
        (137, 0.75, 44, 24, 2.1),
        (196, 0.83, 34, 19, 3.0),
        (246, 0.74, 42, 22, 4.2),
        (316, 0.82, 29, 17, 5.1)
    ]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2

            ZStack {
                ForEach(floes.indices, id: \.self) { index in
                    let floe = floes[index]
                    let radians = floe.angle * .pi / 180
                    let driftX = sin(time * 0.43 + floe.phase) * 3.2
                    let driftY = cos(time * 0.37 + floe.phase) * 2.2
                    let x = center.x + cos(radians) * radius * floe.distance + driftX
                    let y = center.y - sin(radians) * radius * floe.distance + driftY

                    PolarIceFloe(ice: ice, deepIce: deepIce)
                        .frame(width: floe.width, height: floe.height)
                        .rotationEffect(.degrees(sin(time * 0.22 + floe.phase) * 7 + floe.angle * 0.08))
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PolarIceFloe: View {
    let ice: Color
    let deepIce: Color

    var body: some View {
        ZStack {
            PolarIceFloeShape()
                .fill(Color.black.opacity(0.22))
                .offset(y: 3)

            PolarIceFloeShape()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.9), ice.opacity(0.72), deepIce.opacity(0.48)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PolarIceFloeShape().stroke(.white.opacity(0.62), lineWidth: 0.8))

            PolarIceFloeShape()
                .stroke(ice.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .scaleEffect(0.72)
        }
    }
}

private struct PolarIceFloeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.minY + rect.height * 0.39))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.17, y: rect.maxY - rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.11))
        path.closeSubpath()
        return path
    }
}

private struct PolarLakeGrid: View {
    let labelStyle: PolarLakeLabelStyle
    let center: CGPoint
    let radius: CGFloat
    let ice: Color

    var body: some View {
        ZStack {
            ForEach(1...4, id: \.self) { ring in
                Circle()
                    .stroke(.white.opacity(ring == 4 ? 0.34 : 0.18), lineWidth: ring == 4 ? 1.5 : 1)
                    .frame(width: radius * 2 * CGFloat(ring) / 4, height: radius * 2 * CGFloat(ring) / 4)
                    .position(center)

                if labelStyle != .hidden && (labelStyle == .degrees || ring.isMultiple(of: 2)) {
                    Text("\(ring)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .position(x: center.x + radius * CGFloat(ring) / 4 - 8, y: center.y + 11)
                }
            }

            ForEach(0..<12, id: \.self) { index in
                let theta = Double(index * 30)
                Path { path in
                    path.move(to: center)
                    path.addLine(to: radialPoint(theta: theta, distance: radius, center: center))
                }
                .stroke(.white.opacity(index.isMultiple(of: 3) ? 0.25 : 0.11), lineWidth: index.isMultiple(of: 3) ? 1.2 : 1)
            }

            ForEach(angleLabels, id: \.theta) { label in
                Text(label.text)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(label.theta.truncatingRemainder(dividingBy: 90) == 0 ? ice : .white.opacity(0.58))
                    .position(radialPoint(theta: label.theta, distance: radius + 12, center: center))
            }

            Circle()
                .fill(ice)
                .frame(width: 7, height: 7)
                .position(center)
        }
    }

    private var angleLabels: [(theta: Double, text: String)] {
        switch labelStyle {
        case .degrees:
            return stride(from: 0, to: 360, by: 30).map { (Double($0), "\($0)°") }
        case .radians:
            return [(0, "0"), (90, "π/2"), (180, "π"), (270, "3π/2")]
        case .hidden:
            return []
        }
    }

    private func radialPoint(theta: Double, distance: CGFloat, center: CGPoint) -> CGPoint {
        let radians = theta * .pi / 180
        return CGPoint(x: center.x + cos(radians) * distance, y: center.y - sin(radians) * distance)
    }
}

private struct PolarBearSprite: View {
    let carryingFish: Bool
    let ice: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.96))
                .frame(width: 34, height: 43)
                .offset(y: 7)

            Circle().fill(.white).frame(width: 11, height: 11).offset(x: -12, y: -19)
            Circle().fill(.white).frame(width: 11, height: 11).offset(x: 12, y: -19)
            Circle().fill(.white).frame(width: 30, height: 29).offset(y: -13)
            Ellipse().fill(Color(red: 0.86, green: 0.9, blue: 0.91)).frame(width: 17, height: 12).offset(y: -20)
            Circle().fill(.black).frame(width: 3, height: 3).offset(x: -6, y: -14)
            Circle().fill(.black).frame(width: 3, height: 3).offset(x: 6, y: -14)
            Circle().fill(.black).frame(width: 4, height: 4).offset(y: -23)

            if carryingFish {
                Image(systemName: "fish.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ice)
                    .offset(y: -33)
            }
        }
    }
}

private struct PolarSwimmingFish: View {
    let escaping: Bool
    let time: TimeInterval
    let ice: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 29, height: 9)
                .offset(y: 7)
                .opacity(escaping ? 0 : 1)

            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.55 - Double(index) * 0.16))
                    .frame(width: index == 0 ? 4 : 2.5, height: index == 0 ? 4 : 2.5)
                    .offset(
                        x: 13 + Double(index) * 5 + sin(time * 2.1 + Double(index)) * 1.5,
                        y: -8 - Double(index) * 7 + cos(time * 1.7 + Double(index)) * 2
                    )
                    .opacity(escaping ? 0 : 1)
            }

            Image(systemName: "fish.fill")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, ice, Color(red: 0.12, green: 0.62, blue: 0.76)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .rotationEffect(.degrees(-18 + sin(time * 2.7) * 5))
                .offset(
                    x: escaping ? 0 : sin(time * 2.35) * 5,
                    y: escaping ? -22 : cos(time * 1.9) * 2.2
                )
                .opacity(escaping ? 0 : 1)
                .scaleEffect(escaping ? 0.55 : 1)
        }
    }
}

private struct PolarCatchSplash: View {
    let ice: Color
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(ice.opacity(1 - progress), lineWidth: 2.5)
                .frame(width: 45, height: 20)
                .scaleEffect(0.35 + progress * 1.35)

            Ellipse()
                .stroke(.white.opacity((1 - progress) * 0.72), lineWidth: 1.5)
                .frame(width: 31, height: 13)
                .scaleEffect(0.3 + progress)

            ForEach(0..<7, id: \.self) { index in
                let angle = Double(index) * 360 / 7 - 90
                let radians = angle * .pi / 180
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color.white : ice)
                    .frame(width: 3.5, height: 10)
                    .rotationEffect(.degrees(angle + 90))
                    .offset(
                        x: cos(radians) * (8 + progress * 22),
                        y: sin(radians) * (5 + progress * 19)
                    )
                    .opacity(1 - progress)
            }
        }
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: 0.7)) {
                progress = 1
            }
        }
    }
}

private enum PolarLakeMode {
    case choose
    case place
}

private enum PolarLakeLabelStyle {
    case degrees
    case radians
    case hidden
}

private struct PolarLakeCoordinate: Identifiable, Hashable {
    let r: Double
    let theta: Double
    let label: String

    var id: String { "\(r)-\(theta)-\(label)" }
    var physicalRadius: Double { abs(r) }
    var physicalTheta: Double { normalized(theta + (r < 0 ? 180 : 0)) }

    func isEquivalent(to other: PolarLakeCoordinate, tolerance: Double = 0.08) -> Bool {
        let lhs = cartesian
        let rhs = other.cartesian
        return hypot(lhs.x - rhs.x, lhs.y - rhs.y) <= tolerance
    }

    private var cartesian: (x: Double, y: Double) {
        let radians = physicalTheta * .pi / 180
        return (physicalRadius * cos(radians), physicalRadius * sin(radians))
    }

    private func normalized(_ angle: Double) -> Double {
        let value = angle.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}

private struct PolarLakeChallenge {
    let mode: PolarLakeMode
    let target: PolarLakeCoordinate
    let options: [PolarLakeCoordinate]
}

private struct PolarLakeStage {
    let title: String
    let symbol: String
    let labelStyle: PolarLakeLabelStyle
    let challenges: [PolarLakeChallenge]

    static let all: [PolarLakeStage] = [
        PolarLakeStage(
            title: "DEGREES",
            symbol: "degreesign",
            labelStyle: .degrees,
            challenges: [
                PolarLakeChallenge(
                    mode: .choose,
                    target: PolarLakeCoordinate(r: 3, theta: 60, label: "(3, 60°)"),
                    options: [
                        PolarLakeCoordinate(r: 3, theta: 60, label: "(3, 60°)"),
                        PolarLakeCoordinate(r: 2, theta: 135, label: "(2, 135°)"),
                        PolarLakeCoordinate(r: 4, theta: 300, label: "(4, 300°)")
                    ]
                ),
                PolarLakeChallenge(
                    mode: .choose,
                    target: PolarLakeCoordinate(r: 2, theta: 135, label: "(2, 135°)"),
                    options: [
                        PolarLakeCoordinate(r: 2, theta: 45, label: "(2, 45°)"),
                        PolarLakeCoordinate(r: 3, theta: 135, label: "(3, 135°)"),
                        PolarLakeCoordinate(r: 2, theta: 135, label: "(2, 135°)")
                    ]
                )
            ]
        ),
        PolarLakeStage(
            title: "RADIANS",
            symbol: "compass.drawing",
            labelStyle: .radians,
            challenges: [
                PolarLakeChallenge(
                    mode: .choose,
                    target: PolarLakeCoordinate(r: 4, theta: 300, label: "(4, 5π/3)"),
                    options: [
                        PolarLakeCoordinate(r: 4, theta: 60, label: "(4, π/3)"),
                        PolarLakeCoordinate(r: 4, theta: 300, label: "(4, 5π/3)"),
                        PolarLakeCoordinate(r: 3, theta: 300, label: "(3, 5π/3)")
                    ]
                ),
                PolarLakeChallenge(
                    mode: .choose,
                    target: PolarLakeCoordinate(r: 3, theta: 225, label: "(3, 5π/4)"),
                    options: [
                        PolarLakeCoordinate(r: 3, theta: 225, label: "(3, 5π/4)"),
                        PolarLakeCoordinate(r: -3, theta: 45, label: "(-3, π/4)"),
                        PolarLakeCoordinate(r: 3, theta: 135, label: "(3, 3π/4)")
                    ]
                )
            ]
        ),
        PolarLakeStage(
            title: "PLACE THE FISH",
            symbol: "hand.tap.fill",
            labelStyle: .hidden,
            challenges: [
                PolarLakeChallenge(
                    mode: .place,
                    target: PolarLakeCoordinate(r: 3, theta: -60, label: "(3, -60°)"),
                    options: []
                ),
                PolarLakeChallenge(
                    mode: .place,
                    target: PolarLakeCoordinate(r: -2, theta: 45, label: "(-2, 45°)"),
                    options: []
                )
            ]
        )
    ]
}

#Preview {
    MathItLevelSeventyNineView(onContinue: {}, onLevelSelect: {})
}
