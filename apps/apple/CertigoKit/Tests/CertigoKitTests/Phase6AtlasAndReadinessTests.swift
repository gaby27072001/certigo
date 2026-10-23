import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite struct Phase6AtlasAndReadinessTests {
    @Test func atlasDefaultsToListUnderVoiceOverAndCapsVisibleNodesAtFiveHundred() {
        let territory = AtlasTerritorySummary(
            id: "t-iam",
            title: "Identité et accès",
            region: .security,
            totalConceptsCount: 10,
            anchoredOrMasteredCount: 7,
            averageDepthRung: 3.5
        )
        #expect(territory.ringProgress == 0.7)

        let regionSummary = AtlasRegionSummary(region: .security, territories: [territory])
        #expect(regionSummary.totalAnchoredOrMasteredCount == 7)
        #expect(regionSummary.averageDepthRung == 3.5)

        let manyNodes = (1...620).map { i in
            PrismAtlasNode(
                id: "n-\(i)",
                code: "C\(i)",
                title: "Concept \(i)",
                region: i.isMultiple(of: 2) ? .cloud : .security,
                masteryState: .anchored,
                normalizedX: 0.5,
                normalizedY: 0.5
            )
        }

        let voAtlas = AtlasScreenModel(
            isVoiceOverRunning: true,
            regions: [regionSummary],
            nodes: manyNodes
        )
        #expect(voAtlas.mode == .list)
        #expect(voAtlas.visibleFilteredNodes.count == AtlasScreenModel.maxVisibleNodesPerFrame)

        let standardAtlas = AtlasScreenModel(
            isVoiceOverRunning: false,
            regions: [regionSummary],
            nodes: manyNodes
        )
        #expect(standardAtlas.mode == .map)
    }

    @Test func conceptDetailExposesDepthLadderMemoryWordAndOneMinutePractice() {
        let concept = ConceptDetailScreenModel(
            id: "az-nsg",
            code: "AZ-NSG",
            title: "Groupes de sécurité réseau (NSG)",
            summary: "Filtre le trafic réseau entrant et sortant vers les sous-réseaux et interfaces Azure.",
            product: .azureVirtualNetwork,
            region: .network,
            masteryState: .practicing,
            depthLadder: PrismDepthLadderModel(
                conceptTitle: "Groupes de sécurité réseau (NSG)",
                currentLevel: 3,
                practiceOffPhoneRecommended: true
            ),
            predictedRetention: 0.68,
            forecastPoints: [
                PrismMemoryForecastPoint(dayOffset: 0, dayLabel: "Auj.", retention: 0.92),
                PrismMemoryForecastPoint(dayOffset: 3, dayLabel: "J+3", retention: 0.68),
            ],
            activeMisconception: "Croire qu'un NSG inspecte la couche 7 HTTP comme un WAF."
        )
        #expect(concept.quickPracticeActionTitle == "Pratiquer 1 min")
        #expect(!concept.retentionWordLabel.isEmpty)
        #expect(concept.depthLadder.currentLevel == 3)
        #expect(concept.depthLadder.practiceOffPhoneRecommended)
    }

    @Test func readinessHidesUncalibratedProbabilityAndRequiresThreeWeeksForDateRange() {
        let uncalibratedReadiness = PrismReadinessModel(
            band: .insufficientEvidence,
            isCalibrated: false,
            rawProbability: 0.72,
            uncertaintyLow: 0.30,
            uncertaintyHigh: 0.85,
            evidenceCount: 4,
            recommendedActions: ["Pratiquer Identité Entra ID", "Pratiquer Réseau VNet", "Pratiquer Stockage Blob"]
        )
        let earlyRoute = RouteReadinessScreenModel(
            routeCode: "AZ-900",
            officialTitle: "Microsoft Azure Fundamentals",
            readiness: uncalibratedReadiness,
            objectiveCoverage: [],
            historyWeeksCount: 2,
            estimatedReadyDateRange: "Sous 2 semaines"
        )
        // NS-10: No percentage when uncalibrated / insufficient evidence, no date range under 3 weeks
        #expect(earlyRoute.visibleCalibratedProbability == nil)
        #expect(earlyRoute.visibleDateRangeForecast == nil)

        let calibratedReadiness = PrismReadinessModel(
            band: .readyToTry,
            isCalibrated: true,
            rawProbability: 0.86,
            uncertaintyLow: 0.80,
            uncertaintyHigh: 0.91,
            evidenceCount: 75,
            recommendedActions: ["Faire un examen blanc complet"]
        )
        let matureRoute = RouteReadinessScreenModel(
            routeCode: "AZ-104",
            officialTitle: "Microsoft Azure Administrator",
            readiness: calibratedReadiness,
            objectiveCoverage: [],
            historyWeeksCount: 4,
            estimatedReadyDateRange: "Entre le 5 et le 15 novembre"
        )
        #expect(matureRoute.visibleCalibratedProbability == "86 %")
        #expect(matureRoute.visibleDateRangeForecast == "Entre le 5 et le 15 novembre")
    }

    @Test func passportCalibrationComputesBrierScoreAndGlobalSearchFiltersProducts() {
        let passport = PrismPassportSummary(
            holderPseudonym: "Gabriel",
            holderInitials: "GC",
            primaryRegion: .cloud,
            anchoredConceptsCount: 28,
            masteredConceptsCount: 14,
            completedRhythmWeeks: 6,
            routes: [
                PrismRouteBadgeModel(examCode: "AZ-900", officialTitle: "Microsoft Azure Fundamentals", region: .cloud)
            ],
            verificationLinks: [
                PrismExternalVerificationLink(
                    id: "ms-learn-1",
                    providerName: "Microsoft Learn",
                    label: "Vérifier sur Microsoft Learn",
                    urlString: "https://learn.microsoft.com/credentials/"
                )
            ]
        )
        let history = CalibrationHistoryScreenModel(
            passport: passport,
            samples: [
                CalibrationSamplePoint(id: "s1", confidence: .sure, wasCorrect: true),
                CalibrationSamplePoint(id: "s2", confidence: .sure, wasCorrect: true),
            ],
            recentSessionsCount: 12
        )
        let brier = try! #require(history.brierScore)
        #expect(brier < 0.02)
        #expect(history.calibrationLabel == "Calibration très précise")

        var search = GlobalSearchScreenModel(
            catalog: [
                GlobalSearchResultItem(
                    id: "c-vm",
                    kind: .concept,
                    title: "Disponibilité des machines virtuelles",
                    subtitle: "Zones de disponibilité et VMSS",
                    product: .azureVirtualMachines,
                    region: .cloud
                ),
                GlobalSearchResultItem(
                    id: "r-ai",
                    kind: .route,
                    title: "AI-103 · Microsoft Foundry Engineer",
                    subtitle: "Route de certification IA",
                    product: .microsoftFoundry,
                    region: .ai
                ),
            ]
        )
        #expect(search.filteredResults.count == 2)
        search.query = "Foundry"
        #expect(search.filteredResults.map(\.id) == ["r-ai"])
    }
}
