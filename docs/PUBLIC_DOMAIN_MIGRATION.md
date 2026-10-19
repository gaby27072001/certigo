# Migration vers un domaine public possédé

Le dépôt ne configure aucun domaine public par défaut. Une origine vide garde
les fonctions de domaine public désactivées, sans interdire le déploiement du
backend. Une origine renseignée exige une preuve de possession du domaine ;
l'activation de la suppression de compte exige en plus la preuve Apple.

## Contrat de configuration

Les valeurs suivantes sont des variables non secrètes de GitHub Environments.
Elles ne doivent jamais être inscrites dans un fichier `*.bicepparam` de
staging ou de production.

| Variable | Valeur fail-closed | Condition d'activation |
|---|---|---|
| `PUBLIC_WEB_ORIGIN` | chaîne vide | origine HTTPS canonique, sans chemin, port, query, fragment, identifiants ou point DNS terminal |
| `PUBLIC_DOMAIN_VERIFIED` | `false` | `true` uniquement après preuve de contrôle DNS et validation TLS |
| `APPLE_CIAM_DOMAIN_RECONFIGURED` | `false` | `true` uniquement après mise à jour et test des domaines/return URLs Apple et External ID |

Les valeurs `true` sont littérales et sensibles à la casse. Toute autre valeur
est refusée au lieu d'être convertie implicitement.

Le GitHub Environment `github-pages` fournit les trois variables au builder des
pages légales. Pour ce seul workload, la reconfiguration Apple n'est pas
requise, mais l'origine et la vérification explicite le sont. Les Environments
`staging` et `prod` fournissent les trois variables au writer de paramètres ARM.
L'Environment `beta` et le groupe Codemagic `certigo_mobile_config` fournissent
le même triplet aux releases mobiles. Pour le backend, la preuve Apple n'est
requise que si `ACCOUNT_DELETION_ENABLED=true`. Les releases mobiles conservent
leur propre gate d'activation. Voir le bilan daté « Réconciliation staging du
23 septembre 2026 » dans [le runbook IaC](runbooks/AZURE_IAC_OPERATIONS.md) pour
les valeurs mesurées ; les constats historiques ci-dessous ne les remplacent pas.

## Garde-fous

- `tools/build_public_pages.mjs` valide le contrat avant de créer `_site`; un
  dispatch sans variables ne produit donc aucun artefact publiable.
- `.github/scripts/write-secure-bicep-parameters.mjs` valide les variables du
  GitHub Environment et les injecte dans le fichier ARM temporaire en mode
  privé.
- `infra/main.bicep` répète les contrôles au plan de déploiement. Une preuve
  sans origine ou une origine non vérifiée échoue ; l'absence de preuve Apple
  bloque l'activation de la suppression de compte, pas un backend qui la laisse
  désactivée.
- `cd-backend.yml` exécute un job de préflight lié à l'Environment cible avant
  tout job qui accède à Azure pour les promotions comme pour les rollbacks, puis
  répète le contrôle dans le job IaC. Les pipelines Android, iOS historique et
  Codemagic appliquent le même gate avant de produire un binaire de release.
- Les outputs `privacyPolicyUrl`, `accountDeletionUrl`,
  `appleAppSiteAssociationUrl` et `assetLinksUrl` restent vides tant que
  `publicDomainActivationReady` vaut `false`.

GitHub Pages n'est acceptable comme origine temporaire que si l'organisation
contrôle réellement l'origine HTTPS, si les chemins publics sont stables et si
les consoles Apple/Google acceptent ces URLs. L'URL Pages de projet actuelle
requiert un préfixe de chemin et n'est donc pas une origine canonique compatible
avec ce contrat : elle reste neutralisée. Le workflow
`publish-verified-public-pages.yml` est le seul chemin d'activation futur ; le
dispatch historique reste bloqué par le builder sans configuration. Le workflow
compare aussi l'origine et le `base_path` retournés par GitHub Pages : toute URL
de projet ou tout alias qui ne sert pas l'origine vérifiée à la racine échoue
avant la création de l'artefact. Ce chemin est toutefois **inexploitable sur ce
dépôt** pour une raison de type de compte : voir « Où héberger les pages
légales : GitHub Pages est exclu sur ce dépôt ».

## Frontière de génération des fichiers publics

Le builder exige un espace de travail stable : aucun processus hostile ne doit
pouvoir remplacer ses parents ou modifier ses fichiers pendant la génération.
La préparation des callers utilise un job GitHub-hosted `ubuntu-24.04` éphémère,
un checkout de `github.sha` sur `main` sans credentials persistants, les seules
permissions `contents: read` et `pages: read`, et aucun secret référencé. `configure-pages`
lit les métadonnées avec `enablement: false` ; il ne doit pas activer le site.
Le job de déploiement reste séparé, attend la génération et ne checkout ni
n'exécute les sources du builder. Cette préparation ne constitue ni une adoption
par les contrôles trusted ni une preuve d'exécution de ce workflow.

Les deux callers de publication sont `publish-verified-public-pages.yml` et
`deploy-privacy-policy.yml`. Le caller de test `ci-infra.yml` / `bicep-build`
passe aussi sur un runner éphémère, avec seulement `contents: read` et
`pull-requests: read`, en conservant les gardes de fork et de fraîcheur et le
checkout du SHA candidat. Son code de PR n'est pas une source de publication ;
aucune sortie de ce test n'est transférée au deploy. Les dépendances de test
sont restaurées depuis le lock sans scripts d'installation. Les appels locaux
directs, `check_public_pages_drift.mjs` et les deux suites de tests exigent eux
aussi un workspace dont les sources et les parents de sortie ne sont pas
modifiés par un processus hostile ; un répertoire temporaire seul ne prouve
pas cette condition.

Dans cet espace isolé, le writer refuse les liens symboliques présents dans les
parents et les fichiers de sortie, les liens physiques multiples et les objets
non réguliers. Une nouvelle sortie est créée exclusivement en mode privé ;
les octets sont écrits par le descripteur vérifié, puis les permissions de
création ordinaires `0666 & umask` sont appliquées sur ce même descripteur.
Une relance conserve les permissions existantes et vérifie le fichier ouvert
avant toute troncature. Aucun renommage ou nettoyage par chemin temporaire ne
peut substituer une source homonyme. Les chemins Windows 8.3 légitimes restent
acceptés : une différence textuelle avec `realpath` n'est pas considérée comme
la preuve d'un lien symbolique. Le mode POSIX final est inchangé par rapport
au builder précédent ; les tests POSIX ne prétendent pas vérifier les ACL Windows.

Ces contrôles **ne garantissent pas un confinement atomique face à des parents
modifiés concurremment**. `O_NOFOLLOW` ne protège que le dernier composant et
n'est pas disponible partout. Le contrat portable Node ne remplace donc pas
l'isolation du caller. Un répertoire partagé avec du code de PR persistant
n'est pas un caller pris en charge ; ne pas y invoquer le builder comme un
contrôle de sécurité. Les tests locaux Windows/Linux vérifient les refus, les
octets, les permissions et les relances, pas l'existence d'un runner isolé en
production. Les contrôles trusted et le manifeste des workflows nécessitent
leur adoption indépendante avant toute activation ; leur refus n'est pas
une erreur à contourner.

## Interface attendue par la PR #298

La PR #298 reste propriétaire des fichiers mobiles et des générateurs
d'association. Lors de sa réconciliation ultérieure, elle doit :

1. consommer uniquement les quatre URLs ARM non vides ou reproduire exactement
   le même gate avant de générer AASA/assetlinks et les redirects ;
2. refuser toute association lorsque `publicDomainActivationReady` est faux ;
3. conserver sa valeur neutralisée tant que le nouveau domaine n'est pas
   entièrement configuré ;
4. ne jamais déduire la possession d'un domaine depuis sa simple présence dans
   une variable.

Cette PR ne génère ni AASA, ni assetlinks, ni configuration mobile et ne modifie
aucun fichier appartenant à #298, notamment pas
`deploy-privacy-policy.yml`.

## Ordre de merge

Cette PR est empilée sur #312. Fusionner #312 d'abord, puis rebaser cette PR sur
`main` avant sa fusion. Aucun dispatch Pages, déploiement Bicep ou changement de
console ne doit être exécuté dans le cadre de ces deux PR.

## Où héberger les pages légales : GitHub Pages est exclu sur ce dépôt

**Mesuré le 2026-09-07.** Le paragraphe ci-dessus décrit GitHub Pages comme
« chemin d'activation futur ». Cette possibilité n'existe pas pour ce dépôt, et
la cause n'est pas une configuration manquante mais le type de compte
propriétaire.

Trois mesures, chacune reproductible :

| Mesure | Commande | Résultat |
|---|---|---|
| Le dépôt est privé et son propriétaire est un compte EMU | `gh api repos/gchambaud_microsoft/Certigo --jq '{private, owner_type: .owner.type}'` puis `gh api users/gchambaud_microsoft --jq .plan.name` | `private: true`, `owner_type: User`, `plan: emu_user` |
| GitHub Pages n'est pas activé | `gh api repos/gchambaud_microsoft/Certigo --jq .has_pages` | `false` |
| L'Environment `github-pages` n'existe pas | `gh api repos/gchambaud_microsoft/Certigo/environments/github-pages/variables` | `Not Found` |

La deuxième mesure exige un contrôle : `has_pages` vaut aussi `false` sur
`github/docs` et `microsoft/vscode`, donc ce champ ne discrimine rien tant qu'on
n'a pas exhibé un dépôt où il vaut `true`. `pages-themes/cayman`,
`github/opensource.guide` et `jekyll/minima` renvoient `true`. Le champ varie
donc bien, et le `false` de Certigo est une mesure et non un artefact. Ne pas
utiliser `GET /repos/{o}/{r}/pages` à cette fin : cet endpoint renvoie `404`
même sur un dépôt qui a des Pages, il ne distingue pas l'absence du défaut de
portée du jeton.

**Conséquence.** Sur une entreprise Enterprise Managed Users, les sites GitHub
Pages ne peuvent être publiés que *privés* et ne sont accessibles qu'aux membres
de l'entreprise. Or une politique de confidentialité et une page de suppression
de compte doivent rester lisibles anonymement, y compris par la revue Apple et
Google et par un utilisateur qui a désinstallé l'application. Un site Pages
restreint à l'entreprise ne satisfait donc pas l'exigence, même une fois le
domaine personnalisé posé.

`publish-verified-public-pages.yml` reste néanmoins correct et fail-closed : son
étape « Require a compatible verified Pages origin » compare
`steps.pages.outputs.origin` à `PUBLIC_WEB_ORIGIN` et exige un `base_path` vide.
Sans site Pages servant l'origine vérifiée à la racine, ce workflow échoue avant
de produire un artefact. Il n'y a donc rien à neutraliser ; il faut seulement
cesser de le décrire comme le chemin prévu.

**L'hébergement des pages légales est tranché : Azure Static Web Apps**, décision
du 2026-09-07, détaillée dans la section « Hébergement retenu » ci-dessous. Le
DNS de `certigo-app.com` est délégué à Wix (`ns12.wixdns.net`, `ns13.wixdns.net`)
et l'origine HTTPS répond déjà — un `404`
à la racine prouve que le DNS résout, que le certificat est valide et que la
connexion aboutit, puisqu'un échec TLS ne produirait pas de code HTTP. Quel que
soit l'hébergeur retenu, il doit servir exactement les chemins que l'ARM
compose, sans redirection ni préfixe :

- `${PUBLIC_WEB_ORIGIN}/privacy-policy/`
- `${PUBLIC_WEB_ORIGIN}/account-deletion/`

et, pour l'étape 4 seulement, `/.well-known/apple-app-site-association` et
`/.well-known/assetlinks.json`, servis en clair, sans redirection et avec le
type de contenu attendu par Apple et Google. **Mesuré le 2026-09-08 sur l'hôte
Azure retenu** : servi en clair, sans redirection, le type MIME de l'AASA
demandant une réécriture — voir « `/.well-known/` est servi en clair » ci-dessous.

**Condition d'invalidation de cette section** : elle cesse d'être vraie si le
dépôt change de propriétaire pour un compte non-EMU, ou si l'entreprise cesse
d'utiliser les Enterprise Managed Users. Le seul fait d'activer Pages ou de
poser un domaine personnalisé ne l'invalide pas, puisque la restriction porte
sur la visibilité du site et non sur son existence. Recontrôler
`gh api users/<owner> --jq .plan.name` avant de conclure.

### Hébergement retenu : Azure Static Web Apps (décision du 2026-09-07)

Les pages légales publiques sont servies par le Static Web App
`swa-certigo-legal` (groupe `rg-certigo-web`, westeurope, SKU **Free**,
souscription `b8952c8c-8f72-469d-99cd-ac906da4e2fc`, locataire
`16b3c013-d300-468d-ac64-7eda0820b6d3`). Le déploiement est automatique :
`.github/workflows/deploy-legal-pages-azure.yml` reconstruit les pages depuis
`docs/legal/*.md` et les publie à chaque modification sur `main`.

**Ce qui a emporté la décision** n'est ni le prix ni le `/.well-known/`, mais le
fait que `docs/legal/*.md` reste la source unique et que la page publiée en
découle. Tout hébergeur exigeant un copier-coller manuel laissait la page
publiée diverger silencieusement du dépôt le jour où quelqu'un oublierait de
recopier une correction.

**Alternatives écartées, avec leur coût mesuré le 2026-09-07 :**

| Option | Verdict | Coût mesuré |
| --- | --- | --- |
| GitHub Pages | **Fermé**, pas cher | Site publiable en privé uniquement (EMU), voir la section ci-dessus |
| Déplacer le dépôt vers un compte personnel | Écarté | 30 workflows, 68 fichiers nommant le dépôt, 9 secrets, 7 variables, 9 Environments, 4 runners à refaire — et une fenêtre où rien ne se déploie. **Non vérifié** : que l'EMU autorise seulement le transfert |
| Wix | Écarté | Rattacher un domaine à un site Wix exige un abonnement Premium, ~17 $/mois |
| Hostinger | Écarté | ~3-4 €/mois, et la recopie manuelle subsistait |
| Azure Static Web Apps | **Retenu** | Gratuit, sert `/.well-known/`, pages générées depuis le dépôt |

**Origine canonique : `https://www.certigo-app.com`, et non la racine.** Ce
n'est pas un report : Wix ne supporte ni `ALIAS` ni `ANAME`, et Azure Static Web
Apps ne publie aucune IP stable qu'un `A` pourrait viser. La racine est donc
**fermée par le DNS du registrar**, de la même façon que Pages l'est par le type
de compte. Un rattachement de la racine avait été créé puis supprimé : resté en
`Validating` sans pouvoir aboutir, il aurait ressemblé à un chemin configuré.

**Conséquence pour l'étape 4** : l'`apple-app-site-association` doit être servi
depuis `www.certigo-app.com`, donc c'est **ce** domaine qui va dans
l'entitlement Apple. Configurer la racine par habitude produit des liens
profonds qui échouent **en silence** — un lien profond qui échoue n'affiche
aucune erreur, il ouvre le navigateur.

**Pourquoi le workflow n'utilise pas l'action officielle Azure.**
`Azure/static-web-apps-deploy` est une action Docker, et le runner
`certigo-trusted` n'a pas de Docker : mesuré le 2026-09-07 sur
`vmss-certigo-runner-zonal_be505fa1`, `DOCKER=ABSENT`, `DAEMON=KO`, pour
`NODE=v20.20.2` et `npx` présents. Le workflow passe donc par
`@azure/static-web-apps-cli`, qui n'est que du Node.

**Pourquoi le workflow vérifie les pages après les avoir publiées.** Le
2026-09-07, une exécution locale de ce même CLI a rendu le **code de sortie 0
sans rien publier** : les deux URLs répondaient `404` immédiatement après. Un
déploiement qui ne prouve pas ce qu'il sert ne prouve rien, et l'étape finale
inclut un contrôle négatif — un chemin absent doit échouer — sans lequel un site
répondant `200` à tout ferait passer les vérifications pour une preuve.

**Cause de ce faux vert, corrigée** : Azure Static Web Apps refuse de publier un
dossier sans fichier par défaut à la racine, et son client **rend malgré tout 0**
en le refusant. GitHub Pages n'exigeait rien de tel, donc
`build_public_pages.mjs` ne produisait pas d'`index.html` racine ; il en génère
un désormais, qui sert aussi de « Site web » déclaré dans la fiche Google Play.

#### Mesuré le 2026-09-08 : `/.well-known/` est servi en clair, mais le type MIME de l'AASA demande une réécriture

C'était « la contrainte qui élimine le plus d'hébergeurs de sites vitrine », et
elle n'avait jamais été mesurée. Résultat, contre l'hôte réel :

| Question | Mesure |
| --- | --- |
| `/.well-known/` est-il servi ? | **Oui**, `200` direct |
| Y a-t-il une redirection ? | **Non**, `num_redirects=0` |
| Y a-t-il un préfixe de chemin ? | **Non**, le chemin est servi tel quel |
| `assetlinks.json` a-t-il le bon type ? | **Oui**, `application/json` |
| `apple-app-site-association` a-t-il le bon type ? | **Non par défaut** : `application/octet-stream` |

Apple exige `application/json` sur ce fichier, qui n'a pas d'extension. Trois
approches ont été essayées :

| Approche | Résultat |
| --- | --- |
| `headers.content-type` sur la route | **Ignoré**, `octet-stream` persiste |
| `mimeTypes` avec la clé `"."` | **Ignoré** |
| `rewrite` vers un jumeau `.json` | **`200`, `application/json`, 0 redirection** |

**Le contrôle qui rend ce verdict utilisable** : un en-tête témoin
`x-certigo-route-temoin` posé sur la *même* route était bien renvoyé. La règle
s'appliquait donc, et c'est `content-type` seul qui résistait. Sans ce contrôle,
on aurait conclu que les routes de `staticwebapp.config.json` ne fonctionnent
pas, et cherché la solution ailleurs.

`rewrite` et non `redirect` : **Apple ne suit aucune redirection.** La
distinction est invisible dans un navigateur — les deux affichent le fichier —
et fatale pour un lien profond, qui échoue alors en silence en ouvrant le
navigateur au lieu de l'application.

La configuration est générée par `tools/build_public_pages.mjs`, donc la route
existe déjà. Le fichier `apple-app-site-association.json` visé par la réécriture
n'est pas encore produit : la route rend `404` sans redirection en attendant, ce
qui est le comportement honnête. **La génération et la validation de ce fichier
existent déjà** sur la branche `gchambaud-microsoft-host-certigo-public-pages`
(PR #352, fermée parce qu'elle verrouillait l'origine sur l'apex) ; ne pas les
réécrire.

**Ce qui n'a pas été touché, et pourquoi.** `deploy-privacy-policy.yml` et
`publish-verified-public-pages.yml` visent tous deux GitHub Pages et sont donc
sans objet, mais ils restent en place : `validate-workflow-security.mjs` exige
huit marqueurs textuels dans le second et nomme le premier deux fois, et
`tools/tests/test_project_state.py` le nomme aussi. Les retirer ou les déplacer
casserait un fichier de trust-root et un test — c'est un changement de contrat,
pas de l'hygiène.

**Condition d'invalidation de cette section** : elle cesse d'être vraie si
`swa-certigo-legal` est supprimé, si le domaine `certigo-app.com` quitte Wix
pour un registrar supportant `ALIAS`/`ANAME` (ce qui rouvrirait la racine), ou
si le SKU Free cesse de couvrir les besoins. Un simple changement d'hôte par
défaut Azure ne l'invalide pas.

## Actions humaines après achat du domaine

1. Configurer le DNS et l'hébergement HTTPS, puis vérifier le certificat et le
   contrôle effectif de l'origine.
2. Configurer `PUBLIC_WEB_ORIGIN` dans `staging`, `prod`, `beta` et le groupe
   Codemagic `certigo_mobile_config`, puis
   passer `PUBLIC_DOMAIN_VERIFIED` à `true` dans chaque Environment après
   validation indépendante. Poser ces variables **au scope Environment et jamais
   au scope dépôt** : une variable de dépôt est visible par tous les
   Environments et activerait `staging` et `prod` sans décision explicite.
   L'Environment `github-pages` est sans objet ici, voir « Où héberger les pages
   légales : GitHub Pages est exclu sur ce dépôt ». Traiter d'abord les six
   variables de contenu, voir « Avant l'étape 6 : `staging` et `prod` sont à
   1-sur-6 sur le contenu » : sans cela cette étape échoue au job IaC.
3. Reconfigurer les domaines et return URLs dans Apple Developer et Microsoft
   Entra External ID, tester le parcours réel, puis passer
   `APPLE_CIAM_DOMAIN_RECONFIGURED` à `true` dans `staging`, `prod`, `beta` et
   Codemagic.
4. Réconcilier #298 avec les outputs ci-dessus, publier et vérifier AASA et
   assetlinks, puis tester Universal Links/App Links et les redirects.
5. Publier les pages légales, vérifier leurs URLs canoniques, puis renseigner
   l'URL de suppression de compte et la politique de confidentialité dans les
   consoles stores.
6. Promouvoir d'abord en staging, exécuter les tests réels, puis promouvoir en
   production après approbation humaine.

### Avant l'étape 6 : `staging` et `prod` sont à 1-sur-6 sur le contenu

**Mesuré le 2026-09-07. Ce point ne se manifeste qu'à partir du moment où l'étape 2 est faite** —
il est aujourd'hui invisible, et c'est précisément ce qui le rend piégeux.

`write-secure-bicep-parameters.mjs` applique une règle **tout-ou-rien** sur six variables de contenu :
les six vides, le déploiement continue en mode legacy (branche sûre) ; les six posées, elles sont
injectées ; **entre une et cinq, il lève**. Or exactement une des six est posée aujourd'hui —
`AZURE_CONTENT_READER_CLIENT_ID`, au **scope dépôt**, donc héritée par *tous* les environnements,
y compris ceux qui n'ont jamais demandé de contenu versionné.

Pourquoi vous ne l'avez jamais vu : `validatePublicDomainConfiguration` s'exécute **avant** le
contrôle de contenu et échoue d'abord, inconditionnellement, pour tout environnement non-`dev`.
Le contrôle de contenu n'est donc jamais atteint. **L'étape 2 lève ce masque.** Le jour où
`PUBLIC_DOMAIN_VERIFIED` passe à `true`, l'erreur de contenu devient atteignable et se déclenchera
dans un contexte où personne ne l'attend.

Ce n'est pas une urgence, et ce n'est pas destructeur : le script s'exécute **avant** tout appel
Azure (`cd-backend.yml`, `write-secure-bicep-parameters.mjs` puis `az deployment sub create`), donc
l'échec est propre, bruyant et sans état partiel. Le message nomme désormais lui-même les valeurs
posées, les manquantes, et le fait que le scope dépôt est visible partout.

**Deux issues, et le choix dépend d'une question non tranchée.**

| Si | Alors le jour J |
| --- | --- |
| `staging`/`prod` doivent servir le contenu versionné | **compléter les six** variables sur l'Environment concerné |
| `staging`/`prod` doivent rester en contenu legacy | **vider les six**, c'est-à-dire neutraliser l'héritage du scope dépôt |

**Question ouverte, mais plus petite qu'elle ne l'était** : elle ne porte plus que sur `prod`.

**Mesuré le 2026-09-07, après la fusion de `272552aa` (#392)** — une version antérieure de cette
section affirmait qu'« aucune déclaration d'intention n'a été trouvée ». **C'est faux depuis ce
commit**, et l'inférence de structure qui l'accompagnait est désormais remplacée par une mesure :

| Fichier de `infra/params` | Nombre de `param content*` | Valeurs |
| --- | --- | --- |
| `dev.bicepparam` | 3 | `stcertigocntz3wqbdww` + `id-certigo-content-reader` |
| `staging.bicepparam` | 3 | **chaînes strictement identiques à `dev`** |
| `prod.bicepparam` | **0** | non câblé |

La comparaison est faite par égalité de chaînes et non à l'œil, et `prod` à zéro dans le même appel
sert de contrôle négatif : il prouve que la lecture sait voir une absence, les trois fichiers
passant par le même code.

**`staging` partage donc déjà le magasin de `dev`** — même compte de stockage, même identité de
lecture, écrit dans le dépôt. La question qui reste ouverte est **`prod`**, qui ne déclare aucun
paramètre de contenu à ce jour. Trancher avant d'agir sur `prod` ; ne pas rouvrir le cas `staging`.

#### Mesuré le 2026-09-07 : « vider les six » n'est pas disponible en l'état

La ligne « vider les six » du tableau ci-dessus décrit une issue qui n'est pas
atteignable aujourd'hui. Le message d'erreur de
`write-secure-bicep-parameters.mjs` disait « clearing all six is the safe
default » — un conseil qu'on ne peut pas suivre pour `staging` et `prod` ; il a
été corrigé dans la même PR que cette section pour décrire l'état *absent*
plutôt que *vide*. La raison est mécanique.

**GitHub refuse une valeur de variable vide.** Vérifié par une chaîne de
contrôles sur l'Environment neutre `copilot`, sans toucher `staging` ni `prod`,
la sonde ayant été supprimée ensuite :

| Étape | Résultat |
|---|---|
| la sonde n'existe pas avant | `404` |
| création avec une valeur **non vide** | succès, relue correctement |
| `PATCH` vers une valeur **vide** | **`422 Variable value cannot be empty.`** |
| relecture après l'échec | valeur inchangée |

Le contrôle positif est indispensable ici : sans la création réussie, un `422`
ne prouverait pas que c'est *le vide* qui est refusé plutôt que la requête, le
jeton ou l'Environment.

**Conséquence.** On ne peut pas masquer une variable de scope dépôt par une
variable d'Environment vide. Amener `staging` ou `prod` à 0-sur-6 exigerait donc
de **supprimer** `AZURE_CONTENT_READER_CLIENT_ID` du scope dépôt, ce qui casse
deux choses à la fois :

1. `ci-content-drift.yml` la lit en `vars.AZURE_CONTENT_READER_CLIENT_ID` comme
   client-id OIDC et **ne déclare aucun `environment:`** — vérifié, le mot-clé
   est absent du fichier — donc elle ne peut lire que le scope dépôt. La
   supprimer supprime le seul garde-fou de dérive de contenu qui fonctionne,
   sans solution de rechange par variable d'Environment ;
2. `dev` tombe de 6-sur-6 à 5-sur-6 et échoue à chaque push sur `main`, puisque
   `dev` a cinq valeurs au scope Environment et tire la sixième du scope dépôt.

**Il ne reste donc qu'une issue réellement disponible pour `staging` et `prod` :
compléter les six.** Choisir malgré tout le contenu legacy imposerait d'abord un
changement de `ci-content-drift.yml` pour qu'il déclare un `environment:`, puis
une copie de la variable au scope Environment de `dev`, et seulement ensuite la
suppression au scope dépôt — dans cet ordre, sinon `dev` casse entre-temps.

**Condition d'invalidation de ce sous-point** : il cesse d'être vrai si GitHub
accepte un jour une valeur de variable vide, ou si `ci-content-drift.yml` déclare
un `environment:`. Le simple fait de compléter les six sur un Environment ne
l'invalide pas. Rejouer les quatre étapes du tableau sur un Environment neutre
avant de conclure.

**Ne supprimez pas `AZURE_CONTENT_READER_CLIENT_ID` du scope dépôt sans précaution.**
`ci-content-drift.yml` la consomme comme client-id OIDC et ne déclare aucun `environment:`, donc
elle ne peut lire que le scope dépôt. C'est le seul garde-fou de dérive de contenu qui fonctionne
aujourd'hui. De plus `dev` tire sa sixième valeur de ce même scope dépôt : toute suppression doit
d'abord poser la valeur en variable d'environnement sur `dev`, sinon `dev` passe par 1-sur-6 et
`cd-backend` le déploie automatiquement à chaque push sur `main`.

**Condition d'invalidation de cette section** : elle cesse d'être vraie dès que le compte des six
variables visibles depuis `staging` ou `prod` n'est plus 1. Recompter au scope dépôt **et** au scope
environnement, les deux, avant de conclure.

## Le contenu a deux sources, pas une : `bicepparam` et variables GitHub

**Mesuré le 2026-09-07.** Une lecture répandue — et que ce document entretenait — est que les six
variables GitHub sont *la* source du contenu. Elles n'en sont que **la surcharge**. Il y a deux
chemins, et ils se rejoignent dans le même fichier de paramètres :

```
infra/params/<env>.bicepparam  --az bicep build-params-->  valeurs de BASE
variables GitHub (les six)     --write-secure-bicep-parameters.mjs-->  SURCHARGE
```

Les six variables correspondent une à une à six paramètres de `main.bicep`, dont trois ont un
défaut non vide :

| Variable GitHub | Paramètre `main.bicep` | Défaut |
| --- | --- | --- |
| `AZURE_BLOB_ENDPOINT` | `contentBlobEndpoint` | `''` |
| `AZURE_CONTENT_READER_CLIENT_ID` | `contentReaderClientId` | `''` |
| `AZURE_CONTENT_READER_RESOURCE_ID` | `contentReaderResourceId` | `''` |
| `AZURE_DESCRIPTOR_CONTAINER` | `contentDescriptorContainerName` | `'content-release-descriptors'` |
| `AZURE_PUBLIC_CONTAINER` | `contentPublicContainerName` | `'content-public-releases'` |
| `AZURE_PRIVATE_CONTAINER` | `contentPrivateContainerName` | `'content-private-releases'` |

`staging.bicepparam` pose les **trois premières** et laisse les trois noms de conteneurs à leurs
défauts.

**Ce que cela change, et ce que cela ne change pas.** La règle tout-ou-rien porte sur les
**variables**, pas sur les paramètres compilés : `staging` lèvera donc le jour J *quoi que
contienne son `bicepparam`*. En revanche, compléter les six sur `staging` **réécrirait par-dessus
des valeurs déjà committées et identiques** — la même valeur existerait alors à deux endroits qui
peuvent diverger sans que rien ne le signale.

**Si l'on préfère `bicepparam` comme source unique**, la séquence est contrainte et son ordre est
la partie importante :

1. donner un `environment:` à `ci-content-drift.yml`, qui n'en déclare aucun aujourd'hui ;
2. poser `AZURE_CONTENT_READER_CLIENT_ID` au scope **Environment** de `dev` ;
3. **seulement ensuite** supprimer la variable au scope dépôt.

Inverser 2 et 3 fait passer `dev` par 1-sur-6, et `cd-backend` le déploie automatiquement à chaque
push sur `main` : la casse serait immédiate et automatique.

**Condition d'invalidation** : cette section cesse d'être vraie si `main.bicep` cesse de déclarer
ces six paramètres, ou si `staging.bicepparam` cesse de déclarer les trois valeurs de contenu.
Recompter les `param content*` dans les trois fichiers de `infra/params` avant de conclure.

## `validate-public-domain` est une gate bloquante, pas une simple validation de forme

**Mesuré le 2026-09-07.** Poser `PUBLIC_WEB_ORIGIN` ne fait pas qu'échouer l'écriture d'un fichier
de paramètres : le contrat est un **job** de `cd-backend.yml` dont dépend toute la chaîne de
déploiement.

```
validate-target
  └── validate-public-domain
        ├── build-release
        └── resolve-release   <-- porte la garde explicite
              └── deploy-infra
                    └── deploy-backend
```

**Attention au mécanisme exact.** C'est **`resolve-release`** qui exige
`needs.validate-public-domain.result == 'success'`. `deploy-backend` ne nomme pas la gate : il en
hérite **transitivement** via `resolve-release` puis `deploy-infra`. Quelqu'un qui chercherait la
protection dans la garde de `deploy-backend` ne l'y trouverait pas, et pourrait la retirer de
`resolve-release` en croyant qu'elle est redondante. Elle est portante : `resolve-release` s'exécute
sous `always()`, donc sans ce test explicite un échec de la gate ne l'arrêterait pas.

**Le job n'a aucun `if:`** — il s'exécute toujours. Pour `dev` il **réussit** (et non « saute »)
grâce au court-circuit `dev` du contrat : mesuré sur le run `34146273853`, où
`Validate public-domain deployment gate` est `completed/success` alors qu'aucune des trois
variables n'est posée.

**Conséquence de séquencement pour `staging` et `prod`.** ~~Le job appelle le contrat avec la
fonctionnalité `infrastructure`, qui fait partie des fonctionnalités exigeant Apple.~~
**Corrigé le 2026-09-09** — voir « La garde refusait le déploiement, pas l'activation ». Le job
appelle toujours le contrat avec `infrastructure`, mais l'exigence Apple n'y est active que si le
déploiement active réellement une URL app-facing (`accountDeletionEnabled`). La reconfiguration
Apple/Entra n'est donc plus un prérequis du premier déploiement `staging` ; elle redevient un
prérequis dès que la suppression de compte est activée.

**Condition d'invalidation** : cette section cesse d'être vraie si `resolve-release` cesse
d'exiger `validate-public-domain`, ou si l'exigence Apple pour `infrastructure` cesse d'être
conditionnée à `accountDeletionEnabled` dans `public-domain-contract.mjs`.

## L'origine sera absente du code : c'est voulu, pas un oubli

**Mesuré le 2026-09-07.** Une propriété voulue de ce contrat ressemble de très près à une
configuration manquante, et quelqu'un la « corrigera » un jour s'il ne la trouve pas nommée.

La règle « jamais dans un `*.bicepparam` » est réelle, mais elle est **plus étroite que sa
formulation courante** : elle ne vise que les environnements de release. Mesuré :

| Fichier | Déclare les trois `param` ? | Statut |
| --- | --- | --- |
| `infra/params/dev.bicepparam:67-69` | **oui**, figés inertes (`''`, `false`, `false`) | autorisé |
| `infra/params/staging.bicepparam` | non | **interdit** |
| `infra/params/prod.bicepparam` | non | **interdit** |

L'interdiction est appliquée **deux fois, indépendamment** — `infra/validate.sh:139`, dans une
boucle `for environment in staging prod`, et `.github/scripts/validate-workflow-security.mjs:887`,
sur `['staging', 'prod']`. `dev` est hors des deux boucles : sa déclaration inerte est délibérée et
garantit qu'aucun `bicepparam` ne peut activer le domaine sur `dev`.

Pour `staging` et `prod`, les trois valeurs ne peuvent donc venir que des GitHub Environments.
Conséquence directe, et c'est le piège :

- l'origine canonique **n'apparaîtra dans aucun fichier de configuration** de ces environnements ;
- elle est donc **invisible en revue de code** : aucune PR ne montrera jamais sa valeur ;
- un `grep` du domaine dans le dépôt trouvera **une phrase de prose, et rien de fonctionnel**.

Vérification à date, avec contrôles : sur `main`, `certigo-app.com` n'apparaît **que dans des
phrases de ce document** — aucun fichier de configuration, de workflow ou d'infrastructure ne le
référence. Contrôle positif (`PUBLIC_WEB_ORIGIN`, 18 fichiers) : la recherche voit du présent.
Contrôle négatif (chaîne inexistante, 0 fichier) : elle voit de l'absent.

> Cette phrase énonce **où** le domaine apparaît, pas **combien de fois**. Un décompte daté serait
> auto-invalidant : ce paragraphe est lui-même une occurrence, et le publier changerait le nombre
> qu'il annonce. La règle du fait volatil s'applique aussi aux faits qui portent sur le document
> qui les énonce.

**Un résultat qui ressemble à une réponse est plus trompeur qu'un vide.** Ne concluez pas d'une
occurrence trouvée dans le dépôt que le domaine est configuré, ni d'une absence qu'il ne l'est pas.
La seule lecture qui fasse foi est l'état des variables des Environments concernés, au scope
Environment **et** au scope dépôt. Et la seule preuve qu'une activation a pris effet est la sortie
de déploiement : `publicDomainActivationReady`, `privacyPolicyUrl` et `accountDeletionUrl` de
`main.bicep`, qui valent `''` tant que l'activation n'est pas effective — ils varient donc avec ce
qu'ils mesurent, contrairement au dépôt.

**Condition d'invalidation** : cette section cesse d'être vraie si `staging` ou `prod` entre dans
la liste des environnements autorisés à déclarer ces `param`, ou si `dev` entre dans la boucle
`staging prod` de `infra/validate.sh:139` ou dans `['staging','prod']` de
`validate-workflow-security.mjs:887`.

## La garde de release attestait une capacité absente du binaire

**Mesuré le 2026-09-08.** Les workflows de release appelaient le contrat avec la fonctionnalité
`account-deletion-url`, qui exige `APPLE_CIAM_DOMAIN_RECONFIGURED=true`, alors qu'ils compilent
`ACCOUNT_DELETION_ENABLED=false` par défaut. **La garde attestait une capacité que le binaire
livré ne contient pas.**

Ce n'est pas une prudence sans conséquence. Une garde plus stricte que son objet ne mesure pas ce
qu'on croit : elle bloquait la première bêta iOS au nom d'une fonctionnalité désactivée, et rien
n'aurait signalé le cas inverse — un binaire qui embarque la suppression de compte sans que la
reconfiguration Apple ait été faite.

**La correction lie la fonctionnalité au drapeau réellement compilé** (`codemagic.yaml`, ancre
`step_public_domain_gate`) : `account-deletion-url` quand `ACCOUNT_DELETION_ENABLED` vaut `true`,
`legal-pages` sinon. Mesuré dans les quatre directions, en exécutant la garde :

| `ACCOUNT_DELETION_ENABLED` | `APPLE_CIAM_DOMAIN_RECONFIGURED` | Résultat |
| --- | --- | --- |
| `false` | `false` | passe — `legal-pages` |
| **`true`** | **`false`** | **échoue** — l'exigence Apple se rallume |
| `true` | `true` | passe — `account-deletion-url` |
| toute autre valeur | — | échoue |

La deuxième ligne est la raison d'être du lien : activer la suppression de compte **rallume
automatiquement** l'exigence Apple, sans dépendre de la mémoire de quelqu'un.

### Ce que le drapeau atteste aujourd'hui : rien, et ce n'est pas définitif

**Mesuré le 2026-09-08** sur le locataire CIAM `af721be8-5901-422a-b299-b9c57847b968`, six
inscriptions d'application sur six : aucune URL de la chaîne d'authentification ne contient de
domaine Certigo. Uniquement le schéma applicatif `certigo://auth/`, des hôtes appartenant à
Microsoft (`*.ciamlogin.com`, `*.onmicrosoft.com`) et une URN `api://<guid>`. Le seul domaine du
locataire est `certigoapp.onmicrosoft.com`.

`APPLE_CIAM_DOMAIN_RECONFIGURED` est rattaché à l'étape 3 de « Actions humaines après achat du
domaine » — « les domaines et return URLs Apple et External ID ». **Cette étape n'a donc aucun
objet mesurable.** L'étape 4, elle, en a un depuis que l'hébergement est tranché : l'entitlement
Apple porte `www.certigo-app.com`, voir « Hébergement retenu : Azure Static Web Apps ».

**Ne pas en conclure que le drapeau restera vide.** Le jour où l'étape 4 est faite, il acquiert un
objet — et le lien ci-dessus fait que l'exigence se rallume seule à ce moment-là.

Un angle n'est pas couvert : `GET /identity/identityProviders` rend `403` faute de
`IdentityProvider.Read.All`, donc la fédération « Sign in with Apple » n'a pas été énumérée. Les
URL de fédération mesurées sur les autres applications pointent toutes vers `*.ciamlogin.com`,
mais c'est une inférence de motif, pas une lecture.

### Périmètre : ne pas généraliser cette correction à `cd-backend.yml`

> **Révisé le 2026-09-09.** La prémisse de cette section était fausse, et sa conclusion a été
> corrigée. Elle est conservée telle quelle parce que son raisonnement — une garde ne vaut que là
> où son objet existe — reste juste, et parce qu'elle montre comment une borne prudente peut se
> tromper d'objet. Lire « La garde refusait le déploiement, pas l'activation » avant de s'en servir.

`cd-backend.yml` appelle le contrat avec `infrastructure`, et **ce n'est pas la même anomalie**.
Un déploiement d'infrastructure ne produit pas de binaire : il produit `accountDeletionUrl` et
`appleAppSiteAssociationUrl`. La garde y a son objet. Voir « `validate-public-domain` est une gate
bloquante, pas une simple validation de forme ».

**La raison de la borne, pas seulement la borne** : quelqu'un qui lit « la garde était trop
stricte, on l'a alignée » voudra appliquer le même geste aux quatre sites d'appel. Sur
`cd-backend.yml`, ce serait un affaiblissement réel. La correction ne vaut que là où un **binaire**
est produit.

**Ce que la mesure du 2026-09-09 a corrigé.** « Il produit `accountDeletionUrl` et
`appleAppSiteAssociationUrl` » est vrai au pied de la lettre et faux dans ce qu'il conclut : ce
sont des **sorties**, vides tant que l'activation n'est pas prête, et **aucune ressource ne les
consomme**. Le fichier `apple-app-site-association` est publié par `tools/build_public_pages.mjs`,
sous la fonctionnalité `legal-pages`, qui **n'exige pas** Apple. L'exigence était posée sur le côté
qui ne publie rien, et absente du côté qui publie. La borne visait le bon principe et le mauvais
fichier.

### Les deux lignes de normalisation sont dupliquées délibérément

La garde reprend mot pour mot les deux lignes que porte déjà l'étape de build :

```bash
ACCOUNT_DELETION_ENABLED="${ACCOUNT_DELETION_ENABLED:-false}"
case "$ACCOUNT_DELETION_ENABLED" in true|false) ;; *) exit 1 ;; esac
```

**Ce n'est pas une duplication à factoriser.** Elle rend la garde correcte **sans dépendre de la
propagation des variables entre étapes Codemagic** — un fait que nous n'avons pas mesuré et qui
peut changer sans préavis. La normalisation étant idempotente, le résultat est identique que les
étapes partagent leur shell ou non. `codemagic.yaml` suggère d'ailleurs qu'elles ne le partagent
pas : `step_resolve_version` écrit `BUILD_NAME` et `BUILD_NUMBER` dans `$CM_ENV`, ce qui serait
inutile autrement.

`${VAR:-false}` traite la valeur vide **comme** l'absence : une variable définie mais vide donne
`false`, comme une variable absente. Avec `-` au lieu de `:-`, une valeur vide aurait produit une
chaîne vide, refusée par le `case` — un échec bruyant, jamais une divergence silencieuse.

### Le littéral `public-domain-contract.mjs account-deletion-url` est exigé tel quel

`validateRepositoryInvariants` dans `validate-workflow-security.mjs` vérifie par
`content.includes()` que `codemagic.yaml`, `release-android.yml` et `release-ios.yml` contiennent
la sous-chaîne littérale `public-domain-contract.mjs account-deletion-url`.

**Remplacer le nom de la fonctionnalité par une variable shell fait échouer la CI**, avec un
message qui annonce une garde « manquante » alors qu'elle est présente, seulement écrite
autrement. C'est pourquoi les deux invocations sont écrites en clair, une par branche : le littéral
est là **parce que le chemin `account-deletion-url` existe réellement**. Supprimer cette branche
déclencherait l'invariant — il fait son travail.

### Android et l'iOS historique portent la même anomalie, sans remède

`release-android.yml` appelle lui aussi le contrat avec `account-deletion-url` tout en compilant
`ACCOUNT_DELETION_ENABLED` à `false` par défaut. `release-ios.yml`, déprécié, l'appelle sans
jamais compiler le drapeau. **Ces deux-là ne peuvent pas être corrigés.**

`validateNoncanonicalWorkflows` dans `backend-deploy-workflow-policy.mjs` rejette tout fichier de
`.github/workflows/` **autre que `cd-backend.yml`** qui diffère de sa révision de base **et** porte
une capacité privilégiée au sens de `privilegedWorkflow`. `release-android.yml` en porte trois :
`permissions:`, `environment:` et `secrets.*`. Mesuré le 2026-09-08 : l'ajout d'**une seule ligne
de commentaire** suffit à le faire rejeter.

> **Le message ment sur son déclencheur.** Il dit `changed or new privileged capability is
> forbidden outside cd-backend.yml`, mais la condition réelle est *le fichier diffère d'un octet*
> **et** *le fichier est privilégié*. Aucune capacité n'a besoin de changer. Quelqu'un qui ajoute
> un commentaire vérifiera ses permissions, ses secrets et son environnement, n'y trouvera rien de
> modifié, et conclura à un bug de l'outil.

Le message qui l'accompagne aggrave la confusion : il propose de pré-approuver le changement
(`generate-workflow-semantic-manifest.mjs --pre-approve`), puis de le fusionner. **Ce remède
adresse la première erreur et jamais la seconde** — vérifié le 2026-09-23 en pré-approuvant
réellement une modification de `release-android.yml` : le refus du scellé reste mot pour mot.

**Ne pas tenter de « réparer » Android.** Ce n'est pas un oubli, c'est fermé, et l'essai coûte un
aller-retour CI complet pour un message trompeur. L'anomalie y disparaîtra d'elle-même le jour où
la suppression de compte sera réellement activée : l'attestation redeviendra vraie.

### Ce qui rend la correction iOS possible tient à l'emplacement d'un fichier

`validateNoncanonicalWorkflows` ne parcourt que `.github/workflows/`. **`codemagic.yaml` vit à la
racine du dépôt, il n'est donc jamais examiné par cette règle.** C'est la seule raison pour
laquelle la chaîne iOS est corrigeable et la chaîne Android ne l'est pas.

**Ce n'est pas une propriété d'architecture, c'est une contingence** : l'emplacement a été choisi
parce que Codemagic lit son manifeste à la racine, pour une raison sans rapport avec la
gouvernance. Déplacer `codemagic.yaml` sous `.github/`, ou migrer la chaîne iOS vers GitHub
Actions, **fermerait la dernière porte** — et le scellé qui l'impose ne peut plus être retiré.

**Condition d'invalidation** : cette section cesse d'être vraie si une return URL du locataire
CIAM contient un domaine Certigo — contrôle : réénumérer les inscriptions d'application du
locataire ; si `account-deletion-url` sort de `featuresRequiringApple` dans
`public-domain-contract.mjs` ; ou si `codemagic.yaml` cesse d'être à la racine du dépôt.

## La garde refusait le déploiement, pas l'activation

**Mesuré le 2026-09-09.** La garde ajoutée le 2026-08-20 (commit `2a7f49d7`) rendait **tout**
déploiement durci impossible, correctifs de sécurité compris. Le dernier déploiement de production
réussi date du 2026-08-16, quatre jours avant. Personne n'a heurté la porte parce que le
déploiement continu ne cible que `dev`, où le contrat court-circuite.

**Le défaut, à deux endroits symétriques.** `main()` de `public-domain-contract.mjs` ne passe
jamais `activationRequested`, qui vaut donc `true` par défaut : la branche `if (!requested)`, seule
sortie sans levée, était inatteignable depuis la ligne de commande. `infra/main.bicep` portait la
même forme avec `publicDomainActivationRequested = hardened`, alors que l'état « non activé » était
déjà écrit et utilisé juste en dessous (`effectivePublicWebOrigin = ready ? publicWebOrigin : ''`).
Il n'y avait rien à construire : un état existant avait été rendu inaccessible.

**La contradiction visible dans le fichier.** `main.bicep:66-67` documente « Empty keeps every
public-domain feature disabled ». Le code faisait l'inverse : origine vide → `fail()` → aucun
déploiement.

**Ce qui a changé.** L'activation est désormais **demandée par la présence d'une origine
configurée**, jamais par défaut ; et l'exigence Apple pour `infrastructure` est active quand le
déploiement active réellement une URL app-facing, ce que gouverne `accountDeletionEnabled`. Les
trois `fail()` gardent leur contenu, mot pour mot. **La garde cesse de s'appliquer à ceux qui ne
demandent rien** : c'est la différence entre « tu ne peux pas activer sans preuve » et « tu ne peux
pas déployer ».

**Ce que la garde refuse encore**, chaque ligne portée par un test qui rougit si on la désarme :

| Cas | Résultat |
| --- | --- |
| origine renseignée, `publicDomainVerified` faux | refus |
| origine renseignée, suppression de compte activée, Apple non reconfiguré | refus (rallumage) |
| origine placeholder, non-HTTPS, IP, ou hôte légataire non contrôlé (`unownedLegacyDomain`) | refus |
| booléen ambigu (`TRUE`, `1`, `yes`) | refus |
| fonctionnalités app-facing (`account-deletion-url`, `apple-ciam`, `link-associations`, `redirects`) | Apple exigé **sans condition** |
| origine vide avec un drapeau posé | refus — durcissement, commit séparé |
| origine vide, aucun drapeau | déploiement possible, six sorties vides |

**Le rallumage automatique est préservé et prouvé aux trois barrières** qui peuvent l'observer :
le contrat, `write-secure-bicep-parameters.mjs` — la seule qui lise le fichier de paramètres
compilé, donc la barrière autoritative — et le modèle Bicep. Activer la suppression de compte
rallume l'exigence Apple sans dépendre de la mémoire de quelqu'un, ni de celle d'une seule barrière.

**`APPLE_CIAM_DOMAIN_RECONFIGURED` reste à `false`, et c'est la vérité.** La section « Ce que le
drapeau atteste aujourd'hui : rien » n'est pas périmée : elle explique pourquoi poser le drapeau à
`true` aurait été un mensonge, et la correction évite d'avoir à le poser.

**Ce qui n'a pas été exercé** : le `what-if` Bicep sur la production. Les six sorties sont prouvées
par évaluation du modèle ARM compilé — `infra/tests/public-domain-contract.test.mjs` lit et évalue
les expressions au lieu de les relire — mais l'exécution du chemin réel contre Azure est une preuve
distincte, et c'est elle qui fait foi.

**Le quatrième site d'appel ne dérive pas, il exige.** `tools/build_public_pages.mjs` écrit les
pages du domaine ; pour lui, une origine absente est une erreur, pas un déploiement qui laisse la
fonctionnalité désactivée. `activationRequested` est donc un **tri-état** : laissé indéfini,
l'activation se dérive de l'origine configurée — ce que veut tout appelant de déploiement ; `true`
la rend obligatoire, pour l'appelant qui publie le domaine ; `false` est un renoncement explicite.
Ce site a été trouvé par la CI, pas par la lecture : `tools/tests/` n'était pas dans la première
passe de validation locale.

**Condition d'invalidation** : cette section cesse d'être vraie si `publicDomainActivationRequested`
cesse de dériver de `publicWebOrigin`, ou si l'exigence Apple pour `infrastructure` cesse d'être
conditionnée à `accountDeletionEnabled`.
