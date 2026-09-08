import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'manager_strings.dart';

class ManagerWorkspaceSwitcher extends StatelessWidget {
  const ManagerWorkspaceSwitcher({
    super.key,
    required this.enterpriseSelected,
    required this.organizationId,
    this.compact = false,
  });

  final bool enterpriseSelected;
  final String organizationId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ManagerStrings strings = ManagerStrings.of(context);
    final PrismColorScheme colors = context.prism;

    return Semantics(
      container: true,
      label: strings.pick('Espace actif', 'Active workspace'),
      child: Material(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: colors.border)),
        child: Padding(
          padding: const EdgeInsets.all(PrismSpacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _WorkspaceChoice(
                label: strings.personal,
                icon: Icons.person_outline_rounded,
                selected: !enterpriseSelected,
                compact: compact,
                onTap: () => context.go('/home'),
              ),
              _WorkspaceChoice(
                label: strings.enterprise,
                icon: Icons.domain_rounded,
                selected: enterpriseSelected,
                compact: compact,
                onTap: () => context.go(
                  '/enterprise/${Uri.encodeComponent(organizationId)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceChoice extends StatelessWidget {
  const _WorkspaceChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme colors = context.prism;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: PrismRadii.pillAll,
        onTap: onTap,
        child: AnimatedContainer(
          duration: PrismMotion.resolve(context, PrismMotion.fast),
          curve: PrismMotion.standard,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: PrismSpacing.md,
            vertical: PrismSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.primarySoft : Colors.transparent,
            borderRadius: PrismRadii.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? colors.primary : colors.textSecondary,
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: PrismSpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? colors.primary : colors.textSecondary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
