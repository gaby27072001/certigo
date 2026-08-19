# Runbook — import, promotion et rollback des releases de contenu

Ce runbook est une procédure opérateur. La PR #244 ne déploie, ne publie et
n'active aucune release.

## Préconditions

- Le backend déployé contient les containers Blob/Cosmos du lot.
- `CONTENT_REPOSITORY_MODE=legacy` reste actif pendant l'import initial.
- Les blobs suivent la convention:
  - descriptor: `releases/<releaseId>/release.json`;
  - public/privé:
    `manifests/<manifestId>/manifest.json` et
    `manifests/<manifestId>/<file.path>`.
- Chaque blob possède un `versionId` et une policy d'immutabilité non expirée ou
  un legal hold.
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
3. Vérifier que `GET /tracks/{trackId}/lessons/{lessonId}` retourne le même
   identifiant dans `X-Content-Manifest-Id`; le client doit le conserver dans
   son cache et l'envoyer aux requêtes quiz/tuteur.
4. Vérifier l'absence de `releaseId`, `privateManifestId`, `correct`,
   `correctOptionIds`, `explanation`, `rationale`, `answerKey` et `solution`.
5. Basculer **staging seulement** vers
   `CONTENT_REPOSITORY_MODE=versioned`.
6. Exécuter catalog, lesson, path, quiz, exam et tutor.
7. Soumettre une tentative avec le `publicManifestId`, promouvoir une autre
   release, puis vérifier que le replay et la notation relisent l'ancienne
   release.
8. Contrôler les événements App Insights
   `content.release.import|rejected|promoted|rolled_back`, sans payload.

## Rollback N-1

```bash
curl --fail-with-body \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "If-Match: $ETAG" \
  "$API/admin/content/releases/rollback"
```

Le rollback active `previous`, vide les champs previous et conserve tous les
artefacts. Un second rollback sans nouvelle promotion retourne 409.

## Rollback applicatif

Si le nouveau repository présente un défaut indépendant du contenu:

1. remettre `CONTENT_REPOSITORY_MODE=legacy`;
2. redémarrer la Function App;
3. ne supprimer aucun container, receipt, blob ou attempt;
4. continuer à accepter les opérations déjà épinglées à un
   `publicManifestId`, qui restent résolues dans le store versionné;
5. ouvrir un incident avec correlation ID et release ID, jamais avec le texte
   privé.

## Promotion production

La production est une opération séparée. Réutiliser le même `releaseId`
immuable après preuve staging, approbation de l'environment et validation du
rollback. L'activation production n'est jamais implicite dans un déploiement
backend.
