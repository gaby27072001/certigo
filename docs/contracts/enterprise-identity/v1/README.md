# Contrat Enterprise Identity V1

**Version :** `1.0.0`

**Statut :** contrat uniquement, feature dormante (`off` uniquement)

**ADR :** [ADR-017](../../../adr/ADR-017-enterprise-identity-sso-scim.md)

**Baseline :** `main@6e78c051f`

- `openapi.json` décrit les surfaces administratives, la fédération abstraite et SCIM 2.0 ;
- `cosmos.schema.json` décrit une topologie future additive, non provisionnée ;
- un runtime de domaine et des guards HTTP dormants sont livrés ; aucune infrastructure, ressource
  Azure/Entra, intégration fournisseur ou configuration live n'est livrée.

## Contrats réutilisés

| Agrégat | Contrat autoritatif |
|---|---|
| Person, LinkedIdentity | `../../person-linked-identity/v1` |
| Organization, Membership, Team | `../../organization-membership/v1` |

Ce dossier ne redéfinit pas ces agrégats. Une implémentation ne peut être activée qu'après une
évolution compatible du locator `LinkedIdentity` pour les sujets fédérés abstraits.

## Invariants

- `ENTERPRISE_IDENTITY_V1=off` est la seule valeur acceptée ;
- toute route retourne `404` avant auth, résolution de token, lecture/parsing du body, DNS ou accès
  repository ;
- un domaine verified n'appartient qu'à une Organization ; une réservation pending non expirée
  bloque toute takeover ;
- challenge : `pending -> verified|failed|expired|revoked`, puis révocation explicite possible ;
- la configuration est abstraite `oidc|saml`, sans fournisseur réel, secret ou assertion persistée ;
- un e-mail, `userName`, display name ou `externalId` SCIM ne résout, ne crée et ne fusionne jamais
  une Person ;
- un sujet externe devient un LinkedIdentity seulement après fédération authentifiée ou liaison
  owner/admin explicite ;
- Users/Groups SCIM restent organization-scoped et ne traversent jamais une partition tenant ;
- chaque mutation est idempotente, anti-rejeu et protégée par receipt durable + request hash ;
- un token SCIM n'est persisté que sous forme de hash ; plaintext retourné une fois, aucune
  récupération, rotation générationnelle avec overlap borné ;
- le deprovisioning est soft : accès entreprise révoqué, Person et acquis personnels préservés ;
- l'audit ne contient que hashes pseudonymes, enums et enveloppe technique ; aucune PII, token,
  secret ou assertion fournisseur ;
- Organization inconnue, feature-off et mismatch cross-tenant ont la même réponse `404`.

## Surfaces

| Surface | Routes contractuelles | Auth future |
|---|---|---|
| Metadata | `GET /v1/enterprise-identity/metadata` | aucune, mais feature-off d'abord |
| Domaines | `/v1/organizations/{organizationId}/enterprise-identity/domains...` | bearer Person + Membership owner/admin |
| Fédération | `/v1/organizations/{organizationId}/enterprise-identity/federation...` | bearer Person + Membership owner/admin |
| Tokens SCIM | `/v1/organizations/{organizationId}/enterprise-identity/scim-tokens...` | bearer Person + Membership owner/admin |
| SCIM Users | `/v1/organizations/{organizationId}/scim/v2/Users[/{userId}]` | bearer SCIM hashé, tenant-piné |
| SCIM Groups | `/v1/organizations/{organizationId}/scim/v2/Groups[/{groupId}]` | bearer SCIM hashé, tenant-piné |

Les mutations exigent `Idempotency-Key`. Un rejeu exact reproduit le résultat ; une même clé avec
un request hash différent retourne `409`. Les réponses SCIM utilisent
`application/scim+json` et les erreurs RFC 7644 sans détail cross-tenant.

## Domaines

Le domaine normalisé n'est stocké en clair que dans sa partition Organization. Le registre global
de takeover contient `domainHash` et `organizationBindingHash`, jamais le domaine ni
`organizationId`. La valeur DNS de challenge est retournée une fois ; seul son hash est stocké.
Expiration/révocation libère la claim par CAS, sans transfert automatique.

## Identité et SCIM

Un User SCIM commence en état `staged`. `emails`, `userName`, `displayName` et `externalId` sont des
attributs de répertoire, pas des preuves. Une fédération authentifiée ou une liaison explicite
owner/admin peut produire un LinkedIdentity et associer le User à une Membership existante ou
nouvelle selon policy. Groups projette Team/TeamMembership seulement pour les Users liés et actifs.

`DELETE User` et `active=false` révoquent d'abord Membership et binding. Les nettoyages
organization-owned sont paginés et reprenables ; Person, autres LinkedIdentity et apprentissages
personnels ne sont jamais supprimés.

## Compatibilité et activation

Le contrat est additif et non activable. Une modification des règles de preuve, du partitionnement,
des états de challenge, de la normalisation de sujet, de la sémantique cross-tenant, des receipts ou
de la fenêtre de rotation exige une nouvelle version majeure. Toute activation requiert un nouvel
ADR et ne peut provisionner implicitement aucune ressource Azure/Entra.
