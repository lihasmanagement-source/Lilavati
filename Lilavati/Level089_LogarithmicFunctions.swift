import AVFoundation
import Combine
import Darwin
import SwiftUI

struct MathItLevelOneHundredThirtyFiveView: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private let vocalTarget = -2.0
    private let guitarTarget = -4.0
    private let drumTarget = -8.0

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @StateObject private var mixer = ConcertStemMixer()
    @State private var vocalDB = -18.0
    @State private var guitarDB = -2.0
    @State private var drumDB = -16.0
    @State private var holdProgress = 0.0
    @State private var performanceProgress = 0.0
    @State private var finalPerformanceStart: Date?
    @State private var finalPerformanceDuration = 0.0
    @State private var isFinalPerformance = false
    @State private var animationTime = 0.0
    @State private var lastTick = Date()
    @State private var completed = false

    private var isBalanced: Bool {
        abs(vocalDB - vocalTarget) <= 1.25
            && abs(guitarDB - guitarTarget) <= 1.25
            && abs(drumDB - drumTarget) <= 1.25
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.010, green: 0.016, blue: 0.025).ignoresSafeArea()

                VStack(spacing: compact ? 7 : 11) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    concertScene
                        .frame(maxWidth: 900)
                        .frame(height: max(390, min(535, proxy.size.height * 0.64)))

                    compactSoundboard
                        .frame(maxWidth: 760)
                        .frame(height: compact ? 116 : 132)
                        .padding(.bottom, compact ? 7 : 14)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Live Mix Balanced",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear {
            mixer.start(vocalsDB: vocalDB, guitarDB: guitarDB, drumsDB: drumDB)
        }
        .onDisappear {
            mixer.stop()
        }
        .onReceive(timer, perform: updateLevel)
        .onChange(of: vocalDB) { _, value in mixer.setVocals(db: value) }
        .onChange(of: guitarDB) { _, value in mixer.setGuitar(db: value) }
        .onChange(of: drumDB) { _, value in mixer.setDrums(db: value) }
    }

    private var header: some View {
        VStack(spacing: 7) {
            Capsule()
                .fill(completed ? cyan : gold)
                .frame(width: 42, height: 5)

            HStack(spacing: 9) {
                Image(systemName: mixer.isPlaying ? "speaker.wave.3.fill" : "speaker.slash.fill")
                Image(systemName: "waveform")
            }
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(mixer.isPlaying ? gold : coral)

        }
    }

    private var concertScene: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    drawVenue(context: &context, size: size)
                    drawBand(context: &context, size: size)
                    drawCrowd(context: &context, size: size)
                }

                VStack {
                    HStack {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(mixer.isPlaying ? cyan : coral)
                                .frame(width: 7, height: 7)
                            Text(mixer.isPlaying ? "LIVE" : "AUDIO")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(.black.opacity(0.46))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        Text("dB = 20 log₁₀(A / A₀)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(gold.opacity(0.78))
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(.black.opacity(0.46))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()

                    if let errorMessage = mixer.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(coral)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.74))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(10)
            }
            .background(Color(red: 0.025, green: 0.034, blue: 0.052))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(gold.opacity(0.30), lineWidth: 1))
        }
    }

    private var compactSoundboard: some View {
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                CompactConcertFader(
                    symbol: "mic.fill",
                    value: $vocalDB,
                    target: vocalTarget,
                    tint: cyan
                )
                CompactConcertFader(
                    symbol: "guitars.fill",
                    value: $guitarDB,
                    target: guitarTarget,
                    tint: gold
                )
                CompactConcertFader(
                    symbol: "circle.grid.cross.fill",
                    value: $drumDB,
                    target: drumTarget,
                    tint: coral
                )
            }

            VStack(spacing: 7) {
                Image(systemName: isFinalPerformance ? "music.note" : (isBalanced ? "checkmark.circle.fill" : "slider.vertical.3"))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(isFinalPerformance || isBalanced ? cyan : .white.opacity(0.42))

                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        Capsule().fill(.white.opacity(0.09))
                        Capsule()
                            .fill(isFinalPerformance ? cyan : (isBalanced ? cyan : gold.opacity(0.48)))
                            .frame(height: geo.size.height * (isFinalPerformance ? performanceProgress : holdProgress))
                    }
                }
                .frame(width: 7)

                Button(action: resetMix) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .black))
                        .frame(width: 27, height: 27)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(gold)
            }
            .frame(width: 38)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.030, green: 0.042, blue: 0.052))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.11), lineWidth: 1))
        .allowsHitTesting(!isFinalPerformance && !completed)
    }

    private func updateLevel(_ date: Date) {
        let dt = min(0.1, max(0, date.timeIntervalSince(lastTick)))
        lastTick = date
        animationTime += dt
        guard !completed else { return }

        if isFinalPerformance {
            guard let start = finalPerformanceStart else { return }
            performanceProgress = min(
                1,
                max(0, date.timeIntervalSince(start) / max(0.01, finalPerformanceDuration))
            )

            if performanceProgress >= 1 {
                mixer.finishFinalLoop()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                    completed = true
                }
            }
            return
        }

        if isBalanced {
            holdProgress = min(1, holdProgress + dt / 1.35)
        } else {
            holdProgress = max(0, holdProgress - dt / 0.7)
        }

        if holdProgress >= 1 {
            beginFinalPerformance(at: date)
        }
    }

    private func beginFinalPerformance(at date: Date) {
        vocalDB = vocalTarget
        guitarDB = guitarTarget
        drumDB = drumTarget
        performanceProgress = 0

        let startDelay = 0.08
        finalPerformanceDuration = mixer.playFinalLoop(
            vocalsDB: vocalTarget,
            guitarDB: guitarTarget,
            drumsDB: drumTarget,
            startDelay: startDelay
        )
        finalPerformanceStart = date.addingTimeInterval(startDelay)
        isFinalPerformance = true
    }

    private func resetMix() {
        vocalDB = -18
        guitarDB = -2
        drumDB = -16
        holdProgress = 0
        performanceProgress = 0
        finalPerformanceStart = nil
        finalPerformanceDuration = 0
        isFinalPerformance = false
    }

    private func resetLevel() {
        completed = false
        resetMix()
        mixer.start(vocalsDB: -18, guitarDB: -2, drumsDB: -16)
    }

    private func drawVenue(context: inout GraphicsContext, size: CGSize) {
        let stageTop = size.height * 0.14
        let stageBottom = size.height * 0.73
        let stage = CGRect(x: size.width * 0.08, y: stageTop, width: size.width * 0.84, height: stageBottom - stageTop)
        context.fill(Path(roundedRect: stage, cornerRadius: 7), with: .color(Color(red: 0.055, green: 0.060, blue: 0.078)))

        for beamIndex in 0..<5 {
            let x = size.width * (0.18 + CGFloat(beamIndex) * 0.16)
            let lightColor = beamIndex.isMultiple(of: 2) ? cyan : gold
            let sweep = CGFloat(sin(animationTime * 0.85 + Double(beamIndex))) * 24
            var beam = Path()
            beam.move(to: CGPoint(x: x, y: stageTop - 8))
            beam.addLine(to: CGPoint(x: x - 42 + sweep, y: stageBottom))
            beam.addLine(to: CGPoint(x: x + 42 + sweep, y: stageBottom))
            beam.closeSubpath()
            context.fill(beam, with: .color(lightColor.opacity(0.055)))
            context.fill(Path(ellipseIn: CGRect(x: x - 6, y: stageTop - 13, width: 12, height: 12)), with: .color(lightColor.opacity(0.62)))
        }

        var truss = Path()
        truss.move(to: CGPoint(x: stage.minX, y: stageTop))
        truss.addLine(to: CGPoint(x: stage.maxX, y: stageTop))
        context.stroke(truss, with: .color(.white.opacity(0.16)), lineWidth: 3)

        context.fill(
            Path(CGRect(x: stage.minX - 12, y: stageBottom, width: stage.width + 24, height: 13)),
            with: .color(.black.opacity(0.82))
        )

        for sideX in [stage.minX + 10, stage.maxX - 30] {
            let speaker = CGRect(x: sideX, y: stageTop + 42, width: 20, height: stage.height * 0.58)
            context.fill(Path(roundedRect: speaker, cornerRadius: 3), with: .color(.black.opacity(0.78)))
            for driver in 0..<3 {
                let y = speaker.minY + 22 + CGFloat(driver) * 43
                context.fill(Path(ellipseIn: CGRect(x: speaker.midX - 6, y: y - 6, width: 12, height: 12)), with: .color(.white.opacity(0.08)))
            }
        }
    }

    private func drawBand(context: inout GraphicsContext, size: CGSize) {
        let floorY = size.height * 0.73
        let bandScale = min(size.width / 390, size.height / 520)

        drawGuitarist(
            context: &context,
            center: CGPoint(x: size.width * 0.31, y: floorY - 58 * bandScale),
            scale: bandScale,
            phase: animationTime * 4.2
        )
        drawDrummer(
            context: &context,
            center: CGPoint(x: size.width * 0.52, y: floorY - 52 * bandScale),
            scale: bandScale,
            phase: animationTime * 6.0
        )
        drawSinger(
            context: &context,
            center: CGPoint(x: size.width * 0.70, y: floorY - 61 * bandScale),
            scale: bandScale,
            phase: animationTime * 3.0
        )
    }

    private func drawGuitarist(context: inout GraphicsContext, center: CGPoint, scale: CGFloat, phase: Double) {
        let bob = CGFloat(sin(phase * 0.45)) * 2
        let head = CGPoint(x: center.x, y: center.y - 38 * scale + bob)
        context.fill(Path(ellipseIn: CGRect(x: head.x - 8 * scale, y: head.y - 8 * scale, width: 16 * scale, height: 16 * scale)), with: .color(Color(red: 0.78, green: 0.56, blue: 0.42)))
        context.fill(Path(roundedRect: CGRect(x: center.x - 10 * scale, y: center.y - 28 * scale + bob, width: 20 * scale, height: 38 * scale), cornerRadius: 5), with: .color(gold.opacity(0.82)))

        var legs = Path()
        legs.move(to: CGPoint(x: center.x - 5 * scale, y: center.y + 8 * scale))
        legs.addLine(to: CGPoint(x: center.x - 11 * scale, y: center.y + 42 * scale))
        legs.move(to: CGPoint(x: center.x + 5 * scale, y: center.y + 8 * scale))
        legs.addLine(to: CGPoint(x: center.x + 13 * scale, y: center.y + 42 * scale))
        context.stroke(legs, with: .color(.white.opacity(0.68)), style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))

        let guitarCenter = CGPoint(x: center.x + 7 * scale, y: center.y - 3 * scale + bob)
        context.fill(Path(ellipseIn: CGRect(x: guitarCenter.x - 13 * scale, y: guitarCenter.y - 10 * scale, width: 26 * scale, height: 20 * scale)), with: .color(coral.opacity(0.88)))
        var neck = Path()
        neck.move(to: guitarCenter)
        neck.addLine(to: CGPoint(x: center.x + 31 * scale, y: center.y - 20 * scale + bob))
        context.stroke(neck, with: .color(gold), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))

        let strum = CGFloat(sin(phase)) * 7 * scale
        var arm = Path()
        arm.move(to: CGPoint(x: center.x - 7 * scale, y: center.y - 20 * scale + bob))
        arm.addLine(to: CGPoint(x: guitarCenter.x + strum, y: guitarCenter.y))
        context.stroke(arm, with: .color(Color(red: 0.78, green: 0.56, blue: 0.42)), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))
    }

    private func drawDrummer(context: inout GraphicsContext, center: CGPoint, scale: CGFloat, phase: Double) {
        let head = CGPoint(x: center.x, y: center.y - 35 * scale)
        context.fill(Path(ellipseIn: CGRect(x: head.x - 8 * scale, y: head.y - 8 * scale, width: 16 * scale, height: 16 * scale)), with: .color(Color(red: 0.58, green: 0.38, blue: 0.28)))
        context.fill(Path(roundedRect: CGRect(x: center.x - 11 * scale, y: center.y - 25 * scale, width: 22 * scale, height: 30 * scale), cornerRadius: 5), with: .color(cyan.opacity(0.78)))

        context.fill(Path(ellipseIn: CGRect(x: center.x - 22 * scale, y: center.y - 1 * scale, width: 44 * scale, height: 27 * scale)), with: .color(coral.opacity(0.72)))
        context.stroke(Path(ellipseIn: CGRect(x: center.x - 22 * scale, y: center.y - 1 * scale, width: 44 * scale, height: 27 * scale)), with: .color(.white.opacity(0.46)), lineWidth: 2 * scale)
        for side in [-1.0, 1.0] {
            let x = center.x + CGFloat(side) * 29 * scale
            context.fill(Path(ellipseIn: CGRect(x: x - 12 * scale, y: center.y - 9 * scale, width: 24 * scale, height: 13 * scale)), with: .color(gold.opacity(0.70)))
        }

        let strike = CGFloat(abs(sin(phase))) * 15 * scale
        for side in [-1.0, 1.0] {
            var stick = Path()
            stick.move(to: CGPoint(x: center.x + CGFloat(side) * 7 * scale, y: center.y - 18 * scale))
            stick.addLine(to: CGPoint(x: center.x + CGFloat(side) * 24 * scale, y: center.y - 23 * scale + strike))
            context.stroke(stick, with: .color(.white.opacity(0.78)), style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
        }
    }

    private func drawSinger(context: inout GraphicsContext, center: CGPoint, scale: CGFloat, phase: Double) {
        let sway = CGFloat(sin(phase)) * 4 * scale
        let head = CGPoint(x: center.x + sway, y: center.y - 39 * scale)
        context.fill(Path(ellipseIn: CGRect(x: head.x - 8 * scale, y: head.y - 8 * scale, width: 16 * scale, height: 16 * scale)), with: .color(Color(red: 0.70, green: 0.46, blue: 0.32)))
        context.fill(Path(roundedRect: CGRect(x: center.x - 10 * scale + sway, y: center.y - 29 * scale, width: 20 * scale, height: 39 * scale), cornerRadius: 6), with: .color(Color(red: 0.35, green: 0.52, blue: 0.86)))

        var legs = Path()
        legs.move(to: CGPoint(x: center.x - 5 * scale + sway, y: center.y + 8 * scale))
        legs.addLine(to: CGPoint(x: center.x - 8 * scale, y: center.y + 43 * scale))
        legs.move(to: CGPoint(x: center.x + 5 * scale + sway, y: center.y + 8 * scale))
        legs.addLine(to: CGPoint(x: center.x + 10 * scale, y: center.y + 43 * scale))
        context.stroke(legs, with: .color(.white.opacity(0.68)), style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))

        let standX = center.x + 18 * scale
        var stand = Path()
        stand.move(to: CGPoint(x: standX, y: center.y - 28 * scale))
        stand.addLine(to: CGPoint(x: standX, y: center.y + 43 * scale))
        context.stroke(stand, with: .color(.white.opacity(0.48)), lineWidth: 2 * scale)
        context.fill(Path(ellipseIn: CGRect(x: standX - 4 * scale, y: center.y - 34 * scale, width: 8 * scale, height: 12 * scale)), with: .color(coral))

        var arm = Path()
        arm.move(to: CGPoint(x: center.x + 7 * scale + sway, y: center.y - 21 * scale))
        arm.addLine(to: CGPoint(x: standX, y: center.y - 25 * scale))
        context.stroke(arm, with: .color(Color(red: 0.70, green: 0.46, blue: 0.32)), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))
    }

    private func drawCrowd(context: inout GraphicsContext, size: CGSize) {
        let rows = 4
        let columns = 17
        for row in 0..<rows {
            for column in 0..<columns {
                let stagger = row.isMultiple(of: 2) ? CGFloat(0) : size.width / CGFloat(columns * 2)
                let x = CGFloat(column) / CGFloat(columns - 1) * size.width + stagger - 8
                let baseY = size.height * (0.78 + CGFloat(row) * 0.065)
                let seed = Double(row * 37 + column * 11)
                let sway = CGFloat(sin(animationTime * (1.3 + seed.truncatingRemainder(dividingBy: 4) * 0.08) + seed)) * 2.5
                let personScale = CGFloat(0.72 + Double((row + column) % 4) * 0.08)
                let color = row.isMultiple(of: 2) ? Color.black.opacity(0.88) : Color(red: 0.035, green: 0.045, blue: 0.060).opacity(0.94)

                context.fill(Path(ellipseIn: CGRect(x: x - 5 * personScale + sway, y: baseY - 17 * personScale, width: 10 * personScale, height: 10 * personScale)), with: .color(color))
                context.fill(Path(roundedRect: CGRect(x: x - 8 * personScale + sway, y: baseY - 8 * personScale, width: 16 * personScale, height: 23 * personScale), cornerRadius: 5), with: .color(color))

                if (row + column).isMultiple(of: 3) {
                    let lift = CGFloat(8 + (column % 3) * 6)
                    var arms = Path()
                    arms.move(to: CGPoint(x: x - 6 * personScale + sway, y: baseY - 2 * personScale))
                    arms.addLine(to: CGPoint(x: x - 11 * personScale + sway, y: baseY - lift * personScale))
                    arms.move(to: CGPoint(x: x + 6 * personScale + sway, y: baseY - 2 * personScale))
                    arms.addLine(to: CGPoint(x: x + 11 * personScale + sway, y: baseY - (lift + 4) * personScale))
                    context.stroke(arms, with: .color(color), style: StrokeStyle(lineWidth: 4 * personScale, lineCap: .round))
                }
            }
        }
    }
}

private struct CompactConcertFader: View {
    let symbol: String
    @Binding var value: Double
    let target: Double
    let tint: Color

    private let range = -24.0 ... -1.0

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(isNearTarget ? tint : .white.opacity(0.52))
                .frame(width: 22)

            GeometryReader { geo in
                let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let targetProgress = (target - range.lowerBound) / (range.upperBound - range.lowerBound)
                let knobX = geo.size.width * progress
                let targetX = geo.size.width * targetProgress

                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.09)).frame(height: 5)
                    Capsule().fill(tint.opacity(0.52)).frame(width: max(3, knobX), height: 5)
                    Capsule()
                        .fill(tint.opacity(0.55))
                        .frame(width: 3, height: 17)
                        .position(x: targetX, y: geo.size.height / 2)
                    Circle()
                        .fill(isNearTarget ? tint : .white)
                        .frame(width: 19, height: 19)
                        .shadow(color: tint.opacity(isNearTarget ? 0.65 : 0.15), radius: 4)
                        .position(x: knobX, y: geo.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let progress = min(1, max(0, drag.location.x / max(1, geo.size.width)))
                            let rawValue = range.lowerBound + Double(progress) * (range.upperBound - range.lowerBound)
                            value = (rawValue * 2).rounded() / 2
                        }
                )
            }
            .frame(height: 30)

            Text("\(Int(value.rounded()))")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(isNearTarget ? tint : .white.opacity(0.66))
                .frame(width: 27, alignment: .trailing)

            Text("dB")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.28))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(isNearTarget ? tint.opacity(0.08) : .black.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var isNearTarget: Bool {
        abs(value - target) <= 1.25
    }
}

@MainActor
private final class ConcertStemMixer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?

    private let engine = AVAudioEngine()
    private let stemMixer = AVAudioMixerNode()
    private let vocalPlayer = AVAudioPlayerNode()
    private let guitarPlayer = AVAudioPlayerNode()
    private let drumPlayer = AVAudioPlayerNode()
    private var vocalBuffer: AVAudioPCMBuffer?
    private var guitarBuffer: AVAudioPCMBuffer?
    private var drumBuffer: AVAudioPCMBuffer?
    private var isConfigured = false

    func start(vocalsDB: Double, guitarDB: Double, drumsDB: Double) {
        do {
            try configureIfNeeded()
            setVocals(db: vocalsDB)
            setGuitar(db: guitarDB)
            setDrums(db: drumsDB)

            if !engine.isRunning {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
                engine.prepare()
                try engine.start()
            }

            guard let vocalBuffer, let guitarBuffer, let drumBuffer else {
                throw ConcertStemError.assetsUnavailable
            }

            vocalPlayer.stop()
            guitarPlayer.stop()
            drumPlayer.stop()
            vocalPlayer.scheduleBuffer(vocalBuffer, at: nil, options: .loops)
            guitarPlayer.scheduleBuffer(guitarBuffer, at: nil, options: .loops)
            drumPlayer.scheduleBuffer(drumBuffer, at: nil, options: .loops)

            let startHostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.08)
            let startTime = AVAudioTime(hostTime: startHostTime)
            vocalPlayer.play(at: startTime)
            guitarPlayer.play(at: startTime)
            drumPlayer.play(at: startTime)
            isPlaying = true
            errorMessage = nil
        } catch {
            isPlaying = false
            errorMessage = "AUDIO UNAVAILABLE"
        }
    }

    func setVocals(db: Double) {
        vocalPlayer.volume = amplitude(for: db)
    }

    func setGuitar(db: Double) {
        guitarPlayer.volume = amplitude(for: db)
    }

    func setDrums(db: Double) {
        drumPlayer.volume = amplitude(for: db)
    }

    @discardableResult
    func playFinalLoop(
        vocalsDB: Double,
        guitarDB: Double,
        drumsDB: Double,
        startDelay: TimeInterval
    ) -> TimeInterval {
        do {
            try configureIfNeeded()
            setVocals(db: vocalsDB)
            setGuitar(db: guitarDB)
            setDrums(db: drumsDB)

            if !engine.isRunning {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
                engine.prepare()
                try engine.start()
            }

            guard let vocalBuffer, let guitarBuffer, let drumBuffer else {
                throw ConcertStemError.assetsUnavailable
            }

            vocalPlayer.stop()
            guitarPlayer.stop()
            drumPlayer.stop()
            vocalPlayer.scheduleBuffer(vocalBuffer)
            guitarPlayer.scheduleBuffer(guitarBuffer)
            drumPlayer.scheduleBuffer(drumBuffer)

            let startHostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: startDelay)
            let startTime = AVAudioTime(hostTime: startHostTime)
            vocalPlayer.play(at: startTime)
            guitarPlayer.play(at: startTime)
            drumPlayer.play(at: startTime)
            isPlaying = true
            errorMessage = nil

            return Double(vocalBuffer.frameLength) / vocalBuffer.format.sampleRate
        } catch {
            isPlaying = false
            errorMessage = "AUDIO UNAVAILABLE"
            return 0.01
        }
    }

    func finishFinalLoop() {
        vocalPlayer.stop()
        guitarPlayer.stop()
        drumPlayer.stop()
        isPlaying = false
    }

    func stop() {
        vocalPlayer.stop()
        guitarPlayer.stop()
        drumPlayer.stop()
        engine.stop()
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        vocalBuffer = try loadBuffer(named: "ConcertVocalsLoop")
        guitarBuffer = try loadBuffer(named: "ConcertGuitarLoop")
        drumBuffer = try loadBuffer(named: "ConcertDrumsLoop")

        guard let format = vocalBuffer?.format,
              guitarBuffer?.format.sampleRate == format.sampleRate,
              drumBuffer?.format.sampleRate == format.sampleRate else {
            throw ConcertStemError.incompatibleAssets
        }

        engine.attach(vocalPlayer)
        engine.attach(guitarPlayer)
        engine.attach(drumPlayer)
        engine.attach(stemMixer)
        engine.connect(vocalPlayer, to: stemMixer, format: format)
        engine.connect(guitarPlayer, to: stemMixer, format: format)
        engine.connect(drumPlayer, to: stemMixer, format: format)
        engine.connect(stemMixer, to: engine.mainMixerNode, format: format)

        stemMixer.outputVolume = 0.92
        engine.mainMixerNode.outputVolume = 0.95
        isConfigured = true
    }

    private func loadBuffer(named name: String) throws -> AVAudioPCMBuffer {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            throw ConcertStemError.assetsUnavailable
        }
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw ConcertStemError.assetsUnavailable
        }
        try file.read(into: buffer)
        return buffer
    }

    private func amplitude(for decibels: Double) -> Float {
        Float(pow(10, decibels / 20))
    }
}

private enum ConcertStemError: Error {
    case assetsUnavailable
    case incompatibleAssets
}

#Preview {
    MathItLevelOneHundredThirtyFiveView(onContinue: {}, onLevelSelect: {})
}
