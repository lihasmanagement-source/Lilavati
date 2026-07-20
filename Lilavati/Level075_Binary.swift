import SwiftUI

@Observable
final class MathItLevelEighteenViewModel {
    var inputA1 = false
    var inputB1 = false
    var inputA2 = false
    var inputB2 = false
    var completed = false
    var electronStartDate: Date?

    private let targetA1: Bool
    private let targetB1: Bool
    private let targetA2: Bool
    private let targetB2: Bool
    let truthRows: [LevelEighteenTruthRow]

    init() {
        let target = Self.randomTarget()
        targetA1 = target.a1
        targetB1 = target.b1
        targetA2 = target.a2
        targetB2 = target.b2
        truthRows = Self.makeTruthRows(target: target)
    }

    var output: Bool {
        inputA1 == targetA1
            && inputB1 == targetB1
            && inputA2 == targetA2
            && inputB2 == targetB2
    }

    var progress: Double {
        output ? 0.96 : 0.22
    }

    func toggleA() {
        guard electronStartDate == nil else { return }
        inputA1.toggle()
        HapticPlayer.playLightTap()
        checkCompletion()
    }

    func toggleB() {
        guard electronStartDate == nil else { return }
        inputB1.toggle()
        HapticPlayer.playLightTap()
        checkCompletion()
    }

    func toggleSecondA() {
        guard electronStartDate == nil else { return }
        inputA2.toggle()
        HapticPlayer.playLightTap()
        checkCompletion()
    }

    func toggleSecondB() {
        guard electronStartDate == nil else { return }
        inputB2.toggle()
        HapticPlayer.playLightTap()
        checkCompletion()
    }

    private func checkCompletion() {
        guard output, !completed, electronStartDate == nil else { return }
        electronStartDate = Date()
        HapticPlayer.playCompletionTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }

    private static func randomTarget() -> (a1: Bool, b1: Bool, a2: Bool, b2: Bool) {
        var target = (a1: false, b1: false, a2: false, b2: false)
        while !target.a1 && !target.b1 && !target.a2 && !target.b2 {
            target = (Bool.random(), Bool.random(), Bool.random(), Bool.random())
        }
        return target
    }

    private static func makeTruthRows(target: (a1: Bool, b1: Bool, a2: Bool, b2: Bool)) -> [LevelEighteenTruthRow] {
        var rows = [
            LevelEighteenTruthRow(a1: target.a1, b1: target.b1, a2: target.a2, b2: target.b2, output: true)
        ]
        let distractors = [
            (a1: false, b1: false, a2: false, b2: false),
            (a1: !target.a1, b1: target.b1, a2: target.a2, b2: target.b2),
            (a1: target.a1, b1: !target.b1, a2: target.a2, b2: target.b2),
            (a1: target.a1, b1: target.b1, a2: !target.a2, b2: target.b2),
            (a1: target.a1, b1: target.b1, a2: target.a2, b2: !target.b2)
        ]

        for distractor in distractors where rows.count < 4 {
            guard !rows.contains(where: { $0.matches(distractor) }) else { continue }
            rows.append(LevelEighteenTruthRow(
                a1: distractor.a1,
                b1: distractor.b1,
                a2: distractor.a2,
                b2: distractor.b2,
                output: false
            ))
        }

        return rows.shuffled()
    }
}

struct MathItLevelEighteenView: View {
    var viewModel: MathItLevelEighteenViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let board = CGRect(x: 24, y: size.height * 0.22, width: size.width - 48, height: min(360, size.height * 0.5))

            ZStack {
                Color.black
                    .ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                ProgressView(value: viewModel.progress)
                    .tint(.white)
                    .opacity(0.72)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 128)

                circuitBoard(frame: board)

                truthTable(board: board)

                CompletionOverlay(
                    title: "Level 18 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private func circuitBoard(frame: CGRect) -> some View {
        let a1 = CGPoint(x: frame.minX + 38, y: frame.minY + 58)
        let b1 = CGPoint(x: frame.minX + 38, y: frame.minY + 134)
        let a2 = CGPoint(x: frame.minX + 38, y: frame.minY + 218)
        let b2 = CGPoint(x: frame.minX + 38, y: frame.minY + 294)
        let topAndCenter = CGPoint(x: frame.minX + frame.width * 0.33, y: frame.minY + 94)
        let lowerNotCenter = CGPoint(x: frame.minX + frame.width * 0.27, y: frame.minY + 294)
        let lowerAndCenter = CGPoint(x: frame.minX + frame.width * 0.50, y: frame.minY + 246)
        let finalCenter = CGPoint(x: frame.minX + frame.width * 0.73, y: frame.minY + 170)
        let bulb = CGPoint(x: frame.maxX - 48, y: finalCenter.y)
        let aColor = Color.mathItLogic
        let bColor = Color.mathItLogic
        let topAndInputX = topAndCenter.x - 41
        let topAndOutputX = topAndCenter.x + 41
        let notInputX = lowerNotCenter.x - 31
        let notOutputX = lowerNotCenter.x + 34
        let lowerAndInputX = lowerAndCenter.x - 41
        let lowerAndOutputX = lowerAndCenter.x + 41
        let finalInputX = finalCenter.x - 43
        let finalOutputX = finalCenter.x + 43
        let bracketWhite = Color.white.opacity(0.9)

        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.16), lineWidth: 1.2)
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            CircuitGridShape()
                .stroke(.white.opacity(0.055), lineWidth: 1)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            inputNode(label: "A", isOn: viewModel.inputA1, color: aColor, point: a1, action: viewModel.toggleA)
            inputNode(label: "B", isOn: viewModel.inputB1, color: bColor, point: b1, action: viewModel.toggleB)
            inputNode(label: "A", isOn: viewModel.inputA2, color: aColor, point: a2, action: viewModel.toggleSecondA)
            inputNode(label: "B", isOn: viewModel.inputB2, color: bColor, point: b2, action: viewModel.toggleSecondB)

            wire([CGPoint(x: a1.x + 19, y: a1.y), CGPoint(x: topAndCenter.x - 70, y: a1.y), CGPoint(x: topAndCenter.x - 70, y: topAndCenter.y - 18), CGPoint(x: topAndInputX, y: topAndCenter.y - 18)])
                .stroke(bracketWhite, style: circuitStroke)

            wire([CGPoint(x: b1.x + 19, y: b1.y), CGPoint(x: topAndCenter.x - 70, y: b1.y), CGPoint(x: topAndCenter.x - 70, y: topAndCenter.y + 18), CGPoint(x: topAndInputX, y: topAndCenter.y + 18)])
                .stroke(bracketWhite, style: circuitStroke)

            wire([CGPoint(x: a2.x + 19, y: a2.y), CGPoint(x: lowerAndCenter.x - 70, y: a2.y), CGPoint(x: lowerAndCenter.x - 70, y: lowerAndCenter.y - 18), CGPoint(x: lowerAndInputX, y: lowerAndCenter.y - 18)])
                .stroke(bracketWhite, style: circuitStroke)

            wire([CGPoint(x: b2.x + 19, y: b2.y), CGPoint(x: lowerNotCenter.x - 66, y: b2.y), CGPoint(x: lowerNotCenter.x - 66, y: lowerNotCenter.y), CGPoint(x: notInputX, y: lowerNotCenter.y)])
                .stroke(bracketWhite, style: circuitStroke)

            wire([CGPoint(x: notOutputX, y: lowerNotCenter.y), CGPoint(x: lowerAndCenter.x - 70, y: lowerNotCenter.y), CGPoint(x: lowerAndCenter.x - 70, y: lowerAndCenter.y + 18), CGPoint(x: lowerAndInputX, y: lowerAndCenter.y + 18)])
                .stroke(bracketWhite, style: circuitStroke)

            wire([CGPoint(x: topAndOutputX, y: topAndCenter.y), CGPoint(x: finalCenter.x - 76, y: topAndCenter.y), CGPoint(x: finalCenter.x - 76, y: finalCenter.y - 18), CGPoint(x: finalInputX, y: finalCenter.y - 18)])
                .stroke(bracketWhite, style: circuitStroke)

            wire([CGPoint(x: lowerAndOutputX, y: lowerAndCenter.y), CGPoint(x: finalCenter.x - 76, y: lowerAndCenter.y), CGPoint(x: finalCenter.x - 76, y: finalCenter.y + 18), CGPoint(x: finalInputX, y: finalCenter.y + 18)])
                .stroke(bracketWhite, style: circuitStroke)

            wire([CGPoint(x: finalOutputX, y: finalCenter.y), CGPoint(x: bulb.x - 34, y: bulb.y)])
                .stroke(bracketWhite, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .shadow(color: Color.mathItLogic.opacity(viewModel.output ? 0.48 : 0), radius: 10)

            LogicGateShape(kind: .and)
                .stroke(Color.mathGold.opacity(0.95), lineWidth: 2.4)
                .frame(width: 82, height: 62)
                .position(topAndCenter)

            LogicGateShape(kind: .not)
                .stroke(Color.mathGold.opacity(0.95), lineWidth: 2.4)
                .frame(width: 78, height: 70)
                .position(lowerNotCenter)

            LogicGateShape(kind: .and)
                .stroke(Color.mathGold.opacity(0.95), lineWidth: 2.4)
                .frame(width: 82, height: 64)
                .position(lowerAndCenter)

            LogicGateShape(kind: .and)
                .stroke(Color.mathGold.opacity(0.95), lineWidth: 2.4)
                .frame(width: 86, height: 68)
                .position(finalCenter)

            bulbView(isOn: viewModel.output)
                .position(bulb)

            electronLayer(frame: frame)
        }
    }

    private var circuitStroke: StrokeStyle {
        StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
    }

    private func electronLayer(frame: CGRect) -> some View {
        let a1 = CGPoint(x: frame.minX + 38, y: frame.minY + 58)
        let b1 = CGPoint(x: frame.minX + 38, y: frame.minY + 134)
        let a2 = CGPoint(x: frame.minX + 38, y: frame.minY + 218)
        let b2 = CGPoint(x: frame.minX + 38, y: frame.minY + 294)
        let topAndCenter = CGPoint(x: frame.minX + frame.width * 0.33, y: frame.minY + 94)
        let lowerNotCenter = CGPoint(x: frame.minX + frame.width * 0.27, y: frame.minY + 294)
        let lowerAndCenter = CGPoint(x: frame.minX + frame.width * 0.50, y: frame.minY + 246)
        let finalCenter = CGPoint(x: frame.minX + frame.width * 0.73, y: frame.minY + 170)
        let bulb = CGPoint(x: frame.maxX - 48, y: finalCenter.y)
        let a1Path = [
            CGPoint(x: a1.x + 19, y: a1.y),
            CGPoint(x: topAndCenter.x - 70, y: a1.y),
            CGPoint(x: topAndCenter.x - 70, y: topAndCenter.y - 18),
            CGPoint(x: topAndCenter.x + 58, y: topAndCenter.y),
            CGPoint(x: finalCenter.x - 76, y: topAndCenter.y),
            CGPoint(x: finalCenter.x - 76, y: finalCenter.y - 18),
            CGPoint(x: finalCenter.x + 62, y: finalCenter.y),
            CGPoint(x: bulb.x - 10, y: bulb.y)
        ]
        let b1Path = [
            CGPoint(x: b1.x + 19, y: b1.y),
            CGPoint(x: topAndCenter.x - 70, y: b1.y),
            CGPoint(x: topAndCenter.x - 70, y: topAndCenter.y + 18),
            CGPoint(x: topAndCenter.x + 58, y: topAndCenter.y),
            CGPoint(x: finalCenter.x - 76, y: topAndCenter.y),
            CGPoint(x: finalCenter.x - 76, y: finalCenter.y - 18),
            CGPoint(x: finalCenter.x + 62, y: finalCenter.y),
            CGPoint(x: bulb.x - 10, y: bulb.y)
        ]
        let a2Path = [
            CGPoint(x: a2.x + 19, y: a2.y),
            CGPoint(x: lowerAndCenter.x - 70, y: a2.y),
            CGPoint(x: lowerAndCenter.x - 70, y: lowerAndCenter.y - 18),
            CGPoint(x: lowerAndCenter.x + 58, y: lowerAndCenter.y),
            CGPoint(x: finalCenter.x - 76, y: lowerAndCenter.y),
            CGPoint(x: finalCenter.x - 76, y: finalCenter.y + 18),
            CGPoint(x: finalCenter.x + 62, y: finalCenter.y),
            CGPoint(x: bulb.x - 10, y: bulb.y)
        ]
        let b2Path = [
            CGPoint(x: b2.x + 19, y: b2.y),
            CGPoint(x: lowerNotCenter.x - 66, y: b2.y),
            CGPoint(x: lowerNotCenter.x - 66, y: lowerNotCenter.y),
            CGPoint(x: lowerNotCenter.x + 62, y: lowerNotCenter.y),
            CGPoint(x: lowerAndCenter.x - 70, y: lowerNotCenter.y),
            CGPoint(x: lowerAndCenter.x - 70, y: lowerAndCenter.y + 18),
            CGPoint(x: lowerAndCenter.x + 58, y: lowerAndCenter.y),
            CGPoint(x: finalCenter.x - 76, y: lowerAndCenter.y),
            CGPoint(x: finalCenter.x - 76, y: finalCenter.y + 18),
            CGPoint(x: finalCenter.x + 62, y: finalCenter.y),
            CGPoint(x: bulb.x - 10, y: bulb.y)
        ]

        return Group {
            if let startDate = viewModel.electronStartDate {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    ZStack {
                        electron(at: point(on: a1Path, progress: min(1, max(0, elapsed / 1.75))), color: Color.mathItLogic)
                        electron(at: point(on: b1Path, progress: min(1, max(0, (elapsed - 0.10) / 1.75))), color: Color.mathItLogic)
                        electron(at: point(on: a2Path, progress: min(1, max(0, (elapsed - 0.20) / 1.75))), color: Color.mathItLogic)
                        electron(at: point(on: b2Path, progress: min(1, max(0, (elapsed - 0.30) / 1.75))), color: Color.mathItLogic)
                    }
                }
            }
        }
    }

    private func electron(at point: CGPoint, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.96))
            .frame(width: 10, height: 10)
            .shadow(color: color.opacity(0.82), radius: 10)
            .position(point)
    }

    private func inputNode(label: String, isOn: Bool, color: Color, point: CGPoint, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(isOn ? 0.36 : 0.08))
                    .frame(width: 38, height: 38)
                    .shadow(color: color.opacity(isOn ? 0.72 : 0.12), radius: isOn ? 16 : 4)

                Circle()
                    .stroke(color.opacity(isOn ? 0.95 : 0.52), lineWidth: 2.4)
                    .frame(width: 18, height: 18)

                Text(label)
                    .font(.garamond(18))
                    .foregroundStyle(Color.mathGold.opacity(0.95))
                    .offset(x: 0, y: -36)
            }
            .frame(width: 56, height: 72)
        }
        .buttonStyle(.plain)
        .position(point)
    }

    private func bulbView(isOn: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.mathItLogic.opacity(0.62), style: StrokeStyle(lineWidth: 2, dash: [8, 7]))
                .frame(width: 62, height: 74)
                .shadow(color: Color.mathItLogic.opacity(isOn ? 0.5 : 0.08), radius: isOn ? 18 : 5)

            Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.mathItLogic.opacity(isOn ? 0.98 : 0.56))
                .shadow(color: Color.mathItLogic.opacity(isOn ? 0.8 : 0.1), radius: isOn ? 18 : 4)
        }
    }

    private func truthTable(board: CGRect) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("truth table")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.mathItLogic.opacity(0.86))

            HStack(spacing: 16) {
                Text("A")
                Text("B")
                Text("A")
                Text("B")
                Text("OUT")
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.62))

            ForEach(viewModel.truthRows, id: \.id) { row in
                HStack(spacing: 16) {
                    Text(row.a1 ? "1" : "0")
                    Text(row.b1 ? "1" : "0")
                    Text(row.a2 ? "1" : "0")
                    Text(row.b2 ? "1" : "0")
                    Text(row.output ? "1" : "0")
                        .foregroundStyle(row.output ? Color.mathItLogic.opacity(0.95) : .white.opacity(0.5))
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.76))
            }
        }
        .padding(16)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .position(x: board.midX, y: board.maxY + 112)
    }

    private func wire(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

struct LevelEighteenTruthRow: Identifiable {
    let id = UUID()
    let a1: Bool
    let b1: Bool
    let a2: Bool
    let b2: Bool
    let output: Bool

    func matches(_ values: (a1: Bool, b1: Bool, a2: Bool, b2: Bool)) -> Bool {
        a1 == values.a1 && b1 == values.b1 && a2 == values.a2 && b2 == values.b2
    }
}

private enum LogicGateKind {
    case and
    case or
    case not
}

private struct LogicGateShape: Shape {
    let kind: LogicGateKind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .and:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: rect.height / 2,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .or:
            path.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + 2))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 6, y: rect.midY),
                control: CGPoint(x: rect.midX + 34, y: rect.minY + 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + 4, y: rect.maxY - 2),
                control: CGPoint(x: rect.midX + 34, y: rect.maxY - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + 4, y: rect.minY + 2),
                control: CGPoint(x: rect.minX + 28, y: rect.midY)
            )
        case .not:
            path.move(to: CGPoint(x: rect.minX + 8, y: rect.minY + 6))
            path.addLine(to: CGPoint(x: rect.minX + 8, y: rect.maxY - 6))
            path.addLine(to: CGPoint(x: rect.maxX - 20, y: rect.midY))
            path.closeSubpath()
            path.addEllipse(in: CGRect(x: rect.maxX - 18, y: rect.midY - 6, width: 12, height: 12))
        }
        return path
    }
}

private func point(on points: [CGPoint], progress: Double) -> CGPoint {
    guard let first = points.first else { return .zero }
    guard points.count > 1 else { return first }

    let clamped = min(1, max(0, progress))
    let lengths = zip(points, points.dropFirst()).map { start, end in
        hypot(end.x - start.x, end.y - start.y)
    }
    let total = lengths.reduce(0, +)
    guard total > 0 else { return first }

    var traveled = total * clamped
    for index in lengths.indices {
        let length = lengths[index]
        if traveled <= length {
            let start = points[index]
            let end = points[index + 1]
            let portion = length == 0 ? 0 : traveled / length
            return CGPoint(
                x: start.x + (end.x - start.x) * portion,
                y: start.y + (end.y - start.y) * portion
            )
        }
        traveled -= length
    }

    return points.last ?? first
}

private struct CircuitGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let columns = 8
        let rows = 5

        for column in 0...columns {
            let x = rect.minX + rect.width * CGFloat(column) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        for row in 0...rows {
            let y = rect.minY + rect.height * CGFloat(row) / CGFloat(rows)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}
