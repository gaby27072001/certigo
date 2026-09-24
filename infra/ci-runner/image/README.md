# Image runner immuable

Ce dossier est un livrable **hors deploiement**, dont l'installation reste
**bloquee**. Les archives principales de la toolchain sont epinglees, mais les
entrees reseau transitives ne sont pas encore toutes verrouillees. Une attestation
de fichiers installes ne prouve pas la reproductibilite des telechargements qui
les ont produits. Les controles de boot prevus refusent un contenu different.

Il ne modifie aucun VMSS, SKU, capacite, label, binding, identite, route, IP
publique, acces prive ou automate de lifecycle. `runner.bicep`, `pilot.bicep`, les
inventaires live et les IDs hors scope ne referencent pas cette image dans PR1.

## Contenu

- `toolchain-manifest.json` est la source de verite des versions et empreintes;
- `toolchain-sbom.cyclonedx.document` est le SBOM CycloneDX 1.6 de l'image, y compris
  chaque paquet transitif de l'environnement Python;
- `toolchain-requirements.lock` verrouille avec hashes tout l'environnement
  Checkov/PyYAML Python 3.12;
- `prewarm-toolchain.sh` conserve le futur chemin d'installation des SDK, mais
  refuse actuellement toute execution avant une ecriture ou un telechargement;
- `validate-network-inputs.mjs` exige les deux vrais fichiers de lock et leurs
  empreintes, puis refuse encore l'admission tant que le consommateur hors ligne
  et ses preuves d'exhaustivite ne sont pas implementes;
- `validate-toolchain.sh --boot` verifie manifest, SBOM, lock, attestation,
  versions et l'inventaire exhaustif (fichiers, repertoires, liens, modes et
  hashes) des toolchains, du runner et d'Azure CLI; tout ajout inattendu echoue;
- le generateur systemd ajoute `Requires=certigo-toolchain-validate.service` a
  l'unique service `actions.runner.*`: un mismatch empeche son demarrage;
- `certigo-job-temp-mount.service` bind-monte le workspace runner reel sur le
  disque temporaire `/mnt/certigo-job`; `job-temp.sh` detruit ensuite workspace
  et caches NuGet/npm/pub/.NET au debut et a la fin de chaque job;
- `measure-cold-start.sh` emet les timestamps monotoniques validation/runner du
  futur canari.

Le controle d'admission suivant **doit echouer** dans cet etat du depot:

```bash
node infra/ci-runner/image/validate-network-inputs.mjs
```

Ne pas executer le bootstrap existant pour contourner ce refus. Il reste le
bootstrap mutable des runners actuels et appelle notamment
`bin/installdependencies.sh`; il n'est pas un installateur d'image reproductible.

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
  `deploymentEnabled=true` et des drapeaux JSON falsifies, tant que
  le consommateur exhaustif hors ligne et ses preuves ne sont pas implementes.
  Les locks decrits plus bas ne suffisent pas a lever ce garde. PR2 n'assimile
  jamais une version seule a une preuve de reproductibilite;
- `image-build.bicep` declare la Gallery, la definition et le template Azure VM
  Image Builder. `deploymentEnabled=false` et `autoRun=Disabled`: compiler ou
  deployer le modele sans parametre explicite ne construit rien;
- le build utilise une identite user-assigned dediee uniquement pour ecrire la
  nouvelle version Gallery. Cette identite n'entre pas dans l'image. Les
  sources viennent du commit exact, AIB reverifie chaque hash, la validation
  in-VM refuse `.runner`, credentials, cle privee, cache ou boot non conforme;
- lorsque les locks seront complets dans une PR ulterieure, le tout premier
  customizer bloque IMDS et en apporte la preuve avant les telechargements
  necessaires. La validation finale et le bootstrap canari exigent aussi le
  service actif, la regle iptables et un probe IMDS en echec;
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

**Reste obligatoire avant `locked` et installation :**

1. Remplacer ou confiner, dans le chemin image uniquement, tous les resolvers
   reseau : bootstrap, `installdependencies.sh`, APT, pip et Flutter. Verifier
   les octets avant execution et prouver l'installation sans reseau depuis
   l'ensemble ferme d'artefacts approuve.
2. Ajouter les tests d'execution de ce consommateur (alteration, omission,
   redirection, telechargement imprevu), puis seulement retirer les gardes de
   code. Les tests actuels portent sur l'integrite des fichiers et le **refus
   d'admission** : des propositions redirigees ou ajoutees, meme rehashees, ne
   peuvent rien activer. Ils ne pretendent pas valider un downloader inexistant.
3. Traiter le patching invite de la plateforme : il peut installer ou mettre a
   jour des paquets apres le boot. Le futur contrat devra soit le neutraliser
   sur les nouveaux runners, soit l'assumer et le verifier au boot. Rien de
   cela n'est modifie ici.
4. Activer et epingler le signataire dans un changement separe approuve.
   Aucun workflow actif ni le workflow signataire desactive n'est modifie ici.

Les premiers tests compilent aussi les trois Bicep avec tous les drapeaux JSON
forces sur `locked/true/active`, et verifient que chaque ressource reste sous le
garde literalement faux. Le controle de transition lit les fichiers de lock
avant les attestations et tout appel Azure; le validateur de release applique
le meme refus. Le prewarm direct et le customizer AIB refusent eux aussi avant
le bootstrap mutable. Un digest correct est necessaire, jamais suffisant.
