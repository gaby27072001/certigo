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

  static const String _key = 'microlingo.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final String? raw = await _storage.read(key: _key);
    return AuthSession.decode(raw);
  }

  @override
  Future<void> write(AuthSession session) {
    return _storage.write(key: _key, value: session.encode());
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _key);
  }
}
