# Universal Links iOS et Android App Links

Statut : **runtime câblé, feature flag désactivé et configuration native inerte**.
Aucun changement DNS, Apple Developer, Google Play ou déploiement n'est effectué
par ce document. La PR doit rester en draft tant que le contrôle DNS, le Team ID
Apple et les empreintes Play App Signing ne sont pas confirmés.

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
| `/account-deletion` | `/account-deletion` | publique |

Les identifiants acceptent uniquement lettres ASCII, chiffres, `.`, `_` et `-`,
sur 1 à 128 caractères. Le parseur refuse HTTP, les ports explicites, les
userinfo, les domaines suffixés, les query strings, les fragments, les segments
encodant `/` ou `\`, et les chemins non déclarés. Une destination protégée
retourne une décision `requireAuthentication` avec une route interne construite
par l'app ; elle ne navigue jamais directement avant authentification.

Le callback OIDC existant `certigo://auth/` reste indépendant et inchangé :
Android continue de le confier à `RedirectUriReceiverActivity` de
`flutter_appauth`, tandis que `MainActivity` ne déclare que le schéma HTTPS.

## Feature flags et coordination router

Deux verrous restent désactivés par défaut :

1. Android utilise `links-disabled.invalid` et iOS n'assigne pas encore
   `Runner.entitlements` à `CODE_SIGN_ENTITLEMENTS`.
2. Le coordinateur Dart utilise
   `--dart-define=CERTIGO_HTTPS_LINKS_ENABLED=false` par défaut.

Le routeur final issu des PR #297 et #289 est intégré directement :

1. Flutter remet les liens initiaux et reçus à chaud à `GoRouter` ;
2. `DeepLinkRouterCoordinator` accepte uniquement une destination construite par
   `DeepLinkPolicy`, jamais une URL ou une query string fournie par l'appelant ;
3. une destination protégée reste en mémoire jusqu'à la fin de
   l'authentification **et** de l'onboarding, puis est consommée une seule fois ;
4. `resolveAuthRedirect` conserve ses invariants et autorise explicitement la
   page publique `/account-deletion` ;
5. `/learn/{trackId}/{lessonId}` ouvre la leçon, `/achievements/{id}` ouvre et
   met le succès demandé en tête, et `/assignments/{id}` affiche une surface
   honnête tant qu'aucun contrat métier/API d'affectation n'existe ;
6. un URI `certigo://auth/` est ignoré par le coordinateur HTTPS.

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
      `/account-deletion`, afin que les utilisateurs sans app aient un fallback.
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
      `--dart-define=CERTIGO_HTTPS_LINKS_ENABLED=true` seulement après validation
      du domaine, de l'AASA et du profil signé.
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
      `--dart-define=CERTIGO_HTTPS_LINKS_ENABLED=true` seulement après validation
      de `assetlinks.json` et du certificat de signature distribué.
- [ ] Installer le build distribué par Play ou signé avec le certificat déclaré.
- [ ] Forcer et inspecter la vérification :
      `adb shell pm verify-app-links --re-verify com.certigo.mobileapp`, puis
      `adb shell pm get-app-links com.certigo.mobileapp`.
- [ ] Tester chaque route avec
      `adb shell am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://certigo.app/learn/<track>/<lesson>"`.

### 4. Critères avant bascule

- [x] Les tests parseur, auth, open redirect et configurations natives sont verts.
- [x] Le router final de #297 est intégré sans affaiblir ses gardes.
- [x] Un lien protégé reçu déconnecté reprend uniquement la route interne validée
      après authentification ; aucune URL externe n'est conservée.
- [x] `/account-deletion` reste accessible sans session.
- [ ] Les quatre routes ouvrent l'app installée et une page web utile sinon.
- [ ] Le callback `certigo://auth/` fonctionne toujours sur iOS et Android.
