# Contrat de garde-fous B2B V1

**Version :** `1.0.0`

**Statut :** préparation avant pilote, fonctionnalité strictement `off`

**ADR :** [ADR-017](../../../adr/ADR-017-b2b-compliance-guardrails.md)

Ce dossier ne constitue pas un avis juridique. Il encode des décisions produit prudentes, les
questions qui exigent une validation juridique humaine et les preuves bloquantes avant pilote.

## Artefacts

- [`compliance.contract.json`](./compliance.contract.json) : contrat canonique vérifié par tests ;
- [`data-retention-roles.md`](./data-retention-roles.md) : matrice lisible données, rétention,
  visibilité, export et suppression ;
- [runbook pilote](../../../runbooks/B2B_COMPLIANCE_PILOT.md) : gate opératoire et preuves humaines.

## Invariants

- aucun mode runtime autre que `off` ;
- aucune finalité d'évaluation individuelle ou disciplinaire ;
- aucune visibilité manager individuelle ;
- cohorte minimale de cinq personnes distinctes par bucket fixe ;
- aucun export B2B individuel ;
- acquis personnels séparés des données Organization ;
- offboarding révocable immédiatement et purge reprenable ;
- audit de contrôle sans PII ni pseudonyme stable ;
- résidence, transferts, base légale et consentement non présumés ;
- activation interdite tant que toutes les exigences `pilotRequirements` ne sont pas approuvées.
