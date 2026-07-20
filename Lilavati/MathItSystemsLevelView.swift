import SwiftUI

struct MathItSystemsLevelView: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var values: [Int] = []
    @State private var completed = false
    @State private var wrongPulse = false
    @State private var showingGoal = false
    @State private var validatedControls: Set<Int> = []
    @State private var feedbackText: String?

    private var spec: MathItSystemLevelSpec {
        MathItSystemLevelSpec.level(concept.number)
    }

    private var stage: MathItSystemStage {
        spec.stages[min(stageIndex, spec.stages.count - 1)]
    }

    private var isSolved: Bool {
        stageMatchesSolution && satisfiesSystemConstraints
    }

    private var stageMatchesSolution: Bool {
        values.count == stage.solution.count && zip(values, stage.solution).allSatisfy { pair in
            pair.0 == pair.1
        }
    }

    private var satisfiesSystemConstraints: Bool {
        switch spec.visual {
        case .switchboard, .filter, .routing, .clockwork, .firewall, .antColony, .emergence:
            return true
        case .cascade:
            return values.indices.allSatisfy { stateName($0) != "block" }
        case .traffic:
            let moving = values.indices.filter { ["go", "turn"].contains(stateName($0)) }.count
            return moving <= 2
        case .feedback:
            return (4...7).contains(values.reduce(0, +))
        case .priority:
            return values.indices.filter { stateName($0) == "first" }.count == 1
        case .synchronize:
            return Set(values).count == 1
        case .deadlock:
            return values.indices.contains { ["release", "swap"].contains(stateName($0)) }
        case .signal:
            return values.indices.allSatisfy { ["clean", "boost"].contains(stateName($0)) }
        case .hive:
            return values.indices.allSatisfy { stateName($0) != "off" }
        case .queue:
            return controlValue(1) >= controlValue(0)
        case .elevator:
            return Set(values).count == values.count
        case .market:
            let states = Set(values.indices.map { stateName($0) })
            return states.contains("import") && states.contains("export")
        case .voting:
            return values.reduce(0, +) >= 4
        case .ecosystem:
            return ((values.max() ?? 0) - (values.min() ?? 0)) <= 1
        case .factory:
            return values.indices.allSatisfy { stateName($0) != "idle" }
        case .internet:
            return values.indices.filter { stateName($0) != "down" }.count >= 3
        case .language:
            return values.indices.last.map { stateName($0) == "stop" } ?? false
        case .operatingSystem:
            let budget = values.reduce(0, +)
            return (5...7).contains(budget) && values.indices.allSatisfy { stateName($0) != "low" }
        case .civilization:
            return values.indices.allSatisfy { stateName($0) != "short" }
        }
    }

    private var matchedControls: Int {
        isSolved ? stage.solution.count : 0
    }

    private var progress: Double {
        let stageProgress = Double(matchedControls) / Double(max(1, spec.controls.count))
        return (Double(stageIndex) + stageProgress) / Double(max(1, spec.stages.count))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 13) {
                    header

                    ProgressView(value: progress)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    systemField
                        .frame(height: min(402, proxy.size.height * 0.52))
                        .padding(.horizontal, 18)
                        .scaleEffect(wrongPulse ? 0.985 : 1)

                    statusConsole

                    controls
                }
                .padding(.top, 38)
                .padding(.bottom, 78)

                if showingGoal {
                    goalSheet
                        .zIndex(15)
                }

                CompletionOverlay(
                    title: "Level \(concept.number) Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .onAppear(perform: reset)
            .onChange(of: concept.number) { _, _ in
                reset()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.58))

            Text(spec.title)
                .font(.system(size: 35, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(completed ? 1 : 0.48))
                .multilineTextAlignment(.center)

            Text(spec.pairing.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(accent.opacity(0.82))
        }
        .padding(.horizontal, 58)
    }

    private var systemField: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.08), Color(red: 0.012, green: 0.018, blue: 0.03), .black.opacity(0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.36), lineWidth: 1.2))

                visual(size: proxy.size)
                    .padding(8)

                VStack {
                    HStack(alignment: .top) {
                        stageBadge
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                showingGoal = true
                            }
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 36, height: 30)
                                .background(accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                }
                .padding(14)
            }
        }
    }

    private var stageBadge: some View {
        Label(stage.prompt, systemImage: spec.badgeIcon)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.76), in: Capsule())
            .overlay(Capsule().stroke(accent.opacity(0.4), lineWidth: 1))
    }

    private var controls: some View {
        VStack(spacing: 11) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(4, max(1, spec.controls.count))),
                spacing: 8
            ) {
                ForEach(0..<spec.controls.count, id: \.self) { index in
                    controlTile(index)
                }
            }

            HStack(spacing: 12) {
                Button(action: checkStage) {
                    Label(isSolved ? "LOCK" : "TEST", systemImage: isSolved ? "checkmark.seal.fill" : "scope")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: reset) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 54, height: 44)
                        .background(accent, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
    }

    private func controlTile(_ index: Int) -> some View {
        let control = spec.controls[index]
        let value = controlValue(index)
        let matched = validatedControls.contains(index)

        return VStack(spacing: 4) {
            Button {
                cycle(index, by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(matched ? .black : accent)
                    .frame(width: 30, height: 20)
                    .background(matched ? accent : accent.opacity(0.16), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(completed)

            Button {
                cycle(index, by: 1)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: control.icon)
                        .font(.system(size: 11, weight: .black))
                    Text(control.states[value].uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.56)
                    Text(control.label.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .foregroundStyle(matched ? .black : accent)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(matched ? accent : .black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(matched ? 0.94 : 0.42), lineWidth: 1.1))
                .shadow(color: matched ? accent.opacity(0.28) : .clear, radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(completed)
        }
    }

    private var goalSheet: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()
                .onTapGesture { closeGoal() }

            VStack(alignment: .leading, spacing: 14) {
                Text(spec.objective)
                    .font(.system(size: 21, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                infoRow("RULES", spec.rules)
                infoRow("WIN", spec.winCondition)
                infoRow("LEARN", spec.learningGoal)
                infoRow("RESET", spec.resetBehavior)

                Button(action: closeGoal) {
                    Text("PLAY")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.5), lineWidth: 1.2))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private func infoRow(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.7)
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusConsole: some View {
        HStack(spacing: 10) {
            Image(systemName: isSolved ? "checkmark.circle.fill" : "waveform.path.ecg")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(accent)

            Text(feedbackText ?? liveReadout)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.36), lineWidth: 1))
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func visual(size: CGSize) -> some View {
        switch spec.visual {
        case .switchboard:
            switchboard(size: size)
        case .cascade:
            cascade(size: size)
        case .traffic:
            traffic(size: size)
        case .filter:
            filter(size: size)
        case .feedback:
            feedback(size: size)
        case .routing:
            network(size: size, mode: .routing)
        case .priority:
            priority(size: size)
        case .synchronize:
            synchronize(size: size)
        case .deadlock:
            deadlock(size: size)
        case .signal:
            signal(size: size)
        case .hive:
            hive(size: size)
        case .firewall:
            firewall(size: size)
        case .queue:
            queue(size: size)
        case .elevator:
            elevator(size: size)
        case .clockwork:
            clockwork(size: size)
        case .market:
            market(size: size)
        case .voting:
            voting(size: size)
        case .ecosystem:
            ecosystem(size: size)
        case .factory:
            factory(size: size)
        case .internet:
            network(size: size, mode: .internet)
        case .antColony:
            antColony(size: size)
        case .language:
            language(size: size)
        case .operatingSystem:
            operatingSystem(size: size)
        case .emergence:
            emergence(size: size)
        case .civilization:
            civilization(size: size)
        }
    }

    private func switchboard(size: CGSize) -> some View {
        ZStack {
            Canvas { canvas, canvasSize in
                let points = switchboardPoints(canvasSize)
                let edges: [(String, String, Int)] = [("S", "A", 0), ("A", "B", 1), ("A", "C", 2), ("C", "G", 3), ("B", "G", 1)]
                for edge in edges {
                    let closed = controlLive(edge.2)
                    var path = Path()
                    path.move(to: points[edge.0]!)
                    path.addLine(to: points[edge.1]!)
                    canvas.stroke(path, with: .color(closed ? accent.opacity(0.86) : .white.opacity(0.14)), style: StrokeStyle(lineWidth: closed ? 4 : 2, lineCap: .round, dash: closed ? [] : [5, 6]))
                }
            }

            ForEach(["S", "A", "B", "C", "G"], id: \.self) { label in
                let points = switchboardPoints(size)
                let isGoal = label == "G"
                systemNode(label, active: label == "S" || (isGoal && isSolved), target: isGoal)
                    .position(points[label] ?? .zero)
            }
        }
    }

    private func switchboardPoints(_ size: CGSize) -> [String: CGPoint] {
        [
            "S": CGPoint(x: size.width * 0.18, y: size.height * 0.52),
            "A": CGPoint(x: size.width * 0.38, y: size.height * 0.36),
            "B": CGPoint(x: size.width * 0.58, y: size.height * 0.28),
            "C": CGPoint(x: size.width * 0.58, y: size.height * 0.68),
            "G": CGPoint(x: size.width * 0.82, y: size.height * 0.50)
        ]
    }

    private func cascade(size: CGSize) -> some View {
        VStack(spacing: 12) {
            ForEach(0..<spec.controls.count, id: \.self) { index in
                HStack(spacing: 14) {
                    systemNode("\(index + 1)", active: controlLive(index), target: false)
                    Capsule()
                        .fill(controlLive(index) ? accent.opacity(0.8) : .white.opacity(0.12))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3)
                    Text(spec.controls[index].states[controlValue(index)].uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(controlLive(index) ? .black : accent)
                        .frame(width: 72, height: 30)
                        .background(controlLive(index) ? accent : .black.opacity(0.7), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func traffic(size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(width: size.width * 0.18, height: size.height * 0.74)
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(width: size.width * 0.74, height: size.height * 0.18)

            ForEach(0..<spec.controls.count, id: \.self) { index in
                let positions = [
                    CGPoint(x: size.width * 0.5, y: size.height * 0.24),
                    CGPoint(x: size.width * 0.75, y: size.height * 0.5),
                    CGPoint(x: size.width * 0.5, y: size.height * 0.76),
                    CGPoint(x: size.width * 0.25, y: size.height * 0.5)
                ]
                trafficSignal(index)
                    .position(positions[index])
            }

            Circle()
                .stroke(isSolved ? accent.opacity(0.9) : .white.opacity(0.16), lineWidth: 3)
                .frame(width: 82, height: 82)
        }
    }

    private func trafficSignal(_ index: Int) -> some View {
        let state = spec.controls[index].states[controlValue(index)]
        let live = controlLive(index)
        return VStack(spacing: 4) {
            Circle().fill(state == "go" ? accent : .white.opacity(0.12)).frame(width: 13, height: 13)
            Circle().fill(state == "turn" ? accent : .white.opacity(0.12)).frame(width: 13, height: 13)
            Circle().fill(state == "hold" || state == "stop" ? accent.opacity(live ? 1 : 0.55) : .white.opacity(0.12)).frame(width: 13, height: 13)
        }
        .padding(8)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(live ? 0.88 : 0.28), lineWidth: 1.2))
    }

    private func filter(size: CGSize) -> some View {
        AnyView(
            VStack(spacing: 18) {
                ForEach(0..<spec.controls.count, id: \.self) { index in
                    HStack(spacing: 9) {
                        ForEach(0..<4, id: \.self) { packet in
                            Circle()
                                .fill(packet % 2 == index % 2 ? accent.opacity(0.72) : .white.opacity(0.18))
                                .frame(width: 14, height: 14)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white.opacity(0.26))
                        Text(spec.controls[index].states[controlValue(index)])
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(controlLive(index) ? .black : accent)
                            .frame(width: 62, height: 34)
                            .background(controlLive(index) ? accent : .black.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white.opacity(0.26))
                        Capsule()
                            .fill(controlLive(index) ? accent.opacity(0.86) : .white.opacity(0.12))
                            .frame(width: 62, height: 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    private func feedback(size: CGSize) -> some View {
        Canvas { canvas, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            for index in 0..<72 {
                let t = CGFloat(index) / 72
                let radius = (0.12 + t * 0.34 + CGFloat(abs(controlValue(0) - solutionValue(0))) * 0.012) * min(canvasSize.width, canvasSize.height)
                let angle = t * .pi * 5 + CGFloat(controlValue(1)) * 0.4
                let point = CGPoint(
                    x: center.x + CGFloat(cos(Double(angle))) * radius,
                    y: center.y + CGFloat(sin(Double(angle))) * radius
                )
                let dot = Path(ellipseIn: CGRect(x: point.x - 2.4, y: point.y - 2.4, width: 4.8, height: 4.8))
                canvas.fill(dot, with: .color(isSolved ? accent.opacity(0.9) : accent.opacity(0.46)))
            }
            let target = Path(ellipseIn: CGRect(x: center.x - 42, y: center.y - 42, width: 84, height: 84))
            canvas.stroke(target, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
        }
        .overlay {
            systemNode(isSolved ? "STABLE" : "LOOP", active: isSolved, target: true)
        }
    }

    private enum NetworkMode {
        case routing
        case internet
    }

    private func network(size: CGSize, mode: NetworkMode) -> some View {
        ZStack {
            Canvas { canvas, canvasSize in
                let nodes = networkPoints(canvasSize)
                let edges: [(Int, Int, Int)] = mode == .routing
                    ? [(0, 1, 0), (1, 3, 1), (0, 2, 2), (2, 4, 3), (3, 5, 1), (4, 5, 3)]
                    : [(0, 1, 0), (1, 2, 1), (2, 5, 2), (0, 3, 3), (3, 4, 0), (4, 5, 1)]
                for edge in edges {
                    var path = Path()
                    path.move(to: nodes[edge.0])
                    path.addLine(to: nodes[edge.1])
                    let active = controlLive(edge.2)
                    canvas.stroke(path, with: .color(active ? accent.opacity(0.78) : .white.opacity(0.14)), style: StrokeStyle(lineWidth: active ? 4 : 2, lineCap: .round, dash: active ? [] : [5, 6]))
                }
            }

            ForEach(0..<6, id: \.self) { index in
                let nodes = networkPoints(size)
                systemNode(index == 0 ? "S" : index == 5 ? "G" : "\(index)", active: index == 0 || (index == 5 && isSolved), target: index == 5)
                    .position(nodes[index])
            }
        }
    }

    private func networkPoints(_ size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: size.width * 0.16, y: size.height * 0.52),
            CGPoint(x: size.width * 0.34, y: size.height * 0.28),
            CGPoint(x: size.width * 0.56, y: size.height * 0.28),
            CGPoint(x: size.width * 0.34, y: size.height * 0.72),
            CGPoint(x: size.width * 0.56, y: size.height * 0.72),
            CGPoint(x: size.width * 0.82, y: size.height * 0.52)
        ]
    }

    private func priority(size: CGSize) -> some View {
        AnyView(
            VStack(spacing: 14) {
                ForEach(0..<spec.controls.count, id: \.self) { index in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1)).frame(height: 26)
                        Capsule()
                            .fill(controlLive(index) ? accent.opacity(0.86) : accent.opacity(0.42))
                            .frame(width: CGFloat(controlValue(index) + 1) / CGFloat(spec.controls[index].states.count) * size.width * 0.58 + 28, height: 26)
                        Text(spec.controls[index].label.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9)
                    }
                    .padding(.horizontal, 44)
                }
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(isSolved ? accent : .white.opacity(0.2))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    private func synchronize(size: CGSize) -> some View {
        HStack(spacing: 18) {
            ForEach(0..<spec.controls.count, id: \.self) { index in
                ZStack {
                    Circle().stroke(.white.opacity(0.14), lineWidth: 2)
                    Circle().stroke(controlLive(index) ? accent : accent.opacity(0.36), lineWidth: 3)
                        .rotationEffect(.degrees(Double(controlValue(index)) * 90))
                    Capsule()
                        .fill(controlLive(index) ? accent : accent.opacity(0.56))
                        .frame(width: 5, height: 36)
                        .offset(y: -18)
                        .rotationEffect(.degrees(Double(controlValue(index)) * 90))
                    Text(spec.controls[index].label.prefix(1).uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(width: min(72, size.width / 4.8), height: min(72, size.width / 4.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deadlock(size: CGSize) -> some View {
        ZStack {
            Canvas { canvas, canvasSize in
                let points = ringPoints(count: spec.controls.count, size: canvasSize, radiusScale: 0.28)
                for index in 0..<points.count {
                    let next = (index + 1) % points.count
                    var path = Path()
                    path.move(to: points[index])
                    path.addLine(to: points[next])
                    let broken = controlLive(index)
                    canvas.stroke(path, with: .color(broken ? accent.opacity(0.82) : .white.opacity(0.18)), style: StrokeStyle(lineWidth: broken ? 3.5 : 2, dash: broken ? [2, 8] : []))
                }
            }
            ForEach(0..<spec.controls.count, id: \.self) { index in
                let points = ringPoints(count: spec.controls.count, size: size, radiusScale: 0.28)
                systemNode("P\(index + 1)", active: controlLive(index), target: false)
                    .position(points[index])
            }
            systemNode(isSolved ? "FREE" : "WAIT", active: isSolved, target: true)
        }
    }

    private func signal(size: CGSize) -> some View {
        AnyView(
            HStack(spacing: 12) {
                ForEach(0..<spec.controls.count, id: \.self) { index in
                    VStack(spacing: 10) {
                        Circle()
                            .fill(controlLive(index) ? accent : accent.opacity(0.42))
                            .frame(width: CGFloat(28 + controlValue(index) * 7), height: CGFloat(28 + controlValue(index) * 7))
                        Capsule()
                            .fill(.white.opacity(0.14))
                            .frame(width: 3, height: 42)
                        Text(spec.controls[index].label.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    if index != spec.controls.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(controlLive(index) ? accent : .white.opacity(0.16))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    private func hive(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<84, id: \.self) { index in
                let column = CGFloat(index % 12)
                let row = CGFloat(index / 12)
                let jitter = CGFloat((index * 17) % 9) - 4
                let controller = index % spec.controls.count
                let converged = controlLive(controller)
                Capsule()
                    .fill(converged ? accent.opacity(0.78) : .white.opacity(0.22))
                    .frame(width: 4, height: 12)
                    .rotationEffect(.degrees(converged ? 42 : Double((controlValue(controller) + index) * 31 % 180)))
                    .position(x: size.width * (0.18 + column / 15) + jitter, y: size.height * (0.22 + row / 10))
            }
            systemNode(isSolved ? "HIVE" : "LOCAL", active: isSolved, target: true)
                .position(x: size.width * 0.74, y: size.height * 0.72)
        }
    }

    private func firewall(size: CGSize) -> some View {
        HStack(spacing: 18) {
            VStack(spacing: 9) {
                ForEach(0..<8, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 3) ? .white.opacity(0.22) : accent.opacity(0.48))
                        .frame(width: 62, height: 12)
                }
            }
            VStack(spacing: 8) {
                ForEach(0..<spec.controls.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(controlLive(index) ? accent : .black.opacity(0.8))
                        .frame(width: 46, height: 34)
                        .overlay(Text(spec.controls[index].states[controlValue(index)].prefix(4).uppercased()).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(controlLive(index) ? .black : accent))
                }
            }
            Rectangle()
                .fill(accent.opacity(isSolved ? 0.9 : 0.28))
                .frame(width: 5, height: size.height * 0.58)
            VStack(spacing: 13) {
                Image(systemName: "checkmark.shield.fill")
                Image(systemName: "xmark.shield.fill")
                Image(systemName: "checkmark.shield.fill")
            }
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(isSolved ? accent : .white.opacity(0.22))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func queue(size: CGSize) -> some View {
        AnyView(
            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<12, id: \.self) { index in
                        let controller = index % spec.controls.count
                        RoundedRectangle(cornerRadius: 5)
                            .fill(index < (controlValue(controller) + 1) * 3 ? accent.opacity(controlLive(controller) ? 0.86 : 0.44) : .white.opacity(0.08))
                            .frame(width: 16, height: CGFloat(22 + index % 4 * 7))
                    }
                }
                Capsule()
                    .fill(isSolved ? accent : .white.opacity(0.16))
                    .frame(width: size.width * 0.58, height: 8)
                Text(isSolved ? "STABLE SERVICE" : "REQUEST PRESSURE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(isSolved ? accent : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    private func elevator(size: CGSize) -> some View {
        AnyView(
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(0..<spec.controls.count, id: \.self) { index in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.15), lineWidth: 2)
                            .frame(width: 44, height: size.height * 0.58)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(accent.opacity(0.42 + Double(controlValue(index)) * 0.12))
                            .frame(width: 34, height: 34)
                            .offset(y: -CGFloat(controlValue(index)) / CGFloat(max(1, spec.controls[index].states.count - 1)) * size.height * 0.45)
                        Text(spec.controls[index].label.prefix(1).uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .offset(y: -CGFloat(controlValue(index)) / CGFloat(max(1, spec.controls[index].states.count - 1)) * size.height * 0.45)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    private func clockwork(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<spec.controls.count, id: \.self) { index in
                let positions = [
                    CGPoint(x: size.width * 0.28, y: size.height * 0.48),
                    CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                    CGPoint(x: size.width * 0.72, y: size.height * 0.48),
                    CGPoint(x: size.width * 0.5, y: size.height * 0.68)
                ]
                gear(index)
                    .position(positions[index])
            }
        }
    }

    private func gear(_ index: Int) -> some View {
        let matched = controlLive(index)
        return ZStack {
            Circle()
                .stroke(matched ? accent : accent.opacity(0.42), lineWidth: 4)
            ForEach(0..<8, id: \.self) { tooth in
                Capsule()
                    .fill(matched ? accent : .white.opacity(0.18))
                    .frame(width: 6, height: 14)
                    .offset(y: -38)
                    .rotationEffect(.degrees(Double(tooth) * 45 + Double(controlValue(index)) * 22.5))
            }
            Circle().fill(.black).frame(width: 26, height: 26)
            Capsule()
                .fill(matched ? accent : .white.opacity(0.24))
                .frame(width: 4, height: 31)
                .offset(y: -15)
                .rotationEffect(.degrees(Double(controlValue(index)) * 45))
        }
        .frame(width: 84, height: 84)
    }

    private func market(size: CGSize) -> some View {
        ZStack {
            Canvas { canvas, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let points = ringPoints(count: spec.controls.count, size: canvasSize, radiusScale: 0.28)
                for index in 0..<points.count {
                    var path = Path()
                    path.move(to: points[index])
                    path.addLine(to: center)
                    canvas.stroke(path, with: .color(controlLive(index) ? accent.opacity(0.82) : .white.opacity(0.14)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
            ForEach(0..<spec.controls.count, id: \.self) { index in
                let points = ringPoints(count: spec.controls.count, size: size, radiusScale: 0.28)
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(controlLive(index) ? accent : accent.opacity(0.42))
                        .frame(width: 30, height: CGFloat(24 + controlValue(index) * 10))
                    Text(spec.controls[index].label.prefix(3).uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.68))
                }
                .position(points[index])
            }
            systemNode("BAL", active: isSolved, target: true)
        }
    }

    private func voting(size: CGSize) -> some View {
        AnyView(
            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(0..<spec.controls.count, id: \.self) { index in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(controlLive(index) ? accent : accent.opacity(0.38))
                                .frame(width: 42, height: CGFloat(36 + controlValue(index) * 18))
                            Text(spec.controls[index].label.uppercased())
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.64))
                        }
                    }
                }
                Capsule()
                    .fill(isSolved ? accent : .white.opacity(0.14))
                    .frame(width: size.width * 0.54, height: 8)
                Text(isSolved ? "STABLE MAJORITY" : "SHIFTING COALITION")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isSolved ? accent : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    private func ecosystem(size: CGSize) -> some View {
        ZStack {
            Canvas { canvas, canvasSize in
                let top = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.25)
                let left = CGPoint(x: canvasSize.width * 0.25, y: canvasSize.height * 0.68)
                let right = CGPoint(x: canvasSize.width * 0.75, y: canvasSize.height * 0.68)
                var triangle = Path()
                triangle.move(to: top)
                triangle.addLine(to: left)
                triangle.addLine(to: right)
                triangle.closeSubpath()
                canvas.stroke(triangle, with: .color(isSolved ? accent.opacity(0.84) : .white.opacity(0.18)), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            }
            let points = [
                CGPoint(x: size.width / 2, y: size.height * 0.25),
                CGPoint(x: size.width * 0.25, y: size.height * 0.68),
                CGPoint(x: size.width * 0.75, y: size.height * 0.68)
            ]
            ForEach(0..<spec.controls.count, id: \.self) { index in
                Circle()
                    .fill(controlLive(index) ? accent : accent.opacity(0.42))
                    .frame(width: CGFloat(42 + controlValue(index) * 7), height: CGFloat(42 + controlValue(index) * 7))
                    .overlay(Text(spec.controls[index].label.prefix(1).uppercased()).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(.black.opacity(0.82)))
                    .position(points[index])
            }
        }
    }

    private func factory(size: CGSize) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<spec.controls.count, id: \.self) { index in
                VStack(spacing: 10) {
                    Image(systemName: ["shippingbox.fill", "arrow.triangle.2.circlepath", "slider.horizontal.3", "checkmark.seal.fill"][index])
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(controlLive(index) ? .black : accent)
                        .frame(width: 58, height: 54)
                        .background(controlLive(index) ? accent : .black.opacity(0.76), in: RoundedRectangle(cornerRadius: 10))
                    Text(spec.controls[index].states[controlValue(index)].uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.66))
                }
                if index != spec.controls.count - 1 {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(controlLive(index) ? accent : .white.opacity(0.15))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func antColony(size: CGSize) -> some View {
        ZStack {
            Canvas { canvas, canvasSize in
                let start = CGPoint(x: canvasSize.width * 0.14, y: canvasSize.height * 0.72)
                let food = CGPoint(x: canvasSize.width * 0.84, y: canvasSize.height * 0.24)
                let bends = [
                    CGPoint(x: canvasSize.width * 0.34, y: canvasSize.height * 0.54),
                    CGPoint(x: canvasSize.width * 0.52, y: canvasSize.height * 0.34),
                    CGPoint(x: canvasSize.width * 0.67, y: canvasSize.height * 0.48)
                ]
                var path = Path()
                path.move(to: start)
                for bend in bends {
                    path.addLine(to: bend)
                }
                path.addLine(to: food)
                let strength = CGFloat(values.reduce(0, +)) / CGFloat(max(1, spec.controls.count * 2))
                canvas.stroke(path, with: .color(accent.opacity(isSolved ? 0.9 : 0.28 + min(0.5, strength * 0.35))), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: isSolved ? [] : [6, 7]))
            }
            ForEach(0..<24, id: \.self) { index in
                Capsule()
                    .fill(index % 3 < max(1, values.reduce(0, +)) || isSolved ? accent : .white.opacity(0.22))
                    .frame(width: 5, height: 12)
                    .rotationEffect(.degrees(48))
                    .position(x: size.width * (0.18 + CGFloat(index % 8) * 0.08), y: size.height * (0.68 - CGFloat(index / 8) * 0.16))
            }
            systemNode("FOOD", active: isSolved, target: true)
                .position(x: size.width * 0.84, y: size.height * 0.24)
        }
    }

    private func language(size: CGSize) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                ForEach(0..<spec.controls.count, id: \.self) { index in
                    Text(spec.controls[index].states[controlValue(index)].uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(controlLive(index) ? .black : accent)
                        .frame(width: 64, height: 34)
                        .background(controlLive(index) ? accent : .black.opacity(0.75), in: RoundedRectangle(cornerRadius: 7))
                }
            }
            Canvas { canvas, canvasSize in
                let root = CGPoint(x: canvasSize.width / 2, y: 20)
                let leaves = (0..<spec.controls.count).map { CGPoint(x: canvasSize.width * (0.2 + CGFloat($0) * 0.2), y: canvasSize.height * 0.78) }
                for leaf in leaves {
                    var path = Path()
                    path.move(to: root)
                    path.addLine(to: leaf)
                    canvas.stroke(path, with: .color(isSolved ? accent.opacity(0.78) : .white.opacity(0.14)), lineWidth: 2)
                }
            }
            .overlay(systemNode(isSolved ? "PARSE" : "GRAMMAR", active: isSolved, target: true).offset(y: -38))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func operatingSystem(size: CGSize) -> some View {
        AnyView(
            VStack(spacing: 12) {
                ForEach(0..<spec.controls.count, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text(spec.controls[index].label.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.64))
                            .frame(width: 54, alignment: .trailing)
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.09)).frame(height: 24)
                            Capsule()
                                .fill(controlLive(index) ? accent : accent.opacity(0.46))
                                .frame(width: CGFloat(controlValue(index) + 1) / CGFloat(spec.controls[index].states.count) * size.width * 0.5 + 20, height: 24)
                        }
                        Image(systemName: controlLive(index) ? "cpu.fill" : "hourglass")
                            .foregroundStyle(controlLive(index) ? accent : .white.opacity(0.24))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    private func emergence(size: CGSize) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 8)
        return LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<64, id: \.self) { index in
                let controller = index % spec.controls.count
                let current = (index + controlValue(controller) * (controller + 2)).isMultiple(of: controller + 3)
                let target = (index + solutionValue(controller) * (controller + 2)).isMultiple(of: controller + 3)
                RoundedRectangle(cornerRadius: 4)
                    .fill(current ? accent.opacity(controlLive(controller) ? 0.88 : 0.5) : target ? .white.opacity(0.16) : .white.opacity(0.045))
                    .frame(height: max(17, size.height * 0.052))
            }
        }
        .padding(.horizontal, 42)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func civilization(size: CGSize) -> some View {
        ZStack {
            Canvas { canvas, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let points = ringPoints(count: spec.controls.count, size: canvasSize, radiusScale: 0.3)
                for point in points {
                    var path = Path()
                    path.move(to: point)
                    path.addLine(to: center)
                    canvas.stroke(path, with: .color(isSolved ? accent.opacity(0.8) : .white.opacity(0.14)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
            ForEach(0..<spec.controls.count, id: \.self) { index in
                let points = ringPoints(count: spec.controls.count, size: size, radiusScale: 0.3)
                systemNode(spec.controls[index].label.prefix(1).uppercased(), active: controlLive(index), target: false)
                    .position(points[index])
            }
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSolved ? accent.opacity(0.96) : accent.opacity(0.34), lineWidth: 2.2)
                .frame(width: 104, height: 72)
                .overlay(Text(isSolved ? "SUSTAIN" : "CITY").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(isSolved ? accent : .white.opacity(0.48)))
        }
    }

    private func systemNode(_ label: String, active: Bool, target: Bool) -> some View {
        Text(label)
            .font(.system(size: label.count > 4 ? 9 : 12, weight: .black, design: .monospaced))
            .foregroundStyle(active ? .black : target ? accent : .white.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.54)
            .frame(width: target ? 72 : 50, height: target ? 42 : 38)
            .background(active ? accent : .black.opacity(0.78), in: Capsule())
            .overlay(Capsule().stroke(target ? accent.opacity(0.78) : accent.opacity(active ? 0.8 : 0.3), lineWidth: 1.3))
            .shadow(color: active ? accent.opacity(0.35) : .clear, radius: 10)
    }

    private func ringPoints(count: Int, size: CGSize, radiusScale: CGFloat) -> [CGPoint] {
        let radius = min(size.width, size.height) * radiusScale
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return (0..<count).map { index in
            let angle = Double(index) / Double(max(1, count)) * .pi * 2 - .pi / 2
            return CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
        }
    }

    private func controlValue(_ index: Int) -> Int {
        if values.indices.contains(index) {
            return values[index]
        }
        if stage.start.indices.contains(index) {
            return stage.start[index]
        }
        return 0
    }

    private func solutionValue(_ index: Int) -> Int {
        stage.solution.indices.contains(index) ? stage.solution[index] : 0
    }

    private var differenceCount: Int {
        zip(values, stage.solution).filter { pair in pair.0 != pair.1 }.count
    }

    private var liveReadout: String {
        if isSolved {
            return "\(stage.prompt): system is stable. Press LOCK."
        }

        switch spec.visual {
        case .switchboard:
            let closed = values.filter { $0 == 1 }.count
            return "Power sees \(closed) closed switch\(plural(closed)); look for one clean route to the bulb."
        case .cascade:
            let active = values.indices.filter { stateName($0) != "block" }.count
            return "Pulse can enter \(active) node\(plural(active)); blocked or mistimed rules stop the cascade."
        case .traffic:
            let moving = values.indices.filter { ["go", "turn"].contains(stateName($0)) }.count
            return "Intersection has \(moving) moving approach\(plural(moving)); collisions happen when phases share the box."
        case .filter:
            let passRules = values.indices.filter { ["AND", "OR", "PASS"].contains(stateName($0)) }.count
            return "\(passRules) gate\(plural(passRules)) currently pass particles; noise needs a rejecting rule."
        case .feedback:
            let energy = values.reduce(0, +)
            return "Loop energy is \(energy); positive gain must be tempered by correction and damping."
        case .routing:
            let relays = values.indices.filter { stateName($0) != "offline" }.count
            return "\(relays) relay\(plural(relays)) are awake; damaged links need a continuous detour."
        case .priority:
            let first = spec.controls.indices.filter { stateName($0) == "first" }.map { spec.controls[$0].label.uppercased() }
            return first.isEmpty ? "No lane owns the channel yet." : "\(first.joined(separator: "+")) claims first access; ties still block arbitration."
        case .synchronize:
            let phases = Set(values)
            return phases.count == 1 ? "All machines share a phase; test the beat." : "\(phases.count) phases are still active."
        case .deadlock:
            let breaks = values.indices.filter { ["release", "swap"].contains(stateName($0)) }.count
            return "\(breaks) wait edge\(plural(breaks)) are broken; the cycle must lose its hold."
        case .signal:
            let readable = values.indices.filter { ["clean", "boost"].contains(stateName($0)) }.count
            return "\(readable) repeater\(plural(readable)) preserve the pulse; weak or clipped hops corrupt it."
        case .hive:
            let rulePower = values.reduce(0, +)
            return "Local rule strength is \(rulePower); alignment, spacing, and seeking must cooperate."
        case .firewall:
            let defensive = values.indices.filter { ["block", "inspect", "quarantine"].contains(stateName($0)) }.count
            return "\(defensive) defensive rule\(plural(defensive)) are active; safe packets still need a path."
        case .queue:
            let pressure = controlValue(0) + controlValue(2) - controlValue(1)
            return pressure <= 0 ? "Service is catching demand; test the line." : "Queue pressure is +\(pressure); service or buffer must absorb it."
        case .elevator:
            return "Cars are staged at \(values.map { "\($0 + 1)" }.joined(separator: "-")); minimize reversals."
        case .clockwork:
            let marks = values.filter { $0 == 0 || $0 == 2 }.count
            return "\(marks) timing mark\(plural(marks)) are on a cardinal tooth; seek a common beat."
        case .market:
            let stores = values.indices.filter { stateName($0) == "store" }.count
            return "\(stores) region\(plural(stores)) are storing resources; imports and exports must balance demand."
        case .voting:
            let weight = values.reduce(0, +)
            return "Coalition weight is \(weight); stable outcomes need enough support without swing risk."
        case .ecosystem:
            let spread = (values.max() ?? 0) - (values.min() ?? 0)
            return spread <= 1 ? "Populations are close; test the ecosystem." : "One population still dominates the triangle."
        case .factory:
            let running = values.indices.filter { stateName($0) != "idle" }.count
            return "\(running) station\(plural(running)) are running; one bottleneck can darken the whole line."
        case .internet:
            let backups = values.indices.filter { stateName($0) != "down" }.count
            return "\(backups) fallback link\(plural(backups)) are alive; failed nodes need redundant connectivity."
        case .antColony:
            let marked = values.indices.filter { stateName($0) != "fade" }.count
            return "\(marked) trail\(plural(marked)) carry pheromone; loops should fade while the short path strengthens."
        case .language:
            let sentence = values.indices.map { stateName($0).uppercased() }.joined(separator: " ")
            return "Current parse: \(sentence)."
        case .operatingSystem:
            let budget = values.reduce(0, +)
            return "Allocated budget is \(budget); fairness fails when one task starves."
        case .emergence:
            let rules = values.map(String.init).joined(separator: "-")
            return "Rule code \(rules) is drawing the grid; local changes reshape the global pattern."
        case .civilization:
            let loops = values.indices.filter { stateName($0) == "loop" }.count
            return "\(loops) infrastructure loop\(plural(loops)) are closed; every system must feed another."
        }
    }

    private var solvedReadout: String {
        "\(stage.prompt): clean run confirmed."
    }

    private var diagnosticReadout: String {
        let misses = max(1, differenceCount)
        switch spec.visual {
        case .switchboard:
            return "Test failed: \(misses) switch\(plural(misses)) still create a leak or dark branch."
        case .cascade:
            return "Test failed: the pulse breaks after \(stage.prompt.lowercased()); retune a local transition."
        case .traffic:
            return "Test failed: a vehicle is blocked or two paths contest the center."
        case .filter:
            return "Test failed: at least one particle class reaches the wrong channel."
        case .feedback:
            return "Test failed: the loop still overshoots the stability ring."
        case .routing:
            return "Test failed: the message still touches a missing connection."
        case .priority:
            return "Test failed: the shared channel cannot choose a single winner."
        case .synchronize:
            return "Test failed: one machine fires off-beat."
        case .deadlock:
            return "Test failed: the wait-for cycle still closes."
        case .signal:
            return "Test failed: a repeater weakens or clips the pulse."
        case .hive:
            return "Test failed: local rules scatter the swarm before it converges."
        case .firewall:
            return "Test failed: a safe packet is blocked or a harmful one slips through."
        case .queue:
            return "Test failed: requests still outrun service before the buffer recovers."
        case .elevator:
            return "Test failed: the dispatch path makes an avoidable reversal."
        case .clockwork:
            return "Test failed: the gears do not share a common alignment."
        case .market:
            return "Test failed: a region still starves or overflows."
        case .voting:
            return "Test failed: the coalition can still be overturned."
        case .ecosystem:
            return "Test failed: predator, prey, and resources do not settle together."
        case .factory:
            return "Test failed: a station bottleneck blocks finished output."
        case .internet:
            return "Test failed: a failure still disconnects start from goal."
        case .antColony:
            return "Test failed: pheromone reinforces a loop or longer path."
        case .language:
            return "Test failed: the grammar parses ambiguously."
        case .operatingSystem:
            return "Test failed: one task starves or the system exceeds budget."
        case .emergence:
            return "Test failed: local rules draw the wrong global pattern."
        case .civilization:
            return "Test failed: one infrastructure loop still drains another."
        }
    }

    private func stateName(_ index: Int) -> String {
        guard spec.controls.indices.contains(index) else { return "" }
        let control = spec.controls[index]
        let value = controlValue(index)
        guard control.states.indices.contains(value) else { return "" }
        return control.states[value]
    }

    private func controlLive(_ index: Int) -> Bool {
        let state = stateName(index)
        switch spec.visual {
        case .switchboard:
            return state == "closed"
        case .cascade:
            return state != "block"
        case .traffic:
            return state == "go" || state == "turn"
        case .filter:
            return state == "AND" || state == "OR" || state == "PASS"
        case .feedback:
            return abs(controlValue(index) - solutionValue(index)) <= 1
        case .routing:
            return state != "offline"
        case .priority:
            return state == "first"
        case .synchronize, .clockwork:
            return controlValue(index) == solutionValue(index)
        case .deadlock:
            return state == "release" || state == "swap"
        case .signal:
            return state == "clean" || state == "boost"
        case .hive:
            return state != "off"
        case .firewall:
            return state != "allow"
        case .queue:
            return controlValue(index) > 0
        case .elevator:
            return true
        case .market:
            return state != "consume"
        case .voting:
            return controlValue(index) > 0
        case .ecosystem:
            return abs(controlValue(index) - solutionValue(index)) <= 1
        case .factory:
            return state != "idle"
        case .internet:
            return state != "down"
        case .antColony:
            return state != "fade"
        case .language:
            return true
        case .operatingSystem:
            return state != "low"
        case .emergence:
            return controlValue(index) == solutionValue(index)
        case .civilization:
            return state != "short"
        }
    }

    private func plural(_ count: Int) -> String {
        count == 1 ? "" : "s"
    }

    private func cycle(_ index: Int, by delta: Int) {
        guard !completed, values.indices.contains(index) else { return }
        let count = spec.controls[index].states.count
        values[index] = (values[index] + delta + count) % count
        validatedControls.removeAll()
        feedbackText = nil
        HapticPlayer.playLightTap()
    }

    private func checkStage() {
        guard !completed else { return }

        if isSolved {
            HapticPlayer.playCompletionTap()
            validatedControls = Set(stage.solution.indices)
            feedbackText = solvedReadout
            if stageIndex == spec.stages.count - 1 {
                withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                    completed = true
                }
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    loadStage(stageIndex + 1)
                }
            }
        } else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                validatedControls.removeAll()
                feedbackText = diagnosticReadout
                wrongPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
                    wrongPulse = false
                }
            }
        }
    }

    private func loadStage(_ index: Int) {
        let clampedIndex = min(max(0, index), spec.stages.count - 1)
        stageIndex = clampedIndex
        values = spec.stages[clampedIndex].start
        showingGoal = false
        wrongPulse = false
        feedbackText = nil
        validatedControls.removeAll()
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            completed = false
            loadStage(0)
        }
    }

    private func closeGoal() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            showingGoal = false
        }
    }
}

private struct MathItSystemLevelSpec {
    let number: Int
    let title: String
    let pairing: String
    let objective: String
    let rules: String
    let winCondition: String
    let learningGoal: String
    let resetBehavior: String
    let badgeIcon: String
    let controls: [MathItSystemControl]
    let stages: [MathItSystemStage]
    let visual: MathItSystemVisual
}

private struct MathItSystemControl {
    let label: String
    let icon: String
    let states: [String]
}

private struct MathItSystemStage {
    let prompt: String
    let solution: [Int]
    let start: [Int]
}

private enum MathItSystemVisual {
    case switchboard
    case cascade
    case traffic
    case filter
    case feedback
    case routing
    case priority
    case synchronize
    case deadlock
    case signal
    case hive
    case firewall
    case queue
    case elevator
    case clockwork
    case market
    case voting
    case ecosystem
    case factory
    case internet
    case antColony
    case language
    case operatingSystem
    case emergence
    case civilization
}

private extension MathItSystemLevelSpec {
    static func level(_ number: Int) -> MathItSystemLevelSpec {
        specs[number] ?? specs[100]!
    }

    static let specs: [Int: MathItSystemLevelSpec] = [
        76: make(
            76, "switchboard", "circuits x graph routing",
            "Route power through a network of switches to illuminate the target bulb.",
            "Cycle each switch between open and closed. The glowing wire path shows where power can travel.",
            "All required switches must form the only live path into the bulb.",
            "A circuit is a graph: local switch states decide whether a global path exists.",
            "lightbulb.fill",
            controls: controls(["A", "B", "C", "D"], ["open", "closed"], "switch.2"),
            stages: [
                stage("BULB A", [1, 0, 1, 1], [0, 1, 0, 0]),
                stage("BULB B", [1, 1, 0, 1], [0, 0, 1, 0]),
                stage("BULB C", [0, 1, 1, 0], [1, 0, 0, 1])
            ],
            visual: .switchboard
        ),
        77: make(
            77, "cascade", "systems x chain reaction",
            "Trigger a chain reaction where each activated node powers the next.",
            "Set each node to pass, split, delay, or block. A wrong local rule stops the pulse.",
            "The pulse must visit every node and finish at the final receiver.",
            "Cascades turn small local transitions into large system behavior.",
            "point.3.connected.trianglepath.dotted",
            controls: controls(["seed", "relay", "branch", "sink"], ["block", "pass", "split", "delay"], "bolt.fill"),
            stages: [
                stage("START PULSE", [1, 3, 2, 1], [0, 1, 0, 2]),
                stage("BRANCH FIRST", [2, 1, 3, 1], [1, 0, 2, 0]),
                stage("DELAY MIDDLE", [1, 2, 3, 1], [3, 1, 0, 2])
            ],
            visual: .cascade
        ),
        78: make(
            78, "traffic", "logic x motion planning",
            "Control intersections so every vehicle reaches its destination without collisions.",
            "Each signal can stop, go, turn, or hold. Compatible phases glow without crossing.",
            "Run a full safe phase plan for all approaches.",
            "Traffic control is a constraint problem over shared space and time.",
            "trafficlight",
            controls: controls(["north", "east", "south", "west"], ["stop", "go", "turn", "hold"], "trafficlight"),
            stages: [
                stage("CLEAR STRAIGHTS", [1, 0, 1, 0], [0, 1, 0, 2]),
                stage("PROTECT TURNS", [2, 3, 0, 2], [1, 0, 2, 1]),
                stage("PEDESTRIAN GAP", [0, 3, 0, 3], [2, 1, 2, 1])
            ],
            visual: .traffic
        ),
        79: make(
            79, "filter", "logic gates x classification",
            "Separate mixed particles into correct output channels using logic gates.",
            "Tune each gate rule. The output lane brightens when that particle class is accepted.",
            "Every particle type must reach its matching channel and no other channel.",
            "Filtering uses predicates: each gate decides whether data belongs downstream.",
            "line.3.horizontal.decrease",
            controls: controls(["round", "bright", "heavy"], ["AND", "OR", "NOT", "PASS"], "circle.grid.cross"),
            stages: [
                stage("SORT MIX", [0, 2, 3], [1, 0, 2]),
                stage("BLOCK NOISE", [2, 0, 1], [3, 1, 0]),
                stage("PASS SIGNAL", [3, 1, 0], [0, 2, 1])
            ],
            visual: .filter
        ),
        80: make(
            80, "feedback", "control x stability",
            "Balance a runaway system by adjusting positive and negative feedback loops.",
            "Positive gain accelerates change, negative feedback corrects it, and damping slows overshoot.",
            "The response spiral must settle inside the stable target ring.",
            "Stable systems balance amplification with correction and delay.",
            "arrow.triangle.2.circlepath",
            controls: controls(["positive", "negative", "damping"], ["low", "medium", "high", "max"], "waveform.path.ecg"),
            stages: [
                stage("STOP OVERSHOOT", [1, 2, 2], [3, 0, 0]),
                stage("KEEP RESPONSE", [2, 1, 3], [0, 3, 1]),
                stage("SETTLE FAST", [1, 3, 2], [2, 0, 0])
            ],
            visual: .feedback
        ),
        81: make(
            81, "routing", "networks x resilience",
            "Deliver a message through a damaged network with missing connections.",
            "Choose which relays stay active. Dashed links are broken and cannot carry the white pulse.",
            "The message must route from S to G without touching a failed link.",
            "Routing finds viable paths when parts of a graph disappear.",
            "point.3.filled.connected.trianglepath.dotted",
            controls: controls(["north", "bridge", "south", "exit"], ["offline", "relay", "reroute"], "antenna.radiowaves.left.and.right"),
            stages: [
                stage("BYPASS GAP", [1, 2, 1, 2], [0, 1, 0, 1]),
                stage("USE SOUTH", [2, 0, 1, 2], [1, 2, 0, 0]),
                stage("RESTORE BRIDGE", [1, 1, 2, 1], [2, 0, 1, 0])
            ],
            visual: .routing
        ),
        82: make(
            82, "priority", "arbitration x order",
            "Multiple signals compete for one channel; determine which reaches the goal first.",
            "Assign priority to each lane. The strongest valid lane should enter the shared channel first.",
            "The channel must accept the winning signal and defer the rest.",
            "Priority rules resolve contention without letting every request through at once.",
            "arrow.up.arrow.down.circle.fill",
            controls: controls(["red", "blue", "green"], ["last", "middle", "first"], "flag.checkered"),
            stages: [
                stage("URGENT RED", [2, 1, 0], [0, 2, 1]),
                stage("GREEN WINS", [0, 1, 2], [1, 2, 0]),
                stage("BLUE WINS", [1, 2, 0], [2, 0, 1])
            ],
            visual: .priority
        ),
        83: make(
            83, "synchronize", "timing x phase",
            "Several independent machines must activate simultaneously.",
            "Shift each machine's phase until every hand reaches the top together.",
            "All clocks must align on the same activation beat.",
            "Synchronization coordinates independent cycles by correcting phase offsets.",
            "clock.fill",
            controls: controls(["press", "lift", "seal", "cool"], ["0", "90", "180", "270"], "timer"),
            stages: [
                stage("COMMON BEAT", [0, 0, 0, 0], [1, 2, 3, 1]),
                stage("HALF TURN", [2, 2, 2, 2], [0, 1, 3, 0]),
                stage("QUARTER LOCK", [1, 1, 1, 1], [3, 0, 2, 3])
            ],
            visual: .synchronize
        ),
        84: make(
            84, "deadlock", "systems x wait graphs",
            "Two systems wait on each other indefinitely; break the cycle.",
            "Change each process request to release, wait, hold, or swap. Broken wait edges turn dashed.",
            "Every process must have an acyclic way to finish.",
            "Deadlock is a cycle in a wait-for graph; breaking one edge releases the system.",
            "lock.open.fill",
            controls: controls(["P1", "P2", "P3", "P4"], ["wait", "hold", "release", "swap"], "lock.rotation"),
            stages: [
                stage("BREAK CYCLE", [2, 1, 0, 3], [0, 0, 1, 1]),
                stage("FREE P2", [1, 2, 3, 0], [3, 0, 1, 2]),
                stage("ORDER FINISH", [3, 2, 1, 0], [0, 1, 2, 3])
            ],
            visual: .deadlock
        ),
        85: make(
            85, "signal", "communication x repeaters",
            "Transmit a pulse through repeaters without degrading the message.",
            "Set each repeater's boost so the pulse stays strong but does not distort.",
            "The pulse must arrive at the receiver at readable strength.",
            "Long-range communication preserves information by restoring weak signals.",
            "dot.radiowaves.right",
            controls: controls(["R1", "R2", "R3", "R4"], ["weak", "clean", "boost", "clip"], "waveform"),
            stages: [
                stage("CLEAN PULSE", [1, 2, 1, 2], [0, 0, 3, 1]),
                stage("LONG HOP", [2, 1, 2, 1], [1, 3, 0, 0]),
                stage("NO CLIP", [1, 1, 2, 2], [3, 2, 0, 1])
            ],
            visual: .signal
        ),
        86: make(
            86, "hive", "emergence x local rules",
            "Simple local rules guide hundreds of agents toward a shared objective.",
            "Tune the three local behaviors. Agents turn from scattered marks into an organized swarm.",
            "The swarm must converge on the shared target.",
            "Collective behavior can emerge without a central controller.",
            "hexagon.fill",
            controls: controls(["align", "avoid", "seek"], ["off", "low", "high"], "circle.hexagongrid.fill"),
            stages: [
                stage("FIND CENTER", [1, 2, 2], [0, 0, 1]),
                stage("AVOID CROWD", [2, 2, 1], [1, 0, 0]),
                stage("FLOW RIGHT", [2, 1, 2], [0, 2, 0])
            ],
            visual: .hive
        ),
        87: make(
            87, "firewall", "security x rules",
            "Allow safe packets through while blocking harmful ones.",
            "Each rule can allow, block, inspect, or quarantine matching packets.",
            "Safe packets must pass and unsafe packets must stop at the wall.",
            "Security policies are layered filters with different actions.",
            "checkmark.shield.fill",
            controls: controls(["known", "script", "large"], ["allow", "block", "inspect", "quarantine"], "shield.lefthalf.filled"),
            stages: [
                stage("BLOCK SCRIPT", [0, 1, 2], [1, 0, 0]),
                stage("CHECK LARGE", [0, 3, 2], [2, 1, 1]),
                stage("STRICT WALL", [2, 1, 3], [0, 0, 1])
            ],
            visual: .firewall
        ),
        88: make(
            88, "queue", "operations x throughput",
            "Manage a growing line of requests before the system overloads.",
            "Balance intake, service, and buffer size. The queue is stable only when service catches demand.",
            "The request line must stay below the overload marker.",
            "Queues reveal how rate, capacity, and delay interact.",
            "tray.full.fill",
            controls: controls(["intake", "service", "buffer"], ["low", "steady", "fast", "burst"], "list.bullet.rectangle"),
            stages: [
                stage("ABSORB BURST", [2, 3, 2], [3, 0, 0]),
                stage("STEADY FLOW", [1, 2, 1], [2, 0, 3]),
                stage("NO OVERLOAD", [0, 2, 3], [3, 1, 0])
            ],
            visual: .queue
        ),
        89: make(
            89, "elevator", "optimization x routing",
            "Optimize routes to transport everyone using minimal movement.",
            "Choose stop order and direction. Each car should serve nearby requests before reversing.",
            "All passengers must be delivered with the shortest combined travel.",
            "Elevator dispatching clusters requests to reduce wasted movement.",
            "arrow.up.arrow.down.square.fill",
            controls: controls(["car A", "car B", "express"], ["floor 1", "floor 2", "floor 3", "floor 4"], "building.2.fill"),
            stages: [
                stage("MORNING UP", [0, 2, 3], [3, 0, 1]),
                stage("LOBBY SPLIT", [1, 3, 0], [0, 1, 2]),
                stage("EXPRESS RUN", [2, 0, 3], [1, 3, 0])
            ],
            visual: .elevator
        ),
        90: make(
            90, "clockwork", "mechanics x modular cycles",
            "Multiple gears rotate at different rates and must align.",
            "Set each gear phase. Teeth glow when their timing mark returns to the shared top point.",
            "Every gear's mark must align at the same instant.",
            "Different cycle lengths align at common multiples.",
            "gearshape.2.fill",
            controls: controls(["small", "middle", "large", "idler"], ["0", "1/4", "1/2", "3/4"], "gearshape.fill"),
            stages: [
                stage("TOP MARKS", [0, 0, 0, 0], [1, 2, 3, 1]),
                stage("HALF SYNC", [2, 2, 2, 2], [0, 1, 3, 0]),
                stage("OFFSET SYNC", [1, 3, 1, 3], [3, 0, 2, 1])
            ],
            visual: .clockwork
        ),
        91: make(
            91, "market", "economics x flow",
            "Resources flow between regions; prevent shortages and surpluses.",
            "Set each region to import, export, store, or consume. Balanced regions glow around the hub.",
            "No region may starve or overflow.",
            "Markets stabilize when supply, demand, and storage balance across the network.",
            "chart.line.uptrend.xyaxis",
            controls: controls(["north", "east", "south", "west"], ["import", "export", "store", "consume"], "arrow.left.arrow.right"),
            stages: [
                stage("MOVE GRAIN", [1, 0, 2, 3], [3, 1, 0, 0]),
                stage("FILL SOUTH", [0, 2, 1, 3], [1, 3, 0, 2]),
                stage("STOP GLUT", [2, 3, 0, 1], [0, 0, 2, 3])
            ],
            visual: .market
        ),
        92: make(
            92, "voting", "social choice x equilibrium",
            "Different groups influence a decision; achieve a stable outcome.",
            "Set each group's influence. A coalition becomes stable when no side can overturn it.",
            "The vote bars must settle into a durable majority.",
            "Stable decisions depend on weights, coalitions, and thresholds.",
            "person.3.fill",
            controls: controls(["labor", "trade", "science"], ["low", "medium", "high"], "checkmark.seal.fill"),
            stages: [
                stage("BUILD MAJORITY", [2, 1, 1], [0, 2, 0]),
                stage("STOP SWING", [1, 2, 1], [2, 0, 2]),
                stage("CONSENSUS", [1, 1, 2], [0, 2, 1])
            ],
            visual: .voting
        ),
        93: make(
            93, "ecosystem", "ecology x dynamic balance",
            "Predators, prey, and resources must remain in balance.",
            "Adjust each population level. Too much of one corner collapses the triangle.",
            "All three populations must stabilize together.",
            "Ecosystems are feedback systems between food, consumers, and limits.",
            "leaf.fill",
            controls: controls(["prey", "predator", "resource"], ["scarce", "stable", "abundant"], "circle.lefthalf.filled"),
            stages: [
                stage("RESTORE PREY", [2, 1, 2], [0, 2, 0]),
                stage("CALM PREDATORS", [1, 1, 2], [2, 2, 0]),
                stage("BALANCE FOOD", [1, 2, 1], [0, 0, 2])
            ],
            visual: .ecosystem
        ),
        94: make(
            94, "factory", "processes x transformation",
            "Build an efficient production line that transforms inputs into outputs.",
            "Tune each station: feed, transform, inspect, and ship. Bottlenecks darken the conveyor.",
            "Inputs must become finished outputs with no blocked station.",
            "Factories compose transformations; throughput is limited by the slowest stage.",
            "shippingbox.fill",
            controls: controls(["feed", "shape", "inspect", "ship"], ["idle", "slow", "match", "fast"], "slider.horizontal.3"),
            stages: [
                stage("FIRST LINE", [2, 2, 1, 3], [0, 1, 3, 0]),
                stage("NO WASTE", [1, 2, 2, 3], [3, 0, 0, 1]),
                stage("FAST SHIP", [3, 1, 2, 3], [0, 3, 1, 0])
            ],
            visual: .factory
        ),
        95: make(
            95, "internet", "networks x fault tolerance",
            "Reroute data around failed nodes while maintaining connectivity.",
            "Choose fallback links and mirrors. The white data pulse must avoid failed nodes.",
            "Start and goal must remain connected after failures.",
            "The internet survives outages by routing around damage.",
            "network",
            controls: controls(["edge", "cache", "mirror", "exit"], ["down", "direct", "backup"], "externaldrive.connected.to.line.below"),
            stages: [
                stage("NODE DOWN", [2, 1, 2, 1], [0, 2, 0, 2]),
                stage("CACHE PATH", [1, 2, 1, 2], [2, 0, 2, 0]),
                stage("DOUBLE FAIL", [2, 2, 1, 1], [1, 0, 0, 2])
            ],
            visual: .internet
        ),
        96: make(
            96, "ant colony", "optimization x pheromone trails",
            "Use pheromone trails to discover the shortest path.",
            "Strengthen or fade each trail. Shorter paths should gain the strongest pheromone.",
            "The colony must converge on the shortest route to food.",
            "Ant-colony search reinforces successful local choices into a global optimum.",
            "point.topleft.down.curvedto.point.bottomright.up",
            controls: controls(["left", "middle", "right"], ["fade", "mark", "strong"], "circle.dotted"),
            stages: [
                stage("FIND FOOD", [1, 2, 0], [2, 0, 1]),
                stage("AVOID LOOP", [0, 2, 1], [1, 0, 2]),
                stage("SHORTEST", [2, 1, 0], [0, 2, 1])
            ],
            visual: .antColony
        ),
        97: make(
            97, "language", "grammar x interpretation",
            "Construct a grammar system that correctly interprets messages.",
            "Choose productions for subject, action, object, and ending. The parse tree glows when it reads cleanly.",
            "The grammar must parse the message without ambiguity.",
            "Formal languages use rules to turn symbol strings into meaning.",
            "textformat.abc",
            controls: controls(["subject", "verb", "object", "end"], ["noun", "verb", "phrase", "stop"], "curlybraces"),
            stages: [
                stage("READ COMMAND", [0, 1, 2, 3], [2, 0, 1, 0]),
                stage("READ QUESTION", [2, 1, 0, 3], [0, 2, 1, 1]),
                stage("READ SIGNAL", [0, 2, 1, 3], [1, 0, 2, 0])
            ],
            visual: .language
        ),
        98: make(
            98, "operating system", "computing x resource allocation",
            "Allocate limited processing power among competing tasks.",
            "Assign CPU time, memory, IO, and priority so no task starves.",
            "Every task must receive enough resources without exceeding the system budget.",
            "Operating systems balance fairness, responsiveness, and resource limits.",
            "cpu.fill",
            controls: controls(["cpu", "memory", "io", "priority"], ["low", "fair", "high", "burst"], "cpu"),
            stages: [
                stage("FAIR SHARE", [1, 1, 1, 2], [3, 0, 0, 0]),
                stage("IO WAIT", [1, 2, 3, 1], [0, 0, 1, 3]),
                stage("URGENT TASK", [2, 1, 1, 3], [0, 3, 2, 0])
            ],
            visual: .operatingSystem
        ),
        99: make(
            99, "emergence", "complexity x simple rules",
            "Create complex behavior using only a few simple rules.",
            "Tune birth, survival, and drift rules. The grid shows the pattern produced by local decisions.",
            "The live cells must match the target emergent pattern.",
            "Complex global patterns can arise from short local update rules.",
            "square.grid.3x3.fill",
            controls: controls(["birth", "survive", "drift"], ["0", "1", "2", "3"], "square.grid.3x3"),
            stages: [
                stage("SPOTS", [1, 2, 0], [3, 0, 1]),
                stage("STRIPES", [2, 1, 3], [0, 3, 1]),
                stage("GROWTH", [3, 2, 1], [1, 0, 2])
            ],
            visual: .emergence
        ),
        100: make(
            100, "civilization", "systems x sustainability",
            "Design interconnected systems - water, food, energy, transport - that sustain themselves indefinitely.",
            "Balance each subsystem. Connections glow only when every dependency can feed the others.",
            "The city must sustain all four systems without a hidden shortage.",
            "Civilizations endure when infrastructure loops support each other instead of draining one another.",
            "building.columns.fill",
            controls: controls(["water", "food", "energy", "transport"], ["short", "steady", "surplus", "loop"], "building.2.crop.circle"),
            stages: [
                stage("FOUNDATION", [1, 1, 1, 1], [0, 2, 0, 3]),
                stage("CLOSED LOOP", [3, 1, 2, 3], [1, 3, 0, 0]),
                stage("SELF SUSTAIN", [2, 2, 3, 3], [0, 1, 1, 2])
            ],
            visual: .civilization
        )
    ]

    static func make(
        _ number: Int,
        _ title: String,
        _ pairing: String,
        _ objective: String,
        _ rules: String,
        _ winCondition: String,
        _ learningGoal: String,
        _ badgeIcon: String,
        controls: [MathItSystemControl],
        stages: [MathItSystemStage],
        visual: MathItSystemVisual,
        resetBehavior: String = "Replay returns to stage one and restores every control to its designed starting state."
    ) -> MathItSystemLevelSpec {
        MathItSystemLevelSpec(
            number: number,
            title: title,
            pairing: pairing,
            objective: objective,
            rules: rules,
            winCondition: winCondition,
            learningGoal: learningGoal,
            resetBehavior: resetBehavior,
            badgeIcon: badgeIcon,
            controls: controls,
            stages: stages,
            visual: visual
        )
    }

    static func controls(_ labels: [String], _ states: [String], _ icon: String) -> [MathItSystemControl] {
        labels.map { MathItSystemControl(label: $0, icon: icon, states: states) }
    }

    static func stage(_ prompt: String, _ solution: [Int], _ start: [Int]) -> MathItSystemStage {
        MathItSystemStage(prompt: prompt, solution: solution, start: start)
    }
}
