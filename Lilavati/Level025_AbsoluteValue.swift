import SwiftUI

// MARK: - Level 25 - Absolute Value (Shark Hunt)
//
// An ocean cross-section on a vertical number line: 0 sits exactly on the
// water line. Three sharks wait at −6, −3 and −2, each wearing a gray |x|
// badge. A bird flaps across the sky at some height +h — and only the shark
// whose |depth| equals h can reach it. Drop the golden |x| on the right shark
// and it times its leap, bursting out of the water to snatch the bird at the
// apex: |−3| = 3 with teeth. Three birds, three sharks, three absolute values.

@Observable
final class MathItLevelTwentyFiveViewModel {
    let depths: [Int] = [-6, -3, -2]
    let rounds: [Int] = [3, 6, 2]          // bird heights, one per round

    var roundIndex = 0
    var tokenOffset = CGSize.zero
    var jumpingIndex: Int?
    var jumpStart: Date?
    var jumpIsCorrect = false
    var jumpTargetX: CGFloat = 0           // where the shark intercepts the bird
    var birdVisible = true
    var eatIndex: Int?                     // burst + gulp marker
    var eatX: CGFloat = 0
    var wrongIndex: Int?
    var done: Set<Int> = []
    var completed = false

    let jumpDuration: TimeInterval = 2.3
    /// Fraction of the jump at which the shark is at its apex.
    let apexFraction = 0.55

    var birdHeight: Int? {
        guard birdVisible, roundIndex < rounds.count else { return nil }
        return rounds[roundIndex]
    }

    var progress: Double {
        completed ? 1 : Double(done.count) / Double(depths.count)
    }

    func reset() {
        roundIndex = 0
        tokenOffset = .zero
        jumpingIndex = nil
        jumpStart = nil
        jumpIsCorrect = false
        birdVisible = true
        eatIndex = nil
        wrongIndex = nil
        done = []
        completed = false
    }

    /// The token is always draggable — only the drop action is gated.
    func moveToken(_ translation: CGSize) {
        guard !completed else { return }
        tokenOffset = translation
    }

    /// `interceptX` is where the bird will be when this shark's leap peaks —
    /// the shark travels there mid-jump, so no timing is required of the player.
    func dropToken(on index: Int?, interceptX: CGFloat, homeX: CGFloat) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tokenOffset = .zero }
        guard !completed, jumpingIndex == nil else { return }
        guard let index, !done.contains(index) else { return }

        HapticPlayer.playLightTap()
        let correct = abs(depths[index]) == birdHeight

        if correct {
            beginJump(index: index, correct: true, targetX: interceptX)
        } else {
            wrongIndex = index
            beginJump(index: index, correct: false, targetX: homeX)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.wrongIndex = nil
            }
        }
    }

    private func beginJump(index: Int, correct: Bool, targetX: CGFloat) {
        jumpingIndex = index
        jumpIsCorrect = correct
        jumpTargetX = targetX
        jumpStart = Date()

        if correct {
            // The bite, exactly at the apex — where the bird will be.
            DispatchQueue.main.asyncAfter(deadline: .now() + apexFraction * jumpDuration) {
                self.birdVisible = false
                self.eatIndex = index
                self.eatX = targetX
                HapticPlayer.playCompletionTap()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + jumpDuration) {
            self.jumpingIndex = nil
            self.jumpStart = nil
            self.eatIndex = nil

            if correct {
                self.done.insert(index)
                if self.done.count == self.depths.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.spring(response: 0.54, dampingFraction: 0.84)) {
                            self.completed = true
                        }
                    }
                } else {
                    // Next bird flies in.
                    self.roundIndex += 1
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.birdVisible = true
                    }
                }
            }
        }
    }
}

struct MathItLevelTwentyFiveView: View {
    var viewModel: MathItLevelTwentyFiveViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let gold = Color.mathGold
    private let water = Color(red: 0.02, green: 0.28, blue: 0.40)
    private let deepWater = Color(red: 0.01, green: 0.08, blue: 0.14)
    private let cyan = Color(red: 0.36, green: 0.86, blue: 1.0)

    /// Bird flight: left → right, wrapping. Points per second.
    private let birdSpeed: CGFloat = 84

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // The axis spans +8 … −10 edge-to-edge; sea level sits exactly at 0.
            let seaLevel = 132 + (size.height - 150) / 18 * 8
            let axisX = max(58, size.width * 0.18)
            let tokenBase = CGPoint(x: size.width / 2, y: size.height - 92)

            ZStack {
                oceanBackground(seaLevel: seaLevel)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)
                    .zIndex(20)

                ProgressView(value: viewModel.progress)
                    .tint(gold)
                    .frame(width: min(size.width - 58, 380))
                    .position(x: size.width / 2, y: 108)

                axis(x: axisX, seaLevel: seaLevel, size: size)

                // Bird + sharks, all on one clock.
                TimelineView(.animation) { context in
                    let now = context.date
                    let time = CGFloat(now.timeIntervalSinceReferenceDate)

                    ZStack {
                        if let h = viewModel.birdHeight {
                            let bx = birdX(time: time, width: size.width)
                            let by = y(for: h, seaLevel: seaLevel, size: size)
                            birdView(time: time)
                                .position(x: bx, y: by + wave(time * 1.6) * 3)
                            badge("+\(h)")
                                .scaleEffect(0.8)
                                .position(x: bx, y: by - 30)
                        }

                        ForEach(Array(viewModel.depths.enumerated()), id: \.offset) { index, depth in
                            let home = sharkPoint(index: index, depth: depth, seaLevel: seaLevel, size: size)
                            let jumping = viewModel.jumpingIndex == index
                            let t = jumping ? jumpProgress(now) : 0
                            let swim = jumping ? .zero : sharkSwimOffset(index: index, time: time)
                            let pos = jumpPosition(home: home, depth: depth, t: t, seaLevel: seaLevel, size: size)
                            let mouthOpen = jumping && viewModel.jumpIsCorrect && t > 0.40 && t < 0.58

                            if jumping, (0.26...0.40).contains(t) || (0.72...0.86).contains(t) {
                                SplashView(color: cyan)
                                    .position(x: pos.x, y: seaLevel)
                            }

                            sharkView(depth: depth, index: index, time: time, jumping: jumping, mouthOpen: mouthOpen)
                                .rotationEffect(.degrees(jumpTilt(t: t)))
                                .scaleEffect(viewModel.eatIndex == index ? 1.08 : 1)
                                .position(x: pos.x + swim.width, y: pos.y + swim.height)
                        }

                        // Feather burst where the bird was snatched.
                        if let eaten = viewModel.eatIndex {
                            let depth = viewModel.depths[eaten]
                            FeatherBurst(time: time)
                                .position(x: viewModel.eatX, y: y(for: abs(depth), seaLevel: seaLevel, size: size))
                        }
                    }
                }

                absToken
                    .position(x: tokenBase.x + viewModel.tokenOffset.width, y: tokenBase.y + viewModel.tokenOffset.height)
                    .opacity(viewModel.done.count == viewModel.depths.count ? 0 : 1)
                    .gesture(
                        DragGesture(coordinateSpace: .named("absoluteValueStage"))
                            .onChanged { value in
                                viewModel.moveToken(value.translation)
                            }
                            .onEnded { value in
                                let tokenCenter = CGPoint(
                                    x: tokenBase.x + value.translation.width,
                                    y: tokenBase.y + value.translation.height
                                )
                                let index = sharkIndex(at: value.location, tokenCenter: tokenCenter, seaLevel: seaLevel, size: size)
                                // Where the bird will be when the leap peaks.
                                let apexTime = CGFloat(Date().timeIntervalSinceReferenceDate)
                                    + CGFloat(viewModel.apexFraction * viewModel.jumpDuration)
                                let intercept = birdX(time: apexTime, width: size.width)
                                let homeX = index.map {
                                    sharkPoint(index: $0, depth: viewModel.depths[$0], seaLevel: seaLevel, size: size).x
                                } ?? 0
                                viewModel.dropToken(on: index, interceptX: intercept, homeX: homeX)
                            }
                    )
                    .zIndex(30)

                CompletionOverlay(
                    title: "Distance Matched",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(100)
            }
            .coordinateSpace(name: "absoluteValueStage")
            .environment(\.mathItAccent, gold)
        }
    }

    // MARK: - Bird flight & launch timing

    private func birdX(time: CGFloat, width: CGFloat) -> CGFloat {
        let span = width + 160
        return (time * birdSpeed).truncatingRemainder(dividingBy: span) - 80
    }

    // MARK: - Jump choreography

    private func jumpProgress(_ now: Date) -> CGFloat {
        guard let start = viewModel.jumpStart else { return 0 }
        return CGFloat(min(max(now.timeIntervalSince(start) / viewModel.jumpDuration, 0), 1))
    }

    /// depth → surface → leap to +|depth| → splash back down to depth.
    /// Horizontally the shark travels from home to the intercept point by the
    /// apex, hangs there for the bite, then glides back home on the descent.
    private func jumpPosition(home: CGPoint, depth: Int, t: CGFloat, seaLevel: CGFloat, size: CGSize) -> CGPoint {
        guard t > 0 else { return home }
        let surfaceY = y(for: 0, seaLevel: seaLevel, size: size)
        let apexY = y(for: abs(depth), seaLevel: seaLevel, size: size)
        let targetX = viewModel.jumpTargetX

        let x: CGFloat
        if t < 0.55 {
            let s = t / 0.55
            let e = s * s * (3 - 2 * s)
            x = home.x + (targetX - home.x) * e
        } else if t < 0.78 {
            x = targetX
        } else {
            let s = (t - 0.78) / 0.22
            let e = s * s * (3 - 2 * s)
            x = targetX + (home.x - targetX) * e
        }

        if t < 0.32 {
            let s = t / 0.32
            let e = s * s * (3 - 2 * s)
            return CGPoint(x: x, y: home.y + (surfaceY - home.y) * e)
        } else if t < 0.78 {
            let s = (t - 0.32) / 0.46
            let lift = CGFloat(sin(Double(s) * .pi))
            return CGPoint(x: x, y: surfaceY + (apexY - surfaceY) * lift)
        } else {
            let s = (t - 0.78) / 0.22
            let e = s * s * (3 - 2 * s)
            return CGPoint(x: x, y: surfaceY + (home.y - surfaceY) * e)
        }
    }

    private func jumpTilt(t: CGFloat) -> Double {
        guard t > 0 else { return 0 }
        if t < 0.32 { return -24 }
        if t < 0.55 { return -32 }
        if t < 0.78 { return 26 }
        return 10 * Double(1 - (t - 0.78) / 0.22)
    }

    // MARK: - Backdrop

    private func oceanBackground(seaLevel: CGFloat) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let waterHeight = max(0, size.height - seaLevel)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.07, blue: 0.15),
                        Color(red: 0.03, green: 0.16, blue: 0.28),
                        deepWater
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [water.opacity(0.72), deepWater.opacity(0.96)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width, height: waterHeight)
                    .position(x: size.width / 2, y: seaLevel + waterHeight / 2)

                WaveLine()
                    .stroke(cyan.opacity(0.66), lineWidth: 2.2)
                    .frame(width: size.width - 36, height: 22)
                    .position(x: size.width / 2, y: seaLevel)

                ForEach(0..<18, id: \.self) { bubble in
                    Circle()
                        .stroke(cyan.opacity(0.12), lineWidth: 1)
                        .frame(width: CGFloat(4 + bubble % 5), height: CGFloat(4 + bubble % 5))
                        .position(
                            x: CGFloat(34 + (bubble * 47) % max(1, Int(size.width - 30))),
                            y: seaLevel + 34 + CGFloat((bubble * 83) % max(1, Int(max(80, waterHeight - 70))))
                        )
                }

                currentOverlay(seaLevel: seaLevel)
            }
        }
    }

    private func currentOverlay(seaLevel: CGFloat) -> some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                let time = CGFloat(context.date.timeIntervalSinceReferenceDate)
                let width = max(proxy.size.width, 1)
                let height = max(proxy.size.height - seaLevel - 80, 100)
                let drift = (time * 54).truncatingRemainder(dividingBy: width + 180)

                ZStack {
                    ForEach(0..<18, id: \.self) { index in
                        let baseX = CGFloat((index * 83) % Int(width + 180))
                        let y = seaLevel + 28 + CGFloat((index * 37) % Int(height))
                        let x = baseX - drift
                        Capsule()
                            .fill(cyan.opacity(index.isMultiple(of: 3) ? 0.24 : 0.15))
                            .frame(width: CGFloat(52 + (index % 4) * 18), height: 1.4)
                            .position(x: x < -90 ? x + width + 180 : x, y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func axis(x: CGFloat, seaLevel: CGFloat, size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: x, y: 8))
                path.addLine(to: CGPoint(x: x, y: size.height - 8))
            }
            .stroke(.white.opacity(0.76), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            ForEach([-10, -8, -6, -4, -2, 0, 2, 4, 6, 8], id: \.self) { value in
                let tickY = y(for: value, seaLevel: seaLevel, size: size)
                Path { path in
                    path.move(to: CGPoint(x: x - 8, y: tickY))
                    path.addLine(to: CGPoint(x: x + 8, y: tickY))
                }
                .stroke(.white.opacity(value == 0 ? 0.9 : 0.58), lineWidth: value == 0 ? 2 : 1.4)

                Text("\(value)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(value == 0 ? 0.88 : 0.58))
                    .position(x: x - 24, y: tickY)
            }

            Path { path in
                path.move(to: CGPoint(x: 20, y: seaLevel))
                path.addLine(to: CGPoint(x: size.width - 20, y: seaLevel))
            }
            .stroke(cyan.opacity(0.54), style: StrokeStyle(lineWidth: 1.4, dash: [7, 7]))
        }
    }

    // MARK: - Bird

    private func birdView(time: CGFloat) -> some View {
        let flap = wave(time * 11) // fast wingbeat
        return ZStack {
            // Wings — pivot at the shoulder, beating in opposition to each other.
            BirdWing()
                .fill(.black.opacity(0.88))
                .frame(width: 26, height: 16)
                .rotationEffect(.degrees(Double(-18 - flap * 34)), anchor: .bottomTrailing)
                .offset(x: -10, y: -9)
            BirdWing()
                .fill(.black.opacity(0.72))
                .frame(width: 24, height: 14)
                .rotationEffect(.degrees(Double(14 + flap * 30)), anchor: .bottomTrailing)
                .offset(x: -8, y: -3)
            // Body.
            Capsule()
                .fill(.black.opacity(0.9))
                .frame(width: 30, height: 12)
            // Tail.
            LevelTwentyFiveTriangle()
                .fill(.black.opacity(0.85))
                .frame(width: 10, height: 9)
                .rotationEffect(.degrees(-96))
                .offset(x: -18, y: 1)
            // Head + beak.
            Circle()
                .fill(.black.opacity(0.9))
                .frame(width: 10, height: 10)
                .offset(x: 15, y: -4)
            LevelTwentyFiveTriangle()
                .fill(gold.opacity(0.9))
                .frame(width: 7, height: 6)
                .rotationEffect(.degrees(90))
                .offset(x: 22, y: -3)
            // Eye.
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 2.2, height: 2.2)
                .offset(x: 16, y: -5)
        }
        .frame(width: 52, height: 34)
        .shadow(color: .black.opacity(0.5), radius: 4)
    }

    // MARK: - Shark

    private func sharkView(depth: Int, index: Int, time: CGFloat, jumping: Bool, mouthOpen: Bool) -> some View {
        let isDone = viewModel.done.contains(index)
        let isWrong = viewModel.wrongIndex == index
        let tailBeat = jumping ? 0 : wave(time * 4.2 + CGFloat(index)) * 9
        let bodyTop = Color(red: 0.62, green: 0.70, blue: 0.78)
        let bodyBottom = Color(red: 0.34, green: 0.42, blue: 0.52)

        return ZStack {
            // Body.
            Capsule()
                .fill(LinearGradient(colors: [bodyTop, bodyBottom], startPoint: .top, endPoint: .bottom))
                .frame(width: 84, height: 32)
            // Dorsal fin.
            LevelTwentyFiveTriangle()
                .fill(bodyBottom)
                .frame(width: 24, height: 20)
                .offset(x: -4, y: -22)
            // Tail fin.
            LevelTwentyFiveTriangle()
                .fill(bodyBottom)
                .frame(width: 24, height: 26)
                .rotationEffect(Angle.degrees(-90))
                .offset(x: -50)
                .rotationEffect(Angle.degrees(tailBeat), anchor: .center)
            // Belly line.
            Capsule()
                .fill(.white.opacity(0.30))
                .frame(width: 56, height: 7)
                .offset(x: 6, y: 9)

            // Jaw — swings open before the bite.
            if mouthOpen {
                SharkJaw()
                    .fill(Color(red: 0.16, green: 0.05, blue: 0.08))
                    .frame(width: 24, height: 18)
                    .offset(x: 34, y: 4)
                // Teeth.
                ForEach(0..<3, id: \.self) { tooth in
                    LevelTwentyFiveTriangle()
                        .fill(.white)
                        .frame(width: 4, height: 4.5)
                        .rotationEffect(.degrees(180))
                        .offset(x: 28 + CGFloat(tooth) * 6, y: -1)
                }
            }

            // Eye.
            Circle()
                .fill(.black.opacity(0.8))
                .frame(width: 4.5, height: 4.5)
                .offset(x: 30, y: -7)
            // Gills.
            ForEach(0..<3, id: \.self) { g in
                Capsule()
                    .fill(.black.opacity(0.25))
                    .frame(width: 1.6, height: 9)
                    .offset(x: 16 - CGFloat(g) * 5, y: 0)
            }

            // The |x| badge riding on the shark.
            sharkBadge(depth: depth, isDone: isDone, isWrong: isWrong)
                .offset(x: -6)
        }
        .frame(width: 110, height: 60)
        .shadow(color: jumping ? gold.opacity(0.6) : cyan.opacity(0.16), radius: 10)
        .overlay(alignment: .bottom) {
            badge("\(depth)")
                .offset(y: 34)
                .opacity(jumping ? 0 : 1)
        }
    }

    private func sharkBadge(depth: Int, isDone: Bool, isWrong: Bool) -> some View {
        let tone: Color = isDone ? gold : (isWrong ? Color(red: 0.95, green: 0.35, blue: 0.35) : Color(white: 0.78))
        return HStack(spacing: 3) {
            Rectangle().fill(tone).frame(width: 1.8, height: 15)
            Text(isDone ? "\(depth)" : "x")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(tone)
            Rectangle().fill(tone).frame(width: 1.8, height: 15)
            if isDone {
                Text("= \(abs(depth))")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(gold)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(tone.opacity(0.8), lineWidth: 1))
        .offset(y: -1)
    }

    private func sharkSwimOffset(index: Int, time: CGFloat) -> CGSize {
        CGSize(
            width: wave(time * 1.15 + CGFloat(index) * 1.7) * 10,
            height: wave(time * 1.55 + CGFloat(index) * 0.9) * 5
        )
    }

    private var absToken: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(gold, lineWidth: 1.5))
                .shadow(color: gold.opacity(0.25), radius: 12)
            HStack(spacing: 6) {
                Rectangle().fill(.white).frame(width: 2.4, height: 25)
                Text("x")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(cyan)
                Rectangle().fill(.white).frame(width: 2.4, height: 25)
            }
        }
        .frame(width: 62, height: 46)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.64)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Geometry

    private func sharkPoint(index: Int, depth: Int, seaLevel: CGFloat, size: CGSize) -> CGPoint {
        let xs = [size.width * 0.32, size.width * 0.56, size.width * 0.80]
        let x = xs[min(index, xs.count - 1)]
        return CGPoint(x: x, y: y(for: depth, seaLevel: seaLevel, size: size))
    }

    private func sharkIndex(at fingerPoint: CGPoint, tokenCenter: CGPoint, seaLevel: CGFloat, size: CGSize) -> Int? {
        let hitCandidates = viewModel.depths.indices.compactMap { index -> (Int, CGFloat)? in
            let depth = viewModel.depths[index]
            let point = sharkPoint(index: index, depth: depth, seaLevel: seaLevel, size: size)
            let frame = CGRect(x: point.x - 86, y: point.y - 64, width: 172, height: 128)
            guard frame.contains(fingerPoint) || frame.contains(tokenCenter) else { return nil }
            let fingerDistance = hypot(point.x - fingerPoint.x, point.y - fingerPoint.y)
            let tokenDistance = hypot(point.x - tokenCenter.x, point.y - tokenCenter.y)
            return (index, min(fingerDistance, tokenDistance))
        }

        return hitCandidates.min(by: { $0.1 < $1.1 })?.0
    }

    private func wave(_ value: CGFloat) -> CGFloat {
        CGFloat(sin(Double(value)))
    }

    private func y(for value: Int, seaLevel: CGFloat, size: CGSize) -> CGFloat {
        // Matches the seaLevel derivation in body: 18 units across the axis.
        let scale = (size.height - 150) / 18
        return seaLevel - CGFloat(value) * scale
    }
}

// MARK: - Effects & shapes

/// A burst of feathers + a shock ring at the bite point.
private struct FeatherBurst: View {
    let time: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.mathGold.opacity(0.85), lineWidth: 2.6)
                .frame(width: 56, height: 56)
                .scaleEffect(1 + CGFloat(0.35 * (0.5 + 0.5 * sin(Double(time) * 9))))
                .opacity(0.7)
            ForEach(0..<8, id: \.self) { index in
                let a = Double(index) / 8 * 2 * .pi
                let drift = CGFloat(8 + 5 * sin(Double(time) * 7 + Double(index)))
                LevelTwentyFiveTriangle()
                    .fill(index.isMultiple(of: 2) ? Color.black.opacity(0.85) : Color.white.opacity(0.8))
                    .frame(width: 7, height: 9)
                    .rotationEffect(.degrees(Double(index) * 45 + Double(time * 60)))
                    .offset(x: CGFloat(cos(a)) * (22 + drift), y: CGFloat(sin(a)) * (18 + drift))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BirdWing: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2),
                control: CGPoint(x: rect.midX * 0.7, y: rect.minY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.3)
            )
            path.closeSubpath()
        }
    }
}

/// Open lower jaw — a dark wedge cut into the shark's nose.
private struct SharkJaw: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.7, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3),
                control: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY * 0.8)
            )
            path.closeSubpath()
        }
    }
}

private struct WaveLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        let segment: CGFloat = 38
        var x = rect.minX
        while x < rect.maxX {
            path.addQuadCurve(
                to: CGPoint(x: min(x + segment, rect.maxX), y: rect.midY),
                control: CGPoint(x: x + segment / 2, y: rect.midY - 10)
            )
            x += segment
        }
        return path
    }
}

private struct SplashView: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { context in
            let time = CGFloat(context.date.timeIntervalSinceReferenceDate)
            let pulse = 0.75 + 0.25 * CGFloat(sin(Double(time * 8)))

            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    let angle = CGFloat(index - 2) * 0.42
                    Path { path in
                        path.move(to: .zero)
                        path.addQuadCurve(
                            to: CGPoint(x: sin(angle) * 32, y: -24 - CGFloat(index % 2) * 8),
                            control: CGPoint(x: sin(angle) * 20, y: -34)
                        )
                    }
                    .stroke(color.opacity(0.72), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }

                Ellipse()
                    .stroke(color.opacity(0.58), lineWidth: 2)
                    .frame(width: 84 * pulse, height: 18 * pulse)
                    .offset(y: 4)
            }
            .frame(width: 100, height: 70)
        }
        .allowsHitTesting(false)
    }
}

private struct LevelTwentyFiveTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

#Preview {
    MathItLevelTwentyFiveView(
        viewModel: MathItLevelTwentyFiveViewModel(),
        onContinue: {},
        onReplay: {},
        onLevelSelect: {}
    )
}
