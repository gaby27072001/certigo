# Hébergement public de l'apex `certigo-app.com`

Statut : **préparation repository uniquement, activation fermée**.

Cette couche est empilée sur la PR #298, branche
`gchambaud-microsoft-universal-links-routing`, au HEAD vérifié
`1f889e228d96a39a9f1a549c9f2b7905d5578261`. La PR #298 reste propriétaire de
la configuration mobile et du générateur
`tools/generate_link_associations.py`. Cette couche consomme ses sorties sans
modifier ces surfaces.

L'origine publique autorisée est exactement `https://certigo-app.com`. Une URL
de projet GitHub Pages, un chemin `/Certigo`, HTTP, `www`, un autre sous-domaine,
un placeholder ou un domaine tiers est refusé avant la création de l'artefact.

Cette PR ne modifie ni DNS, ni réglage GitHub Pages, ni GitHub Environment, ni
secret, ni ruleset, ni Azure. Elle n'exécute aucun workflow et ne déploie rien.
Le site Pages n'était pas activé lors de l'inspection du 2 septembre 2026
(`has_pages=false`) ; ce runbook décrit les actions humaines futures.

## Contrat d'activation

Toutes les valeurs sont des variables non secrètes mais contrôlées du GitHub
Environment `github-pages`. Elles restent absentes ou fausses jusqu'aux preuves
décrites plus bas.

| Variable | État fermé | Valeur autorisée après preuve |
|---|---|---|
| `PUBLIC_WEB_ORIGIN` | chaîne vide | `https://certigo-app.com` exactement |
| `PUBLIC_DOMAIN_VERIFIED` | `false` | `true` après ownership DNS, résolution et TLS valides |
| `APPLE_CIAM_DOMAIN_RECONFIGURED` | `false` | `true` après reconfiguration et test Apple/External ID |
| `APPLE_TEAM_ID` | absente | Team ID exact vérifié dans Apple Developer |
| `MOBILE_APP_ID` | absente | identifiant exact commun au bundle iOS et au package Android |
| `ANDROID_SHA256_CERT_FINGERPRINTS` | absente | empreinte Play App Signing vérifiée, une par ligne |

Les booléens sont littéraux et sensibles à la casse. Le workflow refuse les
valeurs manquantes, les empreintes vides et les identifiants mal formés. Aucun
identifiant Apple ou Android de production n'est versionné dans le workflow.

Le même triplet `PUBLIC_WEB_ORIGIN`, `PUBLIC_DOMAIN_VERIFIED` et
`APPLE_CIAM_DOMAIN_RECONFIGURED` reste requis par `staging`, `prod`, `beta` et
Codemagic selon leurs contrats existants. La présence du domaine dans une
variable ne constitue jamais une preuve de contrôle.

## Artefact public exact

`publish-verified-public-pages.yml` est l'unique chemin d'activation prévu. Il
vérifie d'abord que `actions/configure-pages` retourne l'origine exacte et un
`base_path` vide. L'input `enablement` reste explicitement à `false` : le
workflow ne crée ni n'active le site Pages. Il appelle ensuite le générateur de
#298 avec les variables contrôlées, puis le builder empaquette uniquement :

```text
CNAME
.nojekyll
.well-known/apple-app-site-association
.well-known/assetlinks.json
privacy-policy/index.html
account-deletion/index.html
```

`CNAME` contient exactement `certigo-app.com`. Pour une publication Pages par
GitHub Actions, GitHub indique que ce fichier n'établit pas le custom domain :
le réglage Pages reste autoritaire. Le fichier est conservé ici comme contrat
déterministe et preuve dans l'artefact.

Le builder exige une sortie vide, refuse liens symboliques, fichiers
d'association supplémentaires, champs JSON inattendus, formats non
déterministes, préfixes de projet et routes différentes du contrat racine.
L'allowlist ci-dessus empêche notamment l'inclusion de contenu pédagogique
privé, d'`answerKey`, de fichiers de travail, de credentials ou d'anciens
artefacts.

Le dispatch historique `deploy-privacy-policy` reste fail-closed : il ne reçoit
ni contrat de domaine ni associations et ne peut donc produire aucun artefact.

## Runbook Wix — aucune action exécutée par cette PR

### 1. Préconditions et sauvegarde

1. Fusionner d'abord #298, puis rebaser ou recibler cette couche sur `main`.
2. Garder cette PR en draft tant que ownership, DNS, TLS et tests physiques ne
   sont pas prouvés.
3. Exporter la zone Wix et capturer une copie horodatée avant toute mutation.
4. Confirmer que le domaine n'est attribué à aucun site Wix et que l'inventaire
   initial est exactement :

| Nom | Type | TTL | Valeur à préserver ou à restaurer |
|---|---|---:|---|
| `certigo-app.com` | `A` | 1 h | `185.230.63.171` |
| `certigo-app.com` | `A` | 1 h | `185.230.63.186` |
| `certigo-app.com` | `A` | 1 h | `185.230.63.107` |
| `www.certigo-app.com` | `CNAME` | 1 h | `initial.wixdns.net` |
| zone | `NS` | 1 j | `ns12.wixdns.net`, `ns13.wixdns.net` |

Arrêter si l'inventaire réel diffère. Ne jamais corriger un écart implicitement.
La résolution publique observée le 2 septembre 2026 expose
`www.certigo-app.com CNAME cdn3.wixdns.net`, tandis que l'inventaire de contrôle
Wix à préserver indique `initial.wixdns.net`. Avant le basculement, confirmer
dans Wix que `initial.wixdns.net` reste bien la valeur configurée et capturer la
chaîne publique résultante. Si Wix affiche directement une autre valeur,
arrêter et faire approuver l'écart ; cette migration ne modifie jamais `www`.

### 2. Prouver l'ownership GitHub

1. Dans les réglages Pages du propriétaire GitHub, ajouter
   `certigo-app.com` comme domaine à vérifier.
2. Copier **sans transformation** le nom et la valeur TXT exacts affichés par
   GitHub. Ne pas construire le nom depuis le login et ne jamais utiliser une
   valeur d'exemple ou un placeholder.
3. Ajouter cette paire TXT exacte dans Wix avec un TTL de 1 h, sans toucher à
   l'inventaire ci-dessus.
4. Vérifier publiquement le TXT exact sur plusieurs résolveurs, puis terminer la
   vérification dans GitHub.
5. Conserver le TXT après validation : GitHub le recommande pour maintenir le
   domaine vérifié et réduire le risque de takeover.

### 3. Préparer GitHub Pages avant le basculement DNS

1. Dans `gchambaud_microsoft/Certigo` > **Settings** > **Pages**, sélectionner
   la source **GitHub Actions** et enregistrer le custom domain exact
   `certigo-app.com`.
2. Ne pas déclencher `publish-verified-public-pages` à ce stade.
3. Confirmer que Pages attend l'apex et non une URL
   `gchambaud_microsoft.github.io/Certigo`.

GitHub demande d'ajouter le custom domain au site Pages avant de pointer le DNS,
afin d'éviter qu'un tiers puisse revendiquer le domaine.

### 4. Appliquer le delta Wix minimal approuvé

Après validation explicite des étapes 1 à 3, remplacer **uniquement** les trois
enregistrements `A` Wix de l'apex :

| Action | Nom | Type | TTL | Valeur |
|---|---|---|---:|---|
| supprimer | `certigo-app.com` | `A` | 1 h | `185.230.63.171` |
| supprimer | `certigo-app.com` | `A` | 1 h | `185.230.63.186` |
| supprimer | `certigo-app.com` | `A` | 1 h | `185.230.63.107` |
| ajouter | `certigo-app.com` | `A` | 1 h | `185.199.108.153` |
| ajouter | `certigo-app.com` | `A` | 1 h | `185.199.109.153` |
| ajouter | `certigo-app.com` | `A` | 1 h | `185.199.110.153` |
| ajouter | `certigo-app.com` | `A` | 1 h | `185.199.111.153` |

Les quatre cibles sont les adresses IPv4 GitHub Pages officielles vérifiées dans
la documentation GitHub actuelle le 2 septembre 2026. Le delta minimal ne crée
pas d'AAAA, d'ALIAS, d'ANAME ou de wildcard.

Ne pas modifier :

- les NS `ns12.wixdns.net` et `ns13.wixdns.net` ;
- le CNAME `www` vers `initial.wixdns.net` ;
- le TXT d'ownership GitHub.

GitHub recommande généralement de raccorder aussi `www`, mais le contrat
Certigo porte uniquement sur l'apex. Une modification de `www` exige un besoin,
une cible et une validation TLS séparément prouvés ; elle ne fait pas partie de
ce basculement.

### 5. Vérifications DNS, ownership et TLS après un TTL complet

Attendre au moins 1 h, puis arrêter avant la première publication au moindre
écart :

1. `Resolve-DnsName certigo-app.com -Type A` retourne exactement les quatre
   adresses GitHub, sans aucune adresse Wix.
2. `Resolve-DnsName certigo-app.com -Type NS` retourne toujours les deux NS Wix.
3. La valeur configurée dans Wix pour `www` reste `initial.wixdns.net` et la
   chaîne CNAME publique reste identique à la capture pré-basculement
   approuvée ; une résolution directe peut exposer la cible Wix
   `cdn3.wixdns.net`.
4. La requête TXT sur le nom exact fourni par GitHub retourne la valeur exacte
   conservée.
5. GitHub Pages affiche `certigo-app.com` comme custom domain vérifié. Activer
   **Enforce HTTPS** seulement lorsque GitHub rend l'option disponible.
6. Le certificat public couvre `certigo-app.com` et la chaîne TLS est valide
   depuis plusieurs réseaux.

Ne pas utiliser le contenu des quatre ressources comme précondition à ce stade :
elles ne peuvent exister qu'après le premier dispatch contrôlé. Les six variables
restent absentes ou fausses tant que les preuves ci-dessus et la reconfiguration
Apple/External ID ne sont pas validées.

### 6. Première activation contrôlée et vérifications publiques

Après toutes les preuves précédentes :

1. Renseigner les six variables contrôlées du GitHub Environment
   `github-pages`.
2. Passer les deux booléens à `true` uniquement après validation indépendante.
3. Déclencher le workflow seulement depuis `main` avec un `client_payload`
   vide.
4. Confirmer que les quatre ressources publiques (deux pages légales et deux
   associations) répondent sur HTTPS à l'apex. Les deux chemins `.well-known`
   doivent répondre `200`, sans redirection ni authentification, avec le corps
   JSON attendu.
5. Confirmer que les pages légales contiennent respectivement les canoniques
   exactes `https://certigo-app.com/privacy-policy/` et
   `https://certigo-app.com/account-deletion/`.

Une vérification reproductible des associations peut enregistrer les headers et
le corps séparément, sans suivre les redirections :

```powershell
curl.exe --silent --show-error --dump-header aasa.headers `
  --output apple-app-site-association `
  --write-out "%{http_code} %{redirect_url}`n" `
  https://certigo-app.com/.well-known/apple-app-site-association
curl.exe --silent --show-error --dump-header assetlinks.headers `
  --output assetlinks.json `
  --write-out "%{http_code} %{redirect_url}`n" `
  https://certigo-app.com/.well-known/assetlinks.json
python -m json.tool apple-app-site-association
python -m json.tool assetlinks.json
```

Le code doit être `200` et `redirect_url` vide. Supprimer ces fichiers de preuve
locaux après revue ; ne jamais les committer.

6. Tester ensuite sur appareils physiques iOS et Android distribués les routes
   `/learn`, `/assignments`, `/achievements` et `/account-deletion`.
7. Activer les flags mobiles seulement après succès de ces tests et revue
   humaine.

La PR reste draft tant que DNS, TLS, ownership, réponse publique et tests
physiques ne sont pas tous prouvés.

## Rollback Wix

Si une preuve échoue après le basculement :

1. ne pas lancer de nouveau dispatch et laisser les flags mobiles désactivés ;
2. supprimer uniquement les quatre `A` GitHub
   `185.199.108.153`, `185.199.109.153`, `185.199.110.153` et
   `185.199.111.153` ;
3. restaurer uniquement les trois `A` Wix
   `185.230.63.171`, `185.230.63.186` et `185.230.63.107`, TTL 1 h ;
4. ne modifier ni les NS, ni `www`, ni le TXT d'ownership ;
5. attendre au moins 1 h et vérifier le retour exact à l'inventaire initial ;
6. retirer éventuellement le custom domain du repository seulement après que le
   DNS ne pointe plus vers GitHub. Conserver l'ownership TXT sauf décision
   explicite de libérer le domaine.

## Sources GitHub officielles

Valeurs et ordre de sécurisation vérifiés le 2 septembre 2026 :

- [Managing a custom domain for your GitHub Pages site](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site)
- [Verifying your custom domain for GitHub Pages](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages)

Relire ces sources immédiatement avant le changement DNS. Si les cibles
officielles ont changé, arrêter et mettre à jour ce runbook dans une PR revue au
lieu d'utiliser des valeurs historiques.
