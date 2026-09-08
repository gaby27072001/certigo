import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/manager_models.dart';
import '../application/manager_providers.dart';
import 'manager_strings.dart';
import 'manager_workspace_switcher.dart';

enum ManagerSection { dashboard, members, teams, assignments, exports, audit }

class ManagerPortalScreen extends ConsumerStatefulWidget {
  const ManagerPortalScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends ConsumerState<ManagerPortalScreen> {
  ManagerSection _section = ManagerSection.dashboard;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    final ManagerOrganizationContext? organization = ref.watch(
      managerOrganizationContextProvider,
    );
    final bool authorized = organization != null &&
        organization.organizationId == widget.organizationId &&
        ref.watch(managerPolicyProvider).canOpenPortal(organization);

    if (!authorized) {
      return Scaffold(
        body: PrismStatusView(
          icon: Icons.search_off_rounded,
          title: strings.unavailable,
          message: strings.unavailableMessage,
        ),
      );
    }

    final AsyncValue<ManagerPortalData> portal = ref.watch(
      managerPortalDataProvider(organization),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _PortalHeader(organization: organization),
            Expanded(
              child: portal.when(
                loading: () => PrismLoadingView(label: strings.loading),
                error: (Object error, StackTrace stackTrace) => _PortalError(
                  error: error,
                  onRetry: () => ref.invalidate(managerPortalDataProvider(organization)),
                ),
                data: (ManagerPortalData data) {
                  if (data.organizationId != organization.organizationId) {
                    return PrismStatusView(
                      icon: Icons.search_off_rounded,
                      title: strings.unavailable,
                      message: strings.unavailableMessage,
                    );
                  }
                  return _PortalLayout(
                    section: _section,
                    data: data,
                    organization: organization,
                    onSectionChanged: (ManagerSection value) {
                      setState(() => _section = value);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalHeader extends StatelessWidget {
  const _PortalHeader({required this.organization});

  final ManagerOrganizationContext organization;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    final PrismColorScheme colors = context.prism;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.portalTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                organization.organizationName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          );
          final Widget switcher = ManagerWorkspaceSwitcher(
            enterpriseSelected: true,
            organizationId: organization.organizationId,
            compact: constraints.maxWidth < 640,
          );
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.gutter,
              vertical: PrismSpacing.sm,
            ),
            child: constraints.maxWidth >= 640
                ? Row(
                    children: <Widget>[
                      Expanded(child: title),
                      const SizedBox(width: PrismSpacing.md),
                      switcher,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      title,
                      const SizedBox(height: PrismSpacing.sm),
                      Align(alignment: Alignment.centerLeft, child: switcher),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _PortalError extends StatelessWidget {
  const _PortalError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    final Failure? failure =
        error is ManagerPortalLoadException ? (error as ManagerPortalLoadException).failure : null;
    final bool hidden = failure is NotFoundFailure || failure is AuthFailure;
    return PrismStatusView(
      icon: hidden ? Icons.search_off_rounded : Icons.cloud_off_rounded,
      title: hidden ? strings.unavailable : strings.pick('Chargement impossible', 'Unable to load'),
      message: hidden
          ? strings.unavailableMessage
          : strings.pick(
              'Le portail local n’a pas pu être chargé.',
              'The local portal could not be loaded.',
            ),
      actionLabel: hidden ? null : strings.retry,
      onAction: hidden ? null : onRetry,
    );
  }
}

class _PortalLayout extends StatelessWidget {
  const _PortalLayout({
    required this.section,
    required this.data,
    required this.organization,
    required this.onSectionChanged,
  });

  final ManagerSection section;
  final ManagerPortalData data;
  final ManagerOrganizationContext organization;
  final ValueChanged<ManagerSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 900;
        final Widget content = _SectionBody(
          section: section,
          data: data,
          organization: organization,
        );
        if (wide) {
          return Row(
            children: <Widget>[
              _ManagerRail(section: section, onChanged: onSectionChanged),
              Expanded(child: content),
            ],
          );
        }
        return Column(
          children: <Widget>[
            _ManagerCompactNavigation(
              section: section,
              onChanged: onSectionChanged,
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _ManagerRail extends StatelessWidget {
  const _ManagerRail({required this.section, required this.onChanged});

  final ManagerSection section;
  final ValueChanged<ManagerSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme colors = context.prism;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        key: const Key('manager-rail'),
        width: 264,
        child: ListView.separated(
          padding: const EdgeInsets.all(PrismSpacing.sm),
          itemCount: ManagerSection.values.length,
          separatorBuilder: (_, __) => const SizedBox(height: PrismSpacing.xxs),
          itemBuilder: (BuildContext context, int index) {
            final _ManagerDestination item = _destinations(context)[index];
            final bool selected = item.section == section;
            return Semantics(
              button: true,
              selected: selected,
              label: item.label,
              child: InkWell(
                borderRadius: PrismRadii.cardLg,
                onTap: () => onChanged(item.section),
                child: AnimatedContainer(
                  duration: PrismMotion.resolve(context, PrismMotion.fast),
                  curve: PrismMotion.standard,
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: PrismSpacing.md,
                    vertical: PrismSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? colors.primarySoft : Colors.transparent,
                    borderRadius: PrismRadii.cardLg,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        selected ? item.selectedIcon : item.icon,
                        color: selected ? colors.primary : colors.textSecondary,
                      ),
                      const SizedBox(width: PrismSpacing.sm),
                      Expanded(
                        child: Text(
                          item.label,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: selected ? colors.primary : colors.textSecondary,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManagerCompactNavigation extends StatelessWidget {
  const _ManagerCompactNavigation({
    required this.section,
    required this.onChanged,
  });

  final ManagerSection section;
  final ValueChanged<ManagerSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme colors = context.prism;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: PrismSpacing.gutter,
            vertical: PrismSpacing.xs,
          ),
          separatorBuilder: (_, __) => const SizedBox(width: PrismSpacing.xs),
          itemCount: ManagerSection.values.length,
          itemBuilder: (BuildContext context, int index) {
            final _ManagerDestination item = _destinations(context)[index];
            return ChoiceChip(
              selected: item.section == section,
              showCheckmark: false,
              avatar: Icon(item.icon, size: 18),
              label: Text(item.label),
              onSelected: (_) => onChanged(item.section),
            );
          },
        ),
      ),
    );
  }
}

class _ManagerDestination {
  const _ManagerDestination(
    this.section,
    this.label,
    this.icon,
    this.selectedIcon,
  );

  final ManagerSection section;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

List<_ManagerDestination> _destinations(BuildContext context) {
  final ManagerStrings strings = ManagerStrings.of(context);
  return <_ManagerDestination>[
    _ManagerDestination(
      ManagerSection.dashboard,
      strings.dashboard,
      Icons.dashboard_outlined,
      Icons.dashboard_rounded,
    ),
    _ManagerDestination(
      ManagerSection.members,
      strings.members,
      Icons.group_outlined,
      Icons.group_rounded,
    ),
    _ManagerDestination(
      ManagerSection.teams,
      strings.teams,
      Icons.groups_outlined,
      Icons.groups_rounded,
    ),
    _ManagerDestination(
      ManagerSection.assignments,
      strings.assignments,
      Icons.assignment_outlined,
      Icons.assignment_rounded,
    ),
    _ManagerDestination(
      ManagerSection.exports,
      strings.exports,
      Icons.download_outlined,
      Icons.download_rounded,
    ),
    _ManagerDestination(
      ManagerSection.audit,
      strings.audit,
      Icons.policy_outlined,
      Icons.policy_rounded,
    ),
  ];
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.data,
    required this.organization,
  });

  final ManagerSection section;
  final ManagerPortalData data;
  final ManagerOrganizationContext organization;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (section) {
      ManagerSection.dashboard => _DashboardSection(metrics: data.metrics),
      ManagerSection.members => _MembersSection(members: data.members),
      ManagerSection.teams => _TeamsSection(teams: data.teams),
      ManagerSection.assignments => _AssignmentsSection(
          assignment: data.assignment,
        ),
      ManagerSection.exports => _ExportsSection(options: data.exports),
      ManagerSection.audit => _AuditSection(entries: data.audit),
    };
    return SingleChildScrollView(
      key: ValueKey<ManagerSection>(section),
      padding: const EdgeInsets.all(PrismSpacing.gutter),
      child: PrismContentFrame(
        maxWidth: 1120,
        expandHeight: false,
        child: child,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme colors = context.prism;
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: colors.primary, size: 28),
          const SizedBox(width: PrismSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: PrismSpacing.xxs),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.metrics});

  final List<ManagerMetricSummary> metrics;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    final ManagerMetricSummary? visible = metrics.cast<ManagerMetricSummary?>().firstWhere(
          (ManagerMetricSummary? item) => item != null && !item.suppressed,
          orElse: () => null,
        );
    if (metrics.isEmpty || visible == null) {
      return SizedBox(
        height: 520,
        child: PrismStatusView.empty(
          title: strings.noData,
          message: strings.noDataMessage,
          icon: Icons.shield_outlined,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(
          title: strings.dashboard,
          message: strings.privacyNotice,
          icon: Icons.query_stats_rounded,
        ),
        _MetricBand(metric: visible),
        const SizedBox(height: PrismSpacing.lg),
        Text(
          strings.pick('Historique des cohortes', 'Cohort history'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: PrismSpacing.sm),
        for (final ManagerMetricSummary metric in metrics)
          Padding(
            padding: PrismSpacing.listGap,
            child: _MetricPeriodRow(metric: metric),
          ),
      ],
    );
  }
}

class _MetricBand extends StatelessWidget {
  const _MetricBand({required this.metric});

  final ManagerMetricSummary metric;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    return PrismCard(
      variant: PrismCardVariant.tonal,
      child: Wrap(
        spacing: PrismSpacing.xl,
        runSpacing: PrismSpacing.lg,
        children: <Widget>[
          _MetricValue(
            label: strings.pick('Temps d’apprentissage', 'Learning time'),
            value: metric.learningHours == null
                ? strings.unknown
                : '${metric.learningHours!.toStringAsFixed(1)} h',
          ),
          _MetricValue(
            label: strings.pick('Progression', 'Progress'),
            value: metric.progressPercent == null
                ? strings.unknown
                : '${metric.progressPercent!.round()} %',
          ),
          _MetricValue(
            label: strings.pick('Complétions', 'Completions'),
            value: metric.completionCount?.toString() ?? strings.unknown,
          ),
          _MetricValue(
            label: strings.pick('Préparation moyenne', 'Average readiness'),
            value: metric.averageReadinessPercent == null
                ? strings.unknown
                : '${metric.averageReadinessPercent!.round()} %',
          ),
        ],
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme colors = context.prism;
    return SizedBox(
      width: 184,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MetricPeriodRow extends StatelessWidget {
  const _MetricPeriodRow({required this.metric});

  final ManagerMetricSummary metric;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    final PrismColorScheme colors = context.prism;
    final String learningHours = metric.learningHours == null
        ? strings.unknown
        : '${metric.learningHours!.toStringAsFixed(1)} h';
    final String completionCount = metric.completionCount?.toString() ?? strings.unknown;
    final String details = metric.suppressed
        ? strings.pick('Masqué · cohorte < 5', 'Hidden · cohort < 5')
        : '$learningHours · $completionCount '
            '${strings.pick('complétions', 'completions')}';
    return PrismCard(
      elevation: 0,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget period = Row(
            children: <Widget>[
              Icon(
                metric.suppressed ? Icons.lock_outline_rounded : Icons.calendar_today_outlined,
                color: metric.suppressed ? colors.textSecondary : colors.primary,
              ),
              const SizedBox(width: PrismSpacing.sm),
              Text(
                metric.periodLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          );
          final Widget detail = Text(
            details,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          );
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                period,
                const SizedBox(height: PrismSpacing.xs),
                detail,
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: period),
              detail,
            ],
          );
        },
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.members});

  final List<ManagerMemberSummary> members;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    if (members.isEmpty) {
      return SizedBox(
        height: 520,
        child: PrismStatusView.empty(
          title: strings.pick('Aucun membre', 'No members'),
          message: strings.pick(
            'Les membres pseudonymisés apparaîtront ici.',
            'Pseudonymous members will appear here.',
          ),
          icon: Icons.group_outlined,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(
          title: strings.members,
          message: strings.pick(
            'Répertoire pseudonymisé: aucun nom, e-mail ou acquis individuel.',
            'Pseudonymous directory: no names, email addresses or individual learning records.',
          ),
          icon: Icons.group_rounded,
        ),
        for (final ManagerMemberSummary member in members)
          Padding(
            padding: PrismSpacing.listGap,
            child: _MemberRow(member: member),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final ManagerMemberSummary member;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme colors = context.prism;
    return PrismCard(
      elevation: 0,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: colors.primarySoft,
            foregroundColor: colors.primary,
            child: const Icon(Icons.person_outline_rounded),
          ),
          const SizedBox(width: PrismSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  member.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  member.teamLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          _RoleChip(role: member.role),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final ManagerOrganizationRole role;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    final String label = switch (role) {
      ManagerOrganizationRole.owner => strings.pick('Propriétaire', 'Owner'),
      ManagerOrganizationRole.admin => strings.pick('Administrateur', 'Admin'),
      ManagerOrganizationRole.manager => strings.pick('Manager', 'Manager'),
      ManagerOrganizationRole.learner => strings.pick('Apprenant', 'Learner'),
    };
    return Chip(label: Text(label));
  }
}

class _TeamsSection extends StatelessWidget {
  const _TeamsSection({required this.teams});

  final List<ManagerTeamSummary> teams;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(
          title: strings.teams,
          message: strings.pick(
            'Structure de l’organisation et effectifs agrégés.',
            'Organization structure and aggregate headcounts.',
          ),
          icon: Icons.groups_rounded,
        ),
        if (teams.isEmpty)
          SizedBox(
            height: 420,
            child: PrismStatusView.empty(
              title: strings.pick('Aucune équipe', 'No teams'),
              message: strings.pick(
                'Crée une équipe lorsque le contrat serveur sera disponible.',
                'Create a team once the server contract is available.',
              ),
              icon: Icons.groups_outlined,
            ),
          )
        else
          for (final ManagerTeamSummary team in teams)
            Padding(
              padding: PrismSpacing.listGap,
              child: PrismCard(
                elevation: 0,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(team.label),
                  subtitle: Text(
                    strings.pick(
                      '${team.memberCount} membres · ${team.assignmentCount} assignation',
                      '${team.memberCount} members · ${team.assignmentCount} assignments',
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _AssignmentsSection extends StatelessWidget {
  const _AssignmentsSection({required this.assignment});

  final ManagerAssignmentSummary assignment;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(
          title: strings.assignments,
          message: strings.pick(
            'Surface réservée par la policy ManageAssignments.',
            'Surface reserved by the ManageAssignments policy.',
          ),
          icon: Icons.assignment_rounded,
        ),
        PrismCard(
          variant: PrismCardVariant.tonal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.construction_rounded),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.pick(
                        'Contrat backend en attente',
                        'Backend contract pending',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: PrismSpacing.xs),
                    Text(
                      strings.pick(
                        'Aucune assignation n’est simulée ou envoyée. '
                            'Le contrôle owner/admin/manager est déjà appliqué localement.',
                        'No assignment is simulated or sent. '
                            'The owner/admin/manager control is already applied locally.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportsSection extends StatelessWidget {
  const _ExportsSection({required this.options});

  final List<ManagerExportOption> options;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(
          title: strings.exports,
          message: strings.pick(
            'Interface abstraite prête; aucune génération locale ni requête réseau.',
            'Abstract interface ready; no local generation or network request.',
          ),
          icon: Icons.download_rounded,
        ),
        for (final ManagerExportOption option in options)
          Padding(
            padding: PrismSpacing.listGap,
            child: PrismCard(
              elevation: 0,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: PrismSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          option.format.name.toUpperCase(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(option.policyLabel),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 152,
                    child: PrismButton.secondary(
                      label: strings.pick('Indisponible', 'Unavailable'),
                      onPressed: null,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AuditSection extends StatelessWidget {
  const _AuditSection({required this.entries});

  final List<ManagerAuditSummary> entries;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(
          title: strings.audit,
          message: strings.pick(
            'Événements de contrôle sans identifiant d’acteur ni donnée personnelle.',
            'Control events without actor identifiers or personal data.',
          ),
          icon: Icons.policy_rounded,
        ),
        if (entries.isEmpty)
          SizedBox(
            height: 420,
            child: PrismStatusView.empty(
              title: strings.pick('Aucun événement', 'No events'),
              message: strings.pick(
                'Les décisions de policy apparaîtront ici.',
                'Policy decisions will appear here.',
              ),
              icon: Icons.policy_outlined,
            ),
          )
        else
          for (final ManagerAuditSummary entry in entries)
            Padding(
              padding: PrismSpacing.listGap,
              child: PrismCard(
                elevation: 0,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(entry.category),
                  subtitle: Text(entry.occurredAtLabel),
                  trailing: Text(entry.outcome),
                ),
              ),
            ),
      ],
    );
  }
}
