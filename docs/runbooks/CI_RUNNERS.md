# CI_RUNNERS — Runbook opérationnel de la CI self-hosted (runners GitHub Actions sur VMs Azure)

| Champ | Valeur |
|---|---|
| **Type** | Runbook opérationnel (CI / infra / coûts) |
| **Objectif** | Exploiter la CI de Certigo sur ses **runners self-hosted** : **rallumer** les VMs avant une session de travail, les **déallouer** après (économie), **vérifier** l'état des runners et **dépanner** un runner hors ligne. |
| **Voie officielle** | **Self-hosted** — VMSS flexible Azure. Les runners GitHub-hosted sont indisponibles par politique d'organisation. |
| **Périmètre** | Repo `gchambaud_microsoft/Certigo` · RG `RG-CERTIGO-CI` · subscription `b8952c8c-8f72-469d-99cd-ac906da4e2fc` (**Non-Prod**). |
| **Statut** | **Labels séparés (vérifié le 4 septembre 2026)**. **Runners à la demande depuis le 2026-09-30** (§13) : les VM s'éteignent seules au repos et se rallument quand un job les attend ; les §4 et §5 ne sont plus que le mode dégradé. |

> **Dérive live consolidée au 4 septembre 2026.** Le pool trusted est
> `vmss-certigo-runner-zonal` (Flexible, capacité 2, autoscale 2–4) et le pool PR est
> `vmss-certigo-pr-pilot-z1` (capacité 1). **Les labels sont désormais strictement
> disjoints** : aucun runner ne porte simultanément `certigo-pr` et `certigo-trusted`.
> L'affirmation précédente (« les deux runners portent les deux labels », 20 août 2026)
> est **caduque** et a été corrigée. Le scale-in CPU ignore toujours l'état `busy`.
> Les anciennes commandes visant `vm-certigo-runner` et `vm-certigo-runner-2` ne doivent
> plus être exécutées : `vm-certigo-runner-2` n'est plus qu'un *hostname* interne porté
> par l'instance VMSS `vmss-certigo-runner-zonal_be505fa1`.

> 🔁 **Contrainte structurante — déallocation nocturne non négociable.**
> `MCAPSGovernance-AutomationApp` (appId `a1a9c5b6-7a4f-4288-89ab-6805873f65d1`, tenant
> `975f013f-7f24-47e8-a7d3-abc4752bf346`) **désalloue toutes les VM du resource group
> chaque nuit vers 00:46–00:49 UTC**. Ce principal détient `Owner` au niveau du
> management group `896a9463-4bb5-462e-b7b5-2e525d3e1a03`, c'est-à-dire **au-dessus de la
> subscription** : le projet ne peut ni le révoquer, ni s'en exempter. Aucune assignation
> de policy au scope du RG, aucun `Microsoft.DevTestLab/schedules`, aucun tag d'exemption
> n'existe pour le contourner. **La CI est donc indisponible chaque matin jusqu'à ce que
> quelqu'un rallume les VMs**, et les 7 checks requis de `main` le sont avec elle.
> Toute conception doit supposer cette déallocation permanente et viser la **reprise**,
> jamais la prévention. Détail et preuves : [`docs/CI_RUNNER_RESILIENCE.md`](../CI_RUNNER_RESILIENCE.md).

> ⚠️ **Principe « l'agent PRÉPARE, VOUS EXÉCUTEZ »** — aucune commande `gh` / `az` n'est lancée par
> l'agent. Les commandes ci-dessous sont **à exécuter par vous** après vérification des identifiants
> (repo, noms de VM, resource group, subscription).
>
> Exécuter d'abord `bash infra/ci-runner/lifecycle-preflight.sh deallocate`. Ce script est
> strictement read-only et doit bloquer l'état actuel. La migration et le rollback sont définis dans
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
| **VMSS live** | trusted `vmss-certigo-runner-zonal` (capacité 2, zones 1 et 2) + pilote PR `vmss-certigo-pr-pilot-z1` (zone 1, capacité 4 : ses 4 instances utiles) |
| **Capacité Azure live** | `f55d176e` (zone 2) et `be505fa1` (zone 1) trusted; `5275ea21`, `94bad106`, `1a6deaa2`, `6e3abce4` (zone 1) PR; les 7 instances PR retirées (`2c1eeb41`, `3601055e`, `765cf6af`, `7d3001c2`, `a14700a3`, `bbf83c5c`, `d8d42366`) ont été supprimées le 2026-09-25 et restent interdites; `4153d1dd` externe; `22f7fb52` et `4596a9d5` absentes/interdites |
| **Resource group** | `RG-CERTIGO-CI` |
| **Subscription** | `b8952c8c-8f72-469d-99cd-ac906da4e2fc` (**Non-Prod**) |
| **Runners GitHub live** | ID 27 `…_f55d176e-Certigo` et ID 29 `…_be505fa1-Certigo` **trusted**; ID 31 `certigo-prMVOC2P`, ID 32 `certigo-prTRHQEY`, ID 33 `certigo-pr7BZU76`, ID 34 `certigo-prUL1UCK` **pr** — labels disjoints |
| **Classification contrôleur** | f55 + be5 + les 4 instances PR liées explicitement dans `capacity-controller.config.json` · les 7 noms des instances PR supprimées dans `forbiddenVirtualMachines` · `22f7fb52` absent · `4153d1dd` externe · `4596a9d5` interdit |
| **Identités** | f55/be5 : UAMI du VMSS zonal; pilote PR : aucune identité |
| **Repo desservi** | `gchambaud_microsoft/Certigo` (les mêmes VMs hébergent aussi un agent pour `gchambaud_microsoft/certigo-content`) |

> Inventaire mesuré le 2026-09-23 vers 16:10 UTC (`az vm list -g rg-certigo-ci -d` et
> `gh api repos/gchambaud_microsoft/Certigo/actions/runners`; `osProfile.computerName` =
> nom du runner GitHub). Invalidé par tout ajout, remplacement ou suppression d'instance
> dans l'un des deux scale sets.

> ✅ Les labels `certigo-pr` et `certigo-trusted` **sont** mutuellement exclusifs depuis le
> 4 septembre 2026. Un éventuel runner **macOS** dédié à iOS (cf. §9) est **distinct** et
> **n'est pas** géré par ce runbook.

> 🔗 **Les instances trusted servent aussi `certigo-content` sous le label `certigo-ci`.**
> `f55d176e` et `be505fa1` portent chacune un **second** agent, enregistré dans
> `gchambaud_microsoft/certigo-content` avec les labels `certigo-ci,azure,vmss,zonal,certigo`
> (ID 25 et ID 26). C'est **intentionnel et porteur** : ces instances sont les seules à
> joindre le stockage de contenu immuable via son private endpoint. **Ne pas supprimer ces
> agents, ne pas renommer leurs labels, ne pas les « normaliser »** — la publication de
> contenu s'exécute dessus. Noter la tension assumée : `certigo-ci` est *interdit* dans un
> `runs-on:` des workflows **de ce dépôt** (validateur `validate-workflow-security.mjs`)
> alors qu'il est *requis* par ceux de `certigo-content`. Cette question est documentée
> dans [`docs/CI_RUNNER_RESILIENCE.md`](../CI_RUNNER_RESILIENCE.md) et **reste à trancher**.

> ⏱️ **Marge avant la fenêtre nocturne.** Une publication de contenu complète dure de
> l'ordre de **quatre heures**. Elle doit donc démarrer avec plusieurs heures de marge
> avant la déallocation de 00:46–00:49 UTC, faute de quoi elle est interrompue en vol.

> ⚠️ **Toute instance du VMSS doit figurer dans `infra/ci-runner/capacity-controller.config.json`.**
> C'est la cause racine de l'incident du 1er septembre 2026 : `be505fa1` n'apparaissait dans
> aucun artefact versionné, donc la liste de rallumage de l'opérateur l'ignorait
> silencieusement. Restée éteinte plus de 14 jours, son enregistrement runner a été
> supprimé par GitHub et `az vm start` ne suffisait plus à la rétablir.
>
> Depuis le 2026-09-23, la **reprise nocturne ne dépend plus de cet inventaire pour savoir
> quoi rallumer** : elle énumère les membres des deux scale sets à chaque run (§11). L'inventaire
> reste la source des **exclusions** (`forbiddenVirtualMachines`, `externalVirtualMachines`), des
> planchers (`minimumOnlineByTrust`) et des bindings du contrôleur et de `runner-health.yml`.

> ℹ️ **Prérequis outillage** (poste opérateur) : `az` (Azure CLI) connecté à la subscription Non-Prod,
> et `gh` (GitHub CLI) authentifié sur `gchambaud_microsoft/Certigo`.

---

## 3. Capacité et stratégie d'exploitation

Chaque runner traite **un job GitHub Actions à la fois**. L'autoscale CPU live peut encore
ajouter une VM trusted sans connaître GitHub (`> 70 % / 10 min`). Le scale-in
`< 20 % / 45 min` a été retiré du live le 2026-09-23 à 18:01Z en appliquant `capacity.bicep`
(voir §12, « Piège mesuré ») ; toute réduction de capacité reste interdite.

Baseline 30 jours : **242,06 USD**, 413 jobs, 18,84 runner-heures, CPU moyen 3,78 %,
file P95 5 108 s et P99 12 628 s. Le CPU faible combiné à une file longue justifie un
contrôleur `workflow_job` queue-driven, pas un seuil CPU. Son feature flag reste désactivé.
Le plan réconcilie les bindings Azure/GitHub exacts et exige simultanément power Azure
**et** runner GitHub online. La séparation des labels est **acquise**; le contrôleur
impose désormais aussi un plancher de redondance (`minimumOnlineByTrust`) de
**2 runners `certigo-pr` et 2 runners `certigo-trusted` online**, comparé **par classe de
confiance** et non sur l'agrégat. La cible du pilote ultérieur est **6 PR + 2 trusted**;
ce n'est ni le plafond live actuel de 4, ni un maximum de production définitif.

| Situation | État requis | Décision opérateur |
|---|---|---|
| Avant une session CI | **deux** runners exclusifs `certigo-pr` et **deux** exclusifs `certigo-trusted`, `online` | Vérifier côté GitHub, pas seulement le power state Azure. |
| Pendant une session | zéro scale-in CPU | Ne jamais laisser Azure retirer une instance sur simple faible CPU. |
| Après la session | 5 min continues à zéro, reset sur toute activité, puis deux gardes | Prévol seulement; changement sous lease, un pool à la fois, avec réarmement sur nouvelle activité. |
| Panne/maintenance | autre classe préservée | Ne jamais déplacer son label pour contourner la panne. |
| Chaque matin | toutes les VMs de `rg-certigo-ci` sont désallouées par la gouvernance MCAPS (00:46–00:49 UTC) | La reprise §11 rallume à 01:30 UTC toutes les instances non exclues des deux scale sets ; elles se rééteignent ensuite après leur période calme (§13), et le premier job de la journée réveille son pool. |

Le détail de reconstruction, de santé et de révocation est dans
[`docs/CI_RUNNER_RESILIENCE.md`](../CI_RUNNER_RESILIENCE.md).

Prévisualiser drift et état `idle`/`normal`/`boost`, sans mutation :

```bash
bash infra/ci-runner/capacity-plan.sh
```

---

## 4. Rallumer la CI (avant une session de travail)

> ⏻ **Depuis le 2026-09-30, rien à faire** : le premier job en file réveille son pool (§13).
> Cette section ne sert plus qu'en mode dégradé (réveil désactivé, webhook en échec).

> 📌 **Depuis la reprise automatique (§11), ce rallumage manuel n'est plus la voie normale.**
> Toutes les instances non exclues des deux scale sets sont démarrées chaque jour à
> **01:30 UTC**. Cette section reste le mode dégradé : reprise en échec, reprise désactivée,
> ou besoin de rallumer en cours de journée.
> Rappel : une VM sous tension n'est **pas** un runner `online` — toujours confirmer au §6.

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

> ⏻ **Depuis le 2026-09-30, c'est automatique** (§13) : chaque VM s'éteint seule après sa
> période calme sans job (PR 15 min, trusted 20 min) et Azure la désalloue dans les 5 minutes.

Le prévol ci-dessous vérifie, sur les deux dépôts, les labels, jobs actifs/en file, autoscale,
frontières d'identité/sous-réseau et réconciliation Azure/GitHub. Il n'effectue aucune
déallocation. Un run système Dependabot n'est exclu que si son acteur est `dependabot[bot]`,
son événement `dynamic` et tous ses jobs sans runner portent le seul label `dependabot`; une
fiche job absente ou une cible self-hosted bloque.

Dans le présent livrable, `enabled=false` et les dérives de migration bloquent toute nouvelle
mutation. Une exception de lecture existe pour l'état final déjà sûr : si f55 et bbf sont
explicitement `deallocated`, les trois registrations exactes sont non-busy et la file valide
est vide, le prévol retourne `terminalSafe=true`, `safeToRequestChange=false` et
`requestedChange=none`. Il ne redémarre rien et n'invente pas de quiet period après coup.
Les dérives restent visibles dans `reasons` afin de bloquer un prochain start/deallocate.
Après une future activation séparée, une vraie déallocation exigera toujours 5 minutes
continues puis deux gardes distinctes. L'état v3 conserve la capacité exacte supprimée par
classe jusqu'à son réarmement réel.

```bash
bash infra/ci-runner/lifecycle-preflight.sh deallocate
```

> ⚠️ **`deallocate` ≠ `stop` — c'est le point crucial.**
> - **`az vm deallocate`** : **libère** le compute (CPU/RAM). Vous **ne payez plus que le disque**
>   attaché. **➜ à utiliser systématiquement.**
> - **`az vm stop`** (ou un `shutdown` depuis l'OS) : éteint l'OS mais **laisse la VM allouée** →
>   **le compute reste facturé**. ❌ **à éviter.**

Un résultat bloqué reste le comportement attendu tant que la file, le scale-in CPU ou un
déficit de redondance `certigo-trusted` existent, sauf constat terminal-safe déjà désalloué
décrit ci-dessus. Le chevauchement de labels, lui, n'est plus une cause de blocage : il est
résolu.

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

> 🔴 **Cas prouvé le 4 septembre 2026 — « VM running » n'est pas « runner online ».**
> Une VM peut être `VM running` sans qu'aucun runner n'apparaisse côté GitHub, **même pas
> en `offline`**. Le journal de l'agent affiche alors :
> `Failed to create a session. The runner registration has been deleted from the server,
> please re-configure.` GitHub supprime l'enregistrement d'un runner resté trop longtemps
> déconnecté (~14 jours). L'agent démarre, se connecte, est rejeté, puis s'arrête de
> lui-même (`no retry needed`). **Dans ce cas `az vm start`, `systemctl start` et
> `systemctl enable` ne peuvent rien** : seul un réenregistrement rétablit le runner.
> Un contrôle de santé qui ne regarde que le power state Azure **manque** cette panne.

Si, après un `az vm start` et ~1–2 minutes d'attente, un runner reste `offline` côté GitHub :

1. **Confirmer l'état Azure de la VM** (§6). Si elle n'est pas `VM running`, la (re)démarrer :
   ```bash
   az vm start --subscription b8952c8c-8f72-469d-99cd-ac906da4e2fc \
     --resource-group RG-CERTIGO-CI --name <vm-concernée>
   ```
   Les instances du VMSS Flexible s'adressent bien avec les commandes `az vm` ordinaires.
2. **Vérifier le service de l'agent sur la VM** (connexion SSH / Bastion selon l'accès en vigueur). Le
   runner tourne en service systemd nommé `actions.runner.*`. Sur les instances du VMSS zonal,
   les répertoires d'installation sont `/home/azureuser/actions-runner-2` (repo `Certigo`) et
   `/home/azureuser/actions-runner-content` (repo `certigo-content`), sous l'utilisateur
   `azureuser`. Le compte break-glass peut administrer le service ; le compte de service
   `runner` ne peut exécuter sans mot de passe que le wrapper root-owned, sans argument, de
   redémarrage :
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
3. **Consulter les logs de l'agent** : `journalctl -u 'actions.runner.*' -n 100`, ou le
   répertoire `_diag/` de l'installation. Chercher explicitement le message
   `registration has been deleted from the server`.
4. **Si l'enregistrement a été supprimé — réenregistrer** en suivant la procédure
   **officielle GitHub** pour les self-hosted runners :
   <https://docs.github.com/actions/hosting-your-own-runners/managing-self-hosted-runners>.
   Réappliquer **exactement** le jeu de labels d'origine de la classe concernée. Pour le
   pool trusted zonal : `certigo-trusted,azure,vmss,zonal,certigo`. **Ne jamais** ajouter
   `certigo-pr` ni `certigo-pr-pilot` à un runner trusted — le chevauchement de labels
   effondre la frontière de confiance et le validateur du dépôt le bloque.

> 🩹 **Un job échoue sur `Could not get lock /var/lib/dpkg/lock-frontend` ou
> `/var/lib/apt/lists/lock` ?** Le patching invité Azure (`LinuxPatchExtension`) exécute
> lui-même apt sur les runners PR. L'automate de gouvernance MCAPS l'a activé le 2026-09-15.
> Une évaluation quotidienne lance `apt-get update` (le 2026-09-24 entre 05:48 et 05:51 UTC),
> et une installation a eu lieu le 2026-09-19 sur les runners 31 et 34. Détails dans
> « Le patching invité Azure modifie les runners » et « Qui a activé ce patching », dans
> [`docs/CI_RUNNER_RESILIENCE.md`](../CI_RUNNER_RESILIENCE.md). Conduite à tenir : relancer
> le job, ne rien réinstaller ni reconfigurer sur le runner. Aucune occurrence de ce symptôme
> n'a encore été observée : c'est un risque déduit.
>
> **Prévention, si un workflow doit lancer apt sur un runner PR.** Garder l'appel
> conditionnel, comme les étapes « Ensure CI prerequisites », qui ne lancent apt que si un
> outil manque. Et envelopper les **deux commandes exactes** autorisées par le sudoers dans
> une boucle bornée. `-o DPkg::Lock::Timeout=…` n'est pas utilisable : le sudoers du runner
> n'autorise que `apt-get update` et `apt-get install -y unzip zip jq xz-utils`, sans aucun
> autre argument. L'évaluation observée le 2026-09-24 a duré moins d'une minute par instance :
> 6 essais espacés de 20 s la couvrent.
>
> ```bash
> for attempt in 1 2 3 4 5 6; do
>   if sudo apt-get update &&
>     sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip zip jq xz-utils; then
>     break
>   fi
>   if [ "${attempt}" -eq 6 ]; then exit 1; fi
>   echo "apt occupé (essai ${attempt}/6) : nouvel essai dans 20 s"
>   sleep 20
> done
> ```

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

## 11. Reprise automatique côté Azure (01:30 UTC)

Un Logic App `logic-certigo-ci-runner-recovery` dans `rg-certigo-ci` rallume **chaque jour à
01:30 UTC** toutes les instances des scale sets `vmss-certigo-runner-zonal` et
`vmss-certigo-pr-pilot-z1`, sauf celles exclues par l'inventaire, puis vérifie le résultat. Il
est décrit en Bicep : ne pas le modifier dans le portail.

- Composition : [`infra/ci-runner/auto-recovery.bicep`](../../infra/ci-runner/auto-recovery.bicep)
- Workflow + alerte : [`infra/ci-runner/modules/runnerAutoRecovery.bicep`](../../infra/ci-runner/modules/runnerAutoRecovery.bicep)
- Paramètres : [`infra/params/ci-runner-auto-recovery.bicepparam`](../../infra/params/ci-runner-auto-recovery.bicepparam)
- Exclusions et planchers : `inventory.forbiddenVirtualMachines`, `inventory.externalVirtualMachines`
  et `minimumOnlineByTrust` de [`infra/ci-runner/capacity-controller.config.json`](../../infra/ci-runner/capacity-controller.config.json),
  lus à la compilation (`loadJsonContent`) : aucune liste n'est recopiée ailleurs.

**Déroulé d'un run, pool par pool** (les deux pools sont indépendants jusqu'à la vérification :
l'échec de l'un n'empêche pas de rallumer l'autre) :

1. `List_the_instances_of_<pool>` : `GET .../virtualMachines?$filter='virtualMachineScaleSet/id' eq '<id>'&$expand=instanceView`.
   Un seul appel rend les membres **et** leur power state, sous le seul droit `virtualMachines/read`.
2. `Select_the_instances_to_start_in_<pool>` : retire les exclusions (comparaison en minuscules).
3. `Start_each_instance_of_<pool>` : un `start` par instance, en parallèle ; une instance cassée
   n'empêche pas les autres.
4. `Wait_for_the_power_state_to_settle` (30 s), puis `Relist_the_instances_of_<pool>`.
5. Trois assertions, dans cet ordre, chacune terminant le run en `Failed` :

| Action d'échec | Code | Signification |
|---|---|---|
| `Fail_the_run_when_the_enumeration_is_incomplete` | `RunnerEnumerationIncomplete` | ARM a paginé une liste : des instances n'ont été ni démarrées ni vérifiées |
| `Fail_the_run_when_a_runner_is_not_running` | `RunnerPowerStateNotRunning` | une instance non exclue n'a pas `PowerState/running` ; le message la **nomme** |
| `Fail_the_run_when_a_pool_is_below_its_floor` | `RunnerPoolBelowRedundancyFloor` | un pool a moins d'instances `running` que `minimumOnlineByTrust` (2 par classe) |

> ⚠️ **Ce mécanisme prouve le power state Azure, rien de plus.** Il ne dit **pas** qu'un
> runner est `online` côté GitHub — c'est précisément la panne du 1er septembre. Après une
> reprise, confirmer toujours avec le §6 (`gh api ... /actions/runners`). Et rallumer les VMs
> ne protège **pas** une opération longue : une publication de contenu de ~4 h démarrée trop
> tard sera tranchée à 00:46 UTC quoi qu'il soit rallumé ensuite.

> 🔁 **Remplacer ou ajouter une instance ne demande plus rien ici.** Elle est rallumée la nuit
> suivante parce qu'elle appartient au scale set. Seule une instance **retirée** (sans runner,
> ou en `Failed`) doit être inscrite dans `inventory.forbiddenVirtualMachines`, puis le Logic App
> redéployé : sinon le run échoue en `RunnerPowerStateNotRunning` en la nommant — les autres
> instances étant quand même rallumées. Historique : jusqu'au 2026-09-23 la liste était figée ;
> du 2026-09-12 au 2026-09-23 elle visait `bbf83c5c` et `a14700a3` (en `Failed`) et ignorait les
> quatre instances PR de remplacement, d'où **12 runs `Failed` consécutifs** et une CI PR éteinte
> chaque matin (#503, #508).

> ⏱️ **Durée mesurée d'un démarrage depuis `deallocated`** : ~1 min pour une instance trusted,
> **~7 min 30 s pour une instance PR** (2026-09-11 : `a14700a3` 7 min 32 s, `bbf83c5c` 8 min 01 s ;
> 2026-09-23 drill : `6e3abce4` 7 min 32 s). Un run complet dure donc ~8 min ; un runner PR
> n'est pas en ligne avant ~01:38 UTC. Depuis le réglage cloud-init du 2026-09-30 (§13), un
> runner PR est en ligne ≈ 45 s après le début du démarrage (mesuré sur `6e3abce4`).

> 🔗 **Depuis le 2026-09-30 (§13), cette reprise garde aussi les runners enregistrés.** Un pool
> sans job reste désalloué, et GitHub supprime un runner persistant resté plus de 14 jours sans
> connexion (c'est la panne du 1er septembre). Ne pas désactiver ni espacer cette reprise sans
> un autre réveil de chaque instance au moins une fois par semaine (ADR-022, risque 8).

### Vérifier que la reprise a bien tourné

```bash
export SUB=b8952c8c-8f72-469d-99cd-ac906da4e2fc
WF="/subscriptions/$SUB/resourceGroups/rg-certigo-ci/providers/Microsoft.Logic/workflows/logic-certigo-ci-runner-recovery"

# Historique : le run du matin doit être "Succeeded".
az rest --method get --subscription "$SUB" \
  --uri "https://management.azure.com${WF}/runs?api-version=2016-06-01" \
  --query "value[].{run:name,status:properties.status,start:properties.startTime}" -o table

# Détail action par action d'un run donné.
az rest --method get --subscription "$SUB" \
  --uri "https://management.azure.com${WF}/runs/<RUN_ID>/actions?api-version=2016-06-01" \
  --query "value[].{action:name,status:properties.status}" -o table

# Instances réellement démarrées par un pool (une répétition par instance).
az rest --method get --subscription "$SUB" \
  --uri "https://management.azure.com${WF}/runs/<RUN_ID>/actions/Start_an_instance_of_vmss_certigo_pr_pilot_z1/repetitions?api-version=2019-05-01" \
  --query "value[].{rep:name,status:properties.status,start:properties.startTime,end:properties.endTime}" -o table
```

Un run sain se termine `Succeeded` avec les **trois** actions `Fail_the_run_when_*` en
`Skipped`. Si l'une est `Succeeded`, la reprise a **échoué volontairement** : lire son code
dans le tableau ci-dessus. Les répétitions n'existent qu'avec l'API `2019-05-01` (`2016-06-01`
rend `ApiNotIntroduced`).

### Déclencher la reprise à la main

```bash
az rest --method post --subscription "$SUB" \
  --uri "https://management.azure.com${WF}/triggers/Daily_after_the_governance_teardown_window/run?api-version=2016-06-01"
```

> 📌 **Un premier run en échec juste après un déploiement neuf est normal.** Le déclencheur
> `Recurrence` se déclenche immédiatement à la création, avant propagation de l'assignation
> de rôle : ce run échoue en `ActionFailed`. Rejouer manuellement une minute plus tard. Une
> simple mise à jour du workflow existant ne déclenche pas de run.

### Comment on est prévenu d'un échec

Alerte `alert-certigo-ci-runner-recovery-failed` (sévérité 1) sur `RunsFailed > 0`, routée
vers l'action group `ag-certigo-ci-recovery`. Le destinataire e-mail vient de la variable
non secrète `ALERT_EMAIL` au déploiement; sans elle l'alerte existe mais n'envoie rien.

```bash
az monitor metrics alert show -g rg-certigo-ci -n alert-certigo-ci-runner-recovery-failed \
  --subscription "$SUB" --query "{enabled:enabled,severity:severity}" -o json
```

**Angle mort connu :** si le Logic App ne tourne **pas du tout**, `RunsFailed` reste vide et
l'alerte ne part pas. Le filet est `runner-health.yml`, qui s'exécute **sur un runner
trusted** : son échec à trouver un runner est la preuve que la reprise n'a pas eu lieu.

### Redéployer

Toujours depuis `main`, what-if d'abord, en repassant le destinataire d'alerte : un
déploiement sans `alertEmail` retire le destinataire de l'action group.

```bash
ALERT_EMAIL="$(az deployment sub show --subscription "$SUB" \
  --name <DERNIER_DEPLOIEMENT_REUSSI> --query properties.parameters.alertEmail.value -o tsv)"
az deployment sub what-if --subscription "$SUB" --location westeurope \
  --parameters infra/params/ci-runner-auto-recovery.bicepparam \
  --parameters alertEmail="$ALERT_EMAIL"
az deployment sub create --subscription "$SUB" --location westeurope \
  --name "certigo-ci-runner-auto-recovery-$(date -u +%Y%m%d%H%M%S)" \
  --parameters infra/params/ci-runner-auto-recovery.bicepparam \
  --parameters alertEmail="$ALERT_EMAIL"
```

Le what-if attendu ne crée ni ne supprime aucune ressource. Il montre toujours un `Modify`
de `properties.principalId` sur l'assignation de rôle : c'est la référence
`reference(...).identity.principalId`, non résolue au moment du what-if. L'identité du
workflow ne change pas (`04bca2c4-12ed-45fc-aab6-2f9641e76273`, système). Le
`Delete ... evaluatedRecurrence` est une propriété calculée par le service. Terminer par
un run manuel et la vérification ci-dessus.

### Rollback

```bash
# 1. Désactiver sans rien supprimer (réversible immédiatement).
az resource update --ids "$WF" --subscription "$SUB" --set properties.state=Disabled
az resource update --ids "$WF" --subscription "$SUB" --set properties.state=Enabled   # ré-activer

# 2. Revenir à la définition précédente : redéployer la composition depuis le commit précédent
#    (git worktree add <dir> <commit>), avec le même alertEmail, what-if d'abord.

# 3. Suppression complète (workflow + alerte + action group + RBAC + rôle).
#    Exige de lever le verrou du §12 : opération délibérée.
az logic workflow delete -g rg-certigo-ci -n logic-certigo-ci-runner-recovery --subscription "$SUB" --yes
az monitor metrics alert delete -g rg-certigo-ci -n alert-certigo-ci-runner-recovery-failed --subscription "$SUB"
az monitor action-group delete -g rg-certigo-ci -n ag-certigo-ci-recovery --subscription "$SUB"
az role assignment delete --assignee <principalId> \
  --scope "/subscriptions/$SUB/resourceGroups/rg-certigo-ci" --subscription "$SUB"
az role definition delete --name "Certigo CI Runner Recovery <suffixe>" --subscription "$SUB"
```

Le retrait rétablit l'état antérieur : rallumage manuel du §4. Rien d'autre n'en dépend.

### Prérequis de redéploiement

`Microsoft.Logic` doit être enregistré sur la subscription (il ne l'était pas avant ce
livrable) :

```bash
az provider register --namespace Microsoft.Logic --subscription "$SUB" --wait
```

---

## 12. Verrou `CanNotDelete` sur `rg-certigo-ci`

Le resource group porte un verrou `certigo-ci-cannot-delete`, décrit dans
[`infra/ci-runner/modules/resourceGroupDeletionLock.bicep`](../../infra/ci-runner/modules/resourceGroupDeletionLock.bicep).

**Pourquoi.** Plusieurs templates ciblent ce RG. Un déploiement en mode `Complete` depuis
l'un d'eux supprimerait ce que les autres ont créé — dont la zone
`privatelink.blob.core.windows.net`, qui porte les enregistrements A de **dev, staging, prod
et content**. Le verrou transforme cette destruction silencieuse en échec immédiat.

> ⚠️ **Toujours déployer en `--mode Incremental` (défaut) sur ce RG. Jamais `Complete`.**
> Lancer systématiquement `az deployment group what-if` d'abord et lire la section des
> suppressions.

> 🧟 **Piège mesuré : ne jamais réduire la capacité d'un scale set tant que le verrou est posé.**
> Un scale-in (baisse de `sku.capacity`, par `az vmss scale`, par une règle d'autoscale ou par
> un déploiement complet de `pilot.bicep` avec une capacité inférieure au live) demande au scale
> set de SUPPRIMER des instances. Le verrou refuse chaque suppression (`ScopeLocked`). Séquence
> mesurée dans l'Activity Log : le 2026-09-11 à 16:09:36Z et 16:14:57Z, deux scale-in manuels
> ont tenté de supprimer `bbf83c5c`, `a14700a3` (saines, rallumées avec succès le matin même)
> et `d8d42366` (déjà en échec de provisionnement) → `ScopeLocked` ; le 2026-09-12 à 00:48:33Z,
> la désallocation MCAPS de `bbf83c5c` et `a14700a3` a échoué en `InternalExecutionError`
> (`provisioningState: Failed`), et chaque `start` a ensuite échoué pareil. Le mécanisme exact
> n'est pas documenté par Microsoft, mais les deux instances saines visées sont mortes. Le
> 2026-09-23, le VMSS PR affiche `sku.capacity = 8` pour 11 instances, soit 11 − 3 : cohérent
> avec les trois suppressions refusées. Conséquences :
> - retirer une instance = lever le verrou, supprimer **la VM exacte** (`az vm delete`), vérifier,
>   remettre le verrou — jamais un scale-in. Toute suppression exige l'accord explicite de
>   Gabriel. Appliqué le 2026-09-25 aux sept instances retirées : verrou levé 1 min 42 s, remis
>   dans un bloc `finally` (voir « Suppression des sept instances retirées — 2026-09-25 » dans
>   `docs/CI_RUNNER_RESILIENCE.md`) ;
> - la règle d'autoscale « CPU < 20 % → −1 » du pool trusted était ce piège armé : elle a été
>   retirée du live le 2026-09-23 à 18:01Z en appliquant `infra/ci-runner/capacity.bicep`
>   (déploiement `certigo-ci-capacity-20260923180037`, what-if : 1 seul `Modify`, aucune
>   création ni suppression ; what-if suivant à 20:11Z : `NoChange`) ;
> - `pilot.bicep` n'a plus de capacité par défaut : l'opérateur passe la capacité live (voir
>   `infra/ci-runner/README.md`, « Vérifier aussi la capacité »).

**Effet de bord attendu, pas un bug.** Les verrous sont hérités. Supprimer le private
endpoint de contenu (`pe-stcertigocntz3wqbdww-blob`, dans `rg-certigo-content`) tente de
supprimer son enregistrement A dans la zone verrouillée et **échoue** avec
`ScopeLocked`. C'est voulu.

```bash
# Lever temporairement (opération délibérée).
az lock delete --name certigo-ci-cannot-delete -g rg-certigo-ci --subscription "$SUB"

# Remettre — préférer un redéploiement Bicep pour que l'IaC reste la source de vérité.
az deployment sub create --location westeurope \
  --parameters infra/params/ci-runner-auto-recovery.bicepparam --subscription "$SUB"

# Vérifier.
az lock list -g rg-certigo-ci --subscription "$SUB" -o table
```

---

## 13. Runners à la demande : extinction locale, désallocation, réveil (depuis le 2026-09-30)

Décision et risques : [`docs/adr/ADR-022-runners-ci-a-la-demande.md`](../adr/ADR-022-runners-ci-a-la-demande.md).
En une phrase : **une VM de runner s'éteint seule quand elle n'a plus rien à faire, Azure la
désalloue, et GitHub la fait redémarrer dès qu'un job l'attend.** Plus besoin de rallumer ni
d'éteindre la CI à la main (§4, §5).

| Pièce | Où | Ce qu'elle fait | Droits |
|---|---|---|---|
| Agent `certigo-idle-shutdown` | chaque VM de runner (timer systemd, 15 s) | après la période calme (PR 900 s, trusted 1 200 s) sans job, deux gardes, arrêt des services runner puis `poweroff` | root local, aucune identité, aucun appel réseau |
| `logic-certigo-ci-runner-idle-deallocation` | `rg-certigo-ci`, toutes les 5 min de 02:00 à 23:55 UTC | désalloue les instances dont le power state est **exactement** `PowerState/stopped` | `virtualMachines/read` + `deallocate/action` |
| `logic-certigo-ci-runner-wake` | `rg-certigo-ci`, webhook GitHub `workflow_job` | job `queued`/`waiting` → démarre les instances `deallocated`/`stopped` du pool désigné par les labels, en 4 passes sur 4 min | `virtualMachines/read` + `start/action` |
| Webhooks `workflow_job` | `Certigo` et `certigo-content` | poussent chaque événement de job vers le déclencheur signé | aucun secret GitHub dans Azure |

Labels → pool (versionné dans `infra/ci-runner/on-demand.config.json`, testé) : `certigo-pr` →
`vmss-certigo-pr-pilot-z1` ; `certigo-trusted` et `certigo-ci` → `vmss-certigo-runner-zonal`.
Un label PR ne réveille jamais le pool trusted.

**Ce que voit un développeur.** Premier job d'une rafale après une période calme : le job reste
`Queued` le temps du démarrage (35 à 59 s mesurés le 2026-09-30 ; ≈ 6 min pour une instance PR
sans le réglage cloud-init posé par l'installateur, `cloud_init_boot_refresh=new-instance-only`).
Les jobs suivants partent aussitôt. Un runner `offline` côté GitHub n'est **plus** une anomalie
en soi : c'est l'état normal d'un pool au repos.

### Déployer (depuis `main`, what-if d'abord)

```bash
export SUB=b8952c8c-8f72-469d-99cd-ac906da4e2fc
az deployment sub what-if --subscription "$SUB" --location westeurope \
  --parameters infra/params/ci-runner-on-demand.bicepparam
az deployment sub create --subscription "$SUB" --location westeurope \
  --name "certigo-ci-runner-on-demand-$(date -u +%Y%m%d%H%M%S)" \
  --parameters infra/params/ci-runner-on-demand.bicepparam
```

Le what-if d'un premier déploiement crée 2 rôles, 2 assignations, 2 Logic Apps et 2 alertes ;
il ne modifie ni la reprise, ni l'action group, ni aucune VM. Le déclencheur `Recurrence` de la
désallocation s'exécute une fois à la création, avant propagation du rôle : un premier run en
échec est attendu (comme pour la reprise, §11).

### Poser les webhooks GitHub

```powershell
.\infra\ci-runner\register-wake-webhooks.ps1 -SubscriptionId $env:SUB
gh api repos/gchambaud_microsoft/Certigo/hooks --jq '.[] | {id, events, active}'
gh api repos/gchambaud_microsoft/Certigo/hooks/<id>/deliveries --jq '.[0:3][] | {event, status_code, delivered_at}'
```

Le script lit l'URL signée du déclencheur dans ARM, la transmet à GitHub par l'entrée standard
de `gh api` et ne l'affiche jamais. Il refuse un endpoint joignable en IPv6 (le déclencheur
n'admet que les plages IPv4 `hooks`). Le `ping` de création doit être livré en `202`.

### Installer l'agent sur les VM (canari d'abord)

```powershell
# Une instance PR d'abord, puis toutes les instances gérées de l'inventaire.
.\infra\ci-runner\install-idle-shutdown.ps1 -SubscriptionId $env:SUB -VmName vmss-certigo-pr-pilot-z1_6e3abce4
.\infra\ci-runner\install-idle-shutdown.ps1 -SubscriptionId $env:SUB -All
.\infra\ci-runner\install-idle-shutdown.ps1 -SubscriptionId $env:SUB -All -Action status
```

La VM doit être `running`. L'installation passe par une Run Command *action* (aucune ressource
enfant, donc rien d'accumulé sous le verrou du §12), prend la période calme de son pool dans
`on-demand.config.json`, vérifie l'empreinte SHA-256 de l'agent installé et que le timer est
actif. Sur une instance PR, elle ordonne aussi `certigo-block-imds.service` avant
`cloud-init-local.service` et limite le rafraîchissement des métadonnées de cloud-init à une
nouvelle instance (`/etc/cloud/cloud.cfg.d/91-certigo-imds-blocked.cfg`) : sans ce réglage,
cloud-init attend 300 s à chaque boot un IMDS bloqué, et le runner n'est en ligne que ≈ 6 min
après le réveil au lieu de 45 s. `-Action status` affiche alors `imds_drop_in=present` et
`cloud_init_boot_refresh=new-instance-only` ; une désinstallation garde ces deux réglages. **Toute
instance ajoutée ou reconstruite doit recevoir l'agent** après son enregistrement ; sans lui,
elle reste allumée comme avant (coût, pas panne).

### Suspendre l'extinction sur une VM (maintenance)

```bash
sudo touch /etc/certigo-idle-shutdown.hold     # suspend
sudo rm /etc/certigo-idle-shutdown.hold        # reprend
journalctl -u certigo-idle-shutdown.service --since '-1h'   # décisions de l'agent
```

L'agent ne journalise rien tant qu'il voit une activité ou que la période calme court. Pour
savoir pourquoi une VM reste allumée, lire `activity=` dans la sortie de `-Action status` :
`job` (un `Runner.Worker` du vrai listener), `package-maintenance` (apt, apt-get, dpkg ou
`unattended-upgrade` exécuté par root, hors évaluation périodique des correctifs Azure) ou
`none` (la VM s'éteindra à la fin de la période
calme, `last_activity` + `QUIET_PERIOD_SECONDS`). Un `package-maintenance` qui dure sans mise à
jour en cours désigne un processus root de ce nom : `ps -eo pid,user,comm,args` le montre.

### Vérifier que tout fonctionne

```bash
WAKE="/subscriptions/$SUB/resourceGroups/rg-certigo-ci/providers/Microsoft.Logic/workflows/logic-certigo-ci-runner-wake"
DEALLOC="/subscriptions/$SUB/resourceGroups/rg-certigo-ci/providers/Microsoft.Logic/workflows/logic-certigo-ci-runner-idle-deallocation"
for WF in "$WAKE" "$DEALLOC"; do
  az rest --method get --subscription "$SUB" \
    --uri "https://management.azure.com${WF}/runs?api-version=2016-06-01&\$top=20" \
    --query "value[].{run:name,status:properties.status,start:properties.startTime}" -o table
done
az vm list -g rg-certigo-ci -d --subscription "$SUB" --query "[].{vm:name,power:powerState}" -o table
```

Un run de réveil sans pool concerné (`in_progress`, `completed`, `ping`) se termine en
`Succeeded` en quelques secondes. Un run de réveil concerné dure ≈ 4 min 30 s (quatre passes).

### Comment on est prévenu d'un échec

| Alerte | Condition | Sens |
|---|---|---|
| `alert-certigo-ci-runner-wake-failed` (sév. 1) | `RunsFailed > 0` sur 1 h | aucune instance du pool n'a démarré : un job peut attendre |
| `alert-certigo-ci-runner-idle-deallocation-failed` (sév. 2) | `RunsFailed > 3` sur 1 h | des VM arrêtées restent allouées (coût), pas une panne de CI |

Les deux sont routées vers `ag-certigo-ci-recovery`, comme la reprise : aucun nouveau
destinataire, aucune alerte de budget ou de consommation.

**Angles morts connus.** Une livraison refusée avant le déclencheur (plage IP inconnue,
panne Logic Apps) ne produit aucun run, donc aucune alerte : elle n'apparaît que dans l'onglet
« Recent Deliveries » du webhook. Remède immédiat : « Redeliver », ou relancer le job. Contrôle
mensuel des plages : `gh api meta --jq .hooks` doit être inclus dans
`githubHookSourceRanges.addressRanges` (IPv4) ; sinon, mettre à jour le fichier et redéployer.

### Rotation de l'URL signée

Régénérer la clé d'accès du Logic App invalide toutes les URL émises ; relancer ensuite
`register-wake-webhooks.ps1`, qui met à jour les deux webhooks en place :

```bash
az rest --method post --subscription "$SUB" \
  --uri "https://management.azure.com${WAKE}/regenerateAccessKey?api-version=2019-05-01" \
  --body '{"keyType":"Primary"}'
```

### Rollback (sans lever le verrou)

```powershell
# 1. Rallumer toutes les instances (reprise, §11), puis retirer l'agent (il exige une VM allumée).
$recovery = "/subscriptions/$env:SUB/resourceGroups/rg-certigo-ci/providers/Microsoft.Logic/workflows/logic-certigo-ci-runner-recovery"
az rest --method post --subscription $env:SUB --uri "https://management.azure.com$recovery/triggers/Daily_after_the_governance_teardown_window/run?api-version=2016-06-01"
.\infra\ci-runner\install-idle-shutdown.ps1 -SubscriptionId $env:SUB -All -Action uninstall
# 2. Retirer les webhooks et désactiver les deux Logic Apps (réversible).
$workflows = "/subscriptions/$env:SUB/resourceGroups/rg-certigo-ci/providers/Microsoft.Logic/workflows"
.\infra\ci-runner\register-wake-webhooks.ps1 -SubscriptionId $env:SUB -Remove
az resource update --ids "$workflows/logic-certigo-ci-runner-wake" --set properties.state=Disabled --subscription $env:SUB
az resource update --ids "$workflows/logic-certigo-ci-runner-idle-deallocation" --set properties.state=Disabled --subscription $env:SUB
```

Attendre la fin de la reprise (≈ 8 min, §11) avant l'étape `uninstall`. La suppression complète
des Logic Apps, alertes, assignations et rôles exige de lever le verrou du §12, comme pour la
reprise.

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

> **Paramètres confirmés (4 septembre 2026)** : RG `RG-CERTIGO-CI` · VMSS trusted
> `vmss-certigo-runner-zonal` (capacité 2, zones 1 et 2) · VMSS PR
> `vmss-certigo-pr-pilot-z1` (capacité 1, zone 1) · subscription
> `b8952c8c-8f72-469d-99cd-ac906da4e2fc` · f55 + be5 + bbf liés explicitement ·
> `22f7fb52` absent · `4153d1dd` externe · `4596a9d5` interdit ·
> **labels disjoints, aucun chevauchement**.
