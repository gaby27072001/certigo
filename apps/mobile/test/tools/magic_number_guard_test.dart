// Ratchet guard: fails when the number of hardcoded spacing/radius magic
// numbers under apps/mobile/lib/features rises above a fixed threshold.
//
// This is intentionally a *ratchet*, not a hard zero: the codebase still has
// many pre-existing magic numbers being migrated to Prism tokens screen by
// screen. New code must not add magic numbers (the count may only go down).
// When a migration PR removes some, lower [kThreshold] to the new count so
// the gain is locked in.
//
// The parallel onboarding/auth ("Luma") session's files are excluded (see
// kExcludedPaths in magic_number_scanner.dart) so this guard never blocks it.
//
// It runs automatically as part of `flutter test` (already wired into CI),
// so it needs no change under .github/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'magic_number_scanner.dart';

/// Current locked-in ceiling. Only ever lower this, never raise it.
const int kThreshold = 244;

/// Resolves the features root whether tests run from apps/mobile (CI) or the
/// repository root (local convenience).
String _resolveFeaturesRoot() {
  const List<String> candidates = <String>['lib/features', 'apps/mobile/lib/features'];
  for (final String c in candidates) {
    if (Directory(c).existsSync()) {
      return c;
    }
  }
  return candidates.first;
}

void main() {
  test('no new hardcoded spacing/radius magic numbers (ratchet)', () {
    final String root = _resolveFeaturesRoot();
    final List<Violation> violations = scanFeatureMagicNumbers(root);
    if (violations.length > kThreshold) {
      final StringBuffer msg = StringBuffer();
      msg.writeln('Hardcoded spacing/radius magic numbers increased.');
      msg.writeln('Found ${violations.length}, threshold is $kThreshold.');
      msg.writeln('Replace new EdgeInsets/BorderRadius/Radius literals with');
      msg.writeln('PrismSpacing / PrismRadii tokens (see packages/prism_ui).');
      msg.writeln('Sample of current violations:');
      final int sample = violations.length < 15 ? violations.length : 15;
      for (var i = 0; i < sample; i++) {
        msg.writeln('  ${violations[i]}');
      }
      fail(msg.toString());
    }
  });
}
