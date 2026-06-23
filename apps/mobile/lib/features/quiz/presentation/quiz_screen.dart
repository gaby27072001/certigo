import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:data/data.dart';

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
        onDone: () {
          Navigator.of(context).pop();
          context.go(Routes.home);
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

class _ResultsSheet extends StatelessWidget {
  const _ResultsSheet({
    required this.scorePct,
    required this.correct,
    required this.total,
    required this.onDone,
  });

  final int scorePct;
  final int correct;
  final int total;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool strong = scorePct >= 80;
    // Skeleton rewards mirror QuizRewards; server returns the real values.
    final int xp = 20 + correct * 10;

    return Container(
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
          Icon(strong ? Icons.celebration_rounded : Icons.trending_up_rounded,
              color: strong ? p.xpGold : p.primary, size: 56),
          const SizedBox(height: 12),
          Text(strong ? 'Excellent !' : 'Bonne progression', style: t.headlineMedium),
          Text('$correct / $total correct · $scorePct%',
              style: t.bodyLarge?.copyWith(color: p.textSecondary)),
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
          PrismButton(label: 'Terminer', onPressed: onDone),
        ],
      ),
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
