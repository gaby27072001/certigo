# ADR-025 — Liquid Glass natif, et la séparation des couches qu'il impose

| Champ | Valeur |
|---|---|
| **ADR** | 025 |
| **Statut** | Accepté — **implémentation non compilée** |
| **Date** | 2026-09-11 |
| **Exigence** | « Donner l'impression que c'est iOS natif, avec Liquid Glass comme dernier type de design. » Référence visuelle citée : Apple Music. |
| **Confinement** | Toute l'API iOS 26 vit dans un seul fichier : `apps/ios/Packages/CertigoKit/Sources/DesignSystem/PrismGlass.swift` |

## Contexte

En Flutter, Liquid Glass doit être **imité** : un flou gaussien, un liseré, une ombre. L'imitation
a un coût mesuré côté Prism — dégradation du verre partout, perte de testabilité golden — et elle
ne sera jamais fidèle, parce que le matériau d'Apple réfracte le contenu et réagit à la lumière.

En natif, Liquid Glass est **gratuit et fidèle** : c'est le SDK de compilation qui l'active, pas
un réglage. **C'est l'argument le plus concret de la décision native**, et il doit se démontrer
au premier lancement.

## Décision

### 1. Utiliser le matériau d'Apple, jamais l'imiter

L'API est employée telle qu'Apple la publie : `glassEffect(_:in:)`, `GlassEffectContainer`,
`glassEffectID(_:in:)`, `scrollEdgeEffectStyle(_:for:)`, `tabBarMinimizeBehavior(_:)`.

Les signatures ont été relevées le 2026-09-11 dans les données DocC d'Apple — le flux qui rend
`developer.apple.com` — et non de mémoire. Trois d'entre elles diffèrent de ce qu'on aurait
supposé, et l'écart aurait coûté une compilation :

| Supposé | Réel |
|---|---|
| `in shape: some Shape = .capsule` | `= DefaultGlassEffectShape()` |
| `ScrollEdgeEffectStyle` est un `enum` | C'est une **`struct`** à propriétés statiques — un `switch` dessus ne compile pas |
| `for:` prend un type dédié | C'est `Edge.Set`, **sans valeur par défaut** |

### 2. Respecter la séparation des couches, qui n'est pas optionnelle

Apple écrit deux règles explicites, et elles décident de la conception :

> « **Don't use Liquid Glass in the content layer.** »
> « **Always avoid glass on glass.** »

D'où deux modificateurs distincts, et un nom qui dit à quelle couche on s'adresse :

| Couche | Modificateur | Matériau |
|---|---|---|
| Contrôle — barres flottantes, boutons posés au-dessus | `.prismGlass()` | Liquid Glass (iOS 26+) |
| Contenu — cartes, listes, surfaces du corps | `.prismContent(in:)` | `.regularMaterial`, y compris sur iOS 26 |

La barre flottante **n'a pas de fond de verre à elle** : chaque pilule porte son propre verre, et
un `GlassEffectContainer` les fait fusionner en s'approchant. C'est le motif documenté par Apple,
et c'est ce qui évite le verre sur verre.

### 3. Ne pas surcharger ce que le système fait déjà

- **Accessibilité :** Apple confirme que « Réduire la transparence », « Augmenter le contraste »
  et « Réduire les animations » s'appliquent **automatiquement** au matériau natif. Les
  réappliquer à la main le dégraderait. Le code ne les traite que sur le **chemin de repli**, où
  le matériau est le nôtre.
- **Couleur du contenu posé sur le verre :** le verre `regular` bascule clair/sombre selon ce
  qu'il y a derrière, et **les symboles et textes posés dessus basculent avec lui**. Forcer un
  `foregroundStyle` casserait exactement ce comportement. Le code ne le force pas.
- **Teinte :** elle passe par `Glass.tint(_:)`, jamais par un `background` coloré. Apple mappe la
  teinte sur la luminosité du contenu dessous ; un aplat est opaque et « casse le caractère
  visuel de Liquid Glass ».

> **Ce que cet accès direct vaut, mesuré le 2026-09-11 sur `#495`.**
>
> Pour obtenir le seul réglage « Réduire la transparence » côté Flutter, il a fallu **221 lignes
> de plomberie** réparties sur trois fichiers : un `FlutterMethodChannel` dans
> `apps/mobile/ios/Runner/AppDelegate.swift` (51 l.), un scope de propagation
> `reduce_transparency_scope.dart` (105 l.) et un scope de thème
> `prism_accessibility_scope.dart` (65 l.) — plus 127 lignes de test pour le seul scope de thème.
>
> Le canal doit faire **deux** choses, et le commentaire de `#495` l'explique : répondre à la
> question au démarrage, **et pousser le changement** quand l'utilisateur bascule le réglage en
> cours d'exécution, faute de quoi il ne prendrait effet qu'au lancement suivant.
>
> La raison est nommée dans ce même commentaire : *« Flutter n'expose pas ce réglage :
> `MediaQueryData` déclare `highContrast`, `boldText`, `accessibleNavigation`,
> `disableAnimations`, `invertColors` et `onOffSwitchLabels`, mais aucun équivalent de
> `UIAccessibility.isReduceTransparencyEnabled`. »*
>
> L'équivalent natif est **une ligne**, disponible depuis iOS 13, dans `PrismGlass.swift` :
>
> ```swift
> @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
> ```
>
> Et sur iOS 26, cette ligne ne sert **que** sur le chemin de repli : le matériau d'Apple
> applique lui-même le réglage. Ce n'est pas un argument de confort — c'est un axe
> d'accessibilité qui, en Flutter, exigeait d'écrire du Swift de toute façon.

### 4. Ne jamais poser `UIDesignRequiresCompatibility`

Cette clé fait rendre l'application comme si elle était compilée contre un ancien SDK — donc
**sans** Liquid Glass. C'est le genre de clé qu'on ajoute « temporairement » puis qu'on oublie.
Un test de la cible d'application vérifie son **absence**.

### 5. Reprendre la grammaire d'Apple Music, avec le matériau que Certigo a déjà

Trois traits, et leur équivalent Certigo :

| Apple Music | Certigo |
|---|---|
| La couleur vient de la pochette et irradie sa région | Elle vient de la **piste de certification** : une bande OKLCH à clarté constante par piste, déjà définie dans `prism_colors.dart` |
| Les contrôles flottent au-dessus du contenu | Barre flottante, rien collé aux bords, contenu qui passe dessous avec `scrollEdgeEffectStyle(.soft, …)` |
| Le mouvement est continu | `glassEffectID` : la pilule **s'étire** vers son état suivant au lieu de disparaître puis réapparaître |

L'attribution d'une bande à une piste utilise une empreinte **FNV-1a** et non `hashValue` :
**`hashValue` est réamorcé à chaque lancement du processus**, ce qui ferait changer la couleur
d'une certification entre deux démarrages. Un test fige l'empreinte sur des valeurs calculées
hors de Swift.

### 6. Confiner l'API dans un seul fichier

Toute l'API iOS 26 vit dans `PrismGlass.swift`, derrière `prismGlass`, `prismContent`,
`prismGlassID`, `prismScrollEdge`, `prismTabBarMinimize` et `PrismGlassGroup`.

**Raison assumée : ce code n'a jamais été compilé.** Si une signature est fausse, il y a
exactement **un** fichier à corriger, et le reste du squelette compile quand même.
`DEMARRAGE.md` documente la neutralisation en une commande.

## Le point qu'on ne peut pas vérifier depuis Windows

La refonte Flutter avait mesuré que le liseré de lumière d'Apple rend **1.00:1** en mode clair —
rigoureusement invisible — et avait délibérément dévié : en clair, la profondeur vient de l'ombre
et d'une arête sombre.

En natif, on hérite du matériau d'Apple, qui gère lui-même sa profondeur. Apple documente
d'ailleurs une modulation qui va dans le même sens :

> « [L'élément] augmente l'opacité de son ombre lorsqu'il est au-dessus de texte. Inversement, il
> abaisse l'opacité de son ombre lorsqu'il est au-dessus d'un fond clair uni. »

Autrement dit : **en mode clair sur fond uni, le verre d'Apple rend volontairement plus plat**, et
la déviation choisie côté Flutter est cohérente avec ce qu'Apple fait réellement.

> **[NON VÉRIFIÉ]** Cette lecture vient de la narration d'une session WWDC 2025, pas d'un contrat
> d'API, et aucune page de documentation ne la formule par écrit. Elle n'a été confirmée par
> aucun rendu. Le jugement visuel sur fond clair reste à faire sur le Mac — il figure comme point
> de contrôle explicite dans `DEMARRAGE.md`.

## Conséquences

- Liquid Glass est visible à partir d'**iOS 26**. En deçà (iOS 17 à 18.x), l'application
  fonctionne avec les matériaux standard. Il n'existe pas d'iOS 19 à 25.
- Un simulateur iOS 18 affichera donc un flou ordinaire. Ce n'est pas un défaut, et
  `DEMARRAGE.md` le dit avant que la question ne se pose.
- `glassEffect` n'est **pas** disponible sur visionOS — il y existe une API distincte. Aucune
  annotation de disponibilité de ce dépôt ne doit mentionner visionOS.
