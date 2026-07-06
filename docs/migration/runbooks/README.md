# Runbooks de migration — pointeur

> **Les runbooks canoniques vivent sous [`docs/runbooks/`](../../runbooks/).**

Certains prompts / lots référencent `docs/migration/runbooks/`. Ce chemin n'héberge
**aucun** runbook : l'autorité est le registre `docs/migration/work-packages.yaml`
(precondition des lots), qui pointe explicitement vers **`docs/runbooks/`**.

Ce fichier existe uniquement pour lever l'ambiguïté et éviter la duplication.

## Runbooks disponibles (`docs/runbooks/`)

| Finding | Runbook |
|--------|---------|
| R-04 | [`R-04_compte-break-glass-ciam.md`](../../runbooks/R-04_compte-break-glass-ciam.md) |
| R-05 | [`R-05_rotation-secret-idp-msa.md`](../../runbooks/R-05_rotation-secret-idp-msa.md) |
| R-06 | [`R-06_resource-lock-ciam-facturation.md`](../../runbooks/R-06_resource-lock-ciam-facturation.md) |
| O-05 | [`O-05_nettoyage-tenant-ciam.md`](../../runbooks/O-05_nettoyage-tenant-ciam.md) |
| O-01 | [`O-01_decision-tutor-ia-prod.md`](../../runbooks/O-01_decision-tutor-ia-prod.md) |
| O-02 | [`O-02_plan-test-charge-openai.md`](../../runbooks/O-02_plan-test-charge-openai.md) |

Voir aussi l'index [`docs/runbooks/README.md`](../../runbooks/README.md).
