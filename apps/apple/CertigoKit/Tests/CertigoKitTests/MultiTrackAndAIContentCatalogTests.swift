import BrandAssets
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Multi-Track Parallel Certifications, AI Frontier Actors & 10 Question Formats Catalog")
struct MultiTrackAndAIContentCatalogTests {

    @Test("All 13 parallel certification tracks expose units, winding path steps, 10 question formats, and official assets")
    func parallelCertificationTracksExposeCompleteUnitsFormatsAndAssets() {
        let expectedCodes = [
            "AZ-104", "AZ-900", "AI-102", "AZ-305",
            "SAA-C03", "CLF-C02",
            "ACE", "PCA",
            "GH-300", "CKA", "TF-003", "CCNA", "CCA-F"
        ]
        #expect(CertiGoMultiTrackAndAIContentCatalog.parallelCertificationTrackCodes == expectedCodes)
        #expect(CertiGoMultiTrackAndAIContentCatalog.parallelCertificationTracks.count == 13)

        let allFormats = Set(CertiGoQuestionFormatID.allCases)
        #expect(allFormats.count == 10)

        for code in expectedCodes {
            let track = CertiGoMultiTrackAndAIContentCatalog.track(forCode: code)
            #expect(track.code == code)
            #expect(!track.isAIFrontierTrack)
            #expect(track.units.count == 3)
            #expect(track.activeUnit.steps.count == 5)
            #expect(track.exercises.count == 10)
            #expect(track.coveredQuestionFormats == allFormats)
            #expect(track.certificationAssetName.hasPrefix("Certifications/"))
            #expect(track.brandLogoAssetName.hasPrefix("BrandLogos/"))
            #expect(track.serviceAssetNames.count >= 4)

            for format in CertiGoQuestionFormatID.allCases {
                let exercise = CertiGoMultiTrackAndAIContentCatalog.exercise(forTrackCode: code, format: format)
                #expect(exercise.format == format)
                #expect(exercise.trackCode == code)
                #expect(!exercise.stem.isEmpty)
                #expect(exercise.sessionItem.payload.isSupported)
            }
        }
    }

    @Test("All 5 AI Frontier watch tracks expose units, 10 question formats, and official brand/service assets")
    func aiFrontierTracksExposeCompleteUnitsFormatsAndAssets() throws {
        let expectedTitles = [
            "OpenAI & Architecture GPT",
            "Anthropic & Claude CCA-F",
            "Google Gemini & Vertex AI",
            "Microsoft Foundry & Copilot",
            "Mistral AI & Modèles Open-Weight"
        ]
        #expect(CertiGoMultiTrackAndAIContentCatalog.aiFrontierTrackTitles == expectedTitles)
        #expect(CertiGoMultiTrackAndAIContentCatalog.aiFrontierTracks.count == 5)

        let allFormats = Set(CertiGoQuestionFormatID.allCases)

        for title in expectedTitles {
            let track = try #require(CertiGoMultiTrackAndAIContentCatalog.aiFrontierTrack(titledOrCoded: title))
            #expect(track.officialTitle == title)
            #expect(track.isAIFrontierTrack)
            #expect(track.region == .ai)
            #expect(track.units.count == 3)
            #expect(track.activeUnit.steps.count == 5)
            #expect(track.exercises.count == 10)
            #expect(track.coveredQuestionFormats == allFormats)
            #expect(track.brandLogoAssetName.hasPrefix("BrandLogos/"))

            let q02 = CertiGoMultiTrackAndAIContentCatalog.exercise(forTrackCode: track.code, format: .q02ServiceGrid2x2)
            #expect(q02.serviceGridOptions.count == 4)

            let q03 = CertiGoMultiTrackAndAIContentCatalog.exercise(forTrackCode: track.code, format: .q03InteractiveDiagram)
            #expect(q03.diagramSlot != nil)

            let q04 = CertiGoMultiTrackAndAIContentCatalog.exercise(forTrackCode: track.code, format: .q04IOSKeyboardInput)
            let kb = try #require(q04.keyboardInput)
            #expect(kb.matches(kb.expectedAnswer))

            let q06 = CertiGoMultiTrackAndAIContentCatalog.exercise(forTrackCode: track.code, format: .q06MatchingPairs)
            #expect(q06.matchingPairs.count == 4)

            let q09 = CertiGoMultiTrackAndAIContentCatalog.exercise(forTrackCode: track.code, format: .q09ArchitectureVerdict)
            #expect(q09.architectureVerdict != nil)
        }
    }

    @Test("Every referenced asset across all 18 tracks exists in Prism.xcassets on disk")
    func allReferencedCatalogAssetsExistInPrismXcassets() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let xcassetsRoot = root.appendingPathComponent("apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets")

        let allTracks = CertiGoMultiTrackAndAIContentCatalog.allTracks
        #expect(allTracks.count == 18)

        let allowedPrefixes = [
            "AzureServices/",
            "AWSServices/",
            "GCPServices/",
            "BrandLogos/",
            "Certifications/"
        ]

        for track in allTracks {
            let assets = track.allReferencedAssetNames
            #expect(!assets.isEmpty)
            for assetName in assets {
                #expect(
                    allowedPrefixes.contains(where: { assetName.hasPrefix($0) }),
                    "Unexpected asset prefix for \(assetName) in track \(track.code)"
                )
                let imagesetDir = xcassetsRoot.appendingPathComponent("\(assetName).imageset")
                #expect(
                    FileManager.default.fileExists(atPath: imagesetDir.path),
                    "Missing .imageset on disk for \(assetName) (track \(track.code))"
                )
            }
        }
    }

    @Test("Session player and coordinator switch cleanly across all 18 tracks")
    func sessionPlayerAndCoordinatorSwitchAcrossAllTracks() {
        var coordinator = PrismAppShellCoordinatorModel()
        for track in CertiGoMultiTrackAndAIContentCatalog.allTracks {
            coordinator.activateTrack(code: track.code)
            #expect(coordinator.todayModel.activeRouteCode == track.code)
            #expect(coordinator.todayModel.activeRouteTitle == track.officialTitle)
            #expect(coordinator.catalogExplorer.routes.count == 18)
            // 1 WorkedExample learning card + 10 interactive question format items = 11 cards
            #expect(coordinator.sessionPlayerMachine.plan.cards.count == 11)
        }
    }

    @Test("CertigoParallelTracksPreference persists and reloads parallel tracks, active certification, AI frontier watch, bilingual EN terms, and 90m timed exam mode")
    func parallelTracksPreferencePersistenceAndStoreRoundTrip() throws {
        let defaults = UserDefaults.standard
        let key = "certigo.parallel-tracks.test.\(UUID().uuidString)"
        defer { defaults.removeObject(forKey: key) }

        let store = CertigoParallelTracksPreferenceStore(defaults: defaults, key: key)
        #expect(try store.load() == nil)

        var preference = CertigoParallelTracksPreference()
        #expect(preference.parallelTrackCodes == ["AZ-104", "SAA-C03", "GH-300"])
        #expect(preference.activeTrackCode == "AZ-104")
        #expect(preference.aiFrontierTrackCodes == ["AI-OPENAI", "AI-CLAUDE", "AI-GEMINI", "AI-FOUNDRY"])
        #expect(preference.bilingualTechnicalTermsEN == true)
        #expect(preference.strictTimed90Min == true)
        #expect(preference.settingsParallelTracksSummary == "AZ-104 + 2 ›")
        #expect(preference.settingsLanguageSummary == "FR + Termes EN ›")
        #expect(preference.settingsMockExamSummary == "Chrono 90m ›")

        preference.addParallelTrack("CKA")
        preference.setActiveTrack("SAA-C03")
        preference.addAIFrontierTrack("AI-MISTRAL")
        preference.bilingualTechnicalTermsEN = false
        preference.strictTimed90Min = false

        try store.save(preference)
        let reloaded = try #require(try store.load())
        #expect(reloaded == preference)
        #expect(reloaded.parallelTrackCodes == ["AZ-104", "SAA-C03", "GH-300", "CKA"])
        #expect(reloaded.activeTrackCode == "SAA-C03")
        #expect(reloaded.aiFrontierTrackCodes == ["AI-OPENAI", "AI-CLAUDE", "AI-GEMINI", "AI-FOUNDRY", "AI-MISTRAL"])
        #expect(reloaded.bilingualTechnicalTermsEN == false)
        #expect(reloaded.strictTimed90Min == false)
        #expect(reloaded.settingsParallelTracksSummary == "SAA-C03 + 3 ›")
        #expect(reloaded.settingsLanguageSummary == "FR uniquement ›")
        #expect(reloaded.settingsMockExamSummary == "Mode libre ›")

        let updated = try store.update { current in
            current.removeParallelTrack("SAA-C03")
        }
        #expect(updated.activeTrackCode == "AZ-104")
        #expect(updated.parallelTrackCodes == ["AZ-104", "GH-300", "CKA"])

        store.reset()
        #expect(try store.load() == nil)
    }

    @Test("Coordinator, OnboardingFlowStateMachine, and settings stay coherently synchronized across parallel track additions, removals, and active switches")
    func coordinatorAndOnboardingSynchronizeParallelTracksAndAIFrontier() throws {
        let defaults = UserDefaults.standard
        let key = "certigo.parallel-tracks.sync.\(UUID().uuidString)"
        defer { defaults.removeObject(forKey: key) }

        var onboarding = OnboardingFlowStateMachine()
        #expect(onboarding.selectedParallelRoutes == ["AZ-104", "SAA-C03", "GH-300"])
        #expect(onboarding.selectedAIFrontierTrackCodes == ["AI-OPENAI", "AI-CLAUDE", "AI-GEMINI", "AI-FOUNDRY"])

        onboarding.toggleParallelRoute("CKA")
        onboarding.toggleAIFrontierTrack("AI-MISTRAL")
        onboarding.selectRoute(
            region: .cloud,
            routeCode: "SAA-C03",
            productId: BrandProductID("aws-vpc")
        )

        let builtPref = onboarding.buildParallelTracksPreference()
        #expect(builtPref.activeTrackCode == "SAA-C03")
        #expect(builtPref.parallelTrackCodes == ["AZ-104", "SAA-C03", "GH-300", "CKA"])
        #expect(builtPref.aiFrontierTrackCodes.contains("AI-MISTRAL"))

        var coordinator = PrismAppShellCoordinatorModel()
        coordinator.applyParallelTracksPreference(builtPref, persistTo: defaults, key: key)

        #expect(coordinator.todayModel.activeRouteCode == "SAA-C03")
        #expect(coordinator.routeReadiness.routeCode == "SAA-C03")
        #expect(coordinator.mockExamMachine.routeCode == "SAA-C03")
        #expect(coordinator.mockExamMachine.baseDurationMinutes == 90)
        #expect(coordinator.mockExamMachine.timePolicy == .standardTimed)
        #expect(coordinator.calibrationHistory.passport.routes.map(\.examCode) == ["AZ-104", "SAA-C03", "GH-300", "CKA"])

        // Removing the active track falls back to the first remaining parallel track and updates the whole shell
        coordinator.removeParallelTrack(code: "SAA-C03", persistTo: defaults, key: key)
        #expect(coordinator.parallelTracksPreference.activeTrackCode == "AZ-104")
        #expect(coordinator.todayModel.activeRouteCode == "AZ-104")
        #expect(coordinator.routeReadiness.routeCode == "AZ-104")
        #expect(coordinator.mockExamMachine.routeCode == "AZ-104")
        #expect(coordinator.calibrationHistory.passport.routes.map(\.examCode) == ["AZ-104", "GH-300", "CKA"])

        // Toggling mock exam mode updates MockExamStateMachine and persists
        coordinator.setStrictTimed90Min(false, persistTo: defaults, key: key)
        #expect(coordinator.mockExamMachine.timePolicy == .untimed)
        #expect(coordinator.mockExamMachine.baseDurationMinutes == 40)

        var reloadedCoordinator = PrismAppShellCoordinatorModel()
        reloadedCoordinator.loadParallelTracksPreference(from: defaults, key: key)
        #expect(reloadedCoordinator.parallelTracksPreference == coordinator.parallelTracksPreference)
        #expect(reloadedCoordinator.todayModel.activeRouteCode == "AZ-104")
        #expect(reloadedCoordinator.mockExamMachine.timePolicy == .untimed)
    }
}
