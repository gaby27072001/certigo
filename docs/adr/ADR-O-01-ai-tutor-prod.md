# ADR-O-01 — AI Tutor en production : repli déterministe (Phase 0)

| Champ | Valeur |
|---|---|
| **ADR** | O-01 |
| **Finding audit** | O-01 (🔴 Haut — décision requise) |
| **Statut** | ✅ **Accepté — Option B (repli déterministe `NullTutorCompletion`)** en Phase 0 |
| **Date de décision** | 2026-07-06 |
| **Lot de migration** | `wp-p0-04-ai-tutor-decision` (Phase 0) |
| **Décideurs** | Produit + Technique (+ DPO à consulter avant toute bascule Option A — données de mineurs) |
| **Supersède / complète** | Formalise la note de décision `docs/runbooks/O-01_decision-tutor-ia-prod.md` (statut passé de « Proposé » à « Décidé — Option B ») |

> **Type de document.** ADR (Architecture Decision Record). Il **acte officiellement** la décision AI Tutor
> prod exigée par le finding O-01 : la production fonctionne **sans LLM** (mode « grounded-only »), le
> Tutor IA génératif étant **différé en Phase 2**. La note `docs/runbooks/O-01_decision-tutor-ia-prod.md`
> reste la référence détaillée (options, arguments, checklist de bascule) ; cet ADR en est la décision
> ferme et datée.

---

## Contexte

Le Tutor IA de Certigo peut fonctionner selon deux modes, sélectionnés au démarrage par le flag
`TUTOR_LLM_ENABLED` :

- **Repli déterministe** (`NullTutorCompletion`) : réponses pédagogiques **statiques / grounded** déjà en
  place, aucun appel à un LLM.
- **LLM génératif** (`AzureOpenAiTutorCompletion`) : appel à Azure OpenAI / Foundry.

Constats d'audit (finding O-01) :

- **Prod** : `TUTOR_LLM_ENABLED=false`. **Aucune** ressource Azure OpenAI (`Microsoft.CognitiveServices`)
  n'est provisionnée en prod. Réseau prod verrouillé (`publicNetworkAccess=Disabled` sur Key Vault /
  Cosmos / Storage).
- **Dev** : ressource `certigo-openai` (1 déploiement `gpt-5.4-mini`, capacity=1 ~1000 TPM), **jamais
  load-testée** (cf O-02), **créée à la main hors IaC** (drift §G de l'audit).
- **Public cible** : application éducative → **données potentiellement de mineurs** (enjeu RGPD renforcé
  dès qu'un contenu élève est envoyé à un LLM).

État réel du code / IaC (contrôle d'idempotence de ce lot) — le repli déterministe est **déjà** le
comportement par défaut, sans dérive :

| Preuve | Emplacement | Effet |
|---|---|---|
| `var tutorLlmEnabled = string.Equals(configuration["TUTOR_LLM_ENABLED"], "true", …)` → sinon `NullTutorCompletion` | `backend/src/Certigo.Api/Program.cs` (~l.167-183) | Flag absent/≠"true" ⇒ repli déterministe |
| `param tutorLlmEnabled bool = false` | `infra/main.bicep` (l.31) | Défaut IaC = désactivé |
| `param tutorLlmEnabled bool = false` + app setting `TUTOR_LLM_ENABLED = string(tutorLlmEnabled)` | `infra/modules/functionApp.bicep` (l.39, ~l.150) | App setting prod = `'false'` |
| `module tutor 'modules/openai.bicep' = if (tutorLlmEnabled)` | `infra/main.bicep` (~l.220) | **Aucune** ressource OpenAI provisionnée en prod |
| `prod.bicepparam` n'override **pas** `tutorLlmEnabled` (+ commentaire explicite l.57-62) | `infra/params/prod.bicepparam` | Prod hérite du défaut `false`, documenté |

**Conclusion d'idempotence** : le flag prod est **cohérent** avec le repli déterministe. Il ne manque
que la **formalisation** de la décision (la note existante était en statut « Proposé »). Aucun changement
de code ni d'IaC n'est requis par ce lot.

---

## Options considérées

### Option A — Provisionner Azure OpenAI en prod et activer le Tutor IA

Amener la feature générative en production avec une infra OpenAI prod dédiée (IaC, private endpoint,
RBAC managed identity, capacity dimensionnée au load-test, DPIA). Détail complet : voir la note O-01
(§ Option A).

- **Bénéfice** : expérience pédagogique complète (tutorat génératif) en prod.
- **Coûts / risques** : coût OpenAI récurrent ; effort IaC + private endpoint + DPIA ; **prématuré** tant
  que O-02 (load-test) n'est pas fait ; surface d'attaque et exposition de données (mineurs) élargies.

### Option B — Acter le mode « grounded-only » en prod (repli déterministe)

Décider que la prod fonctionne **sans LLM** : uniquement contenu pédagogique statique / grounded (déjà en
place via `NullTutorCompletion`). Le Tutor IA génératif reste une capacité **dev / future (Phase 2)**.

- **Bénéfice** : surface RGPD minimale (aucune donnée élève envoyée à un LLM) ; zéro coût OpenAI prod ;
  aucune ressource supplémentaire à sécuriser ; **réversible**.
- **Coût** : la valeur « tutorat génératif » n'est pas offerte aux utilisateurs prod à ce stade.

---

## Décision

> **Option B — Repli déterministe (`NullTutorCompletion`) en Phase 0.** La production reste en mode
> « grounded-only » : `TUTOR_LLM_ENABLED=false`. Le Tutor IA génératif (Option A) est **différé en
> Phase 2**, où la brique AI Search + grounding + évaluations + garde-fous seront mises en place
> (`wp-phase-2-search-ai-tutor`).

**Justification** (reprend les arguments de la note O-01) :

1. **Load-test absent (O-02)** — activer une capacity=1 non testée exposerait à des 429 sous charge.
2. **Données de mineurs** — un envoi de contenu élève à un LLM impose DPIA + minimisation, non encore en
   place.
3. **Cohérence de sécurité** — la prod est verrouillée réseau ; une OpenAI prod exigerait un private
   endpoint (surcoût non justifié au stade pilote).
4. **Dette IaC** — l'OpenAI dev est hors IaC (drift §G) ; reproduire ce schéma en prod aggraverait la
   dette. Option A ne doit démarrer qu'**après** remise en IaC.
5. **Réversibilité** — Option B ne ferme aucune porte ; c'est le choix par défaut le moins coûteux et le
   plus sûr, révisable dès que les conditions d'Option A sont réunies.

---

## Conséquences

- `TUTOR_LLM_ENABLED=false` en prod devient un **choix documenté et acté**, plus un oubli.
- **Aucune** donnée élève n'est envoyée à un LLM en prod → surface RGPD minimale.
- **Zéro coût** Azure OpenAI en prod ; aucune ressource générative supplémentaire à sécuriser.
- L'implémentation `AzureOpenAiTutorCompletion` reste en place (chemin optionnel), prête à être activée
  en Phase 2 par simple bascule du flag une fois les conditions ci-dessous remplies.
- **Aucun changement de code/IaC dans ce lot** : le défaut prod est déjà cohérent (cf tableau de preuves).

---

## Conditions de bascule vers l'Option A (Phase 2 — `wp-phase-2-search-ai-tutor`)

À remplir **avant** d'activer le Tutor IA en prod (`TUTOR_LLM_ENABLED=true`) :

- [ ] Load-test O-02 réalisé ; capacity / quota cible déterminés (pas capacity=1).
- [ ] Ressource Azure OpenAI décrite en **IaC** (dev **et** prod ; corrige le drift §G).
- [ ] **Private endpoint** + `publicNetworkAccess=Disabled` validés en prod (cohérence réseau).
- [ ] RBAC `Cognitive Services OpenAI User` attribué à l'identité prod (`61d948e4`) — managed identity,
      pas de clé (cohérent avec `disableLocalAuth=true`).
- [ ] **DPIA / cadre RGPD données mineurs** validé (minimisation, pas de données identifiantes élève).
- [ ] AI Search + grounding + jeu d'**évaluations** (qualité/safety) + garde-fous en place.
- [ ] Alertes coût + 429 (throttling) configurées.

La bascule effective se fait alors en mettant `tutorLlmEnabled = true` (+ endpoint / deployment) dans
`infra/params/prod.bicepparam`, redéploiement, sans modification de code applicatif (le binding DI est
déjà conditionné par le flag).

---

## Rollback

Le repli déterministe **est** le rollback naturel : si l'Option A est un jour activée puis pose problème
(coût, 429, incident sécurité/RGPD), il suffit de **remettre `TUTOR_LLM_ENABLED=false`** (ou
`tutorLlmEnabled = false` dans les params Bicep) et de redéployer. Le backend rebascule immédiatement sur
`NullTutorCompletion`, sans perte de données ni migration.

---

## Références

- Note de décision détaillée : [`docs/runbooks/O-01_decision-tutor-ia-prod.md`](../runbooks/O-01_decision-tutor-ia-prod.md)
- Code : `backend/src/Certigo.Api/Program.cs` (garde du flag), `backend/src/Certigo.Infrastructure/Ai/NullTutorCompletion.cs`, `backend/src/Certigo.Infrastructure/Ai/AzureOpenAiTutorCompletion.cs`
- IaC : `infra/main.bicep`, `infra/modules/functionApp.bicep`, `infra/modules/openai.bicep`, `infra/params/prod.bicepparam`, `infra/params/dev.bicepparam`
- Registre de migration : `docs/migration/work-packages.yaml` (`wp-p0-04-ai-tutor-decision`), Phase 2 `wp-phase-2-search-ai-tutor`
- Findings liés : O-02 (load-test Tutor), drift §G (OpenAI dev hors IaC)
