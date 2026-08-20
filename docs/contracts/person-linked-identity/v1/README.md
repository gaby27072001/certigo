# Contrat Person / LinkedIdentity V1

**Version :** `1.0.0`

**Statut :** contrat V1, runtime de migration `off|shadow`

**ADR :** [ADR-014](../../../adr/ADR-014-person-linked-identity.md)

Ce répertoire reste la surface versionnée de la phase Person / LinkedIdentity :

- `openapi.json` décrit les endpoints, DTO, erreurs, preuves et feature mode ;
- `cosmos.schema.json` décrit les documents additifs et les contraintes de stockage ;
- les tests contractuels vivent dans
  `backend/tests/Certigo.Application.Tests/PersonLinkedIdentityContractTests.cs`.

Le contrat est réconcilié avec `main@034c1dd41e8ce7da0a84f8a6e70d821829a54e61`,
qui inclut #300. Le premier runtime accepte uniquement `off` (défaut) et `shadow`.
`shadow` ajoute l'overlay Person, le sujet local opaque et le miroir LinkedIdentity,
mais le `userId` legacy reste l'unique autorité. Les endpoints list/begin/complete/revoke
et toute UI de liaison restent contractuels et ne sont pas livrés.

## Règles de compatibilité

- `personId` est égal au `userId` legacy pour tout compte existant.
- Les API historiques peuvent continuer à nommer ce champ `userId`.
- Aucun changement de conteneur ou de clé de partition n’est requis par V1.
- Le backfill est additif : `personId == profile.id == legacy userId`.
- Une évolution additive compatible incrémente le minor.
- Une modification de locator, d’id déterministe, de preuve, de sémantique d’erreur ou de
  compatibilité `userId` exige une nouvelle version majeure.

## Baselines préservées

| Surface fusionnée | Contrat conservé |
|---|---|
| Suppression #296 | `GET`/`POST /account/deletion`, record idempotent par Person, `202` pending puis `200`, aucun `Idempotency-Key` client |
| Active track #297 | `POST /me/active-track`, owner dérivé du JWT, validation du track et CAS `expectedTrackId` |
| Onboarding/catalogue #289 | sélection parmi les tracks actifs avec contenu ; cache et complétion owner-scopés par l'id du profil Person |
| Cosmos | conteneurs et clés de partition inchangés ; policy `/*` avec `/"_etag"/?` exclu |

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

En mode `off`, la surface V1 est absente et retourne `404`. Le
`503 identity_linking_disabled` ne s'applique qu'aux mutations en modes `shadow` ou `resolve`.

Les réponses de lecture ne retournent jamais le subject interne, un e-mail complet ou une preuve.
