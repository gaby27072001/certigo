import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The software vendors whose certification catalogues Certigo surfaces.
///
/// The Certigo content library is organised, Duolingo-section-picker style, by
/// *provider* first, before drilling into a certification and its chapters.
///
/// Kept dependency-free (no data-layer coupling) so the design system can draw
/// a vendor tile without importing any app model; screens map their catalogue
/// to a [VendorBrand].
enum VendorBrand {
  /// Microsoft — Azure, Security, Data & AI, Microsoft 365, Power Platform… .
  microsoft,

  /// GitHub — GitHub Foundations, Actions, Advanced Security, Copilot… .
  github,

  /// Google Cloud.
  google,

  /// Amazon Web Services.
  aws,

  /// OpenAI — showcase placeholder (no tracks yet).
  openai,
}

/// Per-vendor identity: display label and signature brand color.
extension VendorBrandInfo on VendorBrand {
  /// Brand name shown under the tile (kept in the vendor's own wording).
  String get label => switch (this) {
        VendorBrand.microsoft => 'Microsoft',
        VendorBrand.github => 'GitHub',
        VendorBrand.google => 'Google Cloud',
        VendorBrand.aws => 'AWS',
        VendorBrand.openai => 'OpenAI',
      };

  /// A stable id, used for routing (`/library/vendor/:vendorId`).
  String get id => switch (this) {
        VendorBrand.google => 'gcp',
        _ => name,
      };

  /// Signature brand color — a representative single hue for chips, borders and
  /// accent washes. The multi-color logos are drawn by [VendorLogo].
  Color get brandColor => switch (this) {
        VendorBrand.microsoft => const Color(0xFF0078D4),
        VendorBrand.github => const Color(0xFF24292F),
        VendorBrand.google => const Color(0xFF4285F4),
        VendorBrand.aws => const Color(0xFFFF9900),
        VendorBrand.openai => const Color(0xFF10A37F),
      };

  /// Resolves a [VendorBrand] from its [id]; falls back to Microsoft, the
  /// flagship vendor, for unknown ids.
  static VendorBrand fromId(String id) => VendorBrand.values.firstWhere(
        (VendorBrand v) => v.id == id || (v == VendorBrand.google && id == 'google'),
        orElse: () => VendorBrand.microsoft,
      );
}

/// A trademark-safe, hand-drawn vendor "logo" pastille.
///
/// Every mark is a **stylised** [CustomPaint] approximation — never a
/// pixel-perfect reproduction of the official logo, and no brand asset is
/// bundled or downloaded. It reads instantly as the vendor (Microsoft's four
/// tiles, GitHub's cat silhouette, Google's multicolor ring, AWS's orange
/// smile, OpenAI's petal knot) while staying an original drawing.
class VendorLogo extends StatelessWidget {
  const VendorLogo({super.key, required this.brand, this.size = 44});

  final VendorBrand brand;

  /// Edge length of the (square) logo box.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo ${brand.label}',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _VendorLogoPainter(brand)),
      ),
    );
  }
}

class _VendorLogoPainter extends CustomPainter {
  const _VendorLogoPainter(this.brand);

  final VendorBrand brand;

  @override
  void paint(Canvas canvas, Size size) {
    switch (brand) {
      case VendorBrand.microsoft:
        _paintMicrosoft(canvas, size);
      case VendorBrand.github:
        _paintGitHub(canvas, size);
      case VendorBrand.google:
        _paintGoogle(canvas, size);
      case VendorBrand.aws:
        _paintAws(canvas, size);
      case VendorBrand.openai:
        _paintOpenAi(canvas, size);
    }
  }

  /// Four coloured tiles in a 2×2 grid with a thin gutter — the unmistakable
  /// Microsoft "window", drawn from scratch.
  void _paintMicrosoft(Canvas canvas, Size size) {
    const double gutterFactor = 0.08;
    final double gutter = size.width * gutterFactor;
    final double tile = (size.width - gutter) / 2;
    const List<Color> colors = <Color>[
      Color(0xFFF25022), // red — top-left
      Color(0xFF7FBA00), // green — top-right
      Color(0xFF00A4EF), // blue — bottom-left
      Color(0xFFFFB900), // yellow — bottom-right
    ];
    final List<Offset> origins = <Offset>[
      Offset.zero,
      Offset(tile + gutter, 0),
      Offset(0, tile + gutter),
      Offset(tile + gutter, tile + gutter),
    ];
    final double radius = tile * 0.08;
    for (int i = 0; i < 4; i++) {
      final Paint paint = Paint()..color = colors[i];
      final RRect r = RRect.fromRectAndRadius(
        Rect.fromLTWH(origins[i].dx, origins[i].dy, tile, tile),
        Radius.circular(radius),
      );
      canvas.drawRRect(r, paint);
    }
  }

  /// A monochrome cat-like silhouette (rounded body, two ears, tail curl) — an
  /// original nod to GitHub's mascot, not a copy of the Octocat.
  void _paintGitHub(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF24292F)
      ..style = PaintingStyle.fill;
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w * 0.5, h * 0.52);
    final double headR = w * 0.34;

    // Ears — two soft triangles poking above the head.
    final Path ears = Path()
      ..moveTo(w * 0.24, h * 0.30)
      ..lineTo(w * 0.36, h * 0.14)
      ..lineTo(w * 0.44, h * 0.34)
      ..close()
      ..moveTo(w * 0.76, h * 0.30)
      ..lineTo(w * 0.64, h * 0.14)
      ..lineTo(w * 0.56, h * 0.34)
      ..close();
    canvas.drawPath(ears, paint);

    // Head + body blob.
    canvas.drawCircle(center, headR, paint);
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.20, h * 0.52, w * 0.60, h * 0.34),
      Radius.circular(w * 0.20),
    );
    canvas.drawRRect(body, paint);

    // Eyes punched out with the background so the silhouette reads as a face.
    final Paint cut = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(ears, paint);
    canvas.drawCircle(center, headR, paint);
    canvas.drawRRect(body, paint);
    canvas.drawCircle(Offset(w * 0.40, h * 0.50), w * 0.055, cut);
    canvas.drawCircle(Offset(w * 0.60, h * 0.50), w * 0.055, cut);
    canvas.restore();
  }

  /// A thick multicolour ring with the signature crossbar — a stylised "G".
  void _paintGoogle(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width * 0.36;
    final double stroke = size.width * 0.18;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const List<Color> arcColors = <Color>[
      Color(0xFF4285F4), // blue
      Color(0xFFEA4335), // red
      Color(0xFFFBBC05), // yellow
      Color(0xFF34A853), // green
    ];
    // Draw the ring in four quarter-arcs, leaving a gap on the right for the "G".
    const double start = -math.pi / 4;
    const double sweep = (2 * math.pi - math.pi / 3) / 4;
    for (int i = 0; i < 4; i++) {
      final Paint arc = Paint()
        ..color = arcColors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start + i * sweep, sweep, false, arc);
    }
    // The crossbar of the G — a blue stub reaching into the centre.
    final Paint bar = Paint()
      ..color = arcColors[0]
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx + radius * 0.1, center.dy),
      Offset(center.dx + radius + stroke * 0.2, center.dy),
      bar,
    );
  }

  /// An orange upward "smile" arrow — an original take on AWS's smile.
  void _paintAws(Canvas canvas, Size size) {
    final Paint smile = Paint()
      ..color = const Color(0xFFFF9900)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;
    final double w = size.width;
    final double h = size.height;
    final Path path = Path()
      ..moveTo(w * 0.16, h * 0.56)
      ..quadraticBezierTo(w * 0.5, h * 0.86, w * 0.84, h * 0.56);
    canvas.drawPath(path, smile);

    // Arrowhead at the end of the smile.
    final Paint head = Paint()..color = const Color(0xFFFF9900);
    final Path arrow = Path()
      ..moveTo(w * 0.84, h * 0.56)
      ..lineTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.80, h * 0.66)
      ..close();
    canvas.drawPath(arrow, head);
  }

  /// A radial knot of six petals — a stylised OpenAI blossom.
  void _paintOpenAi(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double petalLen = size.width * 0.34;
    final double petalW = size.width * 0.16;
    final Paint paint = Paint()
      ..color = const Color(0xFF10A37F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = petalW
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final double angle = i * math.pi / 3;
      final Offset tip = center + Offset(math.cos(angle), math.sin(angle)) * petalLen;
      canvas.drawLine(center, tip, paint);
    }
    // A soft hub so the petals read as a single flower.
    canvas.drawCircle(center, petalW * 0.5, Paint()..color = const Color(0xFF0E8C6D));
  }

  @override
  bool shouldRepaint(_VendorLogoPainter oldDelegate) => oldDelegate.brand != brand;
}
