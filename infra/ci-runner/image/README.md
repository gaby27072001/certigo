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
  les paquets transitifs Ubuntu/Microsoft ne sont pas lies a un snapshot APT et
  a leurs hashes, et que les artefacts du `flutter precache` ne sont pas tous
  enumeres et hashes. PR2 n'assimile jamais une version seule a une preuve de
  reproductibilite;
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

**Reste obligatoire avant `locked` :**

1. Faire relire cette reconstruction, resoudre puis verrouiller la fermeture
   finale Ubuntu **et** Microsoft, incluant les dependances de prewarm et du
   runner. Le manifeste de base n'est pas `apt-packages.lock.json`.
2. Enumerer et hasher les artefacts effectivement consommes par le SDK Flutter
   epingle, son precache Linux et ses entrees universelles. Le commit moteur
   publie pour Flutter 3.44.4 est
   `a10d8ac38de835021c8d2f920dbf50a920ccc030`
   ([source au commit Flutter exact](https://github.com/flutter/flutter/blob/ad70ec4617166f1c38e5d2bfd388af71fda14f06/bin/internal/engine.version)).
   Ce commit seul n'est pas `flutter-engine-artifacts.lock.json`.
3. Remplacer ou confiner, dans le chemin image uniquement, tous les resolvers
   reseau : bootstrap, `installdependencies.sh`, APT, pip et Flutter. Verifier
   les octets avant execution et prouver l'installation sans reseau depuis
   l'ensemble ferme d'artefacts approuve.
4. Ajouter les tests d'execution de ce consommateur (alteration, omission,
   redirection, telechargement imprevu), puis seulement retirer les gardes de
   code. Les tests actuels portent sur l'integrite des fichiers et le **refus
   d'admission** : des propositions redirigees ou ajoutees, meme rehashees, ne
   peuvent rien activer. Ils ne pretendent pas valider un downloader inexistant.
5. Activer et epingler le signataire dans le changement separe prevu par #497.
   Aucun workflow actif ni le workflow signataire desactive n'est modifie ici.

Les premiers tests compilent aussi les trois Bicep avec tous les drapeaux JSON
forces sur `locked/true/active`, et verifient que chaque ressource reste sous le
garde literalement faux. Le controle de transition lit les fichiers de lock
avant les attestations et tout appel Azure; le validateur de release applique
le meme refus. Le prewarm direct et le customizer AIB refusent eux aussi avant
le bootstrap mutable. Un digest correct est necessaire, jamais suffisant.
