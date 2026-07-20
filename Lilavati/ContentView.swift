//
//  ContentView.swift
//  Lilavati
//
//  Created by Sahil tripurana on 5/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var screen: MathItScreen = .levelSelect
    @State private var lastGroupTitle: String? = nil   // group to reopen when leaving a level
    @State private var levelsRevealed = false          // intro seal plays once per launch
    @State private var activeHint: String?
    @State private var activeConcept: LevelConcept?
    @State private var completionOverlayActive = false
    @State private var completionConceptDismissed = false
    @ObservedObject private var levelProgress = LevelProgress.shared
    @State private var levelOneViewModel = MathItLevelOneViewModel()
    @State private var levelTwoViewModel = MathItLevelTwoViewModel()
    @State private var levelThreeViewModel = MathItLevelThreeViewModel()
    @State private var levelFourViewModel = MathItLevelFourViewModel()
    @State private var levelFiveViewModel = MathItLevelFiveViewModel()
    @State private var levelSixViewModel = MathItLevelSixViewModel()
    @State private var levelSevenViewModel = MathItLevelSevenViewModel()
    @State private var levelNineViewModel = MathItLevelNineViewModel()
    @State private var levelTenViewModel = MathItLevelTenViewModel()
    @State private var levelElevenViewModel = MathItLevelElevenViewModel()
    @State private var levelTwelveViewModel = MathItLevelTwelveViewModel()
    @State private var levelThirteenViewModel = MathItLevelThirteenViewModel()
    @State private var levelFourteenViewModel = MathItLevelFourteenViewModel()
    @State private var levelFifteenViewModel = MathItLevelFifteenViewModel()
    @State private var levelSixteenViewModel = MathItLevelSixteenViewModel()
    @State private var levelSeventeenViewModel = MathItLevelSeventeenViewModel()
    @State private var levelEighteenViewModel = MathItLevelEighteenViewModel()
    @State private var levelNineteenViewModel = MathItLevelNineteenViewModel()
    @State private var levelTwentyViewModel = MathItLevelTwentyViewModel()
    @State private var levelTwentyOneViewModel = MathItLevelTwentyOneViewModel()
    @State private var levelTwentyTwoViewModel = MathItLevelTwentyTwoViewModel()
    @State private var levelTwentyThreeViewModel = MathItLevelTwentyThreeViewModel()
    @State private var levelTwentyFourViewModel = MathItLevelTwentyFourViewModel()
    @State private var levelTwentyFiveViewModel = MathItLevelTwentyFiveViewModel()
    @State private var levelTwentySixViewModel = MathItLevelTwentySixViewModel()
    @State private var levelTwentySevenViewModel = MathItLevelTwentySevenViewModel()
    @State private var levelTwentyEightViewModel = MathItLevelTwentyEightViewModel()
    @State private var levelTwentyNineViewModel = MathItLevelTwentyNineViewModel()
    @State private var levelThirtyViewModel = MathItLevelThirtyViewModel()
    @State private var levelThirtyOneViewModel = MathItLevelThirtyOneViewModel()
    @State private var levelThirtyTwoViewModel = MathItLevelThirtyTwoViewModel()
    @State private var levelThirtyThreeViewModel = MathItLevelThirtyThreeViewModel()
    @State private var levelThirtyFourViewModel = MathItLevelThirtyFourViewModel()
    @State private var levelThirtyFiveViewModel = MathItLevelThirtyFiveViewModel()
    @State private var levelThirtySixViewModel = MathItLevelThirtySixViewModel()
    @State private var levelThirtySevenViewModel = MathItLevelThirtySevenViewModel()
    @State private var levelThirtyEightViewModel = MathItLevelThirtyEightViewModel()
    @State private var levelThirtyNineViewModel = MathItLevelThirtyNineViewModel()
    @State private var levelFortyViewModel = MathItLevelFortyViewModel()
    @State private var levelFortyOneViewModel = MathItLevelFortyOneViewModel()
    @State private var levelFortyTwoViewModel = MathItLevelThirtyThreeViewModel()
    @State private var levelFortyThreeViewModel = MathItLevelFortyThreeViewModel()
    @State private var levelFortyFourViewModel = MathItLevelFortyFourViewModel()
    @State private var levelFortyFiveViewModel = MathItLevelFortyFiveViewModel()
    @State private var levelFortySixViewModel = MathItLevelFortySixViewModel()
    @State private var levelFortySevenViewModel = MathItLevelFortySevenViewModel()
    @State private var levelFortyEightViewModel = MathItLevelFortyEightViewModel()
    @State private var levelFortyNineViewModel = MathItLevelFortyNineViewModel()
    @State private var levelFiftyViewModel = MathItLevelFiftyViewModel()
    @State private var levelFiftyOneViewModel = MathItLevelFiftyOneViewModel()
    @State private var levelFiftyTwoViewModel = MathItLevelFiftyTwoViewModel()
    @State private var levelFiftyThreeViewModel = MathItLevelFiftyThreeViewModel()
    @State private var levelFiftyFourViewModel = MathItLevelFiftyFourViewModel()
    @State private var levelFiftyFiveViewModel = MathItLevelFiftyFiveViewModel()
    @State private var levelFiftySixViewModel = MathItLevelFiftySixViewModel()
    @State private var levelFiftySevenViewModel = MathItLevelFiftySevenViewModel()
    @State private var levelFiftyEightViewModel = MathItLevelFiftyEightViewModel()
    @State private var levelFiftyNineViewModel = MathItLevelFiftyNineViewModel()
    @State private var levelSixtyViewModel = MathItLevelSixtyViewModel()
    @State private var levelSixtyOneViewModel = MathItLevelSixtyOneViewModel()
    @State private var levelOneHundredFortyThreeViewModel = MathItLevelFiftySevenViewModel()

    var body: some View {
        GeometryReader { proxy in
            let usesSharedChrome = hasSharedLevelChrome(screen)
            let contentTopInset: CGFloat = usesSharedChrome ? 118 : 0
            let contentBottomInset: CGFloat = usesSharedChrome ? 60 : 0

            ZStack {
                Color.black
                    .ignoresSafeArea()

                content
                    .padding(.top, contentTopInset)
                    .padding(.bottom, contentBottomInset)
                    .environment(\.mathItUsesSharedChrome, usesSharedChrome)
                    .environment(\.mathItLevelContentInset, contentTopInset)

                if usesSharedChrome, let chrome = levelChromeData(for: screen) {
                    LevelTopChrome(
                        levelNumber: chrome.number,
                        levelTitle: chrome.title,
                        progress: chrome.progress,
                        onHome: { returnToLevelSelect() }
                    )
                    .zIndex(850)
                }

                if let hint = hintText(for: screen) {
                    HintButton {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            activeHint = hint
                        }
                    }
                    .position(x: proxy.size.width - 34, y: 54)
                    .zIndex(900)
                }

                if let screenLevel = screenLevel(for: screen),
                   let concept = ConceptLibrary.concept(for: screenLevel) {
                    InfoButton(
                        isActive: completionOverlayActive
                            ? !completionConceptDismissed
                            : activeConcept != nil
                    ) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            activeHint = nil
                            if completionOverlayActive {
                                activeConcept = nil
                                completionConceptDismissed.toggle()
                            } else {
                                activeConcept = activeConcept == nil ? concept : nil
                            }
                        }
                    }
                    .position(x: proxy.size.width - 82, y: 54)
                    .zIndex(1_250)
                }

                if let position = curriculumPosition(for: screen) {
                    LevelStepControl(
                        levelNumber: position,
                        canGoBack: position > 1,
                        canGoForward: position < MathItCurriculum.allTopics.count,
                        onBack: { moveLevel(by: -1) },
                        onForward: { moveLevel(by: 1) }
                    )
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 28)
                    .zIndex(900)
                }

                if let activeHint {
                    HintPopup(text: activeHint) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            self.activeHint = nil
                        }
                    }
                    .zIndex(1_000)
                }

                if let activeConcept {
                    ConceptInfoOverlay(concept: activeConcept) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            self.activeConcept = nil
                        }
                    }
                    .zIndex(1_000)
                }
            }
            .environment(\.mathItAccent, screen.categoryAccent)
            .environment(\.mathItLevelNumber, levelNumber(for: screen))
            .environment(\.mathItCompletionConceptDismissed, completionConceptDismissed)
            .onPreferenceChange(MathItCompletionOverlayActiveKey.self) { isActive in
                guard completionOverlayActive != isActive else { return }
                completionOverlayActive = isActive
                completionConceptDismissed = false
                if isActive {
                    activeConcept = nil
                    activeHint = nil
                }
            }
        }
        .animation(.spring(response: 0.62, dampingFraction: 0.86), value: screen)
        .onChange(of: screen) { _, _ in
            activeConcept = nil
            activeHint = nil
            completionOverlayActive = false
            completionConceptDismissed = false
        }
    }

    private func hasSharedLevelChrome(_ screen: MathItScreen) -> Bool {
        levelNumber(for: screen) != nil
    }

    private func levelChromeData(for screen: MathItScreen) -> (number: Int, title: String, progress: Double)? {
        guard let level = levelNumber(for: screen) else { return nil }
        let screenLevel = screenLevel(for: screen) ?? level
        // The name shown at the top of a level is its curriculum topic (the math
        // concept on the homepage). Bonus entries are their own game names, so those
        // still read naturally.
        let title: String
        if let topicTitle = MathItCurriculum.topic(forLevelNumber: level)?.title {
            title = topicTitle
        } else {
            let rawTitle = LevelGroup.title(for: screenLevel)
                ?? conceptDefinition(for: screen)?.title
                ?? ConceptLibrary.concept(for: screenLevel)?.title
                ?? "Level \(level)"
            title = formattedLevelTitle(rawTitle, levelNumber: screenLevel)
        }
        let completedOffset = levelProgress.isComplete(level) ? 1.0 : 0.18
        let progress = (Double(level - 1) + completedOffset) / Double(MathItCurriculum.allTopics.count)
        return (level, title, progress)
    }

    private func formattedLevelTitle(_ title: String, levelNumber: Int) -> String {
        if levelNumber == 1 { return "One Mirror" }
        return title
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                if lower == "3d" { return "3D" }
                if lower == "lcm" { return "LCM" }
                return lower.prefix(1).uppercased() + String(lower.dropFirst())
            }
            .joined(separator: " ")
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .levelSelect:
            LevelSelectView(
                initialGroupTitle: lastGroupTitle,
                revealed: $levelsRevealed,
                onLevelSelected: { position in
                    if let placement = MathItCurriculum.placement(forPosition: position) {
                        lastGroupTitle = placement.section.title
                    }
                    navigateToCurriculum(position: position)
                },
                onPlaceholder: { position in navigateToCurriculum(position: position) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .placeholder(let position):
            MathItPlaceholderLevelView(
                number: position,
                onContinue: { advanceFromCurrent() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOne:
            MathItLevelOneView(
                viewModel: levelOneViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelOne() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelOneViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwo:
            MathItLevelTwoView(
                viewModel: levelTwoViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwo() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwoViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThree:
            MathItLevelThreeView(
                viewModel: levelThreeViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThree() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThreeViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFour:
            MathItLevelFourView(
                viewModel: levelFourViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFour() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFourViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFive:
            MathItLevelFiveView(
                viewModel: levelFiveViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFive() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFiveViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSix:
            MathItLevelSixView(
                viewModel: levelSixViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelSix() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelSixViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSeven:
            MathItLevelSevenView(
                viewModel: levelSevenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelSeven() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelSevenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEight:
            MathItLevelOneHundredThreeView(
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNine:
            MathItLevelNineView(
                viewModel: levelNineViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelNine() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelNineViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTen:
            MathItLevelTenView(
                viewModel: levelTenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTen() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEleven:
            MathItLevelElevenView(
                viewModel: levelElevenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelEleven() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelElevenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwelve:
            MathItLevelTwelveView(
                viewModel: levelTwelveViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwelve() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwelveViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirteen:
            MathItLevelThirteenView(
                viewModel: levelThirteenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirteen() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirteenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFourteen:
            MathItLevelFourteenView(
                viewModel: levelFourteenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFourteen() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFourteenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFifteen:
            MathItLevelFifteenView(
                viewModel: levelFifteenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFifteen() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFifteenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSixteen:
            MathItLevelSixteenView(
                viewModel: levelSixteenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelSixteen() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelSixteenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSeventeen:
            MathItLevelSeventeenView(
                viewModel: levelSeventeenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelSeventeen() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelSeventeenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEighteen:
            MathItLevelEighteenView(
                viewModel: levelEighteenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelEighteen() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelEighteenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNineteen:
            MathItLevelNineteenView(
                viewModel: levelNineteenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelNineteen() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelNineteenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwenty:
            MathItLevelTwentyView(
                viewModel: levelTwentyViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwenty() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentyViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentyOne:
            MathItLevelTwentyOneView(
                viewModel: levelTwentyOneViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentyOne() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentyOneViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentyTwo:
            MathItLevelTwentyTwoView(
                viewModel: levelTwentyTwoViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentyTwo() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentyTwoViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentyThree:
            MathItLevelTwentyThreeView(
                viewModel: levelTwentyThreeViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentyThree() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentyThreeViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentyFour:
            MathItLevelTwentyFourView(
                viewModel: levelTwentyFourViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentyFour() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentyFourViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentyFive:
            MathItLevelTwentyFiveView(
                viewModel: levelTwentyFiveViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentyFive() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentyFiveViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentySix:
            MathItLevelTwentySixView(
                viewModel: levelTwentySixViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentySix() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentySixViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentySeven:
            MathItLevelTwentySevenView(
                viewModel: levelTwentySevenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentySeven() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentySevenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentyEight:
            MathItLevelTwentyEightView(
                viewModel: levelTwentyEightViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentyEight() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentyEightViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelTwentyNine:
            MathItLevelTwentyNineView(
                viewModel: levelTwentyNineViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelTwentyNine() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelTwentyNineViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirty:
            MathItLevelThirtyView(
                viewModel: levelThirtyViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirty() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtyViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtyOne:
            MathItLevelThirtyOneView(
                viewModel: levelThirtyOneViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtyOne() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtyOneViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtyTwo:
            MathItLevelThirtyTwoView(
                viewModel: levelThirtyTwoViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtyTwo() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtyTwoViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtyThree:
            MathItLevelThirtyThreeView(
                viewModel: levelThirtyThreeViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtyThree() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtyThreeViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtyFour:
            MathItLevelThirtyFourView(
                viewModel: levelThirtyFourViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtyFour() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtyFourViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtyFive:
            MathItLevelThirtyFiveView(
                viewModel: levelThirtyFiveViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtyFive() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtyFiveViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtySix:
            MathItLevelThirtySixView(
                viewModel: levelThirtySixViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtySix() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtySixViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtySeven:
            MathItLevelThirtySevenView(
                viewModel: levelThirtySevenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtySeven() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtySevenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtyEight:
            MathItLevelThirtyEightView(
                viewModel: levelThirtyEightViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtyEight() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtyEightViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelThirtyNine:
            MathItLevelThirtyNineView(
                viewModel: levelThirtyNineViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelThirtyNine() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelThirtyNineViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelForty:
            MathItLevelFortyView(
                viewModel: levelFortyViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelForty() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortyViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortyOne:
            MathItLevelFortyOneView(
                viewModel: levelFortyOneViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFortyOne() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortyOneViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortyTwo:
            MathItLevelThirtyThreeView(
                viewModel: levelFortyTwoViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFortyTwo() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortyTwoViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortyThree:
            MathItLevelFortyThreeView(
                viewModel: levelFortyThreeViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFortyThree() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortyThreeViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortyFour:
            MathItLevelFortyFourView(
                viewModel: levelFortyFourViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFortyFour() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortyFourViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortyFive:
            MathItLevelFortyFiveView(
                viewModel: levelFortyFiveViewModel,
                onContinue: {
                    markCurrentComplete()
                    levelFortyFiveViewModel.cancelScheduledActions()
                    startLevelFortySix()
                },
                onReplay: { startLevelFortyFive() },
                onLevelSelect: {
                    levelFortyFiveViewModel.cancelScheduledActions()
                    returnToLevelSelect()
                }
            )
            .id(ObjectIdentifier(levelFortyFiveViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortySix:
            MathItLevelFortySixView(
                viewModel: levelFortySixViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFortySix() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortySixViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortySeven:
            MathItLevelFortySevenView(
                viewModel: levelFortySevenViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFortySeven() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortySevenViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortyEight:
            MathItLevelFortyEightView(
                viewModel: levelFortyEightViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFortyEight() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortyEightViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFortyNine:
            MathItLevelFortyNineView(
                viewModel: levelFortyNineViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFortyNine() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFortyNineViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFifty:
            MathItLevelFiftyView(
                viewModel: levelFiftyViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFifty() },
                onLevelSelect: {
                    levelFiftyViewModel.cancelTimer()
                    returnToLevelSelect()
                }
            )
            .id(ObjectIdentifier(levelFiftyViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftyOne:
            MathItLevelFiftyOneView(
                viewModel: levelFiftyOneViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFiftyOne() },
                onLevelSelect: {
                    levelFiftyOneViewModel.cancelTimer()
                    returnToLevelSelect()
                }
            )
            .id(ObjectIdentifier(levelFiftyOneViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftyTwo:
            MathItLevelFiftyTwoView(
                viewModel: levelFiftyTwoViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFiftyTwo() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFiftyTwoViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftyThree:
            MathItLevelFiftyThreeFlockingView(
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSixtyEight:
            MathItLevelSixtyEightView(
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSixtyTwo, .levelSixtyThree, .levelSixtyFour,
             .levelSixtyFive, .levelSixtySix, .levelSixtySeven, .levelSixtyNine,
             .levelSeventy, .levelSeventyOne, .levelSeventyTwo, .levelSeventyThree, .levelSeventyFour,
             .levelSeventyFive:
            conceptPreview(for: screen)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSeventySix:
            MathItLevelSeventySixView(
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSeventySeven:
            MathItLevelSeventySevenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSeventyEight:
            MathItLevelSeventyEightView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSeventyNine:
            MathItLevelSeventyNineView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEighty:
            MathItLevelEightyView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightyOne:
            MathItLevelEightyOneView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightyTwo:
            MathItLevelEightyTwoView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightyThree:
            MathItLevelEightyThreeView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightyFour:
            MathItLevelEightyFourView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightyFive:
            MathItLevelEightyFiveView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightySix:
            MathItLevelEightySixView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightySeven:
            MathItLevelEightySevenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightyEight:
            MathItLevelEightyEightView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelEightyNine:
            MathItLevelEightyNineView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinety:
            MathItLevelNinetyView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetyOne:
            MathItLevelNinetyOneView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetyTwo:
            MathItLevelNinetyTwoView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetyThree:
            MathItLevelNinetyThreeView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetyFour:
            MathItLevelNinetyFourView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetyFive:
            MathItLevelNinetyFiveView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetySix:
            MathItLevelNinetySixView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetySeven:
            MathItLevelNinetySevenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetyEight:
            MathItLevelNinetyEightView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelNinetyNine:
            MathItLevelNinetyNineView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundred:
            MathItLevelOneHundredView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredOne:
            MathItLevelOneHundredOneView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwo:
            MathItLevelOneHundredTwoView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThree:
            MathItLevelOneHundredThreeView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredFour:
            MathItLevelOneHundredFourView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredFive:
            MathItLevelOneHundredFiveView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredSix:
            MathItLevelOneHundredSixView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredSeven:
            MathItLevelOneHundredSevenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredEight:
            MathItLevelOneHundredEightView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredNine:
            MathItLevelOneHundredNineView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTen:
            MathItLevelOneHundredTenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredEleven:
            MathItLevelOneHundredElevenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwelve:
            MathItLevelOneHundredTwelveView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirteen:
            MathItLevelOneHundredThirteenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredFourteen:
            MathItLevelOneHundredFourteenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredFifteen:
            MathItLevelOneHundredFifteenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredSixteen:
            MathItNoContactView(
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onLevelSelect: { returnToLevelSelect() },
                levelTitle: "NO CONTACT",
                eyebrow: "N-QUEENS PROBLEM",
                completionTitle: "N-Queens Completed"
            )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredSeventeen:
            MathItLevelOneHundredSeventeenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredEighteen:
            MathItLevelOneHundredEighteenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwenty:
            MathItLevelOneHundredTwentyView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentyOne:
            MathItLevelOneHundredTwentyOneView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentyTwo:
            MathItLevelOneHundredTwentyTwoView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentyThree:
            MathItLevelOneHundredTwentyThreeView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentyFour:
            MathItLevelOneHundredTwentyFourView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentyFive:
            MathItLevelOneHundredTwentyFiveView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentySix:
            MathItLevelOneHundredTwentySixView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentySeven:
            MathItLevelOneHundredTwentySevenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentyEight:
            MathItLevelOneHundredTwentyEightView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredTwentyNine:
            MathItLevelOneHundredTwentyNineView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirty:
            MathItLevelOneHundredThirtyView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtyOne:
            MathItLevelOneHundredThirtyOneView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtyTwo:
            MathItLevelOneHundredThirtyTwoView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtyThree:
            MathItLevelOneHundredThirtyThreeView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtyFour:
            MathItLevelOneHundredThirtyFourView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtyFive:
            MathItLevelOneHundredThirtyFiveView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtySix:
            MathItLevelOneHundredThirtySixView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtySeven:
            MathItLevelOneHundredThirtySevenView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtyEight:
            MathItLevelOneHundredThirtyEightView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredThirtyNine:
            MathItLevelOneHundredThirtyNineView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredForty:
            MathItLevelOneHundredFortyView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredFortyOne:
            MathItLevelOneHundredFortyOneView(onContinue: { markCurrentComplete(); advanceFromCurrent() }, onLevelSelect: { returnToLevelSelect() })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelOneHundredFortyThree:
            MathItLevelFiftySevenView(
                viewModel: levelOneHundredFortyThreeViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelOneHundredFortyThree() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelOneHundredFortyThreeViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftyFour:
            MathItLevelFiftyFourView(
                viewModel: levelFiftyFourViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFiftyFour() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFiftyFourViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftyFive:
            MathItLevelFiftyFiveView(
                viewModel: levelFiftyFiveViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFiftyFive() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFiftyFiveViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftySix:
            MathItLevelFiftySixView(
                viewModel: levelFiftySixViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFiftySix() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFiftySixViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftySeven:
            MathItCompositeFunctionsLevelView(
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftyEight:
            MathItLevelFiftyEightView(
                viewModel: levelFiftyEightViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFiftyEight() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFiftyEightViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelFiftyNine:
            MathItLevelFiftyNineView(
                viewModel: levelFiftyNineViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelFiftyNine() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelFiftyNineViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSixty:
            MathItLevelSixtyView(
                viewModel: levelSixtyViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelSixty() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelSixtyViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .levelSixtyOne:
            MathItLevelSixtyOneView(
                viewModel: levelSixtyOneViewModel,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onReplay: { startLevelSixtyOne() },
                onLevelSelect: { returnToLevelSelect() }
            )
            .id(ObjectIdentifier(levelSixtyOneViewModel))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private func hintText(for screen: MathItScreen) -> String? {
        switch screen {
        case .levelSelect:
            nil
        case .placeholder:
            nil
        case .levelOne:
            "Drag the 1 to the mirror, pull out its reflection, then place the two 1s around the equals sign."
        case .levelTwo:
            "Drag the markers along the number line into the positions that build the target relationship."
        case .levelThree:
            "Drag the Moon around its orbit to change how much of its lit face you see from Earth. Match the target fraction shown at the top — new moon (0), quarter (½), gibbous, full (1) — and the phases repeat in a steady cycle, a sequence you can read around the orbit."
        case .levelFour:
            "Pull back to set your launch power, then release to toss the paper into the trash can. Later stages can only be reached by bouncing off the walls."
        case .levelFive:
            "Drag the knob to sweep the diameter all the way around and paint the circle. Then drop the circle and the diameter into the equation's outlines to reveal the result."
        case .levelSix:
            "Aim the cannon and fire at the target. The ball flies straight — but your platform is spinning, so it looks like it curves. Lead the target to hit it. Faster spins and more targets follow."
        case .levelSeven:
            "Play misère Nim against the CPU. Remove one or more matches from exactly one row; whoever takes the last match loses. Use bitwise XOR to track the nim-sum: aim for 0 after your turn, except when every remaining row contains a single match, where parity controls the misère endgame."
        case .levelEight:
            "Set each fraction string's tension, then drop the ball. Each string flings it to the next — too little falls short, too much overshoots. Get every fraction right to chain into the goal."
        case .levelNine:
            "Shape the two oval lenses, then drag either lens into either dotted outline. Matching both outlines focuses the beam, lights the cage, and drops the ball into the white goal."
        case .levelTen:
            "Drag numbers and an operator to build an expression, then use the blocks it generates to bridge the gap."
        case .levelEleven:
            "Drag marbles onto the two pans to weigh them. Use the balance to find the odd marble, then drag it into the gray circle."
        case .levelTwelve:
            "Drag in one continuous stroke to trace every edge exactly once. Lifting your finger or retracing resets the attempt."
        case .levelThirteen:
            "Drag to rotate the pyramid, then trace a single path that crosses every edge exactly once."
        case .levelFourteen:
            "Every face of the mountain is a linear function over its stretch of x. Drag each equation tile out of the snow onto the dotted slot on its matching face — read the slope's sign and steepness, and use the x-interval to tell twins apart. Match them all and the blue climber snowboards down to the pink one."
        case .levelFifteen:
            "Drag each fraction under the string it matches, then tap the strings to play the melody."
        case .levelSixteen:
            "Build each number with the equation pieces, then drag them onto the beats to play the rhythm."
        case .levelSeventeen:
            "Brush your finger across the sand to uncover the buried tracks. Every print has exactly one congruent partner — same shape AND same size, hidden far away at a different angle (some mirrored). Drag each print into its matching outline in the museum; complete a pair and the dinosaur is rebuilt. The two theropod sizes are similar, not congruent."
        case .levelEighteen:
            "Tap the A and B inputs to toggle them on or off. Find the setting that powers the bulb through every gate."
        case .levelNineteen:
            "Drag pieces to build a triangle, snap on its height to form a prism, then drag the prism into the beam."
        case .levelTwenty:
            "Drag the pieces to build a speed value and drop it in the speed box, then watch whether the orbit escapes."
        case .levelTwentyOne:
            "Drag each fraction onto the note it completes. The melody plays once every note is filled."
        case .levelTwentyTwo:
            "Drag each pink point across the axis to its mirrored position to complete the symmetric design."
        case .levelTwentyThree:
            "Stages 1–3: drag one continuous stroke across every stellar link exactly once. Stage 4: rotate the musical pyramid and trace every edge; each connection plays its note. The level finishes only after the pyramid is complete."
        case .levelTwentyFour:
            "Drag each loose component into its matching gap, then tap the switch to close the circuit."
        case .levelTwentyFive:
            "A bird flies across the sky at some height +h. Only the shark whose |depth| equals h can reach it — a shark at −3 leaps to exactly +3. Drop the golden |x| on the right shark: it times its jump and snatches the bird at the top of its arc. Absolute value is distance from zero."
        case .levelTwentySix:
            "Drag each fraction to its position on the string. The wave on each row shows which harmonic it carries."
        case .levelTwentySeven:
            "Tap each glowing endpoint to grow its two child branches. Finish one iteration to unlock the next."
        case .levelTwentyEight:
            "Drag the magnetic axis until it lines up with the rotation axis and the beams steady."
        case .levelTwentyNine:
            "Tap to open or close lockers, or to lock in your prediction. Ten students each toggle a run of lockers — work out which ones end up open."
        case .levelThirty:
            "Use a² + b² = c² with the fixed truck distance and building height to find each ladder length."
        case .levelThirtyOne:
            "Complete three encryption gates. For each lock, find the two prime numbers whose product equals the displayed value, drag them into the sockets, and watch the encrypted packet pass through to the receiver."
        case .levelThirtyTwo:
            "Tap to set a volume from the pot's shown length, width, and height, then release the blocks."
        case .levelThirtyThree:
            "Fold a paper crane step by step: tap markers 1 and 2 on each fold line and watch the paper fold over the crease. After every fold, the right triangle you just created appears with its angles and side lengths — the diagonal gives 45-45-90 with hypotenuse √2, and the kite folds create the crane's 22.5° angle (tan 22.5° = √2 − 1). Finish the crane to see its folds lift into a hypercube lattice."
        case .levelThirtyFour:
            "Tap to plant the seed, then tap each flower to multiply its seeds. Fill the whole field."
        case .levelThirtyFive:
            "Drag the k slider upward. A higher k packs the wave's oscillations tighter — push it all the way to fill the shape."
        case .levelThirtySix:
            "Tap to choose how many steps to test, then press play. Find the count that brings both dots back to the top together."
        case .levelThirtySeven:
            "Drag the three pieces into the slots, then rearrange them to find every distinct ordering."
        case .levelThirtyEight:
            "Drag the ball from the origin in the highlighted direction; the vector field responds to each move."
        case .levelThirtyNine:
            "Drag to revolve the surface, rolling the ball across it until the whole mesh is painted."
        case .levelForty:
            "Drag the fulcrum left and right until the data points balance perfectly."
        case .levelFortyOne:
            "Drag the glowing vertex until all three angles match the target values exactly."
        case .levelFortyTwo:
            "Fold a realistic paper crane step by step in 3D. Tap the glowing interaction dots in order, watch each rigid paper face rotate around its crease, then read the exact transformation: reflections across fold lines, squash-fold hinge rotations, angle bisections, preserved lengths, and the dihedral angles that lift a flat sheet into space."
        case .levelFortyThree:
            "Two grids, A and B, are given. Place a logic gate on each row — AND (&), OR (|), or XOR (^) — so A combined with B builds the target image. Tap a row's gate to cycle the options."
        case .levelFortyFour:
            "Drag the operation gears into a row, then turn the crank. The machine runs them left to right, so order matters."
        case .levelFortyFive:
            "Watch the items scan, then double-tap a bill to break it into smaller money. Drag the exact total onto the counter."
        case .levelFortySix:
            "Build a value with the same pieces from the earlier wave levels, then drop the result into the orange exponent slot."
        case .levelFortySeven:
            "Tap to set the mystery bag's value, then drag it onto the lighter pan until the scale balances."
        case .levelFortyEight:
            "Read the pattern in the symbols, then draw the missing shape or dots in the glowing pad."
        case .levelFortyNine:
            "Set an aim and slope, press play, then drag both triangle pieces into the outline slots."
        case .levelFifty:
            "Tap to shift the gear to a symbol that makes the sentence true, then press check. Answer as many as you can before time runs out."
        case .levelFiftyOne:
            "Tap to choose the inequality that fences off the target side before the markers cross the line."
        case .levelFiftyTwo:
            "Tap to choose the equation whose line links the ball to the goal; it becomes the ramp."
        case .levelFiftyThree:
            "Guide the flock and watch steering forces continuously change velocity. Separation, alignment, and cohesion act as acceleration."
        case .levelFiftyFour:
            "Drag one clean cut across each shape to split it into two equal halves."
        case .levelFiftyFive:
            "Tap cells to lay tiles with no gaps or overlaps. Tap a triangle to rotate it when the pattern alternates."
        case .levelFiftySix:
            "Drag along the net to mark the fold seams. When every seam is marked, it folds into the solid."
        case .levelFiftySeven:
            "Each round brings a new nesting doll wearing a composite like f(g(x)). Open her and name each doll inside with the right expression: the middle doll is the inner function, the tiniest is x. Label all three and the values cascade inside-out."
        case .levelFiftyEight:
            "Set a width and height so the plot matches BOTH the soil (area) and the fence (perimeter), then press Build. There's no counter — work the dimensions out yourself."
        case .levelFiftyNine:
            "Tap the arrow pad for straight moves. For diagonals, set the rise and run, then launch along the slope."
        case .levelSixty:
            "Watch the tiles flash in sequence, then tap the same tiles in the same order."
        case .levelSixtyOne:
            "Drag the glowing point along the horizon until the perspective rays line up with the dotted guides."
        case .levelSixtyEight:
            "Trace each gray dotted guide from left to right. Follow every horizontal, curved, and vertical section to reveal the sine, square, triangle, and sawtooth waves in four different colors."
        case .levelSixtyTwo, .levelSixtyThree, .levelSixtyFour,
             .levelSixtyFive, .levelSixtySix, .levelSixtySeven, .levelSixtyNine,
             .levelSeventy, .levelSeventyOne, .levelSeventyTwo, .levelSeventyThree, .levelSeventyFour,
             .levelSeventyFive:
            conceptDefinition(for: screen)?.instruction
        case .levelSeventySix:
            "Drag the top ring off a peg and drop it onto another. A ring can never rest on a smaller one. Move the whole stack to a new peg."
        case .levelSeventySeven:
            "Drag to rotate the grid until each value lands in its highlighted target cell."
        case .levelSeventyEight:
            "Move x and y independently. Watch how changing one input, while holding the other fixed, changes the surface and its output."
        case .levelSeventyNine:
            "Read each fish as two moves: rotate to θ, then travel r rings from the center. Later, tap the lake to place the coordinate yourself."
        case .levelEighty:
            "Slide t from 0 to 12π to trace the butterfly. The same parameter drives both x(t) and y(t), pairing two changing coordinates into one moving point."
        case .levelEightyOne:
            "Drag across cells to fill or clear them. Use the number clues on each row and column to reveal the picture."
        case .levelEightyTwo:
            "Drag an item into the boat and tap to cross. Never leave an unsafe pair alone on a bank, or the move rewinds."
        case .levelEightyThree:
            "Tap to fill, pour between, or empty the jugs. Use the two jug sizes to measure out the exact target amount."
        case .levelEightyFour:
            "Tap anywhere to push the snowboarder uphill. The opposing force weakens as the slope approaches zero; after the vertex, gravity controls the descent."
        case .levelEightyFive:
            "Watch the demo, then drag each rod into its slot before the timer runs out."
        case .levelEightySix:
            "Drag near the sheep to apply a local step that lowers their total distance from the matching pens. Guide every flock to minimum error."
        case .levelEightySeven:
            "Tap a question-mark tunnel to send a gold digger. If it reveals a green chamber, tap that chamber to send a blue carrier and open the next split. Red chambers are dead ends."
        case .levelEightyEight:
            "Drag the two knobs — prey birth rate and predator birth rate — to settle the populations into the target cycle."
        case .levelEightyNine:
            "Drag the frequency control to vibrate the plate. The sand drifts onto the still nodal lines — match the target pattern."
        case .levelNinety:
            "Tap a square a knight's L-move away to hop there. Visit every square exactly once. The numeral toggle reveals the order as a hint."
        case .levelNinetyOne:
            "Drag from the ball along the edges; each edge spends its weight from your credits. Reach the goal by spending your budget efficiently."
        case .levelNinetyTwo:
            "Drag a vertical line between two tracks to drop a comparator, then press Play. Comparators swap so the smaller value rides higher — sort the tracks in order."
        case .levelNinetyThree:
            "Rotate the cube to inspect all layers, then select an empty block. Every player and CPU move displays its 3D coordinate triple (x,y,z)."
        case .levelNinetyFour:
            "Memorize the deflectors before they vanish, then tap where you think the ball will exit. During the replay, every platform bounce turns the path through a right angle and leaves a 90° marker at the collision."
        case .levelNinetyFive:
            "Pump the giant swing on the high bar and RELEASE to fly across and catch the low bar. Swing again, release to dismount, and hold to tuck so you land on your feet."
        case .levelNinetySix:
            "Stage 1 is a flat grid: drag from a number to draw a rectangle of that area. Stage 2 is a 3D prism and stage 3 a sphere: pick a number, then tap cubes/sectors to fill that many (drag to rotate). Filling past a number is refused with a red outline."
        case .levelNinetySeven:
            "After the demo triangle, tap the point farthest outside the current dashed edge to extend the hull. Edges with no points beyond them lock in."
        case .levelNinetyEight:
            "Tap to guess which seat survives the elimination, then press play to run it and see if you were right."
        case .levelNinetyNine:
            nil
        case .levelOneHundred:
            "Adjust Workers and Pheromone to change how many independent ant trials occur and how strongly local density influences each drop. Hold exactly five organized piles inside the five dotted target rings."
        case .levelOneHundredOne:
            "Tap the gold singularity to trigger the big bang, then drag the 0 into the centre to ignite the sun. Once the orbits appear, drag every number onto its correct ring — naturals, negatives and rationals — to rebuild the system."
        case .levelOneHundredTwo:
            "Tap one of your pits (bottom row) to sow its stones counter-clockwise. Land your last stone in your store for another turn, or in an empty pit on your side to capture the stones across from it. Finish with more stones than the opponent."
        case .levelOneHundredThree:
            "Build the recipe: tap ingredients and machines to fill the expression strip — the mixer adds, the oven multiplies, the knife divides, the strainer subtracts. Use ( ) GROUP to control which operation cooks first, then RUN RECIPE to match the customer's target flavor."
        case .levelOneHundredFour:
            "The left cylinder is full; the right one already holds some water and its empty space is x. Tap PUMP to move water across one litre at a time until the right cylinder fills to the top — the number of litres you pumped is the value of x that solves the equation."
        case .levelOneHundredFive:
            "x → +3 → ÷2 → +4 → 12m"
        case .levelOneHundredSix:
            "Slide the magnifier from left to right to zoom from the edge of the observable universe down to a quark. Each object grows from the centre of the one before it — everything is inside something bigger. Watch the 10ⁿ m readout: the exponent is the zoom."
        case .levelOneHundredSeven:
            "Tap + to grow the Spiral of Theodorus to √17 — each triangle's hypotenuse is √(n+1). Then every triangle becomes a note, high pitch on √2 down to low on √17. Listen to the melody as the triangles glow, then tap them back in order from memory. Three stages, each a little longer."
        case .levelOneHundredEight:
            "Tap each egg to breed the four offspring in the Punnett square — every cell pairs one gene from each parent (aa, ab, ba, bb). Since ab and ba are the same, the litter sorts into one a², two ab and one b². That tally IS (a+b)² = a² + 2ab + b²."
        case .levelOneHundredNine:
            "Forge the medallion by solving x² − 5x + 6 = 0 five ways. Pick a method, choose the right step (or tap the parabola's x-intercepts for graphing), and its golden wedge locks into the medallion. Complete all five — every method gives x = 2, 3."
        case .levelOneHundredTen:
            "Each ramp is one piece of a piecewise function with its own equation and domain. Drag every piece up or down until it sits where its equation says — check the endpoints against the grid. When all pieces lock, the skater rides the course: closed circles roll through, open circles at a different height become jumps across the gap."
        case .levelOneHundredEleven:
            "Adjust angle and power so the projectile follows the parabolic path toward the opposing tank. The live equation changes with the shot: the curve's height, vertex, and x-intercepts show the shape of a quadratic."
        case .levelOneHundredTwelve:
            "Tap the camera to raise it to your eye, then zoom until the animal exactly fills the gold outline in the lens — hold steady and the shutter clicks. Zoom scales every length by the same factor and never bends an angle: the animal keeps its shape at every size. That's similarity, and the zoom is the scale factor k."
        case .levelOneHundredThirteen:
            "Five targets approach the unit circle along its standard angle rays, with no more than two on screen at once and each arriving from a different direction. Tap either occupied ray to fire. The selected ray highlights, a right triangle forms, and its angle appears in degrees and radians. Tapping an empty ray or letting a target reach the center costs one of your three hearts."
        case .levelOneHundredFourteen:
            "Drag each disconnected track section onto the faint course guide. Match the endpoint circles and each piece will snap into place. Connect all six cubic polynomial sections, then launch the train through the completed parametric coaster."
        case .levelOneHundredFifteen:
            "Select x², x, or 1 from the parts bins, then tap the cutting bed to install that tile. Rotate x strips when needed, drag installed pieces to rearrange them, or tap a piece to return it. Use every piece to make one solid rectangle with no gaps or overlaps; its side lengths reveal the factors."
        case .levelOneHundredSixteen:
            "Place one queen in every row without allowing any pair to share a row, column, or diagonal. Conflicting queens flash red and reset the stage. Complete the 4x4, 5x5, and 6x6 boards to solve the constraint system."
        case .levelOneHundredSeventeen:
            "Set the cube production rate, then start the plant. Watch average cost C(q) = 1800/q + 10 fall toward its $10 variable-cost asymptote while the factory and bank update together. Produce near market demand to spread fixed cost without building costly unsold inventory."
        case .levelOneHundredEighteen:
            "Each water droplet arrives stamped with a function f. The machine wears f⁻¹(x) and a dotted slot: drag in the equation that truly undoes f — swap the operations and reverse their order (2x − 4 undoes as add 4, THEN halve). Install the right inverse and the machine freezes the droplet, delivering an ice cube from its chute."
        case .levelOneHundredTwenty:
            "Drag the beacon or use its slider to move the V's center h. Adjust pulse speed to change the V's steepness, then send an echo pulse. Every circular timing window must sit on the cyan graph; pulse speed v sets the slope through t = 2|x − h|/v."
        case .levelOneHundredTwentyOne:
            "Adjust the arch crown k, cable slope m, and cable height b. Cyan dots show where the arch and cable currently intersect; align them with the gold construction rings, then run the inspection. The final inspection needs no intersections, so make the discriminant negative."
        case .levelOneHundredTwentyTwo:
            "Drag the cyan u and gold v handles to transform the pixel image onto the faint target. The handles form the two columns of the live 2 × 2 matrix. Keep the determinant meter out of the red compression and stretching zones, then redistribute the pixels when the image, orientation, and area scale match."
        case .levelOneHundredTwentyThree:
            "Drag the zoom slider from 1× to 64×. Every full generation doubles the magnification and reveals the same structure at a smaller scale. Cross the 4×, 16×, and 64× checkpoints to build the geometric sequence aₙ = 2ⁿ."
        case .levelOneHundredTwentyFour:
            "Record up to eight seconds, then play the reconstructed voice. Each harmonic isolates a frequency band: mute it or change amplitude A, frequency f, and phase φ while playback runs. The displayed aₙ and bₙ values are that layer's cosine and sine coefficients."
        case .levelOneHundredTwentyFive:
            "Tap play to tip the bucket. Every peg gives each bead an equal chance to fall left or right. Watch the repeated random choices collect into a centered distribution, with middle bins receiving more beads than the outer bins."
        case .levelOneHundredTwentySix:
            "Tap a destination on the new diagonal boundary. Its route count is the sum of the two feeder intersections one block closer to the depot. Choose that total to open the block; the completed boundary becomes the coefficient row for (E + N)ⁿ."
        case .levelOneHundredTwentySeven:
            "Drag the hammer onto 6 and 35 to split the composite crystals into their prime factors. Then drag each shining blue crystal into its matching dotted outline: 2, 3, 5, and 7."
        case .levelOneHundredTwentyEight:
            "Calibrate the radar arm to the forecast cell's bearing θ and radial distance r. Drag inside the scope or use the angle and range sliders, then lock the storm cell. The live readout converts your polar location using x = r cos(θ) and y = r sin(θ)."
        case .levelOneHundredTwentyNine:
            "Drag the next loose card into its correct spot in the sorted row. The other cards shift to make room."
        case .levelOneHundredThirty:
            "Send probes toward the damaged sensor from both the left and right. Compare the output readings as x gets closer to a. If both sides approach one value, that is the two-sided limit even when the sensor is missing or reports something else; if the sides disagree, choose DNE."
        case .levelOneHundredThirtyOne:
            "Move each pipe section vertically until both neighboring endpoints meet the fixed gold junction valve. At every boundary, the incoming height is the left limit, the outgoing height is the right limit, and the valve height is f(a). Pressurize only when all three agree."
        case .levelOneHundredThirtyTwo:
            "Scrub the vehicle through time and watch the tangent line rotate. Its rise over a one-second run is the instantaneous speed shown on the gauge. Stop when that local slope matches the posted speed limit, then check the speedometer."
        case .levelOneHundredThirtyThree:
            "Hold the dispenser longer to trap more air, then release three bubbles and let them touch. V/VMAX tracks air against the dispenser's total capacity, R comes from V = 4πr³/3, and the live A MIN and E MIN meters recalculate the least-film spherical-cap connection for the exact bubble sizes you create."
        case .levelOneHundredThirtyFour:
            "Set the collection duration T to the forecast window, then tune the rainfall intensity k. Start collection to watch narrow time slices fill both the area beneath the rainfall-rate curve and the reservoir. Their total is the definite integral ∫₀ᵀ k·r(t)dt; taller slices or a longer interval collect more water."
        case .levelOneHundredThirtyFive:
            "Move the master volume while comparing physical sound intensity with the decibel scale. Every 10× increase in intensity adds 10 dB. In the live-mix stages, compensate for drums, guitar, and vocals to keep the decibel meter inside the venue's highlighted target zone."
        case .levelOneHundredThirtySix:
            "Set the outdoor ambient temperature Tₐ and the insulation rating. More insulation lowers k, so the room exchanges heat more slowly. Run the schedule and watch dT/dt = −k(T − Tₐ): a large temperature difference creates a steep change, while the rate approaches zero as the room approaches ambient temperature."
        case .levelOneHundredThirtySeven:
            "Match the station brief by setting P(wet) and the conditional branch P(storm | wet). Their product gives P(storm), while P(light rain) = P(wet)[1 − P(storm | wet)]. Choose the plan with the strongest theoretical average, then run 300 days and compare experimental frequencies with the branch probabilities."
        case .levelOneHundredThirtyEight:
            "Drag the gold guide around the pie crust or use − and + to choose one serving's arc length. Tap the knife to repeat that interval around the circle. Equal arcs make equal slices; an incorrect interval leaves a visibly unequal final piece."
        case .levelOneHundredThirtyNine:
            "Move the approximation slider to add Airy power-series terms. The colored pattern is the current partial sum, while the dotted intensity curve is the full target model. Reach the required accuracy, then use no more than the stage's term budget."
        case .levelOneHundredForty:
            "Set the launch angle θ₀, gravitational acceleration g, and friction c at the joint between the two arms. Release the single double pendulum and compare its trail, phase path, angular speed, energy, and musical notes: height selects pitch, speed shapes strength, and horizontal position controls stereo placement."
        case .levelOneHundredFortyOne:
            "Move time to paint the area under the flow-rate curve and fill the reservoir by the same amount. Later, reshape f(t) directly. The gold accumulation graph is F(t) = ∫₀ᵗf(x)dx, and its local slope is the current flow rate: F′(t) = f(t)."
        case .levelOneHundredFortyThree:
            "Tap the arrow pad to slide the shape and the rotate button to turn it onto the white outline."
        }
    }

    @ViewBuilder
    private func conceptPreview(for screen: MathItScreen) -> some View {
        if let definition = algebraChoiceDefinition(for: screen) {
            MathItAlgebraChoiceLevelView(
                definition: definition,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onLevelSelect: { self.returnToLevelSelect() }
            )
        } else {
            MathItBuiltConceptLevelView(
                concept: conceptDefinition(for: screen)!,
                onContinue: { markCurrentComplete(); advanceFromCurrent() },
                onLevelSelect: { self.returnToLevelSelect() }
            )
        }
    }

    private func algebraChoiceDefinition(for screen: MathItScreen) -> AlgebraChoiceDefinition? {
        let number: Int
        switch screen {
        case .levelFortySix: number = 46
        case .levelFortyNine: number = 49
        case .levelFifty: number = 50
        case .levelFiftyOne: number = 51
        case .levelFiftyTwo: number = 52
        case .levelFiftyThree: number = 53
        default: return nil
        }
        return AlgebraChoiceDefinition.levels[number]
    }

    private func conceptDefinition(for screen: MathItScreen) -> MathItConceptDefinition? {
        let number: Int
        switch screen {
        case .levelFortyFour: number = 44
        case .levelFortyFive: number = 45
        case .levelFortySix: number = 46
        case .levelFortySeven: number = 47
        case .levelFortyEight: number = 48
        case .levelFortyNine: number = 49
        case .levelFifty: number = 50
        case .levelFiftyOne: number = 51
        case .levelFiftyTwo: number = 52
        case .levelFiftyThree: number = 53
        case .levelFiftyFour: number = 54
        case .levelFiftyFive: number = 55
        case .levelFiftySix: number = 56
        case .levelFiftySeven: number = 57
        case .levelFiftyEight: number = 58
        case .levelFiftyNine: number = 59
        case .levelSixty: number = 60
        case .levelSixtyOne: number = 61
        case .levelSixtyTwo: number = 62
        case .levelSixtyThree: number = 63
        case .levelSixtyFour: number = 64
        case .levelSixtyFive: number = 65
        case .levelSixtySix: number = 66
        case .levelSixtySeven: number = 67
        case .levelSixtyEight: number = 68
        case .levelSixtyNine: number = 69
        case .levelSeventy: number = 70
        case .levelSeventyOne: number = 71
        case .levelSeventyTwo: number = 72
        case .levelSeventyThree: number = 73
        case .levelSeventyFour: number = 74
        case .levelSeventyFive: number = 75
        case .levelSeventySix: number = 76
        case .levelSeventySeven: number = 77
        case .levelSeventyEight: number = 78
        case .levelSeventyNine: number = 79
        case .levelEighty: number = 80
        case .levelEightyOne: number = 81
        case .levelEightyTwo: number = 82
        case .levelEightyThree: number = 83
        case .levelEightyFour: number = 84
        case .levelEightyFive: number = 85
        case .levelEightySix: number = 86
        case .levelEightySeven: number = 87
        case .levelEightyEight: number = 88
        case .levelEightyNine: number = 89
        case .levelNinety: number = 90
        case .levelNinetyOne: number = 91
        case .levelNinetyTwo: number = 92
        case .levelNinetyThree: number = 93
        case .levelNinetyFour: number = 94
        case .levelNinetyFive: number = 95
        case .levelNinetySix: number = 96
        case .levelNinetySeven: number = 97
        case .levelNinetyEight: number = 98
        case .levelNinetyNine: number = 99
        case .levelOneHundred: number = 100
        default: return nil
        }
        return MathItConceptDefinition.algebraPreviews[number]
            ?? MathItConceptDefinition.geometryPreviews[number]
            ?? MathItConceptDefinition.musicPreviews[number]
            ?? MathItConceptDefinition.logicPreviews[number]
    }

    private func nextConceptScreen(after screen: MathItScreen) -> MathItScreen {
        switch screen {
        case .levelFortyFour: .levelFortyFive
        case .levelFortyFive: .levelFortySix
        case .levelFortySix: .levelFortySeven
        case .levelFortySeven: .levelFortyEight
        case .levelFortyEight: .levelFortyNine
        case .levelFortyNine: .levelFifty
        case .levelFifty: .levelFiftyOne
        case .levelFiftyOne: .levelFiftyTwo
        case .levelFiftyTwo: .levelFiftyThree
        case .levelFiftyThree: .levelFiftyFour
        case .levelFiftyFour: .levelFiftyFive
        case .levelFiftyFive: .levelFiftySix
        case .levelFiftySix: .levelFiftySeven
        case .levelFiftySeven: .levelFiftyEight
        case .levelFiftyEight: .levelFiftyNine
        case .levelFiftyNine: .levelSixty
        case .levelSixty: .levelSixtyOne
        case .levelSixtyOne: .levelSixtyTwo
        case .levelSixtyTwo: .levelSixtyThree
        case .levelSixtyThree: .levelSixtyFour
        case .levelSixtyFour: .levelSixtyFive
        case .levelSixtyFive: .levelSixtySix
        case .levelSixtySix: .levelSixtySeven
        case .levelSixtySeven: .levelSixtyEight
        case .levelSixtyEight: .levelSixtyNine
        case .levelSixtyNine: .levelSeventy
        case .levelSeventy: .levelSeventyOne
        case .levelSeventyOne: .levelSeventyTwo
        case .levelSeventyTwo: .levelSeventyThree
        case .levelSeventyThree: .levelSeventyFour
        case .levelSeventyFour: .levelSeventyFive
        case .levelSeventyFive: .levelSeventySix
        case .levelSeventySix: .levelSeventySeven
        case .levelSeventySeven: .levelSeventyEight
        case .levelSeventyEight: .levelSeventyNine
        case .levelSeventyNine: .levelEighty
        case .levelEighty: .levelEightyOne
        case .levelEightyOne: .levelEightyTwo
        case .levelEightyTwo: .levelEightyThree
        case .levelEightyThree: .levelEightyFour
        case .levelEightyFour: .levelEightyFive
        case .levelEightyFive: .levelEightySix
        case .levelEightySix: .levelEightySeven
        case .levelEightySeven: .levelEightyEight
        case .levelEightyEight: .levelEightyNine
        case .levelEightyNine: .levelNinety
        case .levelNinety: .levelNinetyOne
        case .levelNinetyOne: .levelNinetyTwo
        case .levelNinetyTwo: .levelNinetyThree
        case .levelNinetyThree: .levelNinetyFour
        case .levelNinetyFour: .levelNinetyFive
        case .levelNinetyFive: .levelNinetySix
        case .levelNinetySix: .levelNinetySeven
        case .levelNinetySeven: .levelNinetyEight
        case .levelNinetyEight: .levelNinetyNine
        case .levelNinetyNine: .levelOneHundred
        case .levelOneHundred: .levelOneHundredOne
        case .levelOneHundredOne: .levelOneHundredTwo
        default: .levelSelect
        }
    }

    /// Curriculum list position of a screen (real level or placeholder).
    private func curriculumPosition(for s: MathItScreen) -> Int? {
        levelNumber(for: s)
    }

    private func returnToLevelSelect() {
        if let position = curriculumPosition(for: screen),
           let placement = MathItCurriculum.placement(forPosition: position) {
            lastGroupTitle = placement.section.title
        }
        activeHint = nil
        activeConcept = nil
        cancelActiveLevelTimers()
        screen = .levelSelect
    }

    /// Go to a curriculum position — a real level, or its placeholder screen if unbuilt.
    private func navigateToCurriculum(position: Int) {
        guard position >= 1, position <= MathItCurriculum.allTopics.count else { returnToLevelSelect(); return }
        activeHint = nil
        activeConcept = nil
        cancelActiveLevelTimers()
        if MathItCurriculum.screenLevel(forLevelNumber: position) != nil {
            startLevel(number: position)
        } else {
            screen = .placeholder(position)
        }
    }

    private func moveLevel(by delta: Int) {
        guard let cur = curriculumPosition(for: screen) else { return }
        navigateToCurriculum(position: cur + delta)
    }

    /// Advance one curriculum step (used by "Continue"); off the end returns to the menu.
    private func advanceFromCurrent() {
        guard let cur = curriculumPosition(for: screen) else { returnToLevelSelect(); return }
        if cur >= MathItCurriculum.allTopics.count { returnToLevelSelect(); return }
        navigateToCurriculum(position: cur + 1)
    }

    private func cancelActiveLevelTimers() {
        switch screen {
        case .levelFifty:
            levelFiftyViewModel.cancelTimer()
        case .levelFiftyOne:
            levelFiftyOneViewModel.cancelTimer()
        default:
            break
        }
    }

    private func levelNumber(for screen: MathItScreen) -> Int? {
        if case .placeholder(let n) = screen { return n }
        guard let screenLevel = screenLevel(for: screen) else { return nil }
        return MathItCurriculum.levelNumber(forScreenLevel: screenLevel) ?? screenLevel
    }

    private func screenLevel(for screen: MathItScreen) -> Int? {
        switch screen {
        case .placeholder: nil
        case .levelOne: 1
        case .levelTwo: 2
        case .levelThree: 3
        case .levelFour: 4
        case .levelFive: 5
        case .levelSix: 6
        case .levelSeven: 7
        case .levelEight: 8
        case .levelNine: 9
        case .levelTen: 10
        case .levelEleven: 11
        case .levelTwelve: 12
        case .levelThirteen: 13
        case .levelFourteen: 14
        case .levelFifteen: 15
        case .levelSixteen: 16
        case .levelSeventeen: 17
        case .levelEighteen: 18
        case .levelNineteen: 19
        case .levelTwenty: 20
        case .levelTwentyOne: 21
        case .levelTwentyTwo: 22
        case .levelTwentyThree: 23
        case .levelTwentyFour: 24
        case .levelTwentyFive: 25
        case .levelTwentySix: 26
        case .levelTwentySeven: 27
        case .levelTwentyEight: 28
        case .levelTwentyNine: 29
        case .levelThirty: 30
        case .levelThirtyOne: 31
        case .levelThirtyTwo: 32
        case .levelThirtyThree: 33
        case .levelThirtyFour: 34
        case .levelThirtyFive: 35
        case .levelThirtySix: 36
        case .levelThirtySeven: 37
        case .levelThirtyEight: 38
        case .levelThirtyNine: 39
        case .levelForty: 40
        case .levelFortyOne: 41
        case .levelFortyTwo: 42
        case .levelFortyThree: 43
        case .levelFortyFour: 44
        case .levelFortyFive: 45
        case .levelFortySix: 46
        case .levelFortySeven: 47
        case .levelFortyEight: 48
        case .levelFortyNine: 49
        case .levelFifty: 50
        case .levelFiftyOne: 51
        case .levelFiftyTwo: 52
        case .levelFiftyThree: 53
        case .levelFiftyFour: 54
        case .levelFiftyFive: 55
        case .levelFiftySix: 56
        case .levelFiftySeven: 57
        case .levelFiftyEight: 58
        case .levelFiftyNine: 59
        case .levelSixty: 60
        case .levelSixtyOne: 61
        case .levelSixtyTwo: 62
        case .levelSixtyThree: 63
        case .levelSixtyFour: 64
        case .levelSixtyFive: 65
        case .levelSixtySix: 66
        case .levelSixtySeven: 67
        case .levelSixtyEight: 68
        case .levelSixtyNine: 69
        case .levelSeventy: 70
        case .levelSeventyOne: 71
        case .levelSeventyTwo: 72
        case .levelSeventyThree: 73
        case .levelSeventyFour: 74
        case .levelSeventyFive: 75
        case .levelSeventySix: 76
        case .levelSeventySeven: 77
        case .levelSeventyEight: 78
        case .levelSeventyNine: 79
        case .levelEighty: 80
        case .levelEightyOne: 81
        case .levelEightyTwo: 82
        case .levelEightyThree: 83
        case .levelEightyFour: 84
        case .levelEightyFive: 85
        case .levelEightySix: 86
        case .levelEightySeven: 87
        case .levelEightyEight: 88
        case .levelEightyNine: 89
        case .levelNinety: 90
        case .levelNinetyOne: 91
        case .levelNinetyTwo: 92
        case .levelNinetyThree: 93
        case .levelNinetyFour: 94
        case .levelNinetyFive: 95
        case .levelNinetySix: 96
        case .levelNinetySeven: 97
        case .levelNinetyEight: 98
        case .levelNinetyNine: 99
        case .levelOneHundred: 100
        case .levelOneHundredOne: 101
        case .levelOneHundredTwo: 102
        case .levelOneHundredThree: 103
        case .levelOneHundredFour: 104
        case .levelOneHundredFive: 105
        case .levelOneHundredSix: 106
        case .levelOneHundredSeven: 107
        case .levelOneHundredEight: 108
        case .levelOneHundredNine: 109
        case .levelOneHundredTen: 110
        case .levelOneHundredEleven: 111
        case .levelOneHundredTwelve: 112
        case .levelOneHundredThirteen: 113
        case .levelOneHundredFourteen: 114
        case .levelOneHundredFifteen: 115
        case .levelOneHundredSixteen: 116
        case .levelOneHundredSeventeen: 117
        case .levelOneHundredEighteen: 118
        case .levelOneHundredTwenty: 120
        case .levelOneHundredTwentyOne: 121
        case .levelOneHundredTwentyTwo: 122
        case .levelOneHundredTwentyThree: 123
        case .levelOneHundredTwentyFour: 124
        case .levelOneHundredTwentyFive: 125
        case .levelOneHundredTwentySix: 126
        case .levelOneHundredTwentySeven: 127
        case .levelOneHundredTwentyEight: 128
        case .levelOneHundredTwentyNine: 129
        case .levelOneHundredThirty: 130
        case .levelOneHundredThirtyOne: 131
        case .levelOneHundredThirtyTwo: 132
        case .levelOneHundredThirtyThree: 133
        case .levelOneHundredThirtyFour: 134
        case .levelOneHundredThirtyFive: 135
        case .levelOneHundredThirtySix: 136
        case .levelOneHundredThirtySeven: 137
        case .levelOneHundredThirtyEight: 138
        case .levelOneHundredThirtyNine: 139
        case .levelOneHundredForty: 140
        case .levelOneHundredFortyOne: 141
        case .levelOneHundredFortyThree: 143
        case .levelSelect: nil
        }
    }

    /// Records the level the player is currently on as completed. Called the
    /// moment the Continue button is pressed (before navigating onward).
    private func markCurrentComplete() {
        if let n = levelNumber(for: screen) { LevelProgress.shared.markComplete(n) }
    }

    private func startLevel(number: Int) {
        guard let screenLevel = MathItCurriculum.screenLevel(forLevelNumber: number) else {
            screen = .placeholder(number)
            return
        }
        startScreenLevel(number: screenLevel)
    }

    private func startScreenLevel(number: Int) {
        switch number {
        case 1: startLevelOne()
        case 2: startLevelTwo()
        case 3: startLevelThree()
        case 4: startLevelFour()
        case 5: startLevelFive()
        case 6: startLevelSix()
        case 7: startLevelSeven()
        case 8: startLevelEight()
        case 9: startLevelNine()
        case 10: startLevelTen()
        case 11: startLevelEleven()
        case 12: startLevelTwelve()
        case 13: startLevelThirteen()
        case 14: startLevelFourteen()
        case 15: startLevelFifteen()
        case 16: startLevelSixteen()
        case 17: startLevelSeventeen()
        case 18: startLevelEighteen()
        case 19: startLevelNineteen()
        case 20: startLevelTwenty()
        case 21: startLevelTwentyOne()
        case 22: startLevelTwentyTwo()
        case 23: startLevelTwentyThree()
        case 24: startLevelTwentyFour()
        case 25: startLevelTwentyFive()
        case 26: startLevelTwentySix()
        case 27: startLevelTwentySeven()
        case 28: startLevelTwentyEight()
        case 29: startLevelTwentyNine()
        case 30: startLevelThirty()
        case 31: startLevelThirtyOne()
        case 32: startLevelThirtyTwo()
        case 33: startLevelThirtyThree()
        case 34: startLevelThirtyFour()
        case 35: startLevelThirtyFive()
        case 36: startLevelThirtySix()
        case 37: startLevelThirtySeven()
        case 38: startLevelThirtyEight()
        case 39: startLevelThirtyNine()
        case 40: startLevelForty()
        case 41: startLevelFortyOne()
        case 42: startLevelFortyTwo()
        case 43: startLevelFortyThree()
        case 44: startLevelFortyFour()
        case 45: startLevelFortyFive()
        case 46: startLevelFortySix()
        case 47: startLevelFortySeven()
        case 48: startLevelFortyEight()
        case 49: startLevelFortyNine()
        case 50: startLevelFifty()
        case 51: startLevelFiftyOne()
        case 52: startLevelFiftyTwo()
        case 53: startLevelFiftyThree()
        case 54: startLevelFiftyFour()
        case 55: startLevelFiftyFive()
        case 56: startLevelFiftySix()
        case 57: startLevelFiftySeven()
        case 58: startLevelFiftyEight()
        case 59: startLevelFiftyNine()
        case 60: startLevelSixty()
        case 61: startLevelSixtyOne()
        case 62: screen = .levelSixtyTwo
        case 63: screen = .levelSixtyThree
        case 64: screen = .levelSixtyFour
        case 65: screen = .levelSixtyFive
        case 66: screen = .levelSixtySix
        case 67: screen = .levelSixtySeven
        case 68: screen = .levelSixtyEight
        case 69: screen = .levelSixtyNine
        case 70: screen = .levelSeventy
        case 71: screen = .levelSeventyOne
        case 72: screen = .levelSeventyTwo
        case 73: screen = .levelSeventyThree
        case 74: screen = .levelSeventyFour
        case 75: screen = .levelSeventyFive
        case 76: screen = .levelSeventySix
        case 77: screen = .levelSeventySeven
        case 78: screen = .levelSeventyEight
        case 79: screen = .levelSeventyNine
        case 80: screen = .levelEighty
        case 81: screen = .levelEightyOne
        case 82: screen = .levelEightyTwo
        case 83: screen = .levelEightyThree
        case 84: screen = .levelEightyFour
        case 85: screen = .levelEightyFive
        case 86: screen = .levelEightySix
        case 87: screen = .levelEightySeven
        case 88: screen = .levelEightyEight
        case 89: screen = .levelEightyNine
        case 90: screen = .levelNinety
        case 91: screen = .levelNinetyOne
        case 92: screen = .levelNinetyTwo
        case 93: screen = .levelNinetyThree
        case 94: screen = .levelNinetyFour
        case 95: screen = .levelNinetyFive
        case 96: screen = .levelNinetySix
        case 97: screen = .levelNinetySeven
        case 98: screen = .levelNinetyEight
        case 99: screen = .levelNinetyNine
        case 100: screen = .levelOneHundred
        case 101: screen = .levelOneHundredOne
        case 102: screen = .levelOneHundredTwo
        case 103: screen = .levelOneHundredThree
        case 104: screen = .levelOneHundredFour
        case 105: screen = .levelOneHundredFive
        case 106: screen = .levelOneHundredSix
        case 107: screen = .levelOneHundredSeven
        case 108: screen = .levelOneHundredEight
        case 109: screen = .levelOneHundredNine
        case 110: screen = .levelOneHundredTen
        case 111: screen = .levelOneHundredEleven
        case 112: screen = .levelOneHundredTwelve
        case 113: screen = .levelOneHundredThirteen
        case 114: screen = .levelOneHundredFourteen
        case 115: screen = .levelOneHundredFifteen
        case 116: screen = .levelOneHundredSixteen
        case 117: screen = .levelOneHundredSeventeen
        case 118: screen = .levelOneHundredEighteen
        case 120: screen = .levelOneHundredTwenty
        case 121: screen = .levelOneHundredTwentyOne
        case 122: screen = .levelOneHundredTwentyTwo
        case 123: screen = .levelOneHundredTwentyThree
        case 124: screen = .levelOneHundredTwentyFour
        case 125: screen = .levelOneHundredTwentyFive
        case 126: screen = .levelOneHundredTwentySix
        case 127: screen = .levelOneHundredTwentySeven
        case 128: screen = .levelOneHundredTwentyEight
        case 129: screen = .levelOneHundredTwentyNine
        case 130: screen = .levelOneHundredThirty
        case 131: screen = .levelOneHundredThirtyOne
        case 132: screen = .levelOneHundredThirtyTwo
        case 133: screen = .levelOneHundredThirtyThree
        case 134: screen = .levelOneHundredThirtyFour
        case 135: screen = .levelOneHundredThirtyFive
        case 136: screen = .levelOneHundredThirtySix
        case 137: screen = .levelOneHundredThirtySeven
        case 138: screen = .levelOneHundredThirtyEight
        case 139: screen = .levelOneHundredThirtyNine
        case 140: screen = .levelOneHundredForty
        case 141: screen = .levelOneHundredFortyOne
        case 143: startLevelOneHundredFortyThree()
        default: break
        }
    }

    private func startLevelOne() {
        levelOneViewModel = MathItLevelOneViewModel()
        screen = .levelOne
    }

    private func startLevelTwo() {
        levelTwoViewModel = MathItLevelTwoViewModel()
        screen = .levelTwo
    }

    private func startLevelThree() {
        levelThreeViewModel = MathItLevelThreeViewModel()
        screen = .levelThree
    }

    private func startLevelFour() {
        levelFourViewModel = MathItLevelFourViewModel()
        screen = .levelFour
    }

    private func startLevelFive() {
        levelFiveViewModel = MathItLevelFiveViewModel()
        screen = .levelFive
    }

    private func startLevelSix() {
        levelSixViewModel = MathItLevelSixViewModel()
        screen = .levelSix
    }

    private func startLevelSeven() {
        levelSevenViewModel = MathItLevelSevenViewModel()
        screen = .levelSeven
    }

    private func startLevelEight() {
        screen = .levelOneHundredThree
    }

    private func startLevelNine() {
        levelNineViewModel = MathItLevelNineViewModel()
        screen = .levelNine
    }

    private func startLevelTen() {
        levelTenViewModel = MathItLevelTenViewModel()
        screen = .levelTen
    }

    private func startLevelEleven() {
        levelElevenViewModel = MathItLevelElevenViewModel()
        screen = .levelEleven
    }

    private func startLevelTwelve() {
        levelTwelveViewModel = MathItLevelTwelveViewModel()
        screen = .levelTwelve
    }

    private func startLevelThirteen() {
        levelThirteenViewModel = MathItLevelThirteenViewModel()
        screen = .levelThirteen
    }

    private func startLevelFourteen() {
        levelFourteenViewModel = MathItLevelFourteenViewModel()
        screen = .levelFourteen
    }

    private func startLevelFifteen() {
        levelFifteenViewModel = MathItLevelFifteenViewModel()
        screen = .levelFifteen
    }

    private func startLevelSixteen() {
        levelSixteenViewModel = MathItLevelSixteenViewModel()
        screen = .levelSixteen
    }

    private func startLevelSeventeen() {
        levelSeventeenViewModel = MathItLevelSeventeenViewModel()
        screen = .levelSeventeen
    }

    private func startLevelEighteen() {
        levelEighteenViewModel = MathItLevelEighteenViewModel()
        screen = .levelEighteen
    }

    private func startLevelNineteen() {
        levelNineteenViewModel = MathItLevelNineteenViewModel()
        screen = .levelNineteen
    }

    private func startLevelTwenty() {
        levelTwentyViewModel = MathItLevelTwentyViewModel()
        screen = .levelTwenty
    }

    private func startLevelTwentyOne() {
        levelTwentyOneViewModel = MathItLevelTwentyOneViewModel()
        screen = .levelTwentyOne
    }

    private func startLevelTwentyTwo() {
        levelTwentyTwoViewModel = MathItLevelTwentyTwoViewModel()
        screen = .levelTwentyTwo
    }

    private func startLevelTwentyThree() {
        levelTwentyThreeViewModel = MathItLevelTwentyThreeViewModel()
        screen = .levelTwentyThree
    }

    private func startLevelTwentyFour() {
        levelTwentyFourViewModel = MathItLevelTwentyFourViewModel()
        screen = .levelTwentyFour
    }

    private func startLevelTwentyFive() {
        levelTwentyFiveViewModel = MathItLevelTwentyFiveViewModel()
        screen = .levelTwentyFive
    }

    private func startLevelTwentySix() {
        levelTwentySixViewModel = MathItLevelTwentySixViewModel()
        screen = .levelTwentySix
    }

    private func startLevelTwentySeven() {
        levelTwentySevenViewModel = MathItLevelTwentySevenViewModel()
        screen = .levelTwentySeven
    }

    private func startLevelTwentyEight() {
        levelTwentyEightViewModel = MathItLevelTwentyEightViewModel()
        screen = .levelTwentyEight
    }

    private func startLevelTwentyNine() {
        levelTwentyNineViewModel = MathItLevelTwentyNineViewModel()
        screen = .levelTwentyNine
    }

    private func startLevelThirty() {
        levelThirtyViewModel = MathItLevelThirtyViewModel()
        screen = .levelThirty
    }

    private func startLevelThirtyOne() {
        levelThirtyOneViewModel = MathItLevelThirtyOneViewModel()
        screen = .levelThirtyOne
    }

    private func startLevelThirtyTwo() {
        levelThirtyTwoViewModel = MathItLevelThirtyTwoViewModel()
        screen = .levelThirtyTwo
    }

    private func startLevelThirtyThree() {
        levelThirtyThreeViewModel = MathItLevelThirtyThreeViewModel()
        screen = .levelThirtyThree
    }

    private func startLevelThirtyFour() {
        levelThirtyFourViewModel = MathItLevelThirtyFourViewModel()
        screen = .levelThirtyFour
    }

    private func startLevelThirtyFive() {
        levelThirtyFiveViewModel = MathItLevelThirtyFiveViewModel()
        screen = .levelThirtyFive
    }

    private func startLevelThirtySix() {
        levelThirtySixViewModel = MathItLevelThirtySixViewModel()
        screen = .levelThirtySix
    }

    private func startLevelThirtySeven() {
        levelThirtySevenViewModel = MathItLevelThirtySevenViewModel()
        screen = .levelThirtySeven
    }

    private func startLevelThirtyEight() {
        levelThirtyEightViewModel = MathItLevelThirtyEightViewModel()
        screen = .levelThirtyEight
    }

    private func startLevelThirtyNine() {
        levelThirtyNineViewModel = MathItLevelThirtyNineViewModel()
        screen = .levelThirtyNine
    }

    private func startLevelForty() {
        levelFortyViewModel = MathItLevelFortyViewModel()
        screen = .levelForty
    }

    private func startLevelFortyOne() {
        levelFortyOneViewModel = MathItLevelFortyOneViewModel()
        screen = .levelFortyOne
    }

    private func startLevelFortyTwo() {
        levelFortyTwoViewModel = MathItLevelThirtyThreeViewModel()
        screen = .levelFortyTwo
    }

    private func startLevelFortyThree() {
        levelFortyThreeViewModel = MathItLevelFortyThreeViewModel()
        screen = .levelFortyThree
    }

    private func startLevelFortyFour() {
        levelFortyFourViewModel = MathItLevelFortyFourViewModel()
        screen = .levelFortyFour
    }

    private func startLevelFortyFive() {
        levelFortyFiveViewModel = MathItLevelFortyFiveViewModel()
        screen = .levelFortyFive
    }

    private func startLevelFortySix() {
        levelFortySixViewModel = MathItLevelFortySixViewModel()
        screen = .levelFortySix
    }

    private func startLevelFortySeven() {
        levelFortySevenViewModel = MathItLevelFortySevenViewModel()
        screen = .levelFortySeven
    }

    private func startLevelFortyEight() {
        levelFortyEightViewModel = MathItLevelFortyEightViewModel()
        screen = .levelFortyEight
    }

    private func startLevelFortyNine() {
        levelFortyNineViewModel = MathItLevelFortyNineViewModel()
        screen = .levelFortyNine
    }

    private func startLevelFifty() {
        levelFiftyViewModel.cancelTimer()
        levelFiftyViewModel = MathItLevelFiftyViewModel()
        screen = .levelFifty
    }

    private func startLevelFiftyOne() {
        levelFiftyOneViewModel.cancelTimer()
        levelFiftyOneViewModel = MathItLevelFiftyOneViewModel()
        screen = .levelFiftyOne
    }

    private func startLevelFiftyTwo() {
        levelFiftyTwoViewModel = MathItLevelFiftyTwoViewModel()
        screen = .levelFiftyTwo
    }

    private func startLevelFiftyThree() {
        levelFiftyThreeViewModel = MathItLevelFiftyThreeViewModel()
        screen = .levelFiftyThree
    }

    private func startLevelFiftyFour() {
        levelFiftyFourViewModel = MathItLevelFiftyFourViewModel()
        screen = .levelFiftyFour
    }

    private func startLevelFiftyFive() {
        levelFiftyFiveViewModel = MathItLevelFiftyFiveViewModel()
        screen = .levelFiftyFive
    }

    private func startLevelFiftySix() {
        levelFiftySixViewModel = MathItLevelFiftySixViewModel()
        screen = .levelFiftySix
    }

    private func startLevelFiftySeven() {
        levelFiftySevenViewModel = MathItLevelFiftySevenViewModel()
        screen = .levelFiftySeven
    }

    private func startLevelFiftyEight() {
        levelFiftyEightViewModel = MathItLevelFiftyEightViewModel()
        screen = .levelFiftyEight
    }

    private func startLevelFiftyNine() {
        levelFiftyNineViewModel = MathItLevelFiftyNineViewModel()
        screen = .levelFiftyNine
    }

    private func startLevelSixty() {
        levelSixtyViewModel = MathItLevelSixtyViewModel()
        screen = .levelSixty
    }

    private func startLevelSixtyOne() {
        levelSixtyOneViewModel = MathItLevelSixtyOneViewModel()
        screen = .levelSixtyOne
    }

    private func startLevelOneHundredFortyThree() {
        levelOneHundredFortyThreeViewModel = MathItLevelFiftySevenViewModel()
        screen = .levelOneHundredFortyThree
    }
}

private struct LevelStepControl: View {
    @Environment(\.mathItAccent) private var accent

    let levelNumber: Int
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            stepButton(systemName: "chevron.left", enabled: canGoBack, action: onBack)

            Text("\(levelNumber)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .frame(minWidth: 34)

            stepButton(systemName: "chevron.right", enabled: canGoForward, action: onForward)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.82), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.48), lineWidth: 1.1))
        .shadow(color: accent.opacity(0.22), radius: 14)
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(enabled ? accent : .white.opacity(0.22))
                .frame(width: 38, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous level" : "Next level")
    }
}

#Preview {
    ContentView()
}
