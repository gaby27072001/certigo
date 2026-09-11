import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';

/// Fades a scrollable's trailing edge while content remains beyond it.
///
/// A scroll view that simply ends at a hard border does not read as "there is
/// more below" — it reads as a rendering fault, especially when a sticky action
/// bar slices the last row flat. The cheapest honest signal is the one Apple
/// Music uses: let the content dissolve at the edge it continues past.
///
/// The signal is **conditional**, which is the whole point. It shows only while
/// [ScrollMetrics.extentAfter] is non-zero, so a short list is never dimmed for
/// no reason, and reaching the end clears it — confirming the end. A gradient
/// that is always on claims there is more even when there is not.
///
/// ```dart
/// PrismScrollEdge(child: ListView(children: rows))
/// ```
///
/// The scrim paints [color] — the surface behind the list, by default the
/// theme background — rather than masking the child to transparent. That keeps
/// the child's position in the widget tree fixed. An earlier version swapped a
/// `ShaderMask` in and out around the scrollable; re-parenting it **reset its
/// scroll offset to zero mid-scroll**, measured at `offset=0.0` after a fling
/// that should have ended at 900.
class PrismScrollEdge extends StatefulWidget {
  const PrismScrollEdge({
    super.key,
    required this.child,
    this.extent = 32,
    this.color,
    this.leading = false,
  });

  final Widget child;

  /// Height of the faded band, in logical pixels.
  final double extent;

  /// Colour the scrim fades from. Defaults to the theme background.
  final Color? color;

  /// Also fade the leading edge once the view has scrolled away from it.
  final bool leading;

  @override
  State<PrismScrollEdge> createState() => _PrismScrollEdgeState();
}

class _PrismScrollEdgeState extends State<PrismScrollEdge> {
  bool _more = false;
  bool _before = false;

  bool _apply(ScrollMetrics m) {
    if (!m.hasContentDimensions) {
      return false;
    }
    final bool more = m.extentAfter > 0.5;
    final bool before = widget.leading && m.extentBefore > 0.5;
    if (more != _more || before != _before) {
      // Metrics arrive during layout, so defer rather than setState mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _more = more;
          _before = before;
        });
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Color scrim = widget.color ?? context.prism.background;
    final Duration duration = PrismMotion.resolve(context, PrismMotion.fast);

    return Stack(
      children: <Widget>[
        // Always at the same position in the tree: the scrollable is never
        // re-parented, so its offset survives every state change here.
        Positioned.fill(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (ScrollMetricsNotification n) => _apply(n.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification n) => _apply(n.metrics),
              child: widget.child,
            ),
          ),
        ),
        if (widget.leading)
          _EdgeScrim(
            visible: _before,
            top: true,
            extent: widget.extent,
            color: scrim,
            duration: duration,
          ),
        _EdgeScrim(
          visible: _more,
          top: false,
          extent: widget.extent,
          color: scrim,
          duration: duration,
        ),
      ],
    );
  }
}

class _EdgeScrim extends StatelessWidget {
  const _EdgeScrim({
    required this.visible,
    required this.top,
    required this.extent,
    required this.color,
    required this.duration,
  });

  final bool visible;
  final bool top;
  final double extent;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: extent,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          curve: PrismMotion.standard,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: <Color>[color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
