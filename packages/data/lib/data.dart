/// Data — Microlingo's models, API client and repositories.
///
/// Hand-written JSON models (no codegen), a configured Dio [ApiClient] and the
/// repository contracts + remote implementations that the app depends on.
library data;

export 'src/models/user_profile.dart';
export 'src/models/learning_path.dart';
export 'src/models/track_summary.dart';
export 'src/models/lesson.dart';
export 'src/models/quiz.dart';
export 'src/models/leaderboard.dart';
export 'src/models/tutor.dart';
export 'src/models/recommendation.dart';

export 'src/api/api_client.dart';

export 'src/repositories/repositories.dart';
export 'src/repositories/remote_repositories.dart';

export 'src/sync/sync_action.dart';
export 'src/sync/backoff.dart';
export 'src/sync/sync_dispatcher.dart';
export 'src/sync/sync_queue_store.dart';
export 'src/sync/sync_engine.dart';
export 'src/sync/offline_quiz_repository.dart';
export 'src/sync/api_sync_sender.dart';
