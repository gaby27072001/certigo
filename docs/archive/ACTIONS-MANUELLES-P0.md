# Actions manuelles P0 — Runbook opérateur consolidé (Certigo)

> **⚠️ ARCHIVÉ le 2026-09-03.** Ce document est **entièrement obsolète** : les deux PR qu'il
> gate (#205, #201) sont **fusionnées depuis le 2026-07-06** (Phase 0 est `done` à 100 % —
> voir `docs/migration/STATE.md`). Aucune commande ci-dessous n'est unique : toutes proviennent
> déjà de `docs/runbooks/` (R-04, R-05, R-06, O-05) ou de `docs/GOVERNANCE.md` (§4, branch
> protection). Conservé pour l'historique uniquement — voir le registre canonique
> [`docs/ETAT_DU_PROJET.md`](../ETAT_DU_PROJET.md) pour l'état actuel.

> **Statut de ce document** : GUIDE OPÉRATEUR consolidé, additif, **non exécutable par une session agent** (les 5 actions exigent des credentials live Entra / Azure / GitHub). Destiné à **Gabriel** (admin Azure / Entra External ID CIAM / GitHub), à exécuter **à la main**.
>
> **Source de vérité** : ce document **réconcilie sans les remplacer** les runbooks déjà versionnés. Il ne contient **aucune commande inventée** ; chaque commande est tirée des runbooks cités. En cas de doute, **le runbook source fait foi**.
>
> - Lot **wp-p0-05-ciam-governance** (PR **#205**, DRAFT, `in_review`) — branche `gchambaud-microsoft-wp-p0-05-ciam-governance` :
>   - `docs/runbooks/R-06_resource-lock-ciam-facturation.md`
>   - `docs/runbooks/R-04_compte-break-glass-ciam.md`
>   - `docs/runbooks/O-05_nettoyage-tenant-ciam.md`
>   - `docs/runbooks/R-05_rotation-secret-idp-msa.md`
> - Lot **wp-p0-07-github-branch-protection-release** (PR **#201**, DRAFT, `in_review`) — branche `gchambaud-microsoft-wp-p0-07-branch-protection-release` :
>   - `docs/GOVERNANCE.md` (§4)
>   - `.github/branch-protection-main.json`
>
> **Ne merge rien depuis ce guide.** L'ordre des merges P0 est coordonné avec l'orchestrateur (voir §Ordre d'exécution global).

---

## Résumé — les 5 actions dans l'ordre

| # | Action | Lot | Surface | Durée | Bloque le merge de |
|---|--------|-----|---------|-------|--------------------|
| 1 | **R-06** — resource lock `CanNotDelete` sur le CIAM directory | p0-05 | Azure (sub facturation) | ~2 min | #205 |
| 2 | **R-04** — compte break-glass cloud-only (Global Admin) | p0-05 | Entra CIAM | ~15 min | #205 |
| 3 | **O-05** — ménage Entra (3 apps + 2 user flows) + subscription vide | p0-05 | Entra CIAM + Azure | ~20 min | #205 |
| 4 | **R-05** — rotation outillée + **alerte J-30** du secret MSA | p0-05 | Entra CIAM + ops | ~15 min (alerte) | #205 |
| 5 | **Durcissement branch protection `main`** (`enforce_admins`…) | p0-07 | GitHub | ~5 min | *(APRÈS les merges P0)* |

**Ordre impératif : R-06 → R-04 → O-05 → R-05 → [merges P0 souhaités, dont #205] → durcissement #5.**
R-06 **en premier** car le lock protège tout le reste. Le durcissement #5 **en dernier** car `enforce_admins=true` retire à l'admin la capacité de bypasser les checks (voir §5).

---

## BLOC A — CIAM (lot wp-p0-05, PR #205) — 4 actions à exécuter AVANT de merger #205

### Identifiants communs au BLOC A

| Élément | Valeur |
|---|---|
| Tenant CIAM (Entra External ID) | `af721be8-5901-422a-b299-b9c57847b968` |
| Subscription facturation CIAM (Visual Studio) | `f434ec55-f342-4948-9298-f99af5216204` |
| Resource group du directory CIAM | `rg-certigo-identity` |
| Subscription vide à annuler (O-05) | `906c6a44-…` *(ID complet dans le runbook O-05 / portail)* |

> ⚠️ Le CIAM vit dans une **sub/RG externes** (`rg-certigo-identity`) **non déclarés** dans `infra/main.bicep`. La voie live (Azure CLI / portail) est donc **la bonne voie** — **pas de Bicep** pour ces actions.

---

### 1. R-06 — Resource lock `CanNotDelete` sur le CIAM directory
**Source : `docs/runbooks/R-06_resource-lock-ciam-facturation.md` (branche p0-05).**

**Objectif (finding).** Le CIAM directory (`Microsoft.AzureActiveDirectory/ciamDirectories`) n'a **aucun verrou de suppression**. Une suppression accidentelle du directory ou du RG détruirait toute l'identité clients Certigo. On pose un lock `CanNotDelete` — **en premier**, car il protège tout le reste du BLOC A.

**Pré-requis.**
- Rôle **`Owner`** *ou* **`User Access Administrator`** sur la subscription `f434ec55-…` (⚠️ `Contributor` **ne suffit pas** pour créer/supprimer un lock).
- Azure CLI **≥ 2.60**.
- Être positionné sur la bonne subscription.

**Commandes exactes (copier-coller).**
```bash
# 0) Contexte : sélectionner la subscription de facturation du CIAM
az account set --subscription "f434ec55-f342-4948-9298-f99af5216204"

# 1) Récupérer dynamiquement le NOM exact du directory CIAM (ne pas le deviner)
az resource list \
  --resource-group rg-certigo-identity \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories \
  --query "[].{name:name, id:id, location:location}" -o table
#   -> noter la valeur de la colonne "name" => <NOM_CIAM>

# 2) Poser le lock CanNotDelete sur le directory CIAM
az lock create \
  --name lock-ciam-nodelete \
  --lock-type CanNotDelete \
  --resource-group rg-certigo-identity \
  --resource-name "<NOM_CIAM>" \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories \
  --notes "P0 R-06 : protection anti-suppression du CIAM directory Certigo. Ne pas retirer sans validation sécurité."
```

**Option renforcée (recommandée par R-06)** — verrouiller aussi le **resource group** entier :
```bash
az lock create \
  --name lock-rg-certigo-identity-nodelete \
  --lock-type CanNotDelete \
  --resource-group rg-certigo-identity \
  --notes "P0 R-06 : protection anti-suppression du RG hébergeant le CIAM."
```

**Placeholders.**
- `<NOM_CIAM>` = valeur `name` retournée à l'étape 1 (ex. `certigoapp` / `certigoapp.onmicrosoft.com` selon l'affichage — **utiliser la valeur exacte renvoyée**).

**Vérification.**
```bash
az lock list --resource-group rg-certigo-identity -o table
#   -> attendu : lock-ciam-nodelete (et, si option, lock-rg-certigo-identity-nodelete), Level=CanNotDelete

az lock show --name lock-ciam-nodelete \
  --resource-group rg-certigo-identity \
  --resource-name "<NOM_CIAM>" \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories -o json
#   -> attendu : "level": "CanNotDelete"
```
Test négatif (facultatif, **non destructif** : le lock doit faire échouer la commande) :
```bash
az resource delete \
  --resource-group rg-certigo-identity \
  --name "<NOM_CIAM>" \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories
#   -> attendu : ÉCHEC avec code "ScopeLocked" (preuve que le lock bloque bien la suppression)
```

**Rollback.**
```bash
az lock delete --name lock-ciam-nodelete \
  --resource-group rg-certigo-identity \
  --resource-name "<NOM_CIAM>" \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories
# (et, si posé) az lock delete --name lock-rg-certigo-identity-nodelete --resource-group rg-certigo-identity
```
Idempotent : ré-exécuter `az lock create` sur un lock existant ne casse rien.

**Durée estimée.** ~2 min.
**Ordre / dépendances.** **Action n°1, aucune dépendance.** À faire **avant** R-04/O-05/R-05.

---

### 2. R-04 — Compte break-glass cloud-only (Global Admin)
**Source : `docs/runbooks/R-04_compte-break-glass-ciam.md` (branche p0-05).**

**Objectif (finding).** Le seul Global Admin actuel du tenant CIAM est un **compte MSA gmail fédéré** (`#EXT#`). Si la fédération MSA tombe (ou le compte externe est perdu), **plus aucun admin** ne peut administrer le tenant. On crée un **compte break-glass cloud-only** (`.onmicrosoft.com`), Global Admin, **exclu des Conditional Access**, mot de passe long **scellé hors-ligne**.

**Pré-requis.**
- Être **Global Admin** du tenant CIAM `af721be8-…` (via le compte MSA actuel).
- Azure CLI connecté au tenant CIAM **sans subscription** :
```bash
az login --tenant af721be8-5901-422a-b299-b9c57847b968 --allow-no-subscriptions
```
- Un **coffre / gestionnaire de secrets** (Key Vault, 1Password, coffre physique scellé…) prêt à recevoir le mot de passe.

**Commandes exactes (copier-coller).**
```bash
# 1) Générer un mot de passe long et aléatoire (choisir UNE méthode)
#    Linux/macOS :
openssl rand -base64 30
#    Windows PowerShell :
#    [Convert]::ToBase64String((1..30 | ForEach-Object {Get-Random -Max 256}))
#    -> copier la valeur => <MDP_BREAKGLASS> (à sceller dans le coffre immédiatement)

# 2) Créer le compte cloud-only (Member), mot de passe à changer à la 1re connexion selon politique du runbook
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/users" \
  --headers "Content-Type=application/json" \
  --body '{
    "accountEnabled": true,
    "displayName": "Certigo Break-Glass (P0 R-04)",
    "userPrincipalName": "breakglass@certigoapp.onmicrosoft.com",
    "mailNickname": "breakglass",
    "passwordProfile": {
      "forceChangePasswordNextSignIn": false,
      "password": "<MDP_BREAKGLASS>"
    }
  }'
#   -> noter la valeur "id" du user créé => <USER_OBJECT_ID>

# 3) Attribuer le rôle Global Administrator (roleDefinitionId GUID fixe Entra)
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
  --headers "Content-Type=application/json" \
  --body '{
    "principalId": "<USER_OBJECT_ID>",
    "roleDefinitionId": "62e90394-69f5-4237-9190-012177145e10",
    "directoryScopeId": "/"
  }'
#   -> noter la valeur "id" de l'attribution => <ROLE_ASSIGNMENT_ID>
```

**Placeholders.**
- `<MDP_BREAKGLASS>` = sortie de l'étape 1 (**à sceller immédiatement** dans le coffre ; ne jamais laisser en clair).
- `<USER_OBJECT_ID>` = `id` du user (étape 2).
- `<ROLE_ASSIGNMENT_ID>` = `id` de l'attribution (étape 3, utile pour le rollback).
- `62e90394-69f5-4237-9190-012177145e10` = roleDefinitionId **Global Administrator** (GUID fixe Entra, **ne pas modifier**).

**Exclusion Conditional Access.** Le tenant CIAM a **actuellement 0 policy CA**. **Dès qu'une policy CA est créée**, ajouter `breakglass@certigoapp.onmicrosoft.com` aux **utilisateurs exclus** de **chaque** policy (le compte break-glass ne doit jamais être bloqué par MFA/CA). Best practice R-04 : MFA **FIDO2 dédié** sur ce compte + surveillance des connexions.

**Vérification.**
```bash
# Le compte existe et est actif
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/users/breakglass@certigoapp.onmicrosoft.com?\$select=id,userPrincipalName,accountEnabled" -o json
#   -> attendu : accountEnabled=true, userPrincipalName=breakglass@certigoapp.onmicrosoft.com

# Le rôle Global Admin est bien attribué
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=principalId eq '<USER_OBJECT_ID>'" -o json
#   -> attendu : une entrée avec roleDefinitionId=62e90394-69f5-4237-9190-012177145e10
```
**Test de connexion** (obligatoire) : se connecter **une fois** au portail avec `breakglass@…` en navigation privée pour confirmer l'accès, puis re-sceller.

**Rollback.**
```bash
# Désactiver le compte
az rest --method PATCH \
  --url "https://graph.microsoft.com/v1.0/users/<USER_OBJECT_ID>" \
  --headers "Content-Type=application/json" \
  --body '{ "accountEnabled": false }'

# Retirer l'attribution de rôle
az rest --method DELETE \
  --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments/<ROLE_ASSIGNMENT_ID>"
```

**Durée estimée.** ~15 min (dont test de connexion + scellement).
**Ordre / dépendances.** **Action n°2**, après R-06. Indépendante d'O-05/R-05, mais R-04 **avant** O-05 (garder un admin de secours avant de faire le ménage).

> **Note (best practice vs brief).** Microsoft recommande **2 comptes** break-glass. Le brief P0 n'en demande **qu'un** ; R-04 documente le second comme amélioration ultérieure (non bloquante P0).

---

### 3. O-05 — Ménage Entra (apps + user flows) + subscription vide
**Source : `docs/runbooks/O-05_nettoyage-tenant-ciam.md` (branche p0-05).**

**Objectif (finding).** Résidus de QuickStart Entra External ID : **3 app registrations** de test (redirections `jwt.ms` / `localhost`), **2 user flows** QuickStart, et **1 subscription vide**. On les supprime pour réduire la surface d'attaque et la dette — **sans jamais toucher** aux objets de PROD.

**⛔ NE JAMAIS supprimer (objets de PRODUCTION).**
| Objet | appId / id | Rôle |
|---|---|---|
| Certigo Mobile | `4d1f1075-…` | App mobile prod |
| Certigo API | `12910b8e-…` | API prod |
| Certigo MSA Login | `df42c145-…` | IdP MSA prod (cf. R-05) |
| b2c-extensions-app | `77216304-…` | Infra Entra (ne jamais supprimer) |
| User flow `susi_certigo` | `7fdf12ed-…` | User flow prod |

**✅ À supprimer.**
| Objet | appId / id |
|---|---|
| App QuickStart #1 (redirect jwt.ms/localhost) | `35bb7bbc-…` |
| App QuickStart #2 | `49957408-…` |
| App QuickStart #3 | `5f371968-…` |
| User flow QuickStart #1 | `<FLOW_ID_1>` *(≠ susi_certigo)* |
| User flow QuickStart #2 | `<FLOW_ID_2>` *(≠ susi_certigo)* |
| Subscription vide | `906c6a44-…` |

**Pré-requis.**
- **`Application Administrator`** (ou Global Admin) sur le tenant CIAM `af721be8-…` pour apps + user flows.
- **`Owner`** sur la subscription `906c6a44-…` pour l'annuler.
- Connecté au tenant CIAM (cf. R-04, `az login --tenant … --allow-no-subscriptions`).

**Étape 0 — INVENTAIRE OBLIGATOIRE (garde-fous, avant toute suppression).**
```bash
# a) Inventaire complet des app registrations (confirmer appId + displayName + redirects)
az ad app list --all \
  --query "[].{name:displayName, appId:appId, id:id}" -o table
#   -> vérifier que 35bb7bbc / 49957408 / 5f371968 sont bien les QuickStart (redirects jwt.ms/localhost)
#   -> vérifier que 4d1f1075 / 12910b8e / df42c145 / 77216304 sont bien les PROD (à NE PAS toucher)

# b) Lister les user flows (API beta authenticationEventsFlows) pour identifier les 2 QuickStart
az rest --method GET \
  --url "https://graph.microsoft.com/beta/identity/authenticationEventsFlows" \
  --query "value[].{name:displayName, id:id}" -o table
#   -> repérer <FLOW_ID_1> et <FLOW_ID_2> (les 2 QuickStart) ; CONSERVER susi_certigo (7fdf12ed)

# c) Confirmer que la subscription 906c6a44 est bien VIDE (aucune ressource)
az resource list --subscription "906c6a44-…" -o table
#   -> attendu : liste VIDE. Si NON vide -> STOP, ne pas annuler, escalader.
```

**Commandes exactes (dans cet ordre : apps → user flows → subscription).**
```bash
# 1) Supprimer les 3 app registrations QuickStart (corbeille 30 j)
az ad app delete --id 35bb7bbc-…    # QuickStart #1
az ad app delete --id 49957408-…    # QuickStart #2
az ad app delete --id 5f371968-…    # QuickStart #3

# 2) Supprimer les 2 user flows QuickStart (PAS de corbeille -> irréversible)
az rest --method DELETE \
  --url "https://graph.microsoft.com/beta/identity/authenticationEventsFlows/<FLOW_ID_1>"
az rest --method DELETE \
  --url "https://graph.microsoft.com/beta/identity/authenticationEventsFlows/<FLOW_ID_2>"

# 3) Annuler la subscription vide (récupérable ~90 j)
az account subscription cancel --id "906c6a44-…"
```

**Placeholders.**
- `<FLOW_ID_1>`, `<FLOW_ID_2>` = ids des 2 user flows QuickStart repérés à l'étape 0-b (**jamais** `7fdf12ed` = `susi_certigo`).
- Les appId `35bb7bbc-…`, `49957408-…`, `5f371968-…` et la subscription `906c6a44-…` : compléter avec les **ID complets** confirmés à l'étape 0 (le runbook O-05 les fournit in extenso).

**Vérification.**
```bash
# Apps supprimées absentes de la liste active, présentes en corbeille
az ad app list --all --query "[?appId=='35bb7bbc-…' || appId=='49957408-…' || appId=='5f371968-…']" -o table
#   -> attendu : VIDE (plus dans les apps actives)
az rest --method GET --url "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.application" -o table
#   -> attendu : les 3 apps y figurent (corbeille 30 j)

# User flows : susi_certigo TOUJOURS présent, les 2 QuickStart absents
az rest --method GET \
  --url "https://graph.microsoft.com/beta/identity/authenticationEventsFlows" \
  --query "value[].{name:displayName, id:id}" -o table
#   -> attendu : susi_certigo (7fdf12ed) présent ; <FLOW_ID_1>/<FLOW_ID_2> absents

# Subscription : état
az account subscription show --id "906c6a44-…" --query "{name:displayName, state:state}" -o json
#   -> attendu : state="Deleted" (ou "Disabled"/"Warned" selon délai de propagation)
```

**Rollback.**
- **Apps** : `az ad app show --id <appId>` puis restauration corbeille via `az rest POST …/directory/deletedItems/<id>/restore` (**≤ 30 j**).
- **Subscription** : réactivation via portail/support (**≤ 90 j**).
- **User flows** : ⚠️ **PAS de corbeille** → **irréversible** ; recréation manuelle depuis QuickStart si nécessaire (raison de l'inventaire strict à l'étape 0).

**Durée estimée.** ~20 min (dont inventaire).
**Ordre / dépendances.** **Action n°3**, après R-04. L'étape 0 (inventaire) est **non négociable**.

---

### 4. R-05 — Rotation outillée + alerte J-30 du secret MSA
**Source : `docs/runbooks/R-05_rotation-secret-idp-msa.md` (branche p0-05).**

**Objectif (finding).** L'app IdP **`Certigo MSA Login`** (`df42c145-…`) — reliée au user flow `susi_certigo` (`7fdf12ed`) — porte un client secret `certigo-ciam-oidc-2026-07` qui **expire le 2027-07-01** (≈ 1 an → **PAS urgent**). Un secret expiré **casserait le login clients**. **Valeur immédiate de ce lot = poser l'alerte d'expiration (J-30)**. La procédure de rotation **sans coupure** est fournie pour l'échéance.

**Pré-requis.**
- **`Application Administrator`** (ou GA) sur le tenant CIAM `af721be8-…`, connecté (cf. R-04).
- Accès à la config de l'**IdP** côté user flow (portail Entra External ID, ou API Graph beta).
- Un **e-mail/canal surveillé** pour l'alerte (owner d'app et/ou webhook Teams).

> **Certificat impossible** : l'IdP attend un **clientSecret** (chaîne). On **conserve** donc le client secret, avec **rotation annuelle + alerte**.

#### 4.a — Mettre en place l'alerte J-30 (⭐ valeur immédiate, à faire maintenant)
Deux dispositifs **complémentaires** (le runbook recommande les deux) :

**Dispositif 1 — Owner d'app avec e-mail surveillé** (notifications natives d'expiration Entra) :
```bash
# Ajouter un owner (boîte surveillée) sur l'app IdP -> reçoit les alertes d'expiration Entra
az ad app owner add --id df42c145-… --owner-object-id <OWNER_OBJECT_ID>
```
- `<OWNER_OBJECT_ID>` = objectId de l'utilisateur/boîte surveillée (ex. alias ops).

**Dispositif 2 — Vérification programmée (GitHub Action cron)** : le runbook R-05 fournit un **modèle de workflow YAML** (job cron interrogeant Graph sur l'expiration du secret de `df42c145`, seuil `THRESHOLD_DAYS=30`, notification via **webhook Teams**). ⚠️ **À déployer côté dépôt ops/infra**, **PAS dans ce dépôt applicatif** (voir le YAML exact dans R-05 §alerte). Résumé des paramètres :
- Déclencheur : `schedule: cron` (quotidien).
- Requête : `GET https://graph.microsoft.com/v1.0/applications/<APP_OBJECT_ID>?$select=passwordCredentials`.
- Seuil : `THRESHOLD_DAYS=30` → si `endDateTime - now ≤ 30 j`, notifier.
- Notification : `TEAMS_WEBHOOK_URL` (secret CI).

**Vérification (alerte).**
```bash
# L'owner surveillé est bien attaché à l'app IdP
az ad app owner list --id df42c145-… --query "[].{name:displayName, id:id}" -o table
#   -> attendu : la boîte surveillée figure dans la liste
```
Pour le Dispositif 2 : déclencher le workflow manuellement (`workflow_dispatch`) une fois → vérifier qu'il lit bien la date d'expiration et n'alerte pas (>30 j restants aujourd'hui).

#### 4.b — Rotation SANS coupure (procédure pour l'échéance 2027-07-01)
```bash
# 1) Lister les credentials actuels et NOTER l'ancien keyId
az ad app credential list --id df42c145-… \
  --query "[].{keyId:keyId, displayName:displayName, end:endDateTime}" -o table
#   -> noter le keyId du secret certigo-ciam-oidc-2026-07 => <ANCIEN_KEY_ID>

# 2) Créer le NOUVEAU secret en mode APPEND (⚠️ --append ESSENTIEL : ne PAS écraser l'ancien)
az ad app credential reset --id df42c145-… \
  --display-name "certigo-ciam-oidc-2027-07" \
  --years 1 \
  --append
#   -> RÉCUPÉRER la valeur "password" retournée => <NOUVEAU_SECRET> (affichée UNE seule fois)

# 3) Mettre à jour l'IdP avec <NOUVEAU_SECRET>
#    Voie A (RECOMMANDÉE) : portail Entra External ID -> User flows -> Identity providers
#      -> IdP relié à susi_certigo -> remplacer le Client secret par <NOUVEAU_SECRET> -> Save
#    Voie B (API) :
#      az rest --method PATCH \
#        --url "https://graph.microsoft.com/beta/identity/identityProviders/<IDP_ID>" \
#        --headers "Content-Type=application/json" \
#        --body '{ "clientSecret": "<NOUVEAU_SECRET>" }'

# 4) TESTER un login réel via susi_certigo (bout-en-bout) AVANT de purger l'ancien secret

# 5) Une fois le login validé sur le nouveau secret, PURGER l'ancien
az ad app credential delete --id df42c145-… --key-id <ANCIEN_KEY_ID>
```

**Placeholders.**
- `<OWNER_OBJECT_ID>` = objectId de la boîte/alias surveillé (alerte).
- `<APP_OBJECT_ID>` = objectId (≠ appId) de `df42c145` pour la requête Graph du workflow.
- `<ANCIEN_KEY_ID>` = keyId du secret `certigo-ciam-oidc-2026-07`.
- `<NOUVEAU_SECRET>` = valeur `password` renvoyée à l'étape 2 (**affichée une seule fois** → sceller aussitôt).
- `<IDP_ID>` = id de l'identity provider (Voie B uniquement).

**Vérification (rotation).**
```bash
az ad app credential list --id df42c145-… \
  --query "[].{keyId:keyId, displayName:displayName, end:endDateTime}" -o table
#   -> attendu APRÈS purge : seul certigo-ciam-oidc-2027-07 présent (fin ~ +1 an) ; l'ancien absent
```
+ **login clients OK** via `susi_certigo` (test bout-en-bout de l'étape 4).

**Rollback.**
- Si le login casse **après** l'étape 3 : re-basculer l'IdP sur l'**ancien** secret (encore valide tant que l'étape 5 n'est pas faite grâce à `--append`).
- L'étape 5 (purge) n'est faite **qu'après** validation du login → pas de coupure.

**Durée estimée.** ~15 min pour l'**alerte (4.a)** aujourd'hui ; ~15 min pour la **rotation (4.b)** à l'échéance 2027-07.
**Ordre / dépendances.** **Action n°4**, après O-05. Aujourd'hui : **exécuter 4.a (alerte)**. 4.b : **planifier avant 2027-07-01**.

> **Après R-06 + R-04 + O-05 + R-05(4.a) exécutés & vérifiés**, l'orchestrateur peut basculer `wp-p0-05` de `in_review` → `done` et proposer le merge de **#205**.

---

## BLOC B — Durcissement branch protection GitHub (lot wp-p0-07, PR #201) — 1 action

### 5. Durcissement admin de la protection de `main`
**Source : `docs/GOVERNANCE.md` §4 + `.github/branch-protection-main.json` (branche p0-07).**

**Objectif (finding).** La branche `main` est **déjà protégée** (revues=1, checks stricts `Build & test` + `Flutter app + UI packages`, push direct interdit). Restent **3 durcissements admin** non encore appliqués en live (choix délibéré du lot p0-07 pour ne pas se bloquer) :
- `enforce_admins = true` (les admins **aussi** soumis aux règles),
- `require_code_owner_reviews = true` (revue CODEOWNERS obligatoire),
- `required_conversation_resolution = true` (toutes les conversations résolues avant merge).

**Pré-requis.**
- Droit **admin** sur `gchambaud_microsoft/Certigo`.
- `gh` CLI authentifié :
```bash
gh auth status
```
- ⚠️ **`.github/CODEOWNERS` doit être présent sur `main`** **AVANT** d'activer `require_code_owner_reviews` (sinon aucune revue code owner ne pourra être satisfaite). Il est livré par le lot p0-07 (PR #201) → **s'assurer que #201 est mergé** (ou CODEOWNERS présent sur `main`) avant l'étape.
- Disposer du fichier `.github/branch-protection-main.json` (branche p0-07 / après merge #201).

**⚠️ EFFET DE BORD MAJEUR — pourquoi cette action est la DERNIÈRE.**
Une fois `enforce_admins=true`, **l'admin ne pourra plus bypasser les checks** (pas d'admin-merge en force). Donc : **appliquer ce durcissement APRÈS avoir mergé toutes les PR P0 souhaitées** (dont #205 une fois p0-05 `done`). **Coordination avec l'orchestrateur impérative.**

**Commandes exactes (copier-coller).**
```bash
# 0) Dry-run : lire l'état de protection ACTUEL (aucune mutation)
gh api repos/gchambaud_microsoft/Certigo/branches/main/protection \
  -H "Accept: application/vnd.github+json"

# 1) Appliquer l'état cible durci (fichier versionné, ré-appliquable / idempotent)
gh api --method PUT \
  repos/gchambaud_microsoft/Certigo/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --input .github/branch-protection-main.json
```
*(Alternative UI : GitHub → Settings → Branches → règle `main` → cocher « Do not allow bypassing the settings » (enforce_admins), « Require review from Code Owners », « Require conversation resolution before merging ». La procédure exacte champ-par-champ est dans `GOVERNANCE.md §4`.)*

**Option à arbitrer — historique linéaire.**
Le brief mentionne `required_linear_history=true`. ⚠️ Dans le JSON **versionné**, ce champ vaut **`false`** (non retenu par le lot p0-07). Pour l'activer, **éditer** `.github/branch-protection-main.json` (`"required_linear_history": true`) **avant** le PUT, ou cocher « Require linear history » dans l'UI. **Décision à prendre avec l'orchestrateur** (impacte la stratégie de merge : squash/rebase only).

**Vérification.**
```bash
gh api repos/gchambaud_microsoft/Certigo/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --jq '{admins:.enforce_admins.enabled, code_owners:.required_pull_request_reviews.require_code_owner_reviews, convo:.required_conversation_resolution.enabled, checks:.required_status_checks.contexts}'
#   -> attendu : admins=true, code_owners=true, convo=true,
#      checks=["Build & test","Flutter app + UI packages"]
```

**Rollback.**
Rejouer un `PUT` avec un JSON remettant les 3 champs à `false` (`enforce_admins:false`, `require_code_owner_reviews:false`, `required_conversation_resolution:false`) — cf. `GOVERNANCE.md §4` (état §1 = état antérieur non durci). Réversible à tout moment par un admin.

**Durée estimée.** ~5 min.
**Ordre / dépendances.** **Action n°5, EN DERNIER**, **après** les merges P0 souhaités (dont #205). Dépend de : CODEOWNERS présent sur `main` (#201).

---

## ✅ Checklist récapitulative (cochable)

**BLOC A — CIAM (avant merge #205)**
- [ ] **R-06** — `az account set` sub `f434ec55-…` ; `<NOM_CIAM>` récupéré ; `lock-ciam-nodelete` posé ; (option) lock RG ; `az lock list` OK ; test `ScopeLocked` OK.
- [ ] **R-04** — `az login --tenant af721be8-…` ; MDP généré **et scellé** ; user `breakglass@certigoapp.onmicrosoft.com` créé (`<USER_OBJECT_ID>`) ; rôle GA attribué (`<ROLE_ASSIGNMENT_ID>`) ; **test de connexion** OK ; exclusion CA notée (à appliquer dès qu'une policy existe).
- [ ] **O-05** — **inventaire (étape 0) fait** ; apps `35bb7bbc`/`49957408`/`5f371968` supprimées ; user flows `<FLOW_ID_1>`/`<FLOW_ID_2>` supprimés ; `susi_certigo` (7fdf12ed) **intact** ; subscription `906c6a44-…` annulée ; vérifs OK ; **aucun objet PROD touché**.
- [ ] **R-05 (4.a alerte)** — owner surveillé ajouté sur `df42c145` ; (option) workflow cron J-30 déployé côté ops (Teams webhook) ; vérif owner OK.
- [ ] **R-05 (4.b rotation)** — *planifié avant 2027-07-01* (pas requis aujourd'hui).
- [ ] → Signaler à l'orchestrateur : p0-05 prêt à passer `in_review` → `done`, puis merge **#205**.

**BLOC B — GitHub (après merges P0)**
- [ ] **#5 durcissement** — `gh auth status` OK ; CODEOWNERS sur `main` (#201 mergé) ; dry-run lu ; **merges P0 souhaités effectués** ; `PUT … --input .github/branch-protection-main.json` ; vérif `admins=true, code_owners=true, convo=true, checks=[…]`.
- [ ] *(option)* `required_linear_history` arbitré avec l'orchestrateur.

---

## 🔢 Ordre d'exécution global

```
1. R-06   (resource lock CanNotDelete)        ─┐
2. R-04   (break-glass cloud-only)             │  BLOC A — CIAM
3. O-05   (ménage apps/flows + subscription)   │  (avant merge #205)
4. R-05   (alerte J-30 ; rotation planifiée)  ─┘
        │
        ▼
5. [MERGES P0 SOUHAITÉS]  (dont #205 une fois p0-05 = done)   ← coordonné avec l'orchestrateur
        │
        ▼
6. #5  Durcissement branch protection main (enforce_admins…)  ← EN DERNIER (effet de bord)
```

**Règles d'or.**
1. **R-06 en premier** (protège tout le reste).
2. **R-04 avant O-05** (garder un admin de secours avant le ménage).
3. **O-05 : inventaire (étape 0) obligatoire**, ne jamais toucher les objets PROD, user flows **irréversibles**.
4. **Durcissement #5 en dernier**, **après** les merges P0 (sinon `enforce_admins` bloque l'admin-merge).
5. **Zéro invention** : si un placeholder/valeur manque, **se référer au runbook source** cité en tête de chaque action.

---

*Document additif — ne modifie aucun code applicatif, ne merge rien. Réconcilié avec R-06 / R-04 / O-05 / R-05 (lot wp-p0-05, PR #205) et GOVERNANCE.md §4 / branch-protection-main.json (lot wp-p0-07, PR #201).*
