# Traverser l'application de développement de bout en bout

> **Ce runbook remplace une hypothèse par une mesure.** L'onboarding de
> développement était infranchissable et le diagnostic reçu était « le backend de
> développement ne publie aucun parcours avec leçons ». **C'est faux, et mesuré
> comme faux le 2026-09-10** : le backend de développement publie 31 parcours,
> dont 26 avec 4 à 6 leçons. Le blocage était côté application.
>
> Discipline de preuve : voir `docs/GOVERNANCE.md` §7 « Discipline de mesure ».
> Chaque fait daté ci-dessous a une commande qui le rejoue.

## Ce que ce runbook permet

Lancer l'application en web, créer un compte, **terminer l'onboarding**, et
atteindre Accueil, Parcours, Ligue, Profil et Boutique — sans aucun accès Azure,
sans VM éphémère, sans écriture Cosmos.

## Mode d'emploi

```powershell
# 1. Servir l'app (réchauffe le backend, puis lance Flutter web)
pwsh tools/run_dev_web.ps1

# 2. Ouvrir http://127.0.0.1:8080 et créer un compte avec une adresse jetable.

# 3. Optionnel — un apprenant déjà avancé, via l'API publique uniquement
$env:CERTIGO_DEV_SEED_PASSWORD = 'choisis-un-mot-de-passe-jetable'
python tools/seed_dev_demo_account.py --lessons 2
```

`tools/seed_dev_demo_account.py` s'inscrit, résout un parcours **dans le
catalogue vivant**, le sélectionne, puis répond à de vraies leçons : la
progression est notée côté serveur, jamais injectée. Il refuse tout hôte qui
n'est pas manifestement de développement (`prod`, `staging`, ou un hôte
non identifié sont rejetés avant le premier appel).

Le mot de passe vient de l'environnement et **n'est ni généré, ni écrit, ni
réaffiché**. Une première version le générait et l'imprimait pour que l'opérateur
puisse se connecter ; CodeQL l'a refusée à raison
(`py/clear-text-logging-sensitive-data`, sévérité 7.0) : un outil qui imprime un
identifiant le dépose dans l'historique du terminal et dans les journaux de CI.

## Les trois obstacles réels, et lequel reste

### 1. L'onboarding proposait des parcours qui n'existaient pas — corrigé

L'identifiant de parcours servi par le catalogue **dépend du mode de contenu du
backend** (`CONTENT_REPOSITORY_MODE`) :

| Mode | Identifiant servi | Où |
|------|-------------------|-----|
| `legacy` | `az-900` | production |
| `versioned` | `microsoft.az-900.track.main` | **développement** |

L'application codait en dur les identifiants *legacy* et les comparait à
`track.id`. En développement l'intersection était donc toujours vide, et l'écran
de choix affichait « **Aucun parcours disponible — Réessaie quand le catalogue de
leçons aura été synchronisé.** » C'est ce message, et non un catalogue vide, qui
a été lu comme « le backend ne publie rien ».

Rejouer la mesure d'origine :

```powershell
$b='https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api'
# Le catalogue est plein :
(Invoke-WebRequest "$b/catalog/tracks" -Headers @{Authorization='Bearer dev'}).Content |
  ConvertFrom-Json | ForEach-Object { $_.tracks.Count }         # -> 31
# Mais l'identifiant historique n'existe pas :
Invoke-WebRequest "$b/me/paths/az-900" -Headers @{Authorization='Bearer dev'} -SkipHttpErrorCheck |
  Select-Object -ExpandProperty StatusCode                      # -> 404
```

La résolution se fait désormais sur le **code d'examen** et le **slug**, stables
dans les deux modes (`TargetCertification.matchesTrack`). La sélection envoie
l'`id` du catalogue, jamais l'identifiant codé en dur.

> **Portée au-delà du développement.** La production tourne en `legacy`, donc
> elle ne voyait pas la panne. Le plan d'activation du contenu versionné
> (`docs/plans/PUBLICATION_CONTENU_FACILE.md`) prévoit de basculer la production
> en `versioned` : sans ce correctif, cette bascule aurait rendu l'onboarding de
> production infranchissable à l'instant du flip.

### 2. Terminer une leçon renvoyait HTTP 500 — corrigé en code, **reste à déployer**

Toute soumission de quiz et toute génération d'examen passent par le garde-fou de
cadence `CosmosAttemptRepository.GetRecentActivityAsync`. Sa requête composait
deux agrégats dans un littéral d'objet — une forme que Cosmos rejette à
l'exécution :

```
Compositions of aggregates and other expressions are not allowed.
```

Mesuré le 2026-09-10 dans Application Insights `appi-certigo-dev` :

```powershell
$aid = az monitor app-insights component show -a appi-certigo-dev -g rg-certigo-dev --query appId -o tsv
az monitor app-insights query -a $aid --analytics-query `
  "requests | where timestamp > ago(1h) | where resultCode == '500' | project timestamp, name, operation_Id"
```

La requête projette désormais ses agrégats à plat. **Ce correctif ne prend effet
qu'après un déploiement du backend de développement** : tant qu'il n'est pas
déployé, Ligue affiche « Pas encore de ligue » et Accueil reste à 0 XP, parce
qu'aucune leçon ne peut aboutir.

Le garde `CosmosQueryShapeTests` échoue si la forme interdite revient. Il existe
parce que le seul test qui couvrait ce chemin,
`CosmosRepositoriesIntegrationTests`, exige un émulateur Cosmos et **est ignoré
par défaut** : il n'a jamais exécuté cette requête.

### 3. L'inscription expire au démarrage à froid — contourné par le lanceur

Le client abandonne une connexion après 12 s ; un démarrage à froid du Function
App de développement dépasse ce délai. L'échec est **silencieux à l'écran** :
le formulaire redevient simplement actif. `tools/run_dev_web.ps1` sonde
`/health` jusqu'à obtenir une réponse rapide avant de lancer Flutter.

## Contraintes Azure du développement, mesurées

Contrairement à ce qu'on pouvait supposer, **le développement porte les mêmes
contraintes réseau que la production** :

```powershell
az cosmosdb show -n cosmos-certigo-dev-bk3j5ja6vw23s -g rg-certigo-dev `
  --query "{public:publicNetworkAccess,localAuth:disableLocalAuth}"
# -> { "public": "Disabled", "localAuth": true }
```

Conséquence directe : **`python tools/seed_content.py --cosmos` ne peut pas
atteindre le Cosmos de développement** depuis un poste, exactement comme en
production (voir « Seed d'urgence du conteneur `content` de production »). Ce
n'était de toute façon pas la bonne piste : ce conteneur est le conteneur
*legacy*, et le développement lit le contenu *versionné*. L'y écrire aurait
rempli une base que l'application ne lit pas — un échec silencieux.

Différence avec la production : **aucun verrou** `lock-delete-protection` sur
`rg-certigo-dev` (`az lock list -g rg-certigo-dev` ne renvoie rien).

## Pourquoi cette méthode plutôt qu'une autre

| Option envisagée | Écartée parce que |
|---|---|
| Seed Cosmos via `seed_content.py --cosmos` | Réseau fermé en dev, **et** mauvaise cible : écrit le conteneur legacy alors que dev lit le versionné. |
| VM éphémère dans le VNet, comme le seed d'urgence prod | Résout un problème que le développement n'a pas : le contenu y est déjà publié et promu. |
| Activer le pipeline de contenu versionné sur dev | **Déjà actif** : `CONTENT_REPOSITORY_MODE=versioned`, release promue, 1735 fichiers publics. Rien à activer. |
| Basculer dev en `legacy` pour coller à l'app | Ferait reculer dev, et masquerait le défaut client qui attend la production au moment du flip. |

Le blocage n'était pas une absence de contenu : c'était une application
incapable de nommer le contenu présent. Le correctif est donc côté application.

## Vérifier sans lancer l'application

```powershell
# L'onboarding résout bien les deux formes d'identifiant
cd apps/mobile; flutter test test/onboarding_versioned_catalog_test.dart

# Aucune requête Cosmos ne compose d'agrégats dans un littéral d'objet
cd backend; dotnet test tests/Certigo.Infrastructure.Tests/Certigo.Infrastructure.Tests.csproj `
  --filter "FullyQualifiedName~CosmosQueryShapeTests"
```

## Ce qui reste ouvert

- Le correctif Cosmos doit être **déployé sur le développement** pour que la
  progression (XP, série, gemmes, ligue) apparaisse. Tant qu'il ne l'est pas,
  les cinq écrans sont atteignables et affichent leur structure réelle, mais
  Accueil, Ligue et Boutique montrent un apprenant à zéro.
- Le contenu servi en développement provient du dépôt `certigo-content` et ne
  correspond pas à `content/` dans ce dépôt : AZ-900 y a une seule leçon
  « practice » alors que `content/az-900/lessons/` en contient douze. Les deux
  sources coexistent ; ce runbook ne tranche pas laquelle doit gagner.
