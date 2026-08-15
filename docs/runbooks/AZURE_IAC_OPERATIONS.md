# Exploitation IaC Azure Certigo

Ce runbook couvre les contrôles reproductibles de l'infrastructure Certigo. Les commandes de cette
section sont **read-only** sauf celles explicitement placées sous « Déploiement autorisé ».

## Validation locale

Utiliser une version Bicep épinglée, puis compiler tous les templates et paramètres :

```bash
export BICEP_BIN=/opt/bicep/0.46.1/bicep
bash infra/validate.sh
bash infra/ci-runner/validate.sh
```

Le validateur compile tous les templates et tous les paramètres. Il impose des CIDR explicites et
non partagés par environnement, l'accès public désactivé sur Storage / Cosmos / Key Vault, la
topologie private endpoint/DNS complète, une politique Cosmos explicite, un destinataire d'alerte
hors dev et l'identité utilisateur FC1 préprovisionnée.

```bash
node --test infra/tests/cosmos-indexing-policy.test.mjs \
  infra/tests/private-networking.test.mjs
checkov --directory infra --framework bicep --compact --quiet \
  --config-file .checkov.yaml
```

## Diagnostics Azure read-only

L'hôte de cette remédiation ne possède ni Azure CLI ni session Azure authentifiée. Un opérateur
autorisé doit exécuter exactement les commandes suivantes :

```bash
az login
az account show --query "{subscription:name,id:id,tenantId:tenantId,user:user.name}" -o table
az account set --subscription "<SUBSCRIPTION_ID>"

ENV="staging" # puis prod
RG="rg-certigo-${ENV}"

az resource list -g "$RG" \
  --query "[].{name:name,type:type,state:properties.provisioningState}" -o table

FUNC="$(az functionapp list -g "$RG" --query '[0].name' -o tsv)"
STORAGE="$(az storage account list -g "$RG" --query '[0].name' -o tsv)"
COSMOS="$(az cosmosdb list -g "$RG" --query '[0].name' -o tsv)"
KV="$(az keyvault list -g "$RG" --query '[0].name' -o tsv)"
APPI="$(az resource list -g "$RG" --resource-type Microsoft.Insights/components \
  --query '[0].name' -o tsv)"

az functionapp show -g "$RG" -n "$FUNC" \
  --query "{state:state,host:defaultHostName,identities:identity,config:properties.functionAppConfig}" -o json
az role assignment list --scope "$(az storage account show -g "$RG" -n "$STORAGE" --query id -o tsv)" \
  --query "[].{principalId:principalId,role:roleDefinitionName,scope:scope}" -o table
az storage account show -g "$RG" -n "$STORAGE" \
  --query "{publicNetworkAccess:publicNetworkAccess,sharedKey:allowSharedKeyAccess,defaultAction:networkRuleSet.defaultAction}" -o table
az cosmosdb show -g "$RG" -n "$COSMOS" \
  --query "{publicNetworkAccess:publicNetworkAccess,localAuthDisabled:disableLocalAuth,backup:backupPolicy}" -o json
az keyvault show -g "$RG" -n "$KV" \
  --query "{publicNetworkAccess:properties.publicNetworkAccess,rbac:properties.enableRbacAuthorization,defaultAction:properties.networkAcls.defaultAction}" -o table
az network vnet subnet show -g "$RG" --vnet-name "vnet-certigo-${ENV}" \
  -n snet-functions \
  --query "{prefix:addressPrefix,delegation:delegations[0].serviceName}" -o table
az network vnet subnet show -g "$RG" --vnet-name "vnet-certigo-${ENV}" \
  -n snet-private-endpoints \
  --query "{prefix:addressPrefix,privateEndpointPolicies:privateEndpointNetworkPolicies}" -o table
az network private-endpoint list -g "$RG" \
  --query "[].{name:name,groupIds:privateLinkServiceConnections[0].groupIds,status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
  -o table
az network private-dns zone list -g "$RG" --query "[].name" -o tsv
az functionapp config show -g "$RG" -n "$FUNC" \
  --query "{routeAll:vnetRouteAllEnabled}" -o table
az role assignment list \
  --scope "$(az monitor app-insights component show -g "$RG" -a "$APPI" --query id -o tsv)" \
  --query "[].{principalId:principalId,role:roleDefinitionName}" -o table
az policy assignment show --name certigo-mcsb \
  --query "{name:name,enforcementMode:enforcementMode,definition:policyDefinitionId}" -o table
az security pricing list \
  --query "value[?name=='AppServices'||name=='StorageAccounts'||name=='KeyVaults'||name=='CosmosDbs'].{plan:name,tier:pricingTier}" -o table
az monitor action-group show -g "$RG" -n ag-certigo-security \
  --query "{enabled:enabled,receivers:emailReceivers[].emailAddress}" -o json

HOST="$(az functionapp show -g "$RG" -n "$FUNC" --query defaultHostName -o tsv)"
curl --fail --show-error "https://${HOST}/api/health/live"
curl --fail --show-error "https://${HOST}/api/health/ready"
```

Résultats attendus : package `UserAssignedIdentity`, rôles Blob Data Owner/Contributor + Queue/Table
Contributor, réseau `Disabled/Deny`, cinq connexions private endpoint `Approved`, cinq zones DNS,
subnet FC1 délégué à `Microsoft.App/environments`, route-all actif, authentification locale
Storage/Cosmos désactivée hors dev et readiness `healthy` pour Cosmos, Storage et Key Vault.

## Prévol sans mutation

```bash
PARAMETERS_DIRECTORY="$(mktemp -d)"
chmod 700 "$PARAMETERS_DIRECTORY"
BASE_PARAMETERS_FILE="$PARAMETERS_DIRECTORY/base.json"
AUTH_PARAMETERS_FILE="$PARAMETERS_DIRECTORY/auth.json"
trap 'rm -rf -- "$PARAMETERS_DIRECTORY"' EXIT

# Charger AUTH_JWT_SIGNING_KEY et AUTH_JWT_SIGNING_KEY_EXPIRES_ON depuis le
# gestionnaire de secrets autorisé, sans les écrire dans la ligne de commande.
export TARGET_ENV="$ENV"
export BASE_PARAMETERS_FILE AUTH_PARAMETERS_FILE
az bicep build-params \
  --file "infra/params/${ENV}.bicepparam" \
  --outfile "$BASE_PARAMETERS_FILE"
node .github/scripts/write-secure-bicep-parameters.mjs
az deployment sub what-if \
  --name "certigo-${ENV}-preflight" \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters "@$AUTH_PARAMETERS_FILE"
```

Refuser l'application si le what-if annonce une suppression, un remplacement du compte Cosmos,
une Function App créée avant le déploiement `privateNetwork`, une private endpoint sans zone group,
ou une baisse inattendue de Defender.
La date d'expiration JWT est une entrée absolue auditée : ne pas utiliser `utcNow()`, ne pas la
repousser sans changer la clé, et appliquer la procédure de chevauchement décrite dans
`docs/deployment-runbook.md` avant toute rotation.

## Ordre de déploiement autorisé

1. **Dev** : appliquer l'IaC ; le module réseau doit terminer avant la Function App. Vérifier cinq
   connexions privées approuvées, l'intégration `snet-functions` et route-all, puis publier le
   backend et vérifier `/health/live` puis `/health/ready`.
2. **Staging** : fournir la clé JWT sécurisée et son expiration absolue, appliquer l'IaC, attendre
   la propagation RBAC, publier, tester alertes et restauration PITR vers un nouveau compte.
3. **Production** : fenêtre de changement approuvée, preuve du what-if, sauvegarde/PITR vérifiée,
   appliquer l'IaC puis publier ; ne jamais inverser cet ordre.
4. **Runner CI** : le cycle start/stop reste une opération séparée et autorisée ; aucun script de
   validation de ce dépôt ne démarre, n'arrête ou ne détruit une VM.

## Risques de migration

- La bascule Cosmos `Periodic` vers `Continuous` est irréversible.
- `DisableLocalAuth=true` sur Application Insights exige le rôle `Monitoring Metrics Publisher`
  avant le redémarrage de l'application.
- L'identité utilisateur FC1 et ses rôles doivent exister avant la mise à jour de
  `functionAppConfig.deployment.storage`.
- Le subnet Flex doit être dédié, dans la même région que l'app, délégué à
  `Microsoft.App/environments` et au minimum `/27`. Certigo réserve `/26`. Référence :
  [Flex Consumption virtual network
  integration](https://learn.microsoft.com/azure/azure-functions/flex-consumption-how-to#configure-virtual-network-integration).
- Le subnet private endpoint ne doit jamais être réutilisé pour l'intégration Flex. Les zones DNS
  suivent les [valeurs officielles Azure Private
  Endpoint](https://learn.microsoft.com/azure/private-link/private-endpoint-dns).
- Defender et MCSB sont au scope abonnement : un seul environnement doit posséder les paramètres
  Defender, et MCSB reste `DoNotEnforce` tant que les exemptions/remédiations ne sont pas validées.
- Ne jamais réintroduire de fallback public ou de toggle partiel : la policy Storage désactive
  l'accès public et l'application dépend de la topologie privée complète.

## Interdictions opérationnelles

Sans ticket de changement, preuve de what-if et autorisation effective, ne pas exécuter
`az deployment ... create`, `az vm start`, `az vm deallocate`, `az group delete`,
`az cosmosdb restore` ou `az cosmosdb delete`.
