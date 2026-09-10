import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../features/auth/presentation/widgets/email_verification_banner.dart';
import '../features/manager/application/manager_providers.dart';
import '../features/manager/presentation/manager_workspace_switcher.dart';
import 'account_deletion_resume_scope.dart';
import 'content/content_update_banner.dart';

/// App shell hosting the four primary tabs behind a floating glass nav bar.
///
/// Uses [StatefulNavigationShell] so each tab keeps its own navigation stack
/// and scroll position. The bottom bar is a [GlassSurface] to extend the Prism
/// material language to chrome, not just content.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab('Accueil', Icons.home_rounded, Icons.home_outlined),
    _Tab('Parcours', Icons.school_rounded, Icons.school_outlined),
    _Tab(
      'Bibliothèque',
      Icons.auto_stories_rounded,
      Icons.auto_stories_outlined,
    ),
    _Tab('Ligue', Icons.emoji_events_rounded, Icons.emoji_events_outlined),
    _Tab('Profil', Icons.person_rounded, Icons.person_outline_rounded),
  ];

  void _onTap(int index) {
    // Re-tapping the active tab pops to its root.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final organization = ref.watch(managerOrganizationContextProvider);
    final bool showEnterprise =
        AppEnv.managerPortalEnabled && ref.watch(managerPolicyProvider).canOpenPortal(organization);
    return Scaffold(
      extendBody: true,
      // The verification banner sits above the tab content and self-hides unless
      // the session is an unverified email/password account (non-blocking).
      body: AccountDeletionResumeScope(
        child: Column(
          children: <Widget>[
            const EmailVerificationBanner(),
            const ContentUpdateBanner(),
            if (showEnterprise)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PrismSpacing.gutter,
                  PrismSpacing.sm,
                  PrismSpacing.gutter,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ManagerWorkspaceSwitcher(
                    enterpriseSelected: false,
                    organizationId: organization!.organizationId,
                  ),
                ),
              ),
            // The body is what needs bounding, not just the bar. On a phone
            // this is a no-op (the frame takes min(maxWidth, constraints)); it
            // only bites on iPad, in landscape and in Split View, where an
            // unbounded body would stretch a line of prose past readability.
            Expanded(child: PrismContentFrame(child: shell)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        // Was a bare 16, which left the bar out of step with the content
        // gutter of 20.
        minimum: const EdgeInsets.fromLTRB(
          PrismSpacing.gutter,
          0,
          PrismSpacing.gutter,
          PrismSpacing.sm,
        ),
        child: PrismContentFrame(
          maxWidth: PrismLayout.controlBar,
          expandHeight: false,
          child: GlassSurface(
            elevation: 2,
            borderRadius: PrismRadii.pillAll,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (int i = 0; i < _tabs.length; i++)
                  _NavItem(
                    tab: _tabs[i],
                    selected: i == shell.currentIndex,
                    color: p,
                    onTap: () => _onTap(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.activeIcon, this.icon);
  final String label;
  final IconData activeIcon;
  final IconData icon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final PrismColorScheme color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PrismPressable(
        semanticLabel: tab.label,
        selected: selected,
        haptic: PrismHaptic.selection,
        pressedScale: 0.96,
        borderRadius: PrismRadii.pillAll,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: PrismMotion.resolve(context, PrismMotion.fast),
          curve: PrismMotion.standard,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            // The measured selected-state layer, not a wash. `primarySoft` is
            // a region tint: over the dark glass it measured 1.004:1, i.e.
            // invisible. `selectedOn` is the layer built for exactly this and
            // is verified to move the surface (1.20:1 light, 1.36:1 dark).
            color: selected ? color.selectedOn(color.glassFill) : Colors.transparent,
            borderRadius: PrismRadii.pillAll,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected ? tab.activeIcon : tab.icon,
                color: selected ? color.primaryOnSurface : color.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? color.primaryOnSurface : color.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
