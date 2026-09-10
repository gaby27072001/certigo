import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/prism_layout.dart';

/// Centers a full-height screen body and caps its readable width on large
/// screens.
///
/// [maxWidth] defaults to [PrismLayout.reading] rather than a bare literal:
/// this is the primitive that keeps a screen body from stretching across a
/// wide window, which is already the everyday case on iPad, in landscape and
/// in Split View.
class PrismContentFrame extends StatelessWidget {
  const PrismContentFrame({
    super.key,
    required this.child,
    this.maxWidth = PrismLayout.reading,
    this.alignment = Alignment.topCenter,
    this.expandHeight = true,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;
  final bool expandHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Align(
          alignment: alignment,
          heightFactor: expandHeight ? null : 1,
          child: SizedBox(width: math.min(maxWidth, constraints.maxWidth), child: child),
        );
      },
    );
  }
}
