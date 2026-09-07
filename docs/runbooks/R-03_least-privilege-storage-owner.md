# R-03 — Rétrogradation Storage Blob Data Owner → Contributor (identités Function App)

| Champ | Valeur |
|---|---|
| **Finding** | R-03 (🟡 Faible) |
| **Constat audit** | Les 2 identités managées du backend (`id-func-certigo-dev-...-host`, `id-func-certigo-prod-...-host`) ont le rôle **Storage Blob Data *Owner*** sur leur compte de stockage respectif, alors que **Contributor** — déjà assigné en parallèle — suffit pour tout le chemin d'écriture applicatif (déploiement du paquet FC1). Owner est donc strictement redondant. |
| **Impact** | Rayon d'action élevé d'une identité compromise (Owner permet en plus la gestion des ACL POSIX / permissions du compte, que Contributor n'autorise pas). |
| **Cible** | Les 2 attributions de rôle **Owner** ci-dessous, sur les comptes de stockage `dev` et `prod`. **Contributor n'est jamais touché.** |

> **Pourquoi ce runbook ?** L'IaC a déjà été corrigé (PR #368 : la ressource Bicep qui créait
> l'attribution Owner a été retirée). Mais les déploiements Certigo s'exécutent en mode
> **Incremental** (`az deployment sub create`, jamais `--mode Complete`) : retirer une ressource
> du Bicep **n'efface pas** l'attribution déjà vivante sur les comptes de stockage. Un retrait
> **explicite et ciblé** de l'attribution Owner reste donc nécessaire, avec un accès Azure vivant.
> Ce runbook fournit les identifiants exacts (résolus en live) pour le faire sans ambiguïté.

---

## Ressources concernées (garde-fous)

Revalidé en live le 2026-09-03 (subscription `b8952c8c-8f72-469d-99cd-ac906da4e2fc`, tenant
`16b3c013-d300-468d-ac64-7eda0820b6d3`) :

| Environnement | Identité managée | `principalId` | Storage | Attributions live actuelles |
|---|---|---|---|---|
| dev | `id-func-certigo-dev-bk3j5ja6vw23s-host` | `f07b5723-61a9-46c2-8824-c90e2c4f87bd` | `stcertigodevbk3j5ja6` | Blob **Contributor** + Blob **Owner** + Table Contributor + Queue Contributor |
| prod | `id-func-certigo-prod-izfhvvxjdxc2k-host` | `928f8ee8-9ff0-4c0f-a27c-f078f16cc11a` | `stcertigoprodizfhvvxj` | Blob **Contributor** + Blob **Owner** + Table Contributor + Queue Contributor |

**Attribution Owner exacte à supprimer** (résolue en live — id d'attribution de rôle, pas de rôle générique) :

| Environnement | `roleAssignments` id complet |
|---|---|
| dev | `/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourcegroups/rg-certigo-dev/providers/Microsoft.Storage/storageAccounts/stcertigodevbk3j5ja6/providers/Microsoft.Authorization/roleAssignments/8a3e98d4-98ee-5669-b79a-e26d2d0b5096` |
| prod | `/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourcegroups/rg-certigo-prod/providers/Microsoft.Storage/storageAccounts/stcertigoprodizfhvvxj/providers/Microsoft.Authorization/roleAssignments/fa852099-772c-556d-b8d4-d0fd9ef08b46` |

> ⚠️ Ces IDs sont scellés au moment de la vérification (0a). Si l'attribution a changé depuis
> (rotation, redéploiement), **relire l'id avant de supprimer** — ne jamais coller un id périmé.

## ⛔ Ne JAMAIS supprimer l'attribution **Contributor**

Seule l'attribution **Owner** doit disparaître. Les rôles Table/Queue Contributor et Blob
Contributor ne sont **pas concernés** par ce runbook.

---

## Prérequis d'accès

| Prérequis | Détail |
|---|---|
| **Rôle** | `Owner` ou `User Access Administrator` sur la subscription `b8952c8c-8f72-469d-99cd-ac906da4e2fc` (ou scope resource group `rg-certigo-dev`/`rg-certigo-prod`) |
| **Merge préalable** | La PR #368 (retrait IaC de la ressource Bicep) doit être **mergée et redéployée** avant ce retrait live, pour qu'un futur `az deployment sub create` ne puisse pas re-créer l'attribution Owner entre-temps. |
| **Contrôle post-déploiement** | Après merge, vérifier qu'un déploiement `cd-backend.yml` a bien tourné sans erreur sur `dev` (et idéalement `prod`) avant de retirer l'attribution Owner. |

## Ce que l'agent a préparé / ce que VOUS exécutez

- ✅ **Préparé par l'agent** : identification exacte des 2 attributions Owner (id complet, résolu en
  live), vérification préalable que Contributor est bien présent en parallèle, ordre d'exécution,
  rollback.
- 👤 **Exécuté par vous** : la suppression elle-même, après confirmation que la PR #368 est mergée
  et déployée.

---

## Étape 0 — Garde-fous : vérifications préalables OBLIGATOIRES

> 🚨 **Ne supprimez rien tant que l'étape 0 n'est pas 100 % concluante**, et tant que la PR #368
> n'est pas mergée + redéployée sur l'environnement ciblé.

```bash
# 0a. Reconfirmer que Contributor est bien présent (le seul rôle qui doit rester) avant de toucher à Owner
az role assignment list \
  --assignee f07b5723-61a9-46c2-8824-c90e2c4f87bd \
  --scope /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/rg-certigo-dev/providers/Microsoft.Storage/storageAccounts/stcertigodevbk3j5ja6 \
  --query "[?roleDefinitionName=='Storage Blob Data Contributor']" -o table
# Attendu : une ligne "Storage Blob Data Contributor". Si vide → NE PAS CONTINUER (Functions perdraient l'écriture).

az role assignment list \
  --assignee 928f8ee8-9ff0-4c0f-a27c-f078f16cc11a \
  --scope /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/rg-certigo-prod/providers/Microsoft.Storage/storageAccounts/stcertigoprodizfhvvxj \
  --query "[?roleDefinitionName=='Storage Blob Data Contributor']" -o table
# Attendu : une ligne "Storage Blob Data Contributor".

# 0b. Reconfirmer que les ids d'attribution Owner ci-dessus sont toujours valides
az role assignment show --ids /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourcegroups/rg-certigo-dev/providers/Microsoft.Storage/storageAccounts/stcertigodevbk3j5ja6/providers/Microsoft.Authorization/roleAssignments/8a3e98d4-98ee-5669-b79a-e26d2d0b5096 -o table
az role assignment show --ids /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourcegroups/rg-certigo-prod/providers/Microsoft.Storage/storageAccounts/stcertigoprodizfhvvxj/providers/Microsoft.Authorization/roleAssignments/fa852099-772c-556d-b8d4-d0fd9ef08b46 -o table
# Attendu : chacune renvoie bien "Storage Blob Data Owner" sur le bon principalId.
```

**Checklist manuelle (à cocher avant de continuer) :**

- [ ] PR #368 mergée sur `main`.
- [ ] Un déploiement `cd-backend.yml` a tourné avec succès sur `dev` après le merge.
- [ ] Contributor confirmé présent (étape 0a) pour dev **et** prod.
- [ ] Les 2 ids d'attribution Owner confirmés valides (étape 0b).

---

## Étape 1 — Retirer l'attribution Owner (dev)

```bash
az role assignment delete --ids /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourcegroups/rg-certigo-dev/providers/Microsoft.Storage/storageAccounts/stcertigodevbk3j5ja6/providers/Microsoft.Authorization/roleAssignments/8a3e98d4-98ee-5669-b79a-e26d2d0b5096
```

## Étape 2 — Retirer l'attribution Owner (prod)

Uniquement après avoir validé dev (Functions dev écrivent toujours — voir Vérification) :

```bash
az role assignment delete --ids /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourcegroups/rg-certigo-prod/providers/Microsoft.Storage/storageAccounts/stcertigoprodizfhvvxj/providers/Microsoft.Authorization/roleAssignments/fa852099-772c-556d-b8d4-d0fd9ef08b46
```

---

## Vérification post-nettoyage

```bash
# 1) L'attribution Owner a bien disparu (dev)
az role assignment list \
  --assignee f07b5723-61a9-46c2-8824-c90e2c4f87bd \
  --scope /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/rg-certigo-dev/providers/Microsoft.Storage/storageAccounts/stcertigodevbk3j5ja6 \
  --query "[].roleDefinitionName" -o tsv
# Attendu : Storage Blob Data Contributor, Storage Table Data Contributor, Storage Queue Data
# Contributor. PLUS de "Storage Blob Data Owner".

# 2) Idem pour prod
az role assignment list \
  --assignee 928f8ee8-9ff0-4c0f-a27c-f078f16cc11a \
  --scope /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/rg-certigo-prod/providers/Microsoft.Storage/storageAccounts/stcertigoprodizfhvvxj \
  --query "[].roleDefinitionName" -o tsv
```

3. **Test fonctionnel décisif** : déclencher un déploiement OneDeploy réel (ou rejouer
   `cd-backend.yml` sur `dev`) et confirmer que le Function App lit/écrit toujours son paquet de
   déploiement (`app-package/`) sans erreur 403. Vérifier aussi qu'un appel API réel qui écrit en
   Blob (le cas échéant) fonctionne toujours.

✅ **Critère de succès** : l'attribution Owner a disparu sur dev **et** prod, Contributor reste
présent sur les deux, **et** un déploiement/appel applicatif réel s'exécute sans erreur d'accès
Storage.

---

## Rollback

Réversible en une commande, si un chemin d'écriture non prévu dépendait d'Owner (ACL POSIX,
gestion de permissions) :

```bash
# Recréer l'attribution Owner (dev) — à n'utiliser qu'en cas de régression confirmée
az role assignment create \
  --assignee f07b5723-61a9-46c2-8824-c90e2c4f87bd \
  --role "Storage Blob Data Owner" \
  --scope /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/rg-certigo-dev/providers/Microsoft.Storage/storageAccounts/stcertigodevbk3j5ja6

# Recréer l'attribution Owner (prod)
az role assignment create \
  --assignee 928f8ee8-9ff0-4c0f-a27c-f078f16cc11a \
  --role "Storage Blob Data Owner" \
  --scope /subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/rg-certigo-prod/providers/Microsoft.Storage/storageAccounts/stcertigoprodizfhvvxj
```

> Si un rollback est nécessaire, **ouvrir une issue** expliquant le chemin d'écriture qui
> nécessitait Owner : c'est probablement un signal qu'un rôle plus précis que Contributor (mais
> plus étroit qu'Owner) devrait être utilisé à la place, pas qu'Owner doit rester en place
> durablement.

## Notes & considérations

- **Aucune régression attendue** : Contributor est le rôle utilisé par Azure Functions Flex
  Consumption pour lire/écrire son paquet de déploiement (`functionAppConfig.deployment.storage`
  utilise l'identité utilisateur-assignée en authentification, pas de clé partagée). Owner
  n'apporte que la gestion des ACL/permissions du compte, non utilisée par ce chemin.
- **`infra/validate.sh`** porte désormais un garde-fou anti-régression : toute réintroduction du
  rôle Owner (GUID `b7e6dc6d-f1e8-4753-8033-0f276bb0955b`) dans `functionApp.bicep` fait échouer
  la CI.
- Ce runbook ne concerne **que** les 2 identités Function App (`...-host`). L'identité de
  déploiement CI (`ciDeploymentPrincipalId`, cf. `CLOUD_LEAST_PRIVILEGE.md`) n'a jamais eu Owner et
  n'est pas concernée.
