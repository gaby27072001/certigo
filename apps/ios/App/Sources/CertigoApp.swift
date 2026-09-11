// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// **La racine de composition, et le seul endroit du programme qui sait quel
// environnement est actif.** C'est délibérément le fichier le plus court et le
// plus lisible du projet : ce qui est branché doit se voir d'un coup d'œil,
// parce qu'un mécanisme complet qu'on oublie de brancher est le défaut le plus
// coûteux de ce dépôt.

import APIClient
import DesignSystem
import Navigation
import SwiftUI

@main
struct CertigoApp: App {
    /// Le routeur de la coquille. Une pile par onglet.
    @State private var router = AppRouter()

    /// Le client d'API. **Volontairement `.failing` dans le squelette** : il
    /// n'y a aucune URL de production ici, et un client qui échoue est plus
    /// honnête qu'un client qui semble marcher.
    private let api = APIClient.failing

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
        }
    }
}
