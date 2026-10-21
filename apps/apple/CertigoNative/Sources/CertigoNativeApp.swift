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

    extension AppInterfaceCopy {
        enum NativeLabel: CaseIterable {
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
                    "Relire", "Read again", "फिर पढ़ें", "再次阅读", "다시 읽기", "Volver a leer", "Rileggi",
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
                row = ["Score", "Score", "स्कोर", "得分", "점수", "Puntuación", "Punteggio", "Punktzahl"]
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
                            "\(copy.native(.duration)) · \(minutes) min",
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
                        title: "One question. A clearer idea.",
                        message: "Explore Certigo’s native learning preview.", prominent: true)
                    NativeAppLanguagePicker()
                    NativeReadingSection(title: "Try the learning experience") {
                        NativePrimaryButton(title: copy.exploreDemo, symbol: "play.circle") {
                            showDemo = true
                        }
                        .accessibilityIdentifier("open-native-demo")
                        Text(
                            "Goals, answers and explanations are fictional. No account, network or real result is used."
                        )
                        .foregroundStyle(.secondary)
                    }
                    #if DEBUG
                        if let pendingLessonLink {
                            NativeReadingSection(title: "Shared lesson link") {
                                Text(
                                    "Non-certifying editorial pilot · \(pendingLessonLink.lessonID)"
                                )
                                Button("Continue to linked lesson", systemImage: "book") {
                                    showDeveloper = true
                                }
                                .accessibilityIdentifier("continue-to-linked-lesson")
                            }
                        }
                        NativeReadingSection(title: "Development") {
                            Button(
                                "Open the test API connector",
                                systemImage: "wrench.and.screwdriver"
                            ) {
                                showDeveloper = true
                            }
                            .frame(minHeight: 44)
                            Text(
                                "For test accounts only. This is not production sign-in."
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
                    }
                #endif
            }
            .onOpenURL(perform: handleIncomingURL)
            .alert("Lesson link unavailable", isPresented: $invalidLessonLink) {
                Button("OK", role: .cancel) { invalidLessonLink = false }
            } message: {
                Text("This link does not identify a supported editorial pilot lesson.")
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
            @State private var configurationIssue: String?
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
                                "Microsoft sign-in is not configured",
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text(configurationIssue))
                        }
                    } else if model.profile == nil && model.deletionStage == nil {
                        NavigationStack {
                            NativeReadingPage {
                                NativeEntryHeading(
                                    title: "Make your next decision clearer.",
                                    message:
                                        "Your learning goals, practice and confirmed progress, together in Certigo."
                                )
                                NativeAppLanguagePicker()
                                NativeReadingSection(title: "Continue your learning") {
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
                                "Microsoft sign-in did not complete",
                                isPresented: Binding(
                                    get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } }
                                )
                            ) {
                                Button("OK", role: .cancel) { model.errorMessage = nil }
                            } message: {
                                Text(model.errorMessage ?? "")
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

            private static func safeMessage(for error: Error) -> String {
                switch error {
                case CIAMConfigurationEnvironmentError.productionBuildRequired:
                    "Microsoft sign-in is only enabled for the Distribution build."
                case CIAMConfigurationEnvironmentError.unsupportedProductionBundle:
                    "Use the existing Certigo App Store bundle identifier."
                case CIAMConfigurationEnvironmentError.missingValue(let key):
                    "Distribution is missing \(key). Configure the verified production identity before sign-in."
                case CIAMConfigurationEnvironmentError.invalidValue(let key):
                    "Distribution has an invalid \(key). Correct the verified production configuration."
                case CIAMConfigurationEnvironmentError.callbackNotDeclared:
                    "Declare the app-derived Microsoft callback in the Distribution Info.plist."
                case CIAMConfigurationEnvironmentError.callbackCollision:
                    "The Microsoft callback is duplicated in the Distribution Info.plist."
                case CIAMConfigurationEnvironmentError.redirectDoesNotMatchBundle:
                    "The Microsoft callback must match this app's bundle identifier."
                case is CIAMConfigurationEnvironmentError:
                    "Correct the Distribution Microsoft sign-in configuration."
                case is CIAMConfigurationError:
                    "The Distribution Microsoft sign-in configuration failed validation."
                default:
                    "Microsoft sign-in could not be initialized. No manual-token fallback is available."
                }
            }
        }
    #endif

    #if DEBUG
        @MainActor
        private struct NativeDeveloperConnector: View {
            @Environment(\.dismiss) private var dismiss
            @Binding private var pendingLessonLink: EditorialPilotLessonLink?
            @State private var model: NativeModel
            @State private var usesCIAM: Bool
            @State private var ciamProvider: MSALAuthenticationProvider?
            @State private var configurationIssue: String?

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
                            "CIAM test sign-in is unavailable",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text(configurationIssue)
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
                        Text("Developer connector").font(.subheadline)
                        Spacer()
                        Button("Close") { dismiss() }
                    }
                    .padding()
                    .background(.background)
                }
            }

            private var ciamSignIn: some View {
                NavigationStack {
                    NativeReadingPage {
                        NativeEntryHeading(
                            title: "Test your connected learning.",
                            message: "CIAM development configuration · test accounts only.")
                        NativeReadingSection(title: "CIAM test sign-in") {
                            Text("Sign in explicitly with the locally configured test identity.")
                            NativePrimaryButton(
                                title: "Sign in with CIAM", symbol: "person.crop.circle"
                            ) {
                                Task { await model.connect() }
                            }
                            .disabled(model.busy)
                        }
                    }
                    .navigationTitle("Certigo")
                    .alert(
                        "CIAM sign-in did not complete",
                        isPresented: Binding(
                            get: { model.errorMessage != nil },
                            set: { if !$0 { model.errorMessage = nil } }
                        )
                    ) {
                        Button("OK", role: .cancel) { model.errorMessage = nil }
                    } message: {
                        Text(model.errorMessage ?? "")
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

            private static func safeConfigurationMessage(for error: Error) -> String {
                if let error = error as? CIAMConfigurationEnvironmentError {
                    return error.localizedDescription
                }
                if let error = error as? CIAMConfigurationError {
                    switch error {
                    case .invalidIdentity:
                        return
                            "Set valid client, tenant, and API audience identifiers in the local Xcode scheme."
                    case .invalidAuthority:
                        return "Correct the CIAM authority in the local Xcode scheme."
                    case .issuerMismatch:
                        return "Set the issuer matching the configured CIAM tenant and authority."
                    case .invalidAPIScope:
                        return
                            "Set one API scope for the configured audience in the local Xcode scheme."
                    case .invalidAPIURL:
                        return "Set the existing API HTTPS base URL, including its /api path."
                    case .invalidRedirect, .redirectNotRegistered:
                        return "Set the exact CIAM redirect registered for this app."
                    case .callbackNotDeclared:
                        return
                            "The callback scheme must already be declared in this app's Info.plist."
                    case .callbackCollision:
                        return "The CIAM callback scheme collides with another app callback scheme."
                    }
                }
                return
                    "Review the local Xcode scheme and registered app callback. Manual token sign-in is disabled while CIAM is opted in."
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
        @State private var issue: String?
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
                            "Coach is not connected in this preview. No AI response, conversation history or saved memory is created."
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
                        Section("Catalog states · simulation") {
                            Picker("Catalog", selection: $scenario) {
                                ForEach(DemoCatalogScenario.allCases, id: \.self) {
                                    Text($0.rawValue)
                                }
                            }
                            Toggle("Simulate offline mode", isOn: $offline)
                        }
                        Section {
                            Text(
                                "These settings do not change the device network or a server."
                            )
                        }
                    }
                    .navigationTitle("Demo settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(copy[.done]) { showScenarios = false }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear only the saved demonstration?", isPresented: $showReset
            ) {
                Button("Reset the demo", role: .destructive) {
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
            .alert("Demo restoration unavailable", isPresented: issuePresented) {
                Button(copy[.done], role: .cancel) { issue = nil }
            } message: {
                Text(issue ?? "")
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
                        "The saved demonstration cannot be read. Reset only the demo in its settings."
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
                        "\(title) is not connected", systemImage: symbol,
                        description: Text(description))
                    Text(
                        "This is a navigation preview, not a working \(title.lowercased()) service."
                    )
                    .foregroundStyle(.secondary)
                    DemoPrimaryButton(title: "Return to Learn", symbol: "book") {
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
                        "\(socialSection == .friends ? copy.friends : copy.teams) · not connected",
                        systemImage: socialSection == .friends ? "person.2" : "person.3",
                        description: Text(
                            "Social is unavailable in this navigation preview. No real relationships, invitations, team membership or sharing are loaded."
                        ))
                    DemoPrimaryButton(title: "Return to Learn", symbol: "book") {
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
                    "The demonstration could not be saved. You can continue in the current session."
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
                    "The question cannot be reopened. Choose a goal in Learn > Explore."
            }
        }

        private var objective: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    learnSelector
                    if let goal = flow.objective {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(goal.displayName).font(.largeTitle.bold())
                            Text(goal.displayTitle).font(.title2.weight(.semibold))
                            Text(flow.activitySummary)
                                .font(.subheadline)
                            NavigationLink(value: flow.startRoute) {
                                Label(flow.startLabel, systemImage: "arrow.right.circle.fill")
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
                            Text("The decision workshop").font(.title2.bold())
                            Text(goal.practice.intent)
                            Text(
                                "Read a situation, make a choice, understand the explanation."
                            )
                            .foregroundStyle(.secondary)
                            Label(
                                "Fictional content · not a published course",
                                systemImage: "text.book.closed"
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Divider()
                        Button("Switch goal", systemImage: "square.grid.2x2") {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                        Button("View demo history", systemImage: "clock.arrow.circlepath") {
                            tab = .followUp
                        }
                        .frame(minHeight: 44)
                    } else {
                        ContentUnavailableView(
                            "Your next learning goal",
                            systemImage: "scope",
                            description: Text(
                                "Explore two fictional situations. No account or real result is needed."
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
                                "Choose a demo goal to begin. These French examples are fictional, not published courses."
                            )
                        }
                    }
                    Section("Demonstration workshops") {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            NavigationLink(value: NativeDemoRoute.goalDetail(goal)) {
                                HStack(spacing: 16) {
                                    Image(systemName: goal.symbol).font(.title2)
                                        .foregroundStyle(NativePrism.tint)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.displayName).font(.headline)
                                        Text(goal.displayTitle).foregroundStyle(.secondary)
                                        Text(goal.practice.intent).font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("1 fictional situation · 1 question · French")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if flow.objective == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NativePrism.tint)
                                            .accessibilityLabel("Selected goal")
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
                                Text(goal.displayTitle).font(.headline)
                                Text("A situation to explore").font(.subheadline)
                            }
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                        }
                        Label("\(copy.loading) · \(copy[.demo])", systemImage: "hourglass")
                            .accessibilityIdentifier("demo-catalog-loading")
                        Button("Finish simulated loading") { scenario = .ready }
                    }
                case .empty:
                    Section {
                        ContentUnavailableView(
                            "No goals in this example", systemImage: "books.vertical",
                            description: Text("The empty catalog is a demonstration scenario.")
                        )
                        Button("Show demo goals") { scenario = .ready }
                    }
                case .error:
                    Section {
                        ContentUnavailableView(
                            "Catalog unavailable · simulation",
                            systemImage: "wifi.exclamationmark",
                            description: Text(
                                "Your demo state is preserved. No server is contacted."))
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
                    Text(goal.displayName).font(.largeTitle.bold()).foregroundStyle(
                        NativePrism.tint)
                    Text(goal.displayTitle).font(.title2.bold())
                    Text(
                        "A short scenario to explore the native experience. This is not a published catalog."
                    )
                    DemoReadingSection(title: "The decision to explore", text: goal.practice.intent)
                    DemoReadingSection(
                        title: "The fictional situation", text: goal.practice.situation)
                    Label("Read, choose, understand · no grade", systemImage: "text.bubble")
                    Label("Local demo restoration", systemImage: "clock.arrow.circlepath")
                    DemoPrimaryButton(title: copy[.chooseGoal], symbol: "scope") {
                        flow.choose(goal)
                        learnSection = .myLearning
                        catalogPath = []
                        objectivePath = []
                        tab = .objective
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("Goal overview").navigationBarTitleDisplayMode(.inline)
        }

        private var preparation: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(progress: NativeDemoPracticeProgress(current: .situation))
                        Text(practice.title).font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        DemoReadingSection(title: "The situation", text: practice.situation)
                        DemoReadingSection(title: "Your task", text: practice.intent)
                        Divider()
                        DemoReadingSection(
                            title: "Before you choose",
                            text:
                                "Identify what the team wants to manage and what it wants to delegate. Focus on that boundary, not a provider name."
                        )
                        DemoPrimaryButton(title: "Open the question", symbol: "arrow.right") {
                            objectivePath = [.exercise]
                        }
                        .accessibilityIdentifier("demo-open-question")
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("Preparation").navigationBarTitleDisplayMode(.inline)
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
                                    ? "Choose an answer" : "Answer selected",
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
                                            ? "Selected" : "Not selected"
                                    )
                                    .accessibilityIdentifier("demo-option-\(index)")
                                }
                            }
                            Text("You can change your choice before the simulated submission.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: "\(copy.submitAnswer) · \(copy[.demo])", symbol: "paperplane"
                            ) {
                                flow.submit()
                            }
                            .disabled(!flow.canSubmit)
                            .accessibilityHint("Choose an answer before continuing.")
                            .accessibilityIdentifier("demo-submit")
                        case .pending:
                            Label {
                                Text("\(copy.pending) · \(copy[.demo])")
                            } icon: {
                                Image(systemName: "clock.fill").foregroundStyle(.orange)
                            }
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-pending-state")
                            Text("Your choice is saved in the demo.")
                                .font(.headline)
                            selectedAnswer
                            Text(
                                "No verdict, score or reward is calculated on this device."
                            )
                            if offline {
                                Label(
                                    "\(copy[.offline]) · \(copy[.demo])", systemImage: "wifi.slash")
                                Text(
                                    "The demo answer remains pending. The offline scenario pauses the next simulation step."
                                )
                                DemoPrimaryButton(
                                    title: "Turn off the offline scenario",
                                    symbol: "wifi"
                                ) { offline = false }
                            } else {
                                Text(
                                    "The next action simulates a server response. It does not contact an API."
                                )
                                DemoPrimaryButton(
                                    title: "Simulate the fictional explanation",
                                    symbol: "text.bubble"
                                ) {
                                    flow.receiveMockExplanation(offline: offline)
                                }
                                .accessibilityIdentifier("demo-receive-mock")
                            }
                        case .reviewed:
                            Label(
                                "Fictional explanation · no verdict",
                                systemImage: "text.bubble"
                            )
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-explanation-state")
                            selectedAnswer
                            DemoReadingSection(
                                title: "The decisive constraint", text: practice.constraint)
                            DemoReadingSection(
                                title: "Understanding the decision", text: practice.explanation)
                            DemoResponsibilities(rows: practice.responsibilities)
                            DemoTakeaway(text: practice.takeaway)
                            Text(
                                "This is a design fixture, not the correction of a published question. It appears for every choice: the demo gives no verdict or score."
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: copy.progressAndHistory,
                                symbol: "arrow.right"
                            ) { tab = .followUp }
                            Button(
                                "Practice the demo question again",
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
            .navigationTitle("Practice · demo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Demo settings", systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                }
            }
        }

        private var selectedAnswer: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your demo choice").font(.headline)
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
                    Text("Preview profile").font(.title2.bold())
                    Text("No account is signed in. This screen shows only the local demonstration.")
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
                            Section("Demonstration controls") {
                                Button("Preview states & offline simulation") {
                                    showScenarios = true
                                }
                                .frame(minHeight: 44)
                                Button("Reset the demo", role: .destructive) { showReset = true }
                                    .frame(minHeight: 44)
                            }
                            Section("Appearance & accessibility") {
                                Text(
                                    "The preview follows system appearance and text size. Navigation uses system transitions and controls respect Reduce Transparency."
                                )
                            }
                            Section("Account") {
                                Text(
                                    "Account, privacy and notification settings are not connected in this preview. No account preferences are changed."
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
                Section("Demo history") {
                    if let goal = flow.objective {
                        Text(goal.displayTitle).font(.headline)
                        Button(action: resumeExercise) {
                            Label(copy.resume, systemImage: flow.phase.symbol)
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("resume-demo-follow-up")
                        Text(flow.activitySummary)
                        if flow.phase == .reviewed {
                            Text(goal.practice.takeaway)
                        }
                        Text("This saved demonstration is not certification progress.")
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
            .navigationTitle(copy.progressAndHistory)
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
            let progress: NativeDemoPracticeProgress

            var body: some View {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { steps }
                    VStack(alignment: .leading, spacing: 8) { steps }
                }
                .font(.subheadline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progress.accessibilityLabel)
            }

            @ViewBuilder private var steps: some View {
                ForEach(NativeDemoPracticeStage.allCases, id: \.self) { step in
                    let state = progress.state(for: step)
                    Label(
                        step.rawValue,
                        systemImage: state.symbol
                    )
                    .foregroundStyle(state == .current ? NativePrism.tint : Color.secondary)
                    .fontWeight(state == .current ? .semibold : .regular)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        private struct DemoTakeaway: View {
            let text: String

            var body: some View {
                GroupBox {
                    Text(text)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } label: {
                    Label("Takeaway", systemImage: "lightbulb")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }

        private struct DemoResponsibilities: View {
            let rows: [NativeDemoPractice.Responsibility]

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Who manages what?").font(.headline)
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
                Label("Demo · fictional data and results", systemImage: "testtube.2")
                Text("Learning examples: French").font(.caption)
            }
            .font(.subheadline).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("synthetic-demo-notice")
        }

        @ToolbarContentBuilder private var demoToolbar: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Demo settings", systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                    Button(
                        "Reset the demo", systemImage: "arrow.counterclockwise",
                        role: .destructive
                    ) {
                        showReset = true
                    }
                } label: {
                    Label("Demo options", systemImage: "ellipsis.circle")
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

        var displayName: String {
            switch self {
            case .fundamentals: "Cloud · discovery"
            case .operations: "Cloud · operations"
            }
        }
        var displayTitle: String {
            switch self {
            case .fundamentals: "Cloud fundamentals"
            case .operations: "Cloud services in practice"
            }
        }
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
    var startLabel: String {
        startRoute == .preparation ? "Explore the situation" : resumeLabel
    }
    var activitySummary: String {
        switch phase {
        case .answering:
            selection == nil
                ? "A situation to explore · no grade"
                : "An editable choice · not submitted"
        case .pending: "Demo answer pending · no confirmed result"
        case .reviewed: "Fictional explanation available · no verdict"
        }
    }
    var resumeLabel: String {
        switch phase {
        case .answering: selection == nil ? "Start a question" : "Resume your choice"
        case .pending: "Resume the pending answer"
        case .reviewed: "Read the fictional explanation again"
        }
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

enum NativeDemoPracticeStage: String, CaseIterable {
    case situation = "Situation"
    case decision = "Decision"
    case explanation = "Explanation"

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

    var accessibilityLabel: String {
        let stageCount = NativeDemoPracticeStage.allCases.count
        return "Stage \(current.position) of \(stageCount): \(current.rawValue). "
            + "Stages describe the learning flow, not whether an answer is correct."
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
                        Text(message).accessibilityIdentifier("account-deletion-message")
                            .accessibilityFocused($focused, equals: .error)
                    }
                }
                if [.explanation, .verifying, .confirmation].contains(
                    model.deletionStage ?? .explanation)
                {
                    Section("Before you continue") {
                        Text(
                            "Permanently delete your Certigo account, confirmed learning and progression. Local drafts and downloaded account references are removed only after the server confirms completion."
                        )
                        Text(
                            "This is irreversible. There is no cancellation endpoint after submission. Residual production backups may rotate for up to 30 days, a pseudonymous tombstone remains for 30 days and identity-free deletion audit logs for 90 days. These are not an undo period."
                        )
                        if model.canReauthenticateForDeletion {
                            Button(
                                "Continue to verify identity",
                                systemImage: "person.badge.shield.checkmark"
                            ) {
                                Task { await model.verifyDeletionIdentity() }
                            }
                            .disabled(model.deletionBusy)
                        } else {
                            Text(
                                "Remote deletion requires configured Microsoft sign-in. It is unavailable for the demo and manual development connector."
                            )
                        }
                    }
                } else if model.deletionStage == .pending || model.deletionStage == .unconfirmed
                    || model.deletionStage == .checking
                {
                    Section("Server status") {
                        if let status = model.deletionStatus, status.status == .pending {
                            Text(
                                "\(status.completedSteps) of \(status.totalSteps) server steps confirmed."
                            )
                            Text(
                                "Deletion is pending, not completed. Learning is paused and local data is retained. Status checks do not advance unfinished deletion steps."
                            )
                            if status.retryAfterSeconds != nil {
                                Text(
                                    "The server requested a retry delay. Refresh status before retrying if the action is not available yet."
                                )
                            }
                        }
                        Button("Check status", systemImage: "arrow.clockwise") {
                            Task { await model.refreshDeletionStatus() }
                        }
                        .disabled(model.deletionBusy)
                        Button(
                            "Sign in to check the same account", systemImage: "person.crop.circle"
                        ) {
                            Task { await model.recoverDeletionConnection(interactive: true) }
                        }
                        .disabled(model.deletionBusy)
                        Button(copy.retry, role: .destructive) {
                            Task { await model.retryAccountDeletion() }
                        }
                        .disabled(!model.canRetryDeletion)
                        if model.deletionStatus?.status == .notRequested {
                            Button("Resume account to verify identity") {
                                Task { await model.resumeAccountAfterStatusCheck() }
                            }
                            .disabled(model.deletionBusy)
                        }
                    }
                } else if model.deletionStage == .cleanupFailed {
                    Section {
                        Text(
                            "\(copy.confirmed). Cleanup on this device is not complete."
                        )
                        Button(copy.retry, systemImage: "arrow.clockwise") {
                            Task { await model.retryDeletionCleanup() }
                        }
                        .disabled(model.deletionBusy)
                    }
                } else if model.deletionStage == .completed {
                    Section {
                        Text(
                            "The server confirmed account deletion and this device confirmed local cleanup. Residual retention periods still apply."
                        )
                        Button("Return to sign-in") { model.acknowledgeAccountDeletion() }
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
                "Permanently delete this Certigo account?",
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
                    "Microsoft verified the same account. Only Delete account submits the irreversible request. Completion may require retries."
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
            case .verifying: "Verify your Microsoft identity"
            case .confirmation: "Identity verified"
            case .checking: "Checking account deletion"
            case .pending: "Deletion pending"
            case .unconfirmed: "Account status unconfirmed"
            case .cleanupFailed: "Local cleanup requires attention"
            case .completed: "Account deleted"
            default: "Delete your Certigo account"
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
                                        ? "Friends are not connected"
                                        : "Teams are not connected",
                                    systemImage: "person.2",
                                    description: Text(
                                        "Invitations, sharing and group activity are not available. No relationships are created here."
                                    ))
                                NativeReadingSection(title: "Private learning comes first") {
                                    Text(
                                        "Your Profile is your private learning record, not a friend profile."
                                    )
                                    Text(
                                        "Detailed results, mistakes, readiness and Coach context are not published by visiting Social."
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                NativeReadingSection(
                                    title: navigation.social == .friends
                                        ? "Friends · not active" : "Teams · not active"
                                ) {
                                    Text(
                                        navigation.social == .friends
                                            ? "Friend discovery, invitations and shared profiles are not enabled. No contacts are uploaded and no invitations are sent."
                                            : "Team membership, roles, invitations and challenges are not enabled. A shared team would not grant access to private results or readiness."
                                    )
                                    Text(
                                        "Any future sharing needs a separate, explicit opt-in with a preview of the content and audience. No sharing controls are active here."
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                Button("Return to learning", systemImage: "book") {
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
                        savingGoalID == nil ? copy.loading : "Saving active goal…"
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
                "Operation not confirmed",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
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
                        description: Text(coachPhase))
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
                        model.selectedTab = .learn
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
                        Section("Shared lesson link") {
                            Text("Editorial pilot · \(pendingLessonLink.lessonID)")
                            Button("Open linked lesson", systemImage: "arrow.up.right.square") {
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
                "Download public question packs?",
                isPresented: Binding(
                    get: { downloadTrack != nil },
                    set: { if !$0 { downloadTrack = nil } })
            ) {
                if let track = downloadTrack {
                    Button("Download public content") {
                        downloadTrack = nil
                        Task { await model.downloadQuestionPack(track) }
                    }
                }
            } message: {
                Text(
                    "This downloads the whole current public release, not just this certification. No solutions are downloaded. Answers stay local until you choose Submit; correction and XP require the server."
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
                    "\(copy[.startReview]) · \(node.title) · \(node.estMinutes) min",
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
                    LabeledContent(copy.native(.remainingLearning), value: "\(remaining) min")
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
            Text("\(copy.native(.duration)) · \(recommendation.estMinutes) min")
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
                        Text("\(copy.native(.studyPlan)) · \(plan.dailyMinutesGoal) min")
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
                                    "\(copy.startSession) · \(next.title) · \(next.estMinutes) min",
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
                                    "\(destination.actionTitle(copy.startSession)) · \(next.estMinutes) min",
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
                "Development connection"
            #else
                "Microsoft account"
            #endif
        }

        private var connectionDescription: String {
            #if DEBUG
                "Test connector only. Production sign-in is not enabled."
            #else
                "Connected with your Microsoft account."
            #endif
        }

        private var connection: some View {
            NavigationStack {
                Form {
                    Section {
                        NativeEntryHeading(
                            title: "Connect a test workspace.",
                            message:
                                "Development access only. Your production account uses Microsoft sign-in."
                        )
                        Text(
                            "This developer connector is not production sign-in. No Apple account or new identity is created."
                        )
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Certigo · development")
                    }
                    .scrollContentBackground(.hidden)
                    .background(NativePrism.canvas)
                    Section("Test connection") {
                        TextField("HTTPS API URL", text: $model.baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityIdentifier("developer-api-url")
                        SecureField("Test account access token", text: $model.token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .accessibilityIdentifier("developer-access-token")
                        Button("Connect the test account") { Task { await model.connect() } }
                            .disabled(model.busy || model.baseURL.isEmpty || model.token.isEmpty)
                    }
                    Section {
                        Text(
                            "The token stays in this device’s secure vault. Pending answers are never graded locally."
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Certigo")
            }
        }

        private var path: some View {
            List(selection: $selectedLesson) {
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
                        Section("Offline question pack") {
                            Button(
                                "Download public question packs", systemImage: "arrow.down.circle"
                            ) {
                                downloadTrack = track
                            }
                            .disabled(model.busy)
                            if let pack = model.offlinePack, pack.trackId == track.id {
                                Text("Downloaded public content. No local correction or XP.")
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
                if let path = model.path,
                    selectedTrack == nil || selectedTrack == path.trackId,
                    model.tracks.first(where: { $0.id == path.trackId })?.learningAvailable != false
                {
                    if let track = model.tracks.first(where: { $0.id == path.trackId }) {
                        activeGoalSection(track)
                    }
                    Section {
                        Text(path.trackName).font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        LabeledContent(
                            copy.native(.readiness), value: "\(path.readinessScore) %")
                        Button(copy.native(.refreshData), systemImage: "arrow.clockwise") {
                            Task { await model.refreshProgress() }
                        }
                        .disabled(model.busy)
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
                    }
                    ForEach(path.units) { unit in
                        Section("\(copy.native(.unit)) · \(unit.title)") {
                            ForEach(unit.lessons) { lesson in
                                NavigationLink(value: lesson.id) {
                                    Label {
                                        VStack(alignment: .leading) {
                                            Text(lesson.title)
                                                .font(.headline)
                                            Text("\(lesson.estMinutes) min").foregroundStyle(
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
                                "Learning path not loaded",
                                systemImage: "wifi.exclamationmark",
                                description: Text(
                                    "Load or retry this certification’s path. This does not change your active goal."
                                )
                            )
                            Button("Load or retry path", systemImage: "arrow.clockwise") {
                                requestPath(track)
                            }
                            .disabled(model.busy || loadingTrackID != nil)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Choose a certification", systemImage: "books.vertical",
                        description: Text("Its learning path will load from the server.")
                    )
                }
                savedAnswers
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(NativePrism.canvas)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .navigationTitle(
                selectedTrack.map(trackTitle) ?? model.path?.trackName ?? "Learning path")
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
                        "Across your devices · \(model.serverHistory.count) summaries loaded\(model.historyNextCursor == nil ? "" : " · more pages available")"
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    Text(
                        "These are loaded attempts, not all-time question coverage. Pending answers are not confirmed results; no average or pass probability is inferred."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if model.historyLoading {
                        ProgressView(copy.loading)
                    }
                    if let error = model.historyError {
                        Label(
                            error,
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
                                    : "No confirmed attempts in this page. More history is available."
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
                                    "Recorded score: \(item.scorePct) % · Earned XP: \(item.xpEarned)"
                                )
                                Text(
                                    "Server-confirmed summary · full correction is in saved answers when available."
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
                        "Drafts are never uploaded by viewing history. Local dates are activity start dates, not server submission times."
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
                                        "Confirmed score: \(result.scorePct) % · Earned XP: \(result.rewards.xpEarned)"
                                    )
                                }
                                Text(
                                    "Server acknowledgement saved locally; not in the loaded history pages."
                                )
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        ForEach(presentation.onDevice) { saved in
                            savedAnswer(saved)
                        }
                        if presentation.onDevice.isEmpty && presentation.confirmedOnDevice.isEmpty {
                            Text("No additional saved submissions on this device.")
                        }
                    } else if model.historyError != nil {
                        Text(
                            "The local history presentation could not be verified. Saved answers remain available in Learn."
                        )
                    }
                    if model.lesson != nil {
                        Label(
                            model.outcome == nil
                                ? "Current local activity" : "Current submitted activity",
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
                        "History pages do not update your balance, readiness or active learning goal."
                    )
                    Text(
                        "Readiness is a server-returned learning indicator for the named path, not a calibrated probability of passing the exam. Its formula version, evidence window and last calculation time are not supplied by this client contract."
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    if model.path == nil {
                        Text(
                            "Readiness is unknown until a learning path is loaded. Unknown is not zero."
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
                        value: "\(coverage.completedActivities) of \(coverage.totalActivities)")
                    LabeledContent(
                        copy.native(.completedUnits),
                        value: "\(coverage.completedUnits) of \(coverage.totalUnits)")
                    Text(
                        "Snapshot of the currently loaded server path, not a time-period report. Completed or mastered activities count; empty units do not count as complete."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(
                        "Load a learning path to see its activity denominator. Coverage is not known yet."
                    )
                }
                if let lesson = model.lesson {
                    let selectedCount = lesson.questions.filter {
                        model.selections[$0.id] != nil
                    }.count
                    Text(lesson.title).font(.headline)
                    LabeledContent(
                        copy.native(.localAnswers),
                        value: "\(selectedCount) of \(lesson.questions.count) questions")
                    Text(
                        "Selection is not submission or correctness. Total questions covered across the whole path are not provided."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                Text(
                    "Viewing this snapshot never switches your active goal. History is separate and may contain other goals."
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
                Section("Saved answers") {
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
                    Label("Correction pending", systemImage: "clock")
                        .foregroundStyle(NativePrism.pending)
                    Button(copy.retry) {
                        Task { await model.retry(saved) }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.busy)
                case .corrected:
                    if let result = saved.result {
                        Text("Confirmed score: \(result.scorePct) %")
                        ForEach(result.results) { item in
                            Text(item.explanation)
                        }
                    }
                case .failed:
                    Label(
                        "Submission rejected · answers preserved",
                        systemImage: "exclamationmark.triangle")
                    Text(
                        "This is a local status; the server may already have recorded the attempt."
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
            Section("Active learning goal") {
                Label(state.status, systemImage: state.symbol)
                    .accessibilityIdentifier("active-goal-status")
                if let current = model.profile?.activeTrackId {
                    Text(
                        "Server-confirmed goal: \(model.tracks.first(where: { $0.id == current })?.title ?? current)"
                    )
                    .foregroundStyle(.secondary)
                } else {
                    Text("No active goal is confirmed by the server.")
                        .foregroundStyle(.secondary)
                }
                NativePrimaryButton(title: state.action, symbol: "scope") {
                    savingGoalID = track.id
                    Task {
                        await model.chooseActiveTrack(track)
                        savingGoalID = nil
                    }
                }
                .frame(minHeight: 44)
                .disabled(!state.canChoose)
                .accessibilityIdentifier("choose-active-goal")
                Text(
                    "Browsing does not change your goal. This action requests a server-confirmed change; your current activity and saved submissions stay available."
                )
                .font(.subheadline).foregroundStyle(.secondary)
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
                                    copy.native(.duration), value: "\(node.estMinutes) min")
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
                                "Answer the questions, then submit your answers for server correction."
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
                                            "Correction will be requested after reconnecting. No score or XP is confirmed yet."
                                        )
                                        .foregroundStyle(.secondary)
                                    }
                                    .accessibilityIdentifier("pending-correction")
                                case .corrected(let result):
                                    NativeReadingSection(title: "Your confirmed result") {
                                        Label(
                                            copy.confirmed, systemImage: "checkmark.seal"
                                        )
                                        .foregroundStyle(NativePrism.confirmed)
                                        LabeledContent("Score", value: "\(result.scorePct) %")
                                        LabeledContent(
                                            "XP earned", value: "\(result.rewards.xpEarned)")
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
                                                item.correct ? "Correct answer" : "Review needed",
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
                                        Button("Read again", systemImage: "text.book.closed") {
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
                                                "Starts a new answer selection for this activity. Your confirmed attempt stays in history."
                                            )
                                            .font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Text(
                                                "Open an available activity in the learning plan to practice again. Reading does not create another attempt."
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
                                "Lesson unavailable",
                                systemImage: "wifi.exclamationmark",
                                description: Text(
                                    "The selected lesson could not be loaded."
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
                        "One session at a time", systemImage: "book",
                        description: Text("Choose an activity in the learning path.")
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
                        model.selections[question.id] == option.id ? "Selected" : "Not selected")
                }
            }
            .onAppear { model.questionAppeared(question.id) }
        }
    }

    @MainActor
    struct NativeLessonAudioControls: View {
        @Environment(\.scenePhase) private var scenePhase
        @State private var speech = NativeLessonSpeech()
        let content: NativeLessonReadingContent
        let ownerID: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Read lesson aloud").font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    "Reads selected learning text only. Code, questions and corrections are not read. Choose a reading voice; the content language is not detected."
                )
                .font(.subheadline).foregroundStyle(.secondary)
                Picker("Reading voice", selection: $speech.voiceID) {
                    Text("Choose a voice").tag("")
                    ForEach(speech.voices, id: \.identifier) { voice in
                        Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                    }
                }
                .disabled(speech.state != .idle)
                if speech.voices.isEmpty {
                    Text("No reading voices are available on this device.")
                }
                Picker("Reading speed", selection: $speech.rate) {
                    Text("Slower").tag(AVSpeechUtteranceDefaultSpeechRate * 0.8)
                    Text("Standard").tag(AVSpeechUtteranceDefaultSpeechRate)
                }
                .disabled(speech.state != .idle)
                Text(speech.state.label).font(.subheadline)
                    .accessibilityIdentifier("lesson-audio-state")
                ViewThatFits(in: .horizontal) {
                    HStack { playbackButtons }
                    VStack(alignment: .leading) { playbackButtons }
                }
                if let issue = speech.issue {
                    Text(issue).foregroundStyle(.primary)
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
                Button("Read lesson", systemImage: "speaker.wave.2") {
                    speech.read(content)
                }
                .frame(minHeight: 44)
            case .reading:
                Button("Pause reading", systemImage: "pause") { speech.pause() }
                    .frame(minHeight: 44)
            case .paused:
                Button("Resume reading", systemImage: "play") { speech.resume() }
                    .frame(minHeight: 44)
            }
            if speech.state != .idle {
                Button("Stop reading", systemImage: "stop") { speech.stop() }
                    .frame(minHeight: 44)
            }
        }
    }

    @MainActor
    @Observable
    private final class NativeLessonSpeech: NSObject, AVSpeechSynthesizerDelegate {
        enum State {
            case idle, reading, paused

            var label: String {
                switch self {
                case .idle: "Audio stopped"
                case .reading: "Reading lesson"
                case .paused: "Audio paused"
                }
            }
        }

        let voices = AVSpeechSynthesisVoice.speechVoices().sorted {
            ($0.language, $0.name, $0.identifier) < ($1.language, $1.name, $1.identifier)
        }
        var voiceID = ""
        var rate = AVSpeechUtteranceDefaultSpeechRate
        private(set) var state = State.idle
        private(set) var issue: String?
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
                issue = "No reading voices are available on this device."
                return
            }
            guard !UIAccessibility.isVoiceOverRunning else {
                issue =
                    "VoiceOver is active. Use VoiceOver to read this content; optional audio stays stopped to avoid overlapping speech."
                return
            }
            guard !voiceID.isEmpty else {
                issue = "Choose a reading voice before starting."
                return
            }
            guard let voice = AVSpeechSynthesisVoice(identifier: voiceID) else {
                issue = "That voice is unavailable. Choose an available reading voice."
                return
            }
            let text: String
            do {
                text = try content.spokenText(
                    renderingMarkdown: NativeLessonReadingContent.plainText)
            } catch {
                issue =
                    "The lesson text could not be prepared for reading. No audio was started; you can still read the lesson on screen."
                return
            }
            guard !text.isEmpty else {
                issue = "No lesson text is available to read."
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
                issue = "Reading could not be paused. Stop reading and try again."
            }
        }

        func resume() {
            guard state == .paused else { return }
            guard !UIAccessibility.isVoiceOverRunning else {
                stop()
                issue =
                    "VoiceOver is active. Optional audio stays stopped to avoid overlapping speech."
                return
            }
            if synthesizer.continueSpeaking() {
                state = .reading
            } else {
                issue = "Reading could not be resumed. Stop reading and try again."
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
    var status: String {
        if isSaving { return "Goal change pending · waiting for the server" }
        return isConfirmed ? "This is your confirmed active goal" : "Viewing a goal · not selected"
    }
    var symbol: String { isSaving ? "clock" : isConfirmed ? "checkmark.circle" : "eye" }
    var action: String { isSaving ? "Saving active goal…" : "Choose as active goal" }
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
