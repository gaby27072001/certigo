# Publication immuable du contenu vers Azure Blob Storage

Ce runbook réconcilie #290 avec le HEAD `8a780bf` de #304. Il décrit un pilote
staging uniquement. Cette PR ne fusionne, ne déploie, ne publie, ne verrouille
aucune policy WORM et ne manipule aucun secret.

## Contrat réconcilié

| Surface | #290 après réconciliation | Propriétaire restant |
|---|---|---|
| Compte | un StorageV2 GRS dédié dans `rg-certigo-content` | #290 |
| Conteneurs | `content-release-descriptors`, `content-public-releases`, `content-private-releases` | #290 |
| Chemins | `releases/<releaseId>/release.json`; `manifests/<manifestId>/...` | publication `certigo-content` |
| Versioning/WORM | versioning actif, version-level WORM actif, defaults temporels `Unlocked` | #290 ; lock OPS séparé |
| Private Endpoint | un endpoint Blob dans `rg-certigo-ci/vnet-certigo-ci/snet-runners` | #290 |
| DNS | zone existante `privatelink.blob.core.windows.net`, zone group `default` | #290 |
| Publishers | trois UAMI OIDC, une par conteneur | #290 |
| Reader runtime | `id-certigo-content-reader`, sans OIDC, `Storage Blob Data Reader` sur les trois conteneurs | #290 |
| Attachement reader | UAMI externe attachée à la Function App | #304 |
| Settings Function | endpoint, client ID et trois noms de conteneur issus des outputs #290 | #304 |
| Cosmos | `content-public`, `content-private`, `content-control` | #304 |
| Feature flags | `CONTENT_REPOSITORY_MODE=legacy`, `CONTENT_ALLOW_MUTABLE_BLOBS=false` | #304 |

Le runtime #304 utilise un seul `BlobServiceClient`. Une topologie à deux
comptes n'est donc pas compatible sans modifier le runtime. #290 adopte un
endpoint unique et conserve la séparation de confidentialité au niveau
conteneur, identité publisher et RBAC.

## Mapping outputs vers #304

| Output #290 | Consommation #304 |
|---|---|
| `azureBlobEndpoint` | `CONTENT_BLOB_ENDPOINT` |
| `azureContentReaderClientId` | `CONTENT_STORAGE_CLIENT_ID` |
| `azureContentReaderResourceId` | identité utilisateur attachée à la Function App |
| `azureDescriptorContainer` | `CONTENT_DESCRIPTOR_CONTAINER` |
| `azurePublicContainer` | `CONTENT_PUBLIC_CONTAINER` |
| `azurePrivateContainer` | `CONTENT_PRIVATE_CONTAINER` |
| `contentRepositoryModeDefault` | doit rester `legacy` |
| `contentAllowMutableBlobsDefault` | doit rester `false` |

#304 doit remplacer son compte/UAMI reader locaux par ces entrées externes
après fusion de #304 dans `main`. Ce changement appartient à la couche
applicative de #304 ; #290 n'écrit aucun app setting et ne cible aucun resource
group applicatif.

La réconciliation de #304 doit supprimer, dans une même modification :

- le module `infra/modules/contentStorage.bicep` et son déploiement
  `contentStorage` dans `infra/main.bicep` ;
- le Private Endpoint `contentStorageBlobEndpoint` et son zone group dans
  `infra/modules/privateNetwork.bicep` ;
- la création `contentReaderIdentity` et ses trois role assignments dans
  `infra/modules/functionApp.bicep`.

#304 reçoit à la place l'endpoint, les trois noms de conteneur, le resource ID
et le client ID de l'UAMI externe. Il attache cette UAMI à la Function App sans
recréer son RBAC. Les paramètres déployés restent `legacy` dans dev, staging et
prod, et `CONTENT_ALLOW_MUTABLE_BLOBS=false`. Une dérogation locale éventuelle
doit être explicite et non committée; aucun exemple, fichier de paramètres ou
Environment de déploiement ne l'active par défaut.

## Matrice d'environnements et activation

Le compte de contenu est un stack partagé, hors
`rg-certigo-dev`/`rg-certigo-staging`/`rg-certigo-prod`. Il n'est donc pas
dupliqué par environnement.

| Environnement applicatif | UAMI reader attachée | Mode repository | Mutable blobs | Action autorisée par le pilote |
|---|---:|---|---:|---|
| dev | non | `legacy` | `false` | aucune dépendance au stack partagé |
| staging avant preuve | oui | `legacy` | `false` | import et promotion administratifs |
| staging pendant lecture | oui | `versioned` temporaire | `false` | preuve lecture puis rollback N-1 |
| prod | non | `legacy` | `false` | aucune modification |

La bascule staging est une modification applicative explicite et réversible.
Le template #290 n'active aucun environnement et ses outputs de defaults sont
des chaînes informatives, pas des app settings appliqués.

## Coût et bornes du pilote

Le compte Storage n'a pas de coût fixe : la facture dépend de la capacité GRS,
des opérations, du trafic et du Private Endpoint. GRS est conservé pour la
durabilité décidée ; le tiering Cool limite la capacité chaude, mais toute
version reste facturable jusqu'à la fin de sa rétention et le Cool applique sa
propre durée minimale. Le versioning, le soft delete et WORM interdisent donc
d'utiliser une estimation fondée uniquement sur la taille du dernier manifeste.

Bornes du pilote staging :

- au plus deux releases candidates et 10 GiB cumulés, versions incluses ;
- aucun test de charge ni réplication vers un second compte ;
- un seul Private Endpoint Blob et aucun endpoint par environnement ;
- aucune règle lifecycle de suppression et aucun lock WORM ;
- revue du coût réel après chaque release, puis arrêt de publication si le
  plafond FinOps approuvé est dépassé.

Avant production, OPS chiffre séparément capacité Hot/Cool GRS, opérations,
Private Link et éventuel egress à partir des tarifs Azure du jour. Une alerte de
budget est portée par le stack FinOps existant, pas par #290, afin de ne pas
étendre le scope de ce déploiement de contenu.

## Gap publisher hors #290 — résolu

> Mise à jour 2026-09-04. Cette section listait cinq corrections restantes.
> Vérifié sur `certigo-content@07ab6b04` : les cinq sont implémentées dans
> `.github/workflows/publish-content-azure.yml` et
> `tools/publish_blob_artifact.sh`.

Le workflow publie :

1. le public sous `content-public-releases/manifests/<publicManifestId>/` ;
2. le privé sous `content-private-releases/manifests/<privateManifestId>/` ;
3. avec relecture et comparaison SHA-256 de chaque blob distant ;
4. puis en dernier
   `content-release-descriptors/releases/<releaseId>/release.json` avec
   l'Environment `azure-content-release` ;
5. sans overwrite (`--overwrite false`), sans delete et sans alias mutable.

Le descripteur n'est pas confié au publisher public ou privé : sa publication
atteste que les deux artefacts sont présents et vérifiés.

## Verrou WORM et publication

Le script exigeait initialement une policy `Locked` avant tout upload, alors que
Bicep crée les policies `Unlocked` et que ce runbook interdit le lock avant la
preuve complète. Publier exigeait donc le lock, et le lock exigeait d'avoir
publié.

`tools/publish_blob_artifact.sh` accepte désormais `Locked` ou `Unlocked` et
exige dans les deux cas une rétention réelle, non expirée et sans append
protégé — c'est cette rétention qui empêche l'écrasement. `Locked` n'est exigé
que lorsque `CONTENT_REQUIRE_LOCKED_WORM=true`, valeur attendue en production
après la preuve staging. Le pilote laisse la variable à `false`.

## Validation strictement read-only

La CI locale compile tous les Bicep, exécute les tests de contrat et lance
Checkov :

```bash
export BICEP_BIN=/opt/bicep/0.44.1/bicep
bash infra/validate.sh
BICEP_CLI="$BICEP_BIN" node --test infra/tests/content-storage.test.mjs
checkov --directory infra --framework bicep --compact --quiet \
  --config-file .checkov.yaml
```

Le workflow `Content infrastructure what-if` :

- est déclenché uniquement après un push sur `main` ;
- checkout explicitement `refs/heads/main` ;
- utilise uniquement `az deployment group what-if` sur `rg-certigo-content` ;
- refuse toute suppression ;
- refuse toute cible hors `rg-certigo-content` ;
- publie le diff complet dans le job summary.

Le workflow `Content infrastructure apply` applique le même template :

- déclenché uniquement par `repository_dispatch` de type `content-infra-apply`,
  car `validate-workflow-security.mjs` interdit `workflow_dispatch` sur un
  workflow `certigo-trusted` ;
- refuse toute exécution hors `refs/heads/main` ;
- exige dans son payload le SHA-256 exact de `infra/content/main.bicep`, ce qui
  interdit d'appliquer autre chose que le template approuvé ;
- vérifie le tenant et la subscription réellement obtenus après login ;
- rejoue le what-if et ses garde-fous avant d'appliquer, et échoue en plus si le
  plan verrouillerait une policy d'immuabilité ;
- ne verrouille jamais une policy WORM.

Refuser le plan s'il annonce :

- une suppression ou un remplacement de compte ;
- une cible `rg-certigo-dev`, `rg-certigo-staging` ou `rg-certigo-prod` ;
- Shared Key, réseau public ou accès anonyme ;
- un rôle publisher avec delete ou mutation de policy ;
- un reader plus large que `Storage Blob Data Reader` au scope conteneur ;
- une policy déjà `Locked`.

## Ordre minimal de fusion et de provisionnement

1. Garder #290 draft et sans déploiement.
2. Finaliser puis fusionner #304, avec les defaults
   `CONTENT_REPOSITORY_MODE=legacy` et
   `CONTENT_ALLOW_MUTABLE_BLOBS=false`.
3. Réaligner #290 par merge non destructif de ce `main`, remplacer dans l'IaC
   #304 le stockage/UAMI reader locaux par les paramètres/outputs externes de
   #290, puis relancer Bicep, tests, Checkov et project-state.
4. Corriger et fusionner le publisher `certigo-content` pour les trois chemins,
   sans lancer sa publication.
5. Exécuter et approuver le what-if #290 sur le `main` courant ; conserver le
   JSON et le résumé comme preuve.
6. Fusionner #290 seulement après approbation du what-if et de la
   réconciliation #304.
7. Provisionner uniquement `rg-certigo-content`, policies encore `Unlocked`.
8. Déployer #304 en staging avec mode `legacy`, en attachant
   `azureContentReaderResourceId`; ne toucher ni prod ni ses settings.
9. Configurer les trois Environments publisher avec les outputs non secrets,
   puis publier une release candidate.
10. Importer la release en staging, promouvoir, basculer staging seulement en
    `versioned`, lire le manifeste et les parcours, promouvoir une seconde
    release, puis prouver le rollback N-1.
11. Remettre staging en `legacy` en cas d'échec. Garder prod inchangée et les
    flags désactivés.
12. Examiner séparément un futur lock WORM après preuve complète. Le pilote ne
    l'autorise pas.

Cet ordre évite de créer le compte temporaire de #304 puis de le remplacer, et
évite toute fenêtre où une Function `versioned` pointerait vers un stockage non
peuplé.

## Preuve staging attendue

### 1. Préconditions

- `CONTENT_REPOSITORY_MODE=legacy` ;
- `CONTENT_ALLOW_MUTABLE_BLOBS=false` ;
- un `versionId` non vide sur chaque blob ;
- une policy temporelle active ou un legal hold sur chaque version ;
- aucune configuration production modifiée ;
- jeton opérateur avec `Content.Release.Admin`.

### 2. Import

Importer le `releaseId` par l'endpoint admin #304. Attendre un receipt complet
dans `content-control`. Un replay exact doit être idempotent ; une erreur de
schema, hash, version, taille ou fermeture de graphe ne doit pas produire de
receipt complet.

### 3. Promotion

Lire le pointeur et son ETag, puis promouvoir avec `If-Match`. Une ETag périmée
doit retourner 412. Ne jamais utiliser `*` lorsqu'un pointeur existe.

### 4. Lecture versionnée

Basculer staging seulement en `versioned`, puis vérifier :

- manifeste actif et ETag = `publicManifestId` ;
- lecture catalog/lesson avec le même identifiant ;
- quiz, exam et tutor épinglés au manifeste ;
- absence de `releaseId`, `privateManifestId`, solution, rationale ou answer key
  dans les réponses publiques ;
- événements App Insights sans contenu privé.

### 5. Rollback N-1

Publier et promouvoir une seconde release, relire le nouvel ETag, puis appeler
le rollback avec `If-Match`. Vérifier que :

- `previous` redevient actif ;
- un second rollback sans nouvelle promotion retourne 409 ;
- les anciens attempts restent notables avec leur `publicManifestId` ;
- aucun blob, version ou receipt n'est supprimé ou réécrit.

## Garde-fous WORM

Les paramètres de rétention sont des baselines de planification. Ils ne valent
pas approbation compliance. Bicep crée uniquement des policies `Unlocked`.

Le lock ne peut pas être annulé et la durée ne peut ensuite qu'augmenter. Il est
hors périmètre de #290 et du pilote staging. Aucune commande de lock ne doit
être ajoutée à un workflow.

`tools/publish_blob_artifact.sh` n'exige donc pas `Locked` par défaut. Voir
« Verrou WORM et publication » ci-dessus.

## Fenêtre de dérive du rôle publisher

> À supprimer une fois la PR #377 fusionnée dans `main`.

Le 2026-09-04, le rôle `c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de` a été corrigé
impérativement par `az role definition update` pour ajouter les deux
`dataActions` `blobs/read` et `blobs/write`, sans lesquelles chaque upload
retournait 403. La correction IaC correspondante est dans
`infra/governance/bootstrap-identities.bicep` sur la branche de la PR #377.

**Tant que #377 n'est pas fusionnée, `main` contient encore l'ancienne
définition.** Rejouer Phase A depuis `main` pendant cette fenêtre écrase
silencieusement les `dataActions` et toute publication recommence à échouer en
403, sans cause évidente : le rôle existe, l'attribution existe, seul le
data-plane est muet.

Ne pas exécuter `infra/governance/deploy-phase-a.sh` depuis `main` avant la
fusion. En cas de doute, vérifier avant publication :

```bash
az role definition list \
  --name c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de \
  --subscription b8952c8c-8f72-469d-99cd-ac906da4e2fc \
  --query "[0].permissions[0].dataActions" --output json
```

Attendu : les deux actions `blobs/read` et `blobs/write`. Une liste vide
signifie que la dérive s'est produite.

Note : `az role definition update` ignore silencieusement une charge utile
dépourvue du champ `id` et retourne un succès sans rien modifier. Toujours
relire la définition après mise à jour.

## Rollback infrastructure

Avant la première publication et tant qu'aucune policy n'est verrouillée, toute
suppression éventuelle exige une décision OPS séparée et un nouveau what-if.
Après publication ou lock, ne supprimer ni compte, conteneur, endpoint, identité
ou rôle. Corriger DNS, peering, identité attachée, RBAC ou settings, puis
reprendre la preuve depuis le mode `legacy`.
