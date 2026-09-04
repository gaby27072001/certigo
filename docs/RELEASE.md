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
- **Traçabilité** : le tag reste le point de version, mais toute opération GitHub
  privilégiée est déclenchée par `repository_dispatch` depuis le workflow de `main` (§3).

---

## 2. Convention de tags & changelog

### Tags

```bash
# Depuis main à jour, après merge de la PR de release :
git checkout main && git pull --ff-only
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

- Format strict : `v` + SemVer (`v1.2.3`). Le tag ne déclenche aucun workflow
  privilégié ; l'opérateur transmet explicitement la même version au dispatch Android.
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

> [!IMPORTANT]
> Le scope de release actif est l'**Alpha iOS interne** gelée le 2026-09-04.
> Les instructions Android ci-dessous restent un runbook futur et ne font pas
> partie de cette Alpha. Les gates et la vérité historique/live canoniques sont
> dans `RELEASE_MOBILE.md`; ne créer aucun tag ou store pour les vérifier.

| Élément | Valeur |
| --- | --- |
| Déclencheurs | `repository_dispatch` type `release-android`, chargé uniquement depuis la branche par défaut |
| Gates bloquants | provenance `main`, SemVer/versionCode/track, `flutter analyze`, `flutter test`, signature, configuration API/Entra |
| Approbation humaine | environnement GitHub **`beta`** (reviewers requis à configurer) |
| Runner | self-hosted `certigo-trusted` |
| `versionName` | saisi, sinon lu depuis `apps/mobile/pubspec.yaml` |
| `versionCode` | saisi, sinon `github.run_number` (auto-incrémenté) |
| Package | `com.certigo.mobileapp` |
| Secrets | Azure Key Vault (repli : secrets GitHub) |

Tout build, y compris `dry_run`, échoue si l'une des valeurs
`MOBILE_API_BASE_URL`, `MOBILE_ENTRA_CLIENT_ID`, `MOBILE_ENTRA_AUTHORITY`,
`MOBILE_ENTRA_API_SCOPE` et `MOBILE_CERTIGO_ENV` est absente, de développement,
legacy ou placeholder. La source est le Key Vault nommé par
`vars.AZURE_KEYVAULT_NAME`, sinon les seules variables `vars.MOBILE_*`; l'ancienne
variable `API_BASE_URL` n'est jamais utilisée. Les valeurs live sont administrées
hors dépôt. L'AAB signé est conservé 90 jours comme artefact.

**Lancer une release mobile** :

```bash
# Après création éventuelle du tag de traçabilité, déclencher depuis main :
gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches --input - <<'JSON'
{
  "event_type": "release-android",
  "client_payload": {
    "track": "internal",
    "version_name": "1.2.3",
    "dry_run": true
  }
}
JSON
```

> Détails complets (signature, tracks Play, Key Vault, iOS/Codemagic) :
> [`RELEASE_MOBILE.md`](./RELEASE_MOBILE.md).

---

## 4. Release backend (.NET / Azure Functions)

Le backend suit un modèle **CD par environnement** (pas un tag applicatif) :

| Workflow | Rôle | Déclencheur | Garde |
| --- | --- | --- | --- |
| [`cd-backend.yml`](../.github/workflows/cd-backend.yml) | Construit une fois, déploie, promeut ou rollback `dev`/`staging`/`prod` | `push` sur `main` (build + dev), dispatch `promote-backend` | opération, environnement et run source validés depuis un payload strict |

- **Build unique** : chaque push `main` publie une seule fois le backend avec le SDK
  .NET `8.0.424` et CycloneDX `6.2.0`, normalise les timestamps du ZIP et produit
  `release-manifest.json` (commit, SHA-256 du ZIP/SBOM, run et provenance).
- **`dev`** : ce même run déploie automatiquement l'artefact retenu. Aucun job de
  déploiement ne relance `dotnet publish`.
- **`staging` puis `prod`** : deux promotions manuelles référencent le `source_run_id`
  du run `main` déjà passé en `dev`. Le workflow vérifie via l'API GitHub que ce run
  est un push `main` réussi de `cd-backend.yml`, puis revérifie manifeste et hashes.
  `prod` refuse l'artefact s'il n'est pas le `current` déjà sain de staging.
- **Récupération** : `promote-backend` avec `operation=rollback` redéploie uniquement
  l'artefact `previous` enregistré pour l'environnement, sous sa gate GitHub et sans
  redéployer Bicep.
- **Conservation** : le bundle source reste 90 jours sous
  `app-package/releases/<source_run_id>/` dans le Storage privé `dev`, sans dépendre
  du quota GitHub Actions Artifact ; chaque stockage d'environnement conserve les
  ZIP immuables déployés 30 jours et
  `state/backend-release.json` référence les versions courante et précédente. Le
  SHA-256 du ZIP est aussi ancré dans les logs immuables du job source et revérifié
  à chaque téléchargement ; un rerun réutilise le bundle canonique du run.
- **Post-déploiement** : les probes existantes `/api/health/live` et
  `/api/health/ready` sont bloquantes avant la mise à jour du pointeur de release.
- **Destinataire des alertes** : `staging` et `prod` définissent chacun la
  variable non secrète `ALERT_EMAIL` dans leur GitHub Environment. Le CD refuse une
  valeur vide ou mal formée et l'injecte dans le JSON Bicep temporaire ; aucune
  adresse d'opérateur n'est versionnée.

**Promouvoir le backend** :

```bash
SOURCE_RUN_ID="<run push main ayant déployé dev>"
printf '%s' \
  "{\"event_type\":\"promote-backend\",\"client_payload\":{\"environment\":\"staging\",\"operation\":\"promotion\",\"source_run_id\":\"$SOURCE_RUN_ID\"}}" |
  gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches --input -

# Après validation staging, promouvoir exactement le même run :
printf '%s' \
  "{\"event_type\":\"promote-backend\",\"client_payload\":{\"environment\":\"prod\",\"operation\":\"promotion\",\"source_run_id\":\"$SOURCE_RUN_ID\"}}" |
  gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches --input -
```

**Rollback contrôlé** :

```bash
PREVIOUS_RUN_ID="<run push main précédent encore retenu>"
printf '%s' \
  "{\"event_type\":\"promote-backend\",\"client_payload\":{\"environment\":\"prod\",\"operation\":\"rollback\",\"source_run_id\":\"$PREVIOUS_RUN_ID\"}}" |
  gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches --input -
```

> Détails infra/déploiement (OIDC, Bicep, runners, RBAC) :
> [`deployment-runbook.md`](./deployment-runbook.md).

---

## 5. Checklist de release E2E

> Sert de base au lot **wp-p0-08** (release E2E taggée). À dérouler pour une release
> coordonnée backend + mobile **après l'Alpha iOS**. Pour l'Alpha, appliquer
> exclusivement les gates de `RELEASE_MOBILE.md` §1.3 et §8.

1. **Pré-vol**
   - [ ] `main` à jour, PR de release mergée (revue + checks verts).
   - [ ] CI verte : `Build & test`, `Flutter app + UI packages`,
         `Generated state equals committed state`, `Validate workflow YAML` et
         `CodeQL / Security gate`, plus `Security / Required gate`.
   - [ ] Version décidée (SemVer) et reflétée dans `apps/mobile/pubspec.yaml`.
   - [ ] Notes de version / changelog préparés.
2. **Backend**
   - [ ] `dev` déployé (auto au merge) et sain.
   - [ ] Noter le `source_run_id` du push `main` déployé en `dev`.
   - [ ] Dispatch `promote-backend` pour `staging` avec ce run, valider les smoke
         tests, puis promouvoir le même run vers `prod`.
3. **Point de version (tag)**
   - [ ] `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`.
   - [ ] `gh release create vX.Y.Z --generate-notes` (optionnel mais recommandé).
4. **Mobile**
   - [ ] Dispatch `release-android` avec le SemVer du tag → valider la *gate* `beta`.
   - [ ] iOS : lancer/valider la release TestFlight (Codemagic — cf. `RELEASE_MOBILE.md`).
5. **Post-release**
   - [ ] Vérifier santé backend (`/api/health`) et publication mobile.
   - [ ] Consigner la version et l'horodatage (registre / changelog).

---

## 6. Pré-requis de gouvernance

Toute release part de `main`, qui doit être **protégée** : PR + ≥ 1 revue +
checks stricts, pas de push direct. Les environnements `dev`, `staging` et
`prod` doivent accepter uniquement les branches protégées ; `beta` doit accepter
uniquement `main`. Aucune règle de déploiement `v*` ne doit subsister. Voir
[`GOVERNANCE.md`](./GOVERNANCE.md) pour les réglages live à appliquer manuellement.
