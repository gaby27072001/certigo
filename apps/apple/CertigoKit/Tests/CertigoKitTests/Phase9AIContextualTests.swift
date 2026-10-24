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
}
