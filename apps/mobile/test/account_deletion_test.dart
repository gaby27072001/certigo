import 'dart:async';
import 'dart:convert';

import 'package:certigo/app/account_deletion_resume_scope.dart';
import 'package:certigo/app/active_track_store.dart';
import 'package:certigo/app/offline/prefs_sync_store.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

class _AuthGateway implements AuthGateway {
  _AuthGateway(this.session);

  AuthSession session;
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
  _DeletionRepository({
    required this.status,
    required this.requestResult,
    this.request,
  });

  AccountDeletion status;
  Result<AccountDeletion> requestResult;
  final Future<Result<AccountDeletion>> Function()? request;
  int requestCalls = 0;
  int statusCalls = 0;
  String? proofToken;

  @override
  Future<Result<AccountDeletion>> getStatus() async {
    statusCalls++;
    return Success<AccountDeletion>(status);
  }

  @override
  Future<Result<AccountDeletion>> requestDeletion({String? reauthenticationToken}) async {
    requestCalls++;
    proofToken = reauthenticationToken;
    return request?.call() ?? requestResult;
  }
}

class _Purger implements LocalAccountDataPurger {
  _Purger({this.fail = false});

  int calls = 0;
  bool fail;
  String? personId;
  bool? serverConfirmed;

  @override
  Future<void> purge({
    required String personId,
    required bool serverConfirmed,
  }) async {
    calls++;
    this.personId = personId;
    this.serverConfirmed = serverConfirmed;
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
    _AuthGateway? authGateway,
  }) {
    final AuthSession fresh = reauthenticatedSession ?? socialSession();
    final _AuthGateway gateway = authGateway ?? _AuthGateway(fresh);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(gateway),
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
        ownerIdProvider: () => 'user-1',
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
    expect(purger.personId, 'user-1');
    expect(purger.serverConfirmed, isTrue);
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

  test('local purge is never invoked before server confirmation', () async {
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Success<AccountDeletion>(pending),
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

    expect(purger.calls, 0);
    expect(purger.serverConfirmed, isNull);
  });

  test('person-scoped purge preserves another person quarantine and global preferences', () async {
    const String personAKey = '$kSyncQueueQuarantinePrefsPrefix.person-a';
    const String personBKey = '$kSyncQueueQuarantinePrefsPrefix.person-b';
    SharedPreferences.setMockInitialValues(<String, Object>{
      personAKey: jsonEncode(<String, dynamic>{
        'schema': 'certigo.sync.queue-quarantine/v1',
        'ownerId': 'person-a',
      }),
      personBKey: jsonEncode(<String, dynamic>{
        'schema': 'certigo.sync.queue-quarantine/v1',
        'ownerId': 'person-b',
      }),
      'global-setting': 'preserved',
    });
    final InMemoryRuntimeContentStore runtimeStore = InMemoryRuntimeContentStore();
    final RuntimeContentPinRegistry pins = RuntimeContentPinRegistry();
    final InMemoryActiveTrackStore activeTrack =
        InMemoryActiveTrackStore.synced('track-b', ownerId: 'person-b');
    final PersonScopedAccountDataPurger purger = PersonScopedAccountDataPurger(
      RuntimeContentPersonPurger(store: runtimeStore, pins: pins),
      activeTrackStore: activeTrack,
    );

    await expectLater(
      purger.purge(personId: 'person-a', serverConfirmed: false),
      throwsStateError,
    );
    await purger.purge(personId: 'person-a', serverConfirmed: true);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(personAKey), isFalse);
    expect(preferences.containsKey(personBKey), isTrue);
    expect(preferences.getString('global-setting'), 'preserved');
    expect(activeTrack.read()!.ownerId, 'person-b');
  });

  test('person-scoped purge clears only the confirmed person active track', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final InMemoryActiveTrackStore activeTrack =
        InMemoryActiveTrackStore.synced('track-a', ownerId: 'person-a');
    final PersonScopedAccountDataPurger purger = PersonScopedAccountDataPurger(
      RuntimeContentPersonPurger(
        store: InMemoryRuntimeContentStore(),
        pins: RuntimeContentPinRegistry(),
      ),
      activeTrackStore: activeTrack,
    );

    await purger.purge(personId: 'person-a', serverConfirmed: true);

    expect(activeTrack.read(), isNull);
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

  test('account switch during deletion response never purges the new person', () async {
    final Completer<Result<AccountDeletion>> response = Completer<Result<AccountDeletion>>();
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Success<AccountDeletion>(completed),
      request: () => response.future,
    );
    final _SessionStore store = _SessionStore(socialSession());
    final _Purger purger = _Purger();
    final _AuthGateway gateway = _AuthGateway(socialSession());
    final ProviderContainer container = containerFor(
      repository: repository,
      store: store,
      purger: purger,
      sync: syncEngine(),
      authGateway: gateway,
    );
    final AuthController auth = container.read(authControllerProvider.notifier);
    container.read(authControllerProvider);
    await settle();
    await settle();
    await settle();

    final Future<void> deletion =
        container.read(accountDeletionControllerProvider.notifier).start(expectedUserId: 'user-1');
    await settle();
    await auth.signOut();
    gateway.session = const AuthSession(
      accessToken: 'other-access',
      userId: 'user-2',
      idToken: 'other-id-token',
      provider: AuthProvider.microsoft,
    );
    await auth.signIn(AuthProvider.microsoft);
    response.complete(const Success<AccountDeletion>(completed));
    await deletion;

    expect(purger.calls, 0);
    expect(container.read(authControllerProvider), isA<Authenticated>());
    expect((container.read(authControllerProvider) as Authenticated).session.userId, 'user-2');
    expect(container.read(accountDeletionControllerProvider).stage, AccountDeletionStage.failure);

    await container.read(accountDeletionControllerProvider.notifier).retry();

    expect(repository.requestCalls, 1);
    expect(purger.calls, 0);
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

  const AuthSession appleSession = AuthSession(
    accessToken: 'apple-access',
    userId: 'user-1',
    idToken: 'fresh-apple-id-token',
    refreshToken: 'apple-refresh',
    provider: AuthProvider.apple,
  );

  Future<ProviderContainer> completedDeletionFor(AuthSession session) async {
    final _DeletionRepository repository = _DeletionRepository(
      status: notRequested,
      requestResult: const Success<AccountDeletion>(completed),
    );
    final ProviderContainer container = containerFor(
      repository: repository,
      store: _SessionStore(session),
      purger: _Purger(),
      sync: syncEngine(),
      reauthenticatedSession: session,
    );
    container.read(authControllerProvider);
    await settle();
    await settle();
    await settle();
    await container
        .read(accountDeletionControllerProvider.notifier)
        .start(expectedUserId: 'user-1');
    return container;
  }

  test('completion remembers an Apple sign-in once the session is cleared', () async {
    final ProviderContainer container = await completedDeletionFor(appleSession);

    final AuthState state = container.read(authControllerProvider);
    expect(state, isA<AccountDeletionCompleted>());
    expect((state as AccountDeletionCompleted).provider, AuthProvider.apple);
  });

  testWidgets('Apple accounts are told how to revoke Certigo from their Apple Account', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await tester.runAsync(
      () => completedDeletionFor(appleSession),
    ) as ProviderContainer;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountDeletionCompletedScreen()),
      ),
    );

    expect(find.byKey(const Key('account-deletion-apple-revocation')), findsOneWidget);
    expect(find.textContaining('Touchez « Se connecter avec Apple »'), findsOneWidget);
    expect(find.textContaining('touchez « Supprimer »'), findsOneWidget);
    expect(find.textContaining('account.apple.com'), findsOneWidget);
  });

  testWidgets('other accounts complete without an Apple step', (WidgetTester tester) async {
    final ProviderContainer container = await tester.runAsync(
      () => completedDeletionFor(socialSession()),
    ) as ProviderContainer;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountDeletionCompletedScreen()),
      ),
    );

    expect(find.text('Compte supprimé'), findsOneWidget);
    expect(find.byKey(const Key('account-deletion-apple-revocation')), findsNothing);
  });

  testWidgets('Apple accounts are warned of the Apple step before confirming', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(_AuthGateway(appleSession)),
          credentialsGatewayProvider.overrideWithValue(_CredentialsGateway(appleSession)),
          sessionStoreProvider.overrideWithValue(_SessionStore(appleSession)),
          authRequiredProvider.overrideWithValue(true),
          authConfiguredProvider.overrideWithValue(true),
          accountDeletionRepositoryProvider.overrideWithValue(_DeletionRepository(
            status: notRequested,
            requestResult: const Success<AccountDeletion>(pending),
          )),
          localAccountDataPurgerProvider.overrideWithValue(_Purger()),
          syncEngineProvider.overrideWithValue(syncEngine()),
        ],
        child: const MaterialApp(home: AccountDeletionScreen(expectedUserId: 'user-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-deletion-apple-notice')), findsOneWidget);
    expect(find.byKey(const Key('account-deletion-password')), findsNothing);
  });

  group('deletion recovery probe', () {
    Future<_DeletionRepository> pumpScope(WidgetTester tester, {required bool enabled}) async {
      final _DeletionRepository repository = _DeletionRepository(
        status: notRequested,
        requestResult: const Success<AccountDeletion>(notRequested),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            accountDeletionEnabledProvider.overrideWithValue(enabled),
            accountDeletionRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: AccountDeletionResumeScope(child: Text('shell')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('a build without account deletion never calls the deletion API', (
      WidgetTester tester,
    ) async {
      final _DeletionRepository repository = await pumpScope(tester, enabled: false);

      expect(repository.statusCalls, 0);
      expect(find.text('shell'), findsOneWidget);
    });

    testWidgets('a build with account deletion checks for a durable request once', (
      WidgetTester tester,
    ) async {
      final _DeletionRepository repository = await pumpScope(tester, enabled: true);

      expect(repository.statusCalls, 1);
      expect(find.text('shell'), findsOneWidget);
    });
  });
}
