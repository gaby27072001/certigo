# Runbook — Gate de conformité B2B avant pilote

## Portée

Ce runbook prépare une décision humaine. Il ne demande aucune opération Azure/M365 et ne constitue
pas un avis juridique. Tant que la gate n'est pas intégralement approuvée,
`ENTERPRISE_LEARNING_METRICS_V1=off` reste obligatoire.

## Rôles humains requis

| Rôle | Responsabilité |
|---|---|
| Product owner | finalités, métriques, destinataires, UX de transparence |
| Conseil juridique compétent | analyse par juridiction et contexte d'emploi |
| Privacy/DPO | registre, DPIA/AIPD, droits, notice, rétention |
| Security | accès, audit sans PII, incident, support |
| Engineering/Data | preuves techniques, TTL, suppression, anti-differencing |
| Client pilote autorisé | contexte social, destinataires, contrat et communications |

Une même personne peut cumuler des rôles uniquement si la gouvernance applicable l'autorise. Chaque
approbation conserve date, version d'artefact et référence non sensible.

## Gate 0 — Gel technique

- [ ] valeur absente ou `off` dans tous les environnements ;
- [ ] démarrage fail-closed pour toute autre valeur ;
- [ ] routes masquées en 404 avant authentification ;
- [ ] aucun export, dashboard manager ou ingestion pilote activé ;
- [ ] rollback documenté : restaurer `off`, interrompre workers, conserver les preuves d'incident.

Échec d'un item : arrêter la préparation du pilote.

## Gate 1 — Qualification juridique et sociale

- [ ] juridictions, populations (salarié, prestataire, candidat) et entités contractantes inventoriées ;
- [ ] rôles responsable/sous-traitant et finalités déterminés par traitement ;
- [ ] base légale documentée sans présumer que le consentement est libre dans l'emploi ;
- [ ] besoin de consentement/retrait et conséquences du refus tranchés ;
- [ ] obligations de consultation/information des représentants du personnel tranchées ;
- [ ] DPIA/AIPD approuvée, ou décision motivée de non-nécessité approuvée ;
- [ ] DPA, registre, sous-traitants et transferts approuvés ;
- [ ] délais et voies d'exercice des droits approuvés.

Preuve attendue : identifiant/version/date d'un avis validé. Ne pas committer de conseil confidentiel.

## Gate 2 — Transparence et finalités

- [ ] notice versionnée avant collecte : finalités, catégories, sources, destinataires, seuil,
  rétention, droits, contact, exports, offboarding et régions/transferts ;
- [ ] accusé de présentation séparé de tout mécanisme de consentement ;
- [ ] refus/retrait éventuel défini par le conseil, sans dark pattern ;
- [ ] finalités interdites du contrat reprises dans le DPA et la documentation client ;
- [ ] aucune réutilisation incompatible ou jointure RH implicite.

## Gate 3 — Accès, cohorte et exports

Sur données synthétiques exclusivement :

1. vérifier learner, manager, admin, owner et changements de rôle concurrents ;
2. vérifier 0 à 4 personnes : bucket entièrement supprimé ;
3. vérifier 5 personnes distinctes : agrégat sans identifiant ;
4. tenter des soustractions entre jours/équipes : aucune reconstruction individuelle ;
5. vérifier qu'aucun range arbitraire ou drill-down n'existe ;
6. vérifier tout export B2B : agrégé, thresholdé, journalisé sans PII ;
7. vérifier la voie DSAR séparée et l'authentification forte de l'opérateur privacy.

Échec d'un cas : bloquer le pilote et ouvrir un finding Security/Privacy.

## Gate 4 — Cycle de vie

- [ ] TTL réconciliés avec la matrice et les besoins approuvés ;
- [ ] offboarding révoque avant purge et stoppe les écritures concurrentes ;
- [ ] intents en vol drainés ou marqués skipped avant suppression ;
- [ ] purge reprise après interruption et preuve de completion obtenue ;
- [ ] réadhésion bloquée avant completion puis isolée par nouveau cycle ;
- [ ] Account Deletion personnel testé séparément ;
- [ ] export d'accès, rectification, opposition/limitation et suppression traités selon l'avis humain ;
- [ ] sauvegardes, PITR, logs et caches inclus dans la politique de cycle de vie.

## Gate 5 — Résidence et audit

- [ ] régions de données primaires, réplication, sauvegardes, logs, CI/support et reprise inventoriées ;
- [ ] accès support et sous-traitants cartographiés ;
- [ ] transferts et mécanismes contractuels approuvés ;
- [ ] tests de résidence exécutés dans l'environnement pilote réel par un opérateur autorisé ;
- [ ] audit inspecté : aucun nom, e-mail, `personId`, pseudonyme stable, réponse ou contenu étudié ;
- [ ] accès audit least-privilege, alertes et durée approuvés.

La présence d'une ressource dans une région ne prouve pas à elle seule la résidence de bout en bout.

## Gate 6 — Décision Go/No-Go

Le Go exige toutes les cases précédentes, les références des preuves, un périmètre pilote borné, une
date de fin, un owner de rollback et un nouvel ADR introduisant explicitement le mode activable.

| Décision | Condition | Action |
|---|---|---|
| No-Go | preuve absente, périmée ou ambiguë | conserver `off`, assigner owner/date |
| Go conditionnel | uniquement conditions écrites et datées, toutes bloquantes avant activation | conserver `off` jusqu'à clôture |
| Go | signatures complètes + tests réussis + ADR activation fusionné | changement séparé, revu et réversible |

## Registre minimal de décision

| Champ | Valeur |
|---|---|
| Juridictions/populations | À renseigner |
| Avis juridique (référence/version/date) | BLOQUANT |
| DPIA/AIPD (référence/version/date) | BLOQUANT |
| Notice employé (référence/version/date) | BLOQUANT |
| DPA/registre/sous-traitants | BLOQUANT |
| Résidence/transferts vérifiés | BLOQUANT |
| Rapport tests synthétiques | BLOQUANT |
| Approbations Product/Legal/Privacy/Security/client | BLOQUANT |
| ADR activation | BLOQUANT |
| Décision actuelle | **NO-GO — feature off** |
