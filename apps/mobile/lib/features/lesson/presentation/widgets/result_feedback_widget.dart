import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../tutor/presentation/tutor_sheet.dart';

/// End-of-lesson result: a score emblem, the rewards earned, a per-check recap
/// and a path back into the product (continue or review weak concepts).
class ResultFeedbackWidget extends StatelessWidget {
  const ResultFeedbackWidget({
    super.key,
    required this.result,
    required this.lesson,
    required this.trackId,
    required this.lessonId,
    required this.answers,
    required this.onContinue,
    required this.onReview,
  });

  final SubmitQuizResult result;
  final Lesson lesson;
  final String trackId;
  final String lessonId;

  /// The learner's locked selection per check itemId, used to ask the tutor to
  /// explain a specific answer.
  final Map<String, List<String>> answers;
  final VoidCallback onContinue;
  final VoidCallback onReview;

  String _stemFor(String itemId) {
    for (final LessonBlock block in lesson.blocks) {
      if (block.check?.id == itemId) return block.check!.stem;
    }
    return itemId;
  }

  void _explain(BuildContext context, ItemResult r) {
    showTutorSheet(
      context,
      request: TutorExplainRequest(
        trackId: trackId,
        lessonId: lessonId,
        itemId: r.itemId,
        selected: answers[r.itemId] ?? const <String>[],
      ),
      correct: r.correct,
    );
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final QuizRewards rewards = result.rewards;
    final bool passed = result.scorePct >= 60;
    final Color tone = passed ? p.success : p.warning;

    return ListView(
      padding: PrismSpacing.screen,
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 8),
        Center(child: _ScoreRing(scorePct: result.scorePct, tone: tone)),
        const SizedBox(height: 20),
        Text(
          passed ? 'Concept validé !' : 'Presque !',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          passed
              ? 'Tu maîtrises ce concept. On le consolide avec une révision espacée.'
              : 'Tu y es presque — une courte révision et ce sera acquis.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: p.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            XpChip(xp: rewards.newXp, delta: rewards.xpEarned),
            if (rewards.streakExtended) ...<Widget>[
              const SizedBox(width: 12),
              _RewardPill(
                icon: Icons.local_fire_department_rounded,
                label: 'Série +1',
                color: p.ember,
              ),
            ],
          ],
        ),
        if (rewards.levelUp) ...<Widget>[
          const SizedBox(height: 16),
          Center(
            child: _RewardPill(
              icon: Icons.military_tech_rounded,
              label: 'Niveau supérieur !',
              color: p.xpGold,
            ),
          ),
        ],
        const SizedBox(height: 24),
        PrismCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Récapitulatif', style: text.titleMedium),
              const SizedBox(height: 14),
              for (final ItemResult r in result.results) ...<Widget>[
                _ResultRow(
                  correct: r.correct,
                  stem: _stemFor(r.itemId),
                  tone: r.correct ? p.success : p.error,
                  onExplain: () => _explain(context, r),
                ),
                if (!identical(r, result.results.last)) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        if (result.weakConcepts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          CalloutBlock(
            kind: CalloutKind.warning,
            title: 'À renforcer',
            text: 'On replanifiera ${result.weakConcepts.length} concept(s) en '
                'révision pour bien les ancrer.',
          ),
        ],
        const SizedBox(height: 28),
        PrismButton(
          label: 'Continuer',
          icon: Icons.arrow_forward_rounded,
          onPressed: onContinue,
        ),
        const SizedBox(height: 10),
        Center(
          child: PrismButton.ghost(
            label: 'Réviser les points faibles',
            onPressed: onReview,
          ),
        ),
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.scorePct, required this.tone});

  final int scorePct;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 132,
            height: 132,
            child: CircularProgressIndicator(
              value: (scorePct / 100).clamp(0.0, 1.0),
              strokeWidth: 10,
              backgroundColor: p.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$scorePct%',
                style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'score',
                style: text.labelSmall?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: PrismSpacing.sm, vertical: PrismSpacing.debt7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: PrismRadii.pillAll,
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: text.labelLarge?.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.correct,
    required this.stem,
    required this.tone,
    required this.onExplain,
  });

  final bool correct;
  final String stem;
  final Color tone;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: tone,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(stem, style: text.bodyMedium?.copyWith(height: 1.35)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: PrismSpacing.debt30),
          child: GestureDetector(
            onTap: onExplain,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpacing.xxs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.auto_awesome_rounded, size: 16, color: p.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Demander au tuteur',
                    style: text.labelMedium?.copyWith(
                      color: p.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
