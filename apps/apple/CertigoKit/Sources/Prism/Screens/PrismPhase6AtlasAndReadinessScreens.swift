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

// MARK: - 5. Passport & Calibration History (S-71, S-72, §8, §14, §22A.2, §31)

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

    public init(
        passport: PrismPassportSummary,
        samples: [CalibrationSamplePoint],
        recentSessionsCount: Int
    ) {
        self.passport = passport
        self.samples = samples
        self.recentSessionsCount = max(0, recentSessionsCount)
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

                PrismCard(variant: .standard) {
                    PrismRow(
                        configuration: PrismRowConfiguration(
                            title: "Objectifs & routes de certification",
                            subtitle: "Explorer le catalogue complet",
                            showsChevron: true
                        ),
                        action: onOpenExplorer
                    )
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
                        selectedRegion: model.selectedRegion,
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
                BrandLabel(
                    product: model.product,
                    context: .catalog,
                    examCode: model.routeCode,
                    size: .medium,
                    flags: flags
                )

                PrismText(text: model.officialTitle, style: .title2)

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

public struct PassportAndCalibrationScreen: View {
    public let model: CalibrationHistoryScreenModel

    public init(model: CalibrationHistoryScreenModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
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
                            context: .catalog,
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
