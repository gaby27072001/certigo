# Modifier un workflow GitHub Actions : pré-approuver, puis fusionner

> **Fait daté.** Procédure en place depuis le 2026-09-23 (#497). **Invalidée si**
> `validate-workflow-security.mjs` cesse d'appeler `validateCandidateWorkflowManifest`, si
> `Validate workflow YAML` cesse d'être un contexte requis de `main`, ou si le validateur cesse de
> lire le manifeste de la **base** plutôt que celui de la PR.

## En une phrase

Tout changement de `.github/workflows/` passe par **deux pull requests** :

1. **PR A — la pré-approbation.** Elle ne modifie aucun workflow. Elle montre le **contenu exact**
   du futur workflow dans `.github/workflows-proposed/` et inscrit son empreinte dans le manifeste,
   avec une date d'expiration.
2. **PR B — la fusion.** Une fois A sur `main`, elle applique ce contenu et **consomme**
   l'approbation : le manifeste passe à la nouvelle empreinte, l'approbation et la proposition
   disparaissent.

`main` décrit ses propres workflows **après chacune des deux fusions**. C'est ce qui manquait.

## Pourquoi deux PR, et pourquoi pas l'ancien remède

Le job requis `Validate workflow YAML` (`lint-workflows.yml`) exécute le validateur de la **base**
(`.trusted-control`) et lit **son** manifeste, jamais celui de la PR. Une PR ne peut donc pas
approuver son propre changement de workflow : c'est voulu, et c'est conservé.

Jusqu'au 2026-09-23, le seul chemin annoncé par le validateur était destructeur : faire tourner les
`states` du manifeste dans une première PR, puis changer le workflow dans une seconde. Entre les
deux, `main` portait un manifeste qui contredisait ses propres workflows ; l'étape
`Test workflow security scripts` (exécutée sur l'arbre de la base, à chaque PR) et le validateur
lui-même refusaient alors **toutes** les PR, y compris celle censée réparer. Mesuré, voir « Preuves ».

La pré-approbation n'écrit pas l'empreinte future **à la place** de l'actuelle, mais **à côté** :
l'empreinte actuelle reste dans `states`, l'empreinte future attend dans `preApproved`.

## Procédure

Prérequis : Node **20.20.2** (la version épinglée par `lint-workflows.yml`) et `npm ci --ignore-scripts`
à la racine.

### PR A — pré-approuver (aucun workflow modifié)

```bash
git switch -c ci-preapprove-<sujet> origin/main
# 1. Écrire le changement voulu dans .github/workflows/<nom>.yml, puis :
node .github/scripts/generate-workflow-semantic-manifest.mjs --pre-approve   # [--expires-in-days 1..30], défaut 14
# 2. Restaurer le workflow : la PR A ne doit en modifier aucun.
git restore .github/workflows
# 3. Reporter dans .github/scripts/account-deletion-cosmos-policy.test.mjs la valeur de
#    manifestGoldenDigest affichée par le générateur, puis vérifier :
node .github/scripts/generate-workflow-semantic-manifest.mjs --check
```

Committer **le manifeste, `.github/workflows-proposed/<nom>.yml` et le golden digest**, rien d'autre
côté CI. Pour relire la PR A comme un diff du workflow :

```bash
git diff --no-index .github/workflows/<nom>.yml .github/workflows-proposed/<nom>.yml
```

Coller ce diff dans le corps de la PR A : c'est lui qu'on approuve.

### PR B — fusionner (après la fusion de A)

```bash
git switch -c ci-<sujet> origin/main
cp .github/workflows-proposed/<nom>.yml .github/workflows/<nom>.yml
node .github/scripts/generate-workflow-semantic-manifest.mjs --write   # consomme l'approbation, supprime la proposition
# Reporter le nouveau manifestGoldenDigest, puis :
node .github/scripts/generate-workflow-semantic-manifest.mjs --check
```

Les commentaires YAML sont libres : l'empreinte porte sur l'arbre YAML décodé, pas sur les octets.
Tout autre écart avec la proposition est refusé.

`.github/workflows` est une source observable de `tools/project_state.py` : la PR B doit en général
régénérer l'état du projet. Committer d'abord, puis `python -P tools/project_state.py --refresh-reference`
dans un **commit de tête séparé** (voir `docs/GOVERNANCE.md`).

### Ajouter ou retirer un workflow

- **Ajout** : créer le fichier, `--pre-approve`, puis supprimer le fichier avant de committer A. La
  proposition est créée comme pour une modification ; B ajoute le fichier et lance `--write`.
- **Retrait** : supprimer le fichier, `--pre-approve` (l'empreinte approuvée vaut `null`, aucune
  proposition), puis `git restore`. B supprime le fichier et lance `--write`. Avant A, chercher le
  nom du fichier dans `.github/scripts/` : un script qui le cite encore fait refuser A et B.

## Ce que la CI vérifie

Tout est exécuté par le code de la **base**, sur l'arbre de la PR, dans `Validate workflow YAML`.

| Contrôle | Code | Refuse |
|---|---|---|
| Chaque workflow porte l'empreinte de `states` **ou** celle d'une pré-approbation non expirée **de la base** | `account-deletion-cosmos-policy.mjs` | Tout changement de workflow non pré-approuvé sur `main`, y compris une PR unique qui s'approuverait elle-même |
| Le manifeste de la PR est exactement le rendu canonique de **ses propres** workflows | `workflow-manifest-consistency.mjs` | L'ancien remède (`states` tournés sans le workflow) ; une approbation atteinte mais non consommée |
| Chaque approbation en attente a sa proposition, et la proposition a exactement l'empreinte approuvée | idem | Une approbation « aveugle », une proposition retouchée, une proposition orpheline |
| `manifestGoldenDigest` égale l'empreinte du manifeste de la PR | idem | L'oubli du golden, qui aurait fait rougir `main` sur ses propres tests |
| Une approbation ajoutée ou modifiée par la PR expire entre aujourd'hui et +30 jours (UTC) | idem | Une approbation permanente |
| Les règles de sécurité par fichier s'appliquent aussi aux propositions | `validate-workflow-security.mjs` | Une approbation que la PR B se verrait refuser |
| Un workflow retiré n'est plus cité par `.github/scripts/*.mjs` | `workflow-manifest-consistency.mjs` | Un retrait qui casserait les tests de `main` après fusion |
| Les labels `runs-on` sont vérifiés sur le YAML **analysé**, en plus de la règle par ligne | `workflow-runner-labels.mjs` | `"runs-on": [self-hosted, Linux, X64]`, qui échappait à la règle par ligne et pouvait viser un runner de confiance |
| Chaque contexte requis (listé dans `branch-protection-main.json` de la base **et** de la PR) reste publié par un job `pull_request_target` non filtré, nommé exactement, sans matrice ni appel réutilisable — aujourd'hui **et** dans l'état futur de chaque pré-approbation en attente | `required-context-policy.mjs` | Un renommage de job requis, un retrait de déclencheur, un filtre de chemins au niveau du workflow : tout ce qui ferait attendre un contrôle requis indéfiniment |
| L'empreinte refuse les chaînes YAML contenant un retour chariot décodé ou non NFC | `workflow-semantic-fingerprint.mjs` | Deux contenus qui s'exécutent différemment sous la même empreinte (`"# x\rcurl …"` est un commentaire bash, `"# x\ncurl …"` exécute `curl`) |

**Le temps ne fait jamais rougir une PR sans rapport.** Seule l'acceptation d'un workflow modifié
dépend de la date. Une approbation expirée n'autorise plus rien ; elle reste inerte tant qu'une PR
ne la retire pas (`--write` retire les approbations expirées et leurs propositions).

**Limite connue : l'expiration est vérifiée quand le contrôle tourne, pas au moment de la fusion.**
GitHub ne relance pas un contrôle vert parce que le temps passe : une PR B validée la veille de
l'expiration reste fusionnable après, tant que `main` n'a pas bougé (avec `strict: true`, tout
mouvement de `main` impose une mise à jour, donc un nouveau contrôle). Le contenu fusionné reste
exactement celui qui a été approuvé ; seule la borne temporelle est lâche.

**La file de fusion (merge queue), qui la fermerait, est impossible sur ce dépôt** (vérifié le
2026-09-24). Source (`github/docs`, `data/reusables/gated-features/merge-queue.md`) : *« Pull
request merge queues are available in any public repository owned by an organization, or in
private repositories owned by organizations using GitHub Enterprise Cloud. »* Certigo est privé
et appartient à un compte utilisateur (`owner.type: User`). Même dans une organisation, il
faudrait ajouter `merge_group` à `codeql.yml` et `security-gate.yml`, figés à l'octet, et
`merge_group` exécute le workflow du commit de la file, c'est-à-dire la version de la PR, à
rebours de l'architecture `pull_request_target`. On garde donc `strict: true` et la fusion
automatique. **Borne de l'écart** : ce qui fusionne après l'expiration est exactement le contenu
approuvé, jamais un autre ; et l'écart se referme au premier mouvement de `main`.

## Règle pour les tests de `.github/scripts`

Ces tests tournent sur l'arbre de `main` à chaque PR. **Un test de base ne doit dépendre ni des
pré-approbations en attente sur `main`, ni des empreintes de production, ni de la date du jour** :
une PR qui pré-approuverait exactement la mutation qu'un test attend refusée, ou une évolution
légitime d'un workflow Cosmos que les fixtures codent en dur, ferait échouer ce test pour toutes
les PR dès sa fusion — le blocage de #497 sous une autre forme (trouvé en revue le 2026-09-23).
Concrètement : calculer le manifeste d'un fixture à partir de **ses propres** workflows
(`preApproved: {}`), passer `now` explicitement, et réserver le manifeste réel aux mutations
imprévisibles (nonce aléatoire). `account-deletion-cosmos-policy.test.mjs` montre les deux formes.

## Ce que ce mécanisme ne débloque pas

- **Les workflows privilégiés restent figés à l'octet.** Hors `cd-backend.yml`, un workflow qui
  porte `environment:`, `secrets.`, une permission `write`, `id-token: write` ou `azure/login@`
  (liste complète : `privilegedWorkflow` dans `backend-deploy-workflow-policy.mjs`) est refusé au
  moindre octet modifié, par une règle scellée qu'aucune PR ne peut amender (voir
  `docs/GOVERNANCE.md`, « Workflow privilégié »). C'est le cas de `release-android.yml` : une
  montée de `FLUTTER_VERSION`, qui doit rester alignée entre `ci-mobile.yml`,
  `release-android.yml` et `codemagic.yaml`, **reste bloquée** par ce scellé-là.
- **Ne jamais renommer un job dont le nom est un contexte requis** (`Flutter app + UI packages`,
  `Build & test`, `Validate workflow YAML`, …) : la protection de `main` attendrait un contexte
  que plus aucun workflow ne produit. C'est désormais refusé automatiquement, dès la PR A
  (`required-context-policy.mjs`) ; retirer un contexte requis exige d'abord de changer la
  protection de branche, puis `branch-protection-main.json`. Chaque pré-approbation en attente est
  jugée seule contre les workflows courants : déplacer un contexte requis d'un workflow à un autre
  prend donc deux cycles — ajouter d'abord le nouveau job producteur, retirer ensuite l'ancien.
- Les deux workflows Cosmos de cycle de vie (`test-account-deletion-cosmos.yml`,
  `post-merge-cosmos-account-deletion.yml`) restent régis par le contrat A/B/C de
  `docs/ACCOUNT_DELETION.md` : leur **contenu** peut être pré-approuvé, jamais leur retrait, et la
  PR B reste soumise au contrat exact que le code de la base impose à ces fichiers
  (`account-deletion-cosmos-policy.mjs`). Un changement de ce contrat passe donc d'abord par une
  PR de code qui accepte l'ancienne et la nouvelle forme — elle peut porter la pré-approbation.

## Un workflow modifié ne s'exécute pas dans sa propre PR

### Migration vers le dépôt personnel

Pour les changements de code et workflows non privilégiés, appliquer le
[fonctionnement solo](../GOVERNANCE.md#fonctionnement-solo-du-dépôt-personnel) :
revue technique indépendante, décision explicite du propriétaire sur la
proposition exacte et gates A/B inchangées. Cette politique source n'est pas
une autorisation de protection live ni une exception aux scellés de CD.

La migration de `gchambaud_microsoft/Certigo` vers `gaby27072001/certigo`
ne constitue pas une pré-approbation de workflow ou de confiance Azure.
Le validateur Cosmos accepte temporairement les deux **conjonctions exactes**
de propriétaire, chacune conservant `workflow_dispatch`, `main`, le flag
d'activation et le runner dédié. Une disjonction entre propriétaires, un fork
ou une condition moins restrictive reste interdit. Le manifeste trusted doit
encore autoriser le contenu exact avant qu'il puisse être appliqué.

Procéder dans cet ordre : fusion revue du contrat compatible de validation,
PR A avec proposition du nouveau propriétaire, puis PR B appliquant exactement
cette proposition. Ne pas modifier l'empreinte active pour rendre verte la
première PR. La même séquence s'applique à la version SDK du gate Cosmos ;
elle n'autorise pas à changer un workflow privilégié scellé à l'octet.

L'autorisation du dispatch backend utilise uniquement le dépôt personnel
canonique. Elle continue d'exiger un opérateur humain autorisé et un reviewer
indépendant empêchant l'auto-approbation. Ce contrôle n'enregistre aucun runner,
ne crée aucun Environment et ne modifie aucune fédération OIDC. Établir les
protections et vérifier leur fonctionnement avant d'ajouter un sujet OIDC exact
du nouveau dépôt ; ne retirer l'ancien qu'après preuve et approbation.

### Prérequis de fusion de la cible backend .NET 10

Le changement des `TargetFramework` ne met pas à jour les workflows actifs.
Le gate backend doit installer le SDK .NET 10 approuvé et, après la restauration
de la solution, restaurer directement `src/Certigo.Api/Certigo.Api.csproj` :
le hook de `Azure.Functions.Sdk` restaure ainsi le projet d'extensions généré.
L'absence de ce hook peut être masquée par un répertoire `obj` existant ; la
preuve CI doit donc venir d'un checkout propre.

L'évolution du pin Cosmos exige d'abord un contrat de validation compatible
avec les deux pins exacts, puis les PR A/B. Le pin du CD privilégié reste soumis
à son propre scellé : aucune mise à jour de manifeste ni de documentation ne
constitue une autorisation de le remplacer. Ne pas fusionner la cible .NET 10
avant que les workflows requis puissent la compiler ; ne pas promouvoir son
artefact avant la validation et l'approbation de la transition du runtime Flex.

Le contrat du one-shot Cosmos accepte uniquement les deux formes identiques
dont le pin SDK est `8.0.424` ou `10.0.401`. La pré-approbation trusted reste
requise pour changer le workflow actif. Aucune version flottante, option
prerelease, modification de commande ou nouvelle permission n'est autorisée
par cette compatibilité. Le workflow legacy archivé reste inchangé.

Les workflows de PR sont chargés depuis `main` (`pull_request_target`) : la PR B tourne avec
l'**ancien** workflow, et ses nouvelles étapes n'agissent qu'après la fusion. Une étape cassée dans
un job requis ne peut alors être réparée que par une PR… jugée par l'étape cassée.

- Si le workflow déclare `workflow_dispatch`, **prouver B avant de fusionner** : pousser la branche,
  puis `gh workflow run <nom>.yml --ref <branche>`. GitHub exécute alors le fichier de la branche.
- Sinon, reproduire les commandes de l'étape à la main, sur la version d'outil épinglée.

## Avant de fusionner A ou B : simuler l'arbre entier

Depuis le 2026-09-24, le job `Candidate workflow security script tests` exécute les tests
`.github/scripts` **de votre PR** sur son propre arbre, et le contrôle requis
`Validate workflow YAML` échoue s'ils échouent. Il ne remplace pas la simulation ci-dessous pour
une PR B, dont le workflow modifié ne s'exécute qu'après la fusion.

Le validateur seul ne suffit pas : c'est ainsi que l'ancien remède a paru sûr (#497). Pour chaque
état de `main` que la séquence produit, monter **l'arbre entier** de la base en contrôle trusted et
lancer **la suite complète**, avec Node 20.20.2 et `GITHUB_OUTPUT` positionné :

```bash
# base = main tel qu'il sera ; candidat = la PR suivante
node "$BASE/.github/scripts/validate-workflow-security.mjs" --workspace "$CANDIDAT"
(cd "$BASE" && npm ci --ignore-scripts && node --test .github/scripts/*.test.mjs)
```

Le test `a workflow change lands through a pre-approval without ever leaving main inconsistent`
(`workflow-manifest-consistency.test.mjs`) rejoue cette séquence sur des workflows synthétiques ;
il ne remplace pas la simulation du vrai changement.

## Preuves (#497)

Mesuré le 2026-09-23, par simulation avant toute exécution réelle : Linux, **Node 20.20.2** (la
version de `lint-workflows.yml`), **arbre entier** de la base monté en `.trusted-control`,
`npm ci --ignore-scripts`, validateur de la base contre l'arbre de la PR, puis
`node --test .github/scripts/*.test.mjs` sur la base. Le changement simulé est le vrai changement
de `ci-mobile.yml` de #496 (tests `prism_ui`), pré-approuvé et fusionné avec le vrai générateur.

**Avant**, sur `main` `d0ce2638`, l'ancien remède :

| Base | PR jugée | Validateur | `node --test` de la base |
|---|---|---|---|
| `main` | PR unique (workflow + manifeste + golden) | ❌ refusée | ✅ 205/205 |
| `main` | remède 1/2 (`states` tournés, workflow inchangé) | ✅ acceptée | ✅ 205/205 |
| `main` + remède 1/2 | remède 2/2 (le workflow) | ✅ | ❌ **202/205** (A, B, C) |
| `main` + remède 1/2 | PR sans rapport | ❌ **refusée** | ❌ **202/205** |

**Après**, sur `main` `ccca0412`, avec la version finale de la PR 0 (deux passes de relecture comprises) :

| État de `main` | PR jugée | Validateur | `node --test` de la base |
|---|---|---|---|
| `main` | **PR 0** (ce mécanisme) | ✅ acceptée | ✅ 205/205 |
| `main` | PR sans rapport | ✅ | ✅ 205/205 |
| `main` + PR 0 | PR sans rapport | ✅ | ✅ 225/225 |
| `main` + PR 0 | **ancien remède destructeur** | ❌ **refusé** par la garde de cohérence | ✅ 225/225 |
| `main` + PR 0 | PR unique (auto-approbation) | ❌ refusée | ✅ 225/225 |
| `main` + PR 0 | **A** (pré-approbation) | ✅ | ✅ 225/225 |
| `main` + PR 0 + A | PR sans rapport | ✅ | ✅ 225/225 |
| `main` + PR 0 + A | **B** (fusion) | ✅ | ✅ 225/225 |
| `main` + PR 0 + A | autre modification, non approuvée | ❌ refusée | ✅ 225/225 |
| `main` + PR 0 + A + B | PR sans rapport | ✅ | ✅ 225/225 |
| `main` + PR 0 + A + B | nouvelle modification sans pré-approbation | ❌ refusée | ✅ 225/225 |
| `main` + PR 0 + A (`release-android.yml`) | B (`release-android.yml`, privilégié) | ❌ refusée par le scellé | ✅ 225/225 |

`npm run test:ci-impact` (étape trusted de `ci-preflight.yml`) : 51/51 sur chaque ligne. Après B,
le manifeste ne porte plus aucune pré-approbation et `.github/workflows-proposed/` est vide.
