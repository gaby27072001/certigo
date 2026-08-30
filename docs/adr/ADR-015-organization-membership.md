# ADR-015 — Organization, Membership, Team et invitations

| Champ | Valeur |
|---|---|
| **ADR** | 015 |
| **Statut** | Accepté — contrat et runtime dormant |
| **Date** | 2026-08-20 |
| **Activation runtime** | `off` uniquement ; aucune activation dev/staging/prod |
| **Contrat** | `docs/contracts/organization-membership/v1` |
| **Baseline** | `origin/main@102025d1` (#329), avec Person/LinkedIdentity #300/#311 |

## Contexte

Certigo doit introduire un périmètre B2B sans transformer une identité d'entreprise en
propriétaire des acquis personnels. `Person` reste permanente et portable. La progression,
les tentatives, l'économie, les préférences et les certifications personnelles restent
owner-scopées par `personId`. L'e-mail reste un attribut mutable et ne prouve jamais que deux
Person sont identiques.

Les assignations, équipes, métriques et contenus privés d'une entreprise appartiennent au
périmètre de l'Organization. Leur futur runtime ne doit jamais écrire ces données dans les
conteneurs personnels.

## Décision

### Agrégat et rôles

Le domaine additif définit :

- `Organization`, racine B2B dont l'owner est un `personId` existant ;
- `OrganizationMembership`, lien explicite entre une Organization et une Person ;
- `OrganizationTeam` et `OrganizationTeamMembership`, toujours organization-scoped ;
- `OrganizationInvitation`, capacité opaque à usage unique.

Les rôles V1 sont `owner`, `admin`, `manager`, `learner`. Owner/admin peuvent inviter,
owner/admin/manager peuvent gérer les équipes. Un owner ne peut être ni invité ni offboardé.
Un admin ne peut retirer qu'un manager ou learner.

### Cosmos additif et transactions

Un nouveau conteneur `organizations` est ajouté sans modifier les conteneurs ni clés existants :

```text
container = organizations
partition key = /organizationId
default TTL = -1
indexing = consistent, include /*, exclude /"_etag"/?
```

Organization, Membership, Team, TeamMembership et Invitation partagent cette partition. La
création Organization+owner, l'acceptation Invitation→Membership et l'offboarding
Membership+TeamMembership utilisent des transactional batches mono-partition. Toute assignation
d'équipe remplace aussi la Membership sous ETag dans son batch : elle ne peut donc pas gagner une
course contre un offboarding et laisser une arête orpheline.

Les identifiants sont déterministes, versionnés et hachent leur domaine avec séparateurs NUL.
`Idempotency-Key` est obligatoire pour créer une Organization, une Team ou une Invitation. Un
rejeu avec un payload différent échoue ; le secret d'invitation n'est jamais récupérable.

Le conteneur active le TTL par item. Une invitation pending porte un `ttl` positif (sept jours par
défaut, trente jours maximum). L'acceptation vérifie aussi `expiresAt` : le nettoyage Cosmos ne
constitue pas la règle métier.

### Invitation et absence de fusion par e-mail

L'e-mail fourni pour acheminer une invitation est réduit à un hash de hint. Il ne participe ni à
la résolution Person, ni à l'autorisation, ni à la création de Membership. L'acceptation exige :

1. un bearer déjà validé, dont `IUserContext.UserId` est le `personId` ;
2. `organizationId`, `invitationId` et le token opaque ;
3. une Invitation pending non expirée ;
4. une comparaison constante du hash du token ;
5. un batch ETag qui consomme l'Invitation et crée la Membership une seule fois.

Un receipt d'idempotence non expirant est créé dans le même batch que la capacité. Le TTL peut
supprimer l'Invitation sans autoriser la réutilisation de sa clé. Un second appel, même identique,
retourne un conflit. Aucune Person n'est fusionnée.

L'issuer n'accorde pas un droit durable en créant le token. À l'acceptation, sa Membership doit
encore exister avec un rôle `owner|admin`; cette Membership est remplacée sous ETag dans le même
batch que la consommation de l'Invitation et la création de la Membership cible. Un issuer
offboardé ou rétrogradé ne peut donc pas réutiliser un token conservé.

### Offboarding

L'offboarding supprime atomiquement la Membership et ses TeamMembership dans la partition de
l'Organization. Il ne supprime ni la Person, ni LinkedIdentity, ni progression, tentatives,
économie, amis ou préférences. Les données et accès entreprise deviennent inaccessibles dès que
la Membership disparaît.

Le batch Cosmos est limité à 100 opérations. V1 refuse fail-closed un offboarding dépassant
99 team edges pour un départ volontaire, ou 98 team edges quand un acteur privilégié distinct
est aussi CAS dans le batch, plutôt que de laisser un état partiel. La phase shadow devra mesurer
ce seuil avant toute activation.

Toute mutation privilégiée CAS la Membership de l'acteur dans son batch mono-partition après
avoir revérifié son rôle côté repository. Une invitation, une équipe ou une assignation ne peut
donc pas être commise après l'offboarding ou la rétrogradation concurrente de l'acteur.

### Activation et autorité

`ORGANIZATION_MEMBERSHIP_V1` accepte uniquement `off`. Toute autre valeur fait échouer le
démarrage. En `off`, les routes V1 retournent 404 avant authentification ou accès repository.
Le legacy reste entièrement autoritaire. Aucun environnement n'est activé et aucune ressource
live n'est modifiée par cette décision.

## Conséquences et prochaine phase

La prochaine phase est un runtime `shadow` sans endpoint d'écriture utilisateur : observation
des memberships projetées, télémétrie sans PII, validation des RU, conflits d'idempotence,
volumétrie des équipes et seuil du batch d'offboarding. Une activation `read` ou `write` exigera
un ADR et des gates distincts.
