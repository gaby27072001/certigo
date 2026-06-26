import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:data/data.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';

/// Quiz player — one item at a time. Questions are loaded from the lesson API,
/// answers are submitted at the end, and rewards come from server grading.
///
/// If the API is unavailable, the screen falls back to a local sample quiz so
/// the learning flow still works offline.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.trackId, required this.lessonId});

  final String trackId;
  final String lessonId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<_QuizEntry> _items = <_QuizEntry>[];
  bool _loading = true;
  bool _submitting = false;

  int _index = 0;
  String? _selectedId;
  bool _graded = false;
  int _correctCount = 0;
  final DateTime _startedAt = DateTime.now().toUtc();
  DateTime _shownAt = DateTime.now();
  final Map<String, List<String>> _answersByItem = <String, List<String>>{};
  final Map<String, int> _latencyByItem = <String, int>{};

  _QuizEntry get _current => _items[_index];
  bool get _isLast => _index == _items.length - 1;

  @override
  void initState() {
    super.initState();
    unawaited(_loadItems());
  }

  Future<void> _loadItems() async {
    final LessonRepository lessons = ref.read(lessonRepositoryProvider);
    final Result<Lesson> lesson = await lessons.getLesson(
      trackId: widget.trackId,
      lessonId: widget.lessonId,
    );

    final List<_QuizEntry> entries = lesson.when(
      success: (Lesson l) {
        final List<_QuizEntry> fromApi = l.blocks
            .where((LessonBlock b) => b.check != null)
            .map((LessonBlock b) => _QuizEntry(item: b.check!))
            .toList(growable: false);
        if (fromApi.isNotEmpty) return fromApi;
        return _sampleItems();
      },
      failure: (Failure _) => _sampleItems(),
    );

    if (!mounted) return;
    setState(() {
      _items = entries;
      _loading = false;
      _shownAt = DateTime.now();
    });
  }

  void _select(String optionId) {
    if (_graded) return;
    setState(() => _selectedId = optionId);
  }

  void _grade() {
    if (_selectedId == null || _graded) return;
    setState(() {
      _graded = true;
      final String pickedId = _selectedId!;
      _answersByItem[_current.item.id] = <String>[pickedId];
      _latencyByItem[_current.item.id] = DateTime.now().difference(_shownAt).inMilliseconds;
      if (_current.hasLocalCorrection) {
        final bool ok = pickedId == _current.correctOptionId;
        _current.lastAnswerCorrect = ok;
        if (ok) _correctCount++;
      }
    });
  }

  Future<void> _next() async {
    if (_isLast) {
      await _showResults();
      return;
    }
    setState(() {
      _index++;
      _selectedId = null;
      _graded = false;
      _shownAt = DateTime.now();
    });
  }

  Future<void> _showResults() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final QuizRepository quiz = ref.read(quizRepositoryProvider);
    final String clientAttemptId = DateTime.now().microsecondsSinceEpoch.toString();
    final List<QuizAnswer> answers = _items
        .map(
          (_QuizEntry entry) => QuizAnswer(
            itemId: entry.item.id,
            type: entry.item.type,
            selected: _answersByItem[entry.item.id] ?? const <String>[],
            latencyMs: _latencyByItem[entry.item.id] ?? 0,
          ),
        )
        .toList(growable: false);

    final Result<SubmitQuizResult> submission = await quiz.submit(
      lessonId: widget.lessonId,
      request: SubmitQuizRequest(
        clientAttemptId: clientAttemptId,
        trackId: widget.trackId,
        startedAt: _startedAt,
        answers: answers,
      ),
    );

    final bool hasLocalKey = _items.any((_QuizEntry entry) => entry.hasLocalCorrection);
    final bool pendingSync = submission.isFailure && !hasLocalKey;
    final SubmitQuizResult result = submission.valueOrNull ??
        _localFallbackResult(
          clientAttemptId: clientAttemptId,
          total: _items.length,
          hasLocalCorrection: hasLocalKey,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultsSheet(
        result: result,
        totalQuestions: _items.length,
        pendingSync: pendingSync,
        trackId: widget.trackId,
        lessonId: widget.lessonId,
        onDone: () {
          Navigator.of(context).pop();
          context.go(Routes.home);
        },
        onNextLesson: (String nextId) {
          Navigator.of(context).pop();
          context.go('${Routes.lesson}/${widget.trackId}/$nextId');
        },
      ),
    );
  }

  SubmitQuizResult _localFallbackResult({
    required String clientAttemptId,
    required int total,
    required bool hasLocalCorrection,
  }) {
    final int scorePct =
        hasLocalCorrection ? (total == 0 ? 0 : ((_correctCount / total) * 100).round()) : 0;
    final int xp = hasLocalCorrection ? (20 + _correctCount * 10) : 0;
    return SubmitQuizResult(
      attemptId: 'local-$clientAttemptId',
      scorePct: scorePct,
      results: const <ItemResult>[],
      rewards: QuizRewards(
        xpEarned: xp,
        newXp: 1240 + xp,
        levelUp: false,
        streakExtended: false,
        gemsEarned: 0,
        achievementsUnlocked: const <String>[],
      ),
      weakConcepts: const <String>[],
    );
  }

  QuizOptionState _stateFor(String optionId) {
    if (!_graded) {
      return optionId == _selectedId ? QuizOptionState.selected : QuizOptionState.idle;
    }
    if (!_current.hasLocalCorrection) {
      return optionId == _selectedId ? QuizOptionState.selected : QuizOptionState.idle;
    }
    final bool isCorrect = optionId == _current.correctOptionId;
    final bool isPicked = optionId == _selectedId;
    if (isCorrect && isPicked) return QuizOptionState.correct;
    if (isCorrect && !isPicked) return QuizOptionState.missed;
    if (!isCorrect && isPicked) return QuizOptionState.incorrect;
    return QuizOptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_items.isEmpty) {
      return Scaffold(
        body: Center(
          child: PrismCard(
            child: Text(
              'Aucune question disponible pour cette leçon.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final _QuizEntry entry = _current;
    final QuizItem item = entry.item;

    return AuroraBackground(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Progress dots --------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.go(Routes.path),
                  ),
                  Expanded(
                    child: PrismProgressBar(
                      value: (_index + (_graded ? 1 : 0)) / _items.length,
                      height: 8,
                      semanticLabel: 'Progression du quiz',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_index + 1}/${_items.length}',
                    style: t.labelMedium?.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: <Widget>[
                  Text(item.stem, style: t.titleLarge?.copyWith(height: 1.4)),
                  const SizedBox(height: 20),
                  for (int i = 0; i < item.options.length; i++) ...<Widget>[
                    QuizOptionTile(
                      label: item.options[i].label,
                      leading: String.fromCharCode(65 + i), // A, B, C, D
                      state: _stateFor(item.options[i].id),
                      onTap: () => _select(item.options[i].id),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_graded) ...<Widget>[
                    const SizedBox(height: 8),
                    _FeedbackCard(item: _current),
                  ],
                ],
              ),
            ),
            // Action bar -----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _graded
                  ? PrismButton(
                      label: _isLast ? 'Voir mon résultat' : 'Continuer',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _submitting ? null : () => unawaited(_next()),
                    )
                  : PrismButton(
                      label: 'Valider',
                      onPressed: _selectedId == null || _submitting ? null : _grade,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item});
  final _QuizEntry item;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    if (!item.hasLocalCorrection) {
      return PrismCard(
        variant: PrismCardVariant.tonal,
        accent: p.primary,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.info_outline_rounded, color: p.primary),
                const SizedBox(width: 8),
                Text('Réponse enregistrée', style: t.titleMedium?.copyWith(color: p.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Le corrigé détaillé sera affiché après la soumission.',
              style: t.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      );
    }
    final bool ok = item.lastAnswerCorrect;
    final Color accent = ok ? p.success : p.error;
    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: accent,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(ok ? Icons.check_circle_rounded : Icons.school_rounded, color: accent),
              const SizedBox(width: 8),
              Text(ok ? 'Bien vu' : 'À clarifier', style: t.titleMedium?.copyWith(color: accent)),
            ],
          ),
          const SizedBox(height: 8),
          PrismRichText(item.explanation!, style: t.bodyLarge?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _ResultsSheet extends ConsumerStatefulWidget {
  const _ResultsSheet({
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
  ConsumerState<_ResultsSheet> createState() => _ResultsSheetState();
}

class _ResultsSheetState extends ConsumerState<_ResultsSheet> {
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
    final String? nextLessonId =
        pathLoaded ? _findNextLessonId(pathAsync.requireValue, widget.lessonId) : null;

    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: p.border),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
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

// --- Sample graded items (replaced by server grading in P1) ----------------

/// Pairs a public [QuizItem] with optional local answer-key metadata used only
/// in offline fallback mode.
class _QuizEntry {
  _QuizEntry({required this.item, this.correctOptionId, this.explanation});

  final QuizItem item;
  final String? correctOptionId;
  final String? explanation;

  bool get hasLocalCorrection => correctOptionId != null && explanation != null;
  bool lastAnswerCorrect = false;
}

List<_QuizEntry> _sampleItems() => <_QuizEntry>[
      _QuizEntry(
        item: const QuizItem(
          id: 'q-capex-1',
          conceptId: 'c-capex-opex',
          type: ItemType.mcq,
          stem: 'Une équipe paie ses serveurs Azure uniquement selon la '
              'consommation mensuelle, sans achat initial. De quel modèle de '
              'coût s\'agit-il ?',
          options: <QuizOption>[
            QuizOption(id: 'a', label: 'Capex — dépense d\'investissement'),
            QuizOption(id: 'b', label: 'Opex — dépense de fonctionnement'),
            QuizOption(id: 'c', label: 'Amortissement sur 5 ans'),
            QuizOption(id: 'd', label: 'Licence perpétuelle'),
          ],
        ),
        correctOptionId: 'b',
        explanation: 'Payer à l\'usage, sans investissement initial, est la '
            'définition de l\'Opex. Le cloud transforme l\'achat d\'actifs '
            '(Capex) en charges variables (Opex).',
      ),
      _QuizEntry(
        item: const QuizItem(
          id: 'q-capex-2',
          conceptId: 'c-capex-opex',
          type: ItemType.scenario,
          stem: 'Quel est l\'avantage principal de l\'Opex pour une startup '
              'dont la charge varie fortement ?',
          options: <QuizOption>[
            QuizOption(id: 'a', label: 'Elle possède physiquement ses serveurs'),
            QuizOption(id: 'b', label: 'Ses coûts sont fixes quoi qu\'il arrive'),
            QuizOption(id: 'c', label: 'La facture suit la demande, à la hausse comme à la baisse'),
            QuizOption(id: 'd', label: 'Elle évite toute facturation cloud'),
          ],
        ),
        correctOptionId: 'c',
        explanation: 'L\'élasticité des coûts est clé : en Opex, la dépense '
            'monte quand la demande monte et redescend quand elle baisse — '
            'idéal pour une charge imprévisible.',
      ),
      _QuizEntry(
        item: const QuizItem(
          id: 'q-capex-3',
          conceptId: 'c-capex-opex',
          type: ItemType.mcq,
          stem: 'Acheter 50 000 € de serveurs pour son propre datacenter '
              'correspond à…',
          options: <QuizOption>[
            QuizOption(id: 'a', label: 'Du Capex'),
            QuizOption(id: 'b', label: 'De l\'Opex'),
            QuizOption(id: 'c', label: 'Du serverless'),
            QuizOption(id: 'd', label: 'Du pay-as-you-go'),
          ],
        ),
        correctOptionId: 'a',
        explanation: 'Un gros achat d\'actifs en amont, amorti dans le temps, '
            'est l\'archétype du Capex — l\'opposé du modèle cloud à la demande.',
      ),
    ];
