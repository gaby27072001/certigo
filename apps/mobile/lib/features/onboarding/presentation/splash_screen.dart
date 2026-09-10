import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'onboarding_common.dart';

/// Brand splash — a full-bleed primary screen with the wordmark and the guide,
/// shown for a beat before the welcome screen. The equivalent of the colored
/// boot screen at the very start of the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) context.go(OnboardingRoutes.welcome);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Duration d = reduceMotion ? Duration.zero : PrismMotion.slow;
    return GestureDetector(
      onTap: () => context.go(OnboardingRoutes.welcome),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[p.primaryFill, p.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: <Widget>[
                Center(
                  child: AnimatedSlide(
                    offset: _visible ? Offset.zero : const Offset(0, 0.05),
                    duration: d,
                    curve: PrismMotion.decelerate,
                    child: AnimatedOpacity(
                      opacity: _visible ? 1 : 0,
                      duration: d,
                      curve: PrismMotion.decelerate,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedScale(
                            scale: _visible ? 1 : 0.9,
                            duration: d,
                            curve: PrismMotion.spring,
                            child: const MascotHero(
                              mascot: AuroraMascot.nimbus,
                              mood: MascotMood.celebrate,
                              size: 132,
                              ground: false,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Certigo',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tes certifs Microsoft, leçon par leçon',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.85)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: AnimatedOpacity(
                      opacity: _visible ? 1 : 0,
                      duration: d,
                      curve: PrismMotion.decelerate,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.9)),
                        ),
                      ),
                    ),
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
