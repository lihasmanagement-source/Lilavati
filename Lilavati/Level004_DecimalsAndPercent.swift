import SwiftUI

struct LevelFortyFiveItem: Identifiable {
    let id: Int
    let icon: String
    let priceCents: Int
}

struct LevelFortyFiveStage {
    let items: [LevelFortyFiveItem]

    var totalCents: Int {
        items.map(\.priceCents).reduce(0, +)
    }
}

struct LevelFortyFiveMoneyPiece: Identifiable, Equatable {
    let id = UUID()
    let cents: Int
}

@Observable
final class MathItLevelFortyFiveViewModel {
    let stages = [
        LevelFortyFiveStage(items: [
            LevelFortyFiveItem(id: 0, icon: "book", priceCents: 1011),
            LevelFortyFiveItem(id: 1, icon: "pencil.and.ruler", priceCents: 327),
            LevelFortyFiveItem(id: 2, icon: "eraser", priceCents: 146)
        ]),
        LevelFortyFiveStage(items: [
            LevelFortyFiveItem(id: 0, icon: "headphones", priceCents: 1208),
            LevelFortyFiveItem(id: 1, icon: "music.note", priceCents: 234),
            LevelFortyFiveItem(id: 2, icon: "cable.connector", priceCents: 175)
        ]),
        LevelFortyFiveStage(items: [
            LevelFortyFiveItem(id: 0, icon: "gamecontroller", priceCents: 1116),
            LevelFortyFiveItem(id: 1, icon: "battery.100", priceCents: 455),
            LevelFortyFiveItem(id: 2, icon: "gift", priceCents: 219)
        ])
    ]

    var stage = 0
    var scannedCount = 0
    var beltOffset: CGFloat = -210
    var currentItemIndex = 0
    var walletVisible = false
    var wallet: [LevelFortyFiveMoneyPiece] = []
    var payment: [LevelFortyFiveMoneyPiece] = []
    var selectedWalletIDs: Set<UUID> = []
    var selectedPaymentIDs: Set<UUID> = []
    var failed = false
    var successPulse = false
    var completed = false

    private var hasStarted = false
    private var runID = UUID()

    var currentStage: LevelFortyFiveStage {
        stages[min(stage, stages.count - 1)]
    }

    var scannedTotalCents: Int {
        currentStage.items.prefix(scannedCount).map(\.priceCents).reduce(0, +)
    }

    var paymentCents: Int {
        payment.map(\.cents).reduce(0, +)
    }

    var scanningComplete: Bool {
        scannedCount == currentStage.items.count
    }

    var currentItem: LevelFortyFiveItem? {
        guard currentItemIndex < currentStage.items.count else { return nil }
        return currentStage.items[currentItemIndex]
    }

    var progress: Double {
        if completed { return 1 }
        let base = Double(stage) / Double(stages.count)
        let scanProgress = Double(scannedCount) / Double(currentStage.items.count) * 0.5
        let payProgress = min(0.45, Double(paymentCents) / Double(max(currentStage.totalCents, 1)) * 0.45)
        return base + (scanProgress + payProgress) / Double(stages.count)
    }

    init() {
        resetStage(startScanning: false)
    }

    func cancelScheduledActions() {
        runID = UUID()
        hasStarted = false
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        beginStage()
    }

    func beginStage() {
        resetStage(startScanning: true)
    }

    private func resetStage(startScanning: Bool) {
        hasStarted = startScanning
        runID = UUID()
        scannedCount = 0
        currentItemIndex = 0
        beltOffset = -210
        walletVisible = false
        wallet = [LevelFortyFiveMoneyPiece(cents: 2000)]
        payment.removeAll()
        selectedWalletIDs.removeAll()
        selectedPaymentIDs.removeAll()
        failed = false
        successPulse = false
        if startScanning {
            animateNextItem(id: runID)
        }
    }

    func selectWalletPiece(_ piece: LevelFortyFiveMoneyPiece) {
        guard walletVisible, !successPulse else { return }
        HapticPlayer.playLightTap()
        selectedPaymentIDs.removeAll()
        if selectedWalletIDs.contains(piece.id) {
            selectedWalletIDs.remove(piece.id)
        } else {
            selectedWalletIDs.insert(piece.id)
        }
    }

    func selectPaymentPiece(_ piece: LevelFortyFiveMoneyPiece) {
        guard !successPulse else { return }
        HapticPlayer.playLightTap()
        selectedWalletIDs.removeAll()
        if selectedPaymentIDs.contains(piece.id) {
            selectedPaymentIDs.remove(piece.id)
        } else {
            selectedPaymentIDs.insert(piece.id)
        }
    }

    func splitWalletPiece(_ piece: LevelFortyFiveMoneyPiece) {
        guard walletVisible, !successPulse,
              let index = wallet.firstIndex(where: { $0.id == piece.id }),
              let splitValues = splitValues(for: piece.cents) else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            wallet.remove(at: index)
            wallet.insert(contentsOf: splitValues.map(LevelFortyFiveMoneyPiece.init(cents:)), at: index)
            selectedWalletIDs.remove(piece.id)
            failed = false
        }
    }

    func moveSelectedToPayment() {
        guard !selectedWalletIDs.isEmpty else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            let selectedPieces = wallet.filter { selectedWalletIDs.contains($0.id) }
            wallet.removeAll { selectedWalletIDs.contains($0.id) }
            payment.append(contentsOf: selectedPieces)
            selectedWalletIDs.removeAll()
            failed = false
        }
    }

    func returnSelectedToWallet() {
        guard !selectedPaymentIDs.isEmpty else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            let selectedPieces = payment.filter { selectedPaymentIDs.contains($0.id) }
            payment.removeAll { selectedPaymentIDs.contains($0.id) }
            wallet.append(contentsOf: selectedPieces)
            selectedPaymentIDs.removeAll()
            failed = false
        }
    }

    func checkPayment() {
        guard walletVisible, !payment.isEmpty else { return }
        if paymentCents == currentStage.totalCents {
            succeed()
        } else {
            fail()
        }
    }

    private func splitValues(for cents: Int) -> [Int]? {
        switch cents {
        case 2000: [1000, 1000]
        case 1000: [500, 500]
        case 500: [100, 100, 100, 100, 100]
        case 100: [25, 25, 25, 25]
        case 25: [10, 10, 5]
        case 10: [5, 5]
        case 5: [1, 1, 1, 1, 1]
        default: nil
        }
    }

    private func animateNextItem(id: UUID) {
        guard id == runID, currentItemIndex < currentStage.items.count else {
            showWallet(id: id)
            return
        }

        beltOffset = -210
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard id == self.runID else { return }
            withAnimation(.easeInOut(duration: 0.78)) {
                self.beltOffset = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            guard id == self.runID else { return }
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                self.scannedCount += 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.12) {
            guard id == self.runID else { return }
            withAnimation(.easeInOut(duration: 0.42)) {
                self.beltOffset = 118
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            guard id == self.runID else { return }
            self.currentItemIndex += 1
            self.animateNextItem(id: id)
        }
    }

    private func showWallet(id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard id == self.runID else { return }
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                self.walletVisible = true
            }
        }
    }

    private func fail() {
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.16, dampingFraction: 0.42)) {
            failed = true
        }
        let id = runID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            guard id == self.runID else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                self.failed = false
            }
        }
    }

    private func succeed() {
        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            successPulse = true
        }

        let id = runID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard id == self.runID else { return }
            if self.stage == self.stages.count - 1 {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                    self.completed = true
                }
                return
            }

            self.stage += 1
            self.beginStage()
        }
    }
}

struct MathItLevelFortyFiveView: View {
    var viewModel: MathItLevelFortyFiveViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let orange = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 10) {
                    header(size: size)
                    checkoutScene
                        .frame(height: min(260, size.height * 0.33))
                    paymentWorkspace
                        .frame(maxHeight: .infinity)
                    controls
                }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 14)

                CompletionOverlay(
                    title: "45 ✓",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
        .onAppear {
            viewModel.startIfNeeded()
        }
        .onDisappear {
            viewModel.cancelScheduledActions()
        }
    }

    private func header(size: CGSize) -> some View {
        VStack(spacing: 8) {
            Text("45")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(Color.mathGold.opacity(0.85))

            EmptyView()
                .font(.trajan(34))
                .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.34))

            ProgressView(value: viewModel.progress)
                .tint(orange)
                .frame(width: max(180, size.width - 68))
                .opacity(0.76)
        }
    }

    private var checkoutScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(orange.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(orange.opacity(0.32), lineWidth: 1.1))

            conveyor
                .offset(y: 56)

            scanner
                .offset(x: -6, y: 12)

            cart
                .offset(x: 118, y: 38)

            movingItem
                .offset(x: viewModel.beltOffset - 98, y: 54)

            receipt
                .offset(x: -118, y: -52)
        }
    }

    private var conveyor: some View {
        Capsule()
            .fill(.white.opacity(0.08))
            .frame(height: 44)
            .overlay {
                HStack(spacing: 11) {
                    ForEach(0..<12, id: \.self) { index in
                        Capsule()
                            .fill(index.isMultiple(of: 2) ? orange.opacity(0.42) : .white.opacity(0.12))
                            .frame(width: 17, height: 4)
                    }
                }
            }
            .padding(.horizontal, 18)
    }

    private var scanner: some View {
        VStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(orange)
            money(viewModel.scannedTotalCents)
                .font(.system(size: 23, weight: .bold, design: .monospaced))
                .contentTransition(.numericText())
        }
        .frame(width: 112, height: 104)
        .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(orange.opacity(0.56), lineWidth: 1.2))
    }

    private var cart: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(orange)

            HStack(spacing: 5) {
                ForEach(viewModel.currentStage.items.prefix(viewModel.scannedCount)) { item in
                    Image(systemName: item.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 24, height: 24)
                        .background(orange, in: RoundedRectangle(cornerRadius: 5))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 88, height: 28)
        }
    }

    @ViewBuilder
    private var movingItem: some View {
        if let item = viewModel.currentItem {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.95))
                    .frame(width: 82, height: 66)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(orange.opacity(0.36), lineWidth: 1))
                    .overlay {
                        Image(systemName: item.icon)
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.white.opacity(0.82))
                    }

                money(item.priceCents)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
        }
    }

    private var receipt: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.currentStage.items.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    Image(systemName: index < viewModel.scannedCount ? "checkmark" : "circle")
                        .font(.system(size: 9, weight: .bold))
                    money(viewModel.currentStage.items[index].priceCents)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(index < viewModel.scannedCount ? orange : .white.opacity(0.28))
            }
        }
        .padding(10)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var paymentWorkspace: some View {
        VStack(spacing: 10) {
            if viewModel.scanningComplete {
                HStack {
                    Spacer(minLength: 0)
                    totalPanel(icon: "sum", cents: viewModel.currentStage.totalCents, alert: viewModel.failed)
                        .frame(width: 150)
                    Spacer(minLength: 0)
                }
                .transition(.scale.combined(with: .opacity))
            }

            HStack(spacing: 10) {
                moneyArea(
                    icon: "wallet.pass.fill",
                    pieces: viewModel.wallet,
                    selectedIDs: viewModel.selectedWalletIDs,
                    action: viewModel.selectWalletPiece,
                    doubleTapAction: viewModel.splitWalletPiece
                )
                moneyArea(
                    icon: "rectangle.grid.2x2.fill",
                    pieces: viewModel.payment,
                    selectedIDs: viewModel.selectedPaymentIDs,
                    action: viewModel.selectPaymentPiece,
                    doubleTapAction: nil
                )
            }
        }
        .opacity(viewModel.walletVisible ? 1 : 0.2)
        .allowsHitTesting(viewModel.walletVisible)
    }

    private func totalPanel(icon: String, cents: Int, alert: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(orange.opacity(0.7))
            money(cents)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(alert ? .red : .white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(alert ? .red.opacity(0.6) : orange.opacity(0.22), lineWidth: 1))
    }

    private func moneyArea(
        icon: String,
        pieces: [LevelFortyFiveMoneyPiece],
        selectedIDs: Set<UUID>,
        action: @escaping (LevelFortyFiveMoneyPiece) -> Void,
        doubleTapAction: ((LevelFortyFiveMoneyPiece) -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(orange.opacity(0.68))

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 6)], spacing: 6) {
                    ForEach(pieces) { piece in
                        Button {
                            action(piece)
                        } label: {
                            moneyPiece(piece.cents, selected: selectedIDs.contains(piece.id))
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    doubleTapAction?(piece)
                                }
                        )
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(orange.opacity(0.22), lineWidth: 1))
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: viewModel.moveSelectedToPayment) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(viewModel.selectedWalletIDs.isEmpty ? .white.opacity(0.24) : .black)
                    .frame(width: 56, height: 48)
                    .background(viewModel.selectedWalletIDs.isEmpty ? .white.opacity(0.04) : orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedWalletIDs.isEmpty)

            Button(action: viewModel.returnSelectedToWallet) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(viewModel.selectedPaymentIDs.isEmpty ? .white.opacity(0.24) : orange)
                    .frame(width: 56, height: 48)
                    .overlay(Capsule().stroke(orange.opacity(0.42), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedPaymentIDs.isEmpty)

            Button(action: viewModel.checkPayment) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(viewModel.payment.isEmpty ? .white.opacity(0.2) : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(viewModel.payment.isEmpty ? .white.opacity(0.04) : orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.payment.isEmpty)
        }
    }

    private func money(_ cents: Int) -> Text {
        let dollars = cents / 100
        let pennies = cents % 100
        return Text("$\(dollars).\(String(format: "%02d", pennies))")
    }

    @ViewBuilder
    private func moneyPiece(_ cents: Int, selected: Bool) -> some View {
        if cents >= 100 {
            RoundedRectangle(cornerRadius: 7)
                .fill(orange.opacity(cents == 2000 ? 0.72 : cents == 1000 ? 0.62 : cents == 500 ? 0.52 : 0.42))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? .white : orange.opacity(0.78), lineWidth: selected ? 2 : 1))
                .overlay {
                    Text("$\(cents / 100)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                }
                .frame(width: 62, height: 38)
                .shadow(color: selected ? orange.opacity(0.6) : .clear, radius: 8)
        } else {
            Circle()
                .fill(orange.opacity(cents == 25 ? 0.62 : cents == 10 ? 0.46 : cents == 5 ? 0.34 : 0.22))
                .overlay(Circle().stroke(selected ? .white : orange.opacity(0.82), lineWidth: selected ? 2 : 1))
                .overlay {
                    Text(cents == 25 ? "25" : cents == 10 ? "10" : cents == 5 ? "5" : "1")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                .shadow(color: selected ? orange.opacity(0.6) : .clear, radius: 8)
        }
    }
}
