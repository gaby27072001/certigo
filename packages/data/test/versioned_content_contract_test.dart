import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const String _manifestId =
    'sha256:e5663734ac88ac916cff3b6e1206dc03bacf7f6d530e8b115e3f198a1e6304ee';

class _LessonAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(<String, dynamic>{
      'id': 'lesson-1',
      'trackId': 'track-1',
      'unitId': 'unit-1',
      'domainId': 'domain-1',
      'title': 'Lesson',
      'estMinutes': 5,
      'blocks': <dynamic>[],
    }),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      'x-content-manifest-id': <String>[_manifestId],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('remote lesson preserves the server content snapshot header', () async {
    final Dio dio = Dio()..httpClientAdapter = _LessonAdapter();
    final RemoteLessonRepository repository = RemoteLessonRepository(
      ApiClient(dio: dio, baseUrl: 'https://example.test', tokenProvider: () async => null),
    );

    final Result<Lesson> result = await repository.getLesson(
      trackId: 'track-1',
      lessonId: 'lesson-1',
    );

    result.valueOrNull!.publicManifestId.shouldEqual(_manifestId);
    Lesson.fromJson(result.valueOrNull!.toJson()).publicManifestId.shouldEqual(_manifestId);
  });

  test('quiz, tutor and exam generation emit the pinned public manifest', () {
    final SubmitQuizRequest quiz = SubmitQuizRequest(
      clientAttemptId: 'attempt-1',
      trackId: 'track-1',
      startedAt: DateTime.utc(2026, 8, 19),
      answers: const <QuizAnswer>[],
      publicManifestId: _manifestId,
    );
    const TutorExplainRequest tutor = TutorExplainRequest(
      trackId: 'track-1',
      lessonId: 'lesson-1',
      itemId: 'item-1',
      selected: <String>['a'],
      publicManifestId: _manifestId,
    );
    const MockExamRequest exam = MockExamRequest(trackId: 'track-1', publicManifestId: _manifestId);

    expect(quiz.toJson()['publicManifestId'], _manifestId);
    expect(tutor.toJson()['publicManifestId'], _manifestId);
    expect(exam.toJson()['publicManifestId'], _manifestId);
  });
}

extension on Object? {
  void shouldEqual(Object? expected) => expect(this, expected);
}
