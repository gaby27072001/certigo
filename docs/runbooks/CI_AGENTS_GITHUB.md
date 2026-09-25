# Agents GitHub « revue Copilot » et « AI findings » : désactivés, et pourquoi

> **Fait daté.** Désactivés le **2026-09-24** (accord de l'orchestrateur, par délégation de
> Gabriel). **Invalidé si** les runners hébergés par GitHub redeviennent disponibles pour ce dépôt,
> ou si un pool de runners **ARC** (Actions Runner Controller) Ubuntu x64 est mis en place.

## Ce qui échouait

Deux workflows *dynamiques*, gérés par GitHub (aucun fichier dans `.github/workflows/`), échouaient
sur **toutes** les PR. Aucun des deux n'est un contexte requis.

| Workflow | Chemin | Échecs mesurés | Réussites |
|---|---|---|---|
| « Running Copilot Code Review » | `dynamic/agents/copilot-pull-request-reviewer` | 267 sur 267, depuis le 2026-06-22 | **aucune** |
| « Code scanning AI findings on PR #… » | `dynamic/agents/github-advanced-security` | 80 sur 80, depuis le 2026-09-19 | **aucune** |

En plus de la croix rouge, la revue Copilot publiait sur chaque PR un commentaire sans contenu :
*« The job failed because GitHub Actions hosted runners are disabled for this repository. »*

## Pourquoi

Les deux agents demandent un runner hébergé par GitHub (`ubuntu-latest`). Annotation GitHub, mot
pour mot (par exemple job `107588172834`, run `35985839336`) :

> *GitHub Actions hosted runners are disabled for this repository. For more information please
> contact your GitHub Enterprise Administrator.*

C'est un réglage de l'entreprise, hors de portée du dépôt. Les runners Certigo sont tous
auto-hébergés (`certigo-pr`, `certigo-trusted`, …) et aucun ne porte `ubuntu-latest`.

**Les faire tourner sur nos runners n'est pas une option sûre** :

- pour la revue Copilot, GitHub n'accepte l'auto-hébergement qu'avec ARC : *« ARC is the only
  officially supported solution for self-hosting Copilot code review. For security reasons, do not
  use non-ARC self-hosted runners. »*
  ([Configuring runners for GitHub Copilot code review](https://docs.github.com/en/copilot/how-tos/copilot-on-github/set-up-copilot/configure-runners)).
  Nos runners sont des VMSS persistants, pas ARC ;
- pour « AI findings » (AI scan de GitHub Advanced Security), aucune option de runner n'est
  documentée.

## Ce qui a été désactivé, avec l'état avant

### 1. La règle `copilot_code_review` du ruleset 19768864

Le ruleset porte aussi deux protections **conservées** : `deletion` et `non_fast_forward`.

État **avant** (`gh api repos/gchambaud_microsoft/Certigo/rulesets/19768864`, champs utiles) :

```json
{
  "id": 19768864,
  "name": "Copilot review for default branch",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "exclude": [], "include": ["~DEFAULT_BRANCH"] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "copilot_code_review",
      "parameters": { "review_on_push": false, "review_draft_pull_requests": true }
    }
  ]
}
```

État **après**, vérifié : `gh api repos/gchambaud_microsoft/Certigo/rulesets/19768864 --jq '[.rules[].type]'`
→ `["deletion","non_fast_forward"]`.

### 2. L'AI scan des PR

Avant : `gh api repos/gchambaud_microsoft/Certigo/code-scanning/ai-scan` → `{"pr_scan":"enabled"}`.
Après, vérifié : `{"pr_scan":"disabled"}`.

### Ce qui n'a pas bougé (vérifié le même jour)

- Les 7 contextes requis de `main`, `strict: true`, `enforce_admins: true`, pas de push forcé ni de
  suppression.
- CodeQL : le workflow `codeql.yml` et son contexte requis `CodeQL / Security gate` sont inchangés ;
  la configuration par défaut de code scanning reste `not-configured` (Certigo utilise la
  configuration avancée, c'est-à-dire le workflow).

Aucune couverture n'est perdue : ni l'un ni l'autre de ces agents n'a jamais réussi à s'exécuter.

## Réactiver

Seulement si l'une des conditions d'invalidation ci-dessus est remplie (sinon les croix rouges
reviennent).

```bash
# Revue Copilot : remettre la règle, avec les paramètres d'origine.
gh api repos/gchambaud_microsoft/Certigo/rulesets/19768864 > ruleset-now.json   # garder une trace
cat > ruleset-restore.json <<'JSON'
{
  "name": "Copilot review for default branch",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "exclude": [], "include": ["~DEFAULT_BRANCH"] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "copilot_code_review",
      "parameters": { "review_on_push": false, "review_draft_pull_requests": true }
    }
  ]
}
JSON
gh api -X PUT repos/gchambaud_microsoft/Certigo/rulesets/19768864 --input ruleset-restore.json
gh api repos/gchambaud_microsoft/Certigo/rulesets/19768864 --jq '[.rules[].type]'
# attendu : ["deletion","non_fast_forward","copilot_code_review"]

# AI scan des PR.
gh api -X PATCH repos/gchambaud_microsoft/Certigo/code-scanning/ai-scan -f pr_scan=enabled
gh api repos/gchambaud_microsoft/Certigo/code-scanning/ai-scan   # attendu : {"pr_scan":"enabled"}
```

Avec ARC, il faudra en plus un workflow `.github/workflows/copilot-code-review.yml` dont le job
`copilot-setup-steps` porte `runs-on` vers le scale set ARC. C'est un **nouveau** workflow : il
passe par la pré-approbation (`CI_WORKFLOW_CHANGES.md`), et le validateur n'accepte aujourd'hui
que les labels de runner Certigo.
