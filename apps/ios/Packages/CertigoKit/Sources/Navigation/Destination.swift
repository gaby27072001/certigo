// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// C'est le fichier qui justifie le passage au natif à lui seul.
//
// Le problème mesuré côté Flutter : dans `go_router`, les routes sont
// enregistrées par chaîne de caractères, et **rien dans le langage ne vérifie
// qu'une destination est atteignable**.
//
// Mesuré le 2026-09-11 : les douze destinations de premier niveau **sont**
// effectivement câblées côté Flutter. Mais il a fallu, pour l'établir, un test
// de 417 lignes (`apps/mobile/test/navigation_reachability_guard_test.dart`)
// qui **lit le code source**, calcule la fermeture des classes réellement
// construites depuis les cinq écrans d'onglet, et rejoue le calcul sur une
// copie mutée pour prouver qu'il n'est pas muet.
//
// C'est exactement ce que le `switch` exhaustif ci-dessous obtient
// gratuitement, à la compilation : **ajouter un cas sans lui donner de
// domicile ne compile pas.** La parade n'est pas de la discipline, et elle ne
// coûte pas 417 lignes.

/// Les douze destinations de premier niveau de Certigo.
///
/// Les noms et les chemins sont transcrits de `Routes` dans
/// `apps/mobile/lib/app/router.dart`, relevé le 2026-09-11. Ils ne sont pas
/// inventés : `certigo://` doit arriver au même endroit conceptuel sur les deux
/// plateformes.
public enum Destination: String, Hashable, CaseIterable, Sendable {
    // Les cinq branches de la coquille.
    case home
    case path
    case library
    case leaderboard
    case profile

    // Les sept qui n'ont aujourd'hui aucun domicile dans la coquille Flutter.
    case achievements
    case seasons
    case quests
    case shop
    case friends
    case exam
    case dailyShare

    /// Le chemin canonique, identique à la constante Dart correspondante.
    public var path: String {
        switch self {
        case .home: "/home"
        case .path: "/path"
        case .library: "/library"
        case .leaderboard: "/leaderboard"
        case .profile: "/profile"
        case .achievements: "/achievements"
        case .seasons: "/seasons"
        case .quests: "/quests"
        case .shop: "/shop"
        case .friends: "/friends"
        case .exam: "/exam"
        case .dailyShare: "/share-daily"
        }
    }

    /// Libellé affiché, en français. Aucune chaîne visible ne doit rester
    /// codée en dur dans une vue : elles passeront toutes par un catalogue de
    /// chaînes (`.xcstrings`) quand la localisation arrivera.
    public var title: String {
        switch self {
        case .home: "Accueil"
        case .path: "Parcours"
        case .library: "Bibliothèque"
        case .leaderboard: "Classement"
        case .profile: "Profil"
        case .achievements: "Succès"
        case .seasons: "Saisons"
        case .quests: "Quêtes"
        case .shop: "Boutique"
        case .friends: "Amis"
        case .exam: "Examen"
        case .dailyShare: "Partage du jour"
        }
    }
}

/// Le domicile d'une destination dans la coquille.
public enum Home: Hashable, Sendable {
    /// La destination **est** une branche de la barre d'onglets.
    case tab(Destination)
    /// La destination est atteinte depuis une branche, par empilement.
    case grouped(Destination, under: Destination)

    /// La branche d'onglet qui héberge cette destination, dans tous les cas.
    public var tab: Destination {
        switch self {
        case .tab(let destination): destination
        case .grouped(_, let parent): parent
        }
    }
}

/// La table des domiciles. **Exhaustive par construction.**
///
/// Le `switch` sans `default` est le cœur du dispositif : ajouter un cas à
/// `Destination` sans l'ajouter ici produit une erreur de compilation, pas un
/// écran silencieusement inatteignable.
public func home(for destination: Destination) -> Home {
    switch destination {
    case .home, .path, .library, .leaderboard, .profile:
        .tab(destination)
    case .achievements, .seasons, .quests, .shop:
        .grouped(destination, under: .profile)
    case .friends, .dailyShare:
        .grouped(destination, under: .leaderboard)
    case .exam:
        .grouped(destination, under: .library)
    }
}

/// Les cinq branches de la barre d'onglets, dans l'ordre d'affichage.
public let tabDestinations: [Destination] = Destination.allCases.filter {
    if case .tab = home(for: $0) { return true }
    return false
}
