import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data/data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../providers.dart';
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
