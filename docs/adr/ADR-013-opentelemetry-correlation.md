# ADR-013 — OpenTelemetry & correlation-id de bout en bout (client → backend → App Insights)

| Champ | Valeur |
|---|---|
| **ADR** | 013 |
| **Finding audit** | ADR-013 (traçabilité distribuée) + **D-10** (limite SAST côté Dart) |
| **Statut** | ✅ **Accepté** — correlation-id E2E via en-tête `x-correlation-id` ; télémétrie distribuée = Application Insights + `System.Diagnostics.Activity` (traceparent W3C), **sans** SDK OpenTelemetry lourd |
| **Date de décision** | 2026-07-07 |
| **Lot de migration** | `wp-p1-14-opentelemetry-correlation` (Phase 1) |
| **Décideurs** | Technique (backend + mobile) |
| **Supersède / complète** | Complète `wp-p0-08` (backend déjà point autoritaire du correlation-id) ; documente formellement le finding **D-10** déjà noté en commentaire dans `.github/workflows/codeql.yml` |

> **Type de document.** ADR (Architecture Decision Record). Il **acte** la stratégie de traçabilité
> distribuée de Certigo : un `x-correlation-id` unique traverse mobile → backend → journaux/traces
> App Insights, et la télémétrie distribuée s'appuie sur la pile **Application Insights + Activity /
> traceparent W3C** déjà en place côté Functions isolées, plutôt que sur l'ajout d'un SDK
> `OpenTelemetry.*` autonome. Il documente aussi la **limite SAST Dart (D-10)** et sa mitigation.

---

## Contexte

L'objectif (ADR-013) est une **corrélation de bout en bout** : pouvoir épingler un incident remonté par
l'app mobile à des lignes de log/traces précises côté backend, via un identifiant unique propagé sur
toute la chaîne d'appel, et exporté dans Application Insights.

### État réel sur `main` (contrôle d'idempotence — indice `wp-p0-08`)

Le backend est **déjà** le point autoritaire du correlation-id ; il ne manquait que l'**amorçage côté
client** et la **formalisation** de la décision de télémétrie.

| Preuve | Emplacement | Effet |
|---|---|---|
| `ResolveCorrelationIdAsync` honore un `x-correlation-id` entrant, sinon `Guid.NewGuid().ToString("n")` | `backend/src/Certigo.Api/Middleware/ExceptionMiddleware.cs` (l.76-90) | **Backend autoritaire** : réutilise l'id client ou en frappe un (32 hex minuscules) |
| `context.Items["CorrelationId"]` + `logger.BeginScope({ ["CorrelationId"] = … })` | idem (l.20-21) | Id injecté dans le **scope de log** → exporté avec chaque trace App Insights |
| Echo `x-correlation-id` en en-tête de réponse + extension ProblemDetails `correlationId` sur erreur | idem (l.106, l.112) | Réponse **traçable** côté client (succès via en-tête, erreur via ProblemDetails) |
| `AddApplicationInsightsTelemetryWorkerService()` + `ConfigureFunctionsApplicationInsights()` | `backend/src/Certigo.Api/Program.cs` (l.37-38) | **Télémétrie distribuée** (Activity / traceparent W3C) exportée vers App Insights |
| `ExceptionMiddleware` enregistré dans le pipeline worker | `backend/src/Certigo.Api/Program.cs` (l.31) | Le correlation-id couvre **toutes** les fonctions HTTP |
| Mobile `ApiClient` : 2 intercepteurs (debug-log + auth), **aucune** émission `x-correlation-id` | `packages/data/lib/src/api/api_client.dart` (avant ce lot) | **Delta réel** : le client **n'amorçait pas** la chaîne — le backend frappait donc toujours un id neuf, non relié au contexte mobile |

**Conclusion d'idempotence** : le correlation-id backend et l'export App Insights **existent déjà** — ne
pas les réinventer. Le seul delta de code est **côté mobile** : émettre/propager `x-correlation-id` pour
que l'id soit *initié par le client* et conservé de bout en bout. Le delta documentaire est cet ADR
(décision OpenTelemetry + D-10).

---

## Options considérées

### Option A — Ajouter un SDK OpenTelemetry (`OpenTelemetry.*`) autonome au backend

Instrumenter explicitement avec `OpenTelemetry`, un `TracerProvider`, un `ActivitySource` dédié et un
exporter (OTLP ou Azure Monitor).

- **Bénéfice** : vocabulaire OTel explicite, portable vers un collector OTLP tiers.
- **Coûts / risques** : redondant avec Application Insights (qui **consomme déjà** `System.Diagnostics.Activity`
  et le format **traceparent W3C**, socle d'OpenTelemetry) ; surcoût de dépendances et de configuration
  sur des Functions isolées ; risque de **double export** / double comptage sans bénéfice E2E réel.

### Option B — S'appuyer sur App Insights + Activity / traceparent W3C (déjà en place) + amorçage mobile

Reconnaître que la pile actuelle **est** le dorsal compatible OpenTelemetry : `Activity`/traceparent =
modèle de trace OTel, App Insights = backend d'export. Le seul manque E2E est l'**amorçage client**, résolu
par un intercepteur mobile qui pose `x-correlation-id`.

- **Bénéfice** : corrélation E2E complète **sans** dépendance supplémentaire ; cohérent avec l'existant
  backend ; delta minimal et testable.
- **Coût** : pas de vocabulaire `OpenTelemetry.*` explicite dans le code (acceptable : le format de trame
  reste W3C traceparent, standard OTel).

---

## Décision

> **Option B.** La traçabilité distribuée de Certigo repose sur **Application Insights +
> `System.Diagnostics.Activity` (traceparent W3C)**, socle **compatible OpenTelemetry**, sans ajout de SDK
> `OpenTelemetry.*` lourd. La **corrélation de bout en bout** est complétée en faisant **émettre le
> `x-correlation-id` par le client mobile**, que le backend honore déjà (`ExceptionMiddleware`) et propage
> dans les logs/traces App Insights.

**Delta de code livré par ce lot (mobile uniquement)** :

| Changement | Emplacement | Effet |
|---|---|---|
| `CorrelationIdInterceptor` (génère un id 32-hex ou **préserve** un id fourni par l'appelant) | `packages/data/lib/src/api/correlation_interceptor.dart` | Le mobile **amorce** le correlation-id, aligné sur le format backend (`ToString("n")`) |
| Intercepteur enregistré **en premier** dans `ApiClient` | `packages/data/lib/src/api/api_client.dart` | Id posé **avant** les intercepteurs de log et d'auth → présent sur chaque requête sortante (y compris rejeu de synchronisation qui passe par `ApiClient`) |
| Export barrel | `packages/data/lib/data.dart` | `CorrelationIdInterceptor` / `generateCorrelationId` exposés publiquement |
| Test hermétique (6 cas, `package:test` pur Dart) | `packages/data/test/correlation_interceptor_test.dart` | DoD mobile : format/unicité de l'id, mint-vs-préservation, câblage `ApiClient` marque bien l'en-tête sur le fil |

**Backend : aucun changement** — déjà autoritaire (cf. tableau de preuves).

---

## Conséquences

- Un **même `x-correlation-id`** traverse désormais mobile → backend → scope de log → App Insights, initié
  par le client. Un incident mobile est reliable aux lignes de log/traces exactes.
- **Aucune dépendance ajoutée** au backend ; pas de double export de télémétrie.
- La propagation mobile est **transparente** pour les appels existants (`getJson`/`postJson`/`deleteJson`)
  et pour le rejeu de synchronisation, qui délègue à `ApiClient` (intercepteur Dio couvre tout).
- Un id fourni par l'appelant (retry idempotent, corrélation multi-requêtes) est **préservé**, jamais écrasé.
- Le format de trame de trace reste **W3C traceparent** (standard OpenTelemetry) : une bascule future vers un
  collector OTLP tiers reste possible sans refonte du code applicatif.

---

## D-10 — Limite SAST côté Dart (analyse statique de sécurité)

**Finding D-10.** Le SAST du dépôt (CodeQL) **ne couvre pas le langage Dart/Flutter**. Le code mobile
(`apps/`, `packages/`) échappe donc à l'analyse statique de sécurité CodeQL.

| Preuve | Emplacement | Constat |
|---|---|---|
| « Dart/Flutter is not supported by CodeQL » | `.github/workflows/codeql.yml` (l.3-7) | Limite **documentée** : CodeQL couvre le backend C#, l'outillage Node/TS et Python |
| Matrice CodeQL = `csharp`, `javascript-typescript`, `python` (pas `dart`) | `.github/workflows/codeql.yml` (l.30-35) | Aucun scan SAST du code Dart |

**Mitigation en place** (couverture de substitution du périmètre Dart) :

| Contrôle | Emplacement | Rôle |
|---|---|---|
| `flutter analyze` (bloquant, fatal-on-info) | `.github/workflows/ci-mobile.yml` (l.166) ; gates release `release-android.yml` (l.134), `release-ios.yml` (l.194) | Analyse statique Dart (lints sécurité/qualité) bloquante sur PR **et** avant release |
| `dart format --line-length 100 --set-exit-if-changed apps packages` | `.github/workflows/ci-mobile.yml` (l.157) | Gate de style Dart déterministe |
| Scan de vulnérabilités des dépendances | `.github/workflows/dependency-vuln-scan.yml`, `.github/workflows/security-scan.yml` | Complète CodeQL sur les dépendances (y compris l'écosystème mobile) |

**Décision D-10.** La limite est **acceptée et documentée** : tant que CodeQL ne supporte pas Dart, le
périmètre mobile s'appuie sur `flutter analyze` (bloquant) + gate de format + scan de dépendances comme
contrôles de substitution. Réévaluer si/quand un support Dart (CodeQL ou SAST tiers, ex. `dart analyze`
avec règles sécurité étendues) devient disponible.

---

## Références

- Backend (correlation-id autoritaire) : `backend/src/Certigo.Api/Middleware/ExceptionMiddleware.cs` (l.20-21, 76-90, 106, 112)
- Backend (télémétrie App Insights) : `backend/src/Certigo.Api/Program.cs` (l.31, 37-38)
- Mobile (delta de ce lot) : `packages/data/lib/src/api/correlation_interceptor.dart`, `packages/data/lib/src/api/api_client.dart`, `packages/data/lib/data.dart`
- Test mobile : `packages/data/test/correlation_interceptor_test.dart`
- SAST / gates : `.github/workflows/codeql.yml`, `.github/workflows/ci-mobile.yml`, `.github/workflows/dependency-vuln-scan.yml`, `.github/workflows/security-scan.yml`, `.github/workflows/release-android.yml`, `.github/workflows/release-ios.yml`
- Registre de migration : `docs/migration/work-packages.yaml` (`wp-p1-14-opentelemetry-correlation`), lot amont `wp-p0-08`
- Format traceparent W3C : socle de trace compatible OpenTelemetry consommé par Application Insights
