import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Centers a full-height screen body and caps its readable width on large screens.
class PrismContentFrame extends StatelessWidget {
  const PrismContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 760,
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
