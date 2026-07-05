# O-05 — Nettoyage sûr du tenant CIAM (résidus QuickStart)

| Champ | Valeur |
|---|---|
| **Finding** | O-05 (🟠 Moyen) |
| **Constat audit** | Le tenant CIAM contient des **résidus de tutoriels QuickStart** : 3 app registrations de test, 2 user flows de test, et une **subscription vide**. |
| **Impact** | Surface d'attaque et confusion inutiles (redirects `jwt.ms`/localhost, apps non utilisées). Pas de risque prod **si** la suppression est ciblée avec précaution. |
| **Cible** | Tenant CIAM `af721be8-5901-422a-b299-b9c57847b968` + subscription vide `906c6a44…` |

> **Pourquoi ce runbook ?** Nettoyer réduit la surface d'attaque, mais une suppression **mal ciblée**
> pourrait détruire une ressource de prod. Ce runbook impose des **vérifications préalables
> obligatoires** (garde-fous) avant toute suppression, et privilégie des opérations **réversibles**
> (corbeille 30 j pour les apps, annulation réversible 90 j pour la subscription).

---

## ⛔ Ressources de PRODUCTION à NE JAMAIS toucher

Avant toute action, gravez cette liste. **Aucune** de ces ressources ne doit être supprimée :

| Type | Nom | appId / id |
|---|---|---|
| App | **Certigo Mobile** | `4d1f1075` |
| App | **Certigo API** | `12910b8e` |
| App | **Certigo MSA Login** | `df42c145` |
| App | **b2c-extensions-app** (système) | `77216304` |
| User flow | **susi_certigo** | `7fdf12ed` |

## ✅ Ressources à SUPPRIMER (résidus QuickStart)

| Type | Identifiant | Indice de reconnaissance |
|---|---|---|
| App | `35bb7bbc` | redirects `jwt.ms` / `localhost`, secret exp. 2028-06-30 |
| App | `49957408` | redirects QuickStart, secret exp. 2028-07-01 |
| App | `5f371968` | redirects QuickStart, secret exp. 2028-07-01 |
| User flow (x2) | QuickStart (liés à `35bb7bbc` et `5f371968`) | Email+password seul, **≠ susi_certigo** |
| Subscription | `906c6a44…` | « Azure subscription 1 », **vide** |

---

## Prérequis d'accès

| Prérequis | Détail |
|---|---|
| **Rôle apps/flows** | `Application Administrator` ou `Global Administrator` du tenant CIAM |
| **Rôle subscription** | `Owner` de la subscription `906c6a44…` (pour l'annulation billing) |
| **Tenant cible** | `af721be8-5901-422a-b299-b9c57847b968` |
| **Permissions Graph** | `Application.ReadWrite.All`, `IdentityUserFlow.ReadWrite.All` |

## Ce que l'agent a préparé / ce que VOUS exécutez

- ✅ **Préparé par l'agent** : les vérifications préalables, l'ordre de suppression sûr, les rollbacks.
- 👤 **Exécuté par vous** : la confirmation visuelle de **chaque** appId avant suppression, puis les
  suppressions.

---

## Étape 0 — Garde-fous : vérifications préalables OBLIGATOIRES

> 🚨 **Ne supprimez rien tant que l'étape 0 n'est pas 100 % concluante.**

```bash
az login --tenant af721be8-5901-422a-b299-b9c57847b968 --allow-no-subscriptions

# 0a. Inventaire complet des apps : confirmer les appId + redirects avant toute action
az ad app list --all \
  --query "[].{name:displayName, appId:appId, web:web.redirectUris, spa:spa.redirectUris}" -o json
```

**Checklist manuelle (à cocher avant de continuer) :**

- [ ] Les 3 apps à supprimer (`35bb7bbc`, `49957408`, `5f371968`) ont bien des redirects
      `jwt.ms`/`localhost` (signature QuickStart).
- [ ] **Aucune** des 3 n'est `4d1f1075`, `12910b8e`, `df42c145`, `77216304`.
- [ ] Les user flows à supprimer sont bien les 2 QuickStart (Email+password seul) et **PAS**
      `susi_certigo` (`7fdf12ed`).

```bash
# 0b. Lister les user flows (API beta) pour identifier les QuickStart vs susi_certigo
az rest --url "https://graph.microsoft.com/beta/identity/authenticationEventsFlows" \
  --query "value[].{id:id, name:displayName}" -o table
# → repérer les 2 flux QuickStart, noter leurs id (<FLOW_ID_1>, <FLOW_ID_2>).
#   susi_certigo NE DOIT PAS figurer dans la liste à supprimer.

# 0c. Confirmer que la subscription cible est bien VIDE
az account subscription show --id 906c6a44-... -o json    # noter displayName = "Azure subscription 1"
az resource list --subscription 906c6a44-... -o table     # doit renvoyer une liste VIDE
```

- [ ] La subscription `906c6a44…` ne contient **aucune** ressource.

---

## Étape 1 — Supprimer les 3 app registrations QuickStart

Répétez pour chaque appId **après** l'avoir confirmé à l'étape 0.

```bash
az ad app delete --id 35bb7bbc
az ad app delete --id 49957408
az ad app delete --id 5f371968
```

> ♻️ Les apps supprimées vont dans la **corbeille Entra pendant 30 jours** → restaurables (voir Rollback).

## Étape 2 — Supprimer les 2 user flows QuickStart

```bash
az rest --method DELETE --url "https://graph.microsoft.com/beta/identity/authenticationEventsFlows/<FLOW_ID_1>"
az rest --method DELETE --url "https://graph.microsoft.com/beta/identity/authenticationEventsFlows/<FLOW_ID_2>"
```

> ⚠️ Vérifiez **une dernière fois** que `<FLOW_ID_1/2>` **≠** l'id de `susi_certigo` avant d'exécuter.

## Étape 3 — Annuler la subscription vide

```bash
az account subscription cancel --id 906c6a44-...
```

> ♻️ L'annulation est **réversible pendant 90 jours** (réactivation possible via le portail billing).

---

## Vérification post-nettoyage

```bash
# 1) Les 3 apps QuickStart ont disparu de la liste active
az ad app list --all --query "[].appId" -o tsv | grep -E "35bb7bbc|49957408|5f371968"
# Attendu : AUCUN résultat.

# 2) Les 5 ressources PROD sont TOUJOURS présentes
az ad app list --all --query "[?appId=='4d1f1075' || appId=='12910b8e' || appId=='df42c145' || appId=='77216304'].{name:displayName, appId:appId}" -o table
# Attendu : les 4 apps prod listées.

# 3) susi_certigo intact
az rest --url "https://graph.microsoft.com/beta/identity/authenticationEventsFlows" --query "value[?displayName=='susi_certigo']" -o json
# Attendu : susi_certigo présent.
```

4. **Test fonctionnel prod** (décisif) : lancer le parcours de connexion `susi_certigo` (Email+password,
   Google, Microsoft, Apple) et vérifier qu'il fonctionne toujours.

✅ **Critère de succès** : les 3 apps + 2 flux + subscription supprimés, **et** les 5 ressources prod
intactes **et** login `susi_certigo` fonctionnel.

---

## Rollback

```bash
# Apps : lister la corbeille (30 j) puis restaurer
az rest --url "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.application" -o table
az rest --method POST --url "https://graph.microsoft.com/v1.0/directory/deletedItems/<DELETED_APP_ID>/restore"

# User flows : PAS de corbeille → recréer manuellement si suppression par erreur (d'où l'importance de l'étape 0).

# Subscription : réactivation via le portail billing dans les 90 jours.
```

---

## Notes & considérations

- **Ordre voulu** : apps → user flows → subscription. Les user flows peuvent référencer les apps ;
  supprimer d'abord les apps est sans risque ici car les flux QuickStart sont eux-mêmes destinés à
  disparaître.
- La suppression des apps QuickStart **règle aussi** leurs secrets 2028 → plus besoin de les surveiller.
- Si un doute subsiste sur un identifiant à l'étape 0, **ne supprimez pas** et demandez confirmation :
  le coût d'une app résiduelle est faible, celui d'une suppression prod est élevé.
- Ce nettoyage n'a **aucun** impact sur la facturation MAU (les résidus QuickStart ne comptent pas
  d'utilisateurs actifs prod).
