import 'package:flutter/widgets.dart';

/// Prism layout tokens — the width axis.
///
/// This axis was missing entirely. `tokens/` held colour, elevation, motion,
/// radii, spacing and typography, but nothing that named a width, so every
/// screen that needed one invented its own literal: 320, 340, 420, 480, 640,
/// 760, 840 and 1120 were all in use, none of them behind a token, and only
/// one screen body in the app was width-bounded at all.
///
/// That matters well before any exotic hardware. An unbounded body stretches
/// to whatever width it is given, which is already the everyday case on iPad,
/// in landscape, and in Split View. A line of text 1100 px wide is unreadable
/// regardless of what device produced it.
///
/// These are **reading widths**, not breakpoints. Prism does not branch on
/// device class; it caps the measure and lets the layout centre itself, which
/// stays correct on any size the platform hands it.
@immutable
class PrismLayout {
  const PrismLayout._();

  /// A single focused card: loading and status views, onboarding illustrations.
  static const double compact = 320;

  /// A form column or a short prose block — sign-in fields, dialogs.
  static const double form = 420;

  /// A standalone panel: config errors, isolated messages.
  static const double panel = 480;

  /// A control bar. Navigation should not stretch to the full width of a wide
  /// window, or its targets drift apart from the content they act on.
  static const double controlBar = 640;

  /// **The reading measure.** Default cap for a screen body. Prose stays in the
  /// 65–75 character range at Prism's 17 pt body size.
  static const double reading = 760;

  /// A canvas that may hold two columns of content plus its aurora.
  static const double canvas = 840;

  /// A dense working surface — tables, dashboards, the manager portal.
  static const double workspace = 1120;

  /// Ordered from tightest to widest, for tests and tooling.
  static const List<double> scale = <double>[
    compact,
    form,
    panel,
    controlBar,
    reading,
    canvas,
    workspace,
  ];
}
