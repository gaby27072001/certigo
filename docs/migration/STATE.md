# État de la migration Certigo — vue humaine

> Miroir lisible de `work-packages.yaml`. **Le manifeste reste la source de vérité** ; en cas
> d'écart, `work-packages.yaml` + `state/*.json` font foi. Statut détaillé (session, branche,
> checkpoint) dans `state/<id>.json`.

| Lot | Phase | Taille | Statut | Dépend de | PR |
|---|---|---|---|---|---|
| `wp-000-amorcage-registre` | 0 | S | in_review | — | [#196](https://github.com/gchambaud_microsoft/Certigo/pull/196) |
| `wp-p0-01-jwt-key-vault` | 0 | S | todo | `wp-000-amorcage-registre` | — |
| `wp-p0-02-etag-concurrency` | 0 | M | in_review | `wp-000-amorcage-registre` | — |
| `wp-p0-03-cosmos-pitr` | 0 | S | todo | `wp-000-amorcage-registre` | — |
| `wp-p0-04-ai-tutor-decision` | 0 | S | todo | `wp-000-amorcage-registre` | — |
| `wp-p0-05-ciam-governance` | 0 | M | todo | `wp-000-amorcage-registre` | — |
| `wp-p0-06-server-authoritative-integrity` | 0 | M | todo | `wp-000-amorcage-registre` | — |
| `wp-p0-07-github-branch-protection-release` | 0 | S | todo | `wp-000-amorcage-registre` | — |
| `wp-p0-08-e2e-auth-health-release` | 0 | M | todo | `wp-p0-01-jwt-key-vault`, `wp-p0-07-github-branch-protection-release` | — |
| `wp-phase-1-contenu-renderer` | 1 | L | planned | `wp-p0-08-e2e-auth-health-release` | — |
| `wp-phase-2-search-ai-tutor` | 2 | L | planned | `wp-phase-1-contenu-renderer` | — |
| `wp-phase-3-admin-ops` | 3 | L | planned | `wp-phase-2-search-ai-tutor` | — |
| `wp-phase-4-backend-modularisation` | 4 | XL | planned | `wp-phase-3-admin-ops` | — |
| `wp-phase-5-scale-mondial` | 5 | L | planned | `wp-phase-4-backend-modularisation` | — |

## Légende des statuts

- **todo** — pas encore commencé ; prêt si toutes les dépendances sont `done`.
- **in_progress** — en cours dans une session active (`session_id` + `branch` renseignés).
- **blocked** — bloqué (timeout, échec, dépendance externe) ; note dans `state/` + `log.jsonl`.
- **in_review** — travail terminé, PR ouverte, en attente de revue/merge.
- **done** — mergé et DoD verte.
- **rolled_back** — annulé via son rollback documenté.
- **planned** — placeholder de phase, à décomposer en lots XS–M au lancement de la phase.
