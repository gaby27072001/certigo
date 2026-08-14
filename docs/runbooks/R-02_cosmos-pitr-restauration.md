# R-02 — Restauration Point-In-Time (PITR) du compte Cosmos DB

| Champ | Valeur |
|---|---|
| **Finding** | R-02 (🟠 Moyen) |
| **Constat audit** | Cosmos prod en backup **Periodic** à l'origine (aucun `backupPolicy` dans le Bicep → défaut Periodic). Pas de PITR : récupération limitée aux snapshots périodiques en cas de corruption/suppression prod. |
| **Remédiation IaC** | `cosmosBackupMode` est explicite par environnement : staging/prod `Continuous` + `Continuous7Days`, dev `Periodic` avec intervalle, rétention et redondance déclarés. |
| **Objet de ce runbook** | Documenter la **procédure de restauration** PITR (gate audit : « preuve d'un restore Cosmos »). |
| **Cible** | Compte `cosmos-certigo-<env>-<suffixe>`, base `certigo`, RG `rg-certigo-<env>` (staging/prod). |

> **Pourquoi ce runbook ?** Le PITR est désormais **actif en IaC** sur staging/prod, mais l'audit
> (`AUDIT_Certigo.md`, section G) exige une **preuve de restauration** pour valider la stratégie de
> reprise après corruption ou suppression accidentelle de données. La restauration Cosmos PITR
> (`az cosmosdb restore`) nécessite des **credentials Azure** que **seul l'opérateur humain possède**.
> L'agent Copilot **n'a lancé aucune commande Azure** : il a **préparé** les commandes `az` exactes,
> la procédure pas-à-pas, les vérifications et le nettoyage. **C'est vous qui exécutez** chaque commande.

---

## Prérequis d'accès

| Prérequis | Détail |
|---|---|
| **Rôle Azure** | `Cosmos DB Operator` **ou** `Contributor`/`Owner` sur la subscription, **+** `CosmosRestoreOperator` (data-plane restore) sur le compte source |
| **Subscription cible** | Subscription hébergeant le compte Cosmos de l'environnement à restaurer (récupérée dynamiquement, étape 1) |
| **Outil** | Azure CLI ≥ 2.60 (`az cosmosdb restore` GA) |
| **Fenêtre PITR** | **7 jours glissants** (tier `Continuous7Days`) — le `--restore-timestamp` doit être **< 7 jours** et postérieur à la création du compte |
| **Environnement éligible** | **staging** et **prod** uniquement (Continuous). **dev = Periodic → PITR indisponible** par design. |

## Ce que l'agent a préparé / ce que VOUS exécutez

- ✅ **Préparé par l'agent** : les commandes `az` exactes (preuve du mode Continuous, listing des points
  restaurables, restauration vers un **nouveau** compte, vérification, nettoyage) et les garde-fous.
- 👤 **Exécuté par vous** : `az login`, la sélection de subscription, puis les commandes ci-dessous.

> ⚠️ **Point clé Cosmos PITR** : une restauration crée **TOUJOURS un nouveau compte** cible — il n'existe
> **pas** de restauration « en place ». La prod en cours **n'est jamais écrasée** par un restore : le test
> est donc **non destructif**. Le basculement applicatif (repointage de la connection string) est une
> décision **manuelle** ultérieure, hors de ce runbook.

---

## Procédure pas-à-pas

### 1. Connexion et sélection de la subscription

```bash
az login
# Lister les subscriptions et repérer celle qui héberge le Cosmos cible
az account list --query "[].{name:name, id:id}" -o table
az account set --subscription "<SUBSCRIPTION_ID>"
az account show --query "{sub:name, id:id}" -o table
```

### 2. Récupérer le **nom exact** du compte Cosmos et **prouver** le mode Continuous

Le suffixe du compte (`uniqueString`) n'est pas figé ; on le lit dynamiquement. On en profite pour
**vérifier le gate R-02** : le `backupPolicy.type` doit être `Continuous`.

```bash
# Choisir l'environnement à restaurer : staging | prod
ENV="prod"
RG="rg-certigo-${ENV}"

# Nom exact du compte Cosmos du RG
az cosmosdb list --resource-group "$RG" \
  --query "[].{name:name, location:location, kind:kind}" -o table

# Renseigner le nom lu ci-dessus :
ACCT="<NOM_COSMOS>"   # ex. cosmos-certigo-prod-xxxxxxxxxxxx

# Preuve que le PITR est actif (gate audit R-02)
az cosmosdb show --resource-group "$RG" --name "$ACCT" \
  --query "{name:name, backupType:backupPolicy.type, tier:backupPolicy.continuousModeProperties.tier}" -o table
```

> 📌 **Attendu** : `backupType = Continuous`, `tier = Continuous7Days`. Si `backupType = Periodic`,
> vous êtes sur `dev` (normal) **ou** sur un compte non remédié → **stop**, le PITR n'est pas disponible.

### 3. Lister les comptes **restaurables** et récupérer l'`instanceId`

```bash
# instanceId = identifiant du compte restaurable ; note aussi les régions et la creationTime
az cosmosdb restorable-database-account list \
  --query "[?accountName=='${ACCT}'].{instanceId:name, location:location, creationTime:creationTime, oldestRestorableTime:oldestRestorableTimestamp}" -o table

RESTORABLE_ID="<instanceId>"
LOCATION="<region>"   # ex. northeurope (région d'écriture du compte source)
```

### 4. (Recommandé) Vérifier qu'un point de restauration est **valide** à l'instant visé

```bash
# Choisir un timestamp UTC dans la fenêtre 7 jours, ex. 5 min avant l'incident
RESTORE_TS="2026-07-06T09:15:00Z"

# Lister les bases restaurables à cet instant (doit inclure 'certigo')
az cosmosdb sql restorable-database list \
  --location "$LOCATION" \
  --instance-id "$RESTORABLE_ID" \
  --query "[].{db:resource.ownerId, eventType:resource.operationType, at:resource.eventTimestamp}" -o table
```

### 5. Restaurer vers un **nouveau** compte cible (non destructif)

```bash
# Nom du compte de restauration (distinct du compte prod). Respecter <=44 car., minuscules.
TARGET_ACCT="cosmos-certigo-${ENV}-restore"

az cosmosdb restore \
  --resource-group "$RG" \
  --account-name "$ACCT" \
  --target-database-account-name "$TARGET_ACCT" \
  --restore-timestamp "$RESTORE_TS" \
  --location "$LOCATION"
```

> ℹ️ La restauration provisionne un **compte séparé**. Elle peut prendre plusieurs minutes.
> La prod source reste **intacte et en ligne** pendant toute l'opération.

---

## Vérification

```bash
# Le compte cible doit exister avec provisioningState = Succeeded
az cosmosdb show --resource-group "$RG" --name "$TARGET_ACCT" \
  --query "{name:name, state:provisioningState, backupType:backupPolicy.type}" -o table

# La base 'certigo' et ses containers doivent être présents dans le compte restauré
az cosmosdb sql database list --resource-group "$RG" --account-name "$TARGET_ACCT" -o table
az cosmosdb sql container list --resource-group "$RG" --account-name "$TARGET_ACCT" \
  --database-name certigo -o table
```

✅ **Critère de succès** : le compte `cosmos-certigo-<env>-restore` affiche `provisioningState = Succeeded`,
la base `certigo` et ses containers sont présents, et les données reflètent l'état au `--restore-timestamp`
choisi. **Cette preuve de restore satisfait le gate R-02** (audit : « Preuve d'un restore Cosmos → valider
la stratégie de reprise »).

---

## Nettoyage / Rollback (après un test de restauration)

Le restore crée un compte **séparé** : aucun impact sur la prod. Après validation de la preuve, **supprimez
le compte de restauration test** pour éviter tout coût et toute confusion.

```bash
az cosmosdb delete --resource-group "$RG" --name "$TARGET_ACCT" --yes
```

> En cas de restauration **réelle** (incident), ne supprimez pas : basculez l'application vers le compte
> restauré (mise à jour de la connection string / du secret Key Vault `COSMOS_CONNECTION`), validez, puis
> décommissionnez l'ancien compte selon votre procédure de reprise.

---

## Notes & considérations

- **Restauration jamais « en place »** : Cosmos PITR provisionne toujours un **nouveau compte**. Prévoir le
  **repointage applicatif** (connection string / secret Key Vault) lors d'une reprise réelle.
- **Fenêtre 7 jours** : tier `Continuous7Days`. Pour une rétention 30 jours, basculer sur `Continuous30Days`
  dans `infra/modules/cosmos.bicep` (`continuousModeProperties.tier`) — impact coût.
- **`dev` = Periodic** : PITR **indisponible** en dev, par design (coût). Ne pas tenter de restore PITR sur dev.
- **Bascule Periodic → Continuous IRRÉVERSIBLE** : documentée dans `infra/modules/cosmos.bicep`
  (`backupMode`). Un compte déjà Continuous ne peut pas revenir à Periodic.
- **Serverless** : le compte Certigo est en `Serverless` / API SQL (`kind GlobalDocumentDB`) — le PITR
  Continuous est **supporté**.
- **Idempotence de la remédiation** : les trois fichiers `.bicepparam` fixent la politique ; le
  validateur `infra/validate.sh` compile les templates et refuse une posture implicite.
- **Réserve d'exécution** : l'agent ne dispose **pas** de credentials Azure → le test de restore réel n'a pas
  été exécuté ici. La remédiation IaC est validée statiquement par le build Bicep ; ce runbook fournit la
  procédure **vérifiable par l'opérateur** pour clore le volet « restauration test » du DoD.
