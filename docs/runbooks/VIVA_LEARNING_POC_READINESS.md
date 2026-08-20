# Readiness du POC Viva Learning

> **Statut : contrats offline uniquement ; tenant, Viva et Graph live NO-GO.**
> Ce document inventorie les preuves et prérequis d'une éventuelle phase
> ultérieure. Il ne fournit aucune commande d'activation, aucun payload live et
> aucune procédure de consentement, publication ou nettoyage.

## Posture fail-closed

Le dépôt ne contient ni inscription Entra POC, ni permission, ni token, ni
credential, ni provider Viva. Le spike n'a aucun transport réseau : son client
accepte uniquement `FixtureGraphMessageHandler`.

Les valeurs suivantes restent désactivées ou vides :

```powershell
$env:VIVA_LEARNING_POC_LIVE_ENABLED = "false"
$env:VIVA_POC_TENANT_ID = ""
$env:VIVA_POC_LEARNER_OBJECT_ID = ""
$env:PUBLIC_WEB_ORIGIN = ""
$env:PUBLIC_DOMAIN_VERIFIED = "false"
$env:APPLE_CIAM_DOMAIN_RECONFIGURED = "false"
```

Ces valeurs ne sont inscrites dans aucun manifeste, `*.bicepparam`, fixture ou
fichier de configuration versionné. Le POC ne consomme pas
`VIVA_LEARNING_POC_LIVE_ENABLED`; cette variable documente seulement le NO-GO.

## Contrats prouvés offline

| Preuve | Endpoint contractuel | Mode attendu | Permission minimale documentée | Résultat |
|---|---|---|---|---|
| Provider | `POST /employeeExperience/learningProviders` | délégué administrateur | `LearningProvider.ReadWrite` | fixture `201` |
| Contenu | `PATCH .../learningContents(externalId='{externalId}')` | application | `LearningContent.ReadWrite.All` | fixture `202` |
| Assignations | `GET /me/employeeExperience/learningCourseActivities` | délégué utilisateur | `LearningAssignedCourse.Read.All` selon la page endpoint | fixture `200` |
| Progression | `PATCH .../learningCourseActivities/{activityId}` | application | `LearningAssignedCourse.ReadWrite.All` | fixture `204` |

Le simulateur vérifie les chemins, statuts, payloads, le filtrage
`learningAssignment`, la pagination, la progression 40 % puis 100 %, et le
chemin HTTPS #298 `/learn/{trackId}/{lessonId}` sous une origine `.invalid`.

## Prérequis humains d'une phase ultérieure

Toutes les cases restent décochées dans cette PR :

- [ ] tenant Microsoft 365 non-production dédié et identifié hors du dépôt ;
- [ ] licence Viva Learning ou Viva Suite active dans ce tenant ;
- [ ] opérateur licencié avec le rôle **Knowledge Administrator** ;
- [ ] compte apprenant de test licencié, référencé uniquement par son object ID ;
- [ ] capacité d'accorder les consentements administrateur minimaux et séparés ;
- [ ] origine HTTPS réellement contrôlée fournie par `PUBLIC_WEB_ORIGIN` ;
- [ ] preuve DNS/TLS indépendante puis `PUBLIC_DOMAIN_VERIFIED=true` ;
- [ ] reconfiguration Apple/External ID validée puis
      `APPLE_CIAM_DOMAIN_RECONFIGURED=true` ;
- [ ] associations Android/iOS signées et testées pour
      `/learn/{trackId}/{lessonId}` ;
- [ ] approbation humaine écrite d'un protocole live et de son nettoyage ;
- [ ] revue sécurité et ADR d'intégration post-POC.

La présence d'une origine dans une variable ne prouve jamais sa propriété. Le
contrat de [`PUBLIC_DOMAIN_MIGRATION.md`](../PUBLIC_DOMAIN_MIGRATION.md) doit
rester l'unique gate public-domain.

## Découpage d'autorisation à confirmer

Une éventuelle validation devra conserver trois frontières :

| Interaction | Identité | Limite |
|---|---|---|
| enregistrement provider | administrateur délégué | rôle Knowledge Administrator et licence Viva |
| lecture `/me` | utilisateur délégué | uniquement le compte apprenant connecté |
| publication et progression | workload application | aucun jeton utilisateur |

La documentation Microsoft présente une incohérence bloquante : la page de
l'endpoint de liste indique `LearningAssignedCourse.Read.All` en délégué et
aucune permission application, tandis que la référence globale catalogue
`LearningAssignedCourse.Read` en délégué et
`LearningAssignedCourse.Read.All` en application. Aucun scope ne doit être
substitué. Si le scope endpoint exact n'est pas disponible, le verdict reste
NO-GO et doit être clarifié avec Microsoft.

## Frontière Person / LinkedIdentity

Le champ Graph `learnerUserId` est nommé `EnterpriseLearnerObjectId` dans le
spike. Il représente une donnée d'entreprise observée dans le tenant Viva. Il
n'est ni un `personId`, ni le `userId` legacy Certigo, ni une preuve de liaison.

- aucune corrélation par e-mail, nom ou `preferred_username` ;
- aucune écriture `Person` ou `LinkedIdentity` ;
- aucun import de progression Viva dans la maîtrise, la readiness, les
  récompenses, la progression ou les acquis personnels ;
- aucune fusion de données entre tenants ou entre Person ;
- aucune modification du resolver legacy, qui reste autoritaire en mode
  Person/LinkedIdentity `off|shadow`.

Une intégration future devrait valider `tid + oid` selon
`docs/contracts/person-linked-identity/v1`, puis faire l'objet d'un ADR séparé
sur la finalité, la rétention et les conflits des données d'entreprise.

## Critères de sortie encore absents

| Niveau | Verdict | Preuve manquante |
|---|---|---|
| Contrats HTTP/JSON | **GO offline** | tests locaux verts |
| Tenant Viva | **NO-GO** | tenant non-prod licencié et opérateur Knowledge Administrator |
| Consentements | **NO-GO** | scopes exacts confirmés et approuvés |
| Domaine public | **NO-GO** | gate #313 complet sur une origine contrôlée |
| Deep-link mobile | **NO-GO** | #298 réconciliée, associations signées et tests appareils |
| Identité | **NO-GO** | ADR entreprise et liaison `tid + oid` vérifiée |
| Production | **NO-GO** | pilote live autorisé, revue sécurité et architecture approuvée |

## Risques résiduels

1. Contradiction de permissions Microsoft pour la lecture des assignations.
2. Disponibilité et comportement réels de l'API conditionnés par la licence et
   le rôle du tenant.
3. Ingestion de contenu asynchrone non observée live.
4. Universal Links/App Links non activés et non testés sur appareil.
5. Sémantique de progression Viva potentiellement différente des acquis
   personnels Certigo.
6. Gouvernance, rétention, audit et suppression des données d'entreprise non
   décidés.
