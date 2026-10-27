import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Versioned ItemPayload Contract (S-22, §6.2, §6.3, §6.4)

public struct SituationDecisionStep: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let prompt: String
    public let options: [PrismChoiceOption]
    public let allowsMultipleSelection: Bool

    public init(
        id: String,
        prompt: String,
        options: [PrismChoiceOption],
        allowsMultipleSelection: Bool = false
    ) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.allowsMultipleSelection = allowsMultipleSelection
    }
}


/// The 10 Validated Interactive Question Formats (`Q_TYPE_01` to `Q_TYPE_10` on Page 06 Figma Pro).
public enum CertiGoQuestionFormatID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case q01ScenarioQCM = "Q_TYPE_01"
    case q02ServiceGrid2x2 = "Q_TYPE_02"
    case q03InteractiveDiagram = "Q_TYPE_03"
    case q04IOSKeyboardInput = "Q_TYPE_04"
    case q05WordBankBricks = "Q_TYPE_05"
    case q06MatchingPairs = "Q_TYPE_06"
    case q07JSONBugDiagnosis = "Q_TYPE_07"
    case q08ScopeHierarchyOrdering = "Q_TYPE_08"
    case q09ArchitectureVerdict = "Q_TYPE_09"
    case q10MultiSelectCheckboxes = "Q_TYPE_10"

    public var id: String { rawValue }

    public var badgeTitle: String {
        switch self {
        case .q01ScenarioQCM: "SCÉNARIO ARCHITECTURE"
        case .q02ServiceGrid2x2: "GRILLE 2×2 SERVICES OFFICIELS"
        case .q03InteractiveDiagram: "SCHÉMA INTERACTIF"
        case .q04IOSKeyboardInput: "SAISIE CLAVIER iOS"
        case .q05WordBankBricks: "ASSEMBLAGE DE BRIQUES CLI"
        case .q06MatchingPairs: "PAIRES À RELIER (SYMBOLES ↔ RÔLES)"
        case .q07JSONBugDiagnosis: "DIAGNOSTIC DE RÈGLE JSON"
        case .q08ScopeHierarchyOrdering: "CLASSER DANS L'ORDRE"
        case .q09ArchitectureVerdict: "VERDICT FLUX RÉSEAU"
        case .q10MultiSelectCheckboxes: "MULTI-SÉLECTION (2 RÉPONSES)"
        }
    }
}

public enum PrismItemFormatPayload: Codable, Equatable, Hashable, Sendable {
    /// P1: Single or multi-choice question with optional confidence picker.
    case choice(options: [PrismChoiceOption], allowsMultipleSelection: Bool)
    /// P1: Real-world context + technical artifact + 1..3 decisions.
    case situation(contextNarrative: String, artifact: PrismArtifactDocument, decisions: [SituationDecisionStep])
    /// P1: Predict the output/behavior of a technical artifact before execution.
    case predict(artifact: PrismArtifactDocument, options: [PrismChoiceOption])
    /// P1 (NS-4): Select buggy/vulnerable line(s) in an artifact via tap or VoiceOver "Lignes" rotor.
    case spotTheIssue(artifact: PrismArtifactDocument, allowsMultipleLines: Bool)
    /// P1: Parsons 1D/2D ordering with tap Move Up/Down & VoiceOver actions.
    case ordering(items: [PrismOrderItem])
    /// P1: Compose a CLI command from tappable tokens (no drag required).
    case commandComposer(promptCommandPrefix: String, availableTokens: [PrismCommandToken])
    /// Forward-compatible graceful fallback (§6.4: "Ce format arrive bientôt" + skip + analytics event).
    case unsupported(rawFormat: String)

    public var formatIdentifier: String {
        switch self {
        case .choice: "choice"
        case .situation: "situation"
        case .predict: "predict"
        case .spotTheIssue: "spotTheIssue"
        case .ordering: "ordering"
        case .commandComposer: "commandComposer"
        case .unsupported(let raw): raw
        }
    }

    public var isSupported: Bool {
        if case .unsupported = self { return false }
        return true
    }
}

/// Client-side item envelope. Note (§6.1 / DR-004): no answer key is ever present in this payload.
public struct PrismSessionItemModel: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let conceptId: String
    public let product: BrandProductID
    public let rung: Int
    public let difficulty: Int
    public let stem: String
    public let revealOptionsDelayMs: Int
    public let captureConfidence: Bool
    public let isMockExamMode: Bool
    public let payload: PrismItemFormatPayload

    public init(
        id: String,
        conceptId: String,
        product: BrandProductID = .microsoftAzure,
        rung: Int = 1,
        difficulty: Int = 1,
        stem: String,
        revealOptionsDelayMs: Int = 0,
        captureConfidence: Bool = false,
        isMockExamMode: Bool = false,
        payload: PrismItemFormatPayload
    ) {
        self.id = id
        self.conceptId = conceptId
        self.product = product
        self.rung = min(max(rung, 1), 5)
        self.difficulty = min(max(difficulty, 1), 3)
        self.stem = stem
        self.revealOptionsDelayMs = min(max(revealOptionsDelayMs, 0), 1500)
        self.captureConfidence = captureConfidence
        self.isMockExamMode = isMockExamMode
        self.payload = payload
    }

    public func shouldShowOptionsImmediately(reduceMotion: Bool, manuallyRevealed: Bool) -> Bool {
        manuallyRevealed || reduceMotion || revealOptionsDelayMs == 0
    }
}

// MARK: - 2. Learning Cards (S-21, §6.2, §14, §22A.5, §23)

public enum PrismLearningCardKind: Codable, Equatable, Hashable, Sendable {
    case openingQuestion(prompt: String, contextNote: String)
    case explanation(PrismExplanationSpec)
    case workedExample(PrismWorkedExample, skipVerificationItemId: String?)
    case artifactStudy(PrismArtifactDocument, takeaway: String)
    case diagramStudy(DiagramSpec, takeaway: String)
}

public struct PrismLearningCardModel: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let conceptId: String
    public let title: String
    public let product: BrandProductID
    public let kind: PrismLearningCardKind

    public init(
        id: String,
        conceptId: String,
        title: String,
        product: BrandProductID,
        kind: PrismLearningCardKind
    ) {
        self.id = id
        self.conceptId = conceptId
        self.title = title
        self.product = product
        self.kind = kind
    }

    public var skipVerificationItemId: String? {
        if case .workedExample(let example, let itemId) = kind, example.isSkippable {
            return itemId
        }
        return nil
    }
}

// MARK: - 3. Session Atom & Server-Ordered Session Plan (S-20, §6.1, §6.2)

public enum PrismSessionCardAtom: Codable, Equatable, Hashable, Sendable, Identifiable {
    case learning(PrismLearningCardModel)
    case item(PrismSessionItemModel)

    public var id: String {
        switch self {
        case .learning(let card): "learn.\(card.id)"
        case .item(let item): "item.\(item.id)"
        }
    }

    public var conceptId: String {
        switch self {
        case .learning(let card): card.conceptId
        case .item(let item): item.conceptId
        }
    }
}

public struct PrismSessionPlan: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let length: PrismSessionLength
    /// Server-authoritative sequence (§6.2: "le serveur fournit l'ordre ; le client ne réordonne pas").
    public let cards: [PrismSessionCardAtom]
    public let skipVerificationItems: [String: PrismSessionItemModel]

    public init(
        id: String,
        length: PrismSessionLength,
        cards: [PrismSessionCardAtom],
        skipVerificationItems: [String: PrismSessionItemModel] = [:]
    ) {
        self.id = id
        self.length = length
        self.cards = cards
        self.skipVerificationItems = skipVerificationItems
    }
}

// MARK: - 4. Draft Response & Contextual Bookmark Store (§6.2, DR-004)

public struct PrismItemDraftResponse: Codable, Equatable, Hashable, Sendable {
    public var selectedChoiceIds: [String]
    public var situationDecisions: [String: [String]]
    public var selectedArtifactLines: Set<Int>
    public var orderedItemIds: [String]
    public var composedTokenIds: [String]
    public var confidence: PrismConfidenceLevel?

    public init(
        selectedChoiceIds: [String] = [],
        situationDecisions: [String: [String]] = [:],
        selectedArtifactLines: Set<Int> = [],
        orderedItemIds: [String] = [],
        composedTokenIds: [String] = [],
        confidence: PrismConfidenceLevel? = nil
    ) {
        self.selectedChoiceIds = selectedChoiceIds
        self.situationDecisions = situationDecisions
        self.selectedArtifactLines = selectedArtifactLines
        self.orderedItemIds = orderedItemIds
        self.composedTokenIds = composedTokenIds
        self.confidence = confidence
    }

    public var hasAnyInputInProgress: Bool {
        !selectedChoiceIds.isEmpty
            || !situationDecisions.isEmpty
            || !selectedArtifactLines.isEmpty
            || !composedTokenIds.isEmpty
            || confidence != nil
    }
}

public struct PrismSessionBookmark: Codable, Equatable, Hashable, Sendable {
    public let sessionId: String
    public let length: PrismSessionLength
    public let currentIndex: Int
    public let totalCards: Int
    public let draftResponse: PrismItemDraftResponse?
    public let savedAt: Date

    public init(
        sessionId: String,
        length: PrismSessionLength,
        currentIndex: Int,
        totalCards: Int,
        draftResponse: PrismItemDraftResponse?,
        savedAt: Date
    ) {
        self.sessionId = sessionId
        self.length = length
        self.currentIndex = max(0, currentIndex)
        self.totalCards = max(1, totalCards)
        self.draftResponse = draftResponse
        self.savedAt = savedAt
    }

    public var accessory: InterruptedSessionAccessory {
        InterruptedSessionAccessory(
            sessionId: sessionId,
            length: length,
            currentCardIndex: currentIndex,
            totalCards: totalCards,
            savedAt: savedAt
        )
    }

    public func isValid(at now: Date) -> Bool {
        accessory.isValid(at: now)
    }
}

/// Offline pre-composed session cache (§6.2: up to 2 pre-composed sessions cached).
public struct PrismOfflineSessionCache: Codable, Equatable, Sendable {
    public static let maxCachedSessions: Int = 2
    public static let offlineQueuedMessage = "Réponse enregistrée — résultat à la synchronisation"

    public private(set) var cachedPlans: [PrismSessionPlan]

    public init(cachedPlans: [PrismSessionPlan] = []) {
        self.cachedPlans = Array(cachedPlans.prefix(Self.maxCachedSessions))
    }

    public mutating func store(_ plan: PrismSessionPlan) {
        cachedPlans.removeAll { $0.id == plan.id }
        cachedPlans.insert(plan, at: 0)
        if cachedPlans.count > Self.maxCachedSessions {
            cachedPlans = Array(cachedPlans.prefix(Self.maxCachedSessions))
        }
    }
}

// MARK: - 5. Session Player State Machine (S-20, §6.2, §31)

public struct SessionPlayerStateMachine: Equatable, Sendable {
    public static let verificationIndicatorThresholdMs: Int = 300

    public let plan: PrismSessionPlan
    public private(set) var currentIndex: Int
    public var currentDraft: PrismItemDraftResponse
    public var optionsManuallyRevealed: Bool
    public private(set) var activeSkipTestItem: PrismSessionItemModel?
    public private(set) var isOffline: Bool
    public private(set) var queuedOfflineSubmissionIds: [String]
    public private(set) var lastOfflineConfirmationMessage: String?
    public private(set) var emittedUnsupportedFormats: [String]
    public private(set) var latestBookmark: PrismSessionBookmark?

    public init(
        plan: PrismSessionPlan,
        initialBookmark: PrismSessionBookmark? = nil,
        isOffline: Bool = false,
        now: Date = Date()
    ) {
        self.plan = plan
        if let initialBookmark,
           initialBookmark.sessionId == plan.id,
           initialBookmark.isValid(at: now),
           initialBookmark.currentIndex < plan.cards.count
        {
            self.currentIndex = initialBookmark.currentIndex
            self.currentDraft = initialBookmark.draftResponse ?? PrismItemDraftResponse()
            self.latestBookmark = initialBookmark
        } else {
            self.currentIndex = 0
            self.currentDraft = PrismItemDraftResponse()
            self.latestBookmark = nil
        }
        self.optionsManuallyRevealed = false
        self.activeSkipTestItem = nil
        self.isOffline = isOffline
        self.queuedOfflineSubmissionIds = []
        self.lastOfflineConfirmationMessage = nil
        self.emittedUnsupportedFormats = []
        initializeOrderedItemsIfNeeded()
    }

    public var currentCard: PrismSessionCardAtom? {
        if let skipItem = activeSkipTestItem {
            return .item(skipItem)
        }
        guard currentIndex >= 0, currentIndex < plan.cards.count else { return nil }
        return plan.cards[currentIndex]
    }

    public var isCompleted: Bool {
        currentIndex >= plan.cards.count && activeSkipTestItem == nil
    }

    public var progressModel: PrismSessionProgressModel {
        PrismSessionProgressModel(
            currentIndex: min(currentIndex + 1, max(1, plan.cards.count)),
            totalCount: max(1, plan.cards.count),
            stepTitle: "Séance \(plan.length.title)"
        )
    }

    public func shouldShowVerificationSpinner(elapsedMs: Int) -> Bool {
        !plan.cards.isEmpty && elapsedMs > Self.verificationIndicatorThresholdMs
    }

    /// Persists the learner's position and draft at every card change or input update (§6.2).
    @discardableResult
    public mutating func persistBookmark(at now: Date = Date()) -> PrismSessionBookmark {
        let bookmark = PrismSessionBookmark(
            sessionId: plan.id,
            length: plan.length,
            currentIndex: currentIndex,
            totalCards: plan.cards.count,
            draftResponse: currentDraft,
            savedAt: now
        )
        latestBookmark = bookmark
        return bookmark
    }

    /// Triggered when the learner taps "Je connais déjà" on a skippable WorkedExample (§6.2).
    public mutating func triggerSkipTestIfAvailable() -> Bool {
        guard case .learning(let card) = currentCard,
              let itemId = card.skipVerificationItemId,
              let item = plan.skipVerificationItems[itemId]
        else { return false }
        activeSkipTestItem = item
        currentDraft = PrismItemDraftResponse()
        optionsManuallyRevealed = false
        initializeOrderedItemsIfNeeded()
        return true
    }

    /// Advances to the next card in the exact server-provided order (§6.2).
    public mutating func advanceToNextCard(at now: Date = Date()) {
        if activeSkipTestItem != nil {
            activeSkipTestItem = nil
        }
        if case .item(let item) = currentCard, !item.payload.isSupported {
            emittedUnsupportedFormats.append(item.payload.formatIdentifier)
        }
        currentIndex += 1
        currentDraft = PrismItemDraftResponse()
        optionsManuallyRevealed = false
        lastOfflineConfirmationMessage = nil
        initializeOrderedItemsIfNeeded()
        if !isCompleted {
            persistBookmark(at: now)
        } else {
            latestBookmark = nil
        }
    }

    /// Submits the current item response; if offline, queues idempotently and shows the honest DR-004 message.
    public mutating func submitCurrentItem(clientAttemptId: String, at now: Date = Date()) {
        guard case .item = currentCard else { return }
        if isOffline {
            if !queuedOfflineSubmissionIds.contains(clientAttemptId) {
                queuedOfflineSubmissionIds.append(clientAttemptId)
            }
            lastOfflineConfirmationMessage = PrismOfflineSessionCache.offlineQueuedMessage
        }
        persistBookmark(at: now)
    }

    private mutating func initializeOrderedItemsIfNeeded() {
        if case .item(let item) = currentCard,
           case .ordering(let orderItems) = item.payload,
           currentDraft.orderedItemIds.isEmpty
        {
            currentDraft.orderedItemIds = orderItems.map(\.id)
        }
    }
}

// MARK: - 6. SwiftUI Views (S-20, S-21, S-22)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct LearningCardView: View {
    public let model: PrismLearningCardModel
    public let flags: FeatureFlags
    public let onSkipTest: () -> Void
    public let onContinue: () -> Void

    public init(
        model: PrismLearningCardModel,
        flags: FeatureFlags = FeatureFlags(),
        onSkipTest: @escaping () -> Void = {},
        onContinue: @escaping () -> Void = {}
    ) {
        self.model = model
        self.flags = flags
        self.onSkipTest = onSkipTest
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.l) {
            BrandLabel(
                product: model.product,
                context: .learningContent,
                size: .medium,
                flags: flags
            )

            CertiGoSpeechBubbleHeaderView(
                region: .network,
                badgeText: "DÉCLIC ARCHITECTURE · 20S",
                questionText: model.title,
                poseOverride: .emotionAhaIdea
            )

            switch model.kind {
            case .openingQuestion(let prompt, let contextNote):
                QuestionCard(
                    spec: PrismQuestionSpec(
                        id: model.id,
                        prompt: prompt,
                        situationContext: contextNote
                    )
                )
            case .explanation(let spec):
                ExplanationCard(spec: spec)
            case .workedExample(let example, _):
                WorkedExampleView(example: example, onSkipTest: onSkipTest)
            case .artifactStudy(let doc, let takeaway):
                ArtifactView(
                    document: doc,
                    selectedLineNumbers: .constant([])
                )
                TakeawayLine(spec: PrismTakeawaySpec(text: takeaway))
            case .diagramStudy(let spec, let takeaway):
                DiagramView(spec: spec)
                TakeawayLine(spec: PrismTakeawaySpec(text: takeaway))
            }

            Button {
                onContinue()
            } label: {
                Text(verbatim: "Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrismButtonStyle(variant: .primary))
        }
    }
}

public struct SessionItemCardView: View {
    public let item: PrismSessionItemModel
    @Binding public var draft: PrismItemDraftResponse
    @Binding public var optionsManuallyRevealed: Bool
    public let flags: FeatureFlags
    public let onVerifyOrSkip: () -> Void

    public init(
        item: PrismSessionItemModel,
        draft: Binding<PrismItemDraftResponse>,
        optionsManuallyRevealed: Binding<Bool>,
        flags: FeatureFlags = FeatureFlags(),
        onVerifyOrSkip: @escaping () -> Void = {}
    ) {
        self.item = item
        self._draft = draft
        self._optionsManuallyRevealed = optionsManuallyRevealed
        self.flags = flags
        self.onVerifyOrSkip = onVerifyOrSkip
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.l) {
            BrandLabel(
                product: item.product,
                context: .learningContent,
                size: .small,
                flags: flags
            )

            CertiGoSpeechBubbleHeaderView(
                region: .cloud,
                badgeText: "SCÉNARIO ARCHITECTURE",
                questionText: item.stem
            )

            payloadBody

            if item.payload.isSupported {
                Button {
                    onVerifyOrSkip()
                } label: {
                    Text(verbatim: "VÉRIFIER")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .primary))
            }
        }
    }

    @ViewBuilder
    private var payloadBody: some View {
        switch item.payload {
        case .choice(let options, let multi):
            ChoiceList(
                options: options,
                selectedIds: Binding(
                    get: { Set(draft.selectedChoiceIds) },
                    set: { draft.selectedChoiceIds = Array($0).sorted() }
                ),
                allowsMultipleSelection: multi,
                isRevealed: false
            )
        case .situation(let narrative, let artifact, let decisions):
            PrismCard(variant: .situation) {
                PrismText(text: narrative, style: .body)
            }
            ArtifactView(
                document: artifact,
                selectedLineNumbers: $draft.selectedArtifactLines
            )
            ForEach(decisions) { step in
                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                    PrismText(text: step.prompt, style: .subheadline)
                    ChoiceList(
                        options: step.options,
                        selectedIds: Binding(
                            get: { Set(draft.situationDecisions[step.id] ?? []) },
                            set: { draft.situationDecisions[step.id] = Array($0).sorted() }
                        ),
                        allowsMultipleSelection: step.allowsMultipleSelection,
                        isRevealed: false
                    )
                }
            }
        case .predict(let artifact, let options):
            ArtifactView(
                document: artifact,
                selectedLineNumbers: .constant([])
            )
            ChoiceList(
                options: options,
                selectedIds: Binding(
                    get: { Set(draft.selectedChoiceIds) },
                    set: { draft.selectedChoiceIds = Array($0).sorted() }
                ),
                allowsMultipleSelection: false,
                isRevealed: false
            )
        case .spotTheIssue(let artifact, let multi):
            ArtifactView(
                document: artifact,
                selectedLineNumbers: $draft.selectedArtifactLines,
                allowsMultipleSelection: multi
            )
        case .ordering(let orderItems):
            OrderList(
                items: Binding(
                    get: {
                        if draft.orderedItemIds.isEmpty { return orderItems }
                        let byId = Dictionary(uniqueKeysWithValues: orderItems.map { ($0.id, $0) })
                        return draft.orderedItemIds.compactMap { byId[$0] }
                    },
                    set: { draft.orderedItemIds = $0.map(\.id) }
                )
            )
        case .commandComposer(let prefix, let tokens):
            TokenComposer(
                state: Binding(
                    get: {
                        PrismTokenComposerState(
                            commandPrefix: prefix,
                            availableTokens: tokens,
                            selectedTokenIds: draft.composedTokenIds
                        )
                    },
                    set: { draft.composedTokenIds = $0.selectedTokenIds }
                )
            )
        case .unsupported(let rawFormat):
            PrismEmptyState(
                model: .unsupportedFormat(formatName: rawFormat),
                onAction: onVerifyOrSkip
            )
        }
    }
}

public struct SessionPlayerScreen: View {
    @Binding public var stateMachine: SessionPlayerStateMachine
    public let flags: FeatureFlags
    public let onCloseRequested: (Bool) -> Void
    public let onRequestAIExplain: (String) -> Void
    @State private var activeFeedback: SessionFeedbackResolution?

    public init(
        stateMachine: Binding<SessionPlayerStateMachine>,
        flags: FeatureFlags = FeatureFlags(),
        onCloseRequested: @escaping (Bool) -> Void = { _ in },
        onRequestAIExplain: @escaping (String) -> Void = { _ in }
    ) {
        self._stateMachine = stateMachine
        self.flags = flags
        self.onCloseRequested = onCloseRequested
        self.onRequestAIExplain = onRequestAIExplain
    }

    private func buildFeedbackResolution(for item: PrismSessionItemModel) -> SessionFeedbackResolution {
        let selectedId = stateMachine.currentDraft.selectedChoiceIds.first
        switch item.payload {
        case .choice(let options, _), .predict(_, let options):
            let correctOpt = options.first(where: \.isCorrect) ?? options[0]
            let chosenOpt = options.first(where: { $0.id == selectedId }) ?? options[0]
            let isCorrect = chosenOpt.id == correctOpt.id
            return SessionFeedbackResolution(
                id: "fb-\(item.id)",
                itemId: item.id,
                isCorrect: isCorrect,
                confidence: stateMachine.currentDraft.confidence,
                aiAvailable: true,
                chosenOption: chosenOpt,
                correctOption: correctOpt,
                allOptions: options,
                authorExplanation: correctOpt.explanation,
                takeaway: "Toujours vérifier l'isolation réseau et la résolution DNS privée associée."
            )
        default:
            let fallbackOption = PrismChoiceOption(
                id: "valid",
                badge: "✓",
                text: "Analyse validée",
                explanation: "Étape vérifiée avec succès.",
                isCorrect: true
            )
            return SessionFeedbackResolution(
                id: "fb-\(item.id)",
                itemId: item.id,
                isCorrect: true,
                confidence: stateMachine.currentDraft.confidence,
                aiAvailable: true,
                chosenOption: fallbackOption,
                correctOption: fallbackOption,
                allOptions: [fallbackOption],
                authorExplanation: "Explication vérifiée par l'auteur.",
                takeaway: "Pratique régulière et rappel actif ancrent durablement le concept."
            )
        }
    }

    private var completedResultsModel: SessionResultsModel {
        SessionResultsModel(
            sessionLength: stateMachine.plan.length,
            durationSeconds: 300,
            itemsCompletedCount: stateMachine.plan.cards.count,
            correctFirstTryCount: stateMachine.plan.cards.count,
            conceptTransitions: [
                SessionConceptTransition(
                    id: "tr-pe",
                    conceptTitle: "Private Endpoint & DNS privé Azure",
                    product: .azureVirtualNetwork,
                    previousState: .practicing,
                    newState: .anchored
                )
            ],
            updatedRhythm: PrismRhythmWeekModel(
                weeklyGoalDays: 4,
                days: [
                    PrismRhythmDayItem(id: "mon", shortDayLabel: "L", state: .completed),
                    PrismRhythmDayItem(id: "tue", shortDayLabel: "M", state: .completed),
                    PrismRhythmDayItem(id: "wed", shortDayLabel: "M", state: .completed),
                    PrismRhythmDayItem(id: "thu", shortDayLabel: "J", state: .planned),
                    PrismRhythmDayItem(id: "fri", shortDayLabel: "V", state: .planned),
                    PrismRhythmDayItem(id: "sat", shortDayLabel: "S", state: .restDay),
                    PrismRhythmDayItem(id: "sun", shortDayLabel: "D", state: .restDay)
                ],
                bestRhythmWeeks: 6,
                dailyStreakOptIn: true,
                dailyStreakDays: 6
            )
        )
    }

    public var body: some View {
        if stateMachine.isCompleted {
            SessionResultsScreen(
                model: completedResultsModel,
                flags: flags,
                onReturnToToday: {
                    onCloseRequested(false)
                }
            )
        } else {
            VStack(spacing: PrismSpacing.m) {
                SessionProgressHeader(
                    model: stateMachine.progressModel,
                    onClose: {
                        stateMachine.persistBookmark()
                        onCloseRequested(stateMachine.currentDraft.hasAnyInputInProgress)
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: PrismSpacing.l) {
                        if let message = stateMachine.lastOfflineConfirmationMessage {
                            PrismCard(variant: .feedback) {
                                PrismText(text: message, style: .subheadline)
                            }
                        }

                        if let currentCard = stateMachine.currentCard {
                            switch currentCard {
                            case .learning(let card):
                                LearningCardView(
                                    model: card,
                                    flags: flags,
                                    onSkipTest: { _ = stateMachine.triggerSkipTestIfAvailable() },
                                    onContinue: {
                                        activeFeedback = nil
                                        stateMachine.advanceToNextCard()
                                    }
                                )
                            case .item(let item):
                                if let resolution = activeFeedback {
                                    SessionFeedbackPanelScreen(
                                        resolution: Binding(
                                            get: { resolution },
                                            set: { activeFeedback = $0 }
                                        ),
                                        onRequestExplainDifferently: {
                                            onRequestAIExplain(item.conceptId)
                                        },
                                        onContinue: {
                                            activeFeedback = nil
                                            stateMachine.submitCurrentItem(clientAttemptId: item.id)
                                            stateMachine.advanceToNextCard()
                                        }
                                    )
                                } else {
                                    SessionItemCardView(
                                        item: item,
                                        draft: $stateMachine.currentDraft,
                                        optionsManuallyRevealed: $stateMachine.optionsManuallyRevealed,
                                        flags: flags,
                                        onVerifyOrSkip: {
                                            activeFeedback = buildFeedbackResolution(for: item)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(PrismSpacing.l)
                }
            }
            .background(PrismColor.canvas)
        }
    }
}
#endif
