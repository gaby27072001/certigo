// Fixture for .github/sast/rules/dart-security.yaml — randomness, crypto and secret rules.
// Every credential-looking literal below is fake and exists only to exercise the rules.
import 'dart:math';
import 'dart:math' as math;

void crypto(List<int> bytes, List<int> key) {
  // ruleid: dart-insecure-random
  final int weak = Random().nextInt(0x7fffffff);

  // ruleid: dart-insecure-random
  final Random clockSeeded = Random(DateTime.now().millisecondsSinceEpoch);

  // ruleid: dart-insecure-random
  final Random prefixed = math.Random();

  // ok: dart-insecure-random
  final int strong = Random.secure().nextInt(0x7fffffff);

  // ok: dart-insecure-random
  final Random deterministic = Random(42);

  // ruleid: dart-weak-hash-algorithm
  final Digest legacy = md5.convert(bytes);

  // ruleid: dart-weak-hash-algorithm
  final Hmac mac = Hmac(sha1, key);

  // ok: dart-weak-hash-algorithm
  final Digest modern = sha256.convert(bytes);

  // ruleid: dart-weak-cipher-mode
  final Encrypter ecb = Encrypter(AES(aesKey, mode: AESMode.ecb));

  // ok: dart-weak-cipher-mode
  final Encrypter gcm = Encrypter(AES(aesKey, mode: AESMode.gcm));
}

class Secrets {
  // ruleid: dart-hardcoded-credential
  static const String clientSecret = 'fixture0only0NOTaSECRET0123';

  // ruleid: dart-hardcoded-credential
  final String apiKey = 'fixture-api-key-0000-1111-2222';

  // ok: dart-hardcoded-credential
  static const String _tokenKey = 'certigo.session.v1';

  // ok: dart-hardcoded-credential
  static const String passwordLabel = 'Mot de passe';

  // ok: dart-hardcoded-credential
  static const String password = 'password';

  // ok: dart-hardcoded-credential
  static const String accessToken = '';

  void assign(Config config) {
    // ruleid: dart-hardcoded-credential
    config.clientSecret = 'fixture0only0NOTaSECRET0456';

    // ruleid: dart-hardcoded-credential
    final Credentials credentials = Credentials(password: 'fixture0only0Password789');

    // ruleid: dart-hardcoded-credential
    final Map<String, String> form = <String, String>{'client_secret': 'fixture0only0Secret789xx'};

    // ok: dart-hardcoded-credential
    final Credentials prompt = Credentials(password: passwordController.text, hasToken: 'fixture0only0bool0123');

    // ruleid: dart-hardcoded-credential
    clientSecret = 'fixture0only0NOTaSECRET0789';

    // ok: dart-hardcoded-credential
    config.clientSecret = String.fromEnvironment('ENTRA_CLIENT_SECRET');
  }

  // ruleid: dart-hardcoded-credential
  static const String fromEnvironment = String.fromEnvironment('API_TOKEN', defaultValue: 'fixture0only0token0123');

  // ok: dart-hardcoded-credential
  static const String fromEnvironmentEmpty = String.fromEnvironment('API_TOKEN', defaultValue: '');

  // ok: dart-hardcoded-credential
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api0.certigo.example');
}
