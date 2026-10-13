// Fixture for .github/sast/rules/dart-security.yaml — TLS / network rules.
// Never compiled: annotations drive `node .github/scripts/dart-sast.mjs test-rules`.
// A `ruleid:` line expects a finding of that rule on the next code line; `ok:` forbids one.
import 'dart:io';

void tls(HttpClient client, dynamic dio, dynamic options) {
  // ruleid: dart-tls-bad-certificate-callback
  client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

  // ruleid: dart-tls-bad-certificate-callback
  final HttpClient cascade = HttpClient()..badCertificateCallback = (cert, host, port) => true;

  // ruleid: dart-tls-bad-certificate-callback
  client.badCertificateCallback = (cert, host, port) => host == 'pinned.example.test';

  // ruleid: dart-tls-bad-certificate-callback
  dio.httpClientAdapter = IOHttpClientAdapter(validateCertificate: (cert, host, port) => true);

  // ok: dart-tls-bad-certificate-callback
  dio.httpClientAdapter = IOHttpClientAdapter(validateCertificate: (cert, host, port) => pin(cert));

  // ok: dart-tls-bad-certificate-callback
  final HttpClient plain = HttpClient();

  // ruleid: dart-tls-global-http-overrides
  HttpOverrides.global = InsecureOverrides();

  // ok: dart-tls-global-http-overrides
  HttpOverrides.runZoned(() => plain.close());

  // ruleid: dart-cleartext-http-url
  const String api = 'http://api.certigo.example/api';

  // ruleid: dart-cleartext-http-url
  final Uri uri = Uri.parse("http://cdn.certigo.example/content.json");

  // ok: dart-cleartext-http-url
  const String secure = 'https://api.certigo.example/api';

  // ok: dart-cleartext-http-url
  const String loopback = 'http://localhost:7071/api';

  // ok: dart-cleartext-http-url
  const String emulator = 'http://10.0.2.2:7071/api';

  // ok: dart-cleartext-http-url
  const String loopbackIp = 'http://127.0.0.1:8080';

  // ruleid: dart-oidc-allow-insecure-connections
  final AuthorizationTokenRequest insecure = AuthorizationTokenRequest(
    'client',
    'certigo://auth/',
    allowInsecureConnections: true,
  );

  // ok: dart-oidc-allow-insecure-connections
  final AuthorizationTokenRequest strict = AuthorizationTokenRequest(
    'client',
    'certigo://auth/',
    allowInsecureConnections: false,
  );
}
