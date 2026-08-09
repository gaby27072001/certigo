import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/tutor_controller.dart';
import '../application/tutor_state.dart';

/// Opens the AI-tutor sheet for one answered item and kicks off the request.
///
/// The sheet talks to the continuously-learning tutor agent: it shows a grounded
/// explanation plus what the agent has learned about this learner on the concept
/// (recurring trap, comeback, accuracy trend), so feedback feels personal.
Future<void> showTutorSheet(
  BuildContext context, {
  required TutorExplainRequest request,
  required bool correct,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext _) => _TutorSheet(request: request, correct: correct),
  );
}

class _TutorSheet extends ConsumerStatefulWidget {
  const _TutorSheet({required this.request, required this.correct});

  final TutorExplainRequest request;
  final bool correct;

  @override
  ConsumerState<_TutorSheet> createState() => _TutorSheetState();
}

class _TutorSheetState extends ConsumerState<_TutorSheet> {
  @override
  void initState() {
    super.initState();
    // Fire the request after the first frame so we never touch a provider while
    // the widget tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  void _fetch() =>
      ref.read(tutorControllerProvider(widget.request.itemId).notifier).explain(widget.request);

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TutorState state = ref.watch(tutorControllerProvider(widget.request.itemId));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PrismRadii.debt26)),
          border: Border.all(color: p.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _Grip(),
              _Header(correct: widget.correct, explanation: state.explanation),
              Flexible(
                child: _TutorBody(state: state, correct: widget.correct, onRetry: _fetch),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: PrismSpacing.sm, bottom: PrismSpacing.debt6),
      decoration: BoxDecoration(
        color: p.border,
        borderRadius: BorderRadius.circular(PrismRadii.debt3),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.correct, required this.explanation});

  final bool correct;
  final TutorExplanation? explanation;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final Color tone = correct ? p.success : p.warning;
    final bool ai = explanation?.isAiGenerated ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.debt6,
        PrismSpacing.sm,
        PrismSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.16),
              borderRadius: BorderRadius.circular(PrismRadii.md),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: tone, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Tuteur IA', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  ai ? 'Explication personnalisée' : 'Explication vérifiée',
                  style: text.labelSmall?.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, color: p.textSecondary),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }
}

class _TutorBody extends StatelessWidget {
  const _TutorBody({required this.state, required this.correct, required this.onRetry});

  final TutorState state;
  final bool correct;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.hasError) {
      return _TutorError(message: state.errorMessage, onRetry: onRetry);
    }
    final TutorExplanation? exp = state.explanation;
    if (!state.hasExplanation || exp == null) {
      return const _TutorLoading();
    }
    return _TutorContent(explanation: exp, correct: correct);
  }
}

class _TutorLoading extends StatelessWidget {
  const _TutorLoading();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xxs,
        PrismSpacing.gutter,
        PrismSpacing.lg,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        Text(
          'Le tuteur analyse ta réponse…',
          style: text.bodyMedium?.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 18),
        const PrismSkeleton(width: 200, height: 22),
        const SizedBox(height: 16),
        const PrismSkeleton(height: 16),
        const SizedBox(height: 10),
        const PrismSkeleton(height: 16),
        const SizedBox(height: 10),
        const PrismSkeleton(width: 240, height: 16),
        const SizedBox(height: 22),
        const PrismSkeleton(height: 72),
      ],
    );
  }
}

class _TutorError extends StatelessWidget {
  const _TutorError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xxs,
        PrismSpacing.gutter,
        PrismSpacing.lg,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        CalloutBlock(
          kind: CalloutKind.warning,
          title: 'Tuteur indisponible',
          text: message ?? 'Réessaie dans un instant.',
        ),
        const SizedBox(height: 18),
        PrismButton.secondary(label: 'Réessayer', icon: Icons.refresh_rounded, onPressed: onRetry),
      ],
    );
  }
}

class _TutorContent extends StatelessWidget {
  const _TutorContent({required this.explanation, required this.correct});

  final TutorExplanation explanation;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final Color tone = correct ? p.success : p.warning;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xxs,
        PrismSpacing.gutter,
        PrismSpacing.debt28,
      ),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        Text(
          explanation.headline,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
        ),
        const SizedBox(height: 14),
        _PersonalizationStrip(personalization: explanation.personalization),
        const SizedBox(height: 18),
        for (final String point in explanation.points) ...<Widget>[
          _PointRow(text: point, tone: tone),
          const SizedBox(height: 10),
        ],
        if (explanation.recommendation.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          CalloutBlock(
            kind: CalloutKind.info,
            title: 'Ce que je te recommande',
            text: explanation.recommendation,
          ),
        ],
        if (explanation.encouragement.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Icon(Icons.favorite_rounded, color: p.ember, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  explanation.encouragement,
                  style: text.bodyMedium?.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        PrismButton(
          label: 'J\'ai compris',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

/// Surfaces what the agent has learned about this learner for the concept: how
/// many attempts, accuracy, and whether they're on a comeback or slipping.
class _PersonalizationStrip extends StatelessWidget {
  const _PersonalizationStrip({required this.personalization});

  final TutorPersonalization personalization;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TutorPersonalization tp = personalization;

    // First time seeing the concept: nothing learned yet, so stay quiet.
    if (tp.attempts <= 0) {
      return _Chip(icon: Icons.fiber_new_rounded, label: 'Nouveau concept pour toi', color: p.info);
    }

    final List<Widget> chips = <Widget>[
      _Chip(
        icon: Icons.percent_rounded,
        label: '${tp.accuracyPct}% de réussite',
        color: tp.accuracyPct >= 70 ? p.success : p.warning,
      ),
      _Chip(
        icon: Icons.repeat_rounded,
        label: '${tp.attempts} tentative(s)',
        color: p.textSecondary,
      ),
    ];

    if (tp.recurringStruggle) {
      chips.add(_Chip(icon: Icons.priority_high_rounded, label: 'Piège récurrent', color: p.error));
    }
    if (tp.isImproving) {
      chips.add(_Chip(icon: Icons.trending_up_rounded, label: 'Retour gagnant', color: p.success));
    } else if (tp.isSlipping) {
      chips.add(_Chip(icon: Icons.trending_down_rounded, label: 'À consolider', color: p.warning));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.debt11,
        vertical: PrismSpacing.debt6,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: PrismRadii.pillAll,
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: text.labelMedium?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: PrismSpacing.debt6),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: textTheme.bodyMedium?.copyWith(height: 1.4))),
      ],
    );
  }
}
