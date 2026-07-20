import SwiftUI
import Combine
import AVFoundation

struct MathItBuiltConceptLevelView: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var selectedSteps: [String] = []
    @State private var completed = false
    @State private var wrongPulse = false

    private var challenge: BuiltConceptChallenge {
        BuiltConceptChallenge(concept: concept)
    }

    var body: some View {
        if concept.number == 62 {
            MathItBattleshipGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 63 {
            MathItScaleCityGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 64 {
            MathItPackingSpaceGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 65 {
            MathItTempoEngineGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 66 {
            MathItPhaseShiftGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 67 {
            MathItEQEnvelopeGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 68 {
            MathItPendulumLaunchGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 69 {
            MathItUpdraftGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 70 {
            MathItChordDetectiveGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 71 {
            MathItEchoCanyonGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 72 {
            MathItRipplePondGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 73 {
            MathItDopplerDashGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if concept.number == 74 {
            MathItFifthsMemoryGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if (76...100).contains(concept.number) {
            MathItSystemsLevelView(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else if (66...100).contains(concept.number) {
            MathItGeneratedMiniGame(
                concept: concept,
                onContinue: onContinue,
                onLevelSelect: onLevelSelect
            )
        } else {
            GeometryReader { proxy in
                ZStack {
                    Color.black.ignoresSafeArea()

                    HomeButton(action: onLevelSelect)
                        .position(x: 34, y: 54)

                    VStack(spacing: 15) {
                        header

                        ProgressView(value: completed ? 1 : Double(selectedSteps.count) / Double(challenge.solution.count))
                            .tint(accent)
                            .opacity(0.72)
                            .padding(.horizontal, 34)

                        conceptStage
                            .frame(height: min(270, proxy.size.height * 0.34))
                            .padding(.horizontal, 20)

                        stepSlots
                        actionGrid

                        if wrongPulse {
                            Text("That piece belongs later in the build.")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.68))
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 38)
                    .padding(.bottom, 24)

                    CompletionOverlay(
                        title: "Level \(concept.number) Completed",
                        isVisible: completed,
                        onContinue: onContinue,
                        onReplay: replay,
                        onLevelSelect: onLevelSelect
                    )
                    .zIndex(20)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.58))

            EmptyView()
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(completed ? 1 : 0.42))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 54)
    }

    private var stepSlots: some View {
        HStack(spacing: 9) {
            ForEach(0..<challenge.solution.count, id: \.self) { index in
                Text(index < selectedSteps.count ? selectedSteps[index] : "\(index + 1)")
                    .font(.system(size: index < selectedSteps.count ? 10 : 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(index < selectedSteps.count ? .black : accent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(index < selectedSteps.count ? accent : .black.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.48), lineWidth: 1.1))
            }
        }
        .padding(.horizontal, 22)
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
            ForEach(challenge.options, id: \.self) { option in
                Button {
                    choose(option)
                } label: {
                    Text(option)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(optionForeground(option))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(optionBackground(option), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(optionStroke(option), lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .disabled(completed || selectedSteps.contains(option))
            }
        }
        .padding(.horizontal, 22)
        .scaleEffect(wrongPulse ? 0.985 : 1)
    }

    private var conceptStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(accent.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.36), lineWidth: 1.2))

            BuiltConceptVisual(visual: concept.visual)
                .padding(26)

            VStack {
                Spacer()
                HStack {
                    Text(challenge.readout)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(accent, in: Capsule())
                    Spacer()
                }
                .padding(14)
            }
        }
    }

    private func choose(_ option: String) {
        guard !completed else { return }
        let next = challenge.solution[selectedSteps.count]
        if option == next {
            selectedSteps.append(option)
            HapticPlayer.playLightTap()
            if selectedSteps.count == challenge.solution.count {
                HapticPlayer.playCompletionTap()
                withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                    completed = true
                }
            }
        } else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                wrongPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
                    wrongPulse = false
                }
            }
        }
    }

    private func replay() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            selectedSteps = []
            completed = false
            wrongPulse = false
        }
    }

    private func optionForeground(_ option: String) -> Color {
        selectedSteps.contains(option) ? .black : .white
    }

    private func optionBackground(_ option: String) -> Color {
        selectedSteps.contains(option) ? accent : .black.opacity(0.86)
    }

    private func optionStroke(_ option: String) -> Color {
        selectedSteps.contains(option) ? accent : accent.opacity(0.36)
    }
}

private struct BuiltConceptChallenge {
    let solution: [String]
    let options: [String]
    let readout: String

    init(concept: MathItConceptDefinition) {
        let actions = BuiltConceptChallenge.actions(for: concept)
        solution = actions.solution
        options = actions.options
        readout = actions.readout
    }

    private static func actions(for concept: MathItConceptDefinition) -> (solution: [String], options: [String], readout: String) {
        switch concept.visual {
        case .locusBeacon, .coordinateNavigator, .scaleCity, .packingCrates,
             .symmetryStudio, .tessellationFloor, .crossSectionScanner,
             .transformationMap, .areaArchitect, .netWorkshop, .perspectiveGrid:
            return geometryActions(for: concept.number)
        case .beatGrid, .phaseRings, .soundEnvelope, .waveformMixer, .spectrumBars,
             .chordCircle, .echoTunnel, .interferencePool:
            return musicActions(for: concept.number)
        case .logicScene, .networkGraph, .stateMachine, .sortingFlow, .systemGrid:
            return logicActions(for: concept.number)
        default:
            return (["Read target", "Tune model", "Lock answer"], ["Read target", "Tune model", "Lock answer", "Skip check"], "BUILD ONLINE")
        }
    }

    private static func geometryActions(for number: Int) -> (solution: [String], options: [String], readout: String) {
        let solution: [String]
        switch number {
        case 62: solution = ["Set beacons", "Trace locus", "Confirm rule"]
        case 63: solution = ["Read ratio", "Scale blueprint", "Match lengths"]
        case 64: solution = ["Sort solids", "Pack volume", "Check empty space"]
        default: solution = ["Read shape", "Transform pieces", "Match target"]
        }
        return (solution, solution + ["Guess shape"], "GEOMETRY ACTIVE")
    }

    private static func musicActions(for number: Int) -> (solution: [String], options: [String], readout: String) {
        let solution: [String]
        switch number {
        case 65: solution = ["Hear target", "Set pulse", "Sync tempo"]
        case 66: solution = ["Compare waves", "Slide phase", "Align peaks"]
        case 67: solution = ["Mark attack", "Shape sustain", "Release sound"]
        case 68: solution = ["Pull left", "Swing right", "Hit goal"]
        case 69: solution = ["Find peak", "Read rhythm", "Time phase"]
        case 70: solution = ["Hear chord", "Pick notes", "Launch ball"]
        case 71: solution = ["Aim mirrors", "Send pulse", "Reach receiver"]
        case 72: solution = ["Place sources", "Watch ripples", "Match pattern"]
        case 73: solution = ["Drag source", "Compress waves", "Fill receiver"]
        case 74: solution = ["Hear notes", "Repeat pattern", "Complete circle"]
        default: solution = ["Map room", "Place panels", "Tame echo"]
        }
        return (solution, solution + ["Mute output"], "AUDIO ACTIVE")
    }

    private static func logicActions(for number: Int) -> (solution: [String], options: [String], readout: String) {
        let solution: [String]
        switch number {
        case 76: solution = ["Trace power", "Close switches", "Light bulb"]
        case 77: solution = ["Seed pulse", "Tune relays", "Finish cascade"]
        case 78: solution = ["Set phases", "Clear lanes", "Avoid collision"]
        case 79: solution = ["Read particles", "Tune gates", "Sort channels"]
        case 80: solution = ["Set feedback", "Add damping", "Stabilize loop"]
        case 81: solution = ["Find damage", "Activate relays", "Deliver message"]
        case 82: solution = ["Rank signals", "Open channel", "Defer losers"]
        case 83: solution = ["Shift phases", "Match clocks", "Fire together"]
        case 84: solution = ["Change velocity", "Curve motion", "Guide flock"]
        case 85: solution = ["Boost repeaters", "Avoid clipping", "Read pulse"]
        case 86: solution = ["Tune local rules", "Align swarm", "Reach target"]
        case 87: solution = ["Allow safe", "Block harmful", "Seal wall"]
        case 88: solution = ["Set intake", "Raise service", "Prevent overload"]
        case 89: solution = ["Cluster calls", "Assign cars", "Minimize travel"]
        case 90: solution = ["Set gear phases", "Find multiple", "Align marks"]
        case 91: solution = ["Move resources", "Balance regions", "Stop shortages"]
        case 92: solution = ["Weight groups", "Build coalition", "Stabilize vote"]
        case 93: solution = ["Feed prey", "Limit predators", "Balance habitat"]
        case 94: solution = ["Feed line", "Tune stations", "Ship output"]
        case 95: solution = ["Mark failures", "Use backups", "Keep connected"]
        case 96: solution = ["Fade loops", "Mark trails", "Choose shortest"]
        case 97: solution = ["Choose grammar", "Build parse", "Remove ambiguity"]
        case 98: solution = ["Share CPU", "Balance memory", "Avoid starvation"]
        case 99: solution = []
        case 100: solution = ["Tune workers", "Tune pheromone", "Form clusters"]
        default: solution = ["Connect modules", "Run system", "Stabilize design"]
        }
        return (solution, solution + ["Ignore rule"], "SYSTEM ACTIVE")
    }
}

private struct BuiltConceptVisual: View {
    @Environment(\.mathItAccent) private var accent

    let visual: MathItConceptVisual

    var body: some View {
        switch visual {
        case .locusBeacon:
            beaconField
        case .scaleCity:
            scaleCity
        case .packingCrates:
            packingCrates
        case .beatGrid:
            beatGrid
        case .phaseRings:
            phaseRings
        case .soundEnvelope:
            envelope
        case .waveformMixer:
            waveform
        case .spectrumBars:
            spectrum
        case .chordCircle:
            chordCircle
        case .echoTunnel:
            echoTunnel
        case .interferencePool:
            interferencePool
        case .logicScene(let number):
            logicScene(number)
        default:
            Image(systemName: "sparkles")
                .font(.system(size: 84, weight: .light))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.42), radius: 18)
        }
    }

    private var beaconField: some View {
        ZStack {
            ForEach([70.0, 118.0, 166.0], id: \.self) { diameter in
                Circle().stroke(accent.opacity(0.22), lineWidth: 1.2).frame(width: diameter, height: diameter)
            }
            HStack(spacing: 68) {
                beacon("A")
                beacon("B")
            }
            Capsule().fill(accent.opacity(0.76)).frame(width: 132, height: 4).rotationEffect(.degrees(-18))
        }
    }

    private var scaleCity: some View {
        HStack(alignment: .bottom, spacing: 16) {
            building(width: 38, height: 70)
            building(width: 54, height: 116)
            building(width: 70, height: 154)
            VStack(spacing: 8) {
                Text("2x").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundStyle(accent)
                Image(systemName: "arrow.up.right").font(.system(size: 34, weight: .bold)).foregroundStyle(accent)
            }
        }
    }

    private var packingCrates: some View {
        VStack(spacing: 8) {
            ForEach(0..<3) { row in
                HStack(spacing: 8) {
                    ForEach(0..<4) { col in
                        RoundedRectangle(cornerRadius: 5)
                            .fill((row + col).isMultiple(of: 2) ? accent.opacity(0.7) : .white.opacity(0.18))
                            .frame(width: 38, height: 32)
                    }
                }
            }
        }
        .padding(18)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.52), lineWidth: 2))
    }

    private var beatGrid: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<12) { index in
                Capsule()
                    .fill(index.isMultiple(of: 3) ? accent : accent.opacity(0.25))
                    .frame(width: 10, height: index.isMultiple(of: 3) ? 120 : 68)
            }
        }
    }

    private var phaseRings: some View {
        ZStack {
            ForEach(0..<5) { index in
                Circle()
                    .stroke(accent.opacity(0.18 + Double(index) * 0.08), lineWidth: 2)
                    .frame(width: 58 + CGFloat(index * 34), height: 58 + CGFloat(index * 34))
                    .offset(x: CGFloat(index * 9 - 18))
            }
            Image(systemName: "waveform.path")
                .font(.system(size: 74, weight: .light))
                .foregroundStyle(accent)
        }
    }

    private var envelope: some View {
        Path { path in
            path.move(to: CGPoint(x: 20, y: 160))
            path.addLine(to: CGPoint(x: 72, y: 34))
            path.addLine(to: CGPoint(x: 128, y: 82))
            path.addLine(to: CGPoint(x: 218, y: 82))
            path.addLine(to: CGPoint(x: 278, y: 160))
        }
        .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        .frame(width: 300, height: 190)
    }

    private var waveform: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                var path = Path()
                for x in stride(from: 0, through: size.width, by: 3) {
                    let y = size.height / 2 + sin((x / 24) + phase * 2) * 42 + sin((x / 9) + phase * 3) * 12
                    if x == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                canvas.stroke(path, with: .color(accent), lineWidth: 4)
            }
        }
    }

    private var spectrum: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach([42, 88, 136, 76, 154, 112, 54, 124], id: \.self) { height in
                RoundedRectangle(cornerRadius: 5)
                    .fill(accent.opacity(0.34 + Double(height) / 260))
                    .frame(width: 18, height: CGFloat(height))
            }
        }
    }

    private var chordCircle: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.38), lineWidth: 2).frame(width: 172, height: 172)
            ForEach(0..<12) { index in
                Circle()
                    .fill([0, 4, 7].contains(index) ? accent : .white.opacity(0.2))
                    .frame(width: [0, 4, 7].contains(index) ? 20 : 12, height: [0, 4, 7].contains(index) ? 20 : 12)
                    .offset(y: -86)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            Triangle()
                .stroke(accent.opacity(0.75), lineWidth: 3)
                .frame(width: 118, height: 106)
        }
    }

    private var echoTunnel: some View {
        ZStack {
            ForEach(0..<6) { index in
                RoundedRectangle(cornerRadius: 22)
                    .stroke(accent.opacity(0.16 + Double(index) * 0.08), lineWidth: 2)
                    .frame(width: 70 + CGFloat(index * 34), height: 42 + CGFloat(index * 24))
            }
            HStack(spacing: 44) {
                Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 44)).foregroundStyle(accent)
                Image(systemName: "arrow.left").font(.system(size: 34, weight: .bold)).foregroundStyle(accent)
            }
        }
    }

    private var interferencePool: some View {
        ZStack {
            ForEach(0..<5) { index in
                Circle().stroke(accent.opacity(0.16), lineWidth: 1.5).frame(width: 44 + CGFloat(index * 30), height: 44 + CGFloat(index * 30)).offset(x: -42)
                Circle().stroke(accent.opacity(0.16), lineWidth: 1.5).frame(width: 44 + CGFloat(index * 30), height: 44 + CGFloat(index * 30)).offset(x: 42)
            }
            HStack(spacing: 70) {
                beacon("S")
                beacon("S")
            }
        }
    }

    private func logicScene(_ number: Int) -> some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                logicNode("A")
                logicNode(number.isMultiple(of: 2) ? "B" : "1")
                logicNode(number.isMultiple(of: 3) ? "C" : "0")
            }
            HStack(spacing: 18) {
                Image(systemName: number.isMultiple(of: 2) ? "arrow.triangle.branch" : "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(accent)
                VStack(spacing: 7) {
                    ForEach(0..<4) { index in
                        Capsule()
                            .fill(index == number % 4 ? accent : accent.opacity(0.24))
                            .frame(width: 138, height: 8)
                    }
                }
            }
            logicNode("OK")
        }
    }

    private func beacon(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .black, design: .monospaced))
            .foregroundStyle(.black)
            .frame(width: 34, height: 34)
            .background(accent, in: Circle())
            .shadow(color: accent.opacity(0.42), radius: 12)
    }

    private func building(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(accent.opacity(0.18))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.68), lineWidth: 1.4))
            .frame(width: width, height: height)
    }

    private func logicNode(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .black, design: .monospaced))
            .foregroundStyle(.black)
            .frame(width: 48, height: 38)
            .background(accent, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
