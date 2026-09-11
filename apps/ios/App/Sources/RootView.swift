// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// La coquille : cinq onglets, **une pile de navigation par onglet**.
// C'est l'équivalent natif de `StatefulShellRoute.indexedStack`, sans
// dépendance — et sans la classe de défauts qui l'accompagne côté Flutter, où
// sept destinations existent sans domicile parce que rien ne le vérifie.

import DesignSystem
import Navigation
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        return TabView(selection: $router.selectedTab) {
            ForEach(tabDestinations, id: \.self) { tab in
                NavigationStack(path: router.binding(for: tab)) {
                    branchRoot(tab)
                        .navigationDestination(for: Destination.self) { destination in
                            PlaceholderScreen(destination: destination)
                        }
                }
                .tabItem {
                    Label(tab.title, systemImage: symbol(for: tab))
                }
                .tag(tab)
            }
        }
        // Comme Apple Music : la barre se réduit quand on descend, pour rendre
        // le contenu au contenu. Sans effet avant iOS 26.
        .prismTabBarMinimize()
    }

    /// L'écran racine d'une branche.
    ///
    /// **Seul l'accueil a un contenu réel dans le squelette** : la vitrine
    /// Prism. Les quatre autres affichent volontairement un écran d'attente
    /// nommé, parce qu'un écran vide sans explication se confond avec un bug.
    @ViewBuilder
    private func branchRoot(_ tab: Destination) -> some View {
        switch tab {
        case .home:
            PrismShowcaseView()
                .navigationTitle(tab.title)
        default:
            PlaceholderScreen(destination: tab)
                .navigationTitle(tab.title)
        }
    }

    /// Le symbole SF de chaque onglet.
    ///
    /// `switch` exhaustif volontaire : une destination ajoutée sans symbole ne
    /// compile pas, exactement comme pour son domicile.
    private func symbol(for destination: Destination) -> String {
        switch destination {
        case .home: "house.fill"
        case .path: "map.fill"
        case .library: "books.vertical.fill"
        case .leaderboard: "trophy.fill"
        case .profile: "person.crop.circle.fill"
        case .achievements: "rosette"
        case .seasons: "calendar"
        case .quests: "checklist"
        case .shop: "bag.fill"
        case .friends: "person.2.fill"
        case .exam: "graduationcap.fill"
        case .dailyShare: "square.and.arrow.up"
        }
    }
}

/// L'écran d'attente d'une destination non encore écrite.
///
/// Il dit **ce qu'il est** et **où il mène**. Un écran vide anonyme se confond
/// avec une panne ; celui-ci ne peut pas.
struct PlaceholderScreen: View {
    let destination: Destination

    @Environment(AppRouter.self) private var router
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let band = PrismSpectrum.band(forTrackId: destination.rawValue)
        VStack(spacing: PrismSpace.md) {
            Image(systemName: "square.dashed")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(
                    Color(prism: colorScheme == .dark ? band.glow : band.ink))
            Text(destination.title)
                .prismType("headlineSmall")
            Text("Écran non encore migré.\nChemin canonique : \(destination.path)")
                .prismType("bodyMedium")
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    Color(
                        prism: colorScheme == .dark
                            ? PrismPalette.darkTextSecondary
                            : PrismPalette.lightTextSecondary))
            Button("Retour à l'accueil") { router.open(.home) }
                .buttonStyle(PrismPrimaryButtonStyle())
        }
        .padding(PrismSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(prism: colorScheme == .dark ? PrismPalette.darkBg : PrismPalette.lightBg)
        )
    }
}

#Preview("Coquille complète") {
    RootView()
        .environment(AppRouter())
}
