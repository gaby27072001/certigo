# Les types d'exercice, mesurés à la source

> **Le moteur sait rendre huit types d'exercice ; le corpus n'en utilisait que
> deux.** Ce document remplace cette asymétrie par un inventaire mesuré : pour
> chaque type, sa forme YAML réelle, le widget qui l'affiche, la façon dont il
> est corrigé des deux côtés, et ce qui l'empêche — le cas échéant — d'atteindre
> un apprenant.
>
> Discipline de preuve : `docs/GOVERNANCE.md` §7. Chaque fait daté ci-dessous
> porte la commande qui le rejoue.

## 1 · Quel corpus atteint réellement un apprenant

Deux corpus coexistent et ont divergé, ce qui rend la question « où écrire ? »
décisive : se tromper produit un travail invisible.

**Mesuré le 2026-09-11 à 16:22:16+02:00** — la production lit le conteneur
*legacy* :

```powershell
az functionapp config appsettings list -n func-certigo-prod-izfhvvxjdxc2k `
  -g rg-certigo-prod -o json | ConvertFrom-Json |
  Where-Object { $_.name -eq 'CONTENT_REPOSITORY_MODE' } | Select-Object name, value
# -> CONTENT_REPOSITORY_MODE   legacy
```

| Environnement | `CONTENT_REPOSITORY_MODE` | Source lue | Alimenté par |
|---|---|---|---|
| **production** | `legacy` | conteneur Cosmos *legacy* | `tools/seed_content.py` depuis **`content/`** de ce dépôt |
| dev | `versioned` | blob immuable | dépôt `certigo-content` |

**Conséquence, et contradiction à signaler.** Le bloc généré de
`docs/ETAT_DU_PROJET.md` qualifie `content/` de « *instantané de compatibilité,
**non actif*** » (rendu par `tools/project_state.py:1001`), et le §sur la
publication ajoute que ce dossier « ne doit plus être présenté ni utilisé comme
source éditoriale active ». La seconde affirmation décrit bien le **processus
éditorial**, qui a migré. La première est **fausse pour la production** : tant
que `CONTENT_REPOSITORY_MODE` vaut `legacy`, `content/` est exactement ce que
sert la production.

Cette correction n'est pas appliquée ici : la phrase est produite par un
générateur gardé par `ci-project-state.yml` et ses tests. Elle est signalée pour
son propriétaire.

**Donc : du contenu destiné à la production s'écrit dans `content/`.** C'est ce
que fait `content/az-900/lessons/resource-locks.lesson.yaml`.

## 2 · Les huit types, un par un

Les huit types sont déclarés **deux fois**, et les deux déclarations sont
alignées par `tools/project_state.py:parse_pedagogical_types` :

* `content/schema/lesson.schema.json` → `$defs.item.properties.type.enum` ;
* `backend/src/Certigo.Domain/Content/ContentModels.cs:27` → `enum ItemType`.

Côté client, `packages/data/lib/src/models/lesson.dart:146` ajoute une neuvième
valeur, `unknown`, qui n'est **pas** un type publiable : c'est le repli de
`itemTypeFrom` pour une valeur inconnue sur le fil.

### Noms des types et issue #245

Décision Q1 de l'orchestrateur du 2026-09-25 : les noms déjà utilisés sur le fil,
dans le corpus, les clients installés et les tentatives stockées sont **gardés**.
L'issue #245 employait d'autres noms ; voici la correspondance, reprise dans le
[contrat des exercices v5](./contracts/exercise-items/v5/README.md) :

| Nom dans #245 | `itemType` (fil, schéma, C#, Dart) |
|---|---|
| `mcq` | `mcq` |
| `multiSelect` | `multi` |
| `scenario` | `scenario` |
| `spotIssue` | `spotTheIssue` |
| `ordering` | `ordering` |
| `fillBlank` | `cloze` |
| `matching` | `matchPairs` |
| — (absent de #245) | `applied` |

### Le contrat commun

Le schéma donne **la même forme à tous les types** : `options` (2 à 6 paires
`{id, label}`) et `correct` (liste d'`id`). `tools/validate_content.mjs` exige
que chaque entrée de `correct` désigne une option existante
(`INVALID_CORRECT_REF`). Toute la variété tient donc dans l'**interprétation**
de ces deux champs.

La correction, elle, se répartit en **trois familles** côté client
(`apps/mobile/lib/features/lesson/application/answer_grading.dart:18`) :

| Famille | Types | Comparaison |
|---|---|---|
| ordonnée | `ordering`, `cloze`, `applied` | élément par élément — l'ordre **est** la réponse |
| ensembliste | `mcq`, `multi`, `scenario`, `spotTheIssue` | ensemble d'`id`, ordre indifférent |
| paires | `matchQPairs` → `matchPairs` | ensemble de jetons `"gauche:droite"` |

> ✅ **Écart client/serveur corrigé (`wp-p2-06`).** Jusqu'au 2026-09-23,
> `QuizService` et `ExamService` triaient les deux listes avant de les comparer :
> la correction serveur, qui fait autorité, acceptait pour `ordering`, `cloze` et
> `applied` une séquence dans le désordre. Le client ne note lui-même que le
> contenu de démonstration embarqué (`EmbeddedKeyGrader`, `check_outcome.dart`),
> et il le notait dans l'ordre. Pour le vrai contenu, l'app affiche le verdict
> du serveur : l'écart n'y était donc pas visible.
>
> La comparaison passe désormais par une fonction de domaine unique,
> `backend/src/Certigo.Domain/Content/AnswerGrading.cs`, jumelle de
> `isAnswerCorrect` dans `package:cortex`, à laquelle le client délègue
> (`answer_grading.dart`). Les deux ont les mêmes familles : séquence pour
> `ordering`, `cloze` et `applied`, multiensemble pour les autres types (jetons
> `"gauche:droite"` pour `matchPairs`). La parité est vérifiée par le job existant
> `ci-cortex-parity`, sur les vecteurs `parity.answerGrading` de
> `packages/cortex/test/golden/cortex_golden_vectors.json`, rejoués par
> `CortexParityTests` (C#) et `cortex_golden_test.dart` (Dart). Ces vecteurs ont
> aussi révélé l'écart inverse, côté client : un `id` en double remplaçait un `id`
> manquant. Le client compare maintenant des multiensembles.
>
> Le balayage du corpus exigé avant d'activer cette notation est consigné dans
> `docs/ETAT_DU_PROJET.md`, « Journal d'évolution ».

### Aiguillage type → widget

`apps/mobile/lib/features/lesson/presentation/widgets/step_renderer.dart`
couvre les neuf valeurs de l'énumération. Depuis l'étape 3 du contrat v5
(`wp-p2-06`), la neuvième, `unknown`, n'est plus rendue comme un QCM : elle
affiche un repli explicite (« Exercice non pris en charge »), non répondable,
qui ne bloque pas la leçon. L'avertissement connu sur les *blocs* de contenu (13 types
canoniques v2, 6 peints, intersection 2 — épinglé par
`packages/prism_ui/test/rendering/content_render_coverage_test.dart`) **ne se
transpose pas ici** : il porte sur `CanonicalBlockType`, un catalogue parallèle
que `lesson.schema.json` n'utilise pas. Les six types de blocs du schéma de
leçon (`hook`, `concept`, `example`, `code`, `check`, `recap`) sont tous rendus.

| Type | Widget | Famille | Publiable ? |
|---|---|---|---|
| `mcq` | `CheckStepWidget` (choix unique) | ensembliste | ✅ |
| `multi` | `CheckStepWidget` (choix multiple) | ensembliste | ✅ |
| `scenario` | `CheckStepWidget` (cadre « Scénario ») | ensembliste | ✅ |
| `spotTheIssue` | `CheckStepWidget` (cadre « Repère l'erreur ») | ensembliste | ✅ |
| `cloze` | `ClozeStepWidget` | ordonnée | ✅ |
| `ordering` | `OrderingStepWidget` | ordonnée | ✅ |
| `applied` | `OrderingStepWidget` (sélection partielle, au moins 2 étapes) | ordonnée | ✅ sans distracteur, voir « Garde provisoire » |
| `matchPairs` | `MatchPairsStepWidget` | paires | ❌ en legacy, voir §3 ; exprimable en contrat v5 |
| *inconnu* | repli explicite, non répondable | — | — |

### Formes YAML et exemples minimaux valides

Chaque exemple ci-dessous est validé par `node tools/validate_content.mjs`.

#### `mcq` — une seule bonne réponse

Exactement une entrée dans `correct` (imposé par le validateur).

```yaml
- type: check
  conceptId: c-exemple
  check:
    id: ex-mcq
    conceptId: c-exemple
    type: mcq
    difficulty: 2
    stem: Sur quelle portée est-il impossible de poser un verrou ?
    options:
      - { id: a, label: "Le groupe de gestion" }
      - { id: b, label: "L'abonnement" }
    correct: [a]
    explanation: Les verrous s'appliquent à un abonnement, un groupe de ressources ou une ressource.
```

#### `multi` — plusieurs bonnes réponses

Le **seul** type rendu en sélection multiple
(`check_step_widget.dart:43` : `final bool multi = item.type == ItemType.multi;`).
Une seule bonne réponse en ferait un `mcq` déguisé, impossible à distinguer à
l'écran : le validateur exige donc **au moins deux** entrées dans `correct`.

```yaml
    type: multi
    stem: Quels rôles peuvent retirer un verrou ? Plusieurs réponses.
    options:
      - { id: a, label: "Propriétaire" }
      - { id: b, label: "Administrateur de l'accès utilisateur" }
      - { id: c, label: "Contributeur" }
    correct: [a, b]
```

#### `scenario` — une mise en situation, une issue

Même rendu que `mcq`, cadre visuel différent. Exactement une bonne réponse.

```yaml
    type: scenario
    stem: >
      Un verrou ReadOnly est posé sur un conteneur Cosmos DB. Une application y
      écrit en continu. Que deviennent ces écritures ?
    options:
      - { id: a, label: "Elles continuent : le verrou ne couvre que le plan de gestion" }
      - { id: b, label: "Elles échouent" }
    correct: [a]
```

#### `spotTheIssue` — repérer la décision fautive

Rendu en **sélection unique** : `correct` doit contenir exactement un `id`, sinon
la seconde bonne réponse serait inatteignable. Le validateur l'impose.

```yaml
    type: spotTheIssue
    stem: Voici le plan de l'équipe. Quelle décision manque son objectif ?
    options:
      - { id: a, label: "Poser un verrou sur le groupe de gestion" }
      - { id: b, label: "Poser un verrou sur le groupe de ressources" }
    correct: [a]
```

#### `cloze` — compléter une phrase

* Le `stem` porte les trous : **une suite d'au moins quatre `_`**
  (`answer_grading.dart:36` : `RegExp('_{4,}')`).
* `options` est la **banque de mots**, distracteurs inclus.
* `correct` est la liste **ordonnée** des `id`, un par trou, dans l'ordre des
  trous.

Le nombre de trous doit égaler `correct.length` : la CTA de validation n'apparaît
que lorsque `selection.length == blanks`
(`lesson_session_state.dart:105`). Un désaccord produit un item **valide mais
insoumettable** ; le validateur le refuse désormais.

```yaml
    type: cloze
    stem: >-
      Un verrou ____ laisse encore modifier la ressource, tandis qu'un verrou
      ____ la fige totalement.
    options:
      - { id: o-cannotdelete, label: "CanNotDelete" }
      - { id: o-readonly, label: "ReadOnly" }
      - { id: o-deny, label: "Deny" }
    correct: [o-cannotdelete, o-readonly]
```

#### `ordering` — remettre une séquence dans l'ordre

`correct` doit énumérer **toutes** les options dans le bon ordre (imposé de
longue date par le validateur). **Rédiger `options` dans un ordre différent de
`correct`** : sinon la réponse est l'ordre d'affichage, et l'exercice ne mesure
plus rien.

```yaml
    type: ordering
    stem: Range les quatre portées d'Azure, de la plus large à la plus étroite.
    options:
      - { id: s-rg, label: "Groupe de ressources" }
      - { id: s-res, label: "Ressource" }
      - { id: s-mg, label: "Groupe de gestion" }
      - { id: s-sub, label: "Abonnement" }
    correct: [s-mg, s-sub, s-rg, s-res]
```

#### `applied` — appliquer une procédure à un cas

Même widget et même correction ordonnée qu'`ordering`. La cible est le format
« Build list and reorder » des examens Microsoft : parmi une liste d'actions,
choisir les bonnes et les ordonner, en laissant de côté des actions pièges.
`correct` est donc, à terme, un **sous-ensemble ordonné** des options, et les
options non citées sont des distracteurs, ce qu'`ordering` n'autorise pas. Au
moins deux entrées : une seule n'a pas d'ordre.

##### Garde provisoire sur les distracteurs d'`applied`

Décision Q-G de l'orchestrateur, 2026-09-25 (« expand avant usage ») : **tant que
l'app ne permet pas de valider une sélection partielle, aucun `applied` avec
distracteurs n'est publiable.** Aujourd'hui, `canSubmitCurrent`
(`lesson_session_state.dart`) n'active la validation qu'une fois **toutes** les
options placées : un corrigé plus court que la liste des options serait
impossible à réussir. Deux gardes l'empêchent, et aucun item du corpus n'est
concerné (balayage du 2026-09-25) :

* `tools/validate_content.mjs` rejette un `applied` dont `correct` ne cite pas
  toutes les options (`APPLIED_DISTRACTORS_NOT_YET_SUPPORTED`) ;
* `tools/sweep_answer_grading.py` signale le même cas (`APPLIED_UNSUBMITTABLE`).

**Quand la lever** : quand ces trois conditions sont vraies, et pas avant.

1. L'app permet de valider un `applied` dès qu'au moins 2 étapes sont placées,
   avec un réordonnancement accessible (VoiceOver, cibles de 44 pt, Dynamic
   Type). C'est l'étape 3 du [contrat v5](./contracts/exercise-items/v5/README.md),
   écrite dans la branche `gchambaud-microsoft-wp-p2-06-v5-expand` (2026-09-25) : la
   condition est remplie une fois cette branche fusionnée et déployée.
2. Cette version est la seule en circulation chez les apprenants : la dernière
   build TestFlight distribuée, vérifiée dans App Store Connect.
3. Les vecteurs de parité couvrent les sous-ensembles (`parity.answerGrading` :
   cinq cas, du bon ordre au distracteur choisi). C'est déjà fait.

**Comment la lever** : dans une même PR, retirer la règle
`APPLIED_DISTRACTORS_NOT_YET_SUPPORTED` et inverser son test, remplacer
`APPLIED_UNSUBMITTABLE` par la règle du nouveau `canSubmitCurrent` (au moins 2
étapes), puis mettre à jour cette section.

```yaml
    type: applied
    stem: Classe les étapes dans l'ordre où elles doivent être menées.
    options:
      - { id: p-remove, label: "Retirer le verrou" }
      - { id: p-delete, label: "Supprimer le groupe de ressources" }
      - { id: p-locate, label: "Localiser le verrou et sa portée" }
    correct: [p-locate, p-remove, p-delete]
```

## 3 · `matchPairs` — implémenté des deux côtés, inatteignable en legacy

Depuis l'étape 3 du [contrat v5](./contracts/exercise-items/v5/README.md), une
release runtime v5 exprime `matches`, que le serveur projette dans `LessonCheck`
et que le client runtime lit. Ce qui suit décrit le chemin **legacy**
(`content/`, `tools/seed_content.py`), toujours servi en prod, où les quatre
obstacles demeurent.

`MatchPairsStepWidget` existe (9 011 octets), fonctionne, et affiche deux
colonnes. La colonne **gauche** vient de `options` ; la colonne **droite** vient
d'un champ distinct, `matches` (`lesson.dart:196`). Quatre obstacles
indépendants empêchent `matches` d'exister dans un item publié :

1. **Le schéma l'interdit.** `$defs.item` porte `additionalProperties: false` et
   ne déclare pas `matches` — écrire ce champ échoue à la validation.
2. **Le serveur ne le transporte pas.** `LessonCheck`
   (`ContentModels.cs:46`) expose `Id, ConceptId, Type, Stem, Options`. Aucun
   champ pour la colonne droite.
3. **La publication ne l'émet pas.** `tools/seed_content.py:57` réduit chaque
   item à `id, conceptId, type, stem, options`.
4. **La clé de réponse est inexprimable.** La correction attend des jetons
   `"gauche:droite"` (`matchToken`), qui ne sont par construction l'`id`
   d'aucune option : `INVALID_CORRECT_REF` les rejette.

Conséquence mesurable : un `matchPairs` publié arrive avec `matches` vide, donc
`isAnswerableCheck` rend `false` (`lesson_session_state.dart:17` exige
`matches.length >= options.length`) et la colonne droite s'affiche vide. Le
learner voit un exercice qu'il ne peut pas résoudre.

**Le seul endroit où ce widget est observable aujourd'hui** est le mode démo :
`apps/mobile/lib/features/lesson/application/sample_lesson.dart:130` construit
son item `matchPairs` **en Dart**, avec ses `matches`, en court-circuitant les
quatre obstacles. Le mode démo prouve donc à la fois que le widget marche et que
la chaîne de contenu ne sait pas l'exprimer.

Débloquer `matchPairs` demande les quatre changements ci-dessus, dont deux
touchent la plomberie de publication. C'est pourquoi il est **épinglé** plutôt
que forcé (voir §4), et pourquoi le validateur le rejette désormais avec sa
raison plutôt qu'avec un `INVALID_CORRECT_REF` opaque.

## 4 · Les deux cliquets

Le dépôt construit des mécanismes et ne les branche pas ; huit types implémentés
pour deux utilisés en était la forme éditoriale. Deux gardes empêchent la
rechute, **chacune dans une gate réellement exécutée**.

### Côté corpus — `tools/validate_content.mjs`

`validateExerciseDiversity` compare l'énumération du schéma à ce que le corpus
exerce réellement, et **épingle l'écart** :

```js
export const UNUSED_ITEM_TYPES_PIN = Object.freeze(['matchPairs']);
```

Rougit si : un type cesse d'être utilisé · un type est déclaré sans contenu · un
type épinglé commence à être utilisé (il faut alors réduire l'épingle) · le
corpus utilise un type non déclaré · **l'instrument devient muet** (catalogue ou
corpus vide).

S'y ajoute `validateItemTypeShape`, qui exprime les règles d'arité que le schéma
JSON ne peut pas porter — arité `cloze`, `applied` et `multi` à deux réponses
minimum, `spotTheIssue` à une seule, `matchPairs` refusé avec sa raison.

> **Pourquoi dans ce fichier et pas dans `tools/tests/`.** `ci-content.yml`
> n'exécute qu'une commande : `node tools/validate_content.mjs`. **Mesuré le
> 2026-09-11** : aucun workflow n'exécute `npm run test:content` ni
> `tools/tests/*.test.mjs` (seul `build_public_pages.test.mjs` est appelé, par
> `ci-infra.yml`). Un cliquet placé dans `tools/tests/` n'aurait jamais mordu en
> CI. Les tests unitaires y sont tout de même ajoutés, par convention du dépôt.
>
> ```powershell
> git --no-pager grep -rn -E "test:content|tools/tests" -- .github/workflows/
> ```

### Côté application — `apps/mobile/test/exercise_variety_render_test.dart`

Exécuté par `ci-mobile.yml` (`flutter test --coverage`). Il fait passer la
charge utile **publique** de chaque type dans le vrai `StepRenderer` et vérifie
que chacun atteint le widget attendu, qu'il est répondable, que `matchPairs`
publié ne l'est pas — et il épingle les familles de correction du client, dont la
parité avec le serveur est prouvée par les vecteurs partagés du §2.

### Preuve que les cliquets mordent
Mesuré le 2026-09-11, chaque mutation accompagnée de l'empreinte SHA-256 du
fichier avant/après (sans ce témoin, une substitution qui n'a rien remplacé
laisse la gate verte et fait croire à un cliquet mort — c'est arrivé à la
première tentative, `` `n `` ne correspondant pas à des fins de ligne CRLF) :

| Régression simulée | Résultat |
|---|---|
| Plus aucun item `cloze` | `ITEM_TYPE_COVERAGE_CHANGED … now [cloze, matchPairs]` |
| Un item `matchPairs` rédigé | `UNSUPPORTED_ITEM_TYPE … cannot express` |
| `cloze` à 2 trous, 1 réponse | `2 blank(s) but 1 correct answer(s)` |
| `multi` à 1 bonne réponse | `needs at least 2 correct ids` |
| 9ᵉ type déclaré, zéro usage | `now [dragDrop, matchPairs], the pin says [matchPairs]` |
| `cloze` aiguillé vers `CheckStepWidget` | `cloze est rendu par ClozeStepWidget` échoue |

Dans les six cas l'arbre restauré redevient vert, et `git diff` est vide.

## 5 · Voir les exercices — captures lisibles

`apps/mobile/test/exercise_variety_capture_test.dart` produit une image par type,
dans `apps/mobile/test/exercise-captures/` :

```powershell
cd apps/mobile
flutter test test/exercise_variety_capture_test.dart --tags capture --update-goldens
```

**Ce n'est pas une gate.** Sans `--update-goldens`, les neuf cas sont ignorés et
rien n'est comparé : des pixels produits sous Windows ne peuvent pas être rejoués
à l'identique sur un runner Linux, et une gate qui échoue pour cette raison ne
surveillerait rien. La non-régression est assurée par les deux cliquets du §4.

Deux détails valent d'être notés, parce qu'ils font la différence entre une
capture utile et une capture qui ment :

* **Les polices réelles sont chargées.** Le harnais de test dessine sinon chaque
  glyphe comme un rectangle plein — le golden `apps/mobile/test/goldens/manager_dashboard.png`
  du dépôt en est l'illustration : il prouve une mise en page, pas un texte.
  Le nom de famille à charger est celui que Flutter **résout**
  (`packages/prism_ui/Archivo`), pas celui déclaré (`Archivo`).
* **`RenderRepaintBoundary.toImage()` ne fonctionne pas ici.** Mesuré : sous le
  binding de test automatisé, son future attend une trame que rien ne planifie,
  et la suite se bloque indéfiniment au lieu d'échouer. `matchesGoldenFile` est
  le seul chemin qui pilote correctement la rastérisation.

### Ce que les captures ont révélé

Regarder les images a produit une trouvaille qu'aucune assertion n'avait vue.

**`matchPairs` publié est visiblement insoluble.** La colonne gauche s'affiche,
la colonne droite est vide, et l'app invite quand même à « toucher un concept
puis sa correspondance » — alors qu'il n'y a aucune correspondance à toucher.
Les deux captures `matchPairs-publie-colonne-vide.png` et
`matchPairs-embarque-mode-demo.png` montrent le **même widget avec le même
énoncé** : seul le champ `matches` les sépare.

**Le trou vide d'un `cloze` occupe toute la largeur de la ligne.**
`_EmptyBlank` (`cloze_step_widget.dart`) ne pose qu'une contrainte
`minWidth: 64` ; placé dans un `Wrap`, il s'étire jusqu'au bord et casse la
lecture en ligne de la phrase à compléter — l'effet recherché par ce type
d'exercice. Le rendu reste fonctionnel, et le défaut disparaît dès qu'un mot est
déposé. Correctif hors périmètre (`apps/mobile/lib/`), signalé ici.

## 6 · Rédiger un exercice qui vaut quelque chose
Le critère déjà appliqué dans `certigo-content` (#92) : **une question devinable
sans avoir lu la leçon ne vaut rien.** En pratique :

* les distracteurs viennent de notions **voisines et réelles** — dans la leçon
  sur les verrous, `Deny` (un effet d'Azure Policy) et `Reader` (un rôle RBAC)
  sont plausibles pour qui n'a pas lu ;
* un `ordering` ou un `applied` doit avoir un **ordre naturel défendable** —
  chaque étape rend la suivante possible. Sans cela, il est pire qu'un QCM :
  il punit une réponse juste ;
* `options` ne doit **jamais** être rédigé dans l'ordre de `correct` ;
* l'`explanation` explique aussi **pourquoi les distracteurs sont faux**.
