import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

Map<String, dynamic> _league() => <String, dynamic>{
      'periodLeagueId': '2026-W39:obsidian',
      'tier': 'obsidian',
      'endsAt': '2026-09-28T00:00:00Z',
      'promoteCount': 0,
      'meUserId': 'me',
      'entries': <dynamic>[
        <String, dynamic>{
          'userId': 'me',
          'displayName': 'Moi',
          'rank': 3,
          'weeklyXp': 700,
          'zone': 'safe',
        },
      ],
      'tierIndex': 10,
      'tierName': 'Obsidienne',
      'relegateCount': 2,
      'nextTier': null,
      'previousTier': 'Diamant',
      'myRank': 3,
      'myWeeklyXp': 700,
      'myZone': 'safe',
      'resetsInSeconds': 3600,
    };

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.status = 200});
  final Object body;
  final int status;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('all server ladder ids are understood, with no invented canonical tier', () {
    final File source = File.fromUri(
      Directory.current.uri.resolve('../../backend/src/Certigo.Domain/Gamification/Leagues.cs'),
    );
    final List<String> server = RegExp(r'new LeagueTier\(\d+, "([^"]+)"')
        .allMatches(source.readAsStringSync())
        .map((Match m) => m.group(1)!)
        .toList();
    final List<String> mobile = LeagueTier.values
        .where((LeagueTier tier) => tier != LeagueTier.unknown && tier != LeagueTier.platinum)
        .map((LeagueTier tier) => tier.name)
        .toList();
    expect(server, isNotEmpty);
    expect(mobile, server);
    for (final String id in server) {
      expect(leagueTierFrom(id).name, id);
    }
  });

  test('reads all enriched values without recomputing ranking or movement', () {
    final League league = League.fromJson(_league());
    expect(league.tier, LeagueTier.obsidian);
    expect(league.tierName, 'Obsidienne');
    expect(league.tierIndex, 10);
    expect(league.promoteCount, 0);
    expect(league.relegateCount, 2);
    expect(league.nextTier, isNull);
    expect(league.previousTier, 'Diamant');
    expect(league.myRank, 3);
    expect(league.myWeeklyXp, 700);
    expect(league.myZone, LeagueZone.safe);
    expect(league.resetsInSeconds, 3600);
    expect(league.entries.single.rank, 3);
    expect(league.entries.single.zone, LeagueZone.safe);
  });

  test('old responses omit enrichment without invented rank, tier or zone', () {
    final Map<String, dynamic> json = _league()
      ..removeWhere((String key, dynamic _) => <String>{
            'tierIndex',
            'tierName',
            'relegateCount',
            'nextTier',
            'previousTier',
            'myRank',
            'myWeeklyXp',
            'myZone',
            'resetsInSeconds',
          }.contains(key));
    (json['entries'] as List<dynamic>).single.remove('zone');
    final League league = League.fromJson(json);
    expect(league.myRank, isNull);
    expect(league.myWeeklyXp, isNull);
    expect(league.tierName, isNull);
    expect(league.myZone, isNull);
    expect(league.entries.single.zone, isNull);
  });

  test('legacy platinum and future tiers never turn into Bronze', () {
    expect(League.fromJson(_league()..['tier'] = 'platinum').tier, LeagueTier.platinum);
    expect(League.fromJson(_league()..['tier'] = 'cosmic').tier, LeagueTier.unknown);
    expect(leagueTierFrom(null), LeagueTier.unknown);
  });

  test('resolution repository reads the server outcome and correct GET route', () async {
    final _Adapter adapter = _Adapter(<String, dynamic>{
      'periodLeagueId': 'w1',
      'tier': 'silver',
      'outcomes': <dynamic>[
        <String, dynamic>{
          'userId': 'me',
          'displayName': 'Moi',
          'rank': 7,
          'zone': 'relegation',
          'movement': 'relegated',
          'fromTier': 'Argent',
          'toTier': 'Bronze',
          'gemReward': 0,
        },
      ],
    });
    final RemoteLeaderboardRepository repository = RemoteLeaderboardRepository(
      ApiClient(dio: Dio()..httpClientAdapter = adapter, tokenProvider: () async => 'token'),
    );
    final Result<LeagueResolution> result = await repository.previewResolution();
    expect(adapter.request?.method, 'GET');
    expect(adapter.request?.path, '/me/league/resolution');
    expect(result.valueOrNull?.outcomes.single.movement, LeagueMovement.relegated);
    expect(result.valueOrNull?.outcomes.single.gemReward, 0);
    expect(result.valueOrNull?.outcomes.single.rank, 7);
  });

  test('old backend missing resolution stays an explicit failure', () async {
    final _Adapter adapter = _Adapter(<String, dynamic>{}, status: 404);
    final RemoteLeaderboardRepository repository = RemoteLeaderboardRepository(
      ApiClient(dio: Dio()..httpClientAdapter = adapter, tokenProvider: () async => 'token'),
    );
    final Result<LeagueResolution> result = await repository.previewResolution();
    expect(result, isA<Err<LeagueResolution>>());
  });
}
