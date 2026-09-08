# Matrice données, rétention, rôles et droits — B2B V1

> Cette matrice décrit des garde-fous produit et des durées techniques actuelles. Les colonnes
> « validation humaine » restent bloquantes et ne constituent pas une conclusion juridique.

| Donnée | Périmètre | Contenu autorisé | Visibilité | Rétention/TTL encodé | Export | Suppression/offboarding | Validation humaine |
|---|---|---|---|---|---|---|---|
| Lease de session | Organization + cycle pseudonyme | session opaque, séquence, watermark, hash token | service uniquement | 1 h | interdit | purge cycle-scoped | nécessité du signal |
| Bucket actif | Organization agrégée | borne basse de contributeurs | owner/admin/manager si cohorte ≥ 5 | fenêtre 5 min, TTL 10 min | agrégé seulement | non attribuable | finalité et destinataires |
| Receipt de rejeu | Organization + cycle pseudonyme | hash de requête, séquence, timestamp | service uniquement | 30 jours | interdit | purge directe par partitions | durée/idempotence |
| Intent outbox terminé | Organization + cycle pseudonyme | état technique et receipt encapsulé | worker uniquement | 1 h | interdit | purge cycle-scoped | audit opératoire |
| Intent pending/processing | Organization + cycle pseudonyme | état technique, lease worker | worker uniquement | durable jusqu'à résolution | interdit | drain/skip puis purge | délai incident |
| Agrégat journalier | Organization agrégée | durée, progression, complétions, readiness | owner/admin/manager si cohorte ≥ 5 | cutoff J+401 (400 jours révolus) | agrégé seulement | non attribuable | durée métier |
| Tombstone offboarding | Organization + cycle pseudonyme | clés de purge, état, timestamps | opérateur privacy/service | durable jusqu'à purge complète | interdit | supprimable après preuve de purge selon future politique | preuve et durée |
| Membership/équipe | Organization | rôle et rattachement | selon policy Organization | contrat Organization séparé | administratif selon futur contrat | révocation immédiate puis purge des arêtes | contrat client |
| Progression/certifications personnelles | Person | acquis et préférences personnels | Person ; jamais manager via B2B V1 | politique personnelle séparée | canal privacy/personnel seulement | préservées à l'offboarding ; Account Deletion séparé | droits applicables |
| Audit de conformité | opération, sans sujet stable | code événement, résultat, classe de rôle, bucket, corrélation éphémère | Security/Privacy autorisés | à définir avant pilote | preuve contrôlée, sans PII | politique d'audit à approuver | durée, accès, résidence |

## Matrice de rôles

| Action | Learner | Manager | Admin | Owner | Privacy/Security |
|---|:---:|:---:|:---:|:---:|:---:|
| Voir ses acquis personnels | Oui | Oui pour soi | Oui pour soi | Oui pour soi | Non par défaut |
| Voir un bucket B2B ≥ 5 | Non | Oui | Oui | Oui | Sur justification |
| Voir un bucket B2B < 5 | Non | Non | Non | Non | Non via reporting |
| Voir un individu via reporting B2B | Non | Non | Non | Non | Non |
| Export agrégé seuil respecté | Non | Futur contrat | Futur contrat | Futur contrat | Sur procédure |
| Export individuel/DSAR | Canal privacy authentifié séparé | Non | Non | Non | Procédure dédiée |
| Offboarder une Membership | Non | Non | Selon ADR-015 | Selon ADR-015 | Non |
| Lire l'audit de conformité | Non | Non | Non par défaut | Non par défaut | Accès explicite |

Tout nouveau rôle, drill-down, range arbitraire, export individuel ou jointure avec les acquis
personnels exige une nouvelle version du contrat et une revue juridique avant implémentation.
