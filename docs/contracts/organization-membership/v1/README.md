# Contrat Organization / Membership V1

**Version :** `1.0.0`

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
- offboarding supprime uniquement les accès et artefacts organisationnels ;
- `ORGANIZATION_MEMBERSHIP_V1=off` dans tous les environnements ; toute autre valeur est refusée.

## Compatibilité

Le conteneur `organizations` est additif. Aucun document existant, conteneur personnel, clé de
partition ou contrat legacy n'est migré. Une évolution additive incrémente la version mineure.
Toute modification des ids, rôles, règles d'autorisation, partitionnement ou anti-rejeu exige une
nouvelle version majeure.
