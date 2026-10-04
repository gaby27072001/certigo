// Fixture: the integration test root is excluded from the production-only rules.
import 'dart:math';

// ok: dart-insecure-random
final int seed = Random().nextInt(1 << 31);
