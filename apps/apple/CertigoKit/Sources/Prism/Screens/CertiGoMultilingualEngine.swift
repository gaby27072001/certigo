import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Unified Multilingual Enumeration (`CertiGoSupportedLanguage` · 12 Modes & 8 Canonical `AppLanguage` Parity)

public enum CertiGoSupportedLanguage: Int, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case frBilingual = 0
    case frFull = 1
    case en = 2
    case es = 3
    case de = 4
    case it = 5
    case pt = 6
    case ar = 7
    case ja = 8
    case hi = 9
    case zhHans = 10
    case ko = 11

    public var id: Int { rawValue }

    public var code: String {
        switch self {
        case .frBilingual: return "fr"
        case .frFull: return "fr-FR"
        case .en: return "en"
        case .es: return "es"
        case .de: return "de"
        case .it: return "it"
        case .pt: return "pt"
        case .ar: return "ar"
        case .ja: return "ja"
        case .hi: return "hi"
        case .zhHans: return "zh-Hans"
        case .ko: return "ko"
        }
    }

    public var flagEmoji: String {
        switch self {
        case .frBilingual, .frFull: return "🇫🇷"
        case .en: return "🇺🇸"
        case .es: return "🇪🇸"
        case .de: return "🇩🇪"
        case .it: return "🇮🇹"
        case .pt: return "🇵🇹"
        case .ar: return "🇸🇦"
        case .ja: return "🇯🇵"
        case .hi: return "🇮🇳"
        case .zhHans: return "🇨🇳"
        case .ko: return "🇰🇷"
        }
    }

    public var nativeDisplayName: String {
        switch self {
        case .frBilingual: return "FR + Termes EN"
        case .frFull: return "Français intégral"
        case .en: return "English (US)"
        case .es: return "Español"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .ar: return "العربية"
        case .ja: return "日本語"
        case .hi: return "हिन्दी"
        case .zhHans: return "简体中文"
        case .ko: return "한국어"
        }
    }

    public var pickerLabel: String {
        "\(nativeDisplayName)  ›"
    }

    public var compactPillLabel: String {
        "\(flagEmoji) \(nativeDisplayName)"
    }

    public var isFrenchVariant: Bool {
        self == .frBilingual || self == .frFull
    }

    public var mappedAppLanguage: AppLanguage {
        switch self {
        case .frBilingual, .frFull: return .french
        case .en, .ar, .ja: return .english
        case .es, .pt: return .spanish
        case .de: return .german
        case .it: return .italian
        case .hi: return .hindi
        case .zhHans: return .chineseSimplified
        case .ko: return .korean
        }
    }

    public init(settingsLanguageIndex: Int) {
        let count = Self.allCases.count
        let normalized = ((settingsLanguageIndex % count) + count) % count
        self = Self(rawValue: normalized) ?? .frBilingual
    }

    public init(appLanguage: AppLanguage) {
        switch appLanguage {
        case .french: self = .frBilingual
        case .english: self = .en
        case .spanish: self = .es
        case .german: self = .de
        case .italian: self = .it
        case .hindi: self = .hi
        case .chineseSimplified: self = .zhHans
        case .korean: self = .ko
        }
    }
}

extension String {
    /// Removes all Markdown bold/italic asterisks (`****`, `***`, `**`, `*mot*`), double underscores (`__`), backticks, and long dashes (`\u{2014}` / `\u{2013}`) so raw Markdown never appears in SwiftUI `Text`.
    public var strippingMarkdownAsterisks: String {
        var cleaned = self
            .replacingOccurrences(of: " \u{2014} ", with: " : ")
            .replacingOccurrences(of: " \u{2013} ", with: " - ")
            .replacingOccurrences(of: "\u{2014}", with: " : ")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "****", with: "")
            .replacingOccurrences(of: "***", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
        if cleaned.contains("*"),
           let regex = try? NSRegularExpression(pattern: #"(?<![/\.\w\[\*])\*([A-Za-zÀ-ÿ0-9][^\*\n]{0,90}[A-Za-zÀ-ÿ0-9\)])\*(?![/\.\w\]\*])"#)
        {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "$1")
        }
        return cleaned
    }

    private static let frenchFondEtFormeRegexRules: [(regex: NSRegularExpression, template: String)] = {
        let patterns: [(String, String)] = [
            (#"(?<![\p{L}\p{N}_])([Dd])e\s+([AEIOUÉÈÊËÀÂÎÏÔÙÛÜaeiouéèêëàâîïôùûü][A-Za-zÀ-ÿ0-9_-]*)"#, "$1'$2"),
            (#"(?<![\p{L}\p{N}_])([Dd])e\s+([Hh](?:éberg|istori|yper|orizont|ybrid|eur|ôt|umain|abitud|abilit)[A-Za-zÀ-ÿ0-9_-]*)"#, "$1'$2"),
            (#"(?<![\p{L}\p{N}_])([Ll])[ea]\s+((?:API|IAM|IA|AKS|EKS|EC2|accès|ajout|achat|activation|identité|architecture|exécution|entreprise|équipe|étape|examen|unité|option|opération|environnement|organisation|utilisateur|outil|erreur|incident|alerte|audit|isolation|automatisation|authentification|autorisation|entraînement|échantillonnage|arrêt|appareil|analyse|approbation|archivage|équilibre|équilibreur|Équilibreur|Identité)[A-Za-zÀ-ÿ0-9_-]*)"#, "$1'$2"),
            (#"(?<![\p{L}\p{N}_])([Qq])ue\s+(il|elle|on|ils|elles|un|une)(?![\p{L}\p{N}_])"#, "$1u'$2"),
            (#"(?<!\.)\.\.(?!\.|<)"#, ".")
        ]
        return patterns.compactMap { pat, tpl in
            guard let rx = try? NSRegularExpression(pattern: pat, options: []) else { return nil }
            return (regex: rx, template: tpl)
        }
    }()

    /// Normalizes French elisions (`de Azure` ➔ `d'Azure`, `de OpenAI` ➔ `d'OpenAI`, `de Anthropic` ➔ `d'Anthropic`, `de IAM` ➔ `d'IAM`, `de IA` ➔ `d'IA`, `de API` ➔ `d'API`, `de identité` ➔ `d'identité`, `de architecture` ➔ `d'architecture`, `de exécution` ➔ `d'exécution`, `de accès` ➔ `d'accès`, `de entreprise` ➔ `d'entreprise`, `le API` / `un API` ➔ `l'API` / `une API`), fixes double punctuation (`..`, `: :`, `?.`, `, .`), and strips Markdown asterisks and long dashes.
    public var sanitizingFrenchFondEtForme: String {
        var out = self.strippingMarkdownAsterisks
            .replacingOccurrences(of: "qu'quelqu'un", with: "que quelqu'un")
            .replacingOccurrences(of: "Qu'quelqu'un", with: "Que quelqu'un")
            .replacingOccurrences(of: "le API", with: "l'API")
            .replacingOccurrences(of: "Le API", with: "L'API")
            .replacingOccurrences(of: "un API", with: "une API")
            .replacingOccurrences(of: "Un API", with: "Une API")
            .replacingOccurrences(of: "du API", with: "de l'API")
            .replacingOccurrences(of: "Du API", with: "De l'API")
            .replacingOccurrences(of: ": :", with: ":")
            .replacingOccurrences(of: "?.", with: "?")
            .replacingOccurrences(of: ", .", with: ".")
            .replacingOccurrences(of: ",.", with: ".")

        for rule in Self.frenchFondEtFormeRegexRules {
            let range = NSRange(out.startIndex..<out.endIndex, in: out)
            out = rule.regex.stringByReplacingMatches(in: out, options: [], range: range, withTemplate: rule.template)
        }
        return out
    }
}

// MARK: - 2. 100% Coverage Dynamic Localization Engine (`CertiGoMultilingualEngine`)

public enum CertiGoMultilingualEngine {

    /// Full 12-option settings & onboarding language list (preserving indices 0, 1, 2 for existing tests).
    public static let allLanguageOptionLabels: [String] = CertiGoSupportedLanguage.allCases.map(\.pickerLabel)

    public static func resolveLanguage(forIndex langIndex: Int) -> CertiGoSupportedLanguage {
        CertiGoSupportedLanguage(settingsLanguageIndex: langIndex)
    }

    public static func resolveAppLanguage(forIndex langIndex: Int) -> AppLanguage {
        resolveLanguage(forIndex: langIndex).mappedAppLanguage
    }

    /// Strips any em-dash (`\u{2014}`), en-dash (`\u{2013}`), or Markdown asterisks (`**` / `****`) from localized copy.
    public static func sanitizeNoLongDashes(_ raw: String) -> String {
        raw.strippingMarkdownAsterisks
    }

    /// Primary dynamic translator `tr(_ fr: String, lang: Int) -> String` covering 100% of UI strings, unit/step titles, micro-slides, Cartes Déclic, questions, choices, explanations, and mock exams.
    public static func tr(_ fr: String, lang: Int) -> String {
        tr(fr, language: resolveLanguage(forIndex: lang))
    }

    public static func tr(_ fr: String, language: CertiGoSupportedLanguage) -> String {
        let cleanFr = sanitizeNoLongDashes(fr)
        guard !cleanFr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return cleanFr
        }

        // Mode 0: Standard French with English technical Cloud/AI terms ( sanitized of long dashes )
        if language == .frBilingual {
            return cleanFr.sanitizingFrenchFondEtForme
        }

        // Mode 1: Integral French (translates English technical terms into official French terminology)
        if language == .frFull {
            if let exact = exactTranslation(for: cleanFr, language: .frFull) {
                return sanitizeNoLongDashes(exact).sanitizingFrenchFondEtForme
            }
            return sanitizeNoLongDashes(applyIntegralFrenchTerminology(cleanFr)).sanitizingFrenchFondEtForme
        }

        // Modes 2..11: Non-French languages (`en`, `es`, `de`, `it`, `pt`, `ar`, `ja`, `hi`, `zh-Hans`, `ko`)
        if let exact = exactTranslation(for: cleanFr, language: language) {
            return sanitizeNoLongDashes(exact)
        }

        if let parameterized = translateParameterizedPattern(cleanFr, language: language) {
            return sanitizeNoLongDashes(parameterized)
        }

        // Handle multi-line text line-by-line while preserving newline structure
        if cleanFr.contains("\n") {
            let lines = cleanFr.components(separatedBy: "\n")
            let translatedLines = lines.map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return line }
                if let exactLine = exactTranslation(for: trimmed, language: language) {
                    return exactLine
                }
                if let paramLine = translateParameterizedPattern(trimmed, language: language) {
                    return paramLine
                }
                return translateCompositionalText(trimmed, language: language)
            }
            return sanitizeNoLongDashes(translatedLines.joined(separator: "\n"))
        }

        return sanitizeNoLongDashes(translateCompositionalText(cleanFr, language: language))
    }

    // MARK: - 3. Exact UI & Screen Catalog (`exactUITable`)

    private struct MultiLangEntry: Sendable {
        let frFull: String?
        let en: String
        let es: String
        let de: String
        let it: String
        let pt: String
        let ar: String
        let ja: String
        let hi: String
        let zhHans: String
        let ko: String

        init(
            frFull: String? = nil,
            en: String,
            es: String,
            de: String,
            it: String,
            pt: String? = nil,
            ar: String? = nil,
            ja: String? = nil,
            hi: String? = nil,
            zhHans: String? = nil,
            ko: String? = nil
        ) {
            self.frFull = frFull
            self.en = en
            self.es = es
            self.de = de
            self.it = it
            self.pt = pt ?? es
            self.ar = ar ?? en
            self.ja = ja ?? en
            self.hi = hi ?? en
            self.zhHans = zhHans ?? en
            self.ko = ko ?? en
        }

        func value(for language: CertiGoSupportedLanguage, defaultFr: String) -> String {
            switch language {
            case .frBilingual: return defaultFr
            case .frFull: return frFull ?? defaultFr
            case .en: return en
            case .es: return es
            case .de: return de
            case .it: return it
            case .pt: return pt
            case .ar: return ar
            case .ja: return ja
            case .hi: return hi
            case .zhHans: return zhHans
            case .ko: return ko
            }
        }
    }

    private static func exactTranslation(for key: String, language: CertiGoSupportedLanguage) -> String? {
        guard let entry = exactCatalog[key] else { return nil }
        return entry.value(for: language, defaultFr: key)
    }

    private static let exactCatalog: [String: MultiLangEntry] = [
        // 1. Bottom Navigation Bar Tabs
        "Parcours": .init(
            en: "Path", es: "Ruta", de: "Pfad", it: "Percorso", pt: "Percurso",
            ar: "المسار", ja: "コース", hi: "पथ", zhHans: "路径", ko: "학습 경로"
        ),
        "Actus": .init(
            en: "News", es: "Noticias", de: "Aktuelles", it: "Notizie", pt: "Notícias",
            ar: "الأخبار", ja: "ニュース", hi: "समाचार", zhHans: "资讯", ko: "뉴스"
        ),
        "Examens": .init(
            en: "Exams", es: "Exámenes", de: "Prüfungen", it: "Esami", pt: "Exames",
            ar: "الاختبارات", ja: "模擬試験", hi: "परीक्षाएं", zhHans: "模拟考试", ko: "모의고사"
        ),
        "✦ IA": .init(
            en: "✦ AI", es: "✦ IA", de: "✦ KI", it: "✦ IA", pt: "✦ IA",
            ar: "✦ الذكاء", ja: "✦ AI", hi: "✦ एआई", zhHans: "✦ AI", ko: "✦ AI"
        ),
        "Social": .init(
            en: "Social", es: "Social", de: "Sozial", it: "Social", pt: "Social",
            ar: "المجتمع", ja: "ソーシャル", hi: "सोशल", zhHans: "社区", ko: "소셜"
        ),
        "Moi": .init(
            en: "Me", es: "Perfil", de: "Profil", it: "Profilo", pt: "Perfil",
            ar: "حسابي", ja: "マイページ", hi: "प्रोफ़ाइल", zhHans: "我的", ko: "내 정보"
        ),

        // 2. Onboarding Step 0 (OB-01) & Auth Portal
        "Décroche tes certifications.\nMaîtrise l'IA & la Tech en continu.": .init(
            en: "Earn your certifications.\nMaster AI & Tech continuously.",
            es: "Consigue tus certificaciones.\nDomina la IA y la tecnología de forma continua.",
            de: "Bestehe deine Zertifizierungen.\nMeistere KI & Tech kontinuierlich.",
            it: "Ottieni le tue certificazioni.\nPadroneggia IA e Tech con continuità.",
            pt: "Conquiste suas certificações.\nDomine IA e Tecnologia continuamente.",
            ar: "احصل على شهاداتك المعتمدة.\nأتقن الذكاء الاصطناعي والتقنية باستمرار.",
            ja: "認定資格を取得しよう。\nAIと最新テックを継続的にマスター。",
            hi: "अपने प्रमाणपत्र प्राप्त करें।\nएआई और टेक में निरंतर महारत हासिल करें।",
            zhHans: "轻松考取权威认证。\n持续掌握 AI 与前沿科技。",
            ko: "자격증을 취득하세요.\nAI와 최신 기술을 꾸준히 마스터하세요."
        ),
        "Suis plusieurs parcours en parallèle : certifications officielles, acteurs majeurs de l'IA et nouveautés Tech ajoutées chaque semaine.": .init(
            en: "Follow multiple tracks in parallel: official certifications, leading AI platforms, and weekly Tech updates.",
            es: "Sigue varias rutas en paralelo: certificaciones oficiales, actores clave de IA y novedades tecnológicas semanales.",
            de: "Verfolge mehrere Pfade parallel: offizielle Zertifizierungen, führende KI-Plattformen und wöchentliche Tech-Updates.",
            it: "Segui più percorsi in parallelo: certificazioni ufficiali, protagonisti dell'IA e novità Tech ogni settimana.",
            pt: "Siga várias trilhas em paralelo: certificações oficiais, líderes em IA e novidades Tech toda semana.",
            ar: "تابع عدة مسارات بالتوازي: الشهادات الرسمية، قادة الذكاء الاصطناعي، والتحديثات التقنية الأسبوعية.",
            ja: "複数のコースを並行学習：公式認定資格、主要AIモデル、毎週追加される最新テック。",
            hi: "समानांतर में कई ट्रैक फॉलो करें: आधिकारिक प्रमाणपत्र, प्रमुख एआई प्लेटफॉर्म और साप्ताहिक टेक अपडेट।",
            zhHans: "并行学习多条路径：官方认证、主流 AI 平台以及每周更新的前沿科技。",
            ko: "공식 자격증, 주요 AI 플랫폼, 매주 추가되는 최신 기술까지 여러 트랙을 동시에 학습하세요."
        ),
        "Multi-Parcours": .init(
            en: "Multi-Track", es: "Multi-Ruta", de: "Multi-Pfad", it: "Multi-Percorso", pt: "Multi-Trilha",
            ar: "متعدد المسارات", ja: "マルチコース", hi: "मल्टी-ट्रैक", zhHans: "多路径并行", ko: "멀티 트랙"
        ),
        "En parallèle": .init(
            en: "In parallel", es: "En paralelo", de: "Parallel", it: "In parallelo", pt: "Em paralelo",
            ar: "بالتوازي", ja: "同時進行", hi: "समानांतर", zhHans: "同时推进", ko: "동시 진행"
        ),
        "Certifs + IA": .init(
            en: "Certs + AI", es: "Certs + IA", de: "Zert. + KI", it: "Cert. + IA", pt: "Certs + IA",
            ar: "شهادات + ذكاء", ja: "資格 + AI", hi: "सर्ट + एआई", zhHans: "认证 + AI", ko: "자격증 + AI"
        ),
        "Veille & Acteurs": .init(
            en: "Radar & Leaders", es: "Radar y Actores", de: "Radar & Akteure", it: "Radar e Attori", pt: "Radar e Líderes",
            ar: "المتابعة والرواد", ja: "最新動向", hi: "राडार और लीडर्स", zhHans: "前沿与生态", ko: "트렌드 및 리더"
        ),
        "Nouveautés 🔄": .init(
            en: "Updates 🔄", es: "Novedades 🔄", de: "Neuheiten 🔄", it: "Novità 🔄", pt: "Novidades 🔄",
            ar: "تحديثات 🔄", ja: "最新情報 🔄", hi: "अपडेट 🔄", zhHans: "每周更新 🔄", ko: "업데이트 🔄"
        ),
        "Chaque semaine": .init(
            en: "Every week", es: "Cada semana", de: "Jede Woche", it: "Ogni settimana", pt: "Toda semana",
            ar: "كل أسبوع", ja: "毎週追加", hi: "हर सप्ताह", zhHans: "每周上新", ko: "매주 추가"
        ),
        "CRÉER MON COMPTE · C'EST PARTI !": .init(
            en: "CREATE MY ACCOUNT · LET'S GO!",
            es: "CREAR MI CUENTA · ¡EMPECEMOS!",
            de: "KONTO ERSTELLEN · LOS GEHT'S!",
            it: "CREA IL MIO ACCOUNT · INIZIAMO!",
            pt: "CRIAR MINHA CONTA · VAMOS LÁ!",
            ar: "إنشاء حسابي · لنبدأ الآن!",
            ja: "アカウントを作成して始める！",
            hi: "मेरा खाता बनाएं · चलिए शुरू करें!",
            zhHans: "创建账户 · 立即开始！",
            ko: "계정 만들기 · 지금 시작하기!"
        ),
        "J'ai déjà un compte · Se connecter": .init(
            en: "I already have an account · Sign in",
            es: "Ya tengo una cuenta · Iniciar sesión",
            de: "Ich habe bereits ein Konto · Anmelden",
            it: "Ho già un account · Accedi",
            pt: "Já tenho uma conta · Entrar",
            ar: "لدي حساب بالفعل · تسجيل الدخول",
            ja: "すでにアカウントをお持ちの方 · ログイン",
            hi: "मेरा पहले से खाता है · साइन इन करें",
            zhHans: "已有账户 · 立即登录",
            ko: "이미 계정이 있으신가요 · 로그인"
        ),
        "🔑 PORTAIL DE CONNEXION CERTIGO": .init(
            en: "🔑 CERTIGO SIGN-IN PORTAL",
            es: "🔑 PORTAL DE ACCESO CERTIGO",
            de: "🔑 CERTIGO ANMELDEPORTAL",
            it: "🔑 PORTALE DI ACCESSO CERTIGO",
            pt: "🔑 PORTAL DE LOGIN CERTIGO",
            ar: "🔑 بوابة تسجيل الدخول CERTIGO",
            ja: "🔑 CERTIGO ログインポータル",
            hi: "🔑 CERTIGO साइन-इन पोर्टल",
            zhHans: "🔑 CERTIGO 登录门户",
            ko: "🔑 CERTIGO 로그인 포털"
        ),
        "Continuer avec Apple": .init(
            en: "Continue with Apple", es: "Continuar con Apple", de: "Weiter mit Apple", it: "Continua con Apple", pt: "Continuar com a Apple",
            ar: "المتابعة باستخدام Apple", ja: "Appleで続ける", hi: "Apple के साथ जारी रखें", zhHans: "通过 Apple 继续", ko: "Apple로 계속하기"
        ),
        "Continuer avec Google": .init(
            en: "Continue with Google", es: "Continuar con Google", de: "Weiter mit Google", it: "Continua con Google", pt: "Continuar com o Google",
            ar: "المتابعة باستخدام Google", ja: "Googleで続ける", hi: "Google के साथ जारी रखें", zhHans: "通过 Google 继续", ko: "Google로 계속하기"
        ),
        "Continuer avec Microsoft": .init(
            en: "Continue with Microsoft", es: "Continuar con Microsoft", de: "Weiter mit Microsoft", it: "Continua con Microsoft", pt: "Continuar com a Microsoft",
            ar: "المتابعة باستخدام Microsoft", ja: "Microsoftで続ける", hi: "Microsoft के साथ जारी रखें", zhHans: "通过 Microsoft 继续", ko: "Microsoft로 계속하기"
        ),
        "Continuer avec une adresse e-mail": .init(
            en: "Continue with email", es: "Continuar con correo electrónico", de: "Weiter mit E-Mail-Adresse", it: "Continua con un indirizzo e-mail", pt: "Continuar com e-mail",
            ar: "المتابعة بالبريد الإلكتروني", ja: "メールアドレスで続ける", hi: "ईमेल पते के साथ जारी रखें", zhHans: "使用电子邮箱继续", ko: "이메일 주소로 계속하기"
        ),
        "Continuer avec mon adresse e-mail": .init(
            en: "Continue with my email address", es: "Continuar con mi correo electrónico", de: "Mit meiner E-Mail-Adresse fortfahren", it: "Continua con il mio indirizzo e-mail", pt: "Continuar com meu e-mail",
            ar: "المتابعة ببريدي الإلكتروني", ja: "メールアドレスで登録・ログイン", hi: "मेरे ईमेल पते के साथ जारी रखें", zhHans: "使用我的电子邮箱继续", ko: "내 이메일 주소로 계속하기"
        ),
        "Continuer sans compte pour l'instant →": .init(
            en: "Continue without an account for now →", es: "Continuar sin cuenta por ahora →", de: "Vorerst ohne Konto fortfahren →", it: "Continua senza account per ora →", pt: "Continuar sem conta por enquanto →",
            ar: "المتابعة بدون حساب حالياً ←", ja: "今はアカウントなしで続ける →", hi: "अभी बिना खाते के जारी रखें →", zhHans: "暂时免登录继续 →", ko: "지금은 계정 없이 계속하기 →"
        ),
        "Continuer vers mon parcours →": .init(
            en: "Continue to my learning path →", es: "Continuar a mi ruta →", de: "Weiter zu meinem Lernpfad →", it: "Continua verso il mio percorso →", pt: "Continuar para minha trilha →",
            ar: "المتابعة إلى مسار التعلم ←", ja: "学習コースへ進む →", hi: "मेरे लर्निंग पथ पर आगे बढ़ें →", zhHans: "前往我的学习路径 →", ko: "내 학습 경로로 이동 →"
        ),
        "Créer mon compte": .init(
            en: "Create account", es: "Crear cuenta", de: "Konto erstellen", it: "Crea account", pt: "Criar conta",
            ar: "إنشاء حساب", ja: "アカウント作成", hi: "खाता बनाएं", zhHans: "创建账户", ko: "계정 만들기"
        ),
        "J'ai déjà un compte": .init(
            en: "Sign in", es: "Ya tengo cuenta", de: "Anmelden", it: "Ho già un account", pt: "Já tenho conta",
            ar: "لدي حساب", ja: "ログイン", hi: "साइन इन", zhHans: "已有账户", ko: "로그인"
        ),
        "Prénom & Nom": .init(
            en: "Full Name", es: "Nombre y Apellido", de: "Vor- & Nachname", it: "Nome e Cognome", pt: "Nome e Sobrenome",
            ar: "الاسم الكامل", ja: "氏名", hi: "पूरा नाम", zhHans: "姓名", ko: "이름 및 성"
        ),
        "Ton prénom et nom": .init(
            en: "Your full name", es: "Tu nombre y apellido", de: "Dein Vor- und Nachname", it: "Il tuo nome e cognome", pt: "Seu nome completo",
            ar: "اسمك الكامل", ja: "氏名を入力", hi: "आपका पूरा नाम", zhHans: "输入您的姓名", ko: "이름 입력"
        ),
        "Adresse e-mail": .init(
            en: "Email address", es: "Correo electrónico", de: "E-Mail-Adresse", it: "Indirizzo e-mail", pt: "Endereço de e-mail",
            ar: "البريد الإلكتروني", ja: "メールアドレス", hi: "ईमेल पता", zhHans: "电子邮箱", ko: "이메일 주소"
        ),
        "Adresse Gmail / Google Workspace": .init(
            en: "Gmail / Google Workspace address", es: "Correo Gmail / Google Workspace", de: "Gmail / Google Workspace-Adresse", it: "Indirizzo Gmail / Google Workspace", pt: "E-mail Gmail / Google Workspace",
            ar: "عنوان Gmail / Google Workspace", ja: "Gmail / Google Workspace アドレス", hi: "Gmail / Google Workspace पता", zhHans: "Gmail / Google Workspace 邮箱", ko: "Gmail / Google Workspace 주소"
        ),
        "Mot de passe (8 caractères minimum)": .init(
            en: "Password (8 characters minimum)", es: "Contraseña (mínimo 8 caracteres)", de: "Passwort (mindestens 8 Zeichen)", it: "Password (minimo 8 caratteri)", pt: "Senha (mínimo de 8 caracteres)",
            ar: "كلمة المرور (8 أحرف على الأقل)", ja: "パスワード（8文字以上）", hi: "पासवर्ड (न्यूनतम 8 अक्षर)", zhHans: "密码（至少 8 个字符）", ko: "비밀번호 (최소 8자 이상)"
        ),
        "Valider & Continuer": .init(
            en: "Confirm & Continue", es: "Validar y Continuar", de: "Bestätigen & Weiter", it: "Conferma e Continua", pt: "Confirmar e Continuar",
            ar: "تأكيد ومتابعة", ja: "確認して続ける", hi: "पुष्टि करें और जारी रखें", zhHans: "确认并继续", ko: "확인 및 계속하기"
        ),
        "Connexion en cours...": .init(
            en: "Signing in...", es: "Conectando...", de: "Anmeldung läuft...", it: "Accesso in corso...", pt: "Conectando...",
            ar: "جاري تسجيل الدخول...", ja: "サインイン中...", hi: "साइन इन हो रहा है...", zhHans: "正在登录...", ko: "로그인 중..."
        ),

        // 3. Onboarding Steps 1..9
        "Qu'est-ce qui t'amène sur CertiGo ?": .init(
            en: "What brings you to CertiGo?",
            es: "¿Qué te trae a CertiGo?",
            de: "Was führt dich zu CertiGo?",
            it: "Cosa ti porta su CertiGo?",
            pt: "O que traz você ao CertiGo?",
            ar: "ما هو هدفك الرئيسي في CertiGo؟",
            ja: "CertiGoを始める目的は何ですか？",
            hi: "आपको CertiGo पर क्या लाता है?",
            zhHans: "您使用 CertiGo 的主要目标是？",
            ko: "CertiGo를 시작하는 목적은 무엇인가요?"
        ),
        "Décrocher 1 ou plusieurs certifications": .init(
            en: "Earn 1 or more certifications", es: "Obtener 1 o más certificaciones", de: "1 oder mehrere Zertifizierungen bestehen", it: "Ottenere 1 o più certificazioni", pt: "Conquistar 1 ou mais certificações",
            ar: "الحصول على شهادة أو أكثر", ja: "1つ以上の認定資格を取得する", hi: "1 या अधिक प्रमाणपत्र प्राप्त करें", zhHans: "考取 1 项或多项官方认证", ko: "1개 이상의 공식 자격증 취득"
        ),
        "Microsoft, AWS, Google Cloud, GitHub ou Kubernetes": .init(
            en: "Microsoft, AWS, Google Cloud, GitHub or Kubernetes", es: "Microsoft, AWS, Google Cloud, GitHub o Kubernetes", de: "Microsoft, AWS, Google Cloud, GitHub oder Kubernetes", it: "Microsoft, AWS, Google Cloud, GitHub o Kubernetes", pt: "Microsoft, AWS, Google Cloud, GitHub ou Kubernetes"
        ),
        "Me tenir à jour sur l'IA & la Tech": .init(
            en: "Stay up to date on AI & Tech", es: "Mantenerme al día en IA y Tech", de: "Über KI & Tech auf dem Laufenden bleiben", it: "Restare aggiornato su IA e Tech", pt: "Manter-me atualizado em IA e Tech",
            ar: "مواكبة أحدث تطورات الذكاء الاصطناعي والتقنية", ja: "AIと最新テックの動向を常に把握する", hi: "एआई और टेक पर अपडेट रहें", zhHans: "持续跟进 AI 与前沿科技", ko: "AI 및 최신 기술 트렌드 파악"
        ),
        "Maîtriser les acteurs de l'IA (OpenAI, Claude, Foundry…)": .init(
            en: "Master leading AI platforms (OpenAI, Claude, Foundry...)", es: "Dominar los líderes de IA (OpenAI, Claude, Foundry...)", de: "KI-Plattformen meistern (OpenAI, Claude, Foundry...)", it: "Padroneggiare i leader IA (OpenAI, Claude, Foundry...)", pt: "Dominar os líderes de IA (OpenAI, Claude, Foundry...)",
            ar: "إتقان منصات الذكاء الاصطناعي (OpenAI وClaude وFoundry...)", ja: "主要AI基盤（OpenAI、Claude、Foundry等）を習得", hi: "प्रमुख एआई प्लेटफॉर्म (OpenAI, Claude, Foundry...) में महारत", zhHans: "掌握主流 AI 平台（OpenAI、Claude、Foundry 等）", ko: "주요 AI 플랫폼 (OpenAI, Claude, Foundry 등) 마스터"
        ),
        "Accélérer ma carrière & mes projets": .init(
            en: "Accelerate my career & projects", es: "Acelerar mi carrera y proyectos", de: "Meine Karriere & Projekte beschleunigen", it: "Accelerare la mia carriera e i progetti", pt: "Acelerar minha carreira e projetos",
            ar: "تسريع مسيرتي المهنية ومشاريعي", ja: "キャリアと実務プロジェクトを加速する", hi: "अपने करियर और प्रोजेक्ट्स को गति दें", zhHans: "加速职业发展与项目实战", ko: "커리어 및 실무 프로젝트 역량 강화"
        ),
        "Pratiquer sur des cas réels d'architecture & CLI": .init(
            en: "Practice on real-world architecture & CLI scenarios", es: "Practicar con casos reales de arquitectura y CLI", de: "An realen Architektur- & CLI-Szenarien üben", it: "Praticare su casi reali di architettura e CLI", pt: "Praticar em casos reais de arquitetura e CLI",
            ar: "التدرب على سيناريوهات معمارية وأوامر CLI واقعية", ja: "実践的なアーキテクチャ設計とCLI演習", hi: "वास्तविक आर्किटेक्चर और CLI परिदृश्यों का अभ्यास करें", zhHans: "通过真实架构场景与 CLI 命令进行实战练习", ko: "실전 아키텍처 및 CLI 시나리오 실습"
        ),
        "Valider des compétences en entreprise": .init(
            en: "Validate enterprise skills", es: "Validar competencias empresariales", de: "Unternehmenskompetenzen validieren", it: "Convalidare competenze aziendali", pt: "Validar competências corporativas",
            ar: "اعتماد المهارات المؤسسية", ja: "エンタープライズスキルの証明", hi: "एंटरप्राइज़ कौशल को प्रमाणित करें", zhHans: "验证企业级技术能力", ko: "기업 실무 역량 검증"
        ),
        "Maintenir mon équipe ou mon profil ESN au top niveau": .init(
            en: "Keep my engineering team or consulting profile at the top", es: "Mantener mi perfil o equipo al máximo nivel", de: "Mein Team oder Beraterprofil auf Top-Niveau halten", it: "Mantenere il mio team o profilo al massimo livello", pt: "Manter minha equipe ou perfil no mais alto nível",
            ar: "الحفاظ على جاهزية فريقي وملفي المهني بأعلى مستوى", ja: "チームや自身の技術プロフィールを最高水準に維持", hi: "अपनी टीम या कंसल्टिंग प्रोफ़ाइल को शीर्ष स्तर पर रखें", zhHans: "保持团队或个人技术档案处于顶尖水平", ko: "팀과 개인 기술 프로필을 최고 수준으로 유지"
        ),
        "Quelles certifications veux-tu suivre ?": .init(
            en: "Which certifications do you want to follow?",
            es: "¿Qué certificaciones quieres seguir?",
            de: "Welche Zertifizierungen möchtest du verfolgen?",
            it: "Quali certificazioni vuoi seguire?",
            pt: "Quais certificações você quer seguir?",
            ar: "ما هي الشهادات التي ترغب في متابعتها؟",
            ja: "どの認定資格コースを学習しますか？",
            hi: "आप कौन से प्रमाणपत्र लेना चाहते हैं?",
            zhHans: "您想学习哪些认证课程？",
            ko: "어떤 자격증 과정을 학습하시겠습니까?"
        ),
        "Tout": .init(
            en: "All", es: "Todo", de: "Alle", it: "Tutto", pt: "Tudo",
            ar: "الكل", ja: "すべて", hi: "सभी", zhHans: "全部", ko: "전체"
        ),
        "Sécurité": .init(
            en: "Security", es: "Seguridad", de: "Sicherheit", it: "Sicurezza", pt: "Segurança",
            ar: "الأمن", ja: "セキュリティ", hi: "सुरक्षा", zhHans: "安全", ko: "보안"
        ),
        "IA": .init(
            en: "AI", es: "IA", de: "KI", it: "IA", pt: "IA",
            ar: "الذكاء الاصطناعي", ja: "AI", hi: "एआई", zhHans: "AI", ko: "AI"
        ),
        "Reste à la pointe de l'IA": .init(
            en: "Stay at the forefront of AI",
            es: "Mantente a la vanguardia de la IA",
            de: "Bleib an der Spitze der KI",
            it: "Resta all'avanguardia dell'IA",
            pt: "Fique na vanguarda da IA",
            ar: "ابقَ في طليعة الذكاء الاصطناعي",
            ja: "AIの最前線をキャッチアップ",
            hi: "एआई में सबसे आगे रहें",
            zhHans: "紧跟 AI 最前沿",
            ko: "AI 최전선 트렌드 유지"
        ),
        "Modèles & Acteurs de l'IA": .init(
            en: "AI Models & Leaders", es: "Modelos y Actores de IA", de: "KI-Modelle & Akteure", it: "Modelli e Attori dell'IA", pt: "Modelos e Líderes de IA",
            ar: "نماذج ورواد الذكاء الاصطناعي", ja: "AIモデル＆主要プレイヤー", hi: "एआई मॉडल और लीडर्स", zhHans: "AI 大模型与核心厂商", ko: "AI 모델 및 주요 기업"
        ),
        "Agents IA & Outils Dev": .init(
            en: "AI Agents & Dev Tools", es: "Agentes IA y Herramientas Dev", de: "KI-Agenten & Dev-Tools", it: "Agenti IA e Strumenti Dev", pt: "Agentes de IA e Ferramentas Dev",
            ar: "وكلاء الذكاء الاصطناعي وأدوات المطورين", ja: "AIエージェント＆開発ツール", hi: "एआई एजेंट और डेव टूल्स", zhHans: "AI 智能体与开发者工具", ko: "AI 에이전트 및 개발 도구"
        ),
        "Nouveautés Cloud & Cyber": .init(
            en: "Cloud & Cyber Updates", es: "Novedades Cloud y Cyber", de: "Cloud- & Cyber-Neuheiten", it: "Novità Cloud e Cyber", pt: "Novidades Cloud e Cyber",
            ar: "مستجدات السحابة والأمن السيبراني", ja: "クラウド＆サイバー最新情報", hi: "क्लाउड और साइबर अपडेट", zhHans: "云计算与网络安全动态", ko: "클라우드 및 사이버 보안 소식"
        ),
        "L'essentiel des sorties AWS, Azure & GCP": .init(
            en: "Essential AWS, Azure & GCP releases", es: "Lo esencial de AWS, Azure y GCP", de: "Wichtige Releases von AWS, Azure & GCP", it: "L'essenziale delle novità AWS, Azure e GCP", pt: "O essencial dos lançamentos AWS, Azure e GCP",
            ar: "أهم إصدارات AWS وAzure وGCP", ja: "AWS・Azure・GCPの重要アップデート", hi: "AWS, Azure और GCP के प्रमुख अपडेट", zhHans: "AWS、Azure 与 GCP 核心发布精选", ko: "AWS, Azure, GCP 핵심 업데이트 요약"
        ),
        "Quel est ton niveau actuel ?": .init(
            en: "What is your current level?",
            es: "¿Cuál es tu nivel actual?",
            de: "Was ist dein aktuelles Niveau?",
            it: "Qual è il tuo livello attuale?",
            pt: "Qual é o seu nível atual?",
            ar: "ما هو مستواك الحالي؟",
            ja: "現在のスキルレベルを教えてください",
            hi: "आपका वर्तमान स्तर क्या है?",
            zhHans: "您目前的技术水平是？",
            ko: "현재 본인의 수준은 어느 정도인가요?"
        ),
        "Je débute sur le Cloud & l'IA": .init(
            en: "I'm new to Cloud & AI", es: "Empiezo en Cloud e IA", de: "Ich starte mit Cloud & KI", it: "Inizio ora con Cloud e IA", pt: "Estou começando em Cloud e IA",
            ar: "مبتدئ في السحابة والذكاء الاصطناعي", ja: "クラウドとAIの初心者", hi: "मैं क्लाउड और एआई में नया हूँ", zhHans: "云计算与 AI 初学者", ko: "클라우드 및 AI 입문자"
        ),
        "On part des bases visuelles étape par étape.": .init(
            en: "Start from visual fundamentals step by step.", es: "Partimos de las bases visuales paso a paso.", de: "Wir starten Schritt für Schritt mit visuellen Grundlagen.", it: "Partiamo dalle basi visive passo dopo passo.", pt: "Partimos das bases visuais passo a passo.",
            ar: "نبدأ من الأساسيات المرئية خطوة بخطوة.", ja: "図解で基礎からステップバイステップで学びます。", hi: "हम चरण-दर-चरण विज़ुअल बेसिक्स से शुरू करते हैं।", zhHans: "从可视化基础开始循序渐进。", ko: "시각적 기초부터 단계별로 시작합니다."
        ),
        "Intermédiaire (Recommandé)": .init(
            en: "Intermediate (Recommended)", es: "Intermedio (Recomendado)", de: "Mittelstufe (Empfohlen)", it: "Intermedio (Consigliato)", pt: "Intermediário (Recomendado)",
            ar: "متوسط (موصى به)", ja: "中級（おすすめ）", hi: "इंटरमीडिएट (अनुशंसित)", zhHans: "中级（推荐）", ko: "중급 (추천)"
        ),
        "Je connais déjà les bases et je veux pratiquer.": .init(
            en: "I know the basics and want hands-on practice.", es: "Ya conozco las bases y quiero practicar.", de: "Ich kenne die Grundlagen und möchte üben.", it: "Conosco già le basi e voglio fare pratica.", pt: "Já conheço o básico e quero praticar.",
            ar: "أعرف الأساسيات وأريد التدرب عملياً.", ja: "基礎を理解しており、実践問題で鍛えたい。", hi: "मुझे मूल बातें पता हैं और मैं अभ्यास करना चाहता हूँ।", zhHans: "已掌握基础，希望进行实战练习。", ko: "기초를 알고 있으며 실전 연습을 원합니다."
        ),
        "Avancé · Sprint & Examens": .init(
            en: "Advanced · Sprints & Mock Exams", es: "Avanzado · Sprints y Exámenes", de: "Fortgeschritten · Sprints & Prüfungen", it: "Avanzato · Sprint ed Esami", pt: "Avançado · Sprints e Exames",
            ar: "متقدم · تدريبات سريعة واختبارات", ja: "上級 · スプリント＆模擬試験", hi: "उन्नत · स्प्रिंट और परीक्षाएं", zhHans: "高级 · 冲刺与模拟考试", ko: "고급 · 스프린트 및 모의고사"
        ),
        "Débloque directement les cas complexes et labs CLI.": .init(
            en: "Unlock complex scenarios and CLI labs right away.", es: "Desbloquea directamente casos complejos y labs CLI.", de: "Schalte komplexe Fälle und CLI-Labs direkt frei.", it: "Sblocca subito casi complessi e lab CLI.", pt: "Desbloqueie diretamente casos complexos e labs CLI.",
            ar: "افتح الحالات المعقدة ومختبرات CLI مباشرة.", ja: "高度な設計ケースとCLIラボをすぐに解放します。", hi: "जटिल मामलों और CLI लैब्स को सीधे अनलॉक करें।", zhHans: "直接解锁复杂架构案例与 CLI 实验。", ko: "복잡한 시나리오와 CLI 실습을 바로 잠금 해제합니다."
        ),
        "Quand vises-tu ta 1re certification ?": .init(
            en: "When do you aim to pass your 1st certification?",
            es: "¿Cuándo planeas obtener tu 1.ª certificación?",
            de: "Wann strebst du deine 1. Zertifizierung an?",
            it: "Quando punti alla tua 1ª certificazione?",
            pt: "Quando você pretende tirar sua 1ª certificação?",
            ar: "متى تهدف للحصول على شهادتك الأولى؟",
            ja: "最初の認定資格をいつまでに取得したいですか？",
            hi: "आप अपना पहला प्रमाणपत्र कब प्राप्त करना चाहते हैं?",
            zhHans: "您计划何时考取第一项认证？",
            ko: "첫 번째 자격증 취득 목표 시점은 언제인가요?"
        ),
        "Dans 30 jours": .init(
            en: "In 30 days", es: "En 30 días", de: "In 30 Tagen", it: "Tra 30 giorni", pt: "Em 30 dias",
            ar: "خلال 30 يوماً", ja: "30日以内", hi: "30 दिनों में", zhHans: "30 天内", ko: "30일 이내"
        ),
        "Sprint intensif": .init(
            en: "Intensive sprint", es: "Sprint intensivo", de: "Intensiver Sprint", it: "Sprint intensivo", pt: "Sprint intensivo",
            ar: "تدريب مكثف", ja: "短期集中スプリント", hi: "गहन स्प्रिंट", zhHans: "高强度冲刺", ko: "집중 스프린트"
        ),
        "Dans 6 semaines": .init(
            en: "In 6 weeks", es: "En 6 semanas", de: "In 6 Wochen", it: "Tra 6 settimane", pt: "Em 6 semanas",
            ar: "خلال 6 أسابيع", ja: "6週間以内", hi: "6 सप्ताह में", zhHans: "6 周内", ko: "6주 이내"
        ),
        "Idéal · Recommandé": .init(
            en: "Ideal · Recommended", es: "Ideal · Recomendado", de: "Ideal · Empfohlen", it: "Ideale · Consigliato", pt: "Ideal · Recomendado",
            ar: "مثالي · موصى به", ja: "最適 · おすすめ", hi: "आदर्श · अनुशंसित", zhHans: "理想节奏 · 推荐", ko: "이상적 · 추천"
        ),
        "Dans 3 mois": .init(
            en: "In 3 months", es: "En 3 meses", de: "In 3 Monaten", it: "Tra 3 mesi", pt: "Em 3 meses",
            ar: "خلال 3 أشهر", ja: "3ヶ月以内", hi: "3 महीने में", zhHans: "3 个月内", ko: "3개월 이내"
        ),
        "Rythme serein": .init(
            en: "Steady pace", es: "Ritmo sereno", de: "Entspanntes Tempo", it: "Ritmo sereno", pt: "Ritmo tranquilo",
            ar: "وتيرة هادئة", ja: "無理のないペース", hi: "सहज गति", zhHans: "稳健节奏", ko: "안정적인 페이스"
        ),
        "Veille continue": .init(
            en: "Continuous learning", es: "Aprendizaje continuo", de: "Kontinuierliches Lernen", it: "Formazione continua", pt: "Aprendizado contínuo",
            ar: "تعلم مستمر", ja: "継続的なスキルアップ", hi: "निरंतर सीखना", zhHans: "持续充电", ko: "지속적인 학습"
        ),
        "Sans date fixe": .init(
            en: "No fixed date", es: "Sin fecha fija", de: "Ohne festes Datum", it: "Senza data fissa", pt: "Sem data fixa",
            ar: "بدون تاريخ محدد", ja: "期限なし", hi: "कोई निश्चित तिथि नहीं", zhHans: "无固定期限", ko: "기한 없음"
        ),
        "Choisis ton objectif quotidien": .init(
            en: "Choose your daily goal", es: "Elige tu objetivo diario", de: "Wähle dein Tagesziel", it: "Scegli il tuo obiettivo giornaliero", pt: "Escolha sua meta diária",
            ar: "اختر هدفك اليومي", ja: "1日の学習目標を選択", hi: "अपना दैनिक लक्ष्य चुनें", zhHans: "选择您的每日学习目标", ko: "일일 학습 목표 선택"
        ),
        "Départ léger": .init(
            en: "Light start", es: "Inicio ligero", de: "Leichter Start", it: "Partenza leggera", pt: "Início leve",
            ar: "بداية خفيفة", ja: "気軽なスタート", hi: "हल्की शुरुआत", zhHans: "轻松起步", ko: "가벼운 시작"
        ),
        "🌱 Doux": .init(
            en: "🌱 Gentle", es: "🌱 Suave", de: "🌱 Sanft", it: "🌱 Dolce", pt: "🌱 Leve",
            ar: "🌱 هادئ", ja: "🌱 ライト", hi: "🌱 सहज", zhHans: "🌱 轻松", ko: "🌱 가벼움"
        ),
        "Rythme idéal": .init(
            en: "Ideal pace", es: "Ritmo ideal", de: "Ideales Tempo", it: "Ritmo ideale", pt: "Ritmo ideal",
            ar: "الوتيرة المثالية", ja: "理想的なペース", hi: "आदर्श गति", zhHans: "理想节奏", ko: "이상적인 페이스"
        ),
        "⭐ Recommandé": .init(
            en: "⭐ Recommended", es: "⭐ Recomendado", de: "⭐ Empfohlen", it: "⭐ Consigliato", pt: "⭐ Recomendado",
            ar: "⭐ موصى به", ja: "⭐ おすすめ", hi: "⭐ अनुशंसित", zhHans: "⭐ 推荐", ko: "⭐ 추천"
        ),
        "Progression accélérée": .init(
            en: "Fast progress", es: "Progreso acelerado", de: "Schneller Fortschritt", it: "Progressione rapida", pt: "Progresso acelerado",
            ar: "تقدم سريع", ja: "スピード習得", hi: "तेज़ प्रगति", zhHans: "加速进阶", ko: "빠른 성장"
        ),
        "🚀 Soutenu": .init(
            en: "🚀 Steady", es: "🚀 Sostenido", de: "🚀 Intensiv", it: "🚀 Sostenuto", pt: "🚀 Forte",
            ar: "🚀 متقدم", ja: "🚀 しっかり", hi: "🚀 तेज़", zhHans: "🚀 进阶", ko: "🚀 집중"
        ),
        "Préparation intensive": .init(
            en: "Intensive prep", es: "Preparación intensiva", de: "Intensive Vorbereitung", it: "Preparazione intensiva", pt: "Preparação intensiva",
            ar: "تحضير مكثف", ja: "短期集中対策", hi: "गहन तैयारी", zhHans: "高强度备考", ko: "집중 시험 대비"
        ),
        "🔥 Intensif": .init(
            en: "🔥 Intensive", es: "🔥 Intensivo", de: "🔥 Power", it: "🔥 Intensivo", pt: "🔥 Intensivo",
            ar: "🔥 مكثف", ja: "🔥 集中", hi: "🔥 गहन", zhHans: "🔥 冲刺", ko: "🔥 하드코어"
        ),
        "Quel est ton meilleur moment ?": .init(
            en: "When is your best time to practice?", es: "¿Cuál es tu mejor momento?", de: "Wann passt es dir am besten?", it: "Qual è il tuo momento migliore?", pt: "Qual é o seu melhor horário?",
            ar: "ما هو أفضل وقت لديك للتدرب؟", ja: "学習に最適な時間帯はいつですか？", hi: "अभ्यास के लिए आपका सबसे अच्छा समय कौन सा है?", zhHans: "您每天最适合学习的时间是？", ko: "학습하기 가장 좋은 시간대는 언제인가요?"
        ),
        "Le matin au réveil / après mon café": .init(
            en: "In the morning / after coffee", es: "Por la mañana / después del café", de: "Morgens nach dem Kaffee", it: "Al mattino / dopo il caffè", pt: "De manhã / após o café",
            ar: "في الصباح / بعد القهوة", ja: "朝起きてすぐ・コーヒーの後", hi: "सुबह उठकर / कॉफी के बाद", zhHans: "早晨醒来 / 喝完咖啡后", ko: "아침 기상 후 / 커피 한 잔 후"
        ),
        "À la pause déjeuner": .init(
            en: "During lunch break", es: "En la pausa del almuerzo", de: "In der Mittagspause", it: "In pausa pranzo", pt: "Na pausa do almoço",
            ar: "أثناء استراحة الغداء", ja: "ランチタイム・昼休み", hi: "लंच ब्रेक के दौरान", zhHans: "午休时间", ko: "점심시간"
        ),
        "En fin de journée / transports": .init(
            en: "Late afternoon / commute", es: "Al final del día / transporte", de: "Am Feierabend / unterwegs", it: "Fine giornata / sui mezzi", pt: "Fim do dia / transporte",
            ar: "نهاية اليوم / في المواصلات", ja: "夕方・通勤通学の移動中", hi: "शाम को / यात्रा के दौरान", zhHans: "傍晚下班 / 通勤途中", ko: "퇴근길 / 이동 중"
        ),
        "Le soir au calme": .init(
            en: "In the evening at home", es: "Por la noche con calma", de: "Abends in Ruhe", it: "La sera in tranquillità", pt: "À noite com calma",
            ar: "في المساء بهدوء", ja: "夜のリラックスタイム", hi: "रात को शांत समय में", zhHans: "夜晚安静时段", ko: "저녁 여유 시간"
        ),
        "🔔 Heure du rappel": .init(
            en: "🔔 Reminder time", es: "🔔 Hora del recordatorio", de: "🔔 Erinnerungszeit", it: "🔔 Ora del promemoria", pt: "🔔 Horário do lembrete",
            ar: "🔔 وقت التذكير", ja: "🔔 リマインダー時刻", hi: "🔔 रिमाइंडर का समय", zhHans: "🔔 提醒时间", ko: "🔔 알림 시간"
        ),
        "Continuer": .init(
            en: "Continue", es: "Continuar", de: "Weiter", it: "Continua", pt: "Continuar",
            ar: "متابعة", ja: "続ける", hi: "जारी रखें", zhHans: "继续", ko: "계속하기"
        ),
        "Plus tard": .init(
            en: "Later", es: "Más tarde", de: "Später", it: "Più tardi", pt: "Mais tarde",
            ar: "لاحقاً", ja: "あとで", hi: "बाद में", zhHans: "稍后", ko: "나중에"
        ),
        "Ajoute le Widget CertiGo sur ton iPhone": .init(
            en: "Add the CertiGo Widget to your iPhone", es: "Añade el Widget de CertiGo en tu iPhone", de: "Füge das CertiGo-Widget auf deinem iPhone hinzu", it: "Aggiungi il Widget CertiGo sul tuo iPhone", pt: "Adicione o Widget CertiGo no seu iPhone",
            ar: "أضف أداة CertiGo على شاشة iPhone", ja: "iPhoneのホーム画面にCertiGoウィジェットを追加", hi: "अपने iPhone पर CertiGo विजेट जोड़ें", zhHans: "在 iPhone 主屏幕添加 CertiGo 小组件", ko: "iPhone 홈 화면에 CertiGo 위젯 추가"
        ),
        "🔥 Série active · Jour 1": .init(
            en: "🔥 Active streak · Day 1", es: "🔥 Racha activa · Día 1", de: "🔥 Aktive Serie · Tag 1", it: "🔥 Serie attiva · Giorno 1", pt: "🔥 Ofensiva ativa · Dia 1",
            ar: "🔥 سلسلة نشطة · اليوم 1", ja: "🔥 連続学習 · 1日目", hi: "🔥 सक्रिय स्ट्रीक · दिन 1", zhHans: "🔥 连续打卡 · 第 1 天", ko: "🔥 연속 학습 · 1일차"
        ),
        "Série active · Jour 1": .init(
            en: "Active streak · Day 1", es: "Racha activa · Día 1", de: "Aktive Serie · Tag 1", it: "Serie attiva · Giorno 1", pt: "Ofensiva ativa · Dia 1",
            ar: "سلسلة نشطة · اليوم 1", ja: "連続学習 · 1日目", hi: "सक्रिय स्ट्रीक · दिन 1", zhHans: "连续打卡 · 第 1 天", ko: "연속 학습 · 1일차"
        ),
        "Appuie longuement sur ton écran d'accueil": .init(
            en: "Long-press on your Home Screen", es: "Mantén pulsada la pantalla de inicio", de: "Halte deinen Home-Bildschirm gedrückt", it: "Tieni premuto sulla schermata Home", pt: "Pressione e segure a Tela de Início",
            ar: "اضغط مطولاً على الشاشة الرئيسية", ja: "ホーム画面の何もない場所を長押し", hi: "अपनी होम स्क्रीन को देर तक दबाएं", zhHans: "长按 iPhone 主屏幕空白处", ko: "홈 화면의 빈 공간을 길게 누르세요"
        ),
        "Touche « Modifier » ou « + » en haut à gauche": .init(
            en: "Tap 'Edit' or '+' in the top-left corner", es: "Toca « Editar » o « + » arriba a la izquierda", de: "Tippe oben links auf „Bearbeiten“ oder „+“", it: "Tocca « Modifica » o « + » in alto a sinistra", pt: "Toque em 'Editar' ou '+' no canto superior esquerdo",
            ar: "اضغط على « تعديل » أو « + » أعلى اليمين/اليسار", ja: "左上の「編集」または「＋」をタップ", hi: "ऊपर बाईं ओर 'Edit' या '+' पर टैप करें", zhHans: "轻点左上角的“编辑”或“+”号", ko: "왼쪽 상단의 '편집' 또는 '+' 버튼을 탭하세요"
        ),
        "Cherche « CertiGo » et place ton widget": .init(
            en: "Search 'CertiGo' and place your widget", es: "Busca « CertiGo » y coloca tu widget", de: "Suche nach „CertiGo“ und platziere dein Widget", it: "Cerca « CertiGo » e posiziona il widget", pt: "Busque 'CertiGo' e adicione seu widget",
            ar: "ابحث عن « CertiGo » وأضف الأداة", ja: "「CertiGo」を検索してウィジェットを配置", hi: "'CertiGo' खोजें और अपना विजेट रखें", zhHans: "搜索“CertiGo”并放置小组件", ko: "'CertiGo'를 검색하여 위젯을 배치하세요"
        ),
        "Super, j'ai compris →": .init(
            en: "Got it, continue →", es: "Genial, lo tengo →", de: "Super, verstanden →", it: "Perfetto, ho capito →", pt: "Ótimo, entendi →",
            ar: "ممتاز، فهمت ذلك ←", ja: "了解、次へ進む →", hi: "बढ़िया, समझ गया →", zhHans: "太棒了，我已了解 →", ko: "좋아요, 이해했습니다 →"
        ),
        "3,4× plus rapide avec CertiGo": .init(
            en: "3.4× faster with CertiGo", es: "3,4× más rápido con CertiGo", de: "3,4× schneller mit CertiGo", it: "3,4× più veloce con CertiGo", pt: "3,4× mais rápido com CertiGo",
            ar: "أسرع بـ 3.4 مرات مع CertiGo", ja: "CertiGoなら3.4倍速く合格圏へ", hi: "CertiGo के साथ 3.4× तेज़", zhHans: "使用 CertiGo 备考速度提升 3.4 倍", ko: "CertiGo와 함께 3.4배 더 빠른 합격"
        ),
        "Révision seule (cours longs & PDF)": .init(
            en: "Solo study (long courses & PDFs)", es: "Estudio solo (cursos largos y PDF)", de: "Alleine lernen (lange Kurse & PDFs)", it: "Studio da solo (corsi lunghi e PDF)", pt: "Estudo sozinho (cursos longos e PDF)",
            ar: "المذاكرة الفردية (ملفات PDF مطولة)", ja: "独学（長時間の動画やPDF）", hi: "अकेले पढ़ाई (लंबे कोर्स और पीडीएफ)", zhHans: "传统自学（冗长课程与 PDF）", ko: "독학 (긴 강의 및 PDF 문서)"
        ),
        "~11 semaines": .init(
            en: "~11 weeks", es: "~11 semanas", de: "~11 Wochen", it: "~11 settimane", pt: "~11 semanas",
            ar: "~11 أسبوعاً", ja: "約11週間", hi: "~11 सप्ताह", zhHans: "约 11 周", ko: "약 11주"
        ),
        "Avec CertiGo (sprints actifs & mémoire espacée)": .init(
            en: "With CertiGo (active sprints & spaced repetition)", es: "Con CertiGo (sprints activos y repetición espaciada)", de: "Mit CertiGo (aktive Sprints & Spaced Repetition)", it: "Con CertiGo (sprint attivi e ripetizione spaziata)", pt: "Com CertiGo (sprints ativos e repetição espaçada)",
            ar: "مع CertiGo (تدريبات نشطة وتكرار متباعد)", ja: "CertiGo（能動スプリント＆間隔反復）", hi: "CertiGo के साथ (सक्रिय स्प्रिंट और स्पेस्ड रिपीटिशन)", zhHans: "使用 CertiGo（主动冲刺与间隔重复）", ko: "CertiGo 활용 (능동형 스프린트 및 간격 반복)"
        ),
        "3 semaines · 3,4× plus efficace 🏆": .init(
            en: "3 weeks · 3.4× more effective 🏆", es: "3 semanas · 3,4× más eficaz 🏆", de: "3 Wochen · 3,4× effektiver 🏆", it: "3 settimane · 3,4× più efficace 🏆", pt: "3 semanas · 3,4× mais eficaz 🏆",
            ar: "3 أسابيع · أكثر فعالية بـ 3.4× 🏆", ja: "3週間 · 3.4倍効率的 🏆", hi: "3 सप्ताह · 3.4× अधिक प्रभावी 🏆", zhHans: "3 周 · 效率提升 3.4 倍 🏆", ko: "3주 · 3.4배 더 효과적 🏆"
        ),
        "100 % ciblé sur les pièges d'examen": .init(
            en: "100% focused on real exam traps", es: "100 % enfocado en trampas de examen", de: "100 % fokussiert auf echte Prüfungsfallen", it: "100% mirato alle trappole d'esame", pt: "100% focado nas pegadinhas de exame",
            ar: "مركز 100% على فخاخ الاختبار الفعلية", ja: "試験のひっかけ急所に100%特化", hi: "परीक्षा के ट्रैप्स पर 100% केंद्रित", zhHans: "100% 聚焦真实考试陷阱", ko: "실전 시험 함정 문제 100% 집중 공략"
        ),
        "Rappel actif & répétition espacée": .init(
            en: "Active recall & spaced repetition", es: "Recuerdo activo y repetición espaciada", de: "Aktives Abrufen & Spaced Repetition", it: "Richiamo attivo e ripetizione spaziata", pt: "Recordação ativa e repetição espaçada",
            ar: "الاستدعاء النشط والتكرار المتباعد", ja: "アクティブリコール＆間隔反復記憶", hi: "सक्रिय रिकॉल और स्पेस्ड रिपीटिशन", zhHans: "主动回忆与间隔重复算法", ko: "능동적 인출 및 간격 반복 학습"
        ),
        "20 % du Chapitre 1 déjà crédités !": .init(
            en: "20% of Chapter 1 already credited!", es: "¡20 % del Capítulo 1 ya acreditado!", de: "20 % von Kapitel 1 bereits gutgeschrieben!", it: "20% del Capitolo 1 già accreditato!", pt: "20% do Capítulo 1 já creditados!",
            ar: "تم احتساب 20% من الفصل الأول مسبقاً!", ja: "チャプター1の20%がすでに認定済み！", hi: "अध्याय 1 का 20% पहले ही क्रेडिट हो चुका है!", zhHans: "第 1 章已直接赠送 20% 进度！", ko: "챕터 1의 20% 진행률이 이미 적립되었습니다!"
        ),
        "Sauvegarde tes 20 % d'avance": .init(
            en: "Save your 20% head start", es: "Guarda tu 20 % de ventaja", de: "Sichere dir deinen 20 % Vorsprung", it: "Salva il tuo 20% di vantaggio", pt: "Salve seus 20% de avanço",
            ar: "احفظ تقدمك المبدئي (20%)", ja: "獲得済みの20%ボーナス進捗を保存", hi: "अपनी 20% शुरुआती बढ़त सहेजें", zhHans: "保存您已获得的 20% 领先进度", ko: "획득한 20% 사전 진행률을 저장하세요"
        ),
        "Chapitre 1 : 2 / 10 tampons validés (20 %)": .init(
            en: "Chapter 1: 2 / 10 stamps completed (20%)", es: "Capítulo 1: 2 / 10 sellos validados (20 %)", de: "Kapitel 1: 2 / 10 Stempel bestätigt (20 %)", it: "Capitolo 1: 2 / 10 timbri convalidati (20%)", pt: "Capítulo 1: 2 / 10 selos validados (20%)",
            ar: "الفصل 1: تم إنجاز 2 / 10 أختام (20%)", ja: "チャプター1：2 / 10 スタンプ達成（20%）", hi: "अध्याय 1: 2 / 10 स्टैम्प पूरे (20%)", zhHans: "第 1 章：已点亮 2 / 10 枚印章（20%）", ko: "챕터 1: 2 / 10 스탬프 달성 (20%)"
        ),

        // 4. Parcours Tab (01), Popover (02), Step Sheet (03) & Memo Sheet (14)
        "COMMENCER": .init(
            en: "START", es: "EMPEZAR", de: "STARTEN", it: "INIZIA", pt: "COMEÇAR",
            ar: "ابدأ", ja: "開始", hi: "शुरू करें", zhHans: "开始", ko: "시작"
        ),
        "CONTINUER": .init(
            en: "CONTINUE", es: "CONTINUAR", de: "WEITER", it: "CONTINUA", pt: "CONTINUAR",
            ar: "متابعة", ja: "続ける", hi: "जारी रखें", zhHans: "继续", ko: "계속"
        ),
        "🧪 MINI-LAB PRATIQUE": .init(
            en: "🧪 HANDS-ON MINI-LAB", es: "🧪 MINI-LAB PRÁCTICO", de: "🧪 PRAXIS-MINI-LAB", it: "🧪 MINI-LAB PRATICO", pt: "🧪 MINI-LAB PRÁTICO",
            ar: "🧪 مختبر عملي مصغر", ja: "🧪 実践ミニラボ", hi: "🧪 प्रैक्टिकल मिनी-लैब", zhHans: "🧪 实战迷你实验", ko: "🧪 실전 미니 랩"
        ),
        "🧪 Mini-Lab": .init(
            en: "🧪 Mini-Lab", es: "🧪 Mini-Lab", de: "🧪 Mini-Lab", it: "🧪 Mini-Lab", pt: "🧪 Mini-Lab",
            ar: "🧪 مختبر", ja: "🧪 ミニラボ", hi: "🧪 मिनी-लैब", zhHans: "🧪 迷你实验", ko: "🧪 미니 랩"
        ),
        "🏆 Boss": .init(
            en: "🏆 Boss", es: "🏆 Jefe", de: "🏆 Boss", it: "🏆 Boss", pt: "🏆 Chefe",
            ar: "🏆 التحدي النهائي", ja: "🏆 ボス", hi: "🏆 बॉस", zhHans: "🏆 章节 Boss", ko: "🏆 보스"
        ),
        "CHOISIR UNE MARQUE OFFICIELLE": .init(
            en: "CHOOSE AN OFFICIAL VENDOR", es: "ELEGIR UNA MARCA OFICIAL", de: "OFFIZIELLEN ANBIETER WÄHLEN", it: "SCEGLI UN BRAND UFFICIALE", pt: "ESCOLHER UMA MARCA OFICIAL",
            ar: "اختر جهة رسمية", ja: "公式ベンダーを選択", hi: "आधिकारिक ब्रांड चुनें", zhHans: "选择官方认证厂商", ko: "공식 벤더 선택"
        ),
        "Version simple": .init(
            en: "Simple mode", es: "Versión simple", de: "Einfache Version", it: "Versione semplice", pt: "Versão simples",
            ar: "الوضع المبسط", ja: "やさしい解説モード", hi: "सरल संस्करण", zhHans: "通俗易懂模式", ko: "쉬운 설명 모드"
        ),
        "Défi Examen": .init(
            en: "Exam Challenge", es: "Modo Examen", de: "Prüfungsmodus", it: "Sfida Esame", pt: "Desafio Exame",
            ar: "تحدي الاختبار", ja: "本番試験モード", hi: "परीक्षा चुनौती", zhHans: "真题挑战模式", ko: "실전 시험 모드"
        ),
        "📖 Mémo d'Unité": .init(
            en: "📖 Unit Study Guide", es: "📖 Guía de Unidad", de: "📖 Einheits-Memo", it: "📖 Memo dell'Unità", pt: "📖 Guia da Unidade",
            ar: "📖 ملخص الوحدة", ja: "📖 ユニット要点メモ", hi: "📖 यूनिट मेमो", zhHans: "📖 单元核心速记", ko: "📖 유닛 핵심 노트"
        ),
        "MÉMO D'UNITÉ": .init(
            en: "UNIT STUDY GUIDE", es: "GUÍA DE UNIDAD", de: "EINHEITS-MEMO", it: "MEMO DELL'UNITÀ", pt: "GUIA DA UNIDADE",
            ar: "ملخص الوحدة", ja: "ユニット要点メモ", hi: "यूनिट मेमो", zhHans: "单元核心速记", ko: "유닛 핵심 노트"
        ),
        "RÈGLE D'OR D'ARCHITECTURE": .init(
            en: "GOLDEN ARCHITECTURE RULE", es: "REGLA DE ORO DE ARQUITECTURA", de: "GOLDENE ARCHITEKTURREGEL", it: "REGOLA D'ORO DI ARCHITETTURA", pt: "REGRA DE OURO DE ARQUITETURA",
            ar: "القاعدة الذهبية للمعمارية", ja: "アーキテクチャの鉄則", hi: "आर्किटेक्चर का सुनहरा नियम", zhHans: "架构黄金法则", ko: "아키텍처 핵심 원칙"
        ),
        "COMPRIS · RETOUR AU PARCOURS": .init(
            en: "GOT IT · BACK TO PATH", es: "ENTENDIDO · VOLVER A LA RUTA", de: "VERSTANDEN · ZURÜCK ZUM PFAD", it: "CAPITO · TORNA AL PERCORSO", pt: "ENTENDI · VOLTAR AO PERCURSO",
            ar: "فهمت · العودة إلى المسار", ja: "理解しました · コースに戻る", hi: "समझ गया · पथ पर वापस जाएं", zhHans: "已掌握 · 返回学习路径", ko: "확인 완료 · 경로로 돌아가기"
        ),

        // 5. Interactive Lesson Session (15 -> Exercises -> 18/04 -> 05/20 -> 19)
        "J'AI COMPRIS · PASSER AUX QUESTIONS →": .init(
            en: "GOT IT · START QUESTIONS →", es: "ENTENDIDO · PASAR A LAS PREGUNTAS →", de: "VERSTANDEN · ZU DEN FRAGEN →", it: "HO CAPITO · PASSA ALLE DOMANDE →", pt: "ENTENDI · IR PARA AS QUESTÕES →",
            ar: "فهمت · الانتقال إلى الأسئلة ←", ja: "理解完了 · 演習問題へ進む →", hi: "समझ गया · प्रश्नों पर जाएं →", zhHans: "我已理解 · 开始答题 →", ko: "이해 완료 · 문제 풀이 시작 →"
        ),
        "VÉRIFIER": .init(
            en: "CHECK", es: "COMPROBAR", de: "PRÜFEN", it: "VERIFICA", pt: "VERIFICAR",
            ar: "تحقق", ja: "回答をチェック", hi: "जांचें", zhHans: "检查答案", ko: "정답 확인"
        ),
        "CONTINUER →": .init(
            en: "CONTINUE →", es: "CONTINUAR →", de: "WEITER →", it: "CONTINUA →", pt: "CONTINUAR →",
            ar: "متابعة ←", ja: "次へ →", hi: "जारी रखें →", zhHans: "继续 →", ko: "계속하기 →"
        ),
        "CONTINUER ➔": .init(
            en: "CONTINUE ➔", es: "CONTINUAR ➔", de: "WEITER ➔", it: "CONTINUA ➔", pt: "CONTINUAR ➔",
            ar: "متابعة ➔", ja: "次へ ➔", hi: "जारी रखें ➔", zhHans: "继续 ➔", ko: "계속하기 ➔"
        ),
        "Excellent réflexe !": .init(
            en: "Spot on!", es: "¡Excelente reflejo!", de: "Ausgezeichnet!", it: "Ottimo riflesso!", pt: "Excelente reflexo!",
            ar: "إجابة ممتازة!", ja: "素晴らしい判断です！", hi: "शानदार जवाब!", zhHans: "回答非常精准！", ko: "정확한 판단입니다!"
        ),
        "Pas tout à fait…": .init(
            en: "Not quite...", es: "No exactamente...", de: "Nicht ganz...", it: "Non proprio...", pt: "Não exatamente...",
            ar: "ليس تماماً...", ja: "あと一歩です...", hi: "बिल्कुल सही नहीं...", zhHans: "还差一点点...", ko: "아쉽네요..."
        ),
        "Pourquoi ?": .init(
            en: "Why?", es: "¿Por qué?", de: "Warum?", it: "Perché?", pt: "Por quê?",
            ar: "لماذا؟", ja: "なぜ？", hi: "क्यों?", zhHans: "为什么？", ko: "이유 보기"
        ),
        "Comparer": .init(
            en: "Compare", es: "Comparar", de: "Vergleichen", it: "Confronta", pt: "Comparar",
            ar: "مقارنة", ja: "比較する", hi: "तुलना करें", zhHans: "对比服务", ko: "비교하기"
        ),
        "💡 ASTUCE D'EXAMEN": .init(
            en: "💡 EXAM TIP", es: "💡 CONSEJO DE EXAMEN", de: "💡 PRÜFUNGSTIPP", it: "💡 CONSIGLIO D'ESAME", pt: "💡 DICA DE EXAME",
            ar: "💡 نصيحة الاختبار", ja: "💡 試験対策のコツ", hi: "💡 परीक्षा टिप", zhHans: "💡 考试技巧", ko: "💡 시험 팁"
        ),
        "✦ Comparer (20)": .init(
            en: "✦ Compare Services", es: "✦ Comparar servicios", de: "✦ Dienste vergleichen", it: "✦ Confronta servizi", pt: "✦ Comparar serviços",
            ar: "✦ مقارنة الخدمات", ja: "✦ サービス比較", hi: "✦ सेवाओं की तुलना करें", zhHans: "✦ 架构对比", ko: "✦ 서비스 비교"
        ),
        "CONTINUER LA SÉANCE": .init(
            en: "CONTINUE SESSION", es: "CONTINUAR LA SESIÓN", de: "SITZUNG FORTSETZEN", it: "CONTINUA LA SESSIONE", pt: "CONTINUAR A SESSÃO",
            ar: "متابعة الجلسة", ja: "セッションを続ける", hi: "सत्र जारी रखें", zhHans: "继续练习", ko: "학습 계속하기"
        ),
        "Étape terminée !": .init(
            en: "Step completed!", es: "¡Etapa completada!", de: "Schritt abgeschlossen!", it: "Tappa completata!", pt: "Etapa concluída!",
            ar: "اكتملت المرحلة!", ja: "ステップ完了！", hi: "चरण पूरा हुआ!", zhHans: "本节挑战完成！", ko: "단계 완료!"
        ),
        "RYTHME": .init(
            en: "PACE", es: "RITMO", de: "TEMPO", it: "RITMO", pt: "RITMO",
            ar: "السرعة", ja: "スピード", hi: "गति", zhHans: "答题速度", ko: "속도"
        ),
        "PRÉCISION": .init(
            en: "ACCURACY", es: "PRECISIÓN", de: "GENAUIGKEIT", it: "PRECISIONE", pt: "PRECISÃO",
            ar: "الدقة", ja: "正答率", hi: "सटीकता", zhHans: "准确率", ko: "정확도"
        ),
        "SÉRIE": .init(
            en: "STREAK", es: "RACHA", de: "SERIE", it: "SERIE", pt: "OFENSIVA",
            ar: "السلسلة", ja: "連続日数", hi: "स्ट्रीक", zhHans: "连续天数", ko: "연속 학습"
        ),
        "RETOUR AU PARCOURS (DÉBLOQUER LA SUITE)": .init(
            en: "BACK TO PATH (UNLOCK NEXT STEP)", es: "VOLVER A LA RUTA (DESBLOQUEAR SIGUIENTE)", de: "ZURÜCK ZUM PFAD (NÄCHSTEN SCHRITT FREISCHALTEN)", it: "TORNA AL PERCORSO (SBLOCCA IL PROSSIMO)", pt: "VOLTAR AO PERCURSO (DESBLOQUEAR PRÓXIMA)",
            ar: "العودة للمسار (فتح المرحلة التالية)", ja: "コースに戻る（次のステップを解放）", hi: "पथ पर वापस जाएं (अगला चरण अनलॉक करें)", zhHans: "返回学习路径（解锁下一节）", ko: "경로로 돌아가기 (다음 단계 잠금 해제)"
        ),
        "Tu n'as plus de cœurs ! 💔 (5 fautes)": .init(
            en: "You're out of hearts! 💔 (5 mistakes)", es: "¡Te quedaste sin corazones! 💔 (5 fallos)", de: "Keine Herzen mehr! 💔 (5 Fehler)", it: "Hai finito i cuori! 💔 (5 errori)", pt: "Você ficou sem corações! 💔 (5 erros)",
            ar: "نفدت قلوبك! 💔 (5 أخطاء)", ja: "ライフがなくなりました！💔（5回ミス）", hi: "आपके पास दिल खत्म हो गए हैं! 💔 (5 गलतियां)", zhHans: "红心已耗尽！💔（5 次失误）", ko: "하트가 모두 소진되었습니다! 💔 (5회 오답)"
        ),
        "Tu as fait 5 erreurs sur cette étape. Il faut terminer l'étape avec au moins 1 cœur pour valider tes acquis et débloquer l'étape suivante du parcours.": .init(
            en: "You made 5 mistakes on this step. Finish with at least 1 heart remaining to validate your mastery and unlock the next step.",
            es: "Cometiste 5 errores en esta etapa. Debes terminar con al menos 1 corazón para validar tu dominio y desbloquear la siguiente etapa.",
            de: "Du hast in diesem Schritt 5 Fehler gemacht. Beende ihn mit mindestens 1 Herz, um den nächsten Schritt freizuschalten.",
            it: "Hai commesso 5 errori in questa tappa. Devi completarla con almeno 1 cuore per sbloccare la tappa successiva.",
            pt: "Você cometeu 5 erros nesta etapa. Termine com pelo menos 1 coração para validar seu domínio e desbloquear a próxima etapa.",
            ar: "ارتكبت 5 أخطاء في هذه المرحلة. يجب إنهاء المرحلة بقلب واحد على الأقل لفتح المرحلة التالية.",
            ja: "このステップで5回ミスしました。次のステップを解放するには、ライフを1つ以上残してクリアする必要があります。",
            hi: "आपने इस चरण में 5 गलतियां कीं। अगला चरण अनलॉक करने के लिए कम से कम 1 दिल के साथ पूरा करें।",
            zhHans: "您在本节中出现了 5 次失误。请至少保留 1 颗红心完成本节，以解锁下一阶段。",
            ko: "이 단계에서 5번 틀렸습니다. 다음 단계를 잠금 해제하려면 최소 1개의 하트를 남기고 완료해야 합니다."
        ),
        "🔄 Recommencer cette étape (5 ❤️ neufs)": .init(
            en: "🔄 Retry this step (5 fresh ❤️)", es: "🔄 Reintentar esta etapa (5 ❤️ nuevos)", de: "🔄 Schritt neu starten (5 frische ❤️)", it: "🔄 Ricomincia questa tappa (5 ❤️ nuovi)", pt: "🔄 Recomeçar esta etapa (5 ❤️ novos)",
            ar: "🔄 إعادة المحاولة (5 ❤️ جديدة)", ja: "🔄 このステップをやり直す（5 ❤️ 回復）", hi: "🔄 इस चरण को पुनः आरंभ करें (5 नए ❤️)", zhHans: "🔄 重新挑战本节（恢复 5 颗 ❤️）", ko: "🔄 이 단계 다시 시작하기 (새 하트 5개 ❤️)"
        ),
        "← Retourner au parcours (Étape non débloquée)": .init(
            en: "← Back to path (Step still locked)", es: "← Volver a la ruta (Etapa no desbloqueada)", de: "← Zurück zum Pfad (Schritt noch gesperrt)", it: "← Torna al percorso (Tappa non sbloccata)", pt: "← Voltar ao percurso (Etapa bloqueada)",
            ar: "← العودة إلى المسار", ja: "← コースに戻る（未クリア）", hi: "← पथ पर वापस जाएं", zhHans: "← 返回学习路径（本节未解锁）", ko: "← 경로로 돌아가기 (미완료)"
        ),

        // 6. Examens Tab (21), Sheet (22), Cockpit (23) & Report (24)
        "Examen Blanc Complet": .init(
            en: "Full Timed Mock Exam", es: "Examen Blanco Completo", de: "Vollständige Probeprüfung", it: "Simulazione d'Esame Completa", pt: "Simulado Oficial Completo",
            ar: "اختبار تجريبي كامل", ja: "本番形式フル模擬試験", hi: "पूर्ण मॉक परीक्षा", zhHans: "全真模拟考试", ko: "실전 전체 모의고사"
        ),
        "DÉMARRER L'EXAMEN COMPLET": .init(
            en: "START FULL MOCK EXAM", es: "INICIAR EXAMEN COMPLETO", de: "VOLLSTÄNDIGE PRÜFUNG STARTEN", it: "AVVIA ESAME COMPLETO", pt: "INICIAR SIMULADO COMPLETO",
            ar: "بدء الاختبار التجريبي الكامل", ja: "フル模擬試験を開始", hi: "पूर्ण परीक्षा शुरू करें", zhHans: "开始全真模拟考试", ko: "전체 모의고사 시작"
        ),
        "DOMAINES OFFICIELS": .init(
            en: "OFFICIAL EXAM DOMAINS", es: "DOMINIOS OFICIALES", de: "OFFIZIELLE PRÜFUNGSBEREICHE", it: "DOMINI UFFICIALI D'ESAME", pt: "DOMÍNIOS OFICIAIS",
            ar: "المجالات الرسمية للاختبار", ja: "公式出題ドメイン", hi: "आधिकारिक परीक्षा डोमेन", zhHans: "官方考试知识域", ko: "공식 시험 도메인"
        ),
        "🏳 Marquer": .init(
            en: "🏳 Flag", es: "🏳 Marcar", de: "🏳 Markieren", it: "🏳 Segna", pt: "🏳 Marcar",
            ar: "🏳 تعليم", ja: "🏳 フラグ", hi: "🏳 चिह्नित करें", zhHans: "🏳 标记", ko: "🏳 표시"
        ),
        "🏳 Marquée ✓": .init(
            en: "🏳 Flagged ✓", es: "🏳 Marcada ✓", de: "🏳 Markiert ✓", it: "🏳 Segnata ✓", pt: "🏳 Marcada ✓",
            ar: "🏳 معلمة ✓", ja: "🏳 フラグ済 ✓", hi: "🏳 चिह्नित ✓", zhHans: "🏳 已标记 ✓", ko: "🏳 표시됨 ✓"
        ),
        "← Préc.": .init(
            en: "← Prev", es: "← Ant.", de: "← Zurück", it: "← Prec.", pt: "← Ant.",
            ar: "← السابق", ja: "← 前へ", hi: "← पिछला", zhHans: "← 上一题", ko: "← 이전"
        ),
        "QUESTION SUIVANTE →": .init(
            en: "NEXT QUESTION →", es: "SIGUIENTE PREGUNTA →", de: "NÄCHSTE FRAGE →", it: "DOMANDA SUCCESSIVA →", pt: "PRÓXIMA QUESTÃO →",
            ar: "السؤال التالي ←", ja: "次の問題へ →", hi: "अगला प्रश्न →", zhHans: "下一题 →", ko: "다음 문제 →"
        ),
        "TERMINER L'EXAMEN ✓": .init(
            en: "FINISH EXAM ✓", es: "TERMINAR EXAMEN ✓", de: "PRÜFUNG BEENDEN ✓", it: "TERMINA ESAME ✓", pt: "FINALIZAR EXAME ✓",
            ar: "إنهاء الاختبار ✓", ja: "試験を終了する ✓", hi: "परीक्षा समाप्त करें ✓", zhHans: "交卷并查看成绩 ✓", ko: "시험 종료 ✓"
        ),
        "Terminer": .init(
            en: "Finish", es: "Terminar", de: "Beenden", it: "Termina", pt: "Finalizar",
            ar: "إنهاء", ja: "終了", hi: "समाप्त", zhHans: "交卷", ko: "종료"
        ),
        "■ En cours": .init(
            en: "■ Current", es: "■ Actual", de: "■ Aktuell", it: "■ Attuale", pt: "■ Atual",
            ar: "■ الحالي", ja: "■ 現在", hi: "■ वर्तमान", zhHans: "■ 当前", ko: "■ 현재"
        ),
        "■ Répondue ✓": .init(
            en: "■ Answered ✓", es: "■ Respondida ✓", de: "■ Beantwortet ✓", it: "■ Risposta ✓", pt: "■ Respondida ✓",
            ar: "■ مجاب ✓", ja: "■ 回答済 ✓", hi: "■ उत्तर दिया ✓", zhHans: "■ 已答 ✓", ko: "■ 답변됨 ✓"
        ),
        "■ Marquée 🏳": .init(
            en: "■ Flagged 🏳", es: "■ Marcada 🏳", de: "■ Markiert 🏳", it: "■ Segnata 🏳", pt: "■ Marcada 🏳",
            ar: "■ معلمة 🏳", ja: "■ フラグ 🏳", hi: "■ चिह्नित 🏳", zhHans: "■ 已标记 🏳", ko: "■ 표시됨 🏳"
        ),
        "■ À faire": .init(
            en: "■ To do", es: "■ Pendiente", de: "■ Offen", it: "■ Da fare", pt: "■ Pendente",
            ar: "■ متبقي", ja: "■ 未回答", hi: "■ बाकी", zhHans: "■ 未答", ko: "■ 미답변"
        ),

        // 7. Coach IA (06, 06B, 06C, 06D)
        "+ Nouvelle": .init(
            en: "+ New", es: "+ Nueva", de: "+ Neu", it: "+ Nuova", pt: "+ Nova",
            ar: "+ محادثة جديدة", ja: "+ 新規", hi: "+ नया", zhHans: "+ 新对话", ko: "+ 새 대화"
        ),
        "Pose n'importe quelle question ou révise ton parcours à ton rythme.": .init(
            en: "Ask any architecture question or review your track at your own pace.",
            es: "Haz cualquier pregunta o repasa tu ruta a tu propio ritmo.",
            de: "Stelle jede beliebige Frage oder wiederhole deinen Pfad in deinem Tempo.",
            it: "Fai qualsiasi domanda o ripassa il tuo percorso al tuo ritmo.",
            pt: "Faça qualquer pergunta ou revise sua trilha no seu ritmo.",
            ar: "اطرح أي سؤال معماري أو راجع مسارك بالسرعة التي تناسبك.",
            ja: "疑問点を何でも質問するか、自分のペースでコースを復習しましょう。",
            hi: "कोई भी प्रश्न पूछें या अपनी गति से अपने ट्रैक का रिवीजन करें।",
            zhHans: "随时提问任何架构难题，或按您的节奏复习当前路径。",
            ko: "궁금한 점을 질문하거나 나만의 속도로 학습 경로를 복습하세요."
        ),
        "Explique-moi RBAC vs Azure Policy": .init(
            en: "Explain RBAC vs Azure Policy", es: "Explícame RBAC vs Azure Policy", de: "Erkläre mir RBAC vs. Azure Policy", it: "Spiegami RBAC vs Azure Policy", pt: "Explique RBAC vs Azure Policy",
            ar: "اشرح الفرق بين RBAC وAzure Policy", ja: "RBACとAzure Policyの違いを解説して", hi: "RBAC बनाम Azure Policy समझाएं", zhHans: "用通俗语言解释 RBAC 与 Azure Policy 的区别", ko: "RBAC와 Azure Policy의 차이점 설명해 줘"
        ),
        "Différences, portée & priorité en français clair": .init(
            en: "Differences, scope & priority in plain language", es: "Diferencias, alcance y prioridad en lenguaje claro", de: "Unterschiede, Umfang & Priorität einfach erklärt", it: "Differenze, ambito e priorità in modo chiaro", pt: "Diferenças, escopo e prioridade de forma clara",
            ar: "الفروق والنطاق والأولوية بلغة واضحة", ja: "違い・適用範囲・優先順位をわかりやすく解説", hi: "सरल भाषा में अंतर, दायरा और प्राथमिकता", zhHans: "通俗讲清核心区别、作用域与优先级", ko: "차이점, 적용 범위 및 우선순위를 쉽게 설명"
        ),
        "Simuler un entretien technique à voix haute": .init(
            en: "Simulate a live voice technical interview", es: "Simular una entrevista técnica por voz", de: "Technisches Sprachinterview simulieren", it: "Simula un colloquio tecnico vocale", pt: "Simular uma entrevista técnica por voz",
            ar: "محاكاة مقابلة تقنية صوتية مباشرة", ja: "音声で技術面接をシミュレーション", hi: "लाइव वॉयस तकनीकी साक्षात्कार का अभ्यास करें", zhHans: "语音模拟技术架构面试", ko: "음성으로 기술 면접 시뮬레이션"
        ),
        "Discussion interactive sur ton architecture": .init(
            en: "Interactive discussion about your cloud architecture", es: "Conversación interactiva sobre tu arquitectura", de: "Interaktives Gespräch über deine Architektur", it: "Discussione interattiva sulla tua architettura", pt: "Discussão interativa sobre sua arquitetura",
            ar: "نقاش تفاعلي حول تصميمك المعماري", ja: "アーキテクチャ設計に関する対話型ディスカッション", hi: "आपके आर्किटेक्चर पर इंटरैक्टिव चर्चा", zhHans: "围绕您的云架构进行互动问答", ko: "아키텍처 설계에 대한 대화형 토론"
        ),
        "Analyse ma progression et mes erreurs": .init(
            en: "Analyze my progress and recent mistakes", es: "Analiza mi progreso y mis errores", de: "Analysiere meinen Fortschritt und meine Fehler", it: "Analizza i miei progressi e i miei errori", pt: "Analise meu progresso e meus erros",
            ar: "حلل تقدمي وأخطائي الأخيرة", ja: "学習の進捗と弱点ミスを分析して", hi: "मेरी प्रगति और गलतियों का विश्लेषण करें", zhHans: "分析我的学习进度与近期错题", ko: "내 학습 진행률과 오답 분석하기"
        ),
        "Conseils personnalisés selon tes réponses": .init(
            en: "Personalized coaching based on your answers", es: "Consejos personalizados según tus respuestas", de: "Persönliche Tipps basierend auf deinen Antworten", it: "Consigli personalizzati in base alle tue risposte", pt: "Dicas personalizadas com base nas suas respostas",
            ar: "نصائح مخصصة بناءً على إجاباتك", ja: "あなたの回答履歴に基づく個別アドバイス", hi: "आपके उत्तरों के आधार पर व्यक्तिगत सुझाव", zhHans: "基于您的作答记录提供定制化建议", ko: "내 답변 기록을 바탕으로 한 맞춤형 조언"
        ),
        "Donne-moi un exemple de code ou CLI": .init(
            en: "Give me a practical CLI or code example", es: "Dame un ejemplo práctico de código o CLI", de: "Gib mir ein praktisches Code- oder CLI-Beispiel", it: "Dammi un esempio pratico di codice o CLI", pt: "Dê-me um exemplo prático de código ou CLI",
            ar: "أعطني مثالاً عملياً للأوامر البرمجية أو CLI", ja: "実践的なCLIコマンドやコード例を教えて", hi: "मुझे कोड या CLI का व्यावहारिक उदाहरण दें", zhHans: "给我一个实用的 CLI 命令或代码示例", ko: "실전 CLI 명령어 또는 코드 예제 보기"
        ),

        // 8. Social Tab (07 & 25)
        "➕ Ajouter": .init(
            en: "➕ Add Friend", es: "➕ Añadir", de: "➕ Hinzufügen", it: "➕ Aggiungi", pt: "➕ Adicionar",
            ar: "➕ إضافة", ja: "➕ 友達追加", hi: "➕ जोड़ें", zhHans: "➕ 添加好友", ko: "➕ 친구 추가"
        ),
        "QUÊTE D'ÉQUIPE · OBJECTIF HEBDO": .init(
            en: "TEAM QUEST · WEEKLY GOAL", es: "MISIÓN DE EQUIPO · META SEMANAL", de: "TEAM-QUEST · WOCHENZIEL", it: "MISSIONE DI SQUADRA · OBIETTIVO SETTIMANALE", pt: "MISSÃO EM EQUIPE · META SEMANAL",
            ar: "مهمة الفريق · الهدف الأسبوعي", ja: "チームクエスト · 週間目標", hi: "टीम क्वेस्ट · साप्ताहिक लक्ष्य", zhHans: "小队任务 · 本周目标", ko: "팀 퀘스트 · 주간 목표"
        ),
        "Terminer 15 étapes à deux": .init(
            en: "Complete 15 steps together", es: "Completar 15 etapas en pareja", de: "15 Schritte gemeinsam abschließen", it: "Completare 15 tappe in coppia", pt: "Concluir 15 etapas em dupla",
            ar: "إنجاز 15 مرحلة معاً", ja: "ペアで合計15ステップをクリア", hi: "मिलकर 15 चरण पूरे करें", zhHans: "两人合力完成 15 个小节", ko: "둘이서 함께 15단계 완료하기"
        ),
        "Aucun binôme associé pour le moment": .init(
            en: "No study partner paired yet", es: "Aún no tienes compañero asignado", de: "Noch kein Lernpartner verbunden", it: "Nessun compagno associato al momento", pt: "Nenhum parceiro associado no momento",
            ar: "لم يتم ربط شريك دراسة بعد", ja: "現在ペアリング中の学習パートナーはいません", hi: "अभी तक कोई स्टडी पार्टनर नहीं जुड़ा है", zhHans: "暂未绑定学习搭档", ko: "아직 연결된 학습 파트너가 없습니다"
        ),
        "➕ Inviter un binôme": .init(
            en: "➕ Invite a study partner", es: "➕ Invitar a un compañero", de: "➕ Lernpartner einladen", it: "➕ Invita un compagno", pt: "➕ Convidar um parceiro",
            ar: "➕ دعوة شريك دراسة", ja: "➕ 学習パートナーを招待", hi: "➕ स्टडी पार्टनर को आमंत्रित करें", zhHans: "➕ 邀请学习搭档", ko: "➕ 학습 파트너 초대하기"
        ),
        "CLASSEMENT LIGUE OR": .init(
            en: "GOLD LEAGUE LEADERBOARD", es: "CLASIFICACIÓN LIGA ORO", de: "GOLD-LIGA RANGLISTE", it: "CLASSIFICA LEGA ORO", pt: "RANKING LIGA OURO",
            ar: "ترتيب الدوري الذهبي", ja: "ゴールドリーグ順位表", hi: "गोल्ड लीग लीडरबोर्ड", zhHans: "黄金联赛排行榜", ko: "골드 리그 순위표"
        ),
        "Lancer": .init(
            en: "Start", es: "Iniciar", de: "Starten", it: "Avvia", pt: "Iniciar",
            ar: "ابدأ", ja: "開始", hi: "शुरू करें", zhHans: "开始", ko: "시작"
        ),
        "Squad en direct": .init(
            en: "Live Squad Activity", es: "Squad en vivo", de: "Squad Live", it: "Squad in diretta", pt: "Squad ao vivo",
            ar: "نشاط الفريق المباشر", ja: "スクワッドのリアルタイム状況", hi: "लाइव स्क्वाड", zhHans: "小队实时动态", ko: "실시간 스쿼드 현황"
        ),
        "👋 Féliciter": .init(
            en: "👋 High-five", es: "👋 Felicitar", de: "👋 Gratulieren", it: "👋 Congratulati", pt: "👋 Parabenizar",
            ar: "👋 تهنئة", ja: "👋 称賛する", hi: "👋 बधाई दें", zhHans: "👋 点赞鼓励", ko: "👋 응원하기"
        ),

        // 9. Moi Tab (08), Stats Pro (08B), Cert Detail (26), PRO (27) & Settings (28)
        "Mon Profil": .init(
            en: "My Profile", es: "Mi Perfil", de: "Mein Profil", it: "Il Mio Profilo", pt: "Meu Perfil",
            ar: "ملفي الشخصي", ja: "マイプロフィール", hi: "मेरी प्रोफ़ाइल", zhHans: "个人主页", ko: "내 프로필"
        ),
        "Membre PRO": .init(
            en: "PRO Member", es: "Miembro PRO", de: "PRO-Mitglied", it: "Membro PRO", pt: "Membro PRO",
            ar: "عضو PRO", ja: "PROメンバー", hi: "PRO सदस्य", zhHans: "PRO 会员", ko: "PRO 멤버"
        ),
        "Compte PRO": .init(
            en: "PRO Account", es: "Cuenta PRO", de: "PRO-Konto", it: "Account PRO", pt: "Conta PRO",
            ar: "حساب PRO", ja: "PROアカウント", hi: "PRO खाता", zhHans: "PRO 账户", ko: "PRO 계정"
        ),
        "Compte Gratuit": .init(
            en: "Free Account", es: "Cuenta Gratuita", de: "Kostenloses Konto", it: "Account Gratuito", pt: "Conta Gratuita",
            ar: "حساب مجاني", ja: "無料アカウント", hi: "निःशुल्क खाता", zhHans: "免费账户", ko: "무료 계정"
        ),
        "Série active": .init(
            en: "Active streak", es: "Racha activa", de: "Aktive Serie", it: "Serie attiva", pt: "Ofensiva ativa",
            ar: "سلسلة نشطة", ja: "連続学習", hi: "सक्रिय स्ट्रीक", zhHans: "连续打卡", ko: "연속 학습"
        ),
        "Validées": .init(
            en: "Completed", es: "Completadas", de: "Abgeschlossen", it: "Completate", pt: "Concluídas",
            ar: "مكتملة", ja: "クリア済", hi: "पूरे किए", zhHans: "已完成", ko: "완료됨"
        ),
        "Ligue Semaine": .init(
            en: "Weekly League", es: "Liga Semanal", de: "Wochenliga", it: "Lega Settimanale", pt: "Liga Semanal",
            ar: "دوري الأسبوع", ja: "週間リーグ", hi: "साप्ताहिक लीग", zhHans: "本周联赛", ko: "주간 리그"
        ),
        "Ligue hebdo": .init(
            en: "Weekly league", es: "Liga semanal", de: "Wochenliga", it: "Lega settimanale", pt: "Liga semanal",
            ar: "الدوري الأسبوعي", ja: "週間リーグ", hi: "साप्ताहिक लीग", zhHans: "每周联赛", ko: "주간 리그"
        ),
        "Costumes de la mascotte": .init(
            en: "Mascot outfits", es: "Figurinos de la mascota", de: "Maskottchen-Kostüme", it: "Costumi della mascotte", pt: "Figurinos do mascote",
            ar: "أزياء التميمة", ja: "マスコット衣装", hi: "मैस्कॉट पोशाकें", zhHans: "吉祥物装扮", ko: "마스코트 의상"
        ),
        "Parcours actifs": .init(
            en: "Active tracks", es: "Rutas activas", de: "Aktive Lernpfade", it: "Percorsi attivi", pt: "Trilhas ativas",
            ar: "المسارات النشطة", ja: "学習中のコース", hi: "सक्रिय ट्रैक", zhHans: "活跃路径", ko: "진행 중인 트랙"
        ),
        "Langue des cours": .init(
            en: "Course language", es: "Idioma de cursos", de: "Kurssprache", it: "Lingua dei corsi", pt: "Idioma dos cursos",
            ar: "لغة الدورات", ja: "コースの言語", hi: "कोर्स की भाषा", zhHans: "课程语言", ko: "강의 언어"
        ),
        "Cours hors ligne": .init(
            en: "Offline courses", es: "Cursos sin conexión", de: "Offline-Kurse", it: "Corsi offline", pt: "Cursos offline",
            ar: "دورات دون اتصال", ja: "オフラインコース", hi: "ऑफ़लाइन कोर्स", zhHans: "离线课程", ko: "오프라인 강의"
        ),
        "Widgets et Dynamic Island": .init(
            en: "Widgets & Dynamic Island", es: "Widgets y Dynamic Island", de: "Widgets & Dynamic Island", it: "Widget e Dynamic Island", pt: "Widgets e Dynamic Island",
            ar: "الأدوات وDynamic Island", ja: "ウィジェット＆Dynamic Island", hi: "विजेट और Dynamic Island", zhHans: "小组件与灵动岛", ko: "위젯 및 Dynamic Island"
        ),
        "Centre de contrôle": .init(
            en: "Control Center", es: "Centro de control", de: "Kontrollzentrum", it: "Centro di Controllo", pt: "Central de Controle",
            ar: "مركز التحكم", ja: "コントロールセンター", hi: "कंट्रोल सेंटर", zhHans: "控制中心", ko: "제어 센터"
        ),
        "Lien d'invitation": .init(
            en: "Invite link", es: "Enlace de invitación", de: "Einladungslink", it: "Link d'invito", pt: "Link de convite",
            ar: "رابط الدعوة", ja: "招待リンク", hi: "आमंत्रण लिंक", zhHans: "邀请链接", ko: "초대 링크"
        ),
        "Lien et QR code": .init(
            en: "Link & QR code", es: "Enlace y código QR", de: "Link & QR-Code", it: "Link e codice QR", pt: "Link e código QR",
            ar: "الرابط ورمز QR", ja: "リンク＆QRコード", hi: "लिंक और QR कोड", zhHans: "链接与二维码", ko: "링크 및 QR 코드"
        ),
        "Rechercher un pseudo": .init(
            en: "Search username", es: "Buscar usuario", de: "Nutzername suchen", it: "Cerca nickname", pt: "Buscar apelido",
            ar: "ابحث عن اسم مستخدم", ja: "ユーザー名を検索", hi: "यूज़रनेम खोजें", zhHans: "搜索昵称", ko: "닉네임 검색"
        ),
        "Cours": .init(
            en: "Course", es: "Curso", de: "Kurs", it: "Corso", pt: "Curso",
            ar: "الدرس", ja: "コース", hi: "कोर्स", zhHans: "课程", ko: "강의"
        ),
        "Déclic": .init(
            en: "Key insight", es: "Idea clave", de: "Aha-Moment", it: " intuizione", pt: "Virada de chave",
            ar: "الفكرة الأساسية", ja: "ひらめき", hi: "मुख्य बिंदु", zhHans: "核心顿悟", ko: "핵심 포인트"
        ),
        "📊 Voir mes Statistiques & Analyses Pro": .init(
            en: "📊 View my Pro Analytics & Readiness", es: "📊 Ver mis Estadísticas y Análisis Pro", de: "📊 Meine Pro-Statistiken & Analysen ansehen", it: "📊 Vedi Statistiche e Analisi Pro", pt: "📊 Ver minhas Estatísticas e Análises Pro",
            ar: "📊 عرض إحصائياتي وتحليلات PRO", ja: "📊 Pro統計＆合格予測分析を見る", hi: "📊 मेरे प्रो आंकड़े और विश्लेषण देखें", zhHans: "📊 查看专业数据统计与备考分析", ko: "📊 Pro 통계 및 합격 분석 보기"
        ),
        "←  Moi": .init(
            en: "←  Me", es: "←  Perfil", de: "←  Profil", it: "←  Profilo", pt: "←  Perfil",
            ar: "←  حسابي", ja: "←  マイページ", hi: "←  प्रोफ़ाइल", zhHans: "←  我的", ko: "←  내 정보"
        ),
        "←  Paramètres": .init(
            en: "←  Settings", es: "←  Ajustes", de: "←  Einstellungen", it: "←  Impostazioni", pt: "←  Ajustes",
            ar: "←  الإعدادات", ja: "←  設定", hi: "←  सेटिंग्स", zhHans: "←  设置", ko: "←  설정"
        ),
        "Paramètres": .init(
            en: "Settings", es: "Ajustes", de: "Einstellungen", it: "Impostazioni", pt: "Ajustes",
            ar: "الإعدادات", ja: "設定", hi: "सेटिंग्स", zhHans: "设置", ko: "설정"
        ),
        "Parcours & Examens": .init(
            en: "Tracks & Exams", es: "Rutas y Exámenes", de: "Lernpfade & Prüfungen", it: "Percorsi ed Esami", pt: "Trilhas e Exames",
            ar: "المسارات والاختبارات", ja: "学習コース＆模擬試験", hi: "ट्रैक और परीक्षाएं", zhHans: "学习路径与考试", ko: "학습 경로 및 모의고사"
        ),
        "Parcours actifs en parallèle": .init(
            en: "Active parallel tracks", es: "Rutas activas en paralelo", de: "Aktive parallele Lernpfade", it: "Percorsi attivi in parallelo", pt: "Trilhas ativas em paralelo",
            ar: "المسارات النشطة بالتوازي", ja: "並行学習中のコース", hi: "समानांतर सक्रिय ट्रैक", zhHans: "并行学习中的路径", ko: "동시 진행 중인 트랙"
        ),
        "Langue des cours & examens": .init(
            en: "Course & Exam Language", es: "Idioma de cursos y exámenes", de: "Sprache für Kurse & Prüfungen", it: "Lingua di corsi ed esami", pt: "Idioma dos cursos e exames",
            ar: "لغة الدورات والاختبارات", ja: "コースと試験の言語", hi: "कोर्स और परीक्षा की भाषा", zhHans: "课程与考试语言", ko: "강의 및 시험 언어"
        ),
        "Mode Examen Blanc": .init(
            en: "Mock Exam Mode", es: "Modo Examen Blanco", de: "Probeprüfungsmodus", it: "Modalità Simulazione Esame", pt: "Modo Simulado",
            ar: "وضع الاختبار التجريبي", ja: "模擬試験モード", hi: "मॉक परीक्षा मोड", zhHans: "模拟考试模式", ko: "모의고사 모드"
        ),
        "Mode Examen Blanc (Pearson)": .init(
            en: "Mock Exam Mode (Pearson)", es: "Modo Examen Blanco (Pearson)", de: "Probeprüfungsmodus (Pearson)", it: "Modalità Simulazione (Pearson)", pt: "Modo Simulado (Pearson)",
            ar: "وضع الاختبار التجريبي (Pearson)", ja: "模擬試験モード（Pearson）", hi: "मॉक परीक्षा मोड (Pearson)", zhHans: "模拟考试模式（Pearson）", ko: "모의고사 모드 (Pearson)"
        ),
        "Cours téléchargés (Hors-Ligne)": .init(
            en: "Downloaded courses (Offline)", es: "Cursos descargados (Sin conexión)", de: "Heruntergeladene Kurse (Offline)", it: "Corsi scaricati (Offline)", pt: "Cursos baixados (Offline)",
            ar: "الدورات المحملة (دون اتصال)", ja: "ダウンロード済みコース（オフライン）", hi: "डाउनलोड किए गए कोर्स (ऑफ़लाइन)", zhHans: "已下载课程（离线可用）", ko: "다운로드한 강의 (오프라인)"
        ),
        "CertiGo AI (Vocal & Écrit)": .init(
            en: "CertiGo AI (Voice & Text)", es: "CertiGo AI (Voz y Texto)", de: "CertiGo AI (Sprache & Text)", it: "CertiGo AI (Voce e Testo)", pt: "CertiGo AI (Voz e Texto)",
            ar: "مساعد CertiGo AI (صوتي ونصي)", ja: "CertiGo AI（音声＆チャット）", hi: "CertiGo AI (वॉयस और टेक्स्ट)", zhHans: "CertiGo AI（语音与文字）", ko: "CertiGo AI (음성 및 텍스트)"
        ),
        "Voix de CertiGo AI Live": .init(
            en: "CertiGo AI Live Voice", es: "Voz de CertiGo AI Live", de: "CertiGo AI Live-Stimme", it: "Voce di CertiGo AI Live", pt: "Voz do CertiGo AI Live",
            ar: "صوت CertiGo AI المباشر", ja: "CertiGo AI ライブ音声", hi: "CertiGo AI लाइव वॉयस", zhHans: "CertiGo AI 实时语音音色", ko: "CertiGo AI 라이브 음성"
        ),
        "Voix du Coach IA Live": .init(
            en: "Live AI Coach Voice", es: "Voz del Coach IA Live", de: "Live-KI-Coach-Stimme", it: "Voce del Coach IA Live", pt: "Voz do Coach IA Live",
            ar: "صوت المدرب الذكي المباشر", ja: "AIコーチのライブ音声", hi: "लाइव एआई कोच वॉयस", zhHans: "AI 教练实时音色", ko: "실시간 AI 코치 음성"
        ),
        "Style des explications": .init(
            en: "Explanation Style", es: "Estilo de las explicaciones", de: "Erklärungsstil", it: "Stile delle spiegazioni", pt: "Estilo das explicações",
            ar: "أسلوب الشرح", ja: "解説スタイル", hi: "स्पष्टीकरण शैली", zhHans: "解析风格", ko: "해설 스타일"
        ),
        "Widgets iOS 18 & Dynamic Island": .init(
            en: "iOS 18 Widgets & Dynamic Island", es: "Widgets iOS 18 y Dynamic Island", de: "iOS 18 Widgets & Dynamic Island", it: "Widget iOS 18 e Dynamic Island", pt: "Widgets iOS 18 e Dynamic Island",
            ar: "أدوات iOS 18 وDynamic Island", ja: "iOS 18 ウィジェット＆Dynamic Island", hi: "iOS 18 विजेट और Dynamic Island", zhHans: "iOS 18 小组件与灵动岛", ko: "iOS 18 위젯 및 Dynamic Island"
        ),
        "Actifs": .init(
            en: "Active", es: "Activos", de: "Aktiv", it: "Attivi", pt: "Ativos",
            ar: "مفعّل", ja: "有効", hi: "सक्रिय", zhHans: "已启用", ko: "활성"
        ),
        "Banque & Costumes de la Mascotte (Icône Dynamique)": .init(
            en: "Mascot Vault & Outfits (Dynamic Icon)", es: "Colección de la Mascota (Icono Dinámico)", de: "Maskottchen-Kostüme (Dynamisches Icon)", it: "Costumi Mascotte (Icona Dinamica)", pt: "Figurinos do Mascote (Ícone Dinâmico)",
            ar: "خزانة وأزياء التميمة (أيقونة ديناميكية)", ja: "マスコット衣装＆動的アプリアイコン", hi: "मैस्कॉट वॉल्ट और पोशाकें (डायनामिक आइकन)", zhHans: "吉祥物装扮库（动态桌面图标）", ko: "마스코트 의상 보관함 (동적 앱 아이콘)"
        ),
        "Apparence Liquid Glass, Rappels & Haptique": .init(
            en: "Liquid Glass Appearance, Reminders & Haptics", es: "Apariencia Liquid Glass, Recordatorios y Háptica", de: "Liquid Glass, Erinnerungen & Haptik", it: "Aspetto Liquid Glass, Promemoria e Feedback Aptico", pt: "Aparência Liquid Glass, Lembretes e Vibração",
            ar: "مظهر Liquid Glass والتذكيرات والاهتزاز", ja: "Liquid Glass外観・リマインダー・触覚フィードバック", hi: "लिक्विड ग्लास, रिमाइंडर और हैप्टिक्स", zhHans: "液态玻璃外观、提醒与触觉反馈", ko: "Liquid Glass 외관, 알림 및 햅틱"
        ),
        "Réfraction optique de la barre de navigation et de la goutte de sélection": .init(
            en: "Optical refraction of the navigation bar and selection droplet", es: "Refracción óptica de la barra de navegación y gota de selección", de: "Optische Lichtbrechung der Navigationsleiste und des Auswahltropfens", it: "Rifrazione ottica della barra di navigazione e della goccia di selezione", pt: "Refração óptica da barra de navegação e gota de seleção",
            ar: "انكسار بصري لشريط التنقل وقطرة الاختيار", ja: "ナビゲーションバーと選択ドロップレットの光学屈折効果", hi: "नेविगेशन बार और चयन ड्रॉपलेट का ऑप्टिकल अपवर्तन", zhHans: "底部导航栏与水滴选中态的光学折射强度", ko: "하단 내비게이션 바 및 물방울 선택 효과의 광학 굴절 강도"
        ),
        "Rappel d'entraînement (19:30)": .init(
            en: "Daily training reminder (19:30)", es: "Recordatorio de entrenamiento (19:30)", de: "Trainingserinnerung (19:30)", it: "Promemoria di allenamento (19:30)", pt: "Lembrete de treino (19:30)",
            ar: "تذكير التدريب اليومي (19:30)", ja: "毎日の学習リマインダー (19:30)", hi: "प्रशिक्षण रिमाइंडर (19:30)", zhHans: "每日学习提醒 (19:30)", ko: "일일 학습 알림 (19:30)"
        ),
        "Radar Hebdo Nouveautés IA & Tech": .init(
            en: "Weekly AI & Tech News Radar", es: "Radar Semanal de Novedades IA y Tech", de: "Wöchentlicher KI- & Tech-Radar", it: "Radar Settimanale Novità IA e Tech", pt: "Radar Semanal de Novidades IA e Tech",
            ar: "رادار أخبار الذكاء الاصطناعي والتقنية الأسبوعي", ja: "週間AI＆テック最新レーダー", hi: "साप्ताहिक एआई और टेक न्यूज़ राडार", zhHans: "每周 AI 与前沿科技雷达", ko: "주간 AI 및 테크 뉴스 레이더"
        ),
        "Retours haptiques 3D": .init(
            en: "3D Tactile Haptics", es: "Respuesta háptica 3D", de: "3D-Haptisches Feedback", it: "Feedback aptico 3D", pt: "Vibração tátil 3D",
            ar: "الاهتزاز التفاعلي ثلاثي الأبعاد", ja: "3D触覚フィードバック（ハプティクス）", hi: "3D हैप्टिक फीडबैक", zhHans: "3D 触觉振动反馈", ko: "3D 입체 햅틱 피드백"
        ),
        "Aide, Compte & Réinitialisation": .init(
            en: "Help, Account & Reset", es: "Ayuda, Cuenta y Restablecimiento", de: "Hilfe, Konto & Zurücksetzen", it: "Aiuto, Account e Ripristino", pt: "Ajuda, Conta e Redefinição",
            ar: "المساعدة والحساب وإعادة الضبط", ja: "ヘルプ・アカウント・初期化", hi: "सहायता, खाता और रीसेट", zhHans: "帮助、账户与重置", ko: "도움말, 계정 및 초기화"
        ),
        "🧭 Relancer la visite guidée": .init(
            en: "🧭 Replay Guided Tour", es: "🧭 Repetir visita guiada", de: "🧭 Geführte Tour neu starten", it: "🧭 Riavvia il tour guidato", pt: "🧭 Reiniciar tour guiado",
            ar: "🧭 إعادة الجولة التعريفية", ja: "🧭 ガイドツアーを再開", hi: "🧭 गाइडेड टूर फिर से चलाएं", zhHans: "🧭 重新开启引导之旅", ko: "🧭 가이드 투어 다시 보기"
        ),
        "5 étapes": .init(
            en: "5 steps", es: "5 etapas", de: "5 Schritte", it: "5 tappe", pt: "5 etapas",
            ar: "5 مراحل", ja: "全5ステップ", hi: "5 चरण", zhHans: "5 个步骤", ko: "5단계"
        ),
        "🔑 Portail de connexion / Changer de compte": .init(
            en: "🔑 Sign-In Portal / Switch Account", es: "🔑 Portal de acceso / Cambiar cuenta", de: "🔑 Anmeldeportal / Konto wechseln", it: "🔑 Portale d'accesso / Cambia account", pt: "🔑 Portal de login / Trocar conta",
            ar: "🔑 بوابة الدخول / تبديل الحساب", ja: "🔑 ログインポータル / アカウント切替", hi: "🔑 साइन-इन पोर्टल / खाता बदलें", zhHans: "🔑 登录门户 / 切换账户", ko: "🔑 로그인 포털 / 계정 전환"
        ),
        "Se connecter": .init(
            en: "Sign in", es: "Iniciar sesión", de: "Anmelden", it: "Accedi", pt: "Entrar",
            ar: "تسجيل الدخول", ja: "ログイン", hi: "साइन इन", zhHans: "去登录", ko: "로그인"
        ),
        "🔄 Revoir l'accueil & l'Onboarding": .init(
            en: "🔄 Replay Welcome & Onboarding", es: "🔄 Volver a ver el Onboarding", de: "🔄 Onboarding erneut starten", it: "🔄 Rivedi l'Onboarding iniziale", pt: "🔄 Rever boas-vindas e Onboarding",
            ar: "🔄 إعادة شاشة الترحيب والإعداد", ja: "🔄 初期オンボーディングをやり直す", hi: "🔄 ऑनबोर्डिंग फिर से देखें", zhHans: "🔄 重新体验新手指引", ko: "🔄 온보딩 처음부터 다시 보기"
        ),
        "🚪 Se déconnecter de mon compte": .init(
            en: "🚪 Sign out of my account", es: "🚪 Cerrar sesión", de: "🚪 Vom Konto abmelden", it: "🚪 Esci dal mio account", pt: "🚪 Sair da minha conta",
            ar: "🚪 تسجيل الخروج من حسابي", ja: "🚪 ログアウト", hi: "🚪 मेरे खाते से साइन आउट करें", zhHans: "🚪 退出当前账户", ko: "🚪 로그아웃"
        ),
        "🗑️ Supprimer mon compte et mes données": .init(
            en: "🗑️ Delete my account and data", es: "🗑️ Eliminar mi cuenta y mis datos", de: "🗑️ Mein Konto und meine Daten löschen", it: "🗑️ Elimina il mio account e i dati", pt: "🗑️ Excluir minha conta e meus dados",
            ar: "🗑️ حذف حسابي وبياناتي", ja: "🗑️ アカウントと全データを削除", hi: "🗑️ मेरा खाता और डेटा हटाएं", zhHans: "🗑️ 删除我的账户与所有数据", ko: "🗑️ 내 계정 및 데이터 삭제"
        ),
        "🧹 Réinitialiser en nouvel utilisateur (0 donnée)": .init(
            en: "🧹 Reset as fresh new user (0 data)", es: "🧹 Restablecer como usuario nuevo (0 datos)", de: "🧹 Als neuer Nutzer zurücksetzen (0 Daten)", it: "🧹 Ripristina come nuovo utente (0 dati)", pt: "🧹 Redefinir como novo usuário (0 dados)",
            ar: "🧹 إعادة الضبط كمستخدم جديد", ja: "🧹 新規ユーザー状態にリセット（データ消去）", hi: "🧹 नए उपयोगकर्ता के रूप में रीसेट करें", zhHans: "🧹 重置为全新用户状态（清空数据）", ko: "🧹 신규 사용자 상태로 초기화 (데이터 0)"
        ),
        "PRÉFÉRENCE CERTIGO": .init(
            en: "CERTIGO PREFERENCE", es: "PREFERENCIA CERTIGO", de: "CERTIGO-EINSTELLUNG", it: "PREFERENZA CERTIGO", pt: "PREFERÊNCIA CERTIGO",
            ar: "تفضيلات CERTIGO", ja: "CERTIGO 設定", hi: "CERTIGO प्राथमिकता", zhHans: "CERTIGO 偏好设置", ko: "CERTIGO 환경설정"
        ),
        "ENREGISTRER MON PROFIL ✓": .init(
            en: "SAVE MY PROFILE ✓", es: "GUARDAR MI PERFIL ✓", de: "MEIN PROFIL SPEICHERN ✓", it: "SALVA IL MIO PROFILO ✓", pt: "SALVAR MEU PERFIL ✓",
            ar: "حفظ ملفي الشخصي ✓", ja: "プロフィールを保存 ✓", hi: "मेरी प्रोफ़ाइल सहेजें ✓", zhHans: "保存个人资料 ✓", ko: "내 프로필 저장 ✓"
        )
    ]

    // MARK: - 4. Parameterized Dynamic String Translator (`translateParameterizedPattern`)

    private static func translateParameterizedPattern(
        _ text: String,
        language: CertiGoSupportedLanguage
    ) -> String? {
        // 1. "UNITÉ X · <Title>"
        if text.hasPrefix("UNITÉ ") {
            let rest = String(text.dropFirst("UNITÉ ".count))
            let parts = rest.components(separatedBy: " · ")
            if let unitNum = parts.first {
                let tail = parts.dropFirst().joined(separator: " · ")
                let translatedTail = tail.isEmpty ? "" : " · \(tr(tail, language: language))"
                switch language {
                case .frBilingual, .frFull: return "UNITÉ \(unitNum)\(translatedTail)"
                case .en: return "UNIT \(unitNum)\(translatedTail)"
                case .es: return "UNIDAD \(unitNum)\(translatedTail)"
                case .de: return "EINHEIT \(unitNum)\(translatedTail)"
                case .it: return "UNITÀ \(unitNum)\(translatedTail)"
                case .pt: return "UNIDADE \(unitNum)\(translatedTail)"
                case .ar: return "الوحدة \(unitNum)\(translatedTail)"
                case .ja: return "ユニット \(unitNum)\(translatedTail)"
                case .hi: return "यूनिट \(unitNum)\(translatedTail)"
                case .zhHans: return "第 \(unitNum) 单元\(translatedTail)"
                case .ko: return "유닛 \(unitNum)\(translatedTail)"
                }
            }
        }

        // 2. "Page X sur Y"
        if text.hasPrefix("Page "), text.contains(" sur ") {
            let nums = text.replacingOccurrences(of: "Page ", with: "").components(separatedBy: " sur ")
            if nums.count == 2 {
                let x = nums[0], y = nums[1]
                switch language {
                case .frBilingual, .frFull: return text
                case .en: return "Page \(x) of \(y)"
                case .es: return "Página \(x) de \(y)"
                case .de: return "Seite \(x) von \(y)"
                case .it: return "Pagina \(x) di \(y)"
                case .pt: return "Página \(x) de \(y)"
                case .ar: return "صفحة \(x) من \(y)"
                case .ja: return "\(x) / \(y) ページ"
                case .hi: return "पृष्ठ \(x) / \(y)"
                case .zhHans: return "第 \(x) / \(y) 页"
                case .ko: return "\(x) / \(y) 페이지"
                }
            }
        }

        // 3. "CONTINUER (X/Y) →"
        if text.hasPrefix("CONTINUER ("), text.hasSuffix(") →") {
            let inner = text.replacingOccurrences(of: "CONTINUER (", with: "").replacingOccurrences(of: ") →", with: "")
            if inner.contains("/") {
                switch language {
                case .frBilingual, .frFull: return text
                case .en: return "CONTINUE (\(inner)) →"
                case .es: return "CONTINUAR (\(inner)) →"
                case .de: return "WEITER (\(inner)) →"
                case .it: return "CONTINUA (\(inner)) →"
                case .pt: return "CONTINUAR (\(inner)) →"
                case .ar: return "متابعة (\(inner)) ←"
                case .ja: return "次へ (\(inner)) →"
                case .hi: return "जारी रखें (\(inner)) →"
                case .zhHans: return "继续 (\(inner)) →"
                case .ko: return "계속 (\(inner)) →"
                }
            }
        }

        // 4. "CONTINUER (X OBJECTIF(S) CHOISI(S))"
        if text.hasPrefix("CONTINUER ("), text.contains("OBJECTIF") {
            let digits = text.filter(\.isNumber)
            let n = digits.isEmpty ? "1" : digits
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return n == "1" ? "CONTINUE (1 GOAL SELECTED)" : "CONTINUE (\(n) GOALS SELECTED)"
            case .es: return n == "1" ? "CONTINUAR (1 OBJETIVO ELEGIDO)" : "CONTINUAR (\(n) OBJETIVOS ELEGIDOS)"
            case .de: return n == "1" ? "WEITER (1 ZIEL GEWÄHLT)" : "WEITER (\(n) ZIELE GEWÄHLT)"
            case .it: return n == "1" ? "CONTINUA (1 OBIETTIVO SCELTO)" : "CONTINUA (\(n) OBIETTIVI SCELTI)"
            case .pt: return n == "1" ? "CONTINUAR (1 META ESCOLHIDA)" : "CONTINUAR (\(n) METAS ESCOLHIDAS)"
            case .ar: return "متابعة (\(n) أهداف مختارة)"
            case .ja: return "続ける（\(n)個の目標を選択中）"
            case .hi: return "जारी रखें (\(n) लक्ष्य चुने गए)"
            case .zhHans: return "继续（已选 \(n) 个目标）"
            case .ko: return "계속하기 (목표 \(n)개 선택됨)"
            }
        }

        // 5. "SUIVRE CE PARCOURS →" / "SUIVRE CES X PARCOURS →"
        if text.hasPrefix("SUIVRE "), text.hasSuffix("PARCOURS →") {
            let digits = text.filter(\.isNumber)
            let n = digits.isEmpty ? "1" : digits
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return n == "1" ? "FOLLOW THIS TRACK →" : "FOLLOW THESE \(n) TRACKS →"
            case .es: return n == "1" ? "SEGUIR ESTA RUTA →" : "SEGUIR ESTAS \(n) RUTAS →"
            case .de: return n == "1" ? "DIESEM PFAD FOLGEN →" : "DIESEN \(n) PFADEN FOLGEN →"
            case .it: return n == "1" ? "SEGUI QUESTO PERCORSO →" : "SEGUI QUESTI \(n) PERCORSI →"
            case .pt: return n == "1" ? "SEGUIR ESTA TRILHA →" : "SEGUIR ESTAS \(n) TRILHAS →"
            case .ar: return "متابعة المسار المختار (\(n)) ←"
            case .ja: return "選択した\(n)コースを学習する →"
            case .hi: return "इस ट्रैक को फॉलो करें (\(n)) →"
            case .zhHans: return "开始学习所选的 \(n) 条路径 →"
            case .ko: return "선택한 \(n)개 트랙 시작하기 →"
            }
        }

        // 6. "X min / jour"
        if text.hasSuffix(" min / jour") {
            let mins = text.replacingOccurrences(of: " min / jour", with: "")
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "\(mins) min / day"
            case .es: return "\(mins) min / día"
            case .de: return "\(mins) Min. / Tag"
            case .it: return "\(mins) min / giorno"
            case .pt: return "\(mins) min / dia"
            case .ar: return "\(mins) دقيقة / يوم"
            case .ja: return "1日 \(mins)分"
            case .hi: return "\(mins) मिनट / दिन"
            case .zhHans: return "每天 \(mins) 分钟"
            case .ko: return "하루 \(mins)분"
            }
        }

        // 7. "▶ Lancer le sprint (X min)"
        if text.hasPrefix("▶ Lancer le sprint ("), text.hasSuffix(" min)") {
            let mins = text.replacingOccurrences(of: "▶ Lancer le sprint (", with: "").replacingOccurrences(of: " min)", with: "")
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "▶ Start sprint (\(mins) min)"
            case .es: return "▶ Iniciar sprint (\(mins) min)"
            case .de: return "▶ Sprint starten (\(mins) Min.)"
            case .it: return "▶ Avvia sprint (\(mins) min)"
            case .pt: return "▶ Iniciar sprint (\(mins) min)"
            case .ar: return "▶ ابدأ التدريب السريع (\(mins) د)"
            case .ja: return "▶ スプリントを開始 (\(mins)分)"
            case .hi: return "▶ स्प्रिंट शुरू करें (\(mins) मिनट)"
            case .zhHans: return "▶ 开始冲刺 (\(mins) 分钟)"
            case .ko: return "▶ 스프린트 시작 (\(mins)분)"
            }
        }

        // 8. "Coach IA · <Code>"
        if text.hasPrefix("Coach IA · ") {
            let code = String(text.dropFirst("Coach IA · ".count))
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "AI Coach · \(code)"
            case .es: return "Coach IA · \(code)"
            case .de: return "KI-Coach · \(code)"
            case .it: return "Coach IA · \(code)"
            case .pt: return "Coach IA · \(code)"
            case .ar: return "المدرب الذكي · \(code)"
            case .ja: return "AIコーチ · \(code)"
            case .hi: return "एआई कोच · \(code)"
            case .zhHans: return "AI 教练 · \(code)"
            case .ko: return "AI 코치 · \(code)"
            }
        }

        // 9. "MES AMIS (X)"
        if text.hasPrefix("MES AMIS ("), text.hasSuffix(")") {
            let count = text.replacingOccurrences(of: "MES AMIS (", with: "").replacingOccurrences(of: ")", with: "")
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "MY FRIENDS (\(count))"
            case .es: return "MIS AMIGOS (\(count))"
            case .de: return "MEINE FREUNDE (\(count))"
            case .it: return "I MIEI AMICI (\(count))"
            case .pt: return "MEUS AMIGOS (\(count))"
            case .ar: return "أصدقائي (\(count))"
            case .ja: return "友達 (\(count))"
            case .hi: return "मेरे दोस्त (\(count))"
            case .zhHans: return "我的好友 (\(count))"
            case .ko: return "내 친구 (\(count))"
            }
        }

        // 10. "💧 Effet Liquid Glass · X%"
        if text.hasPrefix("💧 Effet Liquid Glass · ") {
            let pct = String(text.dropFirst("💧 Effet Liquid Glass · ".count))
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "💧 Liquid Glass Effect · \(pct)"
            case .es: return "💧 Efecto Liquid Glass · \(pct)"
            case .de: return "💧 Liquid-Glass-Effekt · \(pct)"
            case .it: return "💧 Effetto Liquid Glass · \(pct)"
            case .pt: return "💧 Efeito Liquid Glass · \(pct)"
            case .ar: return "💧 تأثير Liquid Glass · \(pct)"
            case .ja: return "💧 Liquid Glass 効果 · \(pct)"
            case .hi: return "💧 लिक्विड ग्लास प्रभाव · \(pct)"
            case .zhHans: return "💧 液态玻璃折射强度 · \(pct)"
            case .ko: return "💧 Liquid Glass 효과 · \(pct)"
            }
        }

        // 11. "Niv. X/Y"
        if text.hasPrefix("Niv. ") {
            let ratio = String(text.dropFirst("Niv. ".count))
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "Lvl \(ratio)"
            case .es: return "Niv. \(ratio)"
            case .de: return "Stufe \(ratio)"
            case .it: return "Liv. \(ratio)"
            case .pt: return "Nív. \(ratio)"
            case .ar: return "مستوى \(ratio)"
            case .ja: return "Lv.\(ratio)"
            case .hi: return "स्तर \(ratio)"
            case .zhHans: return "等级 \(ratio)"
            case .ko: return "레벨 \(ratio)"
            }
        }

        // 12. "📋 Grille (X)"
        if text.hasPrefix("📋 Grille ("), text.hasSuffix(")") {
            let count = text.replacingOccurrences(of: "📋 Grille (", with: "").replacingOccurrences(of: ")", with: "")
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "📋 Grid (\(count))"
            case .es: return "📋 Cuadrícula (\(count))"
            case .de: return "📋 Übersicht (\(count))"
            case .it: return "📋 Griglia (\(count))"
            case .pt: return "📋 Grade (\(count))"
            case .ar: return "📋 الشبكة (\(count))"
            case .ja: return "📋 問題一覧 (\(count))"
            case .hi: return "📋 ग्रिड (\(count))"
            case .zhHans: return "📋 题卡 (\(count))"
            case .ko: return "📋 문제 목록 (\(count))"
            }
        }

        // 13. "Dernier score : X/1000 ✓"
        if text.hasPrefix("Dernier score : ") {
            let score = String(text.dropFirst("Dernier score : ".count))
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "Last score: \(score)"
            case .es: return "Última puntuación: \(score)"
            case .de: return "Letztes Ergebnis: \(score)"
            case .it: return "Ultimo punteggio: \(score)"
            case .pt: return "Última pontuação: \(score)"
            case .ar: return "آخر نتيجة: \(score)"
            case .ja: return "前回スコア: \(score)"
            case .hi: return "अंतिम स्कोर: \(score)"
            case .zhHans: return "最近得分: \(score)"
            case .ko: return "최근 점수: \(score)"
            }
        }

        // 14. Expanded 10-step Unit Node prefixes:
        // "Diagnostic · X", "Architecture · X", "Lab Pratique · X", "Révision Ciblée · Unité X", "Boss d'Unité X · Y"
        if text.hasPrefix("Diagnostic · ") {
            let sub = tr(String(text.dropFirst("Diagnostic · ".count)), language: language)
            switch language {
            case .frBilingual, .frFull: return "Diagnostic · \(sub)"
            case .en: return "Diagnostics · \(sub)"
            case .es: return "Diagnóstico · \(sub)"
            case .de: return "Diagnose · \(sub)"
            case .it: return "Diagnostica · \(sub)"
            case .pt: return "Diagnóstico · \(sub)"
            case .ar: return "تشخيص · \(sub)"
            case .ja: return "トラブル診断 · \(sub)"
            case .hi: return "डायग्नोस्टिक्स · \(sub)"
            case .zhHans: return "故障诊断 · \(sub)"
            case .ko: return "진단 · \(sub)"
            }
        }
        if text.hasPrefix("Architecture · ") {
            let sub = tr(String(text.dropFirst("Architecture · ".count)), language: language)
            switch language {
            case .frBilingual, .frFull: return "Architecture · \(sub)"
            case .en: return "Architecture · \(sub)"
            case .es: return "Arquitectura · \(sub)"
            case .de: return "Architektur · \(sub)"
            case .it: return "Architettura · \(sub)"
            case .pt: return "Arquitetura · \(sub)"
            case .ar: return "هندسة معمارية · \(sub)"
            case .ja: return "アーキテクチャ設計 · \(sub)"
            case .hi: return "आर्किटेक्चर · \(sub)"
            case .zhHans: return "架构设计 · \(sub)"
            case .ko: return "아키텍처 · \(sub)"
            }
        }
        if text.hasPrefix("Lab Pratique · ") {
            let sub = tr(String(text.dropFirst("Lab Pratique · ".count)), language: language)
            switch language {
            case .frBilingual, .frFull: return "Lab Pratique · \(sub)"
            case .en: return "Hands-On Lab · \(sub)"
            case .es: return "Lab Práctico · \(sub)"
            case .de: return "Praxis-Lab · \(sub)"
            case .it: return "Lab Pratico · \(sub)"
            case .pt: return "Lab Prático · \(sub)"
            case .ar: return "مختبر عملي · \(sub)"
            case .ja: return "実践ラボ · \(sub)"
            case .hi: return "प्रैक्टिकल लैब · \(sub)"
            case .zhHans: return "实战实验 · \(sub)"
            case .ko: return "실전 랩 · \(sub)"
            }
        }
        if text.hasPrefix("Révision Ciblée · Unité ") {
            let uNum = String(text.dropFirst("Révision Ciblée · Unité ".count))
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "Targeted Review · Unit \(uNum)"
            case .es: return "Repaso Focalizado · Unidad \(uNum)"
            case .de: return "Gezielter Rückblick · Einheit \(uNum)"
            case .it: return "Ripasso Mirato · Unità \(uNum)"
            case .pt: return "Revisão Focada · Unidade \(uNum)"
            case .ar: return "مراجعة مركزة · الوحدة \(uNum)"
            case .ja: return "重点復習 · ユニット \(uNum)"
            case .hi: return "लक्षित रिवीजन · यूनिट \(uNum)"
            case .zhHans: return "专项复习 · 第 \(uNum) 单元"
            case .ko: return "집중 복습 · 유닛 \(uNum)"
            }
        }
        if text.hasPrefix("Boss d'Unité ") {
            let rest = String(text.dropFirst("Boss d'Unité ".count))
            switch language {
            case .frBilingual, .frFull: return text
            case .en: return "Unit Boss \(rest)"
            case .es: return "Jefe de Unidad \(rest)"
            case .de: return "Einheits-Boss \(rest)"
            case .it: return "Boss dell'Unità \(rest)"
            case .pt: return "Chefe da Unidade \(rest)"
            case .ar: return "تحدي الوحدة \(rest)"
            case .ja: return "ユニットボス \(rest)"
            case .hi: return "यूनिट बॉस \(rest)"
            case .zhHans: return "单元 Boss 挑战 \(rest)"
            case .ko: return "유닛 보스 \(rest)"
            }
        }

        return nil
    }

    // MARK: - 5. Integral French Terminology Adapter (`langIndex == 1`)

    private static func applyIntegralFrenchTerminology(_ text: String) -> String {
        var out = text
        let replacements: [(String, String)] = [
            ("Private Endpoint", "Point de terminaison privé"),
            ("Service Endpoint", "Point de terminaison de service"),
            ("Load Balancer", "Équilibreur de charge"),
            ("Application Gateway", "Passerelle applicative"),
            ("Availability Zones", "Zones de disponibilité"),
            ("Region Pairs", "Paires de régions"),
            ("Scale Sets", "Groupes identiques"),
            ("Key Vault", "Coffre de clés"),
            ("Recovery Services Vault", "Coffre Recovery Services"),
            ("Storage Account", "Compte de stockage"),
            ("Lifecycle Management", "Gestion du cycle de vie"),
            ("Soft Delete", "Suppression réversible"),
            ("Cross-Region Restore", "Restauration inter-régions"),
            ("Prompt Caching", "Mise en cache de prompt"),
            ("Hybrid Search", "Recherche hybride"),
            ("Semantic Ranker", "Classeur sémantique"),
            ("Prompt Shields", "Boucliers de prompt"),
            ("Workload Identity", "Identité de charge de travail")
        ]
        for (enTerm, frTerm) in replacements {
            out = out.replacingOccurrences(of: enTerm, with: frTerm)
        }
        return out
    }

    // MARK: - 6. High-Coverage Multi-Pass Compositional Translator (Units, Micro-Slides, Déclic Cards, Exercises & Mock Exams)

    private static func translateCompositionalText(
        _ text: String,
        language: CertiGoSupportedLanguage
    ) -> String {
        var result = text

        // Pass 1: Curated French->Target phrase, sentence-starter & pedagogical clause replacements
        for rule in phraseRules {
            if result.contains(rule.fr) {
                result = result.replacingOccurrences(of: rule.fr, with: rule.replacement(for: language))
            }
        }

        // Pass 2: Word-boundary & connector lexicon replacements so zero French glue words remain
        for lex in wordLexiconRules {
            result = replacingWordOrPhrase(in: result, target: lex.fr, with: lex.replacement(for: language))
        }

        return result
    }

    private static func replacingWordOrPhrase(in source: String, target: String, with replacement: String) -> String {
        guard source.range(of: target, options: .caseInsensitive) != nil else { return source }
        let escaped = NSRegularExpression.escapedPattern(for: target)
        let pattern = "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return source.replacingOccurrences(of: target, with: replacement)
        }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.stringByReplacingMatches(in: source, options: [], range: nsRange, withTemplate: replacement)
    }

    private struct PhraseTranslationRule: Sendable {
        let fr: String
        let en: String
        let es: String
        let de: String
        let it: String
        let pt: String
        let ar: String
        let ja: String
        let hi: String
        let zhHans: String
        let ko: String

        init(
            fr: String,
            en: String,
            es: String,
            de: String,
            it: String,
            pt: String? = nil,
            ar: String? = nil,
            ja: String? = nil,
            hi: String? = nil,
            zhHans: String? = nil,
            ko: String? = nil
        ) {
            self.fr = fr
            self.en = en
            self.es = es
            self.de = de
            self.it = it
            self.pt = pt ?? es
            self.ar = ar ?? en
            self.ja = ja ?? en
            self.hi = hi ?? en
            self.zhHans = zhHans ?? en
            self.ko = ko ?? en
        }

        func replacement(for language: CertiGoSupportedLanguage) -> String {
            switch language {
            case .frBilingual, .frFull: return fr
            case .en: return en
            case .es: return es
            case .de: return de
            case .it: return it
            case .pt: return pt
            case .ar: return ar
            case .ja: return ja
            case .hi: return hi
            case .zhHans: return zhHans
            case .ko: return ko
            }
        }
    }

    private static let phraseRules: [PhraseTranslationRule] = [
        // Step & Slide badges
        .init(fr: "VUE D'ENSEMBLE · TA MISSION", en: "OVERVIEW · YOUR MISSION", es: "VISTA GENERAL · TU MISIÓN", de: "ÜBERBLICK · DEINE MISSION", it: "PANORAMICA · LA TUA MISSIONE", pt: "VISÃO GERAL · SUA MISSÃO", ar: "نظرة عامة · مهمتك", ja: "全体像 · あなたのミッション", hi: "अवलोकन · आपका मिशन", zhHans: "全景概览 · 核心目标", ko: "전체 개요 · 핵심 미션"),
        .init(fr: "LA GRANDE IMAGE · EN 3 BRIQUES", en: "THE BIG PICTURE · IN 3 BRICKS", es: "LA GRAN IMAGEN · EN 3 BLOQUES", de: "DAS GROSSE BILD · IN 3 BAUSTEINEN", it: "IL QUADRO GENERALE · IN 3 BLOCCHI", pt: "A VISÃO GERAL · EM 3 BLOCOS", ar: "الصورة الكبرى · في 3 ركائز", ja: "全体アーキテクチャ · 3つの柱", hi: "बड़ी तस्वीर · 3 मुख्य स्तंभ", zhHans: "核心架构 · 三大支柱", ko: "핵심 아키텍처 · 3대 구성요소"),
        .init(fr: "3/3 · MOTS-CLÉS ESSENTIELS", en: "3/3 · ESSENTIAL KEYWORDS", es: "3/3 · PALABRAS CLAVE ESENCIALES", de: "3/3 · WICHTIGE SCHLÜSSELBEGRIFFE", it: "3/3 · PAROLE CHIAVE ESSENZIALI", pt: "3/3 · PALAVRAS-CHAVE ESSENCIAIS", ar: "3/3 · المصطلحات الأساسية", ja: "3/3 · 必須キーワード", hi: "3/3 · आवश्यक कीवर्ड", zhHans: "3/3 · 必背核心术语", ko: "3/3 · 필수 핵심 키워드"),
        .init(fr: "NOTION 1/3 · CONCEPT CLÉ", en: "CONCEPT 1/3 · KEY IDEA", es: "NOCIÓN 1/3 · CONCEPTO CLAVE", de: "KONZEPT 1/3 · KERNIDEE", it: "NOZIONE 1/3 · CONCETTO CHIAVE", pt: "NOÇÃO 1/3 · CONCEITO-CHAVE", ar: "مفهوم 1/3 · الفكرة الأساسية", ja: "ポイント 1/3 · 基本概念", hi: "अवधारणा 1/3 · मुख्य सिद्धांत", zhHans: "要点 1/3 · 核心概念", ko: "핵심 1/3 · 주요 개념"),
        .init(fr: "NOTION 1/3 · L'ESSENTIEL", en: "CONCEPT 1/3 · THE ESSENTIALS", es: "NOCIÓN 1/3 · LO ESENCIAL", de: "KONZEPT 1/3 · DAS WESENTLICHE", it: "NOZIONE 1/3 · L'ESSENZIALE", pt: "NOÇÃO 1/3 · O ESSENCIAL", ar: "مفهوم 1/3 · الأساسيات", ja: "ポイント 1/3 · 要点", hi: "अवधारणा 1/3 · मुख्य बातें", zhHans: "要点 1/3 · 核心精髓", ko: "핵심 1/3 · 필수 요약"),
        .init(fr: "NOTION 2/3 · ARCHITECTURE & MÉCANISME", en: "CONCEPT 2/3 · ARCHITECTURE & MECHANISM", es: "NOCIÓN 2/3 · ARQUITECTURA Y MECANISMO", de: "KONZEPT 2/3 · ARCHITEKTUR & MECHANISMUS", it: "NOZIONE 2/3 · ARCHITETTURA E MECCANISMO", pt: "NOÇÃO 2/3 · ARQUITETURA E MECANISMO", ar: "مفهوم 2/3 · المعمارية والآلية", ja: "ポイント 2/3 · アーキテクチャと仕組み", hi: "अवधारणा 2/3 · आर्किटेक्चर और तंत्र", zhHans: "要点 2/3 · 架构与机制", ko: "핵심 2/3 · 아키텍처 및 작동 원리"),
        .init(fr: "NOTION 3/3 · CAS PRATIQUE", en: "CONCEPT 3/3 · PRACTICAL CASE", es: "NOCIÓN 3/3 · CASO PRÁCTICO", de: "KONZEPT 3/3 · PRAXISFALL", it: "NOZIONE 3/3 · CASO PRATICO", pt: "NOÇÃO 3/3 · CASO PRÁTICO", ar: "مفهوم 3/3 · حالة عملية", ja: "ポイント 3/3 · 実践ケース", hi: "अवधारणा 3/3 · व्यावहारिक केस", zhHans: "要点 3/3 · 实战案例", ko: "핵심 3/3 · 실전 사례"),
        .init(fr: "NOTION 3/3 · RÉFLEXE D'EXAMEN", en: "CONCEPT 3/3 · EXAM REFLEX", es: "NOCIÓN 3/3 · REFLEJO DE EXAMEN", de: "KONZEPT 3/3 · PRÜFUNGSREFLEX", it: "NOZIONE 3/3 · RIFLESSO D'ESAME", pt: "NOÇÃO 3/3 · REFLEXO DE EXAME", ar: "مفهوم 3/3 · قاعدة الاختبار", ja: "ポイント 3/3 · 試験の鉄則", hi: "अवधारणा 3/3 · परीक्षा नियम", zhHans: "要点 3/3 · 考试秒杀法则", ko: "핵심 3/3 · 시험 핵심 포인트"),
        .init(fr: "ÉTAPE 1/3 · LE PROBLÈME", en: "STEP 1/3 · THE PROBLEM", es: "PASO 1/3 · EL PROBLEMA", de: "SCHRITT 1/3 · DAS PROBLEM", it: "FASE 1/3 · IL PROBLEMA", pt: "PASSO 1/3 · O PROBLEMA", ar: "خطوة 1/3 · المشكلة", ja: "ステップ 1/3 · 課題", hi: "चरण 1/3 · समस्या", zhHans: "步骤 1/3 · 核心痛点", ko: "단계 1/3 · 문제 상황"),
        .init(fr: "ÉTAPE 2/3 · L'ARCHITECTURE", en: "STEP 2/3 · THE ARCHITECTURE", es: "PASO 2/3 · LA ARQUITECTURA", de: "SCHRITT 2/3 · DIE ARCHITEKTUR", it: "FASE 2/3 · L'ARCHITETTURA", pt: "PASSO 2/3 · A ARQUITETURA", ar: "خطوة 2/3 · المعمارية", ja: "ステップ 2/3 · アーキテクチャ", hi: "चरण 2/3 · आर्किटेक्चर", zhHans: "步骤 2/3 · 架构方案", ko: "단계 2/3 · 아키텍처"),
        .init(fr: "ÉTAPE 3/3 · RÉFLEXE D'EXAMEN", en: "STEP 3/3 · EXAM REFLEX", es: "PASO 3/3 · REFLEJO DE EXAMEN", de: "SCHRITT 3/3 · PRÜFUNGSREFLEX", it: "FASE 3/3 · RIFLESSO D'ESAME", pt: "PASSO 3/3 · REFLEXO DE EXAME", ar: "خطوة 3/3 · قاعدة الاختبار", ja: "ステップ 3/3 · 試験の鉄則", hi: "चरण 3/3 · परीक्षा नियम", zhHans: "步骤 3/3 · 考试秒杀法则", ko: "단계 3/3 · 시험 핵심 포인트"),
        .init(fr: "ÉTUDE DE CAS", en: "CASE STUDY", es: "ESTUDIO DE CASO", de: "FALLSTUDIE", it: "CASO DI STUDIO", pt: "ESTUDO DE CASO", ar: "دراسة حالة", ja: "ケーススタディ", hi: "केस स्टडी", zhHans: "案例分析", ko: "케이스 스터디"),
        .init(fr: "Règle d'or", en: "Golden rule", es: "Regla de oro", de: "Goldene Regel", it: "Regola d'oro", pt: "Regra de ouro", ar: "القاعدة الذهبية", ja: "ゴールデンルール", hi: "सुनहरा नियम", zhHans: "黄金法则", ko: "핵심 규칙"),
        .init(fr: "Piège d'examen", en: "Exam trap", es: "Trampa de examen", de: "Prüfungsfalle", it: "Trappola d'esame", pt: "Pegadinha de exame", ar: "فخ الاختبار", ja: "試験のひっかけ", hi: "परीक्षा ट्रैप", zhHans: "考试陷阱", ko: "시험 함정"),
        .init(fr: "Poids officiel :", en: "Official weight:", es: "Peso oficial:", de: "Offizielle Gewichtung:", it: "Peso ufficiale:", pt: "Peso oficial:", ar: "الوزن الرسمي:", ja: "公式出題比率:", hi: "आधिकारिक भार:", zhHans: "官方权重:", ko: "공식 비중:"),
        .init(fr: "À cibler", en: "Focus area", es: "Prioritario", de: "Fokusbereich", it: "Da potenziare", pt: "Prioritário", ar: "للتركيز", ja: "重点強化", hi: "प्राथमिकता", zhHans: "重点突破", ko: "집중 공략"),

        // Question directives & stems
        .init(fr: "Que configurez-vous ?", en: "What do you configure?", es: "¿Qué configuras?", de: "Was konfigurierst du?", it: "Cosa configuri?", pt: "O que você configura?", ar: "ماذا تقوم بإعداده؟", ja: "どの構成を設定しますか？", hi: "आप क्या कॉन्फ़िगर करते हैं?", zhHans: "您应当如何配置？", ko: "무엇을 구성해야 합니까?"),
        .init(fr: "Quelle fonctionnalité déployez-vous ?", en: "Which feature do you deploy?", es: "¿Qué funcionalidad despliegas?", de: "Welche Funktion stellst du bereit?", it: "Quale funzionalità distribuisci?", pt: "Qual recurso você implanta?", ar: "ما الميزة التي تقوم بنشرها؟", ja: "どの機能をデプロイしますか？", hi: "आप कौन सी सुविधा डिप्लॉय करते हैं?", zhHans: "您应当部署哪项功能？", ko: "어떤 기능을 배포해야 합니까?"),
        .init(fr: "Quels paramètres activez-vous ?", en: "Which settings do you enable?", es: "¿Qué parámetros activas?", de: "Welche Einstellungen aktivierst du?", it: "Quali parametri attivi?", pt: "Quais parâmetros você ativa?", ar: "ما الإعدادات التي تفعلها؟", ja: "どの設定を有効にしますか？", hi: "आप कौन सी सेटिंग्स सक्रिय करते हैं?", zhHans: "您应当启用哪些参数？", ko: "어떤 설정을 활성화해야 합니까?"),
        .init(fr: "Quelle architecture déployez-vous ?", en: "Which architecture do you deploy?", es: "¿Qué arquitectura despliegas?", de: "Welche Architektur stellst du bereit?", it: "Quale architettura distribuisci?", pt: "Qual arquitetura você implanta?", ar: "ما المعمارية التي تنشرها؟", ja: "どのアーキテクチャを採用しますか？", hi: "आप कौन सा आर्किटेक्चर डिप्लॉय करते हैं?", zhHans: "您应当部署哪种架构？", ko: "어떤 아키텍처를 배포해야 합니까?"),
        .init(fr: "Quelle architecture choisissez-vous ?", en: "Which architecture do you choose?", es: "¿Qué arquitectura eliges?", de: "Welche Architektur wählst du?", it: "Quale architettura scegli?", pt: "Qual arquitetura você escolhe?", ar: "ما المعمارية التي تختارها؟", ja: "どのアーキテクチャを選択しますか？", hi: "आप कौन सा आर्किटेक्चर चुनते हैं?", zhHans: "您选择哪种架构？", ko: "어떤 아키텍처를 선택하시겠습니까?"),
        .init(fr: "Quelle redondance choisissez-vous ?", en: "Which redundancy option do you choose?", es: "¿Qué redundancia eliges?", de: "Welche Redundanz wählst du?", it: "Quale ridondanza scegli?", pt: "Qual redundância você escolhe?", ar: "أي خيار تكرار تختار؟", ja: "どの冗長성オプションを選択しますか？", hi: "आप कौन सा रिडंडेंसी विकल्प चुनते हैं?", zhHans: "您选择哪种冗余级别？", ko: "어떤 중복성 옵션을 선택하시겠습니까?"),
        .init(fr: "Quel composant activez-vous ?", en: "Which component do you enable?", es: "¿Qué componente activas?", de: "Welche Komponente aktivierst du?", it: "Quale componente attivi?", pt: "Qual componente você ativa?", ar: "أي مكوّن تفعل؟", ja: "どのコンポーネントを有効化しますか？", hi: "आप कौन सा घटक सक्रिय करते हैं?", zhHans: "您应当启用哪个组件？", ko: "어떤 구성 요소를 활성화합니까?"),
        .init(fr: "Quelle configuration est requise ?", en: "Which configuration is required?", es: "¿Qué configuración se requiere?", de: "Welche Konfiguration ist erforderlich?", it: "Quale configurazione è richiesta?", pt: "Qual configuração é necessária?", ar: "ما الإعداد المطلوب؟", ja: "どの構成が必要ですか？", hi: "कौन सा कॉन्फ़िगरेशन आवश्यक है?", zhHans: "需要哪种配置？", ko: "어떤 구성이 필요합니까?"),
        .init(fr: "Quelle configuration activez-vous ?", en: "Which configuration do you enable?", es: "¿Qué configuración activas?", de: "Welche Konfiguration aktivierst du?", it: "Quale configurazione attivi?", pt: "Qual configuração você ativa?", ar: "أي إعداد تفعل؟", ja: "どの構成を有効にしますか？", hi: "आप कौन सा कॉन्फ़िगरेशन सक्रिय करते हैं?", zhHans: "您启用哪种配置？", ko: "어떤 구성을 활성화합니까?"),
        .init(fr: "Que se passe-t-il ?", en: "What happens?", es: "¿Qué sucede?", de: "Was passiert?", it: "Cosa succede?", pt: "O que acontece?", ar: "ماذا يحدث؟", ja: "何が起きますか？", hi: "क्या होता है?", zhHans: "会发生什么结果？", ko: "어떤 일이 발생합니까?"),
        .init(fr: "Quel service choisissez-vous ?", en: "Which service do you choose?", es: "¿Qué servicio eliges?", de: "Welchen Dienst wählst du?", it: "Quale servizio scegli?", pt: "Qual serviço você escolhe?", ar: "أي خدمة تختار؟", ja: "どのサービスを選択しますか？", hi: "आप कौन सी सेवा चुनते हैं?", zhHans: "您选择哪项服务？", ko: "어떤 서비스를 선택하시겠습니까?"),
        .init(fr: "Quelle solution utilisez-vous ?", en: "Which solution do you use?", es: "¿Qué solución utilizas?", de: "Welche Lösung verwendest du?", it: "Quale soluzione utilizzi?", pt: "Qual solução você utiliza?", ar: "أي حل تستخدم؟", ja: "どのソリューションを使用しますか？", hi: "आप किस समाधान का उपयोग करते हैं?", zhHans: "您使用哪种解决方案？", ko: "어떤 솔루션을 사용합니까?"),
        .init(fr: "Quelle solution configurez-vous ?", en: "Which solution do you configure?", es: "¿Qué solución configuras?", de: "Welche Lösung konfigurierst du?", it: "Quale soluzione configuri?", pt: "Qual solução você configura?", ar: "أي حل تقوم بإعداده؟", ja: "どのソリューションを構成しますか？", hi: "आप कौन सा समाधान कॉन्फ़िगर करते हैं?", zhHans: "您配置哪种解决方案？", ko: "어떤 솔루션을 구성합니까?"),
        .init(fr: "Que recommandez-vous ?", en: "What do you recommend?", es: "¿Qué recomiendas?", de: "Was empfiehlst du?", it: "Cosa consigli?", pt: "O que você recomenda?", ar: "بماذا توصي؟", ja: "何を推奨しますか？", hi: "आप क्या अनुशंसा करते हैं?", zhHans: "您推荐哪种方案？", ko: "무엇을 권장합니까?"),
        .init(fr: "Comment les déployez-vous ?", en: "How do you deploy them?", es: "¿Cómo las despliegas?", de: "Wie stellst du sie bereit?", it: "Come le distribuisci?", pt: "Como você as implanta?", ar: "كيف تقوم بنشرها؟", ja: "どのようにデプロイしますか？", hi: "आप उन्हें कैसे डिप्लॉय करते हैं?", zhHans: "您应当如何部署它们？", ko: "어떻게 배포해야 합니까?"),
        .init(fr: "Quel rôle attribuez-vous ?", en: "Which role do you assign?", es: "¿Qué rol asignas?", de: "Welche Rolle weist du zu?", it: "Quale ruolo assegni?", pt: "Qual função você atribui?", ar: "أي دور تمنحه؟", ja: "どのロールを割り当てますか？", hi: "आप कौन सी भूमिका सौंपते हैं?", zhHans: "您应当分配哪个角色？", ko: "어떤 역할을 할당합니까?"),
        .init(fr: "Quelle brique officielle", en: "Which official service", es: "Qué servicio oficial", de: "Welchen offiziellen Dienst", it: "Quale servizio ufficiale", pt: "Qual serviço oficial", ar: "أي خدمة رسمية", ja: "どの公式サービス", hi: "कौन सी आधिकारिक सेवा", zhHans: "哪项官方组件", ko: "어떤 공식 서비스"),
        .init(fr: "en lecture seule", en: "with read-only access", es: "en solo lectura", de: "mit Lesezugriff", it: "in sola lettura", pt: "somente leitura", ar: "بصلاحية القراءة فقط", ja: "読み取り専用で", hi: "रीड-ओनली एक्सेस के साथ", zhHans: "以只读权限", ko: "읽기 전용으로"),
        .init(fr: "moindre privilège", en: "least privilege", es: "menor privilegio", de: "geringstes Privileg", it: "minimo privilegio", pt: "menor privilégio", ar: "أقل امتياز", ja: "最小権限", hi: "न्यूनतम विशेषाधिकार", zhHans: "最小权限原则", ko: "최소 권한 원칙"),
        .init(fr: "haute disponibilité", en: "high availability", es: "alta disponibilidad", de: "Hochverfügbarkeit", it: "alta disponibilità", pt: "alta disponibilidade", ar: "التوافر العالي", ja: "高可用性", hi: "उच्च उपलब्धता", zhHans: "高可用性", ko: "고가용성"),
        .init(fr: "panne régionale complète", en: "full regional outage", es: "caída regional completa", de: "vollständiger Regionalausfall", it: "guasto regionale completo", pt: "falha regional completa", ar: "انقطاع إقليمي كامل", ja: "リージョン全体の障害", hi: "पूर्ण क्षेत्रीय आउटेज", zhHans: "整个区域故障", ko: "전체 리전 장애"),
        .init(fr: "groupe de ressources", en: "Resource Group", es: "grupo de recursos", de: "Ressourcengruppe", it: "gruppo di risorse", pt: "grupo de recursos", ar: "مجموعة الموارد", ja: "リソースグループ", hi: "रिसोर्स ग्रुप", zhHans: "资源组", ko: "리소스 그룹"),
        .init(fr: "Groupe de ressources", en: "Resource Group", es: "Grupo de recursos", de: "Ressourcengruppe", it: "Gruppo di risorse", pt: "Grupo de recursos", ar: "مجموعة الموارد", ja: "リソースグループ", hi: "रिसोर्स ग्रुप", zhHans: "资源组", ko: "리소스 그룹"),
        .init(fr: "sous-réseau", en: "subnet", es: "subred", de: "Subnetz", it: "sottorete", pt: "sub-rede", ar: "الشبكة الفرعية", ja: "サブネット", hi: "सबनेट", zhHans: "子网", ko: "서브넷"),
        .init(fr: "Sous-réseau", en: "Subnet", es: "Subred", de: "Subnetz", it: "Sottorete", pt: "Sub-rede", ar: "الشبكة الفرعية", ja: "サブネット", hi: "सबनेट", zhHans: "子网", ko: "서브넷"),
        .init(fr: "machines virtuelles", en: "virtual machines", es: "máquinas virtuales", de: "virtuelle Maschinen", it: "macchine virtuali", pt: "máquinas virtuais", ar: "الأجهزة الافتراضية", ja: "仮想マシン", hi: "वर्चुअल मशीन", zhHans: "虚拟机", ko: "가상 머신"),
        .init(fr: "machine virtuelle", en: "virtual machine", es: "máquina virtual", de: "virtuelle Maschine", it: "macchina virtuale", pt: "máquina virtual", ar: "جهاز افتراضي", ja: "仮想マシン", hi: "वर्चुअल मशीन", zhHans: "虚拟机", ko: "가상 머신"),
        .init(fr: "base de données", en: "database", es: "base de datos", de: "Datenbank", it: "database", pt: "banco de dados", ar: "قاعدة البيانات", ja: "データベース", hi: "डेटाबेस", zhHans: "数据库", ko: "데이터베이스"),
        .init(fr: "bases de données", en: "databases", es: "bases de datos", de: "Datenbanken", it: "database", pt: "bancos de dados", ar: "قواعد البيانات", ja: "データベース", hi: "डेटाबेस", zhHans: "数据库", ko: "데이터베이스"),
        .init(fr: "sans jamais", en: "without ever", es: "sin nunca", de: "ohne jemals", it: "senza mai", pt: "sem nunca", ar: "دون أن", ja: "決して〜せずに", hi: "बिना कभी", zhHans: "绝不", ko: "절대 ~하지 않고"),
        .init(fr: "sans aucune", en: "without any", es: "sin ninguna", de: "ohne jegliche", it: "senza alcuna", pt: "sem nenhuma", ar: "بدون أي", ja: "一切の〜なしで", hi: "बिना किसी", zhHans: "无需任何", ko: "어떠한 ~도 없이"),
        .init(fr: "Résolution d'incidents et analyse sur", en: "Incident troubleshooting and analysis on", es: "Resolución de incidentes y análisis sobre", de: "Störungsbehebung und Analyse für", it: "Risoluzione incidenti e analisi su", pt: "Resolução de incidentes e análise sobre", ar: "حل الحوادث والتحليل في", ja: "障害切り分けと分析:", hi: "घटना समाधान और विश्लेषण:", zhHans: "故障排查与深入分析：", ko: "장애 해결 및 분석:"),
        .init(fr: "Mise en situation réelle :", en: "Real-world scenario:", es: "Escenario real:", de: "Praxisszenario:", it: "Scenario reale:", pt: "Cenário real:", ar: "سيناريو واقعي:", ja: "実務シナリオ:", hi: "वास्तविक परिदृश्य:", zhHans: "真实实战场景：", ko: "실전 시나리오:"),
        .init(fr: "Simulation interactive et commandes sur", en: "Interactive simulation and CLI commands on", es: "Simulación interactiva y comandos sobre", de: "Interaktive Simulation und Befehle zu", it: "Simulazione interattiva e comandi su", pt: "Simulação interativa e comandos sobre", ar: "محاكاة تفاعلية وأوامر على", ja: "対話型シミュレーションとコマンド:", hi: "इंटरैक्टिव सिमुलेशन और कमांड:", zhHans: "交互式模拟与命令实战：", ko: "대화형 시뮬레이션 및 명령어:"),
        .init(fr: "Consolidation des réflexes sur", en: "Consolidating exam reflexes on", es: "Consolidación de reflejos sobre", de: "Festigung der Prüfungsreflexe zu", it: "Consolidamento dei riflessi su", pt: "Consolidação de reflexos sobre", ar: "ترسيخ مهارات الاختبار في", ja: "重要ポイントの定着:", hi: "महत्वपूर्ण अवधारणाओं का सुदृढ़ीकरण:", zhHans: "核心考点巩固：", ko: "핵심 개념 다지기:"),
        .init(fr: "Validation complète des 10 jalons de l'Unité", en: "Complete validation of all 10 milestones in Unit", es: "Validación completa de los 10 hitos de la Unidad", de: "Vollständige Validierung aller 10 Meilensteine der Einheit", it: "Convalida completa delle 10 tappe dell'Unità", pt: "Validação completa dos 10 marcos da Unidade", ar: "التحقق الكامل من المراحل العشر للوحدة", ja: "全10ステップ総合認定 · ユニット", hi: "यूनिट के सभी 10 चरणों का पूर्ण सत्यापन", zhHans: "全面通关本单元全部 10 个节点 · 单元", ko: "10개 마일스톤 완전 정복 · 유닛"),
        .init(fr: "Réponse officielle validée", en: "Official validated answer", es: "Respuesta oficial validada", de: "Offiziell bestätigte Antwort", it: "Risposta ufficiale convalidata", pt: "Resposta oficial validada", ar: "الإجابة الرسمية المعتمدة", ja: "公式認定の正解", hi: "आधिकारिक सत्यापित उत्तर", zhHans: "官方验证正确答案", ko: "공식 검증 정답")
    ]

    private static let wordLexiconRules: [PhraseTranslationRule] = [
        .init(fr: "Identité", en: "Identity", es: "Identidad", de: "Identität", it: "Identità", pt: "Identidade", ar: "الهوية", ja: "ID管理", hi: "पहचान", zhHans: "身份认证", ko: "ID 관리"),
        .init(fr: "Gouvernance", en: "Governance", es: "Gobernanza", de: "Governance", it: "Governance", pt: "Governança", ar: "الحوكمة", ja: "ガバナンス", hi: "गवर्नेंस", zhHans: "治理", ko: "거버넌스"),
        .init(fr: "Stockage", en: "Storage", es: "Almacenamiento", de: "Speicher", it: "Archiviazione", pt: "Armazenamento", ar: "التخزين", ja: "ストレージ", hi: "स्टोरेज", zhHans: "存储", ko: "스토리지"),
        .init(fr: "Réseaux", en: "Networking", es: "Redes", de: "Netzwerke", it: "Reti", pt: "Redes", ar: "الشبكات", ja: "ネットワーク", hi: "नेटवर्किंग", zhHans: "网络", ko: "네트워크"),
        .init(fr: "Réseau", en: "Network", es: "Red", de: "Netzwerk", it: "Rete", pt: "Rede", ar: "شبكة", ja: "ネットワーク", hi: "नेटवर्क", zhHans: "网络", ko: "네트워크"),
        .init(fr: "Supervision", en: "Monitoring", es: "Supervisión", de: "Überwachung", it: "Monitoraggio", pt: "Monitoramento", ar: "المراقبة", ja: "監視", hi: "निगरानी", zhHans: "监控", ko: "모니터링"),
        .init(fr: "Sauvegarde", en: "Backup", es: "Copia de seguridad", de: "Sicherung", it: "Backup", pt: "Backup", ar: "النسخ الاحتياطي", ja: "バックアップ", hi: "बैकअप", zhHans: "备份", ko: "백업"),
        .init(fr: "Chiffrement", en: "Encryption", es: "Cifrado", de: "Verschlüsselung", it: "Crittografia", pt: "Criptografia", ar: "التشفير", ja: "暗号化", hi: "एन्क्रिप्शन", zhHans: "加密", ko: "암호화"),
        .init(fr: "Conteneurs", en: "Containers", es: "Contenedores", de: "Container", it: "Container", pt: "Contêineres", ar: "الحاويات", ja: "コンテナ", hi: "कंटेनर", zhHans: "容器", ko: "컨테이너"),
        .init(fr: "Fondations", en: "Foundations", es: "Fundamentos", de: "Grundlagen", it: "Fondamenti", pt: "Fundamentos", ar: "الأساسيات", ja: "基礎", hi: "बुनियाद", zhHans: "核心基础", ko: "기초"),
        .init(fr: "Fondamentaux", en: "Fundamentals", es: "Fundamentos", de: "Grundlagen", it: "Fondamentali", pt: "Fundamentos", ar: "الأساسيات", ja: "ファンダメンタルズ", hi: "फंडामेंटल्स", zhHans: "基础", ko: "기초"),
        .init(fr: "Productivité", en: "Productivity", es: "Productividad", de: "Produktivität", it: "Produttività", pt: "Produtividade", ar: "الإنتاجية", ja: "生産性", hi: "उत्पादकता", zhHans: "生产力", ko: "생산성"),
        .init(fr: "Niveau", en: "Level", es: "Nivel", de: "Stufe", it: "Livello", pt: "Nível", ar: "المستوى", ja: "レベル", hi: "स्तर", zhHans: "级别", ko: "레벨"),
        .init(fr: "Unité", en: "Unit", es: "Unidad", de: "Einheit", it: "Unità", pt: "Unidade", ar: "الوحدة", ja: "ユニット", hi: "यूनिट", zhHans: "单元", ko: "유닛"),
        .init(fr: "Étape", en: "Step", es: "Etapa", de: "Schritt", it: "Tappa", pt: "Etapa", ar: "مرحلة", ja: "ステップ", hi: "चरण", zhHans: "步骤", ko: "단계"),
        .init(fr: "Verrou", en: "Lock", es: "Bloqueo", de: "Sperre", it: "Blocco", pt: "Bloqueio", ar: "قفل", ja: "ロック", hi: "लॉक", zhHans: "资源锁", ko: "잠금"),
        .init(fr: "Verrous", en: "Locks", es: "Bloqueos", de: "Sperren", it: "Blocchi", pt: "Bloqueios", ar: "أقفال", ja: "ロック", hi: "लॉक्स", zhHans: "资源锁", ko: "잠금"),
        .init(fr: "Coffre", en: "Vault", es: "Bóveda", de: "Tresor", it: "Vault", pt: "Cofre", ar: "خزنة", ja: "ボールト", hi: "वॉल्ट", zhHans: "保管库", ko: "볼트"),
        .init(fr: "Lecteur", en: "Reader", es: "Lector", de: "Leser", it: "Lettore", pt: "Leitor", ar: "قارئ", ja: "閲覧者", hi: "रीडर", zhHans: "读取者", ko: "독자"),
        .init(fr: "Contributeur", en: "Contributor", es: "Colaborador", de: "Mitwirkender", it: "Collaboratore", pt: "Colaborador", ar: "مساهم", ja: "共同作成者", hi: "योगदानकर्ता", zhHans: "参与者", ko: "기여자"),
        .init(fr: "Propriétaire", en: "Owner", es: "Propietario", de: "Besitzer", it: "Proprietario", pt: "Proprietário", ar: "مالك", ja: "所有者", hi: "स्वामी", zhHans: "所有者", ko: "소유자"),
        .init(fr: "Vous", en: "You", es: "Tú", de: "Du", it: "Tu", pt: "Você", ar: "أنت", ja: "あなた", hi: "आप", zhHans: "您", ko: "귀하"),
        .init(fr: "Votre", en: "Your", es: "Tu", de: "Dein", it: "Il tuo", pt: "Seu", ar: "الخاص بك", ja: "あなたの", hi: "आपका", zhHans: "您的", ko: "귀하의"),
        .init(fr: "Quel", en: "Which", es: "Cuál", de: "Welcher", it: "Quale", pt: "Qual", ar: "أي", ja: "どの", hi: "कौन सा", zhHans: "哪个", ko: "어떤"),
        .init(fr: "Quelle", en: "Which", es: "Cuál", de: "Welche", it: "Quale", pt: "Qual", ar: "أي", ja: "どの", hi: "कौन सा", zhHans: "哪项", ko: "어떤"),
        .init(fr: "Comment", en: "How", es: "Cómo", de: "Wie", it: "Come", pt: "Como", ar: "كيف", ja: "どのように", hi: "कैसे", zhHans: "如何", ko: "어떻게"),
        .init(fr: "Pourquoi", en: "Why", es: "Por qué", de: "Warum", it: "Perché", pt: "Por que", ar: "لماذا", ja: "なぜ", hi: "क्यों", zhHans: "为什么", ko: "왜"),
        .init(fr: "doit", en: "must", es: "debe", de: "muss", it: "deve", pt: "deve", ar: "يجب أن", ja: "必要がある", hi: "चाहिए", zhHans: "必须", ko: "해야 합니다"),
        .init(fr: "doivent", en: "must", es: "deben", de: "müssen", it: "devono", pt: "devem", ar: "يجب أن", ja: "必要がある", hi: "चाहिए", zhHans: "必须", ko: "해야 합니다"),
        .init(fr: "uniquement", en: "only", es: "únicamente", de: "nur", it: "solo", pt: "apenas", ar: "فقط", ja: "のみ", hi: "केवल", zhHans: "仅", ko: "오직"),
        .init(fr: "automatiquement", en: "automatically", es: "automáticamente", de: "automatisch", it: "automaticamente", pt: "automaticamente", ar: "تلقائياً", ja: "自動的に", hi: "स्वचालित रूप से", zhHans: "自动", ko: "자동으로"),
        .init(fr: "directement", en: "directly", es: "directamente", de: "direkt", it: "direttamente", pt: "diretamente", ar: "مباشرة", ja: "直接", hi: "सीधे", zhHans: "直接", ko: "직접"),
        .init(fr: "sans", en: "without", es: "sin", de: "ohne", it: "senza", pt: "sem", ar: "بدون", ja: "なしで", hi: "बिना", zhHans: "无", ko: "없이"),
        .init(fr: "avec", en: "with", es: "con", de: "mit", it: "con", pt: "com", ar: "مع", ja: "で", hi: "के साथ", zhHans: "配合", ko: "함께"),
        .init(fr: "dans", en: "in", es: "en", de: "in", it: "in", pt: "em", ar: "في", ja: "内の", hi: "में", zhHans: "在", ko: "내"),
        .init(fr: "pour", en: "for", es: "para", de: "für", it: "per", pt: "para", ar: "لأجل", ja: "のために", hi: "के लिए", zhHans: "以", ko: "위해"),
        .init(fr: "sur", en: "on", es: "en", de: "auf", it: "su", pt: "em", ar: "على", ja: "上の", hi: "पर", zhHans: "在", ko: "상에서"),
        .init(fr: "vers", en: "to", es: "hacia", de: "zu", it: "verso", pt: "para", ar: "إلى", ja: "へ", hi: "की ओर", zhHans: "至", ko: "로"),
        .init(fr: "entre", en: "between", es: "entre", de: "zwischen", it: "tra", pt: "entre", ar: "بين", ja: "間の", hi: "के बीच", zhHans: "之间", ko: "간"),
        .init(fr: "et", en: "and", es: "y", de: "und", it: "e", pt: "e", ar: "و", ja: "および", hi: "और", zhHans: "与", ko: "및"),
        .init(fr: "ou", en: "or", es: "o", de: "oder", it: "o", pt: "ou", ar: "أو", ja: "または", hi: "या", zhHans: "或", ko: "또는")
    ]

    // MARK: - 7. Structural Domain Model Localizers (Units, Nodes, Slides, Déclic Cards, Exercises, Exams, Tour, Coach IA)

    public static func localizedTabTitle(_ tab: CertiGoNativeTab, lang: Int) -> String {
        tr(tab.title, lang: lang)
    }

    public static func localizedGuidedTourStep(
        stepIndex: Int,
        lang: Int
    ) -> (badge: String, title: String, body: String, targetLabel: String, pose: CertiGoMascotPose, spotlightY: CGFloat, spotlightHeight: CGFloat, pointsUp: Bool) {
        let clamped = min(max(stepIndex, 0), 4)
        let frSpecs: [(badge: String, title: String, body: String, targetLabel: String, pose: CertiGoMascotPose, spotlightY: CGFloat, spotlightHeight: CGFloat, pointsUp: Bool)] = [
            (
                "1/5 · PARCOURS & UNITÉS EN 10 ÉTAPES",
                "Ton Parcours & tes Unités de 10 étapes",
                "Change de certification en haut à gauche, suis ta Série 🔥, tes Gemmes 💎 et tes 5 Vies ❤️ en haut à droite, et valide les 10 étapes de chaque Unité.",
                "▲ Sélecteur de parcours, compteurs & Unité 1 (10 étapes)",
                .angle34LeftPath,
                FigMetrics.fiftySix,
                FigMetrics.oneHundredTwenty,
                true
            ),
            (
                "2/5 · CENTRE D'EXAMEN OFFICIEL",
                "Examens Blancs & Sprints par Domaine",
                "Lance un examen blanc chronométré noté sur 1000 ou entraîne-toi sur un domaine précis en Sprint Express de 5 questions.",
                "▲ Examen Blanc officiel & Domaines ciblés",
                .poseAnalyst,
                FigMetrics.oneHundredForty,
                FigMetrics.oneHundredSixty,
                true
            ),
            (
                "3/5 · COACH IA 24/7",
                "Coach IA Écrit & Mode Vocal Live",
                "Pose tes questions d'architecture, compare deux services Cloud côte à côte et épingle tes fiches clés pour le jour J.",
                "▲ Coach IA interactif 24/7 & Voix Live",
                .specialistAICoach,
                FigMetrics.oneHundredSixty,
                FigMetrics.oneHundredSixty,
                true
            ),
            (
                "4/5 · QUÊTE D'ÉQUIPE & LIGUE",
                "Quête Coopérative & Ligue entre Amis",
                "Invite un binôme sur la Quête d'Équipe en 15 étapes et compare ton XP hebdomadaire avec tes vrais collègues.",
                "▲ Quête d'Équipe & Classement Ligue Or",
                .celebratingTrophy,
                FigMetrics.oneHundredForty,
                FigMetrics.oneHundredSixty,
                true
            ),
            (
                "5/5 · PROFIL & LIQUID GLASS",
                "Ton Profil, Paramètres & Barre Liquid Glass",
                "Ouvre les Paramètres (⚙️) dans ton Profil pour ajuster l'intensité Liquid Glass iOS 26 (0 % à 100 %), changer la langue et gérer tes 3 parcours.",
                "▼ Barre Liquid Glass & Paramètres (⚙️)",
                .emotionStarryEyes,
                FigMetrics.oneHundredTwenty,
                FigMetrics.oneHundredForty,
                false
            )
        ]

        let enSpecs: [(badge: String, title: String, body: String, targetLabel: String)] = [
            (
                "1/5 · PATH & CERTIFICATIONS",
                "Your Path & 10-Step Units",
                "Switch certifications at the top left, track your Streak, Gems and 5 Hearts at the top right, and complete the 10 steps of Unit 1.",
                "▲ Course switcher, counters & Unit 1 (10 steps)"
            ),
            (
                "2/5 · OFFICIAL EXAM CENTER",
                "Timed Mock Exams & Domain Sprints",
                "Launch a timed mock exam scored out of 1000 or practice a specific exam domain in a 5-question sprint.",
                "▲ Timed mock exam & official domains"
            ),
            (
                "3/5 · 24/7 AI COACH",
                "Written & Live Voice AI Coach",
                "Ask architecture questions, compare cloud services side by side, and pin your key takeaways for exam day.",
                "▲ Interactive 24/7 AI Coach & Voice Live"
            ),
            (
                "4/5 · TEAM QUEST & LEAGUE",
                "Cooperative Quest & Friends League",
                "Invite a study partner for the 15-step Team Quest and compare your weekly XP with your real friends.",
                "▲ Team Quest & Friends Leaderboard"
            ),
            (
                "5/5 · PROFILE & LIQUID GLASS",
                "Your Profile, Settings & Liquid Glass Bar",
                "Open Settings (⚙️) in your Profile to adjust the iOS 26 Liquid Glass intensity (0% to 100%) and manage up to 3 parallel tracks.",
                "▼ Liquid Glass Navigation Bar & Settings (⚙️)"
            )
        ]

        let base = frSpecs[clamped]
        let language = resolveLanguage(forIndex: lang)
        if language.isFrenchVariant {
            return base
        }
        if language == .en {
            let en = enSpecs[clamped]
            return (en.badge, en.title, en.body, en.targetLabel, base.pose, base.spotlightY, base.spotlightHeight, base.pointsUp)
        }
        return (
            tr(base.badge, language: language),
            tr(base.title, language: language),
            tr(base.body, language: language),
            tr(base.targetLabel, language: language),
            base.pose,
            base.spotlightY,
            base.spotlightHeight,
            base.pointsUp
        )
    }

    public static func localizedLessonNode(_ node: CertiGoPathLessonNode, lang: Int) -> CertiGoPathLessonNode {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return node }
        return CertiGoPathLessonNode(
            id: node.id,
            unitNumber: node.unitNumber,
            stepIndexInUnit: node.stepIndexInUnit,
            globalIndex: node.globalIndex,
            title: tr(node.title, language: language),
            subtitle: tr(node.subtitle, language: language),
            state: node.state,
            iconSymbol: node.iconSymbol,
            levelBadge: tr(node.levelBadge, language: language),
            horizontalOffsetFactor: node.horizontalOffsetFactor
        )
    }

    public static func localizedUnit(_ unit: CertiGoCertificationUnit, lang: Int) -> CertiGoCertificationUnit {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return unit }
        return CertiGoCertificationUnit(
            id: unit.id,
            unitNumber: unit.unitNumber,
            headerTitle: tr(unit.headerTitle, language: language),
            subtitle: tr(unit.subtitle, language: language),
            progressPercent: unit.progressPercent,
            accentHex: unit.accentHex,
            lipHex: unit.lipHex,
            memoActivity: tr(unit.memoActivity, language: language),
            memoKeyTopics: unit.memoKeyTopics.map { tr($0, language: language) },
            memoGoldenRule: tr(unit.memoGoldenRule, language: language),
            lessons: unit.lessons.map { localizedLessonNode($0, lang: lang) }
        )
    }

    public static func localizedLessonSlide(_ slide: CertiGoLessonMicroSlide, lang: Int) -> CertiGoLessonMicroSlide {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return slide }
        return CertiGoLessonMicroSlide(
            stepBadge: tr(slide.stepBadge, language: language),
            title: tr(slide.title, language: language),
            bodyParagraph: tr(slide.bodyParagraph, language: language),
            keyTakeawayPill: tr(slide.keyTakeawayPill, language: language),
            serviceAssetName: slide.serviceAssetName
        )
    }

    public static func localizedThreeBrickSchema(
        _ schema: CertiGoThreeBrickArchitectureSpec,
        lang: Int
    ) -> CertiGoThreeBrickArchitectureSpec {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return schema }
        func locBrick(_ b: CertiGoThreeBrickArchitectureSpec.BrickNode) -> CertiGoThreeBrickArchitectureSpec.BrickNode {
            .init(
                icon: b.icon,
                title: tr(b.title, language: language),
                subtitle: tr(b.subtitle, language: language),
                borderHex: b.borderHex,
                bgHex: b.bgHex,
                textHex: b.textHex
            )
        }
        return CertiGoThreeBrickArchitectureSpec(
            brick1: locBrick(schema.brick1),
            brick2: locBrick(schema.brick2),
            brick3: locBrick(schema.brick3),
            flowSummaryLine: tr(schema.flowSummaryLine, language: language),
            goldenRule: tr(schema.goldenRule, language: language)
        )
    }

    public static func localizedDeclicCard(_ card: CertiGoDeclicCardSpec, lang: Int) -> CertiGoDeclicCardSpec {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return card }
        return CertiGoDeclicCardSpec(
            id: card.id,
            lessonId: card.lessonId,
            title: tr(card.title, language: language),
            analogy: tr(card.analogy, language: language),
            keyTakeaways: card.keyTakeaways.map { tr($0, language: language) },
            concreteExample: tr(card.concreteExample, language: language),
            diagramTop: tr(card.diagramTop, language: language),
            diagramBottom: tr(card.diagramBottom, language: language),
            step1: tr(card.step1, language: language),
            step2: tr(card.step2, language: language),
            rule: tr(card.rule, language: language),
            threeBrickSchema: localizedThreeBrickSchema(card.threeBrickSchema, lang: lang),
            microSlides: card.microSlides.map { localizedLessonSlide($0, lang: lang) }
        )
    }

    public static func localizedLessonDeclicCard(_ card: LessonDeclicCard, lang: Int) -> LessonDeclicCard {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return card }
        return LessonDeclicCard(
            title: tr(card.title, language: language),
            analogy: tr(card.analogy, language: language),
            keyTakeaways: card.keyTakeaways.map { tr($0, language: language) },
            concreteExample: tr(card.concreteExample, language: language),
            diagramTop: tr(card.diagramTop, language: language),
            diagramBottom: tr(card.diagramBottom, language: language),
            step1: tr(card.step1, language: language),
            step2: tr(card.step2, language: language),
            rule: tr(card.rule, language: language)
        )
    }

    public static func localizedExercise(_ ex: CertiGoNativeExerciseItem, lang: Int) -> CertiGoNativeExerciseItem {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return ex }
        let locOptions: [CertiGoNativeExerciseItem.OptionItem] = ex.options.map { opt in
            CertiGoNativeExerciseItem.OptionItem(
                id: opt.id,
                badge: opt.badge,
                title: tr(opt.title, language: language),
                plainLanguageTitle: tr(opt.plainLanguageTitle, language: language),
                subtitle: opt.subtitle.map { tr($0, language: language) },
                assetName: opt.assetName,
                isCorrect: opt.isCorrect,
                whyWrongOrRight: tr(opt.whyWrongOrRight, language: language)
            )
        }
        let locGlossary: [(term: String, simpleMeaning: String)] = ex.jargonGlossaryBridge.map { item in
            (
                term: tr(item.term, language: language),
                simpleMeaning: tr(item.simpleMeaning, language: language)
            )
        }
        return CertiGoNativeExerciseItem(
            id: ex.id,
            formatCode: ex.formatCode,
            domainBadge: tr(ex.domainBadge, language: language),
            subBadge: tr(ex.subBadge, language: language),
            prompt: tr(ex.prompt, language: language),
            plainLanguagePrompt: tr(ex.plainLanguagePrompt, language: language),
            jargonGlossaryBridge: locGlossary,
            mascotPose: ex.mascotPose,
            options: locOptions,
            cliPrefix: ex.cliPrefix,
            cliSuffix: ex.cliSuffix,
            expectedCLIInput: ex.expectedCLIInput,
            cliSuggestionBricks: ex.cliSuggestionBricks,
            wordBankTargetTokens: ex.wordBankTargetTokens,
            wordBankAllBricks: ex.wordBankAllBricks,
            matchingLeftItems: ex.matchingLeftItems.map { tr($0, language: language) },
            matchingRightItems: ex.matchingRightItems.map { tr($0, language: language) },
            hierarchyCorrectOrder: ex.hierarchyCorrectOrder,
            examTip: tr(ex.examTip, language: language),
            comparisonLeftTitle: tr(ex.comparisonLeftTitle, language: language),
            comparisonLeftBullets: ex.comparisonLeftBullets.map { tr($0, language: language) },
            comparisonRightTitle: tr(ex.comparisonRightTitle, language: language),
            comparisonRightBullets: ex.comparisonRightBullets.map { tr($0, language: language) },
            comparisonGoldenRule: tr(ex.comparisonGoldenRule, language: language),
            conceptId: ex.conceptId,
            conceptTitle: tr(ex.conceptTitle, language: language),
            difficulty: ex.difficulty,
            variantGroupId: ex.variantGroupId,
            isReviewReplay: ex.isReviewReplay
        )
    }

    public static func localizedExamQuestion(_ q: CertiGoNativeExamQuestion, lang: Int) -> CertiGoNativeExamQuestion {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return q }
        let locChoices: [CertiGoNativeExamQuestion.Choice] = q.choices.map { c in
            CertiGoNativeExamQuestion.Choice(
                id: c.id,
                badge: c.badge,
                text: tr(c.text, language: language),
                isCorrect: c.isCorrect,
                plainLanguageText: tr(c.plainLanguageText, language: language)
            )
        }
        return CertiGoNativeExamQuestion(
            id: q.id,
            number: q.number,
            domainTitle: tr(q.domainTitle, language: language),
            caseStudyBadge: tr(q.caseStudyBadge, language: language),
            stem: tr(q.stem, language: language),
            plainLanguageStem: tr(q.plainLanguageStem, language: language),
            choices: locChoices
        )
    }

    public static func localizedOnboardingCatalogItem(
        _ item: CertiGoOnboardingCatalogItem,
        lang: Int
    ) -> CertiGoOnboardingCatalogItem {
        let language = resolveLanguage(forIndex: lang)
        guard language != .frBilingual else { return item }
        return CertiGoOnboardingCatalogItem(
            code: item.code,
            title: tr(item.title, language: language),
            subtitle: tr(item.subtitle, language: language),
            vendorId: item.vendorId,
            categoryId: item.categoryId,
            difficultyRank: item.difficultyRank,
            levelLabel: tr(item.levelLabel, language: language)
        )
    }

    public static func localizedAICoachSuggestions(
        routeCode: String,
        lang: Int
    ) -> [(icon: String, title: String, subtitle: String, key: String)] {
        let language = resolveLanguage(forIndex: lang)
        let base: [(icon: String, title: String, subtitle: String, key: String)] = [
            ("📘", "Explique-moi RBAC vs Azure Policy", "Différences, portée & priorité en français clair", "rbac-vs-policy"),
            ("🎙️", "Simuler un entretien technique à voix haute", "Discussion interactive sur ton architecture", "oral-interview"),
            ("🎯", "Analyse ma progression et mes erreurs", "Conseils personnalisés selon tes réponses", "last-3-errors"),
            ("⚡", "Donne-moi un exemple de code ou CLI", "Commandes \(routeCode), scripts & bonnes pratiques", "cli-example")
        ]
        guard language != .frBilingual else { return base }
        return base.map { item in
            let locSubtitle: String = {
                if item.key == "cli-example" {
                    switch language {
                    case .frBilingual, .frFull: return "Commandes \(routeCode), scripts et bonnes pratiques"
                    case .en: return "\(routeCode) CLI commands, scripts & best practices"
                    case .es: return "Comandos \(routeCode), scripts y buenas prácticas"
                    case .de: return "\(routeCode)-Befehle, Skripte & Best Practices"
                    case .it: return "Comandi \(routeCode), script e best practice"
                    case .pt: return "Comandos \(routeCode), scripts e boas práticas"
                    case .ar: return "أوامر \(routeCode) النصية وأفضل الممارسات"
                    case .ja: return "\(routeCode) コマンド・スクリプト・ベストプラクティス"
                    case .hi: return "\(routeCode) कमांड, स्क्रिप्ट और सर्वोत्तम अभ्यास"
                    case .zhHans: return "\(routeCode) 命令、脚本与最佳实践"
                    case .ko: return "\(routeCode) 명령어, 스크립트 및 모범 사례"
                    }
                }
                return tr(item.subtitle, language: language)
            }()
            return (
                icon: item.icon,
                title: tr(item.title, language: language),
                subtitle: locSubtitle,
                key: item.key
            )
        }
    }

    public static func localizedAICoachFallbackReply(
        routeCode: String,
        userQuestion: String,
        lang: Int
    ) -> (reply: String, suggestions: [String]) {
        let language = resolveLanguage(forIndex: lang)
        switch language {
        case .frBilingual, .frFull:
            return (
                reply: "Sur le parcours \(routeCode), voici la règle d'or pour « \(userQuestion) » : isole d'abord le périmètre réseau (Private Endpoint / VPC Endpoint), applique le moindre privilège IAM/RBAC, puis vérifie la résilience Multi-AZ.",
                suggestions: [
                    "Donne-moi la commande CLI exacte (\(routeCode))",
                    "Quel est le piège d'examen le plus fréquent ?",
                    "Teste-moi avec une question d'examen"
                ]
            )
        case .en:
            return (
                reply: "For track \(routeCode), here is the golden rule regarding '\(userQuestion)': isolate the network perimeter first (Private Endpoint / VPC Endpoint), enforce least-privilege IAM/RBAC, and verify Multi-AZ resilience.",
                suggestions: [
                    "Show me the exact \(routeCode) CLI command",
                    "What is the most common exam trap?",
                    "Quiz me with an exam question"
                ]
            )
        case .es:
            return (
                reply: "En la ruta \(routeCode), esta es la regla de oro para « \(userQuestion) »: aísla primero el perímetro de red (Private Endpoint / VPC Endpoint), aplica el menor privilegio IAM/RBAC y verifica la resiliencia Multi-AZ.",
                suggestions: [
                    "Dame el comando CLI exacto (\(routeCode))",
                    "¿Cuál es la trampa de examen más frecuente?",
                    "Ponme a prueba con una pregunta"
                ]
            )
        case .de:
            return (
                reply: "Für den Pfad \(routeCode) gilt bei „\(userQuestion)“ folgende goldene Regel: Isoliere zuerst das Netzwerk (Private Endpoint / VPC Endpoint), wende das geringste Privileg (IAM/RBAC) an und sichere Multi-AZ-Resilienz.",
                suggestions: [
                    "Zeige mir den genauen CLI-Befehl (\(routeCode))",
                    "Was ist die häufigste Prüfungsfalle?",
                    "Teste mich mit einer Prüfungsfrage"
                ]
            )
        case .it:
            return (
                reply: "Nel percorso \(routeCode), ecco la regola d'oro per « \(userQuestion) »: isola prima il perimetro di rete (Private Endpoint / VPC Endpoint), applica il minimo privilegio IAM/RBAC e verifica la resilienza Multi-AZ.",
                suggestions: [
                    "Mostrami il comando CLI esatto (\(routeCode))",
                    "Qual è la trappola d'esame più frequente?",
                    "Mettiti alla prova con una domanda"
                ]
            )
        case .pt:
            return (
                reply: "Na trilha \(routeCode), aqui está a regra de ouro para '\(userQuestion)': isole primeiro o perímetro de rede (Private Endpoint / VPC Endpoint), aplique o menor privilégio IAM/RBAC e garanta resiliência Multi-AZ.",
                suggestions: [
                    "Mostre o comando CLI exato (\(routeCode))",
                    "Qual é a pegadinha de exame mais comum?",
                    "Teste-me com uma questão de exame"
                ]
            )
        case .ar:
            return (
                reply: "في مسار \(routeCode)، إليك القاعدة الذهبية حول « \(userQuestion) »: اعزل الشبكة أولاً عبر Private Endpoint، وطبّق مبدأ أقل امتياز IAM/RBAC، ثم تحقق من التوافر العالي Multi-AZ.",
                suggestions: [
                    "أعطني أمر CLI الدقيق (\(routeCode))",
                    "ما هو فخ الاختبار الأكثر شيوعاً؟",
                    "اختبرني بسؤال تطبيقي"
                ]
            )
        case .ja:
            return (
                reply: "\(routeCode) コースにおける「\(userQuestion)」の鉄則：まずネットワーク境界（Private Endpoint / VPC Endpoint）を分離し、最小権限（IAM/RBAC）を適用した上で、Multi-AZ冗長構成を確認します。",
                suggestions: [
                    "\(routeCode) の正確なCLIコマンドを表示",
                    "最も頻出する試験のひっかけは？",
                    "実践問題でテストする"
                ]
            )
        case .hi:
            return (
                reply: "\(routeCode) ट्रैक पर '\(userQuestion)' के लिए सुनहरा नियम: पहले नेटवर्क परिधि (Private Endpoint / VPC Endpoint) को अलग करें, न्यूनतम विशेषाधिकार IAM/RBAC लागू करें, और Multi-AZ लचीलापन सुनिश्चित करें।",
                suggestions: [
                    "सटीक \(routeCode) CLI कमांड दिखाएं",
                    "सबसे आम परीक्षा ट्रैप क्या है?",
                    "मुझसे एक परीक्षा प्रश्न पूछें"
                ]
            )
        case .zhHans:
            return (
                reply: "在 \(routeCode) 路径中，针对“\(userQuestion)”的黄金法则是：首先隔离网络边界（Private Endpoint / VPC Endpoint），实施 IAM/RBAC 最小权限原则，并确保多可用区（Multi-AZ）高可用。",
                suggestions: [
                    "展示完整的 \(routeCode) CLI 命令",
                    "最常见的考试陷阱是什么？",
                    "出一道真题考考我"
                ]
            )
        case .ko:
            return (
                reply: "\(routeCode) 트랙에서 '\(userQuestion)'에 대한 핵심 원칙: 먼저 네트워크 경계(Private Endpoint / VPC Endpoint)를 격리하고, 최소 권한(IAM/RBAC)을 적용한 뒤 Multi-AZ 고가용성을 검증하세요.",
                suggestions: [
                    "정확한 \(routeCode) CLI 명령어 보기",
                    "가장 자주 나오는 시험 함정은?",
                    "실전 문제로 테스트하기"
                ]
            )
        }
    }

    /// Audit helper for unit tests: returns `true` if a non-French localized string still contains untranslated French sentence markers.
    public static func containsUntranslatedFrenchLeak(_ text: String, lang: Int) -> Bool {
        let language = resolveLanguage(forIndex: lang)
        guard !language.isFrenchVariant else { return false }
        let frenchMarkers = [
            "Qu'est-ce qui",
            "Choisis ton",
            "Que configurez-vous",
            "Quelle fonctionnalité déployez-vous",
            "Quels paramètres activez-vous",
            "Quelle redondance choisissez-vous",
            "Tu n'as plus de cœurs",
            "J'ai déjà un compte",
            "Décroche tes certifications"
        ]
        return frenchMarkers.contains { text.contains($0) }
    }
}
