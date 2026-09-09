# Gouvernance du dépôt — Certigo

> Lot de migration : **wp-p0-07-github-branch-protection-release** (Phase 0 — Stabilisation P0).
> Ce document décrit la gouvernance du dépôt : **protection de la branche `main`**,
> **propriété du code (CODEOWNERS)** et **interdiction de push direct**.
> La procédure de **release** est documentée séparément dans [`RELEASE.md`](./RELEASE.md).

---

## 1. Protection de la branche `main` — état ACTUEL appliqué

La branche `main` est **déjà protégée** (protection « classique », pas de *ruleset*).
Valeurs constatées en lecture via `gh api repos/gchambaud_microsoft/Certigo/branches/main/protection` :

| Réglage | Valeur appliquée | DoD |
| --- | --- | --- |
| Revues de PR requises | ✅ oui | **DoD : revues obligatoires** |
| Nombre d'approbations requises | `1` | ✅ |
| `dismiss_stale_reviews` (annuler les revues périmées) | `true` | ✅ |
| `require_code_owner_reviews` (revue d'un code owner) | `false` | ⚠️ durcissement possible |
| `require_last_push_approval` | `false` | — |
| Checks de statut requis | ✅ oui, `strict = true` | **DoD : checks requis** |
| Contextes requis constatés avant réconciliation | `Build & test`, `Flutter app + UI packages` | ⚠️ réconcilier les sept gates cibles |
| Contextes cibles supplémentaires | `Generated state equals committed state`, `Validate workflow YAML`, `CodeQL / Security gate`, `Security / Required gate`, `Fork PR policy / Required gate` | Vérifiés sur chaque PR |
| `allow_force_pushes` (push forcé) | `false` | **DoD : push direct interdit** |
| `allow_deletions` (suppression de branche) | `false` | ✅ |
| `enforce_admins` (appliquer aux admins) | `false` | ⚠️ durcissement possible |
| `required_conversation_resolution` | `false` | ⚠️ durcissement possible |
| `required_linear_history` | `false` | ◽ optionnel |
| `required_signatures` | `false` | ◽ optionnel |
| `lock_branch` | `false` | — |
| `block_creations` | `false` | — |

**Origine des contextes de check** (jobs GitHub Actions) :

| Contexte requis | Workflow | Job |
| --- | --- | --- |
| `Build & test` | [`.github/workflows/ci-backend.yml`](../.github/workflows/ci-backend.yml) | `Build & test` |
| `Flutter app + UI packages` | [`.github/workflows/ci-mobile.yml`](../.github/workflows/ci-mobile.yml) | `Flutter app + UI packages` |
| `Generated state equals committed state` | [`.github/workflows/ci-project-state.yml`](../.github/workflows/ci-project-state.yml) | `Generated state equals committed state` |
| `Validate workflow YAML` | [`.github/workflows/lint-workflows.yml`](../.github/workflows/lint-workflows.yml) | `Validate workflow YAML` |
| `CodeQL / Security gate` | [`.github/workflows/codeql.yml`](../.github/workflows/codeql.yml) | `CodeQL / Security gate` |

> ℹ️ **Portée de `Validate workflow YAML` : large sur les PR, nulle sans PR.**
>
> Cette gate lint **tous** les workflows à chaque PR vers `main` — pas seulement ceux modifiés : son
> déclencheur n'a aucun filtre `paths` et le script passe `.github/workflows/*.yml` en bloc à
> `actionlint`. Un fichier que personne n'édite, y compris un workflow **désactivé**, est donc revérifié
> à chaque PR.
>
> En revanche, **un simple push de branche sans PR ouverte n'est pas linté du tout.** C'est inhérent à
> une gate déclenchée par PR, pas un défaut : rien ne s'exécute tant qu'aucune PR n'existe. Un workflow
> invalide poussé sur une branche ne se manifeste que par des runs en échec nommés d'après le *chemin
> du fichier* (`.github/workflows/<nom>.yml`, `jobs=0`) — la signature d'un fichier que GitHub n'a pas
> pu parser. Constaté le 2026-09-05 : six workflows cassés poussés sur une branche, cinq runs de ce
> type, et aucune gate franchie puisqu'aucune PR n'existait encore.
>
> **Pré-contrôle local**, avec la version que la CI épingle déjà :
>
> ```bash
> actionlint .github/workflows/*.yml   # v1.7.12, cf. lint-workflows.yml
> ```
>
> `actionlint` connaît les règles de **disponibilité des contextes** — il rejette par exemple
> `runner.*` dans un `env:` de job — ce qu'aucun parseur YAML ne peut voir.
| `Security / Required gate` | [`.github/workflows/security-gate.yml`](../.github/workflows/security-gate.yml) | `Security / Required gate` |
| `Fork PR policy / Required gate` | [`.github/workflows/fork-pr-policy.yml`](../.github/workflows/fork-pr-policy.yml) | `Fork PR policy / Required gate` |

Le gate CodeQL ne se contente pas du statut d'exécution de l'analyse. Chaque langue produit un
SARIF évalué localement : les sévérités de sécurité `high`/`critical` (score >= 7.0) et les
résultats SARIF de niveau `error` sans score bloquent le job. L'action CodeQL transmet le SARIF
au service Code Scanning natif ; indépendamment, le contrôleur local journalise des findings
assainis et publie une synthèse dans `GITHUB_STEP_SUMMARY`. Aucun artefact Actions n'est créé.
Sur les PR internes, les sources analysées sont isolées sous `.untrusted-source` ; scripts
d'enforcement et configurations scanner proviennent exclusivement du SHA immuable de base sous
`.trusted-control`. Chaque scanner réutilisable exige aussi l'environnement `pr-ci`, avant toute
évaluation ou restauration pouvant interpréter les fichiers de la PR.
Les jobs Azure OSV et Checkov écrivent leurs diagnostics et résultats structurés non
secrets dans les logs immutables du job et une synthèse dans `GITHUB_STEP_SUMMARY`. Leur
conclusion dépend uniquement du statut scanner, des findings et de la validité de la sortie,
jamais du quota de stockage d'artefacts. Les forks ne sont pas supportés : la gate de confiance
chargée depuis `main` échoue sans checkout, tandis qu'aucun workflow contrôlé par le fork ne peut
atteindre le pool Azure persistant.
OSV reçoit explicitement chaque lockfile issu de l'inventaire validé : aucun `.gitignore` fourni
par la PR ne peut masquer un
manifeste ou lockfile, et toute modification d'un `.gitignore` déclenche le scan de dépendances.
Le contrôleur trusted-base calcule d'abord l'inventaire Git attendu et rejette le rapport OSV si
une seule source verrouillée non vide suivie manque dans `results[].source.path`. Un lock NuGet
sans aucun package est identifié comme vide seulement après validation statique complète, car OSV
ne produit pas de résultat JSON pour cette source bien qu'il l'ait parcourue.
Chaque `.csproj` suivi sous `backend/` doit avoir exactement un `packages.lock.json` adjacent.
Le validateur statique trusted-base refuse les locks absents, orphelins ou malformés, les graphes
incomplets et tout écart entre un `PackageReference` direct à version exacte et son entrée
`Direct` demandée/résolue. Il rejette aussi les imports/SDK/conditions/versions indirectes non
modélisés et exige que chaque `contentHash` soit un SHA-512 base64 de 64 octets.
Après une modification de package, un mainteneur régénère les locks dans un environnement de
développement de confiance avec
`dotnet restore backend/Certigo.sln --use-lock-file --force-evaluate`, n'ajoute que les huit
`packages.lock.json` adjacents aux projets (jamais `obj/**/WorkerExtensions/**`), puis exécute
`python tools/validate_nuget_locks.py --root .` avant de commiter.
La gate exécute ensuite un `dotnet restore backend/Certigo.sln --locked-mode` sans secret, depuis
un SDK installé dans un chemin absolu isolé. Ce restore peut évaluer les projets de PR : il est
donc le dernier traitement de code non fiable de son job, ne précède aucun job secret/trusted,
et ses sources ainsi que son SDK sont supprimés avec des chemins de cleanup réinjectés au niveau
de l'étape. Le risque résiduel propre au runner persistant reste contenu par cette absence de
secrets et par le nettoyage ; la décision statique trusted-base demeure indépendante de MSBuild.
Les builds CI et le déploiement backend restaurent aussi en `--locked-mode`, afin qu'une
dépendance importée ou un lock tronqué ne puisse ni être fusionné ni produire l'artefact publié.

Le même inventaire exige exactement un `package-lock.json` adjacent à chaque `package.json` et un
`pubspec.lock` adjacent à chaque `pubspec.yaml`, hors répertoires générés et exemples ; manifestes
et locks symboliques sont interdits. Le lock npm v3 doit reproduire les dépendances racine du
manifest, tandis que les locks pub doivent conserver leur structure générée `packages`/`sdks`.
La validation statique exporte en JSON la liste triée de tous les `pubspec.yaml` inclus. Sur
`certigo-pr` uniquement, la gate télécharge Flutter dans un répertoire neuf, vérifie le SHA-256
figé de l'archive avant toute exécution, puis lance `flutter pub get --enforce-lockfile` pour
chaque entrée avec un `PUB_CACHE` temporaire isolé. Elle exige ensuite des locks identiques octet
par octet, un `git diff` vide et un checkout trusted-base inchangé avant OSV, puis supprime SDK,
cache et source de restauration.
La CI utilise exclusivement `npm ci` et `dart/flutter pub get --enforce-lockfile`. Toute
régénération npm/pub s'effectue seulement dans un environnement de développement de confiance,
puis `python tools/validate_dependency_locks.py --root .` doit réussir avant commit.

Les releases Android/iOS et toute autre exécution `certigo-trusted` interdisent les actions de
cache ainsi que toute entrée `cache`/`pub-cache` autre que le booléen littéral `false`. Les
workflows mobiles téléchargent Flutter dans un répertoire neuf, vérifient le SHA-256 figé de
l'archive, utilisent un `PUB_CACHE` propre au run et suppriment ces deux répertoires en fin de job.
Une PR exécutée via `pull_request_target` sur `certigo-pr` ne peut donc alimenter ni SDK ni cache
ensuite restauré par une opération de signature ou de publication.

La gate `Generated state equals committed state` n'accède à aucun dépôt externe et ne reçoit
aucun secret. Son contrôle source rapide exécute d'abord
`python tools/generated_contracts.py --check`. Les contrats canoniques
`contracts/content-package-v2.json` et `contracts/cosmos-containers.json` pilotent respectivement
le contrat de package intégré à `docs/active-content-reference.json` et la topologie partagée par
Bicep et `CosmosContainers.cs`. Le générateur du SHA immuable valide ensuite la référence locale
(SHA de révision complet, identifiants et SHA-256 des manifestes), puis vérifie que l'état généré
de la PR est commité.
La fraîcheur de `certigo-content/main` relève de la CI et de la protection de ce dépôt, pas d'un
checkout cross-repository sur un runner PR persistant. Le workflow séparé `ci-content-drift.yml`
surveille néanmoins le pin sans affaiblir cette règle : il ne tourne **jamais** sur PR (seulement
`push` sur `main` et planification), reste sur `certigo-trusted`, ne checkout pas `certigo-content`
et compare le pin à la *release publiée* dans le stockage immuable. Il échoue explicitement tant
que cette source n'existe pas, plutôt que de se désactiver silencieusement. Sa moitié sans
credential — `tools/check_active_content_age.py` — vérifie dès aujourd'hui que le bump manuel a
bien été rejoué récemment ; elle ne prouve pas l'absence de dérive amont, seulement que la
procédure n'a pas été oubliée.

Le bump de contenu actif est donc volontairement manuel et vérifié : après fusion protégée dans
`certigo-content`, un mainteneur checkout le SHA exact, exécute `npm ci --ignore-scripts` puis
`npm run package`, reporte la révision, l'horodatage et les deux manifestes dans
`docs/active-content-reference.json`, puis lance
`python tools/generated_contracts.py --refresh`,
`python tools/project_state.py --validate-active-content <checkout-certigo-content>` et
`python tools/project_state.py --refresh-reference`. La PR du bump doit commiter la référence et
l'état projet régénéré.

### Faire évoluer le contrat de package : expand / migrate / contract

> **D'abord, une seule question : changez-vous la *forme* du contrat, ou seulement les *données*
> qu'il décrit ?**
>
> | Votre changement | Procédure |
> |---|---|
> | **Données seules** — rafraîchir le pin : révision, horodatage, `manifestId`, `fileCount`, `fileSha256` | **Une seule PR**, la procédure de bump ci-dessus. Rien de spécial. |
> | **Forme du contrat** — schéma du manifeste, champs d'entrée, préfixes ou profondeurs de chemins, enveloppe du fichier de contrat | **Trois PR**, la séquence ci-dessous. Un basculement atomique est impossible. |
>
> Le rafraîchissement périodique du pin appartient à la **première** ligne. Ne payez pas le coût
> de trois PR pour un bump de contenu ordinaire.

**Règle générale qui explique les deux cas.** La contrainte de la gate se traverse dans les deux
sens **à condition de ne jamais changer le code et les données dans la même PR**. Le validateur de
la base juge les données du candidat : si les données ne bougent pas, le code peut bouger ; si le
code ne bouge pas, les données peuvent bouger — pourvu que le code déjà sur `main` les accepte.

**Symptôme.** Une PR qui modifie `contracts/content-package-*.json` ou
`docs/active-content-reference.json` échoue sur `Validate project-state source` et
`Generated state equals committed state` avec l'un de ces messages :

```
docs/active-content-reference.json.packageContract: contract does not match certigo.content.package-manifest/v1.
contracts/content-package-v1.json: unexpected fields.
contracts/content-package-v1.json: cannot load canonical JSON: [Errno 2] No such file or directory
generated contracts are stale: docs/active-content-reference.json.
```

**Ce n'est pas une donnée malformée, et un rebase n'y change rien.** `ci-project-state.yml`
exécute délibérément le validateur *de la branche de base* contre les *données de la PR*
(`working-directory: .trusted-control`, `--root "$PROJECT_WORKSPACE"` pointant sur
`.untrusted-source`). C'est une propriété de sécurité voulue : une PR ne peut pas réécrire le
validateur qui la juge. La conséquence est que le validateur et les données qu'il valide sont
versionnés ensemble, donc **toute évolution du contrat est jugée par le validateur d'avant
l'évolution**. Le message ci-dessus attribue les données du candidat au schéma de la base : il
signifie « le juge est périmé », pas « tes données sont invalides ».

**Conséquence pratique : un basculement atomique est impossible.** Il faut trois PR :

1. **expand** — code seul. Le validateur apprend à accepter l'ancienne *et* la nouvelle forme.
   Ne toucher ni `docs/active-content-reference.json` ni le fichier de contrat existant, afin
   que la base (qui ne connaît que l'ancienne forme) voie des données inchangées.
2. **migrate** — données seules. Basculer la référence sur la nouvelle forme. `main` porte
   désormais le code bi-compatible et l'accepte.
3. **contract** — code seul à nouveau : retirer l'ancienne forme. La base porte déjà la nouvelle
   et voit des données inchangées, d'où le passage. L'état final redevient strict et
   mono-schéma.

La bi-compatibilité de l'étape 1 est un **échafaudage transitoire, pas la cible** : un validateur
qui accepte à la fois la forme courante et la forme supersédée ne peut pas détecter une
régression de l'une vers l'autre. L'étape 3 n'est pas optionnelle.

Chaque forme reste validée **séparément et strictement** : les règles d'entrées et de chemins sont
déclarées par schéma dans `manifestShapes`, jamais fusionnées en une union permissive.

> **Migration v1 → v3 : terminée le 2026-09-05** (PR #379 *expand*, #382 *migrate*, puis
> l'étape *contract*). `contracts/content-package-v2.json` ne déclare plus qu'une seule forme,
> `certigo.content.package-manifest/v3`, et un manifeste v1 est désormais **rejeté**. Les
> messages d'erreur cités plus haut mentionnent des fichiers qui n'existent plus : ils sont
> conservés tels quels parce que c'est le texte que l'on rencontre encore sur une branche
> antérieure à la migration, et qu'il doit rester trouvable par recherche.
>
> Cette procédure resservira : l'essentiel du corpus amont porte `provenance.checkedOn`
> 2026-08-17 et arrive à échéance en bloc à la mi-septembre 2026. **Ce rafraîchissement-là est un
> changement de données seules : une PR, pas trois.**

### Workflow privilégié : ni ajout, ni modification — la règle est scellée

> **Avant de concevoir quoi que ce soit : un workflow qui parle à Azure ne peut plus être ajouté
> ni modifié dans ce dépôt, et cette contrainte ne peut être levée par aucune PR.** Mesuré le
> 2026-09-08 sur `main` = `9c438660`. **Invalidé si** `backend-deploy-workflow-policy.mjs`
> disparaît de `backendDeployTrustedFiles`, si `Validate workflow YAML` cesse d'être un contexte
> requis, ou si `enforce_admins` repasse à `false`.

**Symptôme.** Une PR qui ajoute un workflow, ou qui modifie d'une seule ligne l'un des cinq
workflows utilisant `azure/login@`, échoue sur `Validate workflow YAML` avec :

```
.github/workflows/<nom>.yml: changed or new privileged capability is forbidden outside cd-backend.yml
```

Un commentaire suffit à le déclencher : la comparaison porte sur les **octets** du fichier, pas
sur les capacités qu'il ajoute. Les cinq workflows concernés — `ci-content-drift.yml`,
`content-infra-apply.yml`, `content-infra-what-if.yml`,
`governance-bootstrap-phase-a-what-if.yml`, `governance-bootstrap-phase-b-what-if.yml` — sont
donc figés à l'octet.

**Ce qui déclenche.** `privilegedWorkflow` dans
`.github/scripts/backend-deploy-workflow-policy.mjs` signale un workflow dès qu'il porte une
permission `write` ou `write-all`, un `id-token: write`, un `environment:`, un `secrets:` de job,
ou l'un de dix-sept marqueurs textuels (`azure/login@`, `secrets.`, `az deployment`,
`management.azure.com`, …). L'unique exemption est le nom de fichier `cd-backend.yml`, en dur.

**La règle ne peut pas être amendée.** `validateBackendDeployWorkspace` exige que trois fichiers
soient **byte-identiques entre la PR et sa révision de base** :

```
.github/scripts/backend-deploy-workflow-policy.mjs
.github/scripts/backend-deploy-gate.test.mjs
.github/scripts/validate-backend-deploy-dispatch.mjs
```

Toute modification, fût-elle d'un commentaire, produit :

```
candidate trusted control: <chemin> must match the immutable base revision
```

Ajouter une liste d'exemptions, exempter un workflow nommément, ou remplacer la comparaison
d'octets par une comparaison de capacités exigent tous d'éditer ces fichiers. **Aucune PR ne le
peut.** Et il n'existe pas de contournement : `Validate workflow YAML` est un contexte requis sur
`main`, `enforce_admins` vaut `true`, `allow_force_pushes` vaut `false`.

**Comment le scellé a pu être posé.** `validate-workflow-security.mjs` importe la politique et
l'appelle sans condition. Lorsque la PR #357 l'a introduite, la révision de base ne contenait pas
le module : le validateur de la base n'a donc jamais appliqué la règle à la PR qui l'apportait.

> **Une PR n'est jamais soumise à la règle qu'elle introduit.** C'est la même propriété que celle
> décrite plus haut pour le contrat de package — le validateur de la base juge les données du
> candidat — mais elle a ici un effet à sens unique : #357 a pu poser un scellé qu'elle-même ne
> pourrait plus poser aujourd'hui, et que personne ne peut retirer.

**Le scellé n'est pas le défaut.** Son intention est déclarée par son propre test
(`backend-deploy-gate.test.mjs`, `workspace rejects a symlink trust root and privileged shadow
workflows`), qui construit le cas visé en copiant `cd-backend.yml` vers `cd-backend-shadow.yml` :
empêcher qu'un workflow fantôme contourne les scellés du pipeline de déploiement. Sceller la garde
contre son propre désarmement est cohérent avec ce but. **C'est la règle scellée qui est plus large
que son intention — et le scellé est précisément ce qui interdit de la resserrer.**

**Ce qui reste possible.** Un workflow qui n'utilise que le jeton GitHub automatique ne déclenche
aucun des marqueurs : ni `github.token`, ni `permissions: contents: read` n'y figurent. Mesuré le
2026-09-08 en écrivant deux workflows neufs dans le même répertoire et la même seconde — celui qui
ne lit que l'API GitHub n'est pas signalé, celui qui porte `azure/login@` l'est. La surveillance
qui ne demande que des données GitHub (vivacité des runners, états de jobs) est donc constructible ;
celle qui exige une lecture Azure ne l'est pas.

### Un test ajouté sous `.github/scripts/` ne s'exécute jamais sur sa propre PR

**Symptôme.** Il n'y en a aucun. C'est tout le problème : la PR qui introduit le test passe au
vert sans que le test ait tourné une seule fois. La panne se déclare **après la fusion**, sur les
PR de tout le monde — et l'auteur, lui, n'a rien vu.

**Mécanisme.** `lint-workflows.yml` monte deux checkouts : `.untrusted-source` (le head de la PR)
et `.trusted-control` (la **base**, donc `main`). L'étape `Test workflow security scripts`
s'exécute avec `working-directory: .trusted-control` :

```yaml
- name: Test workflow security scripts
  working-directory: .trusted-control
  run: node --test .github/scripts/*.test.mjs
```

Le glob est donc résolu **dans l'arbre de `main`**. Un fichier de test qui n'existe que dans la
branche n'est pas ramassé, et le validateur exécuté est celui de `main`, pas celui de la PR.

**Pourquoi on ne le corrige pas.** C'est la même frontière de sécurité que pour la gate d'état
projet : une PR ne doit jamais faire exécuter son propre code par la CI de confiance. Basculer
cette étape sur `.untrusted-source` supprimerait l'angle mort en rouvrant une faille bien pire —
n'importe quelle PR pourrait alors réécrire le juge qui la juge. **L'angle mort est inhérent au
choix, pas un défaut d'implémentation : seule une procédure peut le combler.**

**La conséquence est asymétrique**, et c'est ce qui la rend coûteuse. Un test faux ou un pin
périmé ne casse pas la PR qui l'introduit ; il casse `main`, donc le vert de toutes les autres
PR, après coup. Le coût est payé par ceux qui n'ont rien écrit.

**Procédure — exécuter la suite contre le head *fusionné*, à la main, avant de fusionner.**

```bash
gh pr update-branch <n>          # ou `git merge origin/main` dans la branche
node --test .github/scripts/*.test.mjs
```

Le head fusionné est le seul arbre qui porte à la fois le code de `main` et celui de la branche :
c'est exactement l'état que `main` aura après la fusion, et le seul endroit où la combinaison peut
être observée avant qu'elle ne devienne le problème de tout le monde. Reporter le compte de tests
dans le corps de la PR.

**Sur la version épinglée, et dans l'environnement du runner.** `lint-workflows.yml` épingle
`node-version` à une version précise ; un poste de développement en porte presque toujours une
plus récente, et n'exporte pas `GITHUB_OUTPUT`. Ces deux écarts suffisent à eux seuls à rendre une
suite verte hors CI et rouge en CI. Le correctif #413 en donne la mesure croisée — quatre
combinaisons, un seul et même arbre :

```
Node 24, sans GITHUB_OUTPUT   0 échec                    <- poste de développement
Node 24, avec GITHUB_OUTPUT   test 11 échoue
Node 20, sans GITHUB_OUTPUT   test 3 échoue
Node 20, avec GITHUB_OUTPUT   tests 3 et 11 échouent     <- le runner
```

**La seule ligne qui compte est la dernière, et c'est la seule qu'un poste ne produit jamais
spontanément.** Lancer la suite sur la version du poste vérifie un environnement que la CI
n'exécutera pas : le vert obtenu est réel, mais il ne répond pas à la question posée. La procédure
ci-dessus n'a donc de valeur que si `node --version` affiche la version épinglée par
`lint-workflows.yml` et si `GITHUB_OUTPUT` est positionné comme sur le runner.

> **Deux précédents, tous deux mesurés, tous deux auraient cassé `main`.** #327 posait un
> manifeste sémantique périmé — son head non modifié échouait sur une vingtaine d'écarts,
> invisibles à la CI. #357 introduisait `backend-deploy-workflow-policy.mjs` avec un pin d'octets
> sur `cd-backend.yml` désaccordé du fichier réel : plus de cent erreurs, toutes issues de la même
> cause. Témoin qui exclut une autre explication : `main` seule ne produisait aucun échec, et
> `main` + #357 seule en produisait un. Les deux ont été corrigées avant fusion parce que la suite
> avait été lancée à la main sur le head fusionné.

> **Et le précédent où la procédure n'a pas été appliquée — celui-là a cassé `main`.** Le train
> #407 (*merge #328, #357 and #369 as one CI train*) a fusionné le 2026-09-08 à 11 h 51 UTC en
> emportant `backend-deploy-gate.test.mjs`, apporté par #357. Deux défauts indépendants y
> dormaient : une *aide d'itérateur* — `Map.prototype.keys().map()`, disponible à partir de
> Node 22 seulement — dans un workflow épinglé à Node 20.20.2 ; et un processus enfant qui
> héritait `GITHUB_OUTPUT` du runner, si bien que la sortie attendue partait dans le fichier au
> lieu de `stdout`. **Aucun des deux n'était observable sur la PR qui les introduisait**, pour la
> raison exposée en tête de section. À partir de cette fusion, toute PR dont la base était ce
> `main` échouait sur `Validate workflow YAML` — un contexte requis : **le dépôt entier devenait
> infusionnable.** Le correctif #413 a fusionné à 12 h 47 UTC, soit 56 minutes plus tard.

**Deux corollaires pour lire les sorties.**

- Le volume d'une sortie d'erreur est un artefact de propagation, jamais une mesure du nombre de
  causes. Cent erreurs peuvent n'en avoir qu'une seule.
- Un échec isolé n'est pas une régression tant qu'il n'a pas été rejoué.
  `deploy-flex-onedeploy.test.mjs` échoue par intermittence sous charge et passe au rejeu :
  rejouer avant de conclure, et ne jamais attribuer à sa propre modification un échec qu'on n'a
  pas su reproduire.

### Un vert peut décrire une base qui n'existe plus

> **Un contrôle vert atteste d'un couple (head, base) mesuré à l'instant du run — jamais de l'état
> présent de `main`.** Mesuré le 2026-09-08. **Invalidé si** `strict` repasse à `false` dans la
> protection de `main`.

**Symptôme.** Une PR affiche des contrôles entièrement verts et refuse pourtant de fusionner ; ou,
bien plus coûteux, on se fie à ce vert.

**Mécanisme.** La protection de `main` porte `strict: true` : une branche doit être à jour avec
`main` pour être fusionnable. Un vert acquis avant que `main` n'avance décrit donc une base
révolue, et **la seule action qui rend la PR fusionnable — mettre la branche à jour — est aussi
celle qui rejoue les contrôles contre la nouvelle base.** Aucune manœuvre ne conserve le vert *et*
rend la PR fusionnable : un vert périmé n'est pas rattrapable, il est seulement remplaçable.

**Le cas dégénéré, mesuré.** Pendant les 56 minutes où `main` portait la suite cassée décrite par
la section « Un test ajouté sous `.github/scripts/` ne s'exécute jamais sur sa propre PR », 14 PR
étaient ouvertes et **9 affichaient un vert complet** — non parce qu'elles étaient saines, mais
parce qu'elles n'avaient pas encore été rejouées contre cette base. Leur vert était exact et sans
valeur. Mettre l'une d'elles à jour la faisait rougir aussitôt, **sans qu'une seule ligne de la
branche ait changé.** L'ensemble des PR vertes et l'ensemble des PR fusionnables étaient alors
disjoints, et la couleur affichée mesurait exactement une chose : l'absence de contact avec le
problème.

**Pourquoi cela ne se lit pas dans les workflows.** Aucun fichier de `.github/workflows/` ne porte
l'information. Le discriminant est la comparaison entre la base **enregistrée** d'une PR et la tête
courante de `main` — deux valeurs qui ne figurent ensemble sur aucune page de PR :

```bash
gh api repos/<owner>/<repo>/pulls/<n> --jq .base.sha   # base à laquelle la PR a été mesurée
git rev-parse origin/main                              # tête courante
```

Si les deux diffèrent, les contrôles affichés décrivent un `main` révolu, quelle que soit leur
couleur. **C'est le régime ordinaire, pas l'exception** : relevé le 2026-09-08 à 14 h UTC, les
9 PR ouvertes du dépôt portaient **toutes** une base distincte de la tête de `main`.

**Conséquence pratique — armer l'auto-fusion plutôt que courir après le vert.** Sous
`strict: true`, résoudre un conflit puis attendre le vert à la main est une course perdue dès que
le dépôt est actif : chaque fusion sur `main` périme la résolution avant la fin du cycle de
contrôles, et un pool de runners réduit allonge ce cycle. Armer `gh pr merge <n> --auto --squash`
retire l'exigence d'être présent à l'instant précis où les conditions s'alignent.

### Snapshot d'état projet périmé : la branche, ou `main` ?

**Symptôme.** Une PR échoue sur `Validate project-state source` et `Generated state equals
committed state` avec :

```
project-state: Observable sources differ from the captured source snapshot
sha256:<attendu> (current sha256:<obtenu>). Commit the source changes, then run
`python tools/project_state.py --refresh-reference`.
```

> ⚠️ **Ces deux checks portent le même nom que ceux de la section précédente, mais la cause est
> différente.** C'est la source de confusion la plus fréquente sur cette gate : `expand / migrate /
> contract` concerne le *validateur de base jugeant les données de la PR* ; la présente section
> concerne le *contenu de la branche elle-même*. Le message d'erreur les distingue —
> « Observable sources differ » désigne toujours le second cas.
>
> 🔎 **Limitation connue de l'outillage.** L'information discriminante n'existe **que dans le texte
> du log**. Le *nom* du check est identique dans les deux cas, et c'est lui qui s'affiche partout où
> l'on regarde par défaut : page de PR, résumé de run, notifications, messages entre équipes. Un
> lecteur qui se fie au résumé ne peut pas distinguer les deux causes — il ne lui manque pas
> seulement du détail, il reçoit une information **activement trompeuse**, puisqu'un nom identique
> suggère une cause identique.
>
> *Piste pour qui reprendra cet outillage* (hors périmètre ici) : faire émettre aux deux causes des
> noms de check distincts, ou à défaut une première ligne discriminante en tête de log. Tant que le
> nom du check sert de proxy pour la panne, il ne peut pas distinguer ce qu'il représente.

**Ce n'est presque jamais « `main` a bougé », et un rebase seul ne corrige rien.** `OBSERVABLE_PATHS`
(`tools/project_state.py`) hache le **contenu** d'une liste de chemins. Dès que la branche modifie
l'un d'eux, l'empreinte change et le snapshot committé devient faux — **indépendamment de toute
avance de `main`**. Modifier un fichier existant suffit : il n'est pas nécessaire d'en ajouter ou
d'en supprimer un.

Chemins observables (source de vérité : `tools/project_state.py`) :

```
.github/workflows                                     docs/active-content-reference.json
codemagic.yaml                                        tools/project_state.py
README.md                                             tools/tests
package.json                                          backend/tests
content                                               apps/mobile/test
backend/src/Certigo.Domain/Content/ContentModels.cs   apps/mobile/integration_test
                                                      packages/*/test/**
```

> 📌 `backend/tests`, `apps/mobile/test` et `packages/*/test/**` en font partie : **toute PR qui
> ajoute un test déclenche ce cas**, tout comme une PR qui ne modifie que `README.md` ou
> `package.json`. C'est le fonctionnement voulu, pas un défaut.

**Diagnostic — une seule commande, sans rebase**, sur une branche à jour avec `main` :

```bash
python tools/project_state.py --check
```

| Résultat | Cause | Correction |
|---|---|---|
| **Échoue en local** | Le contenu **de la branche** — un chemin observable a été modifié. | `--refresh-reference`. **Aucun rebase nécessaire.** |
| **Passe en local, échoue en CI** | `main` a réellement avancé sur un chemin observable. | Rebase, **puis** `--refresh-reference`. |

**Correction.** Committer d'abord les sources observables (l'outil refuse de tourner sur un arbre
sale), puis :

```bash
python tools/project_state.py --refresh-reference   # met à jour la référence ET le document
python tools/project_state.py --check               # doit répondre « Project state is current. »
```

Committer `docs/project-state-reference.json` et `docs/ETAT_DU_PROJET.md` **séparément** des sources
observables : ni l'un ni l'autre n'est observable, donc ce commit ne réinvalide pas l'empreinte —
c'est ce qui évite l'auto-référence. Après un rebase, régénérer **après** le rebase, jamais avant,
pour que le snapshot reflète l'arbre final.

> 🕳️ **Piège après un rebase : `--check` peut passer alors que le champ `commit` est périmé.**
>
> Un rebase réécrit les commits : l'ancien SHA capturé devient **orphelin**, irrésolvable dans
> l'historique de la branche. Or `--check` ne compare **que** `observableSha256`, qui est stable au
> rebase par conception (il hache le *contenu*, pas l'historique — cf. le champ `semantics` de la
> référence). **La gate ne signalera donc jamais ce décalage.**
>
> Le champ n'est pas seulement muet, il est **faux** : quiconque fait `git show <commit>` obtient une
> erreur, sans pouvoir distinguer « la référence est périmée » de « mon clone est incomplet ».
>
> ```bash
> # Après tout rebase, vérifier que le commit capturé appartient encore à l'historique :
> CAPTURED=$(jq -r .commit docs/project-state-reference.json)
> git merge-base --is-ancestor "$CAPTURED" HEAD \
>   && echo "commit capturé présent dans l'historique" \
>   || echo "ORPHELIN -> relancer --refresh-reference"
> ```
>
> ⚠️ **N'utilisez pas `git cat-file -e` pour ce test.** Il répond « existe » pour un commit orphelin,
> parce que le reflog local le maintient vivant plusieurs semaines : le test **passe sur la machine
> de l'auteur** et échoue sur un clone frais, où l'objet n'a jamais été transféré. C'est un faux
> positif qui ne se manifeste que chez les autres. Seul `merge-base --is-ancestor` teste
> l'appartenance à l'historique plutôt que la simple présence de l'objet.
>
> `--refresh-reference` le repointe. Le faire **systématiquement après un rebase**, même si
> `--check` est déjà vert : « la CI ne le vérifie pas » est une raison de le corriger à la main, pas
> de l'ignorer — un champ que rien ne contrôle est précisément un champ qui pourrit.
>
> 🔬 **Ce test vaut pour une branche, jamais pour `main`.** Mesuré le 2026-09-05 sur les douze
> derniers commits de `main` : le commit capturé y est **orphelin dans 12 cas sur 12**, sans
> exception. Ce n'est pas une anomalie, c'est mécanique — le dépôt fusionne en *squash*, donc le
> commit de branche que `--refresh-reference` a capturé cesse d'exister à l'instant de la fusion,
> remplacé par le commit de squash. Le champ `commit` de `docs/project-state-reference.json` n'a
> donc, sur `main`, **jamais** désigné un commit atteignable et ne le peut pas.
>
> Conséquences pratiques, à ne pas confondre :
>
> - **Rien n'est cassé.** `observableSha256` est le contrôle réel et il est stable au squash *par
>   conception* — le champ `semantics` de la référence le dit explicitement. La gate reste juste.
> - **Le champ `commit` est de la provenance, pas une garantie.** Sur `main` il indique « la
>   branche qui a produit ce relevé », dans une forme qui ne survit pas au squash.
> - **N'appliquez donc pas la commande ci-dessus à `main`** en concluant à un défaut : elle y
>   échouera toujours. Elle sert à vérifier *votre branche avant de pousser*, où un orphelin est
>   réellement de votre fait et réellement corrigeable.
>
> Le contrôle est correct ; c'est son domaine d'application qui devait être borné. Un contrôle
> dont on ignore le domaine produit un faux positif permanent, et un faux positif permanent finit
> par être ignoré — y compris le jour où il dit vrai.
>
> 🎯 **Corollaire : quand `--amend` est-il sûr ?** `--refresh-reference` capture *le dernier commit
> touchant un chemin observable*. Amender **ce commit-là** réécrit le SHA qu'on vient de capturer :
> c'est un **point fixe inatteignable par amendement**, chaque tentative de faire coïncider le
> relevé avec l'historique déplaçant l'historique.
>
> > **Amender est sûr si et seulement si le commit amendé n'est pas celui que la référence a
> > capturé.**
>
> Exemple : si la capture porte sur un commit *workflow* et que l'on amende un commit *docs*, la
> capture survit (`is-ancestor` reste vrai). Amender le commit workflow l'orpheline à tous les
> coups. Cette formulation remplace la consigne plus grossière « toujours commiter l'état projet
> séparément » : elle dit **où passe la frontière**, donc un lecteur peut déterminer de quel côté
> il se trouve, au lieu de suivre une interdiction qui paraît arbitraire et qu'il abandonnera à la
> première gêne.
>
> À noter sur la provenance de cette règle : le test `merge-base --is-ancestor` documenté ci-dessus
> **a pris son propre auteur en défaut**, quelques heures après avoir été écrit. C'est la seule
> preuve réelle qu'un contrôle fonctionne — toute autre confirmation revient à ce que l'auteur se
> donne raison à lui-même.

> ✅ **Vérifiez cette affirmation vous-même, en une commande.** Le présent fichier
> (`docs/GOVERNANCE.md`) n'est pas un chemin observable. Modifiez-le, puis lancez :
>
> ```bash
> python tools/project_state.py --check   # attendu : « Project state is current. »
> ```
>
> S'il passe alors que le fichier est modifié, c'est la preuve directe que `docs/` est hors
> périmètre observable. La même manipulation sur un fichier de `backend/tests` échouera. Ne croyez
> pas la liste ci-dessus sur parole : dix secondes suffisent à la tester.

### Conclusion DoD

Le **cœur de la DoD est SATISFAIT** : `main` exige une PR avec **≥ 1 revue**, des checks stricts et
interdit le push direct (`allow_force_pushes=false` + revue obligatoire ⇒ pas de `git push` direct
sur `main`). L'état cible versionné ajoute cinq gates aux deux contextes existants ; sa
réconciliation live doit utiliser uniquement le `PATCH` étroit du §4.

Restent des **gaps de durcissement** (facultatifs pour la DoD mais recommandés) traités
en **réserve admin** au §4.

---

## 2. Interdiction de push direct

Le push direct sur `main` est bloqué par la combinaison :

- **Revue de PR obligatoire** (`required_pull_request_reviews`, count = 1) ⇒ toute
  modification passe par une Pull Request approuvée ;
- **Checks stricts** (`strict = true`) ⇒ la branche doit être à jour et les checks verts ;
- **`allow_force_pushes = false`** et **`allow_deletions = false`** ⇒ pas de réécriture
  ni de suppression de l'historique de `main`.

> Pour un blocage total y compris pour les administrateurs, activer `enforce_admins = true`
> (voir §4, réserve admin).

### Fusionner une PR appartenant à une pile (*stack*)

Lorsqu'une PR est empilée sur une autre (base = branche d'une PR ouverte), **tous les
chemins de fusion documentés refusent**, sans indiquer qu'il en existe un autre :

| Chemin | Résultat |
| --- | --- |
| `gh pr merge <n>` | refus — *« part of a stack »* |
| `PUT /repos/{owner}/{repo}/pulls/{n}/merge` | refus — même message |
| Changer la base d'une PR enfant | refus — *« Cannot change the base branch because the pull request is part of a stack »* |

Le seul chemin fonctionnel est l'API asynchrone :

```bash
gh api --method PUT "repos/{owner}/{repo}/pulls/{n}/merge-async" \
  -f merge_method=squash -f merge_action=default
# -> {"status":"pending","uuid":"..."}
```

Deux pièges :

1. **Le suivi documenté ne fonctionne pas.** `GET /pulls/merge-async/{uuid}` renvoie `404`.
   Interroger l'état de la PR elle-même (`gh pr view <n> --json state,mergedAt`).
2. **La fusion porte sur la pile jusqu'à la PR ciblée incluse.** Fusionner la PR du bas
   ne fusionne donc qu'elle. Les enfants restent ouverts et sont **rebasés
   automatiquement** sur la nouvelle base.

> **Vérifié le 2026-09-05** sur la PR #363 (bas de pile) : #363 fusionnée seule, #372
> (enfant) restée ouverte et re-basée automatiquement sur `main`.
> **Ce qui invaliderait ce constat** : GitHub rendant `merge-async` inutile en levant le
> refus sur `gh pr merge` / `PUT …/merge` pour les piles, ou corrigeant le `404` du suivi
> par `uuid`. Revérifier si l'un des deux chemins refusés cesse de refuser.

---

## 3. Propriété du code — `CODEOWNERS`

Le fichier [`.github/CODEOWNERS`](../.github/CODEOWNERS) déclare les responsables de revue
par domaine (backend, mobile, infra, `.github`, docs, registre de migration…).

- **État actuel** : le dépôt appartient à un **compte utilisateur**
  (`gchambaud_microsoft`), pas à une organisation → il n'existe pas encore d'équipes
  GitHub. Tous les périmètres pointent donc vers `@gchambaud_microsoft`.
- **Évolution** : remplacer par des handles d'équipe (`@certigo/backend`, …) dès qu'une
  organisation existera, **sans changer la structure** du fichier.
- **Activation** : `CODEOWNERS` ne devient contraignant que si
  `require_code_owner_reviews = true` est activé sur la protection de `main` (réserve §4).

---

## 4. Réserve admin — (ré)appliquer / durcir la protection

> ⚠️ **Réserve** : les réglages ci-dessous nécessitent des **droits ADMIN** sur le dépôt.
> Ne jamais appliquer le document durci complet avec `PUT`. Une mise à jour des checks doit rester
> limitée à `/protection/required_status_checks`, après lecture de l'état live, en conservant
> `strict` et tous les contextes existants.

### Fichier de capture ré-appliquable

[`.github/branch-protection-main.json`](../.github/branch-protection-main.json) contient un
**état cible pour revue**, incluant les sept contextes du §4. Ce fichier
n'est pas une charge utile à envoyer en bloc : les champs de durcissement restent des réserves
séparées, et seuls les checks requis sont réconciliés ici.
Ces sept noms sont uniquement les gates agrégées stables : aucun job enfant, variante de matrice
ou contexte interne d'un workflow réutilisable ne doit être ajouté à la protection.

### Procédure pas-à-pas (admin)

1. **Pré-requis** : être **admin** du dépôt ; `gh` authentifié
   (`gh auth status` → scope `repo` / admin). Le fichier `CODEOWNERS` doit être mergé sur
   `main` **avant** d'activer `require_code_owner_reviews`.
2. **Dry-run / revue** de l'état actuel (lecture seule) :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/branches/main/protection \
     -H "Accept: application/vnd.github+json"
   ```

3. Après que le contexte a été créé par un run de PR, **réconcilier uniquement les checks requis** :

   ```bash
   gh api --method PATCH \
     repos/gchambaud_microsoft/Certigo/branches/main/protection/required_status_checks \
     -H "Accept: application/vnd.github+json" \
     --input - <<'JSON'
   {
     "strict": true,
     "contexts": [
       "Build & test",
       "Flutter app + UI packages",
       "Generated state equals committed state",
       "Validate workflow YAML",
       "CodeQL / Security gate",
       "Security / Required gate",
       "Fork PR policy / Required gate"
     ]
   }
   JSON
   ```

4. **Vérifier** :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/branches/main/protection \
     --jq '{admins:.enforce_admins.enabled, code_owners:.required_pull_request_reviews.require_code_owner_reviews, convo:.required_conversation_resolution.enabled, checks:.required_status_checks.contexts}'
   ```

   Attendu pour les checks :
   `strict=true` et
   `   checks=["Build & test","Flutter app + UI packages","Generated state equals committed state","Validate workflow YAML","CodeQL / Security gate","Security / Required gate","Fork PR policy / Required gate"]`.

> **Rollback des checks seulement** : rejouer le même endpoint `PATCH` avec `strict` inchangé et la
> liste de contextes antérieure. Ne jamais utiliser `PUT` avec le JSON durci complet.

### Détail des durcissements proposés (réserves)

| Réglage | Actuel | Cible | Effet |
| --- | --- | --- | --- |
| `enforce_admins` | `false` | `true` | Les admins aussi passent par PR + checks. |
| `require_code_owner_reviews` | `false` | `true` | Exige la revue d'un code owner (cf. `CODEOWNERS`). |
| `required_conversation_resolution` | `false` | `true` | Toutes les conversations doivent être résolues avant merge. |
| `required_linear_history` (option) | `false` | *(non retenu)* | Interdirait les merges non fast-forward ; à décider avec l'équipe. |

---

## 5. Réconciliation avec `deployment-runbook.md` (§T0.3)

Le [runbook de déploiement](./deployment-runbook.md) (§T0.3, tableau d'en-tête) marquait :

> `| Branch protection sur main | ⛔ Humain (admin repo) | §T0.3 |`

**Cette entrée est désormais obsolète** : la protection **a été appliquée** depuis la
rédaction du runbook (constat live du lot wp-p0-07, cf. §1). De plus, la commande `gh api`
proposée au §T0.3 du runbook (lignes ~247-253) est **partielle / périmée** :

- elle pose `required_status_checks=null` (aucun check requis), alors que l'état réel exige
  des checks **stricts** (`Build & test`, `Flutter app + UI packages`) ;
- elle pose `enforce_admins=true`, ce qui **ne correspond pas** à l'état actuellement
  appliqué (`enforce_admins=false`).

➡️ **Ce document (`GOVERNANCE.md`) et
[`.github/branch-protection-main.json`](../.github/branch-protection-main.json) font
désormais autorité** pour la protection de `main` et **remplacent** la sous-section
« Branch protection sur `main` » du runbook §T0.3.

---

## 6. Récapitulatif des réserves (à appliquer par un admin, hors session)

- [ ] Activer `enforce_admins = true`.
- [ ] Activer `require_code_owner_reviews = true` (après merge de `CODEOWNERS` sur `main`).
- [ ] Activer `required_conversation_resolution = true`.
- [ ] *(Optionnel, à arbitrer)* `required_linear_history = true`.
- [ ] Réconcilier les checks requis avec les sept contextes du §4, en gardant
      `strict=true`.
- [ ] Dans **Settings → Actions → General**, conserver le token par défaut en
      lecture seule, désactiver l'autorisation pour GitHub Actions d'approuver
      des PR et restreindre les Actions autorisées. L'épinglage SHA complet est
      contrôlé localement par `validate-workflow-security.mjs`.
- [ ] Ajouter `Fork PR policy / Required gate` aux contextes requis. Les PR de forks
      restent non supportées et échouent fermement sans checkout ; seules les PR internes
      peuvent exécuter leur SHA de tête uniquement sur `certigo-pr`, sans environnement,
      secret ou identité cloud. Les gates agrégées sans source PR et toutes les opérations
      privilégiées utilisent exclusivement `certigo-trusted`.
- [x] Le secret `AUTOMERGE_TOKEN` a été supprimé et le PAT correspondant révoqué.
      Aucun workflow ne dépend de cet ancien mécanisme.
- [ ] Protéger l'environnement `beta` avec reviewers obligatoires, interdiction
      d'auto-approbation et déploiement limité à la branche `main` uniquement.
      Stocker ses secrets de signature/publication dans cet environnement.
- [ ] Limiter `dev`, `staging` et `prod` aux branches protégées. Ajouter des
      reviewers obligatoires et interdire l'auto-approbation sur `staging` et
      `prod`. Conserver les secrets OIDC `AZURE_*` au niveau environnement, pas
      au niveau dépôt.
- [ ] Supprimer toute règle de déploiement ou autorité de release fondée sur
      `v*`. Les tags restent une métadonnée de traçabilité et ne déclenchent
      aucun workflow privilégié.

Les mises à jour de versions de `.github/dependabot.yml` restent une aide de maintenance.
La décision de sécurité repose exclusivement sur les gates Azure bloquantes OSV (qui couvre
NuGet/csproj, npm et pub), Checkov et CodeQL, sans activation de fonctionnalité Enterprise.

Ces réserves ne doivent pas être appliquées implicitement avec le JSON complet. Les traiter
séparément, avec revue admin et lecture préalable de l'état live.

---

## 7. Discipline de mesure — un instrument muet doit échouer, pas rendre zéro

> **Note opérationnelle.** Faits relevés le **2026-09-08**, journée où une dizaine de sessions ont
> travaillé en parallèle sur ce dépôt et sur `certigo-content`. **Invalidée** le jour où les parades
> ci-dessous deviennent structurelles — c'est-à-dire où un instrument de ce dépôt ne peut plus rendre
> un verdict sans avoir déclaré ce qu'il a lu. Tant qu'écrire un instrument muet reste possible, la
> note vaut, quel que soit l'âge des incidents.

Cette section prolonge le §1, qui dit déjà **comment lire un verdict** — voir « Un vert peut décrire
une base qui n'existe plus » et « Deux corollaires pour lire les sorties ». Elle ajoute la question
d'avant : **le verdict a-t-il seulement été produit par une lecture ?**

Ce jour-là, **dix instruments ont rendu un résultat sans avoir rien mesuré.** Chacun a été attrapé
par un contrôle différent, improvisé sur le moment, et les traces se trouvaient dans des commentaires
de PR et des messages appelés à disparaître. Ce qui suit ne conserve pas les incidents pour eux-mêmes :
il conserve **ce qui les a attrapés**.

### Un critère de relecture pour tout le §7 — chaque règle doit être exécutable par un lecteur seul

> Ajouté le **2026-09-09**. Cette sous-section ne relève pas un incident : elle fixe la forme que
> chaque règle ci-dessous doit prendre pour survivre à ceux qui les écrivent. **Invalidée** le
> jour où toute règle du §7 se relit et se ferme sans nommer un rôle, une équipe ou une personne.

Nous avons vu une contre-mesure passer, dans une même conversation, d'une forme locale à une
forme qui nommait un rôle — *demander à tel rôle avant d'agir*. La reformulation ressemblait à un
durcissement, et se dégradait en trois temps : elle dépend d'un acteur ; sous saturation, elle
devient attente ; sous pression, l'attente devient action non demandée — c'est-à-dire exactement
ce que la règle interdisait.

**La version robuste est locale.** *Sous ambiguïté, ne rien faire est le comportement par défaut*
se relit sur place et se vérifie sans personne.

> **Une règle qui nomme un rôle n'est plus une règle — c'est une dépendance.** Elle meurt le jour
> où le rôle n'existe plus, et elle meurt silencieusement : le lecteur ne saura pas à qui
> s'adresser, et fera le geste.

**Critère de relecture pour tout le §7** — chaque règle doit être exécutable par un lecteur seul.
Aucun nom d'acteur, aucun rôle à joindre, aucune procédure qui suppose une réponse venue
d'ailleurs. Ce document est destiné à survivre à ceux qui l'écrivent ; ce critère est ce qui rend
cette survie possible.

**Contre-mesure — à l'écriture, gratuite.** Toute formulation qui contient *demander à*, *faire
valider par*, *sous accord de* se réécrit en une conduite locale — attendre, s'abstenir, consigner
— vérifiable là où elle s'applique. Ce que le rôle apportait à la règle, la règle doit le porter
elle-même.

### Les dix instruments vides

| # | Instrument | Ce qu'il rendait | Pourquoi c'était vide |
| --- | --- | --- | --- |
| 1 | `Object.keys()` appliqué à un **tableau** | « identifiant absent » | Rend les **indices** (`["0","1"]`), jamais les identifiants : « absent » sans qu'aucun élément ait été examiné. |
| 2 | SHA tronqué à **8 caractères** envoyé à l'API GitHub | **liste vide** | Une liste vide est indiscernable d'une absence réelle. |
| 3 | `require('yaml')` indisponible | `exit 127` | **Quatre** configurations différentes rendaient le même code : le discriminant attendu n'était jamais atteint. |
| 4 | `git show … \| Set-Content -NoNewline` | **quatre verdicts identiques** | Le pipeline concatène les lignes **sans séparateur** ; les verdicts mesuraient l'écriture du fichier, pas son contenu. |
| 5 | `npm ci` non lancé | trois `ERR_MODULE_NOT_FOUND` | Ressemblent à des échecs de test ; ce sont des dépendances absentes. |
| 6 | Enveloppe `{corpus, nbCorpus, nbQuestions}` non déballée | « 0 problème » | **3** clés comparées à **33** identifiants : aucune régression n'était *représentable*, donc aucune n'a été trouvée. |
| 7 | Localisateur par **chaîne exacte** après réécriture complète | « introduit » | La transformation mesurée détruisait la clé de comparaison : réponse vraie **par construction**. |
| 8 | `\b` adjacent à une lettre accentée, en JS | jamais de correspondance | `é` n'est pas un caractère de mot : le motif existe, tourne, et ne participe jamais. |
| 9 | `.Replace()` sur une constante qui avait changé sous l'auteur | **rouge** | Une mutation qui échoue et un vrai défaut rendent le même rouge. |
| 10 | Motif **sur-échappé** (`\\d` au lieu de `\d`) | — | Le seul attrapé **avant exécution**. |

Trois de ces mécanismes tiennent en une commande, et ont été rejoués le 2026-09-08 :

```bash
node -e "console.log(Object.keys([{id:'q1'}]))"                # ["0"]  — n°1
node -e "console.log(/\bla totalité\b/.test('la totalité'))"   # false  — n°8, y compris avec /u
node -e "console.log(new RegExp('\\\\d+').test('42'))"         # false  — n°10
```

**Le n°2 n'a pas été reproduit.** Rejoué le 2026-09-08 sur quatre points d'entrée REST
(`commits?sha=`, `commits/{sha}/pulls`, `compare/…`, `search/commits`), un SHA de 8 caractères est
**résolu normalement** ; en GraphQL, `GitObjectID!` le **rejette bruyamment**. L'incident reste
consigné tel qu'observé, sans mécanisme nommé : écrire ici une cause non reproduite serait commettre,
dans une note sur la mesure, exactement la faute qu'elle décrit.

### Les parades, par coût croissant

**a. L'autotest de quelques chaînes, avant la première exécution.** Le n°10 n'a **jamais** produit de
résultat faux : quatre chaînes de contrôle l'ont arrêté avant qu'il ne serve. Les neuf autres en ont
produit un, qu'il a fallu reconnaître, puis défaire.

**b. Le plancher de lecture — la seule parade structurelle.**

```js
if (corpus < 30 || questions < 700) throw new Error('lecture insuffisante');
```

**Un instrument qui n'a rien lu échoue, au lieu de rendre zéro.** C'est la seule des quatre parades
qui couvre les dix cas, et la seule qui protège **sans qu'on y pense** : elle ne demande pas au
lecteur de se méfier au bon moment.

**c. Le contrôle qui rend une présence.** Avant de conclure à une absence, montrer que l'instrument
sait rendre autre chose. **Une absence n'informe que si l'instrument peut varier.** Le §1 pratique
déjà ce geste, sous « Snapshot d'état projet périmé : la branche, ou `main` ? » : « Ne croyez pas la
liste ci-dessus sur parole : dix secondes suffisent à la tester. »

> **Onzième cas, attrapé pendant la rédaction de cette section, le 2026-09-08.** Le script qui
> vérifiait la présence des citations ci-dessus a rendu deux « ABSENT » et un `True` pour un nom de
> fonction inexistant. Un témoin négatif — chercher `zzzNeverExistsZzz` — a rendu `True` lui aussi :
> l'instrument ne lisait rien. Les deux « ABSENT » étaient des retours à la ligne (le n°4), et le
> `True` un `-Quiet` mal composé. **Deux minutes de témoin ont évité de publier, dans une note sur la
> mesure, une citation fausse et un symbole inventé.**

**d. L'assertion sur l'ACTION, pas sur son résultat.** Pour le n°9, la ligne qui manquait est
`substitution effective : True`. **Le résultat ne distingue pas « j'ai mesuré » de « je n'ai rien
mesuré » ; l'action, si.**

### Le signal partagé : l'uniformité

Aux n°3, 4 et 9, **des entrées différentes rendaient exactement la même sortie.**

> **Quand des entrées variées donnent le même résultat, le discriminant n'a pas été atteint : on
> mesure l'instrument, pas l'objet.**

C'est le seul symptôme commun à plusieurs de ces incidents, et il se teste **sans comprendre la
panne** : faire varier l'entrée, regarder si la sortie bouge.

**Corollaire côté règle de décision.** Sur deux corpus de questions relayés le **2026-09-09**, la
même règle a commandé **deux décisions opposées** — ne pas réécrire sur l'un, réécrire sur l'autre
— parce que les axes qu'elle examinait n'avaient pas le même poids dans chaque corpus. **C'est
cette capacité à trancher dans les deux sens qui valide un critère** : un critère qui ne peut
produire qu'une seule réponse ne mesure rien, et l'uniformité qu'il présente dans ses sorties n'est
pas une propriété du monde, mais du critère lui-même. Le détail chiffré appartient au dépôt de
contenu où la mesure a été faite ; ici, seul importe le geste — **exiger d'un critère qu'il
démontre, avant d'être utilisé, qu'il peut trancher dans l'autre sens**.

**Corollaire — la non-discrimination existe aussi côté parade.** Une contre-mesure qui se
déclenche toujours n'est pas une contre-mesure : c'est un rituel. Elle coûte à chaque passage et
n'informe à aucun. De même qu'un critère qui produit toujours la même réponse ne mesure rien, une
parade qui s'applique quelle que soit la situation ne protège plus rien — la non-discrimination
prend deux formes, l'une côté critère, l'autre côté parade. **Une parade bien écrite se déclenche
quand son motif se produit, et se tait quand il ne se produit pas** ; son silence, quand il est
attendu, est un signe qu'elle vit, pas qu'elle dort.

### Le détecteur qui normalise ce qu'il cherche

> Ajouté le **2026-09-09**. Variante d'entrée de ce que la sous-section « Les dix instruments
> vides » nommait « réponse vraie par construction » (n°7).

Un contrôle du presse-papiers appliquait `.Trim()` sur la première ligne **avant** de tester le
préfixe attendu, alors que l'hypothèse examinée était précisément « un caractère invisible en
tête ». **L'instrument normalisait le défaut qu'il devait détecter** — il ne pouvait pas le
trouver, non parce qu'il était absent, mais parce que la chaîne de mesure l'avait retiré avant la
mesure.

> **Un détecteur qui transforme son entrée avant de la comparer ne détecte plus qu'après cette
> transformation ; si le défaut cherché est dans la transformation, il n'apparaît jamais.**

À ranger avec le n°7 de la table : deux formes du même piège, l'un côté sortie (la clé de
comparaison détruite par la transformation mesurée), l'autre côté entrée (le défaut normalisé
avant d'atteindre le comparateur).

### Le rendu peut mentir sur la présence des données

> Ajouté le **2026-09-09**. Nouvelle variante de la famille des instruments qui mentent, la plus
> insidieuse pour un opérateur humain : **un affichage vide se lit comme une absence, jamais comme
> une panne d'affichage**. **Invalidée** le jour où l'outil rend le même résultat quel que soit le
> format demandé, ou signale explicitement lorsqu'un rendu tabulaire a soustrait des lignes.

**Le motif mesuré.** Une même requête, sur le même corpus, à la même seconde : rendue en tableau,
elle affiche **zéro ligne** ; rendue en format structuré, elle affiche **seize**. Ni la requête ni
la donnée n'ont menti — **c'est la couche d'affichage qui a soustrait, silencieusement**.

**Ce qui rend cette variante plus dangereuse que les précédentes.** Un tableau vide **ne demande
pas à être expliqué** : il est cohérent avec lui-même, il ressemble à une réponse, il clôt la
question comme un vert (voir « Un succès exact peut clôturer l'examen »). Un opérateur qui voit
zéro ligne conclut à l'absence — c'est la lecture attendue d'un tableau vide. **La panne de rendu
ne se trahit qu'en changeant de format**, jamais dans le rendu lui-même.

**Contre-mesure — gratuite, mais avant la conclusion.** Quand un affichage rend zéro, **redemander
la même requête dans un autre format** avant de conclure à l'absence. Un écart entre les deux
formats désigne la panne ; leur accord ferme la question.

> **Un affichage vide est un instrument qui ment sans mentir : il ne fabrique rien de faux, il
> soustrait ce qu'il devait montrer. Un négatif silencieux dont seule la comparaison avec un
> témoin d'un autre format le fait apparaître.**

### Le nom qui contredit l'état — troisième mensonge de la couche de présentation

> Ajouté le **2026-09-09**. Trois occurrences mesurées le même jour, dont deux sont apparues
> **indépendamment**, sans communication entre leurs auteurs. **Invalidée** le jour où le dépôt
> refuse d'écrire un mot d'état dans un identifiant, ou signale explicitement ceux qui en
> contiennent un.

**Trois façons dont une couche de présentation trahit l'objet qu'elle présente**, à lire ensemble :
le **format** (voir « Le rendu peut mentir sur la présence des données » : la couche d'affichage
soustrait ce qu'elle devait montrer), le **libellé** (voir « Un message d'erreur exact peut
désigner une cause fausse » dans « Citer sans envoyer... » : la sortie exacte pointe à côté quand
un intermédiaire n'a pas été nommé), et le **nom** — cette sous-section : l'identifiant lui-même
porte un mot qui contredit l'état.

**Trois occurrences.** Un travail de CI dont le nom contient le mot de l'échec, mais qui a
**réussi** : filtre textuel sur ce mot, décision « rouge » — **deux opérateurs différents, aucun
contact, le même jour**. Un workflow dont le nom porte le mot « désactivé » alors que son état
structuré est **actif**. Un identifiant cité dans un document comme désactivé, réactivé depuis
sans mise à jour du document.

**Ce n'est pas de l'inattention — c'est structurel.** Deux instruments, deux auteurs, aucun
contact, le même défaut le même jour ne signent pas une distraction ; ils signent une propriété
du support. **Un nom qui contient un mot d'état est un piège pour tout filtre textuel et pour
tout lecteur pressé.**

**Deux contre-mesures, de coûts très différents.**

- **À la lecture — bon marché, défensive.** Ne jamais déduire un état d'un nom. Lire le champ
  d'état. Un zéro sur un filtre textuel ne prouve rien ; un champ structuré, si.
- **À l'écriture — génératrice.** Ne jamais écrire un mot d'état dans un nom. **Un nom est
  permanent ; un état ne l'est pas.** Encoder un état dans un nom garantit qu'il deviendra faux —
  la seule question est quand.

> **La règle d'écriture est la vraie règle** : elle explique les trois cas et prévient les
> suivants. La règle de lecture ne fait que s'en défendre.

Le pattern commun aux trois façons — format, libellé, nom : **l'objet est correct ; sa
présentation ne l'est pas ; le lecteur lit la présentation.**

### La limite structurelle de la ressource transitoire — ce que le nom ne peut pas porter

> Ajouté le **2026-09-09**, à lire immédiatement après « Le nom qui contredit l'état ».
> **Invalidée** le jour où toute lecture sur une ressource transitoire s'écrit avec le processus
> concurrent connu, ou signale explicitement qu'aucun processus concurrent n'a été identifié.

**Le motif.** Un relevé frais, exact, pris à la seconde, a supporté **deux conclusions opposées** :
résidu d'un nettoyage avorté, ou ressource d'une opération en cours. Rien dans le relevé ne
permettait de trancher, et la lecture alarmante — celle vers laquelle l'instinct penche —
détruisait une opération en vol.

**Remésurer protège contre un état périmé** (voir « La parade de dernier recours : deux mesures
qui se contredisent »). **Cela ne protège pas contre une lecture ambiguë d'un état frais quand un
autre acteur agit sur le même objet.** La mesure est vraie ; c'est la lecture qui invente un
processus — celui qu'on cherche à confirmer — au lieu de constater qu'aucun processus n'est
nommé.

**Le lien avec « Le nom qui contredit l'état ».** Ce constat établit qu'un nom ne peut pas porter
un état, parce que le nom est permanent et l'état ne l'est pas. La conséquence, à écrire ici, est
plus lourde :

> **Puisqu'un nom ne peut pas porter un état, l'état d'une ressource transitoire n'est lisible
> nulle part sur la ressource. Il n'existe que dans le processus qui la manipule.** Ce n'est donc
> pas un défaut de nommage corrigible — c'est une **limite structurelle**, et c'est ce qui rend la
> règle d'abstention (voir « L'asymétrie de l'incertitude — le défaut, par règle, est l'attente »)
> **nécessaire plutôt que prudente**.

**Contre-mesure — gratuite, mais avant la lecture.** Avant de conclure sur une ressource
transitoire à partir d'un relevé, nommer le processus qui pourrait être en cours dessus. Si aucun
processus concurrent n'est nommable, la conclusion n'est pas *rien ne se passe* — c'est *on ne
sait pas*, et la règle d'abstention s'applique.

### L'instrument aveugle à son propre passé

> Ajouté le **2026-09-09**. Nouvelle forme de la famille des instruments qui mentent, la plus
> retorse rencontrée jusqu'ici — elle échappe à la parade d'uniformité, parce que l'instrument
> **ne varie pas** : il ne voit pas.

Un outil que nous appelions liste les ressources existantes **en les filtrant par la clé qu'on lui
fournit**, puis crée si la liste rendue est vide. **Son filtre est donc aussi son critère
d'existence.** Conséquence : une ressource créée par ce même outil sous une clé antérieure
**n'apparaît dans aucune liste qu'il consulte**. Il ne peut structurellement pas signaler qu'on
approche d'un plafond fournisseur — il verra `0`, créera, et l'échec viendra de plus loin, dans
un message qui ne nommera pas la cause.

> **Un instrument dont le filtre sert de critère d'existence est aveugle à tout ce qui existe hors
> du filtre — y compris à ce qu'il a lui-même produit.**

**Contre-mesure.** Quand un outil décide « ça n'existe pas », demander **sur quel critère** — et
compter la ressource **hors de l'outil** quand ce critère est fourni par l'appelant.

### Trois règles d'inférence, chacune payée deux fois

**1. Le volume dit combien, il ne dit pas si.** Deux fois, une session a mesuré une composition exacte
— « 64 % de cette famille est de la négation neutre », « 19,6 % de ces appariements sont temporels » —
et en a tiré un **verdict de validité**. Les deux fois, une permutation a montré que la partie réputée
contaminante **portait le signal**. Le pourcentage était juste ; « donc c'est un défaut » ne suivait
pas.

**2. Un état décrit un passé.** Un contrôle vert mesure la base contre laquelle il a tourné, pas la
fusion qu'il prédit. **Cette règle est déjà instruite**, avec son relevé daté, sous « Un vert peut
décrire une base qui n'existe plus » : le vert périmé y est établi comme **le régime ordinaire, pas
l'exception**. Elle n'est pas répétée ici.

**3. Une mémoire correctement datée n'est pas une mesure courante.** Un compteur relu dans une note
puis recyclé comme frais a donné **« 28 PR ouvertes »** là où il y en avait **9**, et **« 90 minutes »**
là où la soustraction de deux horodatages donne **56** — les deux valeurs justes figurant, mesurées,
sous « Un vert peut décrire une base qui n'existe plus ». Une note bien datée reste vraie **à sa
date** ; la recycler sans la redater la transforme en mesure fausse.

### Un contrôle nécessaire n'est pas un contrôle suffisant

> Ajouté le **2026-09-09**.

La validation d'une clé PEM traverse deux portes distinctes, **éloignées dans le temps** : d'abord
`value.startswith("-----BEGIN ")` à l'analyse des arguments, puis `load_pem_private_key` bien plus
tard, à l'usage réel. **Une valeur aplatie sur une seule ligne franchit la première et échoue à la
seconde.** Le premier contrôle est nécessaire ; il n'est pas suffisant, et rien dans son succès ne
distingue une valeur valide d'une valeur qui *commence bien*.

> **Le franchissement d'un contrôle nécessaire ne prouve pas la validité — il prouve que la valeur
> a la forme qui fait franchir ce contrôle.** Lire l'un pour l'autre, c'est ranger un instrument
> partiel comme instrument complet.

Séparer les deux contrôles dans le temps rend la confusion structurelle : entre les deux, un lecteur
qui a vu passer le premier conclut au pire moment que le second n'était pas censé échouer.

### Une sonde en amont est une garde déguisée

> Ajouté le **2026-09-09**. Famille **distincte** de celle des instruments qui mentent : cet
> instrument était exact et a détruit l'opération qu'il devait observer. **Invalidée** le jour où
> toute vérification placée avant une boucle de travail est examinée sur la question *son échec
> doit-il arrêter cette opération ?* avant d'être écrite.

**Le motif.** Une opération de chargement de données a échoué sans jamais commencer : une sonde
de vérification, placée avant la boucle de travail, a levé une exception parce que sa requête
était invalide. La sonde ne chargeait rien — elle observait.

**C'est une famille distincte de celle des instruments qui mentent.** Ceux-là rendent un faux
résultat ; celui-ci rendait un résultat **exact** — la requête était réellement invalide — et
**a détruit l'opération au lieu de la décrire**. Le défaut n'est pas dans le verdict, il est dans
la place.

> **Un contrôle placé avant ce qu'il mesure ne peut rien mesurer — il ne peut que bloquer.** Sa
> place était après la boucle de travail, où il aurait décrit un résultat au lieu d'empêcher une
> cause.

**Deux parades, l'une faible, l'autre juste.**

- **Parade faible** — envelopper la sonde pour qu'elle ne lève plus. Le contrôle reste au mauvais
  endroit et ne mesure toujours rien ; on a acheté du silence, pas de la lecture.
- **Parade juste** — **déplacer** la sonde après l'opération qu'elle observe ; ou assumer que
  c'est une **garde**, et le dire. Ce sont deux gestes de conception, pas deux styles de code.

**Le test qui tranche est bon marché — une question.** *Si ce contrôle échoue, l'opération
doit-elle s'arrêter ?*

- **Oui** — c'est une **garde**. Sa place en amont est légitime, et son échec doit bloquer, sans
  enveloppe.
- **Non** — c'est une **sonde**. Sa place est en **aval**, et sa présence en amont est un défaut
  de **conception**, pas un défaut de robustesse. Absorber son échec dans une garde ne corrige
  que le symptôme.

> **Une sonde en amont est une garde déguisée. Le lecteur doit pouvoir classer son propre
> contrôle en une question.**

**Corollaire de coût.** Quand une sonde bloque, le correctif le moins cher n'est pas toujours de
la réparer : c'est parfois de la retirer. Une sonde qui ne peut pas mesurer doit dire qu'elle n'a
pas pu mesurer, jamais interrompre ce qu'elle observe — et si l'écrire coûte plus que ce que la
sonde apporte, l'absence de sonde est plus honnête que sa présence.

### L'asymétrie de l'incertitude — le défaut, par règle, est l'attente

> Ajouté le **2026-09-09**, à lire ensemble avec « Une sonde en amont est une garde déguisée » :
> l'un cadre le geste de conception, l'autre cadre le geste de décision. **Invalidée** le jour où
> toute action sur un objet partagé ou irréversible se relit sous la question *l'inaction
> coûte-t-elle du temps, ou un état ?* avant d'être exécutée.

**Le motif.** Trois gestes de nature différente ont partagé le même réflexe : élargir une règle
de filtrage qui ne correspondait pas, régénérer un secret quand une opération échouait, supprimer
une ressource qui semblait abandonnée. **Dans les trois cas, l'action était le seul chemin vers
le dégât ; l'inaction ne coûtait qu'un délai.**

**L'attente et l'action ne sont pas symétriques quand l'objet est partagé ou irréversible.**
L'attente coûte du temps, mesurable, revenu à zéro dès qu'on obtient l'information manquante.
L'action, sur un tel objet, coûte un état que personne n'a décrit — et cet état, une fois posé,
ne revient pas au précédent sur la simple constatation qu'il était prématuré.

> **Sous incertitude sur un objet partagé ou irréversible, le défaut est l'attente — et il doit
> l'être par règle**, parce que l'instinct va dans l'autre sens. Une règle prudente laisse le
> réflexe gagner ; seule la règle **par défaut** l'arrête.

**Cette règle ne se lit pas comme une invitation à la prudence.** C'est une **règle
d'abstention** — locale, exécutable sans arbitrage extérieur (voir « Un critère de relecture pour
tout le §7 »). Elle ne demande à personne *faut-il agir ?* — elle statue : *sans certitude sur ce
que l'action produira, on attend*.

**Contre-mesure — à la décision, gratuite.** Avant tout geste sur un objet partagé ou
irréversible, demander : *l'inaction coûte-t-elle du temps, ou un état ?* Si elle ne coûte que du
temps, elle est le défaut.

### Le transport ampute la portée avant le chiffre

> Ajouté le **2026-09-08**, quelques heures après le reste du §7. **Invalidé** le jour où un nombre
> relayé sans objet ni date est refusé à la lecture plutôt que corrigé après coup.

**Le cas.** Une session mesure `200 / application/json / 0 redirection` sur un chemin de production.
**La mesure est exacte** : elle porte sur un fichier témoin déposé pour valider une règle de
réécriture, puis retiré, disparition vérifiée — et son contrôle négatif figure **dans le même
message**. Relayée, elle devient « le fichier est servi » et circule huit heures, jusqu'à ce qu'une
remesure rende `404`. **Aucun instrument n'a échoué et personne n'a menti.**

**Pourquoi ce n'est pas de la distraction.** Les autres cas de ce §7 sont des défauts d'instrument ;
celui-ci est un défaut de **transport**.

> **Un nombre est portable, une portée ne l'est pas.** `200` tient en trois caractères et se cite ;
> « sur un fichier témoin déposé pour valider la règle de réécriture, puis retiré » est une phrase
> qu'un résumé écrase. **Le transport sélectionne ce qui est court**, et un coordinateur par lequel
> tout passe est précisément l'endroit où tout se résume. La règle qui suit doit donc être
> **opposable, pas recommandée** : elle doit tenir sans la vigilance de celui qui relaie.

1. **Un nombre relayé ne s'écrit jamais seul.** Forme minimale : *`<valeur>`, mesurée sur `<objet>`,
   le `<date>`*. Un nombre privé de l'un des trois champs est **irrecevable** — pas « à vérifier ».
2. **Si la portée ne tient pas dans la phrase qui porte le nombre, le nombre ne se transmet pas** :
   on transmet le lien vers la mesure.
3. **Un nombre qui va décider se remesure avant d'être opposé** — pas en cas de doute, *avant de
   décider*. C'est la règle qui aurait tout arrêté ; appliquée, elle a coûté trente secondes. Le
   chiffre avait circulé huit heures **parce qu'il n'était pas contesté**, ce qui n'est pas une
   propriété de la mesure.

### Le chiffre qui ne décide pas ne s'écrit pas

> Ajouté le **2026-09-09**, immédiatement après avoir failli inscrire nous-mêmes une valeur
> incorrecte dans un commentaire. Le mécanisme est écrit sans valeur numérique ; l'incident précis
> qui a produit ce constat n'appartient pas au dépôt — c'est ce que ce constat prescrit.

Ce prolongement attrape ce que la sous-section précédente ne couvre pas. « Le transport ampute la
portée avant le chiffre » attrape le nombre relayé sans objet ni date ; celui-ci attrape le nombre
**écrit sans décision**. Un plafond fournisseur allait être inscrit dans un commentaire.
Vérification faite, la valeur retenue portait sur un programme voisin, et la valeur réelle était
différente — l'une comme l'autre venant de sources tierces, donc **non mesurées**. Et surtout, **la
règle qui en dépendait était identique pour les deux valeurs.** Le chiffre n'a jamais rien décidé ;
il n'apportait que du risque.

> **Quand le mécanisme décide et que le chiffre ne décide pas : écrire le mécanisme, omettre le
> chiffre.** Un nombre attire l'œil, se périme, et se transporte hors de son contexte ; c'est lui
> qui deviendra faux, et il sera cru **parce qu'il est précis**.

**Contre-mesure.** Avant d'inscrire une valeur, se demander **quelle décision changerait si elle
était autre**. Si aucune : ne pas l'écrire. Cette règle est plus stricte que la précédente : elle
ne dit pas seulement *comment* transmettre un chiffre, elle dit *quand ne pas l'écrire du tout*.

### Un nombre qui décide s'écrit avec le mécanisme qui le contraint

> Ajouté le **2026-09-09**, à lire en miroir immédiat de la sous-section précédente.
> **Invalidée** le jour où toute valeur numérique portant une garantie apparaît, au point où elle
> est écrite, à côté du mécanisme qui l'a contrainte — et où toute modification de la valeur est
> refusée quand le mécanisme n'a pas été relu.

**Le symétrique de « le chiffre qui ne décide pas ne s'écrit pas ».** La règle précédente attrape
le chiffre inscrit **sans décision**. Celle-ci attrape le chiffre inscrit **sans son mécanisme
contraignant**. Les deux se lisent ensemble : **un nombre du dépôt sans mécanisme adossé n'est pas
une mesure — c'est une préférence.**

**Le motif.** Une cadence, un délai, un intervalle est fixé non pour son coût propre mais pour
**rester en deçà d'une borne d'expiration définie ailleurs** — sur un jeton, un lock, une session,
une fenêtre de validité. Écrite seule, la valeur ressemble à un choix économique. Un lecteur
ultérieur qui cherche à la simplifier — rehausser pour économiser des appels, arrondir à une
valeur plus « propre » — ne voit pas la contrainte : il agit sur ce qui ressemble à une préférence,
et **franchit la borne** — silencieusement, et seulement plus tard, quand le jeton expirera plus
vite que la boucle ne le rafraîchit.

> **Une préférence se simplifie ; une contrainte se relit. Écrire un nombre sans son mécanisme,
> c'est le faire passer de contrainte à préférence sous la main d'un lecteur qui ne le savait
> pas.**

**Contre-mesure — bon marché, au moment d'écrire.** Toute valeur numérique portant une garantie
s'écrit avec sa contrainte **au même endroit**, en trois éléments suffisants : la borne qu'elle
respecte, la marge conservée sous cette borne, et le fichier ou paramètre où la borne est
définie. Sans ces trois éléments, la modification suivante de la valeur se fera à l'aveugle.

**Corollaire — comment lire les deux règles ensemble.** L cadre l'**omission** : *ne pas écrire un
chiffre qui ne décide pas.* Q cadre l'**écriture** : *ne pas écrire un chiffre utile sans son
mécanisme.* Ensemble, elles ne laissent que deux formes acceptables à un nombre du dépôt : soit il
décide et il porte son mécanisme, soit il ne décide pas et il n'est pas écrit. **Tout nombre
présent sans mécanisme adossé est présumé être une préférence — et les préférences se
simplifient.**

### La parade de dernier recours : deux mesures qui se contredisent

Aucune parade de ce §7 n'aurait attrapé le cas ci-dessus. **Ce qui l'a fait tomber, c'est un `404`
opposé à un `200`.** Le 2026-09-08, trois fois, le seul détecteur disponible a été l'incohérence
entre deux mesures — jamais un contrôle prévu pour ça : ce `404` contre `200` ; un `exit 0` contre
un témoin à `False` ; un comptage à 6 contre un outil rendant 5.

> **Quand deux sorties ne peuvent pas être vraies ensemble, ne choisissez pas la rassurante :
> cherchez laquelle ment.**

Elle ne se planifie pas — on ne décide pas de rencontrer une contradiction. Mais elle s'applique dès
qu'on la connaît, et elle est gratuite : elle ne demande qu'un second regard sur deux résultats
qu'on possède déjà.

**Attention aux fausses contradictions par convention inversée.** Deux mesures **identiques**
exprimées dans deux conventions opposées — par exemple `rang 0 = la plus courte` côté outil,
`rang 0 = la plus longue` côté rapport — se lisent comme un désaccord. **C'est exactement le
signal qu'on utilise pour détecter les vraies erreurs** ; le confondre avec une contradiction
réelle use un détecteur qui n'a rien d'autre à sa place. **Toute mesure transmise doit donc porter
sa convention** — au même titre qu'un nombre relayé porte son objet et sa date — sous peine de
déclencher un détecteur légitime sur un faux positif, et de l'user.

### La limite de la parade de dernier recours : deux mesures qui disent vrai sur des objets différents

> Ajouté le **2026-09-09**. Première limite documentée d'une des parades de ce §7 — non pas une
> brèche qu'on peut colmater en aval, mais une **frontière de conception**. **Invalidée** le jour
> où l'on adopte une convention explicite qui exige de nommer l'objet mesuré avant de rendre la
> mesure.

La parade précédente cherche laquelle de deux mesures ment ; elle suppose qu'au moins l'une des
deux ment — c'est-à-dire qu'un rapprochement est possible entre elles. **Elle échoue en silence
dès que deux mesures disent vrai sur des objets différents portant le même nom.**

**Le motif.** Un même mot désigne, dans le dépôt, deux objets distincts — par exemple un champ
persisté qui entre dans une clé d'idempotence, et un champ homonyme seulement transmis à l'appel.
On pose une question sur « le champ » ; l'outil répond sur l'un des deux, la réponse est vraie, et
la conclusion — que la lecture tire sur l'autre — est fausse. **Aucune mesure ne se contredit
elle-même.** La contradiction, si on savait la voir, serait entre l'**objet** posé par la question
et l'**objet** rendu par la réponse.

**Pourquoi la parade ne l'attrape pas.** Elle compare deux mesures, non deux objets. Elle regarde
en aval de la question ; c'est la question qui, en amont, a fusionné deux objets sous un mot.

**Contre-mesure — gratuite, mais avant la mesure.** Nommer l'objet avant de mesurer : *« sur quel
champ précis ce nom renvoie-t-il ici — la ligne persistée, ou la valeur transmise ? »* puis mesurer
ce champ-là. C'est un geste **d'avant lecture**, pas de vérification.

> **Aucune parade *aval* ne rattrape une question qui a fusionné deux objets sous un mot.**

### Le dispositif de secours n'est éprouvé que hors incident

> Ajouté le **2026-09-09**. **Invalidée** le jour où chaque workflow présenté chez nous comme filet
> de sécurité porte, dans un cycle plus court que sa condition d'invocation, la preuve datée d'un
> lancement délibéré hors incident, **sur le chemin qu'il empruntera en service**.

**Le cas, chez nous.** `codemagic.yaml`, workflow `ios-refresh-signing` : il ne déclare aucun bloc
`groups:` sous `environment:`, alors que les trois autres workflows iOS de ce dépôt (`ios-release`,
`ios-release-dry`, `ios-crash-smoke`) déclarent tous `groups: - certigo_mobile_config`. L'ancre
`step_setup_signing` qu'il invoque utilise `--certificate-key @env:CERTIFICATE_PRIVATE_KEY`,
variable Secure de ce groupe. Il échoue donc à 100 %, dès sa première seconde. Il est `manual-only`
— aucun push ne l'a jamais déclenché, personne ne l'a jamais lancé — et il a été présenté à
plusieurs reprises, par nous-mêmes, comme le filet à utiliser en cas de problème de signature iOS.

Un dispositif de secours n'est éprouvé que par le chemin qu'on n'emprunte qu'en cas d'incident.
Sans lancement délibéré **hors** incident, son premier essai réel a lieu au pire moment — en
situation déjà dégradée, où il empile une seconde erreur trompeuse sur la première.

> **« On remplacera un filet cassé par un filet non testé. »**

**Corollaire.** Un filet non testé est **plus dangereux** qu'un filet absent, parce qu'on renonce
à d'autres protections en comptant dessus.

**Corollaire de coût — le moment change ce que le test coûte.** L'outil de signature
(`fetch-signing-files --create`) est idempotent : il crée ce qui manque, réutilise ce qui existe.
Lancer le filet **avant** que le certificat Apple n'existe le **crée** — et consomme le quota qu'il
sert à protéger ; le lancer **après** le réutilise, et le test est gratuit. **Le moment d'un test
peut changer son coût du tout au rien** ; le régime de vérification doit choisir ce moment, pas le
subir.

**Corollaire de validité — le moment change *ce* qui est testé.** Le même outil suit deux chemins
distincts : **créer** la ressource si elle manque, **réutiliser** celle qui existe. Un filet réel
n'est emprunté, en service, que sur le chemin de **réutilisation**. Le tester avant que la
ressource n'existe valide donc le chemin de **création** — l'autre branche.

> **Un filet non testé n'inspire aucune confiance. Un filet testé sur une branche qu'il
> n'empruntera jamais en service en inspire une fausse** — et une fausse assurance est plus
> coûteuse qu'une absence d'assurance, parce qu'elle **clôt l'examen**.

Vérifier qu'un test emprunte **la branche du service**, pas seulement qu'il passe au vert.

**Corollaire d'ordre — vérifier avant que l'objet devienne invérifiable.** Un secret enregistré
dans un champ Secure du fournisseur est masqué dès l'enregistrement ; toute confirmation ultérieure
ne peut plus porter que sur l'**existence de la ligne**, jamais sur son **contenu**. **Vérifier
avant que l'objet devienne invérifiable, ou ne pas prétendre vérifier.**

**Corollaire — choisir une valeur dont la justesse ne dépend pas de l'état où l'on est.** Ce
corollaire porte sur les **paramètres**, non sur les dispositifs. Il partage avec la règle
principale la structure du filet non testé, transposée : une valeur numérique dont la **justesse
n'est vérifiable que dans un état où l'on n'est pas** — l'état actif, l'état chargé, l'état
d'incident — est un paramètre qu'on ne peut pas éprouver au moment de l'écrire. Il n'interdit pas
d'agir : **il commande de choisir la valeur qui survit à l'activation future, et non celle qui
optimise l'état présent.** Un paramètre optimal pour l'état actuel qui deviendra faux au moment
où il servira réellement se comporte, à l'usage, comme un filet non testé : c'est en service
qu'on découvrira qu'il ne tenait pas — au pire moment, comme le dispositif principal de cette
sous-section.

### Une contrainte bien posée n'interdit pas, elle oriente — premier constat positif du §7

> Ajouté le **2026-09-09**. **Premier constat positif de ce §7** — non pas ce qui a trompé, mais
> ce qui a fonctionné, et qu'il faut savoir choisir. Un document qui ne recense que des échecs
> apprend la méfiance et jamais le choix. **Invalidée** le jour où le dépôt écrit ses
> autorisations d'opérations risquées sans budget de temps, sans exigence de stabilité, sans
> ordre de démantèlement, et sans relecture après coup.

**Le motif.** Une opération sur des ressources de production semblait exiger l'ouverture
temporaire d'un accès réseau. Nous l'avons autorisée, mais encadrée : budget de temps borné,
exigence de stabilité de l'adresse source, interdiction explicite d'élargir la règle si elle ne
correspondait pas, ordre de démantèlement imposé, relecture obligatoire après coup.
**L'opération a finalement réussi sans que l'accès réseau soit ouvert une seule seconde** — la
voie retenue écrivait depuis l'intérieur du périmètre.

> **Le résultat n'est pas « zéro exposition malgré les contraintes ». C'est « zéro exposition
> grâce à elles ».** En rendant l'ouverture coûteuse à obtenir et à tenir, nous ne l'avons pas
> rendue plus sûre : nous l'avons rendue assez chère pour qu'une meilleure voie soit cherchée —
> et trouvée.

**Contre-mesure — à la conception, et c'est là qu'elle se paie.**

> **Quand on autorise une opération risquée, encadrer n'est pas seulement se protéger de son
> échec — c'est en augmenter le prix, et donc financer la recherche d'une alternative qui n'en a
> pas besoin.** Une autorisation sans contrainte n'obtient jamais cette recherche : elle rend le
> chemin risqué gratuit, donc premier.

**Le rapport avec « Le dispositif de secours n'est éprouvé que hors incident » — deux faces d'un
même axe.** Là, un dispositif rassurait sans protéger : sa présence éteignait l'examen, et sa
première épreuve réelle ne devait avoir lieu qu'en situation dégradée. Ici, une contrainte a
protégé sans jamais être exercée : son coût a déclenché la recherche d'une voie qu'elle n'avait
pas besoin d'autoriser.

> **Ce qui distingue les deux n'est pas la prudence, c'est de savoir ce qu'un dispositif fait
> quand personne ne le regarde.** Un filet non testé fait moins que zéro — il finance une
> inaction ailleurs. Une contrainte bien posée fait davantage que ce qu'elle interdit — elle
> finance une recherche que rien d'autre ne rendait rentable.

**Corollaire — comment se mesure une contrainte bien posée.** Une contrainte qui n'est jamais
exercée n'est pas une contrainte inutile ; elle est au contraire le régime qu'on doit chercher.
Sa présence a modifié le calcul en amont, et ce qu'elle rend coûteux n'a pas été tenté. **On la
mesure non à ses interventions, mais à leur absence sur un chemin où l'on s'attendait à en
compter.**

### Un motif correct présent ne protège pas ses voisins — il les expose

> Ajouté le **2026-09-09**, dernier constat du lot. Famille **distincte** de celle des mécanismes
> dormants qui précède (les dix instruments vides, le filet non testé) : là où ceux-là sont
> **construits et jamais empruntés**, celui-ci est **construit, emprunté à un endroit, et non imité
> aux endroits qui ont le même besoin**. Sans cette distinction, un lecteur du §7 conclurait que
> « tout est construit mais éteint », alors qu'une part est **construite, allumée, et contredite
> ailleurs**.

**Le cas mesuré chez nous ce matin.** Une clé d'idempotence est fabriquée **correctement** dans un
contrôleur du dépôt — stable, réutilisée entre deux tentatives. Le même besoin est traité de
travers dans plusieurs fichiers voisins, où la clé est régénérée à chaque envoi. La bonne
implémentation n'a pas été **imitée** ; elle n'a pas non plus **appelé** l'examen qui l'aurait
révélé.

Les deux familles se distinguent par où se trouve le défaut :

- **Mécanisme dormant** — la bonne implémentation existe et **n'est pas appelée**.
- **Motif non suivi** — la bonne implémentation existe, **est appelée** ailleurs, et **n'a pas été
  imitée** au voisinage.

> **Un motif correct présent dans un fichier voisin ne protège pas les autres : il les expose.** Sa
> présence donne l'impression que le sujet est traité, **et éteint l'examen au lieu de l'appeler**.
> Un dépôt sans aucune implémentation correcte aurait été audité ; celui-ci ne l'a pas été **parce
> qu'il en avait une**.

**Contre-mesure, bon marché.** Quand on corrige une occurrence d'un motif, chercher ses frères
**par le besoin, pas par le symbole**. Un `grep` sur le nom de la variable trouve les copies ; il
ne trouve pas les endroits qui résolvent le même problème sous un autre nom. **La question utile
n'est pas « où ce symbole apparaît-il », mais « quels autres endroits ont ce besoin ».**

### Citer sans envoyer le lecteur au mauvais endroit

**Citez par titre de section et courte phrase entre guillemets, jamais par numéro de ligne.** Une
citation qui glisse ne devient pas invalide, elle devient **trompeuse** : elle désigne une ligne
réelle qui dit autre chose, et le lecteur en conclut que l'auteur s'est trompé sur le fond.

**Vérifiez que tout symbole cité existe.** Une session a écrit `validatePrivilegedWorkflows` ; la
fonction de `.github/scripts/backend-deploy-workflow-policy.mjs` s'appelle
**`validateNoncanonicalWorkflows`**. Un nom inventé mais plausible envoie chercher une modification
qui n'a jamais eu lieu — un coût qu'aucune relecture ne rattrape, puisque rien ne paraît faux.

**Ne pas croire les commentaires qui affirment une équivalence — les vérifier sur le code.** Le
2026-09-09, dans `codemagic.yaml`, deux traces écrites contredisent le YAML dans le **même
fichier** : le commentaire de l'ancre `step_setup_signing` **nomme explicitement le groupe requis**
— « stored as a SECURE variable in the `certigo_mobile_config` group » — à environ 340 lignes de
distance du workflow `ios-refresh-signing` qui l'ignore ; le commentaire de ce workflow affirme
« Same idempotent recipe as the build workflows » — faux, puisqu'il lui manque le bloc `groups:`
que les trois autres déclarent. C'est le **deuxième** commentaire faux relevé dans ce fichier en
24 h ; le premier concernait le reporting de statut GitHub par Codemagic et a été remplacé au
commit `36b5b873`.

> **Un commentaire décrit l'intention de son auteur, le code décrit l'exécution.** Quand un
> commentaire affirme une équivalence entre deux blocs — « même recette », « idempotent comme
> l'autre » — la vérifier sur le code plutôt que la croire.

**Un message d'erreur exact peut désigner une cause fausse.** Quand la variable n'est pas injectée,
l'outil Codemagic lève `Environment variable "X" is not defined`. Un lecteur cherche alors une
variable manquante côté fournisseur — **alors que la variable existe et que c'est le workflow qui
ne la demande pas**, faute d'avoir déclaré le groupe qui la porte. Le message est exact, et pointe
pourtant à l'opposé de la cause. **Une sortie exacte peut désigner une cause fausse dès qu'un
intermédiaire n'a pas été nommé** — ici : le groupe. À ranger avec les instruments qui mentent
sans mentir.

**Corollaire — un contrat de sérialisation nomme des clés, jamais des valeurs.** Un attribut qui
décrit comment se transforment les **noms** d'un objet (`camelCase`, snake ↔ camel, etc.) ne dit
rien sur les **valeurs** qu'ils portent. Les confondre fait diagnostiquer une incohérence de
contenu — « la valeur n'a pas la casse annoncée » — là où il n'y a que la lecture d'un contrat
côté clé comme s'il portait sur ce qu'il ne recouvre pas. La sortie est exacte et documentée ;
l'ensemble qu'elle décrit n'est pas celui qu'on interrogeait. **Avant d'accuser une valeur de ne
pas respecter une convention, vérifier que la convention porte bien sur des valeurs.**

### Un succès exact peut clôturer l'examen sur une cause fausse

> Ajouté le **2026-09-09**, à propos de la fusion de la PR #425 elle-même. Variante de « Un message
> d'erreur exact peut désigner une cause fausse » (ci-dessus), **plus difficile** : une erreur
> attire l'examen, un succès le clôt. **Invalidée** le jour où l'auto-merge de ce dépôt rebasse
> proactivement une PR passée en `BEHIND` sur `main`, ou porte un signal explicite lorsqu'il ne le
> fait pas.

**Le cas mesuré.** PR **#425** créée à `2026-09-09T11:30:18Z`, auto-merge **squash** armé à
`11:30:34Z`. Sur le premier HEAD, le rollup des checks requis est passé au vert dans les deux
minutes. **Aucune fusion n'a suivi.** La PR est restée `BEHIND` **34 min 6 s**. Un
`gh pr update-branch` manuel a fusionné `main` dans la branche (commit `423e3924` à `12:04:40Z`) ;
la CI a re-passé sur le nouveau HEAD (20 SUCCESS, 8 SKIPPED, 0 FAILURE), et la fusion a eu lieu à
`12:08:17Z` — 3 min 37 s après le rebase.

**Ce que le vert ne disait pas.** Le verdict « rollup requis vert » était une mesure **exacte**. Il
ne disait rien de la fraîcheur de la base sur laquelle la CI venait de tourner : `main` bougeait
pendant que la PR attendait. Sous `strict = true` — voir §1 « Un vert peut décrire une base qui
n'existe plus » — **chaque fusion sur `main` invalide silencieusement la base de toute PR non
fusionnée**. L'auto-merge n'a pas rebasé de lui-même ; rien n'a signalé que le vert affiché ne
portait plus rien de fusionnable.

**La différence avec le constat sur le message d'erreur.** Une erreur exacte pointe à côté, **mais
elle alerte**. Un succès exact ne déclenche aucun examen — il **clôt** la question, et il la clôt
d'autant mieux qu'il est vrai. C'est cette clôture qui rend la variante plus coûteuse : personne ne
va « vérifier le vert » ; le pont non nommé entre le vert et l'effet — ici, `strict = true` — reste
invisible aussi longtemps que l'effet est attendu et qu'il ne vient pas.

> **Quand un état vert n'aboutit pas à l'effet attendu, ne pas re-vérifier le vert — chercher
> l'étape que personne n'a nommée entre le vert et l'effet.**

**Corollaire opérationnel, à faible coût.** Après l'armement d'un auto-merge, `gh pr update-branch`
n'est pas un dépannage ; c'est une action de routine à prévoir dès qu'une PR reste `BEHIND` sans
progression, et à surveiller soi-même. Une PR verte avec auto-merge armé peut rester
**indéfiniment** en `BEHIND` sans que rien ne signale l'attente : l'inaction du fournisseur
ressemble à de la patience.

### Le cas limite des instruments qui mentent — un succès rendu par un canal qui ne mesure pas l'effet

> Ajouté le **2026-09-09**. À lire comme cas limite de la famille inventoriée sous « Les dix
> instruments vides », « Le rendu peut mentir sur la présence des données », « Le nom qui
> contredit l'état » et « Un succès exact peut clôturer l'examen sur une cause fausse ».
> **Invalidée** le jour où toute opération de configuration se conclut par une relecture de la
> valeur posée, et où le code de retour du canal d'écriture ne fait pas foi seul.

**Le motif.** Deux appels successifs, par deux voies différentes, ont modifié un réglage
d'infrastructure et **rendu un succès** — code de retour nul, réponse positive. Une relecture
immédiate a montré que la valeur n'avait pas changé : une politique d'organisation la réécrivait,
**après avoir accusé réception**.

**Ce cas constitue la limite de la famille.** Les instruments qui mentent, dans ce §7, se
trompent, se taisent, ou observent le mauvais objet. **Celui-ci confirme.** Ce n'est ni un refus,
ni un verrou, ni une erreur, ni un silence : l'instrument atteste une opération qui n'a pas eu
lieu.

> **Un succès rendu par un canal qui ne mesure pas l'effet n'est pas un succès de l'effet — il
> est un succès du canal.** Deux entités séparent l'appel de sa conséquence : la couche qui
> accuse réception, et la couche qui applique. Un succès n'atteste que la première ; croire qu'il
> atteste la seconde revient à demander à un instrument de mesurer un objet auquel il n'a pas
> accès.

**Ce qui a sauvé le script — la contre-mesure la moins chère du §7, appliquée à de
l'infrastructure.** Le script n'a survécu que parce qu'il **relisait** au lieu de croire le code
de retour. Le coût tient en un appel de plus.

**Corollaire.** Une opération qui a besoin d'un succès pour continuer doit relire elle-même
l'effet qu'elle attend, ou l'écrire dans une couche qui ne peut pas être réécrite après coup.
Sans l'un des deux, le succès reçu est un succès du canal, pas de l'effet.

### Trois obstacles se déclarent, un seul ment — et le quatrième est physique

> Ajouté le **2026-09-09**. **Invalidée** le jour où tout catalogue d'obstacles rencontrés
> distingue les catégories déclarantes des catégories mensongères, et nomme à part la catégorie
> physique.

**Le motif.** Une même opération a buté successivement sur quatre obstacles de natures
différentes : un pare-feu réseau, une politique à effet de réécriture, un verrou de suppression,
et une **indisponibilité de capacité dans la région**.

**La ventilation.** Trois des quatre ont refusé franchement — chacun avec un message qui nommait
la cause, ou du moins sa catégorie. **Une seule a menti** — la politique à effet de réécriture,
qui accuse réception avant de défaire. C'est le motif consigné sous « Le cas limite des
instruments qui mentent — un succès rendu par un canal qui ne mesure pas l'effet ».

> **La plupart des obstacles se déclarent, et c'est l'exception qui coûte cher.** Le §7 est
> tellement écrit autour des instruments qui mentent qu'il fait oublier ce rappel utile : la
> majorité des refus, on les lit.

**La quatrième catégorie est à part.** Un pare-feu se change, une politique se relit, un verrou
se lève. **Une indisponibilité de capacité dans la région n'est ni un droit, ni une
configuration, ni une politique — c'est une contrainte physique**, et aucune contre-mesure de ce
§7 ne la couvre parce qu'elle ne dépend de rien qu'on écrive.

> **Trois catégories d'obstacles se corrigent en modifiant ce qui est écrit ; la quatrième ne se
> corrige qu'en attendant, en changeant de région, ou en changeant de plan.** Elle n'appartient
> pas au même registre, et le confondre avec les précédentes fait chercher un correctif là où il
> n'y en a pas.

**Contre-mesure — à la lecture d'un incident, gratuite.** Avant de chercher ce qu'il faut
modifier, se demander si l'obstacle appartient aux trois catégories qui se déclarent, ou à la
quatrième. Si c'est la quatrième, aucune modification locale ne le lève.

### Ce qui a réellement corrigé

Une session a tiré ce bilan de sa propre journée :

> **« trois fois attrapé par un contrôle, zéro fois par la prudence ».**

**La prudence ralentit sans corriger.** Ce qui a fonctionné, chez tous les acteurs sans exception,
c'est **remesurer une chose qu'on croyait déjà savoir**. Le §1 le dit déjà d'un contrôle qui a pris
son propre auteur en défaut : « C'est la seule preuve réelle qu'un contrôle fonctionne — toute autre
confirmation revient à ce que l'auteur se donne raison à lui-même. »
