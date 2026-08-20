# ADR-015 — POC isolé d'intégration Certigo avec Viva Learning

| Champ | Valeur |
|---|---|
| **ADR** | 015 |
| **Statut** | **Accepté pour preuve contractuelle** ; **NO-GO live/production** |
| **Date** | 2026-08-20 |
| **Portée** | Phase 1 du plan directeur, sans déploiement ni modification des fonctionnalités de production |

## Contexte

La Phase 1 doit déterminer si Certigo peut :

1. être enregistré comme `learningProvider` ;
2. publier un `learningContent` ;
3. lire une `learningAssignment` pour l'utilisateur connecté ;
4. mapper ce contenu vers une leçon Certigo ;
5. synchroniser progression et complétion.

Le contrat stable de la PR #298 sépare le chemin HTTPS public
`/learn/{trackId}/{lessonId}` de la route Flutter interne
`/lesson/:trackId/:lessonId`. Son host reste neutralisé par
`links-disabled.invalid` et son feature flag est désactivé. Les garde-fous
fusionnés par #312 et #313 interdisent tout domaine tiers et exigent
`PUBLIC_WEB_ORIGIN`, `PUBLIC_DOMAIN_VERIFIED=true` et
`APPLE_CIAM_DOMAIN_RECONFIGURED=true` avant une activation future.

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
  `certigo:{trackId}:{lessonId}` et le chemin HTTPS #298
  `/learn/{trackId}/{lessonId}`. Dans le spike, l'origine doit appartenir au
  domaine réservé `.invalid`.
- `FixtureGraphMessageHandler` simule Graph à partir de fixtures contractuelles
  et capture chaque requête.
- `CERTIGO_VIVA_LEARNING_POC_OFFLINE_ENABLED` est `false` par défaut. Même
  activé, le harness ne contacte aucun réseau : le client n'accepte que
  `FixtureGraphMessageHandler` et l'adapter refuse toute origine routable.
- Le `learnerUserId` Graph est nommé `EnterpriseLearnerObjectId` dans le DTO.
  Il n'est jamais résolu vers `Person` ou `LinkedIdentity`, ni utilisé pour
  importer progression, maîtrise, readiness, récompenses ou acquis personnels.
- Les tests vérifient le découpage des permissions, les cinq appels simulés,
  le filtrage `learningAssignment`, le deep-link, et les transitions 40 % puis
  100 %.

## Résultat Phase 1

| Question | Preuve exécutable | Résultat |
|---|---|---|
| Enregistrer un provider | Contrat `POST`, payload logos/sync, fixture `201` | **GO contractuel** |
| Publier un contenu | Contrat `PATCH` par `externalId`, fixture `202` | **GO contractuel** |
| Lire une assignation | Contrat `/me`, header d'enum évolutive, fixture `200` | **GO contractuel**, permission live à confirmer |
| Mapper/deep-linker | Publication de `/learn/az-900/az900-l-cloud-benefits` selon #298 | **GO mapping**, **NO-GO ouverture app HTTPS** |
| Synchroniser la progression | `PATCH` 40 % `inProgress`, puis 100 % `completed` | **GO contractuel** |

Le verdict global est donc :

- **GO** pour poursuivre vers un test tenant non-production contrôlé ;
- **NO-GO** pour intégration production, fusion ou déploiement ;
- **NO-GO live immédiat** tant que le tenant Viva licencié, le consentement
  exact et les App/Universal Links HTTPS ne sont pas validés.

## Conséquences

- Aucune fonctionnalité de production, configuration d'authentification,
  permission Entra, ressource Azure ou application mobile n'est modifiée.
- Les données d'assignation Viva restent des données d'entreprise. Elles ne
  fusionnent pas avec les acquis personnels détenus par `Person`; toute
  corrélation future exige une `LinkedIdentity` vérifiée et un ADR distinct.
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
