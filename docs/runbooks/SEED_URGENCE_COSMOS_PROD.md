# Seed d'urgence du conteneur `content` de production — trace du 2026-09-09

## ⛔ Vous cherchez comment publier du contenu ? Vous êtes au mauvais endroit.

**Ceci n'est pas la procédure de publication de contenu.** C'est la trace d'une intervention
d'urgence exécutée **une seule fois**, le 2026-09-09, sur une base de production **vide** qui
n'avait jamais été alimentée. Elle crée une machine virtuelle dans le VNet de production, s'attribue
un rôle data-plane et lève un verrou de protection. **Rien de tout cela n'a sa place dans une
publication de routine.**

👉 **Pour publier du contenu, lisez [« Rendre la publication de contenu routinière — plan
d'activation »](../plans/PUBLICATION_CONTENU_FACILE.md) et
[« Runbook — import, promotion et rollback des releases de contenu »](./CONTENT_RELEASES.md).**
La voie normale est le pipeline versionné : ses points d'entrée d'administration sont joignables en
HTTPS et ne demandent **ni accès Cosmos, ni accès VNet** à l'auteur du contenu.

Ce document existe pour une seule raison : la panne a été causée par un mécanisme Azure qui
**atteste une opération qui n'a pas eu lieu**. Quelqu'un qui rencontrera ce mécanisme perdra des
heures s'il ne sait pas qu'il existe. Le reste — la VM, le verrou, le rôle — n'est que la
conséquence.

---

| Champ | Valeur |
|---|---|
| **Nature** | Intervention d'urgence ponctuelle, exécutée une fois le 2026-09-09. **Pas** une procédure récurrente. |
| **Symptôme traité** | Application connectée, catalogue vide, HTTP 503 « No certification tracks are available yet. The database needs to be seeded. » |
| **Cible** | Sub `b8952c8c-8f72-469d-99cd-ac906da4e2fc` · RG `rg-certigo-prod` · compte `cosmos-certigo-prod-izfhvvxjdxc2k` · base `certigo` · conteneur `content` (partition `/trackId`) |
| **Résultat mesuré** | `UPSERT_OK 383  ERRS 0` puis `FINAL_COUNT 383` par relevé indépendant du conteneur |
| **Exposition réseau** | **Aucune.** `publicNetworkAccess` est resté `Disabled` et `ipRules` est resté `[]` de bout en bout (relus après coup) |
| **Durée création → destruction** | 4,1 min sur un budget de 20 min |
| **Résidus** | Aucun. Rôle retiré, VM détruite, sous-réseau transitoire supprimé, verrou restauré — chaque élément **relu** (voir « Démontage ») |
| **Ce que ça n'a PAS réparé** | L'application est restée inutilisable le soir même, pour une cause sans rapport (voir « Ce qui reste incertain ») |

> **Fait volatil, daté et borné.** La cible ci-dessus vaut au **2026-09-09**, mesurée sur les app
> settings du Function App `func-certigo-prod-izfhvvxjdxc2k` (`COSMOS_ENDPOINT`,
> `COSMOS_DATABASE`). **Invalidée** le jour où le Function App de production lit un autre compte ou
> une autre base — pas le jour où le nom du compte change. **Reprouvez la cible par la configuration
> applicative, jamais par le nom de la ressource** : c'est la seule lecture qui dit ce que le
> backend interroge réellement.

---

## 1. Le symptôme, et comment reconnaître la même situation

L'application mobile se connecte, l'authentification aboutit, et l'écran des certifications reste
vide avec un message d'erreur. Côté backend, la réponse est un **HTTP 503** portant la chaîne :

> `No certification tracks are available yet. The database needs to be seeded.`

Cette chaîne est émise par
[`backend/src/Certigo.Api/Middleware/ExceptionMiddleware.cs`](../../backend/src/Certigo.Api/Middleware/ExceptionMiddleware.cs)
(recherchez la chaîne, pas un numéro de ligne). **Sa disparition est le critère de succès de cette
procédure ; son maintien signifie que le conteneur `content` est toujours vide.**

**Ce que ce symptôme dit, et ce qu'il ne dit pas.** Il dit que le backend a interrogé Cosmos et n'a
trouvé aucune piste. Il ne dit **rien** sur le fait que l'application redeviendra utilisable une
fois le conteneur rempli — voir « Ce qui reste incertain », où c'est précisément ce qui s'est passé.

**Vérification préalable, avant d'engager quoi que ce soit :** le backend de production lit-il le
conteneur `content` (mode hérité) ou le pipeline versionné ? La bascule est portée par
`CONTENT_REPOSITORY_MODE`, dont l'absence vaut `legacy` :
[`Program.cs`](../../backend/src/Certigo.Api/Program.cs), `configuration[ConfigurationKeys.ContentRepositoryMode] ?? "legacy"`.

```bash
az functionapp config appsettings list \
  -g rg-certigo-prod -n func-certigo-prod-izfhvvxjdxc2k \
  --query "[?name=='CONTENT_REPOSITORY_MODE' || name=='COSMOS_ENDPOINT' || name=='COSMOS_DATABASE'].{n:name,v:value}" -o table
```

> **Fait volatil, daté et borné.** Au **2026-09-09**, `CONTENT_REPOSITORY_MODE` était **absent** des
> app settings de production, donc le mode était `legacy`, donc `seed_content.py` écrivait bien dans
> le conteneur que le backend interroge. **Invalidée** le jour où cette lecture rend `versioned` —
> auquel cas **cette procédure ne répare rien** : écrire dans `content` n'alimenterait plus le
> chemin de lecture, et il faut passer par le pipeline versionné.

---

## 2. L'Azure Policy à effet `modify` — un instrument qui atteste une opération qui n'a pas eu lieu

**C'est le point central de ce document.** Tout le reste en découle.

### Ce qui a été observé

Deux tentatives d'ouverture du pare-feu Cosmos, par deux chemins différents :

```bash
# Chemin 1 — CLI de haut niveau
az cosmosdb update -g rg-certigo-prod -n cosmos-certigo-prod-izfhvvxjdxc2k \
  --public-network-access Enabled
# -> exit 0

az cosmosdb show -g rg-certigo-prod -n cosmos-certigo-prod-izfhvvxjdxc2k \
  --query publicNetworkAccess -o tsv
# -> Disabled

# Chemin 2 — ARM brut, pour écarter la CLI
az rest --method PATCH \
  --url "https://management.azure.com/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/rg-certigo-prod/providers/Microsoft.DocumentDB/databaseAccounts/cosmos-certigo-prod-izfhvvxjdxc2k?api-version=<api-version>" \
  --body "@patch.json"
# -> HTTP 200, et le corps de la reponse rend lui-meme publicNetworkAccess: Disabled
```

**Ni 403, ni message de policy, ni avertissement.** Un effet `modify` d'Azure Policy réécrit la
valeur pendant l'admission de la requête, puis ARM accuse réception de la ressource **telle qu'elle
a été réécrite**. Le succès est authentique — c'est l'opération demandée qui n'a pas eu lieu.

### La règle qui en découle

> **Sur le plan de contrôle ARM des ressources de `rg-certigo-prod` et `rg-certigo-staging`, un code
> de retour ne prouve pas qu'une écriture a pris effet. Relisez la valeur effective après chaque
> écriture, et faites décider la relecture.**

Le domaine est écrit dans la règle parce qu'il compte : ces deux groupes de ressources sont soumis à
la policy d'entreprise de la subscription `b8952c8c`. Ailleurs, l'écriture peut être fidèle.

Cette règle est une instance de la discipline générale du dépôt — voir
[`docs/GOVERNANCE.md`](../GOVERNANCE.md), section « Discipline de mesure — un instrument muet doit
échouer, pas rendre zéro ». Les dix instruments qu'elle recense rendaient un verdict sans avoir rien
lu. Celui-ci est d'une famille plus dure : **il a lu, il a répondu juste, et la réponse décrit un
état que la demande n'a pas produit.** Aucun autotest de l'appelant ne l'attrape ; seule la
relecture le fait. La règle générale, dégagée de tout contexte Azure, est écrite sous
**« Le cas limite des instruments qui mentent — un succès rendu par un canal qui ne mesure pas
l'effet »**.

### Ce qui n'a pas été établi

**La policy elle-même n'a jamais été identifiée.** Aucune lecture de
`az policy assignment list` ni de `az policy state list` ne figure dans la trace : seul l'**effet** a
été mesuré, deux fois, par deux chemins. Son nom, son périmètre d'assignation et l'existence
éventuelle d'autres effets `modify` sur d'autres ressources restent **non mesurés**.

**Ne demandez pas d'exemption de policy** — c'est une contrainte permanente du contexte, et la
méthode ci-dessous a été retenue précisément parce qu'elle n'en a pas besoin.

---

## 3. Le verrou `CanNotDelete` — ce qu'il empêche réellement

Un verrou nommé `lock-delete-protection`, de type `CanNotDelete`, porte sur le compte Cosmos, le
Function App, le compte de stockage, le Key Vault et l'espace de travail Log Analytics, **en
production et en staging**.

```bash
az lock list -g rg-certigo-prod -o table
```

**Il autorise les modifications et bloque les suppressions.** La conséquence n'est pas intuitive :
une **attribution de rôle Cosmos SQL** est une ressource enfant du compte, donc **toute suppression
d'attribution échoue en `ScopeLocked`**. Un rôle data-plane que l'on s'attribue pour l'opération ne
peut donc pas être retiré tant que le verrou est en place.

> **La conséquence opérationnelle, et c'est celle qu'on découvre trop tard :** si vous vous attribuez
> un rôle sans avoir prévu la levée temporaire du verrou pour le retrait, **le nettoyage échoue et le
> rôle survit à l'intervention.** Prévoyez la levée **avant** l'attribution, pas après.

**Le VNet, lui, n'est pas verrouillé.** On peut y ajouter et en retirer des sous-réseaux librement.
C'est ce qui a rendu la méthode ci-dessous possible.

---

## 4. La méthode retenue — écrire depuis l'intérieur du réseau

Puisque le pare-feu ne peut pas s'ouvrir, on ne l'ouvre pas : on se place **à l'intérieur** du VNet
où le point de terminaison privé de Cosmos est déjà joignable.

### Topologie mesurée le 2026-09-09

| Objet | Valeur | Conséquence |
|---|---|---|
| `vnet-certigo-prod` | `10.100.0.0/16` | Non verrouillé — sous-réseaux ajoutables |
| `snet-func-flex` | `10.100.1.0/24` | **Délégué à `Microsoft.App`** — ne peut pas héberger de VM |
| `snet-private-endpoints` | `10.100.2.0/24` | Porte les points de terminaison privés |
| NAT Gateway / Azure Firewall / IP publique / table de routage | **aucun** | **Le VNet n'a pas de sortie Internet** — `pip install` échouera |
| `privatelink.documents.azure.com` | Zone présente dans `rg-certigo-prod` | **Aucun lien VNet, aucun enregistrement A** — la résolution DNS ne fonctionne pas seule |

Deux de ces lignes commandent toute la conception : **pas de sortie Internet** et **pas de
résolution DNS**. La méthode ne les contourne pas — elle **supprime le besoin**.

### Les quatre décisions qui font la méthode

1. **Aucun paquet à installer.** Le seeder est du **Python 3 de bibliothèque standard uniquement**,
   préinstallé sur l'image Ubuntu. Jeton AAD par IMDS, requêtes par `urllib`. Pas de `pip`, pas de
   `azure-cosmos`, pas de `azure-identity`, pas de wheels — donc **aucun besoin de sortie Internet**,
   donc aucune NAT Gateway à créer.
2. **Aucun flux entrant.** La VM n'a **pas d'IP publique** et n'est pilotée que par
   `az vm run-command invoke`, qui passe par le canal ARM et l'agent invité. Aucun port à ouvrir,
   aucune règle NSG à modifier, aucune clé SSH.
3. **Aucun secret.** Identité managée affectée par le système ; le jeton est obtenu sur la VM par
   IMDS en lien-local et ne quitte jamais la machine. Rien n'est écrit sur disque, rien ne transite
   dans une variable d'environnement.
4. **Aucune modification DNS de production.** La zone privée n'ayant ni lien ni enregistrement, l'IP
   du point de terminaison privé est **lue sur le point de terminaison** puis injectée dans le
   `/etc/hosts` de la VM éphémère. TLS reste valide : le nom d'hôte présenté en SNI est le bon.

> **Correction d'une lecture répandue :** la résolution **n'est pas** assurée par la zone DNS privée.
> La zone existe, mais `az network private-dns link vnet list` a rendu `[]` et aucun enregistrement A
> n'a été trouvé. **Relisez ce point avant de rejouer** : si un lien VNet a été créé depuis, l'étape
> `/etc/hosts` devient inutile ; s'il n'existe toujours pas, elle reste indispensable.

### Séquence

> **Ces commandes sont reconstituées** à partir de la trace de l'exécution : les paramètres qui
> décident (SKU, absence d'IP publique, identité système, sous-réseau, identifiant de rôle) y sont
> attestés, mais **toutes les options n'ont pas été conservées verbatim**. Traitez ce bloc comme une
> séquence à relire et à adapter, pas comme un script à copier tel quel.

```bash
SUB=b8952c8c-8f72-469d-99cd-ac906da4e2fc
RG=rg-certigo-prod
ACCOUNT=cosmos-certigo-prod-izfhvvxjdxc2k
az account set --subscription "$SUB"

# 0. Etat AVANT — a relire a l identique au demontage
az cosmosdb show -g $RG -n $ACCOUNT \
  --query "{pna:publicNetworkAccess, ip:ipRules, dla:disableLocalAuth}" -o json
az cosmosdb sql role assignment list -g $RG -a $ACCOUNT -o table   # noter la baseline
az lock list -g $RG -o table

# 1. Sous-reseau transitoire (le VNet n est pas verrouille)
az network vnet subnet create -g $RG --vnet-name vnet-certigo-prod \
  -n snet-seed --address-prefixes 10.100.3.0/24

# 2. VM ephemere, sans IP publique, identite systeme
#    Image : une image Ubuntu avec python3 preinstalle. L alias exact n est PAS
#    consigne dans la trace — choisissez-le et verifiez `python3 --version` au
#    premier run-command avant de transferer quoi que ce soit.
az vm create -g $RG -n vm-certigo-seed \
  --image <alias-ubuntu> --size Standard_D2as_v6 \
  --vnet-name vnet-certigo-prod --subnet snet-seed \
  --public-ip-address "" --assign-identity \
  --nic-delete-option Delete --os-disk-delete-option Delete
# `az vm create` exige un identifiant d administration (cle SSH ou mot de passe).
# Il n a servi a rien ici : sans IP publique et sans regle NSG entrante, aucun
# chemin ne permettait de s en servir. Le pilotage passe uniquement par run-command.

# 3. Role data-plane Cosmos pour le MSI de la VM (Built-in Data Contributor)
PRINCIPAL=$(az vm show -g $RG -n vm-certigo-seed --query identity.principalId -o tsv)
az cosmosdb sql role assignment create -g $RG -a $ACCOUNT \
  --role-definition-id 00000000-0000-0000-0000-000000000002 \
  --principal-id "$PRINCIPAL" \
  --scope "/"

# 4. IP du point de terminaison prive — A RELIRE, ne jamais recopier
az network private-endpoint show -g $RG -n pe-cosmos-certigo-prod-sql \
  --query "customDnsConfigs[].{fqdn:fqdn, ip:ipAddresses[0]}" -o table
```

> **Ces adresses sont contraintes par le point de terminaison privé, pas par une convention.** Au
> 2026-09-09 la lecture rendait `10.100.2.5` pour le compte et `10.100.2.6` pour l'endpoint régional
> `northeurope`. **Une recréation du point de terminaison les change.** Relisez-les à chaque
> exécution ; les recopier depuis ce document produirait un délai d'attente réseau sans message
> utile.

### Le transfert et le seeder

Le paquet de documents est compilé **localement** par `build_documents()` de
[`tools/seed_content.py`](../../tools/seed_content.py) — c'est la logique de seed autoritative, et
elle n'est pas reproduite ici. Elle lit `content/*/track.yaml` et `content/*/lessons/*.lesson.yaml`,
et **extrait les corrigés dans des documents `type: answerKey` séparés, côté serveur uniquement**.
Un document de leçon expédié au client ne contient jamais les réponses.

> **Ce nombre est contraint par l'arborescence `content/`, pas par une cible.** Au 2026-09-09 :
> **383 documents = 91 `track.yaml` + 146 `*.lesson.yaml` + 146 `answerKey`**, pour un paquet JSON
> compact de **371 142 octets**. **Recomptez** — le nombre change à chaque ajout de contenu, et un
> écart entre l'attendu et l'écrit est justement le signal à surveiller.

Le paquet est **gzippé puis encodé en base64** pour tenir dans un seul appel `run-command`. La
limite exacte de charge utile d'un `run-command` **n'a pas été mesurée** : la compression a été
appliquée par précaution, pas en réponse à un refus observé.

Le script exécuté sur la VM tient en bibliothèque standard et enchaîne :

```text
1. injection dans /etc/hosts     <ip-du-PE>  cosmos-certigo-prod-izfhvvxjdxc2k.documents.azure.com
2. jeton AAD par IMDS            GET http://169.254.169.254/metadata/identity/oauth2/token
                                     ?api-version=2018-02-01
                                     &resource=https://cosmos.azure.com
                                 en-tete   Metadata: true
3. document sentinelle           le premier document est ecrit SEUL, avec reprise sur 401/403
                                 (la propagation du role data-plane n est pas instantanee)
4. boucle d upsert               les 382 suivants
5. comptage independant          read-feed pagine  GET /dbs/certigo/colls/content/docs
                                 + en-tete x-ms-continuation
```

L'upsert d'un document, en REST brut :

```text
POST https://<compte>.documents.azure.com/dbs/certigo/colls/content/docs
  x-ms-date                          <date RFC1123 en GMT>
  x-ms-version                       2018-12-31
  Content-Type                       application/json
  x-ms-documentdb-is-upsert          true
  x-ms-documentdb-partitionkey       ["<trackId>"]
  Authorization                      urlencode("type=aad&ver=1.0&sig=<jeton AAD>")
```

**Le format de l'en-tête `Authorization` a été validé par l'exécution**, pas par la documentation :
c'est le passage du document sentinelle qui l'a prouvé.

### Sortie de l'exécution réussie

```text
DOCS_TO_WRITE 383
TOKEN_OK len 1794
UPSERT_OK 383 ERRS 0
FINAL_COUNT 383 PAGES 1
DONE
```

> **`FINAL_COUNT` ne partage aucun code avec `UPSERT_OK`.** Le premier relève le conteneur, le
> second compte les appels réussis. **Un compteur d'écriture ne peut pas se contredire lui-même ;
> deux instruments indépendants, si.** C'est le contrôle qu'on omet le plus souvent, et il coûte
> quelques lignes.

### Trois échecs avant le succès — ils font partie de la procédure

| # | Ce qui a échoué | Nature | Ce qu'il faut en retenir |
|---|---|---|---|
| 1 | `az vm create` → `SkuNotAvailable` sur `Standard_B2s` en westeurope | Capacité régionale | Le `finally` a tout nettoyé, rôle jamais créé, 0,9 min écoulées. **Prévoyez un SKU de repli** — `D2as_v6` a fonctionné. |
| 2 | Sonde `SELECT VALUE COUNT(1) FROM c` → `HTTP 400 BadRequest`, « cross partition query can not be directly served by the gateway » | Requête interdite en REST brut | La sonde levait avant la boucle d'upsert : **zéro document écrit**. Les agrégats inter-partitions exigent un plan de requête que les SDK produisent et qu'un client de bibliothèque standard ne produit pas. |
| 3 | — | — | Sonde **retirée**, comptage remplacé par un read-feed paginé. Succès. |

L'échec n°2 mérite sa règle, parce qu'il n'était pas un défaut de robustesse mais de placement :

> **Un contrôle placé en amont d'une opération est une garde, qu'on le veuille ou non.** Avant de
> l'écrire, posez la question qui le classe : *si ce contrôle échoue, l'opération doit-elle
> s'arrêter ?* **Oui → c'est une garde, sa place en amont est légitime. Non → c'est une sonde, sa
> place est en aval.** Ici la réponse était non, et une sonde mal placée a coûté une exécution
> complète.

Cette règle ne concerne ni Cosmos, ni Azure, ni le seed : elle est générale et vit dans
[`docs/GOVERNANCE.md`](../GOVERNANCE.md), sous **« Une sonde en amont est une garde déguisée »**,
avec le coût mesuré de ce cas. **C'est là qu'il faut la lire et la citer** ; la présente page n'en
garde que les circonstances.

**Cinq causes d'échec sur cette journée, de cinq natures différentes : pare-feu (refus franc), policy
`modify` (succès attesté, valeur réécrite), verrou `CanNotDelete` (refus franc), `SkuNotAvailable`
(capacité), et notre propre sonde (exacte, et mal placée). Une seule sur cinq a menti — et la
cinquième venait de notre code.** La ventilation générale de ces natures — celles qui se déclarent,
celle qui ment, celle qui est physique, et la nôtre — est dans `GOVERNANCE.md` sous **« Trois
obstacles se déclarent, un seul ment — et le quatrième est physique »**.

---

## 5. Démontage — chaque élément relu, dans cet ordre

**L'ordre n'est pas cosmétique : le rôle se retire en premier**, parce que son retrait exige la
levée du verrou et que cette levée doit être la fenêtre la plus courte possible. Détruire la VM
d'abord laisserait un rôle orphelin sur le compte Cosmos si la suite échouait.

**Une procédure d'urgence sans démontage relu est un piège.** Un nettoyage interrompu est pire qu'un
échec : l'échec laisse un état connu, l'interruption laisse un état que personne n'a décrit.

| # | Action | Relecture de vérification | Attendu |
|---|---|---|---|
| 1 | Lever le verrou, supprimer l'attribution de rôle du MSI de la VM, **restaurer le verrou à l'identique** | `az cosmosdb sql role assignment list -g $RG -a $ACCOUNT -o table` | **Seule** la baseline subsiste (le MSI du Function App) |
| 2 | — | `az lock list -g $RG -o table` | `lock-delete-protection`, type `CanNotDelete`, présent |
| 3 | Supprimer la VM (NIC et disque en `delete-option Delete`) | `az vm show -g $RG -n vm-certigo-seed` | **exit 3** — introuvable |
| 4 | Supprimer le sous-réseau transitoire | `az network vnet subnet show -g $RG --vnet-name vnet-certigo-prod -n snet-seed` | **exit 3** — introuvable |
| 5 | — | `az cosmosdb show -g $RG -n $ACCOUNT --query "{pna:publicNetworkAccess, ip:ipRules, dla:disableLocalAuth}"` | `Disabled`, `[]`, `true` — identiques à l'état AVANT |

**Chaque ligne du tableau a été exécutée et relue le 2026-09-09.** Le sous-réseau `snet-seed` a été
observé subsistant en cours d'opération : c'était le transitoire d'une tentative **encore en vol**,
pas un `finally` interrompu. Il a bien été supprimé à la fin de chacune des trois tentatives, relu
introuvable à chaque fois.

> **Un nom ne dit pas un état.** `snet-seed` dit vrai — ressource transitoire liée à un chargement —
> et il est pourtant **impossible d'en déduire si l'opération est en cours ou abandonnée**. Devant
> une ressource transitoire dont l'état est ambigu, **ne rien faire est le comportement par défaut** :
> la supprimer aurait cassé la VM et la NIC d'une exécution active. L'instinct pousse vers l'action
> corrective, et c'est exactement celle qui casse.

Là encore, la règle est générale et n'appartient pas à cette page : voir
[`docs/GOVERNANCE.md`](../GOVERNANCE.md), **« La limite structurelle de la ressource transitoire —
ce que le nom ne peut pas porter »** et **« L'asymétrie de l'incertitude — le défaut, par règle, est
l'attente »**.

### Les pièges de nettoyage rencontrés

- **PowerShell supprime la chaîne vide.** `az cosmosdb update --ip-range-filter ""` est interprété
  comme un argument omis, donc **sans effet**, et rend `exit 0`. Le vidage effectif des règles IP a
  exigé de passer par `cmd.exe` pour transmettre une chaîne vide littérale.
- **`ipRules: []` par PATCH ARM est un no-op** : un tableau vide est lu comme « pas de changement ».
- **Le plan de contrôle Cosmos sérialise ses opérations.** Une opération concurrente rend
  `PreconditionFailed` ; il faut attendre que le compte soit au repos et réessayer.
- **`az rest --body` en JSON inline est déformé par PowerShell.** Écrivez le corps dans un fichier et
  passez `--body "@fichier"`.

Ces quatre pièges partagent un trait : **trois d'entre eux rendent `exit 0` en n'ayant rien fait.**
C'est la même famille que la policy `modify`, et la même parade : relire.

---

## 6. Ce qui reste incertain ou non vérifié

- **L'application n'est pas redevenue utilisable ce soir-là.** Le chargement a fait disparaître le
  503, et un **autre** échec est apparu : « Connexion impossible, réponse inattendue ». Cause
  mesurée le 2026-09-09 et **sans rapport avec le seed** : le backend de production tournait sur une
  révision déployée le 2026-08-16, dont le contrat de catalogue avait divergé du client. **Un
  conteneur rempli ne suffit pas ; il faut aussi que la révision déployée en production sache le
  servir.** Vérifiez la révision déployée avant de conclure qu'un seed a échoué.
- **La policy n'a jamais été identifiée.** Seul son effet a été mesuré. Nom, périmètre et existence
  d'autres effets `modify` : non mesurés.
- **La limite de charge utile de `run-command`** n'a pas été mesurée ; la compression est une
  précaution, pas une réponse à un refus observé.
- **Le canal exact de `az vm run-command`** (agent invité, pas de sortie Internet requise) est un
  raisonnement de conception, corroboré par le fait que l'exécution a réussi dans un VNet sans
  sortie — mais **il n'a pas été isolé par une mesure dédiée**.
- **La durée de création de la VM a varié de ~7 min à ~1,5 min** entre deux tentatives, sans
  explication mesurée. Ne dimensionnez pas un budget sur la valeur basse.
- **Le script de seed exécuté sur la VM n'a pas été conservé.** Il vivait dans un espace de travail
  de session, jamais versionné. Ce document en décrit la forme assez précisément pour le réécrire,
  mais **le code exact n'existe plus** — c'est la raison d'être de cette page, et l'erreur à ne pas
  répéter.
- **La vérification anonyme par l'API est impossible.** `GET /api/catalog/tracks` est anonyme dans le
  code, mais l'intergiciel JWT de l'application rend `401`. La seule preuve externe reste le relevé
  du conteneur, puis l'ouverture de l'application par une personne authentifiée.

---

## 7. Ce qu'il faut faire à la place, la prochaine fois

Cette procédure ne devrait plus jamais servir. Elle demande 25 minutes d'expertise, un accès Azure
étendu, la levée d'un verrou de production et la création d'une ressource dans un VNet de
production — pour un geste dont la fréquence normale est hebdomadaire.

👉 **[« Rendre la publication de contenu routinière — plan d'activation »](../plans/PUBLICATION_CONTENU_FACILE.md)**
recommande d'activer le pipeline versionné déjà présent, dont les points d'entrée d'administration
sont joignables en HTTPS sans aucun accès Cosmos ni VNet.
**[« Runbook — import, promotion et rollback des releases de contenu »](./CONTENT_RELEASES.md)**
en décrit l'exécution.

> **Une contrainte bien posée n'interdit pas : elle oriente.** Le cadrage initial rendait l'ouverture
> du pare-feu coûteuse — budget de temps, adresse stable, interdiction d'élargir. Il n'a pas rendu
> l'ouverture plus sûre : **il l'a rendue assez chère pour qu'une voie qui l'évite soit cherchée.**
> Le résultat n'est pas « zéro seconde d'exposition malgré les contraintes », c'est « zéro seconde
> d'exposition grâce à elles ».
