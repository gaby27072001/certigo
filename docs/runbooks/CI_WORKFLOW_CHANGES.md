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

### Préparation bornée post-self-seal : lint mobile et génération publique

La préparation initiale de `backend-deploy-workflow-policy.mjs` reconnaît six
transitions exactes, avec SHA256 **des octets source et cible** : `cd-backend.yml`, `release-android.yml`,
`release-ios.yml`, `ci-infra.yml`, `deploy-privacy-policy.yml` et
`publish-verified-public-pages.yml`. Les deux releases gardent leurs triggers, permissions,
secrets et déploiements ; seules les redirections groupées et la conservation des arguments
keychain iOS changent. Les trois jobs de génération (`bicep-build` ou `build`) utilisent
`ubuntu-24.04` ; les deux builds Pages réduisent `pages: write` à `pages: read`, épinglent
Node et le checkout sans credentials et interdisent l'activation implicite de Pages. Les
jobs de publication privilégiés restent inchangés. Ce n'est pas une allowlist générale de
workflows privilégiés ni un fallback de runner.

Le lot lint source est le patch SHA256
`84e93e57aa09444b25270ecafd045a3228a47a51583ac8578c46c09c43b1f8d5`.
Les cibles Android/iOS sont reconstruites en **LF** depuis ce patch, sans conversion
`core.autocrlf`. Les callers publics proviennent du commit
`a706caa8ad94d162d3a584a5ad39dbc0d8c04a6b`. Ces références désignent une préparation,
pas une adoption. Ces six paires d'empreintes sont littérales dans le code et les tests ;
la consolidation ci-dessous ajoute seulement les deux paires CodeQL/security-gate.

Le landing exige une préapprobation non expirée **déjà dans la trusted BASE**, son manifeste
valide, sa proposition régulière non symlink aux octets cibles exacts et le workflow source
exact. Le manifeste candidat ne peut ni accorder ni renouveler cette autorité. Une proposition
exacte est vérifiable avant cette approbation, mais ne donne aucune permission d'exécuter
le workflow. Après adoption, l'héritage n'accepte que les octets cibles exacts et leur état
BASE correspondant. Les autres contrôles (YAML, triggers, secrets, checkouts, caches,
permissions et runners des autres jobs) continuent tous de s'exécuter.

**Extension CD exacte à revoir explicitement.** La redirection groupée de `cd-backend.yml`
n'est ni l'objet A/A-hardened original, ni B. La préparation ajoute un seul delta legacy :
38056 octets, SHA256 `05287664503833f3c2e6f7daa4c20ff7cb38584de45dccb89f02aff9401fc516`,
depuis les 38066 octets A-hardened existants. L'inverse de la seule redirection groupée doit
reconstituer exactement A-hardened, dont la taille et l'empreinte existantes ne changent pas.
Cette version reste soumise à l'approbation préalable BASE et aux mêmes sémantiques de
déploiement A-hardened ; elle ne prétend pas satisfaire les garanties supplémentaires B.
Tout autre octet, source ou capacité retombe dans le refus strict B. Pour ce delta, les
entrées runtime/état/IaC, les contrôles de support et le document de capacité doivent tous
rester identiques à la BASE (ajouts et suppressions IaC compris). Les contrôles stricts B
qui n'existent pas dans la BASE legacy doivent rester absents des deux arbres ; leur
introduction n'est pas autorisée par le delta lint. Les contrôles stricts B
existants restent inchangés. Ce changement de contrat minimal est un nouveau diff à approuver :
l'accord sur le head original de PR #18 ne l'adopte pas.
La politique de PR #17 n'est ni importée ni implicitement autorisée ; seuls ses cinq
fichiers réseau finaux sont réutilisés comme prérequis de code distinct.

**Adoption de la consolidation : un seul bootstrap atomique à revoir.** Les états
code, préapprobation et consommation conservés dans l'historique démontrent les frontières
de confiance ; ils ne sont plus une route de fusions proposée. Ne pas adopter leurs cinq
erreurs lint historiques ni leurs références de sources intermédiaires périmées. Le lot
final contient simultanément les corrections lint, les vingt workflows hosted, l'activation
du garde JSON Checkov et sa référence de sources générée. Il doit passer ses contrôles locaux
comme arbre entier. Un seul merge du lot final installe cet arbre, pas chaque commit comme PR.
L'ancienne BASE refuse toujours ce bootstrap : conserver tous ses diagnostics et obtenir
l'accord humain sur le nouveau diff exact, sans les renommer succès ni étendre l'accord PR #18.
La décision et l'action GitHub appartiennent au propriétaire ; aucun override administrateur,
changement de settings, waiver scanner ou exécution Azure n'est implicite.

La simulation historique suivante explique les dépendances, **pas des étapes à adopter** :

1. Faire revoir explicitement le nouveau bootstrap de code : simplification self-seal,
   politique hosted réutilisée de PR #10, code Checkov de PR #19
   (`73f3138d444e6ee08fab606d32b760f02dfc52da`), builder public et les cinq fichiers réseau
   finaux de `2754545998ec0f1348bdc8e9d06dbb6870004726`, sans importer la politique PR #17.
   Dans cette simulation, le code précède les workflows. Le compare partiel `7821c4b1` n'est pas un prérequis.
   L'accord sur le head original de PR #18 ne couvre pas ce nouveau diff ; l'ancienne BASE
   refuse encore les deux scellés. Les workflows actifs restent ceux de la BASE : leurs
   cinq erreurs actionlint historiques restent présentes à ce stade, non dérogées.
   Cet ordre de préparation ne constitue donc pas une séquence de fusions déjà autorisée
   ou intégralement verte. Aucune preuve locale ne remplace les checks GitHub exécutés.
2. Préapprouver ensemble les vingt contenus futurs exacts, sans modifier les workflows actifs :
   six transitions initiales, deux scanners et douze consommateurs hosted réutilisés de PR #14.
   Cette simulation précédait l'activation du garde Checkov dans le lot atomique final. Les empreintes/golden sont des données
   de cette PR de préapprobation distincte, pas un rafraîchissement pour verdir le code policy.
   Ne jamais fabriquer un état `states` qui contredit les workflows actifs.
3. Consommer ensemble les vingt approbations déjà adoptées dans la BASE, sans changer leur
   périmètre. Le manifeste et les
   propositions sont consommés par les outils existants. Un assemblage préparatoire dépourvu
   d'approbation BASE doit rester refusé ; il ne s'auto-approuve pas. La combinaison du réseau
   et du nouveau CD sans installation préalable des cinq fichiers doit également être refusée
   par le contrôle des entrées privilégiées. Aucun nouveau SARIF ne prouve leur résolution CodeQL.

Cet ordre n'annonce ni capacité runner disponible, ni checks officiels verts, ni fusion.
Une préapprobation doit être recalculée et revue si les octets ou la source changent ; elle
ne se transpose pas à une combinaison arbitraire de patchs. Aucune modification de settings,
déploiement Azure, nouveau scan manuel ou changement de seuil CodeQL ne fait partie du lot.

### Contrôles communs

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

### Exception native Apple sans signature

`native-apple-check.yml` est l'exception Apple aux labels self-hosted :
`native-apple-workflow-policy.mjs` autorise son contenu exact par empreinte SHA-256
des octets, sans ajouter de runner à la liste globale. Contrairement aux empreintes
sémantiques du manifeste, cette exception refuse aussi les modifications de commentaires
et de fins de ligne. Toute évolution exige une revue du contrat de politique et le cycle
de pré-approbation A/B ; la pré-approbation seule ne modifie pas la politique.

Le workflow proposé utilise le runner standard `macos-15` et Xcode 26.3, uniquement sur
dispatch du propriétaire du dépôt personnel `gaby27072001/certigo`. Le champ
`candidate_sha` doit être un SHA complet de 40 caractères hexadécimaux minuscules :
aucune branche ni aucun tag n'est accepté. Le checkout est vérifié, sans credentials
persistants. Les tests SPM et le build simulateur iPhone/iPad sont sans signature,
sans environnement, secret, permission d'écriture, distribution ni publication.
Cela ne prouve ni une installation sur appareil physique ni la validité des accès Apple.

La fixture `.github/scripts/fixtures/native-apple-check.yml` rend les tests de politique
indépendants de la présence et de l'expiration de la proposition. Les runners standard
hébergés sont gratuits pour les dépôts publics selon
[la documentation GitHub](https://docs.github.com/en/actions/concepts/billing-and-usage).
Ne pas remplacer le label par un runner larger, ni utiliser ce workflow dans un dépôt privé.

### Rapports Checkov et couverture effective

`checkov_report_gate.py` est installé avec ses tests avant toute modification du workflow.
Cette installation seule ne change pas le scan actif. Lors de son intégration future,
`security-scan.yml` doit conserver le journal CLI et ajouter un rapport JSON du même scan,
contrôlé par ce script depuis les contrôles de la **base**.
Il refuse un code scanner non nul, un contrôle échoué, une erreur de parsing, un rapport
absent/malformé/incohérent et une couverture effective nulle. Un scan ne peut donc pas être déclaré
réussi uniquement parce que Checkov renvoie zéro malgré des erreurs de parsing.

Le résumé distingue le compteur de ressources du scanner et les identités fichier/ressource
ayant au moins un contrôle exécuté. Aucun des deux ne prouve à lui seul que chaque source a été
analysée, ni ne compte des ressources déployées uniques. Les exclusions existantes restent
inchangées ; ce garde-fou ne corrige pas le parseur Bicep et ne remplace pas son analyse par ARM.

Tester le garde-fou sans scanner, réseau ou Azure :

```powershell
python -m unittest discover -s .github\scripts -p test_checkov_report_gate.py -v
```

Son intégration suit la pré-approbation puis la consommation ci-dessus ; la présence du code
candidat et ses tests ne constituent ni une approbation par la base ni une preuve de CI verte.

### Indépendance des tests de la base

Ces tests tournent sur l'arbre de `main` à chaque PR. **Un test de base ne doit dépendre ni des
pré-approbations en attente sur `main`, ni des empreintes de production, ni de la date du jour** :
une PR qui pré-approuverait exactement la mutation qu'un test attend refusée, ou une évolution
légitime d'un workflow Cosmos que les fixtures codent en dur, ferait échouer ce test pour toutes
les PR dès sa fusion — le blocage de #497 sous une autre forme (trouvé en revue le 2026-09-23).
Concrètement : calculer le manifeste d'un fixture à partir de **ses propres** workflows
(`preApproved: {}`), passer `now` explicitement, et réserver le manifeste réel aux mutations
imprévisibles (nonce aléatoire). `account-deletion-cosmos-policy.test.mjs` montre les deux formes.

## Consolidation des contrôles PR sur runners hosted

La proposition consolidée réutilise la politique de #10 et les consommateurs de #14,
sans modifier leurs branches. Les vingt couples CI de `linux-ci-runner-policy.mjs`
acceptent `ubuntu-24.04`, avec permissions décodées read-only, sans secrets,
environnement ni identité cloud. Les restrictions de cache, fraîcheur et fork,
les contrôles trusted BASE et les tests candidats distincts restent obligatoires.
Les agrégats ne peuvent pas checkout ou lire le source PR.

Les sélecteurs et agrégats de `codeql.yml` et `security-gate.yml`, ainsi que
l'analyse CodeQL PR, rejoignent ce périmètre read-only. La transition de ces deux
workflows auparavant scellés exige leurs octets source et cible exacts et une
préapprobation active de BASE, via le helper existant. Ni un manifeste candidat,
ni les tests candidats, ni une mutation du workflow ne peuvent renouveler cette
autorité.

CodeQL ne reçoit plus `security-events: write` sur une PR : `analyze` garde la
configuration et l'enforcer de BASE, produit le SARIF local, applique le seuil
**7.0**, et utilise `upload: never`. Le job distinct `analyze-main` conserve la
publication SARIF uniquement sur push/schedule de `refs/heads/main`, avec les deux
checkouts fixés à `github.sha`. Ce job privilégié hosted n'est accepté que pour
le workflow exact préapprouvé, jamais comme permission générale de publication.
Le gate officiel choisit explicitement le résultat de l'analyse applicable.
Les deux analyses restent buildless, appliquent le même enforcer et ne dépendent
pas du stockage d'artefacts. Une PR n'alimente donc plus directement le tableau
GitHub Code scanning : son résultat bloquant est le gate SARIF local ; la
publication est faite par l'analyse de main après adoption.

Les simulations ordonnées code/BASE, préapprobation, consommation restent des preuves,
pas une route d'adoption des états intermédiaires. Le bootstrap de consolidation est
le lot final atomique décrit plus haut, soumis à une nouvelle décision humaine exacte ;
ni le manifeste candidat ni ces simulations ne l'autorisent. Les SDK, noms des
contextes officiels, déclencheurs, règles de scoring et filtres restent inchangés ;
seuls les anciens nettoyages de caches persistants Flutter de #14 sont retirés.
Les releases, signatures, déploiements et identités cloud restent séparés et ne
sont pas activés par cette migration. Aucune exécution CI/CodeQL, résolution de
findings, gratuité permanente ni capacité réelle des runners n'est déduite des
tests locaux. Le job Checkov exécute désormais les tests du garde Python de BASE, exige
le rapport JSON de la même invocation et refuse les erreurs de parsing, rapports absents,
malformés, périmés ou sans couverture effective, même si le scanner renvoie zéro. Le test
Bash du vrai script de workflow vérifie notamment que 22 erreurs de parsing font échouer
le job et qu'un rapport complet propre passe. Ce ne sont pas de nouveaux scans.
Les erreurs de parsing Checkov officielles restent ouvertes : compiler Bicep localement
n'est pas une preuve de couverture du scanner.

## Ce que ce mécanisme ne débloque pas

### Correction du répertoire d'extraction CodeQL

Le mode buildless du CodeQL Action épinglé lance `database trace-command --use-build-mode`
dans son `process.cwd()`, le workspace GitHub, même si `init` a reçu un autre `source-root`.
Un checkout source uniquement sous `.untrusted-source` peut donc laisser les autobuilders
JavaScript et C# sans source visible depuis ce répertoire. Le correctif place le source à la
racine du workspace, fixe `source-root: .` et aligne `UNTRUSTED_SOURCE_DIR`/`checkout_path`
sur cette même racine, pour PR et main. Le checkout des contrôles reste `.trusted-control`,
immuable sur BASE pour les PR et sur `github.sha` pour main ; sa seule exclusion de scan
existante reste inchangée. Après le checkout source et avant celui de BASE, une commande Node
inline du workflow supprime le chemin `.trusted-control` candidat sans suivre ses symlinks.
Le checkout épinglé initialise alors un nouveau dépôt et récupère le ref immuable, plutôt que
de préparer un éventuel dépôt ou lien fourni par la PR. Les fixtures fichier/répertoire/lien
vérifient le ref et le contenu de BASE ainsi que la conservation de la cible externe du lien.
Aucun langage, filtre de sélection, analyse ou seuil n'est retiré.

Le code de contrôle accepte temporairement les deux layouts cohérents afin de permettre une
PR A ordinaire sans changer le workflow actif. La transition CodeQL elle-même reste le seul
couple exact ancien/nouveau déclaré, avec proposition et préapprobation active dans BASE,
puis consommation séparée B. Les tests de layout utilisent de vrais fichiers JS et C# du
dépôt et deux checkouts ; ils ne constituent pas une extraction CodeQL réelle. La preuve
runtime viendra de l'exécution officielle après adoption, sans rerun manuel déduit de ce test.

- **Les workflows privilégiés restent figés à l'octet par défaut.** Hors `cd-backend.yml`
  et des seules transitions source/cible exactes préapprouvées décrites ci-dessus, un workflow qui
  porte `environment:`, `secrets.`, une permission `write`, `id-token: write` ou `azure/login@`
  (liste complète : `privilegedWorkflow` dans `backend-deploy-workflow-policy.mjs`) est refusé au
  moindre octet modifié, par la politique de la trusted BASE (voir
  `docs/GOVERNANCE.md`, « Workflow privilégié »). C'est le cas de `release-android.yml` : une
  montée de `FLUTTER_VERSION`, qui doit rester alignée entre `ci-mobile.yml`,
  `release-android.yml` et `codemagic.yaml`, **reste bloquée** : elle n'est pas le delta lint
  exact proposé. La politique est amendable par revue explicite, pas par auto-approbation.
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
