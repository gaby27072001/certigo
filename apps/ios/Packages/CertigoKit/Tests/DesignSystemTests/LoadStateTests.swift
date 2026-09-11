// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Ce que ces tests protègent n'est pas un comportement, c'est une **contrainte
// de type** : il doit rester impossible de produire un état d'erreur sans
// fournir l'action de reprise qui va avec.
//
// Le jour où quelqu'un rendra `retry` optionnel, ces tests ne rougiront pas —
// c'est le compilateur qui refusera le code appelant. Ces tests vérifient la
// moitié que le compilateur ne voit pas : que la reprise est réellement
// branchée, et pas une fermeture vide.

import XCTest

@testable import DesignSystem

final class LoadStateTests: XCTestCase {
    /// Les états non réglés ne présentent rien à l'utilisateur.
    func testIdleAndLoadingAreNotSettled() {
        XCTAssertFalse(LoadState<Int>.idle.isSettled)
        XCTAssertFalse(LoadState<Int>.loading.isSettled)
        XCTAssertNil(LoadState<Int>.idle.value)
        XCTAssertNil(LoadState<Int>.loading.value)
    }

    /// L'état chargé rend sa valeur.
    func testLoadedCarriesItsValue() {
        let state = LoadState<Int>.loaded(42)
        XCTAssertTrue(state.isSettled)
        XCTAssertEqual(state.value, 42)
    }

    /// L'échec est un état réglé — l'écran doit afficher quelque chose — mais
    /// il ne porte aucune valeur.
    @MainActor
    func testFailedIsSettledButHasNoValue() {
        let state = LoadState<Int>.failed(
            LoadFailure(title: "Titre", message: "Message"), retry: {})
        XCTAssertTrue(state.isSettled)
        XCTAssertNil(state.value)
    }

    /// La reprise transportée par l'état est bien celle qui s'exécute.
    ///
    /// C'est la vérification qui compte : une fermeture présente mais vide
    /// satisferait le compilateur et tromperait l'utilisateur.
    @MainActor
    func testRetryClosureIsActuallyInvoked() {
        var invocations = 0
        let state = LoadState<Int>.failed(
            LoadFailure(title: "Titre", message: "Message"),
            retry: { invocations += 1 }
        )
        guard case .failed(_, let retry) = state else {
            return XCTFail("L'état construit n'est pas un échec.")
        }
        retry()
        retry()
        XCTAssertEqual(invocations, 2)
    }

    /// Le libellé de reprise a un défaut en français, et reste remplaçable.
    func testRetryLabelDefaultsToFrench() {
        XCTAssertEqual(LoadFailure(title: "T", message: "M").retryLabel, "Réessayer")
        XCTAssertEqual(
            LoadFailure(title: "T", message: "M", retryLabel: "Recharger").retryLabel,
            "Recharger"
        )
    }

    /// Un échec ne doit jamais exposer un code brut à l'utilisateur : le titre
    /// et le message sont du texte, et ils ne sont pas vides.
    func testFailureTextIsHumanReadable() {
        let failure = LoadFailure(
            title: "Impossible de charger",
            message: "Le serveur n'a pas répondu."
        )
        XCTAssertFalse(failure.title.isEmpty)
        XCTAssertFalse(failure.message.isEmpty)
        XCTAssertFalse(failure.message.contains("Error Domain"))
    }
}
