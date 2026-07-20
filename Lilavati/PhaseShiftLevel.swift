import SwiftUI
import Combine
import AVFoundation

struct MathItPhaseShiftGame: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    @State private var stageIndex = 0
    @State private var phaseStep = 2
    @State private var completed = false
    @State private var wrongPulse = false

    private let targets = [0, 4, 9]
    private var targetStep: Int { targets[stageIndex] }
    private var match: Bool { phaseStep == targetStep }
    private var progress: Double {
        let distance = min(abs(phaseStep - targetStep), 12 - abs(phaseStep - targetStep))
        return (Double(stageIndex) + max(0, 1 - Double(distance) / 6.0)) / Double(targets.count)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)

                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        EmptyView()
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Color.mathGold.opacity(0.85))

                        EmptyView()
                            .font(.trajan(36))
                            .foregroundStyle(Color.mathGold.opacity(completed ? 1 : 0.46))
                    }
                    .padding(.horizontal, 58)

                    ProgressView(value: progress)
                        .tint(accent)
                        .opacity(0.72)
                        .padding(.horizontal, 34)

                    phaseField
                        .frame(height: min(390, proxy.size.height * 0.5))
                        .padding(.horizontal, 20)
                        .scaleEffect(wrongPulse ? 0.985 : 1)

                    HStack(spacing: 14) {
                        phaseButton("arrow.left", action: { adjust(-1) })
                        phaseBadge
                        phaseButton("arrow.right", action: { adjust(1) })
                        Button(action: checkStage) {
                            Image(systemName: match ? "checkmark.seal.fill" : "scope")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 50, height: 46)
                                .background(accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                        Button(action: reset) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 50, height: 46)
                                .background(accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 38)
                .padding(.bottom, 78)

                CompletionOverlay(
                    title: "Level \(concept.number) Completed",
                    isVisible: completed,
                    onContinue: onContinue,
                    onReplay: reset,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(20)
            }
        }
    }

    private var phaseField: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.08), Color(red: 0.01, green: 0.025, blue: 0.05), .black.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.36), lineWidth: 1.2))

                Canvas { canvas, size in
                    drawWave(canvas: &canvas, size: size, phase: Double(targetStep) / 12.0, color: .white.opacity(0.2), dashed: true)
                    drawWave(canvas: &canvas, size: size, phase: Double(phaseStep) / 12.0, color: accent.opacity(match ? 0.96 : 0.68), dashed: false)
                }

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 2)
                    ForEach(0..<12, id: \.self) { index in
                        Circle()
                            .fill(index == phaseStep ? accent : .white.opacity(0.12))
                            .frame(width: index == phaseStep ? 14 : 8, height: index == phaseStep ? 14 : 8)
                            .offset(y: -56)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                    Image(systemName: match ? "checkmark" : "waveform.path.ecg")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(match ? .black : accent)
                        .frame(width: 54, height: 54)
                        .background(match ? accent : .black.opacity(0.74), in: Circle())
                }
                .frame(width: 128, height: 128)
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.68)
            }
        }
    }

    private var phaseBadge: some View {
        VStack(spacing: 2) {
            Text("\(phaseStep)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(match ? .black : accent)
            Image(systemName: "circle.dotted")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(match ? .black.opacity(0.58) : .white.opacity(0.56))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(match ? accent : .black.opacity(0.84), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.44), lineWidth: 1.1))
    }

    private func phaseButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 50, height: 46)
                .background(accent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(completed)
    }

    private func drawWave(canvas: inout GraphicsContext, size: CGSize, phase: Double, color: Color, dashed: Bool) {
        var path = Path()
        let width = size.width * 0.84
        let startX = size.width * 0.08
        let midY = size.height * 0.33
        for step in 0...110 {
            let x = startX + width * CGFloat(step) / 110.0
            let angle = Double(step) / 110.0 * .pi * 4 + phase * .pi * 2
            let y = midY + CGFloat(sin(angle)) * size.height * 0.12
            if step == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        canvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: dashed ? 3 : 5, lineCap: .round, lineJoin: .round, dash: dashed ? [8, 8] : []))
    }

    private func adjust(_ amount: Int) {
        guard !completed else { return }
        phaseStep = (phaseStep + amount + 12) % 12
        HapticPlayer.playLightTap()
    }

    private func checkStage() {
        guard !completed else { return }
        if match {
            HapticPlayer.playCompletionTap()
            if stageIndex == targets.count - 1 {
                withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                    completed = true
                }
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    stageIndex += 1
                    phaseStep = (targets[stageIndex] + 3) % 12
                }
            }
        } else {
            HapticPlayer.playLightTap()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                wrongPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
                    wrongPulse = false
                }
            }
        }
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            stageIndex = 0
            phaseStep = 2
            completed = false
            wrongPulse = false
        }
    }
}
