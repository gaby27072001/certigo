# R-04 — Compte break-glass CIAM (Global Admin cloud-only, non fédéré)

| Champ | Valeur |
|---|---|
| **Finding** | R-04 (🔴 Haut) |
| **Constat audit** | Le tenant CIAM n'a **qu'un seul Global Admin** : `gabriel.chambaud_gmail.com#EXT#` (compte MSA gmail **externe fédéré**). **Aucun compte break-glass.** |
| **Impact** | Si le compte gmail est perdu, compromis, ou si la fédération MSA échoue → **plus aucun accès administrateur** au tenant CIAM (perte de contrôle de l'authentification prod). |
| **Cible** | Tenant CIAM `af721be8-5901-422a-b299-b9c57847b968` |

> **Pourquoi ce runbook ?** Un compte break-glass (« bris de glace ») est un compte
> **cloud-only, natif du tenant**, indépendant de toute fédération externe, réservé aux urgences.
> Ici le **seul** administrateur dépend d'un MSA gmail fédéré : une panne de fédération, une
> suppression du compte Microsoft, ou une compromission gmail verrouillerait toute administration.
> Ce runbook crée un GA natif `…@certigoapp.onmicrosoft.com` qui ne dépend d'aucun IdP externe.

---

## Prérequis d'accès

| Prérequis | Détail |
|---|---|
| **Rôle** | `Global Administrator` du tenant CIAM (le compte gmail actuel) |
| **Tenant cible** | `af721be8-5901-422a-b299-b9c57847b968` |
| **Permissions Graph** | `User.ReadWrite.All` + `RoleManagement.ReadWrite.Directory` (couvertes par le rôle GA via `az rest`) |
| **Coffre secret** | Un gestionnaire de secrets **hors tenant CIAM** (coffre physique, gestionnaire d'entreprise, ou Key Vault d'une autre subscription) |

## Ce que l'agent a préparé / ce que VOUS exécutez

- ✅ **Préparé par l'agent** : la procédure de création du compte, l'attribution du rôle GA,
  la fiche d'urgence, les recommandations d'exclusion Conditional Access/MFA.
- 👤 **Exécuté par vous** : génération du mot de passe, création de l'utilisateur, attribution du
  rôle, stockage sécurisé du secret, test de connexion.

---

## Procédure pas-à-pas

### 1. Connexion au tenant CIAM

```bash
az login --tenant af721be8-5901-422a-b299-b9c57847b968 --allow-no-subscriptions
az rest --url "https://graph.microsoft.com/v1.0/organization?\$select=id,displayName" -o json
```

> `--allow-no-subscriptions` est requis : le tenant CIAM n'a pas de subscription Azure liée directement.

### 2. Générer un mot de passe fort (≥ 24 caractères, aléatoire)

```bash
# Linux/macOS
openssl rand -base64 30

# Windows PowerShell
[Convert]::ToBase64String((1..30 | % {Get-Random -Max 256}))
```

> 🔐 **Ne collez ce mot de passe nulle part en clair.** Vous l'enregistrerez à l'étape 5 dans le
> coffre hors-ligne. Conservez-le temporairement uniquement le temps de la création.

### 3. Créer l'utilisateur break-glass (cloud-only, natif)

Remplacez `<MOT_DE_PASSE>` par la valeur générée à l'étape 2.

```bash
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/users" \
  --headers "Content-Type=application/json" \
  --body '{
    "accountEnabled": true,
    "displayName": "Break Glass CIAM (urgence)",
    "mailNickname": "breakglass",
    "userPrincipalName": "breakglass@certigoapp.onmicrosoft.com",
    "passwordPolicies": "DisablePasswordExpiration",
    "passwordProfile": {
      "password": "<MOT_DE_PASSE>",
      "forceChangePasswordNextSignIn": false
    }
  }'
```

> 📌 Récupérez l'`id` (objectId) renvoyé → il remplace `<USER_OBJECT_ID>` ci-dessous.
> `DisablePasswordExpiration` évite qu'une expiration silencieuse ne rende le compte inutilisable
> au pire moment. `forceChangePasswordNextSignIn=false` évite un blocage lors du premier login d'urgence.

### 4. Attribuer le rôle **Global Administrator**

Le `roleDefinitionId` de Global Administrator est un GUID **fixe et universel** :
`62e90394-69f5-4237-9190-012177145e10`.

```bash
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
  --headers "Content-Type=application/json" \
  --body '{
    "principalId": "<USER_OBJECT_ID>",
    "roleDefinitionId": "62e90394-69f5-4237-9190-012177145e10",
    "directoryScopeId": "/"
  }'
```

### 5. Stocker le secret de façon sécurisée (hors tenant CIAM)

Enregistrez dans votre **coffre hors-ligne** (⚠️ pas dans un Key Vault du tenant CIAM lui-même — il
deviendrait inaccessible en cas de perte d'accès admin) :

| À conserver | Valeur |
|---|---|
| UPN | `breakglass@certigoapp.onmicrosoft.com` |
| objectId | `<USER_OBJECT_ID>` |
| Mot de passe | `<MOT_DE_PASSE>` |
| Date de création | (à noter) |
| Tenant | `af721be8-5901-422a-b299-b9c57847b968` |

---

## Fiche procédure d'urgence (à archiver avec le secret)

1. **Quand l'utiliser** : perte d'accès du GA gmail, panne de fédération MSA, compromission suspectée
   du compte principal, ou toute situation d'exclusion administrative.
2. **Comment se connecter** : `https://login.microsoftonline.com/` (ou portail External ID) avec
   l'UPN `breakglass@certigoapp.onmicrosoft.com` et le mot de passe du coffre.
3. **Journalisation** : toute utilisation doit être **tracée** (qui, quand, pourquoi) et suivie d'une
   **rotation du mot de passe** (regénérer via `az rest PATCH /users/<id>` avec un nouveau
   `passwordProfile`) une fois l'incident clos.
4. **Après usage** : reposer le mot de passe dans le coffre, vérifier les journaux de connexion
   (`az rest GET /auditLogs/signIns`).

---

## Vérification

```bash
# 1) Le compte existe et est actif
az rest --url "https://graph.microsoft.com/v1.0/users/breakglass@certigoapp.onmicrosoft.com?\$select=id,userPrincipalName,accountEnabled,userType" -o json
# Attendu : accountEnabled=true, userType="Member" (cloud-only, non #EXT#)

# 2) Lister les titulaires du rôle Global Administrator (doit contenir 2 principals : gmail + breakglass)
az rest --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=roleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'&\$expand=principal" -o json
```

3. **Test de connexion réel** (obligatoire) : ouvrez une **fenêtre de navigation privée**, connectez-vous
   avec le compte break-glass, vérifiez l'accès au centre d'administration. **C'est le seul moyen de
   garantir que le compte fonctionne le jour J.**

✅ **Critère de succès** : `userType = Member` (non fédéré), rôle GA confirmé pour 2 principals, et
connexion interactive réussie.

---

## Exclusions Conditional Access / MFA

> ⚠️ **Section mise à jour le 2026-09-04** — l'état des security defaults, auparavant inconnu, a été
> **mesuré**. Les conclusions ci-dessous remplacent les recommandations conditionnelles précédentes.

| Recommandation | Détail |
|---|---|
| **Security defaults** | ✅ **ACTIVÉS — confirmé le 2026-09-04.** `GET /policies/identitySecurityDefaultsEnforcementPolicy` renvoie `"isEnabled": true`. L'audit de juillet n'avait pas pu le lire (`Forbidden` avec un jeton délégué, qui ne porte pas `Policy.Read.All`) ; la lecture a été obtenue via un **jeton applicatif** dédié. |
| **MFA des administrateurs** | ✅ **Déjà imposé** par les security defaults, qui exigent le MFA pour le rôle Global Administrator. Le finding `CIAM-2` est donc **couvert** — voir l'encadré ci-dessous. |
| **Ne PAS créer de policy Conditional Access** | ❌ Security defaults et Conditional Access sont **mutuellement exclusifs** : créer une policy CA obligerait à **désactiver** les security defaults, ce qui ferait perdre le blocage de l'authentification héritée, le blocage du device code flow et l'inscription MFA généralisée. Ce serait une **régression nette**. |
| **✅ MFA du compte break-glass — écart clos le 2026-09-07** | Microsoft Authenticator enregistré sur le compte. L'écart, ouvert depuis le 2026-09-04, est refermé. Voir l'encadré ci-dessous : la procédure qui a fonctionné n'est **pas** celle que ce runbook prescrivait. |
| **Surveillance** | ✅ **Automatisée** : `.github/workflows/ciam-posture-monitor.yml` vérifie chaque jour que les security defaults restent activés et que le compte break-glass conserve une méthode forte. |

### ✅ Écart clos le 2026-09-07 — et la procédure prescrite ne marchait pas

La note conditionnelle de la version précédente de ce runbook (« *si les security defaults sont
activés et qu'aucun CA n'existe, le compte break-glass devra satisfaire le MFA → enregistrer sa
méthode MFA à l'avance* ») s'est **vérifiée**. Les trois conditions étaient réunies au 2026-09-04 :

1. Security defaults **activés** (`isEnabled: true`) ;
2. **0 policy Conditional Access** dans le tenant — donc **aucune exclusion possible**, les security
   defaults n'en supportant pas ;
3. Compte break-glass avec **une seule** méthode : `#microsoft.graph.passwordAuthenticationMethod`.

**Conséquence** : le compte de secours aurait dû **inscrire un MFA dans l'urgence**, au moment même
où il est censé débloquer la situation.

**Remédiation appliquée le 2026-09-07** : **Microsoft Authenticator** enregistré sur le compte.

> ⚠️ **Le bootstrap par Temporary Access Pass décrit ailleurs dans cette documentation n'est pas
> praticable dans ce tenant.** La policy de méthodes affiche « Droit d'accès temporaire : Oui, tous
> les utilisateurs », mais le menu **Ajouter une méthode d'authentification** de la fiche
> utilisateur ne propose que **E-mail / Numéro de téléphone / Code QR** — le TAP en est absent
> (constaté le 2026-09-07). Une capacité **déclarée** dans la policy n'est pas une capacité
> **exposée** par la surface d'administration : ce tenant est un tenant externe (CIAM), dont
> l'interface d'administration est réduite. Ne pas remettre la procédure TAP en se fiant à la policy.

**Voie qui a fonctionné, et qui ne dépend d'aucune surface d'administration** :

1. Se connecter à `https://login.microsoftonline.com` avec `breakglass@certigoapp.onmicrosoft.com`
   et le mot de passe du coffre, dans une fenêtre **distincte** de la session administrateur.
2. Les security defaults déclenchent d'eux-mêmes l'écran **« Informations supplémentaires
   requises »**, qui conduit à l'inscription de la méthode. C'est l'exigence MFA elle-même qui
   ouvre la porte — aucun facteur préexistant, aucun TAP, aucun écran d'administration.
3. Si l'interruption n'apparaît pas, aller directement sur
   `https://mysignins.microsoft.com/security-info` → **Ajouter une méthode**.

**Vérification — ne pas se fier à l'absence d'erreur.** `GET /users/<id>/authentication/methods`
renvoie `403` avec un jeton `az` délégué (portée `UserAuthenticationMethod.Read.All` absente), et ce
`403` se lit à tort comme « aucune méthode ». Le contrôle qui tranche est
`.github/workflows/ciam-posture-monitor.yml`, déclenchable à la demande :

```bash
gh api -X POST repos/gchambaud_microsoft/Certigo/dispatches -f event_type=ciam-posture
```

Comparer alors **deux** runs, avant et après : celui du 2026-09-07 12:47 UTC portait
`BREAK_GLASS_NO_STRONG_METHOD` et sortait en `exit 1` ; celui de 16:00 UTC, après remédiation,
ne rapportait aucun finding. Un vert seul ne prouve rien — il faut avoir lu le journal du rouge
précédent pour établir que l'échec venait du **constat** et non d'une panne de l'instrument.

> **Ce fait redevient faux si** la méthode forte est retirée du compte, ou si les security defaults
> sont désactivés. Le monitor ci-dessus vérifie les deux quotidiennement. En revanche il **n'a pas
> d'étape de fermeture** : il sait ouvrir l'issue de suivi, jamais la refermer quand la posture
> redevient saine (`if: steps.audit.outcome == 'failure'`). Après toute remédiation future, refermer
> l'issue à la main en citant les deux runs — sinon la prochaine alerte réelle se fondra dans un
> ticket déjà ouvert et cessé d'être lu.

L'action reste **délibérément laissée à l'humain** : établir un credential sur un compte d'urgence
exige une décision explicite et la possession du facteur.

### Si Conditional Access devenait un jour la bonne réponse

CA **est** disponible dans un tenant externe, mais avec des limites : les affectations se réduisent à
« inclure tous les utilisateurs, exclure des utilisateurs/groupes » — **on ne peut pas cibler un
rôle d'annuaire**. CA ne deviendrait préférable que si l'on avait besoin de granularité impossible
avec les security defaults, par exemple des exclusions par emplacement nommé, ou justement une
**exclusion du compte break-glass**. Dans ce cas il faudrait, **dans cet ordre** : créer la policy CA
en mode *report-only* avec l'exclusion break-glass, vérifier son évaluation, l'activer, **puis
seulement** désactiver les security defaults.

---

## Rollback

```bash
# Désactiver (réversible) plutôt que supprimer, en cas de création par erreur
az rest --method PATCH \
  --url "https://graph.microsoft.com/v1.0/users/<USER_OBJECT_ID>" \
  --headers "Content-Type=application/json" \
  --body '{"accountEnabled": false}'

# Retirer l'attribution de rôle (récupérer d'abord l'id de l'assignment via la requête de vérification #2)
az rest --method DELETE \
  --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments/<ROLE_ASSIGNMENT_ID>"
```

---

## Notes & considérations

- **Best practice = 2 comptes break-glass.** Le brief demande **1** compte → ce runbook en crée **1**.
  **Recommandation** : dupliquer la procédure pour un second compte (`breakglass2@…`) stocké dans un
  **autre** coffre / lieu, afin de couvrir la perte d'un des deux secrets. Microsoft recommande 2
  comptes break-glass distincts.
- Le compte est **`Member` cloud-only** : il ne dépend d'**aucun** IdP externe (contrairement au GA
  gmail `#EXT#`), ce qui est précisément l'objectif de résilience.
- Ne **jamais** utiliser ce compte pour des tâches quotidiennes : son usage doit rester **exceptionnel
  et tracé**, sinon il perd sa valeur de dernier recours.
- Le mot de passe long + `DisablePasswordExpiration` est un choix délibéré (recommandation Microsoft
  pour break-glass) : la robustesse vient de la longueur et du stockage hors-ligne, pas de la rotation
  forcée périodique.
