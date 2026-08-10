# Runbooks — Gouvernance CIAM, Opérations Cloud & Protection des données (Certigo)

> **Origine** : findings de l'audit de sécurité `AUDIT_Certigo.md` (PR #176).
> Ce dossier regroupe les procédures opérationnelles pour les findings **gouvernance CIAM**,
> **opérations cloud** et **protection des données** : `R-02`, `R-04`, `R-05`, `R-06`, `O-01`, `O-02`, `O-05`.

## ⚠️ Principe : « l'agent PRÉPARE, VOUS EXÉCUTEZ »

Ces runbooks portent sur le **tenant CIAM Azure**, la **subscription de facturation** et les
**données applicatives (Cosmos DB)**. Les opérations nécessitent des accès (Global Admin du tenant
CIAM, Owner de la subscription, opérateur Cosmos DB) que **seul l'opérateur humain possède**. L'agent Copilot **n'a lancé aucune commande Azure** : il a **préparé**
les commandes `az` CLI / Microsoft Graph exactes, les procédures pas-à-pas, les vérifications et les
rollbacks. **C'est vous qui exécutez** chaque commande, après relecture.

> 🔐 **Avant toute suppression** : relisez la section « Vérification préalable » du runbook concerné
> et **confirmez chaque identifiant** (appId, keyId, nom de ressource). Une erreur d'ID peut couper
> l'authentification de production.

## Contexte technique commun (constantes réutilisées)

| Élément | Valeur | Où |
|---|---|---|
| Compte opérateur (seul Global Admin actuel) | `gabriel.chambaud@gmail.com` (MSA gmail fédéré, `#EXT#`) | Tenant CIAM + Owner sub facturation |
| Tenant CIAM (Entra External ID) | `af721be8-5901-422a-b299-b9c57847b968` | Domaines `certigoapp.onmicrosoft.com` / `certigoapp.ciamlogin.com` |
| Subscription de facturation (MAU) | `f434ec55-f342-4948-9298-f99af5216204` | Microsoft / Visual Studio |
| Resource group facturation | `rg-certigo-identity` (westeurope) | Contient la ressource `ciamDirectories` |
| Ressource de facturation CIAM | `Microsoft.AzureActiveDirectory/ciamDirectories` | Billing MAU, SKU Base/A0 |
| Subscription vide (résidu) | `906c6a44…` | À nettoyer (O-05) |
| Azure OpenAI (dev) | `certigo-openai` (swedencentral), RG `rg-certigo-dev` | Déploiement `gpt-5.4-mini`, capacity=1 |
| Identité managée prod | `61d948e4` | Function App prod (RBAC OpenAI à ajouter si Option A O-01) |
| Identité managée dev | `55014fa6` | A déjà `Cognitive Services OpenAI User` |

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
| **R-06** | 🔴 Haut | Resource lock `CanNotDelete` sur la facturation CIAM | [`R-06_resource-lock-ciam-facturation.md`](./R-06_resource-lock-ciam-facturation.md) | Owner **ou** User Access Administrator sur sub `f434ec55` | À exécuter |
| **R-04** | 🔴 Haut | Compte break-glass CIAM (Global Admin cloud-only) | [`R-04_compte-break-glass-ciam.md`](./R-04_compte-break-glass-ciam.md) | Global Admin du tenant CIAM `af721be8` | À exécuter |
| **R-05** | 🔴 Haut | Rotation du secret IdP « Microsoft account » + alerte J-30 | [`R-05_rotation-secret-idp-msa.md`](./R-05_rotation-secret-idp-msa.md) | Owner de l'app `df42c145` + admin External ID (user flows) | À exécuter |
| **O-05** | 🟠 Moyen | Nettoyage sûr du tenant CIAM (résidus QuickStart) | [`O-05_nettoyage-tenant-ciam.md`](./O-05_nettoyage-tenant-ciam.md) | Application Administrator (apps) + Owner sub `906c6a44` (billing) | À exécuter |
| **O-01** | 🔴 Haut | Décision : Tutor IA en production (note ADR) | [`O-01_decision-tutor-ia-prod.md`](./O-01_decision-tutor-ia-prod.md) | Décision produit/technique (aucune commande destructive) | À arbitrer |
| **O-02** | 🔴 Haut | Plan de test de charge Azure OpenAI + bump capacity | [`O-02_plan-test-charge-openai.md`](./O-02_plan-test-charge-openai.md) | Cognitive Services OpenAI User (test) + Contributor (bump) | À exécuter |
| **R-02** | 🟠 Moyen | Restauration Point-In-Time (PITR) du compte Cosmos DB | [`R-02_cosmos-pitr-restauration.md`](./R-02_cosmos-pitr-restauration.md) | Cosmos DB Operator/Contributor + `CosmosRestoreOperator` (sub staging/prod) | Remédiation IaC ✅ (PR #178) — restore-test à planifier |
| **Azure IaC** | 🔴 Haut | Prévol, diagnostics read-only, ordre de déploiement et risques | [`AZURE_IAC_OPERATIONS.md`](./AZURE_IAC_OPERATIONS.md) | Reader pour diagnostic ; Contributor + User Access Administrator pour appliquer | Versionné — exécution live soumise à autorisation |

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
