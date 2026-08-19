# Contrat Person / LinkedIdentity V1

**Version :** `1.0.0`

**Statut :** contract-only, runtime désactivé

**ADR :** [ADR-014](../../../adr/ADR-014-person-linked-identity.md)

Ce répertoire est la surface versionnée de la phase préparatoire :

- `openapi.json` décrit les endpoints, DTO, erreurs, preuves et feature mode ;
- `cosmos.schema.json` décrit les documents additifs et les contraintes de stockage ;
- les tests exécutables vivent dans
  `backend/tests/Certigo.Application.Tests/PersonLinkedIdentityContractTests.cs`.

## Règles de compatibilité

- `personId` est égal au `userId` legacy pour tout compte existant.
- Les API historiques peuvent continuer à nommer ce champ `userId`.
- Aucun changement de conteneur ou de clé de partition n’est requis par V1.
- Une évolution additive compatible incrémente le minor.
- Une modification de locator, d’id déterministe, de preuve, de sémantique d’erreur ou de
  compatibilité `userId` exige une nouvelle version majeure.

## Erreurs stables

| HTTP | Code | Sens |
|---|---|---|
| 404 | `intent_not_found` | intent inconnu, expiré ou non accessible à cette Person |
| 404 | `identity_not_found` | identité inconnue ou non accessible à cette Person |
| 401 | `invalid_reauthentication` | preuve source ou cible invalide/non récente |
| 401 | `confused_deputy` | preuve émise pour une autre audience ou un autre contexte |
| 409 | `identity_already_linked` | locator rattaché à une autre Person |
| 409 | `idempotency_conflict` | même clé avec un payload différent |
| 409 | `replay_detected` | intent/nonce déjà consommé autrement |
| 409 | `cross_tenant` | tenant de preuve différent du tenant piné |
| 409 | `same_identity` | source et cible désignent le même locator |
| 409 | `last_identity` | révocation du dernier accès utilisable |
| 423 | `account_deletion_in_progress` | mutation interdite par #296 |
| 500 | `identity_hash_collision` | collision cryptographique, arrêt fail-closed et intervention |
| 503 | `identity_linking_disabled` | mode inférieur à `link` |

Les réponses de lecture ne retournent jamais le subject interne, un e-mail complet ou une preuve.
