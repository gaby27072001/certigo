// Fixture: a lib/src/test/ directory inside a package is production code too.
import 'dart:math';

// ruleid: dart-insecure-random
final int id = Random().nextInt(1 << 31);
