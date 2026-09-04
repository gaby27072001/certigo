# Pilote CI ACA Jobs — activation, observation et rollback

## Statut

Le pilote ADR-018 est **livré mais désactivé par défaut**. Cette procédure ne
constitue pas une autorisation de déploiement.

- Les quatre checks requis existants restent sur
  `[self-hosted, Linux, X64, certigo-pr]`.
- La source du canari reste dans
  `.github/workflows-disabled/ci-aca-pilot.yml` : GitHub Actions ne l'enregistre
  pas et elle ne peut pas être dispatchée. Une PR d'activation séparée devra la
  déplacer sous `.github/workflows/`, après fermeture de tous les NO-GO.
- Même après ce déplacement, le workflow reste manuel, non requis et bloqué tant
  que la variable dépôt `CERTIGO_ACA_PILOT_ENABLED` n'existe pas avec la valeur
  exacte `true`.
- Le job ACA n'existe que si `pilotEnabled=true`; le template vaut `false` par
  défaut.
- Aucun runner VMSS, déploiement, release ou environnement de production ne
  change de route.

Le 4 septembre 2026 à `03:15Z` (environ `04:15` heure locale observée), les
runners 27 (`certigo-trusted`) et 28 (`certigo-pr`) étaient simultanément
`offline`, et les checks de la PR #366 attendaient un runner. Cette récidive
montre que deux labels correctement séparés ne fournissent pas à eux seuls une
capacité indépendante. Le pilote ACA utilise un plan de calcul, un label et un
lifecycle distincts des VMSS. Il n'est cependant **pas** un secours de la CI
complète : il ne couvre que quatre validations stateless et ne reçoit jamais un
job trusted ou de production.

## Contrat du pilote

| Surface | Contrat |
|---|---|
| Workloads | `ci-content`, `ci-migration-registry`, `lint-workflows`, `ci-project-state` |
| Déclenchement futur | Après PR d'activation : `workflow_dispatch` depuis `main`, PR interne ouverte vers `main` |
| Label | `self-hosted, Linux, X64, certigo-pr-aca` exclusivement |
| Capacité | min 0, max 2, poll 30 s, un replica et une complétion, retry 0 |
| Durée | 30 minutes maximum |
| Identité runner | aucune identité managée, aucun OIDC, aucun secret workflow |
| Réseau | environnement ACA public dédié, aucun VNet/peering/RFC1918 privé |
| Stockage | `EmptyDir` uniquement pour la configuration JIT, aucun volume persistant |
| Auth contrôle | GitHub App dédiée; clé visible seulement par KEDA et l'init container |
| Cycle | configuration JIT GitHub, runner éphémère, un seul job, destruction |
| Logs | workspace Log Analytics dédié, rétention 30 jours |

Le fallback normal reste le VMSS : les workflows requis n'ont pas été modifiés.
Pendant une panne simultanée des VMSS, le pilote activé peut produire une preuve
indépendante pour les quatre workloads, mais ne débloque ni les gates trusted,
ni les déploiements, ni les releases.

## Prérequis bloquants avant tout provisionnement

Tous les points suivants doivent être prouvés. Une absence est un **NO-GO**.

1. **Image publique immutable linux/amd64**
   - construire `infra/ci-runner/aca/image/Dockerfile`;
   - publier par digest;
   - produire SBOM et provenance;
   - vérifier la signature et le scan sans finding critique/haut non accepté;
   - renseigner une référence exacte `registry/path@sha256:<64 hex>`.
2. **GitHub App dédiée au seul dépôt `gchambaud_microsoft/Certigo`**
   - webhooks désactivés;
   - `Metadata: read`, `Actions: read`, `Administration: read/write`;
   - aucune permission contents write, secrets, environments ou deployments;
   - clé privée stockée hors dépôt, rotation et révocation testées;
   - App ID, Installation ID et runner group ID confirmés.
3. **Gouvernance Azure**
   - abonnement et RG explicitement confirmés;
   - providers `Microsoft.App`, `Microsoft.OperationalInsights` et
     `Microsoft.Insights` déjà enregistrés;
   - aucun enregistrement automatique de provider;
   - tout apply est incrémentiel et relu par un humain après `what-if`.
4. **GitHub**
   - le label `certigo-pr-aca` n'existe sur aucun runner persistant;
   - la variable `CERTIGO_ACA_PILOT_ENABLED` reste absente ou `false`;
   - aucun check ACA n'est requis par la protection de branche.

Le poste ayant produit ce livrable ne disposait pas d'un moteur Docker actif,
d'une image Certigo publiée/attestée, ni d'une GitHub App/variable d'activation
prouvée. Un `what-if` activé **structurel** a validé le schéma et les permissions
avec une clé RSA éphémère, des IDs synthétiques et une image publique épinglée;
il ne prouve ni le runtime, ni l'App, ni la supply chain Certigo. Aucun apply
Azure n'est autorisé à partir de cet état.

## Permissions minimales et OIDC

Le **runner de PR n'utilise pas OIDC** : le workflow pilote n'accorde jamais
`id-token: write`, ne référence aucun environnement et ne lance pas
`azure/login`.

Si le déploiement du plan de contrôle est automatisé plus tard, utiliser une
identité distincte `id-certigo-aca-pilot-provision` avec une seule fédération :

```text
repo:gchambaud_microsoft/Certigo:environment:ci-aca-pilot-provisioning
```

Le workflow de provisionnement doit être séparé de `ci-aca-pilot.yml`, chargé
depuis `main`, protégé par reviewers et être le seul job avec `id-token: write`.
Son rôle custom est limité à `RG-CERTIGO-CI` et aux lectures/deployments ARM,
`Microsoft.App/managedEnvironments`, `Microsoft.App/jobs`,
`Microsoft.OperationalInsights/workspaces` et
`Microsoft.Insights/diagnosticSettings`. Il exclut explicitement RBAC,
Compute/VMSS, Network, Key Vault, environnements applicatifs et toute action de
suppression. Le bootstrap de cette identité et du rôle reste une opération
humaine PIM séparée; il n'est pas effectué par ce pilote.

## Prévol obligatoire, sans mutation

Depuis la racine du dépôt :

```powershell
az account show --subscription <SUBSCRIPTION_ID>
az bicep build --file infra\ci-runner\aca\main.bicep --stdout > $null

pwsh -NoProfile -File infra\ci-runner\aca\preflight.ps1 `
  -SubscriptionId <SUBSCRIPTION_ID> `
  -ResourceGroupName RG-CERTIGO-CI `
  -Location westeurope `
  -EvidenceDirectory <PRIVATE_EVIDENCE_DIRECTORY>
```

Le prévol désactivé doit retourner :

- validation `Provider`, jamais seulement `ProviderNoRbac`;
- exactement trois créations si le plan d'observabilité n'existe pas :
  workspace, environnement ACA et diagnostic setting;
- zéro `Modify`, `Delete`, `Deploy` ou `Ignore` portant un nom pilote;
- zéro `Microsoft.App/jobs`;
- toutes les ressources existantes du RG classées `Ignore` seulement parce
  qu'elles sont hors template incrémentiel.

Avant le premier apply activé, rejouer le même script avec les vrais
prérequis :

```powershell
pwsh -NoProfile -File infra\ci-runner\aca\preflight.ps1 `
  -SubscriptionId <SUBSCRIPTION_ID> `
  -ResourceGroupName RG-CERTIGO-CI `
  -Location westeurope `
  -RunnerImage '<PUBLIC_IMAGE>@sha256:<DIGEST>' `
  -GitHubAppId '<APP_ID>' `
  -GitHubAppInstallationId '<INSTALLATION_ID>' `
  -GitHubAppPrivateKeyPath '<PRIVATE_PEM_PATH>' `
  -EnablePilot `
  -EvidenceDirectory <PRIVATE_EVIDENCE_DIRECTORY>
```

Le résultat activé doit ajouter exactement
`Microsoft.App/jobs/job-certigo-pr-aca`, sans autre création ou mutation. Le
fichier PEM et les paramètres temporaires ne doivent jamais être copiés dans le
dépôt, un log, un ticket ou une ligne de commande. `preflight.ps1` protège puis
supprime son fichier de paramètres temporaire.

## Séquence d'activation

1. Faire relire le rapport `what-if` activé et le digest d'image par un second
   opérateur.
2. Déployer le template en mode **Incremental** uniquement, avec les mêmes
   paramètres approuvés et un canal secret protégé. Ne jamais utiliser
   `Complete`.
3. Vérifier dans Azure :
   - job `job-certigo-pr-aca`, identity `None`;
   - min 0, max 2, retry 0, timeout 1800;
   - aucune configuration VNet, registry credential ou volume persistant;
   - logs console et système présents.
4. Vérifier dans GitHub qu'aucun runner persistant ne porte
   `certigo-pr-aca`.
5. Créer la variable dépôt `CERTIGO_ACA_PILOT_ENABLED=false`.
6. Dans une PR d'activation séparée, déplacer uniquement
   `.github/workflows-disabled/ci-aca-pilot.yml` vers
   `.github/workflows/ci-aca-pilot.yml`. Le validator de `main` doit déjà
   reconnaître `certigo-pr-aca`; actionlint et la policy sécurité doivent passer.
7. Après merge de cette PR d'activation, vérifier que le workflow n'est pas un
   check requis, puis passer la variable à `true` pour une fenêtre surveillée.
8. Dispatcher `ACA runner pilot (disabled by default)` sur une PR interne, un
   workload à la fois, dans l'ordre ADR-018.
9. Après chaque exécution, remettre la variable à `false` pendant la revue des
   logs, du runner éphémère et du coût.

La variable ne doit être activée que lorsque les VMSS sont sains. Le pilote
mesure une capacité alternative; il ne remplace pas l'incident response VMSS.

## Observabilité

### Lifecycle et erreurs ACA

```kusto
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(24h)
| where EnvironmentName_s == "cae-certigo-ci-aca-pilot"
| project TimeGenerated, ContainerGroupName_g, ContainerImage_s, Log_s
| order by TimeGenerated desc
```

```kusto
ContainerAppSystemLogs_CL
| where TimeGenerated > ago(24h)
| where EnvironmentName_s == "cae-certigo-ci-aca-pilot"
| where Log_s has_any ("Error", "Failed", "Timeout", "ImagePull")
| project TimeGenerated, ContainerAppName_s, Log_s
| order by TimeGenerated desc
```

Les marqueurs `runner_start`, `runner_exit`, `jit_config_prepared` et
`CERTIGO_ACA_METRIC` doivent exister pour chaque exécution. Corréler avec
`workflow_job.created_at`/`started_at` afin de publier P50/P95/P99 de file,
cold-start et durée. Une exécution sans `runner_exit`, un runner ACA encore
enregistré après son TTL ou deux jobs servis par le même runner est un no-go.

### Capacité et coût

- Suivre exécutions actives, échecs, OOM, timeout et pull d'image.
- Alerter à concurrence 2 prolongée ou file P99 >= 300 s.
- Filtrer Azure Cost Management par tags
  `workload=github-actions-runner`, `env=ci-pilot` et par les trois IDs pilotes.
- Inclure compute ACA, Log Analytics, registry, egress et coût total CI.
- Comparer aux 242,06 USD/30 jours et au plafond 275 USD de l'ADR.

Une alerte de disponibilité indépendante doit comparer toutes les cinq minutes :

1. nombre de runners VMSS `online` par classe;
2. jobs GitHub `queued` par label;
3. démarrages/exécutions ACA;
4. erreurs du scaler et quota/capacité ACA.

Si les deux classes VMSS sont offline et qu'une file existe, l'alerte est
critique même si ACA traite un des quatre workloads : la CI complète reste
dégradée.

## No-go et rollback

Déclencher le rollback au premier signal de l'ADR-018 ou si les logs/couts ne
sont pas disponibles.

1. Positionner immédiatement `CERTIGO_ACA_PILOT_ENABLED=false`.
2. Ne dispatcher aucun nouveau canari.
3. Laisser terminer les exécutions `busy`; ne jamais tuer un job en cours.
4. Confirmer que les quatre workflows requis continuent à cibler
   `[self-hosted, Linux, X64, certigo-pr]`.
5. Vérifier qu'aucun runner ACA n'est encore `online` ou `busy`.
6. Si le scaler doit être arrêté, supprimer **uniquement**
   `/resourceGroups/RG-CERTIGO-CI/providers/Microsoft.App/jobs/job-certigo-pr-aca`
   après un nouveau preflight, un inventaire exact et une approbation humaine.
   Ne jamais cibler un VMSS, une VM, un réseau ou un runner existant.
7. Conserver workspace/environnement/logs pendant l'analyse et la rétention
   approuvée. Leur suppression relève d'un changement séparé.

`pilotEnabled=false` empêche la création initiale du job; en mode ARM
incrémentiel, il ne supprime pas un job déjà créé. Le rollback opérationnel
commence donc toujours par la variable GitHub, puis par la suppression explicite
et approuvée du seul job si nécessaire.
