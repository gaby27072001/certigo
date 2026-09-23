# ADR-022 — Exercices multi-formats : un contrat par type (v5)

| Champ | Valeur |
|---|---|
| **ADR** | 022 |
| **Statut** | Proposé — trois décisions en attente (voir « Décisions à valider ») |
| **Date** | 2026-09-23 |
| **Lot** | `wp-p2-06` / #245 |
| **Dépend de** | ADR-019 (releases runtime), `docs/GOVERNANCE.md` (expand / migrate / contract) |

## Contexte

Constat mesuré le 2026-09-23 sur `main` et `certigo-content` `main` :

- Le schéma runtime **v4** des questions (canonique `certigo-content`, copie embarquée
  dans `backend/src/Certigo.Infrastructure/ContentContracts/Schemas/`) n'accepte que
  `itemType ∈ {mcq, multi, scenario, spotTheIssue}` avec `options[{id,label}]`.
  `ordering`, `cloze` et `matchPairs` ne sont **pas publiables** en release runtime.
- Le corrigé v4 est générique : `correctOptionIds[]` + `rationale`. Il ne sait
  exprimer ni un ordre, ni une réponse par trou, ni des paires.
- Le chemin `legacy` servi en prod (`tools/seed_content.py`) connaît huit types
  (`mcq, multi, scenario, cloze, ordering, matchPairs, spotTheIssue, applied`), mais le
  check public ne porte que `options` : `matchPairs` arrive sans colonne droite et reste
  inauteurable (voir `docs/EXERCICES.md`).
- La correction serveur (`QuizService.IsCorrect`) **trie** réponse attendue et réponse
  soumise : l'ordre est ignoré pour `ordering`, `cloze` et `applied`, alors que le client
  le note. C'est un écart de parité client/serveur.
- Les rendus Prism existent pour les huit types (`StepRenderer`). Un type inconnu est
  rendu comme un QCM, sans fallback explicite. Les captures d'exercices ne sont pas une
  gate CI.

## Décision proposée

### 1. Noms sur le fil inchangés

| Nom de l'issue #245 | Nom sur le fil (inchangé) |
|---|---|
| `mcq` | `mcq` |
| `multiSelect` | `multi` |
| `scenario` | `scenario` |
| `ordering` | `ordering` |
| `matching` | `matchPairs` |
| `fillBlank` | `cloze` |
| `spotIssue` | `spotTheIssue` |

Renommer imposerait une migration cassante du corpus, des clients déjà installés et des
tentatives stockées, pour aucun bénéfice produit. `applied` reste un huitième type,
noté comme `ordering`.

### 2. Charge publique v5 — union discriminée sur `itemType`, champs existants réutilisés

Champs communs : `id`, `schemaVersion: "v5"`, `kind: "public"`, `metadata`, `itemType`,
`difficulty` (1–3), `prompt`. La v5 réutilise les champs que le client connaît déjà
(`options`, `matches`, marqueurs `____` de `answer_grading.dart`). Elle ajoute les types
manquants et des contraintes par type, sans nouveau champ côté client.

| `itemType` | Charge publique |
|---|---|
| `mcq`, `scenario`, `spotTheIssue` | `options[{id,label}]`, 2–8 |
| `multi` | `options[{id,label}]`, 3–8 |
| `ordering`, `applied` | `options[{id,label}]`, 2–8, publiés triés par `id` : l'ordre publié ne révèle pas la solution |
| `cloze` | `prompt` avec N marqueurs `____` (4 soulignés ou plus, N de 1 à 6), `options[{id,label}]` = banque de mots, au moins N |
| `matchPairs` | `options[{id,label}]` (colonne gauche) et `matches[{id,label}]` (colonne droite), même cardinal 2–8, publiés triés par `id` |

Aucune charge publique ne porte `correct*`, `answerKey`, `rationale`, `solution`,
`explanation` ni `pairs`. C'est vérifié récursivement, comme en v4.

### 3. Corrigé privé v5 — `correctOptionIds` avec une sémantique par type

| `itemType` | `correctOptionIds` |
|---|---|
| `mcq`, `scenario`, `spotTheIssue` | exactement 1 id d'option (ensemble) |
| `multi` | au moins 2 ids d'options (ensemble) |
| `ordering`, `applied` | permutation de tous les ids d'options (séquence) |
| `cloze` | N ids d'options, un par marqueur, dans l'ordre des marqueurs (séquence) |
| `matchPairs` | un jeton `"<leftId>:<rightId>"` par id de `options`, bijection vers `matches` (ensemble) |

Le validateur contrôle ces contraintes par type. `rationale` reste commun.

### 4. Soumission compatible et correction serveur autoritaire

Le contrat de soumission ne change pas : `selected: string[]`, déjà produit ainsi par le
client (`gradeSelection`, `matchToken`).

| Type | Contenu de `selected` | Règle serveur |
|---|---|---|
| `mcq`, `multi`, `scenario`, `spotTheIssue` | ids d'options | égalité d'ensembles |
| `ordering`, `applied` | ids dans l'ordre choisi | égalité de séquences |
| `cloze` | ids d'options, dans l'ordre des marqueurs | égalité de séquences |
| `matchPairs` | jetons `"<leftId>:<rightId>"` | égalité d'ensembles |

La règle serveur devient une fonction de domaine unique, partagée par `QuizService` et
`ExamService` qui la dupliquent aujourd'hui. Elle est testée contre des vecteurs communs
avec `answer_grading.dart`, pour garantir la parité exigée par AGENTS.md.

### 5. Rendu

Chaque type garde un renderer Prism dédié. Un `itemType` inconnu affiche un fallback
explicite, qui annonce que l'exercice n'est pas pris en charge par cette version de
l'app, au lieu d'être rendu comme un QCM. Chaque type reçoit un golden gaté en CI, avec
un comparateur à tolérance mesurée (méthode de `manager_portal_test.dart`).

### 6. Séquence

Elle suit `docs/GOVERNANCE.md` :

1. **certigo-content — expand** : schémas canoniques v5, validateur et packager qui
   acceptent v4 et v5.
2. **Certigo — expand** : schémas embarqués v5, modèles C# et Dart, projection,
   correction par type, renderers et fallback, tests anti-fuite et goldens par type.
   Déploiement dev puis staging, avant toute release v5.
3. **certigo-content — migrate** : corpus migré type par type, sans perte.
4. **contract** : retrait de v4 quand plus aucune release active ne le porte.

## Décisions à valider

- **Q1** : noms sur le fil inchangés (§1).
- **Q2** : correction serveur sensible à l'ordre pour `ordering`, `cloze` et `applied`
  (§4). C'est un changement de notation (« Ask first ») : une réponse dans le mauvais
  ordre, acceptée aujourd'hui, sera refusée.
- **Q3** : répartition cross-repo (§6) entre la session Contenu (étapes 1 et 3) et
  Certigo (étape 2).

## Conséquences

- Les sept types de l'issue deviennent publiables en release runtime, avec une
  correction autoritaire propre à chaque type.
- La parité client/serveur est rétablie pour les types ordonnés.
- Rollback : v4 reste lue derrière la compatibilité de schéma. Aucune release v5 n'est
  promue avant validation staging.

## Alternatives écartées

- **Renommer les types** : migration cassante, sans gain.
- **Nouveaux champs par type** (`items`, `blanks`, `left`/`right`, `correctOrder`,
  `pairs`) : plus lisible, mais il faudrait migrer client, corpus et tentatives. La
  réutilisation de `options`, `matches` et `correctOptionIds` avec une sémantique
  **déclarée par type** donne la même garantie sans rien casser.
- **Garder `correctOptionIds` sans sémantique par type** (v4) : c'est la cause du tri
  serveur qui accepte un mauvais ordre.
- **Un fichier de schéma par type** : plus de fichiers à épingler, pour la même
  garantie qu'une union discriminée dans un seul schéma.
