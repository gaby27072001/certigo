import 'package:core/core.dart';

import 'manager_models.dart';

class ManagerPolicy {
  const ManagerPolicy();

  bool canPerform(ManagerOrganizationRole role, ManagerOperation operation) {
    return switch (operation) {
      ManagerOperation.viewOrganization ||
      ManagerOperation.viewTeams ||
      ManagerOperation.viewAssignments =>
        true,
      ManagerOperation.viewMembers ||
      ManagerOperation.manageTeams ||
      ManagerOperation.manageAssignments ||
      ManagerOperation.viewMetrics ||
      ManagerOperation.requestExport ||
      ManagerOperation.viewAudit =>
        role == ManagerOrganizationRole.owner ||
            role == ManagerOrganizationRole.admin ||
            role == ManagerOrganizationRole.manager,
    };
  }

  Result<void> authorize({
    required ManagerOrganizationContext context,
    required ManagerOperation operation,
    required String resourceOrganizationId,
  }) {
    if (context.organizationId != resourceOrganizationId) {
      return const Err<void>(NotFoundFailure());
    }
    if (!canPerform(context.role, operation)) {
      return const Err<void>(AuthFailure('Accès organisation non autorisé'));
    }
    return const Success<void>(null);
  }

  bool canOpenPortal(ManagerOrganizationContext? context) {
    return context != null &&
        canPerform(context.role, ManagerOperation.viewMetrics) &&
        canPerform(context.role, ManagerOperation.viewMembers);
  }
}
