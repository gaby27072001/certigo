# ADR-024 — Cible iOS minimale : 17.0

| Champ | Valeur |
|---|---|
| **ADR** | 024 |
| **Statut** | Accepté |
| **Date** | 2026-09-11 |
| **Valeur retenue** | `IPHONEOS_DEPLOYMENT_TARGET = 17.0` pour `apps/ios/` |
| **Non modifié** | `apps/mobile/ios` reste à **12.0** — mesuré dans `Runner.xcodeproj/project.pbxproj` |

## Contexte

Le projet Flutter cible **iOS 12.0**, une valeur héritée du gabarit d'origine et qu'aucune
décision n'a jamais justifiée. L'application native doit choisir sa propre cible.

## Décision

**iOS 17.0**, pour trois raisons qui sont des exigences et non des préférences :

| Besoin | Version minimale |
|---|---|
| `@Observable` (framework Observation) — l'étage `Store` d'ADR-022 en dépend | iOS 17 |
| `NavigationStack` mûr, avec `navigationDestination` stable | iOS 16, fiable en 17 |
| `.smooth` / `.snappy`, `Task.sleep(for:)` | iOS 17 |

Descendre sous 17 obligerait à écrire les Stores en `ObservableObject`/`@Published`, dont la
granularité de suivi est inférieure et provoque des recompositions inutiles — puis à tout
réécrire plus tard.

## Ce que cela exclut, explicitement

iOS 17 ne s'installe pas sur les appareils sortis avant **septembre 2018**.

Sont donc exclus : **iPhone X, iPhone 8, iPhone 8 Plus**, et tout ce qui précède (iPhone 7, 6s,
SE 1ʳᵉ génération). Le plus ancien appareil pris en charge est l'**iPhone XS / XR**.

Ces trois modèles peuvent installer iOS 16 mais pas iOS 17. C'est le coût réel de la décision,
et il est nommé ici plutôt que découvert plus tard.

> **[NON MESURÉ]** La part de ces appareils dans la base d'utilisateurs Certigo n'est pas connue :
> aucune donnée d'installation par version d'iOS n'a été consultée. Si la console App Store
> Connect montre une part significative sous iOS 17, cette décision doit être rouverte — elle
> n'est pas coûteuse à annuler tant que le corpus de code natif est petit.

## Articulation avec Liquid Glass

Liquid Glass exige **iOS 26** (voir ADR-025), bien au-dessus de la cible. Ce n'est pas une
contradiction : le code applique le matériau sous `if #available(iOS 26.0, *)` et retombe sur les
matériaux standard en deçà. Apple documente d'ailleurs ces matériaux comme non dépréciés et comme
le traitement correct de la couche de contenu, y compris sur iOS 26.

**Précision utile :** il n'existe pas d'iOS 19 à 25. La numérotation passe d'iOS 18 à iOS 26. La
plage de repli est donc **iOS 17 à 18.x**, et non « 17 à 25 ».

## Conséquences

- `Package.swift` déclare `.iOS(.v17)` et `.macOS(.v14)`. La ligne macOS ne sert qu'à faire
  tourner `swift test` sans simulateur — elle n'annonce aucune application macOS.
- Une remontée ultérieure (iOS 18, puis 26) restera possible et peu coûteuse tant que le corpus
  natif est petit. **Une descente, elle, coûterait une réécriture des Stores.**
