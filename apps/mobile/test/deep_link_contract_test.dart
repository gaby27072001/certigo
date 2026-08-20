import 'package:certigo/features/deep_links/application/deep_link_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String controlledTestHost = 'links.user-owned.example';
  const DeepLinkPolicy enabledPolicy = DeepLinkPolicy(
    enabled: true,
    primaryHost: controlledTestHost,
  );

  group('HTTPS deep-link parsing', () {
    test('is disabled by default', () {
      const DeepLinkPolicy policy = DeepLinkPolicy(primaryHost: controlledTestHost);

      final DeepLinkParseResult result = policy.parse(
        'https://$controlledTestHost/learn/az-900/shared-responsibility',
      );

      expect(result.rejection, DeepLinkRejection.disabled);
    });

    test('maps the canonical lesson URL to the existing lesson route', () {
      final DeepLinkParseResult result = enabledPolicy.parse(
        'https://$controlledTestHost/learn/az-900/shared-responsibility',
      );

      expect(result.isAccepted, isTrue);
      expect(result.destination!.kind, DeepLinkKind.lesson);
      expect(result.destination!.appLocation, '/lesson/az-900/shared-responsibility');
      expect(result.destination!.requiresAuthentication, isTrue);
    });

    test('supports achievement and public account-deletion contracts', () {
      final DeepLinkDestination achievement =
          enabledPolicy.parse('https://$controlledTestHost/achievements/first-lesson').destination!;
      final DeepLinkDestination deletion =
          enabledPolicy.parse('https://$controlledTestHost/account-deletion').destination!;

      expect(achievement.appLocation, '/achievements/first-lesson');
      expect(achievement.requiresAuthentication, isTrue);
      expect(deletion.appLocation, '/account-deletion');
      expect(deletion.requiresAuthentication, isFalse);
    });

    test('generates canonical share URLs without carrying arbitrary parameters', () {
      const DeepLinkDestination lesson = DeepLinkDestination.lesson(
        trackId: 'az-900',
        lessonId: 'identity-basics',
      );

      expect(
        lesson.toHttpsUri(host: controlledTestHost).toString(),
        'https://$controlledTestHost/learn/az-900/identity-basics',
      );
    });
  });

  group('authentication boundary', () {
    test('does not navigate to a protected route before authentication', () {
      final DeepLinkNavigationDecision decision = enabledPolicy.resolveNavigation(
        rawUrl: 'https://$controlledTestHost/assignments/assignment-42',
        isAuthenticated: false,
      );

      expect(decision.action, DeepLinkNavigationAction.requireAuthentication);
      expect(decision.location, isNull);
      expect(decision.pendingLocation, '/assignments/assignment-42');
    });

    test('allows a protected route only after authentication', () {
      final DeepLinkNavigationDecision decision = enabledPolicy.resolveNavigation(
        rawUrl: 'https://$controlledTestHost/achievements/first-lesson',
        isAuthenticated: true,
      );

      expect(decision.action, DeepLinkNavigationAction.navigate);
      expect(decision.location, '/achievements/first-lesson');
    });

    test('keeps account deletion public', () {
      final DeepLinkNavigationDecision decision = enabledPolicy.resolveNavigation(
        rawUrl: 'https://$controlledTestHost/account-deletion',
        isAuthenticated: false,
      );

      expect(decision.action, DeepLinkNavigationAction.navigate);
      expect(decision.location, '/account-deletion');
    });
  });

  group('Flutter router input', () {
    test('accepts a relative native route without weakening origin parsing', () {
      final DeepLinkParseResult result = enabledPolicy.parseRouterUri(
        Uri.parse('/learn/az-900/shared-responsibility'),
      );

      expect(result.destination!.appLocation, '/lesson/az-900/shared-responsibility');
      expect(
        enabledPolicy.parse('https://evil.example/learn/az-900/shared-responsibility').rejection,
        DeepLinkRejection.untrustedOrigin,
      );
    });

    test('rejects relative redirect parameters', () {
      expect(
        enabledPolicy
            .parseRouterUri(Uri.parse('/assignments/a?next=https://evil.example'))
            .rejection,
        DeepLinkRejection.unexpectedParameters,
      );
    });
  });

  group('origin and open-redirect hardening', () {
    test('rejects non-HTTPS and foreign origins', () {
      expect(
        enabledPolicy.parse('http://$controlledTestHost/assignments/a').rejection,
        DeepLinkRejection.insecureScheme,
      );
      expect(
        enabledPolicy.parse('https://$controlledTestHost.evil.example/assignments/a').rejection,
        DeepLinkRejection.untrustedOrigin,
      );
      expect(
        enabledPolicy.parse('https://$controlledTestHost@evil.example/assignments/a').rejection,
        DeepLinkRejection.untrustedOrigin,
      );
    });

    test('rejects the uncontrolled domain even when explicitly configured', () {
      const DeepLinkPolicy uncontrolledPolicy = DeepLinkPolicy(
        enabled: true,
        primaryHost: 'certigo.app',
      );

      expect(
        uncontrolledPolicy.parse('https://certigo.app/assignments/a').rejection,
        DeepLinkRejection.unconfiguredHost,
      );
    });

    test('rejects the inert placeholder even when the feature flag is enabled', () {
      const DeepLinkPolicy inertPolicy = DeepLinkPolicy(
        enabled: true,
        primaryHost: certigoConfiguredLinkHost,
      );

      expect(
        inertPolicy.parse('https://links-disabled.invalid/assignments/a').rejection,
        DeepLinkRejection.unconfiguredHost,
      );
    });

    test('rejects redirect parameters, fragments, ports, and unsupported paths', () {
      expect(
        enabledPolicy
            .parse('https://$controlledTestHost/assignments/a?redirect=https://evil.example')
            .rejection,
        DeepLinkRejection.unexpectedParameters,
      );
      expect(
        enabledPolicy
            .parse('https://$controlledTestHost/assignments/a#https://evil.example')
            .rejection,
        DeepLinkRejection.unexpectedParameters,
      );
      expect(
        enabledPolicy.parse('https://$controlledTestHost:443/assignments/a').rejection,
        DeepLinkRejection.untrustedOrigin,
      );
      expect(
        enabledPolicy.parse('https://$controlledTestHost/unknown/a').rejection,
        DeepLinkRejection.unsupportedPath,
      );
    });

    test('rejects traversal and encoded separators in identifiers', () {
      expect(
        enabledPolicy.parse('https://$controlledTestHost/assignments/..').rejection,
        isNotNull,
      );
      expect(
        enabledPolicy
            .parse('https://$controlledTestHost/learn/az-900%2F..%2Fadmin/lesson')
            .rejection,
        DeepLinkRejection.invalidIdentifier,
      );
      expect(
        enabledPolicy.parse('https://$controlledTestHost/assignments/a%5Cb').rejection,
        DeepLinkRejection.invalidIdentifier,
      );
    });
  });
}
