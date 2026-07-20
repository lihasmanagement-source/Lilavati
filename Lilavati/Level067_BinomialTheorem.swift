import SwiftUI

struct MathItLevelOneHundredTwentySixView: View {
    private let depths = [2, 3, 4]
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.31, blue: 0.25)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var filled: [Int: Int] = [:]
    @State private var selected: Int?
    @State private var wrongChoice: Int?
    @State private var highlightedRoute: Int?
    @State private var routeProgress: CGFloat = 0
    @State private var stageSolved = false
    @State private var completed = false
    @State private var animationToken = UUID()

    private var depth: Int { depths[stageIndex] }
    private var row: [Int] { pascalRow(depth) }
    private var previousRow: [Int] { pascalRow(depth - 1) }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.022, green: 0.032, blue: 0.046).ignoresSafeArea()

                VStack(spacing: compact ? 8 : 13) {
                    header
                        .padding(.top, compact ? 10 : 20)

                    cityMap
                        .frame(maxWidth: 880)
                        .frame(height: max(410, min(540, proxy.size.height * 0.62)))

                    controlPanel(compact: compact)
                        .frame(maxWidth: 760)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, compact ? 12 : 20)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 68 Completed",
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
                ForEach(depths.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stageIndex ? cyan : index == stageIndex ? gold : .white.opacity(0.13))
                        .frame(width: index == stageIndex ? 42 : 24, height: 5)
                }
            }

            Text("DISTRICT \(stageIndex + 1) · \(depth)-BLOCK BOUNDARY")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(gold)

            EmptyView()
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(stageSolved ? cyan : .white)
        }
    }

    private var cityMap: some View {
        GeometryReader { geo in
            let plot = mapRect(in: geo.size)

            ZStack {
                Canvas { context, _ in
                    drawBlocks(context: &context, plot: plot)
                    drawStreets(context: &context, plot: plot)
                    drawFeeders(context: &context, plot: plot)
                    drawKnownIntersections(context: &context, plot: plot)
                    drawRoute(context: &context, plot: plot)
                }

                depotLabel(plot: plot)

                ForEach(0...depth, id: \.self) { index in
                    destinationButton(index: index, plot: plot)
                }

                if let highlightedRoute {
                    courier(route: highlightedRoute, plot: plot)
                }

                VStack {
                    HStack {
                        metric("BOUNDARY", "x + y = \(depth)")
                        metric("DESTINATIONS", "\(filled.count) / \(depth + 1)")
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)
            }
            .background(Color(red: 0.035, green: 0.055, blue: 0.069))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func destinationButton(index: Int, plot: CGRect) -> some View {
        let point = nodePoint(x: depth - index, y: index, plot: plot)
        let value = filled[index]
        let isSelected = selected == index

        return Button {
            guard !stageSolved else { return }
            selected = index
            wrongChoice = nil
            highlightedRoute = index
            routeProgress = 0
            withAnimation(.easeInOut(duration: 0.65)) { routeProgress = 1 }
        } label: {
            ZStack {
                Circle()
                    .fill(value == nil ? Color(red: 0.06, green: 0.09, blue: 0.11) : gold)
                Circle()
                    .stroke(isSelected ? cyan : value == nil ? .white.opacity(0.5) : gold, lineWidth: isSelected ? 4 : 2)
                Text(value.map(String.init) ?? "?")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(value == nil ? .white : .black.opacity(0.75))
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .position(point)
        .accessibilityLabel("Boundary destination \(index), \(value.map { "\($0) routes" } ?? "route count unknown")")
    }

    private func depotLabel(plot: CGRect) -> some View {
        let point = nodePoint(x: 0, y: 0, plot: plot)
        return VStack(spacing: 2) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 15, weight: .bold))
            Text("DEPOT")
                .font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .foregroundStyle(.black.opacity(0.72))
        .frame(width: 46, height: 42)
        .background(cyan)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .position(point)
    }

    private func courier(route: Int, plot: CGRect) -> some View {
        let point = routePoint(destination: route, progress: routeProgress, plot: plot)
        return Image(systemName: "car.side.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: cyan, radius: 7)
            .position(point)
    }

    @ViewBuilder
    private func controlPanel(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            if stageSolved {
                Text(expansion)
                    .font(.system(size: compact ? 17 : 21, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("THE BOUNDARY ROUTE TOTALS ARE THE COEFFICIENTS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
            } else if let selected {
                let feeders = feederCounts(for: selected)
                Text("DESTINATION \(selected + 1):  \(feeders.left) + \(feeders.right) = ?")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    ForEach(choices(for: selected), id: \.self) { choice in
                        Button {
                            submit(choice, for: selected)
                        } label: {
                            Text("\(choice) ROUTES")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(wrongChoice == choice ? .white : .black.opacity(0.75))
                                .frame(maxWidth: .infinity)
                                .frame(height: compact ? 38 : 44)
                                .background(wrongChoice == choice ? coral : gold)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("TAP A ? DESTINATION ON THE NEW BOUNDARY")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text("COUNT ALL SHORTEST COMBINATIONS OF EAST AND NORTH STREETS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: compact ? 72 : 88)
    }

    private func submit(_ choice: Int, for destination: Int) {
        let expected = row[destination]
        guard choice == expected else {
            withAnimation(.easeInOut(duration: 0.15)) { wrongChoice = choice }
            let token = animationToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard token == animationToken else { return }
                withAnimation { wrongChoice = nil }
            }
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            filled[destination] = expected
            selected = nil
            wrongChoice = nil
        }

        if filled.count + (filled[destination] == nil ? 1 : 0) == depth + 1 {
            finishStage()
        }
    }

    private func finishStage() {
        stageSolved = true
        let token = animationToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard token == animationToken else { return }
            if stageIndex == depths.count - 1 {
                withAnimation { completed = true }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    stageIndex += 1
                    filled = [:]
                    selected = nil
                    highlightedRoute = nil
                    routeProgress = 0
                    stageSolved = false
                }
            }
        }
    }

    private func resetLevel() {
        animationToken = UUID()
        stageIndex = 0
        filled = [:]
        selected = nil
        wrongChoice = nil
        highlightedRoute = nil
        routeProgress = 0
        stageSolved = false
        completed = false
    }

    private func feederCounts(for destination: Int) -> (left: Int, right: Int) {
        let left = destination > 0 ? previousRow[destination - 1] : 0
        let right = destination < previousRow.count ? previousRow[destination] : 0
        return (left, right)
    }

    private func choices(for destination: Int) -> [Int] {
        let expected = row[destination]
        let base: [Int]
        switch expected {
        case 1: base = [1, 2, 3]
        case 2: base = [1, 2, 3]
        case 3: base = [2, 3, 4]
        case 4: base = [3, 4, 6]
        case 6: base = [4, 6, 8]
        default: base = [max(1, expected - 1), expected, expected + 1]
        }
        let shift = destination % base.count
        return Array(base[shift...] + base[..<shift])
    }

    private var expansion: String {
        let terms = row.enumerated().map { index, coefficient in
            let ePower = depth - index
            let nPower = index
            let coefficientText = coefficient == 1 ? "" : "\(coefficient)"
            return coefficientText + variable("E", power: ePower) + variable("N", power: nPower)
        }
        return "(E + N)\(superscript(depth)) = " + terms.joined(separator: " + ")
    }

    private func variable(_ symbol: String, power: Int) -> String {
        guard power > 0 else { return "" }
        return symbol + (power == 1 ? "" : superscript(power))
    }

    private func superscript(_ value: Int) -> String {
        [2: "²", 3: "³", 4: "⁴"][value] ?? "\(value)"
    }

    private func pascalRow(_ n: Int) -> [Int] {
        guard n > 0 else { return [1] }
        var values = [1]
        for _ in 1...n {
            values = zip([0] + values, values + [0]).map(+)
        }
        return values
    }

    private func mapRect(in size: CGSize) -> CGRect {
        CGRect(x: 74, y: 70, width: max(120, size.width - 148), height: max(120, size.height - 120))
    }

    private func nodePoint(x: Int, y: Int, plot: CGRect) -> CGPoint {
        let step = min(plot.width, plot.height) / CGFloat(depth)
        let used = step * CGFloat(depth)
        let origin = CGPoint(x: plot.midX - used / 2, y: plot.midY + used / 2)
        return CGPoint(x: origin.x + CGFloat(x) * step, y: origin.y - CGFloat(y) * step)
    }

    private func drawStreets(context: inout GraphicsContext, plot: CGRect) {
        for x in 0...depth {
            for y in 0...(depth - x) {
                let point = nodePoint(x: x, y: y, plot: plot)
                if x + y < depth {
                    var east = Path()
                    east.move(to: point)
                    east.addLine(to: nodePoint(x: x + 1, y: y, plot: plot))
                    context.stroke(east, with: .color(.white.opacity(0.24)), lineWidth: 7)

                    var north = Path()
                    north.move(to: point)
                    north.addLine(to: nodePoint(x: x, y: y + 1, plot: plot))
                    context.stroke(north, with: .color(.white.opacity(0.24)), lineWidth: 7)
                }
            }
        }
    }

    private func drawBlocks(context: inout GraphicsContext, plot: CGRect) {
        guard depth > 1 else { return }
        let step = min(plot.width, plot.height) / CGFloat(depth)
        for x in 0..<depth {
            for y in 0..<(depth - x) {
                guard x + y < depth - 1 else { continue }
                let lowerLeft = nodePoint(x: x, y: y, plot: plot)
                let rect = CGRect(x: lowerLeft.x + 9, y: lowerLeft.y - step + 9, width: step - 18, height: step - 18)
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Color(red: 0.08, green: 0.14, blue: 0.16)))
                let roof = CGRect(x: rect.minX + 6, y: rect.minY + 6, width: max(3, rect.width - 12), height: max(3, rect.height - 12))
                context.stroke(Path(roundedRect: roof, cornerRadius: 2), with: .color(cyan.opacity(0.18)), lineWidth: 1)
            }
        }
    }

    private func drawKnownIntersections(context: inout GraphicsContext, plot: CGRect) {
        for index in previousRow.indices {
            let point = nodePoint(x: depth - 1 - index, y: index, plot: plot)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)), with: .color(cyan.opacity(0.9)))
            context.draw(Text("\(previousRow[index])").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.black.opacity(0.7)), at: point)
        }
    }

    private func drawFeeders(context: inout GraphicsContext, plot: CGRect) {
        guard let selected else { return }
        let destination = nodePoint(x: depth - selected, y: selected, plot: plot)
        let sources = [
            selected > 0 ? nodePoint(x: depth - selected, y: selected - 1, plot: plot) : nil,
            selected < depth ? nodePoint(x: depth - selected - 1, y: selected, plot: plot) : nil
        ]
        for source in sources.compactMap({ $0 }) {
            var path = Path()
            path.move(to: source)
            path.addLine(to: destination)
            context.stroke(path, with: .color(gold), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        }
    }

    private func drawRoute(context: inout GraphicsContext, plot: CGRect) {
        guard let route = highlightedRoute else { return }
        let eastMoves = depth - route
        var points = [nodePoint(x: 0, y: 0, plot: plot)]
        if eastMoves > 0 {
            for x in 1...eastMoves { points.append(nodePoint(x: x, y: 0, plot: plot)) }
        }
        if route > 0 {
            for y in 1...route { points.append(nodePoint(x: eastMoves, y: y, plot: plot)) }
        }
        var path = Path()
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        context.stroke(path, with: .color(cyan), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
    }

    private func routePoint(destination: Int, progress: CGFloat, plot: CGRect) -> CGPoint {
        let eastMoves = depth - destination
        let total = CGFloat(depth)
        let traveled = min(total, max(0, progress * total))
        if traveled <= CGFloat(eastMoves) {
            return interpolatedNode(x: traveled, y: 0, plot: plot)
        }
        return interpolatedNode(x: CGFloat(eastMoves), y: traveled - CGFloat(eastMoves), plot: plot)
    }

    private func interpolatedNode(x: CGFloat, y: CGFloat, plot: CGRect) -> CGPoint {
        let step = min(plot.width, plot.height) / CGFloat(depth)
        let used = step * CGFloat(depth)
        let origin = CGPoint(x: plot.midX - used / 2, y: plot.midY + used / 2)
        return CGPoint(x: origin.x + x * step, y: origin.y - y * step)
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
}

#Preview {
    MathItLevelOneHundredTwentySixView(onContinue: {}, onLevelSelect: {})
}
