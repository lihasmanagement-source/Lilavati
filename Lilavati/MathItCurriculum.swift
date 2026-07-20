import SwiftUI

// MARK: - Curriculum ordering (single source of truth)
//
// The four-year curriculum. `number` is the tile's ordering position inside the
// homepage list and the public level number shown to the player.
// `screenLevel` is only the hidden legacy view binding used to open the actual
// SwiftUI screen while the app is being migrated.
//
// Edit `sections` to re-map which level fills which topic — everything (the menu
// layout, numbering, and later the play order) reads from here.

struct CurriculumTopic: Identifiable {
    let number: Int          // curriculum ordering position
    let title: String
    let screenLevel: Int?
    var id: Int { number }
    var isPlaceholder: Bool { screenLevel == nil }
}

struct CurriculumSection: Identifiable {
    let title: String
    let subtitle: String
    let color: Color
    let topics: [CurriculumTopic]
    var id: String { title }
}

enum MathItCurriculum {
    // Colors per year band (kept close to the existing gold-forward palette).
    private static let cY1 = Color(red: 0.36, green: 0.66, blue: 1.0)
    private static let cY2 = Color(red: 0.98, green: 0.55, blue: 0.25)
    private static let cY3 = Color(red: 0.50, green: 0.95, blue: 0.40)
    private static let cY4 = Color(red: 0.78, green: 0.48, blue: 1.0)
    private static let cBonus = Color(red: 0.93, green: 0.78, blue: 0.40)

    static let sections: [CurriculumSection] = {
        var n = 0
        func t(_ title: String, _ screenLevel: Int?) -> CurriculumTopic {
            n += 1
            return CurriculumTopic(
                number: n,
                title: title,
                screenLevel: screenLevel
            )
        }

        let year1 = CurriculumSection(
            title: "Year 1 · Foundations",
            subtitle: "How mathematics describes quantity and pattern",
            color: cY1,
            topics: [
                t("Counting & Natural Numbers", 101),   // universe / number-system model
                t("Integers", 2),                       // the number line
                t("Fractions", 15),                     // string theory (music) — fraction tension removed
                t("Decimals & Percent", 45),
                t("Ratios & Proportion", 63),
                t("Order of Operations", 44),
                t("Variables", 47),
                t("Expressions", 103),  // cooking assembly line
                t("One-Step Equations", 104),   // graduated cylinders — x + a = b
                t("Multi-Step Equations", 105),        // glacier time machine — (x + 8) / 2 = 20
                t("Inequalities", 50),
                t("Coordinate Plane", 52),
                t("Slope", 49),
                t("Linear Functions", 14),
                t("Systems of Equations", 62),
                t("Sequences", 3),   // moon phases — cyclic sequence of illumination
                t("Exponents", 34),
                t("Scientific Notation", 106),   // powers of ten — camera zoom
                t("Radicals", 107),   // pendulum clock tower — T ∝ √L
                t("Factoring", 108),   // Punnett square — (a+b)² = a² + 2ab + b²
                t("Number Sense", 21),               // abacus marketplace — base-10 regrouping
                t("Parabolas", 111),
                t("Functions", 35),   // coordinate affection (music graph moved into pyramid graph L13)
                t("Piecewise Functions", 110),   // skatepark transitions
                t("Absolute Value", 25),
                t("One Mirror", 1),
            ])

        let year2 = CurriculumSection(
            title: "Year 2 · Geometry & Measurement",
            subtitle: "Understanding space and structure",
            color: cY2,
            topics: [
                t("Angles", 4),
                t("Triangles", 41),
                t("Congruence", 17),
                t("Similarity", 112),   // wildlife zoom — scale factor k
                t("Pythagorean Theorem", 30),
                t("Circles", 5),
                t("Polygons", 54),
                t("Area and Volume", 96),
                t("Surface Area", 56),
                t("Volume", 32),
                t("Coordinate Geometry", 59),
                t("Transformations", 143),
                t("Symmetry", 22),
                t("Tessellations", 55),
                t("Vectors Intro", 38),
                t("3D Geometry", 33),
                t("Perspective", 61),
                t("Area and Perimeter", 58),
                t("Right Triangle Applications", 94),   // Pinball Memory
                t("Law of Sines", 19),
                t("Cosine Waves", 69),
                t("Networks & Graphs", 23),   // constellation network + musical pyramid
                t("Optimization", 87),
                t("Cymatics", 89),
            ])

        let year3 = CurriculumSection(
            title: "Year 3 · Algebra II & Discrete",
            subtitle: "Relationships between changing quantities",
            color: cY3,
            topics: [
                t("Polynomial Functions", 114),
                t("Factoring Polynomials", 115),
                t("N-Queens Problem", 116),
                t("Rational Functions", 117),
                t("Algorithms", 129),
                t("Inverse Functions", 118),
                t("Composite Functions", 57),
                t("Absolute Value Functions", 120),
                t("Quadratic Systems", 121),
                t("Matrices", 77),
                t("Determinants", 122),
                t("Recursive Sequences", 76),
                t("Arithmetic Sequences", 48),
                t("Geometric Sequences", 123),
                t("Sigma Notation", 124),
                t("Galton's Board", 125),
                t("Binomial Theorem", 126),
                t("Modular Arithmetic", 98),
                t("Prime Numbers", 127),
                t("Cryptography", 31),
                t("Boolean Logic", 43),
                t("Graph Theory", 90),
                t("Sorting Networks", 92),
                t("Game Theory", 102),
                t("Binary", 18),
            ])

        let year4 = CurriculumSection(
            title: "Year 4 · Precalculus & Calculus",
            subtitle: "Continuous change and abstraction",
            color: cY4,
            topics: [
                t("Unit Circle", 113),
                t("Doppler Effect", 73),
                t("Wave Motion", 26),
                t("Periodic Functions", 68),
                t("Polar Coordinates", 79),
                t("Parametric Equations", 80),
                t("Limits", 130),
                t("Continuity", 131),
                t("Derivatives", 53),
                t("Rates of Change", 84),
                t("Calculus Optimization", 133),
                t("Coriolis Effect", 6),
                t("Integrals", 134),
                t("Logarithmic Functions", 135),
                t("Differential Equations", 88),
                t("Probability", 100),
                t("Arc Length", 138),
                t("Infinite Series", 139),
                t("Chaos Theory", 140),
                t("Fractals", 27),
                t("Partial Derivatives", 78),
                t("3D Coordinates", 93),
                t("Gradient Descent", 86),
                t("Interference Pool", 72),
            ])

        // Bonus — every remaining built level, kept fully accessible.
        let bonusLevels: [(String, Int)] = [
            ("Weigh In", 11),
            ("Closed Circuit", 24),
            ("10 Lockers", 29),
            ("Gear Sync", 36), ("Permutation Lock", 37),
            ("Balance Point", 40), ("3D Geometry Crane", 42),
            ("Laser Fence", 51),
            ("Memory Match", 60),
            ("Escape Block", 64), ("Sound Envelope", 67),
            ("Chord Detective", 70),
            ("Echo Canyon", 71),
            ("Fifths Memory", 74), ("XOR", 7),
            ("Reservoir", 83), ("Storm Shelter", 85),
            ("Topology", 39),
            ("Convex Hull", 97),
        ]
        let bonusTopics = bonusLevels.map { t($0.0, $0.1) }
        let bonus = CurriculumSection(
            title: "Bonus",
            subtitle: "Extra built levels not yet mapped to a topic",
            color: cBonus,
            topics: bonusTopics)

        return [year1, year2, year3, year4, bonus]
    }()

    static var allTopics: [CurriculumTopic] { sections.flatMap { $0.topics } }
    static var playable: [CurriculumTopic] { allTopics.filter { !$0.isPlaceholder } }

    /// The topic + its section for a curriculum list position.
    static func placement(forPosition number: Int) -> (topic: CurriculumTopic, section: CurriculumSection)? {
        for s in sections { if let t = s.topics.first(where: { $0.number == number }) { return (t, s) } }
        return nil
    }

    /// The topic for the actual level number used everywhere outside the screen binding.
    static func topic(forLevelNumber level: Int) -> CurriculumTopic? {
        allTopics.first { $0.number == level }
    }

    /// The topic backed by a hidden legacy screen/view binding.
    static func topic(forScreenLevel level: Int) -> CurriculumTopic? {
        allTopics.first { $0.screenLevel == level }
    }

    /// The visible level number for a hidden legacy screen/view binding.
    static func levelNumber(forScreenLevel level: Int) -> Int? {
        topic(forScreenLevel: level)?.number
    }

    /// The hidden legacy screen/view binding opened by a visible level number.
    static func screenLevel(forLevelNumber number: Int) -> Int? {
        allTopics.first { $0.number == number }?.screenLevel
    }

    /// The next playable visible level number after a given visible level number.
    static func nextLevel(after level: Int) -> Int? {
        guard let idx = allTopics.firstIndex(where: { $0.number == level }) else { return nil }
        for topic in allTopics[(idx + 1)...] where topic.screenLevel != nil {
            return topic.number
        }
        return nil
    }

    /// Step to the next/previous playable visible level number (skipping placeholders).
    static func step(fromNumber number: Int, by delta: Int) -> Int? {
        var pos = number + delta
        while pos >= 1 && pos <= allTopics.count {
            if screenLevel(forLevelNumber: pos) != nil { return pos }
            pos += delta
        }
        return nil
    }

    static func hasPlayable(before number: Int) -> Bool {
        allTopics.contains { $0.number < number && $0.screenLevel != nil }
    }

    static func hasPlayable(after number: Int) -> Bool {
        allTopics.contains { $0.number > number && $0.screenLevel != nil }
    }
}
