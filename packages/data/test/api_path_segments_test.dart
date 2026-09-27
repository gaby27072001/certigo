import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Records every outbound request and answers `{}`: these tests only look at the
/// URI the backend would receive.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _OfflineQuiz implements QuizRepository {
  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) async =>
      const Err<SubmitQuizResult>(NetworkFailure());
}

const String _baseUrl = 'https://api.certigo.test/api';

ApiClient _client(_RecordingAdapter adapter) {
  final Dio dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(dio: dio, baseUrl: _baseUrl, tokenProvider: () async => null);
}

SubmitQuizRequest _request([String clientAttemptId = 'attempt-1']) => SubmitQuizRequest(
      clientAttemptId: clientAttemptId,
      trackId: 'az-900',
      startedAt: DateTime.utc(2026),
      answers: const <QuizAnswer>[],
      publicManifestId: 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

/// Every lesson id of the authored catalogue (`content/*/lessons/*.lesson.yaml`).
List<String> _realLessonIds() {
  Directory directory = Directory.current;
  while (!Directory('${directory.path}/content').existsSync() ||
      !File('${directory.path}/packages/data/pubspec.yaml').existsSync()) {
    final Directory parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('The repository content/ directory was not found.');
    }
    directory = parent;
  }
  final RegExp idLine = RegExp(r'''^id:\s*['"]?([^'"\s]+)''', multiLine: true);
  final List<String> ids = <String>[];
  for (final FileSystemEntity track in Directory('${directory.path}/content').listSync()) {
    final Directory lessons = Directory('${track.path}/lessons');
    if (!lessons.existsSync()) continue;
    for (final FileSystemEntity file in lessons.listSync()) {
      if (file is File && file.path.endsWith('.lesson.yaml')) {
        final Match? match = idLine.firstMatch(file.readAsStringSync());
        if (match != null) ids.add(match.group(1)!);
      }
    }
  }
  return ids..sort();
}

/// Account ids in the two formats the backend issues: `Guid.NewGuid().ToString("n")`
/// for e-mail accounts (`AuthService.cs`) and the Entra `oid` claim for CIAM
/// accounts (`EntraTokenValidator.cs`). Synthetic values, real formats.
const List<String> _realFormatAccountIds = <String>[
  '3f2b9c1e7d8a4b6c9e0f1a2b3c4d5e6f',
  '5b1d2c3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
];

/// Ids a crafted link could carry: each must stay ONE segment of its route.
const List<String> _hostileIds = <String>[
  '../me/account-deletion',
  'a/b',
  'lesson?admin=true',
  'lesson#fragment',
  'leçon avec espaces',
  '%2e%2e',
  '..%2Fme',
  r'..\me',
];

void main() {
  group('quiz submission path', () {
    test('every real lesson id reaches the backend route exactly as before', () async {
      final List<String> ids = _realLessonIds();
      expect(ids.length, greaterThan(100), reason: 'the catalogue should be read in full');
      expect(ids.where((String id) => Uri.encodeComponent(id) != id), isEmpty);

      final _RecordingAdapter adapter = _RecordingAdapter();
      final RemoteQuizRepository quiz = RemoteQuizRepository(_client(adapter));
      for (final String id in ids) {
        await quiz.submit(lessonId: id, request: _request());
      }

      expect(adapter.requests.map((RequestOptions r) => r.method).toSet(), <String>{'POST'});
      expect(
        adapter.requests.map((RequestOptions r) => r.uri.toString()).toList(),
        ids.map((String id) => '$_baseUrl/quiz/$id/submit').toList(),
      );
    });

    test('a hostile lesson id stays one segment of the quiz route', () async {
      for (final String id in _hostileIds) {
        final _RecordingAdapter adapter = _RecordingAdapter();
        await RemoteQuizRepository(_client(adapter)).submit(lessonId: id, request: _request());

        final Uri uri = adapter.requests.single.uri;
        expect(uri.host, 'api.certigo.test', reason: id);
        expect(uri.pathSegments, <String>['api', 'quiz', id, 'submit'], reason: id);
        expect(uri.hasQuery, isFalse, reason: id);
        expect(uri.hasFragment, isFalse, reason: id);
      }
    });

    test('a dot-segment lesson id is refused before any request', () async {
      for (final String id in <String>['.', '..']) {
        final _RecordingAdapter adapter = _RecordingAdapter();
        final Result<SubmitQuizResult> result =
            await RemoteQuizRepository(_client(adapter)).submit(lessonId: id, request: _request());

        expect(result, isA<Err<SubmitQuizResult>>(), reason: id);
        expect((result as Err<SubmitQuizResult>).failure, isA<ParseFailure>(), reason: id);
        expect(adapter.requests, isEmpty, reason: id);
      }
    });

    test('the offline queue replays exactly the path of the live request', () async {
      final List<String> ids = <String>[..._realLessonIds().take(5), ..._hostileIds];
      final SyncEngine engine = SyncEngine(
        store: InMemorySyncQueueStore(),
        sender: (SyncAction _) async => SyncDispatch.success,
        ownerIdProvider: () => 'owner',
      );
      final OfflineQuizRepository offline = OfflineQuizRepository(_OfflineQuiz(), engine);

      for (final (int index, String id) in ids.indexed) {
        final _RecordingAdapter live = _RecordingAdapter();
        await RemoteQuizRepository(_client(live)).submit(lessonId: id, request: _request());
        await offline.submit(lessonId: id, request: _request('attempt-$index'));
        final SyncAction queued = engine.actions.last;
        expect(queued.endpoint, live.requests.single.path, reason: id);

        final _RecordingAdapter replay = _RecordingAdapter();
        expect(await apiSyncSender(_client(replay))(queued), SyncDispatch.success, reason: id);
        expect(
          replay.requests.single.uri.pathSegments,
          <String>['api', 'quiz', id, 'submit'],
          reason: id,
        );
      }
      await engine.dispose();
    });
  });

  group('friend removal path', () {
    test('real-format account ids reach the backend route exactly as before', () async {
      final _RecordingAdapter adapter = _RecordingAdapter();
      final RemoteFriendRepository friends = RemoteFriendRepository(_client(adapter));
      for (final String id in _realFormatAccountIds) {
        await friends.removeFriend(id);
      }

      expect(adapter.requests.map((RequestOptions r) => r.method).toSet(), <String>{'DELETE'});
      expect(
        adapter.requests.map((RequestOptions r) => r.uri.toString()).toList(),
        _realFormatAccountIds.map((String id) => '$_baseUrl/friends/$id').toList(),
      );
    });

    test('a hostile account id stays one segment of the friend route', () async {
      for (final String id in _hostileIds) {
        final _RecordingAdapter adapter = _RecordingAdapter();
        await RemoteFriendRepository(_client(adapter)).removeFriend(id);

        final Uri uri = adapter.requests.single.uri;
        expect(uri.pathSegments, <String>['api', 'friends', id], reason: id);
        expect(uri.hasQuery, isFalse, reason: id);
        expect(uri.hasFragment, isFalse, reason: id);
      }
    });

    test('a dot-segment account id is refused before any request', () async {
      for (final String id in <String>['.', '..']) {
        final _RecordingAdapter adapter = _RecordingAdapter();
        final Result<FriendActionResult> result =
            await RemoteFriendRepository(_client(adapter)).removeFriend(id);

        expect((result as Err<FriendActionResult>).failure, isA<ParseFailure>(), reason: id);
        expect(adapter.requests, isEmpty, reason: id);
      }
    });
  });

  group('ApiClient dot-segment guard', () {
    Map<String, dynamic> echo(Map<String, dynamic> json) => json;

    test('refuses a dot segment, literal or percent-encoded, before any request', () async {
      const List<String> paths = <String>[
        '/me/../account-deletion',
        '/me/%2e%2E/account-deletion',
        '/me/.%2E/account-deletion',
        '/./me',
        '/me/.',
        '..',
      ];
      for (final String path in paths) {
        final _RecordingAdapter adapter = _RecordingAdapter();
        final ApiClient api = _client(adapter);
        final List<Result<Map<String, dynamic>>> results = <Result<Map<String, dynamic>>>[
          await api.getJson(path, echo),
          await api.postJson(path, const <String, dynamic>{}, echo),
          await api.deleteJson(path, echo),
        ];

        for (final Result<Map<String, dynamic>> result in results) {
          expect((result as Err<Map<String, dynamic>>).failure, isA<ParseFailure>(), reason: path);
        }
        expect(adapter.requests, isEmpty, reason: path);
      }
    });

    test('keeps dots inside a segment and in the query string', () async {
      const List<String> paths = <String>[
        '/content/releases/r/files/h/lesson.json',
        '/me/paths/az.900',
        '/me/items?next=../elsewhere',
      ];
      final _RecordingAdapter adapter = _RecordingAdapter();
      final ApiClient api = _client(adapter);
      for (final String path in paths) {
        expect((await api.getJson(path, echo)).isSuccess, isTrue, reason: path);
      }
      expect(adapter.requests.map((RequestOptions r) => r.path).toList(), paths);
    });
  });
}
