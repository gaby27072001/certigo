import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Step — "Où en es-tu sur Azure ?". Single-select knowledge level with a
/// growing "signal bars" glyph (1 bar = beginner … 4 bars = expert) that helps
/// the coach calibrate difficulty from day one.
class LevelScreen extends ConsumerWidget {
  const LevelScreen({super.key});

  static const List<(KnowledgeLevel, int, String, String)> _options =
      <(KnowledgeLevel, int, String, String)>[
    (KnowledgeLevel.beginner, 1, 'Débutant', 'Je débute en Cloud / Azure'),
    (KnowledgeLevel.intermediate, 2, 'Intermédiaire', 'Je connais les bases du Cloud'),
    (KnowledgeLevel.advanced, 3, 'Avancé', 'J\'utilise Azure au quotidien'),
    (KnowledgeLevel.expert, 4, 'Expert', 'Je prépare des certifications avancées'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final PrismColorScheme p = context.prism;

    return OnboardingScaffold(
      progress: 0.38,
      onBack: () => context.go(OnboardingRoutes.attribution),
      primaryLabel: 'CONTINUER',
      onPrimary: c.level == null ? null : () => context.go(OnboardingRoutes.levelReaction),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Où en es-tu sur Azure ?'),
          const SizedBox(height: 24),
          for (final (KnowledgeLevel value, int bars, String label, String subtitle)
              in _options) ...<Widget>[
            _LevelTile(
              leading: SignalBars(level: bars, color: p.primary, size: 26),
              label: label,
              subtitle: subtitle,
              selected: c.level == value,
              onTap: () => c.setLevel(value),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// A selectable tile with a leading glyph, a bold label and a subtitle line.
/// Designed to match the visual style of [ChoiceTile] while supporting two
/// lines of text.
class _LevelTile extends StatefulWidget {
  const _LevelTile({
    required this.leading,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final Widget leading;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LevelTile> createState() => _LevelTileState();
}

class _LevelTileState extends State<_LevelTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color accent = p.primary;
    final bool sel = widget.selected;

    final Color border = sel ? accent : p.border;
    final Color lip = sel ? _shift(accent, -0.12) : _shift(p.border, -0.06);
    final Color fill = sel
        ? Color.alphaBlend(
            accent.withOpacity(p.brightness == Brightness.dark ? 0.20 : 0.08),
            p.surface,
          )
        : p.surface;

    return Semantics(
      button: true,
      selected: sel,
      label: '${widget.label}: ${widget.subtitle}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: PrismMotion.fast,
          curve: PrismMotion.standard,
          margin: EdgeInsets.only(bottom: _down ? 0 : 3),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: PrismRadii.cardLg,
            border: Border.all(color: border, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(color: lip, offset: Offset(0, _down ? 0 : 3), blurRadius: 0),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 34,
                height: 34,
                child: Center(child: widget.leading),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 16.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: t.bodySmall?.copyWith(
                        color: sel ? accent : p.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Checkbox(selected: sel, accent: accent, border: p.border),
            ],
          ),
        ),
      ),
    );
  }

  static Color _shift(Color c, double amount) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.selected, required this.accent, required this.border});

  final bool selected;
  final Color accent;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PrismMotion.fast,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? accent : border, width: 2),
      ),
      child: AnimatedSwitcher(
        duration: PrismMotion.fast,
        switchInCurve: PrismMotion.spring,
        switchOutCurve: PrismMotion.standard,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: selected
            ? const Icon(
                Icons.check_rounded,
                key: ValueKey<String>('level-check'),
                size: 17,
                color: Colors.white,
              )
            : const SizedBox.shrink(key: ValueKey<String>('level-empty')),
      ),
    );
  }
}
