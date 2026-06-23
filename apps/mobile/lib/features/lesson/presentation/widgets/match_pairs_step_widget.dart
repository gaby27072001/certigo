import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/answer_grading.dart';
import '../../application/check_outcome.dart';

/// Renders a `matchPairs` check: two columns the learner connects pair by pair
/// (concept on the left ↔ definition on the right). Pairs form a **set**, so
/// grading is order-insensitive.
///
/// Stateful because the half-formed selection (a tapped left awaiting its right,
/// or vice-versa) is transient UI state that must not pollute the controller —
/// only a *completed* pair is committed via [onToggleMatch], which toggles the
/// `"left:right"` token in the session selection.
class MatchPairsStepWidget extends StatefulWidget {
  const MatchPairsStepWidget({
    super.key,
    required this.item,
    required this.selection,
    required this.outcome,
    required this.onToggleMatch,
  });

  final QuizItem item;
  final List<String> selection;
  final CheckOutcome? outcome;
  final void Function(String leftId, String rightId) onToggleMatch;

  @override
  State<MatchPairsStepWidget> createState() => _MatchPairsStepWidgetState();
}

class _MatchPairsStepWidgetState extends State<MatchPairsStepWidget> {
  String? _pendingLeft;
  String? _pendingRight;

  bool get _graded => widget.outcome != null;

  String? _rightFor(String leftId) {
    for (final String token in widget.selection) {
      final List<String> parts = token.split(':');
      if (parts.length == 2 && parts[0] == leftId) return parts[1];
    }
    return null;
  }

  String? _leftFor(String rightId) {
    for (final String token in widget.selection) {
      final List<String> parts = token.split(':');
      if (parts.length == 2 && parts[1] == rightId) return parts[0];
    }
    return null;
  }

  void _clearPending() {
    _pendingLeft = null;
    _pendingRight = null;
  }

  void _tapLeft(String leftId) {
    if (_graded) return;
    final String? paired = _rightFor(leftId);
    if (paired != null) {
      widget.onToggleMatch(leftId, paired);
      setState(_clearPending);
      return;
    }
    if (_pendingRight != null) {
      final String right = _pendingRight!;
      widget.onToggleMatch(leftId, right);
      setState(_clearPending);
      return;
    }
    setState(() {
      _pendingLeft = _pendingLeft == leftId ? null : leftId;
      _pendingRight = null;
    });
  }

  void _tapRight(String rightId) {
    if (_graded) return;
    final String? paired = _leftFor(rightId);
    if (paired != null) {
      widget.onToggleMatch(paired, rightId);
      setState(_clearPending);
      return;
    }
    if (_pendingLeft != null) {
      final String left = _pendingLeft!;
      widget.onToggleMatch(left, rightId);
      setState(_clearPending);
      return;
    }
    setState(() {
      _pendingRight = _pendingRight == rightId ? null : rightId;
      _pendingLeft = null;
    });
  }

  QuizOptionState _leftState(String leftId, String? paired) {
    if (_graded) {
      if (paired == null) return QuizOptionState.idle;
      final bool ok = widget.outcome!.correctAnswer.contains(matchToken(leftId, paired));
      return ok ? QuizOptionState.correct : QuizOptionState.incorrect;
    }
    if (_pendingLeft == leftId) return QuizOptionState.selected;
    return QuizOptionState.idle;
  }

  QuizOptionState _rightState(String rightId, String? paired) {
    if (_graded) {
      if (paired == null) return QuizOptionState.idle;
      final bool ok = widget.outcome!.correctAnswer.contains(matchToken(paired, rightId));
      return ok ? QuizOptionState.correct : QuizOptionState.incorrect;
    }
    if (_pendingRight == rightId) return QuizOptionState.selected;
    return QuizOptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;

    // Stable pair numbering + hue from selection order, shared by both halves.
    final Map<String, int> numberByLeft = <String, int>{};
    final Map<String, int> numberByRight = <String, int>{};
    for (int i = 0; i < widget.selection.length; i++) {
      final List<String> parts = widget.selection[i].split(':');
      if (parts.length != 2) continue;
      numberByLeft[parts[0]] = i + 1;
      numberByRight[parts[1]] = i + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.swap_horiz_rounded, color: p.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Associe les paires',
              style: text.labelLarge?.copyWith(
                color: p.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Touche un concept puis sa correspondance.',
          style: text.bodySmall?.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 16),
        Text(widget.item.stem, style: text.titleMedium?.copyWith(height: 1.3)),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  for (final QuizOption o in widget.item.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MatchTile(
                        label: o.label,
                        state: _leftState(o.id, _rightFor(o.id)),
                        badge: numberByLeft[o.id],
                        badgeColor: numberByLeft[o.id] == null
                            ? null
                            : p.accentFor(numberByLeft[o.id]! - 1),
                        onTap: _graded ? null : () => _tapLeft(o.id),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: <Widget>[
                  for (final QuizOption o in widget.item.matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MatchTile(
                        label: o.label,
                        state: _rightState(o.id, _leftFor(o.id)),
                        badge: numberByRight[o.id],
                        badgeColor: numberByRight[o.id] == null
                            ? null
                            : p.accentFor(numberByRight[o.id]! - 1),
                        onTap: _graded ? null : () => _tapRight(o.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_graded) ...<Widget>[
          if (!widget.outcome!.correct) ...<Widget>[
            const SizedBox(height: 8),
            _CorrectPairs(item: widget.item, tokens: widget.outcome!.correctAnswer),
          ],
          const SizedBox(height: 16),
          AnswerFeedbackCard(
            correct: widget.outcome!.correct,
            explanation: widget.outcome!.explanation,
          ),
        ],
      ],
    );
  }
}

/// After a wrong answer, lists the expected concept → definition pairs so the
/// learner sees the correct mapping.
class _CorrectPairs extends StatelessWidget {
  const _CorrectPairs({required this.item, required this.tokens});

  final QuizItem item;
  final List<String> tokens;

  String _label(List<QuizOption> from, String id) {
    for (final QuizOption o in from) {
      if (o.id == id) return o.label;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'BONNES ASSOCIATIONS',
          style: text.labelSmall?.copyWith(
            color: p.success,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        for (final String token in tokens)
          if (token.split(':').length == 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.link_rounded, size: 16, color: p.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_label(item.options, token.split(':')[0])}'
                      ' → ${_label(item.matches, token.split(':')[1])}',
                      style: text.bodyMedium?.copyWith(color: p.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
