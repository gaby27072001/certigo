# Releases de contenu backend

Le backend importe les deux artefacts immuables produits séparément par
`gchambaud_microsoft/certigo-content` (contrat public/privé livré par les PR #7 et #8).
Chaque artefact contient un `manifest.json` conforme à
`certigo.content.package-manifest/v1`. Une release est adressée, promue et restaurée par le
`releaseManifestId` composite (`sha256:<hash(publicManifestId + privateManifestId)>`).
Le `publicManifestId` reste exposé séparément par l'API de lecture publique.

## Contrat d'import `certigo-content-release/v1`

`POST /api/ops/content/releases/import` exige une clé Function **et** un JWT portant le rôle
`ContentReleaseOperator`. Le corps
assemble les deux artefacts sans en modifier les octets :

Le rôle applicatif Entra `ContentReleaseOperator` doit être assigné explicitement aux identités
d'opérateur ; un JWT utilisateur standard reste insuffisant même si la clé Function est connue.

```json
{
  "contractVersion": "certigo-content-release/v1",
  "public": {
    "manifest": {
      "schema": "certigo.content.package-manifest/v1",
      "channel": "public",
      "artifact": "public",
      "algorithm": "sha256",
      "serialization": "json-sorted-keys-compact-utf8-lf",
      "fileCount": 1,
      "files": [
        { "id": "az-900", "path": "questions/az-900.json", "hash": "<64 hex>", "size": 123 }
      ],
      "manifestId": "sha256:<rootHash public>",
      "rootHash": "<64 hex>"
    },
    "files": [
      { "path": "questions/az-900.json", "contentBase64": "<octets publiés en base64>" }
    ]
  },
  "private": {
    "manifest": {
      "schema": "certigo.content.package-manifest/v1",
      "channel": "answerKey",
      "artifact": "private",
      "algorithm": "sha256",
      "serialization": "json-sorted-keys-compact-utf8-lf",
      "fileCount": 1,
      "files": [
        { "id": "az-900", "path": "solutions/az-900.json", "hash": "<64 hex>", "size": 456 }
      ],
      "manifestId": "sha256:<rootHash privé>",
      "rootHash": "<64 hex>"
    },
    "files": [
      { "path": "solutions/az-900.json", "contentBase64": "<octets publiés en base64>" }
    ]
  }
}
```

Garanties avant la première écriture :

- schéma, canal, nom d'artefact, algorithme, sérialisation, `fileCount`, identifiants, chemins,
  cardinalité et tailles sont validés ;
- `rootHash` est recalculé sur le corps canonique du manifeste (sans `manifestId`/`rootHash`) et
  `manifestId` doit être exactement `sha256:<rootHash>` ;
- chaque SHA-256 est recalculé sur les octets décodés et comparé en temps constant ;
- les listes du manifeste et du payload doivent être strictement identiques ;
- les chemins publics sont limités à `questions/*.json`, les chemins privés à
  `solutions/*.json`, sans traversée ni archive imbriquée ;
- le paquet public est inspecté récursivement : chemins `answerKey` et clés
  `answerKey`/`correct`/`rationale` sont interdits, et les archives opaques imbriquées sont
  refusées ;
- un même `releaseManifestId` rejoué est un succès sans doublon ; une modification du seul
  artefact privé produit une nouvelle release composite sans collision ;
- les fichiers publics et privés sont adressés par l'identité composite et vérifiés contre le reçu
  committé avant chaque lecture.

Limites défensives : 500 fichiers et 25 Mo décodés par canal, 1 Mo par fichier, manifeste de reçu
limité à 512 Ko et chemin relatif de 512 caractères maximum. Un import interrompu n'a pas de reçu et n'est donc jamais promouvable ; son
rejeu complète les fichiers immuables puis écrit le reçu en dernier.

## Promotion et rollback

`CONTENT_RELEASE_ENVIRONMENT` vaut `dev`, `staging` ou `prod` (injecté par Bicep). Chaque
environnement possède un pointeur Cosmos distinct :

```text
POST /api/ops/content/releases/{releaseManifestId}/promote
POST /api/ops/content/releases/{releaseManifestId}/rollback
```

La promotion remplace atomiquement le pointeur `active/previous/history` avec `If-Match` sur
l'ETag. Deux opérateurs concurrents ne peuvent donc pas perdre une mise à jour : le perdant reçoit
`409 Conflict`. Le rollback n'accepte que le `previousManifestId` (N-1), ne supprime aucun
artefact et garde les 100 transitions les plus récentes dans le pointeur actif. Procédure :

1. télécharger les deux artefacts exacts
   `certigo-content-{public|private}-sha256-<rootHash>` sans wildcard, vérifier leurs
   `manifestId`, extraire leur `manifest.json` et leurs payloads, puis construire l'enveloppe
   ci-dessus ;
2. importer en staging, promouvoir, puis exécuter les smoke tests contenu/quiz ;
3. importer le même paquet en prod et promouvoir le même `releaseManifestId` composite ;
4. en incident, appeler `/rollback` avec le `previousManifestId` composite retourné lors de la
   promotion.

Import, rejeu idempotent, promotion, rejet et rollback émettent les événements Application Insights
`content.release.*`, sans octet de contenu ni corrigé.

## Surface mobile et frontière privée

Les routes authentifiées destinées au client sont :

```text
GET /api/content/releases/active/public
GET /api/content/releases/active/public/files/{path}
```

La première ne sérialise que le manifeste public actif. Le reçu public ne contient aucune
métadonnée du manifeste privé ; celle-ci reste dans le container privé. La seconde calcule
toujours l'id Cosmos avec le canal `public` et vérifie le canal et le chemin après lecture. Il
n'existe **aucune route HTTP privée** : les fichiers `answerKey` restent accessibles uniquement au
repository backend.

Rollback opérationnel du code : redéployer la version précédente de l'API ; les documents de
release étant additifs et immuables, aucun nettoyage de données n'est requis.
