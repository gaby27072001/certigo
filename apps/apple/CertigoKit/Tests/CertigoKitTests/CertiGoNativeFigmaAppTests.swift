import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("PR #150 — Native Figma App Video Layout, Mimo Reset, 8-Step Onboarding & Parallel Tracks Deduplication")
struct CertiGoNativeFigmaAppTests {

    @Test("selectRoute resets selectedMimoFilter to .allUnits so all 3 units (15 winding nodes) appear after switching certifications")
    func selectRouteResetsSelectedMimoFilterToAllUnits() {
        var appState = CertiGoNativeAppState()
        appState.selectedMimoFilter = .miniLabs
        #expect(appState.filteredUnitsForMimoRail.flatMap(\.lessons).count == 4)

        appState.selectRoute("PCA")
        #expect(appState.activeRouteCode == "PCA")
        #expect(appState.selectedMimoFilter == .allUnits)
        #expect(appState.filteredUnitsForMimoRail.count == 3)
        #expect(appState.filteredUnitsForMimoRail.flatMap(\.lessons).count == 15)
    }

    @Test("8-step native onboarding flow advances from step 0 to step 7, supports back navigation, and dismisses cleanly on completion or close")
    func onboardingEightStepNavigationAndDismissal() {
        var appState = CertiGoNativeAppState()
        #expect(CertiGoNativeAppState.onboardingStepCount == 8)

        appState.startOnboardingFlow()
        #expect(appState.isPresentingOnboardingFlow == true)
        #expect(appState.onboardingStepIndex == 0)

        for expectedNextStep in 1..<CertiGoNativeAppState.onboardingStepCount {
            appState.advanceOnboardingStep()
            #expect(appState.onboardingStepIndex == expectedNextStep)
            #expect(appState.isPresentingOnboardingFlow == true)
        }

        appState.goBackOnboardingStep()
        #expect(appState.onboardingStepIndex == 6)
        appState.advanceOnboardingStep()
        #expect(appState.onboardingStepIndex == 7)

        // Advancing from step 7 (8/8) completes and dismisses the onboarding flow
        appState.advanceOnboardingStep()
        #expect(appState.isPresentingOnboardingFlow == false)

        // Restarting and explicitly dismissing mid-flow resets presentation
        appState.startOnboardingFlow()
        appState.advanceOnboardingStep()
        #expect(appState.onboardingStepIndex == 1)
        appState.dismissOnboardingFlow()
        #expect(appState.isPresentingOnboardingFlow == false)
    }

    @Test("deduplicatedParallelTrackCodes preserves order, returns 3 distinct certifications, and resolves distinct profile titles")
    func deduplicatedParallelTracksHelperAndDistinctProfileTitles() {
        var appState = CertiGoNativeAppState()
        appState.activeRouteCode = "AZ-104"

        let deduplicatedDefault = appState.deduplicatedParallelTrackCodes(
            preferred: ["AZ-104", "AZ-104", "SAA-C03"]
        )
        #expect(deduplicatedDefault == ["AZ-104", "SAA-C03", "PCA"])
        #expect(Set(deduplicatedDefault).count == 3)

        let titles = deduplicatedDefault.map {
            CertiGoNativeRichCatalog.profileCertificationDetail(forCode: $0).title
        }
        #expect(Set(titles).count == 3)
        #expect(titles[0].contains("AZ-104"))
        #expect(titles[1].contains("SAA-C03"))
        #expect(titles[2].contains("PCA"))

        appState.selectRoute("CKA")
        let deduplicatedCustom = appState.deduplicatedParallelTrackCodes(
            preferred: ["AI-102", "CKA", "CCA-F", "AZ-104"]
        )
        #expect(deduplicatedCustom == ["CKA", "AI-102", "CCA-F"])
        let customTitles = deduplicatedCustom.map {
            CertiGoNativeRichCatalog.profileCertificationDetail(forCode: $0).title
        }
        #expect(Set(customTitles).count == 3)
    }
}
