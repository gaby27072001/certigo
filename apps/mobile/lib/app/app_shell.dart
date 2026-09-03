import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../features/auth/presentation/widgets/email_verification_banner.dart';
import 'account_deletion_resume_scope.dart';
import 'content/content_update_banner.dart';
import 'capabilities/release_profile_provider.dart';
import 'capabilities/release_strings.dart';
import 'capabilities/release_widgets.dart';

/// App shell hosting the four primary tabs behind a floating glass nav bar.
///
/// Uses [StatefulNavigationShell] so each tab keeps its own navigation stack
/// and scroll position. The bottom bar is a [GlassSurface] to extend the Prism
/// material language to chrome, not just content.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab('Accueil', Icons.home_rounded, Icons.home_outlined, AppCapability.progressionReadinessXp),
    _Tab('Parcours', Icons.school_rounded, Icons.school_outlined, AppCapability.learningPath),
    _Tab(
      'Bibliothèque',
      Icons.auto_stories_rounded,
      Icons.auto_stories_outlined,
      AppCapability.certificationCatalog,
    ),
    _Tab(
      'Ligue',
      Icons.emoji_events_rounded,
      Icons.emoji_events_outlined,
      AppCapability.socialLeague,
    ),
    _Tab(
      'Profil',
      Icons.person_rounded,
      Icons.person_outline_rounded,
      AppCapability.progressionReadinessXp,
    ),
  ];

  void _onTap(int index) {
    // Re-tapping the active tab pops to its root.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrismColorScheme p = context.prism;
    final ReleaseStrings strings = ReleaseStrings.of(context);
    final bool accountDeletionEnabled =
        ref.watch(capabilityAvailabilityProvider(AppCapability.accountDeletion)).isEnabled;
    Widget body = Column(
      children: <Widget>[
        const EmailVerificationBanner(),
        const ContentUpdateBanner(),
        Expanded(child: shell),
      ],
    );
    if (accountDeletionEnabled) {
      body = AccountDeletionResumeScope(child: body);
    }
    return Scaffold(
      extendBody: true,
      // The verification banner sits above the tab content and self-hides unless
      // the session is an unverified email/password account (non-blocking).
      body: body,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: PrismContentFrame(
          maxWidth: 640,
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
                    availability: ref.watch(capabilityAvailabilityProvider(_tabs[i].capability)),
                    strings: strings,
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
  const _Tab(this.label, this.activeIcon, this.icon, this.capability);
  final String label;
  final IconData activeIcon;
  final IconData icon;
  final AppCapability capability;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.color,
    required this.availability,
    required this.strings,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final PrismColorScheme color;
  final CapabilityAvailability availability;
  final ReleaseStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = AnimatedContainer(
      duration: PrismMotion.resolve(context, PrismMotion.fast),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? color.primary : color.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
          if (availability.isUpcoming) ...<Widget>[
            const SizedBox(height: 2),
            CapabilityStatusBadge(availability: availability),
          ],
        ],
      ),
    );

    return Expanded(
      child: availability.isEnabled
          ? PrismPressable(
              semanticLabel: tab.label,
              selected: selected,
              haptic: PrismHaptic.selection,
              pressedScale: 0.96,
              borderRadius: PrismRadii.pillAll,
              onPressed: onTap,
              child: content,
            )
          : Semantics(
              button: true,
              enabled: false,
              label: strings.unavailableSemantics(tab.label, availability),
              child: ExcludeSemantics(child: content),
            ),
    );
  }
}
