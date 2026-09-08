import 'package:core/core.dart';

import 'manager_models.dart';
import 'manager_policy.dart';

abstract interface class ManagerPortalRepository {
  Future<Result<ManagerPortalData>> loadPortal(
    ManagerOrganizationContext context,
  );
}

abstract interface class ManagerExportService {
  Future<Result<void>> requestExport({
    required ManagerOrganizationContext context,
    required ManagerExportFormat format,
  });
}

class FixtureManagerPortalRepository implements ManagerPortalRepository {
  const FixtureManagerPortalRepository({this.policy = const ManagerPolicy()});

  static const String fixtureOrganizationId = 'org-fixture-northstar';
  final ManagerPolicy policy;

  @override
  Future<Result<ManagerPortalData>> loadPortal(
    ManagerOrganizationContext context,
  ) async {
    final Result<void> authorization = policy.authorize(
      context: context,
      operation: ManagerOperation.viewMetrics,
      resourceOrganizationId: fixtureOrganizationId,
    );
    if (authorization.isFailure) {
      return Err<ManagerPortalData>((authorization as Err<void>).failure);
    }

    return const Success<ManagerPortalData>(
      ManagerPortalData(
        organizationId: fixtureOrganizationId,
        members: <ManagerMemberSummary>[
          ManagerMemberSummary(
            label: 'Membre 7A2',
            role: ManagerOrganizationRole.manager,
            teamLabel: 'Plateforme',
          ),
          ManagerMemberSummary(
            label: 'Membre C14',
            role: ManagerOrganizationRole.learner,
            teamLabel: 'Sécurité',
          ),
          ManagerMemberSummary(
            label: 'Membre E09',
            role: ManagerOrganizationRole.learner,
            teamLabel: 'Plateforme',
          ),
        ],
        teams: <ManagerTeamSummary>[
          ManagerTeamSummary(
            label: 'Plateforme',
            memberCount: 8,
            assignmentCount: 0,
          ),
          ManagerTeamSummary(
            label: 'Sécurité',
            memberCount: 6,
            assignmentCount: 0,
          ),
        ],
        metrics: <ManagerMetricSummary>[
          ManagerMetricSummary(
            periodLabel: 'Semaine 33',
            suppressed: false,
            learningHours: 42.5,
            progressPercent: 18,
            completionCount: 31,
            averageReadinessPercent: 67,
          ),
          ManagerMetricSummary(periodLabel: 'Semaine 34', suppressed: true),
        ],
        assignment: ManagerAssignmentSummary(
          availability: ManagerAssignmentAvailability.contractPending,
          canManage: true,
        ),
        exports: <ManagerExportOption>[
          ManagerExportOption(
            format: ManagerExportFormat.csv,
            available: false,
            policyLabel: 'Agrégats organisation uniquement',
          ),
          ManagerExportOption(
            format: ManagerExportFormat.json,
            available: false,
            policyLabel: 'Agrégats organisation uniquement',
          ),
        ],
        audit: <ManagerAuditSummary>[
          ManagerAuditSummary(
            category: 'Consultation des métriques',
            occurredAtLabel: 'Aujourd’hui · 09:30',
            outcome: 'Autorisé',
          ),
          ManagerAuditSummary(
            category: 'Export agrégé',
            occurredAtLabel: 'Hier · 16:10',
            outcome: 'Bloqué par la policy',
          ),
        ],
      ),
    );
  }
}

class FixtureManagerExportService implements ManagerExportService {
  const FixtureManagerExportService();

  @override
  Future<Result<void>> requestExport({
    required ManagerOrganizationContext context,
    required ManagerExportFormat format,
  }) async {
    return const Err<void>(
      ServerFailure('Contrat d’export indisponible', statusCode: 503),
    );
  }
}
