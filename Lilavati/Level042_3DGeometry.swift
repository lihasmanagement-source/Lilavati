import SwiftUI

// MARK: - Level 42 - 3D Geometry Origami (Fold the Crane)
//
// A guided crane tutorial matching the classic atdc 20-step diagram one step
// to one step: both squash folds, every turn-over, the crease-and-unfold, both
// petal folds, both narrowing passes, the neck/tail/head reverse folds and the
// wings. Every step draws its fold line as a red dashed guide and puts the two
// numbered markers exactly where the instructions say to grab. Front layers
// render lighter than back layers so the paper visibly has depth. Animation
// state resets only when the step changes, so a finished fold never snaps
// back. The math of each fold (45°, 22.5°, √2, 1+√2, layer counts) is called
// out as it appears.

@Observable
final class MathItLevelThirtyThreeViewModel {
    var stepIndex = 0
    var tappedCount = 0
    var folding = false
    var showMath = false
    var finale = false
    var completed = false

    var progress: Double {
        completed || finale ? 1 : Double(stepIndex) / 19
    }

    func reset() {
        stepIndex = 0
        tappedCount = 0
        folding = false
        showMath = false
        finale = false
        completed = false
    }

    /// Markers must be tapped in order (1, 2, 3, …). Returns true when the
    /// last marker of the step has been tapped and the fold should fire.
    func tapMarker(_ n: Int, total: Int) -> Bool {
        guard !folding, !showMath, !completed, !finale else { return false }
        guard n == tappedCount + 1 else { return false }   // enforce the sequence
        HapticPlayer.playLightTap()
        tappedCount += 1
        return tappedCount == total
    }

    func foldFinished() {
        folding = false
        showMath = true
        HapticPlayer.playCompletionTap()
    }

    func nextStep(total: Int) {
        guard showMath else { return }
        guard stepIndex < total - 1 else { return }
        HapticPlayer.playLightTap()
        tappedCount = 0
        showMath = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            stepIndex += 1
        }
    }

    func revealFinale() {
        guard !finale, !completed else { return }
        folding = false
        showMath = false
        tappedCount = 0
        HapticPlayer.playCompletionTap()
        withAnimation(.easeInOut(duration: 0.5)) {
            finale = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.spring(response: 0.54, dampingFraction: 0.84)) {
                self.completed = true
            }
        }
    }
}

struct MathItLevelThirtyThreeView: View {
    var viewModel: MathItLevelThirtyThreeViewModel

    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    @State private var foldAngle: Double = 0       // 3D flap / flip rotation
    @State private var swingAngle: Double = 0      // 2D spike swing
    @State private var dissolve: Double = 0        // flatten / morph blend

    private let mountainRed = Color(red: 0.95, green: 0.42, blue: 0.34)
    private let valleyBlue = Color(red: 0.36, green: 0.72, blue: 0.92)
    private let paperFront = Color(red: 0.88, green: 0.96, blue: 0.93)   // fibrous mint-white origami paper
    private let paperRear = Color(red: 0.52, green: 0.72, blue: 0.66)    // shaded back layers
    private let gold = Color.mathGold

    // MARK: Geometry helpers

    private static func rotate(_ pts: [CGPoint], about pivot: CGPoint, degrees: Double) -> [CGPoint] {
        let a = degrees * .pi / 180
        return pts.map { p in
            let dx = p.x - pivot.x, dy = p.y - pivot.y
            return CGPoint(x: pivot.x + dx * cos(a) - dy * sin(a),
                           y: pivot.y + dx * sin(a) + dy * cos(a))
        }
    }

    private static func mirror(_ pts: [CGPoint]) -> [CGPoint] {
        pts.map { CGPoint(x: 1 - $0.x, y: $0.y) }
    }

    // MARK: Layers & steps

    private struct Layer {
        let pts: [CGPoint]
        var front = false
    }

    private enum FoldAnim {
        case flap(crease: (CGPoint, CGPoint), stationary: [Layer], moving: [CGPoint]) // real single-crease fold
        case squash(crease: (CGPoint, CGPoint), moving: [CGPoint])        // lift edge-on, flatten open
        case turnOver                                                     // flip the whole paper
        case swing(pivot: CGPoint, degrees: Double, movingIndex: Int)     // reverse fold
        case dissolve                                                     // squash pieces / petal / narrow
        case crane                                                        // final morph
    }

    private struct TriangleCallout {
        let pts: [CGPoint]
        let angleLabels: [(String, CGPoint)]
        let sideLabels: [(String, CGPoint)]
    }

    private struct FoldStep {
        let title: String
        let instruction: String
        let layers: [Layer]                 // paper before the fold
        let afterLayers: [Layer]            // paper after
        let innerCreases: [(CGPoint, CGPoint)]
        let foldGuides: [[CGPoint]]
        let anim: FoldAnim
        let markers: [CGPoint]
        let mathTitle: String
        let mathLines: [String]
        let callout: TriangleCallout?
    }

    // MARK: Silhouette keyframes (unit space, y down) — one per diagram frame.

    private static let diamond: [CGPoint] = [CGPoint(x: 0.5, y: 0.04), CGPoint(x: 0.96, y: 0.5), CGPoint(x: 0.5, y: 0.96), CGPoint(x: 0.04, y: 0.5)]
    private static let tri1: [CGPoint] = [CGPoint(x: 0.04, y: 0.5), CGPoint(x: 0.96, y: 0.5), CGPoint(x: 0.5, y: 0.96)]
    private static let tri2: [CGPoint] = [CGPoint(x: 0.04, y: 0.5), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.96)]        // points left
    private static let tri2M: [CGPoint] = mirror(tri2)                                                                          // points right
    private static let step1Stationary: [CGPoint] = [CGPoint(x: 0.04, y: 0.5), CGPoint(x: 0.96, y: 0.5), CGPoint(x: 0.5, y: 0.96)]
    private static let step2Stationary: [CGPoint] = [CGPoint(x: 0.04, y: 0.5), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.96)]
    private static let lifted: [CGPoint] = [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.60, y: 0.66), CGPoint(x: 0.5, y: 0.94)]      // layer picked up
    private static let frontDiamond: [CGPoint] = [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.70, y: 0.72), CGPoint(x: 0.5, y: 0.94), CGPoint(x: 0.30, y: 0.72)]
    private static let squareBase: [CGPoint] = [CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.73, y: 0.62), CGPoint(x: 0.5, y: 0.96), CGPoint(x: 0.27, y: 0.62)]
    private static let kite: [CGPoint] = [CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.635, y: 0.70), CGPoint(x: 0.5, y: 0.96), CGPoint(x: 0.365, y: 0.70)]
    private static let kiteBody: [CGPoint] = [CGPoint(x: 0.436, y: 0.48), CGPoint(x: 0.564, y: 0.48), CGPoint(x: 0.635, y: 0.70), CGPoint(x: 0.5, y: 0.96), CGPoint(x: 0.365, y: 0.70)]
    private static let kiteTip: [CGPoint] = [CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.564, y: 0.48), CGPoint(x: 0.436, y: 0.48)]
    private static let kiteTipDown: [CGPoint] = [CGPoint(x: 0.436, y: 0.48), CGPoint(x: 0.564, y: 0.48), CGPoint(x: 0.5, y: 0.68)]
    private static let petalFront: [CGPoint] = [CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.60, y: 0.60), CGPoint(x: 0.5, y: 0.94), CGPoint(x: 0.40, y: 0.60)]
    private static let birdBase: [CGPoint] = petalFront
    private static let narrowFront: [CGPoint] = [CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.55, y: 0.55), CGPoint(x: 0.5, y: 0.80), CGPoint(x: 0.45, y: 0.55)]
    private static let narrowBody: [CGPoint] = [CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.565, y: 0.55), CGPoint(x: 0.5, y: 0.74), CGPoint(x: 0.435, y: 0.55)]
    private static let spikeL: [CGPoint] = [CGPoint(x: 0.435, y: 0.55), CGPoint(x: 0.5, y: 0.74), CGPoint(x: 0.335, y: 0.94)]
    private static let spikeR: [CGPoint] = [CGPoint(x: 0.565, y: 0.55), CGPoint(x: 0.5, y: 0.74), CGPoint(x: 0.665, y: 0.94)]
    // Verified: +125° sends the neck up-LEFT; −125° sends the tail up-RIGHT.
    private static let neckUp = rotate(spikeL, about: CGPoint(x: 0.435, y: 0.55), degrees: 125)
    private static let tailUp = rotate(spikeR, about: CGPoint(x: 0.565, y: 0.55), degrees: -125)
    // The neck split for the head fold (62% toward the tip).
    private static let headTip: [CGPoint] = [CGPoint(x: 0.272, y: 0.361), CGPoint(x: 0.199, y: 0.339), CGPoint(x: 0.173, y: 0.244)]
    private static let neckLower: [CGPoint] = [CGPoint(x: 0.435, y: 0.55), CGPoint(x: 0.242, y: 0.494), CGPoint(x: 0.199, y: 0.339), CGPoint(x: 0.272, y: 0.361)]
    private static let headPivot = CGPoint(x: 0.236, y: 0.35)

    private static let rt4545 = TriangleCallout(
        pts: [CGPoint(x: 0.08, y: 0.88), CGPoint(x: 0.92, y: 0.88), CGPoint(x: 0.92, y: 0.10)],
        angleLabels: [("45°", CGPoint(x: 0.28, y: 0.79)), ("90°", CGPoint(x: 0.80, y: 0.79)), ("45°", CGPoint(x: 0.81, y: 0.26))],
        sideLabels: [("1", CGPoint(x: 0.5, y: 0.99)), ("1", CGPoint(x: 1.04, y: 0.5)), ("√2", CGPoint(x: 0.40, y: 0.42))]
    )
    private static let rt4545Half = TriangleCallout(
        pts: [CGPoint(x: 0.08, y: 0.88), CGPoint(x: 0.92, y: 0.88), CGPoint(x: 0.92, y: 0.10)],
        angleLabels: [("45°", CGPoint(x: 0.28, y: 0.79)), ("90°", CGPoint(x: 0.80, y: 0.79)), ("45°", CGPoint(x: 0.81, y: 0.26))],
        sideLabels: [("√2⁄2", CGPoint(x: 0.5, y: 0.99)), ("√2⁄2", CGPoint(x: 1.08, y: 0.5)), ("1", CGPoint(x: 0.40, y: 0.42))]
    )
    private static let rt225 = TriangleCallout(
        pts: [CGPoint(x: 0.04, y: 0.80), CGPoint(x: 0.96, y: 0.80), CGPoint(x: 0.96, y: 0.42)],
        angleLabels: [("22.5°", CGPoint(x: 0.28, y: 0.71)), ("90°", CGPoint(x: 0.85, y: 0.71))],
        sideLabels: [("1", CGPoint(x: 0.5, y: 0.93)), ("√2−1", CGPoint(x: 1.13, y: 0.60))]
    )
    private static let rt225Long = TriangleCallout(
        pts: [CGPoint(x: 0.04, y: 0.80), CGPoint(x: 0.96, y: 0.80), CGPoint(x: 0.96, y: 0.42)],
        angleLabels: [("22.5°", CGPoint(x: 0.28, y: 0.71)), ("67.5°", CGPoint(x: 0.80, y: 0.50))],
        sideLabels: [("1+√2", CGPoint(x: 0.5, y: 0.93)), ("1", CGPoint(x: 1.05, y: 0.60))]
    )

    // MARK: The nineteen fold actions shown by the twenty reference panels.

    private static let steps: [FoldStep] = [
        // 1 — fold top corner to bottom corner.
        FoldStep(title: "STEP 1", instruction: "fold top corner 1 down onto corner 2",
                 layers: [Layer(pts: diamond)],
                 afterLayers: [Layer(pts: tri1)],
                 innerCreases: [],
                 foldGuides: [[CGPoint(x: 0.04, y: 0.5), CGPoint(x: 0.96, y: 0.5)]],
                 anim: .flap(crease: (CGPoint(x: 0.04, y: 0.5), CGPoint(x: 0.96, y: 0.5)),
                             stationary: [Layer(pts: step1Stationary)],
                             moving: [CGPoint(x: 0.5, y: 0.04), CGPoint(x: 0.96, y: 0.5), CGPoint(x: 0.04, y: 0.5)]),
                 markers: [CGPoint(x: 0.5, y: 0.04), CGPoint(x: 0.5, y: 0.96)],
                 mathTitle: "reflection across a diagonal",
                 mathLines: ["R₁(top vertex) = bottom vertex", "side 1 becomes hypotenuse √2"],
                 callout: rt4545),
        // 2 — fold right corner to left corner.
        FoldStep(title: "STEP 2", instruction: "fold right corner 1 onto left corner 2",
                 layers: [Layer(pts: tri1)],
                 afterLayers: [Layer(pts: tri2)],
                 innerCreases: [],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.96)]],
                 anim: .flap(crease: (CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.96)),
                             stationary: [Layer(pts: step2Stationary)],
                             moving: [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.96, y: 0.5), CGPoint(x: 0.5, y: 0.96)]),
                 markers: [CGPoint(x: 0.96, y: 0.5), CGPoint(x: 0.04, y: 0.5)],
                 mathTitle: "a second line reflection",
                 mathLines: ["R₂(right vertex) = left vertex", "visible face area: ½ → ¼"],
                 callout: rt4545Half),
        // 3 — pick up the top layer from the edge.
        FoldStep(title: "STEP 3", instruction: "pick up the top layer at 1, pull toward 2",
                 layers: [Layer(pts: tri2), Layer(pts: tri2, front: true)],
                 afterLayers: [Layer(pts: tri2), Layer(pts: lifted, front: true)],
                 innerCreases: [],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.96)]],
                 anim: .dissolve,
                 markers: [CGPoint(x: 0.25, y: 0.73), CGPoint(x: 0.60, y: 0.66)],
                 mathTitle: "rotation about a hinge",
                 mathLines: ["θ: 0° → 90° around the old crease", "distance to the hinge stays fixed"],
                 callout: nil),
        // 4 — push the bottom corner down flat to make a diamond.
        FoldStep(title: "STEP 4", instruction: "push corner 1 down, flattening at 2 and 3",
                 layers: [Layer(pts: tri2), Layer(pts: lifted, front: true)],
                 afterLayers: [Layer(pts: tri2), Layer(pts: frontDiamond, front: true)],
                 innerCreases: [(CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.94))],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.30, y: 0.72), CGPoint(x: 0.5, y: 0.94)],
                              [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.70, y: 0.72), CGPoint(x: 0.5, y: 0.94)]],
                 anim: .dissolve,
                 markers: [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.30, y: 0.72), CGPoint(x: 0.70, y: 0.72)],
                 mathTitle: "a symmetric squash fold",
                 mathLines: ["two facets rotate by equal opposite angles", "the pocket flattens into a congruent square"],
                 callout: nil),
        // 5 — turn the crane over from left to right.
        FoldStep(title: "STEP 5", instruction: "turn over: the unopened back pocket now faces you",
                 layers: [Layer(pts: tri2), Layer(pts: frontDiamond, front: true)],
                 afterLayers: [Layer(pts: tri2M), Layer(pts: frontDiamond, front: true)],
                 innerCreases: [],
                 foldGuides: [],
                 anim: .turnOver,
                 markers: [CGPoint(x: 0.15, y: 0.68), CGPoint(x: 0.85, y: 0.68)],
                 mathTitle: "reflection of the whole model",
                 mathLines: ["F(x, y) = (1 − x, y)", "the hidden pocket becomes the front pocket"],
                 callout: nil),
        // 6 — squash the second side into a diamond → square base.
        FoldStep(title: "STEP 6", instruction: "repeat steps 3-4 on that exposed pocket: lift 1, open 2, flatten 3",
                 layers: [Layer(pts: tri2M), Layer(pts: frontDiamond, front: true)],
                 afterLayers: [Layer(pts: squareBase)],
                 innerCreases: [(CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.5, y: 0.96))],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.96)]],
                 anim: .squash(crease: (CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.96)),
                               moving: tri2M),
                 markers: [CGPoint(x: 0.96, y: 0.5), CGPoint(x: 0.62, y: 0.66), CGPoint(x: 0.5, y: 0.94)],
                 mathTitle: "the second squash fold",
                 mathLines: ["same hinge rotation as steps 3-4, on the opposite layer", "both pockets now form one square base"],
                 callout: nil),
        // 7 — kite folds: top-layer corners in to the centre line.
        FoldStep(title: "STEP 7", instruction: "fold corners 1 and 2 in to meet at 3",
                 layers: [Layer(pts: squareBase)],
                 afterLayers: [Layer(pts: squareBase), Layer(pts: kite, front: true)],
                 innerCreases: [(CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.5, y: 0.96))],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.635, y: 0.70), CGPoint(x: 0.5, y: 0.96)],
                              [CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.365, y: 0.70), CGPoint(x: 0.5, y: 0.96)]],
                 anim: .dissolve,
                 markers: [CGPoint(x: 0.73, y: 0.62), CGPoint(x: 0.27, y: 0.62), CGPoint(x: 0.5, y: 0.70)],
                 mathTitle: "two angle bisectors",
                 mathLines: ["45° → 22.5° + 22.5°", "tan 22.5° = √2 − 1 ≈ 0.414"],
                 callout: rt225),
        // 8 — fold the top corner down.
        FoldStep(title: "STEP 8", instruction: "fold top corner 1 down to 2",
                 layers: [Layer(pts: squareBase), Layer(pts: kite, front: true)],
                 afterLayers: [Layer(pts: squareBase), Layer(pts: kiteBody, front: true), Layer(pts: kiteTipDown, front: true)],
                 innerCreases: [],
                 foldGuides: [[CGPoint(x: 0.436, y: 0.48), CGPoint(x: 0.564, y: 0.48)]],
                 anim: .flap(crease: (CGPoint(x: 0.436, y: 0.48), CGPoint(x: 0.564, y: 0.48)),
                             stationary: [Layer(pts: squareBase), Layer(pts: kiteBody, front: true)],
                             moving: kiteTip),
                 markers: [CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.5, y: 0.68)],
                 mathTitle: "a perpendicular reflection",
                 mathLines: ["the cap crosses its horizontal crease", "R₃ preserves every edge length"],
                 callout: nil),
        // 9 — unfold all the step 7–8 folds.
        FoldStep(title: "STEP 9", instruction: "unfold — pull 1 and 2 out, tip back up at 3",
                 layers: [Layer(pts: squareBase), Layer(pts: kiteBody, front: true), Layer(pts: kiteTipDown, front: true)],
                 afterLayers: [Layer(pts: squareBase)],
                 innerCreases: [(CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.635, y: 0.70)),
                                (CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.365, y: 0.70)),
                                (CGPoint(x: 0.436, y: 0.48), CGPoint(x: 0.564, y: 0.48))],
                 foldGuides: [],
                 anim: .dissolve,
                 markers: [CGPoint(x: 0.635, y: 0.70), CGPoint(x: 0.365, y: 0.70), CGPoint(x: 0.5, y: 0.34)],
                 mathTitle: "reflection followed by its inverse",
                 mathLines: ["R₃⁻¹ ∘ R₃ = identity", "the shape returns; three crease axes remain"],
                 callout: nil),
        // 10 — petal fold the front.
        FoldStep(title: "STEP 10", instruction: "hold 1, lift 2 all the way up, push in at 3 and 4",
                 layers: [Layer(pts: squareBase)],
                 afterLayers: [Layer(pts: squareBase), Layer(pts: petalFront, front: true)],
                 innerCreases: [(CGPoint(x: 0.436, y: 0.48), CGPoint(x: 0.564, y: 0.48))],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.635, y: 0.70), CGPoint(x: 0.5, y: 0.96)],
                              [CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.365, y: 0.70), CGPoint(x: 0.5, y: 0.96)]],
                 anim: .dissolve,
                 markers: [CGPoint(x: 0.5, y: 0.32), CGPoint(x: 0.5, y: 0.96), CGPoint(x: 0.365, y: 0.70), CGPoint(x: 0.635, y: 0.70)],
                 mathTitle: "composition of three reflections",
                 mathLines: ["P = R₃ ∘ R₂ ∘ R₁", "the lower point maps to a 22.5° upper point"],
                 callout: nil),
        // 11 — turn over.
        FoldStep(title: "STEP 11", instruction: "turn the paper over, 1 to 2",
                 layers: [Layer(pts: squareBase), Layer(pts: petalFront, front: true)],
                 afterLayers: [Layer(pts: squareBase), Layer(pts: petalFront, front: true)],
                 innerCreases: [],
                 foldGuides: [],
                 anim: .turnOver,
                 markers: [CGPoint(x: 0.2, y: 0.55), CGPoint(x: 0.8, y: 0.55)],
                 mathTitle: "a 180° spatial rotation",
                 mathLines: ["Rotᵧ(180°) exposes the opposite face", "the petal-fold geometry is unchanged"],
                 callout: nil),
        // 12 — petal fold the back → bird base.
        FoldStep(title: "STEP 12", instruction: "hold 1, lift 2 all the way up, push in at 3 and 4",
                 layers: [Layer(pts: squareBase), Layer(pts: petalFront, front: true)],
                 afterLayers: [Layer(pts: birdBase)],
                 innerCreases: [(CGPoint(x: 0.5, y: 0.60), CGPoint(x: 0.5, y: 0.94))],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.635, y: 0.70), CGPoint(x: 0.5, y: 0.96)],
                              [CGPoint(x: 0.5, y: 0.28), CGPoint(x: 0.365, y: 0.70), CGPoint(x: 0.5, y: 0.96)]],
                 anim: .dissolve,
                 markers: [CGPoint(x: 0.5, y: 0.32), CGPoint(x: 0.5, y: 0.96), CGPoint(x: 0.365, y: 0.70), CGPoint(x: 0.635, y: 0.70)],
                 mathTitle: "a mirrored petal fold",
                 mathLines: ["the second petal is congruent to the first", "22.5° · 67.5° · 90° gives 1 + √2"],
                 callout: rt225Long),
        // 13 — narrow the front: corners to the centre line.
        FoldStep(title: "STEP 13", instruction: "fold edges 1 and 2 in to the centre line 3",
                 layers: [Layer(pts: birdBase)],
                 afterLayers: [Layer(pts: birdBase), Layer(pts: narrowFront, front: true)],
                 innerCreases: [(CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.5, y: 0.80))],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.55, y: 0.55), CGPoint(x: 0.5, y: 0.80)],
                              [CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.45, y: 0.55), CGPoint(x: 0.5, y: 0.80)]],
                 anim: .dissolve,
                 markers: [CGPoint(x: 0.60, y: 0.60), CGPoint(x: 0.40, y: 0.60), CGPoint(x: 0.5, y: 0.45)],
                 mathTitle: "paired edge reflections",
                 mathLines: ["both outer edges map to the center axis", "bisecting 22.5° creates 11.25°"],
                 callout: nil),
        // 14 — turn over.
        FoldStep(title: "STEP 14", instruction: "turn the paper over, 1 to 2",
                 layers: [Layer(pts: birdBase), Layer(pts: narrowFront, front: true)],
                 afterLayers: [Layer(pts: birdBase), Layer(pts: narrowFront, front: true)],
                 innerCreases: [],
                 foldGuides: [],
                 anim: .turnOver,
                 markers: [CGPoint(x: 0.25, y: 0.5), CGPoint(x: 0.75, y: 0.5)],
                 mathTitle: "another half-turn",
                 mathLines: ["Rotᵧ(180°) swaps front and back", "the center axis remains invariant"],
                 callout: nil),
        // 15 — narrow the back → body with two loose points.
        FoldStep(title: "STEP 15", instruction: "fold edges 1 and 2 in to the centre line 3",
                 layers: [Layer(pts: birdBase), Layer(pts: narrowFront, front: true)],
                 afterLayers: [Layer(pts: narrowBody), Layer(pts: spikeL), Layer(pts: spikeR)],
                 innerCreases: [(CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.5, y: 0.74))],
                 foldGuides: [[CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.565, y: 0.55), CGPoint(x: 0.5, y: 0.74)],
                              [CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.435, y: 0.55), CGPoint(x: 0.5, y: 0.74)]],
                 anim: .dissolve,
                 markers: [CGPoint(x: 0.60, y: 0.60), CGPoint(x: 0.40, y: 0.60), CGPoint(x: 0.5, y: 0.45)],
                 mathTitle: "matching edge reflections",
                 mathLines: ["four narrow facets are pairwise congruent", "two free points become neck and tail"],
                 callout: nil),
        // 16 — inside reverse fold: the neck.
        FoldStep(title: "STEP 16", instruction: "hold at 1, pull point 2 up inside from joint 3",
                 layers: [Layer(pts: narrowBody), Layer(pts: spikeL), Layer(pts: spikeR)],
                 afterLayers: [Layer(pts: narrowBody), Layer(pts: neckUp), Layer(pts: spikeR)],
                 innerCreases: [],
                 foldGuides: [[CGPoint(x: 0.395, y: 0.62), CGPoint(x: 0.485, y: 0.55)]],
                 anim: .swing(pivot: CGPoint(x: 0.435, y: 0.55), degrees: 125, movingIndex: 1),
                 markers: [CGPoint(x: 0.56, y: 0.62), CGPoint(x: 0.335, y: 0.94), CGPoint(x: 0.435, y: 0.55)],
                 mathTitle: "inside reverse rotation",
                 mathLines: ["Rotⱼ(125°) lifts the first free point", "the joint and every facet length stay fixed"],
                 callout: nil),
        // 17 — inside reverse fold: the tail.
        FoldStep(title: "STEP 17", instruction: "hold at 1, pull point 2 up from joint 3",
                 layers: [Layer(pts: narrowBody), Layer(pts: neckUp), Layer(pts: spikeR)],
                 afterLayers: [Layer(pts: narrowBody), Layer(pts: neckUp), Layer(pts: tailUp)],
                 innerCreases: [],
                 foldGuides: [[CGPoint(x: 0.605, y: 0.62), CGPoint(x: 0.515, y: 0.55)]],
                 anim: .swing(pivot: CGPoint(x: 0.565, y: 0.55), degrees: -125, movingIndex: 2),
                 markers: [CGPoint(x: 0.44, y: 0.62), CGPoint(x: 0.665, y: 0.94), CGPoint(x: 0.565, y: 0.55)],
                 mathTitle: "the reflected reverse fold",
                 mathLines: ["Rotⱼ(−125°) mirrors the neck rotation", "equal angles create bilateral symmetry"],
                 callout: nil),
        // 18 — reverse fold the head.
        FoldStep(title: "STEP 18", instruction: "push point 1 down at 2 to make the head",
                 layers: [Layer(pts: narrowBody), Layer(pts: neckLower), Layer(pts: headTip), Layer(pts: tailUp)],
                 afterLayers: [Layer(pts: narrowBody), Layer(pts: neckLower), Layer(pts: headTip), Layer(pts: tailUp)],
                 innerCreases: [],
                 foldGuides: [[CGPoint(x: 0.272, y: 0.361), CGPoint(x: 0.199, y: 0.339)]],
                 anim: .swing(pivot: headPivot, degrees: 118, movingIndex: 2),
                 markers: [CGPoint(x: 0.173, y: 0.244), CGPoint(x: 0.236, y: 0.35)],
                 mathTitle: "a smaller reverse rotation",
                 mathLines: ["Rotₕ(118°) maps the tip into a beak", "neck length and beak length are preserved"],
                 callout: nil),
        // 19 — pull the wings down and out into the finished 3D crane.
        FoldStep(title: "STEP 19", instruction: "pull wing 1 down and out toward 2 and 3",
                 layers: [Layer(pts: narrowBody), Layer(pts: neckLower),
                          Layer(pts: rotate(headTip, about: headPivot, degrees: 118)), Layer(pts: tailUp)],
                 afterLayers: [],
                 innerCreases: [],
                 foldGuides: [[CGPoint(x: 0.44, y: 0.30), CGPoint(x: 0.56, y: 0.30)]],
                 anim: .crane,
                 markers: [CGPoint(x: 0.5, y: 0.06), CGPoint(x: 0.30, y: 0.32), CGPoint(x: 0.70, y: 0.32)],
                 mathTitle: "a plane-to-space transformation",
                 mathLines: ["equal wing rotations preserve bilateral symmetry", "dihedral angles add depth without stretching"],
                 callout: nil)
    ]

    private var step: FoldStep { Self.steps[min(viewModel.stepIndex, Self.steps.count - 1)] }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.finale {
                    finaleView(size: size)
                        .transition(.opacity)
                } else {
                    foldStage(size: size)
                }

                ProgressView(value: viewModel.progress)
                    .tint(gold)
                    .frame(width: min(size.width - 58, 380))
                    .position(x: size.width / 2, y: size.height * 0.165)

                HomeButton(action: onLevelSelect)
                    .position(x: 34, y: 54)
                    .zIndex(20)

                CompletionOverlay(
                    title: "Level \(MathItCurriculum.levelNumber(forScreenLevel: 42) ?? 42) Folded",
                    isVisible: viewModel.completed,
                    onContinue: onContinue,
                    onReplay: onReplay,
                    onLevelSelect: onLevelSelect
                )
                .zIndex(100)
            }
            .environment(\.mathItAccent, gold)
            .onChange(of: viewModel.stepIndex) { _, _ in
                // Animation state is reset ONLY here, never after a fold — a
                // finished fold can never snap back.
                foldAngle = 0
                swingAngle = 0
                dissolve = 0
            }
        }
    }

    // MARK: - Stage

    private func foldStage(size: CGSize) -> some View {
        let side = min(size.width - 64, size.height * 0.43, 360)
        let canvas = CGRect(x: (size.width - side) / 2, y: size.height * 0.28, width: side, height: side)

        return ZStack {
            RadialGradient(
                colors: [.white.opacity(0.10), .clear],
                center: .center,
                startRadius: 20,
                endRadius: side * 0.82
            )
            .frame(width: side * 1.6, height: side * 1.35)
            .position(x: size.width / 2, y: canvas.midY + side * 0.08)
            .allowsHitTesting(false)

            VStack(spacing: 4) {
                Text("LEVEL \(MathItCurriculum.levelNumber(forScreenLevel: 42) ?? 42) · \(step.title) OF \(Self.steps.count)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(3)
                    .foregroundStyle(gold.opacity(0.85))
                Text(step.instruction)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .position(x: size.width / 2, y: size.height * 0.205)

            paperView(canvas: canvas)

            if !viewModel.folding && !viewModel.showMath {
                let guides = step.foldGuides
                ForEach(guides.indices, id: \.self) { g in
                    guideLine(guides[g], in: canvas)
                }
                let markers = step.markers
                ForEach(markers.indices, id: \.self) { m in
                    marker(m + 1,
                           at: point(markers[m], in: canvas),
                           armed: m < viewModel.tappedCount,
                           isNext: m == viewModel.tappedCount,
                           total: markers.count)
                }
            }

            if viewModel.showMath {
                mathPanel(width: min(size.width - 56, 340))
                    .position(x: size.width / 2, y: size.height * 0.805)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func point(_ unit: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + unit.x * rect.width, y: rect.minY + unit.y * rect.height)
    }

    private func guideLine(_ pts: [CGPoint], in canvas: CGRect) -> some View {
        Path { p in
            guard let first = pts.first else { return }
            p.move(to: point(first, in: canvas))
            for pt in pts.dropFirst() {
                p.addLine(to: point(pt, in: canvas))
            }
        }
        .stroke(mountainRed.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        .allowsHitTesting(false)
    }

    // MARK: - Paper rendering

    @ViewBuilder
    private func paperView(canvas: CGRect) -> some View {
        switch step.anim {
        case .flap(let crease, let stationary, let moving):
            flapStep(canvas: canvas, crease: crease, stationary: stationary, moving: moving)
        case .squash(let crease, let moving):
            squashStep(canvas: canvas, crease: crease, moving: moving)
        case .turnOver:
            turnOverStep(canvas: canvas)
        case .swing(let pivot, let degrees, let movingIndex):
            swingStep(canvas: canvas, pivot: pivot, degrees: degrees, movingIndex: movingIndex)
        case .dissolve:
            dissolveStep(canvas: canvas)
        case .crane:
            craneStep(canvas: canvas)
        }
    }

    @ViewBuilder
    private func flapStep(canvas: CGRect, crease: (CGPoint, CGPoint), stationary: [Layer], moving: [CGPoint]) -> some View {
        if viewModel.showMath {
            paperLayers(step.afterLayers, creases: step.innerCreases, in: canvas)
        } else {
            paperLayers(stationary, creases: step.innerCreases, in: canvas)

            let backside = foldAngle > 90
            let mid = CGPoint(x: (crease.0.x + crease.1.x) / 2, y: (crease.0.y + crease.1.y) / 2)
            PolygonShape(unitPoints: moving)
                .fill(paperFill(backside ? paperRear : paperFront, highlight: backside ? 0.0 : 0.16))
                .overlay(PaperFiberShape().stroke(.white.opacity(backside ? 0.02 : 0.045), lineWidth: 0.8).mask(PolygonShape(unitPoints: moving)))
                .overlay(PolygonShape(unitPoints: moving).stroke(.black.opacity(0.25), lineWidth: 1))
                .frame(width: canvas.width, height: canvas.height)
                .rotation3DEffect(
                    .degrees(foldAngle),
                    axis: (x: crease.1.x - crease.0.x, y: crease.1.y - crease.0.y, z: 0),
                    anchor: UnitPoint(x: mid.x, y: mid.y),
                    perspective: 0.3
                )
                .position(x: canvas.midX, y: canvas.midY)
                .paperStage3D()
                .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 8)
        }
    }

    @ViewBuilder
    private func squashStep(canvas: CGRect, crease: (CGPoint, CGPoint), moving: [CGPoint]) -> some View {
        let d = viewModel.showMath ? 1.0 : dissolve

        paperLayers(step.layers, creases: [], in: canvas)
            .opacity(1 - d)
        paperLayers(step.afterLayers, creases: step.innerCreases, in: canvas)
            .opacity(d)

        if !viewModel.showMath {
            let mid = CGPoint(x: (crease.0.x + crease.1.x) / 2, y: (crease.0.y + crease.1.y) / 2)
            PolygonShape(unitPoints: moving)
                .fill(paperFill(paperFront, highlight: 0.14))
                .overlay(PaperFiberShape().stroke(.white.opacity(0.04), lineWidth: 0.8).mask(PolygonShape(unitPoints: moving)))
                .overlay(PolygonShape(unitPoints: moving).stroke(.black.opacity(0.25), lineWidth: 1))
                .frame(width: canvas.width, height: canvas.height)
                .rotation3DEffect(
                    .degrees(foldAngle),
                    axis: (x: crease.1.x - crease.0.x, y: crease.1.y - crease.0.y, z: 0),
                    anchor: UnitPoint(x: mid.x, y: mid.y),
                    perspective: 0.3
                )
                .position(x: canvas.midX, y: canvas.midY)
                .paperStage3D()
                .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 8)
                .opacity(1 - d)
        }
    }

    /// Turn-over: the whole paper flips about its vertical axis. Rotating the
    /// before-layers by 180° IS the mirrored after-state, so the end of the
    /// animation matches the static after-render exactly.
    @ViewBuilder
    private func turnOverStep(canvas: CGRect) -> some View {
        if viewModel.showMath {
            paperLayers(step.afterLayers, creases: step.innerCreases, in: canvas)
        } else {
            paperLayers(step.layers, creases: step.innerCreases, in: canvas)
                .rotation3DEffect(.degrees(foldAngle), axis: (x: 0, y: 1, z: 0),
                                  anchor: .center, perspective: 0.35)
        }
    }

    @ViewBuilder
    private func swingStep(canvas: CGRect, pivot: CGPoint, degrees: Double, movingIndex: Int) -> some View {
        let statics = step.layers.enumerated().filter { $0.offset != movingIndex }.map(\.element)
        paperLayers(statics, creases: step.innerCreases, in: canvas)

        let angle = viewModel.showMath ? degrees : swingAngle
        let phase = degrees == 0 ? 1 : min(1, abs(angle / degrees))
        let lift = sin(phase * .pi)
        let swung = Self.rotate(step.layers[movingIndex].pts, about: pivot, degrees: angle)
        PolygonShape(unitPoints: swung)
            .fill(paperFill(paperFront, highlight: 0.12))
            .overlay(PolygonShape(unitPoints: swung).stroke(.black.opacity(0.25), lineWidth: 1))
            .frame(width: canvas.width, height: canvas.height)
            .rotation3DEffect(
                .degrees(lift * 34),
                axis: (x: 1, y: 0.15, z: 0),
                anchor: UnitPoint(x: pivot.x, y: pivot.y),
                perspective: 0.45
            )
            .offset(y: -CGFloat(lift * 10))
            .position(x: canvas.midX, y: canvas.midY)
            .paperStage3D()
            .shadow(color: .black.opacity(0.28), radius: 4 + CGFloat(lift * 8), x: 0, y: 4 + CGFloat(lift * 8))
    }

    @ViewBuilder
    private func dissolveStep(canvas: CGRect) -> some View {
        let d = viewModel.showMath ? 1.0 : dissolve

        paperLayers(step.layers, creases: [], in: canvas)
            .opacity(1 - d)
            .rotation3DEffect(
                .degrees(d * 30),
                axis: (x: 1, y: -0.12, z: 0),
                anchor: .center,
                perspective: 0.45
            )
            .offset(y: CGFloat(d * 9))
        paperLayers(step.afterLayers, creases: step.innerCreases, in: canvas)
            .opacity(d)
            .rotation3DEffect(
                .degrees((1 - d) * -30),
                axis: (x: 1, y: 0.12, z: 0),
                anchor: .center,
                perspective: 0.45
            )
            .offset(y: -CGFloat((1 - d) * 9))
    }

    @ViewBuilder
    private func craneStep(canvas: CGRect) -> some View {
        let d = viewModel.showMath ? 1.0 : dissolve

        paperLayers(step.layers, creases: [], in: canvas)
            .opacity(1 - d)
        PaperCrane3DView(front: paperFront, rear: paperRear)
            .frame(width: canvas.width * 1.12, height: canvas.height * 1.12)
            .position(x: canvas.midX, y: canvas.midY)
            .opacity(d)
            .scaleEffect(0.82 + d * 0.18)
            .rotation3DEffect(.degrees(7), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(-9), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 14)
    }

    private func paperLayers(_ layers: [Layer], creases: [(CGPoint, CGPoint)], in canvas: CGRect) -> some View {
        // Arrays captured by value — `step` is never re-read inside ForEach.
        ZStack {
            ForEach(layers.indices, id: \.self) { i in
                let layer = layers[i]
                ZStack {
                    PolygonShape(unitPoints: layer.pts)
                        .fill(paperRear.opacity(layer.front ? 0.72 : 0.5))
                        .offset(x: 2.2, y: 2.8)

                    PolygonShape(unitPoints: layer.pts)
                        .fill(paperFill(layer.front ? paperFront : paperRear, highlight: layer.front ? 0.14 : 0.05))
                        .overlay(PaperFiberShape().stroke(.white.opacity(layer.front ? 0.04 : 0.018), lineWidth: 0.7).mask(PolygonShape(unitPoints: layer.pts)))
                        .overlay(PolygonShape(unitPoints: layer.pts).stroke(.black.opacity(0.28), lineWidth: 1))
                        .overlay(PolygonShape(unitPoints: layer.pts).stroke(.white.opacity(layer.front ? 0.20 : 0.08), lineWidth: 0.6).blendMode(.plusLighter))
                }
                .shadow(color: .black.opacity(0.20), radius: 5, x: 0, y: 2 + CGFloat(i))
                .offset(x: CGFloat(i) * 1.6, y: CGFloat(i) * -1.2)
            }
            Path { p in
                for crease in creases {
                    p.move(to: CGPoint(x: crease.0.x * canvas.width, y: crease.0.y * canvas.height))
                    p.addLine(to: CGPoint(x: crease.1.x * canvas.width, y: crease.1.y * canvas.height))
                }
            }
            .stroke(.black.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .frame(width: canvas.width, height: canvas.height)
        .position(x: canvas.midX, y: canvas.midY)
        .paperStage3D()
        .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 12)
        .shadow(color: .white.opacity(0.06), radius: 12)
    }

    private func paperFill(_ base: Color, highlight: Double) -> LinearGradient {
        let light = highlight > 0.1 ? base.opacity(0.98) : base.opacity(0.9)
        return LinearGradient(
            colors: [
                light,
                base,
                base.opacity(0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Markers & firing

    private func marker(_ n: Int, at p: CGPoint, armed: Bool, isNext: Bool, total: Int) -> some View {
        TimelineView(.animation) { context in
            let pulse = isNext ? 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 5.6) : 0
            Button {
                fireMarker(n, total: total)
            } label: {
                ZStack {
                    Circle()
                        .stroke(gold.opacity(isNext ? 0.34 : 0.0), lineWidth: 2)
                        .frame(width: 38 + CGFloat(pulse * 16), height: 38 + CGFloat(pulse * 16))
                    Circle()
                        .fill(gold.opacity(isNext ? 0.18 : (armed ? 0.12 : 0.04)))
                        .frame(width: 48, height: 48)
                        .blur(radius: 5)
                    Circle().fill(armed ? gold : Color.black.opacity(0.78))
                    Circle().stroke(gold.opacity(armed || isNext ? 1 : 0.55), lineWidth: isNext ? 2.6 : 1.6)
                    Circle().fill(.white.opacity(isNext ? 0.32 : 0.10)).frame(width: 8, height: 8).offset(x: -6, y: -7)
                    Text("\(n)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(armed ? .black : gold)
                }
                .frame(width: 30, height: 30)
                .shadow(color: gold.opacity(armed ? 0.8 : (isNext ? 0.92 : 0.22)), radius: armed ? 13 : (isNext ? 18 : 5))
                .scaleEffect(armed ? 1.15 : (isNext ? 1.08 + pulse * 0.04 : 0.94))
                .opacity(armed || isNext ? 1 : 0.78)
            }
            .buttonStyle(.plain)
            .contentShape(Circle().inset(by: -14))
        }
        .position(p)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: armed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isNext)
    }

    private func fireMarker(_ n: Int, total: Int) {
        guard viewModel.tapMarker(n, total: total) else { return }
        viewModel.folding = true

        switch step.anim {
        case .flap:
            withAnimation(.easeInOut(duration: 0.85)) { foldAngle = 180 }
            finish(after: 0.95)
        case .squash:
            withAnimation(.easeIn(duration: 0.5)) { foldAngle = 90 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.55)) { dissolve = 1 }
            }
            finish(after: 1.15)
        case .turnOver:
            withAnimation(.easeInOut(duration: 0.8)) { foldAngle = 180 }
            finish(after: 0.9)
        case .swing(_, let degrees, _):
            withAnimation(.spring(response: 0.8, dampingFraction: 0.72)) { swingAngle = degrees }
            finish(after: 1.0)
        case .dissolve:
            withAnimation(.easeInOut(duration: 0.8)) { dissolve = 1 }
            finish(after: 0.9)
        case .crane:
            withAnimation(.easeInOut(duration: 0.8)) { dissolve = 1 }
            reveal(after: 0.9)
        }
    }

    /// No animation-state cleanup here — final poses persist until the next
    /// step loads (reset happens in onChange(stepIndex)).
    private func finish(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.foldFinished()
            }
        }
    }

    private func reveal(after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            viewModel.revealFinale()
        }
    }

    // MARK: - Math panel

    private func mathPanel(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text(step.mathTitle)
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                .foregroundStyle(gold)

            Text(transformationFormula(for: step.anim))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                if let callout = step.callout {
                    calloutTriangle(callout)
                        .frame(width: 96, height: 84)
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(step.mathLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }

            Button {
                viewModel.nextStep(total: Self.steps.count)
            } label: {
                Text("NEXT FOLD")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 26).padding(.vertical, 9)
                    .background(Capsule().fill(gold))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private func calloutTriangle(_ c: TriangleCallout) -> some View {
        Canvas { ctx, s in
            func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * s.width, y: p.y * s.height) }
            var tri = Path()
            tri.move(to: pt(c.pts[0]))
            tri.addLine(to: pt(c.pts[1]))
            tri.addLine(to: pt(c.pts[2]))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(paperFront.opacity(0.15)))
            ctx.stroke(tri, with: .color(.white.opacity(0.85)), lineWidth: 1.6)
            for (text, p) in c.angleLabels {
                ctx.draw(Text(text).font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color.mathGold), at: pt(p))
            }
            for (text, p) in c.sideLabels {
                ctx.draw(Text(text).font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85)), at: pt(p))
            }
        }
    }

    private func transformationFormula(for anim: FoldAnim) -> String {
        switch anim {
        case .flap:
            return "rigid reflection across crease L: p' = reflect_L(p)"
        case .squash:
            return "two hinged rotations share one projected crease axis"
        case .turnOver:
            return "whole-model half-turn: Rot_y(180°)"
        case .swing:
            return "inside reverse fold: Rot_joint(theta) with fixed edge lengths"
        case .dissolve:
            return "crease pattern composes reflections, then flattens into new facets"
        case .crane:
            return "planar facets gain dihedral angle without stretching"
        }
    }

    // MARK: - Finale · the hypercube lattice

    private func finaleView(size: CGSize) -> some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                PaperCrane3DView(front: paperFront, rear: paperRear)
                    .frame(width: 120, height: 120)
                    .position(x: size.width / 2, y: size.height * 0.68)

                Canvas { c, s in
                    let top = CGPoint(x: s.width / 2, y: s.height * 0.36)
                    let bottom = CGPoint(x: s.width / 2, y: s.height * 0.66)
                    for i in 0..<6 {
                        let f = CGFloat(i) / 5 - 0.5
                        var ray = Path()
                        ray.move(to: CGPoint(x: top.x + f * 150, y: top.y + 60))
                        ray.addLine(to: CGPoint(x: bottom.x + f * 70, y: bottom.y))
                        c.stroke(ray, with: .color((i.isMultiple(of: 2) ? mountainRed : valleyBlue).opacity(0.35)),
                                 lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)

                TesseractView(time: t, mountain: mountainRed, valley: valleyBlue)
                    .frame(width: 250, height: 250)
                    .position(x: size.width / 2, y: size.height * 0.35)

                VStack(spacing: 5) {
                    Text("PLANE → SPACE")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(gold)

                    Text("rigid faces preserve length · dihedral angles create depth")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))

                    Text("your crane's folds are a shadow of a hypercube lattice")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(gold)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 38)
                .position(x: size.width / 2, y: size.height * 0.82)
            }
        }
    }
}

// MARK: - Shapes

private struct PolygonShape: Shape {
    let unitPoints: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = unitPoints.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for p in unitPoints.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

private struct PaperFiberShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for i in 0..<18 {
            let y = rect.minY + rect.height * CGFloat(i) / 17
            let offset = CGFloat((i * 13) % 19) - 9
            path.move(to: CGPoint(x: rect.minX - 12, y: y + offset * 0.15))
            path.addLine(to: CGPoint(x: rect.maxX + 12, y: y + offset * 0.15 + rect.height * 0.08))
        }
        for i in 0..<10 {
            let x = rect.minX + rect.width * CGFloat(i) / 9
            path.move(to: CGPoint(x: x, y: rect.minY - 8))
            path.addLine(to: CGPoint(x: x + rect.width * 0.05, y: rect.maxY + 8))
        }
        return path
    }
}

private extension View {
    func paperStage3D() -> some View {
        self
            .rotation3DEffect(.degrees(8), axis: (x: 1, y: 0, z: 0), perspective: 0.42)
            .rotation3DEffect(.degrees(-7), axis: (x: 0, y: 1, z: 0), perspective: 0.42)
    }
}

/// A faceted folded-paper crane built from overlapping planes, with raised
/// wings, a vertical neck, a small head fold and shaded body faces.
/// A low-poly paper crane modelled on the classic render: tall tail spike
/// upper-left, vertical neck on the right with a down-turned beak, one big
/// bright wing sweeping down-left, a shadowed wing behind to the right, and a
/// compact two-tone body standing on its notched base. Flat-shaded facets,
/// light from the upper left.
private struct PaperCrane3DView: View {
    let front: Color
    let rear: Color

    var body: some View {
        ZStack {
            groundShadow

            // ── Back layer ─────────────────────────────────────────────
            // Right (far) wing — in shadow behind the body and neck.
            facet([p(0.62, 0.50), p(0.98, 0.585), p(0.66, 0.665)],
                  light: 0.28)
            facet([p(0.62, 0.50), p(0.98, 0.585), p(0.80, 0.505)],
                  light: 0.45)

            // Tail spike — two long slivers meeting at the sharp tip.
            facet([p(0.44, 0.545), p(0.225, 0.045), p(0.485, 0.475)],
                  light: 0.95)
            facet([p(0.485, 0.475), p(0.225, 0.045), p(0.525, 0.545)],
                  light: 0.55)

            // ── Body ───────────────────────────────────────────────────
            // Back body panel (dark) with the standing base.
            facet([p(0.42, 0.545), p(0.66, 0.545), p(0.615, 0.83), p(0.455, 0.83)],
                  light: 0.42)
            // Base feet — the notched bottom.
            facet([p(0.455, 0.83), p(0.615, 0.83), p(0.575, 0.925), p(0.535, 0.845), p(0.495, 0.925)],
                  light: 0.30)
            // Bright front body facet — the big lit triangle of the photo.
            facet([p(0.42, 0.545), p(0.66, 0.545), p(0.525, 0.77)],
                  light: 1.0)
            facet([p(0.455, 0.83), p(0.525, 0.77), p(0.615, 0.83), p(0.535, 0.845)],
                  light: 0.66)

            // ── Neck & head (right, nearly vertical) ───────────────────
            // Neck: dark back sliver + lit front sliver.
            facet([p(0.665, 0.72), p(0.705, 0.155), p(0.72, 0.72)],
                  light: 0.40)
            facet([p(0.635, 0.72), p(0.67, 0.135), p(0.705, 0.155), p(0.675, 0.72)],
                  light: 0.88)
            // Head — the beak folding down-left off the neck apex.
            facet([p(0.655, 0.125), p(0.725, 0.165), p(0.575, 0.315)],
                  light: 0.62)
            facet([p(0.655, 0.125), p(0.69, 0.145), p(0.60, 0.27)],
                  light: 0.92)

            // ── Front (near) wing — the hero panel sweeping down-left ──
            facet([p(0.455, 0.46), p(0.02, 0.665), p(0.50, 0.60)],
                  light: 1.0)
            facet([p(0.50, 0.60), p(0.02, 0.665), p(0.545, 0.70)],
                  light: 0.72)

            crease(p(0.455, 0.46), p(0.545, 0.70), opacity: 0.36)
            crease(p(0.62, 0.50), p(0.66, 0.665), opacity: 0.30)
            crease(p(0.485, 0.475), p(0.525, 0.545), opacity: 0.34)
            crease(p(0.42, 0.545), p(0.615, 0.83), opacity: 0.30)
            crease(p(0.635, 0.72), p(0.705, 0.155), opacity: 0.32)
            crease(p(0.655, 0.125), p(0.60, 0.27), opacity: 0.35)
        }
        .compositingGroup()
    }

    private var groundShadow: some View {
        Ellipse()
            .fill(.black.opacity(0.24))
            .blur(radius: 10)
            .frame(width: 200, height: 32)
            .offset(x: 2, y: 66)
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }

    /// Flat-shaded facet: `light` 0…1 blends from shadowed rear tone to fully
    /// lit front tone, with a hairline fold edge.
    private func facet(_ points: [CGPoint], light: Double) -> some View {
        let lit = light >= 0.85
        let top = lit ? front : front.opacity(0.4 + light * 0.5)
        let bottom = lit ? front.opacity(0.88) : rear.opacity(0.55 + light * 0.4)
        return PolygonShape(unitPoints: points)
            .fill(LinearGradient(colors: [top, bottom],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(PaperFiberShape().stroke(.white.opacity(0.05 + light * 0.05), lineWidth: 0.55).mask(PolygonShape(unitPoints: points)))
            .overlay(PolygonShape(unitPoints: points).stroke(.black.opacity(0.22), lineWidth: 1))
            .overlay(PolygonShape(unitPoints: points).stroke(.white.opacity(lit ? 0.22 : 0.08), lineWidth: 0.55).blendMode(.plusLighter))
    }

    private func crease(_ a: CGPoint, _ b: CGPoint, opacity: Double) -> some View {
        UnitLineShape(a: a, b: b)
            .stroke(.black.opacity(opacity), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            .overlay(UnitLineShape(a: a, b: b).stroke(.white.opacity(0.08), lineWidth: 0.45).offset(y: -0.5))
    }
}

private struct UnitLineShape: Shape {
    let a: CGPoint
    let b: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + a.x * rect.width, y: rect.minY + a.y * rect.height))
        path.addLine(to: CGPoint(x: rect.minX + b.x * rect.width, y: rect.minY + b.y * rect.height))
        return path
    }
}

// MARK: - Tesseract projection

private struct TesseractView: View {
    let time: Double
    let mountain: Color
    let valley: Color

    var body: some View {
        Canvas { ctx, size in
            let scale = size.width * 0.22
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let a = time * 0.5
            let b = time * 0.32

            var pts: [CGPoint] = []
            for i in 0..<16 {
                var x = Double(i & 1) * 2 - 1
                var y = Double((i >> 1) & 1) * 2 - 1
                var z = Double((i >> 2) & 1) * 2 - 1
                var w = Double((i >> 3) & 1) * 2 - 1
                (x, w) = (x * cos(a) - w * sin(a), x * sin(a) + w * cos(a))
                (y, z) = (y * cos(b) - z * sin(b), y * sin(b) + z * cos(b))
                let s3 = 1.6 / (2.6 - w)
                let x3 = x * s3, y3 = y * s3, z3 = z * s3
                let s2 = 2.4 / (3.4 - z3)
                pts.append(CGPoint(x: center.x + x3 * s2 * scale,
                                   y: center.y + y3 * s2 * scale))
            }

            for i in 0..<16 {
                for bit in 0..<4 {
                    let j = i | (1 << bit)
                    guard j != i else { continue }
                    var p = Path()
                    p.move(to: pts[i]); p.addLine(to: pts[j])
                    let color: Color = bit == 3 ? mountain : (bit == 2 ? .white.opacity(0.75) : valley)
                    ctx.stroke(p, with: .color(color.opacity(0.85)), lineWidth: bit == 3 ? 1.8 : 1.3)
                }
            }
        }
    }
}

#Preview {
    MathItLevelThirtyThreeView(
        viewModel: MathItLevelThirtyThreeViewModel(),
        onContinue: {},
        onReplay: {},
        onLevelSelect: {}
    )
}
