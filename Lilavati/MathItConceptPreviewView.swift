import SwiftUI

struct MathItConceptDefinition {
    let number: Int
    let title: String
    let instruction: String
    let mechanic: String
    let buildNote: String
    let visual: MathItConceptVisual
}

enum MathItConceptVisual {
    case functionMachine
    case percentMarket
    case exponentTower
    case equationPaths
    case sequenceGarden
    case probabilityLab
    case inequalityGate
    case decimalOrbit
    case polynomialBlocks
    case rateRace
    case symmetryStudio
    case tessellationFloor
    case crossSectionScanner
    case transformationMap
    case areaArchitect
    case coordinateNavigator
    case netWorkshop
    case perspectiveGrid
    case locusBeacon
    case scaleCity
    case packingCrates
    case waveformMixer
    case beatGrid
    case phaseRings
    case soundEnvelope
    case spectrumBars
    case chordCircle
    case echoTunnel
    case interferencePool
    case networkGraph
    case stateMachine
    case sortingFlow
    case systemGrid
    case logicScene(Int)
}

extension MathItConceptDefinition {
    static let algebraPreviews: [Int: MathItConceptDefinition] = [
        44: .init(
            number: 44,
            title: "function factory",
            instruction: "Route each input through the machine and predict the output.",
            mechanic: "Drag number tiles into a function machine, then choose the matching output.",
            buildNote: "Add editable function rules, input tiles, and output validation.",
            visual: .functionMachine
        ),
        45: .init(
            number: 45,
            title: "makes cents",
            instruction: "Scan the items, then build the exact payment from a $20 bill.",
            mechanic: "Double-tap bills and coins to split them into smaller denominations, then move the exact amount to the counter.",
            buildNote: "Animate the scanner, cart, bill splitting, and exact-payment validation.",
            visual: .percentMarket
        ),
        46: .init(
            number: 46,
            title: "power tower",
            instruction: "Build powers that reach the target height without going over.",
            mechanic: "Stack bases and exponents to create values that match tower targets.",
            buildNote: "Add stackable base and exponent tiles with live evaluation.",
            visual: .exponentTower
        ),
        47: .init(
            number: 47,
            title: "equation crossroads",
            instruction: "Choose operations that keep both paths equal.",
            mechanic: "Guide two expressions through operation gates until they meet at one value.",
            buildNote: "Add selectable operation gates and expression-state tracking.",
            visual: .equationPaths
        ),
        48: .init(
            number: 48,
            title: "arithmetic sequences",
            instruction: "Find the constant difference and draw the next term in the pattern.",
            mechanic: "Read evenly changing terms, identify the shared step, and complete the next symbol.",
            buildNote: "Use the existing symbol-pattern drawing level as the arithmetic-sequence experience.",
            visual: .sequenceGarden
        ),
        49: .init(
            number: 49,
            title: "probability lab",
            instruction: "Mix colored samples to create the requested probability.",
            mechanic: "Adjust colored tokens in a chamber until the fraction matches the target.",
            buildNote: "Add token controls, fraction simplification, and randomized targets.",
            visual: .probabilityLab
        ),
        50: .init(
            number: 50,
            title: "inequality gates",
            instruction: "Open every gate by placing the correct inequality symbol.",
            mechanic: "Compare moving quantities and choose less than, greater than, or equal.",
            buildNote: "Add symbol tiles, changing quantities, and gate animations.",
            visual: .inequalityGate
        ),
        51: .init(
            number: 51,
            title: "decimal orbit",
            instruction: "Place each decimal at its exact orbit distance.",
            mechanic: "Order decimals and fractions by distance from zero.",
            buildNote: "Add draggable values, snapping orbit positions, and mixed representations.",
            visual: .decimalOrbit
        ),
        52: .init(
            number: 52,
            title: "polynomial foundry",
            instruction: "Combine algebra blocks to forge the target expression.",
            mechanic: "Join and remove x-squared, x, and unit blocks to simplify polynomials.",
            buildNote: "Add algebra-tile dragging, combining rules, and target generation.",
            visual: .polynomialBlocks
        ),
        53: .init(
            number: 53,
            title: "rate relay",
            instruction: "Match each runner with the rate that reaches the finish on time.",
            mechanic: "Compare distance, time, and speed across several animated lanes.",
            buildNote: "Add rate controls, moving runners, and distance-time challenges.",
            visual: .rateRace
        )
    ]

    static let geometryPreviews: [Int: MathItConceptDefinition] = [
        54: .init(number: 54, title: "symmetry studio",
                  instruction: "Complete each glowing design across its mirror lines.",
                  mechanic: "Place missing points and shapes using reflection and rotational symmetry.",
                  buildNote: "Add draggable points, symmetry checks, and mirrored drawing trails.",
                  visual: .symmetryStudio),
        55: .init(number: 55, title: "tessellation floor",
                  instruction: "Tile the floor with no gaps and no overlaps.",
                  mechanic: "Rotate and place polygons to discover which shapes tessellate.",
                  buildNote: "Add rotatable tiles, snapping edges, and overlap detection.",
                  visual: .tessellationFloor),
        56: .init(number: 56, title: "slice lab",
                  instruction: "Match each cutting plane to the cross-section it creates.",
                  mechanic: "Move a plane through solids and predict the resulting 2D shape.",
                  buildNote: "Add movable slicing planes and animated solid cross-sections.",
                  visual: .crossSectionScanner),
        57: .init(number: 57, title: "transformation map",
                  instruction: "Move the shape onto its target using exact transformations.",
                  mechanic: "Sequence translations, rotations, reflections, and dilations.",
                  buildNote: "Add transformation cards, coordinate tracking, and ghost targets.",
                  visual: .transformationMap),
        58: .init(number: 58, title: "area architect",
                  instruction: "Rearrange the pieces to prove two areas are equal.",
                  mechanic: "Cut and compose figures while preserving total area.",
                  buildNote: "Add draggable polygon pieces and area-preservation validation.",
                  visual: .areaArchitect),
        59: .init(number: 59, title: "coordinate navigator",
                  instruction: "Plot a route using bearings and coordinate clues.",
                  mechanic: "Travel between ordered pairs while tracking direction and distance.",
                  buildNote: "Add route plotting, compass controls, and distance scoring.",
                  visual: .coordinateNavigator),
        60: .init(number: 60, title: "net workshop",
                  instruction: "Choose the flat net that folds into the target solid.",
                  mechanic: "Fold candidate nets and test whether their faces meet correctly.",
                  buildNote: "Add fold animations, selectable hinges, and collision checks.",
                  visual: .netWorkshop),
        61: .init(number: 61, title: "vanishing point",
                  instruction: "Align every edge with the correct vanishing point.",
                  mechanic: "Construct one-point and two-point perspective scenes.",
                  buildNote: "Add draggable guide lines and perspective alignment scoring.",
                  visual: .perspectiveGrid),
        62: .init(number: 62, title: "coordinate battle",
                  instruction: "Reveal every point that satisfies the beacon rule.",
                  mechanic: "Trace loci defined by equal distance, fixed distance, and angle conditions.",
                  buildNote: "Add movable beacons, live distance fields, and path validation.",
                  visual: .locusBeacon),
        63: .init(number: 63, title: "scale city",
                  instruction: "Resize the blueprint without changing its proportions.",
                  mechanic: "Apply scale factors to buildings, roads, and measured distances.",
                  buildNote: "Add scale controls, blueprint overlays, and ratio checks.",
                  visual: .scaleCity),
        64: .init(number: 64, title: "escape block",
                  instruction: "Slide the marked block through the side opening.",
                  mechanic: "Shift horizontal and vertical blocks along one axis to clear a path.",
                  buildNote: "Add sliding blocks, blocked-path checks, and escape validation.",
                  visual: .packingCrates)
    ]

    static let musicPreviews: [Int: MathItConceptDefinition] = [
        65: .init(number: 65, title: "tempo engine", instruction: "Set the pulse to match the target tempo.",
                  mechanic: "Adjust beat spacing and compare beats per minute.", buildNote: "Add a tempo slider, metronome audio, and timing validation.", visual: .beatGrid),
        66: .init(number: 66, title: "phase shift", instruction: "Align the two waves so their peaks arrive together.",
                  mechanic: "Slide one periodic wave to explore phase difference.", buildNote: "Add draggable phase controls and constructive-interference feedback.", visual: .phaseRings),
        67: .init(number: 67, title: "sound envelope", instruction: "Shape the sound from its first attack to its final release.",
                  mechanic: "Arrange attack, decay, sustain, and release segments.", buildNote: "Add editable envelope handles and synthesized audio playback.", visual: .soundEnvelope),
        68: .init(number: 68, title: "pendulum launch", instruction: "Pull the tethered ball left, then let it swing and release from the right edge.",
                  mechanic: "Choose the pull angle so the automatic rightmost release sends the ball into the goal.", buildNote: "Add drag-to-pull pendulum controls, swing release physics, and goal validation.", visual: .phaseRings),
        69: .init(number: 69, title: "cosine waves", instruction: "Use the wave's peak, rhythm, and phase to time each jump.",
                  mechanic: "Read amplitude, frequency, and phase from a moving cosine wave.", buildNote: "Retheme the updraft survival path around cosine-wave motion and timing feedback.", visual: .phaseRings),
        70: .init(number: 70, title: "chord detective", instruction: "Listen to the chord and identify the two notes that were played.",
                  mechanic: "Use pitch color, a hint arc, and a note circle to solve the chord.", buildNote: "Add chord playback, note selection, hint arcs, and launch validation.", visual: .chordCircle),
        71: .init(number: 71, title: "echo canyon", instruction: "Rotate reflectors to guide the sound pulse into the receiver.",
                  mechanic: "Use straight-line sound travel and reflection angles to solve the path.", buildNote: "Add reflector rotation, pulse tracing, and receiver validation.", visual: .echoTunnel),
        72: .init(number: 72, title: "interference pool", instruction: "Place emitters to create the target ripple pattern.",
                  mechanic: "Explore constructive and destructive wave interference.", buildNote: "Add movable wave sources and a live interference field.", visual: .interferencePool),
        73: .init(number: 73, title: "doppler dash", instruction: "Drag the sound source toward the microphone and listen as pitch rises.",
                  mechanic: "Use changing distance, compressed waves, and perceived pitch to fill the receiver.", buildNote: "Add draggable source motion, Doppler wave compression, pitch audio, and receiver progress.", visual: .waveformMixer),
        74: .init(number: 74, title: "fifths memory", instruction: "Listen to the note pattern and repeat it around the circle of fifths.",
                  mechanic: "Memorize note sequences and match them on a circle-of-fifths layout.", buildNote: "Add sequence playback, note memory input, staged difficulty, and match validation.", visual: .chordCircle)
    ]

    static let logicPreviews: [Int: MathItConceptDefinition] = [
        76: .init(number: 76, title: "switchboard", instruction: "Route power through a network of switches to illuminate a target bulb.",
                  mechanic: "Cycle switch states, test the circuit, and discover the only live path.", buildNote: "Built as a playable switch-network routing puzzle.", visual: .logicScene(76)),
        77: .init(number: 77, title: "cascade", instruction: "Trigger a chain reaction where each activated node powers the next.",
                  mechanic: "Tune local node rules so one pulse activates the whole chain.", buildNote: "Built as a playable chain-reaction systems puzzle.", visual: .logicScene(77)),
        78: .init(number: 78, title: "partial derivatives", instruction: "Change x and y independently to examine the surface in one direction at a time.",
                  mechanic: "Move one input while holding the other fixed and observe the output's directional rate of change.", buildNote: "Built as a multivariable surface exploration puzzle.", visual: .logicScene(78)),
        79: .init(number: 79, title: "insertion sort", instruction: "Build a sorted row by shifting larger cards to the right.",
                  mechanic: "Compare left, shift larger cards, then insert the active card.", buildNote: "Built as a playing-card insertion sort puzzle.", visual: .logicScene(79)),
        80: .init(number: 80, title: "no contact", instruction: "Place dots so none share a row, column, or touching diagonal.",
                  mechanic: "Use row, column, and adjacency constraints to build safe dot configurations.", buildNote: "Built as a staged coordinate-grid placement puzzle.", visual: .logicScene(80)),
        81: .init(number: 81, title: "paint with numbers", instruction: "Connect matching numbered dots with non-overlapping paths that fill the grid.",
                  mechanic: "Draw adjacent graph paths while avoiding crossings and gaps.", buildNote: "Built as a full-board numbered path puzzle.", visual: .logicScene(81)),
        82: .init(number: 82, title: "river crossing", instruction: "Move wolf, goat, and cabbage across without leaving unsafe pairs alone.",
                  mechanic: "Plan state transitions while avoiding forbidden shore states.", buildNote: "Built as a visual river-crossing constraint puzzle.", visual: .logicScene(82)),
        83: .init(number: 83, title: "reservoir", instruction: "Use the 5L and 3L jugs to measure exactly 4 liters.",
                  mechanic: "Fill, pour, and empty jugs until the 5L jug holds 4L.", buildNote: "Built as a neon reservoir jug-measuring puzzle.", visual: .logicScene(83)),
        84: .init(number: 84, title: "deadlock", instruction: "Break the wait cycle so every process can finish.", mechanic: "Change waits, holds, releases, and swaps in a resource graph.", buildNote: "Built as a wait-graph cycle breaker.", visual: .logicScene(84)),
        85: .init(number: 85, title: "signal", instruction: "Transmit a pulse through repeaters without degrading the message.", mechanic: "Tune repeater strength through a chain.", buildNote: "Built as a signal-integrity relay puzzle.", visual: .logicScene(85)),
        86: .init(number: 86, title: "hive", instruction: "Use local rules to guide a swarm toward a shared target.", mechanic: "Tune align, avoid, and seek behavior.", buildNote: "Built as an emergent-agent puzzle.", visual: .logicScene(86)),
        87: .init(number: 87, title: "firewall", instruction: "Let safe packets through while blocking harmful ones.", mechanic: "Choose allow, block, inspect, and quarantine rules.", buildNote: "Built as a layered packet-filter puzzle.", visual: .logicScene(87)),
        88: .init(number: 88, title: "queue", instruction: "Manage requests before the system overloads.", mechanic: "Balance intake, service, and buffer capacity.", buildNote: "Built as a queue-stability puzzle.", visual: .logicScene(88)),
        89: .init(number: 89, title: "elevator", instruction: "Optimize elevator routes using minimal movement.", mechanic: "Assign stops and express movement.", buildNote: "Built as a dispatch optimization puzzle.", visual: .logicScene(89)),
        90: .init(number: 90, title: "clockwork", instruction: "Align gears that rotate at different rates.", mechanic: "Set gear phases to a shared alignment.", buildNote: "Built as a modular-cycle puzzle.", visual: .logicScene(90)),
        91: .init(number: 91, title: "market", instruction: "Balance regional resource flow to avoid shortages and surpluses.", mechanic: "Tune import, export, storage, and consumption.", buildNote: "Built as a network-flow economy puzzle.", visual: .logicScene(91)),
        92: .init(number: 92, title: "voting", instruction: "Balance group influence into a stable decision.", mechanic: "Set coalition weights around a majority threshold.", buildNote: "Built as a stable-vote puzzle.", visual: .logicScene(92)),
        93: .init(number: 93, title: "ecosystem", instruction: "Keep predators, prey, and resources in balance.", mechanic: "Adjust population levels without collapsing the triangle.", buildNote: "Built as an ecological feedback puzzle.", visual: .logicScene(93)),
        94: .init(number: 94, title: "factory", instruction: "Build an efficient production line from inputs to outputs.", mechanic: "Tune feed, transform, inspect, and ship stations.", buildNote: "Built as a production-throughput puzzle.", visual: .logicScene(94)),
        95: .init(number: 95, title: "internet", instruction: "Reroute data around failed nodes while staying connected.", mechanic: "Choose backup links, mirrors, and exits.", buildNote: "Built as a fault-tolerant network puzzle.", visual: .logicScene(95)),
        96: .init(number: 96, title: "ant colony", instruction: "Use pheromone trails to discover the shortest path.", mechanic: "Strengthen successful trails and fade weaker routes.", buildNote: "Built as a pheromone-optimization puzzle.", visual: .logicScene(96)),
        97: .init(number: 97, title: "language", instruction: "Build a grammar that interprets messages correctly.", mechanic: "Choose productions for a clean parse tree.", buildNote: "Built as a grammar-parse puzzle.", visual: .logicScene(97)),
        98: .init(number: 98, title: "operating system", instruction: "Allocate processing power among competing tasks.", mechanic: "Balance CPU, memory, IO, and priority.", buildNote: "Built as an OS resource-allocation puzzle.", visual: .logicScene(98)),
        99: .init(number: 99, title: "emergence", instruction: "Create complex behavior from a few simple rules.", mechanic: "Tune local birth, survival, and drift rules.", buildNote: "Built as a cellular emergence puzzle.", visual: .logicScene(99)),
        100: .init(number: 100, title: "civilization", instruction: "Sustain water, food, energy, and transport indefinitely.", mechanic: "Balance linked infrastructure loops.", buildNote: "Built as an interconnected systems puzzle.", visual: .logicScene(100))
    ]
}

struct MathItConceptPreviewView: View {
    @Environment(\.mathItAccent) private var accent

    let concept: MathItConceptDefinition
    let onContinue: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    conceptVisual
                        .frame(height: min(330, proxy.size.height * 0.4))
                    instructionCard
                    buildCard
                    navigation
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 34)
                .frame(minHeight: proxy.size.height)
            }
            .background(Color.black)
            .overlay(alignment: .topLeading) {
                HomeButton(action: onLevelSelect)
                    .padding(.leading, 10)
                    .padding(.top, 14)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("LEVEL \(concept.number)  •  CONCEPT PREVIEW")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(accent)

            Text(concept.title)
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("NOT YET PLAYABLE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accent, in: Capsule())
        }
        .padding(.horizontal, 48)
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("PLAYER INSTRUCTION")
            Text(concept.instruction)
                .font(.system(size: 21, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(3)

            Divider().overlay(accent.opacity(0.34))

            label("INTENDED INTERACTION")
            Text(concept.mechanic)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(4)
        }
        .conceptCard(accent: accent)
    }

    private var buildCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("BUILD LATER")
            Text(concept.buildNote)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(accent.opacity(0.86))
                .lineSpacing(3)
        }
        .conceptCard(accent: accent)
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            Button("LEVELS", action: onLevelSelect)
                .conceptButton(accent: accent, filled: false)
            Button("NEXT CONCEPT", action: onContinue)
                .conceptButton(accent: accent, filled: true)
        }
        .padding(.top, 4)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(accent.opacity(0.72))
    }

    @ViewBuilder
    private var conceptVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(accent.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accent.opacity(0.38), lineWidth: 1.2)
                }

            switch concept.visual {
            case .functionMachine:
                functionMachine
            case .percentMarket:
                percentMarket
            case .exponentTower:
                exponentTower
            case .equationPaths:
                equationPaths
            case .sequenceGarden:
                sequenceGarden
            case .probabilityLab:
                probabilityLab
            case .inequalityGate:
                inequalityGate
            case .decimalOrbit:
                decimalOrbit
            case .polynomialBlocks:
                polynomialBlocks
            case .rateRace:
                rateRace
            case .symmetryStudio:
                geometrySymbol("circle.hexagongrid.fill", secondary: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            case .tessellationFloor:
                tessellationFloor
            case .crossSectionScanner:
                geometrySymbol("cube.transparent", secondary: "rectangle.split.3x1")
            case .transformationMap:
                geometrySymbol("rotate.right", secondary: "arrow.up.left.and.arrow.down.right")
            case .areaArchitect:
                areaArchitect
            case .coordinateNavigator:
                coordinateNavigator
            case .netWorkshop:
                geometrySymbol("square.grid.3x3.square", secondary: "cube")
            case .perspectiveGrid:
                perspectiveGrid
            case .locusBeacon:
                locusBeacon
            case .scaleCity:
                scaleCity
            case .packingCrates:
                packingCrates
            case .waveformMixer:
                waveformMixer
            case .beatGrid:
                beatGrid
            case .phaseRings:
                phaseRings
            case .soundEnvelope:
                soundEnvelope
            case .spectrumBars:
                spectrumBars
            case .chordCircle:
                chordCircle
            case .echoTunnel:
                echoTunnel
            case .interferencePool:
                interferencePool
            case .networkGraph:
                networkGraph
            case .stateMachine:
                stateMachine
            case .sortingFlow:
                sortingFlow
            case .systemGrid:
                systemGrid
            case .logicScene(let number):
                logicScene(number)
            }
        }
    }

    private var functionMachine: some View {
        HStack(spacing: 18) {
            conceptToken("4")
            Image(systemName: "arrow.right")
            VStack(spacing: 8) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 52))
                Text("× 3 − 1").font(.system(.title3, design: .monospaced))
            }
            .foregroundStyle(accent)
            .padding(22)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent, lineWidth: 2))
            Image(systemName: "arrow.right")
            conceptToken("?")
        }
        .foregroundStyle(accent)
    }

    private var percentMarket: some View {
        HStack(spacing: 22) {
            VStack(spacing: 10) {
                Image(systemName: "headphones")
                    .font(.system(size: 64, weight: .light))
                Text("$80").font(.system(.title2, design: .monospaced))
            }
            Image(systemName: "arrow.right").foregroundStyle(accent)
            VStack(spacing: 12) {
                Text("25% OFF")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(12)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8))
                Text("$ ?").font(.system(size: 34, design: .monospaced))
            }
        }
        .foregroundStyle(.white)
    }

    private var exponentTower: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ForEach([(2, "2²"), (4, "2⁴"), (6, "2⁶"), (8, "?")], id: \.0) { height, text in
                VStack {
                    Text(text).font(.system(.headline, design: .monospaced)).foregroundStyle(accent)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(accent.opacity(0.18 + Double(height) * 0.04))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(accent.opacity(0.72)))
                        .frame(width: 48, height: CGFloat(height * 22))
                }
            }
        }
    }

    private var equationPaths: some View {
        VStack(spacing: 24) {
            HStack(spacing: 18) {
                conceptToken("x + 4")
                Text("× 2").conceptGate(accent)
                Text("− 3").conceptGate(accent)
            }
            Text("=").font(.system(size: 34, design: .serif)).foregroundStyle(accent)
            HStack(spacing: 18) {
                conceptToken("3x")
                Text("+ 5").conceptGate(accent)
                Text("?").conceptGate(accent)
            }
        }
    }

    private var sequenceGarden: some View {
        HStack(alignment: .bottom, spacing: 18) {
            ForEach(Array(["2", "5", "8", "?", "14"].enumerated()), id: \.offset) { index, value in
                VStack(spacing: 5) {
                    Image(systemName: index == 3 ? "questionmark.circle" : "leaf.fill")
                        .font(.system(size: 20 + CGFloat(index * 7)))
                        .foregroundStyle(accent.opacity(0.55 + Double(index) * 0.09))
                    Capsule().fill(accent.opacity(0.55)).frame(width: 3, height: 24 + CGFloat(index * 12))
                    Text(value).font(.system(.headline, design: .monospaced)).foregroundStyle(.white)
                }
            }
        }
    }

    private var probabilityLab: some View {
        HStack(spacing: 32) {
            ZStack {
                Circle().stroke(accent.opacity(0.4), lineWidth: 2).frame(width: 150, height: 150)
                ForEach(0..<8) { index in
                    Circle()
                        .fill(index < 3 ? accent : .white.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .offset(x: cos(Double(index) * .pi / 4) * 48, y: sin(Double(index) * .pi / 4) * 48)
                }
            }
            VStack(spacing: 8) {
                Text("TARGET").foregroundStyle(accent.opacity(0.7))
                Text("3 / 8").font(.system(size: 38, design: .serif)).foregroundStyle(.white)
            }
        }
    }

    private var inequalityGate: some View {
        HStack(spacing: 18) {
            VStack(spacing: 8) {
                ForEach(0..<4) { _ in Circle().fill(accent).frame(width: 22, height: 22) }
            }
            Text("?")
                .font(.system(size: 64, weight: .thin, design: .serif))
                .foregroundStyle(accent)
                .frame(width: 90, height: 120)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent, style: StrokeStyle(lineWidth: 2, dash: [7])))
            VStack(spacing: 8) {
                ForEach(0..<6) { _ in Circle().fill(.white.opacity(0.7)).frame(width: 22, height: 22) }
            }
        }
    }

    private var decimalOrbit: some View {
        ZStack {
            ForEach([70.0, 120.0, 170.0], id: \.self) { diameter in
                Circle().stroke(accent.opacity(0.22), lineWidth: 1).frame(width: diameter, height: diameter)
            }
            conceptToken("0")
            conceptToken("0.5").offset(x: 84)
            conceptToken("3/4").offset(x: -54, y: -66)
            conceptToken("?").offset(x: 10, y: 112)
        }
    }

    private var polynomialBlocks: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6).fill(accent.opacity(0.65)).frame(width: 104, height: 104)
                Text("x²").foregroundStyle(.black)
            }
            VStack(spacing: 8) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(accent.opacity(0.42)).frame(width: 34, height: 76)
                }
                Text("3x").foregroundStyle(accent)
            }
            VStack(spacing: 6) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.62)).frame(width: 27, height: 27)
                }
                Text("+4").foregroundStyle(.white)
            }
        }
        .font(.system(.headline, design: .monospaced))
    }

    private var rateRace: some View {
        VStack(spacing: 22) {
            ForEach(Array([("3 mph", 0.42), ("5 mph", 0.68), ("? mph", 0.84)].enumerated()), id: \.offset) { index, lane in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1)).frame(height: 3)
                        Image(systemName: "figure.run")
                            .font(.system(size: 28))
                            .foregroundStyle(index == 2 ? accent : .white.opacity(0.68))
                            .offset(x: (proxy.size.width - 36) * lane.1)
                        Text(lane.0)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(accent)
                            .offset(y: -20)
                    }
                }
                .frame(height: 32)
            }
        }
        .padding(.horizontal, 26)
    }

    private func geometrySymbol(_ primary: String, secondary: String) -> some View {
        HStack(spacing: 34) {
            Image(systemName: primary)
                .font(.system(size: 90, weight: .ultraLight))
            Image(systemName: "arrow.right")
                .font(.system(size: 28))
            Image(systemName: secondary)
                .font(.system(size: 72, weight: .ultraLight))
        }
        .foregroundStyle(accent)
        .shadow(color: accent.opacity(0.35), radius: 12)
    }

    private var tessellationFloor: some View {
        VStack(spacing: 2) {
            ForEach(0..<4) { row in
                HStack(spacing: 2) {
                    ForEach(0..<6) { column in
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 39))
                            .foregroundStyle((row + column).isMultiple(of: 3) ? accent : accent.opacity(0.28))
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? 0 : 20)
            }
        }
    }

    private var areaArchitect: some View {
        HStack(spacing: 24) {
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(accent.opacity(0.25)).frame(width: 140, height: 140)
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 140, y: 140))
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 2, dash: [7]))
            }
            Image(systemName: "equal").foregroundStyle(accent)
            HStack(spacing: 2) {
                ForEach(0..<2) { _ in
                    TriangleShape().fill(accent.opacity(0.45)).frame(width: 90, height: 140)
                }
            }
        }
    }

    private var coordinateNavigator: some View {
        ZStack {
            ConceptGrid().stroke(accent.opacity(0.18), lineWidth: 1)
            Path { path in
                path.move(to: CGPoint(x: 45, y: 245))
                path.addLine(to: CGPoint(x: 145, y: 155))
                path.addLine(to: CGPoint(x: 255, y: 195))
                path.addLine(to: CGPoint(x: 310, y: 70))
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            Image(systemName: "location.north.fill").font(.system(size: 32)).foregroundStyle(.white)
        }
        .padding(28)
    }

    private var perspectiveGrid: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.36)
            ZStack {
                ForEach(0..<9) { index in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(x: CGFloat(index) * proxy.size.width / 8, y: proxy.size.height))
                    }
                    .stroke(accent.opacity(0.35), lineWidth: 1)
                }
                Circle().fill(accent).frame(width: 12, height: 12).position(center)
                Image(systemName: "building.2").font(.system(size: 90)).foregroundStyle(.white.opacity(0.65)).offset(y: 48)
            }
        }
        .padding(20)
    }

    private var locusBeacon: some View {
        ZStack {
            ForEach([80.0, 140.0, 210.0], id: \.self) { size in
                Circle().stroke(accent.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6])).frame(width: size, height: size)
            }
            Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 58)).foregroundStyle(accent)
            Circle().fill(.white).frame(width: 14, height: 14).offset(x: 104)
        }
    }

    private var scaleCity: some View {
        HStack(alignment: .bottom, spacing: 24) {
            ForEach([(42.0, 72.0), (62.0, 118.0), (84.0, 170.0)], id: \.0) { size in
                RoundedRectangle(cornerRadius: 4)
                    .fill(accent.opacity(size.0 / 120))
                    .overlay {
                        VStack(spacing: 8) {
                            ForEach(0..<3) { _ in Capsule().fill(.black.opacity(0.55)).frame(width: size.0 * 0.5, height: 4) }
                        }
                    }
                    .frame(width: size.0, height: size.1)
            }
        }
    }

    private var packingCrates: some View {
        HStack(spacing: 18) {
            ForEach(0..<3) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.7), lineWidth: 2)
                    VStack(spacing: 5) {
                        ForEach(0..<(index + 2), id: \.self) { _ in
                            HStack(spacing: 5) {
                                ForEach(0..<(index + 2), id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.35 + Double(index) * 0.18))
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(width: 80 + CGFloat(index * 18), height: 90 + CGFloat(index * 18))
            }
        }
    }

    private var waveformMixer: some View {
        VStack(spacing: 22) {
            ForEach(Array([1.0, 1.8, 2.7].enumerated()), id: \.offset) { index, frequency in
                WaveformShape(frequency: frequency, phase: Double(index) * 0.7)
                    .stroke(index == 2 ? accent : accent.opacity(0.34), lineWidth: index == 2 ? 3 : 1.5)
                    .frame(height: 54)
            }
        }
        .padding(.horizontal, 26)
    }

    private var beatGrid: some View {
        VStack(spacing: 22) {
            ForEach(0..<3) { row in
                HStack(spacing: 14) {
                    ForEach(0..<8) { beat in
                        Circle()
                            .fill(beat.isMultiple(of: row + 2) ? accent : .white.opacity(0.14))
                            .frame(width: 22, height: 22)
                            .shadow(color: beat.isMultiple(of: row + 2) ? accent.opacity(0.6) : .clear, radius: 7)
                    }
                }
            }
        }
    }

    private var phaseRings: some View {
        ZStack {
            ForEach(0..<3) { ring in
                Circle()
                    .trim(from: 0.08 * CGFloat(ring), to: 0.72 + 0.08 * CGFloat(ring))
                    .stroke(accent.opacity(0.35 + Double(ring) * 0.22), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 90 + CGFloat(ring * 60), height: 90 + CGFloat(ring * 60))
                    .rotationEffect(.degrees(Double(ring * 55)))
            }
            Circle().fill(.white).frame(width: 14, height: 14)
        }
    }

    private var soundEnvelope: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 20, y: proxy.size.height - 30))
                path.addLine(to: CGPoint(x: proxy.size.width * 0.24, y: 28))
                path.addLine(to: CGPoint(x: proxy.size.width * 0.42, y: proxy.size.height * 0.44))
                path.addLine(to: CGPoint(x: proxy.size.width * 0.72, y: proxy.size.height * 0.44))
                path.addLine(to: CGPoint(x: proxy.size.width - 20, y: proxy.size.height - 30))
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .padding(34)
    }

    private var spectrumBars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach([42, 78, 126, 188, 150, 98, 64, 116, 48], id: \.self) { height in
                Capsule()
                    .fill(accent.opacity(0.25 + Double(height) / 260))
                    .frame(width: 18, height: CGFloat(height))
            }
        }
    }

    private var chordCircle: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.25), lineWidth: 2).frame(width: 220, height: 220)
            ForEach(0..<12) { note in
                Text(["C", "G", "D", "A", "E", "B", "F♯", "D♭", "A♭", "E♭", "B♭", "F"][note])
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle([0, 4, 8].contains(note) ? accent : .white.opacity(0.46))
                    .offset(x: cos(Double(note) * .pi / 6 - .pi / 2) * 100,
                            y: sin(Double(note) * .pi / 6 - .pi / 2) * 100)
            }
            TriangleShape().stroke(accent, lineWidth: 2).frame(width: 140, height: 140)
        }
    }

    private var echoTunnel: some View {
        ZStack {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent.opacity(0.18 + Double(index) * 0.12), lineWidth: 2)
                    .frame(width: 260 - CGFloat(index * 35), height: 200 - CGFloat(index * 28))
            }
            Image(systemName: "waveform").font(.system(size: 52)).foregroundStyle(accent)
        }
    }

    private var interferencePool: some View {
        ZStack {
            ForEach([CGPoint(x: -65, y: 0), CGPoint(x: 65, y: 0)], id: \.x) { source in
                ForEach([50.0, 95.0, 140.0, 185.0], id: \.self) { diameter in
                    Circle()
                        .stroke(accent.opacity(0.22), lineWidth: 1.5)
                        .frame(width: diameter, height: diameter)
                        .offset(x: source.x, y: source.y)
                }
                Circle().fill(accent).frame(width: 10, height: 10).offset(x: source.x)
            }
        }
    }

    private var networkGraph: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 45, y: 160)); path.addLine(to: CGPoint(x: 145, y: 70))
                path.addLine(to: CGPoint(x: 275, y: 105)); path.addLine(to: CGPoint(x: 340, y: 205))
                path.move(to: CGPoint(x: 45, y: 160)); path.addLine(to: CGPoint(x: 165, y: 245))
                path.addLine(to: CGPoint(x: 340, y: 205)); path.move(to: CGPoint(x: 145, y: 70)); path.addLine(to: CGPoint(x: 165, y: 245))
            }.stroke(accent.opacity(0.6), lineWidth: 2)
            ForEach([CGPoint(x: 45, y: 160), CGPoint(x: 145, y: 70), CGPoint(x: 275, y: 105), CGPoint(x: 165, y: 245), CGPoint(x: 340, y: 205)], id: \.x) {
                Circle().fill(accent).frame(width: 24, height: 24).position($0)
            }
        }.frame(width: 390, height: 300)
    }

    private var stateMachine: some View {
        HStack(spacing: 22) {
            ForEach(Array(["START", "CHECK", "ACCEPT"].enumerated()), id: \.offset) { index, text in
                HStack(spacing: 16) {
                    Text(text).font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(index == 2 ? .black : accent).padding(14)
                        .background(index == 2 ? accent : .clear, in: Circle())
                        .overlay(Circle().stroke(accent, lineWidth: 2)).frame(width: 82, height: 82)
                    if index < 2 { Image(systemName: "arrow.right").foregroundStyle(accent) }
                }
            }
        }
    }

    private var sortingFlow: some View {
        VStack(spacing: 18) {
            HStack(spacing: 22) { ForEach(["8", "3", "6", "1"], id: \.self) { conceptToken($0) } }
            HStack(spacing: 30) { Image(systemName: "arrow.down.right.and.arrow.up.left"); Image(systemName: "arrow.down.left.and.arrow.up.right") }
                .font(.system(size: 38)).foregroundStyle(accent)
            HStack(spacing: 22) { ForEach(["1", "3", "6", "8"], id: \.self) { conceptToken($0) } }
        }
    }

    private var systemGrid: some View {
        VStack(spacing: 5) {
            ForEach(0..<6) { row in
                HStack(spacing: 5) {
                    ForEach(0..<8) { column in
                        RoundedRectangle(cornerRadius: 3)
                            .fill((row + column * 2).isMultiple(of: 5) ? accent : accent.opacity(0.12))
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func logicScene(_ number: Int) -> some View {
        switch number {
        case 76:
            ZStack {
                previewLink(from: CGPoint(x: -130, y: 10), to: CGPoint(x: -54, y: -58), active: true)
                previewLink(from: CGPoint(x: -54, y: -58), to: CGPoint(x: 44, y: -30), active: true)
                previewLink(from: CGPoint(x: 44, y: -30), to: CGPoint(x: 132, y: 0), active: true)
                previewLink(from: CGPoint(x: -54, y: 70), to: CGPoint(x: 44, y: -30), active: false)
                previewLink(from: CGPoint(x: -130, y: 10), to: CGPoint(x: -54, y: 70), active: false)
                previewNode("PWR", x: -130, y: 10, active: true)
                previewNode("A", x: -54, y: -58, active: true)
                previewNode("B", x: -54, y: 70, active: false)
                previewNode("C", x: 44, y: -30, active: true)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.55), radius: 14)
                    .offset(x: 132, y: 0)
            }
            .frame(width: 360, height: 250)
        case 77:
            VStack(spacing: 18) {
                HStack(spacing: 13) {
                    ForEach(0..<5) { index in
                        previewNode("\(index + 1)", active: index < 4)
                        if index != 4 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(index < 3 ? accent : .white.opacity(0.2))
                        }
                    }
                }
                HStack(spacing: 18) {
                    Text("PASS").conceptGate(accent)
                    Text("DELAY").conceptGate(accent)
                    Text("SPLIT").conceptGate(accent)
                }
                Text("ONE PULSE POWERS THE CHAIN")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
            }
        case 78:
            ZStack {
                Rectangle().fill(.white.opacity(0.1)).frame(width: 300, height: 76)
                Rectangle().fill(.white.opacity(0.1)).frame(width: 76, height: 260)
                ForEach([CGPoint(x: 0, y: -82), CGPoint(x: 92, y: 0), CGPoint(x: 0, y: 82), CGPoint(x: -92, y: 0)], id: \.x) { point in
                    VStack(spacing: 3) {
                        Circle().fill(point.y == 0 ? .white.opacity(0.15) : accent)
                        Circle().fill(point.x == 92 ? accent : .white.opacity(0.15))
                        Circle().fill(point.x == -92 ? accent.opacity(0.5) : .white.opacity(0.15))
                    }
                    .frame(width: 18, height: 58)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    .offset(x: point.x, y: point.y)
                }
                Image(systemName: "car.fill").foregroundStyle(.white).offset(x: -116)
                Image(systemName: "bus.fill").foregroundStyle(accent).rotationEffect(.degrees(90)).offset(y: -104)
            }
        case 79:
            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    Circle()
                        .stroke(.white.opacity(0.12 + Double(ring) * 0.04), lineWidth: 1)
                        .frame(width: CGFloat(ring) * 42, height: CGFloat(ring) * 42)
                }
                ForEach(0..<8, id: \.self) { spoke in
                    Rectangle()
                        .fill(.white.opacity(0.13))
                        .frame(width: 176, height: 1)
                        .rotationEffect(.degrees(Double(spoke) * 22.5))
                }
                Circle().fill(.white).frame(width: 42, height: 42)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                Image(systemName: "fish.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
                    .offset(x: 65, y: -52)
            }
        case 80:
            ParametricButterflyPreview(accent: accent)
                .frame(width: 250, height: 250)
        case 81:
            ZStack {
                previewLink(from: CGPoint(x: -130, y: 0), to: CGPoint(x: -45, y: -58), active: false)
                previewLink(from: CGPoint(x: -130, y: 0), to: CGPoint(x: -45, y: 58), active: true)
                previewLink(from: CGPoint(x: -45, y: 58), to: CGPoint(x: 55, y: 44), active: true)
                previewLink(from: CGPoint(x: 55, y: 44), to: CGPoint(x: 135, y: 0), active: true)
                previewLink(from: CGPoint(x: -45, y: -58), to: CGPoint(x: 55, y: -44), active: false)
                previewNode("S", x: -130, y: 0, active: true)
                previewNode("1", x: -45, y: -58, active: false)
                previewNode("2", x: -45, y: 58, active: true)
                previewNode("3", x: 55, y: 44, active: true)
                previewNode("G", x: 135, y: 0, active: true)
            }
            .frame(width: 360, height: 250)
        case 82:
            VStack(spacing: 16) {
                ForEach(Array(["RED", "BLUE", "GREEN"].enumerated()), id: \.offset) { index, label in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1)).frame(width: 260, height: 26)
                        Capsule().fill(accent.opacity(index == 0 ? 0.9 : 0.35)).frame(width: CGFloat(220 - index * 54), height: 26)
                        Text(label)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.leading, 10)
                    }
                }
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(accent)
            }
        case 83:
            HStack(spacing: 18) {
                ForEach(["A", "B", "C", "D"], id: \.self) { label in
                    ZStack {
                        Circle().stroke(accent.opacity(0.75), lineWidth: 3).frame(width: 70, height: 70)
                        Capsule().fill(accent).frame(width: 5, height: 34).offset(y: -17)
                        Text(label).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.white).offset(y: 44)
                    }
                }
            }
        case 84:
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .frame(width: 82, height: 82)
                    .offset(x: 88, y: -45)
                ForEach(0..<32, id: \.self) { index in
                    let angle = Double(index) * 0.58
                    let radius = 22 + Double(index % 8) * 8
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(index.isMultiple(of: 6) ? accent : .white.opacity(0.82))
                        .rotationEffect(.degrees(-24 + Double(index % 5) * 4))
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius * 0.62)
                }
            }
        case 85:
            HStack(spacing: 12) {
                ForEach(0..<4) { index in
                    Circle().fill(accent.opacity(index == 1 ? 1 : 0.45)).frame(width: CGFloat(30 + index * 5), height: CGFloat(30 + index * 5))
                    if index != 3 {
                        Image(systemName: "arrow.right").foregroundStyle(accent.opacity(0.6))
                    }
                }
            }
        case 86:
            ZStack {
                ForEach(0..<96) { index in
                    let column = Double(index % 12)
                    let row = Double(index / 12)
                    Capsule()
                        .fill(index.isMultiple(of: 3) ? accent.opacity(0.85) : .white.opacity(0.2))
                        .frame(width: 4, height: 12)
                        .rotationEffect(.degrees(index.isMultiple(of: 3) ? 42 : Double((index * 17) % 180)))
                        .offset(x: -150 + column * 27, y: -95 + row * 27)
                }
                previewNode("HIVE", x: 108, y: 82, active: true)
            }
        case 87:
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    ForEach(0..<7) { index in
                        Capsule().fill(index.isMultiple(of: 3) ? .red.opacity(0.45) : accent.opacity(0.58)).frame(width: 62, height: 12)
                    }
                }
                Rectangle().fill(accent).frame(width: 6, height: 176)
                VStack(spacing: 18) {
                    Image(systemName: "checkmark.shield.fill")
                    Image(systemName: "xmark.shield.fill")
                    Image(systemName: "checkmark.shield.fill")
                }
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(accent)
            }
        case 88:
            VStack(spacing: 18) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<12) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index < 8 ? accent.opacity(0.78) : .red.opacity(0.4))
                            .frame(width: 17, height: CGFloat(22 + index % 4 * 8))
                    }
                }
                Capsule().fill(accent).frame(width: 220, height: 8)
                Text("SERVICE >= ARRIVAL")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
            }
        case 89:
            HStack(alignment: .bottom, spacing: 18) {
                ForEach(["A", "B", "X"], id: \.self) { label in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.18), lineWidth: 2).frame(width: 46, height: 190)
                        RoundedRectangle(cornerRadius: 5).fill(accent).frame(width: 34, height: 34).offset(y: label == "A" ? -34 : label == "B" ? -112 : -150)
                        Text(label).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.black).offset(y: label == "A" ? -43 : label == "B" ? -121 : -159)
                    }
                }
            }
        case 90:
            HStack(spacing: -10) {
                ForEach(0..<4) { index in
                    ZStack {
                        Circle().stroke(accent.opacity(0.8), lineWidth: 4).frame(width: 78, height: 78)
                        ForEach(0..<8) { tooth in
                            Capsule().fill(accent.opacity(0.72)).frame(width: 5, height: 13).offset(y: -38).rotationEffect(.degrees(Double(tooth * 45 + index * 13)))
                        }
                        Capsule().fill(.white).frame(width: 4, height: 28).offset(y: -14)
                    }
                }
            }
        case 91:
            ZStack {
                ForEach(0..<4) { index in
                    previewLink(from: CGPoint(x: cos(Double(index) * .pi / 2) * 120, y: sin(Double(index) * .pi / 2) * 86), to: .zero, active: true)
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4).fill(accent).frame(width: 32, height: CGFloat(34 + index * 8))
                        Text(["N", "E", "S", "W"][index]).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                    }
                    .offset(x: cos(Double(index) * .pi / 2) * 120, y: sin(Double(index) * .pi / 2) * 86)
                }
                previewNode("BAL", active: true)
            }
        case 92:
            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 16) {
                    ForEach(Array(["LABOR", "TRADE", "SCI"].enumerated()), id: \.offset) { index, label in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 6).fill(accent.opacity(0.55 + Double(index) * 0.14)).frame(width: 48, height: CGFloat(52 + index * 18))
                            Text(label).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.68))
                        }
                    }
                }
                Capsule().fill(accent).frame(width: 210, height: 8)
            }
        case 93:
            ZStack {
                previewLink(from: CGPoint(x: 0, y: -92), to: CGPoint(x: -112, y: 82), active: true)
                previewLink(from: CGPoint(x: -112, y: 82), to: CGPoint(x: 112, y: 82), active: true)
                previewLink(from: CGPoint(x: 112, y: 82), to: CGPoint(x: 0, y: -92), active: true)
                previewNode("PREY", x: 0, y: -92, active: true)
                previewNode("PRED", x: -112, y: 82, active: true)
                previewNode("FOOD", x: 112, y: 82, active: true)
            }
            .frame(width: 320, height: 240)
        case 94:
            HStack(spacing: 10) {
                ForEach(Array(["FEED", "MAKE", "TEST", "SHIP"].enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(index == 2 ? .black : accent)
                        .frame(width: 58, height: 52)
                        .background(index == 2 ? accent : accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    if index != 3 {
                        Image(systemName: "arrow.right").foregroundStyle(accent.opacity(0.65))
                    }
                }
            }
        case 95:
            ZStack {
                previewLink(from: CGPoint(x: -130, y: -55), to: CGPoint(x: -45, y: -70), active: true)
                previewLink(from: CGPoint(x: -45, y: -70), to: CGPoint(x: 44, y: -58), active: false)
                previewLink(from: CGPoint(x: -130, y: -55), to: CGPoint(x: -58, y: 45), active: true)
                previewLink(from: CGPoint(x: -58, y: 45), to: CGPoint(x: 48, y: 58), active: true)
                previewLink(from: CGPoint(x: 48, y: 58), to: CGPoint(x: 132, y: -10), active: true)
                previewNode("S", x: -130, y: -55, active: true)
                previewNode("X", x: 44, y: -58, active: false)
                previewNode("G", x: 132, y: -10, active: true)
            }
            .frame(width: 360, height: 250)
        case 96:
            ZStack {
                previewLink(from: CGPoint(x: -132, y: 76), to: CGPoint(x: -48, y: 22), active: true)
                previewLink(from: CGPoint(x: -48, y: 22), to: CGPoint(x: 12, y: -26), active: true)
                previewLink(from: CGPoint(x: 12, y: -26), to: CGPoint(x: 120, y: -76), active: true)
                ForEach(0..<22) { index in
                    Capsule().fill(index.isMultiple(of: 3) ? accent : .white.opacity(0.2)).frame(width: 5, height: 12).rotationEffect(.degrees(48)).offset(x: -126 + Double(index % 8) * 32, y: 66 - Double(index / 8) * 48)
                }
                previewNode("FOOD", x: 125, y: -76, active: true)
            }
            .frame(width: 340, height: 240)
        case 97:
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    ForEach(["NOUN", "VERB", "OBJ", "STOP"], id: \.self) { label in
                        Text(label).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.black).frame(width: 58, height: 32).background(accent, in: RoundedRectangle(cornerRadius: 7))
                    }
                }
                ZStack {
                    previewLink(from: CGPoint(x: 0, y: -42), to: CGPoint(x: -100, y: 72), active: true)
                    previewLink(from: CGPoint(x: 0, y: -42), to: CGPoint(x: 0, y: 72), active: true)
                    previewLink(from: CGPoint(x: 0, y: -42), to: CGPoint(x: 100, y: 72), active: true)
                    previewNode("PARSE", x: 0, y: -42, active: true)
                }
                .frame(width: 280, height: 130)
            }
        case 98:
            VStack(spacing: 13) {
                ForEach(Array(["CPU", "MEM", "IO", "PRI"].enumerated()), id: \.offset) { index, label in
                    HStack(spacing: 10) {
                        Text(label).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).frame(width: 42, alignment: .trailing)
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.1)).frame(width: 220, height: 24)
                            Capsule().fill(accent.opacity(0.52 + Double(index) * 0.11)).frame(width: CGFloat(90 + index * 36), height: 24)
                        }
                    }
                }
                Image(systemName: "cpu.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(accent)
            }
        case 99:
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, dash: [7, 8]))
                    .frame(width: 230, height: 150)
                Image(systemName: "ellipsis")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white.opacity(0.24))
            }
        case 100:
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .stroke(accent.opacity(0.34), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                        .frame(width: 58, height: 58)
                        .offset(
                            x: cos(Double(index) * .pi * 2 / 5) * 92,
                            y: sin(Double(index) * .pi * 2 / 5) * 62
                        )
                }
                ForEach(0..<30, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 4) ? accent : .white.opacity(0.72))
                        .frame(width: index.isMultiple(of: 4) ? 7 : 4, height: index.isMultiple(of: 4) ? 7 : 4)
                        .offset(
                            x: cos(Double(index) * 1.7) * Double(28 + (index % 4) * 24),
                            y: sin(Double(index) * 1.7) * Double(18 + (index % 3) * 19)
                        )
                }
                Image(systemName: "ant.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(accent)
            }
        default:
            ZStack {
                ForEach(Array(["drop.fill", "leaf.fill", "bolt.fill", "tram.fill"].enumerated()), id: \.offset) { index, symbol in
                    let angle = Double(index) * .pi * 2 / 4 - .pi / 2
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 70, height: 70)
                        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .offset(x: cos(angle) * 118, y: sin(angle) * 88)
                }
                Image(systemName: "building.columns.fill").font(.system(size: 62)).foregroundStyle(.white)
            }
        }
    }

    private func previewNode(_ text: String, x: Double = 0, y: Double = 0, active: Bool) -> some View {
        Text(text)
            .font(.system(size: text.count > 3 ? 10 : 13, weight: .black, design: .monospaced))
            .foregroundStyle(active ? .black : accent)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: 58, height: 40)
            .background(active ? accent : .black.opacity(0.78), in: Capsule())
            .overlay(Capsule().stroke(accent.opacity(active ? 0.9 : 0.36), lineWidth: 1.2))
            .offset(x: x, y: y)
    }

    private func previewLink(from start: CGPoint, to end: CGPoint, active: Bool) -> some View {
        GeometryReader { proxy in
            Path { path in
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                path.move(to: CGPoint(x: center.x + start.x, y: center.y + start.y))
                path.addLine(to: CGPoint(x: center.x + end.x, y: center.y + end.y))
            }
            .stroke(active ? accent.opacity(0.78) : .white.opacity(0.18), style: StrokeStyle(lineWidth: active ? 4 : 2, lineCap: .round, dash: active ? [] : [5, 7]))
        }
    }

    private func conceptToken(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(minWidth: 48, minHeight: 48)
            .padding(.horizontal, 5)
            .background(.black, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.75), lineWidth: 1.4))
            .shadow(color: accent.opacity(0.24), radius: 8)
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct ConceptGrid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            stride(from: rect.minX, through: rect.maxX, by: 35).forEach {
                path.move(to: CGPoint(x: $0, y: rect.minY))
                path.addLine(to: CGPoint(x: $0, y: rect.maxY))
            }
            stride(from: rect.minY, through: rect.maxY, by: 35).forEach {
                path.move(to: CGPoint(x: rect.minX, y: $0))
                path.addLine(to: CGPoint(x: rect.maxX, y: $0))
            }
        }
    }
}

private struct WaveformShape: Shape {
    let frequency: Double
    let phase: Double

    func path(in rect: CGRect) -> Path {
        Path { path in
            for x in stride(from: rect.minX, through: rect.maxX, by: 2) {
                let progress = (x - rect.minX) / rect.width
                let y = rect.midY + sin(Double(progress) * .pi * 2 * frequency + phase) * rect.height * 0.38
                if x == rect.minX { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }
}

private struct ConceptMaze: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for x in stride(from: rect.minX, through: rect.maxX, by: 60) {
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY - CGFloat(Int(x) % 120)))
            }
            for y in stride(from: rect.minY, through: rect.maxY, by: 55) {
                path.move(to: CGPoint(x: rect.minX + CGFloat(Int(y) % 110), y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
    }
}

private struct ParametricButterflyPreview: View {
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.43

            for ring in 1...5 {
                let r = radius * CGFloat(ring) / 5
                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(0.12)),
                    style: StrokeStyle(lineWidth: 0.8, dash: [2, 3])
                )
            }

            for spoke in 0..<12 {
                let angle = Double(spoke) * .pi / 6
                var line = Path()
                line.move(to: center)
                line.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y - sin(angle) * radius))
                context.stroke(line, with: .color(.white.opacity(spoke.isMultiple(of: 3) ? 0.22 : 0.08)), lineWidth: 0.8)
            }

            var curve = Path()
            for sample in 0...720 {
                let t = Double(sample) / 720 * 12 * .pi
                let r = exp(cos(t)) - 2 * cos(4 * t) - pow(sin(t / 12), 5)
                let point = CGPoint(
                    x: center.x + sin(t) * r * radius / 4.75,
                    y: center.y - cos(t) * r * radius / 4.75
                )
                sample == 0 ? curve.move(to: point) : curve.addLine(to: point)
            }
            context.stroke(curve, with: .color(accent), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}

private extension View {
    func conceptCard(accent: Color) -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.3), lineWidth: 1))
    }

    func conceptButton(accent: Color, filled: Bool) -> some View {
        self
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(filled ? .black : accent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(filled ? accent : .clear, in: Capsule())
            .overlay(Capsule().stroke(accent.opacity(filled ? 0 : 0.7), lineWidth: 1.2))
    }

    func conceptGate(_ accent: Color) -> some View {
        self
            .font(.system(.headline, design: .monospaced))
            .foregroundStyle(accent)
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(accent.opacity(0.7), lineWidth: 1.2))
    }
}
