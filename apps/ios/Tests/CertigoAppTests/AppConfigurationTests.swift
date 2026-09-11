// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Ces tests portent sur la **configuration de l'application**, pas sur son
// code. C'est la seule chose que le paquet `CertigoKit` ne peut pas vérifier,
// et c'est une classe de panne qui a déjà failli coûter cher ailleurs : une
// clé absente d'`Info.plist` ne produit aucune erreur de compilation, aucun
// avertissement, et se manifeste par une application qui ne démarre pas, ou
// qui démarre en boîte aux lettres.
//
// Comme le plist est **généré par XcodeGen**, ces tests vérifient en réalité
// que `project.yml` dit ce qu'on croit qu'il dit.

import XCTest

final class AppConfigurationTests: XCTestCase {
    private var info: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    /// L'application ne porte pas l'identifiant de l'application Flutter.
    ///
    /// Un identifiant identique **remplacerait** Certigo sur l'appareil de
    /// test. Tant que les deux coexistent, ils doivent rester distincts.
    func testBundleIdentifierDoesNotCollideWithFlutterApp() {
        let identifier = Bundle.main.bundleIdentifier
        XCTAssertEqual(identifier, "com.certigo.native")
        XCTAssertNotEqual(
            identifier, "com.certigo.mobileapp",
            "Cet identifiant écraserait l'application Flutter en production."
        )
    }

    /// Liquid Glass n'est pas désactivé.
    ///
    /// `UIDesignRequiresCompatibility` à `true` ferait rendre l'application
    /// comme si elle était compilée contre un ancien SDK — donc **sans** le
    /// matériau natif. C'est exactement ce qu'on ne veut pas, et c'est le
    /// genre de clé qu'on ajoute « temporairement » puis qu'on oublie.
    func testLiquidGlassIsNotOptedOut() {
        XCTAssertNil(
            info["UIDesignRequiresCompatibility"],
            "L'application a désactivé le design du système. Liquid Glass ne s'appliquera pas."
        )
    }

    /// La scène est déclarée.
    ///
    /// iOS 27 exige l'adoption d'UIScene : sans `UIApplicationSceneManifest`,
    /// une application compilée contre les SDK récents **ne se lance plus**.
    /// Le cycle de vie SwiftUI la fournit, mais la clé doit être présente.
    func testSceneManifestIsDeclared() {
        XCTAssertNotNil(
            info["UIApplicationSceneManifest"],
            "Sans manifeste de scène, l'application ne se lancera pas sur iOS 27."
        )
    }

    /// L'écran de lancement est déclaré.
    ///
    /// Sans `UILaunchScreen`, iOS affiche l'application en boîte aux lettres,
    /// dans le gabarit d'un vieil iPhone, au lieu d'occuper l'écran.
    func testLaunchScreenIsDeclared() {
        XCTAssertNotNil(
            info["UILaunchScreen"],
            "Sans écran de lancement, l'application s'affiche en boîte aux lettres."
        )
    }

    /// La version est renseignée et non vide.
    func testVersionsArePresent() {
        XCTAssertEqual(info["CFBundleShortVersionString"] as? String, "0.1.0")
        XCTAssertFalse((info["CFBundleVersion"] as? String ?? "").isEmpty)
    }

    /// Aucun secret ni aucune URL de service ne se sont glissés dans le plist.
    ///
    /// Une configuration de production dans un bundle est lisible par
    /// quiconque télécharge l'application. Le squelette n'en a aucune, et ce
    /// test existe pour que cela reste vrai.
    func testNoSecretsLeakedIntoTheBundle() {
        let forbidden = ["apiKey", "clientSecret", "connectionString", "CERTIGO_API_KEY"]
        for key in forbidden {
            XCTAssertNil(info[key], "La clé \(key) n'a rien à faire dans Info.plist.")
        }
        let serialized = String(describing: info).lowercased()
        XCTAssertFalse(
            serialized.contains("azurewebsites.net"),
            "Une URL de service est présente dans Info.plist."
        )
    }
}
