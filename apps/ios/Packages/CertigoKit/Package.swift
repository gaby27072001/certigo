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
        // macOS 14 : uniquement pour que `swift test` tourne sans simulateur,
        // ce qui donne une boucle rouge/vert sans passer par le projet Xcode.
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
