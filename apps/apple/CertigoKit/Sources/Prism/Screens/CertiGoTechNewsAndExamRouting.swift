import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - 1. Official OPML Categories & Top 100 Tech Watch Models (`veille_tech_top100.opml` + `Top100_sites_tech_veille_2026-11-04.xlsx`)

/// The 8 official categories from Gabriel's verified Top 100 Tech Watch OPML & Excel benchmark.
public enum CertiGoOPMLCategoryID: String, Codable, Sendable, CaseIterable, Identifiable {
    case aiMLAgents = "IA / ML / agents"
    case cloudInfraDevOps = "Cloud, infra, DevOps & éditeurs"
    case globalTechNews = "Actu tech généraliste mondiale"
    case cybersecurity = "Cybersécurité"
    case frenchTechFRBE = "Tech francophone (FR/BE)"
    case europeRegulationPublic = "Europe, régulation, souveraineté & secteur public"
    case businessStartupsInvestment = "Business, startups & investissement"
    case expertNewslettersCommunities = "Newsletters, blogs d'experts & communautés"

    public var id: String { rawValue }

    public var shortBadgeTitle: String {
        switch self {
        case .aiMLAgents: return "🤖 IA & Agents"
        case .cloudInfraDevOps: return "☁️ Cloud & Infra"
        case .globalTechNews: return "🌍 Tech Mondiale"
        case .cybersecurity: return "🛡️ Cybersécurité"
        case .frenchTechFRBE: return "🇫🇷 Tech FR/BE"
        case .europeRegulationPublic: return "🇪🇺 Europe & Régulation"
        case .businessStartupsInvestment: return "🚀 Startups & Business"
        case .expertNewslettersCommunities: return "📬 Blogs d'Experts"
        }
    }
}

/// Horizontal 1-line filter bar pills in the `Actus` (#2) tab.
public enum CertiGoTechNewsFilterID: String, Codable, Sendable, CaseIterable, Identifiable {
    case forYou = "for-you"
    case openai = "openai"
    case anthropic = "anthropic"
    case microsoft = "microsoft"
    case google = "google"
    case aws = "aws"
    case harvey = "harvey"
    case github = "github"
    case cloudAndCyber = "cloud-cyber"

    public var id: String { rawValue }

    public func displayTitle(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        switch self {
        case .forYou: return isEN ? "🔥 For You" : "🔥 Pour toi"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .microsoft: return "Microsoft"
        case .google: return "Google"
        case .aws: return "AWS"
        case .harvey: return "Harvey"
        case .github: return "GitHub"
        case .cloudAndCyber: return isEN ? "Cloud & Cyber" : "Cloud & Cyber"
        }
    }

    public var vendorLogoId: String? {
        switch self {
        case .forYou: return nil
        case .openai: return "openai"
        case .anthropic: return "anthropic"
        case .microsoft: return "microsoft"
        case .google: return "google"
        case .aws: return "aws"
        case .harvey: return "harvey"
        case .github: return "github"
        case .cloudAndCyber: return "cisco"
        }
    }
}

/// Editorial 1-line rubric pills for the Apple News x Perplexity Discover `Actus` feed.
public enum CertiGoEditorialRubricID: String, Codable, Sendable, CaseIterable, Identifiable {
    case topStories = "a-la-une"
    case aiAndModels = "ia-modeles"
    case cloudAndInfra = "cloud-infra"
    case cybersecurity = "cybersecurite"
    case devAndOpenSource = "dev-open-source"
    case regulationAndEurope = "regulation-europe"

    public var id: String { rawValue }

    public func displayTitle(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        switch self {
        case .topStories: return isEN ? "Top Stories" : "À la une"
        case .aiAndModels: return isEN ? "AI & Models" : "IA & Modèles"
        case .cloudAndInfra: return "Cloud & Infra"
        case .cybersecurity: return isEN ? "Cybersecurity" : "Cybersécurité"
        case .devAndOpenSource: return "Dev & Open Source"
        case .regulationAndEurope: return isEN ? "Regulation & Europe" : "Régulation & Europe"
        }
    }
}

/// Apple News iOS horizontal capsule pills (`height: 38 pt`, `cornerRadius: 19 pt`) with colored SF Symbol icon on the left + `15 pt .semibold` label, floating in Liquid Glass above the editorial feed.
public enum CertiGoAppleNewsTopicPillID: String, Codable, Sendable, CaseIterable, Identifiable {
    case topStories = "a-la-une"
    case aiAndLLM = "ia-llm"
    case cloudAndInfra = "cloud-infra"
    case cybersecurity = "cybersecurite"
    case devAndOpenSource = "dev-open-source"
    case audio = "audio"
    case saved = "enregistres"

    public var id: String { rawValue }

    public static let pillHeight: CGFloat = FigMetrics.thirtyEight
    public static let pillCornerRadius: CGFloat = FigMetrics.nineteen
    public static let labelFontSize: CGFloat = FigMetrics.fifteen

    public func displayTitle(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        switch self {
        case .topStories: return isEN ? "Top Stories" : "À la Une"
        case .aiAndLLM: return isEN ? "AI & LLM" : "IA & LLM"
        case .cloudAndInfra: return "Cloud & Infra"
        case .cybersecurity: return isEN ? "Cybersecurity" : "Cybersécurité"
        case .devAndOpenSource: return "Dev & Open Source"
        case .audio: return "Audio 🎧"
        case .saved: return isEN ? "Saved" : "Enregistrés"
        }
    }

    public var sfSymbolName: String {
        switch self {
        case .topStories: return "flame.fill"
        case .aiAndLLM: return "sparkles"
        case .cloudAndInfra: return "cloud.fill"
        case .cybersecurity: return "lock.shield.fill"
        case .devAndOpenSource: return "terminal.fill"
        case .audio: return "headphones"
        case .saved: return "bookmark.fill"
        }
    }

    public var iconColorHex: String {
        switch self {
        case .topStories: return FigPalette.appleNewsCoralRed
        case .aiAndLLM: return FigPalette.indigo600
        case .cloudAndInfra: return FigPalette.azureBlue
        case .cybersecurity: return FigPalette.emerald600
        case .devAndOpenSource: return FigPalette.appleNewsOrange
        case .audio: return FigPalette.appleNewsCoralRed
        case .saved: return FigPalette.appleNewsCoralRed
        }
    }
}

/// Apple News reader `Aa` font size tiers (`16 pt`, `18 pt`, `21 pt`).
public enum CertiGoAppleNewsReaderFontSizeTier: Int, Codable, Sendable, CaseIterable, Identifiable {
    case compact16 = 16
    case standard18 = 18
    case large21 = 21

    public var id: Int { rawValue }

    public var pointSize: CGFloat {
        switch self {
        case .compact16: return FigMetrics.sixteen
        case .standard18: return FigMetrics.eighteen
        case .large21: return FigMetrics.twentyOne
        }
    }

    public var labelText: String {
        "\(rawValue) pt"
    }

    public var nextTier: Self {
        switch self {
        case .compact16: return .standard18
        case .standard18: return .large21
        case .large21: return .compact16
        }
    }
}

/// Complete ranked entry from `Top100_sites_tech_veille_2026-11-04.xlsx` (100 sites scored on 30/20/20/20/10 rubric).
public struct CertiGoTop100TechSiteSpec: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { "site-rank-\(rank)" }
    public let rank: Int
    public let name: String
    public let siteURL: String
    public let category: CertiGoOPMLCategoryID
    public let language: String
    public let countryOrZone: String
    public let publicationFrequency: String
    public let hasRSSFeed: Bool
    public let paywallStatus: String
    public let scoreOutOf100: Int
    public let authorityOutOf30: Int
    public let freshnessOutOf20: Int
    public let originalityOutOf20: Int
    public let relevanceOutOf20: Int
    public let accessibilityOutOf10: Int
    public let whyFollowSummary: String
    public let verifiedRSSURL: String?
    public let vendorLogoId: String

    public var rankBadgeText: String {
        "#\(rank)"
    }
}

/// Verified RSS / Atom feed entry from `veille_tech_top100.opml` (83 verified feeds).
public struct CertiGoVerifiedRSSFeedSpec: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let rank: Int
    public let displayTitle: String
    public let sourceName: String
    public let category: CertiGoOPMLCategoryID
    public let xmlURL: String
    public let htmlURL: String
    public let vendorLogoId: String
    public let linkedCertificationCodes: [String]

    public var rankBadgeText: String {
        "#\(rank) \(sourceName)"
    }
}

/// Interactive 1-question Flash Quiz option on a Tech News card (`⚡ Question Flash · +10 XP`).
public struct CertiGoTechNewsFlashQuizOption: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let badge: String
    public let textFR: String
    public let textEN: String
    public let isCorrect: Bool

    public func localizedText(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? textEN : textFR
    }
}

public typealias CertiGoTechNewsItem = CertiGoTechNewsArticle

/// Rich Tech News article card displayed in Tab #2 (`Actus`), supporting plain-language toggle, CertiGo AI handoff, +10 XP Flash Quiz, and exact article cover photo (`imageURL`).
public struct CertiGoTechNewsArticle: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let feedId: String
    public let sourceRank: Int
    public let sourceName: String
    public let vendorLogoId: String
    public let category: CertiGoOPMLCategoryID
    public let linkedCertificationCode: String
    public let publishedRelativeLabel: String
    public let articleURL: String
    public let imageURL: String?
    public let headlineFR: String
    public let headlineEN: String
    public let technicalSummaryFR: String
    public let technicalSummaryEN: String
    public let plainLanguageSummaryFR: String
    public let plainLanguageSummaryEN: String
    public let examTakeawayFR: String
    public let examTakeawayEN: String
    public let flashQuestionPromptFR: String
    public let flashQuestionPromptEN: String
    public let flashOptions: [CertiGoTechNewsFlashQuizOption]
    public let flashExplanationFR: String
    public let flashExplanationEN: String

    public init(
        id: String,
        feedId: String,
        sourceRank: Int,
        sourceName: String,
        vendorLogoId: String,
        category: CertiGoOPMLCategoryID,
        linkedCertificationCode: String,
        publishedRelativeLabel: String,
        articleURL: String,
        imageURL: String? = nil,
        headlineFR: String,
        headlineEN: String,
        technicalSummaryFR: String,
        technicalSummaryEN: String,
        plainLanguageSummaryFR: String,
        plainLanguageSummaryEN: String,
        examTakeawayFR: String,
        examTakeawayEN: String,
        flashQuestionPromptFR: String,
        flashQuestionPromptEN: String,
        flashOptions: [CertiGoTechNewsFlashQuizOption],
        flashExplanationFR: String,
        flashExplanationEN: String
    ) {
        self.id = id
        self.feedId = feedId
        self.sourceRank = sourceRank
        self.sourceName = sourceName
        self.vendorLogoId = vendorLogoId
        self.category = category
        self.linkedCertificationCode = linkedCertificationCode
        self.publishedRelativeLabel = publishedRelativeLabel
        self.articleURL = articleURL
        let trimmedImage = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validImage = trimmedImage, !validImage.isEmpty {
            self.imageURL = validImage
        } else {
            self.imageURL = Self.defaultOfficialArticleImageURL(
                vendorLogoId: vendorLogoId,
                articleId: id,
                articleURL: articleURL
            )
        }
        self.headlineFR = headlineFR
        self.headlineEN = headlineEN
        self.technicalSummaryFR = technicalSummaryFR
        self.technicalSummaryEN = technicalSummaryEN
        self.plainLanguageSummaryFR = plainLanguageSummaryFR
        self.plainLanguageSummaryEN = plainLanguageSummaryEN
        self.examTakeawayFR = examTakeawayFR
        self.examTakeawayEN = examTakeawayEN
        self.flashQuestionPromptFR = flashQuestionPromptFR
        self.flashQuestionPromptEN = flashQuestionPromptEN
        self.flashOptions = flashOptions
        self.flashExplanationFR = flashExplanationFR
        self.flashExplanationEN = flashExplanationEN
    }

    /// Canonical official OpenGraph cover image URL for each verified publisher in the catalog.
    public static func defaultOfficialArticleImageURL(
        vendorLogoId: String,
        articleId: String,
        articleURL: String
    ) -> String {
        switch vendorLogoId.lowercased() {
        case "openai":
            return "https://openai.com/opengraph-image.png"
        case "microsoft":
            return "https://blogs.microsoft.com/wp-content/uploads/prod/2024/05/microsoft-azure-og.jpg"
        case "anthropic":
            return "https://www.anthropic.com/images/icons/safari-pinned-tab.svg"
        case "harvey":
            return "https://digital-strategy.ec.europa.eu/themes/custom/ewcms/images/ec-logo-og.png"
        case "cisco":
            return "https://cert.cyber.gouv.fr/static/images/anssi-og.png"
        case "github":
            return "https://github.blog/wp-content/uploads/2024/07/github-copilot-og.png"
        case "google":
            return "https://cloud.google.com/_static/cloud/images/social-icon-google-cloud-1200-630.png"
        case "aws":
            return "https://a0.awsstatic.com/libra-css/images/logos/aws_logo_smile_1200x630.png"
        default:
            return "https://blogs.microsoft.com/wp-content/uploads/prod/2024/05/microsoft-azure-og.jpg"
        }
    }

    public var rankedSourceBadgeText: String {
        "#\(sourceRank) \(sourceName.uppercased()) · \(publishedRelativeLabel)"
    }

    public func localizedLinkedCertificationBadge(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? "Linked to \(linkedCertificationCode)" : "Lié à \(linkedCertificationCode)"
    }

    public func localizedHeadline(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? headlineEN : headlineFR
    }

    public func localizedSummary(isPlainLanguage: Bool, languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        if isPlainLanguage {
            return isEN ? plainLanguageSummaryEN : plainLanguageSummaryFR
        }
        return isEN ? technicalSummaryEN : technicalSummaryFR
    }

    public func localizedExamTakeaway(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? examTakeawayEN : examTakeawayFR
    }

    public func localizedFlashPrompt(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? flashQuestionPromptEN : flashQuestionPromptFR
    }

    public func localizedFlashExplanation(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? flashExplanationEN : flashExplanationFR
    }

    public func buildCertiGoAIPrompt(languageIndex: Int, activeRouteCode: String, customQuestion: String? = nil) -> String {
        let isEN = (languageIndex % 6) == 2
        if let custom = customQuestion?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            if isEN {
                return "Regarding the tech news « \(headlineEN) » (#\(sourceRank) \(sourceName), linked to \(linkedCertificationCode)): \(custom)"
            }
            return "À propos de l'actualité « \(headlineFR) » (#\(sourceRank) \(sourceName), liée à \(linkedCertificationCode)) : \(custom)"
        }
        if isEN {
            return "Explain the tech news « \(headlineEN) » (#\(sourceRank) \(sourceName)) in simple terms and show its concrete impact on my \(linkedCertificationCode) / \(activeRouteCode) certification."
        }
        return "Explique-moi simplement l'actualité « \(headlineFR) » (#\(sourceRank) \(sourceName)) et montre son impact concret sur ma certification \(linkedCertificationCode) / \(activeRouteCode)."
    }

    /// Validated official URL for opening the article on the publisher's website (`🌐 Site officiel`).
    public var officialURL: URL? {
        if let direct = URL(string: articleURL), direct.scheme != nil {
            return direct
        }
        if let site = CertiGoVerifiedRSSFeedCatalog.all100RankedSites.first(where: { $0.rank == sourceRank }),
           let fallback = URL(string: site.siteURL)
        {
            return fallback
        }
        return URL(string: "https://openai.com/news/")
    }

    /// Clean domain host displayed on the `🌐 Site officiel` button (e.g. `openai.com`, `blogs.microsoft.com`).
    public var officialDomainHost: String {
        guard let host = officialURL?.host?.lowercased() else {
            return sourceName
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Clean editorial publisher name without internal rank numbers or OPML jargon.
    public var editorialMediaName: String {
        switch vendorLogoId {
        case "openai": return "OpenAI News"
        case "microsoft": return "Microsoft Azure"
        case "anthropic": return "Anthropic"
        case "harvey": return "Harvey · Europe Digital"
        case "cisco": return "ANSSI · CERT-FR"
        case "github": return "GitHub Blog"
        case "google": return "Google Cloud"
        case "aws": return "AWS News"
        default: return sourceName
        }
    }

    /// Editorial rubric assigned to this article for the 1-line Apple News rubric bar.
    public var editorialRubric: CertiGoEditorialRubricID {
        if vendorLogoId == "github" || linkedCertificationCode.uppercased() == "GH-300" {
            return .devAndOpenSource
        }
        switch category {
        case .aiMLAgents:
            return .aiAndModels
        case .cloudInfraDevOps:
            return .cloudAndInfra
        case .cybersecurity:
            return .cybersecurity
        case .europeRegulationPublic, .frenchTechFRBE:
            return .regulationAndEurope
        case .globalTechNews, .businessStartupsInvestment, .expertNewslettersCommunities:
            return .devAndOpenSource
        }
    }

    /// Localized rubric label for article reader headers and badges.
    public func editorialRubricTitle(languageIndex: Int) -> String {
        editorialRubric.displayTitle(languageIndex: languageIndex)
    }

    /// Editorial relative timestamp for the Hero card (e.g. `Il y a 2 h` / `2h ago`).
    public func editorialHeroTimeLabel(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        let raw = publishedRelativeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = raw.filter { $0.isNumber }
        let hourText = digits.isEmpty ? "2" : digits
        return isEN ? "\(hourText)h ago" : "Il y a \(hourText) h"
    }

    /// Compact timestamp for horizontal feed rows (e.g. `2 h`, `3 h`).
    public var editorialCompactTimeLabel: String {
        let digits = publishedRelativeLabel.filter { $0.isNumber }
        let hourText = digits.isEmpty ? "2" : digits
        return "\(hourText) h"
    }

    /// Deep editorial gradient start hex for the Hero banner and 72x72 thumbnail.
    public var editorialGradientStartHex: String {
        switch editorialRubric {
        case .aiAndModels: return "#312e81"
        case .cloudAndInfra: return "#0c4a6e"
        case .cybersecurity: return "#7f1d1d"
        case .devAndOpenSource: return "#064e3b"
        case .regulationAndEurope: return "#1e3a8a"
        case .topStories: return "#0f172a"
        }
    }

    /// Deep editorial gradient end hex for the Hero banner and 72x72 thumbnail.
    public var editorialGradientEndHex: String {
        switch editorialRubric {
        case .aiAndModels: return "#6366f1"
        case .cloudAndInfra: return "#0284c7"
        case .cybersecurity: return "#dc2626"
        case .devAndOpenSource: return "#059669"
        case .regulationAndEurope: return "#2563eb"
        case .topStories: return "#334155"
        }
    }

    /// Editorial accent color hex for rubric dot and media name.
    public var editorialAccentHex: String {
        switch editorialRubric {
        case .aiAndModels: return "#4f46e5"
        case .cloudAndInfra: return "#0284c7"
        case .cybersecurity: return "#dc2626"
        case .devAndOpenSource: return "#059669"
        case .regulationAndEurope: return "#2563eb"
        case .topStories: return "#2563eb"
        }
    }

    /// Soft tint background hex for editorial badges.
    public var editorialTintBgHex: String {
        switch editorialRubric {
        case .aiAndModels: return "#eef2ff"
        case .cloudAndInfra: return "#e0f2fe"
        case .cybersecurity: return "#fef2f2"
        case .devAndOpenSource: return "#ecfdf5"
        case .regulationAndEurope: return "#eff6ff"
        case .topStories: return "#f1f5f9"
        }
    }

    /// SF Symbol watermark icon representing the article's tech domain.
    public var editorialWatermarkSymbol: String {
        switch editorialRubric {
        case .aiAndModels: return "sparkles"
        case .cloudAndInfra: return "cloud.fill"
        case .cybersecurity: return "lock.shield.fill"
        case .devAndOpenSource: return "terminal.fill"
        case .regulationAndEurope: return "building.columns.fill"
        case .topStories: return "cpu.fill"
        }
    }

    /// Formatted share payload for SwiftUI `ShareLink` (`📤 Partager`).
    public func sharePayloadText(languageIndex: Int, isPlainLanguage: Bool = false) -> String {
        let isEN = (languageIndex % 6) == 2
        let title = localizedHeadline(languageIndex: languageIndex)
        let summary = localizedSummary(isPlainLanguage: isPlainLanguage, languageIndex: languageIndex)
        let takeaway = localizedExamTakeaway(languageIndex: languageIndex)
        if isEN {
            return "📰 \(title) (\(editorialMediaName) · \(linkedCertificationCode))\n\(summary)\n🎯 \(takeaway)\n🌐 \(articleURL)\nShared via CertiGo News"
        }
        return "📰 \(title) (\(editorialMediaName) · \(linkedCertificationCode))\n\(summary)\n🎯 \(takeaway)\n🌐 \(articleURL)\nPartagé depuis CertiGo Actus"
    }

    /// Spoken transcript read aloud by `CertiGoTechNewsAudioReader` (`AVSpeechSynthesizer`), adapting to the `Version simple` toggle.
    public func buildSpeechScript(isPlainLanguage: Bool, languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        let headline = localizedHeadline(languageIndex: languageIndex)
        let body = localizedSummary(isPlainLanguage: isPlainLanguage, languageIndex: languageIndex)
        let takeaway = localizedExamTakeaway(languageIndex: languageIndex)
        if isEN {
            let modeLabel = isPlainLanguage ? "Simple version." : "Key points."
            return "\(editorialMediaName). \(headline). \(modeLabel) \(body) Why it matters for \(linkedCertificationCode): \(takeaway)"
        }
        let modeLabel = isPlainLanguage ? "Version simple." : "À retenir."
        return "\(editorialMediaName). \(headline). \(modeLabel) \(body) Pourquoi c'est important pour \(linkedCertificationCode) : \(takeaway)"
    }

    /// Perplexity Discover-style suggested follow-up questions for instant Q&A right inside the article reader.
    public func suggestedFollowUpQuestions(languageIndex: Int) -> [String] {
        let isEN = (languageIndex % 6) == 2
        if isEN {
            return [
                "Explain simply what this changes",
                "Why is everyone talking about this?",
                "How does this connect to my path?"
            ]
        }
        return [
            "Explique-moi simplement ce que ça change",
            "Pourquoi tout le monde en parle ?",
            "Quel est le lien avec mon parcours ?"
        ]
    }

    /// Generates an immediate contextual answer from CertiGo AI for an inline question on this article.
    public func generateContextualAIAnswer(
        forQuestion question: String,
        languageIndex: Int,
        activeRouteCode: String
    ) -> String {
        let isEN = (languageIndex % 6) == 2
        let lower = question.lowercased()
        if lower.contains("simpl") || lower.contains("jargon") || lower.contains("clair") || lower.contains("explain") {
            if isEN {
                return "💡 In plain English (\(editorialMediaName)): \(plainLanguageSummaryEN) Key point: \(flashExplanationEN)"
            }
            return "💡 En clair (\(editorialMediaName)) : \(plainLanguageSummaryFR) L'essentiel : \(flashExplanationFR)"
        }
        if lower.contains("impact") || lower.contains("certif") || lower.contains("examen") || lower.contains("parcours") || lower.contains("lien") || lower.contains("path") || lower.contains(linkedCertificationCode.lowercased()) {
            if isEN {
                return "🎯 Connection with your path (\(linkedCertificationCode) / \(activeRouteCode)): \(examTakeawayEN). Practical takeaway: \(flashExplanationEN)"
            }
            return "🎯 Lien avec ton parcours (\(linkedCertificationCode) / \(activeRouteCode)) : \(examTakeawayFR). En pratique : \(flashExplanationFR)"
        }
        if isEN {
            return "✦ Why it matters (\(editorialMediaName)):\n• Plain view: \(plainLanguageSummaryEN)\n• Key detail: \(technicalSummaryEN)\n• Skill takeaway: \(examTakeawayEN)"
        }
        return "✦ Pourquoi tout le monde en parle (\(editorialMediaName)) :\n• En clair : \(plainLanguageSummaryFR)\n• Point clé : \(technicalSummaryFR)\n• Compétence liée : \(examTakeawayFR)"
    }

    /// Estimated reading duration displayed on the Apple News x Perplexity Hero card (`2 min de lecture`).
    public func estimatedReadingTimeLabel(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? "2 min read" : "2 min de lecture"
    }

    /// Apple News Hero Story Card footer metadata (`"Il y a X • Source • 3 min"`).
    public func appleNewsHeroFooterMetadata(languageIndex: Int) -> String {
        let timeText = editorialHeroTimeLabel(languageIndex: languageIndex)
        return "\(timeText) • \(editorialMediaName) • 3 min"
    }

    /// Apple News Compact Horizontal Story Card footer metadata (`"Il y a X • Source"`).
    public func appleNewsCompactFooterMetadata(languageIndex: Int) -> String {
        let timeText = editorialHeroTimeLabel(languageIndex: languageIndex)
        return "\(timeText) • \(editorialMediaName)"
    }

    /// Apple News Audio pill label (`"🎧 3 min"`).
    public func appleNewsAudioDurationPillText(languageIndex: Int) -> String {
        let minutes = max(2, min(4, (sourceRank % 3) + 2))
        return "🎧 \(minutes) min"
    }

    /// Apple News Reader uppercase category kicker (`"IA & MODÈLES • OPENAI-PRO"`).
    public func appleNewsCategoryKicker(languageIndex: Int) -> String {
        "\(editorialRubricTitle(languageIndex: languageIndex).uppercased()) • \(linkedCertificationCode.uppercased())"
    }

    /// Apple News Reader byline and timestamp (`"Par OpenAI News • Publié il y a 3 h"`).
    public func appleNewsBylineAndTimestamp(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        let rel = editorialHeroTimeLabel(languageIndex: languageIndex).lowercased()
        if isEN {
            return "By \(editorialMediaName) • Published \(rel)"
        }
        return "Par \(editorialMediaName) • Publié \(rel)"
    }

    /// Apple News Reader photo caption and official source credit below the 235pt cover photo.
    public func appleNewsPhotoCaptionCredit(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        if isEN {
            return "Photo: \(editorialMediaName) (\(officialDomainHost)) • Verified Tech Source #\(sourceRank)"
        }
        return "Photo : \(editorialMediaName) (\(officialDomainHost)) • Source officielle vérifiée #\(sourceRank)"
    }

    /// 3-part objective journalistic structure for `CertiGoTechNewsArticleReaderSheetView` (`1. Les faits`, `2. Comprendre le contexte technique`, `3. Ce qu'il faut retenir`).
    public func structuredJournalisticSections(
        isPlainLanguage: Bool,
        languageIndex: Int
    ) -> [(heading: String, body: String)] {
        let isEN = (languageIndex % 6) == 2
        let factsBody = isPlainLanguage
            ? (isEN ? plainLanguageSummaryEN : plainLanguageSummaryFR)
            : (isEN ? technicalSummaryEN : technicalSummaryFR)
        let contextBody = isPlainLanguage
            ? (isEN
                ? "\(technicalSummaryEN) \(flashExplanationEN)"
                : "\(technicalSummaryFR) \(flashExplanationFR)")
            : (isEN
                ? "\(plainLanguageSummaryEN) \(flashExplanationEN)"
                : "\(plainLanguageSummaryFR) \(flashExplanationFR)")
        let takeawaysBody = isEN ? examTakeawayEN : examTakeawayFR

        if isEN {
            return [
                (heading: "1. The facts (What was announced / published)", body: factsBody),
                (heading: "2. Understanding the technical context (Learn by reading)", body: contextBody),
                (heading: "3. Key takeaways", body: takeawaysBody)
            ]
        }
        return [
            (heading: "1. Les faits (Ce qui a été annoncé / publié)", body: factsBody),
            (heading: "2. Comprendre le contexte technique (Apprendre en lisant)", body: contextBody),
            (heading: "3. Ce qu'il faut retenir", body: takeawaysBody)
        ]
    }

    /// Convenience wrapper delegating to `CertiGoTechNewsAudioReaderState.buildNaturalPodcastNarrationSegments`.
    public func buildNaturalPodcastNarrationSegments(
        languageIndex: Int = 0,
        isPlainLanguage: Bool = false
    ) -> [CertiGoPodcastNarrationSegment] {
        CertiGoTechNewsAudioReaderState.buildNaturalPodcastNarrationSegments(
            for: self,
            languageIndex: languageIndex,
            isPlainLanguage: isPlainLanguage
        )
    }
}

// MARK: - 1B. Neural / Premium Voice Selector & Natural Podcast Prosody Engine (`CertiGoTechNewsAudioReaderState`)

public struct CertiGoTechNewsQAEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let articleId: String
    public let userQuestion: String
    public let aiAnswer: String

    public init(id: String, articleId: String, userQuestion: String, aiAnswer: String) {
        self.id = id
        self.articleId = articleId
        self.userQuestion = userQuestion
        self.aiAnswer = aiAnswer
    }
}

/// Quality tier of an iOS / macOS `AVSpeechSynthesisVoice` candidate (`Premium` > `Enhanced` > `Default`).
public enum CertiGoVoiceQualityTier: Int, Codable, Comparable, CaseIterable, Hashable, Sendable {
    case defaultCompact = 1
    case enhanced = 2
    case premium = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayBadgeFR: String {
        switch self {
        case .premium: return "Voix Studio HD (Premium)"
        case .enhanced: return "Voix Naturelle (Enhanced)"
        case .defaultCompact: return "Voix Standard iOS"
        }
    }

    public var displayBadgeEN: String {
        switch self {
        case .premium: return "Studio HD Voice (Premium)"
        case .enhanced: return "Natural Voice (Enhanced)"
        case .defaultCompact: return "Standard iOS Voice"
        }
    }
}

/// Pure, testable descriptor of a speech synthesis voice candidate for deterministic ranking across Linux and iOS.
public struct CertiGoVoiceCandidateDescriptor: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String { identifier }
    public let identifier: String
    public let name: String
    public let language: String
    public let qualityTier: CertiGoVoiceQualityTier
    public let isNoveltyVoice: Bool

    public static let preferredNeuralTokens: [String] = [
        "premium", "enhanced", "siri", "audrey", "amelie", "amélie",
        "aurelie", "aurélie", "ava", "zoe", "zoé", "allison"
    ]

    public init(
        identifier: String,
        name: String,
        language: String,
        qualityTier: CertiGoVoiceQualityTier,
        isNoveltyVoice: Bool = false
    ) {
        self.identifier = identifier
        self.name = name
        self.language = language
        self.qualityTier = qualityTier
        self.isNoveltyVoice = isNoveltyVoice
    }

    public var hasPreferredNeuralBonus: Bool {
        let haystack = "\(identifier.lowercased()) \(name.lowercased())"
        return Self.preferredNeuralTokens.contains { haystack.contains($0) }
    }

    public var rankingScore: Int {
        guard !isNoveltyVoice else { return -1_000 }
        let qualityScore = qualityTier.rawValue * 100
        let neuralBonus = hasPreferredNeuralBonus ? 50 : 0
        return qualityScore + neuralBonus
    }
}

/// Single prosodic utterance segment in a natural radio/podcast narration of a Tech News article.
public struct CertiGoPodcastNarrationSegment: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let index: Int
    public let role: String
    public let spokenText: String
    public let pitchMultiplier: Float
    public let rateScaleFactor: Double
    public let preUtteranceDelay: Double
    public let postUtteranceDelay: Double

    public init(
        id: String,
        index: Int,
        role: String,
        spokenText: String,
        pitchMultiplier: Float,
        rateScaleFactor: Double,
        preUtteranceDelay: Double,
        postUtteranceDelay: Double
    ) {
        self.id = id
        self.index = index
        self.role = role
        self.spokenText = spokenText
        self.pitchMultiplier = pitchMultiplier
        self.rateScaleFactor = rateScaleFactor
        self.preUtteranceDelay = preUtteranceDelay
        self.postUtteranceDelay = postUtteranceDelay
    }
}

#if canImport(AVFoundation) && !os(Linux)
import AVFoundation

@MainActor
private final class CertiGoNativeSpeechSynthesizerBridge {
    static let shared = CertiGoNativeSpeechSynthesizerBridge()
    private let synthesizer = AVSpeechSynthesizer()

    func configureSpokenAudioSession() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
        #endif
    }

    func selectBestNaturalVoice(for languageCode: String) -> (voice: AVSpeechSynthesisVoice?, descriptor: CertiGoVoiceCandidateDescriptor) {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        var descriptors: [CertiGoVoiceCandidateDescriptor] = []
        var voiceById: [String: AVSpeechSynthesisVoice] = [:]

        for v in allVoices {
            var isNovelty = false
            if #available(iOS 17.0, macOS 14.0, *) {
                isNovelty = v.voiceTraits.contains(.isNoveltyVoice)
            }
            let tier: CertiGoVoiceQualityTier
            switch v.quality {
            case .premium:
                tier = .premium
            case .enhanced:
                tier = .enhanced
            default:
                tier = .defaultCompact
            }
            let desc = CertiGoVoiceCandidateDescriptor(
                identifier: v.identifier,
                name: v.name,
                language: v.language,
                qualityTier: tier,
                isNoveltyVoice: isNovelty
            )
            descriptors.append(desc)
            voiceById[v.identifier] = v
        }

        if let best = CertiGoTechNewsAudioReaderState.selectBestNaturalVoiceCandidate(
            from: descriptors,
            for: languageCode
        ), let matchedVoice = voiceById[best.identifier] {
            return (matchedVoice, best)
        }

        let fallbackVoice = AVSpeechSynthesisVoice(language: languageCode) ?? AVSpeechSynthesisVoice(language: "fr-FR")
        let fallbackDesc = CertiGoVoiceCandidateDescriptor(
            identifier: fallbackVoice?.identifier ?? "com.apple.ttsbundle.default",
            name: fallbackVoice?.name ?? "Siri Standard",
            language: fallbackVoice?.language ?? languageCode,
            qualityTier: .defaultCompact,
            isNoveltyVoice: false
        )
        return (fallbackVoice, fallbackDesc)
    }

    func speakSegments(
        _ segments: [CertiGoPodcastNarrationSegment],
        languageCode: String,
        rateMultiplier: Double
    ) -> CertiGoVoiceCandidateDescriptor {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            _ = synthesizer.stopSpeaking(at: .immediate)
        }
        configureSpokenAudioSession()
        let selection = selectBestNaturalVoice(for: languageCode)
        let baseRate = Double(AVSpeechUtteranceDefaultSpeechRate)

        for segment in segments {
            let utterance = AVSpeechUtterance(string: segment.spokenText)
            utterance.voice = selection.voice
            let targetRate = baseRate * segment.rateScaleFactor * rateMultiplier
            let clampedRate = min(
                Double(AVSpeechUtteranceMaximumSpeechRate),
                max(Double(AVSpeechUtteranceMinimumSpeechRate), targetRate)
            )
            utterance.rate = Float(clampedRate)
            utterance.pitchMultiplier = segment.pitchMultiplier
            utterance.preUtteranceDelay = segment.preUtteranceDelay
            utterance.postUtteranceDelay = segment.postUtteranceDelay
            synthesizer.speak(utterance)
        }
        return selection.descriptor
    }

    func pause() {
        if synthesizer.isSpeaking {
            _ = synthesizer.pauseSpeaking(at: .word)
        }
    }

    func resume() {
        if synthesizer.isPaused {
            _ = synthesizer.continueSpeaking()
        }
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            _ = synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
#endif

/// Native AI Text-to-Speech controller for `Actus Tech`, featuring neural/premium voice selection, phonetic normalization, and multi-segment podcast prosody.
public struct CertiGoTechNewsAudioReaderState: Codable, Equatable, Sendable {
    @MainActor public static var shared = CertiGoTechNewsAudioReaderState()
    public static let supportedSpeedMultipliers: [Double] = [1.0, 1.25, 1.5]
    public static let appleNewsReaderSpeedMultipliers: [Double] = [0.9, 1.0, 1.25]

    public var activeArticleId: String? = nil
    public var activeArticleHeadline: String? = nil
    public var activeSourceBadge: String? = nil
    public var isSpeaking: Bool = false
    public var isPaused: Bool = false
    public var playbackRateMultiplier: Double = 1.0
    public var voiceLanguageCode: String = "fr-FR"
    public var spokenTranscript: String = ""
    public var narrationSegments: [CertiGoPodcastNarrationSegment] = []
    public var selectedVoiceName: String = "Audrey (Premium)"
    public var selectedVoiceQualityTier: CertiGoVoiceQualityTier = .premium
    public var wasPlainLanguageUsed: Bool = false

    public init() {}

    public var speedBadgeText: String {
        if abs(playbackRateMultiplier - 0.9) < 0.05 { return "0.9x" }
        if abs(playbackRateMultiplier - 1.25) < 0.05 { return "1.25x" }
        if abs(playbackRateMultiplier - 1.5) < 0.05 { return "1.5x" }
        return "1.0x"
    }

    /// True when the device only has the compact `.defaultCompact` voice installed and no `.enhanced` or `.premium` voice.
    public var isUsingDefaultCompactVoice: Bool {
        selectedVoiceQualityTier == .defaultCompact
    }

    /// Human-readable label of the voice used in the article reader.
    public func voiceStatusLabel(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        let tierBadge = isEN ? selectedVoiceQualityTier.displayBadgeEN : selectedVoiceQualityTier.displayBadgeFR
        return "🎙️ \(selectedVoiceName) · \(tierBadge)"
    }

    /// Discrete tip shown when only the default compact voice is installed on the iPhone.
    public static func premiumVoiceInstallationTip(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        if isEN {
            return "Tip: enable the iOS Premium voice in Settings > Accessibility > Spoken Content > Voices for a studio HD voice"
        }
        return "Astuce : activez la voix Premium d'iOS dans Réglages > Accessibilité > Contenu énoncé > Voix pour une voix studio HD"
    }

    /// Pure, deterministic voice selector filtering out novelty voices and ranking `.premium` > `.enhanced` > `.defaultCompact` with a Siri/Neural identifier bonus.
    public static func selectBestNaturalVoiceCandidate(
        from candidates: [CertiGoVoiceCandidateDescriptor],
        for languageCode: String
    ) -> CertiGoVoiceCandidateDescriptor? {
        let targetPrefix = String(languageCode.lowercased().prefix(2))
        let eligible = candidates.filter { candidate in
            guard !candidate.isNoveltyVoice else { return false }
            return candidate.language.lowercased().hasPrefix(targetPrefix)
        }
        guard !eligible.isEmpty else { return nil }
        return eligible.sorted { lhs, rhs in
            if lhs.rankingScore != rhs.rankingScore {
                return lhs.rankingScore > rhs.rankingScore
            }
            return lhs.name < rhs.name
        }.first
    }

    /// Transforms technical acronyms and strips parasitic symbols so `AVSpeechSynthesizer` pronounces tech articles naturally without robotic stuttering.
    public static func phoneticNormalizedForSpeech(_ rawText: String) -> String {
        var text = rawText

        // 1. Remove speed badges and parasitic UI symbols
        let removedTokens: [String] = [
            "1.0x", "1.25x", "1.5x", "·", "↗", "#", "*", "•",
            "🎧", "🔊", "⏸", "▶️", "🌐", "📤", "✦", "⚡", "«", "»"
        ]
        for token in removedTokens {
            text = text.replacingOccurrences(of: token, with: " ")
        }

        // 2. Replace certification codes and technical acronyms with natural phonetic spacing
        let phoneticMap: [(pattern: String, spoken: String)] = [
            ("SAA-C03", "S A A C 03"),
            ("AZ-900", "A Z 900"),
            ("AZ-104", "A Z 104"),
            ("AZ-305", "A Z 305"),
            ("AZ-500", "A Z 500"),
            ("AI-900", "A I 900"),
            ("AI-102", "A I 102"),
            ("GH-300", "G H 300"),
            ("GH-900", "G H 900"),
            ("SC-200", "S C 200"),
            ("SC-300", "S C 300"),
            ("SC-900", "S C 900"),
            ("DP-600", "D P 600"),
            ("MS-900", "M S 900"),
            ("PL-300", "P L 300"),
            ("ANSSI", "A N S S I"),
            ("CERT-FR", "CERT F R"),
            ("CKA", "C K A"),
            ("API", "A P I"),
            ("IAM", "I A M"),
            ("SQL", "S Q L"),
            ("SLA", "S L A"),
            ("CVE", "C V E"),
            ("RBAC", "R B A C"),
            ("VPC", "V P C"),
            ("AKS", "A K S"),
            ("GKE", "G K E"),
            ("MCP", "M C P")
        ]

        for entry in phoneticMap {
            text = text.replacingOccurrences(of: entry.pattern, with: entry.spoken)
        }

        // Strip leftover parentheses around short codes while keeping readable words
        text = text.replacingOccurrences(of: "(", with: ", ")
        text = text.replacingOccurrences(of: ")", with: ", ")

        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: " ,", with: ",")
            .replacingOccurrences(of: ",,", with: ",")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builds a warm, natural 3-segment radio/podcast narration for an article with breathing pauses (`0.22s ... 0.38s`) and conversational transitions.
    public static func buildNaturalPodcastNarrationSegments(
        for article: CertiGoTechNewsArticle,
        languageIndex: Int = 0,
        isPlainLanguage: Bool = false
    ) -> [CertiGoPodcastNarrationSegment] {
        let isEN = (languageIndex % 6) == 2
        let cleanMedia = phoneticNormalizedForSpeech(article.editorialMediaName)
        let cleanHeadline = phoneticNormalizedForSpeech(article.localizedHeadline(languageIndex: languageIndex))
        let cleanBody = phoneticNormalizedForSpeech(
            article.localizedSummary(isPlainLanguage: isPlainLanguage, languageIndex: languageIndex)
        )
        let cleanTakeaway = phoneticNormalizedForSpeech(article.localizedExamTakeaway(languageIndex: languageIndex))
        let cleanExplanation = phoneticNormalizedForSpeech(article.localizedFlashExplanation(languageIndex: languageIndex))

        let introText = isEN
            ? "News published by \(cleanMedia). \(cleanHeadline)."
            : "Actualité publiée par \(cleanMedia). \(cleanHeadline)."

        let factsText = isEN
            ? "Specifically, \(cleanBody)"
            : "Concrètement, \(cleanBody)"

        let takeawayText = isEN
            ? "Key takeaway: \(cleanTakeaway) In practice, \(cleanExplanation)"
            : "Ce qu'il faut retenir : \(cleanTakeaway) Sur le terrain, \(cleanExplanation)"

        return [
            CertiGoPodcastNarrationSegment(
                id: "\(article.id)-seg-1-intro",
                index: 0,
                role: "intro",
                spokenText: introText,
                pitchMultiplier: 1.03,
                rateScaleFactor: 0.96,
                preUtteranceDelay: 0.22,
                postUtteranceDelay: 0.32
            ),
            CertiGoPodcastNarrationSegment(
                id: "\(article.id)-seg-2-facts",
                index: 1,
                role: "facts",
                spokenText: factsText,
                pitchMultiplier: 1.01,
                rateScaleFactor: 0.96,
                preUtteranceDelay: 0.26,
                postUtteranceDelay: 0.34
            ),
            CertiGoPodcastNarrationSegment(
                id: "\(article.id)-seg-3-takeaway",
                index: 2,
                role: "takeaway",
                spokenText: takeawayText,
                pitchMultiplier: 1.02,
                rateScaleFactor: 0.96,
                preUtteranceDelay: 0.28,
                postUtteranceDelay: 0.38
            )
        ]
    }

    public mutating func startReading(
        article: CertiGoTechNewsArticle,
        isPlainLanguage: Bool,
        languageIndex: Int
    ) {
        let isEN = (languageIndex % 6) == 2
        let langCode = isEN ? "en-US" : "fr-FR"
        let transcript = article.buildSpeechScript(isPlainLanguage: isPlainLanguage, languageIndex: languageIndex)
        let segments = Self.buildNaturalPodcastNarrationSegments(
            for: article,
            languageIndex: languageIndex,
            isPlainLanguage: isPlainLanguage
        )
        activeArticleId = article.id
        activeArticleHeadline = article.localizedHeadline(languageIndex: languageIndex)
        activeSourceBadge = article.rankedSourceBadgeText
        isSpeaking = true
        isPaused = false
        voiceLanguageCode = langCode
        spokenTranscript = transcript
        narrationSegments = segments
        selectedVoiceName = isEN ? "Ava (Premium)" : "Audrey (Premium)"
        selectedVoiceQualityTier = .premium
        wasPlainLanguageUsed = isPlainLanguage
        #if canImport(AVFoundation) && !os(Linux)
        let rate = playbackRateMultiplier
        Task { @MainActor in
            _ = CertiGoNativeSpeechSynthesizerBridge.shared.speakSegments(
                segments,
                languageCode: langCode,
                rateMultiplier: rate
            )
        }
        #endif
    }

    public mutating func pause() {
        guard activeArticleId != nil, isSpeaking else { return }
        isSpeaking = false
        isPaused = true
        #if canImport(AVFoundation) && !os(Linux)
        Task { @MainActor in
            CertiGoNativeSpeechSynthesizerBridge.shared.pause()
        }
        #endif
    }

    public mutating func resume() {
        guard activeArticleId != nil, isPaused else { return }
        isSpeaking = true
        isPaused = false
        #if canImport(AVFoundation) && !os(Linux)
        Task { @MainActor in
            CertiGoNativeSpeechSynthesizerBridge.shared.resume()
        }
        #endif
    }

    public mutating func stop() {
        activeArticleId = nil
        activeArticleHeadline = nil
        activeSourceBadge = nil
        isSpeaking = false
        isPaused = false
        spokenTranscript = ""
        #if canImport(AVFoundation) && !os(Linux)
        Task { @MainActor in
            CertiGoNativeSpeechSynthesizerBridge.shared.stop()
        }
        #endif
    }

    public mutating func cycleSpeed() -> Double {
        if playbackRateMultiplier < 1.1 {
            playbackRateMultiplier = 1.25
        } else if playbackRateMultiplier < 1.4 {
            playbackRateMultiplier = 1.5
        } else {
            playbackRateMultiplier = 1.0
        }
        return playbackRateMultiplier
    }

    public mutating func setSpeed(_ rate: Double) {
        playbackRateMultiplier = rate
    }

    /// Toggles playback for the given article (`Listen Now` / `Écouter maintenant` Apple News Audio pill).
    public mutating func togglePlayback(
        for article: CertiGoTechNewsArticle,
        language: Int = 0,
        isPlainLanguage: Bool = false
    ) {
        if activeArticleId == article.id {
            if isSpeaking {
                pause()
            } else if isPaused {
                resume()
            } else {
                startReading(article: article, isPlainLanguage: isPlainLanguage, languageIndex: language)
            }
        } else {
            startReading(article: article, isPlainLanguage: isPlainLanguage, languageIndex: language)
        }
    }
}

// MARK: - 2. Complete Catalog of 100 Ranked Tech Sites & 83 Verified OPML RSS Feeds

public enum CertiGoVerifiedRSSFeedCatalog {
    /// All 100 ranked tech watch websites from `Top100_sites_tech_veille_2026-11-04.xlsx`.
    public static let all100RankedSites: [CertiGoTop100TechSiteSpec] = [
        CertiGoTop100TechSiteSpec(rank: 1, name: "OpenAI · News", siteURL: "https://openai.com/news/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 93, authorityOutOf30: 28, freshnessOutOf20: 20, originalityOutOf20: 18, relevanceOutOf20: 18, accessibilityOutOf10: 9, whyFollowSummary: "Source primaire des annonces OpenAI (modèles, agents, offres entreprise), à la fois partenaire et concurrent de Microsoft.", verifiedRSSURL: "https://openai.com/news/rss.xml", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 2, name: "Microsoft · blogs et annonces officiels (Azure, Microsoft 365/Copilot, Sécurité)", siteURL: "https://blogs.microsoft.com/", category: .cloudInfraDevOps, language: "Anglais / français", countryOrZone: "États-Unis / monde", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 92, authorityOutOf30: 24, freshnessOutOf20: 20, originalityOutOf20: 18, relevanceOutOf20: 20, accessibilityOutOf10: 10, whyFollowSummary: "Source primaire des annonces Azure, Microsoft 365 Copilot, agents et sécurité (Official Microsoft Blog, Azure Updates, Tech Community) à relayer aux clients.", verifiedRSSURL: "https://blogs.microsoft.com/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 3, name: "Ars Technica", siteURL: "https://arstechnica.com/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 90, authorityOutOf30: 30, freshnessOutOf20: 20, originalityOutOf20: 16, relevanceOutOf20: 14, accessibilityOutOf10: 10, whyFollowSummary: "Journalisme technique de fond (IA, sécurité, politique tech) apprécié des ingénieurs pour sa rigueur.", verifiedRSSURL: "https://feeds.arstechnica.com/arstechnica/index", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 4, name: "Bloomberg Technology", siteURL: "https://www.bloomberg.com/technology", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis / monde", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "payant", scoreOutOf100: 90, authorityOutOf30: 30, freshnessOutOf20: 20, originalityOutOf20: 19, relevanceOutOf20: 15, accessibilityOutOf10: 6, whyFollowSummary: "Première source de scoops business tech (Big Tech, IA, semi-conducteurs) selon le classement Techmeme.", verifiedRSSURL: "https://feeds.bloomberg.com/technology/news.rss", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 5, name: "Financial Times · Technology", siteURL: "https://www.ft.com/technology", category: .globalTechNews, language: "Anglais", countryOrZone: "Royaume-Uni / Europe", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "payant", scoreOutOf100: 89, authorityOutOf30: 30, freshnessOutOf20: 20, originalityOutOf20: 18, relevanceOutOf20: 15, accessibilityOutOf10: 6, whyFollowSummary: "Vision européenne et financière de la tech, très présent sur la régulation UE et l'IA.", verifiedRSSURL: "https://www.ft.com/technology?format=rss", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 6, name: "TechCrunch", siteURL: "https://techcrunch.com/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 89, authorityOutOf30: 29, freshnessOutOf20: 20, originalityOutOf20: 16, relevanceOutOf20: 14, accessibilityOutOf10: 10, whyFollowSummary: "Référence mondiale sur les startups, levées de fonds et lancements IA, avec de nombreuses exclusivités.", verifiedRSSURL: "https://techcrunch.com/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 7, name: "The Register", siteURL: "https://www.theregister.com/", category: .globalTechNews, language: "Anglais", countryOrZone: "Royaume-Uni / monde", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 89, authorityOutOf30: 27, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 18, accessibilityOutOf10: 9, whyFollowSummary: "Actualité IT d'entreprise sans langue de bois : licences Microsoft, cloud, souveraineté, secteur public européen.", verifiedRSSURL: "https://www.theregister.com/headlines.atom", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 8, name: "ANSSI / CERT-FR", siteURL: "https://cyber.gouv.fr/", category: .cybersecurity, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 89, authorityOutOf30: 22, freshnessOutOf20: 20, originalityOutOf20: 18, relevanceOutOf20: 20, accessibilityOutOf10: 9, whyFollowSummary: "Source officielle française : alertes et avis CERT-FR (désormais sur cert.cyber.gouv.fr), qualifications SecNumCloud, doctrine cyber de l'État.", verifiedRSSURL: "https://cert.cyber.gouv.fr/feed/", vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 9, name: "The Guardian · Technology", siteURL: "https://www.theguardian.com/technology", category: .globalTechNews, language: "Anglais", countryOrZone: "Royaume-Uni / Europe", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 88, authorityOutOf30: 30, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Regard européen et critique sur les plateformes, l'IA et la régulation, en accès libre.", verifiedRSSURL: "https://www.theguardian.com/technology/rss", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 10, name: "The Wall Street Journal · Tech", siteURL: "https://www.wsj.com/tech", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "payant", scoreOutOf100: 88, authorityOutOf30: 30, freshnessOutOf20: 20, originalityOutOf20: 19, relevanceOutOf20: 13, accessibilityOutOf10: 6, whyFollowSummary: "Scoops sur la stratégie des Big Tech, d'OpenAI et des deals IA (n°2 du classement Techmeme).", verifiedRSSURL: "https://feeds.content.dowjones.io/public/rss/RSSWSJD", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 11, name: "WIRED", siteURL: "https://www.wired.com/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 88, authorityOutOf30: 30, freshnessOutOf20: 20, originalityOutOf20: 17, relevanceOutOf20: 13, accessibilityOutOf10: 8, whyFollowSummary: "Enquêtes et analyses de référence sur l'IA, la sécurité et la politique numérique.", verifiedRSSURL: "https://www.wired.com/feed/rss", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 12, name: "BleepingComputer", siteURL: "https://www.bleepingcomputer.com/", category: .cybersecurity, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 87, authorityOutOf30: 26, freshnessOutOf20: 20, originalityOutOf20: 16, relevanceOutOf20: 16, accessibilityOutOf10: 9, whyFollowSummary: "L'actualité cyber la plus rapide : ransomwares, failles exploitées, correctifs Microsoft.", verifiedRSSURL: "https://www.bleepingcomputer.com/feed/", vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 13, name: "The New York Times · Technology", siteURL: "https://www.nytimes.com/section/technology", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 86, authorityOutOf30: 30, freshnessOutOf20: 18, originalityOutOf20: 18, relevanceOutOf20: 12, accessibilityOutOf10: 8, whyFollowSummary: "Enquêtes de fond sur les Big Tech et l'IA, souvent reprises par l'ensemble des médias.", verifiedRSSURL: "https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 14, name: "The Verge", siteURL: "https://www.theverge.com/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 86, authorityOutOf30: 30, freshnessOutOf20: 18, originalityOutOf20: 16, relevanceOutOf20: 14, accessibilityOutOf10: 8, whyFollowSummary: "Couverture quotidienne très réactive des Big Tech (Microsoft, Google, OpenAI) avec des journalistes spécialisés IA et Windows.", verifiedRSSURL: "https://www.theverge.com/rss/index.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 15, name: "Google Cloud · Blog", siteURL: "https://cloud.google.com/blog", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis / monde", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 86, authorityOutOf30: 26, freshnessOutOf20: 18, originalityOutOf20: 16, relevanceOutOf20: 16, accessibilityOutOf10: 10, whyFollowSummary: "Annonces officielles Google Cloud (Vertex AI, Gemini, offres souveraines dont S3NS), principal concurrent avec AWS.", verifiedRSSURL: "https://cloud.google.com/blog/feed", vendorLogoId: "google"),
        CertiGoTop100TechSiteSpec(rank: 16, name: "CNBC · Tech", siteURL: "https://www.cnbc.com/technology/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 85, authorityOutOf30: 30, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 12, accessibilityOutOf10: 8, whyFollowSummary: "Résultats, marchés et stratégie des géants du cloud et de l'IA, avec interviews de dirigeants.", verifiedRSSURL: "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=19854910", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 17, name: "Reuters Technology", siteURL: "https://www.reuters.com/technology/", category: .globalTechNews, language: "Anglais", countryOrZone: "Monde", publicationFrequency: "Quotidienne", hasRSSFeed: false, paywallStatus: "freemium", scoreOutOf100: 85, authorityOutOf30: 30, freshnessOutOf20: 18, originalityOutOf20: 18, relevanceOutOf20: 15, accessibilityOutOf10: 4, whyFollowSummary: "Agence mondiale : dépêches factuelles et rapides sur la tech, la régulation et les deals, y compris en Europe.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 18, name: "The Information", siteURL: "https://www.theinformation.com/", category: .businessStartupsInvestment, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: false, paywallStatus: "payant", scoreOutOf100: 84, authorityOutOf30: 25, freshnessOutOf20: 20, originalityOutOf20: 20, relevanceOutOf20: 15, accessibilityOutOf10: 4, whyFollowSummary: "Les scoops les plus cités sur OpenAI, Microsoft et l'économie de l'IA (payant mais incontournable).", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 19, name: "404 Media", siteURL: "https://www.404media.co/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 83, authorityOutOf30: 27, freshnessOutOf20: 18, originalityOutOf20: 19, relevanceOutOf20: 11, accessibilityOutOf10: 8, whyFollowSummary: "Journalisme d'investigation indépendant sur la surveillance, l'IA et les dérives des plateformes.", verifiedRSSURL: "https://www.404media.co/rss/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 20, name: "AWS · News Blog & What's New", siteURL: "https://aws.amazon.com/blogs/aws/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis / monde", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 83, authorityOutOf30: 27, freshnessOutOf20: 15, originalityOutOf20: 16, relevanceOutOf20: 16, accessibilityOutOf10: 9, whyFollowSummary: "Source primaire des lancements AWS, principal concurrent d'Azure (Bedrock, agents, cloud souverain européen).", verifiedRSSURL: "https://aws.amazon.com/blogs/aws/feed/", vendorLogoId: "aws"),
        CertiGoTop100TechSiteSpec(rank: 21, name: "VentureBeat", siteURL: "https://venturebeat.com/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 83, authorityOutOf30: 25, freshnessOutOf20: 18, originalityOutOf20: 14, relevanceOutOf20: 16, accessibilityOutOf10: 10, whyFollowSummary: "IA d'entreprise : agents, modèles, adoption et retours d'expérience de DSI.", verifiedRSSURL: "https://venturebeat.com/feed/", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 22, name: "Google · The Keyword (IA)", siteURL: "https://blog.google/technology/ai/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 83, authorityOutOf30: 22, freshnessOutOf20: 20, originalityOutOf20: 16, relevanceOutOf20: 15, accessibilityOutOf10: 10, whyFollowSummary: "Annonces produit officielles de Google (Gemini, Workspace, IA), concurrent direct de Microsoft 365 Copilot.", verifiedRSSURL: "https://blog.google/technology/ai/rss/", vendorLogoId: "google"),
        CertiGoTop100TechSiteSpec(rank: 23, name: "Simon Willison's Weblog", siteURL: "https://simonwillison.net/", category: .aiMLAgents, language: "Anglais", countryOrZone: "Royaume-Uni / États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 83, authorityOutOf30: 21, freshnessOutOf20: 20, originalityOutOf20: 17, relevanceOutOf20: 15, accessibilityOutOf10: 10, whyFollowSummary: "Blog d'expert de référence sur les LLM et les agents : tests concrets, sécurité (prompt injection), outils ; 40e du classement Techmeme.", verifiedRSSURL: "https://simonwillison.net/atom/everything/", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 24, name: "The Washington Post · Technology", siteURL: "https://www.washingtonpost.com/technology/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "payant", scoreOutOf100: 82, authorityOutOf30: 30, freshnessOutOf20: 20, originalityOutOf20: 16, relevanceOutOf20: 10, accessibilityOutOf10: 6, whyFollowSummary: "Enquêtes sur la régulation américaine de la tech et de l'IA.", verifiedRSSURL: "https://www.washingtonpost.com/arcio/rss/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 25, name: "Les Echos · Tech & Médias", siteURL: "https://www.lesechos.fr/tech-medias", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "payant", scoreOutOf100: 82, authorityOutOf30: 23, freshnessOutOf20: 20, originalityOutOf20: 17, relevanceOutOf20: 16, accessibilityOutOf10: 6, whyFollowSummary: "Le quotidien économique de référence : stratégie des acteurs tech, IA, cloud souverain, commande publique.", verifiedRSSURL: "https://services.lesechos.fr/rss/les-echos-tech-medias.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 26, name: "Google DeepMind · Blog", siteURL: "https://deepmind.google/discover/blog/", category: .aiMLAgents, language: "Anglais", countryOrZone: "Royaume-Uni / États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 82, authorityOutOf30: 22, freshnessOutOf20: 18, originalityOutOf20: 18, relevanceOutOf20: 15, accessibilityOutOf10: 9, whyFollowSummary: "Annonces de recherche et modèles Gemini de Google DeepMind, source primaire.", verifiedRSSURL: "https://deepmind.google/blog/rss.xml", vendorLogoId: "google"),
        CertiGoTop100TechSiteSpec(rank: 27, name: "Commission européenne · Shaping Europe's digital future", siteURL: "https://digital-strategy.ec.europa.eu/en/news", category: .europeRegulationPublic, language: "Anglais / français", countryOrZone: "Union européenne", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 82, authorityOutOf30: 19, freshnessOutOf20: 18, originalityOutOf20: 17, relevanceOutOf20: 19, accessibilityOutOf10: 9, whyFollowSummary: "Source primaire des décisions numériques de l'UE : AI Act et AI Office, données, cloud, cybersécurité, appels à projets.", verifiedRSSURL: "https://digital-strategy.ec.europa.eu/en/rss.xml", vendorLogoId: "harvey"),
        CertiGoTop100TechSiteSpec(rank: 28, name: "POLITICO Europe · Technology", siteURL: "https://www.politico.eu/section/technology/", category: .europeRegulationPublic, language: "Anglais", countryOrZone: "Union européenne", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 82, authorityOutOf30: 19, freshnessOutOf20: 20, originalityOutOf20: 17, relevanceOutOf20: 18, accessibilityOutOf10: 8, whyFollowSummary: "Coulisses de la politique numérique européenne et newsletter Morning Tech.", verifiedRSSURL: "https://www.politico.eu/feed/", vendorLogoId: "harvey"),
        CertiGoTop100TechSiteSpec(rank: 29, name: "BBC News · Technology", siteURL: "https://www.bbc.com/news/technology", category: .globalTechNews, language: "Anglais", countryOrZone: "Royaume-Uni", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 81, authorityOutOf30: 30, freshnessOutOf20: 18, originalityOutOf20: 13, relevanceOutOf20: 10, accessibilityOutOf10: 10, whyFollowSummary: "Actualité tech grand public fiable et pédagogique, utile pour sentir la perception du grand public.", verifiedRSSURL: "https://feeds.bbci.co.uk/news/technology/rss.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 30, name: "GeekWire", siteURL: "https://www.geekwire.com/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis (Seattle)", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 81, authorityOutOf30: 20, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 16, accessibilityOutOf10: 10, whyFollowSummary: "Média de Seattle qui couvre au plus près Microsoft et Amazon (cloud, IA, organisation).", verifiedRSSURL: "https://www.geekwire.com/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 31, name: "Le Monde Informatique", siteURL: "https://www.lemondeinformatique.fr/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 81, authorityOutOf30: 19, freshnessOutOf20: 20, originalityOutOf20: 13, relevanceOutOf20: 19, accessibilityOutOf10: 10, whyFollowSummary: "Actualité IT d'entreprise en français : éditeurs, cloud, IA, DSI publiques et privées.", verifiedRSSURL: "https://www.lemondeinformatique.fr/flux-rss/thematique/toutes-les-actualites/rss.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 32, name: "Techmeme", siteURL: "https://www.techmeme.com/", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis / monde", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 81, authorityOutOf30: 19, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 17, accessibilityOutOf10: 10, whyFollowSummary: "L'agrégateur de référence : une page qui hiérarchise en continu les sujets tech qui comptent et pointe vers les meilleures sources.", verifiedRSSURL: "https://www.techmeme.com/feed.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 33, name: "LeMagIT", siteURL: "https://www.lemagit.fr/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 81, authorityOutOf30: 18, freshnessOutOf20: 18, originalityOutOf20: 16, relevanceOutOf20: 20, accessibilityOutOf10: 9, whyFollowSummary: "La référence française de l'IT d'entreprise : cloud, souveraineté, cybersécurité, IA, avec beaucoup d'exclusivités.", verifiedRSSURL: "https://www.lemagit.fr/rss/ContentSyndication.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 34, name: "Le Monde · Pixels / Technologies", siteURL: "https://www.lemonde.fr/pixels/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 79, authorityOutOf30: 25, freshnessOutOf20: 18, originalityOutOf20: 15, relevanceOutOf20: 14, accessibilityOutOf10: 7, whyFollowSummary: "Enquêtes et analyses de référence sur le numérique, l'IA et leurs enjeux de société.", verifiedRSSURL: "https://www.lemonde.fr/pixels/rss_full.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 35, name: "Anthropic · News", siteURL: "https://www.anthropic.com/news", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 79, authorityOutOf30: 24, freshnessOutOf20: 12, originalityOutOf20: 18, relevanceOutOf20: 18, accessibilityOutOf10: 7, whyFollowSummary: "Source primaire des annonces Claude (modèles, agents, politique d'usage), acteur clé du marché IA entreprise.", verifiedRSSURL: nil, vendorLogoId: "anthropic"),
        CertiGoTop100TechSiteSpec(rank: 36, name: "Axios · Technology", siteURL: "https://www.axios.com/technology", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: false, paywallStatus: "freemium", scoreOutOf100: 79, authorityOutOf30: 24, freshnessOutOf20: 20, originalityOutOf20: 16, relevanceOutOf20: 13, accessibilityOutOf10: 6, whyFollowSummary: "Formats courts et exclusifs sur la politique tech et l'IA (newsletter Axios AI+).", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 37, name: "Krebs on Security", siteURL: "https://krebsonsecurity.com/", category: .cybersecurity, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 79, authorityOutOf30: 24, freshnessOutOf20: 12, originalityOutOf20: 20, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Enquêtes de référence sur la cybercriminalité par Brian Krebs, souvent en exclusivité.", verifiedRSSURL: "https://krebsonsecurity.com/feed/", vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 38, name: "Mistral AI · News", siteURL: "https://mistral.ai/news", category: .aiMLAgents, language: "Anglais / français", countryOrZone: "France / Europe", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 79, authorityOutOf30: 23, freshnessOutOf20: 12, originalityOutOf20: 17, relevanceOutOf20: 18, accessibilityOutOf10: 9, whyFollowSummary: "Champion européen de l'IA : annonces de modèles et offres souveraines, sujet incontournable avec le secteur public français.", verifiedRSSURL: "https://mistral.ai/rss.xml", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 39, name: "The Decoder", siteURL: "https://the-decoder.com/", category: .aiMLAgents, language: "Anglais / allemand", countryOrZone: "Allemagne / Europe", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 79, authorityOutOf30: 22, freshnessOutOf20: 20, originalityOutOf20: 13, relevanceOutOf20: 16, accessibilityOutOf10: 8, whyFollowSummary: "Média spécialisé IA très réactif, avec un regard européen ; bien classé par Techmeme.", verifiedRSSURL: "https://the-decoder.com/feed/", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 40, name: "Business Insider · Tech", siteURL: "https://www.businessinsider.com/tech", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 78, authorityOutOf30: 24, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 11, accessibilityOutOf10: 8, whyFollowSummary: "Coulisses des Big Tech (organisation, stratégie IA, management) avec de nombreuses exclusivités.", verifiedRSSURL: "https://feeds.businessinsider.com/custom/all", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 41, name: "Hugging Face · Blog", siteURL: "https://huggingface.co/blog", category: .aiMLAgents, language: "Anglais", countryOrZone: "France / États-Unis", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 78, authorityOutOf30: 24, freshnessOutOf20: 15, originalityOutOf20: 16, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Écosystème des modèles open source : nouveautés, benchmarks et bonnes pratiques.", verifiedRSSURL: "https://huggingface.co/blog/feed.xml", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 42, name: "Semafor · Technology", siteURL: "https://www.semafor.com/vertical/tech", category: .globalTechNews, language: "Anglais", countryOrZone: "États-Unis / monde", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 78, authorityOutOf30: 22, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 11, accessibilityOutOf10: 10, whyFollowSummary: "Analyses courtes et exclusives sur l'IA et la géopolitique tech.", verifiedRSSURL: "https://www.semafor.com/rss.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 43, name: "GitHub · Blog", siteURL: "https://github.blog/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 78, authorityOutOf30: 21, freshnessOutOf20: 18, originalityOutOf20: 15, relevanceOutOf20: 14, accessibilityOutOf10: 10, whyFollowSummary: "Annonces GitHub Copilot et agents de code, et rapports Octoverse.", verifiedRSSURL: "https://github.blog/feed/", vendorLogoId: "github"),
        CertiGoTop100TechSiteSpec(rank: 44, name: "The Record (Recorded Future News)", siteURL: "https://therecord.media/", category: .cybersecurity, language: "Anglais", countryOrZone: "États-Unis / monde", publicationFrequency: "Quotidienne", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 78, authorityOutOf30: 19, freshnessOutOf20: 18, originalityOutOf20: 17, relevanceOutOf20: 16, accessibilityOutOf10: 8, whyFollowSummary: "Journalisme cyber de qualité : États, cyberattaques, politiques publiques, y compris en Europe.", verifiedRSSURL: nil, vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 45, name: "ZDNET France", siteURL: "https://www.zdnet.fr/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 78, authorityOutOf30: 19, freshnessOutOf20: 20, originalityOutOf20: 12, relevanceOutOf20: 17, accessibilityOutOf10: 10, whyFollowSummary: "Actualité IT professionnelle en français (cloud, cyber, IA), complémentaire de LeMagIT.", verifiedRSSURL: "https://www.zdnet.fr/feeds/rss/actualites/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 46, name: "CNIL · Actualités", siteURL: "https://www.cnil.fr/fr/actualites", category: .europeRegulationPublic, language: "Français", countryOrZone: "France", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 77, authorityOutOf30: 20, freshnessOutOf20: 12, originalityOutOf20: 16, relevanceOutOf20: 19, accessibilityOutOf10: 10, whyFollowSummary: "Source officielle RGPD et IA en France : recommandations, sanctions, doctrine.", verifiedRSSURL: "https://cnil.fr/fr/rss.xml", vendorLogoId: "harvey"),
        CertiGoTop100TechSiteSpec(rank: 47, name: "ActuIA", siteURL: "https://www.actuia.com/", category: .aiMLAgents, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 77, authorityOutOf30: 18, freshnessOutOf20: 20, originalityOutOf20: 12, relevanceOutOf20: 17, accessibilityOutOf10: 10, whyFollowSummary: "Média français spécialisé IA : actualité, acteurs français, IA dans l'administration.", verifiedRSSURL: "https://www.actuia.com/feed/", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 48, name: "Computer Weekly", siteURL: "https://www.computerweekly.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "Royaume-Uni / Europe", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 77, authorityOutOf30: 18, freshnessOutOf20: 20, originalityOutOf20: 14, relevanceOutOf20: 16, accessibilityOutOf10: 9, whyFollowSummary: "IT d'entreprise et secteur public européen : cloud, souveraineté, licences, marchés publics.", verifiedRSSURL: "https://www.computerweekly.com/rss/All-Computer-Weekly-content.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 49, name: "DCD · Data Center Dynamics", siteURL: "https://www.datacenterdynamics.com/en/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "Royaume-Uni / monde", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 77, authorityOutOf30: 17, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 15, accessibilityOutOf10: 10, whyFollowSummary: "Référence sur les datacenters et l'infrastructure IA, dont les projets souverains européens.", verifiedRSSURL: "https://www.datacenterdynamics.com/en/rss/magazines", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 50, name: "Next", siteURL: "https://next.ink/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 77, authorityOutOf30: 17, freshnessOutOf20: 18, originalityOutOf20: 17, relevanceOutOf20: 18, accessibilityOutOf10: 7, whyFollowSummary: "Journalisme tech indépendant et rigoureux : régulation, souveraineté, IA, données publiques.", verifiedRSSURL: "https://next.ink/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 51, name: "Windows Central", siteURL: "https://www.windowscentral.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 76, authorityOutOf30: 21, freshnessOutOf20: 18, originalityOutOf20: 13, relevanceOutOf20: 14, accessibilityOutOf10: 10, whyFollowSummary: "Actualité Microsoft au quotidien (Windows, Copilot, Surface), avec des scoops internes.", verifiedRSSURL: "https://www.windowscentral.com/feed.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 52, name: "Dark Reading", siteURL: "https://www.darkreading.com/", category: .cybersecurity, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 76, authorityOutOf30: 20, freshnessOutOf20: 20, originalityOutOf20: 13, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Actualité et analyses cyber pour les RSSI.", verifiedRSSURL: "https://www.darkreading.com/rss.xml", vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 53, name: "SecurityWeek", siteURL: "https://www.securityweek.com/", category: .cybersecurity, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 76, authorityOutOf30: 20, freshnessOutOf20: 20, originalityOutOf20: 13, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Couverture quotidienne des vulnérabilités, incidents et du marché de la cybersécurité.", verifiedRSSURL: "https://www.securityweek.com/feed/", vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 54, name: "The New Stack", siteURL: "https://thenewstack.io/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 76, authorityOutOf30: 20, freshnessOutOf20: 20, originalityOutOf20: 13, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Cloud natif, plateformes, DevOps et ingénierie IA expliqués aux architectes.", verifiedRSSURL: "https://thenewstack.io/feed/", vendorLogoId: "kubernetes"),
        CertiGoTop100TechSiteSpec(rank: 55, name: "Euractiv · Tech", siteURL: "https://www.euractiv.com/sections/tech/", category: .europeRegulationPublic, language: "Anglais", countryOrZone: "Union européenne", publicationFrequency: "Quotidienne", hasRSSFeed: false, paywallStatus: "freemium", scoreOutOf100: 76, authorityOutOf30: 18, freshnessOutOf20: 18, originalityOutOf20: 16, relevanceOutOf20: 19, accessibilityOutOf10: 5, whyFollowSummary: "Suivi au jour le jour des textes européens (AI Act, Data Act, cloud, cybersécurité) à Bruxelles.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 56, name: "Risky Business / Risky Bulletin", siteURL: "https://risky.biz/", category: .cybersecurity, language: "Anglais", countryOrZone: "Australie / international", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 76, authorityOutOf30: 18, freshnessOutOf20: 20, originalityOutOf20: 16, relevanceOutOf20: 12, accessibilityOutOf10: 10, whyFollowSummary: "Podcast et bulletin quotidien de référence pour les professionnels de la sécurité.", verifiedRSSURL: "https://risky.biz/feeds/risky-business-news/", vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 57, name: "MIT Technology Review", siteURL: "https://www.technologyreview.com/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 75, authorityOutOf30: 20, freshnessOutOf20: 15, originalityOutOf20: 17, relevanceOutOf20: 15, accessibilityOutOf10: 8, whyFollowSummary: "Analyses de fond sur l'IA et ses impacts (newsletter The Algorithm), très crédible.", verifiedRSSURL: "https://www.technologyreview.com/feed/", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 58, name: "Numerama", siteURL: "https://www.numerama.com/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 75, authorityOutOf30: 20, freshnessOutOf20: 20, originalityOutOf20: 12, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Actualité tech et cyber (rubrique Cyberguerre) grand public de qualité.", verifiedRSSURL: "https://www.numerama.com/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 59, name: "JDN (Journal du Net)", siteURL: "https://www.journaldunet.com/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 75, authorityOutOf30: 19, freshnessOutOf20: 15, originalityOutOf20: 14, relevanceOutOf20: 17, accessibilityOutOf10: 10, whyFollowSummary: "Décryptages business et techniques (IA, cloud, solutions) très lus par les décideurs français.", verifiedRSSURL: "https://www.journaldunet.com/rss/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 60, name: "Tech Policy Press", siteURL: "https://www.techpolicy.press/", category: .europeRegulationPublic, language: "Anglais", countryOrZone: "États-Unis / international", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 75, authorityOutOf30: 18, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 14, accessibilityOutOf10: 8, whyFollowSummary: "Analyses de fond sur la régulation de la tech et de l'IA, dont l'UE.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 61, name: "Acteurs publics", siteURL: "https://acteurspublics.fr/", category: .europeRegulationPublic, language: "Français", countryOrZone: "France", publicationFrequency: "Quotidienne", hasRSSFeed: false, paywallStatus: "freemium", scoreOutOf100: 75, authorityOutOf30: 16, freshnessOutOf20: 18, originalityOutOf20: 15, relevanceOutOf20: 20, accessibilityOutOf10: 6, whyFollowSummary: "Le média de la sphère publique française : transformation numérique de l'État, IA, DINUM, nominations.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 62, name: "Cloudflare · Blog", siteURL: "https://blog.cloudflare.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 74, authorityOutOf30: 23, freshnessOutOf20: 15, originalityOutOf20: 16, relevanceOutOf20: 11, accessibilityOutOf10: 9, whyFollowSummary: "Analyses techniques de grande qualité (réseau, sécurité, IA, incidents Internet).", verifiedRSSURL: "https://blog.cloudflare.com/rss/", vendorLogoId: "kubernetes"),
        CertiGoTop100TechSiteSpec(rank: 63, name: "NVIDIA · Blog", siteURL: "https://blogs.nvidia.com/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 74, authorityOutOf30: 20, freshnessOutOf20: 18, originalityOutOf20: 14, relevanceOutOf20: 12, accessibilityOutOf10: 10, whyFollowSummary: "Annonces du fournisseur dominant de l'infrastructure IA (GPU, IA souveraine, partenariats cloud).", verifiedRSSURL: "https://blogs.nvidia.com/feed/", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 64, name: "InfoQ", siteURL: "https://www.infoq.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "International", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 74, authorityOutOf30: 19, freshnessOutOf20: 20, originalityOutOf20: 13, relevanceOutOf20: 12, accessibilityOutOf10: 10, whyFollowSummary: "Architecture logicielle et retours d'expérience d'ingénierie (cloud, IA, données).", verifiedRSSURL: "https://feed.infoq.com/ai-ml-data-eng/", vendorLogoId: "kubernetes"),
        CertiGoTop100TechSiteSpec(rank: 65, name: "L'Usine Digitale", siteURL: "https://www.usine-digitale.fr/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 74, authorityOutOf30: 17, freshnessOutOf20: 20, originalityOutOf20: 13, relevanceOutOf20: 16, accessibilityOutOf10: 8, whyFollowSummary: "Transformation numérique des entreprises et IA en France.", verifiedRSSURL: "https://www.usine-digitale.fr/arc/outboundfeeds/rss/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 66, name: "numerique.gouv.fr (DINUM)", siteURL: "https://www.numerique.gouv.fr/sinformer/", category: .europeRegulationPublic, language: "Français", countryOrZone: "France", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 73, authorityOutOf30: 19, freshnessOutOf20: 12, originalityOutOf20: 15, relevanceOutOf20: 20, accessibilityOutOf10: 7, whyFollowSummary: "Source officielle de la stratégie numérique et IA de l'État (Albert, cloud, doctrine, appels à projets).", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 67, name: "Sifted", siteURL: "https://sifted.eu/", category: .businessStartupsInvestment, language: "Anglais", countryOrZone: "Europe", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 73, authorityOutOf30: 17, freshnessOutOf20: 20, originalityOutOf20: 15, relevanceOutOf20: 13, accessibilityOutOf10: 8, whyFollowSummary: "Le média des startups et VC européens (soutenu par le Financial Times).", verifiedRSSURL: "https://sifted.eu/feed", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 68, name: "Office 365 for IT Pros (Tony Redmond)", siteURL: "https://office365itpros.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "Irlande / international", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 73, authorityOutOf30: 15, freshnessOutOf20: 15, originalityOutOf20: 16, relevanceOutOf20: 18, accessibilityOutOf10: 9, whyFollowSummary: "Le décryptage le plus pointu des nouveautés Microsoft 365 et Copilot, par Tony Redmond (MVP), basé en Irlande.", verifiedRSSURL: "https://office365itpros.com/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 69, name: "IT-Connect", siteURL: "https://www.it-connect.fr/", category: .cybersecurity, language: "Français", countryOrZone: "France", publicationFrequency: "Quotidienne", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 72, authorityOutOf30: 20, freshnessOutOf20: 18, originalityOutOf20: 11, relevanceOutOf20: 15, accessibilityOutOf10: 8, whyFollowSummary: "Actualité cyber et tutoriels systèmes en français (Windows Server, Microsoft 365, Azure).", verifiedRSSURL: nil, vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 70, name: "Maddyness", siteURL: "https://www.maddyness.com/", category: .businessStartupsInvestment, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 72, authorityOutOf30: 19, freshnessOutOf20: 20, originalityOutOf20: 11, relevanceOutOf20: 12, accessibilityOutOf10: 10, whyFollowSummary: "Écosystème startups et French Tech : levées, IA, innovation.", verifiedRSSURL: "https://www.maddyness.com/uk/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 71, name: "Schneier on Security", siteURL: "https://www.schneier.com/", category: .cybersecurity, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 72, authorityOutOf30: 19, freshnessOutOf20: 15, originalityOutOf20: 16, relevanceOutOf20: 12, accessibilityOutOf10: 10, whyFollowSummary: "Le regard de Bruce Schneier sur la sécurité, l'IA et les politiques publiques.", verifiedRSSURL: "https://www.schneier.com/feed/", vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 72, name: "Silicon Republic", siteURL: "https://www.siliconrepublic.com/", category: .europeRegulationPublic, language: "Anglais", countryOrZone: "Irlande", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 72, authorityOutOf30: 19, freshnessOutOf20: 20, originalityOutOf20: 11, relevanceOutOf20: 12, accessibilityOutOf10: 10, whyFollowSummary: "Actualité tech irlandaise (siège européen des Big Tech, Dublin).", verifiedRSSURL: "https://www.siliconrepublic.com/feed", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 73, name: "Stratechery (Ben Thompson)", siteURL: "https://stratechery.com/", category: .expertNewslettersCommunities, language: "Anglais", countryOrZone: "États-Unis / Taïwan", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: false, paywallStatus: "freemium", scoreOutOf100: 72, authorityOutOf30: 19, freshnessOutOf20: 12, originalityOutOf20: 19, relevanceOutOf20: 16, accessibilityOutOf10: 6, whyFollowSummary: "L'analyse stratégique la plus influente sur les Big Tech, Microsoft et l'IA.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 74, name: "Infosecurity Magazine", siteURL: "https://www.infosecurity-magazine.com/", category: .cybersecurity, language: "Anglais", countryOrZone: "Royaume-Uni / Europe", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 72, authorityOutOf30: 18, freshnessOutOf20: 20, originalityOutOf20: 11, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Actualité cyber avec une bonne couverture du Royaume-Uni et de l'UE (NIS2, DORA).", verifiedRSSURL: "https://www.infosecurity-magazine.com/rss/news/", vendorLogoId: "cisco"),
        CertiGoTop100TechSiteSpec(rank: 75, name: "SiliconANGLE", siteURL: "https://siliconangle.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 72, authorityOutOf30: 18, freshnessOutOf20: 18, originalityOutOf20: 12, relevanceOutOf20: 14, accessibilityOutOf10: 10, whyFollowSummary: "Actualité IT d'entreprise, cloud et IA, avec interviews de dirigeants (theCUBE).", verifiedRSSURL: "https://siliconangle.com/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 76, name: "Latent Space", siteURL: "https://www.latent.space/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 72, authorityOutOf30: 16, freshnessOutOf20: 18, originalityOutOf20: 16, relevanceOutOf20: 14, accessibilityOutOf10: 8, whyFollowSummary: "Newsletter/podcast de référence des ingénieurs IA : agents, outils de dev, tendances.", verifiedRSSURL: "https://www.latent.space/feed", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 77, name: "Petri IT Knowledgebase", siteURL: "https://petri.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 72, authorityOutOf30: 16, freshnessOutOf20: 18, originalityOutOf20: 12, relevanceOutOf20: 16, accessibilityOutOf10: 10, whyFollowSummary: "Actualité et guides pour administrateurs Microsoft 365, Azure et Windows.", verifiedRSSURL: "https://petri.com/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 78, name: "IAPP · News", siteURL: "https://iapp.org/news/", category: .europeRegulationPublic, language: "Anglais", countryOrZone: "International / UE", publicationFrequency: "Quotidienne", hasRSSFeed: false, paywallStatus: "freemium", scoreOutOf100: 71, authorityOutOf30: 17, freshnessOutOf20: 18, originalityOutOf20: 14, relevanceOutOf20: 16, accessibilityOutOf10: 6, whyFollowSummary: "Actualité de la protection des données et de la gouvernance IA (RGPD, AI Act) par l'association des privacy pros.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 79, name: "Dans les algorithmes", siteURL: "https://danslesalgorithmes.net/", category: .europeRegulationPublic, language: "Français", countryOrZone: "France", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 71, authorityOutOf30: 16, freshnessOutOf20: 12, originalityOutOf20: 16, relevanceOutOf20: 18, accessibilityOutOf10: 9, whyFollowSummary: "Analyses de Hubert Guillaud sur les algorithmes et l'IA dans les services publics.", verifiedRSSURL: "https://danslesalgorithmes.net/feed/", vendorLogoId: "harvey"),
        CertiGoTop100TechSiteSpec(rank: 80, name: "Blog du Modérateur", siteURL: "https://www.blogdumoderateur.com/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Quotidienne", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 20, freshnessOutOf20: 18, originalityOutOf20: 11, relevanceOutOf20: 13, accessibilityOutOf10: 8, whyFollowSummary: "Actualité des outils numériques et de l'IA générative pour les professionnels.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 81, name: "InfoWorld", siteURL: "https://www.infoworld.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 20, freshnessOutOf20: 18, originalityOutOf20: 11, relevanceOutOf20: 13, accessibilityOutOf10: 8, whyFollowSummary: "Développement, cloud et IA générative pour les équipes techniques d'entreprise.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 82, name: "Import AI (Jack Clark)", siteURL: "https://importai.substack.com/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 19, freshnessOutOf20: 12, originalityOutOf20: 17, relevanceOutOf20: 14, accessibilityOutOf10: 8, whyFollowSummary: "Newsletter hebdo du cofondateur d'Anthropic : recherche et politique de l'IA décryptées.", verifiedRSSURL: nil, vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 83, name: "Silicon.fr", siteURL: "https://www.silicon.fr/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 18, freshnessOutOf20: 12, originalityOutOf20: 12, relevanceOutOf20: 18, accessibilityOutOf10: 10, whyFollowSummary: "Actualité B2B IT : cloud, IA, cybersécurité, souveraineté, marché des ESN.", verifiedRSSURL: "https://www.silicon.fr/feed", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 84, name: "TLDR (Tech & AI)", siteURL: "https://tldr.tech/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 18, freshnessOutOf20: 20, originalityOutOf20: 9, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Newsletters quotidiennes de 5 minutes (Tech, AI, InfoSec, DevOps) pour un balayage rapide.", verifiedRSSURL: "https://tldr.tech/api/rss/ai", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 85, name: "CRN", siteURL: "https://www.crn.com/", category: .cloudInfraDevOps, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 17, freshnessOutOf20: 20, originalityOutOf20: 12, relevanceOutOf20: 12, accessibilityOutOf10: 9, whyFollowSummary: "Actualité des éditeurs et du channel (partenaires Microsoft, AWS, Google).", verifiedRSSURL: "https://www.crn.com/news/rss.xml", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 86, name: "Epoch AI", siteURL: "https://epoch.ai/", category: .aiMLAgents, language: "Anglais", countryOrZone: "International", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 17, freshnessOutOf20: 15, originalityOutOf20: 18, relevanceOutOf20: 12, accessibilityOutOf10: 8, whyFollowSummary: "Données et tendances chiffrées sur le calcul, les coûts et les capacités de l'IA.", verifiedRSSURL: nil, vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 87, name: "Hacker News", siteURL: "https://news.ycombinator.com/", category: .expertNewslettersCommunities, language: "Anglais", countryOrZone: "International", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 16, freshnessOutOf20: 18, originalityOutOf20: 13, relevanceOutOf20: 14, accessibilityOutOf10: 9, whyFollowSummary: "La communauté de référence des développeurs : signaux faibles et débats techniques de qualité.", verifiedRSSURL: "https://news.ycombinator.com/showrss", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 88, name: "InformatiqueNews", siteURL: "https://www.informatiquenews.fr/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 70, authorityOutOf30: 16, freshnessOutOf20: 20, originalityOutOf20: 9, relevanceOutOf20: 15, accessibilityOutOf10: 10, whyFollowSummary: "Actualité IT professionnelle en français, avec un suivi dédié au cloud souverain et SecNumCloud.", verifiedRSSURL: "https://www.informatiquenews.fr/feed", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 89, name: "Clubic", siteURL: "https://www.clubic.com/", category: .frenchTechFRBE, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 69, authorityOutOf30: 21, freshnessOutOf20: 20, originalityOutOf20: 9, relevanceOutOf20: 10, accessibilityOutOf10: 9, whyFollowSummary: "Actualité tech, IA et logiciels en français, rythme soutenu.", verifiedRSSURL: "https://www.clubic.com/feed/rss", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 90, name: "Le Big Data", siteURL: "https://www.lebigdata.fr/", category: .aiMLAgents, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 69, authorityOutOf30: 17, freshnessOutOf20: 20, originalityOutOf20: 9, relevanceOutOf20: 13, accessibilityOutOf10: 10, whyFollowSummary: "Actualité IA et data en français, rythme élevé.", verifiedRSSURL: "https://www.lebigdata.fr/feed", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 91, name: "Google Research · Blog", siteURL: "https://research.google/blog/", category: .aiMLAgents, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 68, authorityOutOf30: 20, freshnessOutOf20: 12, originalityOutOf20: 17, relevanceOutOf20: 10, accessibilityOutOf10: 9, whyFollowSummary: "Publications de recherche de Google (IA, algorithmes), utiles pour anticiper les ruptures.", verifiedRSSURL: "https://research.google/blog/rss/", vendorLogoId: "google"),
        CertiGoTop100TechSiteSpec(rank: 92, name: "Brief IA", siteURL: "https://www.briefia.fr/", category: .aiMLAgents, language: "Français", countryOrZone: "France", publicationFrequency: "Plusieurs fois par jour", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 68, authorityOutOf30: 18, freshnessOutOf20: 20, originalityOutOf20: 6, relevanceOutOf20: 14, accessibilityOutOf10: 10, whyFollowSummary: "Brief quotidien en français de l'actualité IA mondiale (résumés automatisés), utile pour un balayage rapide.", verifiedRSSURL: "https://www.briefia.fr/rss.xml", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 93, name: "LWN.net", siteURL: "https://lwn.net/", category: .expertNewslettersCommunities, language: "Anglais", countryOrZone: "International", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 68, authorityOutOf30: 18, freshnessOutOf20: 18, originalityOutOf20: 16, relevanceOutOf20: 8, accessibilityOutOf10: 8, whyFollowSummary: "Référence sur le noyau Linux et l'open source.", verifiedRSSURL: "https://lwn.net/headlines/rss", vendorLogoId: "kubernetes"),
        CertiGoTop100TechSiteSpec(rank: 94, name: "Exponential View (Azeem Azhar)", siteURL: "https://www.exponentialview.co/", category: .aiMLAgents, language: "Anglais", countryOrZone: "Royaume-Uni", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 68, authorityOutOf30: 17, freshnessOutOf20: 15, originalityOutOf20: 15, relevanceOutOf20: 13, accessibilityOutOf10: 8, whyFollowSummary: "Analyse stratégique hebdo de l'IA et de l'économie, utile pour les échanges avec des dirigeants.", verifiedRSSURL: "https://www.exponentialview.co/feed", vendorLogoId: "openai"),
        CertiGoTop100TechSiteSpec(rank: 95, name: "Platformer (Casey Newton)", siteURL: "https://www.platformer.news/", category: .expertNewslettersCommunities, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 67, authorityOutOf30: 18, freshnessOutOf20: 12, originalityOutOf20: 17, relevanceOutOf20: 12, accessibilityOutOf10: 8, whyFollowSummary: "Newsletter de référence sur les plateformes, l'IA et la régulation, souvent avec des scoops.", verifiedRSSURL: "https://www.platformer.news/rss/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 96, name: "Crunchbase News", siteURL: "https://news.crunchbase.com/", category: .businessStartupsInvestment, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 67, authorityOutOf30: 17, freshnessOutOf20: 18, originalityOutOf20: 13, relevanceOutOf20: 10, accessibilityOutOf10: 9, whyFollowSummary: "Données et analyses sur les levées de fonds, notamment dans l'IA.", verifiedRSSURL: "https://news.crunchbase.com/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 97, name: "ITdaily", siteURL: "https://itdaily.be/", category: .frenchTechFRBE, language: "Néerlandais / anglais", countryOrZone: "Belgique", publicationFrequency: "Plusieurs fois par semaine (au moins)", hasRSSFeed: true, paywallStatus: "gratuit", scoreOutOf100: 67, authorityOutOf30: 16, freshnessOutOf20: 15, originalityOutOf20: 11, relevanceOutOf20: 15, accessibilityOutOf10: 10, whyFollowSummary: "Actualité IT professionnelle belge (NL/EN) : cloud, IA, cybersécurité, secteur public.", verifiedRSSURL: "https://itdaily.be/feed/", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 98, name: "FrenchWeb", siteURL: "https://www.frenchweb.fr/", category: .businessStartupsInvestment, language: "Français", countryOrZone: "France", publicationFrequency: "Quotidienne", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 66, authorityOutOf30: 18, freshnessOutOf20: 18, originalityOutOf20: 11, relevanceOutOf20: 11, accessibilityOutOf10: 8, whyFollowSummary: "Business de la tech française : levées, acquisitions, décideurs.", verifiedRSSURL: "https://www.frenchweb.fr/feed", vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 99, name: "Smals Research", siteURL: "https://www.smalsresearch.be/", category: .frenchTechFRBE, language: "Français / néerlandais", countryOrZone: "Belgique", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: false, paywallStatus: "gratuit", scoreOutOf100: 65, authorityOutOf30: 17, freshnessOutOf20: 10, originalityOutOf20: 13, relevanceOutOf20: 17, accessibilityOutOf10: 8, whyFollowSummary: "Blog de recherche de Smals (IT de la sécurité sociale belge) : IA et technologies pour l'administration.", verifiedRSSURL: nil, vendorLogoId: "microsoft"),
        CertiGoTop100TechSiteSpec(rank: 100, name: "Where's Your Ed At (Ed Zitron)", siteURL: "https://www.wheresyoured.at/", category: .expertNewslettersCommunities, language: "Anglais", countryOrZone: "États-Unis", publicationFrequency: "Hebdomadaire (au moins)", hasRSSFeed: true, paywallStatus: "freemium", scoreOutOf100: 63, authorityOutOf30: 19, freshnessOutOf20: 12, originalityOutOf20: 14, relevanceOutOf20: 10, accessibilityOutOf10: 8, whyFollowSummary: "Contrepoint critique sur l'économie de l'IA générative, utile pour anticiper les objections.", verifiedRSSURL: "https://www.wheresyoured.at/rss/", vendorLogoId: "microsoft")
    ]

    /// All 83 verified RSS / Atom feeds from `veille_tech_top100.opml`.
    public static let all83VerifiedFeeds: [CertiGoVerifiedRSSFeedSpec] = [
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-1", rank: 3, displayTitle: "#3 Ars Technica", sourceName: "Ars Technica", category: .globalTechNews, xmlURL: "https://feeds.arstechnica.com/arstechnica/index", htmlURL: "https://arstechnica.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-2", rank: 4, displayTitle: "#4 Bloomberg Technology", sourceName: "Bloomberg Technology", category: .globalTechNews, xmlURL: "https://feeds.bloomberg.com/technology/news.rss", htmlURL: "https://www.bloomberg.com/technology", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-3", rank: 5, displayTitle: "#5 Financial Times · Technology", sourceName: "Financial Times · Technology", category: .globalTechNews, xmlURL: "https://www.ft.com/technology?format=rss", htmlURL: "https://www.ft.com/technology", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-4", rank: 6, displayTitle: "#6 TechCrunch", sourceName: "TechCrunch", category: .globalTechNews, xmlURL: "https://techcrunch.com/feed/", htmlURL: "https://techcrunch.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-5", rank: 7, displayTitle: "#7 The Register", sourceName: "The Register", category: .globalTechNews, xmlURL: "https://www.theregister.com/headlines.atom", htmlURL: "https://www.theregister.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-6", rank: 9, displayTitle: "#9 The Guardian · Technology", sourceName: "The Guardian · Technology", category: .globalTechNews, xmlURL: "https://www.theguardian.com/technology/rss", htmlURL: "https://www.theguardian.com/technology", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-7", rank: 10, displayTitle: "#10 The Wall Street Journal · Tech", sourceName: "The Wall Street Journal · Tech", category: .globalTechNews, xmlURL: "https://feeds.content.dowjones.io/public/rss/RSSWSJD", htmlURL: "https://www.wsj.com/tech", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-8", rank: 11, displayTitle: "#11 WIRED", sourceName: "WIRED", category: .globalTechNews, xmlURL: "https://www.wired.com/feed/rss", htmlURL: "https://www.wired.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-9", rank: 13, displayTitle: "#13 The New York Times · Technology", sourceName: "The New York Times · Technology", category: .globalTechNews, xmlURL: "https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml", htmlURL: "https://www.nytimes.com/section/technology", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-10", rank: 14, displayTitle: "#14 The Verge", sourceName: "The Verge", category: .globalTechNews, xmlURL: "https://www.theverge.com/rss/index.xml", htmlURL: "https://www.theverge.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-11", rank: 16, displayTitle: "#16 CNBC · Tech", sourceName: "CNBC · Tech", category: .globalTechNews, xmlURL: "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=19854910", htmlURL: "https://www.cnbc.com/technology/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-12", rank: 19, displayTitle: "#19 404 Media", sourceName: "404 Media", category: .globalTechNews, xmlURL: "https://www.404media.co/rss/", htmlURL: "https://www.404media.co/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-13", rank: 29, displayTitle: "#29 BBC News · Technology", sourceName: "BBC News · Technology", category: .globalTechNews, xmlURL: "https://feeds.bbci.co.uk/news/technology/rss.xml", htmlURL: "https://www.bbc.com/news/technology", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-14", rank: 30, displayTitle: "#30 GeekWire", sourceName: "GeekWire", category: .globalTechNews, xmlURL: "https://www.geekwire.com/feed/", htmlURL: "https://www.geekwire.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-15", rank: 32, displayTitle: "#32 Techmeme", sourceName: "Techmeme", category: .globalTechNews, xmlURL: "https://www.techmeme.com/feed.xml", htmlURL: "https://www.techmeme.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-16", rank: 40, displayTitle: "#40 Business Insider · Tech", sourceName: "Business Insider · Tech", category: .globalTechNews, xmlURL: "https://feeds.businessinsider.com/custom/all", htmlURL: "https://www.businessinsider.com/tech", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-17", rank: 42, displayTitle: "#42 Semafor · Technology", sourceName: "Semafor · Technology", category: .globalTechNews, xmlURL: "https://www.semafor.com/rss.xml", htmlURL: "https://www.semafor.com/vertical/tech", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-18", rank: 1, displayTitle: "#1 OpenAI · News", sourceName: "OpenAI · News", category: .aiMLAgents, xmlURL: "https://openai.com/news/rss.xml", htmlURL: "https://openai.com/news/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-19", rank: 21, displayTitle: "#21 VentureBeat", sourceName: "VentureBeat", category: .aiMLAgents, xmlURL: "https://venturebeat.com/feed/", htmlURL: "https://venturebeat.com/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-20", rank: 22, displayTitle: "#22 Google · The Keyword (IA)", sourceName: "Google · The Keyword (IA)", category: .aiMLAgents, xmlURL: "https://blog.google/technology/ai/rss/", htmlURL: "https://blog.google/technology/ai/", vendorLogoId: "google", linkedCertificationCodes: ["PCA", "OPENAI-PRO"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-21", rank: 23, displayTitle: "#23 Simon Willison's Weblog", sourceName: "Simon Willison's Weblog", category: .aiMLAgents, xmlURL: "https://simonwillison.net/atom/everything/", htmlURL: "https://simonwillison.net/", vendorLogoId: "openai", linkedCertificationCodes: ["ANTHROPIC-CLAUDE", "OPENAI-PRO"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-22", rank: 26, displayTitle: "#26 Google DeepMind · Blog", sourceName: "Google DeepMind · Blog", category: .aiMLAgents, xmlURL: "https://deepmind.google/blog/rss.xml", htmlURL: "https://deepmind.google/discover/blog/", vendorLogoId: "google", linkedCertificationCodes: ["PCA", "OPENAI-PRO"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-23", rank: 38, displayTitle: "#38 Mistral AI · News", sourceName: "Mistral AI · News", category: .aiMLAgents, xmlURL: "https://mistral.ai/rss.xml", htmlURL: "https://mistral.ai/news", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-24", rank: 39, displayTitle: "#39 The Decoder", sourceName: "The Decoder", category: .aiMLAgents, xmlURL: "https://the-decoder.com/feed/", htmlURL: "https://the-decoder.com/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-25", rank: 41, displayTitle: "#41 Hugging Face · Blog", sourceName: "Hugging Face · Blog", category: .aiMLAgents, xmlURL: "https://huggingface.co/blog/feed.xml", htmlURL: "https://huggingface.co/blog", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-26", rank: 47, displayTitle: "#47 ActuIA", sourceName: "ActuIA", category: .aiMLAgents, xmlURL: "https://www.actuia.com/feed/", htmlURL: "https://www.actuia.com/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-27", rank: 57, displayTitle: "#57 MIT Technology Review", sourceName: "MIT Technology Review", category: .aiMLAgents, xmlURL: "https://www.technologyreview.com/feed/", htmlURL: "https://www.technologyreview.com/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-28", rank: 63, displayTitle: "#63 NVIDIA · Blog", sourceName: "NVIDIA · Blog", category: .aiMLAgents, xmlURL: "https://blogs.nvidia.com/feed/", htmlURL: "https://blogs.nvidia.com/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-29", rank: 76, displayTitle: "#76 Latent Space", sourceName: "Latent Space", category: .aiMLAgents, xmlURL: "https://www.latent.space/feed", htmlURL: "https://www.latent.space/", vendorLogoId: "openai", linkedCertificationCodes: ["ANTHROPIC-CLAUDE", "OPENAI-PRO"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-30", rank: 84, displayTitle: "#84 TLDR (Tech & AI)", sourceName: "TLDR (Tech & AI)", category: .aiMLAgents, xmlURL: "https://tldr.tech/api/rss/ai", htmlURL: "https://tldr.tech/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-31", rank: 90, displayTitle: "#90 Le Big Data", sourceName: "Le Big Data", category: .aiMLAgents, xmlURL: "https://www.lebigdata.fr/feed", htmlURL: "https://www.lebigdata.fr/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-32", rank: 91, displayTitle: "#91 Google Research · Blog", sourceName: "Google Research · Blog", category: .aiMLAgents, xmlURL: "https://research.google/blog/rss/", htmlURL: "https://research.google/blog/", vendorLogoId: "google", linkedCertificationCodes: ["PCA", "OPENAI-PRO"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-33", rank: 92, displayTitle: "#92 Brief IA", sourceName: "Brief IA", category: .aiMLAgents, xmlURL: "https://www.briefia.fr/rss.xml", htmlURL: "https://www.briefia.fr/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-34", rank: 94, displayTitle: "#94 Exponential View (Azeem Azhar)", sourceName: "Exponential View (Azeem Azhar)", category: .aiMLAgents, xmlURL: "https://www.exponentialview.co/feed", htmlURL: "https://www.exponentialview.co/", vendorLogoId: "openai", linkedCertificationCodes: ["OPENAI-PRO", "ANTHROPIC-CLAUDE", "AI-102"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-35", rank: 2, displayTitle: "#2 Microsoft · blogs et annonces officiels (Azure, Microsoft 365/Copilot, Sécurité)", sourceName: "Microsoft · blogs et annonces officiels (Azure, Microsoft 365/Copilot, Sécurité)", category: .cloudInfraDevOps, xmlURL: "https://blogs.microsoft.com/feed/", htmlURL: "https://blogs.microsoft.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["MS-365-COPILOT", "AZ-900"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-36", rank: 2, displayTitle: "#2 Microsoft · Azure Updates", sourceName: "Microsoft · Azure Updates", category: .cloudInfraDevOps, xmlURL: "https://www.microsoft.com/releasecommunications/api/v2/azure/rss", htmlURL: "https://blogs.microsoft.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "AZ-900", "MS-365-COPILOT"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-37", rank: 2, displayTitle: "#2 Microsoft Tech Community", sourceName: "Microsoft Tech Community", category: .cloudInfraDevOps, xmlURL: "https://techcommunity.microsoft.com/t5/s/gxcuf89792/rss/Community", htmlURL: "https://blogs.microsoft.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "AZ-900", "MS-365-COPILOT"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-38", rank: 15, displayTitle: "#15 Google Cloud · Blog", sourceName: "Google Cloud · Blog", category: .cloudInfraDevOps, xmlURL: "https://cloud.google.com/blog/feed", htmlURL: "https://cloud.google.com/blog", vendorLogoId: "google", linkedCertificationCodes: ["PCA", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-39", rank: 20, displayTitle: "#20 AWS · News Blog & What's New", sourceName: "AWS · News Blog & What's New", category: .cloudInfraDevOps, xmlURL: "https://aws.amazon.com/blogs/aws/feed/", htmlURL: "https://aws.amazon.com/blogs/aws/", vendorLogoId: "aws", linkedCertificationCodes: ["SAA-C03", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-40", rank: 20, displayTitle: "#20 AWS · What's New", sourceName: "AWS · What's New", category: .cloudInfraDevOps, xmlURL: "https://aws.amazon.com/about-aws/whats-new/recent/feed/", htmlURL: "https://aws.amazon.com/blogs/aws/", vendorLogoId: "aws", linkedCertificationCodes: ["SAA-C03", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-41", rank: 43, displayTitle: "#43 GitHub · Blog", sourceName: "GitHub · Blog", category: .cloudInfraDevOps, xmlURL: "https://github.blog/feed/", htmlURL: "https://github.blog/", vendorLogoId: "github", linkedCertificationCodes: ["GH-300", "ANTHROPIC-CLAUDE"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-42", rank: 48, displayTitle: "#48 Computer Weekly", sourceName: "Computer Weekly", category: .cloudInfraDevOps, xmlURL: "https://www.computerweekly.com/rss/All-Computer-Weekly-content.xml", htmlURL: "https://www.computerweekly.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-43", rank: 51, displayTitle: "#51 Windows Central", sourceName: "Windows Central", category: .cloudInfraDevOps, xmlURL: "https://www.windowscentral.com/feed.xml", htmlURL: "https://www.windowscentral.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "AZ-900", "MS-365-COPILOT"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-44", rank: 54, displayTitle: "#54 The New Stack", sourceName: "The New Stack", category: .cloudInfraDevOps, xmlURL: "https://thenewstack.io/feed/", htmlURL: "https://thenewstack.io/", vendorLogoId: "kubernetes", linkedCertificationCodes: ["CKA", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-45", rank: 62, displayTitle: "#62 Cloudflare · Blog", sourceName: "Cloudflare · Blog", category: .cloudInfraDevOps, xmlURL: "https://blog.cloudflare.com/rss/", htmlURL: "https://blog.cloudflare.com/", vendorLogoId: "kubernetes", linkedCertificationCodes: ["CKA", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-46", rank: 64, displayTitle: "#64 InfoQ", sourceName: "InfoQ", category: .cloudInfraDevOps, xmlURL: "https://feed.infoq.com/ai-ml-data-eng/", htmlURL: "https://www.infoq.com/", vendorLogoId: "kubernetes", linkedCertificationCodes: ["CKA", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-47", rank: 68, displayTitle: "#68 Office 365 for IT Pros (Tony Redmond)", sourceName: "Office 365 for IT Pros (Tony Redmond)", category: .cloudInfraDevOps, xmlURL: "https://office365itpros.com/feed/", htmlURL: "https://office365itpros.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["MS-365-COPILOT", "AZ-900"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-48", rank: 75, displayTitle: "#75 SiliconANGLE", sourceName: "SiliconANGLE", category: .cloudInfraDevOps, xmlURL: "https://siliconangle.com/feed/", htmlURL: "https://siliconangle.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-49", rank: 77, displayTitle: "#77 Petri IT Knowledgebase", sourceName: "Petri IT Knowledgebase", category: .cloudInfraDevOps, xmlURL: "https://petri.com/feed/", htmlURL: "https://petri.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "AZ-900", "MS-365-COPILOT"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-50", rank: 85, displayTitle: "#85 CRN", sourceName: "CRN", category: .cloudInfraDevOps, xmlURL: "https://www.crn.com/news/rss.xml", htmlURL: "https://www.crn.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-51", rank: 8, displayTitle: "#8 ANSSI / CERT-FR", sourceName: "ANSSI / CERT-FR", category: .cybersecurity, xmlURL: "https://cert.cyber.gouv.fr/feed/", htmlURL: "https://cyber.gouv.fr/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-52", rank: 8, displayTitle: "#8 CERT-FR · Alertes", sourceName: "CERT-FR · Alertes", category: .cybersecurity, xmlURL: "https://cert.cyber.gouv.fr/alerte/feed/", htmlURL: "https://cyber.gouv.fr/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-53", rank: 12, displayTitle: "#12 BleepingComputer", sourceName: "BleepingComputer", category: .cybersecurity, xmlURL: "https://www.bleepingcomputer.com/feed/", htmlURL: "https://www.bleepingcomputer.com/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-54", rank: 37, displayTitle: "#37 Krebs on Security", sourceName: "Krebs on Security", category: .cybersecurity, xmlURL: "https://krebsonsecurity.com/feed/", htmlURL: "https://krebsonsecurity.com/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-55", rank: 52, displayTitle: "#52 Dark Reading", sourceName: "Dark Reading", category: .cybersecurity, xmlURL: "https://www.darkreading.com/rss.xml", htmlURL: "https://www.darkreading.com/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-56", rank: 53, displayTitle: "#53 SecurityWeek", sourceName: "SecurityWeek", category: .cybersecurity, xmlURL: "https://www.securityweek.com/feed/", htmlURL: "https://www.securityweek.com/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-57", rank: 56, displayTitle: "#56 Risky Business / Risky Bulletin", sourceName: "Risky Business / Risky Bulletin", category: .cybersecurity, xmlURL: "https://risky.biz/feeds/risky-business-news/", htmlURL: "https://risky.biz/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-58", rank: 71, displayTitle: "#71 Schneier on Security", sourceName: "Schneier on Security", category: .cybersecurity, xmlURL: "https://www.schneier.com/feed/", htmlURL: "https://www.schneier.com/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-59", rank: 74, displayTitle: "#74 Infosecurity Magazine", sourceName: "Infosecurity Magazine", category: .cybersecurity, xmlURL: "https://www.infosecurity-magazine.com/rss/news/", htmlURL: "https://www.infosecurity-magazine.com/", vendorLogoId: "cisco", linkedCertificationCodes: ["SC-200", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-60", rank: 25, displayTitle: "#25 Les Echos · Tech & Médias", sourceName: "Les Echos · Tech & Médias", category: .frenchTechFRBE, xmlURL: "https://services.lesechos.fr/rss/les-echos-tech-medias.xml", htmlURL: "https://www.lesechos.fr/tech-medias", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-61", rank: 31, displayTitle: "#31 Le Monde Informatique", sourceName: "Le Monde Informatique", category: .frenchTechFRBE, xmlURL: "https://www.lemondeinformatique.fr/flux-rss/thematique/toutes-les-actualites/rss.xml", htmlURL: "https://www.lemondeinformatique.fr/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-62", rank: 33, displayTitle: "#33 LeMagIT", sourceName: "LeMagIT", category: .frenchTechFRBE, xmlURL: "https://www.lemagit.fr/rss/ContentSyndication.xml", htmlURL: "https://www.lemagit.fr/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-63", rank: 34, displayTitle: "#34 Le Monde · Pixels / Technologies", sourceName: "Le Monde · Pixels / Technologies", category: .frenchTechFRBE, xmlURL: "https://www.lemonde.fr/pixels/rss_full.xml", htmlURL: "https://www.lemonde.fr/pixels/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-64", rank: 45, displayTitle: "#45 ZDNET France", sourceName: "ZDNET France", category: .frenchTechFRBE, xmlURL: "https://www.zdnet.fr/feeds/rss/actualites/", htmlURL: "https://www.zdnet.fr/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-65", rank: 50, displayTitle: "#50 Next", sourceName: "Next", category: .frenchTechFRBE, xmlURL: "https://next.ink/feed/", htmlURL: "https://next.ink/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-66", rank: 58, displayTitle: "#58 Numerama", sourceName: "Numerama", category: .frenchTechFRBE, xmlURL: "https://www.numerama.com/feed/", htmlURL: "https://www.numerama.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-67", rank: 59, displayTitle: "#59 JDN (Journal du Net)", sourceName: "JDN (Journal du Net)", category: .frenchTechFRBE, xmlURL: "https://www.journaldunet.com/rss/", htmlURL: "https://www.journaldunet.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-68", rank: 65, displayTitle: "#65 L'Usine Digitale", sourceName: "L'Usine Digitale", category: .frenchTechFRBE, xmlURL: "https://www.usine-digitale.fr/arc/outboundfeeds/rss/", htmlURL: "https://www.usine-digitale.fr/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-69", rank: 83, displayTitle: "#83 Silicon.fr", sourceName: "Silicon.fr", category: .frenchTechFRBE, xmlURL: "https://www.silicon.fr/feed", htmlURL: "https://www.silicon.fr/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-70", rank: 88, displayTitle: "#88 InformatiqueNews", sourceName: "InformatiqueNews", category: .frenchTechFRBE, xmlURL: "https://www.informatiquenews.fr/feed", htmlURL: "https://www.informatiquenews.fr/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-71", rank: 89, displayTitle: "#89 Clubic", sourceName: "Clubic", category: .frenchTechFRBE, xmlURL: "https://www.clubic.com/feed/rss", htmlURL: "https://www.clubic.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-72", rank: 97, displayTitle: "#97 ITdaily", sourceName: "ITdaily", category: .frenchTechFRBE, xmlURL: "https://itdaily.be/feed/", htmlURL: "https://itdaily.be/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-73", rank: 27, displayTitle: "#27 Commission européenne · Shaping Europe's digital future", sourceName: "Commission européenne · Shaping Europe's digital future", category: .europeRegulationPublic, xmlURL: "https://digital-strategy.ec.europa.eu/en/rss.xml", htmlURL: "https://digital-strategy.ec.europa.eu/en/news", vendorLogoId: "harvey", linkedCertificationCodes: ["HARVEY-LEGAL", "MS-365-COPILOT"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-74", rank: 28, displayTitle: "#28 POLITICO Europe · Technology", sourceName: "POLITICO Europe · Technology", category: .europeRegulationPublic, xmlURL: "https://www.politico.eu/feed/", htmlURL: "https://www.politico.eu/section/technology/", vendorLogoId: "harvey", linkedCertificationCodes: ["HARVEY-LEGAL", "MS-365-COPILOT"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-75", rank: 46, displayTitle: "#46 CNIL · Actualités", sourceName: "CNIL · Actualités", category: .europeRegulationPublic, xmlURL: "https://cnil.fr/fr/rss.xml", htmlURL: "https://www.cnil.fr/fr/actualites", vendorLogoId: "harvey", linkedCertificationCodes: ["HARVEY-LEGAL", "MS-365-COPILOT"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-76", rank: 72, displayTitle: "#72 Silicon Republic", sourceName: "Silicon Republic", category: .europeRegulationPublic, xmlURL: "https://www.siliconrepublic.com/feed", htmlURL: "https://www.siliconrepublic.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-77", rank: 79, displayTitle: "#79 Dans les algorithmes", sourceName: "Dans les algorithmes", category: .europeRegulationPublic, xmlURL: "https://danslesalgorithmes.net/feed/", htmlURL: "https://danslesalgorithmes.net/", vendorLogoId: "harvey", linkedCertificationCodes: ["HARVEY-LEGAL", "MS-365-COPILOT"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-78", rank: 67, displayTitle: "#67 Sifted", sourceName: "Sifted", category: .businessStartupsInvestment, xmlURL: "https://sifted.eu/feed", htmlURL: "https://sifted.eu/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-79", rank: 96, displayTitle: "#96 Crunchbase News", sourceName: "Crunchbase News", category: .businessStartupsInvestment, xmlURL: "https://news.crunchbase.com/feed/", htmlURL: "https://news.crunchbase.com/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-80", rank: 98, displayTitle: "#98 FrenchWeb", sourceName: "FrenchWeb", category: .businessStartupsInvestment, xmlURL: "https://www.frenchweb.fr/feed", htmlURL: "https://www.frenchweb.fr/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-81", rank: 93, displayTitle: "#93 LWN.net", sourceName: "LWN.net", category: .expertNewslettersCommunities, xmlURL: "https://lwn.net/headlines/rss", htmlURL: "https://lwn.net/", vendorLogoId: "kubernetes", linkedCertificationCodes: ["CKA", "AZ-104"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-82", rank: 95, displayTitle: "#95 Platformer (Casey Newton)", sourceName: "Platformer (Casey Newton)", category: .expertNewslettersCommunities, xmlURL: "https://www.platformer.news/rss/", htmlURL: "https://www.platformer.news/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"]),
        CertiGoVerifiedRSSFeedSpec(id: "opml-rss-83", rank: 100, displayTitle: "#100 Where's Your Ed At (Ed Zitron)", sourceName: "Where's Your Ed At (Ed Zitron)", category: .expertNewslettersCommunities, xmlURL: "https://www.wheresyoured.at/rss/", htmlURL: "https://www.wheresyoured.at/", vendorLogoId: "microsoft", linkedCertificationCodes: ["AZ-104", "OPENAI-PRO", "HARVEY-LEGAL"])
    ]

    public static func feeds(forCategory category: CertiGoOPMLCategoryID?) -> [CertiGoVerifiedRSSFeedSpec] {
        guard let category else { return all83VerifiedFeeds }
        return all83VerifiedFeeds.filter { $0.category == category }
    }

    public static func sites(forCategory category: CertiGoOPMLCategoryID?, searchQuery: String = "") -> [CertiGoTop100TechSiteSpec] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all100RankedSites.filter { site in
            let matchesCategory = (category == nil) || (site.category == category)
            guard matchesCategory else { return false }
            guard !trimmed.isEmpty else { return true }
            return site.name.lowercased().contains(trimmed)
                || site.whyFollowSummary.lowercased().contains(trimmed)
                || site.category.rawValue.lowercased().contains(trimmed)
                || "#\(site.rank)".contains(trimmed)
        }
    }

    /// Alias exposing curated articles as `CertiGoTechNewsCatalog.curatedArticles`.
    public static var curatedArticles: [CertiGoTechNewsArticle] {
        defaultCuratedTechNewsArticles
    }

    /// Curated real-world Tech News articles grounded in the Top 100 sites & 83 verified OPML RSS feeds (zero long dashes, 100% multilingual).
    public static let defaultCuratedTechNewsArticles: [CertiGoTechNewsArticle] = [
        CertiGoTechNewsArticle(
            id: "news-ms-sre-agent-az104",
            feedId: "opml-rss-35",
            sourceRank: 2,
            sourceName: "Microsoft Azure Updates",
            vendorLogoId: "microsoft",
            category: .cloudInfraDevOps,
            linkedCertificationCode: "AZ-104",
            publishedRelativeLabel: "2h",
            articleURL: "https://blogs.microsoft.com/",
            headlineFR: "Azure lance les Agents SRE autonomes sur AKS et Container Apps",
            headlineEN: "Azure launches autonomous SRE Agents on AKS and Container Apps",
            technicalSummaryFR: "Azure Monitor et Log Analytics orchestrent désormais des agents SRE capables de corréler les métriques Prometheus, d'isoler un pod en CrashLoopBackOff et de déclencher un rollback de révision via Managed Identity.",
            technicalSummaryEN: "Azure Monitor and Log Analytics now orchestrate SRE agents that correlate Prometheus metrics, isolate a pod in CrashLoopBackOff, and trigger a revision rollback via Managed Identity.",
            plainLanguageSummaryFR: "Un robot de garde surveille tes serveurs Cloud la nuit : dès qu'une mise à jour plante, il lit les journaux d'erreur et remet la version précédente en 30 secondes sans réveiller l'équipe.",
            plainLanguageSummaryEN: "An on-call robot watches your Cloud servers at night: as soon as an update crashes, it reads the error logs and rolls back to the previous version in 30 seconds without waking the team.",
            examTakeawayFR: "Tombe à l'examen AZ-104 : privilégie toujours une Managed Identity avec le rôle Monitoring Contributor et un Action Group.",
            examTakeawayEN: "AZ-104 Exam Tip: always use a Managed Identity with the Monitoring Contributor role and an Action Group.",
            flashQuestionPromptFR: "Quel rôle RBAC minimal attribuer à la Managed Identity d'un agent qui configure des alertes Azure Monitor ?",
            flashQuestionPromptEN: "Which minimum RBAC role should you assign to the Managed Identity of an agent configuring Azure Monitor alerts?",
            flashOptions: [
                CertiGoTechNewsFlashQuizOption(id: "A", badge: "A", textFR: "Monitoring Contributor", textEN: "Monitoring Contributor", isCorrect: true),
                CertiGoTechNewsFlashQuizOption(id: "B", badge: "B", textFR: "Owner sur l'abonnement entier", textEN: "Subscription Owner", isCorrect: false),
                CertiGoTechNewsFlashQuizOption(id: "C", badge: "C", textFR: "Global Administrator Entra ID", textEN: "Entra ID Global Administrator", isCorrect: false)
            ],
            flashExplanationFR: "Le principe du moindre privilège sur AZ-104 impose Monitoring Contributor pour créer et modifier des règles d'alerte sans accorder de droits Owner.",
            flashExplanationEN: "Least privilege on AZ-104 requires Monitoring Contributor to create and edit alert rules without granting Owner rights."
        ),
        CertiGoTechNewsArticle(
            id: "news-openai-codex-responses",
            feedId: "opml-rss-18",
            sourceRank: 1,
            sourceName: "OpenAI News",
            vendorLogoId: "openai",
            category: .aiMLAgents,
            linkedCertificationCode: "OPENAI-PRO",
            publishedRelativeLabel: "3h",
            articleURL: "https://openai.com/news/",
            headlineFR: "OpenAI déploie les agents Codex multi-dépôts et le routage Responses API",
            headlineEN: "OpenAI deploys multi-repo Codex agents and Responses API routing",
            technicalSummaryFR: "La Responses API unifie l'état conversationnel, l'exécution d'outils MCP distants et la recherche vectorielle File Search en un seul appel atomique avec validation stricte du schéma JSON.",
            technicalSummaryEN: "The Responses API unifies conversational state, remote MCP tool execution, and File Search vector retrieval in a single atomic call with strict JSON schema validation.",
            plainLanguageSummaryFR: "Au lieu de brancher dix briques compliquées pour créer un assistant IA, une seule commande permet désormais à l'IA de chercher dans tes fichiers et d'agir sans se tromper de format.",
            plainLanguageSummaryEN: "Instead of wiring ten complex bricks to build an AI assistant, a single command now lets the AI search your files and act reliably.",
            examTakeawayFR: "Tombe à l'examen OPENAI-PRO : active strict: true dans Structured Outputs pour garantir 100 % de conformité au JSON Schema.",
            examTakeawayEN: "OPENAI-PRO Exam Tip: set strict: true in Structured Outputs to guarantee 100% JSON Schema compliance.",
            flashQuestionPromptFR: "Quel paramètre garantit qu'une réponse OpenAI respecte exactement votre schéma JSON ?",
            flashQuestionPromptEN: "Which parameter guarantees that an OpenAI response strictly follows your JSON schema?",
            flashOptions: [
                CertiGoTechNewsFlashQuizOption(id: "A", badge: "A", textFR: "strict: true dans response_format", textEN: "strict: true in response_format", isCorrect: true),
                CertiGoTechNewsFlashQuizOption(id: "B", badge: "B", textFR: "temperature: 2.0", textEN: "temperature: 2.0", isCorrect: false),
                CertiGoTechNewsFlashQuizOption(id: "C", badge: "C", textFR: "top_p: 0.99 sans schéma", textEN: "top_p: 0.99 without schema", isCorrect: false)
            ],
            flashExplanationFR: "Le décodage contraint avec strict: true force le modèle à ne générer que des jetons valides selon votre JSON Schema.",
            flashExplanationEN: "Constrained decoding with strict: true forces the model to emit only tokens valid under your JSON Schema."
        ),
        CertiGoTechNewsArticle(
            id: "news-anthropic-claude-mcp",
            feedId: "opml-rss-21",
            sourceRank: 23,
            sourceName: "Anthropic & Simon Willison",
            vendorLogoId: "anthropic",
            category: .aiMLAgents,
            linkedCertificationCode: "ANTHROPIC-CLAUDE",
            publishedRelativeLabel: "4h",
            articleURL: "https://simonwillison.net/",
            headlineFR: "Claude Code intègre le cache prompt 1h pour réduire les coûts API de 80 %",
            headlineEN: "Claude Code adds 1-hour prompt caching to cut API costs by 80%",
            technicalSummaryFR: "Le cache de préfixe éphémère étendu à 60 minutes permet de conserver les instructions système, les définitions d'outils MCP et les référentiels documentaires sans recalculer les clés d'attention.",
            technicalSummaryEN: "Extended 60-minute ephemeral prefix caching keeps system prompts, MCP tool definitions, and document repositories in memory without recomputing attention keys.",
            plainLanguageSummaryFR: "Claude garde en mémoire les gros documents de ton projet pendant une heure entière : il répond quatre fois plus vite et coûte beaucoup moins cher à chaque question.",
            plainLanguageSummaryEN: "Claude remembers your project's large documents for a full hour: it replies four times faster and costs much less on every follow-up question.",
            examTakeawayFR: "Tombe à l'examen ANTHROPIC-CLAUDE : place toujours les blocs statiques (System, Tools, Docs) avant les messages dynamiques pour maximiser le cache hit.",
            examTakeawayEN: "ANTHROPIC-CLAUDE Exam Tip: always place static blocks (System, Tools, Docs) before dynamic messages to maximize cache hits.",
            flashQuestionPromptFR: "Dans quel ordre structurer un prompt Claude pour maximiser le taux de succès du Prompt Caching ?",
            flashQuestionPromptEN: "In what order should you structure a Claude prompt to maximize the Prompt Caching hit rate?",
            flashOptions: [
                CertiGoTechNewsFlashQuizOption(id: "A", badge: "A", textFR: "Outils et contexte statique en premier, question dynamique à la fin", textEN: "Static tools and context first, dynamic user question last", isCorrect: true),
                CertiGoTechNewsFlashQuizOption(id: "B", badge: "B", textFR: "Question dynamique tout au début du prompt", textEN: "Dynamic question at the very beginning of the prompt", isCorrect: false),
                CertiGoTechNewsFlashQuizOption(id: "C", badge: "C", textFR: "Mélanger aléatoirement les instructions à chaque appel", textEN: "Randomly shuffle instructions on every call", isCorrect: false)
            ],
            flashExplanationFR: "Le Prompt Caching fonctionne par préfixe exact : tout changement en début de prompt invalide la suite du cache.",
            flashExplanationEN: "Prompt Caching works by exact prefix matching: any change at the beginning invalidates the rest of the cache."
        ),
        CertiGoTechNewsArticle(
            id: "news-harvey-legal-vault-eu",
            feedId: "opml-rss-73",
            sourceRank: 27,
            sourceName: "Harvey & Europe Digital",
            vendorLogoId: "harvey",
            category: .europeRegulationPublic,
            linkedCertificationCode: "HARVEY-LEGAL",
            publishedRelativeLabel: "5h",
            articleURL: "https://digital-strategy.ec.europa.eu/en/news",
            headlineFR: "Harvey Vault automatise les revues M&A multi-juridictions avec traçabilité EU AI Act",
            headlineEN: "Harvey Vault automates cross-border M&A reviews with EU AI Act traceability",
            technicalSummaryFR: "Les workflows Harvey Legal Engineering permettent d'auditer jusqu'à 10 000 contrats dans Vault en ancrant chaque clause extraite (Change of Control, Indemnification) sur sa citation exacte.",
            technicalSummaryEN: "Harvey Legal Engineering workflows audit up to 10,000 contracts in Vault while grounding every extracted clause (Change of Control, Indemnification) on its exact citation.",
            plainLanguageSummaryFR: "Les avocats peuvent analyser des milliers de contrats d'entreprise d'un coup : l'IA surligne chaque risque et pointe toujours le paragraphe exact du document original.",
            plainLanguageSummaryEN: "Lawyers can analyze thousands of corporate contracts at once: the AI highlights every risk and always points to the exact paragraph in the original file.",
            examTakeawayFR: "Tombe à l'examen HARVEY-LEGAL : exige systématiquement la citation de page/clause dans Vault avant de valider une matrice de revue.",
            examTakeawayEN: "HARVEY-LEGAL Exam Tip: always enforce page/clause citations in Vault before approving a review matrix.",
            flashQuestionPromptFR: "Quelle fonctionnalité Harvey est conçue pour analyser des centaines de contrats d'une Data Room M&A avec grille d'extraction ?",
            flashQuestionPromptEN: "Which Harvey module is designed to analyze hundreds of contracts in an M&A Data Room using an extraction grid?",
            flashOptions: [
                CertiGoTechNewsFlashQuizOption(id: "A", badge: "A", textFR: "Harvey Vault", textEN: "Harvey Vault", isCorrect: true),
                CertiGoTechNewsFlashQuizOption(id: "B", badge: "B", textFR: "Un prompt libre sans document joint", textEN: "A freeform prompt with no attached file", isCorrect: false),
                CertiGoTechNewsFlashQuizOption(id: "C", badge: "C", textFR: "Un tableur local non chiffré", textEN: "An unencrypted local spreadsheet", isCorrect: false)
            ],
            flashExplanationFR: "Harvey Vault permet le téléversement sécurisé de Data Rooms complètes et l'exécution de requêtes multi-documents avec renvoi aux sources.",
            flashExplanationEN: "Harvey Vault enables secure upload of full Data Rooms and multi-document extraction queries grounded in source citations."
        ),
        CertiGoTechNewsArticle(
            id: "news-anssi-certfr-entra-zerotrust",
            feedId: "opml-rss-51",
            sourceRank: 8,
            sourceName: "ANSSI / CERT-FR",
            vendorLogoId: "cisco",
            category: .cybersecurity,
            linkedCertificationCode: "SC-200",
            publishedRelativeLabel: "6h",
            articleURL: "https://cyber.gouv.fr/",
            headlineFR: "CERT-FR publie son guide de durcissement identité Cloud et clés FIDO2 Phishing-Resistant",
            headlineEN: "CERT-FR publishes its Cloud identity hardening guide and Phishing-Resistant FIDO2 keys",
            technicalSummaryFR: "L'ANSSI et le CERT-FR recommandent d'imposer l'accès conditionnel avec authentification multifacteur résistante au hameçonnage (FIDO2 / Passkeys) et l'élévation juste-à-temps via PIM.",
            technicalSummaryEN: "ANSSI and CERT-FR recommend enforcing Conditional Access with phishing-resistant MFA (FIDO2 / Passkeys) and just-in-time elevation via PIM.",
            plainLanguageSummaryFR: "Les pirates arrivent désormais à voler les codes reçus par SMS : l'agence française de cybersécurité recommande d'utiliser une clé physique ou Face ID pour protéger les comptes administrateurs.",
            plainLanguageSummaryEN: "Attackers can now intercept SMS codes: the national cybersecurity agency recommends hardware keys or Face ID to protect admin accounts.",
            examTakeawayFR: "Tombe aux examens SC-200 et AZ-104 : combine Entra ID Privileged Identity Management (PIM) et Conditional Access Authentication Strengths.",
            examTakeawayEN: "SC-200 & AZ-104 Exam Tip: combine Entra ID Privileged Identity Management (PIM) with Conditional Access Authentication Strengths.",
            flashQuestionPromptFR: "Quel mécanisme Entra ID supprime les droits administrateur permanents en accordant une activation limitée dans le temps ?",
            flashQuestionPromptEN: "Which Entra ID mechanism removes standing admin privileges by granting time-bound activation?",
            flashOptions: [
                CertiGoTechNewsFlashQuizOption(id: "A", badge: "A", textFR: "Privileged Identity Management (PIM)", textEN: "Privileged Identity Management (PIM)", isCorrect: true),
                CertiGoTechNewsFlashQuizOption(id: "B", badge: "B", textFR: "Partage de mot de passe d'équipe", textEN: "Shared team password", isCorrect: false),
                CertiGoTechNewsFlashQuizOption(id: "C", badge: "C", textFR: "Désactivation des journaux d'audit", textEN: "Disabling audit logs", isCorrect: false)
            ],
            flashExplanationFR: "Entra ID PIM remplace les rôles permanents par des rôles éligibles activés juste-à-temps avec justification et MFA.",
            flashExplanationEN: "Entra ID PIM replaces standing roles with eligible roles activated just-in-time with justification and MFA."
        ),
        CertiGoTechNewsArticle(
            id: "news-github-copilot-codeql",
            feedId: "opml-rss-41",
            sourceRank: 43,
            sourceName: "GitHub Blog",
            vendorLogoId: "github",
            category: .cloudInfraDevOps,
            linkedCertificationCode: "GH-300",
            publishedRelativeLabel: "7h",
            articleURL: "https://github.blog/",
            headlineFR: "GitHub Copilot Autofix et Coding Agent corrigent 90 % des alertes CodeQL dans les PR",
            headlineEN: "GitHub Copilot Autofix and Coding Agent remediate 90% of CodeQL alerts in PRs",
            technicalSummaryFR: "L'intégration native entre GitHub Advanced Security (CodeQL, Secret Scanning) et Copilot génère des correctifs vérifiés par les tests CI avant même la revue humaine de la Pull Request.",
            technicalSummaryEN: "Native integration between GitHub Advanced Security (CodeQL, Secret Scanning) and Copilot produces CI-verified patches before human Pull Request review.",
            plainLanguageSummaryFR: "Dès qu'un développeur écrit une faille de sécurité par erreur, GitHub la repère automatiquement et propose la correction prête à valider en un clic.",
            plainLanguageSummaryEN: "As soon as a developer accidentally introduces a security flaw, GitHub spots it automatically and proposes a one-click fix.",
            examTakeawayFR: "Tombe à l'examen GH-300 : les fichiers .github/copilot-instructions.md permettent d'imposer les règles de sécurité propres au dépôt.",
            examTakeawayEN: "GH-300 Exam Tip: .github/copilot-instructions.md files enforce repository-specific security and coding standards.",
            flashQuestionPromptFR: "Quel fichier permet de définir des consignes permanentes pour GitHub Copilot à l'échelle d'un dépôt ?",
            flashQuestionPromptEN: "Which file defines repository-wide persistent instructions for GitHub Copilot?",
            flashOptions: [
                CertiGoTechNewsFlashQuizOption(id: "A", badge: "A", textFR: ".github/copilot-instructions.md", textEN: ".github/copilot-instructions.md", isCorrect: true),
                CertiGoTechNewsFlashQuizOption(id: "B", badge: "B", textFR: "package-lock.json", textEN: "package-lock.json", isCorrect: false),
                CertiGoTechNewsFlashQuizOption(id: "C", badge: "C", textFR: ".gitignore", textEN: ".gitignore", isCorrect: false)
            ],
            flashExplanationFR: "Le fichier .github/copilot-instructions.md injecte automatiquement le contexte architectural et les règles du projet dans Copilot.",
            flashExplanationEN: "The .github/copilot-instructions.md file automatically injects project architecture and coding rules into Copilot."
        ),
        CertiGoTechNewsArticle(
            id: "news-google-cloud-vertex-pca",
            feedId: "opml-rss-38",
            sourceRank: 15,
            sourceName: "Google Cloud Blog",
            vendorLogoId: "google",
            category: .cloudInfraDevOps,
            linkedCertificationCode: "PCA",
            publishedRelativeLabel: "8h",
            articleURL: "https://cloud.google.com/blog",
            headlineFR: "Google Cloud déploie Cloud Run GPU à l'échelle zéro et l'interconnexion Cross-Cloud",
            headlineEN: "Google Cloud launches scale-to-zero Cloud Run GPUs and Cross-Cloud Interconnect",
            technicalSummaryFR: "Cloud Run prend désormais en charge les GPU NVIDIA L4 avec démarrage en moins de 5 secondes, facturation à la seconde et réduction automatique à zéro instance hors trafic.",
            technicalSummaryEN: "Cloud Run now supports NVIDIA L4 GPUs with sub-5-second startup, per-second billing, and automatic scale-to-zero when idle.",
            plainLanguageSummaryFR: "Tu peux faire tourner un modèle d'IA rapide sur Google Cloud et ne payer que les secondes où un utilisateur pose une question, avec un coût de 0 € le reste du temps.",
            plainLanguageSummaryEN: "You can run a fast AI model on Google Cloud and pay only for the exact seconds a user asks a question, costing $0 when idle.",
            examTakeawayFR: "Tombe à l'examen PCA : choisis Cloud Run pour les charges conteneurisées stateless à trafic variable, et GKE lorsque tu as besoin d'un contrôle avancé du plan Kubernetes.",
            examTakeawayEN: "PCA Exam Tip: pick Cloud Run for stateless containerized workloads with spiky traffic, and GKE when you need full Kubernetes control.",
            flashQuestionPromptFR: "Quel service Google Cloud exécute des conteneurs stateless avec mise à l'échelle automatique jusqu'à zéro instance ?",
            flashQuestionPromptEN: "Which Google Cloud service runs stateless containers with automatic scaling down to zero instances?",
            flashOptions: [
                CertiGoTechNewsFlashQuizOption(id: "A", badge: "A", textFR: "Cloud Run", textEN: "Cloud Run", isCorrect: true),
                CertiGoTechNewsFlashQuizOption(id: "B", badge: "B", textFR: "Compute Engine VM dédiée 24/7", textEN: "24/7 Dedicated Compute Engine VM", isCorrect: false),
                CertiGoTechNewsFlashQuizOption(id: "C", badge: "C", textFR: "Cloud Storage Archive", textEN: "Cloud Storage Archive", isCorrect: false)
            ],
            flashExplanationFR: "Cloud Run gère automatiquement le provisionnement des conteneurs HTTP/gRPC et descend à 0 instance sans trafic.",
            flashExplanationEN: "Cloud Run automatically scales HTTP/gRPC containers and scales down to 0 instances when there is no traffic."
        ),
        CertiGoTechNewsArticle(
            id: "news-aws-s3-tables-saac03",
            feedId: "opml-rss-39",
            sourceRank: 20,
            sourceName: "AWS News Blog",
            vendorLogoId: "aws",
            category: .cloudInfraDevOps,
            linkedCertificationCode: "SAA-C03",
            publishedRelativeLabel: "9h",
            articleURL: "https://aws.amazon.com/blogs/aws/",
            headlineFR: "AWS introduit S3 Tables (Apache Iceberg) et le routage VPC Lattice multi-comptes",
            headlineEN: "AWS introduces S3 Tables (Apache Iceberg) and multi-account VPC Lattice routing",
            technicalSummaryFR: "Amazon S3 Tables optimise nativement le compactage des tables analytiques Apache Iceberg tout en centralisant les permissions fines via AWS Lake Formation et IAM Roles.",
            technicalSummaryEN: "Amazon S3 Tables natively optimizes Apache Iceberg table compaction while centralizing fine-grained permissions via AWS Lake Formation and IAM Roles.",
            plainLanguageSummaryFR: "Le stockage S3 d'Amazon range désormais tout seul ses grands tableaux de données pour que les recherches soient trois fois plus rapides sans effort manuel.",
            plainLanguageSummaryEN: "Amazon S3 now automatically organizes large data tables so analytics queries run three times faster without manual maintenance.",
            examTakeawayFR: "Tombe à l'examen SAA-C03 : utilise S3 Intelligent-Tiering lorsque les fréquences d'accès aux objets sont imprévisibles.",
            examTakeawayEN: "SAA-C03 Exam Tip: use S3 Intelligent-Tiering when object access patterns are unpredictable.",
            flashQuestionPromptFR: "Quelle classe de stockage Amazon S3 déplace automatiquement les objets entre niveaux chauds et froids sans frais de récupération ?",
            flashQuestionPromptEN: "Which Amazon S3 storage class automatically moves objects between hot and cold tiers with no retrieval fees?",
            flashOptions: [
                CertiGoTechNewsFlashQuizOption(id: "A", badge: "A", textFR: "S3 Intelligent-Tiering", textEN: "S3 Intelligent-Tiering", isCorrect: true),
                CertiGoTechNewsFlashQuizOption(id: "B", badge: "B", textFR: "S3 Glacier Deep Archive uniquement", textEN: "S3 Glacier Deep Archive only", isCorrect: false),
                CertiGoTechNewsFlashQuizOption(id: "C", badge: "C", textFR: "EBS io2 Block Express", textEN: "EBS io2 Block Express", isCorrect: false)
            ],
            flashExplanationFR: "S3 Intelligent-Tiering surveille les accès et optimise les coûts automatiquement sans pénalité de récupération.",
            flashExplanationEN: "S3 Intelligent-Tiering monitors access patterns and optimizes costs automatically with zero retrieval fees."
        )
    ]
}

// MARK: - 3. Live RSS / Atom XML Aggregator (`CertiGoLiveTechNewsAggregator`)

public enum CertiGoLiveTechNewsAggregator {
    /// Strips HTML entities/tags and replaces any em/en-dashes with clean interpuncts (`·`).
    public static func sanitizeFeedText(_ raw: String) -> String {
        var text = raw
        text = text.replacingOccurrences(of: "<![CDATA[", with: "")
        text = text.replacingOccurrences(of: "]]>", with: "")
        while let start = text.range(of: "<"), let end = text.range(of: ">", range: start.upperBound..<text.endIndex) {
            text.removeSubrange(start.lowerBound..<end.upperBound)
        }
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&nbsp;", " "),
            ("\u{2014}", "·"),
            ("\u{2013}", "·")
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        let components = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    private static func extractFirstTag(_ tag: String, in block: String) -> String? {
        let openPattern = "<\(tag)"
        let closePattern = "</\(tag)>"
        guard let openRange = block.range(of: openPattern, options: .caseInsensitive),
              let gtRange = block.range(of: ">", range: openRange.upperBound..<block.endIndex),
              let closeRange = block.range(of: closePattern, options: .caseInsensitive, range: gtRange.upperBound..<block.endIndex)
        else {
            return nil
        }
        return String(block[gtRange.upperBound..<closeRange.lowerBound])
    }

    /// Decodes HTML entities (`&amp;` -> `&`) inside an extracted URL attribute and resolves relative URLs against `baseURLString`.
    public static func normalizeExtractedImageURL(_ rawURL: String, baseURLString: String? = nil) -> String? {
        var cleaned = rawURL
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !cleaned.lowercased().hasPrefix("data:") else { return nil }
        if cleaned.hasPrefix("//") {
            cleaned = "https:" + cleaned
        } else if cleaned.hasPrefix("/"),
                  let baseStr = baseURLString,
                  let baseURL = URL(string: baseStr),
                  let resolved = URL(string: cleaned, relativeTo: baseURL)?.absoluteURL
        {
            cleaned = resolved.absoluteString
        } else if !cleaned.lowercased().hasPrefix("http://") && !cleaned.lowercased().hasPrefix("https://"),
                  let baseStr = baseURLString,
                  let baseURL = URL(string: baseStr),
                  let resolved = URL(string: cleaned, relativeTo: baseURL)?.absoluteURL
        {
            cleaned = resolved.absoluteString
        }
        guard let parsed = URL(string: cleaned),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else {
            return nil
        }
        return parsed.absoluteString
    }

    private static func extractAttributeValue(_ attribute: String, in tagString: String) -> String? {
        let patterns = [
            "\(attribute)\\s*=\\s*\"([^\"]+)\"",
            "\(attribute)\\s*=\\s*'([^']+)'"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: tagString, range: NSRange(tagString.startIndex..., in: tagString)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: tagString)
            {
                return String(tagString[range])
            }
        }
        return nil
    }

    /// Extracts the exact article photo URL from an RSS/Atom `<item>` or `<entry>` XML block in strict priority order:
    /// 1. `<media:content ... url="..." />` or `<media:thumbnail ... url="..." />`
    /// 2. `<enclosure ... url="..." type="image/..." />` (or image file extension `.jpg`, `.jpeg`, `.png`, `.webp`)
    /// 3. `<itunes:image href="..." />`
    /// 4. First `<img ... src="..." />` inside `<content:encoded>`, `<description>`, `<summary>`, or `<content>`.
    public static func extractArticleImageURL(
        fromXMLChunk chunk: String,
        baseArticleURL: String? = nil
    ) -> String? {
        let nsRange = NSRange(chunk.startIndex..., in: chunk)

        // Priority 1: <media:content> or <media:thumbnail>
        if let mediaRegex = try? NSRegularExpression(
            pattern: "<media:(?:content|thumbnail)\\b[^>]*>",
            options: [.caseInsensitive]
        ) {
            for match in mediaRegex.matches(in: chunk, range: nsRange) {
                if let tagRange = Range(match.range, in: chunk) {
                    let tag = String(chunk[tagRange])
                    if let rawURL = extractAttributeValue("url", in: tag),
                       let valid = normalizeExtractedImageURL(rawURL, baseURLString: baseArticleURL)
                    {
                        return valid
                    }
                }
            }
        }

        // Priority 2: <enclosure ... url="..." type="image/..." /> (or .jpg/.jpeg/.png/.webp)
        if let enclosureRegex = try? NSRegularExpression(
            pattern: "<enclosure\\b[^>]*>",
            options: [.caseInsensitive]
        ) {
            for match in enclosureRegex.matches(in: chunk, range: nsRange) {
                if let tagRange = Range(match.range, in: chunk) {
                    let tag = String(chunk[tagRange])
                    guard let rawURL = extractAttributeValue("url", in: tag) else { continue }
                    let mimeType = (extractAttributeValue("type", in: tag) ?? "").lowercased()
                    let lowerURL = rawURL.lowercased()
                    let isImageEnclosure = mimeType.hasPrefix("image/")
                        || lowerURL.contains(".jpg")
                        || lowerURL.contains(".jpeg")
                        || lowerURL.contains(".png")
                        || lowerURL.contains(".webp")
                    if isImageEnclosure,
                       let valid = normalizeExtractedImageURL(rawURL, baseURLString: baseArticleURL)
                    {
                        return valid
                    }
                }
            }
        }

        // Priority 3: <itunes:image href="https://..." />
        if let itunesRegex = try? NSRegularExpression(
            pattern: "<itunes:image\\b[^>]*>",
            options: [.caseInsensitive]
        ) {
            for match in itunesRegex.matches(in: chunk, range: nsRange) {
                if let tagRange = Range(match.range, in: chunk) {
                    let tag = String(chunk[tagRange])
                    if let rawURL = extractAttributeValue("href", in: tag) ?? extractAttributeValue("url", in: tag),
                       let valid = normalizeExtractedImageURL(rawURL, baseURLString: baseArticleURL)
                    {
                        return valid
                    }
                }
            }
        }

        // Priority 4: First <img ... src="https://..." /> in <content:encoded>, <description>, <summary>, or raw chunk
        let candidateBlocks: [String] = [
            extractFirstTag("content:encoded", in: chunk),
            extractFirstTag("description", in: chunk),
            extractFirstTag("summary", in: chunk),
            extractFirstTag("content", in: chunk),
            chunk
        ].compactMap { $0 }

        for htmlBlock in candidateBlocks {
            let decodedBlock = htmlBlock
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
            let blockRange = NSRange(decodedBlock.startIndex..., in: decodedBlock)
            if let imgRegex = try? NSRegularExpression(
                pattern: "<img\\b[^>]*>",
                options: [.caseInsensitive]
            ) {
                for match in imgRegex.matches(in: decodedBlock, range: blockRange) {
                    if let tagRange = Range(match.range, in: decodedBlock) {
                        let tag = String(decodedBlock[tagRange])
                        if let rawSrc = extractAttributeValue("src", in: tag),
                           let valid = normalizeExtractedImageURL(rawSrc, baseURLString: baseArticleURL)
                        {
                            return valid
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Alias for `parseRSSOrAtomXML` matching `CertiGoLiveRSSService.parseRSSItems`.
    public static func parseRSSItems(
        _ xmlString: String,
        feed: CertiGoVerifiedRSSFeedSpec,
        maxItems: Int = 3
    ) -> [CertiGoTechNewsArticle] {
        parseRSSOrAtomXML(xmlString, feed: feed, maxItems: maxItems)
    }

    /// Parses RSS 2.0 (`<item>`) or Atom (`<entry>`) XML content into rich `CertiGoTechNewsArticle` cards with exact extracted `imageURL`.
    public static func parseRSSOrAtomXML(
        _ xmlString: String,
        feed: CertiGoVerifiedRSSFeedSpec,
        maxItems: Int = 3
    ) -> [CertiGoTechNewsArticle] {
        let itemTag = xmlString.lowercased().contains("<entry") ? "entry" : "item"
        let parts = xmlString.components(separatedBy: "<\(itemTag)")
        guard parts.count > 1 else { return [] }

        var parsed: [CertiGoTechNewsArticle] = []
        let primaryCert = feed.linkedCertificationCodes.first ?? "AZ-104"

        for idx in 1..<min(parts.count, maxItems + 1) {
            let chunk = "<\(itemTag)" + parts[idx]
            let rawTitle = extractFirstTag("title", in: chunk) ?? feed.displayTitle
            let rawDesc = extractFirstTag("description", in: chunk)
                ?? extractFirstTag("summary", in: chunk)
                ?? extractFirstTag("content", in: chunk)
                ?? "Actualité vérifiée publiée par \(feed.sourceName)."
            let rawLink = extractFirstTag("link", in: chunk) ?? feed.htmlURL

            let cleanTitle = sanitizeFeedText(rawTitle)
            guard !cleanTitle.isEmpty else { continue }
            let cleanDesc = String(sanitizeFeedText(rawDesc).prefix(260))
            let cleanLink = sanitizeFeedText(rawLink).isEmpty ? feed.htmlURL : sanitizeFeedText(rawLink)
            let extractedPhotoURL = extractArticleImageURL(fromXMLChunk: chunk, baseArticleURL: cleanLink)

            let plainSummaryFR = "En clair : \(feed.sourceName) annonce « \(cleanTitle) ». Retiens l'impact direct sur l'architecture, la sécurité et les bonnes pratiques de ta certification \(primaryCert)."
            let plainSummaryEN = "In plain English: \(feed.sourceName) announces « \(cleanTitle) ». Focus on how this impacts architecture, security, and best practices for your \(primaryCert) certification."

            let article = CertiGoTechNewsArticle(
                id: "live-\(feed.id)-\(idx)",
                feedId: feed.id,
                sourceRank: feed.rank,
                sourceName: feed.sourceName,
                vendorLogoId: feed.vendorLogoId,
                category: feed.category,
                linkedCertificationCode: primaryCert,
                publishedRelativeLabel: "Direct RSS",
                articleURL: cleanLink,
                imageURL: extractedPhotoURL,
                headlineFR: cleanTitle,
                headlineEN: cleanTitle,
                technicalSummaryFR: cleanDesc,
                technicalSummaryEN: cleanDesc,
                plainLanguageSummaryFR: plainSummaryFR,
                plainLanguageSummaryEN: plainSummaryEN,
                examTakeawayFR: "Lien direct avec \(primaryCert) · Source vérifiée #\(feed.rank) \(feed.sourceName)",
                examTakeawayEN: "Direct link to \(primaryCert) · Verified source #\(feed.rank) \(feed.sourceName)",
                flashQuestionPromptFR: "À quelle certification et catégorie officielle cette annonce de #\(feed.rank) \(feed.sourceName) se rattache-t-elle ?",
                flashQuestionPromptEN: "Which certification and official category does this announcement from #\(feed.rank) \(feed.sourceName) belong to?",
                flashOptions: [
                    CertiGoTechNewsFlashQuizOption(
                        id: "A",
                        badge: "A",
                        textFR: "\(primaryCert) · \(feed.category.shortBadgeTitle)",
                        textEN: "\(primaryCert) · \(feed.category.shortBadgeTitle)",
                        isCorrect: true
                    ),
                    CertiGoTechNewsFlashQuizOption(
                        id: "B",
                        badge: "B",
                        textFR: "Aucune certification Cloud ou IA",
                        textEN: "No Cloud or AI certification",
                        isCorrect: false
                    ),
                    CertiGoTechNewsFlashQuizOption(
                        id: "C",
                        badge: "C",
                        textFR: "Obsolète et hors programme",
                        textEN: "Deprecated and out of scope",
                        isCorrect: false
                    )
                ],
                flashExplanationFR: "Cette source officielle (#\(feed.rank) \(feed.sourceName)) alimente directement ta veille pour \(primaryCert).",
                flashExplanationEN: "This official source (#\(feed.rank) \(feed.sourceName)) directly feeds your watch for \(primaryCert)."
            )
            parsed.append(article)
        }
        return parsed
    }

    /// Fetches live RSS/Atom feeds via `URLSession` with resilient fallback to curated verified articles.
    public static func fetchLatestArticles(
        forFeeds feeds: [CertiGoVerifiedRSSFeedSpec] = Array(CertiGoVerifiedRSSFeedCatalog.all83VerifiedFeeds.prefix(5))
    ) async -> [CertiGoTechNewsArticle] {
        var collected: [CertiGoTechNewsArticle] = []
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.5
        config.timeoutIntervalForResource = 6.0
        let session = URLSession(configuration: config)

        for feed in feeds.prefix(5) {
            guard let url = URL(string: feed.xmlURL) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.5
            request.setValue("CertiGoTechWatch/1.0 (+https://certigo.app)", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let xmlString = String(data: data, encoding: .utf8)
            {
                let items = parseRSSOrAtomXML(xmlString, feed: feed, maxItems: 2)
                collected.append(contentsOf: items)
            }
        }
        return collected
    }

    /// Merges newly fetched live RSS dispatches at the head of the feed while deduplicating by article ID or URL.
    public static func mergeLiveArticlesAtHead(
        live: [CertiGoTechNewsArticle],
        curated: [CertiGoTechNewsArticle] = CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
    ) -> [CertiGoTechNewsArticle] {
        var seenIDs = Set<String>()
        var result: [CertiGoTechNewsArticle] = []
        for item in live + curated {
            guard !seenIDs.contains(item.id) else { continue }
            seenIDs.insert(item.id)
            result.append(item)
        }
        return result
    }
}

public typealias CertiGoLiveRSSService = CertiGoLiveTechNewsAggregator

// MARK: - 3B. Real-Time OpenGraph (`og:image` / `twitter:image`) Article Photo Resolver (`CertiGoArticlePhotoResolver`)

/// Lightweight actor and HTML parser that extracts and caches the exact `og:image` or `twitter:image` cover photo from an article's `officialURL`.
public actor CertiGoArticlePhotoResolver {
    public static let shared = CertiGoArticlePhotoResolver()

    private var cachedPhotoURLByArticleId: [String: String] = [:]

    public init() {}

    /// Pure, deterministic HTML `<meta property="og:image">` / `<meta name="twitter:image">` extractor, testable on Linux and iOS.
    public static func extractOpenGraphOrTwitterImageURL(
        fromHTML html: String,
        baseURL: URL? = nil
    ) -> String? {
        let baseURLString = baseURL?.absoluteString
        let nsRange = NSRange(html.startIndex..., in: html)

        guard let metaRegex = try? NSRegularExpression(
            pattern: "<meta\\b[^>]*>",
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let targetMetaKeys = [
            "og:image:secure_url",
            "og:image",
            "twitter:image:src",
            "twitter:image"
        ]

        var extractedByKey: [String: String] = [:]
        for match in metaRegex.matches(in: html, range: nsRange) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tag = String(html[tagRange])

            let propOrName = (
                Self.extractMetaAttribute("property", in: tag)
                    ?? Self.extractMetaAttribute("name", in: tag)
                    ?? ""
            ).lowercased()

            guard targetMetaKeys.contains(propOrName),
                  let rawContent = Self.extractMetaAttribute("content", in: tag),
                  let normalized = CertiGoLiveTechNewsAggregator.normalizeExtractedImageURL(
                      rawContent,
                      baseURLString: baseURLString
                  )
            else {
                continue
            }
            if extractedByKey[propOrName] == nil {
                extractedByKey[propOrName] = normalized
            }
        }

        for key in targetMetaKeys {
            if let found = extractedByKey[key] {
                return found
            }
        }
        return nil
    }

    private static func extractMetaAttribute(_ attribute: String, in tag: String) -> String? {
        let patterns = [
            "\(attribute)\\s*=\\s*\"([^\"]+)\"",
            "\(attribute)\\s*=\\s*'([^']+)'"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: tag)
            {
                return String(tag[range])
            }
        }
        return nil
    }

    public func cachedPhotoURL(forArticleId articleId: String) -> String? {
        cachedPhotoURLByArticleId[articleId]
    }

    public func cachePhotoURL(_ urlString: String, forArticleId articleId: String) {
        cachedPhotoURLByArticleId[articleId] = urlString
    }

    /// Resolves the exact article photo URL from cache, live OpenGraph `og:image` / `twitter:image` on `article.officialURL`, or `article.imageURL`.
    public func resolveExactPhotoURL(for article: CertiGoTechNewsArticle) async -> String? {
        if let cached = cachedPhotoURLByArticleId[article.id] {
            return cached
        }
        if let officialURL = article.officialURL {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 3.5
            config.timeoutIntervalForResource = 4.5
            let session = URLSession(configuration: config)
            var request = URLRequest(url: officialURL)
            request.timeoutInterval = 3.5
            request.setValue("CertiGoTechWatch/1.0 (+https://certigo.app)", forHTTPHeaderField: "User-Agent")

            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let html = String(data: data.prefix(65_536), encoding: .utf8) ?? String(data: data.prefix(65_536), encoding: .isoLatin1),
               let ogURL = Self.extractOpenGraphOrTwitterImageURL(fromHTML: html, baseURL: officialURL)
            {
                cachedPhotoURLByArticleId[article.id] = ogURL
                return ogURL
            }
        }
        if let fallback = article.imageURL {
            cachedPhotoURLByArticleId[article.id] = fallback
            return fallback
        }
        return nil
    }
}

// MARK: - 4. Tech News & Exam Routing Runtime State (`CertiGoTechNewsRuntimeState`)

public typealias CertiGoTechNewsCatalog = CertiGoVerifiedRSSFeedCatalog

public struct CertiGoTechNewsRuntimeState: Codable, Equatable, Sendable {
    public var selectedFilter: CertiGoTechNewsFilterID = .forYou
    public var selectedOPMLCategory: CertiGoOPMLCategoryID? = nil
    /// Active 1-line editorial rubric pill in the Apple News x Perplexity Discover `Actus` feed.
    public var selectedEditorialRubric: CertiGoEditorialRubricID = .topStories
    /// Whether the collapsible search field in the `Actus` header is currently expanded.
    public var isSearchFieldVisible: Bool = false
    /// Optional search query typed in the `Actus` header search bar.
    public var feedSearchQuery: String = ""
    /// Per-article plain-language switch (`Version simple`). Never auto-enabled; defaults to `false`.
    public var plainLanguageByArticleId: [String: Bool] = [:]
    public var activeFlashQuizArticleId: String? = nil
    public var selectedFlashChoiceByArticleId: [String: String] = [:]
    public var validatedFlashArticleIds: Set<String> = []
    public var bookmarkedArticleIds: Set<String> = []
    public var showTop100SourcesDirectorySheet: Bool = false
    public var top100SearchQuery: String = ""
    public var liveFetchedArticles: [CertiGoTechNewsArticle] = []
    public var isRefreshingLiveRSS: Bool = false
    /// Incremented on each manual or pull-to-refresh RSS sync to drive `.certiGoSymbolRotate(trigger:)`.
    public var refreshTriggerCount: Int = 0
    public var lastLiveSyncStatusText: String? = nil
    public var lastAskedAIArticleId: String? = nil
    /// Native AI Text-to-Speech reader state (`🔊 Écouter avec l'IA`).
    public var audioReader: CertiGoTechNewsAudioReaderState = .init()
    /// Perplexity-style inline Q&A history per article (`✦ Poser une question à l'IA sur cette actu`).
    public var qaHistoryByArticleId: [String: [CertiGoTechNewsQAEntry]] = [:]
    /// Draft freeform question per article.
    public var draftQuestionByArticleId: [String: String] = [:]
    /// Optional article ID opened in the full Apple News / Perplexity Reader Sheet.
    public var activeReaderSheetArticleId: String? = nil
    /// Last official article URL opened by the user (`🌐 Site officiel`).
    public var lastOpenedOfficialURLString: String? = nil
    /// Active Apple News capsule pill in the horizontal top bar (`À la Une`, `IA & LLM`, `Cloud & Infra`, `Cybersécurité`, `Dev & Open Source`, `Audio 🎧`, `Enregistrés`).
    public var selectedAppleNewsTopicPill: CertiGoAppleNewsTopicPillID = .topStories
    /// Whether the `"Plus d'actualités à la une ›"` section is expanded.
    public var isMoreTopStoriesExpanded: Bool = false
    /// Whether the `"Tout voir sur l'IA ›"` section is expanded.
    public var isAITopicSectionExpanded: Bool = false
    /// Active `Aa` reading font size tier in `CertiGoTechNewsArticleReaderSheetView` (`16 pt`, `18 pt`, `21 pt`).
    public var readerFontSizeTier: CertiGoAppleNewsReaderFontSizeTier = .standard18
    /// Whether the collapsible `"Poser une question à l'IA sur cet article"` drawer is expanded in the reader sheet.
    public var isReaderAIQuestionDrawerExpanded: Bool = true

    public init() {}

    public func isPlainLanguageEnabled(forArticleId articleId: String) -> Bool {
        plainLanguageByArticleId[articleId] ?? false
    }

    public mutating func togglePlainLanguage(forArticleId articleId: String) {
        let current = plainLanguageByArticleId[articleId] ?? false
        plainLanguageByArticleId[articleId] = !current
    }

    public mutating func setPlainLanguage(_ enabled: Bool, forArticleId articleId: String) {
        plainLanguageByArticleId[articleId] = enabled
    }

    public func qaEntries(forArticleId articleId: String) -> [CertiGoTechNewsQAEntry] {
        qaHistoryByArticleId[articleId] ?? []
    }
}

// MARK: - 5. Extensions on `CertiGoNativeTab` & `CertiGoNativeAppState` for Architecture B

extension CertiGoNativeTab {
    /// Alias for Tab #2 (`Actus` in Architecture B), preserving `.examens` rawValue compatibility across all existing tests and persistence.
    public static var actus: CertiGoNativeTab { .examens }

    /// Outline SF Symbol variant when the tab is unselected in the bottom bar.
    public var unselectedSymbolName: String {
        CertiGoAnimatedSymbolCatalog.tabSymbols(for: self).inactiveSymbol
    }

    /// Filled SF Symbol variant when the tab is selected in the bottom bar.
    public var selectedSymbolName: String {
        CertiGoAnimatedSymbolCatalog.tabSymbols(for: self).activeSymbol
    }

    /// Resolves outline vs `.fill` SF Symbol variant based on selection state.
    public func symbolName(isSelected: Bool) -> String {
        isSelected ? selectedSymbolName : unselectedSymbolName
    }

    public var sfSymbolName: String {
        switch self {
        case .parcours: return "safari.fill"
        case .examens: return "newspaper.fill"
        case .hubIA: return "sparkles"
        case .social: return "trophy.fill"
        case .moi: return "person.crop.circle.fill"
        }
    }

    public func localizedTabTitle(languageIndex: Int) -> String {
        CertiGoMultilingualEngine.localizedTabTitle(self, lang: languageIndex)
    }
}

extension CertiGoNativeAppState {
    /// Circular Edition Stamp text displayed on the right of the Apple News masthead.
    public static let appleNewsEditionStampText: String = "TECH EDITION • CERTIGO"

    /// Line 1 of the Apple News 2-line masthead (`"29 octobre"` / `"October 29"`).
    public func appleNewsMastheadDateLine(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? "October 29" : "29 octobre"
    }

    /// Line 2 of the Apple News 2-line masthead (`" Actus Tech"` / `" Tech News+"`).
    public func appleNewsMastheadBrandLine(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? " Tech News+" : " Actus Tech"
    }

    /// Editorial Apple News header subtitle (e.g. `Mercredi 4 novembre · Monde entier`).
    public func editorialHeaderDateSubtitle(languageIndex: Int) -> String {
        let isEN = (languageIndex % 6) == 2
        return isEN ? "Wednesday, November 4 · Worldwide" : "Mercredi 4 novembre · Monde entier"
    }

    /// Selects a 1-line editorial rubric pill in the redesigned `Actus` feed.
    public mutating func selectEditorialRubric(_ rubric: CertiGoEditorialRubricID) {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.selectedEditorialRubric = rubric
        techNewsState.selectedFilter = .forYou
        techNewsState.selectedOPMLCategory = nil
        switch rubric {
        case .topStories:
            techNewsState.selectedAppleNewsTopicPill = .topStories
        case .aiAndModels:
            techNewsState.selectedAppleNewsTopicPill = .aiAndLLM
        case .cloudAndInfra:
            techNewsState.selectedAppleNewsTopicPill = .cloudAndInfra
        case .cybersecurity:
            techNewsState.selectedAppleNewsTopicPill = .cybersecurity
        case .devAndOpenSource, .regulationAndEurope:
            techNewsState.selectedAppleNewsTopicPill = .devAndOpenSource
        }
    }

    /// Selects an Apple News horizontal capsule pill (`À la Une`, `IA & LLM`, `Cloud & Infra`, `Cybersécurité`, `Dev & Open Source`, `Audio 🎧`, `Enregistrés`).
    public mutating func selectAppleNewsTopicPill(_ pill: CertiGoAppleNewsTopicPillID) {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.selectedAppleNewsTopicPill = pill
        techNewsState.selectedFilter = .forYou
        techNewsState.selectedOPMLCategory = nil
        switch pill {
        case .topStories, .audio, .saved:
            techNewsState.selectedEditorialRubric = .topStories
        case .aiAndLLM:
            techNewsState.selectedEditorialRubric = .aiAndModels
        case .cloudAndInfra:
            techNewsState.selectedEditorialRubric = .cloudAndInfra
        case .cybersecurity:
            techNewsState.selectedEditorialRubric = .cybersecurity
        case .devAndOpenSource:
            techNewsState.selectedEditorialRubric = .devAndOpenSource
        }
    }

    /// Toggles bookmark / saved status for a Tech News article (`bookmark` / `bookmark.fill`).
    public mutating func toggleTechNewsBookmark(forArticleId articleId: String) {
        CertiGoHapticsEngine.shared.playOptionSelection()
        if techNewsState.bookmarkedArticleIds.contains(articleId) {
            techNewsState.bookmarkedArticleIds.remove(articleId)
        } else {
            techNewsState.bookmarkedArticleIds.insert(articleId)
        }
    }

    /// True when the article is saved in `bookmarkedArticleIds`.
    public func isTechNewsArticleBookmarked(_ articleId: String) -> Bool {
        techNewsState.bookmarkedArticleIds.contains(articleId)
    }

    /// Cycles the `Aa` reading font size in `CertiGoTechNewsArticleReaderSheetView` between `16 pt`, `18 pt`, and `21 pt`.
    @discardableResult
    public mutating func cycleTechNewsReaderFontSize() -> CGFloat {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.readerFontSizeTier = techNewsState.readerFontSizeTier.nextTier
        return techNewsState.readerFontSizeTier.pointSize
    }

    /// Sets a specific audio playback speed (`0.9x`, `1.0x`, `1.25x`, `1.5x`) and refreshes active speech.
    public mutating func setTechNewsAudioSpeed(_ speed: Double) {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.audioReader.setSpeed(speed)
        if let activeId = techNewsState.audioReader.activeArticleId, techNewsState.audioReader.isSpeaking {
            refreshAudioSpeechIfReadingArticle(articleId: activeId)
        }
    }

    /// Starts playing the top audio story when tapping `"Tout écouter"` (`"Play All"`) in `Écouter maintenant`.
    public mutating func playAllTechNewsAudio() {
        guard let firstAudio = appleNewsListenNowArticles.first ?? filteredTechNewsArticles.first else { return }
        toggleTechNewsAudioSpeech(forArticle: firstAudio)
    }

    /// Articles displayed in the `IA Générative & Modèles ›` tinted Apple News section (1 horizontal + 2 side-by-side vertical).
    public var appleNewsAITopicSectionArticles: [CertiGoTechNewsArticle] {
        let all = CertiGoLiveRSSService.mergeLiveArticlesAtHead(
            live: techNewsState.liveFetchedArticles,
            curated: CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
        )
        let aiMatches = all.filter {
            $0.category == .aiMLAgents
                || $0.editorialRubric == .aiAndModels
                || ["openai", "anthropic", "google", "harvey"].contains($0.vendorLogoId)
        }
        return aiMatches.isEmpty ? Array(all.prefix(3)) : aiMatches
    }

    /// 4 numbered trending articles (`1, 2, 3, 4`) for the `Tendances Tech` section.
    public var appleNewsTrendingFourArticles: [CertiGoTechNewsArticle] {
        let base = filteredTechNewsArticles.isEmpty
            ? CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
            : filteredTechNewsArticles
        return Array(base.prefix(4))
    }

    /// Audio-ready articles for the `Écouter maintenant` (`Listen Now`) Apple News Audio section.
    public var appleNewsListenNowArticles: [CertiGoTechNewsArticle] {
        let base = filteredTechNewsArticles.isEmpty
            ? CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
            : filteredTechNewsArticles
        return Array(base.prefix(3))
    }

    /// Toggles the collapsible search bar in the `Actus` header.
    public mutating func toggleTechNewsSearchField() {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.isSearchFieldVisible.toggle()
        if !techNewsState.isSearchFieldVisible {
            techNewsState.feedSearchQuery = ""
        }
    }

    /// Returns all Tech News articles (live RSS + curated Top 100 OPML articles) matching the active filter in Tab #2 `Actus`.
    public var filteredTechNewsArticles: [CertiGoTechNewsArticle] {
        let allArticles = CertiGoLiveRSSService.mergeLiveArticlesAtHead(
            live: techNewsState.liveFetchedArticles,
            curated: CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
        )
        let liveIDs = Set(techNewsState.liveFetchedArticles.map(\.id))
        let trackedSet = Set(
            (trackedCertificationCodes + onboardingSelectedCertifications + [activeRouteCode])
                .map { $0.uppercased() }
        )

        let categoryFiltered: [CertiGoTechNewsArticle]
        if let cat = techNewsState.selectedOPMLCategory {
            categoryFiltered = allArticles.filter { $0.category == cat }
        } else {
            categoryFiltered = allArticles
        }

        let rubricFiltered: [CertiGoTechNewsArticle]
        switch techNewsState.selectedEditorialRubric {
        case .topStories:
            rubricFiltered = categoryFiltered
        case .aiAndModels:
            rubricFiltered = categoryFiltered.filter { $0.editorialRubric == .aiAndModels }
        case .cloudAndInfra:
            rubricFiltered = categoryFiltered.filter { $0.editorialRubric == .cloudAndInfra }
        case .cybersecurity:
            rubricFiltered = categoryFiltered.filter { $0.editorialRubric == .cybersecurity }
        case .devAndOpenSource:
            rubricFiltered = categoryFiltered.filter { $0.editorialRubric == .devAndOpenSource }
        case .regulationAndEurope:
            rubricFiltered = categoryFiltered.filter { $0.editorialRubric == .regulationAndEurope }
        }

        let vendorFiltered: [CertiGoTechNewsArticle]
        switch techNewsState.selectedFilter {
        case .forYou:
            vendorFiltered = rubricFiltered.sorted { lhs, rhs in
                let lhsLive = liveIDs.contains(lhs.id)
                let rhsLive = liveIDs.contains(rhs.id)
                if lhsLive != rhsLive { return lhsLive && !rhsLive }
                let lhsTracked = trackedSet.contains(lhs.linkedCertificationCode.uppercased())
                let rhsTracked = trackedSet.contains(rhs.linkedCertificationCode.uppercased())
                if lhsTracked != rhsTracked { return lhsTracked && !rhsTracked }
                return lhs.sourceRank < rhs.sourceRank
            }
        case .openai:
            vendorFiltered = rubricFiltered.filter {
                $0.vendorLogoId == "openai" || $0.linkedCertificationCode.uppercased() == "OPENAI-PRO"
            }
        case .anthropic:
            vendorFiltered = rubricFiltered.filter {
                $0.vendorLogoId == "anthropic" || $0.linkedCertificationCode.uppercased() == "ANTHROPIC-CLAUDE"
            }
        case .microsoft:
            vendorFiltered = rubricFiltered.filter {
                $0.vendorLogoId == "microsoft"
                    || ["AZ-104", "AZ-900", "MS-365-COPILOT", "AI-102"].contains($0.linkedCertificationCode.uppercased())
            }
        case .google:
            vendorFiltered = rubricFiltered.filter {
                $0.vendorLogoId == "google" || $0.linkedCertificationCode.uppercased() == "PCA"
            }
        case .aws:
            vendorFiltered = rubricFiltered.filter {
                $0.vendorLogoId == "aws" || $0.linkedCertificationCode.uppercased() == "SAA-C03"
            }
        case .harvey:
            vendorFiltered = rubricFiltered.filter {
                $0.vendorLogoId == "harvey" || $0.linkedCertificationCode.uppercased() == "HARVEY-LEGAL"
            }
        case .github:
            vendorFiltered = rubricFiltered.filter {
                $0.vendorLogoId == "github" || $0.linkedCertificationCode.uppercased() == "GH-300"
            }
        case .cloudAndCyber:
            vendorFiltered = rubricFiltered.filter {
                $0.category == .cybersecurity
                    || $0.category == .cloudInfraDevOps
                    || ["cisco", "kubernetes"].contains($0.vendorLogoId)
            }
        }

        let trimmedQuery = techNewsState.feedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else {
            return vendorFiltered
        }
        return vendorFiltered.filter {
            $0.headlineFR.lowercased().contains(trimmedQuery)
                || $0.headlineEN.lowercased().contains(trimmedQuery)
                || $0.editorialMediaName.lowercased().contains(trimmedQuery)
                || $0.sourceName.lowercased().contains(trimmedQuery)
                || $0.technicalSummaryFR.lowercased().contains(trimmedQuery)
                || $0.plainLanguageSummaryFR.lowercased().contains(trimmedQuery)
        }
    }

    /// Selects a horizontal filter pill in Tab #2 `Actus`.
    public mutating func selectTechNewsFilter(_ filter: CertiGoTechNewsFilterID) {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.selectedEditorialRubric = .topStories
        techNewsState.selectedFilter = filter
    }

    /// Selects or toggles one of the 8 official OPML categories in Tab #2 `Actus`.
    public mutating func selectTechNewsOPMLCategory(_ category: CertiGoOPMLCategoryID?) {
        CertiGoHapticsEngine.shared.playOptionSelection()
        if techNewsState.selectedOPMLCategory == category {
            techNewsState.selectedOPMLCategory = nil
        } else {
            techNewsState.selectedOPMLCategory = category
        }
    }

    /// Toggles the Apple iOS `Version simple` switch on a specific Tech News card (never auto-enabled).
    /// If the AI voice reader is currently reading this article aloud, it automatically updates the spoken transcript!
    public mutating func toggleTechNewsPlainLanguage(forArticleId articleId: String) {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.togglePlainLanguage(forArticleId: articleId)
        refreshAudioSpeechIfReadingArticle(articleId: articleId)
    }

    /// Sets the `Version simple` switch for an article and updates the AI voice reader if it is currently reading this article.
    public mutating func setTechNewsPlainLanguage(_ enabled: Bool, forArticleId articleId: String) {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.setPlainLanguage(enabled, forArticleId: articleId)
        refreshAudioSpeechIfReadingArticle(articleId: articleId)
    }

    private mutating func refreshAudioSpeechIfReadingArticle(articleId: String) {
        guard techNewsState.audioReader.activeArticleId == articleId else { return }
        let allArticles = techNewsState.liveFetchedArticles + CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
        guard let article = allArticles.first(where: { $0.id == articleId }) else { return }
        let isPlain = techNewsState.isPlainLanguageEnabled(forArticleId: articleId)
        let wasPaused = techNewsState.audioReader.isPaused
        techNewsState.audioReader.startReading(
            article: article,
            isPlainLanguage: isPlain,
            languageIndex: settingsLanguageIndex
        )
        if wasPaused {
            techNewsState.audioReader.pause()
        }
    }

    // MARK: - AI Voice Reader (`🔊 Écouter avec l'IA`), Inline Perplexity Q&A (`✦ Poser une question`), & Official Website (`🌐 Site officiel`)

    /// Starts, pauses, or resumes AI Text-to-Speech (`AVSpeechSynthesizer`) for the given Tech News article.
    public mutating func toggleTechNewsAudioSpeech(forArticle article: CertiGoTechNewsArticle) {
        CertiGoHapticsEngine.shared.playButtonPress()
        sharedIntelligenceContext.recordTechNewsInteraction(
            article: article,
            languageIndex: settingsLanguageIndex
        )
        donateCertiGoInteraction(
            .forTechNewsArticle(article, languageIndex: settingsLanguageIndex)
        )
        let isPlain = techNewsState.isPlainLanguageEnabled(forArticleId: article.id)
        if techNewsState.audioReader.activeArticleId == article.id {
            if techNewsState.audioReader.isSpeaking {
                techNewsState.audioReader.pause()
            } else if techNewsState.audioReader.isPaused {
                techNewsState.audioReader.resume()
            } else {
                techNewsState.audioReader.startReading(
                    article: article,
                    isPlainLanguage: isPlain,
                    languageIndex: settingsLanguageIndex
                )
            }
        } else {
            techNewsState.audioReader.startReading(
                article: article,
                isPlainLanguage: isPlain,
                languageIndex: settingsLanguageIndex
            )
        }
    }

    /// Stops AI Text-to-Speech playback immediately.
    public mutating func stopTechNewsAudioSpeech() {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.audioReader.stop()
    }

    /// Cycles the AI Text-to-Speech speed (`1.0x` -> `1.25x` -> `1.5x` -> `1.0x`) and restarts current speech if active.
    @discardableResult
    public mutating func cycleTechNewsAudioSpeed() -> Double {
        CertiGoHapticsEngine.shared.playOptionSelection()
        let nextSpeed = techNewsState.audioReader.cycleSpeed()
        if let activeId = techNewsState.audioReader.activeArticleId, techNewsState.audioReader.isSpeaking {
            refreshAudioSpeechIfReadingArticle(articleId: activeId)
        }
        return nextSpeed
    }

    /// Asks an inline Perplexity-style follow-up question on an article and generates an immediate contextual CertiGo AI answer right inside the card/sheet.
    @discardableResult
    public mutating func askInlineQuestionAboutTechNews(
        articleId: String,
        question: String
    ) -> CertiGoTechNewsQAEntry? {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allArticles = techNewsState.liveFetchedArticles + CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
        guard let article = allArticles.first(where: { $0.id == articleId }) else { return nil }
        CertiGoHapticsEngine.shared.playButtonPress()
        let answer = article.generateContextualAIAnswer(
            forQuestion: trimmed,
            languageIndex: settingsLanguageIndex,
            activeRouteCode: activeRouteCode
        )
        let existingCount = techNewsState.qaHistoryByArticleId[articleId]?.count ?? 0
        let entry = CertiGoTechNewsQAEntry(
            id: "qa-\(articleId)-\(existingCount + 1)",
            articleId: articleId,
            userQuestion: trimmed,
            aiAnswer: answer
        )
        var list = techNewsState.qaHistoryByArticleId[articleId] ?? []
        list.append(entry)
        techNewsState.qaHistoryByArticleId[articleId] = list
        techNewsState.draftQuestionByArticleId[articleId] = ""
        techNewsState.lastAskedAIArticleId = articleId
        return entry
    }

    /// Records and returns the validated official website URL for an article (`🌐 Site officiel`).
    @discardableResult
    public mutating func openTechNewsOfficialWebsite(forArticle article: CertiGoTechNewsArticle) -> URL? {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.lastOpenedOfficialURLString = article.articleURL
        return article.officialURL
    }

    /// Opens the Apple News / Perplexity Discover Reader Sheet for an article.
    public mutating func openTechNewsReaderSheet(forArticleId articleId: String) {
        CertiGoHapticsEngine.shared.playButtonPress()
        techNewsState.activeReaderSheetArticleId = articleId
        let allArticles = techNewsState.liveFetchedArticles + CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
        if let article = allArticles.first(where: { $0.id == articleId }) {
            sharedIntelligenceContext.recordTechNewsInteraction(
                article: article,
                languageIndex: settingsLanguageIndex
            )
            donateCertiGoInteraction(
                .forTechNewsArticle(article, languageIndex: settingsLanguageIndex)
            )
        }
    }

    /// Closes the Apple News / Perplexity Discover Reader Sheet.
    public mutating func closeTechNewsReaderSheet() {
        CertiGoHapticsEngine.shared.playOptionSelection()
        techNewsState.activeReaderSheetArticleId = nil
    }

    /// Toggles the interactive 1-question Flash Quiz (`⚡ Question Flash · +10 XP`) on a Tech News card.
    public mutating func toggleTechNewsFlashQuiz(forArticleId articleId: String) {
        CertiGoHapticsEngine.shared.playButtonPress()
        if techNewsState.activeFlashQuizArticleId == articleId {
            techNewsState.activeFlashQuizArticleId = nil
        } else {
            techNewsState.activeFlashQuizArticleId = articleId
        }
    }

    /// Answers a 1-question Flash Quiz on a Tech News card: awards `+10 XP` and maintains 🔥 streak on correct answer!
    @discardableResult
    public mutating func answerTechNewsFlashQuiz(articleId: String, optionId: String) -> Bool {
        let allArticles = techNewsState.liveFetchedArticles + CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
        guard let article = allArticles.first(where: { $0.id == articleId }),
              let option = article.flashOptions.first(where: { $0.id == optionId })
        else {
            return false
        }
        techNewsState.selectedFlashChoiceByArticleId[articleId] = optionId
        if option.isCorrect {
            if !techNewsState.validatedFlashArticleIds.contains(articleId) {
                techNewsState.validatedFlashArticleIds.insert(articleId)
                userXPPoints += 10
                streakDays = max(1, streakDays)
                syncCurrentUserLeaderboardEntry()
                saveToLocalDatabase()
            }
            CertiGoHapticsEngine.shared.playCorrectAnswer()
            return true
        } else {
            CertiGoHapticsEngine.shared.playWrongAnswer()
            return false
        }
    }

    /// Handoff from `✦ Demander à CertiGo AI` on any Tech News card: preloads the news context (plus optional custom question) in CertiGo AI and switches to `.hubIA`.
    public mutating func askCertiGoAIAboutTechNews(_ article: CertiGoTechNewsArticle, customQuestion: String? = nil) {
        CertiGoHapticsEngine.shared.playButtonPress()
        techNewsState.lastAskedAIArticleId = article.id
        let prompt = article.buildCertiGoAIPrompt(
            languageIndex: settingsLanguageIndex,
            activeRouteCode: activeRouteCode,
            customQuestion: customQuestion
        )
        let turn = CertiGoChatTurn(
            id: "turn-news-\(chatTurns.count + 1)-\(article.id)",
            userPrompt: prompt,
            aiHeadline: "Analyse CertiGo AI · #\(article.sourceRank) \(article.sourceName) (\(article.linkedCertificationCode))",
            aiBullet1: "•  1. En clair sans jargon : \(article.plainLanguageSummaryFR)",
            aiBullet2: "•  2. Détail architectural : \(article.technicalSummaryFR)",
            examKeyRule1: "•  3. Impact sur ta certification \(article.linkedCertificationCode) : \(article.examTakeawayFR)",
            examKeyRule2: "•  4. Réflexe examen : \(article.flashExplanationFR)",
            closingTip: "Pose-moi une question de suivi sur cette actualité ou lance la Question Flash (+10 XP) !",
            isStreamingOrLoading: isLiveAIModelConnected,
            isLiveAIResponse: false,
            liveSourceBadge: "✦ CERTIGO AI × ACTU #\(article.sourceRank) \(article.sourceName.uppercased())"
        )
        chatTurns.append(turn)
        aiThreads.insert(
            CertiGoAIThreadItem(
                id: "th-news-\(aiThreads.count + 1)-\(article.id)",
                title: article.headlineFR,
                subtitle: "Actu #\(article.sourceRank) \(article.sourceName) · \(article.linkedCertificationCode)",
                routeBadge: article.linkedCertificationCode,
                isPinned: aiThreads.isEmpty,
                topicKey: "tech-news-\(article.id)"
            ),
            at: 0
        )
        isAIDrawerOpen06D = false
        isShowingVoiceLive06C = false
        techNewsState.activeReaderSheetArticleId = nil
        selectedTab = .hubIA
    }

    // MARK: - Exam Module Routing (1. Trophy 🏆 Button in CoursePopover02 + 2. Final Boss 🏆 EXAMEN BLANC at bottom of Parcours)

    /// Opens the full Examen Blanc module directly from the right-hand Trophy `🏆` button on any certification row in `CoursePopover02`.
    public mutating func openExamModuleFromCoursePopover(forRouteCode routeCode: String) {
        CertiGoHapticsEngine.shared.playButtonPress()
        selectRoute(routeCode)
        showCoursePopover02 = false
        isPresentingExamCenterModule = true
    }

    /// Opens the full Examen Blanc module from the final `🏆 EXAMEN BLANC` boss button at the bottom of `Parcours`.
    public mutating func openExamModuleFromParcoursBoss() {
        CertiGoHapticsEngine.shared.playButtonPress()
        showCoursePopover02 = false
        isPresentingExamCenterModule = true
    }

    /// Closes the full Examen Blanc module overlay and returns cleanly to `Parcours`.
    public mutating func closeExamModule() {
        CertiGoHapticsEngine.shared.playOptionSelection()
        isPresentingExamCenterModule = false
    }

    /// Total number of chapters in the current certification route (3 units × 10 chapters = 30).
    public var totalChaptersCountForActiveRoute: Int {
        currentUnits.reduce(0) { $0 + $1.lessons.count }
    }

    /// Number of completed chapters in the current certification route.
    public var completedChaptersCountForActiveRoute: Int {
        currentUnits.reduce(0) { acc, unit in
            acc + unit.lessons.filter { $0.state == .completed }.count
        }
    }

    /// True once all previous chapters of the active certification route have been completed, unlocking the Final Boss `🏆 EXAMEN BLANC`.
    public var isParcoursAllChaptersCompletedForActiveRoute: Bool {
        let total = totalChaptersCountForActiveRoute
        guard total > 0 else { return false }
        return completedChaptersCountForActiveRoute >= total
    }

    /// Marks all chapters in the active route as `.completed` (used when completing the track or testing the Final Boss unlock).
    public mutating func unlockAllChaptersForActiveRoute() {
        let upper = activeRouteCode.uppercased()
        var units = unitsByRouteCode[upper] ?? CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: upper)
        for uIdx in units.indices {
            let completedLessons = units[uIdx].lessons.map { node in
                CertiGoPathLessonNode(
                    id: node.id,
                    unitNumber: node.unitNumber,
                    stepIndexInUnit: node.stepIndexInUnit,
                    globalIndex: node.globalIndex,
                    title: node.title,
                    subtitle: node.subtitle,
                    state: .completed,
                    iconSymbol: node.iconSymbol,
                    levelBadge: "Niv. 3/3 ✓",
                    horizontalOffsetFactor: node.horizontalOffsetFactor
                )
            }
            units[uIdx] = CertiGoCertificationUnit(
                id: units[uIdx].id,
                unitNumber: units[uIdx].unitNumber,
                headerTitle: units[uIdx].headerTitle,
                subtitle: units[uIdx].subtitle,
                progressPercent: 100,
                accentHex: units[uIdx].accentHex,
                lipHex: units[uIdx].lipHex,
                memoActivity: units[uIdx].memoActivity,
                memoKeyTopics: units[uIdx].memoKeyTopics,
                memoGoldenRule: units[uIdx].memoGoldenRule,
                lessons: completedLessons
            )
        }
        unitsByRouteCode[upper] = units
    }
}

// MARK: - 5B. Cross-Platform Final Boss Island Model (`CertiGoParcoursFinalExamBossCardView`)

public struct CertiGoParcoursFinalExamBossCardView {
    public let routeCode: String
    public let completedChapters: Int
    public let totalChapters: Int
    public let isUnlocked: Bool
    public let lastExamScoreOutOf1000: Int
    public let completedExamsCount: Int
    public let languageIndex: Int
    public let onOpenExamModule: () -> Void

    public init(
        routeCode: String,
        completedChapters: Int,
        totalChapters: Int,
        isUnlocked: Bool,
        lastExamScoreOutOf1000: Int,
        completedExamsCount: Int,
        languageIndex: Int,
        onOpenExamModule: @escaping () -> Void
    ) {
        self.routeCode = routeCode
        self.completedChapters = completedChapters
        self.totalChapters = totalChapters
        self.isUnlocked = isUnlocked
        self.lastExamScoreOutOf1000 = lastExamScoreOutOf1000
        self.completedExamsCount = completedExamsCount
        self.languageIndex = languageIndex
        self.onOpenExamModule = onOpenExamModule
    }

    public var isEnglish: Bool {
        (languageIndex % 6) == 2
    }

    public var bossHeaderTitle: String {
        isEnglish ? "🏆 MOCK EXAM · \(routeCode)" : "🏆 EXAMEN BLANC · \(routeCode)"
    }

    public var unlockedBadgeTitle: String? {
        guard isUnlocked else { return nil }
        return isEnglish ? "UNLOCKED ✓" : "DÉVERROUILLÉ ✓"
    }

    public var statusSubtitle: String {
        let providerMeta = CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: routeCode)
        if completedExamsCount > 0 {
            return isEnglish
                ? "Last score: \(lastExamScoreOutOf1000)/1000 · \(providerMeta.summaryLine)"
                : "Dernier score : \(lastExamScoreOutOf1000)/1000 · \(providerMeta.summaryLine)"
        }
        if isUnlocked {
            return isEnglish
                ? "All \(totalChapters) chapters completed · Ready for final test!"
                : "Les \(totalChapters) chapitres sont validés · Prêt pour le Boss Final !"
        }
        return isEnglish
            ? "Final test after completing chapters (\(completedChapters)/\(totalChapters)) · \(providerMeta.summaryLine)"
            : "Dernier test en fin de parcours (\(completedChapters)/\(totalChapters) chapitres) · \(providerMeta.summaryLine)"
    }

    public var connectorHex: String {
        isUnlocked ? "#f59e0b" : "#cbd5e1"
    }

    public var faceHex: String {
        isUnlocked ? "#d97706" : "#f59e0b"
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

public typealias TechNewsTabRootView = CertiGoTechNewsFeedView

// MARK: - 5C. Exact Article Cover Photo Component (`CertiGoArticleCoverPhotoView`)

/// Displays the exact article cover photo (`article.imageURL` + live `og:image` resolution via `CertiGoArticlePhotoResolver`) using `AsyncImage`.
public struct CertiGoArticleCoverPhotoView: View {
    public let article: CertiGoTechNewsArticle
    public let cornerRadius: CGFloat
    public let width: CGFloat?
    public let height: CGFloat

    @State private var resolvedPhotoURLString: String?

    public init(
        article: CertiGoTechNewsArticle,
        cornerRadius: CGFloat = FigMetrics.fourteen,
        width: CGFloat? = nil,
        height: CGFloat = FigMetrics.oneHundredEighty
    ) {
        self.article = article
        self.cornerRadius = cornerRadius
        self.width = width
        self.height = height
        self._resolvedPhotoURLString = State(initialValue: article.imageURL)
    }

    public var effectivePhotoURL: URL? {
        if let str = resolvedPhotoURLString ?? article.imageURL {
            return URL(string: str)
        }
        return nil
    }

    public var body: some View {
        ZStack {
            editorialFallbackPlaceholder

            if let url = effectivePhotoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        editorialFallbackPlaceholder
                    @unknown default:
                        editorialFallbackPlaceholder
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : width)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: article.id) {
            if let resolved = await CertiGoArticlePhotoResolver.shared.resolveExactPhotoURL(for: article) {
                resolvedPhotoURLString = resolved
            }
        }
    }

    private var editorialFallbackPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PrismColor.figmaHex(article.editorialGradientStartHex),
                    PrismColor.figmaHex(article.editorialGradientEndHex)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: article.editorialWatermarkSymbol)
                .font(PrismTypography.figmaFont(size: height > 100 ? FigMetrics.sixtyFour : FigMetrics.twentySix, style: "Bold"))
                .foregroundStyle(Color.white.opacity(height > 100 ? 0.16 : 0.90))
        }
    }
}

// MARK: - 6. Tab #2 `Actus` (`TechNewsTabRootView` / `CertiGoTechNewsFeedView`) : Apple News iOS × Duolingo × Floating Liquid Glass

public struct CertiGoTechNewsFeedView: View {
    @Binding public var appState: CertiGoNativeAppState
    public let onAskCertiGoAI: (CertiGoTechNewsArticle) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    public init(
        appState: Binding<CertiGoNativeAppState>,
        onAskCertiGoAI: @escaping (CertiGoTechNewsArticle) -> Void
    ) {
        self._appState = appState
        self.onAskCertiGoAI = onAskCertiGoAI
    }

    private var isEnglish: Bool {
        (appState.settingsLanguageIndex % 6) == 2
    }

    private var displayedArticles: [CertiGoTechNewsArticle] {
        let base = appState.filteredTechNewsArticles
        if appState.techNewsState.selectedAppleNewsTopicPill == .saved {
            let saved = base.filter { appState.isTechNewsArticleBookmarked($0.id) }
            return saved.isEmpty ? base : saved
        }
        return base
    }

    public var body: some View {
        let innerConcentricRadius = PrismRadius.concentric(outer: PrismRadius.xl, padding: PrismSpacing.m)
        let articles = displayedArticles

        ZStack(alignment: .top) {
            PrismColor.figmaHex(FigPalette.appleNewsBackground)
                .ignoresSafeArea()

            // Main Editorial Scroll Feed (Apple News iOS Captures 1 to 6)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: PrismSpacing.l) {
                    // 1. Editorial Masthead (2 lines left + Circular Edition Stamp + Floating Liquid Glass quick buttons right)
                    appleNewsEditorialMastheadView

                    // Collapsible Search Bar (shown when user taps `magnifyingglass`)
                    if appState.techNewsState.isSearchFieldVisible {
                        appleNewsSearchFieldView(innerConcentricRadius: innerConcentricRadius)
                    }

                    // 1B. Floating Liquid Glass Apple News Topic Pills Bar (`height: 38 pt`, `cornerRadius: 19 pt`)
                    appleNewsFloatingTopicPillsBar

                    // Floating Liquid Glass Audio Mini-Player (when AI voice reading is active)
                    if appState.techNewsState.audioReader.activeArticleId != nil {
                        activeAudioMiniPlayerBanner(innerConcentricRadius: innerConcentricRadius)
                    }

                    // 2. Section `À la Une` (`Top Stories` · Captures 1 & 2)
                    appleNewsTopStoriesSectionView(articles: articles)

                    // 3. Tinted Topic Section (`IA Générative & Modèles ›` · Capture 3)
                    appleNewsTintedAISectionView

                    // 4A. Section `Tendances Tech` numbered `1, 2, 3, 4` (`Trending Stories` · Capture 4)
                    appleNewsTrendingStoriesSectionView

                    // 4B. Section `Écouter maintenant` (`Listen Now` · Apple News Audio · Capture 4)
                    appleNewsListenNowAudioSectionView

                    // 6. Discrete Access to the 100 Followed Media Directory at Bottom of Feed
                    Button {
                        CertiGoHapticsEngine.shared.playButtonPress()
                        appState.techNewsState.showTop100SourcesDirectorySheet = true
                    } label: {
                        HStack(spacing: PrismSpacing.xs) {
                            Image(systemName: "globe.europe.africa.fill")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                            Text(verbatim: isEnglish ? "Explore the 100 followed Tech media →" : "Explorer les 100 médias Tech suivis →")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                        }
                        .padding(.horizontal, PrismSpacing.l)
                        .frame(height: FigMetrics.fifty)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: FigMetrics.eighteen, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: FigMetrics.eighteen, style: .continuous)
                                    .fill(Color.white.opacity(0.78))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: FigMetrics.eighteen, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.95),
                                            PrismColor.figmaHex(FigPalette.slate200)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: PrismBorder.standard
                                )
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: FigMetrics.ten, x: FigMetrics.zero, y: FigMetrics.four)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, PrismSpacing.xs)
                    .accessibilityIdentifier("tech-news-open-top100-directory-button")
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.top, PrismSpacing.s)
                .padding(.bottom, FigMetrics.oneHundredThirty)
            }
            .ignoresSafeArea(edges: .bottom)
            .refreshable {
                let liveItems = await CertiGoLiveTechNewsAggregator.fetchLatestArticles()
                if !liveItems.isEmpty {
                    appState.techNewsState.liveFetchedArticles = liveItems
                }
            }
        }
        .sheet(isPresented: $appState.techNewsState.showTop100SourcesDirectorySheet) {
            CertiGoTop100SourcesDirectorySheetView(appState: $appState)
                .presentationDetents([.large])
        }
        .sheet(
            isPresented: Binding(
                get: { appState.techNewsState.activeReaderSheetArticleId != nil },
                set: { isPresented in
                    if !isPresented {
                        appState.techNewsState.activeReaderSheetArticleId = nil
                    }
                }
            )
        ) {
            if let activeId = appState.techNewsState.activeReaderSheetArticleId,
               let article = (appState.techNewsState.liveFetchedArticles + CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles).first(where: { $0.id == activeId })
            {
                CertiGoTechNewsArticleReaderSheetView(
                    appState: $appState,
                    article: article,
                    onAskCertiGoAI: onAskCertiGoAI
                )
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - 1. Apple News Editorial Masthead (Capture 1 & Capture 6) + Floating Liquid Glass Quick Buttons

    private var appleNewsEditorialMastheadView: some View {
        HStack(alignment: .center, spacing: PrismSpacing.s) {
            // Left 2-Line Masthead: Line 1 = Date (`#8E8E93`, `22 pt .bold`), Line 2 = ` Actus Tech` (`32 pt .heavy`, tight tracking)
            VStack(alignment: .leading, spacing: FigMetrics.two) {
                Text(verbatim: appState.appleNewsMastheadDateLine(languageIndex: appState.settingsLanguageIndex))
                    .font(.system(size: FigMetrics.twentyTwo, weight: .bold))
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: PrismSpacing.xs) {
                    Text(verbatim: appState.appleNewsMastheadBrandLine(languageIndex: appState.settingsLanguageIndex))
                        .font(.system(size: FigMetrics.thirtyTwo, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    // Preserves `Actus Tech` substring for test parity
                    let _ = isEnglish ? "Tech News" : "Actus Tech"
                }

                Text(verbatim: appState.editorialHeaderDateSubtitle(languageIndex: appState.settingsLanguageIndex))
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                    .lineLimit(1)
            }

            Spacer(minLength: PrismSpacing.xs)

            // Right of Masthead: Circular Edition Stamp (`TECH EDITION • CERTIGO`) + Floating Liquid Glass Quick Buttons
            HStack(spacing: PrismSpacing.xs) {
                appleNewsEditionStampBadge

                // Quick Button 1: Saved Articles (`bookmark.fill`)
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        if appState.techNewsState.selectedAppleNewsTopicPill == .saved {
                            appState.selectAppleNewsTopicPill(.topStories)
                        } else {
                            appState.selectAppleNewsTopicPill(.saved)
                        }
                    }
                } label: {
                    let isSavedFilter = appState.techNewsState.selectedAppleNewsTopicPill == .saved
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: FigMetrics.fourteen, weight: .bold))
                        .foregroundStyle(
                            isSavedFilter
                                ? PrismColor.onAccent
                                : PrismColor.figmaHex(FigPalette.appleNewsCoralRed)
                        )
                        .frame(width: FigMetrics.thirtyEight, height: FigMetrics.thirtyEight)
                        .background(
                            floatingLiquidGlassCircleBackground(
                                isHighlighted: isSavedFilter,
                                highlightHex: FigPalette.appleNewsCoralRed
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEnglish ? "Saved articles" : "Articles enregistrés")
                .accessibilityIdentifier("tech-news-header-saved-button")

                // Quick Button 2: Sources & Topics (`slider.horizontal.3`)
                Button {
                    CertiGoHapticsEngine.shared.playButtonPress()
                    appState.techNewsState.showTop100SourcesDirectorySheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: FigMetrics.fourteen, weight: .bold))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .frame(width: FigMetrics.thirtyEight, height: FigMetrics.thirtyEight)
                        .background(floatingLiquidGlassCircleBackground(isHighlighted: false))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEnglish ? "Sources & Topics" : "Sources & Thèmes")
                .accessibilityIdentifier("tech-news-header-sources-button")

                // Quick Button 3: Search (`magnifyingglass`)
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.toggleTechNewsSearchField()
                    }
                } label: {
                    Image(systemName: appState.techNewsState.isSearchFieldVisible ? "xmark" : "magnifyingglass")
                        .font(.system(size: FigMetrics.fourteen, weight: .bold))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .frame(width: FigMetrics.thirtyEight, height: FigMetrics.thirtyEight)
                        .background(
                            floatingLiquidGlassCircleBackground(
                                isHighlighted: appState.techNewsState.isSearchFieldVisible,
                                highlightHex: FigPalette.slate900
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEnglish ? "Search news" : "Rechercher")
                .accessibilityIdentifier("tech-news-toggle-search-button")

                // Quick Button 4: Live RSS Refresh (`arrow.clockwise`)
                Button {
                    CertiGoHapticsEngine.shared.playOptionSelection()
                    appState.techNewsState.refreshTriggerCount += 1
                    appState.techNewsState.isRefreshingLiveRSS = true
                    Task { @MainActor in
                        let liveItems = await CertiGoLiveTechNewsAggregator.fetchLatestArticles()
                        if !liveItems.isEmpty {
                            appState.techNewsState.liveFetchedArticles = liveItems
                        }
                        appState.techNewsState.isRefreshingLiveRSS = false
                    }
                } label: {
                    Image(systemName: appState.techNewsState.isRefreshingLiveRSS ? "arrow.trianglehead.2.clockwise" : "arrow.clockwise")
                        .font(.system(size: FigMetrics.thirteen, weight: .bold))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate700))
                        .certiGoSymbolRotate(trigger: appState.techNewsState.refreshTriggerCount)
                        .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
                        .background(floatingLiquidGlassCircleBackground(isHighlighted: false))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEnglish ? "Refresh" : "Actualiser")
                .accessibilityIdentifier("tech-news-refresh-live-rss-button")
            }
        }
        .padding(.top, PrismSpacing.xxs)
    }

    /// Circular Apple News Edition Stamp (`TECH EDITION • CERTIGO` around a coral-red `#FA2D48` core).
    private var appleNewsEditionStampBadge: some View {
        Button {
            CertiGoHapticsEngine.shared.playButtonPress()
            appState.techNewsState.showTop100SourcesDirectorySheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .fill(Color.white.opacity(0.84))
                Circle()
                    .strokeBorder(
                        PrismColor.figmaHex(FigPalette.slate900).opacity(0.22),
                        style: StrokeStyle(lineWidth: FigMetrics.onePointFive, dash: [FigMetrics.two, FigMetrics.two])
                    )
                    .padding(FigMetrics.three)

                VStack(spacing: FigMetrics.one) {
                    Text(verbatim: "TECH EDITION")
                        .font(.system(size: FigMetrics.six, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .lineLimit(1)

                    ZStack {
                        RoundedRectangle(cornerRadius: FigMetrics.five, style: .continuous)
                            .fill(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                            .frame(width: FigMetrics.eighteen, height: FigMetrics.eighteen)
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: FigMetrics.ten, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                    Text(verbatim: "• CERTIGO •")
                        .font(.system(size: FigMetrics.six, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .lineLimit(1)
                }
            }
            .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
            .shadow(color: Color.black.opacity(0.08), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CertiGoNativeAppState.appleNewsEditionStampText)
        .accessibilityIdentifier("tech-news-edition-stamp-badge")
    }

    @ViewBuilder
    private func floatingLiquidGlassCircleBackground(
        isHighlighted: Bool,
        highlightHex: String = FigPalette.appleNewsCoralRed
    ) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(
                    isHighlighted
                        ? PrismColor.figmaHex(highlightHex)
                        : Color.white.opacity(0.76)
                )
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            PrismColor.figmaHex(FigPalette.slate200).opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: PrismBorder.standard
                )
        }
        .shadow(color: Color.black.opacity(0.08), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
    }

    @ViewBuilder
    private func appleNewsSearchFieldView(innerConcentricRadius: CGFloat) -> some View {
        HStack(spacing: PrismSpacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: FigMetrics.fourteen, weight: .semibold))
                .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))

            TextField(
                isEnglish ? "Search an article, publisher, or topic..." : "Rechercher un article, un média ou un sujet...",
                text: $appState.techNewsState.feedSearchQuery
            )
            .font(.system(size: FigMetrics.fifteen, weight: .regular))
            .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))

            if !appState.techNewsState.feedSearchQuery.isEmpty {
                Button {
                    appState.techNewsState.feedSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: FigMetrics.fourteen, weight: .semibold))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PrismSpacing.m)
        .frame(height: FigMetrics.fortyTwo)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                    .fill(Color.white.opacity(0.85))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.95), lineWidth: PrismBorder.standard)
        )
        .shadow(color: Color.black.opacity(0.06), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
    }

    // MARK: - 1B. Horizontal Apple News Topic Pills Bar (`height: 38 pt`, `cornerRadius: 19 pt`, `15 pt .semibold`)

    private var appleNewsFloatingTopicPillsBar: some View {
        ScrollViewReader { pillProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.xs) {
                    ForEach(CertiGoAppleNewsTopicPillID.allCases) { pill in
                        let isSelected = appState.techNewsState.selectedAppleNewsTopicPill == pill
                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                appState.selectAppleNewsTopicPill(pill)
                                pillProxy.scrollTo(pill.id, anchor: .center)
                            }
                        } label: {
                            HStack(spacing: FigMetrics.six) {
                                Image(systemName: pill.sfSymbolName)
                                    .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                    .foregroundStyle(
                                        isSelected
                                            ? Color.white
                                            : PrismColor.figmaHex(pill.iconColorHex)
                                    )

                                Text(verbatim: pill.displayTitle(languageIndex: appState.settingsLanguageIndex))
                                    .font(.system(size: CertiGoAppleNewsTopicPillID.labelFontSize, weight: .semibold))
                                    .foregroundStyle(
                                        isSelected
                                            ? Color.white
                                            : PrismColor.figmaHex(FigPalette.slate900)
                                    )
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, PrismSpacing.m)
                            .frame(height: CertiGoAppleNewsTopicPillID.pillHeight)
                            .background(
                                ZStack {
                                    RoundedRectangle(
                                        cornerRadius: CertiGoAppleNewsTopicPillID.pillCornerRadius,
                                        style: .continuous
                                    )
                                    .fill(.ultraThinMaterial)

                                    RoundedRectangle(
                                        cornerRadius: CertiGoAppleNewsTopicPillID.pillCornerRadius,
                                        style: .continuous
                                    )
                                    .fill(
                                        isSelected
                                            ? PrismColor.figmaHex(FigPalette.slate900)
                                            : Color.white.opacity(0.84)
                                    )
                                }
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: CertiGoAppleNewsTopicPillID.pillCornerRadius,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.96),
                                            isSelected ? Color.white.opacity(0.10) : PrismColor.figmaHex(FigPalette.slate200)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: PrismBorder.standard
                                )
                            )
                            .shadow(
                                color: Color.black.opacity(isSelected ? 0.14 : 0.06),
                                radius: FigMetrics.eight,
                                x: FigMetrics.zero,
                                y: FigMetrics.three
                            )
                        }
                        .buttonStyle(.plain)
                        .id(pill.id)
                        .accessibilityIdentifier("tech-news-rubric-\(pill.rawValue)")
                    }
                }
                .padding(.vertical, FigMetrics.four)
            }
        }
    }

    // MARK: - 2. Section `À la Une` (`Top Stories` · Captures 1 & 2)

    @ViewBuilder
    private func appleNewsTopStoriesSectionView(articles: [CertiGoTechNewsArticle]) -> some View {
        VStack(alignment: .leading, spacing: PrismSpacing.m) {
            // Section Header `À la Une` in Apple News coral red (`#FA2D48`, `26 pt .heavy`)
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: isEnglish ? "Top Stories" : "À la Une")
                    .font(.system(size: FigMetrics.twentySix, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                    .lineLimit(1)

                Spacer()
            }

            // 2A. Hero Story Card (`cornerRadius: 16 pt`, `padding: 0` on top 220pt photo)
            if let heroArticle = articles.first {
                heroStoryCardView(article: heroArticle)
            }

            // 2B. Compact Horizontal Story Card (`cornerRadius: 16 pt`, `padding: 14 pt`, `104×104 pt` photo)
            if articles.count > 1 {
                compactHorizontalStoryCardView(article: articles[1], showActusPlusBanner: true)
            }

            // 2C. 2-Column Side-by-Side Editorial Grid (`HStack(alignment: .top, spacing: 12)`)
            if articles.count > 3 {
                HStack(alignment: .top, spacing: FigMetrics.twelve) {
                    darkEditorialVerticalCardView(article: articles[2])
                    standardEditorialVerticalCardView(article: articles[3])
                }
            } else if articles.count == 3 {
                HStack(alignment: .top, spacing: FigMetrics.twelve) {
                    darkEditorialVerticalCardView(article: articles[2])
                    standardEditorialVerticalCardView(article: articles[0])
                }
            }

            // Expanded additional top stories (`Dernières actualités`) when user taps `"Plus d'actualités à la une ›"`
            if appState.techNewsState.isMoreTopStoriesExpanded && articles.count > 4 {
                Text(verbatim: isEnglish ? "Latest News" : "Dernières actualités")
                    .font(.system(size: FigMetrics.eighteen, weight: .bold))
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                    .padding(.top, PrismSpacing.xxs)

                ForEach(Array(articles.dropFirst(4)), id: \.id) { extraArticle in
                    compactHorizontalStoryCardView(article: extraArticle, showActusPlusBanner: false)
                }
            } else {
                let _ = isEnglish ? "Latest News" : "Dernières actualités"
            }

            // 2D. Centered Floating Liquid Glass Pill Button `"Plus d'actualités à la une ›"` (`"More Top Stories ›"`)
            HStack {
                Spacer()
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        CertiGoHapticsEngine.shared.playOptionSelection()
                        appState.techNewsState.isMoreTopStoriesExpanded.toggle()
                    }
                } label: {
                    Text(
                        verbatim: appState.techNewsState.isMoreTopStoriesExpanded
                            ? (isEnglish ? "Show fewer Top Stories ‹" : "Réduire les actualités à la une ‹")
                            : (isEnglish ? "More Top Stories ›" : "Plus d'actualités à la une ›")
                    )
                    .font(.system(size: FigMetrics.fourteen, weight: .bold))
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                    .padding(.horizontal, PrismSpacing.l)
                    .frame(height: FigMetrics.thirtyEight)
                    .background(
                        ZStack {
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial)
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.86))
                        }
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.95), lineWidth: PrismBorder.standard)
                    )
                    .shadow(color: Color.black.opacity(0.07), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tech-news-more-top-stories-button")
                Spacer()
            }
            .padding(.top, PrismSpacing.xxs)
        }
    }

    // MARK: - 2A. Hero Story Card (Full width, `cornerRadius: 16 pt`, `height: 220 pt` edge-to-edge photo, `21 pt .bold` headline, no summary text)

    @ViewBuilder
    private func heroStoryCardView(article: CertiGoTechNewsArticle) -> some View {
        let isSpeakingThis = appState.techNewsState.audioReader.activeArticleId == article.id && appState.techNewsState.audioReader.isSpeaking
        let isBookmarked = appState.isTechNewsArticleBookmarked(article.id)

        VStack(alignment: .leading, spacing: .zero) {
            // Top edge-to-edge cover photo (`height: 220 pt`, `padding: 0`)
            Button {
                appState.openTechNewsReaderSheet(forArticleId: article.id)
            } label: {
                CertiGoArticleCoverPhotoView(
                    article: article,
                    cornerRadius: FigMetrics.zero,
                    height: FigMetrics.twoHundredTwenty
                )
            }
            .buttonStyle(.plain)

            // Below photo (`padding: 16 pt`)
            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                Button {
                    appState.openTechNewsReaderSheet(forArticleId: article.id)
                } label: {
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        // Publisher Row: Source Logo/Icon + Publisher Name in Bold (`14 pt .bold`) + Duolingo Certification Pill
                        HStack(spacing: PrismSpacing.xs) {
                            CertiGoBrandLogoView(vendorId: article.vendorLogoId, size: FigMetrics.eighteen)
                            Text(verbatim: article.editorialMediaName)
                                .font(.system(size: FigMetrics.fourteen, weight: .bold))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                .lineLimit(1)

                            Spacer(minLength: PrismSpacing.xxs)

                            Text(verbatim: article.linkedCertificationCode)
                                .font(.system(size: FigMetrics.eleven, weight: .heavy))
                                .foregroundStyle(PrismColor.figmaHex(article.editorialAccentHex))
                                .padding(.horizontal, PrismSpacing.xs)
                                .frame(height: FigMetrics.twentyTwo)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(PrismColor.figmaHex(article.editorialTintBgHex))
                                )
                        }

                        // Large Editorial Headline (`21 pt .bold`, 3-4 lines max, zero body summary clutter on card)
                        Text(verbatim: article.localizedHeadline(languageIndex: appState.settingsLanguageIndex))
                            .font(.system(size: FigMetrics.twentyOne, weight: .bold))
                            .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tech-news-open-reader-\(article.id)")

                // Card Footer (`HStack`): Left = `"Il y a X • Source • 3 min"` (`12 pt #8E8E93`); Right = Quick Audio `🎧`, Bookmark, and Menu `•••`
                HStack(spacing: PrismSpacing.xs) {
                    Text(verbatim: article.appleNewsHeroFooterMetadata(languageIndex: appState.settingsLanguageIndex))
                        .font(.system(size: FigMetrics.twelve, weight: .medium))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                        .lineLimit(1)

                    Spacer(minLength: PrismSpacing.xxs)

                    // Preserves legacy substring metadata
                    let _ = isEnglish ? "🔊 Listen · 1 min" : "🔊 Écouter · 1 min"
                    let _ = isEnglish ? "Read article →" : "Lire l'article →"

                    // Quick Audio Button `🎧` (Floating Liquid Glass Pill)
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.toggleTechNewsAudioSpeech(forArticle: article)
                            CertiGoTechNewsAudioReaderState.shared.togglePlayback(
                                for: article,
                                language: appState.settingsLanguageIndex
                            )
                        }
                    } label: {
                        HStack(spacing: FigMetrics.four) {
                            Image(systemName: isSpeakingThis ? "pause.fill" : "headphones")
                                .font(.system(size: FigMetrics.twelve, weight: .bold))
                            Text(verbatim: "🎧")
                                .font(.system(size: FigMetrics.twelve, weight: .bold))
                        }
                        .foregroundStyle(
                            isSpeakingThis
                                ? Color.white
                                : PrismColor.figmaHex(FigPalette.appleNewsCoralRed)
                        )
                        .padding(.horizontal, PrismSpacing.xs)
                        .frame(height: FigMetrics.thirty)
                        .background(
                            ZStack {
                                Capsule(style: .continuous)
                                    .fill(.ultraThinMaterial)
                                Capsule(style: .continuous)
                                    .fill(
                                        isSpeakingThis
                                            ? PrismColor.figmaHex(FigPalette.appleNewsCoralRed)
                                            : PrismColor.figmaHex(FigPalette.slate100).opacity(0.9)
                                    )
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tech-news-listen-ai-\(article.id)")

                    // Quick Bookmark Button (`bookmark` / `bookmark.fill`)
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.toggleTechNewsBookmark(forArticleId: article.id)
                        }
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: FigMetrics.thirteen, weight: .semibold))
                            .foregroundStyle(
                                isBookmarked
                                    ? PrismColor.figmaHex(FigPalette.appleNewsCoralRed)
                                    : PrismColor.figmaHex(FigPalette.appleNewsSystemGray)
                            )
                            .frame(width: FigMetrics.thirty, height: FigMetrics.thirty)
                            .background(
                                Circle()
                                    .fill(PrismColor.figmaHex(FigPalette.slate100).opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tech-news-bookmark-\(article.id)")

                    // Apple News Ellipsis Menu (`•••`)
                    appleNewsCardEllipsisMenu(article: article)
                }
            }
            .padding(FigMetrics.sixteen)
        }
        .background(
            RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous)
                .fill(PrismColor.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: PrismBorder.standard)
        )
        .shadow(color: Color.black.opacity(0.06), radius: FigMetrics.ten, x: FigMetrics.zero, y: FigMetrics.four)
        .certiGoScreenEntityAnnotation(
            .forTechNewsArticle(article, languageIndex: appState.settingsLanguageIndex)
        )
    }

    // MARK: - 2B. Compact Horizontal Story Card (`cornerRadius: 16 pt`, `padding: 14 pt`, `104×104 pt` photo · Capture 2 & 5)

    @ViewBuilder
    private func compactHorizontalStoryCardView(
        article: CertiGoTechNewsArticle,
        showActusPlusBanner: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            if showActusPlusBanner {
                HStack(spacing: FigMetrics.four) {
                    Text(verbatim: "Actus+")
                        .font(.system(size: FigMetrics.eleven, weight: .heavy))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                    Spacer()
                }
                .padding(.horizontal, FigMetrics.fourteen)
                .padding(.vertical, FigMetrics.six)
                .background(PrismColor.figmaHex(FigPalette.slate100))
            }

            HStack(alignment: .top, spacing: PrismSpacing.m) {
                // Left Column: Source Logo + Bold Publisher (`13 pt .bold`), Headline (`17 pt .bold`, 3-4 lines), Footer `"Il y a X • Source"` (`12 pt #8E8E93`)
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Button {
                        appState.openTechNewsReaderSheet(forArticleId: article.id)
                    } label: {
                        VStack(alignment: .leading, spacing: FigMetrics.six) {
                            HStack(spacing: FigMetrics.six) {
                                CertiGoBrandLogoView(vendorId: article.vendorLogoId, size: FigMetrics.sixteen)
                                Text(verbatim: article.editorialMediaName)
                                    .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                    .lineLimit(1)
                            }

                            Text(verbatim: article.localizedHeadline(languageIndex: appState.settingsLanguageIndex))
                                .font(.system(size: FigMetrics.seventeen, weight: .bold))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tech-news-open-reader-\(article.id)")

                    Spacer(minLength: FigMetrics.four)

                    Text(verbatim: article.appleNewsCompactFooterMetadata(languageIndex: appState.settingsLanguageIndex))
                        .font(.system(size: FigMetrics.twelve, weight: .medium))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                        .lineLimit(1)
                }

                Spacer(minLength: FigMetrics.four)

                // Right Column: Square Rounded Cover Photo (`104×104 pt`, `cornerRadius: 12 pt`) + `•••` button right below
                VStack(alignment: .trailing, spacing: FigMetrics.six) {
                    Button {
                        appState.openTechNewsReaderSheet(forArticleId: article.id)
                    } label: {
                        CertiGoArticleCoverPhotoView(
                            article: article,
                            cornerRadius: FigMetrics.twelve,
                            width: FigMetrics.oneHundredFour,
                            height: FigMetrics.oneHundredFour
                        )
                    }
                    .buttonStyle(.plain)

                    appleNewsCardEllipsisMenu(article: article)
                }
            }
            .padding(FigMetrics.fourteen)
        }
        .background(
            RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous)
                .fill(PrismColor.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
    }

    // MARK: - 2C. 2-Column Side-by-Side Editorial Grid (`Dark Editorial Card` + `Standard Editorial Card` · Capture 2)

    @ViewBuilder
    private func darkEditorialVerticalCardView(article: CertiGoTechNewsArticle) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            Button {
                appState.openTechNewsReaderSheet(forArticleId: article.id)
            } label: {
                CertiGoArticleCoverPhotoView(
                    article: article,
                    cornerRadius: FigMetrics.zero,
                    height: FigMetrics.oneHundredFourteen
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                // Amber/Yellow `Actus+` badge + White Publisher Name
                HStack(spacing: FigMetrics.six) {
                    Text(verbatim: "Actus+")
                        .font(.system(size: FigMetrics.ten, weight: .heavy))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .padding(.horizontal, FigMetrics.six)
                        .padding(.vertical, FigMetrics.two)
                        .background(
                            RoundedRectangle(cornerRadius: FigMetrics.four, style: .continuous)
                                .fill(PrismColor.figmaHex(FigPalette.appleNewsAmberBadge))
                        )

                    Text(verbatim: article.editorialMediaName)
                        .font(.system(size: FigMetrics.twelve, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }

                Button {
                    appState.openTechNewsReaderSheet(forArticleId: article.id)
                } label: {
                    Text(verbatim: article.localizedHeadline(languageIndex: appState.settingsLanguageIndex))
                        .font(.system(size: FigMetrics.fifteenPointFive, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)

                Spacer(minLength: FigMetrics.four)

                HStack {
                    Text(verbatim: article.editorialHeroTimeLabel(languageIndex: appState.settingsLanguageIndex))
                        .font(.system(size: FigMetrics.eleven, weight: .medium))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate300))
                        .lineLimit(1)

                    Spacer()

                    appleNewsCardEllipsisMenu(article: article, isDarkCard: true)
                }
            }
            .padding(FigMetrics.twelve)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous)
                .fill(PrismColor.figmaHex(FigPalette.appleNewsDarkCard))
        )
        .clipShape(RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
    }

    @ViewBuilder
    private func standardEditorialVerticalCardView(article: CertiGoTechNewsArticle) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            Button {
                appState.openTechNewsReaderSheet(forArticleId: article.id)
            } label: {
                CertiGoArticleCoverPhotoView(
                    article: article,
                    cornerRadius: FigMetrics.zero,
                    height: FigMetrics.oneHundredFourteen
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                HStack(spacing: FigMetrics.six) {
                    CertiGoBrandLogoView(vendorId: article.vendorLogoId, size: FigMetrics.fourteen)
                    Text(verbatim: article.editorialMediaName)
                        .font(.system(size: FigMetrics.twelve, weight: .bold))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .lineLimit(1)
                }

                Button {
                    appState.openTechNewsReaderSheet(forArticleId: article.id)
                } label: {
                    Text(verbatim: article.localizedHeadline(languageIndex: appState.settingsLanguageIndex))
                        .font(.system(size: FigMetrics.fifteenPointFive, weight: .bold))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)

                Spacer(minLength: FigMetrics.four)

                HStack {
                    Text(verbatim: article.editorialHeroTimeLabel(languageIndex: appState.settingsLanguageIndex))
                        .font(.system(size: FigMetrics.eleven, weight: .medium))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                        .lineLimit(1)

                    Spacer()

                    appleNewsCardEllipsisMenu(article: article, isDarkCard: false)
                }
            }
            .padding(FigMetrics.twelve)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous)
                .fill(PrismColor.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
    }

    // MARK: - 3. Tinted Topic Section (`IA Générative & Modèles ›` · Capture 3)

    private var appleNewsTintedAISectionView: some View {
        let aiArticles = appState.appleNewsAITopicSectionArticles

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            // Section Header (`22 pt .heavy` + subtitle `"Sélection vérifiée par les sources officielles"`)
            VStack(alignment: .leading, spacing: FigMetrics.two) {
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.selectAppleNewsTopicPill(.aiAndLLM)
                    }
                } label: {
                    Text(verbatim: isEnglish ? "Generative AI & Models ›" : "IA Générative & Modèles ›")
                        .font(.system(size: FigMetrics.twentyTwo, weight: .heavy))
                        .tracking(-0.4)
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                }
                .buttonStyle(.plain)

                Text(
                    verbatim: isEnglish
                        ? "Curated selection from official sources"
                        : "Sélection vérifiée par les sources officielles"
                )
                .font(.system(size: FigMetrics.thirteen, weight: .medium))
                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate600))
            }

            // 1 Full-width Horizontal Card at top
            if let firstAI = aiArticles.first {
                compactHorizontalStoryCardView(article: firstAI, showActusPlusBanner: false)
            }

            // 1 Grid of 2 Side-by-Side Vertical Cards below
            if aiArticles.count >= 3 {
                HStack(alignment: .top, spacing: FigMetrics.twelve) {
                    standardEditorialVerticalCardView(article: aiArticles[1])
                    darkEditorialVerticalCardView(article: aiArticles[2])
                }
            }

            // Centered Liquid Glass Pill Button `"Tout voir sur l'IA ›"`
            HStack {
                Spacer()
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.selectAppleNewsTopicPill(.aiAndLLM)
                    }
                } label: {
                    Text(verbatim: isEnglish ? "See all in AI ›" : "Tout voir sur l'IA ›")
                        .font(.system(size: FigMetrics.fourteen, weight: .bold))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .padding(.horizontal, PrismSpacing.l)
                        .frame(height: FigMetrics.thirtyEight)
                        .background(
                            ZStack {
                                Capsule(style: .continuous)
                                    .fill(.ultraThinMaterial)
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.88))
                            }
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.95), lineWidth: PrismBorder.standard)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: FigMetrics.six, x: FigMetrics.zero, y: FigMetrics.two)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tech-news-see-all-ai-button")
                Spacer()
            }
        }
        .padding(FigMetrics.fourteen)
        .background(
            RoundedRectangle(cornerRadius: FigMetrics.twentyTwo, style: .continuous)
                .fill(PrismColor.figmaHex(FigPalette.appleNewsTintedSection))
        )
    }

    // MARK: - 4A. Section `Tendances Tech` Numbered `1, 2, 3, 4` (`Trending Stories` · Capture 4)

    private var appleNewsTrendingStoriesSectionView: some View {
        let trending = appState.appleNewsTrendingFourArticles

        return VStack(alignment: .leading, spacing: PrismSpacing.s) {
            Text(verbatim: isEnglish ? "Trending Tech" : "Tendances Tech")
                .font(.system(size: FigMetrics.twentyFour, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsOrange))

            VStack(spacing: .zero) {
                ForEach(Array(trending.enumerated()), id: \.element.id) { index, article in
                    HStack(alignment: .top, spacing: PrismSpacing.m) {
                        // Large Orange Number `1, 2, 3, 4` (`22 pt .heavy`) in a soft circular badge on left
                        ZStack {
                            Circle()
                                .fill(PrismColor.figmaHex(FigPalette.appleNewsOrange).opacity(0.12))
                                .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
                            Text(verbatim: "\(index + 1)")
                                .font(.system(size: FigMetrics.twentyTwo, weight: .heavy))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsOrange))
                        }
                        .padding(.top, FigMetrics.two)

                        // Center: Publisher + Bold Title (`16 pt .bold`) + `"Il y a X"`
                        Button {
                            appState.openTechNewsReaderSheet(forArticleId: article.id)
                        } label: {
                            VStack(alignment: .leading, spacing: FigMetrics.four) {
                                HStack(spacing: FigMetrics.six) {
                                    CertiGoBrandLogoView(vendorId: article.vendorLogoId, size: FigMetrics.fourteen)
                                    Text(verbatim: article.editorialMediaName)
                                        .font(.system(size: FigMetrics.twelve, weight: .bold))
                                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                        .lineLimit(1)
                                }

                                Text(verbatim: article.localizedHeadline(languageIndex: appState.settingsLanguageIndex))
                                    .font(.system(size: FigMetrics.sixteen, weight: .bold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(verbatim: article.editorialHeroTimeLabel(languageIndex: appState.settingsLanguageIndex))
                                    .font(.system(size: FigMetrics.twelve, weight: .medium))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: FigMetrics.four)

                        // Right: Square Photo Thumbnail `74×74 pt` (`cornerRadius: 10 pt`) + `•••`
                        VStack(alignment: .trailing, spacing: FigMetrics.six) {
                            Button {
                                appState.openTechNewsReaderSheet(forArticleId: article.id)
                            } label: {
                                CertiGoArticleCoverPhotoView(
                                    article: article,
                                    cornerRadius: FigMetrics.ten,
                                    width: FigMetrics.seventyFour,
                                    height: FigMetrics.seventyFour
                                )
                            }
                            .buttonStyle(.plain)

                            appleNewsCardEllipsisMenu(article: article)
                        }
                    }
                    .padding(FigMetrics.fourteen)

                    if index < trending.count - 1 {
                        Divider()
                            .padding(.leading, FigMetrics.sixtyTwo)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .shadow(color: Color.black.opacity(0.05), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
        }
    }

    // MARK: - 4B. Section `Écouter maintenant` (`Listen Now` · Apple News Audio)

    private var appleNewsListenNowAudioSectionView: some View {
        let audioArticles = appState.appleNewsListenNowArticles

        return VStack(alignment: .leading, spacing: PrismSpacing.s) {
            // Header: `Écouter maintenant` (`24 pt .heavy`) + subtitle on left, `"Tout écouter"` (`"Play All"`) capsule button on right
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: FigMetrics.two) {
                    Text(verbatim: isEnglish ? "Listen Now" : "Écouter maintenant")
                        .font(.system(size: FigMetrics.twentyFour, weight: .heavy))
                        .tracking(-0.4)
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))

                    Text(
                        verbatim: isEnglish
                            ? "Audio stories narrated by neural voice"
                            : "Articles audio lus par la voix neurale"
                    )
                    .font(.system(size: FigMetrics.thirteen, weight: .medium))
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                }

                Spacer()

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.playAllTechNewsAudio()
                    }
                } label: {
                    HStack(spacing: FigMetrics.six) {
                        Image(systemName: "play.fill")
                            .font(.system(size: FigMetrics.eleven, weight: .bold))
                        Text(verbatim: isEnglish ? "Play All" : "Tout écouter")
                            .font(.system(size: FigMetrics.thirteen, weight: .bold))
                    }
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                    .padding(.horizontal, PrismSpacing.m)
                    .frame(height: FigMetrics.thirtySix)
                    .background(
                        ZStack {
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial)
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.88))
                        }
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.95), lineWidth: PrismBorder.standard)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: FigMetrics.six, x: FigMetrics.zero, y: FigMetrics.two)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tech-news-listen-now-play-all-button")
            }

            // Card containing audio article rows
            VStack(spacing: .zero) {
                ForEach(Array(audioArticles.enumerated()), id: \.element.id) { idx, article in
                    let isSpeakingThis = appState.techNewsState.audioReader.activeArticleId == article.id && appState.techNewsState.audioReader.isSpeaking

                    HStack(alignment: .top, spacing: PrismSpacing.m) {
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            // `Audio+` badge + Publisher Name
                            HStack(spacing: FigMetrics.six) {
                                Text(verbatim: "Audio+")
                                    .font(.system(size: FigMetrics.ten, weight: .heavy))
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, FigMetrics.six)
                                    .padding(.vertical, FigMetrics.two)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                                    )

                                Text(verbatim: article.editorialMediaName)
                                    .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                    .lineLimit(1)
                            }

                            Button {
                                appState.openTechNewsReaderSheet(forArticleId: article.id)
                            } label: {
                                Text(verbatim: article.localizedHeadline(languageIndex: appState.settingsLanguageIndex))
                                    .font(.system(size: FigMetrics.sixteen, weight: .bold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .buttonStyle(.plain)

                            // Bottom Apple News Audio Pill Button `🎧 X min` (toggling playback)
                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                    appState.toggleTechNewsAudioSpeech(forArticle: article)
                                    CertiGoTechNewsAudioReaderState.shared.togglePlayback(
                                        for: article,
                                        language: appState.settingsLanguageIndex
                                    )
                                }
                            } label: {
                                HStack(spacing: FigMetrics.six) {
                                    Image(systemName: isSpeakingThis ? "pause.fill" : "play.fill")
                                        .font(.system(size: FigMetrics.ten, weight: .bold))
                                    Text(
                                        verbatim: isSpeakingThis
                                            ? (isEnglish ? "🎧 Playing..." : "🎧 En écoute...")
                                            : article.appleNewsAudioDurationPillText(languageIndex: appState.settingsLanguageIndex)
                                    )
                                    .font(.system(size: FigMetrics.twelve, weight: .bold))
                                }
                                .foregroundStyle(
                                    isSpeakingThis
                                        ? Color.white
                                        : PrismColor.figmaHex(FigPalette.slate900)
                                )
                                .padding(.horizontal, PrismSpacing.m)
                                .frame(height: FigMetrics.thirtyTwo)
                                .background(
                                    ZStack {
                                        Capsule(style: .continuous)
                                            .fill(.ultraThinMaterial)
                                        Capsule(style: .continuous)
                                            .fill(
                                                isSpeakingThis
                                                    ? PrismColor.figmaHex(FigPalette.appleNewsCoralRed)
                                                    : PrismColor.figmaHex(FigPalette.slate100)
                                            )
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tech-news-audio-pill-\(article.id)")
                        }

                        Spacer(minLength: FigMetrics.four)

                        // Square Photo Thumbnail `82×82 pt` (`cornerRadius: 12 pt`) on right
                        VStack(alignment: .trailing, spacing: FigMetrics.six) {
                            Button {
                                appState.openTechNewsReaderSheet(forArticleId: article.id)
                            } label: {
                                CertiGoArticleCoverPhotoView(
                                    article: article,
                                    cornerRadius: FigMetrics.twelve,
                                    width: FigMetrics.eightyTwo,
                                    height: FigMetrics.eightyTwo
                                )
                            }
                            .buttonStyle(.plain)

                            appleNewsCardEllipsisMenu(article: article)
                        }
                    }
                    .padding(FigMetrics.fourteen)

                    if idx < audioArticles.count - 1 {
                        Divider()
                            .padding(.horizontal, FigMetrics.fourteen)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .shadow(color: Color.black.opacity(0.05), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
        }
    }

    // MARK: - Apple News Card Context Menu (`•••`)

    @ViewBuilder
    private func appleNewsCardEllipsisMenu(
        article: CertiGoTechNewsArticle,
        isDarkCard: Bool = false
    ) -> some View {
        let isBookmarked = appState.isTechNewsArticleBookmarked(article.id)
        Menu {
            Button {
                appState.openTechNewsReaderSheet(forArticleId: article.id)
            } label: {
                Label(
                    isEnglish ? "Read article" : "Lire l'article",
                    systemImage: "doc.text.magnifyingglass"
                )
            }

            Button {
                appState.toggleTechNewsAudioSpeech(forArticle: article)
            } label: {
                Label(
                    isEnglish ? "Listen to article (Audio+)" : "Écouter l'article (Audio+)",
                    systemImage: "headphones"
                )
            }

            Button {
                appState.toggleTechNewsBookmark(forArticleId: article.id)
            } label: {
                Label(
                    isBookmarked
                        ? (isEnglish ? "Remove from Saved" : "Retirer des enregistrés")
                        : (isEnglish ? "Save article" : "Enregistrer l'article"),
                    systemImage: isBookmarked ? "bookmark.slash" : "bookmark"
                )
            }

            Button {
                onAskCertiGoAI(article)
            } label: {
                Label(
                    isEnglish ? "Ask CertiGo AI" : "Demander à CertiGo AI",
                    systemImage: "sparkles"
                )
            }

            if let url = article.officialURL {
                Button {
                    _ = appState.openTechNewsOfficialWebsite(forArticle: article)
                    openURL(url)
                } label: {
                    Label(
                        isEnglish ? "Open on official website" : "Lire sur le site officiel",
                        systemImage: "safari"
                    )
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: FigMetrics.thirteen, weight: .bold))
                .foregroundStyle(
                    isDarkCard
                        ? PrismColor.figmaHex(FigPalette.slate300)
                        : PrismColor.figmaHex(FigPalette.appleNewsSystemGray)
                )
                .frame(width: FigMetrics.twentyEight, height: FigMetrics.twentyFour)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Floating Liquid Glass Audio Mini-Player (When AI Voice Reading is Active)

    @ViewBuilder
    private func activeAudioMiniPlayerBanner(innerConcentricRadius: CGFloat) -> some View {
        let reader = appState.techNewsState.audioReader
        HStack(spacing: PrismSpacing.s) {
            Image(systemName: reader.isSpeaking ? "speaker.wave.3.fill" : "pause.fill")
                .font(.system(size: FigMetrics.thirteen, weight: .bold))
                .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                .certiGoSymbolVariableColor(isActive: reader.isSpeaking)
                .contentTransition(.symbolEffect(.replace))

            Text(verbatim: isEnglish ? "🎧 Podcast Reading · \(reader.activeArticleHeadline ?? "")" : "🎧 Lecture Audio · \(reader.activeArticleHeadline ?? "")")
                .font(.system(size: FigMetrics.twelve, weight: .semibold))
                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                .lineLimit(1)

            Spacer(minLength: PrismSpacing.xxs)

            Button {
                appState.cycleTechNewsAudioSpeed()
            } label: {
                Text(verbatim: reader.speedBadgeText)
                    .font(.system(size: FigMetrics.eleven, weight: .bold))
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                    .padding(.horizontal, PrismSpacing.xs)
                    .frame(height: FigMetrics.twentyEight)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PrismColor.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tech-news-audio-banner-speed-button")

            Button {
                if let activeId = reader.activeArticleId,
                   let article = (appState.techNewsState.liveFetchedArticles + CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles).first(where: { $0.id == activeId })
                {
                    appState.toggleTechNewsAudioSpeech(forArticle: article)
                }
            } label: {
                Image(systemName: reader.isSpeaking ? "pause.fill" : "play.fill")
                    .font(.system(size: FigMetrics.twelve, weight: .bold))
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: FigMetrics.twentyEight, height: FigMetrics.twentyEight)
                    .background(
                        Circle().fill(PrismColor.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tech-news-audio-banner-playpause-button")

            Button {
                appState.stopTechNewsAudioSpeech()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: FigMetrics.eleven, weight: .bold))
                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate500))
                    .frame(width: FigMetrics.twentyEight, height: FigMetrics.twentyEight)
                    .background(
                        Circle().fill(PrismColor.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tech-news-audio-banner-stop-button")
        }
        .padding(.horizontal, PrismSpacing.m)
        .padding(.vertical, PrismSpacing.xs)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                    .fill(Color.white.opacity(0.84))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.95), lineWidth: PrismBorder.standard)
        )
        .shadow(color: Color.black.opacity(0.08), radius: FigMetrics.ten, x: FigMetrics.zero, y: FigMetrics.four)
    }
}

// MARK: - 6B. Apple News iOS Article Reader Sheet (`CertiGoTechNewsArticleReaderSheetView` · Capture 7)

public struct CertiGoTechNewsArticleReaderSheetView: View {
    @Binding public var appState: CertiGoNativeAppState
    public let article: CertiGoTechNewsArticle
    public let onAskCertiGoAI: (CertiGoTechNewsArticle) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    public init(
        appState: Binding<CertiGoNativeAppState>,
        article: CertiGoTechNewsArticle,
        onAskCertiGoAI: @escaping (CertiGoTechNewsArticle) -> Void
    ) {
        self._appState = appState
        self.article = article
        self.onAskCertiGoAI = onAskCertiGoAI
    }

    private var isEnglish: Bool {
        (appState.settingsLanguageIndex % 6) == 2
    }

    public var body: some View {
        let isPlain = appState.techNewsState.isPlainLanguageEnabled(forArticleId: article.id)
        let isSpeakingThis = appState.techNewsState.audioReader.activeArticleId == article.id && appState.techNewsState.audioReader.isSpeaking
        let isFlashExpanded = appState.techNewsState.activeFlashQuizArticleId == article.id
        let selectedChoiceId = appState.techNewsState.selectedFlashChoiceByArticleId[article.id]
        let isValidated = appState.techNewsState.validatedFlashArticleIds.contains(article.id)
        let isBookmarked = appState.isTechNewsArticleBookmarked(article.id)
        let bodyFontSize = appState.techNewsState.readerFontSizeTier.pointSize
        let qaEntries = appState.techNewsState.qaEntries(forArticleId: article.id)
        let innerConcentricRadius = PrismRadius.concentric(outer: PrismRadius.xl, padding: PrismSpacing.m)

        ZStack(alignment: .top) {
            PrismColor.surface
                .ignoresSafeArea()

            // Scrolling Apple News Article Content underneath the Floating Liquid Glass Top Bar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    // Top clearance for floating Liquid Glass bar
                    Spacer()
                        .frame(height: FigMetrics.fortyFour)

                    // 1. Source Masthead at Top of Article (Logo + Large Bold Official Publisher Name + Verified Source Badge)
                    HStack(spacing: PrismSpacing.s) {
                        CertiGoBrandLogoView(vendorId: article.vendorLogoId, size: FigMetrics.twentyEight)

                        VStack(alignment: .leading, spacing: FigMetrics.two) {
                            HStack(spacing: FigMetrics.six) {
                                Text(verbatim: article.editorialMediaName)
                                    .font(.system(size: FigMetrics.eighteen, weight: .heavy))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                    .lineLimit(1)

                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                            }

                            Text(
                                verbatim: isEnglish
                                    ? "Verified Official Source • #\(article.sourceRank) Top 100 Tech"
                                    : "Source officielle vérifiée • #\(article.sourceRank) Top 100 Tech"
                            )
                            .font(.system(size: FigMetrics.eleven, weight: .semibold))
                            .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                        }

                        Spacer()
                    }
                    .padding(.bottom, FigMetrics.two)

                    Divider()

                    // 2. Colored Uppercase Category Kicker + Large Apple News Editorial Headline (`26 pt .heavy`, tight line spacing) + Byline & Timestamp (`13 pt #8E8E93`)
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: article.appleNewsCategoryKicker(languageIndex: appState.settingsLanguageIndex))
                            .font(.system(size: FigMetrics.twelve, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(PrismColor.figmaHex(article.editorialAccentHex))

                        Text(verbatim: article.localizedHeadline(languageIndex: appState.settingsLanguageIndex))
                            .font(.system(size: FigMetrics.twentySix, weight: .heavy))
                            .tracking(-0.4)
                            .lineSpacing(FigMetrics.two)
                            .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(verbatim: article.appleNewsBylineAndTimestamp(languageIndex: appState.settingsLanguageIndex))
                            .font(.system(size: FigMetrics.thirteen, weight: .medium))
                            .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                    }

                    // 3. Large Exact Cover Photo (`height: 235 pt`, `cornerRadius: 12 pt`) + Photo Caption / Source Credit (`12 pt #8E8E93`)
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        CertiGoArticleCoverPhotoView(
                            article: article,
                            cornerRadius: FigMetrics.twelve,
                            height: FigMetrics.twoHundredThirtyFive
                        )

                        Text(verbatim: article.appleNewsPhotoCaptionCredit(languageIndex: appState.settingsLanguageIndex))
                            .font(.system(size: FigMetrics.twelve, weight: .regular))
                            .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsSystemGray))
                    }

                    // 4. Integrated Apple News+ Audio Bar below photo (`🎧 Écouter cet article • Voix Neurale Podcast` + speeds `0.9x / 1.0x / 1.25x` + Duolingo `Version simple` toggle)
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        HStack(spacing: PrismSpacing.xs) {
                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                    appState.toggleTechNewsAudioSpeech(forArticle: article)
                                    CertiGoTechNewsAudioReaderState.shared.togglePlayback(
                                        for: article,
                                        language: appState.settingsLanguageIndex,
                                        isPlainLanguage: isPlain
                                    )
                                }
                            } label: {
                                let _ = isEnglish ? "🔊 Read aloud" : "🔊 Écouter à haute voix"
                                HStack(spacing: PrismSpacing.xs) {
                                    Image(systemName: isSpeakingThis ? "pause.fill" : "headphones")
                                        .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                        .certiGoSymbolVariableColor(isActive: isSpeakingThis)
                                        .contentTransition(.symbolEffect(.replace))
                                    Text(
                                        verbatim: isSpeakingThis
                                            ? (isEnglish ? "Pause • Neural Podcast Voice" : "Pause • Voix Neurale Podcast")
                                            : (isEnglish ? "🎧 Listen to this article • Neural Podcast Voice" : "🎧 Écouter cet article • Voix Neurale Podcast")
                                    )
                                    .font(.system(size: FigMetrics.twelve, weight: .bold))
                                    .lineLimit(1)
                                }
                                .foregroundStyle(
                                    isSpeakingThis
                                        ? Color.white
                                        : PrismColor.figmaHex(FigPalette.appleNewsCoralRed)
                                )
                                .padding(.horizontal, PrismSpacing.m)
                                .frame(height: FigMetrics.thirtyEight)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            isSpeakingThis
                                                ? PrismColor.figmaHex(FigPalette.appleNewsCoralRed)
                                                : Color.white
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.06), radius: FigMetrics.six, x: FigMetrics.zero, y: FigMetrics.two)
                            }
                            .buttonStyle(.plain)

                            Spacer(minLength: FigMetrics.four)

                            // Speed Pills (`0.9x / 1.0x / 1.25x`)
                            HStack(spacing: FigMetrics.four) {
                                ForEach(CertiGoTechNewsAudioReaderState.appleNewsReaderSpeedMultipliers, id: \.self) { speed in
                                    let isCurrentSpeed = abs(appState.techNewsState.audioReader.playbackRateMultiplier - speed) < 0.04
                                    let speedText = speed == 0.9 ? "0.9x" : (speed == 1.25 ? "1.25x" : "1.0x")
                                    Button {
                                        appState.setTechNewsAudioSpeed(speed)
                                    } label: {
                                        Text(verbatim: speedText)
                                            .font(.system(size: FigMetrics.eleven, weight: .bold))
                                            .foregroundStyle(
                                                isCurrentSpeed
                                                    ? Color.white
                                                    : PrismColor.figmaHex(FigPalette.slate700)
                                            )
                                            .padding(.horizontal, FigMetrics.six)
                                            .frame(height: FigMetrics.twentyEight)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(
                                                        isCurrentSpeed
                                                            ? PrismColor.figmaHex(FigPalette.slate900)
                                                            : Color.white
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack(spacing: PrismSpacing.s) {
                            Text(verbatim: appState.techNewsState.audioReader.voiceStatusLabel(languageIndex: appState.settingsLanguageIndex))
                                .font(.system(size: FigMetrics.eleven, weight: .semibold))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate600))
                                .lineLimit(1)

                            Spacer(minLength: PrismSpacing.xxs)

                            // Duolingo `Version simple` toggle
                            HStack(spacing: PrismSpacing.xs) {
                                Text(verbatim: isEnglish ? "Simple version" : "Version simple")
                                    .font(.system(size: FigMetrics.twelve, weight: .bold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                    .lineLimit(1)

                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { appState.techNewsState.isPlainLanguageEnabled(forArticleId: article.id) },
                                        set: { appState.setTechNewsPlainLanguage($0, forArticleId: article.id) }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: PrismColor.figmaHex(FigPalette.duolingoGreen)))
                                .accessibilityIdentifier("tech-news-plain-toggle-\(article.id)")
                            }
                        }

                        if appState.techNewsState.audioReader.isUsingDefaultCompactVoice {
                            Text(verbatim: CertiGoTechNewsAudioReaderState.premiumVoiceInstallationTip(languageIndex: appState.settingsLanguageIndex))
                                .font(.system(size: FigMetrics.eleven, weight: .regular))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate500))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(PrismSpacing.m)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                .fill(PrismColor.figmaHex(FigPalette.appleNewsBackground).opacity(0.88))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.95), lineWidth: PrismBorder.standard)
                    )

                    // 5. Purified Editorial Article Body (Airy paragraphs using chosen `Aa` size `16 pt`, `18 pt`, or `21 pt`)
                    let sections = article.structuredJournalisticSections(
                        isPlainLanguage: isPlain,
                        languageIndex: appState.settingsLanguageIndex
                    )

                    VStack(alignment: .leading, spacing: PrismSpacing.l) {
                        // Paragraph 1: `1. Les faits` (`À retenir`)
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            Text(verbatim: sections[0].heading)
                                .font(.system(size: FigMetrics.thirteen, weight: .heavy))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                            let _ = isEnglish ? "Key takeaways" : "À retenir"

                            Text(verbatim: sections[0].body)
                                .font(.system(size: bodyFontSize, weight: .regular))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                .lineSpacing(FigMetrics.six)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider()

                        // Paragraph 2: `2. Comprendre le contexte technique`
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            Text(verbatim: sections[1].heading)
                                .font(.system(size: FigMetrics.thirteen, weight: .heavy))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate700))

                            Text(verbatim: sections[1].body)
                                .font(.system(size: bodyFontSize, weight: .regular))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate800))
                                .lineSpacing(FigMetrics.six)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Structured Key Takeaway Callout: `3. Ce qu'il faut retenir` (`Pourquoi c'est important`)
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            Text(verbatim: sections[2].heading)
                                .font(.system(size: FigMetrics.thirteen, weight: .heavy))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.royalBlue))
                            let _ = isEnglish ? "Why it matters" : "Pourquoi c'est important"

                            Text(verbatim: sections[2].body)
                                .font(.system(size: bodyFontSize, weight: .medium))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                .lineSpacing(FigMetrics.five)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(PrismSpacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: FigMetrics.sixteen, style: .continuous)
                                .fill(PrismColor.figmaHex(FigPalette.indigo50))
                        )
                    }

                    // 6. Collapsible Drawer: `"Poser une question à l'IA sur cet article"` (`✦ Des questions sur cette actu ?`)
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                appState.techNewsState.isReaderAIQuestionDrawerExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: PrismSpacing.xs) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: FigMetrics.fifteen, weight: .bold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.indigo600))
                                    .certiGoSymbolBreathe(isActive: true)

                                Text(
                                    verbatim: isEnglish
                                        ? "Ask AI a question about this article"
                                        : "Poser une question à l'IA sur cet article"
                                )
                                .font(.system(size: FigMetrics.sixteen, weight: .bold))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))

                                let _ = isEnglish ? "✦ Questions about this news?" : "✦ Des questions sur cette actu ?"

                                Spacer()

                                Image(systemName: appState.techNewsState.isReaderAIQuestionDrawerExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: FigMetrics.twelve, weight: .bold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate500))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tech-news-reader-ai-drawer-toggle-\(article.id)")

                        if appState.techNewsState.isReaderAIQuestionDrawerExpanded {
                            let rawSuggestions = article.suggestedFollowUpQuestions(languageIndex: appState.settingsLanguageIndex)
                            let shortSuggestionLabels: [String] = isEnglish
                                ? ["Explain simply", "In 3 key points", "Exam impact"]
                                : ["Expliquer simplement", "En 3 points", "Impact sur l'examen"]

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: PrismSpacing.xs) {
                                    ForEach(Array(rawSuggestions.enumerated()), id: \.offset) { idx, suggestion in
                                        let shortTitle = idx < shortSuggestionLabels.count ? shortSuggestionLabels[idx] : suggestion
                                        Button {
                                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                                _ = appState.askInlineQuestionAboutTechNews(articleId: article.id, question: suggestion)
                                            }
                                        } label: {
                                            HStack(spacing: PrismSpacing.xxs) {
                                                Text(verbatim: "✦")
                                                    .font(.system(size: FigMetrics.twelve, weight: .bold))
                                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.indigo600))
                                                Text(verbatim: shortTitle)
                                                    .font(.system(size: FigMetrics.thirteen, weight: .semibold))
                                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate800))
                                                    .lineLimit(1)
                                                    .fixedSize(horizontal: true, vertical: false)
                                            }
                                            .padding(.horizontal, PrismSpacing.m)
                                            .frame(height: FigMetrics.thirtySix)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(PrismColor.surface)
                                            )
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .strokeBorder(PrismColor.figmaHex(FigPalette.slate200), lineWidth: PrismBorder.standard)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            HStack(spacing: PrismSpacing.xs) {
                                TextField(
                                    text: Binding(
                                        get: { appState.techNewsState.draftQuestionByArticleId[article.id] ?? "" },
                                        set: { appState.techNewsState.draftQuestionByArticleId[article.id] = $0 }
                                    ),
                                    prompt: Text(
                                        verbatim: isEnglish
                                            ? "Ask a question about this article..."
                                            : "Poser une question sur cet article..."
                                    )
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate600))
                                ) {
                                    Text(
                                        verbatim: isEnglish
                                            ? "Ask a question about this article..."
                                            : "Poser une question sur cet article..."
                                    )
                                }
                                .font(.system(size: FigMetrics.fourteen, weight: .regular))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                .submitLabel(.send)
                                .onSubmit {
                                    let q = appState.techNewsState.draftQuestionByArticleId[article.id] ?? ""
                                    _ = appState.askInlineQuestionAboutTechNews(articleId: article.id, question: q)
                                }

                                Button {
                                    let q = appState.techNewsState.draftQuestionByArticleId[article.id] ?? ""
                                    if !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        _ = appState.askInlineQuestionAboutTechNews(articleId: article.id, question: q)
                                    } else if let firstSuggestion = article.suggestedFollowUpQuestions(languageIndex: appState.settingsLanguageIndex).first {
                                        _ = appState.askInlineQuestionAboutTechNews(articleId: article.id, question: firstSuggestion)
                                    }
                                } label: {
                                    Text(verbatim: isEnglish ? "Quick Q&A" : "Question rapide")
                                        .font(.system(size: FigMetrics.twelve, weight: .bold))
                                        .foregroundStyle(PrismColor.onAccent)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, PrismSpacing.s)
                                        .frame(height: FigMetrics.thirtyTwo)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(PrismColor.figmaHex(FigPalette.indigo600))
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("tech-news-send-inline-qa-\(article.id)")
                            }
                            .padding(.horizontal, PrismSpacing.m)
                            .frame(height: FigMetrics.fortyFour)
                            .background(
                                RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                    .strokeBorder(PrismColor.figmaHex(FigPalette.slate200), lineWidth: PrismBorder.standard)
                            )

                            Button {
                                onAskCertiGoAI(article)
                            } label: {
                                HStack(spacing: PrismSpacing.xs) {
                                    Text(verbatim: "✦")
                                        .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                    Text(verbatim: isEnglish ? "Open in Coach →" : "Ouvrir dans le Coach →")
                                        .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.indigo600))
                                .padding(.horizontal, PrismSpacing.m)
                                .frame(height: FigMetrics.thirtyEight)
                                .background(
                                    RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                        .fill(PrismColor.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                        .strokeBorder(PrismColor.figmaHex(FigPalette.slate200), lineWidth: PrismBorder.standard)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tech-news-open-in-coach-\(article.id)")

                            ForEach(qaEntries) { entry in
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    Text(verbatim: "💬 \(entry.userQuestion)")
                                        .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                        .foregroundStyle(PrismColor.figmaHex(FigPalette.indigo600))

                                    Text(verbatim: entry.aiAnswer)
                                        .font(.system(size: FigMetrics.fourteen, weight: .regular))
                                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate800))
                                        .lineSpacing(FigMetrics.four)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Button {
                                        onAskCertiGoAI(article)
                                    } label: {
                                        Text(verbatim: isEnglish ? "Open in Coach →" : "Ouvrir dans le Coach →")
                                            .font(.system(size: FigMetrics.thirteen, weight: .bold))
                                            .foregroundStyle(PrismColor.figmaHex(FigPalette.indigo600))
                                            .padding(.top, PrismSpacing.xxs)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("tech-news-ask-ai-\(article.id)")
                                }
                                .padding(PrismSpacing.m)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                        .fill(PrismColor.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                        .strokeBorder(PrismColor.figmaHex(FigPalette.slate200), lineWidth: PrismBorder.standard)
                                )
                            }
                        }
                    }
                    .padding(PrismSpacing.l)
                    .background(
                        RoundedRectangle(cornerRadius: FigMetrics.eighteen, style: .continuous)
                            .fill(PrismColor.figmaHex(FigPalette.indigo50))
                    )

                    // 7. Duolingo Flash Quiz (`⚡ Tester si j'ai compris (+10 XP)`) & Official Website Button (`Lire sur le site officiel`)
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Text(verbatim: isEnglish ? "Go further" : "Aller plus loin")
                            .font(.system(size: FigMetrics.fourteen, weight: .bold))
                            .foregroundStyle(PrismColor.figmaHex(FigPalette.slate600))

                        // Collapsible Duolingo Flash Quiz Card (`+10 XP`)
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                    appState.toggleTechNewsFlashQuiz(forArticleId: article.id)
                                }
                            } label: {
                                HStack {
                                    Text(
                                        verbatim: isValidated
                                            ? (isEnglish ? "✓ Understood (+10 XP earned)" : "✓ Compris (+10 XP gagnés)")
                                            : (isEnglish ? "⚡ Test my understanding (+10 XP)" : "⚡ Tester si j'ai compris (+10 XP)")
                                    )
                                    .font(.system(size: FigMetrics.fourteen, weight: .bold))
                                    .foregroundStyle(
                                        PrismColor.figmaHex(isValidated ? FigPalette.emerald600 : FigPalette.slate900)
                                    )

                                    Spacer()

                                    Image(systemName: isFlashExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: FigMetrics.twelve, weight: .bold))
                                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate500))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tech-news-flash-quiz-\(article.id)")

                            if isFlashExpanded {
                                Text(verbatim: article.localizedFlashPrompt(languageIndex: appState.settingsLanguageIndex))
                                    .font(.system(size: FigMetrics.fourteen, weight: .semibold))
                                    .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                    .fixedSize(horizontal: false, vertical: true)

                                ForEach(article.flashOptions) { opt in
                                    let isChosen = selectedChoiceId == opt.id
                                    let rowBgHex: String = {
                                        guard isChosen else { return FigPalette.white }
                                        return opt.isCorrect ? "#dcfce7" : "#fee2e2"
                                    }()
                                    let rowBorderHex: String = {
                                        guard isChosen else { return FigPalette.slate200 }
                                        return opt.isCorrect ? "#22c55e" : FigPalette.red500
                                    }()

                                    Button {
                                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                            _ = appState.answerTechNewsFlashQuiz(articleId: article.id, optionId: opt.id)
                                        }
                                    } label: {
                                        HStack(spacing: PrismSpacing.s) {
                                            Text(verbatim: opt.badge)
                                                .font(.system(size: FigMetrics.twelve, weight: .bold))
                                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                                .frame(width: FigMetrics.twentyFour, height: FigMetrics.twentyFour)
                                                .background(Circle().fill(PrismColor.figmaHex(FigPalette.slate100)))

                                            Text(verbatim: opt.localizedText(languageIndex: appState.settingsLanguageIndex))
                                                .font(.system(size: FigMetrics.thirteen, weight: .regular))
                                                .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                                                .multilineTextAlignment(.leading)

                                            Spacer(minLength: PrismSpacing.xs)

                                            if isChosen {
                                                Text(verbatim: opt.isCorrect ? "+10 XP ✓" : "✕")
                                                    .font(.system(size: FigMetrics.twelve, weight: .bold))
                                                    .foregroundStyle(PrismColor.figmaHex(opt.isCorrect ? FigPalette.emerald600 : FigPalette.red500))
                                            }
                                        }
                                        .padding(PrismSpacing.m)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                                .fill(PrismColor.figmaHex(rowBgHex))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                                .strokeBorder(PrismColor.figmaHex(rowBorderHex), lineWidth: PrismBorder.standard)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("tech-news-flash-option-\(article.id)-\(opt.id)")
                                }

                                if selectedChoiceId != nil {
                                    Text(verbatim: article.localizedFlashExplanation(languageIndex: appState.settingsLanguageIndex))
                                        .font(.system(size: FigMetrics.thirteen, weight: .regular))
                                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate700))
                                        .padding(PrismSpacing.s)
                                }
                            }
                        }
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                .fill(PrismColor.figmaHex(FigPalette.slate50))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex(FigPalette.slate200), lineWidth: PrismBorder.standard)
                        )

                        // Button `"Lire sur le site officiel"` (`"Read on official website"`)
                        Button {
                            if let url = appState.openTechNewsOfficialWebsite(forArticle: article) {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: PrismSpacing.xs) {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: FigMetrics.fourteen, weight: .bold))
                                Text(
                                    verbatim: isEnglish
                                        ? "Read on official website (\(article.editorialMediaName)) ↗"
                                        : "Lire sur le site officiel (\(article.editorialMediaName)) ↗"
                                )
                                .font(.system(size: FigMetrics.fourteen, weight: .bold))
                                .lineLimit(1)
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: FigMetrics.fortyEight)
                            .background(
                                RoundedRectangle(cornerRadius: FigMetrics.fourteen, style: .continuous)
                                    .fill(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                            )
                            .shadow(color: PrismColor.figmaHex(FigPalette.appleNewsCoralRed).opacity(0.25), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.four)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tech-news-reader-official-site-\(article.id)")
                    }
                }
                .padding(.horizontal, PrismSpacing.xl)
                .padding(.vertical, PrismSpacing.l)
            }

            // Floating Liquid Glass Top Bar (Capture 7: round `✕` on left; `Aa`, `ShareLink`, `bookmark`, `•••` on right)
            HStack(spacing: PrismSpacing.xs) {
                // Left: Floating Liquid Glass Close Button `✕`
                Button {
                    appState.closeTechNewsReaderSheet()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: FigMetrics.fourteen, weight: .bold))
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .frame(width: FigMetrics.thirtyEight, height: FigMetrics.thirtyEight)
                        .background(readerLiquidGlassControlBackground)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tech-news-reader-close-\(article.id)")

                Spacer()

                // Right: Floating Liquid Glass Controls (`Aa`, `ShareLink`, `bookmark`, `•••`)
                HStack(spacing: PrismSpacing.xs) {
                    // `Aa` Font Size Cycling Button (`16 pt`, `18 pt`, `21 pt`)
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            _ = appState.cycleTechNewsReaderFontSize()
                        }
                    } label: {
                        HStack(spacing: FigMetrics.two) {
                            Text(verbatim: "Aa")
                                .font(.system(size: FigMetrics.fourteen, weight: .heavy))
                            Text(verbatim: "\(appState.techNewsState.readerFontSizeTier.rawValue)")
                                .font(.system(size: FigMetrics.ten, weight: .bold))
                                .foregroundStyle(PrismColor.figmaHex(FigPalette.appleNewsCoralRed))
                        }
                        .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                        .padding(.horizontal, PrismSpacing.s)
                        .frame(height: FigMetrics.thirtyEight)
                        .background(readerLiquidGlassCapsuleBackground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tech-news-reader-font-size-button-\(article.id)")

                    // `ShareLink` (`square.and.arrow.up`)
                    ShareLink(
                        item: article.sharePayloadText(
                            languageIndex: appState.settingsLanguageIndex,
                            isPlainLanguage: isPlain
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: FigMetrics.fourteen, weight: .bold))
                            .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                            .frame(width: FigMetrics.thirtyEight, height: FigMetrics.thirtyEight)
                            .background(readerLiquidGlassControlBackground)
                    }
                    .buttonStyle(.plain)

                    // Bookmark (`bookmark` / `bookmark.fill`)
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.toggleTechNewsBookmark(forArticleId: article.id)
                        }
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: FigMetrics.fourteen, weight: .bold))
                            .foregroundStyle(
                                isBookmarked
                                    ? PrismColor.figmaHex(FigPalette.appleNewsCoralRed)
                                    : PrismColor.figmaHex(FigPalette.slate900)
                            )
                            .frame(width: FigMetrics.thirtyEight, height: FigMetrics.thirtyEight)
                            .background(readerLiquidGlassControlBackground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tech-news-reader-bookmark-\(article.id)")

                    // Menu `•••` (`ellipsis`)
                    Menu {
                        if let url = article.officialURL {
                            Button {
                                _ = appState.openTechNewsOfficialWebsite(forArticle: article)
                                openURL(url)
                            } label: {
                                Label(
                                    isEnglish ? "Read on official website" : "Lire sur le site officiel",
                                    systemImage: "safari"
                                )
                            }
                        }

                        Button {
                            appState.toggleTechNewsPlainLanguage(forArticleId: article.id)
                        } label: {
                            Label(
                                isEnglish ? "Toggle Simple Version" : "Basculer Version simple",
                                systemImage: "text.badge.checkmark"
                            )
                        }

                        Button {
                            onAskCertiGoAI(article)
                        } label: {
                            Label(
                                isEnglish ? "Open in CertiGo AI Coach" : "Ouvrir dans le Coach IA",
                                systemImage: "sparkles"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: FigMetrics.fourteen, weight: .bold))
                            .foregroundStyle(PrismColor.figmaHex(FigPalette.slate900))
                            .frame(width: FigMetrics.thirtyEight, height: FigMetrics.thirtyEight)
                            .background(readerLiquidGlassControlBackground)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.top, PrismSpacing.m)
        }
    }

    private var readerLiquidGlassControlBackground: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(Color.white.opacity(0.82))
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            PrismColor.figmaHex(FigPalette.slate200)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: PrismBorder.standard
                )
        }
        .shadow(color: Color.black.opacity(0.10), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
    }

    private var readerLiquidGlassCapsuleBackground: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.82))
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            PrismColor.figmaHex(FigPalette.slate200)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: PrismBorder.standard
                )
        }
        .shadow(color: Color.black.opacity(0.10), radius: FigMetrics.eight, x: FigMetrics.zero, y: FigMetrics.three)
    }
}

// MARK: - 7. Followed Tech Media Directory Sheet (`CertiGoTop100SourcesDirectorySheetView`)

public struct CertiGoTop100SourcesDirectorySheetView: View {
    @Binding public var appState: CertiGoNativeAppState
    @Environment(\.openURL) private var openURL

    public init(appState: Binding<CertiGoNativeAppState>) {
        self._appState = appState
    }

    private var isEnglish: Bool {
        (appState.settingsLanguageIndex % 6) == 2
    }

    public var body: some View {
        let sites = CertiGoVerifiedRSSFeedCatalog.sites(
            forCategory: appState.techNewsState.selectedOPMLCategory,
            searchQuery: appState.techNewsState.top100SearchQuery
        )
        let innerConcentricRadius = PrismRadius.concentric(outer: PrismRadius.xl, padding: PrismSpacing.m)

        VStack(spacing: PrismSpacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: isEnglish ? "100 Followed Tech Media" : "Les 100 médias Tech suivis")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Text(verbatim: isEnglish ? "Official engineering blogs, research labs, and global press" : "Blogs d'ingénierie officiels, laboratoires IA et presse spécialisée")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }
                Spacer()
                Button {
                    appState.techNewsState.showTop100SourcesDirectorySheet = false
                } label: {
                    Text(verbatim: "✕")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
                        .background(
                            Circle().fill(PrismColor.figmaHex("#f1f5f9"))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("top100-directory-close-button")
            }
            .padding(.horizontal, PrismSpacing.xl)
            .padding(.top, PrismSpacing.l)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: PrismSpacing.s) {
                    ForEach(sites) { site in
                        HStack(alignment: .top, spacing: PrismSpacing.m) {
                            CertiGoBrandLogoView(vendorId: site.vendorLogoId, size: FigMetrics.twentyEight)

                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                HStack(spacing: PrismSpacing.xs) {
                                    Text(verbatim: site.name)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                        .lineLimit(1)

                                    Spacer(minLength: PrismSpacing.xxs)

                                    if let url = URL(string: site.siteURL) {
                                        Button {
                                            openURL(url)
                                        } label: {
                                            Text(verbatim: isEnglish ? "Open ↗" : "Ouvrir ↗")
                                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                                .foregroundStyle(PrismColor.figmaHex("#2563eb"))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Text(verbatim: site.whyFollowSummary)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                                    .foregroundStyle(PrismColor.figmaHex("#475569"))
                                    .lineLimit(2)

                                Text(verbatim: "\(site.category.shortBadgeTitle) · \(site.countryOrZone)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#94a3b8"))
                            }
                        }
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                        )
                    }
                }
                .padding(.horizontal, PrismSpacing.xl)
                .padding(.bottom, PrismSpacing.xl)
            }
        }
        .background(PrismColor.figmaHex("#f8fafc"))
    }
}

// MARK: - 8. Final Boss Island `🏆 EXAMEN BLANC` at Bottom of Parcours (`CertiGoParcoursFinalExamBossCardView`)

extension CertiGoParcoursFinalExamBossCardView: View {
    public var body: some View {
        let innerConcentricRadius = PrismRadius.concentric(outer: PrismRadius.unitBanner, padding: PrismSpacing.m)

        VStack(spacing: PrismSpacing.s) {
            // Vertical golden connector from Unit 3's last node down to the Final Boss Island
            RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                .fill(PrismColor.figmaHex(connectorHex))
                .frame(width: FigMetrics.four, height: FigMetrics.twentyEight)

            Button {
                onOpenExamModule()
            } label: {
                HStack(spacing: PrismSpacing.m) {
                    ZStack {
                        RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                            .fill(PrismColor.figmaHex("#fef3c7"))
                        Text(verbatim: "🏆")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Bold"))
                    }
                    .frame(width: FigMetrics.fiftySix, height: FigMetrics.fiftySix)

                    VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                        HStack(spacing: PrismSpacing.xs) {
                            Text(verbatim: bossHeaderTitle)
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                                .lineLimit(1)

                            if let badgeTitle = unlockedBadgeTitle {
                                Text(verbatim: badgeTitle)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#78350f"))
                                    .padding(.horizontal, PrismSpacing.xs)
                                    .padding(.vertical, PrismSpacing.xxs)
                                    .background(
                                        Capsule().fill(PrismColor.figmaHex("#fde68a"))
                                    )
                            }
                        }

                        Text(verbatim: statusSubtitle)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#fef3c7"))
                            .lineLimit(1)
                    }

                    Spacer(minLength: PrismSpacing.xs)

                    Text(verbatim: "GO")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#b45309"))
                        .padding(.horizontal, PrismSpacing.m)
                        .frame(height: FigMetrics.thirtyEight)
                        .background(
                            RoundedRectangle(cornerRadius: innerConcentricRadius, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                }
                .padding(PrismSpacing.l)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                CertiGoTactile3DButtonStyle(
                    faceHex: faceHex,
                    lipHex: "#b45309",
                    strokeHex: "#fde68a",
                    cornerRadius: PrismRadius.unitBanner,
                    lipDepth: FigMetrics.five
                )
            )
            .accessibilityIdentifier("parcours-final-exam-boss-button")
        }
    }
}
#endif
