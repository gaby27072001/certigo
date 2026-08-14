# CI_RUNNERS — Runbook opérationnel de la CI self-hosted (runners GitHub Actions sur VMs Azure)

| Champ | Valeur |
|---|---|
| **Type** | Runbook opérationnel (CI / infra / coûts) |
| **Objectif** | Exploiter la CI de Certigo sur ses **runners self-hosted** : **rallumer** les VMs avant une session de travail, les **déallouer** après (économie), **vérifier** l'état des runners et **dépanner** un runner hors ligne. |
| **Voie officielle** | **Self-hosted** — 2 VMs Azure. Les runners **GitHub-hosted sont BLOQUÉS au niveau Enterprise (EMU)** : cf. §1 (verdict + preuve). |
| **Périmètre** | Repo `gchambaud_microsoft/Certigo` · RG `RG-CERTIGO-CI` · subscription `b8952c8c-8f72-469d-99cd-ac906da4e2fc` (**Non-Prod**). |
| **Statut** | **En vigueur** (voie pérenne de la CI Certigo). |

> **Pourquoi ce runbook ?** La CI de Certigo tourne **exclusivement** sur des runners *self-hosted*
> hébergés par 2 VMs Azure. Ces VMs **facturent du compute tant qu'elles sont allouées** : on les
> **rallume** juste avant d'avoir besoin de la CI et on les **déalloue** dès qu'on a fini, pour ne payer
> que l'usage réel. Ce runbook regroupe les commandes exactes pour ce cycle **allumage → usage →
> extinction**, plus le **dépannage** d'un runner offline.

> ⚠️ **Principe « l'agent PRÉPARE, VOUS EXÉCUTEZ »** — aucune commande `gh` / `az` n'est lancée par
> l'agent. Les commandes ci-dessous sont **à exécuter par vous** après vérification des identifiants
> (repo, noms de VM, resource group, subscription).

---

## 1. Contexte & verdict — pourquoi self-hosted (et pas GitHub-hosted)

La CI de Certigo s'appuie **uniquement** sur des runners **self-hosted** (labels
`self-hosted, Linux, X64, certigo-ci`), portés par **2 VMs Azure**. Ce n'est pas une préférence : c'est
une **contrainte dure**, désormais **prouvée empiriquement**.

**Test empirique (verdict sans appel).** Une tentative de bascule vers un runner
hébergé par GitHub a été testée en conditions réelles :

- **Échec immédiat** : `startup_failure` en **~4 secondes**.
- **Annotation officielle GitHub** :
  > *GitHub Actions hosted runners are disabled for this repository. For more information please contact
  > your GitHub Enterprise Administrator.*
- **Preuve** : run **`28782170300`** →
  <https://github.com/gchambaud_microsoft/Certigo/actions/runs/28782170300>.

**Cause** : les runners GitHub-hosted sont **désactivés au niveau Enterprise (politique EMU —
Enterprise Managed Users)**, pas seulement au niveau repo/org. Les réactiver relève d'un **admin GitHub
Enterprise**, **hors de portée de l'équipe Certigo** et jugé **irréaliste** à ce jour.

> ✅ **Conclusion opérationnelle** : **self-hosted est la voie officielle et pérenne** de la CI Certigo.
> Le reste de ce runbook décrit son exploitation au quotidien. Aucun chemin alternatif
> hébergé par GitHub n'est supporté.

---

## 2. Inventaire de l'infrastructure CI

| Élément | Valeur |
|---|---|
| **Runner #1** | `vm-certigo-runner` |
| **Runner #2** | `vm-certigo-runner-2` |
| **Resource group** | `RG-CERTIGO-CI` |
| **Subscription** | `b8952c8c-8f72-469d-99cd-ac906da4e2fc` (**Non-Prod**) |
| **Labels runner** | `self-hosted`, `Linux`, `X64`, `certigo-ci` |
| **Repo desservi** | `gchambaud_microsoft/Certigo` |

> 📌 Ces 2 VMs portent le pool **Linux `certigo-ci`** (CI des PR + backend + android). Un éventuel
> runner **macOS** dédié à iOS (cf. §8) est **distinct** et **n'est pas** géré par ce runbook.

> ℹ️ **Prérequis outillage** (poste opérateur) : `az` (Azure CLI) connecté à la subscription Non-Prod,
> et `gh` (GitHub CLI) authentifié sur `gchambaud_microsoft/Certigo`.

---

## 3. Rallumer la CI (avant une session de travail)

À faire **avant** d'ouvrir/relancer des PR ou de déclencher un build : les 2 VMs doivent être démarrées.

```bash
az login
az account set --subscription b8952c8c-8f72-469d-99cd-ac906da4e2fc

# Démarrer les 2 runners (--no-wait : rend la main immédiatement, démarrage en tâche de fond)
az vm start --resource-group RG-CERTIGO-CI --name vm-certigo-runner   --no-wait
az vm start --resource-group RG-CERTIGO-CI --name vm-certigo-runner-2 --no-wait
```

> ℹ️ **Le service runner redémarre tout seul au boot.** L'agent GitHub Actions est installé en service
> (systemd) et démarre automatiquement au boot de la VM — comptez **~1 minute** après le démarrage pour
> que le runner repasse **online**. Aucune action manuelle sur la VM n'est nécessaire en temps normal.

**Vérifier que les runners sont bien en ligne côté GitHub :**

```bash
gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | {name, status, busy}'
# Attendu : status = "online" pour les 2 runners
```

Attendre `status: online` **avant** d'approuver un run de PR (sinon les jobs restent `Pending`).

---

## 4. Éteindre la CI (après usage — pour le coût)

Dès que la CI n'est plus nécessaire, **déallouer** les 2 VMs pour couper la facturation compute.

```bash
az vm deallocate --resource-group RG-CERTIGO-CI --name vm-certigo-runner   --no-wait
az vm deallocate --resource-group RG-CERTIGO-CI --name vm-certigo-runner-2 --no-wait
```

> ⚠️ **`deallocate` ≠ `stop` — c'est le point crucial.**
> - **`az vm deallocate`** : **libère** le compute (CPU/RAM). Vous **ne payez plus que le disque**
>   attaché. **➜ à utiliser systématiquement.**
> - **`az vm stop`** (ou un `shutdown` depuis l'OS) : éteint l'OS mais **laisse la VM allouée** →
>   **le compute reste facturé**. ❌ **à éviter.**

**Vérifier que les VMs sont bien déallouées** (cf. §5) avant de considérer la CI éteinte.

---

## 5. Vérifier l'état (VMs + runners)

**État des VMs (Azure) :**

```bash
az vm list -g RG-CERTIGO-CI --show-details \
  --query "[].{Nom:name, Etat:powerState}" -o table
# Après extinction  -> Etat = "VM deallocated"
# Après allumage    -> Etat = "VM running"
```

**État des runners (GitHub) :**

```bash
gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | {name, status, busy}'
# status : "online" / "offline"   |   busy : true (job en cours) / false (libre)
```

> 📌 `busy: true` = un job tourne : **ne déallouez pas** tant qu'un run est en cours, sous peine de le
> faire échouer.

---

## 6. Dépannage — un runner reste `offline`

Si, après un `az vm start` et ~1–2 minutes d'attente, un runner reste `offline` côté GitHub :

1. **Confirmer l'état Azure de la VM** (§5). Si elle n'est pas `VM running`, la (re)démarrer :
   ```bash
   az vm restart --resource-group RG-CERTIGO-CI --name <vm-concernée>
   ```
2. **Vérifier le service de l'agent sur la VM** (connexion SSH / Bastion selon l'accès en vigueur). Le
   runner tourne en service systemd nommé `actions.runner.*` :
   ```bash
   systemctl list-units 'actions.runner.*'
   sudo systemctl status  'actions.runner.*'
   sudo systemctl restart 'actions.runner.*'   # relance l'agent si le service est tombé
   ```
3. **Consulter les logs de l'agent** sur la VM (répertoire `_diag/` de l'installation du runner) pour
   identifier un échec de connexion.
4. **En dernier recours — reconfigurer le runner** (token expiré, runner supprimé côté GitHub, etc.) en
   suivant la procédure **officielle GitHub** pour les self-hosted runners :
   <https://docs.github.com/actions/hosting-your-own-runners/managing-self-hosted-runners>.

> 🔐 **Aucun secret en clair.** Ne copiez **jamais** de token d'enregistrement (`--token …`), de PAT ou
> de secret dans ce runbook, un ticket, un chat ou un commit. Les tokens d'enregistrement de runner sont
> **éphémères** et se régénèrent depuis **Settings → Actions → Runners** du repo au moment du besoin.

---

## 7. Coût & bonnes pratiques

- **Ne jamais laisser les VMs allumées H24.** Une VM `running` — ou seulement `stopped` (non
  déallouée) — facture le compute **même à vide**. C'est le principal poste d'économie.
- **`deallocate` systématique** après chaque session de CI (cf. §4). Réflexe : *j'allume → j'utilise →
  je déalloue*.
- **Vérifier `busy: false`** avant de déallouer (§5) pour ne pas tuer un run en cours.
- **Grouper les runs.** Plutôt que d'allumer/éteindre pour une micro-PR, regrouper les besoins CI d'une
  même session réduit les cycles de démarrage.
- **Subscription Non-Prod** : ces VMs vivent dans la sub `b8952c8c-8f72-469d-99cd-ac906da4e2fc`
  (Non-Prod) — vérifier le contexte via `az account show` avant toute commande.

---

## 8. Ce qui reste **obligatoirement** self-hosted

Tous les workflows **exigent** une capacité self-hosted adaptée :

| Workflow | Raison |
|---|---|
| [`cd-backend.yml`](../../.github/workflows/cd-backend.yml) | **Déploiement critique** du backend sur le pool Azure `certigo-ci`. |
| [`promote-backend-staging-prod.yml`](../../.github/workflows/promote-backend-staging-prod.yml) | Orchestrateur **manuel** (`workflow_dispatch`) qui **réutilise** `cd-backend.yml`. |
| [`release-android.yml`](../../.github/workflows/release-android.yml) | Build **AAB lourd**, runner **en dur** `[self-hosted, Linux, X64, certigo-ci]` (release/tag). |
| [`release-ios.yml`](../../.github/workflows/release-ios.yml) | **iOS = Mac obligatoire** (Xcode), runner **en dur** `[self-hosted, macOS]`. **Non remplaçable.** |
| [`sync-ios-certs.yml`](../../.github/workflows/sync-ios-certs.yml) | Certificats iOS, runner **en dur** `[self-hosted, macOS]`. **Non remplaçable.** |

> ⚠️ **Runner macOS distinct.** Les jobs iOS exigent un runner **macOS self-hosted** séparé des 2 VMs
> Linux de ce runbook. S'il existe, il doit **rester disponible** pour les releases iOS. Voir
> [`docs/RELEASE_MOBILE.md`](../RELEASE_MOBILE.md).

---

## 9. Politique permanente de sélection

Les workflows Linux utilisent exclusivement :

```yaml
runs-on: [self-hosted, Linux, X64, certigo-ci]
```

Cette sélection n'est ni paramétrable ni dotée d'un fallback. La capacité se restaure en
remettant une VM Azure conforme en ligne, jamais en changeant le type de runner.

---

## Références (chemins relatifs)

- Preuve du blocage EMU : run [`28782170300`](https://github.com/gchambaud_microsoft/Certigo/actions/runs/28782170300).
- Workflows CI/CD : [`.github/workflows/`](../../.github/workflows/).
- Restent self-hosted : [`cd-backend.yml`](../../.github/workflows/cd-backend.yml),
  [`promote-backend-staging-prod.yml`](../../.github/workflows/promote-backend-staging-prod.yml),
  [`release-android.yml`](../../.github/workflows/release-android.yml),
  [`release-ios.yml`](../../.github/workflows/release-ios.yml),
  [`sync-ios-certs.yml`](../../.github/workflows/sync-ios-certs.yml).
- Contexte iOS/mobile : [`docs/RELEASE_MOBILE.md`](../RELEASE_MOBILE.md).
- Doc GitHub self-hosted runners : <https://docs.github.com/actions/hosting-your-own-runners/managing-self-hosted-runners>.
- Autres runbooks : [`docs/runbooks/README.md`](./README.md).

> **Paramètres confirmés** : RG `RG-CERTIGO-CI` · VMs `vm-certigo-runner`, `vm-certigo-runner-2` ·
> subscription `b8952c8c-8f72-469d-99cd-ac906da4e2fc` (Non-Prod) · labels `self-hosted, Linux, X64, certigo-ci`.
