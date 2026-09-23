# Contrat Learner Streak V1

**Version :** `1.0.0`

**Statut :** surface livrée, consommée par l'application mobile (écran « Ma série »).

Ce répertoire décrit les deux routes de la série :

- `openapi.json` décrit les opérations, les corps et les invariants ;
- les `*.golden.json` sont les octets exacts que l'API émet, lus par les deux langages ;
- la garde de surface vit dans `backend/tests/Certigo.Api.Tests/ApiSurfaceContractTests.cs`.

## Pourquoi un contrat maintenant

Ces routes étaient inscrites dans `docs/contracts/deferred-routes.json` tant qu'aucun client
ne les appelait. L'application mobile en dépend désormais, et une seconde application native
est en préparation : une forme non écrite y divergerait sans qu'aucun signal ne rougisse.

## Ce qu'un client ne recalcule jamais

Le serveur fait autorité sur la série, le solde et la fenêtre. `GET /streak` publie donc, dans
un seul instantané, tout ce qu'un écran doit dire :

| Champ | Ce qu'il évite de re-dériver sur l'appareil |
|---|---|
| `repairable`, `reason` | la règle d'éligibilité (`StreakRepairPolicy`) |
| `repairCostGems` | le prix |
| `gems` | un second appel pour le solde, lu à un autre instant |
| `repairExpiresAt` | `MaxGapDays` et la frontière de jour **UTC** du serveur |
| `coveredByFreeze` | la règle du gel (`StreakService.UpdateStreak`) |

`repairExpiresAt` est un **instant UTC exclusif**, pas une date : une date « jusqu'au 12 »
serait fausse de plusieurs heures pour un apprenant hors UTC.

`gems`, `repairExpiresAt` et `coveredByFreeze` sont **additifs** : un serveur antérieur les
omet, et le client traite alors l'information comme inconnue au lieu de l'inventer.

## Le piège que ce contrat documente

`POST /streak/repair` rend son **refus métier** sous le statut `400`, avec le même corps que son
succès (`success: false`, `error` renseigné). Le middleware rend lui aussi `400` pour une
requête mal formée, mais avec un `ProblemDetails`. Un client qui traiterait tout `400` comme
une erreur de transport afficherait « échec » là où le serveur a donné la cause exacte ; il
distingue les deux corps par la présence d'un booléen `success`.

## Invariants gardés

| Invariant | Où il est vérifié |
|---|---|
| Les deux opérations existent dans le backend et ne sont plus différées | `ApiSurfaceContractTests` |
| L'API émet exactement les octets des vecteurs | `StreakContractGoldenVectorTests` |
| Le client mobile comprend exactement ces octets | `packages/data/test/streak_contract_golden_test.dart` |
| La fenêtre publiée est celle que la règle applique, des deux côtés de sa borne | `StreakRepairPolicyTests` |
| `coveredByFreeze` prédit exactement la consommation d'un gel | `StreakFreezeCoverageTests` |
| Le rejeu d'une même `clientRepairId` ne débite qu'une fois | `StreakRepairServiceTests.RepairAsync_bridges_gap_charges_gems_and_is_idempotent` |
