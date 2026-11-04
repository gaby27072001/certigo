import CertigoDomain
import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - 1. Official V3 Notification Categories & iOS Quick Actions (Duolingo × Apple HIG Writing)

/// The 5 official notification categories in CertiGo V3.
public enum CertiGoSmartNotificationCategory: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// Category 1: Daily Habit Anchor (19:30 or user-chosen anchor time), focused on the exact active step.
    case dailyAnchor = "CERTIGO_NOTIF_DAILY_ANCHOR_V3"
    /// Category 2: Evening 90-Second Streak Rescue (21:30), friendly Duo-style nudge without guilt.
    case streakRescue90s = "CERTIGO_NOTIF_STREAK_RESCUE_90S_V3"
    /// Category 3: Tech & AI News Flash Alert (30s digest or direct CertiGo AI explanation).
    case techNewsFlash = "CERTIGO_NOTIF_TECH_NEWS_FLASH_V3"
    /// Category 4: FSRS Spaced Repetition Consolidation (long-term memory anchor in 45s).
    case fsrsSpacedReview = "CERTIGO_NOTIF_FSRS_SPACED_REVIEW_V3"
    /// Category 5: Kind Comeback after 48h of inactivity (shield saved your spot, zero penalty).
    case kindComeback48h = "CERTIGO_NOTIF_KIND_COMEBACK_48H_V3"

    public var id: String { rawValue }

    /// Maximum character count on iPhone Lock Screen for notification titles.
    public static let maxTitleCharacters: Int = 38
    /// Maximum character count on iPhone Lock Screen for notification bodies.
    public static let maxBodyCharacters: Int = 90

    /// Default scheduled time label used when displaying or scheduling the notification category.
    public func defaultScheduledTimeLabel(preferredAnchorTime: String = "19:30") -> String {
        let cleanAnchor = preferredAnchorTime.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .dailyAnchor:
            return cleanAnchor.isEmpty ? "19:30" : cleanAnchor
        case .streakRescue90s:
            return "21:30"
        case .techNewsFlash:
            return "12:30"
        case .fsrsSpacedReview:
            return "18:00"
        case .kindComeback48h:
            return "+48h"
        }
    }

    /// Thread identifier used by iOS `UNMutableNotificationContent` to group notifications cleanly.
    public var threadIdentifier: String {
        switch self {
        case .dailyAnchor:
            return "certigo.thread.daily-anchor"
        case .streakRescue90s:
            return "certigo.thread.streak-rescue"
        case .techNewsFlash:
            return "certigo.thread.tech-news"
        case .fsrsSpacedReview:
            return "certigo.thread.fsrs-review"
        case .kindComeback48h:
            return "certigo.thread.comeback"
        }
    }
}

/// Interactive iOS Lock Screen quick actions attached to every CertiGo V3 notification category.
public enum CertiGoSmartNotificationQuickAction: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case oneTapLaunch = "CERTIGO_ACTION_ONE_TAP_LAUNCH"
    case askCertiGoAI = "CERTIGO_ACTION_ASK_CERTIGO_AI"

    public var id: String { rawValue }

    /// Localized action button title for `UNNotificationAction` (zero em/en dashes).
    public func localizedTitle(in language: AppLanguage = .french) -> String {
        switch (self, language) {
        case (.oneTapLaunch, .french):
            return "Lancer en 1 tap"
        case (.oneTapLaunch, .english):
            return "1-Tap Launch"
        case (.oneTapLaunch, .spanish):
            return "Iniciar en 1 toque"
        case (.oneTapLaunch, .german):
            return "Mit 1 Tippen starten"
        case (.oneTapLaunch, .italian):
            return "Avvia in 1 tocco"
        case (.oneTapLaunch, .hindi):
            return "1 टैप में शुरू करें"
        case (.oneTapLaunch, .chineseSimplified):
            return "一键开始"
        case (.oneTapLaunch, .korean):
            return "원탭 시작"

        case (.askCertiGoAI, .french):
            return "Demander à CertiGo AI"
        case (.askCertiGoAI, .english):
            return "Ask CertiGo AI"
        case (.askCertiGoAI, .spanish):
            return "Preguntar a CertiGo AI"
        case (.askCertiGoAI, .german):
            return "CertiGo AI fragen"
        case (.askCertiGoAI, .italian):
            return "Chiedi a CertiGo AI"
        case (.askCertiGoAI, .hindi):
            return "CertiGo AI से पूछें"
        case (.askCertiGoAI, .chineseSimplified):
            return "询问 CertiGo AI"
        case (.askCertiGoAI, .korean):
            return "CertiGo AI에게 질문"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .oneTapLaunch:
            return "play.fill"
        case .askCertiGoAI:
            return "sparkles"
        }
    }
}

// MARK: - 2. Track Personalization Context (`AZ-900`, `HARVEY-LEGAL`, `OPENAI-PRO`, `ANTHROPIC-CLAUDE`, `GH-300`, ...)

public struct CertiGoSmartNotificationTrackContext: Codable, Equatable, Hashable, Sendable {
    public let routeCode: String
    public let shortTrackName: String
    public let defaultStepTitle: String
    public let techActorName: String

    public init(
        routeCode: String,
        shortTrackName: String,
        defaultStepTitle: String,
        techActorName: String
    ) {
        self.routeCode = routeCode
        self.shortTrackName = shortTrackName
        self.defaultStepTitle = defaultStepTitle
        self.techActorName = techActorName
    }

    /// Resolves the personalized notification context for any certification or AI track in CertiGo.
    public static func resolve(
        forRouteCode routeCode: String,
        customStepTitle: String? = nil,
        language: AppLanguage = .french
    ) -> CertiGoSmartNotificationTrackContext {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let (shortTrack, defaultStepFR, defaultStepEN, actor): (String, String, String, String) = {
            switch upper {
            case "HARVEY-LEGAL":
                return ("Harvey Academy", "Vault Due Diligence", "Vault Due Diligence", "Harvey")
            case "OPENAI-PRO", "AI-OPENAI":
                return ("OpenAI Pro", "Responses API et o3", "Responses API & o3", "OpenAI")
            case "ANTHROPIC-CLAUDE", "AI-ANTHROPIC":
                return ("Claude & MCP", "Claude Code et MCP", "Claude Code & MCP", "Anthropic")
            case "MS-365-COPILOT":
                return ("M365 Copilot", "Work IQ et Agents", "Work IQ & Agents", "Microsoft")
            case "GH-300":
                return ("GitHub Copilot", "Garde-fous Copilot", "Copilot Guardrails", "GitHub")
            case "AZ-900":
                return ("Azure AZ-900", "Gouvernance et Coûts", "Governance & Cost", "Microsoft")
            case "AZ-104":
                return ("Azure AZ-104", "Private Endpoint et DNS", "Private Endpoint & DNS", "Microsoft")
            case "AZ-305":
                return ("Azure AZ-305", "Architecture Zero Trust", "Zero Trust Design", "Microsoft")
            case "AI-102", "AI-FOUNDRY":
                return ("Azure AI-102", "AI Search et RAG", "AI Search & RAG", "Microsoft")
            case "SAA-C03":
                return ("AWS SAA-C03", "VPC et Security Groups", "VPC & Security Groups", "AWS")
            case "CLF-C02":
                return ("AWS CLF-C02", "IAM et Facturation AWS", "AWS IAM & Billing", "AWS")
            case "CKA":
                return ("Kubernetes CKA", "RBAC et NetworkPolicy", "RBAC & NetworkPolicy", "Cloud")
            case "PCA", "ACE", "AI-GEMINI":
                return ("Google Cloud", "Pub/Sub et BigQuery", "Pub/Sub & BigQuery", "Google")
            case "TF-003":
                return ("Terraform", "State et Modules", "State & Modules", "Cloud")
            case "CCNA":
                return ("Cisco CCNA", "VLAN et Routage OSPF", "VLAN & OSPF Routing", "Cloud")
            case "CCA-F":
                return ("Claude CCA-F", "Prompt Caching et MCP", "Prompt Caching & MCP", "Anthropic")
            case "AI-MISTRAL":
                return ("Mistral AI", "Agents et Open-Weight", "Agents & Open-Weight", "Mistral")
            default:
                let cleanCode = upper.isEmpty ? "AZ-104" : String(upper.prefix(12))
                return (cleanCode, "Architecture Cloud", "Cloud Architecture", "Microsoft")
            }
        }()

        let stepFallback = (language == .french) ? defaultStepFR : defaultStepEN
        let resolvedStep: String = {
            guard let custom = customStepTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !custom.isEmpty
            else {
                return stepFallback
            }
            let sanitized = CertiGoSmartNotificationsCatalog.sanitizeForbiddenDashes(in: custom)
            return sanitized.count <= 26 ? sanitized : String(sanitized.prefix(26)).trimmingCharacters(in: .whitespaces)
        }()

        return CertiGoSmartNotificationTrackContext(
            routeCode: upper.isEmpty ? "AZ-104" : upper,
            shortTrackName: shortTrack,
            defaultStepTitle: resolvedStep,
            techActorName: actor
        )
    }
}

// MARK: - 3. Validated V3 Notification Payload Spec

public struct CertiGoSmartNotificationSpec: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let category: CertiGoSmartNotificationCategory
    public let routeCode: String
    public let language: AppLanguage
    public let title: String
    public let body: String
    public let scheduledTimeText: String
    public let primaryDeepLinkURL: String
    public let askAIDeepLinkURL: String
    public let quickActionTitles: [String]

    public init(
        id: String,
        category: CertiGoSmartNotificationCategory,
        routeCode: String,
        language: AppLanguage,
        title: String,
        body: String,
        scheduledTimeText: String,
        primaryDeepLinkURL: String,
        askAIDeepLinkURL: String,
        quickActionTitles: [String]
    ) {
        self.id = id
        self.category = category
        self.routeCode = routeCode
        self.language = language
        self.title = CertiGoSmartNotificationsCatalog.clampAndSanitize(
            title,
            maxLength: CertiGoSmartNotificationCategory.maxTitleCharacters
        )
        self.body = CertiGoSmartNotificationsCatalog.clampAndSanitize(
            body,
            maxLength: CertiGoSmartNotificationCategory.maxBodyCharacters
        )
        self.scheduledTimeText = scheduledTimeText
        self.primaryDeepLinkURL = primaryDeepLinkURL
        self.askAIDeepLinkURL = askAIDeepLinkURL
        self.quickActionTitles = quickActionTitles.map {
            CertiGoSmartNotificationsCatalog.sanitizeForbiddenDashes(in: $0)
        }
    }

    /// True if both title (`<= 38`) and body (`<= 90`) respect iPhone Lock Screen bounds and contain zero em/en dashes.
    public var compliesWithLockScreenCopyCharter: Bool {
        title.count <= CertiGoSmartNotificationCategory.maxTitleCharacters
            && body.count <= CertiGoSmartNotificationCategory.maxBodyCharacters
            && !title.contains("—")
            && !title.contains("–")
            && !body.contains("—")
            && !body.contains("–")
            && quickActionTitles.allSatisfy { !$0.contains("—") && !$0.contains("–") }
    }
}

// MARK: - 4. Official CertiGo V3 Smart Notifications Catalog & UNUserNotificationCenter Bridge

public enum CertiGoSmartNotificationsCatalog: Sendable {
    /// Replaces any forbidden em-dash (`—`) or en-dash (`–`) with clean punctuation.
    public static func sanitizeForbiddenDashes(in text: String) -> String {
        text
            .replacingOccurrences(of: " — ", with: " : ")
            .replacingOccurrences(of: " – ", with: " : ")
            .replacingOccurrences(of: "—", with: ":")
            .replacingOccurrences(of: "–", with: "-")
    }

    /// Ensures the string contains zero em/en dashes and fits strictly within `maxLength` characters.
    public static func clampAndSanitize(_ text: String, maxLength: Int) -> String {
        let clean = sanitizeForbiddenDashes(in: text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > maxLength else { return clean }
        return String(clean.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    }

    /// Builds a single V3 notification specification for the given category, track, and language.
    public static func notification(
        for category: CertiGoSmartNotificationCategory,
        routeCode: String,
        activeStepTitle: String? = nil,
        streakDays: Int = 7,
        preferredAnchorTime: String = "19:30",
        language: AppLanguage = .french
    ) -> CertiGoSmartNotificationSpec {
        let context = CertiGoSmartNotificationTrackContext.resolve(
            forRouteCode: routeCode,
            customStepTitle: activeStepTitle,
            language: language
        )
        let safeStreak = max(1, min(streakDays, 999))
        let actions = CertiGoSmartNotificationQuickAction.allCases.map {
            $0.localizedTitle(in: language)
        }

        let (rawTitle, rawBody): (String, String) = {
            switch category {
            case .dailyAnchor:
                return dailyAnchorCopy(context: context, language: language)
            case .streakRescue90s:
                return streakRescueCopy(streakDays: safeStreak, language: language)
            case .techNewsFlash:
                return techNewsFlashCopy(context: context, language: language)
            case .fsrsSpacedReview:
                return fsrsSpacedReviewCopy(language: language)
            case .kindComeback48h:
                return kindComebackCopy(language: language)
            }
        }()

        let primaryURL: String = {
            switch category {
            case .dailyAnchor:
                return "certigo://sprint/one-tap?route=\(context.routeCode)"
            case .streakRescue90s:
                return "certigo://sprint/rescue-90s?route=\(context.routeCode)"
            case .techNewsFlash:
                return "certigo://radar/flash-30s?route=\(context.routeCode)&actor=\(context.techActorName.lowercased())"
            case .fsrsSpacedReview:
                return "certigo://review/fsrs-45s?route=\(context.routeCode)"
            case .kindComeback48h:
                return "certigo://sprint/kind-comeback?route=\(context.routeCode)"
            }
        }()

        let askAIURL = "certigo://ai-coach/explain?route=\(context.routeCode)&category=\(category.rawValue)"

        return CertiGoSmartNotificationSpec(
            id: "certigo-v3-\(category.rawValue.lowercased())-\(context.routeCode.lowercased())-\(language.rawValue)",
            category: category,
            routeCode: context.routeCode,
            language: language,
            title: rawTitle,
            body: rawBody,
            scheduledTimeText: category.defaultScheduledTimeLabel(preferredAnchorTime: preferredAnchorTime),
            primaryDeepLinkURL: primaryURL,
            askAIDeepLinkURL: askAIURL,
            quickActionTitles: actions
        )
    }

    /// Builds the complete 5-category V3 notification suite for a learner's active track and language.
    public static func buildCompleteSuite(
        routeCode: String,
        activeStepTitle: String? = nil,
        streakDays: Int = 7,
        preferredAnchorTime: String = "19:30",
        language: AppLanguage = .french
    ) -> [CertiGoSmartNotificationSpec] {
        CertiGoSmartNotificationCategory.allCases.map { category in
            notification(
                for: category,
                routeCode: routeCode,
                activeStepTitle: activeStepTitle,
                streakDays: streakDays,
                preferredAnchorTime: preferredAnchorTime,
                language: language
            )
        }
    }

    // MARK: - Localized Copy Builders (Title <= 38 chars, Body <= 90 chars, Zero Em/En Dash)

    private static func dailyAnchorCopy(
        context: CertiGoSmartNotificationTrackContext,
        language: AppLanguage
    ) -> (title: String, body: String) {
        let track = context.shortTrackName
        let step = context.defaultStepTitle
        switch language {
        case .french:
            return (
                "🎯 2 min sur \(track) ?",
                "Ta prochaine étape sur \(step) t'attend."
            )
        case .english:
            return (
                "🎯 2 min on \(track)?",
                "Your next step on \(step) is ready."
            )
        case .spanish:
            return (
                "🎯 ¿2 min en \(track)?",
                "Tu siguiente paso en \(step) te espera."
            )
        case .german:
            return (
                "🎯 2 Min. für \(track)?",
                "Dein nächster Schritt zu \(step) wartet."
            )
        case .italian:
            return (
                "🎯 2 min su \(track)?",
                "Il tuo prossimo passo su \(step) ti aspetta."
            )
        case .hindi:
            return (
                "🎯 \(track) पर 2 मिनट?",
                "\(step) पर आपका अगला चरण तैयार है।"
            )
        case .chineseSimplified:
            return (
                "🎯 2分钟学 \(track)？",
                "你在 \(step) 的下一步已就绪。"
            )
        case .korean:
            return (
                "🎯 \(track) 2분 학습할까요?",
                "\(step)의 다음 단계가 준비되었습니다."
            )
        }
    }

    private static func streakRescueCopy(
        streakDays: Int,
        language: AppLanguage
    ) -> (title: String, body: String) {
        switch language {
        case .french:
            return (
                "🔥 Garde ta série de \(streakDays) jours en vie",
                "1 seule question rapide suffit ce soir pour valider ta journée."
            )
        case .english:
            return (
                "🔥 Keep your \(streakDays)-day streak alive",
                "Just 1 quick question tonight locks in your daily goal."
            )
        case .spanish:
            return (
                "🔥 Salva tu racha de \(streakDays) días",
                "1 pregunta rápida esta noche basta para validar tu día."
            )
        case .german:
            return (
                "🔥 Halte deine \(streakDays)-Tage-Serie aktiv",
                "Nur 1 schnelle Frage heute Abend sichert dein Tagesziel."
            )
        case .italian:
            return (
                "🔥 Salva la tua serie di \(streakDays) giorni",
                "Basta 1 domanda veloce stasera per completare la giornata."
            )
        case .hindi:
            return (
                "🔥 अपनी \(streakDays) दिन की स्ट्रीक बचाएं",
                "आज का लक्ष्य पूरा करने के लिए बस 1 तेज़ सवाल काफी है।"
            )
        case .chineseSimplified:
            return (
                "🔥 保住你的 \(streakDays) 天连胜纪录",
                "今晚只需回答 1 道快问即可完成今日目标。"
            )
        case .korean:
            return (
                "🔥 \(streakDays)일 연속 기록을 지켜보세요",
                "오늘 밤 빠른 문제 1개면 일일 목표가 완료됩니다."
            )
        }
    }

    private static func techNewsFlashCopy(
        context: CertiGoSmartNotificationTrackContext,
        language: AppLanguage
    ) -> (title: String, body: String) {
        let actor = context.techActorName
        switch language {
        case .french:
            return (
                "⚡ Actu \(actor) : que change-t-elle ?",
                "Découvre le résumé en 30s ou demande à CertiGo AI de te l'expliquer."
            )
        case .english:
            return (
                "⚡ \(actor) update: what changes?",
                "Read the 30s summary or ask CertiGo AI to break it down."
            )
        case .spanish:
            return (
                "⚡ Actu \(actor): ¿qué cambia?",
                "Lee el resumen en 30s o pide a CertiGo AI que te lo explique."
            )
        case .german:
            return (
                "⚡ \(actor)-News: Was ändert sich?",
                "Lies die 30s-Zusammenfassung oder frag direkt CertiGo AI."
            )
        case .italian:
            return (
                "⚡ Novità \(actor): cosa cambia?",
                "Scopri il riepilogo in 30s o chiedi a CertiGo AI di spiegarlo."
            )
        case .hindi:
            return (
                "⚡ \(actor) अपडेट: क्या बदला?",
                "30 सेकंड में सारांश पढ़ें या CertiGo AI से समझें।"
            )
        case .chineseSimplified:
            return (
                "⚡ \(actor) 新动态：有哪些变化？",
                "30秒速览核心要点，或让 CertiGo AI 为你解读。"
            )
        case .korean:
            return (
                "⚡ \(actor) 새 소식: 무엇이 바뀌나요?",
                "30초 요약을 보거나 CertiGo AI에게 설명을 요청하세요."
            )
        }
    }

    private static func fsrsSpacedReviewCopy(
        language: AppLanguage
    ) -> (title: String, body: String) {
        switch language {
        case .french:
            return (
                "🧠 1 concept prêt à consolider",
                "Revois cette question clé en 45s pour l'ancrer avant l'examen."
            )
        case .english:
            return (
                "🧠 1 concept ready to lock in",
                "Review this key question in 45s to anchor it before exam day."
            )
        case .spanish:
            return (
                "🧠 1 concepto listo para fijar",
                "Repasa esta pregunta clave en 45s para anclarla antes del examen."
            )
        case .german:
            return (
                "🧠 1 Konzept bereit zum Festigen",
                "Wiederhole diese Schlüsselfrage in 45s für dein Langzeitgedächtnis."
            )
        case .italian:
            return (
                "🧠 1 concetto pronto da fissare",
                "Ripassa questa domanda chiave in 45s per fissarla prima dell'esame."
            )
        case .hindi:
            return (
                "🧠 1 कॉन्सेप्ट पक्का करने का समय",
                "परीक्षा से पहले इसे याद रखने के लिए 45 सेकंड में दोहराएं।"
            )
        case .chineseSimplified:
            return (
                "🧠 1 个核心概念待巩固",
                "花 45 秒回顾这道关键题，考前牢牢锁住记忆。"
            )
        case .korean:
            return (
                "🧠 장기 기억으로 굳힐 개념 1개",
                "시험 전 확실히 각인되도록 45초 만에 핵심 문제를 복습하세요."
            )
        }
    }

    private static func kindComebackCopy(
        language: AppLanguage
    ) -> (title: String, body: String) {
        switch language {
        case .french:
            return (
                "🛡️ Ton blason t'a gardé ta place",
                "Reprends tranquillement là où tu t'étais arrêté."
            )
        case .english:
            return (
                "🛡️ Your shield saved your spot",
                "Pick up right where you left off at your own pace."
            )
        case .spanish:
            return (
                "🛡️ Tu escudo te guardó el lugar",
                "Retoma tranquilamente justo donde lo dejaste."
            )
        case .german:
            return (
                "🛡️ Dein Wappen hält deinen Platz",
                "Mach entspannt genau dort weiter, wo du aufgehört hast."
            )
        case .italian:
            return (
                "🛡️ Il tuo scudo ha tenuto il posto",
                "Riprendi con calma esattamente da dove ti eri fermato."
            )
        case .hindi:
            return (
                "🛡️ आपके बैज ने जगह सुरक्षित रखी है",
                "जहाँ आपने छोड़ा था, वहाँ से आराम से फिर शुरू करें।"
            )
        case .chineseSimplified:
            return (
                "🛡️ 你的徽章已为你保留进度",
                "随时从上次停下的地方轻松继续学习。"
            )
        case .korean:
            return (
                "🛡️ 배지가 학습 자리를 지켜두었어요",
                "멈췄던 곳에서 부담 없이 편안하게 다시 시작하세요."
            )
        }
    }

    // MARK: - Native iOS `UNUserNotificationCenter` Integration (`Lancer en 1 tap` & `Demander à CertiGo AI`)

    #if canImport(UserNotifications)
    /// Builds the 2 interactive `UNNotificationAction` items (`Lancer en 1 tap` and `Demander à CertiGo AI`) for the active language.
    public static func makeUNNotificationActions(in language: AppLanguage = .french) -> [UNNotificationAction] {
        CertiGoSmartNotificationQuickAction.allCases.map { action in
            UNNotificationAction(
                identifier: action.rawValue,
                title: action.localizedTitle(in: language),
                options: [.foreground],
                icon: UNNotificationActionIcon(systemImageName: action.sfSymbolName)
            )
        }
    }

    /// Builds the 5 `UNNotificationCategory` objects ready to register on `UNUserNotificationCenter.current()`.
    public static func makeUNNotificationCategories(in language: AppLanguage = .french) -> Set<UNNotificationCategory> {
        let actions = makeUNNotificationActions(in: language)
        return Set(
            CertiGoSmartNotificationCategory.allCases.map { category in
                UNNotificationCategory(
                    identifier: category.rawValue,
                    actions: actions,
                    intentIdentifiers: [],
                    options: []
                )
            }
        )
    }

    /// Registers all 5 CertiGo V3 categories and quick actions on `UNUserNotificationCenter`.
    public static func registerCategoriesOnNotificationCenter(
        _ center: UNUserNotificationCenter = .current(),
        language: AppLanguage = .french
    ) {
        center.setNotificationCategories(makeUNNotificationCategories(in: language))
    }

    /// Converts a `CertiGoSmartNotificationSpec` into a configured `UNMutableNotificationContent`.
    public static func makeUNNotificationContent(from spec: CertiGoSmartNotificationSpec) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = spec.body
        content.sound = .default
        content.categoryIdentifier = spec.category.rawValue
        content.threadIdentifier = spec.category.threadIdentifier
        if #available(iOS 15.0, macOS 12.0, watchOS 8.0, *) {
            content.interruptionLevel = (spec.category == .streakRescue90s) ? .timeSensitive : .active
        }
        content.userInfo = [
            "certigo_notification_id": spec.id,
            "certigo_category": spec.category.rawValue,
            "certigo_route_code": spec.routeCode,
            "certigo_language": spec.language.rawValue,
            "certigo_primary_deeplink": spec.primaryDeepLinkURL,
            "certigo_ask_ai_deeplink": spec.askAIDeepLinkURL
        ]
        return content
    }
    #endif
}
