# Migrations de dépendances majeures

## Règle de découpage

Une migration majeure forme un lot et une PR autonomes lorsque son runtime, son
rollback ou sa surface de tests diffère d'une autre migration. Les changements
Flutter/Prism ne sont donc pas mélangés aux dépendances backend, contenu, IaC ou
aux workflows de runners.

## Lot livré : #155 — icônes et polices

L'application utilisait `font_awesome_flutter 10.7.0` pour onze logos de marque
et `google_fonts 6.2.1` pour sa typographie. Ces versions ne compilent pas avec
le SDK Flutter 3.44.5 du job Prism. Le lot :

- retire les deux packages incompatibles des résolutions Dart ;
- embarque Plus Jakarta Sans, Inter et JetBrains Mono dans `packages/prism_ui`
  sous licence SIL OFL 1.1 ;
- embarque uniquement la police Font Awesome Brands nécessaire et expose les
  onze glyphes utilisés via `PrismBrandIcons`, sans dépendre de son API Dart ;
- conserve l'icône e-mail via Material Icons ;
- versionne les licences et les sommes SHA-256 des quatre fontes ;
- met à jour le lockfile Prism et ajoute des contrats structurels.

Le lockfile de l'application reste volontairement non suivi tant que les SDK
Flutter app et Prism divergent, conformément à `.gitignore`. Le lockfile de
Prism reste commité et prouve l'absence des deux packages retirés.

Sources figées :

| Fonte | Source | SHA-256 |
|---|---|---|
| Plus Jakarta Sans variable | `google/fonts` (`ofl/plusjakartasans`) | `89b3fb38aa0d275d7a731d0d817a4f1622b316b4d7fbdedcf02ee9099ff68bc8` |
| Inter variable | `google/fonts` (`ofl/inter`) | `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031` |
| JetBrains Mono variable | `google/fonts` (`ofl/jetbrainsmono`) | `48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda` |
| Font Awesome Brands 400 | `font_awesome_flutter 10.7.0` / Font Awesome Free | `f29fff334747ec7d303bf58131ceddd28d1bfde973e981ce731e2d2bb93cc4e6` |

### Validation

```bash
cd packages/prism_ui
flutter pub get
flutter test test/tokens/prism_typography_test.dart test/tokens/prism_brand_icons_test.dart

cd ../../apps/mobile
flutter pub get
flutter test test/structural/icon_font_dependency_contract_test.dart
flutter analyze
```

### Rollback

Revert de la PR, puis régénération des résolutions restaure les packages, leurs
imports et le lockfile antérieurs :

```bash
cd packages/prism_ui
flutter pub get
flutter test test/tokens/prism_typography_test.dart

cd ../../apps/mobile
flutter pub get
```

## Lots restant séparés

| Lot à ouvrir | Précondition | Pourquoi il reste séparé |
|---|---|---|
| Alignement Flutter/Dart + suivi de `apps/mobile/pubspec.lock` | Coordonner avec #249 sans modifier son infrastructure runners | Ce lot touche les workflows, caches SDK, la politique de lockfile et devra exécuter toute la suite de tests Prism en CI. |
| Rafraîchissement des fontes embarquées | Nouvelle version ou nouveaux glyphes explicitement requis | Les binaires, licences, checksums et goldens doivent évoluer ensemble. |
| Adoption éventuelle de Font Awesome 11 | Un besoin produit dépasse les onze glyphes locaux | La majeure exige Dart >= 3.9 et Flutter >= 3.27 ; son API `FaIconData` est distincte d'`IconData`. |
| Migrations majeures backend, contenu ou IaC | Inventaire et tests propres à chaque écosystème | Leurs runtimes et rollbacks n'ont aucun lien avec Flutter/Prism. |

Les travaux parallèles #246 et `certigo-content#6` restent hors périmètre :
aucun schéma, contenu ou pipeline de contenu n'est modifié par ce lot.
