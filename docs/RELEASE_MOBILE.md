# Release mobile — Pipeline & runbooks

Documentation opérationnelle pour publier les bêtas Microlingo.
**Priorité : Android d'abord, puis iOS.** Pipeline reproductible :
`code → build signée → upload beta store`.

> 🔐 **Aucun secret n'est committé.** Toutes les valeurs sensibles vivent dans
> les secrets GitHub Actions (ou en local dans des fichiers ignorés par git).
> Ce document ne contient que des **noms** de secrets et des **commandes**.

---

## 1. Vue d'ensemble

```
                    ┌─────────────────────────────────────────────────────┐
  git push / tag /  │  GitHub Actions (runner self-hosted Linux)          │
  Run workflow ────▶│  release-android.yml                                │
                    │   1. JDK 17 + SDK Android + Flutter 3.24.0           │
                    │   2. gates BLOQUANTS : flutter analyze + test        │
                    │   3. déchiffre keystore (secrets) → key.properties   │
                    │   4. flutter build appbundle (signé, versionné)      │
                    │   5. upload Google Play (piste internal/closed/…)    │
                    │   6. nettoyage du matériel de signature              │
                    └─────────────────────────────────────────────────────┘
```

| Élément | Valeur |
|---|---|
| App Flutter | `apps/mobile` |
| applicationId / bundle id | `com.microlingo.app` — ⚠️ **NON modifiable après le 1er upload Play** |
| Nom affiché | Microlingo |
| versionName | lu depuis `apps/mobile/pubspec.yaml` (`version:` → partie avant `+`) |
| versionCode / build number | `github.run_number` (auto-incrémenté), override possible |
| Workflows | `release-android.yml` (prêt), `release-ios.yml` (Phase iOS) |
| CI inchangée | `ci-mobile.yml` (format/analyze/test) — aucune régression |

> ⚠️ **`com.microlingo.app` est un placeholder explicite.** Il doit être confirmé
> **avant la toute première publication Play** : l'applicationId est définitif une
> fois la première build uploadée. S'il change, mettre à jour :
> `apps/mobile/android/app/build.gradle` (`applicationId`),
> `PLAY_PACKAGE_NAME` dans `release-android.yml`, et la fiche store.

---

## 2. Secrets GitHub Actions (à créer une fois)

`Settings → Secrets and variables → Actions → New repository secret`.

| Secret | Plateforme | Usage |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Android | Keystore upload (.jks) encodé base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Android | Mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | Android | Alias de la clé (ex : `upload`) |
| `ANDROID_KEY_PASSWORD` | Android | Mot de passe de la clé |
| `PLAY_SERVICE_ACCOUNT_JSON` | Android | JSON du compte de service Google Play |
| `IOS_*` / `APP_STORE_CONNECT_*` | iOS | Voir la section iOS (Phase iOS) |

> Tant que `PLAY_SERVICE_ACCOUNT_JSON` est absent, le workflow **construit quand
> même l'AAB signé** (téléchargeable en artefact) et **saute** proprement la
> publication.

---

## 3. Android

### 3.1 Pré-requis du runner self-hosted

Le runner `microlingo-ci` (Linux X64) doit disposer de Flutter/Dart (déjà requis
par la CI). Le workflow installe lui-même **JDK 17** et le **SDK Android**
(`android-actions/setup-android` + `sdkmanager`), donc aucune action manuelle
supplémentaire n'est nécessaire. L'egress internet passe par la NAT Gateway
`nat-microlingo` (voir README).

### 3.2 Générer le keystore upload (one-time, en local)

Le keystore **upload** signe l'AAB ; Google Play le re-signe ensuite avec la clé
d'application (Play App Signing). **Sauvegardez ce keystore et ses mots de passe
en lieu sûr** (sa perte est irréversible).

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### 3.3 Encoder et enregistrer les secrets Android

Encoder le keystore en base64 :

```bash
# Linux / macOS
base64 -w0 upload-keystore.jks > keystore.b64
```
```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Out-File keystore.b64 -NoNewline -Encoding ascii
```

Créer les secrets (via l'UI GitHub, ou `gh`) :

```bash
gh secret set ANDROID_KEYSTORE_BASE64   < keystore.b64
gh secret set ANDROID_KEYSTORE_PASSWORD --body '<mot_de_passe_keystore>'
gh secret set ANDROID_KEY_ALIAS         --body 'upload'
gh secret set ANDROID_KEY_PASSWORD      --body '<mot_de_passe_cle>'
```

> Supprimez ensuite `keystore.b64` du disque. Ne committez jamais le `.jks`
> (déjà couvert par `.gitignore`).

### 3.4 Configurer Google Play (one-time)

1. **Créer l'application** dans la [Google Play Console](https://play.google.com/console)
   avec le package `com.microlingo.app`.
2. **Activer Play App Signing** (proposé au 1er upload).
3. **Compte de service** : dans Google Cloud, créez un compte de service, générez
   une **clé JSON**. Dans la Play Console → *Configuration → accès à l'API* →
   liez le compte de service et accordez-lui au minimum le rôle permettant de
   *gérer les versions de test* (Release manager).
4. Enregistrer la clé JSON en secret :
   ```bash
   gh secret set PLAY_SERVICE_ACCOUNT_JSON < service-account.json
   ```
5. **Créer la piste "Test interne"** et y ajouter au moins une fois une release
   (la première peut devoir être faite manuellement depuis la console selon
   l'état d'enrôlement ; les suivantes passent par le workflow).

### 3.5 Runbook — Lancer une beta Android (manuel) ✅

1. Onglet **Actions** → workflow **release-android** → **Run workflow**.
2. Renseigner :
   - **track** : `internal` (puis `beta`/closed plus tard),
   - **version_name** : vide (= pubspec) ou ex. `0.1.0`,
   - **build_number** : vide (= numéro de run, auto-incrémenté),
   - **dry_run** : `false` (mettre `true` pour builder sans publier).
3. Le workflow exécute les **gates** (`analyze` + `test`), construit l'**AAB
   signé**, l'**uploade** sur la piste choisie, puis nettoie les secrets.
4. Dans la Play Console, ajouter les testeurs (e-mails ou liste) et partager le
   **lien d'opt-in** de la piste de test interne.
5. Les testeurs acceptent l'invitation puis installent depuis le lien.

### 3.6 Runbook — Release par tag

```bash
git tag v0.1.0
git push origin v0.1.0
```

→ déclenche `release-android` qui publie automatiquement sur la piste
**internal** (versionName = `0.1.0` déduit du tag).

### 3.7 Promouvoir Internal → Closed testing (beta)

- Soit relancer le workflow avec **track=`beta`** (closed),
- soit, dans la Play Console, **promouvoir** la release de la piste interne vers
  la piste fermée (recommandé pour réutiliser le même artefact validé).

---

## 4. iOS

Voir la section dédiée plus bas (renseignée en **Phase iOS**). En résumé : build
sur runner **macOS** (requis pour iOS ; les runners hébergés sont désactivés par
la politique EMU → un runner macOS self-hosted est nécessaire), signature via
**clé API App Store Connect**, distribution **TestFlight**.

---

## 5. Versioning

| Champ | Source | Règle |
|---|---|---|
| versionName | `pubspec.yaml` ou input/tag | Sémantique (`MAJEUR.MINEUR.CORRECTIF`) |
| versionCode (Android) | `github.run_number` ou input | **Strictement croissant** (exigé par Play) |

- Pour une nouvelle version publique, bumper `version:` dans
  `apps/mobile/pubspec.yaml` (ex. `0.1.0+1` → `0.2.0+1`).
- Le `build_number` réel en CI vient du run GitHub : il est **monotone** et évite
  les collisions de versionCode entre deux releases.

---

## 6. Rollback (Android)

Le versionCode étant strictement croissant, on ne « réinstalle » pas un ancien
code : on **arrête** la diffusion fautive et on **republie** une build saine.

1. **Stopper la diffusion** : Play Console → piste concernée → *Arrêter le
   déploiement* de la release problématique (la build précédente reste celle
   servie aux testeurs).
2. **Republier une version saine** : se placer sur le commit/tag connu-bon et
   relancer `release-android` (le `build_number` issu du run sera supérieur, donc
   accepté), ou promouvoir une release antérieure valide.
3. **Communiquer** aux testeurs si l'app était déjà installée.

> Astuce : conserver la correspondance `versionCode ↔ commit` via les artefacts
> du run et les release notes (`whatsnew`).

---

## 7. Checklist pré-release

- [ ] `ci-mobile` au vert sur la branche à publier (format/analyze/test).
- [ ] `version:` de `pubspec.yaml` à jour si nouvelle version publique.
- [ ] Notes de version `apps/mobile/distribution/android/whatsnew/*` actualisées.
- [ ] Secrets présents : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
      `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`.
- [ ] (1ère fois) App créée dans Play Console + piste de test interne existante.
- [ ] applicationId `com.microlingo.app` **confirmé** (définitif après 1er upload).
- [ ] Run de validation `dry_run=true` réussi (AAB signé produit).
- [ ] `docs/RELEASE_MOBILE.md` à jour.
