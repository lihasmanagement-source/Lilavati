import SwiftUI

struct MathItLevelSeventySixView: View {
    @Environment(\.mathItAccent) private var accent

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var towers: [[Int]] = [[4, 3, 2, 1], [], []]
    @State private var dragging: HanoiDrag?
    @State private var completed = false
    @State private var wrongPulse = false

    private var solved: Bool { towers[2] == [4, 3, 2, 1] }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 12) {
                    VStack(spacing: 7) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(36))
                            .tracking(2)
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.76))
                    }
                    .padding(.horizontal, 58)

                    hanoiBoard
                        .frame(height: min(600, proxy.size.height * 0.68))
                        .padding(.horizontal, 18)

                    HStack(spacing: 12) {
                        ProgressView(value: Double(towers[2].count) / 4.0)
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
                    title: "Level 76 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var hanoiBoard: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let baseY = size.height * 0.76
            let topY = size.height * 0.17

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.08),
                                Color(red: 0.012, green: 0.014, blue: 0.018),
                                .black
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: max(size.width, size.height) * 0.72
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(wrongPulse ? .red.opacity(0.82) : .white.opacity(0.12), lineWidth: 1.2))

                ForEach(0..<3, id: \.self) { tower in
                    let centerX = towerCenter(tower, width: size.width)

                    Capsule()
                        .fill(.white.opacity(0.82))
                        .frame(width: 10, height: baseY - topY)
                        .position(x: centerX, y: (baseY + topY) / 2)
                        .shadow(color: .white.opacity(0.12), radius: 5)

                    Capsule()
                        .fill(tower == 2 ? accent.opacity(0.62) : .white.opacity(0.28))
                        .frame(width: size.width / 3 * 0.84, height: 12)
                        .position(x: centerX, y: baseY + 8)

                    ForEach(Array(towers[tower].enumerated()), id: \.element) { index, disk in
                        let topDisk = towers[tower].last == disk
                        let isDragging = dragging?.disk == disk
                        diskView(disk: disk, in: size, lifted: false)
                            .opacity(isDragging ? 0 : 1)
                            .position(diskPosition(tower: tower, stackIndex: index, disk: disk, in: size))
                            .gesture(topDisk && !completed ? dragGesture(disk: disk, source: tower, size: size) : nil)
                    }
                }

                if let dragging {
                    diskView(disk: dragging.disk, in: size, lifted: true)
                        .position(
                            x: dragging.origin.x + dragging.translation.width,
                            y: dragging.origin.y + dragging.translation.height
                        )
                        .zIndex(10)
                }
            }
        }
    }

    private func diskView(disk: Int, in size: CGSize, lifted: Bool) -> some View {
        let colors: [Color] = [
            Color(red: 0.37, green: 0.68, blue: 0.98),
            Color(red: 0.56, green: 0.43, blue: 0.82),
            Color(red: 0.66, green: 0.78, blue: 0.38),
            Color(red: 0.82, green: 0.32, blue: 0.30)
        ]
        let columnWidth = size.width / 3
        let width = columnWidth * (0.32 + CGFloat(disk) * 0.12)

        return RoundedRectangle(cornerRadius: 7)
            .fill(colors[disk - 1].opacity(lifted ? 0.98 : 0.84))
            .frame(width: width, height: 32)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.72), lineWidth: 2))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(lifted ? 0.55 : 0.16), lineWidth: 1))
            .shadow(color: colors[disk - 1].opacity(lifted ? 0.62 : 0.22), radius: lifted ? 16 : 6)
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }

    private func dragGesture(disk: Int, source: Int, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragging == nil {
                    let index = max(0, towers[source].count - 1)
                    dragging = HanoiDrag(
                        disk: disk,
                        source: source,
                        origin: diskPosition(tower: source, stackIndex: index, disk: disk, in: size),
                        translation: value.translation
                    )
                } else {
                    dragging?.translation = value.translation
                }
            }
            .onEnded { value in
                guard let current = dragging else { return }
                dragging = nil

                let dropX = current.origin.x + value.translation.width
                let destination = nearestTower(to: dropX, width: size.width)
                moveDisk(current.disk, from: current.source, to: destination)
            }
    }

    private func moveDisk(_ disk: Int, from source: Int, to destination: Int) {
        guard source != destination else { return }
        guard towers[source].last == disk else { return }

        if let destinationTop = towers[destination].last, destinationTop < disk {
            pulseWrong()
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            _ = towers[source].popLast()
            towers[destination].append(disk)
            completed = solved
        }
    }

    private func diskPosition(tower: Int, stackIndex: Int, disk: Int, in size: CGSize) -> CGPoint {
        CGPoint(
            x: towerCenter(tower, width: size.width),
            y: size.height * 0.76 - CGFloat(stackIndex) * 36
        )
    }

    private func towerCenter(_ tower: Int, width: CGFloat) -> CGFloat {
        width * (CGFloat(tower) + 0.5) / 3
    }

    private func nearestTower(to x: CGFloat, width: CGFloat) -> Int {
        let clamped = max(0, min(2, Int((x / width * 3).rounded(.down))))
        return clamped
    }

    private func pulseWrong() {
        withAnimation(.easeOut(duration: 0.12)) {
            wrongPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeOut(duration: 0.18)) {
                wrongPulse = false
            }
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            towers = [[4, 3, 2, 1], [], []]
            dragging = nil
            completed = false
            wrongPulse = false
        }
    }
}

private struct HanoiDrag: Equatable {
    let disk: Int
    let source: Int
    let origin: CGPoint
    var translation: CGSize
}
