import 'package:certigo/features/manager/application/manager_models.dart';
import 'package:certigo/features/manager/application/manager_policy.dart';
import 'package:certigo/features/manager/application/manager_repository.dart';
import 'package:certigo/features/manager/application/manager_route_codec.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ManagerPolicy policy = ManagerPolicy();

  ManagerOrganizationContext context(
    ManagerOrganizationRole role, {
    String organizationId = FixtureManagerPortalRepository.fixtureOrganizationId,
  }) {
    return ManagerOrganizationContext(
      organizationId: organizationId,
      organizationName: 'Northstar',
      role: role,
    );
  }

  group('ManagerPolicy', () {
    for (final ManagerOrganizationRole role in <ManagerOrganizationRole>[
      ManagerOrganizationRole.owner,
      ManagerOrganizationRole.admin,
      ManagerOrganizationRole.manager,
    ]) {
      test('${role.name} can open the manager portal', () {
        expect(policy.canOpenPortal(context(role)), isTrue);
        expect(policy.canPerform(role, ManagerOperation.viewMetrics), isTrue);
        expect(
          policy.canPerform(role, ManagerOperation.manageAssignments),
          isTrue,
        );
      });
    }

    test('learner cannot open manager-only surfaces', () {
      final ManagerOrganizationContext learner = context(
        ManagerOrganizationRole.learner,
      );

      expect(policy.canOpenPortal(learner), isFalse);
      expect(
        policy.canPerform(learner.role, ManagerOperation.viewTeams),
        isTrue,
      );
      expect(
        policy.canPerform(learner.role, ManagerOperation.viewMetrics),
        isFalse,
      );
      expect(
        policy.canPerform(learner.role, ManagerOperation.viewAudit),
        isFalse,
      );
    });

    test('cross-tenant access is hidden behind NotFound', () {
      final Result<void> result = policy.authorize(
        context: context(ManagerOrganizationRole.owner),
        operation: ManagerOperation.viewMetrics,
        resourceOrganizationId: 'org-other',
      );

      expect(result, isA<Err<void>>());
      expect((result as Err<void>).failure, isA<NotFoundFailure>());
    });

    test('same-tenant unauthorized access stays an auth failure', () {
      final Result<void> result = policy.authorize(
        context: context(ManagerOrganizationRole.learner),
        operation: ManagerOperation.viewMetrics,
        resourceOrganizationId: FixtureManagerPortalRepository.fixtureOrganizationId,
      );

      expect(result, isA<Err<void>>());
      expect((result as Err<void>).failure, isA<AuthFailure>());
    });
  });

  test('fixtures suppress small cohorts without disclosive values', () async {
    const FixtureManagerPortalRepository repository = FixtureManagerPortalRepository();
    final Result<ManagerPortalData> result = await repository.loadPortal(
      context(ManagerOrganizationRole.manager),
    );
    final ManagerPortalData data = result.valueOrNull!;
    final ManagerMetricSummary suppressed = data.metrics.singleWhere(
      (ManagerMetricSummary metric) => metric.suppressed,
    );

    expect(suppressed.hasNoDisclosiveValues, isTrue);
    expect(
      data.members.every(
        (ManagerMemberSummary member) =>
            member.label.startsWith('Membre ') && !member.label.contains('@'),
      ),
      isTrue,
      reason: 'Fixture labels use opaque member aliases and never email addresses.',
    );
  });

  group('manager route codec', () {
    test('decodes an organization route segment exactly once', () {
      expect(decodeManagerOrganizationIdSegment('org%25west'), 'org%west');
      expect(
        managerOrganizationIdFromUri(Uri.parse('/enterprise/org%2525west?tab=metrics')),
        'org%25west',
      );
    });

    test('rejects malformed percent encoding explicitly', () {
      expect(
        () => decodeManagerOrganizationIdSegment('org%ZZwest'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
