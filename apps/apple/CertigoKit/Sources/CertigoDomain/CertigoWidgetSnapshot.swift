import Foundation

public enum CertigoWidgetPhase: String, Codable, CaseIterable, Sendable {
  case readyToStart
  case inProgress
  case streakAtRisk
  case goalCompleted
}

public enum CertigoWidgetRoute: String, Codable, CaseIterable, Sendable {
  case learn
  case review

  public var url: URL? {
    URL(string: "certigo://widget/\(rawValue)")
  }

  public init?(url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme?.lowercased() == "certigo",
      components.host?.lowercased() == "widget",
      components.user == nil, components.password == nil, components.port == nil,
      components.query == nil, components.fragment == nil,
      components.percentEncodedPath == components.path,
      let route = Self(rawValue: String(components.path.dropFirst()))
    else {
      return nil
    }
    self = route
  }
}

public enum CertigoWidgetSnapshotError: Error, Equatable, Sendable {
  case invalid
  case stale
}

public struct CertigoWidgetSnapshot: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 1

  public let schemaVersion: Int
  public let revision: UUID
  public let updatedAt: Date
  public let validUntil: Date
  public let studyDay: String
  public let studyDayUtcOffsetMinutes: Int
  public let totalXP: Int
  public let streakDays: Int?
  public let dailyGoalXP: Int?
  public let dailyXPEarned: Int?
  public let activeTrackCode: String?
  public let activeTrackTitle: String?
  public let serverStreakRisk: Bool
  public let studyPlanDailyMinutes: Int?
  public let targetExamDate: Date?
  public let language: AppLanguage
  public let parallelTracksSummary: String?
  public let aiRadarHeadline: String?

  /// §15 NS-14, DR-004 & §22A.7 invariants: never store answer keys or render third-party logos in widget containers.
  public var storesAnswerKeyInWidgetContainer: Bool { false }
  public var rendersThirdPartyBrandLogoInWidgetExtension: Bool { false }

  public init(
    updatedAt: Date = .now,
    validUntil: Date,
    studyDay: String,
    studyDayUtcOffsetMinutes: Int,
    totalXP: Int,
    streakDays: Int?,
    dailyGoalXP: Int?,
    dailyXPEarned: Int?,
    activeTrackCode: String?,
    activeTrackTitle: String?,
    serverStreakRisk: Bool,
    studyPlanDailyMinutes: Int?,
    targetExamDate: Date?,
    language: AppLanguage,
    parallelTracksSummary: String? = nil,
    aiRadarHeadline: String? = nil,
    revision: UUID = UUID()
  ) throws {
    self.schemaVersion = Self.currentSchemaVersion
    self.revision = revision
    self.updatedAt = updatedAt
    self.validUntil = validUntil
    self.studyDay = studyDay
    self.studyDayUtcOffsetMinutes = studyDayUtcOffsetMinutes
    self.totalXP = totalXP
    self.streakDays = streakDays
    self.dailyGoalXP = dailyGoalXP
    self.dailyXPEarned = dailyXPEarned
    self.activeTrackCode = activeTrackCode
    self.activeTrackTitle = activeTrackTitle
    self.serverStreakRisk = serverStreakRisk
    self.studyPlanDailyMinutes = studyPlanDailyMinutes
    self.targetExamDate = targetExamDate
    self.language = language
    self.parallelTracksSummary = parallelTracksSummary
    self.aiRadarHeadline = aiRadarHeadline
    _ = try validated()
  }

  public static func make(
    profile: Profile,
    tracks: [Track],
    notificationPlan: NotificationPlan?,
    notificationSettings: NotificationSettings?,
    studyPlan: CertigoStudyPlanPreference?,
    language: AppLanguage,
    now: Date = .now,
    deviceTimeZone: TimeZone = .autoupdatingCurrent
  ) throws -> Self {
    let offsetMinutes =
      notificationSettings?.utcOffsetMinutes
      ?? deviceTimeZone.secondsFromGMT(for: now) / 60
    guard (-720...840).contains(offsetMinutes),
      let timeZone = TimeZone(secondsFromGMT: offsetMinutes * 60)
    else {
      throw CertigoWidgetSnapshotError.invalid
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    guard let day = Self.studyDayKey(at: now, utcOffsetMinutes: offsetMinutes),
      let nextDay = calendar.date(
        byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    else {
      throw CertigoWidgetSnapshotError.invalid
    }
    let track = profile.activeTrackId.flatMap { activeID in
      tracks.first { $0.id.caseInsensitiveCompare(activeID) == .orderedSame }
    }
    let hasCurrentNotificationPlan = notificationPlan?.localDate == day
    let serverStreakRisk =
      (profile.streakDays ?? 0) > 0
      && hasCurrentNotificationPlan
      && (notificationPlan?.notifications.contains {
        $0.kind.caseInsensitiveCompare("StreakDanger") == .orderedSame
      } ?? false)
    return try Self(
      updatedAt: now,
      validUntil: nextDay,
      studyDay: day,
      studyDayUtcOffsetMinutes: offsetMinutes,
      totalXP: profile.xp,
      streakDays: profile.streakDays,
      dailyGoalXP: profile.dailyGoalXp,
      dailyXPEarned: profile.dailyXpEarned,
      activeTrackCode: track?.code,
      activeTrackTitle: track?.title,
      serverStreakRisk: serverStreakRisk,
      studyPlanDailyMinutes: studyPlan?.dailyMinutesGoal,
      targetExamDate: studyPlan?.targetExamDate,
      language: language
    )
  }

  public var dailyGoalProgress: Double? {
    guard let dailyGoalXP, dailyGoalXP > 0, let dailyXPEarned, dailyXPEarned >= 0 else {
      return nil
    }
    return min(1, Double(dailyXPEarned) / Double(dailyGoalXP))
  }

  public var destination: CertigoWidgetRoute {
    .learn
  }

  public func validated() throws -> Self {
    let codeIsValid = activeTrackCode.map {
      !$0.isEmpty && $0.utf8.count <= 64
        && $0.unicodeScalars.allSatisfy {
          CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_:")
            .contains($0)
        }
    } ?? true
    let titleIsValid = activeTrackTitle.map { !$0.isEmpty && $0.utf8.count <= 160 } ?? true
    let parallelSummaryIsValid =
      parallelTracksSummary.map { !$0.isEmpty && $0.utf8.count <= 64 } ?? true
    let radarHeadlineIsValid =
      aiRadarHeadline.map { !$0.isEmpty && $0.utf8.count <= 160 } ?? true
    let dayIsValid = Self.parseDay(studyDay) != nil
    guard schemaVersion == Self.currentSchemaVersion,
      updatedAt.timeIntervalSince1970.isFinite, updatedAt.timeIntervalSince1970 >= 0,
      validUntil.timeIntervalSince1970.isFinite, validUntil > updatedAt,
      validUntil.timeIntervalSince(updatedAt) <= 36 * 60 * 60,
      dayIsValid, (-720...840).contains(studyDayUtcOffsetMinutes),
      Self.studyDayKey(at: updatedAt, utcOffsetMinutes: studyDayUtcOffsetMinutes) == studyDay,
      totalXP >= 0, totalXP <= 1_000_000_000,
      streakDays.map({ (0...1_000_000).contains($0) }) ?? true,
      dailyGoalXP.map({ (1...1_000_000).contains($0) }) ?? true,
      dailyXPEarned.map({ (0...1_000_000_000).contains($0) }) ?? true,
      studyPlanDailyMinutes.map({ (1...1_440).contains($0) }) ?? true,
      targetExamDate.map({ $0.timeIntervalSince1970.isFinite && $0.timeIntervalSince1970 >= 0 })
        ?? true,
      codeIsValid, titleIsValid, parallelSummaryIsValid, radarHeadlineIsValid,
      activeTrackCode == nil || activeTrackTitle != nil,
      !serverStreakRisk || (streakDays ?? 0) > 0
    else {
      throw CertigoWidgetSnapshotError.invalid
    }
    return self
  }

  public func isFresh(at date: Date) -> Bool {
    guard date >= updatedAt.addingTimeInterval(-5 * 60), date < validUntil,
      let currentDay = Self.studyDayKey(
        at: date, utcOffsetMinutes: studyDayUtcOffsetMinutes)
    else {
      return false
    }
    return currentDay == studyDay
  }

  public func phase(at date: Date) -> CertigoWidgetPhase? {
    guard isFresh(at: date) else { return nil }
    if serverStreakRisk { return .streakAtRisk }
    if let progress = dailyGoalProgress, progress >= 1 { return .goalCompleted }
    if (dailyXPEarned ?? 0) > 0 { return .inProgress }
    return .readyToStart
  }

  public static func studyDayKey(at date: Date, utcOffsetMinutes: Int) -> String? {
    guard (-720...840).contains(utcOffsetMinutes), date.timeIntervalSince1970.isFinite else {
      return nil
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: utcOffsetMinutes * 60) ?? .gmt
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    return String(format: "%04d-%02d-%02d", year, month, day)
  }

  private static func parseDay(_ value: String) -> Date? {
    guard value.utf8.count == 10 else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.date(from: value)
  }
}

public struct CertigoWidgetCopy: Sendable {
  public let language: AppLanguage

  public init(language: AppLanguage) {
    self.language = language
  }

  public func title(for phase: CertigoWidgetPhase) -> String {
    switch (language, phase) {
    case (.french, .readyToStart): "Une étape aujourd’hui ?"
    case (.english, .readyToStart): "A small step today?"
    case (.hindi, .readyToStart): "आज एक छोटा कदम?"
    case (.chineseSimplified, .readyToStart): "今天迈出一小步？"
    case (.korean, .readyToStart): "오늘 한 걸음?"
    case (.spanish, .readyToStart): "¿Un paso hoy?"
    case (.italian, .readyToStart): "Un piccolo passo oggi?"
    case (.german, .readyToStart): "Ein kleiner Schritt heute?"
    case (.french, .inProgress): "Continuez sur votre lancée"
    case (.english, .inProgress): "Keep your momentum"
    case (.hindi, .inProgress): "अपनी प्रगति जारी रखें"
    case (.chineseSimplified, .inProgress): "继续保持进度"
    case (.korean, .inProgress): "꾸준히 이어가세요"
    case (.spanish, .inProgress): "Sigue con tu progreso"
    case (.italian, .inProgress): "Continua così"
    case (.german, .inProgress): "Bleib im Lernfluss"
    case (.french, .streakAtRisk): "Votre série attend une séance"
    case (.english, .streakAtRisk): "Your streak is waiting for a session"
    case (.hindi, .streakAtRisk): "आपकी स्ट्रीक एक सत्र की प्रतीक्षा में है"
    case (.chineseSimplified, .streakAtRisk): "完成一次学习，延续连续学习"
    case (.korean, .streakAtRisk): "학습 세션으로 연속 기록을 이어가세요"
    case (.spanish, .streakAtRisk): "Tu racha espera una sesión"
    case (.italian, .streakAtRisk): "La tua serie aspetta una sessione"
    case (.german, .streakAtRisk): "Deine Serie wartet auf eine Lerneinheit"
    case (.french, .goalCompleted): "Objectif du jour atteint"
    case (.english, .goalCompleted): "Today's goal reached"
    case (.hindi, .goalCompleted): "आज का लक्ष्य पूरा हुआ"
    case (.chineseSimplified, .goalCompleted): "今日目标已达成"
    case (.korean, .goalCompleted): "오늘의 목표를 달성했어요"
    case (.spanish, .goalCompleted): "Objetivo de hoy alcanzado"
    case (.italian, .goalCompleted): "Obiettivo di oggi raggiunto"
    case (.german, .goalCompleted): "Tagesziel erreicht"
    }
  }

  public var continueLearning: String {
    switch language {
    case .french: "Reprendre"
    case .english: "Continue"
    case .hindi: "जारी रखें"
    case .chineseSimplified: "继续学习"
    case .korean: "계속하기"
    case .spanish: "Continuar"
    case .italian: "Continua"
    case .german: "Weiterlernen"
    }
  }

  public var streakLabel: String {
    switch language {
    case .french: "jours de série"
    case .english: "day streak"
    case .hindi: "दिनों की स्ट्रीक"
    case .chineseSimplified: "天连续学习"
    case .korean: "일 연속 학습"
    case .spanish: "días de racha"
    case .italian: "giorni di serie"
    case .german: "Tage in Folge"
    }
  }

  public func dailyGoalAccessibility(progress: Double?) -> String {
    guard let progress else {
      return switch language {
      case .french: "Progression de l’objectif quotidien indisponible"
      case .english: "Daily goal progress unavailable"
      case .hindi: "दैनिक लक्ष्य की प्रगति उपलब्ध नहीं है"
      case .chineseSimplified: "每日目标进度不可用"
      case .korean: "일일 목표 진행 상황을 사용할 수 없어요"
      case .spanish: "Progreso del objetivo diario no disponible"
      case .italian: "Progresso dell’obiettivo giornaliero non disponibile"
      case .german: "Fortschritt des Tagesziels nicht verfügbar"
      }
    }
    let percentage = Int((min(1, max(0, progress)) * 100).rounded())
    return switch language {
    case .french: "Progression de l’objectif quotidien : \(percentage) %"
    case .english: "Daily goal progress: \(percentage)%"
    case .hindi: "दैनिक लक्ष्य की प्रगति: \(percentage)%"
    case .chineseSimplified: "每日目标进度：\(percentage)%"
    case .korean: "일일 목표 진행률: \(percentage)%"
    case .spanish: "Progreso del objetivo diario: \(percentage)%"
    case .italian: "Progresso dell’obiettivo giornaliero: \(percentage)%"
    case .german: "Fortschritt des Tagesziels: \(percentage)%"
    }
  }

  public var openCertigo: String {
    switch language {
    case .french: "Ouvrez Certigo pour actualiser"
    case .english: "Open Certigo to refresh"
    case .hindi: "अपडेट करने के लिए Certigo खोलें"
    case .chineseSimplified: "打开 Certigo 以刷新"
    case .korean: "새로 고치려면 Certigo를 여세요"
    case .spanish: "Abre Certigo para actualizar"
    case .italian: "Apri Certigo per aggiornare"
    case .german: "Öffne Certigo zum Aktualisieren"
    }
  }

  public var noGoal: String {
    switch language {
    case .french: "Choisissez un objectif"
    case .english: "Choose a learning goal"
    case .hindi: "सीखने का लक्ष्य चुनें"
    case .chineseSimplified: "选择学习目标"
    case .korean: "학습 목표를 선택하세요"
    case .spanish: "Elige un objetivo"
    case .italian: "Scegli un obiettivo"
    case .german: "Wähle ein Lernziel"
    }
  }

  public var galleryTitle: String {
    switch language {
    case .french: "Widgets Certigo"
    case .english: "Certigo widgets"
    case .hindi: "Certigo विजेट"
    case .chineseSimplified: "Certigo 小组件"
    case .korean: "Certigo 위젯"
    case .spanish: "Widgets de Certigo"
    case .italian: "Widget Certigo"
    case .german: "Certigo-Widgets"
    }
  }

  public var simulatedLabel: String {
    switch language {
    case .french: "Simulation — données fictives"
    case .english: "Preview — sample data"
    case .hindi: "पूर्वावलोकन — नमूना डेटा"
    case .chineseSimplified: "预览 — 示例数据"
    case .korean: "미리보기 — 샘플 데이터"
    case .spanish: "Vista previa — datos de ejemplo"
    case .italian: "Anteprima — dati di esempio"
    case .german: "Vorschau — Beispieldaten"
    }
  }

  public var liveLabel: String {
    switch language {
    case .french: "Données du compte"
    case .english: "Account data"
    case .hindi: "खाते का डेटा"
    case .chineseSimplified: "账户数据"
    case .korean: "계정 데이터"
    case .spanish: "Datos de la cuenta"
    case .italian: "Dati dell’account"
    case .german: "Kontodaten"
    }
  }

  public var sharingNotConfigured: String {
    switch language {
    case .french: "Le partage des données du widget n’est pas configuré."
    case .english: "Widget data sharing is not configured."
    case .hindi: "विजेट डेटा साझाकरण कॉन्फ़िगर नहीं है।"
    case .chineseSimplified: "尚未配置小组件数据共享。"
    case .korean: "위젯 데이터 공유가 설정되지 않았어요."
    case .spanish: "El uso compartido de datos del widget no está configurado."
    case .italian: "La condivisione dei dati del widget non è configurata."
    case .german: "Die Widget-Datenfreigabe ist nicht eingerichtet."
    }
  }

  public var previewMode: String {
    switch language {
    case .french: "Mode d’aperçu"
    case .english: "Preview mode"
    case .hindi: "पूर्वावलोकन मोड"
    case .chineseSimplified: "预览模式"
    case .korean: "미리보기 모드"
    case .spanish: "Modo de vista previa"
    case .italian: "Modalità anteprima"
    case .german: "Vorschaumodus"
    }
  }

  public var widgetGalleryNote: String {
    switch language {
    case .french: "Les widgets installés partagent les données du compte uniquement avec le groupe App Group configuré. Le système choisit l’heure d’actualisation."
    case .english: "Installed widgets share account data only through the configured App Group. iOS decides when timelines refresh."
    case .hindi: "इंस्टॉल किए गए विजेट खाते का डेटा केवल कॉन्फ़िगर किए गए App Group से साझा करते हैं। रिफ्रेश का समय iOS तय करता है।"
    case .chineseSimplified: "已安装的小组件仅通过已配置的 App Group 共享账户数据。刷新时间由 iOS 决定。"
    case .korean: "설치된 위젯은 구성된 App Group을 통해서만 계정 데이터를 공유합니다. 새로 고침 시점은 iOS가 결정합니다."
    case .spanish: "Los widgets instalados comparten datos de la cuenta solo mediante el App Group configurado. iOS decide cuándo actualizar."
    case .italian: "I widget installati condividono i dati dell’account solo tramite l’App Group configurato. iOS decide quando aggiornare."
    case .german: "Installierte Widgets teilen Kontodaten nur über die eingerichtete App Group. iOS bestimmt den Aktualisierungszeitpunkt."
    }
  }

  public var widgetDataUnreadable: String {
    switch language {
    case .french: "Les données du widget sont illisibles."
    case .english: "Widget data cannot be read."
    case .hindi: "विजेट डेटा पढ़ा नहीं जा सकता।"
    case .chineseSimplified: "无法读取小组件数据。"
    case .korean: "위젯 데이터를 읽을 수 없어요."
    case .spanish: "No se pueden leer los datos del widget."
    case .italian: "Impossibile leggere i dati del widget."
    case .german: "Widget-Daten können nicht gelesen werden."
    }
  }

  public var widgetStorageError: String {
    switch language {
    case .french: "Le stockage du widget est indisponible."
    case .english: "Widget storage is unavailable."
    case .hindi: "विजेट संग्रहण उपलब्ध नहीं है।"
    case .chineseSimplified: "小组件存储不可用。"
    case .korean: "위젯 저장소를 사용할 수 없어요."
    case .spanish: "El almacenamiento del widget no está disponible."
    case .italian: "Lo spazio del widget non è disponibile."
    case .german: "Der Widget-Speicher ist nicht verfügbar."
    }
  }

  public func phaseName(_ phase: CertigoWidgetPhase) -> String {
    switch (language, phase) {
    case (.french, .readyToStart): "Prêt à commencer"
    case (.english, .readyToStart): "Ready to start"
    case (.hindi, .readyToStart): "शुरू करने के लिए तैयार"
    case (.chineseSimplified, .readyToStart): "准备开始"
    case (.korean, .readyToStart): "시작할 준비"
    case (.spanish, .readyToStart): "Listo para empezar"
    case (.italian, .readyToStart): "Pronto per iniziare"
    case (.german, .readyToStart): "Bereit zum Start"
    case (.french, .inProgress): "En cours"
    case (.english, .inProgress): "In progress"
    case (.hindi, .inProgress): "जारी है"
    case (.chineseSimplified, .inProgress): "进行中"
    case (.korean, .inProgress): "진행 중"
    case (.spanish, .inProgress): "En curso"
    case (.italian, .inProgress): "In corso"
    case (.german, .inProgress): "In Arbeit"
    case (.french, .streakAtRisk): "Série à préserver"
    case (.english, .streakAtRisk): "Streak at risk"
    case (.hindi, .streakAtRisk): "स्ट्रीक बचाएँ"
    case (.chineseSimplified, .streakAtRisk): "连续记录待延续"
    case (.korean, .streakAtRisk): "연속 기록 지키기"
    case (.spanish, .streakAtRisk): "Racha en riesgo"
    case (.italian, .streakAtRisk): "Serie da proteggere"
    case (.german, .streakAtRisk): "Serie in Gefahr"
    case (.french, .goalCompleted): "Objectif atteint"
    case (.english, .goalCompleted): "Goal complete"
    case (.hindi, .goalCompleted): "लक्ष्य पूरा"
    case (.chineseSimplified, .goalCompleted): "目标已完成"
    case (.korean, .goalCompleted): "목표 달성"
    case (.spanish, .goalCompleted): "Objetivo cumplido"
    case (.italian, .goalCompleted): "Obiettivo completato"
    case (.german, .goalCompleted): "Ziel erreicht"
    }
  }

  public var smallFamily: String {
    switch language {
    case .french: "Petit"
    case .english: "Small"
    case .hindi: "छोटा"
    case .chineseSimplified: "小号"
    case .korean: "소형"
    case .spanish: "Pequeño"
    case .italian: "Piccolo"
    case .german: "Klein"
    }
  }

  public var mediumFamily: String {
    switch language {
    case .french: "Moyen"
    case .english: "Medium"
    case .hindi: "मध्यम"
    case .chineseSimplified: "中号"
    case .korean: "중형"
    case .spanish: "Mediano"
    case .italian: "Medio"
    case .german: "Mittel"
    }
  }

  public var circularFamily: String {
    switch language {
    case .french: "Circulaire"
    case .english: "Circular"
    case .hindi: "गोल"
    case .chineseSimplified: "圆形"
    case .korean: "원형"
    case .spanish: "Circular"
    case .italian: "Circolare"
    case .german: "Rund"
    }
  }

  public var rectangularFamily: String {
    switch language {
    case .french: "Rectangulaire"
    case .english: "Rectangular"
    case .hindi: "आयताकार"
    case .chineseSimplified: "矩形"
    case .korean: "직사각형"
    case .spanish: "Rectangular"
    case .italian: "Rettangolare"
    case .german: "Rechteckig"
    }
  }
}
