# Fiche App Store Connect & TestFlight — CertiGo (`com.certigo.mobileapp`)

Ce document consigne la configuration complète, vérifiée et publiée sur **App Store Connect** pour **CertiGo** (Version iOS `1.1`, équipe Apple Developer `FFQPC7NC68`, App Store Connect ID effectif `6786861081`).

---

## 1. Identifiants App Store Connect

| Ressource | Identifiant App Store Connect | Détail |
|---|---|---|
| **Application (`apps`)** | `6786861081` | Nom : `CertiGo` • Bundle ID : `com.certigo.mobileapp` • SKU : `CERTIGO001` |
| **App Info (`appInfos`)** | `43d09c74-9056-426b-a286-eed982a02d85` | Catégorie principale : `EDUCATION` • Catégorie secondaire : `PRODUCTIVITY` • Classification : `4+` (`FOUR_PLUS`) |
| **App Info Localization (`fr-FR`)** | `92f84b84-492b-48dc-8eca-f2d131143150` | Nom : `CertiGo` • Sous-titre : `Certifications Cloud & IA` (25 car.) |
| **App Info Localization (`en-US`)** | `6b67c306-14e4-46ca-aebb-62ed0ec13b46` | Nom : `CertiGo` • Sous-titre : `Cloud, AI & IT Exam Prep` (24 car.) |
| **App Store Version (`1.1`)** | `4b2df4af-67c7-413e-9b2f-109f2d350411` | Plateforme : `IOS` • Copyright : `© 2026 CertiGo. Tous droits réservés.` |
| **Version Localization (`fr-FR`)** | `c3aff270-477d-4e18-b179-9d0189172263` | Promo (163 car.), Description (avec moteur haptique Core Haptics), Keywords (99 car.), URLs HTTPS |
| **Version Localization (`en-US`)** | `28664fa1-d05c-4ae2-bd16-73f863c2e36d` | Promo (165 car.), Description (avec moteur haptique Core Haptics), Keywords (96 car.), URLs HTTPS |
| **App Store Review Detail** | `5066c85d-11fd-4ec5-962a-859f62971812` | Contact complet + instructions de test immédiat sans compte requis (`demoAccountRequired: false`) |
| **Subscription Group (`CertiGo PRO`)** | `22537514` | Abonnements : `CertiGo PRO Mensuel` (`6829772138`, `com.certigo.mobileapp.pro.monthly`) & `CertiGo PRO Annuel` (`6829772215`, `com.certigo.mobileapp.pro.annual`) |

---

## 2. Tarifs, Disponibilité & Confidentialité (App Privacy)

- **Grille tarifaire (`appPriceSchedules`)** : **Gratuit (`Free / $0.00`)** configuré sur le territoire de base `FRA` et répercuté automatiquement sur les **175 pays et régions**.
- **Disponibilité (`appAvailabilities`)** : disponible dans les **175 territoires** App Store.
- **Confidentialité (`appDataUsagesPublishState/6786861081`)** :
  - État : **`published: true`**
  - URL de politique de confidentialité : `https://www.certigo-app.com/privacy-policy/` (HTTP 200)
  - URL de suppression de compte : `https://www.certigo-app.com/account-deletion/` (HTTP 200)
  - Déclarations publiées (`No Tracking`) : `NAME`, `EMAIL_ADDRESS`, `USER_ID`, `PRODUCT_INTERACTION`, `CRASH_DATA`, `PERFORMANCE_DATA`, `OTHER_DIAGNOSTIC_DATA` (finalités `APP_FUNCTIONALITY` et `ANALYTICS`, aucun suivi publicitaire tiers).

---

## 3. Captures d'Écran Marketing Minimalistes (6 Slides FR-FR & EN-US)

Conformément à la direction artistique **Page 17 / Page 18 Figma** (minimalisme textuel strict : badge court de 2–3 mots + titre percutant de 3 à 5 mots, aucun sous-texte bavard, cartes d'une seule ligne dans les mockups + mise en avant des boutons coussins 3D et des vibrations Core Haptics), 6 planches marketing sont générées de manière déterministe en **PNG 24-bit RGB sans canal alpha** par `tools/appstore_connect/generate_appstore_screenshots.py` :

| # | Slug | Badge FR / EN | Titre FR (3–4 mots) | Titre EN (3–4 mots) |
|---|---|---|---|---|
| 1 | `01_parcours_34x` | `N°1 CLOUD & IA` / `#1 CLOUD & AI` | **Certifié 3,4× plus vite.** | **Get certified 3.4× faster.** |
| 2 | `02_cartes_declic` | `CARTES DÉCLIC 15S` / `15S VISUAL CARDS` | **L'architecture Cloud en 15 secondes.** | **Cloud architecture in 15 seconds.** |
| 3 | `03_cloud_shell_cli` | `CLOUD SHELL CLI` / `CLOUD SHELL CLI` | **Vrai Terminal Cloud Shell.** | **Real Cloud Shell Terminal.** |
| 4 | `04_coach_ia_examen` | `COACH IA & EXAMEN` / `AI COACH & EXAM` | **Coach IA & Examen Blanc.** | **AI Coach & Mock Exam.** |
| 5 | `05_widgets_mascotte` | `WIDGETS & MASCOTTE` / `WIDGETS & MASCOT` | **Une habitude sur mesure.** | **Build a daily habit.** |
| 6 | `06_catalogue_multicloud` | `+15 CERTIFICATIONS` / `15+ CERTIFICATIONS` | **Azure, AWS, GCP, Kubernetes & IA.** | **Azure, AWS, GCP, Kubernetes & AI.** |

### Sets d'captures d'écran uploadés sur App Store Connect (48 captures au total)

| Locale | Display Type App Store Connect | Set ID | Résolution uploadée | Nombre |
|---|---|---|---|---|
| `fr-FR` | `APP_IPHONE_67` (iPhone 6.9" / 6.7") | `528bd95c-9101-4b32-954b-5f2709b279c3` | `1320×2868` | 6 / 6 |
| `fr-FR` | `APP_IPHONE_65` (iPhone 6.5") | `b1b124d7-5ce6-4d10-9ab7-48ecaf1c7381` | `1284×2778` | 6 / 6 |
| `fr-FR` | `APP_IPHONE_61` (iPhone 6.3" / 6.1" Dynamic Island) | `82e6fab7-b1c1-4822-803a-c8e45f1a6e6a` | `1206×2622` | 6 / 6 |
| `fr-FR` | `APP_IPAD_PRO_3GEN_129` (iPad Pro 13" / 12.9") | `4c91a3c7-729e-4777-bfa1-aec48aa14c74` | `2064×2752` | 6 / 6 |
| `en-US` | `APP_IPHONE_67` (iPhone 6.9" / 6.7") | `af865ae8-0b35-44f7-b5be-f084e1c5cc1b` | `1320×2868` | 6 / 6 |
| `en-US` | `APP_IPHONE_65` (iPhone 6.5") | `9a3b80b3-eb38-4a9a-929e-74ca80645fa0` | `1284×2778` | 6 / 6 |
| `en-US` | `APP_IPHONE_61` (iPhone 6.3" / 6.1" Dynamic Island) | `7374f163-5a0c-4493-8f86-8646b873fe63` | `1206×2622` | 6 / 6 |
| `en-US` | `APP_IPAD_PRO_3GEN_129` (iPad Pro 13" / 12.9") | `ab63a65b-7325-4d48-9510-b8b473c0f376` | `2064×2752` | 6 / 6 |

---

## 4. Régénération Reproductible

Pour régénérer les 72 captures d'écran (6 slides × 2 locales × 6 résolutions iPhone/iPad) localement hors de l'arbre Git :

```powershell
python tools\appstore_connect\generate_appstore_screenshots.py --output artifacts\appstore_screenshots
```
