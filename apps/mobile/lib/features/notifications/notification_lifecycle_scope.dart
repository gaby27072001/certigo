import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'notification_service.dart';

/// Invalidates bounded local snapshots on startup, account changes and resume.
/// A fresh server plan is only scheduled after an explicit learner action.
class NotificationLifecycleScope extends ConsumerStatefulWidget {
  const NotificationLifecycleScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationLifecycleScope> createState() => _NotificationLifecycleScopeState();
}

class _NotificationLifecycleScopeState extends ConsumerState<NotificationLifecycleScope>
    with WidgetsBindingObserver {
  bool _disposed = false;
  bool _wasPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh('while refreshing notifications at startup', restoringSession: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _wasPaused = true;
    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      _refresh('while refreshing notifications after app resume');
    }
  }

  void _refresh(String operation, {bool restoringSession = false}) {
    if (_disposed) return;
    unawaited(
      NotificationService.reconcileLifecycle(ref.read(activeTrackOwnerIdProvider),
              restoringSession: restoringSession)
          .catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'certigo.notifications',
            context: ErrorDescription(operation),
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(activeTrackOwnerIdProvider, (String? previous, String? next) {
      if (previous != next) _refresh('while cancelling notifications after account change');
    });
    return widget.child;
  }
}
