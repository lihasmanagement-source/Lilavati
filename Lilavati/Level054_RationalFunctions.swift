import SwiftUI

struct MathItLevelOneHundredSeventeenView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var viewModel = RationalFactoryViewModel()

    var body: some View {
        RationalFactoryView(
            viewModel: viewModel,
            onContinue: onContinue,
            onReplay: resetFactory,
            onLevelSelect: onLevelSelect
        )
    }

    private func resetFactory() {
        viewModel.stop()
        viewModel = RationalFactoryViewModel()
    }
}

#Preview {
    MathItLevelOneHundredSeventeenView(onContinue: {}, onLevelSelect: {})
        .environment(\.mathItLevelNumber, MathItCurriculum.levelNumber(forScreenLevel: 117) ?? 117)
}
