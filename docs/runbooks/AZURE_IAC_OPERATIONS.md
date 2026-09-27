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
BICEP_CLI="$BICEP_BIN" node --test infra/tests/cosmos-indexing-policy.test.mjs \
  infra/tests/private-networking.test.mjs \
  infra/tests/content-storage.test.mjs
checkov --directory infra --framework bicep --compact --quiet \
  --config-file .checkov.yaml
```

Le stack de publication de contenu est volontairement séparé des environnements
applicatifs. Il fournit un endpoint Blob unique, trois conteneurs et une UAMI
reader que #304 doit attacher à la Function App. Son what-if, son futur lock
WORM et son rollback sont décrits dans
[`IMMUTABLE_CONTENT_STORAGE.md`](./IMMUTABLE_CONTENT_STORAGE.md).
L'alignement LRS du contenu du 25 septembre et ses plans racine dédiés sont
consignés dans « Alignement LRS du contenu » de ce runbook. Ils ne remplacent
pas la preuve racine applicative/OIDC encore requise pour `wp-p1-12` / `wp-p1-13`.

## Diagnostics Azure read-only

L'inventaire du 4 septembre 2026 a été capturé avec Azure CLI en lecture seule.
Pour toute nouvelle preuve, un opérateur autorisé exécute les commandes suivantes :

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

### Staging live à réconcilier, pas à recréer

`rg-certigo-staging` existe et est peuplé. Le déploiement subscription
`certigo-staging` a terminé `Succeeded` le 2026-08-16 à 13:45:34 UTC, en mode
`Incremental` (correlation ID `22b74f66-9ba9-4030-8b1d-bdd6978b2b00`).
Storage, Cosmos, Key Vault, Function App, VNet, private endpoints et alertes sont
présents; `/api/health/live`, `/api/health/ready` et `/api/health` répondent 200.
Le RG et les ressources principales portent `managedBy=bicep`.

La procédure staging est donc un **what-if de réconciliation** sur l'existant.
Ne jamais lancer `az group create`, `az group delete` ou planifier la stack comme
une création initiale. Toute création/suppression annoncée par le what-if est
bloquante jusqu'à explication ressource par ressource.

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

### Gouvernance MCAPS et LRS du 24 septembre 2026

La décision de l'orchestrateur du **24 septembre 2026 à 15:22 UTC** accepte
temporairement `Standard_LRS` pour le stockage **applicatif staging et prod**.
La condition « écart LRS non intentionnel » est levée par cette consignation ;
`infra/main.bicep` est aligné sans modifier une autre propriété Storage. Le stack
contenu, les runners, les droits et les workflows sont hors de ce changement.
La [preuve structurée](../migration/evidence/2026-09-24-mcaps-lrs.json) contient
l'inventaire, les corps de requête expurgés, les corrélations, les mesures live
et tous les deltas du what-if. Elle remplace les conclusions opérationnelles
de la photographie précédente, sans réécrire ses mesures historiques.

**Risque accepté, pas équivalence de durabilité :** LRS n'offre pas de copie
interrégionale du stockage applicatif. Une perte ou panne régionale peut
entraîner une **perte de données ou une indisponibilité**. Restauration Blob
29 jours, versioning, change feed, soft-delete Blob/conteneur 30 jours et
sauvegardes Cosmos `Continuous7Days` (staging) / `Continuous30Days` (prod)
sont conservés ; ils **ne remplacent pas une copie interrégionale**. Les GET
ARM du 24 septembre à 15:38 UTC confirment ces protections, LRS, accès public
désactivé et clés partagées désactivées sur les deux comptes Storage.
Cette photographie précède la promotion prod en cours et ne vaut pas mesure
postérieure à celle-ci.

**Inventaire Activity Log, pas inventaire des données :** fenêtre fermée du
**2026-08-25T15:28:00Z au 2026-09-24T15:28:00Z**, uniquement
`rg-certigo-staging` et `rg-certigo-prod`. API ARM `2015-04-01`, filtre serveur
sur le RG exact et les deux bornes ; chaque `nextLink` a été suivi jusqu'à
son absence (cinq pages par RG, aucun plafond `max-events`). Attribution
par les claims exacts `appid=a1a9c5b6-7a4f-4288-89ab-6805873f65d1` **et**
object ID `da847d8c-ee71-44de-b462-6775e7d649a7`, tenant du principal
`975f013f-7f24-47e8-a7d3-abc4752bf346`, distinct du tenant de la souscription.
Le nom fourni `MCAPSGovernance-AutomationApp` n'est pas utilisé comme filtre.
La collecte conserve les collisions d'`eventDataId` : seules les copies
identiques du JSON complet sont dédupliquées. Les sommes et SHA-256 des pages
sont consignés ; les bruts restent locaux, non versionnés. Aucun jeton,
claim complet, adresse personnelle, IP appelante, valeur de tag ou corps
de réponse libre n'est publié. Une ingestion ARM tardive peut compléter
cette fenêtre historique ; aucune conclusion n'est étendue hors de celle-ci.

| RG | Événements lus / attribués | Started | Accepted | Succeeded | Canceled | Failed | Groupes d'écriture réussis / annulés |
|---|---|---|---|---|---|---|---|
| staging | 768 / 51 | 16 | 6 | 28 | 1 | 0 | 7 / 1 |
| prod | 672 / 35 | 11 | 5 | 18 | 1 | 0 | 5 / 1 |

Les 27 évaluations `auditIfNotExists` staging et 17 prod ne sont **pas**
des mutations réussies. Les groupes normalisent la casse des resource IDs
et actions, puis regroupent par `(correlationId, resource, action)` sans
perdre les événements ni leurs états individuels :

- Storage : PATCH `sku.name=Standard_LRS`, staging le 10 et le 24 septembre,
  prod le 10 septembre. La dernière requête staging est à
  `2026-09-24T00:57:06.3620927Z`, corrélation
  `6c62ae30-fbbf-4b6d-9e3b-c1b1edcb649b`.
- VNet : staging six écritures (cinq réussies, une annulée), prod quatre
  (trois réussies, une annulée). Les corps soumis incluent les associations
  NSG des subnets, adresses, délégations, politiques private endpoint,
  DHCP, peerings et `enableDdosProtection=false`. Les valeurs intégrales
  non sensibles sont conservées par requête dans la preuve.
- NSG prod : écriture réussie du 9 septembre sur
  `vnet-certigo-prod-snet-seed-nsg-westeurope`, `securityRules=[]`,
  corrélation `b5f87b36-41ac-44b2-9c6c-7c3fb15d60db`.

Ces corps décrivent des **valeurs demandées**, pas un diff avant/après :
ne pas affirmer que chaque champ fourni a changé, ni transformer une
tentative annulée en mutation effective. Les opérations historiques réseau
ne prouvent pas à elles seules une dérive actuelle ; aucune correction
réseau n'est appliquée dans ce lot. Le patching runners du 15 septembre
est exclu du périmètre et des comptes ci-dessus.

**What-if Storage staging uniquement :** `mcaps-lrs-staging-20260924153854`,
terminé le 24 septembre à 15:39:31 UTC, validation `Provider`, Bicep
`0.44.1`. Module courant compilé, paramètres non secrets du déploiement
`storage`, avec `skuName=Standard_LRS` et `blobRestoreDays=29` lus dans la
racine candidate compilée. Le compte est `NoChange`, sans delta SKU :
l'écart GRS/LRS disparaît. Résultat : zéro ressource Create/Delete,
trois Modify, quatre NoChange, **41 Ignore non analysés**, jamais assimilés
à NoChange. Restent les suppressions de propriétés par défaut
`allowPermanentDelete=false`, `defaultEncryptionScope=$account-encryption-key`
et `denyEncryptionScopeOverride=false` ; aucun ajustement opportuniste.
Ce résultat ne couvre ni la racine abonnement, ni prod, ni les autres modules.

**Cosmos :** le déploiement racine staging réel du 23 septembre à
19:11:17.963991 UTC (`az deployment sub create`, corrélation
`83abb79d-74eb-49e3-b607-b6fa3cfd5bb3`) a réussi via
[CD 35907227638](https://github.com/gchambaud_microsoft/Certigo/actions/runs/35907227638),
source `25a75bf38a24f867cf27fb27e238e703facdcabb`, antérieure à #518.
Le GET ARM `2024-11-15` mesure encore `enablePartitionKeyMonitor=true`
après cet apply : **aucune désactivation durable observée**. Ce n'était
pas un what-if et ce n'est pas un préflight actuel ; cette observation
n'établit pas que tous les futurs deltas Cosmos seront inoffensifs.

**Blocage exact maintenu :** `wp-p1-12` et `wp-p1-13` restent `blocked`.
Il faut un mode CD **« what-if seul »**, exécuté avec l'identité **OIDC
autorisée et les vrais secrets**, conservant la **sortie brute en artefact**,
**sans apply**, puis une classification de tout le plan racine staging.
La session propriétaire des workflows scellés conçoit ce mode ; ce lot
ne touche pas CD. Aucun script à secrets factices ne remplace cette preuve.
L'opérateur parent lancera ce mode une fois livré ; ne pas relancer le CD
actuel pour obtenir un plan, car il applique. Aucun what-if prod pendant
la promotion Phase 2. La PR d'alignement/inventaire attend un feu vert
**explicite** de l'orchestrateur avant fusion, sans auto-merge.

Toute modification des templates, paramètres effectifs, policies, déploiements
ou ressources mesurées invalide la photographie live et nécessite une nouvelle
mesure ; l'inventaire reste une preuve bornée de la fenêtre ci-dessus.

#### Associations NSG MCAPS : complément autorisé, sans apply

L'orchestrateur a ensuite autorisé l'adoption **déclarative des associations
uniquement**, vers les NSG MCAPS **existants** des deux subnets applicatifs
staging/prod. Les paramètres environnementaux donnent leurs noms exacts ;
le module `privateNetwork` ne déploie **aucun NSG ni aucune règle NSG**.
CIDR, délégation Flex `Microsoft.App/environments`, politiques de private
endpoint, peerings et endpoints ne sont pas modifiés par ce correctif.
Dev conserve son absence d'association explicite. Aucun réattachement manuel,
création de NSG ou reconstitution de `snet-seed` n'est effectué.

**Compatibilité :** la documentation
[Functions / Flex networking](https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options?pivots=flex-consumption-plan)
autorise un NSG sur le subnet d'intégration. Les règles par défaut observées
autorisent les sorties VNet/Internet et aucune règle personnalisée n'est
présente. Le subnet des private endpoints reste distinct, avec
`privateEndpointNetworkPolicies=Disabled` : selon
[Private Link / network policies](https://learn.microsoft.com/en-us/azure/private-link/disable-private-endpoint-network-policy),
l'association du NSG **n'active pas son filtrage sur le trafic des private
endpoints**. Il s'agit de conserver le contrat de gouvernance, pas de
revendiquer une nouvelle isolation réseau. Le what-if Provider valide le
plan sans prouver le comportement runtime d'un futur apply.

**Différence historique/post-apply prod prouvée :** job « Prepare infrastructure
(prod) » du [run 36022032292](https://github.com/gchambaud_microsoft/Certigo/actions/runs/36022032292),
source `a765aef618948723a35e4dc9ca45c3b919e3329c`, réussi entre 15:42:23 et
15:46:26 UTC. GET ARM réseau `2024-05-01` à 15:47:16–15:47:39 UTC :
les subnets `snet-func-flex` et `snet-private-endpoints` existent mais leurs
associations NSG sont absentes. Elles figuraient dans l'écriture MCAPS
réussie du 9 septembre à 22:13:36–22:13:40 UTC, corrélation
`86c0749d-3799-43a4-88ee-93f6c507ff18`. Les trois NSG applicatifs observés
(Flex, private endpoints, seed) existent, sans subnet attaché, avec
`securityRules=[]` et leurs règles par défaut. Aucune règle personnalisée
supprimée n'est prouvée. **Sans GET immédiatement avant apply, la causalité
du seul run courant n'est pas démontrée.** Cet écart de conformité ne
constitue pas une preuve de panne ou d'exposition publique.

`snet-seed` apparaît dans la requête réussie du 9 septembre à 14:14:33 UTC
(`b100b853-562d-4a01-91c1-2648963419c6`) mais est absent de la mesure actuelle.
Sa disparition n'est pas datée par ces seules preuves et n'est pas attribuée
à cette promotion. Il reste hors code ; aucune recréation n'est demandée.

**What-if réseau staging :** `mcaps-nsg-staging-20260924155601`, Provider,
réussi à 15:56:24 UTC. Les deux associations MCAPS déjà présentes sont
identiques dans `before` et `after` ; le correctif **les conserve** au lieu
de les omettre. Douze Modify, 36 Ignore, zéro ressource Create/Delete ;
les deltas complets de métadonnées/defaults des VNets, peerings et zone
groups sont conservés dans la preuve, sans correction opportuniste ni
assimilation d'Ignore à NoChange. Les NSG et règles ne sont pas écrits.
En prod, l'association prévue est intentionnelle par rapport au GET
post-apply, mais **aucun what-if prod** n'est exécuté durant le gel.
La future promotion normale doit refaire ses contrôles autorisés.

**Observation de réassociation automatique :** une seconde mesure prod à
15:57:33 UTC trouve encore les deux associations absentes. Le journal
15:40:00–15:57:23 UTC, deux pages épuisées, ne retourne aucun événement
attribué à l'identité MCAPS exacte. Ce constat borné ne prouve pas que la
gouvernance ne réessaiera pas plus tard ; aucune cadence n'est déduite.
Les mesures ultérieures éventuelles sont enregistrées séparément dans
`productionReassociationObservations` de la preuve.
Le contrôle suivant à 16:06:02 UTC retrouve la même absence ; deux pages
épuisées sur 15:40:00–16:05:58 UTC, toujours aucun événement MCAPS attribué.
La durée de réassociation reste donc inconnue, pas « zéro » ni « jamais ».

**Réassociation ensuite observée, sans intervention :** au GET
`2026-09-24T16:16:27.862079Z`, les deux NSG prod sont de nouveau associés.
La collecte complémentaire, bornée à `16:16:22Z` et paginée jusqu'à épuisement,
attribue les requêtes à la même paire exacte appid/object ID :

- `16:13:55.6564296Z`, corrélation `811dad59-5bd0-4898-93d6-00e7e3bad7a9` :
  requête VNet associant Flex, puis `Succeeded` à `16:13:57.6477184Z`.
- `16:13:57.6664758Z`, corrélation `67bcc28f-6194-4932-9728-91277811c609` :
  requête VNet avec les deux associations, `Accepted` à `16:13:57.8852213Z`.
  Son événement terminal n'est pas encore retourné dans cette collecte ;
  le GET confirme néanmoins les deux liens effectifs.

Le premier démarrage observé arrive environ **27 min 30 s après la fin du job
infra**. Cette seule séquence ne définit ni cadence, ni délai garanti. Elle
montre que les associations absentes à 16:06 ont été rétablies automatiquement,
sans prouver quand ni par quelle opération leur retrait initial a eu lieu.
L'adoption IaC évite de continuer à omettre ces liens lors d'une promotion.

### Réconciliation staging du 23 septembre 2026

**Périmètre de preuve :** mesures en lecture seule depuis le commit
`43e06a5f6cdc2dbcd84fb2dd00152f29d2ae0bd9`, puis what-if du module Storage corrigé
dans cette livraison. Abonnement `b8952c8c-8f72-469d-99cd-ac906da4e2fc`,
tenant `16b3c013-d300-468d-ac64-7eda0820b6d3`. Aucun apply, changement d'accès,
rotation de secret, modification de runner ou activation du tuteur.
Les résultats structurés et les deltas complets des ressources analysées sont
dans [la preuve de préflight](../migration/evidence/2026-09-23-staging-iac.json).
Cette photographie est invalidée par toute modification des templates,
paramètres effectifs, variables GitHub, déploiements, policies ou ressources
Azure concernés ; elle n'autorise aucun déploiement ultérieur.

| Mesure | Résultat vérifié |
|---|---|
| PR de réconciliation | [#371](https://github.com/gchambaud_microsoft/Certigo/pull/371) fusionnée le 8 septembre à 15:28:20 UTC |
| Déploiement racine | `certigo-staging`, `Succeeded`, 9 septembre à 20:40:09 UTC ; correlation ID `2bffde7e-22e5-4b6a-8c9b-39bf68196473` |
| CD correspondant | [34402007646](https://github.com/gchambaud_microsoft/Certigo/actions/runs/34402007646), `success`, source `10c0c834b63c48410e161cf44ae6c608bdd41cad` |
| Variables GitHub staging | `PUBLIC_WEB_ORIGIN=https://www.certigo-app.com`, `PUBLIC_DOMAIN_VERIFIED=true`, `APPLE_CIAM_DOMAIN_RECONFIGURED=false` |
| Pages publiques | GET HTTPS `/privacy-policy/` : 200, sans désactiver la validation TLS |
| Santé à 19:02–19:03 UTC | `/api/health/live`, `/api/health/ready`, `/api/health` : 200 sur staging et prod ; Cosmos, Storage et Key Vault `ok` |
| Tuteur runtime | `TUTOR_LLM_ENABLED=False` dans les deux environnements ; inchangé, conformément à ADR-O-01 |
| Compilation | `infra/main.bicep` et `infra/params/staging.bicepparam`, Bicep 0.44.1 |

L'ancien blocage « variables de domaine absentes » n'est donc plus actuel.
`accountDeletionEnabled=false` dans le déploiement observé ; la preuve Apple
ne bloque pas ce backend. Elle ne doit pas être passée à `true` sans test réel.
Le DNS privé Foundry n'est pas nécessaire à la clôture du staging tant que
le tuteur LLM reste volontairement désactivé ; aucune ressource Foundry n'a
été modifiée dans ce lot.

**What-if Provider bornés** contre le RG staging peuplé, avec les paramètres
non secrets des déploiements modulaires live, et le nouveau `blobRestoreDays=29`
du template racine pour la seconde mesure Storage :

| Module | Heure UTC | Create / Delete (ressources) | Modify | NoChange | Ignore |
|---|---|---|---|---|---|
| `privateNetwork` | 19:09:57 | 0 / 0 | 12 | 0 | 36 |
| `cosmos` | 19:09:43 | 0 / 0 | 14 | 1 | 41 |
| `storage`, avant correction | 19:09:45 | 0 / 0 | 3 | 4 | 41 |
| `storage`, après correction | 19:24:33 | 0 / 0 | 3 | 4 | 41 |

`Ignore` n'est **pas** une preuve d'absence de dérive. Les plans modulaires
ne couvrent pas les autres modules ni leur composition au scope abonnement.
Un `Delete` de propriété n'est pas un `Delete` de ressource :

- Storage omettait `changeFeed.enabled=true` et `restorePolicy` activée à
  29 jours, observés sur dev, staging et prod. Le correctif les préserve
  explicitement, avec versioning et soft-delete à 30 jours. Le second
  what-if ne contient plus ces deux suppressions. Il conserve des deltas
  sur les valeurs par défaut `allowPermanentDelete=false`,
  `defaultEncryptionScope=$account-encryption-key` et
  `denyEncryptionScopeOverride=false` ; aucun changement de ces valeurs
  n'est demandé par le template.
- Réseau : deltas de métadonnées calculées des zone groups et peerings,
  et propriétés par défaut ; aucun changement annoncé de CIDR ou d'ID de
  zone DNS. Le peering applicatif est `Connected` et le zone group Vault
  référence bien la zone partagée dans `rg-certigo-ci`. Les anciennes
  zones locales encore inventoriées ne sont ni supprimées ni supposées
  adoptées par le plan.
- Cosmos : **écart non classifié**, `enablePartitionKeyMonitor: true -> false`.
  Le GET ARM avec l'API `2024-11-15` confirme `true` sur les trois comptes,
  mais le modèle `az cosmosdb show` et le schéma Bicep publié ne l'exposent
  pas. Ne pas inventer une propriété Bicep ni déclarer ce delta inoffensif.
  Les autres deltas concernent notamment les valeurs par défaut de
  résolution des conflits, les métadonnées de sauvegarde des conteneurs
  et l'endpoint calculé. Le compte conserve le mode de sauvegarde déclaré.

**Clôture non acquise :** `wp-p1-12` reste bloqué, et `wp-p1-13` est bloqué
par cette dépendance malgré sa santé et son déploiement déjà prouvés.
Le préflight racine complet n'a pas été lancé : l'opérateur reçoit
`ForbiddenByRbac` sur `Microsoft.KeyVault/vaults/secrets/getSecret/action`
pour la clé JWT staging, et les paramètres sécurisés ne sont pas restitués
par l'historique ARM. Aucune clé fictive, extraction GitHub de secret,
augmentation RBAC ou ouverture réseau ne remplace cette entrée.

Pour lever le blocage : exécuter le préflight racine `Provider` ci-dessous
dans un contexte déjà autorisé à fournir la clé réelle, faire classifier le
delta Cosmos, puis vérifier l'absence de dérive non intentionnelle sur
**tout** le plan. Si un apply s'avère nécessaire, demander un feu vert
explicite après présentation du plan et remesurer la santé ensuite.
Ne pas rejouer CD uniquement pour obtenir un what-if : CD peut appliquer.

Les commandes de mesure ne lisent aucune valeur de secret :

```powershell
gh api --paginate "repos/gchambaud_microsoft/Certigo/environments/staging/variables?per_page=100"
az deployment sub show --name certigo-staging --query "{state:properties.provisioningState,at:properties.timestamp,correlationId:properties.correlationId}"
az deployment group show --resource-group rg-certigo-staging --name storage --query properties.parameters
# Convertir chaque paramètre non secret {type,value} en {value}, refuser
# SecureString/SecureObject ou une value absente. Ne pas inventer les entrées.
# Compiler le module courant ; pour Storage ajouter blobRestoreDays=29,
# valeur vérifiée dans les paramètres du module du template racine compilé.
az deployment group what-if --resource-group rg-certigo-staging --template-file infra\modules\storage.bicep --parameters "@storage-parameters.json" --validation-level Provider --no-pretty-print
```

Sur ce poste Windows, borner chaque invocation Azure (60 secondes pour les
lectures, 180 secondes pour un what-if), arrêter uniquement son arbre de
processus en cas de dépassement et conserver l'erreur. Une limite de temps
atteinte n'est jamais un plan vide réussi.

### Préflight racine avec les secrets autorisés

```bash
# 0. Vérifier identité, scope et permissions effectives.
az account show --query "{subscription:id,tenantId:tenantId,user:user.name}" -o json
az role assignment list --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>" --include-inherited \
  --query "[].{role:roleDefinitionName,scope:scope}" -o table

# 1. Syntaxe : toutes les compilations doivent réussir avant un what-if.
bicep build infra/main.bicep --stdout >/dev/null
bicep build infra/ci-runner/network.bicep --stdout >/dev/null
bicep build infra/ci-runner/capacity.bicep --stdout >/dev/null
bicep build infra/modules/openai.bicep --stdout >/dev/null

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
  --parameters "@$AUTH_PARAMETERS_FILE" \
  --validation-level Provider

# 2. Surfaces CI bornées : aucun VMSS/VM/VNet parent ne doit être modifié.
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/network.bicep \
  --validation-level Provider
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/capacity.bicep \
  --validation-level Provider

# 3. Adoption OpenAI dev, indépendamment du feature flag runtime.
FUNC_PRINCIPAL_ID="$(az functionapp identity show -g rg-certigo-dev \
  -n "$(az functionapp list -g rg-certigo-dev --query '[0].name' -o tsv)" \
  --query principalId -o tsv)"
az deployment group what-if -g rg-certigo-dev \
  --template-file infra/modules/openai.bicep \
  --parameters accountName=certigo-openai location=swedencentral \
               deploymentName=gpt-5.4-mini \
               functionAppPrincipalId="$FUNC_PRINCIPAL_ID" \
  --validation-level Provider

# 4. Garde DNS OpenAI strictement read-only.
az network private-endpoint show -g rg-certigo-dev \
  -n pep-certigo-openai-account \
  --query "{dns:customDnsConfigs,zoneGroups:privateDnsZoneGroups}" -o json
az network private-dns zone list -g rg-certigo-dev \
  --query "[].name" -o tsv
```

Le niveau `Provider` est obligatoire. En cas de refus RBAC, `ProviderNoRbac` peut
servir uniquement au diagnostic; il ne constitue pas une autorisation de déployer.
Conserver la sortie complète et la joindre au ticket de changement.

Refuser l'application si le what-if annonce une suppression, un remplacement du compte Cosmos,
une Function App créée avant le déploiement `privateNetwork`, une private endpoint sans zone group,
une baisse inattendue de Defender, une création de NAT/IP déjà live, un PUT de
l'IP, de la NAT, du NSG, du VNet `vnet-certigo-ci`, ou une modification d'un
VMSS/VM. Pour
`capacity.bicep`, la suppression de la seule règle `Decrease` CPU et l'ajout des
tags FinOps à l'autoscale sont intentionnels. Pour `network.bicep`, seules les
extensions de tags FinOps sur PIP/NAT/NSG sont intentionnelles. Le compte OpenAI doit rester
`AIServices`, privé, `disableLocalAuth=true`, avec le modèle existant; son projet
et son private endpoint restent `existing`. Le what-if OpenAI n'autorise pas
l'activation runtime : le hostname `*.services.ai.azure.com` doit disposer de
la zone `privatelink.services.ai.azure.com`, de l'enregistrement A annoncé par
le private endpoint, d'un lien au VNet applicatif et d'un zone group approuvé.
Au 4 septembre 2026, seule `privatelink.openai.azure.com` existe, avec une
adresse différente, et le private endpoint n'a aucun zone group. Ne pas
réutiliser cette zone classique ni créer les ressources manquantes sans un
changement séparé et son propre what-if `Provider`.
La date d'expiration JWT est une entrée absolue auditée : ne pas utiliser `utcNow()`, ne pas la
repousser sans changer la clé, et appliquer la procédure de chevauchement décrite dans
`docs/deployment-runbook.md` avant toute rotation.

## Ordre de déploiement autorisé

1. **Dev** : appliquer l'IaC ; le module réseau doit terminer avant la Function App. Vérifier cinq
   connexions privées approuvées, les peerings, les liens DNS CI, l'intégration au subnet FC1 attendu et
   route-all désactivé. Le CD publie ensuite via
   `.github/scripts/deploy-flex-onedeploy.sh` et bloque tant que `/health/live` puis
   `/health/ready` ne sont pas verts.
2. **Staging** : l'environnement est déjà déployé et healthy. Fournir la clé JWT
   sécurisée et son expiration absolue uniquement pour un changement approuvé,
   relire le what-if contre le RG peuplé, puis appliquer en mode incrémentiel.
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
- Le finding R-03 (rôles Storage Blob Data Owner/Contributor) appartient à une
  PR distincte. Le préflight le signale mais ce chantier ne modifie ni ne retire
  aucune attribution Storage.
- OneDeploy est invoqué par PUT ARM direct. Ne jamais revenir à une corrélation par « dernier
  déploiement » : seul l'en-tête `Azure-AsyncOperation` ou `Location` renvoyé par le PUT exact peut
  être interrogé. L'absence d'en-tête, une URL hors `management.azure.com`, un statut inconnu ou un
  timeout sont bloquants. Jeton ARM, SAS, corps, en-têtes et réponses restent dans des fichiers
  temporaires `0600` détruits par `trap`.

## Interdictions opérationnelles

Sans ticket de changement, preuve de what-if et autorisation effective, ne pas exécuter
`az deployment ... create`, `az vm start`, `az vm deallocate`, `az group delete`,
`az cosmosdb restore` ou `az cosmosdb delete`.
