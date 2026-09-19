import 'dart:math';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../shared/widgets/screen_header.dart';

/// Mock exam — a full, timed-style assessment that mirrors the real
/// certification experience. Unlike the lesson quiz (which grades locally for
/// instant feedback), the exam is graded by the SERVER: we collect every answer
/// plus per-item latency, post a [SubmitMockExamRequest], and render the
/// authoritative [MockExamResult] (scaled score, pass/fail, per-domain
/// breakdown, weak concepts and rewards). No local grading happens here.
class ExamScreen extends ConsumerWidget {
  const ExamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MockExam> async = ref.watch(examProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const ScreenHeader(title: 'Examen blanc'),
            Expanded(
              child: async.when(
                data: (MockExam exam) => exam.items.isEmpty
                    ? const _ExamEmpty()
                    : _ExamRunner(key: ValueKey<String>(exam.examId), exam: exam),
                loading: () => const _ExamLoading(),
                error: (Object error, StackTrace _) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PrismSpacing.gutter,
                    PrismSpacing.xs,
                    PrismSpacing.gutter,
                    PrismSpacing.gutter,
                  ),
                  child: PrismStatusView.error(
                    message: 'Impossible de charger cet examen.',
                    onRetry: () => ref.invalidate(examProvider),
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

/// The interactive exam player. Lives in its own [ConsumerStatefulWidget] so the
/// run state (answers, latency, current index, the result) survives provider
/// rebuilds — only an explicit "refaire" (which changes the exam id and thus the
/// [ValueKey]) resets it.
class _ExamRunner extends ConsumerStatefulWidget {
  const _ExamRunner({super.key, required this.exam});

  final MockExam exam;

  @override
  ConsumerState<_ExamRunner> createState() => _ExamRunnerState();
}

class _ExamRunnerState extends ConsumerState<_ExamRunner> {
  /// itemId -> chosen option id (single-select MCQ exam).
  final Map<String, String> _selected = <String, String>{};

  /// itemId -> accumulated milliseconds the learner spent on that item.
  final Map<String, int> _latencyMs = <String, int>{};

  late final DateTime _startedAt;
  late DateTime _itemShownAt;

  int _index = 0;
  bool _submitting = false;
  String? _error;
  MockExamResult? _result;

  /// Server-dedup key for the current submission. Held for as long as the
  /// outcome is unknown so a retry after a transport failure — where the
  /// server may already have counted the exam — resolves to the same
  /// operation instead of doubling the attempt (which would then twice
  /// feed the readiness score). Released once the server has ruled
  /// (success or permanent refusal).
  ///
  /// Deliberately **not** persisted across a process death, unlike the quiz
  /// and lesson equivalents. Those submit through `QuizService`, which dedupes
  /// on this key alone, so it has to outlive the app. `ExamService.SubmitAsync`
  /// additionally dedupes on the **`examId`** — `GetByExamIdAsync` returns the
  /// stored result for an already-submitted exam — and an `examId` is issued by
  /// the server, so no device-side value has to survive for the guarantee to
  /// hold. `ExamServiceTests.SubmitAsync_is_single_use_even_with_a_new_client_attempt_id`
  /// is the standing guard. Persisting this key would add a moving part that
  /// protects nothing.
  String? _pendingAttemptId;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _itemShownAt = _startedAt;
  }

  /// Fold the time spent on the current item into its running total and reset
  /// the stopwatch anchor. Called on every navigation and right before submit.
  void _recordCurrentLatency() {
    final MockExamItem current = widget.exam.items[_index];
    final int elapsed = DateTime.now().difference(_itemShownAt).inMilliseconds;
    _latencyMs[current.itemId] = (_latencyMs[current.itemId] ?? 0) + elapsed;
    _itemShownAt = DateTime.now();
  }

  void _select(String optionId) {
    if (_submitting) return;
    setState(() => _selected[widget.exam.items[_index].itemId] = optionId);
  }

  void _goTo(int newIndex) {
    _recordCurrentLatency();
    setState(() => _index = newIndex);
  }

  void _next() {
    if (_index < widget.exam.items.length - 1) {
      _goTo(_index + 1);
    }
  }

  void _prev() {
    if (_index > 0) {
      _goTo(_index - 1);
    }
  }

  Future<void> _submit() async {
    _recordCurrentLatency();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final MockExam exam = widget.exam;
    final String? selectedTrackId = ref.read(activeTrackProvider).asData?.value;
    final String trackId = exam.trackId.isNotEmpty
        ? exam.trackId
        : selectedTrackId ?? (throw const MissingActiveTrackException());

    final List<QuizAnswer> answers = <QuizAnswer>[
      for (final MockExamItem item in exam.items)
        QuizAnswer(
          itemId: item.itemId,
          type: item.type,
          selected: _selected[item.itemId] == null ? <String>[] : <String>[_selected[item.itemId]!],
          latencyMs: _latencyMs[item.itemId] ?? 0,
        ),
    ];

    final SubmitMockExamRequest request = SubmitMockExamRequest(
      clientAttemptId: _pendingAttemptId ??= _newAttemptId(),
      trackId: trackId,
      examId: exam.examId,
      startedAt: _startedAt,
      answers: answers,
    );

    final Result<MockExamResult> result =
        await ref.read(examRepositoryProvider).submitExam(request);
    if (!mounted) return;

    result.when(
      success: (MockExamResult value) => setState(() {
        _submitting = false;
        _result = value;
        // Final outcome — release the key so a fresh attempt gets a fresh one.
        _pendingAttemptId = null;
      }),
      failure: (Failure failure) => setState(() {
        _submitting = false;
        _error = failure.message;
        // Retryable failures leave the server outcome unknown, so we HOLD
        // the key; a permanent failure is a server ruling, so we release it.
        if (classifyFailure(failure) != SyncDispatch.retryable) {
          _pendingAttemptId = null;
        }
      }),
    );
  }

  static String _newAttemptId() {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    final int rand = Random().nextInt(0x7fffffff);
    return '${micros.toRadixString(16)}-${rand.toRadixString(16)}';
  }

  @override
  Widget build(BuildContext context) {
    final MockExamResult? result = _result;
    if (result != null) {
      return _ExamResultView(
        result: result,
        exam: widget.exam,
        onHome: () => context.go(Routes.home),
        onReplay: () => ref.invalidate(examProvider),
      );
    }

    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final MockExam exam = widget.exam;
    final MockExamItem item = exam.items[_index];
    final int total = exam.items.length;
    final double progress = ((_index + 1) / total).clamp(0.0, 1.0);
    final bool isLast = _index == total - 1;

    final Map<String, String> domainNames = <String, String>{
      for (final MockExamBlueprintDomain domain in exam.blueprint) domain.domainId: domain.name,
    };
    final String eyebrow = domainNames[item.domainId] ?? 'Question ${_index + 1}';

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.gutter,
            0,
            PrismSpacing.gutter,
            PrismSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: PrismProgressBar(
                  value: progress,
                  height: 8,
                  semanticLabel: 'Progression de l examen',
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_index + 1}/$total',
                style: PrismTypography.tabular(t.labelMedium?.copyWith(color: p.textSecondary)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              PrismSpacing.gutter,
              PrismSpacing.xs,
              PrismSpacing.gutter,
              PrismSpacing.lg,
            ),
            children: <Widget>[
              Text(
                eyebrow.toUpperCase(),
                style: t.labelMedium?.copyWith(
                  color: p.primary,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(item.stem, style: t.titleLarge?.copyWith(height: 1.4)),
              const SizedBox(height: 20),
              for (int i = 0; i < item.options.length; i++) ...<Widget>[
                QuizOptionTile(
                  label: item.options[i].label,
                  leading: String.fromCharCode(65 + i),
                  state: _selected[item.itemId] == item.options[i].id
                      ? QuizOptionState.selected
                      : QuizOptionState.idle,
                  onTap: _submitting ? null : () => _select(item.options[i].id),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                _InlineError(message: _error!),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.gutter,
            0,
            PrismSpacing.gutter,
            PrismSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              if (_index > 0) ...<Widget>[
                Expanded(
                  child: PrismButton(
                    label: 'Précédent',
                    variant: PrismButtonVariant.secondary,
                    icon: Icons.arrow_back_rounded,
                    onPressed: _submitting ? null : _prev,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: isLast
                    ? PrismButton(
                        label: 'Soumettre',
                        icon: Icons.flag_rounded,
                        loading: _submitting,
                        onPressed: _submitting ? null : _submit,
                      )
                    : PrismButton(
                        label: 'Suivant',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _submitting ? null : _next,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The graded result — rendered full-screen (below the header) once the server
/// responds. Surfaces the scaled score, pass/fail verdict, per-domain mastery,
/// the concepts to revisit, the earned rewards and a per-item review with the
/// authoritative explanations.
class _ExamResultView extends StatelessWidget {
  const _ExamResultView({
    required this.result,
    required this.exam,
    required this.onHome,
    required this.onReplay,
  });

  final MockExamResult result;
  final MockExam exam;
  final VoidCallback onHome;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool passed = result.passed;
    final Color accent = passed ? p.success : p.error;
    final QuizRewards rewards = result.rewards;

    final Map<String, String> stems = <String, String>{
      for (final MockExamItem item in exam.items) item.itemId: item.stem,
    };

    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: <Widget>[
        Center(
          child: ReadinessGauge(score: result.pct.clamp(0, 100), label: 'Score'),
        ),
        const SizedBox(height: 16),
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: accent,
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    passed ? Icons.verified_rounded : Icons.replay_circle_filled_rounded,
                    color: accent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      passed ? 'Réussi !' : 'Pas encore',
                      style: t.titleLarge?.copyWith(color: accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Score de ${result.scaledScore} — seuil de réussite ${result.passingScore}.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${result.correct}/${result.total} bonnes réponses (${result.pct}%).',
                style: t.bodyMedium?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            XpChip(xp: rewards.xpEarned),
            GemCounter(gems: rewards.gemsEarned),
            if (rewards.levelUp)
              _Pill(icon: Icons.trending_up_rounded, label: 'Niveau supérieur', color: p.primary),
            if (rewards.streakExtended)
              _Pill(
                icon: Icons.local_fire_department_rounded,
                label: 'Série prolongée',
                color: p.ember,
              ),
            if (rewards.achievementsUnlocked.isNotEmpty)
              _Pill(
                icon: Icons.emoji_events_rounded,
                label: '${rewards.achievementsUnlocked.length} succès',
                color: p.xpGold,
              ),
          ],
        ),
        if (result.domains.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Text('Par domaine', style: t.titleMedium),
          const SizedBox(height: 8),
          for (final ExamDomainScore domain in result.domains) _DomainScoreRow(score: domain),
        ],
        if (result.weakConcepts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Text('Concepts à revoir', style: t.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String concept in result.weakConcepts)
                _Pill(icon: Icons.menu_book_rounded, label: concept, color: p.warning),
            ],
          ),
        ],
        if (result.results.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Text('Revois tes réponses', style: t.titleMedium),
          const SizedBox(height: 12),
          for (final ItemResult item in result.results) ...<Widget>[
            _ItemReviewCard(result: item, stem: stems[item.itemId] ?? ''),
            const SizedBox(height: 12),
          ],
        ],
        const SizedBox(height: 12),
        PrismButton(label: 'Terminer', icon: Icons.check_rounded, onPressed: onHome),
        const SizedBox(height: 12),
        PrismButton(
          label: 'Refaire un examen',
          variant: PrismButtonVariant.secondary,
          icon: Icons.refresh_rounded,
          onPressed: onReplay,
        ),
      ],
    );
  }
}

class _DomainScoreRow extends StatelessWidget {
  const _DomainScoreRow({required this.score});

  final ExamDomainScore score;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final double ratio = (score.pct / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PrismSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  score.name,
                  style: t.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${score.pct}%',
                style: PrismTypography.tabular(t.labelLarge?.copyWith(color: p.primary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          PrismProgressBar(value: ratio, height: 8),
          const SizedBox(height: 4),
          Text(
            '${score.correct}/${score.total} bonnes réponses',
            style: t.bodySmall?.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ItemReviewCard extends StatelessWidget {
  const _ItemReviewCard({required this.result, required this.stem});

  final ItemResult result;
  final String stem;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool ok = result.correct;
    final Color accent = ok ? p.success : p.error;

    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(ok ? 'Correct' : 'Incorrect', style: t.titleSmall?.copyWith(color: accent)),
            ],
          ),
          if (stem.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(stem, style: t.bodyMedium?.copyWith(height: 1.4)),
          ],
          const SizedBox(height: 8),
          PrismRichText(result.explanation, style: t.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.sm, vertical: PrismSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: PrismRadii.pillAll,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: t.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _ExamEmpty extends StatelessWidget {
  const _ExamEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        PrismSpacing.gutter,
      ),
      child: PrismStatusView(
        icon: Icons.assignment_outlined,
        title: 'Examen indisponible',
        message: 'Aucune question disponible pour le moment.',
      ),
    );
  }
}

class _ExamLoading extends StatelessWidget {
  const _ExamLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: const <Widget>[
        PrismSkeleton(height: 10),
        SizedBox(height: 20),
        PrismSkeleton(height: 26, width: 220),
        SizedBox(height: 20),
        PrismSkeleton(height: 64),
        SizedBox(height: 12),
        PrismSkeleton(height: 64),
        SizedBox(height: 12),
        PrismSkeleton(height: 64),
        SizedBox(height: 12),
        PrismSkeleton(height: 64),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.sm,
        vertical: PrismSpacing.debt10,
      ),
      decoration: BoxDecoration(
        color: p.error.withOpacity(0.12),
        borderRadius: PrismRadii.cardMd,
        border: Border.all(color: p.error.withOpacity(0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: p.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: t.bodySmall?.copyWith(color: p.error)),
          ),
        ],
      ),
    );
  }
}
