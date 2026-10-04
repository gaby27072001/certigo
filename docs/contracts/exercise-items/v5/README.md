# Contrat des exercices v5 — un contrat par type

| Champ | Valeur |
|---|---|
| **Statut** | Spécification prête pour `certigo-content` (2026-09-25) |
| **Lot** | `wp-p2-06` / #245 |
| **Décisions** | Q1, Q2 et Q3 de l'orchestrateur, 2026-09-25, par délégation (voir [ADR-023](../../../adr/ADR-023-exercices-multiformats-v5.md)) |
| **Remplace** | rien : la v4 reste acceptée (expand) |

Ce document est la **spécification** de la variante `v5` des questions publiques et des
corrigés privés. Le schéma canonique, le validateur et le packager restent la propriété de
`certigo-content`. Les fichiers `question-v5.proposed.schema.json` et
`solution-v5.proposed.schema.json` sont une **proposition** à intégrer dans les `oneOf` de
`question.schema.json` et `solution.schema.json`. Les exemples de `examples/` sont valides
selon ces deux schémas et selon les règles croisées du §5.

## 1. Portée

- Nouvelle variante `schemaVersion: "v5"` dans les deux schémas existants. Les variantes
  v2, v3 et v4 ne changent pas.
- Aucun nouveau type de ressource : les fichiers v5 restent des `question` et des
  `solution` dans le manifeste de paquet `certigo.content.package-manifest/v3`.
- Le contrat de soumission ne change pas : `selected: string[]`.
- Hors portée : le chemin `legacy` (`content/`, `tools/seed_content.py`), qui reste servi
  tel quel en prod tant que `CONTENT_REPOSITORY_MODE=legacy`.

## 2. Noms des types (décision Q1 : garder)

Les noms déjà utilisés sur le fil, dans le corpus, les clients installés et les tentatives
stockées sont gardés. L'issue #245 employait d'autres noms. Correspondance :

| Nom dans #245 | `itemType` (fil, schéma, C#, Dart) | Famille de notation |
|---|---|---|
| `mcq` | `mcq` | ensemble |
| `multiSelect` | `multi` | ensemble |
| `scenario` | `scenario` | ensemble |
| `spotIssue` | `spotTheIssue` | ensemble |
| `ordering` | `ordering` | séquence |
| `fillBlank` | `cloze` | séquence |
| `matching` | `matchPairs` | ensemble de jetons |
| — (absent de #245) | `applied` | séquence |

## 3. Question publique v5 (`kind: "public"`)

Champs communs, inchangés depuis v4 : `id`, `legacyId` (facultatif), `schemaVersion`,
`kind`, `metadata` (runtime), `itemType`, `difficulty` (1 à 3), `prompt`, `options`.
Nouveau champ : `matches`, **uniquement** pour `matchPairs`.

| `itemType` | Charge publique |
|---|---|
| `mcq`, `scenario`, `spotTheIssue` | `options` : 2 à 8 |
| `multi` | `options` : 3 à 8 |
| `ordering` | `options` : 2 à 8, les éléments à ordonner |
| `applied` | `options` : 2 à 8, les étapes et d'éventuels distracteurs |
| `cloze` | `prompt` avec N trous, N de 1 à 6 (un trou = une suite d'au moins 4 `_`, comme `answer_grading.dart`) ; `options` : banque de mots, au moins N |
| `matchPairs` | `options` : colonne gauche, 2 à 8 ; `matches` : colonne droite, même cardinal |

Une option ou un match est `{ "id", "label" }`. Les `id` suivent le motif v4
`^[a-z0-9]+(?:-[a-z0-9]+)*$`.

**Anti-fuite** (inchangé, étendu) : aucune clé `answerKey`, `correct`, `correctOptionIds`,
`explanation`, `privateManifestId`, `rationale`, `solution` ni `pairs`, à aucune
profondeur. Le schéma l'impose par `additionalProperties: false`. Le backend le revérifie
récursivement à l'import.

## 4. Corrigé privé v5 (`kind: "answerKey"`)

Champs : `id` (celui de la question), `schemaVersion: "v5"`, `kind`, `itemType` (nouveau,
redondant avec la question et vérifié égal), `correctOptionIds`, `rationale`.

| `itemType` | `correctOptionIds` | Nature |
|---|---|---|
| `mcq`, `scenario`, `spotTheIssue` | exactement 1 id d'option | ensemble |
| `multi` | au moins 2 ids d'options | ensemble |
| `ordering` | **tous** les ids d'options, une fois chacun, dans le bon ordre | séquence |
| `applied` | au moins 2 ids d'options, dans le bon ordre ; les options absentes sont des distracteurs | séquence |
| `cloze` | exactement N ids d'options, un par trou, dans l'ordre des trous | séquence |
| `matchPairs` | un jeton `"<idGauche>:<idDroite>"` par option de gauche | ensemble de jetons |

`correctOptionIds` n'a jamais de doublon (`uniqueItems`). Pour `cloze`, un même mot ne
remplit donc qu'un trou : s'il en faut deux, on crée deux options aux `id` distincts.
Porter `itemType` dans le corrigé permet au schéma seul d'imposer les cardinalités et le
motif des jetons de `matchPairs`.

## 5. Règles croisées question ↔ corrigé

Le schéma ne voit qu'un fichier à la fois. Ces règles lient les deux et s'appliquent **deux
fois** : dans le validateur et le packager de `certigo-content`, puis à l'import dans
`ContentContractVerifier`, qui rejette la release **avant toute écriture**.

| Règle | Types | Contrainte |
|---|---|---|
| X1 | tous | `solution.itemType == question.itemType` |
| X2 | tous | les `id` de `options` sont uniques, ceux de `matches` aussi ; `options` et `matches` sont disjoints |
| X3 | tous sauf `matchPairs` | chaque `correctOptionIds[i]` désigne une option |
| X4 | `ordering` | `correctOptionIds` est une permutation de toutes les options |
| X5 | `applied` | 2 ≤ taille de `correctOptionIds` ≤ taille de `options` |
| X6 | `cloze` | N = nombre de trous du `prompt`, 1 ≤ N ≤ 6 ; `correctOptionIds` compte N éléments ; `options` en compte au moins N |
| X7 | `matchPairs` | `options` et `matches` ont le même cardinal ; chaque jeton `g:d` a `g` dans `options` et `d` dans `matches` ; chaque `g` et chaque `d` apparaît une seule fois (bijection) |
| X8 | `ordering`, `applied` | l'ordre publié ne donne pas la réponse : les options citées par `correctOptionIds`, prises dans l'ordre de `options`, ne forment pas la suite `correctOptionIds` |
| X9 | `matchPairs` | l'ordre publié ne donne pas les paires : il existe au moins un `i` tel que `options[i]` n'est pas associée à `matches[i]` |

X8 et X9 remplacent la règle « publiés triés par `id` » de la première version d'ADR-023 :
un tri par `id` révèle la réponse dès que les `id` encodent le rang (`s-1`, `s-2`, …).

## 6. Notation (décision Q2 : sensible à l'ordre)

La correction serveur fait autorité. Elle est identique à celle du client
(`answer_grading.dart`) et passe par une fonction de domaine unique
(`backend/src/Certigo.Domain/Content/AnswerGrading.cs`).

| Famille | Types | `selected` | Juste si |
|---|---|---|---|
| ensemble | `mcq`, `multi`, `scenario`, `spotTheIssue` | ids d'options | même multiensemble que le corrigé |
| séquence | `ordering`, `applied`, `cloze` | ids dans l'ordre choisi (pour `cloze`, l'ordre des trous) | même suite, élément par élément |
| jetons | `matchPairs` | jetons `g:d` | même multiensemble de jetons |

Les vecteurs partagés sont le groupe `parity.answerGrading` de
[`packages/cortex/test/golden/cortex_golden_vectors.json`](../../../../packages/cortex/test/golden/cortex_golden_vectors.json).
Le job existant `ci-cortex-parity` les rejoue en C# (`CortexParityTests`) et en Dart
(`cortex_golden_test.dart`, sur `isAnswerCorrect` de `package:cortex`, auquel le client
délègue). Conditions posées par la décision Q2 avant d'activer
cette notation : balayage du corpus, parité vérifiée par le job existant, aucune tentative
stockée réécrite, note datée dans l'état du projet.

## 7. Séquence imposée (décision Q3, garde `certigo-content#94`)

La garde « expand avant usage » de `certigo-content` refuse tout paquet que le backend
n'importerait pas. L'ordre est donc strict :

1. **Cette spécification.**
2. **`certigo-content`** : schéma canonique v5 (les deux `oneOf` étendus), validateur et
   packager qui acceptent v5 et appliquent le §5, **sans aucun contenu v5**.
3. **Certigo** : schémas embarqués v5 (copies à l'octet), modèles C# et Dart,
   `LessonCheck.Matches` (ajout), lecture de `matches` par le client runtime, règles du
   §5 dans `ContentContractVerifier`, anti-fuite par type, repli explicite pour un
   `itemType` inconnu (aujourd'hui rendu comme un QCM, `step_renderer.dart:97`), goldens par
   type. Pour `applied` (décision Q-G du 2026-09-25) : l'app permet de valider une sélection
   d'au moins 2 étapes placées, avec un réordonnancement accessible (VoiceOver, cibles de
   44 pt, Dynamic Type) ; le serveur note l'ensemble **et** l'ordre. Puis déploiement en dev,
   en staging et en prod.
4. **`certigo-content`** : resynchronisation de sa copie des schémas embarqués. La garde
   accepte alors v5.
5. **Contenu** : seulement ensuite, des questions `ordering`, `cloze`, `applied` ou
   `matchPairs` en v5, dans une nouvelle release. Import en staging d'abord. Aucune
   activation en prod sans le plan de bascule validé par l'orchestrateur.

## 8. Compatibilité et retour arrière

- Une release v4 reste importable et promouvable. Revenir à une release v4 se fait par le
  rollback N-1 du pointeur, sans toucher aux données.
- Un client antérieur à l'étape 3 ne lit pas `matches` : un `matchPairs` v5 y serait
  insoluble. En prod, l'app n'active pas le contenu runtime (`RUNTIME_CONTENT_MOBILE=false`).
  Le déploiement de l'étape 3 précède donc toute release v5.
- De même, un `applied` avec distracteurs est insoluble tant que l'app exige que toutes
  les options soient placées. Une garde provisoire l'empêche dans le corpus legacy, et
  aucun contenu v5 de ce genre n'est publié avant l'étape 3. Conditions et procédure de
  levée : `docs/EXERCICES.md`, « Garde provisoire sur les distracteurs d'`applied` ».
- Le retrait de v4 (*contract*) est hors de ce lot. Il n'aura lieu que lorsque plus aucune
  release active ne la porte.

## 9. Critères d'acceptation, par type

Pour chacun des huit types (DoD de #245) : schéma public, schéma privé, validation (§5),
modèle Dart, modèle C#, correction serveur, rendu, test unitaire, golden et test
anti-fuite.

## 10. Exemples

`examples/<itemType>.question.json` et `examples/<itemType>.solution.json`, un couple par
type. Ils sont valides selon les deux schémas proposés et selon toutes les règles du §5.
