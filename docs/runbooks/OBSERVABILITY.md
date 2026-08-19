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

- deux tests standard externes, `GET /api/health/live` et
  `GET /api/health/ready`, toutes les cinq minutes depuis Amsterdam et Ashburn ;
- une alerte par test, uniquement si les deux localisations echouent ;
- une alerte au premier 5xx hors endpoints de sante sur 15 minutes ;
- une alerte readiness et une alerte d'absence totale de requetes sur
  15 minutes, intervalle normalement alimente par les tests synthetiques ;
- un workbook agrege Functions, Cosmos DB et Storage ;
- la metrique `functions.cold_start`, emise une seule fois par processus
  Functions avec deux dimensions statiques ;
- une retention Log Analytics de 30 jours et un sampling adaptatif borne a
  5 elements par seconde. Les requetes et exceptions restent exemptes afin que
  les alertes demeurent fiables au faible volume observe.

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

Tarif public Azure Retail Prices West Europe consulte le 19 aout 2026 :
`Standard Web Test Execution` = **0,0006 EUR par execution**.

Un test ajoute, deux localisations, une execution toutes les cinq minutes :

`2 x 12 x 730 = 17 520 executions/mois`, soit **10,51 EUR/mois par
environnement**. Staging et production ajoutent donc environ **21,02 EUR/mois**
au total. Le webtest readiness existant coute deja le meme montant et ne fait
pas partie du marginal.

Le workbook n'a pas de cout propre. La metrique cold-start et les requetes
synthetiques ajoutent un volume d'ingestion negligeable a cette echelle. Les
regles d'alerte supplementaires peuvent ajouter moins de 1 EUR/mois par
environnement selon le tarif d'evaluation et de notification du contrat.
Retirer la retention 90 jours au profit de 30 jours et borner le sampling peut
reduire le cout existant ; cette economie n'est pas creditee dans l'estimation.
Budget prudent : **12 EUR/mois par environnement**, **24 EUR/mois au total**.

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
