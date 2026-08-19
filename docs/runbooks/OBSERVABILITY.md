# Observabilite minimale

Ce runbook decrit les signaux ajoutes sans nouveau service, changement de SKU,
Sentinel ni Front Door. Le comportement produit et les endpoints restent
inchanges.

## Baseline et objectifs

La baseline mesuree avant ce changement est :

- production : 6 requetes sur 30 jours, P95 2,067 s, aucun 5xx ;
- staging : 23 requetes, dont 13 reponses 5xx hors endpoints de sante ;
- aucun webtest dans `AppAvailabilityResults` ;
- cold-start non mesure ;
- aucun 429 Cosmos, avec couverture partition/storage incomplete ;
- ingestion de logs notable au regard du trafic.

Le module `infra/modules/diagnostics.bicep` ajoute ou ajuste :

- le test readiness existant `availability-<function-app>` est conserve sans
  renommage, et un seul test standard externe `availability-<function-app>-live`
  est ajoute ; tous deux s'executent toutes les cinq minutes depuis Amsterdam
  et Ashburn ;
- une alerte par test, uniquement si les deux localisations echouent ;
- une alerte au premier 5xx hors endpoints de sante sur 15 minutes ;
- une alerte readiness et une alerte d'absence totale de requetes sur
  15 minutes, intervalle normalement alimente par les tests synthetiques ;
- un workbook agrege Functions, Cosmos DB et Storage ;
- la metrique `functions.cold_start`, emise une seule fois par processus
  Functions avec deux dimensions statiques ;
- une retention Log Analytics de 30 jours en dev et 90 jours dans les
  environnements hardened (staging et production), sans
  `immediatePurgeDataOn30Days`, afin de conserver les logs de suppression ; le
  sampling adaptatif reste borne a 5 elements par seconde. Les requetes et
  exceptions restent exemptes afin que les alertes demeurent fiables au faible
  volume observe.

Le workflow runner quotidien publie dans son Step Summary des metriques de
lifecycle, attente du run courant, taille agregee des caches locaux, latence
des registres NuGet/pub.dev/npm et duree totale du probe. Ces signaux restent
dans GitHub Actions : aucun backend de metriques ni stockage Azure n'est ajoute.

## Confidentialite et cardinalite

Les webtests n'envoient ni header, ni query string, ni body. Ils ciblent
uniquement les deux endpoints anonymes et bornes de sante. La metrique
cold-start ne contient ni identifiant d'instance, utilisateur, requete,
operation ou adresse.

Le workbook n'affiche aucun URL, operation id, partition key, payload ou
identite. Les vues partition Cosmos exposent uniquement des agregats
`P95`, `max` et `dcount`. Ne jamais ajouter de valeur de partition brute :
les partitions peuvent etre correlees a un utilisateur.

## Cout marginal estime

Tarifs publics Azure Retail Prices West Europe consultes le 19 aout 2026 :

- `Standard Web Test Execution` : **0,0006 EUR par execution**
  ([meter `301dd520-69b3-52a7-9ad2-3cd457b79fb8`](https://prices.azure.com/api/retail/prices?currencyCode=%27EUR%27&$filter=serviceName%20eq%20%27Azure%20Monitor%27%20and%20armRegionName%20eq%20%27westeurope%27%20and%20meterName%20eq%20%27Standard%20Web%20Test%20Execution%27)) ;
- `Alerts Resource Monitored at 5 Minute Frequency` :
  **0,1318 EUR par ressource/mois**
  ([meter `25bbac3f-6637-54eb-89f2-30d9afed34a0`](https://prices.azure.com/api/retail/prices?currencyCode=%27EUR%27&$filter=serviceName%20eq%20%27Azure%20Monitor%27%20and%20armRegionName%20eq%20%27westeurope%27%20and%20meterName%20eq%20%27Alerts%20Resource%20Monitored%20at%205%20Minute%20Frequency%27)).

La PR ajoute exactement un webtest live dans chacun des deux environnements ou
le module diagnostics est deploye (staging et production). Ses retries sont
desactives : `2 localisations x 12 executions/heure x 730 heures =
17 520 executions/mois`, soit exactement **10,512 EUR/mois par environnement**
au tarif public. Le webtest readiness conserve son nom et son cout existants ;
il ne fait pas partie du marginal.

Sans crediter les eventuelles unites gratuites, l'alerte live ajoute au plus
**0,1318 EUR/mois par environnement** sur ce meter. Le marginal public borne est
donc **10,6438 EUR/mois par environnement**, soit **21,2876 EUR/mois** pour
staging et production. Les notifications ne sont facturees que si elles sont
emises et restent dependantes du contrat ; elles ne sont pas masquees dans ce
total fixe. Le workbook n'a pas de cout propre. La metrique cold-start et les
requetes synthetiques ajoutent un faible volume d'ingestion variable, facture
au tarif d'ingestion du contrat. La retention 90 jours hors dev est conservee :
aucune economie de retention n'est creditee. Budget arrondi vers le haut pour
les meters fixes : **11 EUR/mois par environnement**, **22 EUR/mois au total**.

## Validation sans mutation

Les gates locaux ne contactent aucun endpoint applicatif :

```bash
bash infra/validate.sh
bash infra/ci-runner/validate.sh
node --test infra/tests/cosmos-indexing-policy.test.mjs \
  infra/tests/private-networking.test.mjs
dotnet test backend/tests/Certigo.Api.Tests/Certigo.Api.Tests.csproj \
  --configuration Release
```

Le parseur Bicep de Checkov ne comprend pas encore plusieurs expressions
Bicep utilisees par le depot. Scanner les ARM compiles evite un faux vert avec
`Parsing errors` :

```bash
CHECKOV_DIR="$(mktemp -d)"
trap 'rm -rf -- "$CHECKOV_DIR"' EXIT
bicep build infra/modules/appInsights.bicep \
  --outfile "$CHECKOV_DIR/appInsights.json"
bicep build infra/modules/diagnostics.bicep \
  --outfile "$CHECKOV_DIR/diagnostics.json"
checkov --file "$CHECKOV_DIR/appInsights.json" \
  "$CHECKOV_DIR/diagnostics.json" \
  --framework arm --compact --quiet --config-file .checkov.yaml
```

Le `what-if` est le seul appel Azure autorise dans cette PR. Il est read-only
et doit etre lance avec les parametres securises ephemeres decrits dans
`AZURE_IAC_OPERATIONS.md` :

```bash
az deployment sub what-if \
  --name "certigo-${ENV}-observability-preflight" \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters "@$AUTH_PARAMETERS_FILE" \
  --result-format FullResourcePayloads
```

Refuser toute suppression, tout remplacement, toute hausse de SKU et toute
ressource hors `Microsoft.Insights/webtests`, alertes, workbook, configuration
de retention/sampling et code Functions. Cette PR ne doit jamais executer
`deployment create`, deployer l'application, demarrer une VM ou fusionner.
