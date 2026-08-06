// Golden test harness configuration for `prism_ui`.
//
// Flutter auto-discovers this file and wraps every test in the package. Its
// sole job here is to install a *tolerant* golden comparator so the renderer
// golden suite (see `test/rendering/renderer_golden_test.dart`) stays robust
// across engine/toolchain revisions: sub-pixel anti-aliasing and icon
// rasterisation differ slightly between the local SDK and the CI Flutter, and a
// byte-exact comparator would flag those as false regressions. A small
// percentage threshold still fails hard on real, structural visual changes,
// which is exactly what the `ci-mobile` golden gate must catch.
//
// This file imports only `flutter_test` + core Dart libraries. For non-golden
// tests the swapped comparator is inert (they never call `matchesGoldenFile`).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

/// Maximum tolerated fraction of differing pixels (1.0 == 100%).
///
/// Baselines are captured on one toolchain and replayed on the pinned CI
/// Flutter/Linux image, so sub-pixel anti-aliasing and font/icon rasterisation
/// drift by a small, thinly-spread amount (measured 0.5%-2.1% across the block
/// suite). 3% absorbs that cross-toolchain jitter with headroom while staying
/// far below the large, contiguous diffs a real layout, colour or content
/// regression produces, so the golden gate still fails hard on genuine visual
/// changes.
const double _kGoldenDiffTolerance = 0.03;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final GoldenFileComparator previous = goldenFileComparator;
  if (previous is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(previous.basedir);
  }
  await testMain();
}

/// A [LocalFileComparator] that passes when the pixel diff stays under
/// [_kGoldenDiffTolerance], and otherwise fails exactly like the default
/// comparator (writing the usual failure artefacts for triage).
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(Uri basedir)
      : super(Uri.parse('$basedir/flutter_test_config.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed || result.diffPercent <= _kGoldenDiffTolerance) {
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}
