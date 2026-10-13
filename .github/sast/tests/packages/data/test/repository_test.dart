// Fixture: package test roots are excluded from the production-only rules.
import 'dart:math';

// ok: dart-insecure-random
final int seed = Random().nextInt(1 << 31);
