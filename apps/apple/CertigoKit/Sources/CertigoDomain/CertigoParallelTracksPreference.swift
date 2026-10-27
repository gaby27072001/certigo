import Foundation

public struct CertigoParallelTracksPreference: Codable, Equatable, Hashable, Sendable {
    public static let storageKey = "certigo.parallel-tracks.v1"
    public static let defaultParallelTrackCodes = ["AZ-104", "SAA-C03", "GH-300"]
    public static let defaultActiveTrackCode = "AZ-104"
    public static let defaultAIFrontierTrackCodes = [
        "AI-OPENAI",
        "AI-CLAUDE",
        "AI-GEMINI",
        "AI-FOUNDRY"
    ]

    public var parallelTrackCodes: [String]
    public var activeTrackCode: String
    public var aiFrontierTrackCodes: [String]
    public var bilingualTechnicalTermsEN: Bool
    public var strictTimed90Min: Bool

    public init(
        parallelTrackCodes: [String] = Self.defaultParallelTrackCodes,
        activeTrackCode: String = Self.defaultActiveTrackCode,
        aiFrontierTrackCodes: [String] = Self.defaultAIFrontierTrackCodes,
        bilingualTechnicalTermsEN: Bool = true,
        strictTimed90Min: Bool = true
    ) {
        let normalizedParallel = Self.normalizedUniqueCodes(parallelTrackCodes)
        let normalizedAI = Self.normalizedUniqueCodes(aiFrontierTrackCodes)
        let candidateActive = Self.normalizedCode(activeTrackCode)

        var resolvedParallel = normalizedParallel.isEmpty
            ? Self.defaultParallelTrackCodes
            : normalizedParallel
        let resolvedActive = candidateActive.isEmpty
            ? (resolvedParallel.first ?? Self.defaultActiveTrackCode)
            : candidateActive

        if !Self.isAIFrontierCode(resolvedActive), !resolvedParallel.contains(resolvedActive) {
            resolvedParallel.append(resolvedActive)
        }

        var resolvedAI = normalizedAI
        if Self.isAIFrontierCode(resolvedActive), !resolvedAI.contains(resolvedActive) {
            resolvedAI.append(resolvedActive)
        }

        self.parallelTrackCodes = resolvedParallel
        self.activeTrackCode = resolvedActive
        self.aiFrontierTrackCodes = resolvedAI
        self.bilingualTechnicalTermsEN = bilingualTechnicalTermsEN
        self.strictTimed90Min = strictTimed90Min
    }

    public var additionalParallelTracksCount: Int {
        max(0, parallelTrackCodes.count - 1)
    }

    public var settingsParallelTracksSummary: String {
        if additionalParallelTracksCount > 0 {
            return "\(activeTrackCode) + \(additionalParallelTracksCount) ›"
        }
        return "\(activeTrackCode) ›"
    }

    public var settingsLanguageSummary: String {
        bilingualTechnicalTermsEN ? "FR + Termes EN ›" : "FR uniquement ›"
    }

    public var settingsMockExamSummary: String {
        strictTimed90Min ? "Chrono 90m ›" : "Mode libre ›"
    }

    public func isTrackingParallelCertification(_ code: String) -> Bool {
        let normalized = Self.normalizedCode(code)
        return parallelTrackCodes.contains(normalized)
    }

    public func isTrackingAIFrontier(_ code: String) -> Bool {
        let normalized = Self.normalizedAICode(code)
        return aiFrontierTrackCodes.contains(normalized)
            || aiFrontierTrackCodes.contains(Self.normalizedCode(code))
    }

    public mutating func setActiveTrack(_ code: String) {
        let normalized = Self.normalizedCode(code)
        guard !normalized.isEmpty else { return }
        activeTrackCode = normalized
        if Self.isAIFrontierCode(normalized) {
            let canonicalAI = Self.normalizedAICode(normalized)
            if !aiFrontierTrackCodes.contains(canonicalAI) && !aiFrontierTrackCodes.contains(normalized) {
                aiFrontierTrackCodes.append(canonicalAI)
            }
        } else if !parallelTrackCodes.contains(normalized) {
            parallelTrackCodes.append(normalized)
        }
    }

    public mutating func addParallelTrack(_ code: String) {
        let normalized = Self.normalizedCode(code)
        guard !normalized.isEmpty else { return }
        if !parallelTrackCodes.contains(normalized) {
            parallelTrackCodes.append(normalized)
        }
    }

    public mutating func removeParallelTrack(_ code: String) {
        let normalized = Self.normalizedCode(code)
        guard !normalized.isEmpty, parallelTrackCodes.count > 1 else { return }
        parallelTrackCodes.removeAll { $0 == normalized }
        if activeTrackCode == normalized, let firstRemaining = parallelTrackCodes.first {
            activeTrackCode = firstRemaining
        }
    }

    public mutating func toggleParallelTrack(_ code: String) {
        let normalized = Self.normalizedCode(code)
        guard !normalized.isEmpty else { return }
        if parallelTrackCodes.contains(normalized) {
            removeParallelTrack(normalized)
        } else {
            addParallelTrack(normalized)
        }
    }

    public mutating func addAIFrontierTrack(_ code: String) {
        let normalized = Self.normalizedAICode(code)
        guard !normalized.isEmpty else { return }
        if !aiFrontierTrackCodes.contains(normalized) {
            aiFrontierTrackCodes.append(normalized)
        }
    }

    public mutating func removeAIFrontierTrack(_ code: String) {
        let normalized = Self.normalizedAICode(code)
        let rawNormalized = Self.normalizedCode(code)
        guard !normalized.isEmpty else { return }
        aiFrontierTrackCodes.removeAll { $0 == normalized || $0 == rawNormalized }
        if (activeTrackCode == normalized || activeTrackCode == rawNormalized),
            let fallback = parallelTrackCodes.first
        {
            activeTrackCode = fallback
        }
    }

    public mutating func toggleAIFrontierTrack(_ code: String) {
        if isTrackingAIFrontier(code) {
            removeAIFrontierTrack(code)
        } else {
            addAIFrontierTrack(code)
        }
    }

    public func validated() throws -> Self {
        let normalizedParallel = Self.normalizedUniqueCodes(parallelTrackCodes)
        let normalizedActive = Self.normalizedCode(activeTrackCode)
        guard !normalizedParallel.isEmpty, !normalizedActive.isEmpty else {
            throw ContractError.malformed("parallel tracks preference")
        }
        return Self(
            parallelTrackCodes: normalizedParallel,
            activeTrackCode: normalizedActive,
            aiFrontierTrackCodes: Self.normalizedUniqueCodes(aiFrontierTrackCodes),
            bilingualTechnicalTermsEN: bilingualTechnicalTermsEN,
            strictTimed90Min: strictTimed90Min
        )
    }

    public static func load(
        from defaults: UserDefaults = .standard,
        key: String = storageKey
    ) throws -> Self? {
        guard !key.isEmpty else { throw ContractError.malformed("parallel tracks key") }
        guard let data = defaults.data(forKey: key) else {
            guard defaults.object(forKey: key) == nil else {
                throw ContractError.malformed("parallel tracks storage")
            }
            return nil
        }
        let decoded = try JSONDecoder().decode(Self.self, from: data)
        return try decoded.validated()
    }

    public static func loadOrDefault(
        from defaults: UserDefaults = .standard,
        key: String = storageKey
    ) -> Self {
        (try? load(from: defaults, key: key)) ?? Self()
    }

    public func save(
        to defaults: UserDefaults = .standard,
        key: String = storageKey
    ) throws {
        guard !key.isEmpty else { throw ContractError.malformed("parallel tracks key") }
        let valid = try validated()
        defaults.set(try JSONEncoder().encode(valid), forKey: key)
    }

    public static func reset(
        in defaults: UserDefaults = .standard,
        key: String = storageKey
    ) {
        guard !key.isEmpty else { return }
        defaults.removeObject(forKey: key)
    }

    public static func isAIFrontierCode(_ code: String) -> Bool {
        let normalized = normalizedCode(code)
        switch normalized {
        case "AI-OPENAI", "AI-CLAUDE", "AI-ANTHROPIC", "AI-GEMINI", "AI-FOUNDRY", "AI-MISTRAL":
            return true
        default:
            return false
        }
    }

    private static func normalizedCode(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func normalizedAICode(_ raw: String) -> String {
        let normalized = normalizedCode(raw)
        if normalized == "AI-ANTHROPIC" {
            return "AI-CLAUDE"
        }
        return normalized
    }

    private static func normalizedUniqueCodes(_ codes: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for code in codes {
            let normalized = normalizedCode(code)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            result.append(normalized)
        }
        return result
    }
}
