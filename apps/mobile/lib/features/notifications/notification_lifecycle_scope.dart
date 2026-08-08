import 'dart:async';

import 'package:flutter/widgets.dart';

import 'notification_service.dart';

/// Keeps persisted reminders aligned with the device timezone without ever
/// prompting for notification permission during bootstrap or app resume.
class NotificationLifecycleScope extends StatefulWidget {
  const NotificationLifecycleScope({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationLifecycleScope> createState() =>
      _NotificationLifecycleScopeState();
}

class _NotificationLifecycleScopeState extends State<NotificationLifecycleScope>
    with WidgetsBindingObserver {
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh('while refreshing notifications at startup');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh('while refreshing notifications after app resume');
    }
  }

  void _refresh(String operation) {
    if (_disposed) return;
    unawaited(
      NotificationService.refreshTimezoneAndReschedule().catchError((
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
        return false;
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
  Widget build(BuildContext context) => widget.child;
}
