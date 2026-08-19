import 'package:core/core.dart';
import '../models/user_profile.dart';
import '../models/learning_path.dart';
import '../models/track_summary.dart';
import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/leaderboard.dart';
import '../models/tutor.dart';
import '../models/recommendation.dart';
import '../models/season.dart';
import '../models/quest.dart';
import '../models/achievement.dart';
import '../models/shop.dart';
import '../models/friend.dart';
import '../models/exam.dart';
import '../models/share_card.dart';
import '../models/account_deletion.dart';

/// Repository contracts consumed by the app's feature controllers.
///
/// Controllers depend on these abstractions (not on `ApiClient`), which keeps
/// features testable with fakes and lets us add caching/offline layers behind
/// the same interface later.

abstract interface class UserRepository {
  Future<Result<UserProfile>> getMe();

  Future<Result<UserProfile>> setActiveTrack({
    required String trackId,
    required String? expectedTrackId,
  });
}

abstract interface class AccountDeletionRepository {
  Future<Result<AccountDeletion>> getStatus();
  Future<Result<AccountDeletion>> requestDeletion({
    String? reauthenticationToken,
  });
}

abstract interface class PathRepository {
  Future<Result<LearningPath>> getPath(String trackId);
}

/// The catalog of certification tracks the app offers, for the course picker.
abstract interface class CatalogRepository {
  Future<Result<List<TrackSummary>>> getCatalog();
}

abstract interface class LessonRepository {
  Future<Result<Lesson>> getLesson({
    required String trackId,
    required String lessonId,
  });
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

/// The "next best action" coach: a server-ranked list of what the learner
/// should do next on a track (forgetting risk + struggles + path frontier).
abstract interface class RecommendationRepository {
  Future<Result<NextBest>> getNextBest(String trackId);
}

/// The live monthly season + its claimable community challenge.
abstract interface class SeasonRepository {
  Future<Result<Season>> getSeason();
  Future<Result<ClaimSeasonResult>> claimSeason(ClaimSeasonRequest request);
}

/// The learner's daily quest board + per-quest gem claims.
abstract interface class QuestRepository {
  Future<Result<QuestBoard>> getQuests();
  Future<Result<ClaimQuestResult>> claimQuest(ClaimQuestRequest request);
}

/// The learner's achievements board. Read-only: unlocks are server-side.
abstract interface class AchievementRepository {
  Future<Result<AchievementBoard>> getAchievements();
}

/// The gem shop: catalog + idempotent purchases.
abstract interface class ShopRepository {
  Future<Result<ShopCatalog>> getShop();
  Future<Result<PurchaseResult>> purchase(PurchaseRequest request);
}

/// The social graph: friends list, add/remove, and a friends-only leaderboard.
abstract interface class FriendRepository {
  Future<Result<FriendList>> getFriends();
  Future<Result<FriendActionResult>> addFriend(AddFriendRequest request);
  Future<Result<FriendActionResult>> removeFriend(String friendId);
  Future<Result<FriendLeaderboard>> getFriendLeaderboard();
}

/// The learner's daily share card, generated server-side from authoritative
/// progress, streak and referral data.
abstract interface class ShareCardRepository {
  Future<Result<ShareCard>> getDailyShareCard();
}

/// The adaptive mock exam: generate a blueprint-weighted exam, then submit it
/// for authoritative server grading.
abstract interface class ExamRepository {
  Future<Result<MockExam>> generateExam(MockExamRequest request);
  Future<Result<MockExamResult>> submitExam(SubmitMockExamRequest request);
}
