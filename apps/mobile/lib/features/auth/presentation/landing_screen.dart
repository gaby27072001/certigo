import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import 'widgets/get_started_sheet.dart';

// ---------------------------------------------------------------------------
// Design defaults — TRIVIALEMENT basculables (l'équipe itérera dessus).
// Change une seule ligne pour tester une autre direction.
// ---------------------------------------------------------------------------

/// Style du CTA « Commencer ».
enum _CtaStyle {
  /// Pilule à la couleur de marque (Azure). Défaut.
  azure,

  /// Pilule sombre (encre) — alternative future.
  ink,
}

/// Ancre lumineuse au centre du champ orbital.
enum _CenterAnchor {
  /// L'initiale « C » de Certigo dans un anneau glass. Défaut.
  brandC,

  /// Une étoile ✨ dessinée en dégradé — alternative future.
  star,
}

/// **Choix de design actifs.** Bascule en 1 ligne pour itérer.
const _CtaStyle _kCtaStyle = _CtaStyle.azure;
const _CenterAnchor _kCenterAnchor = _CenterAnchor.brandC;

/// Dégradé de marque du hero (Azure → violet → ember).
const LinearGradient _kBrandGradient = LinearGradient(
  colors: kOrbitBrandGradient,
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// **Écran d'ouverture façon Luma** — le vrai premier écran au lancement (avant
/// toute authentification).
///
/// Structure : logos cloud & IT en orbite autour d'une ancre « C » (Certigo),
/// wordmark « Certigo », gros titre dont la 2ᵉ ligne est en dégradé, un seul
/// CTA « Commencer » qui ouvre la bottom sheet d'auth, et un lien « J'ai déjà
/// un compte ».
///
/// Adapté de Luma (pas un copié-collé) : palette Prism Azure→violet→ember,
/// disques glass glossy, léger flottement (Liquid-Glass). L'entrée (fade+scale
/// du centre puis apparition staggerée des items) respecte « réduire les
/// animations ».
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: PrismMotion.celebrate,
  );

  bool _started = false;

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  /// Items en orbite : les **logos des grands acteurs cloud / IT** (Microsoft,
  /// AWS, Google, Docker, Linux, Python, GitHub…) posés sur trois anneaux
  /// concentriques. Certigo couvre les certifications de tout l'écosystème IT,
  /// pas seulement Microsoft. L'apparition est staggerée (chaque item entre un
  /// peu après le précédent).
  List<OrbitItem> _orbitItems() {
    // angle en radians ; 0 = 3h, croît dans le sens horaire.
    double deg(double d) => d * math.pi / 180;

    // Descripteurs (sans wrapper) pour pouvoir calculer un stagger par index.
    // Couleurs = teinte de marque de chaque logo (glow de la puce).
    final List<_OrbitSpec> specs = <_OrbitSpec>[
      // Anneau interne — les trois hyperscalers en tête.
      _OrbitSpec.brand(
        PrismBrandIcons.microsoft,
        const Color(0xFF0067B8),
        ring: 0,
        angle: deg(-90),
        size: 52,
      ),
      _OrbitSpec.brand(
        PrismBrandIcons.aws,
        const Color(0xFFFF9900),
        ring: 0,
        angle: deg(40),
        size: 46,
      ),
      _OrbitSpec.brand(
        PrismBrandIcons.google,
        const Color(0xFF4285F4),
        ring: 0,
        angle: deg(165),
        size: 46,
      ),
      // Anneau médian — outils & plateformes IT.
      _OrbitSpec.brand(
        PrismBrandIcons.docker,
        const Color(0xFF2496ED),
        ring: 1,
        angle: deg(-58),
        size: 48,
      ),
      _OrbitSpec.brand(
        PrismBrandIcons.python,
        const Color(0xFF3776AB),
        ring: 1,
        angle: deg(8),
        size: 44,
      ),
      _OrbitSpec.brand(
        PrismBrandIcons.linux,
        const Color(0xFF1F2937),
        ring: 1,
        angle: deg(118),
        size: 48,
      ),
      _OrbitSpec.brand(
        PrismBrandIcons.github,
        const Color(0xFF181717),
        ring: 1,
        angle: deg(210),
        size: 44,
      ),
      // Anneau externe — langages & écosystèmes.
      _OrbitSpec.brand(
        PrismBrandIcons.apple,
        const Color(0xFF111111),
        ring: 2,
        angle: deg(-100),
        size: 46,
      ),
      _OrbitSpec.brand(
        PrismBrandIcons.java,
        const Color(0xFFE76F00),
        ring: 2,
        angle: deg(-20),
        size: 46,
      ),
      _OrbitSpec.brand(
        PrismBrandIcons.android,
        const Color(0xFF3DDC84),
        ring: 2,
        angle: deg(70),
        size: 44,
      ),
      _OrbitSpec.brand(
        PrismBrandIcons.node,
        const Color(0xFF339933),
        ring: 2,
        angle: deg(160),
        size: 46,
      ),
    ];

    final int n = specs.length;
    return <OrbitItem>[
      for (int i = 0; i < n; i++)
        OrbitItem(
          ring: specs[i].ring,
          angle: specs[i].angle,
          size: specs[i].size,
          child: _RevealIn(
            controller: _reveal,
            interval: _staggerInterval(i, n),
            child: specs[i].build(),
          ),
        ),
    ];
  }

  /// Fenêtre d'apparition [start, end] de l'item [i] parmi [n] : les items
  /// entrent après le centre (≥ 0.25) et finissent avant 1.
  Interval _staggerInterval(int i, int n) {
    final double start = 0.25 + (i / n) * 0.55;
    final double end = (start + 0.3).clamp(0.0, 1.0);
    return Interval(start, end, curve: PrismMotion.decelerate);
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Entrée : joue une fois. En reduced-motion, on saute directement à la fin.
    if (!_started) {
      _started = true;
      if (reduceMotion) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    }

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Backdrop lumineux edge-to-edge (sous la SafeArea).
          const Positioned.fill(child: _LandingBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.lg),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: PrismSpacing.md),
                  // Hero orbital — scale-to-fit pour rester dans la largeur.
                  Flexible(
                    flex: 5,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: OrbitField(
                          ringRadii: const <double>[72, 122, 170],
                          centerSize: 104,
                          floatAmplitude: 5,
                          center: _RevealIn(
                            controller: _reveal,
                            interval: const Interval(0, 0.5, curve: PrismMotion.decelerate),
                            child: const _HeroAnchor(),
                          ),
                          items: _orbitItems(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: PrismSpacing.md),
                  // Bloc texte + CTA.
                  Flexible(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            'Certigo',
                            style: text.titleMedium?.copyWith(
                              color: p.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: PrismSpacing.sm),
                          Text(
                            'Tes certifs cloud & IT',
                            textAlign: TextAlign.center,
                            style: text.displaySmall?.copyWith(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          GradientText(
                            'commencent ici',
                            gradient: _kBrandGradient,
                            textAlign: TextAlign.center,
                            style: text.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: PrismSpacing.md),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Text(
                              'Des micro-leçons pour décrocher tes certifications '
                              'Microsoft, AWS, Google Cloud… et suivre ta readiness.',
                              textAlign: TextAlign.center,
                              style: text.titleMedium?.copyWith(color: p.textSecondary),
                            ),
                          ),
                          const SizedBox(height: PrismSpacing.lg),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _CommencerButton(onPressed: () => showGetStartedSheet(context)),
                          ),
                          const SizedBox(height: PrismSpacing.xs),
                          TextButton(
                            key: const Key('landing-existing-account'),
                            onPressed: () => showGetStartedSheet(context),
                            child: Text(
                              'J’ai déjà un compte',
                              style: text.titleSmall?.copyWith(
                                color: p.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: PrismSpacing.sm),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backdrop lumineux du landing : un dégradé de base + quelques halos radiaux
/// teintés marque, construits localement à partir des tokens Prism.
class _LandingBackdrop extends StatelessWidget {
  const _LandingBackdrop();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(p.primary.withOpacity(0.10), p.background),
            p.background,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -140,
            left: -90,
            child: _Glow(color: p.primary.withOpacity(0.22), size: 360),
          ),
          Positioned(
            top: -40,
            right: -120,
            child: _Glow(color: p.ember.withOpacity(0.16), size: 320),
          ),
          Positioned(
            bottom: -160,
            left: 10,
            child: _Glow(color: const Color(0xFF8C5CF6).withOpacity(0.16), size: 380),
          ),
        ],
      ),
    );
  }
}

/// Halo radial doux (repris de l'esprit d'`AuroraBackground`).
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: <Color>[color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

/// Puce glass glossy portant le **logo d'une marque IT** (Microsoft, AWS,
/// Google, Docker…). Corps blanc laqué façon tuile d'app pour que le logo
/// ressorte, halo teinté à la couleur de la marque.
class _BrandChip extends StatelessWidget {
  const _BrandChip({required this.icon, required this.tint, required this.size});

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    // Corps clair pour que les logos de marque restent lisibles (y compris les
    // logos sombres : GitHub, Apple, Linux).
    final Color body = Color.alphaBlend(Colors.white.withOpacity(0.86), p.surface);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color.alphaBlend(Colors.white.withOpacity(0.5), body), body],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tint.withOpacity(0.30),
            blurRadius: size * 0.42,
            offset: Offset(0, size * 0.14),
            spreadRadius: -size * 0.08,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.46, color: tint),
    );
  }
}

/// Ancre centrale : l'initiale « C » de Certigo dans un anneau glass lumineux,
/// ou une étoile dessinée en dégradé — selon [_kCenterAnchor].
class _HeroAnchor extends StatelessWidget {
  const _HeroAnchor();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    const double outer = 104;

    final Widget core = switch (_kCenterAnchor) {
      _CenterAnchor.brandC => Container(
          width: outer * 0.56,
          height: outer * 0.56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outer * 0.18),
            gradient: LinearGradient(
              colors: <Color>[p.primary, p.ember],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'C',
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
          ),
        ),
      _CenterAnchor.star => const SizedBox(
          width: outer * 0.56,
          height: outer * 0.56,
          child: CustomPaint(painter: _StarPainter()),
        ),
    };

    // Anneau glass lumineux autour du cœur.
    return Container(
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.glassFill,
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: p.primary.withOpacity(0.35),
            blurRadius: 34,
            offset: const Offset(0, 16),
            spreadRadius: -10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: core,
    );
  }
}

/// Étoile à 4 branches remplie du dégradé de marque (alternative d'ancre).
class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double rOuter = size.width / 2;
    final double rInner = rOuter * 0.42;
    final Path path = Path();
    for (int i = 0; i < 8; i++) {
      final double r = i.isEven ? rOuter : rInner;
      final double a = -math.pi / 2 + i * math.pi / 4;
      final Offset pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    final Paint paint = Paint()
      ..shader = _kBrandGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => false;
}

/// CTA « Commencer » — pilule pleine largeur, Azure ou encre selon [_kCtaStyle].
class _CommencerButton extends StatefulWidget {
  const _CommencerButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_CommencerButton> createState() => _CommencerButtonState();
}

class _CommencerButtonState extends State<_CommencerButton> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    // Switch (plutôt qu'un booléen) pour référencer les deux styles → bascule
    // triviale entre Azure et encre via [_kCtaStyle].
    final Color base = switch (_kCtaStyle) {
      _CtaStyle.azure => p.primary,
      _CtaStyle.ink => p.textPrimary,
    };
    final Color baseDark = switch (_kCtaStyle) {
      _CtaStyle.azure => p.primaryDark,
      _CtaStyle.ink => Color.alphaBlend(Colors.black.withOpacity(0.4), p.textPrimary),
    };

    return Semantics(
      button: true,
      label: 'Commencer',
      onTap: widget.onPressed,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(PrismRadii.pill),
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          onFocusChange: (bool value) {
            if (_focused != value) setState(() => _focused = value);
          },
          onHighlightChanged: (bool value) {
            if (_down != value) setState(() => _down = value);
          },
          onTap: widget.onPressed,
          child: ExcludeSemantics(
            child: AnimatedScale(
              scale: _down ? 0.98 : 1,
              duration: PrismMotion.resolve(context, PrismMotion.fast),
              curve: PrismMotion.standard,
              child: Container(
                height: 58,
                alignment: Alignment.center,
                foregroundDecoration: _focused
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(PrismRadii.pill),
                        border: Border.all(color: Colors.white, width: 2),
                      )
                    : null,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PrismRadii.pill),
                  gradient: LinearGradient(
                    colors: <Color>[base, baseDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: _down
                      ? const <BoxShadow>[]
                      : <BoxShadow>[
                          BoxShadow(
                            color: base.withOpacity(0.38),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                            spreadRadius: -6,
                          ),
                        ],
                ),
                child: Text(
                  'Commencer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Enveloppe d'entrée réutilisable : applique un fade + scale piloté par un
/// [controller] partagé, sur un [interval] (stagger). En reduced-motion, le
/// contrôleur est déjà à 1 → l'enfant apparaît directement.
class _RevealIn extends StatelessWidget {
  const _RevealIn({
    required this.controller,
    required this.child,
    this.interval = const Interval(0.15, 1, curve: PrismMotion.decelerate),
  });

  final AnimationController controller;
  final Widget child;
  final Interval interval;

  @override
  Widget build(BuildContext context) {
    final Animation<double> t = CurvedAnimation(parent: controller, curve: interval);
    return AnimatedBuilder(
      animation: t,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: t.value.clamp(0, 1),
          child: Transform.scale(scale: 0.6 + 0.4 * t.value, child: child),
        );
      },
      child: child,
    );
  }
}

/// Descripteur léger d'un logo de marque en orbite, pour construire les
/// [OrbitItem] avec un stagger indexé sans dupliquer la géométrie.
class _OrbitSpec {
  const _OrbitSpec.brand(
    this.icon,
    this.tint, {
    required this.ring,
    required this.angle,
    required this.size,
  });

  final int ring;
  final double angle;
  final double size;
  final IconData icon;
  final Color tint;

  Widget build() => _BrandChip(icon: icon, tint: tint, size: size);
}
