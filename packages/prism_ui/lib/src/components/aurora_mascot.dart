import 'package:flutter/material.dart';

import 'mascot_assets.dart';

/// The **Aurora Crew** — Certigo's cast of mascots, each one a *gamified,
/// cutified Azure service icon* (the equivalent of Duolingo's Duo & friends).
/// Every member embodies a real Azure service or concept (the platform itself,
/// Functions, Cosmos DB, Defender, Bicep, AI, Blob Storage) so the mascot doubles
/// as a memory aid for its icon, and carries a signature color + a friendly face.
///
/// Mascots are intentionally decoupled from any data model so the design system
/// stays dependency-free; screens map their domain/unit to a crew member.
enum AuroraMascot {
  /// Azure itself — the main, welcoming face of Certigo ("the Duo").
  nimbus,

  /// Azure Functions — quick and energetic (a yellow lightning bolt).
  volt,

  /// Azure Cosmos DB — calm and dreamy (a ringed planet).
  cosmo,

  /// Microsoft Defender / Sentinel — protective (a little shield).
  sentinel,

  /// Bicep / IaC — the proud, methodical little strongman (a flexed arm).
  bicky,

  /// Azure AI / Foundry — curious and creative (sparkles).
  pixel,

  /// Azure Blob Storage — a soft little blob; the learner themselves, clumsy but
  /// endearing, who progresses with you.
  pip,
}

/// Expressive state of a mascot. Drives the drawn face (and, later, Rive).
enum MascotMood { idle, happy, celebrate, sad }

/// How a [MascotAvatar] is framed when custom image art is used.
///
/// * [disc]  — the art is clipped into the signature glossy disc (consistent
///   with the procedural avatars; ideal for headers, path guardians, lists).
/// * [free]  — the art is painted as-is with no disc, so a full-body character
///   (à la Duo standing) can breathe (ideal for the welcome / hero moments).
///
/// Has no effect on the built-in procedural face, which is always a disc.
enum MascotShape { disc, free }

/// Per-member identity (French display name, role, signature color, icon).
extension AuroraMascotInfo on AuroraMascot {
  /// Short display name shown on banners and headers.
  String get displayName => switch (this) {
    AuroraMascot.nimbus => 'Nimbus',
    AuroraMascot.volt => 'Volt',
    AuroraMascot.cosmo => 'Cosmo',
    AuroraMascot.sentinel => 'Sentinel',
    AuroraMascot.bicky => 'Bicky',
    AuroraMascot.pixel => 'Pixel',
    AuroraMascot.pip => 'Pip',
  };

  /// Pedagogical role, used for accessibility labels.
  String get role => switch (this) {
    AuroraMascot.nimbus => 'la mascotte Azure',
    AuroraMascot.volt => 'Azure Functions',
    AuroraMascot.cosmo => 'Azure Cosmos DB',
    AuroraMascot.sentinel => 'Microsoft Defender',
    AuroraMascot.bicky => 'Bicep',
    AuroraMascot.pixel => 'Azure AI',
    AuroraMascot.pip => 'Stockage Blob',
  };

  /// Signature color — stable per member, color-blind aware.
  Color get color => switch (this) {
    AuroraMascot.nimbus => const Color(0xFF0078D4),
    AuroraMascot.volt => const Color(0xFFFFB020),
    AuroraMascot.cosmo => const Color(0xFF8C5CF6),
    AuroraMascot.sentinel => const Color(0xFF0EA5A5),
    AuroraMascot.bicky => const Color(0xFFFF7A45),
    AuroraMascot.pixel => const Color(0xFFF0476A),
    AuroraMascot.pip => const Color(0xFF0078D4),
  };

  /// Service / concept icon shown on the mascot's badge — echoes the real Azure
  /// service the mascot gamifies (used by the procedural fallback face).
  IconData get icon => switch (this) {
    AuroraMascot.nimbus => Icons.cloud_rounded,
    AuroraMascot.volt => Icons.bolt_rounded,
    AuroraMascot.cosmo => Icons.bubble_chart_rounded,
    AuroraMascot.sentinel => Icons.shield_rounded,
    AuroraMascot.bicky => Icons.fitness_center_rounded,
    AuroraMascot.pixel => Icons.auto_awesome_rounded,
    AuroraMascot.pip => Icons.water_drop_rounded,
  };
}

/// A stylised mascot avatar: a luminous gradient disc with a friendly face and
/// a service badge. Purely presentational; pass [mood] to change the expression
/// and [onTap] to make it interactive (e.g. a guardian on the path).
class MascotAvatar extends StatelessWidget {
  const MascotAvatar({
    super.key,
    required this.mascot,
    this.size = 64,
    this.mood = MascotMood.idle,
    this.onTap,
    this.showBadge = true,
    this.shape = MascotShape.disc,
  });

  final AuroraMascot mascot;
  final double size;
  final MascotMood mood;
  final VoidCallback? onTap;

  /// Whether to draw the small service-icon badge. Hidden for tiny avatars.
  /// Ignored for [MascotShape.free] custom art.
  final bool showBadge;

  /// Framing used when custom image art is registered (see [MascotShape]).
  final MascotShape shape;

  @override
  Widget build(BuildContext context) {
    final MascotArt? art = MascotRegistry.instance.resolve(mascot, mood);
    final Widget figure = art != null ? _buildImage(art) : _buildDrawn();

    final Widget labelled = Semantics(
      label: '${mascot.displayName}, ${mascot.role}',
      image: true,
      button: onTap != null,
      child: figure,
    );

    if (onTap == null) return labelled;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: labelled);
  }

  /// Custom character art, framed per [shape], with a graceful fall back to the
  /// procedural face if the file is missing or fails to decode at runtime.
  Widget _buildImage(MascotArt art) {
    final Image image = Image.asset(
      art.assetPath,
      package: art.package,
      width: size,
      height: size,
      fit: shape == MascotShape.disc ? BoxFit.cover : BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext _, Object __, StackTrace? ___) => _buildDrawn(),
    );

    if (shape == MascotShape.free) {
      return SizedBox(width: size, height: size, child: image);
    }

    final Color base = mascot.color;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: base.withOpacity(0.30),
                  blurRadius: size * 0.30,
                  offset: Offset(0, size * 0.12),
                  spreadRadius: -size * 0.08,
                ),
              ],
            ),
            child: ClipOval(child: image),
          ),
          if (showBadge) _badge(_shift(base, -0.18)),
        ],
      ),
    );
  }

  Widget _badge(Color dark) {
    return Positioned(
      right: -size * 0.02,
      bottom: -size * 0.02,
      child: Container(
        width: size * 0.42,
        height: size * 0.42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(mascot.icon, size: size * 0.24, color: dark),
      ),
    );
  }

  Widget _buildDrawn() {
    final Color base = mascot.color;
    final Color light = _shift(base, 0.22);
    final Color dark = _shift(base, -0.18);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Body — luminous gradient disc with a soft colored glow.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[light, dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: base.withOpacity(0.34),
                  blurRadius: size * 0.30,
                  offset: Offset(0, size * 0.12),
                  spreadRadius: -size * 0.08,
                ),
              ],
            ),
          ),
          // Glossy highlight (top-left), the Liquid-Glass sheen.
          Positioned(
            left: size * 0.18,
            top: size * 0.12,
            child: Container(
              width: size * 0.30,
              height: size * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                color: Colors.white.withOpacity(0.32),
              ),
            ),
          ),
          // Friendly face.
          Positioned.fill(child: CustomPaint(painter: _MascotFacePainter(mood))),
          // Service badge.
          if (showBadge) _badge(dark),
        ],
      ),
    );
  }

  /// Lightens (positive [amount]) or darkens (negative) a color in HSL space.
  static Color _shift(Color c, double amount) {
    final HSLColor hsl = HSLColor.fromColor(c);
    final double l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}

/// A large, free-standing "hero" mascot for welcome / greeting moments — the
/// equivalent of a big standing Duo. Uses full-body custom art when available
/// ([MascotShape.free]); otherwise shows the procedural disc face resting on a
/// soft ground shadow so the welcome screen still feels alive before art exists.
class MascotHero extends StatelessWidget {
  const MascotHero({
    super.key,
    required this.mascot,
    this.mood = MascotMood.happy,
    this.size = 160,
    this.ground = true,
  });

  final AuroraMascot mascot;
  final MascotMood mood;
  final double size;

  /// Whether to paint the little elliptical ground shadow under the figure.
  final bool ground;

  @override
  Widget build(BuildContext context) {
    final bool custom = MascotRegistry.instance.hasCustomArt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MascotAvatar(
          mascot: mascot,
          mood: mood,
          size: size,
          showBadge: false,
          shape: custom ? MascotShape.free : MascotShape.disc,
        ),
        if (ground) ...<Widget>[
          SizedBox(height: size * 0.04),
          Container(
            width: size * 0.52,
            height: size * 0.07,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.10),
              borderRadius: BorderRadius.all(Radius.circular(size)),
            ),
          ),
        ],
      ],
    );
  }
}

class _MascotFacePainter extends CustomPainter {
  const _MascotFacePainter(this.mood);

  final MascotMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const Color ink = Color(0xFF0B1120);

    final Paint eye = Paint()..color = ink;
    final Paint catchlight = Paint()..color = Colors.white.withOpacity(0.9);
    final double eyeR = w * 0.075;
    final Offset le = Offset(w * 0.38, h * 0.45);
    final Offset re = Offset(w * 0.62, h * 0.45);

    if (mood == MascotMood.celebrate) {
      // Joyful closed "^ ^" eyes.
      final Paint arc = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04
        ..strokeCap = StrokeCap.round;
      _drawEyeArc(canvas, le, eyeR, arc);
      _drawEyeArc(canvas, re, eyeR, arc);
    } else {
      canvas.drawCircle(le, eyeR, eye);
      canvas.drawCircle(re, eyeR, eye);
      canvas.drawCircle(le.translate(-eyeR * 0.3, -eyeR * 0.3), eyeR * 0.32, catchlight);
      canvas.drawCircle(re.translate(-eyeR * 0.3, -eyeR * 0.3), eyeR * 0.32, catchlight);
    }

    // Mouth — curvature encodes the mood.
    final double curve = switch (mood) {
      MascotMood.happy => h * 0.13,
      MascotMood.celebrate => h * 0.14,
      MascotMood.idle => h * 0.07,
      MascotMood.sad => -h * 0.08,
    };
    final Paint mouth = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    final Path path = Path()
      ..moveTo(w * 0.38, h * 0.62)
      ..quadraticBezierTo(w * 0.50, h * 0.62 + curve, w * 0.62, h * 0.62);
    canvas.drawPath(path, mouth);
  }

  void _drawEyeArc(Canvas canvas, Offset center, double r, Paint paint) {
    final Path p = Path()
      ..moveTo(center.dx - r, center.dy + r * 0.4)
      ..quadraticBezierTo(center.dx, center.dy - r * 0.8, center.dx + r, center.dy + r * 0.4);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_MascotFacePainter oldDelegate) => oldDelegate.mood != mood;
}
