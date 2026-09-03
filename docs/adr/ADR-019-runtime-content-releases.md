# ADR-019 — Releases de contenu runtime immuables

| Champ | Valeur |
|---|---|
| **ADR** | 019 |
| **Statut** | Accepté |
| **Date** | 2026-08-19 |
| **Lot** | `wp-p2-04` / #244 |
| **Contrat amont** | `certigo-content` merge `87ae81724899387a8d6c922f0dc4b4631b6523ec` |

## Contexte

Le repository historique lit `Track`, `Lesson` et `LessonAnswerKey` dans un
container Cosmos unique sans identité de release. Une promotion éditoriale peut
donc modifier la matière utilisée pour noter une tentative déjà commencée, et
le rollback dépend d'un reseed mutable.

`certigo-content` définit désormais:

- `certigo.content.release/v1`, qui lie les manifestes public et privé par
  `releaseId`;
- `package-manifest/v1`, `/v2` et `/v3`;
- le graphe runtime canonique v1;
- les questions/solutions v4 à options stables;
- des parcours `guided` reference-only et des tracks `questionBank`.

## Décision

1. Le backend importe exclusivement depuis des versions Blob WORM lues par une
   identité managée `Storage Blob Data Reader`.
2. Release, manifestes, chemins, schémas, hashes, tailles, graphe et anti-fuite
   sont vérifiés avant la première écriture Cosmos.
3. Une `release/v1` est acceptée uniquement avec deux
   `package-manifest/v3`; v1/v2 restent vérifiables mais n'ont pas de descriptor
   runtime promotable.
4. Le projecteur C# reproduit le contrat canonique:
   - guided: les blocs `check` résolvent une question par référence;
   - questionBank: une unit et une lesson de pratique sont synthétisées par
     domaine;
   - `legacyId` devient l'identité runtime lorsque présent.
5. Cosmos sépare `content-public`, `content-private` et `content-control`.
   Tous les documents d'une release sont create-only et partitionnés par
   `releaseId`; le receipt compact (compte + digest des versions Blob) est
   prévalidé en taille et créé en dernier.
6. Le singleton `active` conserve active/previous. Promotion et rollback N-1
   utilisent ETag et une transactional batch mono-partition.
7. Quiz, examens et tuteur résolvent uniquement un `publicManifestId` appartenant
   à une release déjà activée; les imports de staging restent inaccessibles. Les
   nouveaux attempts persistent `releaseId` et `publicManifestId`.
8. `CONTENT_REPOSITORY_MODE=legacy|versioned` garde le repository historique
   comme rollback explicite. Aucun fallback implicite n'est permis en mode
   versionné.

## Frontières de sécurité

- Les containers Blob descriptor/public/private sont distincts et privés.
- Les documents de correction n'entrent jamais dans `content-public`.
- L'endpoint learner retourne uniquement le manifeste public actif et utilise
  son `publicManifestId` comme ETag.
- Import, promotion, rollback et lecture du pointeur exigent l'app role
  `Content.Release.Admin`; aucune Function key n'est utilisée.
- Les événements Application Insights contiennent IDs, résultat, durée et
  catégorie d'échec, jamais le texte des questions ou solutions.

## Conséquences

- Une interruption d'import est récupérable par replay idempotent.
- Un `publicManifestId` est lié définitivement à une seule release/private
  manifest avant exposition; un binding sans receipt complet n'est pas
  résolvable.
- Une activation crée atomiquement un marqueur immuable par release; ce marqueur
  permet les tentatives épinglées historiques sans exposer un import jamais promu.
- Une promotion concurrente échoue en 412 sans écraser le pointeur.
- Le rollback ne supprime aucune release et ne peut revenir qu'à N-1.
- Les anciens attempts restent lisibles avec une identité de contenu nullable.
- Le stockage de contenu est provisionné séparément par la PR #290. Le backend
  consomme son endpoint et son UAMI reader externes; il ne crée ni compte,
  ni identité reader, ni RBAC de contenu.
- La publication des blobs et leur politique WORM restent une responsabilité
  du pipeline `certigo-content`; ce lot ne publie aucun contenu.

## Références

- `docs/runbooks/CONTENT_RELEASES.md`
- `backend/src/Certigo.Application/Services/ContentContractVerifier.cs`
- `backend/src/Certigo.Domain/Content/RuntimeContentProjector.cs`
- `backend/src/Certigo.Infrastructure/Cosmos/CosmosContentReleaseStore.cs`
- `infra/content/main.bicep` dans la PR #290
