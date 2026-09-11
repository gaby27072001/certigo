import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data/data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../providers.dart';
import '../session_resume_store.dart';
import '../content/runtime_content_providers.dart';

/// Drains the offline action queue whenever the app regains connectivity, is
/// resumed from the background, or finishes restoring an authenticated session.
///
/// It lives above [CertigoApp] so a single lifecycle observer and a single
/// connectivity subscription cover the whole session. It is a pure side-effect
/// wrapper: it renders [child] unchanged while flushing the generic queue and
/// the account-scoped active-track mutation.
///
/// This widget is wired only in production [bootstrap]; widget tests build the
/// app without it, so they never touch the connectivity platform channel.
class OfflineSyncScope extends ConsumerStatefulWidget {
  const OfflineSyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineSyncScope> createState() => _OfflineSyncScopeState();
}

class _OfflineSyncScopeState extends ConsumerState<OfflineSyncScope> with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  late final SyncEngine _engine;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = ref.read(syncEngineProvider);
    _connectivity = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error, StackTrace stackTrace) {
        _reportError(error, stackTrace, 'while observing connectivity');
      },
    );
    // Drain anything queued during a previous offline session, once at startup.
    _flush();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_disposed) return;
    final bool isOnline = results.any(
      (ConnectivityResult result) => result != ConnectivityResult.none,
    );
    if (isOnline) {
      _flush();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _flush();
    }
  }

  void _flush() {
    if (_disposed) return;
    final AuthState auth = ref.read(authControllerProvider);
    if (!canFlushOfflineActions(auth)) return;
    unawaited(
      _flushAuthenticated(auth as Authenticated).catchError((Object error, StackTrace stackTrace) {
        _reportError(error, stackTrace, 'while flushing the offline queue');
      }),
    );
  }

  Future<void> _flushAuthenticated(Authenticated auth) async {
    final List<Future<void>> operations = <Future<void>>[
      _engine.flush().then<void>((SyncFlushReport _) {}),
      ref.read(activeTrackProvider.notifier).syncPending(),
    ];
    if (ref.read(runtimeContentSyncEnabledProvider)) {
      final String? ownerId = auth.session.userId;
      if (ownerId != null && ownerId.isNotEmpty) {
        operations.add(
          ref.read(runtimeContentControllerProvider.notifier).syncNow(ownerId),
        );
      }
    }
    await Future.wait<void>(operations);
    await _dropResumeRecordsTheQueueHasSettled();
  }

  /// Retires a resume record once the queue has delivered the attempt it names.
  ///
  /// Without this, a submission that was queued offline and replayed by the
  /// engine — while the learner never reopened the quiz — would leave its
  /// record behind, and reopening the lesson later would resume a session the
  /// server has already graded. No points are at stake: `QuizService` returns
  /// the stored result for a known key, so the replayed submission is refused
  /// as the duplicate it is. What is at stake is the learner replaying a run
  /// for nothing.
  Future<void> _dropResumeRecordsTheQueueHasSettled() async {
    if (_disposed) return;
    final SessionResumeStore store = ref.read(sessionResumeStoreProvider);
    for (final ResumeSurface surface in resumeSurfacesSettledByQueue(
      store: store,
      actions: _engine.actions,
    )) {
      await store.clear(surface);
    }
  }

  void _reportError(Object error, StackTrace stackTrace, String operation) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'certigo.offline-sync',
        context: ErrorDescription(operation),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_connectivity?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (_, AuthState next) {
      if (next is Authenticated) _flush();
    });
    return widget.child;
  }
}

bool canFlushOfflineActions(AuthState auth) => auth is Authenticated;

/// Which surfaces' resume records the offline queue has made obsolete.
///
/// A record is retired once the action carrying its `clientAttemptId` is
/// **done**: the server accepted that attempt, so the session it describes is
/// finished and replaying it could only produce a duplicate.
///
/// A **dead-lettered** action deliberately does not retire anything. It was
/// never applied server-side, so the learner may still resume and finish — and
/// reusing the same key is safe precisely because nothing was counted.
///
/// Pure and top-level so it is testable without a widget tree, like
/// [canFlushOfflineActions].
List<ResumeSurface> resumeSurfacesSettledByQueue({
  required SessionResumeStore store,
  required List<SyncAction> actions,
}) {
  final Set<String> delivered = <String>{
    for (final SyncAction action in actions)
      if (action.isDone) action.idempotencyKey,
  };
  if (delivered.isEmpty) return const <ResumeSurface>[];
  return <ResumeSurface>[
    for (final ResumeSurface surface in ResumeSurface.values)
      if (delivered.contains(store.read(surface)?.clientAttemptId)) surface,
  ];
}
