import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:data/data.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';

/// Quiz player — one item at a time, comprehension-first. After the learner
/// locks an answer we reveal correctness AND the explanation (real learning,
/// not just a score). At the end we show server-style rewards.
///
/// Skeleton note: grading is done locally against an in-file answer key. In P1
/// this is replaced by `lessonRepositoryProvider.submitQuiz(...)`, which posts a
/// [SubmitQuizRequest] and renders the authoritative [SubmitQuizResult].
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.trackId, required this.lessonId});

  final String trackId;
  final String lessonId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  late final List<_GradedItem> _items = _sampleItems();

  int _index = 0;
  String? _selectedId;
  bool _graded = false;
  int _correctCount = 0;

  _GradedItem get _current => _items[_index];
  bool get _isLast => _index == _items.length - 1;

  void _select(String optionId) {
    if (_graded) return;
    setState(() => _selectedId = optionId);
  }

  void _grade() {
    if (_selectedId == null || _graded) return;
    setState(() {
      _graded = true;
      final bool ok = _selectedId == _current.correctOptionId;
      _current.lastAnswerCorrect = ok;
      if (ok) _correctCount++;
    });
  }

  void _next() {
    if (_isLast) {
      _showResults();
      return;
    }
    setState(() {
      _index++;
      _selectedId = null;
      _graded = false;
    });
  }

  void _showResults() {
    final int scorePct = ((_correctCount / _items.length) * 100).round();
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultsSheet(
        scorePct: scorePct,
        correct: _correctCount,
        total: _items.length,
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

  QuizOptionState _stateFor(String optionId) {
    if (!_graded) {
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
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final QuizItem item = _current.item;

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
                  Text('${_index + 1}/${_items.length}',
                      style: t.labelMedium?.copyWith(color: p.textSecondary)),
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
                      onPressed: _next,
                    )
                  : PrismButton(
                      label: 'Valider',
                      onPressed: _selectedId == null ? null : _grade,
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
  final _GradedItem item;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
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
          PrismRichText(item.explanation, style: t.bodyLarge?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _ResultsSheet extends ConsumerStatefulWidget {
  const _ResultsSheet({
    required this.scorePct,
    required this.correct,
    required this.total,
    required this.trackId,
    required this.lessonId,
    required this.onDone,
    required this.onNextLesson,
  });

  final int scorePct;
  final int correct;
  final int total;
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
    if (widget.scorePct >= 60) _confetti.play();
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
    final bool strong = widget.scorePct >= 80;
    final int xp = 20 + widget.correct * 10;

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
                strong ? 'Excellent !' : 'Bonne progression',
                style: t.headlineMedium,
              ),
              Text(
                '${widget.correct} / ${widget.total} correct · ${widget.scorePct}%',
                style: t.bodyLarge?.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  XpChip(xp: xp),
                  const SizedBox(width: 12),
                  const StreakBadge(days: 7),
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
                PrismButton.secondary(
                  label: 'Terminer',
                  onPressed: widget.onDone,
                ),
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

/// Pairs a public [QuizItem] with the answer key + explanation that the server
/// would normally own. Lets the skeleton give real feedback offline.
class _GradedItem {
  _GradedItem({
    required this.item,
    required this.correctOptionId,
    required this.explanation,
  });

  final QuizItem item;
  final String correctOptionId;
  final String explanation;

  bool lastAnswerCorrect = false;
}

List<_GradedItem> _sampleItems() => <_GradedItem>[
      _GradedItem(
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
      _GradedItem(
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
      _GradedItem(
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
