# ADR-022 — Architecture de l'application iOS native

| Champ | Valeur |
|---|---|
| **ADR** | 022 |
| **Statut** | Accepté — squelette livré, **non compilé** |
| **Date** | 2026-09-11 |
| **Périmètre** | `apps/ios/` uniquement. L'application Flutter n'est pas touchée. |
| **Numérotation** | `021` est le dernier numéro utilisé ; `022` est le premier libre. |

> ⚠️ **Rien de ce qui est décrit ici n'a été compilé.** Le squelette a été écrit sur Windows
> ARM64, où SwiftUI et UIKit ne peuvent pas exister — ce n'est pas une lacune d'installation
> mais une propriété permanente du SDK d'Apple. La première compilation aura lieu sur le
> MacBook. Voir `apps/ios/DEMARRAGE.md`.

## Contexte

L'application iOS passe en natif Swift/SwiftUI. Android reste en Flutter. La question ouverte
était le patron d'architecture : MVVM, TCA, Clean, ou MV natif.

Deux mesures tranchent :

1. **`AGENTS.md` établit que le serveur est autoritaire** pour le score des quiz, la
   progression, les récompenses et la préparation. Le client n'arbitre rien.
2. **Le calcul côté client pèse 320 lignes, soit 0,89 % du code.**

Les architectures qui se vendent sur la testabilité exhaustive d'une logique métier côté client
n'ont donc presque rien à mordre ici. Leur coût — un objet par écran, une couche de cas d'usage,
un réducteur par fonctionnalité — s'appliquerait intégralement à un bénéfice quasi nul.

## Décision

### 1. MV natif SwiftUI, avec un étage `Store` par domaine

> **MV par défaut ; un `Store` dès que l'état survit à la vue ; jamais un objet par écran.**

Quatre étages, et rien de plus :

| Étage | Forme | Rôle |
|---|---|---|
| Vues | SwiftUI, `@State` local, `@Environment` | Aucune logique réseau, aucun `try await` dans un `body` |
| Stores | `@Observable @MainActor final class` | Un par **domaine**, pas par écran. L'unité de test unitaire. |
| Clients | `struct` à fermetures | Substituables champ par champ, sans classe de simulation |
| Modèles | `struct Sendable` | Zéro comportement métier |

**Corollaire vérifiable :** si un objet d'état n'est lu que par une seule vue et meurt avec elle,
il n'a pas lieu d'exister — son état appartient à la vue.

### 2. Deux contraintes portées par le système de types, pas par la discipline

C'est ce qui distingue cette décision d'une simple préférence de style.

**`LoadState.failed(_, retry:)`** — le cas d'échec porte son action de reprise dans sa signature.
Il devient **impossible de produire un état d'erreur sans offrir la reprise**. C'est la
transformation en contrainte de type d'un défaut réel côté Flutter : un écran affichait une
erreur sans aucun moyen de réessayer, et rien dans le code ne pouvait le signaler.

**`home(for:)`** — un `switch` exhaustif, sans `default`, sur `Destination`. **Ajouter une
destination sans lui donner de domicile ne compile pas.**

Côté Flutter, `go_router` enregistre les routes par chaîne de caractères, et rien dans le
langage ne vérifie qu'une destination est atteignable. La même garantie y existe désormais —
mesuré le 2026-09-11, les douze destinations **sont** câblées — mais elle coûte un test de
**417 lignes** qui lit le code source, calcule la fermeture des classes réellement construites
depuis les cinq écrans d'onglet, et rejoue le calcul sur une copie mutée pour prouver qu'il
n'est pas muet. En Swift, c'est le compilateur, et c'est gratuit.

### 3. Un paquet SwiftPM local, plusieurs cibles

```
apps/ios/Packages/CertigoKit/
├── Sources/{DesignSystem,Navigation,APIClient}/
└── Tests/{DesignSystemTests,NavigationTests,APIClientTests}/
```

**Un seul `Package.swift` avec plusieurs cibles**, et non trois paquets séparés. Les cibles
donnent déjà des frontières de module vérifiées par le compilateur ; trois paquets ajouteraient
des références croisées `.package(path:)` et trois résolutions, pour la même garantie. Un seul
`swift test` couvre tout, ce qui rend la commande du premier soir triviale. Le découpage en
paquets distincts reste un déplacement mécanique si le besoin apparaît.

**Ce découpage sert aussi un problème d'outillage** : SwiftPM découvre les fichiers par
convention de répertoire, donc ajouter un fichier Swift n'exige **aucune modification du fichier
de projet**. Voir ADR-023.

### 3 bis. Ce que `swift test` valide — et ce qu'il ne valide pas

`Package.swift` déclare `.macOS(.v14)` **pour une seule raison** : permettre à `swift test` de
tourner sans simulateur, ce qui donne une boucle rouge/vert de quelques secondes. **macOS n'est
pas une cible produit** et aucun rendu n'y est jugé.

Cette commodité a un coût, mesuré le 2026-09-14 sur la première compilation réelle :

| Étape de `demarrer.sh` | Compile pour | Ce qu'elle prouve |
|---|---|---|
| 3/6 — `swift test` | **macOS** | La logique pure : contraste, jetons, destinations, table d'erreurs. Les tests n'importent que `XCTest`. |
| 5/6 — `xcodebuild -destination id=<sim>` | **iOS** | Que le code destiné à l'appareil compile réellement. |

**Conséquence à énoncer clairement : aucun test n'exécute quoi que ce soit sur la cible iOS.**
L'étape 3 éprouve du Swift pur sur une plateforme qui n'est pas la cible ; l'étape 5 compile la
cible mais n'exécute rien. Les vues SwiftUI ne sont donc **ni testées, ni rendues** par la chaîne
automatique — elles ne le seront que par un œil humain dans le simulateur, ou par des tests
d'instantané qui exigeront un simulateur en CI.

**Et le compilateur macOS produit des échecs qui n'existent pas sur iOS.** `TabBarMinimizeBehavior`
`.onScrollDown` est marqué `@available(macOS, unavailable)` : il a fait échouer l'étape 3 pour un
symbole que l'application iOS n'aurait jamais rencontré. Comme l'étape 3 précède l'étape 5, un
faux échec macOS bloque avant que la vraie cible ne soit seulement tentée.

La parade retenue est double, et aucune des deux n'est un compilateur :

1. **`#if os(iOS)` autour de tout le chrome iOS 26**, y compris des symboles dont la
   documentation annonce une disponibilité macOS. Sur une plateforme qui ne sert qu'aux tests,
   un effet visuel perdu ne coûte rien ; un aller-retour avec le Mac coûte une demi-heure.
2. **Une garde de source** (`tools/tests/test_ios_detection.py`) qui refuse qu'un symbole
   iOS-only vive hors d'un `#if os(iOS)`, et qu'un `#available` promette macOS 26. Elle
   s'exécute en CI depuis Windows, là où aucun compilateur Swift ne peut exister.

### 4. Aucune dépendance externe dans le squelette

Ni `swift-openapi-generator`, ni `swift-snapshot-testing`, ni `sentry-cocoa`. Chacune viendra
avec son besoin. Chaque paquet distant est un mode de panne de plus le soir où il faut que la
chaîne démarre pour la première fois.

### 5. Les jetons Prism sont transcrits à la main — provisoirement

`#473` a livré `packages/prism_ui/schemas/tokens/v1/prism-tokens.json`, une source neutre
indépendante du langage. Le squelette **transcrit** ces valeurs en Swift plutôt que de les
générer, parce qu'une chaîne de génération est un mode de panne de plus au premier lancement.

La transcription a été **vérifiée mécaniquement** contre cette source le 2026-09-11 :
**154 valeurs comparées** — 32 jetons de palette, 30 valeurs de spectre (6 bandes × 5 rôles),
75 valeurs typographiques (15 créneaux × 5 dimensions) et 17 espacements et rayons — **zéro
écart**.

**Ce n'est pas une garde permanente : c'est un contrôle ponctuel.** Et la nuance compte, parce
qu'une garde de dérive existe désormais sans couvrir ce cas :

> `#478` a posé `apps/mobile/test/prism_tokens_contract_test.dart`, et cette garde **mord
> réellement** — elle vit dans `apps/mobile/test/`, exécuté par `flutter test --coverage`
> (`ci-mobile.yml:231`), et non dans `packages/prism_ui/test/`, dont la CI n'exécute **qu'un
> fichier sur 39** (`ci-mobile.yml:331`, mesuré le 2026-09-11).
>
> **Mais elle compare Dart ↔ JSON. Elle ne voit pas une ligne de Swift.** La transcription
> d'`apps/ios/` reste donc **non gardée** : rien ne rougira si elle dérive.

La génération depuis le JSON, avec un contrôle de CI vérifiant que la régénération est identique
à l'octet, reste à faire et appartient à la phase suivante — **et elle exigera d'abord un job de
CI capable d'exécuter du Swift**, qui n'existe pas.

## Ce que cette architecture écarte, délibérément

| Écarté | Raison |
|---|---|
| **Cortex porté en Swift** | 320 lignes, et le serveur est autoritaire. Le porter créerait un deuxième miroir du même calcul, à maintenir en parallèle. |
| **Un ViewModel par écran** | Multiplie les objets sans état à gérer. |
| **TCA, Clean, KMP** | Se vendent sur le partage ou la testabilité de la logique métier. Il y en a 320 lignes. |
| **SwiftData / Core Data** | Le contenu est constitué de releases immuables. Une base ajoute une surface de migration pour zéro bénéfice. |
| **Combine** | `async/await` + Observation couvrent tout ; deux modèles concurrents doublent la charge mentale. |

## Conséquences

- Le mode de langage **Swift 6** est actif dès la première ligne. L'activer sur 20 000 lignes
  serait un chantier ; l'activer à zéro ligne est gratuit.
- Les Stores restent à écrire : le squelette ne contient que `AppRouter`. Les huit Stores prévus
  (`SessionStore`, `LearningStore`, `AssessmentStore`, `ProfileStore`, `GamificationStore`,
  `SocialStore`, `ContentStore`, `NotificationStore`) arriveront avec leurs écrans.
- **Aucun écran n'est migré.** L'application Flutter reste l'application réelle, et le restera
  jusqu'à ce qu'un job de CI compile le Swift.

## Prochaine phase, explicitement hors périmètre

Un **gate de CI macOS** doit exister **avant la première ligne de SwiftUI de production**. Sans
lui, des agents écriraient des dizaines de milliers de lignes sans qu'une seule ait jamais
compilé. Aucun runner macOS n'existe aujourd'hui dans ce dépôt ; sa mise en place fera l'objet
de sa propre décision.
