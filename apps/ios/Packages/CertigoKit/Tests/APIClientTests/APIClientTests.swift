// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.

import XCTest

@testable import APIClient

final class CertigoErrorTests: XCTestCase {
    /// La table HTTP → domaine, code par code.
    func testStatusMapping() {
        XCTAssertEqual(CertigoError.fromStatus(401), .unauthorized)
        XCTAssertEqual(CertigoError.fromStatus(403), .forbidden)
        XCTAssertEqual(CertigoError.fromStatus(404), .notFound)
        XCTAssertEqual(CertigoError.fromStatus(409), .conflict)
        XCTAssertEqual(CertigoError.fromStatus(408), .timeout)
        XCTAssertEqual(CertigoError.fromStatus(504), .timeout)
        XCTAssertEqual(CertigoError.fromStatus(500), .server(status: 500))
        XCTAssertEqual(CertigoError.fromStatus(418), .server(status: 418))
    }

    /// Le délai indiqué par le serveur est conservé tel quel.
    func testRateLimitCarriesRetryAfter() {
        XCTAssertEqual(CertigoError.fromStatus(429, retryAfter: 30), .rateLimited(retryAfter: 30))
        XCTAssertEqual(CertigoError.fromStatus(429), .rateLimited(retryAfter: nil))
    }

    /// Un code inconnu devient une erreur **serveur**, jamais une erreur
    /// réseau : accuser le réseau envoie l'utilisateur vérifier son wifi alors
    /// que le problème est chez nous.
    func testUnknownStatusIsNeverReportedAsNetwork() {
        for status in [402, 451, 502, 599] {
            XCTAssertNotEqual(CertigoError.fromStatus(status), .network)
        }
    }

    /// Ce qui se rejoue, et ce qui ne se rejoue jamais.
    func testRetryability() {
        XCTAssertTrue(CertigoError.network.isRetryable)
        XCTAssertTrue(CertigoError.timeout.isRetryable)
        XCTAssertTrue(CertigoError.rateLimited(retryAfter: nil).isRetryable)
        XCTAssertTrue(CertigoError.server(status: 503).isRetryable)

        XCTAssertFalse(CertigoError.unauthorized.isRetryable)
        XCTAssertFalse(CertigoError.forbidden.isRetryable)
        XCTAssertFalse(CertigoError.notFound.isRetryable)
        XCTAssertFalse(CertigoError.decoding.isRetryable)
    }

    /// Un 409 n'est **jamais** rejoué automatiquement.
    ///
    /// La soumission de quiz est idempotente par `clientAttemptId` : rejouer un
    /// conflit masquerait une vraie divergence d'état au lieu de la révéler.
    func testConflictIsNeverRetried() {
        XCTAssertFalse(CertigoError.conflict.isRetryable)
        XCTAssertFalse(RetryPolicy.standard.shouldRetry(.conflict, attempt: 1))
    }

    /// Un 4xx qui n'est pas 429 ne se rejoue pas non plus.
    func testClientErrorsBelow500AreNotRetried() {
        XCTAssertFalse(CertigoError.server(status: 418).isRetryable)
    }
}

final class RetryPolicyTests: XCTestCase {
    /// Croissance exponentielle depuis le délai de base.
    func testExponentialBackoff() {
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 0.5, maxDelay: 8)
        XCTAssertEqual(policy.delay(forAttempt: 1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 2), 1.0, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 3), 2.0, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 4), 4.0, accuracy: 0.0001)
    }

    /// Le délai est plafonné : une reprise ne doit jamais devenir un abandon
    /// silencieux de plusieurs minutes.
    func testBackoffIsCapped() {
        let policy = RetryPolicy(maxAttempts: 10, baseDelay: 0.5, maxDelay: 8)
        XCTAssertEqual(policy.delay(forAttempt: 6), 8.0, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 9), 8.0, accuracy: 0.0001)
    }

    /// Une tentative invalide n'attend pas.
    func testNonPositiveAttemptHasNoDelay() {
        XCTAssertEqual(RetryPolicy.standard.delay(forAttempt: 0), 0)
        XCTAssertEqual(RetryPolicy.standard.delay(forAttempt: -3), 0)
    }

    /// Le nombre de tentatives est respecté.
    func testAttemptBudgetIsHonoured() {
        let policy = RetryPolicy(maxAttempts: 3)
        XCTAssertTrue(policy.shouldRetry(.network, attempt: 1))
        XCTAssertTrue(policy.shouldRetry(.network, attempt: 2))
        XCTAssertFalse(policy.shouldRetry(.network, attempt: 3))
        XCTAssertFalse(policy.shouldRetry(.network, attempt: 4))
    }
}

final class APIClientWitnessTests: XCTestCase {
    /// Le client par défaut des tests échoue : un test qui n'a rien remplacé
    /// ne doit pas toucher le réseau par accident.
    func testFailingClientThrowsNetwork() async {
        do {
            _ = try await APIClient.failing.health()
            XCTFail("Le client `failing` a répondu au lieu d'échouer.")
        } catch let error as CertigoError {
            XCTAssertEqual(error, .network)
        } catch {
            XCTFail("Erreur inattendue : \(error)")
        }
    }

    /// Le témoin se remplace champ par champ, sans classe de simulation.
    func testWitnessIsSubstitutable() async throws {
        let client = APIClient(health: { true })
        let result = try await client.health()
        XCTAssertTrue(result)
    }
}
