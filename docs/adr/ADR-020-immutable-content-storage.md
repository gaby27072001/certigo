# ADR-020 — Stockage Azure dédié pour les releases de contenu immuables

> Renuméroté depuis `ADR-014` le 2026-09-03 (via `ADR-019` puis `ADR-020` le même jour) : ce
> numéro était déjà utilisé par
> [`ADR-014-person-linked-identity.md`](./ADR-014-person-linked-identity.md),
> référencé ailleurs (ADR-017, contrat `person-linked-identity/v1`). Le numéro `ADR-019` a été
> abandonné avant merge suite à une collision détectée avec `ADR-019-runtime-content-releases.md`,
> committé en parallèle sur une autre branche (`wp-p2-04`, import des releases de contenu
> backend). Aucun changement de contenu au-delà du numéro et de ce titre.

- Statut : proposé
- Date : 2026-08-19
- Dépendances :
  [`gchambaud_microsoft/certigo-content#25`](https://github.com/gchambaud_microsoft/certigo-content/pull/25)
  puis
  [`Certigo#304`](https://github.com/gchambaud_microsoft/Certigo/pull/304)
- Consommateur :
  [`Certigo#244`](https://github.com/gchambaud_microsoft/Certigo/issues/244)

## Contexte

Le contrat runtime de #304 charge un descripteur
`certigo.content.release/v1`, un paquet public et un paquet privé par un unique
`BlobServiceClient`. Il exige des blobs versionnés, immuables et rangés sous :

- `content-release-descriptors/releases/<releaseId>/release.json` ;
- `content-public-releases/manifests/<publicManifestId>/...` ;
- `content-private-releases/manifests/<privateManifestId>/...`.

Le précédent dessin de #290 utilisait deux comptes, deux conteneurs et les
préfixes `releases/sha256/<rootHash>`. Il ne pouvait donc pas être consommé par
#304 sans plusieurs endpoints Blob et ne fournissait aucune cible pour
`release.json`.

## Décision

Créer un stack subscription-scoped indépendant sous `rg-certigo-content` :

- un compte StorageV2 GRS dédié, privé, OAuth-only et versionné ;
- trois conteneurs privés portant les noms exacts du contrat #304 ;
- le support WORM version-level et une policy temporelle `Unlocked` par
  conteneur, sans append protégé ;
- un seul Private Endpoint Blob dans
  `rg-certigo-ci/vnet-certigo-ci/snet-runners`, relié à la zone DNS Blob
  partagée ;
- trois identités OIDC publisher, chacune limitée à son conteneur ;
- une identité managée utilisateur sans fédération pour la lecture runtime ;
- trois attributions `Storage Blob Data Reader` au scope exact des conteneurs ;
- une policy lifecycle de tiering Cool sur `manifests/` et `releases/`, sans
  suppression.

Le stack expose l'endpoint, les trois conteneurs et l'identité reader sous une
forme directement mappable aux settings #304 :

| Output #290 | Setting #304 |
|---|---|
| `azureBlobEndpoint` | `CONTENT_BLOB_ENDPOINT` |
| `azureContentReaderClientId` | `CONTENT_STORAGE_CLIENT_ID` |
| `azureDescriptorContainer` | `CONTENT_DESCRIPTOR_CONTAINER` |
| `azurePublicContainer` | `CONTENT_PUBLIC_CONTAINER` |
| `azurePrivateContainer` | `CONTENT_PRIVATE_CONTAINER` |

Les defaults restent `CONTENT_REPOSITORY_MODE=legacy` et
`CONTENT_ALLOW_MUTABLE_BLOBS=false`.

## Frontières de propriété

#290 crée le compte, les conteneurs, le Private Endpoint/DNS group, les
identités, le RBAC et les outputs. Il ne crée ni Function App, ni conteneur
Cosmos, ni app setting.

#304 reste propriétaire de l'attachement de l'UAMI reader à la Function App,
des settings ci-dessus, des conteneurs Cosmos
`content-public`/`content-private`/`content-control` et de la bascule
`legacy -> versioned`. Avant intégration, #304 doit consommer l'UAMI externe de
#290 plutôt que créer un reader et un compte de contenu locaux.

Le dépôt `certigo-content` reste propriétaire de la publication. Son workflow
publie désormais le paquet public sous
`content-public-releases/manifests/<publicManifestId>/`, le paquet privé sous
`content-private-releases/manifests/<privateManifestId>/`, puis `release.json`
en dernier sous `content-release-descriptors/releases/<releaseId>/`, chacun avec
son Environment et son identité OIDC dédiés.

> Mise à jour 2026-09-04 : ce paragraphe décrivait l'ancien préfixe
> `releases/sha256/<rootHash>` et présentait la publication de `release.json`
> comme un travail restant. Vérifié sur `certigo-content@07ab6b04` : les trois
> chemins et l'ordre descripteur-en-dernier sont déjà implémentés.

## WORM et rollback

Bicep ne verrouille jamais les policies. Le passage à `Locked` est une action
opérateur séparée et irréversible, interdite tant que l'import, la promotion,
la lecture versionnée et le rollback N-1 n'ont pas été prouvés en staging.

Le rollback applicatif change uniquement le pointeur Cosmos actif. Il ne
déplace aucun alias Blob, ne réécrit aucun objet et ne modifie aucune policy.

## Conséquences

- #290 ne peut pas être fusionnée ou provisionnée avant #304.
- La production reste inchangée pendant le pilote ; ses flags restent
  désactivés.
- Le partage d'un endpoint simplifie le contrat runtime, tandis que la
  séparation en conteneurs conserve les frontières RBAC public/privé/release.
- La preuve staging et l'ordre opératoire sont maintenus dans
  [`IMMUTABLE_CONTENT_STORAGE.md`](../runbooks/IMMUTABLE_CONTENT_STORAGE.md).
