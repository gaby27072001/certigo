import Foundation

enum NativeRadarCategory: String, CaseIterable, Sendable {
    case cloud = "cloud-hyperscalers"
    case ai = "ai-foundation-models"
    case apple = "apple-mobile"
    case data = "data-analytics"
    case devops = "devops-cloud-native-dev"
    case security = "cybersecurity-networking"
    case enterprise = "enterprise-delivery"

    var title: String {
        switch self {
        case .cloud: "Cloud platforms"
        case .ai: "AI & foundation models"
        case .apple: "Apple & mobile"
        case .data: "Data & analytics"
        case .devops: "DevOps & cloud native"
        case .security: "Security & networking"
        case .enterprise: "Enterprise & delivery"
        }
    }

    var band: Int {
        switch self {
        case .cloud: 0
        case .ai: 1
        case .apple: 2
        case .data: 4
        case .devops: 3
        case .security: 5
        case .enterprise: 6
        }
    }
}

enum NativeTrackAppearance {
    struct CodeGroup: Sendable {
        let family: String
        let category: NativeRadarCategory
        let prefixes: [String]
    }

    // Display hints from code namespaces, not authoritative provider/category metadata.
    private static let groups: [CodeGroup] = [
        .init(
            family: "MICROSOFT", category: .cloud,
            prefixes: ["MICROSOFT", "MSFT", "AZ", "AI", "PL", "MS", "DP", "SC"]),
        .init(family: "AWS", category: .cloud, prefixes: ["AWS"]),
        .init(family: "GCP", category: .cloud, prefixes: ["GCP", "GOOGLE-CLOUD"]),
        .init(family: "ORACLE", category: .cloud, prefixes: ["ORACLE", "OCI"]),
        .init(family: "OPENAI", category: .ai, prefixes: ["OPENAI", "OAI"]),
        .init(family: "ANTHROPIC", category: .ai, prefixes: ["ANTHROPIC", "CLAUDE"]),
        .init(family: "MISTRAL", category: .ai, prefixes: ["MISTRAL"]),
        .init(family: "NVIDIA", category: .ai, prefixes: ["NVIDIA", "NV", "DLI"]),
        .init(family: "HF", category: .ai, prefixes: ["HF", "HUGGINGFACE", "HUGGING-FACE"]),
        .init(family: "COHERE", category: .ai, prefixes: ["COHERE"]),
        .init(family: "META", category: .ai, prefixes: ["META"]),
        .init(family: "APPLE", category: .apple, prefixes: ["APPLE"]),
        .init(family: "DATABRICKS", category: .data, prefixes: ["DATABRICKS", "DBX"]),
        .init(family: "SNOWFLAKE", category: .data, prefixes: ["SNOWFLAKE", "SNOW", "SNOWPRO"]),
        .init(family: "MONGODB", category: .data, prefixes: ["MONGODB"]),
        .init(family: "CONFLUENT", category: .data, prefixes: ["CONFLUENT"]),
        .init(family: "DBT", category: .data, prefixes: ["DBT"]),
        .init(
            family: "CNCF", category: .devops,
            prefixes: ["CNCF", "LINUX-FOUNDATION", "LF", "CKA", "CKAD", "CKS"]),
        .init(
            family: "HASHICORP", category: .devops, prefixes: ["HASHICORP", "TERRAFORM", "VAULT"]),
        .init(family: "GITHUB", category: .devops, prefixes: ["GITHUB", "GH"]),
        .init(
            family: "REDHAT", category: .devops,
            prefixes: ["REDHAT", "RED-HAT", "RH", "RHCSA", "RHCE"]),
        .init(family: "DOCKER", category: .devops, prefixes: ["DOCKER"]),
        .init(family: "GITLAB", category: .devops, prefixes: ["GITLAB"]),
        .init(family: "CISCO", category: .security, prefixes: ["CISCO", "CCNA", "CCNP"]),
        .init(family: "COMPTIA", category: .security, prefixes: ["COMPTIA", "SY0", "N10"]),
        .init(family: "ISC2", category: .security, prefixes: ["ISC2", "CISSP"]),
        .init(family: "ISACA", category: .security, prefixes: ["ISACA", "CISM", "CISA"]),
        .init(family: "OFFSEC", category: .security, prefixes: ["OFFSEC", "OSCP"]),
        .init(family: "PALOALTO", category: .security, prefixes: ["PALOALTO", "PALO-ALTO"]),
        .init(family: "CLOUDFLARE", category: .security, prefixes: ["CLOUDFLARE"]),
        .init(family: "SALESFORCE", category: .enterprise, prefixes: ["SALESFORCE", "SF"]),
        .init(family: "SERVICENOW", category: .enterprise, prefixes: ["SERVICENOW", "CSA", "CAD"]),
        .init(family: "SAP", category: .enterprise, prefixes: ["SAP"]),
        .init(family: "ATLASSIAN", category: .enterprise, prefixes: ["ATLASSIAN"]),
        .init(family: "PMI", category: .enterprise, prefixes: ["PMI", "PMP", "PSM"]),
    ]

    static func normalized(_ code: String) -> String {
        code.uppercased().components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: "-")
    }

    static func group(for code: String) -> CodeGroup? {
        let code = normalized(code)
        return groups.first { group in
            group.prefixes.contains { code == $0 || code.hasPrefix($0 + "-") }
        }
    }

    static func band(for code: String) -> Int {
        // Preserve the established Microsoft subject accents.
        switch normalized(code).split(separator: "-").first {
        case "AI": 1
        case "PL": 2
        case "MS": 3
        case "DP": 4
        case "SC": 5
        default: group(for: code)?.category.band ?? 0
        }
    }
}

struct NativeCatalogFilter {
    var query = ""
    var family = ""
    var category: NativeRadarCategory?
    var availableOnly = false

    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !family.isEmpty || category != nil || availableOnly
    }

    static func family(for code: String) -> String {
        let prefix =
            NativeTrackAppearance.normalized(code).split(separator: "-").first
            .map(String.init) ?? ""
        if ["AZ", "AI", "PL", "MS", "DP", "SC"].contains(prefix) { return prefix }
        return NativeTrackAppearance.group(for: code)?.family ?? prefix
    }

    func includes(code: String, title: String, summary: String, available: Bool) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (family.isEmpty || Self.family(for: code) == family)
            && (category == nil || NativeTrackAppearance.group(for: code)?.category == category)
            && (!availableOnly || available)
            && (text.isEmpty
                || [code, title, summary].contains {
                    $0.range(
                        of: text, options: [.caseInsensitive, .diacriticInsensitive],
                        locale: Locale(identifier: "en_US_POSIX")) != nil
                })
    }

    mutating func clear() { self = Self() }
}

struct NativePathCoverage {
    let completedActivities: Int
    let totalActivities: Int
    let completedUnits: Int
    let totalUnits: Int
    let lockedActivities: Int

    init(units: [[String]]) {
        func complete(_ status: String) -> Bool {
            status == "completed" || status == "mastered"
        }
        let statuses = units.flatMap { $0 }
        completedActivities = statuses.filter(complete).count
        totalActivities = statuses.count
        completedUnits = units.filter { !$0.isEmpty && $0.allSatisfy(complete) }.count
        totalUnits = units.count
        lockedActivities = statuses.filter { $0 == "locked" }.count
    }

    var remainingActivities: Int { totalActivities - completedActivities }
}

struct NativeActivityDestination {
    let lessonID: String
    let title: String

    var resumeTitle: String { "Resume \(title)" }
    func actionTitle(_ action: String) -> String { "\(action) · \(title)" }
}

enum NativeDeclaredContentLanguage {
    static func badges(_ languages: [String]) -> [String] {
        Set(
            languages.compactMap { value -> String? in
                let language = value.lowercased().replacingOccurrences(of: "_", with: "-")
                if language == "fr" || language.hasPrefix("fr-") { return "FR" }
                if language == "en" || language.hasPrefix("en-") { return "EN" }
                return nil
            }
        ).sorted()
    }
}

enum NativeLearningDuration {
    static func total(_ minutes: [Int]) -> Int? {
        var total = 0
        for value in minutes {
            let addition = total.addingReportingOverflow(value)
            guard value >= 0, !addition.overflow else { return nil }
            total = addition.partialValue
        }
        return total
    }
}

#if canImport(CertigoDomain)
    import CertigoDomain

    extension NativeRadarCategory {
        func title(_ copy: AppInterfaceCopy) -> String {
            switch self {
            case .cloud: copy[.categoryCloud]
            case .ai: copy[.categoryAI]
            case .apple: copy[.categoryApple]
            case .data: copy[.categoryData]
            case .devops: copy[.categoryDevOps]
            case .security: copy[.categoryCyber]
            case .enterprise: copy[.categoryEnterprise]
            }
        }
    }

    extension PathLesson {
        var nativeMasteryStage: MasteryStage {
            switch status {
            case .locked, .available: .notStarted
            case .inProgress: .learning
            case .completed: .practicing
            case .mastered: .mastered
            }
        }
    }

    extension NativeDemoFlow.Objective {
        func displayName(_ copy: AppInterfaceCopy) -> String {
            copy.native(self == .fundamentals ? .demoCloudDiscovery : .demoCloudOperations)
        }

        func displayTitle(_ copy: AppInterfaceCopy) -> String {
            copy.native(self == .fundamentals ? .demoCloudFundamentals : .demoCloudPractice)
        }
    }

    extension NativeDemoFlow {
        func startLabel(_ copy: AppInterfaceCopy) -> String {
            startRoute == .preparation ? copy.native(.demoExploreSituation) : resumeLabel(copy)
        }

        func activitySummary(_ copy: AppInterfaceCopy) -> String {
            switch phase {
            case .answering:
                copy.native(selection == nil ? .demoSituationNoGrade : .demoEditableChoice)
            case .pending: copy.native(.demoAnswerPending)
            case .reviewed: copy.native(.demoExplanationAvailable)
            }
        }

        func resumeLabel(_ copy: AppInterfaceCopy) -> String {
            switch phase {
            case .answering:
                copy.native(selection == nil ? .demoStartQuestion : .demoResumeChoice)
            case .pending: copy.native(.demoResumePending)
            case .reviewed: copy.native(.demoReadExplanation)
            }
        }
    }

    extension NativeDemoPracticeStage {
        func label(_ copy: AppInterfaceCopy) -> String {
            switch self {
            case .situation: copy.native(.demoStageSituation)
            case .decision: copy.native(.demoStageDecision)
            case .explanation: copy.native(.demoStageExplanation)
            }
        }
    }

    extension NativeDemoPracticeProgress {
        func accessibilityLabel(_ copy: AppInterfaceCopy) -> String {
            "\(current.position) / \(NativeDemoPracticeStage.allCases.count) · "
                + "\(current.label(copy)). \(copy.native(.demoStageHint))"
        }
    }

    extension AppInterfaceCopy {
        func minutes(_ value: Int) -> String {
            native(.minutesTemplate).replacingOccurrences(
                of: "{minutes}", with: value.formatted(.number.locale(language.locale)))
        }

        enum NativeLabel: CaseIterable {
            case minutesTemplate, apiEndpoint
            case findGoal, catalogHint, findCertification, codeFamily, allFamilies, codeCategory
            case availableOnly, catalogScope, loadedResults, noCatalog, noMatchesHint
            case continueDevice, restoreActivity, chooseGoalHint, guidedReading, frenchPilot
            case collection, yourGoals, learningPlan, remainingActivities, activities, openPlanHint
            case loadGoalHint, reviewPractice, readCorrectionHint, goalOverview, openOverview
            case overviewHint, nextSession, confirmedLearning, confirmedXP, confirmedGoal
            case noGoal, yourAccount, account, accessibility, accessibilityHint, privacy,
                privacyHint
            case coachPrivacy, coachDisclosure, currentContext, chooseContext, tutorFailure
            case sourceAI, sourceOther, attempts, accuracy, trend, errors, recurringErrors
            case yes, no, reviewEvidence, noReview, refreshHistory, lowestScore, continueReview
            case contentLanguage, beforeStart, learningNotCertification, originalFrench
            case duration, sourcesChecked, lessons, editorialPilot, studyPlan, save, targetDate
            case initialLevel, noTargetDate, localPlanHint, levelUnknown, beginner, intermediate,
                advanced
            case readiness, skills, focusArea, review, finalAssessment, rewards, notifications
            case unavailable, contentLoadFailure, historyUnconfirmed, understandSituation, keyIdeas
            case workedExample, selfCheck, takeaway, sourcesLimits, openSource, readingHistory
            case markedRead, lastOpened, markRead, declarationHint, revisit, readAgain,
                formativePractice
            case noScoreHint, unsynced, readNotConfirmed, readAloud, dataFailure, refreshData
            case remainingLearning, readinessHint, domainMasteryUnavailable, reviewTimingUnavailable
            case reviewRisk, sourceServer, level, streak, dailyGoal, earned, achievements, quests
            case strongest, selectedAnswer, correctAnswer, masteryChange, nextReview
            case learnStage, understandStage, recallApplyStage, feedbackStage, masterStage
            case questionType, multipleChoice, reviewRecommendations, planNotLoaded
            case assessmentPassed, assessmentReview, assessmentDisclaimer, generateExam, submitExam
            case emptyExam
            case discardExam, discardExamHint, unsupportedExam, score, correctCount, timeRemaining
            case notificationScope, utcOffset, quietStart, quietEnd, pendingExam
            case developerConnector, testLearning, ciamTestScope, ciamTestSignIn, ciamSignIn,
                ciamExplicit, ciamUnavailable, ciamIncomplete, developmentConnection,
                microsoftAccount, testConnectorHint, microsoftConnected, connectWorkspace,
                developmentScope, connectorBoundary, testConnection, testToken, connectTest,
                tokenStorageHint, activeGoal, noActiveGoal, goalChangeHint
            case welcomeTitle, welcomeHint, tryLearning, fictionalBoundary, sharedLesson,
                openLinkedLesson, development, openConnector, testOnly, lessonLinkUnavailable,
                lessonLinkInvalid, signInUnconfigured, productionTitle, productionHint,
                continueLearning, signInIncomplete, socialUnavailable, socialUnavailableHint,
                privateLearning, privateProfileHint, privateResultsHint, friendsInactive,
                teamsInactive, friendsPrivacy, teamsPrivacy, sharingConsent, returnLearning,
                savingGoal, operationUnconfirmed, downloadQuestionPacks, downloadContent,
                downloadBoundary, offlinePack, downloadPack, downloadedBoundary, pathUnavailable,
                pathRetryHint, retryPath, chooseCertification, pathServerHint, learningPath,
                answerInstruction, pendingCorrectionHint, confirmedResult, answerCorrect,
                reviewNeeded, newAttemptHint, practiceAgainHint, lessonUnavailable,
                lessonLoadFailure, oneSession, chooseActivity, goalPending, goalConfirmed,
                goalViewing, chooseGoal
            case demoPreviewOnly, demoHistory, demoHistoryHint, demoResponsibilities, demoNotice,
                demoFrenchExamples, demoOptions, demoExploreSituation, demoSituationNoGrade,
                demoEditableChoice, demoAnswerPending, demoExplanationAvailable, demoStartQuestion,
                demoResumeChoice, demoResumePending, demoReadExplanation, demoCloudDiscovery,
                demoCloudOperations, demoCloudFundamentals, demoCloudPractice, demoStageSituation,
                demoStageDecision, demoStageExplanation, demoStageHint, demoReady, demoLoading,
                demoEmpty, demoError, close
            case demoCoachUnavailable, demoCatalogStates, demoCatalog, demoOfflineToggle,
                demoSettingsScope, demoSettings, demoResetConfirmation, demoReset,
                demoRestorationUnavailable, demoRestoreFailure, demoSaveFailure, demoReopenFailure,
                demoReturnLearn, demoSocialUnavailable, demoWorkshop, demoWorkshopHint,
                demoFictionalContent, demoSwitchGoal, demoHistoryAction, demoNextGoal,
                demoExploreHint, demoChooseHint, demoWorkshops, demoVolume, demoSelectedGoal,
                demoSituationExplore, demoFinishLoading, demoNoGoals, demoEmptyHint, demoShowGoals,
                demoCatalogUnavailable, demoPreservedHint, demoScenarioHint, demoDecisionExplore,
                demoFictionalSituation, demoNoGrade, demoLocalRestore, demoSituation, demoTask,
                demoBeforeChoose, demoBoundaryHint, demoOpenQuestion, demoPreparation,
                demoChooseAnswer, demoAnswerSelected, selected, notSelected, demoEditableHint,
                demoChooseBeforeContinue, demoChoiceSaved, demoNoVerdict, demoOfflinePending,
                demoDisableOffline, demoSimulateHint, demoSimulateExplanation, demoExplanation,
                demoConstraint, demoUnderstanding, demoFixtureHint, demoPracticeAgain, demoPractice,
                demoChoice, demoProfile, demoProfileHint, demoControls, demoPreviewStates,
                demoAppearance, demoAppearanceHint, demoAccountHint
            case savedActivityHint, nextAvailableHint, publicVersion, codeGroup, unit
            case activityCoverageHint, lockedHint, catalogFormats, radarLimits
            case confirmedSessions, activityCoverage, localDevice, completedActivities,
                completedUnits
            case localAnswers, lastLoaded, unloadedHistory, retrieveCorrection, loadMore,
                signInAgain
            case availableActivity, completedActivity, lockedActivity
        }

        func native(_ key: NativeLabel) -> String {
            let row: [String]
            switch key {
            case .minutesTemplate:
                row = [
                    "{minutes} min", "{minutes} min", "{minutes} मिनट", "{minutes} 分钟",
                    "{minutes}분", "{minutes} min", "{minutes} min", "{minutes} Min.",
                ]
            case .apiEndpoint:
                row = [
                    "URL HTTPS de l’API", "HTTPS API URL", "HTTPS API यूआरएल",
                    "HTTPS API 地址", "HTTPS API 주소", "URL HTTPS de la API",
                    "URL HTTPS dell’API", "HTTPS-API-Adresse",
                ]
            case .developerConnector:
                row = [
                    "Connecteur développeur", "Developer connector", "डेवलपर कनेक्टर", "开发者连接器",
                    "개발자 커넥터", "Conector de desarrollo", "Connettore sviluppatore",
                    "Entwicklerverbindung",
                ]
            case .testLearning:
                row = [
                    "Testez l’apprentissage connecté.", "Test your connected learning.",
                    "कनेक्टेड सीखने का परीक्षण करें।", "测试联网学习。", "연결된 학습을 테스트하세요.",
                    "Prueba el aprendizaje conectado.", "Prova l’apprendimento connesso.",
                    "Teste das verbundene Lernen.",
                ]
            case .ciamTestScope:
                row = [
                    "Configuration CIAM de développement · comptes de test uniquement.",
                    "CIAM development configuration · test accounts only.",
                    "CIAM विकास कॉन्फ़िगरेशन · केवल परीक्षण खाते।", "CIAM 开发配置 · 仅供测试账户。",
                    "CIAM 개발 구성 · 테스트 계정 전용.",
                    "Configuración CIAM de desarrollo · solo cuentas de prueba.",
                    "Configurazione CIAM di sviluppo · solo account di test.",
                    "CIAM-Entwicklungskonfiguration · nur Testkonten.",
                ]
            case .ciamTestSignIn:
                row = [
                    "Connexion CIAM de test", "CIAM test sign-in", "CIAM परीक्षण साइन-इन", "CIAM 测试登录",
                    "CIAM 테스트 로그인", "Inicio de sesión CIAM de prueba", "Accesso CIAM di test",
                    "CIAM-Testanmeldung",
                ]
            case .ciamSignIn:
                row = [
                    "Se connecter avec CIAM", "Sign in with CIAM", "CIAM से साइन इन करें", "使用 CIAM 登录",
                    "CIAM으로 로그인", "Iniciar sesión con CIAM", "Accedi con CIAM", "Mit CIAM anmelden",
                ]
            case .ciamExplicit:
                row = [
                    "Connectez-vous explicitement avec l’identité de test configurée localement.",
                    "Sign in explicitly with the locally configured test identity.",
                    "स्थानीय रूप से कॉन्फ़िगर परीक्षण पहचान से स्पष्ट रूप से साइन इन करें।", "请使用本地配置的测试身份明确登录。",
                    "로컬에 구성된 테스트 ID로 직접 로그인하세요.",
                    "Inicia sesión explícitamente con la identidad local de prueba.",
                    "Accedi esplicitamente con l’identità di test locale.",
                    "Melde dich ausdrücklich mit der lokal konfigurierten Testidentität an.",
                ]
            case .ciamUnavailable:
                row = [
                    "Connexion CIAM de test indisponible", "CIAM test sign-in is unavailable",
                    "CIAM परीक्षण साइन-इन उपलब्ध नहीं", "CIAM 测试登录不可用", "CIAM 테스트 로그인 사용 불가",
                    "Inicio de sesión CIAM no disponible", "Accesso CIAM di test non disponibile",
                    "CIAM-Testanmeldung nicht verfügbar",
                ]
            case .ciamIncomplete:
                row = [
                    "Connexion CIAM non aboutie", "CIAM sign-in did not complete",
                    "CIAM साइन-इन पूरा नहीं हुआ", "CIAM 登录未完成", "CIAM 로그인 미완료",
                    "Inicio de sesión CIAM incompleto", "Accesso CIAM non completato",
                    "CIAM-Anmeldung nicht abgeschlossen",
                ]
            case .developmentConnection:
                row = [
                    "Connexion de développement", "Development connection", "विकास कनेक्शन", "开发连接",
                    "개발 연결", "Conexión de desarrollo", "Connessione di sviluppo",
                    "Entwicklungsverbindung",
                ]
            case .microsoftAccount:
                row = [
                    "Compte Microsoft", "Microsoft account", "Microsoft खाता", "Microsoft 账户",
                    "Microsoft 계정", "Cuenta Microsoft", "Account Microsoft", "Microsoft-Konto",
                ]
            case .testConnectorHint:
                row = [
                    "Connecteur de test uniquement. Connexion de production non activée.",
                    "Test connector only. Production sign-in is not enabled.",
                    "केवल परीक्षण कनेक्टर। प्रोडक्शन साइन-इन सक्षम नहीं है।", "仅供测试连接器使用，未启用生产登录。",
                    "테스트 커넥터 전용. 프로덕션 로그인이 비활성화되어 있습니다.",
                    "Solo conector de prueba. Sin inicio de sesión de producción.",
                    "Solo connettore di test. Accesso di produzione non abilitato.",
                    "Nur Testverbindung. Produktionsanmeldung nicht aktiviert.",
                ]
            case .microsoftConnected:
                row = [
                    "Connecté avec votre compte Microsoft.",
                    "Connected with your Microsoft account.", "आपके Microsoft खाते से कनेक्ट है।",
                    "已使用你的 Microsoft 账户连接。", "Microsoft 계정으로 연결되었습니다.",
                    "Conectado con tu cuenta Microsoft.", "Connesso con il tuo account Microsoft.",
                    "Mit deinem Microsoft-Konto verbunden.",
                ]
            case .connectWorkspace:
                row = [
                    "Connectez un espace de test.", "Connect a test workspace.",
                    "परीक्षण कार्यक्षेत्र कनेक्ट करें।", "连接测试工作区。", "테스트 작업 영역에 연결하세요.",
                    "Conecta un espacio de prueba.", "Connetti un’area di test.",
                    "Verbinde einen Testarbeitsbereich.",
                ]
            case .developmentScope:
                row = [
                    "Accès de développement uniquement. Votre compte de production utilise Microsoft.",
                    "Development access only. Your production account uses Microsoft sign-in.",
                    "केवल विकास पहुँच। प्रोडक्शन खाता Microsoft साइन-इन उपयोग करता है।",
                    "仅限开发访问，生产账户使用 Microsoft 登录。", "개발 접근 전용. 프로덕션 계정은 Microsoft 로그인을 사용합니다.",
                    "Solo desarrollo. Tu cuenta de producción usa Microsoft.",
                    "Solo sviluppo. L’account di produzione usa l’accesso Microsoft.",
                    "Nur Entwicklungszugriff. Dein Produktionskonto verwendet Microsoft-Anmeldung.",
                ]
            case .connectorBoundary:
                row = [
                    "Ce connecteur n’est pas une connexion de production. Aucun compte Apple ni nouvelle identité créé.",
                    "This developer connector is not production sign-in. No Apple account or new identity is created.",
                    "यह डेवलपर कनेक्टर प्रोडक्शन साइन-इन नहीं है। Apple खाता या नई पहचान नहीं बनती।",
                    "此开发者连接器不是生产登录，不会创建 Apple 账户或新身份。",
                    "개발자 커넥터는 프로덕션 로그인이 아닙니다. Apple 계정이나 새 ID를 만들지 않습니다.",
                    "Este conector no es inicio de sesión de producción. No crea cuenta Apple ni identidad nueva.",
                    "Questo connettore non è accesso di produzione. Non crea account Apple o nuove identità.",
                    "Diese Entwicklerverbindung ist keine Produktionsanmeldung. Kein Apple-Konto und keine neue Identität werden erstellt.",
                ]
            case .testConnection:
                row = [
                    "Connexion de test", "Test connection", "परीक्षण कनेक्शन", "测试连接", "테스트 연결",
                    "Conexión de prueba", "Connessione di test", "Testverbindung",
                ]
            case .testToken:
                row = [
                    "Jeton d’accès du compte de test", "Test account access token",
                    "परीक्षण खाते का एक्सेस टोकन", "测试账户访问令牌", "테스트 계정 액세스 토큰", "Token de acceso de prueba",
                    "Token di accesso account di test", "Zugriffstoken für Testkonto",
                ]
            case .connectTest:
                row = [
                    "Connecter le compte de test", "Connect the test account", "परीक्षण खाता कनेक्ट करें",
                    "连接测试账户", "테스트 계정 연결", "Conectar cuenta de prueba", "Connetti account di test",
                    "Testkonto verbinden",
                ]
            case .tokenStorageHint:
                row = [
                    "Le jeton reste dans le coffre sécurisé de cet appareil. Les réponses en attente ne sont jamais corrigées localement.",
                    "The token stays in this device’s secure vault. Pending answers are never graded locally.",
                    "टोकन इस डिवाइस के सुरक्षित भंडार में रहता है। लंबित उत्तर स्थानीय रूप से नहीं जाँचे जाते।",
                    "令牌留在设备安全存储中，待提交答案绝不在本地评分。",
                    "토큰은 이 기기의 보안 저장소에 보관됩니다. 대기 중인 답변은 기기에서 채점하지 않습니다.",
                    "El token queda en el almacén seguro del dispositivo. Las respuestas pendientes nunca se corrigen localmente.",
                    "Il token resta nell’archivio sicuro del dispositivo. Le risposte in attesa non sono mai corrette localmente.",
                    "Das Token bleibt im sicheren Gerätespeicher. Ausstehende Antworten werden niemals lokal ausgewertet.",
                ]
            case .activeGoal:
                row = [
                    "Objectif d’apprentissage actif", "Active learning goal", "सक्रिय सीखने का लक्ष्य",
                    "当前学习目标", "활성 학습 목표", "Objetivo de aprendizaje activo",
                    "Obiettivo di apprendimento attivo", "Aktives Lernziel",
                ]
            case .noActiveGoal:
                row = [
                    "Aucun objectif actif confirmé par le serveur.",
                    "No active goal is confirmed by the server.", "सर्वर ने किसी सक्रिय लक्ष्य की पुष्टि नहीं की है।",
                    "服务器尚未确认当前目标。", "서버가 확인한 활성 목표가 없습니다.",
                    "No hay objetivo activo confirmado por el servidor.",
                    "Nessun obiettivo attivo confermato dal server.",
                    "Kein aktives Ziel vom Server bestätigt.",
                ]
            case .goalChangeHint:
                row = [
                    "La consultation ne change pas l’objectif. Cette action demande un changement confirmé par le serveur ; activité et réponses sauvegardées restent disponibles.",
                    "Browsing does not change your goal. This action requests a server-confirmed change; your current activity and saved submissions stay available.",
                    "देखने से लक्ष्य नहीं बदलता। यह कार्रवाई सर्वर-पुष्ट परिवर्तन माँगती है; गतिविधि और सहेजे उत्तर उपलब्ध रहते हैं।",
                    "浏览不会更改目标。此操作请求服务器确认更改，当前活动与已保存作答仍可用。",
                    "탐색으로 목표는 바뀌지 않습니다. 이 작업은 서버가 확인하는 변경을 요청하며 현재 활동과 저장된 제출은 유지됩니다.",
                    "Navegar no cambia el objetivo. Esta acción pide un cambio confirmado; actividad y respuestas guardadas siguen disponibles.",
                    "Esplorare non cambia l’obiettivo. L’azione richiede una modifica confermata dal server; attività e invii restano disponibili.",
                    "Ansehen ändert das Ziel nicht. Diese Aktion fordert einen serverbestätigten Wechsel an; Aktivität und gespeicherte Antworten bleiben verfügbar.",
                ]
            case .welcomeTitle:
                row = [
                    "Une question. Une idée plus claire.", "One question. A clearer idea.",
                    "एक प्रश्न। अधिक स्पष्ट समझ।", "一个问题，更清晰的理解。", "문제 하나로 더 명확하게.",
                    "Una pregunta. Una idea más clara.", "Una domanda. Un’idea più chiara.",
                    "Eine Frage. Mehr Klarheit.",
                ]
            case .welcomeHint:
                row = [
                    "Découvrez l’aperçu natif de Certigo.",
                    "Explore Certigo’s native learning preview.", "Certigo का नेटिव सीखने का पूर्वावलोकन देखें।",
                    "探索 Certigo 原生学习预览。", "Certigo 네이티브 학습 미리 보기를 살펴보세요.",
                    "Explora la vista nativa de aprendizaje de Certigo.",
                    "Esplora l’anteprima nativa di Certigo.",
                    "Entdecke Certigos native Lernvorschau.",
                ]
            case .tryLearning:
                row = [
                    "Essayer l’expérience d’apprentissage", "Try the learning experience",
                    "सीखने का अनुभव आज़माएँ", "体验学习", "학습 체험하기", "Probar el aprendizaje",
                    "Prova l’esperienza di apprendimento", "Lernerlebnis ausprobieren",
                ]
            case .fictionalBoundary:
                row = [
                    "Objectifs, réponses et explications sont fictifs. Aucun compte, réseau ou résultat réel n’est utilisé.",
                    "Goals, answers and explanations are fictional. No account, network or real result is used.",
                    "लक्ष्य, उत्तर और व्याख्याएँ काल्पनिक हैं। खाता, नेटवर्क या वास्तविक परिणाम उपयोग नहीं होते।",
                    "目标、答案和解析均为虚构，不使用账户、网络或真实结果。", "목표, 답변, 설명은 가상입니다. 계정, 네트워크, 실제 결과를 사용하지 않습니다.",
                    "Los objetivos, respuestas y explicaciones son ficticios. No se usa cuenta, red ni resultado real.",
                    "Obiettivi, risposte e spiegazioni sono fittizi. Nessun account, rete o risultato reale è utilizzato.",
                    "Ziele, Antworten und Erklärungen sind fiktiv. Es werden keine Konten, Netzwerke oder echten Ergebnisse verwendet.",
                ]
            case .sharedLesson:
                row = [
                    "Lien de leçon partagé", "Shared lesson link", "साझा पाठ लिंक", "共享课程链接",
                    "공유된 학습 링크", "Enlace compartido", "Link lezione condiviso",
                    "Geteilter Lektionslink",
                ]
            case .openLinkedLesson:
                row = [
                    "Ouvrir la leçon liée", "Open linked lesson", "लिंक किया पाठ खोलें", "打开链接课程",
                    "연결된 학습 열기", "Abrir lección enlazada", "Apri lezione collegata",
                    "Verlinkte Lektion öffnen",
                ]
            case .development:
                row = [
                    "Développement", "Development", "विकास", "开发", "개발", "Desarrollo", "Sviluppo",
                    "Entwicklung",
                ]
            case .openConnector:
                row = [
                    "Ouvrir le connecteur API de test", "Open the test API connector",
                    "परीक्षण API कनेक्टर खोलें", "打开测试 API 连接器", "테스트 API 커넥터 열기",
                    "Abrir conector API de prueba", "Apri connettore API di test",
                    "Test-API-Verbindung öffnen",
                ]
            case .testOnly:
                row = [
                    "Comptes de test uniquement. Ce n’est pas une connexion de production.",
                    "For test accounts only. This is not production sign-in.",
                    "केवल परीक्षण खातों के लिए। यह प्रोडक्शन साइन-इन नहीं है।", "仅供测试账户使用，不是生产登录。",
                    "테스트 계정 전용입니다. 프로덕션 로그인이 아닙니다.",
                    "Solo cuentas de prueba. No es inicio de sesión de producción.",
                    "Solo account di test. Non è accesso di produzione.",
                    "Nur für Testkonten. Keine Produktionsanmeldung.",
                ]
            case .lessonLinkUnavailable:
                row = [
                    "Lien de leçon indisponible", "Lesson link unavailable", "पाठ लिंक उपलब्ध नहीं",
                    "课程链接不可用", "학습 링크 사용 불가", "Enlace no disponible",
                    "Link lezione non disponibile", "Lektionslink nicht verfügbar",
                ]
            case .lessonLinkInvalid:
                row = [
                    "Ce lien ne correspond à aucune leçon pilote prise en charge.",
                    "This link does not identify a supported editorial pilot lesson.",
                    "यह लिंक समर्थित संपादकीय पायलट पाठ की पहचान नहीं करता।", "此链接未指向受支持的编辑试点课程。",
                    "지원되는 편집 파일럿 학습 링크가 아닙니다.",
                    "El enlace no identifica una lección piloto compatible.",
                    "Il link non identifica una lezione pilota supportata.",
                    "Dieser Link verweist auf keine unterstützte Pilotlektion.",
                ]
            case .signInUnconfigured:
                row = [
                    "Connexion Microsoft non configurée", "Microsoft sign-in is not configured",
                    "Microsoft साइन-इन कॉन्फ़िगर नहीं है", "尚未配置 Microsoft 登录", "Microsoft 로그인 미설정",
                    "Inicio de sesión Microsoft sin configurar",
                    "Accesso Microsoft non configurato", "Microsoft-Anmeldung nicht konfiguriert",
                ]
            case .productionTitle:
                row = [
                    "Éclairez votre prochaine décision.", "Make your next decision clearer.",
                    "अपना अगला निर्णय स्पष्ट बनाएँ।", "让下一次决策更清晰。", "다음 결정을 더 명확하게.",
                    "Aclara tu próxima decisión.", "Rendi più chiara la prossima decisione.",
                    "Triff deine nächste Entscheidung klarer.",
                ]
            case .productionHint:
                row = [
                    "Vos objectifs, vos exercices et votre progression confirmée, réunis dans Certigo.",
                    "Your learning goals, practice and confirmed progress, together in Certigo.",
                    "आपके सीखने के लक्ष्य, अभ्यास और पुष्ट प्रगति, सब Certigo में।", "学习目标、练习与已确认进度，尽在 Certigo。",
                    "학습 목표, 연습, 확인된 진행 상황을 Certigo에서 함께.",
                    "Tus objetivos, práctica y progreso confirmado, juntos en Certigo.",
                    "Obiettivi, pratica e progressi confermati, insieme in Certigo.",
                    "Lernziele, Übungen und bestätigter Fortschritt – vereint in Certigo.",
                ]
            case .continueLearning:
                row = [
                    "Poursuivre votre apprentissage", "Continue your learning", "सीखना जारी रखें", "继续学习",
                    "학습 계속하기", "Continuar aprendiendo", "Continua a imparare", "Weiterlernen",
                ]
            case .signInIncomplete:
                row = [
                    "Connexion Microsoft non aboutie", "Microsoft sign-in did not complete",
                    "Microsoft साइन-इन पूरा नहीं हुआ", "Microsoft 登录未完成", "Microsoft 로그인 미완료",
                    "Inicio de sesión Microsoft incompleto", "Accesso Microsoft non completato",
                    "Microsoft-Anmeldung nicht abgeschlossen",
                ]
            case .socialUnavailable:
                row = [
                    "Amis et équipes non connectés", "Friends and teams are not connected",
                    "मित्र और टीमें कनेक्ट नहीं हैं", "好友与团队尚未连接", "친구 및 팀 미연결", "Amigos y equipos sin conectar",
                    "Amici e team non connessi", "Freunde und Teams nicht verbunden",
                ]
            case .socialUnavailableHint:
                row = [
                    "Invitations, partage et activités de groupe indisponibles. Aucun lien n’est créé ici.",
                    "Invitations, sharing and group activity are not available. No relationships are created here.",
                    "आमंत्रण, साझाकरण और समूह गतिविधि उपलब्ध नहीं हैं। यहाँ संबंध नहीं बनते।",
                    "邀请、分享和群组活动暂不可用，这里不会建立社交关系。", "초대, 공유, 그룹 활동은 제공되지 않습니다. 관계가 생성되지 않습니다.",
                    "Invitaciones, compartir y actividades grupales no disponibles. Aquí no se crean relaciones.",
                    "Inviti, condivisione e attività di gruppo non disponibili. Qui non si creano relazioni.",
                    "Einladungen, Teilen und Gruppenaktivitäten sind nicht verfügbar. Hier entstehen keine Kontakte.",
                ]
            case .privateLearning:
                row = [
                    "L’apprentissage privé avant tout", "Private learning comes first",
                    "निजी सीखना पहले", "私密学习优先", "비공개 학습 우선", "El aprendizaje privado primero",
                    "Prima l’apprendimento privato", "Privates Lernen zuerst",
                ]
            case .privateProfileHint:
                row = [
                    "Votre profil est votre dossier d’apprentissage privé, pas un profil public.",
                    "Your Profile is your private learning record, not a friend profile.",
                    "आपकी प्रोफ़ाइल निजी सीखने का रिकॉर्ड है, मित्र प्रोफ़ाइल नहीं।", "个人资料是私密学习记录，并非社交主页。",
                    "프로필은 비공개 학습 기록이며 친구 프로필이 아닙니다.",
                    "Tu perfil es tu registro privado de aprendizaje, no un perfil de amigos.",
                    "Il profilo è un registro privato di apprendimento, non un profilo per amici.",
                    "Dein Profil ist dein privater Lernnachweis, kein Freundesprofil.",
                ]
            case .privateResultsHint:
                row = [
                    "Consulter Social ne publie ni résultats détaillés, ni erreurs, ni préparation, ni contexte Coach.",
                    "Detailed results, mistakes, readiness and Coach context are not published by visiting Social.",
                    "Social खोलने से परिणाम, गलतियाँ, तैयारी या कोच संदर्भ प्रकाशित नहीं होते।",
                    "访问社交不会公开详细结果、错误、准备度或教练上下文。", "소셜을 열어도 세부 결과, 실수, 준비도, 코치 맥락은 공개되지 않습니다.",
                    "Visitar Social no publica resultados, errores, preparación ni contexto del Coach.",
                    "Visitare Social non pubblica risultati, errori, preparazione o contesto Coach.",
                    "Der Besuch von Social veröffentlicht weder Ergebnisse noch Fehler, Lernbereitschaft oder Coach-Kontext.",
                ]
            case .friendsInactive:
                row = [
                    "Amis · inactif", "Friends · not active", "मित्र · निष्क्रिय", "好友 · 未启用", "친구 · 비활성",
                    "Amigos · inactivo", "Amici · non attivo", "Freunde · nicht aktiv",
                ]
            case .teamsInactive:
                row = [
                    "Équipes · inactif", "Teams · not active", "टीमें · निष्क्रिय", "团队 · 未启用", "팀 · 비활성",
                    "Equipos · inactivo", "Team · non attivo", "Teams · nicht aktiv",
                ]
            case .friendsPrivacy:
                row = [
                    "Recherche d’amis, invitations et profils partagés désactivés. Aucun contact envoyé, aucune invitation expédiée.",
                    "Friend discovery, invitations and shared profiles are not enabled. No contacts are uploaded and no invitations are sent.",
                    "मित्र खोज, आमंत्रण और साझा प्रोफ़ाइल सक्षम नहीं हैं। संपर्क अपलोड या आमंत्रण भेजे नहीं जाते।",
                    "好友发现、邀请与共享资料未启用。不会上传联系人或发送邀请。",
                    "친구 찾기, 초대, 프로필 공유가 비활성화되어 있습니다. 연락처 업로드나 초대 전송은 없습니다.",
                    "Descubrimiento de amigos, invitaciones y perfiles compartidos desactivados. No se suben contactos ni se envían invitaciones.",
                    "Ricerca amici, inviti e profili condivisi non attivi. Nessun contatto caricato o invito inviato.",
                    "Freundesuche, Einladungen und geteilte Profile sind deaktiviert. Keine Kontakte werden hochgeladen oder Einladungen versendet.",
                ]
            case .teamsPrivacy:
                row = [
                    "Adhésion, rôles, invitations et défis d’équipe désactivés. Une équipe partagée ne donnerait pas accès aux résultats privés ni à la préparation.",
                    "Team membership, roles, invitations and challenges are not enabled. A shared team would not grant access to private results or readiness.",
                    "टीम सदस्यता, भूमिकाएँ, आमंत्रण और चुनौतियाँ सक्षम नहीं हैं। साझा टीम निजी परिणाम या तैयारी तक पहुँच नहीं देगी।",
                    "团队成员、角色、邀请与挑战未启用。共享团队也不会获得私密结果或准备度。",
                    "팀 가입, 역할, 초대, 챌린지가 비활성화되어 있습니다. 팀 공유로도 비공개 결과나 준비도에 접근할 수 없습니다.",
                    "Membresía, roles, invitaciones y retos de equipo desactivados. Un equipo no daría acceso a resultados privados ni preparación.",
                    "Appartenenza, ruoli, inviti e sfide non attivi. Un team non darebbe accesso a risultati o preparazione privati.",
                    "Mitgliedschaft, Rollen, Einladungen und Aufgaben sind deaktiviert. Ein Team erhielte keinen Zugriff auf private Ergebnisse oder Lernbereitschaft.",
                ]
            case .sharingConsent:
                row = [
                    "Tout partage futur nécessitera un accord explicite séparé, avec aperçu du contenu et du public. Aucun partage n’est actif ici.",
                    "Any future sharing needs a separate, explicit opt-in with a preview of the content and audience. No sharing controls are active here.",
                    "भविष्य में साझाकरण के लिए सामग्री और दर्शकों के पूर्वावलोकन सहित अलग स्पष्ट सहमति चाहिए। यहाँ साझाकरण सक्रिय नहीं है।",
                    "未来分享须单独明确授权，并预览内容及受众。此处未启用分享。",
                    "향후 공유에는 내용과 대상을 미리 확인하는 별도 동의가 필요합니다. 현재 공유 기능은 없습니다.",
                    "Compartir en el futuro requerirá consentimiento explícito separado y vista del contenido y público. Aquí no hay controles activos.",
                    "Ogni condivisione futura richiederà consenso esplicito separato e anteprima di contenuto e pubblico. Nessun controllo attivo qui.",
                    "Künftiges Teilen erfordert eine gesonderte Zustimmung mit Vorschau von Inhalt und Zielgruppe. Hier ist kein Teilen aktiv.",
                ]
            case .returnLearning:
                row = [
                    "Revenir à l’apprentissage", "Return to learning", "सीखने पर लौटें", "返回学习",
                    "학습으로 돌아가기", "Volver al aprendizaje", "Torna all’apprendimento",
                    "Zurück zum Lernen",
                ]
            case .savingGoal:
                row = [
                    "Enregistrement de l’objectif…", "Saving active goal…", "सक्रिय लक्ष्य सहेजा जा रहा है…",
                    "正在保存当前目标…", "활성 목표 저장 중…", "Guardando objetivo…", "Salvataggio obiettivo…",
                    "Aktives Ziel wird gespeichert…",
                ]
            case .operationUnconfirmed:
                row = [
                    "Opération non confirmée", "Operation not confirmed", "कार्रवाई की पुष्टि नहीं", "操作未确认",
                    "작업 미확인", "Operación no confirmada", "Operazione non confermata",
                    "Vorgang nicht bestätigt",
                ]
            case .downloadQuestionPacks:
                row = [
                    "Télécharger les packs publics de questions ?",
                    "Download public question packs?", "सार्वजनिक प्रश्न पैक डाउनलोड करें?", "下载公共题库包？",
                    "공개 문제 팩을 다운로드할까요?", "¿Descargar paquetes públicos?",
                    "Scaricare i pacchetti pubblici?", "Öffentliche Fragenpakete herunterladen?",
                ]
            case .downloadContent:
                row = [
                    "Télécharger le contenu public", "Download public content",
                    "सार्वजनिक सामग्री डाउनलोड करें", "下载公共内容", "공개 콘텐츠 다운로드", "Descargar contenido público",
                    "Scarica contenuto pubblico", "Öffentliche Inhalte herunterladen",
                ]
            case .downloadBoundary:
                row = [
                    "Toute la version publique actuelle sera téléchargée, pas seulement cette certification. Aucune solution téléchargée. Réponses locales jusqu’à l’envoi ; correction et XP nécessitent le serveur.",
                    "This downloads the whole current public release, not just this certification. No solutions are downloaded. Answers stay local until you choose Submit; correction and XP require the server.",
                    "पूरी वर्तमान सार्वजनिक रिलीज़ डाउनलोड होगी, केवल यह प्रमाणन नहीं। समाधान डाउनलोड नहीं होते। जमा करने तक उत्तर स्थानीय रहते हैं; सुधार और XP के लिए सर्वर चाहिए।",
                    "将下载整个当前公共版本，而不只是此认证。不下载答案解析。提交前答案留在本地，评分与 XP 需要服务器。",
                    "이 인증만이 아닌 현재 전체 공개 버전을 다운로드합니다. 정답은 내려받지 않습니다. 제출 전 답변은 기기에만 있으며 채점과 XP는 서버가 필요합니다.",
                    "Se descarga toda la versión pública, no solo esta certificación. Sin soluciones. Las respuestas son locales hasta Enviar; corrección y XP requieren servidor.",
                    "Scarica l’intera versione pubblica, non solo questa certificazione. Nessuna soluzione. Risposte locali fino all’invio; correzione e XP richiedono il server.",
                    "Die gesamte öffentliche Version wird geladen, nicht nur diese Zertifizierung. Keine Lösungen. Antworten bleiben bis zum Absenden lokal; Auswertung und XP benötigen den Server.",
                ]
            case .offlinePack:
                row = [
                    "Pack de questions hors ligne", "Offline question pack", "ऑफ़लाइन प्रश्न पैक", "离线题库包",
                    "오프라인 문제 팩", "Paquete de preguntas sin conexión", "Pacchetto domande offline",
                    "Offline-Fragenpaket",
                ]
            case .downloadPack:
                row = [
                    "Télécharger les packs publics", "Download public question packs",
                    "सार्वजनिक प्रश्न पैक डाउनलोड करें", "下载公共题库包", "공개 문제 팩 다운로드",
                    "Descargar paquetes públicos", "Scarica pacchetti pubblici",
                    "Öffentliche Fragenpakete laden",
                ]
            case .downloadedBoundary:
                row = [
                    "Contenu public téléchargé. Ni correction ni XP en local.",
                    "Downloaded public content. No local correction or XP.",
                    "सार्वजनिक सामग्री डाउनलोड हुई। स्थानीय सुधार या XP नहीं।", "已下载公共内容。本地不评分、不授予 XP。",
                    "공개 콘텐츠 다운로드됨. 기기 내 채점이나 XP는 없습니다.",
                    "Contenido público descargado. Sin corrección ni XP locales.",
                    "Contenuto pubblico scaricato. Nessuna correzione o XP locali.",
                    "Öffentliche Inhalte geladen. Keine lokale Auswertung oder XP.",
                ]
            case .pathUnavailable:
                row = [
                    "Parcours non chargé", "Learning path not loaded", "सीखने का पथ लोड नहीं हुआ",
                    "学习路径未加载", "학습 경로 미로드", "Ruta no cargada", "Percorso non caricato",
                    "Lernpfad nicht geladen",
                ]
            case .pathRetryHint:
                row = [
                    "Charger ou réessayer ce parcours ne modifie pas l’objectif actif.",
                    "Load or retry this certification’s path. This does not change your active goal.",
                    "इस प्रमाणन का पथ लोड करें या फिर प्रयास करें। सक्रिय लक्ष्य नहीं बदलेगा।", "加载或重试此认证路径，不会更改当前目标。",
                    "경로를 불러오거나 재시도하세요. 활성 목표는 바뀌지 않습니다.",
                    "Carga o reintenta esta ruta. No cambia tu objetivo activo.",
                    "Carica o riprova il percorso. Non cambia l’obiettivo attivo.",
                    "Lade diesen Lernpfad oder versuche es erneut. Dein aktives Ziel bleibt unverändert.",
                ]
            case .retryPath:
                row = [
                    "Charger ou réessayer", "Load or retry path", "पथ लोड करें या फिर प्रयास करें", "加载或重试路径",
                    "경로 불러오기 또는 재시도", "Cargar o reintentar ruta", "Carica o riprova percorso",
                    "Lernpfad laden oder erneut versuchen",
                ]
            case .chooseCertification:
                row = [
                    "Choisir une certification", "Choose a certification", "प्रमाणन चुनें", "选择认证",
                    "인증 선택", "Elegir certificación", "Scegli certificazione",
                    "Zertifizierung wählen",
                ]
            case .pathServerHint:
                row = [
                    "Le parcours sera chargé depuis le serveur.",
                    "Its learning path will load from the server.", "पथ सर्वर से लोड होगा।",
                    "将从服务器加载学习路径。", "서버에서 학습 경로를 불러옵니다.", "La ruta se cargará desde el servidor.",
                    "Il percorso verrà caricato dal server.",
                    "Der Lernpfad wird vom Server geladen.",
                ]
            case .learningPath:
                row = [
                    "Parcours d’apprentissage", "Learning path", "सीखने का पथ", "学习路径", "학습 경로",
                    "Ruta de aprendizaje", "Percorso di apprendimento", "Lernpfad",
                ]
            case .answerInstruction:
                row = [
                    "Répondez, puis envoyez vos réponses pour correction par le serveur.",
                    "Answer the questions, then submit your answers for server correction.",
                    "प्रश्नों के उत्तर दें, फिर सर्वर सुधार के लिए जमा करें।", "回答问题后提交，由服务器评分。",
                    "문제에 답한 후 서버 채점을 위해 제출하세요.",
                    "Responde y envía tus respuestas para corrección del servidor.",
                    "Rispondi, poi invia per la correzione del server.",
                    "Beantworte die Fragen und sende sie zur Serverauswertung ab.",
                ]
            case .pendingCorrectionHint:
                row = [
                    "La correction sera demandée à la reconnexion. Aucun score ni XP confirmé.",
                    "Correction will be requested after reconnecting. No score or XP is confirmed yet.",
                    "दोबारा कनेक्ट होने पर सुधार माँगा जाएगा। अंक या XP की पुष्टि अभी नहीं है।", "重新连接后将请求评分，目前未确认分数或 XP。",
                    "재연결 후 채점을 요청합니다. 점수나 XP는 아직 확인되지 않았습니다.",
                    "Se pedirá corrección al reconectar. Aún no hay puntuación ni XP confirmados.",
                    "Correzione richiesta alla riconnessione. Nessun punteggio o XP ancora confermato.",
                    "Nach Wiederverbindung wird die Auswertung angefordert. Noch keine bestätigten Punkte oder XP.",
                ]
            case .confirmedResult:
                row = [
                    "Votre résultat confirmé", "Your confirmed result", "आपका पुष्ट परिणाम", "已确认的结果",
                    "확인된 결과", "Tu resultado confirmado", "Il tuo risultato confermato",
                    "Dein bestätigtes Ergebnis",
                ]
            case .answerCorrect:
                row = [
                    "Réponse correcte", "Correct answer", "सही उत्तर", "回答正确", "정답",
                    "Respuesta correcta", "Risposta corretta", "Richtige Antwort",
                ]
            case .reviewNeeded:
                row = [
                    "À réviser", "Review needed", "समीक्षा आवश्यक", "需要复习", "복습 필요", "Necesita repaso",
                    "Ripasso necessario", "Wiederholung nötig",
                ]
            case .newAttemptHint:
                row = [
                    "Commence une nouvelle sélection. La tentative confirmée reste dans l’historique.",
                    "Starts a new answer selection for this activity. Your confirmed attempt stays in history.",
                    "इस गतिविधि के लिए नया उत्तर चयन शुरू होगा। पुष्ट प्रयास इतिहास में रहेगा।", "为此活动开始新选择，已确认作答保留在历史中。",
                    "새 답변 선택을 시작합니다. 확인된 시도는 기록에 남습니다.",
                    "Inicia una selección nueva. Tu intento confirmado sigue en el historial.",
                    "Avvia una nuova selezione. Il tentativo confermato resta nella cronologia.",
                    "Startet eine neue Auswahl. Dein bestätigter Versuch bleibt im Verlauf.",
                ]
            case .practiceAgainHint:
                row = [
                    "Ouvrez une activité disponible pour vous exercer. Lire ne crée pas de tentative.",
                    "Open an available activity in the learning plan to practice again. Reading does not create another attempt.",
                    "फिर अभ्यास के लिए योजना की उपलब्ध गतिविधि खोलें। पढ़ने से नया प्रयास नहीं बनता।",
                    "打开学习计划中的可用活动再次练习。阅读不会创建新作答。", "다시 연습하려면 학습 계획의 활동을 여세요. 읽기는 시도를 만들지 않습니다.",
                    "Abre una actividad disponible para practicar. Leer no crea otro intento.",
                    "Apri un’attività disponibile per esercitarti. Leggere non crea un tentativo.",
                    "Öffne eine verfügbare Aktivität zum Üben. Lesen erzeugt keinen neuen Versuch.",
                ]
            case .lessonUnavailable:
                row = [
                    "Leçon indisponible", "Lesson unavailable", "पाठ उपलब्ध नहीं", "课程不可用", "학습 사용 불가",
                    "Lección no disponible", "Lezione non disponibile", "Lektion nicht verfügbar",
                ]
            case .lessonLoadFailure:
                row = [
                    "Impossible de charger la leçon choisie.",
                    "The selected lesson could not be loaded.", "चुना पाठ लोड नहीं हो सका।", "无法加载所选课程。",
                    "선택한 학습을 불러오지 못했습니다.", "No se pudo cargar la lección elegida.",
                    "Impossibile caricare la lezione selezionata.",
                    "Die gewählte Lektion konnte nicht geladen werden.",
                ]
            case .oneSession:
                row = [
                    "Une session à la fois", "One session at a time", "एक समय में एक सत्र", "一次一个学习单元",
                    "한 번에 하나의 세션", "Una sesión a la vez", "Una sessione alla volta",
                    "Eine Sitzung nach der anderen",
                ]
            case .chooseActivity:
                row = [
                    "Choisissez une activité du parcours.",
                    "Choose an activity in the learning path.", "सीखने के पथ में गतिविधि चुनें।",
                    "选择学习路径中的活动。", "학습 경로에서 활동을 선택하세요.", "Elige una actividad de la ruta.",
                    "Scegli un’attività nel percorso.", "Wähle eine Aktivität im Lernpfad.",
                ]
            case .goalPending:
                row = [
                    "Changement d’objectif en attente du serveur",
                    "Goal change pending · waiting for the server", "लक्ष्य परिवर्तन लंबित · सर्वर की प्रतीक्षा",
                    "目标更改等待中 · 等待服务器", "목표 변경 대기 · 서버 응답 대기",
                    "Cambio de objetivo pendiente · esperando servidor",
                    "Cambio obiettivo in attesa del server",
                    "Zielwechsel ausstehend · warte auf Server",
                ]
            case .goalConfirmed:
                row = [
                    "C’est votre objectif actif confirmé", "This is your confirmed active goal",
                    "यह आपका पुष्ट सक्रिय लक्ष्य है", "这是已确认的当前目标", "확인된 활성 목표입니다",
                    "Este es tu objetivo activo confirmado",
                    "Questo è l’obiettivo attivo confermato",
                    "Dies ist dein bestätigtes aktives Ziel",
                ]
            case .goalViewing:
                row = [
                    "Objectif consulté · non sélectionné", "Viewing a goal · not selected",
                    "लक्ष्य देख रहे हैं · चुना नहीं", "正在浏览目标 · 未选择", "목표 보기 · 미선택",
                    "Viendo un objetivo · no seleccionado",
                    "Obiettivo visualizzato · non selezionato", "Ziel ansehen · nicht ausgewählt",
                ]
            case .chooseGoal:
                row = [
                    "Choisir comme objectif actif", "Choose as active goal", "सक्रिय लक्ष्य के रूप में चुनें",
                    "设为当前目标", "활성 목표로 선택", "Elegir como objetivo activo",
                    "Scegli come obiettivo attivo", "Als aktives Ziel wählen",
                ]
            case .demoPreviewOnly:
                row = [
                    "Ceci est un aperçu de navigation, pas un service connecté.",
                    "This is a navigation preview, not a working service.",
                    "यह नेविगेशन पूर्वावलोकन है, चालू सेवा नहीं।", "这是导航预览，并非已连接服务。",
                    "이것은 탐색 미리 보기이며 연결된 서비스가 아닙니다.",
                    "Es una vista de navegación, no un servicio conectado.",
                    "È un’anteprima di navigazione, non un servizio connesso.",
                    "Dies ist eine Navigationsvorschau, kein verbundener Dienst.",
                ]
            case .demoHistory:
                row = [
                    "Historique de la démo", "Demo history", "डेमो इतिहास", "演示历史", "데모 기록",
                    "Historial de demo", "Cronologia demo", "Demo-Verlauf",
                ]
            case .demoHistoryHint:
                row = [
                    "Cette démonstration enregistrée ne constitue pas une progression de certification.",
                    "This saved demonstration is not certification progress.",
                    "यह सहेजा डेमो प्रमाणन प्रगति नहीं है।", "已保存演示并非认证学习进度。", "이 저장된 데모는 인증 학습 진행 상황이 아닙니다.",
                    "Esta demo guardada no es progreso de certificación.",
                    "Questa demo salvata non è progresso di certificazione.",
                    "Diese gespeicherte Demo ist kein Zertifizierungsfortschritt.",
                ]
            case .demoResponsibilities:
                row = [
                    "Qui gère quoi ?", "Who manages what?", "कौन क्या संभालता है?", "谁管理什么？",
                    "누가 무엇을 관리하나요?", "¿Quién gestiona qué?", "Chi gestisce cosa?",
                    "Wer verwaltet was?",
                ]
            case .demoNotice:
                row = [
                    "Démo · données et résultats fictifs", "Demo · fictional data and results",
                    "डेमो · काल्पनिक डेटा और परिणाम", "演示 · 虚构数据与结果", "데모 · 가상 데이터 및 결과",
                    "Demo · datos y resultados ficticios", "Demo · dati e risultati fittizi",
                    "Demo · fiktive Daten und Ergebnisse",
                ]
            case .demoFrenchExamples:
                row = [
                    "Exemples pédagogiques : français", "Learning examples: French",
                    "सीखने के उदाहरण: फ़्रेंच", "学习示例：法语", "학습 예시: 프랑스어", "Ejemplos de aprendizaje: francés",
                    "Esempi didattici: francese", "Lernbeispiele: Französisch",
                ]
            case .demoOptions:
                row = [
                    "Options de la démo", "Demo options", "डेमो विकल्प", "演示选项", "데모 옵션",
                    "Opciones de demo", "Opzioni demo", "Demo-Optionen",
                ]
            case .demoExploreSituation:
                row = [
                    "Explorer la situation", "Explore the situation", "स्थिति खोजें", "探索情境", "상황 살펴보기",
                    "Explorar la situación", "Esplora la situazione", "Situation erkunden",
                ]
            case .demoSituationNoGrade:
                row = [
                    "Une situation à explorer · sans note", "A situation to explore · no grade",
                    "समझने की स्थिति · अंक नहीं", "待探索的情境 · 不评分", "살펴볼 상황 · 점수 없음",
                    "Una situación para explorar · sin nota",
                    "Una situazione da esplorare · senza voto",
                    "Situation zum Erkunden · ohne Note",
                ]
            case .demoEditableChoice:
                row = [
                    "Un choix modifiable · non envoyé", "An editable choice · not submitted",
                    "बदल सकने वाला विकल्प · जमा नहीं", "可编辑选择 · 尚未提交", "변경 가능한 선택 · 제출 안 됨",
                    "Elección editable · no enviada", "Scelta modificabile · non inviata",
                    "Änderbare Auswahl · nicht abgesendet",
                ]
            case .demoAnswerPending:
                row = [
                    "Réponse de démo en attente · aucun résultat confirmé",
                    "Demo answer pending · no confirmed result", "डेमो उत्तर लंबित · पुष्ट परिणाम नहीं",
                    "演示答案等待中 · 无已确认结果", "데모 답변 대기 중 · 확인된 결과 없음",
                    "Respuesta demo pendiente · sin resultado confirmado",
                    "Risposta demo in attesa · nessun risultato confermato",
                    "Demo-Antwort ausstehend · kein bestätigtes Ergebnis",
                ]
            case .demoExplanationAvailable:
                row = [
                    "Explication fictive disponible · sans verdict",
                    "Fictional explanation available · no verdict", "काल्पनिक व्याख्या उपलब्ध · निर्णय नहीं",
                    "虚构解析已可查看 · 不作判定", "가상 설명 사용 가능 · 정답 판정 없음",
                    "Explicación ficticia disponible · sin veredicto",
                    "Spiegazione fittizia disponibile · nessun verdetto",
                    "Fiktive Erklärung verfügbar · kein Urteil",
                ]
            case .demoStartQuestion:
                row = [
                    "Commencer une question", "Start a question", "प्रश्न शुरू करें", "开始答题", "문제 시작",
                    "Empezar una pregunta", "Inizia una domanda", "Frage beginnen",
                ]
            case .demoResumeChoice:
                row = [
                    "Reprendre votre choix", "Resume your choice", "विकल्प पर लौटें", "继续你的选择",
                    "선택 이어서 하기", "Retomar tu elección", "Riprendi la scelta", "Auswahl fortsetzen",
                ]
            case .demoResumePending:
                row = [
                    "Reprendre la réponse en attente", "Resume the pending answer", "लंबित उत्तर पर लौटें",
                    "继续等待中的答案", "대기 중인 답변 이어서 하기", "Retomar respuesta pendiente",
                    "Riprendi risposta in attesa", "Ausstehende Antwort fortsetzen",
                ]
            case .demoReadExplanation:
                row = [
                    "Relire l’explication fictive", "Read the fictional explanation again",
                    "काल्पनिक व्याख्या फिर पढ़ें", "重读虚构解析", "가상 설명 다시 읽기",
                    "Volver a leer la explicación ficticia", "Rileggi la spiegazione fittizia",
                    "Fiktive Erklärung erneut lesen",
                ]
            case .demoCloudDiscovery:
                row = [
                    "Cloud · découverte", "Cloud · discovery", "क्लाउड · परिचय", "云 · 探索",
                    "클라우드 · 알아보기", "Nube · descubrimiento", "Cloud · scoperta", "Cloud · Einstieg",
                ]
            case .demoCloudOperations:
                row = [
                    "Cloud · exploitation", "Cloud · operations", "क्लाउड · संचालन", "云 · 运维",
                    "클라우드 · 운영", "Nube · operaciones", "Cloud · operazioni", "Cloud · Betrieb",
                ]
            case .demoCloudFundamentals:
                row = [
                    "Les fondamentaux du cloud", "Cloud fundamentals", "क्लाउड की बुनियाद", "云基础知识",
                    "클라우드 기초", "Fundamentos de la nube", "Fondamenti del cloud", "Cloud-Grundlagen",
                ]
            case .demoCloudPractice:
                row = [
                    "Les services cloud en pratique", "Cloud services in practice",
                    "व्यवहार में क्लाउड सेवाएँ", "云服务实践", "클라우드 서비스 실습", "Servicios de nube en la práctica",
                    "Servizi cloud in pratica", "Cloud-Dienste in der Praxis",
                ]
            case .demoStageSituation:
                row = [
                    "Situation", "Situation", "स्थिति", "情境", "상황", "Situación", "Situazione",
                    "Situation",
                ]
            case .demoStageDecision:
                row = [
                    "Décision", "Decision", "निर्णय", "决策", "결정", "Decisión", "Decisione",
                    "Entscheidung",
                ]
            case .demoStageExplanation:
                row = [
                    "Explication", "Explanation", "व्याख्या", "解析", "설명", "Explicación", "Spiegazione",
                    "Erklärung",
                ]
            case .demoStageHint:
                row = [
                    "Les étapes décrivent le parcours, pas la justesse d’une réponse.",
                    "Stages describe the learning flow, not whether an answer is correct.",
                    "चरण सीखने का क्रम हैं, उत्तर की शुद्धता नहीं।", "步骤表示学习流程，并不表示答案正确与否。",
                    "단계는 학습 흐름을 나타내며 정답 여부를 뜻하지 않습니다.",
                    "Las etapas describen el aprendizaje, no si la respuesta es correcta.",
                    "Le fasi descrivono il percorso, non la correttezza della risposta.",
                    "Die Schritte beschreiben den Lernablauf, nicht die Richtigkeit einer Antwort.",
                ]
            case .demoReady:
                row = ["Prêt", "Ready", "तैयार", "就绪", "준비됨", "Listo", "Pronto", "Bereit"]
            case .demoLoading:
                row = [
                    "Chargement", "Loading", "लोड हो रहा है", "加载中", "불러오는 중", "Cargando",
                    "Caricamento", "Laden",
                ]
            case .demoEmpty: row = ["Vide", "Empty", "खाली", "空", "비어 있음", "Vacío", "Vuoto", "Leer"]
            case .demoError:
                row = ["Erreur", "Error", "त्रुटि", "错误", "오류", "Error", "Errore", "Fehler"]
            case .close:
                row = ["Fermer", "Close", "बंद करें", "关闭", "닫기", "Cerrar", "Chiudi", "Schließen"]
            case .demoCoachUnavailable:
                row = [
                    "Le Coach n’est pas connecté dans cet aperçu. Aucune réponse IA, conversation ou mémoire n’est créée.",
                    "Coach is not connected in this preview. No AI response, conversation history or saved memory is created.",
                    "इस पूर्वावलोकन में कोच जुड़ा नहीं है। कोई AI जवाब, बातचीत या स्मृति नहीं बनती।",
                    "此预览未连接教练，不会创建 AI 回复、对话历史或记忆。",
                    "이 미리 보기에는 코치가 연결되어 있지 않습니다. AI 응답, 대화 기록, 메모리가 생성되지 않습니다.",
                    "El Coach no está conectado. No se crean respuestas de IA, historial ni memoria.",
                    "Il Coach non è connesso. Nessuna risposta IA, cronologia o memoria viene creata.",
                    "Coach ist nicht verbunden. Keine KI-Antworten, Gesprächsverläufe oder Erinnerungen werden erstellt.",
                ]
            case .demoCatalogStates:
                row = [
                    "États du catalogue · simulation", "Catalog states · simulation",
                    "कैटलॉग स्थितियाँ · अभ्यास", "目录状态 · 模拟", "카탈로그 상태 · 시뮬레이션",
                    "Estados del catálogo · simulación", "Stati del catalogo · simulazione",
                    "Katalogzustände · Simulation",
                ]
            case .demoCatalog:
                row = [
                    "Catalogue", "Catalog", "कैटलॉग", "目录", "카탈로그", "Catálogo", "Catalogo", "Katalog",
                ]
            case .demoOfflineToggle:
                row = [
                    "Simuler le mode hors ligne", "Simulate offline mode", "ऑफ़लाइन मोड का अभ्यास",
                    "模拟离线模式", "오프라인 모드 시뮬레이션", "Simular modo sin conexión",
                    "Simula modalità offline", "Offline-Modus simulieren",
                ]
            case .demoSettingsScope:
                row = [
                    "Ces réglages ne modifient ni le réseau de l’appareil ni un serveur.",
                    "These settings do not change the device network or a server.",
                    "ये सेटिंग डिवाइस नेटवर्क या सर्वर को नहीं बदलतीं।", "这些设置不会更改设备网络或服务器。",
                    "이 설정은 기기 네트워크나 서버를 변경하지 않습니다.",
                    "Estos ajustes no cambian la red del dispositivo ni un servidor.",
                    "Queste impostazioni non cambiano la rete del dispositivo o un server.",
                    "Diese Einstellungen ändern weder das Gerätenetzwerk noch einen Server.",
                ]
            case .demoSettings:
                row = [
                    "Réglages de la démo", "Demo settings", "डेमो सेटिंग", "演示设置", "데모 설정",
                    "Ajustes de la demo", "Impostazioni demo", "Demo-Einstellungen",
                ]
            case .demoResetConfirmation:
                row = [
                    "Effacer uniquement la démonstration enregistrée ?",
                    "Clear only the saved demonstration?", "केवल सहेजा हुआ डेमो मिटाएँ?", "仅清除已保存的演示？",
                    "저장된 데모만 지울까요?", "¿Borrar solo la demostración guardada?",
                    "Cancellare solo la demo salvata?", "Nur die gespeicherte Demo löschen?",
                ]
            case .demoReset:
                row = [
                    "Réinitialiser la démo", "Reset the demo", "डेमो रीसेट करें", "重置演示", "데모 재설정",
                    "Restablecer la demo", "Reimposta demo", "Demo zurücksetzen",
                ]
            case .demoRestorationUnavailable:
                row = [
                    "Restauration de la démo indisponible", "Demo restoration unavailable",
                    "डेमो बहाली उपलब्ध नहीं", "无法恢复演示", "데모 복원 불가", "Restauración de demo no disponible",
                    "Ripristino demo non disponibile", "Demo-Wiederherstellung nicht verfügbar",
                ]
            case .demoRestoreFailure:
                row = [
                    "La démo enregistrée est illisible. Réinitialisez uniquement la démo dans ses réglages.",
                    "The saved demonstration cannot be read. Reset only the demo in its settings.",
                    "सहेजा डेमो पढ़ा नहीं जा सका। सेटिंग में केवल डेमो रीसेट करें।", "无法读取已保存的演示，请仅在演示设置中重置演示。",
                    "저장된 데모를 읽을 수 없습니다. 데모 설정에서 데모만 재설정하세요.",
                    "No se puede leer la demo guardada. Restablece solo la demo en sus ajustes.",
                    "Impossibile leggere la demo salvata. Reimposta solo la demo nelle sue impostazioni.",
                    "Die gespeicherte Demo ist nicht lesbar. Setze nur die Demo in ihren Einstellungen zurück.",
                ]
            case .demoSaveFailure:
                row = [
                    "La démo n’a pas pu être enregistrée. Vous pouvez poursuivre cette session.",
                    "The demonstration could not be saved. You can continue in the current session.",
                    "डेमो सहेजा नहीं जा सका। मौजूदा सत्र जारी रख सकते हैं।", "无法保存演示，仍可继续当前会话。",
                    "데모를 저장할 수 없습니다. 현재 세션은 계속할 수 있습니다.",
                    "No se pudo guardar la demo. Puedes continuar esta sesión.",
                    "Impossibile salvare la demo. Puoi continuare la sessione attuale.",
                    "Die Demo konnte nicht gespeichert werden. Du kannst diese Sitzung fortsetzen.",
                ]
            case .demoReopenFailure:
                row = [
                    "La question ne peut pas être rouverte. Choisissez un objectif dans Apprendre > Explorer.",
                    "The question cannot be reopened. Choose a goal in Learn > Explore.",
                    "प्रश्न फिर नहीं खुल सका। सीखें > खोजें में लक्ष्य चुनें।", "无法重新打开题目，请在学习 > 探索中选择目标。",
                    "문제를 다시 열 수 없습니다. 학습 > 둘러보기에서 목표를 선택하세요.",
                    "No se puede reabrir la pregunta. Elige un objetivo en Aprender > Explorar.",
                    "Impossibile riaprire la domanda. Scegli un obiettivo in Impara > Esplora.",
                    "Die Frage kann nicht erneut geöffnet werden. Wähle ein Ziel unter Lernen > Entdecken.",
                ]
            case .demoReturnLearn:
                row = [
                    "Revenir à Apprendre", "Return to Learn", "सीखें पर लौटें", "返回学习", "학습으로 돌아가기",
                    "Volver a Aprender", "Torna a Impara", "Zurück zu Lernen",
                ]
            case .demoSocialUnavailable:
                row = [
                    "Social est indisponible dans cet aperçu. Aucune relation, invitation, équipe ou donnée partagée réelle n’est chargée.",
                    "Social is unavailable in this navigation preview. No real relationships, invitations, team membership or sharing are loaded.",
                    "इस पूर्वावलोकन में सामाजिक सुविधा उपलब्ध नहीं। कोई असली संबंध, निमंत्रण, टीम सदस्यता या साझा डेटा नहीं है।",
                    "此导航预览不提供社交功能，不会加载真实关系、邀请、团队成员或共享内容。",
                    "이 탐색 미리 보기에서는 소셜을 사용할 수 없습니다. 실제 관계, 초대, 팀 소속, 공유 데이터는 불러오지 않습니다.",
                    "Social no está disponible. No se cargan relaciones, invitaciones, equipos ni datos compartidos reales.",
                    "Social non è disponibile. Non vengono caricati relazioni, inviti, appartenenze o condivisioni reali.",
                    "Social ist nicht verfügbar. Keine echten Beziehungen, Einladungen, Teamzugehörigkeiten oder Freigaben werden geladen.",
                ]
            case .demoWorkshop:
                row = [
                    "L’atelier de décision", "The decision workshop", "निर्णय कार्यशाला", "决策练习坊",
                    "의사 결정 워크숍", "El taller de decisiones", "Il laboratorio decisionale",
                    "Die Entscheidungswerkstatt",
                ]
            case .demoWorkshopHint:
                row = [
                    "Lisez une situation, faites un choix, comprenez l’explication.",
                    "Read a situation, make a choice, understand the explanation.",
                    "स्थिति पढ़ें, विकल्प चुनें, व्याख्या समझें।", "阅读情境、作出选择、理解解析。", "상황을 읽고, 선택하고, 설명을 이해하세요.",
                    "Lee una situación, elige y comprende la explicación.",
                    "Leggi una situazione, scegli e comprendi la spiegazione.",
                    "Lies eine Situation, entscheide und verstehe die Erklärung.",
                ]
            case .demoFictionalContent:
                row = [
                    "Contenu fictif · pas un cours publié",
                    "Fictional content · not a published course", "काल्पनिक सामग्री · प्रकाशित पाठ्यक्रम नहीं",
                    "虚构内容 · 非已发布课程", "가상 콘텐츠 · 게시된 강좌 아님",
                    "Contenido ficticio · no es un curso publicado",
                    "Contenuto fittizio · non un corso pubblicato",
                    "Fiktiver Inhalt · kein veröffentlichter Kurs",
                ]
            case .demoSwitchGoal:
                row = [
                    "Changer d’objectif", "Switch goal", "लक्ष्य बदलें", "切换目标", "목표 변경",
                    "Cambiar objetivo", "Cambia obiettivo", "Ziel wechseln",
                ]
            case .demoHistoryAction:
                row = [
                    "Voir l’historique de la démo", "View demo history", "डेमो इतिहास देखें", "查看演示历史",
                    "데모 기록 보기", "Ver historial de demo", "Vedi cronologia demo",
                    "Demo-Verlauf ansehen",
                ]
            case .demoNextGoal:
                row = [
                    "Votre prochain objectif", "Your next learning goal", "आपका अगला सीखने का लक्ष्य",
                    "你的下一个学习目标", "다음 학습 목표", "Tu próximo objetivo", "Il tuo prossimo obiettivo",
                    "Dein nächstes Lernziel",
                ]
            case .demoExploreHint:
                row = [
                    "Explorez deux situations fictives. Aucun compte ni résultat réel n’est nécessaire.",
                    "Explore two fictional situations. No account or real result is needed.",
                    "दो काल्पनिक स्थितियाँ खोजें। खाता या असली परिणाम नहीं चाहिए।", "探索两个虚构情境，无需账户或真实结果。",
                    "두 가지 가상 상황을 살펴보세요. 계정이나 실제 결과는 필요 없습니다.",
                    "Explora dos situaciones ficticias. No necesitas cuenta ni resultados reales.",
                    "Esplora due situazioni fittizie. Non servono account o risultati reali.",
                    "Erkunde zwei fiktive Situationen. Kein Konto oder echtes Ergebnis nötig.",
                ]
            case .demoChooseHint:
                row = [
                    "Choisissez un objectif de démo. Ces exemples en français sont fictifs, pas des cours publiés.",
                    "Choose a demo goal to begin. These French examples are fictional, not published courses.",
                    "डेमो लक्ष्य चुनें। ये फ़्रेंच उदाहरण काल्पनिक हैं, प्रकाशित पाठ्यक्रम नहीं।", "选择演示目标开始。这些法语示例是虚构内容，并非已发布课程。",
                    "데모 목표를 선택하세요. 이 프랑스어 예시는 가상이며 게시된 강좌가 아닙니다.",
                    "Elige un objetivo de demo. Los ejemplos en francés son ficticios, no cursos publicados.",
                    "Scegli un obiettivo demo. Gli esempi francesi sono fittizi, non corsi pubblicati.",
                    "Wähle ein Demo-Ziel. Die französischen Beispiele sind fiktiv, keine veröffentlichten Kurse.",
                ]
            case .demoWorkshops:
                row = [
                    "Ateliers de démonstration", "Demonstration workshops", "डेमो कार्यशालाएँ", "演示练习坊",
                    "데모 워크숍", "Talleres de demostración", "Laboratori dimostrativi",
                    "Demo-Werkstätten",
                ]
            case .demoVolume:
                row = [
                    "1 situation fictive · 1 question · français",
                    "1 fictional situation · 1 question · French", "1 काल्पनिक स्थिति · 1 प्रश्न · फ़्रेंच",
                    "1 个虚构情境 · 1 道题 · 法语", "가상 상황 1개 · 문제 1개 · 프랑스어",
                    "1 situación ficticia · 1 pregunta · francés",
                    "1 situazione fittizia · 1 domanda · francese",
                    "1 fiktive Situation · 1 Frage · Französisch",
                ]
            case .demoSelectedGoal:
                row = [
                    "Objectif choisi", "Selected goal", "चुना लक्ष्य", "已选目标", "선택한 목표",
                    "Objetivo seleccionado", "Obiettivo selezionato", "Ausgewähltes Ziel",
                ]
            case .demoSituationExplore:
                row = [
                    "Une situation à explorer", "A situation to explore", "खोजने के लिए एक स्थिति",
                    "待探索的情境", "살펴볼 상황", "Una situación para explorar",
                    "Una situazione da esplorare", "Eine Situation zum Erkunden",
                ]
            case .demoFinishLoading:
                row = [
                    "Terminer le chargement simulé", "Finish simulated loading", "अभ्यास लोडिंग पूरी करें",
                    "完成模拟加载", "시뮬레이션 불러오기 완료", "Finalizar carga simulada",
                    "Termina caricamento simulato", "Simuliertes Laden beenden",
                ]
            case .demoNoGoals:
                row = [
                    "Aucun objectif dans cet exemple", "No goals in this example",
                    "इस उदाहरण में कोई लक्ष्य नहीं", "此示例中没有目标", "이 예시에 목표 없음",
                    "No hay objetivos en este ejemplo", "Nessun obiettivo in questo esempio",
                    "Keine Ziele in diesem Beispiel",
                ]
            case .demoEmptyHint:
                row = [
                    "Le catalogue vide est un scénario de démonstration.",
                    "The empty catalog is a demonstration scenario.", "खाली कैटलॉग एक डेमो स्थिति है।",
                    "空目录是演示情境。", "빈 카탈로그는 데모 시나리오입니다.",
                    "El catálogo vacío es un escenario de demo.",
                    "Il catalogo vuoto è uno scenario demo.",
                    "Der leere Katalog ist ein Demo-Szenario.",
                ]
            case .demoShowGoals:
                row = [
                    "Afficher les objectifs de démo", "Show demo goals", "डेमो लक्ष्य दिखाएँ", "显示演示目标",
                    "데모 목표 표시", "Mostrar objetivos de demo", "Mostra obiettivi demo",
                    "Demo-Ziele anzeigen",
                ]
            case .demoCatalogUnavailable:
                row = [
                    "Catalogue indisponible · simulation", "Catalog unavailable · simulation",
                    "कैटलॉग अनुपलब्ध · अभ्यास", "目录不可用 · 模拟", "카탈로그 사용 불가 · 시뮬레이션",
                    "Catálogo no disponible · simulación", "Catalogo non disponibile · simulazione",
                    "Katalog nicht verfügbar · Simulation",
                ]
            case .demoPreservedHint:
                row = [
                    "Votre état de démo est conservé. Aucun serveur n’est contacté.",
                    "Your demo state is preserved. No server is contacted.",
                    "डेमो स्थिति सुरक्षित है। किसी सर्वर से संपर्क नहीं होता।", "演示状态已保留，不会联系服务器。",
                    "데모 상태는 유지됩니다. 서버에 연결하지 않습니다.",
                    "Tu estado de demo se conserva. No se contacta con ningún servidor.",
                    "Lo stato demo è conservato. Nessun server viene contattato.",
                    "Dein Demo-Zustand bleibt erhalten. Kein Server wird kontaktiert.",
                ]
            case .demoScenarioHint:
                row = [
                    "Un scénario court pour explorer l’expérience native. Ce n’est pas un catalogue publié.",
                    "A short scenario to explore the native experience. This is not a published catalog.",
                    "मूल ऐप अनुभव खोजने के लिए छोटा परिदृश्य। यह प्रकाशित कैटलॉग नहीं।", "用于体验原生应用的简短情境，并非已发布目录。",
                    "네이티브 경험을 살펴보는 짧은 시나리오입니다. 게시된 카탈로그가 아닙니다.",
                    "Un escenario breve para explorar la experiencia nativa. No es un catálogo publicado.",
                    "Un breve scenario per esplorare l’esperienza nativa. Non è un catalogo pubblicato.",
                    "Ein kurzes Szenario zum Erkunden der nativen App. Kein veröffentlichter Katalog.",
                ]
            case .demoDecisionExplore:
                row = [
                    "La décision à explorer", "The decision to explore", "समझने के लिए निर्णय", "待探索的决策",
                    "살펴볼 결정", "La decisión que explorar", "La decisione da esplorare",
                    "Die zu erkundende Entscheidung",
                ]
            case .demoFictionalSituation:
                row = [
                    "La situation fictive", "The fictional situation", "काल्पनिक स्थिति", "虚构情境", "가상 상황",
                    "La situación ficticia", "La situazione fittizia", "Die fiktive Situation",
                ]
            case .demoNoGrade:
                row = [
                    "Lire, choisir, comprendre · sans note", "Read, choose, understand · no grade",
                    "पढ़ें, चुनें, समझें · अंक नहीं", "阅读、选择、理解 · 不评分", "읽고, 선택하고, 이해하기 · 점수 없음",
                    "Leer, elegir, comprender · sin nota", "Leggi, scegli, comprendi · senza voto",
                    "Lesen, wählen, verstehen · ohne Note",
                ]
            case .demoLocalRestore:
                row = [
                    "Restauration locale de la démo", "Local demo restoration", "डिवाइस पर डेमो बहाली",
                    "本机演示恢复", "기기 내 데모 복원", "Restauración local de demo", "Ripristino locale demo",
                    "Lokale Demo-Wiederherstellung",
                ]
            case .demoSituation:
                row = [
                    "La situation", "The situation", "स्थिति", "情境", "상황", "La situación",
                    "La situazione", "Die Situation",
                ]
            case .demoTask:
                row = [
                    "Votre mission", "Your task", "आपका कार्य", "你的任务", "과제", "Tu tarea",
                    "Il tuo compito", "Deine Aufgabe",
                ]
            case .demoBeforeChoose:
                row = [
                    "Avant de choisir", "Before you choose", "चुनने से पहले", "选择之前", "선택하기 전에",
                    "Antes de elegir", "Prima di scegliere", "Bevor du wählst",
                ]
            case .demoBoundaryHint:
                row = [
                    "Identifiez ce que l’équipe veut gérer et déléguer. Concentrez-vous sur cette limite, pas sur le nom du fournisseur.",
                    "Identify what the team wants to manage and what it wants to delegate. Focus on that boundary, not a provider name.",
                    "पहचानें कि टीम क्या संभालेगी और क्या सौंपेगी। प्रदाता के नाम नहीं, सीमा पर ध्यान दें।",
                    "识别团队希望管理和委托的职责，关注责任边界而非提供商名称。",
                    "팀이 직접 관리할 것과 위임할 것을 구분하세요. 제공자 이름보다 경계에 집중하세요.",
                    "Identifica qué quiere gestionar y delegar el equipo. Céntrate en ese límite, no en el proveedor.",
                    "Individua cosa il team vuole gestire o delegare. Concentrati sul confine, non sul fornitore.",
                    "Erkenne, was das Team verwalten oder delegieren möchte. Achte auf diese Grenze, nicht auf Anbieternamen.",
                ]
            case .demoOpenQuestion:
                row = [
                    "Ouvrir la question", "Open the question", "प्रश्न खोलें", "打开题目", "문제 열기",
                    "Abrir la pregunta", "Apri la domanda", "Frage öffnen",
                ]
            case .demoPreparation:
                row = [
                    "Préparation", "Preparation", "तैयारी", "准备", "준비", "Preparación", "Preparazione",
                    "Vorbereitung",
                ]
            case .demoChooseAnswer:
                row = [
                    "Choisissez une réponse", "Choose an answer", "उत्तर चुनें", "选择答案", "답변 선택",
                    "Elige una respuesta", "Scegli una risposta", "Wähle eine Antwort",
                ]
            case .demoAnswerSelected:
                row = [
                    "Réponse choisie", "Answer selected", "उत्तर चुना गया", "已选答案", "답변 선택됨",
                    "Respuesta seleccionada", "Risposta selezionata", "Antwort ausgewählt",
                ]
            case .selected:
                row = [
                    "Sélectionné", "Selected", "चुना गया", "已选择", "선택됨", "Seleccionado", "Selezionato",
                    "Ausgewählt",
                ]
            case .notSelected:
                row = [
                    "Non sélectionné", "Not selected", "नहीं चुना गया", "未选择", "선택 안 됨",
                    "No seleccionado", "Non selezionato", "Nicht ausgewählt",
                ]
            case .demoEditableHint:
                row = [
                    "Vous pouvez modifier votre choix avant l’envoi simulé.",
                    "You can change your choice before the simulated submission.",
                    "अभ्यास जमा करने से पहले विकल्प बदल सकते हैं।", "模拟提交前可更改选择。",
                    "시뮬레이션 제출 전에는 선택을 변경할 수 있습니다.",
                    "Puedes cambiar tu elección antes del envío simulado.",
                    "Puoi cambiare scelta prima dell’invio simulato.",
                    "Du kannst deine Auswahl vor dem simulierten Absenden ändern.",
                ]
            case .demoChooseBeforeContinue:
                row = [
                    "Choisissez une réponse avant de continuer.",
                    "Choose an answer before continuing.", "जारी रखने से पहले उत्तर चुनें।", "继续前请选择答案。",
                    "계속하기 전에 답변을 선택하세요.", "Elige una respuesta antes de continuar.",
                    "Scegli una risposta prima di continuare.",
                    "Wähle eine Antwort, bevor du fortfährst.",
                ]
            case .demoChoiceSaved:
                row = [
                    "Votre choix est enregistré dans la démo.", "Your choice is saved in the demo.",
                    "आपका विकल्प डेमो में सहेजा है।", "你的选择已保存在演示中。", "선택이 데모에 저장되었습니다.",
                    "Tu elección está guardada en la demo.", "La tua scelta è salvata nella demo.",
                    "Deine Auswahl ist in der Demo gespeichert.",
                ]
            case .demoNoVerdict:
                row = [
                    "Aucun verdict, score ou gain n’est calculé sur cet appareil.",
                    "No verdict, score or reward is calculated on this device.",
                    "इस डिवाइस पर निर्णय, अंक या पुरस्कार नहीं बनता।", "本机不会计算判定、分数或奖励。",
                    "이 기기에서는 정답 판정, 점수, 보상을 계산하지 않습니다.",
                    "No se calcula veredicto, puntuación ni recompensa en este dispositivo.",
                    "Sul dispositivo non si calcolano verdetti, punteggi o premi.",
                    "Auf diesem Gerät werden weder Urteil, Punktzahl noch Belohnung berechnet.",
                ]
            case .demoOfflinePending:
                row = [
                    "La réponse reste en attente. Le scénario hors ligne suspend l’étape suivante.",
                    "The demo answer remains pending. The offline scenario pauses the next simulation step.",
                    "डेमो उत्तर लंबित है। ऑफ़लाइन स्थिति अगला चरण रोकती है।", "演示答案仍在等待，离线情境会暂停下一模拟步骤。",
                    "데모 답변이 대기 중입니다. 오프라인 시나리오가 다음 단계를 멈춥니다.",
                    "La respuesta sigue pendiente. El escenario sin conexión pausa el siguiente paso.",
                    "La risposta resta in attesa. Lo scenario offline sospende il passo seguente.",
                    "Die Demo-Antwort bleibt ausstehend. Das Offline-Szenario pausiert den nächsten Schritt.",
                ]
            case .demoDisableOffline:
                row = [
                    "Désactiver le scénario hors ligne", "Turn off the offline scenario",
                    "ऑफ़लाइन स्थिति बंद करें", "关闭离线情境", "오프라인 시나리오 끄기", "Desactivar escenario sin conexión",
                    "Disattiva scenario offline", "Offline-Szenario ausschalten",
                ]
            case .demoSimulateHint:
                row = [
                    "L’action suivante simule une réponse serveur sans contacter d’API.",
                    "The next action simulates a server response. It does not contact an API.",
                    "अगली क्रिया सर्वर उत्तर का अभ्यास है। API से संपर्क नहीं होता।", "下一操作模拟服务器响应，不会调用 API。",
                    "다음 동작은 서버 응답을 시뮬레이션하며 API에 연결하지 않습니다.",
                    "La siguiente acción simula una respuesta sin contactar una API.",
                    "L’azione seguente simula una risposta senza contattare API.",
                    "Die nächste Aktion simuliert eine Serverantwort, ohne eine API zu kontaktieren.",
                ]
            case .demoSimulateExplanation:
                row = [
                    "Simuler l’explication fictive", "Simulate the fictional explanation",
                    "काल्पनिक व्याख्या दिखाएँ", "模拟虚构解析", "가상 설명 시뮬레이션", "Simular explicación ficticia",
                    "Simula spiegazione fittizia", "Fiktive Erklärung simulieren",
                ]
            case .demoExplanation:
                row = [
                    "Explication fictive · sans verdict", "Fictional explanation · no verdict",
                    "काल्पनिक व्याख्या · निर्णय नहीं", "虚构解析 · 不作判定", "가상 설명 · 정답 판정 없음",
                    "Explicación ficticia · sin veredicto",
                    "Spiegazione fittizia · nessun verdetto", "Fiktive Erklärung · kein Urteil",
                ]
            case .demoConstraint:
                row = [
                    "La contrainte décisive", "The decisive constraint", "निर्णायक शर्त", "决定性条件",
                    "결정적 제약", "La condición decisiva", "Il vincolo decisivo",
                    "Die entscheidende Bedingung",
                ]
            case .demoUnderstanding:
                row = [
                    "Comprendre la décision", "Understanding the decision", "निर्णय समझें", "理解决策",
                    "결정 이해하기", "Comprender la decisión", "Comprendere la decisione",
                    "Die Entscheidung verstehen",
                ]
            case .demoFixtureHint:
                row = [
                    "Cet exemple de conception n’est pas un corrigé publié. Il apparaît pour tous les choix : aucun verdict ni score.",
                    "This is a design fixture, not the correction of a published question. It appears for every choice: the demo gives no verdict or score.",
                    "यह डिज़ाइन उदाहरण है, प्रकाशित प्रश्न का सुधार नहीं। हर विकल्प पर यही दिखता है, कोई अंक या निर्णय नहीं।",
                    "这是设计示例而非已发布题目的解析。任何选择都会显示，不作判定或评分。",
                    "게시된 문제의 해설이 아닌 디자인 예시입니다. 어떤 선택에도 표시되며 정답 판정이나 점수는 없습니다.",
                    "Es un ejemplo de diseño, no una corrección publicada. Aparece con cualquier elección, sin veredicto ni nota.",
                    "È un esempio di design, non una correzione pubblicata. Appare per ogni scelta, senza verdetto o punteggio.",
                    "Dies ist ein Designbeispiel, keine veröffentlichte Korrektur. Es erscheint bei jeder Auswahl, ohne Urteil oder Punktzahl.",
                ]
            case .demoPracticeAgain:
                row = [
                    "Reprendre la question de démo", "Practice the demo question again",
                    "डेमो प्रश्न फिर करें", "再次练习演示题", "데모 문제 다시 연습",
                    "Practicar de nuevo la pregunta de demo", "Riprova la domanda demo",
                    "Demo-Frage erneut üben",
                ]
            case .demoPractice:
                row = [
                    "Exercice · démo", "Practice · demo", "अभ्यास · डेमो", "练习 · 演示", "연습 · 데모",
                    "Práctica · demo", "Pratica · demo", "Übung · Demo",
                ]
            case .demoChoice:
                row = [
                    "Votre choix dans la démo", "Your demo choice", "आपका डेमो विकल्प", "你的演示选择",
                    "데모에서 선택한 답변", "Tu elección en la demo", "La tua scelta demo",
                    "Deine Demo-Auswahl",
                ]
            case .demoProfile:
                row = [
                    "Profil de démonstration", "Preview profile", "पूर्वावलोकन प्रोफ़ाइल", "预览个人资料",
                    "미리 보기 프로필", "Perfil de vista previa", "Profilo di anteprima", "Vorschauprofil",
                ]
            case .demoProfileHint:
                row = [
                    "Aucun compte connecté. Cet écran montre uniquement la démonstration locale.",
                    "No account is signed in. This screen shows only the local demonstration.",
                    "कोई खाता साइन इन नहीं। यह केवल स्थानीय डेमो है।", "未登录账户，此屏幕仅显示本机演示。",
                    "로그인된 계정이 없습니다. 이 화면은 기기 내 데모만 표시합니다.",
                    "No hay cuenta conectada. Solo se muestra la demo local.",
                    "Nessun account connesso. Questa schermata mostra solo la demo locale.",
                    "Kein Konto ist angemeldet. Diese Ansicht zeigt nur die lokale Demo.",
                ]
            case .demoControls:
                row = [
                    "Commandes de démonstration", "Demonstration controls", "डेमो नियंत्रण", "演示控制",
                    "데모 제어", "Controles de demostración", "Controlli demo", "Demo-Steuerung",
                ]
            case .demoPreviewStates:
                row = [
                    "États et simulation hors ligne", "Preview states & offline simulation",
                    "स्थितियाँ और ऑफ़लाइन अभ्यास", "状态预览与离线模拟", "상태 미리 보기 및 오프라인 시뮬레이션",
                    "Estados y simulación sin conexión", "Stati e simulazione offline",
                    "Zustände und Offline-Simulation",
                ]
            case .demoAppearance:
                row = [
                    "Apparence et accessibilité", "Appearance & accessibility", "दिखावट और सुलभता",
                    "外观与辅助功能", "모양 및 손쉬운 사용", "Aspecto y accesibilidad", "Aspetto e accessibilità",
                    "Darstellung und Barrierefreiheit",
                ]
            case .demoAppearanceHint:
                row = [
                    "L’aperçu suit l’apparence et le texte du système. Navigation native et réduction de transparence sont respectées.",
                    "The preview follows system appearance and text size. Navigation uses system transitions and controls respect Reduce Transparency.",
                    "पूर्वावलोकन सिस्टम रूप और टेक्स्ट आकार अपनाता है। नेविगेशन और पारदर्शिता की सेटिंग का पालन होता है।",
                    "预览遵循系统外观与文字大小，使用系统导航过渡并尊重降低透明度设置。",
                    "미리 보기는 시스템 모양과 글자 크기를 따릅니다. 시스템 탐색 전환과 투명도 줄이기를 사용합니다.",
                    "La vista sigue el aspecto y texto del sistema. Usa transiciones nativas y respeta Reducir transparencia.",
                    "L’anteprima segue aspetto e testo di sistema. Usa transizioni native e rispetta Riduci trasparenza.",
                    "Die Vorschau folgt Systemdarstellung und Textgröße. Sie nutzt Systemübergänge und berücksichtigt reduzierte Transparenz.",
                ]
            case .demoAccountHint:
                row = [
                    "Les réglages de compte, confidentialité et notifications ne sont pas connectés. Aucune préférence de compte ne change.",
                    "Account, privacy and notification settings are not connected in this preview. No account preferences are changed.",
                    "खाता, गोपनीयता और सूचना सेटिंग जुड़ी नहीं हैं। खाता प्राथमिकताएँ नहीं बदलतीं।",
                    "此预览未连接账户、隐私或通知设置，不会更改账户偏好。",
                    "계정, 개인정보, 알림 설정은 연결되지 않았습니다. 계정 환경설정은 변경되지 않습니다.",
                    "Los ajustes de cuenta, privacidad y notificaciones no están conectados. No cambian preferencias reales.",
                    "Le impostazioni di account, privacy e notifiche non sono connesse. Nessuna preferenza reale cambia.",
                    "Konto-, Datenschutz- und Benachrichtigungseinstellungen sind nicht verbunden. Keine Kontoeinstellung wird geändert.",
                ]
            case .findGoal:
                row = [
                    "Trouvez votre prochain objectif.", "Find your next learning goal.",
                    "अपना अगला लक्ष्य खोजें।", "寻找下一个学习目标。", "다음 학습 목표를 찾아보세요.",
                    "Encuentra tu próximo objetivo.", "Trova il tuo prossimo obiettivo.",
                    "Finde dein nächstes Lernziel.",
                ]
            case .savedActivityHint:
                row = [
                    "Votre activité reste sur cet appareil. Reprendre ne l’envoie pas.",
                    "Your activity stays on this device. Resuming does not submit it.",
                    "गतिविधि इसी डिवाइस पर है। फिर शुरू करने से जमा नहीं होती।", "活动保留在本机，继续不会提交。",
                    "활동은 이 기기에 보관됩니다. 이어서 해도 제출되지 않습니다.",
                    "La actividad queda en este dispositivo. Reanudar no la envía.",
                    "L’attività resta sul dispositivo. Riprendere non la invia.",
                    "Die Aktivität bleibt auf diesem Gerät. Fortsetzen sendet sie nicht ab.",
                ]
            case .nextAvailableHint:
                row = [
                    "Prochaine activité disponible dans le parcours chargé.",
                    "Next available activity in the loaded path.", "लोड किए पथ की अगली उपलब्ध गतिविधि।",
                    "已加载路径中的下一个可用活动。", "불러온 과정에서 다음으로 가능한 활동입니다.",
                    "Siguiente actividad disponible del itinerario cargado.",
                    "Prossima attività disponibile nel percorso caricato.",
                    "Nächste verfügbare Aktivität im geladenen Lernpfad.",
                ]
            case .publicVersion:
                row = [
                    "Version publique chargée", "Loaded public content version", "लोड किया सार्वजनिक संस्करण",
                    "已加载的公开内容版本", "불러온 공개 콘텐츠 버전", "Versión pública cargada",
                    "Versione pubblica caricata", "Geladene öffentliche Inhaltsversion",
                ]
            case .codeGroup:
                row = [
                    "Groupe de codes", "Code group", "कोड समूह", "代码组", "코드 그룹", "Grupo de códigos",
                    "Gruppo di codici", "Codegruppe",
                ]
            case .confirmedSessions:
                row = [
                    "Résultats de sessions confirmés", "Confirmed session results", "पुष्ट सत्र परिणाम",
                    "已确认会话结果", "확인된 세션 결과", "Resultados de sesiones confirmados",
                    "Risultati delle sessioni confermati", "Bestätigte Sitzungsergebnisse",
                ]
            case .activityCoverage:
                row = [
                    "Activité et couverture", "Activity & coverage", "गतिविधि और कवरेज", "活动与覆盖范围",
                    "활동 및 범위", "Actividad y cobertura", "Attività e copertura",
                    "Aktivität und Abdeckung",
                ]
            case .localDevice:
                row = [
                    "Sur cet appareil", "On this device", "इस डिवाइस पर", "在此设备上", "이 기기에서",
                    "En este dispositivo", "Su questo dispositivo", "Auf diesem Gerät",
                ]
            case .completedActivities:
                row = [
                    "Activités terminées", "Completed activities", "पूरी गतिविधियाँ", "已完成活动", "완료된 활동",
                    "Actividades completadas", "Attività completate", "Abgeschlossene Aktivitäten",
                ]
            case .completedUnits:
                row = [
                    "Unités terminées", "Completed units", "पूरी इकाइयाँ", "已完成单元", "완료된 단원",
                    "Unidades completadas", "Unità completate", "Abgeschlossene Einheiten",
                ]
            case .localAnswers:
                row = [
                    "Réponses choisies sur l’appareil", "Locally selected answers",
                    "डिवाइस पर चुने उत्तर", "本机所选答案", "기기에서 선택한 답변",
                    "Respuestas elegidas en el dispositivo", "Risposte scelte sul dispositivo",
                    "Lokal ausgewählte Antworten",
                ]
            case .lastLoaded:
                row = [
                    "Dernier chargement", "Last loaded", "अंतिम बार लोड", "上次加载", "마지막 불러오기",
                    "Última carga", "Ultimo caricamento", "Zuletzt geladen",
                ]
            case .unloadedHistory:
                row = [
                    "Historique confirmé non chargé.", "Confirmed history has not been loaded.",
                    "पुष्ट इतिहास लोड नहीं हुआ।", "尚未加载已确认历史。", "확인된 기록을 아직 불러오지 않았습니다.",
                    "Historial confirmado sin cargar.", "Cronologia confermata non caricata.",
                    "Bestätigter Verlauf noch nicht geladen.",
                ]
            case .retrieveCorrection:
                row = [
                    "Récupérer le corrigé complet", "Retrieve full correction", "पूरा सुधार प्राप्त करें",
                    "获取完整解析", "전체 해설 가져오기", "Recuperar corrección completa",
                    "Recupera correzione completa", "Vollständige Korrektur laden",
                ]
            case .loadMore:
                row = [
                    "Afficher la suite", "Load more", "और लोड करें", "加载更多", "더 불러오기", "Cargar más",
                    "Carica altro", "Mehr laden",
                ]
            case .signInAgain:
                row = [
                    "Se reconnecter", "Sign in again", "फिर साइन इन करें", "重新登录", "다시 로그인",
                    "Volver a iniciar sesión", "Accedi di nuovo", "Erneut anmelden",
                ]
            case .availableActivity:
                row = [
                    "Disponible pour s’exercer", "Available to practice", "अभ्यास उपलब्ध", "可以练习",
                    "연습 가능", "Disponible para practicar", "Disponibile per esercitarsi",
                    "Zum Üben verfügbar",
                ]
            case .completedActivity:
                row = [
                    "Terminée · état du serveur", "Completed · server state", "पूरी · सर्वर स्थिति",
                    "已完成 · 服务器状态", "완료 · 서버 상태", "Completada · estado del servidor",
                    "Completata · stato del server", "Abgeschlossen · Serverstatus",
                ]
            case .lockedActivity:
                row = [
                    "Verrouillée", "Locked", "बंद", "已锁定", "잠김", "Bloqueada", "Bloccata", "Gesperrt",
                ]
            case .unit: row = ["Unité", "Unit", "इकाई", "单元", "단원", "Unidad", "Unità", "Einheit"]
            case .activityCoverageHint:
                row = [
                    "Terminé signifie completed ou mastered côté serveur, pas maîtrise ni réussite à l’examen.",
                    "Completed means completed or mastered on the server, not mastery or exam success.",
                    "पूर्ण का अर्थ सर्वर पर completed या mastered है, परीक्षा सफलता नहीं।",
                    "已完成表示服务器状态为 completed 或 mastered，并非掌握程度或考试成功。",
                    "완료는 서버의 completed 또는 mastered 상태이며 숙련이나 시험 합격을 뜻하지 않습니다.",
                    "Completado indica completed o mastered en el servidor, no dominio ni éxito en el examen.",
                    "Completato indica completed o mastered sul server, non padronanza né successo all’esame.",
                    "Abgeschlossen bedeutet completed oder mastered auf dem Server, nicht Beherrschung oder Prüfungserfolg.",
                ]
            case .lockedHint:
                row = [
                    "Verrouillé par le serveur. Motif du prérequis non fourni.",
                    "Locked by the server. No prerequisite reason is supplied.",
                    "सर्वर ने बंद किया। पूर्वशर्त का कारण नहीं दिया गया।", "服务器已锁定，未提供先修条件原因。",
                    "서버에서 잠겼습니다. 선수 조건 이유는 제공되지 않습니다.",
                    "Bloqueado por el servidor. No se indica el requisito.",
                    "Bloccato dal server. Motivo del prerequisito non fornito.",
                    "Vom Server gesperrt. Kein Grund für die Voraussetzung angegeben.",
                ]
            case .catalogFormats:
                row = [
                    "Les exercices utilisent le lecteur de questions pris en charge. Aucun format par certification n’est déclaré.",
                    "Practice uses the supported question reader. Per-certification formats are not declared.",
                    "अभ्यास समर्थित प्रश्न रीडर उपयोग करता है। प्रमाणन के प्रारूप घोषित नहीं हैं।", "练习使用支持的题目阅读器，未声明各认证题型。",
                    "지원되는 문제 리더로 연습합니다. 인증별 형식은 명시되지 않았습니다.",
                    "La práctica usa el lector compatible. No se declara el formato de cada certificación.",
                    "La pratica usa il lettore supportato. Formati per certificazione non dichiarati.",
                    "Übungen verwenden den unterstützten Fragenleser. Formate je Zertifizierung sind nicht angegeben.",
                ]
            case .radarLimits:
                row = [
                    "Les groupes viennent des codes. Les statuts annoncé/planifié et dates de sortie ne sont pas fournis. Les badges de langue exigent une déclaration du catalogue.",
                    "Groups come from codes. Announced and planned statuses are not supplied; no release date is inferred. Language badges require explicit catalog metadata.",
                    "समूह कोड से हैं। घोषित/नियोजित स्थिति या रिलीज़ तिथि नहीं मिली। भाषा बैज कैटलॉग घोषणा पर आधारित हैं।",
                    "分组来自代码。未提供已宣布或计划状态，也不推断发布日期。语言标记仅来自明确目录元数据。",
                    "그룹은 코드에서 가져옵니다. 발표·계획 상태와 출시일은 추정하지 않습니다. 언어 배지는 명시된 카탈로그 정보만 사용합니다.",
                    "Grupos por código. No se indican estados anunciado/planificado ni se infieren fechas. Idiomas solo con metadatos explícitos.",
                    "Gruppi dai codici. Stati annunciato/pianificato non forniti, date non dedotte. Lingue solo da metadati espliciti.",
                    "Gruppen stammen aus Codes. Angekündigt/geplant wird nicht geliefert; kein Veröffentlichungsdatum wird abgeleitet. Sprachabzeichen nur aus expliziten Katalogangaben.",
                ]
            case .catalogHint:
                row = [
                    "Explorer ne change pas votre objectif.", "Browsing does not change your goal.",
                    "ब्राउज़ करने से लक्ष्य नहीं बदलता।", "浏览不会更改目标。", "둘러봐도 목표는 바뀌지 않습니다.",
                    "Explorar no cambia tu objetivo.", "Esplorare non cambia il tuo obiettivo.",
                    "Stöbern ändert dein Ziel nicht.",
                ]
            case .findCertification:
                row = [
                    "Trouver une certification", "Find a certification", "प्रमाणन खोजें", "查找认证", "인증 찾기",
                    "Buscar certificación", "Trova una certificazione", "Zertifizierung finden",
                ]
            case .codeFamily:
                row = [
                    "Famille de codes", "Code family", "कोड समूह", "代码系列", "코드 계열",
                    "Familia de códigos", "Famiglia di codici", "Codefamilie",
                ]
            case .allFamilies:
                row = [
                    "Toutes les familles", "All code families", "सभी कोड समूह", "所有代码系列", "모든 코드 계열",
                    "Todas las familias", "Tutte le famiglie", "Alle Codefamilien",
                ]
            case .codeCategory:
                row = [
                    "Catégorie de codes", "Code category", "कोड श्रेणी", "代码分类", "코드 범주",
                    "Categoría de códigos", "Categoria di codici", "Codekategorie",
                ]
            case .availableOnly:
                row = [
                    "Exercices disponibles uniquement", "Available practice only", "केवल उपलब्ध अभ्यास",
                    "仅显示可练习内容", "가능한 연습만", "Solo práctica disponible", "Solo esercizi disponibili",
                    "Nur verfügbare Übungen",
                ]
            case .catalogScope: return native(.radarLimits)
            case .loadedResults:
                row = [
                    "Résultats / catalogue chargé", "Results / loaded catalog", "परिणाम / लोड किया कैटलॉग",
                    "结果 / 已加载目录", "결과 / 불러온 카탈로그", "Resultados / catálogo cargado",
                    "Risultati / catalogo caricato", "Ergebnisse / geladener Katalog",
                ]
            case .noCatalog:
                row = [
                    "Aucun catalogue chargé. Ce n’est pas un résultat de recherche.",
                    "No catalog is loaded. This is not a search result.",
                    "कैटलॉग लोड नहीं है। यह खोज परिणाम नहीं है।", "尚未加载目录，这不是搜索结果。",
                    "카탈로그가 로드되지 않았습니다. 검색 결과가 아닙니다.",
                    "No hay catálogo cargado. No es un resultado de búsqueda.",
                    "Nessun catalogo caricato. Non è un risultato di ricerca.",
                    "Kein Katalog geladen. Dies ist kein Suchergebnis.",
                ]
            case .noMatchesHint:
                row = [
                    "Modifiez la recherche ou effacez les filtres.",
                    "Change the query or clear the filters.", "खोज बदलें या फ़िल्टर हटाएँ।", "更改搜索或清除筛选。",
                    "검색어를 바꾸거나 필터를 지우세요.", "Cambia la búsqueda o borra los filtros.",
                    "Modifica la ricerca o cancella i filtri.",
                    "Ändere die Suche oder lösche die Filter.",
                ]
            case .continueDevice:
                row = [
                    "Reprendre sur cet appareil", "Continue on this device", "इस डिवाइस पर जारी रखें",
                    "在此设备继续", "이 기기에서 계속", "Continuar en este dispositivo",
                    "Continua sul dispositivo", "Auf diesem Gerät fortsetzen",
                ]
            case .restoreActivity:
                row = [
                    "Restaurer l’activité téléchargée", "Restore downloaded activity",
                    "डाउनलोड की गतिविधि बहाल करें", "恢复已下载活动", "다운로드 활동 복원",
                    "Restaurar actividad descargada", "Ripristina attività scaricata",
                    "Geladene Aktivität wiederherstellen",
                ]
            case .chooseGoalHint:
                row = [
                    "Choisissez un objectif disponible dans Explorer.",
                    "Choose an available goal in Explore.", "खोजें में उपलब्ध लक्ष्य चुनें।", "在探索中选择可用目标。",
                    "둘러보기에서 가능한 목표를 선택하세요.", "Elige un objetivo disponible en Explorar.",
                    "Scegli un obiettivo disponibile in Esplora.",
                    "Wähle ein verfügbares Ziel unter Entdecken.",
                ]
            case .guidedReading:
                row = [
                    "Lecture guidée", "Guided reading", "निर्देशित पढ़ाई", "引导阅读", "안내 읽기",
                    "Lectura guiada", "Lettura guidata", "Geführtes Lesen",
                ]
            case .frenchPilot:
                row = [
                    "Pilote éditorial français · environ 18 min · pas une certification.",
                    "French editorial pilot · estimated 18 min · not a certification.",
                    "फ़्रेंच संपादकीय पायलट · लगभग 18 मिनट · प्रमाणन नहीं।", "法语编辑试点 · 约18分钟 · 非认证。",
                    "프랑스어 편집 파일럿 · 약 18분 · 인증 아님.",
                    "Piloto editorial francés · unos 18 min · no es certificación.",
                    "Pilota editoriale francese · circa 18 min · non è una certificazione.",
                    "Französischer redaktioneller Pilot · etwa 18 Min. · keine Zertifizierung.",
                ]
            case .collection:
                row = [
                    "Catalogue des certifications", "Certification collection", "प्रमाणन संग्रह", "认证集合",
                    "인증 모음", "Colección de certificaciones", "Raccolta certificazioni",
                    "Zertifizierungssammlung",
                ]
            case .yourGoals:
                row = [
                    "Vos objectifs", "Your learning goals", "आपके लक्ष्य", "学习目标", "학습 목표",
                    "Tus objetivos", "I tuoi obiettivi", "Deine Lernziele",
                ]
            case .learningPlan:
                row = [
                    "Plan d’apprentissage", "Learning plan", "अध्ययन योजना", "学习计划", "학습 계획",
                    "Plan de aprendizaje", "Piano di apprendimento", "Lernplan",
                ]
            case .remainingActivities:
                row = [
                    "Activités restantes / total chargé", "Remaining activities / loaded total",
                    "शेष गतिविधियाँ / लोड कुल", "剩余活动 / 已加载总数", "남은 활동 / 불러온 전체",
                    "Actividades restantes / total cargado", "Attività rimanenti / totale caricato",
                    "Verbleibende Aktivitäten / geladene Gesamtzahl",
                ]
            case .activities:
                row = [
                    "Activités", "Activities", "गतिविधियाँ", "活动", "활동", "Actividades", "Attività",
                    "Aktivitäten",
                ]
            case .openPlanHint:
                row = [
                    "Ouvrez le plan pour consulter les activités et les verrouillages du serveur.",
                    "Open the plan for activities and server-reported locks.",
                    "गतिविधियाँ और सर्वर लॉक देखने के लिए योजना खोलें।", "打开计划查看活动和服务器锁定状态。",
                    "활동과 서버 잠금 상태를 보려면 계획을 여세요.",
                    "Abre el plan para ver actividades y bloqueos del servidor.",
                    "Apri il piano per attività e blocchi del server.",
                    "Öffne den Plan für Aktivitäten und serverseitige Sperren.",
                ]
            case .loadGoalHint:
                row = [
                    "Ouvrez l’objectif confirmé pour charger son plan.",
                    "Open your confirmed goal to load its plan.", "योजना लोड करने के लिए पुष्टि किया लक्ष्य खोलें।",
                    "打开已确认目标以加载计划。", "계획을 불러오려면 확인된 목표를 여세요.",
                    "Abre tu objetivo confirmado para cargar el plan.",
                    "Apri l’obiettivo confermato per caricare il piano.",
                    "Öffne dein bestätigtes Ziel, um den Plan zu laden.",
                ]
            case .reviewPractice:
                row = [
                    "Révision et exercices", "Review & practice", "पुनरावृत्ति और अभ्यास", "复习与练习", "복습과 연습",
                    "Repaso y práctica", "Ripasso ed esercizi", "Wiederholen und Üben",
                ]
            case .readCorrectionHint:
                row = [
                    "Relire une correction ne crée pas de tentative.",
                    "Reading a correction does not create an attempt.", "सुधार पढ़ने से नया प्रयास नहीं बनता।",
                    "阅读解析不会创建新答题记录。", "해설을 읽어도 시도가 생성되지 않습니다.",
                    "Leer una corrección no crea un intento.",
                    "Leggere una correzione non crea un tentativo.",
                    "Eine Korrektur zu lesen erstellt keinen Versuch.",
                ]
            case .goalOverview:
                row = [
                    "Vue d’ensemble de l’objectif", "Goal overview", "लक्ष्य का अवलोकन", "目标概览", "목표 개요",
                    "Resumen del objetivo", "Panoramica dell’obiettivo", "Zielübersicht",
                ]
            case .openOverview:
                row = [
                    "Ouvrir la vue d’ensemble", "Open overview", "अवलोकन खोलें", "打开概览", "개요 열기",
                    "Abrir resumen", "Apri panoramica", "Übersicht öffnen",
                ]
            case .overviewHint:
                row = [
                    "Résumé et disponibilité du catalogue. Votre objectif ne change pas.",
                    "Catalog summary and availability. Your goal is unchanged.",
                    "कैटलॉग सारांश और उपलब्धता। लक्ष्य नहीं बदलता।", "目录简介和可用性。目标保持不变。",
                    "카탈로그 요약과 이용 가능 여부입니다. 목표는 바뀌지 않습니다.",
                    "Resumen y disponibilidad del catálogo. Tu objetivo no cambia.",
                    "Riepilogo e disponibilità del catalogo. L’obiettivo non cambia.",
                    "Katalogübersicht und Verfügbarkeit. Dein Ziel bleibt unverändert.",
                ]
            case .nextSession:
                row = [
                    "Prochaine séance", "Next session", "अगला सत्र", "下一次学习", "다음 세션",
                    "Próxima sesión", "Prossima sessione", "Nächste Sitzung",
                ]
            case .confirmedLearning:
                row = [
                    "Apprentissage confirmé", "Confirmed learning", "पुष्टि की गई पढ़ाई", "已确认学习",
                    "확인된 학습", "Aprendizaje confirmado", "Apprendimento confermato",
                    "Bestätigtes Lernen",
                ]
            case .confirmedXP:
                row = [
                    "XP confirmés", "Confirmed XP", "पुष्ट XP", "已确认经验值", "확인된 XP", "XP confirmados",
                    "XP confermati", "Bestätigte XP",
                ]
            case .confirmedGoal:
                row = [
                    "Objectif confirmé", "Confirmed goal", "पुष्ट लक्ष्य", "已确认目标", "확인된 목표",
                    "Objetivo confirmado", "Obiettivo confermato", "Bestätigtes Ziel",
                ]
            case .noGoal:
                row = [
                    "Aucun objectif confirmé par le serveur.", "No server-confirmed goal.",
                    "सर्वर द्वारा पुष्ट लक्ष्य नहीं।", "暂无服务器确认的目标。", "서버에서 확인된 목표가 없습니다.",
                    "Sin objetivo confirmado por el servidor.",
                    "Nessun obiettivo confermato dal server.",
                    "Kein serverseitig bestätigtes Ziel.",
                ]
            case .yourAccount:
                row = [
                    "Votre compte", "Your account", "आपका खाता", "账户", "내 계정", "Tu cuenta",
                    "Il tuo account", "Dein Konto",
                ]
            case .account:
                row = ["Compte", "Account", "खाता", "账户", "계정", "Cuenta", "Account", "Konto"]
            case .accessibility:
                row = [
                    "Lecture et accessibilité", "Reading & accessibility", "पढ़ना और सुलभता", "阅读与辅助功能",
                    "읽기 및 손쉬운 사용", "Lectura y accesibilidad", "Lettura e accessibilità",
                    "Lesen und Bedienungshilfen",
                ]
            case .accessibilityHint:
                row = [
                    "Texte, VoiceOver, contraste et mouvement suivent les réglages système. Choisissez la voix dans la leçon.",
                    "Text, VoiceOver, contrast and motion follow system settings. Choose the reading voice in the lesson.",
                    "पाठ, VoiceOver, कंट्रास्ट और गति सिस्टम सेटिंग से चलते हैं। पाठ की आवाज़ पाठ में चुनें।",
                    "文字、VoiceOver、对比度和动态效果遵循系统设置。请在课程中选择朗读声音。",
                    "텍스트, VoiceOver, 대비와 동작은 시스템 설정을 따릅니다. 읽기 음성은 수업에서 선택하세요.",
                    "Texto, VoiceOver, contraste y movimiento siguen al sistema. Elige la voz en la lección.",
                    "Testo, VoiceOver, contrasto e movimento seguono il sistema. Scegli la voce nella lezione.",
                    "Text, VoiceOver, Kontrast und Bewegung folgen den Systemeinstellungen. Wähle die Stimme in der Lektion.",
                ]
            case .privacy:
                row = [
                    "Données et confidentialité", "Data & privacy", "डेटा और गोपनीयता", "数据与隐私",
                    "데이터 및 개인정보", "Datos y privacidad", "Dati e privacy", "Daten und Datenschutz",
                ]
            case .privacyHint:
                row = [
                    "Questions téléchargées et réponses en attente restent locales. L’historique confirmé vient du serveur. Se déconnecter ne supprime pas le compte.",
                    "Downloaded questions and pending answers stay local. Confirmed history comes from the server. Signing out does not delete your account.",
                    "डाउनलोड प्रश्न और लंबित उत्तर स्थानीय रहते हैं। पुष्ट इतिहास सर्वर से आता है। साइन आउट से खाता नहीं मिटता।",
                    "已下载题目和待提交答案保留在本机。已确认历史来自服务器。退出不会删除账户。",
                    "다운로드한 문제와 대기 중인 답변은 기기에 보관됩니다. 확인된 기록은 서버에서 가져옵니다. 로그아웃해도 계정은 삭제되지 않습니다.",
                    "Preguntas descargadas y respuestas pendientes son locales. El historial confirmado viene del servidor. Salir no elimina la cuenta.",
                    "Domande scaricate e risposte in attesa restano locali. La cronologia confermata viene dal server. Uscire non elimina l’account.",
                    "Geladene Fragen und ausstehende Antworten bleiben lokal. Bestätigter Verlauf kommt vom Server. Abmelden löscht kein Konto.",
                ]
            case .coachPrivacy:
                row = [
                    "Le Coach envoie la réponse choisie sur demande explicite. Aucune mémoire de conversation ni partage social n’est activé.",
                    "Coach sends the selected answer only on explicit request. No conversation memory or social sharing is enabled.",
                    "Coach केवल स्पष्ट अनुरोध पर चुना उत्तर भेजता है। बातचीत की स्मृति या सामाजिक साझाकरण सक्रिय नहीं है।",
                    "教练仅在明确请求后发送所选答案。未启用对话记忆或社交分享。",
                    "코치는 명시적으로 요청할 때만 선택한 답변을 전송합니다. 대화 기억이나 소셜 공유는 활성화되지 않았습니다.",
                    "El Coach envía la respuesta elegida solo cuando lo solicitas. Sin memoria de conversación ni intercambio social.",
                    "Il Coach invia la risposta scelta solo su richiesta esplicita. Nessuna memoria di conversazione o condivisione sociale.",
                    "Coach sendet die gewählte Antwort nur auf ausdrückliche Anfrage. Kein Gesprächsgedächtnis oder soziales Teilen aktiviert.",
                ]
            case .coachDisclosure:
                row = [
                    "Explication à la demande, fondée sur le contenu et vos résultats. Le serveur peut utiliser une réponse structurée sans IA générative. La correction reste indépendante.",
                    "On-demand explanation grounded in content and your results. The server may return a structured explanation without generative AI. Grading remains separate.",
                    "सामग्री और परिणामों पर आधारित माँगा गया स्पष्टीकरण। सर्वर बिना जनरेटिव AI के संरचित जवाब दे सकता है। मूल्यांकन अलग रहता है।",
                    "按需提供基于内容和学习结果的解释。服务器可能返回非生成式AI的结构化说明。评分独立进行。",
                    "콘텐츠와 결과에 근거한 요청형 설명입니다. 서버는 생성형 AI 없이 구조화된 설명을 반환할 수 있습니다. 채점은 별개입니다.",
                    "Explicación bajo demanda basada en contenido y resultados. El servidor puede responder sin IA generativa. La corrección es independiente.",
                    "Spiegazione su richiesta basata su contenuti e risultati. Il server può rispondere senza IA generativa. La valutazione resta separata.",
                    "Erklärung auf Anfrage anhand von Inhalten und Ergebnissen. Der Server kann ohne generative KI antworten. Die Bewertung bleibt getrennt.",
                ]
            case .currentContext:
                row = [
                    "Contexte d’apprentissage", "Learning context", "अध्ययन संदर्भ", "学习上下文", "학습 맥락",
                    "Contexto de aprendizaje", "Contesto di apprendimento", "Lernkontext",
                ]
            case .chooseContext:
                row = [
                    "Choisir une activité", "Choose an activity", "गतिविधि चुनें", "选择活动", "활동 선택",
                    "Elegir actividad", "Scegli attività", "Aktivität wählen",
                ]
            case .tutorFailure:
                row = [
                    "Explication non confirmée. Réessayez après une réponse corrigée et une connexion réseau.",
                    "Explanation not confirmed. Retry after a corrected answer and a network connection.",
                    "स्पष्टीकरण की पुष्टि नहीं हुई। उत्तर सुधरने और नेटवर्क उपलब्ध होने पर फिर प्रयास करें।",
                    "解释未确认。请在答案已批改且联网后重试。", "설명이 확인되지 않았습니다. 채점된 답변과 네트워크 연결을 확인한 후 다시 시도하세요.",
                    "Explicación no confirmada. Reintenta tras corregir la respuesta y conectar la red.",
                    "Spiegazione non confermata. Riprova dopo una risposta corretta dal server e con rete disponibile.",
                    "Erklärung nicht bestätigt. Versuche es nach einer bewerteten Antwort mit Netzwerk erneut.",
                ]
            case .sourceAI:
                row = [
                    "Source : IA", "Source: AI", "स्रोत: AI", "来源：AI", "출처: AI", "Fuente: IA",
                    "Fonte: IA", "Quelle: KI",
                ]
            case .sourceOther:
                row = [
                    "Source du serveur", "Server source", "सर्वर स्रोत", "服务器来源", "서버 출처",
                    "Fuente del servidor", "Fonte del server", "Serverquelle",
                ]
            case .attempts:
                row = [
                    "Tentatives", "Attempts", "प्रयास", "尝试次数", "시도", "Intentos", "Tentativi",
                    "Versuche",
                ]
            case .accuracy:
                row = [
                    "Précision", "Accuracy", "सटीकता", "准确率", "정확도", "Precisión", "Precisione",
                    "Genauigkeit",
                ]
            case .trend:
                row = ["Tendance", "Trend", "रुझान", "趋势", "추세", "Tendencia", "Tendenza", "Trend"]
            case .errors:
                row = ["Erreurs", "Errors", "गलतियाँ", "错误", "오류", "Errores", "Errori", "Fehler"]
            case .recurringErrors:
                row = [
                    "Difficulté récurrente", "Recurring struggle", "बार-बार कठिनाई", "反复困难", "반복되는 어려움",
                    "Dificultad recurrente", "Difficoltà ricorrente",
                    "Wiederkehrende Schwierigkeit",
                ]
            case .yes: row = ["Oui", "Yes", "हाँ", "是", "예", "Sí", "Sì", "Ja"]
            case .no: row = ["Non", "No", "नहीं", "否", "아니요", "No", "No", "Nein"]
            case .reviewEvidence:
                row = [
                    "Conseil fondé sur les résultats confirmés chargés, pas sur toutes vos tentatives. Les réponses en attente ne sont pas notées.",
                    "Advice uses loaded confirmed results, not all attempts. Pending answers are not scored.",
                    "सलाह लोड किए पुष्ट परिणामों पर आधारित है, सभी प्रयासों पर नहीं। लंबित उत्तरों का मूल्यांकन नहीं होता।",
                    "建议基于已加载且确认的结果，而非全部记录。待处理答案不计分。",
                    "불러온 확인된 결과를 기반으로 하며 전체 시도는 아닙니다. 대기 중인 답변은 채점하지 않습니다.",
                    "Consejo basado en resultados confirmados cargados, no en todos los intentos. Las respuestas pendientes no se puntúan.",
                    "Consiglio basato sui risultati confermati caricati, non su tutti i tentativi. Le risposte in attesa non sono valutate.",
                    "Hinweis anhand geladener bestätigter Ergebnisse, nicht aller Versuche. Ausstehende Antworten werden nicht bewertet.",
                ]
            case .noReview:
                row = [
                    "Chargez le plan confirmé pour obtenir une recommandation disponible.",
                    "Load the confirmed plan for an available recommendation.",
                    "उपलब्ध सलाह के लिए पुष्ट योजना लोड करें।", "加载已确认计划以获取可用建议。", "추천을 보려면 확인된 계획을 불러오세요.",
                    "Carga el plan confirmado para obtener una recomendación.",
                    "Carica il piano confermato per un consiglio disponibile.",
                    "Lade den bestätigten Plan für eine verfügbare Empfehlung.",
                ]
            case .refreshHistory:
                row = [
                    "Actualiser l’historique", "Refresh history", "इतिहास ताज़ा करें", "刷新历史", "기록 새로 고침",
                    "Actualizar historial", "Aggiorna cronologia", "Verlauf aktualisieren",
                ]
            case .lowestScore:
                row = [
                    "Résultat chargé le plus faible", "Lowest loaded score", "लोड किया न्यूनतम स्कोर",
                    "已加载最低得分", "불러온 최저 점수", "Menor puntuación cargada",
                    "Punteggio caricato più basso", "Niedrigster geladener Wert",
                ]
            case .continueReview:
                row = [
                    "Prochaine unité disponible", "Next available unit", "अगली उपलब्ध इकाई", "下一个可用单元",
                    "다음 가능한 단원", "Siguiente unidad disponible", "Prossima unità disponibile",
                    "Nächste verfügbare Einheit",
                ]
            case .contentLanguage:
                row = [
                    "Langue du contenu", "Content language", "सामग्री की भाषा", "内容语言", "콘텐츠 언어",
                    "Idioma del contenido", "Lingua del contenuto", "Inhaltssprache",
                ]
            case .beforeStart:
                row = [
                    "Avant de commencer", "Before you start", "शुरू करने से पहले", "开始之前", "시작하기 전에",
                    "Antes de empezar", "Prima di iniziare", "Vor dem Start",
                ]
            case .learningNotCertification:
                row = [
                    "Apprentissage, pas certification", "Learning, not certification",
                    "सीखना, प्रमाणन नहीं", "学习，非认证", "학습용, 인증 아님", "Aprendizaje, no certificación",
                    "Apprendimento, non certificazione", "Lernen, keine Zertifizierung",
                ]
            case .originalFrench:
                row = [
                    "Brouillon original français", "Original French draft", "मूल फ़्रेंच मसौदा", "法语原稿",
                    "프랑스어 원본 초안", "Borrador original francés", "Bozza originale francese",
                    "Französischer Originalentwurf",
                ]
            case .duration:
                row = [
                    "Durée estimée", "Estimated duration", "अनुमानित अवधि", "预计时长", "예상 소요 시간",
                    "Duración estimada", "Durata stimata", "Geschätzte Dauer",
                ]
            case .sourcesChecked:
                row = [
                    "Sources vérifiées le", "Sources checked on", "स्रोत जाँच की तारीख", "来源核查日期", "출처 확인일",
                    "Fuentes verificadas el", "Fonti verificate il", "Quellen geprüft am",
                ]
            case .lessons:
                row = ["Leçons", "Lessons", "पाठ", "课程", "수업", "Lecciones", "Lezioni", "Lektionen"]
            case .editorialPilot:
                row = [
                    "Pilote éditorial", "Editorial pilot", "संपादकीय पायलट", "编辑试点", "편집 파일럿",
                    "Piloto editorial", "Pilota editoriale", "Redaktioneller Pilot",
                ]
            case .studyPlan:
                row = [
                    "Plan de préparation", "Study plan", "तैयारी योजना", "备考计划", "학습 일정",
                    "Plan de estudio", "Piano di studio", "Studienplan",
                ]
            case .save:
                row = ["Enregistrer", "Save", "सहेजें", "保存", "저장", "Guardar", "Salva", "Speichern"]
            case .targetDate:
                row = [
                    "Date cible d’examen", "Target exam date", "लक्ष्य परीक्षा तिथि", "目标考试日期", "목표 시험일",
                    "Fecha objetivo del examen", "Data obiettivo esame",
                    "Angestrebter Prüfungstermin",
                ]
            case .initialLevel:
                row = [
                    "Niveau initial", "Initial level", "शुरुआती स्तर", "初始水平", "시작 수준", "Nivel inicial",
                    "Livello iniziale", "Ausgangsniveau",
                ]
            case .noTargetDate:
                row = [
                    "Sans date cible", "No target date", "लक्ष्य तिथि नहीं", "无目标日期", "목표 날짜 없음",
                    "Sin fecha objetivo", "Senza data obiettivo", "Kein Zieldatum",
                ]
            case .localPlanHint:
                row = [
                    "Préférence locale de préparation, pas un diagnostic ni une promesse de réussite.",
                    "Local study preference, not a diagnostic or a pass guarantee.",
                    "स्थानीय अध्ययन पसंद, निदान या पास होने की गारंटी नहीं।", "本地学习偏好，并非诊断或通过保证。",
                    "기기 내 학습 설정이며 진단이나 합격 보장이 아닙니다.",
                    "Preferencia local, no diagnóstico ni garantía de aprobar.",
                    "Preferenza locale, non diagnosi né garanzia di superamento.",
                    "Lokale Lernpräferenz, keine Diagnose oder Bestehensgarantie.",
                ]
            case .levelUnknown:
                row = [
                    "Non renseigné", "Not specified", "निर्दिष्ट नहीं", "未指定", "미지정", "Sin especificar",
                    "Non specificato", "Nicht angegeben",
                ]
            case .beginner:
                row = [
                    "Débutant", "Beginner", "शुरुआती", "初学者", "초급", "Principiante", "Principiante",
                    "Anfänger",
                ]
            case .intermediate:
                row = [
                    "Intermédiaire", "Intermediate", "मध्यम", "中级", "중급", "Intermedio", "Intermedio",
                    "Fortgeschritten",
                ]
            case .advanced:
                row = ["Avancé", "Advanced", "उन्नत", "高级", "고급", "Avanzado", "Avanzato", "Erfahren"]
            case .readiness:
                row = [
                    "Préparation à l’examen", "Exam readiness", "परीक्षा तैयारी", "考试准备度", "시험 준비도",
                    "Preparación del examen", "Preparazione all’esame", "Prüfungsbereitschaft",
                ]
            case .skills:
                row = [
                    "Vos compétences", "Your skills", "आपके कौशल", "技能", "내 역량", "Tus competencias",
                    "Le tue competenze", "Deine Fähigkeiten",
                ]
            case .focusArea:
                row = [
                    "Domaine prioritaire", "Focus area", "प्राथमिक क्षेत्र", "重点领域", "집중 영역",
                    "Área prioritaria", "Area prioritaria", "Schwerpunkt",
                ]
            case .review:
                row = [
                    "Révision", "Review", "पुनरावृत्ति", "复习", "복습", "Repaso", "Ripasso", "Wiederholung",
                ]
            case .finalAssessment:
                row = [
                    "Évaluation finale", "Final assessment", "अंतिम मूल्यांकन", "最终评估", "최종 평가",
                    "Evaluación final", "Valutazione finale", "Abschlussbewertung",
                ]
            case .rewards:
                row = [
                    "Objectifs et récompenses", "Goals & rewards", "लक्ष्य और पुरस्कार", "目标与奖励", "목표 및 보상",
                    "Objetivos y recompensas", "Obiettivi e premi", "Ziele und Belohnungen",
                ]
            case .notifications:
                row = [
                    "Notifications intelligentes", "Smart notifications", "स्मार्ट सूचनाएँ", "智能通知",
                    "스마트 알림", "Notificaciones inteligentes", "Notifiche intelligenti",
                    "Intelligente Benachrichtigungen",
                ]
            case .unavailable:
                row = [
                    "Contenu indisponible", "Content unavailable", "सामग्री उपलब्ध नहीं", "内容不可用",
                    "콘텐츠 이용 불가", "Contenido no disponible", "Contenuto non disponibile",
                    "Inhalt nicht verfügbar",
                ]
            case .contentLoadFailure:
                row = [
                    "Le contenu n’a pas pu être chargé ou vérifié. Réessayez.",
                    "Content could not be loaded or verified. Please retry.",
                    "सामग्री लोड या सत्यापित नहीं हुई। फिर प्रयास करें।", "无法加载或验证内容，请重试。",
                    "콘텐츠를 불러오거나 확인할 수 없습니다. 다시 시도하세요.",
                    "No se pudo cargar o verificar el contenido. Reintenta.",
                    "Impossibile caricare o verificare il contenuto. Riprova.",
                    "Inhalt konnte nicht geladen oder geprüft werden. Erneut versuchen.",
                ]
            case .historyUnconfirmed:
                row = [
                    "Historique non confirmé", "History not confirmed", "इतिहास की पुष्टि नहीं हुई", "历史未确认",
                    "기록 확인 안 됨", "Historial sin confirmar", "Cronologia non confermata",
                    "Verlauf nicht bestätigt",
                ]
            case .understandSituation:
                row = [
                    "Comprendre la situation", "Understand the situation", "स्थिति समझें", "理解情境",
                    "상황 이해하기", "Comprender la situación", "Comprendi la situazione",
                    "Die Situation verstehen",
                ]
            case .keyIdeas:
                row = [
                    "Idées clés", "Key ideas", "मुख्य विचार", "核心概念", "핵심 개념", "Ideas clave",
                    "Idee chiave", "Kernideen",
                ]
            case .workedExample:
                row = [
                    "Exemple détaillé", "Worked example", "समझाया उदाहरण", "示例详解", "풀이 예시",
                    "Ejemplo resuelto", "Esempio svolto", "Ausgearbeitetes Beispiel",
                ]
            case .selfCheck:
                row = [
                    "Auto-évaluation · aucune réponse enregistrée",
                    "Self-check · no answer recorded", "स्व-जाँच · उत्तर रिकॉर्ड नहीं होता", "自查 · 不记录答案",
                    "자기 점검 · 답변 기록 안 함", "Autoevaluación · sin respuesta registrada",
                    "Autoverifica · nessuna risposta registrata",
                    "Selbstkontrolle · keine Antwort gespeichert",
                ]
            case .takeaway:
                row = [
                    "À retenir", "Takeaway", "सार", "要点总结", "핵심 정리", "Conclusión", "Da ricordare",
                    "Merksatz",
                ]
            case .sourcesLimits:
                row = [
                    "Sources et limites", "Sources & limits", "स्रोत और सीमाएँ", "来源与限制", "출처 및 한계",
                    "Fuentes y límites", "Fonti e limiti", "Quellen und Grenzen",
                ]
            case .openSource:
                row = [
                    "Ouvrir la source", "Open source", "स्रोत खोलें", "打开来源", "출처 열기", "Abrir fuente",
                    "Apri fonte", "Quelle öffnen",
                ]
            case .readingHistory:
                row = [
                    "Votre historique de lecture", "Your reading history", "आपका पढ़ने का इतिहास", "阅读历史",
                    "내 읽기 기록", "Tu historial de lectura", "La tua cronologia di lettura",
                    "Dein Leseverlauf",
                ]
            case .markedRead:
                row = [
                    "Marqué comme lu", "Marked as read", "पढ़ा हुआ चिह्नित", "已标为已读", "읽음으로 표시됨",
                    "Marcado como leído", "Segnato come letto", "Als gelesen markiert",
                ]
            case .lastOpened:
                row = [
                    "Dernière ouverture", "Last opened", "अंतिम बार खोला", "上次打开", "최근 열기",
                    "Última apertura", "Ultima apertura", "Zuletzt geöffnet",
                ]
            case .markRead:
                row = [
                    "Marquer comme lu", "Mark as read", "पढ़ा हुआ चिह्नित करें", "标为已读", "읽음으로 표시",
                    "Marcar como leído", "Segna come letto", "Als gelesen markieren",
                ]
            case .declarationHint:
                row = [
                    "Cette déclaration ne mesure ni maîtrise ni performance.",
                    "This declaration does not measure mastery or performance.",
                    "यह घोषणा महारत या प्रदर्शन नहीं मापती।", "此标记不衡量掌握程度或表现。", "이 표시는 숙련도나 성과를 측정하지 않습니다.",
                    "Esta declaración no mide dominio ni rendimiento.",
                    "Questa dichiarazione non misura padronanza o prestazioni.",
                    "Diese Angabe misst weder Beherrschung noch Leistung.",
                ]
            case .revisit:
                row = [
                    "Revoir la leçon", "Revisit the lesson", "पाठ फिर देखें", "重温课程", "수업 다시 보기",
                    "Revisar lección", "Rivedi la lezione", "Lektion erneut ansehen",
                ]
            case .readAgain:
                row = [
                    "Relire", "Read again", "फिर पढ़ें", "再次阅读", "다시 읽기", "Volver a leer",
                    "Rileggi",
                    "Erneut lesen",
                ]
            case .formativePractice:
                row = [
                    "Revoir l’exercice formatif", "Revisit formative practice", "सीखने का अभ्यास फिर देखें",
                    "重温学习练习", "학습 연습 다시 보기", "Revisar práctica formativa",
                    "Rivedi esercizio formativo", "Lernübung erneut ansehen",
                ]
            case .noScoreHint:
                row = [
                    "Relire ne change pas l’historique. Cet exercice n’envoie aucune réponse et ne donne ni score ni XP.",
                    "Rereading does not change history. This exercise sends no answer and awards no score or XP.",
                    "फिर पढ़ने से इतिहास नहीं बदलता। यह अभ्यास उत्तर नहीं भेजता, स्कोर या XP नहीं देता।",
                    "重读不会更改历史。此练习不提交答案，也不授予分数或经验值。",
                    "다시 읽어도 기록은 바뀌지 않습니다. 이 연습은 답변을 보내지 않으며 점수나 XP를 주지 않습니다.",
                    "Releer no cambia el historial. Este ejercicio no envía respuestas ni otorga puntos o XP.",
                    "Rileggere non cambia la cronologia. L’esercizio non invia risposte né assegna punteggi o XP.",
                    "Erneutes Lesen ändert den Verlauf nicht. Diese Übung sendet keine Antwort und vergibt weder Punkte noch XP.",
                ]
            case .unsynced:
                row = [
                    "Lecture non synchronisée. Aucun marquage lu enregistré.",
                    "Reading not synchronized. No read declaration recorded.",
                    "पढ़ना सिंक नहीं हुआ। पढ़ा हुआ दर्ज नहीं है।", "阅读未同步，未记录已读标记。",
                    "읽기가 동기화되지 않았습니다. 읽음 표시가 기록되지 않았습니다.",
                    "Lectura sin sincronizar. No se registró como leída.",
                    "Lettura non sincronizzata. Nessun segno di lettura registrato.",
                    "Lesen nicht synchronisiert. Keine Gelesen-Angabe gespeichert.",
                ]
            case .readNotConfirmed:
                row = [
                    "Le serveur n’a pas confirmé la déclaration. Réessayez.",
                    "The server did not confirm the declaration. Please retry.",
                    "सर्वर ने घोषणा की पुष्टि नहीं की। फिर प्रयास करें।", "服务器未确认标记，请重试。",
                    "서버가 표시를 확인하지 못했습니다. 다시 시도하세요.",
                    "El servidor no confirmó la declaración. Reintenta.",
                    "Il server non ha confermato la dichiarazione. Riprova.",
                    "Der Server hat die Angabe nicht bestätigt. Erneut versuchen.",
                ]
            case .readAloud:
                row = [
                    "Lire la leçon à voix haute", "Read lesson aloud", "पाठ ज़ोर से पढ़ें", "朗读课程",
                    "수업 소리 내어 읽기", "Leer lección en voz alta", "Leggi la lezione ad alta voce",
                    "Lektion vorlesen",
                ]
            case .dataFailure:
                row = [
                    "Données non confirmées. Réessayez en ligne.",
                    "Data not confirmed. Retry online.", "डेटा की पुष्टि नहीं हुई। ऑनलाइन फिर प्रयास करें।",
                    "数据未确认，请联网重试。", "데이터가 확인되지 않았습니다. 온라인에서 다시 시도하세요.",
                    "Datos sin confirmar. Reintenta en línea.",
                    "Dati non confermati. Riprova online.",
                    "Daten nicht bestätigt. Online erneut versuchen.",
                ]
            case .refreshData:
                row = [
                    "Actualiser les données", "Refresh data", "डेटा ताज़ा करें", "刷新数据", "데이터 새로 고침",
                    "Actualizar datos", "Aggiorna dati", "Daten aktualisieren",
                ]
            case .remainingLearning:
                row = [
                    "Temps estimé des activités restantes", "Estimated remaining activity time",
                    "शेष गतिविधियों का अनुमानित समय", "剩余活动预计时间", "남은 활동 예상 시간",
                    "Tiempo estimado de actividades restantes", "Tempo stimato attività rimanenti",
                    "Geschätzte Zeit verbleibender Aktivitäten",
                ]
            case .readinessHint:
                row = [
                    "Indicateur d’apprentissage du serveur, pas une probabilité de réussite ni une garantie. Une activité terminée n’est pas forcément maîtrisée.",
                    "Server learning indicator, not a pass probability or guarantee. Completed does not mean mastered.",
                    "सर्वर का अध्ययन संकेतक, पास होने की संभावना या गारंटी नहीं। पूरा करना महारत नहीं है।",
                    "服务器学习指标，并非通过概率或保证。完成不等于掌握。",
                    "서버 학습 지표이며 합격 확률이나 보장이 아닙니다. 완료가 숙련을 의미하지는 않습니다.",
                    "Indicador de aprendizaje del servidor, no probabilidad ni garantía de aprobar. Completar no es dominar.",
                    "Indicatore del server, non probabilità o garanzia di superamento. Completare non significa padroneggiare.",
                    "Lernindikator des Servers, keine Bestehenswahrscheinlichkeit oder Garantie. Abgeschlossen heißt nicht beherrscht.",
                ]
            case .domainMasteryUnavailable:
                row = [
                    "Score par domaine chargé ; couverture et maîtrise détaillées par domaine non fournies. Aucun nombre de domaines maîtrisés n’est déduit.",
                    "Loaded domain score; detailed domain coverage and mastery are not provided. No mastered-domain count is inferred.",
                    "लोड किया क्षेत्र स्कोर; विस्तृत कवरेज और महारत नहीं दिए गए हैं। महारत वाले क्षेत्रों की संख्या अनुमानित नहीं है।",
                    "已加载领域得分；未提供详细覆盖率和掌握程度，不推断已掌握领域数量。",
                    "불러온 영역 점수입니다. 영역별 상세 범위와 숙련도는 제공되지 않으며 숙련 영역 수를 추정하지 않습니다.",
                    "Puntuación por dominio cargada; sin cobertura ni dominio detallados. No se deducen dominios dominados.",
                    "Punteggio per dominio caricato; copertura e padronanza dettagliate non fornite. Nessun conteggio dedotto.",
                    "Geladener Bereichswert; detaillierte Abdeckung und Beherrschung fehlen. Keine Anzahl beherrschter Bereiche abgeleitet.",
                ]
            case .reviewTimingUnavailable:
                row = [
                    "Aucun calendrier de révision complet fourni. Seules les recommandations chargées sont affichées.",
                    "No complete review schedule is provided. Only loaded recommendations are shown.",
                    "पूरी पुनरावृत्ति समय-सारणी नहीं दी गई। केवल लोड की सलाह दिखाई जाती है।", "未提供完整复习日程，仅显示已加载建议。",
                    "전체 복습 일정은 제공되지 않습니다. 불러온 추천만 표시합니다.",
                    "Sin calendario completo de repaso. Solo se muestran recomendaciones cargadas.",
                    "Nessun calendario di ripasso completo fornito. Solo consigli caricati.",
                    "Kein vollständiger Wiederholungsplan vorhanden. Nur geladene Empfehlungen werden angezeigt.",
                ]
            case .reviewRisk:
                row = [
                    "Risque d’oubli indiqué par le serveur", "Server-reported forgetting risk",
                    "सर्वर द्वारा दिया भूलने का जोखिम", "服务器报告的遗忘风险", "서버에서 보고한 망각 위험",
                    "Riesgo de olvido del servidor", "Rischio di dimenticanza del server",
                    "Serverseitiges Vergessensrisiko",
                ]
            case .sourceServer:
                row = [
                    "Source : serveur", "Source: server", "स्रोत: सर्वर", "来源：服务器", "출처: 서버",
                    "Fuente: servidor", "Fonte: server", "Quelle: Server",
                ]
            case .level: row = ["Niveau", "Level", "स्तर", "等级", "레벨", "Nivel", "Livello", "Stufe"]
            case .streak:
                row = [
                    "Série de jours", "Streak days", "लगातार दिन", "连续天数", "연속 학습일", "Días de racha",
                    "Giorni consecutivi", "Tages-Serie",
                ]
            case .dailyGoal:
                row = [
                    "Objectif quotidien XP", "Daily XP goal", "दैनिक XP लक्ष्य", "每日经验值目标", "일일 XP 목표",
                    "Objetivo diario XP", "Obiettivo XP giornaliero", "Tägliches XP-Ziel",
                ]
            case .earned:
                row = ["Gagnés", "Earned", "अर्जित", "已获得", "획득", "Ganados", "Guadagnati", "Verdient"]
            case .achievements:
                row = [
                    "Succès", "Achievements", "उपलब्धियाँ", "成就", "업적", "Logros", "Traguardi", "Erfolge",
                ]
            case .quests:
                row = [
                    "Quêtes", "Quests", "खोज अभियान", "任务", "퀘스트", "Misiones", "Missioni", "Aufgaben",
                ]
            case .strongest:
                row = [
                    "Meilleur score de domaine chargé", "Highest loaded domain score",
                    "लोड किया उच्चतम क्षेत्र स्कोर", "已加载最高领域得分", "불러온 최고 영역 점수",
                    "Mayor puntuación de dominio cargada", "Punteggio di dominio caricato più alto",
                    "Höchster geladener Bereichswert",
                ]
            case .selectedAnswer:
                row = [
                    "Votre réponse envoyée", "Your submitted answer", "आपका जमा उत्तर", "已提交答案",
                    "제출한 답변", "Tu respuesta enviada", "La tua risposta inviata",
                    "Deine eingereichte Antwort",
                ]
            case .correctAnswer:
                row = [
                    "Réponse confirmée", "Confirmed answer", "पुष्ट उत्तर", "已确认答案", "확인된 답변",
                    "Respuesta confirmada", "Risposta confermata", "Bestätigte Antwort",
                ]
            case .masteryChange:
                row = [
                    "Évolution de maîtrise", "Mastery change", "महारत में बदलाव", "掌握程度变化", "숙련도 변화",
                    "Cambio de dominio", "Variazione padronanza", "Änderung der Beherrschung",
                ]
            case .nextReview:
                row = [
                    "Prochaine révision indiquée", "Reported next review", "अगली पुनरावृत्ति बताई गई",
                    "报告的下次复习", "보고된 다음 복습", "Próximo repaso indicado", "Prossimo ripasso indicato",
                    "Angegebene nächste Wiederholung",
                ]
            case .learnStage:
                row = ["Apprendre", "Learn", "सीखें", "学习", "학습", "Aprender", "Impara", "Lernen"]
            case .understandStage:
                row = [
                    "Comprendre", "Understand", "समझें", "理解", "이해", "Comprender", "Comprendi",
                    "Verstehen",
                ]
            case .recallApplyStage:
                row = [
                    "Rappeler et appliquer", "Recall & apply", "याद करें और लागू करें", "回忆与应用", "회상 및 적용",
                    "Recordar y aplicar", "Ricorda e applica", "Abrufen und anwenden",
                ]
            case .feedbackStage:
                row = [
                    "Correction", "Feedback", "प्रतिक्रिया", "反馈", "피드백", "Corrección", "Riscontro",
                    "Rückmeldung",
                ]
            case .masterStage:
                row = [
                    "Maîtriser", "Master", "महारत", "掌握", "숙련", "Dominar", "Padroneggia",
                    "Beherrschen",
                ]
            case .questionType:
                row = [
                    "Type de question", "Question type", "प्रश्न प्रकार", "题型", "문제 유형",
                    "Tipo de pregunta", "Tipo di domanda", "Fragetyp",
                ]
            case .multipleChoice:
                row = [
                    "Choix unique", "Multiple choice · one answer", "बहुविकल्पी · एक उत्तर", "单选题",
                    "객관식 · 답 하나", "Opción múltiple · una respuesta",
                    "Scelta multipla · una risposta", "Mehrfachauswahl · eine Antwort",
                ]
            case .reviewRecommendations:
                row = [
                    "Recommandations de révision chargées", "Loaded review recommendations",
                    "लोड की पुनरावृत्ति सलाह", "已加载复习建议", "불러온 복습 추천", "Recomendaciones de repaso cargadas",
                    "Consigli di ripasso caricati", "Geladene Wiederholungsempfehlungen",
                ]
            case .planNotLoaded:
                row = [
                    "Plan non chargé", "Plan not loaded", "योजना लोड नहीं है", "计划未加载", "계획을 불러오지 않음",
                    "Plan no cargado", "Piano non caricato", "Plan nicht geladen",
                ]
            case .assessmentPassed:
                row = [
                    "Simulation réussie", "Assessment passed", "मूल्यांकन सफल", "模拟评估通过", "평가 통과",
                    "Simulación superada", "Simulazione superata", "Simulation bestanden",
                ]
            case .assessmentReview:
                row = [
                    "À réviser avant l’examen", "Review before the exam", "परीक्षा से पहले दोहराएँ", "考前复习",
                    "시험 전 복습", "Repasar antes del examen", "Ripassa prima dell’esame",
                    "Vor der Prüfung wiederholen",
                ]
            case .assessmentDisclaimer:
                row = [
                    "Simulation corrigée par le serveur, pas un examen officiel ni une garantie de réussite. Les durées et seuils affichés viennent du serveur.",
                    "Server-graded simulation, not an official exam or pass guarantee. Displayed times and thresholds come from the server.",
                    "सर्वर द्वारा जाँचा अभ्यास, आधिकारिक परीक्षा या पास गारंटी नहीं। समय और सीमाएँ सर्वर से हैं।",
                    "服务器评分的模拟评估，并非正式考试或通过保证。时长和阈值来自服务器。",
                    "서버에서 채점하는 모의 평가이며 공식 시험이나 합격 보장이 아닙니다. 시간과 기준은 서버에서 제공합니다.",
                    "Simulación corregida por el servidor, no examen oficial ni garantía. Tiempos y umbrales del servidor.",
                    "Simulazione valutata dal server, non esame ufficiale né garanzia. Tempi e soglie dal server.",
                    "Serverbewertete Simulation, keine offizielle Prüfung oder Bestehensgarantie. Zeiten und Schwellen stammen vom Server.",
                ]
            case .generateExam:
                row = [
                    "Commencer la simulation", "Start exam simulation", "परीक्षा अभ्यास शुरू करें", "开始模拟考试",
                    "모의 시험 시작", "Iniciar simulación", "Avvia simulazione",
                    "Prüfungssimulation starten",
                ]
            case .emptyExam:
                row = [
                    "Aucune question de simulation disponible pour cet objectif.",
                    "No assessment questions are available for this goal.",
                    "इस लक्ष्य के लिए कोई मूल्यांकन प्रश्न उपलब्ध नहीं है।", "此目标暂无模拟评估题目。",
                    "이 목표에 사용할 수 있는 평가 문제가 없습니다.",
                    "No hay preguntas de simulación disponibles para este objetivo.",
                    "Nessuna domanda di simulazione disponibile per questo obiettivo.",
                    "Für dieses Ziel sind keine Simulationsfragen verfügbar.",
                ]
            case .submitExam:
                row = [
                    "Envoyer pour évaluation", "Submit assessment", "मूल्यांकन जमा करें", "提交评估", "평가 제출",
                    "Enviar evaluación", "Invia valutazione", "Bewertung einreichen",
                ]
            case .discardExam:
                row = [
                    "Supprimer la copie locale", "Discard local assessment", "स्थानीय मूल्यांकन हटाएँ",
                    "删除本地评估", "기기 내 평가 삭제", "Descartar evaluación local",
                    "Elimina valutazione locale", "Lokale Bewertung verwerfen",
                ]
            case .discardExamHint:
                row = [
                    "Cette action supprime seulement la copie de cet appareil. Une tentative déjà envoyée n’est pas annulée sur le serveur.",
                    "This removes only this device’s copy. An attempt already sent is not cancelled on the server.",
                    "यह केवल इस डिवाइस की प्रति हटाता है। भेजा प्रयास सर्वर पर रद्द नहीं होता।",
                    "仅删除此设备上的副本，已发送的答题记录不会在服务器上撤销。", "이 기기의 사본만 삭제합니다. 이미 전송한 시도는 서버에서 취소되지 않습니다.",
                    "Solo elimina la copia de este dispositivo. Un intento enviado no se cancela en el servidor.",
                    "Elimina solo la copia del dispositivo. Un tentativo inviato non viene annullato sul server.",
                    "Entfernt nur die Kopie auf diesem Gerät. Ein bereits gesendeter Versuch wird serverseitig nicht storniert.",
                ]
            case .unsupportedExam:
                row = [
                    "Cette simulation contient un type de question non pris en charge. Aucune réponse n’a été envoyée.",
                    "This assessment contains an unsupported question type. No answer was sent.",
                    "इस मूल्यांकन में असमर्थित प्रश्न प्रकार है। कोई उत्तर नहीं भेजा गया।", "此评估含不支持的题型，未发送答案。",
                    "지원하지 않는 문제 유형이 포함되어 있습니다. 답변은 전송되지 않았습니다.",
                    "La evaluación contiene un tipo no compatible. No se envió ninguna respuesta.",
                    "La valutazione contiene domande non supportate. Nessuna risposta inviata.",
                    "Diese Bewertung enthält einen nicht unterstützten Fragetyp. Keine Antwort wurde gesendet.",
                ]
            case .score:
                row = [
                    "Score", "Score", "स्कोर", "得分", "점수", "Puntuación",
                    "Punteggio", "Punktzahl",
                ]
            case .correctCount:
                row = [
                    "Réponses correctes / total", "Correct answers / total", "सही उत्तर / कुल",
                    "正确答案 / 总数", "정답 / 전체", "Respuestas correctas / total",
                    "Risposte corrette / totale", "Richtige Antworten / Gesamtzahl",
                ]
            case .timeRemaining:
                row = [
                    "Temps restant indicatif", "Indicative time remaining", "अनुमानित शेष समय",
                    "参考剩余时间", "참고 남은 시간", "Tiempo restante orientativo",
                    "Tempo rimanente indicativo", "Ungefähre verbleibende Zeit",
                ]
            case .notificationScope:
                row = [
                    "Préférences et plan du serveur uniquement. Aucun abonnement push ni autorisation iOS n’est créé ici. Enregistrer envoie vos choix au serveur.",
                    "Server preferences and plan only. No push subscription or iOS permission is created here. Save sends your choices to the server.",
                    "केवल सर्वर पसंद और योजना। यहाँ push सदस्यता या iOS अनुमति नहीं बनती। सहेजना विकल्प सर्वर को भेजता है।",
                    "仅服务器偏好与计划，不在此创建推送订阅或iOS权限。保存会将选择发送到服务器。",
                    "서버 설정과 계획만 제공합니다. 여기서는 푸시 구독이나 iOS 권한을 만들지 않습니다. 저장하면 선택 사항을 서버로 보냅니다.",
                    "Solo preferencias y plan del servidor. No crea suscripción push ni permiso iOS. Guardar envía tus opciones al servidor.",
                    "Solo preferenze e piano del server. Non crea abbonamenti push né permessi iOS. Salvare invia le scelte al server.",
                    "Nur Servereinstellungen und -plan. Kein Push-Abonnement oder iOS-Recht wird erstellt. Speichern sendet deine Auswahl an den Server.",
                ]
            case .utcOffset:
                row = [
                    "Décalage UTC en minutes", "UTC offset in minutes", "UTC अंतर मिनटों में", "UTC偏移分钟数",
                    "UTC 오프셋(분)", "Desfase UTC en minutos", "Scarto UTC in minuti",
                    "UTC-Abweichung in Minuten",
                ]
            case .quietStart:
                row = [
                    "Début du silence", "Quiet hours start", "शांत समय शुरू", "勿扰开始", "방해 금지 시작",
                    "Inicio del silencio", "Inizio ore silenziose", "Beginn der Ruhezeit",
                ]
            case .quietEnd:
                row = [
                    "Fin du silence", "Quiet hours end", "शांत समय समाप्त", "勿扰结束", "방해 금지 종료",
                    "Fin del silencio", "Fine ore silenziose", "Ende der Ruhezeit",
                ]
            case .pendingExam:
                row = [
                    "Envoi non confirmé : réessayer conserve la même tentative et les mêmes réponses.",
                    "Submission unconfirmed: retry keeps the same attempt and answers.",
                    "जमा करने की पुष्टि नहीं: दोबारा प्रयास में वही प्रयास और उत्तर रहेंगे।", "提交未确认：重试将保持相同答题记录和答案。",
                    "제출이 확인되지 않았습니다. 재시도해도 같은 시도와 답변을 유지합니다.",
                    "Envío sin confirmar: reintentar conserva el intento y las respuestas.",
                    "Invio non confermato: riprovare mantiene lo stesso tentativo e le risposte.",
                    "Einreichung unbestätigt: Wiederholen behält denselben Versuch und dieselben Antworten.",
                ]
            }
            let index: Int
            switch language {
            case .french: index = 0
            case .english: index = 1
            case .hindi: index = 2
            case .chineseSimplified: index = 3
            case .korean: index = 4
            case .spanish: index = 5
            case .italian: index = 6
            case .german: index = 7
            }
            precondition(row.count == 8)
            return row[index]
        }
    }

#endif

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    struct NativeContentLanguageBadges: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        let languages: [String]

        var body: some View {
            ForEach(NativeDeclaredContentLanguage.badges(languages), id: \.self) { language in
                Label(
                    language == "FR" ? copy[.contentLanguageFR] : copy[.contentLanguageEN],
                    systemImage: "textformat"
                )
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(NativePrism.surface, in: Capsule(style: .continuous))
                .accessibilityLabel("\(copy.native(.contentLanguage)) · \(language)")
            }
        }
    }

    private struct NativeStudyPlanView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.dismiss) private var dismiss
        @Bindable var model: NativeModel
        let ownerID: String
        let trackID: String
        @State private var targetDate = Date()
        @State private var hasTargetDate = false
        @State private var level: CertigoStudyPlanPreference.InitialLevel = .beginner
        @State private var minutes = 10
        @State private var issue = false

        var body: some View {
            NavigationStack {
                Form {
                    Section(copy.native(.studyPlan)) {
                        Toggle(copy.native(.targetDate), isOn: $hasTargetDate)
                        if hasTargetDate {
                            DatePicker(
                                copy.native(.targetDate), selection: $targetDate,
                                displayedComponents: .date)
                        }
                        Picker(copy.native(.initialLevel), selection: $level) {
                            Text(copy.native(.beginner))
                                .tag(CertigoStudyPlanPreference.InitialLevel.beginner)
                            Text(copy.native(.intermediate))
                                .tag(CertigoStudyPlanPreference.InitialLevel.intermediate)
                            Text(copy.native(.advanced))
                                .tag(CertigoStudyPlanPreference.InitialLevel.advanced)
                        }
                        Stepper(
                            "\(copy.native(.duration)) · \(copy.minutes(minutes))",
                            value: $minutes, in: 1...1440, step: 1)
                        Text(copy.native(.localPlanHint)).foregroundStyle(.secondary)
                    }
                    if issue || model.studyPlanError {
                        Label(copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
                    }
                }
                .navigationTitle(copy.native(.studyPlan))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(copy[.cancel]) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(copy.native(.save)) {
                            do {
                                let plan = try CertigoStudyPlanPreference(
                                    targetExamDate: hasTargetDate ? targetDate : nil,
                                    initialLevel: level, dailyMinutesGoal: minutes)
                                model.saveStudyPlan(plan, ownerID: ownerID, trackID: trackID)
                                if !model.studyPlanError { dismiss() }
                            } catch { issue = true }
                        }
                        .disabled(
                            model.busy || model.profile?.id != ownerID
                                || model.profile?.activeTrackId != trackID)
                    }
                }
                .onAppear {
                    model.loadStudyPlan()
                    if let plan = model.studyPlan {
                        targetDate = plan.targetExamDate ?? Date()
                        hasTargetDate = plan.targetExamDate != nil
                        level = plan.initialLevel
                        minutes = plan.dailyMinutesGoal
                    }
                }
            }
        }
    }

    private struct NativeMockExamView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Bindable var model: NativeModel
        @State private var confirmDiscard = false

        var body: some View {
            NativeReadingPage {
                NativeEntryHeading(
                    title: copy.native(.finalAssessment),
                    message: copy.native(.assessmentDisclaimer))
                if let snapshot = model.examSnapshot {
                    Text(snapshot.exam.trackTitle).font(.title2.bold())
                    if snapshot.exam.items.isEmpty {
                        Text(copy.native(.emptyExam))
                    } else if let result = snapshot.result {
                        NativeReadingSection(
                            title: result.passed
                                ? copy.native(.assessmentPassed) : copy.native(.assessmentReview)
                        ) {
                            Label(
                                snapshot.exam.trackCode,
                                systemImage: result.passed ? "trophy" : "book")
                            LabeledContent(copy.native(.score), value: "\(result.pct) %")
                            LabeledContent(
                                copy.native(.correctCount),
                                value: "\(result.correct) / \(result.total)")
                            Text("\(result.scaledScore) / 1000 · \(result.passingScore)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            ForEach(result.domains, id: \.domainId) { domain in
                                LabeledContent(
                                    domain.name,
                                    value: "\(domain.correct) / \(domain.total) · \(domain.pct) %")
                            }
                            if let strongest = result.domains.max(by: { $0.pct < $1.pct }) {
                                LabeledContent(copy.native(.strongest), value: strongest.name)
                            }
                            Text(copy.native(.assessmentReview)).font(.headline)
                            Text(result.weakConcepts.joined(separator: " · "))
                            LabeledContent(
                                copy.native(.confirmedXP),
                                value: "\(result.rewards.xpEarned)")
                        }
                        ForEach(snapshot.exam.items, id: \.itemId) { item in
                            if let feedback = result.results.first(where: {
                                $0.itemId == item.itemId
                            }) {
                                NativeReadingCard {
                                    Text(.init(item.stem)).font(.headline)
                                    Text(.init(feedback.explanation)).textSelection(.enabled)
                                    LabeledContent(
                                        copy.native(.masteryChange),
                                        value: feedback.masteryDelta.formatted())
                                }
                            }
                        }
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = max(
                                0,
                                snapshot.exam.timeLimitSeconds
                                    - Int(context.date.timeIntervalSince(snapshot.startedAt)))
                            LabeledContent(
                                copy.native(.timeRemaining),
                                value: "\(remaining / 60):\(String(format: "%02d", remaining % 60))"
                            )
                        }
                        if snapshot.submission != nil {
                            Text(copy.native(.pendingExam)).foregroundStyle(.secondary)
                        }
                        ForEach(snapshot.exam.items, id: \.itemId) { item in
                            NativeReadingSection(title: copy.native(.multipleChoice)) {
                                Text(.init(item.stem)).font(.headline)
                                ForEach(item.options) { option in
                                    Button {
                                        model.selectExamOption(
                                            itemID: item.itemId, optionID: option.id)
                                    } label: {
                                        Label(
                                            option.label,
                                            systemImage: snapshot.selections[item.itemId]
                                                == option.id
                                                ? "checkmark.circle.fill" : "circle"
                                        )
                                        .frame(
                                            maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    }
                                    .buttonStyle(NativeChoiceButtonStyle())
                                    .disabled(snapshot.submission != nil || model.examBusy)
                                    .accessibilityAddTraits(
                                        snapshot.selections[item.itemId] == option.id
                                            ? .isSelected : [])
                                }
                            }
                        }
                        NativePrimaryButton(
                            title: snapshot.submission == nil
                                ? copy.native(.submitExam) : copy.retry,
                            symbol: "paperplane"
                        ) {
                            Task { await model.submitMockExam() }
                        }
                        .disabled(!model.canSubmitMockExam)
                    }
                } else if !model.examBusy {
                    NativePrimaryButton(
                        title: copy.native(.generateExam), symbol: "checkmark.seal"
                    ) {
                        Task { await model.generateMockExam() }
                    }
                    .disabled(model.busy || model.profile?.activeTrackId == nil || model.examError)
                }
                if model.examBusy { ProgressView(copy.loading) }
                if model.examError {
                    Label(
                        model.examUnsupported
                            ? copy.native(.unsupportedExam) : copy.native(.dataFailure),
                        systemImage: "exclamationmark.triangle")
                }
                if model.examSnapshot != nil || model.examError {
                    Button(copy.native(.discardExam), role: .destructive) { confirmDiscard = true }
                        .frame(minHeight: 44)
                        .disabled(model.busy || model.examBusy)
                }
            }
            .navigationTitle(copy.native(.finalAssessment))
            .task { model.restoreMockExam() }
            .confirmationDialog(copy.native(.discardExam), isPresented: $confirmDiscard) {
                Button(copy.native(.discardExam), role: .destructive) { model.discardMockExam() }
            } message: {
                Text(copy.native(.discardExamHint))
            }
        }
    }

    private struct NativeNotificationPreferencesView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Bindable var model: NativeModel
        let ownerID: String
        @State private var enabled: Bool
        @State private var offset: Int
        @State private var quietStart: Int
        @State private var quietEnd: Int
        @State private var preferredHour: Int
        @State private var maxPerDay: Int
        @State private var streak: Bool
        @State private var quests: Bool
        @State private var leagues: Bool

        init(model: NativeModel, settings: NotificationSettings, ownerID: String) {
            self.model = model
            self.ownerID = ownerID
            _enabled = State(initialValue: settings.enabled)
            _offset = State(initialValue: settings.utcOffsetMinutes)
            _quietStart = State(initialValue: settings.quietHoursStart)
            _quietEnd = State(initialValue: settings.quietHoursEnd)
            _preferredHour = State(initialValue: settings.preferredHour)
            _maxPerDay = State(initialValue: settings.maxPerDay)
            _streak = State(initialValue: settings.streakAlerts)
            _quests = State(initialValue: settings.questAlerts)
            _leagues = State(initialValue: settings.leagueAlerts)
        }

        var body: some View {
            Section(copy[.notifications]) {
                Toggle(copy[.notificationsEnabled], isOn: $enabled)
                Stepper(
                    "\(copy.native(.utcOffset)) · \(offset)", value: $offset, in: -840...840,
                    step: 15)
                Stepper(
                    "\(copy.native(.quietStart)) · \(quietStart):00", value: $quietStart, in: 0...23
                )
                Stepper("\(copy.native(.quietEnd)) · \(quietEnd):00", value: $quietEnd, in: 0...23)
                Stepper(
                    "\(copy[.preferredHour]) · \(preferredHour):00", value: $preferredHour,
                    in: 0...23)
                Stepper("\(copy[.maxPerDay]) · \(maxPerDay)", value: $maxPerDay, in: 0...10)
                Toggle(copy[.streakAlerts], isOn: $streak)
                Toggle(copy[.questAlerts], isOn: $quests)
                Toggle(copy[.leagueAlerts], isOn: $leagues)
                Text(copy.native(.notificationScope)).font(.caption).foregroundStyle(.secondary)
                Button(copy.native(.save)) {
                    let settings = NotificationSettings(
                        enabled: enabled, utcOffsetMinutes: offset, quietHoursStart: quietStart,
                        quietHoursEnd: quietEnd, preferredHour: preferredHour, maxPerDay: maxPerDay,
                        streakAlerts: streak, questAlerts: quests, leagueAlerts: leagues)
                    Task { await model.saveNotificationSettings(settings, ownerID: ownerID) }
                }
                .frame(minHeight: 44)
                .disabled(model.busy || model.insightsLoading || model.profile?.id != ownerID)
            }
            .onChange(of: model.notificationSettings) { _, settings in
                guard let settings else { return }
                enabled = settings.enabled
                offset = settings.utcOffsetMinutes
                quietStart = settings.quietHoursStart
                quietEnd = settings.quietHoursEnd
                preferredHour = settings.preferredHour
                maxPerDay = settings.maxPerDay
                streak = settings.streakAlerts
                quests = settings.questAlerts
                leagues = settings.leagueAlerts
            }
        }
    }

    @main
    struct CertigoNativeApp: App {
        var body: some Scene {
            WindowGroup {
                NativeLanguageRoot()
            }
        }
    }

    private struct NativeLanguagePreferenceKey: EnvironmentKey {
        static let defaultValue: Binding<AppLanguagePreference> = .constant(.system)
    }

    private struct NativeInterfaceCopyKey: EnvironmentKey {
        static let defaultValue = AppInterfaceCopy(language: .english)
    }

    extension EnvironmentValues {
        var nativeLanguagePreference: Binding<AppLanguagePreference> {
            get { self[NativeLanguagePreferenceKey.self] }
            set { self[NativeLanguagePreferenceKey.self] = newValue }
        }

        var nativeInterfaceCopy: AppInterfaceCopy {
            get { self[NativeInterfaceCopyKey.self] }
            set { self[NativeInterfaceCopyKey.self] = newValue }
        }
    }

    private struct NativeLanguageRoot: View {
        @Environment(\.scenePhase) private var scenePhase
        @State private var preference = AppLanguagePreference.load(from: .standard)
        @State private var preferredLanguages = Locale.preferredLanguages

        private var effectiveLanguage: AppLanguage {
            preference.effectiveLanguage(fromPreferredLanguages: preferredLanguages)
        }

        var body: some View {
            NativeEntry()
                .tint(NativePrism.tint)
                .environment(\.locale, effectiveLanguage.locale)
                .environment(\.nativeInterfaceCopy, AppInterfaceCopy(language: effectiveLanguage))
                .environment(
                    \.nativeLanguagePreference,
                    Binding(
                        get: { preference },
                        set: {
                            $0.save(to: .standard)
                            preference = $0
                        })
                )
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        preferredLanguages = Locale.preferredLanguages
                        preference = AppLanguagePreference.load(from: .standard)
                    }
                }
        }
    }

    struct NativeAppLanguagePicker: View {
        @Environment(\.nativeLanguagePreference) private var preference
        @Environment(\.nativeInterfaceCopy) private var copy

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Picker(
                    copy.appLanguage,
                    selection: Binding(
                        get: { preference.wrappedValue.rawValue },
                        set: { raw in
                            guard let value = AppLanguagePreference(rawValue: raw) else { return }
                            preference.wrappedValue = value
                        })
                ) {
                    Text(copy.systemDefault).tag(AppLanguagePreference.system.rawValue)
                    ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                        Text(
                            "\(language.nativeDisplayName) · "
                                + language.localizedDisplayName(in: copy.language)
                        )
                        .tag(AppLanguagePreference.explicit(language).rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .accessibilityIdentifier("app-interface-language")
                Text(copy.contentLanguageNote)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("app-content-language-note")
            }
        }
    }

    // THESIS: A decision workshop extends the objective-first demo; no invented course or metrics.
    // OWN-WORLD: Prism violet, semantic surfaces, SF text, native navigation and glass controls.
    // STORY: Read a situation, decide, wait, understand; every demo result is explicitly synthetic.
    // FIRST VIEWPORT: One colored objective plane, one resume action, then quiet supporting rows.
    // FORM: Reviewable extension of approved A, not a new identity; bounded iPad reading width.
    enum NativePrism {
        // Prism spectrumInk / spectrumGlow plus info; glow is never a solid reading fill.
        private static let ink: [UInt32] = [
            0x3B35F2, 0x901BAE, 0xA91A66, 0x924A13, 0x177331, 0x176C7A, 0x1562AA,
        ]
        private static let glow: [UInt32] = [
            0x8097F8, 0xD764F8, 0xF95DA5, 0xEC7B26, 0x2DBC55, 0x2CB0C7, 0x52A2F8,
        ]
        static let canvas = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let edge = Color(
            uiColor: UIColor { traits in
                traits.accessibilityContrast == .high ? .label : .separator
            })
        static let tint = accent(band: 0)
        static let objectiveFill = Color(uiColor: color(ink[0]))
        static let confirmed = accent(band: 4)
        static let pending = accent(band: 3)

        static func accent(for code: String) -> Color {
            accent(band: NativeTrackAppearance.band(for: code))
        }

        private static func accent(band: Int) -> Color {
            Color(
                uiColor: UIColor { traits in
                    let dark = traits.userInterfaceStyle == .dark
                    let base = color(dark ? glow[band] : ink[band])
                    guard traits.accessibilityContrast == .high else { return base }
                    var red: CGFloat = 0
                    var green: CGFloat = 0
                    var blue: CGFloat = 0
                    var alpha: CGFloat = 0
                    base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    let target: CGFloat = dark ? 1 : 0
                    return UIColor(
                        red: red + (target - red) * 0.25,
                        green: green + (target - green) * 0.25,
                        blue: blue + (target - blue) * 0.25, alpha: 1)
                })
        }

        private static func color(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }

    private struct NativePracticeBadge: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        let available: Bool

        var body: some View {
            Label(
                copy[available ? .practiceAvailable : .practiceUnavailable],
                systemImage: available ? "book" : "book.closed"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(NativePrism.surface, in: Capsule(style: .continuous))
            .accessibilityIdentifier("catalog-practice-availability")
        }
    }

    struct NativeReadingPage<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { content }
                    .padding(20)
                    .frame(maxWidth: 700, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .background(NativePrism.canvas)
        }
    }

    private struct NativeCatalogSearch: ViewModifier {
        @Environment(\.nativeInterfaceCopy) private var copy
        let enabled: Bool
        @Binding var query: String

        @ViewBuilder func body(content: Content) -> some View {
            if enabled {
                content.searchable(text: $query, prompt: copy[.searchPlaceholder])
            } else {
                content
            }
        }
    }

    struct NativeReadingSection<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct NativeReadingCard<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    NativePrism.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(NativePrism.edge, lineWidth: 1)
                }
        }
    }

    struct NativePrimaryButton: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        let title: String
        let symbol: String
        let action: () -> Void

        var body: some View {
            Group {
                if #available(iOS 26.0, *), !reduceTransparency {
                    button.buttonStyle(.glassProminent)
                } else {
                    button.buttonStyle(.borderedProminent)
                }
            }
            .tint(NativePrism.objectiveFill)
        }

        private var button: some View {
            Button(action: action) {
                Label(title, systemImage: symbol)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .multilineTextAlignment(.center)
            }
            .controlSize(.large)
        }
    }

    struct NativeChoiceButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                .padding(16)
                .background(
                    configuration.isPressed
                        ? Color(uiColor: .tertiarySystemFill) : NativePrism.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    struct NativeEntryHeading: View {
        let title: String
        let message: String
        var prominent = false

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "book.pages")
                    .font(.title2).symbolRenderingMode(.monochrome).accessibilityHidden(true)
                Text(title).font(prominent ? .largeTitle.bold() : .title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(message).font(.body)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background(
                NativePrism.objectiveFill,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private struct NativeEntry: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @State private var showDemo = false
        #if DEBUG
            @State private var showDeveloper = false
        #endif
        @State private var pendingLessonLink: EditorialPilotLessonLink?
        @State private var invalidLessonLink = false

        var body: some View {
            #if CERTIGO_PRODUCTION_DISTRIBUTION
                NativeProductionEntry(pendingLessonLink: $pendingLessonLink)
            #else
                developmentEntry
            #endif
        }

        private var developmentEntry: some View {
            NavigationStack {
                NativeReadingPage {
                    NativeEntryHeading(
                        title: copy.native(.welcomeTitle),
                        message: copy.native(.welcomeHint), prominent: true)
                    NativeAppLanguagePicker()
                    NativeReadingSection(title: copy.native(.tryLearning)) {
                        NativePrimaryButton(title: copy.exploreDemo, symbol: "play.circle") {
                            showDemo = true
                        }
                        .accessibilityIdentifier("open-native-demo")
                        Text(
                            copy.native(.fictionalBoundary)
                        )
                        .foregroundStyle(.secondary)
                    }
                    #if DEBUG
                        if let pendingLessonLink {
                            NativeReadingSection(title: copy.native(.sharedLesson)) {
                                Text(
                                    "\(copy.native(.editorialPilot)) · \(pendingLessonLink.lessonID)"
                                )
                                Button(copy.native(.openLinkedLesson), systemImage: "book") {
                                    showDeveloper = true
                                }
                                .accessibilityIdentifier("continue-to-linked-lesson")
                            }
                        }
                        NativeReadingSection(title: copy.native(.development)) {
                            Button(
                                copy.native(.openConnector),
                                systemImage: "wrench.and.screwdriver"
                            ) {
                                showDeveloper = true
                            }
                            .frame(minHeight: 44)
                            Text(
                                copy.native(.testOnly)
                            )
                            .foregroundStyle(.secondary)
                        }
                    #endif
                }
                .navigationTitle("Certigo")
                .fullScreenCover(isPresented: $showDemo) { NativeDemoRoot() }
                #if DEBUG
                    .sheet(isPresented: $showDeveloper) {
                        NativeDeveloperConnector(pendingLessonLink: $pendingLessonLink)
                        .interactiveDismissDisabled()
                    }
                #endif
            }
            .onOpenURL(perform: handleIncomingURL)
            .alert(copy.native(.lessonLinkUnavailable), isPresented: $invalidLessonLink) {
                Button(copy[.done], role: .cancel) { invalidLessonLink = false }
            } message: {
                Text(copy.native(.lessonLinkInvalid))
            }
        }

        private func handleIncomingURL(_ url: URL) {
            guard url.scheme == "https", url.host == EditorialPilotLessonLink.host else { return }
            guard let link = EditorialPilotLessonLink(url: url) else {
                pendingLessonLink = nil
                invalidLessonLink = true
                return
            }
            pendingLessonLink = link
        }
    }

    #if CERTIGO_PRODUCTION_DISTRIBUTION
        @MainActor
        private struct NativeProductionEntry: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            @Binding private var pendingLessonLink: EditorialPilotLessonLink?
            @State private var model: NativeModel
            @State private var provider: MSALAuthenticationProvider?
            @State private var configurationIssue: NativePresentationMessage?
            @State private var showDemo = false

            init(pendingLessonLink: Binding<EditorialPilotLessonLink?>) {
                self._pendingLessonLink = pendingLessonLink
                do {
                    let configured = try CIAMConfigurationEnvironment.configuredProductionProvider(
                        infoDictionary: Bundle.main.infoDictionary ?? [:],
                        bundleIdentifier: Bundle.main.bundleIdentifier,
                        isDevelopmentBuild: false
                    ) { configuration in
                        try MSALAuthenticationProvider(
                            configuration: configuration,
                            presentation: Self.authenticationPresentationController)
                    }
                    _model = State(
                        initialValue: NativeModel(
                            authentication: (configured.provider, configured.configuration)))
                    _provider = State(initialValue: configured.provider)
                    _configurationIssue = State(initialValue: nil)
                } catch {
                    _model = State(initialValue: NativeModel())
                    _provider = State(initialValue: nil)
                    _configurationIssue = State(initialValue: Self.safeMessage(for: error))
                }
            }

            var body: some View {
                Group {
                    if let configurationIssue {
                        VStack(spacing: 24) {
                            NativeAppLanguagePicker().padding(20)
                            ContentUnavailableView(
                                copy.native(.signInUnconfigured),
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text(configurationIssue.resolved(using: copy)))
                        }
                    } else if model.profile == nil && model.deletionStage == nil {
                        NavigationStack {
                            NativeReadingPage {
                                NativeEntryHeading(
                                    title: copy.native(.productionTitle),
                                    message:
                                        copy.native(.productionHint)
                                )
                                NativeAppLanguagePicker()
                                NativeReadingSection(title: copy.native(.continueLearning)) {
                                    Text(copy.signInWithMicrosoft)
                                    NativePrimaryButton(
                                        title: copy.signInWithMicrosoft,
                                        symbol: "person.crop.circle"
                                    ) {
                                        Task { await model.connect() }
                                    }
                                    .disabled(model.busy)
                                    if model.busy { ProgressView() }
                                    Divider()
                                    Button(copy.exploreDemo, systemImage: "play.circle") {
                                        showDemo = true
                                    }
                                    .frame(minHeight: 44)
                                    .disabled(model.busy)
                                    Text(copy.contentLanguageNote)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .navigationTitle("Certigo")
                            .fullScreenCover(isPresented: $showDemo) { NativeDemoRoot() }
                            .alert(
                                copy.native(.signInIncomplete),
                                isPresented: Binding(
                                    get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } }
                                )
                            ) {
                                Button(copy[.done], role: .cancel) { model.errorMessage = nil }
                            } message: {
                                Text(model.errorMessage?.resolved(using: copy) ?? "")
                            }
                        }
                    } else {
                        NativeRoot(model: model, pendingLessonLink: $pendingLessonLink)
                    }
                }
                .onOpenURL { url in
                    _ = provider?.handleCallback(url, sourceApplication: nil)
                }
                .task {
                    if configurationIssue == nil {
                        _ = await model.restoreAccountDeletionIfNeeded()
                    }
                }
            }

            @MainActor
            private static func authenticationPresentationController() throws -> UIViewController {
                let windows = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                guard var controller = windows.first(where: \.isKeyWindow)?.rootViewController
                else {
                    throw CIAMAuthenticationFailure.configuration
                }
                while let presented = controller.presentedViewController {
                    controller = presented
                }
                return controller
            }

            private static func safeMessage(for error: Error) -> NativePresentationMessage {
                switch error {
                case CIAMConfigurationEnvironmentError.productionBuildRequired:
                    .copy(.configurationDistributionOnly)
                case CIAMConfigurationEnvironmentError.unsupportedProductionBundle:
                    .copy(.configurationAppStoreBundle)
                case CIAMConfigurationEnvironmentError.missingValue(let key):
                    .configuration(name: key, production: true, missing: true)
                case CIAMConfigurationEnvironmentError.invalidValue(let key):
                    .configuration(name: key, production: true, missing: false)
                case CIAMConfigurationEnvironmentError.callbackNotDeclared:
                    .copy(.configurationDeclareProductionCallback)
                case CIAMConfigurationEnvironmentError.callbackCollision:
                    .copy(.configurationDuplicateProductionCallback)
                case CIAMConfigurationEnvironmentError.redirectDoesNotMatchBundle:
                    .copy(.configurationCallbackBundle)
                case is CIAMConfigurationEnvironmentError:
                    .copy(.configurationCorrectProduction)
                case is CIAMConfigurationError:
                    .copy(.configurationProductionValidation)
                default:
                    .copy(.configurationInitializationFailed)
                }
            }
        }
    #endif

    #if DEBUG
        @MainActor
        private struct NativeDeveloperConnector: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            @Environment(\.dismiss) private var dismiss
            @Binding private var pendingLessonLink: EditorialPilotLessonLink?
            @State private var model: NativeModel
            @State private var usesCIAM: Bool
            @State private var ciamProvider: MSALAuthenticationProvider?
            @State private var configurationIssue: NativePresentationMessage?

            init(pendingLessonLink: Binding<EditorialPilotLessonLink?> = .constant(nil)) {
                self._pendingLessonLink = pendingLessonLink
                do {
                    let configured = try CIAMConfigurationEnvironment.configuredProvider(
                        environment: ProcessInfo.processInfo.environment,
                        bundleIdentifier: Bundle.main.bundleIdentifier,
                        infoDictionary: Bundle.main.infoDictionary ?? [:],
                        isDevelopmentBuild: true
                    ) { configuration in
                        try MSALAuthenticationProvider(
                            configuration: configuration,
                            presentation: Self.authenticationPresentationController
                        )
                    }
                    if let configured {
                        _model = State(
                            initialValue: NativeModel(
                                authentication: (configured.provider, configured.configuration)))
                        _usesCIAM = State(initialValue: true)
                        _ciamProvider = State(initialValue: configured.provider)
                    } else {
                        _model = State(initialValue: NativeModel())
                        _usesCIAM = State(initialValue: false)
                        _ciamProvider = State(initialValue: nil)
                    }
                    _configurationIssue = State(initialValue: nil)
                } catch {
                    _model = State(initialValue: NativeModel())
                    _usesCIAM = State(initialValue: true)
                    _ciamProvider = State(initialValue: nil)
                    _configurationIssue = State(
                        initialValue: Self.safeConfigurationMessage(for: error))
                }
            }

            var body: some View {
                Group {
                    if let configurationIssue {
                        ContentUnavailableView(
                            copy.native(.ciamUnavailable),
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text(configurationIssue.resolved(using: copy))
                        )
                        .accessibilityIdentifier("ciam-configuration-error")
                    } else if usesCIAM && model.profile == nil {
                        ciamSignIn
                    } else {
                        NativeRoot(model: model, pendingLessonLink: $pendingLessonLink)
                    }
                }
                .onOpenURL { url in
                    _ = ciamProvider?.handleCallback(url, sourceApplication: nil)
                }
                .safeAreaInset(edge: .top) {
                    HStack {
                        Text(copy.native(.developerConnector)).font(.subheadline)
                        Spacer()
                        Button(copy.native(.close)) { dismiss() }
                    }
                    .padding()
                    .background(.background)
                }
            }

            private var ciamSignIn: some View {
                NavigationStack {
                    NativeReadingPage {
                        NativeEntryHeading(
                            title: copy.native(.testLearning),
                            message: copy.native(.ciamTestScope))
                        NativeReadingSection(title: copy.native(.ciamTestSignIn)) {
                            Text(copy.native(.ciamExplicit))
                            NativePrimaryButton(
                                title: copy.native(.ciamSignIn), symbol: "person.crop.circle"
                            ) {
                                Task { await model.connect() }
                            }
                            .disabled(model.busy)
                        }
                    }
                    .navigationTitle("Certigo")
                    .alert(
                        copy.native(.ciamIncomplete),
                        isPresented: Binding(
                            get: { model.errorMessage != nil },
                            set: { if !$0 { model.errorMessage = nil } }
                        )
                    ) {
                        Button(copy[.done], role: .cancel) { model.errorMessage = nil }
                    } message: {
                        Text(model.errorMessage?.resolved(using: copy) ?? "")
                    }
                }
            }

            @MainActor
            private static func authenticationPresentationController() throws -> UIViewController {
                let windows = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                guard var controller = windows.first(where: \.isKeyWindow)?.rootViewController
                else {
                    throw CIAMAuthenticationFailure.configuration
                }
                while let presented = controller.presentedViewController {
                    controller = presented
                }
                return controller
            }

            private static func safeConfigurationMessage(for error: Error)
                -> NativePresentationMessage
            {
                if let error = error as? CIAMConfigurationEnvironmentError {
                    switch error {
                    case .invalidOptIn: return .copy(.configurationOptIn)
                    case .missingValue(let name):
                        return .configuration(name: name, production: false, missing: true)
                    case .invalidValue(let name):
                        return .configuration(name: name, production: false, missing: false)
                    case .releaseOptInNotAllowed: return .copy(.configurationDevelopmentOnly)
                    case .productionBuildRequired: return .copy(.configurationDistributionOnly)
                    case .unsupportedProductionBundle: return .copy(.configurationAppStoreBundle)
                    case .missingBundleIdentifier: return .copy(.configurationMissingBundle)
                    case .callbackNotDeclared: return .copy(.configurationCallbackUnregistered)
                    case .callbackCollision: return .copy(.configurationCallbackDuplicate)
                    case .redirectDoesNotMatchBundle: return .copy(.configurationDerivedRedirect)
                    }
                }
                if let error = error as? CIAMConfigurationError {
                    switch error {
                    case .invalidIdentity:
                        return
                            .copy(.configurationIdentity)
                    case .invalidAuthority:
                        return .copy(.configurationAuthority)
                    case .issuerMismatch:
                        return .copy(.configurationIssuer)
                    case .invalidAPIScope:
                        return
                            .copy(.configurationScope)
                    case .invalidAPIURL:
                        return .copy(.configurationAPIURL)
                    case .invalidRedirect, .redirectNotRegistered:
                        return .copy(.configurationRedirect)
                    case .callbackNotDeclared:
                        return
                            .copy(.configurationCallbackDeclaration)
                    case .callbackCollision:
                        return .copy(.configurationCallbackCollision)
                    }
                }
                return
                    .copy(.configurationReview)
            }
        }
    #endif

    private enum DemoCatalogScenario: String, CaseIterable {
        case ready = "Available"
        case loading = "Loading"
        case empty = "Empty"
        case error = "Error"
    }

    private enum DemoSocialSection: String, CaseIterable {
        case friends = "Friends"
        case teams = "Teams"
    }

    private struct NativeDemoRoot: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.dismiss) private var dismiss
        @AppStorage("certigo.native-design-demo.v1") private var savedState = ""
        @State private var flow = NativeDemoFlow()
        @State private var tab = NativeDemoTab.catalog
        @State private var learnSection = NativeDemoLearnSection.explore
        @State private var objectivePath: [NativeDemoRoute] = []
        @State private var catalogPath: [NativeDemoRoute] = []
        @State private var scenario = DemoCatalogScenario.ready
        @State private var offline = false
        @State private var issue: AppInterfaceCopy.NativeLabel?
        @State private var showScenarios = false
        @State private var showReset = false
        @State private var persistence = NativeDemoPersistence.awaitingRestoration
        @State private var socialSection = DemoSocialSection.friends

        var body: some View {
            TabView(selection: mainTabSelection) {
                Group {
                    if learnSection == .myLearning {
                        NavigationStack(path: $objectivePath) {
                            objective.navigationDestination(for: NativeDemoRoute.self) { route in
                                destination(for: route)
                            }
                        }
                    } else {
                        NavigationStack(path: $catalogPath) {
                            catalog.navigationDestination(for: NativeDemoRoute.self) { route in
                                destination(for: route)
                            }
                        }
                    }
                }
                .tabItem { Label(copy.learn, systemImage: "book") }.tag(NativeDemoDestination.learn)
                NavigationStack {
                    unavailableService(
                        copy.coach, symbol: "bubble.left.and.bubble.right",
                        description:
                            copy.native(.demoCoachUnavailable)
                    )
                }
                .tabItem { Label(copy.coach, systemImage: "bubble.left.and.bubble.right") }
                .tag(NativeDemoDestination.coach)
                NavigationStack {
                    social
                }
                .tabItem { Label(copy.social, systemImage: "person.2") }.tag(
                    NativeDemoDestination.social)
                NavigationStack { followUp }
                    .tabItem { Label(copy.profile, systemImage: "person.crop.circle") }
                    .tag(NativeDemoDestination.profile)
            }
            .tint(NativePrism.tint)
            .sheet(isPresented: $showScenarios) {
                NavigationStack {
                    Form {
                        Section(copy.appLanguage) { NativeAppLanguagePicker() }
                        Section(copy.native(.demoCatalogStates)) {
                            Picker(copy.native(.demoCatalog), selection: $scenario) {
                                ForEach(DemoCatalogScenario.allCases, id: \.self) {
                                    Text(scenarioTitle($0)).tag($0)
                                }
                            }
                            Toggle(copy.native(.demoOfflineToggle), isOn: $offline)
                        }
                        Section {
                            Text(
                                copy.native(.demoSettingsScope)
                            )
                        }
                    }
                    .navigationTitle(copy.native(.demoSettings))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(copy[.done]) { showScenarios = false }
                        }
                    }
                }
            }
            .confirmationDialog(
                copy.native(.demoResetConfirmation), isPresented: $showReset
            ) {
                Button(copy.native(.demoReset), role: .destructive) {
                    flow = NativeDemoFlow()
                    objectivePath = []
                    catalogPath = []
                    tab = .catalog
                    learnSection = .explore
                    scenario = .ready
                    offline = false
                    persistence.reset(&savedState)
                }
            }
            .alert(copy.native(.demoRestorationUnavailable), isPresented: issuePresented) {
                Button(copy[.done], role: .cancel) { issue = nil }
            } message: {
                Text(issue.map { copy.native($0) } ?? "")
            }
            .task {
                guard persistence == .awaitingRestoration else { return }
                do {
                    if let snapshot = try persistence.restore(savedState) {
                        flow = snapshot.flow
                        let navigation = snapshot.navigation
                        tab = navigation.selectedTab
                        learnSection = navigation.learnSection
                        objectivePath = navigation.objectivePath
                        catalogPath = navigation.catalogPath
                    } else {
                        learnSection = flow.objective == nil ? .explore : .myLearning
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                } catch {
                    issue =
                        .demoRestoreFailure
                }
            }
            .onChange(of: flow) { _, value in
                persistDemoSnapshot(flow: value)
            }
            .onChange(of: tab) { _, _ in persistDemoSnapshot() }
            .onChange(of: learnSection) { _, _ in persistDemoSnapshot() }
            .onChange(of: objectivePath) { _, _ in persistDemoSnapshot() }
            .onChange(of: catalogPath) { _, _ in persistDemoSnapshot() }
        }

        private var mainTabSelection: Binding<NativeDemoDestination> {
            Binding(
                get: { tab.destination },
                set: { destination in
                    tab = NativeDemoTab.selecting(destination, learnSection: learnSection)
                })
        }

        private var learnSectionSelection: Binding<NativeDemoLearnSection> {
            Binding(
                get: { learnSection },
                set: { section in
                    learnSection = section
                    tab = NativeDemoTab.selecting(.learn, learnSection: section)
                })
        }

        private var learnSelector: some View {
            Picker(copy.learn, selection: learnSectionSelection) {
                Text(copy.myLearning).tag(NativeDemoLearnSection.myLearning)
                Text(copy.explore).tag(NativeDemoLearnSection.explore)
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("learn-section")
        }

        private func unavailableService(_ title: String, symbol: String, description: String)
            -> some View
        {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    ContentUnavailableView(
                        copy.native(.unavailable), systemImage: symbol,
                        description: Text(description))
                    Text(copy.native(.demoPreviewOnly))
                        .foregroundStyle(.secondary)
                    DemoPrimaryButton(title: copy.native(.demoReturnLearn), symbol: "book") {
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .navigationTitle(title)
            .toolbar { demoToolbar }
        }

        private var social: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    Picker(copy.social, selection: $socialSection) {
                        ForEach(DemoSocialSection.allCases, id: \.self) { section in
                            Text(section == .friends ? copy.friends : copy.teams).tag(section)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                    ContentUnavailableView(
                        copy.native(.unavailable),
                        systemImage: socialSection == .friends ? "person.2" : "person.3",
                        description: Text(
                            copy.native(.demoSocialUnavailable)
                        ))
                    DemoPrimaryButton(title: copy.native(.demoReturnLearn), symbol: "book") {
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .navigationTitle(copy.social)
            .toolbar { demoToolbar }
        }

        @ViewBuilder private func destination(for route: NativeDemoRoute) -> some View {
            switch route {
            case .preparation:
                preparation
            case .exercise:
                exercise
            case .goalDetail(let goal):
                goalDetail(goal)
            }
        }

        private func persistDemoSnapshot(flow currentFlow: NativeDemoFlow? = nil) {
            guard persistence == .ready else { return }
            do {
                let flowToPersist = currentFlow ?? flow
                let navigation = try NativeDemoNavigationState.make(
                    selectedTab: tab, objectivePath: objectivePath,
                    catalogPath: catalogPath, flow: flowToPersist, learnSection: learnSection)
                let snapshot = try NativeDemoSnapshot.make(
                    flow: flowToPersist, navigation: navigation)
                try persistence.save(snapshot, to: &savedState)
            } catch {
                issue =
                    .demoSaveFailure
            }
        }

        private var issuePresented: Binding<Bool> {
            Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })
        }

        private func resumeExercise() {
            do {
                let navigation = try NativeDemoNavigationState.make(
                    selectedTab: tab, objectivePath: objectivePath,
                    catalogPath: catalogPath, flow: flow
                ).resumingExercise(for: flow)
                objectivePath = navigation.objectivePath
                learnSection = .myLearning
                tab = navigation.selectedTab
            } catch {
                issue =
                    .demoReopenFailure
            }
        }

        private var objective: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    learnSelector
                    if let goal = flow.objective {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(goal.displayName(copy)).font(.largeTitle.bold())
                            Text(goal.displayTitle(copy)).font(.title2.weight(.semibold))
                            Text(flow.activitySummary(copy))
                                .font(.subheadline)
                            NavigationLink(value: flow.startRoute) {
                                Label(flow.startLabel(copy), systemImage: "arrow.right.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .tint(.white)
                            .accessibilityIdentifier("resume-demo")
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.white)
                        .background(
                            NativePrism.objectiveFill,
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        VStack(alignment: .leading, spacing: 12) {
                            Text(copy.native(.demoWorkshop)).font(.title2.bold())
                            Text(goal.practice.intent)
                            Text(
                                copy.native(.demoWorkshopHint)
                            )
                            .foregroundStyle(.secondary)
                            Label(
                                copy.native(.demoFictionalContent),
                                systemImage: "text.book.closed"
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Divider()
                        Button(copy.native(.demoSwitchGoal), systemImage: "square.grid.2x2") {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                        Button(
                            copy.native(.demoHistoryAction), systemImage: "clock.arrow.circlepath"
                        ) {
                            tab = .followUp
                        }
                        .frame(minHeight: 44)
                    } else {
                        ContentUnavailableView(
                            copy.native(.demoNextGoal),
                            systemImage: "scope",
                            description: Text(
                                copy.native(.demoExploreHint)
                            )
                        )
                        DemoPrimaryButton(title: copy[.chooseGoal], symbol: "arrow.right") {
                            learnSection = .explore
                            tab = .catalog
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(copy.learn)
            .toolbar { demoToolbar }
        }

        private var catalog: some View {
            List {
                Section {
                    demoNotice
                    learnSelector
                }
                switch scenario {
                case .ready:
                    if flow.objective == nil {
                        Section {
                            Text(
                                copy.native(.demoChooseHint)
                            )
                        }
                    }
                    Section(copy.native(.demoWorkshops)) {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            NavigationLink(value: NativeDemoRoute.goalDetail(goal)) {
                                HStack(spacing: 16) {
                                    Image(systemName: goal.symbol).font(.title2)
                                        .foregroundStyle(NativePrism.tint)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.displayName(copy)).font(.headline)
                                        Text(goal.displayTitle(copy)).foregroundStyle(.secondary)
                                        Text(goal.practice.intent).font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text(copy.native(.demoVolume))
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if flow.objective == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NativePrism.tint)
                                            .accessibilityLabel(copy.native(.demoSelectedGoal))
                                    }
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }
                case .loading:
                    Section {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(goal.displayTitle(copy)).font(.headline)
                                Text(copy.native(.demoSituationExplore)).font(.subheadline)
                            }
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                        }
                        Label("\(copy.loading) · \(copy[.demo])", systemImage: "hourglass")
                            .accessibilityIdentifier("demo-catalog-loading")
                        Button(copy.native(.demoFinishLoading)) { scenario = .ready }
                    }
                case .empty:
                    Section {
                        ContentUnavailableView(
                            copy.native(.demoNoGoals), systemImage: "books.vertical",
                            description: Text(copy.native(.demoEmptyHint))
                        )
                        Button(copy.native(.demoShowGoals)) { scenario = .ready }
                    }
                case .error:
                    Section {
                        ContentUnavailableView(
                            copy.native(.demoCatalogUnavailable),
                            systemImage: "wifi.exclamationmark",
                            description: Text(
                                copy.native(.demoPreservedHint)))
                        Button(copy.retry, systemImage: "arrow.clockwise") {
                            scenario = .ready
                        }
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.learn)
            .toolbar { demoToolbar }
        }

        private func goalDetail(_ goal: NativeDemoFlow.Objective) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    Text(goal.displayName(copy)).font(.largeTitle.bold()).foregroundStyle(
                        NativePrism.tint)
                    Text(goal.displayTitle(copy)).font(.title2.bold())
                    Text(
                        copy.native(.demoScenarioHint)
                    )
                    DemoReadingSection(
                        title: copy.native(.demoDecisionExplore), text: goal.practice.intent)
                    DemoReadingSection(
                        title: copy.native(.demoFictionalSituation), text: goal.practice.situation)
                    Label(copy.native(.demoNoGrade), systemImage: "text.bubble")
                    Label(copy.native(.demoLocalRestore), systemImage: "clock.arrow.circlepath")
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                DemoPrimaryButton(title: copy[.chooseGoal], symbol: "scope") {
                    flow.choose(goal)
                    learnSection = .myLearning
                    catalogPath = []
                    objectivePath = []
                    tab = .objective
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationTitle(copy.native(.goalOverview)).navigationBarTitleDisplayMode(.inline)
        }

        private var preparation: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(progress: NativeDemoPracticeProgress(current: .situation))
                        Text(practice.title).font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        DemoReadingSection(
                            title: copy.native(.demoSituation), text: practice.situation)
                        DemoReadingSection(title: copy.native(.demoTask), text: practice.intent)
                        Divider()
                        DemoReadingSection(
                            title: copy.native(.demoBeforeChoose),
                            text:
                                copy.native(.demoBoundaryHint)
                        )
                        DemoPrimaryButton(
                            title: copy.native(.demoOpenQuestion), symbol: "arrow.right"
                        ) {
                            objectivePath = [.exercise]
                        }
                        .accessibilityIdentifier("demo-open-question")
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle(copy.native(.demoPreparation)).navigationBarTitleDisplayMode(.inline)
            .toolbar { demoToolbar }
        }

        private var exercise: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(
                            progress: NativeDemoPracticeProgress(
                                current: flow.phase == .reviewed ? .explanation : .decision))
                        switch flow.phase {
                        case .answering:
                            Label(
                                flow.selection == nil
                                    ? copy.native(.demoChooseAnswer)
                                    : copy.native(.demoAnswerSelected),
                                systemImage: flow.selection == nil
                                    ? "circle" : "checkmark.circle.fill"
                            )
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                flow.selection == nil ? Color.secondary : NativePrism.tint
                            )
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-answer-state")
                            Text(practice.title).font(.title2.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(practice.situation).textSelection(.enabled)
                            Text(practice.question)
                                .font(.title3.weight(.semibold))
                                .accessibilityAddTraits(.isHeader)
                            VStack(spacing: 12) {
                                ForEach(Array(NativeDemoFlow.options.enumerated()), id: \.offset) {
                                    index, option in
                                    Button {
                                        flow.select(index)
                                    } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Image(
                                                systemName: flow.selection == index
                                                    ? "checkmark.circle.fill" : "circle")
                                            Text(option).multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }
                                        .frame(
                                            maxWidth: .infinity, minHeight: 44, alignment: .leading
                                        )
                                        .padding(12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(
                                        flow.selection == index ? NativePrism.tint : .primary
                                    )
                                    .background(
                                        Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                flow.selection == index
                                                    ? NativePrism.tint : Color(uiColor: .separator),
                                                lineWidth: flow.selection == index ? 2 : 1)
                                    }
                                    .accessibilityAddTraits(
                                        flow.selection == index ? .isSelected : []
                                    )
                                    .accessibilityLabel(option)
                                    .accessibilityValue(
                                        flow.selection == index
                                            ? copy.native(.selected) : copy.native(.notSelected)
                                    )
                                    .accessibilityIdentifier("demo-option-\(index)")
                                }
                            }
                            Text(copy.native(.demoEditableHint))
                                .font(.subheadline).foregroundStyle(.secondary)
                        case .pending:
                            Label {
                                Text("\(copy.pending) · \(copy[.demo])")
                            } icon: {
                                Image(systemName: "clock.fill").foregroundStyle(.orange)
                            }
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-pending-state")
                            Text(copy.native(.demoChoiceSaved))
                                .font(.headline)
                            selectedAnswer
                            Text(
                                copy.native(.demoNoVerdict)
                            )
                            if offline {
                                Label(
                                    "\(copy[.offline]) · \(copy[.demo])", systemImage: "wifi.slash")
                                Text(
                                    copy.native(.demoOfflinePending)
                                )
                                DemoPrimaryButton(
                                    title: copy.native(.demoDisableOffline),
                                    symbol: "wifi"
                                ) { offline = false }
                            } else {
                                Text(
                                    copy.native(.demoSimulateHint)
                                )
                                DemoPrimaryButton(
                                    title: copy.native(.demoSimulateExplanation),
                                    symbol: "text.bubble"
                                ) {
                                    flow.receiveMockExplanation(offline: offline)
                                }
                                .accessibilityIdentifier("demo-receive-mock")
                            }
                        case .reviewed:
                            Label(
                                copy.native(.demoExplanation),
                                systemImage: "text.bubble"
                            )
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-explanation-state")
                            selectedAnswer
                            DemoReadingSection(
                                title: copy.native(.demoConstraint), text: practice.constraint)
                            DemoReadingSection(
                                title: copy.native(.demoUnderstanding), text: practice.explanation)
                            DemoResponsibilities(rows: practice.responsibilities)
                            DemoTakeaway(text: practice.takeaway)
                            Text(
                                copy.native(.demoFixtureHint)
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: copy.progressAndHistory,
                                symbol: "arrow.right"
                            ) { tab = .followUp }
                            Button(
                                copy.native(.demoPracticeAgain),
                                systemImage: "arrow.counterclockwise"
                            ) {
                                flow.restartQuestion()
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if flow.practice != nil, flow.phase == .answering {
                    DemoPrimaryButton(
                        title: "\(copy.submitAnswer) · \(copy[.demo])", symbol: "paperplane"
                    ) {
                        flow.submit()
                    }
                    .disabled(!flow.canSubmit)
                    .accessibilityHint(copy.native(.demoChooseBeforeContinue))
                    .accessibilityIdentifier("demo-submit")
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .frame(maxWidth: 680).frame(maxWidth: .infinity)
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle(copy.native(.demoPractice)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.native(.demoSettings), systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                }
            }
        }

        private var selectedAnswer: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.native(.demoChoice)).font(.headline)
                if let selection = flow.selection {
                    Text(NativeDemoFlow.options[selection])
                }
            }
            .accessibilityElement(children: .combine)
        }

        private var followUp: some View {
            List {
                Section {
                    demoNotice
                    Text(copy.native(.demoProfile)).font(.title2.bold())
                    Text(copy.native(.demoProfileHint))
                        .foregroundStyle(.secondary)
                }
                Section {
                    NavigationLink {
                        demoHistory
                    } label: {
                        Label(copy.progressAndHistory, systemImage: "clock.arrow.circlepath")
                            .frame(minHeight: 44)
                    }
                    NavigationLink {
                        List {
                            Section(copy.appLanguage) { NativeAppLanguagePicker() }
                            Section(copy.native(.demoControls)) {
                                Button(copy.native(.demoPreviewStates)) {
                                    showScenarios = true
                                }
                                .frame(minHeight: 44)
                                Button(copy.native(.demoReset), role: .destructive) {
                                    showReset = true
                                }
                                .frame(minHeight: 44)
                            }
                            Section(copy.native(.demoAppearance)) {
                                Text(
                                    copy.native(.demoAppearanceHint)
                                )
                            }
                            Section(copy.native(.account)) {
                                Text(
                                    copy.native(.demoAccountHint)
                                )
                            }
                        }
                        .navigationTitle(copy.settings)
                    } label: {
                        Label(copy.settings, systemImage: "gearshape")
                            .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.profile)
            .toolbar { demoToolbar }
        }

        private var demoHistory: some View {
            List {
                Section { demoNotice }
                Section(copy.native(.demoHistory)) {
                    if let goal = flow.objective {
                        Text(goal.displayTitle(copy)).font(.headline)
                        Button(action: resumeExercise) {
                            Label(copy.resume, systemImage: flow.phase.symbol)
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("resume-demo-follow-up")
                        Text(flow.activitySummary(copy))
                        if flow.phase == .reviewed {
                            Text(goal.practice.takeaway)
                        }
                        Text(copy.native(.demoHistoryHint))
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(
                            copy[.chooseGoal], systemImage: "scope",
                            description: Text(copy[.noHistory]))
                        Button(copy[.chooseGoal]) {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.native(.demoHistory))
            .toolbar { demoToolbar }
        }

        private struct DemoReadingSection: View {
            let title: String
            let text: String

            var body: some View {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                    Text(text).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        private struct DemoPracticeTrail: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            let progress: NativeDemoPracticeProgress

            var body: some View {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { steps }
                    VStack(alignment: .leading, spacing: 8) { steps }
                }
                .font(.subheadline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progress.accessibilityLabel(copy))
            }

            @ViewBuilder private var steps: some View {
                ForEach(NativeDemoPracticeStage.allCases, id: \.self) { step in
                    let state = progress.state(for: step)
                    Label(
                        step.label(copy),
                        systemImage: state.symbol
                    )
                    .foregroundStyle(state == .current ? NativePrism.tint : Color.secondary)
                    .fontWeight(state == .current ? .semibold : .regular)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        private struct DemoTakeaway: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            let text: String

            var body: some View {
                GroupBox {
                    Text(text)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } label: {
                    Label(copy.native(.takeaway), systemImage: "lightbulb")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }

        private struct DemoResponsibilities: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            let rows: [NativeDemoPractice.Responsibility]

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text(copy.native(.demoResponsibilities)).font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(rows, id: \.layer) { row in
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.layer).font(.subheadline.weight(.semibold))
                            Text(row.owner)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }

        private var demoNotice: some View {
            VStack(alignment: .leading, spacing: 4) {
                Label(copy.native(.demoNotice), systemImage: "testtube.2")
                Text(copy.native(.demoFrenchExamples)).font(.caption)
                NativeContentLanguageBadges(languages: ["fr"])
            }

            .font(.subheadline).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("synthetic-demo-notice")
        }

        private func scenarioTitle(_ scenario: DemoCatalogScenario) -> String {
            switch scenario {
            case .ready: copy.native(.demoReady)
            case .loading: copy.native(.demoLoading)
            case .empty: copy.native(.demoEmpty)
            case .error: copy.native(.demoError)
            }
        }

        @ToolbarContentBuilder private var demoToolbar: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) { Button(copy.native(.close)) { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(copy.native(.demoSettings), systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                    Button(
                        copy.native(.demoReset), systemImage: "arrow.counterclockwise",
                        role: .destructive
                    ) {
                        showReset = true
                    }
                } label: {
                    Label(copy.native(.demoOptions), systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private struct DemoPrimaryButton: View {
        let title: String
        let symbol: String
        let action: () -> Void

        var body: some View {
            NativePrimaryButton(title: title, symbol: symbol, action: action)
        }
    }

    #Preview("Learn · demonstration") { NativeDemoRoot() }
#endif

// A demo-only state machine: no API identity, scoring, answer keys, rewards or production progress.
struct NativeDemoFlow: Codable, Equatable {
    enum Objective: String, Codable, CaseIterable {
        case fundamentals = "Cloud · découverte"
        case operations = "Cloud · exploitation"

        var title: String {
            switch self {
            case .fundamentals: "Les fondamentaux du cloud"
            case .operations: "Les services cloud au quotidien"
            }
        }
        var symbol: String {
            switch self {
            case .fundamentals: "cloud"
            case .operations: "server.rack"
            }
        }
        var practice: NativeDemoPractice {
            switch self {
            case .fundamentals: .fundamentals
            case .operations: .operations
            }
        }
    }
    enum Phase: String, Codable {
        case answering, pending, reviewed
        var symbol: String {
            switch self {
            case .answering: "circle"
            case .pending: "clock"
            case .reviewed: "text.bubble"
            }
        }
    }
    enum InvalidSnapshot: Error { case inconsistentState }
    static let options = [
        "Une infrastructure à administrer (IaaS)",
        "Une plateforme gérée (PaaS)", "Un logiciel prêt à l’emploi (SaaS)",
    ]
    private(set) var objective: Objective?
    private(set) var selection: Int?
    private(set) var phase = Phase.answering

    var canSubmit: Bool { objective != nil && selection != nil && phase == .answering }
    var practice: NativeDemoPractice? { objective?.practice }
    var startRoute: NativeDemoRoute {
        phase == .answering && selection == nil ? .preparation : .exercise
    }
    mutating func choose(_ objective: Objective) {
        guard self.objective != objective else { return }
        self.objective = objective
        restartQuestion()
    }
    mutating func select(_ index: Int) {
        guard objective != nil, phase == .answering, Self.options.indices.contains(index) else {
            return
        }
        selection = index
    }
    mutating func submit() {
        guard canSubmit else { return }
        phase = .pending
    }
    mutating func receiveMockExplanation(offline: Bool) {
        guard phase == .pending, !offline else { return }
        phase = .reviewed
    }
    mutating func restartQuestion() {
        selection = nil
        phase = .answering
    }
    static func restore(_ data: Data) throws -> Self {
        let flow = try JSONDecoder().decode(Self.self, from: data)
        guard flow.selection.map({ options.indices.contains($0) }) ?? true,
            flow.objective != nil || (flow.selection == nil && flow.phase == .answering),
            flow.phase == .answering || flow.selection != nil
        else {
            throw InvalidSnapshot.inconsistentState
        }
        return flow
    }
}

enum NativeDemoPracticeStage: Hashable, CaseIterable {
    case situation, decision, explanation

    var position: Int {
        switch self {
        case .situation: 1
        case .decision: 2
        case .explanation: 3
        }
    }
}

enum NativeDemoPracticeStepState: Equatable {
    case completed, current, upcoming

    var symbol: String {
        switch self {
        case .completed: "circle.fill"
        case .current: "circle.inset.filled"
        case .upcoming: "circle"
        }
    }
}

struct NativeDemoPracticeProgress {
    let current: NativeDemoPracticeStage

    func state(for stage: NativeDemoPracticeStage) -> NativeDemoPracticeStepState {
        if stage == current { return .current }
        return stage.position < current.position ? .completed : .upcoming
    }

}

struct NativeDemoPractice: Sendable {
    struct Responsibility: Sendable {
        let layer: String
        let owner: String
    }
    let title: String
    let intent: String
    let situation: String
    let question: String
    let constraint: String
    let explanation: String
    let takeaway: String
    let responsibilities: [Responsibility]

    static let fundamentals = Self(
        title: "Déployer sans gérer les serveurs",
        intent: "Distinguer une plateforme gérée d’une infrastructure à administrer.",
        situation:
            "L’équipe Exemple veut déployer son application sans administrer le système d’exploitation des serveurs. Elle souhaite garder la responsabilité de son code et de ses données.",
        question: "Quel modèle de service correspond à cette situation fictive ?",
        constraint:
            "L’équipe veut déléguer l’administration du système d’exploitation, pas son application.",
        explanation:
            "Dans cet exemple inventé, une plateforme gérée (PaaS) correspond à cette limite : le fournisseur prend en charge la plateforme et son système. L’équipe déploie son code. Une infrastructure (IaaS) lui laisserait la gestion du système ; un logiciel prêt à l’emploi (SaaS) ne lui fournit pas le même cadre pour déployer son application.",
        takeaway:
            "Le critère utile est la responsabilité conservée par l’équipe, pas seulement la présence de serveurs dans le cloud.",
        responsibilities: [
            .init(layer: "Application et données", owner: "L’équipe Exemple"),
            .init(
                layer: "Plateforme et système d’exploitation",
                owner: "Le fournisseur, dans cet exemple PaaS"),
            .init(layer: "Infrastructure physique", owner: "Le fournisseur"),
        ])

    static let operations = Self(
        title: "Garder la main sur le système",
        intent: "Identifier ce qui reste à administrer dans une infrastructure cloud.",
        situation:
            "L’équipe Atelier exploite une application qui exige une configuration particulière du système d’exploitation. Elle veut installer ses composants système et gérer elle-même les mises à jour, sans entretenir de serveurs physiques.",
        question:
            "Quel modèle de service lui laisse cette responsabilité dans ce scénario fictif ?",
        constraint:
            "L’équipe veut conserver le contrôle du système d’exploitation tout en déléguant le matériel.",
        explanation:
            "Dans cet exemple inventé, une infrastructure à administrer (IaaS) laisse à l’équipe le choix et la gestion du système d’exploitation. Le fournisseur prend en charge le matériel. Une plateforme gérée (PaaS) ou un logiciel prêt à l’emploi (SaaS) ne lui donnent pas cette même responsabilité système.",
        takeaway:
            "Déléguer le matériel ne signifie pas déléguer les mises à jour du système : la frontière dépend du modèle choisi.",
        responsibilities: [
            .init(layer: "Application et données", owner: "L’équipe Atelier"),
            .init(
                layer: "Système d’exploitation et mises à jour",
                owner: "L’équipe Atelier, dans cet exemple IaaS"),
            .init(layer: "Infrastructure physique", owner: "Le fournisseur"),
        ])
}

enum NativeDemoDestination: String, CaseIterable, Hashable {
    case learn, coach, social, profile
}

enum NativeDemoLearnSection: String, Codable {
    case myLearning, explore
}

// Retain version-one storage identifiers; visible destinations use the approved English names.
enum NativeDemoTab: String, Codable, CaseIterable, Hashable {
    case objective, catalog, followUp, coach, social

    var destination: NativeDemoDestination {
        switch self {
        case .objective, .catalog: .learn
        case .followUp: .profile
        case .coach: .coach
        case .social: .social
        }
    }

    static func selecting(
        _ destination: NativeDemoDestination, learnSection: NativeDemoLearnSection
    ) -> Self {
        switch destination {
        case .learn: learnSection == .myLearning ? .objective : .catalog
        case .coach: .coach
        case .social: .social
        case .profile: .followUp
        }
    }
}

enum NativeDemoRoute: Codable, Equatable, Hashable {
    case preparation
    case exercise
    case goalDetail(NativeDemoFlow.Objective)
}

struct NativeDemoNavigationState: Codable, Equatable {
    enum InvalidSnapshot: Error { case tooLarge, inconsistentRoute }
    private static let maximumEncodedBytes = 4_096

    let selectedTab: NativeDemoTab
    let objectivePath: [NativeDemoRoute]
    let catalogPath: [NativeDemoRoute]
    let learnSection: NativeDemoLearnSection

    init(
        selectedTab: NativeDemoTab, objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute], learnSection: NativeDemoLearnSection? = nil
    ) {
        self.selectedTab = selectedTab
        self.objectivePath = objectivePath
        self.catalogPath = catalogPath
        self.learnSection = learnSection ?? (selectedTab == .catalog ? .explore : .myLearning)
    }

    private enum CodingKeys: String, CodingKey {
        case selectedTab, objectivePath, catalogPath, learnSection
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedTab: try values.decode(NativeDemoTab.self, forKey: .selectedTab),
            objectivePath: try values.decode([NativeDemoRoute].self, forKey: .objectivePath),
            catalogPath: try values.decode([NativeDemoRoute].self, forKey: .catalogPath),
            learnSection: try values.decodeIfPresent(
                NativeDemoLearnSection.self, forKey: .learnSection))
    }

    static func make(
        selectedTab: NativeDemoTab,
        objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute],
        flow: NativeDemoFlow,
        learnSection: NativeDemoLearnSection? = nil
    ) throws -> Self {
        let state = Self(
            selectedTab: selectedTab, objectivePath: objectivePath, catalogPath: catalogPath,
            learnSection: learnSection)
        try state.validate(for: flow)
        return state
    }

    static func restore(_ data: Data, for flow: NativeDemoFlow) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw InvalidSnapshot.tooLarge
        }
        let state = try JSONDecoder().decode(Self.self, from: data)
        try state.validate(for: flow)
        return state
    }

    func resumingExercise(for flow: NativeDemoFlow) throws -> Self {
        try Self.make(
            selectedTab: .objective, objectivePath: [.exercise],
            catalogPath: catalogPath, flow: flow)
    }

    private func validate(for flow: NativeDemoFlow) throws {
        let objectiveRoutesAreValid =
            objectivePath.count <= 1
            && objectivePath.allSatisfy { $0 == .exercise || $0 == .preparation }
            && (objectivePath.isEmpty || flow.objective != nil)
        let catalogRoutesAreValid =
            catalogPath.count <= 1
            && catalogPath.allSatisfy {
                if case .goalDetail = $0 { true } else { false }
            }
        let sectionMatchesTab =
            (selectedTab != .objective || learnSection == .myLearning)
            && (selectedTab != .catalog || learnSection == .explore)
        guard objectiveRoutesAreValid, catalogRoutesAreValid, sectionMatchesTab else {
            throw InvalidSnapshot.inconsistentRoute
        }
    }
}

enum NativeDemoPersistence {
    case awaitingRestoration, ready, preservingRejectedSnapshot

    mutating func restore(_ savedState: String) throws -> NativeDemoSnapshot? {
        self = .preservingRejectedSnapshot
        let snapshot =
            savedState.isEmpty ? nil : try NativeDemoSnapshot.restore(Data(savedState.utf8))
        self = .ready
        return snapshot
    }

    func save(_ snapshot: NativeDemoSnapshot, to savedState: inout String) throws {
        guard self == .ready else { return }
        savedState = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
    }

    mutating func reset(_ savedState: inout String) {
        savedState = ""
        self = .ready
    }
}

struct NativeDemoSnapshot: Codable, Equatable {
    enum InvalidSnapshot: Error { case tooLarge, unsupportedSchema }

    private static let maximumEncodedBytes = 8_192
    let schema: Int
    let flow: NativeDemoFlow
    let navigation: NativeDemoNavigationState

    static func make(
        flow: NativeDemoFlow, navigation: NativeDemoNavigationState
    ) throws -> Self {
        let validatedNavigation = try NativeDemoNavigationState.make(
            selectedTab: navigation.selectedTab,
            objectivePath: navigation.objectivePath,
            catalogPath: navigation.catalogPath,
            flow: flow, learnSection: navigation.learnSection)
        return Self(schema: 1, flow: flow, navigation: validatedNavigation)
    }

    static func restore(_ data: Data) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw InvalidSnapshot.tooLarge
        }
        let decoder = JSONDecoder()
        do {
            let snapshot = try decoder.decode(Self.self, from: data)
            guard snapshot.schema == 1 else {
                throw InvalidSnapshot.unsupportedSchema
            }
            return try make(flow: snapshot.flow, navigation: snapshot.navigation)
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "schema" {
            let legacyFlow = try NativeDemoFlow.restore(data)
            let legacyNavigation = try NativeDemoNavigationState.make(
                selectedTab: legacyFlow.objective == nil ? .catalog : .objective,
                objectivePath: [], catalogPath: [], flow: legacyFlow)
            return try make(flow: legacyFlow, navigation: legacyNavigation)
        }
    }
}

#if canImport(SwiftUI)
    private struct NativeAccountDeletionView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Bindable var model: NativeModel
        @Environment(\.dismiss) private var dismiss
        @Environment(\.scenePhase) private var scenePhase
        private enum Focus: Hashable { case status, error }
        @AccessibilityFocusState private var focused: Focus?

        var body: some View {
            Form {
                Section {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focused, equals: .status)
                    if model.deletionBusy { ProgressView(copy.loading) }
                    if let message = model.deletionMessage {
                        Text(message.resolved(using: copy)).accessibilityIdentifier(
                            "account-deletion-message"
                        )
                        .accessibilityFocused($focused, equals: .error)
                    }
                }
                if [.explanation, .verifying, .confirmation].contains(
                    model.deletionStage ?? .explanation)
                {
                    Section(copy[.deletionBeforeContinuing]) {
                        Text(
                            copy[.deletionScopeNote]
                        )
                        Text(
                            copy[.deletionRetentionNote]
                        )
                        if model.canReauthenticateForDeletion {
                            Button(
                                copy[.deletionVerify],
                                systemImage: "person.badge.shield.checkmark"
                            ) {
                                Task { await model.verifyDeletionIdentity() }
                            }
                            .disabled(model.deletionBusy)
                        } else {
                            Text(
                                copy[.deletionMicrosoftRequired]
                            )
                        }
                    }
                } else if model.deletionStage == .pending || model.deletionStage == .unconfirmed
                    || model.deletionStage == .checking
                {
                    Section(copy[.deletionServerStatus]) {
                        if let status = model.deletionStatus, status.status == .pending {
                            Text(
                                copy.deletionProgress(
                                    completed: status.completedSteps, total: status.totalSteps)
                            )
                            Text(
                                copy[.deletionPendingNote]
                            )
                            if status.retryAfterSeconds != nil {
                                Text(
                                    copy[.deletionRetryDelay]
                                )
                            }
                        }
                        Button(copy[.deletionCheckStatus], systemImage: "arrow.clockwise") {
                            Task { await model.refreshDeletionStatus() }
                        }
                        .disabled(model.deletionBusy)
                        Button(
                            copy[.deletionSignInSameAccount], systemImage: "person.crop.circle"
                        ) {
                            Task { await model.recoverDeletionConnection(interactive: true) }
                        }
                        .disabled(model.deletionBusy)
                        Button(copy.retry, role: .destructive) {
                            Task { await model.retryAccountDeletion() }
                        }
                        .disabled(!model.canRetryDeletion)
                        if model.deletionStatus?.status == .notRequested {
                            Button(copy[.deletionResumeAccount]) {
                                Task { await model.resumeAccountAfterStatusCheck() }
                            }
                            .disabled(model.deletionBusy)
                        }
                    }
                } else if model.deletionStage == .cleanupFailed {
                    Section {
                        Text(
                            copy[.deletionCleanupIncomplete]
                        )
                        Button(copy.retry, systemImage: "arrow.clockwise") {
                            Task { await model.retryDeletionCleanup() }
                        }
                        .disabled(model.deletionBusy)
                    }
                } else if model.deletionStage == .completed {
                    Section {
                        Text(
                            copy[.deletionCompletedNote]
                        )
                        Button(copy[.deletionReturnToSignIn]) { model.acknowledgeAccountDeletion() }
                    }
                }
            }
            .navigationTitle(copy.accountDeletion)
            .navigationBarBackButtonHidden(model.deletionBusy || !model.canCancelDeletion)
            .toolbar {
                if model.canCancelDeletion {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(copy[.cancel]) {
                            Task {
                                await model.cancelAccountDeletion()
                                if model.deletionStage == nil { dismiss() }
                            }
                        }
                    }
                }
            }
            .alert(
                copy[.deletionConfirmTitle],
                isPresented: Binding(
                    get: { model.deletionStage == .confirmation },
                    set: { _ in })
            ) {
                Button(copy[.deleteAccount], role: .destructive) {
                    Task { await model.confirmAccountDeletion() }
                }
                Button(copy[.cancel], role: .cancel) { model.discardDeletionProof() }
            } message: {
                Text(
                    copy[.deletionConfirmMessage]
                )
            }
            .onChange(of: model.deletionStage) { _, _ in focused = .status }
            .onChange(of: model.deletionMessage) { _, message in
                focused = message == nil ? .status : .error
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.discardDeletionProof() }
            }
            .onAppear { if model.deletionStage == nil { model.showAccountDeletion() } }
            .onDisappear {
                model.discardDeletionProof()
                if model.canCancelDeletion { Task { await model.cancelAccountDeletion() } }
            }
        }

        private var title: String {
            switch model.deletionStage {
            case .verifying: copy[.deletionVerifying]
            case .confirmation: copy[.deletionIdentityVerified]
            case .checking: copy[.deletionChecking]
            case .pending: copy[.deletionPending]
            case .unconfirmed: copy[.deletionUnconfirmed]
            case .cleanupFailed: copy[.deletionCleanupAttention]
            case .completed: copy[.deletionCompleted]
            default: copy[.deletionTitle]
            }
        }
    }

    private struct NativeRoot: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @Bindable var model: NativeModel
        @Binding var pendingLessonLink: EditorialPilotLessonLink?
        @State private var selectedTrack: String?
        @State private var selectedLesson: String?
        @State private var savingGoalID: String?
        @State private var navigation = NativeLearningNavigation()
        @State private var columns: NavigationSplitViewVisibility = .automatic
        @State private var compactColumn: NavigationSplitViewColumn = .sidebar
        @State private var showEditorialPilot = false
        @State private var requestedLessonID: String?
        @State private var loadingTrackID: String?
        @State private var loadingPathRequestID: UUID?
        @State private var loadingLessonID: String?
        @State private var loadingLessonRequestID: UUID?
        @State private var downloadTrack: Track?
        @State private var catalogFilter = NativeCatalogFilter()
        @State private var resumeTrackID: String?
        @State private var showingStudyPlan = false

        init(
            model: NativeModel,
            pendingLessonLink: Binding<EditorialPilotLessonLink?> = .constant(nil)
        ) {
            self.model = model
            self._pendingLessonLink = pendingLessonLink
        }

        var body: some View {
            Group {
                if model.requiresDeletionSurface {
                    NavigationStack { NativeAccountDeletionView(model: model) }
                } else if model.profile == nil {
                    connection
                } else {
                    TabView(selection: $model.selectedTab) {
                        learning
                            .tabItem { Label(copy.learn, systemImage: "book") }
                            .tag(NativeResumeState.Tab.learn)
                        NavigationStack {
                            coach
                        }
                        .tabItem { Label(copy.coach, systemImage: "bubble.left.and.bubble.right") }
                        .tag(NativeResumeState.Tab.coach)
                        NavigationStack {
                            NativeReadingPage {
                                Picker(copy.social, selection: $navigation.social) {
                                    Text(copy.friends).tag(NativeLearningNavigation.Social.friends)
                                    Text(copy.teams).tag(NativeLearningNavigation.Social.teams)
                                }
                                .pickerStyle(.menu)
                                ContentUnavailableView(
                                    navigation.social == .friends
                                        ? copy.native(.socialUnavailable)
                                        : copy.native(.socialUnavailable),
                                    systemImage: "person.2",
                                    description: Text(
                                        copy.native(.socialUnavailableHint)
                                    ))
                                NativeReadingSection(title: copy.native(.privateLearning)) {
                                    Text(
                                        copy.native(.privateProfileHint)
                                    )
                                    Text(
                                        copy.native(.privateResultsHint)
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                NativeReadingSection(
                                    title: navigation.social == .friends
                                        ? copy.native(.friendsInactive)
                                        : copy.native(.teamsInactive)
                                ) {
                                    Text(
                                        navigation.social == .friends
                                            ? copy.native(.friendsPrivacy)
                                            : copy.native(.teamsPrivacy)
                                    )
                                    Text(
                                        copy.native(.sharingConsent)
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                Button(copy.native(.returnLearning), systemImage: "book") {
                                    model.selectedTab = .learn
                                }
                                .frame(minHeight: 44)
                            }
                            .navigationTitle(copy.social)
                        }
                        .tabItem { Label(copy.social, systemImage: "person.2") }
                        .tag(NativeResumeState.Tab.social)
                        NavigationStack { profile }
                            .tabItem { Label(copy.profile, systemImage: "person.crop.circle") }
                            .tag(NativeResumeState.Tab.profile)
                    }
                }
            }
            .onChange(of: model.profile?.id, initial: true) { _, owner in
                navigation = NativeLearningNavigation(hasGoal: model.profile?.activeTrackId != nil)
                selectedTrack = nil
                selectedLesson = nil
                catalogFilter.clear()
                showingStudyPlan = false
                resumeTrackID = nil
                columns = .automatic
                compactColumn = .sidebar
                loadingTrackID = nil
                loadingPathRequestID = nil
                loadingLessonID = nil
                loadingLessonRequestID = nil
                if owner == nil { savingGoalID = nil }
            }
            .onChange(of: model.profile?.activeTrackId) { _, _ in
                showingStudyPlan = false
            }
            .onChange(of: model.restorationRevision) { _, _ in
                selectedTrack = model.path?.trackId ?? model.offlinePack?.trackId
                selectedLesson = model.lesson?.id
                if model.lesson != nil {
                    columns = .detailOnly
                    compactColumn = .detail
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.busy {
                    ProgressView(
                        savingGoalID == nil ? copy.loading : copy.native(.savingGoal)
                    )
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        if reduceTransparency {
                            NativePrism.surface
                        } else {
                            Rectangle().fill(.regularMaterial)
                        }
                    }
                    .overlay(alignment: .top) {
                        Rectangle().fill(NativePrism.edge).frame(height: 1)
                            .accessibilityHidden(true)
                    }
                }
            }
            .alert(
                copy.native(.operationUnconfirmed),
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button(copy[.done], role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage?.resolved(using: copy) ?? "")
            }
            .task { await model.restore() }
            .sheet(isPresented: $showEditorialPilot) {
                NativeEditorialPilotView(
                    model: model,
                    requestedLessonID: requestedLessonID
                )
            }
            .sheet(isPresented: $showingStudyPlan) {
                if let ownerID = model.profile?.id, let trackID = model.profile?.activeTrackId {
                    NativeStudyPlanView(model: model, ownerID: ownerID, trackID: trackID)
                }
            }
        }

        private var coach: some View {
            NativeReadingPage {
                NativeEntryHeading(
                    title: copy[.coachWorkspaceTitle], message: copy[.coachPromptHint])
                Text(copy.native(.coachDisclosure))
                    .font(.subheadline).foregroundStyle(.secondary)
                if case .corrected(let result) = model.outcome, let lesson = model.lesson {
                    ForEach(result.results) { item in
                        if let question = lesson.questions.first(where: { $0.id == item.itemId }) {
                            NativeReadingSection(title: lesson.title) {
                                Text(.init(question.stem)).font(.headline)
                                Text(.init(item.explanation)).textSelection(.enabled)
                                tutorContent(for: item.itemId)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        copy[.coachPromptHint], systemImage: "bubble.left.and.bubble.right",
                        description: model.outcome == nil ? nil : Text(coachPhase))
                }
                NativeReadingSection(title: copy.native(.currentContext)) {
                    if let goal = model.profile?.activeTrackId {
                        LabeledContent(copy.native(.confirmedGoal), value: trackTitle(goal))
                    } else {
                        Text(copy.native(.noGoal))
                    }
                    if let lesson = model.lesson {
                        Text(lesson.title).font(.headline)
                        Text(coachPhase)
                    }
                    Text(copy.native(.coachPrivacy))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(copy.native(.chooseContext), systemImage: "book") {
                        showMyLearning()
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle(copy.coach)
        }

        private var coachPhase: String {
            switch model.outcome {
            case .pendingCorrection: copy[.pendingCorrection]
            case .corrected: copy.confirmed
            case nil: copy[.coachPromptHint]
            }
        }

        @ViewBuilder private func tutorContent(for itemID: String) -> some View {
            if let explanation = model.tutorExplanation, explanation.itemId == itemID {
                NativeReadingCard {
                    Text(copy[.coachHeadline]).font(.subheadline).foregroundStyle(.secondary)
                    Text(explanation.headline).font(.headline)
                    Text(copy[.coachKeyPoints]).font(.subheadline.weight(.semibold))
                    ForEach(Array(explanation.points.enumerated()), id: \.offset) { _, point in
                        Text(point).textSelection(.enabled)
                    }
                    Text(explanation.encouragement)
                    Text(copy[.coachRecommendation]).font(.subheadline.weight(.semibold))
                    Text(explanation.recommendation).textSelection(.enabled)
                    Divider()
                    Text(copy[.coachPersonalization]).font(.subheadline.weight(.semibold))
                    LabeledContent(
                        copy.native(.attempts), value: "\(explanation.personalization.attempts)")
                    LabeledContent(
                        copy.native(.errors), value: "\(explanation.personalization.errors)")
                    LabeledContent(
                        copy.native(.accuracy),
                        value: "\(explanation.personalization.accuracyPct) %")
                    LabeledContent(copy.native(.trend), value: explanation.personalization.trend)
                    LabeledContent(
                        copy.native(.recurringErrors),
                        value: copy.native(
                            explanation.personalization.recurringStruggle ? .yes : .no))
                    Text(
                        explanation.source == "grounded"
                            ? copy[.coachSourceGrounded]
                            : explanation.source == "ai"
                                ? copy.native(.sourceAI)
                                : "\(copy.native(.sourceOther)) · \(explanation.source)"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Text(explanation.citedConceptIds.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("confirmed-tutor-explanation")
            }
            if model.isRequestingTutorExplanation {
                ProgressView(copy[.coachExplaining])
            }
            if model.tutorExplanationError != nil {
                Label(copy.native(.tutorFailure), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            let wasWrong: Bool = {
                guard case .corrected(let result) = model.outcome else { return false }
                return result.results.first(where: { $0.itemId == itemID })?.correct == false
            }()
            Button(
                wasWrong ? copy[.whyWasIWrong] : copy[.explainWithCoach],
                systemImage: "bubble.left.and.bubble.right"
            ) {
                Task { await model.requestTutorExplanation(itemId: itemID) }
            }
            .frame(minHeight: 44)
            .disabled(model.busy || model.isRequestingTutorExplanation)
            .accessibilityIdentifier("request-tutor-explanation-\(itemID)")
        }

        private var visibleTracks: [Track] {
            model.tracks.filter {
                navigation.showsTrack(
                    $0.id, activeID: model.profile?.activeTrackId, openedID: selectedTrack)
                    && (navigation.learn != .explore
                        || catalogFilter.includes(
                            code: $0.code, title: $0.title, summary: $0.summary,
                            available: $0.learningAvailable))
            }
        }

        private var catalogFamilies: [String] {
            Set(model.tracks.map { NativeCatalogFilter.family(for: $0.code) })
                .filter { !$0.isEmpty }.sorted()
        }

        private var catalogCategories: [NativeRadarCategory] {
            NativeRadarCategory.allCases.filter { category in
                model.tracks.contains {
                    NativeTrackAppearance.group(for: $0.code)?.category == category
                }
            }
        }

        private var learning: some View {
            NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn)
            {
                List(selection: $selectedTrack) {
                    Section {
                        Picker(copy.learn, selection: $navigation.learn) {
                            Text(copy.myLearning).tag(NativeLearningNavigation.Learn.myLearning)
                            Text(copy.explore).tag(NativeLearningNavigation.Learn.explore)
                        }
                        .pickerStyle(.menu)
                    }
                    if navigation.learn == .myLearning {
                        Section {
                            confirmedGoal
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        myLearningPlan
                        Section(copy.native(.readiness)) {
                            learningInsights
                        }
                        Section(copy.native(.finalAssessment)) {
                            NavigationLink {
                                NativeMockExamView(model: model)
                            } label: {
                                Label(copy[.startFinalAssessment], systemImage: "checkmark.seal")
                            }
                        }
                    } else {
                        Section {
                            Text(copy.native(.findGoal))
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(copy.native(.catalogHint))
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                        Section(copy.native(.findCertification)) {
                            Picker(copy.native(.codeFamily), selection: $catalogFilter.family) {
                                Text(copy.native(.allFamilies)).tag("")
                                ForEach(catalogFamilies, id: \.self) { family in
                                    Text(family).tag(family)
                                }
                            }
                            Picker(copy.native(.codeCategory), selection: $catalogFilter.category) {
                                Text(copy[.categoryAll]).tag(nil as NativeRadarCategory?)
                                ForEach(catalogCategories, id: \.self) { category in
                                    Text(category.title(copy)).tag(Optional(category))
                                }
                            }
                            Toggle(copy.native(.availableOnly), isOn: $catalogFilter.availableOnly)
                            Text(copy.native(.catalogScope))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(
                                "\(copy.native(.loadedResults)) · \(visibleTracks.count) / \(model.tracks.count)"
                            )
                            .font(.subheadline)
                            if catalogFilter.isActive {
                                Button(copy[.clearFilters], systemImage: "xmark.circle") {
                                    catalogFilter.clear()
                                }
                            }
                        }
                    }
                    Section(copy.native(.continueDevice)) {
                        if let lesson = model.lesson,
                            navigation.learn == .explore
                                || lesson.trackId.lowercased()
                                    != model.profile?.activeTrackId?.lowercased()
                        {
                            Button("\(copy.resume) · \(lesson.title)", systemImage: "play.circle") {
                                resumeCurrentActivity(lesson)
                            }
                            .disabled(model.busy || loadingLessonID != nil)
                        }
                        Button(copy.native(.restoreActivity), systemImage: "internaldrive") {
                            Task { await model.restoreDownloadedActivity() }
                        }
                        .disabled(model.busy)
                        if navigation.learn == .myLearning && model.profile?.activeTrackId == nil {
                            Text(copy.native(.chooseGoalHint))
                            Button(copy.explore) { navigation.learn = .explore }
                        }
                    }
                    Section(copy.native(.guidedReading)) {
                        Button("Assistants IA responsables", systemImage: "text.book.closed") {
                            requestedLessonID = nil
                            showEditorialPilot = true
                        }
                        Text(copy.native(.frenchPilot))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let pendingLessonLink {
                        Section(copy.native(.sharedLesson)) {
                            Text("\(copy.native(.editorialPilot)) · \(pendingLessonLink.lessonID)")
                            Button(
                                copy.native(.openLinkedLesson), systemImage: "arrow.up.right.square"
                            ) {
                                requestedLessonID = pendingLessonLink.lessonID
                                self.pendingLessonLink = nil
                                showEditorialPilot = true
                            }
                            .disabled(model.busy)
                            .accessibilityIdentifier("open-linked-editorial-lesson")
                        }
                    }
                    Section(
                        navigation.learn == .explore
                            ? copy.native(.collection) : copy.native(.yourGoals)
                    ) {
                        ForEach(visibleTracks) { track in
                            NavigationLink(value: track.id) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(track.code, systemImage: "books.vertical")
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(NativePrism.accent(for: track.code))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            NativePrism.surface,
                                            in: Capsule(style: .continuous))
                                    Text(track.title).font(.title3.weight(.semibold))
                                    NativeContentLanguageBadges(languages: track.languages ?? [])
                                    if let group = NativeTrackAppearance.group(for: track.code) {
                                        Text(
                                            "\(NativeCatalogFilter.family(for: track.code)) · \(group.category.title(copy))"
                                        )
                                        .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(track.summary).font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    NativePracticeBadge(available: track.learningAvailable)
                                }
                                .padding(.vertical, 8)
                            }
                            .disabled(model.busy)
                        }
                    }
                    if model.tracks.isEmpty {
                        Text(copy.native(.noCatalog))
                    } else if navigation.learn == .explore && visibleTracks.isEmpty {
                        Section {
                            ContentUnavailableView(
                                copy[.noMatchingTracks], systemImage: "magnifyingglass",
                                description: Text(copy.native(.noMatchesHint)))
                            Button(copy[.clearFilters]) { catalogFilter.clear() }
                        }
                    }
                }
                .disabled(
                    model.busy || loadingTrackID != nil || loadingLessonID != nil
                )
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(NativePrism.canvas)
                .navigationTitle(copy.learn)
                .modifier(
                    NativeCatalogSearch(
                        enabled: navigation.learn == .explore, query: $catalogFilter.query))
            } content: {
                path
            } detail: {
                session
            }
            .onChange(of: selectedTrack) { _, id in
                if let resumeTrackID, resumeTrackID == id {
                    self.resumeTrackID = nil
                    return
                }
                guard let track = model.tracks.first(where: { $0.id == id }),
                    track.learningAvailable
                else { return }
                guard model.path?.trackId != track.id else { return }
                if model.offlinePack?.trackId == track.id && model.lesson != nil { return }
                selectedLesson = nil
                requestPath(track)
            }
            .onChange(of: selectedLesson) { _, id in
                guard model.lesson?.id != id else { return }
                if let id, model.offlinePack?.lessons.contains(where: { $0.id == id }) == true {
                    Task { await model.openCachedLesson(id) }
                    return
                }
                guard
                    let node = model.path?.units.flatMap(\.lessons).first(where: {
                        $0.id == id
                    }
                    )
                else { return }
                requestLesson(node)
            }
            .confirmationDialog(
                copy.native(.downloadQuestionPacks),
                isPresented: Binding(
                    get: { downloadTrack != nil },
                    set: { if !$0 { downloadTrack = nil } })
            ) {
                if let track = downloadTrack {
                    Button(copy.native(.downloadContent)) {
                        downloadTrack = nil
                        Task { await model.downloadQuestionPack(track) }
                    }
                }
            } message: {
                Text(
                    copy.native(.downloadBoundary)
                )
            }
        }

        @ViewBuilder private var myLearningPlan: some View {
            Section(copy.native(.learningPlan)) {
                if let path = model.path,
                    path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased()
                {
                    let coverage = NativePathCoverage(
                        units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                    Text(
                        "\(copy.native(.remainingActivities)) · \(coverage.remainingActivities) / \(coverage.totalActivities)"
                    )
                    .font(.headline)
                    ForEach(path.units) { unit in
                        LabeledContent(
                            unit.title, value: "\(unit.lessons.count) · \(copy.native(.activities))"
                        )
                        ForEach(unit.lessons) { lesson in
                            LabeledContent(
                                lesson.title,
                                value:
                                    "\(lesson.nativeMasteryStage.symbol) \(copy[lesson.nativeMasteryStage.copyKey])"
                            )
                            .font(.subheadline)
                        }
                    }
                    Text(copy.native(.openPlanHint))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(copy.native(.loadGoalHint))
                        .foregroundStyle(.secondary)
                }
            }
            Section(copy.native(.reviewPractice)) {
                smartReview
                Text(copy.native(.readCorrectionHint))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section(copy.native(.goalOverview)) {
                if let goal = model.profile?.activeTrackId,
                    let track = model.tracks.first(where: {
                        $0.id.lowercased() == goal.lowercased()
                    })
                {
                    Button(
                        "\(copy.native(.openOverview)) · \(track.title)",
                        systemImage: "list.bullet.rectangle"
                    ) {
                        selectedTrack = track.id
                        columns = .all
                        compactColumn = .content
                    }
                    Text(copy.native(.overviewHint))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(copy.native(.chooseGoalHint))
                        .foregroundStyle(.secondary)
                }
            }
        }

        @ViewBuilder private var smartReview: some View {
            Text(copy[.recommendedReview]).font(.headline)
            if let path = model.path,
                path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased(),
                model.tracks.first(where: { $0.id == path.trackId })?.learningAvailable == true,
                let recommendation = model.smartReviewRecommendation,
                let node = recommendation.unit.lessons.first(where: { $0.canOpen })
            {
                Text(recommendation.unit.title).font(.title3.weight(.semibold))
                Text(reviewReason(recommendation.reason)).foregroundStyle(.secondary)
                Button(
                    "\(copy[.startReview]) · \(node.title) · \(copy.minutes(node.estMinutes))",
                    systemImage: "arrow.clockwise"
                ) {
                    selectedTrack = path.trackId
                    selectedLesson = node.id
                    columns = .detailOnly
                    compactColumn = .detail
                    if model.lesson?.id == node.id { requestLesson(node) }
                }
                .frame(minHeight: 44)
                .disabled(model.busy || loadingLessonID != nil)
            } else {
                Text(copy.native(.noReview)).foregroundStyle(.secondary)
            }
            Text(copy.native(.reviewEvidence)).font(.caption).foregroundStyle(.secondary)
            Button(copy.native(.refreshHistory), systemImage: "arrow.clockwise") {
                Task { await model.refreshHistory() }
            }
            .disabled(model.historyLoading || model.busy)
        }

        private func reviewReason(_ reason: SmartReviewRecommendation.Reason) -> String {
            switch reason {
            case .lowestScore(let score): "\(copy.native(.lowestScore)) · \(score) %"
            case .recurringErrors: copy.native(.recurringErrors)
            case .notYetAttempted: copy[.reviewReasonContinue]
            case .nextUnlockedUnit: copy.native(.continueReview)
            }
        }

        @ViewBuilder private var learningInsights: some View {
            if let path = model.path,
                path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased()
            {
                LabeledContent(copy.native(.readiness), value: "\(path.readinessScore) %")
                Text(copy.native(.readinessHint)).font(.caption).foregroundStyle(.secondary)
                let remaining = NativeLearningDuration.total(
                    path.units.flatMap(\.lessons).filter {
                        $0.status != .completed && $0.status != .mastered
                    }.map(\.estMinutes))
                if let remaining {
                    LabeledContent(
                        copy.native(.remainingLearning), value: "\(copy.minutes(remaining))")
                } else {
                    Label(copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
                }
                Text(copy.native(.skills)).font(.headline)
                if let domains = path.domains, !domains.isEmpty {
                    ForEach(domains, id: \.id) { domain in
                        if let band = try? SkillBand.resolved(percent: domain.score) {
                            LabeledContent(domain.name, value: "\(domain.score) %")
                                .foregroundStyle(domainScoreColor(band))
                        } else {
                            Label(
                                copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
                        }
                    }
                    if let weakest = domains.filter({ (0...100).contains($0.score) })
                        .min(by: { $0.score < $1.score })
                    {
                        Text("\(copy.native(.focusArea)) · \(weakest.name)").font(.headline)
                        if let recommendation = model.recommendations?.items.first(where: {
                            $0.domainId == weakest.id
                        }) {
                            recommendationAction(recommendation)
                        }
                    }
                }
                Text(copy.native(.domainMasteryUnavailable))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(copy.native(.loadGoalHint)).foregroundStyle(.secondary)
            }
            Text(copy.native(.review)).font(.headline)
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(MasteryStage.allCases, id: \.self) { stage in
                        Text("\(stage.symbol) \(copy[stage.copyKey])")
                            .font(.caption)
                    }
                }
            }
            Text(copy.native(.readinessHint)).font(.caption).foregroundStyle(.secondary)
            if let recommendations = model.recommendations {
                let reviews = recommendations.items.filter { $0.kind == "review" }
                LabeledContent(copy.native(.reviewRecommendations), value: "\(reviews.count)")
                ForEach(Array(reviews.enumerated()), id: \.offset) { _, item in
                    recommendationAction(item)
                    LabeledContent(copy.native(.reviewRisk), value: "\(item.forgettingRiskPct) %")
                }
            }
            Text(copy.native(.reviewTimingUnavailable)).font(.caption).foregroundStyle(.secondary)
            if model.insightsLoading { ProgressView(copy.loading) }
            if !model.insightFailures.isEmpty {
                Label(copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
            }
            Button(copy.native(.refreshData), systemImage: "arrow.clockwise") {
                Task { await model.refreshLearningInsights() }
            }
            .frame(minHeight: 44)
            .disabled(model.busy || model.insightsLoading)
        }

        private func domainScoreColor(_ band: SkillBand) -> Color {
            switch band {
            case .strong: NativePrism.confirmed
            case .developing: NativePrism.pending
            case .weak: Color(uiColor: .systemRed)
            }
        }

        private func recommendationNode(_ recommendation: RecommendationItem) -> PathLesson? {
            guard let path = model.path, let recommendations = model.recommendations,
                path.trackId == recommendations.trackId,
                path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased(),
                model.tracks.first(where: { $0.id == path.trackId })?.learningAvailable == true
            else { return nil }
            if let lessonID = recommendation.lessonId {
                return path.units.flatMap(\.lessons).first { $0.id == lessonID && $0.canOpen }
            }
            if let unitID = recommendation.unitId {
                return path.units.first(where: { $0.id == unitID })?.lessons.first { $0.canOpen }
            }
            return nil
        }

        @ViewBuilder private func recommendationAction(_ recommendation: RecommendationItem)
            -> some View
        {
            Text(recommendation.title).font(.headline)
            Text(recommendation.reason).foregroundStyle(.secondary)
            Text("\(copy.native(.duration)) · \(copy.minutes(recommendation.estMinutes))")
                .font(.caption).foregroundStyle(.secondary)
            if let node = recommendationNode(recommendation) {
                Button("\(copy.startSession) · \(node.title)", systemImage: "play.circle") {
                    selectedTrack = model.path?.trackId
                    selectedLesson = node.id
                    columns = .detailOnly
                    compactColumn = .detail
                    if model.lesson?.id == node.id { requestLesson(node) }
                }
                .frame(minHeight: 44)
                .disabled(model.busy || loadingLessonID != nil)
            }
        }

        private var confirmedGoal: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let goalID = model.profile?.activeTrackId {
                    NativeEntryHeading(
                        title: model.tracks.first(where: {
                            $0.id.lowercased() == goalID.lowercased()
                        })?.title ?? goalID,
                        message: copy.confirmed)
                    Text(copy.native(.nextSession)).font(.headline)
                    if let plan = model.studyPlan {
                        if let target = plan.targetExamDate {
                            LabeledContent(
                                copy.native(.targetDate),
                                value: target.formatted(date: .abbreviated, time: .omitted))
                        }
                        Text("\(copy.native(.studyPlan)) · \(copy.minutes(plan.dailyMinutesGoal))")
                            .font(.subheadline)
                        switch plan.initialLevel {
                        case .beginner: Text("\(copy[.initialLevel]) · \(copy[.levelBeginner])")
                        case .intermediate:
                            Text("\(copy[.initialLevel]) · \(copy[.levelIntermediate])")
                        case .advanced: Text("\(copy[.initialLevel]) · \(copy[.levelAdvanced])")
                        }
                    }
                    if let track = model.tracks.first(where: {
                        $0.id.lowercased() == goalID.lowercased()
                    }) {
                        if !track.learningAvailable {
                            NativePracticeBadge(available: false)
                            Text(copy[.practiceUnavailableNote])
                                .font(.subheadline)
                        } else if let lesson = model.lesson,
                            lesson.trackId.lowercased() == goalID.lowercased()
                        {
                            let destination = NativeActivityDestination(
                                lessonID: lesson.id, title: lesson.title)
                            NativePrimaryButton(
                                title: destination.actionTitle(copy.resume), symbol: "play.circle"
                            ) {
                                resumeCurrentActivity(lesson)
                            }
                            .disabled(model.busy || loadingTrackID != nil || loadingLessonID != nil)
                            Text(copy.native(.savedActivityHint))
                                .font(.caption).foregroundStyle(.secondary)
                        } else if let recommendation = model.recommendations?.items.first(where: {
                            recommendationNode($0) != nil
                        }), let next = recommendationNode(recommendation) {
                            NativePrimaryButton(
                                title:
                                    "\(copy.startSession) · \(next.title) · \(copy.minutes(next.estMinutes))",
                                symbol: "play.circle"
                            ) {
                                selectedTrack = track.id
                                selectedLesson = next.id
                                columns = .detailOnly
                                compactColumn = .detail
                            }
                            .disabled(model.busy || loadingTrackID != nil || loadingLessonID != nil)
                        } else if let path = model.path,
                            path.trackId.lowercased() == goalID.lowercased(),
                            let next = path.units.flatMap(\.lessons).first(where: {
                                $0.status == .inProgress || $0.status == .available
                            })
                        {
                            let destination = NativeActivityDestination(
                                lessonID: next.id, title: next.title)
                            NativePrimaryButton(
                                title:
                                    "\(destination.actionTitle(copy.startSession)) · \(copy.minutes(next.estMinutes))",
                                symbol: "play.circle"
                            ) {
                                selectedTrack = path.trackId
                                selectedLesson = destination.lessonID
                                columns = .detailOnly
                                compactColumn = .detail
                            }
                            .disabled(model.busy || loadingTrackID != nil || loadingLessonID != nil)
                            Text(copy.native(.nextAvailableHint))
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            NativePrimaryButton(
                                title: "\(copy.startSession) · \(track.title)",
                                symbol: "arrow.right"
                            ) {
                                selectedTrack = track.id
                                columns = .all
                                compactColumn = .content
                            }
                            .disabled(
                                !track.learningAvailable || model.busy || loadingTrackID != nil)
                        }
                    }
                    Button(copy.native(.studyPlan), systemImage: "calendar") {
                        showingStudyPlan = true
                    }
                    .frame(minHeight: 44)
                    .disabled(model.busy)
                    if let path = model.path,
                        path.trackId.lowercased() == goalID.lowercased()
                    {
                        LabeledContent(
                            copy.native(.readiness),
                            value: "\(path.readinessScore) %"
                        )
                        .font(.subheadline)
                        Text(copy.native(.readinessHint))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(copy.native(.loadGoalHint))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    NativeEntryHeading(
                        title: copy.native(.findGoal),
                        message: copy.native(.noGoal))
                    NativePrimaryButton(title: copy.explore, symbol: "books.vertical") {
                        navigation.learn = .explore
                    }
                }
            }
            .accessibilityIdentifier("confirmed-learning-goal")
        }

        private func resumeCurrentActivity(_ lesson: Lesson) {
            if selectedTrack != lesson.trackId { resumeTrackID = lesson.trackId }
            selectedTrack = lesson.trackId
            selectedLesson = lesson.id
            columns = .detailOnly
            compactColumn = .detail
        }

        private func showMyLearning() {
            navigation.learn = .myLearning
            model.selectedTab = .learn
            columns = .all
            compactColumn = .sidebar
        }

        private func requestPath(_ track: Track) {
            let requestID = UUID()
            loadingTrackID = track.id
            loadingPathRequestID = requestID
            Task {
                await model.loadPath(track)
                guard loadingPathRequestID == requestID else { return }
                loadingTrackID = nil
                loadingPathRequestID = nil
            }
        }

        private func requestLesson(_ node: PathLesson) {
            let requestID = UUID()
            loadingLessonID = node.id
            loadingLessonRequestID = requestID
            Task {
                await model.loadLesson(node)
                guard loadingLessonRequestID == requestID else { return }
                loadingLessonID = nil
                loadingLessonRequestID = nil
            }
        }

        private var profile: some View {
            NativeReadingPage {
                if let profile = model.profile {
                    NativeEntryHeading(
                        title: profile.displayName,
                        message: copy.myLearning)
                    NativeReadingSection(title: copy.native(.confirmedLearning)) {
                        LabeledContent(copy.native(.confirmedXP), value: "\(profile.xp)")
                        if let goal = profile.activeTrackId {
                            LabeledContent(
                                copy.native(.confirmedGoal),
                                value: model.tracks.first(where: {
                                    $0.id.lowercased() == goal.lowercased()
                                })?.title ?? goal)
                        } else {
                            Text(copy.native(.noGoal))
                        }
                    }
                }
                NativeReadingSection(title: copy.native(.yourAccount)) {
                    NavigationLink {
                        NativeReadingPage {
                            learningInsights
                            rewards
                        }
                        .navigationTitle(copy.native(.skills))
                    } label: {
                        Label(copy.native(.skills), systemImage: "chart.bar")
                            .frame(minHeight: 44)
                    }
                    NavigationLink {
                        progressHistory
                    } label: {
                        Label(copy.progressAndHistory, systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    Divider()
                    NavigationLink {
                        Form {
                            Section(copy.appLanguage) { NativeAppLanguagePicker() }
                            Section(copy.native(.studyPlan)) {
                                Button(copy.native(.studyPlan), systemImage: "calendar") {
                                    showingStudyPlan = true
                                }
                                .disabled(model.profile?.activeTrackId == nil)
                            }
                            NavigationLink(copy[.notifications]) {
                                Form {
                                    if let settings = model.notificationSettings,
                                        let ownerID = model.profile?.id
                                    {
                                        NativeNotificationPreferencesView(
                                            model: model, settings: settings, ownerID: ownerID)
                                    } else {
                                        Text(copy.native(.planNotLoaded))
                                    }
                                    if model.insightFailures.contains("notifications") {
                                        Label(
                                            copy.native(.dataFailure),
                                            systemImage: "exclamationmark.triangle")
                                    }
                                    if let plan = model.notificationPlan {
                                        Section(plan.localDate) {
                                            ForEach(plan.notifications, id: \.dedupeKey) { item in
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text(item.title).font(.headline)
                                                    Text(item.body)
                                                    Text(
                                                        item.scheduledUtc,
                                                        format: .dateTime.year().month().day()
                                                            .hour().minute())
                                                }
                                            }
                                        }
                                    }
                                    Button(copy.native(.refreshData)) {
                                        Task { await model.refreshLearningInsights() }
                                    }
                                    .disabled(model.insightsLoading || model.busy)
                                    if model.insightsLoading { ProgressView(copy.loading) }
                                }
                                .navigationTitle(copy[.notifications])
                            }
                            Section(copy.native(.account)) {
                                NavigationLink(copy.accountDeletion) {
                                    NativeAccountDeletionView(model: model)
                                }
                                Section(copy.native(.accessibility)) {
                                    Text(copy.native(.accessibilityHint))
                                        .foregroundStyle(.secondary)
                                }
                                Section(copy.native(.privacy)) {
                                    Text(copy.native(.privacyHint))
                                    Text(copy.native(.coachPrivacy))
                                        .foregroundStyle(.secondary)
                                }
                                .disabled(model.busy)
                            }
                            Section(connectionSectionTitle) {
                                Text(connectionDescription)
                                Button(
                                    copy[.signOut], systemImage: "person.crop.circle.badge.xmark"
                                ) {
                                    Task { await model.disconnect() }
                                }
                                .disabled(model.busy)
                            }
                        }
                        .navigationTitle(copy.settings)
                    } label: {
                        Label(copy.settings, systemImage: "gearshape")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            }
            .navigationTitle(copy.profile)
        }

        @ViewBuilder private var rewards: some View {
            Text(copy.native(.rewards)).font(.title2.bold())
            if let profile = model.profile {
                LabeledContent(copy.native(.confirmedXP), value: "\(profile.xp)")
                if let level = profile.level {
                    LabeledContent(copy.native(.level), value: "\(level)")
                }
                if let streak = profile.streakDays {
                    LabeledContent(copy.native(.streak), value: "\(streak)")
                }
                if let target = profile.dailyGoalXp, let earned = profile.dailyXpEarned {
                    LabeledContent(copy.native(.dailyGoal), value: "\(earned) / \(target)")
                }
            }
            if let board = model.questBoard {
                Text(copy.native(.quests)).font(.headline)
                Text(board.date).font(.caption).foregroundStyle(.secondary)
                ForEach(board.quests, id: \.id) { quest in
                    LabeledContent(quest.title, value: "\(quest.current) / \(quest.target)")
                    if quest.completed {
                        Label(copy.confirmed, systemImage: "checkmark.circle")
                    }
                }
            }
            if let board = model.achievementBoard {
                Text(copy.native(.achievements)).font(.headline)
                LabeledContent(copy.confirmed, value: "\(board.unlocked) / \(board.total)")
                ForEach(board.achievements, id: \.id) { achievement in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            achievement.name,
                            systemImage: achievement.unlocked ? "checkmark.seal" : "seal"
                        )
                        .font(.headline)
                        Text(achievement.description)
                        Text("\(achievement.progress) / \(achievement.threshold)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text(copy.native(.sourceServer)).font(.caption).foregroundStyle(.secondary)
        }

        private var connectionSectionTitle: String {
            #if DEBUG
                copy.native(.developmentConnection)
            #else
                copy.native(.microsoftAccount)
            #endif
        }

        private var connectionDescription: String {
            #if DEBUG
                copy.native(.testConnectorHint)
            #else
                copy.native(.microsoftConnected)
            #endif
        }

        private var connection: some View {
            NavigationStack {
                Form {
                    Section {
                        NativeEntryHeading(
                            title: copy.native(.connectWorkspace),
                            message:
                                copy.native(.developmentScope)
                        )
                        Text(
                            copy.native(.connectorBoundary)
                        )
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Certigo · \(copy.native(.development))")
                    }
                    .scrollContentBackground(.hidden)
                    .background(NativePrism.canvas)
                    Section(copy.native(.testConnection)) {
                        TextField(copy.native(.apiEndpoint), text: $model.baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityIdentifier("developer-api-url")
                        SecureField(copy.native(.testToken), text: $model.token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .accessibilityIdentifier("developer-access-token")
                        Button(copy.native(.connectTest)) { Task { await model.connect() } }
                            .disabled(model.busy || model.baseURL.isEmpty || model.token.isEmpty)
                    }
                    Section {
                        Text(
                            copy.native(.tokenStorageHint)
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Certigo")
            }
        }

        private var path: some View {
            List(selection: $selectedLesson) {
                pathLearningSections
                if let track = model.tracks.first(where: {
                    $0.id == (selectedTrack ?? model.offlinePack?.trackId ?? model.path?.trackId)
                }) {
                    Section(copy.native(.goalOverview)) {
                        Label(track.code, systemImage: "books.vertical")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(NativePrism.accent(for: track.code))
                        Text(track.title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Text(track.summary)
                        NativeContentLanguageBadges(languages: track.languages ?? [])
                        if let group = NativeTrackAppearance.group(for: track.code) {
                            LabeledContent(
                                copy.native(.codeGroup),
                                value: NativeCatalogFilter.family(for: track.code))
                            LabeledContent(
                                copy.native(.codeCategory), value: group.category.title(copy))
                        }
                        NativePracticeBadge(available: track.learningAvailable)
                        if !track.learningAvailable {
                            Text(copy[.practiceUnavailableNote])
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(copy.native(.catalogFormats))
                        Text(copy.native(.radarLimits))
                            .font(.caption).foregroundStyle(.secondary)
                        if let lesson = model.lesson, lesson.trackId == track.id,
                            let manifest = lesson.publicManifestId
                        {
                            LabeledContent(copy.native(.publicVersion), value: manifest)
                        }
                    }
                    if track.learningAvailable {
                        Section(copy.native(.offlinePack)) {
                            Button(
                                copy.native(.downloadPack), systemImage: "arrow.down.circle"
                            ) {
                                downloadTrack = track
                            }
                            .disabled(model.busy)
                            if let pack = model.offlinePack, pack.trackId == track.id {
                                Text(copy.native(.downloadedBoundary))
                                    .font(.footnote).foregroundStyle(.secondary)
                                ForEach(pack.lessons, id: \.id) { lesson in
                                    NavigationLink(value: lesson.id) {
                                        Label(lesson.title, systemImage: "internaldrive")
                                    }
                                    .disabled(model.busy)
                                }
                            }
                        }
                    }
                }
                savedAnswers
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(NativePrism.canvas)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .navigationTitle(
                model.tracks.first(where: {
                    $0.id == (selectedTrack ?? model.offlinePack?.trackId ?? model.path?.trackId)
                })?.code ?? copy.native(.learningPath)
            )
            .navigationBarTitleDisplayMode(.inline)
        }

        @ViewBuilder private var pathLearningSections: some View {
            if let track = model.tracks.first(where: {
                $0.id == (selectedTrack ?? model.offlinePack?.trackId ?? model.path?.trackId)
            }), track.learningAvailable {
                activeGoalSection(track)
            }
            if let path = model.path,
                selectedTrack == nil || selectedTrack == path.trackId,
                model.tracks.first(where: { $0.id == path.trackId })?.learningAvailable != false
            {
                ForEach(path.units) { unit in
                    Section("\(copy.native(.unit)) · \(unit.title)") {
                        ForEach(unit.lessons) { lesson in
                            NavigationLink(value: lesson.id) {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(lesson.title)
                                            .font(.headline)
                                        Text("\(copy.minutes(lesson.estMinutes))")
                                            .foregroundStyle(
                                                .secondary)
                                        Text(activityStatus(lesson.status))
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text(
                                            "\(lesson.nativeMasteryStage.symbol) \(copy[lesson.nativeMasteryStage.copyKey])"
                                        )
                                        .font(.caption)
                                        if !lesson.canOpen {
                                            Text(copy.native(.lockedHint))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: lesson.canOpen ? "book" : "lock")
                                }
                            }
                            .disabled(
                                !lesson.canOpen || model.busy || loadingLessonID != nil)
                        }
                    }
                }
                Section(copy.native(.learningPlan)) {
                    let coverage = NativePathCoverage(
                        units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                    LabeledContent(
                        copy.native(.activities),
                        value: "\(coverage.completedActivities) / \(coverage.totalActivities)")
                    LabeledContent(
                        copy.native(.remainingActivities),
                        value: "\(coverage.remainingActivities)"
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    Text(copy.native(.activityCoverageHint))
                        .font(.caption).foregroundStyle(.secondary)
                    LabeledContent(
                        copy.native(.readiness), value: "\(path.readinessScore) %")
                    Button(copy.native(.refreshData), systemImage: "arrow.clockwise") {
                        Task { await model.refreshProgress() }
                    }
                    .disabled(model.busy)
                }
                if model.profile?.activeTrackId?.lowercased() == path.trackId.lowercased() {
                    Section(copy.native(.finalAssessment)) {
                        NavigationLink {
                            NativeMockExamView(model: model)
                        } label: {
                            Label(copy[.startFinalAssessment], systemImage: "checkmark.seal")
                        }
                    }
                }
                Section(copy.native(.reviewPractice)) {
                    smartReview
                    if let lesson = model.lesson, lesson.trackId == path.trackId {
                        Button("\(copy.resume) · \(lesson.title)", systemImage: "play.circle") {
                            resumeCurrentActivity(lesson)
                        }
                        .disabled(model.busy)
                    }
                }
            } else if let selectedTrack,
                let track = model.tracks.first(where: { $0.id == selectedTrack })
            {
                if !track.learningAvailable {
                    Section {
                        Text(copy[.practiceUnavailableNote])
                        Button(copy.explore) { navigation.learn = .explore }
                    }
                } else if loadingTrackID == track.id {
                    Section {
                        ProgressView(copy.loading)
                            .frame(maxWidth: .infinity, minHeight: 88)
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            copy.native(.pathUnavailable),
                            systemImage: "wifi.exclamationmark",
                            description: Text(
                                copy.native(.pathRetryHint)
                            )
                        )
                        Button(copy.native(.retryPath), systemImage: "arrow.clockwise") {
                            requestPath(track)
                        }
                        .disabled(model.busy || loadingTrackID != nil)
                    }
                }
            } else {
                ContentUnavailableView(
                    copy.native(.chooseCertification), systemImage: "books.vertical",
                    description: Text(copy.native(.pathServerHint))
                )
            }
        }

        private var progressHistory: some View {
            NativeReadingPage {
                coverageSummary
                NativeReadingSection(title: copy.native(.skills)) {
                    learningInsights
                    rewards
                }
                NativeReadingSection(title: copy.native(.confirmedSessions)) {
                    Text(
                        copy.historyLoaded(
                            count: model.serverHistory.count,
                            hasMore: model.historyNextCursor != nil)
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    Text(
                        copy[.historyEvidenceNote]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if model.historyLoading {
                        ProgressView(copy.loading)
                    }
                    if let error = model.historyError {
                        Label(
                            error.resolved(using: copy),
                            systemImage: model.historyOffline
                                ? "wifi.slash" : "exclamationmark.triangle"
                        )
                        .accessibilityIdentifier("history-error")
                    }
                    if let refreshedAt = model.historyRefreshedAt {
                        Text(
                            "\(copy.native(.lastLoaded)) · \(refreshedAt.formatted(.dateTime.year().month().day().hour().minute().locale(copy.language.locale)))"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        if model.serverHistory.isEmpty && model.historyError == nil {
                            Text(
                                model.historyNextCursor == nil
                                    ? copy[.noHistory]
                                    : copy[.historyPageEmpty]
                            )
                        }
                    } else if !model.historyLoading && model.historyError == nil {
                        Text(copy.native(.unloadedHistory))
                    }
                    if let presentation = model.historyPresentation {
                        ForEach(presentation.confirmed) { item in
                            NativeReadingCard {
                                Label(copy.confirmed, systemImage: "checkmark.seal")
                                    .font(.subheadline).foregroundStyle(NativePrism.confirmed)
                                Text(lessonTitle(item.lessonId)).font(.headline)
                                Text(trackTitle(item.trackId)).foregroundStyle(.secondary)
                                Text(
                                    item.submittedAt,
                                    format: .dateTime.year().month().day().hour().minute())
                                Text(
                                    copy.historyScore(
                                        scorePercent: item.scorePct, xp: item.xpEarned,
                                        confirmedOnDevice: false)
                                )
                                Text(
                                    copy[.historyCorrectionNote]
                                )
                                .font(.caption).foregroundStyle(.secondary)
                                if let saved = model.localHistorySubmission(for: item),
                                    saved.status == .pendingCorrection && saved.result == nil
                                {
                                    Button(copy.native(.retrieveCorrection)) {
                                        Task { await model.retry(saved) }
                                    }
                                    .frame(minHeight: 44)
                                    .disabled(model.busy)
                                }
                            }
                        }
                    }
                    Button(copy.native(.refreshHistory), systemImage: "arrow.clockwise") {
                        Task { await model.refreshHistory() }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.historyLoading)
                    if model.historyNeedsSignIn && model.canReconnectHistory {
                        Button(copy.native(.signInAgain), systemImage: "person.crop.circle") {
                            Task { await model.reconnectHistory() }
                        }
                        .frame(minHeight: 44)
                        .disabled(model.busy || model.historyLoading)
                    }
                    if model.historyNextCursor != nil {
                        Button(copy.native(.loadMore), systemImage: "chevron.down") {
                            Task { await model.loadMoreHistory() }
                        }
                        .frame(minHeight: 44)
                        .disabled(model.historyLoading)
                    }
                }
                NativeReadingSection(title: copy.native(.localDevice)) {
                    Text(
                        copy[.historyLocalDatesNote]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if let presentation = model.historyPresentation {
                        ForEach(presentation.confirmedOnDevice) { saved in
                            NativeReadingCard {
                                Label(copy.confirmed, systemImage: "checkmark.circle")
                                    .foregroundStyle(NativePrism.confirmed)
                                Text(lessonTitle(saved.lessonId)).font(.headline)
                                Text(
                                    saved.submission.startedAt,
                                    format: .dateTime.year().month().day())
                                if let result = saved.result {
                                    Text(
                                        copy.historyScore(
                                            scorePercent: result.scorePct,
                                            xp: result.rewards.xpEarned, confirmedOnDevice: true)
                                    )
                                }
                                Text(
                                    copy[.historyLocalAcknowledgement]
                                )
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        ForEach(presentation.onDevice) { saved in
                            savedAnswer(saved)
                        }
                        if presentation.onDevice.isEmpty && presentation.confirmedOnDevice.isEmpty {
                            Text(copy[.historyNoAdditional])
                        }
                    } else if model.historyError != nil {
                        Text(
                            copy[.historyLocalUnverified]
                        )
                    }
                    if model.lesson != nil {
                        Label(
                            model.outcome == nil
                                ? copy[.historyCurrentLocal] : copy[.historyCurrentSubmitted],
                            systemImage: "doc.text")
                        Button(copy.resume, systemImage: "play.circle") {
                            model.selectedTab = .learn
                            columns = .detailOnly
                            compactColumn = .detail
                        }
                        .frame(minHeight: 44)
                    }
                }
                NativeReadingSection(title: copy.native(.readiness)) {
                    if let profile = model.profile {
                        LabeledContent(copy.native(.confirmedXP), value: "\(profile.xp)")
                    }
                    if let path = model.path {
                        Text(path.trackName)
                        LabeledContent(copy.native(.readiness), value: "\(path.readinessScore) %")
                    }
                    Text(
                        copy[.historyNoBalanceChange]
                    )
                    Text(
                        copy[.historyReadinessNote]
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    if model.path == nil {
                        Text(
                            copy[.historyReadinessUnknown]
                        )
                    }
                }
            }
            .navigationTitle(copy.progressAndHistory)
            .task {
                if !model.historyAttempted { await model.refreshHistory() }
            }
        }

        private var coverageSummary: some View {
            NativeReadingSection(title: copy.native(.activityCoverage)) {
                if let path = model.path {
                    let coverage = NativePathCoverage(
                        units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                    Text(path.trackName).font(.headline)
                    LabeledContent(
                        copy.native(.completedActivities),
                        value: copy.coverageCount(
                            completed: coverage.completedActivities, total: coverage.totalActivities
                        ))
                    LabeledContent(
                        copy.native(.completedUnits),
                        value: copy.coverageCount(
                            completed: coverage.completedUnits, total: coverage.totalUnits))
                    Text(
                        copy[.historyCoverageSnapshot]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(
                        copy[.historyCoverageUnknown]
                    )
                }
                if let lesson = model.lesson {
                    let selectedCount = lesson.questions.filter {
                        model.selections[$0.id] != nil
                    }.count
                    Text(lesson.title).font(.headline)
                    LabeledContent(
                        copy.native(.localAnswers),
                        value: copy.questionCount(
                            selected: selectedCount, total: lesson.questions.count))
                    Text(
                        copy[.historySelectionNote]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                Text(
                    copy[.historyGoalUnchanged]
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }

        private func activityStatus(_ status: NodeStatus) -> String {
            switch status {
            case .locked: copy.native(.lockedActivity)
            case .available: copy.native(.availableActivity)
            case .inProgress: copy[.masteryLearning]
            case .completed: copy.native(.completedActivity)
            case .mastered: copy[.masteryMastered]
            }
        }

        @ViewBuilder private var savedAnswers: some View {
            if !model.queue.isEmpty {
                Section(copy[.historySavedAnswers]) {
                    ForEach(model.queue) { saved in
                        savedAnswer(saved)
                    }
                }
            }
        }

        private func savedAnswer(_ saved: SavedSubmission) -> some View {
            NativeReadingCard {
                Text(lessonTitle(saved.lessonId)).font(.headline)
                switch saved.status {
                case .pendingCorrection:
                    Label(copy[.pendingCorrection], systemImage: "clock")
                        .foregroundStyle(NativePrism.pending)
                    Button(copy.retry) {
                        Task { await model.retry(saved) }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.busy)
                case .corrected:
                    if let result = saved.result {
                        Text(copy.confirmedScore(result.scorePct))
                        ForEach(result.results) { item in
                            Text(item.explanation)
                        }
                    }
                case .failed:
                    Label(
                        copy[.historySubmissionRejected],
                        systemImage: "exclamationmark.triangle")
                    Text(
                        copy[.historyLocalStatusNote]
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        private func trackTitle(_ id: String) -> String {
            model.tracks.first(where: { $0.id.lowercased() == id.lowercased() })?.title ?? id
        }

        private func lessonTitle(_ id: String) -> String {
            if let lesson = model.lesson, lesson.id == id { return lesson.title }
            if let lesson = model.path?.units.flatMap(\.lessons).first(where: { $0.id == id }) {
                return lesson.title
            }
            return model.offlinePack?.lessons.first(where: { $0.id == id })?.title ?? id
        }

        @ViewBuilder private func activeGoalSection(_ track: Track) -> some View {
            let state = NativeActiveGoalPresentation(
                targetID: track.id, confirmedID: model.profile?.activeTrackId,
                savingID: savingGoalID, busy: model.busy)
            Section(copy.native(.activeGoal)) {
                Label(state.status(copy), systemImage: state.symbol)
                    .accessibilityIdentifier("active-goal-status")
                if let current = model.profile?.activeTrackId,
                    current.lowercased() != track.id.lowercased()
                {
                    Text(
                        "\(copy.native(.goalConfirmed)) · \(model.tracks.first(where: { $0.id == current })?.title ?? current)"
                    )
                    .foregroundStyle(.secondary)
                }
                if model.profile?.activeTrackId?.lowercased() == track.id.lowercased() {
                    NativePrimaryButton(title: copy.myLearning, symbol: "book") {
                        showMyLearning()
                    }
                    .disabled(model.busy)
                    .accessibilityIdentifier("open-confirmed-learning-goal")
                } else {
                    NativePrimaryButton(title: state.action(copy), symbol: "scope") {
                        savingGoalID = track.id
                        Task {
                            await model.chooseActiveTrack(track)
                            savingGoalID = nil
                        }
                    }
                    .frame(minHeight: 44)
                    .disabled(!state.canChoose)
                    .accessibilityIdentifier("choose-active-goal")
                }
            }
        }

        private var session: some View {
            Group {
                if let track = model.tracks.first(where: {
                    $0.id == (selectedTrack ?? model.lesson?.trackId)
                }), !track.learningAvailable {
                    ContentUnavailableView(
                        copy[.practiceUnavailable], systemImage: "book.closed",
                        description: Text(copy[.practiceUnavailableNote])
                    )
                } else if let lesson = model.lesson,
                    selectedTrack == nil || selectedTrack == lesson.trackId,
                    selectedLesson == nil || selectedLesson == lesson.id
                {
                    ScrollViewReader { reader in
                        NativeReadingPage {
                            Text(lesson.title).font(.title).bold()
                                .accessibilityAddTraits(.isHeader)
                                .id("session-reading-start")
                            learningCycle
                            if let node = model.path?.units.flatMap(\.lessons).first(where: {
                                $0.id == lesson.id
                            }) {
                                LabeledContent(
                                    copy.native(.duration),
                                    value: "\(copy.minutes(node.estMinutes))")
                            }
                            Label(copy.native(.understandStage), systemImage: "text.book.closed")
                                .font(.subheadline).foregroundStyle(NativePrism.tint)
                            DisclosureGroup(copy.native(.readAloud)) {
                                NativeLessonAudioControls(
                                    content: NativeLessonReadingContent(
                                        lessonTitle: lesson.title,
                                        blocks: lesson.blocks.map {
                                            (type: $0.type, title: $0.title, body: $0.body)
                                        }),
                                    ownerID: model.profile?.id
                                )
                                .id(lesson.id)
                            }
                            .frame(minHeight: 44)
                            Text(
                                copy.native(.answerInstruction)
                            )
                            .foregroundStyle(.secondary)
                            ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { _, block in
                                if let title = block.title {
                                    Text(title).font(.headline)
                                        .accessibilityAddTraits(.isHeader)
                                }
                                if let body = block.body {
                                    Text(.init(body)).textSelection(.enabled)
                                }
                                if let code = block.code {
                                    ScrollView(.horizontal) {
                                        Text(code).font(.body.monospaced()).textSelection(.enabled)
                                    }
                                    .padding(16)
                                    .background(
                                        NativePrism.surface,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                if let question = block.check {
                                    questionView(question)
                                }
                            }
                            if let outcome = model.outcome {
                                switch outcome {
                                case .pendingCorrection:
                                    NativeReadingCard {
                                        Label(
                                            copy[.pendingCorrection],
                                            systemImage: "clock"
                                        )
                                        .font(.headline).foregroundStyle(NativePrism.pending)
                                        Text(
                                            copy.native(.pendingCorrectionHint)
                                        )
                                        .foregroundStyle(.secondary)
                                    }
                                    .accessibilityIdentifier("pending-correction")
                                case .corrected(let result):
                                    NativeReadingSection(title: copy.native(.confirmedResult)) {
                                        Label(
                                            copy.confirmed, systemImage: "checkmark.seal"
                                        )
                                        .foregroundStyle(NativePrism.confirmed)
                                        LabeledContent(
                                            copy.native(.score), value: "\(result.scorePct) %")
                                        LabeledContent(
                                            copy.native(.earned),
                                            value: "\(result.rewards.xpEarned)")
                                        if let reviewDate = result.nextReviewDueAt {
                                            LabeledContent(
                                                copy.native(.nextReview),
                                                value: reviewDate.formatted(
                                                    date: .abbreviated, time: .shortened))
                                        }
                                    }
                                    ForEach(result.results) { item in
                                        NativeReadingCard {
                                            Label(
                                                item.correct
                                                    ? copy.native(.answerCorrect)
                                                    : copy.native(.reviewNeeded),
                                                systemImage: item.correct
                                                    ? "checkmark.circle" : "book"
                                            )
                                            .font(.headline)
                                            .foregroundStyle(
                                                item.correct
                                                    ? NativePrism.confirmed : NativePrism.pending)
                                            if let question = lesson.blocks.compactMap(\.check)
                                                .first(where: { $0.id == item.itemId })
                                            {
                                                Text(.init(question.stem)).font(.headline)
                                            }
                                            Text(.init(item.explanation)).textSelection(.enabled)
                                            if let question = lesson.questions.first(where: {
                                                $0.id == item.itemId
                                            }), let selected = model.selections[item.itemId],
                                                let option = question.options.first(where: {
                                                    $0.id == selected
                                                })
                                            {
                                                LabeledContent(
                                                    copy.native(.selectedAnswer),
                                                    value: option.label)
                                                if let correct = item.correctAnswer {
                                                    Text(
                                                        "\(copy.native(.correctAnswer)) · "
                                                            + question.options.filter {
                                                                correct.contains($0.id)
                                                            }.map(\.label).joined(separator: " · "))
                                                }
                                            }
                                            LabeledContent(
                                                copy.native(.masteryChange),
                                                value: item.masteryDelta.formatted(
                                                    .number.precision(.fractionLength(0...3))
                                                        .locale(copy.language.locale)))
                                            tutorContent(for: item.itemId)
                                        }
                                    }
                                    NativeReadingSection(title: copy[.continueLearning]) {
                                        Button(
                                            copy.native(.readAgain), systemImage: "text.book.closed"
                                        ) {
                                            reader.scrollTo("session-reading-start", anchor: .top)
                                        }
                                        .frame(minHeight: 44)
                                        .accessibilityIdentifier("read-confirmed-lesson-again")
                                        if let node = model.path?.units.flatMap(\.lessons).first(
                                            where: {
                                                $0.id == lesson.id && $0.canOpen
                                            }), model.path?.trackId == lesson.trackId
                                        {
                                            let destination = NativeActivityDestination(
                                                lessonID: lesson.id, title: lesson.title)
                                            NativePrimaryButton(
                                                title: destination.actionTitle(copy.practiceAgain),
                                                symbol: "arrow.clockwise"
                                            ) {
                                                requestLesson(node)
                                            }
                                            .disabled(model.busy || loadingLessonID != nil)
                                            Text(
                                                copy.native(.newAttemptHint)
                                            )
                                            .font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Text(
                                                copy.native(.practiceAgainHint)
                                            )
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } else {
                                NativePrimaryButton(
                                    title: copy.submitAnswer, symbol: "paperplane"
                                ) {
                                    Task { await model.submit() }
                                }
                                .disabled(!model.canSubmit)
                                .accessibilityIdentifier("submit-for-correction")
                            }
                        }
                    }
                } else if let selectedLesson,
                    let node = model.path?.units.flatMap(\.lessons).first(where: {
                        $0.id == selectedLesson
                    })
                {
                    if loadingLessonID == node.id {
                        ProgressView(copy.loading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 16) {
                            ContentUnavailableView(
                                copy.native(.lessonUnavailable),
                                systemImage: "wifi.exclamationmark",
                                description: Text(
                                    copy.native(.lessonLoadFailure)
                                )
                            )
                            Button(copy.retry, systemImage: "arrow.clockwise") {
                                requestLesson(node)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.busy || loadingLessonID != nil)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ContentUnavailableView(
                        copy.native(.oneSession), systemImage: "book",
                        description: Text(copy.native(.chooseActivity))
                    )
                }
            }
            .navigationTitle(copy.startSession)
        }

        private var learningCycle: some View {
            let phases: [AppInterfaceCopy.NativeLabel] = [
                .learnStage, .understandStage, .recallApplyStage, .feedbackStage, .masterStage,
            ]
            let active = model.outcome == nil ? 2 : 3
            return ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                        Text(copy.native(phase))
                            .font(.subheadline.weight(index == active ? .semibold : .regular))
                            .foregroundStyle(index == active ? NativePrism.tint : .secondary)
                            .accessibilityAddTraits(index == active ? .isSelected : [])
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }

        private func questionView(_ question: QuizItem) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(copy.native(.questionType)) · \(copy.native(.multipleChoice))")
                    .font(.caption).foregroundStyle(.secondary)
                Text(.init(question.stem)).font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(question.options) { option in
                    Button {
                        model.select(option, question: question)
                    } label: {
                        Label(
                            option.label,
                            systemImage: model.selections[question.id] == option.id
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NativeChoiceButtonStyle())
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                model.selections[question.id] == option.id
                                    ? NativePrism.tint : NativePrism.edge,
                                lineWidth: model.selections[question.id] == option.id ? 2 : 1)
                    }
                    .disabled(model.outcome != nil || model.busy)
                    .accessibilityAddTraits(
                        model.selections[question.id] == option.id ? .isSelected : []
                    )
                    .accessibilityValue(
                        model.selections[question.id] == option.id
                            ? copy.native(.selected) : copy.native(.notSelected))
                }
            }
            .onAppear { model.questionAppeared(question.id) }
        }
    }

    @MainActor
    struct NativeLessonAudioControls: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.scenePhase) private var scenePhase
        @State private var speech = NativeLessonSpeech()
        let content: NativeLessonReadingContent
        let ownerID: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(copy[.audioReadAloud]).font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    copy[.audioScopeNote]
                )
                .font(.subheadline).foregroundStyle(.secondary)
                Picker(copy[.audioVoice], selection: $speech.voiceID) {
                    Text(copy[.audioChooseVoice]).tag("")
                    ForEach(speech.voices, id: \.identifier) { voice in
                        Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                    }
                }
                .disabled(speech.state != .idle)
                if speech.voices.isEmpty {
                    Text(copy[.audioNoVoices])
                }
                Picker(copy[.audioSpeed], selection: $speech.rate) {
                    Text(copy[.audioSlower]).tag(AVSpeechUtteranceDefaultSpeechRate * 0.8)
                    Text(copy[.audioStandard]).tag(AVSpeechUtteranceDefaultSpeechRate)
                }
                .disabled(speech.state != .idle)
                Text(speech.state.label(copy)).font(.subheadline)
                    .accessibilityIdentifier("lesson-audio-state")
                ViewThatFits(in: .horizontal) {
                    HStack { playbackButtons }
                    VStack(alignment: .leading) { playbackButtons }
                }
                if let issue = speech.issue {
                    Text(copy[issue]).foregroundStyle(.primary)
                        .accessibilityIdentifier("lesson-audio-error")
                }
            }
            .onDisappear { speech.stop() }
            .onChange(of: content) { _, _ in speech.stop() }
            .onChange(of: ownerID) { _, _ in speech.reset() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { speech.stop() }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIAccessibility.voiceOverStatusDidChangeNotification)
            ) { _ in
                if UIAccessibility.isVoiceOverRunning { speech.stop() }
            }
        }

        @ViewBuilder private var playbackButtons: some View {
            switch speech.state {
            case .idle:
                Button(copy[.audioRead], systemImage: "speaker.wave.2") {
                    speech.read(content)
                }
                .frame(minHeight: 44)
            case .reading:
                Button(copy[.audioPause], systemImage: "pause") { speech.pause() }
                    .frame(minHeight: 44)
            case .paused:
                Button(copy[.audioResume], systemImage: "play") { speech.resume() }
                    .frame(minHeight: 44)
            }
            if speech.state != .idle {
                Button(copy[.audioStop], systemImage: "stop") { speech.stop() }
                    .frame(minHeight: 44)
            }
        }
    }

    @MainActor
    @Observable
    private final class NativeLessonSpeech: NSObject, AVSpeechSynthesizerDelegate {
        enum State {
            case idle, reading, paused

            func label(_ copy: AppInterfaceCopy) -> String {
                switch self {
                case .idle: copy[.audioStopped]
                case .reading: copy[.audioReading]
                case .paused: copy[.audioPaused]
                }
            }
        }

        let voices = AVSpeechSynthesisVoice.speechVoices().sorted {
            ($0.language, $0.name, $0.identifier) < ($1.language, $1.name, $1.identifier)
        }
        var voiceID = ""
        var rate = AVSpeechUtteranceDefaultSpeechRate
        private(set) var state = State.idle
        private(set) var issue: AppInterfaceCopy.Key?
        private let synthesizer = AVSpeechSynthesizer()
        private var utteranceID: ObjectIdentifier?

        override init() {
            super.init()
            synthesizer.delegate = self
            synthesizer.usesApplicationAudioSession = false
        }

        func read(_ content: NativeLessonReadingContent) {
            guard state == .idle else { return }
            issue = nil
            guard !voices.isEmpty else {
                issue = .audioNoVoices
                return
            }
            guard !UIAccessibility.isVoiceOverRunning else {
                issue = .audioVoiceOverRead
                return
            }
            guard !voiceID.isEmpty else {
                issue = .audioChooseVoiceFirst
                return
            }
            guard let voice = AVSpeechSynthesisVoice(identifier: voiceID) else {
                issue = .audioVoiceUnavailable
                return
            }
            let text: String
            do {
                text = try content.spokenText(
                    renderingMarkdown: NativeLessonReadingContent.plainText)
            } catch {
                issue = .audioPreparationFailed
                return
            }
            guard !text.isEmpty else {
                issue = .audioNoText
                return
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = rate
            utteranceID = ObjectIdentifier(utterance)
            state = .reading
            synthesizer.speak(utterance)
        }

        func pause() {
            guard state == .reading else { return }
            if synthesizer.pauseSpeaking(at: .immediate) {
                state = .paused
            } else {
                issue = .audioPauseFailed
            }
        }

        func resume() {
            guard state == .paused else { return }
            guard !UIAccessibility.isVoiceOverRunning else {
                stop()
                issue = .audioVoiceOverResume
                return
            }
            if synthesizer.continueSpeaking() {
                state = .reading
            } else {
                issue = .audioResumeFailed
            }
        }

        func stop() {
            utteranceID = nil
            synthesizer.stopSpeaking(at: .immediate)
            state = .idle
            issue = nil
        }

        func reset() {
            stop()
            voiceID = ""
            rate = AVSpeechUtteranceDefaultSpeechRate
        }

        nonisolated func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
        ) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor [weak self] in self?.finished(id) }
        }

        nonisolated func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
        ) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor [weak self] in self?.finished(id) }
        }

        private func finished(_ id: ObjectIdentifier) {
            guard utteranceID == id else { return }
            utteranceID = nil
            state = .idle
        }
    }
#endif

struct NativeLessonReadingContent: Equatable {
    enum Part: Equatable {
        case title(String)
        case text(String)
        case markdown(String)
    }

    let parts: [Part]

    init(lessonTitle: String, blocks: [(type: String, title: String?, body: String?)]) {
        let readableTypes: Set<String> = ["hook", "concept", "example", "recap"]
        var parts: [Part] = [.title(lessonTitle)]
        for block in blocks where readableTypes.contains(block.type) {
            if let title = block.title { parts.append(.title(title)) }
            if let body = block.body { parts.append(.markdown(body)) }
        }
        self.parts = parts
    }

    init(
        editorialTitle: String,
        objective: String,
        hook: String,
        keyIdeas: [String],
        exampleSituation: String,
        exampleSteps: [String],
        exampleDecision: String,
        recap: String
    ) {
        var parts: [Part] = [
            .title(editorialTitle),
            .text(objective),
            .text(hook),
            .title("Idées clés"),
        ]
        parts.append(contentsOf: keyIdeas.map(Part.text))
        parts.append(.title("Exemple résolu"))
        parts.append(.text(exampleSituation))
        parts.append(
            contentsOf: exampleSteps.enumerated().map {
                .text("\($0.offset + 1). \($0.element)")
            })
        parts.append(.text(exampleDecision))
        parts.append(.title("À retenir"))
        parts.append(.text(recap))
        self.parts = parts
    }

    func spokenText(renderingMarkdown: (String) throws -> String) throws -> String {
        try parts.map { part in
            let text: String
            switch part {
            case .title(let title): text = title
            case .text(let value): text = value
            case .markdown(let body): text = try renderingMarkdown(body)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    #if canImport(Darwin)
        static func plainText(_ markdown: String) throws -> String {
            // Match Text's inline Markdown while preserving paragraph whitespace.
            let value = try AttributedString(
                markdown: markdown,
                options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .throwError))
            return String(value.characters)
        }
    #endif
}

struct NativeActiveGoalPresentation {
    let targetID: String
    let confirmedID: String?
    let savingID: String?
    let busy: Bool

    var isConfirmed: Bool {
        confirmedID?.lowercased()
            == targetID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isSaving: Bool { savingID == targetID }
    var canChoose: Bool { !busy && savingID == nil && !isConfirmed }
    #if canImport(CertigoDomain)
        func status(_ copy: AppInterfaceCopy) -> String {
            if isSaving { return copy.native(.goalPending) }
            return isConfirmed ? copy.native(.goalConfirmed) : copy.native(.goalViewing)
        }
    #endif
    var symbol: String { isSaving ? "clock" : isConfirmed ? "checkmark.circle" : "eye" }
    #if canImport(CertigoDomain)
        func action(_ copy: AppInterfaceCopy) -> String {
            isSaving ? copy.native(.savingGoal) : copy.native(.chooseGoal)
        }
    #endif
}

struct NativeLearningNavigation {
    enum Tab: String, CaseIterable { case learn, coach, social, profile }
    enum Learn { case myLearning, explore }
    enum Social { case friends, teams }
    var tab: Tab = .learn
    var learn: Learn
    var social: Social = .friends

    init(hasGoal: Bool = false) {
        learn = hasGoal ? .myLearning : .explore
    }

    func showsTrack(_ id: String, activeID: String?, openedID: String?) -> Bool {
        learn == .explore || id.lowercased() == activeID?.lowercased() || id == openedID
    }
}
