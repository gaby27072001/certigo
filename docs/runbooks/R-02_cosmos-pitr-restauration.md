# R-02 — Restauration Point-In-Time (PITR) du compte Cosmos DB

| Champ | Valeur |
|---|---|
| **Finding** | R-02 (🟠 Moyen) |
| **Constat audit** | Cosmos prod en backup **Periodic** à l'origine (aucun `backupPolicy` dans le Bicep → défaut Periodic). Pas de PITR : récupération limitée aux snapshots périodiques en cas de corruption/suppression prod. |
| **Remédiation IaC** | `cosmosBackupMode` est explicite par environnement : staging/prod `Continuous` + `Continuous7Days`, dev `Periodic` avec intervalle, rétention et redondance déclarés. |
| **Objet de ce runbook** | Documenter la **procédure de restauration** PITR (gate audit : « preuve d'un restore Cosmos »). |
| **Cible** | Compte `cosmos-certigo-<env>-<suffixe>`, base `certigo`, RG `rg-certigo-<env>` (staging/prod). |
| **Statut du gate** | ✅ **Satisfait le 2026-09-04** — restauration réelle exécutée sur **staging**. Voir [Preuve de restauration](#preuve-de-restauration-exécutée-le-2026-09-04). |

> **Pourquoi ce runbook ?** Le PITR est désormais **actif en IaC** sur staging/prod, mais le
> registre de risques (`docs/ETAT_DU_PROJET.md` §14, finding R-02) exige une **preuve de
> restauration** pour valider la stratégie de reprise après corruption ou suppression accidentelle
> de données.
>
> ✅ **Cette preuve existe désormais** : une restauration réelle a été exécutée sur **staging** le
> **2026-09-04** (durée 708 s, 8 containers vérifiés, compte temporaire supprimé). Voir
> [Preuve de restauration](#preuve-de-restauration-exécutée-le-2026-09-04). La procédure ci-dessous
> reste la référence pour une reprise réelle, notamment sur **production**, où elle doit être
> exécutée par un opérateur humain.

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

> 🛡️ **Garde-fou obligatoire avant toute suppression — à reprendre tel quel.**
> Les noms du compte source et du compte restauré ne diffèrent que par un suffixe. Une faute de
> frappe supprimerait la base réelle. **Ne vous fiez pas à la relecture du nom** : faites vérifier
> par la machine une propriété que **seul** le compte restauré possède.
>
> Un compte issu d'un restore porte `createMode = Restore`. Un compte normal porte `createMode = Default`.
> Cette assertion rend la suppression du source **structurellement impossible**, et pas seulement
> improbable :

```bash
SUB="<SUBSCRIPTION_ID>"
RG="rg-certigo-staging"
TARGET="cosmos-certigo-staging-pitrtest"   # le compte TEMPORAIRE, jamais le source

# Garde-fou 1 : le compte cible DOIT être un compte restauré.
MODE=$(az cosmosdb show --subscription "$SUB" -g "$RG" -n "$TARGET" --query "createMode" -o tsv)
[ "$MODE" = "Restore" ] || { echo "ABORT: $TARGET n'est pas un compte restauré (createMode=$MODE)"; exit 1; }

# Garde-fou 2 : le compte cible ne doit jamais être le compte source.
[ "$TARGET" != "cosmos-certigo-staging-hwbsyiwa7tqnw" ] || { echo "ABORT: cible == source"; exit 1; }

az cosmosdb delete --subscription "$SUB" -g "$RG" -n "$TARGET" --yes
```

Vérification après suppression — il ne doit rester que le compte source, en `createMode = Default` :

```bash
az cosmosdb list --subscription "$SUB" -g "$RG" \
  --query "[].{name:name, mode:createMode, state:provisioningState}" -o table
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
- **Réserve d'exécution** : ~~l'agent ne dispose pas de credentials Azure~~ — **levée le 2026-09-04**.
  La restauration a été **réellement exécutée** sur staging (voir la section « Preuve de restauration »
  ci-dessous). La remédiation IaC reste validée statiquement par le build Bicep.

---

## Preuve de restauration (exécutée le 2026-09-04)

Le gate audit R-02 exigeait une **preuve** de restauration, pas seulement une procédure. Cette
restauration a été réalisée de bout en bout sur **staging uniquement** (jamais la production), puis
le compte temporaire a été supprimé.

### Paramètres réels de l'opération

| Élément | Valeur mesurée |
|---|---|
| Date d'exécution | **2026-09-04** |
| Environnement | **staging** (production non touchée) |
| Compte source | `cosmos-certigo-staging-hwbsyiwa7tqnw` (RG `rg-certigo-staging`) |
| Politique du source | `backupPolicy.type = Continuous`, `tier = Continuous7Days` |
| `instanceId` restaurable | `8c121a29-e94a-4ed4-a838-4fc61e516786` |
| Région | North Europe |
| **`--restore-timestamp` utilisé** | **`2026-09-04T16:30:00Z`** (dans la fenêtre 7 jours) |
| Compte cible temporaire | `cosmos-certigo-staging-pitrtest` |
| **Durée de la restauration** | **708 s (≈ 11 min 48 s)** |
| **Durée de la suppression** | **725 s (≈ 12 min 5 s)** |

### Résultat vérifié

Le compte restauré s'est provisionné avec `provisioningState = Succeeded`, en mode
`createMode = Restore` / `restoreMode = PointInTime`, avec
`restoreTimestampInUtc = 2026-09-04T16:30:00+00:00`.

La base `certigo` et ses **8 containers** ont été restaurés, **identiques au compte source** :

```text
progress, leaderboard, friends, attempts, events, users, content, economy
```

Le compte source est resté `Succeeded` et `Continuous` pendant toute l'opération — confirmant le
caractère **non destructif** de la restauration PITR.

### Nettoyage vérifié

Le compte temporaire a été supprimé, avec un garde-fou explicite avant suppression : la commande a
vérifié que `createMode = Restore` (le compte source est `Default`), ce qui rend impossible la
suppression accidentelle du compte source par confusion de nom.

Après suppression, `az cosmosdb list -g rg-certigo-staging` ne renvoie plus que le compte source :

```json
[ { "name": "cosmos-certigo-staging-hwbsyiwa7tqnw", "mode": "Default", "state": "Succeeded" } ]
```

### Note sur les verrous `CanNotDelete`

Les cinq ressources staging (Function App, Cosmos, Key Vault, Storage, Log Analytics) portent un
verrou `CanNotDelete`. Ces verrous protègent les **ressources sources** et **n'ont pas gêné**
l'opération : un compte restauré est une **nouvelle** ressource, créée sans verrou. Aucun verrou
n'a été retiré ni modifié.

### Enseignements pour une reprise réelle

- **Budget temps** : compter **~12 minutes** pour qu'un compte restauré soit exploitable
  (mesure réelle sur un compte serverless de petite taille). À ajouter au RTO.
- La restauration **hérite** de la configuration réseau du source : le compte restauré est sorti
  avec `publicNetworkAccess = Disabled` et `disableLocalAuth = true`. Un accès data-plane depuis
  l'extérieur du VNet n'est donc **pas** possible immédiatement — le prévoir dans le plan de reprise.
- La restauration **ne crée pas** d'endpoint privé : lors d'une reprise réelle, il faudra créer le
  private endpoint et le repointage applicatif avant que l'application puisse joindre le compte.

