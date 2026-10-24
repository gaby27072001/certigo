import Foundation

enum FileProtectionPolicy {
    enum Rejection: Error, Equatable, Sendable {
        case missingAttribute
        case nonstringAttribute
        case differentKnownPolicy
        case unrecognizedPolicy
    }

    // File attribute dictionaries bridge the Objective-C extensible string enum as NSString.
    static func isFirstUnlock(_ value: Any?) -> Bool {
        rejection(value) == nil
    }

    static func requireFirstUnlock(_ value: Any?) throws {
        if let error = rejection(value) { throw error }
    }

    static func rejection(_ value: Any?) -> Rejection? {
        guard let value else { return .missingAttribute }
        let raw: String
        #if os(iOS)
            if let policy = value as? FileProtectionType {
                raw = policy.rawValue
            } else if let string = value as? String {
                raw = string
            } else {
                return .nonstringAttribute
            }
            let expected = FileProtectionType.completeUntilFirstUserAuthentication.rawValue
            let otherPolicies = [
                FileProtectionType.none.rawValue, FileProtectionType.complete.rawValue,
                FileProtectionType.completeUnlessOpen.rawValue,
            ]
        #else
            guard let string = value as? String else { return .nonstringAttribute }
            raw = string
            let expected = "NSFileProtectionCompleteUntilFirstUserAuthentication"
            let otherPolicies = [
                "NSFileProtectionNone", "NSFileProtectionComplete",
                "NSFileProtectionCompleteUnlessOpen",
            ]
        #endif
        if raw == expected { return nil }
        return otherPolicies.contains(raw) ? .differentKnownPolicy : .unrecognizedPolicy
    }
}
