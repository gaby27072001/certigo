# ADR-016 — Métriques d'apprentissage entreprise

| Champ | Valeur |
|---|---|
| **ADR** | 016 |
| **Statut** | Accepté — contrat et runtime dormant |
| **Date** | 2026-08-21 |
| **Activation runtime** | `off` uniquement |
| **Baseline** | tenant authorization `e9210f2` |

## Autorité et lease

Le bearer résout une Person puis une Membership active ; le rôle serveur est la seule autorité.
Une session n'est jamais choisie par le client : le serveur émet un `sessionId` et un token opaque,
et persiste un lease CAS unique pour `(Organization, Person, Membership cycle)`. Tant que ce lease
n'expire pas, un autre appareil ne peut pas ouvrir de session. La création du lease ne contribue
aucune métrique.

Le heartbeat contient uniquement token, `operationId`, séquence et timestamp. Temps, progression,
completion et readiness proviennent de `IEnterpriseLearningFactSource`, branché sur des événements
serveur autoritaires ; le runtime dormant utilise volontairement une source indisponible. La
séquence avance strictement de un, avec fenêtre de 15 minutes et watermark de faits. Un rejeu exact
est réparé depuis le watermark ; changer d'operation ou de session ne double pas les agrégats.

## Cosmos et exactly-once

Les leases, shards quotidiens, shards d'activité et tombstones restent dans `organizations`
(`/organizationId`) afin que Membership, lease et agrégats soient CAS dans un batch mono-partition.

Les receipts immuables sont déplacés vers un conteneur additif :

```text
container = enterpriseMetricReceipts
partition key = /partitionKey
partitionKey = organizationId|yyyyMMdd|000..127
default TTL = -1 ; item ttl = 30 jours
```

Le batch Organization commit l'exactly-once via `LastSequence`/`LastRequestHash` et crée un intent
outbox déterministe dans la même transaction. Un worker claim l'intent sous ETag avec lease de deux
minutes, vérifie l'absence de tombstone, matérialise le receipt puis termine l'intent. Un crash est
repris après expiration du processing lease. Le rejeu historique point-read l'intent avant le lease
courant et avant la source de faits : un hash exact est idempotent, un mismatch est refusé. Après
matérialisation, l'intent expire en une heure ; les rejeux plus anciens point-read directement le
receipt via `sessionId + sequence + occurredAt`; le shard est redérivé du pseudonyme de cohorte
serveur et n'est jamais accepté du client.

À 10 000 actifs, 96 heartbeats/jour, une partition reçoit en moyenne 7 500 receipts/jour. Même avec
1 KiB/document, le budget projeté est inférieur à 10 MiB/partition/jour, très loin de 20 GiB. Les
28,8 M receipts retenus représentent toujours environ 16–25 GiB logiques au total avant
index/réplication, mais ils ne partagent plus une partition Organization.

## Reporting sans differencing

Il n'existe aucun range arbitraire. L'API ne retourne qu'un bucket UTC journalier fixe ; les ranges
futurs devront sommer uniquement des buckets ayant chacun passé le seuil. Chaque jour est réparti
sur 128 shards et contient un bitmap anonyme de 2 048 bits. Sous cinq contributeurs dans ce jour,
le bucket entier est supprimé.

L'activité n'interroge jamais les leases bruts. Chaque heartbeat met à jour un des 128 bitmaps de la
fenêtre serveur fixe de cinq minutes. La lecture charge au plus 128 documents, fusionne les bitmaps,
applique le même seuil et n'expose qu'une borne basse.

Le bitmap utilise `metricCohortSubjectId`, pseudonyme stable par `(Organization, Person)` avec un
domaine cryptographique distinct. Le sujet de purge reste cycle-scoped. Cinq cycles d'une même
Person ne peuvent donc jamais satisfaire artificiellement le seuil de cinq contributeurs.

## Offboarding et rejoin

Une courte transaction CAS l'acteur, écrit un tombstone de cycle et supprime la Membership. Toute
écriture cesse immédiatement. La completion attend que les intents du sujet soient tous completed
ou skipped ; un worker en vol voit le tombstone et ne crée pas de receipt. Le tombstone contient les
30 clés de partition receipt directes (`jour × shard`) et la purge n'effectue aucun scan cross-partition.
La purge TeamMembership, lease et receipts est paginée et idempotente.
`IOrganizationOffboardingRecoveryWorker` énumère les tombstones incomplets et retente avec backoff ;
le DELETE peut aussi reprendre le tombstone même si la Membership cible n'existe plus.

Une invitation ne peut être acceptée tant que le dernier tombstone est incomplet. Après completion,
la nouvelle Membership reçoit `cycle+1`, donc un nouveau sujet et un nouveau tombstone id ; les
joins/offboardings suivants ne rencontrent aucun conflit avec les cycles antérieurs.

## Confidentialité, rétention et risques

Aucun document métrique ne contient `personId`, nom, e-mail, réponse, concept, certification ou
acquis portable. Le sujet pseudonyme est séparé par Organization et cycle. Le TTL agrégat est
calculé depuis le jour métrique (cutoff J+401), pas depuis l'arrivée offline.

Deux workers sont planifiés toutes les cinq minutes par TimerTrigger mais retournent immédiatement
en mode `off`. Le claim CAS rend les instances concurrentes sûres.

Risques avant activation : RU réels des quatre CAS Organization, coût des purges des 30 partitions
directes du conteneur receipts, taux de collisions des bitmaps, supervision opérationnelle des workers,
indexation Cosmos dédiée et source de faits autoritaire. `ENTERPRISE_LEARNING_METRICS_V1` n'accepte
que `off`; les routes retournent `404` avant auth/service. Toute activation exige un nouvel ADR.
