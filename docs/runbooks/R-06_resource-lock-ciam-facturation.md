# R-06 — Resource lock `CanNotDelete` sur la facturation CIAM

| Champ | Valeur |
|---|---|
| **Finding** | R-06 (🔴 Haut) |
| **Constat audit** | La ressource `Microsoft.AzureActiveDirectory/ciamDirectories` n'a **aucun resource lock**. |
| **Impact** | Suppression accidentelle → **coupure de l'authentification de production** (aucun garde-fou). |
| **Cible** | RG `rg-certigo-identity`, subscription `f434ec55-f342-4948-9298-f99af5216204` |

> **Pourquoi ce runbook ?** La ressource `ciamDirectories` est le point de facturation **et** de
> rattachement Azure du tenant CIAM qui authentifie la prod. Il n'existe qu'**un seul Owner**
> (`gabriel.chambaud@gmail.com`). Un `az resource delete` ou un clic malheureux dans le portail
> supprimerait le garde-fou de facturation sans aucune confirmation renforcée. Un lock
> `CanNotDelete` bloque toute suppression tant que le lock n'est pas explicitement retiré.

---

## Prérequis d'accès

| Prérequis | Détail |
|---|---|
| **Rôle Azure** | `Owner` **ou** `User Access Administrator` sur la subscription `f434ec55…` ou le RG `rg-certigo-identity` |
| **Subscription cible** | `f434ec55-f342-4948-9298-f99af5216204` (Visual Studio) |
| **Outil** | Azure CLI ≥ 2.60 |

## Ce que l'agent a préparé / ce que VOUS exécutez

- ✅ **Préparé par l'agent** : les commandes `az` exactes (récupération du nom, création du lock,
  vérification, rollback) et les garde-fous.
- 👤 **Exécuté par vous** : `az login`, la sélection de subscription, puis les commandes ci-dessous.

---

## Procédure pas-à-pas

### 1. Connexion et sélection de la subscription de facturation

```bash
az login
az account set --subscription f434ec55-f342-4948-9298-f99af5216204
az account show --query "{sub:name, id:id}" -o table
```

### 2. Récupérer le **nom exact** de la ressource `ciamDirectories`

Le nom de la ressource n'est pas figé dans l'audit ; il faut le lire dynamiquement.

```bash
az resource list \
  --resource-group rg-certigo-identity \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories \
  --query "[].{name:name, id:id, location:location}" -o table
```

> 📌 Notez la valeur de la colonne `name` → elle remplace `<NOM_CIAM>` ci-dessous.
> Si la commande ne renvoie rien, vérifiez la subscription active (étape 1) : la ressource
> `ciamDirectories` peut n'apparaître que sous la subscription de facturation.

### 3. Créer le lock `CanNotDelete` sur la ressource

```bash
az lock create \
  --name lock-ciam-nodelete \
  --lock-type CanNotDelete \
  --resource-group rg-certigo-identity \
  --resource-name "<NOM_CIAM>" \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories \
  --notes "R-06 audit : protege la facturation/auth CIAM prod contre suppression accidentelle. Retrait uniquement sur decision explicite."
```

### 3-bis. (Option renforcée recommandée) Verrouiller aussi le **resource group**

Un lock au niveau RG protège la ressource **et** empêche la suppression du groupe entier. Recommandé
car `rg-certigo-identity` ne contient que cette ressource critique.

```bash
az lock create \
  --name lock-rg-certigo-identity-nodelete \
  --lock-type CanNotDelete \
  --resource-group rg-certigo-identity \
  --notes "R-06 audit : protege le RG de facturation CIAM. Les locks RG s'appliquent par heritage a toutes les ressources du groupe."
```

> ℹ️ Les deux locks peuvent coexister. Le lock RG est le plus robuste ; le lock ressource est plus
> ciblé. En cas de doute, appliquez **au minimum** le lock ressource (étape 3).

---

## Vérification

```bash
# Lister tous les locks du RG (doit afficher lock-ciam-nodelete et/ou lock-rg-...)
az lock list --resource-group rg-certigo-identity -o table

# Vérifier précisément le lock ressource
az lock show \
  --name lock-ciam-nodelete \
  --resource-group rg-certigo-identity \
  --resource-name "<NOM_CIAM>" \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories \
  --query "{name:name, level:level, notes:notes}" -o table
```

**Test négatif (facultatif, sans risque)** — tenter une suppression à blanc doit échouer :

```bash
# Doit renvoyer une erreur "locked" : NE PAS confirmer si un prompt apparaît.
az resource delete \
  --resource-group rg-certigo-identity \
  --name "<NOM_CIAM>" \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories
# Résultat attendu : ScopeLocked / "the scope ... is locked".
```

✅ **Critère de succès** : `az lock list` affiche le lock avec `level = CanNotDelete`, et la tentative
de suppression est refusée avec une erreur de type `ScopeLocked`.

---

## Rollback (retrait volontaire du lock)

À n'exécuter **que** si une opération de maintenance planifiée exige de retirer le garde-fou.
**Reposer le lock immédiatement après.**

```bash
# Retrait du lock ressource
az lock delete \
  --name lock-ciam-nodelete \
  --resource-group rg-certigo-identity \
  --resource-name "<NOM_CIAM>" \
  --resource-type Microsoft.AzureActiveDirectory/ciamDirectories

# (si posé) Retrait du lock RG
az lock delete --name lock-rg-certigo-identity-nodelete --resource-group rg-certigo-identity
```

---

## Notes & considérations

- Un lock `CanNotDelete` **n'empêche pas** la lecture ni la modification ; il bloque uniquement la
  suppression. Il n'a **aucun impact** sur la facturation MAU ni sur l'authentification.
- La création/suppression de locks requiert `Microsoft.Authorization/locks/*` → couvert par `Owner`
  et `User Access Administrator`, **pas** par `Contributor` (qui ne peut pas gérer les locks).
- Après R-04 (break-glass), envisager d'accorder le rôle nécessaire au compte break-glass pour qu'il
  puisse aussi gérer ce lock en cas d'urgence.
- **Idempotence** : relancer `az lock create` avec le même nom mettra à jour le lock sans erreur
  bloquante ; la commande est sûre à rejouer.
