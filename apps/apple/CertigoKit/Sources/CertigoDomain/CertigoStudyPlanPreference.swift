import Foundation

public struct CertigoStudyPlanPreference: Codable, Equatable, Sendable {
    public enum InitialLevel: String, Codable, CaseIterable, Sendable {
        case beginner, intermediate, advanced
    }

    public static let storageKey = "certigo.study-plan.v1"
    public let targetExamDate: Date?
    public let initialLevel: InitialLevel
    public let dailyMinutesGoal: Int

    public init(
        targetExamDate: Date? = nil, initialLevel: InitialLevel = .beginner,
        dailyMinutesGoal: Int = 10
    ) throws {
        guard (1...1_440).contains(dailyMinutesGoal) else {
            throw ContractError.malformed("study plan preference")
        }
        if let targetExamDate, !targetExamDate.timeIntervalSince1970.isFinite {
            throw ContractError.malformed("study plan date")
        }
        self.targetExamDate = targetExamDate
        self.initialLevel = initialLevel
        self.dailyMinutesGoal = dailyMinutesGoal
    }

    public static func load(
        from defaults: UserDefaults = .standard, key: String = storageKey
    ) throws -> Self? {
        guard !key.isEmpty else { throw ContractError.malformed("study plan key") }
        guard let data = defaults.data(forKey: key) else {
            guard defaults.object(forKey: key) == nil else {
                throw ContractError.malformed("study plan storage")
            }
            return nil
        }
        return try JSONDecoder().decode(Self.self, from: data).validated()
    }

    public func save(to defaults: UserDefaults = .standard, key: String = storageKey) throws {
        guard !key.isEmpty else { throw ContractError.malformed("study plan key") }
        _ = try validated()
        defaults.set(try JSONEncoder().encode(self), forKey: key)
    }

    public func validated() throws -> Self {
        try Self(
            targetExamDate: targetExamDate, initialLevel: initialLevel,
            dailyMinutesGoal: dailyMinutesGoal)
    }
}
