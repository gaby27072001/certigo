import Foundation

public struct FeatureFlag: RawRepresentable, Hashable, Sendable, CaseIterable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.allCases.contains(where: { $0.rawValue == rawValue }) else { return nil }
        self.rawValue = rawValue
    }

    private init(_ key: String) { rawValue = key }

    public static let prism = Self("prism.enabled")
    public static let brandIcons = Self("brand.icons.v1")
    public static let navigation = Self("nav.v2")
    public static let today = Self("today.v2")
    public static let session = Self("session.v2")
    public static let feedback = Self("feedback.v2")
    public static let dailySituation = Self("daily.situation")
    public static let atlas = Self("atlas.v1")
    public static let readiness = Self("readiness.v2")
    public static let rhythm = Self("rhythm.v1")
    public static let dailyStreakOptIn = Self("rhythm.dailyStreakOptIn")
    public static let celebrations = Self("celebrations.v1")
    public static let missions = Self("missions.v1")
    public static let events = Self("events.v1")
    public static let social = Self("social.v2")
    public static let contextualAI = Self("ai.contextual")
    public static let onboarding = Self("onboarding.v2")
    public static let pro = Self("pro.v1")
    public static let widgets = Self("widgets.v1")
    public static let legacyDemoExposure = Self("developer.demo")

    public enum BrandVendor: String, CaseIterable, Sendable {
        case microsoft, github, aws, google, cncf, cisco, python, linux
    }

    public static func brandIcons(vendor: BrandVendor) -> Self {
        Self("brand.icons.\(vendor.rawValue)")
    }

    public static var allCases: [Self] {
        [
            .prism, .brandIcons, .navigation, .today, .session, .feedback, .dailySituation,
            .atlas, .readiness, .rhythm, .dailyStreakOptIn, .celebrations, .missions,
            .events, .social, .contextualAI, .onboarding, .pro, .widgets, .legacyDemoExposure,
        ] + BrandVendor.allCases.map { brandIcons(vendor: $0) }
    }

    public var compiledDefault: Bool {
        self == .dailyStreakOptIn || self == .legacyDemoExposure
            || BrandVendor.allCases.contains { self == Self.brandIcons(vendor: $0) }
    }
}

/// Remote configuration can disable an experience, never activate an unaccepted one.
/// Transport/authenticity belongs to the configuration source, not this domain resolver.
public struct FeatureFlags: Equatable, Sendable {
    private var remoteDisabled: Set<FeatureFlag> = []
    #if DEBUG
        private var debugOverrides: [FeatureFlag: Bool] = [:]
        private static let overridesKey = "certigo.feature-flags.debug.v1"
    #endif

    public init() {}

    public func isVendorExplicitlyDisabled(_ vendor: FeatureFlag.BrandVendor) -> Bool {
        let flag = FeatureFlag.brandIcons(vendor: vendor)
        if remoteDisabled.contains(flag) { return true }
        #if DEBUG
            if debugOverrides[flag] == false { return true }
        #endif
        return false
    }

    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        guard !remoteDisabled.contains(flag) else { return false }
        if flag.rawValue.hasPrefix("brand.icons."), flag != .brandIcons,
            !isEnabled(.brandIcons)
        {
            return false
        }
        #if DEBUG
            if let value = debugOverrides[flag] { return value }
        #endif
        return flag.compiledDefault
    }

    /// JSON object of flag keys to booleans. Unknown keys are forward-compatible.
    /// Decoding is atomic: malformed data leaves the previous kill switches intact.
    public mutating func applyRemoteJSON(_ data: Data) throws {
        let values = try JSONDecoder().decode([String: Bool].self, from: data)
        remoteDisabled = Set(
            values.compactMap { key, value in value ? nil : FeatureFlag(rawValue: key) })
    }

    #if DEBUG
        public mutating func setDebugOverride(_ value: Bool?, for flag: FeatureFlag) {
            debugOverrides[flag] = value
        }

        public func debugOverride(for flag: FeatureFlag) -> Bool? { debugOverrides[flag] }

        public mutating func loadDebugOverrides(from defaults: UserDefaults) throws {
            guard let data = defaults.data(forKey: Self.overridesKey) else {
                debugOverrides = [:]
                return
            }
            let values = try JSONDecoder().decode([String: Bool].self, from: data)
            debugOverrides = Dictionary(
                uniqueKeysWithValues: values.compactMap { key, value in
                    FeatureFlag(rawValue: key).map { ($0, value) }
                })
        }

        public func saveDebugOverrides(to defaults: UserDefaults) throws {
            let values = Dictionary(
                uniqueKeysWithValues: debugOverrides.map { ($0.key.rawValue, $0.value) })
            defaults.set(try JSONEncoder().encode(values), forKey: Self.overridesKey)
        }
    #endif
}
