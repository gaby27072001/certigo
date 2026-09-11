// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// `LoadState` est la contrainte de type centrale de l'architecture retenue.
// Elle n'est pas une convention : le cas d'échec **porte son action de reprise
// dans sa signature**, donc il est impossible de produire un état d'erreur sans
// offrir une reprise à l'utilisateur.
//
// C'est la réponse structurelle à un défaut réel et mesuré côté Flutter : un
// écran affichait une erreur sans aucun moyen de réessayer, et rien dans le
// code ne pouvait le signaler.

import SwiftUI

/// Une erreur telle que l'interface doit la présenter.
///
/// Volontairement **détachée du transport** : `APIClient` ne connaît pas le
/// système de design, et le système de design ne connaît pas HTTP. La table de
/// correspondance entre les deux vit dans la racine de composition, où elle est
/// lisible d'un coup d'œil — et non dispersée dans les écrans.
public struct LoadFailure: Sendable, Equatable {
    /// Titre court, en français, lisible par un humain.
    public let title: String
    /// Explication d'une à deux phrases. Jamais un code d'erreur brut.
    public let message: String
    /// Libellé du bouton de reprise.
    public let retryLabel: String

    public init(title: String, message: String, retryLabel: String = "Réessayer") {
        self.title = title
        self.message = message
        self.retryLabel = retryLabel
    }
}

/// L'état de chargement d'une section d'écran.
///
/// Générique sur la valeur chargée. **Une section, un `LoadState`** : une page
/// entière qui bascule en erreur parce qu'un seul de trois appels a échoué est
/// interdite par l'architecture (agrégation partielle).
public enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    /// L'échec **exige** une action de reprise. C'est tout l'intérêt du type.
    case failed(LoadFailure, retry: @MainActor () -> Void)

    /// La valeur, si elle est chargée.
    public var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    /// Vrai tant que rien n'est affichable.
    public var isSettled: Bool {
        switch self {
        case .idle, .loading: false
        case .loaded, .failed: true
        }
    }
}
