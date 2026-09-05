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
