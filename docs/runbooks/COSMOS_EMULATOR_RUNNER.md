# Runner éphémère Cosmos — validation post-merge de suppression de compte

## Statut et limite de ce changement

Ce livrable est volontairement **feature-off** et ne réalise **aucun déploiement**,
aucun démarrage, aucune déallocation et aucune suppression de VM. Il prépare :

- un template Bicep autonome, non référencé par `infra/main.bicep` ;
- un bootstrap à versions et SHA-256 épinglés ;
- un workflow qui reste dans `.github/workflows-disabled/` ;
- des validations locales de sécurité, de provenance, de runbook et de rollback.

Seul un `what-if` Azure read-only est autorisé pendant la revue. L'activation, le
provisionnement, la registration GitHub et l'exécution réelle appartiennent à une
fenêtre et à une PR séparées.

## Dépendances et coordination

- `main` de référence est `8cd955faa790aa69a2f330a8f57781e8856d624b`.
  Il contient les merges #296 (`6145f357c4cdc3524d04faddf1e2f96e7a1b32d9`),
  #302 (`978c38e9b64d12144ccc4bbe02ff1fe37c5c0458`), #311
  (`8a4f3be99b5d7cf97eb870d85e8481be24ceb1bc`) et #313
  (`8cd955faa790aa69a2f330a8f57781e8856d624b`). Le test réel doit partir d'un
  `main` contenant aussi le merge de la présente PR.
- **PR #296** fournit la cible
  `CosmosRepositoriesIntegrationTests.Account_deletion_removes_user_partitions_and_keeps_only_pseudonymous_tombstone`.
  Elle reste obligatoire, mais n'est plus seule : le gate exécute désormais toute la suite
  émulateur (voir « Contenu du gate : toute la suite émulateur »). Son workflow temporaire sur
  `certigo-trusted` est retiré de `.github/workflows/` et ne doit pas être réactivé.
- **PR #302** reste la source de décision pour les futurs pools/VMSS et le contrôleur
  de capacité. Ce canari n'entre ni dans ses pools `certigo-pr` / `certigo-trusted`,
  ni dans son autoscaling feature-off : il s'agit d'une VM singleton jetable, avec
  le label exclusif `certigo-cosmos-emulator`.
- **PR #311** ajoute le runtime Person/LinkedIdentity en mode `off|shadow` ;
  ce gate ne change pas ce mode et teste le code fusionné courant.
- **PR #313** garde l'activation du domaine public fail-closed ; ce gate ne
  modifie ni domaine public, ni paramètres de production, ni données live.

## Groupe GitHub

`gchambaud_microsoft` est un compte utilisateur, pas une organisation GitHub.
Les runner groups dédiés ne sont donc pas disponibles. Le cloisonnement possible
aujourd'hui est un runner repository-scoped dans le groupe par défaut, portant un
seul label de rôle : `certigo-cosmos-emulator`.

Si le dépôt migre vers une organisation, créer un groupe dédié limité à ce dépôt
avant l'activation, puis ajouter ce groupe à `runs-on`. Ne jamais réutiliser les
groupes ou labels privilégiés de #302.

## Architecture isolée

Le template `infra/ci-runner/cosmos-emulator/runner.bicep` crée uniquement, dans
un groupe de ressources jetable dédié :

1. une IP publique Standard utilisée seulement par la NAT Gateway ;
2. une NAT Gateway pour l'egress explicite ;
3. un VNet `/28` sans peering, service endpoint ou private endpoint ;
4. un sous-réseau privé avec `defaultOutboundAccess=false` ;
5. un NSG qui autorise l'egress Internet TCP/443, refuse le reste d'Internet et
   refuse `VirtualNetwork` en sortie ; le refus du service tag
   `AzurePlatformIMDS` est ajouté **après l'enregistrement** (voir « IMDS : deux
   barrières, posées au bon moment ») ;
6. une NIC privée sans IP publique ;
7. une VM Trusted Launch sans managed identity, avec VM Agent uniquement pour
   recevoir la registration protégée hors IaC.

Le NSG refuse **tout ingress**, y compris SSH. Aucun chemin vers les private
endpoints applicatifs n'est créé ; le deny `VirtualNetwork` reste une seconde
barrière si un peering était ajouté par erreur. Aucun rôle ou credential Azure
n'est présent dans la VM ou le job.

Le bootstrap ajoute aussi un deny hôte global et Docker vers
`169.254.169.254`. Le job refuse de démarrer si IMDS répond ou si une variable
Azure/managed identity est présente. `allowExtensionOperations=true` est limité
au canal control-plane Managed Run Command : aucune extension n'est déclarée dans
l'IaC, le Run Command temporaire est supprimé avant le job et le job ne possède
aucun credential pour en créer un.

### IMDS : deux barrières, posées au bon moment

> **Fait daté.** Mesuré sur le pool PR du 2026-09-11 au 2026-09-14
> (`docs/CI_RUNNER_RESILIENCE.md`, « Cause racine des instances PR mortes ») : les cinq
> créations faites avec un refus `AzurePlatformIMDS` actif ont échoué en provisionnement.
> **Invalidé si** Azure cesse d'exiger IMDS pendant le provisionnement Linux.

Le provisionnement Azure a besoin d'IMDS. Un refus NSG présent **dès la création** fait
donc échouer la VM avant tout bootstrap. Le template ne le porte plus ; les deux barrières
sont posées dans cet ordre :

1. **Hôte, avant l'enregistrement.** Le bootstrap installe `certigo-block-imds` (chaînes
   `OUTPUT` et `DOCKER-USER`) avant d'écrire la sentinelle `bootstrap-complete`, que
   l'enregistrement attend. Aucun token GitHub n'entre donc dans une VM où IMDS répond
   encore.
2. **NSG, après l'enregistrement et avant le `workflow_dispatch`.** L'opérateur ajoute le
   refus, qu'Azure n'accepte qu'en `Deny` et avec la source `*` :

   ```bash
   az network nsg rule create \
     --resource-group rg-certigo-ci-cosmos-validation \
     --nsg-name "${RUNNER_NAME}-nsg" \
     --name DenyImdsOutbound \
     --priority 100 \
     --direction Outbound \
     --access Deny \
     --protocol '*' \
     --source-address-prefixes '*' \
     --source-port-ranges '*' \
     --destination-address-prefixes AzurePlatformIMDS \
     --destination-port-ranges '*'
   ```

   puis vérifie `provisioningState=Succeeded` sur la règle.

La sonde IMDS du script de gate reste le dernier contrôle, dans le job lui-même.

### Pourquoi ni clé SSH opérateur, ni Serial Console

L'opérateur ne génère, ne copie et ne conserve **aucune clé SSH**. Azure exige
néanmoins une credential syntaxique dans l'OS profile : le template contient
uniquement une clé publique non opérationnelle dont la moitié privée a été
détruite avant commit, et le NSG bloque le port 22.

Cloud-init ne suffit pas pour la registration : son `customData` est fourni au
provisionnement, donc y placer le token GitHub le ferait entrer dans l'IaC et
dans l'état de provisioning. Azure Serial Console n'est pas plus sûre pour ce
secret : la documentation Microsoft exige boot diagnostics et un utilisateur à
mot de passe, et avertit que les commandes contenant des secrets sont inscrites
dans les logs boot diagnostics. Ce template désactive donc boot diagnostics et
n'ajoute aucun mot de passe local.

Le seul canal retenu est
[Managed Run Command](https://learn.microsoft.com/azure/virtual-machines/linux/run-command-managed) :
son `protectedParameters` chiffre le token, ne le renvoie pas dans l'instance
view et permet de supprimer immédiatement l'enfant Run Command.

## Provenance épinglée

| Composant | Pin | Vérification |
| --- | --- | --- |
| Ubuntu 24.04 | `imageVersion` Marketplace exacte, jamais `latest` | tag VM + garde Bicep |
| GitHub runner | `2.336.0` | SHA-256 release GitHub |
| Docker statique x64 | `29.7.2` | SHA-256 de l'archive officielle |
| Cosmos emulator amd64 | build `vnext-EN20260810-amd64` | digest OCI `sha256:dc583d...1669c` |
| Bootstrap | contenu exact de `bootstrap.sh` | SHA-256 dans Bicep et test Node |
| .NET SDK | `8.0.424` | version exacte dans le workflow |
| Actions | SHA de commit complet | commentaire de version requis |

Toute rotation met à jour le binaire ou l'image, son digest, le runbook et les
tests dans le même commit.

### Défauts trouvés avant la première création réelle

> **Fait daté.** Mesuré le 2026-09-25 depuis le poste opérateur et l'abonnement
> `MCAPS-Hybrid-REQ-150432-2026-gchambaud`. **Invalidé si** l'image, la taille ou le
> NSG du template changent, ou si Azure change la disponibilité d'une taille ou d'un
> miroir.

Le modèle n'avait jamais été créé. Relu contre la réalité, il aurait échoué pour trois
raisons indépendantes :

| Défaut | Mesure | Correction |
| --- | --- | --- |
| Le miroir de l'image Azure, `azure.archive.ubuntu.com`, ne sert pas HTTPS ; le NSG n'autorise que TCP/443 | TCP 443 : délai dépassé ; `archive.ubuntu.com` et `security.ubuntu.com` rendent 200 en HTTPS ; HTTP 80 du miroir Azure rend 200 | le bootstrap réécrit les sources vers `https://archive.ubuntu.com/ubuntu/` et `https://security.ubuntu.com/ubuntu/`, puis échoue fermé si une source reste en HTTP ; vérifié dans `ubuntu:24.04` amd64 : `apt-get update` et l'installation réussissent en HTTPS seul |
| `Standard_D4s_v5` est `NotAvailableForSubscription` en `westeurope` | `az vm list-skus` : restriction sur les trois zones | `Standard_D4ads_v6` (4 vCPU, 16 Gio), famille du pool existant, avec `diskControllerType: 'NVMe'` exigé par les tailles v6 ; quota Dadv6 : 12/100 |
| Le refus NSG `AzurePlatformIMDS` à la création empêche le provisionnement | 5 créations sur 5 en échec sur le pool PR | refus posé après l'enregistrement, voir « IMDS : deux barrières, posées au bon moment » |

Contrôles complémentaires du même jour : les SHA-256 épinglés de Docker `29.7.2` et du
runner `2.336.0` correspondent aux archives téléchargées ; les options Docker du
bootstrap (`userland-proxy=false`, `icc=false`, `bip`) servent bien un port publié sur
`127.0.0.1` (Docker `29.8.1` en Docker-in-Docker). Les timers `apt-daily` sont désactivés
et `apt-get` attend les verrous (`DPkg::Lock::Timeout=60`, huit essais bornés) : une
évaluation de correctifs Azure concurrente ne fait plus échouer le bootstrap.

## Validation de PR — what-if uniquement

Depuis un poste opérateur authentifié en lecture sur le groupe de ressources
jetable, choisir des valeurs non existantes et exécuter seulement :

```bash
az deployment group what-if \
  --resource-group rg-certigo-ci-cosmos-validation \
  --template-file infra/ci-runner/cosmos-emulator/runner.bicep \
  --parameters \
    runnerName=vm-certigo-cosmos-<run-id> \
    imageVersion=<UBUNTU_24_04_EXACT_VERSION>
```

Critères de revue :

- uniquement les six déclarations ARM dédiées sont `Create` ; le sous-réseau est
  embarqué dans le VNet et le disque OS est géré par la VM avec `deleteOption=Delete` ;
- aucun `Modify`, `Delete`, rôle RBAC, identité ou peering ;
- aucune ressource du pool existant `rg-certigo-ci` n'est ciblée ;
- les tags contiennent `lifecycle=one-shot`, la version image et le SHA bootstrap.

Ne pas remplacer `what-if` par `create` dans cette PR.

## Registration éphémère hors IaC

La registration n'est ni dans Bicep, ni dans cloud-init, ni dans un workflow.
Après provisionnement approuvé dans une fenêtre séparée, l'opérateur exécute une
seule commande depuis un poste déjà authentifié avec `gh` et `Az.Accounts` :

```powershell
.\infra\ci-runner\cosmos-emulator\register-runner.ps1 `
  -ResourceGroupName rg-certigo-ci-cosmos-validation `
  -VmName vm-certigo-cosmos-<run-id> `
  -Apply `
  -Confirm:$false
```

Le script :

1. vérifie les tags one-shot et l'absence de managed identity ;
2. obtient en mémoire un token repository-scoped valable une heure ;
3. le transmet comme `protectedParameter` au Managed Run Command ;
4. attend avec une borne la sentinelle de fin cloud-init, puis le transmet au
   bootstrap sur stdin avec `set +x`, sans l'imprimer ;
5. met à null ses références locales, puis supprime toujours l'enfant Run
   Command.

Ne pas activer PowerShell `-Debug`, `Start-Transcript` ou un proxy de capture
pendant cette commande. Aucun fichier, clé SSH, copier-coller de token ou
connexion interactive à la VM n'est requis ; l'opérateur n'a pas à deviner quand
cloud-init est terminé.

Le bootstrap appelle `config.sh --ephemeral --disableupdate`. Son service
systemd a `Restart=no` : le listener accepte un seul job, se désenregistre puis
s'arrête. `RuntimeMaxSec=2700` arrête aussi le listener après 45 minutes même si
aucun job n'est attribué ; `KillMode=control-group` termine ses processus fils.
`ExecStopPost` nettoie le workspace, puis met l'OS hors tension. Cet arrêt local
ne vaut pas déallocation Azure : l'opérateur doit encore déallouer ou supprimer
la VM. Une VM déjà enregistrée est refusée et doit être détruite.

### Permissions opérateur minimales

Séparer autant que possible les deux identités humaines temporaires :

- le déploiement/rollback Azure est limité au groupe
  `rg-certigo-ci-cosmos-validation` et aux actions nécessaires sur VM, NIC,
  disque, VNet, NSG, NAT Gateway et IP publique ;
- la registration requiert seulement la lecture de la VM et
  `Microsoft.Compute/virtualMachines/runCommands/read|write|delete` sur cette VM ;
- GitHub requiert l'administration des runners de ce seul dépôt pour créer le
  token repository-scoped, vérifier/supprimer la registration et lancer le
  workflow ;
- aucune identité Azure, permission OIDC, environment GitHub ou permission
  d'écriture du dépôt n'est transmise au runner ou au job.

Ne pas attribuer de rôle au principal de la VM : le template ne crée aucune
identité managée et aucune role assignment.

## Activation séparée

La PR qui déplace uniquement le workflow vers son chemin actif ne provisionne
aucune ressource et ne lance aucun test : elle laisse le gate et la feature off.
Les étapes 3 à 5 ci-dessous sont accomplies par cette PR d'activation, qui porte
le dossier de l'état B à l'état C ; la variable `CERTIGO_COSMOS_EMULATOR_ENABLED`
reste non définie ou `false`.

Après fusion de la présente PR, alors que le gate et la feature restent off :

1. vérifier que `main` contient les merges #296, #302, #311, #313 et celui de
   la présente PR ;
2. garder `ACCOUNT_DELETION_ENABLED=false` et
   `CERTIGO_COSMOS_EMULATOR_ENABLED=false` ;
3. déplacer le workflow vers
   `.github/workflows/post-merge-cosmos-account-deletion.yml` dans une PR dédiée ;
4. conserver le workflow historique `test-account-deletion-cosmos.yml` hors de
   `.github/workflows/` ;
5. vérifier que le validateur trusted reconnaît l'état C atomique — one-shot actif,
   legacy archivé et archive one-shot absente — puis adapter dans la même PR
   `infra/ci-runner/cosmos-emulator/validate.test.mjs` et le présent runbook pour
   retirer leurs assertions et mentions feature-off ;
6. fusionner cette PR d'activation sur `main` tandis que la variable reste
   `false` ;
7. dans la fenêtre approuvée, valider le `what-if`, créer uniquement le groupe
   jetable et ses six ressources, puis confirmer l'absence d'identité managée,
   de peering, de private endpoint et d'ingress ;
8. exécuter le script de registration, vérifier immédiatement que le runner est
   online, non busy et porte uniquement le label custom
   `certigo-cosmos-emulator`, puis ajouter le refus NSG `AzurePlatformIMDS`
   (voir « IMDS : deux barrières, posées au bon moment ») ;
9. définir la variable à `true`, puis lancer **une seule fois**
   `workflow_dispatch` depuis `main` avant l'expiration de 45 minutes du listener ;
10. accepter comme preuve uniquement un job sur le SHA `main` attendu dont le résumé
    affiche exactement un résultat TRX, exécuté et `Passed`, par test `[CosmosEmulatorFact]`,
    test de suppression de compte compris (voir « Contenu du gate : toute la suite
    émulateur ») ;
11. après conclusion du job, remettre immédiatement la variable à `false`, puis
    appliquer le rollback externe ;
12. n'ouvrir la PR produit qui active `ACCOUNT_DELETION_ENABLED` qu'après
    conservation de la conclusion GitHub, du SHA testé et de la preuve d'absence
    de toutes les ressources jetables.

Le workflow ne contient aucun événement PR, checkout de head SHA ou secret
Azure. Il checkout explicitement `refs/heads/main`, vérifie `HEAD == origin/main`,
exécute toute la suite émulateur (`--filter Category=CosmosEmulator`, test de suppression
de compte compris), écrit le résultat par test dans `GITHUB_STEP_SUMMARY`, exige
exactement un résultat TRX exécuté et réussi par test `[CosmosEmulatorFact]`, ne
publie aucun artifact et nettoie conteneur, clé et résultat local.

Le passage de B à C doit conserver exactement la baseline active B et ajouter le
seul workflow one-shot décrit ci-dessus. Le manifeste sémantique trusted épingle
les ensembles A, B et C par chemin canonique et SHA-256 ; le générateur manuel ne
fait partie d'aucun workflow et le validateur ne régénère jamais les empreintes.
Tout changement sémantique d'un workflow est d'abord pré-approuvé sur `main`, puis
appliqué par une PR distincte qui consomme l'approbation : voir
[`CI_WORKFLOW_CHANGES.md`](./CI_WORKFLOW_CHANGES.md).

## Contenu du gate : toute la suite émulateur

> **Fait daté.** Mesuré le 2026-09-24 sur le build `vnext-EN20260810` (jumeau `arm64`
> `sha256:8383edc6…ee41c` du digest `amd64` épinglé). **Invalidé si** l'image épinglée
> change, ou si un test `[CosmosEmulatorFact]` est ajouté, retiré ou modifié.

`run-account-deletion.sh` garde son nom, car le workflow scellé l'appelle mot pour mot,
mais n'exécute plus un seul test. Il compte les attributs `[CosmosEmulatorFact]` dans
`backend/tests/Certigo.Infrastructure.Tests`, lance `dotnet test --filter
Category=CosmosEmulator`, puis refuse le résultat si le TRX ne contient pas exactement
un résultat `Passed` par attribut, si un test est rapporté deux fois, si le test de
suppression de compte manque ou si `dotnet test` échoue. Un test émulateur laissé hors
du trait, sauté ou supprimé fait donc échouer le gate au lieu de le rétrécir.
`CosmosEmulatorSuiteContractTests` vérifie la même frontière sans émulateur, à chaque
CI backend.

Mesures locales, émulateur `vnext-EN20260810-arm64` sous Docker Desktop :

| Exécution | Résultat |
| --- | --- |
| Suite avant correction | 16/18 : deux tests de `CosmosContentReleaseStoreIntegrationTests` échouaient selon l'ordre d'exécution xUnit, parce que trois tests promouvaient le pointeur singleton avec `If-Match: *` dans une base partagée par la classe |
| Suite après isolation d'une base par test | **18/18** |
| Script du gate, conteneur Linux `dotnet/sdk:8.0`, socket Docker de l'hôte | **18/18**, sortie 0, zéro conteneur, clé ou résultat restant après `--cleanup-only` |
| Même script, un test `[CosmosEmulatorFact]` ajouté hors du trait | sortie 1 : `expected 19 Cosmos emulator results … found 18` |

L'ancien sixième échec, l'agrégat `GetRecentActivityAsync` sur `vnext-preview`, ne se
reproduit plus : la requête projette désormais ses agrégats à plat
(`SELECT COUNT(1) AS attempts, SUM(…) AS xp`), forme que Cosmos exige aussi.

## Fin d'un job et destruction obligatoire

L'opérateur qui a créé la VM reste propriétaire du cleanup externe. Dès que le
job obtient une conclusion GitHub, réussie ou non :

1. vérifier que le listener éphémère est absent ou offline et `busy=false` ;
2. supprimer l'enfant Managed Run Command s'il subsiste après une interruption
   opérateur ;
3. supprimer un éventuel enregistrement GitHub stale ;
4. déallouer immédiatement la VM si la suppression du groupe ne peut pas être
   lancée dans la même minute ;
5. supprimer le groupe de ressources jetable ;
6. vérifier l'absence de VM, NIC, disque, VNet, NAT Gateway, IP publique et runner.

Commandes de rollback opérateur :

```bash
set -euo pipefail
RUNNER_NAME=vm-certigo-cosmos-<run-id>
: "${RUNNER_NAME:?set RUNNER_NAME to the deployed one-shot VM name}"

az vm run-command delete \
  --resource-group rg-certigo-ci-cosmos-validation \
  --vm-name "$RUNNER_NAME" \
  --run-command-name register-ephemeral-github-runner \
  --yes

RUNNER_ID="$(gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | select(.name == "'"${RUNNER_NAME}"'") | .id')"
if [ -n "$RUNNER_ID" ]; then
  gh api --method DELETE \
    "repos/gchambaud_microsoft/Certigo/actions/runners/$RUNNER_ID"
fi

az vm deallocate \
  --resource-group rg-certigo-ci-cosmos-validation \
  --name "$RUNNER_NAME"

az group delete \
  --name rg-certigo-ci-cosmos-validation \
  --yes
```

Si la registration échoue avant le job, le script supprime déjà le Run Command ;
appliquer ensuite le même rollback. Si le job
reste en file, ne jamais ajouter `certigo-pr` ou `certigo-trusted` à la VM :
annuler le run, supprimer l'enregistrement, déallouer puis détruire.

## Désactivation

Avant toute autre action, remettre
`CERTIGO_COSMOS_EMULATOR_ENABLED=false`. Retirer ensuite le workflow actif dans
une PR, annuler les runs en file, supprimer les registrations stale et appliquer
le rollback ci-dessus. Aucun changement de schéma Cosmos, de réseau applicatif
ou de contrôleur VMSS n'est nécessaire.
