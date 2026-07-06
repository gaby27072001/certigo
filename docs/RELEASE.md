# Processus de release — Certigo

> Lot de migration : **wp-p0-07-github-branch-protection-release** (Phase 0).
> Ce document **formalise et consolide** le processus de release du monorepo Certigo
> (backend .NET + mobile Flutter + infra). Le processus est **déjà appliqué** (tags
> `v1.0.0`, `v1.0.1`, `v1.0.2` présents). Ce fichier unifie les conventions et renvoie aux
> runbooks détaillés existants.
>
> Voir aussi : [`GOVERNANCE.md`](./GOVERNANCE.md) (protection de `main`),
> [`RELEASE_MOBILE.md`](./RELEASE_MOBILE.md) (détails mobile),
> [`deployment-runbook.md`](./deployment-runbook.md) (détails backend/infra).

---

## 1. Principes

- **Versionnage : [SemVer](https://semver.org/lang/fr/)** — `MAJOR.MINOR.PATCH`.
- **Point de release = un tag `v<version>` annoté, posé sur `main`** (ex. `v1.0.2`).
  - `main` étant protégée (cf. `GOVERNANCE.md`), la version releasée provient toujours
    d'un commit mergé via PR approuvée + checks verts.
- **Un seul numéro de version produit** partagé (source : `apps/mobile/pubspec.yaml`
  pour le mobile ; le backend est déployé en continu par environnement — cf. §4).
- **Traçabilité** : chaque tag `v*` déclenche automatiquement la release mobile (§3).

---

## 2. Convention de tags & changelog

### Tags

```bash
# Depuis main à jour, après merge de la PR de release :
git checkout main && git pull --ff-only
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

- Format strict : `v` + SemVer (`v1.2.3`). Le workflow `release-android.yml` filtre sur
  `tags: [ "v*" ]`.
- Tags **annotés** (`-a`) obligatoires (portent l'auteur, la date et le message).

### Changelog

- **Convention recommandée** : [Keep a Changelog](https://keepachangelog.com/fr/) +
  [Conventional Commits](https://www.conventionalcommits.org/fr/) pour dériver les entrées.
- ⚠️ **État actuel** : pas de `CHANGELOG.md` à la racine. **Recommandation** (hors périmètre
  de durcissement de ce lot) : ajouter `CHANGELOG.md` et une section par version au moment
  de poser le tag, OU générer les *Release Notes* GitHub à partir des PR mergées
  (`gh release create v1.2.3 --generate-notes`).

---

## 3. Release mobile (Flutter)

**Workflow** : [`.github/workflows/release-android.yml`](../.github/workflows/release-android.yml)
(Android / Google Play). iOS : voir [`RELEASE_MOBILE.md`](./RELEASE_MOBILE.md)
(TestFlight via Codemagic ; `release-ios.yml` conservé à titre historique).

| Élément | Valeur |
| --- | --- |
| Déclencheurs | push d'un tag `v*` **ou** `workflow_dispatch` (manuel) |
| Gates bloquants | `flutter analyze` + `flutter test` |
| Approbation humaine | environnement GitHub **`beta`** (reviewers requis à configurer) |
| Runner | self-hosted `certigo-ci` |
| `versionName` | saisi, sinon lu depuis `apps/mobile/pubspec.yaml` |
| `versionCode` | saisi, sinon `github.run_number` (auto-incrémenté) |
| Package | `com.certigo.mobileapp` |
| Secrets | Azure Key Vault (repli : secrets GitHub) |

**Lancer une release mobile** :

```bash
# Option A — par tag (recommandé, aligne mobile + point de version) :
git tag -a v1.2.3 -m "Release v1.2.3" && git push origin v1.2.3

# Option B — manuel (dry-run possible : build AAB signé sans publier) :
gh workflow run release-android.yml \
  -f track=internal -f version_name=1.2.3 -f dry_run=true
```

> Détails complets (signature, tracks Play, Key Vault, iOS/Codemagic) :
> [`RELEASE_MOBILE.md`](./RELEASE_MOBILE.md).

---

## 4. Release backend (.NET / Azure Functions)

Le backend suit un modèle **CD par environnement** (pas un tag applicatif) :

| Workflow | Rôle | Déclencheur | Garde |
| --- | --- | --- | --- |
| [`cd-backend.yml`](../.github/workflows/cd-backend.yml) | Déploie `dev` | `push` sur `main` (auto), `workflow_dispatch`, `workflow_call` | environnement `dev` |
| [`promote-backend-staging-prod.yml`](../.github/workflows/promote-backend-staging-prod.yml) | Promotion `staging` → `prod` | `workflow_dispatch` (manuel) | environnements `staging` puis `prod` (chaînés, `needs`) |

- **`dev`** : déploiement automatique à chaque merge sur `main` (via `cd-backend.yml`,
  OIDC + Bicep + `func` zip-deploy, runners self-hosted `certigo-ci`).
- **`staging` → `prod`** : promotion **manuelle et chaînée** (`deploy-prod` dépend de
  `deploy-staging`), chaque étape franchissant la *gate* d'environnement GitHub
  correspondante.

**Promouvoir le backend** :

```bash
gh workflow run promote-backend-staging-prod.yml
```

> Détails infra/déploiement (OIDC, Bicep, runners, RBAC) :
> [`deployment-runbook.md`](./deployment-runbook.md).

---

## 5. Checklist de release E2E

> Sert de base au lot **wp-p0-08** (release E2E taggée). À dérouler pour une release
> coordonnée backend + mobile.

1. **Pré-vol**
   - [ ] `main` à jour, PR de release mergée (revue + checks verts).
   - [ ] CI verte : `Build & test` (backend) + `Flutter app + UI packages` (mobile).
   - [ ] Version décidée (SemVer) et reflétée dans `apps/mobile/pubspec.yaml`.
   - [ ] Notes de version / changelog préparés.
2. **Backend**
   - [ ] `dev` déployé (auto au merge) et sain.
   - [ ] `gh workflow run promote-backend-staging-prod.yml` → valider *gate* `staging`,
         puis *gate* `prod`.
3. **Point de version (tag)**
   - [ ] `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`.
   - [ ] `gh release create vX.Y.Z --generate-notes` (optionnel mais recommandé).
4. **Mobile**
   - [ ] Le tag `v*` déclenche `release-android.yml` → valider la *gate* `beta`.
   - [ ] iOS : lancer/valider la release TestFlight (Codemagic — cf. `RELEASE_MOBILE.md`).
5. **Post-release**
   - [ ] Vérifier santé backend (`/api/health`) et publication mobile.
   - [ ] Consigner la version et l'horodatage (registre / changelog).

---

## 6. Pré-requis de gouvernance

Toute release part de `main`, qui est **protégée** : PR + ≥ 1 revue + checks stricts, pas de
push direct. Voir [`GOVERNANCE.md`](./GOVERNANCE.md). Les durcissements en réserve
(`enforce_admins`, `require_code_owner_reviews`, résolution des conversations) y sont
documentés et applicables par un admin.
