// Locked ratchet guard: fails when the number of hardcoded spacing/radius
// magic numbers under apps/mobile/lib/features rises above the locked floor.
//
// Levier 1 (screen-by-screen tokenisation, Lots A-E) is complete: every
// migratable EdgeInsets/BorderRadius/Radius literal we own has been replaced
// with a Prism token. [kThreshold] is now LOCKED at the exact remaining floor
// and may only ever go DOWN if the last leftovers are removed, never up.
//
// This is a hard, blocking assertion (expect + lessThanOrEqualTo): any new
// magic number pushes the count above the locked floor and fails
// `flutter test` (and CI). That is the permanent anti-regression ratchet -
// no one can reintroduce hardcoded spacing/radius magic numbers.
//
// Grandfathered floor (count = 2): home/presentation/coach_section.dart:247,
// EdgeInsets.symmetric(... 10, 5). The 5 is off-grid (no token exists), so the
// pair is left as-is and locked in rather than inventing a new token.
//
// The parallel onboarding/auth ("Luma") session's files are excluded (see
// kExcludedPaths in magic_number_scanner.dart) so this guard never blocks it.
//
// It runs automatically as part of `flutter test` (already wired into CI),
// so it needs no change under .github/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'magic_number_scanner.dart';

/// Locked-in floor at completion of Levier 1. Only ever lower this (never
/// raise it): the guard is a permanent ratchet pinned at the current minimum.
const int kThreshold = 2;

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
  test('no new hardcoded spacing/radius magic numbers (locked ratchet)', () {
    final String root = _resolveFeaturesRoot();
    final List<Violation> violations = scanFeatureMagicNumbers(root);

    final StringBuffer msg = StringBuffer();
    msg.writeln('Hardcoded spacing/radius magic numbers exceeded the locked floor.');
    msg.writeln('Found ${violations.length}, locked threshold is $kThreshold.');
    msg.writeln('The threshold is pinned at the floor and may only go DOWN.');
    msg.writeln('Replace new EdgeInsets/BorderRadius/Radius literals with');
    msg.writeln('PrismSpacing / PrismRadii tokens (see packages/prism_ui).');
    msg.writeln('Sample of current violations:');
    final int sample = violations.length < 15 ? violations.length : 15;
    for (var i = 0; i < sample; i++) {
      msg.writeln('  ${violations[i]}');
    }

    // Hard, blocking ratchet: the moment the count rises above the locked
    // floor this fails the suite (and CI). No soft skip/warn escape hatch.
    expect(violations.length, lessThanOrEqualTo(kThreshold), reason: msg.toString());
  });
}
