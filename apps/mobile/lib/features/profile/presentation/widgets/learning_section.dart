import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../onboarding/application/onboarding_controller.dart';
import '../../application/settings_preferences.dart';
import 'tappable_row.dart';

class LearningSection extends ConsumerStatefulWidget {
  const LearningSection({super.key});

  @override
  ConsumerState<LearningSection> createState() => _LearningSectionState();
}

class _LearningSectionState extends ConsumerState<LearningSection> {
  Future<void> _pickGoal() async {
    DailyGoalOption current = ref.read(dailyGoalProvider);
    final DailyGoalOption? result = await showDialog<DailyGoalOption>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDialogState) => AlertDialog(
          title: const Text('Objectif quotidien'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: DailyGoalOption.values
                .map(
                  (DailyGoalOption g) => RadioListTile<DailyGoalOption>(
                    value: g,
                    groupValue: current,
                    title: Text('${g.label} (${g.minutes} min / j)'),
                    onChanged: (DailyGoalOption? v) {
                      if (v != null) setDialogState(() => current = v);
                    },
                  ),
                )
                .toList(),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(current),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await ref.read(dailyGoalProvider.notifier).set(result);
    }
  }

  Future<void> _pickLevel() async {
    KnowledgeLevel current = ref.read(knowledgeLevelProvider);
    final KnowledgeLevel? result = await showDialog<KnowledgeLevel>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDialogState) => AlertDialog(
          title: const Text('Niveau Azure'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: KnowledgeLevel.values
                .map(
                  (KnowledgeLevel l) => RadioListTile<KnowledgeLevel>(
                    value: l,
                    groupValue: current,
                    title: Text(l.label),
                    onChanged: (KnowledgeLevel? v) {
                      if (v != null) setDialogState(() => current = v);
                    },
                  ),
                )
                .toList(),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(current),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await ref.read(knowledgeLevelProvider.notifier).set(result);
    }
  }

  Future<void> _pickDomains() async {
    Set<AzureDomain> current = Set<AzureDomain>.from(ref.read(domainsProvider));
    final Set<AzureDomain>? result = await showDialog<Set<AzureDomain>>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDialogState) => AlertDialog(
          title: const Text('Domaines d\'intérêt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AzureDomain.values
                  .map(
                    (AzureDomain d) => CheckboxListTile(
                      value: current.contains(d),
                      title: Text(d.label),
                      onChanged: (bool? v) {
                        setDialogState(() {
                          if (v == true) {
                            current = <AzureDomain>{...current, d};
                          } else {
                            current = current.where((AzureDomain x) => x != d).toSet();
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(current),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
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
