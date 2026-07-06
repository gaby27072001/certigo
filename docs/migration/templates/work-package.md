# Gabarit de lot (WP)

> Copier ce gabarit pour définir un nouveau lot, puis reporter les champs de schéma dans
> `work-packages.yaml` (source de vérité) et créer `state/<id>.json` à partir de
> `state/_TEMPLATE.json`. Périmètre visé **XS–M** ; re-découper si trop gros.

## Champs de schéma (à reporter dans `work-packages.yaml`)

- **id** : `wp-<phase>-<nn>-<slug>` (identifiant stable, en anglais, kebab-case).
- **phase** : `0`–`5`.
- **title** : titre lisible (peut citer la référence de finding, ex. « F-01 — … »).
- **size** : `XS` | `S` | `M` | `L` | `XL`.
- **effort_pweeks** : estimation en semaines-personne (XS≈0.25, S≈0.5, M≈1, L≈2–3, XL≈4–6).
- **depends_on** : liste d'`id` prérequis (`done` avant de démarrer). `[]` si aucun.
- **precondition** : sonde **idempotente** — comment savoir si c'est *déjà fait* et *où reprendre*.
- **dod** : Definition of Done **machine-vérifiable** (parsing, tests, /health, drift IaC…).
- **rollback** : comment annuler proprement (réversibilité, revert, désactivation de flag…).
- **status** : `todo` | `in_progress` | `blocked` | `in_review` | `done` | `rolled_back` | `planned`.
- **notes** *(optionnel)* : re-découpage possible, dépendances externes, précisions.

## Exemple (YAML)

```yaml
- id: wp-p0-XX-slug
  phase: 0
  title: "Réf — description courte du lot"
  size: S
  effort_pweeks: 0.5
  depends_on: [wp-000-amorcage-registre]
  precondition: "Comment détecter l'état actuel de façon idempotente (déjà fait ? partiel ?)."
  dod: "Critère(s) prouvable(s) par une commande / un test."
  rollback: "Action de retour arrière réversible et sûre."
  status: todo
```

## Étapes détaillées (à remplir au lancement du lot)

1. _(étape 1 — action concrète + checkpoint attendu)_
2. _(étape 2 — …)_
3. _(étape 3 — …)_
4. _(vérification DoD — commande(s) machine)_
5. _(commit + PR + passage `in_review`)_

> Rappel : **checkpoint après chaque étape** dans `state/<id>.json`, **timebox → `blocked`** si
> blocage, une seule **branche dédiée** et une seule **PR** par lot.
