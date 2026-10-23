import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Phase 11 — Accessibility AX5, Performance Budgets §30, Analytics Taxonomy §31 & Hardening (§28–34)")
struct Phase11HardeningTests {

    @Test("§28 Accessibility audit verifies all 13 dimensions and all 9 App Store Nutrition Labels")
    func accessibilityAuditAndAppStoreNutritionLabels() {
        let summary = AccessibilityAuditSummary()
        #expect(summary.passesAllAccessibilityGates == true)
        #expect(summary.verifiedDimensions.count == 13)
        #expect(summary.eligibleNutritionLabels.count == 9)
        #expect(summary.minimumTapTargetPt >= 44.0)
        #expect(summary.calmModeMaxCelebrationLevel == 1)
    }

    @Test("§30 Performance budget gate enforces cold launch, transition, feedback, Atlas 60fps/500 nodes, memory, size, and energy")
    func performanceBudgetsMeetSection30Thresholds() {
        let nominal = PerformanceBudgetSnapshot()
        #expect(nominal.meetsAllSection30Budgets == true)

        let regressed = PerformanceBudgetSnapshot(coldLaunchMs: 520, activeRestingTimersOrLoops: 1)
        #expect(regressed.meetsAllSection30Budgets == false)
    }

    @Test("§31 Normative analytics taxonomy uses strict snake_case and emits critical journey events in Debug")
    func normativeAnalyticsTaxonomyAndCriticalJourneys() {
        #expect(NormativeAnalyticsEventName.allCases.count == 53)
        for event in NormativeAnalyticsEventName.allCases {
            #expect(event.isSnakeCase == true)
        }
        let journeys = CriticalJourneyDescriptor.allEightJourneys
        #expect(journeys.count == 8)
        for journey in journeys {
            #expect(journey.passesAccessibilityAudit == true)
        }
    }

    @Test("§34.1 Legacy path retirement requires >= 14 days ON in production with 0 incident")
    func legacyPathRetirementGovernance() {
        let tooEarly = LegacyPathCleanupGovernance(flag: FeatureFlag.allCases[0], daysEnabledInProduction: 10, recordedIncidents: 0)
        #expect(tooEarly.isEligibleForLegacyPathDeletion == false)

        let withIncident = LegacyPathCleanupGovernance(flag: FeatureFlag.allCases[0], daysEnabledInProduction: 21, recordedIncidents: 1)
        #expect(withIncident.isEligibleForLegacyPathDeletion == false)

        let ready = LegacyPathCleanupGovernance(flag: FeatureFlag.allCases[0], daysEnabledInProduction: 14, recordedIncidents: 0)
        #expect(ready.isEligibleForLegacyPathDeletion == true)
    }
}
