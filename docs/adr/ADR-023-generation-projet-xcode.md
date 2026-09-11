# ADR-023 — Le projet Xcode est généré, pas versionné

| Champ | Valeur |
|---|---|
| **ADR** | 023 |
| **Statut** | Accepté |
| **Date** | 2026-09-11 |
| **Outil retenu** | XcodeGen (`apps/ios/project.yml`) |
| **Périmètre** | `apps/ios/` uniquement. `apps/mobile/ios/Runner.xcodeproj` appartient à Flutter et n'est pas touché. |

## Contexte

Ajouter **un seul** fichier Swift à un projet Xcode classique modifie `project.pbxproj` en
**quatre endroits** — `PBXBuildFile`, `PBXFileReference`, le tableau `children` du `PBXGroup`, et
le tableau `files` de la `PBXSourcesBuildPhase` — chacun avec un identifiant hexadécimal de
24 caractères tiré au hasard.

Deux branches qui ajoutent chacune un fichier écrivent donc dans **les mêmes tableaux**. Git a
alors deux issues, et les deux sont mauvaises :

1. **Conflit textuel** — illisible, non résoluble à la main de façon fiable.
2. **Fusion textuelle « réussie »** — **le cas dangereux** : le fichier se fusionne sans conflit,
   mais le projet obtenu est incohérent ou a perdu une référence. **Rien ne rougit.**

Sur un dépôt où plusieurs agents travaillent en parallèle, ce blocage arrive dès la deuxième
semaine.

**Un fait du dépôt rend le changement naturel plutôt que disruptif :** il n'existe **aucun
`Podfile` versionné** dans ce dépôt — ni suivi, ni ignoré. La configuration CocoaPods du projet
Flutter est déjà régénérée depuis le gabarit à chaque build, sans que cela ait jamais posé
problème. Passer à un `.xcodeproj` généré ne rompt donc aucune pratique : **cela formalise une
pratique existante.**

## Décision

### 1. SPM d'abord — c'est le gros du gain, et il est gratuit

Environ 90 % du code vit dans `apps/ios/Packages/CertigoKit`. **`Package.swift` ne liste aucun
fichier** : SwiftPM les découvre par convention de répertoire. Ajouter un écran, un Store, un
composant ⇒ **zéro modification de fichier de projet, donc zéro conflit possible**.

C'est une décision d'architecture (ADR-022) qui se trouve résoudre un problème d'outillage.

### 2. XcodeGen pour la coquille

Il demeure une cible d'application et une cible de test. Elles changent rarement, mais quand
elles changent, le diff doit être lisible. `project.yml` tient en quelques dizaines de lignes de
YAML qu'un agent sait éditer depuis Windows.

**`*.xcodeproj/` passe au `.gitignore`.** `App/Info.plist`, généré par XcodeGen depuis
`project.yml`, également.

### 3. Pourquoi XcodeGen et non Tuist

| | XcodeGen | Tuist |
|---|---|---|
| Format | YAML — lisible, fusionnable, éditable sans Swift | DSL Swift |
| Coût d'entrée | Faible : un fichier | Moyen : DSL, cache, graphe, version à épingler |
| Dépendance ajoutée | Une, sur le poste de build | Une, **structurante** |
| Gain propre | — | Cache de build sur gros graphes |

Pour **un** développeur et **une** application, le cache de Tuist ne rembourse ni sa courbe
d'apprentissage ni sa version à épingler. **Tuist n'est pas écarté par principe** : à rouvrir si
un `apps/android/` natif arrive, ou si le graphe de modules grossit.

### 4. `Scripts/demarrer.sh` est la seule façon d'ouvrir le projet

Le nouveau mode de panne introduit est réel : `git pull` puis double-clic sur un `.xcodeproj`
périmé. La parade est un script unique, documenté comme le seul point d'entrée, qui génère avant
de compiler.

**La génération devient un test** : si `project.yml` est faux, on l'apprend à l'étape 4 sur 6,
avec le message de XcodeGen.

## Contre-arguments, énoncés franchement

- **Le `.xcodeproj` n'est plus dans le dépôt.** Ouvrir le projet exige d'abord `xcodegen
  generate`. Parade : le script, et `DEMARRAGE.md`.
- **XcodeGen est un binaire macOS.** Un agent peut éditer `project.yml` mais **ne peut pas
  vérifier** que la génération réussit. Parade : à terme, la CI génère puis compile à chaque PR.
  **Aujourd'hui cette parade n'existe pas** — c'est une dette assumée et datée.
- **Cela ne s'applique pas à `apps/mobile/ios`.** Ce projet appartient à Flutter et reste tel
  quel. Le changement est **purement additif** : il ne touche rien d'existant.

## Conséquences

- Supprimer `apps/ios/` laisse le dépôt exactement dans son état antérieur.
- Un nouvel arrivant doit lire `DEMARRAGE.md` avant d'ouvrir Xcode. C'est le prix, et il est
  documenté en tête du dossier.
