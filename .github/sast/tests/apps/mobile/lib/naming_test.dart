// Fixture: a production file merely named *_test.dart is still production code.
import 'dart:math';

// ruleid: dart-insecure-random
final int id = Random().nextInt(1 << 31);
