import SwiftUI

struct MathItLevelOneHundredFifteenView: View {
    private let stages = SheetMetalStage.all
    private let steel = Color(red: 0.12, green: 0.15, blue: 0.18)
    private let yellow = Color(red: 1.0, green: 0.73, blue: 0.12)
    private let cyan = Color(red: 0.20, green: 0.78, blue: 0.82)
    private let red = Color(red: 0.95, green: 0.28, blue: 0.24)

    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var placements: [Int: SheetPlacement] = [:]
    @State private var selectedKind: SheetPieceKind = .square
    @State private var selectedRotated = false
    @State private var dragOffsets: [Int: CGSize] = [:]
    @State private var invalidFlash = false
    @State private var solvedBounds: SheetBounds?
    @State private var stageSolved = false
    @State private var clearingPieceIDs: Set<Int> = []
    @State private var matchFlash = false
    @State private var completed = false
    @State private var stageToken = UUID()

    private var stage: SheetMetalStage { stages[stageIndex] }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 760

            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.052).ignoresSafeArea()

                Canvas { context, size in
                    for x in stride(from: 0.0, through: size.width, by: 28) {
                        var line = Path()
                        line.move(to: CGPoint(x: x, y: 0))
                        line.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(line, with: .color(.white.opacity(0.018)), lineWidth: 1)
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: compact ? 9 : 14) {
                    workshopHeader
                        .padding(.top, compact ? 10 : 20)

                    cuttingBed
                        .frame(maxWidth: 650)
                        .frame(height: min(proxy.size.width - 24, compact ? 390 : 470))

                    inventory
                        .frame(maxWidth: 650)

                    statusBar
                        .frame(maxWidth: 650)
                        .padding(.bottom, compact ? 8 : 18)
                }
                .padding(.horizontal, 14)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                CompletionOverlay(
                    title: "Level 115 Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: resetLevel,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(50)
            }
        }
        .environment(\.mathItAccent, yellow)
    }

    private var workshopHeader: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(stages.indices, id: \.self) { index in
                    Rectangle()
                        .fill(index < stageIndex ? cyan : index == stageIndex ? yellow : .white.opacity(0.12))
                        .frame(width: index == stageIndex ? 44 : 26, height: 4)
                }
            }

            Text("PANEL \(stageIndex + 1) · \(stage.formula)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(stageSolved ? "CERTIFIED  \(stage.factored)" : "UNFACTORED SHEET")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(stageSolved ? cyan : .white.opacity(0.45))
        }
    }

    private var cuttingBed: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = floor((side - 34) / 8)
            let boardSide = cell * 8
            let origin = CGPoint(x: (geo.size.width - boardSide) / 2, y: (geo.size.height - boardSide) / 2)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(steel)
                    .frame(width: boardSide + 22, height: boardSide + 22)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.16), lineWidth: 1))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                grid(cell: cell, side: boardSide)
                    .frame(width: boardSide, height: boardSide)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            let column = Int(value.location.x / cell)
                            let row = Int(value.location.y / cell)
                            placeSelected(atColumn: column, row: row)
                        }
                    )
                    .position(x: origin.x + boardSide / 2, y: origin.y + boardSide / 2)

                ForEach(stage.pieces) { piece in
                    if let placement = placements[piece.id] {
                        placedPiece(piece, placement: placement, cell: cell)
                            .position(pieceCenter(placement: placement, piece: piece, cell: cell, origin: origin))
                    }
                }

                if let bounds = solvedBounds {
                    certifiedOutline(bounds: bounds, cell: cell, origin: origin)
                }
            }
            .coordinateSpace(name: "sheetBed")
            .overlay {
                if invalidFlash {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(red, lineWidth: 5)
                        .shadow(color: red, radius: 12)
                        .transition(.opacity)
                }

                if matchFlash {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cyan.opacity(0.16))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(cyan, lineWidth: 3))
                        .shadow(color: cyan, radius: 18)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func grid(cell: CGFloat, side: CGFloat) -> some View {
        Canvas { context, _ in
            context.fill(Path(CGRect(x: 0, y: 0, width: side, height: side)), with: .color(Color.black.opacity(0.25)))
            for index in 0...8 {
                let p = CGFloat(index) * cell
                var vertical = Path()
                vertical.move(to: CGPoint(x: p, y: 0))
                vertical.addLine(to: CGPoint(x: p, y: side))
                context.stroke(vertical, with: .color(.white.opacity(0.11)), lineWidth: 1)

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: p))
                horizontal.addLine(to: CGPoint(x: side, y: p))
                context.stroke(horizontal, with: .color(.white.opacity(0.11)), lineWidth: 1)
            }

            for row in 0..<8 {
                for column in 0..<8 {
                    let dot = CGRect(x: CGFloat(column) * cell + 4, y: CGFloat(row) * cell + 4, width: 2.5, height: 2.5)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.12)))
                }
            }
        }
    }

    private func placedPiece(_ piece: SheetPiece, placement: SheetPlacement, cell: CGFloat) -> some View {
        let dimensions = piece.dimensions(rotated: placement.rotated)
        let offset = dragOffsets[piece.id] ?? .zero

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(piece.kind.color)
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.75), lineWidth: 1.3)
            sheetGrain
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(piece.kind.label)
                .font(.system(size: max(10, cell * 0.34), weight: .black, design: .serif))
                .foregroundStyle(Color.black.opacity(0.72))
                .minimumScaleFactor(0.6)
        }
        .frame(width: CGFloat(dimensions.width) * cell - 3, height: CGFloat(dimensions.height) * cell - 3)
        .offset(offset)
        .scaleEffect(clearingPieceIDs.contains(piece.id) ? 0.08 : 1)
        .rotationEffect(.degrees(clearingPieceIDs.contains(piece.id) ? (piece.id.isMultiple(of: 2) ? 24 : -24) : 0))
        .offset(y: clearingPieceIDs.contains(piece.id) ? 70 : 0)
        .opacity(clearingPieceIDs.contains(piece.id) ? 0 : 1)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !stageSolved else { return }
            placements[piece.id] = nil
            dragOffsets[piece.id] = nil
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("sheetBed"))
                .onChanged { value in
                    guard !stageSolved else { return }
                    dragOffsets[piece.id] = value.translation
                }
                .onEnded { value in
                    guard !stageSolved else { return }
                    dragOffsets[piece.id] = nil
                    let dc = Int((value.translation.width / cell).rounded())
                    let dr = Int((value.translation.height / cell).rounded())
                    move(piece, to: SheetPlacement(column: placement.column + dc, row: placement.row + dr, rotated: placement.rotated))
                }
        )
        .accessibilityLabel("\(piece.kind.label) sheet tile")
    }

    private var sheetGrain: some View {
        Canvas { context, size in
            for x in stride(from: -size.height, through: size.width, by: 12) {
                var line = Path()
                line.move(to: CGPoint(x: x, y: size.height))
                line.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(line, with: .color(.white.opacity(0.11)), lineWidth: 1)
            }
        }
    }

    private func certifiedOutline(bounds: SheetBounds, cell: CGFloat, origin: CGPoint) -> some View {
        let rect = CGRect(
            x: origin.x + CGFloat(bounds.minColumn) * cell - 5,
            y: origin.y + CGFloat(bounds.minRow) * cell - 5,
            width: CGFloat(bounds.width) * cell + 10,
            height: CGFloat(bounds.height) * cell + 10
        )

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .stroke(cyan, style: StrokeStyle(lineWidth: 4, dash: [11, 6]))
                .shadow(color: cyan.opacity(0.8), radius: 9)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            Text(bounds.width == stage.factorTopUnits ? stage.factorTop : stage.factorSide)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
                .position(x: rect.midX, y: max(12, rect.minY - 14))

            Text(bounds.width == stage.factorTopUnits ? stage.factorSide : stage.factorTop)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
                .rotationEffect(.degrees(-90))
                .position(x: max(13, rect.minX - 17), y: rect.midY)
        }
        .allowsHitTesting(false)
    }

    private var inventory: some View {
        HStack(spacing: 9) {
            ForEach(SheetPieceKind.allCases, id: \.self) { kind in
                let remaining = stage.pieces.filter { $0.kind == kind && placements[$0.id] == nil }.count
                Button {
                    selectedKind = kind
                    if kind != .strip { selectedRotated = false }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: kind.icon)
                        Text(kind.label)
                            .font(.system(size: 15, weight: .black, design: .serif))
                        Text("×\(remaining)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(selectedKind == kind ? kind.color.opacity(0.72) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(selectedKind == kind ? yellow : .white.opacity(0.11), lineWidth: selectedKind == kind ? 2 : 1))
                }
                .buttonStyle(.plain)
                .disabled(stageSolved || remaining == 0)
            }

            Button {
                selectedRotated.toggle()
            } label: {
                Image(systemName: "rotate.right")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 46, height: 46)
                    .foregroundStyle(selectedRotated ? yellow : .white.opacity(0.72))
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.11), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(selectedKind != .strip || stageSolved)
            .accessibilityLabel("Rotate x tile")
        }
    }

    private var statusBar: some View {
        let filled = occupiedCells().count
        let total = stage.totalArea

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(stageSolved ? "RECTANGLE COMPLETE" : "CUTTING BED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.42))
                Text(stageSolved ? stage.factored : "\(filled) / \(total) AREA INSTALLED")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(stageSolved ? cyan : .white)
            }

            Spacer()

            if !stageSolved {
                Button(action: clearBed) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("Clear cutting bed")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(Color(red: 0.075, green: 0.09, blue: 0.105), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(stageSolved ? cyan.opacity(0.5) : .white.opacity(0.09), lineWidth: 1))
    }

    private func pieceCenter(placement: SheetPlacement, piece: SheetPiece, cell: CGFloat, origin: CGPoint) -> CGPoint {
        let dimensions = piece.dimensions(rotated: placement.rotated)
        return CGPoint(
            x: origin.x + (CGFloat(placement.column) + CGFloat(dimensions.width) / 2) * cell,
            y: origin.y + (CGFloat(placement.row) + CGFloat(dimensions.height) / 2) * cell
        )
    }

    private func placeSelected(atColumn column: Int, row: Int) {
        guard !stageSolved,
              let piece = stage.pieces.first(where: { $0.kind == selectedKind && placements[$0.id] == nil }) else { return }
        let placement = SheetPlacement(column: column, row: row, rotated: selectedKind == .strip && selectedRotated)
        guard canPlace(piece, at: placement, excluding: nil) else { flashInvalid(); return }
        placements[piece.id] = placement
        checkForRectangle()
    }

    private func move(_ piece: SheetPiece, to placement: SheetPlacement) {
        guard canPlace(piece, at: placement, excluding: piece.id) else { flashInvalid(); return }
        placements[piece.id] = placement
        checkForRectangle()
    }

    private func canPlace(_ piece: SheetPiece, at placement: SheetPlacement, excluding excludedID: Int?) -> Bool {
        let dimensions = piece.dimensions(rotated: placement.rotated)
        guard placement.column >= 0, placement.row >= 0,
              placement.column + dimensions.width <= 8,
              placement.row + dimensions.height <= 8 else { return false }

        let proposed = cells(for: piece, placement: placement)
        let occupied = Set(stage.pieces.compactMap { other -> [SheetCell]? in
            guard other.id != excludedID, let otherPlacement = placements[other.id] else { return nil }
            return cells(for: other, placement: otherPlacement)
        }.flatMap { $0 })
        return proposed.allSatisfy { !occupied.contains($0) }
    }

    private func cells(for piece: SheetPiece, placement: SheetPlacement) -> [SheetCell] {
        let dimensions = piece.dimensions(rotated: placement.rotated)
        return (0..<dimensions.height).flatMap { row in
            (0..<dimensions.width).map { column in
                SheetCell(column: placement.column + column, row: placement.row + row)
            }
        }
    }

    private func occupiedCells() -> Set<SheetCell> {
        Set(stage.pieces.compactMap { piece -> [SheetCell]? in
            guard let placement = placements[piece.id] else { return nil }
            return cells(for: piece, placement: placement)
        }.flatMap { $0 })
    }

    private func checkForRectangle() {
        guard placements.count == stage.pieces.count else { return }
        let occupied = occupiedCells()
        guard occupied.count == stage.totalArea,
              let minColumn = occupied.map(\.column).min(), let maxColumn = occupied.map(\.column).max(),
              let minRow = occupied.map(\.row).min(), let maxRow = occupied.map(\.row).max() else { return }
        let bounds = SheetBounds(minColumn: minColumn, maxColumn: maxColumn, minRow: minRow, maxRow: maxRow)
        guard bounds.width * bounds.height == occupied.count,
              Set([bounds.width, bounds.height]) == Set(stage.requiredDimensions) else { return }

        stageSolved = true
        solvedBounds = bounds
        let token = stageToken
        withAnimation(.easeOut(duration: 0.18)) { matchFlash = true }

        for (index, piece) in stage.pieces.sorted(by: { $0.id < $1.id }).enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38 + Double(index) * 0.075) {
                guard stageToken == token else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                    _ = clearingPieceIDs.insert(piece.id)
                }
            }
        }

        let clearDuration = 0.68 + Double(stage.pieces.count) * 0.075
        DispatchQueue.main.asyncAfter(deadline: .now() + clearDuration) {
            guard stageToken == token else { return }
            withAnimation(.easeOut(duration: 0.22)) { matchFlash = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + clearDuration + 0.35) {
            guard stageToken == token else { return }
            advanceStage()
        }
    }

    private func advanceStage() {
        if stageIndex == stages.count - 1 {
            completed = true
        } else {
            stageIndex += 1
            placements = [:]
            selectedKind = .square
            selectedRotated = false
            solvedBounds = nil
            stageSolved = false
            clearingPieceIDs = []
            matchFlash = false
            stageToken = UUID()
        }
    }

    private func flashInvalid() {
        withAnimation(.easeOut(duration: 0.12)) { invalidFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.2)) { invalidFlash = false }
        }
    }

    private func clearBed() {
        stageToken = UUID()
        placements = [:]
        dragOffsets = [:]
        solvedBounds = nil
        stageSolved = false
        clearingPieceIDs = []
        matchFlash = false
    }

    private func resetLevel() {
        completed = false
        stageIndex = 0
        selectedKind = .square
        selectedRotated = false
        clearBed()
    }
}

private enum SheetPieceKind: CaseIterable, Hashable {
    case square, strip, unit

    var label: String {
        switch self { case .square: "x²"; case .strip: "x"; case .unit: "1" }
    }
    var icon: String {
        switch self { case .square: "square.fill"; case .strip: "rectangle.fill"; case .unit: "smallcircle.filled.circle" }
    }
    var color: Color {
        switch self {
        case .square: Color(red: 0.18, green: 0.68, blue: 0.72)
        case .strip: Color(red: 0.95, green: 0.60, blue: 0.16)
        case .unit: Color(red: 0.86, green: 0.87, blue: 0.82)
        }
    }
}

private struct SheetPiece: Identifiable {
    let id: Int
    let kind: SheetPieceKind

    func dimensions(rotated: Bool) -> (width: Int, height: Int) {
        switch kind {
        case .square: (3, 3)
        case .strip: rotated ? (1, 3) : (3, 1)
        case .unit: (1, 1)
        }
    }
}

private struct SheetPlacement {
    let column: Int
    let row: Int
    let rotated: Bool
}

private struct SheetCell: Hashable {
    let column: Int
    let row: Int
}

private struct SheetBounds {
    let minColumn: Int
    let maxColumn: Int
    let minRow: Int
    let maxRow: Int
    var width: Int { maxColumn - minColumn + 1 }
    var height: Int { maxRow - minRow + 1 }
}

private struct SheetMetalStage {
    let formula: String
    let factored: String
    let factorTop: String
    let factorSide: String
    let factorTopUnits: Int
    let pieces: [SheetPiece]
    let requiredDimensions: [Int]
    var totalArea: Int { pieces.reduce(0) { $0 + $1.dimensions(rotated: false).width * $1.dimensions(rotated: false).height } }

    static let all: [SheetMetalStage] = [
        .init(
            formula: "x² + 5x + 6",
            factored: "(x + 2)(x + 3)",
            factorTop: "x + 3",
            factorSide: "x + 2",
            factorTopUnits: 6,
            pieces: makePieces(squares: 1, strips: 5, units: 6),
            requiredDimensions: [5, 6]
        ),
        .init(
            formula: "x² + 7x + 10",
            factored: "(x + 2)(x + 5)",
            factorTop: "x + 5",
            factorSide: "x + 2",
            factorTopUnits: 8,
            pieces: makePieces(squares: 1, strips: 7, units: 10),
            requiredDimensions: [5, 8]
        ),
        .init(
            formula: "2x² + 7x + 3",
            factored: "(2x + 1)(x + 3)",
            factorTop: "2x + 1",
            factorSide: "x + 3",
            factorTopUnits: 7,
            pieces: makePieces(squares: 2, strips: 7, units: 3),
            requiredDimensions: [6, 7]
        )
    ]

    private static func makePieces(squares: Int, strips: Int, units: Int) -> [SheetPiece] {
        var result: [SheetPiece] = []
        for _ in 0..<squares { result.append(SheetPiece(id: result.count, kind: .square)) }
        for _ in 0..<strips { result.append(SheetPiece(id: result.count, kind: .strip)) }
        for _ in 0..<units { result.append(SheetPiece(id: result.count, kind: .unit)) }
        return result
    }
}

#Preview {
    MathItLevelOneHundredFifteenView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 115) ?? 115)
}
