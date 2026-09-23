import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const Map<String, dynamic> settingsJson = <String, dynamic>{
  'enabled': false,
  'utcOffsetMinutes': 345,
  'quietHoursStart': 21,
  'quietHoursEnd': 6,
  'preferredHour': 18,
  'maxPerDay': 2,
  'streakAlerts': false,
  'questAlerts': true,
  'leagueAlerts': false,
};

Map<String, dynamic> planJson() => <String, dynamic>{
      'localDate': '2026-09-23',
      'notifications': <dynamic>[
        <String, dynamic>{
          'kind': 'futureKind',
          'priority': 'High',
          'scheduledUtc': '2026-09-23T18:00:00+02:00',
          'localHour': 18,
          'mascot': 'nova',
          'title': 'Title',
          'body': 'Body',
          'deeplink': 'certigo://home',
          'dedupeKey': 'key',
        },
      ],
    };

class _Adapter implements HttpClientAdapter {
  Object body = settingsJson;
  int status = 200;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late RemoteNotificationRepository repository;
  setUp(() {
    adapter = _Adapter();
    repository = RemoteNotificationRepository(ApiClient(
      dio: Dio()..httpClientAdapter = adapter,
      tokenProvider: () async => 'test-token',
      baseUrl: 'https://example.test',
    ));
  });

  test('GET settings preserves all nine values including false and offset minutes', () async {
    expect((await repository.getSettings()).valueOrNull?.toJson(), settingsJson);
    expect(adapter.request?.path, '/me/notifications/settings');
    expect(adapter.request?.method, 'GET');
    expect(adapter.request?.queryParameters, isEmpty);
  });
  test('POST replaces all fields without a user id and returns server canonical values', () async {
    final NotificationSettings request =
        NotificationSettings.fromJson(settingsJson).copyWith(enabled: true);
    final Result<NotificationSettings> result = await repository.updateSettings(request);
    expect(adapter.request?.data, request.toJson());
    expect((adapter.request?.data as Map<String, dynamic>).length, 9);
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.path, '/me/notifications/settings');
    expect(result.valueOrNull?.enabled, isFalse);
  });
  for (final String key in settingsJson.keys) {
    test('missing $key fails instead of inventing a replacement default', () async {
      adapter.body = Map<String, dynamic>.from(settingsJson)..remove(key);
      expect(
          await repository.getSettings(),
          isA<Err<NotificationSettings>>()
              .having((Err<NotificationSettings> e) => e.failure, 'failure', isA<ParseFailure>()));
    });
  }
  test('invalid normalized range fails', () async {
    adapter.body = <String, dynamic>{...settingsJson, 'maxPerDay': 11};
    expect((await repository.getSettings()).isFailure, isTrue);
  });
  test('GET plan preserves date-only and parses timezone as UTC, tolerates unknown kind', () async {
    adapter.body = planJson();
    final NotificationPlan plan = (await repository.getPlan()).valueOrNull!;
    expect(adapter.request?.path, '/me/notifications/plan');
    expect(plan.localDate, '2026-09-23');
    expect(plan.notifications.single.scheduledUtc, DateTime.utc(2026, 9, 23, 16));
    expect(plan.notifications.single.kind, 'futureKind');
    expect(() => plan.notifications.clear(), throwsUnsupportedError);
  });
  test('missing plan list is not an empty plan', () async {
    adapter.body = <String, dynamic>{'localDate': '2026-09-23'};
    expect((await repository.getPlan()).isFailure, isTrue);
  });
  test('invalid calendar date is rejected', () async {
    adapter.body = <String, dynamic>{...planJson(), 'localDate': '2026-02-30'};
    expect((await repository.getPlan()).isFailure, isTrue);
  });
  for (final int status in <int>[401, 404, 503]) {
    test('$status remains an explicit module failure', () async {
      adapter.status = status;
      expect((await repository.getSettings()).isFailure, isTrue);
      expect((await repository.getPlan()).isFailure, isTrue);
    });
  }
}
