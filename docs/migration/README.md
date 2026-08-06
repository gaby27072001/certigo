# Registre de migration Certigo (`docs/migration/`)

> **Le repo est la source de vérité de la reprise.** Ce registre persiste l'avancement de la
> migration **hors mémoire**, versionné dans Git, pour survivre à un plantage, une coupure de
> courant ou un changement de machine. Toute session qui reprend le travail relit ce dossier.

## Rôle

La migration est découpée en **phases (0→5)**, elles-mêmes en **lots de travail (WP)** petits et
robustes. Convention : **1 lot = 1 session = 1 PR**, périmètre visé **XS–M**. Pour éviter les
sessions qui buggent, tournent dans le vide ou perdent leur progrès, l'état de chaque lot est
écrit dans le repo à chaque étape.

Principes que le dispositif incarne :
- **Précondition idempotente** en entrée (« est-ce déjà fait ? où reprendre ? »).
- **DoD machine-vérifiable** en sortie (parsing, tests, /health, etc.).
- **Checkpoint après chaque étape** (jamais uniquement en mémoire).
- **Timebox → `blocked`** au lieu de boucler indéfiniment.

## Structure des fichiers

| Fichier | Rôle |
|---|---|
| `work-packages.yaml` | **Manifeste** : source de vérité du séquencement (lots, dépendances, DoD, rollback, statut). |
| `state/<id>.json` | **Un fichier JSON par lot** (zéro conflit de merge) : statut courant + session + branche + PR + dernier checkpoint. |
| `state/_TEMPLATE.json` | Gabarit vierge pour un nouveau lot. |
| `log.jsonl` | **Journal append-only** : une transition de statut par ligne (JSON). Historique immuable. |
| `STATE.md` | **Vue humaine** : tableau lisible miroir du manifeste. |
| `templates/session-kickoff.md` | Gabarit de démarrage d'une session de lot. |
| `templates/work-package.md` | Gabarit pour définir un nouveau lot. |

`work-packages.yaml` + `STATE.md` décrivent le **plan** ; `state/` + `log.jsonl` décrivent l'**exécution**.

## Protocole de reprise (self-location) — 5 étapes

1. **Se localiser.** Lire `work-packages.yaml` + tous les `state/*.json` → calculer l'ensemble
   **prêt** : les lots `todo` dont **toutes les dépendances (`depends_on`) sont `done`**.
2. **Choisir + sonder.** Prendre un lot prêt ; exécuter sa **précondition idempotente** pour
   mesurer l'avancement réel (déjà fait ? partiellement ? reprendre où ?).
3. **Verrouiller + avancer.** Passer le lot `in_progress` (renseigner `session_id` + `branch` dans
   son `state/<id>.json`) ; dérouler les étapes ; **écrire un checkpoint après chaque étape**
   (`checkpoint.step`, `checkpoint.note`, `checkpoint.at`).
4. **Clôturer.** DoD **verte** → commit + PR → statut `in_review` (puis `done` au merge) →
   **append** une ligne dans `log.jsonl` → **stop**.
5. **Échouer proprement.** Échec ou dépassement de timebox → statut `blocked` + note explicative
   (dans `state/` et `log.jsonl`) → **stop propre** → escalade.

### Après un crash / une extinction

1. Relire le registre **commité** (`git pull` puis ce dossier).
2. Repérer les lots `in_progress` et leur **dernier checkpoint**.
3. **Rejouer la précondition idempotente** du lot pour mesurer l'avancement réel sur disque/infra
   (ne jamais se fier à la mémoire d'une session morte).
4. Selon le résultat : **reprendre** à l'étape suivante, ou **réinitialiser** le lot (`todo`) et
   relancer proprement. Consigner la décision dans `log.jsonl`.

## Conventions

- **Tailles** : XS · S · M · L · XL (voir bloc `conventions.sizes` du manifeste).
- **Statuts** : `todo` · `in_progress` · `blocked` · `in_review` · `done` · `rolled_back` ·
  `planned` (voir `conventions.statuses`).
- **Nommage de branche** : une branche dédiée par lot (idéalement `wp-<id>`). Le worktree local
  peut préfixer le nom ; on enregistre alors le **nom git réel** dans `state/<id>.json`.
- **Français** pour les contenus ; **clés YAML/JSON en anglais**.

## Validation machine (DoD du registre)

```bash
python -m pip install PyYAML
python tools/validate_migration_registry.py
```

Le validateur parse les quatre représentations, compare leurs statuts, vérifie les références
`state/`, les dépendances et l'absence de cycle. La gate
`.github/workflows/ci-migration-registry.yml` rejoue ce contrôle à chaque changement du registre.

## Suivi GitHub (optionnel)

Une **issue de suivi** « Migration Certigo — suivi des lots » peut lister les lots et leur statut.
Si l'outillage `gh` n'est pas disponible au moment du bootstrap, la créer **manuellement** en
reprenant le tableau de `STATE.md`. L'issue est un confort de visibilité ; **le manifeste reste la
source de vérité**.

## Lancer le prochain lot

Chaque lot suivant (Phase 0 : `wp-p0-01-jwt-key-vault`, …) démarre dans **sa propre session**, sur
**sa propre branche**, en partant de `templates/session-kickoff.md`. Ne jamais empiler plusieurs
lots dans une même session.
