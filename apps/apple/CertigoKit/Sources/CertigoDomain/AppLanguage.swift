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
    case learn, coach, social, profile, myLearning, explore, friends, teams
    case appLanguage, systemDefault, contentLanguageNote
    case signInWithMicrosoft, exploreDemo, resume, startSession, practiceAgain
    case submitAnswer, retry, loading
    case progressAndHistory, settings, accountDeletion, pending, confirmed
    case signOut, cancel, done, back, continueLearning, answer, next, previous
    case offline, pendingCorrection, noHistory, deleteAccount, demo, chooseGoal
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
    }
  }
}
