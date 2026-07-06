# Kickoff de session — Lot `wp-<id>`

> Gabarit de démarrage standard d'une session de lot. **1 lot = 1 session = 1 PR**, périmètre
> visé **XS–M**. Copier ce fichier mentalement au début de chaque lot ; ne jamais empiler
> plusieurs lots dans une même session.

## Identité du lot

- **id** : `wp-<id>` (doit exister dans `work-packages.yaml`)
- **phase** : `<0–5>`
- **branche dédiée** : `wp-<id>` (enregistrer le **nom git réel** si le worktree le préfixe)
- **session_id** : `<renseigner>`

## Règles anti-crash (non négociables)

1. **Précondition idempotente** — avant tout, exécuter la précondition du lot pour savoir si
   c'est *déjà fait* et *où reprendre*. Ne jamais présumer un état neuf.
2. **DoD machine-vérifiable** — la sortie se prouve (parsing, tests, /health, drift IaC…), pas
   « ça a l'air bon ».
3. **Checkpoint après chaque étape** — écrire `checkpoint.{step,note,at}` dans
   `state/wp-<id>.json` à chaque étape ; jamais uniquement en mémoire.
4. **Timebox → `blocked`** — si blocage ou dépassement du budget temps, passer `blocked` + note et
   s'arrêter proprement. Ne pas boucler.
5. **Branche dédiée + 1 PR** — tout le travail du lot sur sa branche, une seule PR.
6. **Additif / rollback prêt** — connaître le rollback du lot avant de commencer.

## Protocole de reprise (self-location) — 5 étapes

1. **Se localiser** : lire `work-packages.yaml` + `state/*.json` → calculer l'ensemble **prêt**
   (lots `todo` dont toutes les `depends_on` sont `done`).
2. **Choisir + sonder** : prendre un lot prêt ; exécuter sa **précondition idempotente** (déjà
   fait ? reprendre où ?).
3. **Verrouiller + avancer** : passer `in_progress` (`session_id` + `branch`) ; dérouler les
   étapes ; **checkpoint** à chacune.
4. **Clôturer** : DoD verte → commit + PR → `in_review` (puis `done`) → append `log.jsonl` → stop.
5. **Échouer proprement** : échec/timeout → `blocked` + note → stop propre → escalade.

## Étapes de la session

- [ ] `git fetch` + créer/checkout la branche dédiée.
- [ ] Exécuter la **précondition** ; noter le résultat (déjà fait ? partiel ? point de reprise).
- [ ] Passer le lot `in_progress` dans `state/wp-<id>.json` (+ ligne `log.jsonl`).
- [ ] Dérouler les étapes du lot, **checkpoint après chacune**.
- [ ] Vérifier la **DoD** (commandes machine).
- [ ] Commit (trailer `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`) + push.
- [ ] Ouvrir la **PR** ; renseigner `pr` dans `state/wp-<id>.json` + `STATE.md`.
- [ ] Passer `in_review` (+ ligne `log.jsonl`) ; **stop**. Ne pas merger sans revue.

## En cas de reprise après crash

- `git pull` → relire le registre commité.
- Repérer le lot `in_progress` + son dernier checkpoint.
- **Rejouer la précondition idempotente** pour mesurer l'avancement réel.
- Reprendre à l'étape suivante **ou** réinitialiser (`todo`) proprement ; consigner dans `log.jsonl`.
