import Foundation

enum NativeRadarCategory: String, CaseIterable, Sendable {
    case cloud = "cloud-hyperscalers"
    case ai = "ai-foundation-models"
    case apple = "apple-mobile"
    case data = "data-analytics"
    case devops = "devops-cloud-native-dev"
    case security = "cybersecurity-networking"
    case enterprise = "enterprise-delivery"

    var title: String {
        switch self {
        case .cloud: "Cloud platforms"
        case .ai: "AI & foundation models"
        case .apple: "Apple & mobile"
        case .data: "Data & analytics"
        case .devops: "DevOps & cloud native"
        case .security: "Security & networking"
        case .enterprise: "Enterprise & delivery"
        }
    }

    var band: Int {
        switch self {
        case .cloud: 0
        case .ai: 1
        case .apple: 2
        case .data: 4
        case .devops: 3
        case .security: 5
        case .enterprise: 6
        }
    }
}

enum NativeTrackAppearance {
    struct CodeGroup: Sendable {
        let family: String
        let category: NativeRadarCategory
        let prefixes: [String]
    }

    // Display hints from code namespaces, not authoritative provider/category metadata.
    private static let groups: [CodeGroup] = [
        .init(
            family: "MICROSOFT", category: .cloud,
            prefixes: ["MICROSOFT", "MSFT", "AZ", "AI", "PL", "MS", "DP", "SC"]),
        .init(family: "AWS", category: .cloud, prefixes: ["AWS"]),
        .init(family: "GCP", category: .cloud, prefixes: ["GCP", "GOOGLE-CLOUD"]),
        .init(family: "ORACLE", category: .cloud, prefixes: ["ORACLE", "OCI"]),
        .init(family: "OPENAI", category: .ai, prefixes: ["OPENAI", "OAI"]),
        .init(family: "ANTHROPIC", category: .ai, prefixes: ["ANTHROPIC", "CLAUDE"]),
        .init(family: "MISTRAL", category: .ai, prefixes: ["MISTRAL"]),
        .init(family: "NVIDIA", category: .ai, prefixes: ["NVIDIA", "NV", "DLI"]),
        .init(family: "HF", category: .ai, prefixes: ["HF", "HUGGINGFACE", "HUGGING-FACE"]),
        .init(family: "COHERE", category: .ai, prefixes: ["COHERE"]),
        .init(family: "META", category: .ai, prefixes: ["META"]),
        .init(family: "APPLE", category: .apple, prefixes: ["APPLE"]),
        .init(family: "DATABRICKS", category: .data, prefixes: ["DATABRICKS", "DBX"]),
        .init(family: "SNOWFLAKE", category: .data, prefixes: ["SNOWFLAKE", "SNOW", "SNOWPRO"]),
        .init(family: "MONGODB", category: .data, prefixes: ["MONGODB"]),
        .init(family: "CONFLUENT", category: .data, prefixes: ["CONFLUENT"]),
        .init(family: "DBT", category: .data, prefixes: ["DBT"]),
        .init(
            family: "CNCF", category: .devops,
            prefixes: ["CNCF", "LINUX-FOUNDATION", "LF", "CKA", "CKAD", "CKS"]),
        .init(
            family: "HASHICORP", category: .devops, prefixes: ["HASHICORP", "TERRAFORM", "VAULT"]),
        .init(family: "GITHUB", category: .devops, prefixes: ["GITHUB", "GH"]),
        .init(
            family: "REDHAT", category: .devops,
            prefixes: ["REDHAT", "RED-HAT", "RH", "RHCSA", "RHCE"]),
        .init(family: "DOCKER", category: .devops, prefixes: ["DOCKER"]),
        .init(family: "GITLAB", category: .devops, prefixes: ["GITLAB"]),
        .init(family: "CISCO", category: .security, prefixes: ["CISCO", "CCNA", "CCNP"]),
        .init(family: "COMPTIA", category: .security, prefixes: ["COMPTIA", "SY0", "N10"]),
        .init(family: "ISC2", category: .security, prefixes: ["ISC2", "CISSP"]),
        .init(family: "ISACA", category: .security, prefixes: ["ISACA", "CISM", "CISA"]),
        .init(family: "OFFSEC", category: .security, prefixes: ["OFFSEC", "OSCP"]),
        .init(family: "PALOALTO", category: .security, prefixes: ["PALOALTO", "PALO-ALTO"]),
        .init(family: "CLOUDFLARE", category: .security, prefixes: ["CLOUDFLARE"]),
        .init(family: "SALESFORCE", category: .enterprise, prefixes: ["SALESFORCE", "SF"]),
        .init(family: "SERVICENOW", category: .enterprise, prefixes: ["SERVICENOW", "CSA", "CAD"]),
        .init(family: "SAP", category: .enterprise, prefixes: ["SAP"]),
        .init(family: "ATLASSIAN", category: .enterprise, prefixes: ["ATLASSIAN"]),
        .init(family: "PMI", category: .enterprise, prefixes: ["PMI", "PMP", "PSM"]),
    ]

    static func normalized(_ code: String) -> String {
        code.uppercased().components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: "-")
    }

    static func group(for code: String) -> CodeGroup? {
        let code = normalized(code)
        return groups.first { group in
            group.prefixes.contains { code == $0 || code.hasPrefix($0 + "-") }
        }
    }

    static func band(for code: String) -> Int {
        // Preserve the established Microsoft subject accents.
        switch normalized(code).split(separator: "-").first {
        case "AI": 1
        case "PL": 2
        case "MS": 3
        case "DP": 4
        case "SC": 5
        default: group(for: code)?.category.band ?? 0
        }
    }
}

struct NativeCatalogFilter {
    var query = ""
    var family = ""
    var category: NativeRadarCategory?
    var availableOnly = false

    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !family.isEmpty || category != nil || availableOnly
    }

    static func family(for code: String) -> String {
        let prefix =
            NativeTrackAppearance.normalized(code).split(separator: "-").first
            .map(String.init) ?? ""
        if ["AZ", "AI", "PL", "MS", "DP", "SC"].contains(prefix) { return prefix }
        return NativeTrackAppearance.group(for: code)?.family ?? prefix
    }

    func includes(code: String, title: String, summary: String, available: Bool) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (family.isEmpty || Self.family(for: code) == family)
            && (category == nil || NativeTrackAppearance.group(for: code)?.category == category)
            && (!availableOnly || available)
            && (text.isEmpty
                || [code, title, summary].contains {
                    $0.range(
                        of: text, options: [.caseInsensitive, .diacriticInsensitive],
                        locale: Locale(identifier: "en_US_POSIX")) != nil
                })
    }

    mutating func clear() { self = Self() }
}

enum NativeShowcaseUniverse: String, CaseIterable, Sendable {
    case azure, github, data, aws, security

    func includes(code: String) -> Bool {
        let parts = NativeTrackAppearance.normalized(code).split(separator: "-")
        let family = NativeCatalogFilter.family(for: code)
        switch self {
        case .azure: return parts.contains("AZ") || parts.contains("AI")
        case .github: return parts.contains("GH") || family == "GITHUB"
        case .data: return parts.contains("DP") || parts.contains("FABRIC")
        case .aws: return family == "AWS"
        case .security:
            return NativeTrackAppearance.group(for: code)?.category == .security
                || parts.contains("SC")
                || (NativeTrackAppearance.group(for: code)?.category == .cloud
                    && !Self.azure.includes(code: code)
                    && !Self.github.includes(code: code)
                    && !Self.data.includes(code: code)
                    && !Self.aws.includes(code: code))
        }
    }
}

struct NativePathCoverage {
    let completedActivities: Int
    let totalActivities: Int
    let completedUnits: Int
    let totalUnits: Int
    let lockedActivities: Int

    init(units: [[String]]) {
        func complete(_ status: String) -> Bool {
            status == "completed" || status == "mastered"
        }
        let statuses = units.flatMap { $0 }
        completedActivities = statuses.filter(complete).count
        totalActivities = statuses.count
        completedUnits = units.filter { !$0.isEmpty && $0.allSatisfy(complete) }.count
        totalUnits = units.count
        lockedActivities = statuses.filter { $0 == "locked" }.count
    }

    var remainingActivities: Int { totalActivities - completedActivities }
}

struct NativeActivityDestination {
    let lessonID: String
    let title: String

    var resumeTitle: String { "Resume \(title)" }
    func actionTitle(_ action: String) -> String { "\(action) · \(title)" }
}

enum NativeDeclaredContentLanguage {
    static func badges(_ languages: [String]) -> [String] {
        Set(
            languages.compactMap { value -> String? in
                let language = value.lowercased().replacingOccurrences(of: "_", with: "-")
                if language == "fr" || language.hasPrefix("fr-") { return "FR" }
                if language == "en" || language.hasPrefix("en-") { return "EN" }
                return nil
            }
        ).sorted()
    }
}

enum NativeLearningDuration {
    static func total(_ minutes: [Int]) -> Int? {
        var total = 0
        for value in minutes {
            let addition = total.addingReportingOverflow(value)
            guard value >= 0, !addition.overflow else { return nil }
            total = addition.partialValue
        }
        return total
    }
}

#if canImport(CertigoDomain)
    import CertigoDomain

    extension NativeRadarCategory {
        func title(_ copy: AppInterfaceCopy) -> String {
            switch self {
            case .cloud: copy[.categoryCloud]
            case .ai: copy[.categoryAI]
            case .apple: copy[.categoryApple]
            case .data: copy[.categoryData]
            case .devops: copy[.categoryDevOps]
            case .security: copy[.categoryCyber]
            case .enterprise: copy[.categoryEnterprise]
            }
        }
    }

    extension PathLesson {
        var nativeMasteryStage: MasteryStage {
            switch status {
            case .locked, .available: .notStarted
            case .inProgress: .learning
            case .completed: .practicing
            case .mastered: .mastered
            }
        }
    }

    extension NativeDemoFlow.Objective {
        func displayName(_ copy: AppInterfaceCopy) -> String {
            copy.native(self == .fundamentals ? .demoCloudDiscovery : .demoCloudOperations)
        }

        func displayTitle(_ copy: AppInterfaceCopy) -> String {
            copy.native(self == .fundamentals ? .demoCloudFundamentals : .demoCloudPractice)
        }
    }

    extension NativeDemoFlow {
        func startLabel(_ copy: AppInterfaceCopy) -> String {
            startRoute == .preparation ? copy.native(.demoExploreSituation) : resumeLabel(copy)
        }

        func activitySummary(_ copy: AppInterfaceCopy) -> String {
            switch phase {
            case .answering:
                copy.native(selection == nil ? .demoSituationNoGrade : .demoEditableChoice)
            case .pending: copy.native(.demoAnswerPending)
            case .reviewed: copy.native(.demoExplanationAvailable)
            }
        }

        func resumeLabel(_ copy: AppInterfaceCopy) -> String {
            switch phase {
            case .answering:
                copy.native(selection == nil ? .demoStartQuestion : .demoResumeChoice)
            case .pending: copy.native(.demoResumePending)
            case .reviewed: copy.native(.demoReadExplanation)
            }
        }
    }

    extension NativeDemoPracticeStage {
        func label(_ copy: AppInterfaceCopy) -> String {
            switch self {
            case .situation: copy.native(.demoStageSituation)
            case .decision: copy.native(.demoStageDecision)
            case .explanation: copy.native(.demoStageExplanation)
            }
        }
    }

    extension NativeDemoPracticeProgress {
        func accessibilityLabel(_ copy: AppInterfaceCopy) -> String {
            "\(current.position) / \(NativeDemoPracticeStage.allCases.count) · "
                + "\(current.label(copy)). \(copy.native(.demoStageHint))"
        }
    }


#endif

struct NativeActiveGoalPresentation {
    let targetID: String
    let confirmedID: String?
    let savingID: String?
    let busy: Bool

    var isConfirmed: Bool {
        confirmedID?.lowercased()
            == targetID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isSaving: Bool { savingID == targetID }
    var canChoose: Bool { !busy && savingID == nil && !isConfirmed }
    #if canImport(CertigoDomain)
        func status(_ copy: AppInterfaceCopy) -> String {
            if isSaving { return copy.native(.goalPending) }
            return isConfirmed ? copy.native(.goalConfirmed) : copy.native(.goalViewing)
        }
    #endif
    var symbol: String { isSaving ? "clock" : isConfirmed ? "checkmark.circle" : "eye" }
    #if canImport(CertigoDomain)
        func action(_ copy: AppInterfaceCopy) -> String {
            isSaving ? copy.native(.savingGoal) : copy.native(.chooseGoal)
        }
    #endif
}

struct NativeLearningNavigation {
    enum Tab: String, CaseIterable { case learn, coach, social, profile }
    enum Learn { case myLearning, explore }
    enum Social { case friends, teams }
    var tab: Tab = .learn
    var learn: Learn
    var social: Social = .friends

    init(hasGoal: Bool = false) {
        learn = hasGoal ? .myLearning : .explore
    }

    func showsTrack(_ id: String, activeID: String?, openedID: String?) -> Bool {
        learn == .explore || id.lowercased() == activeID?.lowercased() || id == openedID
    }
}
