# ADR-022 — Runners CI à la demande : extinction locale, désallocation Azure, réveil par webhook

| Champ | Valeur |
|---|---|
| **ADR** | 022 |
| **Statut** | Accepté le 2026-09-30 ; mise en service et mesures : `docs/FINOPS.md`, « On-demand runners (ADR-022) » |
| **Date** | 2026-09-30 |
| **Décision** | Les VM de runner s'éteignent elles-mêmes après une période calme sans job ; un Logic App désalloue les VM dont l'OS est arrêté ; un second Logic App les redémarre sur webhook GitHub `workflow_job`. |
| **Complète** | ADR-018 (runners éphémères, toujours la cible durable) ; ne remplace ni la reprise de 01:30 UTC ni le verrou `CanNotDelete`. |
| **Mandat** | Mission « Réduction coût CI » validée par Gabriel le 2026-09-30 : réduire le coût CI sans casser la CI ni affaiblir la frontière de confiance. |

## Contexte mesuré (2026-09-30)

- `rg-certigo-ci` coûte ≈ 555 USD/30 j, soit 65 % de la facture Certigo (audit Cost Management
  du 2026-09-30). Pool trusted ≈ 265 USD (VM 172, Defender 32), pool PR ≈ 279 USD (VM 156,
  Defender 28). Le compute est facturé à l'heure de VM allumée (0,138 USD/h,
  `Standard_D2ads_v6`), Defender for Servers aussi ; une VM désallouée ne coûte que son disque.
- Depuis le 2026-09-23, la reprise de 01:30 UTC rallume les six instances chaque nuit : ≈ 140
  VM-heures/jour, pour **2,14 runner-heures/jour de travail PR et 0,95 de travail trusted**
  (1 860 et 531 jobs du 2026-09-24 12:00 au 2026-09-30 11:00 UTC, API GitHub des deux dépôts).
  L'activité tient entre 08:00 et 18:00 UTC, en 21 rafales séparées par plus de 20 minutes.
- Au démarrage d'une instance PR, la datasource Azure de cloud-init rafraîchit ses métadonnées à
  chaque boot et réessaie l'IMDS jusqu'à une échéance de 300 s ; l'IMDS y est bloqué (NSG et
  `certigo-block-imds.service`). Mesuré le 2026-09-30 sur `6e3abce4` : boot 01:31:31, dernier
  essai IMDS 01:36:43, runner démarré 01:36:44, soit **5 min 13 s perdues à chaque boot** (et
  ~7 min 30 s d'opération `start`, voir `docs/runbooks/CI_RUNNERS.md` §11). Des refus immédiats
  au lieu de paquets jetés n'y changent rien : même échéance, 5 min 14 s (16:02:05 → 16:07:19).
- Décisions du dépôt à respecter : aucun credential GitHub dans Azure ; aucune identité
  d'automatisation avec `runCommand` ; la reprise ne peut pas désallouer ; les deux pools
  restent disjoints ; un scale-in sous le verrou tue les instances visées.

## Décision

Trois pièces, chacune sans credential GitHub :

1. **La VM décide de l'inactivité** (`infra/ci-runner/idle-shutdown.sh`, timer systemd de 15 s,
   installé par Run Command *action*, donc sans ressource résiduelle sous le verrou). Période
   calme réinitialisable de **900 s pour le pool PR et 1 200 s pour le pool trusted** (≥ les
   300 s du contrat du contrôleur, et PR avant trusted comme `scaleInOrder`), puis deux gardes,
   puis une garde finale : arrêt des services `actions.runner.*` (le listener ferme sa session),
   attente bornée (90 s) de la fin de tout `Runner.Worker`, relecture de la maintenance de
   paquets, `systemctl poweroff`. N'est une activité qu'un signal que le code d'une PR ne peut
   pas imiter : un `Runner.Worker` **enfant du vrai listener**, c'est-à-dire du `Runner.Listener`
   petit-enfant du processus principal que systemd attribue au service runner
   (`runsvc.sh` → `node` → `Runner.Listener`, mesuré sur les deux pools le 2026-09-30) — un nom
   de processus se choisit, une filiation depuis ce MainPID non —, ou une maintenance de paquets
   **exécutée par root** (UID effectif 0 : `apt`, `apt-get`, `dpkg` ou une exécution
   d'`unattended-upgrade`). Le veilleur permanent
   `unattended-upgrade-shutdown --wait-for-signal`, présent sur toutes les VM Ubuntu et que le
   noyau nomme lui aussi `unattended-upgr`, n'en est pas une : il est reconnu à sa ligne de
   commande (compté à tort, il empêchait toute extinction, mesuré le 2026-09-30 sur le canari).
   Jamais d'extinction entre 01:15 et 01:50 UTC (reprise), ni d'une machine sans service runner
   (provisionnement). Sur les instances PR, l'installateur ordonne aussi
   `certigo-block-imds.service` avant `cloud-init-local.service` (l'IMDS est refusé dès le début
   du boot) et limite le rafraîchissement des métadonnées de cloud-init à une nouvelle instance
   (`updates.network.when: [boot-new-instance]`) : la configuration réseau déjà rendue reste
   (elle reconnaît la carte par son adresse MAC, que la désallocation conserve), et le runner est
   en ligne 45 s après la mise en file du job au lieu de 6 min (mesuré le 2026-09-30).
2. **Azure désalloue ce qui est déjà arrêté** (`logic-certigo-ci-runner-idle-deallocation`,
   toutes les 5 minutes de 02:00 à 23:55 UTC, jamais pendant le teardown MCAPS ni la reprise).
   Il ne désalloue que les instances non exclues dont le power state est exactement
   `PowerState/stopped`, relues juste avant. Il ne peut pas tuer un job : l'OS de la VM s'est
   déjà arrêté. Rôle : `virtualMachines/read` + `deallocate/action`.
3. **GitHub pousse la demande** (`logic-certigo-ci-runner-wake`, déclencheur HTTP signé SAS,
   restreint aux plages IPv4 `hooks` de GitHub). Pour un job `queued` ou `waiting` des dépôts de
   l'inventaire, les labels choisissent le pool (`certigo-pr` → PR ; `certigo-trusted` ou
   `certigo-ci` → trusted). Le workflow démarre toutes les instances non exclues du pool qui sont
   `deallocated` ou `stopped`, en quatre passes (0, +60, +150, +240 s) pour rattraper une VM qui
   finissait de s'éteindre ou qu'une désallocation concurrente visait, puis échoue bruyamment si
   aucune instance n'est `running`/`starting`. Rôle : `virtualMachines/read` + `start/action`.

La frontière de confiance ne bouge pas : ni label, ni identité de VM, ni réseau, ni image ne
change ; le mapping label → pool est versionné et testé (un label PR ne réveille jamais le pool
trusted). Les deux nouvelles identités sont distinctes de celle de la reprise, qui ne reçoit
toujours pas `deallocate`.

## Pourquoi ce découpage, et pas le contrôleur central prévu

`docs/runbooks/CLOUD_LEAST_PRIVILEGE.md` (« Runners : automatisation sûre ») prévoyait un
contrôleur unique lisant l'état `busy` GitHub, sous lease Blob et compare-and-swap. Il exige
un credential GitHub dans Azure (décision contraire du dépôt) et un état persistant. Ici :

| Exigence du contrôleur prévu | Où elle est tenue |
|---|---|
| quiet period 5 min resettable, `busy=false` | sur la VM, là où `busy` est exact (≥ 900 s) |
| deux gardes puis garde finale relisant `busy` | sur la VM (`REQUIRED_GUARDS=2`, arrêt du listener puis relecture) |
| zéro job en file | un runner en ligne et inactif ne peut pas coexister avec un job en file sur ses labels : GitHub le lui attribue |
| pilote PR avant trusted | période calme PR < trusted |
| jamais deux désallocations concurrentes, lease | inutile : on ne désalloue qu'une VM dont l'OS est arrêté, aucune désallocation ne peut interrompre un job |
| réarmement sur nouvelle activité | webhook `workflow_job` → réveil du pool |
| identité `read` + `start` + `deallocate` aux scopes exacts | deux identités séparées, portée `rg-certigo-ci` (les membres d'un VMSS Flexible sont des VM du resource group, pas des enfants du VMSS) |

## Options écartées

| Option | Raison |
|---|---|
| Autoscale CPU ou désallocation sur métrique CPU | ignore `busy` : une publication de contenu peu gourmande en CPU serait tuée ; retiré du dépôt le 2026-09-23 pour cette raison |
| Désallocation à heure fixe (nuit/week-end) | ≈ 30 % d'économie seulement, et tue les jobs en cours sans garde locale |
| Contrôleur central avec PAT ou GitHub App | contredit la décision « aucun credential GitHub dans Azure » ; état et lease à héberger |
| Réduire le pool PR de 4 à 2 instances | une instance désallouée ne coûte que son disque (5,89 USD/mois) ; la supprimer exige de lever le verrou et retire de la capacité de rafale (41 % de jobs non démarrés le 2026-09-11 avec 4 runners) |
| Plancher d'une VM chaude par pool | ≈ 100 USD/mois par pool pour éviter un démarrage à froid d'environ une minute |
| Vérifier la signature HMAC GitHub | impossible dans un Logic App Consumption sans code ; une Function ou APIM ajouterait un service et un secret. Compensé par la signature SAS de l'URL et la restriction aux plages `hooks` |

## Risques résiduels, dits franchement

1. **Attribution pendant l'arrêt.** GitHub ne garantit pas qu'un runner persistant qui s'arrête
   ne reçoive plus de job ; seuls des runners éphémères l'éliminent (ADR-018). Un job attribué
   dans la fraction de seconde entre la dernière lecture et l'arrêt du listener est annulé par cet
   arrêt (le listener annule son job en s'arrêtant) : aucune relecture ne peut le sauver, l'agent
   laisse seulement au worker jusqu'à 90 s pour rendre compte de l'annulation. Estimé
   sur les mesures du 2026-09-30 (≈ 3,5 rafales/jour, ≈ 24 extinctions/jour, fenêtre ≈ 0,2 s) :
   de l'ordre d'un job tous les dix ans. Le job annulé se relance à la main.
2. **Livraison de webhook perdue.** GitHub ne relivre pas automatiquement. Un job dont tous les
   événements de réveil sont perdus attend le prochain événement de son pool ou la reprise de
   01:30 UTC ; un job resté en file plus de 24 h échoue. Remède : « Redeliver » dans les
   paramètres du webhook, ou relancer le job. Le premier job d'une rafale n'est isolé que pour
   les workflows planifiés à un seul job.
3. **Plages GitHub.** Si GitHub ajoute une plage `hooks`, les livraisons qui en partent sont
   refusées (403) : le réveil se dégrade sans alerte Azure. Contrôle : `gh api meta --jq .hooks`
   comparé à `infra/ci-runner/on-demand.config.json` (procédure dans `docs/runbooks/CI_RUNNERS.md`
   §13). L'endpoint Logic Apps n'a pas d'adresse IPv6 (mesuré le 2026-09-30), donc les plages
   IPv6 de GitHub ne s'appliquent pas ; `register-wake-webhooks.ps1` le revérifie.
4. **Fuite de l'URL signée.** Elle ne permet que de démarrer des VM existantes (coût borné au
   régime actuel) et de consommer des exécutions Logic Apps, depuis les seules plages GitHub.
   Remède : régénérer les clés d'accès du Logic App puis relancer `register-wake-webhooks.ps1`.
5. **Démarrage à froid.** Premier job d'une rafale : ≈ 1 minute côté trusted ; côté PR ≈ 1 minute
   une fois l'ordre IMDS corrigé, ≈ 6 minutes sans. Simulation sur les jobs réels (démarrage de
   1,5 min) : attente p90 ≈ 90 s pour le pool PR.
6. **Instances futures.** Une instance créée ou reconstruite n'a pas l'agent tant que
   `install-idle-shutdown.ps1` n'a pas été exécuté : elle reste allumée comme aujourd'hui (coût,
   pas panne). L'étape est dans la procédure d'ajout d'instance.
7. **Teardown MCAPS de 00:46 UTC** : inchangé ; il peut toujours interrompre un job long.

## Effet attendu

Rejeu des 6 jours de jobs réels (réveil de tout le pool, démarrage de 1,5 min, reprise de
01:30 incluse) : pool PR ≈ 7 VM-h/jour au lieu de 96 ; pool trusted ≈ 5 VM-h/jour au lieu de 48.
Chiffrage et mesures après activation : `docs/FINOPS.md`, « Runners à la demande ».

## Mise en service et retour arrière

Procédure, vérifications et rollback : `docs/runbooks/CI_RUNNERS.md` §13. Le retour arrière
complet sans lever le verrou : désactiver les deux Logic Apps, retirer les webhooks,
désinstaller l'agent, puis déclencher la reprise pour rallumer toutes les instances.

## Références

- `infra/ci-runner/idle-shutdown.sh`, `infra/ci-runner/test-idle-shutdown.sh`
- `infra/ci-runner/on-demand.bicep`, `infra/ci-runner/modules/runnerOnDemand.bicep`,
  `infra/ci-runner/on-demand.config.json`, `infra/params/ci-runner-on-demand.bicepparam`
- `infra/ci-runner/install-idle-shutdown.ps1`, `infra/ci-runner/register-wake-webhooks.ps1`
- `infra/tests/ci-runner-on-demand.test.mjs`, `infra/tests/ci-runner-on-demand-simulation.test.mjs`
- [Compute throttling limits](https://learn.microsoft.com/azure/virtual-machines/compute-throttling-limits)
- [Secure access for Logic Apps, restrict inbound IP addresses](https://learn.microsoft.com/azure/logic-apps/logic-apps-securing-a-logic-app)
- [GitHub webhook events: `workflow_job`](https://docs.github.com/webhooks/webhook-events-and-payloads#workflow_job)
