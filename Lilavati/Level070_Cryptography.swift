import SwiftUI

struct LevelThirtyOnePrime: Identifiable {
    let id = UUID()
    let value: Int
    var origin: CGPoint = .zero
    var position: CGPoint = .zero
    var socket: Int?
}

private struct CryptographyPrimeStage {
    let product: Int
    let factors: Set<Int>
    let primeBank: [Int]
    let message: String

    static let all = [
        CryptographyPrimeStage(product: 143, factors: [11, 13], primeBank: [2, 5, 7, 11, 13, 17, 19], message: "HELLO"),
        CryptographyPrimeStage(product: 437, factors: [19, 23], primeBank: [7, 11, 13, 17, 19, 23, 29], message: "SECURE"),
        CryptographyPrimeStage(product: 899, factors: [29, 31], primeBank: [13, 17, 19, 23, 29, 31, 37], message: "VERIFIED")
    ]
}

@Observable
final class MathItLevelThirtyOneViewModel {
    private let stages = CryptographyPrimeStage.all

    var stageIndex = 0
    var primes: [LevelThirtyOnePrime]
    var attemptedSend = false
    var gateOpen = false
    var showFactorization = false
    var messageProgress: CGFloat = 0
    var messageDelivered = false
    var completed = false
    var rejectedPrimeID: UUID?
    var didLayout = false
    private var layoutSize: CGSize = .zero
    private var animationToken = UUID()

    init() {
        primes = CryptographyPrimeStage.all[0].primeBank.map { LevelThirtyOnePrime(value: $0) }
    }

    private var stage: CryptographyPrimeStage { stages[stageIndex] }
    var stageCount: Int { stages.count }
    var product: Int { stage.product }
    var factors: [Int] { stage.factors.sorted() }
    var message: String { stage.message }

    private var blockedMessageProgress: CGFloat {
        guard layoutSize.width > 108 else { return 0.4 }
        let senderX: CGFloat = 54
        let receiverX = layoutSize.width - 54
        let gateEdgeX = layoutSize.width / 2 - 48
        return (gateEdgeX - senderX) / (receiverX - senderX)
    }

    var progress: Double {
        if completed { return 1 }
        let socketProgress = Double(primes.filter { $0.socket != nil }.count) / 2
        let stageProgress = max(socketProgress * 0.64, Double(messageProgress) * 0.96)
        return (Double(stageIndex) + stageProgress) / Double(stages.count)
    }

    func prepareLayout(size: CGSize) {
        guard !didLayout else { return }
        didLayout = true
        layoutSize = size
        let positions = [
            CGPoint(x: size.width * 0.13, y: size.height * 0.64),
            CGPoint(x: size.width * 0.32, y: size.height * 0.69),
            CGPoint(x: size.width * 0.52, y: size.height * 0.64),
            CGPoint(x: size.width * 0.74, y: size.height * 0.69),
            CGPoint(x: size.width * 0.2, y: size.height * 0.79),
            CGPoint(x: size.width * 0.5, y: size.height * 0.82),
            CGPoint(x: size.width * 0.8, y: size.height * 0.79)
        ]
        for index in primes.indices {
            primes[index].origin = positions[index]
            primes[index].position = positions[index]
        }
    }

    func attemptTransmission() {
        guard !gateOpen else { return }
        attemptedSend = true
        HapticPlayer.playLightTap()
        withAnimation(.easeOut(duration: 0.72)) {
            messageProgress = blockedMessageProgress
        }
    }

    func movePrime(id: UUID, to point: CGPoint) {
        guard !gateOpen, let index = primes.firstIndex(where: { $0.id == id }),
              primes[index].socket == nil else { return }
        primes[index].position = point
    }

    func finishPrime(id: UUID, sockets: [CGRect]) {
        guard !gateOpen, let index = primes.firstIndex(where: { $0.id == id }),
              primes[index].socket == nil else { return }

        let value = primes[index].value
        let availableSocket = sockets.indices.first { socketIndex in
            sockets[socketIndex].insetBy(dx: -28, dy: -28).contains(primes[index].position) &&
            !primes.contains(where: { $0.socket == socketIndex })
        }

        if let socket = availableSocket,
           stage.factors.contains(value),
           !primes.contains(where: { $0.value == value && $0.socket != nil }) {
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                primes[index].socket = socket
                primes[index].position = CGPoint(x: sockets[socket].midX, y: sockets[socket].midY)
            }
            if primes.filter({ $0.socket != nil }).count == 2 {
                unlock()
            }
        } else {
            rejectedPrimeID = id
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.46, dampingFraction: 0.64)) {
                primes[index].position = primes[index].origin
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                if self.rejectedPrimeID == id { self.rejectedPrimeID = nil }
            }
        }
    }

    private func unlock() {
        attemptedSend = true
        let token = animationToken

        withAnimation(.easeOut(duration: 0.42)) {
            messageProgress = blockedMessageProgress
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            guard token == self.animationToken else { return }
            withAnimation(.spring(response: 0.72, dampingFraction: 0.78)) {
                self.gateOpen = true
                self.showFactorization = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            guard token == self.animationToken else { return }
            withAnimation(.easeInOut(duration: 1.35)) {
                self.messageProgress = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
            guard token == self.animationToken else { return }
            HapticPlayer.playCompletionTap()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                self.messageDelivered = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.25) {
            guard token == self.animationToken else { return }
            if self.stageIndex == self.stages.count - 1 {
                withAnimation(.spring(response: 0.56, dampingFraction: 0.82)) {
                    self.completed = true
                }
            } else {
                self.advanceStage()
            }
        }
    }

    private func advanceStage() {
        animationToken = UUID()
        stageIndex += 1
        primes = stage.primeBank.map { LevelThirtyOnePrime(value: $0) }
        attemptedSend = false
        gateOpen = false
        showFactorization = false
        messageProgress = 0
        messageDelivered = false
        rejectedPrimeID = nil
        didLayout = false

        withAnimation(.easeInOut(duration: 0.36)) {
            prepareLayout(size: layoutSize)
        }
    }
}

struct MathItLevelThirtyOneView: View {
    var viewModel: MathItLevelThirtyOneViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let cyan = Color.mathItAlgebra
    private let green = Color.mathItAlgebra
    private let amber = Color.mathItAlgebra

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let channelY = size.height * 0.34
            let gateCenter = CGPoint(x: size.width / 2, y: channelY)
            let sender = CGPoint(x: 54, y: channelY)
            let receiver = CGPoint(x: size.width - 54, y: channelY)
            let sockets = socketFrames(size: size)

            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 9) {
                    HStack(spacing: 7) {
                        ForEach(0..<viewModel.stageCount, id: \.self) { index in
                            Capsule()
                                .fill(index < viewModel.stageIndex ? green : index == viewModel.stageIndex ? amber : .white.opacity(0.13))
                                .frame(width: index == viewModel.stageIndex ? 38 : 22, height: 5)
                        }
                    }

                    Text("RSA ENCRYPTION \(viewModel.stageIndex + 1) / \(viewModel.stageCount)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(viewModel.completed ? 1 : 0.56))
                }
                .position(x: size.width / 2, y: 78)

                ProgressView(value: viewModel.progress)
                    .tint(viewModel.gateOpen ? green : cyan)
                    .opacity(0.76)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: 138)

                transmissionChannel(sender: sender, receiver: receiver, gate: gateCenter)
                senderNode(at: sender)
                receiverNode(at: receiver)
                gateView(center: gateCenter)
                socketsView(frames: sockets)
                messageParticle(sender: sender, receiver: receiver)

                ForEach(viewModel.primes) { prime in
                    primeCrystal(prime)
                        .position(prime.position)
                        .zIndex(prime.socket == nil ? 5 : 3)
                }

                CompletionOverlay(
                    title: "Level 71 Completed",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
            .coordinateSpace(name: "levelThirtyOneStage")
            .onAppear {
                stageSize = size
                viewModel.prepareLayout(size: size)
            }
            .onChange(of: size) { _, newSize in
                stageSize = newSize
            }
        }
    }

    private func transmissionChannel(sender: CGPoint, receiver: CGPoint, gate: CGPoint) -> some View {
        TimelineView(.animation) { context in
            let pulse = (sin(context.date.timeIntervalSinceReferenceDate * 3.4) + 1) / 2
            ZStack {
                Path { path in
                    path.move(to: sender)
                    path.addLine(to: receiver)
                }
                .stroke(.white.opacity(0.13), style: StrokeStyle(lineWidth: 1.2, dash: [4, 7]))

                Path { path in
                    path.move(to: sender)
                    path.addLine(to: CGPoint(x: gate.x - 37, y: gate.y))
                }
                .stroke(cyan.opacity(0.3 + pulse * 0.35), lineWidth: 1.5)
                .shadow(color: cyan.opacity(0.55), radius: 7)

                if viewModel.gateOpen {
                    Path { path in
                        path.move(to: CGPoint(x: gate.x + 37, y: gate.y))
                        path.addLine(to: receiver)
                    }
                    .stroke(green.opacity(0.4 + pulse * 0.4), lineWidth: 1.5)
                    .shadow(color: green.opacity(0.5), radius: 7)
                }
            }
        }
    }

    private func senderNode(at point: CGPoint) -> some View {
        Button(action: viewModel.attemptTransmission) {
            ZStack {
                Circle()
                    .fill(cyan.opacity(0.12))
                    .frame(width: 68, height: 68)
                    .overlay { Circle().stroke(cyan.opacity(0.8), lineWidth: 1.5) }
                    .shadow(color: cyan.opacity(0.55), radius: 14)
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: cyan, radius: 8)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(point)
    }

    private func receiverNode(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(viewModel.messageDelivered ? 0.9 : 0.34), lineWidth: 2)
                .frame(width: 62, height: 62)
                .shadow(color: green.opacity(viewModel.messageDelivered ? 0.8 : 0), radius: 15)
            Circle()
                .stroke(.white.opacity(0.13), lineWidth: 1)
                .frame(width: 42, height: 42)
        }
        .position(point)
    }

    private func gateView(center: CGPoint) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(.black)
                .frame(width: 76, height: 130)
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(viewModel.gateOpen ? green.opacity(0.7) : amber.opacity(0.72), lineWidth: 1.5)
                }
                .shadow(color: (viewModel.gateOpen ? green : amber).opacity(0.4), radius: 12)

            Rectangle()
                .fill(.black)
                .overlay { Rectangle().stroke(amber.opacity(0.6), lineWidth: 1) }
                .frame(width: 32, height: 116)
                .offset(x: viewModel.gateOpen ? -45 : -17)

            Rectangle()
                .fill(.black)
                .overlay { Rectangle().stroke(amber.opacity(0.6), lineWidth: 1) }
                .frame(width: 32, height: 116)
                .offset(x: viewModel.gateOpen ? 45 : 17)

            if !viewModel.gateOpen {
                VStack(spacing: 8) {
                    Text("RSA MODULUS")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1.1)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("\(viewModel.product)")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(amber)
            }

            if viewModel.showFactorization {
                Text("\(viewModel.product) = \(viewModel.factors[0]) × \(viewModel.factors[1])")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(green)
                    .fixedSize(horizontal: true, vertical: true)
                    .offset(y: 86)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .position(center)
    }

    private func socketsView(frames: [CGRect]) -> some View {
        ForEach(frames.indices, id: \.self) { index in
            let occupied = viewModel.primes.contains(where: { $0.socket == index })
            Circle()
                .fill(.black)
                .frame(width: frames[index].width, height: frames[index].height)
                .overlay {
                    Circle()
                        .stroke(
                            occupied ? green : Color.mathGold.opacity(0.5),
                            style: StrokeStyle(lineWidth: occupied ? 2 : 1.3, dash: occupied ? [] : [4, 5])
                        )
                }
                .shadow(color: occupied ? green.opacity(0.65) : .clear, radius: 12)
                .position(x: frames[index].midX, y: frames[index].midY)
        }
    }

    private func messageParticle(sender: CGPoint, receiver: CGPoint) -> some View {
        let x = sender.x + (receiver.x - sender.x) * viewModel.messageProgress

        return ZStack {
            Capsule()
                .fill(viewModel.gateOpen ? .black : .white)
                .overlay {
                    Capsule()
                        .stroke(viewModel.gateOpen ? green : cyan, lineWidth: 1.2)
                }

            Text(viewModel.gateOpen ? viewModel.message : "••••••")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(viewModel.gateOpen ? green : .black)
                .lineLimit(1)
        }
        .frame(width: 68, height: 23)
        .shadow(color: viewModel.gateOpen ? green.opacity(0.8) : cyan.opacity(0.65), radius: 8)
        .scaleEffect(viewModel.messageDelivered ? 1.08 : 1)
        .position(x: x, y: sender.y)
        .animation(.easeInOut(duration: 0.2), value: viewModel.gateOpen)
        .allowsHitTesting(false)
        .zIndex(8)
    }

    private func primeCrystal(_ prime: LevelThirtyOnePrime) -> some View {
        let rejected = viewModel.rejectedPrimeID == prime.id
        let placed = prime.socket != nil

        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill((placed ? green : cyan).opacity(placed ? 0.18 : 0.1))
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(rejected ? amber : (placed ? green : cyan).opacity(0.8), lineWidth: 1.4)
                }
                .rotationEffect(.degrees(45))
                .shadow(color: (placed ? green : cyan).opacity(0.45), radius: placed ? 12 : 7)

            Text("\(prime.value)")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: 70, height: 70)
        .scaleEffect(rejected ? 0.86 : 1)
        .contentShape(Circle())
        .gesture(
            DragGesture(coordinateSpace: .named("levelThirtyOneStage"))
                .onChanged { value in viewModel.movePrime(id: prime.id, to: value.location) }
                .onEnded { _ in viewModel.finishPrime(id: prime.id, sockets: socketFrames(size: stageSize)) }
        )
    }

    @State private var stageSize: CGSize = .zero

    private func socketFrames(size: CGSize) -> [CGRect] {
        let y = size.height * 0.51
        return [
            CGRect(x: size.width / 2 - 76, y: y - 28, width: 56, height: 56),
            CGRect(x: size.width / 2 + 20, y: y - 28, width: 56, height: 56)
        ]
    }
}
