# Image runner immuable

Ce dossier est un livrable **hors deploiement**, dont l'installation reste
**bloquee**. Toutes les entrees reseau de l'installation sont desormais
verrouillees (APT, Flutter/Pub, roues Python, archives de toolchain) et consommees
par un installateur hors ligne, execute localement sous qemu (voir « Consommateur
hors ligne »). L'admission reste fermee par les gardes tant que relecture, CI et
accord explicite ne l'ont pas levee. Une attestation de fichiers installes ne
prouve pas a elle seule la reproductibilite des telechargements; les controles de
boot refusent un contenu different.

Il ne modifie aucun VMSS, SKU, capacite, label, binding, identite, route, IP
publique, acces prive ou automate de lifecycle. `runner.bicep`, `pilot.bicep`, les
inventaires live et les IDs hors scope ne referencent pas cette image dans PR1.

## Contenu

- `toolchain-manifest.json` est la source de verite des versions et empreintes;
- `toolchain-sbom.cyclonedx.document` est le SBOM CycloneDX 1.6 de l'image, y compris
  chaque paquet transitif de l'environnement Python;
- `toolchain-requirements.lock` verrouille avec hashes tout l'environnement
  Checkov/PyYAML Python 3.12; `python-wheels.lock.json` choisit la roue exacte de
  chaque exigence pour la cible (`lock_python.py`, tags `python-target-tags.txt`);
- `install_offline.py` est l'installateur hors ligne de l'image; il ne consomme que
  les entrees verifiees et le store ferme produit par `image_artifacts.py`;
- `prewarm-toolchain.sh` reste le chemin legacy, epingle par le lock APT : il
  refuse toute execution avant une ecriture ou un telechargement;
- `validate-network-inputs.mjs` exige les trois vrais fichiers de lock et leurs
  empreintes, puis refuse encore l'admission : l'installateur existe mais n'est
  pas admis;
- `validate-toolchain.sh --boot` verifie manifest, SBOM, lock, attestation,
  versions, l'inventaire exhaustif (fichiers, repertoires, liens, modes et
  hashes) des toolchains, du runner et d'Azure CLI, et l'etat dpkg atteste; tout
  ajout inattendu echoue;
- le generateur systemd ajoute `Requires=certigo-toolchain-validate.service` a
  l'unique service `actions.runner.*`: un mismatch empeche son demarrage;
- `certigo-job-temp-mount.service` bind-monte le workspace runner reel sur le
  disque temporaire `/mnt/certigo-job`; `job-temp.sh` detruit ensuite workspace
  et caches NuGet/npm/pub/.NET au debut et a la fin de chaque job;
- `measure-cold-start.sh` emet les timestamps monotoniques validation/runner du
  futur canari;
- `offline_harness.py` est l'outillage de test local (banc amd64 qemu), jamais une
  entree de l'image; `transport/` contient les derives `gzip -n -9` embarques.

Le controle d'admission suivant **doit echouer** dans cet etat du depot:

```bash
node infra/ci-runner/image/validate-network-inputs.mjs
```

Ne pas executer le bootstrap existant hors de l'installateur pour contourner ce
refus. Seul, il reste le bootstrap mutable des runners actuels et appelle
notamment `bin/installdependencies.sh`. L'installateur hors ligne l'execute
confine, sans source APT, et ne lance jamais `installdependencies.sh`.

L'image ne doit contenir ni `.runner`, ni token GitHub, ni secret, ni dependance
du depot. L'enregistrement ulterieur doit copier les variables sans secret de
`runner-ephemeral.conf` dans le fichier `.env` du runner. Le flux protege appelle
`certigo-seal-runner-state prepare`, enregistre le runner et installe son service
sans le demarrer, puis appelle `certigo-seal-runner-state seal`. Cette derniere
etape rend le payload et les fichiers d'identite root-owned/read-only, les
atteste, recharge systemd et rejoue la validation avant tout demarrage.

Au boot, `certigo-job-temp-mount.service` remonte le resource disk Azure `/mnt`
avec `nodev,nosuid`, exige le device `/dev/disk/azure/resource-part1`, cree
`/mnt/certigo-job`, puis bind-monte son `_work` sur le workspace configure.
Toute autre source, option ou identite inode/device echoue fermee.

## Mesures actuelles

Les timestamps viennent de l'API GitHub Jobs et sont conserves dans
`runner-image-evidence.json`.

| Chemin observe | Installation evitee estimee |
| --- | ---: |
| Probe complet froid (`runner-health`, run `33387732157`) | 102 s |
| Build backend PR (setup .NET) | 11 s |
| Validation infra (Bicep) | 2 s |

Le probe froid detaille 88 s pour Flutter, 11 s pour .NET et 1 s chacun pour
Node, Dart et Bicep. actionlint et Checkov sont inferieurs a la resolution d'une
seconde sur les runs observes, donc exclus du total. Le delai creation du
workflow vers prise en charge par un runner deja allume est de 3 s.

Le cold-start VM de la nouvelle image n'est volontairement pas invente: PR1 ne
construit et ne deploie rien. PR2 devra publier la sortie de
`measure-cold-start.sh` et comparer P50/P95 sur au moins 20 boots.

## PR2: canari puis rollback

1. Construire une version Azure Compute Gallery neuve depuis un commit PR1
   approuve, conserver son resource ID et ses hashes, puis faire relire le SBOM
   et l'attestation. Aucun alias `latest`.
2. Ajouter l'IaC dans une PR distincte. Le premier passage autorise est
   `bicep build`, Checkov puis un `what-if` sauvegarde et relu; aucun deploiement
   automatique.
3. Creer ulterieurement un VMSS **neuf**, capacite canari 1, sans changement du
   VMSS live. Le premier pool reste PR-only, label exclusif
   `certigo-pr-image-canary`, sans identite managee, IMDS bloque, sans PIP ni
   acces prive applicatif. Le pool trusted reste physiquement distinct et garde
   son MI/IMDS seulement lorsqu'il sera traite dans une phase ulterieure.
4. Prouver boot fail-closed, disque temporaire, effacement inter-job, egress,
   absence de secret/cache, hashes, labels exclusifs, et 20 cold-starts. Lancer
   ensuite des jobs shadow explicites; ne deplacer aucun required check avant
   validation P95 et accord.
5. Garder le controleur lifecycle en feature flag off. Toute activation future
   conserve quiet period, doubles gardes, generation lease et CAS de revision,
   et relit `busy` juste avant scale-in.
6. Rollback: retirer uniquement le label/routing canari, drainer le runner,
   supprimer son enregistrement GitHub exact, puis le nouveau VMSS et la version
   d'image exacte. Relire ensuite le VMSS live et ses bindings hors scope; ne
   jamais modifier sa capacite, son SKU, ses IDs, son NAT/LB ou ses exclusions.

## PR2 code-only

PR2 ajoute uniquement des ressources **nouvelles et desactivees par defaut**:

- `image-build-contract.json` conserve le commit PR1
  `f8e23b2952e8ca39c59f30081b8950170abb701a` comme origine du toolchain et
  lie les sources au SHA Git exact de `contractCommit` (mis a jour seulement
  apres le commit des entrees, sans reference circulaire), a l'image Marketplace exacte
  `24.04.202608070`, a la version Gallery `1.0.337` et aux SHA-256 de chaque
  entree;
- le contrat reste fail-closed avec `reproducibleInputsReady=false`: les trois
  Bicep ont aussi un garde de code `networkInstallerImplemented=false`, non
  exposable comme parametre. Ils ne peuvent creer aucune ressource, meme avec
  `deploymentEnabled=true` et des drapeaux JSON falsifies, tant que ce garde
  litteral n'est pas leve apres relecture, CI verte et accord explicite. Les locks
  et l'installateur hors ligne ne suffisent pas a le lever. PR2 n'assimile
  jamais une version seule a une preuve de reproductibilite;
- `image-build.bicep` declare la Gallery, la definition et le template Azure VM
  Image Builder. `deploymentEnabled=false` et `autoRun=Disabled`: compiler ou
  deployer le modele sans parametre explicite ne construit rien;
- le build utilise une identite user-assigned dediee uniquement pour ecrire la
  nouvelle version Gallery. Cette identite n'entre pas dans l'image. Les
  entrees voyagent dans le template lui-meme (transport « (C') » plus bas), la VM
  reverifie chaque hash avant usage, la validation in-VM refuse `.runner`,
  credentials, cle privee, cache ou boot non conforme;
- le tout premier customizer bloque IMDS et en apporte la preuve avant la seule
  etape reseau (acquisition de l'ensemble ferme). La validation finale et le
  bootstrap canari exigent aussi le service actif, la regle iptables et un probe
  IMDS en echec;
- `canary-main.bicep` cree conditionnellement le groupe runtime dedie et le
  marque avec le meme TTL que ses ressources; `canary.bicep` declare un reseau
  non peere et un VMSS neuf de capacite 1,
  sans identite managee ni IP publique. IMDS est bloque dans l'image et par le
  NSG; le seul label metier est `certigo-pr-image-canary`. Les deux templates
  calculent `effectiveDeploymentEnabled=false` tant que les locks reproductibles
  ou la politique signataire ne sont pas actifs, meme si un appelant force
  `deploymentEnabled=true`;
- `canary-contract.json` reserve explicitement les runners 24/26 et la VM 415,
  refuse les noms/labels existants, exige 20 mesures cold et 20 warm, et borne
  le canari a 72 heures / 15 USD. Le tarif Linux VM observe est 0,138 USD/h;
- `validate-canary-evidence.mjs` refuse toute cible hors subscription, groupe,
  type et nom attendus. Une creation initiale doit contenir l'ensemble complet;
  chaque payload de creation est relu (absence d'identite/PIP runner/label
  existant, capacite/SKU/image, deny-only NSG, VNet non peere, NAT dedie,
  Trusted Launch et authentification sans mot de passe);
  une transition ne peut modifier que l'ID image et ses fingerprints sur le
  nouveau VMSS, avec les versions avant/apres exactes. Le validateur lie aussi
  les hashes du what-if et du descripteur Azure, les attestations, les
  percentiles recalcules, le TTL et la version precedente;
- `canary-transition.ps1` exige une autorisation litterale avant le moindre
  appel Azure, compile une seule fois le graphe Bicep complet en ARM, hash ce
  fichier, l'utilise pour le what-if et le deploiement, puis reverifie son hash
  juste avant application. Il refuse aussi un descripteur de plus de 24 heures et
  re-hashe la sortie AIB, le template AIB et la version Gallery courants avant le
  what-if puis avant l'application. Il sauvegarde le what-if complet, le valide,
  puis promeut ou remet
  la version Gallery precedente exacte dans un deploiement subscription limite
  au groupe canari. Avant application, il verifie les deux attestations GitHub,
  observe et sauvegarde l'image courante reelle. Le seul exemplaire est ensuite
  mis a jour avant verification du modele; il reste hors routing pendant la
  transition;
- `canary-cleanup.ps1` exige une autorisation distincte, l'expiration du TTL,
  des tags de possession sur chaque ressource et l'absence de tout token hors
  scope avant de supprimer le seul groupe runtime dedie;
- le scan Checkov compile d'abord les trois Bicep en ARM, car Checkov 3.2.495 ne
  sait pas analyser `loadJsonContent`. L'exception locale `CKV_AZURE_95`
  interdit seulement l'auto-upgrade OS qui contournerait la version Gallery
  exacte et ses attestations; SSH par cle, chiffrement host, Trusted Launch,
  NSG et authentification sans mot de passe restent controles;
- la limite de 15 USD est un plafond operationnel **estime**, pas un Azure
  Budget: 72 h du SKU observe valent 9,94 USD avant reseau et stockage. Le TTL
  est refuse au-dela de 72 h et le cleanup reste une operation separee,
  explicitement autorisee et fail-closed;
- `canary-evidence.json` reste volontairement `planned`: aucune mesure,
  attestation ou sortie what-if live n'est inventee;
- `.github/workflows-disabled/runner-image-attest.yml` utilise Azure OIDC pour
  lire la sortie AIB, le deploiement et la version Gallery attendus dans
  l'abonnement exact. Il recompile le Bicep avec le binaire epingle, compare le
  template ARM canonique exporte, valide tous les parametres, l'identite du
  deploiement, sa correlation et l'absence de mutation AIB dans l'Activity Log,
  puis publie ces preuves dans un artifact GitHub immuable. Le descripteur signe
  contient l'ID et le digest de cet artifact; les tags Azure mutables ne servent
  jamais de preuve de provenance. Il atteste ce descripteur avec la provenance
  SLSA et le SBOM CycloneDX. Aucun ID image ou digest de sujet n'est accepte
  depuis le dispatcher. Son
  activation demande une PR separee et l'environnement protege
  `runner-image-canary-attestation`. Il cible exclusivement le nouveau label
  `certigo-image-attestation-canary`; aucun workflow actif ne route ce label.
  La transition reste bloquee jusqu'a ce que cette future activation inscrive
  son SHA Git exact dans `attestation-policy.json`, puis `gh attestation
  verify` impose repo, workflow, SHA signataire, ref source et SHA source.

Le deploiement image, l'appel AIB, le what-if Azure, l'enregistrement GitHub du
nouveau runner et toute promotion restent interdits tant qu'une autorisation
ulterieure n'a pas ete donnee. Le rollback reutilise le meme modele Incremental
avec `galleryImageVersionId` positionne sur
`previousGalleryImageVersionId`; il ne cible que le nouveau groupe runtime.
Le premier `Promote` accepte un VMSS absent uniquement si le what-if valide le
`Create` complet de chaque ressource dediee, sans `Modify`; tout `Create`
partiel, mixte, rollback initial ou drift entre what-if et etat observe est
refuse. Le validateur exige les ressources developpees et refuse aussi toute
entree de delta `Microsoft.Resources/deployments`, meme en `NoChange`. Cette
premiere autorisation produit seulement le statut
`provision-authorized`: les mesures cold/warm et la preuve de rollback restent
obligatoires apres provisioning, sans jamais etre inventees avant.

## Verrous #341 : preuves et limites

Le releve date et borne du **23 septembre 2026** est conserve dans
[`base-image-evidence/base-image-reconstruction.json`](base-image-evidence/base-image-reconstruction.json).
Ce fichier est la source des identifiants d'instance, timestamps, nombres de
paquets, empreintes et index sources. Le contrat epingle son SHA-256. Les fichiers
TSV, dpkg, APT et `build.info` associes sont des preuves selectionnees en lecture
seule, distinctes du dossier ignore `evidence/` des futures operations live.

La VM observee provient de l'URN exacte du contrat, pas d'une image voisine.
L'inversion des transactions dpkg conservees reconstitue la base avant bootstrap;
le rejeu reproduit exactement l'inventaire observe. Chaque version reconstruite
figure dans les index du snapshot immuable epingle par le contrat. Les trois
signatures `InRelease` ont ete verifiees avec `gpgv` et la cle Ubuntu Archive
2018; les tailles et SHA-256 des douze index compresses correspondent aux
metadonnees signees. Les URL et SHA-256 des `.deb` de base viennent de ces index :
les archives elles-memes n'ont pas toutes ete telechargees.

```bash
node infra/ci-runner/image/verify-base-image-evidence.mjs
```

Ce controle local verifie les empreintes des observations, la reconstruction,
le rejeu et la couverture du manifeste. Il ne refait pas une verification GPG
ni un telechargement reseau. Pour refaire la verification externe, recuperer les
`InRelease` et les `Packages.xz` aux URL snapshot de `sources`, verifier les
signatures avec la cle dont le fingerprint est consigne, puis les hashes des
index et les tuples Package/Version/Architecture/SHA256/Filename.

Le statut reste `reconstructed-not-independent` : les journaux invites ne sont
ni un inventaire signe par Canonical, ni une observation independante d'une VM
vierge. Toute lacune des journaux ou divergence d'une future observation vierge
invalide cette reconstruction; une autre version Marketplace demande son propre
releve. Les ajouts et upgrades posterieurs restent dans les journaux, jamais
assimiles a la base. L'installation d'`ubuntu-advantage-tools` est observee dans
l'historique APT; son auteur n'y est pas renseigne.

### Closure APT et Microsoft

`apt-packages.lock.json` distingue `packages` (archives des transactions) et
`snapshotResolvedPackages` (graphe resolu du snapshot, base comprise, **pas**
l'inventaire final observe sur la VM). Chaque tuple inclut version,
architecture, URL, taille, SHA-256 et index source; `controlSha256` lie les
metadonnees completes utilisees par le solveur. Les dependances deja satisfaites
par la base ne sont ni omises ni presentees comme de nouveaux telechargements.

`lock_apt.py` authentifie les `InRelease` avec `gpgv`, puis les index par
SHA-256/taille. Il reconstruit le statut dpkg depuis les paragraphes **complets**
des index correspondants, pas uniquement nom/version : Depends, Pre-Depends,
Provides, Multi-Arch, Conflicts, Breaks, Replaces, Essential et Recommends restent
disponibles au solveur. Les commandes et fallbacks sont lus dans les deux scripts
epingles et `bin/installdependencies.sh` extrait de l'archive runner verifiee.
Le hold d'Azure CLI, les recommandations et l'ordre des transactions sont gardes.
`apt-get check`, simulation et `--print-uris` doivent etre coherents.

Le solveur est **APT et libapt 2.8.3 du meme snapshot Noble**. Leurs paquets
amd64/arm64 sont identifies dans le lock; seule l'architecture du solveur depend
de l'hote. La cible est toujours amd64. Les paquets verifies sont extraits dans
un repertoire temporaire, sans installation sur l'hote. Les bibliotheques
systeme restantes viennent de l'hote : le rejeu doit produire le meme lock,
sinon il echoue. Ce calcul ne pretend pas etre un boot ni une installation Noble.
`APT_CONFIG` isole sources, preferences, hooks, caches et statut. La resolution
exige un namespace reseau ne contenant que `lo`; aucun `apt update` reseau n'y
est execute.

Le depot Microsoft **reste mutable**. `apt-index-evidence` conserve exactement
sa cle publique, son `InRelease` signe et son index `Packages`, avec leurs
hashes/provenance dans `indexes.json`. Un rejeu ne les actualise jamais. Il
recupere seulement les index Ubuntu du snapshot exact. Les hashes des paquets
sont authentifies par les index; la commande `download` mesure aussi les octets
des archives des transactions. Les archives de la base ne sont pas toutes
telechargees. La disponibilite future des URL Microsoft n'est pas garantie :
un futur stockage hors ligne devra conserver les blobs verifies.

L'oracle terrain couvre exactement les installations du bootstrap du 14/09.
Il exclut une seule transaction APT conservee : 19/09/2026 12:53:07--11Z,
`apt-get install ubuntu-advantage-tools -y`, version `37.2ubuntu~24.04.1`
(`:amd64` dans l'historique APT, `:all` dans dpkg a 12:53:09Z).
Les deux journaux sont verifies contre les hashes du rapport de base avant
lecture. Toute autre installation ou upgrade tardif, y compris du meme nom,
ainsi que toute suppression/purge, echoue.
Cette transaction coincide sur PR31/PR34 avec ConfigurePatching :
[preuves de #341](https://github.com/gchambaud_microsoft/Certigo/issues/341#issuecomment-5803012081).
Le client Ubuntu Pro de
[LinuxPatchExtension au commit source exact](https://github.com/Azure/LinuxPatchExtension/blob/119f1101f927096e5c25ed3b4463ac8306fdd0a3/src/core/src/package_managers/UbuntuProClient.py#L30)
execute cette commande. **La version de l'extension deployee n'a pas ete lue** :
ce commit source n'est pas presente comme le binaire observe. Les upgrades du
14/09 provenaient alors des depots courants; ils ne sont pas artificiellement
ajoutes a la resolution du snapshot du 07/08.
Le bootstrap live etait le blob `da050d7e`, dont les commandes d'installation
sont identiques a celles du bootstrap actuellement epingle; ce n'est pas une
preuve d'execution du bootstrap de main.

`observationReconciliation` rend cet ecart calculable : chaque transaction
bootstrap porte ses versions precedente, observee et resolue, avec son resultat
de comparaison. `unreproducedVersionTransactions` enumere les 22 upgrades
non reproduits par le snapshot impose. Les six ajouts bootstrap et l'unique
ajout plateforme expliquent les 663 paquets observes depuis les 656 de base.
Les trois ajouts propres au prewarm (`python3-pip-whl`, `python3-setuptools-whl`,
`python3.12-venv`) expliquent les 665 paquets resolus : 663 - 1 + 3.
Ces identites d'ensembles et cardinalites sont controlees; le snapshot ne doit
pas etre change pour faire artificiellement coincider les versions terrain.

### Graphe Flutter Linux x64

`lock_flutter.py` lit l'archive SDK apres verification de son SHA-256 et refuse
toute autre version tant que son evaluateur specialise n'a pas ete relu.
Le graphe est derive des classes du SDK epingle, notamment `PrecacheCommand`,
`FlutterCache`, `EngineCachedArtifact` et `PubDependencies`. Les sources lues
sont liees par `sdkSourceSha256`. Aucun binaire x64 du SDK n'est execute sur
l'hote ARM64; ce n'est **pas une trace d'execution native**.

Le point d'entree `bin/flutter` est aussi borne : snapshot flutter_tools et
Dart SDK presents, stamps moteur concordants, stamp outil coherent avec le HEAD
Git exact et `FLUTTER_TOOL_ARGS` vide, pubspec pas plus recent que son lock.
L'index Git v2 est conserve et lie par SHA; `engine.version` doit y etre suivi,
sinon `update_engine_version.sh` emprunterait le fallback content-hash.
Les sources `shared.sh`, `update_engine_version.sh`, `update_dart_sdk.sh` et
`features.dart` sont liees; le defaut Linux `Feature.fullyEnabled` est verifie.
`entrypointPreconditions` declare un SDK non modifie (Git et mtimes conserves),
un home/config vierge et aucun override Flutter/Pub/moteur/Git. Le futur
consommateur devra imposer ces conditions. Hors de ce domaine, `bin/flutter`
peut lancer `pub upgrade` et telecharger un autre Dart SDK : ce lock ne revendique
pas couvrir ces branches de re-resolution non bornee.

`--linux` selectionne Linux **et** les groupes universal/informative par defaut.
Le lock couvre fonts, Gradle wrapper, informations moteur, paquets sky_engine et
flutter_gpu, SDK patches, outils hote, GTK debug/profile/release et font-subset.
Il distingue `bundled-current` (cache deja present dans l'archive SDK selon les
predicats du SDK) de `download-required`. Tous ces blobs ont neanmoins ete
telecharges pour mesurer leurs SHA-256; les entrees integrees ne sont pas
presentees comme des requetes reseau effectivement executees par precache.
Les branches iOS USB sont sans telechargement sous Linux; les autres plateformes
ne sont pas selectionnees.

La branche universelle `PubDependencies` n'est pas oubliee : l'archive n'a pas
de `package_config.json` local pour flutter_tools ni de reference workspace
locale. Son `pub get` implique les archives de `packages/flutter_tools/pubspec.lock`.
Le script les enumere et verifie les SHA-256 du lock inclus dans le SDK.
Il ne declare pas le resolver Pub courant immuable et ne le lance pas en ligne.
Le futur consommateur devra fournir le cache ferme et imposer le lock hors
ligne, sans requete de metadonnees ni re-resolution implicite.

Les empreintes moteur mesurees sous HTTPS sont des **octets verifies et
rejouables**, pas une signature editeur independante. Les hashes Pub ont en plus
ete compares au lock de l'archive SDK epinglee.

### Rejouer sans modifier un runner

Depuis la racine du depot, sous Linux avec Python 3.11+, gpg/gpgv, dpkg-deb et
`unshare -n` (root ou namespace autorise), utiliser un cache prive hors depot :

```bash
IMAGE=infra/ci-runner/image
CACHE=/chemin/prive/apt-cache
# Rejeu : restaure Ubuntu, conserve Microsoft depuis le depot.
python3 -B "$IMAGE/lock_apt.py" restore-indexes --cache "$CACHE"
python3 -B "$IMAGE/lock_apt.py" capture-solver --cache "$CACHE"
# RUNNER_ARCHIVE et FLUTTER_ARCHIVE : archives aux URL du manifest;
# leur SHA-256 est reverifie AVANT extraction/lecture.
unshare -n python3 -B "$IMAGE/lock_apt.py" verify \
  --cache "$CACHE" --runner-archive "$RUNNER_ARCHIVE"
python3 -B "$IMAGE/lock_apt.py" download \
  --cache "$CACHE" --runner-archive "$RUNNER_ARCHIVE"
python3 -B "$IMAGE/lock_flutter.py" capture \
  --sdk-archive "$FLUTTER_ARCHIVE" --cache "$FLUTTER_CACHE" --output /tmp/flutter-recapture.json
unshare -n python3 -B "$IMAGE/lock_flutter.py" verify \
  --sdk-archive "$FLUTTER_ARCHIVE" --cache "$FLUTTER_CACHE"
python3 -B -m unittest discover -s "$IMAGE" -p 'lock_inputs_test.py'
```

Pour une nouvelle capture **explicitement revue**, `lock_apt.py capture`
remplace les preuves Microsoft; `resolve` ecrit un nouveau lock dans le
namespace sans reseau. Ne pas confondre cette operation de maintenance avec
`restore-indexes`/`verify`. Le telechargeur refuse les redirections, les blobs
vides et les hashes divergents; il ne suit pas une nouvelle URL implicitement.
La capture Flutter ecrit seulement un fichier propose; `resolve` permet de
recalculer ce fichier depuis les blobs deja acquis, sans reseau. `verify` le
compare au graphe et aux octets attendus du lock versionne.

Les tests courts sont inclus dans `validate.sh`. Les deux tests de replay complets
additionnels exigent les variables `CERTIGO_APT_CACHE`,
`CERTIGO_RUNNER_ARCHIVE`, `CERTIGO_FLUTTER_CACHE`, `CERTIGO_FLUTTER_ARCHIVE`;
ils sont explicitement marques ignores sans ces gros inputs, pas annonces
comme executes par le gate court. Chacun lance la vraie CLI `verify` cinq fois
dans `unshare -n` : original, omission, ajout, URL redirigee et hash altere.
Chaque mutation doit echouer sur la comparaison au graphe **recalcule**, pas
sur une autre erreur ni seulement sur une comparaison de fixtures.
Mesure du 24 septembre 2026 sous WSL ARM64 : 15 tests reussis, aucun ignore,
en 619,562 s apres la correction de l'index Git, dont ces dix executions CLI
hors reseau. Le gate court seul
execute les 13 autres tests et signale explicitement les deux tests ignores.

### Relecture independante

Relecture `rubber-duck`, agent `77cfb627-b939-4e57-a9e4-9f2d1d92ea52`,
24 septembre 2026 : scripts, deux locks, index Microsoft, oracle terrain,
sources Flutter/Pub, tests et maintien des gardes. Les constats ont conduit a :

- authentifier les deux logs et reconciler explicitement toutes les transactions
  de version, les upgrades hors snapshot et les ajouts prewarm;
- remplacer les seules mutations de fixtures par huit rejets via la vraie CLI;
- borner les branches du point d'entree Flutter et le defaut de la feature Linux;
- refuser les recettes APT dupliquees et remplacer le test d'absence du lock par
  celui du garde d'installation.

Le reviewer a verifie les 12 URL moteur/universelles contre les classes du SDK
et la correspondance exacte des 102 archives Pub (nom/version/SHA).
Il n'a pas execute les replays Linux ni verifie independamment les repertoires
de l'archive complete : ces mesures sont celles de l'implementatrice.
L'authenticite editeur des empreintes moteur et l'independance de l'inventaire
de base ne sont toujours pas demontrees. La contre-relecture a confirme les
corrections ci-dessus et les 11 tests canary; elle a releve un dernier manque,
l'index Git qui commande le fallback moteur. Cet index et sa precondition
ont ensuite ete ajoutes avec un test negatif. Aucun avis d'approbation global
ni reproduction independante des mesures WSL n'est presume.

### Consommateur hors ligne (#341, points 1 et 2)

`install_offline.py` est le seul chemin d'installation de l'image. Il tourne en
root dans `unshare --net` (aucune interface hors `lo`) et n'utilise que :

- les entrees du contrat : digest du contrat fourni par le template, SHA-256 de
  chaque entree, ensemble exact des fichiers (tout fichier en plus est refuse).
  Les modules Python effectivement charges doivent etre ces memes entrees;
- le store ferme de `image_artifacts.py`, adresse par digest, qui doit egaler
  exactement l'ensemble derive des locks : 7 archives de toolchain, les 9 `.deb`
  des transactions APT, 102 archives Pub et 94 roues Python, soit 212 artefacts.
  Les 656 paquets de base viennent de l'image Marketplace; les 12 blobs
  moteur/universels Flutter sont `bundled-current` dans l'archive SDK verifiee.

`image_artifacts.py acquire` est la seule etape reseau : URL exactes des locks,
HTTPS, variables proxy ignorees, aucune redirection sauf le saut documente
`github.com/<owner>/<repo>/releases/download/...` vers
`release-assets.githubusercontent.com` ou `objects.githubusercontent.com`,
publication atomique apres verification du digest et de la taille. `verify` est
hors ligne et exact. Une URL verrouillee disparue ou modifiee fait echouer
l'acquisition (`Download failed`, `Digest mismatch`), sans substitution.

Sentinelle : l'installateur ajoute des routes AnyIP (`local 0.0.0.0/0`, et
`::/0` si IPv6 existe) sur `lo`, puis ecoute DNS UDP/TCP 53 et TCP 22, 80, 443,
9418 et 11371. Une tentative est enregistree et fait echouer l'etape qui l'a
provoquee, avant son code de retour. Un auto-test DNS et TCP prouve la sentinelle
au demarrage. Hors de ces ports, une connexion echoue quand meme (aucune route
externe) mais n'est pas nommee.

| Resolveur du chemin image | Traitement |
| --- | --- |
| APT (bootstrap, prewarm, `installdependencies.sh`) | aucune source distante; les 9 `.deb` du lock installes transaction par transaction; etat dpkg egal aux 665 paquets du lock |
| `bootstrap.sh` | octets inchanges et epingles; execute confine une fois paquets, runner et Azure CLI presents; doit s'arreter a « Base image prepared » sans changer dpkg |
| `bin/installdependencies.sh` | jamais execute; digest egal a celui du lock, postconditions verifiees |
| pip | `--no-index --find-links` sur les roues verifiees, `--require-hashes`, `--only-binary=:all:`, `PIP_CONFIG_FILE=/dev/null`; aucun paquet en plus hors `pip` |
| Flutter/Pub | cache Pub prive (`dart pub cache preload` des 102 archives) puis `pub get --offline --enforce-lockfile`; `flutter config` et `flutter precache --linux` ne changent aucun octet du SDK (seul `bin/cache/lockfile` peut etre cree) |
| Node/npm, .NET/NuGet, Bicep, actionlint, dart-formatter | archives verifiees seulement, aucune restauration; telemetrie et notifications coupees |
| `contentTools.prewarmedProjectDependencies` | doit rester vide : verifie par l'installateur et au boot |
| Azure CLI | `.deb` du lock; son controle de version a l'initialisation est neutralise pendant l'installation (defaut 2 ci-dessous) |
| Mise a jour du runner | `--disableupdate` a l'enregistrement, hors installation |

Un resolveur non liste fait echouer l'installation : sentinelle, etat dpkg ou
inventaire.

### Transport des entrees : option (C')

Le depot est prive : un fetch anonyme de `raw.githubusercontent.com` rend 404, et
la doc AIB exige pour le customizer `File` des fichiers publics ou un stockage
Azure (#341, commentaire 5812238187). Le stockage (A') est ecarte pour cette
tranche : MCAPSGovDeployPolicies force `publicNetworkAccess=Disabled`,
`allowSharedKeyAccess=false` et `allowBlobPublicAccess=false` sur tout compte, ce
qui imposerait endpoint prive, DNS prive, NAT et droits supplementaires. Aucune
exemption par tag MCAPS n'est utilisee.

Les entrees voyagent donc dans le template : `loadFileAsBase64` par fichier, puis
decodage sous `/tmp`, verification du contrat contre le litteral
`contractSha256`, verification de chaque entree contre le contrat (`jq` et
`sha256sum --check --strict`), controle de l'ensemble exact, deplacement en
`sudo`. `loadFileAsBase64` refuse plus de 96 Ko (BCP184 a 98 304 octets, mesure
avec Bicep 0.44.1) et `loadTextContent` 131 072 caracteres : les deux gros locks
voyagent en derives `gzip -n -9` sous `transport/`. La CI prouve que leur
decompression redonne exactement les octets du lock et le SHA-256 du contrat;
une recompression differente reste admise.

`image-transport.test.mjs` evalue l'ARM compile, decode chaque entree, execute
les lignes de decodage et de verification sous `/bin/sh` (une session par ligne)
et prouve le refus d'une entree alteree, omise, ajoutee ou d'un contrat
substitue. Sa garde de taille impose au moins 10 % de marge sous chaque limite
documentee : template 4 Mo et ressource 1 Mo apres expansion (ARM « Template
limits »), job 1 Mo compresse (ARM « job size exceeded »). Mesure du 25 septembre
2026 : template 582 323 octets, 262 748 octets compresse. Aucune limite AIB sur
les commandes inline ou `customization.log` n'est documentee : une limite cachee
ferait echouer ferme le premier build, etape autorisee a part. Repli documente :
(A') si une telle limite apparait.

Toutes les lignes inline sont du sh POSIX et sortent en erreur d'elles-memes : la
doc AIB ne precise pas le shell utilise, et le `dash` de Noble refuse `pipefail`
(defaut 1). `packages.microsoft.com` reste mutable : si une URL verrouillee
disparait, l'acquisition echoue fermee. Un futur miroir prive des 212 blobs
verifies supprimerait cette dependance, mais demanderait les ressources de (A').

### Patching invite de la plateforme (#341, point 3)

Faits mesures (#341; `docs/CI_RUNNER_RESILIENCE.md`) :

- le 15/09 a 08:06:24Z, l'automate MCAPSGovernance-AutomationApp (appid
  `a1a9c5b6-7a4f-4288-89ab-6805873f65d1`, via Lighthouse) a bascule `patchSettings`
  des VM PR de `ImageDefault` a `AutomaticByPlatform`, avec
  `bypassPlatformSafetyChecksOnUserSchedule=true`; le modele VMSS reste `ImageDefault`;
- le 19/09 a 08:05Z, la meme tentative a echoue sur les VM trusted (image de galerie
  specialisee) : `PropertyChangeNotAllowed`, « Changing property 'osProfile' is not
  allowed ». Une image generalisee (sortie AIB) aura un `osProfile` modifiable : le
  canari doit supposer `AutomaticByPlatform`;
- une evaluation tourne depuis chaque jour sur les VM PR (le 24/09 de 05:48:51 a
  05:50:55Z) et lance `sudo apt-get -q update` ([LinuxPatchExtension @ 119f1101](https://github.com/Azure/LinuxPatchExtension/blob/119f1101f927096e5c25ed3b4463ac8306fdd0a3/src/core/src/package_managers/AptitudePackageManager.py#L51) :
  `AptitudePackageManager.py` l. 51 et 98, `PatchAssessor.py` l. 64).
  ConfigurePatching a installe `ubuntu-advantage-tools` le 19/09
  (`UbuntuProClient.py` l. 28 a 40). Le meme code sait aussi installer `mokutil` et
  `fwupd` (`AptitudePackageManager.py` l. 97 a 104);
- aucune assignation de maintenance. MCAPSGovDeployPolicies ajoute une identite
  managee aux VM sans identite (regle « modify »), aujourd'hui Compliant sur les
  VM PR qui restent sans identite.

Conception : la politique modifiant `osProfile`, l'image **assume** le patching
mais le prive de tout effet, puis **verifie** au boot et a chaque job :

1. aucune source APT distante : `apt-get update` ne rafraichit rien, la simulation
   `dist-upgrade` ne trouve rien et toute installation demandee par l'extension
   echoue (« Unable to locate package »);
2. `APT::Periodic::*` a `0`; unites `apt-daily*`, `unattended-upgrades` et
   `snapd.snap-repair*` masquees;
3. cloud-init `preserve_sources_list: true` : cloud-init 26.1 (celui de la base) ne
   regenere les sources que si ce drapeau est faux (`cc_apt_configure.py` l. 149);
   `package_update` et `package_upgrade` a `false`;
4. aucun snap : l'installateur refuse des le preflight un snap installe ou seede;
5. `validate-toolchain.sh --boot|--job` compare l'etat dpkg complet (paquet,
   architecture, version, etat) a `dpkg-state.tsv` atteste par `attestation.json`,
   et refuse une source APT, un `APT::Periodic` actif ou une unite demasquee.
   Toute derive empeche le demarrage du runner ou l'admission du job.

Rien n'est change cote Azure. Non couvert, par confiance dans la plateforme :
l'agent Azure et les extensions sous `/var/lib/waagent` tournent en root; une
modification hors paquets et hors racines inventoriees ne serait pas vue. La mise
a jour de certificats UEFI par `fwupd` (flux « cert » de l'extension) ne passe pas
par dpkg.

### Defauts latents mesures (masques jusqu'ici par les gardes)

1. **`pipefail` sous dash.** `chroot <base Noble> dash -c 'set -o pipefail'` rend
   « Illegal option -o pipefail » (dash `0.5.12-6ubuntu5`, 25/09/2026). Les
   customizers AIB commencaient tous par `set -euo pipefail`, et la doc AIB ne dit
   pas quel shell execute les lignes inline. Corrige : sh POSIX, sortie explicite.
2. **Azure CLI contacte le reseau a chaque demarrage.** Avec un
   `versionCheck.json` vide, Azure CLI 2.89.0 appelle, dans `AzCli.__init__` et
   avant toute commande, `handle_version_update` (`core/__init__.py` l. 105,
   `core/util.py` l. 1417) puis `get_cached_latest_versions` et
   `check_connectivity`, soit un HEAD vers `azcliprod.blob.core.windows.net`.
   `AZURE_CORE_COLLECT_TELEMETRY=false` n'y change rien : la sentinelle a compte
   8 requetes DNS pour un seul `az version`. Le bootstrap legacy le declenchait
   via `az version`. Corrige pendant l'installation : cache amorce hors ligne par
   `_get_local_versions` d'Azure CLI dans un `AZURE_CONFIG_DIR` prive. A
   l'execution, la validation de boot le declenche encore, reseau present, sans
   ecriture de paquet.
3. **Cout de l'inventaire.** L'ancien `inventory-toolchain.sh` lancait trois
   processus par fichier sur des dizaines de milliers de fichiers, au boot **et** a
   chaque job. Reecrit en lot, au meme format, avec un refus explicite des noms a
   tabulation ou saut de ligne et des types speciaux. Un test le compare a une
   reference Python independante.
4. **Cache Pub sous `/root`.** Le prewarm legacy lance `flutter precache --linux`
   en root sans `PUB_CACHE` : Pub prend alors `$HOME/.pub-cache`, soit
   `/root/.pub-cache` (`pub.dart` l. 620, `_getPubCacheIfAvailable`), et
   `package_config.json` de `flutter_tools` y pointe. `/root` est en `0700` dans la
   base (mesure). Or `PubDependencies.isUpToDate` exige que chaque racine de paquet
   soit lisible (`flutter_cache.dart` l. 113, sources epinglees) : pour
   l'utilisateur `runner`, le cache est perime et le premier job relancerait un
   `pub get` en ligne dans un SDK en lecture seule. Corrige : cache Pub prive dans
   l'arbre toolchain, lisible par tous et verifie.
5. **Propriete du depot Git Flutter.** `tar -xJf` en root conserve l'uid de
   l'archive; `bin/flutter` lance `git rev-parse HEAD`, que git refuse
   (« detected dubious ownership », exit 128, mesure dans le banc le 25/09). Le
   prewarm legacy aurait echoue a son premier `flutter config`. Corrige :
   extraction `--no-same-owner` et `safe.directory` limite a ce seul chemin dans
   `/etc/gitconfig`, fichier atteste par l'inventaire.
6. **SDK Flutter en lecture seule pour `runner` (non corrige ici).**
   `bin/internal/update_engine_version.sh` (SHA-256 `6d71ef5d...`, lie par le lock)
   reecrit `bin/cache/engine.stamp` et `engine.realm` a **chaque** appel de
   `flutter` ou `dart`. Mesure : avec `bin/cache` en lecture seule, un utilisateur
   non root sort en « Permission denied », exit 1; root reussit. Le scellement
   (`chmod -R a-w`, herite du prewarm) rend donc Flutter inutilisable par le
   runner. C'est un defaut d'execution du canari, hors des points 1 a 3 : il
   demande une decision de conception separee.

### Rejouer le consommateur sans modifier un runner

Sous Linux amd64, ou ARM64 avec un binfmt `qemu-x86_64` enregistre (paquets
`qemu-user` et `qemu-user-binfmt`), en root, avec `mmdebstrap`, overlayfs et
`unshare`. Les caches restent hors depot :

```bash
IMAGE=infra/ci-runner/image
S=/chemin/prive
python3 -B "$IMAGE/image_artifacts.py" acquire --store "$S/closed-store"
python3 -B "$IMAGE/offline_harness.py" acquire-base --store "$S/base-store"
python3 -B "$IMAGE/lock_apt.py" restore-indexes --cache "$S/apt-cache"
python3 -B "$IMAGE/offline_harness.py" build-base --store "$S/base-store" \
  --apt-cache "$S/apt-cache" --rootfs "$S/base-rootfs"
python3 -B "$IMAGE/offline_harness.py" run-suite --rootfs "$S/base-rootfs" \
  --store "$S/closed-store" --report "$S/suite.json" \
  --legacy-inventory /chemin/vers/ancien/inventory-toolchain.sh
```

`build-base` echoue si la base obtenue differe des 656 paquets reconstruits.
`capture-python-tags` recalcule `python-target-tags.txt` avec le pip de la cible;
`lock_python.py capture` recalcule ensuite le lock des roues, puis `verify` le
rejoue hors ligne (execute par `validate.sh`).

Les premiers tests compilent aussi les trois Bicep avec tous les drapeaux JSON
forces sur `locked/true/active`, et verifient que chaque ressource reste sous le
garde literalement faux. Le controle de transition lit les fichiers de lock
avant les attestations et tout appel Azure; le validateur de release applique
le meme refus. Le prewarm direct et le customizer AIB refusent eux aussi avant
le bootstrap mutable. Un digest correct est necessaire, jamais suffisant.
