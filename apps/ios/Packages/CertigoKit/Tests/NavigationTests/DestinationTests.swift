// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Le test qui rougit si une destination redevient orpheline.
//
// Côté Flutter, la même garantie existe — mais elle coûte un test de 417
// lignes qui lit le code source et calcule la fermeture des écrans réellement
// construits (`apps/mobile/test/navigation_reachability_guard_test.dart`,
// mesuré le 2026-09-11 : les douze destinations sont bien atteignables).
//
// Ici, `home(for:)` est un `switch` exhaustif : une destination sans domicile
// ne compile pas, gratuitement. Ces tests vérifient la partie que le
// compilateur ne peut pas voir : le nombre d'onglets, l'unicité des chemins,
// et le fait qu'ouvrir une destination groupée change bien d'onglet.

import XCTest

@testable import Navigation

final class DestinationTests: XCTestCase {
    /// Les douze destinations de premier niveau sont là.
    func testTwelveTopLevelDestinations() {
        XCTAssertEqual(Destination.allCases.count, 12)
    }

    /// Chaque destination a un domicile. Exhaustif par construction, mais le
    /// test documente l'invariant et échouerait si `home(for:)` gagnait un
    /// `default` qui reviendrait à désarmer le dispositif.
    func testEveryDestinationHasAHome() {
        for destination in Destination.allCases {
            let resolved = home(for: destination)
            XCTAssertTrue(
                tabDestinations.contains(resolved.tab),
                "\(destination.rawValue) est hébergée par un onglet qui n'existe pas."
            )
        }
    }

    /// La barre d'onglets en compte exactement cinq, dans cet ordre.
    func testFiveTabsInDeclaredOrder() {
        XCTAssertEqual(
            tabDestinations,
            [.home, .path, .library, .leaderboard, .profile]
        )
    }

    /// Les sept autres sont atteintes par empilement, jamais en racine.
    func testSevenDestinationsAreGrouped() {
        let grouped = Destination.allCases.filter {
            if case .grouped = home(for: $0) { return true }
            return false
        }
        XCTAssertEqual(grouped.count, 7)
        XCTAssertEqual(
            Set(grouped),
            [.achievements, .seasons, .quests, .shop, .friends, .exam, .dailyShare]
        )
    }

    /// Deux destinations ne peuvent pas partager un chemin : un lien profond
    /// ambigu arriverait au hasard.
    func testPathsAreUniqueAndAbsolute() {
        let paths = Destination.allCases.map(\.path)
        XCTAssertEqual(Set(paths).count, paths.count, "Deux destinations partagent un chemin.")
        for path in paths {
            XCTAssertTrue(path.hasPrefix("/"), "\(path) n'est pas un chemin absolu.")
            XCTAssertFalse(path.hasSuffix("/"), "\(path) se termine par une barre oblique.")
        }
    }

    /// Les chemins sont ceux du routeur Dart, relevés le 2026-09-11. Ils ne
    /// sont pas libres : `certigo://` doit arriver au même endroit sur les deux
    /// plateformes.
    func testPathsMatchTheDartRouter() {
        XCTAssertEqual(Destination.home.path, "/home")
        XCTAssertEqual(Destination.path.path, "/path")
        XCTAssertEqual(Destination.library.path, "/library")
        XCTAssertEqual(Destination.leaderboard.path, "/leaderboard")
        XCTAssertEqual(Destination.profile.path, "/profile")
        XCTAssertEqual(Destination.dailyShare.path, "/share-daily")
    }

    /// Chaque destination a un libellé français non vide.
    func testEveryDestinationIsLabelled() {
        for destination in Destination.allCases {
            XCTAssertFalse(
                destination.title.isEmpty,
                "\(destination.rawValue) n'a pas de libellé."
            )
        }
    }
}

final class AppRouterTests: XCTestCase {
    /// Au départ, l'accueil est actif et aucune pile n'est entamée.
    @MainActor
    func testInitialStateIsCleanHome() {
        let router = AppRouter()
        XCTAssertEqual(router.selectedTab, .home)
        for tab in tabDestinations {
            XCTAssertEqual(router.stacks[tab], [], "\(tab.rawValue) démarre avec une pile.")
        }
    }

    /// Ouvrir une destination groupée change d'onglet **et** empile.
    @MainActor
    func testOpeningAGroupedDestinationSwitchesTabAndPushes() {
        let router = AppRouter()
        router.open(.shop)
        XCTAssertEqual(router.selectedTab, .profile)
        XCTAssertEqual(router.stacks[.profile], [.shop])
        XCTAssertEqual(router.stacks[.leaderboard], [])
    }

    /// Ouvrir un onglet ne l'empile pas sur lui-même.
    @MainActor
    func testOpeningATabDoesNotPush() {
        let router = AppRouter()
        router.open(.library)
        XCTAssertEqual(router.selectedTab, .library)
        XCTAssertEqual(router.stacks[.library], [])
    }

    /// Chaque onglet garde sa propre profondeur : changer d'onglet n'efface
    /// pas la pile de celui que l'on quitte.
    @MainActor
    func testEachTabKeepsItsOwnStack() {
        let router = AppRouter()
        router.open(.shop)
        router.open(.friends)
        XCTAssertEqual(router.selectedTab, .leaderboard)
        XCTAssertEqual(router.stacks[.profile], [.shop], "La pile du profil a été perdue.")
        XCTAssertEqual(router.stacks[.leaderboard], [.friends])
    }

    /// Le retour ne dépile que l'onglet actif.
    @MainActor
    func testPopOnlyAffectsTheActiveTab() {
        let router = AppRouter()
        router.open(.shop)
        router.open(.seasons)
        XCTAssertEqual(router.stacks[.profile], [.shop, .seasons])
        router.pop()
        XCTAssertEqual(router.stacks[.profile], [.shop])
        router.popToRoot()
        XCTAssertEqual(router.stacks[.profile], [])
    }

    /// Un lien profond connu se résout ; un lien inconnu rend `nil`.
    ///
    /// Il ne redirige **pas** vers l'accueil : un lien cassé doit être visible
    /// comme cassé, pas déguisé en navigation réussie.
    @MainActor
    func testDeepLinkResolution() {
        XCTAssertEqual(AppRouter.destination(forPath: "/share-daily"), .dailyShare)
        XCTAssertEqual(AppRouter.destination(forPath: "share-daily"), .dailyShare)
        XCTAssertEqual(AppRouter.destination(forPath: "/exam"), .exam)
        XCTAssertNil(AppRouter.destination(forPath: "/route-inventee"))
        XCTAssertNil(AppRouter.destination(forPath: ""))
    }
}
