import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';

/// Progress state of a node on the skill-path. Decoupled from any data enum so
/// the design system has no dependency on the data layer.
enum PathNodeStatus { locked, available, inProgress, completed, mastered }

/// Whether a node is a normal lesson bubble or a unit checkpoint/gate.
enum PathNodeKind { lesson, checkpoint }

/// A single node on the winding skill-path — the iconic Duolingo bubble,
/// reimagined in Prism. Renders a chunky "3D press" disc (bright top face over a
/// darker lip), status-driven visuals (lock, star, progress ring, check, gold
/// crown), an optional progress ring, and a bouncing call-out when [current].
class PathNode extends StatefulWidget {
  const PathNode({
    super.key,
    required this.status,
    this.kind = PathNodeKind.lesson,
    this.accent,
    this.label,
    this.progress = 0,
    this.current = false,
    this.onTap,
    this.size = 64,
    this.startLabel,
  });

  final PathNodeStatus status;
  final PathNodeKind kind;

  /// Domain accent; falls back to the theme primary.
  final Color? accent;

  /// Caption rendered under the bubble.
  final String? label;

  /// 0..1 fill for the [PathNodeStatus.inProgress] ring.
  final double progress;

  /// Highlights this as the next action: gentle bounce + call-out pill.
  final bool current;

  final VoidCallback? onTap;
  final double size;

  /// Text of the floating call-out shown above a [current] node
  /// (e.g. "COMMENCER" / "REPRENDRE").
  final String? startLabel;

  @override
  State<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<PathNode> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  bool get _tappable => widget.onTap != null && widget.status != PathNodeStatus.locked;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme prism = context.prism;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (widget.current && !reduceMotion) {
      if (!_bounce.isAnimating) _bounce.repeat(reverse: true);
    } else if (_bounce.isAnimating) {
      _bounce
        ..stop()
        ..value = 0;
    }

    final _NodeVisual v = _visualFor(widget.status, widget.kind, prism, widget.accent);
    final double lip = widget.size * 0.16;

    Widget bubble = _buildBubble(v, lip);

    // Press sinks the bright face onto its lip for a satisfying 3D click.
    bubble = AnimatedScale(
      duration: PrismMotion.instant,
      curve: PrismMotion.standard,
      scale: _pressed ? 0.94 : 1.0,
      child: bubble,
    );

    if (widget.current && !reduceMotion) {
      bubble = AnimatedBuilder(
        animation: _bounce,
        builder: (BuildContext _, Widget? child) {
          final double t = Curves.easeInOut.transform(_bounce.value);
          return Transform.translate(offset: Offset(0, -4 * t), child: child);
        },
        child: bubble,
      );
    }

    final Widget interactive = GestureDetector(
      onTap: _tappable
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!.call();
            }
          : null,
      onTapDown: _tappable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _tappable ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _tappable ? () => setState(() => _pressed = false) : null,
      behavior: HitTestBehavior.opaque,
      child: bubble,
    );

    // Call-out pill floats above without affecting bubble center geometry.
    final Widget stack = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: <Widget>[
        interactive,
        if (widget.current && widget.startLabel != null)
          Positioned(
            top: -34,
            child: _CallOut(text: widget.startLabel!, accent: v.accent),
          ),
      ],
    );

    final Widget node = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        stack,
        if (widget.label != null) ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            width: widget.size * 1.9,
            child: Text(
              widget.label!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: widget.status == PathNodeStatus.locked
                    ? prism.textSecondary
                    : prism.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(button: _tappable, enabled: _tappable, label: _semanticLabel(), child: node);
  }

  Widget _buildBubble(_NodeVisual v, double lip) {
    return SizedBox(
      width: widget.size,
      height: widget.size + lip,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Lip — the darker bottom that gives the bubble its chunky depth.
          Positioned(
            top: lip,
            left: 0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: v.lip),
            ),
          ),
          // Top face.
          Positioned(
            top: _pressed ? lip * 0.55 : 0,
            left: 0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[v.faceTop, v.faceBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: v.glow
                    ? <BoxShadow>[
                        BoxShadow(
                          color: v.accent.withOpacity(0.5),
                          blurRadius: widget.size * 0.34,
                          spreadRadius: -widget.size * 0.06,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (v.ring != null)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(widget.size * 0.06),
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: v.ringProgress,
                            color: v.ring!,
                            track: v.faceBottom,
                            stroke: widget.size * 0.075,
                          ),
                        ),
                      ),
                    ),
                  Icon(v.icon, size: widget.size * 0.46, color: v.foreground),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _semanticLabel() {
    final String name =
        widget.label ?? (widget.kind == PathNodeKind.checkpoint ? 'Point de contrôle' : 'Leçon');
    return '$name — ${_statusLabel()}';
  }

  String _statusLabel() => switch (widget.status) {
        PathNodeStatus.mastered => 'maîtrisée',
        PathNodeStatus.completed => 'terminée',
        PathNodeStatus.inProgress => 'en cours',
        PathNodeStatus.available => 'disponible',
        PathNodeStatus.locked => 'verrouillée',
      };

  _NodeVisual _visualFor(
    PathNodeStatus status,
    PathNodeKind kind,
    PrismColorScheme prism,
    Color? accentOverride,
  ) {
    final Color accent = accentOverride ?? prism.primary;
    final Color accentLight = _shift(accent, 0.12);
    final Color accentDark = _shift(accent, -0.16);
    final bool checkpoint = kind == PathNodeKind.checkpoint;

    switch (status) {
      case PathNodeStatus.locked:
        return _NodeVisual(
          faceTop: prism.surfaceAlt,
          faceBottom: _shift(prism.surfaceAlt, -0.05),
          lip: _shift(prism.border, -0.05),
          foreground: prism.textSecondary,
          icon: Icons.lock_rounded,
          accent: accent,
        );
      case PathNodeStatus.available:
        return _NodeVisual(
          faceTop: accentLight,
          faceBottom: accent,
          lip: accentDark,
          foreground: Colors.white,
          icon: checkpoint ? Icons.flag_rounded : Icons.star_rounded,
          accent: accent,
        );
      case PathNodeStatus.inProgress:
        return _NodeVisual(
          faceTop: accentLight,
          faceBottom: accent,
          lip: accentDark,
          foreground: Colors.white,
          icon: checkpoint ? Icons.flag_rounded : Icons.bolt_rounded,
          accent: accent,
          ring: Colors.white,
          ringProgress: widget.progress.clamp(0.05, 1.0),
        );
      case PathNodeStatus.completed:
        return _NodeVisual(
          faceTop: accentLight,
          faceBottom: accent,
          lip: accentDark,
          foreground: Colors.white,
          icon: checkpoint ? Icons.emoji_events_rounded : Icons.check_rounded,
          accent: accent,
          ring: Colors.white.withOpacity(0.85),
          ringProgress: 1,
        );
      case PathNodeStatus.mastered:
        const Color gold = Color(0xFFFFC24B);
        return _NodeVisual(
          faceTop: const Color(0xFFFFE08A),
          faceBottom: gold,
          lip: const Color(0xFFE0962B),
          foreground: Colors.white,
          icon: checkpoint ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded,
          accent: gold,
          ring: Colors.white,
          ringProgress: 1,
          glow: true,
        );
    }
  }

  static Color _shift(Color c, double amount) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

class _NodeVisual {
  const _NodeVisual({
    required this.faceTop,
    required this.faceBottom,
    required this.lip,
    required this.foreground,
    required this.icon,
    required this.accent,
    this.ring,
    this.ringProgress = 0,
    this.glow = false,
  });

  final Color faceTop;
  final Color faceBottom;
  final Color lip;
  final Color foreground;
  final IconData icon;
  final Color accent;
  final Color? ring;
  final double ringProgress;
  final bool glow;
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - stroke / 2;
    final Paint trackPaint = Paint()
      ..color = track.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final Paint arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress.clamp(0.0, 1.0) * 2 * math.pi,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class _CallOut extends StatelessWidget {
  const _CallOut({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[
              BoxShadow(color: accent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        // Little downward caret tying the pill to the bubble.
        CustomPaint(size: const Size(14, 6), painter: _CaretPainter(accent)),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => old.color != color;
}
