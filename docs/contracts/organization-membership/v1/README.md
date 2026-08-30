# Contrat Organization / Membership V1

**Version :** `1.1.0`

**Statut :** contrat et implémentation dormante (`off` uniquement)

**ADR :** [ADR-015](../../../adr/ADR-015-organization-membership.md)

- `openapi.json` décrit la surface HTTP versionnée sous `/v1`.
- `cosmos.schema.json` décrit les documents additifs du conteneur `organizations`.
- les tests vivent dans les projets Domain, Application, Infrastructure et API backend.

## Invariants

- `Person` reste permanente, portable et propriétaire de ses acquis personnels.
- l'e-mail d'invitation n'est jamais une clé d'identité et ne déclenche aucune fusion ;
- Organization, Membership, Team, assignations, métriques et contenus privés sont
  organization-scoped ;
- invitation pending, non expirée, consommée une seule fois par ETag ;
- issuer encore actif et autorisé, CAS dans le batch d'acceptation ;
- acteur privilégié actif et rôle inchangé, CAS dans chaque batch d'écriture ;
- le bearer validé doit résoudre une `Person` existante ; aucun rôle, `organizationId` ou e-mail
  fourni par le client ne définit l'acteur ;
- chaque opération résout une Membership active côté serveur et compare exactement
  l'`organizationId` du contexte avec le body, la route et chaque ressource chargée ;
- feature-off, absence de Person/Membership et mismatch cross-tenant sont masqués en `404` ;
- offboarding supprime uniquement les accès et artefacts organisationnels ;
- `ORGANIZATION_MEMBERSHIP_V1=off` dans tous les environnements ; toute autre valeur est refusée.

## Matrice d'autorisation

| Opération | owner | admin | manager | learner |
|---|:---:|:---:|:---:|:---:|
| Voir l'Organization | oui | oui | oui | oui |
| Voir les Memberships | oui | oui | oui | non |
| Changer un rôle | oui | oui* | non | non |
| Créer/révoquer une invitation | oui | oui | non | non |
| Voir équipes/assignations | oui | oui | oui | oui |
| Gérer équipes/assignations | oui | oui | oui | non |
| Offboarder sa propre Membership | non | oui | oui | oui |
| Offboarder une autre Membership | non-owner | manager/learner | non | non |

\* Un admin ne peut attribuer que `manager` ou `learner`. Seul l'owner peut attribuer `admin`.
Le rôle `owner` n'est jamais attribuable et l'owner ne peut pas être offboardé. Les opérations
d'assignation sont réservées pour la future surface et n'exposent encore aucun endpoint.

## Compatibilité

Le conteneur `organizations` est additif. Aucun document existant, conteneur personnel, clé de
partition ou contrat legacy n'est migré. Une évolution additive incrémente la version mineure.
Toute modification des ids, rôles, règles d'autorisation, partitionnement ou anti-rejeu exige une
nouvelle version majeure.
