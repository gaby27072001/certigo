// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Équivalent natif de `StatefulShellRoute.indexedStack` : **une pile par
// onglet**, jamais une pile globale. Changer d'onglet ne doit pas effacer la
// profondeur de navigation de l'onglet quitté.

import Observation
import SwiftUI

/// Le routeur de la coquille.
///
/// `@Observable` et non `ObservableObject` : la granularité de suivi est plus
/// fine, donc une vue qui ne lit qu'un onglet ne se recompose pas quand un
/// autre change.
@Observable
@MainActor
public final class AppRouter {
    /// L'onglet actif.
    public var selectedTab: Destination

    /// Une pile par onglet, indexée par la destination de l'onglet.
    public private(set) var stacks: [Destination: [Destination]]

    public init(selectedTab: Destination = .home) {
        self.selectedTab = selectedTab
        var initial: [Destination: [Destination]] = [:]
        for tab in tabDestinations { initial[tab] = [] }
        self.stacks = initial
    }

    /// Ouvre une destination **à son domicile**, en changeant d'onglet au
    /// besoin. C'est le seul point d'entrée de la navigation : il n'existe
    /// aucun moyen d'ouvrir un écran hors de la coquille par accident.
    public func open(_ destination: Destination) {
        let destinationHome = home(for: destination)
        selectedTab = destinationHome.tab
        if case .grouped(let child, let parent) = destinationHome {
            stacks[parent, default: []].append(child)
        }
    }

    /// Revient d'un cran dans l'onglet actif.
    public func pop() {
        stacks[selectedTab]?.removeLast()
    }

    /// Vide la pile de l'onglet actif — le geste « retaper l'onglet actif ».
    public func popToRoot() {
        stacks[selectedTab] = []
    }

    /// La pile d'un onglet, pour liaison à un `NavigationStack`.
    public func binding(for tab: Destination) -> Binding<[Destination]> {
        Binding(
            get: { [weak self] in self?.stacks[tab] ?? [] },
            set: { [weak self] newValue in self?.stacks[tab] = newValue }
        )
    }

    /// Résout un lien profond `certigo://…` vers une destination connue.
    ///
    /// Retourne `nil` plutôt que de deviner : un lien inconnu doit être visible
    /// comme tel, pas rediriger silencieusement vers l'accueil.
    public static func destination(forPath rawPath: String) -> Destination? {
        let normalized = rawPath.hasPrefix("/") ? rawPath : "/" + rawPath
        return Destination.allCases.first { $0.path == normalized }
    }
}
