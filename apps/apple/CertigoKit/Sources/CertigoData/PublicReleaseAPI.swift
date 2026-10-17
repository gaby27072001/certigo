import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
public enum ActivePublicManifestFetch: Sendable {
    case fetched(PublicPackageManifest, ValidatedReleaseBinding, etag: String)
    case notModified(ValidatedReleaseBinding, etag: String)
}
public struct PublicReleaseAPI: Sendable {
    public let apiScope: String
    private let baseURL: URL
    private let transport: any BoundedHTTPTransport

    public init(api: CertigoAPI, transport: any BoundedHTTPTransport = BoundedURLSessionTransport())
    {
        baseURL = api.baseURL
        apiScope = api.scope
        self.transport = transport
    }

    public func activeManifest(
        credentials: APICredentials, ifNoneMatch: String? = nil
    ) async throws -> ActivePublicManifestFetch {
        let (data, response) = try await request(
            ["content", "releases", "active", "manifest"], credentials: credentials,
            maximumBytes: PublicReleaseContracts.maximumManifestBytes, ifNoneMatch: ifNoneMatch
        )
        let release = try header(response, "x-content-release-id")
        let manifestId = try header(response, "x-content-manifest-id")
        let etag = try header(response, "etag")
        try PublicReleaseContracts.digestId(release)
        try PublicReleaseContracts.digestId(manifestId)
        try cacheControl(response, required: ["private", "no-cache"])
        guard etag == "\"\(manifestId)\"" else { throw PublicReleaseError.provenance }
        if response.statusCode == 304 {
            guard ifNoneMatch == etag, data.isEmpty else { throw PublicReleaseError.provenance }
            return .notModified(
                ValidatedReleaseBinding(releaseId: release, publicManifestId: manifestId),
                etag: etag
            )
        }
        guard response.mimeType == "application/json" else { throw APIError.invalidResponse }
        let manifest = try PublicReleaseContracts.manifest(data)
        let binding = try PublicReleaseContracts.bind(
            manifest, releaseId: release, manifestId: manifestId, etag: etag
        )
        return .fetched(manifest, binding, etag: etag)
    }

    public func file(
        _ file: PublicPackageFile, manifest: PublicPackageManifest,
        binding: ValidatedReleaseBinding, credentials: APICredentials
    ) async throws -> Data {
        guard manifest.files.contains(file), manifest.manifestId == binding.publicManifestId,
            manifest.releaseId == binding.releaseId
        else { throw PublicReleaseError.provenance }
        try PublicReleaseContracts.safePath(file.path)
        let (data, response) = try await request(
            [
                "content", "releases", binding.releaseId, "manifests", binding.publicManifestId,
                "files", file.hash,
            ]
                + file.path.split(separator: "/").map(String.init),
            credentials: credentials, maximumBytes: file.size, ifNoneMatch: nil
        )
        guard response.statusCode == 200, response.mimeType == "application/json",
            try header(response, "etag") == "\"sha256:\(file.hash)\"",
            try header(response, "x-content-release-id") == binding.releaseId,
            try header(response, "x-content-manifest-id") == binding.publicManifestId,
            try header(response, "x-content-sha256") == file.hash,
            try header(response, "accept-ranges") == "none",
            Int(try header(response, "content-length")) == file.size
        else { throw PublicReleaseError.provenance }
        try cacheControl(response, required: ["private", "max-age=31536000", "immutable"])
        try CanonicalQuestionReader.verifyFile(data, size: file.size, sha256: file.hash)
        return data
    }

    private func request(
        _ components: [String], credentials: APICredentials, maximumBytes: Int, ifNoneMatch: String?
    ) async throws -> (Data, HTTPURLResponse) {
        guard !credentials.accessToken.isEmpty,
            !credentials.accessToken.contains("\r"), !credentials.accessToken.contains("\n")
        else { throw APIError.unauthorized }
        var url = baseURL
        for component in components {
            guard !component.isEmpty, component != ".", component != "..",
                !component.contains("/"), !component.contains("\\"),
                !component.contains("%"),
                !component.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            else { throw PublicReleaseError.unsafePath }
            url.appendPathComponent(component)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let ifNoneMatch {
            guard !ifNoneMatch.contains("\r"), !ifNoneMatch.contains("\n") else {
                throw PublicReleaseError.provenance
            }
            request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
        }
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request, maximumBytes: maximumBytes)
        } catch let error as URLError {
            throw APIError.transport(error.code.rawValue)
        }
        if response.statusCode == 401 { throw APIError.unauthorized }
        guard response.statusCode == 200 || response.statusCode == 304 else {
            throw APIError.http(response.statusCode)
        }
        guard response.url == url else { throw PublicReleaseError.provenance }
        guard data.count <= maximumBytes else { throw PublicReleaseError.limitExceeded }
        return (data, response)
    }

    private func header(_ response: HTTPURLResponse, _ name: String) throws -> String {
        guard let value = response.value(forHTTPHeaderField: name), !value.isEmpty else {
            throw PublicReleaseError.provenance
        }
        return value
    }

    private func cacheControl(_ response: HTTPURLResponse, required: Set<String>) throws {
        let tokens = Set(
            try header(response, "cache-control").split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            })
        guard required == tokens else { throw PublicReleaseError.provenance }
    }
}
