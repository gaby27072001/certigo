# Contrat Learning Journey V1

**Version :** `1.0.0`

**Statut :** surface livree, conforme au code a la date de mesure ci-dessous.

Ce repertoire decrit le **parcours critique** du learner — la surface qu'une application
native appelle en premier :

| Operation | Route |
|---|---|
| Profil | `GET /me` |
| Chemin et readiness | `GET /me/paths/{trackId}` |
| Prochaines actions | `GET /me/recommendations/{trackId}` |
| Lecon | `GET /tracks/{trackId}/lessons/{lessonId}` |
| Soumission de quiz | `POST /quiz/{lessonId}/submit` |
| Generation d'examen blanc | `POST /exam/generate` |
| Soumission d'examen blanc | `POST /exam/submit` |

La garde vit dans `backend/tests/Certigo.Api.Tests/ApiSurfaceContractTests.cs`.

## Pourquoi un domaine separe, et pas une extension d'un contrat existant

Deux candidats existaient.

`person-linked-identity/v1` contient deja `GET /catalog/tracks`, `POST /me/active-track` et
`GET|POST /account/deletion`. C'est un contrat **de phase de migration**, adosse a
[ADR-014](../../../adr/ADR-014-person-linked-identity.md), avec son propre cycle de vie
`off|shadow` destine a se terminer. Y verser la surface permanente du parcours critique
coupleraient le coeur de l'application au calendrier d'une migration. Les routes deja
absorbees par ce contrat n'ont donc **pas** ete dupliquees ici : dupliquer un chemin creerait
deux sources de verite pour une meme route, ce que la garde interpreterait comme une
ambiguite.

`runtime-content/v1` decrit la distribution de contenu (manifestes, fichiers, ETag), pas la
progression d'un learner. Les deux surfaces se rencontrent sur l'en-tete
`X-Content-Manifest-Id`, reference ici sans etre redefinie.

Le decoupage retenu suit donc la **posture d'autorisation et le cycle de vie**, pas le
decoupage des fichiers de fonctions : une seule posture `bearerAuth`, un seul proprietaire
derive du JWT, aucune porte de fonctionnalite.

## Invariants gardes

| Invariant | Ou il est verifie |
|---|---|
| Aucune de ces routes n'est absente du backend | `Every_contracted_operation_exists_in_the_backend` |
| Aucune route backend du parcours n'echappe au contrat | `Every_backend_operation_is_contracted_or_explicitly_deferred` |
| `clientAttemptId` reste obligatoire sur les deux soumissions | `Critical_path_submissions_stay_idempotent_and_owner_implicit` |
| Aucun `userId`, `personId` ni `ownerId` accepte depuis un corps de requete | idem |
| Le schema public d'un item reflete exactement `LessonCheck`, sans `correct` ni `explanation` | `Public_lesson_schema_exposes_no_more_than_the_public_domain_model` |
| Ces routes exigent bien un jeton cote middleware | `Contracted_anonymity_matches_the_authentication_middleware` |

Le dernier invariant de schema est compare au **modele de domaine reel**
(`Certigo.Domain.Content.LessonCheck` et `AnswerKeyItem`) par reflexion, pas a une liste
recopiee : ajouter `correct` au modele public ferait rougir la garde.

## Autorite du serveur

`x-certigo-scoring.authority` vaut `server`. Le Cortex client existe pour la reactivite de
l'interface et doit rester **equivalent en comportement** a l'implementation .NET, qui seule
fait foi sur la notation, la progression, les recompenses et la readiness.

## Recommandation : ne pas generer ces documents

Aucun paquet Swashbuckle, NSwag ou Microsoft.OpenApi n'est reference par les `.csproj` du
backend ; les cinq contrats preexistants sont ecrits a la main, et celui-ci suit la meme
convention. Ce choix merite d'etre conserve, pour une raison mesurable : ces documents
portent des faits qu'aucun generateur ne peut deduire du code — l'anti-enumeration de
comptes, la separation entre charge utile publique et corrige serveur, l'ordre d'evaluation
d'une porte de fonctionnalite avant l'authentification, l'autorite du serveur sur la
notation. Un generateur produirait des chemins et des schemas exacts, et **perdrait
exactement la partie du contrat qui empeche deux applications natives de diverger**.

La faiblesse reelle d'un contrat manuscrit n'est pas l'exactitude des schemas mais la
**derive silencieuse**. C'est ce que `ApiSurfaceContractTests` traite, dans les deux sens,
en lisant les attributs `HttpTrigger` reels.

## Mesure

Les sept operations correspondaient une a une aux routes declarees par `UserFunctions`,
`PathFunctions`, `RecommendationFunctions`, `LessonFunctions`, `QuizFunctions` et
`ExamFunctions` le **2026-09-11**, verifie par reflexion sur les attributs `HttpTrigger`
dans `ApiSurfaceContractTests`.

Les routes du backend encore non contractees ce jour-la sont inscrites, avec leur raison,
dans [`docs/contracts/deferred-routes.json`](../../deferred-routes.json).
