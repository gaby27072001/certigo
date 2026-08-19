# ADR-014 — POC isolé d'intégration Certigo avec Viva Learning

| Champ | Valeur |
|---|---|
| **ADR** | 014 |
| **Statut** | **Accepté pour preuve contractuelle** ; **NO-GO live/production** |
| **Date** | 2026-08-19 |
| **Portée** | Phase 1 du plan directeur, sans déploiement ni modification des fonctionnalités de production |

## Contexte

La Phase 1 doit déterminer si Certigo peut :

1. être enregistré comme `learningProvider` ;
2. publier un `learningContent` ;
3. lire une `learningAssignment` pour l'utilisateur connecté ;
4. mapper ce contenu vers une leçon Certigo ;
5. synchroniser progression et complétion.

Le dépôt contient déjà la route Flutter
`/lesson/:trackId/:lessonId` (`apps/mobile/lib/app/router.dart`), mais aucun
Android App Link HTTPS ni iOS Universal Link. Le schéma `certigo://` est
actuellement déclaré uniquement pour l'authentification iOS ; Android ne
déclare pas d'intent-filter de contenu.

## Constat d'autorisation

Un seul jeton ou une seule identité ne peut pas couvrir le flux.

| Opération | Endpoint | Mode accepté par la page de l'endpoint | Permission minimale |
|---|---|---|---|
| Créer le provider | `POST /employeeExperience/learningProviders` | Délégué uniquement | `LearningProvider.ReadWrite` |
| Publier le contenu | `PATCH .../learningContents(externalId='{externalId}')` | Application uniquement | `LearningContent.ReadWrite.All` |
| Lire les assignations de l'utilisateur | `GET /me/employeeExperience/learningCourseActivities` | Délégué uniquement ; application non supportée | `LearningAssignedCourse.Read.All` |
| Mettre à jour progression/complétion | `PATCH .../learningCourseActivities/{id}` | Application uniquement | `LearningAssignedCourse.ReadWrite.All` |

La création du provider exige aussi une licence Viva Learning ou Viva Suite et
un rôle Entra pris en charge ; **Knowledge Administrator** est le rôle minimal.
Le provider doit avoir `isCourseActivitySyncEnabled=true` pour accepter les
activités.

> **Incohérence documentaire à lever en live.** La page de l'endpoint de liste
> indique `LearningAssignedCourse.Read.All` en délégué et aucune permission
> application, tandis que la référence globale des permissions catalogue
> `LearningAssignedCourse.Read` en délégué et `LearningAssignedCourse.Read.All`
> en application. Le POC respecte le contrat spécifique de l'endpoint demandé.
> Aucun consentement ne doit être accordé si le portail Entra n'expose pas ce
> scope délégué exact ; ce cas est un **NO-GO** à escalader auprès de Microsoft.

## Décision

Créer un projet .NET 8 **isolé** sous
`backend/spikes/Certigo.VivaLearning.Poc`, sans référence depuis
`Certigo.Api`, sans SDK Graph supplémentaire, sans secret et sans mode live.

- `IVivaLearningGraphClient` et `VivaLearningGraphClient` matérialisent les
  méthodes, chemins, statuts HTTP et payloads Graph.
- `CertigoVivaLearningAdapter` produit un `externalId` stable
  `certigo:{trackId}:{lessonId}` et un `contentWebUrl` HTTPS dont le chemin
  correspond à la route Flutter existante.
- `FixtureGraphMessageHandler` simule Graph à partir de fixtures contractuelles
  et capture chaque requête.
- `CERTIGO_VIVA_LEARNING_POC_ENABLED` est `false` par défaut. Même activé, le
  harness ne contacte aucun réseau et utilise le domaine réservé `.invalid`.
- Les tests vérifient le découpage des permissions, les cinq appels simulés,
  le filtrage `learningAssignment`, le deep-link, et les transitions 40 % puis
  100 %.

## Résultat Phase 1

| Question | Preuve exécutable | Résultat |
|---|---|---|
| Enregistrer un provider | Contrat `POST`, payload logos/sync, fixture `201` | **GO contractuel** |
| Publier un contenu | Contrat `PATCH` par `externalId`, fixture `202` | **GO contractuel** |
| Lire une assignation | Contrat `/me`, header d'enum évolutive, fixture `200` | **GO contractuel**, permission live à confirmer |
| Mapper/deep-linker | Mapping vers `/lesson/az-900/az900-l-cloud-benefits` | **GO mapping**, **NO-GO ouverture app HTTPS** |
| Synchroniser la progression | `PATCH` 40 % `inProgress`, puis 100 % `completed` | **GO contractuel** |

Le verdict global est donc :

- **GO** pour poursuivre vers un test tenant non-production contrôlé ;
- **NO-GO** pour intégration production, fusion ou déploiement ;
- **NO-GO live immédiat** tant que le tenant Viva licencié, le consentement
  exact et les App/Universal Links HTTPS ne sont pas validés.

## Conséquences

- Aucune fonctionnalité de production, configuration d'authentification,
  permission Entra, ressource Azure ou application mobile n'est modifiée.
- Le futur design doit séparer au minimum l'interaction administrateur,
  l'interaction utilisateur et le worker application.
- L'ingestion de contenu est asynchrone (`202 Accepted`) ; le test live doit
  relire le contenu avant de créer l'assignation.
- La réussite d'un simple mapping URL ne prouve pas l'ouverture de l'app. Les
  associations HTTPS Android/iOS restent une condition de sortie.

## Références officielles

- [Vue d'ensemble de l'API employee learning](https://learn.microsoft.com/graph/api/resources/viva-learning-api-overview?view=graph-rest-1.0)
- [Créer un learningProvider](https://learn.microsoft.com/graph/api/employeeexperience-post-learningproviders?view=graph-rest-1.0)
- [Publier/mettre à jour un learningContent](https://learn.microsoft.com/graph/api/learningcontent-update?view=graph-rest-1.0)
- [Lister les learningCourseActivities](https://learn.microsoft.com/graph/api/learningcourseactivity-list?view=graph-rest-1.0)
- [Créer une learningCourseActivity](https://learn.microsoft.com/graph/api/employeeexperienceuser-post-learningcourseactivities?view=graph-rest-1.0)
- [Mettre à jour une learningCourseActivity](https://learn.microsoft.com/graph/api/learningcourseactivity-update?view=graph-rest-1.0)
- [Référence des permissions Microsoft Graph](https://learn.microsoft.com/graph/permissions-reference#employee-learning-permissions)
