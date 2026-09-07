# Runbook — import, promotion et rollback des releases de contenu

Ce runbook est une procédure opérateur. Le lot `wp-p2-04` (import backend des
releases de contenu) ne déploie, ne publie et n'active aucune release.

## Préconditions

- La PR #290 est déployée. Ses sorties alimentent les **paramètres Bicep**
  `contentBlobEndpoint`, `contentReaderClientId` et `contentReaderResourceId`.
  **Deux chemins les renseignent, et le second écrase le premier :**
  1. `infra/params/<env>.bicepparam`, puis redéploiement de l'infrastructure;
  2. les variables GitHub Environment `AZURE_BLOB_ENDPOINT`,
     `AZURE_CONTENT_READER_CLIENT_ID`, `AZURE_CONTENT_READER_RESOURCE_ID`,
     `AZURE_DESCRIPTOR_CONTAINER`, `AZURE_PUBLIC_CONTAINER` et
     `AZURE_PRIVATE_CONTAINER`, lues par `cd-backend.yml` (`vars.*`, job
     `deploy-infra`) et injectées comme paramètres par
     `.github/scripts/write-secure-bicep-parameters.mjs`, qui **surcharge** la
     valeur compilée depuis le `.bicepparam`.

  `infra/main.bicep` impose ces trois valeurs ensemble (`fail()` si l'une
  manque) et exige les trois pour `contentRepositoryMode = 'versioned'`.
  Les noms de containers ont les bonnes valeurs par défaut côté Bicep
  (`content-release-descriptors`, `content-public-releases`,
  `content-private-releases`) et n'ont pas à être surchargés dans le
  `.bicepparam` — mais voir l'avertissement tout-ou-rien ci-dessous, qui
  s'applique au chemin par variables.
- **Les six variables GitHub Environment sont tout-ou-rien.**
  `validateContentConfiguration` retourne `null` quand les six sont vides
  (aucun paramètre injecté : le `.bicepparam` fait foi) et **lève une erreur**
  quand une à cinq seulement sont renseignées. Un environnement à 1/6 fait
  donc **échouer** le job `deploy-infra`. Renseigner les six — les trois noms
  de containers inclus, malgré leurs valeurs par défaut Bicep — ou aucune.
  Ce piège est resté latent tant que `cd-backend.yml` était désactivé.
- `ci-content-drift.yml` consomme `AZURE_CONTENT_READER_CLIENT_ID` pour son
  login OIDC. Cette variable seule ne suffit pas et déclenche précisément
  l'erreur tout-ou-rien décrite ci-dessus.
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
  peerings connectés, intégration VNet des Function Apps) a longtemps été
  vérifié **topologiquement** seulement. Il est désormais **confirmé par un
  aller-retour data-plane réel**, le 2026-09-07, depuis la Function App dev :
  import de la release complète en 58,6 s, puis, en télémétrie App Insights,
  **1329 dépendances Blob vers le compte de contenu, 1329 succès, 0 échec,
  9,13 ms de moyenne** — contre 0 avant l'import. La latence, très inférieure à
  celle du stockage de packages, est cohérente avec un accès par private
  endpoint. Le chemin dev est donc prouvé; **staging et prod restent non
  éprouvés** et leur premier import doit toujours être traité comme
  l'expérience, pas comme une formalité.
- Vérifier ce compteur est le contrôle positif à utiliser avant de conclure
  qu'un échec est réseau. Attention : `az monitor app-insights query -o tsv`
  rend un résultat agrégé comme `1`; utiliser `-o json`, et passer la requête
  KQL **sur une seule ligne**.
- Le jeton opérateur porte l'app role `Content.Release.Admin`. **Vérifier que
  ce rôle existe et est attribué avant toute tentative**, sinon chaque appel
  retourne 403 :

  ```bash
  az ad app show --id <api-app-id> --query "appRoles[].value" -o json
  ```

  Un tableau vide signifie que le rôle n'a jamais été déclaré. En dev
  uniquement, `CONTENT_ADMIN_ALLOW_DEV=true` combiné à un jeton
  `Authorization: Bearer dev` contourne ce contrôle; ce contournement n'existe
  ni en staging ni en production.
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
  "$API/content/admin/releases/$RELEASE_ID/import"
```

Un premier import retourne 201; un replay exact retourne 200. Toute erreur de
schema/hash/taille/référence doit laisser les trois containers sans receipt
complet. Ne pas promouvoir une release sans receipt.

## Lire puis promouvoir le pointeur

```bash
curl --fail-with-body \
  -D pointer.headers \
  -H "Authorization: Bearer $TOKEN" \
  "$API/content/admin/releases/pointer" \
  -o pointer.json

ETAG="$(awk 'BEGIN{IGNORECASE=1} /^etag:/ {gsub(/\r/,""); print $2}' pointer.headers)"
# Pour la toute première activation, utiliser littéralement '*'.

curl --fail-with-body \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "If-Match: ${ETAG:-*}" \
  "$API/content/admin/releases/$RELEASE_ID/promote"
```

Une ETag obsolète retourne 412. Relire le pointeur; ne pas réessayer avec `*`
si un pointeur existe.

Codes de retour observés sur `promote`, et ce qu'ils discriminent :

| Requête | Code | Ce que cela prouve |
| --- | --- | --- |
| sans `If-Match` | 428 | la route a exécuté le handler; précondition exigée |
| `If-Match` bogus, pointeur absent | 412 | **le receipt d'import existe** : un receipt manquant lève 404 *avant* le contrôle de précondition |
| `If-Match: *`, première activation | 200 | pointeur créé |

Le 412 est donc un contrôle positif utile : il confirme que l'import a bien
laissé un receipt, indépendamment de la lecture du pointeur.

> **Les routes d'administration ne peuvent pas commencer par `admin/`.**
> L'hôte Functions (`ScriptHost`) rejette toute route dont le segment initial
> est `admin` ou `runtime`, en inspectant la route **déclarée**, avant
> application du préfixe `api`. La fonction n'est alors pas enregistrée et
> l'appel retourne **404 avec un corps vide (0 octet)**, ce qui se lit comme un
> problème de permissions ou de réseau. Les routes sont donc
> `content/admin/releases/…` et non `admin/content/releases/…`.
> `HttpRouteReservationTests` verrouille cette contrainte.
>
> Discriminateur à retenir : **c'est le corps, pas le statut.** Un chemin non
> routé renvoie 404 **0 octet**; un handler qui s'exécute et ne trouve rien
> renvoie 404 **avec un corps JSON**. Les deux sont des 404.

## Vérifications staging

> **Contrôle décisif — `GET /api/catalog/tracks` avec un JWT learner.**
> C'est lui qui prouve qu'un learner reçoit le contenu de la release. En mode
> `legacy` il retourne **503 « database needs to be seeded »**; en `versioned`,
> **200** avec la liste des tracks. Les points 1 à 4 ci-dessous portent sur des
> routes de **métadonnées** : elles répondent 200 même quand `catalog/tracks`
> est encore en 503. Ne pas conclure au succès sur le seul manifeste.
>
> Le nombre de tracks servi est **inférieur** au nombre de certifications
> publiées : `RuntimeContentProjector.IsRecommended` filtre les tracks dont le
> cycle de vie ou le statut de certification n'est pas actif. Une certification
> `status = "retired"` est volontairement retirée du catalogue. Vérifier ce
> statut dans `content/public/catalog/certifications.json` avant de traiter un
> écart comme une perte de données.

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
8. Basculer **l'environnement cible seulement** vers
   `CONTENT_REPOSITORY_MODE=versioned`. Ce réglage **est** une variable GitHub
   Environment : `cd-backend.yml` la lit (`vars.CONTENT_REPOSITORY_MODE`) et
   `write-secure-bicep-parameters.mjs` l'injecte comme paramètre
   `contentRepositoryMode`, que `infra/modules/functionApp.bicep` publie en app
   setting. C'est le **seul** chemin supporté : `infra/tests/content-storage.test.mjs`
   (`all committed environments stay legacy and immutable`) **interdit** la
   ligne `param contentRepositoryMode = …` dans les trois fichiers
   `infra/params/*.bicepparam` — l'écrire fait échouer la CI. Attention, le
   test lit le fichier entier : un commentaire contenant cette chaîne suffit à
   le faire échouer.

   Deux conditions non évidentes :
   - la variable n'est injectée que si les **six** variables de contenu sont
     renseignées (`contentConfiguration !== null`); sinon `versioned` est
     ignoré ou rejeté selon le cas;
   - les variables sont résolues au **démarrage du run**. `cd-backend.yml`
     n'expose pas `workflow_dispatch`; un `gh run rerun <id>` relit bien les
     variables et suffit à propager la bascule.

   Après déploiement, vérifier **d'abord** l'app setting effectif, **puis** le
   comportement : « n'a pas fonctionné » et « n'a pas été exécuté » produisent
   la même réponse 503.

   ```bash
   az functionapp config appsettings list -n <function-app> -g <rg> -o json \
     | jq -r '.[] | select(.name=="CONTENT_REPOSITORY_MODE") | .value'
   ```

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
  "$API/content/admin/releases/pointer" \
  -o rollback-pointer.json

ROLLBACK_ETAG="$(
  awk 'BEGIN{IGNORECASE=1} /^etag:/ {gsub(/\r/,""); print $2}' \
    rollback-pointer.headers
)"

curl --fail-with-body \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "If-Match: $ROLLBACK_ETAG" \
  "$API/content/admin/releases/rollback"
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
4. Renseigner les valeurs de contenu (`contentBlobEndpoint`,
   `contentReaderClientId`, `contentReaderResourceId`) par l'un des deux
   chemins décrits en Préconditions — `infra/params/staging.bicepparam`, ou les
   six variables GitHub Environment qui le surchargent — puis redéployer
   l'infrastructure. Laisser le mode à `legacy` : la Function attache
   uniquement l'UAMI reader externe et reste en `legacy`.
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
9. Basculer le mode vers `versioned` via la variable GitHub Environment
   `CONTENT_REPOSITORY_MODE` de l'environnement cible seulement (voir
   Vérifications, point 8 : le `.bicepparam` est interdit par un test
   committé), redéployer, vérifier l'app setting effectif **avant** tout test
   de comportement, puis vérifier manifeste/ETag, catalog, lesson, quiz, exam,
   tutor et absence de données privées.
10. Publier et promouvoir la seconde release, puis prouver le rollback N-1 avec
   `If-Match`; un second rollback doit retourner 409 et aucun artefact ne doit
   être supprimé ou réécrit.
11. En cas d'échec, remettre staging en `legacy`; ne modifier ni prod ni les
   policies. Examiner coûts et preuves avant toute suite.
12. Ne verrouiller aucune policy pendant le pilote. Un futur lock WORM,
    irréversible, exige une décision OPS/compliance et une procédure séparée;
    aucune commande de lock ne doit entrer dans un workflow.
