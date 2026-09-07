# Migration vers un domaine public possédé

Le dépôt ne configure aucun domaine public par défaut. Les pages légales et les
fonctions applicatives liées au web restent désactivées tant que la possession
du domaine et la reconfiguration des dépendances Apple ne sont pas prouvées.

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
le même triplet aux releases mobiles. Toute opération staging/prod, rollback
compris, et toute release mobile exigent les trois conditions.

## Garde-fous

- `tools/build_public_pages.mjs` valide le contrat avant de créer `_site`; un
  dispatch sans variables ne produit donc aucun artefact publiable.
- `.github/scripts/write-secure-bicep-parameters.mjs` valide les variables du
  GitHub Environment et les injecte dans le fichier ARM temporaire en mode
  privé.
- `infra/main.bicep` répète les contrôles au plan de déploiement. Tout plan
  staging/prod échoue lorsque le contrat n'est pas prêt, même si la suppression
  de compte reste désactivée.
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

**L'hébergement des pages légales est donc un choix à trancher hors dépôt**, et
il n'est pas tranché ici. Le DNS de `certigo-app.com` est délégué à Wix
(`ns12.wixdns.net`, `ns13.wixdns.net`) et l'origine HTTPS répond déjà — un `404`
à la racine prouve que le DNS résout, que le certificat est valide et que la
connexion aboutit, puisqu'un échec TLS ne produirait pas de code HTTP. Quel que
soit l'hébergeur retenu, il doit servir exactement les chemins que l'ARM
compose, sans redirection ni préfixe :

- `${PUBLIC_WEB_ORIGIN}/privacy-policy/`
- `${PUBLIC_WEB_ORIGIN}/account-deletion/`

et, pour l'étape 4 seulement, `/.well-known/apple-app-site-association` et
`/.well-known/assetlinks.json`, servis en clair, sans redirection et avec le
type de contenu attendu par Apple et Google. Vérifier que l'hébergeur retenu
sait servir `/.well-known/` **avant** de s'engager sur l'étape 4 : c'est la
contrainte qui élimine le plus d'hébergeurs de sites vitrine.

**Condition d'invalidation de cette section** : elle cesse d'être vraie si le
dépôt change de propriétaire pour un compte non-EMU, ou si l'entreprise cesse
d'utiliser les Enterprise Managed Users. Le seul fait d'activer Pages ou de
poser un domaine personnalisé ne l'invalide pas, puisque la restriction porte
sur la visibilité du site et non sur son existence. Recontrôler
`gh api users/<owner> --jq .plan.name` avant de conclure.

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

**Question ouverte, délibérément non tranchée ici** : `staging` et `prod` sont-ils censés partager
le magasin de contenu de `dev` ? Aucune déclaration d'intention n'a été trouvée. Il n'existe pas de
stack contenu par environnement dans `infra/params`, ce qui *suggère* un magasin unique — mais
c'est une inférence de structure, pas une décision écrite. Trancher avant d'agir.

#### Mesuré le 2026-09-07 : « vider les six » n'est pas disponible en l'état

La ligne « vider les six » du tableau ci-dessus décrit une issue qui n'est pas
atteignable aujourd'hui, et « clearing all six is the safe default » dans le
message d'erreur de `write-secure-bicep-parameters.mjs` est donc un conseil
qu'on ne peut pas suivre pour `staging` et `prod`. La raison est mécanique.

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
