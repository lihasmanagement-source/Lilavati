import SwiftUI

struct MathItLevelOneHundredThirtySevenView: View {
    private let stages = WeatherDecisionStage.all
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)
    private let simulationDays = 300

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var wetChance = 0.5
    @State private var stormGivenWet = 0.5
    @State private var selectedPlan: Int?
    @State private var outcomes: [WeatherOutcome] = []
    @State private var simulationProgress: CGFloat = 0
    @State private var running = false
    @State private var solved = false
    @State private var completed = false
    @State private var feedback: WeatherDecisionFeedback?
    @State private var runCount = 0
    @State private var animationToken = UUID()

    private var stage: WeatherDecisionStage { stages[stageIndex] }
    private var dryChance: Double { 1 - wetChance }
    private var stormChance: Double { wetChance * stormGivenWet }
    private var lightRainChance: Double { wetChance * (1 - stormGivenWet) }
    private var shownDays: Int { min(outcomes.count, Int(Double(outcomes.count) * Double(simulationProgress))) }
    private var shownOutcomes: ArraySlice<WeatherOutcome> { outcomes.prefix(shownDays) }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.017, green: 0.027, blue: 0.042).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header.padding(.top, compact ? 10 : 20)
                    weatherLab
                        .frame(maxWidth: 960)
                        .frame(height: max(405, min(535, proxy.size.height * 0.61)))
                    controls(compact: compact)
                        .frame(maxWidth: 880)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Forecast Decisions Validated",
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

            Text("WEATHER DECISION LAB")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(solved ? cyan : .white)
        }
    }

    private var weatherLab: some View {
        GeometryReader { geo in
            let dividerX = geo.size.width * 0.48
            let treeArea = CGRect(x: 38, y: 105, width: dividerX - 64, height: geo.size.height - 185)
            let experimentArea = CGRect(x: dividerX + 38, y: 105, width: geo.size.width - dividerX - 70, height: geo.size.height - 170)

            ZStack {
                Canvas { context, size in
                    drawBackground(context: &context, size: size, dividerX: dividerX)
                    drawProbabilityTree(context: &context, area: treeArea)
                    drawExperiment(context: &context, area: experimentArea)
                }

                VStack {
                    HStack {
                        metric("STATION P(WET)", percent(stage.wetChance))
                        metric("STORM | WET", percent(stage.stormGivenWet))
                        metric("SIMULATION", "\(simulationDays) DAYS")
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)

                Text("FORECAST TREE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: treeArea.midX, y: 78)

                Text("EXPERIMENTAL DAYS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: experimentArea.midX, y: 78)

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
            .background(Color(red: 0.036, green: 0.050, blue: 0.067))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            HStack(spacing: 12) {
                chanceSlider(label: "P(WET)", value: $wetChance, color: cyan)
                chanceSlider(label: "P(STORM|WET)", value: $stormGivenWet, color: coral)
            }

            HStack(spacing: 8) {
                ForEach(stage.plans.indices, id: \.self) { index in
                    planButton(index)
                }
            }

            Text("P(dry)=\(percent(dryChance))   P(light)=\(percent(lightRainChance))   P(storm)=\(percent(stormChance))   total=\(percent(dryChance + lightRainChance + stormChance))")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Button(action: runExperiment) {
                Label(running ? "SIMULATING \(shownDays) / \(simulationDays) DAYS" : "RUN \(simulationDays) FORECAST DAYS", systemImage: running ? "cloud.sun.rain.fill" : "play.fill")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 38 : 44)
                    .background(running || solved || selectedPlan == nil ? .white.opacity(0.16) : gold)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(running || solved || selectedPlan == nil)
        }
    }

    private func chanceSlider(label: String, value: Binding<Double>, color: Color) -> some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 76, alignment: .leading)
            Slider(value: value, in: 0.1...0.9, step: 0.1)
                .tint(color)
                .disabled(running || solved)
                .onChange(of: value.wrappedValue) { _, _ in clearExperiment() }
            Text(percent(value.wrappedValue))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 36, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private func planButton(_ index: Int) -> some View {
        let plan = stage.plans[index]
        let selected = selectedPlan == index
        return Button {
            selectedPlan = index
            clearExperiment(keepPlan: true)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: plan.icon)
                    .font(.system(size: 15, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(plan.name.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                    Text("EV \(signed(stage.expectedScore(for: index)))")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .opacity(0.66)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? .black.opacity(0.78) : .white)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(selected ? cyan : .white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? cyan : .white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(running || solved)
    }

    private func runExperiment() {
        guard !running, let selectedPlan else { return }
        running = true
        feedback = nil
        simulationProgress = 0
        runCount += 1
        outcomes = generateOutcomes(seed: UInt64(137_000 + stageIndex * 1_000 + runCount * 31))
        let token = animationToken

        withAnimation(.linear(duration: 2.8)) { simulationProgress = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) {
            guard token == animationToken else { return }
            evaluateExperiment(selectedPlan: selectedPlan, token: token)
        }
    }

    private func evaluateExperiment(selectedPlan: Int, token: UUID) {
        running = false
        if abs(wetChance - stage.wetChance) > 0.01 || abs(stormGivenWet - stage.stormGivenWet) > 0.01 {
            feedback = .forecastMismatch
        } else if selectedPlan != stage.bestPlanIndex {
            feedback = .planMismatch
        } else {
            solved = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { feedback = .validated }
            finishStage(token: token)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            guard token == animationToken else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                simulationProgress = 0
                outcomes = []
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
                    wetChance = 0.5
                    stormGivenWet = 0.5
                    selectedPlan = nil
                    outcomes = []
                    simulationProgress = 0
                    feedback = nil
                    solved = false
                }
            }
        }
    }

    private func clearExperiment(keepPlan: Bool = false) {
        guard !running && !solved else { return }
        outcomes = []
        simulationProgress = 0
        feedback = nil
        if !keepPlan { selectedPlan = nil }
    }

    private func resetLevel() {
        animationToken = UUID()
        stageIndex = 0
        wetChance = 0.5
        stormGivenWet = 0.5
        selectedPlan = nil
        outcomes = []
        simulationProgress = 0
        running = false
        solved = false
        completed = false
        feedback = nil
        runCount = 0
    }

    private func generateOutcomes(seed: UInt64) -> [WeatherOutcome] {
        var generator = WeatherSeededGenerator(seed: seed)
        return (0..<simulationDays).map { _ in
            let first = generator.nextUnit()
            guard first < wetChance else { return .dry }
            return generator.nextUnit() < stormGivenWet ? .storm : .lightRain
        }
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize, dividerX: CGFloat) {
        var divider = Path()
        divider.move(to: CGPoint(x: dividerX, y: 76))
        divider.addLine(to: CGPoint(x: dividerX, y: size.height - 52))
        context.stroke(divider, with: .color(.white.opacity(0.1)), lineWidth: 1)

        for y in stride(from: CGFloat(84), through: size.height - 55, by: 34) {
            var line = Path()
            line.move(to: CGPoint(x: 20, y: y))
            line.addLine(to: CGPoint(x: size.width - 20, y: y))
            context.stroke(line, with: .color(.white.opacity(0.025)), lineWidth: 1)
        }
    }

    private func drawProbabilityTree(context: inout GraphicsContext, area: CGRect) {
        let root = CGPoint(x: area.minX + 18, y: area.midY)
        let wet = CGPoint(x: area.minX + area.width * 0.48, y: area.minY + area.height * 0.3)
        let dry = CGPoint(x: area.minX + area.width * 0.48, y: area.minY + area.height * 0.78)
        let storm = CGPoint(x: area.maxX - 15, y: area.minY + area.height * 0.12)
        let light = CGPoint(x: area.maxX - 15, y: area.minY + area.height * 0.43)

        drawBranch(context: &context, from: root, to: wet, label: percent(wetChance), color: cyan)
        drawBranch(context: &context, from: root, to: dry, label: percent(dryChance), color: gold)
        drawBranch(context: &context, from: wet, to: storm, label: percent(stormGivenWet), color: coral)
        drawBranch(context: &context, from: wet, to: light, label: percent(1 - stormGivenWet), color: cyan)

        drawNode(context: &context, point: root, label: "DAY", color: .white)
        drawNode(context: &context, point: wet, label: "WET", color: cyan)
        drawNode(context: &context, point: dry, label: "DRY\n\(percent(dryChance))", color: gold)
        drawNode(context: &context, point: storm, label: "STORM\n\(percent(stormChance))", color: coral)
        drawNode(context: &context, point: light, label: "LIGHT\n\(percent(lightRainChance))", color: cyan)
    }

    private func drawBranch(context: inout GraphicsContext, from: CGPoint, to: CGPoint, label: String, color: Color) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color.opacity(0.65)), lineWidth: 2.5)
        let midpoint = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        context.draw(Text(label).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.white), at: CGPoint(x: midpoint.x, y: midpoint.y - 9))
    }

    private func drawNode(context: inout GraphicsContext, point: CGPoint, label: String, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)), with: .color(color))
        context.draw(Text(label).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(color), at: CGPoint(x: point.x, y: point.y + 22))
    }

    private func drawExperiment(context: inout GraphicsContext, area: CGRect) {
        let columns = 20
        let rows = 15
        let gridHeight = area.height * 0.58
        let gap: CGFloat = 2
        let cellWidth = (area.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let cellHeight = (gridHeight - CGFloat(rows - 1) * gap) / CGFloat(rows)

        for index in 0..<simulationDays {
            let column = index % columns
            let row = index / columns
            let rect = CGRect(
                x: area.minX + CGFloat(column) * (cellWidth + gap),
                y: area.minY + CGFloat(row) * (cellHeight + gap),
                width: cellWidth,
                height: cellHeight
            )
            let color: Color
            if index < shownDays {
                color = outcomeColor(outcomes[index])
            } else {
                color = .white.opacity(0.07)
            }
            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
        }

        let barTop = area.minY + gridHeight + 26
        let barWidth = area.width * 0.48
        let labels: [(WeatherOutcome, String, Double)] = [
            (.dry, "DRY", dryChance),
            (.lightRain, "LIGHT", lightRainChance),
            (.storm, "STORM", stormChance)
        ]

        for (index, item) in labels.enumerated() {
            let y = barTop + CGFloat(index) * 31
            let experimental = frequency(of: item.0)
            let background = CGRect(x: area.minX + 48, y: y - 5, width: barWidth, height: 10)
            let theoreticalBar = CGRect(x: background.minX, y: background.minY, width: barWidth * CGFloat(item.2), height: 10)
            let experimentalX = background.minX + barWidth * CGFloat(experimental)
            context.fill(Path(background), with: .color(.white.opacity(0.08)))
            context.fill(Path(theoreticalBar), with: .color(outcomeColor(item.0).opacity(0.45)))
            context.fill(Path(ellipseIn: CGRect(x: experimentalX - 4, y: y - 4, width: 8, height: 8)), with: .color(.white))
            context.draw(Text(item.1).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(outcomeColor(item.0)), at: CGPoint(x: area.minX + 19, y: y))
            context.draw(Text("\(percent(experimental)) / \(percent(item.2))").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.75)), at: CGPoint(x: background.maxX + 40, y: y))
        }

        if shownDays > 0, let selectedPlan {
            context.draw(
                Text("AVG SCORE \(signed(experimentalAverageScore(plan: selectedPlan)))")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(gold),
                at: CGPoint(x: area.midX, y: area.maxY - 3)
            )
        }
    }

    private func frequency(of outcome: WeatherOutcome) -> Double {
        guard shownDays > 0 else { return 0 }
        return Double(shownOutcomes.filter { $0 == outcome }.count) / Double(shownDays)
    }

    private func experimentalAverageScore(plan index: Int) -> Double {
        guard shownDays > 0 else { return 0 }
        let plan = stage.plans[index]
        let total = shownOutcomes.reduce(0.0) { $0 + plan.score(for: $1) }
        return total / Double(shownDays)
    }

    private func outcomeColor(_ outcome: WeatherOutcome) -> Color {
        switch outcome {
        case .dry: gold
        case .lightRain: cyan
        case .storm: coral
        }
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

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func signed(_ value: Double) -> String {
        let clean = abs(value) < 0.005 ? 0 : value
        return String(format: clean >= 0 ? "+%.2f" : "%.2f", clean)
    }
}

private enum WeatherOutcome: Equatable {
    case dry, lightRain, storm
}

private struct WeatherPlan {
    let name: String
    let icon: String
    let dryScore: Double
    let lightRainScore: Double
    let stormScore: Double

    func score(for outcome: WeatherOutcome) -> Double {
        switch outcome {
        case .dry: dryScore
        case .lightRain: lightRainScore
        case .storm: stormScore
        }
    }
}

private struct WeatherDecisionStage {
    let name: String
    let wetChance: Double
    let stormGivenWet: Double
    let plans: [WeatherPlan]

    var dryChance: Double { 1 - wetChance }
    var stormChance: Double { wetChance * stormGivenWet }
    var lightRainChance: Double { wetChance * (1 - stormGivenWet) }

    func expectedScore(for planIndex: Int) -> Double {
        let plan = plans[planIndex]
        return dryChance * plan.dryScore + lightRainChance * plan.lightRainScore + stormChance * plan.stormScore
    }

    var bestPlanIndex: Int {
        plans.indices.max { expectedScore(for: $0) < expectedScore(for: $1) } ?? 0
    }

    static let all = [
        WeatherDecisionStage(
            name: "Morning commute",
            wetChance: 0.3,
            stormGivenWet: 0.2,
            plans: [
                WeatherPlan(name: "Bike", icon: "bicycle", dryScore: 5, lightRainScore: 0, stormScore: -5),
                WeatherPlan(name: "Train", icon: "tram.fill", dryScore: 2, lightRainScore: 4, stormScore: 1),
                WeatherPlan(name: "Car", icon: "car.fill", dryScore: 1, lightRainScore: 3, stormScore: 5)
            ]
        ),
        WeatherDecisionStage(
            name: "Outdoor festival",
            wetChance: 0.6,
            stormGivenWet: 0.3,
            plans: [
                WeatherPlan(name: "Lawn", icon: "sun.max.fill", dryScore: 6, lightRainScore: 1, stormScore: -6),
                WeatherPlan(name: "Tent", icon: "tent.fill", dryScore: 3, lightRainScore: 4, stormScore: 0),
                WeatherPlan(name: "Hall", icon: "building.2.fill", dryScore: 1, lightRainScore: 2, stormScore: 5)
            ]
        ),
        WeatherDecisionStage(
            name: "Emergency delivery",
            wetChance: 0.8,
            stormGivenWet: 0.5,
            plans: [
                WeatherPlan(name: "Drone", icon: "paperplane.fill", dryScore: 8, lightRainScore: 0, stormScore: -8),
                WeatherPlan(name: "Truck", icon: "truck.box.fill", dryScore: 2, lightRainScore: 5, stormScore: 2),
                WeatherPlan(name: "Delay", icon: "clock.fill", dryScore: -2, lightRainScore: 1, stormScore: 6)
            ]
        )
    ]
}

private struct WeatherSeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(UInt64.max >> 11)
    }
}

private enum WeatherDecisionFeedback {
    case forecastMismatch, planMismatch, validated

    var message: String {
        switch self {
        case .forecastMismatch: "EXPERIMENT MATCHES YOUR TREE · CONFIGURE THE STATION BRIEF"
        case .planMismatch: "FREQUENCIES CONVERGED · CHOOSE THE HIGHEST THEORETICAL AVERAGE"
        case .validated: "300-DAY FREQUENCIES SUPPORT THE FORECAST DECISION"
        }
    }

    var isSuccess: Bool { self == .validated }
}

#Preview {
    MathItLevelOneHundredThirtySevenView(onContinue: {}, onLevelSelect: {})
}
