/// Identifies a lesson to play.
///
/// Used as the family key for [lessonControllerProvider], so it implements value
/// equality — otherwise Riverpod would build a fresh controller on every widget
/// rebuild and the session would reset mid-lesson.
class LessonArgs {
  const LessonArgs({required this.trackId, required this.lessonId});

  final String trackId;
  final String lessonId;

  @override
  bool operator ==(Object other) =>
      other is LessonArgs && other.trackId == trackId && other.lessonId == lessonId;

  @override
  int get hashCode => Object.hash(trackId, lessonId);

  @override
  String toString() => 'LessonArgs($trackId/$lessonId)';
}
