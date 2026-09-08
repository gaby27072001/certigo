enum ManagerOrganizationRole { owner, admin, manager, learner }

enum ManagerOperation {
  viewOrganization,
  viewMembers,
  viewTeams,
  manageTeams,
  viewAssignments,
  manageAssignments,
  viewMetrics,
  requestExport,
  viewAudit,
}

class ManagerOrganizationContext {
  const ManagerOrganizationContext({
    required this.organizationId,
    required this.organizationName,
    required this.role,
  });

  final String organizationId;
  final String organizationName;
  final ManagerOrganizationRole role;

  @override
  bool operator ==(Object other) {
    return other is ManagerOrganizationContext &&
        other.organizationId == organizationId &&
        other.organizationName == organizationName &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(organizationId, organizationName, role);
}

class ManagerMemberSummary {
  const ManagerMemberSummary({
    required this.label,
    required this.role,
    required this.teamLabel,
  });

  /// Deliberately opaque fixture label: no name, email, account id or learning detail.
  final String label;
  final ManagerOrganizationRole role;
  final String teamLabel;
}

class ManagerTeamSummary {
  const ManagerTeamSummary({
    required this.label,
    required this.memberCount,
    required this.assignmentCount,
  });

  final String label;
  final int memberCount;
  final int assignmentCount;
}

class ManagerMetricSummary {
  const ManagerMetricSummary({
    required this.periodLabel,
    required this.suppressed,
    this.learningHours,
    this.progressPercent,
    this.completionCount,
    this.averageReadinessPercent,
  });

  final String periodLabel;
  final bool suppressed;
  final double? learningHours;
  final double? progressPercent;
  final int? completionCount;
  final double? averageReadinessPercent;

  bool get hasNoDisclosiveValues =>
      learningHours == null &&
      progressPercent == null &&
      completionCount == null &&
      averageReadinessPercent == null;
}

enum ManagerAssignmentAvailability { contractPending }

class ManagerAssignmentSummary {
  const ManagerAssignmentSummary({
    required this.availability,
    required this.canManage,
  });

  final ManagerAssignmentAvailability availability;
  final bool canManage;
}

enum ManagerExportFormat { csv, json }

class ManagerExportOption {
  const ManagerExportOption({
    required this.format,
    required this.available,
    required this.policyLabel,
  });

  final ManagerExportFormat format;
  final bool available;
  final String policyLabel;
}

class ManagerAuditSummary {
  const ManagerAuditSummary({
    required this.category,
    required this.occurredAtLabel,
    required this.outcome,
  });

  final String category;
  final String occurredAtLabel;
  final String outcome;
}

class ManagerPortalData {
  const ManagerPortalData({
    required this.organizationId,
    required this.members,
    required this.teams,
    required this.metrics,
    required this.assignment,
    required this.exports,
    required this.audit,
  });

  final String organizationId;
  final List<ManagerMemberSummary> members;
  final List<ManagerTeamSummary> teams;
  final List<ManagerMetricSummary> metrics;
  final ManagerAssignmentSummary assignment;
  final List<ManagerExportOption> exports;
  final List<ManagerAuditSummary> audit;
}
