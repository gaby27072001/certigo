# Contrat Enterprise Learning Metrics V1

**Version :** `1.3.0`

**Statut :** contrat et implémentation dormante (`off` uniquement)

**ADR :** [ADR-016](../../../adr/ADR-016-enterprise-learning-metrics.md)

- `openapi.json` décrit les routes compilées mais non activables ;
- `cosmos.schema.json` décrit les documents additifs de `organizations` ;
- les tests Domain/Application/Infrastructure/API couvrent minimisation, replay concurrent,
  cross-tenant, rôles, offboarding, TTL et feature-off.

## Invariants

- contexte Organization et Membership active résolus côté serveur ;
- rôle lu uniquement depuis la Membership persistée ;
- lease opaque émis serveur, unique et actif par sujet/cycle ; sa création ne contribue rien ;
- heartbeat sans delta client : faits dérivés d'une source serveur autoritaire séparée ;
- séquence strictement monotone et temps déclaré borné par la fenêtre écoulée ;
- receipts immuables dans `enterpriseMetricReceipts`, PK Organization+jour+128 shards ;
- outbox transactionnel, processing lease CAS reprenable et skip si tombstone ;
- lecture réservée à owner/admin/manager ;
- `personId`, PII et acquis personnels absents des documents métriques ;
- sujet pseudonyme non corrélable entre Organizations ;
- buckets quotidiens fixes, sans range arbitraire, seuil de cinq contributeurs par bucket ;
- activité préagrégée en 128 bitmaps par fenêtre fixe de cinq minutes ;
- cohorte privacy stable par Organization+Person, distincte du sujet de purge par cycle ;
- lease et shards CAS dans `organizations`; receipt réparé après commit via watermark ;
- offboarding révoque d'abord, worker/retry API reprend la purge depuis tombstone ;
- tombstone attend l'outbox drainé et purge au plus 30 partitions receipt directes ;
- `ENTERPRISE_LEARNING_METRICS_V1=off` est la seule valeur valide.
