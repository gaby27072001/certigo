# CI_RUNNERS — Runbook opérationnel de la CI self-hosted (runners GitHub Actions sur VMs Azure)

| Champ | Valeur |
|---|---|
| **Type** | Runbook opérationnel (CI / infra / coûts) |
| **Objectif** | Exploiter la CI de Certigo sur ses **runners self-hosted** : **rallumer** les VMs avant une session de travail, les **déallouer** après (économie), **vérifier** l'état des runners et **dépanner** un runner hors ligne. |
| **Voie officielle** | **Self-hosted** — VMSS flexible Azure. Les runners GitHub-hosted sont indisponibles par politique d'organisation. |
| **Périmètre** | Repo `gchambaud_microsoft/Certigo` · RG `RG-CERTIGO-CI` · subscription `b8952c8c-8f72-469d-99cd-ac906da4e2fc` (**Non-Prod**). |
| **Statut** | **Migration bloquée** : aucune déallocation automatisée avant séparation des labels et retrait du scale-in CPU. |

> **Dérive live consolidée au 20 août 2026.** Le pool est désormais
> `vmss-certigo-runner-zonal` (Flexible, autoscale 2–4). Les deux runners GitHub
> enregistrés portent simultanément `certigo-pr` et `certigo-trusted`; le scale-in CPU
> ignore l'état `busy`. Les anciennes commandes visant `vm-certigo-runner` et
> `vm-certigo-runner-2` ne doivent plus être exécutées.

> ⚠️ **Principe « l'agent PRÉPARE, VOUS EXÉCUTEZ »** — aucune commande `gh` / `az` n'est lancée par
> l'agent. Les commandes ci-dessous sont **à exécuter par vous** après vérification des identifiants
> (repo, noms de VM, resource group, subscription).
>
> Exécuter d'abord `bash infra/ci-runner/lifecycle-preflight.sh deallocate`. Ce script est
> strictement read-only et bloque l'état actuel. La migration et le rollback sont définis dans
> [`CLOUD_LEAST_PRIVILEGE.md`](./CLOUD_LEAST_PRIVILEGE.md).

---

## 1. Contexte & verdict — pourquoi self-hosted (et pas GitHub-hosted)

La cible Certigo s'appuie sur des runners **self-hosted** isolés :
`self-hosted, Linux, X64, certigo-pr` pour toute source PR et
`self-hosted, Linux, X64, certigo-trusted` pour les opérations/gates sans source PR.
Ils doivent être portés par des pools/VMSS distincts. Ce n'est pas une préférence : c'est
une **contrainte dure**, désormais **prouvée empiriquement**.

**Test empirique (verdict sans appel).** Une tentative de bascule vers un runner
hébergé par GitHub a été testée en conditions réelles :

- **Échec immédiat** : `startup_failure` en **~4 secondes**.
- **Annotation GitHub** : les runners hébergés sont désactivés pour ce dépôt.
- **Preuve** : run **`28782170300`** →
  <https://github.com/gchambaud_microsoft/Certigo/actions/runs/28782170300>.

**Décision durable** : aucune réactivation ni validation par un propriétaire Enterprise ne sera
sollicitée. La CI et ses contrôles compensatoires reposent exclusivement sur le pool Azure.

> ✅ **Conclusion opérationnelle** : **self-hosted est la voie officielle et pérenne** de la CI Certigo.
> Le reste de ce runbook décrit son exploitation au quotidien. Aucun chemin alternatif
> hébergé par GitHub n'est supporté.

---

## 2. Inventaire de l'infrastructure CI

| Élément | Valeur |
|---|---|
| **VMSS live** | `vmss-certigo-runner-zonal` · Flexible · `Standard_D2ads_v6` |
| **Capacité Azure live** | `f55d176e` gérée/running; `4153d1dd` externe/deallocated et hors scope; `22f7fb52` absent (`ResourceNotFound`) |
| **Resource group** | `RG-CERTIGO-CI` |
| **Subscription** | `b8952c8c-8f72-469d-99cd-ac906da4e2fc` (**Non-Prod**) |
| **Runners GitHub live** | `22f7fb52` offline/stale et absent d'Azure; `f55d176e` est le seul runner géré/online; labels doubles encore bloquants |
| **Classification contrôleur** | `22f7fb52` absent · `f55d176e` géré · `4153d1dd` externe explicitement allow-listée, jamais comptée ou ciblée |
| **Identité VMSS** | UAMI `id-vm-certigo-runner-2-vmss`, rôle `Key Vault Secrets User` au coffre CI exact |
| **Repo desservi** | `gchambaud_microsoft/Certigo` |

> 📌 Les labels `certigo-pr` et `certigo-trusted` doivent redevenir mutuellement exclusifs. Un éventuel
> runner **macOS** dédié à iOS (cf. §9) est **distinct** et **n'est pas** géré par ce runbook.

> ℹ️ **Prérequis outillage** (poste opérateur) : `az` (Azure CLI) connecté à la subscription Non-Prod,
> et `gh` (GitHub CLI) authentifié sur `gchambaud_microsoft/Certigo`.

---

## 3. Capacité et stratégie d'exploitation

Chaque runner traite **un job GitHub Actions à la fois**. L'autoscale CPU actuel peut ajouter
ou retirer une VM sans connaître GitHub. Tout scale-in reste interdit jusqu'au remplacement
par le contrôleur sérialisé décrit dans le runbook moindre privilège.

Baseline 30 jours : **242,06 USD**, 413 jobs, 18,84 runner-heures, CPU moyen 3,78 %,
file P95 5 108 s et P99 12 628 s. Le CPU faible combiné à une file longue justifie un
contrôleur `workflow_job` queue-driven, pas un seuil CPU. Son feature flag reste désactivé.
Le plan réconcilie les noms Azure/GitHub à chaque lecture et ne suppose jamais deux instances
fixes. La redondance doit être reconstruite avec labels, identités et sous-réseaux séparés,
puis prouvée avant toute activation. La cible du pilote ultérieur est **6 PR + 2 trusted**;
ce n'est ni le plafond live actuel de 4, ni un maximum de production définitif.

| Situation | État requis | Décision opérateur |
|---|---|---|
| Avant une session CI | un runner exclusif `certigo-pr` et un exclusif `certigo-trusted`, `online` | Tant que les labels sont doubles, corriger la configuration avant toute automation. |
| Pendant une session | zéro scale-in CPU | Ne jamais laisser Azure retirer une instance sur simple faible CPU. |
| Après la session | 5 min continues à zéro, reset sur toute activité, puis deux gardes | Prévol seulement; changement sous lease, un pool à la fois, avec réarmement sur nouvelle activité. |
| Panne/maintenance | autre classe préservée | Ne jamais déplacer son label pour contourner la panne. |

Le détail de reconstruction, de santé et de révocation est dans
[`docs/CI_RUNNER_RESILIENCE.md`](../CI_RUNNER_RESILIENCE.md).

Prévisualiser drift et état `idle`/`normal`/`boost`, sans mutation :

```bash
bash infra/ci-runner/capacity-plan.sh
```

---

## 4. Rallumer la CI (avant une session de travail)

Le dépôt ne fournit pas de chemin mutable tant que les findings live restent ouverts.

```bash
export AZURE_SUBSCRIPTION_ID=b8952c8c-8f72-469d-99cd-ac906da4e2fc
bash infra/ci-runner/lifecycle-preflight.sh start
```

Une future automation externe acquiert un lease, démarre un pool, attend Azure `running` puis
GitHub `online`, et restaure seulement son label exclusif.

**Vérifier que les runners sont bien en ligne côté GitHub :**

```bash
gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | {name, status, busy}'
# Attendu : status = "online" pour les 2 runners
```

Attendre `status: online` **avant** d'approuver un run de PR (sinon les jobs restent `Pending`).

---

## 5. Éteindre la CI (après usage — pour le coût)

Le prévol ci-dessous vérifie les labels, jobs actifs/en file, autoscale, frontières
d'identité/sous-réseau et réconciliation Azure/GitHub. Il n'effectue aucune déallocation.
Dans le présent livrable, `enabled=false` bloque tous les prévols. Après une future activation
séparée, le premier passage démarrera seulement la quiet period; un snapshot d'état externe
devra prouver les 5 minutes continues puis deux gardes distinctes.

```bash
bash infra/ci-runner/lifecycle-preflight.sh deallocate
```

> ⚠️ **`deallocate` ≠ `stop` — c'est le point crucial.**
> - **`az vm deallocate`** : **libère** le compute (CPU/RAM). Vous **ne payez plus que le disque**
>   attaché. **➜ à utiliser systématiquement.**
> - **`az vm stop`** (ou un `shutdown` depuis l'OS) : éteint l'OS mais **laisse la VM allouée** →
>   **le compute reste facturé**. ❌ **à éviter.**

Un résultat bloqué est le comportement attendu tant que les labels doubles, la file ou le
scale-in CPU existent.

---

## 6. Vérifier l'état (VMs + runners)

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

## 7. Dépannage — un runner reste `offline`

Si, après un `az vm start` et ~1–2 minutes d'attente, un runner reste `offline` côté GitHub :

1. **Confirmer l'état Azure de la VM** (§6). Si elle n'est pas `VM running`, la (re)démarrer :
   ```bash
   az vm restart --resource-group RG-CERTIGO-CI --name <vm-concernée>
   ```
2. **Vérifier le service de l'agent sur la VM** (connexion SSH / Bastion selon l'accès en vigueur). Le
   runner tourne en service systemd nommé `actions.runner.*`. Le compte break-glass peut
   administrer le service ; le compte de service `runner` ne peut exécuter sans mot de
   passe que le wrapper root-owned, sans argument, de redémarrage :
   ```bash
   systemctl list-units 'actions.runner.*'
   sudo systemctl status  'actions.runner.*'
   sudo systemctl restart 'actions.runner.*'   # relance l'agent si le service est tombé

   # Seulement depuis le compte runner :
   sudo /usr/local/sbin/certigo-runner-restart
   ```
   L'allow-list du compte `runner` est volontairement limitée à ce wrapper, à
   `apt-get update` et à `apt-get install -y unzip zip jq xz-utils` (les seuls paquets
   requis par les jobs actuels, avec `DEBIAN_FRONTEND` autorisé). Il ne peut ni installer
   de paquet arbitraire, ni reconfigurer un service, ni enregistrer un runner.
3. **Consulter les logs de l'agent** sur la VM (répertoire `_diag/` de l'installation du runner) pour
   identifier un échec de connexion.
4. **En dernier recours — reconfigurer le runner** (token expiré, runner supprimé côté GitHub, etc.) en
   suivant la procédure **officielle GitHub** pour les self-hosted runners :
   <https://docs.github.com/actions/hosting-your-own-runners/managing-self-hosted-runners>.

> 🔐 **Aucun secret en clair.** Ne copiez **jamais** de token d'enregistrement (`--token …`), de PAT ou
> de secret dans ce runbook, un ticket, un chat ou un commit. Les tokens d'enregistrement de runner sont
> **éphémères** et se régénèrent depuis **Settings → Actions → Runners** du repo au moment du besoin.

---

## 8. Coût & bonnes pratiques

- **Ne jamais laisser les VMs allumées H24.** Une VM `running` — ou seulement `stopped` (non
  déallouée) — facture le compute **même à vide**. C'est le principal poste d'économie.
- **Aucune déallocation immédiate** après une session : attendre 5 minutes continues sans
  activité, deux gardes, le lease et la garde finale; réarmer si un run apparaît ensuite.
- **Vérifier `busy: false`** avant de déallouer (§6) pour ne pas tuer un run en cours.
- **Grouper les runs.** Plutôt que d'allumer/éteindre pour une micro-PR, regrouper les besoins CI d'une
  même session réduit les cycles de démarrage.
- **Subscription Non-Prod** : ces VMs vivent dans la sub `b8952c8c-8f72-469d-99cd-ac906da4e2fc`
  (Non-Prod) — vérifier le contexte via `az account show` avant toute commande.

---

## 9. Ce qui reste **obligatoirement** self-hosted

Tous les workflows **exigent** une capacité self-hosted adaptée :

| Workflow | Raison |
|---|---|
| [`cd-backend.yml`](../../.github/workflows/cd-backend.yml) | **Déploiement critique** du backend sur `certigo-trusted`. |
| [`release-android.yml`](../../.github/workflows/release-android.yml) | Build **AAB lourd**, runner `[self-hosted, Linux, X64, certigo-trusted]`. |
| [`release-ios.yml`](../../.github/workflows/release-ios.yml) | **iOS = Mac obligatoire**, runner `[self-hosted, macOS, certigo-trusted]`. |
| [`sync-ios-certs.yml`](../../.github/workflows/sync-ios-certs.yml) | Certificats iOS, runner `[self-hosted, macOS, certigo-trusted]`. |

> ⚠️ **Runner macOS distinct.** Les jobs iOS exigent un runner **macOS self-hosted** séparé des 2 VMs
> Linux de ce runbook. S'il existe, il doit **rester disponible** pour les releases iOS. Voir
> [`docs/RELEASE_MOBILE.md`](../RELEASE_MOBILE.md).

---

## 10. Politique permanente de sélection

Les workflows Linux utilisent exclusivement l'une de ces deux sélections :

```yaml
runs-on: [self-hosted, Linux, X64, certigo-pr]
runs-on: [self-hosted, Linux, X64, certigo-trusted]
```

Ces sélections ne sont ni paramétrables ni dotées d'un fallback. `certigo-pr` ne reçoit
ni environnement, ni secret, ni identité cloud ; `certigo-trusted` ne checkout et
n'analyse jamais de source PR. Tout workflow contenant un job `certigo-trusted`
interdit `workflow_dispatch` et les déclencheurs par tag : les opérations manuelles
utilisent un type `repository_dispatch` dédié afin que GitHub charge le YAML depuis
la branche par défaut. Ces workflows interdisent `actions/cache`, l'action Flutter à tool-cache
partagé et toute entrée `cache`/`pub-cache` autre que le booléen littéral `false`. Les jobs mobiles
installent à la place un SDK Flutter neuf après vérification d'un SHA-256 figé, utilisent un
`PUB_CACHE` propre au run, puis suppriment SDK et cache. Aucun état inscriptible par les
validations PR ne peut donc être restauré sur le pool trusted.

---

## Références (chemins relatifs)

- Preuve du blocage EMU : run [`28782170300`](https://github.com/gchambaud_microsoft/Certigo/actions/runs/28782170300).
- Workflows CI/CD : [`.github/workflows/`](../../.github/workflows/).
- Restent self-hosted : [`cd-backend.yml`](../../.github/workflows/cd-backend.yml),
  [`release-android.yml`](../../.github/workflows/release-android.yml),
  [`release-ios.yml`](../../.github/workflows/release-ios.yml),
  [`sync-ios-certs.yml`](../../.github/workflows/sync-ios-certs.yml).
- Contexte iOS/mobile : [`docs/RELEASE_MOBILE.md`](../RELEASE_MOBILE.md).
- Doc GitHub self-hosted runners : <https://docs.github.com/actions/hosting-your-own-runners/managing-self-hosted-runners>.
- Autres runbooks : [`docs/runbooks/README.md`](./README.md).

> **Paramètres confirmés** : RG `RG-CERTIGO-CI` · VMSS
> `vmss-certigo-runner-zonal` · subscription
> `b8952c8c-8f72-469d-99cd-ac906da4e2fc` · `22f7fb52` absent ·
> `f55d176e` géré · `4153d1dd` externe · labels live doubles à corriger.
