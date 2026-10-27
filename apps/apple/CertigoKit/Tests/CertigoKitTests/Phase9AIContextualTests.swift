import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Phase 9 — Contextual AI, 5-Tier AIRouter, S-24, S-44, S-45 & Evaluation Suite (§11)")
struct Phase9AIContextualTests {

    @Test("5-level AIRouter resolves tiers deterministically and enforces p95 2500ms timeout fallback")
    func aiRouterFiveLevelFallbackAndTimeout() {
        let tier1 = AIRouter(configuration: AIRouterConfiguration(onDeviceFoundationAvailable: true)).resolveActiveTier()
        #expect(tier1 == .onDeviceFoundationModel)

        let tier2 = AIRouter(configuration: AIRouterConfiguration(onDeviceFoundationAvailable: false, privateCloudComputeAvailable: true)).resolveActiveTier()
        #expect(tier2 == .privateCloudCompute)

        let tier3BlockedWithoutConsent = AIRouter(configuration: AIRouterConfiguration(
            onDeviceFoundationAvailable: false,
            privateCloudComputeAvailable: false,
            cloudAIEnabledInSettings: true,
            hasNamedCloudProviderConsent: false
        )).resolveActiveTier()
        #expect(tier3BlockedWithoutConsent == .deterministicAuthorExplanation)

        let tier3WithConsent = AIRouter(configuration: AIRouterConfiguration(
            onDeviceFoundationAvailable: false,
            privateCloudComputeAvailable: false,
            cloudAIEnabledInSettings: true,
            hasNamedCloudProviderConsent: true
        )).resolveActiveTier()
        #expect(tier3WithConsent == .serverTutorExplain)

        let timedOut = AIRouter(configuration: AIRouterConfiguration(
            onDeviceFoundationAvailable: true,
            cloudAIEnabledInSettings: true,
            hasNamedCloudProviderConsent: true,
            simulatedLatencyMs: 2800,
            authorExplanationAvailable: true
        )).resolveActiveTier()
        #expect(timedOut == .deterministicAuthorExplanation)

        let tier5Abstention = AIRouter(configuration: AIRouterConfiguration(
            onDeviceFoundationAvailable: false,
            privateCloudComputeAvailable: false,
            cloudAIEnabledInSettings: false,
            authorExplanationAvailable: false
        )).resolveActiveTier()
        #expect(tier5Abstention == .abstentionOfficialDocs)
    }

    @Test("Local secret redactor strips Bearer tokens, API keys, and emails before routing")
    func secretRedactorSanitizesSensitiveMaterial() {
        let raw = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 api_key=sk-123456 admin@contoso.com"
        #expect(AISecretRedactor.containsSensitiveMaterial(raw) == true)
        let sanitized = AISecretRedactor.redact(raw)
        #expect(sanitized.contains("eyJhbGci") == false)
        #expect(sanitized.contains("sk-123456") == false)
        #expect(sanitized.contains("admin@contoso.com") == false)
        #expect(sanitized.contains("[EXPURGÉ]") == true)
    }

    @Test("S-24 Contextual AI session enforces Effort Contract, 4-level hint ladder, and max 2 Why turns")
    func contextualAISessionEnforcesEffortAndWhyCap() {
        var state = ContextualAISessionState()
        #expect(state.snippet.provenanceBadgeText == "IA · d'après la fiche Private Endpoint & DNS privé Azure · vérifiée le 15 oct. 2026")
        #expect(state.askWhyFollowUp() == true)
        #expect(state.askWhyFollowUp() == true)
        #expect(state.whyTurnCount == 2)
        #expect(state.askWhyFollowUp() == false)

        state.recordFeedback(.thumbsUp)
        #expect(state.feedbackSignal == .thumbsUp)
    }

    @Test("S-44 Compare Concepts & S-45 Misconceptions Map carry verified provenance and official BrandProductIDs")
    func compareAndMisconceptionsModels() {
        let entries = LearnerMisconceptionEntry.defaultEntries
        #expect(entries.count == 2)
        #expect(entries[0].comparisonPair.leftTitle == "Private Endpoint")
        #expect(entries[0].comparisonPair.rightTitle == "Service Endpoint")
        #expect(entries[0].comparisonPair.snippet.provenanceBadgeText.contains("IA · d'après la fiche") == true)
    }

    @Test("Explain-it-back rubric evaluator enforces 5-word effort contract and never reverses authoritative grade")
    func explainBackRubricEvaluator() {
        let evaluator = ExplainBackRubricEvaluator()
        let tooShort = evaluator.evaluate(learnerExplanation: "DNS privé")
        #expect(tooShort.meetsEffortContract == false)
        #expect(tooShort.scoreRatio == 0.0)
        #expect(tooShort.reversesAuthoritativeGrade == false)

        let strong = evaluator.evaluate(
            learnerExplanation: "Le Private Endpoint utilise une IP privée dans le VNet et résout via la zone privatelink."
        )
        #expect(strong.meetsEffortContract == true)
        #expect(strong.matchedConcepts.count == 3)
        #expect(strong.scoreRatio == 1.0)
        #expect(strong.reversesAuthoritativeGrade == false)
    }

    @Test("Release-blocking adversarial & sycophancy evaluation suite passes all 5 guardrails")
    func releaseBlockingEvaluationSuitePasses() {
        let scenarios = AIEvaluationHarness.runReleaseBlockingSuite()
        #expect(scenarios.count == 5)
        for scenario in scenarios {
            #expect(scenario.passedGuardrail == true)
        }
    }

    @Test("06A..06D AI Hub State Machine manages all 4 validated modes, ASCII diagram & exam tip in 06B")
    func aiHubFourModesAndStructuredResponse06B() {
        var hub = CertiGoAIHubStateMachine()
        #expect(CertiGoAIHubScreenMode.allCases == [.home06A, .writtenResponse06B, .liveVoice06C, .historyDrawer06D])
        #expect(hub.activeMode == .home06A)
        #expect(hub.activeMode.screenCode == "06A")

        hub.openWrittenResponse06B()
        #expect(hub.activeMode == .writtenResponse06B)
        #expect(hub.activeMode.screenCode == "06B")
        #expect(hub.activeWrittenResponse.asciiDiagram.contains("privatelink.blob.core.windows.net") == true)
        #expect(hub.activeWrittenResponse.examTip.contains("Astuce examen") == true)

        hub.openHistoryDrawer06D()
        #expect(hub.activeMode == .historyDrawer06D)
        #expect(hub.isHistoryDrawerOpen == true)
        #expect(hub.activeMode.screenCode == "06D")

        hub.closeHistoryDrawer06D()
        #expect(hub.activeMode == .home06A)
        #expect(hub.isHistoryDrawerOpen == false)
    }

    @Test("06C Live Voice session defaults to Nova 1.0x with background audio on locked screen enabled")
    func aiHubLiveVoiceNovaAndLockedScreenBackgroundAudio() {
        var hub = CertiGoAIHubStateMachine()
        #expect(hub.selectedVoice == "Nova")
        #expect(hub.playbackSpeed == 1.0)
        #expect(hub.voiceSpeedBadgeText == "Nova 1.0x")
        #expect(hub.backgroundAudioLockedScreenEnabled == true)
        #expect(hub.isListening == false)
        #expect(hub.isSpeaking == false)

        hub.startLiveVoiceSession()
        #expect(hub.activeMode == .liveVoice06C)
        #expect(hub.activeMode.screenCode == "06C")
        #expect(hub.isListening == true)
        #expect(hub.isSpeaking == false)

        hub.configureLiveVoice(voice: "Nova", speed: 1.2, backgroundAudioLockedScreenEnabled: true)
        #expect(hub.voiceSpeedBadgeText == "Nova 1.2x")
        #expect(hub.backgroundAudioLockedScreenEnabled == true)

        hub.configureLiveVoice(voice: "Nova", speed: 1.0, backgroundAudioLockedScreenEnabled: true)
        #expect(hub.voiceSpeedBadgeText == "Nova 1.0x")

        hub.stopLiveVoiceSession()
        #expect(hub.activeMode == .home06A)
        #expect(hub.isListening == false)
        #expect(hub.isSpeaking == false)
    }

    @Test("06D Push History Drawer (85% width) groups Today and Last 7 Days, filters by search, and opens in 1 tap")
    func aiHubHistoryDrawer85PercentGroupingSearchAndOneTapOpen() {
        var hub = CertiGoAIHubStateMachine()
        #expect(CertiGoAIHubStateMachine.historyDrawerWidthRatio == 0.85)
        #expect(CertiGoAIHubStateMachine.historyDrawerWidthPercent == 85)
        #expect(CertiGoAIHubStateMachine.historyDrawerWidthPoints == PrismSize.drawerWidth)
        #expect(CertiGoAIHistoryTimeGroup.today.title == "Aujourd'hui")
        #expect(CertiGoAIHistoryTimeGroup.lastSevenDays.title == "7 derniers jours")

        #expect(hub.todayConversations.count == 2)
        #expect(hub.lastSevenDaysConversations.count == 2)

        hub.openHistoryDrawer06D()
        #expect(hub.activeMode == .historyDrawer06D)

        hub.historySearchQuery = "PrivateLink"
        #expect(hub.filteredConversations.count == 2)

        hub.historySearchQuery = ""
        let opened = hub.openConversationInOneTap(id: "conv-7d-saa-vpce")
        #expect(opened?.routeCode == "SAA-C03")
        #expect(hub.activeMode == .writtenResponse06B)
        #expect(hub.selectedConversationId == "conv-7d-saa-vpce")
        #expect(hub.activeWrittenResponse.id == "resp-06b-saa-vpce")
    }

    @Test("AI Hub state machine automatically redacts secrets before routing written and voice prompts through 5-level AIRouter")
    func aiHubAutomaticSecretRedactionAndFiveTierRouting() {
        let cloudRouter = AIRouter(configuration: AIRouterConfiguration(
            onDeviceFoundationAvailable: false,
            privateCloudComputeAvailable: false,
            cloudAIEnabledInSettings: true,
            hasNamedCloudProviderConsent: true,
            serverEndpointAvailable: true,
            simulatedLatencyMs: 320
        ))
        var hub = CertiGoAIHubStateMachine(router: cloudRouter)
        #expect(hub.activeRoutingTier == .serverTutorExplain)

        let rawSecretPrompt = "Explique DNS avec Bearer tok_secret_987 et api_key=sk-live-999 pour dev@contoso.com"
        let writtenRouted = hub.submitWrittenPrompt(rawSecretPrompt)
        #expect(hub.activeMode == .writtenResponse06B)
        #expect(writtenRouted.tier == .serverTutorExplain)
        #expect(writtenRouted.creditsMastery == false)
        #expect(hub.lastRedactedInput.contains("tok_secret_987") == false)
        #expect(hub.lastRedactedInput.contains("sk-live-999") == false)
        #expect(hub.lastRedactedInput.contains("dev@contoso.com") == false)
        #expect(hub.lastRedactedInput.contains("[EXPURGÉ]") == true)
        #expect(hub.todayConversations.first?.title.contains("[EXPURGÉ]") == true)

        let voiceRouted = hub.submitVoiceUtterance("Mon secret=topsecret123 et mail ops@contoso.com")
        #expect(hub.activeMode == .liveVoice06C)
        #expect(hub.isListening == false)
        #expect(hub.isSpeaking == true)
        #expect(voiceRouted.redactedLearnerInput.contains("topsecret123") == false)
        #expect(voiceRouted.redactedLearnerInput.contains("ops@contoso.com") == false)
        #expect(hub.liveVoice.activeUserTranscript.contains("[EXPURGÉ]") == true)
    }
}
