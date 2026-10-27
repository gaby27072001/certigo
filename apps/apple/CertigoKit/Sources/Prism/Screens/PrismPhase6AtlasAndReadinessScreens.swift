import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Memory Detail Model (S-11, §8, §14)

public struct MemoryConceptItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let conceptTitle: String
    public let product: BrandProductID
    public let masteryState: PrismMasteryState
    public let predictedRetention: Double
    public let lastReviewedDaysAgo: Int

    public init(
        id: String,
        conceptTitle: String,
        product: BrandProductID,
        masteryState: PrismMasteryState,
        predictedRetention: Double,
        lastReviewedDaysAgo: Int
    ) {
        self.id = id
        self.conceptTitle = conceptTitle
        self.product = product
        self.masteryState = masteryState
        self.predictedRetention = min(max(predictedRetention, 0.0), 1.0)
        self.lastReviewedDaysAgo = max(0, lastReviewedDaysAgo)
    }

    public var retentionBand: PrismMemoryRetentionBand {
        PrismMemoryRetentionBand.from(retention: predictedRetention)
    }
}

public struct MemoryDetailScreenModel: Codable, Equatable, Hashable, Sendable {
    public let forecastPoints: [PrismMemoryForecastPoint]
    public let items: [MemoryConceptItem]

    public init(
        forecastPoints: [PrismMemoryForecastPoint],
        items: [MemoryConceptItem]
    ) {
        self.forecastPoints = forecastPoints
        self.items = items
    }

    public var dueSoonItems: [MemoryConceptItem] {
        items.filter { $0.retentionBand != .solid }
    }
}

// MARK: - 2. Atlas Complete Model (S-40, S-41, S-42, §8, §14, §15 NS-8, §30)

public enum AtlasPresentationMode: String, Codable, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case list
    case map

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .list: "Liste"
        case .map: "Carte"
        }
    }

    /// §15 NS-8: List is the full functional equivalent of Map and the default mode when VoiceOver is running.
    public static func defaultMode(isVoiceOverRunning: Bool) -> Self {
        PrismAtlasLayout.shouldDefaultToList(voiceOverRunning: isVoiceOverRunning) ? .list : .map
    }
}

public struct AtlasTerritorySummary: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let region: PrismRegion
    public let totalConceptsCount: Int
    public let anchoredOrMasteredCount: Int
    public let averageDepthRung: Double

    public init(
        id: String,
        title: String,
        region: PrismRegion,
        totalConceptsCount: Int,
        anchoredOrMasteredCount: Int,
        averageDepthRung: Double
    ) {
        self.id = id
        self.title = title
        self.region = region
        self.totalConceptsCount = max(1, totalConceptsCount)
        self.anchoredOrMasteredCount = min(max(0, anchoredOrMasteredCount), max(1, totalConceptsCount))
        self.averageDepthRung = min(max(averageDepthRung, 1.0), 5.0)
    }

    /// §8: Territory aggregation ring progress (0...1).
    public var ringProgress: Double {
        Double(anchoredOrMasteredCount) / Double(totalConceptsCount)
    }
}

public struct AtlasRegionSummary: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String { region.rawValue }
    public let region: PrismRegion
    public let territories: [AtlasTerritorySummary]

    public init(region: PrismRegion, territories: [AtlasTerritorySummary]) {
        self.region = region
        self.territories = territories
    }

    public var totalAnchoredOrMasteredCount: Int {
        territories.reduce(0) { $0 + $1.anchoredOrMasteredCount }
    }

    public var averageDepthRung: Double {
        guard !territories.isEmpty else { return 1.0 }
        let sum = territories.reduce(0.0) { $0 + $1.averageDepthRung }
        return sum / Double(territories.count)
    }
}

public struct AtlasScreenModel: Codable, Equatable, Hashable, Sendable {
    public static let maxVisibleNodesPerFrame: Int = 500

    public var mode: AtlasPresentationMode
    public var selectedRegion: PrismRegion?
    public var selectedState: PrismMasteryState?
    public let regions: [AtlasRegionSummary]
    public let nodes: [PrismAtlasNode]

    public init(
        isVoiceOverRunning: Bool = false,
        mode: AtlasPresentationMode? = nil,
        selectedRegion: PrismRegion? = nil,
        selectedState: PrismMasteryState? = nil,
        regions: [AtlasRegionSummary],
        nodes: [PrismAtlasNode]
    ) {
        self.mode = mode ?? AtlasPresentationMode.defaultMode(isVoiceOverRunning: isVoiceOverRunning)
        self.selectedRegion = selectedRegion
        self.selectedState = selectedState
        self.regions = regions
        self.nodes = nodes
    }

    public var visibleFilteredNodes: [PrismAtlasNode] {
        let filtered = PrismAtlasLayout.filteredNodes(
            nodes,
            region: selectedRegion,
            mastery: selectedState
        )
        return Array(filtered.prefix(Self.maxVisibleNodesPerFrame))
    }
}

// MARK: - 3. Concept Detail Page (S-43, §8, §14, §22A.5, §32.2 #6)

public struct ConceptDetailScreenModel: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let code: String
    public let title: String
    public let summary: String
    public let product: BrandProductID
    public let region: PrismRegion
    public let masteryState: PrismMasteryState
    public let depthLadder: PrismDepthLadderModel
    public let predictedRetention: Double
    public let forecastPoints: [PrismMemoryForecastPoint]
    public let activeMisconception: String?
    public let offPhonePracticePrompt: String

    public init(
        id: String,
        code: String,
        title: String,
        summary: String,
        product: BrandProductID,
        region: PrismRegion,
        masteryState: PrismMasteryState,
        depthLadder: PrismDepthLadderModel,
        predictedRetention: Double,
        forecastPoints: [PrismMemoryForecastPoint],
        activeMisconception: String? = nil,
        offPhonePracticePrompt: String = "Pratiquer hors téléphone : déploie cette ressource dans ton bac à sable cloud."
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.summary = summary
        self.product = product
        self.region = region
        self.masteryState = masteryState
        self.depthLadder = depthLadder
        self.predictedRetention = min(max(predictedRetention, 0.0), 1.0)
        self.forecastPoints = forecastPoints
        self.activeMisconception = activeMisconception
        self.offPhonePracticePrompt = offPhonePracticePrompt
    }

    public var retentionWordLabel: String {
        PrismMemoryRetentionBand.from(retention: predictedRetention).wordLabel
    }

    public var quickPracticeActionTitle: String {
        "Pratiquer 1 min"
    }
}

// MARK: - 4. Route, Exam Objective & Honest Readiness (S-47, S-48, S-49, S-53, §8, §15 NS-10)

public struct RouteReadinessScreenModel: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String { routeCode }
    public let routeCode: String
    public let officialTitle: String
    public let product: BrandProductID
    public let region: PrismRegion
    public let isConfirmedOnServer: Bool
    public let readiness: PrismReadinessModel
    public let objectiveCoverage: [PrismObjectiveCoverageItem]
    public let historyWeeksCount: Int
    public let estimatedReadyDateRange: String?

    public init(
        routeCode: String,
        officialTitle: String,
        product: BrandProductID? = nil,
        region: PrismRegion = .cloud,
        isConfirmedOnServer: Bool = true,
        readiness: PrismReadinessModel,
        objectiveCoverage: [PrismObjectiveCoverageItem],
        historyWeeksCount: Int = 0,
        estimatedReadyDateRange: String? = nil
    ) {
        self.routeCode = routeCode
        self.officialTitle = officialTitle
        self.product = product ?? BrandRegistry.productID(forTrackCode: routeCode)
        self.region = region
        self.isConfirmedOnServer = isConfirmedOnServer
        self.readiness = readiness
        self.objectiveCoverage = objectiveCoverage
        self.historyWeeksCount = max(0, historyWeeksCount)
        self.estimatedReadyDateRange = estimatedReadyDateRange
    }

    /// §8: Estimated date range is only displayed if >= 3 weeks of history exist and band != .insufficientEvidence.
    public var visibleDateRangeForecast: String? {
        guard historyWeeksCount >= 3,
              readiness.band != .insufficientEvidence,
              let estimatedReadyDateRange,
              !estimatedReadyDateRange.isEmpty
        else { return nil }
        return estimatedReadyDateRange
    }

    /// §8 & §15 NS-10: Never expose an uncalibrated probability percentage.
    public var visibleCalibratedProbability: String? {
        readiness.formattedProbability
    }
}

public enum ExamReportedOutcome: String, Codable, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case passed
    case needsRetake

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .passed: "Examen réussi"
        case .needsRetake: "À repasser — ajuster mon plan"
        }
    }
}

public struct ExamOutcomeReportDraft: Codable, Equatable, Hashable, Sendable {
    public let routeCode: String
    public let readinessBandAtExam: PrismReadinessBand
    public var outcome: ExamReportedOutcome
    public var verificationUrlString: String

    public init(
        routeCode: String,
        readinessBandAtExam: PrismReadinessBand,
        outcome: ExamReportedOutcome = .passed,
        verificationUrlString: String = ""
    ) {
        self.routeCode = routeCode
        self.readinessBandAtExam = readinessBandAtExam
        self.outcome = outcome
        self.verificationUrlString = verificationUrlString
    }
}

// MARK: - 5. Passport, Calibration History & Pro Statistics Dashboard 08B-1 / 08B-2 (S-71, S-72, §8, §14, §22A.2, §31)

public enum CertiGoProStatisticsPane: String, Codable, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case topPane08B1 = "08B-1"
    case bottomPane08B2 = "08B-2"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .topPane08B1:
            "Volet Haut (08B-1) · Indice, Radar & Heatmap"
        case .bottomPane08B2:
            "Volet Bas (08B-2) · Anneaux, Courbe /1000 & Cibles"
        }
    }
}

public struct CertiGoRadarAxisMetric: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let axisTitle: String
    public let percentage: Int
    public let region: PrismRegion

    public init(
        id: String,
        axisTitle: String,
        percentage: Int,
        region: PrismRegion
    ) {
        self.id = id
        self.axisTitle = axisTitle
        self.percentage = min(max(percentage, 0), 100)
        self.region = region
    }

    public var normalizedValue: Double {
        Double(percentage) / 100.0
    }

    public var formattedLabel: String {
        "\(axisTitle) \(percentage) %"
    }

    public var isPriorityWeakness: Bool {
        percentage < 70
    }

    public static let defaultFiveAxes: [CertiGoRadarAxisMetric] = [
        CertiGoRadarAxisMetric(id: "axis-identity", axisTitle: "Identité", percentage: 92, region: .security),
        CertiGoRadarAxisMetric(id: "axis-storage", axisTitle: "Stockage", percentage: 84, region: .data),
        CertiGoRadarAxisMetric(id: "axis-compute", axisTitle: "Calcul", percentage: 78, region: .cloud),
        CertiGoRadarAxisMetric(id: "axis-network", axisTitle: "Réseau", percentage: 58, region: .network),
        CertiGoRadarAxisMetric(id: "axis-monitoring", axisTitle: "Supervision", percentage: 76, region: .devops)
    ]
}

public struct CertiGoTelemetryCounterMetric: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let iconGlyph: String
    public let valueLabel: String
    public let subtitle: String
    public let colorRole: PrismColorRole

    public init(
        id: String,
        iconGlyph: String,
        valueLabel: String,
        subtitle: String,
        colorRole: PrismColorRole
    ) {
        self.id = id
        self.iconGlyph = iconGlyph
        self.valueLabel = valueLabel
        self.subtitle = subtitle
        self.colorRole = colorRole
    }

    public var badgeDisplayText: String {
        "\(iconGlyph) \(valueLabel)"
    }

    public static let defaultThreeCounters: [CertiGoTelemetryCounterMetric] = [
        CertiGoTelemetryCounterMetric(
            id: "telemetry-pace",
            iconGlyph: "⏱️",
            valueLabel: "18s / quest.",
            subtitle: "Rythme moyen par décision",
            colorRole: .accent
        ),
        CertiGoTelemetryCounterMetric(
            id: "telemetry-first-try",
            iconGlyph: "🎯",
            valueLabel: "88 % 1er essai",
            subtitle: "Exactitude immédiate",
            colorRole: .positive
        ),
        CertiGoTelemetryCounterMetric(
            id: "telemetry-cumulative-time",
            iconGlyph: "🔥",
            valueLabel: "24h 40m cumulées",
            subtitle: "Pratique vérifiée sur 8 sem.",
            colorRole: .caution
        )
    ]
}

public struct CertiGoConsistencyHeatmapCell: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let dayIndex: Int
    public let weekIndex: Int
    public let weekdayIndex: Int
    public let intensityLevel: Int
    public let minutesStudied: Int

    public init(
        dayIndex: Int,
        weekIndex: Int,
        weekdayIndex: Int,
        intensityLevel: Int,
        minutesStudied: Int
    ) {
        let clampedDay = min(max(dayIndex, 1), 56)
        self.id = clampedDay
        self.dayIndex = clampedDay
        self.weekIndex = min(max(weekIndex, 1), 8)
        self.weekdayIndex = min(max(weekdayIndex, 1), 7)
        self.intensityLevel = min(max(intensityLevel, 0), 3)
        self.minutesStudied = max(0, minutesStudied)
    }

    public var isActiveDay: Bool {
        intensityLevel > 0
    }

    public static func defaultEightWeeksGrid() -> [CertiGoConsistencyHeatmapCell] {
        (1...56).map { day in
            let week = ((day - 1) / 7) + 1
            let weekday = ((day - 1) % 7) + 1
            let isRest = weekday == 3 || weekday == 7
            let level = isRest ? 0 : ((day + week) % 3) + 1
            let minutes = level == 0 ? 0 : (level * 10 + 5)
            return CertiGoConsistencyHeatmapCell(
                dayIndex: day,
                weekIndex: week,
                weekdayIndex: weekday,
                intensityLevel: level,
                minutesStudied: minutes
            )
        }
    }
}

public struct CertiGoPerformanceRingMetric: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let valueSummary: String
    public let targetSummary: String
    public let rawProgressRatio: Double
    public let colorRole: PrismColorRole

    public init(
        id: String,
        title: String,
        valueSummary: String,
        targetSummary: String,
        rawProgressRatio: Double,
        colorRole: PrismColorRole
    ) {
        self.id = id
        self.title = title
        self.valueSummary = valueSummary
        self.targetSummary = targetSummary
        self.rawProgressRatio = max(0.0, rawProgressRatio)
        self.colorRole = colorRole
    }

    public var clampedProgress: Double {
        min(max(rawProgressRatio, 0.0), 1.0)
    }

    public var isGoalReached: Bool {
        rawProgressRatio >= 0.80
    }

    public var formattedSummary: String {
        "\(title) : \(valueSummary)"
    }

    public static let defaultThreeRings: [CertiGoPerformanceRingMetric] = [
        CertiGoPerformanceRingMetric(
            id: "ring-daily-goal",
            title: "Objectif Quotidien",
            valueSummary: "15/15 min",
            targetSummary: "100 % complété",
            rawProgressRatio: 1.0,
            colorRole: .positive
        ),
        CertiGoPerformanceRingMetric(
            id: "ring-qcm-accuracy",
            title: "Précision QCM",
            valueSummary: "88 %",
            targetSummary: "Cible 80 % dépassée",
            rawProgressRatio: 0.88,
            colorRole: .accent
        ),
        CertiGoPerformanceRingMetric(
            id: "ring-labs-oral-ai",
            title: "Labs & Oral IA",
            valueSummary: "6/5 séances",
            targetSummary: "120 % de l'objectif hebdo",
            rawProgressRatio: 1.2,
            colorRole: .caution
        )
    ]
}

public struct CertiGoMockScoreProgressionPoint: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String { "week-\(weekNumber)" }
    public let weekNumber: Int
    public let weekLabel: String
    public let scaledScore: Int
    public let passingThreshold: Int
    public let maxScore: Int

    public init(
        weekNumber: Int,
        weekLabel: String? = nil,
        scaledScore: Int,
        passingThreshold: Int = 700,
        maxScore: Int = 1000
    ) {
        let clampedWeek = max(1, weekNumber)
        self.weekNumber = clampedWeek
        self.weekLabel = weekLabel ?? "Sem. \(clampedWeek)"
        self.maxScore = max(100, maxScore)
        self.passingThreshold = min(max(0, passingThreshold), self.maxScore)
        self.scaledScore = min(max(0, scaledScore), self.maxScore)
    }

    public var isAbovePassingThreshold: Bool {
        scaledScore >= passingThreshold
    }

    public var normalizedProgress: Double {
        Double(scaledScore) / Double(maxScore)
    }

    public var formattedPointLabel: String {
        if weekNumber == 4 && isAbovePassingThreshold {
            return "\(weekLabel) : \(scaledScore) / \(maxScore) ✓"
        }
        return "\(weekLabel) : \(scaledScore)"
    }

    public static let defaultFourWeekCurve: [CertiGoMockScoreProgressionPoint] = [
        CertiGoMockScoreProgressionPoint(weekNumber: 1, scaledScore: 540),
        CertiGoMockScoreProgressionPoint(weekNumber: 2, scaledScore: 640),
        CertiGoMockScoreProgressionPoint(weekNumber: 3, scaledScore: 730),
        CertiGoMockScoreProgressionPoint(weekNumber: 4, scaledScore: 810)
    ]
}

public struct CertiGoStrengthOrFocusCardModel: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Equatable, Hashable, Sendable {
        case strength
        case focusTarget
    }

    public let id: String
    public let kind: Kind
    public let headerTitle: String
    public let domainTitle: String
    public let percentage: Int
    public let oneTapActionTitle: String
    public let conceptId: String
    public let region: PrismRegion

    public init(
        id: String,
        kind: Kind,
        headerTitle: String,
        domainTitle: String,
        percentage: Int,
        oneTapActionTitle: String,
        conceptId: String,
        region: PrismRegion
    ) {
        self.id = id
        self.kind = kind
        self.headerTitle = headerTitle
        self.domainTitle = domainTitle
        self.percentage = min(max(percentage, 0), 100)
        self.oneTapActionTitle = oneTapActionTitle
        self.conceptId = conceptId
        self.region = region
    }

    public var formattedSummary: String {
        "\(headerTitle) : \(domainTitle) (\(percentage) %)"
    }

    public static let defaultStrengthCard = CertiGoStrengthOrFocusCardModel(
        id: "card-strength-iam",
        kind: .strength,
        headerTitle: "💪 Points Forts",
        domainTitle: "Entra ID & RBAC",
        percentage: 92,
        oneTapActionTitle: "Maintenir en 1 tap",
        conceptId: "az104-entra-rbac",
        region: .security
    )

    public static let defaultFocusTargetCard = CertiGoStrengthOrFocusCardModel(
        id: "card-focus-network",
        kind: .focusTarget,
        headerTitle: "🎯 À Travailler",
        domainTitle: "Réseaux VNet & DNS Privé",
        percentage: 58,
        oneTapActionTitle: "Relancer en 1 tap",
        conceptId: "az104-pe-dns",
        region: .network
    )
}

public struct CertiGoProStatisticsDashboardModel: Codable, Equatable, Hashable, Sendable {
    public static let heatmapWeeksCount: Int = 8
    public static let heatmapDaysCount: Int = 56
    public static let officialPassingThreshold: Int = 700

    public let routeCode: String
    public let examReadinessIndexPercentage: Int
    public let weeklyDeltaPercentage: Int
    public let officialPassingThresholdScore: Int
    public let projectedScaledScore: Int
    public let pointsAboveOfficialThreshold: Int
    public let radarAxes: [CertiGoRadarAxisMetric]
    public let telemetryCounters: [CertiGoTelemetryCounterMetric]
    public let heatmapCells: [CertiGoConsistencyHeatmapCell]
    public let performanceRings: [CertiGoPerformanceRingMetric]
    public let mockScoreProgression: [CertiGoMockScoreProgressionPoint]
    public let strengthCard: CertiGoStrengthOrFocusCardModel
    public let focusTargetCard: CertiGoStrengthOrFocusCardModel

    public var selectedPane: CertiGoProStatisticsPane
    public var selectedRadarAxisId: String?
    public var selectedHeatmapDayIndex: Int?
    public private(set) var triggeredOneTapActionCount: Int
    public private(set) var lastTriggeredConceptId: String?

    public init(
        routeCode: String = "AZ-104",
        examReadinessIndexPercentage: Int = 84,
        weeklyDeltaPercentage: Int = 12,
        officialPassingThresholdScore: Int = Self.officialPassingThreshold,
        projectedScaledScore: Int = 785,
        pointsAboveOfficialThreshold: Int = 85,
        radarAxes: [CertiGoRadarAxisMetric] = CertiGoRadarAxisMetric.defaultFiveAxes,
        telemetryCounters: [CertiGoTelemetryCounterMetric] = CertiGoTelemetryCounterMetric.defaultThreeCounters,
        heatmapCells: [CertiGoConsistencyHeatmapCell] = CertiGoConsistencyHeatmapCell.defaultEightWeeksGrid(),
        performanceRings: [CertiGoPerformanceRingMetric] = CertiGoPerformanceRingMetric.defaultThreeRings,
        mockScoreProgression: [CertiGoMockScoreProgressionPoint] = CertiGoMockScoreProgressionPoint.defaultFourWeekCurve,
        strengthCard: CertiGoStrengthOrFocusCardModel = .defaultStrengthCard,
        focusTargetCard: CertiGoStrengthOrFocusCardModel = .defaultFocusTargetCard,
        selectedPane: CertiGoProStatisticsPane = .topPane08B1,
        selectedRadarAxisId: String? = nil,
        selectedHeatmapDayIndex: Int? = nil,
        triggeredOneTapActionCount: Int = 0,
        lastTriggeredConceptId: String? = nil
    ) {
        self.routeCode = routeCode
        self.examReadinessIndexPercentage = min(max(examReadinessIndexPercentage, 0), 100)
        self.weeklyDeltaPercentage = weeklyDeltaPercentage
        self.officialPassingThresholdScore = max(100, officialPassingThresholdScore)
        self.projectedScaledScore = min(max(0, projectedScaledScore), 1000)
        self.pointsAboveOfficialThreshold = pointsAboveOfficialThreshold
        self.radarAxes = radarAxes
        self.telemetryCounters = telemetryCounters
        self.heatmapCells = heatmapCells
        self.performanceRings = performanceRings
        self.mockScoreProgression = mockScoreProgression
        self.strengthCard = strengthCard
        self.focusTargetCard = focusTargetCard
        self.selectedPane = selectedPane
        self.selectedRadarAxisId = selectedRadarAxisId ?? radarAxes.first?.id
        self.selectedHeatmapDayIndex = selectedHeatmapDayIndex
        self.triggeredOneTapActionCount = max(0, triggeredOneTapActionCount)
        self.lastTriggeredConceptId = lastTriggeredConceptId
    }

    public var readinessBadgeText: String {
        "INDICE DE FORME EXAMEN · \(examReadinessIndexPercentage) % (PRÊT ✓)"
    }

    public var thresholdSurplusHeadline: String {
        "Seuil officiel Pearson VUE (\(officialPassingThresholdScore)/1000) dépassé de +\(pointsAboveOfficialThreshold) pts"
    }

    public var radarInlineSummaryText: String {
        let axisSummary = radarAxes.map(\.formattedLabel).joined(separator: " · ")
        return "📈 +\(weeklyDeltaPercentage) % cette semaine · Radar 5 Axes : \(axisSummary)"
    }

    public var mockProgressionSummaryText: String {
        "Courbe Examen Blanc : Sem. 1 (540) ──► Sem. 2 (640) ──► Sem. 3 (730) ──► Sem. 4 (810 / 1000 ✓)"
    }

    public var strengthVsFocusSummaryText: String {
        "\(strengthCard.formattedSummary) · \(focusTargetCard.formattedSummary)"
    }

    public var activeHeatmapDaysCount: Int {
        heatmapCells.filter(\.isActiveDay).count
    }

    public var selectedRadarAxis: CertiGoRadarAxisMetric? {
        guard let selectedRadarAxisId else { return radarAxes.first }
        return radarAxes.first(where: { $0.id == selectedRadarAxisId }) ?? radarAxes.first
    }

    public mutating func selectPane(_ pane: CertiGoProStatisticsPane) {
        selectedPane = pane
    }

    public mutating func selectRadarAxis(id: String) {
        if radarAxes.contains(where: { $0.id == id }) {
            selectedRadarAxisId = id
        }
    }

    public mutating func selectHeatmapDay(dayIndex: Int) {
        if heatmapCells.contains(where: { $0.dayIndex == dayIndex }) {
            selectedHeatmapDayIndex = dayIndex
        }
    }

    @discardableResult
    public mutating func triggerOneTapFocusAction() -> String {
        triggeredOneTapActionCount += 1
        lastTriggeredConceptId = focusTargetCard.conceptId
        return focusTargetCard.conceptId
    }

    @discardableResult
    public mutating func triggerOneTapStrengthAction() -> String {
        triggeredOneTapActionCount += 1
        lastTriggeredConceptId = strengthCard.conceptId
        return strengthCard.conceptId
    }
}

public struct CalibrationSamplePoint: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let confidence: PrismConfidenceLevel
    public let wasCorrect: Bool

    public init(id: String, confidence: PrismConfidenceLevel, wasCorrect: Bool) {
        self.id = id
        self.confidence = confidence
        self.wasCorrect = wasCorrect
    }

    public var predictedProbability: Double {
        switch confidence {
        case .sure: 0.90
        case .rather: 0.65
        case .guess: 0.25
        }
    }
}

public struct CalibrationHistoryScreenModel: Codable, Equatable, Hashable, Sendable {
    public let passport: PrismPassportSummary
    public let samples: [CalibrationSamplePoint]
    public let recentSessionsCount: Int
    public var proDashboard: CertiGoProStatisticsDashboardModel

    public init(
        passport: PrismPassportSummary,
        samples: [CalibrationSamplePoint],
        recentSessionsCount: Int,
        proDashboard: CertiGoProStatisticsDashboardModel = CertiGoProStatisticsDashboardModel()
    ) {
        self.passport = passport
        self.samples = samples
        self.recentSessionsCount = max(0, recentSessionsCount)
        self.proDashboard = proDashboard
    }

    /// Brier score (§31: lower is better calibrated; 0.0 is perfect calibration).
    public var brierScore: Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0.0) { acc, sample in
            let outcome = sample.wasCorrect ? 1.0 : 0.0
            let diff = sample.predictedProbability - outcome
            return acc + diff * diff
        }
        return total / Double(samples.count)
    }

    public var calibrationLabel: String {
        guard let score = brierScore else { return "Preuves de calibration insuffisantes" }
        if score <= 0.12 { return "Calibration très précise" }
        if score <= 0.22 { return "Calibration équilibrée" }
        return "Surconfiance ou sous-confiance à affiner"
    }
}

// MARK: - 6. Global Search Model (S-90, §12, §14, §22A.5)

public struct GlobalSearchResultItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Equatable, Hashable, Sendable {
        case concept
        case route
        case product
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let subtitle: String
    public let product: BrandProductID
    public let region: PrismRegion

    public init(
        id: String,
        kind: Kind,
        title: String,
        subtitle: String,
        product: BrandProductID,
        region: PrismRegion
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.product = product
        self.region = region
    }
}

public struct GlobalSearchScreenModel: Codable, Equatable, Hashable, Sendable {
    public var query: String
    public let catalog: [GlobalSearchResultItem]

    public init(query: String = "", catalog: [GlobalSearchResultItem]) {
        self.query = query
        self.catalog = catalog
    }

    public var filteredResults: [GlobalSearchResultItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return catalog }
        return catalog.filter {
            $0.title.lowercased().contains(q)
                || $0.subtitle.lowercased().contains(q)
                || $0.product.rawValue.lowercased().contains(q)
        }
    }
}

// MARK: - 7. SwiftUI Views (S-11, S-40..S-43, S-47..S-49, S-53, S-71, S-72, S-90)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct MemoryDetailScreen: View {
    public let model: MemoryDetailScreenModel
    public let flags: FeatureFlags
    public let onSelectConcept: (MemoryConceptItem) -> Void

    public init(
        model: MemoryDetailScreenModel,
        flags: FeatureFlags = FeatureFlags(),
        onSelectConcept: @escaping (MemoryConceptItem) -> Void = { _ in }
    ) {
        self.model = model
        self.flags = flags
        self.onSelectConcept = onSelectConcept
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                MemoryForecastChart(points: model.forecastPoints)

                PrismSection(title: "Concepts à raviver (\(model.dueSoonItems.count))") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(model.items) { item in
                            PrismCard(variant: .standard) {
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    BrandLabel(
                                        product: item.product,
                                        context: .learningContent,
                                        size: .small,
                                        flags: flags
                                    )
                                    PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                        PrismText(text: item.conceptTitle, style: .headline)
                                        MasteryGlyph(state: item.masteryState)
                                    }
                                    PrismText(
                                        text: "Mémoire : \(item.retentionBand.wordLabel)",
                                        style: .footnote,
                                        role: .textSecondary
                                    )
                                    Button {
                                        onSelectConcept(item)
                                    } label: {
                                        Text(verbatim: "Pratiquer 1 min")
                                    }
                                    .buttonStyle(PrismButtonStyle(variant: .tertiary))
                                }
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Mémoire"))
    }
}

public struct AtlasCompleteScreen: View {
    @Binding public var model: AtlasScreenModel
    public let onSelectRegion: (AtlasRegionSummary) -> Void
    public let onSelectNode: (PrismAtlasNode) -> Void
    public let onOpenExplorer: () -> Void

    public init(
        model: Binding<AtlasScreenModel>,
        onSelectRegion: @escaping (AtlasRegionSummary) -> Void = { _ in },
        onSelectNode: @escaping (PrismAtlasNode) -> Void = { _ in },
        onOpenExplorer: @escaping () -> Void = {}
    ) {
        self._model = model
        self.onSelectRegion = onSelectRegion
        self.onSelectNode = onSelectNode
        self.onOpenExplorer = onOpenExplorer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                HStack(spacing: PrismSpacing.s) {
                    ForEach(AtlasPresentationMode.allCases) { modeOption in
                        PrismChip(
                            configuration: PrismChipConfiguration(
                                title: modeOption.title,
                                isSelected: model.mode == modeOption
                            )
                        ) {
                            model.mode = modeOption
                        }
                    }
                }

                PrismCard(variant: .hero) {
                    PrismRow(
                        configuration: PrismRowConfiguration(
                            title: "Catalogue des routes de certification",
                            subtitle: "Explorer les parcours officiels et choisir ton objectif actif",
                            showsChevron: true
                        ),
                        action: onOpenExplorer
                    )
                }

                if !model.regions.isEmpty {
                    PrismSection(title: "Régions & territoires de compétences") {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            ForEach(model.regions) { regionSummary in
                                ForEach(regionSummary.territories) { territory in
                                    PrismCard(variant: .standard) {
                                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                            PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                                RegionChip(region: territory.region)
                                                PrismBadge(
                                                    configuration: PrismBadgeConfiguration(
                                                        text: "\(territory.anchoredOrMasteredCount)/\(territory.totalConceptsCount) ancrés",
                                                        semantics: .positive
                                                    )
                                                )
                                            }
                                            PrismText(text: territory.title, style: .headline)
                                            PrismProgressBar(
                                                configuration: PrismProgressBarConfiguration(
                                                    progress: territory.ringProgress,
                                                    label: "Échelon moyen : \(String(format: "%.1f", territory.averageDepthRung))/5"
                                                )
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if model.mode == .list {
                    AtlasList(
                        nodes: model.visibleFilteredNodes,
                        selectedRegion: model.selectedRegion,
                        selectedState: model.selectedState,
                        onSelectNode: onSelectNode
                    )
                } else {
                    AtlasCanvas(
                        nodes: model.visibleFilteredNodes,
                        onSelectNode: onSelectNode
                    )
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Atlas"))
    }
}

public struct ConceptDetailScreen: View {
    public let model: ConceptDetailScreenModel
    public let flags: FeatureFlags
    public let onPracticeOneMinute: () -> Void

    public init(
        model: ConceptDetailScreenModel,
        flags: FeatureFlags = FeatureFlags(),
        onPracticeOneMinute: @escaping () -> Void = {}
    ) {
        self.model = model
        self.flags = flags
        self.onPracticeOneMinute = onPracticeOneMinute
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                BrandLabel(
                    product: model.product,
                    context: .learningContent,
                    size: .medium,
                    flags: flags
                )

                PrismAdaptiveStack(spacing: PrismSpacing.s) {
                    PrismText(text: "\(model.code) · \(model.title)", style: .title2)
                    MasteryGlyph(state: model.masteryState)
                }

                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismText(text: model.summary, style: .body)
                        PrismText(
                            text: "Rétention prédite : \(model.retentionWordLabel)",
                            style: .subheadline,
                            role: .textSecondary
                        )
                    }
                }

                DepthLadderView(model: model.depthLadder)
                MemoryForecastChart(points: model.forecastPoints)

                if let misconception = model.activeMisconception {
                    PrismCard(variant: .feedback) {
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            PrismText(text: "Fausse idée active à corriger", style: .headline)
                            PrismText(text: misconception, style: .subheadline, role: .textSecondary)
                        }
                    }
                }

                Button {
                    onPracticeOneMinute()
                } label: {
                    Text(verbatim: model.quickPracticeActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .primary))
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: model.title))
    }
}

public struct RouteReadinessScreen: View {
    public let model: RouteReadinessScreenModel
    public let flags: FeatureFlags
    public let onStartMockExam: () -> Void
    public let onReportExamOutcome: () -> Void

    public init(
        model: RouteReadinessScreenModel,
        flags: FeatureFlags = FeatureFlags(),
        onStartMockExam: @escaping () -> Void = {},
        onReportExamOutcome: @escaping () -> Void = {}
    ) {
        self.model = model
        self.flags = flags
        self.onStartMockExam = onStartMockExam
        self.onReportExamOutcome = onReportExamOutcome
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                // Écran 26 Validated: Official Certification Crest Hero Card
                PrismCard(variant: .hero) {
                    VStack(spacing: PrismSpacing.s) {
                        CertiGoOfficialCrestView(routeCode: model.routeCode, size: PrismSize.crestHero)
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: "CERTIFICATION OFFICIELLE · \(model.routeCode)",
                                semantics: .accent
                            )
                        )
                        PrismText(text: model.officialTitle, style: .title2)
                    }
                }

                BrandLabel(
                    product: model.product,
                    context: .learningContent,
                    examCode: model.routeCode,
                    size: .medium,
                    flags: flags
                )

                ReadinessBandView(model: model.readiness)

                if let dateRange = model.visibleDateRangeForecast {
                    PrismCard(variant: .standard) {
                        PrismText(text: "Horizon estimé : \(dateRange)", style: .subheadline)
                    }
                }

                ObjectiveCoverageList(items: model.objectiveCoverage)

                Button {
                    onStartMockExam()
                } label: {
                    Text(verbatim: "Passer un examen blanc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .primary))

                Button {
                    onReportExamOutcome()
                } label: {
                    Text(verbatim: "Déclarer mon résultat d'examen officiel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .secondary))
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Préparation"))
    }
}

public struct CertiGoProStatisticsDashboardView: View {
    @Binding public var dashboard: CertiGoProStatisticsDashboardModel
    public let onTriggerOneTapAction: (String) -> Void

    public init(
        dashboard: Binding<CertiGoProStatisticsDashboardModel>,
        onTriggerOneTapAction: @escaping (String) -> Void = { _ in }
    ) {
        self._dashboard = dashboard
        self.onTriggerOneTapAction = onTriggerOneTapAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.l) {
            HStack(spacing: PrismSpacing.s) {
                ForEach(CertiGoProStatisticsPane.allCases) { pane in
                    PrismChip(
                        configuration: PrismChipConfiguration(
                            title: pane.title,
                            isSelected: dashboard.selectedPane == pane
                        )
                    ) {
                        dashboard.selectPane(pane)
                    }
                }
            }

            // Écran 08B-1 Validé (Haut) : Indice de Forme 84 %, Radar Polygonal 5 Axes, 3 Compteurs & Heatmap 8 Semaines (56 jours)
            PrismCard(variant: .hero) {
                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    HStack {
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: dashboard.readinessBadgeText,
                                semantics: .positive
                            )
                        )
                        Spacer()
                    }
                    PrismText(text: dashboard.thresholdSurplusHeadline, style: .headline)
                    PrismText(
                        text: dashboard.radarInlineSummaryText,
                        style: .footnote,
                        role: .textSecondary
                    )

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        PrismText(text: "RADAR POLYGONAL À 5 AXES", style: .caption, role: .accent)
                        ForEach(dashboard.radarAxes) { axis in
                            Button {
                                dashboard.selectRadarAxis(id: axis.id)
                            } label: {
                                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                    HStack(spacing: PrismSpacing.s) {
                                        RegionChip(region: axis.region)
                                        PrismText(
                                            text: axis.formattedLabel,
                                            style: .subheadline,
                                            role: axis.isPriorityWeakness ? .caution : .textPrimary
                                        )
                                        Spacer()
                                        if dashboard.selectedRadarAxisId == axis.id {
                                            PrismBadge(
                                                configuration: PrismBadgeConfiguration(
                                                    text: axis.isPriorityWeakness ? "Priorité" : "Sélectionné",
                                                    semantics: axis.isPriorityWeakness ? .warning : .accent
                                                )
                                            )
                                        }
                                    }
                                    PrismProgressBar(
                                        configuration: PrismProgressBarConfiguration(
                                            progress: axis.normalizedValue,
                                            colorRole: axis.isPriorityWeakness ? .caution : .positive
                                        )
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PrismSpacing.s) {
                            ForEach(dashboard.telemetryCounters) { counter in
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: counter.badgeDisplayText,
                                        semantics: counter.colorRole == .positive
                                            ? .positive
                                            : (counter.colorRole == .caution ? .warning : .accent)
                                    )
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        PrismText(
                            text: "GRILLE HEATMAP DE CONSTANCE · 8 SEMAINES (\(dashboard.heatmapCells.count) JOURS)",
                            style: .caption,
                            role: .textSecondary
                        )
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: PrismSpacing.xxs),
                                count: 7
                            ),
                            spacing: PrismSpacing.xxs
                        ) {
                            ForEach(dashboard.heatmapCells) { cell in
                                Button {
                                    dashboard.selectHeatmapDay(dayIndex: cell.dayIndex)
                                } label: {
                                    RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                                        .fill(heatmapColor(for: cell.intensityLevel))
                                        .frame(
                                            width: PrismSize.heatmapCellWidth,
                                            height: PrismSize.heatmapCellHeight
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    Text(verbatim: "Jour \(cell.dayIndex), \(cell.minutesStudied) min")
                                )
                            }
                        }
                    }
                }
            }

            // Écran 08B-2 Validé (Bas en défilant) : 3 Anneaux de Performance, Courbe /1000 & Forces / À Travailler (1 tap)
            PrismCard(variant: .standard) {
                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    PrismText(
                        text: "ANNEAUX D'ACTIVITÉ & PROGRESSION EXAMEN (/1000)",
                        style: .caption,
                        role: .accent
                    )

                    HStack(spacing: PrismSpacing.l) {
                        ZStack {
                            PrismProgressRing(
                                progress: dashboard.performanceRings.first?.clampedProgress ?? 1.0,
                                colorRole: .positive,
                                diameter: PrismSize.ringOuter
                            )
                            PrismProgressRing(
                                progress: dashboard.performanceRings.dropFirst().first?.clampedProgress ?? 0.88,
                                colorRole: .accent,
                                diameter: PrismSize.ringMiddle
                            )
                            PrismProgressRing(
                                progress: dashboard.performanceRings.last?.clampedProgress ?? 1.0,
                                colorRole: .caution,
                                centerLabel: "3/3",
                                diameter: PrismSize.ringInner
                            )
                        }

                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            ForEach(dashboard.performanceRings) { ring in
                                PrismText(
                                    text: "● \(ring.formattedSummary) (\(ring.targetSummary))",
                                    style: .subheadline
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        PrismText(
                            text: dashboard.mockProgressionSummaryText,
                            style: .footnote,
                            role: .positive
                        )
                        ForEach(dashboard.mockScoreProgression) { point in
                            HStack(spacing: PrismSpacing.s) {
                                PrismText(
                                    text: point.formattedPointLabel,
                                    style: .footnote,
                                    role: point.isAbovePassingThreshold ? .positive : .textSecondary
                                )
                                Spacer()
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: point.isAbovePassingThreshold ? "Seuil 700 ✓" : "< 700",
                                        semantics: point.isAbovePassingThreshold ? .positive : .neutral
                                    )
                                )
                            }
                        }
                    }

                    PrismText(
                        text: dashboard.strengthVsFocusSummaryText,
                        style: .footnote,
                        role: .textSecondary
                    )

                    PrismAdaptiveStack(spacing: PrismSpacing.s) {
                        PrismCard(variant: .standard, semanticBorderRole: .positive) {
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                PrismText(
                                    text: dashboard.strengthCard.headerTitle,
                                    style: .caption,
                                    role: .positive
                                )
                                PrismText(
                                    text: "\(dashboard.strengthCard.domainTitle) (\(dashboard.strengthCard.percentage) %)",
                                    style: .subheadline
                                )
                                Button {
                                    let conceptId = dashboard.triggerOneTapStrengthAction()
                                    onTriggerOneTapAction(conceptId)
                                } label: {
                                    Text(verbatim: dashboard.strengthCard.oneTapActionTitle)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrismButtonStyle(variant: .tertiary))
                            }
                        }

                        PrismCard(variant: .feedback, semanticBorderRole: .caution) {
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                PrismText(
                                    text: dashboard.focusTargetCard.headerTitle,
                                    style: .caption,
                                    role: .caution
                                )
                                PrismText(
                                    text: "\(dashboard.focusTargetCard.domainTitle) (\(dashboard.focusTargetCard.percentage) %)",
                                    style: .subheadline
                                )
                                Button {
                                    let conceptId = dashboard.triggerOneTapFocusAction()
                                    onTriggerOneTapAction(conceptId)
                                } label: {
                                    Text(verbatim: dashboard.focusTargetCard.oneTapActionTitle)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrismButtonStyle(variant: .primary))
                            }
                        }
                    }
                }
            }
        }
    }

    private func heatmapColor(for intensity: Int) -> Color {
        switch intensity {
        case 3:
            return PrismColor.positive
        case 2:
            return PrismColor.accent
        case 1:
            return PrismColor.accent.opacity(0.45)
        default:
            return PrismColor.surfaceRaised
        }
    }
}

public struct PassportAndCalibrationScreen: View {
    public let model: CalibrationHistoryScreenModel
    public let onTriggerOneTapAction: (String) -> Void
    @State private var dashboardState: CertiGoProStatisticsDashboardModel

    public init(
        model: CalibrationHistoryScreenModel,
        onTriggerOneTapAction: @escaping (String) -> Void = { _ in }
    ) {
        self.model = model
        self.onTriggerOneTapAction = onTriggerOneTapAction
        self._dashboardState = State(initialValue: model.proDashboard)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                CertiGoProStatisticsDashboardView(
                    dashboard: $dashboardState,
                    onTriggerOneTapAction: onTriggerOneTapAction
                )

                PassportCard(summary: model.passport)

                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismText(text: "Calibration & historique (S-72)", style: .headline)
                        PrismText(text: model.calibrationLabel, style: .subheadline, role: .textSecondary)
                        PrismText(
                            text: "\(model.recentSessionsCount) séances complétées · \(model.samples.count) décisions calibrées",
                            style: .footnote,
                            role: .textSecondary
                        )
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Passeport"))
    }
}

public struct GlobalSearchScreen: View {
    @Binding public var model: GlobalSearchScreenModel
    public let flags: FeatureFlags
    public let onSelectResult: (GlobalSearchResultItem) -> Void

    public init(
        model: Binding<GlobalSearchScreenModel>,
        flags: FeatureFlags = FeatureFlags(),
        onSelectResult: @escaping (GlobalSearchResultItem) -> Void = { _ in }
    ) {
        self._model = model
        self.flags = flags
        self.onSelectResult = onSelectResult
    }

    public var body: some View {
        List {
            ForEach(model.filteredResults) { item in
                Button {
                    onSelectResult(item)
                } label: {
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        BrandLabel(
                            product: item.product,
                            context: .learningContent,
                            size: .small,
                            flags: flags
                        )
                        PrismText(text: item.title, style: .headline)
                        PrismText(text: item.subtitle, style: .footnote, role: .textSecondary)
                    }
                }
            }
        }
        .searchable(text: $model.query)
        .navigationTitle(Text(verbatim: "Recherche"))
    }
}
#endif
