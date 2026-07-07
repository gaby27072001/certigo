# État de la migration Certigo — vue humaine

> Miroir lisible de `work-packages.yaml`. **Le manifeste reste la source de vérité** ; en cas
> d'écart, `work-packages.yaml` + `state/*.json` font foi. Statut détaillé (session, branche,
> checkpoint) dans `state/<id>.json`.

| Lot | Phase | Taille | Statut | Dépend de | PR |
|---|---|---|---|---|---|
| `wp-000-amorcage-registre` | 0 | S | in_review | — | [#196](https://github.com/gchambaud_microsoft/Certigo/pull/196) |
| `wp-p0-01-jwt-key-vault` | 0 | S | done | `wp-000-amorcage-registre` | [#198](https://github.com/gchambaud_microsoft/Certigo/pull/198) |
| `wp-p0-02-etag-concurrency` | 0 | M | done | `wp-000-amorcage-registre` | [#200](https://github.com/gchambaud_microsoft/Certigo/pull/200) |
| `wp-p0-03-cosmos-pitr` | 0 | S | done | `wp-000-amorcage-registre` | [#202](https://github.com/gchambaud_microsoft/Certigo/pull/202) |
| `wp-p0-04-ai-tutor-decision` | 0 | S | done | `wp-000-amorcage-registre` | [#204](https://github.com/gchambaud_microsoft/Certigo/pull/204) |
| `wp-p0-05-ciam-governance` | 0 | M | done | `wp-000-amorcage-registre` | [#205](https://github.com/gchambaud_microsoft/Certigo/pull/205) |
| `wp-p0-06-server-authoritative-integrity` | 0 | M | done | `wp-000-amorcage-registre` | [#206](https://github.com/gchambaud_microsoft/Certigo/pull/206) |
| `wp-p0-07-github-branch-protection-release` | 0 | S | done | `wp-000-amorcage-registre` | [#201](https://github.com/gchambaud_microsoft/Certigo/pull/201) |
| `wp-p0-08-e2e-auth-health-release` | 0 | M | done | `wp-p0-01-jwt-key-vault`, `wp-p0-07-github-branch-protection-release` | [#209](https://github.com/gchambaud_microsoft/Certigo/pull/209) |
| `wp-p1-00-decomposition` | 1 | S | in_review | `wp-p0-08-e2e-auth-health-release` | [#211](https://github.com/gchambaud_microsoft/Certigo/pull/211) |
| `wp-p1-01-renderer-registry-fallback` | 1 | M | in_review | `wp-p1-00-decomposition` | [#212](https://github.com/gchambaud_microsoft/Certigo/pull/212) |
| `wp-p1-02-content-schemas-v2` | 1 | M | todo | `wp-p1-01-renderer-registry-fallback` | — |
| `wp-p1-03-renderer-golden-tests` | 1 | S | todo | `wp-p1-01-renderer-registry-fallback`, `wp-p1-02-content-schemas-v2` | — |
| `wp-p1-04-certigo-content-repo` | 1 | S | todo | `wp-p1-00-decomposition` | — |
| `wp-p1-05-content-migration` | 1 | M | todo | `wp-p1-04-certigo-content-repo`, `wp-p1-02-content-schemas-v2` | — |
| `wp-p1-06-ci-content-pipeline` | 1 | M | todo | `wp-p1-04-certigo-content-repo` | — |
| `wp-p1-07-content-manifest-immutable` | 1 | S | todo | `wp-p1-06-ci-content-pipeline` | — |
| `wp-p1-08-offline-study-cache` | 1 | M | todo | `wp-p1-07-content-manifest-immutable` | — |
| `wp-p1-09-cortex-parity-gate` | 1 | M | todo | `wp-p1-00-decomposition` | — |
| `wp-p1-10-mobile-crash-reporting` | 1 | S | todo | `wp-p1-00-decomposition` | — |
| `wp-p1-11-ci-spof-runners` | 1 | S | todo | `wp-p1-00-decomposition` | — |
| `wp-p1-12-iac-drift-import` | 1 | M | todo | `wp-p1-00-decomposition` | — |
| `wp-p1-13-staging-environment` | 1 | S | todo | `wp-p1-12-iac-drift-import` | — |
| `wp-p1-14-opentelemetry-correlation` | 1 | M | todo | `wp-p1-00-decomposition` | — |
| `wp-p1-15-gamification-integrity` | 1 | M | todo | `wp-p0-02-etag-concurrency`, `wp-p0-06-server-authoritative-integrity` | — |
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
