# R-05 — Rotation du secret IdP « Microsoft account » + alerte d'expiration J-30

| Champ | Valeur |
|---|---|
| **Finding** | R-05 (🔴 Haut) |
| **Constat audit** | L'IdP « Microsoft account » du flux prod dépend du secret `certigo-ciam-oidc-2026-07` (app `Certigo MSA Login` `df42c145`), qui **expire le 2027-07-01**. |
| **Impact** | À l'expiration → **le bouton « Se connecter avec un compte Microsoft » cesse de fonctionner** en production (échec OIDC). |
| **Cible** | App registration `Certigo MSA Login` (`df42c145`) + user flow `susi_certigo` (`7fdf12ed`) |

> **Pourquoi ce runbook ?** Ce secret joue **deux rôles** : (1) client secret de l'app `df42c145`
> **et** (2) valeur `clientSecret` configurée dans l'IdP OIDC « Microsoft account » du user flow de
> production. Il faut donc **faire tourner le secret des deux côtés de façon coordonnée**, sans
> coupure, puis **outiller une alerte** pour ne plus jamais être surpris par une expiration.

---

## Prérequis d'accès

| Prérequis | Détail |
|---|---|
| **Rôle app** | `Owner` de l'app `df42c145` **ou** `Application Administrator` du tenant CIAM |
| **Rôle External ID** | Droit de modifier les identity providers / user flows (`External ID User Flow Administrator` ou GA) |
| **Tenant cible** | `af721be8-5901-422a-b299-b9c57847b968` |
| **Permissions Graph** | `Application.ReadWrite.All`, `IdentityProvider.ReadWrite.All` |

## Ce que l'agent a préparé / ce que VOUS exécutez

- ✅ **Préparé par l'agent** : la séquence de rotation sans coupure (append → maj IdP → test → purge),
  le script d'alerte J-30, l'évaluation certificat.
- 👤 **Exécuté par vous** : la génération du nouveau secret, la mise à jour de l'IdP, le test de login,
  la suppression de l'ancien secret, le déploiement de l'alerte.

---

## Procédure de rotation (sans coupure de service)

### 1. Connexion au tenant CIAM

```bash
az login --tenant af721be8-5901-422a-b299-b9c57847b968 --allow-no-subscriptions
```

### 2. Inventaire de l'existant (identifier le secret courant)

```bash
az ad app credential list --id df42c145 \
  --query "[].{keyId:keyId, displayName:displayName, end:endDateTime}" -o table
```

> 📌 Notez le `keyId` du secret `certigo-ciam-oidc-2026-07` → il servira à le supprimer à l'étape 6
> (`<ANCIEN_KEY_ID>`).

### 3. Générer un **nouveau** secret (en `--append`, sans supprimer l'ancien)

```bash
az ad app credential reset \
  --id df42c145 \
  --display-name "certigo-ciam-oidc-2027-07" \
  --years 1 \
  --append
```

> ⚠️ `--append` est **essentiel** : sans lui, `az ad app credential reset` **supprime tous les
> secrets existants** et couperait la prod immédiatement. Avec `--append`, l'ancien et le nouveau
> coexistent le temps de la bascule.
>
> 📋 **Copiez immédiatement** la valeur `password` renvoyée (le `<NOUVEAU_SECRET>`) : elle **n'est
> affichée qu'une seule fois**.

### 4. Mettre à jour l'IdP « Microsoft account » avec le nouveau secret

L'IdP OIDC est configuré côté External ID. Deux voies :

**Voie A — Portail (recommandée pour fiabilité)** :
Centre d'administration Entra → **External Identities** → **All identity providers** →
ouvrir « Microsoft account » → remplacer le **Client secret** par `<NOUVEAU_SECRET>` → **Save**.

**Voie B — Microsoft Graph (`az rest`)** :

```bash
# 4a. Retrouver l'id de l'identity provider "Microsoft account"
az rest --url "https://graph.microsoft.com/beta/identity/identityProviders" -o json
# → repérer l'entrée MicrosoftAccount / OIDC liée a df42c145, noter son "id" (<IDP_ID>)

# 4b. Mettre a jour son clientSecret
az rest --method PATCH \
  --url "https://graph.microsoft.com/beta/identity/identityProviders/<IDP_ID>" \
  --headers "Content-Type=application/json" \
  --body '{"clientSecret": "<NOUVEAU_SECRET>"}'
```

> ℹ️ Selon la configuration exacte du flux (identity provider classique vs
> `authenticationEventsFlows`), le chemin Graph peut varier. **En cas de doute, utilisez la Voie A
> (portail)** qui met à jour le bon objet de façon sûre.

### 5. **Tester** le login Microsoft en production (avant de purger l'ancien secret)

1. Ouvrir le parcours de connexion prod (app `Certigo Mobile` / user flow `susi_certigo`).
2. Cliquer **« Se connecter avec un compte Microsoft »**.
3. Vérifier que l'authentification aboutit **sans erreur** (`invalid_client` = secret non pris en compte).

> 🚦 **Ne passez à l'étape 6 que si le test réussit.** Tant que l'ancien secret existe encore, un
> échec ne coupe rien : vous pouvez re-corriger l'IdP.

### 6. Supprimer l'ancien secret (une fois le nouveau validé)

```bash
az ad app credential delete --id df42c145 --key-id <ANCIEN_KEY_ID>
```

### 7. Vérification finale

```bash
az ad app credential list --id df42c145 \
  --query "[].{keyId:keyId, displayName:displayName, end:endDateTime}" -o table
# Attendu : un SEUL secret "certigo-ciam-oidc-2027-07", exp. ~ +1 an. L'ancien a disparu.
```

✅ **Critère de succès** : login Microsoft fonctionnel **et** un unique secret actif non expiré.

---

## Alerte d'expiration — ✅ automatisée (déployée le 2026-09-04)

> **Ce volet ne demande plus aucune action.** L'alerte, qui était auparavant fournie « à titre de
> modèle », est désormais **réellement déployée** dans ce dépôt.

### Dispositif déployé — workflow planifié `ciam-posture-monitor`

| Élément | Valeur |
|---|---|
| Workflow | [`.github/workflows/ciam-posture-monitor.yml`](../../.github/workflows/ciam-posture-monitor.yml) |
| Logique | [`.github/scripts/ciam-posture-report.mjs`](../../.github/scripts/ciam-posture-report.mjs) (couverte par `ciam-posture-report.test.mjs`) |
| Fréquence | Quotidienne (`cron: "23 6 * * *"`), plus `repository_dispatch: [ciam-posture]` |
| **Seuil d'alerte** | **90 jours** avant expiration (plus large que le J-30 initial : laisse le temps de planifier la rotation) |
| Effet | Écrit un résumé, **ouvre (ou commente) une issue GitHub**, puis **fait échouer le job** — et **referme l'issue** quand la posture redevient saine (voir « Le front descendant » ci-dessous) |
| Runner | `certigo-trusted` (aucun déclencheur PR ⇒ inatteignable par du code de fork) |

Le workflow couvre **tous** les secrets et certificats de **toutes** les app registrations du tenant
CIAM — donc les trois secrets du finding R-05, mais aussi tout secret créé plus tard, sans
maintenance de liste :

| App | Secret | Expiration |
|---|---|---|
| `Certigo MSA Login` (`df42c145`) | `certigo-ciam-oidc-2026-07` | 2027-07-01 |
| `Certigo Account Deletion Graph` (`0400e855`) | `Certigo account deletion prod` | 2027-08-19 |
| `Certigo Account Deletion Graph` (`0400e855`) | `Certigo account deletion staging` | 2027-08-19 |

### 🔑 Principe : **un moniteur qui partage le mode de défaillance de ce qu'il surveille n'est pas un moniteur**

Le modèle initialement proposé dans ce runbook reposait sur un service principal avec un **secret**
(`AZURE_CIAM_CREDENTIALS`). C'était un **raisonnement circulaire** :

> Le dispositif chargé de **détecter l'expiration des secrets** reposait lui-même sur **un secret qui
> expirerait**. À son expiration, le détecteur se serait tu — **silencieusement**, sans alerte, car
> plus rien ne le surveillait — et il se serait tu **au moment précis où il aurait été le plus
> utile**, c'est-à-dire quand des secrets approchent de leur fin de vie.

Une panne de ce type est particulièrement pernicieuse parce qu'elle est **silencieuse** : un
moniteur mort et un moniteur qui ne trouve rien à signaler produisent exactement le même résultat
observable — rien.

**Règle générale à retenir, au-delà de ce projet** : lorsqu'on outille une surveillance, vérifier
que le dispositif **ne partage aucun mode de défaillance avec son sujet**. Un moniteur de certificats
ne doit pas dépendre d'un certificat ; un moniteur de quota ne doit pas consommer le quota surveillé ;
un moniteur d'expiration ne doit pas détenir de credential qui expire. Et lorsque ce partage est
inévitable, le moniteur doit **échouer bruyamment** plutôt que silencieusement.

Le dispositif déployé applique cette règle de trois façons :

| Propriété | Mise en œuvre |
|---|---|
| **Aucun credential propre** | Federated identity credential GitHub OIDC — 0 secret, 0 certificat (vérifiable ci-dessous). Rien à faire tourner. |
| **Aucune liste à maintenir** | Interroge **toutes** les app registrations du tenant, pas une liste figée de trois. Un secret créé demain est couvert sans modification. |
| **Échec fermé** | Si Graph est illisible, le job **échoue** (`SECURITY_DEFAULTS_UNREADABLE`, `BREAK_GLASS_UNREADABLE`) au lieu de conclure à tort que tout va bien. |

### Identité du moniteur

| Élément | Valeur |
|---|---|
| App registration (tenant CIAM) | `certigo-ciam-posture-monitor` — `8856827e-4e91-4b14-9d4a-3ca4d9586f8e` |
| Credential | **Aucun secret ni certificat** — fédération OIDC uniquement |
| Issuer | `https://token.actions.githubusercontent.com` |
| Subject | `repo:gchambaud_microsoft/Certigo:environment:ciam-posture-monitor` |
| Audience | `api://AzureADTokenExchange` |
| Permissions Graph (application, **lecture seule**) | `Application.Read.All`, `Policy.Read.All`, `UserAuthenticationMethod.Read.All` |
| Environment GitHub | `ciam-posture-monitor` (vars `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `CIAM_BREAK_GLASS_UPN`) |

Vérifier à tout moment que le moniteur reste sans credential :

```bash
az rest --url "https://graph.microsoft.com/v1.0/applications(appId='8856827e-4e91-4b14-9d4a-3ca4d9586f8e')" \
  --query "{secrets: length(passwordCredentials), certs: length(keyCredentials)}" -o json
# Attendu : {"secrets": 0, "certs": 0}. Toute autre valeur signale une régression vers le modèle circulaire.
```

### Contrôles supplémentaires assurés par le même workflow

Le job ne se limite pas à l'expiration des secrets ; il garde aussi deux invariants de posture
confirmés le 2026-09-04 :

| Code | Contrôle |
|---|---|
| `CREDENTIAL_EXPIRING` / `CREDENTIAL_EXPIRED` | Un secret ou certificat approche (≤ 90 j) ou a dépassé son expiration → lancer ce runbook. |
| `SECURITY_DEFAULTS_DISABLED` | Les security defaults ont été désactivés : le MFA des administrateurs n'est plus imposé et rien ne l'a remplacé. |
| `BREAK_GLASS_NO_STRONG_METHOD` | Le compte break-glass n'a plus de méthode d'authentification forte (voir `R-04`). |
| `APPLICATION_LIST_EMPTY` | Graph a renvoyé **zéro** application — état non crédible pour un annuaire, donc traité comme une **lecture ratée**, jamais comme « aucun secret à signaler ». |

### 🔒 Garantie d'échec fermé — chemin de code vérifié

Un moniteur doit distinguer « rien à signaler » de « je n'ai pas réussi à regarder ». **Les deux
produisent exactement la même sortie visible** : rien. Voici les quatre chemins qui garantissent que
ce moniteur ne peut pas confondre les deux.

| Situation | Mécanisme | Résultat |
|---|---|---|
| **Erreur HTTP Graph** (401/403/5xx) | `requestJson()` lève une exception dès que `response.ok` est faux — le corps n'est jamais interprété | Job en **échec** |
| **Lecture des applications en échec** | L'appel n'est **pas** enveloppé dans un `try` : l'exception remonte à `main()`, puis au `.catch()` final qui pose `process.exitCode = 1` | Job en **échec** |
| **Security defaults / break-glass illisibles** | La variable reste `null` → `SECURITY_DEFAULTS_UNREADABLE` / `BREAK_GLASS_UNREADABLE`, sévérité `error` | Job en **échec** |
| **Liste d'applications vide** | `APPLICATION_LIST_EMPTY` — un annuaire contient toujours au moins une application ; zéro signale une permission réduite, une réponse filtrée ou le mauvais tenant | Job en **échec** |

> ⚠️ **La règle générale : une commande qui a ÉCHOUÉ peut s'afficher comme une VALEUR.**
> Un résultat vide n'est une mesure que si l'on a vérifié le code de sortie. C'est exactement ainsi
> qu'un `az storage blob list` refusé par une règle réseau s'est affiché « 0 blob » ailleurs dans ce
> projet, et a été propagé comme un fait. Le tableau ci-dessus existe pour que ce moniteur ne puisse
> pas commettre la même erreur.

**Pagination.** Graph pagine ses collections. Ne lire que la première page laisserait des
credentials **non examinés tout en rapportant un succès** — la même classe de bug. `requestAllPages()`
suit chaque `@odata.nextLink`, propage toute erreur survenue en cours de parcours au lieu de renvoyer
une liste partielle, refuse une réponse sans collection `value`, et s'arrête au-delà de 100 pages
pour ne pas boucler indéfiniment sur un lien auto-référentiel.

Ces quatre chemins sont **couverts par des tests** dans
`.github/scripts/ciam-posture-report.test.mjs` (23 tests), dont un qui vérifie explicitement qu'une
liste vide **échoue** au lieu de passer pour « aucun secret expirant ».

### Le front descendant — comment le moniteur sait dire « c'est réglé »

Jusqu'au 2026-09-07, ce moniteur savait **ouvrir** son issue de suivi et jamais la refermer. Son
état convergeait donc vers « cassé » et y restait, quelle que soit la réalité du tenant : un
instrument dont la sortie finit par ne plus dépendre de son entrée. La conséquence pratique est
qu'une alerte réelle suivante se serait fondue dans un ticket déjà ouvert et cessé d'être lu.

La fermeture automatique introduit le **risque inverse**, plus grave : annoncer « résolu » parce que
l'audit n'a pas su regarder. La condition de fermeture est donc choisie pour l'exclure :

| Situation | `steps.audit.outcome` | `steps.audit.outputs.failed` | Effet |
|---|---|---|---|
| Audit conclu, finding de sévérité `error` | `failure` | `true` | Ouvre / commente, échoue |
| Audit conclu, aucun finding `error` | `success` | `false` | **Ferme** l'issue |
| Audit **planté** (config, token, Graph) | `failure` | *(non écrite)* | Ouvre / commente, échoue |

Le script n'écrit `failed` **qu'après avoir atteint son verdict**. Un `false` est donc une
**affirmation positive de santé**, alors que `outcome == 'success'` ne serait que l'absence d'erreur
constatée — et un refactor qui avalerait une exception transformerait ce silence en feu vert. Les
deux signaux sont exigés conjointement ; s'ils divergeaient un jour, rien n'est fermé. Une issue
laissée ouverte à tort se rattrape, un moniteur qui se tait à tort ne se rattrape pas.

Trois tests verrouillent ce raisonnement : un audit sain publie bien `failed=false` (sans quoi la
porte ne s'ouvrirait jamais), un audit planté ne publie **rien** (vérifié en le faisant échouer pour
de bon, sortie `GITHUB_OUTPUT` restée vide), et le texte du workflow est comparé au marqueur exact
de la condition — avec un contrôle positif sur la condition d'ouverture, pour qu'une absence de
correspondance signifie une porte absente et non un fichier illisible.

### Dispositif complémentaire — owner de l'app avec e-mail

Entra envoie aussi des e-mails d'expiration **aux owners de l'application**. C'est un filet
secondaire, indépendant de GitHub Actions :

```bash
# Lister les owners actuels
az ad app owner list --id df42c145 --query "[].{upn:userPrincipalName, id:id}" -o table

# Ajouter un owner (objectId d'un utilisateur avec e-mail surveillé)
az ad app owner add --id df42c145 --owner-object-id <OWNER_OBJECT_ID>
```

---

## Évaluation : passage à un **certificat** ?

| Question | Réponse |
|---|---|
| L'IdP OIDC External ID accepte-t-il un certificat (`private_key_jwt` / `client_assertion`) ? | ❌ **Non.** Le champ IdP « Microsoft account » attend un **`clientSecret` (chaîne)**. Un certificat ne peut pas y être injecté. |
| Peut-on mettre un certificat sur l'app `df42c145` elle-même ? | Techniquement oui pour l'app, mais **l'IdP du user flow ne l'utiliserait pas** → sans effet sur le finding. |
| **Recommandation** | **Conserver le client secret**, avec **rotation annuelle outillée** (ce runbook) + **alerte J-30**. Réévaluer le certificat **uniquement si** l'IdP est un jour remplacé par une fédération supportant `client_assertion`. |

---

## Rollback

- **Pendant la rotation** : tant que l'ancien secret n'est pas supprimé (étapes 3→5), en cas d'échec
  du test, **remettre l'ancien secret** dans l'IdP (Voie A/B) — aucune coupure.
- **Après suppression accidentelle du bon secret** : `az ad app credential reset --id df42c145
  --append` pour en générer un nouveau, puis mettre à jour l'IdP (étape 4). ⚠️ Un secret **supprimé
  n'est pas récupérable** : il faut en régénérer un et re-propager côté IdP.

---

## Notes & considérations

- Le nommage `certigo-ciam-oidc-<AAAA-MM>` (mois d'expiration) rend l'échéance lisible d'un coup d'œil
  dans `az ad app credential list`.
- Ancrez la rotation dans le calendrier ops à **échéance − 30 jours** (l'alerte J-30 sert de filet).
- Après rotation, mettez à jour toute documentation interne référençant `certigo-ciam-oidc-2026-07`.
- L'audit confirme qu'**aucun** autre secret du tenant n'expire à < 90 jours : R-05 est le seul secret
  à échéance rapprochée côté prod. Les secrets des apps QuickStart (2028) seront de toute façon
  supprimés par le runbook **O-05**.
