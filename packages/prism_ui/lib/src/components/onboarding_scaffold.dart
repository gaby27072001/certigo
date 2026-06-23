import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';
import 'prism_button.dart';

/// The shared chrome for every onboarding step.
///
/// Lays out the three constants of the flow exactly like a polished learning
/// app's wizard: a thin rounded **progress bar** (with an optional back chevron)
/// pinned at the top, the step body in the middle, and a full-width **sticky
/// CTA** at the bottom that stays disabled until the step is valid (pass
/// `onPrimary: null`). An optional [secondary] action sits just below the CTA.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    required this.primaryLabel,
    this.onPrimary,
    this.progress,
    this.onBack,
    this.primaryTone,
    this.primaryLoading = false,
    this.secondary,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 0),
  });

  final Widget child;

  /// Label of the bottom CTA (e.g. "CONTINUER", "C'EST PARTI").
  final String primaryLabel;

  /// CTA handler; `null` greys the button out (step not yet valid).
  final VoidCallback? onPrimary;

  /// 0..1 progress; `null` hides the top bar entirely.
  final double? progress;

  /// Back handler; `null` hides the chevron.
  final VoidCallback? onBack;

  final Color? primaryTone;
  final bool primaryLoading;

  /// Optional low-emphasis action rendered under the CTA.
  final Widget? secondary;

  /// Whether the body scrolls (long question lists) or fills the space.
  final bool scrollable;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;

    final Widget body = Padding(
      padding: padding,
      child: scrollable
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: child,
            )
          : child,
    );

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (progress != null || onBack != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 20, 6),
                child: Row(
                  children: <Widget>[
                    if (onBack != null)
                      _BackChevron(onTap: onBack!, color: p.textSecondary)
                    else
                      const SizedBox(width: 4),
                    const SizedBox(width: 8),
                    Expanded(
                      child: progress == null
                          ? const SizedBox.shrink()
                          : _TopProgress(value: progress!.clamp(0, 1), color: p.primary, track: p.surfaceAlt),
                    ),
                  ],
                ),
              ),
            Expanded(child: body),
            _StickyCta(
              label: primaryLabel,
              onPressed: onPrimary,
              tone: primaryTone,
              loading: primaryLoading,
              secondary: secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackChevron extends StatelessWidget {
  const _BackChevron({required this.onTap, required this.color});

  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retour',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.arrow_back_rounded, color: color, size: 26),
        ),
      ),
    );
  }
}

/// Thin, very-rounded progress track with an animated fill — the top bar of the
/// onboarding flow.
class _TopProgress extends StatelessWidget {
  const _TopProgress({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progression',
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 16,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: ColoredBox(color: track)),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value),
                duration: PrismMotion.base,
                curve: PrismMotion.standard,
                builder: (BuildContext context, double v, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v <= 0 ? 0.0001 : v,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      // A soft top sheen, the Duolingo-style glossy fill.
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          widthFactor: 0.88,
                          heightFactor: 0.34,
                          child: Container(
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyCta extends StatelessWidget {
  const _StickyCta({
    required this.label,
    required this.onPressed,
    required this.tone,
    required this.loading,
    required this.secondary,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? tone;
  final bool loading;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool enabled = onPressed != null && !loading;
    final Duration d = reduceMotion ? Duration.zero : PrismMotion.fast;
    return Container(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedScale(
            scale: enabled ? 1 : 0.985,
            duration: d,
            curve: PrismMotion.decelerate,
            child: PrismButton(
              label: label,
              tone: tone,
              loading: loading,
              onPressed: onPressed,
            ),
          ),
          if (secondary != null) ...<Widget>[
            const SizedBox(height: 6),
            secondary!,
          ],
        ],
      ),
    );
  }
}
