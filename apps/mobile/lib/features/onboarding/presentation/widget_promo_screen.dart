import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'onboarding_common.dart';

/// The home-screen widget promo — a drawn phone mockup with a Certigo widget,
/// and "AJOUTER" / "PLUS TARD" actions. A deliberate placeholder (no real
/// home-screen widget yet), so it carries a discreet "bientôt" tag and both
/// actions simply advance the flow.
class WidgetPromoScreen extends StatelessWidget {
  const WidgetPromoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    void go() => context.go(OnboardingRoutes.widgetReaction);

    return OnboardingScaffold(
      progress: 0.78,
      onBack: () => context.go(OnboardingRoutes.notifications),
      primaryLabel: 'AJOUTER LE WIDGET',
      onPrimary: go,
      secondary: TextButton(
        onPressed: go,
        child: Text('Plus tard', style: t.labelLarge?.copyWith(color: p.textSecondary)),
      ),
      scrollable: false,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[SoonTag()],
          ),
          const SizedBox(height: 12),
          Text(
            'Garde ta série sous les yeux',
            textAlign: TextAlign.center,
            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoute le widget Certigo à ton écran d\'accueil pour ne jamais oublier ta leçon du jour.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          const Expanded(child: Center(child: _PhoneMockup())),
        ],
      ),
    );
  }
}

/// A minimal, drawn phone frame showing a mocked Certigo home-screen widget.
class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    // Drawn at a fixed logical size and scaled to fit, so the phone (and its
    // inner widget card) never squishes below its natural width — even in a
    // short viewport where the available region gets tiny.
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 220,
        height: 440,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.textPrimary,
            borderRadius: BorderRadius.circular(34),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[p.primary.withOpacity(0.25), p.surface],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
            child: Column(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                // The mocked widget card.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: PrismRadii.cardLg,
                    border: Border.all(color: p.border),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      const MascotAvatar(
                        mascot: AuroraMascot.nimbus,
                        size: 40,
                        showBadge: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Série de 3 jours 🔥',
                              style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ta leçon du jour t\'attend',
                              style: t.bodySmall?.copyWith(color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
