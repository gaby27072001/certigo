# Validation live du POC Viva Learning

> **Statut : à exécuter par un opérateur humain, après validation explicite.**
> Ce runbook ne doit viser qu'un tenant Microsoft 365 non-production. Aucun
> provider, consentement, token ou permission n'a été créé pendant le spike.

## Garde-fous obligatoires

- Ne pas utiliser les applications Entra, identités, URLs ou ressources Certigo
  de production.
- Ne jamais coller un access token, certificat, assertion ou secret dans Git,
  une issue, une PR, un terminal enregistré ou un fichier du dépôt.
- Ne créer le provider qu'après validation écrite du tenant, de l'opérateur, des
  URLs publiques et du plan de nettoyage.
- Utiliser le service Graph global ; les endpoints documentés ne sont pas
  disponibles dans les clouds US Government ou Chine.
- Arrêter immédiatement sur toute permission différente de la matrice ci-dessous.

## 1. Prévol sans écriture

Cocher chaque prérequis avant de demander un consentement :

- [ ] Tenant Microsoft 365 **non-production** identifié : `<tenant-id>`.
- [ ] Viva Learning ou Viva Suite est activé dans ce tenant.
- [ ] L'opérateur possède une licence Viva et le rôle **Knowledge Administrator**.
- [ ] L'utilisateur test `<learner-upn>` possède la licence requise.
- [ ] Quatre logos HTTPS publics (carré/long, clair/sombre) sont validés.
- [ ] Une URL HTTPS de test dessert exactement
      `/lesson/az-900/az900-l-cloud-benefits`.
- [ ] Android Asset Links et iOS Associated Domains sont en place sur cet hôte,
      ou le test deep-link est explicitement déclaré hors périmètre.
- [ ] Le nom du provider inclut un marqueur temporaire, par exemple
      `Certigo POC 2026-08-19`.
- [ ] Un approbateur humain autorise la création et le nettoyage du provider.

## 2. Consentements minimaux et séparés

Créer des inscriptions **temporaires non-production**, sans client secret :

| Identité POC | Type | Permission | Consentement |
|---|---|---|---|
| `Certigo Viva POC Interactive` | Client public/délégué | `LearningProvider.ReadWrite` | Admin requis |
| Même client, session apprenant | Délégué | `LearningAssignedCourse.Read.All` selon la page de l'endpoint | À confirmer dans Entra |
| `Certigo Viva POC Worker` | Application avec certificat, fédération de workload ou identité managée | `LearningContent.ReadWrite.All` | Admin requis |
| Même worker | Application | `LearningAssignedCourse.ReadWrite.All` | Admin requis |

**Point de contrôle bloquant :** la référence globale des permissions présente
`LearningAssignedCourse.Read` en délégué et `LearningAssignedCourse.Read.All`
en application, alors que la page `List learningCourseActivities` documente
`LearningAssignedCourse.Read.All` en délégué et aucune permission application.
Ne pas substituer silencieusement un scope. Si le scope délégué demandé n'est
pas sélectionnable ou si le token ne le porte pas, classer le test **NO-GO** et
ouvrir un ticket Microsoft avec les deux liens officiels.

Après consentement, décoder localement les jetons sans les copier dans un outil
tiers et vérifier :

- délégué administrateur : `scp` contient seulement les scopes attendus ;
- délégué apprenant : `scp` contient le scope d'assignation validé ;
- application : `roles` contient les deux rôles d'écriture attendus ;
- `tid` correspond au tenant POC.

## 3. Preuve 1 — enregistrer le provider

Avec la session **déléguée administrateur** :

```http
POST https://graph.microsoft.com/v1.0/employeeExperience/learningProviders
Content-Type: application/json

{
  "displayName": "Certigo POC 2026-08-19",
  "squareLogoWebUrlForDarkTheme": "<https-square-dark>",
  "longLogoWebUrlForDarkTheme": "<https-long-dark>",
  "squareLogoWebUrlForLightTheme": "<https-square-light>",
  "longLogoWebUrlForLightTheme": "<https-long-light>",
  "loginWebUrl": "<https-certigo-test-sign-in>",
  "isCourseActivitySyncEnabled": true
}
```

Critères :

- [ ] réponse `201 Created` ;
- [ ] `id` enregistré localement comme `<provider-id>` ;
- [ ] `isCourseActivitySyncEnabled` vaut `true` ;
- [ ] `GET /employeeExperience/learningProviders` retrouve exactement ce provider.

Ne pas poursuivre si le nom existe déjà ou si les URLs pointent vers la
production.

## 4. Preuve 2 — publier le contenu Certigo

Avec le jeton **application worker** :

```http
PATCH https://graph.microsoft.com/v1.0/employeeExperience/learningProviders/<provider-id>/learningContents(externalId='certigo:az-900:az900-l-cloud-benefits')
Content-Type: application/json

{
  "externalId": "certigo:az-900:az900-l-cloud-benefits",
  "title": "Bénéfices du cloud",
  "description": "Leçon Certigo de preuve de concept Viva Learning.",
  "contentWebUrl": "<https-certigo-test>/lesson/az-900/az900-l-cloud-benefits",
  "sourceName": "Certigo",
  "languageTag": "fr-fr",
  "duration": "PT5M",
  "format": "Course",
  "level": "Beginner",
  "isActive": true,
  "isPremium": true,
  "isSearchable": true
}
```

Critères :

- [ ] réponse `202 Accepted` ;
- [ ] relire périodiquement, avec délai borné, via
      `GET /employeeExperience/learningProviders/<provider-id>/learningContents` ;
- [ ] relever `<learning-content-id>` uniquement quand l'`externalId` exact est visible ;
- [ ] la carte apparaît sous le provider POC dans Viva Learning.

## 5. Preuve 3 — créer puis lire une assignation

Créer une assignation temporaire avec le jeton **application worker** :

```http
POST https://graph.microsoft.com/v1.0/employeeExperience/learningProviders/<provider-id>/learningCourseActivities
Content-Type: application/json

{
  "@odata.type": "#microsoft.graph.learningAssignment",
  "assignmentType": "required",
  "externalCourseActivityId": "certigo-poc-activity-20260819",
  "learningContentId": "<learning-content-id>",
  "learningProviderId": "<provider-id>",
  "learnerUserId": "<learner-object-id>",
  "status": "notStarted",
  "completionPercentage": 0
}
```

Puis, connecté comme `<learner-upn>` avec le jeton **délégué utilisateur** :

```http
GET https://graph.microsoft.com/v1.0/me/employeeExperience/learningCourseActivities
Prefer: include-unknown-enum-members
```

Critères :

- [ ] création `201 Created` et `<activity-id>` conservé ;
- [ ] lecture utilisateur `200 OK` ;
- [ ] un objet `#microsoft.graph.learningAssignment` contient les mêmes
      `<provider-id>`, `<learning-content-id>` et `<activity-id>` ;
- [ ] aucun jeton application n'a été utilisé pour l'endpoint `/me`.

## 6. Preuve 4 — deep-link Certigo

Depuis la carte/assignation Viva Learning :

- [ ] le clic cible l'URL HTTPS publiée, sans redirection vers la production ;
- [ ] Android ouvre Certigo via Asset Links ;
- [ ] iOS ouvre Certigo via Associated Domains ;
- [ ] GoRouter reçoit `/lesson/az-900/az900-l-cloud-benefits` ;
- [ ] la bonne leçon s'affiche après authentification ;
- [ ] le fallback navigateur est explicite si l'app n'est pas installée.

L'état actuel du dépôt ne satisfait pas les deux associations HTTPS mobiles.
Une URL correcte dans Graph ne suffit donc pas à rendre cette preuve verte.

## 7. Preuve 5 — progression et complétion

Avec le jeton **application worker**, appliquer successivement :

```http
PATCH https://graph.microsoft.com/v1.0/employeeExperience/learningProviders/<provider-id>/learningCourseActivities/<activity-id>
Content-Type: application/json

{
  "@odata.type": "#microsoft.graph.learningAssignment",
  "status": "inProgress",
  "completionPercentage": 40
}
```

Puis :

```http
PATCH https://graph.microsoft.com/v1.0/employeeExperience/learningProviders/<provider-id>/learningCourseActivities/<activity-id>
Content-Type: application/json

{
  "@odata.type": "#microsoft.graph.learningAssignment",
  "status": "completed",
  "completionPercentage": 100,
  "completedDateTime": "<UTC-ISO-8601>"
}
```

Critères :

- [ ] chaque mise à jour répond `204 No Content` ;
- [ ] la lecture déléguée `/me/...` reflète d'abord 40 %/`inProgress` ;
- [ ] elle reflète ensuite 100 %/`completed` avec l'horodatage UTC ;
- [ ] Viva Learning affiche le statut final attendu.

## 8. Nettoyage obligatoire

Conserver les IDs dans une note opérateur éphémère, puis nettoyer dans cet ordre :

1. worker application :
   `DELETE /employeeExperience/learningProviders/<provider-id>/learningCourseActivities/<activity-id>`
   → attendre `204` ;
2. worker application :
   `DELETE /employeeExperience/learningProviders/<provider-id>/learningContents/<learning-content-id>/$ref`
   → attendre `204` ;
3. administrateur délégué :
   `DELETE /employeeExperience/learningProviders/<provider-id>/$ref`
   → attendre `204` ;
4. vérifier que le provider et le contenu ont disparu ;
5. retirer les consentements, credentials sans secret et inscriptions POC.

## Verdict

| Niveau | Verdict actuel | Passage à GO |
|---|---|---|
| Contrats HTTP/JSON | **GO** | Tests et simulateur du spike verts |
| Tenant Viva | **NO-GO non testé** | Tenant non-prod licencié + opérateur Knowledge Administrator |
| Consentement assignations | **NO-GO documentaire** | Scope délégué exact confirmé et présent dans `scp` |
| Deep-link | **NO-GO** | App/Universal Links HTTPS installés et testés |
| Production | **NO-GO** | ADR ultérieur, revue sécurité, architecture d'identités et pilote live concluant |

## Références officielles

- [Créer un learningProvider](https://learn.microsoft.com/graph/api/employeeexperience-post-learningproviders?view=graph-rest-1.0)
- [Lister les learningProviders](https://learn.microsoft.com/graph/api/employeeexperience-list-learningproviders?view=graph-rest-1.0)
- [Publier un learningContent](https://learn.microsoft.com/graph/api/learningcontent-update?view=graph-rest-1.0)
- [Lister les learningContents](https://learn.microsoft.com/graph/api/learningprovider-list-learningcontents?view=graph-rest-1.0)
- [Créer une learningCourseActivity](https://learn.microsoft.com/graph/api/employeeexperienceuser-post-learningcourseactivities?view=graph-rest-1.0)
- [Lister les learningCourseActivities](https://learn.microsoft.com/graph/api/learningcourseactivity-list?view=graph-rest-1.0)
- [Mettre à jour une learningCourseActivity](https://learn.microsoft.com/graph/api/learningcourseactivity-update?view=graph-rest-1.0)
- [Supprimer une learningCourseActivity](https://learn.microsoft.com/graph/api/learningcourseactivity-delete?view=graph-rest-1.0)
- [Supprimer un learningContent](https://learn.microsoft.com/graph/api/learningprovider-delete-learningcontents?view=graph-rest-1.0)
- [Supprimer un learningProvider](https://learn.microsoft.com/graph/api/employeeexperience-delete-learningproviders?view=graph-rest-1.0)
- [Référence des permissions Microsoft Graph](https://learn.microsoft.com/graph/permissions-reference#employee-learning-permissions)
