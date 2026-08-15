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
Les jobs Azure OSV, NuGet et Checkov écrivent leurs diagnostics et résultats structurés non
secrets dans les logs immutables du job et une synthèse dans `GITHUB_STEP_SUMMARY`. Leur
conclusion dépend uniquement du statut scanner, des findings et de la validité de la sortie,
jamais du quota de stockage d'artefacts. Les forks ne sont pas supportés : la gate de confiance
chargée depuis `main` échoue sans checkout, tandis qu'aucun workflow contrôlé par le fork ne peut
atteindre le pool Azure persistant.

La gate `Generated state equals committed state` accède au dépôt privé `certigo-content`
uniquement avec la deploy key SSH en lecture seule stockée dans le secret Actions
`CERTIGO_CONTENT_DEPLOY_KEY`. Le workflow refuse une clé absente, impose la vérification stricte
des clés hôte `github.com` épinglées et n'accepte aucun PAT ni GitHub App en fallback. La
validation de la PR est exécutée sans secret par le générateur du SHA de base ; le job qui
installe la deploy key n'exécute ensuite que du code provenant du contrôle de base ou du dépôt
de contenu approuvé.

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
      peuvent exécuter leur SHA de tête sur le pool Azure `certigo-ci`.
- [ ] Supprimer le secret `AUTOMERGE_TOKEN`, révoquer le PAT correspondant et
      désactiver **Allow auto-merge** si aucun autre usage gouverné ne le justifie.
- [ ] Protéger l'environnement `beta` avec reviewers obligatoires, interdiction
      d'auto-approbation et branches/tags de déploiement limités à `main` et
      `v*`. Stocker ses secrets de signature/publication dans cet environnement.
- [ ] Protéger `staging` et `prod` avec reviewers obligatoires, interdiction
      d'auto-approbation et déploiement limité à `main`. Conserver les secrets
      OIDC `AZURE_*` au niveau environnement, pas au niveau dépôt.
- [ ] Créer un ruleset de tags `v*` interdisant suppression et modification, et
      limitant la création aux mainteneurs de release.
- [ ] Dans `certigo-content`, enregistrer la clé publique comme **Deploy key** sans
      `Allow write access`, puis stocker la clé privée correspondante dans le secret
      Actions `CERTIGO_CONTENT_DEPLOY_KEY` de Certigo. Aucun PAT/App ou réglage
      Enterprise ne fait partie de ce contrôle.

Les mises à jour de versions de `.github/dependabot.yml` restent une aide de maintenance.
La décision de sécurité repose exclusivement sur les gates Azure bloquantes OSV, NuGet,
Checkov et CodeQL, sans activation de fonctionnalité Enterprise.

Ces réserves ne doivent pas être appliquées implicitement avec le JSON complet. Les traiter
séparément, avec revue admin et lecture préalable de l'état live.
