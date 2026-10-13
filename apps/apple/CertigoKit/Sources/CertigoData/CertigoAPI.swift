import CertigoDomain
import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
public enum APIError: Error, Equatable, Sendable {
    case configuration
    case unauthorized
    case http(Int)
    case transport(Int)
    case invalidResponse
    case staleSession

    public var isRetryable: Bool {
        switch self {
        case .http(let status): status == 408 || status == 429 || (500...599).contains(status)
        case .transport(let code):
            [
                URLError.timedOut.rawValue, URLError.notConnectedToInternet.rawValue,
                URLError.networkConnectionLost.rawValue, URLError.cannotConnectToHost.rawValue,
                URLError.cannotFindHost.rawValue, URLError.dnsLookupFailed.rawValue,
            ].contains(code)
        default: false
        }
    }
}
public struct APICredentials: Sendable {
    public let ownerId: String
    public let accessToken: String
    public let generation: UUID

    public init(ownerId: String, accessToken: String, generation: UUID = UUID()) {
        self.ownerId = ownerId
        self.accessToken = accessToken
        self.generation = generation
    }
}
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
private final class RejectRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
public final class URLSessionTransport: HTTPTransport, Sendable {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        session = URLSession(
            configuration: configuration, delegate: RejectRedirects(), delegateQueue: nil)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return (data, http)
    }
}
public struct CertigoAPI: Sendable {
    public let baseURL: URL
    private let transport: any HTTPTransport
    public var scope: String { baseURL.absoluteString }

    public init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) throws {
        try Self.validateBaseURL(baseURL)
        self.baseURL = baseURL
        self.transport = transport
    }

    static func validateBaseURL(_ baseURL: URL) throws {
        guard baseURL.scheme == "https", baseURL.host != nil,
            baseURL.user == nil, baseURL.password == nil,
            baseURL.query == nil, baseURL.fragment == nil
        else { throw APIError.configuration }
    }

    public func profile(accessToken: String) async throws -> Profile {
        let (data, _) = try await request(["me"], token: accessToken)
        let profile = try Self.decode(Profile.self, from: data)
        guard !profile.id.isEmpty else { throw ContractError.malformed("profile identity") }
        return profile
    }

    public func catalog(_ credentials: APICredentials) async throws -> [Track] {
        let (data, _) = try await request(["catalog", "tracks"], token: credentials.accessToken)
        return try Self.decode(Catalog.self, from: data).validated().tracks
    }

    public func path(trackId: String, credentials: APICredentials) async throws -> LearningPath {
        let (data, _) = try await request(["me", "paths", trackId], token: credentials.accessToken)
        let path = try Self.decode(LearningPath.self, from: data)
        guard path.trackId == trackId, (0...100).contains(path.readinessScore) else {
            throw ContractError.malformed("path identity or readiness")
        }
        return path
    }

    public func lesson(
        trackId: String, lessonId: String, credentials: APICredentials
    ) async throws -> Lesson {
        let (data, response) = try await request(
            ["tracks", trackId, "lessons", lessonId], token: credentials.accessToken
        )
        var lesson = try Self.decode(Lesson.self, from: data)
        let header = response.value(forHTTPHeaderField: "x-content-manifest-id")
        if let header, let body = lesson.publicManifestId, header != body {
            throw ContractError.malformed("manifest mismatch")
        }
        lesson.publicManifestId = header ?? lesson.publicManifestId
        return try lesson.validated(trackId: trackId, lessonId: lessonId)
    }

    public func submit(
        lessonId: String, submission: QuizSubmission, credentials: APICredentials
    ) async throws -> QuizResult {
        _ = try submission.validated()
        let body = try Self.encoder().encode(submission)
        let (data, _) = try await request(
            ["quiz", lessonId, "submit"], token: credentials.accessToken, body: body
        )
        return try Self.decode(QuizResult.self, from: data).validated(for: submission)
    }

    private func request(
        _ segments: [String], token: String, body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard !token.isEmpty, !token.contains("\r"), !token.contains("\n") else {
            throw APIError.unauthorized
        }
        var url = baseURL
        for segment in segments {
            guard !segment.isEmpty, segment != ".", segment != "..",
                !segment.contains("/"), !segment.contains("\\")
            else {
                throw APIError.configuration
            }
            url.appendPathComponent(segment)
        }
        var request = URLRequest(url: url)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "x-correlation-id")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError {
            throw APIError.transport(error.code.rawValue)
        }
        if response.statusCode == 401 { throw APIError.unauthorized }
        guard (200...299).contains(response.statusCode) else {
            throw APIError.http(response.statusCode)
        }
        guard data.count <= 8 * 1_024 * 1_024,
            response.mimeType == "application/json"
        else { throw APIError.invalidResponse }
        return (data, response)
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: text) else {
                throw ContractError.malformed("UTC timestamp")
            }
            return date
        }
        return decoder
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try decoder().decode(type, from: data) } catch is DecodingError {
            throw APIError.invalidResponse
        }
    }
}
