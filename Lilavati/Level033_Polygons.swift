import SwiftUI
import Foundation
import Combine
import AudioToolbox

@Observable
final class RationalFactoryViewModel {
    let fixedCost = 1_800.0
    let variableCost = 10.0
    let salePrice = 20.0
    let demandRate = 75.0
    let openingBalance = 3_000.0
    let targetBalance = 5_000.0

    var productionRate = 48.0
    var unitsProduced = 0.0
    var unitsSold = 0.0
    var revenue = 0.0
    var variableSpend = 0.0
    var elapsedMinutes = 0.0
    var isRunning = true
    var completed = false
    var failed = false

    private let realTick = 1.0 / 30.0
    private let simulatedMinutesPerRealSecond = 0.18

    var totalCost: Double { fixedCost + variableSpend }
    var inventory: Double { max(0, unitsProduced - unitsSold) }
    var profit: Double { revenue - totalCost }
    var balance: Double { openingBalance + profit }
    var averageCost: Double {
        guard unitsProduced > 0.01 else { return fixedCost + variableCost }
        return fixedCost / unitsProduced + variableCost
    }
    var progress: Double {
        min(1, max(0, (balance - openingBalance) / (targetBalance - openingBalance)))
    }

    func toggleRunning() {
        guard !completed, !failed else { return }
        isRunning ? pause() : start()
    }

    func start() {
        guard !completed, !failed else { return }
        isRunning = true
        HapticPlayer.playLightTap()
    }

    func pause() {
        isRunning = false
    }

    func stop() {
        isRunning = false
    }

    func tick() {
        guard isRunning, !completed, !failed else { return }
        let simulatedMinutes = realTick * simulatedMinutesPerRealSecond
        let made = productionRate * simulatedMinutes
        let sold = min(productionRate, demandRate) * simulatedMinutes

        elapsedMinutes += simulatedMinutes
        unitsProduced += made
        unitsSold += min(sold, unitsProduced - unitsSold)
        variableSpend += made * variableCost
        revenue += sold * salePrice

        if averageCost <= variableCost {
            triggerFailure()
        } else if balance <= 0 {
            triggerFailure()
        } else if balance >= targetBalance {
            stop()
            completed = true
            HapticPlayer.playCompletionTap()
        }
    }

    private func triggerFailure() {
        guard !failed else { return }
        stop()
        failed = true
        AudioServicesPlaySystemSound(1005)
        HapticPlayer.playCompletionTap()
    }
}

struct RationalFactoryView: View {
    var viewModel: RationalFactoryViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let cyan = Color(red: 0.18, green: 0.79, blue: 0.78)
    private let amber = Color(red: 1.0, green: 0.68, blue: 0.16)
    private let red = Color(red: 0.94, green: 0.25, blue: 0.23)
    private let ink = Color(red: 0.035, green: 0.055, blue: 0.07)
    private let simulationClock = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ink.ignoresSafeArea()

                VStack(spacing: 10) {
                    header
                        .padding(.horizontal, 68)

                    if proxy.size.width >= 780 {
                        HStack(spacing: 10) {
                            costDashboard
                                .frame(width: proxy.size.width * 0.36)
                            factoryFloor
                                .frame(width: proxy.size.width * 0.36)
                            bankDashboard
                        }
                        .padding(.horizontal, 14)
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                costDashboard.frame(height: 390)
                                factoryFloor.frame(height: 300)
                                bankDashboard.frame(height: 360)
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                if viewModel.failed {
                    failureOverlay
                        .zIndex(40)
                }

                CompletionOverlay(
                    title: "Factory Profitable",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, cyan)
        .onReceive(simulationClock) { _ in viewModel.tick() }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.failed) { _, failed in
            guard failed else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                onReplay()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isRunning ? cyan : .white.opacity(0.3))
                    .frame(width: 7, height: 7)
                Text(viewModel.isRunning ? "PLANT RUNNING" : "PLANT PAUSED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Button(action: viewModel.toggleRunning) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(ink)
                    .frame(width: 46, height: 42)
                    .background(viewModel.isRunning ? amber : cyan, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isRunning ? "Pause factory" : "Start factory")
        }
        .frame(height: 50)
    }

    private var costDashboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelHeader("AVERAGE COST", icon: "chart.xyaxis.line")

            HStack(alignment: .firstTextBaseline) {
                Text("C(q) =")
                Text("$1,800")
                    .foregroundStyle(amber)
                Text("/ q +")
                Text("$10")
                    .foregroundStyle(red)
            }
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .foregroundStyle(.white)

            AverageCostGraph(
                units: viewModel.unitsProduced,
                productionRate: viewModel.productionRate,
                fixedCost: viewModel.fixedCost,
                variableCost: viewModel.variableCost,
                cyan: cyan,
                amber: amber,
                red: red
            )
            .frame(maxHeight: .infinity)

            VStack(spacing: 4) {
                HStack {
                    Text("PRODUCTION RATE")
                    Spacer()
                    Text("\(Int(viewModel.productionRate)) cubes/min")
                        .foregroundStyle(amber)
                }
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))

                Slider(
                    value: Binding(
                        get: { viewModel.productionRate },
                        set: { viewModel.productionRate = $0 }
                    ),
                    in: 10...220,
                    step: 1
                )
                .tint(cyan)

                HStack {
                    Text("10")
                    Spacer()
                    Text("MARKET DEMAND 75")
                        .foregroundStyle(cyan)
                    Spacer()
                    Text("220")
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
            }
        }
        .padding(14)
        .background(Color(red: 0.06, green: 0.085, blue: 0.10), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.09), lineWidth: 1))
    }

    private var factoryFloor: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelHeader("FACTORY FLOOR", icon: "building.2.fill")

            FactoryAnimation(
                rate: viewModel.productionRate,
                isRunning: viewModel.isRunning,
                cyan: cyan,
                amber: amber,
                ink: ink
            )
            .frame(maxHeight: .infinity)

            HStack(spacing: 8) {
                factoryMetric("OUTPUT", "\(Int(viewModel.unitsProduced))")
                factoryMetric("SOLD", "\(Int(viewModel.unitsSold))")
                factoryMetric("INVENTORY", "\(Int(viewModel.inventory))", warning: viewModel.inventory > 80)
            }
        }
        .padding(14)
        .background(Color(red: 0.075, green: 0.08, blue: 0.085), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.09), lineWidth: 1))
    }

    private var bankDashboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelHeader("BANK", icon: "building.columns.fill")

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("CURRENT BALANCE")
                    Spacer()
                    Text("GOAL  $5,000")
                        .foregroundStyle(amber)
                }
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                Text(currency(viewModel.balance))
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(viewModel.balance < 500 ? red : .white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            Divider().overlay(.white.opacity(0.12))

            bankRow("TOTAL REVENUE", viewModel.revenue, color: cyan)
            bankRow("PRODUCTION COST", viewModel.totalCost, color: amber)
            bankRow("AVERAGE / UNIT", viewModel.averageCost, color: .white)

            Divider().overlay(.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("PROFIT / LOSS")
                    Spacer()
                    Text(currency(viewModel.profit))
                        .foregroundStyle(viewModel.profit >= 0 ? cyan : red)
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))

                ProgressView(value: viewModel.progress)
                    .tint(viewModel.profit >= 0 ? cyan : red)

                Text("BALANCE GOAL  \(currency(viewModel.targetBalance))")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(amber.opacity(0.82))
            }

            Spacer(minLength: 0)

            Text(viewModel.inventory > 80 ? "EXCESS INVENTORY IS DRAINING CASH" : "SPREAD FIXED COST ACROSS MORE UNITS")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(viewModel.inventory > 80 ? red : amber)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(red: 0.055, green: 0.075, blue: 0.085), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.09), lineWidth: 1))
    }

    private var failureOverlay: some View {
        ZStack {
            Color.black.opacity(0.76).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42, weight: .black))
                Text("FACTORY SHUTDOWN")
                    .font(.system(size: 23, weight: .black, design: .monospaced))
                Text("Cash reserves reached zero. Resetting production line...")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.66))
            }
            .foregroundStyle(red)
        }
        .transition(.opacity)
    }

    private func panelHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(cyan)
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func factoryMetric(_ title: String, _ value: String, warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(warning ? red : .white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bankRow(_ title: String, _ value: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.48))
            Spacer()
            Text(currency(value))
                .foregroundStyle(color)
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
    }

    private func currency(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        return "\(sign)$\(Int(abs(value)).formatted())"
    }
}

private struct AverageCostGraph: View {
    let units: Double
    let productionRate: Double
    let fixedCost: Double
    let variableCost: Double
    let cyan: Color
    let amber: Color
    let red: Color

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 34, y: 12, width: max(1, size.width - 45), height: max(1, size.height - 35))
            let maxUnits = 600.0
            let maxCost = 70.0

            func point(q: Double, cost: Double) -> CGPoint {
                CGPoint(
                    x: plot.minX + CGFloat(q / maxUnits) * plot.width,
                    y: plot.maxY - CGFloat((cost - variableCost) / (maxCost - variableCost)) * plot.height
                )
            }

            for index in 0...4 {
                let y = plot.minY + CGFloat(index) * plot.height / 4
                var grid = Path()
                grid.move(to: CGPoint(x: plot.minX, y: y))
                grid.addLine(to: CGPoint(x: plot.maxX, y: y))
                context.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 1)
            }

            var axes = Path()
            axes.move(to: CGPoint(x: plot.minX, y: plot.minY))
            axes.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
            axes.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            context.stroke(axes, with: .color(.white.opacity(0.28)), lineWidth: 1.2)

            let asymptoteY = point(q: 0, cost: variableCost).y
            var asymptote = Path()
            asymptote.move(to: CGPoint(x: plot.minX, y: asymptoteY))
            asymptote.addLine(to: CGPoint(x: plot.maxX, y: asymptoteY))
            context.stroke(asymptote, with: .color(red), style: StrokeStyle(lineWidth: 1.8, dash: [5, 5]))

            var fullCurve = Path()
            for step in 0...160 {
                let q = 30 + (maxUnits - 30) * Double(step) / 160
                let cost = fixedCost / q + variableCost
                let p = point(q: q, cost: min(maxCost, cost))
                if step == 0 { fullCurve.move(to: p) } else { fullCurve.addLine(to: p) }
            }
            context.stroke(fullCurve, with: .color(amber.opacity(0.18)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            let plannedUnits = min(maxUnits, max(30, productionRate * 2.6))
            var productionCurve = Path()
            for step in 0...100 {
                let q = 30 + (plannedUnits - 30) * Double(step) / 100
                let cost = fixedCost / q + variableCost
                let p = point(q: q, cost: min(maxCost, cost))
                if step == 0 { productionCurve.move(to: p) } else { productionCurve.addLine(to: p) }
            }
            context.stroke(productionCurve, with: .color(amber), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

            let planCost = fixedCost / plannedUnits + variableCost
            let planPoint = point(q: plannedUnits, cost: min(maxCost, planCost))
            var planGuide = Path()
            planGuide.move(to: CGPoint(x: planPoint.x, y: planPoint.y))
            planGuide.addLine(to: CGPoint(x: planPoint.x, y: plot.maxY))
            context.stroke(planGuide, with: .color(amber.opacity(0.48)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            context.fill(Path(ellipseIn: CGRect(x: planPoint.x - 4, y: planPoint.y - 4, width: 8, height: 8)), with: .color(amber))

            context.draw(Text("$10 variable-cost floor").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(red), at: CGPoint(x: plot.maxX - 66, y: asymptoteY - 10))
            context.draw(Text("plan \(Int(plannedUnits))").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundColor(amber), at: CGPoint(x: min(plot.maxX - 24, planPoint.x), y: max(plot.minY + 9, planPoint.y - 11)))
            context.draw(Text("units produced").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.38)), at: CGPoint(x: plot.maxX - 42, y: plot.maxY + 14))
            context.draw(Text("cost").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.38)), at: CGPoint(x: 14, y: plot.minY + 8))
        }
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 5))
        .accessibilityLabel("Average cost curve decreasing toward the ten dollar variable cost asymptote")
    }
}

private struct FactoryAnimation: View {
    let rate: Double
    let isRunning: Bool
    let cyan: Color
    let amber: Color
    let ink: Color

    @State private var animationEpoch = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isRunning)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(animationEpoch))
            let cyclesPerSecond = 0.16 + rate / 300.0
            let motion = elapsed * cyclesPerSecond

            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.11, green: 0.13, blue: 0.14)))

                let beltY = size.height * 0.70
                context.fill(Path(CGRect(x: 0, y: beltY, width: size.width, height: 28)), with: .color(Color(red: 0.18, green: 0.20, blue: 0.21)))
                context.fill(Path(CGRect(x: 0, y: beltY, width: size.width, height: 4)), with: .color(cyan.opacity(0.7)))

                let slatSpacing: CGFloat = 24
                let slatOffset = CGFloat(motion.truncatingRemainder(dividingBy: 1)) * slatSpacing
                var slats = Path()
                var slatX = -slatSpacing + slatOffset
                while slatX < size.width + slatSpacing {
                    slats.move(to: CGPoint(x: slatX, y: beltY + 5))
                    slats.addLine(to: CGPoint(x: slatX + 8, y: beltY + 24))
                    slatX += slatSpacing
                }
                context.stroke(slats, with: .color(.white.opacity(0.13)), lineWidth: 2)

                for index in 0..<9 {
                    let x = 18 + CGFloat(index) * (size.width - 36) / 8
                    context.fill(Path(ellipseIn: CGRect(x: x - 7, y: beltY + 14, width: 14, height: 14)), with: .color(.black.opacity(0.72)))

                    let rollerAngle = motion * .pi * 2
                    var spoke = Path()
                    spoke.move(to: CGPoint(
                        x: x + CGFloat(cos(rollerAngle)) * 5,
                        y: beltY + 21 + CGFloat(sin(rollerAngle)) * 5
                    ))
                    spoke.addLine(to: CGPoint(
                        x: x - CGFloat(cos(rollerAngle)) * 5,
                        y: beltY + 21 - CGFloat(sin(rollerAngle)) * 5
                    ))
                    context.stroke(spoke, with: .color(cyan.opacity(0.7)), lineWidth: 1.4)
                }

                let visibleCubes = 8
                for index in 0..<visibleCubes {
                    let rawPhase = (motion + Double(index) / Double(visibleCubes)).truncatingRemainder(dividingBy: 1)
                    let x = -26 + CGFloat(rawPhase) * (size.width + 52)
                    let cube = CGRect(x: x, y: beltY - 25, width: 24, height: 24)
                    context.fill(Path(roundedRect: cube, cornerRadius: 3), with: .color(index.isMultiple(of: 2) ? amber : cyan))
                    var edge = Path()
                    edge.move(to: CGPoint(x: cube.minX + 5, y: cube.minY + 5))
                    edge.addLine(to: CGPoint(x: cube.maxX - 4, y: cube.minY + 5))
                    context.stroke(edge, with: .color(.white.opacity(0.7)), lineWidth: 1.2)
                }

                let machine = CGRect(x: size.width * 0.38, y: size.height * 0.18, width: size.width * 0.24, height: size.height * 0.38)
                context.fill(Path(roundedRect: machine, cornerRadius: 5), with: .color(Color(red: 0.22, green: 0.24, blue: 0.25)))
                context.stroke(Path(roundedRect: machine, cornerRadius: 5), with: .color(.white.opacity(0.22)), lineWidth: 1.5)
                let pulse = isRunning ? 0.55 + 0.35 * sin(motion * .pi * 8) : 0.35
                context.fill(Path(ellipseIn: CGRect(x: machine.midX - 8, y: machine.minY + 13, width: 16, height: 16)), with: .color(cyan.opacity(pulse)))

                drawArm(context: &context, base: CGPoint(x: size.width * 0.23, y: beltY - 8), angle: -0.75 + 0.32 * sin(motion * .pi * 2), color: amber)
                drawArm(context: &context, base: CGPoint(x: size.width * 0.77, y: beltY - 8), angle: -2.35 - 0.32 * sin(motion * .pi * 2 + .pi), color: cyan)

                var flowArrow = Path()
                flowArrow.move(to: CGPoint(x: 12, y: beltY + 42))
                flowArrow.addLine(to: CGPoint(x: size.width - 14, y: beltY + 42))
                flowArrow.addLine(to: CGPoint(x: size.width - 24, y: beltY + 36))
                flowArrow.move(to: CGPoint(x: size.width - 14, y: beltY + 42))
                flowArrow.addLine(to: CGPoint(x: size.width - 24, y: beltY + 48))
                context.stroke(flowArrow, with: .color(.white.opacity(0.26)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                for index in 0..<3 {
                    let x = size.width * (0.18 + CGFloat(index) * 0.32)
                    context.fill(Path(CGRect(x: x, y: size.height * 0.08, width: 6, height: size.height * 0.14)), with: .color(.white.opacity(0.12)))
                    context.fill(Path(ellipseIn: CGRect(x: x - 5, y: size.height * 0.07, width: 16, height: 10)), with: .color(amber.opacity(0.7)))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.08), lineWidth: 1))
        .accessibilityLabel("Animated robotic factory producing cubes at the selected production rate")
    }

    private func drawArm(context: inout GraphicsContext, base: CGPoint, angle: Double, color: Color) {
        let length: CGFloat = 58
        let elbow = CGPoint(x: base.x + CGFloat(cos(angle)) * length, y: base.y + CGFloat(sin(angle)) * length)
        let hand = CGPoint(x: elbow.x + CGFloat(cos(angle + 0.8)) * length * 0.65, y: elbow.y + CGFloat(sin(angle + 0.8)) * length * 0.65)
        var arm = Path()
        arm.move(to: base)
        arm.addLine(to: elbow)
        arm.addLine(to: hand)
        context.stroke(arm, with: .color(color), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        context.fill(Path(ellipseIn: CGRect(x: elbow.x - 7, y: elbow.y - 7, width: 14, height: 14)), with: .color(.white.opacity(0.8)))
        context.fill(Path(ellipseIn: CGRect(x: base.x - 10, y: base.y - 10, width: 20, height: 20)), with: .color(Color(red: 0.28, green: 0.30, blue: 0.31)))
    }
}

enum LevelFiftyFourShapeKind {
    case circle
    case rectangle
    case triangle
    case diamond
}

struct LevelFiftyFourStage {
    let kind: LevelFiftyFourShapeKind
    let acceptedAngles: [Double]?
}

@Observable
final class MathItLevelFiftyFourViewModel {
    let stages = [
        LevelFiftyFourStage(kind: .circle, acceptedAngles: nil),
        LevelFiftyFourStage(kind: .rectangle, acceptedAngles: [0, 90, 45, 135]),
        LevelFiftyFourStage(kind: .triangle, acceptedAngles: [90]),
        LevelFiftyFourStage(kind: .diamond, acceptedAngles: [0, 90])
    ]

    var stageIndex = 0
    var activeLine: [CGPoint] = []
    var acceptedLine: [CGPoint] = []
    var wrongPulse = false
    var completed = false

    var currentStage: LevelFiftyFourStage {
        stages[min(stageIndex, stages.count - 1)]
    }

    var progress: Double {
        if completed { return 1 }
        let local = acceptedLine.isEmpty ? 0.18 : 0.9
        return (Double(stageIndex) + local) / Double(stages.count)
    }

    func beginCut(at point: CGPoint) {
        guard !completed else { return }
        activeLine = [point]
        acceptedLine.removeAll()
    }

    func continueCut(to point: CGPoint) {
        guard !completed else { return }
        activeLine = activeLine.isEmpty ? [point] : [activeLine[0], point]
    }

    func finishCut(in rect: CGRect) {
        guard !completed, activeLine.count == 2 else {
            activeLine.removeAll()
            return
        }

        if isValidCut(activeLine, in: rect) {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                acceptedLine = activeLine
                activeLine.removeAll()
                wrongPulse = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) { self.advance() }
        } else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.46)) { wrongPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    self.activeLine.removeAll()
                    self.wrongPulse = false
                }
            }
        }
    }

    func resetCut() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            activeLine.removeAll()
            acceptedLine.removeAll()
            wrongPulse = false
        }
    }

    private func advance() {
        if stageIndex == stages.count - 1 {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) { completed = true }
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
                stageIndex += 1
                acceptedLine.removeAll()
                activeLine.removeAll()
            }
        }
    }

    private func isValidCut(_ line: [CGPoint], in rect: CGRect) -> Bool {
        let first = line[0]
        let second = line[1]
        let length = distance(first, second)
        guard length > min(rect.width, rect.height) * 0.58 else { return false }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let centerDistance = distanceFromPoint(center, toLineFrom: first, to: second)
        let centerTolerance = min(rect.width, rect.height) * (currentStage.kind == .triangle ? 0.055 : 0.09)
        guard centerDistance < centerTolerance else { return false }

        guard let angles = currentStage.acceptedAngles else { return true }
        let angle = normalizedAngle(from: first, to: second)
        return angles.contains { target in
            min(abs(angle - target), abs(angle - target + 180), abs(angle - target - 180)) < 14
        }
    }

    private func normalizedAngle(from first: CGPoint, to second: CGPoint) -> Double {
        let radians = atan2(second.y - first.y, second.x - first.x)
        let degrees = abs(radians * 180 / .pi)
        return degrees > 180 ? degrees - 180 : degrees
    }

    private func distanceFromPoint(_ point: CGPoint, toLineFrom first: CGPoint, to second: CGPoint) -> CGFloat {
        let numerator = abs((second.x - first.x) * (first.y - point.y) - (first.x - point.x) * (second.y - first.y))
        return numerator / max(1, distance(first, second))
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}

struct MathItLevelFiftyFourView: View {
    var viewModel: MathItLevelFiftyFourViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardSize = min(size.width - 58, min(size.height * 0.48, 360))
            let boardRect = CGRect(
                x: (size.width - boardSize) / 2,
                y: size.height * 0.28,
                width: boardSize,
                height: boardSize
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)
                shapeBoard(rect: boardRect)

                Button(action: viewModel.resetCut) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.45), radius: 12)
                }
                .buttonStyle(.plain)
                .position(x: boardRect.maxX - 12, y: boardRect.maxY + 36)

                CompletionOverlay(
                    title: "Level 54 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
            .coordinateSpace(name: "levelFiftyFour")
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            Text("split in half")
                .font(.garamond(min(33, size.width * 0.08)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func shapeBoard(rect: CGRect) -> some View {
        ZStack {
            shapeView(kind: viewModel.currentStage.kind)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: accent.opacity(0.28), radius: 18)
                .scaleEffect(viewModel.wrongPulse ? 1.018 : 1)

            cutLine(points: viewModel.acceptedLine, color: accent, width: 5.6)
            cutLine(points: viewModel.activeLine, color: viewModel.wrongPulse ? .red : .white, width: 4.4)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("levelFiftyFour"))
                .onChanged { value in
                    let point = clamp(value.location, to: rect)
                    if viewModel.activeLine.isEmpty {
                        viewModel.beginCut(at: point)
                    } else {
                        viewModel.continueCut(to: point)
                    }
                }
                .onEnded { _ in viewModel.finishCut(in: rect) }
        )
    }

    @ViewBuilder
    private func shapeView(kind: LevelFiftyFourShapeKind) -> some View {
        switch kind {
        case .circle:
            Circle()
                .fill(.white.opacity(0.1))
                .overlay(Circle().stroke(Color.mathGold.opacity(0.95), lineWidth: 2.4))
        case .rectangle:
            RoundedRectangle(cornerRadius: 7)
                .fill(.white.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.mathGold.opacity(0.95), lineWidth: 2.4))
                .padding(.vertical, 58)
        case .triangle:
            LevelFiftyFourTriangle()
                .fill(.white.opacity(0.1))
                .overlay(LevelFiftyFourTriangle().stroke(Color.mathGold.opacity(0.95), lineWidth: 2.4))
                .padding(24)
        case .diamond:
            LevelFiftyFourDiamond()
                .fill(.white.opacity(0.1))
                .overlay(LevelFiftyFourDiamond().stroke(Color.mathGold.opacity(0.95), lineWidth: 2.4))
                .padding(34)
        }
    }

    @ViewBuilder
    private func cutLine(points: [CGPoint], color: Color, width: CGFloat) -> some View {
        if points.count == 2 {
            Path { path in
                path.move(to: points[0])
                path.addLine(to: points[1])
            }
            .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: width, lineCap: .round))
            .shadow(color: color.opacity(0.72), radius: 12)
        }
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }
}

struct LevelFiftyFourTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct LevelFiftyFourDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
