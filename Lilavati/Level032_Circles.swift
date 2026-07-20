import SwiftUI
import Foundation

// MARK: - Circle (center → radius → diameter → C ÷ d = π)
//
// Phase 0: tap the glowing center to create one radius, then its opposite radius.
// Phase 1: the circle begins with a horizontal diameter whose two ends are yellow
//          dots. Drag either dot to sweep the diameter; both ends paint the
//          circumference. The sweep is locked to a single 180° turn — once the
//          circle is complete the diameter stops.
// Phase 2: the circle and diameter you just made become the draggable pieces of
//          the equation (circle) ÷ (diameter) = ?. Drop each onto its matching
//          outline and π appears. No new objects — the originals are reused.

@Observable
final class MathItLevelFiveViewModel {
    enum Phase { case constructing, painting, placing }
    var phase: Phase = .constructing
    var constructionStep = 0

    // Phase 1 — track the covered angular span so the diameter can rotate either way.
    var currentSweep: Double = 0          // signed diameter angle from the start (deg)
    var minSweep: Double = 0
    var maxSweep: Double = 0
    private var lastAngle: Double?
    private var lastHapticStep = 0
    var span: Double { maxSweep - minSweep }   // painted arc; full circle at 180

    // Phase 2
    var draggingCircle = false
    var draggingDiameter = false
    var circleDragPos: CGPoint = .zero
    var diameterDragPos: CGPoint = .zero
    var circlePlaced = false
    var diameterPlaced = false
    var showPi = false
    var completed = false

    func extendFromCenter() {
        guard phase == .constructing, constructionStep < 2 else { return }
        HapticPlayer.playLightTap()
        withAnimation(.spring(response: 0.48, dampingFraction: 0.74)) {
            constructionStep += 1
        }

        if constructionStep == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                guard self.phase == .constructing, self.constructionStep == 2 else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                    self.phase = .painting
                }
            }
        }
    }

    func rotateDiameter(to location: CGPoint, center: CGPoint, opposite: Bool = false) {
        guard phase == .painting else { return }
        let raw = Double(atan2(location.y - center.y, location.x - center.x))
        // Reduce the grabbed end to end-A's frame so both dots drive the same sweep.
        let a = opposite ? raw - .pi : raw
        if let last = lastAngle {
            var d = a - last
            if d > .pi { d -= 2 * .pi }
            if d < -.pi { d += 2 * .pi }
            // Rotate either direction; the painted span grows whichever way you go.
            currentSweep += d * 180 / .pi
            minSweep = min(minSweep, currentSweep)
            maxSweep = max(maxSweep, currentSweep)
            hapticIfNeeded()
            if span >= 180 { finishPainting() }
        }
        lastAngle = a
    }

    func releaseKnob() { lastAngle = nil }

    private func finishPainting() {
        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            minSweep = 0; maxSweep = 180; currentSweep = 180   // settle to a clean full circle
            phase = .placing
        }
    }

    private func hapticIfNeeded() {
        let step = Int(span / 30)
        if step > lastHapticStep { lastHapticStep = step; HapticPlayer.playLightTap() }
    }

    // MARK: Phase 2

    func dragCircle(to p: CGPoint) {
        guard phase == .placing, !circlePlaced else { return }
        draggingCircle = true; circleDragPos = p
    }

    func dropCircle(slot: CGPoint, threshold: CGFloat) {
        guard draggingCircle else { return }
        let hit = hypot(circleDragPos.x - slot.x, circleDragPos.y - slot.y) <= threshold
        // Settle in one animation — never flash back to the home position first.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            draggingCircle = false
            if hit { circlePlaced = true }
        }
        if hit { HapticPlayer.playLightTap(); checkEquation() }
    }

    func dragDiameter(to p: CGPoint) {
        guard phase == .placing, !diameterPlaced else { return }
        draggingDiameter = true; diameterDragPos = p
    }

    func dropDiameter(slot: CGPoint, threshold: CGFloat) {
        guard draggingDiameter else { return }
        let hit = hypot(diameterDragPos.x - slot.x, diameterDragPos.y - slot.y) <= threshold
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            draggingDiameter = false
            if hit { diameterPlaced = true }
        }
        if hit { HapticPlayer.playLightTap(); checkEquation() }
    }

    private func checkEquation() {
        guard circlePlaced, diameterPlaced, !completed else { return }
        HapticPlayer.playCompletionTap()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { showPi = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { self.completed = true }
        }
    }
}

struct MathItLevelFiveView: View {
    var viewModel: MathItLevelFiveViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private let accent = Color.mathGold
    private let dotColor = Color(red: 1.0, green: 0.86, blue: 0.2)
    private let R: CGFloat = 50          // shared radius — circle, slot, and token all match
    private let barH: CGFloat = 10
    private let opW: CGFloat = 24
    private let resW: CGFloat = 48

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let W = size.width, H = size.height
            let paintCenter = CGPoint(x: W / 2, y: H * 0.27)

            // Equation row (centered, gap-spaced, no overlaps).
            let gap: CGFloat = 10
            let total = 2 * R + opW + 2 * R + opW + resW + gap * 4
            let startX = (W - total) / 2
            let eqY = H * 0.5    // equation centered vertically
            let cxCircle = startX + R
            let cxDiv = cxCircle + R + gap + opW / 2
            let cxDia = cxDiv + opW / 2 + gap + R
            let cxEq = cxDia + R + gap + opW / 2
            let cxRes = cxEq + opW / 2 + gap + resW / 2
            let circleSlot = CGPoint(x: cxCircle, y: eqY)
            let diaSlot = CGPoint(x: cxDia, y: eqY)
            let resSlot = CGPoint(x: cxRes, y: eqY)

            let diamHome = paintCenter   // diameter stays inside the circle
            let circlePos = viewModel.circlePlaced ? circleSlot
                : (viewModel.draggingCircle ? viewModel.circleDragPos : paintCenter)
            let diamPos = viewModel.diameterPlaced ? diaSlot
                : (viewModel.draggingDiameter ? viewModel.diameterDragPos : diamHome)

            ZStack {
                Color.black.ignoresSafeArea()
                HomeButton(action: onLevelSelect).position(x: 34, y: 54)

                EmptyView()
                    .font(.trajan(38))
                    .foregroundStyle(accent.opacity(viewModel.completed ? 1 : 0.5))
                    .position(x: W / 2, y: 86)

                // ── Phase 0 ──
                constructionView(center: paintCenter)
                    .opacity(viewModel.phase == .constructing ? 1 : 0)
                    .allowsHitTesting(viewModel.phase == .constructing)

                // ── Phase 1 ──
                paintingView(center: paintCenter)
                    .opacity(viewModel.phase == .painting ? 1 : 0)
                    .allowsHitTesting(viewModel.phase == .painting)

                // ── Phase 2 ──
                Group {
                    Circle()
                        .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .frame(width: 2 * R, height: 2 * R)
                        .position(circleSlot)
                        .opacity(viewModel.circlePlaced ? 0 : 1)

                    Text("÷").font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(.white.opacity(0.85)).position(x: cxDiv, y: eqY)

                    Capsule()
                        .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .frame(width: 2 * R, height: barH)
                        .position(diaSlot)
                        .opacity(viewModel.diameterPlaced ? 0 : 1)

                    Text("=").font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(.white.opacity(0.85)).position(x: cxEq, y: eqY)

                    if viewModel.showPi {
                        Text("π")
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundStyle(accent)
                            .shadow(color: accent.opacity(0.6), radius: 14)
                            .position(resSlot)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                            .frame(width: resW, height: 56)
                            .position(resSlot)
                    }

                    // The circle you painted — now draggable, starting exactly where it was made.
                    circleObject()
                        .position(circlePos)
                        .gesture(
                            DragGesture(coordinateSpace: .named("lvl5"))
                                .onChanged { v in viewModel.dragCircle(to: v.location) }
                                .onEnded { _ in viewModel.dropCircle(slot: circleSlot, threshold: R + 18) }
                        )
                        .allowsHitTesting(!viewModel.circlePlaced)

                    // The diameter you made — now draggable.
                    diameterObject()
                        .position(diamPos)
                        .gesture(
                            DragGesture(coordinateSpace: .named("lvl5"))
                                .onChanged { v in viewModel.dragDiameter(to: v.location) }
                                .onEnded { _ in viewModel.dropDiameter(slot: diaSlot, threshold: R + 18) }
                        )
                        .allowsHitTesting(!viewModel.diameterPlaced)
                }
                .opacity(viewModel.phase == .placing ? 1 : 0)
                .allowsHitTesting(viewModel.phase == .placing)

                if let concept = ConceptLibrary.concept(for: 5) {
                    ConceptCompletionOverlay(
                        levelTitle: "Circle",
                        concept: concept,
                        isVisible: viewModel.completed,
                        onContinue: onContinue,
                        onReplay: onReplay,
                        onLevelSelect: onLevelSelect
                    )
                    .zIndex(30)
                }
            }
            .coordinateSpace(name: "lvl5")
        }
    }

    private func constructionView(center: CGPoint) -> some View {
        let right = CGPoint(x: center.x + R, y: center.y)
        let left = CGPoint(x: center.x - R, y: center.y)

        return ZStack {
            Path { path in
                path.move(to: center)
                path.addLine(to: right)
            }
            .trim(from: 0, to: viewModel.constructionStep >= 1 ? 1 : 0)
            .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .shadow(color: accent.opacity(0.55), radius: 8)

            Path { path in
                path.move(to: center)
                path.addLine(to: left)
            }
            .trim(from: 0, to: viewModel.constructionStep >= 2 ? 1 : 0)
            .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .shadow(color: accent.opacity(0.55), radius: 8)

            if viewModel.constructionStep >= 1 {
                Circle()
                    .fill(dotColor)
                    .frame(width: 16, height: 16)
                    .shadow(color: dotColor.opacity(0.7), radius: 8)
                    .position(right)
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.constructionStep >= 2 {
                Circle()
                    .fill(dotColor)
                    .frame(width: 16, height: 16)
                    .shadow(color: dotColor.opacity(0.7), radius: 8)
                    .position(left)
                    .transition(.scale.combined(with: .opacity))
            }

            Button(action: viewModel.extendFromCenter) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let pulse = (sin(timeline.date.timeIntervalSinceReferenceDate * 3.2) + 1) / 2

                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12 + pulse * 0.12))
                            .frame(width: 48, height: 48)
                            .scaleEffect(0.92 + pulse * 0.16)

                        Circle()
                            .fill(accent)
                            .frame(width: 18, height: 18)
                            .shadow(color: accent.opacity(0.65 + pulse * 0.25), radius: 10 + pulse * 7)
                    }
                }
                .frame(width: 58, height: 58)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .position(center)
            .disabled(viewModel.constructionStep >= 2)
            .accessibilityLabel(
                viewModel.constructionStep == 0
                    ? "Create a radius"
                    : "Extend the radius into a diameter"
            )
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.74), value: viewModel.constructionStep)
    }

    private func paintingView(center: CGPoint) -> some View {
        let span = viewModel.span
        let minS = viewModel.minSweep
        let a = viewModel.currentSweep * .pi / 180     // diameter follows the finger both ways
        let endA = CGPoint(x: center.x + CGFloat(cos(a)) * R, y: center.y + CGFloat(sin(a)) * R)
        let endB = CGPoint(x: center.x - CGFloat(cos(a)) * R, y: center.y - CGFloat(sin(a)) * R)

        return ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 1.5)
                .frame(width: 2 * R, height: 2 * R).position(center)

            rotationArrows(center: center)   // hint: rotate either way

            // Painted arc spans [minSweep, maxSweep] from each endpoint.
            Circle()
                .trim(from: 0, to: span / 360)
                .stroke(accent.opacity(0.95), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 2 * R, height: 2 * R).rotationEffect(.degrees(minS)).position(center)
                .shadow(color: accent.opacity(0.4), radius: 8)
            Circle()
                .trim(from: 0, to: span / 360)
                .stroke(accent.opacity(0.95), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 2 * R, height: 2 * R).rotationEffect(.degrees(minS + 180)).position(center)
                .shadow(color: accent.opacity(0.4), radius: 8)

            Path { p in p.move(to: endA); p.addLine(to: endB) }
                .stroke(.white.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            endDot(at: endA, center: center, opposite: false)
            endDot(at: endB, center: center, opposite: true)
        }
    }

    private func endDot(at p: CGPoint, center: CGPoint, opposite: Bool) -> some View {
        Circle()
            .fill(dotColor)
            .frame(width: 22, height: 22)
            .shadow(color: dotColor.opacity(0.7), radius: 9)
            .position(p)
            .gesture(
                DragGesture(coordinateSpace: .named("lvl5"))
                    .onChanged { v in viewModel.rotateDiameter(to: v.location, center: center, opposite: opposite) }
                    .onEnded { _ in viewModel.releaseKnob() }
            )
            .accessibilityLabel("Diameter endpoint")
    }

    // One curved gray arrow over the top (pointing left) and one under the bottom
    // (pointing right) — framing the circle to show it rotates.
    private func rotationArrows(center: CGPoint) -> some View {
        let path = Path { p in
            // Top arrow — curves over the top, arrowhead on the left.
            let tR = CGPoint(x: center.x + R * 0.95, y: center.y - R * 1.05)
            let tC = CGPoint(x: center.x, y: center.y - R * 1.5)
            let tL = CGPoint(x: center.x - R * 0.9, y: center.y - R * 1.1)
            p.move(to: tR); p.addQuadCurve(to: tL, control: tC)
            arrowHead(&p, at: tL, dir: CGVector(dx: tL.x - tC.x, dy: tL.y - tC.y), size: 9)

            // Bottom arrow — curves under the bottom, arrowhead on the right.
            let bL = CGPoint(x: center.x - R * 0.95, y: center.y + R * 1.05)
            let bC = CGPoint(x: center.x, y: center.y + R * 1.5)
            let bR = CGPoint(x: center.x + R * 0.9, y: center.y + R * 1.1)
            p.move(to: bL); p.addQuadCurve(to: bR, control: bC)
            arrowHead(&p, at: bR, dir: CGVector(dx: bR.x - bC.x, dy: bR.y - bC.y), size: 9)
        }
        return path.stroke(.gray.opacity(0.6), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
    }

    private func arrowHead(_ path: inout Path, at tip: CGPoint, dir: CGVector, size: CGFloat) {
        let len = max(hypot(dir.dx, dir.dy), 0.0001)
        let u = CGVector(dx: dir.dx / len, dy: dir.dy / len)
        let perp = CGVector(dx: -u.dy, dy: u.dx)
        let back = CGPoint(x: tip.x - u.dx * size, y: tip.y - u.dy * size)
        let b1 = CGPoint(x: back.x + perp.dx * size * 0.7, y: back.y + perp.dy * size * 0.7)
        let b2 = CGPoint(x: back.x - perp.dx * size * 0.7, y: back.y - perp.dy * size * 0.7)
        path.move(to: b1); path.addLine(to: tip); path.addLine(to: b2)
    }

    private func circleObject() -> some View {
        Circle()
            .fill(accent.opacity(0.12))
            .overlay(Circle().stroke(accent, lineWidth: 4))
            .frame(width: 2 * R, height: 2 * R)
            .shadow(color: accent.opacity(0.5), radius: 10)
    }

    private func diameterObject() -> some View {
        ZStack {
            Capsule().fill(accent).frame(width: 2 * R, height: barH)
            HStack {
                Circle().fill(dotColor).frame(width: 16, height: 16)
                Spacer()
                Circle().fill(dotColor).frame(width: 16, height: 16)
            }
            .frame(width: 2 * R)
        }
        .frame(width: 2 * R, height: 20)
        .shadow(color: accent.opacity(0.5), radius: 8)
    }
}
