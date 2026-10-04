# Observabilite minimale

Ce runbook decrit les signaux ajoutes sans nouveau service, changement de SKU,
Sentinel ni Front Door. Le comportement produit et les endpoints restent
inchanges.

## Signaux et objectifs

Les anciennes mesures preparatoires de #303 ne decrivent pas l'etat actuel.
Le diagnostic date et borne est conserve dans « Incident quiz de septembre :
preuves de detection et de remise » ci-dessous.

Le module `infra/modules/diagnostics.bicep` ajoute ou ajuste :

- le test readiness existant `availability-<function-app>` est conserve sans
  renommage, et un seul test standard externe `availability-<function-app>-live`
  est ajoute ; tous deux s'executent toutes les cinq minutes depuis Amsterdam
  et Ashburn ;
- une alerte par test, uniquement si les deux localisations echouent ;
- une alerte au premier 5xx hors endpoints de sante, ou a la premiere exception
  Error/Critical ou explicitement `Unhandled`, sur 15 minutes ;
- une alerte readiness pour au moins deux requetes en echec sur 10 minutes,
  evaluee chaque minute, et une alerte d'absence totale de requetes sur
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

## Incident quiz de septembre : preuves de detection et de remise

Constat **du 24 septembre 2026**, Azure CLI en lecture seule sur les 30 jours
precedents, abonnement Certigo du tenant Microsoft Non-Production. Sources :
`AppRequests`, `AppExceptions`, ressources `scheduledQueryRules`, `actionGroups`,
attributions RBAC, API `Microsoft.AlertsManagement/alerts` et `/history`.
Ces mesures sont historiques, pas une attestation de l'etat apres promotion.
Toute modification des regles, du routage, des droits, de la collecte ou de la
messagerie impose une nouvelle verification.

**« Aucune alerte n'a ete declenchee » est faux.** La production a enregistre
7 reponses 500 de `SubmitQuiz`, zero succes et une reponse 499. Les 500
incluent le 9 septembre, pas seulement les 11 et 15. La regle existante
`alert-certigo-http5xx-spike` etait deja active avec `Count > 0`,
evaluation toutes les 5 minutes, fenetre de 15 minutes, severite 1,
resolution automatique et action group `ag-certigo-security`.

| Premier quiz 500 UTC | Alerte Fired UTC | Delai observe | Instance d'alerte |
| --- | --- | --- | --- |
| 09/09 20:59:01 | 09/09 21:00:04 | 1 min 02 s | `feceddcd-b76b-5ada-11fe-a1ce6c11000e` |
| 11/09 11:06:17 | 11/09 11:10:20 | 4 min 02 s | `e618df7b-a39d-5573-6370-d8d4f940000e` |
| 11/09 12:46:23 | 11/09 12:50:08 | 3 min 45 s | `6a2a6d7c-6630-4220-e5e4-2883d9f4000e` |
| 15/09 14:41:41 | 15/09 14:45:04 | 3 min 22 s | `162018b2-a9c0-b34e-6f72-8f9a2f72000e` |

Les delais sont tronques a la seconde depuis les timestamps complets. Chaque
instance porte `ActionsTriggered` dans la seconde qui suit, avec l'action group
attendu et `isSuppressed=false`. Certains incidents regroupent aussi des 503
de `GetAccountDeletion` : un seul incident par environnement, pas par requete.
Les 5 identites de regles ont chacune le role Log Analytics Reader sur le
workspace. Aucune regle de traitement/suppression n'etait presente dans
l'abonnement. Staging a aussi declenche au premier 503 de
`GetActivePublicContentManifest`, le 23/09 a 19:22:12 UTC.

Le recepteur email est `Enabled` dans les deux environnements et correspond
a `ALERT_EMAIL` du GitHub Environment. Son adresse personnelle n'est pas
recopiee ici. **`ActionsTriggered` prouve l'execution du groupe, pas la remise
en boite ni la lecture humaine.** Le seuil, la table, le filtre, le faible
trafic et les droits ne sont donc pas la cause demontree du silence percu.
Gabriel a confirme le 24/09 ne pas avoir recu les alertes des 11 et 15/09,
mais avoir recu la veille un email « Action required: Verify your email for
Azure Monitor action group ». Le GET `actionGroups` avec l'API
`2026-03-01-preview` exposait avant validation **`verificationStatus=VerificationPending`** pour
`secops` dans staging **et** prod, malgre `status=Enabled`. L'API stable
`2023-01-01` ne retournait pas le champ de verification.
La cause constatee est donc **alerte declenchee par Azure, notification email
bloquee faute de verification OTP**, et non « email envoye mais non vu ».
Le statut lu le 24/09 n'est pas un historique du statut aux 11 et 15/09 :
ne pas inventer de preuve retrospective de remise ou de non-remise du serveur
de messagerie. Ne pas attribuer ce blocage a iCloud ou aux spams.

### Verification OTP : precondition du routage email

**Toute adresse d'alerte ajoutee ou modifiee doit etre validee par OTP par son
destinataire ; une adresse non verifiee ne recoit ni alerte ni notification
de test apres activation de cette exigence.** Le code expire apres 30 minutes.
La documentation officielle
[Action groups, Notification types / Email](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups#notification-types),
consultee le 24/09/2026, precise : « This verification persists across all past
and future action groups within the same tenant. » Un redeploiement identique
ne doit donc pas annuler une verification deja accomplie. Il n'y a pas lieu
de sortir le recepteur de l'IaC. Le mail recu lors d'une promotion ne prouve
pas une remise a zero : une adresse encore en attente peut redemander validation.

Si le code a expire : portail Azure, bon tenant, groupe de ressources
`rg-certigo-staging`, action group `ag-certigo-security`, recepteur `secops`,
puis **Resend**. Un seul renvoi suffit puisque la verification porte sur
l'adresse dans le tenant. Gabriel saisit lui-meme son code ; ne jamais le
journaliser. La source officielle ci-dessus documente ce bouton.
Aucune API publique de renvoi n'a ete trouvee dans les operations publiees
`actionGroups` 2023-01-01 et 2024-10-01-preview ; ne pas appeler un endpoint
devine ni recreer le groupe comme contournement.

Pour lire l'etat reel, utiliser le GET suivant sur **les deux** environnements :

```text
GET https://management.azure.com/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-certigo-<ENV>/providers/Microsoft.Insights/actionGroups/ag-certigo-security?api-version=2026-03-01-preview
```

Cette version est annoncee par `az provider show --namespace Microsoft.Insights`
pour `actiongroups` et le champ a ete observe directement. Son schema n'etait
pas publie a l'emplacement du swagger consulte le 24/09 : c'est une API preview,
pas une garantie de stabilite. Un champ absent ou une nouvelle valeur est une
erreur a investiguer, jamais un succes implicite.

`infra/check-alert-receivers.mjs` valide une reponse JSON fraiche de ce GET :

```powershell
node infra\check-alert-receivers.mjs <fresh-action-group.json>
```

Le controle exige groupe actif, recepteur `secops` present, et tous les
recepteurs email `Enabled` + `Verified`. Il echoue explicitement (code 1) si
OTP en attente, desinscription, champ inconnu/absent ou reponse invalide.
Il n'affiche pas les adresses, ne modifie aucune ressource et n'envoie pas
d'email. Test sur le snapshot reel `VerificationPending` : echec attendu.
Apres validation OTP par Gabriel vers 16:27 UTC le 24/09, les GET ont retourne
**`Enabled` + `Verified` en staging a 16:28:30 UTC et en prod a 16:28:34 UTC**.
Le meme controle passe sur les deux reponses : la portee tenant est donc
verifiee entre ces deux groupes, sans PUT ni changement de destinataire.
Ce controle local est livre et teste ; **aucune sonde recurrente n'est encore
branchee**. Le futur lot workflow par le circuit A/B doit recuperer ce GET avec
Azure CLI (delai borne, echec HTTP fatal), lancer ce controle avant/apres chaque
promotion et quotidiennement, et rendre son echec visible dans GitHub, hors
du canal email potentiellement casse. Il doit rejeter un snapshot ancien.

Apres OTP, relire les deux groupes, refaire un test reel `createNotifications`,
conserver l'ID de notification et l'heure d'acceptation puis le resultat final,
et demander a Gabriel de confirmer le message correspondant. Refaire les GET
et le controle apres le prochain CD normal pour verifier aussi la persistance.
**Verified et un test Azure reussi ne prouvent pas a eux seuls la reception
en boite.** Ne pas annoncer l'envoi si Azure refuse encore le test.

### Test operationnel de remise du 24 septembre

La fonction de test de l'action group a refuse le recepteur pourtant active :
HTTP 400 `There are no valid receivers in the request`, reproduit avec la CLI
et `az rest` sur le payload documente. Aucun envoi de test n'est atteste par
ces appels. Le champ `VerificationPending` obtenu ensuite explique ce refus ;
le code HTTP seul ne suffisait pas a l'attribuer.

Sur autorisation explicite de l'orchestrateur, une regle **temporaire** distincte
`TEST-certigo-remise-email-20260924` a ete creee dans staging a 15:39:24 UTC.
Un resultat KQL constant, borne a 15 minutes, a exerce le moteur d'alertes
sans panne applicative ni donnees apprenant. La regle etait stateful, Sev3,
evaluee toutes les 5 minutes ; la cadence 1 minute avait ete refusee par Azure
pour cette requete sans table.

- Fired : **15:45:09.247 UTC**, instance
  `8a667551-da83-d5ab-57e4-eb51d509000e`.
- `ActionsTriggered` : **15:45:09.568 UTC**, groupe existant.
- Suppression de cette seule regle : **15:46:45 UTC**, puis absence confirmee
  par une nouvelle lecture ; les cinq regles permanentes restent presentes.
- Reception humaine du message portant ce nom : **en attente de confirmation**.
  Ce test precedait l'OTP ; ne pas lui attribuer la reception du test suivant.

Ce test prouve le chemin moteur -> action group. La preuve de remise exige
en plus l'objet, l'heure et la confirmation de Gabriel. Il ne prouve pas que
le correctif IaC est deploye. Les donnees detaillees de preuve restent dans
les artefacts de session ; ne pas publier les contextes bruts d'alertes
d'activite (ils peuvent contenir des identifiants et des claims).

Apres verification OTP, le nouveau POST `createNotifications` en staging a
ete **accepte HTTP 202 entre 16:28:59.966 et 16:29:05.279 UTC**, identifiant
de notification **`13001076255128580`**, type `logalertv2`. L'orchestrateur a
ete prevenu immediatement. Cette methode ne cree aucune ressource temporaire :
pas de regle a supprimer, aucun endpoint applicatif appele, aucun changement
de configuration. La remise et le resultat terminal du test sont distincts
de cette acceptation : le statut final est **`Complete`**, action Email/secops
**`Succeeded`**, `SendTime=16:29:10.961 UTC`,
`completedTime=16:32:35.931 UTC`. **Gabriel a confirme avoir recu cet email
de test de 16:29 UTC**, confirmation transmise par l'orchestrateur le 24/09.
L'objet et le dossier exacts ne sont pas encore consignes ; ils ne sont pas
inventes. La remise est donc attestee apres validation OTP, contrairement
au test anterieur. Cela ne prouve toujours pas le deploiement du nouveau KQL.

## Contrat de detection a faible trafic

### Readiness : echecs repetes, pas incident transitoire unique

`infra/queries/readiness-failures.kql` cible explicitement le composant
Application Insights de l'environnement (`_ResourceId`, insensible a la casse)
et le chemin exact `/api/health/ready`, y compris avec une query string.
La regle existante `alert-certigo-readiness-failure` conserve son nom, sa
severite 1, son identite, ses droits, son action group et `autoMitigate=true`.
Seuls son KQL, son seuil (`Count > 1`), sa fenetre (`PT10M`) et sa cadence
(`PT1M`) changent. Les autres regles, dont 5xx + exceptions, restent inchangees.
La cadence plus rapide augmente les evaluations de cette seule regle.

Deux requetes non-200 observees dans la fenetre suffisent, meme si des 200
s'intercalent ou si les echecs viennent de deux instances/regions differentes :
un succes sur une instance ne doit pas masquer une panne partielle ailleurs.
Ce critere signifie **echecs repetes**, pas « service continuellement indisponible ».
Les retries sont de vraies requetes : deux retries en echec peuvent declencher.
Ils peuvent partager `OperationId` avec le 200 final ; ne pas dedupliquer par
cette correlation. Les doublons de `Id` (identite de requete/span) sont elimines,
meme si leurs timestamps different. Sans `Id`, le repli utilise
`(TimeGenerated, OperationId, AppRoleInstance)` ; les evenements incomplets
identiques sont fusionnes conservativement, meme sans nom d'instance.
`ItemCount` n'est pas additionne : une ligne echantillonnee de poids 10 ne
prouve pas dix echecs distincts. Requests doit rester exclu du sampling ;
perte de telemetrie ou sampling peuvent retarder ou empecher la detection.
Un 503 isole suivi d'un 200 ne declenche jamais, meme si le 200 n'est pas encore
ingere. L'absence de donnees reste couverte par les signaux existants, pas par
un faux succes produit par ce KQL.

Avec un premier 503 observe a t0, puis au moins un autre dans les 5 minutes
(cadence des sondes), le critere devient vrai au plus tard a t0 + 5 min et est
evalue moins d'une minute plus tard : **moins de 6 minutes depuis le premier
503**, hors ingestion et ordonnancement Azure. Les retries peuvent le rendre
vrai plus tot. Avec le profil observe (sondes toutes les 5 minutes et retry
environ 25 secondes apres le premier echec), une panne 503 continue est
detectable en moins d'environ **6 min 25 s depuis son debut** : attente de
sonde <= 5 min, deuxieme echec au retry ~25 s, evaluation < 1 min.
Cette borne suppose les deux requetes de retry collectees ; deux regions
peuvent raccourcir l'attente mais leur dephasage n'est pas suppose favorable.
Sans retry visible, attendre la premiere sonde peut ajouter jusqu'a 5 minutes
a la borne depuis le premier 503. Ni la latence d'ingestion, ni la remise des notifications,
ni l'heure de resolution stateful ne sont garanties par ce calcul. Une alerte
reste active apres le retour des 200 tant que deux echecs restent dans sa
fenetre, puis selon les evaluations saines exigees par Azure ; sa duree n'est
donc pas la duree de la panne.

Les fixtures `infra/tests/readiness-failures-fixtures.mjs` generent une requete
KQL avec `datatable`, la requete de production et des evaluations historiques
decalees. La suite locale verifie aussi toutes les phases de cadence a la
seconde. Executer le payload dans Log Analytics en lecture seule pour prouver
la semantique KQL reelle ; une simulation JavaScript seule ne la prouve pas.

**Rejeu du 27 septembre 2026, sans deploiement :** le service Log Analytics a
execute le KQL candidat sur staging (26/09, 17:00-18:10 UTC) et production
(27/09, 12:40-13:50 UTC). Chaque fenetre contient 29 requetes readiness,
28 succes, un seul echec distinct, aucun `Id` manquant et `ItemCount` maximal 1.
Toute sous-fenetre de 10 minutes contenue dans ces intervalles a donc au plus
un echec : aucune phase d'evaluation autour des incidents ne peut declencher.
Les 30 cas `datatable`, dont les deux echecs continus a 300/325 secondes et
l'evaluation defavorable a 384 secondes, passent aussi dans le moteur KQL
reel (zero cas en echec). Le modele local couvre 36 120 combinaisons d'attente
initiale, phase d'evaluation et visibilite regionale ; son maximum est 384 s.
Ces preuves ne portent ni sur une regle deployee ni sur la remise d'un email.
Rejouer apres modification du KQL, du seuil, des cadences ou de la collecte.
Les payloads et resultats restent dans les artefacts prives ; rapport agrege
`readiness-replay-report.json`, SHA-256
`1c8827f8be8fecc90fda9d2f7d60f64ab2e8b580576ce40606cc45deeae81e07`.

### Requetes critiques et exceptions

La requete versionnee `infra/queries/critical-failures.kql` remplace seulement
la requete de la regle existante : aucun changement de nom de ressource,
d'identite, d'attribution RBAC, de cadence, de seuil ou de destinataire.
Elle est commune aux environnements qui deploient le module diagnostics.

Elle couvre toutes les routes HTTP, y compris connexion, catalogue, lecons,
quiz, examens et profil, sans liste de noms susceptible d'oublier une nouvelle
route. Le scope `_ResourceId` isole le composant App Insights de l'environnement.
Les chemins exacts `/api/health/live` et `/api/health/ready` sont exclus
du signal 5xx, car ils ont leurs propres alertes ; une query string ne contourne
pas cette separation. Une URL absente n'empeche pas l'alerte.

**Exclusion temporaire jusqu'a #307** : `GetAccountDeletion`, methode `GET`,
chemin exact `/api/account/deletion`, code `503`, uniquement si un Warning
`Certigo.Application.Abstractions.AccountDeletionDisabledException` du
`ExceptionMiddleware`, avec le template et le nom de fonction attendus,
porte les memes `OperationId` **et** `InvocationId` non vides.
Le catch existant emet ce marqueur type ; le statut et le corps HTTP ne changent
pas. Ne pas joindre sur `CorrelationId` fourni par le client.
Tout autre 5xx, le POST, une autre invocation, ou un marqueur absent/retarde
conserve l'alerte. La branche exceptions Error/Critical/Unhandled reste intacte.
Ainsi une vraie panne simultanee ne peut pas etre masquee par un appel normal
a la fonctionnalite desactivee. Le marqueur Warning ne constitue pas lui-meme
une panne non geree. Retirer cette exception KQL et son marqueur quand #307
active la fonctionnalite ou cesse de retourner un 5xx pour son indisponibilite
prevue. Une perte de correlation peut creer du bruit, jamais masquer une panne.

Les exceptions Error/Critical (`SeverityLevel >= 3`) ou explicitement
`HandledAt=Unhandled` declenchent aussi sans requete correlee. Dans les sept
exceptions Cosmos du middleware observees, `OperationName` et `HandledAt`
sont vides : filtrer seulement l'un de ces champs raterait la panne. Les
exceptions Warning des sondes de dependances ont leurs alertes readiness ;
aucune exclusion dans cette branche par type Cosmos, annulation, route ou utilisateur.

L'union ne projette que `TimeGenerated`, sans URL, payload, identifiant
utilisateur ou texte d'exception dans les resultats de l'alerte. Un 500 et son
exception peuvent compter deux signaux, mais le seuil absolu reste `> 0`
et la regle **stateful sans dimensions** les regroupe dans le meme incident.
Pas de message par evenement ni de boucle de rappels.

Objectif : detection a la prochaine evaluation de 5 minutes **apres ingestion**,
puis notification. Ce n'est pas une garantie de remise en cinq minutes :
ingestion, moteur d'alertes et messagerie ajoutent de la latence. Sur la panne
quiz mesuree, l'ingestion maximale etait de 35,5 secondes.

**Resolved ne signifie pas repare.** Au faible trafic, la fenetre devient vide
quand l'utilisateur abandonne. Un humain doit accuser reception, investiguer
le premier incident et confirmer une operation reussie apres correction avant
de clore le suivi. Les sondes de sante ne valident pas le scoring d'un quiz.

### Verifier le moteur KQL, pas une imitation JavaScript

`infra/tests/critical-failures.test.mjs` protege le contrat ARM compile et le
routage. Le generateur ci-dessous exerce la requete exacte avec des tables
`datatable` ephemeres, sans ecrire de telemetrie et sans declencher d'alerte :

```powershell
node infra\tests\critical-failures-fixtures.mjs |
  Set-Content "$env:TEMP\certigo-critical-fixtures.json" -Encoding utf8
az rest --method post `
  --url "https://api.loganalytics.io/v1/workspaces/<WORKSPACE_ID>/query" `
  --resource https://api.loganalytics.io `
  --body "@$env:TEMP\certigo-critical-fixtures.json"
Remove-Item "$env:TEMP\certigo-critical-fixtures.json"
```

Exiger `Cases=46`, `FailedCases=0`, `Failures=[]`. Resultat mesure le
24 septembre : **46/46**, avec routes critiques, route future, URL absente,
sante avec query string, 4xx, code invalide, autre composant et exception
sans operation ni severite, plus marqueur exact, methodes, causes et correlations
incorrectes, marqueur absent et requete soeur non masquee.

Rejeu de la requete exacte sur **23/09/2026 16:17:51 UTC ->
24/09/2026 16:17:51 UTC**, via Azure Logs, sans ecriture :

| Environnement | Signaux | Cause observee |
| --- | --- | --- |
| staging | 1 | manifest indisponible, 23/09 19:18:17 UTC |
| prod | 1 | `GetAccountDeletion` 503, 24/09 15:56:52 UTC, sans marqueur dans l'ancien backend |

Il serait faux d'annoncer zero : la cause de ce dernier 503 n'etait pas
enregistree par le catch ancien. Le nouveau filtre ne peut pas la reconstruire.
Chaque environnement contient donc un episode candidat sur cet intervalle
(une notification Fired si la regle etait auparavant resolue), pas une mesure
exacte des notifications qu'aurait emises le moteur stateful. Les sondes
readiness restent couvertes par leurs regles separees. Le cas equivalent
avec le nouveau marqueur est bien exclu par les fixtures ; confirmer la
correlation reelle apres promotion normale avant de declarer le bruit elimine.

## Promotion et retour arriere

Le what-if du **module diagnostics** est distinct du what-if de la stack
complete `infra/main.bicep` effectue par `cd-backend`. Pour isoler le lot,
reprendre les parametres non secrets du dernier deploiement RG `diagnostics`
avec `az deployment group show`, ne garder que `{value: ...}`, puis lancer :

```powershell
az deployment group what-if --resource-group "rg-certigo-<ENV>" `
  --template-file infra\modules\diagnostics.bicep `
  --parameters "@<PARAMETRES_DIAGNOSTICS.json>" `
  --validation-level Provider --result-format FullResourcePayloads
```

Preuve du 24 septembre, base `c3eb8ae2` apres rebase : staging et prod `Succeeded`.
Comparaison aux memes what-if du module de `main` : **seuls la requete et le
texte descriptif de `alert-certigo-http5xx-spike` changent du fait de ce lot**.
Les 13 autres deltas par environnement sont strictement identiques au baseline
(diagnostic settings, workbook et references RBAC). Ne pas les presenter
comme un what-if vide, ni les approuver implicitement.
L'action group est `NoChange` dans les deux what-if ; aucune creation ni
suppression de ressource propre a ce lot.

1. Attendre le feu vert explicite de l'orchestrateur apres la promotion backend
   en cours et sa surveillance ; aucune fusion de ce module avant ce feu vert.
2. Rebaser sur `main`, repasser les gates, refaire les what-if du lot.
   Faire valider le **what-if complet** avec les parametres securises du
   GitHub Environment ; refuser toute suppression, remplacement ou derive
   nouvelle hors de la regle. Les deltas baseline restent sous le controle
   du responsable de promotion, pas de ce lot.
3. Fusionner la PR uniquement avec les controles requis verts et le feu vert,
   puis promouvoir par le chemin normal `cd-backend`, staging avant prod.
   Aucun `deployment create` manuel, aucune voie de contournement de #452.
4. Relire la requete effectivement deployee, `enabled`, seuil, scope, action
   group et droits Reader ; executer les 46 fixtures et le garde-fou OTP.
   Verifier le marqueur et la correlation du GET profil desactive, sans masquer
   un 503 dont la cause manque. Confirmer reception
   d'une notification et tester un vrai parcours apprenant sans injection
   d'erreur en prod. Surveiller une heure et consigner le resultat.
5. Retour arriere : PR de revert du changement de requete/description et du
   marqueur backend, puis
   meme promotion normale et what-if. Garder les ressources, identites,
   destinataires et l'alerte 5xx historique ; ne pas desactiver la surveillance.

### Visibilite et sonde complementaire

Si le message arrive mais passe inapercu, convenir avec Gabriel d'un canal
plus visible avant de declarer l'incident resolu : notifications du client mail,
nom d'alerte explicitant **Certigo / environnement / API 5xx ou exception**,
ou push de l'application Azure. Ne pas annoncer « les quiz echouent » pour une
alerte qui peut concerner une autre route.
Le push exige que Gabriel installe l'application Azure, s'y connecte avec
l'identite choisie et autorise ses notifications ; l'adresse de cette identite
et le nouveau recepteur doivent etre approuves, deployes via IaC et testes.
Une autre adresse exige aussi son accord et un test de remise. Ne jamais
substituer un destinataire silencieusement.

Une sonde quotidienne connexion -> catalogue -> lecon -> soumission quiz
est recommandee en complement, sur un compte de test dedie, sans donnees
personnelles et sans compte utilisateur reel. Elle doit verifier un succes
metier cote serveur, utiliser un `clientAttemptId` unique et idempotent,
borner duree et tentatives, et ne journaliser ni jeton ni reponses de quiz.
Elle ne remplace pas l'alerte au premier echec et ne garantit pas la detection
en quelques minutes sans trafic. Sa politique de progression/recompenses et
son nettoyage doivent etre approuves avant activation ; ne pas supprimer
de donnees existantes. Le workflow est un lot separe apres resolution de
#497, avec les gardes habituelles des runners et de promotion.

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

Checkov 3.2.495 reste une verification complementaire, pas la preuve principale
sur ce module. Son parseur Bicep ne comprend pas plusieurs expressions utilisees
par le depot : le scan de #303 retourne 31 checks passes, aucun echec et
7 `Parsing errors`. Le meme scan sur la combinaison #303 + #296 retourne
35 checks passes, aucun echec et toujours 7 `Parsing errors`. Apres alignement
sur le `main` incluant egalement #301, la combinaison courante retourne
37 checks passes, aucun echec et toujours 7 `Parsing errors`.

```bash
checkov --directory infra --framework bicep --compact --quiet \
  --config-file .checkov.yaml
```

Ne pas presenter ce resultat comme un scan vert complet. Avec cette version,
scanner les ARM compiles via `--framework arm` retourne `resource_count: 0` et
constitue aussi un faux vert. Les preuves bloquantes sont donc :

- `infra/validate.sh`, qui compile tous les templates et parametres avec Bicep ;
- `infra/tests/private-networking.test.mjs`, qui inspecte les ARM compiles et
  verifie notamment la retention 30/90 jours, l'absence de purge immediate et
  les noms stables des webtests/alertes ;
- les gates workflow et backend listees ci-dessus.

Le `what-if` de la stack complete est read-only et doit etre lance avec les
parametres securises ephemeres decrits dans
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
ressource hors du perimetre approuve. Le lot d'alertes ne doit jamais executer
`deployment create`, deployer manuellement l'application ou demarrer une VM.
Le test operationnel temporaire explicitement autorise est decrit plus haut ;
il ne constitue pas une autorisation de modifier les regles permanentes.
