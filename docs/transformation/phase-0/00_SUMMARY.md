# CertiGo — PHASE 0 : Résumé Exécutif (`00_SUMMARY.md`)

> **Date :** 22/10/2026
> **Branche d'audit :** `transform/phase-0-audit`
> **Commit de base (`origin/main`) :** `778f9c247ceb9c0db29fb931a8573bd328b492ab`
> **Périmètre :** Audit + Baseline en lecture seule stricte (aucun fichier existant modifié)

---

## 1. État global & Chiffres clés

| Indicateur | Valeur vérifiée | Preuve / Livrable |
|---|---|---|
| **Client iOS natif (`apps/apple/`)** | **39 fichiers Swift** (**24 553 lignes**, dont **37 fichiers prod / 20 863 lignes**) | [`01_REPOSITORY_MAP.md`](01_REPOSITORY_MAP.md), [`05_HARDCODED_VALUES.md`](05_HARDCODED_VALUES.md) |
| **Monolithe `CertigoNativeApp.swift`** | **8 565 lignes** (**38 `struct : View`**, **74,1 %** de la dette de valeurs en dur) | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:1-8565` |
| **Targets Xcode (`CertigoNative.xcodeproj`)** | **2 targets** : `CertigoNative` (app) + `CertigoWidgetExtension` (ajouté par PR #100) | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj` |
| **Tests unitaires `CertigoKit` (`swift test`)** | **187 / 187 réussis (0 warning, `-warnings-as-errors`, 2,89 s)** | [`02_BASELINE.md`](02_BASELINE.md), [`08_TESTS.md`](08_TESTS.md) |
| **Harnais Swift autonomes (`NativeModel` + `DemoFlow`)** | **254 / 254** + **3 304 / 3 304 assertions réussies** | [`02_BASELINE.md`](02_BASELINE.md), [`08_TESTS.md`](08_TESTS.md) |
| **Tests d'architecture & contrats Python** | **227 / 240 réussis** (13 `skipped` faute de macOS/Xcode local) ; `project_state.py --check` **OK** | [`02_BASELINE.md`](02_BASELINE.md) |
| **Tests backend `.NET 10` (`backend/Certigo.sln`)** | **1 122 / 1 143 réussis** (21 `skipped` Cosmos live) | [`02_BASELINE.md`](02_BASELINE.md) |
| **Contenu as code (`content/`)** | **91 parcours**, **147 leçons** validés à 100 % (`validate_content.mjs`) ; **146/147 items en QCM** | [`01_REPOSITORY_MAP.md`](01_REPOSITORY_MAP.md), [`02_BASELINE.md`](02_BASELINE.md) |
| **Écrans / vues / modales inventoriés** | **32 écrans/vues (`E-01` à `E-32`)**, **17 modales/alertes**, **5 familles de deep links** | [`03_SCREENS_AND_ROUTES.md`](03_SCREENS_AND_ROUTES.md) |
| **Valeurs codées en dur (Swift natif)** | **526 occurrences** (`260` espacements/tailles/rayons, `103` couleurs, `81` typo, `81` chaînes, `1` anim.) | [`05_HARDCODED_VALUES.md`](05_HARDCODED_VALUES.md), [`hardcoded_values.csv`](hardcoded_values.csv) |
| **Références de marques tierces (`content/` + app)** | **132 produits/certifications** (**1 767 occurrences**) : **89** Niv. 1, **28** Niv. 2, **15** Niv. 3/repli | [`14_BRAND_ASSETS_AUDIT.md`](14_BRAND_ASSETS_AUDIT.md), [`brand_references.csv`](brand_references.csv) |
| **Contrats « MUST NOT BREAK »** | **24 endpoints HTTP** consommés + **10 sous-systèmes critiques** documentés | [`10_BUSINESS_LOGIC_CONTRACTS.md`](10_BUSINESS_LOGIC_CONTRACTS.md) |

---

## 2. Synthèse des Hypothèses H1 à H11

| # | Statut sur `HEAD` (`778f9c24`) | Constat vérifié et preuve |
|---|---|---|
| **H1** | **VÉRIFIÉ** | Client cible = `apps/apple/CertigoNative` + SPM `apps/apple/CertigoKit` (`CertigoDomain`, `CertigoData`, `CertigoAppleFileIO`, `CertigoCortex`). |
| **H2** | **VÉRIFIÉ** | `apps/mobile` + `packages/*` (Flutter/Dart) est un héritage fonctionnel ; l'effort actif est sur `apps/apple/`. |
| **H3** | **VÉRIFIÉ** | `CertigoNativeApp.swift` est un monolithe de **8 565 lignes** regroupant l'essentiel des vues et du style. |
| **H4** | **INFIRMÉ SUR `HEAD` (DÉJÀ CORRIGÉ PAR PR #99)** | L'erreur `@Environment(\.accessibilityContrast)` a été corrigée par PR #99 (`1a025a28` / `f6dd2ea7`) en `@Environment(\.colorSchemeContrast)` à `CertigoNativeApp.swift:3683`. |
| **H5** | **VÉRIFIÉ** | `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `MSAL 2.16.0`. |
| **H6** | **VÉRIFIÉ** | 4 onglets (`Apprendre`, `Coach`, `Communauté`, `Profil`), mode Démo et `NativeDeveloperConnector` exposés jusque dans `NativeProductionEntry`. |
| **H7** | **VÉRIFIÉ** | 8 langues (`fr`, `en`, `hi`, `zh-Hans`, `ko`, `es`, `it`, `de`) dans `AppLanguage.swift:3-12` ; contenu officiel non traduit automatiquement. |
| **H8** | **VÉRIFIÉ** | Notation, XP, streak, readiness, ligues et achats sont autoritatifs côté serveur (`backend/`) ; clé de correction jamais exposée. |
| **H9** | **VÉRIFIÉ (MODULE SPM `Prism` ABSENT)** | Aucun module `apps/apple/CertigoKit/Sources/Prism` n'existe ; des jetons internes `NativePrism` / `NativeTrackTheme` ont été ajoutés dans `CertigoNativeApp.swift` (PR #96/#98). |
| **H10** | **PARTIELLEMENT INFIRMÉ (PR #100)** | `CertigoWidgetExtension` (`WidgetKit`) existe depuis PR #100 (`3b07d68d`), mais **aucune** Live Activity (`ActivityKit`), aucun `AppIntent`/Spotlight ni contrôle Centre de contrôle n'existe. |
| **H11** | **VÉRIFIÉ** | Visuels de marques dessinés en code (`NativeCertificationCrest`, `NativeEcosystemEmblem`, `NativeMicrosoftVendorBadge`, `vendor_brand.dart`) et 7 mascottes Flutter dérivées d'icônes Azure, sans `BrandAssets` officiel ni `content/brands/registry.yaml`. |

---

## 3. Top 10 des constats (avec preuves)

1. **Monolithe `CertigoNativeApp.swift` (8 565 lignes) et couplage aux tests Python** : concentre 38 vues et 74,1 % des valeurs codées en dur (`apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:1-8565`), tandis que `tools/tests/test_native_source_membership.py:58-110` et `tools/tests/test_native_prism_presentation.py:16-20` vérifient statiquement la liste exacte des fichiers Swift.
2. **H4 déjà résolue sur `main` (`778f9c24`)** : `@Environment(\.colorSchemeContrast)` est en place à `CertigoNativeApp.swift:3683` (PR #99).
3. **526 valeurs codées en dur hors module `Prism`** : 260 espacements/tailles/rayons, 103 couleurs brutes, 81 polices/tailles fixes, 81 chaînes non localisées et 1 durée d'animation ([`05_HARDCODED_VALUES.md`](05_HARDCODED_VALUES.md)).
4. **Visuels de marques et de certifications non conformes au §22A** : `NativeCertificationCrest` (`CertigoNativeApp.swift:3682-3836`), `NativeEcosystemEmblem` (`:3838-3935`) et `NativeMicrosoftVendorBadge` (`:3937-4041`) dessinent des logos d'éditeurs et des blasons de certification en `Canvas`/formes SwiftUI au lieu d'utiliser `BrandAssets` / `BrandLabel` ([`14_BRAND_ASSETS_AUDIT.md`](14_BRAND_ASSETS_AUDIT.md)).
5. **132 produits/certifications tiers recensés dans `content/` et l'app (`1 767` occurrences)** : **89** couvrables immédiatement en Niveau 1 (kits d'architecture officiels), **28** en Niveau 2 (autorisation écrite requise : M365, GitHub, AWS hors schémas, CNCF), **15** en Niveau 3 / repli ([`brand_references.csv`](brand_references.csv)).
6. **Noms de produits obsolètes ou traduits dans `content/`** : occurrences de `Azure AD` / `Azure Active Directory` (→ *Microsoft Entra ID*), `Form Recognizer` (→ *Azure AI Document Intelligence*), `Office 365`, `Microsoft 365 Security Center`, `M365`, `GCP` ([`14_BRAND_ASSETS_AUDIT.md`](14_BRAND_ASSETS_AUDIT.md)).
7. **Mode Démo et connecteur développeur accessibles depuis `NativeProductionEntry`** : le bouton « Découvrir la démo » et l'accès au connecteur/galerie de widgets simulée restent atteignables dans l'entrée de production (`CertigoNativeApp.swift:7135-7206`, [`09_DUPLICATIONS.md`](09_DUPLICATIONS.md)).
8. **Écart entre PR #100/#101 et la cible Master Prompt §§7, 14, 22A.7** : l'icône dynamique automatique `CertigoIconStreakAtRisk` (`CertigoAppIconSelection.swift:6-35`) et le wording « Série en danger » devront être alignés sur le modèle **Rythme hebdomadaire sans culpabilisation** (§7, §9, DR-001/DR-005).
9. **Absence totale d'haptique (`PrismHapticToken`), de sons (`PrismSoundToken`) et de `XCUITest`** : 0 appel `sensoryFeedback` / Core Haptics dans `apps/apple/` ([`06_MOTION_HAPTICS.md`](06_MOTION_HAPTICS.md)) et aucune cible `XCUITest` ni `performAccessibilityAudit()` ([`07_ACCESSIBILITY.md`](07_ACCESSIBILITY.md), [`08_TESTS.md`](08_TESTS.md)).
10. **Contrats serveur et sécurité locale solides à préserver** : 24 endpoints HTTP typés, `SubmissionStore` idempotent, `FileProtectionPolicy`, `CredentialVault` Keychain, MSAL CIAM avec chemin de locataire explicite (`MSALAuthenticationProvider.swift:81-97`), et purge complète lors de `AccountDeletion` ([`10_BUSINESS_LOGIC_CONTRACTS.md`](10_BUSINESS_LOGIC_CONTRACTS.md)).

---

## 4. Top 5 des risques

| ID | Risque | Prob. × Impact | Mitigation (Phase cible) |
|---|---|---|---|
| **R-01** | Casse des garde-fous Python (`test_native_source_membership.py`, `test_native_prism_presentation.py`) lors du découpage de `CertigoNativeApp.swift` | Élevée × Élevé | Découpage chirurgical en 12 fichiers en Phase 1 avec mise à jour atomique de `project.pbxproj` et des tests Python (DR-001). |
| **R-02** | Non-conformité de marque / App Store Review (4.1 / 5.2) tant que `NativeCertificationCrest` et les logos redessinés restent affichés | Moyenne × Critique | Basculer vers `BrandLabel` + `BrandFallbackMark` dès l'étape **2B** (DR-006, DR-010) et exclure tout actif tiers des captures App Store. |
| **R-03** | Troncature Dynamic Type AX3/AX5 et cibles tactiles `< 44×44 pt` sur les grilles Bento, puces et cartes compactes | Élevée × Moyen | Remplacer les tailles fixes et `lineLimit(1)` par `PrismText` + `ViewThatFits`/`AnyLayout` et `PrismSize.minTouch = 44` en Phases 1–3. |
| **R-04** | Exposition accidentelle du mode Démo ou du connecteur développeur en build de distribution | Moyenne × Élevé | Isoler strictement derrière `#if DEBUG` et `FeatureFlags` en Phase 1 / Phase 3 (DR-009). |
| **R-05** | Retard d'obtention des autorisations écrites de Niveau 2 (Microsoft 365, GitHub, AWS hors schémas) | Élevée × Faible | Architecture `BrandRegistry` conçue pour afficher `BrandFallbackMark` par défaut sans bloquer le code, puis activer l'icône par simple mise à jour de `brand-manifest.json` (DR-010). |

---

## 5. Décisions requises avant la Phase 1 (`DR-001` à `DR-010`, triées par urgence)

Détail complet dans [`13_RISKS_AND_DECISIONS.md`](13_RISKS_AND_DECISIONS.md) :
1. **DR-001 (Bloquante Phase 1)** : Acter que `H4` (`colorSchemeContrast`) est déjà corrigée sur `main` (`778f9c24`), figer `778f9c24` comme tag `transform-baseline`, et autoriser l'adaptation coordonnée de `test_native_source_membership.py` / `test_native_prism_presentation.py` lors du découpage de `CertigoNativeApp.swift` en Phase 1.
2. **DR-007 (Bloquante Phase 1)** : Valider l'outil de tests de snapshots visuels (`ImageRenderer` natif SwiftUI + comparaison PNG déterministe sans dépendance tierce) et le linter `ArchitectureTests` (§38.2).
3. **DR-009 (Bloquante Phase 1 / Phase 3)** : Exclure le mode Démo fictif et le connecteur développeur des builds `Release` / `Distribution` (`#if DEBUG` + `D-1`).
4. **DR-002 (Avant Phase 1 / Phase 3)** : Cible de déploiement iOS — conserver `iOS 17.0` avec `#available(iOS 26, *)` pendant la transition ou relever immédiatement à `iOS 26.0`.
5. **DR-006 (Bloquante Étape 2B)** : Retrait de `NativeCertificationCrest`, `NativeEcosystemEmblem`, `NativeMicrosoftVendorBadge` et des mascottes dérivées d'icônes Azure au profit de `BrandAssets` / `BrandFallbackMark`.
6. **DR-010 (Bloquante Étape 2B)** : Approbation du programme d'icônes officielles (§22A) et envoi par le propriétaire des 4 courriels de demande d'autorisation Niveau 2 (Microsoft, GitHub, AWS, CNCF) préparés dans [`13_RISKS_AND_DECISIONS.md`](13_RISKS_AND_DECISIONS.md).
7. **DR-005 (Avant Phase 3 / Phase 7)** : Retrait côté UI de l'XP visible, des niveaux, de la copie « Série en danger » et de l'icône automatique `streakAtRisk` au profit du **Rythme hebdomadaire** (`rhythm.v1`).
8. **DR-004 (Avant Phase 4 / Phase 5)** : Politique de latence du feedback (notation serveur autoritative ≤ 1 s en ligne ; mise en file honnête hors ligne sans exposer la clé de correction).
9. **DR-008 (Avant Phase 1 / Phase 3)** : Pipeline d'analytics produit (`AnalyticsClient` vers le conteneur `events` existant du backend, sans SDK tiers, avec consentement explicite).
10. **DR-003 (Avant Phase 1)** : Gel immédiat de l'app Flutter (`apps/mobile`, `packages/prism_ui`) comme archive de référence en lecture seule.

---

## 6. Recommandation GO / NO-GO pour la Phase 1

**Statut (`2026-10-22`) : `GO VALIDÉ PAR LE PROPRIÉTAIRE POUR LA PHASE 1`** — Toutes les décisions **DR-001 à DR-010** ont été tranchées et enregistrées avec le statut `APPROVED` dans `docs/transformation/decisions/DR-001.md` à `DR-010.md` et `13_RISKS_AND_DECISIONS.md` :
- **DR-001 (`APPROVED`)** : Figer `778f9c24` comme baseline (`transform-baseline`) et découper `CertigoNativeApp.swift` en 12 fichiers en Phase 1.
- **DR-002 (`APPROVED`)** : **Passer immédiatement la cible minimale à `iOS 26.0` (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`)**.
- **DR-003 (`APPROVED`)** : Geler Flutter (`apps/mobile`, `packages/prism_ui`) en lecture seule et supprimer après la Phase 11.
- **DR-004 (`APPROVED`)** : Notation 100 % serveur + file hors ligne sans clé exposée.
- **DR-005 (`APPROVED`)** : **Conserver la série quotidienne et l'icône « Série en danger » (`streakAtRisk`) par défaut**.
- **DR-006 (`APPROVED`)** : Remplacer les blasons/logos maison par `BrandLabel` / `BrandFallbackMark` en étape 2B.
- **DR-007 (`APPROVED`)** : `ImageRenderer` natif sans dépendance + `ArchitectureTests`.
- **DR-008 (`APPROVED`)** : Pipeline interne CertiGo (`AnalyticsClient` → Cosmos `events`) sans SDK tiers + consentement explicite.
- **DR-009 (`APPROVED`)** : Démo et connecteur réservés à `#if DEBUG`, Mode Invité réel en prod.
- **DR-010 (`APPROVED`)** : Importer le Niveau 1 en étape 2B (confirmation « J'accepte » validée) et utiliser `BrandFallbackMark` pour le Niveau 2.
- La base technique est saine (`187/187` tests `CertigoKit` verts sans warning, `H4` déjà corrigée sur `main`, `project_state.py --check` vert, contrats serveur et sécurité locale robustes).
- **Phase 1 (Prism foundations) autorisée à démarrer immédiatement.**

---

## 7. Contrôle de conformité Git (lecture seule stricte)

### `git status --porcelain` (avant commit sur `transform/phase-0-audit`)
```text
?? docs/transformation/phase-0/00_SUMMARY.md
?? docs/transformation/phase-0/01_REPOSITORY_MAP.md
?? docs/transformation/phase-0/02_BASELINE.md
?? docs/transformation/phase-0/03_SCREENS_AND_ROUTES.md
?? docs/transformation/phase-0/04_PRISM_TOKENS_COMPONENTS.md
?? docs/transformation/phase-0/05_HARDCODED_VALUES.md
?? docs/transformation/phase-0/06_MOTION_HAPTICS.md
?? docs/transformation/phase-0/07_ACCESSIBILITY.md
?? docs/transformation/phase-0/08_TESTS.md
?? docs/transformation/phase-0/09_DUPLICATIONS.md
?? docs/transformation/phase-0/10_BUSINESS_LOGIC_CONTRACTS.md
?? docs/transformation/phase-0/11_CURRENT_TO_TARGET_MAP.md
?? docs/transformation/phase-0/12_MIGRATION_PLAN.md
?? docs/transformation/phase-0/13_RISKS_AND_DECISIONS.md
?? docs/transformation/phase-0/14_BRAND_ASSETS_AUDIT.md
?? docs/transformation/phase-0/brand_references.csv
?? docs/transformation/phase-0/hardcoded_values.csv
```

### `git diff --stat main...HEAD`
Aucun fichier existant du dépôt n'a été modifié, renommé, déplacé ou supprimé (`0` fichier existant touché ; 100 % des ajouts sont confinés sous `docs/transformation/phase-0/`).

---

PHASE 0 TERMINÉE — EN ATTENTE DE VALIDATION. AUCUNE MODIFICATION DE CODE EFFECTUÉE.
