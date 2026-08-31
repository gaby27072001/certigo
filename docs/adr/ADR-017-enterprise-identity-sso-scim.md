# ADR-017 — Identité entreprise, fédération SSO et provisioning SCIM

| Champ | Valeur |
|---|---|
| **ADR** | 017 |
| **Statut** | Accepté — contrat uniquement, runtime dormant |
| **Date** | 2026-08-31 |
| **Activation runtime** | `off` uniquement ; aucune activation dev/staging/prod |
| **Contrat** | `docs/contracts/enterprise-identity/v1` |
| **Baseline** | `main@6e78c051f` ; réutilise ADR-014, ADR-015 et leurs contrats V1 |

## Contexte

Les entreprises doivent pouvoir prouver leurs domaines, configurer une fédération OIDC ou SAML et
provisionner des utilisateurs et groupes par SCIM 2.0. Ce périmètre ne doit pas créer un second
modèle de tenant ou d'identité : `Organization` reste la racine tenant, `OrganizationMembership`
porte les droits, `Person` reste permanente, et `LinkedIdentity` reste le seul lien entre une
Person et un sujet externe.

Un e-mail, un `userName`, un `externalId` SCIM ou un nom affiché sont des attributs de répertoire
mutables. Aucun ne prouve une identité et aucun ne peut déclencher une création, une fusion ou une
réaffectation de Person.

## Décision

### Réutilisation des agrégats existants

Le contrat est additif. Il référence les contrats
`person-linked-identity/v1` et `organization-membership/v1` sans redéfinir `Person`,
`LinkedIdentity`, `Organization` ou `OrganizationMembership`.

Un sujet externe n'est lié à une Person que dans l'un des deux cas suivants :

1. une authentification fédérée OIDC/SAML a été validée intégralement pour la configuration active
   de l'Organization, puis son sujet normalisé est lié à la Person authentifiée ;
2. un owner/admin effectue une liaison explicite vers un `personId` existant, avec une nouvelle
   preuve d'administration et un sujet externe explicite.

Dans les deux cas, le résultat canonique est un `LinkedIdentity`; le document enterprise ne
conserve qu'un hash de sujet et le `linkedIdentityId`. Une valeur SCIM ou un e-mail ne peut jamais
être utilisé comme preuve de liaison. L'activation nécessitera une version compatible du locator
`LinkedIdentity` abstrait ; ADR-014 V1 n'est pas modifié par cette décision.

### Domaines vérifiés et prévention de takeover

La création d'un domaine normalise le nom, calcule un hash et réserve ce hash par création
conditionnelle dans un registre global minimal `enterpriseDomainClaims`. Ce registre ne contient
ni domaine en clair ni `organizationId`; il contient uniquement le hash du domaine, un hash de
liaison Organization et l'état de réservation. Une réservation pending non expirée ou une
possession verified interdit toute revendication concurrente.

La preuve DNS suit le cycle explicite :

```text
pending -> verified
pending -> failed | expired | revoked
verified -> revoked
```

La valeur de challenge est retournée une seule fois et seul son hash est persisté. La vérification
relit le DNS côté serveur, compare le challenge en temps constant et commit l'état sous ETag. Une
expiration, révocation ou suppression libère la claim de façon CAS ; elle ne transfère jamais
implicitement un domaine à une autre Organization. Une nouvelle Organization doit recommencer un
challenge complet.

### Fédération abstraite

Une Organization possède au plus une configuration active, versionnée, de protocole `oidc` ou
`saml`. Le contrat accepte uniquement des métadonnées abstraites : URI de discovery/metadata,
issuer/entity ID, audience/client ID et règles de claims. Il ne nomme aucun fournisseur et ne
contient ni secret client, clé privée, certificat privé, assertion, code, token ou cookie.

La configuration n'est activable que si au moins un domaine de l'Organization est verified. Toute
modification crée une nouvelle génération et invalide les cérémonies commencées avec l'ancienne.
Les assertions et tokens fédérés sont vérifiés puis détruits ; ils ne sont jamais persistés ni
copiés dans l'audit.

### Provisioning SCIM 2.0

Les routes `/v1/organizations/{organizationId}/scim/v2/Users` et `Groups`, ainsi que leurs routes
item, exposent les opérations SCIM GET/POST/PUT/PATCH/DELETE avec `application/scim+json`.
Les objets SCIM sont des projections de répertoire strictement organization-scoped.

Créer un User SCIM ne crée pas de Person et ne recherche aucune Person par e-mail. Tant qu'aucune
liaison prouvée n'existe, l'utilisateur reste staged. Une liaison validée peut créer ou réactiver
une Membership selon la policy serveur. Les Groups se projettent sur Team/TeamMembership uniquement
pour les Users liés à une Membership active ; les arêtes staged restent confinées au répertoire.

`DELETE User` ou `active=false` réalise un soft deprovision : accès fédéré et Membership sont
révoqués avant le nettoyage paginé des arêtes d'entreprise. La Person, ses autres LinkedIdentity et
ses apprentissages personnels (progression, tentatives, économie, amis, préférences et
certifications) sont préservés. Une réactivation exige une nouvelle preuve ou liaison explicite et
ne réutilise pas une preuve révoquée.

### Tokens SCIM

Un token SCIM est généré avec une forte entropie et retourné une seule fois. Cosmos ne persiste que
`tokenHash`, la génération, l'état et les bornes de validité ; aucune récupération plaintext
n'existe. La rotation incrémente la génération et autorise au plus la génération précédente pendant
une fenêtre d'overlap bornée, puis la révoque. La comparaison est constante et le token résout
d'abord son Organization ; l'`organizationId` de route doit correspondre exactement.

### Isolation, anti-rejeu et audit

Toutes les données tenant, receipts et audits résident dans `organizations` partitionné par
`/organizationId`. Une opération charge la Membership active de l'acteur ou résout le token SCIM,
puis compare exactement le tenant de route, de credential et de chaque document. Feature off,
Organization inconnue, Membership absente, token d'un autre tenant et mismatch cross-tenant
retournent tous `404` sans révéler lequel s'applique. Une Membership active mais insuffisante reçoit
`403`.

Chaque mutation utilise une clé d'idempotence et écrit un receipt durable avec son request hash.
Un rejeu exact reproduit l'issue sans répéter les effets ; la même clé avec un autre payload retourne
`409`. Les challenges, callbacks, PATCH SCIM, rotations et offboardings ont aussi un identifiant de
rejeu et un commit CAS/transactionnel dans leur partition.

Les événements d'audit n'acceptent, hors enveloppe technique de partitionnement et horodatage, que
des hashes pseudonymes et des enums. E-mail, `userName`, display name, domaine en clair, token,
secret, assertion fournisseur, code d'autorisation et contenu de claim sont interdits.

### Activation et ressources live

`ENTERPRISE_IDENTITY_V1` accepte uniquement `off`. Toute autre valeur fait échouer le démarrage.
En mode `off`, toutes les routes de ce contrat retournent `404` avant authentification, résolution
de token, lecture du body, parsing SCIM, accès DNS ou repository.

Cette décision n'ajoute aucune ressource Azure/Entra, aucun fournisseur réel, aucun secret, aucune
configuration live et aucun déploiement. Les conteneurs décrits sont des contrats de topologie
future, non provisionnés.

## Conséquences et prochaine phase

Une future activation exigera un nouvel ADR, une extension compatible de `LinkedIdentity`, une
threat model review, des tests de takeover/replay/cross-tenant, une stratégie de clés de hash, une
validation SCIM d'interopérabilité et des gates séparés pour `shadow`, lecture puis écriture.
