import Foundation

public struct EditorialPilotLessonLink: Equatable, Sendable {
    public static let host = "www.certigo-app.com"
    public static let pilotID = "responsible-ai-assistants"
    public static let lessonIDs: Set<String> = [
        "verify-claims",
        "retrieval-not-training",
        "stop-and-escalate",
    ]

    public let pilotID: String
    public let lessonID: String

    public var canonicalPath: String {
        "/learn/\(pilotID)/\(lessonID)/"
    }

    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == "https",
            components.host == Self.host,
            components.percentEncodedHost == Self.host,
            components.port == nil,
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil
        else { return nil }

        let path = components.percentEncodedPath
        let prefix = "/learn/\(Self.pilotID)/"
        guard path.hasPrefix(prefix) else { return nil }

        var lessonID = String(path.dropFirst(prefix.count))
        if lessonID.hasSuffix("/") {
            lessonID.removeLast()
        }
        guard Self.lessonIDs.contains(lessonID),
            path == "\(prefix)\(lessonID)" || path == "\(prefix)\(lessonID)/"
        else { return nil }

        pilotID = Self.pilotID
        self.lessonID = lessonID
    }
}
