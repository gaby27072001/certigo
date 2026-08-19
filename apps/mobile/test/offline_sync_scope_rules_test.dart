import 'package:certigo/app/offline/offline_sync_scope.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline mutations flush only for an authenticated session', () {
    expect(canFlushOfflineActions(const AuthLoading()), isFalse);
    expect(canFlushOfflineActions(const AuthSigningOut()), isFalse);
    expect(canFlushOfflineActions(const Unauthenticated()), isFalse);
    expect(
      canFlushOfflineActions(
        const Authenticated(
          AuthSession(accessToken: 'token', userId: 'user-1'),
        ),
      ),
      isTrue,
    );
  });
}
