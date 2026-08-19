import 'package:certigo/app/providers.dart';
import 'package:certigo/features/account_deletion/application/account_deletion_controller.dart';
import 'package:certigo/features/account_deletion/presentation/account_deletion_screen.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/application/credentials_gateway.dart';
import 'package:certigo/features/auth/application/session_store.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthGateway implements AuthGateway {
  _AuthGateway(this.session);

  final AuthSession session;
  int reauthenticationCalls = 0;

  @override
  Future<AuthSession> reauthenticate(AuthProvider provider) async {
    reauthenticationCalls++;
    return session;
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async => session;

  @override
  Future<AuthSession> signIn(AuthProvider provider) async => session;

  @override
  Future<void> signOut(AuthSession session) async {}
}

class _CredentialsGateway implements CredentialsGateway {
  _CredentialsGateway(this.session);

  final AuthSession session;

  @override
  Future<AuthSession> login({required String email, required String password}) async => session;

  @override
  Future<AuthSession> refresh(String refreshToken) async => session;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  }) async =>
      session;

  @override
  Future<void> resendVerification(String email) async {}
}

class _SessionStore implements SessionStore {
  _SessionStore(this.session);

  AuthSession? session;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    session = null;
  }

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async {
    this.session = session;
  }
}

class _DeletionRepository implements AccountDeletionRepository {
  _DeletionRepository({required this.status, required this.requestResult});

  AccountDeletion status;
  Result<AccountDeletion> requestResult;
  int requestCalls = 0;
  String? proofToken;

  @override
  Future<Result<AccountDeletion>> getStatus() async => Success<AccountDeletion>(status);

  @override
  Future<Result<AccountDeletion>> requestDeletion({String? reauthenticationToken}) async {
    requestCalls++;
    proofToken = reauthenticationToken;
    return requestResult;
  }
}

class _Purger implements LocalAccountDataPurger {
  _Purger({this.fail = false});

  int calls = 0;
  bool fail;

  @override
  Future<void> purge() async {
    calls++;
    if (fail) throw StateError('simulated local cleanup failure');
  }
}

void main() {
  test('account deletion remains disabled by default until the Cosmos gate passes', () {
    expect(AppEnv.accountDeletionEnabled, isFalse);
  });

  const AccountDeletion notRequested = AccountDeletion(
    status: AccountDeletionPhase.notRequested,
    completedSteps: 0,
    totalSteps: 6,
  );
  const AccountDeletion pending = AccountDeletion(
    status: AccountDeletionPhase.pending,
    completedSteps: 2,
    totalSteps: 6,
    failureCode: 'learning-data-delete-failed',
  );
  const AccountDeletion completed = AccountDeletion(
    status: AccountDeletionPhase.completed,
    completedSteps: 6,
    totalSteps: 6,
  );

  AuthSession socialSession() => const AuthSession(
        accessToken: 'access',
        userId: 'user-1',
        idToken: 'fresh-id-token',
        refreshToken: 'refresh',
        provider: AuthProvider.microsoft,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ProviderContainer containerFor({
    required _DeletionRepository repository,
    required _SessionStore store,
    required _Purger purger,
    required SyncEngine sync,
    AuthSession? reauthenticatedSession,
  }) {
    final AuthSession fresh = reauthenticatedSession ?? socialSession();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(_AuthGateway(fresh)),
        credentialsGatewayProvider.overrideWithValue(_CredentialsGateway(fresh)),
        sessionStoreProvider.overrideWithValue(store),
        authRequiredProvider.overrideWithValue(true),
        authConfiguredProvider.overrideWithValue(true),
        accountDeletionRepositoryProvider.overrideWithValue(repository),
        localAccountDataPurgerProvider.overrideWithValue(purger),
        syncEngineProvider.overrideWithValue(sync),
      ],
    );
    final ProviderSubscription<AccountDeletionState> subscription =
        container.listen<AccountDeletionState>(
      accountDeletionControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    addTearDown(container.dispose);
    return container;
  }

  SyncEngine syncEngine() => SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: (SyncAction _) async => SyncDispatch.success,
      );

  test('confirmed server completion purges local data and ends the session', () async {
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Success<AccountDeletion>(completed),
    );
    final _SessionStore store = _SessionStore(socialSession());
    final _Purger purger = _Purger();
    final SyncEngine sync = syncEngine();
    final ProviderContainer container = containerFor(
      repository: repository,
      store: store,
      purger: purger,
      sync: sync,
    );
    container.read(authControllerProvider);
    await settle();
    await settle();
    await settle();

    await container
        .read(accountDeletionControllerProvider.notifier)
        .start(expectedUserId: 'user-1');

    expect(repository.requestCalls, 1);
    expect(repository.proofToken, 'fresh-id-token');
    expect(purger.calls, 1);
    expect(store.clearCalls, 1);
    expect(container.read(authControllerProvider), isA<AccountDeletionCompleted>());
  });

  test('pending deletion preserves session and offline queue for a safe retry', () async {
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Success<AccountDeletion>(pending),
    );
    final _SessionStore store = _SessionStore(socialSession());
    final _Purger purger = _Purger();
    final SyncEngine sync = syncEngine();
    await sync.enqueue(
      kind: 'quiz-submit',
      endpoint: '/quiz/lesson/submit',
      payload: const <String, dynamic>{},
      idempotencyKey: 'attempt-1',
    );
    final ProviderContainer container = containerFor(
      repository: repository,
      store: store,
      purger: purger,
      sync: sync,
    );
    container.read(authControllerProvider);
    await settle();
    await settle();
    await settle();

    await container
        .read(accountDeletionControllerProvider.notifier)
        .start(expectedUserId: 'user-1');

    expect(container.read(accountDeletionControllerProvider).stage, AccountDeletionStage.pending);
    expect(sync.pendingCount, 1);
    expect(purger.calls, 0);
    expect(store.clearCalls, 0);
    expect(container.read(authControllerProvider), isA<Authenticated>());
  });

  test('network ambiguity never claims that deletion succeeded or failed to record', () async {
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Err<AccountDeletion>(NetworkFailure()),
    );
    final _SessionStore store = _SessionStore(socialSession());
    final _Purger purger = _Purger();
    final ProviderContainer container = containerFor(
      repository: repository,
      store: store,
      purger: purger,
      sync: syncEngine(),
    );
    container.read(authControllerProvider);
    await settle();
    await settle();
    await settle();

    await container
        .read(accountDeletionControllerProvider.notifier)
        .start(expectedUserId: 'user-1');

    final AccountDeletionState state = container.read(accountDeletionControllerProvider);
    expect(state.stage, AccountDeletionStage.failure);
    expect(state.message, contains('Impossible de confirmer'));
    expect(state.message, isNot(contains('supprimé')));
    expect(purger.calls, 0);
    expect(store.clearCalls, 0);
  });

  test('reauthentication for another subject fails closed before the API call', () async {
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Success<AccountDeletion>(completed),
    );
    final _SessionStore store = _SessionStore(socialSession());
    final _Purger purger = _Purger();
    final ProviderContainer container = containerFor(
      repository: repository,
      store: store,
      purger: purger,
      sync: syncEngine(),
      reauthenticatedSession: const AuthSession(
        accessToken: 'other-access',
        userId: 'other-user',
        idToken: 'other-id-token',
        provider: AuthProvider.microsoft,
      ),
    );
    container.read(authControllerProvider);
    await settle();
    await settle();
    await settle();

    await container
        .read(accountDeletionControllerProvider.notifier)
        .start(expectedUserId: 'user-1');

    expect(repository.requestCalls, 0);
    expect(
        container.read(accountDeletionControllerProvider).message, contains('ne correspond pas'));
    expect(purger.calls, 0);
    expect(store.clearCalls, 0);
  });

  test('server completion never hides a failed local cleanup', () async {
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Success<AccountDeletion>(completed),
    );
    final _SessionStore store = _SessionStore(socialSession());
    final _Purger purger = _Purger(fail: true);
    final ProviderContainer container = containerFor(
      repository: repository,
      store: store,
      purger: purger,
      sync: syncEngine(),
    );
    container.read(authControllerProvider);
    await settle();
    await settle();
    await settle();

    await container
        .read(accountDeletionControllerProvider.notifier)
        .start(expectedUserId: 'user-1');

    final AccountDeletionState state = container.read(accountDeletionControllerProvider);
    expect(state.stage, AccountDeletionStage.failure);
    expect(state.message, contains('serveur a confirmé'));
    expect(store.clearCalls, 0);
    expect(container.read(authControllerProvider), isA<Authenticated>());
  });

  testWidgets('confirmation is explicit and pending progress is accessible', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _DeletionRepository repository = _DeletionRepository(
      status: pending,
      requestResult: const Success<AccountDeletion>(pending),
    );
    final _SessionStore store = _SessionStore(socialSession());
    final _Purger purger = _Purger();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(_AuthGateway(socialSession())),
          credentialsGatewayProvider.overrideWithValue(_CredentialsGateway(socialSession())),
          sessionStoreProvider.overrideWithValue(store),
          authRequiredProvider.overrideWithValue(true),
          authConfiguredProvider.overrideWithValue(true),
          accountDeletionRepositoryProvider.overrideWithValue(repository),
          localAccountDataPurgerProvider.overrideWithValue(purger),
          syncEngineProvider.overrideWithValue(syncEngine()),
        ],
        child: const MaterialApp(home: AccountDeletionScreen(expectedUserId: 'user-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-deletion-progress')), findsOneWidget);
    final SemanticsNode progress = tester.getSemantics(
      find.byKey(const Key('account-deletion-progress-semantics')),
    );
    expect(progress.label, contains('2 étapes sur 6 terminées'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('email deletion requires acknowledgement and current password', (
    WidgetTester tester,
  ) async {
    const AuthSession emailSession = AuthSession(
      accessToken: 'email-access',
      userId: 'user-1',
      refreshToken: 'email-refresh',
      email: 'user@example.com',
      provider: AuthProvider.email,
    );
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Success<AccountDeletion>(pending),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(_AuthGateway(emailSession)),
          credentialsGatewayProvider.overrideWithValue(_CredentialsGateway(emailSession)),
          sessionStoreProvider.overrideWithValue(_SessionStore(emailSession)),
          authRequiredProvider.overrideWithValue(true),
          authConfiguredProvider.overrideWithValue(true),
          accountDeletionRepositoryProvider.overrideWithValue(repository),
          localAccountDataPurgerProvider.overrideWithValue(_Purger()),
          syncEngineProvider.overrideWithValue(syncEngine()),
        ],
        child: const MaterialApp(home: AccountDeletionScreen(expectedUserId: 'user-1')),
      ),
    );
    await tester.pumpAndSettle();

    FilledButton button = tester.widget<FilledButton>(
      find.byKey(const Key('account-deletion-confirm')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const Key('account-deletion-understood')));
    await tester.pump();
    button = tester.widget<FilledButton>(find.byKey(const Key('account-deletion-confirm')));
    expect(button.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('account-deletion-password')), 'correct-password');
    await tester.pump();
    button = tester.widget<FilledButton>(find.byKey(const Key('account-deletion-confirm')));
    expect(button.onPressed, isNotNull);
  });
}
