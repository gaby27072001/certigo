# ADR-021 — Le manifeste public pilote le cache offline mobile

| Champ | Valeur |
|---|---|
| **ADR** | 021 |
| **Statut** | Accepté |
| **Date** | 2026-09-04 |
| **Lot** | `wp-p2-05` / #243 |
| **Dépendance** | `wp-p2-04` / PR #363 |

## Contexte

Le cache livré par `wp-p1-08` conserve des leçons dans une valeur
`SharedPreferences` unique, invalidée par un `CONTENT_MANIFEST_VERSION` fourni à
la compilation. Il ne peut ni découvrir la release active, ni reprendre un
téléchargement interrompu, ni conserver N-1. Une écriture de la nouvelle version
purge en outre l'ancienne avant que la nouvelle soit complète.

La PR #363 introduit des releases runtime immuables. Le backend expose le
manifeste public actif, épingle chaque leçon à son `publicManifestId` et sait
résoudre toute release déjà activée sans exposer le manifeste privé.

## Décision

1. Le backend dérive un manifeste `certigo.mobile-offline-manifest/v1` du
   snapshot runtime immuable identifié par `publicManifestId`. Il décrit
   uniquement le catalogue applicatif et les payloads `Lesson` déjà compris par
   le mobile. Chaque entrée contient son identité, son chemin, son type, sa taille
   exacte et le SHA-256 des octets effectivement servis.
2. Les endpoints de payload exigent un JWT learner et un `publicManifestId`
   explicite. Cette identité est résolue par le repository versionné : un import
   seulement stagé ou une identité inconnue échoue, même si le backend sert encore
   le repository historique pour les routes non épinglées.
3. Le client compare le manifeste distant à son journal local. Il réutilise un
   élément N-1 seulement si type, identité, taille et hash correspondent, puis ne
   télécharge que les éléments manquants ou modifiés. Il vérifie en plus les
   headers `X-Content-Manifest-Id`, `X-Content-SHA256` et `Content-Length`.
4. Le stockage mobile utilise deux slots A/B. Chaque mutation écrit le document
   complet dans le slot inactif avant de basculer le pointeur. Une génération
   partielle reste en staging et est reprise au prochain démarrage ; seule une
   génération complète et revérifiée devient active. L'activation conserve
   exactement la précédente comme rollback local N-1.
5. La migration du cache `wp-p1-08` est conservative : seules les leçons portant
   déjà le même `publicManifestId` et dont les octets correspondent au descripteur
   sont copiées. Le catalogue historique, non épinglé, est retéléchargé. Les clés
   historiques ne sont pas supprimées afin que le rollback applicatif reste
   immédiat.
6. Le mobile refuse tout type autre que `catalog` ou `lesson`, tout fichier non
   déclaré et toute clé privée (`answerKey`, `correct`, `correctOptionIds`,
   `explanation`, `rationale`, `solution`, `privateManifestId`, `releaseId`).
7. Une leçon relue depuis le cache conserve son `publicManifestId`; les
   soumissions offline gardent donc la même clé d'idempotence et la même release
   de notation après une promotion ou un rollback.
8. `RELEASE_OFFLINE_CACHE=false` garde les repositories de `wp-p1-08`. Lorsque
   le flag est actif, seul un endpoint absent (404) signifie « capability non
   disponible » et autorise ce chemin de compatibilité. Une erreur réseau, un
   schéma futur, un hash invalide ou une corruption ne sont pas transformés en
   succès : ils sont télémétrés sans payload et le dernier cache compatible n'est
   utilisé que s'il repasse toutes les vérifications.

## Conséquences

- Une coupure entre l'écriture du slot et la bascule du pointeur laisse l'ancien
  cache actif ; au pire, le dernier élément est retéléchargé.
- Une promotion ne rend jamais un cache partiel visible. Un rollback backend vers
  N-1 réactive la génération locale correspondante sans téléchargement si ses
  hashes sont inchangés.
- Un cache actif corrompu peut revenir sur N-1 valide avec un événement de
  dégradation. Sans génération valide, le client retourne une `CacheFailure`.
- Un manifeste offline d'une version future reste inactif ; la dernière version
  v1 complète continue d'être utilisable hors ligne.
- Le scope reste volontairement limité aux formes `CatalogDto` et `Lesson`
  actuelles. L'alignement de `mcq`, `multiSelect`, `scenario`, `ordering`,
  `matching`, `fillBlank` et `spotIssue` demeure dans `wp-p2-06`.

## Références

- `docs/adr/ADR-019-runtime-content-releases.md`
- `docs/runbooks/CONTENT_RELEASES.md`
- `packages/data/lib/src/sync/content_release_cache_store.dart`
- `packages/data/lib/src/sync/offline_content_release.dart`
