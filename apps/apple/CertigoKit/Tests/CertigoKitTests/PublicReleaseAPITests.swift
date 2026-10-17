import Foundation
import XCTest

@testable import CertigoData

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@MainActor
final class PublicReleaseAPITests: XCTestCase {
    private let releaseId =
        "sha256:92bde38713c6a4671428994a32b85ea385904a509efe818d85ccf7b430962a66"
    private let credentials = APICredentials(
        ownerId: "synthetic-owner", accessToken: "synthetic-test-token")

    func testActiveManifestUsesAuthenticatedExistingEndpointAndExactBinding() async throws {
        let fixture = try manifestData()
        let manifest = try PublicReleaseContracts.manifest(fixture)
        let transport = ReleaseTransport(data: fixture, headers: manifestHeaders(manifest))
        let source = PublicReleaseAPI(
            api: try api(),
            transport: transport
        )
        guard
            case .fetched(let actual, let binding, let etag) = try await source.activeManifest(
                credentials: credentials)
        else { return XCTFail("Expected authenticated manifest") }
        XCTAssertEqual(actual, manifest)
        XCTAssertEqual(binding.releaseId, releaseId)
        XCTAssertEqual(etag, "\"\(manifest.manifestId)\"")
        let captured = await transport.request
        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.url?.path, "/api/content/releases/active/manifest")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-test-token")
        let limit = await transport.limit
        XCTAssertEqual(limit, PublicReleaseContracts.maximumManifestBytes)
    }

    func testChangedReleaseHeaderOrResponseOriginCannotPassManifestDigest() async throws {
        let fixture = try manifestData()
        let manifest = try PublicReleaseContracts.manifest(fixture)
        for foreignOrigin in [false, true] {
            var headers = manifestHeaders(manifest)
            if !foreignOrigin {
                headers["X-Content-Release-Id"] = "sha256:" + String(repeating: "a", count: 64)
            }
            let transport = ReleaseTransport(
                data: fixture, headers: headers, foreignOrigin: foreignOrigin)
            let source = PublicReleaseAPI(
                api: try api(),
                transport: transport
            )
            do {
                _ = try await source.activeManifest(credentials: credentials)
                XCTFail("Untrusted provenance accepted")
            } catch {
                XCTAssertEqual(error as? PublicReleaseError, .provenance)
            }
        }
    }

    func testNotModifiedRequiresMatchingConditionalRequestAndNoBody() async throws {
        let fixture = try manifestData()
        let manifest = try PublicReleaseContracts.manifest(fixture)
        let transport = ReleaseTransport(
            data: Data(), headers: manifestHeaders(manifest), status: 304)
        let source = PublicReleaseAPI(
            api: try api(),
            transport: transport
        )
        do {
            _ = try await source.activeManifest(credentials: credentials)
            XCTFail("304 without conditional cache accepted")
        } catch { XCTAssertEqual(error as? PublicReleaseError, .provenance) }
        guard
            case .notModified(let binding, _) = try await source.activeManifest(
                credentials: credentials, ifNoneMatch: "\"\(manifest.manifestId)\""
            )
        else { return XCTFail("Expected coherent 304") }
        XCTAssertEqual(binding.publicManifestId, manifest.manifestId)
    }

    func testFileRequiresExactHeadersByteSizeHashAndPublicManifestMembership() async throws {
        let manifest = try PublicReleaseContracts.manifest(manifestData())
        let file = manifest.files[0]
        let root = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let producer = try Data(
            contentsOf: root.appendingPathComponent("apple-compat/v1/supported/question-v3.json"))
        let bytes = try CanonicalQuestionReader.packageFile(producer)
        let headers = [
            "ETag": "\"sha256:\(file.hash)\"", "X-Content-Release-Id": releaseId,
            "X-Content-Manifest-Id": manifest.manifestId, "X-Content-SHA256": file.hash,
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "private, max-age=31536000, immutable",
            "Accept-Ranges": "none", "Content-Length": String(file.size),
        ]
        let binding = try PublicReleaseContracts.bind(
            manifest, releaseId: releaseId, manifestId: manifest.manifestId,
            etag: "\"\(manifest.manifestId)\""
        )
        let transport = ReleaseTransport(data: bytes, headers: headers)
        let source = PublicReleaseAPI(
            api: try api(), transport: transport
        )
        let fetched = try await source.file(
            file, manifest: manifest, binding: binding, credentials: credentials)
        XCTAssertEqual(fetched, bytes)
        let limit = await transport.limit
        XCTAssertEqual(limit, file.size)
        let captured = await transport.request
        let request = try XCTUnwrap(captured)
        XCTAssertTrue(try XCTUnwrap(request.url?.path).hasSuffix("/\(file.hash)/\(file.path)"))
        XCTAssertFalse(try XCTUnwrap(request.url?.path).contains("solutions"))
    }

    func testCacheControlSubstringAndOversizedResponseAreNotAccepted() async throws {
        let fixture = try manifestData()
        let manifest = try PublicReleaseContracts.manifest(fixture)
        var headers = manifestHeaders(manifest)
        headers["Cache-Control"] = "not-private, no-cache"
        let source = PublicReleaseAPI(
            api: try api(),
            transport: ReleaseTransport(data: fixture, headers: headers)
        )
        do {
            _ = try await source.activeManifest(credentials: credentials)
            XCTFail("Substring masquerading as cache directive accepted")
        } catch { XCTAssertEqual(error as? PublicReleaseError, .provenance) }
        let oversized = PublicReleaseAPI(
            api: try api(),
            transport: ReleaseTransport(
                data: Data(repeating: 0x20, count: PublicReleaseContracts.maximumManifestBytes + 1),
                headers: manifestHeaders(manifest)
            )
        )
        do {
            _ = try await oversized.activeManifest(credentials: credentials)
            XCTFail("Oversized custom transport response accepted")
        } catch { XCTAssertEqual(error as? PublicReleaseError, .limitExceeded) }
    }

    func testFileRejectsTamperingAndEveryRequiredResponseHeaderMismatch() async throws {
        let manifest = try PublicReleaseContracts.manifest(manifestData())
        let file = manifest.files[0]
        let root = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let bytes = try CanonicalQuestionReader.packageFile(
            Data(
                contentsOf: root.appendingPathComponent(
                    "apple-compat/v1/supported/question-v3.json")))
        let headers = [
            "ETag": "\"sha256:\(file.hash)\"", "X-Content-Release-Id": releaseId,
            "X-Content-Manifest-Id": manifest.manifestId, "X-Content-SHA256": file.hash,
            "Content-Type": "application/json", "Content-Length": String(file.size),
            "Cache-Control": "private, max-age=31536000, immutable", "Accept-Ranges": "none",
        ]
        let binding = try PublicReleaseContracts.bind(
            manifest, releaseId: releaseId, manifestId: manifest.manifestId,
            etag: "\"\(manifest.manifestId)\"")
        for name in headers.keys {
            var changed = headers
            changed[name] = "invalid"
            let source = PublicReleaseAPI(
                api: try api(), transport: ReleaseTransport(data: bytes, headers: changed))
            do {
                _ = try await source.file(
                    file, manifest: manifest, binding: binding, credentials: credentials)
                XCTFail("Accepted mismatched \(name)")
            } catch { XCTAssertEqual(error as? PublicReleaseError, .provenance, name) }
        }
        var tampered = bytes
        tampered[0] = 0x20
        let source = PublicReleaseAPI(
            api: try api(), transport: ReleaseTransport(data: tampered, headers: headers))
        do {
            _ = try await source.file(
                file, manifest: manifest, binding: binding, credentials: credentials)
            XCTFail("Accepted hash-mismatched bytes")
        } catch { XCTAssertEqual(error as? CanonicalContentError, .integrityMismatch) }
    }

    func testRealTransportReturnsBoundedBytesAndHonorsAlreadyCancelledTasks() async throws {
        let transport = BoundedURLSessionTransport { configuration in
            configuration.protocolClasses = [BoundedTestProtocol.self]
        }
        let request = URLRequest(
            url: try XCTUnwrap(URL(string: "https://certigo-limit.test/within-limit")))
        let (data, response) = try await transport.send(request, maximumBytes: 64)
        XCTAssertEqual(data.count, 64)
        XCTAssertEqual(response.statusCode, 200)
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await transport.send(request, maximumBytes: 64)
        }
        do {
            _ = try await cancelled.value
            XCTFail("Already cancelled request succeeded")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testRealTransportRejectsContentLengthBeforeBufferingAndUnknownLengthDuringChunks()
        async throws
    {
        let transport = BoundedURLSessionTransport { configuration in
            configuration.protocolClasses = [BoundedTestProtocol.self]
        }
        for path in ["oversized-header", "oversized-chunks"] {
            let request = URLRequest(
                url: try XCTUnwrap(URL(string: "https://certigo-limit.test/\(path)")))
            do {
                _ = try await transport.send(request, maximumBytes: 32)
                XCTFail("Exceeded streaming quota")
            } catch {
                XCTAssertEqual(error as? PublicReleaseError, .limitExceeded, path)
            }
        }
    }

    private func api() throws -> CertigoAPI {
        try CertigoAPI(baseURL: XCTUnwrap(URL(string: "https://certigo.test/api")))
    }

    private func manifestData() throws -> Data {
        let root = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("runtime/manifest-v3.json"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        object["releaseId"] = releaseId
        return try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    private func manifestHeaders(_ manifest: PublicPackageManifest) -> [String: String] {
        [
            "Content-Type": "application/json", "X-Content-Release-Id": releaseId,
            "X-Content-Manifest-Id": manifest.manifestId, "ETag": "\"\(manifest.manifestId)\"",
            "Cache-Control": "private, no-cache",
        ]
    }
}
private actor ReleaseTransport: BoundedHTTPTransport {
    private let data: Data
    private let headers: [String: String]
    private let status: Int
    private let foreignOrigin: Bool
    private(set) var request: URLRequest?
    private(set) var limit: Int?

    init(data: Data, headers: [String: String], status: Int = 200, foreignOrigin: Bool = false) {
        self.data = data
        self.headers = headers
        self.status = status
        self.foreignOrigin = foreignOrigin
    }

    func send(_ request: URLRequest, maximumBytes: Int) throws -> (Data, HTTPURLResponse) {
        self.request = request
        limit = maximumBytes
        let url = try XCTUnwrap(foreignOrigin ? URL(string: "https://other.test/api") : request.url)
        let response = try XCTUnwrap(
            HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers))
        return (data, response)
    }
}
private final class BoundedTestProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "certigo-limit.test"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: url.path == "/oversized-header" ? ["Content-Length": "256"] : [:]
            )
        else {
            client?.urlProtocol(self, didFailWithError: APIError.invalidResponse)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for _ in 0..<4 {
            client?.urlProtocol(self, didLoad: Data(repeating: 0x20, count: 16))
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
