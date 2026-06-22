import 'package:core/core.dart';
import '../models/user_profile.dart';
import '../models/learning_path.dart';
import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/leaderboard.dart';
import '../models/tutor.dart';

/// Repository contracts consumed by the app's feature controllers.
///
/// Controllers depend on these abstractions (not on `ApiClient`), which keeps
/// features testable with fakes and lets us add caching/offline layers behind
/// the same interface later.

abstract interface class UserRepository {
  Future<Result<UserProfile>> getMe();
}

abstract interface class PathRepository {
  Future<Result<LearningPath>> getPath(String trackId);
}

abstract interface class LessonRepository {
  Future<Result<Lesson>> getLesson({required String trackId, required String lessonId});
}

abstract interface class QuizRepository {
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  });
}

abstract interface class LeaderboardRepository {
  Future<Result<League>> getMyLeague();
}

/// The continuously-learning AI tutor: explains one answered item, grounded in
/// the official lesson and personalised from the learner's running model.
abstract interface class TutorRepository {
  Future<Result<TutorExplanation>> explain(TutorExplainRequest request);
}
