// Fixture: production code inside a lib/**/test/ directory is still production code.
// The test-path exclusions are anchored on the package test roots only.
import 'dart:math';

// ruleid: dart-insecure-random
final int id = Random().nextInt(1 << 31);
