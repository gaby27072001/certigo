# Étape 10 — Logique métier et contrats à préserver (« MUST NOT BREAK »)

> **Branche auditée :** `transform/phase-0-audit` (`HEAD` `778f9c247ceb9c0db29fb931a8573bd328b492ab`)
> **Périmètre :** `apps/apple/CertigoKit`, `apps/apple/CertigoNative`, `apps/apple/CertigoNative/WidgetExtension`, `backend/src/Certigo.Api`, `backend/src/Certigo.Application`
> **Statut des constats :** **VÉRIFIÉ** sur le code source et les suites de tests du dépôt. Aucun secret, jeton ou identifiant de locataire réel n'est reproduit en clair (`<redacted-tenant-id>`, `<redacted-client-id>`, `<redacted-api-audience>`, `<redacted-endpoint>`).

---

## 1. Synthèse des invariants non négociables (§6, §33 PRESERVE, §38.1)

1. **Autorité serveur absolue :** la notation (`QuizService.SubmitAsync`, `ExamService.SubmitAsync`), l'attribution d'XP/gemmes/niveaux/succès, le calcul FSRS (`ReviewScheduler`), le modèle de l'apprenant (`LearnerModel`), l'anti-triche (`AttemptIntegrityEvaluator`), la readiness (`ReadinessCalculator`) et le changement d'objectif actif (`UserService.SetActiveTrackAsync` avec `expectedTrackId`) restent **exclusivement côté serveur** (`backend/src/Certigo.Application/Services/QuizService.cs:37-294`, `apps/apple/CertigoKit/Sources/CertigoData/CertigoAPI.swift:100-127,329-338`).
2. **Absence totale de clé de correction sur le client :** les ressources publiques du manifeste v3 rejettent explicitement les champs `answerkey`, `correct`, `correctoptionids`, `explanation`, `privatemanifestid`, `rationale`, `releaseid`, `solution` (`apps/apple/CertigoKit/Sources/CertigoData/PublicResourceReader.swift:12-15,242-253`).
3. **Idempotence de bout en bout :** chaque tentative de quiz ou d'examen porte un `clientAttemptId` UUID v4 (`apps/apple/CertigoKit/Sources/CertigoDomain/Contracts.swift:285,305` ; `apps/apple/CertigoKit/Sources/CertigoDomain/LearningServices.swift:108`). La file locale `SubmissionStore` est bornée, typée et isolée par `(ownerId, apiScope)` (`apps/apple/CertigoKit/Sources/CertigoData/SubmissionStore.swift:45-124`).
4. **Intégrité cryptographique et confinement disque :** chaque manifeste et chaque fichier public est vérifié par SHA-256 et taille exacte avant mise en cache ou lecture (`apps/apple/CertigoKit/Sources/CertigoData/PublicReleaseAPI.swift:29-77`, `apps/apple/CertigoKit/Sources/CertigoData/CanonicalQuestionReader.swift:138-155`), et stocké via descripteurs POSIX sans suivi de liens symboliques (`O_NOFOLLOW`) avec verrouillage `flock` et protection `completeUntilFirstUserAuthentication` (`apps/apple/CertigoKit/Sources/CertigoData/RuntimeDisk.swift:82-321`).
5. **Cloisonnement de session et suppression de compte :** chaque opération asynchrone vérifie la génération de session (`APICredentials.generation`, `LearningClient.assertCurrent` `apps/apple/CertigoKit/Sources/CertigoData/LearningClient.swift:402-406`). La suppression de compte exige une ré-authentification MSAL fraîche (`promptType = .login`, `max_age = 0`) et un reçu durable `NativeDeletionReceipt` avant toute purge locale (`apps/apple/CertigoNative/Sources/MSALAuthenticationProvider.swift:122-159`, `apps/apple/CertigoNative/Sources/NativeModel.swift:809-1038`).

---

## 2. Tableau exhaustif des endpoints consommés par le client natif

### 2.1 Endpoints consommés par `CertigoAPI.swift`, `PublicReleaseAPI.swift` et `AccountDeletion.swift`

Tous les appels de `CertigoAPI` passent par `CertigoAPI.request(_:token:body:method:reauthentication:query:)` (`apps/apple/CertigoKit/Sources/CertigoData/CertigoAPI.swift:375-429`), qui impose :
- `baseURL.scheme == "https"` sans identifiants, query ni fragment (`CertigoAPI.swift:81-86`) ;
- `URLSessionConfiguration.ephemeral`, sans cache ni cookies, timeouts `20 s` (requête) / `30 s` (ressource), refus strict de toute redirection HTTP via `RejectRedirects` (`CertigoAPI.swift:42-68`) ;
- en-têtes `Authorization: Bearer <token>`, `Accept: application/json`, `x-correlation-id: <UUID>`, et `Content-Type: application/json` si corps présent (`CertigoAPI.swift:403-413`) ;
- taille maximale de réponse `8 Mio` (`8 * 1_024 * 1_024` octets) et `mimeType == "application/json"` (`CertigoAPI.swift:425-427`).

| # | Méthode HTTP | Chemin exact (relatif à `baseURL` `/api`) | Méthode client (`fichier:ligne`) | DTO Requête (`fichier:ligne`) | DTO Réponse (`fichier:ligne`) | Validation & en-têtes spécifiques côté client | Endpoint Backend (`fichier:ligne`) & Service / DTO serveur |
|---|---|---|---|---|---|---|---|
| 1 | `GET` | `/me` | `CertigoAPI.profile(accessToken:)` (`CertigoAPI.swift:88-93`) · `LearningClient.connect` / `refreshProfile` (`LearningClient.swift:29-40,191-197`) | — | `Profile` (`Contracts.swift:7-17`) | `!profile.id.isEmpty` (`CertigoAPI.swift:91`) ; en rafraîchissement : `value.id == context.ownerId` (`LearningClient.swift:195`). | `UserFunctions.GetMe` (`backend/src/Certigo.Api/Functions/UserFunctions.cs:11-19`) → `IUserService.GetOrProvisionAsync` → `UserProfileDto` (`ProfileDtos.cs:13-56`) |
| 2 | `GET` | `/catalog/tracks` | `CertigoAPI.catalog(_:)` (`CertigoAPI.swift:95-98`) · `LearningClient.catalog()` (`LearningClient.swift:112-117`) | — | `Catalog` → `[Track]` (`Contracts.swift:18-44`) | `Catalog.validated()` exige `schema == "certigo.app-certification-catalog/v2"`, `sourceSchema == "certigo.certification-catalog/v1"`, IDs uniques non vides (`Contracts.swift:23-35`). | `CatalogFunctions.GetCatalog` (`backend/src/Certigo.Api/Functions/CatalogFunctions.cs:10-18`) → `IContentService.GetCatalogAsync` → `CatalogDto` (`ContentDtos.cs:129-135`) |
| 3 | `POST` | `/me/active-track` | `CertigoAPI.setActiveTrack(trackId:expectedTrackId:credentials:)` (`CertigoAPI.swift:100-127`) · `LearningClient.setActiveTrack` (`LearningClient.swift:199-205`) | Struct interne `Selection { trackId: String, expectedTrackId: String? }` (`CertigoAPI.swift:103-113`) | `Profile` (`Contracts.swift:7-17`) | Encode explicitement `expectedTrackId` (même `null`) ; vérifie `value.id == credentials.ownerId` et `value.activeTrackId?.lowercased() == trackId.lowercased()` (`CertigoAPI.swift:108-125`). Gère `HTTP 409` par `refreshProfile()` (`NativeModel.swift:1247-1260`). | `UserFunctions.SetActiveTrack` (`backend/src/Certigo.Api/Functions/UserFunctions.cs:21-39`) → `SetActiveTrackRequest` (`ProfileDtos.cs:11`) → `IUserService.SetActiveTrackAsync` |
| 4 | `GET` | `/me/paths/{trackId}` | `CertigoAPI.path(trackId:credentials:)` (`CertigoAPI.swift:129-136`) · `LearningClient.path(trackId:)` (`LearningClient.swift:119-124`) | Paramètre de route `trackId` | `LearningPath` (`PathUnit`, `PathLesson`, `NodeStatus`, `DomainProgress`) (`Contracts.swift:45-77`) | Vérifie `path.trackId == trackId` et `(0...100).contains(path.readinessScore)` (`CertigoAPI.swift:132-134`). | `PathFunctions.GetMyPath` (`backend/src/Certigo.Api/Functions/PathFunctions.cs:10-19`) → `IPathService.GetPathAsync` → `PathDto` (`ContentDtos.cs:5-33`) |
| 5 | `GET` | `/tracks/{trackId}/lessons/{lessonId}` | `CertigoAPI.lesson(trackId:lessonId:credentials:)` (`CertigoAPI.swift:138-151`) · `LearningClient.lesson` (`LearningClient.swift:207-212`) | Paramètres de route `trackId`, `lessonId` | `Lesson` (`LessonBlock`, `QuizItem`, `QuizOption`) (`Contracts.swift:212-270`) | Lit l'en-tête `x-content-manifest-id` ; rejette toute divergence avec `lesson.publicManifestId` (`CertigoAPI.swift:145-149`). `lesson.validated(trackId:lessonId:)` vérifie les blocs autorisés (`hook`, `concept`, `example`, `code`, `check`, `recap`) et `type == "mcq"` (`Contracts.swift:221-265`). | `LessonFunctions.GetLesson` (`backend/src/Certigo.Api/Functions/LessonFunctions.cs:10-40`) → `IContentService.GetLessonWithSnapshotAsync` (+ en-têtes `X-Content-Manifest-Id`, `ETag`) |
| 6 | `POST` | `/quiz/{lessonId}/submit` | `CertigoAPI.submit(lessonId:submission:credentials:)` (`CertigoAPI.swift:329-338`) · `LearningClient.submit` / `retry` (`LearningClient.swift:332-395`) | `QuizSubmission` (`clientAttemptId`, `trackId`, `startedAt`, `answers: [QuizAnswer]`, `publicManifestId`) (`Contracts.swift:271-316`) | `QuizResult` (`attemptId`, `scorePct`, `results: [ItemResult]`, `rewards: QuizRewards`, `weakConcepts`, `nextReviewDueAt`) (`Contracts.swift:317-354`) | `submission.validated()` avant envoi (UUID `clientAttemptId`, items distincts, `mcq`, 1 choix non vide, `latencyMs >= 0`) ; `QuizResult.validated(for: submission)` vérifie que les `itemId` retournés sont un sous-ensemble sans doublon des réponses envoyées et que chaque erreur fournit `correctAnswer` non vide (`Contracts.swift:304-336`). | `QuizFunctions.SubmitQuiz` (`backend/src/Certigo.Api/Functions/QuizFunctions.cs:11-21`) → `SubmitQuizRequest` / `SubmitQuizResult` (`QuizDtos.cs:5-40`) → `QuizService.SubmitAsync` (`QuizService.cs:37-294`) |
| 7 | `POST` | `/tutor/explain` | `CertigoAPI.explainAnswer(_:credentials:)` (`CertigoAPI.swift:153-174`) · `LearningClient.explainAnswer` (`LearningClient.swift:126-131`) | `TutorExplainRequest` (`trackId`, `lessonId`, `itemId`, `selected`, `publicManifestId`) (`Contracts.swift:356-373`) | `TutorExplanation` (`TutorPersonalization`) (`Contracts.swift:375-426`) | Exige `baseURL.path == "api"`, `statusCode == 200`, `value.itemId == request.itemId` (insensible à la casse), `points` non vides, `(0...attempts).contains(errors)`, `(0...100).contains(accuracyPct)` (`CertigoAPI.swift:157-172`). | `TutorFunctions.ExplainAnswer` (`backend/src/Certigo.Api/Functions/TutorFunctions.cs:15-24`) → `TutorExplainRequest` / `TutorExplanationDto` (`TutorDtos.cs:7-35`) → `ITutorService.ExplainAsync` |
| 8 | `GET` | `/me/recommendations/{trackId}` | `CertigoAPI.nextBestRecommendations(trackId:credentials:)` (`CertigoAPI.swift:176-188`) · `LearningClient.nextBestRecommendations` (`LearningClient.swift:133-138`) | Paramètre de route `trackId` | `NextBestRecommendations` (`[RecommendationItem]`) (`LearningServices.swift:3-21`) | Exige `baseURL.path == "api"`, `value.trackId == trackId`, bornes `0...100` sur `priority`, `masteryPct`, `forgettingRiskPct`, et `estMinutes >= 0` (`CertigoAPI.swift:181-186`). | `RecommendationFunctions.GetNextBest` (`backend/src/Certigo.Api/Functions/RecommendationFunctions.cs:10-19`) → `IRecommendationService.GetNextBestAsync` → `NextBestDto` (`RecommendationDtos.cs:6-26`) |
| 9 | `POST` | `/exam/generate` | `CertigoAPI.generateMockExam(_:credentials:)` (`CertigoAPI.swift:190-200`) · `LearningClient.generateMockExam` (`LearningClient.swift:140-145`) | `MockExamRequest` (`trackId`, `length`, `publicManifestId`) (`LearningServices.swift:50-60`) | `MockExam` (`MockExamBlueprintDomain`, `MockExamItem`) (`LearningServices.swift:61-106`) | Exige `baseURL.path == "api"`, `exam.trackId == value.trackId`, correspondance `publicManifestId`, et `exam.validated()` (`passingScore` `0...1000`, `type == "mcq"`, ≥ 2 options uniques) (`CertigoAPI.swift:193-199`, `LearningServices.swift:86-105`). | `ExamFunctions.GenerateMockExam` (`backend/src/Certigo.Api/Functions/ExamFunctions.cs:11-20`) → `MockExamRequest` / `MockExamDto` (`ExamDtos.cs:7-33`) → `IExamService.GenerateAsync` |
| 10 | `POST` | `/exam/submit` | `CertigoAPI.submitMockExam(_:credentials:)` (`CertigoAPI.swift:202-218`) · `LearningClient.submitMockExam` (`LearningClient.swift:147-152`) | `SubmitMockExamRequest` (`clientAttemptId`, `trackId`, `examId`, `startedAt`, `answers`) (`LearningServices.swift:107-124`) | `MockExamResult` (`ExamDomainScore`, `ItemResult`, `QuizRewards`) (`LearningServices.swift:125-146`) | Vérifie UUID `clientAttemptId`, `result.examId == value.examId`, `pct` `0...100`, `scaledScore` `0...1000`, `correct` `0...total`, `results` sous-ensemble des `answers` (`CertigoAPI.swift:205-216`). | `ExamFunctions.SubmitMockExam` (`backend/src/Certigo.Api/Functions/ExamFunctions.cs:22-31`) → `SubmitMockExamRequest` / `MockExamResultDto` (`ExamDtos.cs:35-56`) → `IExamService.SubmitAsync` |
| 11 | `GET` | `/achievements` | `CertigoAPI.achievements(credentials:)` (`CertigoAPI.swift:220-222`) · `LearningClient.achievements()` (`LearningClient.swift:154-159`) | — | `AchievementBoard` (`[AchievementItem]`) (`LearningServices.swift:147-162`) | Exige `baseURL.path == "api"` et `statusCode == 200` via `learningService` (`CertigoAPI.swift:246-255`). | `AchievementFunctions.GetAchievements` (`backend/src/Certigo.Api/Functions/AchievementFunctions.cs:10-18`) → `IAchievementService.GetAllAsync` → `AchievementBoardDto` (`GamificationDtos.cs:96-110`) |
| 12 | `GET` | `/quests` | `CertigoAPI.quests(credentials:)` (`CertigoAPI.swift:224-226`) · `LearningClient.quests()` (`LearningClient.swift:161-166`) | — | `QuestBoard` (`[QuestItem]`) (`LearningServices.swift:163-179`) | Exige `baseURL.path == "api"` et `statusCode == 200` (`CertigoAPI.swift:246-255`). `date` est une date calendaire ISO 8601 (`DateOnly` serveur). | `QuestFunctions.GetQuests` (`backend/src/Certigo.Api/Functions/QuestFunctions.cs:11-19`) → `IQuestService.GetTodayAsync` → `QuestBoardDto` (`GamificationDtos.cs:31-45`) |
| 13 | `GET` | `/me/notifications/plan` | `CertigoAPI.notificationPlan(credentials:)` (`CertigoAPI.swift:228-230`) · `LearningClient.notificationPlan()` (`LearningClient.swift:168-173`) | — | `NotificationPlan` (`[ScheduledNotificationItem]`) (`LearningServices.swift:180-194`) | Exige `baseURL.path == "api"` et `statusCode == 200`. Utilisé aussi par `CertigoWidgetSnapshot.make` pour détecter `StreakDanger` (`CertigoWidgetSnapshot.swift:123-129`). | `NotificationFunctions.GetNotificationPlan` (`backend/src/Certigo.Api/Functions/NotificationFunctions.cs:17-25`) → `INotificationService.GetPlanAsync` → `NotificationPlanDto` (`NotificationDtos.cs:49-63`) |
| 14 | `GET` | `/me/notifications/settings` | `CertigoAPI.notificationSettings(credentials:)` (`CertigoAPI.swift:232-236`) · `LearningClient.notificationSettings()` (`LearningClient.swift:175-180`) | — | `NotificationSettings` (`LearningServices.swift:195-221`) | Exige `baseURL.path == "api"` et `statusCode == 200`. | `NotificationFunctions.GetNotificationSettings` (`backend/src/Certigo.Api/Functions/NotificationFunctions.cs:27-35`) → `INotificationService.GetSettingsAsync` → `NotificationSettingsDto` (`NotificationDtos.cs:10-24`) |
| 15 | `POST` | `/me/notifications/settings` | `CertigoAPI.updateNotificationSettings(_:credentials:)` (`CertigoAPI.swift:238-244`) · `LearningClient.updateNotificationSettings` (`LearningClient.swift:182-189`) | `NotificationSettings` (`LearningServices.swift:195-221`) | `NotificationSettings` (`LearningServices.swift:195-221`) | Exige `baseURL.path == "api"` et `statusCode == 200`. Le serveur borne les plages horaires et `maxPerDay`. | `NotificationFunctions.UpdateNotificationSettings` (`backend/src/Certigo.Api/Functions/NotificationFunctions.cs:37-46`) → `UpdateNotificationSettingsRequest` (`NotificationDtos.cs:27-36`) |
| 16 | `GET` | `/pilots/{pilotId}/content` | `CertigoAPI.editorialPilot(pilotId:credentials:)` (`CertigoAPI.swift:257-279`) · `LearningClient.editorialPilot` (`LearningClient.swift:214-219`) | Paramètre de route `pilotId` (`responsible-ai-assistants`) | `EditorialPilotSnapshot` (`EditorialPilot`, `EditorialPilotLesson`, `EditorialPilotSource`) (`Contracts.swift:79-186`) | Vérifie l'en-tête `x-certigo-pilot-content-digest` (`^sha256:[0-9a-f]{64}$`), `etag == "\"\(digest)\""`, recalcule `CanonicalQuestionReader.digest(data)` sur les octets reçus et appelle `pilot.validated()` (`CertigoAPI.swift:262-275`). | `PilotLearningFunctions.GetContent` (`backend/src/Certigo.Api/Functions/PilotLearningFunctions.cs:11-34`) → `IPilotLearningService.GetContentAsync` |
| 17 | `GET` | `/me/pilots/{pilotId}/history/{contentDigest}` | `CertigoAPI.pilotHistory(_:credentials:)` (`CertigoAPI.swift:281-289`) · `LearningClient.pilotHistory` (`LearningClient.swift:221-226`) | Paramètres de route `pilotId`, `contentDigest` | `PilotHistory` (`[PilotLessonProgress]`) (`Contracts.swift:188-210`) | `PilotHistory.validated(for: snapshot)` vérifie `pilotId`, `contentDigest`, unicité et appartenance des `lessonId`, et `lessons.first?.lessonId == lastLessonId` (`Contracts.swift:201-209`). | `PilotLearningFunctions.GetHistory` (`backend/src/Certigo.Api/Functions/PilotLearningFunctions.cs:36-54`) → `PilotHistoryDto` (`PilotLearningDtos.cs:8-12`) |
| 18 | `POST` | `/me/pilots/{pilotId}/lessons/{lessonId}/access/{contentDigest}` | `CertigoAPI.recordPilotLessonAccess(_:lessonId:credentials:)` (`CertigoAPI.swift:291-296,305-327`) · `LearningClient.recordPilotLessonAccess` (`LearningClient.swift:228-236`) | Paramètres de route `pilotId`, `lessonId`, `contentDigest` (corps vide) | `PilotLessonProgress` (`Contracts.swift:188-193`) | Vérifie que `lessonId` appartient au snapshot validé et que `result.lessonId == lessonId` (`CertigoAPI.swift:311-326`). | `PilotLearningFunctions.RecordAccess` (`backend/src/Certigo.Api/Functions/PilotLearningFunctions.cs:56-67,82-102`) → `PilotLessonProgressDto` (`PilotLearningDtos.cs:3-6`) |
| 19 | `POST` | `/me/pilots/{pilotId}/lessons/{lessonId}/read/{contentDigest}` | `CertigoAPI.markPilotLessonRead(_:lessonId:credentials:)` (`CertigoAPI.swift:298-327`) · `LearningClient.markPilotLessonRead` (`LearningClient.swift:238-246`) | Paramètres de route `pilotId`, `lessonId`, `contentDigest` (corps vide) | `PilotLessonProgress` (`Contracts.swift:188-193`) | Exige `result.lessonId == lessonId` et `result.markedReadAt != nil` (`CertigoAPI.swift:323-325`). | `PilotLearningFunctions.MarkRead` (`backend/src/Certigo.Api/Functions/PilotLearningFunctions.cs:69-102`) → `PilotLessonProgressDto` (`PilotLearningDtos.cs:3-6`) |
| 20 | `GET` | `/me/history?limit={1..50}&cursor={cursor}` | `CertigoAPI.history(credentials:limit:cursor:)` (`CertigoAPI.swift:340-354`) · `LearningClient.history` (`LearningClient.swift:104-110`) | Query `limit` (`1...50`, défaut `20`), `cursor` optionnel (`^[A-Za-z0-9_-]{1,2048}$`) | `LearningHistoryPage` (`[QuizAttemptHistoryItem]`, `nextCursor`) (`Contracts.swift:428-524`) | `cachePolicy = .reloadIgnoringLocalCacheData` ; schéma fermé (`historyFields` rejette tout champ inconnu) ; `page.items.count <= limit` (`CertigoAPI.swift:400,352`, `Contracts.swift:434-524`). | `LearningFunctions.GetMyHistory` (`backend/src/Certigo.Api/Functions/LearningFunctions.cs:13-46`) → `IAttemptHistoryService.GetPageAsync` → `AttemptHistoryPageDto` (`AttemptHistoryDtos.cs:3-19`) |
| 21 | `GET` | `/account/deletion` | `CertigoAPI.accountDeletion(accessToken:proof:submit:)` (`submit = false`) (`CertigoAPI.swift:356-373`) · `LearningClient.accountDeletion` (`LearningClient.swift:81-91`) | — | `AccountDeletion` (`AccountDeletion.swift:4-34`) | Exige `baseURL.path == "api"`, `statusCode == 200`, et `AccountDeletion.validated()` (`totalSteps` `1...100`, cohérence `status` / timestamps / `completedSteps`) (`CertigoAPI.swift:360-372`, `AccountDeletion.swift:14-33`). | `AccountDeletionFunctions.Get` (`backend/src/Certigo.Api/Functions/AccountDeletionFunctions.cs:15-24`) → `IAccountDeletionService.GetStatusAsync` → `AccountDeletionDto` (`AccountDeletionDtos.cs:3-17`) |
| 22 | `POST` | `/account/deletion` | `CertigoAPI.accountDeletion(accessToken:proof:submit:)` (`submit = true`) (`CertigoAPI.swift:356-373`) · `LearningClient.accountDeletion` (`LearningClient.swift:81-91`) | En-tête `X-Certigo-Reauthentication: <idToken>` (`proof`, ≤ 32 768 octets sans espace) (`CertigoAPI.swift:406-412`), corps vide | `AccountDeletion` (`AccountDeletion.swift:4-34`) | Exige `(statusCode == 202 && status == .pending) \|\| (statusCode == 200 && status == .completed)` (`CertigoAPI.swift:367-371`). | `AccountDeletionFunctions.Request` (`backend/src/Certigo.Api/Functions/AccountDeletionFunctions.cs:26-60`) → `IAccountDeletionService.RequestAsync` |
| 23 | `GET` | `/content/releases/active/manifest` | `PublicReleaseAPI.activeManifest(credentials:ifNoneMatch:)` (`PublicReleaseAPI.swift:22-49`) · `LearningClient.synchronizePublicContent()` (`LearningClient.swift:255-283`) | En-tête optionnel `If-None-Match` (`PublicReleaseAPI.swift:99-104`) | `ActivePublicManifestFetch` (`PublicPackageManifest`, `ValidatedReleaseBinding`, `etag`) (`PublicReleaseAPI.swift:6-9`, `PublicReleaseContracts.swift:20-30`) | Transport borné à `2 Mio` (`BoundedHTTPTransport.swift:21`) ; vérifie `x-content-release-id`, `x-content-manifest-id`, `etag == "\"\(manifestId)\""`, `cache-control == {"private", "no-cache"}`, et digest canonique SHA-256 du manifeste v3 (`PublicReleaseAPI.swift:29-48`, `PublicReleaseContracts.swift:38-92`). | `ContentReleaseFunctions.GetActivePublicManifest` (`backend/src/Certigo.Api/Functions/ContentReleaseFunctions.cs:90-127`) → `IContentReleaseService.GetActivePublicManifestAsync` |
| 24 | `GET` | `/content/releases/{releaseId}/manifests/{publicManifestId}/files/{hash}/{*path}` | `PublicReleaseAPI.file(_:manifest:binding:credentials:)` (`PublicReleaseAPI.swift:51-78`) · `LearningClient.synchronizePublicContent()` (`LearningClient.swift:272-279`) | Paramètres de route validés (`releaseId`, `publicManifestId`, `hash`, segments de `file.path`) | `Data` validé par `PublicResourceReader.validate(_:file:)` (`PublicResourceReader.swift:17-39`) | Transport borné à `file.size` (≤ `2 Mio`) ; exige `statusCode == 200`, `etag == "\"sha256:\(file.hash)\""`, `x-content-release-id`, `x-content-manifest-id`, `x-content-sha256 == file.hash`, `accept-ranges == "none"`, `content-length == file.size`, `cache-control == {"private", "max-age=31536000", "immutable"}`, et SHA-256 exact (`PublicReleaseAPI.swift:67-77`). | `PublicContentFunctions.GetPublicFile` (`backend/src/Certigo.Api/Functions/PublicContentFunctions.cs:13-90`) → `IPublicContentFileService.GetAsync` |

### 2.2 Endpoints backend existants non appelés par `CertigoNative` (référence pour Phases 7–10 et DR-005)

Ces endpoints existent dans `backend/src/Certigo.Api/Functions/` et **ne doivent pas être cassés côté backend** (§9, §33, DR-005), même lorsque l'UI retire les mécaniques héritées de Flutter :

| Domaine | Endpoint(s) Backend | Fichier Backend (`fichier:ligne`) | Statut vis-à-vis du client iOS natif |
|---|---|---|---|
| Amis & classement amis | `GET /api/friends`, `POST /api/friends`, `DELETE /api/friends/{friendId}`, `GET /api/friends/leaderboard` | `backend/src/Certigo.Api/Functions/FriendFunctions.cs:11-53` | Réutilisable/adaptable en Phase 8 (`S-63`/`S-64`, privé par défaut, §10). |
| Ligues XP hebdomadaires | `GET /api/me/league`, `GET /api/me/league/resolution` | `backend/src/Certigo.Api/Functions/LeaderboardFunctions.cs:10-28` | **À ne pas brancher en l'état** (DR-005 retire les ligues XP à 10 paliers de l'UI ; Phase 8 cible des ligues de progression opt-in Glicko-2). |
| Quêtes (réclamation en gemmes) | `POST /api/quests/claim` | `backend/src/Certigo.Api/Functions/QuestFunctions.cs:21-30` | Non appelé par `CertigoNative` (qui lit uniquement `GET /api/quests` sans afficher les gemmes, `test_native_prism_presentation.py:284`). |
| Boutique & achats en gemmes | `GET /api/shop`, `POST /api/shop/purchase` | `backend/src/Certigo.Api/Functions/ShopFunctions.cs:11-30` | **Interdit dans l'UI cible** (§9, §33 REMOVE, DR-005). Le backend reste intact. |
| Réparation de série en gemmes | `GET /api/streak`, `POST /api/streak/repair` | `backend/src/Certigo.Api/Functions/StreakFunctions.cs:12-32` | **Interdit dans l'UI cible** (§9, §33 REMOVE, DR-005 : remplacé par le Rythme hebdomadaire avec 2 jours de repos et rattrapage gratuit par 3 rappels). |
| Saisons mensuelles | `GET /api/season`, `POST /api/season/claim` | `backend/src/Certigo.Api/Functions/SeasonFunctions.cs:11-30` | **Interdit dans l'UI cible** (§9, §33 REMOVE, DR-005). |
| Carte de partage quotidienne | `GET /api/share/daily` | `backend/src/Certigo.Api/Functions/ShareCardFunctions.cs:10-18` | À adapter en Phase 5/8 pour `S-95` (partage sans spoiler ni XP/mascotte). |
| Auth legacy / B2B / Santé / Admin | `AuthFunctions.cs:1-180`, `EnterpriseIdentityFunctions.cs:1-176`, `EnterpriseLearningMetricsFunctions.cs:1-101`, `EnterpriseLearningRecoveryFunctions.cs:1-30`, `OrganizationFunctions.cs:1-170`, `OrganizationShadowObservationFunctions.cs:1-42`, `VivaLearningFunctions.cs:1-55`, `HealthFunctions.cs:1-70`, `ContentReleaseFunctions.cs:15-88` | `backend/src/Certigo.Api/Functions/` | Hors périmètre UI apprenant iOS ; contrats backend préservés. |

---

## 3. Inventaire détaillé des 10 sous-systèmes « MUST NOT BREAK »

### 3.1 Notation et récompenses autoritatives côté serveur

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoDomain/Contracts.swift:250-354` :
    - `QuizItem` (`:250-266`) contient uniquement `id`, `conceptId`, `type`, `stem`, `options: [QuizOption]` — **aucun champ `correctAnswer` ni `explanation`**.
    - `QuizSubmission` (`:284-316`) tronque `startedAt` à la milliseconde (`:297-299`) pour garantir la reproductibilité JSON lors des réessais hors ligne, et valide `UUID(uuidString: clientAttemptId) != nil`, l'absence de doublon d'`itemId`, `itemType == "mcq"`, `selected.count == 1` et `latencyMs >= 0` (`:304-315`).
    - `QuizResult.validated(for: submission)` (`:325-336`) vérifie que `scorePct` est dans `0...100`, que les `itemId` corrigés sont un sous-ensemble sans doublon des `itemId` soumis, et que chaque `ItemResult` contient une `explanation` non vide et (si `correct == false`) un `correctAnswer` non vide.
    - `QuizRewards` (`:347-354`) : `xpEarned`, `newXp`, `levelUp`, `streakExtended`, `gemsEarned`, `achievementsUnlocked`.
  - `apps/apple/CertigoKit/Sources/CertigoData/PublicResourceReader.swift:12-15,242-253` :
    - `forbidden` rejette récursivement tout JSON public contenant `answerkey`, `correct`, `correctoptionids`, `explanation`, `privatemanifestid`, `rationale`, `releaseid`, `solution`.
  - `apps/apple/CertigoKit/Sources/CertigoCortex/Cortex.swift:231-252` :
    - `AnswerGrading.isCorrect` est explicitement documenté : `/// Use only an authorized answer/feedback, never an embedded private answer bank.` (`:232`).
  - `apps/apple/CertigoNative/Sources/NativeModel.swift:1883-1985` :
    - `submit()` persiste d'abord la barrière d'activité en vol (`saveActivity(submitting: request)` `:1911`), délègue à `LearningClient.submit` (`:1912`), puis rafraîchit le profil confirmé uniquement si la réponse est `.corrected` (`refreshConfirmedProfile` `:1978-1985`).
  - `backend/src/Certigo.Application/Services/QuizService.cs:37-294,350-491` :
    - `SubmitAsync` vérifie l'opération durable `EconomyOperationRecord.IdFor("quiz", request.ClientAttemptId)` (`:46-54`) et l'historique `attempts.GetByClientAttemptIdAsync` (`:56-62`), charge la clé de correction privée via `content.GetAnswerKeyAsync(snapshot, request.TrackId, lessonId)` (`:67-72`), calcule FSRS (`ReviewScheduler.Apply` `:97-99`), évalue l'anti-triche (`AttemptIntegrityEvaluator.Evaluate` `:207-257` — en cas de `Reject`, 0 XP / 0 gemme et aucune mutation du profil), puis exécute le journal durable en 6 étapes (`profile`, `attempt`, `progress`, `learnerModel`, `leaderboard`, `events` `:34-35,350-491`).
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/ContractTests.swift:70-163` (`testPublicLessonUsesOptionLabelsAndContainsNoAnswerKeys:70`, `testResultCannotInventUnrequestedItems:92`, `testCorrectResultMayOmitCorrectAnswerIDs:103`, `testSubmissionRoundTripPreservesWireTimeAndAttemptID:123`, `testAPIEncodesExistingSubmitRouteAndRawAnswers:144`)
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/PublicResourceTests.swift:22-39` (`testRuntimeBlocksDoNotEmbedCorrectionKeysOrInlineVerdicts:22`)
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/SharedHTTPWireTests.swift:112-158` (`testSharedAuthorizedResultsKeepWrongAnswerIDsAndCorrectNullFeedbackDistinct:130`)
  - `apps/apple/CertigoNative/ModelTests/NativeModelTests.swift:1510-1633` (`confirmedProfileAfterCorrection:1510`, `confirmedProfileAfterPendingRetry:1535`, `confirmedProfileFailurePreservesCorrection:1559`, `lateConfirmedProfileIsNotRepublished:1589`)
- **Risque en cas de modification :** **CRITIQUE (Élevé)**. Exposer une clé de correction côté client compromettrait l'intégrité des évaluations et la conformité éditeur ; modifier le calcul de `startedAt` ou la validation de `QuizResult` casserait l'idempotence et le journal économique durable (`DurableEconomy`).

---

### 3.2 File de soumission hors ligne et idempotence (`SubmissionStore.swift`, `SavedSubmission`, `clientAttemptId`)

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoData/SubmissionStore.swift:4-186` :
    - Note : le type dans le code Swift est nommé `SavedSubmission` (`:7-24`, avec `id: String { submission.clientAttemptId }` `:8` et `status: SubmissionStatus` `.pendingCorrection | .corrected | .failed` `:4-6`), correspondant au concept fonctionnel `PendingSubmission`.
    - `Archive` (`:32-35,41`) : schéma strict `"certigo.apple.submissions/v1"`, taille fichier maximale `8 Mio` (`8 * 1_024 * 1_024` `:133-137,168`), capacité maximale `1 000` entrées (`:69,142`).
    - `enqueue(_:)` (`:57-73`) : si un `SavedSubmission` avec le même `id` (`clientAttemptId`) existe déjà, vérifie que `ownerId`, `apiScope`, `lessonId` et `submission` sont **strictement identiques** (retourne l'existant de manière idempotente) ; sinon lève `StoreError.conflictingAttempt` (`:61-68`).
    - `manifestPins()` (`:49-55`) : extrait tous les `RuntimeManifestPin(ownerId:apiScope:manifestId:)` des soumissions stockées pour empêcher le nettoyage du pack hors ligne correspondant avant correction serveur.
    - `suspend(ownerId:apiScope:suspended:)` (`:103-109`) et `purge(ownerId:apiScope:)` (`:111-117`) : bloquent toute écriture tardive (`APIError.staleSession` dans `requireWritable` `:119-124`) lors d'une déconnexion ou suppression de compte.
  - `apps/apple/CertigoKit/Sources/CertigoData/LearningClient.swift:332-395` :
    - `submit(lessonId:submission:)` épingle d'abord `submission.publicManifestId` dans `runtimeStore` (`:337-342`), enfile dans `SubmissionStore` (`:343-347`), puis appelle `send(_:context:)` (`:349`).
    - `send(_:context:)` (`:362-395`) déduplique les envois concurrents via `sending: Set<String>` (`:367-369`), retourne `.pendingCorrection` sans marquer d'échec si `APIError.isRetryable` (`408`, `429`, `500...599`, ou erreurs réseau `URLError` `:15-26,376-379`), ne marque pas d'échec sur `.unauthorized` ni `URLError.cancelled` (`:380-383`), et enregistre le `QuizResult` sur le compte d'origine (`:391-394`).
  - `apps/apple/CertigoKit/Sources/CertigoData/LearningHistoryPresentation.swift:43-89` :
    - Réconcilie par `QuizAttemptHistoryItem.key(clientAttemptId)` (`Contracts.swift:467-471`) l'historique serveur (`confirmed`), les soumissions corrigées localement pas encore paginées (`confirmedOnDevice`) et les soumissions en attente/échouées (`onDevice`), en rejetant toute divergence de score/XP/gemmes (`ContractError.malformed("history correction identity")` `:63-70`).
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/SubmissionTests.swift:73-305` (`testQueueSurvivesRestartWithoutChangingAttemptOrOwner:73`, `testSameAttemptCannotBeReassignedToAnotherOwner:98`, `testMalformedArchiveIsNotSilentlyReplacedWithEmptyQueue:119`, `testOfflineAnswerRemainsPendingUntilServerCorrectsExactlySamePayload:133`, `testOwnerSwitchCannotReplayPreviousAccountQueue:166`, `testCancelledSubmissionRemainsPendingAndCanReplayAfterRestart:190`, `testNonCancellationTransportFailureStillRequiresReview:198`)
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/LearningHistoryTests.swift:52-302` (`testDeterministicMergeKeepsLocalWorkAndNeverFabricatesCorrection:193`, `testConflictsRejectInsteadOfLastWriterWinsAndTiesAreStable:234`)
- **Risque en cas de modification :** **CRITIQUE (Élevé)**. Perte de réponses soumises hors ligne, double facturation d'XP, fuite de tentatives entre deux comptes sur le même appareil, ou suppression prématurée d'un manifeste requis par une tentative en attente.

---

### 3.3 Packs de questions hors ligne et stockage disque (`OfflineQuestionPack.swift`, `RuntimeContentStore.swift`, `RuntimeDisk.swift`, `CanonicalQuestionReader.swift`)

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoData/CanonicalQuestionReader.swift:53-217` :
    - Décode et valide les questions canoniques publiques `schemaVersion` `"v3"` et `"v4"`, `kind == "public"`, `provider` (`aws|gcp|microsoft`), `itemType` (`mcq`, `multi`, `scenario`, `spotTheIssue` en v4, mais `requireBasicCapability()` `:43-47` restreint l'exécution actuelle à `"mcq"`), options uniques (`:104-115`), et vérifie `SHA256` + taille (`maximumPayloadBytes = 2 Mio` `:54,138-155`).
  - `apps/apple/CertigoKit/Sources/CertigoData/OfflineQuestionPack.swift:4-194` :
    - `OfflineQuestionPackReader.read(trackId:snapshot:file:)` reconstruit les `[Lesson]` d'un `trackId` à partir du snapshot local vérifié en mode `"questionBank"` (`:90-123`) ou `"guided"` (`:124-167`), vérifie la cohérence croisée `certificationId` / `blueprintVersion` / `domainId` / `conceptId` (`:51-56,127-158`), et calcule les identifiants d'options v3 déterministes (`optionId(_:)` `:176-193`) compatibles avec `ContentContractVerifier.OptionId` côté `.NET`.
  - `apps/apple/CertigoKit/Sources/CertigoData/RuntimeContentStore.swift:21-430` :
    - Schéma `"certigo.apple.runtime-cache/v1"` (`:44`), quota par défaut `384 Mio` (`:48`), jusqu'à `256` scopes `(ownerId, apiScope)` et `1 000` pins (`:377`).
    - Stockage CAS (Content-Addressed Storage) : état dans `state.json`, capsules de manifeste dans `x-<sha256>.json` (`:412-417`), blobs de ressources dans `b-<sha256>.json` (`:418-420`).
    - Cycle transactionnel en 2 phases : `begin(_:)` stage la capsule (`:149-185`), `saveFile(_:file:)` valide chaque ressource via `PublicResourceReader.validate` avant écriture (`:191-201`), et `activate(_:)` bascule `active` → `previous` et `staged` → `active` seulement après `verifyComplete` de 100 % des fichiers du manifeste (`:203-224,330-335`).
    - `cleanup()` (`:249-284`) protège `active`, `previous`, `staged` de tous les scopes ainsi que tous les `RuntimeManifestPin` de `SubmissionStore`, et supprime au maximum `32` fichiers obsolètes par passe (`:281-282`).
  - `apps/apple/CertigoKit/Sources/CertigoData/RuntimeDisk.swift:27-409` :
    - Valide toute la chaîne de répertoires ancêtres par `lstat` / `fstat` (numéros `st_dev` et `st_ino`) pour empêcher toute attaque par lien symbolique (`O_NOFOLLOW`), FIFO ou lien dur (`st_nlink == 1`) (`:55-145,191-203`).
    - Sérialise les accès inter-processus via `flock(lockFile, LOCK_EX | LOCK_NB)` sur `.lock` (`:125-126,180-187`).
    - Écrit dans `.tmp-<UUID>`, applique la classe de protection iOS, `fsync(handle)`, `renameat`, puis `fsync(directory)` (`:223-265`).
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/CanonicalContentTests.swift:6-211`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/OfflineLearningTests.swift:8-149`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/PublicReleaseAPITests.swift:16-288`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/PublicReleaseContractTests.swift:12-198`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/PublicResourceTests.swift:7-216`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/RuntimeClientTests.swift:83-555`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/RuntimeStoreTests.swift:81-552`
- **Risque en cas de modification :** **CRITIQUE (Élevé)**. Corruption du cache hors ligne, désynchronisation des IDs d'options v3 avec le serveur (rendant les soumissions hors ligne fausses), ou vulnérabilité de traversée de chemin / symlink. Note pour la Phase 4 : l'ajout des nouveaux formats d'items (`spotTheIssue`, `ordering`, etc.) dans `CanonicalQuestionReader.requireBasicCapability()` (`CanonicalQuestionReader.swift:43-47`), `QuizItem.validateCapability()` (`Contracts.swift:257-265`) et `QuizSubmission.validated()` (`Contracts.swift:307-310`) devra être **strictement additif** et synchronisé avec `ExerciseItemsV5Rules.cs`.

---

### 3.4 Protection des fichiers (`FileProtectionPolicy.swift`, `completeUntilFirstUserAuthentication`)

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoData/FileProtectionPolicy.swift:3-48` :
    - Vérifie que l'attribut `.protectionKey` vaut exactement `FileProtectionType.completeUntilFirstUserAuthentication` (`"NSFileProtectionCompleteUntilFirstUserAuthentication"`), et distingue explicitement `.missingAttribute`, `.nonstringAttribute`, `.differentKnownPolicy` (dont `NSFileProtectionNone`, `NSFileProtectionComplete`, `NSFileProtectionCompleteUnlessOpen`) et `.unrecognizedPolicy`.
  - `apps/apple/CertigoKit/Sources/CertigoAppleFileIO/include/CertigoAppleFileIO.h:6-8` & `CertigoAppleFileIO.c:7-21` :
    - Expose `certigo_file_path` (`fcntl(fd, F_GETPATH)`), `certigo_file_protection` (`fcntl(fd, F_GETPROTECTIONCLASS)`) et `certigo_set_file_protection` (`fcntl(fd, F_SETPROTECTIONCLASS, protection)`).
  - `apps/apple/CertigoKit/Sources/CertigoData/RuntimeDisk.swift:236-244,267-321` :
    - Sans deviner de constante entière Darwin privée, crée un fichier témoin éphémère `.tmp-<UUID>`, lui applique `FileProtectionType.completeUntilFirstUserAuthentication` via `FileManager`, vérifie l'attribut avec `FileProtectionPolicy.requireFirstUnlock` et l'identité d'inode (`st_dev`/`st_ino`), lit la classe numérique via `certigo_file_protection(handle)`, supprime le témoin, puis applique et relit cette classe sur chaque descripteur avant écriture des octets.
  - Autres magasins protégés en `completeUntilFirstUserAuthentication` :
    - `SubmissionStore.persist` (`apps/apple/CertigoKit/Sources/CertigoData/SubmissionStore.swift:171-183`) ;
    - `NativeActivityStore.writeProtected` (`apps/apple/CertigoNative/Sources/NativeModel.swift:377-391`) couvrant `activity-v1.json`, `account-deletion-v1.json` et `exam-<sha256>.json` ;
    - `CertigoWidgetStore.write` et vérification à la lecture dans `CertigoWidgetStore.read` (`apps/apple/CertigoKit/Sources/CertigoData/CertigoWidgetStore.swift:79-89,108-112`).
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/FileProtectionPolicyTests.swift:7-38`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/RuntimeDiskProtectionTests.swift:8-70`
  - Projets dédiés `apps/apple/CertigoProtectionTests/CertigoProtectionTests.xcodeproj` et `apps/apple/CertigoProtectionDeviceTests/CertigoProtectionDeviceTests.xcodeproj`
- **Risque en cas de modification :** **ÉLEVÉ**. Régression de sécurité des données au repos sur iOS, ou illisibilité des snapshots par `CertigoWidgetExtension` en arrière-plan après le premier déverrouillage si `NSFileProtectionComplete` strict était appliqué par erreur au conteneur partagé.

---

### 3.5 Keychain (`CredentialVault.swift`)

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoNative/Sources/CredentialVault.swift:1-48` :
    - Implémente `DeveloperConnectionVault` (`apps/apple/CertigoNative/Sources/NativeModel.swift:25-29`) pour persister `DeveloperConnection { baseURL: String, token: String }` (`NativeModel.swift:21-24`).
    - Requête Keychain (`:9-15`) : `kSecClassGenericPassword`, `kSecAttrService: "com.certigo.native.dev.session"`, `kSecAttrAccount: "developer-connection"`.
    - Protection matérielle (`:31-34`) : `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (jamais synchronisé par iCloud Keychain ni sauvegardé hors de l'appareil).
    - `read()` (`:17-27`), `save(_:)` (`:29-40` via `SecItemUpdate` puis `SecItemAdd`), `clear()` (`:42-47` via `SecItemDelete`, tolérant `errSecItemNotFound`).
- **Tests existants :**
  - `apps/apple/CertigoNative/ModelTests/NativeModelTests.swift:13-41,1183-1267,2403-2420,2543-2556` (`MemoryVault`, vérification que `vault.clear()` est appelé à la déconnexion et lors de l'étape `"vault"` de `performDeletionCleanup`, et que l'échec de `clear()` bloque l'état en `.cleanupFailed`).
- **Risque en cas de modification :** **ÉLEVÉ**. Persistance résiduelle d'un jeton après déconnexion ou suppression de compte, ou migration accidentelle de jetons vers un autre appareil via sauvegarde iCloud.

---

### 3.6 Authentification MSAL / Entra External ID CIAM

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoData/CIAMConfiguration.swift:17-122` :
    - Note d'audit : la validation d'autorité (désignée `CIAMAuthorityValidation` dans la documentation d'architecture) est implémentée directement dans `CIAMConfiguration.init` (`:32-103`) — il n'existe pas de fichier séparé `CIAMAuthorityValidation.swift`.
    - Vérifie que `clientID`, `tenantID` et `apiAudience` sont des UUID valides (`:38-40`).
    - Vérifie `isHTTPSOrigin(authority)` et `isHTTPSOrigin(issuer)` (HTTPS, port nil ou 443, sans user/password/query/fragment `:100-103`).
    - En mode `.standard`, exige un hôte `<subdomain>.ciamlogin.com` à 3 labels et un chemin vide, `"/"` ou `"/<tenant-id-lowercase>"` (`:46-51`) ; en mode `.customDomain`, exige `authority.path == "/<tenant-id-lowercase>"` (`:52-55`).
    - Exige `issuer.host == authority.host` et `issuer.path == "/<tenant-id-lowercase>/v2.0"` (`:57-59`).
    - Exige `apiScope` de la forme `"api://<apiAudience>/<permission>"` (caractères `[A-Za-z0-9_.-]` `:65-73`).
    - Exige un `redirectURI` à schéma personnalisé non HTTP(S), exactement enregistré dans `registeredRedirects`, déclaré dans `declaredCallbackSchemes` et absent de `otherAppCallbackSchemes` (pour interdire toute collision avec le callback Flutter `certigo://auth` `:74-89`).
  - `apps/apple/CertigoKit/Sources/CertigoData/CIAMConfigurationEnvironment.swift:40-237` :
    - `configuration(...)` (`:52-74`) : refuse `CERTIGO_CIAM_ENABLED == "true"` si `!isDevelopmentBuild` (`releaseOptInNotAllowed` `:67-69`).
    - `productionConfiguration(...)` (`:76-109`) : exige `!isDevelopmentBuild` (`productionBuildRequired`), `bundleIdentifier == "com.certigo.mobileapp"` (`unsupportedProductionBundle`), `CertigoProductionAuthMode == "microsoft"`, et rejette toute variable Xcode non substituée contenant `"$("` (`:99-101`).
    - Impose `redirectURI == "msauth.\(bundleIdentifier)://auth"` déclaré **exactement une fois** dans `CFBundleURLTypes` (`:168-183`).
  - `apps/apple/CertigoKit/Sources/CertigoData/CIAMDevelopmentCandidate.swift:4-37` :
    - Métadonnées publiques de développement observées : `bundleIdentifier = "com.certigo.native.dev"`, `clientID = "<redacted-client-id>"` (`:7`), `tenantID = "<redacted-tenant-id>"` (`:8`), `apiAudience = "<redacted-api-audience>"` (`:9`), `redirect = "msauth.com.certigo.native.dev://auth"` (`:10`), `apiBaseURL = "<redacted-endpoint>/api"` (`:31`), et `historicallyRegisteredRedirects = ["certigo://auth", "certigo://auth/"]` (`:11-13` — réservés à l'historique Flutter, jamais réutilisés comme redirect MSAL natif).
  - `apps/apple/CertigoNative/Sources/MSALAuthenticationProvider.swift:8-243` :
    - Ajoute explicitement `/<tenantID>` aux URL d'autorité sans chemin pour empêcher MSAL 2.16.0 de synthétiser `<host-prefix>.onmicrosoft.com` (`:35-41`).
    - Configure `keychainSharingGroup = bundleIdentifier`, `brokerAvailability = .none`, `loggerConfig.logLevel = .nothing` (`:49-51`).
    - Utilise `ASWebAuthenticationSession` éphémère (`webviewType = .authenticationSession`, `prefersEphemeralWebBrowserSession = true` `:105-107,133-135`).
    - Dans `accept(_:)` (`:204-221`), vérifie la présence de `configuration.apiScope`, la non-expiration, le schéma `"Bearer"`, l'hôte d'autorité et le `tenantId`, et conserve `accountIdentifier` **uniquement** pour le cache MSAL (jamais comme `ownerId` métier, qui provient exclusivement de `GET /api/me` `:217`).
  - Fichiers `Info.plist` :
    - `apps/apple/CertigoNative/DevelopmentInfo.plist:5-23` déclare `msauth.com.certigo.native.dev` (auth MSAL) et `certigo` (deep links widgets `certigo://widget/learn|review`).
    - `apps/apple/CertigoNative/DistributionInfo.plist:5-42` déclare `msauth.com.certigo.mobileapp`, `certigo`, et les clés `CertigoProductionCIAM*`.
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/CIAMConfigurationTests.swift:11-589` (27 tests unitaires)
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/CIAMProviderPolicyTests.swift:6-41`
  - `apps/apple/CertigoNative/ModelTests/NativeModelTests.swift:2421-2572` (`authoritativeOwnerAndRefresh:2421`, `expiredTokenAndSilentFailure:2451`, `logoutDuringLogin:2498`, `refusedCacheRemoval:2543`)
  - `tools/tests/test_native_ciam_scheme.py:1-319` & `tools/tests/test_native_distribution.py:48-94,158-211`
- **Risque en cas de modification :** **CRITIQUE (Élevé)**. Rupture totale de la connexion en production ou en développement, fuite de diagnostic d'erreur contenant des jetons (`CIAMAuthenticationFailure.classify` filtre strictement `userInfo`), ou confusion d'identité entre comptes.

---

### 3.7 Suppression de compte (`AccountDeletion.swift`, purge locale multi-magasins)

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoData/AccountDeletion.swift:4-86` :
    - `AccountDeletion.validated()` (`:14-33`) vérifie l'intégrité de l'état renvoyé par le serveur (`.notRequested`, `.pending`, `.completed`).
    - `CIAMDeletionProof.validated(expectedAccount:clientID:now:)` (`:49-79`) vérifie localement avant l'envoi que le compte MSAL n'a pas changé (`accountIdentifier == expectedAccount`), que l'`idToken` est un JWT à 3 segments ≤ 32 Kio, que `aud == clientID`, et que `auth_time` est un entier dans `[now - 600 s, now + 120 s]` avec `exp > now`.
  - `apps/apple/CertigoNative/Sources/NativeModel.swift:400-428,566-585,700-1052` :
    - `verifyDeletionIdentity()` (`:722-774`) suspend `SubmissionStore` via `pauseForAccountDeletion()` (`LearningClient.swift:48-59`), interroge `GET /api/account/deletion`, puis déclenche `reauthenticateForAccountDeletion()`.
    - `confirmAccountDeletion()` (`:809-840`) persiste d'abord un reçu `NativeDeletionReceipt` en phase `.unconfirmed` dans `account-deletion-v1.json` (`:825-826`), puis envoie `POST /api/account/deletion` avec `X-Certigo-Reauthentication: <idToken>` (`:830-831`).
    - `acceptDeletionStatus(_:)` (`:878-907`) : lorsque le serveur confirme `.completed`, écrit le reçu durable avec `remainingCleanup = ["learning", "activity", "vault", "msal"]` (`:898`) et `signedOutKey = true` **avant** de lancer `performDeletionCleanup()` (`:981-1038`).
    - `performDeletionCleanup()` (`:981-1038`) exécute séquentiellement et persiste l'avancement du reçu après chaque cible :
      1. `"learning"` (`:995-1004`) : `cleaner.purgeDeletedAccount(ownerId: owner)` (qui purge `SubmissionStore` et `RuntimeContentStore`, `LearningClient.swift:93-102`), `examStore(owner:scope:).clear()`, et suppression des clés `UserDefaults` préfixées par `studyPlanPrefix(owner:scope:)`.
      2. `"activity"` (`:1005-1014`) : `activityStore().clear()` si le snapshot appartient à `(owner, apiScope)`.
      3. `"vault"` (`:1015-1016`) : `vault.clear()` (Keychain).
      4. `"msal"` (`:1017-1024`) : `provider.removeAccountForDeletion(identifier: receipt.accountIdentifier)`.
  - **Observation importante sur les ajouts PR #100 / PR #101 (`CertigoWidgetStore` & `CertigoAppIconPreferenceStore`) :**
    - Dans `CertigoNativeApp.swift:6108-6111,6138-6140,6147-6149`, lorsque `model.profile?.id` passe à `nil` pendant que `NativeRoot` est monté, `.onChange(of: model.profile?.id)` appelle `appIconController.resetForSignedOut()` (qui appelle `CertigoAppIconPreferenceStore.reset()`, `NativeWidgetGalleryView.swift:421-426`) et `.onChange(of: widgetSnapshotKey)` appelle `widgetController.refresh(profile: nil, ...)` → `widgetController.clear()` (qui supprime `snapshot.json` via `CertigoWidgetStore.clear()` et recharge les timelines WidgetKit, `NativeWidgetGalleryView.swift:505-507,545-556`).
    - **Point d'attention pour la Phase 1 / Phase 10 :** `performDeletionCleanup()` dans `NativeModel.swift:981-1038` n'appelle pas directement `CertigoWidgetStore.clear()` ni `CertigoAppIconPreferenceStore.reset()`. Si l'application redémarre à froid sur un reçu `account-deletion-v1.json` en phase `.completed` avec `remainingCleanup` non vide (`restoreAccountDeletionIfNeeded()` `:566-585`), `model.profile` est déjà `nil` dès le lancement (`onChange(of: model.profile?.id, initial: true)` s'exécute toutefois à l'apparition de `NativeRoot` `:6108`). Il conviendra de conserver ce déclenchement initial et d'ajouter un test de caractérisation couvrant la purge du widget et de l'icône lors d'une suppression de compte.
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/AccountDeletionTests.swift:44-231`
  - `apps/apple/CertigoNative/ModelTests/NativeModelTests.swift:1023-1388` (`historyErrorsAndDeletion:1023`, `deletionProofAndCancellation:1139`, `deletionPendingRecoveryAndCleanup:1183`, `deletionLostResponse:1269`, `deletionRecoveryWithoutOwner:1287`, `deletionMissingRequestRecovery:1304`, `deletionUnavailable:1325`, `deletionReceiptWriteFailure:1346`, `deletionFirstLaunchAndCorruptReceipt:1368`)
- **Risque en cas de modification :** **CRITIQUE (Élevé)**. Non-conformité App Store Review Guideline 5.1.1(v) et RGPD si la suppression de compte échoue, laisse des données locales d'un compte supprimé, ou permet d'annuler localement une suppression déjà engagée côté serveur.

---

### 3.8 Préférence de langue et non-traduction du contenu officiel (`AppLanguage.swift`)

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoDomain/AppLanguage.swift:3-97` :
    - 8 langues canoniques exactes (`:3-12`) : `.french = "fr"`, `.english = "en"`, `.hindi = "hi"`, `.chineseSimplified = "zh-Hans"`, `.korean = "ko"`, `.spanish = "es"`, `.italian = "it"`, `.german = "de"`.
    - `AppLanguage.resolved(fromPreferredLanguages:)` (`:32-54`) : refuse explicitement d'assimiler `zh-Hant` ou les régions `TW`, `HK`, `MO` à `zh-Hans` (`:39-48`), et replie par défaut sur `.english` (`:53`).
    - `AppLanguagePreference` (`:56-97`) : `.system` ou `.explicit(AppLanguage)`, persisté dans `UserDefaults.standard` sous la clé `"certigo.app.interface-language.v1"` (`:61`).
    - `AppInterfaceCopy` (`:98-2147`) et `AppInterfaceCopy.NativeLabel` (`apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:313-2750`) : dictionnaires exhaustifs vérifiés par précondition (8 traductions par clé, aucun repli silencieux vers l'anglais).
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:203-214,2756-2772,3093-3157` :
    - `NativeLanguageRoot` (`:3093-3123`) injecte `.environment(\.locale, effectiveLanguage.locale)` et `.environment(\.nativeInterfaceCopy, AppInterfaceCopy(language: effectiveLanguage))` à la racine de l'app et rafraîchit au retour au premier plan (`scenePhase == .active`).
    - `NativeDeclaredContentLanguage` (`:203-214`) et `NativeContentLanguageBadges` (`:2756-2772`) affichent la langue déclarée du contenu (`FR` / `EN`) à partir des métadonnées explicites (`track.languages` ou `snapshot.pilot.locale`), accompagnée de la mention `copy.contentLanguageNote` rappelant que le contenu pédagogique et de certification n'est jamais traduit automatiquement.
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/AppLanguageTests.swift:6-257`
  - `apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift:25-66`
  - `tools/tests/test_native_prism_presentation.py:180-237,481-522,604-651`
- **Risque en cas de modification :** **MOYEN à ÉLEVÉ**. Crash au rendu si une clé `NativeLabel` ne comporte pas 8 entrées (`precondition(row.count == 8)`), régression linguistique sur `zh-Hant`, ou altération des intitulés officiels d'examens/produits.

---

### 3.9 Préférences du plan d'étude et moteurs de révision (`CertigoStudyPlanPreference.swift`, `SmartReviewAdvisor.swift`, `LearningServices.swift`, `Cortex.swift`)

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoDomain/CertigoStudyPlanPreference.swift:3-52` :
    - `InitialLevel` (`.beginner`, `.intermediate`, `.advanced`), `targetExamDate: Date?` (finie), `dailyMinutesGoal: Int` borné à `1...1_440` (`:17-22`).
    - Clé par défaut `"certigo.study-plan.v1"` (`:8`), surchargée dans `NativeModel` par une clé scopée par utilisateur, environnement API et objectif actif : `"certigo.native.study-plan.<sha256([owner, scope])>.<sha256(trackId)>"` (`apps/apple/CertigoNative/Sources/NativeModel.swift:1625-1638`).
  - `apps/apple/CertigoKit/Sources/CertigoDomain/SmartReviewAdvisor.swift:3-196` :
    - `SkillBand.resolved(percent:)` (`:3-14`) : `>= 80` → `.strong`, `>= 55` → `.developing`, `< 55` → `.weak`.
    - `MasteryStage.resolved(coverage:mastery:score:)` (`:15-48`) : présentation conservatrice (`notStarted`, `learning`, `practicing`, `mastered`, `examReady` uniquement si `coverage == 1 && mastery == 1 && score == 100`).
    - `SmartReviewAdvisor.focusArea(readiness:path:recommendations:)` (`:86-133`) : identifie le domaine le plus faible et associe uniquement une recommandation déverrouillée du même `trackId`.
    - `SmartReviewAdvisor.recommend(path:history:localResults:)` (`:136-195`) : priorise dans l'ordre `.recurringErrors` (2 dernières tentatives < 100 %) → `.lowestScore` → `.nextUnlockedUnit` (`.inProgress`) → `.notYetAttempted` (`.available`), sans jamais permettre à un résultat local non horodaté d'écraser l'historique serveur daté (`:160-165`).
  - `apps/apple/CertigoKit/Sources/CertigoCortex/Cortex.swift:1-252` :
    - Implémentation Swift de référence (`CortexAlgorithm.version = "1.0.0"`) alignée au bit près sur les vecteurs partagés `.NET` (`ReviewScheduler`, `ReadinessCalculator` avec arrondi bancaire `.toNearestOrEven`, `SessionPlanner`, `AnswerGrading`).
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/SmartReviewAdvisorTests.swift:37-208`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/LearningServiceTests.swift:105-414`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/CortexTests.swift:8-312`
  - `apps/apple/CertigoNative/ModelTests/NativeModelTests.swift:641-729` (`internationalLearningServices`)
- **Risque en cas de modification :** **MOYEN à ÉLEVÉ**. Divergence entre les recommandations affichées et l'état serveur, fuite des préférences d'un parcours ou d'un compte vers un autre, ou rupture de la porte de parité Cortex (`CortexTests`).

---

### 3.10 Widgets et icônes dynamiques (`CertigoWidgetSnapshot.swift`, `CertigoWidgetStore.swift`, `CertigoAppIconSelection.swift`, `CertigoAppIconPreferenceStore.swift`)

- **Preuves exactes (`fichier:ligne`) :**
  - `apps/apple/CertigoKit/Sources/CertigoDomain/CertigoWidgetSnapshot.swift:3-542` :
    - `CertigoWidgetPhase` (`.readyToStart`, `.inProgress`, `.streakAtRisk`, `.goalCompleted` `:3-8`).
    - `CertigoWidgetRoute` (`.learn` → `certigo://widget/learn`, `.review` → `certigo://widget/review` `:10-31`) avec validation stricte du schéma, de l'hôte et du chemin sans query/fragment.
    - `CertigoWidgetSnapshot` (`schemaVersion = 1` `:38-92`) : **ne contient aucun `ownerId`, email ou jeton**, valide les bornes temporelles (`validUntil > updatedAt`, `<= 36 h`, même jour local `studyDay` `:169-189`), calcule `serverStreakRisk` uniquement à partir d'une notification serveur `"StreakDanger"` du jour local courant (`:123-129`), et vérifie la fraîcheur via `isFresh(at:)` (`:191-199`).
  - `apps/apple/CertigoKit/Sources/CertigoData/CertigoWidgetStore.swift:4-167` :
    - Identifiant App Group par défaut `"group.com.certigo.native"` (`:22`), taille max `64 Kio` (`:23`), fichier `CertigoWidget/snapshot.json` protégé par `completeUntilFirstUserAuthentication` (`:79-89,108-112`).
    - L'extension `CertigoWidgetExtension` instancie `CertigoWidgetStore(sharedContainerOnly: true)` (`apps/apple/CertigoNative/WidgetExtension/CertigoWidgetExtension.swift:37`), qui échoue de façon fermée (`.sharedContainerUnavailable`) tant que l'entitlement App Group n'est pas provisionné.
  - `apps/apple/CertigoKit/Sources/CertigoDomain/CertigoAppIconSelection.swift:3-231` & `apps/apple/CertigoKit/Sources/CertigoData/CertigoAppIconPreferenceStore.swift:4-50` :
    - 4 variantes (`standard`, `streakFire`, `streakAtRisk`, `masteryGold`), mode `.automatic` (par défaut) ou `.manual`, persisté sous `"com.certigo.native.app-icon-preferences.v1"`.
    - `shouldApply` (`CertigoAppIconSelection.swift:27-35`) exige `supportsAlternateIcons && applicationIsActive && alternateIconName != currentAlternateIconName`.
- **Tests existants :**
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/CertigoWidgetTests.swift:36-290`
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/AppIconSelectionTests.swift:7-75`
  - `tools/tests/test_native_source_membership.py:112-156` & `tools/tests/test_native_distribution.py:95-157`
- **Risque en cas de modification et tension avec le Master Prompt :** **MOYEN (Technique) / ÉLEVÉ (Produit — voir DR-001 et DR-005)**.
  - *Technique :* supprimer ou renommer les `.appiconset` sans mettre à jour `project.pbxproj:308-313,364-369,396-401` et `test_native_distribution.py:95-157` casserait le build et la CI.
  - *Produit :* le mode `.automatic` actuel bascule automatiquement l'icône de l'app vers `streakAtRisk` (« Série à préserver » / `"Streak at risk"`) lorsque `phase == .streakAtRisk` (`CertigoAppIconSelection.swift:60,135-142`), et `CertigoWidgetSnapshot` affiche l'état `streakAtRisk` avec XP (`CertigoWidgetPresentation.swift:45,143,160`). Or le Master Prompt (§7, §8, §9, §33 REMOVE) interdit l'XP visible, les messages de perte/culpabilisation et les rappels anxiogènes de série. Ce point fait l'objet d'un arbitrage explicite dans **DR-001** et **DR-005**.
