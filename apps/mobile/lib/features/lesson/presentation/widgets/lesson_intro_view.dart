import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Opening screen of a lesson — sets context and intent before the Learn Loop.
class LessonIntroView extends StatelessWidget {
  const LessonIntroView({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final int checks =
        lesson.blocks.where((LessonBlock b) => b.type == BlockType.check && b.check != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PrismSpacing.sm,
            vertical: PrismSpacing.debt6,
          ),
          decoration: BoxDecoration(color: p.primarySoft, borderRadius: PrismRadii.pillAll),
          child: Text(
            lesson.domainId.toUpperCase(),
            style: text.labelSmall?.copyWith(
              color: p.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(lesson.title, style: text.headlineMedium?.copyWith(height: 1.15)),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            _MetaPill(icon: Icons.schedule_rounded, label: '${lesson.estMinutes} min'),
            const SizedBox(width: 12),
            _MetaPill(icon: Icons.fact_check_rounded, label: '$checks vérifications'),
          ],
        ),
        const SizedBox(height: 24),
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: p.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.auto_stories_rounded, color: p.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Ce que tu vas faire', style: text.titleMedium),
                ],
              ),
              const SizedBox(height: 14),
              const _Bullet(text: 'Comprendre le concept clé, simplement.'),
              const _Bullet(text: 'Le relier à un scénario Azure concret.'),
              _Bullet(text: 'Valider avec $checks vérifications de compréhension.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.sm, vertical: PrismSpacing.xs),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: PrismRadii.pillAll,
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: p.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: text.labelMedium?.copyWith(color: p.textSecondary)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: PrismSpacing.debt7),
            child: Icon(Icons.circle, size: 6, color: p.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: textTheme.bodyMedium?.copyWith(height: 1.4))),
        ],
      ),
    );
  }
}
