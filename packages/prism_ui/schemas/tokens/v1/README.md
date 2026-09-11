# Prism design tokens — source neutre v1

`prism-tokens.json` est la projection **portable** des tokens Prism : la forme
sous laquelle une plateforme qui n'est pas Flutter — iOS d'abord, Android
ensuite — peut consommer le design system sans le redéclarer.

## Sens de la dérivation : le Dart est la source

Ce fichier est **généré**. Ne l'éditez jamais à la main : la prochaine
régénération écraserait la modification, et le test la ferait rougir avant.

La direction inverse — JSON source, Dart généré — a été examinée et écartée pour
deux raisons mesurées :

1. Les fichiers de `lib/src/tokens/` portent environ **450 lignes de
   raisonnement** : la loi de dérivation OKLCH, les ratios de contraste
   mesurés, pourquoi le bleu Fluent a cessé d'être la couleur de marque,
   pourquoi un chroma constant a été rejeté. Un JSON ne peut pas porter cela
   sans devenir illisible, et générer le Dart depuis le JSON reviendrait à
   effacer la mémoire du design system.
2. Les **269 tests** du paquet, dont les trois gardes sémantiques de
   `test/theme/`, lisent le Dart directement. Inverser la dérivation
   interposerait un générateur entre une garde et la valeur qu'elle garde.

La projection dans ce sens-là, elle, est mécanique : 88 couleurs plates, zéro
dérivation à l'exécution.

## Ce que le fichier contient — et pourquoi ce n'est pas la palette brute

`PrismColorScheme` le dit sans ambiguïté :

> This is the layer UI code should depend on — never the raw `PrismColors`.

Le document porte donc les **43 rôles sémantiques résolus, par apparence**
(`color.scheme.light` / `color.scheme.dark`) *en plus* des 56 primitives et des
6 familles indexées.

Ce n'est pas une précaution théorique. `test/theme/prism_contrast_contract_test.dart`
documente la régression exacte qu'un export limité aux primitives reproduirait :
les tests vérifiaient les primitives et jamais les rôles résolus, et **six
accents sur sept sont tombés entre 2.6:1 et 3.1:1 en mode sombre**. Une app
native qui consommerait les seules primitives devrait re-dériver la
correspondance rôle → couleur à la main, c'est-à-dire refaire cette faute.

| Section | Contenu |
| --- | --- |
| `color.primitive` | 56 couleurs brutes, `#AARRGGBB` |
| `color.primitiveSets` | 6 familles indexées (spectre, accents de domaine) |
| `color.scheme.{light,dark}` | 43 rôles résolus + 5 familles de rôles |
| `typography.styles` | 16 créneaux : famille, taille, graisse, axes `wght`/`wdth`, interligne, interlettrage, rôle de couleur |
| `spacing`, `radii` | échelle, valeurs sémantiques, et la **dette hors grille 4pt** publiée telle quelle |
| `layout.readingWidths` | les 7 mesures de lecture |
| `motion` | durées en ms, courbes en points de contrôle cubiques |
| `elevation.{light,dark}` | ombres par niveau : couleur, décalage, flou, étalement |
| `state.{light,dark}` | opacités des couches d'interaction, géométrie de l'anneau de focus |

### Conventions

- **Couleurs** : `#AARRGGBB`, transcription directe du littéral Dart
  `Color(0xAARRGGBB)` — une revue de diff reste donc lisible.
- **Groupes terminaux homogènes** : chaque table associe des clés à une seule
  sorte de valeur, ce qui se décode en Swift avec un `Codable` sans traitement
  spécial, et en Kotlin avec `kotlinx.serialization`.
- `typography.styles[*].colorRole` vaut `textPrimary` ou `textSecondary` et est
  **mesuré**, pas recopié : le générateur construit le thème avec deux couleurs
  sentinelles et lit la réponse.

### Lire le fichier depuis Swift

```swift
struct PrismTokens: Decodable {
  struct Color_: Decodable {
    struct Scheme: Decodable {
      let roles: [String: String]
      let roleSets: [String: [String]]
    }
    let primitive: [String: String]
    let scheme: [String: Scheme]
  }
  let tokenSchemaVersion: Int
  let color: Color_
}

// UIColor(hex:) doit lire #AARRGGBB — l'alpha est en tête, pas en queue.
let tokens = try JSONDecoder().decode(PrismTokens.self, from: data)
let surface = tokens.color.scheme["dark"]!.roles["surface"]!  // "#FF1C1F2B"
```

`tokenSchemaVersion` n'est incrémenté que si la **forme** du document change
d'une manière qu'un consommateur ne peut pas absorber. Un changement de valeur
ne l'incrémente pas.

## Régénérer

```powershell
$env:PRISM_TOKENS_WRITE = '1'
flutter test test\tokens\prism_token_export_test.dart
Remove-Item Env:\PRISM_TOKENS_WRITE
```

Même geste que `--update-goldens`, et pour la même raison : l'artefact est une
empreinte, pas une saisie.

## Les gardes — et ce que chacune voit

`test/tokens/prism_token_export_test.dart` en pose trois, et elles ne gardent
pas la même chose. Les trois ont été éprouvées par casse délibérée.

| Garde | Ce qu'elle détecte | Ce qu'elle ne voit pas |
| --- | --- | --- |
| **Fraîcheur** | une valeur Dart modifiée sans régénération | un token ajouté mais non exporté |
| **Complétude des primitives** | un `static const Color` déclaré dans `prism_colors.dart` et absent du JSON | — |
| **Complétude des rôles** | un champ de `PrismColorScheme` absent d'une apparence | — |

Les deux gardes de complétude relisent les **noms déclarés dans le source Dart**
plutôt qu'une liste écrite à la main : une liste recopiée dériverait exactement
comme le JSON qu'elle prétend garder.

La distinction compte. Ajouter `static const Color driftProbe` sans l'exporter
laisse la garde de fraîcheur **verte** — le JSON reste fidèle à ce que le
générateur produit — et seule la garde de complétude rougit. C'est la dérive par
**omission**, la plus discrète : un document qui reste valide en devenant
incomplet ne signale rien de lui-même.

Symétriquement, retirer un rôle de l'export **puis régénérer** produit un
document parfaitement cohérent et faux ; la fraîcheur est verte, la complétude
des rôles rougit sur `Set:['borderStrong']`.
