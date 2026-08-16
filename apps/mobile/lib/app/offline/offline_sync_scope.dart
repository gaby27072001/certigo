import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data/data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Drains the offline action queue whenever the app regains connectivity, is
/// resumed from the background, or starts up.
///
/// It lives above [CertigoApp] so a single lifecycle observer and a single
/// connectivity subscription cover the whole session. It is a pure side-effect
/// wrapper: it renders [child] unchanged and only ever *reads* the sync engine
/// to flush it, never mutating UI state.
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
    unawaited(
      _engine.flush().catchError((Object error, StackTrace stackTrace) {
        _reportError(error, stackTrace, 'while flushing the offline queue');
        return SyncFlushReport(
          dispatched: 0,
          succeeded: 0,
          retried: 0,
          deadLettered: 0,
          pendingRemaining: _engine.pendingCount,
        );
      }),
    );
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
  Widget build(BuildContext context) => widget.child;
}
