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
topologie private endpoint/DNS complète, le peering bidirectionnel avec le VNet CI, une politique
Cosmos explicite, un destinataire d'alerte hors dev, l'identité utilisateur FC1 préprovisionnée et
le rôle Blob minimal du principal OIDC de déploiement.

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
STORAGE_ID="$(az storage account show -g "$RG" -n "$STORAGE" --query id -o tsv)"
PACKAGE_SCOPE="${STORAGE_ID}/blobServices/default/containers/app-package"
az role assignment list --scope "$STORAGE_ID" \
  --query "[].{principalId:principalId,role:roleDefinitionName,scope:scope}" -o table
az role assignment list --scope "$PACKAGE_SCOPE" \
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
az network private-dns zone list -g rg-certigo-ci --query "[].name" -o tsv
az network vnet peering show -g "$RG" --vnet-name "vnet-certigo-${ENV}" \
  -n peer-to-vnet-certigo-ci --query peeringState -o tsv
az network vnet peering show -g rg-certigo-ci --vnet-name vnet-certigo-ci \
  -n "peer-to-vnet-certigo-${ENV}" --query peeringState -o tsv
CI_VNET_ID="$(az network vnet show -g rg-certigo-ci -n vnet-certigo-ci --query id -o tsv)"
APP_VNET_ID="$(az network vnet show -g "$RG" -n "vnet-certigo-${ENV}" --query id -o tsv)"
for ZONE in privatelink.blob.core.windows.net privatelink.queue.core.windows.net \
  privatelink.table.core.windows.net privatelink.vaultcore.azure.net \
  privatelink.documents.azure.com; do
  az network private-dns link vnet list -g rg-certigo-ci -z "$ZONE" \
    --query "[?virtualNetwork.id=='$CI_VNET_ID'||virtualNetwork.id=='$APP_VNET_ID'].{name:name,state:provisioningState}" -o table
done
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

Résultats attendus : package `UserAssignedIdentity`, rôles runtime Blob Data Owner/Contributor +
Queue/Table Contributor, principal OIDC CI limité à `Storage Blob Data Contributor` sur
`app-package` et `Storage Blob Delegator` sur le compte, réseau `Disabled/Deny`, cinq connexions
private endpoint `Approved`, cinq zones DNS partagées dans `rg-certigo-ci` avec les liens CI et
applicatif, deux peerings `Connected`, subnet FC1 délégué à `Microsoft.App/environments`, route-all
désactivé, authentification locale Storage/Cosmos désactivée hors dev et readiness `healthy`.

### Migration initiale des zones privées par environnement

Avant la première application de chaque environnement, planifier une fenêtre de
changement. Les cinq zones du groupe applicatif (`dev`, `staging`, puis `prod`)
doivent être retirées avant de lier leurs remplaçantes de même namespace.
Lister et supprimer l'unique zone group de chacun des cinq private endpoints,
puis les cinq zones du groupe ; ne supprimer ni endpoint ni VNet. Ne pas
supprimer la zone OpenAI de dev, ni la zone Vault partagée de `rg-certigo-ci`,
ni son lien `vnet-certigo-ci-kv-dnslink`. Appliquer immédiatement le template
de l'environnement, qui adopte le réseau live et rattache liens et zone groups
au jeu partagé. Vérifier les dix liens et la résolution privée avant de passer
à l'environnement suivant.

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
   connexions privées approuvées, les peerings, les liens DNS CI, l'intégration au subnet FC1 attendu et
   route-all désactivé. Le CD publie ensuite via
   `.github/scripts/deploy-flex-onedeploy.sh` et bloque tant que `/health/live` puis
   `/health/ready` ne sont pas verts.
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
- Flex Consumption n'exige pas Route All pour joindre les endpoints privés RFC1918. Tant qu'aucun
  NAT Gateway/firewall n'est associé à `snet-functions`, conserver
  `vnetRouteAllEnabled=false` afin que les dépendances publiques utilisent l'egress plateforme.
  Référence : [Azure Functions networking
  options](https://learn.microsoft.com/azure/azure-functions/functions-networking-options?tabs=azure-portal#regional-virtual-network-integration).
- Defender et MCSB sont au scope abonnement : un seul environnement doit posséder les paramètres
  Defender, et MCSB reste `DoNotEnforce` tant que les exemptions/remédiations ne sont pas validées.
- Ne jamais réintroduire de fallback public ou de toggle partiel : la policy Storage désactive
  l'accès public et l'application dépend de la topologie privée complète.
- La purge protection Key Vault reste activée dans tous les environnements. Son activation est
  irréversible et remplace l'ancienne exception Checkov de développement.
- Ne jamais remplacer le SAS user delegation par une clé de compte. Le SAS lecture seule de
  14 minutes n'accorde qu'une autorisation data-plane ; il ne contourne pas le pare-feu Storage.
  Le runner doit résoudre le FQDN Blob vers l'IP du private endpoint avant tout upload, et le blob
  `deployments/<commit-sha>.zip` ne peut être réutilisé que si son SHA-256 est identique. Le script
  ne le supprime pas après OneDeploy : la policy lifecycle bornée à 30 jours cible exclusivement
  `app-package/deployments/`.
- OneDeploy est invoqué par PUT ARM direct. Ne jamais revenir à une corrélation par « dernier
  déploiement » : seul l'en-tête `Azure-AsyncOperation` ou `Location` renvoyé par le PUT exact peut
  être interrogé. L'absence d'en-tête, une URL hors `management.azure.com`, un statut inconnu ou un
  timeout sont bloquants. Jeton ARM, SAS, corps, en-têtes et réponses restent dans des fichiers
  temporaires `0600` détruits par `trap`.

## Interdictions opérationnelles

Sans ticket de changement, preuve de what-if et autorisation effective, ne pas exécuter
`az deployment ... create`, `az vm start`, `az vm deallocate`, `az group delete`,
`az cosmosdb restore` ou `az cosmosdb delete`.
