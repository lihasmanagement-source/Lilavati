import SwiftUI
import Foundation

@Observable
final class MathItLevelFiftyFiveViewModel {
    let columns = 18
    let rows = 12
    var revealedCells: Set<Int> = []
    var completed = false

    var progress: Double {
        if completed { return 1 }
        return Double(revealedCells.count) / Double(columns * rows)
    }

    func reveal(at location: CGPoint, in size: CGSize) {
        guard !completed, size.width > 0, size.height > 0 else { return }

        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)
        let column = Int(location.x / cellWidth)
        let row = Int(location.y / cellHeight)

        var changed = false
        for rowOffset in -1...1 {
            for columnOffset in -1...1 {
                let targetRow = row + rowOffset
                let targetColumn = column + columnOffset
                guard targetRow >= 0, targetRow < rows, targetColumn >= 0, targetColumn < columns else { continue }
                changed = revealedCells.insert(targetRow * columns + targetColumn).inserted || changed
            }
        }

        if changed {
            HapticPlayer.playLightTap()
        }

        if progress >= 0.985 {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                completed = true
                revealedCells = Set(0..<(columns * rows))
            }
        }
    }

    func reset() {
        guard !completed else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            revealedCells.removeAll()
        }
    }
}

struct MathItLevelFiftyFiveView: View {
    var viewModel: MathItLevelFiftyFiveViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathItGeometry
    private let brightBlue = Color(red: 0.12, green: 0.62, blue: 1.0)
    private let deepBlue = Color(red: 0.02, green: 0.18, blue: 0.36)
    private let softBlue = Color(red: 0.62, green: 0.86, blue: 1.0)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boardWidth = min(size.width - 38, 390)
            let boardHeight = min(size.height * 0.58, boardWidth * 1.34)
            let boardRect = CGRect(
                x: (size.width - boardWidth) / 2,
                y: size.height * 0.22,
                width: boardWidth,
                height: boardHeight
            )

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                header(size: size)

                revealBoard(rect: boardRect)

                Button(action: viewModel.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.34), radius: 12)
                }
                .buttonStyle(.plain)
                .opacity(viewModel.completed ? 0 : 1)
                .position(x: size.width / 2, y: min(size.height - 82, boardRect.maxY + 54))

                CompletionOverlay(
                    title: "Level 55 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(30)
            }
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            EmptyView()
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.garamond(min(32, size.width * 0.073)))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.42))

            ProgressView(value: viewModel.progress)
                .tint(accent)
                .frame(width: min(size.width - 92, 320))
                .opacity(0.74)
        }
        .position(x: size.width / 2, y: 88)
    }

    private func revealBoard(rect: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black)

            tessellationPattern(size: rect.size)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            revealCover(size: rect.size)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 1.2)
        }
        .frame(width: rect.width, height: rect.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    viewModel.reveal(at: value.location, in: rect.size)
                }
        )
        .position(x: rect.midX, y: rect.midY)
    }

    private func revealCover(size: CGSize) -> some View {
        let cellWidth = size.width / CGFloat(viewModel.columns)
        let cellHeight = size.height / CGFloat(viewModel.rows)

        return ZStack {
            ForEach(0..<viewModel.rows, id: \.self) { row in
                ForEach(0..<viewModel.columns, id: \.self) { column in
                    let cell = row * viewModel.columns + column
                    if !viewModel.revealedCells.contains(cell) {
                        Rectangle()
                            .fill(.black)
                            .frame(width: cellWidth + 1, height: cellHeight + 1)
                            .position(
                                x: CGFloat(column) * cellWidth + cellWidth / 2,
                                y: CGFloat(row) * cellHeight + cellHeight / 2
                            )
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.16), value: viewModel.revealedCells)
    }

    private func tessellationPattern(size: CGSize) -> some View {
        ZStack {
            brightBlue.opacity(0.28)

            ForEach(-2..<9, id: \.self) { row in
                ForEach(-2..<8, id: \.self) { column in
                    let tileWidth = size.width / 3.2
                    let tileHeight = tileWidth * 0.72
                    let xOffset = CGFloat(row.isMultiple(of: 2) ? 0 : 0.5) * tileWidth
                    let x = CGFloat(column) * tileWidth + xOffset
                    let y = CGFloat(row) * tileHeight * 0.72

                    LevelFiftyFiveTessellationTile()
                        .fill(tileFill(row: row, column: column))
                        .overlay(
                            LevelFiftyFiveTessellationTile()
                                .stroke(deepBlue, style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                        )
                        .frame(width: tileWidth, height: tileHeight)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private func tileFill(row: Int, column: Int) -> LinearGradient {
        let colors: [Color] = (row + column).isMultiple(of: 2)
            ? [softBlue, brightBlue.opacity(0.94)]
            : [Color(red: 0.24, green: 0.74, blue: 1.0), Color(red: 0.02, green: 0.42, blue: 0.82)]

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct LevelFiftyFiveTessellationTile: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: 0.14 * w, y: 0.18 * h))
        path.addLine(to: CGPoint(x: 0.5 * w, y: 0.02 * h))
        path.addLine(to: CGPoint(x: 0.86 * w, y: 0.18 * h))
        path.addLine(to: CGPoint(x: 0.86 * w, y: 0.54 * h))
        path.addLine(to: CGPoint(x: 0.62 * w, y: 0.66 * h))
        path.addLine(to: CGPoint(x: 0.62 * w, y: 0.98 * h))
        path.addLine(to: CGPoint(x: 0.38 * w, y: 0.86 * h))
        path.addLine(to: CGPoint(x: 0.38 * w, y: 0.66 * h))
        path.addLine(to: CGPoint(x: 0.14 * w, y: 0.54 * h))
        path.closeSubpath()

        return path
    }
}
