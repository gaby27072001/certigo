# Analyse de sécurité statique (SAST) du code Dart/Flutter — finding D10

> **Fait daté.** Outillage versionné le 2026-09-25 (PR 0 de la séquence ci-dessous). Le
> contrôle CI `Dart SAST / Security gate` n'existe qu'à partir de la fusion de la PR B.
> **Invalidé si** `.github/workflows/dart-sast.yml` cesse de lire règles, périmètre, baseline et
> verrou depuis le SHA de **base**, si `validate-workflow-security.mjs` cesse de lui imposer une
> forme relue de `.github/scripts/dart-sast-workflow-forms/`, ou si `dart-sast.mjs` cesse
> d'échouer sur une couverture incomplète.

## En une phrase

CodeQL ne sait pas lire le Dart (`.github/workflows/codeql.yml`). Le code mobile — jetons OIDC,
stockage sécurisé, appels d'API — est donc analysé par **Semgrep Community Edition**, avec
**35 règles écrites pour Certigo**, et le contrôle **échoue dès qu'une découverte nouvelle
apparaît**. Les découvertes déjà revues vivent dans une baseline datée et justifiée.

## Ce qui est analysé

Le périmètre (`.github/sast/scope.json`) est calculé à partir des fichiers **suivis par Git** :
tout `apps/mobile/` et `packages/`, plus tout fichier `.dart` du dépôt, moins les fichiers à
**extension** binaire (`binaryExtensions`) et les fixtures volontairement vulnérables de
`.github/sast/tests/`. Mesuré le 2026-10-04 sur `main` `23202dff` : **527 fichiers**, tous
analysés.

| Famille (`certigo-risk`) | Règles | Exemples de ce qui est détecté |
|---|---|---|
| `tls` | 7 | `badCertificateCallback`, `HttpOverrides.global`, URL `http://`, `allowInsecureConnections: true`, trafic en clair Android, CA utilisateur, ATS iOS désactivé |
| `logging` | 4 | jeton, mot de passe, cookie ou session vers `print`/`debugPrint`/`log`/Sentry/télémétrie ; `LogInterceptor` Dio qui journalise `Authorization` ; `sendDefaultPii` ; copie vers le presse-papiers |
| `storage` | 5 | secret dans `SharedPreferences` ou dans un fichier ; Keychain migrable (sans `_this_device`) ; stockage externe ; sauvegarde Android sans règles |
| `webview` | 4 | JavaScript actif, pont JavaScript, accès fichiers ou contenu mixte, URL chargée non littérale |
| `deeplink` | 8 | valeur d'un lien qui décide de la navigation (analyse de flux intra-fonction), `launchUrl` dynamique, écoute de liens entrants, identifiant non encodé dans un chemin d'API, liens Android non vérifiés, schémas personnalisés, `FlutterDeepLinkingEnabled` |
| `randomness` / `crypto` | 3 | `Random()` non cryptographique, MD5/SHA-1, mode ECB |
| `secrets` | 3 | littéral qui ressemble à un secret sous un nom de secret, clé privée, clé ou signature SAS Azure |
| `platform` | 1 | `android:debuggable="true"` |

La liste exacte est dans `.github/sast/rules/*.yaml` ; chaque règle porte sa CWE, sa référence
OWASP MASVS et son niveau de confiance.

## Ce que le scanner ne couvre pas (limites connues)

- **Pas d'analyse inter-fonctions.** Les règles lisent un appel à la fois ; la règle de flux
  (`dart-deeplink-untrusted-navigation`) suit une valeur à l'intérieur d'une fonction seulement.
  Un chemin d'API construit dans une variable puis passé au client n'est pas vu.
- **Noms, pas valeurs.** « Sensible » veut dire « nommé comme un jeton, un mot de passe, un
  secret, une session ou un cookie ». Un jeton rangé dans `x` échappe aux règles.
- **Dart est « expérimental » dans Semgrep.** Mesuré le 2026-09-25 avec 1.178.0 : les
  **447 fichiers Dart** du dépôt sont analysés **sans aucune erreur d'analyse syntaxique**, y
  compris `switch` en expression, motifs, raccourcis d'énumération (`.low`). Si un fichier ne
  s'analyse pas, le contrôle **échoue** (code 2) au lieu de le sauter.
- **Code natif.** `MainActivity.kt` et `SceneDelegate.swift` ne sont couverts que par les règles
  de secrets ; les réglages natifs (manifeste, `Info.plist`, XML réseau) le sont par
  `mobile-platform.yaml`.
- **Secrets du dépôt entier.** C'est le rôle de GitHub *secret scanning* avec *push protection*
  (activés : `gh api repos/gchambaud_microsoft/Certigo --jq .security_and_analysis`, lu le
  2026-09-24). La règle `dart-hardcoded-credential` ignore les dossiers de test.
- **Dépendances.** C'est le rôle d'OSV (`dependency-vuln-scan.yml`).
- **Runners `certigo-pr` persistants.** Le job `candidate` exécute le code de la PR (son
  `dart-sast.mjs`, ses règles) sur le même pool que `scan`, et ces runners ne sont pas éphémères :
  l'espace de travail survit d'un job à l'autre. Du code de PR peut donc y laisser un fichier
  qu'un job ultérieur chargera. Exemple relevé par la relecture indépendante de #560, mécanisme
  vérifié avec Python 3.12 : `python -m venv` place le répertoire courant en tête de `sys.path`,
  donc un `venv.py` déposé dans l'espace de travail s'exécute dans le `scan` suivant, avant le
  verdict. L'exposition est commune à tous les jobs `certigo-pr` qui exécutent du code de PR ;
  elle est suivie dans #553 (pool PR reconstruit à chaque job), pas réglée par ce workflow.
- **Dossiers de test.** Les règles qui ne visent que le code livré excluent les seules racines de
  test des paquets (`/apps/mobile/test/`, `/apps/mobile/integration_test/`,
  `/apps/mobile/test_driver/`, `/packages/*/test/`). Une exclusion plus large (`**/test/**`,
  `*_test.dart`) laissait passer du code livré rangé dans `lib/**/test/` ou nommé `*_test.dart` :
  mesuré le 2026-10-04, corrigé, et verrouillé par les fixtures `apps/` et `packages/` de
  `.github/sast/tests/`.

## Code qu'une PR voudrait soustraire au scan

Dart compile tout fichier qu'une directive désigne, quelle que soit son extension, et un fichier
qui contient un octet NUL ou de l'UTF-8 invalide dans un commentaire (mesuré le 2026-10-04 avec
Dart 3.12 : `import 'hidden.png';` s'exécute, un `// <NUL>` ne gêne pas la compilation). D'où :

- les binaires sont reconnus **par extension seulement** ; tout autre fichier du périmètre doit
  être de l'UTF-8 valide sans octet NUL, sinon le scan **échoue** (code 2). Semgrep 1.178.0
  analyse bien le code situé après un NUL ou un octet invalide (mesuré pendant la relecture de
  #560), mais ce comportement d'une version n'est pas un contrat ; le contrôle ne dépend plus de
  lui ;
- chaque directive `import`, `export` et `part` de chaque fichier `.dart` analysé est relue par
  un petit analyseur lexical (commentaires imbriqués, chaînes brutes, triples et adjacentes,
  échappements `\x`/`\u`, imports conditionnels, `augment`) : elle doit charger `dart:…`, ou un
  fichier `.dart` par `package:` ou par un chemin relatif qui reste dans l'arbre analysé. Sinon
  le scan **échoue** (code 2). Mesuré le 2026-10-04 : 449 fichiers Dart, 2 347 directives, même
  résultat qu'un comptage ligne à ligne, aucun problème sur `main` ;
- aucun `pubspec.yaml` ne peut vivre sous un dossier exclu (`.github/sast/tests/`) : une
  dépendance `path:` n'y trouverait donc aucun paquet à charger.

## Modèle de confiance

Tout ce qui décide du verdict vient du SHA de **base** de la PR (`.trusted-control`) :
`dart-sast.mjs`, les règles, le périmètre, la baseline et le verrou Semgrep. L'arbre de la PR
n'est lu que comme **données**. Une PR ne peut donc ni affaiblir une règle, ni élargir une
exclusion, ni accepter sa propre découverte.

`dart-sast.mjs` appelle Semgrep avec une liste **explicite** de fichiers, et désactive tout ce
qu'une PR pourrait utiliser pour se cacher : commentaires `nosemgrep` (`--disable-nosem`),
fichiers `.semgrepignore` et `.gitignore`, limite de taille, métriques et vérification de
version, variables d'environnement `SEMGREP_*` et configuration utilisateur (`HOME` isolé).
Il échoue ensuite si Semgrep n'a pas rendu **chaque** fichier comme analysé, s'il signale la
moindre erreur (analyse syntaxique, délai dépassé), s'il analyse un fichier non demandé, si sa
version diffère du verrou, ou si du code Dart échappe au périmètre (section précédente). Chaque
option de la ligne de commande ne peut être donnée qu'une fois : un second `--root` est refusé au
lieu de remplacer silencieusement le premier.

Le validateur des workflows impose ce montage **à l'identique**. `dart-sast.yml` et, dès la PR A,
sa proposition de pré-approbation doivent être exactement l'une des formes relues de
`.github/scripts/dart-sast-workflow-forms/` (`dart-sast-workflow-policy.mjs`, appelé par
`validate-workflow-security.mjs`). L'égalité est sémantique (commentaires et ordre des clés
ignorés) mais porte sur tout le reste, révisions d'actions comprises, avec le parseur durci du
manifeste : ancres, alias, étiquettes, clés en double et retours chariot sont refusés.

Une première version vérifiait des motifs (« le job `scan` contient telle commande »). La
relecture indépendante de #560 l'a contournée de huit façons sans rien casser de visible :
`|| true`, second `--root`, variables d'environnement échangées, `shell:` ou `defaults`,
`working-directory`, étape ajoutée avant le scan, gate sans `exit 1`. Chacune est désormais un
test de refus (`dart-sast-workflow-policy.test.mjs`). Les invariants que le contrat protège y sont
aussi vérifiés sur chaque forme relue, pour qu'une forme future ne puisse pas en perdre un sans
le dire : le job `scan` exécute la copie de base de `dart-sast.mjs`, ne lit l'arbre de la PR que
par `--root`, installe Semgrep depuis le verrou de base avec `--require-hashes
--only-binary=:all: --no-deps`, et aucune de ses étapes ne lit la PR avant le verdict ; le job
agrégé `Dart SAST / Security gate` ne reçoit aucune permission, ne lit aucune source PR et tourne
sur `certigo-trusted`, comme tous les gates agrégés (`docs/runbooks/CI_RUNNERS.md` §10).

### Modifier le workflow

Le contrat épingle tout, y compris les révisions d'actions : une montée de version proposée par
Dependabot suit donc le même chemin qu'un changement voulu. Comme pour le contrat des workflows
Cosmos (`CI_WORKFLOW_CHANGES.md`, « Ce que ce mécanisme ne débloque pas ») :

1. **PR de code** : ajouter la nouvelle forme `v<n+1>.yml` dans `dart-sast-workflow-forms/`, à
   côté de l'ancienne, qui reste acceptée (sinon `main` refuserait son propre workflow). Les
   tests de mutation visent la forme la plus récente ; les adapter si une ancre a changé.
2. **PR A** : pré-approbation ; la proposition doit égaler la nouvelle forme.
3. **PR B** : appliquer le workflow et retirer l'ancienne forme dans la même PR.

## Chaîne d'approvisionnement

`semgrep==1.178.0` et ses **65 dépendances** sont verrouillés **avec leurs empreintes SHA-256**
dans `.github/sast/semgrep-requirements.lock` (généré par `uv pip compile --generate-hashes`,
commande en tête du fichier). L'installation CI utilise `--require-hashes --only-binary=:all:
--no-deps --no-cache-dir --isolated` : aucune compilation, aucun code d'installation, aucun cache
partagé sur les runners persistants. Le verrou contient les empreintes de toutes les roues
publiées : la même commande fonctionne sur x86_64 (runners) et aarch64 (poste WSL). Mesuré le
2026-09-25 avec `pip download --platform … --abi cp312` : les 66 paquets ont une roue x86_64
dont l'empreinte correspond ; celles de `semgrep` et `cryptography` exigent **glibc ≥ 2.34**
(`manylinux_2_34`), ce que satisfont les runners Ubuntu 24.04 (`infra/ci-runner/README.md`). Une
image de runner plus ancienne ferait échouer l'installation, jamais le scan en silence.

Semgrep CE est publié sous LGPL-2.1 ; il est exécuté, pas redistribué. Aucune règle du registre
Semgrep n'est chargée : tout est local, aucune donnée ne sort du runner pendant le scan.

## Exécuter en local (Linux ou WSL, Python 3.12, Node ≥ 20)

```bash
python3.12 -m venv /tmp/semgrep
/tmp/semgrep/bin/python -m pip install --isolated --no-cache-dir --disable-pip-version-check \
  --require-hashes --only-binary=:all: --no-deps -r .github/sast/semgrep-requirements.lock

# Les règles détectent-elles ce qu'elles doivent, et seulement cela ?
node .github/scripts/dart-sast.mjs test-rules --semgrep /tmp/semgrep/bin/semgrep --state /tmp/dart-sast

# Le dépôt a-t-il une découverte hors baseline ?
node .github/scripts/dart-sast.mjs check --semgrep /tmp/semgrep/bin/semgrep --root . --state /tmp/dart-sast
```

Règles, périmètre, baseline, verrou et fixtures sont lus **à côté du script** (`--rules`,
`--scope`, `--baseline`, `--lock` et `--fixtures` ne servent qu'aux tests) : exécuter la copie de
base du script, c'est appliquer les contrôles de base.

Codes de sortie : **0** rien de nouveau ; **1** découverte nouvelle ou test de règle en échec ;
**2** scan invalide ou incomplet (outil en erreur, fichier non analysé, entrée malformée).

## Tri initial des découvertes (mesuré le 2026-09-25, `main` `653e9112`)

Les premières versions des règles ont produit **3 faux positifs**, corrigés dans les règles ;
la version livrée trouve **10 découvertes** sur **523 fichiers**.

| Règle | Où | Verdict | Suite |
|---|---|---|---|
| `dart-hardcoded-credential` | `apps/mobile/test/auth_controller_test.dart:687` (`refreshToken: 'refresh-email-2'`), `apps/mobile/test/get_started_sheet_survives_authloading_test.dart:218` (`kPassword`) | **Faux positif** : valeurs factices de tests, jamais livrées | Règle restreinte au code livré (`paths.exclude`) ; les secrets du dépôt entier restent couverts par *secret scanning* |
| `dart-api-path-unencoded-interpolation` | `packages/data/lib/src/content/api_public_content_source.dart:24` (`'/$kActivePublicManifestRoute'`) | **Faux positif** : constante de compilation (`const String`, préfixe `k`), jamais contrôlable | Les identifiants `k[A-Z]…` sont exclus de la règle |
| `dart-insecure-random` ×5 | identifiants d'idempotence (quiz, leçon, examen, boutique) et de corrélation | Vrai problème (durcissement : `Random()` amorcé sur 32 bits) | Corrigé par #550 |
| `dart-api-path-unencoded-interpolation` ×3 | `/quiz/$lessonId/submit` (en ligne et file hors ligne), `/friends/$friendId` | Vrai problème (redirection de requête authentifiée) | Corrigé par #556, avec refus des segments `.`/`..` dans `ApiClient` |
| `mobile-android-backup-enabled` | `AndroidManifest.xml` | Vrai problème (jetons dans la sauvegarde Google) | Corrigé par #557 |
| `mobile-ios-custom-url-scheme` | `ios/Runner/Info.plist` (`certigo://`) | Risque accepté (schéma requis par le retour OIDC) | Baseline justifiée ; garde des liens entrants dans #564 (test iPhone requis) |

## Que faire devant une découverte

1. **Corriger** : c'est le cas normal. Le message de la règle dit quoi faire.
2. **Faux positif ou risque accepté** : ajouter une entrée à `.github/sast/baseline.json`
   **dans une PR séparée, fusionnée avant** celle qui introduit le code (la baseline est lue sur
   la base). `node .github/scripts/dart-sast.mjs baseline …` (mêmes options que `check`) imprime
   les clés `fingerprint`/`occurrence` à recopier. Chaque entrée exige :
   `classification` (`false-positive` ou `accepted-risk`), `reviewedAt` (date réelle),
   `justification` et `revisitWhen` (au moins 20 caractères chacun, la vraie condition
   d'invalidation).

L'empreinte dépend de la règle, du chemin et de **toutes** les lignes de code trouvées (espaces
normalisés), pas des numéros de ligne : déplacer ou reformater le code ne crée pas de découverte.
Le résumé n'affiche que les 20 premières lignes, suivies de « … », mais l'empreinte les couvre
toutes : modifier une ligne au-delà (un `return false;` devenu `return true;` au fond d'un rappel
accepté) crée une découverte nouvelle. Une entrée
qui ne correspond plus à rien est signalée `STALE` sans faire échouer le contrôle (sinon un
correctif serait bloqué par la base) ; la retirer dans la PR qui corrige, ou dans un nettoyage.

## Ajouter ou modifier une règle

- Identifiant `dart-<risque>-<nom>` ou `mobile-<risque>-<nom>`, `metadata.certigo-risk`
  obligatoire, `certigo-redact: true` pour une règle de secrets (le code n'est alors jamais
  imprimé dans les journaux CI).
- Au moins **un cas positif et un cas négatif** dans `.github/sast/tests/` : une ligne
  `// ruleid: <règle>` (ou `# `, `<!-- -->`) exige une découverte sur la ligne de code suivante,
  `// ok: <règle>` l'interdit. `test-rules` échoue aussi sur toute découverte non annotée.
- Une nouvelle règle qui trouve du code déjà sur `main` doit arriver avec les correctifs **ou**
  les entrées de baseline correspondantes : après la PR B, le job candidat du workflow exécute les
  règles, le périmètre et la baseline **de la PR** sur son propre arbre, et échoue sinon. C'est le
  seul cas où une baseline change dans la même PR que ce qu'elle accepte : la règle et son
  acceptation sont revues ensemble.
- Limites du moteur Dart mesurées le 2026-09-25 (1.178.0), déjà contournées dans les règles :
  un argument nommé ne s'apparie pas sous un appelé métavariable (`$F(..., nom: v, ...)`), d'où
  des constructeurs nommés explicitement ; un appel générique (`dio.get<T>(...)`) ne s'apparie
  que par `pattern-inside`.

## Mettre à jour Semgrep

Modifier la version dans `.github/sast/semgrep-requirements.in`, regénérer le verrou avec la
commande en tête du fichier, puis relancer `test-rules` et `check`. Les empreintes de la
baseline ne dépendent pas de Semgrep, seulement des règles et du code.

## Séquence de mise en place

Les workflows ne se modifient que par pré-approbation (`CI_WORKFLOW_CHANGES.md`) :

1. **PR 0** — outillage seul : règles, fixtures, périmètre, baseline, verrou, `dart-sast.mjs`,
   tests, ce runbook. Aucun workflow.
2. **PR A** — pré-approbation de `.github/workflows/dart-sast.yml` (non privilégié : lecture
   seule, aucun secret ; scans sur `certigo-pr`, job agrégé sur `certigo-trusted`).
3. **PR B** — activation du workflow. Le contexte `Dart SAST / Security gate` n'est **pas**
   requis à ce stade ; le rendre requis passe ensuite par la protection de branche, puis
   `branch-protection-main.json` et la liste des contextes stables du validateur. À ce moment,
   noter que `required-context-policy.mjs` vérifie qu'un contexte requis est produit, pas qu'il
   l'est par un seul job : un job homonyme dans un autre workflow publierait le même nom. Cette
   limite vaut pour tous les contextes requis.
