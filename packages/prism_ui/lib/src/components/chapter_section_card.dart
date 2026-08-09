import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';
import '../tokens/prism_spacing.dart';
import 'aurora_mascot.dart';
import 'speech_bubble.dart';

/// A big, Duolingo-"section-picker"-style card for one certification chapter
/// (a `PathUnit`), adapted to the Certigo look.
///
/// Cards stack vertically down the catalogue: a thick glossy progress bar, a
/// lesson counter badge, a locked state (dimmed + padlock + an unlock hint) and
/// an optional intercalated mascot bubble — the Aurora Crew guardian that makes
/// the shelf feel alive. Available chapters expose a "Commencer ici" affordance
/// and route into the learning path when tapped.
///
/// Purely presentational and data-model-free: the screen maps its `PathUnit`
/// status/progress to these primitive fields.
class ChapterSectionCard extends StatelessWidget {
  const ChapterSectionCard({
    super.key,
    required this.index,
    required this.title,
    required this.accent,
    required this.lessonsTotal,
    required this.lessonsCompleted,
    this.locked = false,
    this.completed = false,
    this.lockedHint,
    this.onStart,
    this.mascot,
    this.mascotMessage,
  });

  /// 1-based chapter number shown as "CHAPITRE N".
  final int index;

  /// The chapter (unit) title.
  final String title;

  /// Per-domain accent color.
  final Color accent;

  /// Total lessons in the chapter.
  final int lessonsTotal;

  /// Lessons completed so far (drives the progress bar and the counter badge).
  final int lessonsCompleted;

  /// Whether the chapter is locked (dimmed, padlock, no tap).
  final bool locked;

  /// Whether the chapter is fully completed/mastered (check emblem, tonal wash).
  final bool completed;

  /// Optional French hint shown under a [locked] chapter, e.g.
  /// "Termine le chapitre précédent pour débloquer".
  final String? lockedHint;

  /// Tap handler for an available chapter; when null the card is inert.
  final VoidCallback? onStart;

  /// Optional Aurora Crew guardian shown as an intercalated bubble above the
  /// card (the "Duo peeking between sections" beat).
  final AuroraMascot? mascot;

  /// Message for the [mascot] bubble. Ignored when [mascot] is null.
  final String? mascotMessage;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;

    final Widget card = _buildCard(context, p);
    if (mascot == null) return card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _MascotInterlude(mascot: mascot!, message: mascotMessage ?? ''),
        const SizedBox(height: PrismSpacing.sm),
        card,
      ],
    );
  }

  Widget _buildCard(BuildContext context, PrismColorScheme p) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = p.brightness == Brightness.dark;

    final Color fill = locked
        ? p.surfaceAlt
        : completed
        ? Color.alphaBlend(accent.withOpacity(isDark ? 0.18 : 0.08), p.surface)
        : p.surface;
    final Color border = locked
        ? p.border
        : completed
        ? accent.withOpacity(0.30)
        : accent.withOpacity(0.45);
    final Color titleColor = locked ? p.textSecondary : p.textPrimary;

    final double progress = lessonsTotal == 0 ? 0 : lessonsCompleted / lessonsTotal;

    final Widget content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(PrismRadii.xxl),
        border: Border.all(color: border, width: locked ? 1 : 1.5),
        boxShadow: locked
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: accent.withOpacity(isDark ? 0.22 : 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                  spreadRadius: -8,
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ChapterEmblem(index: index, accent: accent, locked: locked, completed: completed),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'CHAPITRE $index',
                        style: text.labelSmall?.copyWith(
                          color: locked ? p.textSecondary : accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    _CounterBadge(
                      completed: lessonsCompleted,
                      total: lessonsTotal,
                      accent: accent,
                      muted: locked,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: titleColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _GlossyBar(value: progress, accent: accent, muted: locked),
                const SizedBox(height: 10),
                if (locked)
                  _LockedHint(hint: lockedHint, color: p.textSecondary)
                else if (!completed && onStart != null)
                  _StartHere(accent: accent),
              ],
            ),
          ),
        ],
      ),
    );

    if (locked || onStart == null) {
      return Semantics(
        label: locked ? 'Chapitre $index verrouillé, $title' : 'Chapitre $index, $title',
        child: locked ? Opacity(opacity: 0.72, child: content) : content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(PrismRadii.xxl),
        child: content,
      ),
    );
  }
}

/// The round chapter emblem: a number for available chapters, a check for
/// completed ones and a padlock for locked ones.
class _ChapterEmblem extends StatelessWidget {
  const _ChapterEmblem({
    required this.index,
    required this.accent,
    required this.locked,
    required this.completed,
  });

  final int index;
  final Color accent;
  final bool locked;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;

    if (locked) {
      return Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surface,
          shape: BoxShape.circle,
          border: Border.all(color: p.border),
        ),
        child: Icon(Icons.lock_rounded, color: p.textSecondary, size: 22),
      );
    }

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[accent, Color.alphaBlend(Colors.black.withOpacity(0.14), accent)],
        ),
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withOpacity(0.34),
            blurRadius: 12,
            offset: const Offset(0, 5),
            spreadRadius: -4,
          ),
        ],
      ),
      child: completed
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
          : Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
    );
  }
}

/// A pill counting completed / total lessons.
class _CounterBadge extends StatelessWidget {
  const _CounterBadge({
    required this.completed,
    required this.total,
    required this.accent,
    required this.muted,
  });

  final int completed;
  final int total;
  final Color accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Color color = muted ? p.textSecondary : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: PrismRadii.pillAll),
      child: Text(
        '$completed/$total leçons',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

/// A thick, glossy progress bar — the signature "earned progress" cue.
class _GlossyBar extends StatelessWidget {
  const _GlossyBar({required this.value, required this.accent, required this.muted});

  final double value;
  final Color accent;
  final bool muted;

  static const double _height = 14;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final double clamped = value.clamp(0.0, 1.0);
    final List<Color> fillColors = muted
        ? <Color>[p.textSecondary, p.textSecondary]
        : <Color>[accent, Color.alphaBlend(Colors.black.withOpacity(0.12), accent)];

    return ClipRRect(
      borderRadius: PrismRadii.pillAll,
      child: SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: p.surfaceAlt),
            if (clamped > 0)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: clamped,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: fillColors),
                    borderRadius: PrismRadii.pillAll,
                  ),
                  // Glossy top-half highlight.
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.5,
                      widthFactor: 1,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.28),
                          borderRadius: PrismRadii.pillAll,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The "Commencer ici" affordance on an available chapter.
class _StartHere extends StatelessWidget {
  const _StartHere({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          'Commencer ici',
          style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
      ],
    );
  }
}

/// The unlock hint shown under a locked chapter.
class _LockedHint extends StatelessWidget {
  const _LockedHint({required this.hint, required this.color});

  final String? hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.lock_outline_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hint ?? 'Termine le chapitre précédent pour débloquer',
            style: TextStyle(color: color, fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// A mascot peeking between chapters with a short line of encouragement.
class _MascotInterlude extends StatelessWidget {
  const _MascotInterlude({required this.mascot, required this.message});

  final AuroraMascot mascot;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        MascotAvatar(mascot: mascot, size: 48, mood: MascotMood.happy),
        const SizedBox(width: 10),
        Flexible(
          child: SpeechBubble(
            tail: SpeechTail.left,
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}
