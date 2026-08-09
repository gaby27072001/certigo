import 'package:confetti/confetti.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../../app/providers.dart';

class ResultsSheet extends ConsumerStatefulWidget {
  const ResultsSheet({
    super.key,
    required this.result,
    required this.totalQuestions,
    required this.pendingSync,
    required this.trackId,
    required this.lessonId,
    required this.onDone,
    required this.onNextLesson,
  });

  final SubmitQuizResult result;
  final int totalQuestions;
  final bool pendingSync;
  final String trackId;
  final String lessonId;
  final VoidCallback onDone;
  final void Function(String nextId) onNextLesson;

  @override
  ConsumerState<ResultsSheet> createState() => _ResultsSheetState();
}

class _ResultsSheetState extends ConsumerState<ResultsSheet> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.result.scorePct >= 60) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String? _findNextLessonId(LearningPath path, String currentLessonId) {
    final List<PathLesson> lessons = path.units.expand((PathUnit u) => u.lessons).toList();
    final int idx = lessons.indexWhere((PathLesson l) => l.id == currentLessonId);
    if (idx == -1 || idx >= lessons.length - 1) return null;
    return lessons[idx + 1].id;
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final SubmitQuizResult result = widget.result;
    final int scorePct = result.scorePct;
    final int correct = result.results.where((ItemResult item) => item.correct).length;
    final bool strong = scorePct >= 80;
    final int xp = result.rewards.xpEarned;

    final AsyncValue<LearningPath> pathAsync = ref.watch(pathProvider(widget.trackId));
    final bool pathLoaded = pathAsync.hasValue;
    final String? nextLessonId = pathLoaded
        ? _findNextLessonId(pathAsync.requireValue, widget.lessonId)
        : null;

    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(PrismRadii.debt28)),
            border: Border.all(color: p.border),
          ),
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.lg,
            PrismSpacing.md,
            PrismSpacing.lg,
            PrismSpacing.debt28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: p.border, borderRadius: PrismRadii.pillAll),
              ),
              const SizedBox(height: 24),
              Icon(
                strong ? Icons.celebration_rounded : Icons.trending_up_rounded,
                color: strong ? p.xpGold : p.primary,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                widget.pendingSync
                    ? 'Soumis hors ligne'
                    : (strong ? 'Excellent !' : 'Bonne progression'),
                style: t.headlineMedium,
              ),
              Text(
                widget.pendingSync
                    ? 'Tes réponses sont enregistrées et seront synchronisées automatiquement.'
                    : '${correct > 0 || result.results.isNotEmpty ? '$correct / ${widget.totalQuestions} correct · ' : ''}$scorePct%',
                style: t.bodyLarge?.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  XpChip(xp: xp),
                  const SizedBox(width: 12),
                  StreakBadge(days: result.rewards.streakExtended ? 7 : 0),
                ],
              ),
              const SizedBox(height: 24),
              if (pathLoaded && nextLessonId != null) ...<Widget>[
                PrismButton(
                  label: 'Continuer → Leçon suivante',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => widget.onNextLesson(nextLessonId),
                ),
                const SizedBox(height: 12),
                PrismButton.secondary(label: 'Terminer', onPressed: widget.onDone),
              ] else ...<Widget>[
                PrismButton(label: 'Terminer', onPressed: widget.onDone),
                if (pathLoaded) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    "C'est tout pour aujourd'hui ! 🎉 Reviens demain",
                    style: t.bodyMedium?.copyWith(color: p.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          gravity: 0.05,
        ),
      ],
    );
  }
}
