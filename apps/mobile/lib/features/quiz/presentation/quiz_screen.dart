import 'dart:async';

import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../app/content/runtime_content_providers.dart';
import '../../../app/router.dart';
import '../application/quiz_controller.dart';
import '../application/quiz_entry.dart';
import 'widgets/feedback_card.dart';
import 'widgets/results_sheet.dart';

/// Quiz player — one item at a time. Questions are loaded from the lesson API,
/// answers are submitted at the end, and rewards come from server grading.
///
/// Genuine cached lessons continue to work offline. Bundled sample content is
/// entered only through the explicit, non-synchronizable demo action.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.trackId, required this.lessonId});

  final String trackId;
  final String lessonId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  late final QuizController _controller;

  @override
  void initState() {
    super.initState();
    _controller = QuizController(
      lessons: ref.read(lessonRepositoryProvider),
      quiz: ref.read(quizRepositoryProvider),
      contentPins: ref.read(runtimeContentPinRegistryProvider),
      contentOwnerId: ref.read(activeTrackOwnerIdProvider),
      feedback: ref.read(lessonFeedbackProvider),
      resumeStore: ref.read(sessionResumeStoreProvider),
      resumeOwnerId: ref.read(activeTrackOwnerIdProvider),
      trackId: widget.trackId,
      lessonId: widget.lessonId,
    )..addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _next() async {
    if (_controller.isLast) {
      final QuizSubmission? submission = await _controller.submit();
      if (submission == null || !mounted) return;
      _showResultsSheet(submission);
      return;
    }
    _controller.next();
  }

  void _showResultsSheet(QuizSubmission submission) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ResultsSheet(
        result: submission.result,
        totalQuestions: submission.totalQuestions,
        pendingSync: submission.pendingSync,
        isDemo: submission.isDemo,
        submissionFailed: submission.submissionFailed,
        trackId: widget.trackId,
        lessonId: widget.lessonId,
        onDone: () {
          Navigator.of(context).pop();
          context.go(Routes.home);
        },
        onNextLesson: (String nextId) {
          Navigator.of(context).pop();
          context.go(
            '${Routes.lesson}/${Uri.encodeComponent(widget.trackId)}/${Uri.encodeComponent(nextId)}',
          );
        },
      ),
    );
  }

  QuizOptionState _stateFor(String optionId) {
    if (!_controller.graded) {
      return optionId == _controller.selectedId ? QuizOptionState.selected : QuizOptionState.idle;
    }
    final QuizEntry entry = _controller.current;
    if (!entry.hasLocalCorrection) {
      return optionId == _controller.selectedId ? QuizOptionState.selected : QuizOptionState.idle;
    }
    final bool isCorrect = optionId == entry.correctOptionId;
    final bool isPicked = optionId == _controller.selectedId;
    if (isCorrect && isPicked) return QuizOptionState.correct;
    if (isCorrect && !isPicked) return QuizOptionState.missed;
    if (!isCorrect && isPicked) return QuizOptionState.incorrect;
    return QuizOptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) {
      return const AuroraBackground(
        child: SafeArea(child: PrismLoadingView(label: 'Préparation du quiz…')),
      );
    }
    if (_controller.loadFailed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PrismStatusView.error(
                message:
                    'Réessaie quand la connexion revient, ou lance une démo sans synchronisation.',
                onRetry: () => unawaited(_controller.loadItems()),
              ),
              PrismButton.ghost(label: 'Essayer la démo', onPressed: _controller.startDemo),
            ],
          ),
        ),
      );
    }
    if (_controller.items.isEmpty) {
      return const AuroraBackground(
        child: SafeArea(
          child: PrismStatusView.empty(
            icon: Icons.quiz_outlined,
            title: 'Aucune question disponible',
            message: 'Cette leçon ne contient pas encore de quiz.',
          ),
        ),
      );
    }

    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final QuizEntry entry = _controller.current;
    final QuizItem item = entry.item;

    return AuroraBackground(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Progress dots --------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PrismSpacing.xs,
                PrismSpacing.xxs,
                PrismSpacing.gutter,
                PrismSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.go(Routes.path),
                  ),
                  Expanded(
                    child: PrismProgressBar(
                      value: (_controller.index + (_controller.graded ? 1 : 0)) /
                          _controller.items.length,
                      height: 8,
                      semanticLabel: 'Progression du quiz',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_controller.index + 1}/${_controller.items.length}',
                    style: t.labelMedium?.copyWith(color: p.textSecondary),
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
                  if (_controller.isDemo) ...<Widget>[
                    const CalloutBlock(
                      kind: CalloutKind.info,
                      title: 'Mode démo',
                      text:
                          'Cette session ne sera pas synchronisée et ne rapporte aucune récompense.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(item.stem, style: t.titleLarge?.copyWith(height: 1.4)),
                  const SizedBox(height: 20),
                  for (int i = 0; i < item.options.length; i++) ...<Widget>[
                    QuizOptionTile(
                      label: item.options[i].label,
                      leading: String.fromCharCode(65 + i), // A, B, C, D
                      state: _stateFor(item.options[i].id),
                      onTap: () => _controller.select(item.options[i].id),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_controller.graded) ...<Widget>[
                    const SizedBox(height: 8),
                    FeedbackCard(item: _controller.current),
                  ],
                ],
              ),
            ),
            // Action bar -----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PrismSpacing.gutter,
                0,
                PrismSpacing.gutter,
                PrismSpacing.md,
              ),
              child: _controller.graded
                  ? PrismButton(
                      label: _controller.isLast ? 'Voir mon résultat' : 'Continuer',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _controller.submitting ? null : () => unawaited(_next()),
                    )
                  : PrismButton(
                      label: 'Valider',
                      onPressed: _controller.selectedId == null || _controller.submitting
                          ? null
                          : _controller.grade,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
