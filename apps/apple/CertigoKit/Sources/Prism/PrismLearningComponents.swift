import Foundation

// MARK: - 1. SessionProgressHeader Model

public struct PrismSessionProgressModel: Equatable, Codable, Sendable {
    public let currentIndex: Int
    public let totalCount: Int
    public let stepTitle: String
    public let closeLabel: String

    public init(
        currentIndex: Int,
        totalCount: Int,
        stepTitle: String,
        closeLabel: String = "Terminer et sauvegarder"
    ) {
        self.currentIndex = currentIndex
        self.totalCount = totalCount
        self.stepTitle = stepTitle
        self.closeLabel = closeLabel
    }

    public var clampedCurrentIndex: Int {
        guard totalCount > 0 else { return 0 }
        return min(max(currentIndex, 0), totalCount)
    }

    public var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return min(max(Double(clampedCurrentIndex) / Double(totalCount), 0), 1)
    }

    public var progressSummary: String {
        "\(clampedCurrentIndex) / \(max(totalCount, 0))"
    }

    public var accessibilitySummary: String {
        "Étape \(clampedCurrentIndex) sur \(max(totalCount, 0)), \(stepTitle)"
    }
}

// MARK: - 2. SessionLengthPicker & PrismSessionLength Models

public enum PrismSessionLength: String, CaseIterable, Codable, Sendable, Identifiable {
    case express
    case standard
    case deepDive

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .express:
            return "Express"
        case .standard:
            return "Séance"
        case .deepDive:
            return "Plongée"
        }
    }

    public var durationLabel: String {
        switch self {
        case .express:
            return "~5 min"
        case .standard:
            return "~15 min"
        case .deepDive:
            return "30–45 min"
        }
    }

    public var subtitle: String {
        switch self {
        case .express:
            return "Révision rapide et ciblée"
        case .standard:
            return "Rythme équilibré avec pratique"
        case .deepDive:
            return "Exploration complète et cas avancés"
        }
    }

    public var estimatedMinutes: Int {
        switch self {
        case .express:
            return 5
        case .standard:
            return 15
        case .deepDive:
            return 35
        }
    }
}

public struct SessionLengthOption: Identifiable, Equatable, Codable, Sendable {
    public let length: PrismSessionLength
    public let isSuggested: Bool

    public var id: String { length.id }
    public var title: String { length.title }
    public var durationLabel: String { length.durationLabel }
    public var subtitle: String { length.subtitle }

    public init(length: PrismSessionLength, isSuggested: Bool = false) {
        self.length = length
        self.isSuggested = isSuggested
    }

    public static func allOptions(suggestedLength: PrismSessionLength?) -> [SessionLengthOption] {
        PrismSessionLength.allCases.map { candidate in
            SessionLengthOption(length: candidate, isSuggested: candidate == suggestedLength)
        }
    }
}

public typealias PrismSessionLengthOption = SessionLengthOption

// MARK: - 3. QuestionCard Model

public struct PrismQuestionSpec: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let prompt: String
    public let situationContext: String?
    public let domainLabel: String?
    public let revealOptionsDelayMs: Int
    public let revealOptionsLabel: String

    public init(
        id: String = "question",
        prompt: String,
        situationContext: String? = nil,
        domainLabel: String? = nil,
        revealOptionsDelayMs: Int = 0,
        revealOptionsLabel: String = "Voir les options"
    ) {
        self.id = id
        self.prompt = prompt
        self.situationContext = situationContext
        self.domainLabel = domainLabel
        self.revealOptionsDelayMs = max(0, revealOptionsDelayMs)
        self.revealOptionsLabel = revealOptionsLabel
    }

    public func shouldRevealImmediately(reduceMotion: Bool) -> Bool {
        reduceMotion || revealOptionsDelayMs <= 0
    }

    public func effectiveDelayNanoseconds(reduceMotion: Bool) -> UInt64 {
        guard !shouldRevealImmediately(reduceMotion: reduceMotion) else { return 0 }
        return UInt64(revealOptionsDelayMs) * 1_000_000
    }
}

public typealias QuestionSpec = PrismQuestionSpec

// MARK: - 4. ExplanationCard Model

public struct PrismVerifiedSource: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let referenceCode: String
    public let urlString: String?

    public init(
        id: String,
        title: String,
        referenceCode: String,
        urlString: String? = nil
    ) {
        self.id = id
        self.title = title
        self.referenceCode = referenceCode
        self.urlString = urlString
    }
}

public struct PrismExplanationSpec: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let keyPoints: [String]
    public let verifiedSources: [PrismVerifiedSource]

    public init(
        id: String = "explanation",
        title: String,
        body: String,
        keyPoints: [String] = [],
        verifiedSources: [PrismVerifiedSource] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.keyPoints = keyPoints
        self.verifiedSources = verifiedSources
    }
}

public typealias ExplanationSpec = PrismExplanationSpec

// MARK: - 5. WorkedExampleView Models

public struct PrismWorkedStep: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let stepNumber: Int
    public let subgoalTitle: String
    public let detail: String
    public let formulaOrCommand: String?
    public let isInitiallyExpanded: Bool

    public init(
        id: String,
        stepNumber: Int,
        subgoalTitle: String,
        detail: String,
        formulaOrCommand: String? = nil,
        isInitiallyExpanded: Bool = true
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.subgoalTitle = subgoalTitle
        self.detail = detail
        self.formulaOrCommand = formulaOrCommand
        self.isInitiallyExpanded = isInitiallyExpanded
    }
}

public struct PrismWorkedExample: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let problemContext: String
    public let steps: [PrismWorkedStep]
    public let conclusion: String
    public let isSkippable: Bool
    public let skipActionTitle: String

    public init(
        id: String = "worked-example",
        title: String,
        problemContext: String,
        steps: [PrismWorkedStep],
        conclusion: String,
        isSkippable: Bool = true,
        skipActionTitle: String = "Je connais déjà"
    ) {
        self.id = id
        self.title = title
        self.problemContext = problemContext
        self.steps = steps
        self.conclusion = conclusion
        self.isSkippable = isSkippable
        self.skipActionTitle = skipActionTitle
    }
}

// MARK: - 6. DiagramView & DiagramSpec Models

public struct DiagramNode: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let label: String
    public let productId: String?
    public let region: PrismRegion
    public let groupId: String?
    public let roleDescription: String?

    public init(
        id: String,
        label: String,
        productId: String? = nil,
        region: PrismRegion = PrismRegion.allCases.first!,
        groupId: String? = nil,
        roleDescription: String? = nil
    ) {
        self.id = id
        self.label = label
        self.productId = productId
        self.region = region
        self.groupId = groupId
        self.roleDescription = roleDescription
    }
}

public struct DiagramEdge: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let fromNodeId: String
    public let toNodeId: String
    public let label: String?
    public let isBidirectional: Bool

    public init(
        id: String,
        fromNodeId: String,
        toNodeId: String,
        label: String? = nil,
        isBidirectional: Bool = false
    ) {
        self.id = id
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.label = label
        self.isBidirectional = isBidirectional
    }
}

public struct DiagramGroup: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let label: String
    public let region: PrismRegion
    public let nodeIds: [String]

    public init(
        id: String,
        label: String,
        region: PrismRegion = PrismRegion.allCases.first!,
        nodeIds: [String] = []
    ) {
        self.id = id
        self.label = label
        self.region = region
        self.nodeIds = nodeIds
    }
}

public struct DiagramSpec: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let nodes: [DiagramNode]
    public let edges: [DiagramEdge]
    public let groups: [DiagramGroup]
    public let accessibleSummary: String

    public init(
        id: String = "diagram",
        title: String = "Architecture",
        nodes: [DiagramNode],
        edges: [DiagramEdge] = [],
        groups: [DiagramGroup] = [],
        accessibleSummary: String
    ) {
        self.id = id
        self.title = title
        self.nodes = nodes
        self.edges = edges
        self.groups = groups
        self.accessibleSummary = accessibleSummary
    }

    public func nodes(in group: DiagramGroup) -> [DiagramNode] {
        let idSet = Set(group.nodeIds)
        return nodes.filter { idSet.contains($0.id) || $0.groupId == group.id }
    }

    public var ungroupedNodes: [DiagramNode] {
        let groupedIds = Set(groups.flatMap(\.nodeIds))
        let groupKeySet = Set(groups.map(\.id))
        return nodes.filter { node in
            if groupedIds.contains(node.id) { return false }
            if let groupId = node.groupId, groupKeySet.contains(groupId) { return false }
            return true
        }
    }

    public func nodeLabel(for nodeId: String) -> String {
        nodes.first(where: { $0.id == nodeId })?.label ?? nodeId
    }

    public var structuredVoiceOverDescription: String {
        var parts: [String] = [accessibleSummary]
        if !groups.isEmpty {
            let groupDescriptions = groups.map { group in
                let memberLabels = nodes(in: group).map(\.label).joined(separator: ", ")
                return memberLabels.isEmpty
                    ? "Groupe \(group.label)"
                    : "Groupe \(group.label) contenant \(memberLabels)"
            }
            parts.append(groupDescriptions.joined(separator: ". "))
        }
        if !edges.isEmpty {
            let edgeDescriptions = edges.map { edge in
                let source = nodeLabel(for: edge.fromNodeId)
                let target = nodeLabel(for: edge.toNodeId)
                let direction = edge.isBidirectional ? "connecté bidirectionnellement à" : "vers"
                if let edgeLabel = edge.label, !edgeLabel.isEmpty {
                    return "\(source) \(direction) \(target) (\(edgeLabel))"
                }
                return "\(source) \(direction) \(target)"
            }
            parts.append("Connexions : " + edgeDescriptions.joined(separator: " ; "))
        }
        return parts.joined(separator: ". ")
    }
}

public typealias PrismDiagramSpec = DiagramSpec

// MARK: - 7. ArtifactView & PrismArtifactDocument Models

public struct PrismArtifactSpan: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let text: String
    public let syntax: PrismSyntax

    public init(
        id: String,
        text: String,
        syntax: PrismSyntax = PrismSyntax.allCases.first!
    ) {
        self.id = id
        self.text = text
        self.syntax = syntax
    }
}

public struct PrismArtifactLine: Identifiable, Equatable, Codable, Sendable {
    public let lineNumber: Int
    public let text: String
    public let syntax: PrismSyntax
    public let spans: [PrismArtifactSpan]
    public let diagnosticNote: String?

    public var id: Int { lineNumber }

    public init(
        lineNumber: Int,
        text: String,
        syntax: PrismSyntax = PrismSyntax.allCases.first!,
        spans: [PrismArtifactSpan] = [],
        diagnosticNote: String? = nil
    ) {
        self.lineNumber = lineNumber
        self.text = text
        self.syntax = syntax
        self.spans = spans
        self.diagnosticNote = diagnosticNote
    }

    public var formattedLineNumber: String {
        lineNumber < 10 ? "0\(lineNumber)" : "\(lineNumber)"
    }
}

public typealias ArtifactLine = PrismArtifactLine

public struct PrismArtifactDocument: Identifiable, Equatable, Codable, Sendable {
    public static let maxCollapsedLines: Int = 25

    public let id: String
    public let title: String
    public let language: String
    public let lines: [PrismArtifactLine]
    public let spotTheIssueInteractive: Bool

    public init(
        id: String = "artifact",
        title: String,
        language: String,
        lines: [PrismArtifactLine],
        spotTheIssueInteractive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.language = language
        self.lines = lines
        self.spotTheIssueInteractive = spotTheIssueInteractive
    }

    public var requiresCollapse: Bool {
        lines.count > Self.maxCollapsedLines
    }

    public var hiddenLineCount: Int {
        max(0, lines.count - Self.maxCollapsedLines)
    }

    public func visibleLines(isExpanded: Bool) -> [PrismArtifactLine] {
        guard !isExpanded && requiresCollapse else { return lines }
        return Array(lines.prefix(Self.maxCollapsedLines))
    }

    public static func toggleLineSelection(
        lineNumber: Int,
        in selection: Set<Int>,
        allowsMultipleSelection: Bool = true
    ) -> Set<Int> {
        var updated = selection
        if updated.contains(lineNumber) {
            updated.remove(lineNumber)
        } else if allowsMultipleSelection {
            updated.insert(lineNumber)
        } else {
            updated = [lineNumber]
        }
        return updated
    }
}

// MARK: - 8. ChoiceList & PrismChoiceOption Models

public enum PrismChoiceVisualState: String, Equatable, Codable, Sendable {
    case neutral
    case selected
    case correctSelected
    case correctUnselected
    case incorrectSelected

    public var statusWord: String {
        switch self {
        case .neutral:
            return "Option"
        case .selected:
            return "Choisi"
        case .correctSelected:
            return "Correct • Choisi"
        case .correctUnselected:
            return "Correct"
        case .incorrectSelected:
            return "Incorrect • Choisi"
        }
    }

    public var symbolName: String {
        switch self {
        case .neutral:
            return "circle"
        case .selected:
            return "checkmark.circle.fill"
        case .correctSelected:
            return "checkmark.seal.fill"
        case .correctUnselected:
            return "arrow.right.circle.fill"
        case .incorrectSelected:
            return "xmark.octagon.fill"
        }
    }
}

public struct PrismChoiceOption: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let badge: String
    public let text: String
    public let explanation: String
    public let isCorrect: Bool

    public init(
        id: String,
        badge: String,
        text: String,
        explanation: String,
        isCorrect: Bool = false
    ) {
        self.id = id
        self.badge = badge
        self.text = text
        self.explanation = explanation
        self.isCorrect = isCorrect
    }

    public func visualState(isSelected: Bool, isRevealed: Bool) -> PrismChoiceVisualState {
        guard isRevealed else {
            return isSelected ? .selected : .neutral
        }
        if isCorrect && isSelected {
            return .correctSelected
        }
        if isCorrect && !isSelected {
            return .correctUnselected
        }
        if !isCorrect && isSelected {
            return .incorrectSelected
        }
        return .neutral
    }

    public static func updatedSelection(
        tapping optionId: String,
        currentSelection: Set<String>,
        allowsMultipleSelection: Bool
    ) -> Set<String> {
        if allowsMultipleSelection {
            var next = currentSelection
            if next.contains(optionId) {
                next.remove(optionId)
            } else {
                next.insert(optionId)
            }
            return next
        } else {
            return currentSelection.contains(optionId) ? [] : [optionId]
        }
    }
}

public typealias ChoiceOption = PrismChoiceOption

// MARK: - 9. ConfidencePicker & PrismConfidenceLevel Models

public enum PrismConfidenceLevel: String, CaseIterable, Codable, Sendable, Identifiable {
    case sure
    case rather
    case guess

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sure:
            return "Sûr"
        case .rather:
            return "Plutôt"
        case .guess:
            return "Au hasard"
        }
    }

    public var subtitle: String {
        switch self {
        case .sure:
            return "Règle maîtrisée"
        case .rather:
            return "Hésitation partielle"
        case .guess:
            return "Intuition"
        }
    }

    public var symbolName: String {
        switch self {
        case .sure:
            return "checkmark.shield"
        case .rather:
            return "questionmark.circle"
        case .guess:
            return "dice"
        }
    }
}

public typealias ConfidenceLevel = PrismConfidenceLevel

// MARK: - 10. TokenComposer Models

public struct PrismCommandToken: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let text: String
    public let syntax: PrismSyntax

    public init(
        id: String,
        text: String,
        syntax: PrismSyntax = PrismSyntax.allCases.first!
    ) {
        self.id = id
        self.text = text
        self.syntax = syntax
    }
}

public struct PrismTokenComposerState: Equatable, Codable, Sendable {
    public var availableTokens: [PrismCommandToken]
    public var selectedTokens: [PrismCommandToken]

    public init(
        availableTokens: [PrismCommandToken],
        selectedTokens: [PrismCommandToken] = []
    ) {
        self.availableTokens = availableTokens
        self.selectedTokens = selectedTokens
    }

    public var composedCommand: String {
        selectedTokens.map(\.text).joined(separator: " ")
    }

    public var remainingTokens: [PrismCommandToken] {
        let selectedIds = Set(selectedTokens.map(\.id))
        return availableTokens.filter { !selectedIds.contains($0.id) }
    }

    public mutating func selectToken(_ token: PrismCommandToken) {
        guard !selectedTokens.contains(where: { $0.id == token.id }) else { return }
        selectedTokens.append(token)
    }

    public mutating func removeToken(id: String) {
        selectedTokens.removeAll { $0.id == id }
    }

    public mutating func reset() {
        selectedTokens.removeAll()
    }
}

// MARK: - 11. OrderList Models

public struct PrismOrderItem: Identifiable, Equatable, Codable, Sendable {
    public static let maxIndentation: Int = 3

    public let id: String
    public let text: String
    public var indentLevel: Int

    public init(id: String, text: String, indentLevel: Int = 0) {
        self.id = id
        self.text = text
        self.indentLevel = min(max(indentLevel, 0), Self.maxIndentation)
    }

    public static func moveUp(_ items: [PrismOrderItem], at index: Int) -> [PrismOrderItem] {
        guard index > 0, index < items.count else { return items }
        var copy = items
        copy.swapAt(index, index - 1)
        return copy
    }

    public static func moveDown(_ items: [PrismOrderItem], at index: Int) -> [PrismOrderItem] {
        guard index >= 0, index < items.count - 1 else { return items }
        var copy = items
        copy.swapAt(index, index + 1)
        return copy
    }

    public static func adjustIndent(_ items: [PrismOrderItem], at index: Int, delta: Int) -> [PrismOrderItem] {
        guard index >= 0, index < items.count else { return items }
        var copy = items
        let updatedIndent = min(max(copy[index].indentLevel + delta, 0), maxIndentation)
        copy[index].indentLevel = updatedIndent
        return copy
    }
}

// MARK: - 12. SlotBoard Models

public struct PrismSlotItem: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let label: String
    public let detail: String?

    public init(id: String, label: String, detail: String? = nil) {
        self.id = id
        self.label = label
        self.detail = detail
    }
}

public struct PrismSlotTarget: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?

    public init(id: String, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

public struct PrismSlotBoardState: Equatable, Codable, Sendable {
    public var items: [PrismSlotItem]
    public var targets: [PrismSlotTarget]
    public var assignments: [String: String]
    public var selectedSourceItemId: String?

    public init(
        items: [PrismSlotItem],
        targets: [PrismSlotTarget],
        assignments: [String: String] = [:],
        selectedSourceItemId: String? = nil
    ) {
        self.items = items
        self.targets = targets
        self.assignments = assignments
        self.selectedSourceItemId = selectedSourceItemId
    }

    public var unassignedItems: [PrismSlotItem] {
        let assignedIds = Set(assignments.values)
        return items.filter { !assignedIds.contains($0.id) }
    }

    public func assignedItem(for targetId: String) -> PrismSlotItem? {
        guard let itemId = assignments[targetId] else { return nil }
        return items.first { $0.id == itemId }
    }

    public mutating func tapSourceItem(_ itemId: String) {
        if selectedSourceItemId == itemId {
            selectedSourceItemId = nil
        } else {
            selectedSourceItemId = itemId
        }
    }

    public mutating func tapTargetSlot(_ targetId: String) {
        if let sourceId = selectedSourceItemId {
            for (existingTarget, existingItem) in assignments where existingItem == sourceId {
                assignments.removeValue(forKey: existingTarget)
            }
            assignments[targetId] = sourceId
            selectedSourceItemId = nil
        } else {
            assignments.removeValue(forKey: targetId)
        }
    }
}

// MARK: - 13. EstimateSlider Model

public struct PrismEstimateSpec: Equatable, Codable, Sendable {
    public let title: String
    public let unit: String
    public let minimumValue: Double
    public let maximumValue: Double
    public let step: Double

    public init(
        title: String,
        unit: String,
        minimumValue: Double,
        maximumValue: Double,
        step: Double = 1
    ) {
        let safeMin = min(minimumValue, maximumValue)
        let safeMax = max(minimumValue, maximumValue)
        self.title = title
        self.unit = unit
        self.minimumValue = safeMin
        self.maximumValue = safeMax == safeMin ? safeMin + 1 : safeMax
        self.step = max(step, 0.1)
    }

    public func clamped(_ value: Double) -> Double {
        min(max(value, minimumValue), maximumValue)
    }

    public func incremented(_ value: Double) -> Double {
        clamped(value + step)
    }

    public func decremented(_ value: Double) -> Double {
        clamped(value - step)
    }

    public func formattedValue(_ value: Double) -> String {
        let clean = clamped(value)
        if step.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(clean.rounded())) \(unit)"
        }
        return String(format: "%.1f %@", clean, unit)
    }
}

// MARK: - 14. ExplainInput Model

public struct PrismExplainPromptSpec: Equatable, Codable, Sendable {
    public let prompt: String
    public let placeholder: String
    public let maxCharacters: Int

    public init(
        prompt: String,
        placeholder: String = "Explique ton raisonnement avec tes propres mots…",
        maxCharacters: Int = 280
    ) {
        self.prompt = prompt
        self.placeholder = placeholder
        self.maxCharacters = max(maxCharacters, 1)
    }

    public func characterCount(for text: String) -> Int {
        text.count
    }

    public func remainingCharacters(for text: String) -> Int {
        maxCharacters - text.count
    }

    public func counterDescription(for text: String) -> String {
        "\(text.count) / \(maxCharacters) caractères"
    }
}

// MARK: - 15. FeedbackPanel & PrismFeedbackState Models

public enum FeedbackVariant: String, CaseIterable, Codable, Sendable {
    case correct
    case incorrect
    case partial
    case confidentError
    case aiUnavailable

    public var statusTitle: String {
        switch self {
        case .correct:
            return "Réponse exacte"
        case .incorrect:
            return "Réponse à ajuster"
        case .partial:
            return "Réponse partielle"
        case .confidentError:
            return "Erreur avec certitude"
        case .aiUnavailable:
            return "Explication auteur vérifiée"
        }
    }

    public var symbolName: String {
        switch self {
        case .correct:
            return "checkmark.seal.fill"
        case .incorrect:
            return "xmark.circle.fill"
        case .partial:
            return "circle.lefthalf.filled"
        case .confidentError:
            return "exclamationmark.triangle.fill"
        case .aiUnavailable:
            return "book.closed.fill"
        }
    }
}

public typealias PrismFeedbackVariant = FeedbackVariant

public struct PrismFeedbackState: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let variant: FeedbackVariant
    public let headline: String
    public let chosenOptionExplanation: String
    public let authorExplanation: String
    public let misconceptionTitle: String?
    public let misconceptionCorrection: String?
    public let canExplainDifferently: Bool

    public init(
        id: String = "feedback",
        variant: FeedbackVariant,
        headline: String,
        chosenOptionExplanation: String,
        authorExplanation: String = "",
        misconceptionTitle: String? = nil,
        misconceptionCorrection: String? = nil,
        canExplainDifferently: Bool = true
    ) {
        self.id = id
        self.variant = variant
        self.headline = headline
        self.chosenOptionExplanation = chosenOptionExplanation
        self.authorExplanation = authorExplanation
        self.misconceptionTitle = misconceptionTitle
        self.misconceptionCorrection = misconceptionCorrection
        self.canExplainDifferently = canExplainDifferently
    }

    public var resolvedExplanation: String {
        if variant == .aiUnavailable, !authorExplanation.isEmpty {
            return authorExplanation
        }
        if !chosenOptionExplanation.isEmpty {
            return chosenOptionExplanation
        }
        return authorExplanation
    }

    public var showsExplainDifferentlyButton: Bool {
        canExplainDifferently && variant != .aiUnavailable
    }

    public static func resolveVariant(
        isCorrect: Bool,
        isPartial: Bool = false,
        confidence: PrismConfidenceLevel?,
        aiAvailable: Bool = true
    ) -> FeedbackVariant {
        if !aiAvailable {
            return .aiUnavailable
        }
        if isCorrect {
            return .correct
        }
        if isPartial {
            return .partial
        }
        if confidence == .sure {
            return .confidentError
        }
        return .incorrect
    }
}

// MARK: - 16. ResponsibilityMatrix Models

public enum PrismResponsibilityOwner: String, CaseIterable, Codable, Sendable, Identifiable {
    case customer
    case shared
    case cloudProvider

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .customer:
            return "Client"
        case .shared:
            return "Partagée"
        case .cloudProvider:
            return "Fournisseur Cloud"
        }
    }

    public var symbolName: String {
        switch self {
        case .customer:
            return "person.crop.circle.fill"
        case .shared:
            return "person.2.circle.fill"
        case .cloudProvider:
            return "cloud.fill"
        }
    }
}

public struct ResponsibilityEntry: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let layerName: String
    public let serviceModel: String
    public let owner: PrismResponsibilityOwner
    public let rationale: String?

    public init(
        id: String,
        layerName: String,
        serviceModel: String,
        owner: PrismResponsibilityOwner,
        rationale: String? = nil
    ) {
        self.id = id
        self.layerName = layerName
        self.serviceModel = serviceModel
        self.owner = owner
        self.rationale = rationale
    }
}

public typealias PrismResponsibilityEntry = ResponsibilityEntry

// MARK: - 17. TakeawayLine Model

public struct PrismTakeawaySpec: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let sentence: String
    public let region: PrismRegion

    public init(
        id: String = "takeaway",
        title: String = "À retenir",
        sentence: String,
        region: PrismRegion = PrismRegion.allCases.first!
    ) {
        self.id = id
        self.title = title
        self.sentence = sentence
        self.region = region
    }
}

// MARK: - 18. HintLadderView & PrismHintLadder Models

public struct HintStep: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let level: Int
    public let title: String
    public let hintText: String

    public init(id: String, level: Int, title: String, hintText: String) {
        self.id = id
        self.level = min(max(level, 1), PrismHintLadder.maxLevel)
        self.title = title
        self.hintText = hintText
    }
}

public typealias PrismHintStep = HintStep

public struct PrismHintLadder: Identifiable, Equatable, Codable, Sendable {
    public static let maxLevel: Int = 4

    public let id: String
    public let steps: [HintStep]
    public var unlockedLevel: Int
    public var hasAttemptedQuestion: Bool

    public init(
        id: String = "hint-ladder",
        steps: [HintStep],
        unlockedLevel: Int = 0,
        hasAttemptedQuestion: Bool = false
    ) {
        self.id = id
        self.steps = Array(steps.sorted(by: { $0.level < $1.level }).prefix(Self.maxLevel))
        self.unlockedLevel = min(max(unlockedLevel, 0), Self.maxLevel)
        self.hasAttemptedQuestion = hasAttemptedQuestion
    }

    public var highestAvailableLevel: Int {
        min(Self.maxLevel, steps.count)
    }

    public var canUnlockNext: Bool {
        hasAttemptedQuestion && unlockedLevel < highestAvailableLevel
    }

    public func isUnlocked(_ step: HintStep) -> Bool {
        step.level <= unlockedLevel
    }

    public mutating func registerAttempt() {
        hasAttemptedQuestion = true
        if unlockedLevel == 0, highestAvailableLevel >= 1 {
            unlockedLevel = 1
        }
    }

    public mutating func unlockNextLevel() {
        guard canUnlockNext else { return }
        unlockedLevel = min(unlockedLevel + 1, highestAvailableLevel)
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - Internal Token Resolution Helpers

private enum PrismLearningStyleResolver {
    static let title: PrismTextStyle = match(["title", "screenTitle", "sectionTitle", "titleLarge", "titleMedium", "headline"])
    static let headline: PrismTextStyle = match(["headline", "cardTitle", "titleSmall", "bodyStrong", "subheadline"])
    static let subheadline: PrismTextStyle = match(["subheadline", "callout", "labelLarge", "body"])
    static let body: PrismTextStyle = match(["body", "bodyMedium", "bodyLarge", "callout"])
    static let caption: PrismTextStyle = match(["caption", "footnote", "labelSmall", "bodySmall"])
    static let code: PrismTextStyle = match(["code", "codeMedium", "codeSmall"])
    static let codeSmall: PrismTextStyle = .codeSmall

    private static func match(_ names: [String]) -> PrismTextStyle {
        for candidate in names {
            if let resolved = PrismTextStyle.allCases.first(where: { String(describing: $0) == candidate }) {
                return resolved
            }
        }
        return .codeSmall
    }
}

private enum PrismLearningMotionResolver {
    static var defaultToken: PrismMotion {
        PrismMotion.allCases.first!
    }

    static func animation(reduceMotion: Bool) -> Animation? {
        PrismMotion.resolve(defaultToken, reduceMotion: reduceMotion).animation
    }
}

private enum PrismLearningPaletteResolver {
    static var accentColor: Color {
        PrismRegion.allCases.first!.color
    }

    static var secondaryAccentColor: Color {
        let all = Array(PrismRegion.allCases)
        return all[min(1, max(all.count - 1, 0))].color
    }

    static func syntaxColor(at index: Int) -> Color {
        let all = Array(PrismSyntax.allCases)
        return all[index % max(all.count, 1)].color
    }
}

// MARK: - 1. SessionProgressHeader View

public struct SessionProgressHeader: View {
    public let model: PrismSessionProgressModel
    public let onClose: () -> Void

    public init(
        currentIndex: Int,
        totalCount: Int,
        stepTitle: String,
        closeLabel: String = "Terminer et sauvegarder",
        onClose: @escaping () -> Void
    ) {
        self.model = PrismSessionProgressModel(
            currentIndex: currentIndex,
            totalCount: totalCount,
            stepTitle: stepTitle,
            closeLabel: closeLabel
        )
        self.onClose = onClose
    }

    public init(model: PrismSessionProgressModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            HStack(alignment: .center, spacing: PrismSpacing.md) {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: model.stepTitle)
                        .prismTextStyle(PrismLearningStyleResolver.headline)
                    Text(verbatim: model.progressSummary)
                        .prismTextStyle(PrismLearningStyleResolver.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: PrismSpacing.sm)

                Button(action: onClose) {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: "xmark.circle.fill")
                        Text(verbatim: model.closeLabel)
                            .prismTextStyle(PrismLearningStyleResolver.caption)
                    }
                    .padding(.horizontal, PrismSpacing.sm)
                    .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.md)
                            .fill(.thinMaterial)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: model.closeLabel))
            }

            ProgressView(value: model.progressFraction)
                .tint(PrismLearningPaletteResolver.accentColor)
                .accessibilityValue(Text(verbatim: model.accessibilitySummary))
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 2. SessionLengthPicker View

public struct SessionLengthPicker: View {
    @Binding public var selectedLength: PrismSessionLength
    public let suggestedLength: PrismSessionLength?
    public let onSelect: ((PrismSessionLength) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        selectedLength: Binding<PrismSessionLength>,
        suggestedLength: PrismSessionLength? = .standard,
        onSelect: ((PrismSessionLength) -> Void)? = nil
    ) {
        self._selectedLength = selectedLength
        self.suggestedLength = suggestedLength
        self.onSelect = onSelect
    }

    public var body: some View {
        let options = SessionLengthOption.allOptions(suggestedLength: suggestedLength)
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            Text(verbatim: "Durée de séance")
                .prismTextStyle(PrismLearningStyleResolver.headline)

            ForEach(options) { option in
                let isSelected = selectedLength == option.length
                Button {
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        selectedLength = option.length
                    }
                    onSelect?(option.length)
                } label: {
                    HStack(alignment: .center, spacing: PrismSpacing.md) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                isSelected
                                    ? PrismLearningPaletteResolver.accentColor
                                    : PrismLearningPaletteResolver.secondaryAccentColor
                            )

                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            HStack(spacing: PrismSpacing.xs) {
                                Text(verbatim: option.title)
                                    .prismTextStyle(PrismLearningStyleResolver.headline)
                                Text(verbatim: option.durationLabel)
                                    .prismTextStyle(.codeSmall)
                                    .foregroundStyle(.secondary)
                                if option.isSuggested {
                                    Text(verbatim: "Suggéré")
                                        .prismTextStyle(PrismLearningStyleResolver.caption)
                                        .padding(.horizontal, PrismSpacing.xs)
                                        .padding(.vertical, PrismSpacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.sm)
                                                .fill(PrismSyntax.flaggedLineBackground)
                                        )
                                }
                            }
                            Text(verbatim: option.subtitle)
                                .prismTextStyle(PrismLearningStyleResolver.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: PrismSpacing.sm)
                    }
                    .padding(PrismSpacing.md)
                    .frame(minHeight: PrismSize.minTouch)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.md)
                            .fill(isSelected ? AnyShapeStyle(PrismSyntax.flaggedLineBackground) : AnyShapeStyle(.thinMaterial))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.md)
                            .strokeBorder(
                                isSelected
                                    ? PrismLearningPaletteResolver.accentColor
                                    : PrismLearningPaletteResolver.secondaryAccentColor.opacity(0.25)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 3. QuestionCard View

public struct QuestionCard: View {
    public let spec: PrismQuestionSpec
    @Binding public var areOptionsRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        spec: PrismQuestionSpec,
        areOptionsRevealed: Binding<Bool>
    ) {
        self.spec = spec
        self._areOptionsRevealed = areOptionsRevealed
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            if let domainLabel = spec.domainLabel, !domainLabel.isEmpty {
                Text(verbatim: domainLabel)
                    .prismTextStyle(PrismLearningStyleResolver.caption)
                    .foregroundStyle(PrismLearningPaletteResolver.accentColor)
            }

            if let context = spec.situationContext, !context.isEmpty {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: "Mise en situation")
                        .prismTextStyle(PrismLearningStyleResolver.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: context)
                        .prismTextStyle(PrismLearningStyleResolver.body)
                }
                .padding(PrismSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .fill(.thinMaterial)
                )
            }

            Text(verbatim: spec.prompt)
                .prismTextStyle(PrismLearningStyleResolver.title)
                .fixedSize(horizontal: false, vertical: true)

            if !areOptionsRevealed && !spec.shouldRevealImmediately(reduceMotion: reduceMotion) {
                Button {
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        areOptionsRevealed = true
                    }
                } label: {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: "eye.fill")
                        Text(verbatim: spec.revealOptionsLabel)
                            .prismTextStyle(PrismLearningStyleResolver.headline)
                    }
                    .padding(.horizontal, PrismSpacing.md)
                    .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.md)
                            .fill(PrismSyntax.flaggedLineBackground)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PrismSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
        .task(id: spec.id) {
            if spec.shouldRevealImmediately(reduceMotion: reduceMotion) {
                areOptionsRevealed = true
            } else if !areOptionsRevealed {
                let ns = spec.effectiveDelayNanoseconds(reduceMotion: reduceMotion)
                try? await Task.sleep(nanoseconds: ns)
                if !Task.isCancelled {
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        areOptionsRevealed = true
                    }
                }
            }
        }
    }
}

// MARK: - 4. ExplanationCard View

public struct ExplanationCard: View {
    public let spec: PrismExplanationSpec

    public init(spec: PrismExplanationSpec) {
        self.spec = spec
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            Text(verbatim: spec.title)
                .prismTextStyle(PrismLearningStyleResolver.headline)

            Text(verbatim: spec.body)
                .prismTextStyle(PrismLearningStyleResolver.body)
                .fixedSize(horizontal: false, vertical: true)

            if !spec.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: "Points clés")
                        .prismTextStyle(PrismLearningStyleResolver.subheadline)
                    ForEach(Array(spec.keyPoints.enumerated()), id: \.offset) { _, point in
                        HStack(alignment: .top, spacing: PrismSpacing.xs) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(PrismLearningPaletteResolver.accentColor)
                            Text(verbatim: point)
                                .prismTextStyle(PrismLearningStyleResolver.body)
                        }
                    }
                }
            }

            if !spec.verifiedSources.isEmpty {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: "Sources vérifiées")
                        .prismTextStyle(PrismLearningStyleResolver.caption)
                        .foregroundStyle(.secondary)

                    ForEach(spec.verifiedSources) { source in
                        HStack(spacing: PrismSpacing.xs) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(PrismLearningPaletteResolver.secondaryAccentColor)
                            Text(verbatim: "\(source.title) (\(source.referenceCode))")
                                .prismTextStyle(PrismLearningStyleResolver.caption)
                        }
                    }
                }
                .padding(PrismSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .fill(.thinMaterial)
                )
            }
        }
        .padding(PrismSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 5. WorkedExampleView

public struct WorkedExampleView: View {
    public let example: PrismWorkedExample
    public let onSkipTest: (() -> Void)?

    @State private var expandedStepIds: Set<String>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        example: PrismWorkedExample,
        onSkipTest: (() -> Void)? = nil
    ) {
        self.example = example
        self.onSkipTest = onSkipTest
        let initialIds = example.steps.filter(\.isInitiallyExpanded).map(\.id)
        self._expandedStepIds = State(initialValue: Set(initialIds))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            HStack(alignment: .top, spacing: PrismSpacing.md) {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: example.title)
                        .prismTextStyle(PrismLearningStyleResolver.headline)
                    Text(verbatim: example.problemContext)
                        .prismTextStyle(PrismLearningStyleResolver.body)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: PrismSpacing.sm)

                if example.isSkippable, let onSkipTest {
                    Button(action: onSkipTest) {
                        HStack(spacing: PrismSpacing.xs) {
                            Image(systemName: "forward.end.fill")
                            Text(verbatim: example.skipActionTitle)
                                .prismTextStyle(PrismLearningStyleResolver.caption)
                        }
                        .padding(.horizontal, PrismSpacing.sm)
                        .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.md)
                                .fill(PrismSyntax.flaggedLineBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(example.steps) { step in
                let isExpanded = expandedStepIds.contains(step.id)
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Button {
                        withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                            if isExpanded {
                                expandedStepIds.remove(step.id)
                            } else {
                                expandedStepIds.insert(step.id)
                            }
                        }
                    } label: {
                        HStack(spacing: PrismSpacing.sm) {
                            Text(verbatim: "Étape \(step.stepNumber)")
                                .prismTextStyle(.codeSmall)
                                .foregroundStyle(PrismLearningPaletteResolver.accentColor)
                            Text(verbatim: step.subgoalTitle)
                                .prismTextStyle(PrismLearningStyleResolver.subheadline)
                            Spacer(minLength: PrismSpacing.xs)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: PrismSize.minTouch)
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        Text(verbatim: step.detail)
                            .prismTextStyle(PrismLearningStyleResolver.body)
                        if let command = step.formulaOrCommand, !command.isEmpty {
                            Text(verbatim: command)
                                .prismTextStyle(.codeSmall)
                                .padding(PrismSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.sm)
                                        .fill(PrismColor.surfaceArtifact)
                                )
                        }
                    }
                }
                .padding(PrismSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .fill(.thinMaterial)
                )
            }

            Text(verbatim: example.conclusion)
                .prismTextStyle(PrismLearningStyleResolver.subheadline)
        }
        .padding(PrismSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 6. DiagramView

public struct DiagramView: View {
    public let spec: DiagramSpec
    @State private var showsAccessibleTranscript: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(spec: DiagramSpec) {
        self.spec = spec
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            HStack(spacing: PrismSpacing.sm) {
                Text(verbatim: spec.title)
                    .prismTextStyle(PrismLearningStyleResolver.headline)
                Spacer(minLength: PrismSpacing.xs)
                Button {
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        showsAccessibleTranscript.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: "text.alignleft")
                        Text(verbatim: showsAccessibleTranscript ? "Masquer la description" : "Description textuelle")
                            .prismTextStyle(PrismLearningStyleResolver.caption)
                    }
                    .padding(.horizontal, PrismSpacing.sm)
                    .frame(minHeight: PrismSize.minTouch)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.sm)
                            .fill(.thinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(spec.groups) { group in
                VStack(alignment: .leading, spacing: PrismSpacing.sm) {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(group.region.color)
                        Text(verbatim: group.label)
                            .prismTextStyle(PrismLearningStyleResolver.subheadline)
                    }

                    ForEach(spec.nodes(in: group)) { node in
                        nodeCard(node)
                    }
                }
                .padding(PrismSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .fill(.thinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .strokeBorder(group.region.color)
                )
            }

            if !spec.ungroupedNodes.isEmpty {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    ForEach(spec.ungroupedNodes) { node in
                        nodeCard(node)
                    }
                }
            }

            if !spec.edges.isEmpty {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: "Flux et liaisons")
                        .prismTextStyle(PrismLearningStyleResolver.caption)
                        .foregroundStyle(.secondary)

                    ForEach(spec.edges) { edge in
                        HStack(spacing: PrismSpacing.xs) {
                            Text(verbatim: spec.nodeLabel(for: edge.fromNodeId))
                                .prismTextStyle(.codeSmall)
                            Image(systemName: edge.isBidirectional ? "arrow.left.and.right" : "arrow.right")
                                .foregroundStyle(PrismLearningPaletteResolver.accentColor)
                            Text(verbatim: spec.nodeLabel(for: edge.toNodeId))
                                .prismTextStyle(.codeSmall)
                            if let edgeLabel = edge.label, !edgeLabel.isEmpty {
                                Text(verbatim: "(\(edgeLabel))")
                                    .prismTextStyle(PrismLearningStyleResolver.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(PrismSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.sm)
                        .fill(.thinMaterial)
                )
            }

            if showsAccessibleTranscript {
                Text(verbatim: spec.structuredVoiceOverDescription)
                    .prismTextStyle(PrismLearningStyleResolver.caption)
                    .padding(PrismSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.sm)
                            .fill(.thinMaterial)
                    )
            }
        }
        .padding(PrismSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: spec.structuredVoiceOverDescription))
    }

    @ViewBuilder
    private func nodeCard(_ node: DiagramNode) -> some View {
        HStack(spacing: PrismSpacing.sm) {
            Image(systemName: "cpu.fill")
                .foregroundStyle(node.region.color)
            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                Text(verbatim: node.label)
                    .prismTextStyle(PrismLearningStyleResolver.body)
                if let productId = node.productId, !productId.isEmpty {
                    Text(verbatim: productId)
                        .prismTextStyle(.codeSmall)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: PrismSpacing.xs)
        }
        .padding(PrismSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.sm)
                .fill(PrismColor.surfaceArtifact)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.sm)
                .strokeBorder(node.region.color)
        )
    }
}

// MARK: - 7. ArtifactView

public struct ArtifactView: View {
    public let document: PrismArtifactDocument
    @Binding public var selectedLineNumbers: Set<Int>
    public let allowsMultipleSelection: Bool

    @State private var wrapsLines: Bool = true
    @State private var isExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        document: PrismArtifactDocument,
        selectedLineNumbers: Binding<Set<Int>>,
        allowsMultipleSelection: Bool = true
    ) {
        self.document = document
        self._selectedLineNumbers = selectedLineNumbers
        self.allowsMultipleSelection = allowsMultipleSelection
    }

    public var body: some View {
        let displayedLines = document.visibleLines(isExpanded: isExpanded)
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            HStack(spacing: PrismSpacing.sm) {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: document.title)
                        .prismTextStyle(PrismLearningStyleResolver.subheadline)
                    Text(verbatim: document.language.uppercased())
                        .prismTextStyle(.codeSmall)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: PrismSpacing.xs)

                Button {
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        wrapsLines.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: wrapsLines ? "arrow.turn.down.left" : "arrow.left.and.right")
                        Text(verbatim: wrapsLines ? "Retour ligne" : "Défilement")
                            .prismTextStyle(PrismLearningStyleResolver.caption)
                    }
                    .padding(.horizontal, PrismSpacing.sm)
                    .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.sm)
                            .fill(.thinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }

            Group {
                if wrapsLines {
                    linesListView(displayedLines)
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        linesListView(displayedLines)
                    }
                }
            }

            if document.requiresCollapse {
                Button {
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        Text(
                            verbatim: isExpanded
                                ? "Replier aux \(PrismArtifactDocument.maxCollapsedLines) premières lignes"
                                : "Afficher les \(document.hiddenLineCount) lignes supplémentaires"
                        )
                        .prismTextStyle(PrismLearningStyleResolver.caption)
                    }
                    .padding(.horizontal, PrismSpacing.sm)
                    .frame(minHeight: PrismSize.minTouch)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PrismSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(PrismColor.surfaceArtifact)
        )
        .accessibilityRotor(Text(verbatim: "Lignes")) {
            ForEach(displayedLines) { line in
                AccessibilityRotorEntry(
                    Text(verbatim: "Ligne \(line.lineNumber) : \(line.text)"),
                    id: line.id
                )
            }
        }
    }

    @ViewBuilder
    private func linesListView(_ displayedLines: [PrismArtifactLine]) -> some View {
        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
            ForEach(displayedLines) { line in
                let isSelected = selectedLineNumbers.contains(line.lineNumber)
                Button {
                    guard document.spotTheIssueInteractive else { return }
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        selectedLineNumbers = PrismArtifactDocument.toggleLineSelection(
                            lineNumber: line.lineNumber,
                            in: selectedLineNumbers,
                            allowsMultipleSelection: allowsMultipleSelection
                        )
                    }
                } label: {
                    HStack(alignment: .top, spacing: PrismSpacing.sm) {
                        Text(verbatim: line.formattedLineNumber)
                            .prismTextStyle(.codeSmall)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        if line.spans.isEmpty {
                            Text(verbatim: line.text)
                                .prismTextStyle(.codeSmall)
                                .foregroundStyle(line.syntax.color)
                                .fixedSize(horizontal: !wrapsLines, vertical: true)
                        } else {
                            HStack(spacing: PrismSpacing.xs) {
                                ForEach(line.spans) { span in
                                    Text(verbatim: span.text)
                                        .prismTextStyle(.codeSmall)
                                        .foregroundStyle(span.syntax.color)
                                }
                            }
                        }

                        Spacer(minLength: PrismSpacing.xs)

                        if isSelected {
                            HStack(spacing: PrismSpacing.xs) {
                                Image(systemName: "flag.fill")
                                Text(verbatim: "Sélectionnée")
                                    .prismTextStyle(PrismLearningStyleResolver.caption)
                            }
                            .foregroundStyle(line.syntax.color)
                        }
                    }
                    .padding(.horizontal, PrismSpacing.sm)
                    .padding(.vertical, PrismSpacing.xs)
                    .frame(minHeight: PrismSize.minTouch, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.sm)
                            .fill(isSelected ? AnyShapeStyle(PrismSyntax.flaggedLineBackground) : AnyShapeStyle(.clear))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    Text(verbatim: "Ligne \(line.lineNumber), \(isSelected ? "sélectionnée, " : "")\(line.text)")
                )
                .accessibilityAction(named: Text(verbatim: "Sélectionner cette ligne")) {
                    selectedLineNumbers = PrismArtifactDocument.toggleLineSelection(
                        lineNumber: line.lineNumber,
                        in: selectedLineNumbers,
                        allowsMultipleSelection: allowsMultipleSelection
                    )
                }
            }
        }
    }
}

// MARK: - 8. ChoiceList View

public struct ChoiceList: View {
    public let options: [PrismChoiceOption]
    @Binding public var selectedOptionIds: Set<String>
    public let allowsMultipleSelection: Bool
    public let isRevealed: Bool

    @State private var showsAllExplanations: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        options: [PrismChoiceOption],
        selectedOptionIds: Binding<Set<String>>,
        allowsMultipleSelection: Bool = false,
        isRevealed: Bool = false
    ) {
        self.options = options
        self._selectedOptionIds = selectedOptionIds
        self.allowsMultipleSelection = allowsMultipleSelection
        self.isRevealed = isRevealed
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            ForEach(options) { option in
                let isSelected = selectedOptionIds.contains(option.id)
                let state = option.visualState(isSelected: isSelected, isRevealed: isRevealed)
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Button {
                        guard !isRevealed else { return }
                        withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                            selectedOptionIds = PrismChoiceOption.updatedSelection(
                                tapping: option.id,
                                currentSelection: selectedOptionIds,
                                allowsMultipleSelection: allowsMultipleSelection
                            )
                        }
                    } label: {
                        HStack(alignment: .center, spacing: PrismSpacing.sm) {
                            Text(verbatim: option.badge)
                                .prismTextStyle(.codeSmall)
                                .padding(PrismSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.sm)
                                        .fill(PrismColor.surfaceArtifact)
                                )

                            Text(verbatim: option.text)
                                .prismTextStyle(PrismLearningStyleResolver.body)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: PrismSpacing.xs)

                            HStack(spacing: PrismSpacing.xs) {
                                Image(systemName: state.symbolName)
                                Text(verbatim: state.statusWord)
                                    .prismTextStyle(PrismLearningStyleResolver.caption)
                            }
                            .foregroundStyle(color(for: state))
                        }
                        .padding(PrismSpacing.md)
                        .frame(minHeight: PrismSize.minTouch)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.md)
                                .fill(isSelected ? AnyShapeStyle(PrismSyntax.flaggedLineBackground) : AnyShapeStyle(.thinMaterial))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.md)
                                .strokeBorder(color(for: state))
                        )
                    }
                    .buttonStyle(.plain)

                    if isRevealed && (isSelected || showsAllExplanations) && !option.explanation.isEmpty {
                        Text(verbatim: option.explanation)
                            .prismTextStyle(PrismLearningStyleResolver.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, PrismSpacing.md)
                            .padding(.bottom, PrismSpacing.xs)
                    }
                }
            }

            if isRevealed && options.count > 1 {
                Button {
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        showsAllExplanations.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: showsAllExplanations ? "chevron.up" : "chevron.down")
                        Text(
                            verbatim: showsAllExplanations
                                ? "Masquer les autres explications"
                                : "Voir les explications de toutes les options"
                        )
                        .prismTextStyle(PrismLearningStyleResolver.caption)
                    }
                    .padding(.horizontal, PrismSpacing.sm)
                    .frame(minHeight: PrismSize.minTouch)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func color(for state: PrismChoiceVisualState) -> Color {
        switch state {
        case .neutral:
            return PrismLearningPaletteResolver.secondaryAccentColor.opacity(0.35)
        case .selected:
            return PrismLearningPaletteResolver.accentColor
        case .correctSelected, .correctUnselected:
            return PrismLearningPaletteResolver.syntaxColor(at: 0)
        case .incorrectSelected:
            return PrismLearningPaletteResolver.syntaxColor(at: 1)
        }
    }
}

// MARK: - 9. ConfidencePicker View

public struct ConfidencePicker: View {
    @Binding public var selectedLevel: PrismConfidenceLevel?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(selectedLevel: Binding<PrismConfidenceLevel?>) {
        self._selectedLevel = selectedLevel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
            Text(verbatim: "Degré de certitude (optionnel)")
                .prismTextStyle(PrismLearningStyleResolver.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: PrismSpacing.sm) {
                ForEach(PrismConfidenceLevel.allCases) { level in
                    let isSelected = selectedLevel == level
                    Button {
                        withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                            selectedLevel = isSelected ? nil : level
                        }
                    } label: {
                        HStack(spacing: PrismSpacing.xs) {
                            Image(systemName: level.symbolName)
                            Text(verbatim: level.title)
                                .prismTextStyle(PrismLearningStyleResolver.caption)
                        }
                        .padding(.horizontal, PrismSpacing.sm)
                        .frame(maxWidth: .infinity, minHeight: PrismSize.minTouch)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.md)
                                .fill(isSelected ? AnyShapeStyle(PrismSyntax.flaggedLineBackground) : AnyShapeStyle(.thinMaterial))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.md)
                                .strokeBorder(
                                    isSelected
                                        ? PrismLearningPaletteResolver.accentColor
                                        : PrismLearningPaletteResolver.secondaryAccentColor.opacity(0.25)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }
}

// MARK: - 10. TokenComposer View

public struct TokenComposer: View {
    @Binding public var state: PrismTokenComposerState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: Binding<PrismTokenComposerState>) {
        self._state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            Text(verbatim: "Commande assemblée")
                .prismTextStyle(PrismLearningStyleResolver.subheadline)

            VStack(alignment: .leading, spacing: PrismSpacing.sm) {
                if state.selectedTokens.isEmpty {
                    Text(verbatim: "Touchez un jeton ci-dessous pour assembler la commande…")
                        .prismTextStyle(.codeSmall)
                        .foregroundStyle(.secondary)
                } else {
                    Text(verbatim: state.composedCommand)
                        .prismTextStyle(.codeSmall)
                        .foregroundStyle(PrismLearningPaletteResolver.accentColor)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PrismSpacing.xs) {
                            ForEach(state.selectedTokens) { token in
                                Button {
                                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                                        state.removeToken(id: token.id)
                                    }
                                } label: {
                                    HStack(spacing: PrismSpacing.xs) {
                                        Text(verbatim: token.text)
                                            .prismTextStyle(.codeSmall)
                                            .foregroundStyle(token.syntax.color)
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, PrismSpacing.sm)
                                    .frame(minHeight: PrismSize.minTouch)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.sm)
                                            .fill(PrismSyntax.flaggedLineBackground)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(verbatim: "Retirer le jeton \(token.text)"))
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.md)
                    .fill(PrismColor.surfaceArtifact)
            )

            Text(verbatim: "Jetons disponibles")
                .prismTextStyle(PrismLearningStyleResolver.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.xs) {
                    ForEach(state.remainingTokens) { token in
                        Button {
                            withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                                state.selectToken(token)
                            }
                        } label: {
                            HStack(spacing: PrismSpacing.xs) {
                                Image(systemName: "plus.circle")
                                Text(verbatim: token.text)
                                    .prismTextStyle(.codeSmall)
                                    .foregroundStyle(token.syntax.color)
                            }
                            .padding(.horizontal, PrismSpacing.sm)
                            .frame(minHeight: PrismSize.minTouch)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.sm)
                                    .fill(PrismColor.surfaceArtifact)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "Ajouter le jeton \(token.text)"))
                    }
                }
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 11. OrderList View

public struct OrderList: View {
    @Binding public var items: [PrismOrderItem]
    public let allowsIndentation: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        items: Binding<[PrismOrderItem]>,
        allowsIndentation: Bool = false
    ) {
        self._items = items
        self.allowsIndentation = allowsIndentation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: PrismSpacing.sm) {
                    Text(verbatim: "\(index + 1).")
                        .prismTextStyle(.codeSmall)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    if item.indentLevel > 0 {
                        Text(verbatim: String(repeating: "⇥ ", count: item.indentLevel))
                            .prismTextStyle(.codeSmall)
                            .foregroundStyle(PrismLearningPaletteResolver.accentColor)
                    }

                    Text(verbatim: item.text)
                        .prismTextStyle(PrismLearningStyleResolver.body)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: PrismSpacing.xs) {
                        Button {
                            withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                                items = PrismOrderItem.moveUp(items, at: index)
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)
                        .accessibilityLabel(Text(verbatim: "Monter \(item.text)"))

                        Button {
                            withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                                items = PrismOrderItem.moveDown(items, at: index)
                            }
                        } label: {
                            Image(systemName: "arrow.down")
                                .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                        }
                        .buttonStyle(.plain)
                        .disabled(index == items.count - 1)
                        .accessibilityLabel(Text(verbatim: "Descendre \(item.text)"))

                        if allowsIndentation {
                            Button {
                                withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                                    items = PrismOrderItem.adjustIndent(items, at: index, delta: 1)
                                }
                            } label: {
                                Image(systemName: "increase.indent")
                                    .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: "Indenter \(item.text)"))
                        }
                    }
                }
                .padding(.horizontal, PrismSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .fill(.thinMaterial)
                )
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text(verbatim: "Monter")) {
                    items = PrismOrderItem.moveUp(items, at: index)
                }
                .accessibilityAction(named: Text(verbatim: "Descendre")) {
                    items = PrismOrderItem.moveDown(items, at: index)
                }
            }
        }
    }
}

// MARK: - 12. SlotBoard View

public struct SlotBoard: View {
    @Binding public var state: PrismSlotBoardState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: Binding<PrismSlotBoardState>) {
        self._state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            Text(verbatim: "1. Touchez un élément source")
                .prismTextStyle(PrismLearningStyleResolver.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.sm) {
                    ForEach(state.unassignedItems) { item in
                        let isSelected = state.selectedSourceItemId == item.id
                        Button {
                            withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                                state.tapSourceItem(item.id)
                            }
                        } label: {
                            HStack(spacing: PrismSpacing.xs) {
                                Image(systemName: isSelected ? "hand.tap.fill" : "cube.box")
                                Text(verbatim: item.label)
                                    .prismTextStyle(PrismLearningStyleResolver.body)
                            }
                            .padding(.horizontal, PrismSpacing.md)
                            .frame(minHeight: PrismSize.minTouch)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.md)
                                    .fill(isSelected ? AnyShapeStyle(PrismSyntax.flaggedLineBackground) : AnyShapeStyle(.thinMaterial))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(verbatim: "2. Touchez la cible correspondante")
                .prismTextStyle(PrismLearningStyleResolver.caption)
                .foregroundStyle(.secondary)

            ForEach(state.targets) { target in
                let assigned = state.assignedItem(for: target.id)
                Button {
                    withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                        state.tapTargetSlot(target.id)
                    }
                } label: {
                    HStack(spacing: PrismSpacing.sm) {
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            Text(verbatim: target.title)
                                .prismTextStyle(PrismLearningStyleResolver.subheadline)
                            if let subtitle = target.subtitle {
                                Text(verbatim: subtitle)
                                    .prismTextStyle(PrismLearningStyleResolver.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer(minLength: PrismSpacing.xs)

                        if let assigned {
                            HStack(spacing: PrismSpacing.xs) {
                                Text(verbatim: assigned.label)
                                    .prismTextStyle(.codeSmall)
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, PrismSpacing.sm)
                            .padding(.vertical, PrismSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.sm)
                                    .fill(PrismSyntax.flaggedLineBackground)
                            )
                        } else {
                            Text(verbatim: "Emplacement libre")
                                .prismTextStyle(PrismLearningStyleResolver.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(PrismSpacing.md)
                    .frame(minHeight: PrismSize.minTouch)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.md)
                            .fill(.thinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 13. EstimateSlider View

public struct EstimateSlider: View {
    public let spec: PrismEstimateSpec
    @Binding public var value: Double

    public init(spec: PrismEstimateSpec, value: Binding<Double>) {
        self.spec = spec
        self._value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            HStack {
                Text(verbatim: spec.title)
                    .prismTextStyle(PrismLearningStyleResolver.subheadline)
                Spacer(minLength: PrismSpacing.xs)
                Text(verbatim: spec.formattedValue(value))
                    .prismTextStyle(.codeSmall)
                    .monospacedDigit()
            }

            HStack(spacing: PrismSpacing.sm) {
                Button {
                    value = spec.decremented(value)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: "Diminuer \(spec.title)"))

                Slider(
                    value: $value,
                    in: spec.minimumValue...spec.maximumValue,
                    step: spec.step
                )
                .tint(PrismLearningPaletteResolver.accentColor)

                Button {
                    value = spec.incremented(value)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: "Augmenter \(spec.title)"))
            }

            HStack {
                Text(verbatim: spec.formattedValue(spec.minimumValue))
                    .prismTextStyle(PrismLearningStyleResolver.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: PrismSpacing.xs)
                Text(verbatim: spec.formattedValue(spec.maximumValue))
                    .prismTextStyle(PrismLearningStyleResolver.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 14. ExplainInput View

public struct ExplainInput: View {
    public let spec: PrismExplainPromptSpec
    @Binding public var text: String
    public let isDictating: Bool
    public let onToggleDictation: (() -> Void)?

    public init(
        spec: PrismExplainPromptSpec,
        text: Binding<String>,
        isDictating: Bool = false,
        onToggleDictation: (() -> Void)? = nil
    ) {
        self.spec = spec
        self._text = text
        self.isDictating = isDictating
        self.onToggleDictation = onToggleDictation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            Text(verbatim: spec.prompt)
                .prismTextStyle(PrismLearningStyleResolver.subheadline)

            TextField(text: $text, axis: .vertical) {
                Text(verbatim: spec.placeholder)
            }
            .prismTextStyle(PrismLearningStyleResolver.body)
            .padding(PrismSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.md)
                    .fill(.thinMaterial)
            )

            HStack(spacing: PrismSpacing.sm) {
                Text(verbatim: spec.counterDescription(for: text))
                    .prismTextStyle(.codeSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Spacer(minLength: PrismSpacing.xs)

                if let onToggleDictation {
                    Button(action: onToggleDictation) {
                        HStack(spacing: PrismSpacing.xs) {
                            Image(systemName: isDictating ? "mic.fill" : "mic")
                            Text(verbatim: isDictating ? "Arrêter la dictée" : "Dicter")
                                .prismTextStyle(PrismLearningStyleResolver.caption)
                        }
                        .padding(.horizontal, PrismSpacing.sm)
                        .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.md)
                                .fill(isDictating ? AnyShapeStyle(PrismSyntax.flaggedLineBackground) : AnyShapeStyle(.thinMaterial))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 15. FeedbackPanel View

public struct FeedbackPanel: View {
    public let state: PrismFeedbackState
    public let onExplainDifferently: (() -> Void)?

    public init(
        state: PrismFeedbackState,
        onExplainDifferently: (() -> Void)? = nil
    ) {
        self.state = state
        self.onExplainDifferently = onExplainDifferently
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            HStack(spacing: PrismSpacing.sm) {
                Image(systemName: state.variant.symbolName)
                    .foregroundStyle(PrismLearningPaletteResolver.accentColor)
                Text(verbatim: state.variant.statusTitle)
                    .prismTextStyle(PrismLearningStyleResolver.caption)
                    .foregroundStyle(.secondary)
            }

            Text(verbatim: state.headline)
                .prismTextStyle(PrismLearningStyleResolver.headline)

            if let misconceptionTitle = state.misconceptionTitle, !misconceptionTitle.isEmpty {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: "lightbulb.exclamationmark.fill")
                            .foregroundStyle(PrismLearningPaletteResolver.secondaryAccentColor)
                        Text(verbatim: "Fausse idée fréquente : \(misconceptionTitle)")
                            .prismTextStyle(PrismLearningStyleResolver.subheadline)
                    }
                    if let correction = state.misconceptionCorrection, !correction.isEmpty {
                        Text(verbatim: correction)
                            .prismTextStyle(PrismLearningStyleResolver.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(PrismSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .fill(PrismSyntax.flaggedLineBackground)
                )
            }

            Text(verbatim: state.resolvedExplanation)
                .prismTextStyle(PrismLearningStyleResolver.body)
                .fixedSize(horizontal: false, vertical: true)

            if state.showsExplainDifferentlyButton, let onExplainDifferently {
                Button(action: onExplainDifferently) {
                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: "sparkles")
                        Text(verbatim: "Expliquer autrement")
                            .prismTextStyle(PrismLearningStyleResolver.caption)
                    }
                    .padding(.horizontal, PrismSpacing.md)
                    .frame(minWidth: PrismSize.minTouch, minHeight: PrismSize.minTouch)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.md)
                            .fill(.thinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PrismSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 16. ResponsibilityMatrix View

public struct ResponsibilityMatrix: View {
    public let title: String
    public let entries: [ResponsibilityEntry]

    public init(
        title: String = "Qui gère quoi ?",
        entries: [ResponsibilityEntry]
    ) {
        self.title = title
        self.entries = entries
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            Text(verbatim: title)
                .prismTextStyle(PrismLearningStyleResolver.headline)

            ForEach(entries) { entry in
                HStack(alignment: .center, spacing: PrismSpacing.sm) {
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: entry.layerName)
                            .prismTextStyle(PrismLearningStyleResolver.body)
                        Text(verbatim: entry.serviceModel)
                            .prismTextStyle(.codeSmall)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: PrismSpacing.xs)

                    HStack(spacing: PrismSpacing.xs) {
                        Image(systemName: entry.owner.symbolName)
                        Text(verbatim: entry.owner.label)
                            .prismTextStyle(PrismLearningStyleResolver.caption)
                    }
                    .padding(.horizontal, PrismSpacing.sm)
                    .padding(.vertical, PrismSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.sm)
                            .fill(PrismSyntax.flaggedLineBackground)
                    )
                }
                .padding(PrismSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .fill(.thinMaterial)
                )
                .accessibilityElement(children: .combine)
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 17. TakeawayLine View

public struct TakeawayLine: View {
    public let spec: PrismTakeawaySpec

    public init(spec: PrismTakeawaySpec) {
        self.spec = spec
    }

    public init(
        title: String = "À retenir",
        sentence: String,
        region: PrismRegion = PrismRegion.allCases.first!
    ) {
        self.spec = PrismTakeawaySpec(title: title, sentence: sentence, region: region)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: PrismSpacing.sm) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(spec.region.color)

            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                Text(verbatim: spec.title)
                    .prismTextStyle(PrismLearningStyleResolver.caption)
                    .foregroundStyle(spec.region.color)
                Text(verbatim: spec.sentence)
                    .prismTextStyle(PrismLearningStyleResolver.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PrismSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .strokeBorder(spec.region.color)
        )
    }
}

// MARK: - 18. HintLadderView

public struct HintLadderView: View {
    @Binding public var ladder: PrismHintLadder

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(ladder: Binding<PrismHintLadder>) {
        self._ladder = ladder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            HStack {
                Text(verbatim: "Indices progressifs (\(ladder.unlockedLevel)/\(PrismHintLadder.maxLevel))")
                    .prismTextStyle(PrismLearningStyleResolver.subheadline)
                Spacer(minLength: PrismSpacing.xs)
                if ladder.canUnlockNext {
                    Button {
                        withAnimation(PrismLearningMotionResolver.animation(reduceMotion: reduceMotion)) {
                            ladder.unlockNextLevel()
                        }
                    } label: {
                        HStack(spacing: PrismSpacing.xs) {
                            Image(systemName: "key.fill")
                            Text(verbatim: "Débloquer l'indice \(ladder.unlockedLevel + 1)")
                                .prismTextStyle(PrismLearningStyleResolver.caption)
                        }
                        .padding(.horizontal, PrismSpacing.sm)
                        .frame(minHeight: PrismSize.minTouch)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.sm)
                                .fill(PrismSyntax.flaggedLineBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !ladder.hasAttemptedQuestion {
                Text(verbatim: "Effectuez une première tentative pour débloquer les indices gradués.")
                    .prismTextStyle(PrismLearningStyleResolver.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(ladder.steps) { step in
                let unlocked = ladder.isUnlocked(step)
                HStack(alignment: .top, spacing: PrismSpacing.sm) {
                    Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                        .foregroundStyle(
                            unlocked
                                ? PrismLearningPaletteResolver.accentColor
                                : PrismLearningPaletteResolver.secondaryAccentColor
                        )
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: "Niveau \(step.level) • \(step.title)")
                            .prismTextStyle(PrismLearningStyleResolver.caption)
                        Text(
                            verbatim: unlocked
                                ? step.hintText
                                : "Indice verrouillé jusqu'au palier \(step.level)."
                        )
                        .prismTextStyle(PrismLearningStyleResolver.body)
                        .foregroundStyle(unlocked ? .primary : .secondary)
                    }
                }
                .padding(PrismSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.md)
                        .fill(.thinMaterial)
                )
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 19. Previews (Nominal, Vide, Chargement, Erreur, AX3, Sombre)

private struct PrismLearningPreviewGallery: View {
    @State private var length: PrismSessionLength = .standard
    @State private var revealed: Bool = true
    @State private var selectedLines: Set<Int> = [2]
    @State private var selectedChoices: Set<String> = ["opt-a"]
    @State private var confidence: PrismConfidenceLevel? = nil
    @State private var composerState = PrismTokenComposerState(
        availableTokens: [
            PrismCommandToken(id: "t1", text: "az"),
            PrismCommandToken(id: "t2", text: "group"),
            PrismCommandToken(id: "t3", text: "create"),
            PrismCommandToken(id: "t4", text: "--name rg-prod")
        ],
        selectedTokens: [
            PrismCommandToken(id: "t1", text: "az"),
            PrismCommandToken(id: "t2", text: "group")
        ]
    )
    @State private var orderItems: [PrismOrderItem] = [
        PrismOrderItem(id: "o1", text: "Créer le groupe de ressources"),
        PrismOrderItem(id: "o2", text: "Déployer le réseau virtuel", indentLevel: 1)
    ]
    @State private var slotState = PrismSlotBoardState(
        items: [PrismSlotItem(id: "i1", label: "Entra ID")],
        targets: [PrismSlotTarget(id: "s1", title: "Identité et accès")]
    )
    @State private var sliderValue: Double = 99.9
    @State private var explainText: String = "Le modèle partagé délègue l'infrastructure physique au cloud."
    @State private var hintLadder = PrismHintLadder(
        steps: [
            HintStep(id: "h1", level: 1, title: "Indice conceptuel", hintText: "Observez la couche physique."),
            HintStep(id: "h2", level: 2, title: "Indice architectural", hintText: "Comparez IaaS et PaaS."),
            HintStep(id: "h3", level: 3, title: "Exclusion", hintText: "Le client garde toujours la donnée."),
            HintStep(id: "h4", level: 4, title: "Règle complète", hintText: "En SaaS, seuls les comptes et données restent au client.")
        ],
        unlockedLevel: 2,
        hasAttemptedQuestion: true
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.md) {
                SessionProgressHeader(currentIndex: 3, totalCount: 8, stepTitle: "Responsabilité partagée") {}
                SessionLengthPicker(selectedLength: $length, suggestedLength: .standard)
                QuestionCard(
                    spec: PrismQuestionSpec(
                        prompt: "Quelle couche reste toujours sous la responsabilité du client ?",
                        situationContext: "Migration d'une application critique vers un service SaaS.",
                        domainLabel: "AZ-900 • Sécurité",
                        revealOptionsDelayMs: 1200
                    ),
                    areOptionsRevealed: $revealed
                )
                ArtifactView(
                    document: PrismArtifactDocument(
                        title: "policy.json",
                        language: "json",
                        lines: [
                            PrismArtifactLine(lineNumber: 1, text: "{"),
                            PrismArtifactLine(lineNumber: 2, text: "  \"effect\": \"AllowPublicBlob\""),
                            PrismArtifactLine(lineNumber: 3, text: "}")
                        ]
                    ),
                    selectedLineNumbers: $selectedLines
                )
                ChoiceList(
                    options: [
                        PrismChoiceOption(
                            id: "opt-a",
                            badge: "A",
                            text: "Les données et les identités",
                            explanation: "Le client reste toujours responsable de ses données et accès.",
                            isCorrect: true
                        ),
                        PrismChoiceOption(
                            id: "opt-b",
                            badge: "B",
                            text: "Le câblage physique du datacenter",
                            explanation: "Le fournisseur gère intégralement les datacenters.",
                            isCorrect: false
                        )
                    ],
                    selectedOptionIds: $selectedChoices,
                    isRevealed: true
                )
                ConfidencePicker(selectedLevel: $confidence)
                TokenComposer(state: $composerState)
                OrderList(items: $orderItems, allowsIndentation: true)
                SlotBoard(state: $slotState)
                EstimateSlider(
                    spec: PrismEstimateSpec(title: "SLA composite", unit: "%", minimumValue: 95, maximumValue: 100, step: 0.5),
                    value: $sliderValue
                )
                ExplainInput(
                    spec: PrismExplainPromptSpec(prompt: "Synthétisez la règle de responsabilité :"),
                    text: $explainText
                )
                FeedbackPanel(
                    state: PrismFeedbackState(
                        variant: .confidentError,
                        headline: "Attention au piège d'automatisation",
                        chosenOptionExplanation: "Même en SaaS, le fournisseur ne décide jamais qui a accès à vos données.",
                        misconceptionTitle: "« Le cloud sécurise aussi mes comptes »",
                        misconceptionCorrection: "La gouvernance des identités appartient toujours au client."
                    )
                )
                DiagramView(
                    spec: DiagramSpec(
                        title: "Flux d'accès sécurisé",
                        nodes: [
                            DiagramNode(id: "n1", label: "Entra ID", productId: "entra-id", groupId: "g1"),
                            DiagramNode(id: "n2", label: "Key Vault", productId: "key-vault", groupId: "g1")
                        ],
                        edges: [
                            DiagramEdge(id: "e1", fromNodeId: "n1", toNodeId: "n2", label: "RBAC")
                        ],
                        groups: [
                            DiagramGroup(id: "g1", label: "Souscription Production", nodeIds: ["n1", "n2"])
                        ],
                        accessibleSummary: "Entra ID autorise l'accès RBAC vers Key Vault dans la souscription Production"
                    )
                )
                WorkedExampleView(
                    example: PrismWorkedExample(
                        title: "Calculer un SLA composite",
                        problemContext: "Deux services en série à 99,9 %.",
                        steps: [
                            PrismWorkedStep(id: "s1", stepNumber: 1, subgoalTitle: "Multiplier les disponibilités", detail: "0,999 × 0,999 = 0,998001", formulaOrCommand: "99,80 %")
                        ],
                        conclusion: "Le SLA combiné en série est toujours inférieur au maillon le plus faible."
                    )
                )
                ExplanationCard(
                    spec: PrismExplanationSpec(
                        title: "Modèle de responsabilité partagée",
                        body: "Le transfert vers le cloud déplace la charge opérationnelle physique mais jamais la propriété des données.",
                        keyPoints: ["Données et identités : toujours Client", "Physique : toujours Fournisseur Cloud"],
                        verifiedSources: [PrismVerifiedSource(id: "src1", title: "Microsoft Learn — Responsabilité partagée", referenceCode: "AZ-900-1.2")]
                    )
                )
                ResponsibilityMatrix(
                    entries: [
                        ResponsibilityEntry(id: "r1", layerName: "Données & Identités", serviceModel: "SaaS / PaaS / IaaS", owner: .customer),
                        ResponsibilityEntry(id: "r2", layerName: "Contrôles réseau", serviceModel: "PaaS", owner: .shared),
                        ResponsibilityEntry(id: "r3", layerName: "Datacenter physique", serviceModel: "Tous modèles", owner: .cloudProvider)
                    ]
                )
                TakeawayLine(sentence: "Le client conserve toujours la responsabilité des données, des terminaux et des comptes.")
                HintLadderView(ladder: $hintLadder)
            }
            .padding(PrismSpacing.md)
        }
    }
}

#Preview("Prism Learning — Nominal") {
    PrismLearningPreviewGallery()
}

#Preview("Prism Learning — Vide") {
    VStack(spacing: PrismSpacing.md) {
        SessionProgressHeader(currentIndex: 0, totalCount: 0, stepTitle: "Aucune étape active") {}
        ResponsibilityMatrix(entries: [])
        TakeawayLine(sentence: "Aucun point clé enregistré pour le moment.")
    }
    .padding(PrismSpacing.md)
}

#Preview("Prism Learning — Chargement") {
    VStack(spacing: PrismSpacing.md) {
        SessionProgressHeader(currentIndex: 1, totalCount: 10, stepTitle: "Préparation de l'exercice…") {}
        QuestionCard(
            spec: PrismQuestionSpec(
                prompt: "Chargement du scénario d'architecture…",
                revealOptionsDelayMs: 5000
            ),
            areOptionsRevealed: .constant(false)
        )
    }
    .padding(PrismSpacing.md)
}

#Preview("Prism Learning — Erreur & Repli IA") {
    VStack(spacing: PrismSpacing.md) {
        FeedbackPanel(
            state: PrismFeedbackState(
                variant: .aiUnavailable,
                headline: "Explication de référence",
                chosenOptionExplanation: "",
                authorExplanation: "Explication vérifiée par l'auteur : le verrou ReadOnly empêche toute suppression accidentelle du groupe de ressources.",
                canExplainDifferently: false
            )
        )
    }
    .padding(PrismSpacing.md)
}

#Preview("Prism Learning — Accessibilité AX3") {
    PrismLearningPreviewGallery()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Prism Learning — Sombre") {
    PrismLearningPreviewGallery()
        .preferredColorScheme(.dark)
}
#endif
