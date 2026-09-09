# Crash reporting mobile iOS — Sentry

Ce runbook est la source opérateur pour les builds iOS internes et TestFlight.
Le système principal est **Sentry Flutter + Sentry Cocoa**. Xcode Organizer
reste un complément Apple opt-in, soumis au partage des diagnostics par le
testeur et à un délai de disponibilité ; il ne remplace pas Sentry.

## 1. Décision et garanties

Application Insights reste le système de télémétrie du backend. Un relais Dart
vers Azure n'a pas été retenu : il ne peut pas, à lui seul, installer un handler
de signaux/exceptions iOS, persister un crash fatal après l'arrêt du processus
et consommer les dSYM pour symboliser le rapport.

Le SDK Sentry retenu fournit les trois capacités obligatoires :

1. `sentry_flutter` initialise Sentry Cocoa avant le bootstrap applicatif dans
   la même zone que le binding Flutter et `runApp` ; un canal iOS détenu par
   l'application vérifie ensuite `SentrySDK.isEnabled` avant d'activer le sink
   distant ;
2. un crash iOS fatal est écrit sur disque par le SDK natif, puis l'enveloppe est
   envoyée au lancement suivant ;
3. Codemagic upload les dSYM de l'archive Xcode avec `sentry-cli
   debug-files upload --wait`, ce qui permet la symbolication côté Sentry.

Références fournisseur :

- [Sentry Flutter — debug symbols](https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/)
- [Sentry Apple — upload des dSYM](https://docs.sentry.io/platforms/apple/guides/ios/dsym/)
- [Sentry Flutter — données personnelles](https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/)

Les erreurs Dart non gérées restent capturées par les hooks provider-agnostic
`FlutterError.onError`, `PlatformDispatcher.onError` et `runZonedGuarded`. En
développement local, Sentry est désactivé par défaut et le sink nettoyé
`LoggingCrashReporter` reste utilisé.

## 2. Action manuelle unique avant la première Alpha

> **Action restante indispensable :** un opérateur disposant des accès Sentry
> et Codemagic doit exécuter une fois la checklist ci-dessous. Aucun compte,
> DSN ou token réel n'est commité.

1. Créer un projet **Flutter** Sentry pour Certigo et relever :
   `SENTRY_DSN`, `SENTRY_ORG` et `SENTRY_PROJECT`.
2. Dans les réglages Sentry du projet :
   - activer **Prevent Storing of IP Addresses** ;
   - conserver le scrubbing serveur des champs sensibles et ajouter les motifs
     `authorization`, `token`, `password`, `secret`, `api_key`, `email` ;
   - activer **Spike Protection** et une limite de débit sur la clé DSN ;
   - désactiver le pay-as-you-go et fixer l'alerte/quota d'erreurs au plafond
     budgétaire accepté pour l'Alpha ;
   - choisir la durée de rétention minimale compatible avec le support Alpha.
3. Créer un token d'organisation Sentry dédié à Codemagic, limité aux droits
   nécessaires à la lecture de l'organisation et à l'upload des fichiers de
   debug/releases. Ne pas réutiliser un token personnel.
4. Dans le groupe Codemagic `certigo_mobile_config`, ajouter :

   | Variable | Secure | Destination |
   |---|---:|---|
   | `SENTRY_DSN` | non | `--dart-define`, donc présent dans le binaire |
   | `SENTRY_ORG` | non | CLI Codemagic uniquement |
   | `SENTRY_PROJECT` | non | CLI Codemagic uniquement |
   | `SENTRY_AUTH_TOKEN` | **oui** | CLI Codemagic uniquement, jamais `--dart-define` |

5. Exécuter le smoke test du §6 et consigner les deux liens d'événements Sentry
   dans la checklist de release.

Le DSN est une clé publique d'ingestion, mais il reste injecté par configuration
pour permettre rotation et séparation des environnements. Le token d'upload est
le seul secret Sentry et doit être marqué **Secure** dans Codemagic.

## 3. Contrat de build fail-closed

Tous les workflows Codemagic qui produisent un IPA (`ios-release`,
`ios-release-dry`, `ios-crash-smoke`) imposent :

- `CRASH_REPORTING_ENABLED=true` et `CRASH_REPORTING_REQUIRED=true` ;
- un DSN HTTPS valide, un org, un projet et un token non vides ;
- `SENTRY_RELEASE=com.certigo.mobileapp@<version>+<build>` ;
- `SENTRY_DIST=<build>` et l'environnement Sentry égal à `CERTIGO_ENV` ;
- au moins un bundle `.dSYM` dans l'archive Xcode ;
- un upload `sentry-cli debug-files upload --wait` réussi ;
- une archive `Certigo-<version>-<build>-dSYMs.zip` conservée dans les artefacts.

Le `sentry_dart_plugin` découvre les fichiers et installe un `sentry-cli` dont le
checksum est vérifié. Le pipeline rejoue ensuite directement l'upload CLI :
cette seconde commande est le gate autoritaire, car le plugin peut journaliser
certains échecs CLI sans les propager comme code de sortie non nul.

La CI de pull request `.github/workflows/ci-mobile.yml` ne possède aucun secret
Sentry et n'upload aucun symbole. Les uploads n'ont lieu qu'après création d'un
IPA sur Codemagic.

## 4. Confidentialité et bornes

Configuration SDK :

- `sendDefaultPii=false` ;
- aucun `SentryUser`, token, e-mail, corps ou en-tête HTTP envoyé ;
- événements Dart reconstruits par allowlist avant envoi : type d'exception,
  pile nettoyée, adresses de symbolication, version/build/environnement et deux
  tags techniques seulement ;
- breadcrumbs réduits à catégorie, type, niveau et horodatage ; message et
  données libres supprimés ;
- screenshots, view hierarchy, pièces jointes automatiques, logs et métriques
  désactivés ;
- session replay à `0`, tracing et profiling désactivés ;
- release health (`enableAutoSessionTracking`) désactivé : une session est
  émise à chaque passage avant/arrière-plan, **sans erreur ni crash**, alors que
  la politique de confidentialité publiée cadre Sentry sur les seuls « erreurs
  et crashs techniques ». Sur iOS elle est produite entièrement par Cocoa, donc
  elle échappe à l'allowlist, au scrubber et au limiteur de débit, et elle porte
  un `distinctId` persistant. C'était le seul flux Sentry qu'aucun code Certigo
  ne filtrait. Vérifié dans sentry-cocoa 8.58.4 : la capture watchdog/OOM n'en
  dépend pas (`SentryWatchdogTerminationTrackingIntegration.integrationOptions`
  ne combine que `EnableWatchdogTerminationTracking` et `EnableCrashHandler`).
  Contrepartie assumée : pas de taux de sessions sans plantage côté Sentry ;
  les événements de crash, eux, restent envoyés ;
- détection d'app hang désactivée hors périmètre ; terminaisons watchdog/OOM
  conservées comme crashs natifs pertinents ;
- collecte des requêtes échouées et breadcrumbs réseau désactivée ;
- maximum 30 enveloppes en cache hors ligne, file mémoire de 10 et 10 événements
  Dart par minute.

Les crashs natifs fatals sont capturés quand Dart n'est plus exécutable : ils ne
peuvent donc pas passer dans le scrubber Dart. Leur surface est réduite en amont
par `sendDefaultPii=false`, l'absence de user scope, la désactivation des
breadcrumbs automatiques/réseau et des pièces jointes, puis en aval par le
scrubbing et le blocage d'IP configurés au §2. Ne jamais inclure de donnée
utilisateur ou de secret dans un message de `fatalError`, assertion native ou
breadcrumb custom.

Il n'existe aucun endpoint anonyme Certigo à protéger. L'ingestion publique est
le DSN Sentry et bénéficie du schéma du SDK, des quotas fournisseur, de la Spike
Protection et de la limite de clé. Les tests ciblés injectent PII, URL, IP,
token, champs libres et rafale d'événements pour vérifier allowlist, redaction et
rate limiting.

## 5. Hors ligne et erreurs visibles

Sentry met en cache les événements quand le réseau est indisponible. Un crash
natif fatal est rejoué au lancement suivant ; laisser l'app ouverte après
reconnexion pour permettre l'envoi. Les 30 éléments maximum bornent le stockage
local et les événements les plus anciens peuvent être évincés.

Un build officiel ne démarre pas silencieusement sans crash reporting :

- une configuration compile-time invalide affiche `ConfigErrorApp` ;
- un échec d'initialisation Sentry, un canal natif indisponible ou un
  `SentrySDK.isEnabled == false` ferme le SDK partiellement initialisé, reste sur
  le sink local et affiche une erreur `SENTRY_INIT` ;
- l'absence de DSN/token/dSYM ou un upload refusé fait échouer Codemagic avant
  la publication TestFlight.

## 6. Smoke test volontaire TestFlight

Le workflow **`ios-crash-smoke`** est manuel, destructif et distribué uniquement
au groupe TestFlight **Internal Testers**.

1. Dans Codemagic, lancer `ios-crash-smoke`.
2. Vérifier dans les logs :
   - `Crash reporting configuration accepted` ;
   - au moins un dSYM détecté ;
   - `sentry-cli debug-files upload --wait` réussi ;
   - l'archive dSYM présente dans les artefacts.
3. Dans Sentry **Project Settings > Debug Files**, vérifier les UUID du build.
4. Installer la build depuis TestFlight. Noter les valeurs Release,
   Distribution et Environnement affichées.
5. Appuyer uniquement sur **Déclencher une erreur Dart non gérée**.
   Vérifier dans Sentry un événement `CrashSmokeTestDartError` avec
   `crash.source=zone`, la release/dist attendue et des frames lisibles.
6. Relancer l'app si nécessaire, puis appuyer uniquement sur
   **Déclencher un crash natif iOS**. L'app doit se terminer.
7. Relancer l'app avec le réseau disponible. Le SDK rejoue le crash persistant.
   Vérifier dans Sentry que :
   - l'événement natif porte la même release/dist ;
   - les frames Certigo/Runner sont symboliquées, sans `Missing dSYM` ;
   - aucun e-mail, token, URL complète, IP brute ou identifiant de compte
     n'apparaît dans l'événement ni les breadcrumbs.
8. Expirer la build destructive dans TestFlight après validation et consigner
   les deux événements dans la checklist Alpha.

Si le crash natif n'apparaît qu'avec des adresses hexadécimales, comparer ses
UUID à l'archive dSYM Codemagic puis relancer l'upload avec le même
`SENTRY_ORG`, `SENTRY_PROJECT` et le token sécurisé. Ne jamais copier le token
dans un ticket ou une commande committée.

Xcode Organizer peut être consulté en complément si le testeur a accepté le
partage Apple, mais son absence ou son délai ne bloque pas le diagnostic Sentry.
