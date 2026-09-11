// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// Le squelette du client d'API. Il ne parle à rien : il n'y a **aucune** URL
// de production ici, aucun jeton, aucun secret.
//
// Ce qui est posé, en revanche, c'est la forme : un **témoin de protocole en
// `struct` à fermetures**, et non un protocole avec des classes de simulation.
// Raison : un cas de test remplace **un seul champ** et laisse les autres en
// `.failing`. Avec des protocoles, chaque cas exige une classe complète — et
// sur un projet où l'agent écrit sans pouvoir exécuter, le coût d'écriture
// d'un test est une variable de premier ordre.

import Foundation

/// L'unique type d'erreur du domaine.
///
/// La correspondance HTTP → domaine est **une donnée**, pas une cascade de
/// `if` dispersée dans les écrans : les deux plateformes doivent afficher le
/// même message pour le même 409.
public enum CertigoError: Error, Equatable, Sendable {
    /// Le réseau n'a pas répondu, ou la requête a été annulée par le système.
    case network
    /// Le serveur a mis trop de temps. **Distinct de `.network`** : ne jamais
    /// accuser le réseau quand c'est le serveur qui est lent.
    case timeout
    /// Le jeton est absent, expiré, ou refusé.
    case unauthorized
    /// L'utilisateur est authentifié mais n'a pas le droit.
    case forbidden
    /// La ressource demandée n'existe pas.
    case notFound
    /// Conflit d'état — typiquement une soumission déjà enregistrée.
    case conflict
    /// Trop de requêtes. Porte le délai indiqué par le serveur s'il en donne un.
    case rateLimited(retryAfter: TimeInterval?)
    /// Le serveur a échoué.
    case server(status: Int)
    /// La réponse n'a pas le format attendu par le contrat.
    case decoding

    /// Correspondance depuis un code HTTP.
    ///
    /// Les codes non répertoriés deviennent `.server`, jamais `.network` : une
    /// erreur applicative déguisée en panne réseau envoie l'utilisateur
    /// vérifier son wifi pour rien.
    public static func fromStatus(_ status: Int, retryAfter: TimeInterval? = nil) -> CertigoError {
        switch status {
        case 401: .unauthorized
        case 403: .forbidden
        case 404: .notFound
        case 409: .conflict
        case 429: .rateLimited(retryAfter: retryAfter)
        case 408, 504: .timeout
        default: .server(status: status)
        }
    }

    /// Une reprise automatique a-t-elle un sens ?
    ///
    /// Un 409 n'est **jamais** rejoué : la soumission de quiz est idempotente
    /// par `clientAttemptId`, et rejouer un conflit masquerait une vraie
    /// divergence d'état.
    public var isRetryable: Bool {
        switch self {
        case .network, .timeout, .rateLimited: true
        case .server(let status): status >= 500
        case .unauthorized, .forbidden, .notFound, .conflict, .decoding: false
        }
    }
}

/// La politique de reprise, **unique et centralisée**.
///
/// Elle vit dans le transport, jamais dans un Store : une politique par appelant
/// est une politique qui diverge.
public struct RetryPolicy: Sendable, Equatable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval

    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 0.5, maxDelay: TimeInterval = 8) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    public static let standard = RetryPolicy()

    /// Délai avant la tentative `attempt` (1 = première reprise), en secondes,
    /// **sans** la gigue. Croissance exponentielle, plafonnée.
    ///
    /// La gigue est ajoutée par l'appelant afin que cette fonction reste
    /// déterministe — donc testable.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt >= 1 else { return 0 }
        let exponential = baseDelay * pow(2, Double(attempt - 1))
        return min(exponential, maxDelay)
    }

    /// Faut-il retenter après cette erreur, à cette tentative ?
    ///
    /// Un `Retry-After` du serveur l'emporte toujours sur le calcul local.
    public func shouldRetry(_ error: CertigoError, attempt: Int) -> Bool {
        attempt < maxAttempts && error.isRetryable
    }
}

/// Le client d'API, sous forme de témoin substituable.
///
/// **Squelette** : aucune implémentation `.live`. Elle sera engendrée depuis
/// `docs/contracts/<domaine>/v1/openapi.json` par `swift-openapi-generator`,
/// qui n'est volontairement pas encore une dépendance de ce paquet.
public struct APIClient: Sendable {
    /// Vérifie que le service répond. Le seul appel du squelette.
    public var health: @Sendable () async throws -> Bool

    public init(health: @escaping @Sendable () async throws -> Bool) {
        self.health = health
    }

    /// Échoue systématiquement. C'est le **défaut des tests** : un test qui
    /// n'a pas explicitement remplacé un champ ne doit pas toucher le réseau
    /// par accident.
    public static let failing = APIClient(health: { throw CertigoError.network })

    /// Répond toujours favorablement, pour les aperçus SwiftUI.
    public static let previewing = APIClient(health: { true })
}
