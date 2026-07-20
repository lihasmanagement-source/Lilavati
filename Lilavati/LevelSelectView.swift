import SwiftUI
import Combine

// MARK: - Completed-level progress (persists between launches)

final class LevelProgress: ObservableObject {
    static let shared = LevelProgress()
    private let key = "completedLevels"

    @Published private(set) var completed: Set<Int>

    private init() {
        let stored = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        completed = Set(stored.filter { MathItCurriculum.topic(forLevelNumber: $0)?.screenLevel != nil })
    }

    func isComplete(_ number: Int) -> Bool { completed.contains(number) }

    func markComplete(_ number: Int) {
        guard MathItCurriculum.topic(forLevelNumber: number)?.screenLevel != nil,
              !completed.contains(number) else { return }
        completed.insert(number)
        UserDefaults.standard.set(Array(completed), forKey: key)
    }

    func completedCount(in group: LevelGroup) -> Int {
        group.levels.reduce(0) { $0 + (completed.contains($1.number) ? 1 : 0) }
    }

    func resetAll() {
        completed.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// Typography — Trajan-style caps + Cormorant-Garamond-style body.
// Falls back to the closest iOS faces when the real fonts aren't bundled;
// drop "Trajan Pro" / "Cormorant Garamond" .otf into the app to use them exactly.
extension Font {
    // Bundle "Trajan Pro" / "Cormorant Garamond" .otf and swap the names below
    // for the exact faces. For now these use the closest built-in iOS fonts.
    static func trajan(_ size: CGFloat) -> Font {
        UIFont(name: "TrajanPro-Regular", size: size) != nil
            ? .custom("TrajanPro-Regular", size: size)
            : .custom("Copperplate", size: size)
    }
    static func garamond(_ size: CGFloat) -> Font {
        UIFont(name: "CormorantGaramond-Regular", size: size) != nil
            ? .custom("CormorantGaramond-Regular", size: size)
            : .custom("Hoefler Text", size: size)
    }
}

// MARK: - Level select · gold 10×10 grid of all 100 levels

struct LevelSelectView: View {
    var initialGroupTitle: String? = nil
    @Binding var revealed: Bool            // false = intro seal; true = grid unrolled (persists for the session)
    let onLevelSelected: (Int) -> Void
    var onPlaceholder: (Int) -> Void = { _ in }   // curriculum number of an unbuilt topic

    @State private var showResetConfirm = false
    @State private var glow = false
    @State private var launchSettled = false
    @State private var launchCopyVisible = false
    @ObservedObject private var progress = LevelProgress.shared

    private let gold = Color(red: 0.93, green: 0.78, blue: 0.40)
    private let panelFill = Color(red: 0.05, green: 0.05, blue: 0.09)

    var body: some View {
        GeometryReader { proxy in
            let W = proxy.size.width
            let H = proxy.size.height
            let hPad: CGFloat = 14
            let topH: CGFloat = 92       // title band
            let botH: CGFloat = 64       // progress band
            let gridW = W - hPad * 2
            let gridH = H - topH - botH

            ZStack {
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.10),
                                        Color(red: 0.02, green: 0.02, blue: 0.05)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("Lilavati")
                            .font(.trajan(28)).tracking(1)
                            .foregroundStyle(gold)
                            .shadow(color: gold.opacity(0.6), radius: 10)
                        Text("Math, made playful")
                            .font(.garamond(15)).tracking(1)
                            .foregroundStyle(gold.opacity(0.6))
                    }
                    .frame(height: topH)

                    curriculumList
                        .frame(width: gridW, height: gridH)

                    VStack(spacing: 8) {
                        Text("\(progress.completed.count) / \(MathItCurriculum.playable.count) COMPLETE")
                            .font(.trajan(13)).tracking(2)
                            .foregroundStyle(gold.opacity(0.9))
                            .shadow(color: gold.opacity(0.5), radius: 6)
                        if progress.completed.count > 0 {
                            Button { showResetConfirm = true } label: {
                                Text("RESET PROGRESS")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundStyle(gold.opacity(0.55))
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .overlay(Capsule().stroke(gold.opacity(0.35), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: botH)
                }
                .frame(width: W, height: H)
                .opacity(revealed ? 1 : 0)
                .scaleEffect(x: 1, y: revealed ? 1 : 0.02, anchor: .center)   // unrolls from the seal
                .allowsHitTesting(revealed)

                if !revealed {
                    launchBrand(W: W, H: H)
                        .transition(.opacity)
                }
            }
        }
        .confirmationDialog("Reset all progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) {
                withAnimation { progress.resetAll() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This clears every completed level. This can't be undone.")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { glow = true }
            launchSettled = false
            launchCopyVisible = false
            withAnimation(.interpolatingSpring(stiffness: 72, damping: 10)) {
                launchSettled = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.42)) {
                    launchCopyVisible = true
                }
            }
        }
    }

    private func launchBrand(W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("LilavatiLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(W * 0.58, 260))
                    .scaleEffect(launchSettled ? 1.0 : 0.16)
                    .opacity(launchSettled ? 1.0 : 0.42)
                    .shadow(color: gold.opacity(glow ? 0.58 : 0.28), radius: glow ? 26 : 14)
                    .accessibilityHidden(true)

                VStack(spacing: 28) {
                    Text("Math, made playful")
                        .font(.garamond(18))
                        .tracking(1.2)
                        .foregroundStyle(gold.opacity(0.82))

                    Button {
                        withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) {
                            revealed = true
                        }
                    } label: {
                        Text("BEGIN")
                            .font(.trajan(16))
                            .tracking(4)
                            .foregroundStyle(gold)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 13)
                            .background(.black, in: Capsule())
                            .overlay(Capsule().stroke(gold.opacity(glow ? 0.96 : 0.54), lineWidth: 1.2))
                            .shadow(color: gold.opacity(glow ? 0.74 : 0.26), radius: glow ? 24 : 12)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(launchCopyVisible)
                }
                .opacity(launchCopyVisible ? 1 : 0)
                .offset(y: launchCopyVisible ? 0 : 14)
            }
            .frame(width: W, height: H)
        }
        .frame(width: W, height: H)
        .accessibilityLabel("Lilavati. Math, made playful.")
    }

    // Curriculum-ordered layout: the four years plus Bonus, each topic a tile
    // (placeholders are dashed and disabled).
    private var curriculumList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(MathItCurriculum.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2).fill(section.color).frame(width: 4, height: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(section.title.uppercased())
                                        .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1)
                                        .foregroundStyle(gold)
                                    Text(section.subtitle)
                                        .font(.garamond(11)).foregroundStyle(gold.opacity(0.5))
                                }
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                                ForEach(section.topics) { topicTile($0) }
                            }
                        }
                        .id(section.title)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 20)
            }
            .onAppear { scrollToInitialSection(using: scrollProxy) }
            .onChange(of: initialGroupTitle) { _, _ in
                scrollToInitialSection(using: scrollProxy)
            }
        }
    }

    private func scrollToInitialSection(using proxy: ScrollViewProxy) {
        guard let initialGroupTitle else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(initialGroupTitle, anchor: .top)
        }
    }

    private func topicTile(_ topic: CurriculumTopic) -> some View {
        let done = progress.isComplete(topic.number)
        let placeholder = topic.isPlaceholder
        return Button {
            if topic.screenLevel != nil {
                onLevelSelected(topic.number)
            } else {
                onPlaceholder(topic.number)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(topic.number)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                Text(topic.title)
                    .font(.system(size: 8.5, weight: .medium))
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
            }
            .foregroundStyle(placeholder ? gold.opacity(0.3) : (done ? panelFill : gold))
            .frame(maxWidth: .infinity).frame(height: 54)
            .background((done ? gold : panelFill).opacity(placeholder ? 0.35 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(gold.opacity(placeholder ? 0.25 : (done ? 1 : 0.5)),
                        style: StrokeStyle(lineWidth: 1, dash: placeholder ? [3, 3] : [])))
            .shadow(color: gold.opacity(done ? 0.4 : 0), radius: done ? 5 : 0)
        }
        .buttonStyle(.plain)
    }

    private func levelCell(_ n: Int, size: CGFloat) -> some View {
        let done = progress.isComplete(n)
        return Button { onLevelSelected(n) } label: {
            Text("\(n)")
                .font(.system(size: size * 0.36, weight: .semibold, design: .monospaced))
                .lineLimit(1).minimumScaleFactor(0.5)
                .foregroundStyle(done ? panelFill : gold)
                .frame(width: size, height: size)
                .background(done ? gold : panelFill, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(gold.opacity(done ? 1 : 0.55), lineWidth: 1))
                .shadow(color: gold.opacity(done ? 0.5 : 0.15), radius: done ? 6 : 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data

struct LevelItem: Identifiable { let number: Int; let title: String; var id: Int { number } }

struct LevelGroup: Identifiable {
    let title: String
    let color: Color
    let levels: [LevelItem]
    var id: String { title }

    static let all: [LevelGroup] = build()

    static let names: [String] = [
        "one mirror", "the number line", "lunar phases", "projectile", "circle",
        "coriolis effect", "nim", "fraction tension", "lens focus", "block multiplication",
        "weigh in", "music graph", "pyramid graph", "wave form", "string theory",
        "rockin' out", "mirror path", "binary", "prism path", "gravity assist",
        "hot cross fractions", "mirror bloom", "constellation", "closed circuit", "shadows",
        "harmonics", "fractal", "pulsar", "10 lockers", "pythagorean rescue",
        "encryption", "volume garden", "geometric origami", "roots squared", "coordinate affection",
        "gear sync", "permutation lock", "vector field", "topology", "balance point",
        "angle forge", "euclidean rhythm", "binary relay", "mechanical computer", "makes cents",
        "power tower", "mystery balance", "symbol pattern", "slope rise run", "inequality gates",
        "laser fence", "ramping up", "rate relay", "split in half", "tessellation floor",
        "net fold", "transformation map", "garden planner", "coordinate navigator", "memory match",
        "vanishing point", "coordinate battle", "scale city", "escape block", "tempo engine",
        "phase shift", "sound envelope", "pendulum launch", "updraft", "chord detective",
        "echo canyon", "interference pool", "doppler dash", "fifths memory", "harmonic ladder",
        "hanoi temple", "matrix rotation", "partial derivatives", "insertion sort", "no contact",
        "paint with numbers", "river crossing", "reservoir", "lattice growth", "storm shelter",
        "sheep herding", "ant colony", "predator-prey", "chladni plate", "knight's tour",
        "dijkstra path", "bitonic sort", "3d tic-tac-toe", "pinball memory", "double pendulum",
        "fill the grid", "convex hull", "josephus", "ant cemetery", "flocking",
        "orbital", "mancala", "cooking assembly line", "graduated cylinders", "glacier time machine", "powers of ten",
        "clock tower", "genetics lab", "five lenses", "skatepark transitions", "parabola tank", "wildlife zoom",
        "soh cah toa blast", "polynomial functions", "factoring polynomials", "complex numbers", "rational functions",
        "reversible machines",
    ]

    static func title(for number: Int) -> String? {
        guard (1...names.count).contains(number) else { return nil }
        return names[number - 1]
    }

    private static func build() -> [LevelGroup] {
        func g(_ title: String, _ c: Color, _ nums: [Int]) -> LevelGroup {
            LevelGroup(title: title, color: c, levels: nums.sorted().map { LevelItem(number: $0, title: names[$0 - 1]) })
        }
        return [
            g("Numbers & Arithmetic", Color(red: 0.30, green: 0.82, blue: 1.0),
              [1, 2, 6, 9, 10, 21, 34, 45, 46, 54]),                                   // 0
            g("Algebra, Patterns & Sequences", Color(red: 0.98, green: 0.55, blue: 0.25),
              [3, 11, 27, 30, 40, 47, 48, 50]),                                         // 1
            g("Geometry & Spatial Reasoning", Color(red: 0.98, green: 0.30, blue: 0.72),
              [5, 7, 22, 32, 33, 41, 55, 56, 57, 58, 63, 77]),                          // 2
            g("Coordinates, Graphs & Vectors", Color(red: 0.55, green: 0.55, blue: 1.0),
              [13, 23, 35, 38, 49, 59, 62]),                                            // 3
            g("Motion & Physics", Color(red: 0.36, green: 0.66, blue: 1.0),
              [4, 8, 20, 52, 53, 68, 69, 95]),                                          // 4
            g("Waves, Sound & Music", Color(red: 1.0, green: 0.78, blue: 0.20),
              [12, 14, 15, 16, 26, 28, 42, 65, 66, 67, 70, 71, 72, 73, 74, 75, 89]),    // 5
            g("Light & Optics", Color(red: 0.30, green: 0.90, blue: 0.95),
              [17, 19, 25, 51, 61]),                                                    // 6
            g("Logic, Circuits & Computation", Color(red: 0.50, green: 0.95, blue: 0.30),
              [18, 24, 31, 36, 43, 44, 78]),                                            // 7
            g("Algorithms & Classic Puzzles", Color(red: 0.70, green: 0.40, blue: 1.0),
              [29, 37, 39, 60, 64, 76, 79, 80, 81, 82, 85, 90, 91, 92, 93, 94, 96, 97, 98]), // 8
            g("Emergence & Complex Systems", Color(red: 0.66, green: 0.95, blue: 0.40),
              [83, 84, 86, 87, 88, 99, 100]),                                           // 9
        ]
    }
}
