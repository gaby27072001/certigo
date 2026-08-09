import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../features/auth/presentation/widgets/email_verification_banner.dart';

/// App shell hosting the four primary tabs behind a floating glass nav bar.
///
/// Uses [StatefulNavigationShell] so each tab keeps its own navigation stack
/// and scroll position. The bottom bar is a [GlassSurface] to extend the Prism
/// material language to chrome, not just content.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab('Accueil', Icons.home_rounded, Icons.home_outlined),
    _Tab('Parcours', Icons.school_rounded, Icons.school_outlined),
    _Tab('Bibliothèque', Icons.auto_stories_rounded, Icons.auto_stories_outlined),
    _Tab('Ligue', Icons.emoji_events_rounded, Icons.emoji_events_outlined),
    _Tab('Profil', Icons.person_rounded, Icons.person_outline_rounded),
  ];

  void _onTap(int index) {
    // Re-tapping the active tab pops to its root.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Scaffold(
      extendBody: true,
      // The verification banner sits above the tab content and self-hides unless
      // the session is an unverified email/password account (non-blocking).
      body: Column(
        children: <Widget>[
          const EmailVerificationBanner(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: PrismMotion.fast,
            curve: PrismMotion.standard,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color.primarySoft : Colors.transparent,
              borderRadius: PrismRadii.pillAll,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? tab.activeIcon : tab.icon,
                  color: selected ? color.primary : color.textSecondary,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? color.primary : color.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
