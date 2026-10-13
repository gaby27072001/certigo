import Foundation

enum FileProtectionPolicy {
    // File attribute dictionaries bridge the Objective-C extensible string enum as NSString.
    static func isFirstUnlock(_ value: Any?) -> Bool {
        #if os(iOS)
            if let policy = value as? FileProtectionType {
                return policy == .completeUntilFirstUserAuthentication
            }
        #endif
        guard let raw = value as? String else { return false }
        #if os(iOS)
            return raw == FileProtectionType.completeUntilFirstUserAuthentication.rawValue
        #else
            return raw == "NSFileProtectionCompleteUntilFirstUserAuthentication"
        #endif
    }
}
