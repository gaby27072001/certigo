import CertigoDomain
import CertigoData
import Foundation
import XCTest

@testable import CertigoData

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

private actor EditorialPilotTransport: HTTPTransport {
    private let content: Data
    private let digest: String
    private var requests: [URLRequest] = []
    private var alterDigest = false

    init() throws {
        content = try Self.makeContent()
        digest = "sha256:\(try CanonicalQuestionReader.digest(content).sha256)"
    }

    func setAlterDigest(_ value: Bool) { alterDigest = value }
    func capturedRequests() -> [URLRequest] { requests }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = try XCTUnwrap(request.url?.path)
        let data: Data
        var headers = ["Content-Type": "application/json"]
        if path.hasSuffix("/pilots/responsible-ai-assistants/content") {
            data = content
            let responseDigest = alterDigest ? "sha256:" + String(repeating: "0", count: 64) : digest
            headers["ETag"] = "\"\(responseDigest)\""
            headers["X-Certigo-Pilot-Content-Digest"] = responseDigest
        } else if path.hasSuffix("/history/\(digest)") {
            data = try JSONSerialization.data(
                withJSONObject: [
                    "pilotId": "responsible-ai-assistants",
                    "contentDigest": digest,
                    "lastLessonId": NSNull(),
                    "lessons": [],
                ],
                options: [.sortedKeys]
            )
        } else if path.hasSuffix("/access/\(digest)") {
            data = try Self.progress(lessonId: "verify-claims", markedReadAt: nil)
        } else if path.hasSuffix("/read/\(digest)") {
            data = try Self.progress(
                lessonId: "verify-claims", markedReadAt: "2026-10-19T10:02:00.000Z")
        } else {
            throw APIError.invalidResponse
        }

        return (
            data,
            try XCTUnwrap(
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200,
                                httpVersion: nil, headerFields: headers))
        )
    }

    private static func progress(lessonId: String, markedReadAt: String?) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "lessonId": lessonId,
                "lastAccessedAt": "2026-10-19T10:01:00.000Z",
                "markedReadAt": markedReadAt as Any? ?? NSNull(),
            ],
            options: [.sortedKeys]
        )
    }

    private static func makeContent() throws -> Data {
        let sources = (1...4).map { index in
            [
                "id": "source-\(index)",
                "title": "Source \(index)",
                "url": "https://docs.example.test/\(index)",
                "checkedOn": "2026-10-14",
                "supports": "Synthetic evidence.",
                "limits": "Synthetic limitation.",
            ]
        }
        let lessons = [
            "verify-claims",
            "retrieval-not-training",
            "stop-and-escalate",
        ].map { id in
            [
                "id": id,
                "title": "Leçon originale",
                "objective": "Objectif de démonstration.",
                "estimatedMinutes": 6,
                "hook": "Accroche synthétique.",
                "keyIdeas": ["Idée synthétique."],
                "workedExample": [
                    "situation": "Situation synthétique.",
                    "steps": ["Étape synthétique."],
                    "decision": "Décision synthétique.",
                ],
                "practice": [
                    "prompt": "Consigne synthétique.",
                    "successCriteria": ["Critère synthétique."],
                    "feedback": "Retour synthétique.",
                ],
                "recap": "Récapitulatif synthétique.",
                "sourceIds": ["source-1"],
            ] as [String: Any]
        }
        return try JSONSerialization.data(
            withJSONObject: [
                "schema": "certigo.editorial.pilot/v1",
                "id": "responsible-ai-assistants",
                "locale": "fr-FR",
                "status": "draft",
                "purpose": "learning-not-certification",
                "title": "Pilote synthétique",
                "audience": "Public synthétique.",
                "prerequisites": "Aucun prérequis.",
                "estimatedMinutes": 18,
                "asOf": "2026-10-14",
                "scope": "Apprentissage sans certification.",
                "sources": sources,
                "lessons": lessons,
            ],
            options: [.sortedKeys]
        )
    }
}

final class EditorialPilotAPITests: XCTestCase {
    func testEditorialPilotHistoryAccessAndExplicitReadUseSyntheticIdentityOnly() async throws {
        let transport = try EditorialPilotTransport()
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: "https://api.example.test/api")),
            transport: transport)
        let credentials = APICredentials(
            ownerId: "synthetic-owner", accessToken: "synthetic-token")

        let snapshot = try await api.editorialPilot(
            pilotId: "responsible-ai-assistants", credentials: credentials)
        let emptyHistory = try await api.pilotHistory(snapshot, credentials: credentials)
        XCTAssertNil(emptyHistory.lastLessonId)
        XCTAssertTrue(emptyHistory.lessons.isEmpty)

        let access = try await api.recordPilotLessonAccess(
            snapshot, lessonId: "verify-claims", credentials: credentials)
        XCTAssertNil(access.markedReadAt)
        let marked = try await api.markPilotLessonRead(
            snapshot, lessonId: "verify-claims", credentials: credentials)
        XCTAssertNotNil(marked.markedReadAt)

        let requests = await transport.capturedRequests()
        XCTAssertEqual(requests.count, 4)
        let authorizationHeaders = requests.compactMap {
            $0.allHTTPHeaderFields?["Authorization"]
        }
        XCTAssertEqual(authorizationHeaders.count, requests.count)
        XCTAssertTrue(authorizationHeaders.allSatisfy { !$0.isEmpty })
        XCTAssertFalse(requests.contains { $0.url?.path.contains("synthetic-owner") == true })
        XCTAssertNil(requests[2].httpBody)
        XCTAssertNil(requests[3].httpBody)
        XCTAssertEqual(requests[2].httpMethod, "POST")
        XCTAssertEqual(requests[3].httpMethod, "POST")
        XCTAssertTrue(requests[2].url?.path.contains("/access/") == true)
        XCTAssertTrue(requests[3].url?.path.contains("/read/") == true)
        XCTAssertTrue(
            requests[2].url?.path.contains(String(snapshot.contentDigest.dropFirst(7))) == true)
        XCTAssertTrue(
            requests[3].url?.path.contains(String(snapshot.contentDigest.dropFirst(7))) == true)
    }

    func testContentDigestMismatchIsRejectedBeforePilotCanBeUsed() async throws {
        let transport = try EditorialPilotTransport()
        await transport.setAlterDigest(true)
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: "https://api.example.test/api")),
            transport: transport)

        do {
            _ = try await api.editorialPilot(
                pilotId: "responsible-ai-assistants",
                credentials: APICredentials(
                    ownerId: "synthetic-owner", accessToken: "synthetic-token"))
            XCTFail("A response whose digest does not match its bytes must be rejected.")
        } catch {
            XCTAssertEqual(error as? ContractError, .malformed("editorial pilot content digest"))
        }
    }
}
