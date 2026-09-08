# ADR-018 — Runners CI hybrides : VMSS de référence et ACA Jobs en complément PR

| Champ | Valeur |
|---|---|
| **ADR** | 018 |
| **Statut** | **Accepté pour un pilote limité, sans provisionnement** |
| **Date** | 2026-08-20 |
| **Décision** | Conserver les VMSS comme cible principale. Évaluer ACA Jobs uniquement comme capacité éphémère complémentaire pour quelques jobs PR Linux, stateless, sans secret, identité Azure, Docker ni accès privé. |
| **Périmètre** | Décision documentaire. Aucun changement Azure, GitHub Actions ou IaC. |
| **Provenance** | Évaluation ACA locale `8d09f7d`, recalée sur `origin/main` après le lifecycle VMSS fusionné par #309 (`8495b91`). |

## Décision courte

Certigo adopte une **architecture hybride**, pas un remplacement global :

- les VMSS restent la plateforme de référence pour `certigo-trusted`, macOS, les
  déploiements, releases, jobs lourds, jobs Docker/services, l'émulateur Cosmos et les
  charges qui nécessitent une identité Azure, un réseau privé ou un disque important ;
- un pilote ACA Jobs peut absorber une partie de `certigo-pr`, avec un label exclusif
  `certigo-pr-aca`, au plus deux exécutions concurrentes et un runner JIT éphémère par job ;
- la capacité ACA ne partage aucune identité, aucun secret, environnement, cache, volume,
  réseau applicatif ou label avec les VMSS ;
- le pilote n'est activé qu'après correction complète des labels VMSS et preuve que le
  lifecycle versionné par #309 reste fail-closed. Son contrôleur demeure désactivé jusque-là.

ACA réduit le blast radius d'une PR et peut réduire la file et le coût variable. Il ne
répond pas aux contraintes de compatibilité et de confiance des jobs opérationnels.

## Preuves disponibles sur `origin/main`

### État et incidents observés

- Les runners hébergés par GitHub sont interdits par politique d'organisation. Le run
  `28782170300` échoue en `startup_failure` en environ 4 secondes : il ne constitue pas
  un fallback.
- La saturation des runners a déjà imposé de réduire la fréquence des automatisations
  (`91d7887`) et de limiter les approbations automatiques (`33a3d69`).
- Le SPOF historique a nécessité l'ajout d'une seconde capacité et d'un drill
  (`e09aec5`).
- Le scale-in CPU du VMSS legacy ne connaît pas l'état GitHub `busy`. #309 ajoute une
  quiet period réinitialisable, deux gardes, une garde finale, un lease générationnel,
  un compare-and-swap d'état, un ordre pilote-avant-trusted et le réarmement exact des
  slots. Le contrôleur reste `enabled=false` tant que les frontières ne sont pas saines.
- Le live documenté comporte deux bindings gérés et versionnés :
  `f55d176e`/runner 27 sur le VMSS legacy et `bbf83c5c`/runner 28 sur le VMSS PR isolé.
  Au snapshot du 20 août, le premier conservait encore des labels doubles.

### Addendum live du 4 septembre 2026

L'inventaire Azure/GitHub read-only remplace le dernier constat opérationnel, sans
changer la décision d'architecture :

- `f55d176e` est désormais exclusivement `certigo-trusted` et `bbf83c5c`
  exclusivement PR (`certigo-pr,certigo-pr-pilot`) ; les deux VM ont été
  redémarrées le 3 septembre et sont running/online ;
- `vmss-certigo-runner-zonal_be505fa1` est restée `deallocated`, sans runner
  GitHub ni ownership démontré. Elle n'est ni adoptée ni ajoutée aux exclusions :
  une instance non classifiée doit continuer à bloquer ;
- l'autoscale legacy est toujours actif en 2/2/4, avec scale-out CPU
  `> 70 % / 10 min` et scale-in `< 20 % / 45 min`. Le contrat
  `infra/ci-runner/capacity.bicep` conserve seulement le scale-out ;
- les deux VMSS sont référencés `existing`; `network.bicep` référence aussi
  l'IP, la NAT, le NSG et le VNet `existing`, puis gère uniquement le
  sous-réseau enfant et des extensions de tags isolées ;
- le contrôleur queue-driven reste `enabled=false`. La correction IaC ne vaut ni
  activation du contrôleur, ni autorisation de drill, ni décision sur ACA.

### Baseline 30 jours

Source : `infra/ci-runner/capacity-controller.config.json`, capture du 2026-08-19.

| Indicateur | VMSS observé | ACA pilote |
|---|---:|---:|
| Jobs | 413 | Pas encore mesuré |
| Runner-heures | 18,84 h | Pas encore mesuré |
| CPU moyen | 3,78 % | Sans objet ; facturation à l'exécution |
| File P50 | **Non capturée** | À capturer obligatoirement |
| File P95 | 5 108 s (85 min 08 s) | Cible chaude < 120 s ; froide < 240 s |
| File P99 | 12 628 s (3 h 30 min 28 s) | Cible < 300 s |
| Coût CI complet | 242,06 USD | Pas encore mesuré |

Le P50 historique ne peut pas être reconstitué depuis la preuve versionnée. Il ne doit
pas être inventé. Le pilote doit publier P50, P95 et P99 avec la même définition :
`workflow_job.created_at` jusqu'au démarrage effectif du job.

## Comparaison

| Axe | VMSS versionnés | ACA Jobs éphémères | Conséquence |
|---|---|---|---|
| File | P95/P99 très dégradés sur la baseline ; capacité chaude une fois disponible | Scale-out par profondeur de file, mais poll KEDA, placement, pull, JIT et connexion ajoutent un cold-start | ACA convient aux jobs assez longs pour amortir le démarrage, pas aux micro-gates |
| Coût | 242,06 USD/30 j pour tout le scope CI ; coûts fixes même avec 3,78 % CPU moyen | À 18,84 h, estimation brute de l'étude : ~5,70 USD en 2 vCPU/4 Gio ou ~11,39 USD en 4 vCPU/8 Gio, hors ACR, logs, réseau et egress | Économie réelle uniquement si des heures VMSS sont effectivement supprimées ; sinon ACA est incrémental |
| Cold-start | Runner chaud rapide ; démarrage/réallocation VMSS de l'ordre de minutes lorsqu'il est éteint | Poll 0–30 s, puis placement, pull d'image, JIT et connexion ; aucun SLO fournisseur du runner complet | Mesurer chaud et scale-to-zero séparément |
| Maintenance | OS, bootstrap, service runner, disque, image Marketplace, lifecycle Azure/GitHub et drift | Images immuables par famille, SBOM/signature/scan, version runner, scaler, JIT, cleanup et export de logs | ACA réduit la maintenance d'instance, mais ajoute une supply chain conteneur et un plan de contrôle |
| Sécurité/trust | #309 fournit Trusted Launch, Secure Boot, vTPM, chiffrement hôte, réseau PR isolé, blocage IMDS et lifecycle fail-closed ; persistance à traiter comme exposée au code PR | Destruction après un job et absence d'identité réduisent la persistance et le blast radius ; le scaler et la GitHub App deviennent critiques | ACA est favorable pour du code PR seulement si le secret de contrôle n'entre jamais dans le conteneur runner |
| Docker/services | Support VM complète, Docker, services et privilèges contrôlés | Pas de Docker-in-Docker, socket hôte, conteneur privilégié, `hostPath`, action Docker ou service container | Toute charge Docker/services reste VMSS |
| Cosmos | Le runner isolé feature-off peut héberger Docker et l'émulateur | Émulateur local incompatible ; aucun accès au Cosmos privé pendant le pilote | Tests Cosmos restent VMSS |
| Disque/outillage | Disque Premium 128 Gio et outillage lourd possible | Consumption limité à 4 vCPU/8 Gio, 8 Gio éphémères et 8 Go d'images cumulées | Flutter/goldens, Android, CodeQL et scans lourds restent VMSS jusqu'à preuve contraire |
| Fiabilité | Plateforme connue, mais historique de SPOF, saturation et risque de scale-in ; #309 clôt les races dans le plan, pas encore son activation live | Une exécution = un job, retries plateforme à zéro ; dépendance au scaler, au pull, au JIT et au cleanup | Le pilote doit fonctionner en complément, avec VMSS conservé comme rollback |
| Blast radius | Une VM persistante peut traiter plusieurs jobs successifs ; séparation PR/trusted impérative | Réplique, label, environnement et sous-réseau dédiés, détruits après un job | Incident ACA limité aux jobs pilotes ; jamais de fallback vers `certigo-trusted` |

## Architecture cible

### VMSS : socle durable

Conserver deux classes exclusives :

```text
self-hosted, Linux, X64, certigo-pr
self-hosted, Linux, X64, certigo-trusted
```

Le VMSS PR reste la capacité de compatibilité et de rollback. Le VMSS trusted reste
l'unique capacité Linux autorisée à recevoir environnements, secrets, OIDC, identité
Azure ou réseau privé. Le lifecycle #309 reste l'autorité pour toute réallocation ou
désallocation VMSS ; ACA ne le remplace pas.

### ACA : complément PR explicite

Le pilote utilise un label distinct :

```text
self-hosted, Linux, X64, certigo-pr-aca
```

Contrat initial :

| Paramètre | Valeur |
|---|---:|
| Exécutions minimales | 0 |
| Exécutions maximales | 2 |
| Intervalle de polling | 30 s |
| Longueur de file cible | 1 |
| Parallélisme / complétions | 1 / 1 |
| Retry ACA | 0 |
| Timeout | P99 du job + marge, plafond initial 30 min |
| Rétention logs | 30 jours hors réplique |

Une GitHub App dédiée, limitée au dépôt, alimente le scaler et génère une configuration
JIT. Sa clé n'est jamais injectée dans le conteneur principal. Le runner traite un seul
job, se désenregistre et disparaît. Un reconciler de contrôle ne supprime que les runners
ACA offline au nom signé et au TTL dépassé ; jamais un runner busy ou VMSS.

Le pool n'a aucune identité Azure de workload, aucun `id-token: write`, accès RFC1918,
peering applicatif, secret de workflow, environnement, cache partagé ou volume
persistant. Images par digest, SBOM, provenance, signature et scan sont obligatoires.

## Jobs éligibles

### Première vague recommandée

Migrer un job à la fois, sans changer sa logique :

1. `ci-content.yml / validate` ;
2. `ci-migration-registry.yml / validate` ;
3. `lint-workflows.yml / validate` ;
4. `ci-project-state.yml / validate-source`.

Ces jobs sont Linux, stateless, sans environnement, secret, identité Azure, Docker ou
service. Les sélecteurs de chemins (`changes`) et `fork-pr-policy / trust-gate` sont
techniquement compatibles mais restent d'abord sur VMSS : leur durée courte risque
d'être inférieure au cold-start ACA.

### Deuxième vague conditionnelle

`ci-mobile.yml / packages` peut être évalué après la première vague si une image Dart
immuable respecte le budget disque et si le cold-start n'annule pas le gain de file.
`ci-backend / build-test`, la parité Cortex et `ci-infra / bicep-build` exigent une
évaluation séparée des images, artefacts, durées et téléchargements ; ils ne font pas
partie du pilote initial.

### Jobs qui restent VMSS

- tous les jobs `certigo-trusted`, notamment gates agrégées, Pages, déploiements et
  promotions ;
- `cd-backend`, `release-android`, `release-ios`, `sync-ios-certs` et la chaîne macOS ;
- tests Docker/services et émulateur Cosmos ;
- Flutter app, Prism goldens, CodeQL et scans lourds tant que disque, mémoire et durée
  n'ont pas été prouvés ;
- `runner-health` et `runner-resilience-drill`, qui valident spécifiquement les VMSS ;
- toute charge future avec secret, environnement, OIDC, identité Azure, réseau privé,
  Docker, privilège, montage hôte ou cache partagé.

## Seuils go/no-go

### Préconditions avant le premier job ACA

Toutes sont obligatoires :

- labels `certigo-pr` et `certigo-trusted` mutuellement exclusifs sur les VMSS ;
- lifecycle #309 testé en lecture et toujours fail-closed en cas de `busy`, job en file,
  drift, lease obsolète ou binding inconnu ;
- GitHub App minimale avec rotation et révocation testées ;
- image par digest, SBOM, signature, scan et runner âgé de moins de 30 jours ;
- absence d'identité et tests négatifs IMDS/RFC1918/ressources privées ;
- JIT one-job, retry zéro, cleanup d'orphelins et export `_diag` prouvés ;
- rollback vers le label VMSS `certigo-pr` répété sans changer la logique du job.

### Go après 30 jours

Le pilote peut s'étendre seulement si :

- zéro violation de trust, secret, identité, réseau, supply chain ou cleanup ;
- 100 % des exécutions traitent au plus un job et zéro job est pris en double ;
- taux de démarrage ACA >= 99 % et taux de succès infrastructurel >= 99 % ;
- file P95 < 120 s image chaude, P95 < 240 s après scale-to-zero et P99 < 300 s ;
- aucune régression de plus de 10 % du P50 de durée d'exécution du job hors attente ;
- maximum disque < 75 % de la limite et aucun OOM/timeout plateforme ;
- coût marginal ACA complet <= 25 % de la baseline CI, soit 60,52 USD/30 j, et coût CI
  total <= budget actuel de 275 USD ;
- la réduction annoncée des heures VMSS est observée, pas seulement modélisée.

Une migration durable au-delà du pilote exige en plus deux mois complets montrant au
moins 20 % de baisse de la baseline CI après réduction sûre de capacité VMSS.

### No-go immédiat

Un seul des événements suivants arrête le pilote :

- accès à une identité Azure, IMDS, RFC1918, secret, environnement ou ressource privée ;
- runner réutilisé, double prise en charge, runner orphelin non nettoyé au TTL ou logs
  indisponibles après destruction ;
- image non signée/non scannée, digest mutable ou version runner hors fenêtre ;
- P99 de file >= 300 s pendant trois jours consécutifs, démarrage < 99 %, OOM ou limite
  disque dépassée ;
- coût total CI > 275 USD projeté ou absence de réduction mesurable des heures VMSS ;
- besoin de Docker, service container, privilège, montage hôte ou cache partagé.

## Rollback

Le rollback est un changement de routage documentaire et de workflow futur, pas un
échange de labels entre frontières :

1. arrêter l'envoi de nouveaux jobs au label `certigo-pr-aca` ;
2. laisser finir les exécutions ACA `busy`, sans retry plateforme ;
3. remettre les jobs pilotes sur leur sélection VMSS précédente
   `[self-hosted, Linux, X64, certigo-pr]` ;
4. confirmer le retour des checks requis et leurs artefacts ;
5. supprimer uniquement les runners ACA offline signés par le contrôleur, puis la
   capacité ACA pilote selon son runbook ;
6. conserver les VMSS et le lifecycle #309 inchangés.

Ne jamais ajouter temporairement `certigo-trusted` à un runner ACA ou PR, et ne jamais
désactiver une gate requise pour accélérer le rollback.

## KPI du rapport à 30 jours

Publier par job et agrégé :

| Domaine | KPI |
|---|---|
| File | P50/P95/P99 queue-to-start, séparés image chaude et scale-to-zero |
| Cold-start | Poll, placement, pull, JIT et connexion ; taux de démarrage |
| Exécution | P50/P95/P99 de durée hors attente, succès infrastructurel, retries GitHub |
| Capacité | Profondeur de file, concurrence ACA, heures VMSS running/deallocated |
| Fiabilité | Jobs doublés, runners orphelins, cleanup TTL, logs `_diag` disponibles |
| Ressources | Pic CPU/mémoire/disque, OOM, timeouts, taille et pull d'image |
| Sécurité | Accès IMDS/RFC1918/privé, identité/token exposé, résultats scan/signature |
| Coût | ACA compute, ACR, logs, NAT/egress, coût par job/minute, coût CI total et delta VMSS |
| Blast radius | Jobs affectés par incident ACA, temps de rollback et succès des checks VMSS |

## Références

- `docs/CI_RUNNER_RESILIENCE.md`
- `docs/runbooks/CI_RUNNERS.md`
- `docs/runbooks/CLOUD_LEAST_PRIVILEGE.md`
- `infra/ci-runner/README.md`
- `infra/ci-runner/capacity-controller.config.json`
- ADR source locale : commit `8d09f7d`
- Lifecycle VMSS fusionné : #309, commit `8495b91`
- Azure Container Apps Jobs :
  <https://learn.microsoft.com/azure/container-apps/jobs>
- Runners GitHub Actions sur ACA Jobs :
  <https://learn.microsoft.com/azure/container-apps/tutorial-ci-cd-runners-jobs>
- Limites des conteneurs ACA :
  <https://learn.microsoft.com/azure/container-apps/containers>
- Runners GitHub éphémères et JIT :
  <https://docs.github.com/actions/reference/runners/self-hosted-runners>
