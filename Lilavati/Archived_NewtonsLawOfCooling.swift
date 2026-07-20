import SwiftUI

// Level 95 · Newton's Law of Cooling.

struct MathItLevelOneHundredThirtySixView: View {
    private let stages = ThermalControlStage.all
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var insulation = 1.0
    @State private var ambient = 20.0
    @State private var simulationProgress: CGFloat = 0
    @State private var running = false
    @State private var solved = false
    @State private var completed = false
    @State private var feedback: ThermalFeedback?
    @State private var trials: [ThermalTrial] = []
    @State private var animationToken = UUID()

    private var stage: ThermalControlStage { stages[stageIndex] }
    private var k: Double { max(0.05, 0.65 - 0.1 * insulation) }
    private var simulatedTime: Double { stage.deadline * Double(simulationProgress) }
    private var currentTemperature: Double { temperature(at: simulatedTime) }
    private var scheduledTemperature: Double { temperature(at: stage.deadline) }
    private var currentRate: Double { -k * (currentTemperature - ambient) }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.017, green: 0.027, blue: 0.040).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header.padding(.top, compact ? 10 : 20)
                    controlRoom
                        .frame(maxWidth: 940)
                        .frame(height: max(405, min(535, proxy.size.height * 0.61)))
                    controls(compact: compact)
                        .frame(maxWidth: 850)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Thermal Schedule Stabilized",
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

    private var header: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(stages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex ? cyan : index == stageIndex ? gold : .white.opacity(0.13))
                        .frame(width: index == stageIndex ? 42 : 24, height: 5)
                }
            }

            Text(stage.name.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(gold)

            Text("THERMAL CONTROL ROOM")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(solved ? cyan : .white)
        }
    }

    private var controlRoom: some View {
        GeometryReader { geo in
            let dividerX = geo.size.width * 0.65
            let plot = CGRect(x: 60, y: 92, width: dividerX - 90, height: geo.size.height - 156)
            let room = CGRect(x: dividerX + 42, y: 142, width: geo.size.width - dividerX - 82, height: geo.size.height - 235)

            ZStack {
                Canvas { context, size in
                    drawBackground(context: &context, size: size, dividerX: dividerX)
                    drawTemperatureGraph(context: &context, plot: plot)
                    drawRoom(context: &context, room: room)
                }

                VStack {
                    HStack {
                        metric("INITIAL", "\(number(stage.initialTemperature))°C")
                        metric("TARGET", "\(number(stage.targetTemperature))°C")
                        metric("DEADLINE", "\(number(stage.deadline)) h")
                        metric("TRIALS", "\(trials.count)")
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)

                Text("TEMPERATURE T(t)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: plot.midX, y: 67)

                VStack(spacing: 3) {
                    Text("\(number(currentTemperature))°C")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(temperatureColor(currentTemperature))
                    Text("ROOM SENSOR")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.48))
                    Text("t = \(number(simulatedTime)) h")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(gold)
                }
                .position(x: room.midX, y: 103)

                if let feedback {
                    Text(feedback.message)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(feedback.isSuccess ? cyan : coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .position(x: geo.size.width / 2, y: geo.size.height - 27)
                }
            }
            .background(Color(red: 0.038, green: 0.050, blue: 0.061))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            HStack(spacing: 12) {
                Text("INSULATION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)
                    .frame(width: 78, alignment: .leading)
                Slider(value: $insulation, in: 1...6, step: 1)
                    .tint(cyan)
                    .disabled(running || solved)
                    .onChange(of: insulation) { _, _ in resetSimulation() }
                Text("R\(Int(insulation)) · k=\(number(k))")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 98, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Text("AMBIENT Tₐ")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(gold)
                    .frame(width: 78, alignment: .leading)
                Slider(value: $ambient, in: 10...35, step: 1)
                    .tint(gold)
                    .disabled(running || solved)
                    .onChange(of: ambient) { _, _ in resetSimulation() }
                Text("\(number(ambient))°C")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 98, alignment: .trailing)
            }

            Text("dT/dt = −\(number(k))(\(number(currentTemperature)) − \(number(ambient))) = \(signed(currentRate)) °C/h     T(\(number(stage.deadline))) = \(number(scheduledTemperature))°C")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Button(action: runSchedule) {
                Label(running ? "THERMAL TEST RUNNING" : "RUN TO DEADLINE", systemImage: running ? "thermometer.medium" : "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 38 : 44)
                    .background(running || solved ? .white.opacity(0.16) : gold)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(running || solved)
        }
    }

    private func runSchedule() {
        guard !running && !solved else { return }
        running = true
        feedback = nil
        simulationProgress = 0
        let token = animationToken

        withAnimation(.linear(duration: 2.4)) { simulationProgress = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
            guard token == animationToken else { return }
            trials.append(ThermalTrial(insulation: insulation, ambient: ambient, temperature: scheduledTemperature))
            evaluateSchedule(token: token)
        }
    }

    private func evaluateSchedule(token: UUID) {
        let difference = scheduledTemperature - stage.targetTemperature
        if abs(difference) <= 0.12 {
            running = false
            solved = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { feedback = .onSchedule }
            finishStage(token: token)
            return
        }

        running = false
        feedback = difference < 0 ? .tooCold : .tooHot
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            guard token == animationToken else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                simulationProgress = 0
                feedback = nil
            }
        }
    }

    private func finishStage(token: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            guard token == animationToken else { return }
            if stageIndex == stages.count - 1 {
                withAnimation { completed = true }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    stageIndex += 1
                    insulation = 1
                    ambient = 20
                    simulationProgress = 0
                    trials = []
                    feedback = nil
                    solved = false
                }
            }
        }
    }

    private func resetSimulation() {
        guard !running && !solved else { return }
        simulationProgress = 0
        feedback = nil
    }

    private func resetLevel() {
        animationToken = UUID()
        stageIndex = 0
        insulation = 1
        ambient = 20
        simulationProgress = 0
        running = false
        solved = false
        completed = false
        feedback = nil
        trials = []
    }

    private func temperature(at time: Double) -> Double {
        ambient + (stage.initialTemperature - ambient) * exp(-k * time)
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize, dividerX: CGFloat) {
        var divider = Path()
        divider.move(to: CGPoint(x: dividerX, y: 76))
        divider.addLine(to: CGPoint(x: dividerX, y: size.height - 52))
        context.stroke(divider, with: .color(.white.opacity(0.1)), lineWidth: 1)

        for y in stride(from: CGFloat(82), through: size.height - 55, by: 34) {
            var line = Path()
            line.move(to: CGPoint(x: 20, y: y))
            line.addLine(to: CGPoint(x: size.width - 20, y: y))
            context.stroke(line, with: .color(.white.opacity(0.025)), lineWidth: 1)
        }
    }

    private func drawTemperatureGraph(context: inout GraphicsContext, plot: CGRect) {
        var axes = Path()
        axes.move(to: CGPoint(x: plot.minX, y: plot.minY))
        axes.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        axes.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(axes, with: .color(.white.opacity(0.38)), lineWidth: 1.5)

        for index in 0...5 {
            let time = stage.deadline * Double(index) / 5
            let x = graphX(time, plot: plot)
            context.draw(Text(number(time)).font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.5)), at: CGPoint(x: x, y: plot.maxY + 12))
        }

        let ambientY = graphY(ambient, plot: plot)
        var ambientLine = Path()
        ambientLine.move(to: CGPoint(x: plot.minX, y: ambientY))
        ambientLine.addLine(to: CGPoint(x: plot.maxX, y: ambientY))
        context.stroke(ambientLine, with: .color(cyan.opacity(0.65)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        context.draw(Text("Tₐ").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(cyan), at: CGPoint(x: plot.maxX + 12, y: ambientY))

        var preview = Path()
        for index in 0...120 {
            let time = stage.deadline * Double(index) / 120
            let point = CGPoint(x: graphX(time, plot: plot), y: graphY(temperature(at: time), plot: plot))
            index == 0 ? preview.move(to: point) : preview.addLine(to: point)
        }
        context.stroke(preview, with: .color(.white.opacity(0.18)), lineWidth: 2)

        var active = Path()
        let activeSteps = max(1, Int(120 * simulationProgress))
        for index in 0...activeSteps {
            let time = stage.deadline * Double(index) / 120
            let point = CGPoint(x: graphX(time, plot: plot), y: graphY(temperature(at: time), plot: plot))
            index == 0 ? active.move(to: point) : active.addLine(to: point)
        }
        context.stroke(active, with: .color(gold), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        let targetPoint = CGPoint(x: plot.maxX, y: graphY(stage.targetTemperature, plot: plot))
        context.stroke(Path(ellipseIn: CGRect(x: targetPoint.x - 10, y: targetPoint.y - 10, width: 20, height: 20)), with: .color(coral), lineWidth: 3)
        context.fill(Path(ellipseIn: CGRect(x: targetPoint.x - 3, y: targetPoint.y - 3, width: 6, height: 6)), with: .color(coral))

        let currentPoint = CGPoint(x: graphX(simulatedTime, plot: plot), y: graphY(currentTemperature, plot: plot))
        context.fill(Path(ellipseIn: CGRect(x: currentPoint.x - 6, y: currentPoint.y - 6, width: 12, height: 12)), with: .color(gold))
        context.stroke(Path(ellipseIn: CGRect(x: currentPoint.x - 9, y: currentPoint.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.65)), lineWidth: 1)
    }

    private func drawRoom(context: inout GraphicsContext, room: CGRect) {
        let roomColor = temperatureColor(currentTemperature)
        context.fill(Path(room), with: .color(roomColor.opacity(0.12)))
        context.stroke(Path(room), with: .color(.white.opacity(0.65)), lineWidth: 3)

        let window = CGRect(x: room.minX + 12, y: room.minY + 14, width: room.width * 0.32, height: room.height * 0.38)
        context.fill(Path(window), with: .color(cyan.opacity(0.16)))
        context.stroke(Path(window), with: .color(cyan.opacity(0.7)), lineWidth: 2)
        var pane = Path()
        pane.move(to: CGPoint(x: window.midX, y: window.minY))
        pane.addLine(to: CGPoint(x: window.midX, y: window.maxY))
        pane.move(to: CGPoint(x: window.minX, y: window.midY))
        pane.addLine(to: CGPoint(x: window.maxX, y: window.midY))
        context.stroke(pane, with: .color(.white.opacity(0.3)), lineWidth: 1)

        let unit = CGRect(x: room.maxX - room.width * 0.34, y: room.maxY - room.height * 0.34, width: room.width * 0.25, height: room.height * 0.21)
        context.fill(Path(unit), with: .color(.black.opacity(0.42)))
        context.stroke(Path(unit), with: .color(gold.opacity(0.65)), lineWidth: 2)

        let fanCenter = CGPoint(x: unit.midX, y: unit.midY)
        context.stroke(Path(ellipseIn: CGRect(x: fanCenter.x - 8, y: fanCenter.y - 8, width: 16, height: 16)), with: .color(.white.opacity(0.55)), lineWidth: 1.5)
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 2) {
            var blade = Path()
            blade.move(to: fanCenter)
            blade.addLine(to: CGPoint(x: fanCenter.x + cos(angle) * 8, y: fanCenter.y + sin(angle) * 8))
            context.stroke(blade, with: .color(.white.opacity(0.5)), lineWidth: 2)
        }

        let personX = room.midX
        let floorY = room.maxY - 12
        context.fill(Path(ellipseIn: CGRect(x: personX - 7, y: floorY - 47, width: 14, height: 14)), with: .color(.white.opacity(0.72)))
        var body = Path()
        body.move(to: CGPoint(x: personX, y: floorY - 33))
        body.addLine(to: CGPoint(x: personX, y: floorY - 13))
        body.move(to: CGPoint(x: personX, y: floorY - 27))
        body.addLine(to: CGPoint(x: personX - 10, y: floorY - 19))
        body.move(to: CGPoint(x: personX, y: floorY - 27))
        body.addLine(to: CGPoint(x: personX + 10, y: floorY - 19))
        body.move(to: CGPoint(x: personX, y: floorY - 13))
        body.addLine(to: CGPoint(x: personX - 8, y: floorY))
        body.move(to: CGPoint(x: personX, y: floorY - 13))
        body.addLine(to: CGPoint(x: personX + 8, y: floorY))
        context.stroke(body, with: .color(.white.opacity(0.72)), lineWidth: 3)

        context.draw(Text("OUTSIDE \(number(ambient))°").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(cyan), at: CGPoint(x: window.midX, y: window.maxY + 12))
    }

    private func graphX(_ time: Double, plot: CGRect) -> CGFloat {
        plot.minX + CGFloat(time / stage.deadline) * plot.width
    }

    private func graphY(_ temperature: Double, plot: CGRect) -> CGFloat {
        let minimum = 8.0
        let maximum = 36.0
        return plot.maxY - CGFloat((temperature - minimum) / (maximum - minimum)) * plot.height
    }

    private func temperatureColor(_ temperature: Double) -> Color {
        temperature >= 23 ? coral : temperature <= 18 ? cyan : gold
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func signed(_ value: Double) -> String {
        value >= 0 ? "+\(number(value))" : number(value)
    }

    private func number(_ value: Double) -> String {
        let clean = abs(value) < 0.005 ? 0 : value
        return abs(clean.rounded() - clean) < 0.005 ? String(Int(clean.rounded())) : String(format: "%.2f", clean)
    }
}

private struct ThermalControlStage {
    let name: String
    let initialTemperature: Double
    let deadline: Double
    let solutionInsulation: Double
    let solutionAmbient: Double

    var solutionK: Double { max(0.05, 0.65 - 0.1 * solutionInsulation) }
    var targetTemperature: Double {
        solutionAmbient + (initialTemperature - solutionAmbient) * exp(-solutionK * deadline)
    }

    static let all = [
        ThermalControlStage(name: "Office warm-up", initialTemperature: 15, deadline: 4, solutionInsulation: 4, solutionAmbient: 25),
        ThermalControlStage(name: "Server-room cooldown", initialTemperature: 30, deadline: 3, solutionInsulation: 3, solutionAmbient: 18),
        ThermalControlStage(name: "Greenhouse morning", initialTemperature: 12, deadline: 5, solutionInsulation: 5, solutionAmbient: 28)
    ]
}

private struct ThermalTrial {
    let insulation: Double
    let ambient: Double
    let temperature: Double
}

private enum ThermalFeedback {
    case tooCold, tooHot, onSchedule

    var message: String {
        switch self {
        case .tooCold: "ROOM IS TOO COLD AT THE DEADLINE · ADJUST Tₐ OR THERMAL EXCHANGE"
        case .tooHot: "ROOM IS TOO HOT AT THE DEADLINE · ADJUST Tₐ OR THERMAL EXCHANGE"
        case .onSchedule: "SOLUTION CURVE INTERSECTS THE TARGET AT THE DEADLINE"
        }
    }

    var isSuccess: Bool { self == .onSchedule }
}

#Preview {
    MathItLevelOneHundredThirtySixView(onContinue: {}, onLevelSelect: {})
}
