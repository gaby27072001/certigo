/// A minimal, dependency-free `Result` type for explicit success/failure flow.
///
/// We avoid throwing across architectural layers: repositories and services
/// return `Result<T>` so the UI can render loading / data / error states
/// deterministically. Pattern-match with [when].
import 'failures.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Err<T>;

  /// Value if success, else null.
  T? get valueOrNull => switch (this) {
    Success<T>(:final T value) => value,
    Err<T>() => null,
  };

  /// Exhaustive handling of both branches.
  R when<R>({required R Function(T value) success, required R Function(Failure failure) failure}) {
    return switch (this) {
      Success<T>(:final T value) => success(value),
      Err<T>(failure: final Failure f) => failure(f),
    };
  }

  /// Transform the success value, preserving failures.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(:final T value) => Success<R>(transform(value)),
      Err<T>(:final Failure failure) => Err<R>(failure),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
