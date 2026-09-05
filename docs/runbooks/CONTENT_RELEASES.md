# Runbook — import, promotion et rollback des releases de contenu

Ce runbook est une procédure opérateur. Le lot `wp-p2-04` (import backend des
releases de contenu) ne déploie, ne publie et n'active aucune release.

## Préconditions

- La PR #290 est déployée. Ses sorties alimentent des **paramètres Bicep**, et
  non des variables GitHub Environment : `contentBlobEndpoint`,
  `contentReaderClientId` et `contentReaderResourceId` doivent être renseignés
  dans `infra/params/<env>.bicepparam`, puis l'infrastructure redéployée.
  `infra/main.bicep` impose ces trois valeurs ensemble (`fail()` si l'une
  manque) et exige les trois pour `contentRepositoryMode = 'versioned'`.
  Les noms de containers ont déjà les bonnes valeurs par défaut
  (`content-release-descriptors`, `content-public-releases`,
  `content-private-releases`) et n'ont pas à être surchargés.
- Définir des variables GitHub Environment nommées `AZURE_BLOB_ENDPOINT`,
  `AZURE_CONTENT_READER_RESOURCE_ID`, `AZURE_DESCRIPTOR_CONTAINER`,
  `AZURE_PUBLIC_CONTAINER` ou `AZURE_PRIVATE_CONTAINER` **n'a aucun effet** :
  aucun workflow ni aucun module ne les lit. Seul `ci-content-drift.yml`
  consomme `AZURE_CONTENT_READER_CLIENT_ID`, pour son login OIDC.
- Récupérer les valeurs à jour depuis le déploiement plutôt que de les recopier:

  ```bash
  az identity show \
    --ids "$CONTENT_READER_RESOURCE_ID" \
    --query "{clientId:clientId, resourceId:id}" -o json
  ```

- Le backend ne provisionne aucun stockage, private endpoint, RBAC ou UAMI de
  contenu. L'UAMI reader externe est attachée à la Function App par
  `infra/modules/functionApp.bicep`, uniquement si `contentReaderResourceId`
  est non vide.
- `CONTENT_REPOSITORY_MODE=legacy` reste actif pendant l'import initial.
- Les blobs suivent la convention:
  - descriptor: `releases/<releaseId>/release.json`;
  - public/privé:
    `manifests/<manifestId>/manifest.json` et
    `manifests/<manifestId>/<file.path>`.
- Chaque blob possède un `versionId` et une policy d'immutabilité non expirée ou
  un legal hold.
- Le compte de stockage de contenu est **accessible uniquement par private
  endpoint** (`publicNetworkAccess=Disabled`, `defaultAction=Deny`, aucune règle
  IP ni VNet). Toute commande data-plane (`az storage blob list`,
  `az storage container list`) échoue depuis un poste de travail, y compris avec
  des droits RBAC corrects : l'erreur parle de règles réseau, pas de permissions.
  Import, promotion et vérification doivent donc s'exécuter depuis un contexte
  attaché au VNet (Function App, subnet des runners CI). Les lectures
  **management-plane** (`az rest` sur `.../blobServices/default/containers`)
  fonctionnent depuis n'importe où et servent à vérifier l'existence des
  containers et leurs policies d'immutabilité.
- Le chemin réseau (private endpoint approuvé, zone DNS privée liée aux VNets,
  peerings connectés, intégration VNet des Function Apps) est vérifié
  **topologiquement**, mais aucun aller-retour data-plane n'a encore été
  exécuté. Le premier import est donc la preuve du chemin, pas une formalité :
  le traiter comme une étape susceptible d'échouer.
- Le jeton opérateur porte l'app role `Content.Release.Admin`.
- Le `releaseId` vient du rapport de package `certigo-content`; ne jamais
  accepter une URL ou un package fourni dans le body HTTP.

## Import en staging

```bash
API="https://<staging-function>.azurewebsites.net/api"
RELEASE_ID="sha256:<64-hex>"
TOKEN="<entra-admin-token>"

curl --fail-with-body \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  "$API/admin/content/releases/$RELEASE_ID/import"
```

Un premier import retourne 201; un replay exact retourne 200. Toute erreur de
schema/hash/taille/référence doit laisser les trois containers sans receipt
complet. Ne pas promouvoir une release sans receipt.

## Lire puis promouvoir le pointeur

```bash
curl --fail-with-body \
  -D pointer.headers \
  -H "Authorization: Bearer $TOKEN" \
  "$API/admin/content/releases/pointer" \
  -o pointer.json

ETAG="$(awk 'BEGIN{IGNORECASE=1} /^etag:/ {gsub(/\r/,""); print $2}' pointer.headers)"
# Pour la toute première activation, utiliser littéralement '*'.

curl --fail-with-body \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "If-Match: ${ETAG:-*}" \
  "$API/admin/content/releases/$RELEASE_ID/promote"
```

Une ETag obsolète retourne 412. Relire le pointeur; ne pas réessayer avec `*`
si un pointeur existe.

## Vérifications staging

1. Appeler `GET /api/content/releases/active/manifest` avec un JWT learner.
2. Vérifier l'ETag = `publicManifestId` et le 304 avec `If-None-Match`.
3. Vérifier que la réponse expose `releaseId` et que
   `GET /api/content/releases/<releaseId>/manifests/<publicManifestId>/files/<sha256>/<path>`
   retourne uniquement le fichier public déclaré, avec `ETag`,
   `X-Content-SHA256`, `Content-Length`, `Content-Type`,
   `X-Content-Release-Id`, `X-Content-Manifest-Id`,
   `Cache-Control: private, max-age=31536000, immutable` et
   `Accept-Ranges: none`.
4. Vérifier un 304 avec `If-None-Match` (fort, faible, wildcard et liste), un
   416 non cacheable avec `Range`, et le même 404 pour release, manifeste, hash
   ou path incorrect, traversal inclus.
5. Vérifier que `GET /tracks/{trackId}/lessons/{lessonId}` retourne le même
   identifiant dans `X-Content-Manifest-Id`; le client doit le conserver dans
   son cache et l'envoyer aux requêtes quiz/tuteur.
6. Vérifier l'absence de `privateManifestId`, `correct`,
   `correctOptionIds`, `explanation`, `rationale`, `answerKey` et `solution`.
7. Vérifier qu'en mode `legacy`, la nouvelle route fichier retourne 404 sans
   lecture Blob; le manifeste actif conserve son comportement existant.
8. Basculer **staging seulement** vers `CONTENT_REPOSITORY_MODE=versioned`.
   Ce réglage n'est **pas** une variable GitHub Environment : aucun workflow ne
   lit `CONTENT_REPOSITORY_MODE`. Le seul producteur du paramètre applicatif est
   `infra/modules/functionApp.bicep` à partir du paramètre Bicep
   `contentRepositoryMode`. La bascule se fait donc en passant
   `param contentRepositoryMode = 'versioned'` dans
   `infra/params/staging.bicepparam`, puis en redéployant l'infrastructure.
   Définir une variable GitHub Environment du même nom n'a aucun effet et ne
   produit aucune erreur : l'API continue de servir le mode `legacy` alors que
   le déploiement paraît réussi. Le paramètre reste `legacy` dans dev et prod.
9. Exécuter catalog, lesson, path, quiz, exam et tutor.
10. Soumettre une tentative avec le `publicManifestId`, promouvoir une autre
   release, puis vérifier que le replay et la notation relisent l'ancienne
   release.
11. Contrôler les événements App Insights
   `content.release.import|rejected|promoted|rolled_back`, sans payload.

## Rollback N-1

```bash
curl --fail-with-body \
  -D rollback-pointer.headers \
  -H "Authorization: ******" \
  "$API/admin/content/releases/pointer" \
  -o rollback-pointer.json

ROLLBACK_ETAG="$(
  awk 'BEGIN{IGNORECASE=1} /^etag:/ {gsub(/\r/,""); print $2}' \
    rollback-pointer.headers
)"

curl --fail-with-body \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "If-Match: $ROLLBACK_ETAG" \
  "$API/admin/content/releases/rollback"
```

Le rollback active `previous`, vide les champs previous et conserve tous les
artefacts. L'ETag doit être relu immédiatement avant l'opération : toute
promotion ou rollback concurrent rend le CAS obsolète et retourne 412, sans
écraser le pointeur. Un second rollback sans nouvelle promotion retourne 409.

## Rollback applicatif

Si le nouveau repository présente un défaut indépendant du contenu:

1. remettre `CONTENT_REPOSITORY_MODE=legacy`;
2. redémarrer la Function App;
3. ne supprimer aucun container, receipt, blob ou attempt;
4. continuer à accepter les opérations déjà épinglées à un
   `publicManifestId` d'une release précédemment activée; un import seulement
   stagé n'est jamais résolvable par un learner;
5. ouvrir un incident avec correlation ID et release ID, jamais avec le texte
   privé.

## Promotion production

La production est une opération séparée. Réutiliser le même `releaseId`
immuable après preuve staging, approbation de l'environment et validation du
rollback. L'activation production n'est jamais implicite dans un déploiement
backend.

## Plan exact du pilote WORM staging

1. Fusionner l'implémentation `wp-p2-04` avec `legacy` par défaut et
   `CONTENT_ALLOW_MUTABLE_BLOBS=false`; ne configurer aucun output #290 dans dev
   ou prod.
2. Corriger puis fusionner le publisher `certigo-content` pour écrire public,
   privé, puis `releases/<releaseId>/release.json` en dernier, sans lancer de
   publication.
3. Faire approuver le what-if #290, puis provisionner uniquement
   `rg-certigo-content`: un StorageV2 `Standard_GRS`, OAuth-only, réseau public
   désactivé, trois containers, rétentions WORM `Unlocked` 90/30/90 et un seul
   Private Endpoint Blob dans le subnet CI.
4. Copier les six outputs #290 dans l'Environment GitHub staging. Laisser
   `CONTENT_REPOSITORY_MODE` absent: la Function attache uniquement l'UAMI reader
   externe et reste en `legacy`.
5. Redéployer la même révision backend en staging afin de matérialiser l'endpoint
   et l'UAMI reader externes, tout en conservant `CONTENT_REPOSITORY_MODE=legacy`.
   Vérifier les app settings effectifs avant tout import.
6. Publier au plus deux releases candidates, 10 GiB cumulés versions incluses.
   Vérifier un `versionId` et une policy non expirée sur chaque blob.
7. Importer la première release, vérifier le receipt complet et le replay
   idempotent, puis promouvoir avec l'ETag courant.
8. Avant toute bascule, prouver que les versions mobiles encore admises en
   staging envoient `publicManifestId` pour quiz et tuteur. Drainer les actions
   offline créées avant cette version, ou les invalider explicitement avec une
   information utilisateur; une requête sans pin doit rester rejetée fail-closed.
9. Définir `CONTENT_REPOSITORY_MODE=versioned` dans staging seulement, déployer
   la même révision backend et vérifier manifeste/ETag, catalog, lesson, quiz,
   exam, tutor et absence de données privées.
10. Publier et promouvoir la seconde release, puis prouver le rollback N-1 avec
   `If-Match`; un second rollback doit retourner 409 et aucun artefact ne doit
   être supprimé ou réécrit.
11. En cas d'échec, remettre staging en `legacy`; ne modifier ni prod ni les
   policies. Examiner coûts et preuves avant toute suite.
12. Ne verrouiller aucune policy pendant le pilote. Un futur lock WORM,
    irréversible, exige une décision OPS/compliance et une procédure séparée;
    aucune commande de lock ne doit entrer dans un workflow.
