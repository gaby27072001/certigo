/// The grade assigned to a single recall attempt, FSRS-style.
///
/// Mirrors the backend `ReviewGrade` exactly so client-side optimistic
/// scheduling and server-authoritative scheduling never diverge.
enum ReviewGrade {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const ReviewGrade(this.value);
  final int value;
}

/// Derive a grade from correctness + answer latency.
///
/// Fast & correct ⇒ `easy`; slow & correct ⇒ `hard`; wrong ⇒ `again`. This
/// keeps grading objective (no self-rating) which suits a certification app.
ReviewGrade gradeFromAnswer({required bool correct, required int latencyMs}) {
  if (!correct) return ReviewGrade.again;
  if (latencyMs < 4000) return ReviewGrade.easy;
  if (latencyMs < 9000) return ReviewGrade.good;
  return ReviewGrade.hard;
}
