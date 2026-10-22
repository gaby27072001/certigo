import Foundation

// A demo-only state machine: no API identity, scoring, answer keys, rewards or production progress.
struct NativeDemoFlow: Codable, Equatable {
    enum Objective: String, Codable, CaseIterable {
        case fundamentals = "Cloud · découverte"
        case operations = "Cloud · exploitation"

        var title: String {
            switch self {
            case .fundamentals: "Les fondamentaux du cloud"
            case .operations: "Les services cloud au quotidien"
            }
        }
        var symbol: String {
            switch self {
            case .fundamentals: "cloud"
            case .operations: "server.rack"
            }
        }
        var practice: NativeDemoPractice {
            switch self {
            case .fundamentals: .fundamentals
            case .operations: .operations
            }
        }
    }
    enum Phase: String, Codable {
        case answering, pending, reviewed
        var symbol: String {
            switch self {
            case .answering: "circle"
            case .pending: "clock"
            case .reviewed: "text.bubble"
            }
        }
    }
    enum InvalidSnapshot: Error { case inconsistentState }
    static let options = [
        "Une infrastructure à administrer (IaaS)",
        "Une plateforme gérée (PaaS)", "Un logiciel prêt à l’emploi (SaaS)",
    ]
    private(set) var objective: Objective?
    private(set) var selection: Int?
    private(set) var phase = Phase.answering

    var canSubmit: Bool { objective != nil && selection != nil && phase == .answering }
    var practice: NativeDemoPractice? { objective?.practice }
    var startRoute: NativeDemoRoute {
        phase == .answering && selection == nil ? .preparation : .exercise
    }
    mutating func choose(_ objective: Objective) {
        guard self.objective != objective else { return }
        self.objective = objective
        restartQuestion()
    }
    mutating func select(_ index: Int) {
        guard objective != nil, phase == .answering, Self.options.indices.contains(index) else {
            return
        }
        selection = index
    }
    mutating func submit() {
        guard canSubmit else { return }
        phase = .pending
    }
    mutating func receiveMockExplanation(offline: Bool) {
        guard phase == .pending, !offline else { return }
        phase = .reviewed
    }
    mutating func restartQuestion() {
        selection = nil
        phase = .answering
    }
    static func restore(_ data: Data) throws -> Self {
        let flow = try JSONDecoder().decode(Self.self, from: data)
        guard flow.selection.map({ options.indices.contains($0) }) ?? true,
            flow.objective != nil || (flow.selection == nil && flow.phase == .answering),
            flow.phase == .answering || flow.selection != nil
        else {
            throw InvalidSnapshot.inconsistentState
        }
        return flow
    }
}

enum NativeDemoPracticeStage: Hashable, CaseIterable {
    case situation, decision, explanation

    var position: Int {
        switch self {
        case .situation: 1
        case .decision: 2
        case .explanation: 3
        }
    }
}

enum NativeDemoPracticeStepState: Equatable {
    case completed, current, upcoming

    var symbol: String {
        switch self {
        case .completed: "circle.fill"
        case .current: "circle.inset.filled"
        case .upcoming: "circle"
        }
    }
}

struct NativeDemoPracticeProgress {
    let current: NativeDemoPracticeStage

    func state(for stage: NativeDemoPracticeStage) -> NativeDemoPracticeStepState {
        if stage == current { return .current }
        return stage.position < current.position ? .completed : .upcoming
    }

}

struct NativeDemoPractice: Sendable {
    struct Responsibility: Sendable {
        let layer: String
        let owner: String
    }
    let title: String
    let intent: String
    let situation: String
    let question: String
    let constraint: String
    let explanation: String
    let takeaway: String
    let responsibilities: [Responsibility]

    static let fundamentals = Self(
        title: "Déployer sans gérer les serveurs",
        intent: "Distinguer une plateforme gérée d’une infrastructure à administrer.",
        situation:
            "L’équipe Exemple veut déployer son application sans administrer le système d’exploitation des serveurs. Elle souhaite garder la responsabilité de son code et de ses données.",
        question: "Quel modèle de service correspond à cette situation fictive ?",
        constraint:
            "L’équipe veut déléguer l’administration du système d’exploitation, pas son application.",
        explanation:
            "Dans cet exemple inventé, une plateforme gérée (PaaS) correspond à cette limite : le fournisseur prend en charge la plateforme et son système. L’équipe déploie son code. Une infrastructure (IaaS) lui laisserait la gestion du système ; un logiciel prêt à l’emploi (SaaS) ne lui fournit pas le même cadre pour déployer son application.",
        takeaway:
            "Le critère utile est la responsabilité conservée par l’équipe, pas seulement la présence de serveurs dans le cloud.",
        responsibilities: [
            .init(layer: "Application et données", owner: "L’équipe Exemple"),
            .init(
                layer: "Plateforme et système d’exploitation",
                owner: "Le fournisseur, dans cet exemple PaaS"),
            .init(layer: "Infrastructure physique", owner: "Le fournisseur"),
        ])

    static let operations = Self(
        title: "Garder la main sur le système",
        intent: "Identifier ce qui reste à administrer dans une infrastructure cloud.",
        situation:
            "L’équipe Atelier exploite une application qui exige une configuration particulière du système d’exploitation. Elle veut installer ses composants système et gérer elle-même les mises à jour, sans entretenir de serveurs physiques.",
        question:
            "Quel modèle de service lui laisse cette responsabilité dans ce scénario fictif ?",
        constraint:
            "L’équipe veut conserver le contrôle du système d’exploitation tout en déléguant le matériel.",
        explanation:
            "Dans cet exemple inventé, une infrastructure à administrer (IaaS) laisse à l’équipe le choix et la gestion du système d’exploitation. Le fournisseur prend en charge le matériel. Une plateforme gérée (PaaS) ou un logiciel prêt à l’emploi (SaaS) ne lui donnent pas cette même responsabilité système.",
        takeaway:
            "Déléguer le matériel ne signifie pas déléguer les mises à jour du système : la frontière dépend du modèle choisi.",
        responsibilities: [
            .init(layer: "Application et données", owner: "L’équipe Atelier"),
            .init(
                layer: "Système d’exploitation et mises à jour",
                owner: "L’équipe Atelier, dans cet exemple IaaS"),
            .init(layer: "Infrastructure physique", owner: "Le fournisseur"),
        ])
}

enum NativeDemoDestination: String, CaseIterable, Hashable {
    case learn, coach, social, profile
}

enum NativeDemoLearnSection: String, Codable {
    case myLearning, explore
}

// Retain version-one storage identifiers; visible destinations use the approved English names.
enum NativeDemoTab: String, Codable, CaseIterable, Hashable {
    case objective, catalog, followUp, coach, social

    var destination: NativeDemoDestination {
        switch self {
        case .objective, .catalog: .learn
        case .followUp: .profile
        case .coach: .coach
        case .social: .social
        }
    }

    static func selecting(
        _ destination: NativeDemoDestination, learnSection: NativeDemoLearnSection
    ) -> Self {
        switch destination {
        case .learn: learnSection == .myLearning ? .objective : .catalog
        case .coach: .coach
        case .social: .social
        case .profile: .followUp
        }
    }
}

enum NativeDemoRoute: Codable, Equatable, Hashable {
    case preparation
    case exercise
    case goalDetail(NativeDemoFlow.Objective)
}

struct NativeDemoNavigationState: Codable, Equatable {
    enum InvalidSnapshot: Error { case tooLarge, inconsistentRoute }
    private static let maximumEncodedBytes = 4_096

    let selectedTab: NativeDemoTab
    let objectivePath: [NativeDemoRoute]
    let catalogPath: [NativeDemoRoute]
    let learnSection: NativeDemoLearnSection

    init(
        selectedTab: NativeDemoTab, objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute], learnSection: NativeDemoLearnSection? = nil
    ) {
        self.selectedTab = selectedTab
        self.objectivePath = objectivePath
        self.catalogPath = catalogPath
        self.learnSection = learnSection ?? (selectedTab == .catalog ? .explore : .myLearning)
    }

    private enum CodingKeys: String, CodingKey {
        case selectedTab, objectivePath, catalogPath, learnSection
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedTab: try values.decode(NativeDemoTab.self, forKey: .selectedTab),
            objectivePath: try values.decode([NativeDemoRoute].self, forKey: .objectivePath),
            catalogPath: try values.decode([NativeDemoRoute].self, forKey: .catalogPath),
            learnSection: try values.decodeIfPresent(
                NativeDemoLearnSection.self, forKey: .learnSection))
    }

    static func make(
        selectedTab: NativeDemoTab,
        objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute],
        flow: NativeDemoFlow,
        learnSection: NativeDemoLearnSection? = nil
    ) throws -> Self {
        let state = Self(
            selectedTab: selectedTab, objectivePath: objectivePath, catalogPath: catalogPath,
            learnSection: learnSection)
        try state.validate(for: flow)
        return state
    }

    static func restore(_ data: Data, for flow: NativeDemoFlow) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw InvalidSnapshot.tooLarge
        }
        let state = try JSONDecoder().decode(Self.self, from: data)
        try state.validate(for: flow)
        return state
    }

    func resumingExercise(for flow: NativeDemoFlow) throws -> Self {
        try Self.make(
            selectedTab: .objective, objectivePath: [.exercise],
            catalogPath: catalogPath, flow: flow)
    }

    private func validate(for flow: NativeDemoFlow) throws {
        let objectiveRoutesAreValid =
            objectivePath.count <= 1
            && objectivePath.allSatisfy { $0 == .exercise || $0 == .preparation }
            && (objectivePath.isEmpty || flow.objective != nil)
        let catalogRoutesAreValid =
            catalogPath.count <= 1
            && catalogPath.allSatisfy {
                if case .goalDetail = $0 { true } else { false }
            }
        let sectionMatchesTab =
            (selectedTab != .objective || learnSection == .myLearning)
            && (selectedTab != .catalog || learnSection == .explore)
        guard objectiveRoutesAreValid, catalogRoutesAreValid, sectionMatchesTab else {
            throw InvalidSnapshot.inconsistentRoute
        }
    }
}

enum NativeDemoPersistence {
    case awaitingRestoration, ready, preservingRejectedSnapshot

    mutating func restore(_ savedState: String) throws -> NativeDemoSnapshot? {
        self = .preservingRejectedSnapshot
        let snapshot =
            savedState.isEmpty ? nil : try NativeDemoSnapshot.restore(Data(savedState.utf8))
        self = .ready
        return snapshot
    }

    func save(_ snapshot: NativeDemoSnapshot, to savedState: inout String) throws {
        guard self == .ready else { return }
        savedState = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
    }

    mutating func reset(_ savedState: inout String) {
        savedState = ""
        self = .ready
    }
}

struct NativeDemoSnapshot: Codable, Equatable {
    enum InvalidSnapshot: Error { case tooLarge, unsupportedSchema }

    private static let maximumEncodedBytes = 8_192
    let schema: Int
    let flow: NativeDemoFlow
    let navigation: NativeDemoNavigationState

    static func make(
        flow: NativeDemoFlow, navigation: NativeDemoNavigationState
    ) throws -> Self {
        let validatedNavigation = try NativeDemoNavigationState.make(
            selectedTab: navigation.selectedTab,
            objectivePath: navigation.objectivePath,
            catalogPath: navigation.catalogPath,
            flow: flow, learnSection: navigation.learnSection)
        return Self(schema: 1, flow: flow, navigation: validatedNavigation)
    }

    static func restore(_ data: Data) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw InvalidSnapshot.tooLarge
        }
        let decoder = JSONDecoder()
        do {
            let snapshot = try decoder.decode(Self.self, from: data)
            guard snapshot.schema == 1 else {
                throw InvalidSnapshot.unsupportedSchema
            }
            return try make(flow: snapshot.flow, navigation: snapshot.navigation)
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "schema" {
            let legacyFlow = try NativeDemoFlow.restore(data)
            let legacyNavigation = try NativeDemoNavigationState.make(
                selectedTab: legacyFlow.objective == nil ? .catalog : .objective,
                objectivePath: [], catalogPath: [], flow: legacyFlow)
            return try make(flow: legacyFlow, navigation: legacyNavigation)
        }
    }
}
