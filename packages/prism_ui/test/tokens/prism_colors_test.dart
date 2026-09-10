import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Relative luminance per WCAG 2.x.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Contrast ratio between two opaque colours. 1.0 means identical.
double contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Flatten [src] over [dst] so a translucent token can be measured where it
/// actually lands.
Color over(Color src, Color dst) => Color.alphaBlend(src, dst);

void main() {
  // These are not hex snapshots. They re-derive the guarantees the palette was
  // built to hold, so a future edit that *looks* fine but destroys legibility
  // fails here instead of shipping.
  //
  // The numbers in the failure messages are the point: the palette this
  // replaced had a glass stroke measuring 1.008:1 against its own fill, and a
  // card measuring 1.019:1 against its background.
  group('PrismColors — the spectrum holds its measured floors', () {
    const List<String> names = <String>['violet', 'magenta', 'rose', 'amber', 'green', 'cyan'];
    const Color white = Color(0xFFFFFFFF);

    test('exposes exactly six bands in every role', () {
      expect(PrismColors.spectrumInk, hasLength(6));
      expect(PrismColors.spectrumVivid, hasLength(6));
      expect(PrismColors.spectrumGlow, hasLength(6));
      expect(PrismColors.spectrumSoftLight, hasLength(6));
      expect(PrismColors.spectrumSoftDark, hasLength(6));
    });

    test('bands are all distinct within each role', () {
      for (final List<Color> role in <List<Color>>[
        PrismColors.spectrumInk,
        PrismColors.spectrumVivid,
        PrismColors.spectrumGlow,
      ]) {
        expect(role.map((Color c) => c.toARGB32()).toSet(), hasLength(role.length));
      }
    });

    test('the brand primary is the first band of the spectrum', () {
      expect(PrismColors.primary, PrismColors.spectrumInk.first);
      expect(PrismColors.primaryVivid, PrismColors.spectrumVivid.first);
      expect(PrismColors.primaryGlow, PrismColors.spectrumGlow.first);
    });

    test('ink is body-text legible on the light canvas (>= 4.5:1)', () {
      for (int i = 0; i < 6; i++) {
        expect(
          contrast(PrismColors.spectrumInk[i], PrismColors.lightBg),
          greaterThanOrEqualTo(4.5),
          reason: '${names[i]} ink must carry body text on the light canvas',
        );
      }
    });

    test('ink carries white body text when used as a fill (>= 4.5:1)', () {
      for (int i = 0; i < 6; i++) {
        expect(
          contrast(PrismColors.spectrumInk[i], white),
          greaterThanOrEqualTo(4.5),
          reason: '${names[i]} ink is a solid fill and must carry white text',
        );
      }
    });

    test('glow is body-text legible on dark chrome (>= 4.5:1)', () {
      for (int i = 0; i < 6; i++) {
        expect(
          contrast(PrismColors.spectrumGlow[i], PrismColors.darkBg),
          greaterThanOrEqualTo(4.5),
          reason: '${names[i]} glow is the dark-mode text role',
        );
      }
    });

    test('vivid reads as a fill and carries large text (>= 3:1 on white)', () {
      for (int i = 0; i < 6; i++) {
        expect(
          contrast(PrismColors.spectrumVivid[i], white),
          greaterThanOrEqualTo(3.0),
          reason: '${names[i]} vivid is a fill role, large text only',
        );
        expect(
          contrast(PrismColors.spectrumVivid[i], PrismColors.lightBg),
          greaterThanOrEqualTo(1.5),
          reason: '${names[i]} vivid must be visible as a fill on the canvas',
        );
      }
    });

    test('constant lightness keeps the spectrum even — no band shouts', () {
      // The organizing law: because L is held constant across hues, contrast
      // against a fixed background must stay in a narrow window. A band that
      // drifts out of it would dominate the others.
      final List<double> ratios = <double>[
        for (final Color c in PrismColors.spectrumInk) contrast(c, PrismColors.lightBg),
      ];
      final double spread = ratios.reduce(math.max) - ratios.reduce(math.min);
      expect(
        spread,
        lessThan(1.5),
        reason: 'ink contrast spread across the spectrum was $ratios',
      );
    });
  });

  group('PrismColors — chrome separates into real planes', () {
    test('a light card is a distinct plane above its canvas', () {
      // Was 1.019:1 — the card and the page were the same sheet.
      expect(
        contrast(PrismColors.lightSurface, PrismColors.lightBg),
        greaterThanOrEqualTo(1.12),
      );
    });

    test('a dark card is a distinct plane above its canvas', () {
      // Was 1.017:1.
      expect(contrast(PrismColors.darkSurface, PrismColors.darkBg), greaterThanOrEqualTo(1.12));
    });

    test('borders are visible against their surface', () {
      // Was 1.231:1 light and 1.342:1 dark.
      expect(
        contrast(PrismColors.lightBorder, PrismColors.lightSurface),
        greaterThanOrEqualTo(1.6),
      );
      expect(contrast(PrismColors.darkBorder, PrismColors.darkSurface), greaterThanOrEqualTo(1.6));
    });

    test('the strong border is firmer than the hairline', () {
      expect(
        contrast(PrismColors.lightBorderStrong, PrismColors.lightSurface),
        greaterThan(contrast(PrismColors.lightBorder, PrismColors.lightSurface)),
      );
      expect(
        contrast(PrismColors.darkBorderStrong, PrismColors.darkSurface),
        greaterThan(contrast(PrismColors.darkBorder, PrismColors.darkSurface)),
      );
    });

    test('body and secondary text clear 4.5:1 on both chromes', () {
      expect(
        contrast(PrismColors.lightTextPrimary, PrismColors.lightSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(PrismColors.lightTextSecondary, PrismColors.lightSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(PrismColors.darkTextPrimary, PrismColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(PrismColors.darkTextSecondary, PrismColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('disabled text still reads as text, not as a rendering fault', () {
      expect(
        contrast(PrismColors.lightTextDisabled, PrismColors.lightSurface),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        contrast(PrismColors.darkTextDisabled, PrismColors.darkSurface),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  group('PrismColors — the glass edge is directional', () {
    test('light glass separates from the canvas it floats on', () {
      final Color fill = over(PrismColors.glassLightFill, PrismColors.lightBg);
      expect(contrast(fill, PrismColors.lightBg), greaterThanOrEqualTo(1.10));
    });

    test('the light glass stroke is DARKER than its own fill', () {
      // The original defect, guarded permanently: a white stroke over a light
      // fill measured 1.008:1, where 1.000 is literally the same colour.
      final Color fill = over(PrismColors.glassLightFill, PrismColors.lightBg);
      final Color stroke = over(PrismColors.glassLightStroke, fill);
      expect(
        _luminance(stroke),
        lessThan(_luminance(fill)),
        reason: 'a light-mode edge must be darker than the surface it bounds',
      );
      expect(contrast(stroke, fill), greaterThanOrEqualTo(1.6));
    });

    test('the dark glass stroke is LIGHTER than its own fill', () {
      final Color fill = over(PrismColors.glassDarkFill, PrismColors.darkBg);
      final Color stroke = over(PrismColors.glassDarkStroke, fill);
      expect(_luminance(stroke), greaterThan(_luminance(fill)));
      expect(contrast(stroke, fill), greaterThanOrEqualTo(1.6));
    });

    test('the lit edge exists only where it can be seen', () {
      // A white highlight over a light fill measures 1.00:1, so light mode
      // carries depth with shadow instead and publishes a transparent edge.
      expect(PrismColorScheme.light.litEdge.a, 0);
      expect(PrismColorScheme.dark.litEdge.a, greaterThan(0));
      final Color darkFill = over(PrismColors.glassDarkFill, PrismColors.darkBg);
      expect(contrast(over(PrismColorScheme.dark.litEdge, darkFill), darkFill),
          greaterThanOrEqualTo(1.2));
    });
  });

  group('PrismColors — semantic status', () {
    test('status fills carry white text', () {
      const Color white = Color(0xFFFFFFFF);
      for (final Color c in <Color>[
        PrismColors.success,
        PrismColors.warning,
        PrismColors.error,
        PrismColors.info,
      ]) {
        expect(contrast(c, white), greaterThanOrEqualTo(4.5));
      }
    });

    test('status on-surface tones are legible on their own chrome', () {
      for (final Color c in <Color>[
        PrismColors.successGlow,
        PrismColors.warningGlow,
        PrismColors.errorGlow,
        PrismColors.infoGlow,
      ]) {
        expect(contrast(c, PrismColors.darkBg), greaterThanOrEqualTo(4.5));
      }
      for (final Color c in <Color>[
        PrismColors.success,
        PrismColors.warning,
        PrismColors.error,
        PrismColors.info,
      ]) {
        expect(contrast(c, PrismColors.lightBg), greaterThanOrEqualTo(4.5));
      }
    });

    test('light and dark backgrounds differ', () {
      expect(PrismColors.lightBg, isNot(PrismColors.darkBg));
    });
  });

  group('PrismColors — domain accents', () {
    test('exposes exactly six domain accents', () {
      expect(PrismColors.domainAccents, hasLength(6));
    });

    test('domain accents are all distinct', () {
      final Set<int> unique = PrismColors.domainAccents.map((Color c) => c.toARGB32()).toSet();
      expect(unique, hasLength(PrismColors.domainAccents.length));
    });

    test('first domain accent matches the brand primary', () {
      expect(PrismColors.domainAccents.first, PrismColors.primary);
    });
  });

  group('PrismColors — the Azure blue is kept, just not as the brand', () {
    test('azureTrack preserves the original Fluent blue', () {
      expect(PrismColors.azureTrack, const Color(0xFF0078D4));
    });

    test('the brand is no longer the vendor blue', () {
      expect(PrismColors.primary, isNot(PrismColors.azureTrack));
    });
  });
}
