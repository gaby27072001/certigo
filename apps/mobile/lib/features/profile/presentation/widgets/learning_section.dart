import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../onboarding/application/onboarding_controller.dart';
import '../../application/settings_preferences.dart';
import 'profile_sheets.dart';
import 'tappable_row.dart';

class LearningSection extends ConsumerStatefulWidget {
  const LearningSection({super.key});

  @override
  ConsumerState<LearningSection> createState() => _LearningSectionState();
}

class _LearningSectionState extends ConsumerState<LearningSection> {
  Future<void> _pickGoal() async {
    final DailyGoalOption? result = await showProfileChoiceSheet<DailyGoalOption>(
      context: context,
      title: 'Objectif quotidien',
      selected: ref.read(dailyGoalProvider),
      options: <ProfileOption<DailyGoalOption>>[
        for (final DailyGoalOption g in DailyGoalOption.values)
          ProfileOption<DailyGoalOption>(
            value: g,
            label: g.label,
            trailing: '${g.minutes} min / j',
          ),
      ],
    );
    if (result != null && mounted) {
      await ref.read(dailyGoalProvider.notifier).set(result);
    }
  }

  Future<void> _pickLevel() async {
    final KnowledgeLevel? result = await showProfileChoiceSheet<KnowledgeLevel>(
      context: context,
      title: 'Niveau Azure',
      selected: ref.read(knowledgeLevelProvider),
      options: <ProfileOption<KnowledgeLevel>>[
        for (final KnowledgeLevel l in KnowledgeLevel.values)
          ProfileOption<KnowledgeLevel>(value: l, label: l.label),
      ],
    );
    if (result != null && mounted) {
      await ref.read(knowledgeLevelProvider.notifier).set(result);
    }
  }

  Future<void> _pickDomains() async {
    final Set<AzureDomain>? result = await showProfileMultiChoiceSheet<AzureDomain>(
      context: context,
      title: 'Domaines d\'intérêt',
      selected: ref.read(domainsProvider),
      options: <ProfileOption<AzureDomain>>[
        for (final AzureDomain d in AzureDomain.values)
          ProfileOption<AzureDomain>(value: d, label: d.label),
      ],
    );
    if (result != null && mounted) {
      await ref.read(domainsProvider.notifier).set(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final DailyGoalOption goal = ref.watch(dailyGoalProvider);
    final KnowledgeLevel level = ref.watch(knowledgeLevelProvider);
    final Set<AzureDomain> domains = ref.watch(domainsProvider);
    final String domainsLabel = domains.isEmpty
        ? 'Non défini'
        : '${domains.length} domaine${domains.length > 1 ? 's' : ''}';

    return PrismCard(
      child: Column(
        children: <Widget>[
          TappableRow(
            icon: Icons.flag_rounded,
            label: 'Objectif quotidien',
            trailing: '${goal.minutes} min / j',
            onTap: _pickGoal,
          ),
          Divider(color: p.border, height: 24),
          TappableRow(
            icon: Icons.military_tech_rounded,
            label: 'Niveau Azure',
            trailing: level.label,
            onTap: _pickLevel,
          ),
          Divider(color: p.border, height: 24),
          TappableRow(
            icon: Icons.public_rounded,
            label: 'Domaines d\'intérêt',
            trailing: domainsLabel,
            onTap: _pickDomains,
          ),
        ],
      ),
    );
  }
}
