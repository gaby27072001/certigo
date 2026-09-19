// swift-tools-version: 6.0
//
// NON COMPILÉ — écrit depuis Windows ARM64, où ni `swift`, ni `swiftc`, ni
// `xcodebuild` n'existent, et où SwiftUI/UIKit ne peuvent pas exister. La
// première compilation de ce fichier aura lieu sur le Mac. Voir DEMARRAGE.md.
//
// Le mode de langage Swift 6 (concurrence stricte) est le défaut à partir de
// tools-version 6.0 : il est donc actif dès la première ligne, comme exigé.

import PackageDescription

let package = Package(
    name: "CertigoKit",
    platforms: [
        // iOS 17 : plancher exigé par @Observable et NavigationStack (ADR-024).
        //
        // macOS 14 : uniquement pour que `swift test` tourne sans simulateur,
        // ce qui donne une boucle rouge/vert sans passer par le projet Xcode.
        //
        // ⚠️ NE PAS ABAISSER macOS 14. Vérifié le 2026-09-19 contre les données
        // de documentation d'Apple : toute la pile `@Observable` y est
        // exactement — `@Observable` (macOS 14.0), `@Bindable` (14.0),
        // `@Environment(T.self)` (14.0) et `.environment(instance)` (14.0).
        // Zéro marge : abaisser cette ligne casse les quatre d'un coup.
        //
        // Le reste de la surface SwiftUI du paquet a été vérifié au même
        // moment (40 symboles) : aucun n'est indisponible sur macOS, aucun
        // n'exige macOS 15. Le chrome iOS 26, lui, est gardé par `#if os(iOS)`
        // dans PrismGlass.swift — voir l'en-tête de ce fichier.
        //
        // `tools/tests/test_ios_detection.py` fait échouer toute baisse.
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Navigation", targets: ["Navigation"]),
        .library(name: "APIClient", targets: ["APIClient"]),
    ],
    // Aucune dépendance externe, volontairement. Le premier démarrage sur le
    // Mac ne doit dépendre d'aucune résolution réseau : chaque paquet distant
    // est un mode de panne de plus le soir où il faut que ça marche.
    dependencies: [],
    targets: [
        .target(name: "DesignSystem"),
        .target(name: "Navigation"),
        .target(name: "APIClient"),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "NavigationTests", dependencies: ["Navigation"]),
        .testTarget(name: "APIClientTests", dependencies: ["APIClient"]),
    ]
)
