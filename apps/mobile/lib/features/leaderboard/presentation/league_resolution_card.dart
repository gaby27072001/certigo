import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../../../shared/errors/error_copy.dart';

final leagueResolutionRepositoryProvider = Provider<LeagueResolutionRepository>(
  (Ref ref) => RemoteLeaderboardRepository(ref.watch(apiClientProvider)),
);

final leagueResolutionProvider =
    FutureProvider.autoDispose.family<LeagueResolution, String>((Ref ref, String period) async {
  ref.watch(activeTrackOwnerIdProvider);
  final Result<LeagueResolution> result =
      await ref.watch(leagueResolutionRepositoryProvider).previewResolution();
  final LeagueResolution resolution =
      result.when(success: (value) => value, failure: (failure) => throw failure);
  if (resolution.periodLeagueId != period) {
    throw const LeaguePeriodChanged();
  }
  return resolution;
});

class LeaguePeriodChanged implements Exception {
  const LeaguePeriodChanged();
}

class LeagueResolutionCard extends ConsumerStatefulWidget {
  const LeagueResolutionCard({super.key, required this.league});

  final League league;

  @override
  ConsumerState<LeagueResolutionCard> createState() => _LeagueResolutionCardState();
}

class _LeagueResolutionCardState extends ConsumerState<LeagueResolutionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final League league = widget.league;
    final AsyncValue<LeagueResolution>? state =
        _expanded ? ref.watch(leagueResolutionProvider(league.periodLeagueId)) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          label: Text(_expanded ? 'Masquer la projection' : 'Voir la projection de fin de semaine'),
          style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
        ),
        if (state != null)
          PrismCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Projection, pas une récompense acquise',
                    style: Theme.of(context).textTheme.titleMedium),
                const Text(
                  'Aperçu calculé par le serveur. Le classement peut encore changer ; '
                  'aucune gemme n’est attribuée ici.',
                ),
                if (state.isLoading) const LinearProgressIndicator(),
                if (state.hasError) ...<Widget>[
                  Text(state.error is LeaguePeriodChanged
                      ? 'La semaine a changé. Actualise la ligue pour voir la nouvelle projection.'
                      : state.error is NotFoundFailure
                          ? 'Projection indisponible sur ce serveur. Consulte le classement '
                              'ci-dessous et réessaie plus tard.'
                          : 'Projection indisponible. ${describeFailure(state.error).message}'),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(leagueProvider);
                      ref.invalidate(leagueResolutionProvider(league.periodLeagueId));
                    },
                    child: const Text('Actualiser la projection'),
                  ),
                ],
                if (state.hasValue && state.error is! LeaguePeriodChanged)
                  _Outcome(resolution: state.requireValue, userId: league.meUserId),
              ],
            ),
          ),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.resolution, required this.userId});

  final LeagueResolution resolution;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final List<LeagueOutcome> mine =
        resolution.outcomes.where((LeagueOutcome outcome) => outcome.userId == userId).toList();
    if (mine.isEmpty) {
      return const Text('Pas encore de projection personnelle. Termine une leçon puis actualise.');
    }
    final LeagueOutcome outcome = mine.single;
    final String movement = switch (outcome.movement) {
      LeagueMovement.promoted => 'Montée prévue',
      LeagueMovement.held => 'Maintien prévu',
      LeagueMovement.relegated => 'Descente prévue',
    };
    return Text(
      '$movement : ${outcome.fromTier} → ${outcome.toTier}\n'
      'Rang projeté : ${outcome.rank} · ${outcome.gemReward} gemmes potentielles',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}
