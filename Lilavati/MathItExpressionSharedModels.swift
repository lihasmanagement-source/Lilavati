import SwiftUI

struct MathItOneSymbol: Identifiable, Equatable {
    let id: UUID
    var position: CGPoint

    init(id: UUID = UUID(), position: CGPoint) {
        self.id = id
        self.position = position
    }
}

struct MathItNumberSymbol: Identifiable, Equatable {
    let id: UUID
    var value: Int
    var position: CGPoint

    init(id: UUID = UUID(), value: Int, position: CGPoint) {
        self.id = id
        self.value = value
        self.position = position
    }
}

enum MathItLevelSevenOperatorSymbol: Hashable {
    case plus
    case multiply
    case equals

    var placedSymbol: MathItLevelSevenPlacedSymbol {
        switch self {
        case .plus:
            .plus
        case .multiply:
            .multiply
        case .equals:
            .equals
        }
    }
}

enum MathItLevelSevenPlacedSymbol: Hashable {
    case one(UUID)
    case number(UUID)
    case plus
    case multiply
    case equals
}

struct MathItLevelSevenSnapNode: Identifiable, Equatable {
    let symbol: MathItLevelSevenPlacedSymbol
    var position: CGPoint

    var id: MathItLevelSevenPlacedSymbol { symbol }
}

enum MathItLevelSevenTokenKind: Equatable {
    case one
    case number(Int)
    case plus
    case multiply
    case equals
}

struct MathItLevelSevenToken: Equatable {
    let kind: MathItLevelSevenTokenKind
    let position: CGPoint
}

struct MathItLevelSevenExpressionState {
    let tokens: [MathItLevelSevenToken]

    var result: Int? {
        let orderedKinds = tokens.sorted { $0.position.x < $1.position.x }.map(\.kind)
        let expressionKinds = orderedKinds.filter { $0 != .equals }
        return evaluate(expressionKinds)
    }

    private func evaluate(_ kinds: [MathItLevelSevenTokenKind]) -> Int? {
        var values: [Int] = []
        var operators: [MathItLevelSevenTokenKind] = []

        for kind in kinds {
            switch kind {
            case .one:
                values.append(1)
            case .number(let value):
                values.append(value)
            case .plus, .multiply:
                operators.append(kind)
            case .equals:
                break
            }
        }

        guard !values.isEmpty, operators.count == max(values.count - 1, 0) else { return nil }

        var collapsedValues = [values[0]]
        var collapsedOperators: [MathItLevelSevenTokenKind] = []

        for index in operators.indices {
            let nextValue = values[index + 1]
            if operators[index] == .multiply {
                collapsedValues[collapsedValues.count - 1] *= nextValue
            } else {
                collapsedOperators.append(.plus)
                collapsedValues.append(nextValue)
            }
        }

        return collapsedValues.reduce(0, +)
    }
}
