# ADR-017 — Garde-fous de conformité B2B avant pilote

| Champ | Valeur |
|---|---|
| **ADR** | 017 |
| **Statut** | Accepté — préparation documentaire, aucune validation juridique |
| **Date** | 2026-08-21 |
| **Activation runtime** | `off` uniquement |
| **Contrat** | `docs/contracts/b2b-compliance/v1` |
| **Dépendances** | ADR-015 Organization/Membership, ADR-016 Enterprise Learning Metrics |

## Contexte et limite

Le futur périmètre B2B peut traiter des signaux relatifs à l'activité d'apprentissage de salariés.
Ces traitements peuvent relever de règles différentes selon le pays, le rôle de chaque partie, les
accords collectifs et le contexte du pilote. Cet ADR ne conclut ni à la licéité d'un traitement, ni à
la validité d'un consentement, ni au rôle de responsable ou sous-traitant.

Il sépare trois catégories :

- **décision produit** : invariant que Certigo choisit d'imposer ;
- **question juridique** : conclusion réservée à un conseil compétent et documentée par juridiction ;
- **exigence avant pilote** : preuve humaine ou technique bloquante avant toute activation.

Le contrat machine-readable
[`compliance.contract.json`](../contracts/b2b-compliance/v1/compliance.contract.json) est la source
canonique de cette séparation. Une réponse juridique absente n'est jamais transformée en valeur par
défaut favorable.

## Décisions produit

1. La fonctionnalité reste masquée et `ENTERPRISE_LEARNING_METRICS_V1` n'accepte que `off`.
2. Les finalités V1 sont limitées au pilotage agrégé de l'adoption, de la progression, des
   complétions et de la readiness. Évaluation individuelle, surveillance de présence, discipline,
   rémunération, classement individuel et inférence de performance professionnelle sont interdites.
3. Un manager ne voit que des buckets Organization agrégés. Aucun drill-down vers une Person, une
   Membership, une équipe sous le seuil ou un événement individuel n'est prévu.
4. Chaque bucket doit compter au moins cinq personnes distinctes. Les petits groupes sont supprimés,
   pas fusionnés à la volée ni révélés par différence entre plages.
5. Les acquis personnels restent sous `personId`. L'entreprise ne possède que Membership, équipes,
   assignations futures et agrégats B2B. L'offboarding ne supprime ni progression personnelle, ni
   certifications, ni préférences, ni économie.
6. Les exports B2B V1, s'ils sont conçus ultérieurement, restent agrégés et soumis au même seuil.
   Aucun export individuel manager ou employeur n'est autorisé par ce contrat.
7. L'audit de contrôle ne doit contenir ni nom, ni e-mail, ni `personId`, ni identifiant pseudonyme
   stable, ni réponse, ni concept étudié. Il utilise des codes d'événement, résultat, classe de rôle,
   bucket temporel et identifiant de corrélation éphémère.
8. La résidence des données n'est pas déduite de la région d'un environnement existant. Aucune
   région, aucun transfert et aucun sous-traitant n'est approuvé par cet ADR.

## Transparence, consentement et droits

L'interface devra présenter, avant collecte, une notice versionnée indiquant les finalités, métriques,
destinataires par rôle, seuil, durées, exports, offboarding, voies d'accès et contact. Un accusé de
présentation peut être conservé pour prouver l'affichage ; il ne vaut pas consentement ni base légale.

Le choix de la base légale, la nécessité et la forme d'un consentement, son éventuel retrait, les
obligations de consultation des représentants du personnel et le contenu réglementaire de la notice
sont des **questions juridiques ouvertes**. Les métriques restent `off` tant qu'elles ne sont pas
tranchées pour chaque juridiction pilote.

Une procédure humaine vérifiée doit permettre le droit d'accès et les autres droits applicables sans
ouvrir une vue manager individuelle. L'export d'un sujet, s'il est juridiquement requis, doit être
produit par un canal privacy dédié, authentifié et audité, séparé du reporting entreprise.

## Rétention et suppression

La matrice
[`data-retention-roles.md`](../contracts/b2b-compliance/v1/data-retention-roles.md) distingue TTL
technique et durée métier à approuver. Les valeurs actuellement encodées sont :

- lease : 1 heure ;
- fenêtre active : 10 minutes de TTL pour un bucket fixe de 5 minutes ;
- receipt de rejeu : 30 jours ;
- agrégat journalier : cutoff à J+401, soit 400 jours révolus ;
- intent terminé : 1 heure ; intent pending/processing durable jusqu'à résolution ;
- tombstone d'offboarding : durable jusqu'à purge complète.

L'offboarding révoque d'abord la Membership, empêche toute nouvelle écriture, puis purge les données
cycle-scoped de manière reprenable. Les acquis personnels sont conservés selon leur propre politique.
Une suppression de compte personnel suit le flux Account Deletion distinct.

## Exigences bloquantes avant pilote

- avis juridique daté par juridiction couvrant base légale, consentement, notice, droits, surveillance
  des salariés, consultation sociale, rôles contractuels, transferts et résidence ;
- finalités et destinataires signés par Product, Privacy, Security et client pilote ;
- DPIA/AIPD ou décision motivée sur sa nécessité, validée par la fonction compétente ;
- DPA/accord de traitement, registre de traitement et liste de sous-traitants approuvés ;
- régions de stockage, sauvegarde, logs et support inventoriées et testées ;
- procédures DSAR, export privacy, suppression, offboarding, incident et rétention testées sur données
  synthétiques ;
- tests anti-differencing, petits groupes, changements de rôle et export agrégé réussis ;
- observabilité sans PII revue par Privacy/Security ;
- ADR d'activation séparé ajoutant un mode autre que `off`, avec rollback et pilote borné.

## Conséquences

Le code dormant et les schémas Cosmos ne sont pas activés. Les tests de cohérence bloquent toute
dérive entre contrat, seuil Domain, TTL Cosmos et flags de configuration. Les réponses juridiques et
preuves humaines restent explicitement hors du dépôt tant qu'elles ne sont pas approuvées ; le
runbook conserve uniquement leur statut et leur référence non sensible.
