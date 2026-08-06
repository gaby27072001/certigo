# État de la migration Certigo — vue humaine

> Miroir lisible de `work-packages.yaml`. **Le manifeste reste la source de vérité** ; en cas
> d'écart, `work-packages.yaml` + `state/*.json` font foi. Statut détaillé (session, branche,
> checkpoint) dans `state/<id>.json`.

| Lot | Phase | Taille | Statut | Dépend de | PR |
|---|---|---|---|---|---|
| `wp-000-amorcage-registre` | 0 | S | done | — | [#196](https://github.com/gchambaud_microsoft/Certigo/pull/196) |
| `wp-p0-01-jwt-key-vault` | 0 | S | done | `wp-000-amorcage-registre` | [#198](https://github.com/gchambaud_microsoft/Certigo/pull/198) |
| `wp-p0-02-etag-concurrency` | 0 | M | done | `wp-000-amorcage-registre` | [#200](https://github.com/gchambaud_microsoft/Certigo/pull/200) |
| `wp-p0-03-cosmos-pitr` | 0 | S | done | `wp-000-amorcage-registre` | [#202](https://github.com/gchambaud_microsoft/Certigo/pull/202) |
| `wp-p0-04-ai-tutor-decision` | 0 | S | done | `wp-000-amorcage-registre` | [#204](https://github.com/gchambaud_microsoft/Certigo/pull/204) |
| `wp-p0-05-ciam-governance` | 0 | M | done | `wp-000-amorcage-registre` | [#205](https://github.com/gchambaud_microsoft/Certigo/pull/205) |
| `wp-p0-06-server-authoritative-integrity` | 0 | M | done | `wp-000-amorcage-registre` | [#206](https://github.com/gchambaud_microsoft/Certigo/pull/206) |
| `wp-p0-07-github-branch-protection-release` | 0 | S | done | `wp-000-amorcage-registre` | [#201](https://github.com/gchambaud_microsoft/Certigo/pull/201) |
| `wp-p0-08-e2e-auth-health-release` | 0 | M | done | `wp-p0-01-jwt-key-vault`, `wp-p0-07-github-branch-protection-release` | [#209](https://github.com/gchambaud_microsoft/Certigo/pull/209) |
| `wp-p1-00-decomposition` | 1 | S | done | `wp-p0-08-e2e-auth-health-release` | [#211](https://github.com/gchambaud_microsoft/Certigo/pull/211) |
| `wp-p1-01-renderer-registry-fallback` | 1 | M | done | `wp-p1-00-decomposition` | [#212](https://github.com/gchambaud_microsoft/Certigo/pull/212) |
| `wp-p1-02-content-schemas-v2` | 1 | M | done | `wp-p1-01-renderer-registry-fallback` | [#217](https://github.com/gchambaud_microsoft/Certigo/pull/217) |
| `wp-p1-03-renderer-golden-tests` | 1 | S | done | `wp-p1-01-renderer-registry-fallback`, `wp-p1-02-content-schemas-v2` | [#219](https://github.com/gchambaud_microsoft/Certigo/pull/219) |
| `wp-p1-04-certigo-content-repo` | 1 | S | done | `wp-p1-00-decomposition` | [certigo-content](https://github.com/gchambaud_microsoft/certigo-content) · [preuve opérationnelle #1](https://github.com/gchambaud_microsoft/certigo-content/pull/1) |
| `wp-p1-05-content-migration` | 1 | M | done | `wp-p1-04-certigo-content-repo`, `wp-p1-02-content-schemas-v2` | [certigo-content#2](https://github.com/gchambaud_microsoft/certigo-content/pull/2) + [#4](https://github.com/gchambaud_microsoft/certigo-content/pull/4) |
| `wp-p1-06-ci-content-pipeline` | 1 | M | done | `wp-p1-04-certigo-content-repo` | [certigo-content#1](https://github.com/gchambaud_microsoft/certigo-content/pull/1) |
| `wp-p1-07-content-manifest-immutable` | 1 | S | done | `wp-p1-06-ci-content-pipeline` | [certigo-content#3](https://github.com/gchambaud_microsoft/certigo-content/pull/3) |
| `wp-p1-08-offline-study-cache` | 1 | M | done | `wp-p1-07-content-manifest-immutable` | [#231](https://github.com/gchambaud_microsoft/Certigo/pull/231) |
| `wp-p1-09-cortex-parity-gate` | 1 | M | done | `wp-p1-00-decomposition` | [#216](https://github.com/gchambaud_microsoft/Certigo/pull/216) |
| `wp-p1-10-mobile-crash-reporting` | 1 | S | in_review | `wp-p1-00-decomposition` | [#213](https://github.com/gchambaud_microsoft/Certigo/pull/213) |
| `wp-p1-11-ci-spof-runners` | 1 | S | todo | `wp-p1-00-decomposition` | — |
| `wp-p1-12-iac-drift-import` | 1 | M | todo | `wp-p1-00-decomposition` | — |
| `wp-p1-13-staging-environment` | 1 | S | todo | `wp-p1-12-iac-drift-import` | [#232 (IaC partielle)](https://github.com/gchambaud_microsoft/Certigo/pull/232) |
| `wp-p1-14-opentelemetry-correlation` | 1 | M | done | `wp-p1-00-decomposition` | [#215](https://github.com/gchambaud_microsoft/Certigo/pull/215) |
| `wp-p1-15-gamification-integrity` | 1 | M | done | `wp-p0-02-etag-concurrency`, `wp-p0-06-server-authoritative-integrity` | [#214](https://github.com/gchambaud_microsoft/Certigo/pull/214) |
| `wp-p2-01` | 2 | S | in_review | `wp-p1-00-decomposition` | [#251](https://github.com/gchambaud_microsoft/Certigo/pull/251) |
| `wp-p2-02` | 2 | M | done | `wp-p1-00-decomposition` | [certigo-content#7](https://github.com/gchambaud_microsoft/certigo-content/pull/7) |
| `wp-p2-03` | 2 | M | done | `wp-p2-02` | [certigo-content#8](https://github.com/gchambaud_microsoft/certigo-content/pull/8) |
| `wp-p2-04` | 2 | M | in_progress | `wp-p2-03` | [#244](https://github.com/gchambaud_microsoft/Certigo/issues/244) |
| `wp-p2-05` | 2 | M | todo | `wp-p2-04` | [#243](https://github.com/gchambaud_microsoft/Certigo/issues/243) |
| `wp-p2-06` | 2 | M | todo | `wp-p2-05` | [#245](https://github.com/gchambaud_microsoft/Certigo/issues/245) |
| `wp-p2-07` | 2 | M | in_progress | `wp-p1-00-decomposition` | [#249](https://github.com/gchambaud_microsoft/Certigo/issues/249) · [PR #250](https://github.com/gchambaud_microsoft/Certigo/pull/250) |
| `wp-p2-08` | 2 | S | todo | `wp-p2-01` | [#247](https://github.com/gchambaud_microsoft/Certigo/issues/247) |
| `wp-p2-09` | 2 | M | in_progress | `wp-p1-00-decomposition` | [#248](https://github.com/gchambaud_microsoft/Certigo/issues/248) · [PR #252](https://github.com/gchambaud_microsoft/Certigo/pull/252) |
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
