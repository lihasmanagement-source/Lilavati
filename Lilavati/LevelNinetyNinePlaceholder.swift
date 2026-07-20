import SwiftUI

struct MathItLevelNinetyNineView: View {
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HomeButton(action: onLevelSelect)
                .position(x: 34, y: 54)
        }
    }
}

#Preview {
    MathItLevelNinetyNineView(onContinue: {}, onLevelSelect: {})
}
