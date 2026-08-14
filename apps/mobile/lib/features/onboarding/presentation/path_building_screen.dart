import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// The "we're building your course…" beat — a progress ring that fills over
/// ~1.8 s while a line of social proof reassures the learner, then auto-advances
/// to the next question. Mirrors the reference flow's course-construction pause.
class PathBuildingScreen extends ConsumerStatefulWidget {
  const PathBuildingScreen({super.key});

  @override
  ConsumerState<PathBuildingScreen> createState() => _PathBuildingScreenState();
}

class _PathBuildingScreenState extends ConsumerState<PathBuildingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _advance;

  static const List<String> _steps = <String>[
    'Analyse de ton objectif…',
    'Sélection des notions clés…',
    'Assemblage de tes leçons…',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_controller.isAnimating && _controller.value == 0) {
      if (reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
      _advance = Timer(
        reduceMotion ? const Duration(milliseconds: 400) : const Duration(milliseconds: 2000),
        _next,
      );
    }
  }

  void _next() {
    if (mounted) context.go(OnboardingRoutes.attribution);
  }

  @override
  void dispose() {
    _advance?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final String cert = c.targetCertification?.code ?? 'ta certification';

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: <Widget>[
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, _) {
                  final int pct = (_controller.value * 100).round();
                  final int stepIndex = (_controller.value * _steps.length).floor().clamp(
                        0,
                        _steps.length - 1,
                      );
                  return Column(
                    children: <Widget>[
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: _controller.value <= 0 ? null : _controller.value,
                                strokeWidth: 8,
                                backgroundColor: p.surfaceAlt,
                                valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: t.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: p.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _steps[stepIndex],
                        textAlign: TextAlign.center,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'On construit ton cours sur mesure.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.4),
              ),
              const Spacer(flex: 2),
              _SocialProof(
                text: 'Rejoins les milliers de personnes qui préparent $cert avec Certigo.',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialProof extends StatelessWidget {
  const _SocialProof({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.primary.withOpacity(0.08),
        borderRadius: PrismRadii.cardLg,
        border: Border.all(color: p.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.groups_rounded, color: p.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
