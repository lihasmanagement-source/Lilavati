import SwiftUI

struct MathItLevelSeventyEightView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var xInput: CGFloat = 0
    @State private var yInput: CGFloat = 0
    @State private var visitedCorners: Set<Int> = []
    @State private var advancingStage = false
    @State private var completed = false
    @State private var goalOpen = false

    private let stages = NeuralPlaneStage.stages
    private var stage: NeuralPlaneStage { stages[stageIndex] }

    private var hiddenX: Double {
        0.80 * Double(xInput) + 0.20 * Double(yInput)
    }

    private var hiddenY: Double {
        -0.30 * Double(xInput) + 0.90 * Double(yInput)
    }

    private var hiddenZ: Double {
        0.50 * Double(xInput) + 0.50 * Double(yInput)
    }

    private var outputValue: Double {
        0.40 * hiddenX - 0.25 * hiddenY + 0.85 * hiddenZ
    }

    private var planeTiltX: CGFloat {
        CGFloat(0.65 * hiddenX + 0.35 * outputValue)
    }

    private var planeTiltY: CGFloat {
        CGFloat(0.65 * hiddenY - 0.25 * outputValue)
    }

    private var completionProgress: Double {
        let finished = stages.prefix(stageIndex).reduce(0) { $0 + $1.corners.count }
        let total = stages.reduce(0) { $0 + $1.corners.count }
        return Double(finished + visitedCorners.count) / Double(total)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    neuralPlaneBoard
                        .frame(height: min(620, proxy.size.height * 0.72))
                        .padding(.horizontal, 18)

                    HStack(spacing: 14) {
                        ProgressView(value: completionProgress)
                            .tint(accent)

                        Button(action: reset) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(accent)
                                .frame(width: 58, height: 48)
                                .background(.black.opacity(0.72), in: Capsule())
                                .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.top, 38)
                .padding(.bottom, 76)

                CompletionOverlay(
                    title: "Level 78 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
        .onChange(of: xInput) { _, _ in
            updateCornerProgress()
        }
        .onChange(of: yInput) { _, _ in
            updateCornerProgress()
        }
    }

    private var neuralPlaneBoard: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let planeCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
            let planeWidth = min(size.width * 0.74, 410)
            let planeDepth = min(size.height * 0.26, 165)
            let leftControl = CGRect(x: size.width * 0.09, y: size.height * 0.78, width: size.width * 0.36, height: 92)
            let rightControl = CGRect(x: size.width * 0.55, y: size.height * 0.78, width: size.width * 0.36, height: 92)
            let ballPosition = ballPoint(center: planeCenter, width: planeWidth, depth: planeDepth)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(goalOpen ? 0.16 : 0.07), Color(red: 0.01, green: 0.014, blue: 0.018), .black],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(size.width, size.height) * 0.72
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(goalOpen ? 0.26 : 0.12), lineWidth: 1.2))

                neuralNetwork(size: size)

                neonPlane(center: planeCenter, width: planeWidth, depth: planeDepth)
                    .shadow(color: accent.opacity(goalOpen ? 0.65 : 0.28), radius: goalOpen ? 24 : 12)

                planeGrid(center: planeCenter, width: planeWidth, depth: planeDepth)
                    .opacity(0.42)

                ForEach(stage.corners.indices, id: \.self) { index in
                    Circle()
                        .fill(visitedCorners.contains(index) ? accent : .black.opacity(0.72))
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(.white.opacity(visitedCorners.contains(index) ? 0.9 : 0.36), lineWidth: 1.5))
                        .shadow(color: accent.opacity(visitedCorners.contains(index) ? 0.76 : 0), radius: 8)
                        .position(planePoint(stage.corners[index], center: planeCenter, width: planeWidth, depth: planeDepth))
                }

                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: .white.opacity(0.9), radius: 12)
                    .position(ballPosition)
                    .animation(.spring(response: 0.44, dampingFraction: 0.74), value: xInput)
                    .animation(.spring(response: 0.44, dampingFraction: 0.74), value: yInput)

                outputReadout(size: size)
                    .position(x: size.width * 0.85, y: size.height * 0.10)

                cornerTracker(size: size)
                    .position(x: size.width * 0.5, y: size.height * 0.69)

                inputControl(label: "x", value: $xInput, rect: leftControl, axis: .horizontal)
                inputControl(label: "y", value: $yInput, rect: rightControl, axis: .vertical)
            }
        }
    }

    private func neonPlane(center: CGPoint, width: CGFloat, depth: CGFloat) -> some View {
        Path { path in
            let corners = planeCorners(center: center, width: width, depth: depth)
            path.move(to: corners[0])
            for corner in corners.dropFirst() {
                path.addLine(to: corner)
            }
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.36, blue: 1.0).opacity(0.82),
                    Color(red: 0.08, green: 0.92, blue: 0.86).opacity(0.82),
                    Color(red: 0.58, green: 1.0, blue: 0.28).opacity(goalOpen ? 0.96 : 0.78)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        )
        .overlay(
            Path { path in
                let corners = planeCorners(center: center, width: width, depth: depth)
                path.move(to: corners[0])
                for corner in corners.dropFirst() {
                    path.addLine(to: corner)
                }
                path.closeSubpath()
            }
            .stroke(.white.opacity(goalOpen ? 0.56 : 0.26), lineWidth: 1.3)
        )
    }

    private func planeGrid(center: CGPoint, width: CGFloat, depth: CGFloat) -> some View {
        Path { path in
            let corners = planeCorners(center: center, width: width, depth: depth)
            for index in corners.indices {
                path.move(to: center)
                path.addLine(to: corners[index])
                let next = corners[(index + 1) % corners.count]
                path.move(to: midpoint(corners[index], next))
                path.addLine(to: center)
            }
        }
        .stroke(.black.opacity(0.26), lineWidth: 0.8)
    }

    private func neuralNetwork(size: CGSize) -> some View {
        let inputX = CGPoint(x: size.width * 0.22, y: size.height * 0.15)
        let inputY = CGPoint(x: size.width * 0.22, y: size.height * 0.29)
        let hiddenTop = CGPoint(x: size.width * 0.48, y: size.height * 0.12)
        let hiddenMiddle = CGPoint(x: size.width * 0.48, y: size.height * 0.22)
        let hiddenBottom = CGPoint(x: size.width * 0.48, y: size.height * 0.32)
        let output = CGPoint(x: size.width * 0.75, y: size.height * 0.22)
        let hiddenNodes = [hiddenTop, hiddenMiddle, hiddenBottom]
        let inputNodes = [inputX, inputY]

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.46))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.18), lineWidth: 1.1))
                .frame(width: size.width * 0.74, height: size.height * 0.29)
                .position(x: size.width * 0.49, y: size.height * 0.22)

            Path { path in
                for start in inputNodes {
                    for end in hiddenNodes {
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                }
                for start in hiddenNodes {
                    path.move(to: start)
                    path.addLine(to: output)
                }
            }
            .stroke(.white.opacity(0.28), lineWidth: 1.4)

            edgeLabel("0.80", at: midpoint(inputX, hiddenTop), tint: xInput >= 0 ? accent : .white)
            edgeLabel("0.20", at: midpoint(inputY, hiddenTop), tint: yInput >= 0 ? accent : .white)
            edgeLabel("-0.30", at: midpoint(inputX, hiddenMiddle), tint: xInput < 0 ? accent : .white)
            edgeLabel("0.90", at: midpoint(inputY, hiddenMiddle), tint: yInput >= 0 ? accent : .white)
            edgeLabel("0.50", at: midpoint(inputX, hiddenBottom), tint: accent)
            edgeLabel("0.50", at: midpoint(inputY, hiddenBottom), tint: accent)
            edgeLabel("0.40", at: midpoint(hiddenTop, output), tint: accent)
            edgeLabel("-0.25", at: midpoint(hiddenMiddle, output), tint: .white)
            edgeLabel("0.85", at: midpoint(hiddenBottom, output), tint: accent)

            networkNode(label: "x", value: Double(xInput), point: inputX, active: abs(xInput) > 0.9)
            networkNode(label: "y", value: Double(yInput), point: inputY, active: abs(yInput) > 0.9)
            networkNode(label: "x", value: hiddenX, point: hiddenTop, active: abs(hiddenX) > 0.72)
            networkNode(label: "y", value: hiddenY, point: hiddenMiddle, active: abs(hiddenY) > 0.72)
            networkNode(label: "z", value: hiddenZ, point: hiddenBottom, active: abs(hiddenZ) > 0.72)
            networkNode(label: "o", value: outputValue, point: output, active: goalOpen)
        }
        .opacity(0.9)
    }

    private func networkNode(label: String, value: Double, point: CGPoint, active: Bool) -> some View {
        VStack(spacing: 3) {
            Circle()
                .fill(active ? accent : .white.opacity(0.82))
                .frame(width: active ? 32 : 28, height: active ? 32 : 28)
                .shadow(color: (active ? accent : .white).opacity(active ? 0.76 : 0.38), radius: active ? 12 : 6)
                .overlay(
                    Text(label)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                )

            Text(degreeText(value))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(active ? accent : .white.opacity(0.7))
        }
        .position(point)
    }

    private func edgeLabel(_ text: String, at point: CGPoint, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(tint.opacity(0.72))
            .padding(.horizontal, 3)
            .background(.black.opacity(0.72), in: Capsule())
            .position(point)
    }

    private func outputReadout(size: CGSize) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(goalOpen ? accent : .white.opacity(0.22))
                .frame(width: 8, height: 8)
                .shadow(color: accent.opacity(goalOpen ? 0.8 : 0), radius: 8)

            Text(String(format: "%.2f", outputValue))
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(goalOpen ? 0.94 : 0.54))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.64), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(goalOpen ? 0.28 : 0.12), lineWidth: 1))
    }

    private func cornerTracker(size: CGSize) -> some View {
        HStack(spacing: 8) {
            ForEach(stage.corners.indices, id: \.self) { index in
                Circle()
                    .fill(visitedCorners.contains(index) ? accent : .white.opacity(0.16))
                    .frame(width: 9, height: 9)
                    .shadow(color: accent.opacity(visitedCorners.contains(index) ? 0.72 : 0), radius: 7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.52), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func inputControl(label: String, value: Binding<CGFloat>, rect: CGRect, axis: NeuralPlaneAxis) -> some View {
        let knob = inputKnobPoint(value: value.wrappedValue, rect: rect, axis: axis)

        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.58))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.13), lineWidth: 1.1))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            if axis == .horizontal {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(width: rect.width - 54, height: 3)
                    .position(x: rect.midX, y: rect.midY)
            } else {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(width: 3, height: rect.height - 34)
                    .position(x: rect.midX, y: rect.midY)
            }

            Circle()
                .fill(abs(value.wrappedValue) > 0.9 ? accent : .white)
                .frame(width: 36, height: 36)
                .shadow(color: (abs(value.wrappedValue) > 0.9 ? accent : .white).opacity(0.72), radius: 12)
                .overlay(
                    Text(label)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                )
                .position(knob)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let next = axis == .horizontal
                                ? (gesture.location.x - rect.midX) / ((rect.width - 54) / 2)
                                : (rect.midY - gesture.location.y) / ((rect.height - 34) / 2)
                            value.wrappedValue = max(-1, min(1, next))
                        }
                )
        }
    }

    private func inputKnobPoint(value: CGFloat, rect: CGRect, axis: NeuralPlaneAxis) -> CGPoint {
        if axis == .horizontal {
            return CGPoint(x: rect.midX + value * ((rect.width - 54) / 2), y: rect.midY)
        }
        return CGPoint(x: rect.midX, y: rect.midY - value * ((rect.height - 34) / 2))
    }

    private func ballPoint(center: CGPoint, width: CGFloat, depth: CGFloat) -> CGPoint {
        planePoint(ballUV, center: center, width: width, depth: depth)
    }

    private var rawInputPoint: CGPoint {
        CGPoint(x: max(-1, min(1, xInput)), y: max(-1, min(1, yInput)))
    }

    private var ballUV: CGPoint {
        stage.constrainedPoint(for: rawInputPoint)
    }

    private func planeCorners(center: CGPoint, width: CGFloat, depth: CGFloat) -> [CGPoint] {
        stage.corners.map { planePoint($0, center: center, width: width, depth: depth) }
    }

    private func planePoint(_ uv: CGPoint, center: CGPoint, width: CGFloat, depth: CGFloat) -> CGPoint {
        let isoX = uv.x * width * 0.48 + uv.y * width * 0.18
        let isoY = uv.x * planeTiltX * 34 + uv.y * planeTiltY * 34 + uv.y * depth * 0.28
        return CGPoint(x: center.x + isoX, y: center.y + isoY)
    }

    private func midpoint(_ start: CGPoint, _ end: CGPoint) -> CGPoint {
        CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }

    private func degreeText(_ value: Double) -> String {
        String(format: "%+.0f", value * 45)
    }

    private func updateCornerProgress() {
        guard !completed, !advancingStage else { return }
        guard let corner = stage.cornerIndex(near: rawInputPoint) else { return }

        visitedCorners.insert(corner)
        if visitedCorners.count == stage.corners.count {
            advanceStage()
        }
    }

    private func advanceStage() {
        advancingStage = true
        if stageIndex < stages.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    stageIndex += 1
                    xInput = 0
                    yInput = 0
                    visitedCorners = []
                    advancingStage = false
                }
            }
        } else {
            finishLevel()
        }
    }

    private func finishLevel() {
        guard !completed else { return }
        withAnimation(.easeInOut(duration: 0.42)) {
            goalOpen = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                completed = true
            }
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            xInput = 0
            yInput = 0
            stageIndex = 0
            visitedCorners = []
            advancingStage = false
            goalOpen = false
            completed = false
        }
    }
}

private enum NeuralPlaneAxis {
    case horizontal
    case vertical
}

private struct NeuralPlaneStage {
    let corners: [CGPoint]

    func cornerIndex(near point: CGPoint) -> Int? {
        let threshold: CGFloat = 0.16
        return corners.indices.first { index in
            hypot(corners[index].x - point.x, corners[index].y - point.y) <= threshold
        }
    }

    func constrainedPoint(for point: CGPoint) -> CGPoint {
        if contains(point) {
            return point
        }

        var closest = corners[0]
        var closestDistance = CGFloat.greatestFiniteMagnitude

        for index in corners.indices {
            let start = corners[index]
            let end = corners[(index + 1) % corners.count]
            let candidate = closestPoint(to: point, onSegmentFrom: start, to: end)
            let distance = hypot(candidate.x - point.x, candidate.y - point.y)
            if distance < closestDistance {
                closest = candidate
                closestDistance = distance
            }
        }

        return closest
    }

    private func contains(_ point: CGPoint) -> Bool {
        var inside = false
        var previous = corners.count - 1

        for current in corners.indices {
            let currentPoint = corners[current]
            let previousPoint = corners[previous]
            let crossesY = (currentPoint.y > point.y) != (previousPoint.y > point.y)
            if crossesY {
                let slopeX = (previousPoint.x - currentPoint.x) * (point.y - currentPoint.y) / (previousPoint.y - currentPoint.y) + currentPoint.x
                if point.x < slopeX {
                    inside.toggle()
                }
            }
            previous = current
        }

        return inside
    }

    private func closestPoint(to point: CGPoint, onSegmentFrom start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return start }

        let rawT = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        let t = max(0, min(1, rawT))
        return CGPoint(x: start.x + dx * t, y: start.y + dy * t)
    }

    static let stages: [NeuralPlaneStage] = [
        NeuralPlaneStage(corners: [
            CGPoint(x: -1, y: -1),
            CGPoint(x: 1, y: -1),
            CGPoint(x: 1, y: 1),
            CGPoint(x: -1, y: 1)
        ]),
        NeuralPlaneStage(corners: [
            CGPoint(x: 0, y: -1),
            CGPoint(x: 0.9, y: 0.82),
            CGPoint(x: -0.9, y: 0.82)
        ]),
        NeuralPlaneStage(corners: [
            CGPoint(x: 0, y: -1),
            CGPoint(x: 0.95, y: -0.28),
            CGPoint(x: 0.58, y: 0.92),
            CGPoint(x: -0.58, y: 0.92),
            CGPoint(x: -0.95, y: -0.28)
        ])
    ]
}
