# Runbooks — Gouvernance CIAM, Opérations Cloud & Protection des données (Certigo)

> **Origine** : findings de l'audit de sécurité initial (PR #176), désormais suivis dans le
> registre canonique [`docs/ETAT_DU_PROJET.md`](../ETAT_DU_PROJET.md) §14 « Registre des risques
> & findings ».
> Ce dossier regroupe les procédures opérationnelles pour les findings **gouvernance CIAM**,
> **opérations cloud** et **protection des données** : `R-02`, `R-04`, `R-05`, `R-06`, `O-01`, `O-02`, `O-05`.

## ⚠️ Principe : « l'agent PRÉPARE, VOUS EXÉCUTEZ » — désormais nuancé

Historiquement, l'agent ne disposait d'aucun accès Azure : il **préparait** les commandes et
l'opérateur les exécutait. **Depuis le 2026-09-04, ce n'est plus vrai pour tous les runbooks.**
Certaines actions ont été **réellement exécutées et vérifiées** par l'agent (restauration PITR
staging, lecture des security defaults, déploiement de l'alerte d'expiration). Chaque runbook
indique désormais explicitement ce qui a été **exécuté** et ce qui reste **à exécuter**.

👉 **Le point d'entrée unique pour ce qui reste manuel est
[`ACTIONS_MANUELLES_EN_ATTENTE.md`](./ACTIONS_MANUELLES_EN_ATTENTE.md).** Si une action n'y figure
pas, c'est qu'elle est automatisée ou déjà faite.

Les opérations restantes portent sur le **tenant CIAM Azure**, la **subscription de facturation** et
les **données applicatives (Cosmos DB)**, et nécessitent des accès (Global Admin CIAM, Owner de la
subscription) ou la **possession physique** d'un facteur d'authentification.

> 🔐 **Avant toute suppression** : relisez la section « Vérification préalable » du runbook concerné
> et **confirmez chaque identifiant** (appId, keyId, nom de ressource). Une erreur d'ID peut couper
> l'authentification de production.

## Contexte technique commun (constantes réutilisées)

| Élément | Valeur | Où |
|---|---|---|
| Compte opérateur (GA fédéré) | `gabriel.chambaud@gmail.com` (MSA gmail fédéré, `#EXT#`) | Tenant CIAM + Owner sub facturation |
| Compte break-glass (GA natif) | `breakglass@certigoapp.onmicrosoft.com` (`6503a9b1…`) | Tenant CIAM — créé le 2026-07-05 (R-04) |
| **Security defaults CIAM** | ✅ **Activés** (`isEnabled: true`, vérifié 2026-09-04) | Imposent le MFA administrateur ; **0 policy Conditional Access est donc normal** |
| Tenant CIAM (Entra External ID) | `af721be8-5901-422a-b299-b9c57847b968` | Domaines `certigoapp.onmicrosoft.com` / `certigoapp.ciamlogin.com` |
| Subscription **produit** | `b8952c8c-8f72-469d-99cd-ac906da4e2fc` | `MCAPS-Hybrid-REQ-150432-2026-gchambaud`, tenant `16b3c013…` — héberge `rg-certigo-{dev,staging,prod,ci,identities,content}` |
| Subscription de facturation (MAU) | `f434ec55-f342-4948-9298-f99af5216204` | Microsoft / Visual Studio |
| Resource group facturation | `rg-certigo-identity` (westeurope) | Contient la ressource `ciamDirectories` |
| Ressource de facturation CIAM | `Microsoft.AzureActiveDirectory/ciamDirectories` | Billing MAU, SKU Base/A0 |
| Subscription vide (résidu) | `906c6a44…` | À nettoyer (O-05) |
| Azure OpenAI (dev) | `certigo-openai` (swedencentral), RG `rg-certigo-dev` | Déploiement `gpt-5.4-mini`, capacity=1, `publicNetworkAccess=Disabled` |
| Identité managée prod | `61d948e4` | Function App prod (RBAC OpenAI à ajouter si Option A O-01) |
| Identité managée dev | `55014fa6` | A déjà `Cognitive Services OpenAI User` |
| Moniteur de posture CIAM | `certigo-ciam-posture-monitor` — `8856827e-4e91-4b14-9d4a-3ca4d9586f8e` | App CIAM **sans secret** (OIDC fédéré GitHub), lecture seule Graph — alimente `ciam-posture-monitor.yml` |

**🚫 Ressources de PRODUCTION à NE JAMAIS toucher** (garde-fou transverse) :

| Objet | appId / id | Rôle |
|---|---|---|
| `Certigo Mobile` | `4d1f1075` | Client public front prod (aucun secret) |
| `Certigo API` | `12910b8e` | Backend/API prod (aucun secret) |
| `Certigo MSA Login` | `df42c145` | IdP OIDC « Microsoft account » du flux prod |
| `b2c-extensions-app` | `77216304` | Artefact système Entra |
| User flow `susi_certigo` | `7fdf12ed` | **Flux d'authentification de PRODUCTION** (lié à `Certigo Mobile`) |

## Table des runbooks

| Finding | Criticité | Titre | Fichier | Prérequis d'accès | Statut |
|---|---|---|---|---|---|
| **— (transverse)** | 🔴 Haut | **Actions manuelles en attente (point d'entrée unique)** | [`ACTIONS_MANUELLES_EN_ATTENTE.md`](./ACTIONS_MANUELLES_EN_ATTENTE.md) | Variables selon l'action | **2 actions** en attente au 2026-09-04 |
| **R-06** | 🔴 Haut | Resource lock `CanNotDelete` sur la facturation CIAM | [`R-06_resource-lock-ciam-facturation.md`](./R-06_resource-lock-ciam-facturation.md) | Owner **ou** User Access Administrator sur sub `f434ec55` | À exécuter |
| **R-04** | 🔴 Haut | Compte break-glass CIAM (Global Admin cloud-only) | [`R-04_compte-break-glass-ciam.md`](./R-04_compte-break-glass-ciam.md) | Global Admin du tenant CIAM `af721be8` | Compte créé ✅ — 🔴 **MFA à enregistrer** (aucune méthode forte, cf. actions manuelles) |
| **R-05** | 🔴 Haut | Rotation du secret IdP « Microsoft account » + alerte d'expiration | [`R-05_rotation-secret-idp-msa.md`](./R-05_rotation-secret-idp-msa.md) | Owner de l'app `df42c145` + admin External ID (user flows) | ✅ **Alerte automatisée** (2026-09-04, seuil 90 j, sans secret) — rotation à faire avant 2027-07-01 |
| **O-05** | 🟠 Moyen | Nettoyage sûr du tenant CIAM (résidus QuickStart) | [`O-05_nettoyage-tenant-ciam.md`](./O-05_nettoyage-tenant-ciam.md) | Application Administrator (apps) + Owner sub `906c6a44` (billing) | À exécuter |
| **O-01** | 🔴 Haut | Décision : Tutor IA en production (note ADR) | [`O-01_decision-tutor-ia-prod.md`](./O-01_decision-tutor-ia-prod.md) | Décision produit/technique (aucune commande destructive) | ✅ Décidé le 2026-07-06 — Option B (repli déterministe), voir `docs/adr/ADR-O-01-ai-tutor-prod.md` |
| **O-02** | 🔴 Haut | Plan de test de charge Azure OpenAI + bump capacity | [`O-02_plan-test-charge-openai.md`](./O-02_plan-test-charge-openai.md) | Cognitive Services OpenAI User (test) + Contributor (bump) | ⛔ **Bloqué** — zone DNS privée non liée au VNet CI (diagnostic + correctif Bicep fournis) |
| **R-02** | 🟠 Moyen | Restauration Point-In-Time (PITR) du compte Cosmos DB | [`R-02_cosmos-pitr-restauration.md`](./R-02_cosmos-pitr-restauration.md) | Cosmos DB Operator/Contributor + `CosmosRestoreOperator` (sub staging/prod) | ✅ **Preuve obtenue le 2026-09-04** — restore staging réel (708 s, 8 containers, compte temporaire supprimé) |
| **Azure IaC** | 🔴 Haut | Prévol, diagnostics read-only, ordre de déploiement et risques | [`AZURE_IAC_OPERATIONS.md`](./AZURE_IAC_OPERATIONS.md) | Reader pour diagnostic; rôles custom cibles ou admin PIM pour bootstrap | Versionné — exécution live soumise à autorisation |
| **Tags Azure** | 🟠 Moyen | Contrat FinOps additif pour applications et runners | [`AZURE_TAG_ADOPTION.md`](./AZURE_TAG_ADOPTION.md) | Aucun pour la validation statique; Reader pour l'inventaire live ultérieur | Versionné — aucun déploiement dans la PR |
| **Cloud least privilege** | 🔴 Haut | Migration OIDC/RBAC, policy, runners et rollback | [`CLOUD_LEAST_PRIVILEGE.md`](./CLOUD_LEAST_PRIVILEGE.md) | Reader pour inventaire; admin PIM pour toute mutation | Plan versionné — aucune mutation dans la PR |
| **Observabilité** | 🟠 Moyen | Webtests, alertes, cold-start, workbook, signaux runner, coût et confidentialité | [`OBSERVABILITY.md`](./OBSERVABILITY.md) | Reader pour diagnostic ; Contributor pour appliquer après approbation | Préparé — aucun déploiement dans la PR |
| **Contenu WORM** | 🔴 Haut | Release descriptor + paquets public/privé, OIDC, reader runtime et rollback | [`IMMUTABLE_CONTENT_STORAGE.md`](./IMMUTABLE_CONTENT_STORAGE.md) | Identité de bootstrap Azure + approbation OPS/compliance | Réconcilié avec #304 — aucun déploiement live |

## Ordre d'exécution conseillé

1. **R-06** — poser le garde-fou `CanNotDelete` **en premier** (protège immédiatement la facturation CIAM).
2. **R-04** — créer le compte break-glass cloud-only (résilience d'accès admin).
3. **R-05** — outiller la rotation du secret IdP + l'alerte d'expiration.
4. **O-05** — nettoyer les résidus QuickStart (après R-06/R-04 : garde-fou + break-glass en place).
5. **O-01** — arbitrer la décision Tutor IA prod (A provisionner / B grounded-only).
6. **O-02** — planifier et exécuter le load-test OpenAI (prérequis à l'Option A de O-01).

> **Dépendance notable** : O-01 (Option A « activer le tutor en prod ») ne devrait être engagée
> **qu'après** un load-test O-02 concluant et la mise en IaC de la ressource OpenAI.

## Prérequis outillage (poste opérateur)

| Outil | Version conseillée | Vérification |
|---|---|---|
| Azure CLI (`az`) | ≥ 2.60 | `az version` |
| Extension `account` (subscription cancel) | à jour | `az extension add --name account` |
| Connexion CIAM | device-code | `az login --tenant af721be8-5901-422a-b299-b9c57847b968 --allow-no-subscriptions` |
| Microsoft Graph (via `az rest`) | inclus dans `az` | `az rest --url https://graph.microsoft.com/v1.0/me` |

> Les appels Microsoft Graph utilisent `az rest` (jeton géré par `az`). Aucun secret n'est stocké en clair.
