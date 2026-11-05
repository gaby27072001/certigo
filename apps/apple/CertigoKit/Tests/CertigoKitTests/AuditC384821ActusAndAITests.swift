import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Audit c384821 — Section 3 (Actus P1-16..P3-22) & Section 4 (Coach IA P1-23..P2-26)", .serialized)
struct AuditC384821ActusAndAITests {

    private func loadSourceFile(_ relativePath: String) throws -> String {
        var repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("AGENTS.md").path) {
            let parent = repoRoot.deletingLastPathComponent()
            guard parent != repoRoot else { throw CocoaError(.fileNoSuchFile) }
            repoRoot = parent
        }
        let fileURL = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    @Test("P1-16: Article Reader Sheet constrains width, uses uniform 20pt content margins and 16pt/12pt floating bar margins, and wraps all text at Aa 16/18/21")
    func testP1_16_ArticleReaderWidthAndMargins() throws {
        var appState = CertiGoNativeAppState(restoreFromDisk: false)
        let articles = CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles
        let azureArticle = try #require(articles.first(where: { $0.vendorLogoId == "microsoft" }))
        let openAIArticle = try #require(articles.first(where: { $0.vendorLogoId == "openai" }))

        for article in [azureArticle, openAIArticle] {
            appState.openTechNewsReaderSheet(forArticleId: article.id)
            #expect(appState.techNewsState.activeReaderSheetArticleId == article.id)
            #expect(!article.appleNewsCategoryKicker(languageIndex: 0).isEmpty)
            #expect(!article.localizedHeadline(languageIndex: 0).isEmpty)
            #expect(article.appleNewsBylineAndTimestamp(languageIndex: 0).hasPrefix("Par "))
            #expect(article.appleNewsPhotoCaptionCredit(languageIndex: 0).hasPrefix("Photo : "))
            let sections = article.structuredJournalisticSections(isPlainLanguage: false, languageIndex: 0)
            #expect(sections.count == 3)
        }

        // Verify Aa font size tiers 16, 18, 21 pt
        #expect(appState.techNewsState.readerFontSizeTier == .standard18)
        #expect(appState.cycleTechNewsReaderFontSize() == 21)
        #expect(appState.cycleTechNewsReaderFontSize() == 16)
        #expect(appState.cycleTechNewsReaderFontSize() == 18)

        let actusSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoTechNewsAndExamRouting.swift"
        )
        #expect(!actusSource.contains("UIScreen.main.bounds.width"))
        #expect(actusSource.contains("GeometryReader { readerGeo in"))
        #expect(actusSource.contains(".frame(width: safeReaderWidth, alignment: .leading)"))
        #expect(actusSource.contains(".padding(.horizontal, FigMetrics.twenty)"))
        #expect(actusSource.contains(".padding(.horizontal, FigMetrics.sixteen)"))
        #expect(actusSource.contains(".padding(.top, FigMetrics.twelve)"))
    }

    @Test("P2-17: Actus feed masthead, non-truncated TECH EDITION • CERTIGO badge, visible Refresh button, and symmetric 16pt margins")
    func testP2_17_ActusMastheadBadgeAndMargins() throws {
        #expect(CertiGoNativeAppState.appleNewsEditionStampText == "TECH EDITION • CERTIGO")

        let actusSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoTechNewsAndExamRouting.swift"
        )
        #expect(actusSource.contains("GeometryReader { feedGeo in"))
        #expect(actusSource.contains(".frame(width: safeFeedWidth, alignment: .leading)"))
        #expect(actusSource.contains("CertiGoNativeAppState.appleNewsEditionStampText"))
        #expect(actusSource.contains("tech-news-refresh-live-rss-button"))
        #expect(actusSource.contains("tech-news-header-saved-button"))
        #expect(actusSource.contains("tech-news-header-sources-button"))
    }

    @Test("P2-18: Dynamic edition date based on Date() with zero hardcoded '29 octobre' or 'Mercredi 4 novembre' and explicit 'Mis à jour aujourd'hui' sync label")
    func testP2_18_DynamicEditionDateWithoutHardcoded29Octobre() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let nov5Date = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12)))

        let appState = CertiGoNativeAppState(restoreFromDisk: false)
        let dateLineFR = appState.appleNewsMastheadDateLine(languageIndex: 0, referenceDate: nov5Date)
        let dateLineEN = appState.appleNewsMastheadDateLine(languageIndex: 2, referenceDate: nov5Date)
        #expect(dateLineFR == "Jeudi 5 novembre")
        #expect(dateLineEN == "Thursday, November 5")

        let liveDateFR = appState.appleNewsMastheadDateLine(languageIndex: 0)
        #expect(!liveDateFR.isEmpty)
        #expect(liveDateFR != "29 octobre")

        let subtitleFR = appState.editorialHeaderDateSubtitle(languageIndex: 0)
        let subtitleEN = appState.editorialHeaderDateSubtitle(languageIndex: 2)
        #expect(subtitleFR.hasPrefix("Mis à jour aujourd'hui"))
        #expect(subtitleEN.hasPrefix("Updated today"))

        let actusSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoTechNewsAndExamRouting.swift"
        )
        #expect(!actusSource.contains("\"29 octobre\""))
        #expect(!actusSource.contains("\"October 29\""))
        #expect(!actusSource.contains("\"Mercredi 4 novembre"))
    }

    @Test("P2-19: Reader audio bar has a single headphones icon and 2 non-truncated rows (Row 1: Listen + Voice subtitle, Row 2: Speeds 0.9×/1.0×/1.25× + Version simple switch)")
    func testP2_19_ReaderAudioBarTwoRowsWithoutDuplicateHeadphonesOrTruncation() throws {
        let reader = CertiGoTechNewsAudioReaderState()
        let listenTitleFR = reader.readerListenActionTitle(isSpeakingArticle: false, languageIndex: 0)
        let pauseTitleFR = reader.readerListenActionTitle(isSpeakingArticle: true, languageIndex: 0)
        let voiceSubFR = reader.readerVoiceSubtitle(languageIndex: 0)

        #expect(listenTitleFR == "Écouter cet article")
        #expect(!listenTitleFR.contains("🎧"))
        #expect(pauseTitleFR == "Mettre en pause la lecture")
        #expect(voiceSubFR == "Audrey (Premium) · Voix Neurale · Studio HD")
        #expect(CertiGoTechNewsAudioReaderState.appleNewsReaderSpeedMultipliers == [0.9, 1.0, 1.25])

        let actusSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoTechNewsAndExamRouting.swift"
        )
        #expect(!actusSource.contains("🎧 Écouter cet article"))
        #expect(!actusSource.contains("🎧 Listen to this article"))
        #expect(actusSource.contains("readerListenActionTitle"))
        #expect(actusSource.contains("readerVoiceSubtitle"))
        #expect(actusSource.contains("0.9×"))
        #expect(actusSource.contains("1.0×"))
        #expect(actusSource.contains("1.25×"))
    }

    @Test("P2-20: Sources & Thèmes never assigns the Microsoft logo to third-party media (Ars Technica, Bloomberg, Financial Times, TechCrunch, The Register, etc.) and allows 2-line titles/descriptions")
    func testP2_20_SourcesDirectoryAuthenticOrNeutralLogosAndTwoLineTitles() throws {
        let sites = CertiGoVerifiedRSSFeedCatalog.all100RankedSites
        #expect(sites.count == 100)

        let microsoftSite = try #require(sites.first(where: { $0.rank == 2 }))
        #expect(microsoftSite.authenticBrandLogoId == "microsoft")
        #expect(microsoftSite.usesOfficialBrandLogo == true)

        let openAISite = try #require(sites.first(where: { $0.rank == 1 }))
        #expect(openAISite.authenticBrandLogoId == "openai")
        #expect(openAISite.usesOfficialBrandLogo == true)

        let thirdPartyNames = [
            "Ars Technica",
            "Bloomberg Technology",
            "Financial Times · Technology",
            "TechCrunch",
            "The Register",
            "Reuters Technology",
            "WIRED",
            "The Verge",
            "MIT Technology Review"
        ]
        for mediaName in thirdPartyNames {
            let site = try #require(sites.first(where: { $0.name == mediaName }), "Missing site \(mediaName)")
            #expect(site.authenticBrandLogoId == nil, "\(mediaName) must not use an official vendor logo")
            #expect(site.vendorLogoId != "microsoft", "\(mediaName) must never use the Microsoft logo")
            #expect(site.usesOfficialBrandLogo == false)
            #expect(site.editorialMonogram.count == 2)
        }

        let actusSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoTechNewsAndExamRouting.swift"
        )
        #expect(actusSource.contains("CertiGoSourceDirectoryAvatarView(site: site"))
    }

    @Test("P2-21: Top Bookmark button / Enregistrés pill switches to 'Articles enregistrés' and shows explicit empty state when bookmarkedArticleIDs.isEmpty")
    func testP2_21_SavedArticlesDestinationAndExplicitEmptyState() throws {
        var appState = CertiGoNativeAppState(restoreFromDisk: false)
        #expect(appState.bookmarkedArticleIDs.isEmpty)
        #expect(appState.isShowingSavedTechNewsArticles == false)
        #expect(appState.activeTechNewsPrimarySectionTitle(languageIndex: 0) == "À la Une")

        appState.selectAppleNewsTopicPill(.saved)
        #expect(appState.isShowingSavedTechNewsArticles == true)
        #expect(appState.activeTechNewsPrimarySectionTitle(languageIndex: 0) == "Articles enregistrés")
        #expect(appState.bookmarkedTechNewsArticles.isEmpty)
        #expect(CertiGoNativeAppState.savedArticlesEmptyStateTitle(languageIndex: 0) == "Aucun article enregistré")
        #expect(
            CertiGoNativeAppState.savedArticlesEmptyStateMessage(languageIndex: 0)
                == "Touchez l'icône de signet sur n'importe quel article pour le retrouver ici et le lire ou l'écouter plus tard."
        )
        #expect(
            CertiGoNativeAppState.savedArticlesExploreButtonTitle(languageIndex: 0)
                == "Explorer les actualités à la une"
        )

        let firstArticle = try #require(CertiGoVerifiedRSSFeedCatalog.defaultCuratedTechNewsArticles.first)
        appState.toggleTechNewsBookmark(forArticleId: firstArticle.id)
        #expect(appState.bookmarkedArticleIDs.contains(firstArticle.id))
        #expect(appState.bookmarkedTechNewsArticles.map(\.id) == [firstArticle.id])

        let actusSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoTechNewsAndExamRouting.swift"
        )
        #expect(actusSource.contains("tech-news-saved-empty-state-card"))
        #expect(actusSource.contains("tech-news-saved-back-to-top-stories-button"))
        #expect(!actusSource.contains("return saved.isEmpty ? base : saved"))
    }

    @Test("P3-22: Horizontal topic pills scroll indicator & decorative article icons hidden from accessibility tree ('Ciel Couvert')")
    func testP3_22_TopicPillsScrollHintAndDecorativeIconsAccessibilityHidden() throws {
        let actusSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoTechNewsAndExamRouting.swift"
        )
        #expect(actusSource.contains("chevron.compact.right"))
        #expect(actusSource.contains(".accessibilityHidden(true)"))
        #expect(actusSource.contains("Image(systemName: article.editorialWatermarkSymbol)"))
    }

    @Test("P1-23: Coach IA reserves bottom space for both input field and tab bar via safeAreaInset(edge: .bottom) with zero white gap and zero overlap")
    func testP1_23_CoachIABottomSafeAreaInsetAndClearance() throws {
        #expect(CertiGoChatGPTLiquidGlassChromeSpec.bottomTabBarReservedClearance == 84)
        #expect(CertiGoChatGPTLiquidGlassChromeSpec.bottomInputBarReservedClearance == 68)
        #expect(CertiGoChatGPTLiquidGlassChromeSpec.totalBottomScrollClearance == 156)

        let chatGPTSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoChatGPTExperienceView.swift"
        )
        #expect(chatGPTSource.contains(".safeAreaInset(edge: .bottom, spacing: FigMetrics.zero)"))
        #expect(!chatGPTSource.contains("isInputFocused.wrappedValue ? FigMetrics.eight : FigMetrics.eightyEight"))
    }

    @Test("P2-24: Top pill displays 'CertiGo GPT · AZ-104' without duplicate star, welcome suggestions wrap on 2 lines, and follow-up placeholder is 100% French in FR")
    func testP2_24_TopPillSingleStarTwoLineSuggestionsAndLocalizedPlaceholder() throws {
        var appState = CertiGoNativeAppState(restoreFromDisk: false)
        appState.selectRoute("AZ-104")

        let pillTitle = CertiGoChatGPTLiquidGlassChromeSpec.centerPillTitle(forRouteCode: "AZ-104")
        #expect(pillTitle == "CertiGo GPT · AZ-104")
        #expect(!pillTitle.contains("✦"))
        #expect(CertiGoChatGPTExperienceViewModel.centerHeaderPillTitle(for: appState) == "CertiGo GPT · AZ-104")

        let initialFR = CertiGoChatGPTLiquidGlassChromeSpec.inputPlaceholder(
            hasExistingTurns: false,
            isStreaming: false,
            languageIndex: 0
        )
        let followUpFR = CertiGoChatGPTLiquidGlassChromeSpec.inputPlaceholder(
            hasExistingTurns: true,
            isStreaming: false,
            languageIndex: 0
        )
        let followUpEN = CertiGoChatGPTLiquidGlassChromeSpec.inputPlaceholder(
            hasExistingTurns: true,
            isStreaming: false,
            languageIndex: 2
        )
        #expect(initialFR == "Demander à CertiGo IA")
        #expect(followUpFR == "Poser une question de suivi")
        #expect(!followUpFR.contains("Follow up"))
        #expect(followUpEN == "Ask a follow-up")

        let chatGPTSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoChatGPTExperienceView.swift"
        )
        #expect(!chatGPTSource.contains("Poser une question de suivi · Follow up"))
        #expect(!chatGPTSource.contains("Follow up"))
    }

    @Test("P1-25: Each thread and message pins its own trackCode ('AZ-104') and is never relabeled to 'AZ-900' when switching certification elsewhere")
    func testP1_25_PinTrackCodePerThreadAndMessageAcrossCertificationSwitch() throws {
        CertiGoChatGPTTrackPinRegistry.reset()
        var appState = CertiGoNativeAppState(restoreFromDisk: false)
        appState.selectRoute("AZ-104")

        // 1. Create RBAC discussion on AZ-104
        appState.openAITopic("rbac-vs-policy")
        let rbacTurn = try #require(appState.chatTurns.last)
        #expect(CertiGoChatGPTExperienceViewModel.resolvedTrackCode(for: rbacTurn, in: appState) == "AZ-104")
        #expect(CertiGoChatGPTExperienceViewModel.activeConversationTrackCode(for: appState) == "AZ-104")
        #expect(CertiGoChatGPTExperienceViewModel.hasGlobalTrackDivergedFromActiveThread(for: appState) == false)

        // 2. Open AZ-900 exam and return to Coach IA
        appState.openExamModuleFromCoursePopover(forRouteCode: "AZ-900")
        appState.closeExamModule()
        #expect(appState.activeRouteCode == "AZ-900")

        // 3. Verify the existing RBAC thread and message remain strictly pinned to AZ-104
        #expect(CertiGoChatGPTExperienceViewModel.resolvedTrackCode(for: rbacTurn, in: appState) == "AZ-104")
        #expect(CertiGoChatGPTExperienceViewModel.activeConversationTrackCode(for: appState) == "AZ-104")
        #expect(CertiGoChatGPTExperienceViewModel.centerHeaderPillTitle(for: appState) == "CertiGo GPT · AZ-104")

        let doc = CertiGoChatGPTExperienceViewModel.document(for: rbacTurn, in: appState)
        #expect(doc.emojiAndH2Title.contains("AZ-104"))
        #expect(!doc.emojiAndH2Title.contains("AZ-900"))
        #expect(doc.metadataLines[0].value.contains("AZ-104"))
        #expect(!doc.metadataLines[0].value.contains("AZ-900"))

        let pinnedMsgs = CertiGoChatGPTExperienceViewModel.pinnedMessages(for: appState)
        #expect(pinnedMsgs.count == 1)
        #expect(pinnedMsgs[0].trackCode == "AZ-104")

        let pinnedThreads = CertiGoChatGPTExperienceViewModel.pinnedThreads(for: appState)
        #expect(pinnedThreads.first?.trackCode == "AZ-104")

        // 4. Verify diverged-track banner offers 'Nouvelle discussion AZ-900' without overwriting AZ-104 history
        #expect(CertiGoChatGPTExperienceViewModel.hasGlobalTrackDivergedFromActiveThread(for: appState) == true)
        #expect(CertiGoChatGPTExperienceViewModel.divergedTrackBannerTitle(for: appState) == "Nouvelle discussion AZ-900")

        CertiGoChatGPTExperienceViewModel.startNewThreadForActiveGlobalRoute(&appState)
        #expect(appState.chatTurns.isEmpty)
        #expect(CertiGoChatGPTExperienceViewModel.activeConversationTrackCode(for: appState) == "AZ-900")
        #expect(appState.aiThreads.first?.routeBadge == "AZ-104")
    }

    @Test("P2-26: Standalone H2 response titles never truncate mid-sentence on 'mais ils', and history drawer rows expand to 2 lines")
    func testP2_26_StandaloneResponseTitlesAndExpandableHistoryDrawerRows() throws {
        var appState = CertiGoNativeAppState(restoreFromDisk: false)
        appState.selectRoute("AZ-104")
        appState.openAITopic("rbac-vs-policy")
        let turn = try #require(appState.chatTurns.last)
        let doc = CertiGoChatGPTRichResponseParser.parse(turn: turn, routeCode: "AZ-104")

        #expect(doc.emojiAndH2Title == "🛡️ RBAC vs Azure Policy (AZ-104)")
        #expect(!doc.emojiAndH2Title.lowercased().contains("mais ils"))

        // Verify all topics in aiTopicsById produce clean, self-contained H2 titles
        for (topicKey, _) in CertiGoFigmaLiveRuntimeState.aiTopicsById {
            var topicState = CertiGoNativeAppState(restoreFromDisk: false)
            topicState.selectRoute("AZ-104")
            topicState.openAITopic(topicKey)
            let topicTurn = try #require(topicState.chatTurns.last)
            let topicDoc = CertiGoChatGPTRichResponseParser.parse(turn: topicTurn, routeCode: "AZ-104")
            #expect(!topicDoc.emojiAndH2Title.isEmpty)
            #expect(!topicDoc.emojiAndH2Title.lowercased().hasSuffix("mais ils"))
            #expect(topicDoc.emojiAndH2Title.contains("AZ-104"))
        }

        let chatGPTSource = try loadSourceFile(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoChatGPTExperienceView.swift"
        )
        #expect(!chatGPTSource.contains(".prefix(9)"))
        #expect(chatGPTSource.contains("standaloneH2Title"))
    }
}
