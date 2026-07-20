import SwiftUI

struct MathItLevelEightyTwoView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var locations: [RiverItem: RiverSide] = [.wolf: .left, .goat: .left, .cabbage: .left]
    @State private var boatSide: RiverSide = .left
    @State private var cargo: RiverItem?
    @State private var dragging: RiverDrag?
    @State private var fadingItem: RiverItem?
    @State private var wolfEatingGoat = false
    @State private var ripple = false
    @State private var completed = false

    private var progressValue: Double {
        Double(locations.values.filter { $0 == .right }.count) / 3
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    VStack(spacing: 7) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(34))
                            .tracking(2)
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.horizontal, 58)

                    HStack(spacing: 14) {
                        ProgressView(value: completed ? 1 : progressValue)
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

                    riverBoard
                        .frame(height: min(610, proxy.size.height * 0.72))
                        .padding(.horizontal, 18)
                }
                .padding(.top, 38)
                .padding(.bottom, 76)

                CompletionOverlay(
                    title: "Level 82 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var riverBoard: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shoreSpread = min(170, size.width * 0.36)
            let leftShore = CGPoint(
                x: size.width * 0.29,
                y: size.height * 0.69
            )
            let rightShore = CGPoint(
                x: size.width * 0.71,
                y: size.height * 0.31
            )
            let leftDock = CGPoint(x: size.width * 0.43, y: size.height * 0.58)
            let rightDock = CGPoint(x: size.width * 0.57, y: size.height * 0.42)
            let boatCenter = boatSide == .left ? leftDock : rightDock

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.08, green: 0.45, blue: 1).opacity(completed ? 0.18 : 0.08), Color(red: 0.012, green: 0.014, blue: 0.018), .black],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(size.width, size.height) * 0.72
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(completed ? 0.26 : 0.12), lineWidth: 1.2))

                riverShape(size: size)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                if ripple {
                    Circle()
                        .stroke(Color(red: 0.38, green: 0.78, blue: 1).opacity(0.42), lineWidth: 2)
                        .frame(width: 84, height: 30)
                        .position(boatCenter)
                        .scaleEffect(1.6)
                        .opacity(0)
                        .animation(.easeOut(duration: 0.55), value: ripple)
                }

                boat(center: boatCenter)
                    .onTapGesture {
                        crossRiver()
                    }

                if let cargo {
                    itemIcon(cargo, dimmed: false)
                        .frame(width: 58, height: 58)
                        .position(x: boatCenter.x, y: boatCenter.y - 22)
                        .zIndex(8)
                }

                ForEach(RiverItem.allCases, id: \.self) { item in
                    if cargo != item {
                        let position = itemPosition(item, leftShore: leftShore, rightShore: rightShore, shoreSpread: shoreSpread)
                        itemIcon(item, dimmed: fadingItem == item)
                            .frame(width: 64, height: 64)
                            .position(dragging?.item == item ? dragPoint(for: dragging!) : animatedItemPosition(item, base: position))
                            .opacity(fadingItem == item ? 0.12 : 1)
                            .scaleEffect(wolfEatingGoat && item == .wolf ? 1.18 : 1)
                            .zIndex(dragging?.item == item ? 12 : 5)
                            .gesture(!completed ? itemDrag(item: item, origin: position, boatCenter: boatCenter) : nil)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func riverShape(size: CGSize) -> some View {
        let start = CGPoint(x: size.width * -0.08, y: size.height * 0.29)
        let end = CGPoint(x: size.width * 1.08, y: size.height * 0.76)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        let nx = -dy / length
        let ny = dx / length
        let halfWidth = size.height * 0.125
        let tx = dx / length
        let ty = dy / length
        let shape = riverPath(start: start, end: end, nx: nx, ny: ny, halfWidth: halfWidth)

        return TimelineView(.animation) { timeline in
            let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2)

            ZStack {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.015, green: 0.12, blue: 0.32).opacity(0.96),
                                Color(red: 0.025, green: 0.3, blue: 0.75).opacity(0.9),
                                Color(red: 0.06, green: 0.58, blue: 1).opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 0.08, green: 0.48, blue: 1).opacity(0.35), radius: 16)

                wavePath(start: start, dx: dx, dy: dy, nx: nx, ny: ny, tx: tx, ty: ty, length: length, halfWidth: halfWidth, phase: phase, count: 9, amplitude: 5)
                    .stroke(Color(red: 0.35, green: 0.75, blue: 1).opacity(0.46), style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
                    .clipShape(shape)

                wavePath(start: start, dx: dx, dy: dy, nx: nx, ny: ny, tx: tx, ty: ty, length: length, halfWidth: halfWidth, phase: phase + 0.38, count: 5, amplitude: 8)
                    .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .clipShape(shape)

                shape
                    .stroke(Color(red: 0.43, green: 0.83, blue: 1).opacity(0.42), lineWidth: 2)
            }
        }
    }

    private func riverPath(start: CGPoint, end: CGPoint, nx: CGFloat, ny: CGFloat, halfWidth: CGFloat) -> Path {
        Path { path in
            let topStart = CGPoint(x: start.x + nx * halfWidth * 0.82, y: start.y + ny * halfWidth * 0.82)
            let topEnd = CGPoint(x: end.x + nx * halfWidth * 1.04, y: end.y + ny * halfWidth * 1.04)
            let bottomEnd = CGPoint(x: end.x - nx * halfWidth * 0.92, y: end.y - ny * halfWidth * 0.92)
            let bottomStart = CGPoint(x: start.x - nx * halfWidth * 1.1, y: start.y - ny * halfWidth * 1.1)

            path.move(to: topStart)
            path.addCurve(
                to: topEnd,
                control1: CGPoint(x: start.x + nx * halfWidth * 1.15 + 130, y: start.y + ny * halfWidth * 1.15 + 30),
                control2: CGPoint(x: end.x + nx * halfWidth * 0.8 - 150, y: end.y + ny * halfWidth * 0.8 - 44)
            )
            path.addCurve(
                to: bottomEnd,
                control1: CGPoint(x: end.x + nx * halfWidth * 0.48, y: end.y + ny * halfWidth * 0.48),
                control2: CGPoint(x: end.x - nx * halfWidth * 0.48, y: end.y - ny * halfWidth * 0.48)
            )
            path.addCurve(
                to: bottomStart,
                control1: CGPoint(x: end.x - nx * halfWidth * 1.18 - 120, y: end.y - ny * halfWidth * 1.18 - 18),
                control2: CGPoint(x: start.x - nx * halfWidth * 0.84 + 140, y: start.y - ny * halfWidth * 0.84 + 46)
            )
            path.addCurve(
                to: topStart,
                control1: CGPoint(x: start.x - nx * halfWidth * 0.58, y: start.y - ny * halfWidth * 0.58),
                control2: CGPoint(x: start.x + nx * halfWidth * 0.58, y: start.y + ny * halfWidth * 0.58)
            )
            path.closeSubpath()
        }
    }

    private func wavePath(start: CGPoint, dx: CGFloat, dy: CGFloat, nx: CGFloat, ny: CGFloat, tx: CGFloat, ty: CGFloat, length: CGFloat, halfWidth: CGFloat, phase: CGFloat, count: Int, amplitude: CGFloat) -> Path {
        Path { path in
            for index in 0..<count {
                let progress = CGFloat(index) / CGFloat(max(1, count - 1))
                let offset = -halfWidth * 0.72 + progress * halfWidth * 1.44
                let shiftedStart = CGPoint(x: start.x - tx * length * phase, y: start.y - ty * length * phase)
                var t: CGFloat = 0
                var didMove = false

                while t <= 2.08 {
                    let wave = sin((t * 7.5 + progress * 2.4 + phase * 2) * .pi) * amplitude
                    let point = CGPoint(
                        x: shiftedStart.x + dx * t + nx * (offset + wave),
                        y: shiftedStart.y + dy * t + ny * (offset + wave)
                    )

                    if didMove {
                        path.addLine(to: point)
                    } else {
                        path.move(to: point)
                        didMove = true
                    }
                    t += 0.035
                }
            }
        }
    }

    private func boat(center: CGPoint) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: -48, y: -12))
                path.addQuadCurve(to: CGPoint(x: 0, y: -34), control: CGPoint(x: -22, y: -34))
                path.addQuadCurve(to: CGPoint(x: 48, y: -12), control: CGPoint(x: 22, y: -34))
                path.addQuadCurve(to: CGPoint(x: 34, y: 28), control: CGPoint(x: 50, y: 14))
                path.addQuadCurve(to: CGPoint(x: -34, y: 28), control: CGPoint(x: 0, y: 40))
                path.addQuadCurve(to: CGPoint(x: -48, y: -12), control: CGPoint(x: -50, y: 14))
                path.closeSubpath()
            }
            .fill(.black.opacity(0.78))
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: -48, y: -12))
                    path.addQuadCurve(to: CGPoint(x: 0, y: -34), control: CGPoint(x: -22, y: -34))
                    path.addQuadCurve(to: CGPoint(x: 48, y: -12), control: CGPoint(x: 22, y: -34))
                    path.addQuadCurve(to: CGPoint(x: 34, y: 28), control: CGPoint(x: 50, y: 14))
                    path.addQuadCurve(to: CGPoint(x: -34, y: 28), control: CGPoint(x: 0, y: 40))
                    path.addQuadCurve(to: CGPoint(x: -48, y: -12), control: CGPoint(x: -50, y: 14))
                    path.closeSubpath()
                    path.move(to: CGPoint(x: -36, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 36, y: 0), control: CGPoint(x: 0, y: -18))
                    path.move(to: CGPoint(x: -38, y: 12))
                    path.addQuadCurve(to: CGPoint(x: 38, y: 12), control: CGPoint(x: 0, y: 26))
                    path.move(to: CGPoint(x: 0, y: -28))
                    path.addLine(to: CGPoint(x: 0, y: -2))
                    path.move(to: CGPoint(x: -22, y: 2))
                    path.addLine(to: CGPoint(x: -22, y: 22))
                    path.move(to: CGPoint(x: 22, y: 2))
                    path.addLine(to: CGPoint(x: 22, y: 22))
                }
                .stroke(.white.opacity(0.94), lineWidth: 2.2)
            )
            .shadow(color: Color(red: 0.2, green: 0.68, blue: 1).opacity(0.45), radius: 12)
        }
        .frame(width: 112, height: 78)
        .position(center)
    }

    private func itemIcon(_ item: RiverItem, dimmed: Bool) -> some View {
        ZStack {
            item.lineArt
                .stroke(item.color.opacity(dimmed ? 0.3 : 1), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .shadow(color: item.color.opacity(dimmed ? 0.05 : 0.8), radius: 12)
        }
    }

    private func itemPosition(_ item: RiverItem, leftShore: CGPoint, rightShore: CGPoint, shoreSpread: CGFloat) -> CGPoint {
        let shore = locations[item] == .left ? leftShore : rightShore
        let xOffset = CGFloat(item.order - 1) * shoreSpread * 0.42
        return CGPoint(x: shore.x + xOffset, y: shore.y)
    }

    private func itemDrag(item: RiverItem, origin: CGPoint, boatCenter: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                dragging = RiverDrag(item: item, origin: origin, translation: gesture.translation)
            }
            .onEnded { gesture in
                let drop = CGPoint(x: origin.x + gesture.translation.width, y: origin.y + gesture.translation.height)
                dragging = nil
                guard locations[item] == boatSide, boatContains(drop, center: boatCenter) else { return }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    if let oldCargo = cargo {
                        locations[oldCargo] = boatSide
                    }
                    cargo = item
                }
            }
    }

    private func crossRiver() {
        guard !completed else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            boatSide = boatSide.opposite
            if let cargo {
                locations[cargo] = boatSide
            }
            ripple.toggle()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            cargo = nil
            evaluateState()
        }
    }

    private func evaluateState() {
        if let unsafe = unsafeItem() {
            rewind(afterFading: unsafe)
            return
        }

        if RiverItem.allCases.allSatisfy({ locations[$0] == .right }) {
            finishLevel()
        }
    }

    private func unsafeItem() -> RiverItem? {
        for side in RiverSide.allCases where side != boatSide {
            let items = Set(RiverItem.allCases.filter { locations[$0] == side })
            if items.contains(.wolf), items.contains(.goat) {
                return .goat
            }
            if items.contains(.goat), items.contains(.cabbage) {
                return .cabbage
            }
        }
        return nil
    }

    private func rewind(afterFading item: RiverItem) {
        withAnimation(.easeInOut(duration: 0.22)) {
            fadingItem = item
            wolfEatingGoat = item == .goat
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                locations = [.wolf: .left, .goat: .left, .cabbage: .left]
                boatSide = .left
                cargo = nil
                dragging = nil
                fadingItem = nil
                wolfEatingGoat = false
            }
        }
    }

    private func finishLevel() {
        withAnimation(.easeInOut(duration: 0.44)) {
            completed = true
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            locations = [.wolf: .left, .goat: .left, .cabbage: .left]
            boatSide = .left
            cargo = nil
            dragging = nil
            fadingItem = nil
            wolfEatingGoat = false
            ripple = false
            completed = false
        }
    }

    private func animatedItemPosition(_ item: RiverItem, base: CGPoint) -> CGPoint {
        guard wolfEatingGoat else { return base }
        switch item {
        case .wolf:
            return CGPoint(x: base.x + 48, y: base.y)
        case .goat:
            return CGPoint(x: base.x - 16, y: base.y)
        case .cabbage:
            return base
        }
    }

    private func dragPoint(for drag: RiverDrag) -> CGPoint {
        CGPoint(x: drag.origin.x + drag.translation.width, y: drag.origin.y + drag.translation.height)
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    private func boatContains(_ point: CGPoint, center: CGPoint) -> Bool {
        abs(point.x - center.x) <= 92 && abs(point.y - center.y) <= 72
    }
}

private enum RiverSide: CaseIterable {
    case left
    case right

    var opposite: RiverSide {
        self == .left ? .right : .left
    }
}

private enum RiverItem: CaseIterable, Hashable {
    case wolf
    case goat
    case cabbage

    var order: Int {
        switch self {
        case .wolf: 0
        case .goat: 1
        case .cabbage: 2
        }
    }

    var color: Color {
        switch self {
        case .wolf:
            Color.white
        case .goat:
            Color.white
        case .cabbage:
            Color(red: 0.64, green: 1, blue: 0.42)
        }
    }

    var lineArt: Path {
        switch self {
        case .wolf:
            return Path { path in
                path.move(to: CGPoint(x: 12, y: 24))
                path.addQuadCurve(to: CGPoint(x: 16, y: 4), control: CGPoint(x: 8, y: 10))
                path.addQuadCurve(to: CGPoint(x: 31, y: 19), control: CGPoint(x: 24, y: 8))
                path.addQuadCurve(to: CGPoint(x: 45, y: 19), control: CGPoint(x: 38, y: 16))
                path.addQuadCurve(to: CGPoint(x: 60, y: 4), control: CGPoint(x: 52, y: 8))
                path.addQuadCurve(to: CGPoint(x: 64, y: 25), control: CGPoint(x: 68, y: 10))
                path.addLine(to: CGPoint(x: 58, y: 31))
                path.addLine(to: CGPoint(x: 64, y: 35))
                path.addLine(to: CGPoint(x: 57, y: 39))
                path.addLine(to: CGPoint(x: 61, y: 43))
                path.addLine(to: CGPoint(x: 52, y: 48))
                path.addQuadCurve(to: CGPoint(x: 42, y: 60), control: CGPoint(x: 48, y: 56))
                path.addLine(to: CGPoint(x: 34, y: 60))
                path.addQuadCurve(to: CGPoint(x: 24, y: 48), control: CGPoint(x: 28, y: 56))
                path.addLine(to: CGPoint(x: 15, y: 43))
                path.addLine(to: CGPoint(x: 19, y: 39))
                path.addLine(to: CGPoint(x: 12, y: 35))
                path.addLine(to: CGPoint(x: 18, y: 31))
                path.closeSubpath()
                path.move(to: CGPoint(x: 20, y: 9))
                path.addLine(to: CGPoint(x: 29, y: 25))
                path.addLine(to: CGPoint(x: 22, y: 33))
                path.move(to: CGPoint(x: 56, y: 9))
                path.addLine(to: CGPoint(x: 47, y: 25))
                path.addLine(to: CGPoint(x: 54, y: 33))
                path.move(to: CGPoint(x: 25, y: 34))
                path.addQuadCurve(to: CGPoint(x: 32, y: 38), control: CGPoint(x: 31, y: 33))
                path.move(to: CGPoint(x: 51, y: 34))
                path.addQuadCurve(to: CGPoint(x: 44, y: 38), control: CGPoint(x: 45, y: 33))
                path.move(to: CGPoint(x: 38, y: 43))
                path.addQuadCurve(to: CGPoint(x: 32, y: 44), control: CGPoint(x: 34, y: 41))
                path.addQuadCurve(to: CGPoint(x: 38, y: 49), control: CGPoint(x: 33, y: 50))
                path.addQuadCurve(to: CGPoint(x: 44, y: 44), control: CGPoint(x: 43, y: 50))
                path.addQuadCurve(to: CGPoint(x: 38, y: 43), control: CGPoint(x: 42, y: 41))
                path.move(to: CGPoint(x: 32, y: 49))
                path.addQuadCurve(to: CGPoint(x: 26, y: 55), control: CGPoint(x: 28, y: 52))
                path.move(to: CGPoint(x: 44, y: 49))
                path.addQuadCurve(to: CGPoint(x: 50, y: 55), control: CGPoint(x: 48, y: 52))
            }
        case .goat:
            return Path { path in
                path.move(to: CGPoint(x: 19, y: 18))
                path.addQuadCurve(to: CGPoint(x: 11, y: 30), control: CGPoint(x: 8, y: 22))
                path.addQuadCurve(to: CGPoint(x: 25, y: 31), control: CGPoint(x: 17, y: 35))
                path.move(to: CGPoint(x: 49, y: 18))
                path.addQuadCurve(to: CGPoint(x: 57, y: 30), control: CGPoint(x: 60, y: 22))
                path.addQuadCurve(to: CGPoint(x: 43, y: 31), control: CGPoint(x: 51, y: 35))
                path.move(to: CGPoint(x: 25, y: 18))
                path.addQuadCurve(to: CGPoint(x: 15, y: 0), control: CGPoint(x: 20, y: 5))
                path.addQuadCurve(to: CGPoint(x: 30, y: 20), control: CGPoint(x: 31, y: 5))
                path.move(to: CGPoint(x: 43, y: 18))
                path.addQuadCurve(to: CGPoint(x: 53, y: 0), control: CGPoint(x: 48, y: 5))
                path.addQuadCurve(to: CGPoint(x: 38, y: 20), control: CGPoint(x: 37, y: 5))
                path.move(to: CGPoint(x: 25, y: 18))
                path.addQuadCurve(to: CGPoint(x: 43, y: 18), control: CGPoint(x: 34, y: 13))
                path.addQuadCurve(to: CGPoint(x: 50, y: 33), control: CGPoint(x: 51, y: 25))
                path.addQuadCurve(to: CGPoint(x: 42, y: 52), control: CGPoint(x: 50, y: 44))
                path.addQuadCurve(to: CGPoint(x: 34, y: 58), control: CGPoint(x: 39, y: 58))
                path.addQuadCurve(to: CGPoint(x: 26, y: 52), control: CGPoint(x: 29, y: 58))
                path.addQuadCurve(to: CGPoint(x: 18, y: 33), control: CGPoint(x: 18, y: 44))
                path.addQuadCurve(to: CGPoint(x: 25, y: 18), control: CGPoint(x: 17, y: 25))
                path.move(to: CGPoint(x: 27, y: 33))
                path.addQuadCurve(to: CGPoint(x: 32, y: 36), control: CGPoint(x: 31, y: 32))
                path.move(to: CGPoint(x: 41, y: 33))
                path.addQuadCurve(to: CGPoint(x: 36, y: 36), control: CGPoint(x: 37, y: 32))
                path.move(to: CGPoint(x: 34, y: 43))
                path.addLine(to: CGPoint(x: 29, y: 48))
                path.move(to: CGPoint(x: 34, y: 43))
                path.addLine(to: CGPoint(x: 39, y: 48))
                path.move(to: CGPoint(x: 29, y: 52))
                path.addQuadCurve(to: CGPoint(x: 39, y: 52), control: CGPoint(x: 34, y: 56))
                path.move(to: CGPoint(x: 30, y: 58))
                path.addLine(to: CGPoint(x: 27, y: 66))
                path.addQuadCurve(to: CGPoint(x: 34, y: 61), control: CGPoint(x: 32, y: 65))
                path.addQuadCurve(to: CGPoint(x: 41, y: 66), control: CGPoint(x: 36, y: 65))
                path.addLine(to: CGPoint(x: 38, y: 58))
            }
        case .cabbage:
            return Path { path in
                path.move(to: CGPoint(x: 34, y: 5))
                path.addQuadCurve(to: CGPoint(x: 48, y: 14), control: CGPoint(x: 43, y: 4))
                path.addQuadCurve(to: CGPoint(x: 58, y: 27), control: CGPoint(x: 58, y: 13))
                path.addQuadCurve(to: CGPoint(x: 58, y: 48), control: CGPoint(x: 69, y: 38))
                path.addQuadCurve(to: CGPoint(x: 43, y: 62), control: CGPoint(x: 54, y: 63))
                path.addQuadCurve(to: CGPoint(x: 34, y: 64), control: CGPoint(x: 39, y: 66))
                path.addQuadCurve(to: CGPoint(x: 25, y: 62), control: CGPoint(x: 29, y: 66))
                path.addQuadCurve(to: CGPoint(x: 10, y: 48), control: CGPoint(x: 14, y: 63))
                path.addQuadCurve(to: CGPoint(x: 10, y: 27), control: CGPoint(x: -1, y: 38))
                path.addQuadCurve(to: CGPoint(x: 20, y: 14), control: CGPoint(x: 10, y: 13))
                path.addQuadCurve(to: CGPoint(x: 34, y: 5), control: CGPoint(x: 25, y: 4))
                path.move(to: CGPoint(x: 34, y: 13))
                path.addLine(to: CGPoint(x: 34, y: 63))
                path.move(to: CGPoint(x: 34, y: 29))
                path.addLine(to: CGPoint(x: 25, y: 19))
                path.move(to: CGPoint(x: 34, y: 30))
                path.addLine(to: CGPoint(x: 45, y: 18))
                path.move(to: CGPoint(x: 34, y: 43))
                path.addLine(to: CGPoint(x: 20, y: 32))
                path.move(to: CGPoint(x: 34, y: 44))
                path.addLine(to: CGPoint(x: 50, y: 31))
                path.move(to: CGPoint(x: 34, y: 56))
                path.addLine(to: CGPoint(x: 18, y: 45))
                path.move(to: CGPoint(x: 34, y: 56))
                path.addLine(to: CGPoint(x: 50, y: 45))
            }
        }
    }
}

private struct RiverDrag: Equatable {
    let item: RiverItem
    let origin: CGPoint
    var translation: CGSize
}
