import Foundation
import Testing
@testable import CertigoDomain

@Suite struct FeatureFlagsTests {
    @Test func defaultsPreserveStreakAndDisableUnacceptedExperiences() {
        let flags = FeatureFlags()
        for flag in FeatureFlag.allCases {
            #expect(FeatureFlag(rawValue: flag.rawValue) == flag)
            #expect(flags.isEnabled(flag) == (flag == .dailyStreakOptIn || flag == .legacyDemoExposure))
        }
        #expect(FeatureFlag(rawValue: "unknown") == nil)
        #expect(Set(FeatureFlag.allCases).count == FeatureFlag.allCases.count)
    }

    @Test func remoteCannotEnableAndMalformedUpdateIsAtomic() throws {
        var flags = FeatureFlags()
        try flags.applyRemoteJSON(Data(#"{"prism.enabled":true,"rhythm.dailyStreakOptIn":false}"#.utf8))
        #expect(!flags.isEnabled(.prism))
        #expect(!flags.isEnabled(.dailyStreakOptIn))
        #expect(throws: (any Error).self) {
            try flags.applyRemoteJSON(Data(#"{"rhythm.dailyStreakOptIn":"yes"}"#.utf8))
        }
        #expect(!flags.isEnabled(.dailyStreakOptIn))
        try flags.applyRemoteJSON(Data(#"{"future.flag":false}"#.utf8))
        #expect(flags.isEnabled(.dailyStreakOptIn))
    }

    #if DEBUG
        @Test func remoteWinsOverPersistedDebugOverridesAndVendorDependsOnGlobal() throws {
            let suite = "FeatureFlagsTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            var flags = FeatureFlags()
            flags.setDebugOverride(true, for: .prism)
            flags.setDebugOverride(true, for: .brandIcons)
            try flags.saveDebugOverrides(to: defaults)
            var restored = FeatureFlags()
            try restored.loadDebugOverrides(from: defaults)
            #expect(restored.isEnabled(.prism))
            #expect(restored.isEnabled(.brandIcons(vendor: .microsoft)))
            try restored.applyRemoteJSON(Data(#"{"prism.enabled":false,"brand.icons.v1":false}"#.utf8))
            #expect(!restored.isEnabled(.prism))
            #expect(!restored.isEnabled(.brandIcons(vendor: .microsoft)))
            restored.setDebugOverride(nil, for: .prism)
            #expect(restored.debugOverride(for: .prism) == nil)
        }
    #endif
}
