# `apps/ios` — application iOS native (squelette)

> ## ⚠️ Rien ici n'a jamais été compilé
>
> Ce dossier a été écrit sur un PC **Windows ARM64**, où SwiftUI et UIKit ne peuvent pas
> exister — ce n'est pas une lacune d'installation, c'est une propriété permanente du SDK
> d'Apple. **La première compilation aura lieu sur le Mac.**
>
> ### 👉 Commence par [`DEMARRAGE.md`](./DEMARRAGE.md)

---

## Ce que c'est

Le squelette de l'application iOS native. Il **prouve que la chaîne fonctionne** — génération du
projet, compilation, paquet local, tests, rendu — et **ne migre aucun écran**.

L'application Flutter (`apps/mobile`) reste l'application réelle et n'est pas touchée.
Supprimer entièrement `apps/ios/` laisse le dépôt dans son état antérieur.

## Structure

```
apps/ios/
├── DEMARRAGE.md          ⭐ la checklist du premier lancement
├── project.yml              XcodeGen — le .xcodeproj est GÉNÉRÉ, pas versionné
├── Scripts/
│   ├── demarrer.sh          tout : vérifie, teste, génère, compile, lance
│   ├── verifier-tests.sh    les tests, avec le COMPTE des tests exécutés
│   └── prouver-le-rouge.sh  prouve que le lot de tests mord vraiment
├── App/
│   ├── Sources/             CertigoApp.swift (racine de composition), RootView.swift
│   └── Resources/           Assets.xcassets
├── Packages/CertigoKit/     ~90 % du code — SPM, donc zéro conflit de projet
│   ├── Sources/
│   │   ├── DesignSystem/    jetons Prism, Liquid Glass, LoadState, ScreenScaffold
│   │   ├── Navigation/      Destination, home(for:), AppRouter
│   │   └── APIClient/       CertigoError, RetryPolicy, témoin substituable
│   └── Tests/               54 tests unitaires
└── Tests/CertigoAppTests/   configuration de l'application (Info.plist généré)
```

**Pourquoi presque tout vit dans `Packages/` :** SwiftPM découvre les fichiers par convention de
répertoire. Ajouter un fichier Swift n'exige **aucune modification du fichier de projet**, donc
ne peut produire **aucun conflit**. Voir [ADR-023](../../docs/adr/ADR-023-generation-projet-xcode.md).

## Les commandes

```bash
brew install xcodegen              # une fois
./Scripts/demarrer.sh              # tout
./Scripts/demarrer.sh --tests-seuls
./Scripts/prouver-le-rouge.sh      # le lot de tests mord-il ?
```

## Les décisions

| Décision | ADR |
|---|---|
| MV natif + `Store` par domaine, un paquet SPM multi-cibles | [ADR-022](../../docs/adr/ADR-022-architecture-ios-native.md) |
| Projet Xcode généré par XcodeGen, non versionné | [ADR-023](../../docs/adr/ADR-023-generation-projet-xcode.md) |
| Cible iOS 17.0, et ce qu'elle exclut | [ADR-024](../../docs/adr/ADR-024-cible-ios-minimale.md) |
| Liquid Glass natif et séparation des couches | [ADR-025](../../docs/adr/ADR-025-liquid-glass-natif.md) |

## Deux invariants à ne pas perdre

**`LoadState.failed(_, retry:)`** — le cas d'échec porte son action de reprise **dans sa
signature**. Il est impossible d'afficher une erreur sans offrir la reprise.

**`home(for:)`** — `switch` exhaustif sans `default`. Ajouter une destination sans lui donner de
domicile **ne compile pas**. Côté Flutter, la même garantie coûte un test de 417 lignes qui lit
le code source (`apps/mobile/test/navigation_reachability_guard_test.dart`).

## Visibilité

`apps/ios/` est déclaré dans `OBSERVABLE_PATHS` de `tools/project_state.py`, **dans le même
commit que sa création**. Sans cela, on pourrait y verser des dizaines de milliers de lignes sans
que `docs/ETAT_DU_PROJET.md` ne bouge. `discover_tests` refuse de fonctionner si la famille de
tests Swift disparaît : un instrument muet doit échouer, pas rendre zéro.
