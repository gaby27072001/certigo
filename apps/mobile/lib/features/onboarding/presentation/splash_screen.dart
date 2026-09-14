import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'onboarding_common.dart';

/// Brand splash — a full-bleed primary screen with the wordmark and the guide,
/// shown for a beat before the welcome screen. The equivalent of the colored
/// boot screen at the very start of the app.
///
/// **L'écran n'a pas d'horloge à lui.** Sa destination est connue dès le
/// montage : il n'attend aucune donnée. La seule chose qui reste à attendre est
/// son animation d'entrée, alors c'est elle — et rien d'autre — qui porte la
/// navigation. Quand la plateforme demande un mouvement réduit, il n'y a plus
/// d'entrée à laisser atterrir, donc plus rien à attendre du tout.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final CurvedAnimation _settle;
  late final CurvedAnimation _pop;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // Durée volontairement absente ici : elle dépend de MediaQuery, qui n'est
    // lisible qu'à partir de didChangeDependencies.
    _entrance = AnimationController(vsync: this)..addStatusListener(_onEntranceStatus);
    _settle = CurvedAnimation(parent: _entrance, curve: PrismMotion.decelerate);
    _pop = CurvedAnimation(parent: _entrance, curve: PrismMotion.spring);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(_settle);
    _scale = Tween<double>(begin: 0.9, end: 1).animate(_pop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entrance.duration = PrismMotion.resolve(context, PrismMotion.slow);
    if (_entrance.status == AnimationStatus.dismissed) _entrance.forward();
  }

  @override
  void dispose() {
    _settle.dispose();
    _pop.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _leave();
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    // Une entrée de durée nulle se termine **pendant** didChangeDependencies :
    // naviguer sur place reviendrait à muter l'arbre en cours de construction.
    // `ensureVisualUpdate` garantit qu'un frame viendra porter ce rappel même
    // si l'arbre est déjà au repos (cas de l'appui après la fin de l'entrée).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(OnboardingRoutes.welcome);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return GestureDetector(
      onTap: _leave,
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
                  child: SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _settle,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ScaleTransition(
                            scale: _scale,
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
                    child: FadeTransition(
                      opacity: _settle,
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
