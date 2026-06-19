/// Core — cross-cutting primitives shared by every Microlingo package:
/// `Result`/`Failure` error flow and compile-time environment config.
///
/// Pure Dart, no Flutter dependency, so it is trivially unit-testable and can
/// be consumed by the `cortex` and `data` packages as well as the app.
library core;

export 'src/result.dart';
export 'src/failures.dart';
export 'src/app_env.dart';
