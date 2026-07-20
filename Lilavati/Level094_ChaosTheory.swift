import SwiftUI
import AVFoundation

struct MathItLevelOneHundredFortyView: View {
    private let cyan = Color(red: 0.20, green: 0.86, blue: 0.91)
    private let gold = Color(red: 1.0, green: 0.72, blue: 0.18)
    private let coral = Color(red: 0.97, green: 0.35, blue: 0.29)
    private let runDuration = 8.0

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var launchAngle = 135.0
    @State private var gravity = 9.81
    @State private var jointFriction = 0.04
    @State private var engine = SingleDoublePendulumEngine()
    @State private var notePlayer = PendulumNotePlayer()
    @State private var running = false
    @State private var completed = false
    @State private var showFinishedRun = false
    @State private var animationToken = UUID()

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.012, green: 0.021, blue: 0.033).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 12) {
                    Spacer().frame(height: compact ? 78 : 92)

                    parameterStrip

                    pendulumLab
                        .frame(maxWidth: 920)
                        .frame(height: max(410, min(555, proxy.size.height * 0.63)))

                    controls(compact: compact)
                        .frame(maxWidth: 820)

                    Spacer(minLength: compact ? 64 : 76)
                }
                .padding(.horizontal, compact ? 12 : 18)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Chaotic Motion Observed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(100)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onAppear { configurePreview() }
        .onDisappear {
            engine.stop()
            notePlayer.stop()
        }
    }

    private var parameterStrip: some View {
        HStack(spacing: 10) {
            parameterPill("angle", "θ₀", "\(number(launchAngle))°", gold)
            parameterPill("arrow.down", "g", "\(number(gravity)) m/s²", cyan)
            parameterPill("circle.dotted", "c", number(jointFriction), coral)
        }
        .frame(maxWidth: 620)
    }

    private func parameterPill(_ symbol: String, _ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(label)
                .opacity(0.52)
            Text(value)
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(color.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.23), lineWidth: 1))
    }

    private var pendulumLab: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let _ = engine.advance(to: timeline.date)
                let _ = playPendingNotes()

                Canvas { context, size in
                    drawChamber(context: &context, size: size)
                    drawTrail(context: &context, size: size)
                    drawLaunchAngle(context: &context, size: size)
                    drawPendulum(context: &context, size: size)
                }
                .overlay(alignment: .topLeading) {
                    liveReadouts
                        .padding(12)
                }
                .overlay(alignment: .bottom) {
                    if showFinishedRun {
                        Label("RUN COMPLETE", systemImage: "checkmark")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(cyan, in: Capsule())
                            .padding(.bottom, 12)
                    }
                }
            }
            .background(
                RadialGradient(
                    colors: [
                        Color(red: 0.075, green: 0.105, blue: 0.14),
                        Color(red: 0.025, green: 0.035, blue: 0.052)
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 460
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.mathGold.opacity(0.25), lineWidth: 1))
        }
    }

    private var liveReadouts: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
                liveMetric("clock", "\(number(engine.elapsed)) s")
                liveMetric("music.note", engine.currentNoteName)
                liveMetric("speedometer", "\(number(engine.angularSpeed)) rad/s")
                liveMetric("bolt.fill", "\(number(engine.energy)) J")
            }

            ProgressView(value: min(1, engine.elapsed / runDuration))
                .tint(running ? gold : cyan)
                .frame(width: 190)
        }
        .padding(9)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 5))
    }

    private func liveMetric(_ symbol: String, _ value: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.74))
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            controlSlider(
                symbol: "angle",
                value: $launchAngle,
                range: 20...175,
                step: 5,
                color: gold,
                valueText: "\(number(launchAngle))°"
            )

            controlSlider(
                symbol: "arrow.down",
                value: $gravity,
                range: 1.6...15,
                step: 0.1,
                color: cyan,
                valueText: "\(number(gravity)) m/s²"
            )

            controlSlider(
                symbol: "circle.dotted",
                value: $jointFriction,
                range: 0...0.35,
                step: 0.01,
                color: coral,
                valueText: number(jointFriction)
            )

            HStack(spacing: 10) {
                Button(action: resetRun) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 54, height: compact ? 40 : 46)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: releasePendulum) {
                    Image(systemName: running ? "waveform.path.ecg" : "play.fill")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: compact ? 40 : 46)
                        .background(running ? .white.opacity(0.18) : gold, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(running)
                .accessibilityLabel("Release double pendulum")
            }
        }
    }

    private func controlSlider(
        symbol: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        color: Color,
        valueText: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(color)
                .frame(width: 24)

            Slider(value: value, in: range, step: step)
                .tint(color)
                .disabled(running)
                .onChange(of: value.wrappedValue) { _, _ in configurePreview() }

            Text(valueText)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 82, alignment: .trailing)
        }
    }

    private func releasePendulum() {
        guard !running else { return }
        animationToken = UUID()
        let token = animationToken
        running = true
        showFinishedRun = false
        completed = false
        notePlayer.silence()
        notePlayer.prepare()
        HapticPlayer.playLightTap()

        engine.start(
            launchDegrees: launchAngle,
            gravity: gravity,
            jointFriction: jointFriction,
            duration: runDuration
        ) {
            DispatchQueue.main.async {
                guard token == animationToken else { return }
                running = false
                showFinishedRun = true
                HapticPlayer.playCompletionTap()

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    guard token == animationToken else { return }
                    withAnimation(.easeInOut(duration: 0.4)) { completed = true }
                }
            }
        }
    }

    private func configurePreview() {
        guard !running else { return }
        showFinishedRun = false
        engine.configurePreview(launchDegrees: launchAngle, gravity: gravity, jointFriction: jointFriction)
    }

    private func resetRun() {
        animationToken = UUID()
        running = false
        showFinishedRun = false
        completed = false
        engine.stop()
        notePlayer.silence()
        configurePreview()
    }

    private func playPendingNotes() -> Bool {
        let events = engine.consumeNoteEvents()
        guard !events.isEmpty else { return false }
        for event in events {
            notePlayer.play(noteIndex: event.noteIndex, intensity: event.intensity, pan: event.pan)
        }
        return true
    }

    private func resetLevel() {
        launchAngle = 135
        gravity = 9.81
        jointFriction = 0.04
        resetRun()
    }

    private func drawChamber(context: inout GraphicsContext, size: CGSize) {
        for x in stride(from: CGFloat(24), through: size.width - 24, by: 42) {
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(.white.opacity(0.025)), lineWidth: 1)
        }

        for y in stride(from: CGFloat(28), through: size.height - 20, by: 42) {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(.white.opacity(0.025)), lineWidth: 1)
        }

        let pivot = screenPoint(engine.points.pivot, size: size)
        var support = Path()
        support.move(to: CGPoint(x: pivot.x - 72, y: pivot.y - 12))
        support.addLine(to: CGPoint(x: pivot.x + 72, y: pivot.y - 12))
        context.stroke(support, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        for offset in stride(from: CGFloat(-60), through: 60, by: 20) {
            var hatch = Path()
            hatch.move(to: CGPoint(x: pivot.x + offset - 5, y: pivot.y - 18))
            hatch.addLine(to: CGPoint(x: pivot.x + offset + 5, y: pivot.y - 6))
            context.stroke(hatch, with: .color(.black.opacity(0.35)), lineWidth: 2)
        }
    }

    private func drawTrail(context: inout GraphicsContext, size: CGSize) {
        guard engine.trail.count > 1 else { return }

        let visibleStart = max(0, engine.trail.count - 300)
        var trail = Path()
        trail.move(to: screenPoint(engine.trail[visibleStart], size: size))

        for point in engine.trail.dropFirst(visibleStart + 1) {
            trail.addLine(to: screenPoint(point, size: size))
        }

        context.stroke(
            trail,
            with: .color(cyan.opacity(0.42)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawLaunchAngle(context: inout GraphicsContext, size: CGSize) {
        guard !running, engine.elapsed == 0 else { return }
        let pivot = screenPoint(engine.points.pivot, size: size)
        let arcRadius: CGFloat = 35

        var vertical = Path()
        vertical.move(to: pivot)
        vertical.addLine(to: CGPoint(x: pivot.x, y: pivot.y + 58))
        context.stroke(vertical, with: .color(.white.opacity(0.20)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        var arc = Path()
        arc.addArc(
            center: pivot,
            radius: arcRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(90 - launchAngle),
            clockwise: true
        )
        context.stroke(arc, with: .color(gold.opacity(0.8)), lineWidth: 2)

        let labelAngle = (90 - launchAngle / 2) * .pi / 180
        let labelPoint = CGPoint(
            x: pivot.x + cos(labelAngle) * (arcRadius + 13),
            y: pivot.y + sin(labelAngle) * (arcRadius + 13)
        )
        context.draw(
            Text("θ₀")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(gold),
            at: labelPoint
        )
    }

    private func drawPendulum(context: inout GraphicsContext, size: CGSize) {
        let pivot = screenPoint(engine.points.pivot, size: size)
        let middle = screenPoint(engine.points.middle, size: size)
        let end = screenPoint(engine.points.end, size: size)

        var rods = Path()
        rods.move(to: pivot)
        rods.addLine(to: middle)
        rods.addLine(to: end)
        context.stroke(rods, with: .color(.white.opacity(0.88)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

        context.fill(Path(ellipseIn: CGRect(x: pivot.x - 7, y: pivot.y - 7, width: 14, height: 14)), with: .color(gold))
        context.fill(Path(ellipseIn: CGRect(x: middle.x - 10, y: middle.y - 10, width: 20, height: 20)), with: .color(coral))
        context.stroke(
            Path(ellipseIn: CGRect(x: middle.x - 14, y: middle.y - 14, width: 28, height: 28)),
            with: .color(coral.opacity(0.28 + jointFriction * 1.7)),
            lineWidth: 3
        )
        context.fill(Path(ellipseIn: CGRect(x: end.x - 13, y: end.y - 13, width: 26, height: 26)), with: .radialGradient(
            Gradient(colors: [cyan, Color(red: 0.08, green: 0.34, blue: 0.39)]),
            center: CGPoint(x: end.x - 4, y: end.y - 5),
            startRadius: 1,
            endRadius: 18
        ))
        context.stroke(Path(ellipseIn: CGRect(x: end.x - 16, y: end.y - 16, width: 32, height: 32)), with: .color(.white.opacity(0.32)), lineWidth: 1)
    }

    private func screenPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        let scale = min(size.width * 0.20, size.height * 0.205)
        return CGPoint(
            x: size.width * 0.5 + point.x * scale,
            y: size.height * 0.15 + point.y * scale
        )
    }

    private func number(_ value: Double) -> String {
        let clean = abs(value) < 0.005 ? 0 : value
        return abs(clean.rounded() - clean) < 0.005
            ? String(Int(clean.rounded()))
            : String(format: "%.2f", clean)
    }
}

private struct SinglePendulumState {
    var theta1: Double
    var theta2: Double
    var omega1: Double
    var omega2: Double
}

private struct SinglePendulumDerivative {
    let theta1: Double
    let theta2: Double
    let omega1: Double
    let omega2: Double
}

private struct SinglePendulumPoints {
    let pivot: CGPoint
    let middle: CGPoint
    let end: CGPoint
}

private struct PendulumNoteEvent {
    let noteIndex: Int
    let intensity: Double
    let pan: Double
}

private final class SingleDoublePendulumEngine {
    private var state = SinglePendulumState(theta1: 0, theta2: 0, omega1: 0, omega2: 0)
    private var gravity = 9.81
    private var jointFriction = 0.04
    private var duration = 8.0
    private var lastDate: Date?
    private var completion: (() -> Void)?
    private var lastTrailTime = 0.0
    private var pendingNoteEvents: [PendulumNoteEvent] = []
    private var lastNoteIndex = -1
    private var lastNoteTime = -1.0
    private var previousEndX = 0.0
    private var previousHorizontalDirection = 0

    var points = SinglePendulumPoints(pivot: .zero, middle: .zero, end: .zero)
    var trail: [CGPoint] = []
    var elapsed = 0.0
    var angularSpeed = 0.0
    var energy = 0.0
    var currentNoteName = "—"
    var running = false

    private static let noteNames = ["C4", "D4", "E4", "G4", "A4", "C5", "E5"]

    func configurePreview(launchDegrees: Double, gravity: Double, jointFriction: Double) {
        let launch = launchDegrees * .pi / 180
        state = SinglePendulumState(
            theta1: launch,
            theta2: -launch * 0.52,
            omega1: 0,
            omega2: 0
        )
        self.gravity = gravity
        self.jointFriction = jointFriction
        resetReadouts()
        updateGeometry()
        previousEndX = points.end.x
    }

    func start(
        launchDegrees: Double,
        gravity: Double,
        jointFriction: Double,
        duration: Double,
        completion: @escaping () -> Void
    ) {
        configurePreview(launchDegrees: launchDegrees, gravity: gravity, jointFriction: jointFriction)
        self.duration = duration
        self.completion = completion
        running = true
        lastDate = nil
    }

    func stop() {
        running = false
        completion = nil
        lastDate = nil
    }

    @discardableResult
    func advance(to date: Date) -> Bool {
        guard running else { return false }
        guard let previous = lastDate else {
            lastDate = date
            return false
        }

        let frameTime = min(0.04, max(0, date.timeIntervalSince(previous)))
        lastDate = date
        var remaining = min(frameTime, max(0, duration - elapsed))
        let fixedStep = 1.0 / 240.0

        while remaining > 0.000001 {
            let step = min(fixedStep, remaining)
            state = rk4(state, dt: step)
            elapsed += step
            remaining -= step
        }

        updateGeometry()
        detectMusicalEvent()

        if elapsed - lastTrailTime >= 1.0 / 45.0 {
            trail.append(points.end)
            if trail.count > 360 { trail.removeFirst(trail.count - 360) }
            lastTrailTime = elapsed
        }

        guard elapsed >= duration - 0.0001 else { return false }
        running = false
        let callback = completion
        completion = nil
        callback?()
        return true
    }

    private func resetReadouts() {
        elapsed = 0
        angularSpeed = 0
        trail = []
        lastTrailTime = 0
        lastDate = nil
        energy = mechanicalEnergy(state)
        pendingNoteEvents = []
        lastNoteIndex = -1
        lastNoteTime = -1
        previousHorizontalDirection = 0
        currentNoteName = "—"
    }

    func consumeNoteEvents() -> [PendulumNoteEvent] {
        let events = pendingNoteEvents
        pendingNoteEvents.removeAll(keepingCapacity: true)
        return events
    }

    private func detectMusicalEvent() {
        let normalizedHeight = max(0, min(1, (2 - points.end.y) / 4))
        let noteIndex = max(0, min(Self.noteNames.count - 1, Int((normalizedHeight * 6).rounded())))
        let horizontalDelta = points.end.x - previousEndX
        let direction = abs(horizontalDelta) < 0.0015 ? 0 : (horizontalDelta > 0 ? 1 : -1)
        let changedBand = noteIndex != lastNoteIndex
        let turned = direction != 0 && previousHorizontalDirection != 0 && direction != previousHorizontalDirection
        let enoughTimeForBand = elapsed - lastNoteTime >= 0.10
        let enoughTimeForTurn = elapsed - lastNoteTime >= 0.16

        if angularSpeed > 0.22, (changedBand && enoughTimeForBand) || (turned && enoughTimeForTurn) {
            let speedAmount = max(0, min(1, angularSpeed / 8))
            pendingNoteEvents.append(
                PendulumNoteEvent(
                    noteIndex: noteIndex,
                    intensity: 0.30 + speedAmount * 0.70,
                    pan: max(-1, min(1, points.end.x / 2))
                )
            )
            if pendingNoteEvents.count > 8 {
                pendingNoteEvents.removeFirst(pendingNoteEvents.count - 8)
            }
            lastNoteIndex = noteIndex
            lastNoteTime = elapsed
            currentNoteName = Self.noteNames[noteIndex]
        }

        if direction != 0 {
            previousHorizontalDirection = direction
        }
        previousEndX = points.end.x
    }

    private func rk4(_ state: SinglePendulumState, dt: Double) -> SinglePendulumState {
        let k1 = derivative(state)
        let k2 = derivative(adding(state, k1, scale: dt / 2))
        let k3 = derivative(adding(state, k2, scale: dt / 2))
        let k4 = derivative(adding(state, k3, scale: dt))

        return SinglePendulumState(
            theta1: state.theta1 + dt / 6 * (k1.theta1 + 2 * k2.theta1 + 2 * k3.theta1 + k4.theta1),
            theta2: state.theta2 + dt / 6 * (k1.theta2 + 2 * k2.theta2 + 2 * k3.theta2 + k4.theta2),
            omega1: state.omega1 + dt / 6 * (k1.omega1 + 2 * k2.omega1 + 2 * k3.omega1 + k4.omega1),
            omega2: state.omega2 + dt / 6 * (k1.omega2 + 2 * k2.omega2 + 2 * k3.omega2 + k4.omega2)
        )
    }

    private func adding(
        _ state: SinglePendulumState,
        _ derivative: SinglePendulumDerivative,
        scale: Double
    ) -> SinglePendulumState {
        SinglePendulumState(
            theta1: state.theta1 + derivative.theta1 * scale,
            theta2: state.theta2 + derivative.theta2 * scale,
            omega1: state.omega1 + derivative.omega1 * scale,
            omega2: state.omega2 + derivative.omega2 * scale
        )
    }

    private func derivative(_ state: SinglePendulumState) -> SinglePendulumDerivative {
        let mass1 = 1.0
        let mass2 = 1.0
        let length1 = 1.0
        let length2 = 1.0
        let difference = state.theta1 - state.theta2
        let shared = 2 * mass1 + mass2 - mass2 * cos(2 * difference)

        let numerator1 =
            -gravity * (2 * mass1 + mass2) * sin(state.theta1)
            - mass2 * gravity * sin(state.theta1 - 2 * state.theta2)
            - 2 * sin(difference) * mass2
                * (
                    state.omega2 * state.omega2 * length2
                    + state.omega1 * state.omega1 * length1 * cos(difference)
                )
        var acceleration1 = numerator1 / (length1 * shared)

        let numerator2 = 2 * sin(difference) * (
            state.omega1 * state.omega1 * length1 * (mass1 + mass2)
            + gravity * (mass1 + mass2) * cos(state.theta1)
            + state.omega2 * state.omega2 * length2 * mass2 * cos(difference)
        )
        var acceleration2 = numerator2 / (length2 * shared)

        let relativeVelocity = state.omega2 - state.omega1
        let torque1 = jointFriction * relativeVelocity
        let torque2 = -torque1
        let coupling = cos(difference)
        let massDeterminant = 2 - coupling * coupling
        acceleration1 += (torque1 - coupling * torque2) / massDeterminant
        acceleration2 += (-coupling * torque1 + 2 * torque2) / massDeterminant

        return SinglePendulumDerivative(
            theta1: state.omega1,
            theta2: state.omega2,
            omega1: acceleration1,
            omega2: acceleration2
        )
    }

    private func updateGeometry() {
        let pivot = CGPoint.zero
        let middle = CGPoint(x: sin(state.theta1), y: cos(state.theta1))
        let end = CGPoint(
            x: middle.x + sin(state.theta2),
            y: middle.y + cos(state.theta2)
        )
        points = SinglePendulumPoints(pivot: pivot, middle: middle, end: end)
        angularSpeed = hypot(state.omega1, state.omega2)
        energy = mechanicalEnergy(state)
    }

    private func mechanicalEnergy(_ state: SinglePendulumState) -> Double {
        let kinetic =
            0.5 * state.omega1 * state.omega1
            + 0.5 * (
                state.omega1 * state.omega1
                + state.omega2 * state.omega2
                + 2 * state.omega1 * state.omega2 * cos(state.theta1 - state.theta2)
            )
        let potential =
            2 * gravity * (1 - cos(state.theta1))
            + gravity * (1 - cos(state.theta2))
        return max(0, kinetic + potential)
    }

    private func wrappedAngle(_ angle: Double) -> Double {
        atan2(sin(angle), cos(angle))
    }
}

private final class PendulumNotePlayer {
    private struct Voice {
        var frequency: Double
        var phase: Double = 0
        var amplitude: Double
        var decay: Double
        var pan: Double
        var age = 0
        var brightness: Double
    }

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let lock = NSLock()
    private var voices: [Voice] = []
    private var sourceNode: AVAudioSourceNode?
    private var engineRunning = false

    private static let frequencies = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 659.25]

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

            self.lock.lock()
            for frame in 0..<Int(frameCount) {
                var left = 0.0
                var right = 0.0

                for index in self.voices.indices {
                    var voice = self.voices[index]
                    let attack = min(1, Double(voice.age) / 110)
                    let tone =
                        sin(voice.phase) * 0.72
                        + sin(voice.phase * 2) * voice.brightness
                        + sin(voice.phase * 3) * 0.055
                    let sample = tone * voice.amplitude * attack
                    let leftGain = sqrt((1 - voice.pan) * 0.5)
                    let rightGain = sqrt((1 + voice.pan) * 0.5)
                    left += sample * leftGain
                    right += sample * rightGain

                    voice.phase += 2 * .pi * voice.frequency / self.sampleRate
                    if voice.phase > 2 * .pi { voice.phase -= 2 * .pi }
                    voice.amplitude *= voice.decay
                    voice.age += 1
                    self.voices[index] = voice
                }

                let leftSample = Float(tanh(left * 0.82))
                let rightSample = Float(tanh(right * 0.82))
                if buffers.count >= 2 {
                    buffers[0].mData?.assumingMemoryBound(to: Float.self)[frame] = leftSample
                    buffers[1].mData?.assumingMemoryBound(to: Float.self)[frame] = rightSample
                } else if let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) {
                    data[frame * 2] = leftSample
                    data[frame * 2 + 1] = rightSample
                }
            }
            self.voices.removeAll { $0.amplitude < 0.00015 }
            self.lock.unlock()
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }

    func play(noteIndex: Int, intensity: Double, pan: Double) {
        startIfNeeded()
        let safeIndex = max(0, min(Self.frequencies.count - 1, noteIndex))
        let strength = max(0, min(1, intensity))
        let decaySeconds = 0.34 + strength * 0.32
        let decay = pow(0.001, 1 / (decaySeconds * sampleRate))

        lock.lock()
        voices.append(
            Voice(
                frequency: Self.frequencies[safeIndex],
                amplitude: 0.045 + strength * 0.055,
                decay: decay,
                pan: max(-0.86, min(0.86, pan)),
                brightness: 0.10 + strength * 0.11
            )
        )
        if voices.count > 12 {
            voices.removeFirst(voices.count - 12)
        }
        lock.unlock()
    }

    func silence() {
        lock.lock()
        voices.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    func prepare() {
        startIfNeeded()
    }

    func stop() {
        silence()
        engine.stop()
        engineRunning = false
    }

    private func startIfNeeded() {
        guard !engineRunning || !engine.isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        do {
            try engine.start()
            engineRunning = true
        } catch {
            engineRunning = false
        }
    }
}

#Preview {
    MathItLevelOneHundredFortyView(onContinue: {}, onLevelSelect: {})
}
