import 'dart:convert';

import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secure-session payload preserves the account id used to scope offline data', () {
    const AuthSession session = AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      userId: 'user-1',
      provider: AuthProvider.email,
    );

    final AuthSession? restored = AuthSession.decode(session.encode());

    expect(restored?.userId, 'user-1');
    expect(restored?.provider, AuthProvider.email);
  });

  test('legacy secure-session payload recovers its owner from JWT claims', () {
    final String payload = base64Url
        .encode(utf8.encode(jsonEncode(<String, String>{'oid': 'legacy-user'})))
        .replaceAll('=', '');
    final String token = 'header.$payload.signature';

    final AuthSession? restored = AuthSession.fromJson(<String, dynamic>{
      'accessToken': token,
      'provider': 'email',
    });

    expect(restored?.userId, 'legacy-user');
  });
}
