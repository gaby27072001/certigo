import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

/// Internal destination of a link opened from **outside** the app, or `null` to
/// ignore it.
///
/// iOS registers the `certigo://` scheme for the OIDC callback (`Info.plist`),
/// and Flutter 3.27+ hands the router every URL that opens the app: without this
/// allow-list, any web page or app could open any route (`/account/delete`,
/// `/enterprise/…`, a quiz with a crafted id). The OIDC callback never needs the
/// router: iOS delivers it to `ASWebAuthenticationSession`, Android to AppAuth's
/// `RedirectUriReceiverActivity`.
///
/// Allowed today: the share link `certigo://home?…` built by
/// `daily_share_screen.dart`, whose parameters the app does not read. A new
/// destination must come with its test in `external_link_guard_test.dart`.
String? externalLinkDestination(Uri link) {
  final bool customScheme = link.scheme == AppEnv.redirectScheme;
  final bool bareLocation = !link.hasScheme && !link.hasAuthority;
  if (customScheme && link.host == 'home' && (link.path.isEmpty || link.path == '/')) {
    return Routes.home;
  }
  if (bareLocation && link.path == Routes.home) {
    return Routes.home;
  }
  return null;
}

/// Handles every route the platform pushes (deep links, cold or warm) before
/// the router can: the binding stops at the first observer that returns true,
/// so GoRouter only ever receives the allow-listed internal destinations.
class ExternalLinkGuard with WidgetsBindingObserver {
  ExternalLinkGuard(this._go);

  final void Function(String location) _go;

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final String? destination = externalLinkDestination(routeInformation.uri);
    if (destination != null) _go(destination);
    return true;
  }
}

/// Installs [ExternalLinkGuard] for the lifetime of [child].
///
/// Must wrap `MaterialApp.router`: its `initState` runs before the `Router`
/// subscribes GoRouter's information provider to the binding, so the guard is
/// the first observer asked.
class ExternalLinkScope extends StatefulWidget {
  const ExternalLinkScope({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<ExternalLinkScope> createState() => _ExternalLinkScopeState();
}

class _ExternalLinkScopeState extends State<ExternalLinkScope> {
  late final ExternalLinkGuard _guard =
      ExternalLinkGuard((String location) => widget.router.go(location));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_guard);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_guard);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
