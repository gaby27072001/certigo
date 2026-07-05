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

| Recommandation | Détail |
|---|---|
| **Exclure des futures policies CA** | Le tenant a actuellement **0 policy Conditional Access** (audité). Dès qu'une policy sera créée, **exclure le compte break-glass** pour éviter tout lock-out par une règle mal configurée. |
| **MFA distinct et résilient** | Idéalement une **clé FIDO2** dédiée (stockée avec le secret), **différente** du MFA du compte gmail — pour ne pas partager un facteur avec le compte à risque. |
| **Security defaults** | L'état des *security defaults* n'a pas pu être confirmé lors de l'audit (endpoint `Forbidden` avec le compte délégué). Une fois connecté avec un GA **natif**, vérifiez : `az rest --url "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy"`. Si activés **et** qu'aucun CA n'existe, le compte break-glass devra satisfaire le MFA des security defaults → enregistrer sa méthode MFA à l'avance. |
| **Surveillance** | Créer une alerte sur toute connexion du compte break-glass (usage = exceptionnel). |

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
