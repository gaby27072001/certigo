/// Pure retry-backoff policies for the offline sync engine.
///
/// Deterministic by default (no jitter) so retry timing is exactly testable.
/// The app can inject a jittered policy in production if desired.
library;

/// Computes the delay before retry number [attempt].
///
/// [attempt] is 1-based: the delay applied after the first failed attempt is
/// `policy(1)`, after the second `policy(2)`, and so on.
typedef BackoffPolicy = Duration Function(int attempt);

/// Exponential backoff: `base * factor^(attempt-1)`, capped at [max].
///
/// Defaults: 2 s base, ×2 growth, 5 min cap → 2s, 4s, 8s, 16s, 32s, …, 300s.
BackoffPolicy exponentialBackoff({
  Duration base = const Duration(seconds: 2),
  double factor = 2.0,
  Duration max = const Duration(minutes: 5),
}) {
  return (int attempt) {
    if (attempt < 1) return Duration.zero;
    final double millis = base.inMilliseconds * _intPow(factor, attempt - 1);
    final int capped = millis >= max.inMilliseconds ? max.inMilliseconds : millis.round();
    return Duration(milliseconds: capped);
  };
}

double _intPow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
