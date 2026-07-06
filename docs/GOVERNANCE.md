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
| Contextes requis | `Build & test`, `Flutter app + UI packages` | ✅ |
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

### Conclusion DoD

Le **cœur de la DoD est SATISFAIT** : `main` exige une PR avec **≥ 1 revue**, des **checks
stricts** (`Build & test` + `Flutter app + UI packages`) et **interdit le push direct**
(`allow_force_pushes=false` + revue obligatoire ⇒ pas de `git push` direct sur `main`).

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
> Le lot wp-p0-07 **ne mute pas** la protection en live (choix délibéré : un changement à
> privilèges admin n'est pas capturé dans une PR *reviewable* et pourrait perturber
> l'orchestration). L'état cible est **versionné** dans
> [`.github/branch-protection-main.json`](../.github/branch-protection-main.json) et
> s'applique par la procédure suivante.

### Fichier de capture ré-appliquable

[`.github/branch-protection-main.json`](../.github/branch-protection-main.json) contient
l'**état cible durci** : identique à l'actuel, mais avec
`enforce_admins = true`, `require_code_owner_reviews = true` et
`required_conversation_resolution = true`.

### Procédure pas-à-pas (admin)

1. **Pré-requis** : être **admin** du dépôt ; `gh` authentifié
   (`gh auth status` → scope `repo` / admin). Le fichier `CODEOWNERS` doit être mergé sur
   `main` **avant** d'activer `require_code_owner_reviews`.
2. **Dry-run / revue** de l'état actuel (lecture seule) :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/branches/main/protection \
     -H "Accept: application/vnd.github+json"
   ```

3. **Appliquer l'état cible durci** (idempotent — rejoue l'ensemble de la protection) :

   ```bash
   gh api --method PUT \
     repos/gchambaud_microsoft/Certigo/branches/main/protection \
     -H "Accept: application/vnd.github+json" \
     --input .github/branch-protection-main.json
   ```

4. **Vérifier** :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/branches/main/protection \
     --jq '{admins:.enforce_admins.enabled, code_owners:.required_pull_request_reviews.require_code_owner_reviews, convo:.required_conversation_resolution.enabled, checks:.required_status_checks.contexts}'
   ```

   Attendu : `admins=true`, `code_owners=true`, `convo=true`,
   `checks=["Build & test","Flutter app + UI packages"]`.

> **Rollback** : rejouer l'étape 3 avec une variante du JSON remettant les champs concernés
> à `false` (ou restaurer l'état antérieur capturé à l'étape 2).

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

Toutes applicables en une seule commande via
`gh api --method PUT … --input .github/branch-protection-main.json` (voir §4).
