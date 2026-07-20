import SwiftUI
import UIKit

extension Color {
    static let mathItAlgebra = Color(red: 1, green: 0.62, blue: 0.24)
    static let mathItGeometry = Color(red: 0.28, green: 0.78, blue: 1)
    static let mathItMusic = Color(red: 0.78, green: 0.48, blue: 1)
    static let mathItLogic = Color(red: 0.36, green: 0.92, blue: 0.5)
}

extension Color {
    static let mathGold = Color(red: 0.93, green: 0.78, blue: 0.40)   // shared gold theme
}

private struct MathItAccentKey: EnvironmentKey {
    static let defaultValue = Color.mathGold   // gold theme
}

private struct MathItLevelNumberKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

private struct MathItCompletionConceptDismissedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct MathItUsesSharedChromeKey: EnvironmentKey {
    static let defaultValue = false
}

private struct MathItLevelContentInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

struct MathItCompletionOverlayActiveKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension EnvironmentValues {
    var mathItAccent: Color {
        get { self[MathItAccentKey.self] }
        set { self[MathItAccentKey.self] = newValue }
    }
    /// The number of the level currently on screen — lets shared overlays look up
    /// the level's concept (the same infographic the lightbulb shows).
    var mathItLevelNumber: Int? {
        get { self[MathItLevelNumberKey.self] }
        set { self[MathItLevelNumberKey.self] = newValue }
    }
    var mathItCompletionConceptDismissed: Bool {
        get { self[MathItCompletionConceptDismissedKey.self] }
        set { self[MathItCompletionConceptDismissedKey.self] = newValue }
    }
    var mathItUsesSharedChrome: Bool {
        get { self[MathItUsesSharedChromeKey.self] }
        set { self[MathItUsesSharedChromeKey.self] = newValue }
    }
    var mathItLevelContentInset: CGFloat {
        get { self[MathItLevelContentInsetKey.self] }
        set { self[MathItLevelContentInsetKey.self] = newValue }
    }
}

struct EqualsLineView: View {
    var body: some View {
        ZStack {
            Color.white.opacity(0.001)

            Capsule()
                .fill(.white)
                .frame(width: 144, height: 2)
                .shadow(color: .white.opacity(0.74), radius: 10)
        }
        .contentShape(Rectangle())
    }
}

struct EqualsSymbolView: View {
    let color: Color
    let glow: Bool

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(color)
                .frame(height: 5)
            Capsule()
                .fill(color)
                .frame(height: 5)
        }
        .padding(.horizontal, 9)
        .shadow(color: glow ? color.opacity(0.72) : .clear, radius: 12)
    }
}

struct SymbolOneView: View {
    let fontSize: CGFloat
    let glow: Bool

    var body: some View {
        Text("1")
            .font(.system(size: fontSize, weight: .regular, design: .serif))
            .foregroundStyle(.white)
            .shadow(color: glow ? .white.opacity(0.55) : .clear, radius: 14)
            .contentShape(Rectangle())
    }
}

struct SplittableOneView: View {
    let fontSize: CGFloat

    var body: some View {
        SymbolOneView(fontSize: fontSize, glow: true)
    }
}

struct CompletionOverlay: View {
    @Environment(\.mathItAccent) private var accent
    @Environment(\.mathItLevelNumber) private var levelNumber
    @Environment(\.mathItCompletionConceptDismissed) private var conceptDismissed
    @Environment(\.mathItLevelContentInset) private var contentInset

    let title: String
    let isVisible: Bool
    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    // The completion page shows the SAME infographic the lightbulb shows for this
    // level (looked up from ConceptLibrary), so there is only one source of truth.
    private var concept: LevelConcept? {
        guard let levelNumber else { return nil }
        let screenLevel = MathItCurriculum.screenLevel(forLevelNumber: levelNumber) ?? levelNumber
        return ConceptLibrary.concept(for: screenLevel)
    }

    // Generic "Level N Completed" titles are replaced with the curriculum topic
    // ("3 · Fractions"); custom flavor titles ("Grid Filled", "Mancala") are kept.
    private var displayTitle: String {
        if title.hasPrefix("Level "), title.hasSuffix("Completed"),
           let n = levelNumber,
           let topic = MathItCurriculum.topic(forLevelNumber: n) {
            return "\(n) · \(topic.title)"
        }
        return title
    }

    var body: some View {
        ZStack {
            if isVisible && !conceptDismissed {
                Color.black.opacity(concept == nil ? 0.48 : 0.9)
                    .ignoresSafeArea()
                    .transition(.opacity)

                Group {
                    if let concept {
                        ConceptCardBody(header: displayTitle, concept: concept) { buttons }
                    } else {
                        VStack(spacing: 22) {
                            Text(displayTitle)
                                .font(.system(size: 32, weight: .medium, design: .serif))
                                .foregroundStyle(accent)
                                .shadow(color: accent.opacity(0.42), radius: 10)
                            buttons
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .preference(key: MathItCompletionOverlayActiveKey.self, value: isVisible)
        .animation(.spring(response: 0.7, dampingFraction: 0.86), value: isVisible && !conceptDismissed)
        .offset(y: -contentInset / 2)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            overlayButton("Continue", filled: true, action: onContinue)
            overlayButton("Replay", filled: false, action: onReplay)
            overlayButton("Levels", filled: false, action: onLevelSelect)
        }
    }

    private func overlayButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(filled ? .black : accent)
                .frame(width: 178, height: 52)
                .background(filled ? accent : .clear, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(accent.opacity(filled ? 0 : 0.68), lineWidth: 1.2)
                }
        }
        .buttonStyle(.plain)
    }
}


private struct PolygonShape: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        let count = max(sides, 3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        for index in 0..<count {
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        path.closeSubpath()
        return path
    }
}

struct HomeButton: View {
    @Environment(\.mathItUsesSharedChrome) private var usesSharedChrome

    let action: () -> Void

    var body: some View {
        Group {
            if usesSharedChrome {
                Color.clear.frame(width: 44, height: 44)
            } else {
                Button(action: action) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.mathGold)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.4), in: Circle())
                        .overlay(Circle().stroke(Color.mathGold.opacity(0.82), lineWidth: 1.2))
                        .shadow(color: Color.mathGold.opacity(0.46), radius: 7)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
        }
        .zIndex(1_000)
    }
}

struct HintButton: View {
    @Environment(\.mathItAccent) private var accent

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.48), radius: 7)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hint")
        .zIndex(1_100)
    }
}

struct LevelTopChrome: View {
    let levelNumber: Int
    let levelTitle: String
    let progress: Double
    let onHome: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let reservedSide: CGFloat = 224
            let titleWidth = max(132, proxy.size.width - reservedSide)

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.black)
                        .frame(height: 108)
                    LinearGradient(
                        colors: [.black.opacity(0.82), .black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 24)
                }
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

                VStack(spacing: 5) {
                    Text("LEVEL \(levelNumber)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Color.mathGold.opacity(0.9))
                        .lineLimit(1)

                    Text(levelTitle)
                        .font(.trajan(22))
                        .foregroundStyle(.white.opacity(0.56))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .frame(width: titleWidth, height: 45)

                    ProgressView(value: min(max(progress, 0), 1))
                        .tint(.white)
                        .opacity(0.74)
                        .frame(width: max(180, proxy.size.width - 68))
                }
                .padding(.top, 18)
                .frame(width: proxy.size.width)
                .allowsHitTesting(false)

                Button(action: onHome) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.mathGold)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.54), in: Circle())
                        .overlay(Circle().stroke(Color.mathGold.opacity(0.82), lineWidth: 1.2))
                        .shadow(color: Color.mathGold.opacity(0.46), radius: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to levels")
                .position(x: 34, y: 54)
            }
        }
    }
}

struct HintPopup: View {
    @Environment(\.mathItAccent) private var accent

    let text: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 18) {
                Text(text)
                    .font(.garamond(21))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close hint")
            }
            .padding(26)
            .frame(maxWidth: 310)
            .background(.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent.opacity(0.5), lineWidth: 1.2)
            }
            .shadow(color: accent.opacity(0.2), radius: 18)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .zIndex(1_200)
    }
}

enum HapticPlayer {
    static func playLightTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    static func playCompletionTap() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Concept completion overlay
//
// Like CompletionOverlay, but adds a small looping animation and a short
// description of the mathematical concept the level teaches.

// A level's teaching concept: title, description, and a looping visual.
// Single source of truth, used by both the completion card and the on-demand
// info button.
struct LevelConcept {
    let title: String
    let description: String
    let formula: String?
    let visual: AnyView

    init<V: View>(title: String, description: String, formula: String? = nil, @ViewBuilder visual: () -> V) {
        self.title = title
        self.description = description
        self.formula = formula
        self.visual = AnyView(visual())
    }
}

enum ConceptLibrary {
    static func concept(for level: Int) -> LevelConcept? {
        switch level {
        case 1:
            return LevelConcept(
                title: "The Reflexive Property",
                description: "This quiet rule does constant work in the real world: it's how a bank confirms a balance matches itself after a transfer, and how a computer verifies a file hasn't changed by checking it equals its original.\n\nThe mirror didn't create a new number—it revealed the same one. In the formula, a represents any quantity or object, and the equals sign says both sides have the same value. Every quantity is equal to itself, and though it seems obvious, this simple truth is the starting point for equations, logic, and mathematical proof.",
                formula: "a = a"
            ) { ReflectionConceptVisual() }
        case 2:
            return LevelConcept(
                title: "The Successor",
                description: "You rely on it constantly: a clock ticking to the next second, a page number rising, or a computer stepping through a loop are all the successor at work—one more, again and again.\n\nEvery number has a successor: the next number, exactly one greater. In the formula, n is the current number, S(n) is its successor, and +1 means move one step forward. This single step gives the number system its endless structure one number at a time.",
                formula: "S(n) = n + 1"
            ) { NumberLineConceptVisual() }
        case 3:
            return LevelConcept(
                title: "Sequences",
                description: "A sequence is an ordered pattern. Each position has a specific place, so changing the order changes the sequence even when the same objects are used. Calendars, musical rhythms, traffic signals, and natural cycles all depend on events appearing in a predictable order.\n\nThe Moon's phases form a repeating sequence: new moon grows through crescent, quarter, and gibbous phases to full moon, then returns through the waning phases. The important idea here is not a calculation but recognizing which phase comes next and how the cycle repeats."
            ) { LunarPhaseConceptVisual() }
        case 4:
            return LevelConcept(
                title: "The Angle",
                description: "Angles steer the real world—pilots and satellites navigate by them, architects set the pitch of a roof, telescopes lock onto stars, and a well-aimed shot bends into the goal.\n\nGeometry begins where direction becomes measurable. In the formula, theta is the angle measure, ray 1 and ray 2 are the two directions being compared, and rotation means the turn needed to align one ray with the other. By assigning number to direction, mathematics reveals order within space itself.",
                formula: "θ = rotation from ray 1 to ray 2"
            ) { AngleConceptVisual() }
        case 5:
            return LevelConcept(
                title: "The Constant π",
                description: "π shows up wherever things are round or repeat—sizing wheels, gears, and pipes, charting the orbits of planets, and describing the waves behind sound, light, and electronics.\n\nA circle carries the same secret at any size. In the formula, C is circumference, the distance around the circle, d is diameter, the distance across it, and pi is their constant ratio. Mathematics is often not about objects themselves, but the timeless relationships that unite them.",
                formula: "π = C / d"
            ) { CircleConceptVisual() }
        case 6:
            return LevelConcept(
                title: "Coriolis Effect",
                description: "An object moving freely follows a straight path in an inertial frame. Viewed from a rotating platform, however, the surface turns beneath that path, so the object appears to curve. That apparent deflection is the Coriolis effect.\n\nOn Earth, horizontal motion bends to the right in the Northern Hemisphere and to the left in the Southern Hemisphere. The effect is zero at the equator and grows toward the poles. In the formula, Ω is the frame's rotation vector, v is the object's velocity, and their cross product sets a perpendicular apparent acceleration a_C.",
                formula: "a_C = −2Ω × v    |a_C| = 2Ωv sin φ"
            ) { CoriolisConceptVisual() }
        case 7:
            return LevelConcept(
                title: "XOR",
                description: "Nim is a combinatorial game: there is no chance or hidden information, so every position can be analyzed from the available moves. Its strategy appears when each row size is written in binary and combined column by column without carrying. That operation is bitwise exclusive OR, or XOR.\n\nThe result is the nim-sum. In normal Nim, a nim-sum of zero marks a losing position under perfect play. This level uses the misère rule, where taking the final match loses, so the same XOR strategy applies until every nonempty row has one match; then the winning move is determined by whether an odd or even number of rows remains.",
                formula: "nim-sum = h₁ ⊕ h₂ ⊕ ··· ⊕ hₙ"
            ) { NimConceptVisual() }
        case 9:
            return LevelConcept(
                title: "The Geometry of Light",
                description: "Light surrounds us every day, yet mathematics gives us the power to shape it. Cameras, microscopes, telescopes, eyeglasses, and even the human eye all rely on carefully curved lenses to focus light.\n\nThe path of light is governed by mathematical laws. In the lens formula, f is focal length, d_o is object distance, and d_i is image distance. A lens bends scattered rays so those distances satisfy a precise relationship, transforming light into a clear image.",
                formula: "1/f = 1/d_o + 1/d_i"
            ) { LensConceptVisual() }
        case 11:
            return LevelConcept(
                title: "Asking Better Questions",
                description: "Every day, we solve problems by asking questions that eliminate possibilities. Doctors narrow down a diagnosis through tests, engineers isolate faults in complex systems, and search algorithms quickly locate information by making the most informative comparisons.\n\nEvery weighing is a source of information. In the formula, k is the number of weighings, 3^k is the maximum number of outcome patterns because each weighing has three results, and n is the number of possibilities to distinguish. Better questions split uncertainty with maximum efficiency.",
                formula: "3^k ≥ n"
            ) { BalanceConceptVisual() }
        case 12:
            return LevelConcept(
                title: "Points & Paths",
                description: "Musical structure is built from relationships between notes. Composers connect tones through melody, harmony, and rhythm, choosing paths that create tension, resolution, and pattern.\n\nThis puzzle is an example of graph theory. In the formula, G is the graph, V is the set of vertices or points, and E is the set of edges or connections. Mathematics reveals that structure is not only found in numbers; it lives in relationships between points.",
                formula: "G = (V, E)"
            ) { GraphConceptVisual() }
        case 14:
            return LevelConcept(
                title: "Linear Functions",
                description: "Mountain faces, ramps, roads, and steady-speed journeys can all be modeled by straight lines. Each segment in this level has one constant steepness, so the same vertical change occurs for every equal horizontal step.\n\nA linear function is determined by its slope and vertical intercept. In the formula, m is the slope, x is the input, b is the value where the line crosses the y-axis, and y is the resulting height. Positive m rises from left to right, negative m falls, and a larger magnitude makes the line steeper.",
                formula: "y = mx + b      m = (y₂ − y₁) / (x₂ − x₁)"
            ) { LineEquationConceptVisual() }
        case 15:
            return LevelConcept(
                title: "The Harmony of Ratios",
                description: "Music and mathematics have been intertwined for more than two thousand years. Pythagoras discovered that harmonious musical notes arise from simple numerical ratios. Shortening a vibrating string changes the pitch it produces.\n\nA string's length determines how it vibrates. In the formula, f is frequency, L is string length, and the proportional symbol means frequency rises as length falls. Simple ratios create harmonious intervals because the vibrations align in elegant patterns.",
                formula: "f ∝ 1 / L"
            ) { StringRatioConceptVisual() }
        case 18:
            return LevelConcept(
                title: "Binary",
                description: "Every message you send, every website you visit, and every calculation your computer performs is built from tiny logical decisions. Modern electronics rely on circuits that evaluate simple statements as true or false.\n\nLogic circuits are the physical embodiment of Boolean algebra. In the formula, A and B are truth values, AND is true only when both are true, OR is true when at least one is true, and NOT flips true to false or false to true. From these rules emerge every computation.",
                formula: "A,B ∈ {0,1}    A AND B,  A OR B,  NOT A"
            ) { LogicConceptVisual() }
        case 19:
            return LevelConcept(
                title: "Sine Waves",
                description: "Sound, light, water, and vibration all move through repeating rises and falls. Sine waves model that smooth cycle from the midline upward, through a peak, back down, and around again.\n\nIn the formula, A is amplitude, f is frequency, t is time, and phi is phase shift. Amplitude controls height, frequency controls how often the wave repeats, and phase shifts the wave's timing:",
                formula: "y = A sin(2πft + φ)"
            ) { PrismConceptVisual() }
        case 21:
            return LevelConcept(
                title: "Number Sense",
                description: "Markets, banks, inventories, and measurement systems all depend on grouping quantities so large counts remain readable. Instead of treating 3,486 as thousands of separate objects, the decimal system compresses repeated groups of ten into higher place values.\n\nPlace value is the structure behind base-10 arithmetic. In the formula, d0 is the ones digit, d1 is the tens digit, d2 is the hundreds digit, and d3 is the thousands digit. Each place is worth ten times the place to its right, so carrying and borrowing are not tricks; they are exchanges between equal quantities.",
                formula: "N = d₃·1000 + d₂·100 + d₁·10 + d₀"
            ) { NumberSenseConceptVisual() }
        case 22:
            return LevelConcept(
                title: "Reflection Symmetry",
                description: "Symmetry appears throughout nature and human design. The wings of a butterfly, the petals of a flower, the human face, and the structure of crystals all exhibit balanced patterns.\n\nReflection symmetry is one of geometry's most fundamental transformations. In the formula, P is a point, P' is its reflected image, L is the mirror line, and d means distance. Reflection keeps both points the same distance from the mirror, preserving shape, size, and structure.",
                formula: "d(P, L) = d(P′, L)"
            ) { SymmetryConceptVisual() }
        case 23:
            return LevelConcept(
                title: "Networks, Paths & Music",
                description: "A network is defined by what is connected, not by whether it is drawn as a constellation or a rotating pyramid. In Stages 1–3, stars are vertices and stellar links are edges. In Stage 4, the pyramid's corners are vertices and each musical connection is an edge with its own pitch.\n\nAn Eulerian trail crosses every edge exactly once. It exists when a connected graph has exactly 0 or 2 odd-degree vertices, so the same structural rule guides both the flat star networks and the three-dimensional musical pyramid.",
                formula: "G = (V, E)   Euler trail ⇔ odd vertices = 0 or 2"
            ) { ConstellationConceptVisual() }
        case 24:
            return LevelConcept(
                title: "Open & Closed Boundaries",
                description: "Real life is full of boundary decisions: a ride may require a height greater than 48 inches, a coupon may apply to purchases of at least $25, and a temperature alert may trigger when heat reaches or exceeds a threshold. Inequalities let mathematics describe not just one value, but an entire allowed range.\n\nOn a number line, an open circle means the endpoint is not included, while a closed circle means the endpoint is included. In the formula, x is the value being tested, a is the boundary value, > means greater than but not equal to, and >= means greater than or equal to. The circle tells whether the boundary itself belongs to the solution set.",
                formula: "x > a   vs.   x ≥ a"
            ) { OpenClosedBoundaryConceptVisual() }
        case 25:
            return LevelConcept(
                title: "Absolute Value",
                description: "Navigation, elevation, finance, and measurement often care about magnitude before direction. A diver 6 meters below sea level and a drone 6 meters above sea level are in opposite directions, but both are 6 meters from sea level. Absolute value captures this idea of distance from a reference point.\n\nAbsolute value measures how far a number is from zero on the number line. In the formula, x is the original number, |x| is its distance from 0, and distance cannot be negative. That is why opposite numbers such as 5 and -5 have the same absolute value: they sit the same number of units away from zero.",
                formula: "|x| = distance from 0"
            ) { AbsoluteValueConceptVisual() }
        case 26:
            return LevelConcept(
                title: "The Harmonic Series",
                description: "Musical instruments create harmony through the mathematics of vibration. Guitar strings, violins, pianos, and even the human voice produce rich tones by vibrating in simple fractional patterns.\n\nA vibrating string naturally divides into equal fractions, creating harmonics. In the formula, f_n is the nth harmonic's frequency, n is the harmonic number, and f_1 is the fundamental frequency. Whole-number relationships become the foundation of music itself.",
                formula: "fₙ = n · f₁"
            ) { HarmonicConceptVisual() }
        case 27:
            return LevelConcept(
                title: "Self-Similarity",
                description: "Fractals appear throughout the natural world, from the branching of trees and rivers to the structure of lungs, blood vessels, and lightning. These intricate forms arise not from complicated instructions, but from simple rules repeated over and over.\n\nA fractal is a pattern that repeats at different scales. In the formula, shape_n is the current stage, shape_n+1 is the next stage, and f is the rule that transforms one stage into the next. Infinity can unfold from a single idea repeated without end.",
                formula: "shapeₙ₊₁ = f(shapeₙ)"
            ) { FractalConceptVisual() }
        case 29:
            return LevelConcept(
                title: "Divisors & Perfect Squares",
                description: "Many of the most powerful discoveries in mathematics come from looking for patterns hidden within simple rules. What first appears random can, through careful observation, uncover a deeper order that was there all along.\n\nThe locker problem reveals a property of divisors. In the formula, n is a locker number, k is an integer factor, and k^2 means k times itself. A locker remains open exactly when n is a perfect square, because square numbers have one unpaired divisor.",
                formula: "open ⇔ n = k²"
            ) { LockerConceptVisual() }
        case 30:
            return LevelConcept(
                title: "The Pythagorean Theorem",
                description: "Firefighters, construction crews, rescue teams, and surveyors all use right triangles when they need to reach something high from a safe distance. The ground distance and vertical height form the two legs; the ladder is the diagonal hypotenuse.\n\nThe Pythagorean theorem tells whether a ladder is long enough. In the formula, a and b are the perpendicular legs of a right triangle, and c is the hypotenuse. Solve for c, then round up to the next available ladder length so the ladder safely reaches the window.",
                formula: "a² + b² = c²"
            ) { DistanceConceptVisual() }
        case 31:
            return LevelConcept(
                title: "RSA Cryptography",
                description: "Encryption protects information by using mathematical operations that are easy to perform in one direction but difficult to reverse without a key. Multiplying two primes is immediate: 29 × 31 = 899. Recovering those factors from only the product requires testing possible divisors.\n\nPrime factorization reveals the hidden structure of a whole number. Every whole number greater than 1 has one unique prime product. Real cryptographic systems use primes vastly larger than the examples in this level, making reversal computationally demanding even though creating the product is straightforward.",
                formula: "public modulus: N = pq    easy: p,q → N    hard: N → p,q"
            ) { FactorConceptVisual() }
        case 32:
            return LevelConcept(
                title: "Volume",
                description: "Volume surrounds us in everyday life, from filling a water bottle and designing aquariums to storing fuel, constructing buildings, and measuring medicine. Mathematics transforms three-dimensional space into a quantity that can be measured with precision.\n\nVolume measures the amount of space enclosed by a three-dimensional object. In the formula, V is volume, l is length, w is width, and h is height. Three independent measurements combine to describe an entire region of space.",
                formula: "V = l × w × h"
            ) { VolumeConceptVisual() }
        case 34:
            return LevelConcept(
                title: "Exponential Growth",
                description: "A single seed can become a field. Forests regenerate from scattered seeds, populations grow through generations, and ideas spread from one person to another. Small beginnings, repeated over time, can produce extraordinary growth.\n\nThis level illustrates exponential growth. In the formula, N is the final population, N0 is the initial population, r is the growth factor per generation, and n is the number of generations. Because n sits in the exponent, repeated multiplication can turn a small beginning into abundance quickly.",
                formula: "N = N₀ · rⁿ"
            ) { ExponentialConceptVisual() }
        case 35:
            return LevelConcept(
                title: "Frequency & Form",
                description: "Graphs turn invisible relationships into visible form. Engineers use them to model signals, doctors read them in heartbeats and brain waves, and designers use curves to shape motion, sound, and animation.\n\nThis level explores parametric control within a function. In the formula, x is the horizontal input, y is the height of the graph, k controls the sine wave's frequency, 0.9 controls wave amplitude, and the square-root factor narrows the wave near the edge. One constant can reshape the pattern hidden inside the equation.",
                formula: "y = x^(2/3) + 0.9 sin(kx)√(3 - x²)"
            ) { FrequencyConceptVisual() }
        case 36:
            return LevelConcept(
                title: "The Least Common Multiple",
                description: "Machines run on synchronization. Car engines, clocks, factory equipment, and robotic systems all depend on gears rotating in perfect coordination.\n\nThis level explores the Least Common Multiple. In the formula, a and b are cycle lengths, and LCM(a,b) is the smallest positive number that both cycles divide evenly. It reveals when independent cycles become one again, uncovering the hidden moments when separate rhythms return to harmony.",
                formula: "sync time = LCM(a, b)"
            ) { GearConceptVisual() }
        case 37:
            return LevelConcept(
                title: "Permutations",
                description: "Every time a navigation app finds a route, a computer generates passwords, or scientists arrange DNA sequences, they are exploring different orders of the same objects. The number of possible arrangements grows astonishingly fast.\n\nA permutation is a unique ordering of a collection of objects. In the formula, n is the number of distinct items and n! means the factorial product of every positive whole number down to 1. For example, 3! = 6 because three items can be arranged in six different orders.",
                formula: "n! = n × (n - 1) × ... × 1"
            ) { PermutationConceptVisual() }
        case 38:
            return LevelConcept(
                title: "Vector Fields",
                description: "Every weather forecast, GPS route, magnetic compass, and fluid simulation depends on vector fields. Mathematics transforms invisible forces into maps that reveal both direction and strength.\n\nA vector field assigns a vector to every point in space. In the formula, F is the vector field, x and y are coordinates of a point, and the arrow over F means the output has both magnitude and direction. Rather than describing a single path, a vector field describes every possible local influence at once.",
                formula: "F⃗(x, y) = vector at each point"
            ) { VectorFieldConceptVisual() }
        case 39:
            return LevelConcept(
                title: "Topology",
                description: "Every object around us has a surface that can be explored. Understanding the geometry of a surface allows mathematics to describe how objects can be measured, navigated, and transformed in three dimensions.\n\nTopology studies surfaces by asking how they are connected rather than how large they are. In the formula, g is genus, the number of holes in a surface. A sphere has genus 0, while a torus has genus 1. Shape can stretch, but its number of holes stays topologically meaningful.",
                formula: "torus: g = 1"
            ) { TorusConceptVisual() }
        case 40:
            return LevelConcept(
                title: "The Balance Point",
                description: "Balance is essential wherever forces meet. Engineers design bridges so their weight is evenly distributed, cranes lift massive loads by finding the correct balance point, and robots constantly adjust their center of mass to remain stable.\n\nA balance point is determined by moments: force times distance from a pivot. In the formula, F1 and F2 are opposing forces, while d1 and d2 are their distances from the pivot. Equilibrium occurs when the two moments match.",
                formula: "F₁d₁ = F₂d₂"
            ) { LeverConceptVisual() }
        case 41:
            return LevelConcept(
                title: "Angles Give Structure",
                description: "Architecture, surveying, and computer graphics all rely on geometry to create structures that are both stable and precise. Complex designs begin with simple angle relationships.\n\nTriangles are governed by elegant geometric laws. In the formula, A, B, and C are the three interior angles of a triangle, and 180 degrees is the fixed total in Euclidean geometry. Shape is not arbitrary; it is constrained by immutable angle relationships.",
                formula: "A + B + C = 180°"
            ) { TriangleAnglesConceptVisual() }
        case 42:
            return LevelConcept(
                title: "Euclidean Rhythm",
                description: "Musical rhythms across many cultures spread a small number of beats as evenly as possible across a repeating cycle. A drum machine can create the same structure by placing pulses around a circular sequence of steps.\n\nA Euclidean rhythm distributes a chosen number of pulses among the available positions so the gaps differ by no more than one step. Listening to the loop makes that even spacing easier to recognize than a symbolic rule would."
            ) { MetronomeConceptVisual() }
        case 43:
            return LevelConcept(
                title: "Logic Gates",
                description: "Digital systems make billions of decisions every second using simple logical rules. Search queries, encrypted messages, apps, and processors rely on Boolean operations that combine true and false values.\n\nBoolean algebra shows that reasoning can be expressed mathematically. In the formula, A and B are truth values, AND requires both to be true, OR accepts either, and XOR is true when exactly one input is true. Complex computation grows from these simple rules.",
                formula: "A AND B,  A OR B,  A XOR B"
            ) { GateConceptVisual() }
        case 44:
            return LevelConcept(
                title: "Function Composition",
                description: "Machines and algorithms often solve problems by chaining simple operations together. Calculators, spreadsheets, factory systems, and computer programs all transform inputs step by step.\n\nThis level explores function composition. In the formula, x is the starting input, g is the first function applied, g(x) is its output, and f is the next function applied to that output. The order matters because different arrangements can produce different results.",
                formula: "(f ∘ g)(x) = f(g(x))"
            ) { CompositionConceptVisual() }
        case 45:
            return LevelConcept(
                title: "Value & Representation",
                description: "Money moves through the world by being divided, combined, and exchanged with precision. Every purchase, bank transaction, and financial system depends on representing the same value in different ways. Whether making exact change or optimizing payments, mathematics ensures that value is preserved even as its form changes.\n\nCurrency is really about integer partitions: any amount splits into different combinations of coins and bills that keep the same total. In the formula, V is the total value, each c_i is the count of a denomination, and each d_i is that denomination's value. Adding every count times its denomination gives the same quantity no matter how the money is represented:",
                formula: "V = c₁d₁ + c₂d₂ + ⋯ + cₙdₙ"
            ) { ChangeConceptVisual() }
        case 47:
            return LevelConcept(
                title: "Variables",
                description: "Balances, budgets, recipes, and measurements often contain a quantity that is not known yet. A variable gives that changing or unknown amount a name so it can be reasoned about before its value is discovered.\n\nIn this level, the bag represents x. The balance is level only when both sides have equal total weight. In the formula, a is the known weight beside the bag and b is the known weight on the opposite pan. Subtracting a from both sides isolates the unknown without breaking the equality.",
                formula: "x + a = b      x = b − a"
            ) { BalanceConceptVisual() }
        case 48:
            return LevelConcept(
                title: "Arithmetic Sequences",
                description: "Calendars, staircases, payment plans, and evenly spaced markers all grow by adding the same amount again and again. Once you know the starting value and the constant step, every future term is predictable.\n\nAn arithmetic sequence has a common difference. In the formula, a_n is the nth term, a_1 is the first term, n is the term number, and d is the amount added each step. The line of terms advances by equal jumps:",
                formula: "aₙ = a₁ + (n − 1)d"
            ) { SequenceConceptVisual() }
        case 49:
            return LevelConcept(
                title: "Slope",
                description: "Maps, navigation systems, architecture, and computer graphics all rely on slope to describe direction. Rather than measuring a line by its length alone, mathematics captures how it changes horizontally and vertically, allowing shapes to be reproduced exactly no matter where they are drawn. A single ratio is enough to preserve both direction and form.\n\nSlope is the mathematical language of inclination. In the formula, m is the slope, delta y is the vertical change or rise, and delta x is the horizontal change or run. That ratio represents an entire family of parallel lines sharing the same direction, whatever their size or position:",
                formula: "m = Δy / Δx"
            ) { SlopeConceptVisual() }
        case 50:
            return LevelConcept(
                title: "Inequalities",
                description: "Every day, systems compare quantities to make decisions. Traffic lights check whether enough time has passed before changing, online stores check whether inventory is greater than zero before allowing a purchase, and banking systems verify whether a balance is sufficient to complete a transaction. Inequality symbols give mathematics a precise language for these comparisons.\n\nAn inequality expresses the relationship between two values without requiring equality. In the displayed comparisons, a and b are quantities being compared; < means less than, > means greater than, <= means less than or equal to, and >= means greater than or equal to. These symbols partition the number line into regions of possibility:",
                formula: "a < b     a > b     a ≤ b     a ≥ b"
            ) { InequalityConceptVisual() }
        case 51:
            return LevelConcept(
                title: "Linear Inequalities",
                description: "Every day, inequalities define boundaries that determine what is allowed and what is not. Navigation apps identify locations within a destination zone, weather alerts activate when temperatures exceed a threshold, and autonomous systems classify objects by whether they lie inside or outside safe operating regions. These decision boundaries let complex systems separate possibilities with simple mathematical rules.\n\nIn coordinate geometry, an inequality describes an entire region of the plane. In the formula, x and y are point coordinates, m is the boundary line's slope, and b is its y-intercept. The > symbol keeps the points whose y-value is greater than the line's value at that x, selecting one side of the boundary:",
                formula: "y > mx + b"
            ) { HalfPlaneConceptVisual() }
        case 52:
            return LevelConcept(
                title: "The Equation of a Line",
                description: "Every day, straight-line relationships help systems predict movement and connect locations. Robotic arms move along linear paths to reach precise coordinates, computer graphics use lines to connect points when rendering shapes, and engineering software models structures with linear equations for accurate positioning. These applications rely on equations that describe how one variable changes in relation to another.\n\nIn coordinate geometry, a line is defined by an equation. In the formula, x is the input coordinate, y is the output coordinate, m is the slope that controls steepness, and b is the y-intercept where the line crosses the vertical axis. Two distinct points determine exactly one unique line:",
                formula: "y = mx + b"
            ) { LineEquationConceptVisual() }
        case 53:
            return LevelConcept(
                title: "Derivatives",
                description: "A flock reveals derivatives as motion rather than static notation. Each bird has a position x(t). Its velocity is the rate at which position changes, and acceleration is the rate at which velocity changes. Curved flight appears because velocity is continuously changing.\n\nSeparation, alignment, and cohesion act as steering forces. Together they create acceleration, acceleration updates velocity, and velocity updates position:",
                formula: "v(t) = dx/dt    a(t) = dv/dt"
            ) { FlockingConceptVisual() }
        case 54:
            return LevelConcept(
                title: "Halving",
                description: "Splitting things in half is everywhere: sharing a bill, cutting a recipe, or a computer running a binary search that discards half the possibilities with every guess. Halving a large problem again and again is one of the fastest ways to reach an answer.\n\nEach split leaves exactly half of what remained. In the formula, each 1/2 represents one equal half of the same whole, the plus sign recombines the parts, and 1 represents the complete original unit. Two equal halves always rebuild the whole:",
                formula: "½ + ½ = 1"
            ) { SplitConceptVisual() }
        case 55:
            return LevelConcept(
                title: "Tessellations",
                description: "Tiled floors, brick walls, honeycombs, and the textures in video games are all tessellations—shapes repeated to cover a surface with no gaps and no overlaps. Nature and design both reach for them because they are efficient and strong.\n\nA shape tessellates when copies fit together perfectly around every point. In the formula, angles at a vertex means all corner angles that meet at one shared point, and 360 degrees is one full turn around that point. If the angles total less or more, gaps or overlaps appear:",
                formula: "angles at a vertex = 360°"
            ) { TessellationConceptVisual() }
        case 56:
            return LevelConcept(
                title: "Nets & Solids",
                description: "Every cardboard box, package, and paper model begins as a flat net that folds into a three-dimensional solid. Engineers and designers move between the flat pattern and the finished shape to plan material, strength, and assembly.\n\nA net is a two-dimensional unfolding of a solid's faces. In Euler's formula, V is the number of vertices, E is the number of edges, and F is the number of faces of a convex polyhedron. No matter how the solid is shaped, this relationship between its parts stays fixed:",
                formula: "V − E + F = 2"
            ) { NetFoldConceptVisual() }
        case 57:
            return LevelConcept(
                title: "Transformations",
                description: "Computer graphics, robotics, and animation constantly move and orient shapes using transformations. Every character that walks, every rotated photo, and every mirrored reflection is a geometric transformation applied with precision.\n\nA rigid transformation changes position or orientation without changing size or form. In the formula, d means distance, A and B are two original points, and T(A), T(B) are their transformed images. An isometry preserves the distance between points.",
                formula: "d(T(A), T(B)) = d(A, B)"
            ) { TransformConceptVisual() }
        case 58:
            return LevelConcept(
                title: "Area and Perimeter",
                description: "Fencing a garden, tiling a floor, framing a picture, and buying materials all come down to area and perimeter. One measures the space inside a shape; the other measures the boundary around it.\n\nFor a rectangle, A is area, P is perimeter, l is length, and w is width. Area multiplies length by width to measure interior coverage, while perimeter adds all four side lengths, written as twice the sum of length and width:",
                formula: "A = l × w      P = 2(l + w)"
            ) { GardenConceptVisual() }
        case 59:
            return LevelConcept(
                title: "The Coordinate Plane",
                description: "GPS, maps, phone screens, and video games locate everything with coordinates. Two numbers are enough to pinpoint any position, direct a delivery, or place a pixel exactly where it belongs.\n\nAn ordered pair fixes a point. In the formula, x measures horizontal position along the left-right axis, y measures vertical position along the up-down axis, and the parentheses keep the two coordinates together as one location:",
                formula: "(x, y)"
            ) { CoordinateConceptVisual() }
        case 60:
            return LevelConcept(
                title: "Pattern & Recall",
                description: "Studying, remembering faces, and the caches inside every computer all rely on memory: storing information and retrieving it the moment it's needed. Fast, accurate recall is what makes both minds and machines efficient.\n\nMatching games train recognition by asking you to retain both an object's identity and its location. Organized patterns reduce the amount of information the mind must hold at once, making accurate recall faster."
            ) { MemoryConceptVisual() }
        case 61:
            return LevelConcept(
                title: "Perspective",
                description: "Renaissance painters, camera lenses, and 3D game engines all use perspective to turn depth into a flat image. Parallel roads and hallways appear to shrink and meet at a single point on the horizon.\n\nPerspective projection maps a 3D point onto the screen by dividing by its depth. In the formula, X is the original horizontal position in space, Z is depth or distance from the viewer, f is focal length, and x' is the projected screen position. Greater Z makes the projected result smaller:",
                formula: "x′ = f · X / Z"
            ) { PerspectiveConceptVisual() }
        case 62:
            return LevelConcept(
                title: "Distance & Coordinates",
                description: "Radar, GPS targeting, and the game Battleship all locate objects on a grid and measure how far apart they are. Coordinates turn 'where' and 'how far' into pure calculation.\n\nThe straight-line distance between two points comes from the Pythagorean theorem. In the formula, d is the distance, x1 and y1 are the first point's coordinates, and x2 and y2 are the second point's coordinates. The coordinate differences form the legs of a right triangle, and d is its hypotenuse:",
                formula: "d = √((x₂−x₁)² + (y₂−y₁)²)"
            ) { DistanceConceptVisual() }
        case 63:
            return LevelConcept(
                title: "Scale & Similarity",
                description: "Maps, architectural blueprints, and scale models all shrink the real world onto a page while keeping every proportion intact. A single scale factor connects the model to reality.\n\nSimilar figures have the same shape but different size. In the formula, k is the linear scale factor: every length is multiplied by k, every area by k squared because it has two dimensions, and every volume by k cubed because it has three dimensions:",
                formula: "length ×k,  area ×k²,  volume ×k³"
            ) { ScaleConceptVisual() }
        case 64:
            return LevelConcept(
                title: "State-Space Search",
                description: "Sliding-tile puzzles, robot motion planning, and navigation apps all search through possible moves to get from a start to a goal. The challenge isn't one move but finding the right sequence.\n\nEach configuration is a state and each move is an edge to a neighboring state, so solving the puzzle is a search through a graph. In the formula, states is the approximate number of reachable configurations, b is the branching factor or average number of choices per move, and d is search depth. Possibilities grow exponentially with depth:",
                formula: "states ≈ bᵈ"
            ) { StateGraphConceptVisual() }
        case 65:
            return LevelConcept(
                title: "Tempo & Frequency",
                description: "Music, clocks, engines, and animation all run on a steady beat. Tempo sets how quickly events repeat, keeping performers—and machines—in sync.\n\nTempo in beats per minute is tied to period and frequency. In the formula, BPM is beats per minute, T is the time for one beat in seconds, and f is frequency in beats per second. Dividing 60 by T converts seconds per beat into beats per minute, while f is the reciprocal of T:",
                formula: "BPM = 60 / T      f = 1 / T"
            ) { MetronomeConceptVisual() }
        case 66:
            return LevelConcept(
                title: "Phase",
                description: "Noise-cancelling headphones, radio transmission, and audio mixing all depend on the phase of a wave—how far it is shifted in time relative to another. Small shifts can reinforce a sound or erase it entirely.\n\nIn the sinusoid formula, y is the wave value, A is amplitude, f is frequency, t is time, and phi is phase shift. The 2π factor converts cycles into radians. Two identical waves a half-cycle apart cancel, while waves in phase reinforce:",
                formula: "y = A·sin(2πft + φ)"
            ) { PhaseConceptVisual() }
        case 67:
            return LevelConcept(
                title: "The Envelope (ADSR)",
                description: "Every synthesizer and sampled instrument shapes how a note's loudness rises and falls over time. It's the difference between a sharp plucked string and a slowly swelling pad.\n\nThe ADSR envelope controls amplitude in four stages: attack, decay, sustain, and release. In the formula, output is the heard signal, envelope(t) is the loudness multiplier at time t, sin(2πft) is the raw tone, and f is frequency. The envelope shapes the tone over time:",
                formula: "output = envelope(t) · sin(2πft)"
            ) { EnvelopeConceptVisual() }
        case 68:
            return LevelConcept(
                title: "Periodic Functions",
                description: "A periodic function repeats the same output pattern after a fixed horizontal interval called the period T. Sine waves model smooth oscillation, while square waves switch abruptly between two states. Triangle waves rise and fall at constant rates, and sawtooth waves repeatedly ramp before resetting.\n\nTheir shapes differ, but every point reappears one period later. In the formula, x is any input and T is the smallest positive repeat interval. Amplitude controls vertical size, while frequency is the number of periods completed per unit of input.",
                formula: "f(x + T) = f(x)    frequency = 1/T"
            ) { PeriodicWaveFamilyConceptVisual() }
        case 69:
            return LevelConcept(
                title: "Cosine Waves",
                description: "Sound waves, ocean swells, alternating current, and smooth animation all rise and fall in repeating cycles. Cosine is one of the cleanest ways to describe that motion because it starts at a peak and repeats with steady rhythm.\n\nIn the formula, A is amplitude, f is frequency, t is time, and phi is phase shift. Amplitude controls height, frequency controls how tightly the wave repeats, and phase slides the wave left or right:",
                formula: "y = A cos(2πft + φ)"
            ) { UpdraftConceptVisual() }
        case 70:
            return LevelConcept(
                title: "Harmony & Chords",
                description: "Musicians, piano tuners, and audio engineers build chords by sounding notes together whose frequencies line up in simple ratios. The ear hears these ratios as consonance.\n\nThe most consonant intervals come from small whole-number frequency ratios. In each ratio, the first number is the higher note's frequency proportion and the second is the lower note's. An octave at 2:1 means one frequency is double the other; a fifth at 3:2 and a third at 5:4 are similarly compact relationships:",
                formula: "octave 2:1    fifth 3:2    third 5:4"
            ) { ChordConceptVisual() }
        case 71:
            return LevelConcept(
                title: "Echoes & Reflection",
                description: "Sonar, radar, ultrasound scans, and bats all locate objects by sending out a pulse and timing the echo that bounces back. The delay is a hidden ruler.\n\nSound travels at a fixed speed. In the formula, d is the one-way distance to the reflecting surface, v is wave speed, and t is the measured round-trip time for the echo to leave and return. Dividing by 2 converts the round trip into the actual distance:",
                formula: "d = v · t / 2"
            ) { EchoConceptVisual() }
        case 72:
            return LevelConcept(
                title: "Wave Interference",
                description: "Noise-cancelling headphones, the shimmering colors of soap films, and ripples crossing a pond all show interference—what happens when waves overlap.\n\nBy the principle of superposition, overlapping waves add point by point. In the formula, y is the combined displacement at a point, y1 is the displacement from the first wave, and y2 is the displacement from the second wave. Same-sign displacements reinforce; opposite signs cancel:",
                formula: "y = y₁ + y₂"
            ) { InterferenceConceptVisual() }
        case 73:
            return LevelConcept(
                title: "Doppler Effect",
                description: "Police radar guns, weather radar, passing ambulance sirens, and the redshift of distant galaxies all read motion through the Doppler effect. Movement changes the frequency you observe.\n\nA source moving toward you squeezes its waves together, raising the pitch; moving away stretches them, lowering it. In the formula, f' is observed frequency, f is emitted frequency, v is wave speed, and v_s is source speed. The minus or plus sign depends on whether the source moves toward or away:",
                formula: "f′ = f · v / (v ∓ vₛ)"
            ) { DopplerConceptVisual() }
        case 74:
            return LevelConcept(
                title: "The Circle of Fifths",
                description: "Composers and songwriters use the circle of fifths to find keys, chords, and progressions that naturally sound good together—a map of musical relationships.\n\nStacking perfect fifths means multiplying frequency by 3/2 again and again. In the formula, (3/2)^12 means twelve perfect fifths, and 2^7 means seven octaves, each doubling frequency. Their near equality explains why twelve-tone tuning loops so neatly:",
                formula: "(3/2)¹² ≈ 2⁷"
            ) { CircleOfFifthsConceptVisual() }
        case 75:
            return LevelConcept(
                title: "The Harmonic Series",
                description: "The unique timbre of a violin, a flute, or a human voice comes from overtones—and additive synthesizers rebuild those sounds by stacking them deliberately.\n\nA vibrating string or air column resonates not just at its fundamental but at every whole-number multiple of it. In the formula, f_n is the frequency of the nth harmonic, n is the harmonic number, and f_1 is the fundamental frequency. Higher harmonics are integer multiples of the first:",
                formula: "fₙ = n · f₁"
            ) { HarmonicLadderConceptVisual() }
        case 76:
            return LevelConcept(
                title: "Recursion",
                description: "Recursion powers file systems, fractal graphics, and divide-and-conquer algorithms—solving a large problem by solving smaller copies of the same problem.\n\nThe Towers of Hanoi has an exact move count. In the formula, moves is the minimum number of legal moves required, n is the number of disks, 2^n captures the doubling caused by recursion, and subtracting 1 accounts for the final structure of the recursive sequence:",
                formula: "moves = 2ⁿ − 1"
            ) { HanoiConceptVisual() }
        case 77:
            return LevelConcept(
                title: "Rotation Matrices",
                description: "Every 3D game, robot arm, and graphics engine turns objects using matrices—compact rules that transform whole sets of coordinates at once.\n\nA 2-by-2 rotation matrix turns any point about the origin. In the displayed matrix, theta is the rotation angle, cos theta controls how much of each coordinate stays aligned with its original axis, and sin theta controls how much rotates into the other axis. The signs determine clockwise versus counterclockwise mixing:",
                formula: "[cos θ  −sin θ ;  sin θ  cos θ]"
            ) { MatrixRotationConceptVisual() }
        case 78:
            return LevelConcept(
                title: "Partial Derivatives",
                description: "When a function depends on multiple variables, each input can influence the output differently. A partial derivative measures how the output changes as one variable changes while every other variable is held constant.\n\nOn the level's surface, moving x while keeping y fixed reveals the slope in the x-direction, ∂f/∂x. Moving y while keeping x fixed reveals the slope in the y-direction, ∂f/∂y. Together, these directional rates describe the surface's local change.",
                formula: "∂f/∂x = lim[h→0] (f(x+h,y)−f(x,y))/h\n∂f/∂y = lim[h→0] (f(x,y+h)−f(x,y))/h"
            ) { PartialDerivativesConceptVisual() }
        case 79:
            return LevelConcept(
                title: "Polar Coordinates",
                description: "A point on the frozen lake is reached with two movement instructions. First rotate from the positive horizontal axis by angle theta, then travel outward r units from the center pole. Radius rings measure distance while spokes measure direction.\n\nNegative angles rotate clockwise. A negative radius reverses the travel direction, so different-looking coordinates can identify the same fish. Cartesian coordinates are the horizontal and vertical projections of the same polar movement:",
                formula: "x = r cos(θ)    y = r sin(θ)"
            ) { PolarRadarConceptVisual() }
        case 80:
            return LevelConcept(
                title: "Parametric Equations",
                description: "A parametric curve gives both coordinates as functions of one shared parameter. For 0 ≤ t ≤ 12π, let B(t) = e^(cos t) − 2cos(4t) − sin⁵(t/12). The butterfly is drawn by x(t) = sin(t)B(t) and y(t) = cos(t)B(t), pairing two coordinates at every value of t.\n\nThe same curve has the polar form r = e^(sin θ) − 2cos(4θ) + sin⁵((2θ − π)/24). Both descriptions repeatedly change the point's distance and direction, producing the nested wings:",
                formula: "x(t) = sin(t)[e^(cos t) − 2cos(4t) − sin⁵(t/12)]\ny(t) = cos(t)[e^(cos t) − 2cos(4t) − sin⁵(t/12)]\nr(θ) = e^(sin θ) − 2cos(4θ) + sin⁵((2θ − π)/24)"
            ) { ParametricDroneConceptVisual() }
        case 81:
            return LevelConcept(
                title: "Logic Grids",
                description: "Nonograms, constraint solvers, and even simple image formats encode pictures as numbers that describe runs of filled cells. The puzzle is pure deduction, not guessing.\n\nEach clue lists the lengths of consecutive filled blocks in a line. In the formula, placements is the number of possible starting positions for a run, n is the number of cells in the line, and k is the run length. Subtracting k from n leaves the slack, and adding 1 counts every possible offset:",
                formula: "placements = n − k + 1"
            ) { NonogramConceptVisual() }
        case 82:
            return LevelConcept(
                title: "Constraint Puzzles",
                description: "Logistics, scheduling, and AI planning all work toward a goal while never breaking the rules, like ferrying items across a river without ever leaving a dangerous pair alone together.\n\nEach safe arrangement is a state and each legal move is an edge between states. In the formula, S is the set of all possible states, F is the forbidden subset, and valid states are those in S but not in F. Solving means finding a path through valid states only.",
                formula: "valid states = S - F"
            ) { RiverConceptVisual() }
        case 83:
            return LevelConcept(
                title: "Flow & Capacity",
                description: "Water reservoirs, power grids, and the buffers inside every computer all balance what flows in against what flows out to avoid overflowing or running dry.\n\nThe change in a reservoir's contents over time is inflow minus outflow. In the formula, delta V is the change in stored volume, r_in is the inflow rate, r_out is the outflow rate, and t is elapsed time. Positive difference fills the reservoir; negative difference drains it:",
                formula: "ΔV = (r_in − r_out) · t"
            ) { ReservoirConceptVisual() }
        case 84:
            return LevelConcept(
                title: "Rates of Change",
                description: "A snowboarder's height changes over time as the rider climbs and descends a curved slope. The tangent line measures the instantaneous rate of change. On the climb its slope is positive, at the highest point it is horizontal, and on the descent it is negative.\n\nFor h(t) = 60 − (20/3)(t − 3)², the derivative gives the slope at every instant. At the vertex t = 3, the derivative is zero even though the snowboarder is at maximum height:",
                formula: "h′(t) = −(40/3)(t − 3)    h′(3) = 0"
            ) { SnowboardRateConceptVisual() }
        case 85:
            return LevelConcept(
                title: "Covering & Optimization",
                description: "Placing cell towers, fire stations, or storm shelters so everyone is within reach is a coverage problem—protect the most people using the fewest resources.\n\nEach shelter covers everything within a radius. In the formula, covered means the point is protected, d is its distance to the nearest shelter, r is the shelter's coverage radius, and <= means the point lies inside or on the boundary of the coverage circle:",
                formula: "covered ⟺ d ≤ r"
            ) { CoverageConceptVisual() }
        case 86:
            return LevelConcept(
                title: "Gradient Descent",
                description: "A sheepdog cannot move an entire flock into its pens in one step. Instead, each local push should reduce an objective: the total error between every sheep's current position and the center of its matching pen. The field improves through many small corrections rather than one perfect move.\n\nGradient descent follows the same strategy. The gradient points toward the direction of greatest increase in error, so moving in the opposite direction lowers the loss. In the formula, L is the loss, theta represents the current controls, eta is the step size, and each update searches for a lower value of L:",
                formula: "θₖ₊₁ = θₖ − η∇L(θₖ)"
            ) { HerdingConceptVisual() }
        case 87:
            return LevelConcept(
                title: "Ant Colony Optimization",
                description: "Network routing, delivery logistics, and telecom systems borrow a trick from ants: they discover short paths using trails, with no central planner in charge.\n\nAnts deposit pheromone as they travel, and shorter paths get reinforced faster because ants finish them sooner. In the formula, P(path) is the probability of choosing a route, the proportional symbol means it increases with, and pheromone is the accumulated trail strength on that route:",
                formula: "P(path) ∝ pheromone"
            ) { AntTrailConceptVisual() }
        case 88:
            return LevelConcept(
                title: "Differential Equations",
                description: "Predator-prey populations are modeled by a coupled system of differential equations. The current sheep and fox populations determine both instantaneous rates of change, and those changing rates continuously produce the next population state. The result is a repeating rise-and-fall cycle rather than a fixed scripted animation.\n\nIn the Lotka-Volterra model, prey grow at rate αx but are removed through encounters βxy. Predators decline at rate γy but reproduce through encounters δxy. Because each derivative depends on both populations, changing one birth-rate parameter reshapes the future motion of the entire ecosystem.",
                formula: "dx/dt = αx − βxy    dy/dt = δxy − γy"
            ) { PopulationConceptVisual() }
        case 89:
            return LevelConcept(
                title: "Standing Waves",
                description: "Instrument design, concert-hall acoustics, and Chladni's vibrating plates all reveal standing waves—vibrations that freeze into fixed patterns of motion and stillness.\n\nWhen waves reflect and overlap on a plate, they form nodal lines where the surface barely moves. In the formula, amplitude is vertical vibration size, x and y are positions on the plate, m and n are mode numbers, pi sets the wave period, and the sine factors create stationary nodal patterns:",
                formula: "amplitude = sin(mπx) · sin(nπy)"
            ) { ChladniConceptVisual() }
        case 90:
            return LevelConcept(
                title: "The Knight's Tour",
                description: "Route planning, circuit layout, and coverage problems all ask a version of the same question: can you visit every location exactly once?\n\nA knight's tour crosses every square of a board once using only legal knight moves. In graph theory this is a Hamiltonian path: each square is a vertex, each possible knight move is a connection, and a successful route visits every vertex without repeating one."
            ) { KnightConceptVisual() }
        case 91:
            return LevelConcept(
                title: "Shortest Paths",
                description: "Navigation systems, packet routing, robotics, and logistics all depend on one central question: which route is truly cheapest once every connection has its own cost? The answer is not always the path with the fewest steps, because distance, risk, time, and capacity can all be encoded as edge weights.\n\nDijkstra's algorithm works by growing a region of certainty. At each step, the closest unsettled node becomes permanent because every other possible route to it would have to pass through an even more expensive frontier. In the formula, dist[v] is the best known cost to reach node v, dist[u] is the confirmed cost to a neighboring node u, and w is the weight of the edge from u to v. The min operation keeps whichever route is cheaper.",
                formula: "dist[v] = min(dist[v], dist[u] + w)"
            ) { DijkstraConceptVisual() }
        case 92:
            return LevelConcept(
                title: "Sorting Networks",
                description: "High-performance hardware and parallel computing need sorting methods whose comparisons are scheduled before the data is even known. A sorting network does exactly that: it fixes the comparison pattern in advance, allowing many comparisons to happen at once.\n\nBitonic sort repeatedly compares paired values, separates them into smaller groups, and applies the same visual network again. No single equation is the lesson here; the mathematical object is the fixed network of comparisons and the order it guarantees."
            ) { BitonicConceptVisual() }
        case 93:
            return LevelConcept(
                title: "3D Coordinates",
                description: "A location in three-dimensional space needs three measurements. The x-coordinate moves left or right, y moves down or up, and z moves backward or forward through the layers. The center block is the origin (0,0,0), and the surrounding blocks use −1, 0, or 1 on each axis.\n\nEvery tic-tac-toe move therefore selects a coordinate triple. Three blocks form a winning line when their triples advance by one consistent direction vector through the cube:",
                formula: "P = (x, y, z)    x,y,z ∈ {−1,0,1}"
            ) { CubeGameConceptVisual() }
        case 94:
            return LevelConcept(
                title: "Right Triangle Applications",
                description: "A right triangle contains one 90° angle. The two sides that meet there are the legs, a and b; the side opposite the right angle is the hypotenuse, c. Their lengths always satisfy the Pythagorean theorem: a² + b² = c². A 3–4–5 triangle is the classic example because 3² + 4² = 5².\n\nAt every pinball bounce, the incoming and outgoing path segments are perpendicular. Treat those segments as the two legs, connect their endpoints to form the hypotenuse, and each turn becomes a right triangle that can be measured.",
                formula: "a² + b² = c²   where ∠C = 90°"
            ) { PinballMemoryConceptVisual() }
        case 95:
            return LevelConcept(
                title: "Conservation of Angular Momentum",
                description: "Gymnasts, divers, and figure skaters change how fast they spin without any push — just by changing their shape. Pulling into a tight tuck whips a gymnast around faster; opening into a layout slows the rotation for a clean, feet-first landing. Satellites and robots reorient using the very same principle with spinning wheels.\n\nIn free flight the only force is gravity, which acts through the center of mass and so cannot change the body's spin — angular momentum is conserved. In the formula, L is angular momentum, I is the moment of inertia (how far the mass is spread from the spin axis), and ω is the spin rate. Since L stays constant, shrinking I by tucking forces ω to rise, while extending the body raises I and slows the spin.",
                formula: "L = Iω = constant"
            ) { AngularMomentumConceptVisual() }
        case 96:
            return LevelConcept(
                title: "Area and Volume",
                description: "Area measures the two-dimensional space inside a boundary in square units. A rectangle's area is its length multiplied by its width, so each numbered region on the flat grid must cover exactly that many unit squares without gaps or overlaps.\n\nVolume extends the same idea into three dimensions and counts cubic units. Multiplying a rectangular prism's length, width, and height tells how many unit cubes fill it. The stages move from partitioning flat area to filling solid volume, revealing how an added dimension changes the measurement.",
                formula: "A = l × w      V = l × w × h"
            ) { ExactCoverConceptVisual() }
        case 97:
            return LevelConcept(
                title: "Convex Hulls",
                description: "Mapping, collision detection, data visualization, and computer vision often begin by asking for the outer boundary of scattered points. The convex hull is the tightest convex envelope that contains them all, like stretching a band around a set of pins.\n\nA point belongs to the hull when it helps define an extreme direction. In the formula, P is the original set of points, hull(P) is the boundary shape produced from those points, and smallest convex set means the tightest shape that contains every point while never bending inward.",
                formula: "hull(P) = smallest convex set containing P"
            ) { ConvexHullConceptVisual() }
        case 98:
            return LevelConcept(
                title: "Modular Elimination",
                description: "The Josephus problem turns survival into arithmetic on a circle. It appears in scheduling, cyclic buffers, tournament elimination, and any process where positions are repeatedly removed while counting wraps around.\n\nAfter each removal, the circle shrinks and the starting point shifts. In the formula, J(n,k) is the safe position with n people when every kth person is removed, J(n-1,k) is the safe position after one person has been removed, + k rotates the answer by the step size, and mod n wraps the position back around the circle.",
                formula: "J(n,k) = (J(n-1,k) + k) mod n"
            ) { JosephusConceptVisual() }
        case 99:
            return LevelConcept(
                title: "Coming Soon",
                description: "Level 99 is reserved for a future mathematical experience.",
                formula: ""
            ) { Color.clear }
        case 100:
            return LevelConcept(
                title: "Probability",
                description: "An ant cemetery is a probability-driven clustering model. Each ant follows local rules rather than a shared plan: it is more likely to pick up an isolated item and more likely to drop a carried item where nearby items already form a cluster. Repeating those uncertain choices creates organized piles from a scattered field.\n\nWorkers change how many independent trials occur at once, while pheromone strength changes how strongly local density influences each decision. The final pattern is not scripted; it emerges from many small random events whose probabilities depend on the ants' immediate surroundings.",
                formula: "P(drop | density) ↑ as local density ↑"
            ) { SelfOrganizingConceptVisual() }
        case 101:
            return LevelConcept(
                title: "The Number System",
                description: "Every calculator, computer, and measuring instrument must know what kind of number it holds. Counting inventory uses whole numbers, temperatures and debts need negatives, money and measurements use fractions and decimals, physics leans on irrational constants like π, and electronics, signal processing, and quantum mechanics run on complex numbers. Choosing the right kind of number is the first step in modeling anything real.\n\nThe number system is built outward in nested sets, each containing the last. The naturals ℕ count; adding their opposites gives the integers ℤ; ratios of integers give the rationals ℚ; filling the gaps between them with unending, non-repeating values like √2 and π completes the reals ℝ; and admitting i = √−1 extends everything to the complex numbers ℂ. In the formula, ⊂ means 'is contained in' — each world of numbers is a wider sky holding the one before it.",
                formula: "ℕ ⊂ ℤ ⊂ ℚ ⊂ ℝ ⊂ ℂ"
            ) { NumberSystemConceptVisual() }
        case 17:
            return LevelConcept(
                title: "Congruence",
                description: "Congruence is why the modern world fits together. Factories stamp out millions of identical car parts, bolts and phone screens so any one can replace any other; a broken watch gear swaps for a new one because the two are congruent. Forensic examiners match a shoe print to the shoe that made it, quality inspectors lay a template over a machined part to check it, and a key opens a lock only when its cut pattern is congruent to the one the lock expects.\n\nThat's how a paleontologist reads a trackway: footprints scattered across the rock at different spots and angles, even mirrored left-for-right, all came from the same foot if a transparent tracing of one can cover each of the others. A print that's too big or too small can never be covered — it may be similar, but it is not congruent.",
                formula: "≅  ⟺  translate ∘ rotate ∘ reflect"
            ) { FootprintCongruenceConceptVisual() }
        case 33:
            return LevelConcept(
                title: "The Mathematics of Folding",
                description: "Origami runs on theorems. Around any vertex that folds flat, Maekawa's theorem forces the number of mountain and valley creases to differ by exactly 2, and Kawasaki's theorem forces the alternating angles to sum to 180°. The crane obeys both — its crease pattern is built almost entirely from the angle 22.5° (a right angle folded in half twice), which is why lengths like √2 and 1 + √2 appear in the paper (tan 22.5° = √2 − 1).\n\nThis is engineering, not just art: fold mathematics packs solar arrays and airbags, designs unfoldable stents and telescope mirrors, and connects flat patterns to higher-dimensional lattices — a crane's crease pattern can be read as the shadow of a hypercube.",
                formula: "|M − V| = 2   ·   Σ alt. angles = 180°   ·   tan 22.5° = √2 − 1"
            ) { OrigamiFoldConceptVisual() }
        case 102:
            return LevelConcept(
                title: "Sowing & Counting",
                description: "Mancala is one of humanity's oldest games, played for thousands of years across Africa and Asia with seeds and hollows in the ground. Beneath the simple sowing lies real strategy: it teaches counting, planning several moves ahead, and reasoning about a whole system of moving parts — the same skills computers use to master games, plan logistics, and search through possibilities.\n\nEach move is modular arithmetic in disguise. Sowing s stones one per cup around a loop of 13 cups (your six pits, your store, and the opponent's six pits) lands the final stone at position (start + s) mod 13. Extra turns and captures make it a combinatorial game: a finite tree of positions whose best line of play can be found by searching that tree — which is exactly how Kalah was solved by computer.",
                formula: "end ≡ start + s (mod 13)"
            ) { MancalaConceptVisual() }
        case 103:
            return LevelConcept(
                title: "Expressions",
                description: "A mathematical expression is built by combining quantities with operation symbols. A number such as 2 is a constant, x is a variable that can represent different values, and symbols such as + and × tell how those quantities are combined. Unlike an equation, an expression does not claim that two sides are equal.\n\nParentheses create a group and control which operation is performed first. In (x + 2) × 2, first add 2 to x, then multiply the entire group by 2. Changing the order or removing the grouping creates a different expression and can produce a different value.",
                formula: "(x + 2) × 2"
            ) { ExpressionBuilderConceptVisual() }
        case 104:
            return LevelConcept(
                title: "One-Step Equations",
                description: "An equation is a balance: whatever the two sides read, they must stay equal. Solving for an unknown means undoing whatever was done to it — move exactly enough to make both sides match. A single operation to isolate x is a one-step equation, the atom every longer equation is built from.\n\nHere two equal cylinders tell the story. The left is full at 5 litres; the right already holds 2, and its empty space is x: x + 2 = 5. Pump 3 litres across and the right fills to the top, so x = 3. The same move solves x − 4 = 1 (add 4) or 3x = 12 (divide by 3): apply one inverse operation to both sides and the unknown stands alone.",
                formula: "x + 2 = 5  ⟹  x = 3"
            ) { CylinderConceptVisual() }
        case 105:
            return LevelConcept(
                title: "Multi-Step Equations",
                description: "Many real measurements are the result of several transformations applied in sequence. A glacier's observed thickness is not just its starting thickness: snowfall adds material, melting removes a fraction of what exists, and later accumulation can add more material. Algebra records that history as a chain of operations.\n\nIn the equation (x + 3) / 2 + 4 = 12, x is the glacier's original thickness, +3 is the first snowfall, division by 2 represents summer melting the glacier to half its height, +4 is later snowfall, and 12 is the measured final thickness. Solving means finding the starting value whose full chain lands on the target: x = 13.",
                formula: "(x + 3) / 2 + 4 = 12  ⟹  x = 13"
            ) { GlacierConceptVisual() }
        case 106:
            return LevelConcept(
                title: "Scientific Notation",
                description: "Scientific notation writes any number as a power of ten, so the width of the universe and the width of a quark land on the same ruler. The exponent is a number's scale — how many orders of magnitude it stands from 1 — not just how many digits it has.\n\nThat's why a bacterium (10⁻⁶ m) is exactly six powers of ten smaller than a person (10⁰ m): the gap between the exponents, 0 − (−6) = 6, is the amount of zoom between them. Multiplying by 10ⁿ slides you n steps along the ruler — positive n toward the vast, negative n toward the tiny — which turns unimaginable jumps in size into simple addition of exponents.",
                formula: "10⁰ m × 10⁻⁶ = 10⁻⁶ m"
            ) { PowersOfTenConceptVisual() }
        case 107:
            return LevelConcept(
                title: "Radicals",
                description: "A radical is a length. Start with a right triangle whose legs are both 1: its hypotenuse is √2. Stand a second triangle on that hypotenuse with a new unit leg and its hypotenuse is √3, then √4, √5 — the Spiral of Theodorus, winding outward one unit at a time.\n\nEach step is the Pythagorean theorem: a hypotenuse √n plus a perpendicular leg 1 gives √((√n)² + 1²) = √(n+1). So √2, √3, √5, √6, √7 … aren't just symbols waiting to be simplified — they are the actual distances the spiral reaches. Radicals are geometry made visible.",
                formula: "(√n)² + 1² = n + 1  ⟹  √(n+1)"
            ) { SpiralOfTheodorusConceptVisual() }
        case 108:
            return LevelConcept(
                title: "Squaring a Binomial",
                description: "Squaring a sum means pairing every part of it with every part of itself — exactly what a Punnett square does. Two parents each carry genes a and b, and breeding lists all four pairings: aa, ab, ba, bb. Because ab and ba are the same combination, they merge into two ab, leaving one a², two ab, and one b².\n\nThat tally is the identity: (a + b)² = a² + 2ab + b². The middle 2ab isn't arbitrary — the 2 counts the two ways to draw one a and one b. This is why (a + b)² ≠ a² + b²: the cross terms are the offspring you'd forget. Read backward, spotting a² + 2ab + b² and folding it into (a + b)² is factoring a perfect square.",
                formula: "(a + b)² = a² + 2ab + b²"
            ) { BinomialSquareConceptVisual() }
        case 109:
            return LevelConcept(
                title: "Solving Quadratics",
                description: "A quadratic equation like x² − 5x + 6 = 0 has a fixed set of solutions — where its parabola crosses the x-axis. There are many roads to those roots, and they never disagree.\n\nFactoring spots (x − 2)(x − 3); completing the square rewrites it as (x − 5⁄2)² = 1⁄4; square-root extraction then takes the root; and the quadratic formula does all of that at once for any a, b, c. Graphing simply shows the answer. Five methods, one equation, the same roots x = 2 and 3 — the method you pick is a matter of convenience, not of a different truth.",
                formula: "x = ( −b ± √(b² − 4ac) ) ⁄ 2a"
            ) { QuadraticLensesConceptVisual() }
        case 110:
            return LevelConcept(
                title: "Piecewise Functions",
                description: "A piecewise function is one machine with several rules, each governing its own stretch of x. The graph is a course of separate segments, and the notation at each seam tells you everything: a closed circle ● means the endpoint belongs to that piece — solid ground you can ride to — while an open circle ○ means the value is excluded — empty space.\n\nWhere two pieces meet at the same height, the function is continuous and the ride is smooth. Where the rule changes and the height jumps, there's a discontinuity — a literal gap that must be leapt. That's the whole idea: each rule applies only on its interval, and the open/closed endpoints decide whether you roll through a point or launch over it.",
                formula: "f(x) = { x+4 on [−7,−3], 1 on [−3,0), −1 on [0,3] }"
            ) { PiecewiseSkateConceptVisual() }
        case 111:
            return LevelConcept(
                title: "Parabolas",
                description: "Thrown objects, fountain streams, satellite paths near a planet, and aiming systems can be modeled by curved paths. When horizontal motion combines with vertical acceleration, the path bends into a parabola instead of staying straight.\n\nA parabola is the graph of a quadratic equation. In vertex form, y is the vertical output, x is the horizontal input, a controls how wide or narrow the curve is, h is the x-coordinate of the vertex, and k is the y-coordinate of the vertex. When a is negative, the parabola opens downward and the vertex is the maximum point.",
                formula: "y = a(x - h)² + k"
            ) { QuadraticMotionConceptVisual() }
        case 112:
            return LevelConcept(
                title: "Similarity",
                description: "Zoom a camera, resize a photo, print a map, or project a slide — the image gets bigger or smaller, yet nothing about its shape changes. Every length is multiplied by the same number k, the scale factor, while every angle stays exactly as it was. Two figures related this way are similar: same shape, any size.\n\nThat single number is powerful. If k = 2, every edge doubles — but area grows by k² = 4. Mapmakers shrink whole coastlines by one scale factor, engineers test small models of bridges and planes because similar shapes share their geometry, and your eye judges distance partly by how small a familiar shape appears. Congruence is just the special case k = 1.",
                formula: "similar: angles equal, lengths ×k  (area ×k²)"
            ) { SimilarityConceptVisual() }
        case 113:
            return LevelConcept(
                title: "Unit Circle",
                description: "The unit circle organizes familiar angles as rays from the center. Each angle can be named in degrees or radians: 30° is π/6, 90° is π/2, and one full turn is 360° or 2π. Where a ray meets the circle, the point's horizontal coordinate is cos θ and its vertical coordinate is sin θ.\n\nUp to two targets approach at once from different directions. Tap either ray carrying a target and it lights up, forming a right triangle against the horizontal axis. The selected angle then appears in both degree and radian form.",
                formula: "P(θ) = (cos θ, sin θ)   360° = 2π"
            ) { TrigRatioConceptVisual() }
        case 114:
            return LevelConcept(
                title: "Polynomial Functions",
                description: "A vertical loop cannot be the graph of one function y = f(x), because some vertical lines intersect it more than once. Coaster designers can instead describe position with two polynomial functions of time: x(t) and y(t). Together they form a parametric polynomial curve that can move forward, backward, upward, and around a loop.\n\nThe ride uses connected cubic Bézier sections. Each section is a third-degree polynomial in t controlled by four points. Neighboring sections share endpoints and directions, producing one sleek continuous rail through the hill, valley, loop, and finish.",
                formula: "B(t) = (1−t)³P₀ + 3(1−t)²tP₁ + 3(1−t)t²P₂ + t³P₃"
            ) { PolynomialCoasterConceptVisual() }
        case 115:
            return LevelConcept(
                title: "Factoring Polynomials",
                description: "Sheet-metal panels make factoring visible. An x² tile is an x-by-x square, each x tile is an x-by-1 strip, and each unit tile is a 1-by-1 square. Their combined area is the expanded polynomial.\n\nWhen every piece fits into one rectangle, the two side lengths multiply to produce that same area. Those side lengths are the polynomial's factors. No algebra has disappeared: factoring simply reorganizes a sum of areas into one length times one width.",
                formula: "x² + 5x + 6 = (x + 2)(x + 3)"
            ) { FactoringSheetConceptVisual() }
        case 116:
            return LevelConcept(
                title: "N-Queens Problem",
                description: "The N-Queens Problem is a classic constraint-satisfaction puzzle. It asks for n queens on an n-by-n chessboard so that no queen can attack another. The same kind of reasoning appears in scheduling, resource assignment, circuit layout, and search algorithms.\n\nFor every pair of queens, their row numbers must differ, their column numbers must differ, and the absolute row separation cannot equal the absolute column separation. That final condition prevents diagonal attacks.",
                formula: "rᵢ ≠ rⱼ,  cᵢ ≠ cⱼ,  |rᵢ−rⱼ| ≠ |cᵢ−cⱼ|"
            ) { NQueensConceptVisual() }
        case 117:
            return LevelConcept(
                title: "Rational Functions",
                description: "Manufacturers pay fixed costs before the first item leaves the line: equipment, rent, setup, and tooling. Producing more units spreads that fixed amount across a larger batch, so average cost falls. Real plants must still match output to demand, because unsold inventory consumes cash.\n\nIn the formula, F is fixed cost, q is units produced, and v is variable cost per unit. The fraction F/q shrinks as q grows, so average cost approaches v from above. The line y = v is a horizontal asymptote: the curve can approach it indefinitely but never cross it for positive F and q.",
                formula: "C(q) = F/q + v,   q > 0,   C(q) > v"
            ) { RationalFactoryConceptVisual() }
        case 118:
            return LevelConcept(
                title: "Inverse Functions",
                description: "Calibration and decoding work by reversing a known process. If a machine scales, heats, and shifts an input, recovery begins with the shift because it happened last. Each operation is undone by its opposite, and the entire order is reversed.\n\nAn inverse function sends each output back to the input that produced it. Composing a function with its inverse therefore returns the starting value. This works only when outputs identify their original inputs uniquely over the chosen domain.",
                formula: "f⁻¹(f(x)) = x    and    f(f⁻¹(x)) = x"
            ) { ReversibleMachineConceptVisual() }
        case 119:
            return LevelConcept(
                title: "Composite Functions",
                description: "A composite function is a nesting doll: open f and g is living inside it, and inside g sits the input x. The notation f(g(x)) is drawn exactly like the toy — the outer symbol wraps the inner one — and evaluating means opening the dolls from the inside out: find g(x) first, then hand that value to f.\n\nThe nesting also shows why order matters. A doll of f inside g is a different toy from g inside f: with f(x) = x² and g(x) = x + 2, f(g(4)) = 36 but g(f(4)) = 18. Composition is generally not commutative — which doll is on the outside changes everything.",
                formula: "(f ∘ g)(x) = f(g(x))    usually f ∘ g ≠ g ∘ f"
            ) { NestingDollConceptVisual() }
        case 120:
            return LevelConcept(
                title: "Absolute Value Functions",
                description: "An echo measures distance without caring which side of a beacon produced the reflection. That direction-free distance is |x − h|, where h is the beacon's position. Points equally far left and right of h have the same echo time, creating the two symmetric arms of a V.\n\nFor a round trip, sound covers the distance twice, so t = 2|x − h|/v. Moving the beacon translates the vertex horizontally. Changing pulse speed changes the scale factor and therefore the V's steepness: faster pulses produce a flatter timing graph.",
                formula: "t(x) = 2|x − h|/v = a|x − h|"
            ) { EcholocationConceptVisual() }
        case 121:
            return LevelConcept(
                title: "Quadratic Systems",
                description: "Projectile motion under constant gravity traces a parabola. Each cannon's arc can be modeled by a quadratic equation, and any point occupied by both trajectories is a solution of the system. The vertex is the highest point of an arc, where upward motion changes to downward motion.\n\nIn the range, both cannons are synchronized to the same quadratic. Their projectiles arrive at the vertex together, pass one another, and descend through the opposite projectile's earlier path. Matching the equations makes the trajectories coincident, so every point on the parabola satisfies both equations; the vertex is the timed intercept.",
                formula: "y₁ = ax² + k,  y₂ = bx² + m    intercepts satisfy y₁ = y₂"
            ) { CannonSystemsConceptVisual() }
        case 122:
            return LevelConcept(
                title: "Determinants",
                description: "A digital image is a grid of tiny square regions. A 2 × 2 matrix moves the horizontal and vertical basis directions, transforming every pixel with them. Rotation changes orientation, stretching changes scale, and skewing turns the square image frame into a parallelogram.\n\nThe determinant ad − bc is the image's signed area scale. A magnitude of 2 doubles its area, while a magnitude near 0 compresses its pixels toward a line and destroys visible detail. A negative determinant also flips orientation. Redistributing the pixels after a valid transformation restores a crisp sampling of the transformed image.",
                formula: "A = [a b; c d]    det(A) = ad − bc    new area = |det(A)| · old area"
            ) { DeterminantCraneConceptVisual() }
        case 123:
            return LevelConcept(
                title: "Geometric Sequences",
                description: "A self-similar fractal repeats one structure at successively smaller scales. If each copy is half the width of the previous one, zooming inward by one generation requires twice the magnification. The zoom levels therefore read 1, 2, 4, 8, 16, 32, and 64.\n\nThose magnifications form a geometric sequence because every term is produced by multiplying the previous term by the same common ratio, 2. The recursive formula describes the step-by-step zoom, while the explicit formula jumps directly to any generation.",
                formula: "a₀ = 1    aₙ₊₁ = 2aₙ    aₙ = 2ⁿ"
            ) { GeometricBounceConceptVisual() }
        case 124:
            return LevelConcept(
                title: "Fourier Summation",
                description: "A recorded voice is one complicated pressure waveform, but it can be represented as a sum of simpler frequency components. Each harmonic contributes a cosine coefficient aₙ and a sine coefficient bₙ. Sigma notation combines all of those individual terms into one reconstructed signal.\n\nAmplitude controls how strongly a frequency appears. Frequency controls how quickly that component oscillates, and phase shifts it in time. Low-frequency layers carry warmth and body; high-frequency layers carry brightness, consonants, and fine detail.",
                formula: "f(t) = a₀/2 + ∑ⁿₙ₌₁ [aₙ cos(2πfₙt) + bₙ sin(2πfₙt)]"
            ) { FourierSeriesConceptVisual() }
        case 125:
            return LevelConcept(
                title: "Galton's Board",
                description: "Each peg is a physical 50–50 decision: a bead falls left or right. After n rows, a bead reaches bin k only when it has moved right exactly k times. Many more paths lead toward the middle than toward either edge, so repeated drops build a symmetric, bell-shaped binomial distribution.\n\nThe probability of bin k is determined by its number of possible routes. Those route counts can be read from the corresponding row of Pascal's triangle, which serves here as a compact reference for the board's outcomes.",
                formula: "P(X = k) = C(n,k)(1/2)ⁿ"
            ) { GaltonPascalConceptVisual() }
        case 126:
            return LevelConcept(
                title: "Binomial Theorem",
                description: "A shortest city route with n blocks contains some east moves and some north moves. Every ordering of those moves reaches a boundary destination. If a destination needs k north moves, its number of routes is C(n,k), because k positions are chosen from the n moves.\n\nExpanding (E + N)ⁿ makes the same choices: each factor contributes either E or N. Terms with the same number of north choices combine, so the route totals on the boundary become the coefficients of the expansion. Neighboring route counts add because every arrival uses one of two final feeder streets.",
                formula: "(E + N)ⁿ = ∑ⁿₖ₌₀ C(n,k)Eⁿ⁻ᵏNᵏ"
            ) { CityRouteBinomialConceptVisual() }
        case 127:
            return LevelConcept(
                title: "Prime Numbers",
                description: "Minerals often break along planes in their crystal structure. In this model, the composite crystal 6 releases the prime factors 2 and 3, while 35 releases 5 and 7. Those shining factors cannot be broken into smaller whole-number factors.\n\nA prime number has exactly two positive factors: 1 and itself. Every composite whole number can ultimately be broken into a unique product of prime-number building blocks.",
                formula: "p is prime  ⟺  factors(p) = {1, p}"
            ) { PrimeCrystalConceptVisual() }
        case 128:
            return LevelConcept(
                title: "Polar Coordinates",
                description: "Radar measures a target from a central station. The radial coordinate r gives distance from the station, while the angle θ gives counterclockwise bearing from the positive x-axis. Together, (r, θ) identifies a point without first measuring separate horizontal and vertical offsets.\n\nThe radius is the hypotenuse of a right triangle. Its horizontal projection is r cos(θ), and its vertical projection is r sin(θ). These equations convert a polar location to Cartesian coordinates. Reversing direction can describe the same point with a negative radius or with an angle differing by a full turn.",
                formula: "x = r cos(θ)    y = r sin(θ)"
            ) { PolarRadarConceptVisual() }
        case 129:
            return LevelConcept(
                title: "Algorithms",
                description: "Search engines, maps, spreadsheets, and games rely on algorithms: precise procedures that transform inputs into useful results. Insertion sort builds order by repeatedly placing each new item where it belongs.\n\nAt each step, the active item is compared with the already sorted portion, larger values shift right, and the item enters the open position. The important mathematics is the repeatable procedure and why it must eventually produce an ordered list, not a standalone formula."
            ) { SortBarsConceptVisual() }
        case 130:
            return LevelConcept(
                title: "Limits",
                description: "A limit describes the output a function approaches while its input moves closer to a chosen value. The function does not need to be defined at that exact input, and its assigned value there can even differ from the nearby trend. Limits are therefore predictions from surrounding behavior rather than direct readings at the point.\n\nA two-sided limit exists only when the left-hand and right-hand limits agree. If measurements approaching from x < a and x > a converge to the same L, then lim as x approaches a of f(x) equals L. If the two sides approach different values, there is no single two-sided limit.",
                formula: "limₓ→ₐ f(x) = L  when  limₓ→ₐ⁻ f(x) = limₓ→ₐ⁺ f(x) = L"
            ) { LimitSensorConceptVisual() }
        case 131:
            return LevelConcept(
                title: "Continuity",
                description: "A continuous function has no gap, jump, or detached value at the point being inspected. Approaching the boundary from the left must produce the same output as approaching from the right, so the two-sided limit exists. That shared limit must also equal the function's actual value at the boundary.\n\nAll three conditions matter. Two pipe sections could meet each other while missing the junction valve, just as a limit can exist but differ from f(a). A function is continuous at x = a only when its left limit, right limit, and assigned value are one number.",
                formula: "limₓ→ₐ⁻ f(x) = f(a) = limₓ→ₐ⁺ f(x)"
            ) { ContinuityPipelineConceptVisual() }
        case 132:
            return LevelConcept(
                title: "Derivatives",
                description: "Average speed divides the total change in distance by a whole time interval. A speedometer instead reports motion at one instant. Mathematically, we shrink the time interval around that instant; the secant slopes approach one value, which is the derivative.\n\nOn a distance-time graph, the derivative is the slope of the tangent line. A steep positive tangent means rapid forward motion, a horizontal tangent means an instantaneous stop, and a negative tangent means distance in the chosen direction is decreasing. The derivative function records that local rate at every time.",
                formula: "s′(t) = limₕ→₀ [s(t+h) − s(t)] / h"
            ) { DerivativeSpeedConceptVisual() }
        case 133:
            return LevelConcept(
                title: "Calculus Optimization",
                description: "A soap bubble is a physical constrained-optimization system. Holding the dispenser longer traps more air, so the released bubble has greater volume. For a fixed volume V, the sphere has the least possible area A.\n\nWhen two bubbles touch, they can keep distinct air volumes while sharing one membrane. The level preserves both measured volumes and numerically compares spherical-cap configurations to find the shared radius requiring the least film. Because a soap film has an inner and outer liquid-air surface, its minimum surface energy is 2γA, using γ = 0.025 N/m for soapy water.",
                formula: "V = 4πr³/3    Aₘᵢₙ = 4πr²    Eₘᵢₙ = 2γAₘᵢₙ"
            ) { BubbleOptimizationConceptVisual() }
        case 134:
            return LevelConcept(
                title: "Integrals",
                description: "Rainfall rate tells how quickly water is arriving at each instant, measured as volume per unit time. Multiplying a rate by a narrow time width gives the small amount collected during that slice. Adding every slice across the storm estimates the reservoir's total gain.\n\nAs the slices become narrower, their sum approaches the definite integral. The bounds 0 and T define the collection interval, while the area beneath the rate curve represents accumulated volume. Integration therefore reverses differentiation: if V′(t) = r(t), then the integral of r from 0 to T equals V(T) − V(0).",
                formula: "∫₀ᵀ r(t) dt = accumulated volume"
            ) { RainwaterIntegralConceptVisual() }
        case 135:
            return LevelConcept(
                title: "Logarithmic Functions",
                description: "Sound intensity is a physical ratio. Multiplying intensity by 10 does not add a fixed amount of sound energy; it creates another full order of magnitude. The decibel scale compresses those enormous ratios with a base-10 logarithm.\n\nIf intensity is measured relative to a reference I₀, then 1×, 10×, 100×, 1,000×, and 10,000× become 0, 10, 20, 30, and 40 dB. Equal steps in decibels therefore represent multiplicative changes in intensity. A gain of +20 dB requires 100 times the original intensity.",
                formula: "β = 10 log₁₀(I / I₀)    10× intensity = +10 dB"
            ) { LogarithmicSoundConceptVisual() }
        case 136:
            return LevelConcept(
                title: "Newton's Law of Cooling",
                description: "Newton's law of cooling connects a room's current temperature to its instantaneous rate of change. The difference T − Tₐ measures how far the room is from the surrounding environment. Multiplying by −k makes the rate point back toward ambient temperature: hot rooms cool and cold rooms warm.\n\nThe constant k measures thermal exchange. Strong insulation produces a smaller k and a slower response. Solving the differential equation gives an exponential trajectory. The initial difference is multiplied by e⁻ᵏᵗ, so it shrinks over time without overshooting the ambient equilibrium.",
                formula: "dT/dt = −k(T − Tₐ)    T(t) = Tₐ + (T₀ − Tₐ)e⁻ᵏᵗ"
            ) { ThermalEquationConceptVisual() }
        case 137:
            return LevelConcept(
                title: "Probability",
                description: "A probability tree separates a forecast into branches. The probability of following two branches in sequence is their product, so a wet day that becomes a storm has probability P(wet)P(storm | wet). Mutually exclusive endpoints such as dry, light rain, and storm must add to one.\n\nOne simulated day is unpredictable, but many independent days reveal a stable pattern. The law of large numbers says an outcome's experimental frequency approaches its theoretical probability as the number of trials grows. Decisions can therefore compare long-run expected scores even though no individual forecast is guaranteed.",
                formula: "P(storm) = P(wet)P(storm | wet)    frequency = successes / trials"
            ) { WeatherProbabilityConceptVisual() }
        case 138:
            return LevelConcept(
                title: "Arc Length",
                description: "Equal pie servings begin with equal distances around the crust. If a circle has radius r and one slice subtends a central angle θ measured in radians, the curved edge of that slice has length s = rθ.\n\nA full turn is 2π radians, so dividing the pie among n customers gives each person θ = 2π/n radians. Substituting that angle produces s = 2πr/n, which is also the full circumference divided by n. Equal arc lengths therefore guarantee equal central angles and equal sectors.",
                formula: "s = rθ    θ = 2π/n    s = 2πr/n = C/n"
            ) { ArcLengthConceptVisual() }
        case 139:
            return LevelConcept(
                title: "Infinite Series",
                description: "Near the primary rainbow angle, light waves following nearby paths interfere. Their phases reinforce at some scattering angles and cancel at others, creating the bright primary bow and finer supernumerary structure. The Airy function models this intensity pattern; the visible bands are interference effects, not individual series terms.\n\nBecause Ai(x) is an entire function, it can be represented by a power series. A partial sum Sₙ uses finitely many coefficients and only approximates the full pattern. Increasing n reduces the overall error and Sₙ converges toward Ai(x). Later stages impose a term budget because an efficient model uses the fewest terms that meet the required accuracy.",
                formula: "Sₙ(x) = Σₖ₌₀ⁿ cₖxᵏ → Ai(x)    I(x) = Ai(x)²"
            ) { InfiniteRainbowSeriesConceptVisual() }
        case 140:
            return LevelConcept(
                title: "Chaos Theory",
                description: "A double pendulum is deterministic, but its two angular equations are coupled and nonlinear. The launch angle sets the initial condition. Gravity changes the accelerations and time scale, so stronger gravity generally drives faster motion. Friction at the middle joint applies a torque opposite the relative angular velocity of the two arms and removes mechanical energy from their relative motion.\n\nAt high energy, the lower bob can trace irregular loops that are extremely sensitive to the exact initial state. One trajectory reveals complex nonlinear behavior, although formally measuring sensitive dependence requires comparing nearby initial conditions. Increasing joint friction gradually suppresses tumbling and draws the system toward simpler motion.",
                formula: "θ̈ = F(θ₁, θ₂, θ̇₁, θ̇₂, g)    τ_f = −c(θ̇₂ − θ̇₁)"
            ) { ChaosControlledPendulumConceptVisual() }
        case 141:
            return LevelConcept(
                title: "Fundamental Theorem of Calculus",
                description: "A river's flow rate tells how quickly water is entering or leaving at one instant. Adding those tiny changes over time gives the reservoir's accumulated volume, so the area under the rate curve and the amount of stored water are the same quantity.\n\nThe Fundamental Theorem of Calculus connects accumulation and instantaneous change. Integrating the rate f builds the total F. Differentiating that accumulated total returns the original rate: when f is large, F rises steeply; when f is zero, F is flat; and when f is negative, F decreases.",
                formula: "F(t) = ∫₀ᵗ f(x)dx     F′(t) = f(t)"
            ) { FundamentalTheoremConceptVisual() }
        default:
            return nil
        }
    }
}

struct PolynomialCoasterConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6
            Canvas { context, size in
                let navy = Color(red: 0.06, green: 0.18, blue: 0.28)
                let coral = Color(red: 0.96, green: 0.33, blue: 0.25)
                let groundY = size.height - 18

                func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: x * size.width, y: y * size.height)
                }

                for x: CGFloat in [0.15, 0.31, 0.51, 0.73, 0.88] {
                    var support = Path()
                    let topY: CGFloat = x == 0.15 ? 0.28 : (x == 0.73 ? 0.72 : 0.68)
                    support.move(to: point(x, topY))
                    support.addLine(to: CGPoint(x: x * size.width - 14, y: groundY))
                    support.move(to: point(x, topY))
                    support.addLine(to: CGPoint(x: x * size.width + 14, y: groundY))
                    context.stroke(support, with: .color(.white.opacity(0.20)), lineWidth: 1.5)
                }

                var rail = Path()
                rail.move(to: point(0.02, 0.72))
                rail.addCurve(to: point(0.24, 0.78), control1: point(0.10, 0.16), control2: point(0.15, 0.12))
                rail.addCurve(to: point(0.49, 0.69), control1: point(0.34, 0.94), control2: point(0.39, 0.48))
                rail.addCurve(to: point(0.62, 0.78), control1: point(0.54, 0.57), control2: point(0.58, 0.76))
                rail.addEllipse(in: CGRect(x: size.width * 0.62, y: size.height * 0.17, width: size.width * 0.25, height: size.height * 0.61))
                rail.move(to: point(0.745, 0.78))
                rail.addCurve(to: point(0.98, 0.70), control1: point(0.82, 0.81), control2: point(0.91, 0.74))

                context.stroke(rail, with: .color(.white.opacity(0.92)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                context.stroke(rail, with: .color(navy), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                context.stroke(rail, with: .color(coral), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                let train: CGPoint
                if progress < 0.45 {
                    let t = CGFloat(progress / 0.45)
                    train = point(0.02 + 0.47 * t, 0.72 - 0.45 * sin(t * .pi))
                } else if progress < 0.80 {
                    let theta = CGFloat((progress - 0.45) / 0.35) * .pi * 2 + .pi / 2
                    train = point(0.745 + 0.125 * cos(theta), 0.475 + 0.305 * sin(theta))
                } else {
                    let t = CGFloat((progress - 0.80) / 0.20)
                    train = point(0.745 + 0.235 * t, 0.78 - 0.08 * t)
                }
                context.fill(Path(roundedRect: CGRect(x: train.x - 8, y: train.y - 6, width: 16, height: 10), cornerRadius: 2), with: .color(coral))
            }
        }
        .frame(height: 150)
        .accessibilityLabel("A train rides a polynomial roller coaster with a tall hill and a parametric loop")
    }
}

struct FactoringSheetConceptVisual: View {
    private let cyan = Color(red: 0.20, green: 0.78, blue: 0.82)
    private let yellow = Color(red: 1.0, green: 0.73, blue: 0.12)

    var body: some View {
        ZStack {
            Color.white.opacity(0.035)
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    tile("x²", color: cyan).frame(width: 78, height: 78)
                    HStack(spacing: 3) {
                        tile("x", color: yellow).frame(width: 22.5, height: 78)
                        tile("x", color: yellow).frame(width: 22.5, height: 78)
                    }
                    .frame(width: 48, height: 78)
                }
                HStack(spacing: 5) {
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            tile("x", color: yellow).frame(width: 78, height: 8.5)
                        }
                    }
                    .frame(width: 78, height: 30)
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            HStack(spacing: 2) {
                                ForEach(0..<2, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.82))
                                }
                            }
                        }
                    }
                    .frame(width: 48, height: 30)
                }
                Text("(x + 2)(x + 3)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)
            }
            .padding(12)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(cyan.opacity(0.5), lineWidth: 2))
        .accessibilityLabel("Algebra tiles forming a rectangle with side lengths x plus 2 and x plus 3")
    }

    private func tile(_ label: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(0.82))
            .overlay(Text(label).font(.system(size: 14, weight: .black, design: .serif)).foregroundStyle(.black.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.6), lineWidth: 1))
    }
}

struct ComplexDroneConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3
            let angle = t * Double.pi / 4
            let radius = 35 * pow(2.squareRoot(), t)
            let center = CGPoint(x: 105, y: 75)
            let end = CGPoint(x: center.x + CGFloat(cos(angle) * radius), y: center.y - CGFloat(sin(angle) * radius))

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 20, y: center.y))
                    path.addLine(to: CGPoint(x: 190, y: center.y))
                    path.move(to: CGPoint(x: center.x, y: 16))
                    path.addLine(to: CGPoint(x: center.x, y: 130))
                }
                .stroke(.white.opacity(0.17), lineWidth: 1)

                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 70, height: 70)
                    .position(center)

                Path { path in
                    path.move(to: center)
                    path.addLine(to: end)
                }
                .stroke(Color(red: 0.18, green: 0.82, blue: 0.88), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                Image(systemName: "location.north.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(red: 1, green: 0.74, blue: 0.2))
                    .rotationEffect(.radians(angle + .pi / 2))
                    .position(end)

                Text("× (1+i)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .position(x: 48, y: 20)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A drone vector rotating 45 degrees and scaling by square root of two")
    }
}

struct RationalSignalConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let scan = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
            Canvas { context, size in
                let centerY = size.height / 2
                let mapX: (Double) -> CGFloat = { 12 + CGFloat(($0 + 4) / 8) * (size.width - 24) }
                let mapY: (Double) -> CGFloat = { centerY - CGFloat($0 / 6) * (size.height - 24) }

                var axes = Path()
                axes.move(to: CGPoint(x: 10, y: centerY))
                axes.addLine(to: CGPoint(x: size.width - 10, y: centerY))
                axes.move(to: CGPoint(x: mapX(0), y: 8))
                axes.addLine(to: CGPoint(x: mapX(0), y: size.height - 8))
                context.stroke(axes, with: .color(.white.opacity(0.16)), lineWidth: 1)

                let asymptoteX = mapX(1)
                var asymptote = Path()
                asymptote.move(to: CGPoint(x: asymptoteX, y: 8))
                asymptote.addLine(to: CGPoint(x: asymptoteX, y: size.height - 8))
                context.stroke(asymptote, with: .color(Color(red: 0.95, green: 0.27, blue: 0.25).opacity(0.75)), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 10, y: mapY(1)))
                horizontal.addLine(to: CGPoint(x: size.width - 10, y: mapY(1)))
                context.stroke(horizontal, with: .color(Color(red: 0.20, green: 0.82, blue: 0.78).opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))

                let maxX = -4 + 8 * scan
                var curve = Path()
                var drawing = false
                for step in 0...180 {
                    let x = -4 + 8 * Double(step) / 180
                    guard x <= maxX, abs(x - 1) > 0.08 else { drawing = false; continue }
                    let y = (x + 1) / (x - 1)
                    guard abs(y) < 6 else { drawing = false; continue }
                    let point = CGPoint(x: mapX(x), y: mapY(y))
                    if drawing { curve.addLine(to: point) } else { curve.move(to: point); drawing = true }
                }
                context.stroke(curve, with: .color(Color(red: 1, green: 0.74, blue: 0.18)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .frame(height: 140)
        }
        .accessibilityLabel("A rational signal curve approaching a vertical and horizontal asymptote")
    }
}

struct ReversibleMachineConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6
            let forward = cycle < 0.5
            let local = forward ? cycle * 2 : (1 - cycle) * 2
            let x = 20 + CGFloat(local) * 170

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 18, y: 72))
                    path.addLine(to: CGPoint(x: 192, y: 72))
                }
                .stroke(.white.opacity(0.18), lineWidth: 3)

                ForEach(0..<3, id: \.self) { index in
                    let labels = ["×2", "+6", "−3"]
                    RoundedRectangle(cornerRadius: 5)
                        .fill(index == 0 ? Color.blue.opacity(0.35) : index == 1 ? Color.red.opacity(0.35) : Color.green.opacity(0.35))
                        .frame(width: 42, height: 48)
                        .overlay(Text(labels[index]).font(.system(size: 12, weight: .black, design: .serif)).foregroundStyle(.white))
                        .position(x: 57 + CGFloat(index) * 48, y: 72)
                }

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.20, green: 0.82, blue: 0.78))
                    .frame(width: 30, height: 25)
                    .overlay(Text(forward ? "f" : "f⁻¹").font(.system(size: 10, weight: .black, design: .serif)).foregroundStyle(.black.opacity(0.7)))
                    .position(x: x, y: 72)

                Image(systemName: forward ? "arrow.right" : "arrow.left")
                    .foregroundStyle(Color(red: 1, green: 0.73, blue: 0.18))
                    .position(x: 105, y: 120)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("An object moving forward through three operations and backward through their inverses")
    }
}

// Level 119 — two nesting dolls: the big f-doll tips open, the little g-doll
// pops out, then nests back inside. Looping.
struct NestingDollConceptVisual: View {
    private let red = Color(red: 0.82, green: 0.22, blue: 0.20)
    private let teal = Color(red: 0.24, green: 0.62, blue: 0.58)
    private let cream = Color(red: 0.94, green: 0.88, blue: 0.76)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let cycle = (t * 0.30).truncatingRemainder(dividingBy: 1.0)
            // 0–0.2 closed · 0.2–0.5 open + pop out · 0.5–0.8 hold · 0.8–1 nest back
            let open: Double = cycle < 0.2 ? 0 : (cycle < 0.35 ? (cycle - 0.2) / 0.15 : (cycle < 0.8 ? 1 : max(0, 1 - (cycle - 0.8) / 0.15)))
            let out: Double = cycle < 0.28 ? 0 : (cycle < 0.45 ? (cycle - 0.28) / 0.17 : (cycle < 0.75 ? 1 : max(0, 1 - (cycle - 0.75) / 0.18)))

            ZStack {
                // Big doll (f).
                miniDoll(bodyColor: red, w: 74, h: 108, label: "f", lidTilt: -34 * open)
                    .position(x: 78, y: 82)

                // Little doll (g) popping out and nesting back.
                miniDoll(bodyColor: teal, w: 42, h: 62, label: "g", lidTilt: 0)
                    .scaleEffect(0.25 + 0.75 * out)
                    .opacity(out < 0.05 ? 0 : 1)
                    .position(x: 78 + 78 * out, y: 92)

                Text("f(g(x)) — g lives inside f")
                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.mathGold.opacity(0.85))
                    .position(x: 105, y: 148)
            }
            .frame(width: 210, height: 160)
        }
    }

    private func miniDoll(bodyColor: Color, w: CGFloat, h: CGFloat, label: String, lidTilt: Double) -> some View {
        ZStack {
            ConceptDollShape()
                .fill(LinearGradient(colors: [bodyColor.opacity(0.95), bodyColor.opacity(0.7)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(ConceptDollShape().stroke(.white.opacity(0.3), lineWidth: 1))
            // Kerchief head hint.
            Circle()
                .fill(cream.opacity(0.9))
                .frame(width: w * 0.34, height: w * 0.34)
                .offset(y: -h * 0.315)
                .rotationEffect(.degrees(lidTilt), anchor: UnitPoint(x: 0.2, y: 0.36))
            Text(label)
                .font(.system(size: w * 0.24, weight: .heavy, design: .monospaced))
                .italic()
                .foregroundStyle(.white)
                .offset(y: h * 0.12)
        }
        .frame(width: w, height: h)
    }
}

private struct ConceptDollShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var p = Path()
        p.move(to: pt(0.30, 0.30))
        p.addQuadCurve(to: pt(0.50, 0.02), control: pt(0.28, 0.05))
        p.addQuadCurve(to: pt(0.70, 0.30), control: pt(0.72, 0.05))
        p.addCurve(to: pt(0.92, 0.78), control1: pt(0.80, 0.42), control2: pt(0.92, 0.58))
        p.addQuadCurve(to: pt(0.50, 0.985), control: pt(0.92, 0.985))
        p.addQuadCurve(to: pt(0.08, 0.78), control: pt(0.08, 0.985))
        p.addCurve(to: pt(0.30, 0.30), control1: pt(0.08, 0.58), control2: pt(0.20, 0.42))
        p.closeSubpath()
        return p
    }
}

struct WaterTreatmentConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
            let x = 18 + CGFloat(progress) * 176

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 15, y: 72))
                    path.addLine(to: CGPoint(x: 197, y: 72))
                }
                .stroke(Color(red: 0.18, green: 0.82, blue: 0.86).opacity(0.35), lineWidth: 6)

                ForEach(0..<3, id: \.self) { index in
                    let labels = ["f", "p", "m"]
                    let operations = ["x−3", "2x", "x+4"]
                    RoundedRectangle(cornerRadius: 5)
                        .fill([Color.green, Color.blue, Color.purple][index].opacity(0.35))
                        .frame(width: 45, height: 55)
                        .overlay(
                            VStack(spacing: 3) {
                                Text(labels[index]).font(.system(size: 14, weight: .black, design: .serif))
                                Text(operations[index]).font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                        )
                        .position(x: 55 + CGFloat(index) * 50, y: 72)
                }

                Circle()
                    .fill(Color(red: 0.18, green: 0.82, blue: 0.86))
                    .frame(width: 22, height: 22)
                    .overlay(Image(systemName: "drop.fill").font(.system(size: 10)).foregroundStyle(.white))
                    .position(x: x, y: 72)

                Text("m(p(f(x)))")
                    .font(.system(size: 13, weight: .black, design: .serif))
                    .foregroundStyle(Color(red: 1, green: 0.73, blue: 0.18))
                    .position(x: 105, y: 124)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A water sample flowing through three composed treatment functions")
    }
}

struct EcholocationConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3
            let pulse = CGFloat(sin(cycle * .pi))

            Canvas { context, size in
                let vertex = CGPoint(x: size.width * 0.55, y: size.height * 0.82)
                var graph = Path()
                graph.move(to: CGPoint(x: 18, y: 18))
                graph.addLine(to: vertex)
                graph.addLine(to: CGPoint(x: size.width - 18, y: 34))
                context.stroke(graph, with: .color(Color(red: 0.20, green: 0.86, blue: 0.94)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                let radius = 12 + pulse * 42
                context.stroke(Path(ellipseIn: CGRect(x: vertex.x - radius, y: vertex.y - radius, width: radius * 2, height: radius * 2)), with: .color(Color(red: 1, green: 0.73, blue: 0.18).opacity(0.65)), lineWidth: 2)

                for point in [CGPoint(x: 56, y: 54), CGPoint(x: 164, y: 62)] {
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)), with: .color(Color(red: 1, green: 0.73, blue: 0.18)))
                }

                context.draw(Image(systemName: "dot.radiowaves.left.and.right"), at: vertex)
                context.draw(Text("h").font(.system(size: 12, weight: .black, design: .serif)).foregroundColor(.white), at: CGPoint(x: vertex.x, y: vertex.y + 18))
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("An echo pulse expanding from the vertex of an absolute-value timing graph")
    }
}

struct CannonSystemsConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
            let leftX = -5 + 10 * cycle
            let rightX = 5 - 10 * cycle

            Canvas { context, size in
                let mapX: (Double) -> CGFloat = { 17 + CGFloat(($0 + 5) / 10) * (size.width - 34) }
                let mapY: (Double) -> CGFloat = { size.height - 20 - CGFloat($0 / 5) * (size.height - 38) }
                let trajectory: (Double) -> Double = { 4.2 * (1 - $0 * $0 / 25) }

                var parabola = Path()
                for step in 0...120 {
                    let x = -5 + 10 * Double(step) / 120
                    let point = CGPoint(x: mapX(x), y: mapY(trajectory(x)))
                    if step == 0 { parabola.move(to: point) } else { parabola.addLine(to: point) }
                }
                context.stroke(parabola, with: .color(Color(red: 0.18, green: 0.84, blue: 0.88).opacity(0.38)), lineWidth: 8)
                context.stroke(parabola, with: .color(Color(red: 1, green: 0.68, blue: 0.16)), lineWidth: 2)

                let vertex = CGPoint(x: mapX(0), y: mapY(4.2))
                context.stroke(Path(ellipseIn: CGRect(x: vertex.x - 9, y: vertex.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                let left = CGPoint(x: mapX(leftX), y: mapY(trajectory(leftX)))
                let right = CGPoint(x: mapX(rightX), y: mapY(trajectory(rightX)))
                context.fill(Path(ellipseIn: CGRect(x: left.x - 6, y: left.y - 6, width: 12, height: 12)), with: .color(Color(red: 0.18, green: 0.84, blue: 0.88)))
                context.fill(Path(ellipseIn: CGRect(x: right.x - 6, y: right.y - 6, width: 12, height: 12)), with: .color(Color(red: 1, green: 0.68, blue: 0.16)))

                context.draw(Text("SHARED VERTEX").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(.white), at: CGPoint(x: size.width / 2, y: 12))
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Two cannon projectiles crossing at the vertex of a shared parabolic trajectory")
    }
}

struct DeterminantCraneConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5) / 5
            let angle = CGFloat(cycle * .pi * 0.8)
            let squash = 1 - CGFloat(max(0, (cycle - 0.72) / 0.28)) * 0.9

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: 67)
                let scale: CGFloat = 42
                let a = cos(angle)
                let b = -sin(angle) * squash + 0.22
                let c = sin(angle)
                let d = cos(angle) * squash
                let rows = [".###.", "#...#", "#.#.#", "#...#", ".###."]
                let cell = 2.0 / CGFloat(rows.count)

                func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: center.x + (a * x + b * y) * scale, y: center.y - (c * x + d * y) * scale)
                }

                for (row, line) in rows.enumerated() {
                    for (column, character) in Array(line).enumerated() where character == "#" {
                        let left = -1 + CGFloat(column) * cell + 0.025
                        let right = left + cell - 0.05
                        let top = 1 - CGFloat(row) * cell - 0.025
                        let bottom = top - cell + 0.05
                        var pixel = Path()
                        pixel.move(to: point(left, bottom))
                        pixel.addLine(to: point(right, bottom))
                        pixel.addLine(to: point(right, top))
                        pixel.addLine(to: point(left, top))
                        pixel.closeSubpath()
                        context.fill(pixel, with: .color(Color(red: 1, green: 0.73, blue: 0.18)))
                    }
                }

                var frame = Path()
                frame.move(to: point(-1, -1))
                frame.addLine(to: point(1, -1))
                frame.addLine(to: point(1, 1))
                frame.addLine(to: point(-1, 1))
                frame.closeSubpath()
                context.stroke(frame, with: .color(Color(red: 0.18, green: 0.84, blue: 0.88)), lineWidth: 2)

                let determinant = a * d - b * c
                context.draw(Text("det = \(determinant, format: .number.precision(.fractionLength(2)))").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.white), at: CGPoint(x: size.width / 2, y: 128))
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A pixel image transformed by a matrix while its determinant approaches zero")
    }
}

struct GeometricBounceConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let zoom = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4 * 4

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: 65)
                let base = 94.0
                let colors = [
                    Color(red: 0.18, green: 0.84, blue: 0.88),
                    Color(red: 1, green: 0.73, blue: 0.18),
                    Color(red: 0.96, green: 0.31, blue: 0.25)
                ]

                for level in 0..<9 {
                    let side = CGFloat(base * pow(2, zoom - Double(level)))
                    guard side > 2, side < 440 else { continue }
                    let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
                    let color = colors[level % colors.count]
                    context.stroke(Path(rect), with: .color(color.opacity(0.72)), lineWidth: side > 40 ? 2 : 1)

                    let tile = side * 0.17
                    let offset = side * 0.32
                    for x in [-1.0, 1.0] {
                        for y in [-1.0, 1.0] {
                            let tileRect = CGRect(
                                x: center.x + CGFloat(x) * offset - tile / 2,
                                y: center.y + CGFloat(y) * offset - tile / 2,
                                width: tile,
                                height: tile
                            )
                            context.fill(Path(tileRect), with: .color(color.opacity(0.32)))
                        }
                    }
                }

                let term = Int(pow(2, floor(zoom)))
                context.draw(
                    Text("1, 2, 4, 8 …  ×\(term)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.white),
                    at: CGPoint(x: size.width / 2, y: 130)
                )
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A self-similar square fractal zooming through powers of two")
    }
}

struct SigmaSolarConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
            let active = min(3, Int(cycle * 4))
            let terms = [3, 5, 7, 9]

            ZStack {
                ForEach(0..<4, id: \.self) { row in
                    let y = 30 + CGFloat(row) * 24
                    HStack(spacing: 3) {
                        ForEach(0..<terms[row], id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(row <= active ? Color(red: 0.18, green: 0.84, blue: 0.88) : Color.blue.opacity(0.35))
                                .frame(width: 8, height: 12)
                        }
                    }
                    .position(x: 90, y: y)

                    Text("\(terms[row])")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .position(x: 170, y: y)
                }

                Text("∑⁴ᵢ₌₁ [3 + 2(i−1)] = \(terms.prefix(active + 1).reduce(0, +))")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1, green: 0.73, blue: 0.18))
                    .position(x: 105, y: 132)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Solar panel rows being added by a sigma expression")
    }
}

struct GaltonPascalConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let cycle = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2.8) / 2.8

            Canvas { context, _ in
                let centerX: CGFloat = 105
                let horizontalStep: CGFloat = 25
                let pinTop: CGFloat = 17
                let verticalStep: CGFloat = 16
                let rows = 5
                let binTop: CGFloat = 101
                let binBottom: CGFloat = 137
                let binHeights: [CGFloat] = [4, 15, 29, 29, 15, 4]

                for row in 0..<rows {
                    for column in 0...row {
                        let point = CGPoint(
                            x: centerX + (CGFloat(column) - CGFloat(row) / 2) * horizontalStep,
                            y: pinTop + CGFloat(row) * verticalStep
                        )
                        context.stroke(
                            Path(ellipseIn: CGRect(x: point.x - 3.2, y: point.y - 3.2, width: 6.4, height: 6.4)),
                            with: .color(.white.opacity(0.72)),
                            lineWidth: 1.1
                        )
                    }
                }

                let left = centerX - horizontalStep * 3
                var bins = Path()
                bins.move(to: CGPoint(x: left, y: binTop))
                bins.addLine(to: CGPoint(x: left, y: binBottom))
                bins.addLine(to: CGPoint(x: left + horizontalStep * 6, y: binBottom))
                bins.addLine(to: CGPoint(x: left + horizontalStep * 6, y: binTop))
                for index in 1..<6 {
                    let x = left + CGFloat(index) * horizontalStep
                    bins.move(to: CGPoint(x: x, y: binTop))
                    bins.addLine(to: CGPoint(x: x, y: binBottom))
                }
                context.stroke(bins, with: .color(.white.opacity(0.34)), lineWidth: 1)

                for index in 0..<6 {
                    let width = horizontalStep - 5
                    let rect = CGRect(
                        x: left + CGFloat(index) * horizontalStep + 2.5,
                        y: binBottom - binHeights[index],
                        width: width,
                        height: binHeights[index]
                    )
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color(red: 1, green: 0.73, blue: 0.18).opacity(0.82)))
                }

                let choices = [false, true, true, false, true]
                var rights = 0
                var route = [CGPoint(x: centerX, y: 2)]
                for row in 0..<rows {
                    route.append(CGPoint(
                        x: centerX + (CGFloat(rights) - CGFloat(row) / 2) * horizontalStep,
                        y: pinTop + CGFloat(row) * verticalStep
                    ))
                    if choices[row] { rights += 1 }
                }
                route.append(CGPoint(
                    x: centerX + (CGFloat(rights) - CGFloat(rows) / 2) * horizontalStep,
                    y: binTop + 2
                ))

                let scaled = min(0.999_999, cycle) * Double(route.count - 1)
                let segment = min(route.count - 2, Int(scaled))
                let local = CGFloat(scaled - Double(segment))
                let start = route[segment]
                let end = route[segment + 1]
                let bead = CGPoint(
                    x: start.x + (end.x - start.x) * local,
                    y: start.y + (end.y - start.y) * local * local
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: bead.x - 4, y: bead.y - 4, width: 8, height: 8)),
                    with: .color(Color(red: 0.18, green: 0.84, blue: 0.88))
                )
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A bead falling through a Galton board into a centered binomial distribution")
    }
}

struct CityRouteBinomialConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3)
            let route = [CGPoint(x: 24, y: 116), CGPoint(x: 67, y: 116), CGPoint(x: 110, y: 116), CGPoint(x: 110, y: 73), CGPoint(x: 110, y: 30)]

            ZStack {
                Path { path in
                    for index in 0..<4 {
                        let offset = CGFloat(index) * 43
                        path.move(to: CGPoint(x: 24 + offset, y: 116))
                        path.addLine(to: CGPoint(x: 24 + offset, y: 30))
                        path.move(to: CGPoint(x: 24, y: 116 - offset))
                        path.addLine(to: CGPoint(x: 153, y: 116 - offset))
                    }
                }
                .stroke(.white.opacity(0.2), lineWidth: 2)

                Path { path in
                    path.move(to: route[0])
                    route.dropFirst().forEach { path.addLine(to: $0) }
                }
                .trim(from: 0, to: progress)
                .stroke(cyan, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                ForEach(Array([1, 3, 3, 1].enumerated()), id: \.offset) { index, value in
                    let point = CGPoint(x: 24 + CGFloat(index) * 43, y: 30 + CGFloat(index) * 29)
                    Circle()
                        .fill(gold)
                        .frame(width: 24, height: 24)
                        .overlay(Text("\(value)").font(.system(size: 10, weight: .black)).foregroundStyle(.black.opacity(0.72)))
                        .position(point)
                }

                Text("(E + N)³")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .position(x: 153, y: 132)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A highlighted city route ending at a boundary of binomial coefficients")
    }
}

struct PrimeCrystalConceptVisual: View {
    private let cyan = Color(red: 0.20, green: 0.86, blue: 0.78)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let pulse = CGFloat((sin(timeline.date.timeIntervalSinceReferenceDate * 2.6) + 1) / 2)

            ZStack {
                VStack(spacing: 12) {
                    ForEach([6, 35], id: \.self) { composite in
                        let factors = composite == 6 ? [2, 3] : [5, 7]

                        HStack(spacing: 9) {
                            ZStack {
                                ConceptCrystalShape()
                                    .fill(gold.opacity(0.72))
                                    .overlay(ConceptCrystalShape().stroke(gold, lineWidth: 1))
                                    .frame(width: 34, height: 45)
                                Text("\(composite)")
                                    .foregroundStyle(.black.opacity(0.72))
                            }

                            Image(systemName: "arrow.right")
                                .foregroundStyle(.white.opacity(0.42))

                            ForEach(factors, id: \.self) { factor in
                                ZStack {
                                    ConceptCrystalShape()
                                        .fill(LinearGradient(colors: [.white, cyan, cyan.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .overlay(ConceptCrystalShape().stroke(.white.opacity(0.82), lineWidth: 1.2))
                                        .frame(width: 34, height: 45)
                                        .shadow(color: cyan.opacity(0.35 + 0.45 * pulse), radius: 5 + 5 * pulse)
                                    Text("\(factor)")
                                        .foregroundStyle(.black.opacity(0.72))
                                }
                            }

                            Text("\(factors[0]) × \(factors[1])")
                                .foregroundStyle(cyan)
                                .frame(width: 42)
                        }
                    }
                }

                Image(systemName: "hammer.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(coral)
                    .rotationEffect(.degrees(-28 + Double(pulse) * 16))
                    .position(x: 27, y: 19)
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Composite crystal six releasing prime factors two and three, and thirty-five releasing five and seven")
    }
}

private struct ConceptCrystalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.88, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.24))
        path.closeSubpath()
        return path
    }
}

struct PolarRadarConceptVisual: View {
    private let cyan = Color(red: 0.20, green: 0.86, blue: 0.72)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let pulse = CGFloat((sin(timeline.date.timeIntervalSinceReferenceDate * 3) + 1) / 2)
            let center = CGPoint(x: 105, y: 75)
            let angle = CGFloat.pi / 3
            let target = CGPoint(x: center.x + cos(angle) * 52, y: center.y - sin(angle) * 52)

            ZStack {
                ForEach(1...3, id: \.self) { ring in
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                        .frame(width: CGFloat(ring) * 38, height: CGFloat(ring) * 38)
                }

                Path { path in
                    path.move(to: center)
                    path.addLine(to: target)
                    path.move(to: CGPoint(x: center.x, y: target.y))
                    path.addLine(to: target)
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x, y: target.y))
                }
                .stroke(cyan, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

                Circle()
                    .fill(gold.opacity(0.25))
                    .frame(width: 22 + pulse * 10, height: 22 + pulse * 10)
                    .position(target)
                Image(systemName: "cloud.heavyrain.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(gold)
                    .position(target)

                Text("(r, θ)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .position(x: 105, y: 132)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A radar radius locating a storm with polar coordinates and Cartesian projections")
    }
}

struct ParametricDroneConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4 * .pi * 2
            let point = CGPoint(x: 105 + cos(t * 2) * 70, y: 68 - sin(t) * 38)

            ZStack {
                Path { path in
                    for index in 0...160 {
                        let u = Double(index) / 160 * Double.pi * 2
                        let p = CGPoint(x: 105 + cos(u * 2) * 70, y: 68 - sin(u) * 38)
                        index == 0 ? path.move(to: p) : path.addLine(to: p)
                    }
                }
                .stroke(cyan.opacity(0.65), lineWidth: 2)

                Image(systemName: "airplane")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(gold)
                    .shadow(color: gold, radius: 6)
                    .position(point)

                Text("x(t) = 4 cos(2t)")
                    .position(x: 68, y: 124)
                Text("y(t) = 2 sin(t)")
                    .position(x: 155, y: 136)
            }
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A drone tracing a figure-eight from paired horizontal and vertical equations")
    }
}

struct LimitSensorConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = CGFloat((sin(timeline.date.timeIntervalSinceReferenceDate * 2.4) + 1) / 2)
            let leftX = 24 + phase * 70
            let rightX = 186 - phase * 70

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 18, y: 112))
                    path.addLine(to: CGPoint(x: 194, y: 112))
                    path.move(to: CGPoint(x: 105, y: 18))
                    path.addLine(to: CGPoint(x: 105, y: 122))
                    path.move(to: CGPoint(x: 20, y: 102))
                    path.addLine(to: CGPoint(x: 100, y: 53))
                    path.move(to: CGPoint(x: 110, y: 47))
                    path.addLine(to: CGPoint(x: 190, y: 8))
                }
                .stroke(.white.opacity(0.26), lineWidth: 2)

                Circle()
                    .stroke(gold, lineWidth: 3)
                    .frame(width: 14, height: 14)
                    .position(x: 105, y: 50)

                ForEach([leftX, rightX], id: \.self) { x in
                    let y = x < 105 ? 102 - (x - 20) * 0.61 : 47 - (x - 110) * 0.49
                    Circle().fill(cyan).frame(width: 10, height: 10).position(x: x, y: y)
                }

                Text("x → a⁻")
                    .position(x: 48, y: 132)
                Text("x → a⁺")
                    .position(x: 162, y: 132)
                Text("L")
                    .foregroundStyle(gold)
                    .position(x: 119, y: 50)
            }
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Two probes approaching the same missing sensor value from opposite sides")
    }
}

struct ContinuityPipelineConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 15, y: 94))
                    path.addQuadCurve(to: CGPoint(x: 105, y: 62), control: CGPoint(x: 62, y: 28))
                    path.addQuadCurve(to: CGPoint(x: 195, y: 42), control: CGPoint(x: 152, y: 93))
                }
                .stroke(.black.opacity(0.75), lineWidth: 18)
                Path { path in
                    path.move(to: CGPoint(x: 15, y: 94))
                    path.addQuadCurve(to: CGPoint(x: 105, y: 62), control: CGPoint(x: 62, y: 28))
                    path.addQuadCurve(to: CGPoint(x: 195, y: 42), control: CGPoint(x: 152, y: 93))
                }
                .trim(from: 0, to: progress)
                .stroke(cyan, style: StrokeStyle(lineWidth: 8, lineCap: .round))

                Circle().fill(gold).frame(width: 18, height: 18).position(x: 105, y: 62)
                Text("left limit = f(a) = right limit")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .position(x: 105, y: 127)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Water flowing through pipe sections that meet at a continuous junction")
    }
}

struct DerivativeSpeedConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4)
            let x = 24 + t * 162
            let y = 112 - t * t * 82
            let slope = 2 * t * 82 / 162

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 24, y: 112))
                    for index in 1...100 {
                        let u = CGFloat(index) / 100
                        path.addLine(to: CGPoint(x: 24 + u * 162, y: 112 - u * u * 82))
                    }
                }
                .stroke(gold.opacity(0.65), lineWidth: 3)

                Path { path in
                    path.move(to: CGPoint(x: x - 34, y: y + slope * 34))
                    path.addLine(to: CGPoint(x: x + 34, y: y - slope * 34))
                }
                .stroke(cyan, lineWidth: 3)

                Image(systemName: "car.side.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.radians(-atan(Double(slope))))
                    .position(x: x, y: y)

                Text("s′(t) = tangent slope")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .position(x: 105, y: 132)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A car moving along a distance-time curve with a changing tangent line")
    }
}

struct BubbleOptimizationConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let magenta = Color(red: 0.95, green: 0.34, blue: 0.68)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = CGFloat((sin(t * 1.4) + 1) / 2)
            let upper = CGPoint(x: 105, y: 47)
            let lower = CGPoint(x: 105, y: 84)

            Canvas { context, _ in
                func drawLobe(center: CGPoint, radius: CGFloat) {
                    let bubble = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    context.fill(bubble, with: .radialGradient(
                        Gradient(colors: [.white.opacity(0.14), cyan.opacity(0.30), Color(red: 0.02, green: 0.20, blue: 0.28).opacity(0.48), magenta.opacity(0.10)]),
                        center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.35),
                        startRadius: 1,
                        endRadius: radius
                    ))
                    context.stroke(bubble, with: .linearGradient(
                        Gradient(colors: [gold, cyan, .white.opacity(0.9), magenta, gold]),
                        startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
                        endPoint: CGPoint(x: center.x + radius, y: center.y + radius)
                    ), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                    for column in 0..<2 {
                        for row in 0..<2 {
                            let pane = CGRect(
                                x: center.x - radius * 0.42 + CGFloat(column) * radius * 0.18,
                                y: center.y - radius * 0.20 + CGFloat(row) * radius * 0.20,
                                width: radius * 0.13,
                                height: radius * 0.16
                            )
                            context.fill(Path(roundedRect: pane, cornerRadius: 1), with: .color(cyan.opacity(0.14)))
                        }
                    }
                    let shine = CGRect(x: center.x - radius * 0.46, y: center.y - radius * 0.48, width: radius * 0.38, height: radius * 0.12)
                    context.stroke(Path(ellipseIn: shine), with: .color(.white.opacity(0.68)), lineWidth: 1.5)
                }

                drawLobe(center: upper, radius: 44)
                drawLobe(center: lower, radius: 39)

                let membrane = Path(ellipseIn: CGRect(x: 66, y: 63, width: 78, height: 12))
                context.fill(membrane, with: .linearGradient(
                    Gradient(colors: [cyan.opacity(0.45), magenta.opacity(0.65 + Double(pulse) * 0.2), gold.opacity(0.55), cyan.opacity(0.42)]),
                    startPoint: CGPoint(x: 66, y: 69),
                    endPoint: CGPoint(x: 144, y: 69)
                ))
                context.stroke(membrane, with: .color(.white.opacity(0.58)), lineWidth: 1)
            }
            .frame(width: 210, height: 140)

            Text("V₁, V₂ fixed   ·   min Aₜₒₜₐₗ")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .position(x: 105, y: 126)
        }
        .accessibilityLabel("Two constant-volume bubble lobes connected by a shared minimum-area soap membrane")
    }
}

struct RainwaterIntegralConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4)

            Canvas { context, size in
                let plot = CGRect(x: 14, y: 18, width: 116, height: 92)
                let tank = CGRect(x: 151, y: 35, width: 44, height: 76)

                for index in 0..<12 {
                    let x = plot.minX + CGFloat(index) * plot.width / 12
                    let t = CGFloat(index) / 12
                    let height = 22 + 48 * t * t
                    let rect = CGRect(x: x, y: plot.maxY - height, width: plot.width / 12 - 1, height: height)
                    context.fill(Path(rect), with: .color(cyan.opacity(0.22)))
                }

                var curve = Path()
                for index in 0...40 {
                    let t = CGFloat(index) / 40
                    let point = CGPoint(x: plot.minX + t * plot.width, y: plot.maxY - 22 - 48 * t * t)
                    index == 0 ? curve.move(to: point) : curve.addLine(to: point)
                }
                context.stroke(curve, with: .color(gold), lineWidth: 2.5)

                let waterHeight = 12 + phase * 50
                let water = CGRect(x: tank.minX + 3, y: tank.maxY - waterHeight, width: tank.width - 6, height: waterHeight)
                context.fill(Path(water), with: .color(cyan.opacity(0.7)))
                context.stroke(Path(tank), with: .color(.white.opacity(0.75)), lineWidth: 2)
            }
            .overlay(alignment: .bottom) {
                Text("∫ rate · dt = volume")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Narrow slices beneath a rainfall rate curve accumulating as water in a reservoir")
    }
}

struct FundamentalTheoremConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.91)
    private let gold = Color(red: 1.0, green: 0.72, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6)

            Canvas { context, _ in
                let ratePlot = CGRect(x: 10, y: 12, width: 118, height: 52)
                let totalPlot = CGRect(x: 82, y: 78, width: 118, height: 48)

                var rateArea = Path()
                rateArea.move(to: CGPoint(x: ratePlot.minX, y: ratePlot.maxY))
                for sample in 0...50 {
                    let t = CGFloat(sample) / 50
                    guard t <= progress else { break }
                    let value = 0.36 + 0.42 * sin(t * .pi)
                    rateArea.addLine(to: CGPoint(x: ratePlot.minX + t * ratePlot.width, y: ratePlot.maxY - value * ratePlot.height))
                }
                rateArea.addLine(to: CGPoint(x: ratePlot.minX + progress * ratePlot.width, y: ratePlot.maxY))
                rateArea.closeSubpath()
                context.fill(rateArea, with: .color(cyan.opacity(0.25)))

                var rate = Path()
                var total = Path()
                for sample in 0...60 {
                    let t = CGFloat(sample) / 60
                    let rateValue = 0.36 + 0.42 * sin(t * .pi)
                    let totalValue = 0.18 + 0.70 * (0.36 * t + 0.42 / .pi * (1 - cos(t * .pi)))
                    let ratePoint = CGPoint(x: ratePlot.minX + t * ratePlot.width, y: ratePlot.maxY - rateValue * ratePlot.height)
                    let totalPoint = CGPoint(x: totalPlot.minX + t * totalPlot.width, y: totalPlot.maxY - totalValue * totalPlot.height)
                    sample == 0 ? rate.move(to: ratePoint) : rate.addLine(to: ratePoint)
                    sample == 0 ? total.move(to: totalPoint) : total.addLine(to: totalPoint)
                }
                context.stroke(rate, with: .color(cyan), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                context.stroke(total, with: .color(gold), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                let currentRate = 0.36 + 0.42 * sin(progress * .pi)
                let currentTotal = 0.18 + 0.70 * (0.36 * progress + 0.42 / .pi * (1 - cos(progress * .pi)))
                let ratePoint = CGPoint(x: ratePlot.minX + progress * ratePlot.width, y: ratePlot.maxY - currentRate * ratePlot.height)
                let totalPoint = CGPoint(x: totalPlot.minX + progress * totalPlot.width, y: totalPlot.maxY - currentTotal * totalPlot.height)
                context.fill(Path(ellipseIn: CGRect(x: ratePoint.x - 4, y: ratePoint.y - 4, width: 8, height: 8)), with: .color(gold))
                context.fill(Path(ellipseIn: CGRect(x: totalPoint.x - 4, y: totalPoint.y - 4, width: 8, height: 8)), with: .color(cyan))

                var connector = Path()
                connector.move(to: CGPoint(x: 58, y: 68))
                connector.addLine(to: CGPoint(x: 98, y: 76))
                context.stroke(connector, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))

                context.draw(Text("f(t)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(cyan), at: CGPoint(x: 22, y: 18))
                context.draw(Text("F(t)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(gold), at: CGPoint(x: 188, y: 86))
                context.draw(Text("∫").font(.system(size: 18, weight: .bold, design: .serif)).foregroundStyle(.white.opacity(0.72)), at: CGPoint(x: 68, y: 72))
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Flow rate area accumulating into a total whose derivative returns the flow rate")
    }
}

struct LogarithmicSoundConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
            let exponent = phase * 4
            let intensity = pow(10, exponent)
            let decibels = exponent * 10

            Canvas { context, size in
                let intensityTrack = CGRect(x: 35, y: 18, width: 42, height: 92)
                let decibelTrack = CGRect(x: 133, y: 18, width: 42, height: 92)
                context.fill(Path(roundedRect: intensityTrack, cornerRadius: 5), with: .color(.white.opacity(0.07)))
                context.fill(Path(roundedRect: decibelTrack, cornerRadius: 5), with: .color(.white.opacity(0.07)))

                let intensityHeight = intensityTrack.height * CGFloat((intensity - 1) / 9_999)
                let decibelHeight = decibelTrack.height * CGFloat(decibels / 40)
                context.fill(
                    Path(CGRect(x: intensityTrack.minX + 5, y: intensityTrack.maxY - intensityHeight, width: intensityTrack.width - 10, height: intensityHeight)),
                    with: .color(gold.opacity(0.72))
                )
                context.fill(
                    Path(CGRect(x: decibelTrack.minX + 5, y: decibelTrack.maxY - decibelHeight, width: decibelTrack.width - 10, height: decibelHeight)),
                    with: .color(cyan.opacity(0.72))
                )

                for step in 0...4 {
                    let y = decibelTrack.maxY - CGFloat(step) / 4 * decibelTrack.height
                    var tick = Path()
                    tick.move(to: CGPoint(x: decibelTrack.minX - 4, y: y))
                    tick.addLine(to: CGPoint(x: decibelTrack.maxX + 4, y: y))
                    context.stroke(tick, with: .color(.white.opacity(0.24)), lineWidth: 1)
                }
            }
            .overlay(alignment: .bottom) {
                Text("10× I  →  +10 dB")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Sound intensity growing by powers of ten while decibels increase in equal steps")
    }
}

struct ThermalEquationConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4)
            let progress = t / 4
            let current = 18 + (30 - 18) * exp(-0.7 * t)

            Canvas { context, size in
                let plot = CGRect(x: 14, y: 16, width: 180, height: 98)
                let ambientY = plot.maxY - CGFloat((18 - 14) / 20) * plot.height

                var ambient = Path()
                ambient.move(to: CGPoint(x: plot.minX, y: ambientY))
                ambient.addLine(to: CGPoint(x: plot.maxX, y: ambientY))
                context.stroke(ambient, with: .color(cyan.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

                var curve = Path()
                for index in 0...80 {
                    let time = 4 * Double(index) / 80
                    let temp = 18 + 12 * exp(-0.7 * time)
                    let point = CGPoint(
                        x: plot.minX + CGFloat(time / 4) * plot.width,
                        y: plot.maxY - CGFloat((temp - 14) / 20) * plot.height
                    )
                    index == 0 ? curve.move(to: point) : curve.addLine(to: point)
                }
                context.stroke(curve, with: .color(gold), lineWidth: 2.5)

                let point = CGPoint(
                    x: plot.minX + CGFloat(progress) * plot.width,
                    y: plot.maxY - CGFloat((current - 14) / 20) * plot.height
                )
                context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(coral))
            }
            .overlay(alignment: .bottom) {
                Text("rate slows as T → Tₐ")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A room temperature curve approaching ambient temperature with a decreasing rate")
    }
}

struct WeatherProbabilityConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)

    var body: some View {
        TimelineView(.animation) { timeline in
            let count = 20 + Int(timeline.date.timeIntervalSinceReferenceDate * 18) % 80

            Canvas { context, size in
                let root = CGPoint(x: 18, y: 66)
                let wet = CGPoint(x: 78, y: 38)
                let dry = CGPoint(x: 78, y: 94)
                let storm = CGPoint(x: 138, y: 22)
                let rain = CGPoint(x: 138, y: 54)

                for pair in [(root, wet), (root, dry), (wet, storm), (wet, rain)] {
                    var branch = Path()
                    branch.move(to: pair.0)
                    branch.addLine(to: pair.1)
                    context.stroke(branch, with: .color(.white.opacity(0.45)), lineWidth: 2)
                }

                for (point, color) in [(dry, gold), (rain, cyan), (storm, coral)] {
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(color))
                }

                for index in 0..<count {
                    let column = index % 10
                    let row = index / 10
                    let color: Color = index % 10 < 6 ? gold : index % 10 < 9 ? cyan : coral
                    let rect = CGRect(x: 154 + CGFloat(column) * 4.4, y: 22 + CGFloat(row) * 8, width: 3.5, height: 6)
                    context.fill(Path(rect), with: .color(color.opacity(0.85)))
                }
            }
            .overlay(alignment: .bottom) {
                Text("frequency → probability")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("A weather probability tree beside repeated experimental outcomes")
    }
}

struct FactoryStatisticsConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.8) / 2.8)

            Canvas { context, size in
                let belt = CGRect(x: 12, y: 38, width: 186, height: 48)
                context.fill(Path(belt), with: .color(.white.opacity(0.08)))
                context.stroke(Path(belt), with: .color(.white.opacity(0.3)), lineWidth: 2)

                for index in 0..<10 {
                    let x = belt.minX + ((CGFloat(index) / 10 + phase).truncatingRemainder(dividingBy: 1)) * belt.width
                    let selected = index == 1 || index == 5 || index == 8
                    let color = index == 8 ? coral : selected ? cyan : gold.opacity(0.55)
                    context.fill(Path(roundedRect: CGRect(x: x - 7, y: belt.midY - 8, width: 14, height: 16), cornerRadius: 2), with: .color(color))
                }

                let values: [CGFloat] = [0.28, 0.45, 0.52, 0.55, 0.62, 0.9]
                for (index, value) in values.enumerated() {
                    let x = 25 + value * 160
                    let y = 106 + CGFloat(index % 2) * 7
                    context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(index == values.count - 1 ? coral : cyan))
                }
            }
            .overlay(alignment: .bottom) {
                Text("sample → mean · median · spread")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Products moving on a conveyor while a sample becomes a statistical dot plot")
    }
}

struct InfiniteRainbowSeriesConceptVisual: View {
    private let gold = Color(red: 1.0, green: 0.70, blue: 0.18)
    private let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple]

    var body: some View {
        TimelineView(.animation) { timeline in
            let cycle = Int(timeline.date.timeIntervalSinceReferenceDate / 1.15) % 10
            let pairCount = cycle + 1
            let match = min(1, Double(pairCount) / 9)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height + 18)

                for colorIndex in colors.indices {
                    for band in 0..<7 {
                        let bandMatch = max(0, min(1, match * 1.35 - Double(band) * 0.08))
                        var arc = Path()
                        arc.addArc(
                            center: center,
                            radius: 82 + CGFloat(band) * 5 + CGFloat(colorIndex - 3) * 1.5,
                            startAngle: .degrees(205),
                            endAngle: .degrees(335),
                            clockwise: false
                        )
                        context.stroke(
                            arc,
                            with: .color(colors[colorIndex].opacity(0.04 + bandMatch * (0.34 - Double(band) * 0.025))),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                    }
                }

                let plot = CGRect(x: 18, y: 18, width: 174, height: 52)
                var target = Path()
                var partial = Path()
                for index in 0...90 {
                    let u = Double(index) / 90
                    let x = -4 + u * 6
                    let full = intensity(x, pairs: 12)
                    let approximation = intensity(x, pairs: pairCount)
                    let targetPoint = CGPoint(x: plot.minX + CGFloat(u) * plot.width, y: plot.maxY - CGFloat(min(1, full / 0.30)) * plot.height)
                    let partialPoint = CGPoint(x: plot.minX + CGFloat(u) * plot.width, y: plot.maxY - CGFloat(min(1, approximation / 0.30)) * plot.height)
                    index == 0 ? target.move(to: targetPoint) : target.addLine(to: targetPoint)
                    index == 0 ? partial.move(to: partialPoint) : partial.addLine(to: partialPoint)
                }
                context.stroke(target, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                context.stroke(partial, with: .color(gold), lineWidth: 1.8)
            }
            .overlay(alignment: .bottom) {
                Text("\(pairCount * 2) TERMS → \(Int(match * 100))%")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(gold)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("An Airy intensity partial sum converging toward a target curve while a rainbow interference pattern sharpens")
    }

    private func intensity(_ x: Double, pairs: Int) -> Double {
        var coefficients = Array(repeating: 0.0, count: 38)
        coefficients[0] = 0.355_028_053_887_817
        coefficients[1] = -0.258_819_403_792_807
        for index in 3..<coefficients.count {
            coefficients[index] = coefficients[index - 3] / Double(index * (index - 1))
        }

        let count = min(coefficients.count, 2 + max(0, pairs - 1) * 3)
        var value = 0.0
        var power = 1.0
        for index in 0..<count {
            value += coefficients[index] * power
            power *= x
        }
        return value * value
    }
}

struct ChaosControlledPendulumConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 7)
            let friction = 0.5 + 0.5 * sin(t * 0.24)
            let decay = exp(-friction * phase * 0.08)
            let pivot = CGPoint(x: 105, y: 22)
            let first = sin(t * 1.45) * 1.15 * decay
            let second = sin(t * 2.3 + cos(t * 0.7)) * 1.55 * decay

            Canvas { context, size in
                let middle = CGPoint(x: pivot.x + CGFloat(sin(first)) * 42, y: pivot.y + CGFloat(cos(first)) * 42)
                let end = CGPoint(x: middle.x + CGFloat(sin(second)) * 38, y: middle.y + CGFloat(cos(second)) * 38)

                var trail = Path()
                for index in 0...45 {
                    let earlier = t - Double(45 - index) * 0.035
                    let fade = exp(-friction * earlier.truncatingRemainder(dividingBy: 7) * 0.08)
                    let a = sin(earlier * 1.45) * 1.15 * fade
                    let b = sin(earlier * 2.3 + cos(earlier * 0.7)) * 1.55 * fade
                    let m = CGPoint(x: pivot.x + CGFloat(sin(a)) * 42, y: pivot.y + CGFloat(cos(a)) * 42)
                    let p = CGPoint(x: m.x + CGFloat(sin(b)) * 38, y: m.y + CGFloat(cos(b)) * 38)
                    index == 0 ? trail.move(to: p) : trail.addLine(to: p)
                }
                context.stroke(trail, with: .color(cyan.opacity(0.35)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

                var rods = Path()
                rods.move(to: pivot)
                rods.addLine(to: middle)
                rods.addLine(to: end)
                context.stroke(rods, with: .color(.white.opacity(0.84)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                context.fill(Path(ellipseIn: CGRect(x: middle.x - 5, y: middle.y - 5, width: 10, height: 10)), with: .color(coral))
                context.fill(Path(ellipseIn: CGRect(x: end.x - 7, y: end.y - 7, width: 14, height: 14)), with: .color(cyan))
                context.fill(Path(ellipseIn: CGRect(x: pivot.x - 4, y: pivot.y - 4, width: 8, height: 8)), with: .color(gold))
            }
            .overlay(alignment: .bottom) {
                Text("θ₀ · g · joint friction c")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("One double pendulum tracing a nonlinear path while launch angle, gravity, and middle-joint friction vary")
    }
}

struct ResilientCityConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.84, blue: 0.88)
    private let gold = Color(red: 1.0, green: 0.73, blue: 0.18)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)
    private let green = Color(red: 0.35, green: 0.86, blue: 0.55)

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.54)
                let stations = [
                    CGPoint(x: 24, y: 34),
                    CGPoint(x: size.width - 24, y: 34),
                    CGPoint(x: 26, y: size.height - 28),
                    CGPoint(x: size.width - 26, y: size.height - 28)
                ]
                let colors = [cyan, gold, coral, green]

                for index in stations.indices {
                    var route = Path()
                    route.move(to: stations[index])
                    route.addLine(to: center)
                    context.stroke(route, with: .color(colors[index].opacity(0.42)), lineWidth: 2)

                    let signal = CGPoint(
                        x: stations[index].x + (center.x - stations[index].x) * CGFloat(phase),
                        y: stations[index].y + (center.y - stations[index].y) * CGFloat(phase)
                    )
                    context.fill(Path(ellipseIn: CGRect(x: signal.x - 3, y: signal.y - 3, width: 6, height: 6)), with: .color(colors[index]))
                    context.fill(Path(ellipseIn: CGRect(x: stations[index].x - 8, y: stations[index].y - 8, width: 16, height: 16)), with: .color(colors[index]))
                }

                let widths: [CGFloat] = [20, 27, 18, 32, 24]
                let heights: [CGFloat] = [35, 54, 44, 66, 40]
                for index in widths.indices {
                    let x = center.x - 68 + CGFloat(index) * 27
                    let building = CGRect(x: x, y: center.y - heights[index] / 2, width: widths[index], height: heights[index])
                    context.fill(Path(building), with: .color(Color(red: 0.06, green: 0.13, blue: 0.16)))
                    context.stroke(Path(building), with: .color(green.opacity(0.7)), lineWidth: 1)
                }

                context.draw(Text("f(t)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(cyan), at: stations[0])
                context.draw(Text("G(V,E)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(gold), at: stations[1])
                context.draw(Text("ΣpL").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(coral), at: stations[2])
                context.draw(Text("R′(t)").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundColor(green), at: stations[3])
            }
            .overlay(alignment: .bottom) {
                Text("MODELS COORDINATE ONE SYSTEM")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Four mathematical models sending information into one connected city")
    }
}

private struct ConceptCardBody<Buttons: View>: View {
    @Environment(\.mathItAccent) private var accent
    let header: String?
    let concept: LevelConcept
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let header {
                    Text(header)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(accent.opacity(0.7))
                }

                Text(concept.title)
                    .font(.trajan(22))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 330, minHeight: 52)

                concept.visual
                    .frame(width: 210, height: 140)

                Text(concept.description)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 34)

                if let formula = concept.formula, !formula.isEmpty {
                    Text(formula)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .tracking(1)
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 28)
                }

                buttons()
                    .padding(.top, 4)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity)
        }
    }
}

func conceptCapsuleButton(_ title: String, filled: Bool, accent: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 17, weight: .semibold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(filled ? .black : accent)
            .frame(width: 178, height: 48)
            .background(filled ? accent : .clear, in: Capsule())
            .overlay { Capsule().stroke(accent.opacity(filled ? 0 : 0.68), lineWidth: 1.2) }
    }
    .buttonStyle(.plain)
}

struct ConceptCompletionOverlay: View {
    @Environment(\.mathItAccent) private var accent
    @Environment(\.mathItLevelNumber) private var levelNumber
    @Environment(\.mathItCompletionConceptDismissed) private var conceptDismissed
    @Environment(\.mathItLevelContentInset) private var contentInset

    let levelTitle: String
    let concept: LevelConcept
    let isVisible: Bool
    let onContinue: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    private var displayedConcept: LevelConcept {
        guard let levelNumber else { return concept }
        let screenLevel = MathItCurriculum.screenLevel(forLevelNumber: levelNumber) ?? levelNumber
        return ConceptLibrary.concept(for: screenLevel) ?? concept
    }

    var body: some View {
        ZStack {
            if isVisible && !conceptDismissed {
                Color.black.opacity(0.9).ignoresSafeArea().transition(.opacity)

                ConceptCardBody(header: levelTitle, concept: displayedConcept) {
                    VStack(spacing: 10) {
                        conceptCapsuleButton("Continue", filled: true, accent: accent, action: onContinue)
                        conceptCapsuleButton("Replay", filled: false, accent: accent, action: onReplay)
                        conceptCapsuleButton("Levels", filled: false, accent: accent, action: onLevelSelect)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .preference(key: MathItCompletionOverlayActiveKey.self, value: isVisible)
        .animation(.spring(response: 0.7, dampingFraction: 0.86), value: isVisible && !conceptDismissed)
        .offset(y: -contentInset / 2)
    }
}

// On-demand concept card (opened from the info button during play).
struct ConceptInfoOverlay: View {
    @Environment(\.mathItAccent) private var accent

    let concept: LevelConcept
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea().onTapGesture(perform: onClose)

            ConceptCardBody(header: nil, concept: concept) {
                Button(action: onClose) {
                    Text("Close")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(accent)
                        .frame(width: 178, height: 48)
                        .overlay { Capsule().stroke(accent.opacity(0.68), lineWidth: 1.2) }
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(1_150)
    }
}

// Concept / infographic button — sits beside the hint button.
struct InfoButton: View {
    @Environment(\.mathItAccent) private var accent

    let isActive: Bool
    let action: () -> Void

    init(isActive: Bool = false, action: @escaping () -> Void) {
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "lightbulb.fill" : "lightbulb")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.48), radius: 7)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Concept")
        .zIndex(1_100)
    }
}

// MARK: - Concept visuals (small looping animations)

// Level 1 — reflection & equality (1 = 1): the reflected "1" slides out of the
// mirror, glows, then fades and repeats.
struct ReflectionConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let p = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6
            let emerge = min(p / 0.45, 1)
            let e = 1 - pow(1 - emerge, 3)                      // ease-out
            let fade = p > 0.8 ? (1 - (p - 0.8) / 0.2) : 1      // fade out at the end
            let reflX: CGFloat = 105 + 33 * CGFloat(e)
            let reflOpacity = e * fade

            ZStack {
                Rectangle().fill(.white.opacity(0.5)).frame(width: 2, height: 108).position(x: 105, y: 70)

                Path { pth in pth.move(to: CGPoint(x: 72, y: 70)); pth.addLine(to: CGPoint(x: reflX, y: 70)) }
                    .stroke(.white.opacity(0.28 * reflOpacity), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                Text("1").font(.system(size: 46, design: .serif)).foregroundStyle(Color.mathGold)
                    .position(x: 72, y: 66)
                    .shadow(color: Color.mathGold.opacity(0.55), radius: 9)

                Text("1").font(.system(size: 46, design: .serif)).foregroundStyle(.white)
                    .scaleEffect(x: -1, y: 1)
                    .position(x: reflX, y: 66)
                    .opacity(reflOpacity)
                    .shadow(color: .white.opacity(0.7 * reflOpacity), radius: 9)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 2 — the number line (+1 each step).
struct NumberLineConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let step = Int(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6))
            GeometryReader { geo in
                let x0: CGFloat = 22, x1 = geo.size.width - 22, y: CGFloat = 78
                let dx = x0 + (x1 - x0) * CGFloat(step) / 5
                ZStack {
                    Path { p in p.move(to: CGPoint(x: x0, y: y)); p.addLine(to: CGPoint(x: x1, y: y)) }
                        .stroke(.white.opacity(0.6), lineWidth: 2)
                    ForEach(0...5, id: \.self) { i in
                        let x = x0 + (x1 - x0) * CGFloat(i) / 5
                        Rectangle().fill(.white.opacity(0.5)).frame(width: 2, height: 12).position(x: x, y: y)
                        Text("\(i)").font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55)).position(x: x, y: y + 18)
                    }
                    Text("+1").font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.mathGold).position(x: dx, y: y - 24)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: step)
                    Circle().fill(Color.mathGold).frame(width: 16, height: 16)
                        .shadow(color: Color.mathGold.opacity(0.7), radius: 8).position(x: dx, y: y)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: step)
                }
            }
        }
        .frame(width: 210, height: 140)
    }
}

// Level 3 — Sun, Earth, and Moon geometry makes visible fractions.
struct LunarPhaseConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5.2) / 5.2
            let angle = CGFloat(t * 2 * .pi)
            let fraction = min(1, max(0, (1 + cos(angle)) / 2))
            GeometryReader { geo in
                let earth = CGPoint(x: geo.size.width * 0.53, y: geo.size.height * 0.55)
                let orbit: CGFloat = min(geo.size.width, geo.size.height) * 0.31
                let moon = CGPoint(x: earth.x + cos(angle) * orbit, y: earth.y + sin(angle) * orbit * 0.62)
                let sun = CGPoint(x: geo.size.width * 0.14, y: earth.y - 10)
                let moonR: CGFloat = 16

                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: sun.x + 16, y: sun.y))
                        p.addLine(to: CGPoint(x: geo.size.width + 20, y: earth.y - 45))
                        p.move(to: CGPoint(x: sun.x + 16, y: sun.y))
                        p.addLine(to: CGPoint(x: geo.size.width + 20, y: earth.y + 45))
                    }
                    .stroke(Color.mathGold.opacity(0.12), lineWidth: 2)

                    Circle()
                        .fill(Color.mathGold)
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.mathGold.opacity(0.7), radius: 12)
                        .position(sun)

                    Ellipse()
                        .stroke(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1.4, dash: [5, 6]))
                        .frame(width: orbit * 2, height: orbit * 1.24)
                        .position(earth)

                    Circle()
                        .fill(RadialGradient(colors: [Color(red: 0.24, green: 0.68, blue: 1), Color(red: 0.02, green: 0.07, blue: 0.2)], center: .topLeading, startRadius: 2, endRadius: 24))
                        .frame(width: 42, height: 42)
                        .position(earth)

                    ZStack {
                        Circle().fill(Color(red: 0.06, green: 0.065, blue: 0.08))
                        ConceptLunarIlluminationShape(fraction: fraction, waxing: sin(angle) > 0)
                            .fill(.white.opacity(0.92))
                            .clipShape(Circle())
                        Circle().stroke(Color.mathGold.opacity(0.5), lineWidth: 1.2)
                    }
                    .frame(width: moonR * 2, height: moonR * 2)
                    .position(moon)
                    .shadow(color: Color.mathGold.opacity(0.4), radius: 6)

                    Text("\(Int((fraction * 100).rounded()))% visible")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(Color.mathGold.opacity(0.82))
                        .position(x: earth.x, y: geo.size.height - 14)
                }
            }
        }
        .frame(width: 210, height: 140)
    }
}

private struct ConceptLunarIlluminationShape: Shape {
    var fraction: CGFloat
    var waxing: Bool

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let f = min(1, max(0, fraction))
        guard f > 0.01 else { return Path() }
        if f >= 0.99 { return Circle().path(in: rect) }
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let litRight = waxing
        let bulge = (f - 0.5) * 2
        let innerX = c.x - (litRight ? 1 : -1) * bulge * r
        let top = CGPoint(x: c.x, y: c.y - r)
        var path = Path()
        path.move(to: top)
        path.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: !litRight)
        path.addQuadCurve(to: top, control: CGPoint(x: innerX, y: c.y))
        path.closeSubpath()
        return path
    }
}

// Reflection makes identical copies that stack into equal steps.
struct CascadeConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let phase = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
            GeometryReader { geo in
                let baseY = geo.size.height - 20
                let cols: [CGFloat] = [1, 2, 3]
                let stepW: CGFloat = 34, unit: CGFloat = 22
                let startX = geo.size.width / 2 - stepW * 1.5
                let ballCol = min(Int(phase * 3.2), 2)
                ZStack {
                    ForEach(0..<3, id: \.self) { c in
                        let h = cols[c]
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.mathGold.opacity(0.85), lineWidth: 1.4)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.mathGold.opacity(0.14)))
                            .frame(width: unit, height: unit * h)
                            .position(x: startX + stepW * (CGFloat(c) + 0.5), y: baseY - unit * h / 2)
                    }
                    // ball hopping down the descending steps (col 2 tallest → col 0)
                    let bc = 2 - ballCol
                    let topY = baseY - unit * cols[bc]
                    Circle().fill(.white).frame(width: 14, height: 14)
                        .shadow(color: .white.opacity(0.6), radius: 6)
                        .position(x: startX + stepW * (CGFloat(bc) + 0.5), y: topY - 10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: ballCol)
                }
            }
        }
        .frame(width: 210, height: 140)
    }
}

// Level 4 — projectile arc + equal bounce angles.
struct ProjectileConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let s = CGFloat(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let wallX = w * 0.7, ground = h - 18
                let p0 = CGPoint(x: 20, y: ground), p1 = CGPoint(x: wallX, y: ground * 0.5)
                let p2 = CGPoint(x: w * 0.34, y: ground)
                let ball = projectileBall(progress: s, p0: p0, p1: p1, p2: p2)
                ZStack {
                    Rectangle().fill(.white.opacity(0.6)).frame(width: 3, height: h * 0.5).position(x: wallX, y: ground * 0.75)
                    // dotted trajectory
                    Path { p in
                        p.move(to: p0)
                        for i in 0...20 { p.addLine(to: projectileArc(CGFloat(i) / 20, from: p0, to: p1)) }
                        for i in 0...20 { p.addLine(to: projectileArc(CGFloat(i) / 20, from: p1, to: p2)) }
                    }.stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    Circle().fill(Color.mathGold).frame(width: 13, height: 13)
                        .shadow(color: Color.mathGold.opacity(0.7), radius: 6).position(ball)
                }
            }
        }
        .frame(width: 210, height: 140)
    }

    private func projectileBall(progress: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        if progress < 0.5 {
            return projectileArc(progress / 0.5, from: p0, to: p1)
        }
        return projectileArc((progress - 0.5) / 0.5, from: p1, to: p2)
    }

    private func projectileArc(_ u: CGFloat, from a: CGPoint, to b: CGPoint, peak: CGFloat = 46) -> CGPoint {
        let x = a.x + (b.x - a.x) * u
        let base = a.y + (b.y - a.y) * u
        let lift = 4 * peak * u * (1 - u)
        return CGPoint(x: x, y: base - lift)
    }
}

// Level 5 — circle: radius, diameter, circumference.
struct CircleConceptVisual: View {
    @State private var ang: Double = 0
    var body: some View {
        ZStack {
            Circle().stroke(Color.mathGold, lineWidth: 2).frame(width: 112, height: 112)
            Circle().fill(.white.opacity(0.7)).frame(width: 6, height: 6)
            // rotating diameter
            Capsule().fill(.white.opacity(0.85)).frame(width: 112, height: 2).rotationEffect(.degrees(ang))
            Circle().fill(Color.mathGold).frame(width: 9, height: 9)
                .offset(x: 56).rotationEffect(.degrees(ang))
            Circle().fill(Color.mathGold).frame(width: 9, height: 9)
                .offset(x: -56).rotationEffect(.degrees(ang))
            Text("d").font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.8)).offset(y: -12)
        }
        .frame(width: 210, height: 140)
        .onAppear { withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { ang = 360 } }
    }
}

// Level 4 — an angle: a rotating ray sweeping direction from a fixed one.
struct AngleConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let deg = 46 + 38 * sin(t * 0.9)              // oscillate ~8°…84°
            let r = deg * .pi / 180
            let vertex = CGPoint(x: 52, y: 100)
            let len: CGFloat = 128
            let fixedEnd = CGPoint(x: vertex.x + len, y: vertex.y)
            let rayEnd = CGPoint(x: vertex.x + CGFloat(cos(r)) * len, y: vertex.y - CGFloat(sin(r)) * len)

            ZStack {
                Path { p in p.move(to: vertex); p.addLine(to: fixedEnd) }
                    .stroke(.white.opacity(0.55), lineWidth: 2)

                Path { p in p.move(to: vertex); p.addLine(to: rayEnd) }
                    .stroke(Color.mathGold, lineWidth: 2.5)
                    .shadow(color: Color.mathGold.opacity(0.6), radius: 6)

                // minor arc between the two rays
                Path { p in
                    let steps = 24
                    for i in 0...steps {
                        let a = -r * Double(i) / Double(steps)
                        let pt = CGPoint(x: vertex.x + CGFloat(cos(a)) * 34, y: vertex.y + CGFloat(sin(a)) * 34)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }.stroke(.white.opacity(0.7), lineWidth: 1.5)

                Circle().fill(.white).frame(width: 6, height: 6).position(vertex)

                Text("\(Int(deg.rounded()))°")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .position(x: vertex.x + 54, y: vertex.y - 18)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 100 — equal sectors connect circumference, radians, and arc length.
struct ArcLengthConceptVisual: View {
    private let cyan = Color(red: 0.20, green: 0.86, blue: 0.94)
    private let tomato = Color(red: 0.91, green: 0.23, blue: 0.16)

    var body: some View {
        TimelineView(.animation) { timeline in
            let pulse = CGFloat((sin(timeline.date.timeIntervalSinceReferenceDate * 2.2) + 1) / 2)

            ZStack {
                Canvas { context, _ in
                    let center = CGPoint(x: 105, y: 72)
                    let radius: CGFloat = 52
                    let plate = CGRect(x: center.x - 62, y: center.y - 62, width: 124, height: 124)
                    context.fill(Path(ellipseIn: plate), with: .color(.white.opacity(0.08)))
                    context.stroke(Path(ellipseIn: plate), with: .color(.white.opacity(0.15)), lineWidth: 1)

                    for index in 0..<6 {
                        let start = -90.0 + Double(index) * 60
                        let end = start + 60
                        let middle = (start + end) / 2 * .pi / 180
                        let lift = index == 0 ? pulse * 5 : 0
                        let offset = CGVector(dx: cos(middle) * lift, dy: sin(middle) * lift)
                        let sliceCenter = CGPoint(x: center.x + offset.dx, y: center.y + offset.dy)
                        let wedge = wedgePath(center: sliceCenter, radius: radius, startDegrees: start, endDegrees: end)
                        context.fill(wedge, with: .radialGradient(
                            Gradient(colors: [
                                index == 0 ? Color.mathGold : tomato,
                                index == 0 ? Color.mathGold.opacity(0.72) : tomato.opacity(0.58)
                            ]),
                            center: sliceCenter,
                            startRadius: 2,
                            endRadius: radius
                        ))
                        context.stroke(wedge, with: .color(.black.opacity(0.72)), lineWidth: 2)
                    }

                    let highlightAngle = CGFloat(-60.0 * Double.pi / 180)
                    let highlightedCenter = CGPoint(
                        x: center.x + cos(highlightAngle) * pulse * 5,
                        y: center.y + sin(highlightAngle) * pulse * 5
                    )
                    let outerArc = arcPath(center: highlightedCenter, radius: radius + 2, startDegrees: -90, endDegrees: -30)
                    context.stroke(outerArc, with: .color(cyan), style: StrokeStyle(lineWidth: 4, lineCap: .round))

                    var radiusLine = Path()
                    radiusLine.move(to: highlightedCenter)
                    radiusLine.addLine(to: point(center: highlightedCenter, radius: radius, degrees: -90))
                    context.stroke(radiusLine, with: .color(.white.opacity(0.82)), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))

                    let angleArc = arcPath(center: highlightedCenter, radius: 17, startDegrees: -90, endDegrees: -30)
                    context.stroke(angleArc, with: .color(Color.mathGold), lineWidth: 2)
                    context.fill(Path(ellipseIn: CGRect(x: highlightedCenter.x - 3, y: highlightedCenter.y - 3, width: 6, height: 6)), with: .color(.white))
                }

                Text("s")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)
                    .position(x: 135, y: 20)

                Text("r")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .position(x: 106, y: 44)

                Text("θ")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 123, y: 61)
            }
            .frame(width: 210, height: 140)
        }
    }

    private func point(center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    }

    private func wedgePath(center: CGPoint, radius: CGFloat, startDegrees: Double, endDegrees: Double) -> Path {
        var path = Path()
        path.move(to: center)
        let samples = 24
        for sample in 0...samples {
            let fraction = Double(sample) / Double(samples)
            let degrees = startDegrees + (endDegrees - startDegrees) * fraction
            path.addLine(to: point(center: center, radius: radius, degrees: degrees))
        }
        path.closeSubpath()
        return path
    }

    private func arcPath(center: CGPoint, radius: CGFloat, startDegrees: Double, endDegrees: Double) -> Path {
        var path = Path()
        let samples = 24
        for sample in 0...samples {
            let fraction = Double(sample) / Double(samples)
            let degrees = startDegrees + (endDegrees - startDegrees) * fraction
            let position = point(center: center, radius: radius, degrees: degrees)
            sample == 0 ? path.move(to: position) : path.addLine(to: position)
        }
        return path
    }
}

// Level 6 — the same motion viewed from inertial and rotating frames.
struct CoriolisConceptVisual: View {
    private let earth = Color(red: 0.28, green: 0.55, blue: 0.95)
    private let cyan = Color(red: 0.22, green: 0.86, blue: 0.94)
    private let coral = Color(red: 1.0, green: 0.35, blue: 0.29)

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let rotation = CGFloat(time.truncatingRemainder(dividingBy: 8) / 8) * 2 * CGFloat.pi
            let travel = CGFloat(time.truncatingRemainder(dividingBy: 3.2) / 3.2)

            ZStack {
                Canvas { context, _ in
                    let center = CGPoint(x: 105, y: 70)
                    let radius: CGFloat = 53
                    let globeRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

                    context.fill(Path(ellipseIn: globeRect), with: .radialGradient(
                        Gradient(colors: [earth.opacity(0.9), earth.opacity(0.32), .black.opacity(0.88)]),
                        center: CGPoint(x: center.x - 16, y: center.y - 18),
                        startRadius: 2,
                        endRadius: radius * 1.12
                    ))

                    context.drawLayer { grid in
                        grid.clip(to: Path(ellipseIn: globeRect))
                        for ring in 1...3 {
                            let ringRadius = radius * CGFloat(ring) / 4
                            let rect = CGRect(
                                x: center.x - ringRadius,
                                y: center.y - ringRadius,
                                width: ringRadius * 2,
                                height: ringRadius * 2
                            )
                            grid.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.14)), lineWidth: 0.8)
                        }

                        for spoke in 0..<8 {
                            let angle = rotation + CGFloat(spoke) / 8 * 2 * .pi
                            var line = Path()
                            line.move(to: center)
                            line.addLine(to: CGPoint(
                                x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius
                            ))
                            grid.stroke(line, with: .color(.white.opacity(0.18)), lineWidth: 0.8)
                        }
                    }

                    context.stroke(Path(ellipseIn: globeRect), with: .color(cyan.opacity(0.7)), lineWidth: 1.4)

                    let start = CGPoint(x: 68, y: 108)
                    let end = CGPoint(x: 148, y: 35)
                    let control = CGPoint(x: 153, y: 103)

                    var inertial = Path()
                    inertial.move(to: start)
                    inertial.addLine(to: end)
                    context.stroke(inertial, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))

                    var observed = Path()
                    observed.move(to: start)
                    observed.addQuadCurve(to: end, control: control)
                    context.stroke(observed, with: .color(Color.mathGold.opacity(0.95)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                    let particle = quadraticPoint(from: start, control: control, to: end, t: travel)
                    context.fill(Path(ellipseIn: CGRect(x: particle.x - 4, y: particle.y - 4, width: 8, height: 8)), with: .color(coral))
                    context.addFilter(.shadow(color: coral.opacity(0.85), radius: 5))
                    context.stroke(Path(ellipseIn: CGRect(x: particle.x - 4, y: particle.y - 4, width: 8, height: 8)), with: .color(.white.opacity(0.9)), lineWidth: 1)

                    let arrowRadius = radius + 8
                    var rotationArrow = Path()
                    rotationArrow.addArc(center: center, radius: arrowRadius, startAngle: .degrees(205), endAngle: .degrees(318), clockwise: false)
                    context.stroke(rotationArrow, with: .color(cyan.opacity(0.75)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

                    let tipAngle = CGFloat(318) * .pi / 180
                    let tip = CGPoint(x: center.x + cos(tipAngle) * arrowRadius, y: center.y + sin(tipAngle) * arrowRadius)
                    var arrowHead = Path()
                    arrowHead.move(to: tip)
                    arrowHead.addLine(to: CGPoint(x: tip.x - 8, y: tip.y + 1))
                    arrowHead.addLine(to: CGPoint(x: tip.x - 3, y: tip.y + 7))
                    arrowHead.closeSubpath()
                    context.fill(arrowHead, with: .color(cyan.opacity(0.85)))
                }

                Text("Ω")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)
                    .position(x: 40, y: 108)

                Text("v")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                    .position(x: 97, y: 62)

                Text("aᶜ")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 155, y: 82)
            }
            .frame(width: 210, height: 140)
        }
    }

    private func quadraticPoint(from start: CGPoint, control: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            y: oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }
}

// Level 7 — Nim: rows of matches, the last two of a row taken each loop.
struct NimConceptVisual: View {
    private let rows = [3, 4, 5]
    private let targetRow = 1
    private let removeCount = 2

    var body: some View {
        TimelineView(.animation) { ctx in
            let phase = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
            VStack(spacing: 12) {
                ForEach(0..<rows.count, id: \.self) { r in
                    HStack(spacing: 9) {
                        ForEach(0..<rows[r], id: \.self) { i in
                            let isTarget = r == targetRow && i >= rows[r] - removeCount
                            let opacity: Double = {
                                if !isTarget { return 1 }
                                if phase < 0.5 { return 1 }
                                if phase < 0.8 { return max(0, 1 - (phase - 0.5) / 0.3) }
                                return 0
                            }()
                            match(highlight: isTarget && phase < 0.5, opacity: opacity)
                        }
                    }
                }
            }
            .frame(width: 210, height: 140)
        }
    }

    private func match(highlight: Bool, opacity: Double) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(highlight ? Color.mathGold : Color(red: 1.0, green: 0.36, blue: 0.24))
                .frame(width: 7, height: 7)
            Capsule()
                .fill(highlight ? Color.mathGold.opacity(0.85) : .white.opacity(0.82))
                .frame(width: 5, height: 26)
        }
        .opacity(opacity)
    }
}

// Level 9 — a lens focusing parallel rays to a single focal point.
struct LensConceptVisual: View {
    private let ys: [CGFloat] = [42, 56, 70, 84, 98]
    private let leftX: CGFloat = 12
    private let lensX: CGFloat = 100
    private let focal = CGPoint(x: 174, y: 70)

    var body: some View {
        TimelineView(.animation) { ctx in
            let u = CGFloat(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.0) / 2.0)
            ZStack {
                // ray paths (parallel in, converging out)
                ForEach(ys.indices, id: \.self) { i in
                    Path { p in
                        p.move(to: CGPoint(x: leftX, y: ys[i]))
                        p.addLine(to: CGPoint(x: lensX, y: ys[i]))
                        p.addLine(to: focal)
                    }
                    .stroke(Color.mathGold.opacity(0.32), lineWidth: 1)
                }

                // lens
                ZStack {
                    Ellipse().fill(Color(red: 0.6, green: 0.8, blue: 1.0).opacity(0.14))
                    Ellipse().stroke(Color.mathGold, lineWidth: 2)
                }
                .frame(width: 20, height: 96)
                .position(x: lensX, y: 70)

                // light pulse travelling along each ray to the focal point
                ForEach(ys.indices, id: \.self) { i in
                    let pos: CGPoint = u < 0.5
                        ? CGPoint(x: leftX + (lensX - leftX) * (u / 0.5), y: ys[i])
                        : CGPoint(x: lensX + (focal.x - lensX) * ((u - 0.5) / 0.5),
                                  y: ys[i] + (focal.y - ys[i]) * ((u - 0.5) / 0.5))
                    Circle().fill(.white).frame(width: 5, height: 5)
                        .shadow(color: .white.opacity(0.7), radius: 3)
                        .position(pos)
                }

                // focal point, brightening as the pulses arrive
                Circle().fill(Color.mathGold).frame(width: 9, height: 9)
                    .shadow(color: Color.mathGold.opacity(0.85), radius: 4 + 10 * Double(u))
                    .position(focal)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 11 — a balance scale rocking through its three outcomes.
struct BalanceConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let angle = 13 * sin(ctx.date.timeIntervalSinceReferenceDate * 1.1)
            ZStack {
                // fulcrum + base
                Path { p in
                    p.move(to: CGPoint(x: 105, y: 58))
                    p.addLine(to: CGPoint(x: 92, y: 104))
                    p.addLine(to: CGPoint(x: 118, y: 104))
                    p.closeSubpath()
                }
                .fill(Color.mathGold.opacity(0.5))
                Capsule().fill(.white.opacity(0.4)).frame(width: 64, height: 3).position(x: 105, y: 106)

                // beam + hanging pans (rotate as one)
                ZStack {
                    Capsule().fill(Color.mathGold).frame(width: 132, height: 4)
                    pan().offset(x: -60, y: 13)
                    pan().offset(x: 60, y: 13)
                }
                .rotationEffect(.degrees(angle))
                .position(x: 105, y: 58)
            }
            .frame(width: 210, height: 140)
        }
    }

    private func pan() -> some View {
        VStack(spacing: 2) {
            Rectangle().fill(.white.opacity(0.5)).frame(width: 1.5, height: 14)
            HStack(spacing: 2) {
                Circle().fill(.white.opacity(0.85)).frame(width: 8, height: 8)
                Circle().fill(.white.opacity(0.85)).frame(width: 8, height: 8)
            }
        }
    }
}

// Level 12 — graph theory: a dot tracing every edge of a graph once.
struct GraphConceptVisual: View {
    private let nodes: [CGPoint] = [
        CGPoint(x: 45, y: 55), CGPoint(x: 105, y: 28), CGPoint(x: 165, y: 55),
        CGPoint(x: 140, y: 108), CGPoint(x: 70, y: 108)
    ]

    var body: some View {
        TimelineView(.animation) { ctx in
            let n = nodes.count
            let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0) / 3.0
            let prog = u * Double(n)
            let seg = min(Int(prog), n - 1)
            let localT = CGFloat(prog - Double(seg))
            let a = nodes[seg], b = nodes[(seg + 1) % n]
            let dot = CGPoint(x: a.x + (b.x - a.x) * localT, y: a.y + (b.y - a.y) * localT)

            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    let p0 = nodes[i], p1 = nodes[(i + 1) % n]
                    Path { p in p.move(to: p0); p.addLine(to: p1) }
                        .stroke(i <= seg ? Color.mathGold : .white.opacity(0.25),
                                lineWidth: i <= seg ? 2 : 1.2)
                }
                ForEach(nodes.indices, id: \.self) { i in
                    Circle().fill(.white).frame(width: 11, height: 11)
                        .shadow(color: .white.opacity(0.4), radius: 3)
                        .position(nodes[i])
                }
                Circle().fill(Color.mathGold).frame(width: 9, height: 9)
                    .shadow(color: Color.mathGold.opacity(0.8), radius: 5)
                    .position(dot)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 15 — a vibrating string marked at the harmonic ratios.
struct StringRatioConceptVisual: View {
    private let x0: CGFloat = 26
    private let x1: CGFloat = 184
    private let midY: CGFloat = 70

    var body: some View {
        TimelineView(.animation) { ctx in
            let amp = 18 * sin(ctx.date.timeIntervalSinceReferenceDate * 7)
            ZStack {
                Path { p in
                    let steps = 60
                    for i in 0...steps {
                        let f = CGFloat(i) / CGFloat(steps)
                        let x = x0 + (x1 - x0) * f
                        let y = midY - CGFloat(amp) * sin(.pi * Double(f))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.mathGold, lineWidth: 2)
                .shadow(color: Color.mathGold.opacity(0.5), radius: 5)

                Circle().fill(.white).frame(width: 7, height: 7).position(x: x0, y: midY)
                Circle().fill(.white).frame(width: 7, height: 7).position(x: x1, y: midY)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 18 — an AND gate cycling through its truth table.
struct LogicConceptVisual: View {
    private let gateLeft: CGFloat = 84
    private let gateRight: CGFloat = 126
    private let top: CGFloat = 50
    private let bot: CGFloat = 90
    private var cy: CGFloat { (top + bot) / 2 }

    var body: some View {
        TimelineView(.animation) { ctx in
            let combo = min(Int(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6 * 4), 3)
            let a = (combo >> 1) & 1
            let b = combo & 1
            let out = a & b
            let yA: CGFloat = 60, yB: CGFloat = 80
            let tip = CGPoint(x: gateRight + (bot - top) / 2, y: cy)

            ZStack {
                wire(CGPoint(x: 44, y: yA), CGPoint(x: gateLeft, y: yA), on: a == 1)
                wire(CGPoint(x: 44, y: yB), CGPoint(x: gateLeft, y: yB), on: b == 1)
                wire(tip, CGPoint(x: 182, y: cy), on: out == 1)

                gatePath().fill(Color.mathGold.opacity(0.12))
                gatePath().stroke(Color.mathGold, lineWidth: 2)

                Text("AND").font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .position(x: (gateLeft + gateRight) / 2, y: cy)

                bit(a, CGPoint(x: 36, y: yA))
                bit(b, CGPoint(x: 36, y: yB))
                bit(out, CGPoint(x: 192, y: cy))
            }
            .frame(width: 210, height: 140)
        }
    }

    private func gatePath() -> Path {
        Path { p in
            let r = (bot - top) / 2
            p.move(to: CGPoint(x: gateLeft, y: top))
            p.addLine(to: CGPoint(x: gateRight, y: top))
            let steps = 24
            for i in 0...steps {
                let ang = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
                p.addLine(to: CGPoint(x: gateRight + CGFloat(cos(ang)) * r, y: cy + CGFloat(sin(ang)) * r))
            }
            p.addLine(to: CGPoint(x: gateLeft, y: bot))
            p.closeSubpath()
        }
    }

    private func wire(_ a: CGPoint, _ b: CGPoint, on: Bool) -> some View {
        Path { p in p.move(to: a); p.addLine(to: b) }
            .stroke(on ? Color.mathGold : .white.opacity(0.3), lineWidth: on ? 2.5 : 1.4)
    }

    private func bit(_ v: Int, _ p: CGPoint) -> some View {
        Text("\(v)")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(v == 1 ? Color.mathGold : .white.opacity(0.5))
            .position(p)
    }
}

// Level 19 — a sine wave rising from the midline.
struct PrismConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let phase = ctx.date.timeIntervalSinceReferenceDate * 1.7
            let midY: CGFloat = 72
            let amp: CGFloat = 34
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 16, y: midY))
                    p.addLine(to: CGPoint(x: 194, y: midY))
                }
                .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                Path { p in
                    p.move(to: CGPoint(x: 60, y: midY))
                    p.addLine(to: CGPoint(x: 60, y: midY - amp))
                }
                .stroke(Color(red: 0.45, green: 0.78, blue: 1.0).opacity(0.85), lineWidth: 2)

                Path { p in
                    let steps = 100
                    for i in 0...steps {
                        let u = CGFloat(i) / CGFloat(steps)
                        let x = 16 + 178 * u
                        let y = midY - amp * CGFloat(sin(Double(u) * 2.0 * Double.pi - phase))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.mathGold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .shadow(color: Color.mathGold.opacity(0.55), radius: 7)

                Text("A")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.45, green: 0.78, blue: 1.0))
                    .position(x: 52, y: 56)
                Text("sin")
                    .font(.system(size: 18, weight: .black, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 36, y: 18)
                Text("starts at midline")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.58))
                    .position(x: 84, y: 126)
                Text("y = A sin(2πft + φ)")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.mathGold.opacity(0.9))
                    .position(x: 126, y: 18)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 21 — base-10 place value: ten beads regroup into the next rod.
struct NumberSenseConceptVisual: View {
    private let rodXs: [CGFloat] = [48, 86, 124, 162]
    private let labels = ["1000", "100", "10", "1"]

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t.truncatingRemainder(dividingBy: 3.2) / 3.2)
            let merging = phase > 0.58
            let carryLift = max(0, min(1, (phase - 0.58) / 0.28))

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mathGold.opacity(0.22), lineWidth: 1))
                    .frame(width: 184, height: 108)
                    .position(x: 105, y: 76)

                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.35))
                        .frame(width: 3, height: 74)
                        .position(x: rodXs[index], y: 76)
                    Text(labels[index])
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .position(x: rodXs[index], y: 123)
                }

                ForEach(0..<10, id: \.self) { bead in
                    let spread = CGFloat(bead % 2) * 7 - 3.5
                    let y = 108 - CGFloat(bead) * 7
                    let opacity = merging ? max(0, 1 - carryLift * 1.4) : 1
                    Ellipse()
                        .fill(Color.mathGold)
                        .frame(width: 24, height: 11)
                        .position(x: rodXs[3] + spread * carryLift, y: y - 20 * carryLift)
                        .opacity(opacity)
                }

                Ellipse()
                    .fill(Color.mathGold)
                    .frame(width: 26, height: 13)
                    .shadow(color: Color.mathGold.opacity(0.75), radius: 7)
                    .position(
                        x: rodXs[3] + (rodXs[2] - rodXs[3]) * carryLift,
                        y: 38 + 58 * carryLift
                    )
                    .opacity(merging ? 1 : 0)

                Path { p in
                    p.move(to: CGPoint(x: rodXs[3], y: 44))
                    p.addQuadCurve(to: CGPoint(x: rodXs[2], y: 96), control: CGPoint(x: 138, y: 28))
                }
                .trim(from: 0, to: carryLift)
                .stroke(Color.mathGold.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))

                Text("10 ones = 1 ten")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 104, y: 21)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 21 legacy visual kept for older references.
struct QuadraticMotionConceptVisual: View {
    private let ox: CGFloat = 26
    private let oy: CGFloat = 112
    private let w: CGFloat = 160
    private let h: CGFloat = 84

    private func curvePoint(_ u: CGFloat, lift: CGFloat) -> CGPoint {
        let x = ox + w * u
        let y = oy - lift * 4 * u * (1 - u)
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let phase = CGFloat(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.0) / 4.0)
            let lift = h * (0.72 + 0.18 * sin(phase * .pi * 2))
            let ball = curvePoint(phase, lift: lift)
            let vertex = curvePoint(0.5, lift: lift)

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: ox, y: oy - h - 8))
                    p.addLine(to: CGPoint(x: ox, y: oy))
                    p.addLine(to: CGPoint(x: ox + w + 10, y: oy))
                }
                .stroke(.white.opacity(0.45), lineWidth: 1.5)

                Path { p in
                    for i in 0...80 {
                        let u = CGFloat(i) / 80
                        let pt = curvePoint(u, lift: lift)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(Color.mathGold, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                .shadow(color: Color.mathGold.opacity(0.55), radius: 6)

                Path { p in
                    p.move(to: CGPoint(x: vertex.x, y: vertex.y))
                    p.addLine(to: CGPoint(x: vertex.x, y: oy))
                }
                .stroke(.white.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Circle()
                    .stroke(Color.mathGold.opacity(0.9), lineWidth: 1.6)
                    .frame(width: 13, height: 13)
                    .position(vertex)

                ForEach([0.0, 1.0], id: \.self) { root in
                    let pt = curvePoint(CGFloat(root), lift: lift)
                    Circle()
                        .fill(.white.opacity(0.85))
                        .frame(width: 6, height: 6)
                        .position(pt)
                }

                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: .white.opacity(0.75), radius: 5)
                    .position(ball)

                Text("roots")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.58))
                    .position(x: ox + w / 2, y: oy + 14)

                Text("vertex (h, k)")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.62))
                    .position(x: vertex.x + 40, y: vertex.y + 8)

                Text("y = a(x - h)² + k")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 100, y: 22)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 22 — reflection symmetry: a point and its mirror image, equidistant.
struct SymmetryConceptVisual: View {
    private let mirrorX: CGFloat = 105
    private let cL = CGPoint(x: 72, y: 70)
    private let a: CGFloat = 26
    private let b: CGFloat = 40

    var body: some View {
        TimelineView(.animation) { ctx in
            let ang = ctx.date.timeIntervalSinceReferenceDate * 1.1
            let dotL = CGPoint(x: cL.x + a * CGFloat(cos(ang)), y: cL.y + b * CGFloat(sin(ang)))
            let dotR = CGPoint(x: 2 * mirrorX - dotL.x, y: dotL.y)

            ZStack {
                // mirror line
                Rectangle().fill(.white.opacity(0.5)).frame(width: 1.5, height: 108)
                    .position(x: mirrorX, y: 70)

                // symmetric outlines (left + mirror)
                Ellipse().fill(Color.mathGold.opacity(0.10)).frame(width: a * 2, height: b * 2).position(cL)
                Ellipse().stroke(Color.mathGold.opacity(0.7), lineWidth: 1.5).frame(width: a * 2, height: b * 2).position(cL)
                Ellipse().fill(Color.mathGold.opacity(0.10)).frame(width: a * 2, height: b * 2).position(x: 2 * mirrorX - cL.x, y: cL.y)
                Ellipse().stroke(Color.mathGold.opacity(0.7), lineWidth: 1.5).frame(width: a * 2, height: b * 2).position(x: 2 * mirrorX - cL.x, y: cL.y)

                // equidistant connector
                Path { p in p.move(to: dotL); p.addLine(to: dotR) }
                    .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                Circle().fill(.white).frame(width: 8, height: 8)
                    .shadow(color: .white.opacity(0.7), radius: 4).position(dotL)
                Circle().fill(.white).frame(width: 8, height: 8)
                    .shadow(color: .white.opacity(0.7), radius: 4).position(dotR)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 23 — a constellation traced by an Eulerian path (every edge once).
struct ConstellationConceptVisual: View {
    private let stars: [CGPoint] = [
        CGPoint(x: 38, y: 52), CGPoint(x: 92, y: 30), CGPoint(x: 150, y: 46),
        CGPoint(x: 176, y: 92), CGPoint(x: 112, y: 104), CGPoint(x: 54, y: 98)
    ]
    private let trail = [0, 1, 2, 3, 4, 1, 5, 0]   // vertex sequence; consecutive pairs are distinct edges

    var body: some View {
        TimelineView(.animation) { ctx in
            let segs = trail.count - 1
            let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6
            let prog = u * Double(segs)
            let seg = min(Int(prog), segs - 1)
            let localT = CGFloat(prog - Double(seg))
            let a = stars[trail[seg]], b = stars[trail[seg + 1]]
            let dot = CGPoint(x: a.x + (b.x - a.x) * localT, y: a.y + (b.y - a.y) * localT)

            ZStack {
                ForEach(0..<segs, id: \.self) { i in
                    let p0 = stars[trail[i]], p1 = stars[trail[i + 1]]
                    Path { p in p.move(to: p0); p.addLine(to: p1) }
                        .stroke(i <= seg ? Color.mathGold : .white.opacity(0.22), lineWidth: i <= seg ? 1.8 : 1)
                }
                ForEach(stars.indices, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .white.opacity(0.6), radius: 4)
                        .position(stars[i])
                }
                Circle().fill(Color.mathGold).frame(width: 8, height: 8)
                    .shadow(color: Color.mathGold.opacity(0.8), radius: 5)
                    .position(dot)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 24 — inequality endpoints: open circles exclude, closed circles include.
struct OpenClosedBoundaryConceptVisual: View {
    private let x0: CGFloat = 30
    private let x1: CGFloat = 184
    private let openY: CGFloat = 58
    private let closedY: CGFloat = 102
    private let boundaryX: CGFloat = 90

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = 1 + 0.10 * CGFloat(sin(t * 2.8))

            ZStack {
                numberLine(y: openY)
                numberLine(y: closedY)
                solutionRay(y: openY)
                solutionRay(y: closedY)

                Circle()
                    .stroke(Color.mathGold, lineWidth: 2.4)
                    .frame(width: 16 * pulse, height: 16 * pulse)
                    .position(x: boundaryX, y: openY)

                Circle()
                    .fill(Color.mathGold)
                    .frame(width: 16 * pulse, height: 16 * pulse)
                    .shadow(color: Color.mathGold.opacity(0.55), radius: 5)
                    .position(x: boundaryX, y: closedY)

                Text("x > a")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 56, y: 30)

                Text("x ≥ a")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 56, y: 132)

                Text("a")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.7))
                    .position(x: boundaryX, y: openY + 18)

                Text("a excluded")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.62))
                    .position(x: 138, y: openY - 20)

                Text("a included")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.62))
                    .position(x: 138, y: closedY + 20)
            }
            .frame(width: 210, height: 140)
        }
    }

    private func numberLine(y: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: x0, y: y))
                p.addLine(to: CGPoint(x: x1, y: y))
                p.move(to: CGPoint(x: x1, y: y))
                p.addLine(to: CGPoint(x: x1 - 8, y: y - 5))
                p.move(to: CGPoint(x: x1, y: y))
                p.addLine(to: CGPoint(x: x1 - 8, y: y + 5))
            }
            .stroke(.white.opacity(0.42), lineWidth: 1.5)

            ForEach(0..<7, id: \.self) { i in
                let x = x0 + (x1 - x0) * CGFloat(i) / 6
                Rectangle()
                    .fill(.white.opacity(0.34))
                    .frame(width: 1, height: 7)
                    .position(x: x, y: y)
            }
        }
    }

    private func solutionRay(y: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: boundaryX + 9, y: y))
            p.addLine(to: CGPoint(x: x1 - 4, y: y))
        }
        .stroke(Color.mathGold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .shadow(color: Color.mathGold.opacity(0.45), radius: 4)
    }
}

// Level 25 — absolute value as distance from zero.
struct AbsoluteValueConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * 1.25) + 1) / 2
            let leftX = CGFloat(48 + phase * 22)
            let rightX = CGFloat(162 - phase * 22)
            let y: CGFloat = 82
            let zeroX: CGFloat = 105

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 28, y: y))
                    path.addLine(to: CGPoint(x: 182, y: y))
                    path.move(to: CGPoint(x: 182, y: y))
                    path.addLine(to: CGPoint(x: 174, y: y - 5))
                    path.move(to: CGPoint(x: 182, y: y))
                    path.addLine(to: CGPoint(x: 174, y: y + 5))
                    path.move(to: CGPoint(x: 28, y: y))
                    path.addLine(to: CGPoint(x: 36, y: y - 5))
                    path.move(to: CGPoint(x: 28, y: y))
                    path.addLine(to: CGPoint(x: 36, y: y + 5))
                }
                .stroke(.white.opacity(0.45), lineWidth: 1.6)

                ForEach(-3...3, id: \.self) { tick in
                    let x = zeroX + CGFloat(tick) * 22
                    Rectangle()
                        .fill(tick == 0 ? Color.mathGold : .white.opacity(0.38))
                        .frame(width: tick == 0 ? 2 : 1, height: tick == 0 ? 18 : 10)
                        .position(x: x, y: y)
                    Text(tick == 0 ? "0" : "\(tick)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(tick == 0 ? Color.mathGold : .white.opacity(0.52))
                        .position(x: x, y: y + 20)
                }

                distanceArc(from: leftX, to: zeroX, y: y - 26)
                distanceArc(from: zeroX, to: rightX, y: y - 26)

                Circle()
                    .fill(Color(red: 0.36, green: 0.86, blue: 1.0))
                    .frame(width: 13, height: 13)
                    .shadow(color: Color(red: 0.36, green: 0.86, blue: 1.0).opacity(0.75), radius: 7)
                    .position(x: leftX, y: y)

                Circle()
                    .fill(Color.mathGold)
                    .frame(width: 13, height: 13)
                    .shadow(color: Color.mathGold.opacity(0.75), radius: 7)
                    .position(x: rightX, y: y)

                Text("|−x| = |x|")
                    .font(.system(size: 18, weight: .black, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 105, y: 34)

                Text("same distance")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.62))
                    .position(x: 105, y: 122)
            }
            .frame(width: 210, height: 140)
        }
    }

    private func distanceArc(from start: CGFloat, to end: CGFloat, y: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: start, y: y))
            path.addQuadCurve(
                to: CGPoint(x: end, y: y),
                control: CGPoint(x: (start + end) / 2, y: y - 18)
            )
        }
        .stroke(Color.mathGold.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
    }
}

// A reusable rotating 3D cube casting its 2D projected shadow.
struct ProjectionConceptVisual: View {
    private let verts: [(Double, Double, Double)] = [
        (-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
        (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)
    ]
    private let edges: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4),
        (0, 4), (1, 5), (2, 6), (3, 7)
    ]

    private let tilt = 0.5
    private let scale: CGFloat = 23
    private let cx: CGFloat = 105
    private let cy: CGFloat = 58
    private let groundY: CGFloat = 118

    private func project(_ v: (Double, Double, Double), a: Double) -> CGPoint {
        let (x, y, z) = v
        let x1 = x * cos(a) + z * sin(a)
        let z1 = -x * sin(a) + z * cos(a)
        let y2 = y * cos(tilt) - z1 * sin(tilt)
        return CGPoint(x: cx + CGFloat(x1) * scale, y: cy - CGFloat(y2) * scale)
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let a = ctx.date.timeIntervalSinceReferenceDate * 0.7
            let pts = verts.map { project($0, a: a) }
            let xs = pts.map { $0.x }
            let minX = xs.min() ?? cx, maxX = xs.max() ?? cx

            ZStack {
                Ellipse().fill(.white.opacity(0.12))
                    .frame(width: (maxX - minX) + 16, height: 16)
                    .position(x: (minX + maxX) / 2, y: groundY)

                ForEach(edges.indices, id: \.self) { i in
                    let e = edges[i]
                    Path { p in p.move(to: pts[e.0]); p.addLine(to: pts[e.1]) }
                        .stroke(Color.mathGold.opacity(0.85), lineWidth: 1.6)
                }
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 26 — a string vibrating through its harmonics, with nodes marked.
struct HarmonicConceptVisual: View {
    private let x0: CGFloat = 24
    private let x1: CGFloat = 186
    private let midY: CGFloat = 66

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let n = 1 + Int((t / 1.6).truncatingRemainder(dividingBy: 3))   // cycles 1, 2, 3
            let amp = 19 * sin(t * 8)

            ZStack {
                Path { p in
                    let steps = 90
                    for i in 0...steps {
                        let f = CGFloat(i) / CGFloat(steps)
                        let x = x0 + (x1 - x0) * f
                        let y = midY - CGFloat(amp) * sin(Double(n) * .pi * Double(f))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.mathGold, lineWidth: 2)
                .shadow(color: Color.mathGold.opacity(0.5), radius: 5)

                Circle().fill(.white).frame(width: 7, height: 7).position(x: x0, y: midY)
                Circle().fill(.white).frame(width: 7, height: 7).position(x: x1, y: midY)

                ForEach(1..<max(n, 1), id: \.self) { k in
                    let x = x0 + (x1 - x0) * CGFloat(k) / CGFloat(n)
                    Circle().fill(.white.opacity(0.75)).frame(width: 5, height: 5).position(x: x, y: midY)
                }

                Text("n = \(n)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .position(x: (x0 + x1) / 2, y: midY + 42)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 27 — a recursive fractal tree (self-similar branching) swaying.
struct FractalConceptVisual: View {
    private struct Seg { let start: CGPoint; let end: CGPoint; let depth: Int }

    var body: some View {
        TimelineView(.animation) { ctx in
            let spread = 0.52 + 0.07 * sin(ctx.date.timeIntervalSinceReferenceDate * 1.1)
            let segs = segments(spread: spread)
            ZStack {
                ForEach(segs.indices, id: \.self) { i in
                    let s = segs[i]
                    Path { p in p.move(to: s.start); p.addLine(to: s.end) }
                        .stroke(Color.mathGold.opacity(1 - Double(s.depth) * 0.1),
                                lineWidth: max(1, 3 - CGFloat(s.depth) * 0.42))
                }
            }
            .frame(width: 210, height: 140)
        }
    }

    private func segments(spread: Double) -> [Seg] {
        var out: [Seg] = []
        func grow(_ from: CGPoint, _ angle: Double, _ len: CGFloat, _ depth: Int) {
            if depth > 5 { return }
            let end = CGPoint(x: from.x + CGFloat(cos(angle)) * len,
                              y: from.y - CGFloat(sin(angle)) * len)
            out.append(Seg(start: from, end: end, depth: depth))
            grow(end, angle + spread, len * 0.72, depth + 1)
            grow(end, angle - spread, len * 0.72, depth + 1)
        }
        grow(CGPoint(x: 105, y: 132), .pi / 2, 30, 0)
        return out
    }
}

// Level 29 — the locker problem: passes toggle lockers; perfect squares end open.
struct LockerConceptVisual: View {
    private let count = 9

    var body: some View {
        TimelineView(.animation) { ctx in
            let phase = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5.0) / 5.0
            let passes = min(Int(phase * Double(count + 1)), count)
            GeometryReader { geo in
                let w = geo.size.width
                let slotW = (w - 16) / CGFloat(count)
                ZStack {
                    ForEach(1...count, id: \.self) { n in
                        let toggles = (1...n).filter { n % $0 == 0 && $0 <= passes }.count
                        let open = toggles % 2 == 1
                        locker(n: n, open: open)
                            .frame(width: slotW - 4, height: 46)
                            .position(x: 8 + slotW * (CGFloat(n) - 0.5), y: 58)
                    }
                    Text(passes == 0 ? "start" : (passes >= count ? "squares stay open" : "pass \(passes)"))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.mathGold.opacity(0.9))
                        .position(x: w / 2, y: 104)
                }
            }
            .frame(width: 210, height: 140)
        }
    }

    private func locker(n: Int, open: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(open ? Color.mathGold.opacity(0.28) : .white.opacity(0.06))
            RoundedRectangle(cornerRadius: 3)
                .stroke(open ? Color.mathGold : .white.opacity(0.35), lineWidth: open ? 1.8 : 1)
            Text("\(n)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(open ? Color.mathGold : .white.opacity(0.5))
        }
    }
}

// Level 30 — the golden spiral, with a dot travelling its self-similar curve.
struct GoldenRatioConceptVisual: View {
    private let pole = CGPoint(x: 140, y: 84)
    private let thetaMax = 3.0 * Double.pi
    private let phi = 1.618

    private func point(_ th: Double) -> CGPoint {
        let r = 2.2 * pow(phi, th / (Double.pi / 2))
        return CGPoint(x: pole.x - CGFloat(cos(th) * r), y: pole.y - CGFloat(sin(th) * r))
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0) / 3.0
            let dot = point(thetaMax * u)
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
                    .frame(width: 140, height: 140 / 1.618)
                    .position(x: 105, y: 78)

                Path { p in
                    let steps = 130
                    for i in 0...steps {
                        let q = point(thetaMax * Double(i) / Double(steps))
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                }
                .stroke(Color.mathGold, lineWidth: 2)
                .shadow(color: Color.mathGold.opacity(0.5), radius: 5)

                Circle().fill(.white).frame(width: 6, height: 6)
                    .shadow(color: .white.opacity(0.7), radius: 3)
                    .position(dot)

                Text("φ ≈ 1.618")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 52, y: 122)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 31 — RSA's easy multiplication and difficult reverse factor search.
struct FactorConceptVisual: View {
    private let cyan = Color(red: 0.18, green: 0.78, blue: 1.0)
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.28)
    private let candidates = [17, 19, 23, 29, 31]

    var body: some View {
        TimelineView(.animation) { ctx in
            let phase = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.2) / 4.2
            let combine = CGFloat(min(1, phase / 0.34))
            let search = max(0, (phase - 0.42) / 0.58)
            let activeCandidate = min(candidates.count - 1, Int(search * Double(candidates.count)))

            ZStack {
                Text("RSA")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 18, y: 12)

                Text("MULTIPLY · FAST")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(cyan)
                    .position(x: 105, y: 12)

                Path { path in
                    path.move(to: CGPoint(x: 39, y: 40))
                    path.addLine(to: CGPoint(x: 66, y: 58))
                    path.move(to: CGPoint(x: 39, y: 78))
                    path.addLine(to: CGPoint(x: 66, y: 60))
                    path.move(to: CGPoint(x: 84, y: 59))
                    path.addLine(to: CGPoint(x: 112, y: 59))
                }
                .trim(from: 0, to: combine)
                .stroke(cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .shadow(color: cyan.opacity(0.5), radius: 4)

                primeNode("29", at: CGPoint(x: 26, y: 40))
                primeNode("31", at: CGPoint(x: 26, y: 78))

                Text("×")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.08)))
                    .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1))
                    .position(x: 75, y: 59)

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.black)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.mathGold, lineWidth: 1.2))
                        .shadow(color: Color.mathGold.opacity(0.35), radius: 6)
                    VStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("N = 899")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(Color.mathGold)
                }
                .frame(width: 76, height: 54)
                .position(x: 151, y: 59)

                Path { path in
                    path.move(to: CGPoint(x: 151, y: 88))
                    path.addLine(to: CGPoint(x: 151, y: 98))
                    path.addLine(to: CGPoint(x: 30, y: 98))
                }
                .stroke(coral.opacity(search > 0 ? 0.85 : 0.25), style: StrokeStyle(lineWidth: 1.3, dash: [4, 4]))

                Image(systemName: "arrow.left")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(coral)
                    .position(x: 88, y: 98)

                Text("FACTOR · HARD")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(coral)
                    .position(x: 178, y: 98)

                HStack(spacing: 6) {
                    ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                        Text("\(candidate)")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(index == activeCandidate && search > 0 ? .black : .white.opacity(0.5))
                            .frame(width: 26, height: 20)
                            .background(index == activeCandidate && search > 0 ? coral : .white.opacity(0.06), in: Circle())
                    }
                }
                .position(x: 105, y: 121)

                Text("try divisors until N ÷ p is whole")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .position(x: 105, y: 137)
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("RSA diagram showing primes twenty-nine and thirty-one multiplying quickly into public modulus eight hundred ninety-nine, while reverse factorization searches many divisors")
    }

    private func primeNode(_ label: String, at point: CGPoint) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(.black.opacity(0.72))
            .frame(width: 28, height: 28)
            .background(Circle().fill(cyan))
            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
            .shadow(color: cyan.opacity(0.55), radius: 5)
            .position(point)
    }
}

// Level 32 — a rectangular prism filling up, V = l × w × h.
struct VolumeConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let fx: CGFloat = 52, fyTop: CGFloat = 34, fyBot: CGFloat = 98, fw: CGFloat = 80
            let fh = fyBot - fyTop
            let d = CGSize(width: 30, height: -20)
            let fillFrac = CGFloat(0.5 - 0.5 * cos(t * 1.2))
            let liqTop = fyBot - fh * fillFrac

            let A = CGPoint(x: fx, y: fyBot), B = CGPoint(x: fx + fw, y: fyBot)
            let C = CGPoint(x: fx + fw, y: fyTop), D = CGPoint(x: fx, y: fyTop)
            let Dp = CGPoint(x: D.x + d.width, y: D.y + d.height)
            let Cp = CGPoint(x: C.x + d.width, y: C.y + d.height)
            let Bp = CGPoint(x: B.x + d.width, y: B.y + d.height)

            ZStack {
                // liquid
                Rectangle().fill(Color.mathGold.opacity(0.28))
                    .frame(width: fw, height: fh * fillFrac)
                    .position(x: fx + fw / 2, y: fyBot - fh * fillFrac / 2)
                Path { p in
                    p.move(to: CGPoint(x: fx, y: liqTop)); p.addLine(to: CGPoint(x: fx + fw, y: liqTop))
                    p.addLine(to: CGPoint(x: fx + fw + d.width, y: liqTop + d.height))
                    p.addLine(to: CGPoint(x: fx + d.width, y: liqTop + d.height)); p.closeSubpath()
                }.fill(Color.mathGold.opacity(0.42))

                // box faces
                Path { p in p.move(to: D); p.addLine(to: C); p.addLine(to: Cp); p.addLine(to: Dp); p.closeSubpath() }
                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
                Path { p in p.move(to: C); p.addLine(to: B); p.addLine(to: Bp); p.addLine(to: Cp); p.closeSubpath() }
                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
                Path { p in p.move(to: A); p.addLine(to: B); p.addLine(to: C); p.addLine(to: D); p.closeSubpath() }
                    .stroke(.white.opacity(0.9), lineWidth: 1.8)

                // dimension labels
                Text("l").font(dimFont).foregroundStyle(Color.mathGold).position(x: fx + fw / 2, y: fyBot + 12)
                Text("h").font(dimFont).foregroundStyle(Color.mathGold).position(x: fx - 11, y: (fyTop + fyBot) / 2)
                Text("w").font(dimFont).foregroundStyle(Color.mathGold).position(x: fx + fw + d.width / 2 + 8, y: fyTop + d.height / 2)

                Text("V = l × w × h")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .position(x: 105, y: 130)
            }
            .frame(width: 210, height: 140)
        }
    }

    private var dimFont: Font { .system(size: 13, weight: .bold, design: .serif) }
}

// Level 34 — an exponential growth curve with a climbing point.
struct ExponentialConceptVisual: View {
    private let ox: CGFloat = 30
    private let oy: CGFloat = 112
    private let w: CGFloat = 156
    private let h: CGFloat = 84
    private let r = 2.2
    private let maxN = 3.4

    private func curveY(_ fx: Double) -> CGFloat {
        let val = pow(r, fx * maxN), maxVal = pow(r, maxN)
        return oy - h * CGFloat((val - 1) / (maxVal - 1))
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let u = CGFloat(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0) / 3.0)
            let dpt = CGPoint(x: ox + w * u, y: curveY(Double(u)))
            ZStack {
                // axes
                Path { p in
                    p.move(to: CGPoint(x: ox, y: oy - h - 6))
                    p.addLine(to: CGPoint(x: ox, y: oy))
                    p.addLine(to: CGPoint(x: ox + w + 6, y: oy))
                }
                .stroke(.white.opacity(0.5), lineWidth: 1.5)

                // exponential curve
                Path { p in
                    let steps = 60
                    for i in 0...steps {
                        let fx = Double(i) / Double(steps)
                        let pt = CGPoint(x: ox + w * CGFloat(fx), y: curveY(fx))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(Color.mathGold, lineWidth: 2.5)
                .shadow(color: Color.mathGold.opacity(0.5), radius: 5)

                Circle().fill(.white).frame(width: 7, height: 7)
                    .shadow(color: .white.opacity(0.7), radius: 4)
                    .position(dpt)

                Text("N = N₀ · rⁿ")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 82, y: 32)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 35 — a travelling sine wave whose frequency k rises and falls.
struct FrequencyConceptVisual: View {
    private let x0: CGFloat = 22
    private let x1: CGFloat = 188
    private let midY: CGFloat = 66
    private let amp: CGFloat = 30

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let k = 2 + 8 * (0.5 - 0.5 * cos(t * 0.5))   // frequency oscillates 2…10
            let phase = t * 3
            ZStack {
                Path { p in p.move(to: CGPoint(x: x0, y: midY)); p.addLine(to: CGPoint(x: x1, y: midY)) }
                    .stroke(.white.opacity(0.25), lineWidth: 1)

                Path { p in
                    let steps = 130
                    for i in 0...steps {
                        let f = Double(i) / Double(steps)
                        let x = x0 + (x1 - x0) * CGFloat(f)
                        let y = midY - amp * CGFloat(sin(k * f * 2 * Double.pi - phase))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.mathGold, lineWidth: 2.5)
                .shadow(color: Color.mathGold.opacity(0.5), radius: 5)

                Text("k = \(Int(k.rounded()))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .position(x: (x0 + x1) / 2, y: midY + 46)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 36 — two meshing gears (8 and 12 teeth) turning; they realign at the LCM.
struct GearConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                gear(teeth: 8, radius: 24, angle: t * 1.2, at: CGPoint(x: 64, y: 64))
                gear(teeth: 12, radius: 36, angle: -t * 0.8, at: CGPoint(x: 124, y: 64))
                Text("LCM(8, 12) = 24")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 105, y: 126)
            }
            .frame(width: 210, height: 140)
        }
    }

    private func gear(teeth: Int, radius: CGFloat, angle: Double, at c: CGPoint) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.7), lineWidth: 2)
            Circle().fill(.white.opacity(0.05))
            ForEach(0..<teeth, id: \.self) { i in
                let a = Double(i) / Double(teeth) * 2 * Double.pi
                Rectangle()
                    .fill(i == 0 ? Color.mathGold : .white.opacity(0.75))
                    .frame(width: 5, height: 9)
                    .offset(x: radius + 3)
                    .rotationEffect(.radians(a))
            }
            Circle().fill(.white.opacity(0.5)).frame(width: 6, height: 6)
        }
        .frame(width: radius * 2, height: radius * 2)
        .rotationEffect(.radians(angle))
        .position(c)
    }
}

// Level 37 — three items cycling through all 3! = 6 orderings.
struct PermutationConceptVisual: View {
    private let perms = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
    private let colors: [Color] = [Color.mathGold, .white, Color(red: 0.5, green: 0.8, blue: 1.0)]
    private let slots: [CGFloat] = [72, 105, 138]

    var body: some View {
        TimelineView(.animation) { ctx in
            let idx = Int(ctx.date.timeIntervalSinceReferenceDate / 0.9) % perms.count
            let perm = perms[idx]
            ZStack {
                ForEach(0..<3, id: \.self) { item in
                    let slot = perm.firstIndex(of: item) ?? 0
                    Circle().fill(colors[item])
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                        .shadow(color: colors[item].opacity(0.5), radius: 5)
                        .position(x: slots[slot], y: 58)
                        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: idx)
                }
                Text("3! = 6")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 105, y: 102)
                Text("\(idx + 1) of 6")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .position(x: 105, y: 122)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 38 — a vector field (swirl) of arrows with particles flowing along it.
struct VectorFieldConceptVisual: View {
    private let cx: CGFloat = 106
    private let cy: CGFloat = 68

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<5, id: \.self) { gx in
                    ForEach(0..<4, id: \.self) { gy in
                        let px = 26 + CGFloat(gx) * 40
                        let py = 26 + CGFloat(gy) * 32
                        let dx = -(py - cy), dy = (px - cx)
                        arrow(at: CGPoint(x: px, y: py), angle: atan2(Double(dy), Double(dx)))
                    }
                }
                ForEach(0..<3, id: \.self) { i in
                    let r = 24 + CGFloat(i) * 17
                    let a = t * 1.2 + Double(i) * 2.1
                    let p = CGPoint(x: cx + r * CGFloat(cos(a)), y: cy + r * CGFloat(sin(a)))
                    Circle().fill(Color.mathGold).frame(width: 7, height: 7)
                        .shadow(color: Color.mathGold.opacity(0.8), radius: 5)
                        .position(p)
                }
            }
            .frame(width: 210, height: 140)
        }
    }

    private func arrow(at p: CGPoint, angle: Double) -> some View {
        Path { pt in
            pt.move(to: CGPoint(x: 0, y: 8)); pt.addLine(to: CGPoint(x: 14, y: 8))
            pt.move(to: CGPoint(x: 10, y: 5)); pt.addLine(to: CGPoint(x: 14, y: 8)); pt.addLine(to: CGPoint(x: 10, y: 11))
        }
        .stroke(.white.opacity(0.4), lineWidth: 1.3)
        .frame(width: 14, height: 16)
        .rotationEffect(.radians(angle))
        .position(p)
    }
}

// Level 39 — a torus with a path travelling continuously around its surface.
struct TorusConceptVisual: View {
    private let c = CGPoint(x: 105, y: 64)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Ellipse().stroke(Color.mathGold, lineWidth: 2).frame(width: 140, height: 84).position(c)
                Ellipse().stroke(Color.mathGold.opacity(0.8), lineWidth: 2).frame(width: 58, height: 24).position(c)

                ForEach(0..<8, id: \.self) { i in
                    let a = Double(i) / 8 * 2 * Double.pi
                    let ringC = CGPoint(x: c.x + 49 * CGFloat(cos(a)), y: c.y + 27 * CGFloat(sin(a)))
                    Ellipse().stroke(.white.opacity(0.16), lineWidth: 1).frame(width: 14, height: 26).position(ringC)
                }

                let a = t * 1.1
                let dot = CGPoint(x: c.x + 49 * CGFloat(cos(a)), y: c.y + 27 * CGFloat(sin(a)))
                Circle().fill(.white).frame(width: 8, height: 8)
                    .shadow(color: .white.opacity(0.7), radius: 4)
                    .position(dot)

                Text("torus")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.mathGold.opacity(0.85))
                    .position(x: 105, y: 124)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 40 — a lever balancing moments around a pivot.
struct LeverConceptVisual: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 42, y: 74))
                p.addLine(to: CGPoint(x: 168, y: 74))
            }
            .stroke(Color.mathGold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-4))
            .shadow(color: Color.mathGold.opacity(glow ? 0.65 : 0.25), radius: 10)

            TrianglePivot()
                .fill(.white.opacity(0.82))
                .frame(width: 38, height: 32)
                .position(x: 105, y: 94)

            weight(size: 28, label: "F", x: 58, y: 91)
            weight(size: 40, label: "2F", x: 150, y: 85)

            Path { p in
                p.move(to: CGPoint(x: 58, y: 76))
                p.addLine(to: CGPoint(x: 58, y: 104))
                p.move(to: CGPoint(x: 150, y: 73))
                p.addLine(to: CGPoint(x: 150, y: 104))
            }
            .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))

            Text("F d")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.82))
                .position(x: 80, y: 35)

            Text("=")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(Color.mathGold)
                .position(x: 105, y: 35)

            Text("F d")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.82))
                .position(x: 130, y: 35)
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private func weight(size: CGFloat, label: String, x: CGFloat, y: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(.white.opacity(0.12))
                .frame(width: size, height: size)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white.opacity(0.65), lineWidth: 1.4)
                }

            Text(label)
                .font(.system(size: size * 0.32, weight: .bold, design: .serif))
                .foregroundStyle(.white.opacity(0.9))
        }
        .position(x: x, y: y)
    }
}

private struct TrianglePivot: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Level 41 — triangle angle sum and special triangle structure.
struct TriangleAnglesConceptVisual: View {
    @State private var glow = false
    @State private var stateIndex = 0

    private let states = [
        TriangleAngleState(apex: CGPoint(x: 106, y: 30), leftAngle: 60, apexAngle: 60, rightAngle: 60),
        TriangleAngleState(apex: CGPoint(x: 132, y: 38), leftAngle: 45, apexAngle: 45, rightAngle: 90),
        TriangleAngleState(apex: CGPoint(x: 88, y: 28), leftAngle: 30, apexAngle: 90, rightAngle: 60)
    ]

    var body: some View {
        let state = states[stateIndex]
        let left = CGPoint(x: 44, y: 104)
        let right = CGPoint(x: 166, y: 104)
        let apex = state.apex

        return ZStack {
            Path { p in
                p.move(to: left)
                p.addLine(to: apex)
                p.addLine(to: right)
                p.closeSubpath()
            }
            .stroke(Color.mathGold, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            .shadow(color: Color.mathGold.opacity(glow ? 0.65 : 0.25), radius: 10)

            angleArc(center: left, radius: 24, start: -Double(state.leftAngle), end: 0)
            angleArc(center: apex, radius: 22, start: state.leftEdgeAngle, end: state.rightEdgeAngle)
            angleArc(center: right, radius: 24, start: 180, end: 180 + Double(state.rightAngle))

            angleLabel("\(state.leftAngle)", at: CGPoint(x: left.x + 20, y: left.y - 12))
            angleLabel("\(state.apexAngle)", at: CGPoint(x: apex.x, y: apex.y + 24))
            angleLabel("\(state.rightAngle)", at: CGPoint(x: right.x - 20, y: right.y - 12))

            Text("180")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(Color.mathGold)
                .position(x: 106, y: 124)
        }
        .frame(width: 210, height: 140)
        .animation(.easeInOut(duration: 0.82), value: stateIndex)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                glow = true
            }
            cycleTriangleStates()
        }
    }

    private func angleLabel(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.88))
            .contentTransition(.numericText())
            .position(point)
    }

    private func angleArc(center: CGPoint, radius: CGFloat, start: Double, end: Double) -> some View {
        Path { p in
            p.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(start),
                endAngle: .degrees(end),
                clockwise: false
            )
        }
        .stroke(.white.opacity(0.78), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }

    private func cycleTriangleStates() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            stateIndex = (stateIndex + 1) % states.count
            cycleTriangleStates()
        }
    }
}

private struct TriangleAngleState {
    let apex: CGPoint
    let leftAngle: Int
    let apexAngle: Int
    let rightAngle: Int

    var leftEdgeAngle: Double {
        Double(90 + apexAngle / 2)
    }

    var rightEdgeAngle: Double {
        Double(90 - apexAngle / 2)
    }
}

// Level 43 — two bit rows combined through a cycling AND / OR / XOR gate.
struct GateConceptVisual: View {
    private let a = [1, 0, 1, 1, 0, 1]
    private let b = [0, 1, 1, 0, 1, 1]
    private let gates: [(name: String, op: (Int, Int) -> Int)] = [
        ("AND  ∧", { $0 & $1 }),
        ("OR  ∨", { $0 | $1 }),
        ("XOR  ⊕", { $0 ^ $1 })
    ]

    var body: some View {
        TimelineView(.animation) { ctx in
            let idx = Int(ctx.date.timeIntervalSinceReferenceDate / 1.4) % gates.count
            let g = gates[idx]
            let result = zip(a, b).map { g.op($0, $1) }
            VStack(spacing: 7) {
                bitRow(a, label: "A")
                Text(g.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.mathGold)
                bitRow(b, label: "B")
                Rectangle().fill(.white.opacity(0.25)).frame(width: 128, height: 1)
                bitRow(result, label: "=")
            }
            .frame(width: 210, height: 140)
        }
    }

    private func bitRow(_ bits: [Int], label: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 14, alignment: .trailing)
            ForEach(bits.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(bits[i] == 1 ? Color.mathGold : .white.opacity(0.06))
                    .frame(width: 15, height: 15)
                    .overlay { RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.1), lineWidth: 1) }
            }
        }
    }
}

// Level 44 — a value flowing through a chain of function boxes (composition).
struct CompositionConceptVisual: View {
    private let boxX: [CGFloat] = [58, 108, 158]
    private let labels = ["×3", "×2", "+3"]
    private let values = [2, 6, 12, 15]   // 2 → ×3 → ×2 → +3

    var body: some View {
        TimelineView(.animation) { ctx in
            let u = CGFloat(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0) / 3.0)
            let x0: CGFloat = 18, x1: CGFloat = 196
            let tx = x0 + (x1 - x0) * u
            let passed = boxX.filter { $0 < tx }.count
            let val = values[min(passed, values.count - 1)]

            ZStack {
                Path { p in p.move(to: CGPoint(x: x0, y: 80)); p.addLine(to: CGPoint(x: x1, y: 80)) }
                    .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                ForEach(boxX.indices, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(Color.mathGold.opacity(0.12))
                        RoundedRectangle(cornerRadius: 6).stroke(Color.mathGold.opacity(0.6), lineWidth: 1.2)
                        Text(labels[i]).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Color.mathGold)
                    }
                    .frame(width: 40, height: 34)
                    .position(x: boxX[i], y: 80)
                }

                ZStack {
                    Circle().fill(.white).shadow(color: .white.opacity(0.6), radius: 4)
                    Text("\(val)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.black)
                }
                .frame(width: 24, height: 24)
                .position(x: tx, y: 46)

                Text("f(g(x))")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                    .position(x: 105, y: 116)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 45 — different coin combinations that make the same total.
struct ChangeConceptVisual: View {
    private let total = 30
    private let combos: [[Int]] = [[25, 5], [10, 10, 10], [10, 10, 5, 5], [5, 5, 5, 5, 5, 5]]

    var body: some View {
        TimelineView(.animation) { ctx in
            let idx = Int(ctx.date.timeIntervalSinceReferenceDate / 1.6) % combos.count
            let combo = combos[idx]
            VStack(spacing: 16) {
                HStack(spacing: 7) {
                    ForEach(combo.indices, id: \.self) { i in coin(combo[i]) }
                }
                Text("= \(total)¢")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Color.mathGold)
            }
            .frame(width: 210, height: 140)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: idx)
        }
    }

    private func coin(_ v: Int) -> some View {
        ZStack {
            Circle().fill(Color.mathGold.opacity(0.18))
            Circle().stroke(Color.mathGold, lineWidth: 1.5)
            Text("\(v)").font(.system(size: 12, weight: .bold, design: .serif)).foregroundStyle(Color.mathGold)
        }
        .frame(width: 30, height: 30)
    }
}

// Level 48 — an arithmetic sequence growing by a constant difference.
struct SequenceConceptVisual: View {
    private let terms = [3, 7, 11, 15]
    private let xs: [CGFloat] = [32, 80, 128, 176]

    var body: some View {
        TimelineView(.animation) { ctx in
            let idx = Int(ctx.date.timeIntervalSinceReferenceDate / 0.9) % 4
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let visible = idx >= i
                    let active = idx == i
                    ZStack {
                        Circle().fill(Color.mathGold.opacity(active ? 0.24 : 0.1))
                        Circle().stroke(Color.mathGold.opacity(active ? 0.95 : 0.5), lineWidth: active ? 2 : 1.2)
                        Text("\(terms[i])")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.mathGold)
                    }
                    .frame(width: 36, height: 36)
                    .scaleEffect(active ? 1.12 : 1)
                    .opacity(visible ? 1 : 0.15)
                    .position(x: xs[i], y: 70)
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: idx)

                    if i < 3 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .position(x: (xs[i] + xs[i + 1]) / 2, y: 70)
                        Text("+4")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.mathGold.opacity(0.75))
                            .position(x: (xs[i] + xs[i + 1]) / 2, y: 54)
                    }
                }
                Text("d = 4")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.7))
                    .position(x: 105, y: 112)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 49 — a line with a rise/run right triangle and a travelling point.
struct SlopeConceptVisual: View {
    private func lineY(_ x: CGFloat) -> CGFloat { 112 - 0.47 * (x - 30) }

    var body: some View {
        TimelineView(.animation) { ctx in
            let u = CGFloat(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4)
            let a = CGPoint(x: 58, y: lineY(58))
            let b = CGPoint(x: 150, y: lineY(150))
            let c = CGPoint(x: 150, y: lineY(58))
            let dot = CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)

            ZStack {
                // axes
                Path { p in
                    p.move(to: CGPoint(x: 30, y: 24)); p.addLine(to: CGPoint(x: 30, y: 112))
                    p.addLine(to: CGPoint(x: 196, y: 112))
                }
                .stroke(.white.opacity(0.4), lineWidth: 1.2)

                // line
                Path { p in p.move(to: CGPoint(x: 30, y: lineY(30))); p.addLine(to: CGPoint(x: 178, y: lineY(178))) }
                    .stroke(Color.mathGold, lineWidth: 2.5)
                    .shadow(color: Color.mathGold.opacity(0.5), radius: 4)

                // rise / run triangle
                Path { p in p.move(to: a); p.addLine(to: c); p.addLine(to: b) }
                    .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))

                Text("Δx").font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.7)).position(x: (a.x + c.x) / 2, y: c.y + 11)
                Text("Δy").font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.7)).position(x: c.x + 14, y: (c.y + b.y) / 2)

                Circle().fill(.white).frame(width: 8, height: 8)
                    .shadow(color: .white.opacity(0.7), radius: 3).position(dot)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 50 — two points on a number line whose comparison flips as one moves.
struct InequalityConceptVisual: View {
    private let x0: CGFloat = 26
    private let x1: CGFloat = 184
    private let y: CGFloat = 82

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let aX = (x0 + x1) / 2
            let bX = x0 + (x1 - x0) * (0.5 + 0.42 * CGFloat(sin(t * 0.9)))
            let bLess = bX < aX

            ZStack {
                Path { p in p.move(to: CGPoint(x: x0, y: y)); p.addLine(to: CGPoint(x: x1, y: y)) }
                    .stroke(.white.opacity(0.5), lineWidth: 1.5)
                ForEach(0..<9, id: \.self) { i in
                    Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 8)
                        .position(x: x0 + (x1 - x0) * CGFloat(i) / 8, y: y)
                }

                Circle().fill(.white.opacity(0.75)).frame(width: 12, height: 12).position(x: aX, y: y)
                Text("a").font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.75)).position(x: aX, y: y + 17)

                Circle().fill(Color.mathGold).frame(width: 12, height: 12)
                    .shadow(color: Color.mathGold.opacity(0.6), radius: 4).position(x: bX, y: y)
                Text("b").font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(Color.mathGold).position(x: bX, y: y + 17)

                Text(bLess ? "b < a" : "b > a")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 105, y: 40)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 51 — a boundary line, its shaded half-plane, and a point classified in/out.
struct HalfPlaneConceptVisual: View {
    private func boundaryY(_ x: CGFloat) -> CGFloat { 110 - 0.41 * (x - 20) }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let p = CGPoint(x: 105 + 42 * CGFloat(cos(t * 0.9)), y: 74 + 26 * CGFloat(sin(t * 0.9)))
            let above = p.y < boundaryY(p.x)

            ZStack {
                // shaded region above the line
                Path { path in
                    path.move(to: CGPoint(x: 16, y: 18))
                    path.addLine(to: CGPoint(x: 196, y: 18))
                    path.addLine(to: CGPoint(x: 196, y: boundaryY(196)))
                    path.addLine(to: CGPoint(x: 16, y: boundaryY(16)))
                    path.closeSubpath()
                }
                .fill(Color.mathGold.opacity(0.12))

                // axes
                Path { path in
                    path.move(to: CGPoint(x: 24, y: 20)); path.addLine(to: CGPoint(x: 24, y: 116))
                    path.addLine(to: CGPoint(x: 196, y: 116))
                }
                .stroke(.white.opacity(0.35), lineWidth: 1)

                // boundary line
                Path { path in path.move(to: CGPoint(x: 16, y: boundaryY(16))); path.addLine(to: CGPoint(x: 196, y: boundaryY(196))) }
                    .stroke(Color.mathGold, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

                // classified point
                Circle().fill(above ? Color.mathGold : .white.opacity(0.35))
                    .frame(width: 13, height: 13)
                    .shadow(color: above ? Color.mathGold.opacity(0.7) : .clear, radius: 5)
                    .position(p)
                Image(systemName: above ? "checkmark" : "xmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(above ? .black : .white.opacity(0.6))
                    .position(p)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 52 — the unique line through two points, with slope m and intercept b.
struct LineEquationConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let axisX: CGFloat = 40
            let p1 = CGPoint(x: 74, y: 84)
            let p2 = CGPoint(x: 154, y: 42 + 20 * CGFloat(sin(t * 0.9)))
            let k = (p2.y - p1.y) / (p2.x - p1.x)
            let yAt: (CGFloat) -> CGFloat = { x in p1.y + k * (x - p1.x) }
            let leftY = yAt(axisX)
            let rightY = yAt(196)

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: axisX, y: 20)); p.addLine(to: CGPoint(x: axisX, y: 104))
                    p.addLine(to: CGPoint(x: 196, y: 104))
                }
                .stroke(.white.opacity(0.35), lineWidth: 1)

                Path { p in p.move(to: CGPoint(x: axisX, y: leftY)); p.addLine(to: CGPoint(x: 196, y: rightY)) }
                    .stroke(Color.mathGold, lineWidth: 2.5)
                    .shadow(color: Color.mathGold.opacity(0.5), radius: 4)

                Circle().fill(.white).frame(width: 8, height: 8).position(x: axisX, y: leftY)
                Text("b").font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.75)).position(x: axisX - 12, y: leftY)

                Circle().fill(Color.mathGold).frame(width: 11, height: 11)
                    .shadow(color: Color.mathGold.opacity(0.6), radius: 4).position(p1)
                Circle().fill(Color.mathGold).frame(width: 11, height: 11)
                    .shadow(color: Color.mathGold.opacity(0.6), radius: 4).position(p2)

                Text("m").font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(Color.mathGold.opacity(0.9))
                    .position(x: (p1.x + p2.x) / 2 + 8, y: (p1.y + p2.y) / 2 - 12)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 53 — two racers moving at different rates toward a finish line.
struct RateConceptVisual: View {
    private let x0: CGFloat = 30
    private let x1: CGFloat = 182

    var body: some View {
        TimelineView(.animation) { ctx in
            let cyc = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0)
            let ax = x0 + (x1 - x0) * CGFloat(min(cyc / 1.6, 1.0))   // faster rate
            let bx = x0 + (x1 - x0) * CGFloat(min(cyc / 2.6, 1.0))   // slower rate

            ZStack {
                Path { p in p.move(to: CGPoint(x: x1, y: 42)); p.addLine(to: CGPoint(x: x1, y: 112)) }
                    .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))

                lane(y: 62, x: ax, fill: Color.mathGold, label: "r₁")
                lane(y: 96, x: bx, fill: .white.opacity(0.7), label: "r₂")
            }
            .frame(width: 210, height: 140)
        }
    }

    @ViewBuilder
    private func lane(y: CGFloat, x: CGFloat, fill: Color, label: String) -> some View {
        Capsule().fill(.white.opacity(0.12)).frame(width: x1 - x0, height: 3).position(x: (x0 + x1) / 2, y: y)
        Capsule().fill(fill.opacity(0.7)).frame(width: max(x - x0, 1), height: 3).position(x: x0 + max(x - x0, 1) / 2, y: y)
        Circle().fill(fill).frame(width: 13, height: 13).shadow(color: fill.opacity(0.6), radius: 4).position(x: x, y: y)
        Text(label).font(.system(size: 11, weight: .bold, design: .serif)).foregroundStyle(fill).position(x: x0 - 14, y: y)
    }
}

// Level 54 — a whole splitting into two equal halves and back.
struct SplitConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let gap = CGFloat(abs(sin(ctx.date.timeIntervalSinceReferenceDate * 0.8))) * 26
            ZStack {
                half(x: 105 - 32 - gap / 2)
                half(x: 105 + 32 + gap / 2)
                Text("½").font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(.black).position(x: 105 - 32 - gap / 2, y: 66)
                Text("½").font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(.black).position(x: 105 + 32 + gap / 2, y: 66)
                Text("one whole").font(.system(size: 12, design: .serif)).foregroundStyle(.white.opacity(0.5)).position(x: 105, y: 116)
            }
            .frame(width: 210, height: 140)
        }
    }
    private func half(x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6).fill(Color.mathGold.opacity(0.85)).frame(width: 62, height: 50).position(x: x, y: 66)
    }
}

struct RationalFactoryConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { context in
            let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5) / 5
            Canvas { canvas, size in
                let plot = CGRect(x: 24, y: 15, width: size.width - 38, height: size.height - 36)
                let floorY = plot.maxY - 8

                var axes = Path()
                axes.move(to: CGPoint(x: plot.minX, y: plot.minY))
                axes.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                axes.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                canvas.stroke(axes, with: .color(.white.opacity(0.28)), lineWidth: 1)

                var floor = Path()
                floor.move(to: CGPoint(x: plot.minX, y: floorY))
                floor.addLine(to: CGPoint(x: plot.maxX, y: floorY))
                canvas.stroke(floor, with: .color(Color(red: 0.94, green: 0.25, blue: 0.23)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                var curve = Path()
                for step in 0...80 {
                    let q = 0.08 + 0.92 * Double(step) / 80
                    let normalizedCost = min(1, 0.12 + 0.16 / q)
                    let point = CGPoint(
                        x: plot.minX + CGFloat(q) * plot.width,
                        y: plot.minY + CGFloat(normalizedCost) * plot.height * 0.76
                    )
                    if step == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
                }
                canvas.stroke(curve, with: .color(Color.mathGold), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                let q = 0.08 + 0.92 * cycle
                let normalizedCost = min(1, 0.12 + 0.16 / q)
                let marker = CGPoint(
                    x: plot.minX + CGFloat(q) * plot.width,
                    y: plot.minY + CGFloat(normalizedCost) * plot.height * 0.76
                )
                canvas.fill(Path(ellipseIn: CGRect(x: marker.x - 5, y: marker.y - 5, width: 10, height: 10)), with: .color(Color(red: 0.18, green: 0.79, blue: 0.78)))

                for index in 0..<5 {
                    let x = 35 + CGFloat((cycle * 1.3 + Double(index) * 0.21).truncatingRemainder(dividingBy: 1)) * 145
                    let cube = CGRect(x: x, y: 116, width: 13, height: 13)
                    canvas.fill(Path(roundedRect: cube, cornerRadius: 2), with: .color(index.isMultiple(of: 2) ? Color.mathGold : Color(red: 0.18, green: 0.79, blue: 0.78)))
                }
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Average factory cost falls toward a horizontal asymptote as cube production increases")
    }
}

// Level 55 — hexagons tiling the plane with a sweeping highlight.
struct TessellationConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let r: CGFloat = 17
            let dx = r * 1.5, dy = r * CGFloat(3.0).squareRoot()
            ZStack {
                ForEach(0..<5, id: \.self) { col in
                    ForEach(0..<4, id: \.self) { row in
                        let x = 44 + CGFloat(col) * dx
                        let y = 36 + CGFloat(row) * dy + (col % 2 == 1 ? dy / 2 : 0)
                        let lit = sin(t * 1.3 - Double(col + row) * 0.6) > 0.2
                        Hexagon().fill(Color.mathGold.opacity(lit ? 0.7 : 0.12)).frame(width: r * 2 + 1, height: r * 2 + 1).position(x: x, y: y)
                        Hexagon().stroke(Color.mathGold.opacity(0.5), lineWidth: 1).frame(width: r * 2 + 1, height: r * 2 + 1).position(x: x, y: y)
                    }
                }
            }
            .frame(width: 210, height: 140)
        }
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2
        for i in 0..<6 {
            let a = Double(i) / 6 * 2 * Double.pi
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// Level 56 — a cross net folding up into a cube.
struct NetFoldConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let fold = (sin(ctx.date.timeIntervalSinceReferenceDate * 0.9) * 0.5 + 0.5) * 78
            let s: CGFloat = 30
            let c = CGPoint(x: 105, y: 70)
            ZStack {
                face().position(c)
                face().rotation3DEffect(.degrees(fold), axis: (1, 0, 0), anchor: .bottom).position(x: c.x, y: c.y - s)
                face().rotation3DEffect(.degrees(fold), axis: (1, 0, 0), anchor: .top).position(x: c.x, y: c.y + s)
                face().rotation3DEffect(.degrees(fold), axis: (0, 1, 0), anchor: .trailing).position(x: c.x - s, y: c.y)
                face().rotation3DEffect(.degrees(fold), axis: (0, 1, 0), anchor: .leading).position(x: c.x + s, y: c.y)
            }
            .frame(width: 210, height: 140)
        }
    }
    private func face() -> some View {
        RoundedRectangle(cornerRadius: 3).fill(Color.mathGold.opacity(0.22))
            .overlay { RoundedRectangle(cornerRadius: 3).stroke(Color.mathGold, lineWidth: 1.5) }
            .frame(width: 30, height: 30)
    }
}

// Level 57 — a shape translated, rotated, and reflected in turn.
struct TransformConceptVisual: View {
    private let steps = ["translate", "rotate", "reflect"]
    var body: some View {
        TimelineView(.animation) { ctx in
            let idx = Int(ctx.date.timeIntervalSinceReferenceDate / 1.5) % 3
            ZStack {
                arrow(color: .white.opacity(0.22)).position(x: 74, y: 74)
                Group {
                    switch idx {
                    case 0: arrow(color: Color.mathGold).position(x: 138, y: 74)
                    case 1: arrow(color: Color.mathGold).rotationEffect(.degrees(90)).position(x: 74, y: 74)
                    default: arrow(color: Color.mathGold).scaleEffect(x: -1, y: 1).position(x: 74, y: 74)
                    }
                }
                Text(steps[idx]).font(.system(size: 14, weight: .semibold, design: .serif)).foregroundStyle(Color.mathGold).position(x: 105, y: 120)
            }
            .frame(width: 210, height: 140)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: idx)
        }
    }
    private func arrow(color: Color) -> some View {
        Image(systemName: "arrowshape.right.fill").font(.system(size: 34)).foregroundStyle(color)
    }
}

// Level 58 — rectangles with the same area but changing perimeter.
struct GardenConceptVisual: View {
    private let dims: [(Int, Int)] = [(3, 8), (4, 6), (6, 4), (8, 3), (12, 2), (2, 12)]
    var body: some View {
        TimelineView(.animation) { ctx in
            let idx = Int(ctx.date.timeIntervalSinceReferenceDate / 1.3) % dims.count
            let (wU, hU) = dims[idx]
            let cell: CGFloat = 9
            let w = CGFloat(wU) * cell, h = CGFloat(hU) * cell
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color.mathGold.opacity(0.18)).frame(width: w, height: h).position(x: 105, y: 60)
                RoundedRectangle(cornerRadius: 3).stroke(Color.mathGold, lineWidth: 2).frame(width: w, height: h).position(x: 105, y: 60)
                HStack(spacing: 18) {
                    Text("A = \(wU * hU)").foregroundStyle(Color.mathGold)
                    Text("P = \(2 * (wU + hU))").foregroundStyle(.white.opacity(0.7))
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .position(x: 105, y: 124)
            }
            .frame(width: 210, height: 140)
            .animation(.easeInOut(duration: 0.4), value: idx)
        }
    }
}

// Level 59 — a point moving on a coordinate grid with its (x, y) readout.
struct CoordinateConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let gx = 1 + Int((sin(t * 0.5) * 0.5 + 0.5) * 5)
            let gy = 1 + Int((cos(t * 0.7) * 0.5 + 0.5) * 4)
            let ox: CGFloat = 32, oy: CGFloat = 116, step: CGFloat = 23
            let px = ox + CGFloat(gx) * step, py = oy - CGFloat(gy) * step
            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    Path { p in let x = ox + CGFloat(i) * step; p.move(to: CGPoint(x: x, y: oy)); p.addLine(to: CGPoint(x: x, y: oy - 118)) }
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }
                ForEach(0..<6, id: \.self) { i in
                    Path { p in let y = oy - CGFloat(i) * step; p.move(to: CGPoint(x: ox, y: y)); p.addLine(to: CGPoint(x: ox + 6 * step, y: y)) }
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }
                Path { p in p.move(to: CGPoint(x: ox, y: oy - 118)); p.addLine(to: CGPoint(x: ox, y: oy)); p.addLine(to: CGPoint(x: ox + 150, y: oy)) }
                    .stroke(.white.opacity(0.5), lineWidth: 1.5)
                Path { p in p.move(to: CGPoint(x: px, y: py)); p.addLine(to: CGPoint(x: px, y: oy)); p.move(to: CGPoint(x: px, y: py)); p.addLine(to: CGPoint(x: ox, y: py)) }
                    .stroke(Color.mathGold.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Circle().fill(Color.mathGold).frame(width: 13, height: 13).shadow(color: Color.mathGold.opacity(0.6), radius: 4)
                    .position(x: px, y: py)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: CGPoint(x: px, y: py))
                Text("(\(gx), \(gy))").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Color.mathGold)
                    .position(x: px + 24, y: py - 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: CGPoint(x: px, y: py))
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 60 — a memory board where matching pairs flip face-up.
struct MemoryConceptVisual: View {
    private let symbols = ["star.fill", "circle.fill", "suit.diamond.fill", "triangle.fill"]
    var body: some View {
        TimelineView(.animation) { ctx in
            let step = Int(ctx.date.timeIntervalSinceReferenceDate / 1.1) % 4
            ZStack {
                let layout: [(Int, CGPoint)] = [
                    (0, CGPoint(x: 58, y: 52)), (1, CGPoint(x: 105, y: 52)), (2, CGPoint(x: 152, y: 52)),
                    (3, CGPoint(x: 58, y: 100)), (0, CGPoint(x: 105, y: 100)), (1, CGPoint(x: 152, y: 100))
                ]
                ForEach(layout.indices, id: \.self) { i in
                    let (sym, pos) = layout[i]
                    card(symbols[sym], up: sym == step).position(pos)
                }
            }
            .frame(width: 210, height: 140)
            .animation(.easeInOut(duration: 0.25), value: step)
        }
    }
    private func card(_ symbol: String, up: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(up ? Color.mathGold.opacity(0.85) : .white.opacity(0.08))
            RoundedRectangle(cornerRadius: 6).stroke(Color.mathGold.opacity(up ? 0.9 : 0.4), lineWidth: 1.2)
            if up { Image(systemName: symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(.black) }
        }
        .frame(width: 34, height: 40)
    }
}

// Level 61 — lines and receding frames converging to a vanishing point.
struct PerspectiveConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let vp = CGPoint(x: 105, y: 60)
            let corners = [CGPoint(x: 16, y: 24), CGPoint(x: 194, y: 24), CGPoint(x: 194, y: 122), CGPoint(x: 16, y: 122)]
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    Path { p in p.move(to: corners[i]); p.addLine(to: vp) }.stroke(Color.mathGold.opacity(0.3), lineWidth: 1)
                }
                ForEach(0..<4, id: \.self) { k in
                    let ph = (t * 0.4 + Double(k) * 0.25).truncatingRemainder(dividingBy: 1.0)
                    let w = 150 * CGFloat(0.08 + ph * 0.92)
                    let cy = vp.y + (122 - vp.y) * CGFloat(ph)
                    RoundedRectangle(cornerRadius: 2).stroke(Color.mathGold.opacity(ph * 0.9), lineWidth: 1.5)
                        .frame(width: w, height: w * 0.58).position(x: vp.x, y: cy)
                }
                Circle().fill(Color.mathGold).frame(width: 7, height: 7).shadow(color: Color.mathGold.opacity(0.8), radius: 4).position(vp)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 62 — two points with a right triangle; the hypotenuse is the distance.
struct DistanceConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let a = CGPoint(x: 52, y: 102)
            let b = CGPoint(x: 118 + 42 * CGFloat(sin(t * 0.6)), y: 44 + 16 * CGFloat(cos(t * 0.8)))
            let c = CGPoint(x: b.x, y: a.y)
            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    Path { p in let x = 24 + CGFloat(i) * 26; p.move(to: CGPoint(x: x, y: 24)); p.addLine(to: CGPoint(x: x, y: 116)) }
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
                Path { p in p.move(to: a); p.addLine(to: c); p.addLine(to: b) }
                    .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                Path { p in p.move(to: a); p.addLine(to: b) }
                    .stroke(Color.mathGold, lineWidth: 2.5).shadow(color: Color.mathGold.opacity(0.5), radius: 4)
                Circle().fill(.white).frame(width: 11, height: 11).position(a)
                Circle().fill(Color.mathGold).frame(width: 11, height: 11).shadow(color: Color.mathGold.opacity(0.6), radius: 4).position(b)
                Text("Δx").font(.system(size: 10, weight: .semibold, design: .serif)).foregroundStyle(.white.opacity(0.6)).position(x: (a.x + c.x) / 2, y: a.y + 11)
                Text("Δy").font(.system(size: 10, weight: .semibold, design: .serif)).foregroundStyle(.white.opacity(0.6)).position(x: c.x + 12, y: (c.y + b.y) / 2)
                Text("d").font(.system(size: 12, weight: .bold, design: .serif)).foregroundStyle(Color.mathGold).position(x: (a.x + b.x) / 2 - 10, y: (a.y + b.y) / 2 - 9)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 63 — nested similar shapes scaling by a factor k.
struct ScaleConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let s = 0.55 + 0.45 * abs(sin(ctx.date.timeIntervalSinceReferenceDate * 0.7))
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let sc = s * (1 - Double(i) * 0.3)
                    HouseShape().stroke(Color.mathGold.opacity(0.85 - Double(i) * 0.22), lineWidth: 2)
                        .frame(width: CGFloat(96 * sc), height: CGFloat(84 * sc)).position(x: 105, y: 74)
                }
                Text("×k").font(.system(size: 14, weight: .bold, design: .serif)).foregroundStyle(Color.mathGold.opacity(0.7)).position(x: 174, y: 42)
            }
            .frame(width: 210, height: 140)
        }
    }
}

struct HouseShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// Level 64 — a token searching a state graph to reach the goal.
struct StateGraphConceptVisual: View {
    private let nodes: [CGPoint] = [CGPoint(x: 34, y: 100), CGPoint(x: 80, y: 54), CGPoint(x: 118, y: 96), CGPoint(x: 150, y: 46), CGPoint(x: 186, y: 92)]
    private let edges: [(Int, Int)] = [(0, 1), (1, 2), (1, 3), (2, 3), (3, 4), (2, 4)]
    private let route = [0, 1, 3, 4]

    var body: some View {
        TimelineView(.animation) { ctx in
            let segs = route.count - 1
            let u = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
            let prog = u * Double(segs)
            let seg = min(Int(prog), segs - 1)
            let lt = CGFloat(prog - Double(seg))
            let a = nodes[route[seg]], b = nodes[route[seg + 1]]
            let dot = CGPoint(x: a.x + (b.x - a.x) * lt, y: a.y + (b.y - a.y) * lt)
            ZStack {
                ForEach(edges.indices, id: \.self) { i in
                    Path { p in p.move(to: nodes[edges[i].0]); p.addLine(to: nodes[edges[i].1]) }.stroke(.white.opacity(0.2), lineWidth: 1)
                }
                ForEach(0..<segs, id: \.self) { i in
                    if i <= seg {
                        Path { p in p.move(to: nodes[route[i]]); p.addLine(to: nodes[route[i + 1]]) }.stroke(Color.mathGold, lineWidth: 2)
                    }
                }
                ForEach(nodes.indices, id: \.self) { i in
                    let hi = i == route.first || i == route.last
                    Circle().fill(i == route.last ? Color.mathGold : .white).frame(width: hi ? 13 : 10, height: hi ? 13 : 10).position(nodes[i])
                }
                Circle().fill(Color.mathGold).frame(width: 8, height: 8).shadow(color: Color.mathGold.opacity(0.7), radius: 4).position(dot)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 65 — a metronome arm swinging with the beat.
struct MetronomeConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let beat = ctx.date.timeIntervalSinceReferenceDate * 1.6
            let armAngle = sin(beat * Double.pi) * 0.5
            let pivot = CGPoint(x: 105, y: 106)
            let tip = CGPoint(x: pivot.x + CGFloat(sin(armAngle)) * 64, y: pivot.y - CGFloat(cos(armAngle)) * 64)
            let active = Int(beat) % 5
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Circle().fill(Color.mathGold.opacity(i == active ? 1 : 0.3))
                        .frame(width: i == active ? 11 : 7, height: i == active ? 11 : 7)
                        .position(x: 50 + CGFloat(i) * 28, y: 32)
                }
                Path { p in p.move(to: pivot); p.addLine(to: tip) }.stroke(Color.mathGold, lineWidth: 3).shadow(color: Color.mathGold.opacity(0.5), radius: 4)
                Circle().fill(Color.mathGold).frame(width: 12, height: 12).position(tip)
                Circle().fill(.white.opacity(0.5)).frame(width: 6, height: 6).position(pivot)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 66 — two sine waves drifting through phase (in and out of phase).
struct PhaseConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                sine(phase: 0, color: Color.mathGold, t: t)
                sine(phase: t * 1.0, color: Color(red: 0.5, green: 0.8, blue: 1.0), t: t)
            }
            .frame(width: 210, height: 140)
        }
    }
    private func sine(phase: Double, color: Color, t: Double) -> some View {
        Path { p in
            let steps = 90
            for i in 0...steps {
                let f = Double(i) / Double(steps)
                let x = 20 + 170 * CGFloat(f)
                let y = 70 - 26 * CGFloat(sin(f * 3 * 2 * Double.pi - t * 2 - phase))
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
        .stroke(color, lineWidth: 2.2)
    }
}

// Level 67 — an ADSR envelope with a moving playhead.
struct EnvelopeConceptVisual: View {
    private let pts: [CGPoint] = [CGPoint(x: 24, y: 112), CGPoint(x: 58, y: 32), CGPoint(x: 88, y: 62), CGPoint(x: 150, y: 62), CGPoint(x: 188, y: 112)]
    private let labels = ["A", "D", "S", "R"]
    private let labelX: [CGFloat] = [40, 73, 119, 169]

    var body: some View {
        TimelineView(.animation) { ctx in
            let u = CGFloat(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6)
            ZStack {
                Path { p in p.move(to: pts[0]); for pt in pts.dropFirst() { p.addLine(to: pt) }; p.closeSubpath() }
                    .fill(Color.mathGold.opacity(0.12))
                Path { p in for (i, pt) in pts.enumerated() { if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) } } }
                    .stroke(Color.mathGold, lineWidth: 2.5).shadow(color: Color.mathGold.opacity(0.5), radius: 4)
                ForEach(0..<4, id: \.self) { i in
                    Text(labels[i]).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55)).position(x: labelX[i], y: 122)
                }
                Rectangle().fill(.white.opacity(0.5)).frame(width: 1.5, height: 90).position(x: 24 + (188 - 24) * u, y: 66)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 68 — a swinging pendulum over its arc.
struct PeriodicWaveFamilyConceptVisual: View {
    private let colors = [
        Color(red: 0.18, green: 0.78, blue: 1.0),
        Color(red: 1.0, green: 0.68, blue: 0.16),
        Color(red: 0.24, green: 0.84, blue: 0.48),
        Color(red: 1.0, green: 0.34, blue: 0.28)
    ]
    private let labels = ["S", "Q", "T", "W"]

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.4) / 3.4)

            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    let y = CGFloat(7 + index * 33)

                    Text(labels[index])
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(colors[index])
                        .position(x: 8, y: y + 14)

                    PeriodicMiniWaveShape(kind: index)
                        .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(width: 188, height: 28)
                        .position(x: 112, y: y + 14)

                    PeriodicMiniWaveShape(kind: index)
                        .trim(from: 0, to: max(0, min(1, progress * 1.35 - CGFloat(index) * 0.06)))
                        .stroke(colors[index], style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 188, height: 28)
                        .position(x: 112, y: y + 14)
                }
            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Sine, square, triangle, and sawtooth functions repeating in four colored rows")
    }
}

private struct PeriodicMiniWaveShape: Shape {
    let kind: Int

    func path(in rect: CGRect) -> Path {
        switch kind {
        case 1: squarePath(in: rect)
        case 2: smoothPath(in: rect) { phase in 2 / Double.pi * asin(sin(phase * Double.pi * 4)) }
        case 3: sawtoothPath(in: rect)
        default: smoothPath(in: rect) { phase in sin(phase * Double.pi * 4) }
        }
    }

    private func smoothPath(in rect: CGRect, value: (Double) -> Double) -> Path {
        Path { path in
            for index in 0...160 {
                let t = Double(index) / 160
                let point = CGPoint(
                    x: rect.minX + rect.width * CGFloat(t),
                    y: rect.midY - rect.height * 0.38 * CGFloat(value(t))
                )
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
    }

    private func squarePath(in rect: CGRect) -> Path {
        Path { path in
            let high = rect.minY + rect.height * 0.18
            let low = rect.maxY - rect.height * 0.18
            path.move(to: CGPoint(x: rect.minX, y: high))
            for segment in 0..<4 {
                let x = rect.minX + rect.width * CGFloat(segment + 1) / 4
                let y = segment.isMultiple(of: 2) ? high : low
                let nextY = segment.isMultiple(of: 2) ? low : high
                path.addLine(to: CGPoint(x: x, y: y))
                if segment < 3 { path.addLine(to: CGPoint(x: x, y: nextY)) }
            }
        }
    }

    private func sawtoothPath(in rect: CGRect) -> Path {
        Path { path in
            let high = rect.minY + rect.height * 0.18
            let low = rect.maxY - rect.height * 0.18
            path.move(to: CGPoint(x: rect.minX, y: low))
            for cycle in 0..<2 {
                let x = rect.minX + rect.width * CGFloat(cycle + 1) / 2
                path.addLine(to: CGPoint(x: x, y: high))
                if cycle < 1 { path.addLine(to: CGPoint(x: x, y: low)) }
            }
        }
    }
}

struct PendulumConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let a = 0.7 * sin(ctx.date.timeIntervalSinceReferenceDate * 2.0)
            let pivot = CGPoint(x: 105, y: 30)
            let L: CGFloat = 74
            let bob = CGPoint(x: pivot.x + CGFloat(sin(a)) * L, y: pivot.y + CGFloat(cos(a)) * L)
            ZStack {
                Path { p in p.addArc(center: pivot, radius: L, startAngle: .degrees(130), endAngle: .degrees(50), clockwise: true) }
                    .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                Path { p in p.move(to: pivot); p.addLine(to: bob) }.stroke(.white.opacity(0.5), lineWidth: 2)
                Circle().fill(Color.mathGold).frame(width: 20, height: 20).shadow(color: Color.mathGold.opacity(0.6), radius: 6).position(bob)
                Circle().fill(.white.opacity(0.5)).frame(width: 6, height: 6).position(pivot)
                Text("L").font(.system(size: 12, weight: .semibold, design: .serif)).foregroundStyle(.white.opacity(0.6)).position(x: (pivot.x + bob.x) / 2 - 12, y: (pivot.y + bob.y) / 2)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 69 — a cosine wave with amplitude, wavelength, and phase.
struct UpdraftConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = t * 1.7
            let midY: CGFloat = 72
            let amp: CGFloat = 34
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 16, y: midY))
                    p.addLine(to: CGPoint(x: 194, y: midY))
                }
                .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                Path { p in
                    p.move(to: CGPoint(x: 34, y: midY))
                    p.addLine(to: CGPoint(x: 34, y: midY - amp))
                }
                .stroke(Color(red: 0.45, green: 0.78, blue: 1.0).opacity(0.85), lineWidth: 2)

                Path { p in
                    let steps = 100
                    for i in 0...steps {
                        let u = CGFloat(i) / CGFloat(steps)
                        let x = 16 + 178 * u
                        let y = midY - amp * CGFloat(cos(Double(u) * 2.0 * Double.pi - phase))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.mathGold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .shadow(color: Color.mathGold.opacity(0.55), radius: 7)

                Path { p in
                    p.move(to: CGPoint(x: 34, y: 118))
                    p.addLine(to: CGPoint(x: 122, y: 118))
                }
                .stroke(.white.opacity(0.28), lineWidth: 1.5)

                Text("A")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.45, green: 0.78, blue: 1.0))
                    .position(x: 26, y: 56)
                Text("one cycle")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.58))
                    .position(x: 78, y: 130)
                Text("cos")
                    .font(.system(size: 18, weight: .black, design: .serif))
                    .foregroundStyle(Color.mathGold)
                    .position(x: 36, y: 18)
                Text("y = A cos(2πft + φ)")
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.mathGold.opacity(0.9))
                    .position(x: 126, y: 18)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 70 — three tones at consonant frequency ratios forming a chord.
struct ChordConceptVisual: View {
    private let data: [(freq: Double, ratio: String, y: CGFloat)] = [(2, "2:1", 42), (3, "3:2", 74), (4, "5:4", 106)]
    private let cols: [Color] = [Color.mathGold, Color(red: 0.5, green: 0.8, blue: 1.0), Color(red: 1.0, green: 0.6, blue: 0.45)]

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    sine(freq: data[i].freq, y: data[i].y, color: cols[i], t: t)
                    Text(data[i].ratio).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(cols[i]).position(x: 197, y: data[i].y)
                }
            }
            .frame(width: 210, height: 140)
        }
    }
    private func sine(freq: Double, y: CGFloat, color: Color, t: Double) -> some View {
        Path { p in
            let steps = 90
            for i in 0...steps {
                let f = Double(i) / Double(steps)
                let x = 16 + 160 * CGFloat(f)
                let yy = y - 13 * CGFloat(sin(freq * f * 2 * Double.pi - t * 2))
                if i == 0 { p.move(to: CGPoint(x: x, y: yy)) } else { p.addLine(to: CGPoint(x: x, y: yy)) }
            }
        }
        .stroke(color, lineWidth: 2)
    }
}

// Level 71 — a pulse travelling to a wall and echoing back.
struct EchoConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let cyc = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4)
            let emit = CGPoint(x: 26, y: 70)
            let wallX: CGFloat = 184
            let px: CGFloat = cyc < 1.2 ? emit.x + (wallX - emit.x) * CGFloat(cyc / 1.2)
                                        : wallX - (wallX - emit.x) * CGFloat((cyc - 1.2) / 1.2)
            ZStack {
                Rectangle().fill(.white.opacity(0.5)).frame(width: 4, height: 72).position(x: wallX, y: 70)
                Circle().fill(Color.mathGold.opacity(0.4)).frame(width: 18, height: 18).position(emit)
                Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 14)).foregroundStyle(Color.mathGold).position(emit)
                ForEach(0..<3, id: \.self) { k in
                    Circle().stroke(Color.mathGold.opacity(0.7 - Double(k) * 0.2), lineWidth: 2)
                        .frame(width: CGFloat(10 + k * 8), height: CGFloat(20 + k * 10)).position(x: px, y: 70)
                }
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 72 — two wave sources whose expanding rings interfere.
struct InterferenceConceptVisual: View {
    private let centers = [CGPoint(x: 70, y: 70), CGPoint(x: 140, y: 70)]
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<2, id: \.self) { ci in
                    ForEach(0..<5, id: \.self) { k in
                        let phase = (t * 0.8 + Double(k) * 0.2).truncatingRemainder(dividingBy: 1.0)
                        let r = CGFloat(phase) * 68
                        Circle().stroke(Color.mathGold.opacity((1 - phase) * 0.55), lineWidth: 1.6)
                            .frame(width: r * 2, height: r * 2).position(centers[ci])
                    }
                }
                ForEach(0..<2, id: \.self) { ci in Circle().fill(Color.mathGold).frame(width: 7, height: 7).position(centers[ci]) }
            }
            .frame(width: 210, height: 140)
            .clipped()
        }
    }
}

// Level 73 — a moving source with rings bunched ahead, spread behind.
struct DopplerConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let sx = 40 + CGFloat((t * 40).truncatingRemainder(dividingBy: 130))
            ZStack {
                ForEach(0..<6, id: \.self) { k in
                    let age = Double(k) * 0.28
                    let emitX = sx - CGFloat(age * 40)
                    let r = CGFloat(age * 46)
                    Circle().stroke(Color.mathGold.opacity(max(0, 0.6 - age * 0.5)), lineWidth: 1.6)
                        .frame(width: r * 2, height: r * 2).position(x: emitX, y: 70)
                }
                Circle().fill(Color.mathGold).frame(width: 12, height: 12).shadow(color: Color.mathGold.opacity(0.7), radius: 4).position(x: sx, y: 70)
                Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.black).position(x: sx, y: 70)
            }
            .frame(width: 210, height: 140)
            .clipped()
        }
    }
}

// Level 74 — the circle of fifths, hopping by sevens around twelve tones.
struct CircleOfFifthsConceptVisual: View {
    private let c = CGPoint(x: 105, y: 70)
    private let R: CGFloat = 50
    private func point(_ i: Int) -> CGPoint {
        let a = Double(i) / 12 * 2 * Double.pi - .pi / 2
        return CGPoint(x: c.x + CGFloat(cos(a)) * R, y: c.y + CGFloat(sin(a)) * R)
    }
    var body: some View {
        TimelineView(.animation) { ctx in
            let step = Int(ctx.date.timeIntervalSinceReferenceDate * 1.2) % 12
            let cur = (step * 7) % 12
            let nxt = ((step + 1) * 7) % 12
            ZStack {
                Circle().stroke(.white.opacity(0.2), lineWidth: 1).frame(width: R * 2, height: R * 2).position(c)
                Path { p in p.move(to: point(cur)); p.addLine(to: point(nxt)) }.stroke(Color.mathGold.opacity(0.7), lineWidth: 1.5)
                ForEach(0..<12, id: \.self) { i in
                    Circle().fill(i == cur ? Color.mathGold : .white.opacity(0.35))
                        .frame(width: i == cur ? 14 : 9, height: i == cur ? 14 : 9).position(point(i))
                }
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 75 — a ladder of harmonics, each an integer multiple of the fundamental.
struct HarmonicLadderConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<4, id: \.self) { n in
                    let y = 34 + CGFloat(n) * 28
                    wave(freq: Double(n + 1), y: y, t: t)
                    Text("×\(n + 1)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color.mathGold.opacity(0.7)).position(x: 197, y: y)
                }
            }
            .frame(width: 210, height: 140)
        }
    }
    private func wave(freq: Double, y: CGFloat, t: Double) -> some View {
        Path { p in
            let steps = 100
            for i in 0...steps {
                let f = Double(i) / Double(steps)
                let x = 16 + 160 * CGFloat(f)
                let yy = y - 11 * CGFloat(sin(freq * f * 2 * Double.pi - t * 2))
                if i == 0 { p.move(to: CGPoint(x: x, y: yy)) } else { p.addLine(to: CGPoint(x: x, y: yy)) }
            }
        }
        .stroke(Color.mathGold.opacity(0.85), lineWidth: 2)
    }
}

// Level 76 — disks moving between three pegs (Towers of Hanoi).
struct HanoiConceptVisual: View {
    private let pegX: [CGFloat] = [52, 105, 158]
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Rectangle().fill(.white.opacity(0.3)).frame(width: 2, height: 60).position(x: pegX[i], y: 82)
                    Rectangle().fill(.white.opacity(0.3)).frame(width: 46, height: 3).position(x: pegX[i], y: 112)
                }
                ForEach(0..<3, id: \.self) { d in
                    let w = CGFloat(42 - d * 11)
                    let peg = (Int(t * 0.8) + d) % 3
                    RoundedRectangle(cornerRadius: 3).fill(Color.mathGold.opacity(0.85)).frame(width: w, height: 12).position(x: pegX[peg], y: CGFloat(104 - d * 13))
                }
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 77 — a square rotating about the origin by a rotation matrix.
struct MatrixRotationConceptVisual: View {
    private let c = CGPoint(x: 105, y: 70)
    private let s: CGFloat = 34
    private let corners: [(Double, Double)] = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    private func rot(_ p: (Double, Double), _ a: Double) -> CGPoint {
        let x = p.0 * cos(a) - p.1 * sin(a)
        let y = p.0 * sin(a) + p.1 * cos(a)
        return CGPoint(x: c.x + CGFloat(x) * s, y: c.y + CGFloat(y) * s)
    }
    var body: some View {
        TimelineView(.animation) { ctx in
            let a = ctx.date.timeIntervalSinceReferenceDate * 0.7
            let pts = corners.map { rot($0, a) }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: c.x - 56, y: c.y)); p.addLine(to: CGPoint(x: c.x + 56, y: c.y))
                    p.move(to: CGPoint(x: c.x, y: c.y - 56)); p.addLine(to: CGPoint(x: c.x, y: c.y + 56))
                }
                .stroke(.white.opacity(0.25), lineWidth: 1)
                Path { p in for (i, pt) in pts.enumerated() { if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) } }; p.closeSubpath() }
                    .fill(Color.mathGold.opacity(0.1))
                Path { p in for (i, pt) in pts.enumerated() { if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) } }; p.closeSubpath() }
                    .stroke(Color.mathGold, lineWidth: 2)
                Circle().fill(.white).frame(width: 8, height: 8).position(pts[0])
                Text("θ").font(.system(size: 12, weight: .bold, design: .serif)).foregroundStyle(Color.mathGold).position(x: c.x + 22, y: c.y - 14)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 78 — directional change across a surface f(x, y).
struct PartialDerivativesConceptVisual: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 28, y: 95))
                path.addLine(to: CGPoint(x: 100, y: 42))
                path.addLine(to: CGPoint(x: 184, y: 77))
                path.addLine(to: CGPoint(x: 108, y: 126))
                path.closeSubpath()
            }
            .fill(Color.mathGold.opacity(0.08))
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: 28, y: 95))
                    path.addLine(to: CGPoint(x: 100, y: 42))
                    path.addLine(to: CGPoint(x: 184, y: 77))
                    path.addLine(to: CGPoint(x: 108, y: 126))
                    path.closeSubpath()
                }
                .stroke(.white.opacity(0.20), lineWidth: 1)
            }

            ForEach(1..<4, id: \.self) { index in
                let t = CGFloat(index) / 4
                Path { path in
                    path.move(to: CGPoint(x: 28 + (100 - 28) * t, y: 95 + (42 - 95) * t))
                    path.addLine(to: CGPoint(x: 108 + (184 - 108) * t, y: 126 + (77 - 126) * t))
                }
                .stroke(.white.opacity(0.11), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: 28 + (108 - 28) * t, y: 95 + (126 - 95) * t))
                    path.addLine(to: CGPoint(x: 100 + (184 - 100) * t, y: 42 + (77 - 42) * t))
                }
                .stroke(.white.opacity(0.11), lineWidth: 1)
            }

            Path { path in
                path.move(to: CGPoint(x: 44, y: 94))
                path.addQuadCurve(to: CGPoint(x: 170, y: 76), control: CGPoint(x: 105, y: 43))
            }
            .stroke(Color(red: 0.22, green: 0.86, blue: 0.94), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .shadow(color: Color(red: 0.22, green: 0.86, blue: 0.94).opacity(0.65), radius: pulse ? 8 : 3)

            Path { path in
                path.move(to: CGPoint(x: 78, y: 54))
                path.addQuadCurve(to: CGPoint(x: 128, y: 116), control: CGPoint(x: 125, y: 78))
            }
            .stroke(Color.mathGold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .shadow(color: Color.mathGold.opacity(0.65), radius: pulse ? 3 : 8)

            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .shadow(color: .white.opacity(0.8), radius: 6)
                .position(x: 108, y: 79)

            Text("∂f/∂x")
                .font(.system(size: 11, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 0.22, green: 0.86, blue: 0.94))
                .position(x: 166, y: 55)

            Text("∂f/∂y")
                .font(.system(size: 11, weight: .black, design: .serif))
                .foregroundStyle(Color.mathGold)
                .position(x: 70, y: 45)
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// Level 79 — bars settling from shuffled to sorted order.
struct SortBarsConceptVisual: View {
    private let base: [CGFloat] = [34, 72, 46, 92, 56, 80, 40, 64]
    var body: some View {
        TimelineView(.animation) { ctx in
            let phase = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.0) / 4.0
            let sorted = base.sorted()
            let mix = CGFloat(min(max((phase - 0.2) / 0.6, 0), 1))
            let hs = zip(base, sorted).map { $0 + ($1 - $0) * mix }
            HStack(spacing: 5) {
                ForEach(hs.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(Color.mathGold.opacity(0.85)).frame(width: 16, height: hs[i])
                }
            }
            .frame(width: 210, height: 140, alignment: .bottom)
            .padding(.bottom, 22)
        }
    }
}

// Level 80 — two circles that flash red when they draw too close.
struct NoContactConceptVisual: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let aC = CGPoint(x: 70 + 26 * CGFloat(sin(t * 0.9)), y: 70)
            let bC = CGPoint(x: 140 + 26 * CGFloat(sin(t * 0.9 + .pi)), y: 70)
            let r1: CGFloat = 22, r2: CGFloat = 18
            let dist = hypot(aC.x - bC.x, aC.y - bC.y)
            let touching = dist < r1 + r2 + 4
            let col = touching ? Color(red: 1.0, green: 0.4, blue: 0.35) : Color.mathGold
            ZStack {
                Path { p in p.move(to: aC); p.addLine(to: bC) }.stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Circle().stroke(col, lineWidth: 2.5).frame(width: r1 * 2, height: r1 * 2).position(aC).shadow(color: col.opacity(0.5), radius: touching ? 8 : 3)
                Circle().stroke(col, lineWidth: 2.5).frame(width: r2 * 2, height: r2 * 2).position(bC).shadow(color: col.opacity(0.5), radius: touching ? 8 : 3)
                Text("d").font(.system(size: 11, weight: .bold, design: .serif)).foregroundStyle(.white.opacity(0.6)).position(x: (aC.x + bC.x) / 2, y: 56)
            }
            .frame(width: 210, height: 140)
        }
    }
}

struct NQueensConceptVisual: View {
    private let placements = [(row: 0, column: 1), (row: 1, column: 3), (row: 2, column: 0), (row: 3, column: 2)]

    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.0)
            let visibleCount = min(4, max(1, Int(phase) + 1))

            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Path { path in
                        let offset = CGFloat(index) * 27
                        path.move(to: CGPoint(x: 48 + offset, y: 16))
                        path.addLine(to: CGPoint(x: 48 + offset, y: 124))
                        path.move(to: CGPoint(x: 48, y: 16 + offset))
                        path.addLine(to: CGPoint(x: 156, y: 16 + offset))
                    }
                    .stroke(.white.opacity(index == 0 ? 0.36 : 0.16), lineWidth: index == 0 ? 1.5 : 1)
                }

                ForEach(0..<visibleCount, id: \.self) { index in
                    let placement = placements[index]
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 19, height: 19)
                        .background(Color.mathGold, in: Circle())
                        .position(
                            x: 61.5 + CGFloat(placement.column) * 27,
                            y: 29.5 + CGFloat(placement.row) * 27
                        )
                }

            }
            .frame(width: 210, height: 140)
        }
        .accessibilityLabel("Four nonattacking queens placed on a four by four constraint grid")
    }
}

// Level 81 — numerical clues forcing cell states in a logic grid.
struct NonogramConceptVisual: View {
    @State private var phase = false
    private let filled: Set<Int> = [1, 2, 5, 7, 8, 10, 11, 12, 16, 17, 21, 22, 23]

    var body: some View {
        ZStack {
            ForEach(0..<25, id: \.self) { i in
                let row = i / 5
                let col = i % 5
                let active = filled.contains(i)
                RoundedRectangle(cornerRadius: 3)
                    .fill(active ? Color.mathGold.opacity(phase ? 0.9 : 0.55) : .white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(active ? Color.mathGold.opacity(0.8) : .white.opacity(0.2), lineWidth: 1)
                    }
                    .frame(width: 19, height: 19)
                    .position(x: 64 + CGFloat(col) * 21, y: 26 + CGFloat(row) * 21)
            }
            ForEach(Array(["2", "2", "3", "2", "3"].enumerated()), id: \.offset) { i, label in
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .position(x: 42, y: 26 + CGFloat(i) * 21)
            }
            ForEach(Array(["1", "3", "2", "3", "1"].enumerated()), id: \.offset) { i, label in
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .position(x: 64 + CGFloat(i) * 21, y: 12)
            }
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

// Level 82 — legal river-crossing states linked as a constraint graph.
struct RiverConceptVisual: View {
    @State private var glow = false
    private let nodes = [
        CGPoint(x: 42, y: 30), CGPoint(x: 82, y: 46), CGPoint(x: 126, y: 34),
        CGPoint(x: 62, y: 88), CGPoint(x: 112, y: 104), CGPoint(x: 166, y: 82)
    ]
    private let edges = [(0, 1), (1, 2), (1, 3), (3, 4), (4, 5), (2, 5)]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.mathGold.opacity(0.08))
                .frame(width: 42, height: 132)
                .position(x: 105, y: 70)
            Path { p in
                p.move(to: CGPoint(x: 94, y: 8))
                p.addCurve(to: CGPoint(x: 116, y: 132), control1: CGPoint(x: 122, y: 40), control2: CGPoint(x: 82, y: 86))
            }
            .stroke(Color.mathGold.opacity(0.45), lineWidth: 2)

            ForEach(edges.indices, id: \.self) { i in
                let edge = edges[i]
                Path { p in
                    p.move(to: nodes[edge.0])
                    p.addLine(to: nodes[edge.1])
                }
                .stroke(Color.mathGold.opacity(glow && i % 2 == 0 ? 0.75 : 0.25), lineWidth: 1.4)
            }

            ForEach(nodes.indices, id: \.self) { i in
                Circle()
                    .fill(i == 0 || i == nodes.count - 1 ? Color.mathGold : .black)
                    .overlay { Circle().stroke(.white.opacity(0.75), lineWidth: 1.4) }
                    .frame(width: i == 0 || i == nodes.count - 1 ? 15 : 11, height: i == 0 || i == nodes.count - 1 ? 15 : 11)
                    .position(nodes[i])
            }
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// Level 83 — stock-flow accumulation in a reservoir.
struct ReservoirConceptVisual: View {
    @State private var high = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.45), lineWidth: 2)
                .frame(width: 78, height: 92)
                .position(x: 106, y: 76)
            Rectangle()
                .fill(Color.mathGold.opacity(0.55))
                .frame(width: 70, height: high ? 64 : 36)
                .position(x: 106, y: high ? 88 : 102)
                .mask {
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: 72, height: 88)
                        .position(x: 106, y: 78)
                }
            arrow(from: CGPoint(x: 30, y: 42), to: CGPoint(x: 70, y: 58), color: Color.mathGold)
            arrow(from: CGPoint(x: 144, y: 96), to: CGPoint(x: 184, y: 112), color: .white.opacity(0.55))
            Text("in")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.mathGold)
                .position(x: 38, y: 28)
            Text("out")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .position(x: 175, y: 92)
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                high = true
            }
        }
    }

    private func arrow(from a: CGPoint, to b: CGPoint, color: Color) -> some View {
        Path { p in
            p.move(to: a)
            p.addLine(to: b)
            p.move(to: b)
            p.addLine(to: CGPoint(x: b.x - 10, y: b.y - 7))
            p.move(to: b)
            p.addLine(to: CGPoint(x: b.x - 11, y: b.y + 4))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
}

// Level 84 — lattice cells updating from local neighborhood rules.
struct LatticeConceptVisual: View {
    @State private var radius = 0

    var body: some View {
        ZStack {
            ForEach(0..<49, id: \.self) { i in
                let row = i / 7
                let col = i % 7
                let d = abs(row - 3) + abs(col - 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(d <= radius ? Color.mathGold.opacity(0.85 - Double(d) * 0.12) : .white.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }
                    .frame(width: 16, height: 16)
                    .position(x: 54 + CGFloat(col) * 17, y: 20 + CGFloat(row) * 17)
            }
        }
        .frame(width: 210, height: 140)
        .onAppear { cycleGrowth() }
    }

    private func cycleGrowth() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.35)) {
                radius = (radius + 1) % 7
            }
            cycleGrowth()
        }
    }
}

// Level 85 — coverage regions around shelters.
struct CoverageConceptVisual: View {
    @State private var pulse = false
    private let shelters = [CGPoint(x: 70, y: 62), CGPoint(x: 136, y: 78)]
    private let points = [CGPoint(x: 42, y: 40), CGPoint(x: 90, y: 30), CGPoint(x: 114, y: 48), CGPoint(x: 162, y: 48), CGPoint(x: 50, y: 108), CGPoint(x: 100, y: 102), CGPoint(x: 168, y: 110)]

    var body: some View {
        ZStack {
            ForEach(shelters.indices, id: \.self) { i in
                Circle()
                    .stroke(Color.mathGold.opacity(pulse ? 0.52 : 0.22), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(width: pulse ? 82 : 70, height: pulse ? 82 : 70)
                    .position(shelters[i])
                Circle()
                    .fill(Color.mathGold)
                    .frame(width: 13, height: 13)
                    .position(shelters[i])
            }
            ForEach(points.indices, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.8))
                    .frame(width: 7, height: 7)
                    .position(points[i])
            }
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// Level 86 — local control vectors producing group motion.
struct HerdingConceptVisual: View {
    @State private var gathered = false
    private let starts = [CGPoint(x: 40, y: 30), CGPoint(x: 72, y: 106), CGPoint(x: 122, y: 28), CGPoint(x: 168, y: 94), CGPoint(x: 50, y: 82), CGPoint(x: 146, y: 56)]
    private let ends = [CGPoint(x: 88, y: 64), CGPoint(x: 98, y: 82), CGPoint(x: 111, y: 62), CGPoint(x: 122, y: 84), CGPoint(x: 92, y: 76), CGPoint(x: 116, y: 72)]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.mathGold.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 76, height: 76)
                .position(x: 105, y: 72)
            ForEach(starts.indices, id: \.self) { i in
                let p = gathered ? ends[i] : starts[i]
                Path { path in
                    path.move(to: p)
                    path.addLine(to: CGPoint(x: 105, y: 72))
                }
                .stroke(.white.opacity(0.12), lineWidth: 1)
                Circle()
                    .fill(Color.mathGold.opacity(0.88))
                    .frame(width: 12, height: 12)
                    .position(p)
            }
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .position(x: gathered ? 156 : 34, y: gathered ? 102 : 116)
        }
        .frame(width: 210, height: 140)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: gathered)
        .onAppear { gathered = true }
    }
}

// Level 87 — pheromone reinforcement making the shorter route dominant.
struct AntTrailConceptVisual: View {
    @State private var strong = false

    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 15, height: 15).position(x: 34, y: 72)
            Circle().fill(Color.mathGold).frame(width: 15, height: 15).position(x: 178, y: 72)
            trail(yOffset: -30, control: -46, opacity: strong ? 0.25 : 0.75)
            trail(yOffset: 18, control: 22, opacity: strong ? 0.95 : 0.38)
            ForEach(0..<6, id: \.self) { i in
                let x = 54 + CGFloat(i) * 22
                Circle()
                    .fill(Color.mathGold.opacity(strong ? 0.9 : 0.35))
                    .frame(width: 5, height: 5)
                    .position(x: x, y: 88 + CGFloat(sin(Double(i))) * 5)
            }
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                strong = true
            }
        }
    }

    private func trail(yOffset: CGFloat, control: CGFloat, opacity: Double) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 34, y: 72))
            p.addCurve(to: CGPoint(x: 178, y: 72), control1: CGPoint(x: 78, y: 72 + yOffset + control), control2: CGPoint(x: 132, y: 72 + yOffset - control))
        }
        .stroke(Color.mathGold.opacity(opacity), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }
}

// Level 88 — predator and prey cycling around a phase-plane orbit.
struct PopulationConceptVisual: View {
    @State private var rotate = false

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(Color.mathGold.opacity(0.45), lineWidth: 2)
                .frame(width: 120, height: 74)
                .rotationEffect(.degrees(-18))
                .position(x: 108, y: 74)
            Path { p in
                p.move(to: CGPoint(x: 44, y: 114))
                p.addLine(to: CGPoint(x: 44, y: 22))
                p.move(to: CGPoint(x: 36, y: 106))
                p.addLine(to: CGPoint(x: 176, y: 106))
            }
            .stroke(.white.opacity(0.25), lineWidth: 1.4)
            Group {
                Circle().fill(Color.mathGold).frame(width: 13, height: 13).offset(x: 48, y: 0)
                Circle().fill(.white).frame(width: 10, height: 10).offset(x: -48, y: 0)
            }
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .position(x: 108, y: 74)
            Text("prey")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.mathGold.opacity(0.8))
                .position(x: 170, y: 119)
            Text("pred")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .position(x: 64, y: 24)
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                rotate = true
            }
        }
    }
}

// Level 89 — nodal lines of a vibrating plate.
struct ChladniConceptVisual: View {
    @State private var shimmer = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(0.35), lineWidth: 2)
                .frame(width: 120, height: 100)
                .position(x: 105, y: 70)
            nodeCurve(offset: -22, flip: false)
            nodeCurve(offset: 22, flip: true)
            Path { p in
                p.move(to: CGPoint(x: 105, y: 22))
                p.addCurve(to: CGPoint(x: 105, y: 118), control1: CGPoint(x: 78, y: 46), control2: CGPoint(x: 132, y: 94))
                p.move(to: CGPoint(x: 45, y: 70))
                p.addCurve(to: CGPoint(x: 165, y: 70), control1: CGPoint(x: 76, y: 44), control2: CGPoint(x: 134, y: 96))
            }
            .stroke(Color.mathGold.opacity(shimmer ? 0.9 : 0.48), lineWidth: 2.2)
            ForEach(0..<18, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(shimmer ? 0.75 : 0.35))
                    .frame(width: 3, height: 3)
                    .position(x: 54 + CGFloat((i * 29) % 104), y: 30 + CGFloat((i * 47) % 82))
            }
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }

    private func nodeCurve(offset: CGFloat, flip: Bool) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 48, y: 70 + offset))
            p.addCurve(to: CGPoint(x: 162, y: 70 - offset), control1: CGPoint(x: 78, y: flip ? 112 : 28), control2: CGPoint(x: 132, y: flip ? 28 : 112))
        }
        .stroke(.white.opacity(0.18), lineWidth: 1.2)
    }
}

// Level 90 — a Hamiltonian path through the knight-move graph.
struct KnightConceptVisual: View {
    @State private var tourStep = 0
    private let path = [0, 7, 14, 23, 16, 9, 2, 5, 12, 19, 22, 15]

    var body: some View {
        ZStack {
            ForEach(0..<25, id: \.self) { i in
                let row = i / 5
                let col = i % 5
                Rectangle()
                    .fill((row + col).isMultiple(of: 2) ? .white.opacity(0.08) : .white.opacity(0.16))
                    .frame(width: 20, height: 20)
                    .position(square(i))
            }
            Path { p in
                for (index, squareIndex) in path.prefix(tourStep + 1).enumerated() {
                    if index == 0 {
                        p.move(to: square(squareIndex))
                    } else {
                        p.addLine(to: square(squareIndex))
                    }
                }
            }
            .stroke(Color.mathGold.opacity(0.95), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .shadow(color: Color.mathGold.opacity(0.35), radius: 7)
            ForEach(path.indices, id: \.self) { i in
                Circle()
                    .fill(i == 0 ? .white : Color.mathGold.opacity(i <= tourStep ? 0.92 : 0.18))
                    .frame(width: i == tourStep ? 11 : (i == 0 ? 10 : 7), height: i == tourStep ? 11 : (i == 0 ? 10 : 7))
                    .position(square(path[i]))
            }
            Text("L")
                .font(.system(size: 18, weight: .black, design: .serif))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Color.mathGold)
                .rotationEffect(.degrees(-18))
                .shadow(color: Color.mathGold.opacity(0.55), radius: 8)
                .position(square(path[tourStep]))
        }
        .frame(width: 210, height: 140)
        .animation(.easeInOut(duration: 0.35), value: tourStep)
        .onAppear { cycleTour() }
    }

    private func square(_ i: Int) -> CGPoint {
        let row = i / 5
        let col = i % 5
        return CGPoint(x: 64 + CGFloat(col) * 20, y: 30 + CGFloat(row) * 20)
    }

    private func cycleTour() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.easeInOut(duration: 0.32)) {
                tourStep = (tourStep + 1) % path.count
            }
            cycleTour()
        }
    }
}

// Level 91 — Dijkstra relaxation on a weighted graph.
struct DijkstraConceptVisual: View {
    @State private var step = 0
    private let nodes = [
        CGPoint(x: 34, y: 72), CGPoint(x: 72, y: 34), CGPoint(x: 84, y: 108),
        CGPoint(x: 126, y: 46), CGPoint(x: 142, y: 100), CGPoint(x: 178, y: 70)
    ]
    private let edges: [(Int, Int, String)] = [(0, 1, "2"), (0, 2, "5"), (1, 3, "3"), (2, 4, "2"), (3, 5, "4"), (4, 5, "1"), (1, 4, "6")]
    private let bestEdges = [0, 2, 4]

    var body: some View {
        ZStack {
            ForEach(edges.indices, id: \.self) { i in
                let edge = edges[i]
                let active = bestEdges.prefix(step + 1).contains(i)
                Path { p in
                    p.move(to: nodes[edge.0])
                    p.addLine(to: nodes[edge.1])
                }
                .stroke(active ? Color.mathGold : .white.opacity(0.22), lineWidth: active ? 2.8 : 1.2)
                Text(edge.2)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(active ? Color.mathGold : .white.opacity(0.45))
                    .position(mid(nodes[edge.0], nodes[edge.1]))
            }
            ForEach(nodes.indices, id: \.self) { i in
                Circle()
                    .fill(i <= step + 1 ? Color.mathGold.opacity(0.9) : .black)
                    .overlay { Circle().stroke(.white.opacity(0.75), lineWidth: 1.3) }
                    .frame(width: i == 0 || i == 5 ? 16 : 12, height: i == 0 || i == 5 ? 16 : 12)
                    .position(nodes[i])
            }
        }
        .frame(width: 210, height: 140)
        .onAppear { cycleStep(max: 3) }
    }

    private func cycleStep(max: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 0.35)) { step = (step + 1) % max }
            cycleStep(max: max)
        }
    }

    private func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

// Level 92 — bitonic compare-exchange layers.
struct BitonicConceptVisual: View {
    @State private var phase = false
    private let values: [CGFloat] = [28, 56, 38, 76, 88, 64, 46, 34]

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let x1 = 38 + CGFloat(i) * 38
                let x2 = 58 + CGFloat(i) * 38
                Path { p in
                    p.move(to: CGPoint(x: x1, y: 22))
                    p.addLine(to: CGPoint(x: x2, y: 118))
                    p.move(to: CGPoint(x: x2, y: 22))
                    p.addLine(to: CGPoint(x: x1, y: 118))
                }
                .stroke(Color.mathGold.opacity(phase ? 0.75 : 0.25), lineWidth: 1.4)
            }
            HStack(spacing: 7) {
                ForEach(values.indices, id: \.self) { i in
                    let sorted = values.sorted()[i]
                    let h = phase ? sorted : values[i]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.mathGold.opacity(0.85))
                        .frame(width: 13, height: h)
                }
            }
            .frame(width: 180, height: 108, alignment: .bottom)
            .position(x: 105, y: 78)
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

// Level 93 — winning lines as hyperedges in a 3D board.
struct CubeGameConceptVisual: View {
    @State private var glow = false
    private let front = CGPoint(x: 72, y: 84)
    private let back = CGPoint(x: 110, y: 46)

    var body: some View {
        ZStack {
            cube(offset: back, opacity: 0.18)
            cube(offset: front, opacity: 0.42)
            Path { p in
                p.move(to: CGPoint(x: front.x - 32, y: front.y - 32))
                p.addLine(to: CGPoint(x: back.x - 32, y: back.y - 32))
                p.move(to: CGPoint(x: front.x + 32, y: front.y - 32))
                p.addLine(to: CGPoint(x: back.x + 32, y: back.y - 32))
                p.move(to: CGPoint(x: front.x - 32, y: front.y + 32))
                p.addLine(to: CGPoint(x: back.x - 32, y: back.y + 32))
                p.move(to: CGPoint(x: front.x + 32, y: front.y + 32))
                p.addLine(to: CGPoint(x: back.x + 32, y: back.y + 32))
                p.move(to: CGPoint(x: front.x - 32, y: front.y + 32))
                p.addLine(to: CGPoint(x: back.x + 32, y: back.y - 32))
            }
            .stroke(Color.mathGold.opacity(glow ? 0.95 : 0.35), lineWidth: 2.2)
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.mathGold)
                    .frame(width: 9, height: 9)
                    .position(x: front.x - 32 + CGFloat(i) * 32, y: front.y + 32 - CGFloat(i) * 32)
            }
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private func cube(offset: CGPoint, opacity: Double) -> some View {
        Path { p in
            p.addRect(CGRect(x: offset.x - 32, y: offset.y - 32, width: 64, height: 64))
            p.move(to: CGPoint(x: offset.x - 32, y: offset.y))
            p.addLine(to: CGPoint(x: offset.x + 32, y: offset.y))
            p.move(to: CGPoint(x: offset.x, y: offset.y - 32))
            p.addLine(to: CGPoint(x: offset.x, y: offset.y + 32))
        }
        .stroke(.white.opacity(opacity), lineWidth: 1.3)
    }
}

// Level 94 - the anatomy and side relationship of a 3-4-5 right triangle.
struct PinballMemoryConceptVisual: View {
    private let legA = Color(red: 0.30, green: 0.76, blue: 1.0)
    private let legB = Color(red: 0.38, green: 0.90, blue: 0.57)
    private let hypotenuse = Color.mathGold

    var body: some View {
        Canvas { context, _ in
            let rightAngle = CGPoint(x: 43, y: 105)
            let top = CGPoint(x: 43, y: 30)
            let far = CGPoint(x: 143, y: 105)

            var fill = Path()
            fill.move(to: rightAngle)
            fill.addLine(to: top)
            fill.addLine(to: far)
            fill.closeSubpath()
            context.fill(fill, with: .color(.white.opacity(0.055)))

            func line(_ start: CGPoint, _ end: CGPoint, color: Color, width: CGFloat) {
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            line(rightAngle, far, color: legA, width: 4)
            line(rightAngle, top, color: legB, width: 4)
            line(top, far, color: hypotenuse, width: 4)

            var square = Path()
            square.move(to: CGPoint(x: rightAngle.x, y: rightAngle.y - 14))
            square.addLine(to: CGPoint(x: rightAngle.x + 14, y: rightAngle.y - 14))
            square.addLine(to: CGPoint(x: rightAngle.x + 14, y: rightAngle.y))
            context.stroke(square, with: .color(hypotenuse), lineWidth: 2)

            context.draw(
                Text("90°")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(hypotenuse),
                at: CGPoint(x: 66, y: 87)
            )
            context.draw(
                Text("b = 3")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(legB),
                at: CGPoint(x: 26, y: 67)
            )
            context.draw(
                Text("a = 4")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(legA),
                at: CGPoint(x: 93, y: 116)
            )
            context.draw(
                Text("c = 5")
                    .font(.system(size: 8.2, weight: .bold, design: .monospaced))
                    .foregroundColor(hypotenuse),
                at: CGPoint(x: 108, y: 48)
            )

            for point in [rightAngle, top, far] {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)),
                    with: .color(.white)
                )
            }

            context.draw(
                Text("3² + 4² = 5²")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.82)),
                at: CGPoint(x: 105, y: 132)
            )
        }
        .frame(width: 210, height: 140)
    }
}

// Level 95 — coupled pendulum instability near an upright equilibrium.
struct DoublePendulumConceptVisual: View {
    @State private var swing = false

    var body: some View {
        let pivot = CGPoint(x: 105, y: 28)
        let a1 = swing ? -16.0 : 12.0
        let a2 = swing ? 26.0 : -18.0
        let mid = point(from: pivot, angle: a1, length: 42)
        let end = point(from: mid, angle: a1 + a2, length: 40)

        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 28, y: 94))
                p.addLine(to: CGPoint(x: 182, y: 94))
            }
            .stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            rod(from: pivot, to: mid)
            rod(from: mid, to: end)
            Circle().fill(.white).frame(width: 10, height: 10).position(pivot)
            Circle().fill(Color.mathGold).frame(width: 16, height: 16).position(mid)
            Circle().fill(Color.mathGold.opacity(0.85)).frame(width: 18, height: 18).position(end)
        }
        .frame(width: 210, height: 140)
        .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: swing)
        .onAppear { swing = true }
    }

    private func point(from p: CGPoint, angle: Double, length: CGFloat) -> CGPoint {
        let r = (angle - 90) * Double.pi / 180
        return CGPoint(x: p.x + CGFloat(cos(r)) * length, y: p.y + CGFloat(sin(r)) * length)
    }

    private func rod(from a: CGPoint, to b: CGPoint) -> some View {
        Path { p in
            p.move(to: a)
            p.addLine(to: b)
        }
        .stroke(Color.mathGold.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
}

// Level 96 — exact cover rectangles partitioning a grid.
struct ExactCoverConceptVisual: View {
    @State private var fill = false
    private let rects: [(CGRect, Color)] = [
        (CGRect(x: 48, y: 24, width: 44, height: 44), Color.mathGold),
        (CGRect(x: 92, y: 24, width: 66, height: 22), .white),
        (CGRect(x: 92, y: 46, width: 22, height: 66), Color.mathGold),
        (CGRect(x: 114, y: 46, width: 44, height: 44), .white),
        (CGRect(x: 48, y: 68, width: 44, height: 44), .white),
        (CGRect(x: 114, y: 90, width: 44, height: 22), Color.mathGold)
    ]

    var body: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { i in
                let row = i / 6
                let col = i % 6
                Rectangle()
                    .stroke(.white.opacity(0.16), lineWidth: 1)
                    .frame(width: 22, height: 22)
                    .position(x: 59 + CGFloat(col) * 22, y: 35 + CGFloat(row) * 22)
            }
            ForEach(rects.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(rects[i].1.opacity(fill ? 0.42 : 0.14))
                    .overlay { RoundedRectangle(cornerRadius: 3).stroke(rects[i].1.opacity(0.75), lineWidth: 1.7) }
                    .frame(width: rects[i].0.width, height: rects[i].0.height)
                    .position(x: rects[i].0.midX, y: rects[i].0.midY)
            }
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                fill = true
            }
        }
    }
}

// Level 97 — convex hull as the outer envelope of a point set.
struct ConvexHullConceptVisual: View {
    @State private var glow = false
    private let points = [
        CGPoint(x: 42, y: 84), CGPoint(x: 62, y: 38), CGPoint(x: 88, y: 66), CGPoint(x: 104, y: 28),
        CGPoint(x: 126, y: 78), CGPoint(x: 154, y: 42), CGPoint(x: 174, y: 100), CGPoint(x: 92, y: 112), CGPoint(x: 58, y: 106)
    ]
    private let hull = [CGPoint(x: 42, y: 84), CGPoint(x: 62, y: 38), CGPoint(x: 104, y: 28), CGPoint(x: 154, y: 42), CGPoint(x: 174, y: 100), CGPoint(x: 92, y: 112), CGPoint(x: 58, y: 106)]

    var body: some View {
        ZStack {
            Path { p in
                for (i, point) in hull.enumerated() {
                    if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
                }
                p.closeSubpath()
            }
            .fill(Color.mathGold.opacity(0.08))
            Path { p in
                for (i, point) in hull.enumerated() {
                    if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
                }
                p.closeSubpath()
            }
            .stroke(Color.mathGold.opacity(glow ? 0.95 : 0.5), lineWidth: 2.4)
            ForEach(points.indices, id: \.self) { i in
                Circle()
                    .fill(hull.contains(points[i]) ? Color.mathGold : .white.opacity(0.75))
                    .frame(width: hull.contains(points[i]) ? 8 : 6, height: hull.contains(points[i]) ? 8 : 6)
                    .position(points[i])
            }
        }
        .frame(width: 210, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// Level 98 — Josephus elimination as modular recurrence around a circle.
struct JosephusConceptVisual: View {
    @State private var step = 0
    private let n = 9

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 1)
                .frame(width: 102, height: 102)
                .position(x: 105, y: 70)
            ForEach(0..<n, id: \.self) { i in
                let removed = i < step
                Circle()
                    .fill(removed ? .white.opacity(0.12) : (i == n - 1 ? Color.mathGold : .white.opacity(0.8)))
                    .frame(width: removed ? 7 : 12, height: removed ? 7 : 12)
                    .position(point(i))
                if removed {
                    Path { p in
                        let c = point(i)
                        p.move(to: CGPoint(x: c.x - 5, y: c.y - 5))
                        p.addLine(to: CGPoint(x: c.x + 5, y: c.y + 5))
                        p.move(to: CGPoint(x: c.x + 5, y: c.y - 5))
                        p.addLine(to: CGPoint(x: c.x - 5, y: c.y + 5))
                    }
                    .stroke(.white.opacity(0.35), lineWidth: 1.1)
                }
            }
            Text("mod")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.mathGold)
                .position(x: 105, y: 70)
        }
        .frame(width: 210, height: 140)
        .onAppear { cycleStep(max: n - 1) }
    }

    private func cycleStep(max: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.22)) { step = (step + 1) % max }
            cycleStep(max: max)
        }
    }

    private func point(_ i: Int) -> CGPoint {
        let a = Double(i) / Double(n) * 2 * Double.pi - Double.pi / 2
        return CGPoint(x: 105 + CGFloat(cos(a)) * 51, y: 70 + CGFloat(sin(a)) * 51)
    }
}

// Level 100 — local density feedback forming clusters.
struct SelfOrganizingConceptVisual: View {
    @State private var clustered = false
    private let loose = [CGPoint(x: 38, y: 34), CGPoint(x: 78, y: 56), CGPoint(x: 132, y: 28), CGPoint(x: 166, y: 68), CGPoint(x: 52, y: 104), CGPoint(x: 104, y: 116), CGPoint(x: 154, y: 108), CGPoint(x: 112, y: 72)]
    private let dense = [CGPoint(x: 70, y: 70), CGPoint(x: 78, y: 76), CGPoint(x: 68, y: 82), CGPoint(x: 134, y: 64), CGPoint(x: 144, y: 70), CGPoint(x: 138, y: 80), CGPoint(x: 98, y: 104), CGPoint(x: 106, y: 96)]

    var body: some View {
        ZStack {
            ForEach(loose.indices, id: \.self) { i in
                let p = clustered ? dense[i] : loose[i]
                Circle()
                    .fill(i.isMultiple(of: 2) ? Color.mathGold.opacity(0.9) : .white.opacity(0.8))
                    .frame(width: 10, height: 10)
                    .position(p)
            }
            ForEach([CGPoint(x: 73, y: 76), CGPoint(x: 139, y: 72)].indices, id: \.self) { i in
                let centers = [CGPoint(x: 73, y: 76), CGPoint(x: 139, y: 72)]
                Circle()
                    .stroke(Color.mathGold.opacity(clustered ? 0.5 : 0.08), style: StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
                    .frame(width: 46, height: 46)
                    .position(centers[i])
            }
        }
        .frame(width: 210, height: 140)
        .animation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true), value: clustered)
        .onAppear { clustered = true }
    }
}

struct SnowboardRateConceptVisual: View {
    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 20, y: 16, width: size.width - 36, height: size.height - 32)
            func point(_ t: Double, _ h: Double) -> CGPoint {
                CGPoint(x: plot.minX + CGFloat(t / 6) * plot.width, y: plot.maxY - CGFloat(h / 66) * plot.height)
            }

            var axes = Path()
            axes.move(to: CGPoint(x: plot.minX, y: plot.minY))
            axes.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
            axes.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            context.stroke(axes, with: .color(.white.opacity(0.35)), lineWidth: 1)

            var curve = Path()
            for sample in 0...100 {
                let t = Double(sample) / 100 * 6
                let h = max(0, 60 - (20.0 / 3.0) * pow(t - 3, 2))
                let p = point(t, h)
                sample == 0 ? curve.move(to: p) : curve.addLine(to: p)
            }
            context.stroke(curve, with: .color(.white.opacity(0.88)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            let vertex = point(3, 60)
            var tangent = Path()
            tangent.move(to: CGPoint(x: vertex.x - 27, y: vertex.y))
            tangent.addLine(to: CGPoint(x: vertex.x + 27, y: vertex.y))
            context.stroke(tangent, with: .color(Color.mathGold), lineWidth: 2)
            context.fill(Path(ellipseIn: CGRect(x: vertex.x - 4, y: vertex.y - 4, width: 8, height: 8)), with: .color(Color.mathGold))

            var rider = Path()
            rider.move(to: CGPoint(x: vertex.x, y: vertex.y - 8))
            rider.addLine(to: CGPoint(x: vertex.x, y: vertex.y - 20))
            rider.move(to: CGPoint(x: vertex.x, y: vertex.y - 9))
            rider.addLine(to: CGPoint(x: vertex.x - 7, y: vertex.y - 2))
            rider.move(to: CGPoint(x: vertex.x, y: vertex.y - 9))
            rider.addLine(to: CGPoint(x: vertex.x + 7, y: vertex.y - 2))
            context.stroke(rider, with: .color(Color(red: 1.0, green: 0.31, blue: 0.27)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: vertex.x - 4, y: vertex.y - 27, width: 8, height: 8)), with: .color(.white))
            context.stroke(
                Path(roundedRect: CGRect(x: vertex.x - 12, y: vertex.y - 2, width: 24, height: 3), cornerRadius: 1.5),
                with: .color(Color.mathGold),
                lineWidth: 2
            )
            context.draw(Text("h′ = 0").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(Color.mathGold), at: CGPoint(x: vertex.x, y: vertex.y - 37))
        }
        .frame(width: 210, height: 140)
    }
}

// Derivatives visualized through flocking acceleration.
struct FlockingConceptVisual: View {
    @State private var flow = false
    private let starts = [CGPoint(x: 44, y: 42), CGPoint(x: 72, y: 72), CGPoint(x: 52, y: 104), CGPoint(x: 112, y: 38), CGPoint(x: 134, y: 78), CGPoint(x: 102, y: 104), CGPoint(x: 164, y: 58), CGPoint(x: 158, y: 108)]
    private let ends = [CGPoint(x: 62, y: 50), CGPoint(x: 92, y: 68), CGPoint(x: 78, y: 92), CGPoint(x: 128, y: 48), CGPoint(x: 146, y: 72), CGPoint(x: 124, y: 96), CGPoint(x: 170, y: 64), CGPoint(x: 168, y: 96)]

    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 32, y: 112))
                p.addCurve(to: CGPoint(x: 184, y: 34), control1: CGPoint(x: 80, y: 58), control2: CGPoint(x: 130, y: 110))
            }
            .stroke(Color.mathGold.opacity(0.18), lineWidth: 10)
            ForEach(starts.indices, id: \.self) { i in
                let p = flow ? ends[i] : starts[i]
                boid(at: p, angle: flow ? -18 : CGFloat(-36 + i * 9), color: i.isMultiple(of: 3) ? Color.mathGold : .white.opacity(0.8))
            }
        }
        .frame(width: 210, height: 140)
        .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true), value: flow)
        .onAppear { flow = true }
    }

    private func boid(at p: CGPoint, angle: CGFloat, color: Color) -> some View {
        TriangleBoid()
            .fill(color)
            .frame(width: 14, height: 18)
            .rotationEffect(.degrees(Double(angle)))
            .position(p)
    }
}

private struct TriangleBoid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Level 101 — the number system as a tilted solar system: a gold 0-sun with
// orbiting rings of number types (naturals, negatives, rationals).
struct NumberSystemConceptVisual: View {
    private let c = CGPoint(x: 105, y: 70)
    private let colors: [Color] = [
        Color(red: 0.52, green: 0.74, blue: 1.0),   // naturals
        Color(red: 0.42, green: 0.86, blue: 0.80),  // negatives
        Color(red: 0.88, green: 0.74, blue: 0.50),  // rationals
    ]

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                // Tilted orbit rings.
                ForEach(0..<3, id: \.self) { k in
                    let rr = 20.0 + Double(k) * 15.0
                    Ellipse()
                        .stroke(Color.mathGold.opacity(0.28), lineWidth: 1)
                        .frame(width: rr * 2, height: rr * 2 * 0.5)
                        .position(c)
                }

                // Orbiting number-planets — inner rings turn faster.
                ForEach(0..<3, id: \.self) { k in
                    let rr = 20.0 + Double(k) * 15.0
                    let speed = 1.3 - Double(k) * 0.4
                    ForEach(0..<4, id: \.self) { i in
                        let a = t * speed + Double(i) * (.pi / 2) + Double(k)
                        let x = c.x + CGFloat(cos(a)) * CGFloat(rr)
                        let y = c.y + CGFloat(sin(a)) * CGFloat(rr) * 0.5
                        Circle()
                            .fill(colors[k])
                            .frame(width: 7, height: 7)
                            .position(x: x, y: y)
                    }
                }

                // A complex-number comet streaking across.
                let cp = (t * 0.5).truncatingRemainder(dividingBy: 1.0)
                Circle()
                    .fill(Color(red: 0.62, green: 0.86, blue: 1.0))
                    .frame(width: 5, height: 5)
                    .shadow(color: Color(red: 0.62, green: 0.86, blue: 1.0).opacity(0.9), radius: 4)
                    .position(x: 16 + CGFloat(cp) * 178, y: 22 + CGFloat(cp) * 14)

                // The gold 0-sun.
                Circle()
                    .fill(Color.mathGold)
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.mathGold.opacity(0.85), radius: 7)
                    .position(c)
                Text("0")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .position(c)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 102 — a stone of seeds sowing counter-clockwise around a loop of cups.
struct MancalaConceptVisual: View {
    private let n = 10

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let active = Int(t * 2.6) % n
            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    let ang = Double(i) / Double(n) * 2 * .pi - .pi / 2
                    let x = 105 + cos(ang) * 80
                    let y = 70 + sin(ang) * 46
                    let isActive = i == active
                    Circle()
                        .fill(Color.mathGold.opacity(isActive ? 0.9 : 0.16))
                        .frame(width: isActive ? 17 : 12, height: isActive ? 17 : 12)
                        .overlay(Circle().stroke(Color.mathGold.opacity(0.5), lineWidth: 1))
                        .position(x: x, y: y)
                }
                Text("mod 13")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.mathGold.opacity(0.7))
                    .position(x: 105, y: 70)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 95 — a mass on a rotating arm that pulls in and extends: it whips around
// faster when the arm is short (L = Iω held constant).
struct AngularMomentumConceptVisual: View {
    private let c = CGPoint(x: 105, y: 70)
    private let bob = Color(red: 0.62, green: 0.82, blue: 1.0)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let ph = 1.2 * t
            let r = 34.0 + 18.0 * sin(ph)                 // arm length in/out
            let ang = 3.2 * t + 2.4 * cos(ph)             // spins faster when arm is short
            let p = CGPoint(x: c.x + CGFloat(cos(ang) * r), y: c.y + CGFloat(sin(ang) * r))
            ZStack {
                Path { pt in pt.move(to: c); pt.addLine(to: p) }
                    .stroke(Color.mathGold.opacity(0.5), lineWidth: 2)
                Circle().fill(Color.mathGold).frame(width: 7, height: 7).position(c)
                Circle().fill(bob).frame(width: 16, height: 16)
                    .shadow(color: bob.opacity(0.7), radius: 5).position(p)
                Text("L = Iω")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.mathGold.opacity(0.8))
                    .position(x: 105, y: 128)
            }
            .frame(width: 210, height: 140)
        }
    }
}

// Level 103 — mathematical parts assemble into a grouped expression.
struct ExpressionBuilderConceptVisual: View {
    private let symbols = ["(", "x", "+", "2", ")", "×2"]
    private let sources = [
        CGPoint(x: 24, y: 24), CGPoint(x: 67, y: 112),
        CGPoint(x: 106, y: 24), CGPoint(x: 148, y: 112),
        CGPoint(x: 188, y: 27), CGPoint(x: 184, y: 105)
    ]
    private let targets = [
        CGPoint(x: 32, y: 64), CGPoint(x: 59, y: 64),
        CGPoint(x: 88, y: 64), CGPoint(x: 117, y: 64),
        CGPoint(x: 143, y: 64), CGPoint(x: 177, y: 64)
    ]

    var body: some View {
        TimelineView(.animation) { context in
            let cycle = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 5)
            let fadeIn = min(1, cycle / 0.25)
            let fadeOut = min(1, max(0, (5 - cycle) / 0.35))
            let opacity = fadeIn * fadeOut

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(cycle > 2.8 ? 0.045 : 0))
                    .frame(width: 184, height: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.mathGold.opacity(cycle > 2.8 ? 0.48 : 0), lineWidth: 1)
                    }
                    .position(x: 105, y: 64)

                ForEach(symbols.indices, id: \.self) { index in
                    let raw = min(1, max(0, (cycle - 0.35 - Double(index) * 0.32) / 0.55))
                    let progress = raw * raw * (3 - 2 * raw)
                    let positionProgress = CGFloat(progress)
                    let source = sources[index]
                    let target = targets[index]
                    let point = CGPoint(
                        x: source.x + (target.x - source.x) * positionProgress,
                        y: source.y + (target.y - source.y) * positionProgress
                    )
                    let color: Color = symbols[index] == "x"
                        ? Color(red: 0.48, green: 0.78, blue: 1)
                        : (symbols[index].contains("2") ? Color.mathGold : Color.white)

                    Text(symbols[index])
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .frame(width: index == 5 ? 42 : 28, height: 36)
                        .background(Color.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(color.opacity(0.38), lineWidth: 1)
                        }
                        .shadow(color: color.opacity(progress * 0.35), radius: 6)
                        .position(point)
                }

                HStack(spacing: 12) {
                    legend("x", "variable", Color(red: 0.48, green: 0.78, blue: 1))
                    legend("2", "constant", .mathGold)
                    legend("+ ×", "operators", .white)
                }
                .position(x: 105, y: 126)
            }
            .frame(width: 210, height: 140)
            .opacity(opacity)
        }
    }

    private func legend(_ symbol: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(symbol)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }
}

// A value flowing through an assembly line of operations, retained for other
// operation-pipeline concepts.
// Level 8 — a pie riding a belt through the ×2 machine and coming out twice as
// big: an operator applied to a value (matching the Pie Kitchen level).
struct CookingConceptVisual: View {
    private let filling = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let crust   = Color(red: 0.72, green: 0.47, blue: 0.24)
    private let cherry  = Color(red: 0.86, green: 0.24, blue: 0.26)
    private let accent  = Color(red: 0.62, green: 0.45, blue: 0.98)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let cycle = (t * 0.42).truncatingRemainder(dividingBy: 1.0)
            let x = 20.0 + cycle * 170.0
            let big = x > 105                     // once past the machine → doubled
            let r: CGFloat = big ? 20 : 11
            let atMachine = abs(x - 105) < 22
            ZStack {
                // Belt.
                Path { p in p.move(to: CGPoint(x: 14, y: 84)); p.addLine(to: CGPoint(x: 196, y: 84)) }
                    .stroke(Color.white.opacity(0.14), lineWidth: 2)

                // The travelling pie (behind the machine, so it "enters" it).
                miniPie(r: r)
                    .frame(width: r * 2, height: r * 2)
                    .shadow(color: filling.opacity(0.45), radius: 5)
                    .position(x: CGFloat(x), y: 84)

                // The ×2 machine.
                RoundedRectangle(cornerRadius: 10)
                    .fill(atMachine ? accent : Color(red: 0.09, green: 0.09, blue: 0.12))
                    .frame(width: 46, height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.7), lineWidth: 1.5))
                    .overlay(Text("×2")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(atMachine ? .black : .white))
                    .position(x: 105, y: 84)

                Text("×2 → twice as big")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.75))
                    .position(x: 105, y: 126)
            }
            .frame(width: 210, height: 140)
        }
    }

    private func miniPie(r: CGFloat) -> some View {
        ZStack {
            Circle().fill(crust)
            Circle().fill(filling).padding(max(1, r * 0.16))
            Circle().fill(cherry).frame(width: r * 0.5, height: r * 0.5)
        }
    }
}

// Level 106 — a camera marker sliding along a powers-of-ten ruler, from the
// universe down to a quark, with the current scale label following it.
struct PowersOfTenConceptVisual: View {
    private let accent = Color(red: 0.42, green: 0.70, blue: 1.0)
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let stops = [26, 13, 0, -9, -18]

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let cycle = (t * 0.28).truncatingRemainder(dividingBy: 1.0)   // 0 → 1
            let exp = 26.0 - cycle * 44.0                                 // 26 → -18
            let w: CGFloat = 186
            let left: CGFloat = 12

            ZStack(alignment: .topLeading) {
                Capsule().fill(.white.opacity(0.16))
                    .frame(width: w, height: 3)
                    .offset(x: left, y: 70)

                ForEach(stops, id: \.self) { e in
                    VStack(spacing: 4) {
                        Rectangle().fill(.white.opacity(0.28)).frame(width: 1, height: 9)
                        Text("10\(superscriptText(e))")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                    .frame(width: 30)
                    .offset(x: rulerX(Double(e), left: left, w: w) - 15, y: 66)
                }

                // Sliding camera marker + live scale label.
                let mx = rulerX(exp, left: left, w: w)
                VStack(spacing: 5) {
                    Text("10\(superscriptText(Int(exp.rounded()))) m")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(gold)
                        .fixedSize()
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(accent)
                        .shadow(color: accent.opacity(0.7), radius: 6)
                }
                .frame(width: 70)
                .offset(x: mx - 35, y: 30)

                Circle().fill(accent).frame(width: 11, height: 11)
                    .shadow(color: accent.opacity(0.7), radius: 5)
                    .offset(x: mx - 5.5, y: 66)
            }
            .frame(width: 210, height: 118)
        }
    }

    private func rulerX(_ e: Double, left: CGFloat, w: CGFloat) -> CGFloat {
        left + w * CGFloat((26.0 - e) / 44.0)
    }

    private func superscriptText(_ n: Int) -> String {
        let map: [Character: Character] = [
            "-": "⁻", "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"
        ]
        return String(String(n).map { map[$0] ?? $0 })
    }
}

// Level 33 — a crane-style crease pattern with red mountain and blue valley
// folds, breathing as if mid-fold, with the Maekawa count beneath.
struct OrigamiFoldConceptVisual: View {
    private let mountain = Color(red: 0.95, green: 0.42, blue: 0.34)
    private let valley = Color(red: 0.36, green: 0.72, blue: 0.92)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let breathe = 0.92 + 0.08 * sin(t * 1.6)
            VStack(spacing: 10) {
                Canvas { canvas, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = min(size.width, size.height) / 2 - 4
                    // Paper square (diamond).
                    var square = Path()
                    square.move(to: CGPoint(x: c.x, y: c.y - r))
                    square.addLine(to: CGPoint(x: c.x + r, y: c.y))
                    square.addLine(to: CGPoint(x: c.x, y: c.y + r))
                    square.addLine(to: CGPoint(x: c.x - r, y: c.y))
                    square.closeSubpath()
                    canvas.fill(square, with: .color(Color(red: 0.96, green: 0.95, blue: 0.92).opacity(0.9)))
                    // 8 creases: 5 mountains, 3 valleys (M − V = 2).
                    for i in 0..<8 {
                        let a = CGFloat(i) * .pi / 4 + .pi / 8
                        let isM = i != 1 && i != 4 && i != 6
                        var p = Path()
                        p.move(to: c)
                        p.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.9, y: c.y + sin(a) * r * 0.9))
                        canvas.stroke(p, with: .color(isM ? mountain : valley),
                                      style: StrokeStyle(lineWidth: 1.8, dash: isM ? [] : [4, 3]))
                    }
                }
                .frame(width: 120, height: 120)
                .scaleEffect(y: CGFloat(breathe))

                Text("M 5 − V 3 = 2 ✓")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.74, blue: 0.30))
            }
            .frame(width: 210, height: 158)
        }
    }
}

// Level 113 - an animated unit-circle defense preview with standard angle rays.
struct TrigRatioConceptVisual: View {
    private let sineColor = Color(red: 0.38, green: 0.90, blue: 0.57)
    private let cosineColor = Color(red: 0.27, green: 0.76, blue: 1.00)
    private let danger = Color(red: 1.00, green: 0.28, blue: 0.34)
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)

    private let angles: [(degrees: Int, radians: String)] = [
        (0, "0"), (30, "π/6"), (45, "π/4"), (60, "π/3"),
        (90, "π/2"), (120, "2π/3"), (135, "3π/4"), (150, "5π/6"),
        (180, "π"), (210, "7π/6"), (225, "5π/4"), (240, "4π/3"),
        (270, "3π/2"), (300, "5π/3"), (315, "7π/4"), (330, "11π/6")
    ]

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let approach = CGFloat(t.truncatingRemainder(dividingBy: 3.2) / 3.2)
            let selectedDegrees = 45.0

            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: 69)
                let radius: CGFloat = 49
                let theta = selectedDegrees * Double.pi / 180
                let circlePoint = CGPoint(
                    x: center.x + radius * CGFloat(cos(theta)),
                    y: center.y - radius * CGFloat(sin(theta))
                )
                let projection = CGPoint(x: circlePoint.x, y: center.y)

                func line(_ start: CGPoint, _ end: CGPoint, color: Color, width: CGFloat = 2.5) {
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    canvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }

                var triangle = Path()
                triangle.move(to: center)
                triangle.addLine(to: projection)
                triangle.addLine(to: circlePoint)
                triangle.closeSubpath()
                canvas.fill(triangle, with: .color(gold.opacity(0.10)))

                for angle in angles {
                    let radians = Double(angle.degrees) * .pi / 180
                    let end = CGPoint(
                        x: center.x + radius * CGFloat(cos(radians)),
                        y: center.y - radius * CGFloat(sin(radians))
                    )
                    line(
                        center,
                        end,
                        color: angle.degrees == Int(selectedDegrees) ? gold : .white.opacity(0.16),
                        width: angle.degrees == Int(selectedDegrees) ? 2.8 : 0.7
                    )
                }

                line(CGPoint(x: center.x - radius - 10, y: center.y), CGPoint(x: center.x + radius + 10, y: center.y), color: .white.opacity(0.48), width: 1)
                line(CGPoint(x: center.x, y: center.y - radius - 10), CGPoint(x: center.x, y: center.y + radius + 10), color: .white.opacity(0.48), width: 1)

                let circle = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                canvas.stroke(circle, with: .color(.white.opacity(0.82)), lineWidth: 1.8)

                line(center, projection, color: cosineColor, width: 3)
                line(projection, circlePoint, color: sineColor, width: 3)
                line(center, circlePoint, color: gold, width: 3)

                var arc = Path()
                arc.addArc(center: center, radius: 17, startAngle: .degrees(0), endAngle: .degrees(-selectedDegrees), clockwise: true)
                canvas.stroke(arc, with: .color(gold), lineWidth: 1.5)
                canvas.draw(
                    Text("45°")
                        .font(.system(size: 8, weight: .black, design: .serif))
                        .foregroundColor(gold),
                    at: CGPoint(x: center.x + 27, y: center.y - 17)
                )
                canvas.draw(
                    Text("π/4")
                        .font(.system(size: 7.5, weight: .black, design: .serif))
                        .foregroundColor(gold),
                    at: CGPoint(x: center.x + 27, y: center.y - 9)
                )

                for angle in angles where angle.degrees.isMultiple(of: 45) {
                    let radians = Double(angle.degrees) * .pi / 180
                    let labelPoint = CGPoint(
                        x: center.x + radius * 0.70 * CGFloat(cos(radians)),
                        y: center.y - radius * 0.70 * CGFloat(sin(radians))
                    )
                    canvas.draw(
                        Text("\(angle.degrees)°")
                            .font(.system(size: 6.5, weight: .semibold, design: .serif))
                            .foregroundColor(.white.opacity(0.65)),
                        at: labelPoint
                    )
                }

                let enemyAngle = selectedDegrees * Double.pi / 180
                let enemyDistance = 82 * (1 - 0.58 * approach)
                let enemy = CGPoint(
                    x: center.x + CGFloat(cos(enemyAngle)) * enemyDistance,
                    y: center.y - CGFloat(sin(enemyAngle)) * enemyDistance
                )
                let lockRing = Path(ellipseIn: CGRect(x: enemy.x - 16, y: enemy.y - 16, width: 32, height: 32))
                let target = Path(ellipseIn: CGRect(x: enemy.x - 12, y: enemy.y - 12, width: 24, height: 24))
                canvas.stroke(lockRing, with: .color(danger.opacity(0.72)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                canvas.fill(target, with: .color(Color(red: 0.16, green: 0.025, blue: 0.04)))
                canvas.stroke(target, with: .color(danger), lineWidth: 1.5)
                canvas.draw(
                    Text("+").font(.system(size: 13, weight: .black)).foregroundColor(.white),
                    at: enemy
                )
            }
            .frame(width: 210, height: 138)
            .overlay(alignment: .bottom) {
                Text("P(θ) = (cos θ, sin θ)")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }
}

// Level 112 — a stag silhouette breathing between two sizes inside a
// viewfinder, its dashed reference locking gold each time the zoom matches.
struct SimilarityConceptVisual: View {
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let accent = Color(red: 0.36, green: 0.86, blue: 1.0)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // Oscillate zoom 0.55 → 1.0; "matched" near the top of the swing.
            let s = 0.5 + 0.5 * sin(t * 1.2)
            let zoom = 0.55 + 0.45 * s
            let matched = zoom > 0.96

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.2), lineWidth: 1.2)
                    .frame(width: 190, height: 120)

                // Reference outline at full size.
                ConceptStagShape()
                    .stroke(matched ? gold : gold.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.4, dash: matched ? [] : [5, 4]))
                    .frame(width: 104, height: 88)
                    .shadow(color: matched ? gold.opacity(0.6) : .clear, radius: 8)

                // The zooming animal — same proportions at every size.
                ConceptStagShape()
                    .fill(.white.opacity(0.85))
                    .frame(width: 104, height: 88)
                    .scaleEffect(zoom)

                Text(matched ? "k = 1.00 ✓" : String(format: "×%.2f", zoom))
                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(matched ? gold : accent)
                    .offset(y: 48)
            }
            .frame(width: 210, height: 140)
        }
    }
}

private struct ConceptStagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var path = Path()
        path.move(to: pt(0.12, 0.55))
        path.addQuadCurve(to: pt(0.42, 0.44), control: pt(0.25, 0.42))
        path.addLine(to: pt(0.60, 0.46))
        path.addQuadCurve(to: pt(0.72, 0.30), control: pt(0.68, 0.38))
        path.addLine(to: pt(0.78, 0.26))
        path.addLine(to: pt(0.90, 0.28))
        path.addLine(to: pt(0.80, 0.36))
        path.addQuadCurve(to: pt(0.70, 0.55), control: pt(0.74, 0.46))
        path.addLine(to: pt(0.68, 0.60))
        path.addLine(to: pt(0.66, 0.92))
        path.addLine(to: pt(0.61, 0.92))
        path.addLine(to: pt(0.59, 0.64))
        path.addLine(to: pt(0.50, 0.64))
        path.addLine(to: pt(0.34, 0.62))
        path.addLine(to: pt(0.33, 0.92))
        path.addLine(to: pt(0.28, 0.92))
        path.addLine(to: pt(0.26, 0.62))
        path.addQuadCurve(to: pt(0.12, 0.62), control: pt(0.18, 0.64))
        path.closeSubpath()
        // Antlers.
        path.move(to: pt(0.74, 0.26))
        path.addLine(to: pt(0.70, 0.10))
        path.addLine(to: pt(0.64, 0.16))
        path.move(to: pt(0.78, 0.24))
        path.addLine(to: pt(0.84, 0.08))
        path.addLine(to: pt(0.90, 0.14))
        return path
    }
}

// Level 17 — a transparent footprint overlay sliding and rotating from the
// reference print onto a rotated one, flashing gold as it covers it. Looping.
struct FootprintCongruenceConceptVisual: View {
    private let bone = Color(red: 0.85, green: 0.76, blue: 0.58)
    private let cyanTint = Color(red: 0.36, green: 0.86, blue: 1.0)
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let cycle = (t * 0.28).truncatingRemainder(dividingBy: 1.0)
            // Phases: rest (0–0.15), travel+rotate (0.15–0.7), covered (0.7–1).
            let f = min(1, max(0, (cycle - 0.15) / 0.55))
            let e = f * f * (3 - 2 * f)
            let covered = cycle > 0.7

            let a = CGPoint(x: 52, y: 66)
            let b = CGPoint(x: 156, y: 78)
            let pos = CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)

            ZStack {
                // Reference and candidate prints.
                miniPrint(fill: bone, stroke: gold.opacity(0.85))
                    .position(a)
                miniPrint(fill: bone.opacity(0.8), stroke: covered ? gold : .white.opacity(0.25))
                    .rotationEffect(.degrees(120))
                    .position(b)
                    .shadow(color: covered ? gold.opacity(0.6) : .clear, radius: 8)

                // The travelling overlay.
                miniPrint(fill: cyanTint.opacity(0.30), stroke: cyanTint)
                    .rotationEffect(.degrees(120 * e))
                    .position(pos)
                    .opacity(covered ? 0.25 : 1)

                if covered {
                    Text("≅")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(gold)
                        .position(x: b.x, y: b.y - 42)
                }
            }
            .frame(width: 210, height: 140)
        }
    }

    private func miniPrint(fill: Color, stroke: Color) -> some View {
        ConceptFootprintShape()
            .fill(fill)
            .overlay(ConceptFootprintShape().stroke(stroke, lineWidth: 1.3))
            .frame(width: 42, height: 50)
    }
}

private struct ConceptFootprintShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        func blob(_ cx: CGFloat, _ cy: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ tilt: CGFloat) {
            var p = Path(ellipseIn: CGRect(x: -rw / 2, y: -rh / 2, width: rw, height: rh))
            p = p.applying(CGAffineTransform(rotationAngle: tilt))
            p = p.applying(CGAffineTransform(translationX: rect.minX + cx, y: rect.minY + cy))
            path.addPath(p)
        }
        blob(w * 0.5, h * 0.74, w * 0.52, h * 0.38, 0)         // heel
        blob(w * 0.5, h * 0.26, w * 0.20, h * 0.48, 0)         // centre toe
        blob(w * 0.16, h * 0.38, w * 0.18, h * 0.40, -0.5)     // left toe
        blob(w * 0.84, h * 0.38, w * 0.18, h * 0.40, 0.5)      // right toe
        return path
    }
}

// Level 110 — a looping skater riding a three-piece course, rolling the
// continuous join and jumping the open-circle gap.
struct PiecewiseSkateConceptVisual: View {
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let accent = Color(red: 0.28, green: 0.76, blue: 1.0)

    // Course in local coords: ramp up, flat (open end), lower flat.
    private let a0 = CGPoint(x: 14, y: 108), a1 = CGPoint(x: 74, y: 66)     // ramp
    private let b0 = CGPoint(x: 74, y: 66), b1 = CGPoint(x: 128, y: 66)     // flat, open right
    private let c0 = CGPoint(x: 152, y: 96), c1 = CGPoint(x: 200, y: 96)    // lower flat

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let cycle = (t * 0.30).truncatingRemainder(dividingBy: 1.0)
            Canvas { canvas, _ in
                drawSegment(canvas, a0, a1, leftClosed: true, rightClosed: true)
                drawSegment(canvas, b0, b1, leftClosed: true, rightClosed: false)
                drawSegment(canvas, c0, c1, leftClosed: true, rightClosed: true)

                // Skater position along ramp → flat → jump → lower flat.
                let f = cycle
                var p: CGPoint
                if f < 0.30 {
                    let s = f / 0.30
                    p = CGPoint(x: a0.x + (a1.x - a0.x) * s, y: a0.y + (a1.y - a0.y) * s)
                } else if f < 0.58 {
                    let s = (f - 0.30) / 0.28
                    p = CGPoint(x: b0.x + (b1.x - b0.x) * s, y: b0.y)
                } else if f < 0.78 {
                    let s = (f - 0.58) / 0.20
                    let x = b1.x + (c0.x - b1.x) * CGFloat(s)
                    let base = b1.y + (c0.y - b1.y) * CGFloat(s)
                    p = CGPoint(x: x, y: base - CGFloat(4 * s * (1 - s)) * 26)
                } else {
                    let s = (f - 0.78) / 0.22
                    p = CGPoint(x: c0.x + (c1.x - c0.x) * s, y: c0.y)
                }

                var board = Path()
                board.move(to: CGPoint(x: p.x - 8, y: p.y - 4))
                board.addLine(to: CGPoint(x: p.x + 8, y: p.y - 4))
                canvas.stroke(board, with: .color(gold), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                canvas.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 17, width: 7, height: 7)),
                            with: .color(.white))
            }
            .frame(width: 210, height: 130)
        }
    }

    private func drawSegment(_ ctx: GraphicsContext, _ p0: CGPoint, _ p1: CGPoint, leftClosed: Bool, rightClosed: Bool) {
        var line = Path()
        line.move(to: p0)
        line.addLine(to: p1)
        ctx.stroke(line, with: .color(accent), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        for (p, closed) in [(p0, leftClosed), (p1, rightClosed)] {
            let rect = CGRect(x: p.x - 3.6, y: p.y - 3.6, width: 7.2, height: 7.2)
            if closed {
                ctx.fill(Path(ellipseIn: rect), with: .color(accent))
            } else {
                ctx.fill(Path(ellipseIn: rect), with: .color(.black))
                ctx.stroke(Path(ellipseIn: rect), with: .color(accent), lineWidth: 1.5)
            }
        }
    }
}

// Level 109 — the parabola y = x² − 5x + 6 with its two roots pulsing, the
// answer every solving method converges on.
struct QuadraticLensesConceptVisual: View {
    private let accent = Color(red: 0.55, green: 0.78, blue: 0.98)
    private let gold = Color(red: 0.98, green: 0.74, blue: 0.30)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 3)
            Canvas { canvas, size in
                let xMin = -0.7, xMax = 5.7, yMin = -1.6, yMax = 6.6
                func sx(_ x: Double) -> CGFloat { CGFloat((x - xMin) / (xMax - xMin)) * size.width }
                func sy(_ y: Double) -> CGFloat { size.height - CGFloat((y - yMin) / (yMax - yMin)) * size.height }

                var ax = Path()
                ax.move(to: CGPoint(x: 0, y: sy(0))); ax.addLine(to: CGPoint(x: size.width, y: sy(0)))
                ax.move(to: CGPoint(x: sx(0), y: 0)); ax.addLine(to: CGPoint(x: sx(0), y: size.height))
                canvas.stroke(ax, with: .color(.white.opacity(0.22)), lineWidth: 1)

                var curve = Path()
                var first = true
                for i in 0...120 {
                    let x = xMin + (xMax - xMin) * Double(i) / 120
                    let p = CGPoint(x: sx(x), y: sy(x * x - 5 * x + 6))
                    if first { curve.move(to: p); first = false } else { curve.addLine(to: p) }
                }
                canvas.stroke(curve, with: .color(accent), lineWidth: 2.2)

                for (root, label) in [(2.0, "2"), (3.0, "3")] {
                    let p = CGPoint(x: sx(root), y: sy(0))
                    canvas.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)),
                                with: .color(gold))
                    let r = 7 + CGFloat(pulse) * 6
                    canvas.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                                  with: .color(gold.opacity(0.7 - pulse * 0.5)), lineWidth: 1.3)
                    canvas.draw(Text("x = \(label)").font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85)),
                                at: CGPoint(x: p.x, y: p.y + 13))
                }
            }
            .frame(width: 210, height: 150)
        }
    }
}

// Level 108 — a 2×2 area square split into a², ab, ab, b² tiles, the two ab
// tiles pulsing to show why the middle term is 2ab.
struct BinomialSquareConceptVisual: View {
    private let amber = Color(red: 0.98, green: 0.74, blue: 0.30)
    private let blue = Color(red: 0.34, green: 0.62, blue: 0.98)
    private let green = Color(red: 0.42, green: 0.82, blue: 0.55)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 2.4)
            let side: CGFloat = 118
            let aFrac: CGFloat = 0.6                 // a : b split
            let aLen = side * aFrac, bLen = side * (1 - aFrac)

            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    tile(amber, w: aLen, h: aLen, label: "a²", x: 0, y: 0, glow: 0)
                    tile(green, w: bLen, h: aLen, label: "ab", x: aLen, y: 0, glow: pulse)
                    tile(green, w: aLen, h: bLen, label: "ab", x: 0, y: aLen, glow: pulse)
                    tile(blue, w: bLen, h: bLen, label: "b²", x: aLen, y: aLen, glow: 0)
                }
                .frame(width: side, height: side)

                Text("(a + b)² = a² + 2ab + b²")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 210, height: 168)
        }
    }

    private func tile(_ color: Color, w: CGFloat, h: CGFloat, label: String, x: CGFloat, y: CGFloat, glow: Double) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(color.opacity(0.35 + glow * 0.4))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(color, lineWidth: 1))
            .overlay(Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white))
            .frame(width: w, height: h)
            .offset(x: x, y: y)
    }
}

// Level 107 — the Spiral of Theodorus drawing itself outward, one √(n+1)
// triangle at a time, then looping.
struct SpiralOfTheodorusConceptVisual: View {
    private static let spokes: [CGPoint] = {
        var out: [CGPoint] = []
        var phi = 0.0
        for k in 1...15 {
            let r = Double(k).squareRoot()
            out.append(CGPoint(x: cos(phi) * r, y: -sin(phi) * r))
            phi += atan(1.0 / Double(k).squareRoot())
        }
        return out
    }()

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // Build up over ~5s, hold, then restart.
            let cycle = (t * 0.2).truncatingRemainder(dividingBy: 1.0)
            let built = Int((min(cycle / 0.82, 1.0) * 14).rounded()) + 1  // 1…15 spokes
            Canvas { canvas, size in
                draw(canvas, size: size, built: built)
            }
            .frame(width: 200, height: 150)
        }
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize, built: Int) {
        let spokes = Self.spokes
        let minX = spokes.map(\.x).min() ?? 0, maxX = spokes.map(\.x).max() ?? 1
        let minY = spokes.map(\.y).min() ?? 0, maxY = spokes.map(\.y).max() ?? 1
        let scale = min((size.width - 30) / max(maxX - minX, 0.001),
                        (size.height - 30) / max(maxY - minY, 0.001))
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let bcx = (minX + maxX) / 2, bcy = (minY + maxY) / 2
        func screen(_ u: CGPoint) -> CGPoint {
            CGPoint(x: center.x + (u.x - bcx) * scale, y: center.y + (u.y - bcy) * scale)
        }
        let origin = screen(.zero)

        for i in 0..<max(0, min(built, spokes.count) - 1) {
            let a = screen(spokes[i]), b = screen(spokes[i + 1])
            var tri = Path()
            tri.move(to: origin); tri.addLine(to: a); tri.addLine(to: b); tri.closeSubpath()
            ctx.fill(tri, with: .color(Color(hue: Double(i) / 15, saturation: 0.82, brightness: 0.98).opacity(0.85)))
            ctx.stroke(tri, with: .color(.black.opacity(0.3)), lineWidth: 0.7)
        }
        ctx.fill(Path(ellipseIn: CGRect(x: origin.x - 2.5, y: origin.y - 2.5, width: 5, height: 5)),
                 with: .color(.white.opacity(0.9)))
    }
}

// Level 104 — two cylinders balancing as x litres pour into the right one.
struct CylinderConceptVisual: View {
    private let water  = Color(red: 0.30, green: 0.72, blue: 0.98)
    private let xWater = Color(red: 0.98, green: 0.74, blue: 0.30)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = (t * 0.4).truncatingRemainder(dividingBy: 1.0)
            let grow = min(1.0, phase * 1.6)          // fill during the first ~2/3
            let extra = 3.0 * grow                    // 0 → 3 litres of x
            let solved = grow >= 1.0
            let w: CGFloat = 52
            let h: CGFloat = 108
            ZStack {
                // Left cylinder — starts full at 5L, drains as water is pumped out.
                VStack(spacing: 5) {
                    EquationCylinder(width: w, height: h, divisions: 5,
                                     baseValue: 5 - extra, extraValue: 0,
                                     baseColor: xWater, extraColor: xWater)
                    Text("\(Int((5 - extra).rounded()))L")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(xWater)
                }
                .position(x: 62, y: 68)

                // Flow arrow.
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(solved ? xWater : .white.opacity(0.3))
                    .position(x: 105, y: 48)

                // Right cylinder — 2L base + x pumped in.
                ZStack {
                    EquationCylinder(width: w, height: h, divisions: 5,
                                     baseValue: 2, extraValue: extra,
                                     baseColor: water, extraColor: xWater)
                    Text(solved ? "3L" : "x")
                        .font(.system(size: solved ? 15 : 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(extra > 0.4 ? .black.opacity(0.78) : xWater)
                        .offset(y: h / 2 - CGFloat((2 + extra / 2) / 5) * h)
                        .animation(.easeOut(duration: 0.2), value: extra)
                }
                .frame(width: w, height: h)
                .overlay(alignment: .bottom) {
                    Text("2L").font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(water).offset(y: 17)
                }
                .position(x: 148, y: 68)

                Text(solved ? "x + 2 = 5  →  x = 3" : "x + 2 = 5")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(solved ? xWater : .white.opacity(0.7))
                    .position(x: 105, y: 138)
            }
            .frame(width: 210, height: 150)
        }
    }
}

// Level 105 — glacier thickness transformed by a chain of operations.
struct GlacierConceptVisual: View {
    private let ice = Color(red: 0.64, green: 0.90, blue: 1.0)
    private let accent = Color(red: 0.42, green: 0.82, blue: 1.0)
    private let gold = Color(red: 0.93, green: 0.78, blue: 0.40)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = (t * 0.25).truncatingRemainder(dividingBy: 1.0)
            let state: (thickness: CGFloat, label: String, op: String) =
                phase < 0.25 ? (13, "x = 13", "x") :
                phase < 0.50 ? (16, "16m", "+3") :
                phase < 0.75 ? (8, "8m", "/2") :
                (12, "12m", "+4")
            let thickness = state.thickness
            let h = 24 + thickness / 20 * 76

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 150, height: 112)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
                    .position(x: 105, y: 70)

                VStack(spacing: 0) {
                    if (phase >= 0.25 && phase < 0.50) || phase >= 0.75 {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.white.opacity(0.94))
                            .frame(width: 92, height: 15)
                    }
                    GlacierMiniShape()
                        .fill(LinearGradient(colors: [ice, accent.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                        .overlay(GlacierMiniShape().stroke(.white.opacity(0.58), lineWidth: 1))
                        .frame(width: 104, height: h)
                }
                .frame(width: 120, height: 120, alignment: .bottom)
                .position(x: 105, y: 72)
                .shadow(color: accent.opacity(0.35), radius: 14)
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: thickness)

                Text(state.label)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(phase >= 0.75 ? gold : accent)
                    .position(x: 105, y: 20)

                Text(state.op)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 30)
                    .background(Capsule().fill(phase >= 0.75 ? gold : accent))
                    .position(x: 105, y: 136)
            }
            .frame(width: 210, height: 150)
        }
    }
}

private struct GlacierMiniShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.16))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.11))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
