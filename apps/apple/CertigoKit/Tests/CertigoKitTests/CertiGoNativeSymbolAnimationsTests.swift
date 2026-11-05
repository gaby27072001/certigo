import Foundation
import Testing
@testable import Prism

@Suite("CertiGo Native SF Symbols Animations, 3D Holographic Badges, Neural Podcast Voice & Exact Article Photos")
struct CertiGoNativeSymbolAnimationsTests {

    @Test("1. CertiGoSymbolAnimationPreset: all 7 presets, discrete vs indefinite triggers, byLayer rendering, and Reduce Motion gating")
    func symbolAnimationPresetsAndReduceMotionGating() {
        #expect(CertiGoSymbolAnimationPreset.allCases.count == 7)
        #expect(CertiGoSymbolAnimationPreset.allCases == [
            .bounceUpByLayer,
            .magicReplace,
            .variableColorIterative,
            .breathePulseByLayer,
            .wiggleByLayer,
            .rotateByLayer,
            .scaleUpActive
        ])

        #expect(CertiGoSymbolAnimationPreset.bounceUpByLayer.isDiscreteTrigger == true)
        #expect(CertiGoSymbolAnimationPreset.magicReplace.isDiscreteTrigger == true)
        #expect(CertiGoSymbolAnimationPreset.wiggleByLayer.isDiscreteTrigger == true)
        #expect(CertiGoSymbolAnimationPreset.rotateByLayer.isDiscreteTrigger == true)

        #expect(CertiGoSymbolAnimationPreset.variableColorIterative.isIndefiniteActive == true)
        #expect(CertiGoSymbolAnimationPreset.breathePulseByLayer.isIndefiniteActive == true)
        #expect(CertiGoSymbolAnimationPreset.scaleUpActive.isIndefiniteActive == true)

        #expect(CertiGoSymbolAnimationPreset.bounceUpByLayer.usesByLayerRendering == true)
        #expect(CertiGoSymbolAnimationPreset.breathePulseByLayer.usesByLayerRendering == true)
        #expect(CertiGoSymbolAnimationPreset.wiggleByLayer.usesByLayerRendering == true)
        #expect(CertiGoSymbolAnimationPreset.rotateByLayer.usesByLayerRendering == true)

        for preset in CertiGoSymbolAnimationPreset.allCases {
            #expect(!preset.higPurposeSummary.isEmpty)
            #expect(preset.isMotionEnabled(reduceMotion: false) == true)
        }
        // Under Reduce Motion, vestibular animations are suppressed while magicReplace crossfade stays enabled
        #expect(CertiGoSymbolAnimationPreset.magicReplace.isMotionEnabled(reduceMotion: true) == true)
        #expect(CertiGoSymbolAnimationPreset.bounceUpByLayer.isMotionEnabled(reduceMotion: true) == false)
        #expect(CertiGoSymbolAnimationPreset.wiggleByLayer.isMotionEnabled(reduceMotion: true) == false)
        #expect(CertiGoSymbolAnimationPreset.rotateByLayer.isMotionEnabled(reduceMotion: true) == false)
    }

    @Test("2. CertiGoHolographicTiltState: deterministic ±14° clamping, diagonal specular shimmer offset, sparkle intensity, and Reduce Motion")
    func holographicTiltPhysicsAndClamping() {
        let neutral = CertiGoHolographicTiltState.neutral
        #expect(neutral.pitchDegrees == 0.0)
        #expect(neutral.yawDegrees == 0.0)
        #expect(neutral.shimmerOffset == .zero)
        #expect(neutral.isInteracting == false)
        #expect(CertiGoHolographicTiltState.defaultSpringResponse == 0.35)
        #expect(CertiGoHolographicTiltState.defaultSpringDampingFraction == 0.72)

        // Moderate drag produces proportional tilt within ±14°
        let midDrag = CertiGoHolographicTiltState.compute(
            dragTranslation: (dx: 40.0, dy: -40.0),
            isUnlocked: true,
            reduceMotion: false
        )
        #expect(midDrag.isInteracting == true)
        #expect(midDrag.yawDegrees == 7.0)
        #expect(midDrag.pitchDegrees == 7.0)
        #expect(midDrag.shimmerOffset.x > 0.0 && midDrag.shimmerOffset.x <= 1.0)
        #expect(midDrag.shimmerOffset.y < 0.0 && midDrag.shimmerOffset.y >= -1.0)
        #expect(midDrag.sparkleIntensity > neutral.sparkleIntensity)
        #expect(midDrag.sparkleIntensity <= 1.0)

        // Extreme drag strictly clamps pitch and yaw to ±14°
        let extremeDrag = CertiGoHolographicTiltState.compute(
            dragTranslation: (dx: 480.0, dy: 520.0),
            isUnlocked: true,
            reduceMotion: false
        )
        #expect(extremeDrag.yawDegrees == 14.0)
        #expect(extremeDrag.pitchDegrees == -14.0)
        #expect(abs(extremeDrag.shimmerOffset.x) <= 1.0)
        #expect(abs(extremeDrag.shimmerOffset.y) <= 1.0)
        #expect(extremeDrag.sparkleIntensity == 1.0)

        // Reduce motion suppresses 3D rotation and shimmer movement
        let reduced = CertiGoHolographicTiltState.compute(
            dragTranslation: (dx: 65.0, dy: -50.0),
            isUnlocked: true,
            reduceMotion: true
        )
        #expect(reduced.pitchDegrees == 0.0)
        #expect(reduced.yawDegrees == 0.0)
        #expect(reduced.shimmerOffset == .zero)
        #expect(reduced.sparkleIntensity == 0.0)
        #expect(reduced.isInteracting == false)

        // NaN safety
        let nanState = CertiGoHolographicTiltState.compute(
            dragTranslation: (dx: .nan, dy: .infinity),
            isUnlocked: true,
            reduceMotion: false
        )
        #expect(nanState.pitchDegrees == 0.0)
        #expect(nanState.yawDegrees == 0.0)
    }

    @Test("3. CertiGoAnimatedSymbolCatalog: all 9 UI components, outline-to-fill tab variants, and Reduce Motion propagation")
    func animatedSymbolCatalogCompleteness() {
        let allSpecs = CertiGoAnimatedSymbolCatalog.allSpecs(reduceMotion: false)
        #expect(allSpecs.count == 9)

        let tabSpec = CertiGoAnimatedSymbolCatalog.spec(for: .bottomTabBar)
        #expect(tabSpec.primaryPreset == .bounceUpByLayer)
        #expect(tabSpec.secondaryPreset == .magicReplace)
        #expect(tabSpec.inactiveSymbol == "map")
        #expect(tabSpec.activeSymbol == "map.fill")
        #expect(tabSpec.respectsReduceMotion == true)

        let padlockSpec = CertiGoAnimatedSymbolCatalog.spec(for: .lockedStepPadlock)
        #expect(padlockSpec.primaryPreset == .wiggleByLayer)
        #expect(padlockSpec.activeSymbol == "lock.fill")

        let speakerSpec = CertiGoAnimatedSymbolCatalog.spec(for: .audioReaderSpeaker)
        #expect(speakerSpec.primaryPreset == .variableColorIterative)
        #expect(speakerSpec.secondaryPreset == .magicReplace)
        #expect(speakerSpec.inactiveSymbol == "speaker.wave.3.fill")
        #expect(speakerSpec.activeSymbol == "pause.fill")

        let sparklesSpec = CertiGoAnimatedSymbolCatalog.spec(for: .aiCoachSparkles)
        #expect(sparklesSpec.primaryPreset == .breathePulseByLayer)
        #expect(sparklesSpec.activeSymbol == "sparkles")

        let correctSpec = CertiGoAnimatedSymbolCatalog.spec(for: .quizCorrectCheckmark)
        #expect(correctSpec.primaryPreset == .bounceUpByLayer)
        #expect(correctSpec.activeSymbol == "checkmark.circle.fill")

        let wrongSpec = CertiGoAnimatedSymbolCatalog.spec(for: .quizWrongCross)
        #expect(wrongSpec.primaryPreset == .wiggleByLayer)
        #expect(wrongSpec.activeSymbol == "xmark.circle.fill")

        let counterSpec = CertiGoAnimatedSymbolCatalog.spec(for: .topHeaderCounters)
        #expect(counterSpec.primaryPreset == .bounceUpByLayer)
        #expect(counterSpec.inactiveSymbol == "flame.fill")
        #expect(counterSpec.activeSymbol == "diamond.fill")

        let refreshSpec = CertiGoAnimatedSymbolCatalog.spec(for: .techNewsRefresh)
        #expect(refreshSpec.primaryPreset == .rotateByLayer)
        #expect(refreshSpec.inactiveSymbol == "arrow.clockwise")

        let shieldSpec = CertiGoAnimatedSymbolCatalog.spec(for: .certificationShieldBadge)
        #expect(shieldSpec.primaryPreset == .scaleUpActive)
        #expect(shieldSpec.secondaryPreset == .breathePulseByLayer)

        // Verify outline (inactive) vs filled (selected) symbols across all 5 tabs
        #expect(CertiGoAnimatedSymbolCatalog.tabSymbols(for: .parcours) == ("map", "map.fill"))
        #expect(CertiGoAnimatedSymbolCatalog.tabSymbols(for: .actus) == ("newspaper", "newspaper.fill"))
        #expect(CertiGoAnimatedSymbolCatalog.tabSymbols(for: .hubIA) == ("sparkles", "sparkles"))
        #expect(CertiGoAnimatedSymbolCatalog.tabSymbols(for: .social) == ("person.2", "person.2.fill"))
        #expect(CertiGoAnimatedSymbolCatalog.tabSymbols(for: .moi) == ("person.crop.circle", "person.crop.circle.fill"))
    }

    @Test("4. Neural / Premium Voice Selector & Natural Podcast Prosody Engine (Zero Robotic Speech)")
    func neuralVoiceSelectionAndNaturalPodcastProsody() throws {
        // 1. Verify selectBestNaturalVoiceCandidate discards novelty voices and ranks Premium > Enhanced > Default with Siri/Neural bonus
        let candidates: [CertiGoVoiceCandidateDescriptor] = [
            CertiGoVoiceCandidateDescriptor(
                identifier: "com.apple.speech.synthesis.voice.Zarvox",
                name: "Zarvox",
                language: "fr-FR",
                qualityTier: .premium,
                isNoveltyVoice: true
            ),
            CertiGoVoiceCandidateDescriptor(
                identifier: "com.apple.ttsbundle.Thomas-compact",
                name: "Thomas",
                language: "fr-FR",
                qualityTier: .defaultCompact,
                isNoveltyVoice: false
            ),
            CertiGoVoiceCandidateDescriptor(
                identifier: "com.apple.voice.enhanced.fr-FR.Thomas",
                name: "Thomas (Enhanced)",
                language: "fr-FR",
                qualityTier: .enhanced,
                isNoveltyVoice: false
            ),
            CertiGoVoiceCandidateDescriptor(
                identifier: "com.apple.voice.premium.fr-FR.Audrey",
                name: "Audrey (Premium)",
                language: "fr-FR",
                qualityTier: .premium,
                isNoveltyVoice: false
            ),
            CertiGoVoiceCandidateDescriptor(
                identifier: "com.apple.voice.premium.en-US.Ava",
                name: "Ava (Premium)",
                language: "en-US",
                qualityTier: .premium,
                isNoveltyVoice: false
            )
        ]

        let bestFR = try #require(
            CertiGoTechNewsAudioReaderState.selectBestNaturalVoiceCandidate(from: candidates, for: "fr-FR")
        )
        #expect(bestFR.name == "Audrey (Premium)")
        #expect(bestFR.qualityTier == .premium)
        #expect(bestFR.isNoveltyVoice == false)

        let bestEN = try #require(
            CertiGoTechNewsAudioReaderState.selectBestNaturalVoiceCandidate(from: candidates, for: "en-US")
        )
        #expect(bestEN.name == "Ava (Premium)")
        #expect(bestEN.qualityTier == .premium)

        // 2. Verify phoneticNormalizedForSpeech transforms acronyms and removes robotic symbols
        let rawSample = " #1 · AZ-900, AI-900, GH-300, SAA-C03, CKA, API, IAM, SQL, SLA, CVE et ANSSI ↗ 1.0x * "
        let normalized = CertiGoTechNewsAudioReaderState.phoneticNormalizedForSpeech(rawSample)
        #expect(normalized.contains("A Z 900"))
        #expect(normalized.contains("A I 900"))
        #expect(normalized.contains("G H 300"))
        #expect(normalized.contains("S A A C 03"))
        #expect(normalized.contains("C K A"))
        #expect(normalized.contains("A P I"))
        #expect(normalized.contains("I A M"))
        #expect(normalized.contains("S Q L"))
        #expect(normalized.contains("S L A"))
        #expect(normalized.contains("C V E"))
        #expect(normalized.contains("A N S S I"))
        #expect(!normalized.contains("1.0x"))
        #expect(!normalized.contains("·"))
        #expect(!normalized.contains("↗"))
        #expect(!normalized.contains("#"))
        #expect(!normalized.contains("*"))

        // 3. Verify buildNaturalPodcastNarrationSegments produces 3 prosodic segments with breathing pauses (0.22s ... 0.38s)
        let firstArticle = try #require(CertiGoTechNewsCatalog.curatedArticles.first)
        let segments = CertiGoTechNewsAudioReaderState.buildNaturalPodcastNarrationSegments(
            for: firstArticle,
            languageIndex: 0,
            isPlainLanguage: false
        )
        #expect(segments.count == 3)
        #expect(segments[0].role == "intro")
        #expect(segments[0].spokenText.hasPrefix("Actualité publiée par "))
        #expect(segments[0].pitchMultiplier == 1.03)
        #expect(abs(segments[0].rateScaleFactor - 0.96) < 0.001)
        #expect(segments[1].role == "facts")
        #expect(segments[1].spokenText.hasPrefix("Concrètement, "))
        #expect(segments[2].role == "takeaway")
        #expect(segments[2].spokenText.hasPrefix("Ce qu'il faut retenir : "))

        for seg in segments {
            #expect(seg.preUtteranceDelay >= 0.22 && seg.preUtteranceDelay <= 0.38)
            #expect(seg.postUtteranceDelay >= 0.22 && seg.postUtteranceDelay <= 0.38)
            #expect(!seg.spokenText.contains("·"))
            #expect(!seg.spokenText.contains("↗"))
            #expect(!seg.spokenText.contains("#"))
        }

        // 4. Verify discrete iOS Premium Voice tip
        let tipFR = CertiGoTechNewsAudioReaderState.premiumVoiceInstallationTip(languageIndex: 0)
        #expect(tipFR.contains("Réglages > Accessibilité > Contenu énoncé > Voix"))
    }

    @Test("5. Exact Article Photo Extraction: RSS <media:content>, <enclosure>, <itunes:image>, <img src>, OpenGraph og:image / twitter:image, and 100% catalog coverage")
    func exactArticlePhotoExtractionAndCatalogCoverage() throws {
        // 1. Verify 100% of curated articles in CertiGoTechNewsCatalog have a valid https:// imageURL and 3 journalistic sections
        #expect(!CertiGoTechNewsCatalog.curatedArticles.isEmpty)
        for article in CertiGoTechNewsCatalog.curatedArticles {
            let imageURLString = try #require(article.imageURL)
            let url = try #require(URL(string: imageURLString))
            #expect(url.scheme == "https")
            let sections = article.structuredJournalisticSections(isPlainLanguage: false, languageIndex: 0)
            #expect(sections.count == 3)
            #expect(sections[0].heading == "1. Les faits (Ce qui a été annoncé / publié)")
            #expect(sections[1].heading == "2. Comprendre le contexte technique (Apprendre en lisant)")
            #expect(sections[2].heading == "3. Ce qu'il faut retenir")
        }

        // 2. Verify RSS/XML priority 1: <media:content> / <media:thumbnail>
        let xmlMedia = """
        <item>
          <title>OpenAI Agents Update</title>
          <link>https://openai.com/news/agents</link>
          <media:content url="https://images.openai.com/photos/agents-hero.jpg&amp;w=1200" medium="image" />
          <description><img src="https://images.openai.com/photos/fallback.jpg" /></description>
        </item>
        """
        #expect(
            CertiGoLiveRSSService.extractArticleImageURL(fromXMLChunk: xmlMedia)
                == "https://images.openai.com/photos/agents-hero.jpg&w=1200"
        )

        // 3. Verify RSS/XML priority 2: <enclosure type="image/..." />
        let xmlEnclosure = """
        <item>
          <title>Azure AKS Release</title>
          <enclosure url="https://blogs.microsoft.com/uploads/aks-cover.webp" type="image/webp" length="42000" />
        </item>
        """
        #expect(
            CertiGoLiveRSSService.extractArticleImageURL(fromXMLChunk: xmlEnclosure)
                == "https://blogs.microsoft.com/uploads/aks-cover.webp"
        )

        // 4. Verify RSS/XML priority 3: <itunes:image href="..." />
        let xmlItunes = """
        <item>
          <title>Security Podcast</title>
          <itunes:image href="https://cert.cyber.gouv.fr/assets/episode-cover.png" />
        </item>
        """
        #expect(
            CertiGoLiveRSSService.extractArticleImageURL(fromXMLChunk: xmlItunes)
                == "https://cert.cyber.gouv.fr/assets/episode-cover.png"
        )

        // 5. Verify RSS/XML priority 4: <img src="..." /> inside <content:encoded> or <description> (with relative path resolution)
        let xmlImg = """
        <item>
          <title>Cloud Run GPU</title>
          <description>&lt;p&gt;News&lt;/p&gt;&lt;img src="/images/cloud-run-gpu.jpg" alt="GPU" /&gt;</description>
        </item>
        """
        #expect(
            CertiGoLiveRSSService.extractArticleImageURL(
                fromXMLChunk: xmlImg,
                baseArticleURL: "https://cloud.google.com/blog/products"
            ) == "https://cloud.google.com/images/cloud-run-gpu.jpg"
        )

        // 6. Verify OpenGraph og:image & twitter:image HTML extractor in CertiGoArticlePhotoResolver
        let sampleHTML = """
        <html><head>
        <meta name="twitter:image" content="https://openai.com/twitter-card.jpg" />
        <meta property="og:image" content="/assets/exact-article-photo.jpg&amp;v=2" />
        </head></html>
        """
        let resolvedOG = CertiGoArticlePhotoResolver.extractOpenGraphOrTwitterImageURL(
            fromHTML: sampleHTML,
            baseURL: URL(string: "https://openai.com/news/codex")
        )
        #expect(resolvedOG == "https://openai.com/assets/exact-article-photo.jpg&v=2")
    }

    @Test("6. WWDC 2026 Shared Intelligence Context (Zero Multimodal Photo) & AppIntents Screen Entity Donations")
    func sharedIntelligenceContextAndEntityAnnotations() throws {
        var appState = CertiGoNativeAppState(restoreFromDisk: false)
        // Multimodal photo must remain strictly disabled per Gabriel's decision
        #expect(appState.sharedIntelligenceContext.isMultimodalPhotoEnabled == false)

        appState.sharedIntelligenceContext.recordLessonStudy(
            routeCode: "AZ-104",
            routeTitle: "Microsoft Azure Administrator",
            lessonId: "AZ-104-u1-s2",
            lessonTitle: "Private Endpoint & DNS privé",
            conceptTitle: "Zones DNS privées Azure"
        )
        appState.sharedIntelligenceContext.recordMockExamResult(routeCode: "AZ-104", scoreOutOf1000: 820)

        CertiGoInteractionDonationCenter.shared.resetDonations()
        let firstArticle = try #require(CertiGoTechNewsCatalog.curatedArticles.first)
        appState.openTechNewsReaderSheet(forArticleId: firstArticle.id)

        #expect(appState.sharedIntelligenceContext.lastReadNewsArticleId == firstArticle.id)
        let summaryFR = appState.sharedIntelligenceContext.buildCrossSurfaceCoachingSummary(languageIndex: 0)
        #expect(summaryFR.contains("AZ-104"))
        #expect(summaryFR.contains("Private Endpoint & DNS privé"))
        #expect(summaryFR.contains("820/1000"))
        #expect(summaryFR.contains(firstArticle.headlineFR))

        let donated = try #require(CertiGoInteractionDonationCenter.shared.lastDonatedAnnotation)
        #expect(donated.kind == .techNewsArticle)
        #expect(donated.id == "article-\(firstArticle.id)")
        #expect(donated.routeCode == firstArticle.linkedCertificationCode)
    }
}
