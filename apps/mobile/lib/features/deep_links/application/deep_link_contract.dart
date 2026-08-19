/// Canonical HTTPS deep-link contract for Certigo.
///
/// Native association is deliberately independent from this runtime flag. A
/// release must enable both layers before HTTPS links can navigate in the app.
const bool certigoHttpsLinksEnabled = bool.fromEnvironment(
  'CERTIGO_HTTPS_LINKS_ENABLED',
  defaultValue: false,
);

const String certigoPrimaryLinkHost = 'certigo.app';
const String certigoPagesFallbackHost = 'gchambaud_microsoft.github.io';
const String certigoPagesFallbackPrefix = '/Certigo';

final RegExp _identifierPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');

enum DeepLinkKind { lesson, assignment, achievement, accountDeletion }

enum DeepLinkRejection {
  disabled,
  malformedUri,
  insecureScheme,
  untrustedOrigin,
  unexpectedParameters,
  unsupportedPath,
  invalidIdentifier,
}

enum DeepLinkNavigationAction { navigate, requireAuthentication, ignore }

final class DeepLinkDestination {
  const DeepLinkDestination._({required this.kind, this.trackId, this.resourceId});

  const DeepLinkDestination.lesson({required String trackId, required String lessonId})
      : this._(kind: DeepLinkKind.lesson, trackId: trackId, resourceId: lessonId);

  const DeepLinkDestination.assignment(String assignmentId)
      : this._(kind: DeepLinkKind.assignment, resourceId: assignmentId);

  const DeepLinkDestination.achievement(String achievementId)
      : this._(kind: DeepLinkKind.achievement, resourceId: achievementId);

  const DeepLinkDestination.accountDeletion() : this._(kind: DeepLinkKind.accountDeletion);

  final DeepLinkKind kind;
  final String? trackId;
  final String? resourceId;

  bool get requiresAuthentication => kind != DeepLinkKind.accountDeletion;

  String get appLocation => switch (kind) {
        DeepLinkKind.lesson =>
          '/lesson/${Uri.encodeComponent(trackId!)}/${Uri.encodeComponent(resourceId!)}',
        DeepLinkKind.assignment => '/assignments/${Uri.encodeComponent(resourceId!)}',
        DeepLinkKind.achievement => '/achievements/${Uri.encodeComponent(resourceId!)}',
        DeepLinkKind.accountDeletion => '/account-deletion',
      };

  Uri toHttpsUri({String host = certigoPrimaryLinkHost, String pathPrefix = ''}) {
    final String prefix =
        pathPrefix.endsWith('/') ? pathPrefix.substring(0, pathPrefix.length - 1) : pathPrefix;
    final String path = switch (kind) {
      DeepLinkKind.lesson =>
        '$prefix/learn/${Uri.encodeComponent(trackId!)}/${Uri.encodeComponent(resourceId!)}',
      DeepLinkKind.assignment => '$prefix/assignments/${Uri.encodeComponent(resourceId!)}',
      DeepLinkKind.achievement => '$prefix/achievements/${Uri.encodeComponent(resourceId!)}',
      DeepLinkKind.accountDeletion => '$prefix/account-deletion',
    };
    return Uri(scheme: 'https', host: host, path: path);
  }
}

final class DeepLinkParseResult {
  const DeepLinkParseResult.accepted(this.destination) : rejection = null;

  const DeepLinkParseResult.rejected(this.rejection) : destination = null;

  final DeepLinkDestination? destination;
  final DeepLinkRejection? rejection;

  bool get isAccepted => destination != null;
}

final class DeepLinkNavigationDecision {
  const DeepLinkNavigationDecision._({
    required this.action,
    this.location,
    this.pendingLocation,
    this.rejection,
  });

  const DeepLinkNavigationDecision.navigate(String location)
      : this._(action: DeepLinkNavigationAction.navigate, location: location);

  const DeepLinkNavigationDecision.requireAuthentication(String pendingLocation)
      : this._(
          action: DeepLinkNavigationAction.requireAuthentication,
          pendingLocation: pendingLocation,
        );

  const DeepLinkNavigationDecision.ignore(DeepLinkRejection rejection)
      : this._(action: DeepLinkNavigationAction.ignore, rejection: rejection);

  final DeepLinkNavigationAction action;
  final String? location;
  final String? pendingLocation;
  final DeepLinkRejection? rejection;
}

final class DeepLinkPolicy {
  const DeepLinkPolicy({
    this.enabled = certigoHttpsLinksEnabled,
    this.primaryHost = certigoPrimaryLinkHost,
    this.pagesFallbackHost = certigoPagesFallbackHost,
    this.pagesFallbackPrefix = certigoPagesFallbackPrefix,
  });

  final bool enabled;
  final String primaryHost;
  final String pagesFallbackHost;
  final String pagesFallbackPrefix;

  DeepLinkParseResult parse(String rawUrl) {
    if (!enabled) {
      return const DeepLinkParseResult.rejected(DeepLinkRejection.disabled);
    }

    final Uri? uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return const DeepLinkParseResult.rejected(DeepLinkRejection.malformedUri);
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return const DeepLinkParseResult.rejected(DeepLinkRejection.insecureScheme);
    }
    if (uri.userInfo.isNotEmpty || uri.hasPort || _hasExplicitPort(rawUrl)) {
      return const DeepLinkParseResult.rejected(DeepLinkRejection.untrustedOrigin);
    }
    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      return const DeepLinkParseResult.rejected(DeepLinkRejection.unexpectedParameters);
    }

    final bool isPrimary = uri.host == primaryHost;
    final bool isPagesFallback = uri.host == pagesFallbackHost;
    if (!isPrimary && !isPagesFallback) {
      return const DeepLinkParseResult.rejected(DeepLinkRejection.untrustedOrigin);
    }

    List<String> segments = uri.pathSegments;
    if (isPagesFallback) {
      final List<String> prefixSegments = Uri(path: pagesFallbackPrefix).pathSegments;
      if (segments.length < prefixSegments.length || !_startsWith(segments, prefixSegments)) {
        return const DeepLinkParseResult.rejected(DeepLinkRejection.unsupportedPath);
      }
      segments = segments.sublist(prefixSegments.length);
    }

    final bool hasTrailingSlash = segments.isNotEmpty && segments.last.isEmpty;
    if (hasTrailingSlash) {
      segments = segments.sublist(0, segments.length - 1);
    }

    return _parsePath(segments, hasTrailingSlash: hasTrailingSlash);
  }

  /// Parses a URI supplied by Flutter's route-information pipeline.
  ///
  /// Android and iOS can deliver either the absolute HTTPS URI or only its path.
  /// Relative paths are safe here because the native association layer admits
  /// only the configured HTTPS host; custom schemes remain absolute and are
  /// rejected by the router coordinator before reaching this method.
  DeepLinkParseResult parseRouterUri(Uri uri) {
    if (uri.hasScheme || uri.hasAuthority) {
      return parse(uri.toString());
    }
    if (!enabled) {
      return const DeepLinkParseResult.rejected(DeepLinkRejection.disabled);
    }
    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      return const DeepLinkParseResult.rejected(DeepLinkRejection.unexpectedParameters);
    }

    final bool usesFallbackPrefix =
        uri.path == pagesFallbackPrefix || uri.path.startsWith('$pagesFallbackPrefix/');
    final Uri absolute = Uri(
      scheme: 'https',
      host: usesFallbackPrefix ? pagesFallbackHost : primaryHost,
      path: uri.path,
    );
    return parse(absolute.toString());
  }

  /// Whether [path] belongs to a declared HTTPS ingress route.
  ///
  /// This intentionally checks only route prefixes. Full shape and identifier
  /// validation still happens in [parseRouterUri].
  bool isPotentialRouterPath(String path) {
    final String candidate = path == pagesFallbackPrefix
        ? '/'
        : path.startsWith('$pagesFallbackPrefix/')
            ? path.substring(pagesFallbackPrefix.length)
            : path;
    return candidate.startsWith('/learn/') ||
        candidate.startsWith('/assignments/') ||
        candidate.startsWith('/achievements/') ||
        candidate == '/account-deletion' ||
        candidate == '/account-deletion/';
  }

  DeepLinkNavigationDecision resolveNavigation({
    required String rawUrl,
    required bool isAuthenticated,
  }) {
    final DeepLinkParseResult result = parse(rawUrl);
    final DeepLinkDestination? destination = result.destination;
    if (destination == null) {
      return DeepLinkNavigationDecision.ignore(result.rejection!);
    }
    if (destination.requiresAuthentication && !isAuthenticated) {
      return DeepLinkNavigationDecision.requireAuthentication(destination.appLocation);
    }
    return DeepLinkNavigationDecision.navigate(destination.appLocation);
  }

  DeepLinkParseResult _parsePath(List<String> segments, {required bool hasTrailingSlash}) {
    if (segments.length == 3 && segments.first == 'learn' && !hasTrailingSlash) {
      if (!_isValidIdentifier(segments[1]) || !_isValidIdentifier(segments[2])) {
        return const DeepLinkParseResult.rejected(DeepLinkRejection.invalidIdentifier);
      }
      return DeepLinkParseResult.accepted(
        DeepLinkDestination.lesson(trackId: segments[1], lessonId: segments[2]),
      );
    }
    if (segments.length == 2 && segments.first == 'assignments' && !hasTrailingSlash) {
      if (!_isValidIdentifier(segments[1])) {
        return const DeepLinkParseResult.rejected(DeepLinkRejection.invalidIdentifier);
      }
      return DeepLinkParseResult.accepted(DeepLinkDestination.assignment(segments[1]));
    }
    if (segments.length == 2 && segments.first == 'achievements' && !hasTrailingSlash) {
      if (!_isValidIdentifier(segments[1])) {
        return const DeepLinkParseResult.rejected(DeepLinkRejection.invalidIdentifier);
      }
      return DeepLinkParseResult.accepted(DeepLinkDestination.achievement(segments[1]));
    }
    if (segments.length == 1 && segments.first == 'account-deletion' && !hasTrailingSlash) {
      return const DeepLinkParseResult.accepted(DeepLinkDestination.accountDeletion());
    }
    return const DeepLinkParseResult.rejected(DeepLinkRejection.unsupportedPath);
  }
}

bool _startsWith(List<String> values, List<String> prefix) {
  for (int index = 0; index < prefix.length; index++) {
    if (values[index] != prefix[index]) return false;
  }
  return true;
}

bool _isValidIdentifier(String value) => _identifierPattern.hasMatch(value);

bool _hasExplicitPort(String rawUrl) {
  final int authorityStart = rawUrl.indexOf('://') + 3;
  if (authorityStart < 3) return false;
  final int authorityEnd = rawUrl.indexOf(RegExp(r'[/#?]'), authorityStart);
  final String authority = authorityEnd == -1
      ? rawUrl.substring(authorityStart)
      : rawUrl.substring(authorityStart, authorityEnd);
  return authority.contains(':');
}
