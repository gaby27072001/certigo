import '../features/auth/application/auth_state.dart';
import '../features/deep_links/application/deep_link_contract.dart';
import 'auth_redirect.dart';

/// Coordinates validated HTTPS links with the existing auth/onboarding guard.
///
/// Only internal locations produced by [DeepLinkPolicy] are retained. Raw URLs
/// and query parameters are never persisted or replayed after authentication.
final class DeepLinkRouterCoordinator {
  DeepLinkRouterCoordinator({this.policy = const DeepLinkPolicy()});

  final DeepLinkPolicy policy;
  String? _pendingLocation;
  String? _lastIngressUri;

  String? get pendingLocation => _pendingLocation;

  String? redirect({
    required Uri uri,
    required String location,
    required AuthState auth,
    required bool onboardingCompleted,
  }) {
    final DeepLinkParseResult? link = _parseIncoming(uri);
    if (link != null) {
      final DeepLinkDestination? destination = link.destination;
      if (destination == null) {
        _pendingLocation = null;
        return _safeFallback(
          auth: auth,
          location: location,
          onboardingCompleted: onboardingCompleted,
        );
      }

      if (destination.requiresAuthentication && (auth is! Authenticated || !onboardingCompleted)) {
        _pendingLocation = destination.appLocation;
        return resolveAuthRedirect(
              auth: auth,
              location: location,
              onboardingCompleted: onboardingCompleted,
            ) ??
            _safeFallback(auth: auth, location: location, onboardingCompleted: onboardingCompleted);
      }

      _pendingLocation = null;
      return destination.appLocation == location ? null : destination.appLocation;
    }

    if (auth is Authenticated &&
        onboardingCompleted &&
        !AuthShellRoutes.isRegisterFlow(location) &&
        _pendingLocation != null) {
      final String pending = _pendingLocation!;
      _pendingLocation = null;
      return pending == location ? null : pending;
    }

    return resolveAuthRedirect(
      auth: auth,
      location: location,
      onboardingCompleted: onboardingCompleted,
    );
  }

  DeepLinkParseResult? _parseIncoming(Uri uri) {
    final bool isAbsoluteWebLink = uri.hasScheme &&
        (uri.scheme.toLowerCase() == 'https' || uri.scheme.toLowerCase() == 'http');
    final bool isRelativeIngress = !uri.hasScheme && policy.isPotentialRouterPath(uri.path);
    if (!isAbsoluteWebLink && !isRelativeIngress) {
      _lastIngressUri = null;
      return null;
    }

    final String ingressKey = uri.toString();
    if (_lastIngressUri == ingressKey) {
      return null;
    }
    _lastIngressUri = ingressKey;

    if (uri.hasScheme) {
      return policy.parseRouterUri(uri);
    }
    return policy.parseRouterUri(uri);
  }

  String _safeFallback({
    required AuthState auth,
    required String location,
    required bool onboardingCompleted,
  }) {
    final String? guarded = resolveAuthRedirect(
      auth: auth,
      location: location,
      onboardingCompleted: onboardingCompleted,
    );
    if (guarded != null) return guarded;
    if (auth is Authenticated && onboardingCompleted) {
      return AuthShellRoutes.home;
    }
    if (auth is Authenticated) {
      return AuthShellRoutes.onboardingSplash;
    }
    if (auth is AuthLoading || auth is AuthSigningOut) {
      return AuthShellRoutes.splash;
    }
    return AuthShellRoutes.landing;
  }
}
