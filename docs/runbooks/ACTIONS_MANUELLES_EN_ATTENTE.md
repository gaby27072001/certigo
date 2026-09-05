# Actions manuelles en attente

> **Objet** — Ce fichier ne liste QUE les actions qu'il est **impossible d'automatiser** depuis un
> agent, avec la raison exacte du blocage. Tout ce qui pouvait être automatisé l'a été et n'apparaît
> donc pas ici. **L'objectif est que ce fichier tende vers zéro entrée.**
>
> **Dernière revue** : 2026-09-04 — session « Actions résiduelles ».

## Résumé

| # | Action | Finding | Criticité | Pourquoi ce n'est pas automatisable |
|---|---|---|---|---|
| 1 | Enregistrer une méthode MFA forte sur le compte break-glass | R-04 (nouveau constat) | 🔴 Haut | Acte d'établissement de credential sur un compte d'urgence : exige une décision humaine explicite et la possession physique du facteur. |
| 2 | **Déployer** le correctif DNS privé (code déjà fusionné), puis lancer le test de charge | O-02 | 🔴 Haut | Le code Bicep est fusionné (#380) ; il reste un **déploiement Azure** à décider et exécuter, puis une exécution obligatoire depuis un runner **dans** le VNet. |

Aucune autre action manuelle n'est en attente. Les points 1 et 2 ci-dessous sont détaillés.

---

## 1. Enregistrer une méthode MFA forte sur `breakglass@certigoapp.onmicrosoft.com`

### Constat (vérifié le 2026-09-04)

Trois faits, chacun lu directement depuis Microsoft Graph :

1. Les **security defaults sont ACTIVÉS** dans le tenant CIAM
   (`GET /policies/identitySecurityDefaultsEnforcementPolicy` → `"isEnabled": true`).
2. Les security defaults **imposent le MFA à tous les administrateurs** et
   **n'acceptent aucune exclusion** (contrairement à une policy Conditional Access).
3. Le compte break-glass n'a **qu'une seule méthode d'authentification enregistrée** :
   `#microsoft.graph.passwordAuthenticationMethod`
   (`GET /users/6503a9b1-1e64-4c39-9ec7-c15a1c911c80/authentication/methods`).
   **Aucune** méthode forte (FIDO2, Authenticator, OATH, TAP, téléphone).

### Impact — risque de perte de contrôle du tenant

Sous des security defaults **obligatoires et sans exclusion possible**, un compte dont la **seule**
méthode est un mot de passe **ne peut pas terminer sa connexion**. Le compte de secours est donc,
aujourd'hui, **non fonctionnel**.

Conséquence en chaîne : le seul administrateur réellement opérationnel du tenant CIAM est un
**compte gmail fédéré**. Si l'accès à ce compte gmail est perdu, compromis, ou si la fédération MSA
tombe, **le tenant qui porte l'authentification de production devient irrécupérable**.

Ce n'est donc pas un point d'hygiène : c'est un **risque de verrouillage du tenant**.

> ℹ️ **À verser au dossier d'audit** : le runbook `R-04` avait **prédit ce cas** de façon
> conditionnelle (« *Si activés et qu'aucun CA n'existe, le compte break-glass devra satisfaire le
> MFA des security defaults → enregistrer sa méthode MFA à l'avance* »). Les trois conditions sont
> aujourd'hui **confirmées vraies**. L'avertissement existait donc, correctement formulé, **et
> personne ne surveillait les conditions de son déclenchement**. C'est ce défaut de surveillance —
> et non l'absence d'analyse — qui a laissé l'écart s'installer. Le contrôle automatique décrit plus
> bas corrige précisément cela.

### Pourquoi l'agent ne l'a pas fait

Enregistrer un facteur d'authentification sur un compte d'urgence est un **acte d'établissement de
credential**. Il exige :

- une **décision humaine explicite** (le coordinateur a demandé à en être informé au préalable) ;
- la **possession physique** du facteur (clé FIDO2, ou appareil portant Authenticator) ;
- la **mise sous scellé** du facteur avec le mot de passe, dans le coffre hors-ligne.

Aucun de ces trois points n'est réalisable par un agent.

### Deux options — comparaison et recommandation

La question « faut-il forcément acheter une clé matérielle ? » mérite une réponse argumentée. Voici
les deux voies réalistes, avec leur coût réel et ce qu'elles valent.

| Critère | **Option A — Clé FIDO2 dédiée** | **Option B — Application d'authentification (TOTP / Authenticator)** |
|---|---|---|
| Coût / friction | Achat d'une clé (~25-50 €) + rangement au coffre | **Nul** — logiciel uniquement |
| Résistance au hameçonnage | ✅ Oui (cryptographie liée au domaine) | ❌ Non (code recopiable, push approuvable par erreur) |
| Dépendance à un appareil | Aucune (la clé *est* le facteur) | ⚠️ Forte — appareil, batterie, réseau, état de l'app |
| Position de Microsoft | ✅ **« Recommended »** pour les comptes d'urgence | ⚠️ Cité comme le facteur du compte admin **normal**, donc à **ne pas réutiliser** pour le compte d'urgence |
| Risque de partage de facteur avec le compte gmail | Nul | 🔴 **Élevé** si installée sur le téléphone personnel du propriétaire |

**Ce que dit explicitement Microsoft** (guide *Manage emergency access accounts*) :

> « Use strong authentication for your emergency access accounts and make sure it **doesn't use the
> same authentication methods as your other administrative accounts**. For example, if your normal
> administrator account uses the Microsoft Authenticator app for strong authentication, **use a FIDO2
> security key for your emergency accounts**. »

> « **Don't connect these accounts with any employee-supplied devices, such as phones.** »

> Si le compte est malgré tout enregistré sur un appareil : cet appareil doit être « accessible to
> **all administrators** who might need to use it during an emergency » et joignable par « **at least
> two network paths that don't share a common failure mode** ».

### 👉 Recommandation : **Option A (FIDO2)**

L'option B **n'est pas interdite**, mais dans *ce* contexte précis elle est nettement plus faible :

- Le seul autre administrateur est un **compte gmail fédéré**. Si son MFA est déjà Microsoft
  Authenticator sur le téléphone du propriétaire, mettre Authenticator sur **le même téléphone**
  pour le compte break-glass fait **partager le mode de défaillance** aux deux comptes — un
  téléphone perdu, volé, cassé ou réinitialisé emporterait alors **les deux** accès administrateur.
  C'est exactement le scénario que le compte break-glass existe pour couvrir.
- Un appareil « indépendant » satisfait la règle **sur le papier**, mais ses conditions (accessible
  à tout administrateur, deux chemins réseau indépendants, jamais réinitialisé, batterie vivante)
  **s'érodent silencieusement**. Personne ne s'en aperçoit avant le jour J.
- Une clé FIDO2 rangée au coffre avec le mot de passe n'a ni batterie, ni réseau, ni mise à jour, ni
  compte associé. Elle ne se dégrade pas toute seule.

**Si l'Option B est retenue malgré tout**, elle reste **très supérieure au statu quo** (aujourd'hui le
compte est inutilisable). Conditions minimales alors : appareil **dédié**, **jamais** le téléphone
personnel du propriétaire, rangé avec le mot de passe, et **méthode différente** de celle du compte
gmail. Préférer **Software OATH (TOTP)** à la notification push : la *seed* TOTP peut être scellée au
coffre, ce qui rend le facteur **reproductible sur n'importe quel appareil** en cas de perte —
avantage décisif sur la notification Authenticator, qui meurt avec son téléphone.

> 🔁 **C'est la même erreur structurelle que le moniteur circulaire de `R-05`.**
> Là-bas, le dispositif censé détecter l'expiration des secrets détenait lui-même un secret qui
> expirerait : **le moniteur partageait le mode de défaillance de son sujet**. Ici, mettre
> Authenticator sur le téléphone du propriétaire pour **à la fois** le compte gmail administrateur
> **et** le compte break-glass ferait partager **un seul mode de défaillance à deux identités
> administratives** — alors que la seconde n'existe que pour survivre à la perte de la première.
> Un téléphone perdu emporterait les deux.
>
> Même leçon, deux domaines différents : **un dispositif de secours ne doit jamais dépendre de ce
> dont il est le secours.** C'est le critère à appliquer pour trancher entre les options ci-dessus.

> ℹ️ `Fido2`, `MicrosoftAuthenticator`, `SoftwareOath` et `TemporaryAccessPass` sont **tous déjà
> activés** dans la policy de méthodes du tenant (lu le 2026-09-04). Aucune activation préalable
> n'est nécessaire, quelle que soit l'option retenue.

### ⚠️ À vérifier avant d'acheter une clé — spécificité « tenant externe »

La documentation External ID indique que, dans un **tenant externe**, l'enregistrement d'un passkey
« **requires a custom URL domain** ». Or ce tenant n'a **aucun domaine personnalisé** : `GET /domains`
ne renvoie que `certigoapp.onmicrosoft.com` (vérifié le 2026-09-04).

Cette restriction est documentée pour les **utilisateurs de comptes locaux dans les user flows**, pas
pour les **administrateurs de l'annuaire** — qui se connectent via `login.microsoftonline.com` et non
via `certigoapp.ciamlogin.com`. Elle **ne devrait donc pas** s'appliquer ici. Mais ce n'est pas
vérifiable sans tenter l'enregistrement, et l'agent ne doit pas le faire.

👉 **Vérifiez ceci en premier, avant tout achat** : à l'étape 2 ci-dessous, si l'option « Clé de
sécurité » est absente ou refusée, basculez sur l'**Option B (Software OATH)** et signalez-le — cela
constituerait un constat supplémentaire à documenter.

### Réduire la friction : bootstrap par Temporary Access Pass (TAP)

Problème d'amorçage : pour enregistrer une méthode, il faut souvent déjà en avoir une. `TemporaryAccessPass`
est **activé** dans ce tenant, ce qui offre une porte de sortie propre. Depuis le compte GA gmail :

```bash
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/users/6503a9b1-1e64-4c39-9ec7-c15a1c911c80/authentication/temporaryAccessPassMethods" \
  --headers "Content-Type=application/json" \
  --body '{"lifetimeInMinutes": 60, "isUsableOnce": true}'
```

Le TAP renvoyé (usage unique, 60 min) permet au compte break-glass de se connecter **et d'enregistrer
sa méthode forte** sans facteur préexistant. Utilisez-le immédiatement, puis passez à l'étape 2.

### Procédure

**Étape 1 — se connecter en navigation privée avec le compte break-glass**

Ouvrez une fenêtre de navigation privée et allez sur :

```text
https://myaccount.microsoft.com/?tenantId=af721be8-5901-422a-b299-b9c57847b968
```

Connectez-vous avec `breakglass@certigoapp.onmicrosoft.com` et le mot de passe du coffre (ou le TAP
ci-dessus).

> Les security defaults vont **exiger l'enregistrement d'un MFA** dès cette connexion. C'est
> attendu : c'est exactement l'opération que l'on veut réaliser **maintenant, à froid**, plutôt que
> dans l'urgence.

**Étape 2 — enregistrer la méthode forte**

Dans **Informations de sécurité** → **Ajouter une méthode de connexion** :

- **Option A** : **Clé de sécurité** → insérez la clé physique dédiée, définissez son PIN, nommez-la
  par exemple `certigo-breakglass-fido2`.
- **Option B** (si A indisponible) : **Application d'authentification** → **« J'aimerais utiliser une
  autre application »** pour obtenir une *seed* TOTP. **Notez la seed** et scellez-la au coffre avec
  le mot de passe.

**Étape 3 — vérifier depuis un poste opérateur (lecture Graph)**

```bash
az login --tenant af721be8-5901-422a-b299-b9c57847b968 --allow-no-subscriptions

az rest --url "https://graph.microsoft.com/v1.0/users/6503a9b1-1e64-4c39-9ec7-c15a1c911c80/authentication/methods" \
  --query "value[].'@odata.type'" -o json
```

✅ **Critère de succès** : la liste contient une méthode forte — `#microsoft.graph.fido2AuthenticationMethod`
(Option A) ou `#microsoft.graph.softwareOathAuthenticationMethod` (Option B) — **en plus** de
`#microsoft.graph.passwordAuthenticationMethod`.

> Si la commande renvoie `403 Forbidden`, le jeton délégué ne porte pas
> `UserAuthenticationMethod.Read.All`. Ce n'est pas bloquant : le workflow planifié
> `ciam-posture-monitor` vérifie ce point automatiquement chaque jour (voir ci-dessous) et
> échouera tant que la méthode forte est absente.

**Étape 4 — test de connexion réel (obligatoire)**

Déconnectez-vous, puis reconnectez-vous en navigation privée avec la nouvelle méthode pour confirmer
que le parcours complet fonctionne. C'est le seul moyen de garantir que le compte servira le jour J.

**Étape 5 — sceller**

Rangez le facteur **avec** le mot de passe dans le coffre hors-ligne :

- **Option A** : la clé FIDO2 physique, avec son PIN noté séparément.
- **Option B** : la *seed* TOTP, qui permet de reconstituer le facteur sur n'importe quel appareil.

Mettez à jour la fiche d'urgence de `R-04`.

> 📌 **Rappel Microsoft** : la bonne pratique est de disposer de **deux** comptes d'urgence, stockés
> dans **deux lieux distincts**, et de **valider leur fonctionnement au moins tous les 90 jours**.
> `R-04` note déjà que ce projet n'en a qu'un. Une fois le point ci-dessus réglé, envisagez
> `breakglass2@…` — le contrôle automatique couvrira alors les deux.

### Contrôle automatique associé

Une fois l'étape 2 réalisée, aucune surveillance manuelle n'est nécessaire : le workflow
`.github/workflows/ciam-posture-monitor.yml` vérifie **chaque jour** que le compte break-glass
conserve une méthode forte enregistrée, et ouvre une issue GitHub s'il n'en a plus
(code `BREAK_GLASS_NO_STRONG_METHOD`).

---

## 2. Test de charge Azure OpenAI (`O-02`)

### Constat (vérifié le 2026-09-04)

Le test de charge n'a **pas pu être exécuté**. La cause est précise et unique : **la résolution DNS
privée**, et non le routage réseau.

| Élément | État mesuré | Conséquence |
|---|---|---|
| `certigo-openai` `publicNetworkAccess` | `Disabled` | Accessible uniquement via endpoint privé. **À conserver tel quel.** |
| Private endpoint `pep-certigo-openai-account` | `vnet-certigo-dev/snet-private-endpoints` → `10.60.0.75` | OK |
| Peering `vnet-certigo-ci` ↔ `vnet-certigo-dev` | `Connected` (bidirectionnel) | **Le routage IP fonctionne déjà.** |
| Zone DNS `privatelink.openai.azure.com` (RG `rg-certigo-dev`) | Liée **uniquement** à `vnet-certigo-dev` | ❌ **BLOCAGE** — un runner CI ne peut pas résoudre le nom privé. |
| Zones `blob` / `documents` / `queue` / `table` / `vaultcore` (RG `rg-certigo-ci`) | Liées aux **4** VNets | Montre que le lien manquant est une **omission**, pas un choix. |

Autrement dit : un runner `vmss-certigo-runner-zonal` (dans `vnet-certigo-ci`) **peut atteindre**
`10.60.0.75` par le peering, mais il **ne peut pas apprendre cette adresse**, faute de lien vers la
zone DNS privée. Il résoudrait le nom public, qui est fermé.

> 🔎 **Constat latent additionnel — incohérence de nom d'hôte.**
> Le compte annonce l'endpoint `https://certigo-openai.cognitiveservices.azure.com/`
> (`properties.endpoint`), mais la **seule** zone privée déployée est
> `privatelink.openai.azure.com` (enregistrement `certigo-openai` → `10.60.0.75`). Aucune zone
> `privatelink.cognitiveservices.azure.com` n'existe dans la subscription. Un client qui utilise
> l'endpoint annoncé par le compte **échouera à résoudre en privé, même depuis `vnet-certigo-dev`**.
> Seule la forme `https://certigo-openai.openai.azure.com/` est résoluble. À corriger en même temps
> que le point ci-dessous, sans quoi le test de charge échouera pour une deuxième raison.

### Ce qui a été délibérément **écarté**

**Activer `publicNetworkAccess`** aurait rendu le test trivial. C'est **exclu** : cela dégraderait la
posture réseau de façon permanente pour un besoin de mesure ponctuel. La consigne est explicite et
elle est la bonne.

### Pourquoi ce n'est pas automatisable dans cette PR

Deux blocages **indépendants**, qui doivent tous deux être levés :

1. **Changement d'infrastructure.** Le lien de zone DNS manquant doit être ajouté **en Bicep**
   (`infra/` est géré en IaC, tag `managedBy: bicep`). Le créer à la main via `az` créerait une
   dérive entre l'état réel et les templates — exactement le type d'écart que cet audit corrige.
2. **Lieu d'exécution.** Même le DNS corrigé, le test doit s'exécuter **depuis un runner situé dans
   le VNet**. Un workflow planifié ou `repository_dispatch` n'est chargé que depuis la branche
   `main` : il faut donc que le workflow soit **mergé** avant de pouvoir être lancé. La machine de
   l'agent est hors VNet et ne peut en aucun cas atteindre l'endpoint privé.

### Étape 1 — lever le blocage DNS — ✅ **CODE FUSIONNÉ, DÉPLOIEMENT RESTANT**

> **Mise à jour du 2026-09-05.** Le correctif Bicep est **écrit, revu et fusionné** dans `main`
> (PR #380, commit `b5b80dfc`). Il n'y a **plus de code à écrire**. Ce qui reste est un
> **déploiement**, décrit à l'étape 1b.

Le correctif livré est **plus large** que le simple lien manquant décrit à l'origine. Un compte
`kind: AIServices` répond sur **trois** suffixes publics, et chacun exige sa propre zone privée —
or **deux des trois n'existaient pas du tout**. `infra/modules/openAiPrivateDns.bicep` crée donc :

| Ressource | Rôle |
|---|---|
| zone `privatelink.cognitiveservices.azure.com` | **manquante** — suffixe annoncé par `properties.endpoint` du compte |
| zone `privatelink.services.ai.azure.com` | **manquante** — suffixe utilisé par `tutorLlmEndpoint` dans `dev.bicepparam` |
| liens VNet dev + CI sur les trois zones | résolution depuis l'app **et** depuis le runner de confiance |
| entrées du **DNS zone group** du private endpoint | écrit les enregistrements A dans les nouvelles zones |

> ⚠️ **Pourquoi les trois catégories sont dans un seul module.** Une zone DNS privée liée à un VNet
> fait **autorité** sur son espace de noms : une zone liée mais **vide** répond `NXDOMAIN` au lieu de
> laisser la requête retomber sur le DNS public. Créer les zones et leurs liens **sans** les entrées
> du zone group (qui écrivent les enregistrements A) ferait donc passer la résolution de
> « résout en public puis refusé » à « ne résout plus du tout » — strictement pire, avec un symptôme
> sans rapport apparent avec le changement. Ne jamais scinder ces trois éléments.

### Étape 1b — déployer (action manuelle restante)

Le code est sur `main` mais **rien n'est déployé** : `rg-certigo-dev` ne contient toujours qu'une
seule zone privée. Le paramètre `adoptOpenAiPrivateDns` vaut `true` en dev uniquement.

```bash
az account set --subscription b8952c8c-8f72-469d-99cd-ac906da4e2fc

# 1. Rejouer le plan et le relire (attendu : 7 Create, 0 Delete, 0 Modify)
az deployment sub what-if \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam

# 2. Appliquer
az deployment sub create \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam
```

> 🔐 **Ne jamais passer `publicNetworkAccess` à `Enabled`.** Le compte doit rester privé. Ce
> déploiement n'ouvre aucun accès public : il ajoute uniquement de la **résolution de noms** pour des
> VNets déjà appairés et déjà de confiance (`registrationEnabled: false` partout).

**Vérification après déploiement** — les trois zones doivent exister et porter un lien CI :

```bash
az network private-dns zone list \
  --subscription b8952c8c-8f72-469d-99cd-ac906da4e2fc -g rg-certigo-dev \
  --query "[].name" -o tsv
# Attendu : les 3 zones. Aujourd'hui : seulement privatelink.openai.azure.com.

for z in privatelink.openai.azure.com privatelink.cognitiveservices.azure.com privatelink.services.ai.azure.com; do
  echo "== $z"
  az network private-dns link vnet list \
    --subscription b8952c8c-8f72-469d-99cd-ac906da4e2fc -g rg-certigo-dev -z "$z" \
    --query "[].{link:name, state:virtualNetworkLinkState}" -o tsv
done
# Attendu : un lien vnet-certigo-ci en Completed sur CHACUNE des trois.
```

Puis, **depuis un runner `certigo-trusted`** (jamais depuis un poste hors VNet) :

```bash
getent hosts certigo-openai.openai.azure.com
# Attendu : 10.60.0.75 (adresse privée). Toute autre adresse = le lien DNS n'est pas effectif.
```

### Étape 2 — exécuter le test de charge

Une fois le DNS résolu depuis le VNet CI, le protocole de mesure (paliers 500 → 3000 TPM, seuils
429, TTFT/latence, quota régional puis bump de capacity) est **déjà entièrement rédigé** dans
[`O-02_plan-test-charge-openai.md`](./O-02_plan-test-charge-openai.md). Il n'y a rien à réécrire :
il faut l'exécuter depuis un job `certigo-trusted` et consigner les chiffres réels.

⚠️ Utiliser l'hôte `https://certigo-openai.openai.azure.com/` (et **non** l'endpoint
`.cognitiveservices.azure.com` annoncé par le compte), tant que le constat latent ci-dessus n'est
pas corrigé.

---

## Ce qui a été automatisé (pour mémoire — aucune action requise)

Ces points figuraient dans les actions résiduelles et **ne nécessitent plus rien** :

| Sujet | Verdict | Preuve |
|---|---|---|
| Security defaults CIAM (`CIAM-2` partie 1) | ✅ **Déjà conformes** | `isEnabled: true` lu via jeton applicatif `Policy.Read.All`. |
| MFA des Global Administrators (`CIAM-2` partie 2) | ✅ **Déjà appliqué** — sans Conditional Access | Les security defaults imposent le MFA admin ; créer une policy CA **exigerait de les désactiver** → régression. Voir `R-04`. |
| Alerte d'expiration des 3 secrets (`R-05`) | ✅ **Automatisé** | Workflow `ciam-posture-monitor.yml` (quotidien, seuil 90 j, ouvre une issue). |
| Test de restauration PITR Cosmos (`R-02`) | ✅ **Exécuté et prouvé** | Restore staging réel du 2026-09-04, 8 containers vérifiés, compte temporaire supprimé. Voir `R-02`. |

---

## Voir aussi

- [`R-04_compte-break-glass-ciam.md`](./R-04_compte-break-glass-ciam.md) — compte d'urgence, fiche
  de procédure et posture MFA.
- [`R-05_rotation-secret-idp-msa.md`](./R-05_rotation-secret-idp-msa.md) — rotation du secret IdP,
  déclenchée par l'alerte automatique.
- [`R-02_cosmos-pitr-restauration.md`](./R-02_cosmos-pitr-restauration.md) — preuve de restauration.
- [`O-02_plan-test-charge-openai.md`](./O-02_plan-test-charge-openai.md) — protocole de test de charge.
