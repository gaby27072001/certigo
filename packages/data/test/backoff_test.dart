import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('exponentialBackoff', () {
    test('produces the expected doubling sequence capped at 5 minutes', () {
      final BackoffPolicy policy = exponentialBackoff();

      expect(policy(1), const Duration(seconds: 2));
      expect(policy(2), const Duration(seconds: 4));
      expect(policy(3), const Duration(seconds: 8));
      expect(policy(4), const Duration(seconds: 16));
      expect(policy(5), const Duration(seconds: 32));
      expect(policy(6), const Duration(seconds: 64));
      expect(policy(7), const Duration(seconds: 128));
      expect(policy(8), const Duration(seconds: 256));
      // 2 * 2^8 = 512s > 300s cap.
      expect(policy(9), const Duration(minutes: 5));
      expect(policy(20), const Duration(minutes: 5));
    });

    test('attempt below 1 yields zero', () {
      final BackoffPolicy policy = exponentialBackoff();
      expect(policy(0), Duration.zero);
      expect(policy(-3), Duration.zero);
    });

    test('honours custom base, factor and cap', () {
      final BackoffPolicy policy = exponentialBackoff(
        base: const Duration(seconds: 1),
        factor: 3.0,
        max: const Duration(seconds: 20),
      );
      expect(policy(1), const Duration(seconds: 1));
      expect(policy(2), const Duration(seconds: 3));
      expect(policy(3), const Duration(seconds: 9));
      // 27s > 20s cap.
      expect(policy(4), const Duration(seconds: 20));
    });
  });
}
