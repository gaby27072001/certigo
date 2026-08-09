import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import 'onboarding_common.dart';

/// A single icon + title + subtitle benefit row for [ValueListScreen].
class ValueBenefit {
  const ValueBenefit({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;
}

/// A "here's what you'll achieve" value screen — a mascot prompt over a short,
/// icon-led list of concrete benefits. Reused wherever the flow needs to sell an
/// outcome (e.g. "Ce que tu peux accomplir en 3 mois").
class ValueListScreen extends StatelessWidget {
  const ValueListScreen({
    super.key,
    required this.message,
    required this.benefits,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
    this.progress,
    this.accent,
  });

  final String message;
  final List<ValueBenefit> benefits;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onBack;
  final double? progress;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: progress,
      onBack: onBack,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          MascotPrompt(message: message),
          const SizedBox(height: 28),
          for (final ValueBenefit b in benefits) ...<Widget>[
            _BenefitRow(benefit: b, accent: accent),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit, this.accent});

  final ValueBenefit benefit;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color a = accent ?? p.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: a.withOpacity(0.12), borderRadius: PrismRadii.cardMd),
          alignment: Alignment.center,
          child: Icon(benefit.icon, color: a, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(benefit.title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                benefit.subtitle,
                style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
