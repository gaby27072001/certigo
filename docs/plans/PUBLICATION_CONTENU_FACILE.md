# Rendre la publication de contenu routinière — plan d'activation

> Statut : **proposition**. Ce document ne modifie rien en production. Il recommande
> d'**activer** un pipeline qui existe déjà, mesuré comme dormant, plutôt que d'en
> construire un nouveau.
>
> Discipline de preuve : chaque affirmation est marquée **[MESURÉ]** (vérifiée le
> 2026-09-09 par lecture du dépôt et lecture seule Azure) ou **[SUPPOSÉ]** (inférence à
> confirmer avant exécution). Un dispositif jamais exécuté n'est pas un dispositif qui
> marche.

## Le problème vécu

Publier du contenu aujourd'hui = `tools/seed_content.py --cosmos` écrit **directement**
dans Cosmos. Or le compte Cosmos de production est `publicNetworkAccess: Disabled`, forcé
par une Azure Policy à effet `modify` : impossible de le rouvrir. Il a donc fallu une VM
éphémère dans le VNet de prod, un rôle data-plane, la levée d'un verrou, puis tout
détruire — 25 minutes d'expert, infaisable depuis l'extérieur.

Cette intervention a été exécutée **une seule fois**, le 2026-09-09. Sa trace complète —
comportement exact de la policy, verrou, méthode rejouable et démontage relu — est
consignée dans [« Seed d'urgence du conteneur `content` de production »](../runbooks/SEED_URGENCE_COSMOS_PROD.md).
Elle n'y figure pas comme procédure à rejouer, mais comme la mesure de ce que le présent
plan doit rendre inutile.

## Recommandation en une phrase

**Activer le pipeline de contenu versionné déjà présent**, dont la moitié « publication »
tourne déjà et dont la configuration d'activation **tourne déjà en dev**. La publication
routinière ne demande alors **aucun accès Cosmos ni VNet** à l'auteur : le Function App,
déjà à l'intérieur du réseau, lit le contenu par son identité managée et l'écrit dans
Cosmos ; on le déclenche par un appel HTTPS.

---

## 1. Le pipeline versionné est-il réellement complet et utilisable ?

**Il est complet en code et à moitié exécuté. La moitié « publication vers le stockage
immuable » tourne et a produit une vraie release. La moitié « ingestion dans Cosmos +
bascule » n'a jamais tourné en prod.**

### Ce qui existe et fonctionne

- **[MESURÉ]** Les 5 endpoints d'administration existent, avec autorisation par rôle
  applicatif : `ContentReleaseFunctions.cs` — `content/admin/releases/{id}/import`,
  `.../{id}/promote`, `content/admin/releases/rollback`, `content/admin/releases/pointer`,
  `content/releases/active/manifest`.
- **[MESURÉ]** Le service `ContentReleaseService` est cohérent : import **idempotent**
  (rejoue par `releaseId` déjà importé), promote/rollback avec **concurrence optimiste par
  ETag** (`If-Match` obligatoire). Le `releaseId` est une identité de contenu
  `sha256:…` re-vérifiée.
- **[MESURÉ]** L'import lit la matière première depuis un **blob**
  (`IContentReleaseSource` → `BlobContentReleaseSource`), vérifie les digests SHA-256,
  projette en contenu runtime, puis écrit dans Cosmos (`CosmosContentReleaseStore` →
  conteneurs `content-public`, `content-private`, `content-control`). **Ce n'est donc pas
  un écrit direct dans Cosmos depuis l'extérieur.**
- **[MESURÉ]** Les conteneurs Cosmos versionnés sont dans la topologie canonique
  `contracts/cosmos-containers.json`, déployée par `infra/modules/cosmos.bicep` — l'import a
  une cible.
- **[MESURÉ]** Le routeur `ContentRepositoryRouter` bascule legacy/versioned selon
  `CONTENT_REPOSITORY_MODE` sans toucher au conteneur legacy tant qu'on est en `legacy`.
- **[MESURÉ]** Couverture de tests présente : `ContentReleaseServiceTests`,
  `ContentReleaseFunctionsTests`, `CosmosContentReleaseStoreIntegrationTests`,
  `ContentContractVerifierValidationTests`, `RuntimeContentProjectorTests`,
  `MergedContentPackageIntegrationTests`.
- **[MESURÉ]** Le dépôt séparé `gchambaud_microsoft/certigo-content` **a publié une vraie
  release** dans le stockage immuable : workflow `publish-content-azure.yml` (manuel, depuis
  `main`, runner auto-hébergé `certigo-ci`, upload `az storage blob upload` via private
  endpoint), exécution `33965259786` en succès. Le pin `docs/active-content-reference.json`
  suit la révision `78bfa72c`, **1735 fichiers publics + 812 clés de réponse**.
- **[MESURÉ]** Le storage de contenu `stcertigocntz3wqbdww` (rg-certigo-content) est déployé,
  `publicNetworkAccess: Disabled`, private endpoint approuvé.

### Ce qui manque (le trou honnête)

- **[MESURÉ]** Le workflow de publication de `certigo-content` **n'appelle ni import ni
  promote** — c'est volontaire (runbook : « La publication n'effectue ni import, ni
  promotion, ni bascule de feature flag »). Le dernier maillon vers Cosmos n'est câblé nulle
  part automatiquement.
- **[MESURÉ]** Le Function App de **prod** n'a **aucun** réglage `CONTENT_*`. Conséquence :
  `CONTENT_REPOSITORY_MODE` par défaut = `legacy`, et l'endpoint import lèverait
  « CONTENT_BLOB_ENDPOINT is required » s'il était appelé. Le pipeline versionné est donc
  **dormant en prod**.
- **[MESURÉ]** L'identité reader `id-certigo-content-reader` n'est **pas** attachée au func
  de prod (seule `id-func-…-host` l'est).

### La nuance qui dé-risque tout

- **[MESURÉ]** Le Function App **dev** est **déjà** entièrement configuré en `versioned`,
  pointant sur le **même** storage immuable que la prod utiliserait :
  `CONTENT_REPOSITORY_MODE=versioned`,
  `CONTENT_BLOB_ENDPOINT=https://stcertigocntz3wqbdww.blob.core.windows.net/`,
  `CONTENT_STORAGE_CLIENT_ID=cabec54e…` (= `id-certigo-content-reader`, attachée au func
  dev). **La recette d'activation existe et tourne déjà dans un environnement inférieur.**
- **[MESURÉ]** Staging n'a aucun réglage `CONTENT_*`, comme prod. Ordre de déploiement
  naturel : dev (fait) → staging → prod.
- **[SUPPOSÉ]** Que dev ait effectivement importé+promu une release (non vérifié pour ne pas
  interroger Cosmos). À confirmer par un simple GET `content/admin/releases/pointer` sur dev.

---

## 2. Que faudrait-il pour l'activer en production ?

Cutover **étagé et réversible** : le mode `legacy` continue de servir jusqu'à la toute
dernière bascule. Rien de ce qui marche n'est cassé pendant la transition.

| # | Étape | Risque | Réversibilité |
|---|-------|--------|---------------|
| 0 | **Répéter et vérifier sur staging** la séquence complète (réglages → import → promote → flip → lecture app). Staging n'a rien aujourd'hui ; c'est le vrai galop d'essai. | Faible | Total (staging) |
| 1 | **Attacher `id-certigo-content-reader` au func de prod** et lui donner Storage Blob Data Reader au scope conteneur (comme en dev). | Faible — additif, aucune lecture app ne dépend encore du contenu versionné. | Détacher l'identité |
| 2 | **Poser les réglages `CONTENT_*` de prod** identiques à dev, **sauf** `CONTENT_ADMIN_ALLOW_DEV=false`, **et en laissant `CONTENT_REPOSITORY_MODE=legacy` pour l'instant**. | Faible — le blob client se résout mais le routeur sert toujours legacy. | Retirer les réglages |
| 3 | **Enregistrer le rôle applicatif `Content.Release.Admin`** sur l'app registration de l'API et l'assigner à l'appelant (un principal de service CI, ou l'identité admin de Gabriel). | Faible — sans lui, import/promote renvoie 403, rien d'autre. | Retirer l'assignation |
| 4 | **Appeler `POST content/admin/releases/{releaseId}/import`** en HTTPS avec un jeton portant ce rôle, `releaseId` = le pin publié. Le func lit le blob (réseau interne, identité managée), vérifie les digests, écrit dans les conteneurs versionnés. **N'affecte pas encore ce qui est servi.** | Faible — écrit dans des conteneurs neufs ; idempotent. | L'import ne bascule rien |
| 5 | **Appeler `POST .../{releaseId}/promote`** (avec `If-Match` du pointeur). Pose le pointeur actif dans `content-control`. **Toujours pas de changement pour l'app tant que le mode est legacy.** | Faible | `rollback` (ADR-020 : bouge le seul pointeur) |
| 6 | **Bascule finale : `CONTENT_REPOSITORY_MODE=versioned`** sur le func de prod. C'est **le seul geste** qui change ce que voient les utilisateurs. | Moyen — c'est le cutover réel. | **Reflip vers `legacy`** (retour immédiat au comportement actuel) |

**Chemin réseau, mesuré :**
- **[MESURÉ]** `vnet-certigo-prod` est peeré à `vnet-certigo-ci` (Connected) et la zone DNS
  privée `privatelink.blob.core.windows.net` est liée au VNet de prod. Le func de prod peut
  donc **résoudre et atteindre** le private endpoint du storage de contenu : le chemin
  lecteur existe sans accès public.
- **[MESURÉ]** Le func de prod est joignable en **HTTPS public** (restriction « Allow all »).
  Les endpoints import/promote peuvent donc être appelés **de l'extérieur** avec un jeton,
  **sans VNet**. C'est exactement ce qui fait disparaître le problème vécu.

**Ce qui vit avec l'Azure Policy, pas contre elle :** aucune étape ne rouvre l'accès public
de Cosmos ni du storage. La publication passe par le runner interne (déjà en place) ;
l'ingestion passe par le func interne ; le déclencheur est un HTTPS + jeton.

---

## 3. À quoi ressemble « ajouter une certification » — vu par Gabriel

Aujourd'hui : opération d'expert de 25 minutes, impossible depuis l'extérieur.

Après activation, le geste devient :

1. **Écrire le contenu** (une paire de fichiers : la certification côté public + ses
   réponses côté privé) dans le dépôt de contenu `certigo-content`.
2. **Ouvrir une pull request.** Un contrôle automatique valide la structure (schémas, paires
   complètes) avant toute fusion.
3. **Fusionner.** La fusion déclenche la fabrication du paquet et sa publication dans le
   coffre immuable (ça, ça marche déjà aujourd'hui).
4. **Le contenu apparaît en production**, sans qu'aucune main ne touche Azure.

**Point de franchise, à ne pas maquiller :** aujourd'hui, entre l'étape 3 et l'étape 4, il
reste **deux appels techniques** (import puis promote) que le dépôt de contenu **ne lance pas
encore tout seul**. Deux façons d'y arriver :

- **Version « presque automatique » (recommandée) :** ajouter au dépôt de contenu, **après**
  la publication, deux appels HTTPS (import puis promote) vers le Function App. Alors l'étape
  4 devient vraiment automatique : Gabriel écrit du YAML, fusionne, et le contenu arrive
  seul. C'est le petit maillon manquant, et il est simple parce que le func est joignable en
  HTTPS.
- **Version « un bouton » (intermédiaire) :** garder l'automatique jusqu'à la publication,
  puis un opérateur clique « exécuter » sur un workflow qui fait import + promote. Zéro accès
  Azure, juste un clic de validation.

Dans les deux cas, **plus jamais de VM éphémère, de verrou, ni d'accès VNet.** L'objectif
« écrire du YAML → PR → fusion → en prod » est atteignable ; le seul écart restant est ces
deux appels, à câbler une fois.

---

## 4. Alternatives

- **A — Activer le pipeline versionné (recommandé).** Coût : faible à moyen, l'essentiel est
  de la configuration + un galop d'essai staging + câbler deux appels. Bénéfice : publication
  routinière, réversible, auditée, sans accès privilégié. **C'est activer ce qui existe, pas
  construire.**
- **B — Un workflow GitHub qui écrit dans Cosmos à la fusion.** **Réaliste uniquement sur un
  runner auto-hébergé dans un VNet peeré avec la prod**, car l'accès public Cosmos est
  structurellement interdit. **[MESURÉ]** Les runners `certigo-ci` sont dans
  `vnet-certigo-ci`, peeré à prod — donc un runner interne *pourrait* techniquement joindre
  Cosmos. Mais cela recrée un écrit direct dans Cosmos (contourne toute la vérification de
  digests, l'idempotence, le rollback par pointeur) : on jetterait un dispositif de sûreté
  déjà écrit pour réintroduire le geste fragile qu'on veut supprimer. **Déconseillé.**
- **C — Statu quo (`seed_content.py --cosmos` + VM éphémère).** Coût récurrent : 25 min
  d'expert par publication, infaisable depuis l'extérieur. À ne garder que comme filet de
  secours d'urgence, pas comme voie normale.

L'option A réutilise la vérification cryptographique, l'idempotence et le rollback déjà
écrits et testés ; B et C non.

---

## 5. Le contrôle CI « Pinned content reference tracks published content »

**[MESURÉ]** Ce contrôle (`ci-content-drift.yml`, vert) compare le pin
`docs/active-content-reference.json` au **descripteur publié dans le blob**, et son propre
outil (`tools/check_published_content_release.py`) dit **explicitement** :

> « this answers "has the pin drifted from the most recently *published* release?", not "does
> the pin match what users are being *served*?" … Blob is the only source that exists today,
> so it is what this reads — but it must not be described as the serving release. »

Donc le contrôle **n'est pas ignorant** : ses commentaires savent qu'il garde le blob publié,
pas ce qui est servi (Cosmos, aujourd'hui en legacy). Le danger n'est pas un mensonge du
contrôle, mais son **nom** — « tracks published content » — qui, associé au vert, suggère à un
lecteur pressé que « publié = servi ». Or tant que le mode est `legacy`, **le contenu publié
n'est pas servi du tout.**

Recommandation :

1. **Ne pas le supprimer.** Un contrôle vert qui garde le mauvais objet est dangereux, mais
   ce contrôle garde le bon objet (le blob) — il est juste **mal nommé** pour la perception.
2. **Reformuler son intitulé** pour dire ce qu'il prouve vraiment (« le pin suit la dernière
   release *publiée* », pas « servie »).
3. **Ajouter, au moment de l'activation, un contrôle complémentaire** sur le **pointeur actif
   Cosmos** (ce qui est réellement servi) — le seul objet qui compte une fois le mode
   `versioned`. Sans lui, personne ne garde « ce que voient les utilisateurs ».

---

## Coût estimé

- **Option A, chemin recommandé :** faible à moyen. Répartition : galop d'essai staging
  (config + import/promote + vérif app) ; réplication config prod + attache identité + rôle
  applicatif ; câblage des deux appels import/promote après publication ; bascule finale du
  mode avec reflip prêt. L'essentiel est de la **configuration et de la vérification**, pas du
  développement — le code et l'infra sont déjà là et exercés en dev.
- **Réversibilité globale :** à chaque étape, un retour arrière existe ; la bascule finale est
  un simple reflip `versioned` → `legacy`.

## Prochaine décision attendue

Quelqu'un décide de lancer l'option A. Aucune de ces étapes n'a été exécutée par ce plan :
il propose, il ne touche rien en production.
