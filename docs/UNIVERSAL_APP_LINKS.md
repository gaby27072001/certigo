# Universal Links iOS et Android App Links

Statut : **contrats et configuration inerte uniquement**. Aucun changement DNS,
Apple Developer, Google Play ou déploiement n'est effectué par ce document.

## Décision de domaine

Le domaine canonique cible est `certigo.app`.

- Au 2026-08-19, le domaine est délégué à Cloudflare
  (`nicolas.ns.cloudflare.com`, `raegan.ns.cloudflare.com`) et répond en HTTPS.
- Le contrôle de la zone DNS n'est pas prouvé par le dépôt et doit être confirmé
  avant activation.
- Le dépôt publie actuellement la politique de confidentialité à l'URL de secours
  `https://gchambaud_microsoft.github.io/Certigo/privacy-policy/`. L'API Pages du
  dépôt ne retourne toutefois aucun site configuré au moment de cette inspection.

Le fallback Pages partageable est
`https://gchambaud_microsoft.github.io/Certigo/...`, mais il ne peut devenir un
Universal/App Link vérifié que si le site Pages **utilisateur** sert les fichiers
à la racine de l'origine :

- `https://gchambaud_microsoft.github.io/.well-known/apple-app-site-association`
- `https://gchambaud_microsoft.github.io/.well-known/assetlinks.json`

Un site Pages de projet sous `/Certigo` ne peut pas, à lui seul, publier ces deux
fichiers à la racine. Sans ce prérequis, le fallback reste un lien web normal.

## Contrat des routes

| URL HTTPS | Route interne | Authentification |
|---|---|---|
| `/learn/{trackId}/{lessonId}` | `/lesson/{trackId}/{lessonId}` | requise |
| `/assignments/{id}` | `/assignments/{id}` | requise |
| `/achievements/{id}` | `/achievements/{id}` | requise |
| `/account-deletion/` | `/account-deletion/` | publique |

Les identifiants acceptent uniquement lettres ASCII, chiffres, `.`, `_` et `-`,
sur 1 à 128 caractères. Le parseur refuse HTTP, les ports explicites, les
userinfo, les domaines suffixés, les query strings, les fragments, les segments
encodant `/` ou `\`, et les chemins non déclarés. Une destination protégée
retourne une décision `requireAuthentication` avec une route interne construite
par l'app ; elle ne navigue jamais directement avant authentification.

Le callback OIDC existant `certigo://auth/` reste indépendant et inchangé.

## Feature flags et coordination router

Deux verrous sont désactivés par défaut :

1. Android utilise `links-disabled.invalid` et iOS n'assigne pas encore
   `Runner.entitlements` à `CODE_SIGN_ENTITLEMENTS`.
2. Le parseur Dart utilise
   `--dart-define=CERTIGO_HTTPS_LINKS_ENABLED=false` par défaut.

La PR #297 réécrit `apps/mobile/lib/app/router.dart` et
`apps/mobile/lib/app/auth_redirect.dart`; la PR #289 modifie l'App Shell. Pour
éviter un conflit et un contournement involontaire du garde d'auth, ce spike ne
modifie aucun de ces fichiers. Après stabilisation de #297, une PR d'intégration
doit :

1. enregistrer les routes internes manquantes `assignments/{id}`,
   `achievements/{id}` et `account-deletion/` ;
2. conserver la destination protégée en attente pendant le login, sans accepter
   de cible arbitraire issue d'une query string ;
3. laisser `resolveAuthRedirect` décider de l'accès après restauration de
   session et onboarding ;
4. brancher le flux initial et les liens reçus à chaud sur `DeepLinkPolicy` ;
5. activer le dart-define uniquement après les tests d'intégration.

## Génération des fichiers d'association

Le générateur n'a aucune valeur d'identité par défaut, hormis le bundle/package
public confirmé `com.certigo.mobileapp`. Il échoue si l'Apple Team ID ou au moins
une empreinte SHA-256 Android vérifiée manque.

```powershell
python tools\generate_link_associations.py `
  --domain certigo.app `
  --apple-team-id <APPLE_TEAM_ID_VERIFIE> `
  --android-sha256 <SHA256_PLAY_APP_SIGNING_VERIFIE> `
  --output-dir build\link-associations
```

Pour préparer le fallback Pages, sans le publier :

```powershell
python tools\generate_link_associations.py `
  --domain gchambaud_microsoft.github.io `
  --path-prefix /Certigo `
  --apple-team-id <APPLE_TEAM_ID_VERIFIE> `
  --android-sha256 <SHA256_PLAY_APP_SIGNING_VERIFIE> `
  --output-dir build\link-associations
```

Les sorties sont placées sous
`<output-dir>\<domain>\.well-known\`. Ne jamais remplacer l'empreinte de
signature Play par celle de la clé d'upload.

## Checklist manuelle d'activation

### 1. Propriété et hébergement

- [ ] Confirmer avec le propriétaire du compte Cloudflare que l'équipe contrôle
      la zone `certigo.app`.
- [ ] Décider que l'origine canonique est exactement `https://certigo.app`
      (sans `www`) et conserver ce host dans les builds iOS et Android.
- [ ] Préparer une page web pour chaque route, en particulier
      `/account-deletion/`, afin que les utilisateurs sans app aient un fallback.
- [ ] Générer les deux fichiers avec les identifiants vérifiés.
- [ ] Publier `apple-app-site-association` sans extension et `assetlinks.json`
      sous `https://certigo.app/.well-known/`.
- [ ] Vérifier que les deux URL répondent `200`, sans redirection, avec
      `Content-Type: application/json` et un certificat TLS valide.
- [ ] Si GitHub Pages héberge le domaine personnalisé, configurer le custom
      domain et `Enforce HTTPS` dans Pages seulement après validation DNS.

### 2. Apple Developer et build iOS

- [ ] Lire le **Team ID** dans Apple Developer > Membership ; ne pas utiliser
      l'identifiant App Store ni l'UUID d'un profil.
- [ ] Ouvrir Certificates, Identifiers & Profiles > Identifiers >
      `com.certigo.mobileapp`, puis activer **Associated Domains**.
- [ ] Régénérer les profils de provisioning concernés et les synchroniser avec
      le mécanisme de signature existant.
- [ ] Définir les build settings `CODE_SIGN_ENTITLEMENTS=Runner/Runner.entitlements`
      et `CERTIGO_APP_LINKS_HOST=certigo.app` dans la configuration approuvée
      (Xcode ou `xcargs` Fastlane). Ne pas les assigner avant disponibilité des
      nouveaux profils.
- [ ] Construire avec
      `--dart-define=CERTIGO_HTTPS_LINKS_ENABLED=true` seulement après
      intégration router.
- [ ] Vérifier l'entitlement du binaire signé avec
      `codesign -d --entitlements :- <chemin-vers-Runner.app>`.
- [ ] Installer le build sur un appareil, placer une URL canonique dans Notes ou
      Messages, puis la toucher. Tester aussi
      `xcrun simctl openurl booted https://certigo.app/learn/<track>/<lesson>`.
- [ ] Vérifier le cache Apple avec
      `https://app-site-association.cdn-apple.com/a/v1/certigo.app`.

### 3. Google Play et build Android

- [ ] Lire l'empreinte **SHA-256 du certificat de signature d'application** dans
      Play Console > Setup > App integrity. Ne pas utiliser la clé d'upload.
- [ ] Régénérer `assetlinks.json` avec toutes les empreintes réellement
      distribuées si une rotation de clé est active, puis republier le fichier.
- [ ] Définir avant le build :
      `$env:ORG_GRADLE_PROJECT_CERTIGO_APP_LINKS_HOST='certigo.app'`.
- [ ] Pour le fallback Pages uniquement, définir aussi
      `$env:ORG_GRADLE_PROJECT_CERTIGO_APP_LINKS_PATH_PREFIX='/Certigo'`; laisser
      cette propriété vide pour `certigo.app`.
- [ ] Construire avec
      `--dart-define=CERTIGO_HTTPS_LINKS_ENABLED=true` seulement après
      intégration router.
- [ ] Installer le build distribué par Play ou signé avec le certificat déclaré.
- [ ] Forcer et inspecter la vérification :
      `adb shell pm verify-app-links --re-verify com.certigo.mobileapp`, puis
      `adb shell pm get-app-links com.certigo.mobileapp`.
- [ ] Tester chaque route avec
      `adb shell am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://certigo.app/learn/<track>/<lesson>"`.

### 4. Critères avant bascule

- [ ] Les tests parseur, auth, open redirect et configurations natives sont verts.
- [ ] Le router final de #297 est intégré sans affaiblir ses gardes.
- [ ] Un lien protégé reçu déconnecté reprend uniquement la route interne validée
      après authentification ; aucune URL externe n'est conservée.
- [ ] `/account-deletion/` reste accessible sans session.
- [ ] Les quatre routes ouvrent l'app installée et une page web utile sinon.
- [ ] Le callback `certigo://auth/` fonctionne toujours sur iOS et Android.
