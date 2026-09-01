# Image runner immuable - PR1

Ce dossier est un livrable **hors deploiement**. Il fige la toolchain deja utilisee
par Certigo, telecharge chaque artefact par URL versionnee, verifie son empreinte,
produit une attestation locale et refuse le demarrage du service runner si le boot
ne retrouve pas exactement le meme contenu.

Il ne modifie aucun VMSS, SKU, capacite, label, binding, identite, route, IP
publique, acces prive ou automate de lifecycle. `runner.bicep`, `pilot.bicep`, les
inventaires live et les IDs hors scope ne referencent pas cette image dans PR1.

## Contenu

- `toolchain-manifest.json` est la source de verite des versions et empreintes;
- `toolchain-sbom.cyclonedx.document` est le SBOM CycloneDX 1.6 de l'image, y compris
  chaque paquet transitif de l'environnement Python;
- `toolchain-requirements.lock` verrouille avec hashes tout l'environnement
  Checkov/PyYAML Python 3.12;
- `prewarm-toolchain.sh` installe les SDK et outils sans `npm ci`, `dotnet restore`
  ni `flutter pub get`: aucun cache de dependances projet n'entre dans l'image;
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

Le build d'image devra executer, sur Ubuntu 24.04 x64:

```bash
sudo bash infra/ci-runner/bootstrap.sh
sudo bash infra/ci-runner/image/prewarm-toolchain.sh
```

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
