# Mascottes Microlingo — comment fournir tes personnages

Ce dossier accueille l'art de tes personnages (l'équivalent de Duo & ses amis).
Une fois les images déposées ici **avec les bons noms**, elles apparaissent
automatiquement partout : accueil, chemin, onboarding — **sans toucher au code
des écrans**. Le rendu passe par `MascotRegistry` (dans `prism_ui`).

## 1. Les 7 personnages (ids) — chacun = une icône Azure « cutifiée »

| id         | basé sur l'icône Azure…        | personnalité                  | où on le voit beaucoup        |
|------------|--------------------------------|-------------------------------|-------------------------------|
| `nimbus`   | Azure (le logo / « A » nuage)  | le guide (le "Duo")           | accueil, onboarding, splash   |
| `volt`     | Azure Functions (éclair)       | hyperactif, énergique         | gardien d'unité (chemin)      |
| `cosmo`    | Azure Cosmos DB (planète)      | calme, rêveur                 | gardien d'unité (chemin)      |
| `sentinel` | Microsoft Defender (bouclier)  | protecteur, loyal             | gardien d'unité (chemin)      |
| `bicky`    | Bicep (bras musclé)            | costaud fier, méthodique      | gardien d'unité (chemin)      |
| `pixel`    | Azure AI / Foundry (✨)        | curieux, créatif              | gardien d'unité (chemin)      |
| `pip`      | Azure Blob Storage (un blob)   | l'apprenant (toi)             | profil, récompenses           |

## 2. Les 4 expressions (moods)

`idle` · `happy` · `celebrate` · `sad`

`idle` est **obligatoire** par personnage (c'est le repli). Les autres sont
optionnelles : si `happy.png` manque, on retombe sur `idle.png`, puis sur le
visage dessiné par défaut. **Rien ne casse** si une image manque.

## 3. Convention de nommage (la seule chose à respecter)

```
assets/mascots/<id>/<mood>.png
```

Exemples :

```
assets/mascots/nimbus/idle.png
assets/mascots/nimbus/happy.png
assets/mascots/nimbus/celebrate.png
assets/mascots/volt/idle.png
assets/mascots/cosmo/idle.png
...
```

## 4. Specs d'image recommandées

- **Format** : PNG (ou WebP) avec **fond transparent**.
- **Cadrage** :
  - *Disque* (en-têtes, gardiens du chemin, listes) → le personnage est rogné
    en cercle. Centre bien le visage/buste.
  - *Plein corps* (accueil, onboarding) → personnage entier, marges réduites ;
    il est affiché tel quel, non rogné.
- **Taille** : ~512×512 px (ou plus), carré de préférence.
- **Poids** : vise < 200 Ko par image.

Tu peux livrer **une seule image par personnage** (juste `idle.png`) pour
démarrer : elle sera utilisée pour toutes les expressions.

## 5. Activation (1 fois, déjà préparée)

Quand les images sont là :

1. Dé-commente le bloc `assets:` dans `apps/mobile/pubspec.yaml`.
2. Dé-commente l'appel `MascotRegistry.instance.useImageAssets();` dans
   `apps/mobile/lib/app/mascots.dart`.
3. `flutter pub get` puis relance l'app.

C'est tout. Dis-moi simplement « voici les mascottes » + le zip, je m'occupe des
3 étapes et de l'intégration.
