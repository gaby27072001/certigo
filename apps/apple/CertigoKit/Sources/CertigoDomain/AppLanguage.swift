import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Sendable, Equatable {
  case french = "fr"
  case english = "en"
  case hindi = "hi"
  case chineseSimplified = "zh-Hans"
  case korean = "ko"
  case spanish = "es"
  case italian = "it"
  case german = "de"

  public var nativeDisplayName: String {
    switch self {
    case .french: "Français"
    case .english: "English"
    case .hindi: "हिन्दी"
    case .chineseSimplified: "简体中文"
    case .korean: "한국어"
    case .spanish: "Español"
    case .italian: "Italiano"
    case .german: "Deutsch"
    }
  }

  public var locale: Locale { Locale(identifier: rawValue) }

  public func localizedDisplayName(in language: AppLanguage) -> String {
    language.locale.localizedString(forIdentifier: rawValue) ?? nativeDisplayName
  }

  public static func resolved(
    fromPreferredLanguages preferredLanguages: [String] = Locale.preferredLanguages
  ) -> AppLanguage {
    for identifier in preferredLanguages {
      let parts = identifier.replacingOccurrences(of: "_", with: "-")
        .lowercased().split(separator: "-").map(String.init)
      guard let code = parts.first else { continue }
      if code == "zh" {
        // Do not silently present simplified Chinese as a traditional-script match.
        if parts.contains("hant") { continue }
        if !parts.contains("hans")
          && parts.contains(where: { ["tw", "hk", "mo"].contains($0) })
        {
          continue
        }
        return .chineseSimplified
      }
      if let language = allCases.first(where: { $0.rawValue == code }) {
        return language
      }
    }
    return .english
  }
}
public enum AppLanguagePreference: RawRepresentable, Codable, Sendable, Equatable {
  case system
  case explicit(AppLanguage)

  // Local preference identifier, not the uncontrolled legacy web domain.
  public static let storageKey = "certigo" + ".app.interface-language.v1"

  public init?(rawValue: String) {
    if rawValue == "system" {
      self = .system
    } else if let language = AppLanguage(rawValue: rawValue) {
      self = .explicit(language)
    } else {
      return nil
    }
  }

  public var rawValue: String {
    switch self {
    case .system: "system"
    case .explicit(let language): language.rawValue
    }
  }

  public func effectiveLanguage(
    fromPreferredLanguages preferredLanguages: [String] = Locale.preferredLanguages
  ) -> AppLanguage {
    switch self {
    case .system: .resolved(fromPreferredLanguages: preferredLanguages)
    case .explicit(let language): language
    }
  }

  public static func load(from defaults: UserDefaults = .standard) -> AppLanguagePreference {
    guard let value = defaults.string(forKey: storageKey) else { return .system }
    return AppLanguagePreference(rawValue: value) ?? .system
  }

  public func save(to defaults: UserDefaults = .standard) {
    defaults.set(rawValue, forKey: Self.storageKey)
  }
}
public struct AppInterfaceCopy: Sendable, Equatable {
  public enum Key: CaseIterable, Sendable {
    case errorDeletionStateUnreadable, errorConnectionRestore, errorSignOutActivity
    case errorSignOutSDK, errorSignOutStorage, errorDeletionRequiresMicrosoft
    case errorVerificationCancelled, errorDeletionCancelResume, errorDeletionNotRequested
    case errorDeletionRecovery, errorDeletionOwnerUnknown, errorDeletionCleanup
    case errorDeletionReceipt, errorMicrosoftCancelled, errorDifferentMicrosoftAccount
    case errorAccountStatusUnknown, errorRecentAuthentication, errorDeletionUnavailable
    case errorDeletionConfiguration, errorAccountOperationUnknown
    case errorGoalSelectionPending, errorGoalChanged, errorGoalConflict
    case errorCoachRequiresAnswer, errorCoachUnavailable, errorHistoryDisagreement
    case errorReviewEvidence, errorHistorySignIn, errorHistoryDeletion
    case errorHistoryOffline, errorHistoryInvalid, errorHistoryUnavailable
    case errorDeletionReconnect, errorActivitySave, errorActivityCleared
    case errorActivityRemoval, errorActivityRestore, errorContentVersionChanged
    case errorActivityUnsafe, errorReconnect, errorConnectionUnconfirmed, errorConnectionExpired
    case errorInvalidAPIURL, errorAccountChanged, errorContentStorageFull
    case errorContentChanged, errorContentPackInvalid, errorServerUnreachable
    case errorRequestRejected, errorCapabilityUnavailable, errorSavedResponsesUnreadable
    case errorResponseStorageFull, errorSubmissionRetryUnavailable, errorOperationUnconfirmed
    case audioReadAloud, audioScopeNote, audioVoice, audioChooseVoice, audioNoVoices
    case audioSpeed, audioSlower, audioStandard, audioRead, audioPause, audioResume, audioStop
    case audioStopped, audioReading, audioPaused, audioChooseVoiceFirst, audioVoiceUnavailable
    case audioVoiceOverRead, audioPreparationFailed, audioNoText, audioPauseFailed
    case audioVoiceOverResume, audioResumeFailed
    case deletionBeforeContinuing, deletionScopeNote, deletionRetentionNote, deletionVerify
    case deletionMicrosoftRequired, deletionServerStatus, deletionSteps, deletionPendingNote
    case deletionRetryDelay, deletionCheckStatus, deletionSignInSameAccount, deletionResumeAccount
    case deletionCleanupIncomplete, deletionCompletedNote, deletionReturnToSignIn
    case deletionConfirmTitle, deletionConfirmMessage
    case deletionVerifying, deletionIdentityVerified, deletionChecking, deletionPending
    case deletionUnconfirmed, deletionCleanupAttention, deletionCompleted, deletionTitle
    case historyLoaded, historyLoadedMore, historyEvidenceNote, historyPageEmpty
    case historyRecordedScore, historyConfirmedScore, historyConfirmedScoreOnly
    case historyCorrectionNote, historyLocalDatesNote, historyLocalAcknowledgement
    case historyNoAdditional, historyLocalUnverified, historyCurrentLocal, historyCurrentSubmitted
    case historyNoBalanceChange, historyReadinessNote, historyReadinessUnknown
    case historyCoverageSnapshot, historyCoverageUnknown, historySelectionNote
    case historyGoalUnchanged, historyCoverageCount, historyQuestionCount
    case historySavedAnswers, historySubmissionRejected, historyLocalStatusNote
    case configurationDistributionOnly, configurationAppStoreBundle, configurationMissingProduction
    case configurationInvalidProduction, configurationDeclareProductionCallback
    case configurationDuplicateProductionCallback, configurationCallbackBundle
    case configurationCorrectProduction, configurationProductionValidation
    case configurationInitializationFailed, configurationIdentity, configurationAuthority
    case configurationIssuer, configurationScope, configurationAPIURL, configurationRedirect
    case configurationCallbackDeclaration, configurationCallbackCollision, configurationReview
    case configurationOptIn, configurationMissingLocal, configurationInvalidLocal
    case configurationDevelopmentOnly, configurationMissingBundle
    case configurationCallbackUnregistered, configurationCallbackDuplicate
    case configurationDerivedRedirect
    case learn, coach, social, profile, myLearning, explore, friends, teams
    case appLanguage, systemDefault, contentLanguageNote
    case signInWithMicrosoft, exploreDemo, resume, startSession, practiceAgain
    case submitAnswer, retry, loading
    case progressAndHistory, settings, accountDeletion, pending, confirmed
    case signOut, cancel, done, back, continueLearning, answer, next, previous
    case offline, pendingCorrection, noHistory, deleteAccount, demo, chooseGoal
    case categoryAll, categoryCloud, categoryAI, categoryApple, categoryData, categoryDevOps
    case categoryCyber, categoryEnterprise, categoryOther, contentLanguageFR, contentLanguageEN
    case recommendedReview, reviewReasonLowScore, reviewReasonDue, reviewReasonContinue, startReview
    case explainWithCoach, coachWorkspaceTitle, coachExplaining, coachHeadline, coachKeyPoints
    case coachRecommendation, coachPersonalization, coachSourceGrounded, coachPromptHint
    case searchPlaceholder, noMatchingTracks, clearFilters, activeGoalBadge
    case masteryNotStarted, masteryLearning, masteryPracticing, masteryMastered, masteryExamReady
    case focusArea, startFocusSession, spacedRepetitionReview, startFinalAssessment, youreReady
    case explainDifferently, whyWasIWrong, targetExamDate, initialLevel, dailyMinutesGoal
    case levelBeginner, levelIntermediate, levelAdvanced, notifications, notificationsEnabled
    case quietHours, preferredHour, maxPerDay, streakAlerts, questAlerts, leagueAlerts
    case practiceAvailable, practiceUnavailable, practiceUnavailableNote
  }

  public let language: AppLanguage

  public init(language: AppLanguage) {
    self.language = language
  }

  public var learn: String { self[.learn] }
  public var coach: String { self[.coach] }
  public var social: String { self[.social] }
  public var profile: String { self[.profile] }
  public var myLearning: String { self[.myLearning] }
  public var explore: String { self[.explore] }
  public var friends: String { self[.friends] }
  public var teams: String { self[.teams] }
  public var appLanguage: String { self[.appLanguage] }
  public var systemDefault: String { self[.systemDefault] }
  public var contentLanguageNote: String { self[.contentLanguageNote] }
  public var signInWithMicrosoft: String { self[.signInWithMicrosoft] }
  public var exploreDemo: String { self[.exploreDemo] }
  public var resume: String { self[.resume] }
  public var startSession: String { self[.startSession] }
  public var practiceAgain: String { self[.practiceAgain] }
  public var submitAnswer: String { self[.submitAnswer] }
  public var retry: String { self[.retry] }
  public var loading: String { self[.loading] }
  public var progressAndHistory: String { self[.progressAndHistory] }
  public var settings: String { self[.settings] }
  public var accountDeletion: String { self[.accountDeletion] }
  public var pending: String { self[.pending] }
  public var confirmed: String { self[.confirmed] }

  public func requestRejected(httpStatus: Int) -> String {
    self[.errorRequestRejected].replacingOccurrences(of: "{status}", with: String(httpStatus))
  }

  public func deletionProgress(completed: Int, total: Int) -> String {
    self[.deletionSteps]
      .replacingOccurrences(of: "{completed}", with: String(completed))
      .replacingOccurrences(of: "{total}", with: String(total))
  }

  public func historyLoaded(count: Int, hasMore: Bool) -> String {
    self[hasMore ? .historyLoadedMore : .historyLoaded]
      .replacingOccurrences(of: "{count}", with: String(count))
  }

  public func historyScore(scorePercent: Int, xp: Int, confirmedOnDevice: Bool) -> String {
    self[confirmedOnDevice ? .historyConfirmedScore : .historyRecordedScore]
      .replacingOccurrences(of: "{score}", with: String(scorePercent))
      .replacingOccurrences(of: "{xp}", with: String(xp))
  }

  public func confirmedScore(_ scorePercent: Int) -> String {
    self[.historyConfirmedScoreOnly].replacingOccurrences(of: "{score}", with: String(scorePercent))
  }

  public func coverageCount(completed: Int, total: Int) -> String {
    self[.historyCoverageCount]
      .replacingOccurrences(of: "{completed}", with: String(completed))
      .replacingOccurrences(of: "{total}", with: String(total))
  }

  public func questionCount(selected: Int, total: Int) -> String {
    self[.historyQuestionCount]
      .replacingOccurrences(of: "{selected}", with: String(selected))
      .replacingOccurrences(of: "{total}", with: String(total))
  }

  public func configurationValue(_ name: String, production: Bool, missing: Bool) -> String {
    let key: Key
    switch (production, missing) {
    case (true, true): key = .configurationMissingProduction
    case (true, false): key = .configurationInvalidProduction
    case (false, true): key = .configurationMissingLocal
    case (false, false): key = .configurationInvalidLocal
    }
    return self[key].replacingOccurrences(of: "{name}", with: name)
  }

  public subscript(key: Key) -> String {
    let row = translations(for: key)
    switch language {
    case .french: return row.fr
    case .english: return row.en
    case .hindi: return row.hi
    case .chineseSimplified: return row.zh
    case .korean: return row.ko
    case .spanish: return row.es
    case .italian: return row.it
    case .german: return row.de
    }
  }

  private typealias Translations = (
    fr: String, en: String, hi: String, zh: String,
    ko: String, es: String, it: String, de: String
  )

  private func translations(for key: Key) -> Translations {
    switch key {
    case .configurationDistributionOnly:
      return (
        "La connexion Microsoft est disponible uniquement dans la version Distribution.",
        "Microsoft sign-in is only enabled for the Distribution build.",
        "Microsoft साइन-इन केवल Distribution बिल्ड में उपलब्ध है।", "Microsoft 登录仅在 Distribution 构建中启用。",
        "Microsoft 로그인은 Distribution 빌드에서만 사용할 수 있습니다.",
        "El inicio de sesión Microsoft solo está habilitado en la compilación Distribution.",
        "L’accesso Microsoft è abilitato solo nella build Distribution.",
        "Die Microsoft-Anmeldung ist nur im Distribution-Build aktiviert."
      )
    case .configurationAppStoreBundle:
      return (
        "Utilisez l’identifiant de bundle App Store Certigo existant.",
        "Use the existing Certigo App Store bundle identifier.",
        "मौजूदा Certigo App Store बंडल पहचानकर्ता उपयोग करें।", "请使用现有 Certigo App Store 包标识符。",
        "기존 Certigo App Store 번들 식별자를 사용하세요.",
        "Usa el identificador de bundle existente de Certigo en App Store.",
        "Usa l’identificatore bundle App Store Certigo esistente.",
        "Verwende die bestehende Certigo-App-Store-Bundle-ID."
      )
    case .configurationMissingProduction:
      return (
        "Il manque {name} dans Distribution. Configurez l’identité de production vérifiée avant la connexion.",
        "Distribution is missing {name}. Configure the verified production identity before sign-in.",
        "Distribution में {name} नहीं है। साइन-इन से पहले सत्यापित उत्पादन पहचान कॉन्फ़िगर करें।",
        "Distribution 缺少 {name}。登录前请配置经验证的生产身份。",
        "Distribution에 {name}이 없습니다. 로그인 전에 검증된 운영 신원을 설정하세요.",
        "Falta {name} en Distribution. Configura la identidad de producción verificada antes de acceder.",
        "In Distribution manca {name}. Configura l’identità di produzione verificata prima dell’accesso.",
        "In Distribution fehlt {name}. Konfiguriere vor der Anmeldung die geprüfte Produktionsidentität."
      )
    case .configurationInvalidProduction:
      return (
        "La valeur {name} de Distribution est invalide. Corrigez la configuration de production vérifiée.",
        "Distribution has an invalid {name}. Correct the verified production configuration.",
        "Distribution में {name} अमान्य है। सत्यापित उत्पादन कॉन्फ़िगरेशन ठीक करें।",
        "Distribution 的 {name} 无效。请修正经验证的生产配置。",
        "Distribution의 {name}이 유효하지 않습니다. 검증된 운영 설정을 수정하세요.",
        "Distribution tiene un valor {name} no válido. Corrige la configuración de producción verificada.",
        "Distribution ha un valore {name} non valido. Correggi la configurazione di produzione verificata.",
        "Distribution enthält ein ungültiges {name}. Korrigiere die geprüfte Produktionskonfiguration."
      )
    case .configurationDeclareProductionCallback:
      return (
        "Déclarez le rappel Microsoft dérivé de l’application dans le fichier Info.plist de Distribution.",
        "Declare the app-derived Microsoft callback in the Distribution Info.plist.",
        "ऐप से निकला Microsoft कॉलबैक Distribution Info.plist में घोषित करें।",
        "请在 Distribution Info.plist 中声明根据应用派生的 Microsoft 回调。",
        "앱에서 파생된 Microsoft 콜백을 Distribution Info.plist에 선언하세요.",
        "Declara el callback Microsoft derivado de la app en el Info.plist de Distribution.",
        "Dichiara il callback Microsoft derivato dall’app nell’Info.plist di Distribution.",
        "Deklariere den von der App abgeleiteten Microsoft-Callback in der Distribution-Info.plist."
      )
    case .configurationDuplicateProductionCallback:
      return (
        "Le rappel Microsoft est déclaré plusieurs fois dans le fichier Info.plist de Distribution.",
        "The Microsoft callback is duplicated in the Distribution Info.plist.",
        "Microsoft कॉलबैक Distribution Info.plist में दोहराया गया है।",
        "Microsoft 回调在 Distribution Info.plist 中重复。",
        "Distribution Info.plist에 Microsoft 콜백이 중복되어 있습니다.",
        "El callback Microsoft está duplicado en el Info.plist de Distribution.",
        "Il callback Microsoft è duplicato nell’Info.plist di Distribution.",
        "Der Microsoft-Callback ist in der Distribution-Info.plist doppelt vorhanden."
      )
    case .configurationCallbackBundle:
      return (
        "Le rappel Microsoft doit correspondre à l’identifiant de bundle de cette application.",
        "The Microsoft callback must match this app's bundle identifier.",
        "Microsoft कॉलबैक इस ऐप के बंडल पहचानकर्ता से मेल खाना चाहिए।", "Microsoft 回调必须与此应用的包标识符匹配。",
        "Microsoft 콜백은 이 앱의 번들 식별자와 일치해야 합니다.",
        "El callback Microsoft debe coincidir con el identificador de bundle de esta app.",
        "Il callback Microsoft deve corrispondere all’identificatore bundle dell’app.",
        "Der Microsoft-Callback muss zur Bundle-ID dieser App passen."
      )
    case .configurationCorrectProduction:
      return (
        "Corrigez la configuration de connexion Microsoft de Distribution.",
        "Correct the Distribution Microsoft sign-in configuration.",
        "Distribution Microsoft साइन-इन कॉन्फ़िगरेशन ठीक करें।", "请修正 Distribution Microsoft 登录配置。",
        "Distribution Microsoft 로그인 설정을 수정하세요.",
        "Corrige la configuración de acceso Microsoft de Distribution.",
        "Correggi la configurazione di accesso Microsoft di Distribution.",
        "Korrigiere die Microsoft-Anmeldekonfiguration von Distribution."
      )
    case .configurationProductionValidation:
      return (
        "La configuration de connexion Microsoft de Distribution n’a pas passé la validation.",
        "The Distribution Microsoft sign-in configuration failed validation.",
        "Distribution Microsoft साइन-इन कॉन्फ़िगरेशन का सत्यापन विफल हुआ।", "Distribution Microsoft 登录配置未通过验证。",
        "Distribution Microsoft 로그인 설정의 검증에 실패했습니다.",
        "La configuración de acceso Microsoft de Distribution no superó la validación.",
        "La configurazione di accesso Microsoft di Distribution non ha superato la convalida.",
        "Die Microsoft-Anmeldekonfiguration von Distribution hat die Prüfung nicht bestanden."
      )
    case .configurationInitializationFailed:
      return (
        "La connexion Microsoft n’a pas pu être initialisée. Aucun repli sur un jeton manuel n’est disponible.",
        "Microsoft sign-in could not be initialized. No manual-token fallback is available.",
        "Microsoft साइन-इन शुरू नहीं हुआ। मैन्युअल टोकन का वैकल्पिक तरीका उपलब्ध नहीं है।",
        "无法初始化 Microsoft 登录。不提供手动令牌回退。",
        "Microsoft 로그인을 초기화하지 못했습니다. 수동 토큰 대체 수단은 없습니다.",
        "No se pudo inicializar el acceso Microsoft. No hay alternativa mediante token manual.",
        "Impossibile inizializzare l’accesso Microsoft. Non è disponibile un ripiego con token manuale.",
        "Die Microsoft-Anmeldung konnte nicht initialisiert werden. Es gibt keinen Rückfall auf manuelle Token."
      )
    case .configurationIdentity:
      return (
        "Définissez des identifiants client, locataire et audience API valides dans le schéma Xcode local.",
        "Set valid client, tenant, and API audience identifiers in the local Xcode scheme.",
        "स्थानीय Xcode स्कीम में मान्य क्लाइंट, टेनेंट और API ऑडियंस पहचानकर्ता सेट करें।",
        "请在本地 Xcode 方案中设置有效的客户端、租户和 API 受众标识符。", "로컬 Xcode 스킴에 유효한 클라이언트, 테넌트, API 대상 식별자를 설정하세요.",
        "Configura identificadores válidos de cliente, inquilino y audiencia API en el esquema Xcode local.",
        "Imposta identificatori validi di client, tenant e destinatario API nello schema Xcode locale.",
        "Setze gültige Client-, Mandanten- und API-Zielgruppen-IDs im lokalen Xcode-Schema."
      )
    case .configurationAuthority:
      return (
        "Corrigez l’autorité CIAM dans le schéma Xcode local.",
        "Correct the CIAM authority in the local Xcode scheme.", "स्थानीय Xcode स्कीम में CIAM प्राधिकरण ठीक करें।",
        "请修正本地 Xcode 方案中的 CIAM 颁发机构。", "로컬 Xcode 스킴의 CIAM 인증 기관을 수정하세요.",
        "Corrige la autoridad CIAM en el esquema Xcode local.",
        "Correggi l’autorità CIAM nello schema Xcode locale.",
        "Korrigiere die CIAM-Autorität im lokalen Xcode-Schema."
      )
    case .configurationIssuer:
      return (
        "Définissez l’émetteur correspondant au locataire et à l’autorité CIAM configurés.",
        "Set the issuer matching the configured CIAM tenant and authority.",
        "कॉन्फ़िगर CIAM टेनेंट और प्राधिकरण से मेल खाने वाला जारीकर्ता सेट करें।", "请设置与已配置 CIAM 租户和颁发机构匹配的签发者。",
        "설정된 CIAM 테넌트 및 인증 기관과 일치하는 발급자를 설정하세요.",
        "Define el emisor que coincida con el inquilino y autoridad CIAM configurados.",
        "Imposta l’emittente corrispondente al tenant e all’autorità CIAM configurati.",
        "Setze den zum konfigurierten CIAM-Mandanten und zur Autorität passenden Aussteller."
      )
    case .configurationScope:
      return (
        "Définissez une seule étendue API pour l’audience configurée dans le schéma Xcode local.",
        "Set one API scope for the configured audience in the local Xcode scheme.",
        "स्थानीय Xcode स्कीम में कॉन्फ़िगर ऑडियंस के लिए एक API स्कोप सेट करें।", "请在本地 Xcode 方案中为已配置受众设置一个 API 范围。",
        "로컬 Xcode 스킴에서 설정된 대상에 대한 API 범위 하나를 설정하세요.",
        "Define un ámbito API para la audiencia configurada en el esquema Xcode local.",
        "Imposta un ambito API per il destinatario configurato nello schema Xcode locale.",
        "Setze im lokalen Xcode-Schema einen API-Bereich für die konfigurierte Zielgruppe."
      )
    case .configurationAPIURL:
      return (
        "Définissez l’URL de base HTTPS de l’API existante, avec son chemin /api.",
        "Set the existing API HTTPS base URL, including its /api path.",
        "मौजूदा API का HTTPS बेस URL /api पथ सहित सेट करें।", "请设置现有 API 的 HTTPS 基础 URL，包括其 /api 路径。",
        "/api 경로를 포함한 기존 API HTTPS 기본 URL을 설정하세요.",
        "Define la URL base HTTPS de la API existente, incluida su ruta /api.",
        "Imposta l’URL base HTTPS dell’API esistente, incluso il percorso /api.",
        "Setze die bestehende HTTPS-Basis-URL der API einschließlich ihres /api-Pfads."
      )
    case .configurationRedirect:
      return (
        "Définissez la redirection CIAM exacte enregistrée pour cette application.",
        "Set the exact CIAM redirect registered for this app.",
        "इस ऐप के लिए पंजीकृत सही CIAM रीडायरेक्ट सेट करें।", "请设置为此应用注册的确切 CIAM 重定向。",
        "이 앱에 등록된 정확한 CIAM 리디렉션을 설정하세요.",
        "Define la redirección CIAM exacta registrada para esta app.",
        "Imposta il reindirizzamento CIAM esatto registrato per questa app.",
        "Setze die exakt für diese App registrierte CIAM-Umleitung."
      )
    case .configurationCallbackDeclaration:
      return (
        "Le schéma de rappel doit déjà être déclaré dans le fichier Info.plist de cette application.",
        "The callback scheme must already be declared in this app's Info.plist.",
        "कॉलबैक स्कीम इस ऐप की Info.plist में पहले से घोषित होनी चाहिए।", "回调方案必须已在此应用的 Info.plist 中声明。",
        "콜백 스킴은 이 앱의 Info.plist에 이미 선언되어 있어야 합니다.",
        "El esquema de callback debe estar declarado en el Info.plist de esta app.",
        "Lo schema di callback deve già essere dichiarato nell’Info.plist dell’app.",
        "Das Callback-Schema muss bereits in der Info.plist dieser App deklariert sein."
      )
    case .configurationCallbackCollision:
      return (
        "Le schéma de rappel CIAM entre en conflit avec un autre schéma de rappel de l’application.",
        "The CIAM callback scheme collides with another app callback scheme.",
        "CIAM कॉलबैक स्कीम अन्य ऐप कॉलबैक स्कीम से टकराती है।", "CIAM 回调方案与另一个应用回调方案冲突。",
        "CIAM 콜백 스킴이 다른 앱 콜백 스킴과 충돌합니다.",
        "El esquema de callback CIAM entra en conflicto con otro esquema de callback de la app.",
        "Lo schema di callback CIAM è in conflitto con un altro schema di callback dell’app.",
        "Das CIAM-Callback-Schema kollidiert mit einem anderen App-Callback-Schema."
      )
    case .configurationReview:
      return (
        "Vérifiez le schéma Xcode local et le rappel enregistré de l’application. La connexion par jeton manuel est désactivée lorsque CIAM est activé.",
        "Review the local Xcode scheme and registered app callback. Manual token sign-in is disabled while CIAM is opted in.",
        "स्थानीय Xcode स्कीम और पंजीकृत ऐप कॉलबैक जाँचें। CIAM सक्षम होने पर मैन्युअल टोकन साइन-इन बंद रहता है।",
        "请检查本地 Xcode 方案和已注册的应用回调。启用 CIAM 时，手动令牌登录被禁用。",
        "로컬 Xcode 스킴과 등록된 앱 콜백을 확인하세요. CIAM이 켜져 있으면 수동 토큰 로그인은 비활성화됩니다.",
        "Revisa el esquema Xcode local y el callback registrado. El acceso con token manual está desactivado mientras CIAM está habilitado.",
        "Controlla lo schema Xcode locale e il callback registrato. L’accesso con token manuale è disabilitato quando CIAM è attivo.",
        "Prüfe das lokale Xcode-Schema und den registrierten App-Callback. Bei aktiviertem CIAM ist die manuelle Token-Anmeldung deaktiviert."
      )
    case .configurationOptIn:
      return (
        "CERTIGO_CIAM_ENABLED doit valoir exactement true ou false.",
        "CERTIGO_CIAM_ENABLED must be exactly true or false.",
        "CERTIGO_CIAM_ENABLED का मान ठीक true या false होना चाहिए।",
        "CERTIGO_CIAM_ENABLED 必须恰好为 true 或 false。",
        "CERTIGO_CIAM_ENABLED는 정확히 true 또는 false여야 합니다.",
        "CERTIGO_CIAM_ENABLED debe ser exactamente true o false.",
        "CERTIGO_CIAM_ENABLED deve essere esattamente true o false.",
        "CERTIGO_CIAM_ENABLED muss genau true oder false sein."
      )
    case .configurationMissingLocal:
      return (
        "Définissez la valeur manquante {name} du schéma Xcode local.",
        "Set the missing local Xcode scheme value {name}.", "स्थानीय Xcode स्कीम का गायब मान {name} सेट करें।",
        "请设置本地 Xcode 方案中缺失的值 {name}。", "누락된 로컬 Xcode 스킴 값 {name}을 설정하세요.",
        "Define el valor {name} que falta en el esquema Xcode local.",
        "Imposta il valore {name} mancante nello schema Xcode locale.",
        "Setze den fehlenden Wert {name} im lokalen Xcode-Schema."
      )
    case .configurationInvalidLocal:
      return (
        "Corrigez la valeur {name} du schéma Xcode local.",
        "Correct the local Xcode scheme value {name}.", "स्थानीय Xcode स्कीम का मान {name} ठीक करें।",
        "请修正本地 Xcode 方案中的值 {name}。", "로컬 Xcode 스킴 값 {name}을 수정하세요.",
        "Corrige el valor {name} del esquema Xcode local.",
        "Correggi il valore {name} nello schema Xcode locale.",
        "Korrigiere den Wert {name} im lokalen Xcode-Schema."
      )
    case .configurationDevelopmentOnly:
      return (
        "La connexion de test CIAM ne peut être activée que dans une version de développement.",
        "CIAM test sign-in can only be enabled in a development build.",
        "CIAM परीक्षण साइन-इन केवल विकास बिल्ड में सक्षम हो सकता है।", "CIAM 测试登录只能在开发构建中启用。",
        "CIAM 테스트 로그인은 개발 빌드에서만 활성화할 수 있습니다.",
        "El acceso de prueba CIAM solo se puede habilitar en una compilación de desarrollo.",
        "L’accesso di prova CIAM può essere attivato solo in una build di sviluppo.",
        "Die CIAM-Testanmeldung kann nur in einem Entwicklungsbuild aktiviert werden."
      )
    case .configurationMissingBundle:
      return (
        "L’identifiant de bundle de l’application est indisponible ; la connexion CIAM ne peut pas être initialisée.",
        "The app bundle identifier is unavailable; CIAM sign-in cannot be initialized.",
        "ऐप का बंडल पहचानकर्ता उपलब्ध नहीं है; CIAM साइन-इन शुरू नहीं हो सकता।", "应用包标识符不可用；无法初始化 CIAM 登录。",
        "앱 번들 식별자를 사용할 수 없어 CIAM 로그인을 초기화할 수 없습니다.",
        "El identificador de bundle no está disponible; no se puede inicializar el acceso CIAM.",
        "L’identificatore bundle non è disponibile; impossibile inizializzare l’accesso CIAM.",
        "Die Bundle-ID ist nicht verfügbar; die CIAM-Anmeldung kann nicht initialisiert werden."
      )
    case .configurationCallbackUnregistered:
      return (
        "Le schéma de rappel CIAM n’est pas enregistré dans le fichier Info.plist de cette application.",
        "The CIAM callback scheme is not registered by this app's Info.plist.",
        "CIAM कॉलबैक स्कीम इस ऐप की Info.plist में पंजीकृत नहीं है।", "CIAM 回调方案未在此应用的 Info.plist 中注册。",
        "이 앱의 Info.plist에 CIAM 콜백 스킴이 등록되지 않았습니다.",
        "El esquema de callback CIAM no está registrado en el Info.plist de esta app.",
        "Lo schema di callback CIAM non è registrato nell’Info.plist dell’app.",
        "Das CIAM-Callback-Schema ist nicht in der Info.plist dieser App registriert."
      )
    case .configurationCallbackDuplicate:
      return (
        "Le schéma de rappel CIAM est déclaré plusieurs fois dans le fichier Info.plist de cette application.",
        "The CIAM callback scheme is duplicated in this app's Info.plist.",
        "CIAM कॉलबैक स्कीम इस ऐप की Info.plist में दोहराई गई है।", "CIAM 回调方案在此应用的 Info.plist 中重复。",
        "이 앱의 Info.plist에 CIAM 콜백 스킴이 중복되어 있습니다.",
        "El esquema de callback CIAM está duplicado en el Info.plist de esta app.",
        "Lo schema di callback CIAM è duplicato nell’Info.plist dell’app.",
        "Das CIAM-Callback-Schema ist in der Info.plist dieser App doppelt vorhanden."
      )
    case .configurationDerivedRedirect:
      return (
        "Utilisez la redirection msauth.<bundle-id>://auth pour cette application.",
        "Use the msauth.<bundle-id>://auth redirect for this app.",
        "इस ऐप के लिए msauth.<bundle-id>://auth रीडायरेक्ट उपयोग करें।",
        "请为此应用使用 msauth.<bundle-id>://auth 重定向。", "이 앱에 msauth.<bundle-id>://auth 리디렉션을 사용하세요.",
        "Usa la redirección msauth.<bundle-id>://auth para esta app.",
        "Usa il reindirizzamento msauth.<bundle-id>://auth per questa app.",
        "Verwende für diese App die Umleitung msauth.<bundle-id>://auth."
      )
    case .historyLoaded:
      return (
        "Sur vos appareils · {count} résumés chargés",
        "Across your devices · {count} summaries loaded", "आपके सभी डिवाइसों से · {count} सारांश लोड",
        "所有设备 · 已加载 {count} 条摘要", "모든 기기 · 요약 {count}개 불러옴",
        "En tus dispositivos · {count} resúmenes cargados",
        "Tra i tuoi dispositivi · {count} riepiloghi caricati",
        "Auf deinen Geräten · {count} Zusammenfassungen geladen"
      )
    case .historyLoadedMore:
      return (
        "Sur vos appareils · {count} résumés chargés · d’autres pages sont disponibles",
        "Across your devices · {count} summaries loaded · more pages available",
        "आपके सभी डिवाइसों से · {count} सारांश लोड · और पृष्ठ उपलब्ध", "所有设备 · 已加载 {count} 条摘要 · 还有更多页面",
        "모든 기기 · 요약 {count}개 불러옴 · 더 많은 페이지 있음",
        "En tus dispositivos · {count} resúmenes cargados · hay más páginas",
        "Tra i tuoi dispositivi · {count} riepiloghi caricati · altre pagine disponibili",
        "Auf deinen Geräten · {count} Zusammenfassungen geladen · weitere Seiten verfügbar"
      )
    case .historyEvidenceNote:
      return (
        "Ce sont les tentatives chargées, pas la couverture des questions depuis toujours. Les réponses en attente ne sont pas des résultats confirmés ; aucune moyenne ni probabilité de réussite n’est déduite.",
        "These are loaded attempts, not all-time question coverage. Pending answers are not confirmed results; no average or pass probability is inferred.",
        "ये लोड किए गए प्रयास हैं, अब तक के सभी प्रश्नों की कवरेज नहीं। लंबित उत्तर पुष्ट परिणाम नहीं हैं; कोई औसत या पास होने की संभावना नहीं निकाली जाती।",
        "这些是已加载的作答记录，并非历来题目覆盖率。待处理答案不是已确认结果；不推算平均值或通过概率。",
        "불러온 시도이며 전체 기간의 문제 학습 범위가 아닙니다. 대기 중인 답안은 확인된 결과가 아니며 평균이나 합격 확률을 추정하지 않습니다.",
        "Son intentos cargados, no la cobertura histórica de preguntas. Las respuestas pendientes no son resultados confirmados; no se infiere media ni probabilidad de aprobar.",
        "Sono tentativi caricati, non la copertura delle domande di sempre. Le risposte in attesa non sono risultati confermati; non si deducono medie o probabilità di superamento.",
        "Dies sind geladene Versuche, nicht die gesamte bisherige Fragenabdeckung. Ausstehende Antworten sind keine bestätigten Ergebnisse; Durchschnitt oder Bestehenswahrscheinlichkeit werden nicht abgeleitet."
      )
    case .historyPageEmpty:
      return (
        "Aucune tentative confirmée sur cette page. D’autres pages d’historique sont disponibles.",
        "No confirmed attempts in this page. More history is available.",
        "इस पृष्ठ पर कोई पुष्ट प्रयास नहीं है। और इतिहास उपलब्ध है।", "此页没有已确认的作答。还有更多历史记录。",
        "이 페이지에는 확인된 시도가 없습니다. 추가 기록이 있습니다.",
        "No hay intentos confirmados en esta página. Hay más historial disponible.",
        "Nessun tentativo confermato in questa pagina. Altra cronologia disponibile.",
        "Keine bestätigten Versuche auf dieser Seite. Weiterer Verlauf ist verfügbar."
      )
    case .historyRecordedScore:
      return (
        "Score enregistré : {score} % · XP gagnés : {xp}",
        "Recorded score: {score} % · Earned XP: {xp}", "दर्ज स्कोर: {score} % · अर्जित XP: {xp}",
        "记录分数：{score} % · 获得 XP：{xp}", "기록된 점수: {score} % · 획득 XP: {xp}",
        "Puntuación registrada: {score} % · XP ganados: {xp}",
        "Punteggio registrato: {score} % · XP ottenuti: {xp}",
        "Erfasster Wert: {score} % · Verdiente XP: {xp}"
      )
    case .historyConfirmedScore:
      return (
        "Score confirmé : {score} % · XP gagnés : {xp}",
        "Confirmed score: {score} % · Earned XP: {xp}", "पुष्ट स्कोर: {score} % · अर्जित XP: {xp}",
        "已确认分数：{score} % · 获得 XP：{xp}", "확인된 점수: {score} % · 획득 XP: {xp}",
        "Puntuación confirmada: {score} % · XP ganados: {xp}",
        "Punteggio confermato: {score} % · XP ottenuti: {xp}",
        "Bestätigter Wert: {score} % · Verdiente XP: {xp}"
      )
    case .historyConfirmedScoreOnly:
      return (
        "Score confirmé : {score} %", "Confirmed score: {score} %", "पुष्ट स्कोर: {score} %",
        "已确认分数：{score} %", "확인된 점수: {score} %", "Puntuación confirmada: {score} %",
        "Punteggio confermato: {score} %", "Bestätigter Wert: {score} %"
      )
    case .historyCorrectionNote:
      return (
        "Résumé confirmé par le serveur · la correction complète se trouve dans les réponses enregistrées si disponible.",
        "Server-confirmed summary · full correction is in saved answers when available.",
        "सर्वर-पुष्ट सारांश · उपलब्ध होने पर पूरा सुधार सहेजे उत्तरों में है।", "服务器确认的摘要 · 完整批改可在保存的答案中查看（如有）。",
        "서버가 확인한 요약 · 전체 채점 내용은 사용 가능한 경우 저장된 답안에 있습니다.",
        "Resumen confirmado por el servidor · la corrección completa está en respuestas guardadas cuando está disponible.",
        "Riepilogo confermato dal server · la correzione completa è nelle risposte salvate, se disponibile.",
        "Serverbestätigte Zusammenfassung · die vollständige Korrektur steht, sofern verfügbar, in den gespeicherten Antworten."
      )
    case .historyLocalDatesNote:
      return (
        "Consulter l’historique n’envoie jamais les brouillons. Les dates locales sont celles du début d’activité, pas de l’envoi au serveur.",
        "Drafts are never uploaded by viewing history. Local dates are activity start dates, not server submission times.",
        "इतिहास देखने से ड्राफ़्ट अपलोड नहीं होते। स्थानीय तारीखें गतिविधि शुरू होने की हैं, सर्वर सबमिशन की नहीं।",
        "查看历史记录不会上传草稿。本地日期是活动开始日期，不是服务器提交时间。",
        "기록을 봐도 초안은 업로드되지 않습니다. 로컬 날짜는 활동 시작일이며 서버 제출 시간이 아닙니다.",
        "Ver el historial nunca sube los borradores. Las fechas locales son de inicio de actividad, no de envío al servidor.",
        "Visualizzare la cronologia non carica le bozze. Le date locali indicano l’inizio dell’attività, non l’invio al server.",
        "Beim Ansehen des Verlaufs werden keine Entwürfe hochgeladen. Lokale Daten bezeichnen den Aktivitätsbeginn, nicht die Serverübermittlung."
      )
    case .historyLocalAcknowledgement:
      return (
        "Accusé de réception serveur enregistré localement ; absent des pages d’historique chargées.",
        "Server acknowledgement saved locally; not in the loaded history pages.",
        "सर्वर की पावती स्थानीय रूप से सहेजी गई; लोड किए इतिहास पृष्ठों में नहीं है।", "服务器回执已保存在本地；不在已加载的历史页面中。",
        "서버 수신 확인을 로컬에 저장했습니다. 불러온 기록 페이지에는 없습니다.",
        "Confirmación del servidor guardada localmente; no está en las páginas cargadas.",
        "Conferma del server salvata localmente; non presente nelle pagine caricate.",
        "Serverbestätigung lokal gespeichert; nicht in den geladenen Verlaufsseiten enthalten."
      )
    case .historyNoAdditional:
      return (
        "Aucune autre soumission enregistrée sur cet appareil.",
        "No additional saved submissions on this device.", "इस डिवाइस पर और सहेजे सबमिशन नहीं हैं।",
        "此设备上没有其他保存的提交。", "이 기기에 추가로 저장된 제출 내역이 없습니다.",
        "No hay más envíos guardados en este dispositivo.",
        "Nessun altro invio salvato su questo dispositivo.",
        "Keine weiteren gespeicherten Einreichungen auf diesem Gerät."
      )
    case .historyLocalUnverified:
      return (
        "L’affichage de l’historique local n’a pas pu être vérifié. Les réponses enregistrées restent accessibles dans Apprendre.",
        "The local history presentation could not be verified. Saved answers remain available in Learn.",
        "स्थानीय इतिहास का प्रदर्शन सत्यापित नहीं हुआ। सहेजे उत्तर सीखें में उपलब्ध हैं।", "无法验证本地历史显示。保存的答案仍可在“学习”中查看。",
        "로컬 기록 표시를 검증하지 못했습니다. 저장된 답안은 학습에서 계속 볼 수 있습니다.",
        "No se pudo verificar el historial local. Las respuestas guardadas siguen disponibles en Aprender.",
        "Impossibile verificare la cronologia locale. Le risposte salvate restano disponibili in Impara.",
        "Die lokale Verlaufsdarstellung konnte nicht geprüft werden. Gespeicherte Antworten bleiben unter Lernen verfügbar."
      )
    case .historyCurrentLocal:
      return (
        "Activité locale actuelle", "Current local activity", "वर्तमान स्थानीय गतिविधि", "当前本地活动", "현재 로컬 활동",
        "Actividad local actual", "Attività locale attuale", "Aktuelle lokale Aktivität"
      )
    case .historyCurrentSubmitted:
      return (
        "Activité envoyée actuelle", "Current submitted activity", "वर्तमान भेजी गतिविधि", "当前已提交活动",
        "현재 제출된 활동", "Actividad enviada actual", "Attività inviata attuale",
        "Aktuelle eingereichte Aktivität"
      )
    case .historyNoBalanceChange:
      return (
        "Les pages d’historique ne modifient ni votre solde, ni votre préparation, ni votre objectif actif.",
        "History pages do not update your balance, readiness or active learning goal.",
        "इतिहास पृष्ठ आपका शेष, तैयारी या सक्रिय सीखने का लक्ष्य नहीं बदलते।", "历史页面不会更新您的余额、准备度或活动学习目标。",
        "기록 페이지는 잔액, 준비도 또는 활성 학습 목표를 갱신하지 않습니다.",
        "Las páginas del historial no actualizan tu saldo, preparación ni objetivo activo.",
        "Le pagine della cronologia non aggiornano saldo, preparazione o obiettivo attivo.",
        "Verlaufsseiten aktualisieren weder Guthaben noch Bereitschaft oder aktives Lernziel."
      )
    case .historyReadinessNote:
      return (
        "La préparation est un indicateur d’apprentissage renvoyé par le serveur pour le parcours nommé, pas une probabilité calibrée de réussir l’examen. Ce contrat client ne fournit ni version de formule, ni fenêtre de preuve, ni date du dernier calcul.",
        "Readiness is a server-returned learning indicator for the named path, not a calibrated probability of passing the exam. Its formula version, evidence window and last calculation time are not supplied by this client contract.",
        "तैयारी नामित पथ के लिए सर्वर का सीखने का संकेतक है, परीक्षा पास करने की कैलिब्रेटेड संभावना नहीं। यह क्लाइंट अनुबंध सूत्र संस्करण, प्रमाण अवधि या अंतिम गणना समय नहीं देता।",
        "准备度是服务器为指定路径返回的学习指标，不是校准过的考试通过概率。此客户端契约不提供公式版本、依据时间范围或上次计算时间。",
        "준비도는 해당 경로에 대해 서버가 반환한 학습 지표이며 보정된 시험 합격 확률이 아닙니다. 이 클라이언트 계약은 공식 버전, 근거 기간, 마지막 계산 시간을 제공하지 않습니다.",
        "La preparación es un indicador de aprendizaje del servidor para la ruta indicada, no una probabilidad calibrada de aprobar. Este contrato no proporciona versión de fórmula, ventana de evidencia ni fecha del último cálculo.",
        "La preparazione è un indicatore di apprendimento del server per il percorso indicato, non una probabilità calibrata di superare l’esame. Il contratto non fornisce versione della formula, periodo delle evidenze o ora dell’ultimo calcolo.",
        "Bereitschaft ist ein Lernindikator des Servers für den benannten Pfad, keine kalibrierte Bestehenswahrscheinlichkeit. Formelversion, Nachweiszeitraum und letzter Berechnungszeitpunkt sind im Clientvertrag nicht enthalten."
      )
    case .historyReadinessUnknown:
      return (
        "La préparation est inconnue tant qu’aucun parcours n’est chargé. Inconnu ne signifie pas zéro.",
        "Readiness is unknown until a learning path is loaded. Unknown is not zero.",
        "पथ लोड होने तक तैयारी अज्ञात है। अज्ञात का अर्थ शून्य नहीं है।", "加载学习路径之前，准备度未知。未知不等于零。",
        "학습 경로를 불러오기 전에는 준비도를 알 수 없습니다. 미확인은 0이 아닙니다.",
        "La preparación es desconocida hasta cargar una ruta. Desconocido no es cero.",
        "La preparazione è sconosciuta finché non si carica un percorso. Sconosciuto non significa zero.",
        "Die Bereitschaft ist bis zum Laden eines Lernpfads unbekannt. Unbekannt ist nicht null."
      )
    case .historyCoverageSnapshot:
      return (
        "Instantané du parcours serveur chargé, pas un rapport sur une période. Les activités terminées ou maîtrisées comptent ; les unités vides ne comptent pas comme terminées.",
        "Snapshot of the currently loaded server path, not a time-period report. Completed or mastered activities count; empty units do not count as complete.",
        "यह लोड सर्वर पथ की झलक है, किसी अवधि की रिपोर्ट नहीं। पूरे या महारत प्राप्त अभ्यास गिने जाते हैं; खाली इकाइयाँ पूरी नहीं मानी जातीं।",
        "这是当前已加载服务器路径的快照，不是时段报告。计入已完成或已掌握的活动；空单元不计为完成。",
        "현재 불러온 서버 경로의 현황이며 기간별 보고서가 아닙니다. 완료하거나 숙달한 활동을 셉니다. 빈 단원은 완료로 세지 않습니다.",
        "Instantánea de la ruta cargada, no un informe por período. Cuentan las actividades completadas o dominadas; las unidades vacías no cuentan como completas.",
        "Istantanea del percorso caricato, non un rapporto su un periodo. Contano le attività completate o padroneggiate; le unità vuote non sono complete.",
        "Momentaufnahme des geladenen Serverpfads, kein Zeitraum-Bericht. Abgeschlossene oder beherrschte Aktivitäten zählen; leere Einheiten gelten nicht als abgeschlossen."
      )
    case .historyCoverageUnknown:
      return (
        "Chargez un parcours pour voir son nombre total d’activités. La couverture n’est pas encore connue.",
        "Load a learning path to see its activity denominator. Coverage is not known yet.",
        "कुल गतिविधियों की संख्या देखने के लिए पथ लोड करें। कवरेज अभी अज्ञात है।", "请加载学习路径以查看活动总数。覆盖情况尚未知。",
        "활동 전체 수를 보려면 학습 경로를 불러오세요. 학습 범위는 아직 알 수 없습니다.",
        "Carga una ruta para ver el total de actividades. La cobertura aún es desconocida.",
        "Carica un percorso per vedere il totale delle attività. La copertura non è ancora nota.",
        "Lade einen Lernpfad, um die Gesamtzahl der Aktivitäten zu sehen. Die Abdeckung ist noch unbekannt."
      )
    case .historySelectionNote:
      return (
        "Sélectionner n’est ni envoyer ni répondre correctement. Le total des questions couvertes sur tout le parcours n’est pas fourni.",
        "Selection is not submission or correctness. Total questions covered across the whole path are not provided.",
        "चयन का अर्थ सबमिशन या सही उत्तर नहीं है। पूरे पथ में कवर किए कुल प्रश्न उपलब्ध नहीं हैं।",
        "选择不等于提交或答对。不提供整个路径已覆盖的题目总数。", "선택은 제출이나 정답 여부를 뜻하지 않습니다. 전체 경로에서 다룬 문제 총수는 제공되지 않습니다.",
        "Seleccionar no equivale a enviar ni a acertar. No se proporciona el total de preguntas cubiertas en toda la ruta.",
        "Selezionare non significa inviare o rispondere correttamente. Il totale delle domande affrontate nel percorso non è fornito.",
        "Auswählen ist weder Einreichen noch Richtigkeit. Die Gesamtzahl bearbeiteter Fragen des gesamten Pfads wird nicht bereitgestellt."
      )
    case .historyGoalUnchanged:
      return (
        "Consulter cet instantané ne change jamais votre objectif actif. L’historique est séparé et peut contenir d’autres objectifs.",
        "Viewing this snapshot never switches your active goal. History is separate and may contain other goals.",
        "यह झलक देखने से सक्रिय लक्ष्य नहीं बदलता। इतिहास अलग है और उसमें दूसरे लक्ष्य हो सकते हैं।",
        "查看此快照不会切换活动目标。历史记录独立，可能包含其他目标。", "이 현황을 봐도 활성 목표는 바뀌지 않습니다. 기록은 별도이며 다른 목표를 포함할 수 있습니다.",
        "Ver esta instantánea nunca cambia tu objetivo activo. El historial es independiente y puede incluir otros objetivos.",
        "Visualizzare questa istantanea non cambia l’obiettivo attivo. La cronologia è separata e può contenere altri obiettivi.",
        "Das Ansehen dieser Momentaufnahme wechselt nie dein aktives Ziel. Der Verlauf ist getrennt und kann andere Ziele enthalten."
      )
    case .historyCoverageCount:
      return (
        "{completed} sur {total}", "{completed} of {total}", "{total} में से {completed}",
        "{completed}/{total}", "{total}개 중 {completed}개", "{completed} de {total}",
        "{completed} di {total}", "{completed} von {total}"
      )
    case .historyQuestionCount:
      return (
        "{selected} questions sur {total}", "{selected} of {total} questions",
        "{total} प्रश्नों में से {selected}", "{selected}/{total} 道题", "문제 {total}개 중 {selected}개",
        "{selected} de {total} preguntas", "{selected} di {total} domande",
        "{selected} von {total} Fragen"
      )
    case .historySavedAnswers:
      return (
        "Réponses enregistrées", "Saved answers", "सहेजे उत्तर", "保存的答案", "저장된 답안",
        "Respuestas guardadas", "Risposte salvate", "Gespeicherte Antworten"
      )
    case .historySubmissionRejected:
      return (
        "Envoi refusé · réponses conservées", "Submission rejected · answers preserved",
        "सबमिशन अस्वीकार · उत्तर सुरक्षित", "提交被拒绝 · 答案已保留", "제출 거부됨 · 답안 보존됨",
        "Envío rechazado · respuestas conservadas", "Invio rifiutato · risposte conservate",
        "Einreichung abgelehnt · Antworten bewahrt"
      )
    case .historyLocalStatusNote:
      return (
        "C’est un état local ; le serveur peut déjà avoir enregistré la tentative.",
        "This is a local status; the server may already have recorded the attempt.",
        "यह स्थानीय स्थिति है; सर्वर शायद प्रयास दर्ज कर चुका हो।", "这是本地状态；服务器可能已经记录了此次作答。",
        "이는 로컬 상태이며 서버가 이미 시도를 기록했을 수 있습니다.",
        "Es un estado local; el servidor puede haber registrado ya el intento.",
        "È uno stato locale; il server potrebbe aver già registrato il tentativo.",
        "Dies ist ein lokaler Status; der Server hat den Versuch möglicherweise bereits erfasst."
      )
    case .errorDeletionStateUnreadable:
      return (
        "L’état de suppression enregistré est illisible. L’apprentissage reste fermé. Contactez l’assistance ; aucune fin de suppression n’est supposée.",
        "The saved deletion state could not be read. Learning stays closed. Contact support; no completion is assumed.",
        "सहेजी गई हटाने की स्थिति पढ़ी नहीं जा सकी। पढ़ाई बंद रहेगी। सहायता से संपर्क करें; प्रक्रिया पूरी नहीं मानी गई है।",
        "无法读取已保存的删除状态。学习功能保持关闭。请联系支持；不视为删除完成。",
        "저장된 삭제 상태를 읽지 못했습니다. 학습은 계속 차단됩니다. 지원팀에 문의하세요. 완료된 것으로 간주하지 않습니다.",
        "No se pudo leer el estado de eliminación guardado. El aprendizaje sigue cerrado. Contacta con soporte; no se da por finalizado.",
        "Impossibile leggere lo stato di eliminazione salvato. L’apprendimento resta bloccato. Contatta l’assistenza; il completamento non è presunto.",
        "Der gespeicherte Löschstatus konnte nicht gelesen werden. Lernen bleibt gesperrt. Wende dich an den Support; ein Abschluss wird nicht angenommen."
      )
    case .errorConnectionRestore:
      return (
        "La connexion enregistrée n’a pas pu être restaurée. Reconnectez votre compte.",
        "The saved connection could not be restored. Reconnect your account.",
        "सहेजा गया कनेक्शन बहाल नहीं हुआ। अपना खाता फिर जोड़ें।",
        "无法恢复已保存的连接。请重新连接账户。",
        "저장된 연결을 복원하지 못했습니다. 계정을 다시 연결하세요.",
        "No se pudo restaurar la conexión guardada. Vuelve a conectar tu cuenta.",
        "Impossibile ripristinare la connessione salvata. Ricollega il tuo account.",
        "Die gespeicherte Verbindung konnte nicht wiederhergestellt werden. Verbinde dein Konto erneut."
      )
    case .errorSignOutActivity:
      return (
        "La session locale est fermée, mais le retrait de l’activité enregistrée n’est pas confirmé. Réessayez de vous déconnecter.",
        "The local session is closed, but saved activity removal is not confirmed. Retry signing out.",
        "स्थानीय सत्र बंद है, लेकिन सहेजी गतिविधि हटने की पुष्टि नहीं है। फिर साइन आउट करें।",
        "本地会话已关闭，但尚未确认保存的活动已移除。请重试退出登录。",
        "로컬 세션은 닫혔지만 저장된 활동 제거는 확인되지 않았습니다. 로그아웃을 다시 시도하세요.",
        "La sesión local está cerrada, pero no se confirmó la eliminación de la actividad guardada. Reintenta cerrar sesión.",
        "La sessione locale è chiusa, ma la rimozione dell’attività salvata non è confermata. Riprova a uscire.",
        "Die lokale Sitzung ist geschlossen, aber das Entfernen gespeicherter Aktivitäten ist nicht bestätigt. Melde dich erneut ab."
      )
    case .errorSignOutSDK:
      return (
        "La session locale est fermée, mais le retrait du compte du SDK n’est pas confirmé. Réessayez de vous déconnecter.",
        "The local session is closed, but SDK account removal is not confirmed. Retry signing out.",
        "स्थानीय सत्र बंद है, लेकिन SDK से खाता हटने की पुष्टि नहीं है। फिर साइन आउट करें।",
        "本地会话已关闭，但尚未确认 SDK 账户已移除。请重试退出登录。",
        "로컬 세션은 닫혔지만 SDK 계정 제거는 확인되지 않았습니다. 로그아웃을 다시 시도하세요.",
        "La sesión local está cerrada, pero no se confirmó la eliminación de la cuenta del SDK. Reintenta cerrar sesión.",
        "La sessione locale è chiusa, ma la rimozione dell’account dall’SDK non è confermata. Riprova a uscire.",
        "Die lokale Sitzung ist geschlossen, aber das Entfernen des SDK-Kontos ist nicht bestätigt. Melde dich erneut ab."
      )
    case .errorSignOutStorage:
      return (
        "Le stockage sécurisé n’a pas confirmé la déconnexion. Réessayez avant de fermer l’application.",
        "Secure storage did not confirm sign-out. Retry before closing the app.",
        "सुरक्षित संग्रहण ने साइन आउट की पुष्टि नहीं की। ऐप बंद करने से पहले फिर कोशिश करें।",
        "安全存储未确认退出登录。请在关闭应用前重试。",
        "보안 저장소에서 로그아웃을 확인하지 못했습니다. 앱을 닫기 전에 다시 시도하세요.",
        "El almacenamiento seguro no confirmó el cierre de sesión. Reinténtalo antes de cerrar la aplicación.",
        "L’archiviazione sicura non ha confermato l’uscita. Riprova prima di chiudere l’app.",
        "Der sichere Speicher hat die Abmeldung nicht bestätigt. Versuche es vor dem Schließen der App erneut."
      )
    case .errorDeletionRequiresMicrosoft:
      return (
        "La suppression distante exige une connexion Microsoft configurée. La démo et les jetons manuels de développement ne peuvent pas vérifier une identité récente.",
        "Remote deletion requires a configured Microsoft sign-in. Demo and manual development tokens cannot verify recent identity.",
        "दूरस्थ रूप से हटाने के लिए कॉन्फ़िगर किया हुआ Microsoft साइन-इन चाहिए। डेमो और मैन्युअल विकास टोकन हाल की पहचान सत्यापित नहीं कर सकते।",
        "远程删除需要已配置的 Microsoft 登录。演示和手动开发令牌无法验证近期身份。",
        "원격 삭제에는 설정된 Microsoft 로그인이 필요합니다. 데모와 수동 개발 토큰으로는 최근 신원을 확인할 수 없습니다.",
        "La eliminación remota requiere un inicio de sesión Microsoft configurado. La demo y los tokens manuales de desarrollo no verifican la identidad reciente.",
        "L’eliminazione remota richiede un accesso Microsoft configurato. La demo e i token manuali di sviluppo non verificano l’identità recente.",
        "Für die Remote-Löschung ist eine konfigurierte Microsoft-Anmeldung erforderlich. Demo und manuelle Entwicklungstoken können keine aktuelle Identität bestätigen."
      )
    case .errorVerificationCancelled:
      return (
        "La vérification d’identité a été annulée. Vérifiez à nouveau avant de confirmer la suppression.",
        "Identity verification was cancelled. Verify again before confirming deletion.",
        "पहचान सत्यापन रद्द किया गया। हटाने की पुष्टि से पहले फिर सत्यापित करें।",
        "身份验证已取消。请重新验证后再确认删除。",
        "신원 확인이 취소되었습니다. 삭제를 확정하기 전에 다시 확인하세요.",
        "Se canceló la verificación de identidad. Verifica de nuevo antes de confirmar la eliminación.",
        "Verifica dell’identità annullata. Verifica di nuovo prima di confermare l’eliminazione.",
        "Die Identitätsprüfung wurde abgebrochen. Prüfe deine Identität vor der Löschbestätigung erneut."
      )
    case .errorDeletionCancelResume:
      return (
        "La suppression n’a pas été envoyée, mais la session locale n’a pas pu reprendre. Réessayez l’annulation.",
        "Deletion was not submitted, but the local session could not be resumed. Retry cancellation.",
        "हटाने का अनुरोध नहीं भेजा गया, लेकिन स्थानीय सत्र फिर शुरू नहीं हुआ। रद्द करने का फिर प्रयास करें।",
        "未提交删除请求，但无法恢复本地会话。请重试取消。",
        "삭제 요청은 제출되지 않았지만 로컬 세션을 재개하지 못했습니다. 취소를 다시 시도하세요.",
        "No se envió la eliminación, pero no se pudo reanudar la sesión local. Reintenta la cancelación.",
        "L’eliminazione non è stata inviata, ma la sessione locale non è stata ripresa. Riprova ad annullare.",
        "Die Löschung wurde nicht angefordert, aber die lokale Sitzung konnte nicht fortgesetzt werden. Versuche den Abbruch erneut."
      )
    case .errorDeletionNotRequested:
      return (
        "Le serveur ne signale aucune demande de suppression. Connectez-vous au même compte et vérifiez votre identité avant une nouvelle confirmation.",
        "The server reports no deletion request. Sign in to the same account and verify identity before a new confirmation.",
        "सर्वर पर हटाने का कोई अनुरोध नहीं है। नई पुष्टि से पहले उसी खाते से साइन इन करके पहचान सत्यापित करें।",
        "服务器报告没有删除请求。请登录同一账户并验证身份，然后再重新确认。",
        "서버에 삭제 요청이 없습니다. 다시 확정하기 전에 같은 계정으로 로그인하고 신원을 확인하세요.",
        "El servidor no registra ninguna solicitud de eliminación. Accede a la misma cuenta y verifica tu identidad antes de confirmar de nuevo.",
        "Il server non segnala richieste di eliminazione. Accedi allo stesso account e verifica l’identità prima di una nuova conferma.",
        "Der Server meldet keinen Löschantrag. Melde dich vor einer neuen Bestätigung mit demselben Konto an und bestätige deine Identität."
      )
    case .errorDeletionRecovery:
      return (
        "Aucune suppression n’est enregistrée, mais la récupération locale n’a pas abouti. Réessayez ; aucune donnée n’a été retirée.",
        "No deletion is recorded, but local recovery could not finish. Retry; no data was removed.",
        "कोई हटाना दर्ज नहीं है, लेकिन स्थानीय बहाली पूरी नहीं हुई। फिर कोशिश करें; कोई डेटा नहीं हटाया गया।",
        "没有删除记录，但本地恢复未完成。请重试；未移除任何数据。",
        "기록된 삭제는 없지만 로컬 복구를 완료하지 못했습니다. 다시 시도하세요. 데이터는 제거되지 않았습니다.",
        "No hay eliminación registrada, pero no se pudo completar la recuperación local. Reinténtalo; no se eliminó ningún dato.",
        "Non risulta alcuna eliminazione, ma il recupero locale non è terminato. Riprova; nessun dato è stato rimosso.",
        "Es ist keine Löschung verzeichnet, aber die lokale Wiederherstellung konnte nicht abgeschlossen werden. Versuche es erneut; keine Daten wurden entfernt."
      )
    case .errorDeletionOwnerUnknown:
      return (
        "La suppression du compte est confirmée, mais cet appareil n’a aucun propriétaire local vérifié. Le nettoyage local n’est pas confirmé ; contactez l’assistance.",
        "Account deletion is confirmed, but this device has no verified local owner binding. Local cleanup is unconfirmed; contact support.",
        "खाता हटने की पुष्टि है, लेकिन इस डिवाइस पर सत्यापित स्थानीय स्वामी नहीं है। स्थानीय सफ़ाई अपुष्ट है; सहायता से संपर्क करें।",
        "账户删除已确认，但此设备没有经过验证的本地所有者绑定。本地清理尚未确认；请联系支持。",
        "계정 삭제는 확인되었지만 이 기기의 로컬 소유자 연결이 검증되지 않았습니다. 로컬 정리는 미확인 상태입니다. 지원팀에 문의하세요.",
        "Se confirmó la eliminación de la cuenta, pero este dispositivo no tiene un propietario local verificado. La limpieza local no está confirmada; contacta con soporte.",
        "Eliminazione dell’account confermata, ma questo dispositivo non ha un proprietario locale verificato. Pulizia locale non confermata; contatta l’assistenza.",
        "Die Kontolöschung ist bestätigt, aber auf diesem Gerät fehlt eine bestätigte lokale Eigentümerbindung. Die lokale Bereinigung ist unbestätigt; kontaktiere den Support."
      )
    case .errorDeletionCleanup:
      return (
        "Compte supprimé ; certaines données de cet appareil n’ont pas pu être retirées. Réessayez le nettoyage. Aucune nouvelle demande de suppression serveur ne sera envoyée.",
        "Account deleted; some data on this device could not be removed. Retry cleanup. No further server deletion request will be sent.",
        "खाता हट गया; इस डिवाइस का कुछ डेटा नहीं हट सका। सफ़ाई फिर करें। सर्वर को हटाने का कोई नया अनुरोध नहीं भेजा जाएगा।",
        "账户已删除；此设备上的部分数据未能移除。请重试清理。不会再发送服务器删除请求。",
        "계정은 삭제되었지만 이 기기의 일부 데이터를 제거하지 못했습니다. 정리를 다시 시도하세요. 서버 삭제 요청은 다시 보내지 않습니다.",
        "Cuenta eliminada; no se pudieron borrar algunos datos de este dispositivo. Reintenta la limpieza. No se enviará otra solicitud de eliminación al servidor.",
        "Account eliminato; alcuni dati sul dispositivo non sono stati rimossi. Riprova la pulizia. Non verrà inviata un’altra richiesta di eliminazione al server.",
        "Konto gelöscht; einige Daten auf diesem Gerät konnten nicht entfernt werden. Wiederhole die Bereinigung. Es wird kein weiterer Löschantrag an den Server gesendet."
      )
    case .errorDeletionReceipt:
      return (
        "Le reçu de fin n’a pas pu être effacé. Réessayez l’acquittement.",
        "The completion receipt could not be cleared. Retry acknowledgement.",
        "पूर्णता की रसीद हटाई नहीं जा सकी। पावती देने का फिर प्रयास करें।",
        "无法清除完成回执。请重新确认回执。",
        "완료 영수증을 지우지 못했습니다. 수신 확인을 다시 시도하세요.",
        "No se pudo borrar el recibo de finalización. Reintenta su confirmación.",
        "Impossibile cancellare la ricevuta di completamento. Riprova a confermarne la ricezione.",
        "Die Abschlussbestätigung konnte nicht entfernt werden. Bestätige den Erhalt erneut."
      )
    case .errorMicrosoftCancelled:
      return (
        "La vérification Microsoft a été annulée. Rien n’a été envoyé.",
        "Microsoft verification was cancelled. Nothing was submitted.",
        "Microsoft सत्यापन रद्द हुआ। कुछ भी नहीं भेजा गया।",
        "Microsoft 验证已取消。未提交任何内容。",
        "Microsoft 확인이 취소되었습니다. 아무것도 제출되지 않았습니다.",
        "Se canceló la verificación de Microsoft. No se envió nada.",
        "Verifica Microsoft annullata. Non è stato inviato nulla.",
        "Die Microsoft-Prüfung wurde abgebrochen. Es wurde nichts übermittelt."
      )
    case .errorDifferentMicrosoftAccount:
      return (
        "Un autre compte Microsoft a été renvoyé. Connectez-vous avec le compte d’origine ; aucune suppression n’a été envoyée pour cette identité.",
        "A different Microsoft account was returned. Sign in with the original account; no deletion was submitted for this identity.",
        "अलग Microsoft खाता मिला। मूल खाते से साइन इन करें; इस पहचान के लिए हटाने का अनुरोध नहीं भेजा गया।",
        "返回了不同的 Microsoft 账户。请使用原账户登录；未为此身份提交删除请求。",
        "다른 Microsoft 계정이 반환되었습니다. 원래 계정으로 로그인하세요. 이 신원에 대한 삭제 요청은 제출되지 않았습니다.",
        "Se recibió otra cuenta Microsoft. Accede con la cuenta original; no se solicitó la eliminación para esta identidad.",
        "È stato restituito un altro account Microsoft. Accedi con quello originale; non è stata richiesta alcuna eliminazione per questa identità.",
        "Ein anderes Microsoft-Konto wurde zurückgegeben. Melde dich mit dem ursprünglichen Konto an; für diese Identität wurde keine Löschung angefordert."
      )
    case .errorAccountStatusUnknown:
      return (
        "L’état du compte n’est pas confirmé. Connectez-vous avec le même compte Microsoft pour le vérifier. Un jeton refusé ne prouve pas la suppression.",
        "Account status is unconfirmed. Sign in with the same Microsoft account to check it. A rejected token does not prove deletion.",
        "खाते की स्थिति अपुष्ट है। जाँचने के लिए उसी Microsoft खाते से साइन इन करें। टोकन अस्वीकार होना हटने का प्रमाण नहीं है।",
        "账户状态未确认。请使用同一 Microsoft 账户登录以检查。令牌被拒绝并不能证明账户已删除。",
        "계정 상태가 확인되지 않았습니다. 같은 Microsoft 계정으로 로그인해 확인하세요. 토큰 거부는 삭제의 증거가 아닙니다.",
        "El estado de la cuenta no está confirmado. Accede con la misma cuenta Microsoft para comprobarlo. Un token rechazado no demuestra la eliminación.",
        "Stato dell’account non confermato. Accedi con lo stesso account Microsoft per verificarlo. Un token rifiutato non prova l’eliminazione.",
        "Der Kontostatus ist unbestätigt. Prüfe ihn durch Anmeldung mit demselben Microsoft-Konto. Ein abgelehntes Token beweist keine Löschung."
      )
    case .errorRecentAuthentication:
      return (
        "L’authentification Microsoft récente a été refusée. Vérifiez à nouveau votre identité. Aucune suppression n’est confirmée.",
        "Recent Microsoft authentication was not accepted. Verify identity again. No deletion is confirmed.",
        "हाल का Microsoft प्रमाणीकरण स्वीकार नहीं हुआ। पहचान फिर सत्यापित करें। हटने की पुष्टि नहीं है।",
        "近期 Microsoft 身份认证未被接受。请重新验证身份。尚未确认删除。",
        "최근 Microsoft 인증이 수락되지 않았습니다. 신원을 다시 확인하세요. 삭제는 확인되지 않았습니다.",
        "No se aceptó la autenticación reciente de Microsoft. Verifica de nuevo tu identidad. No se confirmó ninguna eliminación.",
        "L’autenticazione Microsoft recente non è stata accettata. Verifica di nuovo l’identità. Nessuna eliminazione è confermata.",
        "Die aktuelle Microsoft-Authentifizierung wurde nicht akzeptiert. Bestätige deine Identität erneut. Eine Löschung ist nicht bestätigt."
      )
    case .errorDeletionUnavailable:
      return (
        "La suppression du compte est indisponible sur ce service. Aucune donnée locale n’a été retirée.",
        "Account deletion is unavailable on this service. No local data was removed.",
        "इस सेवा पर खाता हटाना उपलब्ध नहीं है। कोई स्थानीय डेटा नहीं हटाया गया।",
        "此服务不支持删除账户。未移除任何本地数据。",
        "이 서비스에서는 계정 삭제를 사용할 수 없습니다. 로컬 데이터는 제거되지 않았습니다.",
        "La eliminación de cuentas no está disponible en este servicio. No se eliminó ningún dato local.",
        "L’eliminazione dell’account non è disponibile su questo servizio. Nessun dato locale è stato rimosso.",
        "Die Kontolöschung ist in diesem Dienst nicht verfügbar. Es wurden keine lokalen Daten entfernt."
      )
    case .errorDeletionConfiguration:
      return (
        "La suppression du compte exige la configuration vérifiée du service /api. Contactez l’assistance ; aucune demande n’a été envoyée.",
        "Account deletion requires the verified /api service configuration. Contact support; no request was sent.",
        "खाता हटाने के लिए सत्यापित /api सेवा कॉन्फ़िगरेशन चाहिए। सहायता से संपर्क करें; कोई अनुरोध नहीं भेजा गया।",
        "删除账户需要经过验证的 /api 服务配置。请联系支持；未发送请求。",
        "계정 삭제에는 검증된 /api 서비스 설정이 필요합니다. 지원팀에 문의하세요. 요청은 전송되지 않았습니다.",
        "La eliminación requiere la configuración verificada del servicio /api. Contacta con soporte; no se envió ninguna solicitud.",
        "L’eliminazione richiede la configurazione verificata del servizio /api. Contatta l’assistenza; nessuna richiesta è stata inviata.",
        "Die Kontolöschung erfordert eine geprüfte /api-Dienstkonfiguration. Kontaktiere den Support; es wurde keine Anfrage gesendet."
      )
    case .errorAccountOperationUnknown:
      return (
        "L’opération sur le compte n’est pas confirmée. Vérifiez son état avant de réessayer. Les données locales ont été conservées.",
        "The account operation was not confirmed. Check status before retrying. Local data was preserved.",
        "खाते की कार्रवाई की पुष्टि नहीं हुई। फिर कोशिश करने से पहले स्थिति जाँचें। स्थानीय डेटा सुरक्षित रखा गया।",
        "账户操作未确认。重试前请检查状态。本地数据已保留。",
        "계정 작업이 확인되지 않았습니다. 다시 시도하기 전에 상태를 확인하세요. 로컬 데이터는 보존되었습니다.",
        "No se confirmó la operación de la cuenta. Comprueba su estado antes de reintentar. Los datos locales se conservaron.",
        "Operazione sull’account non confermata. Controlla lo stato prima di riprovare. I dati locali sono stati conservati.",
        "Der Kontovorgang wurde nicht bestätigt. Prüfe vor einem erneuten Versuch den Status. Lokale Daten wurden bewahrt."
      )
    case .errorGoalSelectionPending:
      return (
        "Votre choix d’objectif précédent n’est pas confirmé. Réessayez ce même objectif avant d’en choisir un autre.",
        "Your previous goal selection is not confirmed. Retry that same goal before choosing another.",
        "पिछले लक्ष्य चयन की पुष्टि नहीं हुई। दूसरा चुनने से पहले उसी लक्ष्य का फिर प्रयास करें।",
        "上次目标选择未确认。请选择同一目标重试，再选择其他目标。",
        "이전 목표 선택이 확인되지 않았습니다. 다른 목표를 고르기 전에 같은 목표를 다시 시도하세요.",
        "Tu selección anterior no está confirmada. Reintenta ese mismo objetivo antes de elegir otro.",
        "La scelta precedente non è confermata. Riprova lo stesso obiettivo prima di sceglierne un altro.",
        "Deine vorherige Zielauswahl ist unbestätigt. Versuche dasselbe Ziel erneut, bevor du ein anderes auswählst."
      )
    case .errorGoalChanged:
      return (
        "Votre objectif actif a changé ailleurs. L’objectif actuel a été rechargé ; sélectionnez à nouveau pour confirmer un autre objectif.",
        "Your active goal changed elsewhere. The current goal was reloaded; choose again to confirm a different goal.",
        "आपका सक्रिय लक्ष्य कहीं और बदला गया। वर्तमान लक्ष्य फिर लोड हुआ; अलग लक्ष्य की पुष्टि के लिए फिर चुनें।",
        "活动目标已在其他位置更改。已重新加载当前目标；请重新选择以确认其他目标。",
        "다른 곳에서 활성 목표가 변경되었습니다. 현재 목표를 다시 불러왔습니다. 다른 목표를 확정하려면 다시 선택하세요.",
        "Tu objetivo activo cambió en otro lugar. Se recargó el actual; elige de nuevo para confirmar otro.",
        "Il tuo obiettivo attivo è cambiato altrove. È stato ricaricato quello attuale; scegli di nuovo per confermarne un altro.",
        "Dein aktives Ziel wurde andernorts geändert. Das aktuelle Ziel wurde neu geladen; wähle erneut, um ein anderes Ziel zu bestätigen."
      )
    case .errorGoalConflict:
      return (
        "Votre choix d’objectif est en conflit et l’objectif actuel n’a pas pu être rechargé. Réessayez le même choix pour réconcilier l’état ; aucun changement n’est confirmé.",
        "Your goal selection conflicted and the current goal could not be reloaded. Retry the same selection to reconcile; no change is confirmed.",
        "लक्ष्य चयन में टकराव हुआ और वर्तमान लक्ष्य फिर लोड नहीं हुआ। स्थिति मिलाने के लिए वही चयन दोहराएँ; बदलाव की पुष्टि नहीं है।",
        "目标选择发生冲突，且无法重新加载当前目标。请重试同一选择以协调状态；未确认任何更改。",
        "목표 선택이 충돌했고 현재 목표를 다시 불러오지 못했습니다. 상태를 맞추려면 같은 선택을 다시 시도하세요. 변경은 확인되지 않았습니다.",
        "Hubo un conflicto y no se pudo recargar el objetivo actual. Reintenta la misma selección para reconciliar el estado; no se confirma ningún cambio.",
        "Conflitto nella scelta; impossibile ricaricare l’obiettivo attuale. Riprova la stessa scelta per riconciliare lo stato; nessuna modifica è confermata.",
        "Die Zielauswahl geriet in Konflikt und das aktuelle Ziel konnte nicht neu geladen werden. Wiederhole dieselbe Auswahl zum Abgleich; keine Änderung ist bestätigt."
      )
    case .errorCoachRequiresAnswer:
      return (
        "Une réponse confirmée est requise avant de demander l’aide du Coach.",
        "A confirmed answer is required before requesting Coach help.",
        "मार्गदर्शक से मदद माँगने से पहले उत्तर की पुष्टि ज़रूरी है।",
        "请求教练帮助前，需要已确认的答案。",
        "코치의 도움을 요청하려면 확인된 답안이 필요합니다.",
        "Se requiere una respuesta confirmada antes de pedir ayuda al entrenador.",
        "Serve una risposta confermata prima di chiedere aiuto al Coach.",
        "Für die Coach-Hilfe ist eine bestätigte Antwort erforderlich."
      )
    case .errorCoachUnavailable:
      return (
        "Le Coach n’a pas pu confirmer une explication. Réessayez.",
        "Coach could not confirm an explanation. Please retry.",
        "मार्गदर्शक स्पष्टीकरण की पुष्टि नहीं कर सका। फिर कोशिश करें।",
        "教练未能确认解释。请重试。",
        "코치가 설명을 확인하지 못했습니다. 다시 시도하세요.",
        "El entrenador no pudo confirmar una explicación. Reinténtalo.",
        "Il Coach non ha potuto confermare una spiegazione. Riprova.",
        "Der Coach konnte keine Erklärung bestätigen. Versuche es erneut."
      )
    case .errorHistoryDisagreement:
      return (
        "Les entrées d’historique divergent. Les réponses enregistrées ont été conservées. Actualisez ou contactez l’assistance.",
        "History records disagree. Saved answers were preserved. Refresh or contact support.",
        "इतिहास रिकॉर्ड मेल नहीं खाते। सहेजे उत्तर सुरक्षित रखे गए। रीफ़्रेश करें या सहायता से संपर्क करें।",
        "历史记录不一致。已保留保存的答案。请刷新或联系支持。",
        "기록이 서로 일치하지 않습니다. 저장된 답안은 보존되었습니다. 새로 고치거나 지원팀에 문의하세요.",
        "Los registros del historial no coinciden. Se conservaron las respuestas guardadas. Actualiza o contacta con soporte.",
        "I dati della cronologia non coincidono. Le risposte salvate sono state conservate. Aggiorna o contatta l’assistenza.",
        "Die Verlaufseinträge widersprechen sich. Gespeicherte Antworten wurden bewahrt. Aktualisiere oder kontaktiere den Support."
      )
    case .errorReviewEvidence:
      return (
        "Les preuves de révision n’ont pas pu être vérifiées. Actualisez l’historique confirmé.",
        "Review evidence could not be verified. Refresh confirmed history.",
        "दोहराव के प्रमाण सत्यापित नहीं हो सके। पुष्ट इतिहास रीफ़्रेश करें।",
        "无法验证复习依据。请刷新已确认的历史记录。",
        "복습 근거를 검증하지 못했습니다. 확인된 기록을 새로 고치세요.",
        "No se pudo verificar la evidencia del repaso. Actualiza el historial confirmado.",
        "Impossibile verificare le evidenze del ripasso. Aggiorna la cronologia confermata.",
        "Die Wiederholungsnachweise konnten nicht geprüft werden. Aktualisiere den bestätigten Verlauf."
      )
    case .errorHistorySignIn:
      return (
        "Reconnectez-vous pour charger l’historique confirmé. Le travail local a été conservé.",
        "Sign in again to load confirmed history. Local work was preserved.",
        "पुष्ट इतिहास लोड करने के लिए फिर साइन इन करें। स्थानीय काम सुरक्षित रखा गया।",
        "请重新登录以加载已确认的历史记录。本地工作已保留。",
        "확인된 기록을 불러오려면 다시 로그인하세요. 로컬 작업은 보존되었습니다.",
        "Vuelve a iniciar sesión para cargar el historial confirmado. Se conservó el trabajo local.",
        "Accedi di nuovo per caricare la cronologia confermata. Il lavoro locale è stato conservato.",
        "Melde dich erneut an, um den bestätigten Verlauf zu laden. Lokale Arbeit wurde bewahrt."
      )
    case .errorHistoryDeletion:
      return (
        "La suppression du compte est en cours. L’apprentissage est fermé ; vérifiez l’état de suppression.",
        "Account deletion is in progress. Learning is closed; check deletion status.",
        "खाता हटाना जारी है। पढ़ाई बंद है; हटाने की स्थिति जाँचें।",
        "账户正在删除。学习功能已关闭；请检查删除状态。",
        "계정 삭제가 진행 중입니다. 학습은 차단되었습니다. 삭제 상태를 확인하세요.",
        "La eliminación de la cuenta está en curso. El aprendizaje está cerrado; comprueba el estado de eliminación.",
        "Eliminazione dell’account in corso. L’apprendimento è bloccato; controlla lo stato dell’eliminazione.",
        "Die Kontolöschung läuft. Lernen ist gesperrt; prüfe den Löschstatus."
      )
    case .errorHistoryOffline:
      return (
        "L’historique est hors ligne. Les résumés déjà chargés peuvent être anciens. Le travail local reste sur cet appareil.",
        "History is offline. Previously loaded summaries may be stale. Local work remains on this device.",
        "इतिहास ऑफ़लाइन है। पहले लोड सारांश पुराने हो सकते हैं। स्थानीय काम इसी डिवाइस पर है।",
        "历史记录处于离线状态。先前加载的摘要可能已过时。本地工作仍保留在此设备上。",
        "기록이 오프라인 상태입니다. 이전에 불러온 요약은 오래되었을 수 있습니다. 로컬 작업은 이 기기에 남아 있습니다.",
        "El historial está sin conexión. Los resúmenes cargados pueden estar desactualizados. El trabajo local sigue en este dispositivo.",
        "La cronologia è offline. I riepiloghi caricati potrebbero essere obsoleti. Il lavoro locale resta sul dispositivo.",
        "Der Verlauf ist offline. Geladene Zusammenfassungen können veraltet sein. Lokale Arbeit bleibt auf diesem Gerät."
      )
    case .errorHistoryInvalid:
      return (
        "Les entrées d’historique n’ont pas pu être vérifiées. Les réponses enregistrées ont été conservées. Actualisez ou contactez l’assistance.",
        "History records could not be verified. Saved answers were preserved. Refresh or contact support.",
        "इतिहास रिकॉर्ड सत्यापित नहीं हुए। सहेजे उत्तर सुरक्षित रखे गए। रीफ़्रेश करें या सहायता से संपर्क करें।",
        "无法验证历史记录。已保留保存的答案。请刷新或联系支持。",
        "기록을 검증하지 못했습니다. 저장된 답안은 보존되었습니다. 새로 고치거나 지원팀에 문의하세요.",
        "No se pudo verificar el historial. Se conservaron las respuestas guardadas. Actualiza o contacta con soporte.",
        "Impossibile verificare la cronologia. Le risposte salvate sono state conservate. Aggiorna o contatta l’assistenza.",
        "Die Verlaufseinträge konnten nicht geprüft werden. Gespeicherte Antworten wurden bewahrt. Aktualisiere oder kontaktiere den Support."
      )
    case .errorHistoryUnavailable:
      return (
        "L’historique confirmé est indisponible. Les résumés déjà chargés peuvent être anciens. Relancez explicitement la demande.",
        "Confirmed history is unavailable. Previously loaded summaries may be stale. Retry explicitly.",
        "पुष्ट इतिहास उपलब्ध नहीं है। पहले लोड सारांश पुराने हो सकते हैं। स्वयं फिर प्रयास करें।",
        "已确认的历史记录不可用。先前加载的摘要可能已过时。请主动重试。",
        "확인된 기록을 사용할 수 없습니다. 이전 요약은 오래되었을 수 있습니다. 직접 다시 시도하세요.",
        "El historial confirmado no está disponible. Los resúmenes cargados pueden estar desactualizados. Reintenta explícitamente.",
        "Cronologia confermata non disponibile. I riepiloghi caricati potrebbero essere obsoleti. Riprova esplicitamente.",
        "Der bestätigte Verlauf ist nicht verfügbar. Geladene Zusammenfassungen können veraltet sein. Starte den Versuch ausdrücklich erneut."
      )
    case .errorDeletionReconnect:
      return (
        "La suppression est en cours. Reconnectez le même compte Microsoft pour vérifier son état. Aucune donnée locale n’a été retirée.",
        "Deletion is in progress. Reconnect with the same Microsoft account to check status. No local data was removed.",
        "हटाना जारी है। स्थिति जाँचने के लिए वही Microsoft खाता फिर जोड़ें। कोई स्थानीय डेटा नहीं हटाया गया।",
        "删除正在进行。请重新连接同一 Microsoft 账户以检查状态。未移除本地数据。",
        "삭제가 진행 중입니다. 같은 Microsoft 계정을 다시 연결해 상태를 확인하세요. 로컬 데이터는 제거되지 않았습니다.",
        "La eliminación está en curso. Reconecta la misma cuenta Microsoft para comprobar el estado. No se eliminó ningún dato local.",
        "Eliminazione in corso. Ricollega lo stesso account Microsoft per controllare lo stato. Nessun dato locale è stato rimosso.",
        "Die Löschung läuft. Verbinde dasselbe Microsoft-Konto erneut, um den Status zu prüfen. Keine lokalen Daten wurden entfernt."
      )
    case .errorActivitySave:
      return (
        "Cette activité n’a pas pu être enregistrée pour être rouverte. Gardez l’application ouverte et réessayez votre sélection.",
        "This activity could not be saved for reopening. Keep the app open and retry your selection.",
        "यह गतिविधि फिर खोलने के लिए सहेजी नहीं जा सकी। ऐप खुला रखें और चयन फिर करें।",
        "无法保存此活动以便重新打开。请保持应用开启并重试选择。",
        "다시 열 수 있도록 활동을 저장하지 못했습니다. 앱을 열어 둔 채 선택을 다시 시도하세요.",
        "No se pudo guardar esta actividad para reabrirla. Mantén la aplicación abierta y reintenta la selección.",
        "Impossibile salvare l’attività per riaprirla. Tieni aperta l’app e riprova la selezione.",
        "Diese Aktivität konnte nicht zum Wiederöffnen gespeichert werden. Lass die App offen und wiederhole deine Auswahl."
      )
    case .errorActivityCleared:
      return (
        "L’activité enregistrée n’est plus compatible avec ce compte ou contenu et a été effacée. Les soumissions enregistrées n’ont pas changé.",
        "The saved activity is no longer compatible with this account or content and was cleared. Saved submissions were not changed.",
        "सहेजी गतिविधि अब इस खाते या सामग्री से संगत नहीं है और हटा दी गई। सहेजे प्रस्तुत उत्तर नहीं बदले।",
        "保存的活动已不再兼容此账户或内容，现已清除。保存的提交未更改。",
        "저장된 활동이 이 계정 또는 콘텐츠와 더 이상 호환되지 않아 지웠습니다. 저장된 제출 내역은 변경되지 않았습니다.",
        "La actividad guardada ya no es compatible con esta cuenta o contenido y se borró. Los envíos guardados no cambiaron.",
        "L’attività salvata non è più compatibile con account o contenuto ed è stata cancellata. Gli invii salvati non sono cambiati.",
        "Die gespeicherte Aktivität war mit Konto oder Inhalt nicht mehr kompatibel und wurde entfernt. Gespeicherte Einreichungen blieben unverändert."
      )
    case .errorActivityRemoval:
      return (
        "L’activité enregistrée est incompatible et n’a pas pu être retirée. Elle n’a pas été rouverte. Déconnectez-vous à nouveau pour l’effacer.",
        "The saved activity is incompatible and could not be removed. It was not reopened. Sign out again to clear it.",
        "सहेजी गतिविधि असंगत है और हट नहीं सकी। उसे फिर नहीं खोला गया। हटाने के लिए फिर साइन आउट करें।",
        "保存的活动不兼容，且无法移除。未重新打开。请再次退出登录以清除。",
        "저장된 활동이 호환되지 않으며 제거하지 못했습니다. 다시 열지 않았습니다. 지우려면 다시 로그아웃하세요.",
        "La actividad guardada es incompatible y no pudo eliminarse. No se reabrió. Cierra sesión de nuevo para borrarla.",
        "L’attività salvata è incompatibile e non è stata rimossa né riaperta. Esci di nuovo per cancellarla.",
        "Die gespeicherte Aktivität ist inkompatibel und konnte nicht entfernt werden. Sie wurde nicht geöffnet. Melde dich erneut ab, um sie zu entfernen."
      )
    case .errorActivityRestore:
      return (
        "L’activité enregistrée n’a pas pu être vérifiée. Elle a été conservée sans être rouverte ni envoyée. Reconnectez-vous pour réessayer la restauration.",
        "The saved activity could not be checked. It was kept without reopening or submitting it. Reconnect to retry restoration.",
        "सहेजी गतिविधि जाँची नहीं जा सकी। बिना खोले या भेजे सुरक्षित रखी गई। बहाली फिर करने के लिए कनेक्ट करें।",
        "无法检查保存的活动。已保留，但未重新打开或提交。请重新连接以重试恢复。",
        "저장된 활동을 확인하지 못했습니다. 다시 열거나 제출하지 않고 보존했습니다. 다시 연결해 복원을 재시도하세요.",
        "No se pudo comprobar la actividad guardada. Se conservó sin reabrirla ni enviarla. Reconecta para reintentar la restauración.",
        "Impossibile verificare l’attività salvata. È stata conservata senza riaprirla o inviarla. Ricollegati per riprovare il ripristino.",
        "Die gespeicherte Aktivität konnte nicht geprüft werden. Sie blieb ungeöffnet und wurde nicht übermittelt. Verbinde dich zur Wiederherstellung erneut."
      )
    case .errorContentVersionChanged:
      return (
        "Cette version du contenu a changé. Votre tentative enregistrée a été conservée ; réessayez son envoi d’origine depuis les réponses enregistrées.",
        "This content version changed. Your saved attempt was preserved; retry its original submission from saved responses.",
        "सामग्री का संस्करण बदल गया। सहेजा प्रयास सुरक्षित है; सहेजे उत्तरों से उसका मूल सबमिशन फिर भेजें।",
        "此内容版本已更改。保存的作答已保留；请从保存的答案重试原始提交。",
        "콘텐츠 버전이 변경되었습니다. 저장된 시도는 보존되었습니다. 저장된 답안에서 원래 제출을 다시 시도하세요.",
        "Esta versión del contenido cambió. Tu intento guardado se conservó; reintenta su envío original desde las respuestas guardadas.",
        "La versione del contenuto è cambiata. Il tentativo salvato è stato conservato; riprova l’invio originale dalle risposte salvate.",
        "Diese Inhaltsversion hat sich geändert. Dein gespeicherter Versuch blieb erhalten; wiederhole die ursprüngliche Einreichung aus den gespeicherten Antworten."
      )
    case .errorActivityUnsafe:
      return (
        "Cette activité ne peut pas reprendre en sécurité. Vos réponses enregistrées ont été conservées ; choisissez une activité valide ou consultez les soumissions enregistrées.",
        "This activity cannot be safely resumed. Your saved responses were preserved; choose a valid activity or review saved submissions.",
        "गतिविधि सुरक्षित रूप से फिर शुरू नहीं हो सकती। सहेजे उत्तर सुरक्षित हैं; मान्य गतिविधि चुनें या सहेजे सबमिशन देखें।",
        "无法安全恢复此活动。保存的答案已保留；请选择有效活动或查看保存的提交。",
        "이 활동은 안전하게 재개할 수 없습니다. 저장된 답안은 보존되었습니다. 유효한 활동을 선택하거나 저장된 제출 내역을 확인하세요.",
        "No se puede reanudar esta actividad con seguridad. Tus respuestas se conservaron; elige una actividad válida o revisa los envíos guardados.",
        "L’attività non può riprendere in sicurezza. Le risposte salvate sono conservate; scegli un’attività valida o consulta gli invii salvati.",
        "Diese Aktivität lässt sich nicht sicher fortsetzen. Deine Antworten blieben erhalten; wähle eine gültige Aktivität oder prüfe gespeicherte Einreichungen."
      )
    case .errorReconnect:
      return (
        "Reconnectez votre compte pour continuer.", "Reconnect your account to continue.",
        "जारी रखने के लिए अपना खाता फिर जोड़ें।", "请重新连接账户以继续。",
        "계속하려면 계정을 다시 연결하세요.", "Reconecta tu cuenta para continuar.",
        "Ricollega il tuo account per continuare.", "Verbinde dein Konto erneut, um fortzufahren."
      )
    case .errorConnectionUnconfirmed:
      return (
        "La connexion au compte n’a pas pu être confirmée. Aucun compte ni accès n’est supposé.",
        "The account connection could not be confirmed. No account or access is assumed.",
        "खाते के कनेक्शन की पुष्टि नहीं हुई। किसी खाते या पहुँच को मान्य नहीं माना गया।",
        "无法确认账户连接。不假定任何账户或访问权限。",
        "계정 연결을 확인하지 못했습니다. 계정이나 접근 권한을 가정하지 않습니다.",
        "No se pudo confirmar la conexión de la cuenta. No se presupone ninguna cuenta ni acceso.",
        "Impossibile confermare la connessione dell’account. Non si presume alcun account o accesso.",
        "Die Kontoverbindung konnte nicht bestätigt werden. Konto und Zugriff werden nicht vorausgesetzt."
      )
    case .errorConnectionExpired:
      return (
        "Votre connexion a expiré. Reconnectez votre compte pour continuer.",
        "Your connection expired. Reconnect your account to continue.",
        "कनेक्शन की अवधि समाप्त हुई। जारी रखने के लिए खाता फिर जोड़ें।",
        "连接已过期。请重新连接账户以继续。",
        "연결이 만료되었습니다. 계속하려면 계정을 다시 연결하세요.",
        "Tu conexión caducó. Reconecta tu cuenta para continuar.",
        "La connessione è scaduta. Ricollega il tuo account per continuare.",
        "Deine Verbindung ist abgelaufen. Verbinde dein Konto erneut, um fortzufahren."
      )
    case .errorInvalidAPIURL:
      return (
        "Saisissez une URL d’API HTTPS valide, sans identifiants ni paramètres de requête.",
        "Enter a valid HTTPS API URL without credentials or query parameters.",
        "बिना क्रेडेंशियल या क्वेरी पैरामीटर का मान्य HTTPS API URL दर्ज करें।",
        "请输入有效的 HTTPS API URL，不含凭据或查询参数。",
        "자격 증명이나 쿼리 매개변수가 없는 유효한 HTTPS API URL을 입력하세요.",
        "Introduce una URL HTTPS de API válida, sin credenciales ni parámetros de consulta.",
        "Inserisci un URL HTTPS dell’API valido, senza credenziali né parametri di query.",
        "Gib eine gültige HTTPS-API-URL ohne Zugangsdaten oder Abfrageparameter ein."
      )
    case .errorAccountChanged:
      return (
        "Le compte a changé. Cette réponse n’a pas été affichée.",
        "The account changed. This response was not displayed.",
        "खाता बदल गया। यह प्रतिक्रिया नहीं दिखाई गई।", "账户已更改。未显示此响应。",
        "계정이 변경되었습니다. 이 응답은 표시하지 않았습니다.",
        "La cuenta cambió. Esta respuesta no se mostró.",
        "L’account è cambiato. Questa risposta non è stata mostrata.",
        "Das Konto wurde gewechselt. Diese Antwort wurde nicht angezeigt."
      )
    case .errorContentStorageFull:
      return (
        "La limite de stockage du contenu téléchargé est atteinte. Les tentatives enregistrées ont été conservées ; contactez l’assistance avant de retirer leur contenu épinglé.",
        "The downloaded content storage limit was reached. Saved attempts were preserved; contact support before removing their pinned content.",
        "डाउनलोड सामग्री की संग्रहण सीमा पूरी हुई। सहेजे प्रयास सुरक्षित हैं; उनसे जुड़े स्थिर सामग्री संस्करण हटाने से पहले सहायता लें।",
        "已达到下载内容的存储上限。保存的作答已保留；移除其固定版本内容前请联系支持。",
        "다운로드한 콘텐츠의 저장 한도에 도달했습니다. 저장된 시도는 보존되었습니다. 연결된 고정 버전 콘텐츠를 제거하기 전에 지원팀에 문의하세요.",
        "Se alcanzó el límite de contenido descargado. Los intentos se conservaron; contacta con soporte antes de borrar el contenido de su versión fijada.",
        "Raggiunto il limite di archiviazione dei contenuti scaricati. I tentativi salvati sono conservati; contatta l’assistenza prima di rimuovere i contenuti delle versioni fissate.",
        "Das Speicherlimit für heruntergeladene Inhalte ist erreicht. Gespeicherte Versuche blieben erhalten; kontaktiere den Support, bevor du ihre festgelegten Inhaltsversionen entfernst."
      )
    case .errorContentChanged:
      return (
        "Le contenu téléchargé a changé pendant cette opération. Relancez explicitement ; rien n’a été envoyé.",
        "The downloaded content changed during this operation. Retry explicitly; nothing was submitted.",
        "इस कार्रवाई के दौरान डाउनलोड सामग्री बदल गई। स्वयं फिर प्रयास करें; कुछ नहीं भेजा गया।",
        "下载的内容在操作期间发生更改。请主动重试；未提交任何内容。",
        "작업 도중 다운로드한 콘텐츠가 변경되었습니다. 직접 다시 시도하세요. 제출된 내용은 없습니다.",
        "El contenido descargado cambió durante la operación. Reintenta explícitamente; no se envió nada.",
        "Il contenuto scaricato è cambiato durante l’operazione. Riprova esplicitamente; nulla è stato inviato.",
        "Die heruntergeladenen Inhalte wurden während des Vorgangs geändert. Starte ihn erneut; es wurde nichts übermittelt."
      )
    case .errorContentPackInvalid:
      return (
        "Le pack de questions téléchargé est absent, incompatible ou endommagé. Reconnectez-vous et téléchargez-le à nouveau. Les soumissions enregistrées n’ont pas changé.",
        "The downloaded question pack is missing, incompatible or damaged. Reconnect and download it again. Saved submissions were not changed.",
        "डाउनलोड प्रश्न पैक गायब, असंगत या क्षतिग्रस्त है। फिर कनेक्ट करके डाउनलोड करें। सहेजे सबमिशन नहीं बदले।",
        "下载的题包缺失、不兼容或已损坏。请重新连接并再次下载。保存的提交未更改。",
        "다운로드한 문제 팩이 없거나 호환되지 않거나 손상되었습니다. 다시 연결하고 다운로드하세요. 저장된 제출 내역은 변경되지 않았습니다.",
        "El paquete descargado falta, es incompatible o está dañado. Reconecta y descárgalo de nuevo. Los envíos guardados no cambiaron.",
        "Il pacchetto scaricato manca, è incompatibile o danneggiato. Ricollegati e scaricalo di nuovo. Gli invii salvati non sono cambiati.",
        "Das heruntergeladene Fragenpaket fehlt, ist inkompatibel oder beschädigt. Verbinde dich erneut und lade es herunter. Gespeicherte Einreichungen blieben unverändert."
      )
    case .errorServerUnreachable:
      return (
        "Le serveur est injoignable. Vérifiez la connexion et réessayez.",
        "The server is unreachable. Check the connection and retry.",
        "सर्वर तक नहीं पहुँच सके। कनेक्शन जाँचें और फिर कोशिश करें।",
        "无法连接服务器。请检查连接并重试。",
        "서버에 연결할 수 없습니다. 연결을 확인하고 다시 시도하세요.",
        "No se puede acceder al servidor. Comprueba la conexión y reintenta.",
        "Il server non è raggiungibile. Controlla la connessione e riprova.",
        "Der Server ist nicht erreichbar. Prüfe die Verbindung und versuche es erneut."
      )
    case .errorRequestRejected:
      return (
        "Le serveur a refusé la demande (HTTP {status}). Réessayez ou contactez l’assistance.",
        "The server rejected the request (HTTP {status}). Retry or contact support.",
        "सर्वर ने अनुरोध अस्वीकार किया (HTTP {status})। फिर कोशिश करें या सहायता से संपर्क करें।",
        "服务器拒绝了请求（HTTP {status}）。请重试或联系支持。",
        "서버가 요청을 거부했습니다(HTTP {status}). 다시 시도하거나 지원팀에 문의하세요.",
        "El servidor rechazó la solicitud (HTTP {status}). Reintenta o contacta con soporte.",
        "Il server ha rifiutato la richiesta (HTTP {status}). Riprova o contatta l’assistenza.",
        "Der Server hat die Anfrage abgelehnt (HTTP {status}). Versuche es erneut oder kontaktiere den Support."
      )
    case .errorCapabilityUnavailable:
      return (
        "Ce contenu exige une capacité indisponible dans cette version native.",
        "This content requires a capability that is unavailable in this native version.",
        "इस सामग्री के लिए ऐसी सुविधा चाहिए जो इस नेटिव संस्करण में उपलब्ध नहीं है।",
        "此内容需要本原生版本不支持的功能。",
        "이 콘텐츠에는 현재 네이티브 버전에서 지원하지 않는 기능이 필요합니다.",
        "Este contenido requiere una capacidad no disponible en esta versión nativa.",
        "Questo contenuto richiede una funzionalità non disponibile in questa versione nativa.",
        "Dieser Inhalt benötigt eine Funktion, die in dieser nativen Version nicht verfügbar ist."
      )
    case .errorSavedResponsesUnreadable:
      return (
        "Les réponses enregistrées n’ont pas pu être lues. Elles ont été conservées et n’ont pas été renvoyées.",
        "Saved responses could not be read. They were preserved and were not resent.",
        "सहेजे उत्तर पढ़े नहीं जा सके। वे सुरक्षित हैं और फिर नहीं भेजे गए।",
        "无法读取保存的答案。已保留，且未重新发送。",
        "저장된 답안을 읽지 못했습니다. 보존되었으며 다시 전송하지 않았습니다.",
        "No se pudieron leer las respuestas guardadas. Se conservaron y no se reenviaron.",
        "Impossibile leggere le risposte salvate. Sono state conservate e non reinviate.",
        "Gespeicherte Antworten konnten nicht gelesen werden. Sie blieben erhalten und wurden nicht erneut gesendet."
      )
    case .errorResponseStorageFull:
      return (
        "Le stockage des réponses est plein. L’enregistrement de vos réponses n’est pas confirmé.",
        "Response storage is full. Your answers are not confirmed as saved.",
        "उत्तर संग्रहण भर गया। उत्तर सहेजे जाने की पुष्टि नहीं है।",
        "答案存储空间已满。尚未确认您的答案已保存。",
        "답안 저장 공간이 가득 찼습니다. 답안이 저장되었는지 확인되지 않았습니다.",
        "El almacenamiento de respuestas está lleno. No se confirma que tus respuestas se hayan guardado.",
        "Lo spazio per le risposte è pieno. Il salvataggio delle risposte non è confermato.",
        "Der Antwortspeicher ist voll. Das Speichern deiner Antworten ist nicht bestätigt."
      )
    case .errorSubmissionRetryUnavailable:
      return (
        "Cette soumission enregistrée ne peut pas être réessayée. Vos réponses ont été conservées ; examinez son échec avant une autre tentative.",
        "This saved submission cannot be retried. Your answers were preserved; review its failure before starting another attempt.",
        "यह सहेजा सबमिशन फिर नहीं भेजा जा सकता। उत्तर सुरक्षित हैं; नया प्रयास शुरू करने से पहले विफलता देखें।",
        "无法重试此保存的提交。答案已保留；开始其他作答前请查看失败原因。",
        "이 저장된 제출은 재시도할 수 없습니다. 답안은 보존되었습니다. 새 시도 전에 실패 원인을 확인하세요.",
        "No se puede reintentar este envío guardado. Tus respuestas se conservaron; revisa el fallo antes de iniciar otro intento.",
        "Questo invio salvato non può essere riprovato. Le risposte sono conservate; esamina l’errore prima di un nuovo tentativo.",
        "Diese gespeicherte Einreichung kann nicht wiederholt werden. Deine Antworten blieben erhalten; prüfe den Fehler, bevor du einen neuen Versuch beginnst."
      )
    case .errorOperationUnconfirmed:
      return (
        "L’opération n’a pas pu être confirmée. Aucun succès n’est supposé. Réessayez.",
        "The operation could not be confirmed. No success is assumed. Retry.",
        "कार्रवाई की पुष्टि नहीं हुई। सफल नहीं माना गया। फिर कोशिश करें।",
        "无法确认操作。不视为成功。请重试。",
        "작업을 확인하지 못했습니다. 성공한 것으로 간주하지 않습니다. 다시 시도하세요.",
        "No se pudo confirmar la operación. No se da por exitosa. Reintenta.",
        "Impossibile confermare l’operazione. Il successo non è presunto. Riprova.",
        "Der Vorgang konnte nicht bestätigt werden. Erfolg wird nicht angenommen. Versuche es erneut."
      )
    case .audioReadAloud:
      return (
        "Lire la leçon à voix haute", "Read lesson aloud", "पाठ ज़ोर से पढ़ें", "朗读课程", "학습 내용 소리 내어 읽기",
        "Leer la lección en voz alta", "Leggi la lezione ad alta voce", "Lektion vorlesen"
      )
    case .audioScopeNote:
      return (
        "Lit uniquement le texte d’apprentissage sélectionné. Le code, les questions et les corrections ne sont pas lus. Choisissez une voix ; la langue du contenu n’est pas détectée.",
        "Reads selected learning text only. Code, questions and corrections are not read. Choose a reading voice; the content language is not detected.",
        "केवल चुना हुआ सीखने का पाठ पढ़ता है। कोड, प्रश्न और सुधार नहीं पढ़े जाते। आवाज़ चुनें; सामग्री की भाषा पहचानी नहीं जाती।",
        "仅读取选定的学习文本。不读取代码、题目和批改内容。请选择朗读声音；不会检测内容语言。",
        "선택한 학습 텍스트만 읽습니다. 코드, 문제, 채점 내용은 읽지 않습니다. 읽기 음성을 선택하세요. 콘텐츠 언어는 감지하지 않습니다.",
        "Solo lee el texto de aprendizaje seleccionado. No lee código, preguntas ni correcciones. Elige una voz; no se detecta el idioma del contenido.",
        "Legge solo il testo didattico selezionato. Codice, domande e correzioni non vengono letti. Scegli una voce; la lingua non viene rilevata.",
        "Liest nur ausgewählten Lerntext vor. Code, Fragen und Korrekturen werden nicht vorgelesen. Wähle eine Stimme; die Inhaltssprache wird nicht erkannt."
      )
    case .audioVoice:
      return (
        "Voix de lecture", "Reading voice", "पढ़ने की आवाज़", "朗读声音", "읽기 음성", "Voz de lectura",
        "Voce di lettura", "Vorlesestimme"
      )
    case .audioChooseVoice:
      return (
        "Choisir une voix", "Choose a voice", "आवाज़ चुनें", "选择声音", "음성 선택", "Elegir una voz",
        "Scegli una voce", "Stimme wählen"
      )
    case .audioNoVoices:
      return (
        "Aucune voix de lecture n’est disponible sur cet appareil.",
        "No reading voices are available on this device.", "इस डिवाइस पर पढ़ने की कोई आवाज़ उपलब्ध नहीं है।",
        "此设备没有可用的朗读声音。", "이 기기에 사용할 수 있는 읽기 음성이 없습니다.",
        "No hay voces de lectura disponibles en este dispositivo.",
        "Nessuna voce di lettura è disponibile su questo dispositivo.",
        "Auf diesem Gerät sind keine Vorlesestimmen verfügbar."
      )
    case .audioSpeed:
      return (
        "Vitesse de lecture", "Reading speed", "पढ़ने की गति", "朗读速度", "읽기 속도", "Velocidad de lectura",
        "Velocità di lettura", "Vorlesegeschwindigkeit"
      )
    case .audioSlower:
      return ("Plus lent", "Slower", "धीमा", "较慢", "느리게", "Más lento", "Più lenta", "Langsamer")
    case .audioStandard:
      return ("Normale", "Standard", "सामान्य", "标准", "표준", "Normal", "Normale", "Normal")
    case .audioRead:
      return (
        "Lire la leçon", "Read lesson", "पाठ पढ़ें", "朗读课程", "학습 내용 읽기", "Leer lección",
        "Leggi la lezione", "Lektion vorlesen"
      )
    case .audioPause:
      return (
        "Mettre la lecture en pause", "Pause reading", "पढ़ना रोकें", "暂停朗读", "읽기 일시 정지",
        "Pausar lectura", "Sospendi la lettura", "Vorlesen pausieren"
      )
    case .audioResume:
      return (
        "Reprendre la lecture", "Resume reading", "पढ़ना जारी रखें", "继续朗读", "읽기 재개", "Reanudar lectura",
        "Riprendi la lettura", "Vorlesen fortsetzen"
      )
    case .audioStop:
      return (
        "Arrêter la lecture", "Stop reading", "पढ़ना बंद करें", "停止朗读", "읽기 중지", "Detener lectura",
        "Interrompi la lettura", "Vorlesen beenden"
      )
    case .audioStopped:
      return (
        "Audio arrêté", "Audio stopped", "ऑडियो बंद है", "音频已停止", "오디오 중지됨", "Audio detenido",
        "Audio interrotto", "Audio beendet"
      )
    case .audioReading:
      return (
        "Lecture de la leçon", "Reading lesson", "पाठ पढ़ा जा रहा है", "正在朗读课程", "학습 내용 읽는 중",
        "Leyendo la lección", "Lettura della lezione", "Lektion wird vorgelesen"
      )
    case .audioPaused:
      return (
        "Audio en pause", "Audio paused", "ऑडियो रुका है", "音频已暂停", "오디오 일시 정지됨", "Audio en pausa",
        "Audio in pausa", "Audio pausiert"
      )
    case .audioChooseVoiceFirst:
      return (
        "Choisissez une voix de lecture avant de commencer.",
        "Choose a reading voice before starting.", "शुरू करने से पहले पढ़ने की आवाज़ चुनें।", "开始前请选择朗读声音。",
        "시작하기 전에 읽기 음성을 선택하세요.", "Elige una voz de lectura antes de empezar.",
        "Scegli una voce prima di iniziare.", "Wähle vor dem Start eine Vorlesestimme."
      )
    case .audioVoiceUnavailable:
      return (
        "Cette voix est indisponible. Choisissez une voix de lecture disponible.",
        "That voice is unavailable. Choose an available reading voice.",
        "वह आवाज़ उपलब्ध नहीं है। उपलब्ध पढ़ने की आवाज़ चुनें।", "该声音不可用。请选择可用的朗读声音。",
        "해당 음성을 사용할 수 없습니다. 사용 가능한 읽기 음성을 선택하세요.",
        "Esa voz no está disponible. Elige una voz de lectura disponible.",
        "Quella voce non è disponibile. Scegli una voce di lettura disponibile.",
        "Diese Stimme ist nicht verfügbar. Wähle eine verfügbare Vorlesestimme."
      )
    case .audioVoiceOverRead:
      return (
        "VoiceOver est actif. Utilisez-le pour lire ce contenu ; l’audio facultatif reste arrêté pour éviter de superposer les voix.",
        "VoiceOver is active. Use VoiceOver to read this content; optional audio stays stopped to avoid overlapping speech.",
        "VoiceOver चालू है। सामग्री पढ़ने के लिए VoiceOver का उपयोग करें; आवाज़ों के टकराव से बचने के लिए वैकल्पिक ऑडियो बंद रहेगा।",
        "VoiceOver 已启用。请使用 VoiceOver 阅读此内容；可选音频保持停止，避免语音重叠。",
        "VoiceOver가 켜져 있습니다. 이 콘텐츠는 VoiceOver로 읽으세요. 음성 중첩을 피하기 위해 선택적 오디오는 중지 상태를 유지합니다.",
        "VoiceOver está activo. Úsalo para leer este contenido; el audio opcional permanece detenido para evitar voces superpuestas.",
        "VoiceOver è attivo. Usalo per leggere questo contenuto; l’audio facoltativo resta fermo per evitare voci sovrapposte.",
        "VoiceOver ist aktiv. Lies diesen Inhalt mit VoiceOver; optionales Audio bleibt aus, damit sich Sprachausgaben nicht überlagern."
      )
    case .audioPreparationFailed:
      return (
        "Le texte de la leçon n’a pas pu être préparé pour la lecture. Aucun audio n’a démarré ; vous pouvez toujours lire la leçon à l’écran.",
        "The lesson text could not be prepared for reading. No audio was started; you can still read the lesson on screen.",
        "पाठ पढ़ने के लिए तैयार नहीं हो सका। ऑडियो शुरू नहीं हुआ; आप अब भी स्क्रीन पर पाठ पढ़ सकते हैं।",
        "无法准备课程文本供朗读。未开始播放音频；您仍可在屏幕上阅读课程。",
        "학습 텍스트를 읽기용으로 준비하지 못했습니다. 오디오는 시작되지 않았으며 화면에서 계속 읽을 수 있습니다.",
        "No se pudo preparar el texto para leerlo. No se inició el audio; aún puedes leer la lección en pantalla.",
        "Impossibile preparare il testo per la lettura. Nessun audio avviato; puoi ancora leggere la lezione sullo schermo.",
        "Der Lektionstext konnte nicht zum Vorlesen vorbereitet werden. Audio wurde nicht gestartet; du kannst die Lektion weiterhin am Bildschirm lesen."
      )
    case .audioNoText:
      return (
        "Aucun texte de leçon n’est disponible à lire.", "No lesson text is available to read.",
        "पढ़ने के लिए पाठ उपलब्ध नहीं है।", "没有可朗读的课程文本。", "읽을 학습 텍스트가 없습니다.",
        "No hay texto de lección disponible para leer.",
        "Nessun testo della lezione disponibile da leggere.",
        "Es ist kein Lektionstext zum Vorlesen verfügbar."
      )
    case .audioPauseFailed:
      return (
        "La lecture n’a pas pu être mise en pause. Arrêtez-la et réessayez.",
        "Reading could not be paused. Stop reading and try again.",
        "पढ़ना रोका नहीं जा सका। बंद करके फिर कोशिश करें।", "无法暂停朗读。请停止朗读后重试。",
        "읽기를 일시 정지하지 못했습니다. 읽기를 중지하고 다시 시도하세요.",
        "No se pudo pausar la lectura. Detenla y reintenta.",
        "Impossibile sospendere la lettura. Interrompila e riprova.",
        "Das Vorlesen konnte nicht pausiert werden. Beende es und versuche es erneut."
      )
    case .audioVoiceOverResume:
      return (
        "VoiceOver est actif. L’audio facultatif reste arrêté pour éviter de superposer les voix.",
        "VoiceOver is active. Optional audio stays stopped to avoid overlapping speech.",
        "VoiceOver चालू है। आवाज़ों के टकराव से बचने के लिए वैकल्पिक ऑडियो बंद रहेगा।", "VoiceOver 已启用。可选音频保持停止，避免语音重叠。",
        "VoiceOver가 켜져 있습니다. 음성 중첩을 피하기 위해 선택적 오디오는 중지 상태를 유지합니다.",
        "VoiceOver está activo. El audio opcional permanece detenido para evitar voces superpuestas.",
        "VoiceOver è attivo. L’audio facoltativo resta fermo per evitare voci sovrapposte.",
        "VoiceOver ist aktiv. Optionales Audio bleibt aus, damit sich Sprachausgaben nicht überlagern."
      )
    case .audioResumeFailed:
      return (
        "La lecture n’a pas pu reprendre. Arrêtez-la et réessayez.",
        "Reading could not be resumed. Stop reading and try again.",
        "पढ़ना फिर शुरू नहीं हुआ। बंद करके फिर कोशिश करें।", "无法继续朗读。请停止朗读后重试。",
        "읽기를 재개하지 못했습니다. 읽기를 중지하고 다시 시도하세요.",
        "No se pudo reanudar la lectura. Detenla y reintenta.",
        "Impossibile riprendere la lettura. Interrompila e riprova.",
        "Das Vorlesen konnte nicht fortgesetzt werden. Beende es und versuche es erneut."
      )
    case .deletionBeforeContinuing:
      return (
        "Avant de continuer", "Before you continue", "जारी रखने से पहले", "继续之前", "계속하기 전에",
        "Antes de continuar", "Prima di continuare", "Bevor du fortfährst"
      )
    case .deletionScopeNote:
      return (
        "Supprime définitivement votre compte Certigo, votre apprentissage confirmé et votre progression. Les brouillons locaux et les références de compte téléchargées sont retirés uniquement après confirmation de fin par le serveur.",
        "Permanently delete your Certigo account, confirmed learning and progression. Local drafts and downloaded account references are removed only after the server confirms completion.",
        "आपका Certigo खाता, पुष्ट पढ़ाई और प्रगति स्थायी रूप से हटेंगे। स्थानीय ड्राफ़्ट और डाउनलोड खाता संदर्भ केवल सर्वर की पूर्णता पुष्टि के बाद हटेंगे।",
        "永久删除您的 Certigo 账户、已确认的学习记录和进度。本地草稿和下载的账户引用仅在服务器确认完成后移除。",
        "Certigo 계정, 확인된 학습 및 진도를 영구 삭제합니다. 로컬 초안과 다운로드된 계정 참조는 서버가 완료를 확인한 뒤에만 제거됩니다.",
        "Elimina permanentemente tu cuenta Certigo, aprendizaje confirmado y progreso. Los borradores locales y referencias de cuenta descargadas solo se eliminan tras confirmarse la finalización en el servidor.",
        "Elimina definitivamente account Certigo, apprendimento confermato e progressi. Bozze locali e riferimenti dell’account scaricati vengono rimossi solo dopo la conferma di completamento del server.",
        "Löscht dein Certigo-Konto, bestätigtes Lernen und Fortschritt endgültig. Lokale Entwürfe und heruntergeladene Kontoverweise werden erst nach Abschlussbestätigung des Servers entfernt."
      )
    case .deletionRetentionNote:
      return (
        "Cette action est irréversible. Aucun point de terminaison ne permet l’annulation après envoi. Les sauvegardes résiduelles de production peuvent persister jusqu’à 30 jours, une trace pseudonyme reste 30 jours et les journaux d’audit de suppression sans identité 90 jours. Ce ne sont pas des délais d’annulation.",
        "This is irreversible. There is no cancellation endpoint after submission. Residual production backups may rotate for up to 30 days, a pseudonymous tombstone remains for 30 days and identity-free deletion audit logs for 90 days. These are not an undo period.",
        "यह अपरिवर्तनीय है। अनुरोध भेजने के बाद रद्द करने का कोई एंडपॉइंट नहीं है। बचे उत्पादन बैकअप 30 दिन तक, छद्मनाम वाला हटाने का रिकॉर्ड 30 दिन और पहचान-रहित हटाने के ऑडिट लॉग 90 दिन रह सकते हैं। यह वापस लेने की अवधि नहीं है।",
        "此操作不可撤销。提交后没有取消接口。生产环境残余备份可能保留最长 30 天，假名删除标记保留 30 天，不含身份信息的删除审计日志保留 90 天。这些不是撤销期限。",
        "되돌릴 수 없습니다. 제출 후 취소하는 엔드포인트가 없습니다. 운영 백업 잔여본은 최대 30일, 가명 삭제 표식은 30일, 신원 정보 없는 삭제 감사 로그는 90일 보관됩니다. 이는 취소 가능 기간이 아닙니다.",
        "Es irreversible. No existe un endpoint de cancelación tras el envío. Las copias residuales de producción pueden persistir hasta 30 días, la marca seudónima 30 días y los registros de auditoría sin identidad 90 días. No son plazos para deshacer la acción.",
        "È irreversibile. Dopo l’invio non esiste un endpoint di annullamento. I backup residui di produzione possono persistere fino a 30 giorni, il segnaposto pseudonimo resta 30 giorni e i log di audit senza identità 90 giorni. Non sono periodi per annullare.",
        "Dies ist unumkehrbar. Nach der Übermittlung gibt es keinen Abbruch-Endpunkt. Produktionsbackups können bis zu 30 Tage verbleiben, ein pseudonymer Löschvermerk 30 Tage und identitätsfreie Lösch-Auditprotokolle 90 Tage. Dies sind keine Widerrufsfristen."
      )
    case .deletionVerify:
      return (
        "Continuer pour vérifier l’identité", "Continue to verify identity",
        "पहचान सत्यापित करने के लिए जारी रखें", "继续验证身份", "계속하여 신원 확인", "Continuar para verificar la identidad",
        "Continua per verificare l’identità", "Zur Identitätsprüfung fortfahren"
      )
    case .deletionMicrosoftRequired:
      return (
        "La suppression distante exige une connexion Microsoft configurée. Elle est indisponible dans la démo et le connecteur manuel de développement.",
        "Remote deletion requires configured Microsoft sign-in. It is unavailable for the demo and manual development connector.",
        "दूरस्थ हटाने के लिए कॉन्फ़िगर Microsoft साइन-इन चाहिए। डेमो और मैन्युअल विकास कनेक्टर में यह उपलब्ध नहीं है।",
        "远程删除需要已配置的 Microsoft 登录。演示和手动开发连接器不支持此操作。",
        "원격 삭제에는 설정된 Microsoft 로그인이 필요합니다. 데모 및 수동 개발 연결에서는 사용할 수 없습니다.",
        "La eliminación remota requiere un acceso Microsoft configurado. No está disponible en la demo ni en el conector manual de desarrollo.",
        "L’eliminazione remota richiede un accesso Microsoft configurato. Non è disponibile nella demo e nel connettore manuale di sviluppo.",
        "Die Remote-Löschung erfordert eine konfigurierte Microsoft-Anmeldung. In Demo und manuellem Entwicklungsverbinder ist sie nicht verfügbar."
      )
    case .deletionServerStatus:
      return (
        "État du serveur", "Server status", "सर्वर स्थिति", "服务器状态", "서버 상태", "Estado del servidor",
        "Stato del server", "Serverstatus"
      )
    case .deletionSteps:
      return (
        "{completed} étapes serveur confirmées sur {total}.",
        "{completed} of {total} server steps confirmed.",
        "सर्वर के {total} चरणों में से {completed} की पुष्टि हुई।", "已确认 {completed}/{total} 个服务器步骤。",
        "서버 단계 {total}개 중 {completed}개가 확인되었습니다.",
        "{completed} de {total} pasos del servidor confirmados.",
        "{completed} di {total} passaggi del server confermati.",
        "{completed} von {total} Serverschritten bestätigt."
      )
    case .deletionPendingNote:
      return (
        "La suppression est en attente, pas terminée. L’apprentissage est suspendu et les données locales sont conservées. Les vérifications d’état ne font pas avancer les étapes inachevées.",
        "Deletion is pending, not completed. Learning is paused and local data is retained. Status checks do not advance unfinished deletion steps.",
        "हटाना लंबित है, पूरा नहीं हुआ। पढ़ाई रुकी है और स्थानीय डेटा रखा गया है। स्थिति जाँचने से अधूरे चरण आगे नहीं बढ़ते।",
        "删除待处理，尚未完成。学习已暂停，本地数据已保留。检查状态不会推进未完成的删除步骤。",
        "삭제가 대기 중이며 완료되지 않았습니다. 학습은 일시 중지되고 로컬 데이터는 유지됩니다. 상태 확인으로 미완료 삭제 단계가 진행되지는 않습니다.",
        "La eliminación está pendiente, no finalizada. El aprendizaje está pausado y los datos locales se conservan. Comprobar el estado no avanza los pasos pendientes.",
        "L’eliminazione è in attesa, non completata. L’apprendimento è sospeso e i dati locali conservati. Controllare lo stato non fa avanzare i passaggi incompleti.",
        "Die Löschung ist ausstehend, nicht abgeschlossen. Lernen ist pausiert und lokale Daten bleiben erhalten. Statusprüfungen führen ausstehende Löschschritte nicht aus."
      )
    case .deletionRetryDelay:
      return (
        "Le serveur a demandé un délai avant nouvel essai. Actualisez l’état avant de réessayer si l’action n’est pas encore disponible.",
        "The server requested a retry delay. Refresh status before retrying if the action is not available yet.",
        "सर्वर ने फिर प्रयास से पहले इंतज़ार कहा है। कार्रवाई अभी उपलब्ध न हो तो दोबारा प्रयास से पहले स्थिति रीफ़्रेश करें।",
        "服务器要求延迟重试。若操作尚不可用，请先刷新状态再重试。",
        "서버가 재시도 대기를 요청했습니다. 작업을 아직 사용할 수 없으면 재시도 전에 상태를 새로 고치세요.",
        "El servidor pidió una espera antes de reintentar. Actualiza el estado si la acción aún no está disponible.",
        "Il server ha richiesto un’attesa prima di riprovare. Aggiorna lo stato se l’azione non è ancora disponibile.",
        "Der Server hat eine Wartezeit angefordert. Aktualisiere den Status vor dem nächsten Versuch, falls die Aktion noch nicht verfügbar ist."
      )
    case .deletionCheckStatus:
      return (
        "Vérifier l’état", "Check status", "स्थिति जाँचें", "检查状态", "상태 확인", "Comprobar estado",
        "Controlla lo stato", "Status prüfen"
      )
    case .deletionSignInSameAccount:
      return (
        "Se connecter pour vérifier le même compte", "Sign in to check the same account",
        "उसी खाते की जाँच के लिए साइन इन करें", "登录以检查同一账户", "같은 계정을 확인하려면 로그인",
        "Acceder para comprobar la misma cuenta", "Accedi per verificare lo stesso account",
        "Zum Prüfen desselben Kontos anmelden"
      )
    case .deletionResumeAccount:
      return (
        "Reprendre le compte pour vérifier l’identité", "Resume account to verify identity",
        "पहचान सत्यापित करने के लिए खाता फिर शुरू करें", "恢复账户以验证身份", "신원 확인을 위해 계정 재개",
        "Reanudar cuenta para verificar la identidad",
        "Riprendi l’account per verificare l’identità", "Konto zur Identitätsprüfung fortsetzen"
      )
    case .deletionCleanupIncomplete:
      return (
        "Confirmé. Le nettoyage de cet appareil n’est pas terminé.",
        "Confirmed. Cleanup on this device is not complete.", "पुष्टि हुई। इस डिवाइस की सफ़ाई पूरी नहीं है।",
        "已确认。此设备上的清理尚未完成。", "확인됨. 이 기기의 정리는 완료되지 않았습니다.",
        "Confirmado. La limpieza de este dispositivo no está completa.",
        "Confermato. La pulizia del dispositivo non è completa.",
        "Bestätigt. Die Bereinigung dieses Geräts ist noch nicht abgeschlossen."
      )
    case .deletionCompletedNote:
      return (
        "Le serveur a confirmé la suppression du compte et cet appareil a confirmé le nettoyage local. Les périodes de conservation résiduelle restent applicables.",
        "The server confirmed account deletion and this device confirmed local cleanup. Residual retention periods still apply.",
        "सर्वर ने खाता हटने और डिवाइस ने स्थानीय सफ़ाई की पुष्टि की। बची प्रतियों की प्रतिधारण अवधि अब भी लागू है।",
        "服务器已确认账户删除，此设备已确认本地清理。残余数据保留期限仍然适用。",
        "서버가 계정 삭제를 확인했고 이 기기가 로컬 정리를 확인했습니다. 잔여 데이터 보관 기간은 계속 적용됩니다.",
        "El servidor confirmó la eliminación y este dispositivo la limpieza local. Siguen aplicándose los plazos de retención residual.",
        "Il server ha confermato l’eliminazione e il dispositivo la pulizia locale. Restano validi i periodi di conservazione residua.",
        "Der Server hat die Kontolöschung und dieses Gerät die lokale Bereinigung bestätigt. Restaufbewahrungsfristen gelten weiterhin."
      )
    case .deletionReturnToSignIn:
      return (
        "Revenir à la connexion", "Return to sign-in", "साइन-इन पर लौटें", "返回登录", "로그인으로 돌아가기",
        "Volver al inicio de sesión", "Torna all’accesso", "Zur Anmeldung zurück"
      )
    case .deletionConfirmTitle:
      return (
        "Supprimer définitivement ce compte Certigo ?", "Permanently delete this Certigo account?",
        "यह Certigo खाता स्थायी रूप से हटाएँ?", "永久删除此 Certigo 账户？", "이 Certigo 계정을 영구 삭제할까요?",
        "¿Eliminar permanentemente esta cuenta Certigo?",
        "Eliminare definitivamente questo account Certigo?",
        "Dieses Certigo-Konto endgültig löschen?"
      )
    case .deletionConfirmMessage:
      return (
        "Microsoft a vérifié le même compte. Seul « Supprimer le compte » envoie la demande irréversible. La fin peut nécessiter plusieurs essais.",
        "Microsoft verified the same account. Only Delete account submits the irreversible request. Completion may require retries.",
        "Microsoft ने उसी खाते को सत्यापित किया। केवल खाता हटाएँ अपरिवर्तनीय अनुरोध भेजता है। पूरा करने के लिए फिर प्रयास ज़रूरी हो सकते हैं।",
        "Microsoft 已验证同一账户。只有“删除账户”才会提交不可撤销的请求。完成操作可能需要重试。",
        "Microsoft가 동일한 계정을 확인했습니다. 계정 삭제를 눌러야만 되돌릴 수 없는 요청이 제출됩니다. 완료하려면 재시도가 필요할 수 있습니다.",
        "Microsoft verificó la misma cuenta. Solo Eliminar cuenta envía la solicitud irreversible. Puede requerir reintentos para completarse.",
        "Microsoft ha verificato lo stesso account. Solo Elimina account invia la richiesta irreversibile. Il completamento può richiedere nuovi tentativi.",
        "Microsoft hat dasselbe Konto bestätigt. Nur Konto löschen sendet den unumkehrbaren Antrag. Der Abschluss kann erneute Versuche erfordern."
      )
    case .deletionVerifying:
      return (
        "Vérifier votre identité Microsoft", "Verify your Microsoft identity",
        "अपनी Microsoft पहचान सत्यापित करें", "验证您的 Microsoft 身份", "Microsoft 신원 확인",
        "Verificar tu identidad Microsoft", "Verifica la tua identità Microsoft",
        "Microsoft-Identität prüfen"
      )
    case .deletionIdentityVerified:
      return (
        "Identité vérifiée", "Identity verified", "पहचान सत्यापित", "身份已验证", "신원 확인됨",
        "Identidad verificada", "Identità verificata", "Identität bestätigt"
      )
    case .deletionChecking:
      return (
        "Vérification de la suppression du compte", "Checking account deletion", "खाता हटाने की जाँच",
        "正在检查账户删除", "계정 삭제 확인 중", "Comprobando eliminación de cuenta",
        "Verifica dell’eliminazione dell’account", "Kontolöschung wird geprüft"
      )
    case .deletionPending:
      return (
        "Suppression en attente", "Deletion pending", "हटाना लंबित", "删除待处理", "삭제 대기 중",
        "Eliminación pendiente", "Eliminazione in attesa", "Löschung ausstehend"
      )
    case .deletionUnconfirmed:
      return (
        "État du compte non confirmé", "Account status unconfirmed", "खाते की स्थिति अपुष्ट", "账户状态未确认",
        "계정 상태 미확인", "Estado de cuenta sin confirmar", "Stato dell’account non confermato",
        "Kontostatus unbestätigt"
      )
    case .deletionCleanupAttention:
      return (
        "Le nettoyage local demande votre attention", "Local cleanup requires attention",
        "स्थानीय सफ़ाई पर ध्यान दें", "本地清理需要处理", "로컬 정리 확인 필요", "La limpieza local requiere atención",
        "La pulizia locale richiede attenzione", "Lokale Bereinigung erfordert Aufmerksamkeit"
      )
    case .deletionCompleted:
      return (
        "Compte supprimé", "Account deleted", "खाता हटाया गया", "账户已删除", "계정 삭제됨", "Cuenta eliminada",
        "Account eliminato", "Konto gelöscht"
      )
    case .deletionTitle:
      return (
        "Supprimer votre compte Certigo", "Delete your Certigo account", "अपना Certigo खाता हटाएँ",
        "删除您的 Certigo 账户", "Certigo 계정 삭제", "Eliminar tu cuenta Certigo",
        "Elimina il tuo account Certigo", "Dein Certigo-Konto löschen"
      )
    case .practiceAvailable:
      return (
        "Exercices disponibles", "Practice available", "अभ्यास उपलब्ध", "练习可用", "연습 가능",
        "Práctica disponible", "Esercizi disponibili", "Übungen verfügbar"
      )
    case .practiceUnavailable:
      return (
        "Exercices indisponibles", "Practice unavailable", "अभ्यास उपलब्ध नहीं है", "暂无练习", "연습 불가",
        "Práctica no disponible", "Esercizi non disponibili", "Übungen nicht verfügbar"
      )
    case .practiceUnavailableNote:
      return (
        "Vous pouvez consulter cette fiche. Aucun pack de questions jouable n’est disponible dans ce catalogue. Aucune date de sortie n’est confirmée.",
        "You can explore this summary. No playable question pack is available in this catalog. No release date is confirmed.",
        "आप यह सारांश देख सकते हैं। इस कैटलॉग में कोई प्रश्न पैक अभ्यास के लिए उपलब्ध नहीं है। रिलीज़ की कोई तारीख तय नहीं है।",
        "你可以查看此简介。本目录中暂无可练习的题包，发布日期尚未确定。",
        "이 요약은 볼 수 있습니다. 이 카탈로그에는 연습 가능한 문제 팩이 없습니다. 출시일은 확정되지 않았습니다.",
        "Puedes consultar esta ficha. No hay un paquete de preguntas para practicar en este catálogo. No se ha confirmado una fecha de publicación.",
        "Puoi consultare questa scheda. In questo catalogo non è disponibile un pacchetto di domande per esercitarti. Non è confermata alcuna data di pubblicazione.",
        "Du kannst diese Übersicht ansehen. In diesem Katalog ist kein Fragenpaket zum Üben verfügbar. Ein Veröffentlichungstermin ist nicht bestätigt."
      )
    case .learn:
      return ("Apprendre", "Learn", "सीखें", "学习", "학습", "Aprender", "Impara", "Lernen")
    case .coach:
      return ("Coach", "Coach", "मार्गदर्शक", "学习教练", "코치", "Entrenador", "Coach", "Coach")
    case .social:
      return ("Communauté", "Social", "समुदाय", "社区", "커뮤니티", "Comunidad", "Community", "Community")
    case .profile:
      return ("Profil", "Profile", "प्रोफ़ाइल", "个人资料", "프로필", "Perfil", "Profilo", "Profil")
    case .myLearning:
      return (
        "Mon apprentissage", "My Learning", "मेरी पढ़ाई", "我的学习", "내 학습", "Mi aprendizaje",
        "Il mio apprendimento", "Mein Lernen"
      )
    case .explore:
      return ("Explorer", "Explore", "खोजें", "探索", "둘러보기", "Explorar", "Esplora", "Entdecken")
    case .friends:
      return ("Amis", "Friends", "मित्र", "好友", "친구", "Amigos", "Amici", "Freunde")
    case .teams:
      return ("Équipes", "Teams", "टीमें", "团队", "팀", "Equipos", "Squadre", "Teams")
    case .appLanguage:
      return (
        "Langue de l’application", "App language", "ऐप की भाषा", "应用语言", "앱 언어",
        "Idioma de la aplicación", "Lingua dell’app", "App-Sprache"
      )
    case .systemDefault:
      return (
        "Langue du système", "System default", "सिस्टम की भाषा", "跟随系统", "시스템 기본값", "Idioma del sistema",
        "Lingua di sistema", "Systemsprache"
      )
    case .contentLanguageNote:
      return (
        "Ce choix traduit les menus et les commandes de l’application. Le texte source officiel des questions de certification et du pilote éditorial reste dans sa langue d’origine ; il n’est pas traduit automatiquement.",
        "This choice translates the app’s menus and controls. The official source text of certification questions and the editorial pilot stays in its original language; it is not automatically translated.",
        "यह विकल्प ऐप के मेनू और नियंत्रणों की भाषा बदलता है। प्रमाणन प्रश्नों और संपादकीय पायलट का आधिकारिक मूल पाठ अपनी मूल भाषा में रहता है; उसका स्वचालित अनुवाद नहीं होता।",
        "此选项仅翻译应用的菜单和控件。认证题目和编辑试点内容的官方原文保留原始语言，不会自动翻译。",
        "이 설정은 앱의 메뉴와 조작 항목을 번역합니다. 인증 시험 문제와 편집 파일럿 콘텐츠의 공식 원문은 원래 언어로 유지되며 자동 번역되지 않습니다.",
        "Esta opción traduce los menús y controles de la aplicación. El texto fuente oficial de las preguntas de certificación y del piloto editorial permanece en su idioma original; no se traduce automáticamente.",
        "Questa scelta traduce i menu e i comandi dell’app. Il testo originale ufficiale delle domande di certificazione e del progetto pilota editoriale resta nella lingua d’origine; non viene tradotto automaticamente.",
        "Diese Auswahl übersetzt die Menüs und Bedienelemente der App. Der offizielle Ausgangstext der Zertifizierungsfragen und des redaktionellen Pilotprojekts bleibt in seiner Originalsprache und wird nicht automatisch übersetzt."
      )
    case .signInWithMicrosoft:
      return (
        "Se connecter avec Microsoft", "Sign in with Microsoft", "Microsoft से साइन इन करें",
        "使用 Microsoft 登录", "Microsoft로 로그인", "Iniciar sesión con Microsoft", "Accedi con Microsoft",
        "Mit Microsoft anmelden"
      )
    case .exploreDemo:
      return (
        "Découvrir la démo", "Explore the demo", "डेमो देखें", "体验演示", "데모 둘러보기", "Explorar la demo",
        "Esplora la demo", "Demo entdecken"
      )
    case .resume:
      return (
        "Reprendre", "Resume", "फिर से शुरू करें", "继续", "이어서 하기", "Reanudar", "Riprendi", "Fortsetzen"
      )
    case .startSession:
      return (
        "Commencer une session", "Start session", "सत्र शुरू करें", "开始学习", "학습 시작",
        "Iniciar sesión de estudio", "Inizia una sessione", "Lerneinheit starten"
      )
    case .practiceAgain:
      return (
        "S’entraîner à nouveau", "Practice again", "फिर से अभ्यास करें", "再次练习", "다시 연습하기",
        "Practicar de nuevo", "Esercitati di nuovo", "Erneut üben"
      )
    case .submitAnswer:
      return (
        "Envoyer la réponse", "Submit answer", "उत्तर भेजें", "提交答案", "답안 제출", "Enviar respuesta",
        "Invia risposta", "Antwort absenden"
      )
    case .retry:
      return (
        "Réessayer", "Retry", "फिर से कोशिश करें", "重试", "다시 시도", "Reintentar", "Riprova",
        "Erneut versuchen"
      )
    case .loading:
      return (
        "Chargement…", "Loading…", "लोड हो रहा है…", "正在加载…", "불러오는 중…", "Cargando…", "Caricamento…",
        "Wird geladen…"
      )
    case .progressAndHistory:
      return (
        "Progression et historique", "Progress & history", "प्रगति और इतिहास", "进度与历史记录", "진도 및 기록",
        "Progreso e historial", "Progressi e cronologia", "Fortschritt und Verlauf"
      )
    case .settings:
      return ("Réglages", "Settings", "सेटिंग्स", "设置", "설정", "Ajustes", "Impostazioni", "Einstellungen")
    case .accountDeletion:
      return (
        "Suppression du compte", "Account deletion", "खाता हटाना", "删除账户", "계정 삭제",
        "Eliminación de la cuenta", "Eliminazione dell’account", "Kontolöschung"
      )
    case .pending:
      return ("En attente", "Pending", "लंबित", "待处理", "대기 중", "Pendiente", "In attesa", "Ausstehend")
    case .confirmed:
      return (
        "Confirmé", "Confirmed", "पुष्टि हो गई", "已确认", "확인됨", "Confirmado", "Confermato", "Bestätigt"
      )
    case .signOut:
      return (
        "Se déconnecter", "Sign out", "साइन आउट करें", "退出登录", "로그아웃", "Cerrar sesión", "Esci",
        "Abmelden"
      )
    case .cancel:
      return ("Annuler", "Cancel", "रद्द करें", "取消", "취소", "Cancelar", "Annulla", "Abbrechen")
    case .done:
      return ("Terminé", "Done", "हो गया", "完成", "완료", "Listo", "Fine", "Fertig")
    case .back:
      return ("Retour", "Back", "वापस", "返回", "뒤로", "Atrás", "Indietro", "Zurück")
    case .continueLearning:
      return (
        "Continuer à apprendre", "Continue learning", "सीखना जारी रखें", "继续学习", "계속 학습하기",
        "Seguir aprendiendo", "Continua a imparare", "Weiterlernen"
      )
    case .answer:
      return ("Réponse", "Answer", "उत्तर", "答案", "답안", "Respuesta", "Risposta", "Antwort")
    case .next:
      return ("Suivant", "Next", "अगला", "下一步", "다음", "Siguiente", "Avanti", "Weiter")
    case .previous:
      return ("Précédent", "Previous", "पिछला", "上一步", "이전", "Anterior", "Precedente", "Zurück")
    case .offline:
      return ("Hors ligne", "Offline", "ऑफ़लाइन", "离线", "오프라인", "Sin conexión", "Offline", "Offline")
    case .pendingCorrection:
      return (
        "En attente de correction serveur", "Awaiting server grading", "सर्वर द्वारा मूल्यांकन की प्रतीक्षा",
        "等待服务器评分", "서버 채점 대기 중", "Pendiente de corrección del servidor",
        "In attesa della valutazione del server", "Serverbewertung ausstehend"
      )
    case .noHistory:
      return (
        "Aucun historique pour le moment", "No history yet", "अभी कोई इतिहास नहीं है", "暂无历史记录",
        "아직 기록이 없습니다", "Aún no hay historial", "Nessuna attività precedente", "Noch kein Verlauf"
      )
    case .deleteAccount:
      return (
        "Supprimer le compte", "Delete account", "खाता हटाएँ", "删除账户", "계정 삭제", "Eliminar cuenta",
        "Elimina account", "Konto löschen"
      )
    case .demo:
      return ("Démo", "Demo", "डेमो", "演示", "데모", "Demo", "Demo", "Demo")
    case .chooseGoal:
      return (
        "Choisir un objectif", "Choose a goal", "लक्ष्य चुनें", "选择目标", "목표 선택", "Elegir un objetivo",
        "Scegli un obiettivo", "Ziel auswählen"
      )
    case .categoryAll:
      return ("Toutes", "All", "सभी", "全部", "전체", "Todas", "Tutte", "Alle")
    case .categoryCloud:
      return ("Cloud", "Cloud", "क्लाउड", "云计算", "클라우드", "Nube", "Cloud", "Cloud")
    case .categoryAI:
      return (
        "Intelligence artificielle", "Artificial intelligence", "कृत्रिम बुद्धिमत्ता", "人工智能", "인공지능",
        "Inteligencia artificial", "Intelligenza artificiale", "Künstliche Intelligenz"
      )
    case .categoryApple:
      return (
        "Écosystème Apple", "Apple ecosystem", "Apple इकोसिस्टम", "Apple 生态系统", "Apple 생태계",
        "Ecosistema Apple", "Ecosistema Apple", "Apple-Ökosystem"
      )
    case .categoryData:
      return ("Données", "Data", "डेटा", "数据", "데이터", "Datos", "Dati", "Daten")
    case .categoryDevOps:
      return (
        "Développement et opérations", "Development & operations", "विकास और संचालन", "开发与运维",
        "개발 및 운영", "Desarrollo y operaciones", "Sviluppo e operazioni", "Entwicklung und Betrieb"
      )
    case .categoryCyber:
      return (
        "Cybersécurité", "Cybersecurity", "साइबर सुरक्षा", "网络安全", "사이버 보안", "Ciberseguridad",
        "Sicurezza informatica", "Cybersicherheit"
      )
    case .categoryEnterprise:
      return ("Entreprise", "Enterprise", "उद्यम", "企业", "기업", "Empresa", "Impresa", "Unternehmen")
    case .categoryOther:
      return ("Autres", "Other", "अन्य", "其他", "기타", "Otras", "Altre", "Sonstige")
    case .contentLanguageFR:
      return (
        "Contenu en français", "Content in French", "फ़्रेंच में सामग्री", "法语内容", "프랑스어 콘텐츠",
        "Contenido en francés", "Contenuti in francese", "Inhalte auf Französisch"
      )
    case .contentLanguageEN:
      return (
        "Contenu en anglais", "Content in English", "अंग्रेज़ी में सामग्री", "英语内容", "영어 콘텐츠",
        "Contenido en inglés", "Contenuti in inglese", "Inhalte auf Englisch"
      )
    case .recommendedReview:
      return (
        "Révision recommandée", "Recommended review", "सुझाया गया पुनराभ्यास", "推荐复习", "추천 복습",
        "Repaso recomendado", "Ripasso consigliato", "Empfohlene Wiederholung"
      )
    case .reviewReasonLowScore:
      return (
        "Renforcer un résultat plus faible", "Improve a lower score", "कम अंक वाले विषय को मज़बूत करें",
        "巩固得分较低的内容", "낮은 점수 보완하기", "Mejorar una puntuación baja", "Migliora un risultato più basso",
        "Ein schwächeres Ergebnis verbessern"
      )
    case .reviewReasonDue:
      return (
        "Révision à reprendre", "Review to revisit", "फिर से अभ्यास करने का विषय", "待复习内容", "다시 복습할 내용",
        "Repaso pendiente", "Ripasso da riprendere", "Anstehende Wiederholung"
      )
    case .reviewReasonContinue:
      return (
        "Poursuivre l’apprentissage", "Continue learning", "सीखना जारी रखें", "继续学习", "계속 학습하기",
        "Seguir aprendiendo", "Continua a imparare", "Weiterlernen"
      )
    case .startReview:
      return (
        "Commencer la révision", "Start review", "पुनराभ्यास शुरू करें", "开始复习", "복습 시작", "Empezar repaso",
        "Inizia il ripasso", "Wiederholung starten"
      )
    case .explainWithCoach:
      return (
        "Expliquer avec le coach", "Explain with Coach", "मार्गदर्शक से समझें", "请教学习教练", "코치에게 설명 요청",
        "Explicar con el entrenador", "Chiedi una spiegazione al coach", "Vom Coach erklären lassen"
      )
    case .coachWorkspaceTitle:
      return (
        "Coach pédagogique", "Learning coach", "अध्ययन मार्गदर्शक", "学习教练", "학습 코치",
        "Entrenador de aprendizaje", "Coach di apprendimento", "Lerncoach"
      )
    case .coachExplaining:
      return (
        "Préparation de l’explication…", "Preparing an explanation…", "समझाया जा रहा है…", "正在准备讲解…",
        "설명 준비 중…", "Preparando una explicación…", "Preparazione della spiegazione…",
        "Erklärung wird vorbereitet…"
      )
    case .coachHeadline:
      return (
        "Comprendre la réponse", "Understand the answer", "उत्तर को समझें", "理解答案", "답안 이해하기",
        "Entender la respuesta", "Comprendi la risposta", "Die Antwort verstehen"
      )
    case .coachKeyPoints:
      return (
        "Points clés", "Key points", "मुख्य बातें", "要点", "핵심 내용", "Puntos clave", "Punti chiave",
        "Kernpunkte"
      )
    case .coachRecommendation:
      return (
        "Prochaine étape conseillée", "Recommended next step", "सुझाया गया अगला कदम", "建议下一步",
        "추천 다음 단계", "Siguiente paso recomendado", "Prossimo passo consigliato",
        "Empfohlener nächster Schritt"
      )
    case .coachPersonalization:
      return (
        "Selon votre historique", "Based on your history", "आपके इतिहास के आधार पर", "根据你的学习记录",
        "내 학습 기록 기반", "Según tu historial", "In base alla tua cronologia",
        "Basierend auf deinem Verlauf"
      )
    case .coachSourceGrounded:
      return (
        "Explication fondée sur le contenu", "Content-grounded explanation", "सामग्री पर आधारित स्पष्टीकरण",
        "基于学习内容的讲解", "학습 콘텐츠에 근거한 설명", "Explicación basada en el contenido",
        "Spiegazione basata sui contenuti", "Auf Lerninhalten basierende Erklärung"
      )
    case .coachPromptHint:
      return (
        "Répondez à une question pour demander une explication.",
        "Answer a question to request an explanation.", "स्पष्टीकरण माँगने के लिए किसी प्रश्न का उत्तर दें।",
        "回答一道题目后即可请求讲解。", "문제에 답한 뒤 설명을 요청하세요.",
        "Responde una pregunta para pedir una explicación.",
        "Rispondi a una domanda per richiedere una spiegazione.",
        "Beantworte eine Frage, um eine Erklärung anzufordern."
      )
    case .searchPlaceholder:
      return (
        "Rechercher une certification", "Search certifications", "प्रमाणन खोजें", "搜索认证", "인증 검색",
        "Buscar certificaciones", "Cerca certificazioni", "Zertifizierungen suchen"
      )
    case .noMatchingTracks:
      return (
        "Aucun parcours correspondant", "No matching tracks", "कोई मिलता-जुलता पाठ्यक्रम नहीं", "没有匹配的学习路径",
        "일치하는 학습 경로 없음", "No hay itinerarios coincidentes", "Nessun percorso corrispondente",
        "Keine passenden Lernpfade"
      )
    case .clearFilters:
      return (
        "Effacer les filtres", "Clear filters", "फ़िल्टर हटाएँ", "清除筛选", "필터 지우기", "Borrar filtros",
        "Rimuovi filtri", "Filter zurücksetzen"
      )
    case .activeGoalBadge:
      return (
        "Objectif actif", "Active goal", "सक्रिय लक्ष्य", "当前目标", "현재 목표", "Objetivo activo",
        "Obiettivo attivo", "Aktuelles Ziel"
      )
    case .masteryNotStarted:
      return (
        "Non commencé", "Not started", "अभी शुरू नहीं किया", "未开始", "시작 전", "Sin empezar", "Non iniziato",
        "Noch nicht begonnen"
      )
    case .masteryLearning:
      return (
        "En apprentissage", "Learning", "सीख रहे हैं", "学习中", "학습 중", "Aprendiendo", "In apprendimento",
        "Im Lernen"
      )
    case .masteryPracticing:
      return (
        "En pratique", "Practicing", "अभ्यास कर रहे हैं", "练习中", "연습 중", "Practicando",
        "In esercitazione", "Im Üben"
      )
    case .masteryMastered:
      return (
        "Maîtrisé", "Mastered", "महारत हासिल", "已掌握", "숙달", "Dominado", "Padroneggiato", "Beherrscht"
      )
    case .masteryExamReady:
      return (
        "Préparation consolidée", "Exam ready", "परीक्षा की तैयारी पूरी", "考试准备就绪", "시험 준비 완료",
        "Preparación consolidada", "Pronto per l’esame", "Prüfungsbereit"
      )
    case .focusArea:
      return (
        "Domaine à renforcer", "Focus area", "ध्यान देने का क्षेत्र", "重点提升领域", "집중 학습 영역", "Área de enfoque",
        "Area su cui concentrarsi", "Schwerpunktbereich"
      )
    case .startFocusSession:
      return (
        "Renforcer ce domaine", "Start focus session", "केंद्रित सत्र शुरू करें", "开始专项学习", "집중 학습 시작",
        "Iniciar sesión de refuerzo", "Inizia una sessione mirata",
        "Schwerpunkt-Lerneinheit starten"
      )
    case .spacedRepetitionReview:
      return (
        "Révision espacée", "Spaced repetition review", "अंतराल पर पुनराभ्यास", "间隔复习", "간격 반복 복습",
        "Repaso espaciado", "Ripasso a intervalli", "Verteilte Wiederholung"
      )
    case .startFinalAssessment:
      return (
        "Commencer l’évaluation finale", "Start final assessment", "अंतिम मूल्यांकन शुरू करें", "开始最终测评",
        "최종 평가 시작", "Iniciar evaluación final", "Inizia la valutazione finale",
        "Abschlussbewertung starten"
      )
    case .youreReady:
      return (
        "Vous êtes prêt", "You’re ready", "आप तैयार हैं", "你已准备就绪", "준비가 되었습니다", "Estás listo",
        "Sei pronto", "Du bist bereit"
      )
    case .explainDifferently:
      return (
        "Expliquer autrement", "Explain differently", "अलग तरह से समझाएँ", "换个方式解释", "다른 방식으로 설명",
        "Explicar de otra forma", "Spiega diversamente", "Anders erklären"
      )
    case .whyWasIWrong:
      return (
        "Pourquoi cette erreur ?", "Why was I wrong?", "मेरा उत्तर गलत क्यों था?", "我为什么答错了？", "왜 틀렸나요?",
        "¿Por qué me equivoqué?", "Perché ho sbagliato?", "Warum war meine Antwort falsch?"
      )
    case .targetExamDate:
      return (
        "Date cible d’examen", "Target exam date", "परीक्षा की लक्ष्य तिथि", "目标考试日期", "목표 시험 날짜",
        "Fecha objetivo del examen", "Data prevista dell’esame", "Angestrebter Prüfungstermin"
      )
    case .initialLevel:
      return (
        "Niveau initial", "Initial level", "शुरुआती स्तर", "初始水平", "시작 수준", "Nivel inicial",
        "Livello iniziale", "Ausgangsniveau"
      )
    case .dailyMinutesGoal:
      return (
        "Objectif quotidien en minutes", "Daily minutes goal", "दैनिक मिनटों का लक्ष्य", "每日学习分钟目标",
        "일일 학습 시간 목표(분)", "Objetivo diario en minutos", "Obiettivo giornaliero in minuti",
        "Tägliches Lernziel in Minuten"
      )
    case .levelBeginner:
      return (
        "Débutant", "Beginner", "शुरुआती", "初学者", "초급", "Principiante", "Principiante", "Anfänger"
      )
    case .levelIntermediate:
      return (
        "Intermédiaire", "Intermediate", "मध्यम", "中级", "중급", "Intermedio", "Intermedio",
        "Fortgeschritten"
      )
    case .levelAdvanced:
      return ("Avancé", "Advanced", "उन्नत", "高级", "고급", "Avanzado", "Avanzato", "Erfahren")
    case .notifications:
      return (
        "Notifications", "Notifications", "सूचनाएँ", "通知", "알림", "Notificaciones", "Notifiche",
        "Benachrichtigungen"
      )
    case .notificationsEnabled:
      return (
        "Activer les notifications", "Enable notifications", "सूचनाएँ चालू करें", "启用通知", "알림 사용",
        "Activar notificaciones", "Attiva notifiche", "Benachrichtigungen aktivieren"
      )
    case .quietHours:
      return (
        "Heures de silence", "Quiet hours", "शांत समय", "免打扰时段", "방해 금지 시간", "Horas de silencio",
        "Orario silenzioso", "Ruhezeiten"
      )
    case .preferredHour:
      return (
        "Heure préférée", "Preferred hour", "पसंदीदा समय", "首选时间", "선호 시간", "Hora preferida",
        "Orario preferito", "Bevorzugte Uhrzeit"
      )
    case .maxPerDay:
      return (
        "Maximum par jour", "Maximum per day", "प्रति दिन अधिकतम", "每日上限", "일일 최대 횟수", "Máximo por día",
        "Massimo al giorno", "Höchstens pro Tag"
      )
    case .streakAlerts:
      return (
        "Rappels de série", "Streak reminders", "लगातार अभ्यास के अनुस्मारक", "连续学习提醒", "연속 학습 알림",
        "Recordatorios de racha", "Promemoria serie", "Serienerinnerungen"
      )
    case .questAlerts:
      return (
        "Rappels de quêtes", "Quest reminders", "मिशन अनुस्मारक", "任务提醒", "퀘스트 알림",
        "Recordatorios de misiones", "Promemoria missioni", "Aufgabenerinnerungen"
      )
    case .leagueAlerts:
      return (
        "Rappels de ligue", "League reminders", "लीग अनुस्मारक", "联赛提醒", "리그 알림",
        "Recordatorios de liga", "Promemoria lega", "Ligaerinnerungen"
      )
    }
  }
}
