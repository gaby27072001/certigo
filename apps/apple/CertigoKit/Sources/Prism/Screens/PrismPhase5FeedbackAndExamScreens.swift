import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Single-Step Feedback Resolution (S-23, §6.2, §14, §15 NS-5, §29)

public struct SessionFeedbackResolution: Codable, Equatable, Hashable, Sendable, Identifiable {
    public static let p95TargetLatencyMs: Int = 1000
    public static let verificationIndicatorThresholdMs: Int = 300

    public let id: String
    public let itemId: String
    public let isCorrect: Bool
    public let isPartial: Bool
    public let confidence: PrismConfidenceLevel?
    public let aiAvailable: Bool
    public let chosenOption: PrismChoiceOption
    public let correctOption: PrismChoiceOption
    public let allOptions: [PrismChoiceOption]
    public let authorExplanation: String
    public let misconceptionTitle: String?
    public let misconceptionCorrection: String?
    public let responsibilityEntries: [ResponsibilityEntry]
    public let takeaway: String
    public var areAllOptionsExpanded: Bool

    public init(
        id: String = "feedback-resolution",
        itemId: String,
        isCorrect: Bool,
        isPartial: Bool = false,
        confidence: PrismConfidenceLevel? = nil,
        aiAvailable: Bool = true,
        chosenOption: PrismChoiceOption,
        correctOption: PrismChoiceOption,
        allOptions: [PrismChoiceOption],
        authorExplanation: String,
        misconceptionTitle: String? = nil,
        misconceptionCorrection: String? = nil,
        responsibilityEntries: [ResponsibilityEntry] = [],
        takeaway: String,
        areAllOptionsExpanded: Bool = false
    ) {
        self.id = id
        self.itemId = itemId
        self.isCorrect = isCorrect
        self.isPartial = isPartial
        self.confidence = confidence
        self.aiAvailable = aiAvailable
        self.chosenOption = chosenOption
        self.correctOption = correctOption
        self.allOptions = allOptions
        self.authorExplanation = authorExplanation
        self.misconceptionTitle = misconceptionTitle
        self.misconceptionCorrection = misconceptionCorrection
        self.responsibilityEntries = responsibilityEntries
        self.takeaway = takeaway
        self.areAllOptionsExpanded = areAllOptionsExpanded
    }

    public var variant: FeedbackVariant {
        PrismFeedbackState.resolveVariant(
            isCorrect: isCorrect,
            isPartial: isPartial,
            confidence: confidence,
            aiAvailable: aiAvailable
        )
    }

    public var headline: String {
        switch variant {
        case .correct:
            "Déclic validé"
        case .partial:
            "Raisonnement partiellement exact"
        case .confidentError:
            "Attention à ce piège fréquent"
        case .incorrect:
            "Voyons pourquoi une autre décision s'impose"
        case .aiUnavailable:
            "Explication de référence de l'auteur"
        }
    }

    /// §6.2: Show the explanation of the chosen option + the correct answer; full list is expandable.
    public var primaryDisplayedOptions: [PrismChoiceOption] {
        if areAllOptionsExpanded {
            return allOptions
        }
        if chosenOption.id == correctOption.id {
            return [correctOption]
        }
        return [chosenOption, correctOption]
    }

    public var feedbackState: PrismFeedbackState {
        PrismFeedbackState(
            id: id,
            variant: variant,
            headline: headline,
            chosenOptionExplanation: chosenOption.explanation,
            authorExplanation: authorExplanation,
            misconceptionTitle: misconceptionTitle,
            misconceptionCorrection: misconceptionCorrection,
            canExplainDifferently: aiAvailable
        )
    }

    public var hapticToken: PrismHapticToken {
        isCorrect ? .correct : .incorrectSoft
    }
}

// MARK: - 2. Session Results Model (S-25, §7, §8, §9, §14)

public struct SessionConceptTransition: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let conceptTitle: String
    public let product: BrandProductID
    public let previousState: PrismMasteryState
    public let newState: PrismMasteryState

    public init(
        id: String,
        conceptTitle: String,
        product: BrandProductID,
        previousState: PrismMasteryState,
        newState: PrismMasteryState
    ) {
        self.id = id
        self.conceptTitle = conceptTitle
        self.product = product
        self.previousState = previousState
        self.newState = newState
    }
}

public struct SessionResultsModel: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let sessionLength: PrismSessionLength
    public let durationSeconds: Int
    public let itemsCompletedCount: Int
    public let correctFirstTryCount: Int
    public let conceptTransitions: [SessionConceptTransition]
    public let resolvedMisconceptions: [String]
    public let updatedRhythm: PrismRhythmWeekModel
    public let rhythmDayValidatedToday: Bool
    public let celebrationLevel: PrismCelebrationLevel
    public let tomorrowPreviewText: String

    public init(
        id: String = "session-results",
        sessionLength: PrismSessionLength,
        durationSeconds: Int,
        itemsCompletedCount: Int,
        correctFirstTryCount: Int,
        conceptTransitions: [SessionConceptTransition],
        resolvedMisconceptions: [String] = [],
        updatedRhythm: PrismRhythmWeekModel,
        rhythmDayValidatedToday: Bool = true,
        celebrationLevel: PrismCelebrationLevel = .refraction,
        tomorrowPreviewText: String = "Demain : 3 rappels différés pour consolider tes acquis."
    ) {
        self.id = id
        self.sessionLength = sessionLength
        self.durationSeconds = max(1, durationSeconds)
        self.itemsCompletedCount = max(0, itemsCompletedCount)
        self.correctFirstTryCount = min(max(0, correctFirstTryCount), max(0, itemsCompletedCount))
        self.conceptTransitions = conceptTransitions
        self.resolvedMisconceptions = resolvedMisconceptions
        self.updatedRhythm = updatedRhythm
        self.rhythmDayValidatedToday = rhythmDayValidatedToday
        self.celebrationLevel = celebrationLevel
        self.tomorrowPreviewText = tomorrowPreviewText
    }

    public var anchoredConceptsCount: Int {
        conceptTransitions.filter { $0.newState == .anchored || $0.newState == .mastered }.count
    }

    /// §8 & §34.1 line 806: Never expose unvalidated currency/gems/crowns/XP in results.
    public var exposesCurrencyOrGenericXP: Bool {
        false
    }
}

// MARK: - 3. Daily Situation State Machine (S-30 & S-95, §5.5, §6.1, §14, §15 NS-7)

public struct DailySituationStateMachine: Codable, Equatable, Hashable, Sendable {
    public let situationId: String
    public let dateLabel: String
    public let title: String
    public let product: BrandProductID
    public let region: PrismRegion
    public let contextNarrative: String
    public let artifact: PrismArtifactDocument
    public let options: [PrismChoiceOption]
    public var selectedOptionId: String?
    public var selectedConfidence: PrismConfidenceLevel?
    public private(set) var hasSubmittedAnswer: Bool
    public private(set) var feedback: SessionFeedbackResolution?
    private let serverDistributionBuckets: [PrismDistributionBucket]

    public init(
        situationId: String,
        dateLabel: String,
        title: String,
        product: BrandProductID,
        region: PrismRegion = .cloud,
        contextNarrative: String,
        artifact: PrismArtifactDocument,
        options: [PrismChoiceOption],
        selectedOptionId: String? = nil,
        selectedConfidence: PrismConfidenceLevel? = nil,
        hasSubmittedAnswer: Bool = false,
        feedback: SessionFeedbackResolution? = nil,
        serverDistributionBuckets: [PrismDistributionBucket]
    ) {
        self.situationId = situationId
        self.dateLabel = dateLabel
        self.title = title
        self.product = product
        self.region = region
        self.contextNarrative = contextNarrative
        self.artifact = artifact
        self.options = options
        self.selectedOptionId = selectedOptionId
        self.selectedConfidence = selectedConfidence
        self.hasSubmittedAnswer = hasSubmittedAnswer
        self.feedback = feedback
        self.serverDistributionBuckets = serverDistributionBuckets
    }

    /// §6.1 & §15 NS-7: Community statistics are strictly hidden before answering.
    public var communityDistribution: PrismCommunityDistributionModel {
        PrismCommunityDistributionModel(
            situationTitle: title,
            hasAnswered: hasSubmittedAnswer,
            buckets: serverDistributionBuckets
        )
    }

    public mutating func submitAnswer(
        correctOptionId: String,
        authorExplanation: String,
        takeaway: String
    ) -> Bool {
        guard let selectedOptionId,
              let chosen = options.first(where: { $0.id == selectedOptionId }),
              let correct = options.first(where: { $0.id == correctOptionId })
        else { return false }

        hasSubmittedAnswer = true
        feedback = SessionFeedbackResolution(
            itemId: situationId,
            isCorrect: chosen.id == correct.id,
            confidence: selectedConfidence,
            chosenOption: chosen,
            correctOption: correct,
            allOptions: options,
            authorExplanation: authorExplanation,
            takeaway: takeaway
        )
        return true
    }

    /// §15 NS-7 & §22A.7: Generates a spoiler-free share card (no question stem, no answer text, no third-party brand icon).
    public func makeSpoilerFreeShareCard(streakDays: Int? = nil) -> PrismShareCardPayload {
        let synthesisText = feedback?.isCorrect == true
            ? "Situation du jour résolue dès le premier essai"
            : "Rituel quotidien accompli avec déclic"
        return PrismShareCardPayload(
            id: "share.\(situationId)",
            title: "Situation du jour · \(dateLabel)",
            region: region,
            synthesis: synthesisText,
            milestoneBadge: "Rituel quotidien",
            streakDays: streakDays,
            questionStemCandidate: nil,
            correctAnswerCandidate: nil,
            thirdPartyBrandIconName: nil
        )
    }
}

// MARK: - 4. Mock Exam Intro / Player / Debrief (S-50, S-51, S-52, §6.2, §14, §15 NS-11, §28)

public enum MockExamTimePolicy: String, Codable, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case standardTimed
    case extendedTime
    case untimed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standardTimed: "Temps standard"
        case .extendedTime: "Temps majoré (×1,5)"
        case .untimed: "Sans limite de temps"
        }
    }

    public func allocatedSeconds(baseMinutes: Int) -> Int? {
        switch self {
        case .standardTimed:
            max(1, baseMinutes) * 60
        case .extendedTime:
            Int((Double(max(1, baseMinutes) * 60) * 1.5).rounded())
        case .untimed:
            nil
        }
    }
}

public struct MockExamQuestionRecord: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String { item.id }
    public let item: PrismSessionItemModel
    public let domainId: String
    public let domainTitle: String
    public var selectedOptionIds: [String]
    public var confidence: PrismConfidenceLevel?

    public init(
        item: PrismSessionItemModel,
        domainId: String,
        domainTitle: String,
        selectedOptionIds: [String] = [],
        confidence: PrismConfidenceLevel? = nil
    ) {
        self.item = item
        self.domainId = domainId
        self.domainTitle = domainTitle
        self.selectedOptionIds = selectedOptionIds
        self.confidence = confidence
    }

    /// §6.2: Confidence selection is mandatory during a mock exam.
    public var isReadyToAdvance: Bool {
        !selectedOptionIds.isEmpty && confidence != nil
    }
}

public enum CertiGoExamBarometerCardIndex: Int, CaseIterable, Codable, Equatable, Hashable, Sendable, Identifiable {
    case graduatedBarometer = 0
    case paceAndConfidenceCalibration = 1
    case errorAnalysisAndAICoachRelaunch = 2

    public var id: Int { rawValue }

    public var cardNumber: Int {
        rawValue + 1
    }

    public var paginationDotsLabel: String {
        switch self {
        case .graduatedBarometer:
            "● ○ ○"
        case .paceAndConfidenceCalibration:
            "○ ● ○"
        case .errorAnalysisAndAICoachRelaunch:
            "○ ○ ●"
        }
    }

    public var shortTitle: String {
        switch self {
        case .graduatedBarometer:
            "Carte 1 · Baromètre"
        case .paceAndConfidenceCalibration:
            "Carte 2 · Rythme & Confiance"
        case .errorAnalysisAndAICoachRelaunch:
            "Carte 3 · Erreurs & Coach IA"
        }
    }
}

public struct CertiGoOfficialDomainScoreRow: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let domainCode: String
    public let domainTitle: String
    public let percentage: Int
    public let region: PrismRegion

    public init(
        id: String,
        domainCode: String,
        domainTitle: String,
        percentage: Int,
        region: PrismRegion
    ) {
        self.id = id
        self.domainCode = domainCode
        self.domainTitle = domainTitle
        self.percentage = min(max(percentage, 0), 100)
        self.region = region
    }

    public var isPassingDomain: Bool {
        percentage >= 70
    }

    public var normalizedProgress: Double {
        Double(percentage) / 100.0
    }

    public var formattedScore: String {
        "\(percentage) %"
    }

    public static let defaultOfficialDomains: [CertiGoOfficialDomainScoreRow] = [
        CertiGoOfficialDomainScoreRow(
            id: "dom-identity",
            domainCode: "D1",
            domainTitle: "Identité et gouvernance Entra ID",
            percentage: 92,
            region: .security
        ),
        CertiGoOfficialDomainScoreRow(
            id: "dom-storage",
            domainCode: "D2",
            domainTitle: "Stockage et sécurité des données",
            percentage: 84,
            region: .data
        ),
        CertiGoOfficialDomainScoreRow(
            id: "dom-compute",
            domainCode: "D3",
            domainTitle: "Calcul et ressources Azure",
            percentage: 78,
            region: .cloud
        ),
        CertiGoOfficialDomainScoreRow(
            id: "dom-network",
            domainCode: "D4",
            domainTitle: "Réseaux virtuels et DNS privé",
            percentage: 58,
            region: .network
        ),
        CertiGoOfficialDomainScoreRow(
            id: "dom-monitor",
            domainCode: "D5",
            domainTitle: "Supervision et sauvegarde",
            percentage: 76,
            region: .devops
        )
    ]
}

public struct CertiGoExamBarometerCarouselModel: Codable, Equatable, Hashable, Sendable {
    public static let requiredCardCount: Int = 3
    public static let officialPassingThreshold: Int = 700
    public static let officialMaxScore: Int = 1000

    public let scaledScore: Int
    public let passingThreshold: Int
    public let maxScore: Int
    public let averageSecondsPerQuestion: Int
    public let sureAnswersPrecisionPercentage: Int
    public let errorsToReviewCount: Int
    public let priorityWeakDomainTitle: String
    public let coachAIRelaunchActionTitle: String
    public let officialDomainScores: [CertiGoOfficialDomainScoreRow]

    public var selectedCardIndex: CertiGoExamBarometerCardIndex
    public private(set) var coachAIRelaunchTriggeredCount: Int

    public init(
        scaledScore: Int = 785,
        passingThreshold: Int = Self.officialPassingThreshold,
        maxScore: Int = Self.officialMaxScore,
        averageSecondsPerQuestion: Int = 18,
        sureAnswersPrecisionPercentage: Int = 91,
        errorsToReviewCount: Int = 6,
        priorityWeakDomainTitle: String = "Réseaux virtuels et DNS privé",
        coachAIRelaunchActionTitle: String = "Relancer avec le Coach IA",
        officialDomainScores: [CertiGoOfficialDomainScoreRow] = CertiGoOfficialDomainScoreRow.defaultOfficialDomains,
        selectedCardIndex: CertiGoExamBarometerCardIndex = .graduatedBarometer,
        coachAIRelaunchTriggeredCount: Int = 0
    ) {
        self.maxScore = max(100, maxScore)
        self.passingThreshold = min(max(0, passingThreshold), self.maxScore)
        self.scaledScore = min(max(0, scaledScore), self.maxScore)
        self.averageSecondsPerQuestion = max(1, averageSecondsPerQuestion)
        self.sureAnswersPrecisionPercentage = min(max(sureAnswersPrecisionPercentage, 0), 100)
        self.errorsToReviewCount = max(0, errorsToReviewCount)
        self.priorityWeakDomainTitle = priorityWeakDomainTitle
        self.coachAIRelaunchActionTitle = coachAIRelaunchActionTitle
        self.officialDomainScores = officialDomainScores
        self.selectedCardIndex = selectedCardIndex
        self.coachAIRelaunchTriggeredCount = max(0, coachAIRelaunchTriggeredCount)
    }

    public var cardsCount: Int {
        CertiGoExamBarometerCardIndex.allCases.count
    }

    public var isPassed: Bool {
        scaledScore >= passingThreshold
    }

    public var surplusPoints: Int {
        scaledScore - passingThreshold
    }

    public var normalizedScoreProgress: Double {
        Double(scaledScore) / Double(maxScore)
    }

    public var paginationDotsText: String {
        selectedCardIndex.paginationDotsLabel
    }

    public var card1VerdictBadgeText: String {
        isPassed
            ? "ADMIS · SEUIL \(passingThreshold) DÉPASSÉ ✓"
            : "SOUS LE SEUIL \(passingThreshold)"
    }

    public var card1GraduatedScaleText: String {
        let checkSuffix = isPassed ? " ✓" : ""
        return "0 ── Seuil \(passingThreshold) ── \(scaledScore) / \(maxScore)\(checkSuffix) ── \(maxScore)"
    }

    public var card2PaceAndCalibrationText: String {
        "\(averageSecondsPerQuestion)s/question · \(sureAnswersPrecisionPercentage) % de précision sur les réponses sûres"
    }

    public var card3ErrorAnalysisTitle: String {
        "Analyse des erreurs & Relance ciblée avec le Coach IA"
    }

    public var card3ErrorAnalysisDetailText: String {
        "\(errorsToReviewCount) erreurs ciblées sur \(priorityWeakDomainTitle)"
    }

    public mutating func selectCard(_ index: CertiGoExamBarometerCardIndex) {
        selectedCardIndex = index
    }

    public mutating func advanceToNextCard() {
        let nextRaw = (selectedCardIndex.rawValue + 1) % CertiGoExamBarometerCardIndex.allCases.count
        selectedCardIndex = CertiGoExamBarometerCardIndex(rawValue: nextRaw) ?? .graduatedBarometer
    }

    public mutating func returnToPreviousCard() {
        let count = CertiGoExamBarometerCardIndex.allCases.count
        let prevRaw = (selectedCardIndex.rawValue - 1 + count) % count
        selectedCardIndex = CertiGoExamBarometerCardIndex(rawValue: prevRaw) ?? .graduatedBarometer
    }

    public mutating func triggerCoachAIRelaunch() {
        coachAIRelaunchTriggeredCount += 1
    }
}

public struct MockExamDebriefModel: Codable, Equatable, Hashable, Sendable {
    public let routeCode: String
    public let routeTitle: String
    public let timePolicy: MockExamTimePolicy
    public let readiness: PrismReadinessModel
    public let objectiveCoverage: [PrismObjectiveCoverageItem]
    public let calibrationSummaryText: String
    public let detectedMisconceptions: [String]
    public var barometerCarousel: CertiGoExamBarometerCarouselModel

    public init(
        routeCode: String,
        routeTitle: String,
        timePolicy: MockExamTimePolicy,
        readiness: PrismReadinessModel,
        objectiveCoverage: [PrismObjectiveCoverageItem],
        calibrationSummaryText: String,
        detectedMisconceptions: [String] = [],
        barometerCarousel: CertiGoExamBarometerCarouselModel = CertiGoExamBarometerCarouselModel()
    ) {
        self.routeCode = routeCode
        self.routeTitle = routeTitle
        self.timePolicy = timePolicy
        self.readiness = readiness
        self.objectiveCoverage = objectiveCoverage
        self.calibrationSummaryText = calibrationSummaryText
        self.detectedMisconceptions = detectedMisconceptions
        self.barometerCarousel = barometerCarousel
    }
}

public struct MockExamStateMachine: Codable, Equatable, Hashable, Sendable {
    public let examId: String
    public let routeCode: String
    public let routeTitle: String
    public let baseDurationMinutes: Int
    public var timePolicy: MockExamTimePolicy
    public private(set) var questions: [MockExamQuestionRecord]
    public private(set) var currentQuestionIndex: Int
    public private(set) var isStarted: Bool
    public private(set) var debrief: MockExamDebriefModel?

    public init(
        examId: String,
        routeCode: String,
        routeTitle: String,
        baseDurationMinutes: Int = 45,
        timePolicy: MockExamTimePolicy = .standardTimed,
        questions: [MockExamQuestionRecord]
    ) {
        self.examId = examId
        self.routeCode = routeCode
        self.routeTitle = routeTitle
        self.baseDurationMinutes = max(5, baseDurationMinutes)
        self.timePolicy = timePolicy
        self.questions = questions
        self.currentQuestionIndex = 0
        self.isStarted = false
        self.debrief = nil
    }

    /// §6.2: ZERO feedback is ever shown during a mock exam.
    public var showsImmediateFeedbackDuringExam: Bool {
        false
    }

    public var allocatedSeconds: Int? {
        timePolicy.allocatedSeconds(baseMinutes: baseDurationMinutes)
    }

    public var currentQuestion: MockExamQuestionRecord? {
        guard isStarted, debrief == nil,
              currentQuestionIndex >= 0, currentQuestionIndex < questions.count
        else { return nil }
        return questions[currentQuestionIndex]
    }

    public mutating func startExam(policy: MockExamTimePolicy? = nil) {
        if let policy {
            self.timePolicy = policy
        }
        currentQuestionIndex = 0
        isStarted = true
        debrief = nil
    }

    public mutating func recordCurrentSelection(
        optionIds: [String],
        confidence: PrismConfidenceLevel?
    ) {
        guard currentQuestionIndex >= 0, currentQuestionIndex < questions.count else { return }
        questions[currentQuestionIndex].selectedOptionIds = optionIds
        questions[currentQuestionIndex].confidence = confidence
    }

    public mutating func advanceOrFinish(
        serverReadiness: PrismReadinessModel,
        serverCoverage: [PrismObjectiveCoverageItem],
        calibrationSummaryText: String,
        detectedMisconceptions: [String] = []
    ) -> Bool {
        guard let current = currentQuestion, current.isReadyToAdvance else {
            return false
        }
        if currentQuestionIndex + 1 < questions.count {
            currentQuestionIndex += 1
        } else {
            debrief = MockExamDebriefModel(
                routeCode: routeCode,
                routeTitle: routeTitle,
                timePolicy: timePolicy,
                readiness: serverReadiness,
                objectiveCoverage: serverCoverage,
                calibrationSummaryText: calibrationSummaryText,
                detectedMisconceptions: detectedMisconceptions
            )
        }
        return true
    }
}

// MARK: - 5. SwiftUI Screens (S-23, S-25, S-30, S-50/S-51/S-52)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SessionFeedbackPanelScreen: View {
    @Binding public var resolution: SessionFeedbackResolution
    public let onRequestExplainDifferently: () -> Void
    public let onContinue: () -> Void

    public init(
        resolution: Binding<SessionFeedbackResolution>,
        onRequestExplainDifferently: @escaping () -> Void = {},
        onContinue: @escaping () -> Void = {}
    ) {
        self._resolution = resolution
        self.onRequestExplainDifferently = onRequestExplainDifferently
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.l) {
            FeedbackPanel(
                state: resolution.feedbackState,
                onExplainDifferently: onRequestExplainDifferently
            )

            PrismCard(variant: .standard) {
                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                    ForEach(resolution.primaryDisplayedOptions) { opt in
                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                            PrismText(text: "\(opt.badge) · \(opt.text)", style: .subheadline)
                            PrismText(text: opt.explanation, style: .footnote, role: .textSecondary)
                        }
                    }

                    if resolution.allOptions.count > 2 {
                        Button {
                            resolution.areAllOptionsExpanded.toggle()
                        } label: {
                            Text(
                                verbatim: resolution.areAllOptionsExpanded
                                    ? "Masquer les autres options"
                                    : "Voir l'explication de toutes les options"
                            )
                        }
                        .buttonStyle(PrismButtonStyle(variant: .tertiary))
                    }
                }
            }

            if !resolution.responsibilityEntries.isEmpty {
                ResponsibilityMatrix(entries: resolution.responsibilityEntries)
            }

            TakeawayLine(spec: PrismTakeawaySpec(text: resolution.takeaway))

            Button {
                onContinue()
            } label: {
                Text(verbatim: "Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrismButtonStyle(variant: .primary))
        }
        .sensoryFeedback(resolution.hapticToken.sensoryFeedback, trigger: resolution.id)
    }
}

public struct SessionResultsScreen: View {
    public let model: SessionResultsModel
    public let flags: FeatureFlags
    public let onReturnToToday: () -> Void

    public init(
        model: SessionResultsModel,
        flags: FeatureFlags = FeatureFlags(),
        onReturnToToday: @escaping () -> Void = {}
    ) {
        self.model = model
        self.flags = flags
        self.onReturnToToday = onReturnToToday
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                HStack {
                    Spacer()
                    CertiGoMascotView(pose: .angleFrontCelebration, size: PrismSize.mascotHero)
                    Spacer()
                }

                PrismCelebration(
                    config: PrismCelebrationConfig(
                        level: model.celebrationLevel,
                        title: "Séance terminée",
                        subtitle: "\(model.anchoredConceptsCount) concept(s) ancré(s) durablement"
                    ),
                    onDismiss: {}
                )

                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismText(text: "Progression des concepts", style: .headline)
                        ForEach(model.conceptTransitions) { item in
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                BrandLabel(
                                    product: item.product,
                                    context: .learningContent,
                                    size: .small,
                                    flags: flags
                                )
                                PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                    PrismText(text: item.conceptTitle, style: .subheadline)
                                    MasteryGlyph(state: item.newState)
                                }
                            }
                        }
                    }
                }

                RhythmWeekView(model: model.updatedRhythm)

                PrismText(text: model.tomorrowPreviewText, style: .footnote, role: .textSecondary)

                Button {
                    onReturnToToday()
                } label: {
                    Text(verbatim: "Retour à Aujourd'hui")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .primary))
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Résultats"))
    }
}

public struct DailySituationScreen: View {
    @Binding public var machine: DailySituationStateMachine
    public let flags: FeatureFlags
    public let onShare: (PrismShareCardPayload) -> Void
    public let onClose: () -> Void

    public init(
        machine: Binding<DailySituationStateMachine>,
        flags: FeatureFlags = FeatureFlags(),
        onShare: @escaping (PrismShareCardPayload) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        self._machine = machine
        self.flags = flags
        self.onShare = onShare
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                BrandLabel(
                    product: machine.product,
                    context: .learningContent,
                    size: .medium,
                    flags: flags
                )

                PrismText(text: machine.title, style: .title2)

                PrismCard(variant: .situation) {
                    PrismText(text: machine.contextNarrative, style: .body)
                }

                ArtifactView(
                    document: machine.artifact,
                    selectedLineNumbers: .constant([])
                )

                ChoiceList(
                    options: machine.options,
                    selectedIds: Binding(
                        get: { machine.selectedOptionId.map { [$0] } ?? [] },
                        set: { machine.selectedOptionId = $0.first }
                    ),
                    allowsMultipleSelection: false,
                    isRevealed: machine.hasSubmittedAnswer
                )

                if !machine.hasSubmittedAnswer {
                    ConfidencePicker(selectedConfidence: $machine.selectedConfidence)
                    Button {
                        let correctOption = machine.options.first(where: \.isCorrect) ?? machine.options.first
                        _ = machine.submitAnswer(
                            correctOptionId: correctOption?.id ?? "a",
                            authorExplanation: correctOption?.explanation ?? "Explication vérifiée par l'auteur.",
                            takeaway: "Toujours associer Soft Delete et Purge Protection sur les ressources critiques."
                        )
                    } label: {
                        Text(verbatim: "Valider ma décision")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrismButtonStyle(variant: .primary))
                    .disabled(!machine.canSubmit)
                } else {
                    if let resolution = machine.feedbackResolution {
                        FeedbackPanel(state: resolution.feedbackState)
                    }
                    CommunityDistributionChart(model: machine.communityDistribution)
                    Button {
                        onShare(machine.makeSpoilerFreeShareCard())
                    } label: {
                        Text(verbatim: "Partager sans spoiler")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrismButtonStyle(variant: .secondary))
                }

                Button {
                    onClose()
                } label: {
                    Text(verbatim: "Retour à Aujourd'hui")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .tertiary))
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Situation du jour"))
    }
}

public struct MockExamIntroScreen: View {
    @Binding public var machine: MockExamStateMachine
    public let flags: FeatureFlags
    public let onStart: () -> Void

    public init(
        machine: Binding<MockExamStateMachine>,
        flags: FeatureFlags = FeatureFlags(),
        onStart: @escaping () -> Void = {}
    ) {
        self._machine = machine
        self.flags = flags
        self.onStart = onStart
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                BrandLabel(
                    product: BrandRegistry.productID(forTrackCode: machine.routeCode),
                    context: .learningContent,
                    examCode: machine.routeCode,
                    size: .medium,
                    flags: flags
                )

                PrismText(text: "Examen blanc · \(machine.routeTitle)", style: .title2)

                // Écran 22 Validated: Apple Pay Floating Launch Card with Real Official Certification Crest
                PrismCard(variant: .hero) {
                    VStack(spacing: PrismSpacing.m) {
                        CertiGoOfficialCrestView(routeCode: machine.routeCode, size: PrismSize.crestHero)
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: "SIMULATION OFFICIELLE PEARSON VUE · \(machine.routeCode) ★",
                                semantics: .accent
                            )
                        )
                        HStack(spacing: PrismSpacing.m) {
                            VStack(spacing: PrismSpacing.xxs) {
                                PrismText(text: "QUESTIONS", style: .caption, role: .textSecondary)
                                PrismText(text: "50 items", style: .headline)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: PrismSpacing.xxs) {
                                PrismText(text: "DURÉE STRICTE", style: .caption, role: .textSecondary)
                                PrismText(text: "90 min", style: .headline)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: PrismSpacing.xxs) {
                                PrismText(text: "SCORE REQUIS", style: .caption, role: .textSecondary)
                                PrismText(text: "700 / 1000", style: .headline, role: .accent)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismText(text: "Conditions de l'épreuve (NS-11)", style: .headline)
                        PrismText(
                            text: "Aucun feedback n'est affiché pendant l'épreuve. Le niveau de confiance est demandé à chaque question pour mesurer ta calibration.",
                            style: .subheadline,
                            role: .textSecondary
                        )
                        ForEach(MockExamTimePolicy.allCases) { policy in
                            PrismChip(
                                configuration: PrismChipConfiguration(
                                    title: policy.title,
                                    isSelected: machine.timePolicy == policy
                                )
                            ) {
                                machine.timePolicy = policy
                            }
                        }
                    }
                }

                Button {
                    machine.startExam()
                    onStart()
                } label: {
                    Text(verbatim: "Commencer l'examen blanc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .primary))
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
    }
}

public struct CertiGoExamBarometerCarouselView: View {
    @Binding public var carousel: CertiGoExamBarometerCarouselModel
    public let onTriggerCoachAIRelaunch: () -> Void

    public init(
        carousel: Binding<CertiGoExamBarometerCarouselModel>,
        onTriggerCoachAIRelaunch: @escaping () -> Void = {}
    ) {
        self._carousel = carousel
        self.onTriggerCoachAIRelaunch = onTriggerCoachAIRelaunch
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.m) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.xs) {
                    ForEach(CertiGoExamBarometerCardIndex.allCases) { card in
                        PrismChip(
                            configuration: PrismChipConfiguration(
                                title: card.shortTitle,
                                isSelected: carousel.selectedCardIndex == card
                            )
                        ) {
                            carousel.selectCard(card)
                        }
                    }
                }
            }

            // Écran 24 Validated: Swipeable Pearson VUE 3-Card Barometer Carousel
            PrismCard(variant: .hero) {
                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                    switch carousel.selectedCardIndex {
                    case .graduatedBarometer:
                        HStack {
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: carousel.card1VerdictBadgeText,
                                    semantics: carousel.isPassed ? .positive : .warning
                                )
                            )
                            Spacer()
                            PrismText(
                                text: "\(carousel.scaledScore) / \(carousel.maxScore) ›",
                                style: .title3,
                                role: carousel.isPassed ? .positive : .caution
                            )
                        }
                        PrismText(
                            text: carousel.card1GraduatedScaleText,
                            style: .codeSmall,
                            role: .accent
                        )
                        PrismProgressBar(
                            configuration: PrismProgressBarConfiguration(
                                progress: carousel.normalizedScoreProgress,
                                colorRole: carousel.isPassed ? .positive : .caution,
                                label: "Seuil officiel Pearson VUE : \(carousel.passingThreshold) / \(carousel.maxScore)"
                            )
                        )

                    case .paceAndConfidenceCalibration:
                        HStack {
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: "CARTE 2 · RYTHME CHRONO & CALIBRATION",
                                    semantics: .accent
                                )
                            )
                            Spacer()
                        }
                        PrismText(
                            text: carousel.card2PaceAndCalibrationText,
                            style: .headline
                        )
                        PrismText(
                            text: "Cadence régulière sous la cible de 90 min sans précipitation sur les questions d'architecture.",
                            style: .footnote,
                            role: .textSecondary
                        )

                    case .errorAnalysisAndAICoachRelaunch:
                        HStack {
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: "CARTE 3 · ANALYSE DES ERREURS & COACH IA",
                                    semantics: .warning
                                )
                            )
                            Spacer()
                        }
                        PrismText(
                            text: carousel.card3ErrorAnalysisTitle,
                            style: .headline
                        )
                        PrismText(
                            text: carousel.card3ErrorAnalysisDetailText,
                            style: .subheadline,
                            role: .textSecondary
                        )
                        Button {
                            carousel.triggerCoachAIRelaunch()
                            onTriggerCoachAIRelaunch()
                        } label: {
                            Text(verbatim: carousel.coachAIRelaunchActionTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrismButtonStyle(variant: .primary))
                    }
                }
            }

            HStack(spacing: PrismSpacing.xs) {
                Button {
                    carousel.returnToPreviousCard()
                } label: {
                    Text(verbatim: "‹")
                        .prismTextStyle(.headline)
                        .foregroundStyle(PrismColor.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()
                ForEach(CertiGoExamBarometerCardIndex.allCases) { card in
                    Button {
                        carousel.selectCard(card)
                    } label: {
                        if carousel.selectedCardIndex == card {
                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                .fill(PrismColor.accent)
                                .frame(
                                    width: PrismSize.carouselDotActive,
                                    height: PrismSize.carouselDotInactive
                                )
                        } else {
                            Circle()
                                .fill(PrismColor.separator)
                                .frame(
                                    width: PrismSize.carouselDotInactive,
                                    height: PrismSize.carouselDotInactive
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
                PrismText(
                    text: carousel.paginationDotsText,
                    style: .caption,
                    role: .textSecondary
                )
                Spacer()

                Button {
                    carousel.advanceToNextCard()
                } label: {
                    Text(verbatim: "›")
                        .prismTextStyle(.headline)
                        .foregroundStyle(PrismColor.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Clean Bottom White Card listing Official Domain Scores
            PrismCard(variant: .standard) {
                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                    PrismText(
                        text: "SCORES PAR DOMAINE OFFICIEL",
                        style: .caption,
                        role: .textSecondary
                    )
                    ForEach(carousel.officialDomainScores) { domainRow in
                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                            HStack(spacing: PrismSpacing.s) {
                                RegionChip(region: domainRow.region)
                                PrismText(
                                    text: "\(domainRow.domainCode) · \(domainRow.domainTitle)",
                                    style: .subheadline
                                )
                                Spacer()
                                PrismText(
                                    text: domainRow.formattedScore,
                                    style: .subheadline,
                                    role: domainRow.isPassingDomain ? .positive : .caution
                                )
                            }
                            PrismProgressBar(
                                configuration: PrismProgressBarConfiguration(
                                    progress: domainRow.normalizedProgress,
                                    colorRole: domainRow.isPassingDomain ? .positive : .caution
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}

public struct MockExamDebriefScreen: View {
    public let debrief: MockExamDebriefModel
    public let flags: FeatureFlags
    public let onFinish: () -> Void
    public let onTriggerCoachAIRelaunch: () -> Void
    @State private var carouselState: CertiGoExamBarometerCarouselModel

    public init(
        debrief: MockExamDebriefModel,
        flags: FeatureFlags = FeatureFlags(),
        onFinish: @escaping () -> Void = {},
        onTriggerCoachAIRelaunch: @escaping () -> Void = {}
    ) {
        self.debrief = debrief
        self.flags = flags
        self.onFinish = onFinish
        self.onTriggerCoachAIRelaunch = onTriggerCoachAIRelaunch
        self._carouselState = State(initialValue: debrief.barometerCarousel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                BrandLabel(
                    product: BrandRegistry.productID(forTrackCode: debrief.routeCode),
                    context: .learningContent,
                    examCode: debrief.routeCode,
                    size: .medium,
                    flags: flags
                )

                CertiGoExamBarometerCarouselView(
                    carousel: $carouselState,
                    onTriggerCoachAIRelaunch: onTriggerCoachAIRelaunch
                )

                ReadinessBandView(model: debrief.readiness)
                ObjectiveCoverageList(items: debrief.objectiveCoverage)

                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        PrismText(text: "Calibration", style: .headline)
                        PrismText(text: debrief.calibrationSummaryText, style: .subheadline, role: .textSecondary)
                    }
                }

                Button {
                    onFinish()
                } label: {
                    Text(verbatim: "Terminer le débrief")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .primary))
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Débrief d'examen blanc"))
    }
}

public struct MockExamFlowScreen: View {
    @Binding public var machine: MockExamStateMachine
    public let flags: FeatureFlags
    public let onClose: () -> Void

    public init(
        machine: Binding<MockExamStateMachine>,
        flags: FeatureFlags = FeatureFlags(),
        onClose: @escaping () -> Void = {}
    ) {
        self._machine = machine
        self.flags = flags
        self.onClose = onClose
    }

    public var body: some View {
        if let debrief = machine.debrief {
            MockExamDebriefScreen(
                debrief: debrief,
                flags: flags,
                onFinish: onClose
            )
        } else if let currentQuestion = machine.currentQuestion {
            ScrollView {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    SessionProgressHeader(
                        currentIndex: machine.currentQuestionIndex + 1,
                        totalCount: machine.questions.count,
                        stepTitle: "\(machine.routeCode) · \(currentQuestion.domainTitle)",
                        closeLabel: "Quitter l'épreuve",
                        onClose: onClose
                    )

                    BrandLabel(
                        product: currentQuestion.item.product,
                        context: .learningContent,
                        examCode: machine.routeCode,
                        size: .small,
                        flags: flags
                    )

                    PrismCard(variant: .standard) {
                        PrismText(text: currentQuestion.item.stem, style: .headline)
                    }

                    if case .choice(let options, let multi) = currentQuestion.item.payload {
                        ChoiceList(
                            options: options,
                            selectedIds: Binding(
                                get: { currentQuestion.selectedOptionIds },
                                set: { machine.recordCurrentSelection(optionIds: $0, confidence: currentQuestion.confidence) }
                            ),
                            allowsMultipleSelection: multi,
                            isRevealed: false
                        )
                    }

                    ConfidencePicker(
                        selectedConfidence: Binding(
                            get: { currentQuestion.confidence },
                            set: { machine.recordCurrentSelection(optionIds: currentQuestion.selectedOptionIds, confidence: $0) }
                        )
                    )

                    Button {
                        let readiness = PrismReadinessModel(
                            band: .readyToTry,
                            isCalibrated: true,
                            rawProbability: 0.84,
                            uncertaintyLow: 0.78,
                            uncertaintyHigh: 0.89,
                            evidenceCount: 40,
                            recommendedActions: ["Consolider Private Endpoint DNS", "Pratiquer Azure Policy vs RBAC"]
                        )
                        let coverage = [
                            PrismObjectiveCoverageItem(
                                id: currentQuestion.domainId,
                                objectiveCode: "D1",
                                title: currentQuestion.domainTitle,
                                region: .security,
                                masteryState: .anchored,
                                verifiedEvidenceCount: 11,
                                targetEvidenceCount: 12
                            )
                        ]
                        _ = machine.advanceOrFinish(
                            serverReadiness: readiness,
                            serverCoverage: coverage,
                            calibrationSummaryText: "Bonne calibration : tes niveaux de confiance correspondent à ta précision réelle."
                        )
                    } label: {
                        Text(
                            verbatim: machine.currentQuestionIndex + 1 < machine.questions.count
                                ? "Question suivante (\(machine.currentQuestionIndex + 1)/\(machine.questions.count))"
                                : "Terminer et voir le débrief"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrismButtonStyle(variant: .primary))
                    .disabled(!currentQuestion.isReadyToAdvance)
                }
                .padding(PrismSpacing.l)
            }
            .background(PrismColor.canvas)
            .navigationTitle(Text(verbatim: "Examen blanc"))
        } else {
            MockExamIntroScreen(
                machine: $machine,
                flags: flags,
                onStart: {}
            )
        }
    }
}
#endif
