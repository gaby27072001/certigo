# Résilience des runners GitHub Actions

## Objectif et architecture

Les workflows Linux ciblent un **pool** et jamais une machine précise. Par défaut, le
pool est sélectionné avec les labels :

```json
["self-hosted", "Linux", "X64", "certigo-ci"]
```

Au moins deux runners en ligne doivent partager ces labels. GitHub Actions attribue
alors chaque job à n'importe quelle instance disponible : l'arrêt d'une VM ne bloque
plus la CI. Les protections existantes restent inchangées :

- les PR de fork ne peuvent pas exécuter de code sur les runners persistants ;
- les PR internes restent soumises à l'environnement `pr-ci` ;
- les déploiements et releases conservent leurs environnements (`dev`, `staging`,
  `prod`, `beta`, `github-pages`) et leurs approbations ;
- les runners hébergés par GitHub sont durablement indisponibles ; aucun fallback n'est
  configuré ou accepté.

## Capacité et stratégie de cycle de vie

Chaque VM Linux est une `Standard_D4s_v5` qui exécute un seul job à la fois : deux VMs
`online` offrent donc deux slots de CI concurrents. Il n'y a pas d'autoscaling. Une file
d'attente persistante impose de démarrer les deux VMs ou de planifier une troisième
reconstruction ; ne pas contourner ce signal en diminuant le niveau de redondance.

La stratégie normale est **démarrer les deux VMs avant une session CI, attendre deux
runners `online`, puis déallouer les deux VMs seulement quand tous sont `busy: false`**.
Pendant une session, conserver les deux slots permet à l'un d'absorber une panne ou une
maintenance de l'autre. Les commandes sont strictement opérateur dans
[`docs/runbooks/CI_RUNNERS.md`](./runbooks/CI_RUNNERS.md) : l'IaC et les scripts locaux ne
démarrent, n'arrêtent, ne déallouent ni ne détruisent aucune ressource live.

La release Android reste volontairement sur le pool self-hosted redondé. Elle peut
utiliser l'identité managée Azure du runner pour lire Key Vault.

## Politique des pull requests

Les workflows PR sont chargés depuis `main` avec `pull_request_target`. Pour une PR
interne, ils vérifient `head.repo.full_name == github.repository`, puis checkoutent
explicitement le SHA de tête avant toute exécution. Une PR de fork n'est pas supportée :
`fork-pr-policy.yml`, lui aussi chargé depuis `main`, n'effectue aucun checkout et fait
échouer `Fork PR policy / Required gate`. Ce contexte requis empêche tout faux vert lié
aux autres jobs non applicables, sans exécuter une seule instruction du fork.

## Actions d'infrastructure externes

Ces opérations modifient Azure ou GitHub et ne peuvent pas être prouvées par un commit :

1. Inventorier les runners et les VM :

   ```bash
   az vm list -g rg-certigo-ci -o table
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '.runners[] | {name,status,busy,labels:[.labels[].name]}'
   ```

2. Conserver au moins deux VM dans `snet-runners` ; toute nouvelle instance ou
   reconstruction utilise `infra/ci-runner/runner.bicep` et l'accès NAT décrit dans
   `infra/ci-runner/README.md`.
3. Installer les prérequis des workflows, enregistrer chaque runner avec le label
   commun `certigo-ci`, et attribuer les mêmes droits minimaux à son identité managée
   lorsque le runner doit exécuter `release-android`.
4. Vérifier qu'au moins deux runners en ligne partagent tous les labels du pool :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '[.runners[] | select(.status == "online") | select(any(.labels[]; .name == "certigo-ci"))] | length'
   ```

   La valeur attendue est `2` ou plus.

Conserver comme preuve la sortie des deux inventaires, les noms des runners, leurs
labels, la date et l'URL du drill décrit ci-dessous.

## Bootstrap idempotent des runners

Le dépôt versionne le modèle de reconstruction et le bootstrap, mais ne réconcilie jamais
une VM runner active : le bootstrap reste donc une procédure opérateur. Pour éviter les
dérives, appliquer toujours le bootstrap de façon **idempotente** sur chaque VM du pool
(`vm-certigo-runner`, `vm-certigo-runner-2`) :

1. installer ou vérifier le socle versionné (`git`, `curl`, `jq`, `zip`, `unzip`, `xz`,
   `sudo`, le binaire GitHub runner et Azure CLI) ; les SDK de workload (Node, .NET,
   Flutter/Dart, Java/Android, Bicep) sont épinglés et provisionnés par les workflows ;
2. vérifier que le service `actions.runner.*` existe et redémarre automatiquement ;
3. réappliquer le label personnalisé `certigo-ci` (GitHub ajoute `self-hosted`, `Linux` et
   `X64`) ;
4. tester la connectivité sortante via la NAT Gateway avant d'approuver une PR.

Le compte de service `runner` n'a pas de privilège administrateur général. Son allow-list
`sudo` est limitée à `apt-get update`, à l'installation exacte de `unzip zip jq xz-utils`
requise par les workflows, et au redémarrage sans argument de son unique service runner.
Toute installation hors liste, modification système ou réenregistrement est réalisée par le
compte administrateur break-glass.

Les commandes exactes de cycle de vie et de dépannage restent dans
[`docs/runbooks/CI_RUNNERS.md`](./runbooks/CI_RUNNERS.md).

## Sonde quotidienne de santé du pool

En plus du drill manuel, conserver une **sonde quotidienne** légère exécutée par
l'opérateur (ou par une automation externe) pour détecter tôt un runner cassé :

```bash
gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | {name,status,busy,labels:[.labels[].name]}'
az vm list -g RG-CERTIGO-CI --show-details \
  --query "[].{Nom:name, Etat:powerState}" -o table
az network nat gateway show -g rg-certigo-ci -n nat-certigo
az network vnet subnet show -g rg-certigo-ci --vnet-name vnet-certigo-ci \
  -n snet-runners --query natGateway.id -o tsv
df -h
```

Points à vérifier :

- deux runners `online` portant `certigo-ci` ;
- deux VMs `VM running` avant usage ou `VM deallocated` hors session ;
- NAT Gateway et association du sous-réseau intactes ;
- espace disque suffisant sur chaque runner (conserver une marge opérationnelle pour
  Flutter, .NET, Android SDK et artefacts de build).

La sonde `infra/ci-runner/health-probe.sh` est non destructive : elle teste les endpoints,
les versions des commandes et l'espace disque, affiche son résumé, puis l'ajoute à
`GITHUB_STEP_SUMMARY` lorsque cette variable est fournie. Elle retourne non-zéro en cas
d'échec. La lancer avec `bash infra/ci-runner/health-probe.sh` depuis le runner après
provisioning de ses SDK ; les tests locaux `test-health-probe.sh` emploient des commandes
factices et n'appellent aucun service live.

## Vérification de checksum et de provenance

Toute installation ou rotation d'outillage runner doit **vérifier la provenance** des
binaires téléchargés :

- **actionlint** : version épinglée dans `lint-workflows.yml` ;
- **Bicep CLI** : version épinglée dans `ci-infra.yml` ;
- **OSV-Scanner** : version + SHA256 officiel déjà vérifiés dans
  `dependency-vuln-scan.yml`.

Pour tout nouvel outil ajouté au bootstrap runner, documenter la source officielle, le
checksum attendu et la commande de vérification avant mise en service.

## État versionné et preuve opérationnelle existante

Le code fournit désormais :

- `infra/ci-runner/network.bicep` pour l'egress partagé ;
- `infra/ci-runner/runner.bicep` pour reconstruire une VM/NIC/disque/identité ;
- `infra/ci-runner/bootstrap.sh` pour installer et enregistrer le runner de manière
  idempotente, avec version et SHA-256 épinglés ;
- `.github/workflows/runner-health.yml` pour le probe quotidien.

Preuve externe existante à conserver sans la réinterpréter comme une exécution de ce
changement : le drill
[31090379901](https://github.com/gchambaud_microsoft/Certigo/actions/runs/31090379901)
a été réalisé avec `vm-certigo-runner` hors ligne ; `vm-certigo-runner-2` a pris le job,
puis les deux runners ont été remis en ligne. Le disque primaire a aussi été nettoyé à
**12 GB libres**. Le probe quotidien impose un plancher de 10 Gio.

Un complément externe du 2026-08-06 confirme aussi que l'identité système de
`vm-certigo-runner-2` (`principalId`
`2c3a78ab-3c16-4eef-9cfb-f763d0fc699c`) a reçu uniquement le rôle
`Key Vault Secrets User` au scope exact de `kv-certigo-dev-bk3j5j`. Cette preuve couvre
le runner secondaire actuel ; la procédure ci-dessous reste obligatoire pour chaque
runner reconstruit.

## Reconstruction reproductible d'un runner

Ces opérations Azure/GitHub sont externes au commit. Toujours garder l'autre runner
`online` pendant la reconstruction.

1. Capturer l'inventaire et une version d'image immuable :

   ```bash
   az vm list -g rg-certigo-ci -d -o table
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '.runners[] | {id,name,status,busy,labels:[.labels[].name]}'
   IMAGE_VERSION="$(az vm image list -l westeurope \
     --publisher Canonical --offer ubuntu-24_04-lts --sku server \
     --all --query '[-1].version' -o tsv)"
   printf 'Pinned image: %s\n' "$IMAGE_VERSION"
   ```

2. Pour une **nouvelle** instance, ou après suppression explicite de l'ancienne VM,
   vérifier puis appliquer l'IaC. Ne jamais cibler le nom d'une VM vivante :

   ```bash
   RUNNER_NAME=vm-certigo-runner-3
   SSH_KEY="$HOME/.ssh/${RUNNER_NAME}-$(date +%Y%m%d)"
   ssh-keygen -t ed25519 -f "$SSH_KEY" -C "${RUNNER_NAME}-break-glass"
   az deployment group what-if -g rg-certigo-ci \
     --template-file infra/ci-runner/runner.bicep \
     --parameters runnerName="$RUNNER_NAME" imageVersion="$IMAGE_VERSION" \
                  availabilityZone=3 \
                  adminSshPublicKey="$(cat "$SSH_KEY.pub")"
   az deployment group create -g rg-certigo-ci \
     --template-file infra/ci-runner/runner.bicep \
     --parameters runnerName="$RUNNER_NAME" imageVersion="$IMAGE_VERSION" \
                  availabilityZone=3 \
                  adminSshPublicKey="$(cat "$SSH_KEY.pub")"
   ```

   Critère : uniquement la VM, `${RUNNER_NAME}-nic`, le disque OS géré et l'identité
   système associée sont créés ; aucune IP publique, la sortie `principalId` est non vide
   et `bootstrapSha256` correspond au tag de la VM. Les extensions VM sont désactivées
   (`allowExtensionOperations=false`) : toute évolution passe par une reconstruction avec
   le bootstrap versionné. `network.bicep` doit rester `NoChange`.

3. Attendre `Provisioning succeeded`, ouvrir une session privée (Bastion/VPN), attendre
   explicitement la fin de cloud-init, puis générer un jeton d'enregistrement valable une
   heure. Le flux ci-dessous le transmet par entrée standard : il ne l'écrit ni dans un
   fichier, ni dans une variable d'environnement, ni dans l'historique de commandes.
   Désactiver tout `set -x` avant de l'exécuter :

   ```bash
   sudo cloud-init status --wait
   sudo test -x /usr/local/sbin/certigo-runner-bootstrap

   # Depuis le poste opérateur, via Bastion/VPN vers l'adresse privée de la VM :
   gh api --method POST \
     repos/gchambaud_microsoft/Certigo/actions/runners/registration-token \
     --jq .token |
     ssh <BREAK_GLASS_ADMIN>@<PRIVATE_VM_ADDRESS> \
       'sudo /usr/local/sbin/certigo-runner-bootstrap --register --token-stdin'
   ```

   Le bootstrap lit le jeton une seule fois, le transmet à `config.sh`, puis l'efface de
   son environnement. Ne pas employer `RUNNER_TOKEN=...`, `--token ...`, `tee`, un
   redirecteur, un copier-coller dans un ticket ou un journal. Conserver la clé SSH privée
   dans le coffre break-glass approuvé pendant la vie du runner, puis la détruire lors de
   sa suppression ou la renouveler immédiatement en cas de compromission.

4. Vérifier la configuration, puis lancer les probes :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '.runners[] | select(.name == "'"$RUNNER_NAME"'") | {status,busy,labels:[.labels[].name]}'
   gh workflow run runner-health.yml
   gh run list --workflow runner-health.yml --limit 1
   ```

   Critères : `online`, label `certigo-ci`, santé verte pour GitHub, NuGet, pub.dev,
   npm, Azure, au moins 10 Gio libres et tous les SDK/outils. Exécuter ensuite le drill
   de perte de l'autre runner.

### Rollback de reconstruction

Si le nouveau runner échoue, conserver l'ancien runner en ligne, supprimer
l'enregistrement GitHub du nouveau puis seulement ses ressources. Si un rôle Azure lui a
déjà été accordé, appliquer d'abord le rollback d'identité ci-dessous :

```bash
RUNNER_ID="$(gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | select(.name == "'"$RUNNER_NAME"'") | .id')"
gh api --method DELETE \
  "repos/gchambaud_microsoft/Certigo/actions/runners/$RUNNER_ID"
az vm delete -g rg-certigo-ci -n "$RUNNER_NAME" --yes
az network nic delete -g rg-certigo-ci -n "${RUNNER_NAME}-nic"
```

Le rollback est réussi quand l'ancien pool traite de nouveau un dispatch et que
`network.bicep` ne montre aucune modification.

## Rotation, révocation et compromission

### Rotation planifiée

1. Ajouter/reconstruire un runner avec une nouvelle `imageVersion` et les nouvelles
   versions/SHA-256 vérifiées.
2. Prouver santé et failover.
3. Mettre l'ancien runner hors ligne, confirmer qu'aucun job n'est `busy`, révoquer ses
   attributions Azure, supprimer son enregistrement GitHub, puis sa VM/NIC/disque et sa
   clé SSH break-glass.
4. Ne jamais descendre sous deux runners `online` hors de la fenêtre contrôlée.

Pour mettre à jour le binaire, relever le champ `digest` de l'asset officiel, modifier
ensemble `RUNNER_VERSION` et `RUNNER_SHA256`, puis exécuter :

```bash
gh api repos/actions/runner/releases/tags/v<VERSION> \
  --jq '.assets[] | select(.name == "actions-runner-linux-x64-<VERSION>.tar.gz") | {url:.browser_download_url,digest}'
bash infra/ci-runner/validate.sh
```

Appliquer la même règle aux binaires Bicep/actionlint et aux actions : relever le
`digest` de l'asset ou le SHA du tag officiel, vérifier la signature GitHub du commit,
puis épingler la valeur complète dans le workflow :

```bash
gh api repos/Azure/bicep/releases/tags/v<VERSION> \
  --jq '.assets[] | select(.name == "bicep-linux-x64") | {url:.browser_download_url,digest}'
gh api repos/rhysd/actionlint/releases/tags/v<VERSION> \
  --jq '.assets[] | select(.name == "actionlint_<VERSION>_linux_amd64.tar.gz") | {url:.browser_download_url,digest}'
ACTION_SHA="$(gh api repos/actions/checkout/git/ref/tags/v4 --jq .object.sha)"
gh api "repos/actions/checkout/commits/$ACTION_SHA" \
  --jq '{sha,verified:.commit.verification.verified,reason:.commit.verification.reason}'
```

Le commit n'est accepté que si `verified` vaut `true`. Ne jamais remplacer un SHA
complet ou un digest versionné par un tag flottant.

### Révocation d'urgence

En cas de compromission, empêcher d'abord tout nouveau job :

```bash
RUNNER_ID="$(gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | select(.name == "'"$RUNNER_NAME"'") | .id')"
gh api --method DELETE \
  "repos/gchambaud_microsoft/Certigo/actions/runners/$RUNNER_ID"
az vm deallocate -g rg-certigo-ci -n "$RUNNER_NAME"
```

Révoquer ensuite les attributions de l'identité, renouveler toute clé SSH et tous les
secrets Key Vault auxquels la machine avait accès, examiner les journaux GitHub/Azure,
puis reconstruire depuis l'IaC. Ne jamais réutiliser le disque compromis. Le rollback
d'une révocation consiste à reconstruire et **réenregistrer** une VM saine, jamais à
réactiver l'enregistrement compromis.

## Identité managée pour la release Android (action externe)

`runner.bicep` crée une identité système mais n'accorde aucun droit. Après validation de
chaque nouveau runner, un opérateur autorisé doit accorder uniquement
`Key Vault Secrets User` sur le coffre mobile :

```bash
PRINCIPAL_ID="$(az vm identity show -g rg-certigo-ci -n "$RUNNER_NAME" \
  --query principalId -o tsv)"
KV_ID="$(az keyvault show -g rg-certigo-prod -n <VAULT_NAME> --query id -o tsv)"
az role assignment create --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" --scope "$KV_ID"
az role assignment list --assignee "$PRINCIPAL_ID" --scope "$KV_ID" \
  --include-inherited -o table
# Sur la VM, ne demander que l'identifiant, jamais la valeur du secret :
az login --identity --output none
az keyvault secret show --vault-name <VAULT_NAME> \
  --name <AUTHORIZED_TEST_SECRET> --query id -o tsv
```

Critères : une seule attribution au scope du coffre attendu ; `az login --identity`
réussit sur la VM et la lecture d'un secret de test autorisé réussit, sans afficher sa
valeur. Cette action et une vraie reconstruction ne sont pas réalisables dans une PR.

Rollback/révocation :

```bash
az role assignment delete --assignee "$PRINCIPAL_ID" \
  --role "Key Vault Secrets User" --scope "$KV_ID"
az role assignment list --assignee "$PRINCIPAL_ID" --scope "$KV_ID" -o table
```

Le second résultat doit être vide avant suppression d'une VM compromise.

## Drill de perte d'un runner

Le workflow manuel `Runner resilience drill` ne checkout aucun code, ne lit aucun
secret et refuse toute ref autre que `main`. Pour prouver le failover self-hosted :

1. Relever les deux runners en ligne.
2. Arrêter ou désactiver un seul runner et noter son nom exact.
3. Déclencher le workflow :

   ```bash
   gh workflow run runner-resilience-drill.yml \
     -f expected_offline_runner=<RUNNER_ARRETE>
   ```

4. Vérifier que le job termine sur un autre runner :

   ```bash
   gh run list --workflow runner-resilience-drill.yml --limit 1
   gh run watch <RUN_ID>
   ```

5. Réactiver le runner arrêté et confirmer que les deux instances sont `online`.

Le drill échoue si le runner exécutant porte le nom déclaré indisponible ou si le job
n'est pas exécuté sur un runner self-hosted. L'attente en file n'est pas limitée par
`timeout-minutes` ; l'absence de démarrage reste donc une preuve opérationnelle d'un
pool insuffisant et doit être interrompue manuellement.

## Résilience exclusivement Azure

Les runners hébergés par GitHub sont durablement indisponibles et aucun chemin de
break-glass ne doit les cibler. Le failover supporté consiste exclusivement à conserver
au moins deux runners Azure interchangeables portant
`self-hosted`, `Linux`, `X64`, `certigo-ci`. Si le pool entier est indisponible, la CI
reste bloquée jusqu'à restauration d'une VM saine ; elle ne change jamais de classe de
runner automatiquement.

## Reconstruction, rotation et révocation

- **Reconstruction** : si une VM runner devient irrécupérable, reprovisionner une VM
  Linux dans `RG-CERTIGO-CI`, la raccorder au sous-réseau `snet-runners`, réappliquer
  le bootstrap idempotent, puis réenregistrer le runner GitHub avec le label
  `certigo-ci`.
- **Rotation** : lors de la rotation d'un outil, d'un certificat ou d'un accès
  managé, mettre à jour la documentation opérateur correspondante puis valider la VM
  reconstruite avec la sonde quotidienne et le drill manuel.
- **Révocation** : supprimer immédiatement l'enregistrement GitHub d'un runner
  compromis, révoquer les accès Azure associés (identité managée / rôles) puis
  reconstruire une VM propre avant réintégration au pool.

## Rollback

Réactiver ou reconstruire les runners Azure avec le jeu de labels fixe. Ne supprimer une
VM ou un enregistrement GitHub qu'après avoir confirmé qu'au moins deux autres runners
compatibles sont en ligne.
