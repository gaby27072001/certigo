# Audit Certigo — Refonte complète

> **⚠️ ARCHIVÉ le 2026-09-03.** Les findings encore ouverts et leur statut vérifié vivent
> désormais dans [`docs/ETAT_DU_PROJET.md`](../ETAT_DU_PROJET.md) §14 « Registre des risques &
> findings ». Ce fichier est conservé pour le détail exhaustif de l'audit cloud d'origine
> (tenant CIAM, RG Azure, RBAC — §D, §D-bis) qui n'a pas été reproduit intégralement dans le
> registre canonique. Ne pas s'y fier pour un statut de finding actuel — seul §14 de
> `ETAT_DU_PROJET.md` est tenu à jour.

> **Date de l'audit** : 2026-07-04
> **Auditeur** : Copilot (audit factuel, preuves cloud + repo réelles)
> **Commit de référence repo** : `ccc0fa36` (branche `main`, 2026-07-01 — "docs: guide interactif activation auth Android #150")
> **Périmètre cloud audité** : subscription Non-Production `MCAPS-Hybrid-REQ-150432-2026-gchambaud` (`b8952c8c-8f72-469d-99cd-ac906da4e2fc`), tenant `16b3c013-d300-468d-ac64-7eda0820b6d3` ; **+ tenant CIAM Entra External ID** `certigoapp.onmicrosoft.com` (`af721be8-5901-422a-b299-b9c57847b968`) — annuaire d'auth prod, **audité le 2026-07-05** (voir §D-bis)
> **Nature** : refonte intégrale (pas une mise à jour superficielle). Cet audit **remplace** l'audit précédent grounded sur `9c488c6` et corrige plusieurs constats devenus périmés.

---

## A. Résumé exécutif

Certigo est nettement plus mature que ne le laissait entendre l'audit précédent. Trois écarts factuels majeurs invalident d'anciens constats :

1. **L'infra EST déployée** — dev **et** prod **et** CI sont provisionnés sur Azure (l'ancien audit affirmait "infra jamais déployée, sans prod/staging"). **FAUX.**
2. **Les Functions HTTP et le middleware d'auth SONT testés** — 26 fichiers de tests API / **107 méthodes** (dont `JwtAuthMiddlewareTests`, `MiddlewareOrderingTests`, `ExceptionMiddlewareTests`, `CriticalHttpFunctionsTests`). L'ancien constat "0 test Functions/middleware auth" est **périmé**.
3. **L'anti-triche a désormais une sanction** — le verdict `Reject` supprime toutes les récompenses (0 XP/gems, pas de level-up). L'ancien constat "détection sans sanction" est **périmé**.

La posture de sécurité prod est **solide** (réseau privé, AAD-only, RBAC data-plane, purge protection, TLS 1.2, alertes). Les problèmes résiduels sont **ciblés** et **corrigeables rapidement**, pas structurels.

**Décision de readiness** : **GO conditionnel** pour une prod pilote / accès contrôlé.
Prérequis bloquants avant ouverture large :
- Externaliser les secrets JWT (Key Vault reference) — **faille sécurité**.
- Poser une concurrence optimiste sur l'écriture profil (économie) — **risque intégrité data**.
- Décider et valider le sort du Tutor IA en prod (actuellement désactivé) — **zone d'ombre produit**.
- Passer Cosmos prod en backup **Continuous/PITR** — **risque récupération data**.

> **Complément non bloquant (2026-07-05)** : le **tenant CIAM Entra External ID** (annuaire d'auth prod) et sa **ressource de facturation MAU** (subscription Visual Studio `f434ec55`) ont été audités (§D-bis). Posture globalement **saine** (app mobile sans secret, multi-IdP, aucun secret imminent). Actions de **gouvernance** non bloquantes à planifier : compte break-glass (R-04), rotation du secret IdP MSA (R-05), resource lock sur la facturation (R-06), suppression des résidus QuickStart (O-05).

---

## B. Méthodologie & périmètre

Audit conduit sur preuves observables (pas de supposition) :
- **Cloud** : interrogation live via `az` sur la subscription Non-Prod (Resource Graph, config par ressource, IAM/RBAC control-plane + Cosmos data-plane, app settings des Function Apps) ; puis interrogation du **tenant CIAM** via Microsoft Graph (app registrations, credentials, user flows, rôles, users) et de sa **ressource de facturation** `ciamDirectories` (subscription `f434ec55`).
- **Repo** : lecture du code, comptage réel des tests, inspection du Bicep et des `.bicepparam`.
- **Classification** de chaque constat : **Faille avérée** / **Zone d'ombre** / **Risque latent**, avec criticité et preuve.

### Périmètre étendu au tenant CIAM (2026-07-05)
Le **tenant Certigo personnel** (`certigoapp.onmicrosoft.com`, `af721be8-5901-422a-b299-b9c57847b968`) a été **audité le 2026-07-05** via `az login` device-code (compte `gabriel.chambaud@gmail.com`). Il héberge l'**identité Entra External ID (CIAM)** de l'auth prod (la Function App prod référence `…ciamlogin.com`). Sa **ressource de facturation MAU** vit dans la subscription **`f434ec55…` (Microsoft/Visual Studio)**, elle aussi inventoriée. Détails complets en **§D-bis**. Seule limite résiduelle : l'état des **security defaults** du tenant n'est pas confirmable avec un compte délégué (voir §D-bis · limites) — **non bloquant**.

---

## C. Écarts vs audit précédent (corrections factuelles)

| Ancien constat | Réalité 2026-07-04 | Statut |
|---|---|---|
| "Infra jamais déployée, pas de prod/staging" | dev + prod + CI déployés sur Azure | **Périmé — FAUX** |
| "0 test Functions HTTP / middleware auth" | 107 tests API, middleware auth + ordering + exception testés | **Périmé — FAUX** |
| "Anti-triche : détection sans sanction" | Verdict Reject supprime toutes les récompenses | **Périmé — corrigé** |
| "256 tests backend" | **412 méthodes de test** (Api 107 + App 113 + Domain 172 + Infra 20) | **Sous-évalué** |
| "Intégrité transactionnelle absente (submit)" | Idempotence via `ClientAttemptId` + conflit de création Cosmos | **Partiellement corrigé** (voir R-01) |
| Scorecard ≈ 5.9/10 | Réévaluée à ≈ **7.4/10** (voir section K) | **Revu à la hausse** |

---

## D. État des lieux CLOUD (réel)

Trois groupes de ressources déployés, **aucun** `rg-certigo-staging`.

### rg-certigo-dev (westeurope)
Cosmos `cosmos-certigo-dev-bk3j5ja6vw23s`, Storage `stcertigodevbk3j5ja6`, KeyVault `kv-certigo-dev-bk3j5j`, App Insights + Log Analytics, Functions `func-certigo-dev-bk3j5ja6vw23s`, **Azure OpenAI `certigo-openai` (swedencentral)**, ACS Email, Event Grid.

### rg-certigo-prod (westeurope)
Cosmos `cosmos-certigo-prod-izfhvvxjdxc2k`, Storage `stcertigoprodizfhvvxj`, KeyVault `kv-certigo-prod-izfhvv`, Functions `func-certigo-prod-izfhvvxjdxc2k`, **3 alertes** (`scheduledQueryRules` : HTTP 5xx / 401 / 403), action group `ag-certigo-security`. **Pas d'OpenAI, pas d'ACS en prod.**

### rg-certigo-ci
VNet + NSG + NAT Gateway + **2 VMs** (self-hosted CI runners). Infra **non décrite dans le Bicep applicatif** (voir G — drift).

### Posture de sécurité par service (dev / prod)

| Service | dev | prod | Verdict |
|---|---|---|---|
| **Key Vault** | softDelete✔, purgeProtection✔, RBAC✔, publicNet **Enabled** | idem + publicNet **Disabled** | Prod durci ✔ |
| **Cosmos DB** | disableLocalAuth **true** (clés off), backup **Periodic**, publicNet Enabled | idem + publicNet **Disabled** | AAD-only ✔ / backup ⚠ |
| **Storage** | httpsOnly✔, TLS1.2, sharedKey **false** (AAD-only), publicNet Enabled | idem + publicNet **Disabled** | Excellent ✔ |
| **Function App** | identity **SystemAssigned**, FTPS Disabled, minTLS1.2 | idem | Bon ✔ |
| **Azure OpenAI** | publicNet Enabled, disableLocalAuth **true**, 1 déploiement `gpt-5.4-mini` GlobalStandard **capacity=1 (~1K TPM)** | **absent** | ⚠ (dev-only, sous-dimensionné) |

### RBAC (least-privilege quasi respecté)
- **Identité dev** (`55014fa6`) : Storage Blob Data Owner, KV Secrets User, Storage Queue Data Contributor, **Cognitive Services OpenAI User** (sur `certigo-openai`).
- **Identité prod** (`61d948e4`) : Storage Blob Data Owner, KV Secrets User, Storage Queue Data Contributor (pas d'OpenAI — cohérent).
- **Cosmos data-plane** : les deux identités ont le rôle Built-in Data Contributor, scope compte.
- Réserve mineure : *Storage Blob Data **Owner*** là où *Contributor* suffirait probablement (léger sur-privilège).

---

## D-bis. État des lieux TENANT CIAM (Entra External ID) & facturation

> Audité le **2026-07-05** via `az login` device-code (`gabriel.chambaud@gmail.com`). Tenant `af721be8-5901-422a-b299-b9c57847b968`, domaine `certigoapp.ciamlogin.com`. **Confirmé Entra External ID (CIAM)** — pas Azure AD B2C legacy : la ressource de facturation est de type `Microsoft.AzureActiveDirectory/ciamDirectories`.

### Facturation & rattachement Azure
La ressource de facturation vit dans la subscription **`f434ec55…` (Microsoft / Visual Studio)**, RG `rg-certigo-identity` (westeurope) :
- Type `Microsoft.AzureActiveDirectory/ciamDirectories`, **billing MAU** (Monthly Active Users), SKU **Base / tier A0** (gratuit ≤ 50k MAU), effectif depuis **2026-06-30**, `provisioningState: Succeeded`, countryCode `FR`, `tenantId` = `af721be8…`.
- **RBAC subscription** : `gabriel.chambaud@gmail.com` = **Owner** unique (+ *Foundry User*). Aucun service principal, aucun groupe.
- ⚠️ **Aucun resource lock** (`CanNotDelete`) sur cette ressource critique → une suppression accidentelle couperait l'auth prod (voir **R-06**).
- Subscription **`906c6a44…`** ("Azure subscription 1") = **vide** (résidu, à ignorer/nettoyer).

### App registrations (7)

| App (appId court) | Rôle | Secret / Cert | Verdict |
|---|---|---|---|
| **Certigo Mobile** (`4d1f1075`) | Client public front prod (redirects `certigo://auth/`) | **Aucun secret** ✅ | Sain — client public sans secret |
| **Certigo API** (`12910b8e`) | Backend/API prod | **Aucun secret, aucun redirect** ✅ | Sain |
| **Certigo MSA Login** (`df42c145`) | IdP OIDC "Microsoft account" du flux prod | secret `certigo-ciam-oidc-2026-07` **exp. 2027-07-01** ⚠ | Fonctionnel — dépendance secret (**R-05**) |
| **b2c-extensions-app** (`77216304`) | Artefact système | — | Ne pas toucher ✅ |
| **QuickStart Application** (`35bb7bbc`) | Résidu tutoriel | secret exp. 2028-06-30, redirects `jwt.ms`+localhost | 🟡 À supprimer (**O-05**) |
| **QuickStart Application** (`49957408`) | Résidu tutoriel | secret exp. 2028-07-01, `jwt.ms`+localhost | 🟡 À supprimer (**O-05**) |
| **QuickStart Application** (`5f371968`) | Résidu tutoriel | secret exp. 2028-07-01, `jwt.ms`+localhost | 🟡 À supprimer (**O-05**) |

- **Aucun secret expiré ni expirant sous 90 j** (le plus proche = 2027-07-01). **Aucun certificat** (keyCredentials vides) → 100 % client secrets.

### User flows (parcours d'authentification)
- **`susi_certigo`** (`7fdf12ed`) = **FLUX PROD**, lié à `Certigo Mobile`. IdP configurés : **Email+password, Google, Microsoft account** (via `df42c145`), **Apple** (serviceId `com.certigo.ciam.service`, developerId `FFQPC7NC68`, keyId `Z476P2APZV`, clé **managée par Microsoft**). `isSignUpAllowed: true`. Configuration **multi-IdP solide** ✅.
- **2 flux QuickStart** (liés à `35bb7bbc` et `5f371968`) — Email+password seul → 🟡 résidus à supprimer (**O-05**).

### Identités & gouvernance
- **1 seul Global Administrator** = `gabriel.chambaud_gmail.com#EXT#` (MSA gmail fédéré externe) → 🟠 **pas de compte break-glass cloud-only** (**R-04**). Même identité = Owner de la subscription de facturation.
- **Conditional Access = vide** (`value: []`). Nuance : en External ID la protection admin repose sur les **security defaults** (voir limites ci-dessous).
- **3 utilisateurs** : l'admin gmail externe, 1 compte B2C (GUID-named), 1 `testeur@certigoapp.onmicrosoft.com`.

### Limites d'accès (audit CIAM via compte délégué)
- `identitySecurityDefaultsEnforcementPolicy` → **Forbidden** : état on/off des **security defaults non confirmé** (nécessite un Global Admin natif).
- `identityProviders` (v1.0) → **Forbidden AADB2C** : contourné via l'API beta `authenticationEventsFlows` (données obtenues).

---

## E. État des lieux REPO (réel)

- **Backend** .NET 8, Clean Architecture (Domain / Application / Infrastructure / Api), ~28 endpoints, **20 groupes de Functions** (Achievement, Auth, Catalog, Exam, Friend, Health, HealthProbe, Leaderboard, Lesson, Notification, Path, Quest, Quiz, Recommendation, Season, ShareCard, Shop, Streak, Tutor, User).
- **Tests backend** : **412 méthodes** — Api 107, Application 113, Domain 172, Infrastructure 20. Harness d'hôte Functions in-process (`FunctionTestHost`, `FunctionTestHarness`).
- **Mobile** Flutter : ~62 fichiers Dart, 15 features, ~177 tests (non re-vérifié ce cycle — inchangé).
- **IaC** : modules Bicep (`functionApp`, `keyvault`, `cosmos`, `storage`, `policy`, …) + params `dev`/`staging`/`prod`.
- **Auth** : guard dev/prod via `AuthValidatorSelection` ; middleware JWT testé.

---

## F. Registre des findings (classés)

Légende criticité : 🔴 Haute · 🟠 Moyenne · 🟡 Faible.

### Failles avérées

| ID | Crit. | Constat | Preuve | Impact |
|---|---|---|---|---|
| **F-01** | 🟠 | **Secrets JWT en clair dans les app settings** (`AUTH_JWT_SIGNING_KEY`) en **dev ET prod** | app settings des 2 Function Apps | Secret de signature lisible par tout détenteur d'accès au plan de contrôle App Service ; devrait être une **Key Vault reference** |
| **F-02** | 🟡 | **Auth Entra dev factice** : `ENTRA_AUTHORITY` dev pointe sur un tenant placeholder `00000000-…` | app settings dev | Le mode dev ne valide pas réellement Entra ; seul le bypass `AUTH_ALLOW_DEV=true` fonctionne (acceptable en dev, mais trompeur) |

### Zones d'ombre non couvertes

| ID | Crit. | Constat | Preuve | À lever |
|---|---|---|---|---|
| **O-01** | 🟠 | **Tutor IA désactivé en prod** (`TUTOR_LLM_ENABLED=False`, endpoint vide, pas d'OpenAI prod) | app settings prod + absence ressource | La feature phare n'a **jamais tourné en prod** ; validée dev-only |
| **O-02** | 🟠 | **OpenAI jamais load-testé**, capacity=1 (~1K TPM) | config `certigo-openai` | Risque 429 sous charge non mesuré |
| **O-03** | ✅ | **Tenant CIAM perso — AUDITÉ (blocage levé)** | §D-bis (audit 2026-07-05) | **Levé** : 7 app registrations, secrets/flux/gouvernance inventoriés. Aucun secret imminent, app mobile sans secret. Nouveaux findings dérivés : O-05, R-04, R-05, R-06 |
| **O-04** | 🟡 | **Pas d'environnement staging déployé** malgré `staging.bicepparam` | 3 RG réels, param non appliqué | Aucun pré-prod aligné sur le durcissement prod |
| **O-05** | 🟡 | **Résidus tutoriels dans le tenant CIAM** : 3 app registrations *QuickStart* (redirects `jwt.ms`/localhost) + 2 user flows QuickStart ; subscription `906c6a44…` vide | §D-bis | Surface d'attaque et bruit de gouvernance inutiles ; ménage à faire |

### Risques latents

| ID | Crit. | Constat | Preuve | Chemin de défaillance |
|---|---|---|---|---|
| **R-01** | 🟠 | **Écriture profil (économie) sans concurrence optimiste** — read-modify-write sur Xp/gems/streak, **aucun ETag/If-Match dans tout le backend** | grep global : 0 occurrence ETag ; `QuizService.SubmitAsync` calcule `newXp = profile.Xp + xpEarned` puis écrit | Deux soumissions **distinctes** concurrentes (multi-onglet, retries) → **lost update** sur le profil (XP/gems perdus ou incohérents). L'idempotence par `ClientAttemptId` protège les **doublons** du même attempt, **pas** les updates concurrents distincts |
| **R-02** | 🟠 | **Cosmos prod en backup Periodic** (pas de `backupPolicy` dans le Bicep → défaut Periodic) | `infra/**/*.bicep` sans bloc backup ; Cosmos déployé Periodic | Pas de PITR : récupération limitée aux snapshots périodiques en cas de corruption/suppression prod |
| **R-03** | 🟡 | **Sur-privilège Storage** (Blob Data *Owner* vs *Contributor*) | RBAC des 2 identités | Rayon d'action élevé d'une identité compromise |
| **R-04** | 🟠 | **CIAM : un seul Global Admin, pas de break-glass** = `gabriel.chambaud_gmail.com#EXT#` (MSA externe fédéré) | §D-bis | Perte d'accès au compte gmail = **perte de contrôle du tenant d'identité prod** (aucun admin cloud-only de secours) |
| **R-05** | 🟠 | **Login "Microsoft account" prod dépend d'un client secret** (`df42c145`, `certigo-ciam-oidc-2026-07`, exp. **2027-07-01**) | §D-bis | À l'expiration **sans rotation**, l'IdP Microsoft du flux prod casse ; pas d'alerte outillée |
| **R-06** | 🟠 | **Ressource de facturation CIAM sans resource lock** (`ciamDirectories`, sub `f434ec55…`, single Owner) | §D-bis | Suppression accidentelle → **coupure de l'auth prod** ; aucun garde-fou `CanNotDelete` |

---

## G. Drift IaC vs réel

| Élément | IaC (Bicep/params) | Déployé réel | Écart |
|---|---|---|---|
| Environnement staging | `staging.bicepparam` présent | **aucun RG staging** | Param non appliqué |
| Azure OpenAI | **absent du Bicep** (seulement feature-flags dans `functionApp.bicep`) | `certigo-openai` créé à la main (dev) | **Ressource hors IaC**, non reproductible |
| Infra CI (VNet/NSG/NAT/2 VMs) | non décrite dans le Bicep applicatif | `rg-certigo-ci` déployé | Infra non documentée / non versionnée avec l'app |
| Backup Cosmos | pas de `backupPolicy` | Periodic (défaut) | Défaut implicite non maîtrisé |

### Dérive documentaire (à corriger)
`docs/ETAT_DU_PROJET.md` (l.257) et l'ancien `AUDIT_Certigo.md` affirment "infra à provisionner / pas de prod". **Contredit par la réalité** (prod déployé et durci). À aligner.

---

## H. Plan de remédiation priorisé

### Quick wins (jours)
1. **F-01** — Migrer `AUTH_JWT_SIGNING_KEY` (dev+prod) vers Key Vault reference. *Gate : redéploiement + auth toujours OK.*
2. **R-02** — Activer backup **Continuous** sur Cosmos prod (via Bicep `backupPolicy`). *Gate : PITR visible.*
3. **R-03** — Rétrograder Storage Blob Data Owner → Contributor. *Gate : Functions écrivent toujours.*
4. **R-06** — Poser un **resource lock `CanNotDelete`** sur la ressource `ciamDirectories` (sub `f434ec55…`). *Gate : lock visible, suppression bloquée.*
5. **O-05** — Supprimer les 3 app registrations *QuickStart* + 2 user flows QuickStart du tenant CIAM ; nettoyer la subscription vide `906c6a44…`. *Gate : tenant réduit aux 4 apps utiles + flux `susi_certigo`.*
6. Aligner `docs/ETAT_DU_PROJET.md` + réécrire `AUDIT_Certigo.md` (ce document).

### Travaux structurants (1–2 semaines)
7. **R-01** — Concurrence optimiste sur l'écriture profil : `IfMatchEtag` + retry sur conflit dans `ProfileRepository`/`QuizService`/`ExamService`. *Gate : test de charge concurrent prouvant l'absence de lost update.*
8. **R-04** — Créer un **compte break-glass cloud-only** (Global Admin natif du tenant CIAM, hors gmail) + procédure d'urgence. *Gate : 2 admins, break-glass testé.*
9. **R-05** — Mettre en place la **rotation + alerte d'expiration** du secret `df42c145` (`2027-07-01`) ; envisager un certificat. *Gate : alerte J-30 opérationnelle.*
10. **O-01** — Décision Tutor prod : soit provisionner OpenAI prod + activer, soit acter officiellement le "grounded-only" en prod. *Gate : décision tracée + test live si activé.*
11. **O-02** — Load-test OpenAI dev + dimensionner capacity/quota cible. *Gate : courbe TPM vs 429.*

### Industrialisation (fond)
12. **O-04** — Déployer un vrai **staging** aligné prod (réseau privé) depuis `staging.bicepparam`.
13. **G/CI** — Versionner l'infra CI (`rg-certigo-ci`) et la ressource OpenAI dans l'IaC (éliminer le drift).

---

## I. Preuves manquantes bloquantes (à obtenir)
- Résultat d'un **test de charge concurrent** sur submit → confirmer/infirmer R-01 en réel.
- Résultat load-test OpenAI → chiffrer O-02.
- Preuve d'un **restore** Cosmos → valider la stratégie de reprise (R-02).
- **État des security defaults du tenant CIAM** (`identitySecurityDefaultsEnforcementPolicy` → Forbidden avec compte délégué) → à confirmer via un Global Admin natif (limite de scope, non bloquant).

---

## J. Points forts confirmés (à préserver)
- Prod **entièrement en réseau privé** (KV/Cosmos/Storage publicNet Disabled).
- **AAD-only** partout : Storage sans clé partagée, Cosmos sans clés locales (data-plane RBAC).
- **Key Vault purge protection ON** (dev+prod).
- **Identités managées** bien câblées, quasi least-privilege.
- **Monitoring prod** : alertes 5xx/401/403 + action group sécurité.
- **prod `AUTH_ALLOW_DEV=false`** (bypass dev correctement désactivé).
- **412 tests backend** dont middleware auth, idempotence submit, anti-triche avec sanction.
- **Identité externe (CIAM) saine** : app mobile prod **client public sans secret**, flux multi-IdP (Email/Google/Microsoft/Apple avec clé Apple **managée par Microsoft**), **aucun secret expiré ni imminent** (< 90 j), 100 % sans certificat orphelin, facturation **MAU tier gratuit (A0)**.

---

## K. Scorecard réévaluée

| Domaine | Note /10 | Commentaire |
|---|---|---|
| Architecture & code | 8.0 | Clean Arch, séparation nette, idempotence + anti-triche |
| Tests | 7.5 | 412 tests, bonne couverture ; manque load/E2E device |
| Sécurité cloud | 8.0 | Prod durci, AAD-only, RBAC ; -secrets JWT en clair |
| Sécurité applicative | 7.0 | Auth testée ; F-01/F-02 à corriger |
| Intégrité data | 6.0 | Idempotence OK ; R-01 (concurrence profil) ouvert |
| Ops / DR | 6.5 | Alertes OK ; backup Periodic, pas de staging |
| IaC / repro | 6.5 | Bicep solide ; drift OpenAI + CI + staging |
| Gouvernance / doc | 6.0 | Doc périmée à réaligner |
| Identité externe (CIAM) | 7.0 | Flux prod propre, mobile sans secret, aucun secret imminent ; -single admin/pas de lock/résidus QuickStart |
| **Global** | **≈ 7.4** | Nettement au-dessus de l'ancienne éval (5.9) |

---

## L. Conclusion
Certigo est **prêt pour une prod pilote/contrôlée**, à condition de traiter d'abord les 4 prérequis (F-01, R-01, O-01, R-02). Aucun problème structurel bloquant : la base cloud et applicative est saine et bien testée. Les actions restantes sont ciblées, mesurables, et majoritairement des quick wins ou des chantiers courts.
