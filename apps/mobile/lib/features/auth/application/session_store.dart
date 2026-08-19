import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_state.dart';

/// Persistance de la session entre deux lancements de l'application.
///
/// Interface dédiée car l'implémentation réelle ([SecureSessionStore]) utilise
/// `flutter_secure_storage` (Keychain iOS / Keystore Android), indisponible
/// sous `flutter test`. Les tests injectent un faux en mémoire.
abstract interface class SessionStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

/// Stockage chiffré de la session (jetons OIDC) via le coffre du système.
///
/// C'est ce qui permet à l'app de se rouvrir **directement sur le compte de
/// l'utilisateur** sans redemander de connexion.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const String _key = 'certigo.session.v1';
  static const String _signedOutKey = 'certigo.session.signed_out.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    try {
      final String? signedOut =
          await _storage.read(key: _signedOutKey).timeout(const Duration(seconds: 5));
      if (signedOut == 'true') return null;
      final String? raw = await _storage.read(key: _key).timeout(const Duration(seconds: 5));
      return AuthSession.decode(raw);
    } catch (_) {
      // Coffre indisponible ou bloqué (ex. Keystore Android au 1er accès) :
      // on dégrade en « pas de session » plutôt que de figer le démarrage.
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    await _storage.write(key: _key, value: session.encode()).timeout(const Duration(seconds: 5));
    await _storage.delete(key: _signedOutKey).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> clear() async {
    await _storage.write(key: _signedOutKey, value: 'true').timeout(const Duration(seconds: 5));
    try {
      await _storage.delete(key: _key).timeout(const Duration(seconds: 5));
    } catch (_) {
      // The tombstone already prevents restoration if physical deletion fails.
    }
  }
}
