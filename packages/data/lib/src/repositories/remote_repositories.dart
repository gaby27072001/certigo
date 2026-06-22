import 'package:core/core.dart';
import '../api/api_client.dart';
import '../models/user_profile.dart';
import '../models/learning_path.dart';
import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/leaderboard.dart';
import '../models/tutor.dart';
import 'repositories.dart';

/// HTTP-backed implementations of the repository contracts. Each method maps a
/// single REST endpoint to a typed model via [ApiClient]. Routes mirror the
/// backend exactly (userId is always derived from the JWT, never sent).

class RemoteUserRepository implements UserRepository {
  const RemoteUserRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<UserProfile>> getMe() => _api.getJson('/me', UserProfile.fromJson);
}

class RemotePathRepository implements PathRepository {
  const RemotePathRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<LearningPath>> getPath(String trackId) =>
      _api.getJson('/me/paths/$trackId', LearningPath.fromJson);
}

class RemoteLessonRepository implements LessonRepository {
  const RemoteLessonRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<Lesson>> getLesson({
    required String trackId,
    required String lessonId,
  }) =>
      _api.getJson('/tracks/$trackId/lessons/$lessonId', Lesson.fromJson);
}

class RemoteQuizRepository implements QuizRepository {
  const RemoteQuizRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) =>
      _api.postJson(
        '/quiz/$lessonId/submit',
        request.toJson(),
        SubmitQuizResult.fromJson,
      );
}

class RemoteLeaderboardRepository implements LeaderboardRepository {
  const RemoteLeaderboardRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<League>> getMyLeague() => _api.getJson('/me/league', League.fromJson);
}

class RemoteTutorRepository implements TutorRepository {
  const RemoteTutorRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<TutorExplanation>> explain(TutorExplainRequest request) =>
      _api.postJson('/tutor/explain', request.toJson(), TutorExplanation.fromJson);
}
