/// Data — Microlingo's models, API client and repositories.
///
/// Hand-written JSON models (no codegen), a configured Dio [ApiClient] and the
/// repository contracts + remote implementations that the app depends on.
library data;

export 'src/models/user_profile.dart';
export 'src/models/learning_path.dart';
export 'src/models/lesson.dart';
export 'src/models/quiz.dart';
export 'src/models/leaderboard.dart';

export 'src/api/api_client.dart';

export 'src/repositories/repositories.dart';
export 'src/repositories/remote_repositories.dart';
