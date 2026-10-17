import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
public protocol BoundedHTTPTransport: Sendable {
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> (Data, HTTPURLResponse)
}
public struct BoundedURLSessionTransport: BoundedHTTPTransport {
    private let configure: @Sendable (URLSessionConfiguration) -> Void

    public init() { configure = { _ in } }

    init(configure: @escaping @Sendable (URLSessionConfiguration) -> Void) {
        self.configure = configure
    }

    public func send(_ request: URLRequest, maximumBytes: Int) async throws -> (
        Data, HTTPURLResponse
    ) {
        guard maximumBytes > 0, maximumBytes <= PublicReleaseContracts.maximumManifestBytes else {
            throw PublicReleaseError.limitExceeded
        }
        let download = BoundedDownload(maximumBytes: maximumBytes, configure: configure)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                download.start(request, continuation: continuation)
            }
        } onCancel: {
            download.cancel()
        }
    }
}
// URLSession callbacks and task cancellation can race. Every mutable field is lock-protected.
private final class BoundedDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    typealias Completion = CheckedContinuation<(Data, HTTPURLResponse), any Error>
    private let maximumBytes: Int
    private let configure: @Sendable (URLSessionConfiguration) -> Void
    private let lock = NSLock()
    private var bytes = Data()
    private var response: HTTPURLResponse?
    private var continuation: Completion?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var cancelled = false
    private var finished = false

    init(maximumBytes: Int, configure: @escaping @Sendable (URLSessionConfiguration) -> Void) {
        self.maximumBytes = maximumBytes
        self.configure = configure
    }

    func start(_ request: URLRequest, continuation: Completion) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configure(configuration)
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        let wasCancelled = lock.withLock {
            self.continuation = continuation
            self.session = session
            self.task = task
            return cancelled
        }
        if wasCancelled {
            finish(.failure(CancellationError()))
        } else {
            task.resume()
        }
    }

    func cancel() {
        let task = lock.withLock {
            cancelled = true
            return self.task
        }
        task?.cancel()
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(.failure(APIError.invalidResponse))
            return
        }
        guard response.expectedContentLength <= Int64(maximumBytes) else {
            completionHandler(.cancel)
            finish(.failure(PublicReleaseError.limitExceeded))
            return
        }
        lock.withLock { self.response = http }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let allowed = lock.withLock {
            guard !finished, data.count <= maximumBytes - bytes.count else { return false }
            bytes.append(data)
            return true
        }
        if !allowed {
            finish(.failure(PublicReleaseError.limitExceeded))
        }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
    ) {
        if lock.withLock({ cancelled }) {
            finish(.failure(CancellationError()))
            return
        }
        if let error {
            finish(.failure(error))
            return
        }
        let result: Result<(Data, HTTPURLResponse), any Error> = lock.withLock {
            guard let response else { return .failure(APIError.invalidResponse) }
            return .success((bytes, response))
        }
        finish(result)
    }

    private func finish(_ result: Result<(Data, HTTPURLResponse), any Error>) {
        let completion = lock.withLock { () -> (Completion, URLSession)? in
            guard !finished, let continuation, let session else { return nil }
            finished = true
            self.continuation = nil
            self.session = nil
            self.task = nil
            bytes = Data()
            return (continuation, session)
        }
        guard let (continuation, session) = completion else { return }
        session.invalidateAndCancel()
        continuation.resume(with: result)
    }
}
