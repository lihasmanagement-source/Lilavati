# Lilavati

Lilavati is an iOS math learning app that turns abstract math concepts into short, playable visual levels. Instead of presenting math only as formulas, each level gives the learner a small interaction, puzzle, simulation, or game that makes the underlying idea visible.

This OpenAI Build Week submission focuses on five interactive levels built and refined with Codex.

## Featured Build Week Levels

These are the levels I would like reviewed for the competition. They used ChatGPT 5.6 during development, and Codex was used for the entire project. Reviewers are welcome to explore the other levels too.

| App Level | Concept | Source File | Interaction |
|---|---|---|---|
| 3 | Fractions | `Lilavati/Level003_Fractions.swift` | Place fractions on strings and use them to play a guided melody. |
| 24 | Piecewise Functions | `Lilavati/Level024_PiecewiseFunctions.swift` | Drag skatepark pieces into position, then watch the skater ride across the graph. |
| 44 | Area and Perimeter | `Lilavati/Level044_PerimeterAndArea.swift` | Manipulate shapes and compare how perimeter and area change. |
| 84 | Derivatives | `Lilavati/DerivativesLevel.swift` | Explore instantaneous rate of change through an interactive visual challenge. |
| 97 | 3D Coordinates | `Lilavati/Level097_3DCoordinates.swift` | Play an interactive 3D coordinate game by selecting cubes in space. |

## Codex Details

- Codex was used throughout the project for design iteration, SwiftUI implementation, debugging, polish, and README preparation.
- This conversation's Codex thread ID is `019f62d9-3e7d-75b0-a773-9e998836f2ba`.

## Requirements

- macOS
- Xcode
- iOS Simulator or iPhone
- iOS deployment target: iOS 18.5

## How To Open And Run

1. Clone the repository from GitHub.
2. Open `Lilavati.xcodeproj` in Xcode.
3. In the project navigator, open the `Lilavati` source folder.
4. Select the `Lilavati` target / `Lilavati.app` product.
5. Choose an iOS Simulator or connected iPhone.
6. Press Run.

The app should launch into the Lilavati experience, where the submitted levels can be accessed through the level selection interface.

## Project Goal

The goal of Lilavati is to make math feel playable, visual, and memorable. Each level tries to answer one question: what would this concept feel like if you could touch it?
