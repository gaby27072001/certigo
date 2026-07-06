# WP-P0-05 — Gouvernance CIAM : rapport de vérification & handoff

- **Lot** : `wp-p0-05-ciam-governance` (Phase 0)
- **Findings** : R-04, R-05, R-06, O-05, F-02
- **Session** : `f8ba9096-7adc-41d9-a793-b64490c6090a`
- **Branche** : `gchambaud-microsoft-wp-p0-05-ciam-governance` (base `main` @ `bf698aa`)
- **Date** : 2026-07-06
- **Autorité scope + DoD** : `docs/migration/work-packages.yaml` (entrée `wp-p0-05-ciam-governance`)
- **Autorité runbooks** : `docs/runbooks/` (cf. precondition ligne 90 du registre)

> **Nature du lot.** Les 4 lots P0 précédents étaient déjà remédiés sur `main`. L'audit
> d'idempotence finding par finding confirme que **F-02 est déjà remédié en IaC + code** et que
> **R-04 / R-05 / R-06 / O-05 sont des actions live** (Entra / secrets / Azure / subscription)
> dont les runbooks existent déjà. **Aucune modification de code ou d'IaC n'était requise.**
> Ce lot est donc un lot de **vérification + mise à jour du registre + handoff**.

---

## Synthèse par finding

| Finding | Nature | État réel (idempotence) | Livrable de ce lot |
|--------|--------|--------------------------|--------------------|
| **F-02** | Versionnable (IaC + code) | ✅ **Déjà en place sur `main`** | Vérifié + tracé (aucune modif) |
| **R-06** | Action live Azure (resource lock) | ⏳ **À exécuter par l'ops** | Runbook existant `docs/runbooks/R-06_…` |
| **R-04** | Action live Entra (break-glass) | ⏳ **À exécuter par l'ops** | Runbook existant `docs/runbooks/R-04_…` |
| **R-05** | Action live secret MSA (rotation + alerte) | ⏳ **À exécuter par l'ops** | Runbook existant `docs/runbooks/R-05_…` |
| **O-05** | Action live Entra/Azure (ménage) | ⏳ **À exécuter par l'ops** | Runbook existant `docs/runbooks/O-05_…` |

Légende : ✅ vérifié en place · ⏳ garde-fou outillé (runbook prêt), exécution live en attente d'un opérateur habilité.

---

## F-02 — Bypass dev verrouillé en prod (`AUTH_ALLOW_DEV=false`) — ✅ VÉRIFIÉ

**Conclusion : entièrement remédié sur `main`, en IaC *et* en code. Machine-vérifié.**

Chaîne de dérivation (aucun placeholder à remplir) :

1. `infra/main.bicep:79`
   ```bicep
   var authMode = env == 'dev' ? 'dev' : 'prod'
   ```
2. `infra/modules/functionApp.bicep:146`
   ```bicep
   { name: 'AUTH_ALLOW_DEV', value: authMode == 'dev' ? 'true' : 'false' }
   ```
3. `infra/params/prod.bicepparam:15` → `param env = 'prod'`
   ⇒ `authMode = 'prod'` ⇒ **`AUTH_ALLOW_DEV = 'false'`** en production.
4. Garde-fou backend `AuthValidatorSelection.ShouldUseDevValidator`
   (`backend/src/Certigo.Application/Abstractions/AuthValidatorSelection.cs`) :
   en hosting `Production`, le DevTokenValidator **lève une exception** à chaque requête
   sauf override explicite `AUTH_ALLOW_DEV=true` — override que l'IaC ne pose jamais en prod.
   Défense en profondeur : même une app setting erronée est bloquée par le code.

**Preuve machine (ARM compilé)** — `az bicep build --file infra/main.bicep` → **exit 0** ; l'ARM
généré contient :
```json
"authMode": "[if(equals(parameters('env'), 'dev'), 'dev', 'prod')]",
...
{ "name": "AUTH_ALLOW_DEV",
  "value": "[if(equals(parameters('authMode'), 'dev'), 'true', 'false')]" }
```
⇒ en prod (`env='prod'`), `AUTH_ALLOW_DEV` compile à `'false'`. **DoD F-02 satisfait.**

> Note dev : `infra/params/dev.bicepparam` documente (en-tête) l'usage volontaire d'une **autorité
> Entra placeholder** (valeurs à zéros) côté dev ; c'est le seul environnement où `AUTH_ALLOW_DEV=true`,
> par conception. Prod/staging forcent la validation Entra.

---

## R-06 — Resource lock `CanNotDelete` sur `ciamDirectories` — ⏳ ACTION LIVE

**État : garde-fou outillé (runbook prêt), pose du lock à exécuter par l'ops.**

**Pourquoi ce n'est PAS implémentable proprement en Bicep dans ce dépôt :** la ressource
`Microsoft.AzureActiveDirectory/ciamDirectories` cible vit dans une **souscription / RG distincts**
(`f434ec55-f342-4948-9298-f99af5216204`, `rg-certigo-identity`) qui **ne sont pas déclarés dans
`infra/main.bicep`** (lequel provisionne l'app Certigo : Functions, Cosmos, Storage, Key Vault).
Poser un `Microsoft.Authorization/locks` en Bicep supposerait soit d'étendre le template à une
ressource externe non gérée par ce dépôt (couplage indésirable, risque de drift/écrasement), soit
de déployer dans un autre scope d'abonnement. La voie **propre et idempotente** est donc l'action
live documentée : `az lock create --lock-type CanNotDelete` sur la ressource `ciamDirectories`,
comme décrit dans le runbook.

➡️ **Runbook : `docs/runbooks/R-06_resource-lock-ciam-facturation.md`** (commandes `az` exactes,
vérification `az lock list`, rollback `az lock delete`).

---

## R-04 — Compte break-glass cloud-only (testé) — ⏳ ACTION LIVE

**État : action Entra live (création d'un compte cloud-only + test de connexion), non exécutable
depuis cette session (pas de creds, non reviewable en PR).**

➡️ **Runbook : `docs/runbooks/R-04_compte-break-glass-ciam.md`** (portail Entra + `az`/Graph,
exclusion des accès conditionnels, test documenté, rollback).

---

## R-05 — Rotation + alerte du secret MSA (échéance 2027-07-01) — ⏳ ACTION LIVE

**État : action live sur le secret de l'app MSA (`df42c145`, secret `certigo-ciam-oidc-2026-07`) +
mise en place d'une alerte J-30. Non exécutable en PR.**

➡️ **Runbook : `docs/runbooks/R-05_rotation-secret-idp-msa.md`** (rotation du secret, mise à jour
de la config consommatrice, alerte d'expiration, rollback).

---

## O-05 — Ménage : app registrations QuickStart + subscription vide — ⏳ ACTION LIVE

**État : suppression de 3 app registrations QuickStart résiduelles + annulation d'une subscription
vide. Action destructive live à réaliser par l'ops.**

- **À supprimer (QuickStart résiduelles)** : `35bb7bbc`, `49957408`, `5f371968`.
- **À CONSERVER (prod)** : `4d1f1075` (Mobile), `12910b8e` (API audience), `df42c145` (MSA),
  `77216304` (b2c-extensions) ; user flow `susi_certigo` (`7fdf12ed`).
- **Subscription vide à annuler** : `906c6a44…`.

➡️ **Runbook : `docs/runbooks/O-05_nettoyage-tenant-ciam.md`** (inventaire, suppression `az ad app`,
annulation subscription, rollback via corbeille Entra 30 j).

---

## DoD (machine-vérifiable) — résultats

| Contrôle DoD | Commande | Résultat |
|--------------|----------|----------|
| Compilation IaC (F-02) | `az bicep build --file infra/main.bicep` | ✅ exit 0 |
| F-02 `AUTH_ALLOW_DEV=false` en prod | grep ARM compilé + `prod.bicepparam` | ✅ dérive `false` |
| Aucun secret en clair ajouté | grep (mots de passe / clés) sur le diff | ✅ aucun |
| Registre YAML/JSON/JSONL valides | parse work-packages.yaml + state/*.json + log.jsonl | ✅ valides |
| R-06 / R-04 / R-05 / O-05 (live) | — | ⏳ **hors périmètre PR** : à exécuter par l'ops via runbooks |

> Le code backend n'a pas été modifié (F-02 déjà en place), donc `dotnet build`/`dotnet test`
> ne sont pas déclenchés par ce lot (aucun changement de code).

---

## Réserves / points d'attention

1. **4 garde-fous en attente d'exécution live.** R-04, R-05, R-06 et O-05 exigent des droits
   Entra/Azure non disponibles dans cette session automatisée. Ils sont **outillés et prêts**
   (runbooks) mais **non exécutés**. Le lot passe en `in_review`, **pas** en `done` : le passage
   à `done` suppose l'exécution live des 4 runbooks par un opérateur habilité + preuve de vérif.
2. **Discordance de chemin runbooks (prompt vs registre).** Le prompt mentionnait
   `docs/migration/runbooks/` ; l'autorité (`work-packages.yaml` ligne 90) et les runbooks réels
   sont sous **`docs/runbooks/`**. C'est ce dernier qui fait foi. Un pointeur
   `docs/migration/runbooks/README.md` a été ajouté pour lever l'ambiguïté sans dupliquer.
3. **R-06 non implémentable en Bicep dans ce dépôt** (ressource `ciamDirectories` dans une souscription
   externe non gérée par `infra/main.bicep`) — justification détaillée ci-dessus ; la voie live est correcte.
