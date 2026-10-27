import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite struct Phase4SessionAndFormatsTests {
    @Test func sessionPlayerPreservesServerOrderSkipTestAndContextualBookmarks() {
        let workedExample = PrismWorkedExample(
            id: "we-1",
            title: "Configurer un Private Endpoint Azure Storage",
            problemContext: "Isoler un compte de stockage derrière un VNet.",
            steps: [
                PrismWorkedStep(id: "s1", stepNumber: 1, subgoalTitle: "Désactiver l'accès public", detail: "Passer publicNetworkAccess à Disabled."),
                PrismWorkedStep(id: "s2", stepNumber: 2, subgoalTitle: "Lier la zone DNS privée", detail: "Créer le lien VNet privatelink.blob.core.windows.net."),
            ],
            conclusion: "Le trafic passe désormais exclusivement par le réseau privé.",
            isSkippable: true
        )
        let learnCard = PrismLearningCardModel(
            id: "lc-1",
            conceptId: "az.private-endpoint",
            title: "Private Endpoint",
            product: .azureStorage,
            kind: .workedExample(workedExample, skipVerificationItemId: "verify-skip-1")
        )
        let skipCheckItem = PrismSessionItemModel(
            id: "verify-skip-1",
            conceptId: "az.private-endpoint",
            product: .azureStorage,
            rung: 3,
            difficulty: 2,
            stem: "Quelle zone DNS privée résout un Blob Storage Private Endpoint ?",
            captureConfidence: true,
            payload: .choice(
                options: [
                    PrismChoiceOption(id: "a", badge: "A", text: "privatelink.blob.core.windows.net", explanation: "Zone DNS privée officielle de Blob Storage."),
                    PrismChoiceOption(id: "b", badge: "B", text: "azurewebsites.net", explanation: "Domaine public d'Azure App Service."),
                ],
                allowsMultipleSelection: false
            )
        )
        let spotDoc = PrismArtifactDocument(
            title: "nsg.bicep",
            language: "bicep",
            lines: [
                PrismArtifactLine(lineNumber: 1, text: "resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {"),
                PrismArtifactLine(lineNumber: 2, text: "  sourceAddressPrefix: '*' // Port 22 ouvert à Internet"),
                PrismArtifactLine(lineNumber: 3, text: "}"),
            ]
        )
        let spotItem = PrismSessionItemModel(
            id: "item-spot",
            conceptId: "az.nsg",
            product: .azureVirtualNetwork,
            rung: 2,
            difficulty: 2,
            stem: "Sélectionne la ligne qui expose SSH à Internet :",
            revealOptionsDelayMs: 900,
            payload: .spotTheIssue(artifact: spotDoc, allowsMultipleLines: false)
        )
        let unknownItem = PrismSessionItemModel(
            id: "item-future",
            conceptId: "az.future",
            product: .microsoftAzure,
            stem: "Simulation quantique",
            payload: .unsupported(rawFormat: "quantumTopologyV9")
        )

        let plan = PrismSessionPlan(
            id: "plan-p4",
            length: .standard,
            cards: [.learning(learnCard), .item(spotItem), .item(unknownItem)],
            skipVerificationItems: ["verify-skip-1": skipCheckItem]
        )

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var machine = SessionPlayerStateMachine(plan: plan, now: now)
        #expect(machine.currentCard?.id == "learn.lc-1")

        // Trigger "Je connais déjà" skip test (§6.2)
        let triggered = machine.triggerSkipTestIfAvailable()
        #expect(triggered)
        #expect(machine.currentCard?.id == "item.verify-skip-1")

        // Advance moves to card index 1 (spotItem) in exact server order
        machine.advanceToNextCard(at: now.addingTimeInterval(30))
        #expect(machine.currentCard?.id == "item.item-spot")
        #expect(machine.latestBookmark?.currentIndex == 1)

        // Delayed options respect Reduce Motion (§6.2)
        #expect(!spotItem.shouldShowOptionsImmediately(reduceMotion: false, manuallyRevealed: false))
        #expect(spotItem.shouldShowOptionsImmediately(reduceMotion: true, manuallyRevealed: false))
        #expect(spotItem.shouldShowOptionsImmediately(reduceMotion: false, manuallyRevealed: true))

        // Select line 2 in spotTheIssue and persist bookmark
        machine.currentDraft.selectedArtifactLines = [2]
        let savedBookmark = machine.persistBookmark(at: now.addingTimeInterval(60))

        // Resume from bookmark within 24h restores exact card and draft response
        let resumed = SessionPlayerStateMachine(
            plan: plan,
            initialBookmark: savedBookmark,
            now: now.addingTimeInterval(3600)
        )
        #expect(resumed.currentIndex == 1)
        #expect(resumed.currentDraft.selectedArtifactLines == [2])

        // Advance to unsupported item, then advance records emittedUnsupportedFormats
        machine.advanceToNextCard(at: now.addingTimeInterval(90))
        #expect(machine.currentCard?.id == "item.item-future")
        machine.advanceToNextCard(at: now.addingTimeInterval(100))
        #expect(machine.isCompleted)
        #expect(machine.emittedUnsupportedFormats == ["quantumTopologyV9"])
    }

    @Test func offlineCacheStoresTwoSessionsAndQueuesSubmissionsIdempotently() {
        let p1 = PrismSessionPlan(id: "s1", length: .express, cards: [])
        let p2 = PrismSessionPlan(id: "s2", length: .standard, cards: [])
        let p3 = PrismSessionPlan(id: "s3", length: .deepDive, cards: [])

        var cache = PrismOfflineSessionCache()
        cache.store(p1)
        cache.store(p2)
        cache.store(p3)
        #expect(cache.cachedPlans.count == PrismOfflineSessionCache.maxCachedSessions)
        #expect(cache.cachedPlans.map(\.id) == ["s3", "s2"])

        let cmdItem = PrismSessionItemModel(
            id: "cmd-1",
            conceptId: "az.cli",
            product: .microsoftAzure,
            stem: "Compose la commande pour lister les groupes de ressources :",
            payload: .commandComposer(
                promptCommandPrefix: "az",
                availableTokens: [
                    PrismCommandToken(id: "t1", text: "group"),
                    PrismCommandToken(id: "t2", text: "list"),
                ]
            )
        )
        let offlinePlan = PrismSessionPlan(id: "offline-1", length: .express, cards: [.item(cmdItem)])
        var machine = SessionPlayerStateMachine(plan: offlinePlan, isOffline: true)
        machine.currentDraft.composedTokenIds = ["t1", "t2"]
        machine.submitCurrentItem(clientAttemptId: "attempt-001")
        machine.submitCurrentItem(clientAttemptId: "attempt-001")
        #expect(machine.queuedOfflineSubmissionIds == ["attempt-001"])
        #expect(machine.lastOfflineConfirmationMessage == PrismOfflineSessionCache.offlineQueuedMessage)
    }

    @Test func validatedMascotLibraryQuestionFormatsAnd900AssetCatalogResolveDeterministically() {
        #expect(CertiGoMascotPose.allCases.count == 24)
        #expect(CertiGoQuestionFormatID.allCases.count == 10)
        #expect(CertiGoMascotPose.specialist(for: .cloud) == .specialistCloudAzure)
        #expect(CertiGoMascotPose.specialist(for: .security) == .specialistSecurityEntra)
        #expect(CertiGoMascotPose.specialist(for: .network) == .specialistNetworkVNet)
        #expect(CertiGoMascotPose.specialist(for: .ai) == .specialistAICoach)
        #expect(CertiGoOfficialAssetCatalog.certificationAssetName(forRouteCode: "AZ-104") == "Certifications/ms-official-associate-badge")
        #expect(CertiGoOfficialAssetCatalog.certificationAssetName(forRouteCode: "SAA-C03") == "Certifications/tech-aws-solutions-architect")
        #expect(CertiGoOfficialAssetCatalog.brandLogoAssetName(forVendorId: "aws") == "BrandLogos/brand-aws-official")
        #expect(CertiGoOfficialAssetCatalog.azureServiceAssetName("Virtual-Machines") == "AzureServices/Virtual-Machines")
        #expect(CertiGoOfficialAssetCatalog.awsServiceAssetName("Amazon-EC2") == "AWSServices/Amazon-EC2")
        #expect(CertiGoOfficialAssetCatalog.gcpServiceAssetName("bigquery") == "GCPServices/gcp-bigquery")
    }

    @Test func sessionItemModelResolvesAllTenFigmaQuestionFormatsSpecialistMascotAndScreen05BackgroundDimming() {
        let az104Exercises = CertiGoMultiTrackAndAIContentCatalog.exercises(forTrackCode: "AZ-104")
        #expect(az104Exercises.count == 10)

        for exercise in az104Exercises {
            #expect(exercise.sessionItem.resolvedFigmaQuestionFormat == exercise.format)
            #expect(exercise.sessionItem.resolvedFigmaQuestionFormat.badgeTitle == exercise.badgeTitle)
        }

        let explicitOverrideItem = PrismSessionItemModel(
            id: "custom-item",
            conceptId: "az.custom",
            product: .azureVirtualNetwork,
            stem: "Question personnalisée",
            payload: .choice(
                options: [
                    PrismChoiceOption(id: "a", badge: "A", text: "Option A", explanation: "Explication A"),
                ],
                allowsMultipleSelection: false
            ),
            questionFormatOverride: .q02ServiceGrid2x2
        )
        #expect(explicitOverrideItem.resolvedFigmaQuestionFormat == .q02ServiceGrid2x2)
        #expect(explicitOverrideItem.resolvedFigmaQuestionFormat.badgeTitle == "GRILLE 2×2 SERVICES OFFICIELS")

        // Verify 3/4 right specialist mascot pose resolution across product domains
        let cloudItem = PrismSessionItemModel(
            id: "m-cloud",
            conceptId: "az.vm",
            product: .microsoftAzure,
            stem: "Cloud",
            payload: .choice(options: [], allowsMultipleSelection: false)
        )
        let securityItem = PrismSessionItemModel(
            id: "m-sec",
            conceptId: "az.entra",
            product: .microsoftEntraID,
            stem: "Security",
            payload: .choice(options: [], allowsMultipleSelection: false)
        )
        let networkItem = PrismSessionItemModel(
            id: "m-net",
            conceptId: "az.vnet",
            product: .azureVirtualNetwork,
            stem: "Network",
            payload: .choice(options: [], allowsMultipleSelection: false)
        )
        let devopsItem = PrismSessionItemModel(
            id: "m-dev",
            conceptId: "k8s.pod",
            product: .kubernetes,
            stem: "Containers",
            payload: .choice(options: [], allowsMultipleSelection: false)
        )
        let dataItem = PrismSessionItemModel(
            id: "m-data",
            conceptId: "az.sql",
            product: .azureSQLDatabase,
            stem: "Data",
            payload: .choice(options: [], allowsMultipleSelection: false)
        )
        let aiItem = PrismSessionItemModel(
            id: "m-ai",
            conceptId: "az.foundry",
            product: .microsoftFoundry,
            stem: "AI",
            payload: .choice(options: [], allowsMultipleSelection: false)
        )

        #expect(cloudItem.resolvedSpecialistMascotPose == .specialistCloudAzure)
        #expect(securityItem.resolvedSpecialistMascotPose == .specialistSecurityEntra)
        #expect(networkItem.resolvedSpecialistMascotPose == .specialistNetworkVNet)
        #expect(devopsItem.resolvedSpecialistMascotPose == .specialistCLIContainers)
        #expect(dataItem.resolvedSpecialistMascotPose == .specialistDataSQL)
        #expect(aiItem.resolvedSpecialistMascotPose == .specialistAICoach)

        // Verify Screen 05 background question dimming at 62% opacity when explanation sheet is open
        let plan = PrismSessionPlan(id: "plan-dim", length: .express, cards: [.item(networkItem)])
        let machine = SessionPlayerStateMachine(plan: plan)
        #expect(machine.dimsBackgroundQuestionWhenAIExplanationOpen)
        #expect(machine.backgroundDimOpacityWhenSheetOpen == 0.62)
        #expect(SessionPlayerStateMachine.validatedBackgroundDimOpacityWhenSheetOpen == 0.62)
    }
}
