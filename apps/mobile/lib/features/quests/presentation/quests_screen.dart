import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/inline_error.dart';
import '../../../shared/widgets/screen_header.dart';

/// Daily quests — a small board of bite-size goals that refresh each day. Fed by
/// `questBoardProvider`. Each completed quest can be claimed individually; we
/// track the in-flight quest id so only its button spins, and on success we
/// invalidate the board to pull the authoritative gem balance and claim state.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<QuestBoard> async = ref.watch(questBoardProvider);

    return AuroraBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const ScreenHeader(title: 'Quêtes du jour'),
            Expanded(
              child: async.when(
                data: (QuestBoard board) => _QuestsContent(board: board),
                loading: () => const _QuestsLoading(),
                error: (Object error, StackTrace _) => PrismStatusView.error(
                  onRetry: () => ref.invalidate(questBoardProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestsContent extends ConsumerStatefulWidget {
  const _QuestsContent({required this.board});

  final QuestBoard board;

  @override
  ConsumerState<_QuestsContent> createState() => _QuestsContentState();
}

class _QuestsContentState extends ConsumerState<_QuestsContent> {
  String? _claimingId;
  String? _error;

  Future<void> _claim(Quest quest) async {
    setState(() {
      _claimingId = quest.id;
      _error = null;
    });
    final Result<ClaimQuestResult> result = await ref.read(questRepositoryProvider).claimQuest(
          ClaimQuestRequest(questId: quest.id),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (ClaimQuestResult r) {
        setState(() {
          _claimingId = null;
          _error = r.success ? null : (r.error ?? 'La quête n\'a pas pu être réclamée.');
        });
        if (r.success) {
          ref.invalidate(questBoardProvider);
        }
      },
      failure: (Failure f) {
        setState(() {
          _claimingId = null;
          _error = f.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final QuestBoard board = widget.board;

    if (board.quests.isEmpty) {
      return const PrismStatusView(
        icon: Icons.checklist_rounded,
        title: 'Aucune quête aujourd\'hui',
        message: 'Reviens demain pour de nouveaux objectifs.',
      );
    }

    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: <Widget>[
        PrismCard(
          variant: PrismCardVariant.tonal,
          accent: p.primary,
          child: Row(
            children: <Widget>[
              Icon(Icons.calendar_today_rounded, color: p.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Objectifs du jour', style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Complète-les pour gagner des gemmes.',
                      style: t.bodySmall?.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              GemCounter(gems: board.gems),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 14),
          InlineError(message: _error!),
        ],
        const SizedBox(height: 16),
        for (final Quest quest in board.quests) ...<Widget>[
          _QuestCard(
            quest: quest,
            claiming: _claimingId == quest.id,
            claimEnabled: quest.claimable && _claimingId == null,
            onClaim: () => _claim(quest),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.claiming,
    required this.claimEnabled,
    required this.onClaim,
  });

  final Quest quest;
  final bool claiming;
  final bool claimEnabled;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final double progress = quest.target > 0
        ? (quest.current / quest.target).clamp(0.0, 1.0)
        : (quest.completed ? 1.0 : 0.0);
    final Color accent = quest.claimed ? p.success : p.primary;

    return PrismCard(
      variant: quest.claimed ? PrismCardVariant.tonal : PrismCardVariant.surface,
      accent: quest.claimed ? p.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                quest.claimed ? Icons.check_circle_rounded : Icons.bolt_rounded,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  quest.title,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.diamond_rounded, size: 15, color: p.info),
                  const SizedBox(width: 4),
                  Text(
                    '+${quest.rewardGems}',
                    style: t.labelMedium?.copyWith(
                      color: p.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PrismProgressBar(
                  value: progress,
                  gradient: quest.claimed ? <Color>[p.success, p.success] : null,
                  semanticLabel: 'Progression de la quête',
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${quest.current}/${quest.target}',
                style: t.labelMedium?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          if (quest.claimable || claiming) ...<Widget>[
            const SizedBox(height: 14),
            PrismButton(
              label: 'Réclamer',
              icon: Icons.card_giftcard_rounded,
              loading: claiming,
              onPressed: claimEnabled ? onClaim : null,
            ),
          ] else if (quest.claimed) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Récompense obtenue',
              style: t.labelMedium?.copyWith(color: p.success, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestsLoading extends StatelessWidget {
  const _QuestsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      children: const <Widget>[
        PrismSkeleton(height: 78),
        SizedBox(height: 16),
        PrismSkeleton(height: 132),
        SizedBox(height: 12),
        PrismSkeleton(height: 132),
        SizedBox(height: 12),
        PrismSkeleton(height: 132),
      ],
    );
  }
}
